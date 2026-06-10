# IMPLEMENTATION DISCOVERY WORKFLOW — EXECUTION CONTRACT

> **How this works:** The user invokes this workflow when they want to understand how to approach building or changing something before defining formal requirements. The agent drives a short interactive session to understand the topic, explores the relevant codebase areas in parallel, surfaces either a single recommended approach or a ranked comparison of options, then runs a focused verification round against the user's chosen approach to confirm findings hold and surface anything missed. The full discovery output is persisted to a per-topic file-memory directory and the workflow ends. To run requirements-intake on the discovery, the user clears conversation context with `/clear` and then invokes `/requirements-intake` in a fresh conversation — the files survive the clear, so requirements-intake's R0 discovery pre-check picks the output up automatically. This workflow does not chain into requirements-intake itself.

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute phases in strict sequential order (D0 through D5).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure in the chat. Do not continue.
5. Every required output must be presented in the chat before the phase is considered complete.

**APPROVAL GATE BEHAVIOR:** Approval gates are chat-scoped. If explicit approval is not captured before the session ends or context is lost, stop at the gate. On resume, re-present the latest summary and ask for confirmation again. Never assume a pending approval was granted.

**FILE MEMORY SCOPE — INTENTIONAL PERSISTENCE:** Unlike other workflows, this one does NOT clean up its file memory at the end. The discovery directory `<…>/web-cms-memory/discovery-<topic-slug>/` — `work-item.md` (the discovery root), the explorer files under `explorations/` (D1) and the verification files `explorations/<area-slug>-verification.md` (D4), and `summary.md` written at D5 — is deliberately left in place so a follow-on `requirements-intake` run can pick it up at R0/R2 without re-exploring the codebase. It persists across `/clear` (which only clears conversation context, not files on disk), so the recommended handoff is: this workflow finishes, the user runs `/clear`, then invokes `/requirements-intake` in a fresh conversation. Cleanup ownership transfers to `requirements-intake`: its terminal R6 cleanup removes the `discovery-<slug>/` directory along with its own. If the user never runs `/requirements-intake`, the directory remains on disk until manually removed. Compute the directory path with the recipe in `file-memory-protocol.md` §1 (`<work-item-key> = discovery-<topic-slug>`).

**FILE-AUTHORITATIVE CONTRACT FOR FINDINGS:** Within the discovery output, the exploration files (`explorations/*.md` — their `evidence`, `patterns`, `integration_points`, `risks`, `open_questions` entries) are the canonical record of *what was found*. The `## Synthesis (chosen)` text in `summary.md` (written at D5) is the human-readable summary of that record at persistence time; it is intended for direct insertion into the Jira issue description by downstream consumers. When D4 changes a finding (revises, contradicts, marks an entry superseded), it MUST update the underlying exploration entries at the same time it updates the synthesis text — the two views must agree at D5 persistence. Downstream consumers (notably `requirements-intake` R2) treat the exploration files as the structured truth: they skip entries/files marked `superseded: true` when reading, and prefer exploration evidence over synthesis text if a conflict ever surfaces.

**CLARIFICATION RULE:** Do not assume anything. If required information is missing, ambiguous, or underspecified, stop and use `AskUserQuestion` to ask the user for clarification before proceeding.

**TOOL PREFERENCE:** Prefer native tools over Bash for filesystem work. All filesystem, search, and directory operations must stay within the current project directory.

- **File I/O (read, write, edit a known file):** Use native `Read`, `Write`, `Edit`.
- **File discovery (find files by name or pattern):** Use native `Glob`.
- **Content search (find text inside files):** Use native `Grep`. For symbolic code search, delegate to the `codebase-explorer` agent.
- **Directory operations (list, metadata, move, mkdir):** Use Bash (`ls`, `stat`, `mv`, `mkdir -p`).
- **Git:** Use Bash for all git operations (`git status`, `git diff`, `git log`, `git push`, `git pull`, `git merge`, `git remote`, `git stash`, `git rebase`, etc.) and for running build, test, and lint commands.

