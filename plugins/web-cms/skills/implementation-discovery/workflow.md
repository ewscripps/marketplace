# IMPLEMENTATION DISCOVERY WORKFLOW — EXECUTION CONTRACT

> **How this works:** The user invokes this workflow when they want to understand how to approach building or changing something before defining formal requirements. The agent drives a short interactive session to understand the topic, explores the relevant codebase areas in parallel, surfaces either a single recommended approach or a ranked comparison of options, then runs a focused verification round against the user's chosen approach to confirm findings hold and surface anything missed. The full discovery output is persisted to the session knowledge graph and the workflow ends. To run requirements-intake on the discovery, the user clears conversation context with `/clear` and then invokes `/requirements-intake` in a fresh conversation — the knowledge graph survives the clear, so requirements-intake's R0 discovery pre-check picks the output up automatically. This workflow does not chain into requirements-intake itself.

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute phases in strict sequential order (D0 through D5).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure in the chat. Do not continue.
5. Every required output must be presented in the chat before the phase is considered complete.

**APPROVAL GATE BEHAVIOR:** Approval gates are chat-scoped. If explicit approval is not captured before the session ends or context is lost, stop at the gate. On resume, re-present the latest summary and ask for confirmation again. Never assume a pending approval was granted.

**KNOWLEDGE GRAPH SCOPE — INTENTIONAL PERSISTENCE:** Unlike other intake and execution workflows, this workflow does NOT clean up its knowledge graph at the end. The `work_item-discovery-<slug>` entity, the explorer subgraph created at D1, the verification-round explorations created at D4, and the `discovery_summary-<slug>` entity written at D5 are deliberately left in place so that a follow-on `requirements-intake` run can pick them up at R0/R2 without re-exploring the codebase. The graph persists across `/clear` (which only clears conversation context, not the memory MCP server's state), so the recommended handoff is: this workflow finishes, the user runs `/clear`, then the user invokes `/requirements-intake` in a fresh conversation. Cleanup ownership transfers to `requirements-intake`: its terminal R6 cleanup phase is responsible for deleting all discovery entities along with its own. If the user never runs `/requirements-intake`, the entities remain until the Claude Code session itself ends; they are session-scoped and will not survive into a new launch.

**GRAPH-AUTHORITATIVE CONTRACT FOR FINDINGS:** Within the discovery output, the knowledge-graph entities (explorations, evidence, patterns, integration points, risks, open questions) are the canonical record of *what was found*. The `synthesis_chosen` text written at D5 is the human-readable summary of the canonical record at the time of persistence; it is intended for direct insertion into the Jira issue description by downstream consumers. When D4 changes a finding (revises, contradicts, marks an item superseded), it MUST update the underlying graph entities at the same time it updates the synthesis text — the two views must agree at the moment of D5 persistence. Downstream consumers (notably `requirements-intake` R2) treat the graph as the structured truth: they must filter `superseded: true` entities when traversing, and prefer graph evidence over synthesis text if a conflict ever surfaces.

**CLARIFICATION RULE:** Do not assume anything. If required information is missing, ambiguous, or underspecified, stop and use `AskUserQuestion` to ask the user for clarification before proceeding.

**TOOL PREFERENCE:** Prefer native tools over Bash for filesystem work. All filesystem, search, and directory operations must stay within the current project directory.

- **File I/O (read, write, edit a known file):** Use native `Read`, `Write`, `Edit`.
- **File discovery (find files by name or pattern):** Use native `Glob`.
- **Content search (find text inside files):** Use native `Grep`. For symbolic code search, delegate to the `codebase-explorer` agent.
- **Directory operations (list, metadata, move, mkdir):** Use Bash (`ls`, `stat`, `mv`, `mkdir -p`).
- **Git:** Use Bash for all git operations (`git status`, `git diff`, `git log`, `git push`, `git pull`, `git merge`, `git worktree`, `git remote`, `git stash`, `git rebase`, etc.) and for running build, test, and lint commands.

**SERENA PROJECT ACTIVATION:** Before D0, call `check_onboarding_performed`. If it reports that onboarding has not been performed for this project, call `onboarding` to scope Serena's language server to the current project directory. Serena's symbol tools (`find_symbol`, `find_referencing_symbols`, `get_symbols_overview`, `search_for_pattern`) and any symbol-aware operations invoked by the `codebase-explorer` agent depend on this being done. Do this once at the start of the workflow; do not repeat it between phases.

**TASK TRACKING:** Always use task tracking (`TaskCreate`/`TaskUpdate`) so progress is visible throughout. Create one task per phase at the start of the workflow. Mark each task `in_progress` when starting the phase and `completed` when the phase is done:

- D0 — Intake
- D1 — Codebase Discovery
- D2 — Synthesis
- D3 — Discussion
- D4 — Verification Round
- D5 — Persist and Handoff

**PHASE COMPACTION HANDOFF CONTRACT:** At designated compaction gates in this workflow, the agent writes a durable `phase_handoff` entity to the knowledge graph and prompts the user to run `/compact`. This prevents auto-compaction from discarding phase position mid-discovery.

**Steps at each gate — execute before instructing `/compact`:**

1. Wait for any background `area-mapper` sub-agent to complete.
2. Create a `phase_handoff` entity in the knowledge graph:
   - **Name:** `phase-handoff-discovery-<topic-slug>-<phase-id>` (e.g. `phase-handoff-discovery-add-retry-logic-D2`); use the same `<topic-slug>` derived in D1.
   - **Observations:** `phase: <id>`, `skill: implementation-discovery`, `topic_slug: <slug>`, `work_item_id: <work_item-discovery-<slug>>`, one `decisions: <text>` observation per key decision made this phase, `approval_condition: <verbatim user phrasing or "none">`, `next_phase: <id>`, one `open_items: <text>` per open item.
   - **Relations:** `BELONGS_TO` → `work_item-discovery-<topic-slug>`; `SUPERSEDES` → prior `phase_handoff` for this topic (if any); `REFERENCES` → relevant `exploration` entity names.
3. Call `open_nodes` on the new entity and each `REFERENCES` target to confirm writes landed.
4. Emit the Phase Summary block in the chat. The block must contain: phase ID and skill name, topic slug, work_item_id, one-line decision summary, verbatim approval condition, next phase ID, handoff entity name, and resume contract ("open_nodes on handoff entity → traverse REFERENCES → continue at `<next-phase>`"). End your turn immediately after the Phase Summary block — do not add any further content. The block must end with this literal line: **"Run `/compact` now, then type `continue` to resume."** Do NOT call `AskUserQuestion` here; the user must be free to run `/compact` in the prompt input without any open question consuming their input. When the user next types `continue` (or any message clearly indicating compaction is done), call `open_nodes` on the `phase_handoff` entity, traverse its `REFERENCES`, and resume at `next_phase`. If the user types a different message instead, handle it normally.

**Note on cleanup:** This workflow intentionally leaves the knowledge graph intact for requirements-intake to consume. The `phase_handoff` entities created here are reaped by requirements-intake R6 (which sweeps all upstream implementation-discovery state) or by issue-intake I6 (bug path). If neither follow-on workflow runs, these entities persist until the Claude Code session ends.

---

### D0 — Intake

**Objective:** Understand what the user wants to explore and how they want the output shaped.

**Agent Actions:**

1. Briefly explain what this workflow does (parallel codebase exploration, approach surfacing, focused verification round, persistence to the knowledge graph) and what to expect. Mention that requirements-intake is a separate next step the user runs after `/clear` — this workflow does not chain into it.

2. Ask the following questions using `AskUserQuestion`, one call per question in sequence. Wait for each response before asking the next.

   - **What to build:** Use `AskUserQuestion` (Header: `Discovery Goal`, Question: `What are you trying to build, change, or investigate?`, Options: `Build something new` — a new feature or capability the codebase doesn't currently support, `Change existing behavior` — modifying, improving, or fixing something that already exists, `Investigate / research` — exploring options or understanding the codebase before deciding). Accept any level of specificity — the user can type a specific description using the Other input.
   - **Codebase areas:** Use `AskUserQuestion` (Header: `Codebase Hints`, Question: `Do you know any specific areas of the codebase that are involved — services, modules, repos, or file paths?`, Options: `Yes, I'll name them` — type the areas using the Other input field, `No / Not sure` — proceed without hints; the agent will infer areas from the topic). Accept "none" or "not sure."
   - **Output preference:** Use `AskUserQuestion` (Header: `Output Format`, Question: `Would you like a single recommended approach, or multiple options to compare?`, Options: `Multiple options (Recommended)` — see 2–4 distinct approaches with trade-offs and a recommendation signal, `Single recommendation` — see one recommended approach with rationale). If the user is unsure, the Recommended option applies.
   - **Change scope:** Use `AskUserQuestion` (Header: `Change Scope`, Question: `Are large rewrites or significant additions to the codebase acceptable, or should I focus on targeted, minimal changes?`, Options: `Targeted only (Recommended)` — bias toward minimal-footprint approaches that extend or adapt what already exists, `Large changes acceptable` — the option space is open; significant refactors, new modules, or pattern replacement may be considered). If the user is unsure, the Recommended option applies.

3. Summarize the gathered context back to the user in a structured format.

> **REQUIRED context before proceeding:**
> - **Topic** — what the user wants to build, change, or investigate (2–4 sentences)
> - **Codebase Hints** — specific areas, or "none provided"
> - **Output Preference** — "single recommendation" or "multiple options"
> - **Change Scope** — "large changes acceptable" or "targeted only"

> **APPROVAL GATE — FULL STOP.** Present the gathered context as a structured summary. Use `AskUserQuestion` (Header: `D0 Approval`, Question: `Does the context summary above accurately capture what you want to explore?`, Options: `Approve and proceed (Recommended)` — all fields are accurate, `Request changes` — some fields need correction). Do not proceed to D1 until the user approves.

---

### D1 — Codebase Discovery

**Objective:** Explore the relevant codebase areas to ground the D2 synthesis in evidence.

> **USE KNOWLEDGE GRAPH:** Before spawning explorers, create a `work_item` entity with name `work_item-discovery-<topic-slug>` (slug derived from the D0 topic via the same normalization rule used elsewhere: lowercase, whitespace/punctuation/slashes → single `-`, trim, collapse). Observations: `work_type: discovery`, `topic`, `output_preference`, `change_scope`, `phase: discovery`. **Record the entity name** as the `work_item_id` for D1 and pass it to every explorer. The `discovery_summary-<topic-slug>` entity created at D5 will reference the same id so requirements-intake R0/R2 can pick up the explorer subgraph.

**Agent Actions:**

1. Derive target areas from the topic description and codebase hints from D0. Be specific — prefer concrete module paths, service names, or component boundaries over vague descriptions. If hints were provided, start there. If not, infer areas from the topic description using file discovery and content search before spawning agents.

2. Invoke a `codebase-explorer` sub-agent in **parallel** for each distinct area, providing:
   - The target area to explore
   - A discovery-scoped question: **"What code, patterns, architecture, and constraints in this area are relevant to implementing or changing [topic]? What approaches are already visible in the existing code, and what would be the natural extension points?"**
   - The `work_item_id` (`work_item-discovery-<topic-slug>`). All findings the explorer streams to the graph will be linked to this node.
   - The topic description for context

3. Wait for all explorers to return. Each non-failed return contains an `Entity:` line with the exploration entity name. `INCOMPLETE` means partial findings are present; consider re-spawning for the same area if coverage matters. `FAILED` means no graph data was written — re-spawn that explorer before proceeding.

> **POST-EXPLORATION ENRICHMENT:** Spawn the `area-mapper` sub-agent **in the background** (`run_in_background: true`) with the same `work_item_id`. The mapper crystallizes durable area knowledge from this run's graph into Serena project memory for future explorations. Do not wait for it — proceed immediately to step 4.

4. Call `open_nodes` on each `exploration` entity name from the returns. If any entity comes back empty, re-spawn that explorer rather than treating missing data as confirmed. Surface any `open_question` entities in the responses. If any identifies a connection to another area not yet explored, dispatch a follow-up `codebase-explorer` (passing the same `work_item_id`) before proceeding.

5. Review the assembled subgraph for consistency. Note any conflicting signals across areas before moving to synthesis — for example, two explorers writing `pattern` entities that contradict each other, or `risk` entities that flag the same area at different severities.

> **REQUIRED before proceeding:**
> - All assigned explorer reports received
> - Follow-up explorations dispatched and received (if triggered by open questions)
> - Conflicting signals across areas identified, or confirmed absent

---

### D2 — Synthesis

**Objective:** Translate explorer findings into clear, evidence-grounded implementation approaches.

**Agent Actions:**

1. > **USE SEQUENTIAL THINKING:** Before synthesizing, invoke the `sequentialthinking` tool. Work through the D1 findings systematically: identify what the codebase makes easy, what it makes hard, what patterns are already established, and what constraints exist. For each candidate approach, evaluate effort, risk, and fit with existing conventions. Reason through this in full before producing any output.

   > **RESPECT THE CHANGE SCOPE SIGNAL FROM D0.**
   > - If **"large changes acceptable":** the option space is open. You may surface approaches that involve substantial refactors, new modules or services, replacement of existing patterns, or other significant additions where the D1 evidence supports them as a better fit than a narrow extension.
   > - If **"targeted only":** bias toward minimal-footprint approaches that extend, adapt, or compose what already exists. Do not propose large rewrites or significant new infrastructure. If D1 evidence strongly suggests a targeted change is infeasible or carries serious risk, surface that as a constraint or risk in the synthesis rather than silently proposing a larger change.

2. Produce output shaped by the preference from D0:

   **If "single recommendation":**

   Present a structured recommendation:

   ```
   ## Recommended Approach
   [One clear approach name]

   ### What It Does
   [2–3 sentences describing the approach]

   ### Rationale
   [Why this approach fits — cite specific patterns, conventions, or extension points from D1]

   ### Affected Areas
   - `[path]` — [description] ([high / medium / low] risk)

   ### Effort
   [S / M / L — one sentence justification]

   ### Risks
   - [Risk] — [Mitigation]

   ### Constraints
   [Known constraints from D1 that shape or limit this approach, or "None identified."]
   ```

   **If "multiple options":**

   Present 2–4 distinct approaches. For each:

   ```
   ## Option [N]: [Approach Name]

   ### What It Does
   [2–3 sentences]

   ### Affected Areas
   - `[path]` — [description] ([high / medium / low] risk)

   ### Effort
   [S / M / L]

   ### Risk
   [H / M / L — one sentence rationale]

   ### Trade-offs
   [Pros and cons grounded in D1 evidence]
   ```

   Then present a comparison summary:

   | Option | Effort | Risk | Fits Existing Patterns | Notes |
   |--------|--------|------|------------------------|-------|
   | [name] | S/M/L  | H/M/L | Yes / Partially / No  | ...   |

   Close with a **recommendation signal**: "Based on the codebase findings, Option N is the most natural fit because [brief rationale tied to evidence]."

3. Label any items not directly evidenced in the D1 findings as `[INFERRED]`.

4. > **REQUIRED: Review the synthesis before presenting.** Verify every claim is grounded in D1 evidence. Remove or revise any that are not. Label remaining inferences explicitly. Do not present an unreviewed synthesis.

> **APPROVAL GATE — FULL STOP.** Present the full D2 synthesis. Use `AskUserQuestion` (Header: `D2 Approval`, Question: `Does this synthesis accurately reflect what you want to explore? Are the affected areas and approach(es) correct?`, Options: `Approve and proceed (Recommended)` — the synthesis looks correct, `Request changes` — something needs revision). Do not proceed to D3 until the user approves.

> **COMPACTION GATE — D2:** Once D2 approval is confirmed, follow the Phase Compaction Handoff Contract above. Entity name: `phase-handoff-discovery-<topic-slug>-D2`; `next_phase: D3`; decisions: synthesis approach count and recommended option (if any); output_preference and chosen approach (once selected in D3 — if not yet selected, record "pending D3"). REFERENCES: exploration entities from D1. Emit the Phase Summary block and instruct the user to run `/compact` before proceeding to D3.

---

### D3 — Discussion

**Objective:** Give the user space to ask questions, push back, or express preferences about the discovery output before it is persisted and acted on.

**Agent Actions:**

1. Open the conversation: **"Do you have any questions or thoughts about any of the options? I'm happy to go deeper on any area, compare trade-offs further, or talk through concerns."**

2. Engage in free-form conversation with the user. This phase has no fixed structure — follow the user's lead. Guidelines:
   - **If the user asks a clarifying question:** answer it using evidence from the D1 findings. Do not speculate beyond what was explored. If a question cannot be answered from D1 evidence, say so explicitly and note it as an open question.
   - **If the user pushes back on an option:** engage honestly. If the pushback reveals a constraint or signal that would change the recommendation, acknowledge it and explain how it affects the analysis.
   - **If the user states a preference** (e.g., "I'm leaning toward Option 2"): acknowledge it and note it — it will be recorded in the knowledge graph in D5 so requirements-intake has full context, and it scopes the D4 verification round.
   - **If the user asks to see an additional option** not already presented: evaluate whether D1 evidence supports it. If yes, synthesize it using the same format from D2. If no, explain why the evidence doesn't support it.

3. Continue the conversation for as many turns as the user needs. Do not rush toward the next phase.

4. **Capture the chosen approach before exiting.** When the user signals they are done (e.g., "no, I'm good", "let's continue", "that answers it"), the next phase (D4) re-explores the codebase against one specific approach, so a choice is required.
   - **Single-recommendation runs:** the recommended approach is the chosen approach unless the user said otherwise. Use `AskUserQuestion` (Header: `Chosen Approach`, Question: `We'll verify the recommended approach next — does that match what you want to move forward with?`, Options: `Yes, verify the recommended approach (Recommended)`, `No, I want something different`).
   - **Multiple-options runs:** if the user has not yet stated a choice, use `AskUserQuestion` (Header: `Chosen Approach`, Question: `Which option would you like to move forward with?`, Options: one option per presented approach, labeled with its name from D2). Do not infer a choice; record what the user selects.
   - Then confirm the full exit state using `AskUserQuestion` (Header: `Ready to Verify`, Question: `Got it — I'll verify [chosen approach] and note [preference / concern / open question] when I save the discovery output. Ready to move on?`, Options: `Yes, move on to verification (Recommended)`, `Wait — I have more questions`).

> **There is no approval gate for this phase.** The user exits by signaling readiness. Do not proceed to D4 until the user has explicitly indicated they are done with discussion **and** the chosen approach is recorded.

---

### D4 — Verification Round

**Objective:** Re-explore the codebase against the chosen approach to confirm D1 findings still hold, surface anything the first round missed, and revise the synthesis if material gaps or contradictions are found — before any output is persisted.

**Why this phase exists:** D1 explores broadly across the option space. By the time the user has chosen an approach in D3, the relevant decision boundary is narrower — and a focused second look at the specific files, patterns, and integration points that approach depends on catches problems that wide exploration misses. The cost is one parallel explorer batch; the upside is that requirements-intake inherits a verified picture rather than a first-pass one.

**Preconditions:** A specific chosen approach is recorded from D3 step 4. If no choice was captured, return to D3 and capture one — do not run verification against multiple options.

**Agent Actions:**

1. **Plan the verification.** From the D2 synthesis for the chosen approach, enumerate:
   - The specific files, modules, and integration points the approach relies on.
   - The patterns the approach extends, composes, or replaces.
   - The risks and constraints called out in the synthesis.
   - Any items labelled `[INFERRED]` in D2 — these get the highest verification priority because they were not directly evidenced in D1.
   - Any open questions raised in D3 that touch the chosen approach.

   Group the verification claims by area (the same area boundaries used in D1, plus any new areas the chosen approach pulls in that were not explored in D1). Present the verification plan in the chat as a short, structured list before spawning explorers — the user may add an area, drop one, or flag a claim they want investigated more deeply.

2. **Spawn verification explorers in parallel.** For each area covering one or more verification claims, invoke a `codebase-explorer` sub-agent with:
   - The same `work_item_id` (`work_item-discovery-<topic-slug>`) so verification findings join the same subgraph.
   - A verification-scoped question: **"For the chosen approach `[approach name]`, verify the following specific claims and surface anything missed: [bulleted claim list for this area]. For each claim, return one of confirmed / contradicted / partially confirmed with the supporting evidence. Then look for missing dependencies, integration points, risks, or blockers that prior exploration did not capture."**
   - The chosen approach name and the relevant excerpt of the D2 synthesis for context.
   - An instruction to add `round: verification` and `verifies_approach: [approach name]` observations to the new `exploration` entity it creates, so D5 can distinguish first-round and verification-round findings in the persisted graph.
   - **An explicit name-suffix override for entity uniqueness.** D1 explorations on the same area already exist in the graph with names of the form `exploration-<work_item_key>-<area_slug>` and `<finding-type>-<work_item_key>-<area_slug>-<…>`. Tell the explorer to append the literal suffix `-verification` to every entity name it creates this run (`exploration-<work_item_key>-<area_slug>-verification`, `file-<work_item_key>-<area_slug>-<path-slug>-verification`, `evidence-<work_item_key>-<area_slug>-<short-claim-slug>-verification`, etc.) so the verification-round subgraph never collides with the first-round subgraph on `create_entities`. Without this suffix, every D4 explorer that re-targets a D1 area fails on duplicate-name.

3. Wait for all verification explorers to return. Each non-failed return contains an `Entity:` line with the exploration entity name. If any return `INCOMPLETE` and the gap is on a high-priority verification claim, re-spawn for that area before reconciling. `FAILED` means no graph data was written — re-spawn before reconciling.

> **USE SEQUENTIAL THINKING:** Before reconciling, invoke the `sequentialthinking` tool. Use it to classify each verification claim (Confirmed / Enriched / Contradicted / New blocker) before writing any conclusion to the graph, reason through whether any "Contradicted" finding changes the feasibility of the chosen approach or only adjusts its scope, and decide whether any "New blocker" should trigger a re-open of the synthesis (D3 re-entry) versus being accepted as an open question. This is the most consequential decision point in D4 — a shallow reconciliation that marks everything "Confirmed" because the verification explorer did not find an explicit contradiction is a false clean result that misleads requirements-intake. Do not begin the reconciliation step until the reasoning is complete.

> **THINK HARD:** Before deciding the outcome of the reconciliation, think hard about whether a "material change" threshold is met — specifically, whether any Contradicted or New Blocker finding changes the viability or effort of the chosen approach, or only adds nuance. A false "clean" verdict here causes requirements-intake to inherit a plan whose key assumptions have not been verified.

4. **Reconcile.** Call `open_nodes` on each verification `exploration` entity name from the returns (those with the `-verification` suffix). For each verification claim, classify the outcome:
   - **Confirmed** — verification evidence supports the claim. No action needed.
   - **Enriched** — the claim is correct but the verification round added new evidence (additional callers, edge-case handling, related files). Note for the synthesis update.
   - **Contradicted** — verification evidence shows the claim is wrong. Identify what specifically was wrong and why.
   - **New blocker** — verification surfaced a dependency, risk, or constraint that D1 missed and that materially affects the chosen approach (e.g., the extension point doesn't exist, an integration is owned by another service, a pattern the approach assumed is being deprecated).

   **Mark contradicted entities in the graph as part of reconciliation.** Per the graph-authoritative contract, every D1 finding entity that this verification round contradicts MUST be tagged immediately, before deciding the outcome in step 5. For each contradicted D1 entity (`evidence`, `pattern`, `integration_point`, `risk`, or `affected_file` whose role/relevance is wrong), call `add_observations` to add:
   - `superseded: true`
   - `superseded_at: D4`
   - `superseded_reason: <one-sentence explanation>`
   - `superseded_by: <name of the verification-round entity that supplies the corrected evidence, if any — otherwise "see verification_findings">`

   This applies regardless of which outcome the user chooses in step 5 — once verification has contradicted a finding, it is no longer canonical, and downstream traversal must be able to filter it out.

5. **Decide the outcome.**
   - **Clean (only Confirmed and Enriched):** present a short verification report — "Verification complete. Confirmed: …. New context: …." — then proceed to D5. Update the synthesis text with the enriched evidence before persistence.
   - **Material change (any Contradicted or New blocker):** present the finding to the user with the supporting evidence. Use `AskUserQuestion` (Header: `Material Change`, Question: `This changes the picture for [approach]. How would you like to proceed?`, Options: `Revise this approach and continue (Recommended)` — update the synthesis with the new evidence and proceed, `Re-open synthesis` — loop back to D2 to consider another option with the new evidence in scope, `Accept and proceed` — record the contradiction or blocker as an open question and proceed without revising the synthesis).
     - **(a) Revise:** update the D2 synthesis text inline to reflect the new evidence (revised affected areas, risks, effort, or constraints). The verification-round explorer entities written in step 2 already carry the corrected evidence in the graph; the contradicted D1 entities have already been marked `superseded: true` in step 4. The synthesis text update is the human-readable view that brings the synthesis back into sync with the graph. Present the revised synthesis to the user for confirmation, then proceed.
     - **(b) Re-open synthesis:** loop back to D2 with the verification findings as additional input. Re-run D2 → D3 → D4 with the new evidence in scope. The original `work_item_id` and explorer subgraph stay; this is iteration on the same discovery. (Contradicted entities remain `superseded: true` from step 4 — this carries forward through the re-opened synthesis.)
     - **(c) Accept and proceed:** record the contradiction or blocker as an open question and proceed without revising the synthesis. Specifically:
        - Call `create_entities` to add a structured `open_question` entity for each accepted contradiction or blocker, named `question-<work_item_key>-d4-<short-question-slug>`. Required observations: `question` (the unanswered question or unresolved blocker, phrased as a question), `why_unanswered` (why D4 surfaced it as a blocker), `source: d4_verification`, `severity` (`high` for blockers, `medium` for contradictions, `low` for soft conflicts).
        - Call `create_relations` to link each new `open_question` to `work_item-discovery-<slug>` via a `contains` relation, so it joins the same subgraph as the explorer-written open questions and is reachable from the same traversal.
        - Append a one-line summary of each to the `open_questions` observation on `discovery_summary-<slug>` at D5 step 1 (this is the human-readable view; the entities are the canonical record).

6. **Refresh durable memory.** Spawn the `area-mapper` sub-agent **in the background** (`run_in_background: true`) one more time with the same `work_item_id` so its Serena memory crystallization reflects the verified picture. Do not wait for it.

> **APPROVAL GATE — FULL STOP.** Present the verification report (and the revised synthesis, if revision happened in step 5). Use `AskUserQuestion` (Header: `D4 Approval`, Question: `Does the verification report (and any revisions) look correct? Ready to save the discovery output?`, Options: `Approve and proceed (Recommended)` — the verification outcome and any revisions are correct, `Request changes` — something needs revision). Do not proceed to D5 until the user approves.

> **COMPACTION GATE — D4:** Once D4 approval is confirmed, follow the Phase Compaction Handoff Contract above. Entity name: `phase-handoff-discovery-<topic-slug>-D4`; `next_phase: D5`; decisions: verification outcome (clean / revised / accepted-with-open-questions), approach confirmed or revised. REFERENCES: verification exploration entities from D4 (those with the `-verification` suffix).

> **REQUIRED before proceeding:**
> - Chosen approach is recorded
> - Verification claim list assembled and shown to user
> - All verification explorers returned (with re-spawns for any high-priority `INCOMPLETE`)
> - Reconciliation completed: every verification claim classified
> - User confirmed the outcome (clean proceed / revised proceed / accept-as-open-question proceed) or directed a re-open of synthesis

---

### D5 — Persist and Handoff

**Objective:** Write the confirmed and verified discovery output to the knowledge graph, deliver the standalone synthesis to the user, and instruct them on the clean handoff to requirements-intake. This workflow does not invoke requirements-intake itself.

**Agent Actions:**

1. **Write the discovery summary entity.** Create a `discovery_summary` entity named `discovery_summary-<topic-slug>` (use the same `<topic-slug>` derived in D1, so the summary's name pairs deterministically with `work_item-discovery-<topic-slug>`). The explicit slug-bearing name is required so multiple discoveries in the same session do not collide on a single `discovery_summary` key. Observations:
   - `topic: [the user's topic description from D0]`
   - `work_item_id: [the work_item-discovery-<slug> entity name created in D1]`
   - `codebase_hints: [hints from D0, or "none"]`
   - `output_preference: [single_recommendation | multiple_options]`
   - `change_scope: [large_changes_acceptable | targeted_only]`
   - `affected_areas: [comma-separated list of discovered area paths for the chosen approach, updated with any verification additions and pruned of areas that only mattered to non-chosen options]`
   - `synthesis_chosen: [the synthesis text scoped to the chosen approach — for a single_recommendation run this is the full synthesis; for a multiple_options run this is ONLY the chosen option's block plus any cross-option constraints that still apply, with non-chosen options removed. This is the observation downstream consumers should treat as the human-readable analysis content.]`
   - `synthesis_full: [the complete confirmed synthesis text including all options for a multiple_options run, retained for record only — downstream consumers should NOT use this as the analysis content because it carries unchosen-option evidence.]`
   - `approach_count: [1 for single recommendation, or the number of options presented]`
   - `chosen_approach: [name of the approach the user selected in D3]`
   - `user_preference: [any preference or lean expressed by the user in D3, or "none stated"]`
   - `verification_status: [clean | revised | accepted_with_open_questions]`
   - `verification_findings: [one-line-per-claim summary: confirmed / enriched / contradicted / new-blocker, with file references for non-confirmed items. Contradicted items reference the `superseded: true` D1 entity by name.]`
   - `open_questions: [one line per open question, mirroring the structured `open_question` entities created in step 2 below — this is the human-readable index; the entities themselves are canonical. Use "none" only if no `open_question` entities exist for this work item.]`

   For a `single_recommendation` run, `synthesis_chosen` and `synthesis_full` will normally be identical and that is fine — write both anyway so downstream consumers do not need to branch on output preference.

2. **Reify open questions as structured entities.** Aggregate every unresolved question that should carry into requirements-intake:
   - D3 questions that could not be answered from D1 evidence (those the user signalled as still-open during discussion).
   - Any contradictions or blockers accepted at D4 step 5(c) — these were already reified in D4 and are listed here only for completeness.

   For each that is not already a graph entity, call `create_entities` to create an `open_question` entity named `question-<work_item_key>-d3-<short-question-slug>` (use `d3` as the source segment for D3-origin questions; D4-origin questions already use `d4`). Required observations: `question`, `why_unanswered`, `source` (`d3_discussion` | `d4_verification`), `severity` (`high` | `medium` | `low`).

   Call `create_relations` to link each `open_question` to `work_item-discovery-<slug>` via a `contains` relation. This is the same shape that explorer-written open questions use, so requirements-intake's R4A traversal picks them up uniformly without needing to parse the `open_questions` string observation.

3. **Create the summary→work_item relation.** Call `create_relations` to add a `summarizes` relation from `discovery_summary-<slug>` to the `work_item-discovery-<slug>` node so requirements-intake can navigate from the summary to the explorer subgraph at R2.

4. **Present the chosen synthesis** once more in the chat as a standalone deliverable so the user has the full output in front of them as the workflow closes. Use the `synthesis_chosen` text — for a multiple_options run, this means the chosen-option block plus any cross-cutting constraints, NOT the full options table.

5. **Deliver the handoff message verbatim:**

   > **Discovery saved.** Your full discovery output is persisted to the knowledge graph for this Claude Code session as `discovery_summary-<slug>`, with `chosen_approach`, the chosen-approach synthesis, affected areas, verification findings, and structured `open_question` entities all reachable from the `work_item-discovery-<slug>` node.
   >
   > **Recommended next step — clear context, then run requirements-intake:**
   > 1. Run `/clear` to clear the conversation context. The knowledge graph survives `/clear`; only the conversation is reset.
   > 2. Then invoke `/requirements-intake` in the fresh conversation. Its R0 discovery pre-check will detect the `discovery_summary-<slug>` automatically and skip redundant codebase exploration at R2.
   >
   > Running requirements-intake without `/clear` will work, but it carries this conversation's context forward and is not the recommended path. The discovery entities also persist if you wait — they live until this Claude Code session ends.

6. **Do not invoke `requirements-intake` from this workflow.** Do not ask the user whether to continue into requirements-intake. The handoff is intentionally manual and gated on `/clear` so requirements-intake starts from a clean conversational baseline. End the workflow after the handoff message is delivered.

---

## Completion Criteria

This workflow is complete when **all** of the following are true:

- All 6 phases executed in sequence (D0–D5)
- All three approval gates explicitly confirmed in the chat (D0, D2, and D4)
- D2 synthesis reviewed before presentation
- D3 discussion concluded with explicit user signal to continue and a recorded chosen approach
- D4 verification round executed against the chosen approach, every verification claim classified, and outcome confirmed by the user
- `discovery_summary` entity written to the knowledge graph with all required observations, including chosen approach, user preference, verification status and findings, and open questions
- D5 handoff message delivered verbatim, instructing the user to `/clear` and then invoke `/requirements-intake` separately
- Workflow ended without invoking `requirements-intake`
