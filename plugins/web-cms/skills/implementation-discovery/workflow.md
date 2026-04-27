# IMPLEMENTATION DISCOVERY WORKFLOW — EXECUTION CONTRACT

> **How this works:** The user invokes this workflow when they want to understand how to approach building or changing something before defining formal requirements. The agent drives a short interactive session to understand the topic, explores the relevant codebase areas in parallel, then surfaces either a single recommended approach or a ranked comparison of options. The output is persisted to the session knowledge graph so requirements-intake can pick it up automatically.

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute phases in strict sequential order (D0 through D3).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure in the chat. Do not continue.
5. Every required output must be presented in the chat before the phase is considered complete.

**APPROVAL GATE BEHAVIOR:** Approval gates are chat-scoped. If explicit approval is not captured before the session ends or context is lost, stop at the gate. On resume, re-present the latest summary and ask for confirmation again. Never assume a pending approval was granted.

**CLARIFICATION RULE:** Do not assume anything. If required information is missing, ambiguous, or underspecified, stop and ask the user for clarification before proceeding.

**TOOL PREFERENCE:** Prefer native tools over Bash for filesystem work. All filesystem, search, and directory operations must stay within the current project directory.

- **File I/O (read, write, edit a known file):** Use native `Read`, `Write`, `Edit`.
- **File discovery (find files by name or pattern):** Use native `Glob`.
- **Content search (find text inside files):** Use native `Grep`. For symbolic code search, delegate to the `codebase-explorer` agent.
- **Directory operations (list, metadata, move, mkdir):** Use Bash.

---

### D0 — Intake

**Objective:** Understand what the user wants to explore and how they want the output shaped.

**Agent Actions:**

1. Briefly explain what this workflow does (parallel codebase exploration, approach surfacing, optional handoff to requirements-intake) and what to expect.

2. Ask the following questions **conversationally, one at a time.** Wait for each response before asking the next.

   - **"What are you trying to build, change, or investigate?"** — Accept any level of specificity. The user does not need to know what it's called or where it lives in the codebase.
   - **"Do you know any specific areas of the codebase that are involved — services, modules, repos, or file paths?"** — Used to seed the exploration. Accept "none" or "not sure."
   - **"Would you like a single recommended approach, or would you like to see multiple options to compare?"** — Determines the D2 output format. If the user is unsure, recommend multiple options.
   - **"Are large rewrites or significant additions to the codebase acceptable, or should I focus on targeted, minimal changes?"** — Determines how aggressive the D2 approaches can be. If "yes" / "large changes acceptable," D2 may surface options that involve substantial refactors, new modules, or replacement of existing patterns. If "no" / "targeted only," D2 must bias toward minimal-footprint approaches that extend or adapt what already exists. If the user is unsure, default to "targeted only."

3. Summarize the gathered context back to the user in a structured format.

> **REQUIRED context before proceeding:**
> - **Topic** — what the user wants to build, change, or investigate (2–4 sentences)
> - **Codebase Hints** — specific areas, or "none provided"
> - **Output Preference** — "single recommendation" or "multiple options"
> - **Change Scope** — "large changes acceptable" or "targeted only"

> **APPROVAL GATE — FULL STOP.** Present the gathered context as a structured summary. User must confirm all fields are accurate. Do not proceed to D1 until confirmed.

---

### D1 — Codebase Discovery

**Objective:** Explore the relevant codebase areas to ground the D2 synthesis in evidence.

> **USE KNOWLEDGE GRAPH:** Before spawning explorers, create a `work_item` entity with name `work_item-discovery-<topic-slug>` (slug derived from the D0 topic via the same normalization rule used elsewhere: lowercase, whitespace/punctuation/slashes → single `-`, trim, collapse). Observations: `work_type: discovery`, `topic`, `output_preference`, `change_scope`, `phase: discovery`. **Record the entity name** as the `work_item_id` for D1 and pass it to every explorer. The `discovery_summary` entity created at D4 will reference the same id so requirements-intake R0/R2 can pick up the explorer subgraph.

**Agent Actions:**

1. Derive target areas from the topic description and codebase hints from D0. Be specific — prefer concrete module paths, service names, or component boundaries over vague descriptions. If hints were provided, start there. If not, infer areas from the topic description using file discovery and content search before spawning agents.

2. Invoke a `codebase-explorer` sub-agent in **parallel** for each distinct area, providing:
   - The target area to explore
   - A discovery-scoped question: **"What code, patterns, architecture, and constraints in this area are relevant to implementing or changing [topic]? What approaches are already visible in the existing code, and what would be the natural extension points?"**
   - The `work_item_id` (`work_item-discovery-<topic-slug>`). All findings the explorer streams to the graph will be linked to this node.
   - The topic description for context