**SERENA PROJECT ACTIVATION:** Before D0, check Serena's project-activation message (emitted on connect via `--project-from-cwd`); if it reports that onboarding has not been performed, call `onboarding` to scope Serena's language server to the current project directory. Serena's symbol tools (`find_symbol`, `find_referencing_symbols`, `get_symbols_overview`, `search_for_pattern`) and any symbol-aware operations invoked by the `codebase-explorer` agent depend on this being done. Do this once at the start of the workflow; do not repeat it between phases.

**TASK TRACKING:** Always use task tracking (`TaskCreate`/`TaskUpdate`) so progress is visible throughout. Create one task per phase at the start of the workflow. Mark each task `in_progress` when starting the phase and `completed` when the phase is done:

- D0 — Intake
- D1 — Codebase Discovery
- D2 — Synthesis
- D3 — Discussion
- D4 — Verification Round
- D5 — Persist and Handoff

**CHECKPOINT & COMPACTION CONTRACT:** This workflow records position in a single `$MEM/checkpoint.md` file (full schema and contract in `file-memory-protocol.md` §4), where `$MEM` is the discovery directory.

**Per-phase checkpoint — after EVERY phase (D0–D5), automatically, with no chat output and no `/compact` prompt.** Atomically overwrite `$MEM/checkpoint.md` (`Write` to `checkpoint.md.tmp`, then `mv` over `checkpoint.md`) with `checkpoint_type: phase`, the just-completed `phase`, the upcoming `next_phase`, the `references` list, `## Decisions`, and `## Open items`. (The first checkpoint is written after D1 creates `$MEM`.)

**Compaction gates (D2, D4) — additionally prompt the user to `/compact`.** Do the per-phase write but with `checkpoint_type: gate`, then: (1) wait for any background `area-mapper` to finish; (2) emit the Phase Summary block (§4(b)) — phase + skill, topic slug, one-line decisions, verbatim approval condition, `next_phase`, the checkpoint file path, and the resume contract; (3) end the turn with the literal line **"Run `/compact` now, then type `continue` to resume."** Do NOT call `AskUserQuestion` at a gate.

**Universal resume rule — on ANY resume, before doing anything else:** `Read $MEM/checkpoint.md` → `Read` every file in its `references` (`summary.md`, `explorations/*.md`, `work-item.md`) → **re-read the `next_phase` section of this `workflow.md`** (any phase asking clarifying/structured questions MUST use `AskUserQuestion`) → continue at `next_phase`. If `$MEM` is absent, restart the affected phase from prior chat. Approval gates stay chat-scoped — never assume a pending approval was granted.

**Note on cleanup:** This workflow intentionally leaves its directory intact for requirements-intake to consume. There are no separate handoff entities to reap — the single `checkpoint.md` is removed with the directory by requirements-intake R6 (which sweeps all upstream implementation-discovery state) or by issue-intake I6 (bug path). If neither follow-on workflow runs, the directory persists until manually removed.

---

### D0 — Intake

**Objective:** Understand what the user wants to explore and how they want the output shaped.

**Agent Actions:**

1. Briefly explain what this workflow does (parallel codebase exploration, approach surfacing, focused verification round, persistence to a discovery file-memory directory) and what to expect. Mention that requirements-intake is a separate next step the user runs after `/clear` — this workflow does not chain into it.

2. Gather context in this order:

   **a. Goal category (via `AskUserQuestion`):** Use `AskUserQuestion` (Header: `Discovery Goal`, Question: `What are you trying to build, change, or investigate?`, Options: `Build something new` — a new feature or capability the codebase doesn't currently support, `Change existing behavior` — modifying, improving, or fixing something that already exists, `Investigate / research` — exploring options or understanding the codebase before deciding).

   **b. Topic elaboration — ask conversationally, not via `AskUserQuestion`.**  
   The `AskUserQuestion` free-text field is cramped; a conversational prompt gives the user the full prompt input to write as much as they need. Send this message, then **end your turn and wait** for the user's reply:

   *"Now tell me more about what you want to explore. Share as much or as little as you know — the goal, the problem being solved, any specific behavior or code you have in mind, and any constraints or context that would help scope the investigation. It's fine if you're not sure of the details yet; the exploration phase will fill in the gaps."*

   **c. Soft sufficiency check.** If the topic is so vague that no useful exploration area can be inferred (e.g., a single word with no context), ask one clarifying question to get enough signal to scope the exploration. If the topic is deliberately open-ended or exploratory, proceed — discovery is designed to work with incomplete information.

   **d. Remaining structured questions (via `AskUserQuestion`, one call each):**
   - **Codebase areas:** Use `AskUserQuestion` (Header: `Codebase Hints`, Question: `Do you know any specific areas of the codebase that are involved — services, modules, repos, or file paths?`, Options: `Yes, I'll name them` — type the areas using the Other input field, `No / Not sure` — proceed without hints; the agent will infer areas from the topic). Accept "none" or "not sure."
   - **Output preference:** Use `AskUserQuestion` (Header: `Output Format`, Question: `Would you like a single recommended approach, or multiple options to compare?`, Options: `Multiple options (Recommended)` — see 2–4 distinct approaches with trade-offs and a recommendation signal, `Single recommendation` — see one recommended approach with rationale). If the user is unsure, the Recommended option applies.
   - **Change scope:** Use `AskUserQuestion` (Header: `Change Scope`, Question: `Are large rewrites or significant additions to the codebase acceptable, or should I focus on targeted, minimal changes?`, Options: `Targeted only (Recommended)` — bias toward minimal-footprint approaches that extend or adapt what already exists, `Large changes acceptable` — the option space is open; significant refactors, new modules, or pattern replacement may be considered). If the user is unsure, the Recommended option applies.

3. Summarize the gathered context back to the user in a structured format.

> **REQUIRED context before proceeding:**
> - **Topic** — what the user wants to build, change, or investigate (capture in full — do not summarize or truncate the user's input)
> - **Codebase Hints** — specific areas, or "none provided"
> - **Output Preference** — "single recommendation" or "multiple options"
> - **Change Scope** — "large changes acceptable" or "targeted only"

> **APPROVAL GATE — FULL STOP.** Present the gathered context as a structured summary. Use `AskUserQuestion` (Header: `D0 Approval`, Question: `Does the context summary above accurately capture what you want to explore?`, Options: `Approve and proceed (Recommended)` — all fields are accurate, `Request changes` — some fields need correction). Do not proceed to D1 until the user approves.

---

### D1 — Codebase Discovery

**Objective:** Explore the relevant codebase areas to ground the D2 synthesis in evidence.

> **BOOTSTRAP FILE MEMORY:** Before spawning explorers, derive `<topic-slug>` from the D0 topic (lowercase, whitespace/punctuation/slashes → single `-`, trim, collapse) and compute `MEM` (recipe §1) with `<work-item-key> = discovery-<topic-slug>`. `mkdir -p "$MEM/explorations"` and `Write $MEM/work-item.md` (schema §3.1) with `work_type: discovery`, `jira_key: null`, `title: <topic>`, `status: in_progress`, `phase: D1`, `skill: implementation-discovery`, and the topic, output preference, and change scope under `## Description`. Pass the `MEM` path (as `memory_dir`) and a normalized `area_slug` to every explorer. The `summary.md` written at D5 lives in this same directory so requirements-intake R0/R2 can pick up the explorations.

**Agent Actions:**

1. Derive target areas from the topic description and codebase hints from D0. Be specific — prefer concrete module paths, service names, or component boundaries over vague descriptions. If hints were provided, start there. If not, infer areas from the topic description using file discovery and content search before spawning agents.

2. Invoke a `codebase-explorer` sub-agent in **parallel** for each distinct area, providing:
   - The target area to explore
   - A discovery-scoped question: **"What code, patterns, architecture, and constraints in this area are relevant to implementing or changing [topic]? What approaches are already visible in the existing code, and what would be the natural extension points?"**
   - The `memory_dir` (`$MEM`) and a normalized `area_slug`. The explorer writes its findings to `$MEM/explorations/<area_slug>.md`.
   - The topic description for context

3. Wait for all explorers to return. Each non-failed return contains a `File:` line with the exploration file name. `INCOMPLETE` means partial findings are present; consider re-spawning for the same area if coverage matters. `FAILED` means no file was written — re-spawn that explorer before proceeding.

> **POST-EXPLORATION ENRICHMENT:** Spawn the `area-mapper` sub-agent **in the background** (`run_in_background: true`) with the same `memory_dir` (`$MEM`). The mapper crystallizes durable area knowledge from this run's exploration files into Serena project memory for future explorations. Do not wait for it — proceed immediately to step 4.

4. `Read` each `$MEM/explorations/<area_slug>.md` from the returns. If any file is missing or empty, re-spawn that explorer rather than treating missing data as confirmed. Surface any `open_questions` entries. If any identifies a connection to another area not yet explored, dispatch a follow-up `codebase-explorer` (passing the same `memory_dir`) before proceeding.

5. Review the assembled exploration files for consistency. Note any conflicting signals across areas before moving to synthesis — for example, two explorations' `patterns` that contradict each other, or `risks` that flag the same area at different severities.

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

4. > **GENERATE A FLOWGRAPH (best-effort):** For each approach in the synthesis, produce a Mermaid `flowchart` that shows how that approach works — data/control flow through the affected components, with nodes mapped to real files/functions from the D1 findings. For a single-recommendation run, produce one diagram. For a multiple-options run, produce one per presented approach.
   >
   > - **Skip it** for trivial single-component changes or when the approach is purely procedural with no meaningful branching. If skipped, state in one line why.
   > - **Render each diagram in the chat** inline with the corresponding approach block in the synthesis presentation.
   > - **There is no Jira description to update at this phase.** The diagram is persisted to `summary.md` at D5 (a `diagram` frontmatter field holding the raw Mermaid source for the chosen approach, or for a multiple-options run a JSON object keyed by approach name) so requirements-intake's R4D step can read and reuse it.

5. > **REQUIRED: Review the synthesis before presenting.** Verify every claim is grounded in D1 evidence. Remove or revise any that are not. Label remaining inferences explicitly. Do not present an unreviewed synthesis.

> **APPROVAL GATE — FULL STOP.** Present the full D2 synthesis. Use `AskUserQuestion` (Header: `D2 Approval`, Question: `Does this synthesis accurately reflect what you want to explore? Are the affected areas and approach(es) correct?`, Options: `Approve and proceed (Recommended)` — the synthesis looks correct, `Request changes` — something needs revision). Do not proceed to D3 until the user approves.

> **COMPACTION GATE — D2:** Once D2 approval is confirmed, follow the Checkpoint & Compaction Contract above (gate path). Write `checkpoint.md` with `phase: D2`, `next_phase: D3`, `checkpoint_type: gate`, `references: [work-item.md, explorations/*.md]`; `## Decisions`: synthesis approach count and recommended option (if any); chosen approach (once selected in D3 — record "pending D3" if not yet). Emit the Phase Summary block and instruct the user to run `/compact` before proceeding to D3.

---

### D3 — Discussion

**Objective:** Give the user space to ask questions, push back, or express preferences about the discovery output before it is persisted and acted on.

**Agent Actions:**

1. Open the conversation: **"Do you have any questions or thoughts about any of the options? I'm happy to go deeper on any area, compare trade-offs further, or talk through concerns."**

2. Engage in free-form conversation with the user. This phase has no fixed structure — follow the user's lead. Guidelines:
   - **If the user asks a clarifying question:** answer it using evidence from the D1 findings. Do not speculate beyond what was explored. If a question cannot be answered from D1 evidence, say so explicitly and note it as an open question.
   - **If the user pushes back on an option:** engage honestly. If the pushback reveals a constraint or signal that would change the recommendation, acknowledge it and explain how it affects the analysis.
   - **If the user states a preference** (e.g., "I'm leaning toward Option 2"): acknowledge it and note it — it will be recorded in `summary.md` in D5 so requirements-intake has full context, and it scopes the D4 verification round.
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
   - The same `memory_dir` (`$MEM`) so verification files join the same discovery directory.
   - **A distinct `area_slug` with a `-verification` suffix** (e.g. `payment-core-verification`) so the explorer writes `$MEM/explorations/<area-slug>-verification.md` — a separate file that never overwrites the D1 exploration of the same area. This is how first-round and verification-round findings stay distinguishable on disk; without the suffix a verification explorer would clobber the D1 file.
   - A verification-scoped question: **"For the chosen approach `[approach name]`, verify the following specific claims and surface anything missed: [bulleted claim list for this area]. For each claim, return one of confirmed / contradicted / partially confirmed with the supporting evidence. Then look for missing dependencies, integration points, risks, or blockers that prior exploration did not capture."**
   - The chosen approach name and the relevant excerpt of the D2 synthesis for context.
   - An instruction to set `round: verification` and `verifies_approach: [approach name]` in the new exploration file's frontmatter, so D5 can distinguish first-round and verification-round findings.

3. Wait for all verification explorers to return. Each non-failed return contains a `File:` line with the exploration file name. If any return `INCOMPLETE` and the gap is on a high-priority verification claim, re-spawn for that area before reconciling. `FAILED` means no file was written — re-spawn before reconciling.

> **USE SEQUENTIAL THINKING:** Before reconciling, invoke the `sequentialthinking` tool. Use it to classify each verification claim (Confirmed / Enriched / Contradicted / New blocker) before writing any conclusion to the files, reason through whether any "Contradicted" finding changes the feasibility of the chosen approach or only adjusts its scope, and decide whether any "New blocker" should trigger a re-open of the synthesis (D3 re-entry) versus being accepted as an open question. This is the most consequential decision point in D4 — a shallow reconciliation that marks everything "Confirmed" because the verification explorer did not find an explicit contradiction is a false clean result that misleads requirements-intake. Do not begin the reconciliation step until the reasoning is complete.

> **THINK HARD:** Before deciding the outcome of the reconciliation, think hard about whether a "material change" threshold is met — specifically, whether any Contradicted or New Blocker finding changes the viability or effort of the chosen approach, or only adds nuance. A false "clean" verdict here causes requirements-intake to inherit a plan whose key assumptions have not been verified.

4. **Reconcile.** `Read` each verification exploration file (`$MEM/explorations/*-verification.md`). For each verification claim, classify the outcome:
   - **Confirmed** — verification evidence supports the claim. No action needed.
   - **Enriched** — the claim is correct but the verification round added new evidence (additional callers, edge-case handling, related files). Note for the synthesis update.
   - **Contradicted** — verification evidence shows the claim is wrong. Identify what specifically was wrong and why.
   - **New blocker** — verification surfaced a dependency, risk, or constraint that D1 missed and that materially affects the chosen approach (e.g., the extension point doesn't exist, an integration is owned by another service, a pattern the approach assumed is being deprecated).

   **Mark contradicted findings in the D1 exploration files as part of reconciliation.** Per the file-authoritative contract, every D1 finding entry that this verification round contradicts MUST be tagged immediately, before deciding the outcome in step 5. For each contradicted entry in its D1 `$MEM/explorations/<area-slug>.md` (an `evidence`, `patterns`, `integration_points`, `risks`, or `affected_files` entry whose role/relevance is wrong), `Edit` that entry to add:
   - `superseded: true`
   - `superseded_at: D4`
   - `superseded_reason: <one-sentence explanation>`
   - `superseded_by: <the verification file / entry that supplies the corrected evidence, if any — otherwise "see verification_findings">`

   This applies regardless of which outcome the user chooses in step 5 — once verification has contradicted a finding, it is no longer canonical, and downstream readers must be able to skip it.

5. **Decide the outcome.**
   - **Clean (only Confirmed and Enriched):** present a short verification report — "Verification complete. Confirmed: …. New context: …." — then proceed to D5. Update the synthesis text with the enriched evidence before persistence.
   - **Material change (any Contradicted or New blocker):** present the finding to the user with the supporting evidence. Use `AskUserQuestion` (Header: `Material Change`, Question: `This changes the picture for [approach]. How would you like to proceed?`, Options: `Revise this approach and continue (Recommended)` — update the synthesis with the new evidence and proceed, `Re-open synthesis` — loop back to D2 to consider another option with the new evidence in scope, `Accept and proceed` — record the contradiction or blocker as an open question and proceed without revising the synthesis).
     - **(a) Revise:** update the D2 synthesis text inline to reflect the new evidence (revised affected areas, risks, effort, or constraints). The verification-round exploration files written in step 2 already carry the corrected evidence; the contradicted D1 entries have already been marked `superseded: true` in step 4. The synthesis text update is the human-readable view that brings the synthesis back into sync with the files. Present the revised synthesis to the user for confirmation, then proceed.
     - **(b) Re-open synthesis:** loop back to D2 with the verification findings as additional input. Re-run D2 → D3 → D4 with the new evidence in scope. The original discovery directory and exploration files stay; this is iteration on the same discovery. (Contradicted entries remain `superseded: true` from step 4 — this carries forward through the re-opened synthesis.)
     - **(c) Accept and proceed:** record the contradiction or blocker as an open question and proceed without revising the synthesis. Specifically:
        - Add a structured open question for each accepted contradiction or blocker as an `open_questions` entry in the relevant verification exploration file: `question` (the unresolved blocker, phrased as a question), `why_unanswered` (why D4 surfaced it), `source: d4_verification`, `severity` (`high` for blockers, `medium` for contradictions, `low` for soft conflicts). This keeps it reachable when downstream readers scan `explorations/*.md`.
        - Append a one-line summary of each to `summary.md`'s `## Open questions` at D5 step 1 (the human-readable index; the exploration-file entries are the canonical record).

6. **Refresh durable memory.** Spawn the `area-mapper` sub-agent **in the background** (`run_in_background: true`) one more time with the same `memory_dir` (`$MEM`) so its Serena memory crystallization reflects the verified picture. Do not wait for it.

> **APPROVAL GATE — FULL STOP.** Present the verification report (and the revised synthesis, if revision happened in step 5). Use `AskUserQuestion` (Header: `D4 Approval`, Question: `Does the verification report (and any revisions) look correct? Ready to save the discovery output?`, Options: `Approve and proceed (Recommended)` — the verification outcome and any revisions are correct, `Request changes` — something needs revision). Do not proceed to D5 until the user approves.

> **COMPACTION GATE — D4:** Once D4 approval is confirmed, follow the Checkpoint & Compaction Contract above (gate path). Write `checkpoint.md` with `phase: D4`, `next_phase: D5`, `checkpoint_type: gate`, `references: [explorations/*.md, work-item.md]`; `## Decisions`: verification outcome (clean / revised / accepted-with-open-questions), approach confirmed or revised. Emit the Phase Summary block and instruct the user to run `/compact` before proceeding to D5.

> **REQUIRED before proceeding:**
> - Chosen approach is recorded
> - Verification claim list assembled and shown to user
> - All verification explorers returned (with re-spawns for any high-priority `INCOMPLETE`)
> - Reconciliation completed: every verification claim classified
> - User confirmed the outcome (clean proceed / revised proceed / accept-as-open-question proceed) or directed a re-open of synthesis

---

### D5 — Persist and Handoff

**Objective:** Write the confirmed and verified discovery output to `summary.md`, deliver the standalone synthesis to the user, and instruct them on the clean handoff to requirements-intake. This workflow does not invoke requirements-intake itself.

**Agent Actions:**

1. **Write `summary.md`.** `Write $MEM/summary.md` (schema §3.9, `summary_type: discovery`) with frontmatter:
   - `topic_slug: <slug>` and `topic: <the user's topic description from D0>`
   - `codebase_hints: <hints from D0, or "none">`
   - `output_preference: <single_recommendation | multiple_options>`
   - `change_scope: <large_changes_acceptable | targeted_only>`
   - `chosen_approach: <name of the approach the user selected in D3>`
   - `approach_count: <1 for single recommendation, or the number of options presented>`
   - `affected_areas: [list of discovered area paths for the chosen approach, updated with verification additions and pruned of areas that only mattered to non-chosen options]`
   - `verification_status: <clean | revised | accepted_with_open_questions>`
   - `verification_findings: <one-line-per-claim summary: confirmed / enriched / contradicted / new-blocker, with file references for non-confirmed items; contradicted items name the superseded `explorations/*.md` entry>`
   - `user_preference: <any preference or lean expressed by the user in D3, or "none stated">`
   - `diagram: <Mermaid source for the chosen approach's flowchart from D2, or for a multiple-options run a JSON object keyed by approach name. Omit if the flowgraph was skipped in D2 — requirements-intake will generate its own.>`
   - `discovery_confirmed: false` (a follow-on requirements-intake / issue-intake sets this to `true` when the user confirms reuse)

   And body:
   - `## Synthesis (chosen)` — the synthesis text scoped to the chosen approach. For a single_recommendation run this is the full synthesis; for a multiple_options run this is ONLY the chosen option's block plus any cross-option constraints that still apply, with non-chosen options removed. This is what downstream consumers insert into the Jira description.
   - `## Synthesis (full, record only)` — the complete confirmed synthesis including all options (multiple_options run), retained for record only. Downstream consumers must NOT use this as the analysis content.
   - `## Open questions` — one line per open question (see step 2).

   For a `single_recommendation` run, the two synthesis sections are normally identical; that is fine.

2. **Record open questions.** Aggregate every unresolved question that should carry into requirements-intake:
   - D3 questions that could not be answered from D1 evidence (those the user signalled as still-open during discussion).
   - Any contradictions or blockers accepted at D4 step 5(c) — already added to a verification exploration file's `open_questions`, listed here for completeness.

   Ensure each is captured BOTH as an `open_questions` entry in an `explorations/*.md` file (the canonical, structured record that requirements-intake R2/R4 reads) AND as a one-line entry under `summary.md`'s `## Open questions` (the human-readable index). For a D3-origin question with no natural exploration file, add it to the most relevant exploration file's `open_questions` array. Each carries `source` (`d3_discussion` | `d4_verification`) and `severity` (`high` | `medium` | `low`).

3. **No cross-file links are needed.** `summary.md`, `work-item.md`, and `explorations/*.md` all live in the same `discovery-<slug>/` directory, so requirements-intake navigates from the summary to the explorations by listing that directory — there is nothing to wire up.

4. **Present the chosen synthesis** once more in the chat as a standalone deliverable so the user has the full output in front of them as the workflow closes. Use the `## Synthesis (chosen)` text from `summary.md` — for a multiple_options run, this means the chosen-option block plus any cross-cutting constraints, NOT the full options table.

5. **Deliver the handoff message verbatim:**

   > **Discovery saved.** Your full discovery output is persisted to `web-cms-memory/discovery-<slug>/` for this project — `summary.md` (chosen approach, the chosen-approach synthesis, affected areas, verification findings, and open questions) alongside the `work-item.md` root and the `explorations/*.md` files.
   >
   > **Recommended next step — clear context, then run requirements-intake:**
   > 1. Run `/clear` to clear the conversation context. The files survive `/clear`; only the conversation is reset.
   > 2. Then invoke `/requirements-intake` in the fresh conversation. Its R0 discovery pre-check will detect `discovery-<slug>/summary.md` automatically and skip redundant codebase exploration at R2.
   >
   > Running requirements-intake without `/clear` will work, but it carries this conversation's context forward and is not the recommended path. The discovery directory also persists if you wait — it lives on disk until requirements-intake's R6 cleanup removes it (or you remove it manually).

6. **Do not invoke `requirements-intake` from this workflow.** Do not ask the user whether to continue into requirements-intake. The handoff is intentionally manual and gated on `/clear` so requirements-intake starts from a clean conversational baseline. End the workflow after the handoff message is delivered.

---

## Completion Criteria

This workflow is complete when **all** of the following are true:

- All 6 phases executed in sequence (D0–D5)
- All three approval gates explicitly confirmed in the chat (D0, D2, and D4)
- D2 synthesis reviewed before presentation
- D3 discussion concluded with explicit user signal to continue and a recorded chosen approach
- D4 verification round executed against the chosen approach, every verification claim classified, and outcome confirmed by the user
- `summary.md` written with all required fields, including chosen approach, user preference, verification status and findings, and open questions
- D5 handoff message delivered verbatim, instructing the user to `/clear` and then invoke `/requirements-intake` separately
- Workflow ended without invoking `requirements-intake`