3. Wait for all explorers to return their `EXPLORATION COMPLETE` (or `EXPLORATION FAILED`) pointers.

4. Call `read_graph` and walk the subgraph rooted at each `exploration` entity for this `work_item_id`. Surface any `open_question` entities. If any identifies a connection to another area not yet explored, dispatch a follow-up `codebase-explorer` (passing the same `work_item_id`) before proceeding.

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

> **APPROVAL GATE — FULL STOP.** Present the full D2 synthesis. User must confirm it accurately reflects what they want to explore and that the affected areas and approach(es) look correct. Do not proceed to D3 until confirmed.

---

### D3 — Discussion

**Objective:** Give the user space to ask questions, push back, or express preferences about the discovery output before it is persisted and acted on.

**Agent Actions:**

1. Open the conversation: **"Do you have any questions or thoughts about any of the options? I'm happy to go deeper on any area, compare trade-offs further, or talk through concerns."**

2. Engage in free-form conversation with the user. This phase has no fixed structure — follow the user's lead. Guidelines:
   - **If the user asks a clarifying question:** answer it using evidence from the D1 findings. Do not speculate beyond what was explored. If a question cannot be answered from D1 evidence, say so explicitly and note it as an open question.
   - **If the user pushes back on an option:** engage honestly. If the pushback reveals a constraint or signal that would change the recommendation, acknowledge it and explain how it affects the analysis.
   - **If the user states a preference** (e.g., "I'm leaning toward Option 2"): acknowledge it and note it — it will be recorded in the knowledge graph in D4 so requirements-intake has full context.
   - **If the user asks to see an additional option** not already presented: evaluate whether D1 evidence supports it. If yes, synthesize it using the same format from D2. If no, explain why the evidence doesn't support it.

3. Continue the conversation for as many turns as the user needs. Do not rush toward the next phase.

4. When the user signals they are done (e.g., "no, I'm good", "let's continue", "that answers it"), confirm any stated preferences back to the user before proceeding: "Got it — I'll note [preference / concern / open question] when I save the discovery output. Ready to move on?"

> **There is no approval gate for this phase.** The user exits by signaling readiness. Do not proceed to D4 until the user has explicitly indicated they are done with discussion.

---

### D4 — Persist and Handoff

**Objective:** Write the confirmed discovery output to the knowledge graph and optionally continue into requirements-intake.

**Agent Actions:**

1. Write the confirmed discovery output to the knowledge graph. Create a `discovery_summary` entity with the following observations:
   - `topic: [the user's topic description from D0]`
   - `work_item_id: [the work_item-discovery-<slug> entity name created in D1]`
   - `codebase_hints: [hints from D0, or "none"]`
   - `output_preference: [single_recommendation | multiple_options]`
   - `change_scope: [large_changes_acceptable | targeted_only]`
   - `affected_areas: [comma-separated list of discovered area paths from D2]`
   - `synthesis: [the full confirmed D2 synthesis text]`
   - `approach_count: [1 for single recommendation, or the number of options presented]`
   - `user_preference: [any preference or lean expressed by the user in D3, or "none stated"]`
   - `open_questions: [any questions from D3 that could not be answered from D1 evidence, or "none"]`

   Then create a `summarizes` relation from the `discovery_summary` entity to the `work_item-discovery-<slug>` node so requirements-intake can navigate from the summary to the explorer subgraph at R2.

2. Ask: **"Would you like to continue into requirements-intake now? The discovery output will be pre-loaded so you won't need to re-describe the codebase areas or wait for exploration to run again."**

3. **If yes:** invoke `requirements-intake` via the `Skill` tool. Requirements-intake will detect the `discovery_summary` entity in the knowledge graph at its R0 phase and use it to pre-populate codebase context, skipping redundant exploration at R2.

4. **If no:** inform the user: "Your discovery output is saved for this session. If you run `/requirements-intake` later, it will detect and use this context automatically." Present the discovery synthesis once more as a standalone deliverable.

---

## Completion Criteria

This workflow is complete when **all** of the following are true:

- All 5 phases executed in sequence (D0–D4)
- Both approval gates explicitly confirmed in the chat (D0 and D2)
- D2 synthesis reviewed before presentation
- D3 discussion concluded with explicit user signal to continue
- `discovery_summary` entity written to the knowledge graph with all required observations, including user preference and open questions from D3
- User informed of next steps (proceeded to requirements-intake, or standalone delivery)
