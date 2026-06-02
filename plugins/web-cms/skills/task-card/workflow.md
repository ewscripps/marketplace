# TASK CARD WORKFLOW — EXECUTION CONTRACT

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute phases in strict sequential order (T0 through T13).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure as a comment on this Jira issue. Do not continue.
5. Every required output (comments, plans, summaries) must be posted before the phase is considered complete.

**APPROVAL GATE BEHAVIOR:** Approval gates are chat-scoped. If explicit approval is not captured before the session ends or context is lost, stop at the gate. On resume, re-present the latest plan or testing handoff and ask for confirmation again. Never assume a pending approval was granted.

**KNOWLEDGE GRAPH SCOPE:** The knowledge graph in this workflow is session-scoped and used to track work-item state (affected areas, exploration findings, plan, implementation progress). If this workflow is resumed in a new session and the graph is empty, reconstruct state by reading the Jira issue description and all comments posted in prior phases before continuing.

**CLARIFICATION RULE:** Do not assume anything. If required information is missing, ambiguous, conflicting, or underspecified, stop and use `AskUserQuestion` to ask the user for clarification before proceeding.

**SERENA PROJECT ACTIVATION:** Before T0, check Serena's project-activation message (emitted on connect via `--project-from-cwd`); if it reports that onboarding has not been performed, call `onboarding` to scope Serena's language server to the current project directory. Serena's symbol tools (`find_symbol`, `find_referencing_symbols`, `get_symbols_overview`, `search_for_pattern`, and the symbol-aware write tools) will not function correctly without this. Do this once at the start of the workflow; do not repeat it between phases.

**TOOL PREFERENCE:** Prefer native tools over Bash for filesystem work. All filesystem, search, and directory operations must stay within the current project directory.

- **File I/O (read files, write new files, edit non-symbol regions):** Use native `Read`, `Write`, `Edit`.
- **Symbol-aware code edits (methods, classes, functions in existing source files):** Prefer Serena's `replace_symbol_body`, `insert_after_symbol`, `insert_before_symbol`, `rename_symbol`, and `safe_delete_symbol` over native `Edit` when the target is a named code symbol. See the Serena-first editing rule in T8 for the full decision rubric.
- **File discovery (find files by name or pattern):** Use native `Glob`.
- **Content search (find text inside files):** Use native `Grep`. For symbolic code navigation during implementation (locating a method, class, or caller before editing), use Serena's `find_symbol`, `find_referencing_symbols`, `get_symbols_overview`, and `search_for_pattern` directly. For broader codebase analysis that informs planning (architectural patterns, convention discovery, cross-area impact), delegate to the `codebase-explorer` agent.
- **Directory operations (list, metadata, move, mkdir):** Use Bash (`ls`, `stat`, `mv`, `mkdir -p`).
- **Git:** Use Bash for all git operations (`git status`, `git diff`, `git log`, `git push`, `git pull`, `git merge`, `git remote`, `git stash`, `git rebase`, etc.) and for running build, test, and lint commands.

**JIRA COMMENT CONTRACT:** Keep Jira comments minimal, structured, and durable. Do not narrate every phase. Routine Jira comments are required only at:

- **T4/T5** -- one combined comment containing the reviewed implementation plan and the approval request
- **T10** — user testing handoff in standard mode only
- **T12** -- final structured summary

Additional Jira comments are allowed only for blocking failures, reposting a revised plan after requested changes, or explicit user-requested status updates. Do not post separate narration comments for T0, T1, T2, T3, T6, T7, T8, T9, T11, or T13.

When a Jira comment heading references workflow phases, use the exact phase label defined here. Do not invent synthetic phase ranges such as `T2-T5` or `T6-T10`. The only routine combined phase heading allowed is `T4/T5` because one comment serves both phases.

**Comment formatting:** Pass clean GitHub-flavored markdown to `jira_add_comment`. Never backslash-escape markdown characters — bold is literal `**text**`, never `\*\*text\*\*`. Ensure every bold span has matching `**` delimiters on both sides.

**Comment reviewer gate:** Every `jira_add_comment` call in this workflow (T4/T5, T10, T12) is gated by an `**Independent comment review:**` block, following the same pattern as `plan-reviewer` and `implementation-reviewer`. The `comment-reviewer` sub-agent must return APPROVED (or the 3-iteration cap must be reached) before `jira_add_comment` is called. There are no exceptions.

**COMMIT, PUSH, MERGE & TRANSITION DISCIPLINE — HARD RULE:** Every one of the following is an irreversible action that affects shared state. None may run until the user has explicitly selected the "Approve" option at the T10 User Testing gate **in this same session**:

- `git add` / `git commit` on the working branch
- `git push` of the working branch
- `git merge` into any integration or shared branch
- `git push` of an integration branch
- Any Jira transition that moves the issue out of "In Progress" (e.g. to "In Review", "Done", "Closed")

A passing build, passing tests, clean self-review, or successful reviewer sub-agent do NOT substitute for user testing approval. **Auto Mode does not lift this rule.** Auto Mode's "bias toward working without stopping" applies to implementation decisions and tool usage — not to workflow approval gates or irreversible shared-state actions. If you cannot quote the user's verbatim T10 approval selection from earlier in this same conversation, STOP and return to T10.

These actions must not be chained. Run each one at a time, reporting the result in the chat before starting the next. Do not pre-batch commit + push + merge + push + transition in a single tool sequence.

> **EPIC CHILD TASK MODE — DETECTION IS EXPLICIT, NOT INFERRED.** This mode is active *only* when the Jira Task Details contain a populated **Epic Integration Branch** field. Do not infer epic child mode from the current git branch name, from a parent-link relationship in Jira, from sibling tasks, or from any other signal. Before treating a task as an epic child:
>
> 1. Show the user the exact `Epic Integration Branch` value you read from Task Details.
> 2. Use `AskUserQuestion` with header `Epic Child Mode`, options: `Confirm — run as epic child task (Recommended)` (description: "T6 will verify the integration branch, T10 user testing is deferred to E9, T11 merges into the integration branch") / `No — run as standard task` (description: "Full T10 user testing gate applies before any commit").
> 3. Only after the user selects "Confirm" do the epic mode behaviors below take effect.
>
> If the field is absent but you suspect this is an epic child task, ask the user — do not act on the suspicion. Skipping T10 user testing without an explicit, in-session confirmation that epic child mode is in effect is a workflow violation regardless of Auto Mode.
>
> Three phases behave differently once epic child mode is confirmed:
>
> - **T6:** Verify you are on a branch created from the Epic Integration Branch, rather than asking which base branch to use.
> - **T10:** Skip User Testing — user testing for the epic is handled at the epic level (E9). Proceed directly to T11.
> - **T11:** After committing and pushing the working branch, merge it into the Epic Integration Branch. Run the full build, all tests, and all linters on the integration branch before pushing the integration branch.


**TASK TRACKING:** Always use task tracking (`TaskCreate`/`TaskUpdate`) so progress is visible throughout. Create one task per phase at the start of the workflow. Mark each task `in_progress` when starting the phase and `completed` when the phase is done:

- T0 — Transition to In Progress
- T1 — Understand the Task
- T2 — Review the Codebase
- T3 — Ask Clarifying Questions
- T4 — Create Implementation Plan
- T5 — Await Plan Approval
- T6 — Verify Working Branch
- T7 — Baseline Verification
- T8 — Implementation
- T9 — Post-Implementation Verification
- T10 — User Testing
- T11 — Commit and Push
- T12 — Summary of Changes
- T13 — Cleanup

**PHASE COMPACTION HANDOFF CONTRACT:** At designated compaction gates in this workflow, the agent writes a durable `phase_handoff` entity to the knowledge graph and prompts the user to run `/compact`. This prevents auto-compaction from firing mid-phase and discarding phase position.

**Steps at each gate — execute before instructing `/compact`:**

1. Wait for any background `area-mapper` sub-agent to complete.
2. Create a `phase_handoff` entity in the knowledge graph:
   - **Name:** `phase-handoff-<JIRA-KEY>-<phase-id>` (e.g. `phase-handoff-ELI-1234-T5`)
   - **Observations:** `phase: <id>`, `skill: task-card`, `jira_key: <key>`, `branch: <name or "none">`, `head_sha: <sha or "n/a">`, one `decisions: <text>` observation per key decision made this phase, `approval_condition: <verbatim user phrasing or "none">`, `next_phase: <id>`, one `open_items: <text>` per open item. At T8 only: `reviewer_iterations: impl=N test=N doc=N`.
   - **Relations:** `BELONGS_TO` → `work_item-<JIRA-KEY>`; `SUPERSEDES` → prior `phase_handoff` for this work item (if any); `REFERENCES` → relevant `exploration`, `plan`, and `finding` entity names.
3. Call `open_nodes` on the new entity and each `REFERENCES` target to confirm writes landed.
4. Emit the Phase Summary block in the chat. The block must contain: phase ID and skill name, Jira key + branch + head SHA anchors, reviewer iteration counters (T8 only), one-line decision summary, verbatim approval condition, next phase ID, handoff entity name, and resume contract ("open_nodes on handoff entity → traverse REFERENCES → `git status` → continue at `<next-phase>`"). End your turn immediately after the Phase Summary block — do not add any further content. The block must end with this literal line: **"Run `/compact` now, then type `continue` to resume."** Do NOT call `AskUserQuestion` here; the user must be free to run `/compact` in the prompt input without any open question consuming their input. When the user next types `continue` (or any message clearly indicating compaction is done), call `open_nodes` on the `phase_handoff` entity, traverse its `REFERENCES`, verify git state (`git status`), and resume at `next_phase`. Before executing the resumed phase, **re-read that phase's section in this skill's `workflow.md`** so its full instructions survive compaction — in particular, any phase that asks the user clarifying or structured questions MUST use `AskUserQuestion` (per the Clarification Rule), never plain text. If the user types a different message instead, handle it normally.

**Cleanup:** Include all `phase_handoff` entities for this work item (prefix `phase-handoff-<JIRA-KEY>-`) in the T13 cleanup enumeration alongside other session-scoped entities.

---

### T0 — Transition to In Progress

**This phase requires TWO separate tool calls. Do not move to T1 until both are complete.**

1. **Tool call 1:** Call `jira_get_transitions` with this issue's key. From the response, find the transition whose target status is **In Progress** and note its **ID**.
2. **Tool call 2:** Call `jira_transition_issue` with this issue's key and that transition ID. This is the call that actually moves the issue. Retrieving transitions alone does nothing -- you MUST call `jira_transition_issue` to complete this phase.

Do not guess transition IDs. Always retrieve them first via tool call 1.

### T1 — Understand the Task

- Retrieve the Jira issue using the provided key. Read its full description.
- Read the **Task Details** section of the Jira issue description thoroughly.
- Identify the goal, acceptance criteria (Acceptance Criteria section), and any constraints.
- Note all items in the **Affected Areas** section and any dependencies listed.
- Read the **Patterns & Code References**, **Non-Functional Requirements**, **Data & Interface Changes**, and **Observability & Telemetry** sections if present. These are the implementation guardrails: the patterns/code anchors to mirror, the NFR targets to meet, the data/interface contracts to build, and the instrumentation to add.

### T2 — Review the Codebase

> **USE KNOWLEDGE GRAPH:** Before spawning explorers, ensure a `work_item-<JIRA_KEY>` entity exists for this task. Call `search_nodes` with the work item key (e.g. `work_item-ELI-1234`); if no entity is returned, create it with observations: `work_type: task`, `jira_key`, `title`, `phase: review`. **Record the entity name** as the `work_item_id` for T2 and pass it to every explorer. Explorer findings stream into the graph as `affected_file`, `evidence`, `pattern`, `integration_point`, and `risk` entities linked to this `work_item` node, and the orchestrator retrieves them via `open_nodes` after the explorers return.

- Identify all distinct areas of the codebase to explore based on the **Affected Areas** section and the task goals. Limit the scope of this exploration to the current project directory.
- For each distinct area in this project, invoke a `codebase-explorer` sub-agent in **parallel**, providing:
    - The target area to explore
    - The question: "What patterns, abstractions, utilities, and testing conventions are in use in this area, and what architectural considerations affect how this task's goals can be implemented here?"
    - The `work_item_id` (`work_item-<JIRA_KEY>`). All findings the explorer streams to the graph will be linked to this node.
    - The task description and acceptance criteria for context
- Wait for all explorers to return. Each non-failed return contains an `Entity:` line with the exploration entity name. `INCOMPLETE` means partial findings are present; consider re-spawning for the same area if coverage matters. `FAILED` means no graph data was written — re-spawn that explorer before proceeding.
- **Post-exploration enrichment:** Spawn the `area-mapper` sub-agent **in the background** (`run_in_background: true`) with the same `work_item_id`. It crystallizes durable area knowledge from this run's graph into Serena project memory for future explorations. Do not wait for it.
- Call `open_nodes` on each `exploration` entity name from the returns. If any entity comes back empty, re-spawn that explorer rather than treating missing data as confirmed. Surface any `open_question` entities in the responses. If any identifies a connection to another area not already explored, dispatch a follow-up `codebase-explorer` (passing the same `work_item_id`) before proceeding.

> **USE SEQUENTIAL THINKING:** Before synthesizing the explorer findings, invoke the `sequentialthinking` tool. Use it to integrate the evidence across all explorer reports, reconcile any conflicting signals between areas, identify the patterns and constraints most relevant to this task's implementation, and build a coherent mental model of the affected codebase. Synthesis that skips this step tends to miss cross-area coupling and architectural constraints that only appear when findings are read together. Do not proceed to the synthesis bullets until the reasoning is complete.

- Synthesize the findings from the graph. Read across all `exploration` entities linked to this `work_item_id` and aggregate:
    - **Patterns, abstractions, and utilities in use** — from `pattern` entities; cite the `evidence_files` observation when present.
    - **Existing test coverage and testing patterns** — from `pattern` entities tagged with test concerns and from `evidence` entities with `evidence_type: convention` covering tests.
    - **High-risk areas or architectural considerations** — from `risk` entities (ordered by severity) and `integration_point` entities flagging cross-area coupling.

### T3 — Ask Clarifying Questions

**Objective:** Resolve any ambiguities, gaps, or risks in the task details before planning the implementation.

**Agent Actions:**

1. Review all output from T0, T1, and T2.
2. Identify clarifying questions. Mark each as `[BLOCKING]` or `[NICE TO HAVE]`.
3. Ask each question one at a time using `AskUserQuestion`. Include the `[BLOCKING]` or `[NICE TO HAVE]` tag in the question text. For open-ended questions, offer `Provide answer` / `Skip — non-blocking` (non-blocking only) and rely on the auto-injected "Other" for the typed answer. If there are no clarifying questions, state this in the chat and proceed.
4. Record all answers verbatim. Do not infer or invent answers.

> **REQUIRED:** All BLOCKING questions answered and answers recorded. Remaining unanswered questions listed as open items.

> **APPROVAL GATE — FULL STOP.** Use `AskUserQuestion` with header `T3 Approval`, options: `Approve and proceed (Recommended)` (description: "All blocking answers are accurate and recorded") / `Request changes` (description: "Something needs correction before continuing"). Do not proceed to T4 until approved.

> **COMPACTION GATE — T3:** Once T3 approval is confirmed, follow the Phase Compaction Handoff Contract above. Entity name: `phase-handoff-<KEY>-T3`; `next_phase: T4`; decisions: clarifying answers and any blocking constraints; branch + head SHA: "n/a" (not yet created). REFERENCES: exploration entities from T2. Emit the Phase Summary block and instruct the user to run `/compact` before proceeding to T4.

### T4 — Create Implementation Plan

> **USE SEQUENTIAL THINKING:** Before drafting the plan, invoke the `sequentialthinking` tool. Use it to map the task's acceptance criteria to specific files and code paths identified in T2, identify any gaps or ambiguities that would leave a criterion unaddressed, reason through the ordering of changes (which must be done first to leave the codebase stable?), and weigh alternative approaches against the patterns and constraints observed in T2. Plan quality at this step determines the trajectory of T5–T12 — a plan with an unexamined assumption produces implementation debt that compounds. Do not draft the plan until the reasoning is complete.

> **THINK HARD:** Before finalizing the plan, think hard about whether every acceptance criterion maps to a specific, concrete code change, and whether the ordering and scope of those changes is minimal and safe. This is the highest-leverage decision point in the workflow — a vague or over-scoped plan produces an implementation that cannot be cleanly reviewed or verified.

> **REUSE EXISTING DIAGRAM:** Before generating a flowgraph, call `open_nodes` on the `work_item-<KEY>` entity and check for an existing `diagram` observation (written by `/requirements-intake` or `/implementation-discovery` if those ran first). If one exists, use it as the starting point and refine it to reflect implementation-level detail — do not start from scratch.

> **GENERATE A FLOWGRAPH (best-effort):** Produce a Mermaid `flowchart` that visualizes the changed control/data flow across the affected files/components. Keep it focused — nodes should map to the concrete elements in this plan (files, components, functions), not abstract boxes.
>
> - **Skip it** for trivial changes where a diagram adds no clarity (e.g. a single-file edit with no branching logic). If skipped, state in one line why.
> - **Render it in the chat** as part of the plan presentation at T5.
> - **Embed it in the Jira description under `## Architecture`** as a ` ```mermaid ` fenced block, immediately after `## Affected Areas`. If the description lacks an `## Architecture` section, add one using `jira_update_issue` (additive edit — update only that section). (Jira Cloud does not render Mermaid natively; it will display as a code block, which is acceptable.) If skipped, set the Architecture section to "None — no diagram for this change."
> - **Record the Mermaid source** for inclusion in the `plan-<JIRA_KEY>` entity created after plan-reviewer approval below. T8 reads the `diagram` observation from that entity as an implementation map.

**REQUIRED:** The plan must include ALL of the following:

- Files to create or modify
- Logic changes and new functionality
- How the plan **follows the Patterns & Code References** from the card (reuse/mirror the referenced code rather than inventing new patterns), **satisfies the Non-Functional Requirements**, **implements the Data & Interface Changes** as specified, and **adds the Observability & Telemetry** called for. For any of these sections marked "None"/"N/A", note that explicitly.
- Testing expectations for the dedicated `test-reviewer` sub-agent (scenarios, regressions, edge cases, commands, and any required fixtures or setup)
- Documentation expectations for the dedicated `documentation-reviewer` sub-agent (inline docs, repository docs, and whether separate `/document-card` follow-up is likely needed)

**REQUIRED: Review the plan before posting.** Verify:

- Does the plan fully satisfy every acceptance criterion listed in the Acceptance Criteria section?
- Is every item in the Affected Areas section accounted for?
- Are there any missing steps, gaps in logic, or unstated assumptions?
- Are the testing expectations comprehensive enough to cover the changes, including edge cases and error scenarios?
- Do the documentation expectations cover all likely affected surfaces?
- Is the plan consistent with the codebase patterns and architecture observed in T2?
- Does the plan follow the **Patterns & Code References** and satisfy the **Non-Functional Requirements**, **Data & Interface Changes**, and **Observability & Telemetry** sections of the card?
- Are there any risks or dependencies not addressed?

If the review reveals issues, revise the plan before posting. Do not post an unreviewed plan.

**Independent plan review:**

Once the self-review is clean, invoke the `plan-reviewer` sub-agent, providing:

- The proposed implementation plan
- The acceptance criteria from the Task Details
- The affected areas from the Task Details
- The Patterns & Code References, Non-Functional Requirements, Data & Interface Changes, and Observability & Telemetry sections from the card
- The codebase findings from T2 (patterns, conventions, and architectural context)
- The Jira issue key and work type

The sub-agent will return a structured findings report with an overall verdict of either **APPROVED** or **CHANGES REQUIRED**.

- If **APPROVED**:

    > **USE KNOWLEDGE GRAPH:** Create a `plan` entity named `plan-<JIRA_KEY>` with observations: `description` (the full reviewed plan text, verbatim — do not summarize or truncate), `files_to_change` (comma-separated list of all files to create or modify), `testing_expectations` (the testing expectations section verbatim), `documentation_expectations` (the documentation expectations section verbatim), and `diagram` (the raw Mermaid source from the flowgraph, or omit this observation entirely if the flowgraph was skipped). Link with a `BELONGS_TO` relation → `work_item-<JIRA_KEY>`. Call `open_nodes` on the new entity to confirm the write landed. This entity is the structured persistence surface for the T5 and T8 compaction gates — their REFERENCES point to `plan-<JIRA_KEY>`, and T8 reads the `diagram` observation from it as an implementation map. If the plan was revised during the review loop, ensure the entity contains the **final approved** plan text.

    Draft a single combined Jira comment with the exact heading `**T4/T5 — Implementation Plan & Approval Request**` for the comment review below. This comment must include:

    - The reviewed implementation plan
    - Architecture diagram (under `### Architecture` — the Mermaid source, or a note if skipped)
    - Testing expectations for the `test-reviewer` sub-agent
    - Documentation expectations for the `documentation-reviewer` sub-agent
    - Risks, dependencies, or open items that affect execution
    - `Approval requested: Please approve this implementation plan before work begins.`

- If **CHANGES REQUIRED**: address every Critical and Major finding, revise the plan, then invoke the `plan-reviewer` sub-agent again. Repeat until the verdict is APPROVED.
- **Max 3 review iterations.** If the plan-reviewer returns CHANGES REQUIRED after 3 iterations, create the `plan-<JIRA_KEY>` entity (same as the APPROVED path above, using the current plan text and noting `review_escalated: true`), draft the same combined `T4/T5` comment with the outstanding findings noted, and proceed to the comment review below.

**Independent comment review:**

Once the comment body is drafted, invoke the `comment-reviewer` sub-agent, providing:

- The drafted comment body verbatim, exactly as it will be passed to `jira_add_comment`
- The phase label `T4/T5 — Implementation Plan & Approval Request`
- The reviewed plan and acceptance criteria
- The Jira issue key

The sub-agent will return a structured report with an overall verdict of either **APPROVED** or **CHANGES REQUIRED**.

- If **APPROVED**: call `jira_add_comment` with the reviewed body, then proceed to T5.
- If **CHANGES REQUIRED**: address every Critical and Major finding, revise the draft, then invoke `comment-reviewer` again with the updated body. Repeat until the verdict is APPROVED.
- **Max 3 review iterations.** If `comment-reviewer` returns CHANGES REQUIRED after 3 iterations, post the comment as-is with the remaining minor findings noted inline at the bottom of the comment body, and continue to T5.

Do not call `jira_add_comment` until `comment-reviewer` returns APPROVED (or the 3-iteration cap is reached). A passing plan-reviewer verdict, a clean self-check, or memory of having run `comment-reviewer` earlier in the workflow does not substitute.

### T5 — Await Plan Approval

---

**APPROVAL GATE -- FULL STOP.**

- The approval request Jira record is the combined `T4/T5` comment already posted in T4. Do not post a second Jira comment here unless the plan changed.
- **Present the full implementation plan in the chat output.** The user should not have to open Jira to review it — display it here before asking for approval.
- Then use `AskUserQuestion` with header `T5 Approval`, options: `Approve and proceed (Recommended)` (description: "Implementation plan is accurate — begin work") / `Request changes` (description: "Revise the plan before proceeding"). Do not poll Jira for approval.
- If the user selects "Request changes", revise the plan, repost the full combined `T4/T5` comment to Jira, and update the `plan-<JIRA_KEY>` entity in the knowledge graph: add a revised `description` observation with the updated plan text (use `add_observations`). Then use `AskUserQuestion` again.
- Only proceed to T6 after "Approve and proceed" is selected.

> **COMPACTION GATE — T5:** Once T5 approval is confirmed, follow the Phase Compaction Handoff Contract above. Entity name: `phase-handoff-<KEY>-T5`; `next_phase: T6`; decisions: approved implementation plan (one-line summary); branch + head SHA: "n/a" (not yet created). REFERENCES: `plan-<KEY>` (the plan entity created in T4) and exploration entities from T2. Emit the Phase Summary block and instruct the user to run `/compact` before proceeding to T6.

---

### T6 — Verify Working Branch

- Run `git branch --show-current` and report the current branch to the user.
- **Standard mode:** Use `AskUserQuestion` with header `Working Branch`, options: `Confirm — this is the correct branch (Recommended)` (description: "Proceed with implementation on this branch") / `Wrong branch — switching now` (description: "I need to switch to the correct branch before continuing"). If the user selects "Wrong branch", halt and wait for them to switch manually, then verify again.
- **Epic child task mode:** Confirm the current branch was created from the Epic Integration Branch specified in Task Details. If it was not, halt and ask the user to switch to the correct branch before continuing.

### T7 — Baseline Verification

- Invoke the `verification-runner` sub-agent with phase context `baseline` and the build/test/lint commands if already known. It returns a `VERIFICATION REPORT` with a per-category verdict and, for any failures, the failing targets and excerpts.
- **All checks must pass before continuing.** If the report returns `FAILURES`, investigate and resolve them using the failing targets and excerpts from the report. Re-invoke `verification-runner` after fixing. Do not begin implementation until it returns `ALL GREEN`.

### T8 — Implementation

**ALL of the following are REQUIRED. Do not skip any category.**

- **Architecture diagram:** Call `open_nodes` on the `plan-<JIRA_KEY>` entity (created in T4) and read the `diagram` observation. Use the control/data flow diagram as a map for sequencing your code changes — write code in the order the flow implies and verify each completed step advances the flow correctly. If no diagram was persisted (skipped in T4), proceed without it.
- **Code:** Write or modify source code according to the implementation plan from T4.
- **Testing handoff:** Leave the implementation in a state that the dedicated `test-reviewer` sub-agent can exercise deterministically. Note any commands, fixtures, or setup that sub-agent will need.
- **Documentation handoff:** Identify the public APIs, configuration surfaces, and repository docs the dedicated `documentation-reviewer` sub-agent must cover.
- Follow existing code style, conventions, and architectural patterns observed in T2.

> **USE SEQUENTIAL THINKING:** Before the self-review, invoke the `sequentialthinking` tool. Use it to walk each acceptance criterion against the implementation, verify the changes follow the patterns observed in T2, identify any caller or integration point that may have been affected but not updated, and check whether the testing and documentation handoffs are complete enough for the sub-agents to proceed without redesigning. Do not begin the self-review checklist until the reasoning is complete.

> **SERENA-FIRST EDITING RULE:** When modifying existing source code, prefer Serena's symbol-aware tools over native `Edit`. Symbol-aware edits produce cleaner diffs, are robust against whitespace or context drift, and — for rename and delete — update references atomically.
>
> 1. **Map first.** Use `get_symbols_overview` on the target file to understand its structure before editing.
> 2. **Locate the target.** Use `find_symbol` to jump to the exact symbol you intend to change. Use scoped paths (`ClassName/methodName`) when multiple symbols share a name.
> 3. **Check blast radius.** Before changing the signature or semantics of a public symbol, run `find_referencing_symbols` so every caller is accounted for in the change.
> 4. **Apply the edit with the right tool:**
>     - **Replacing the body of an existing method, function, or field initializer:** use `replace_symbol_body`.
>     - **Adding a new method, field, or inner class next to an existing symbol:** use `insert_after_symbol` or `insert_before_symbol`.
>     - **Renaming a symbol:** use `rename_symbol` — it rewrites the declaration and every reference in one operation.
>     - **Removing a symbol:** use `safe_delete_symbol` — it refuses the delete when callers still exist, preventing broken references.
> 5. **Reserve native `Edit` for:**
>     - Comments, imports, or annotations outside any symbol body
>     - Non-code files (YAML, JSON, markdown, properties, gradle, build scripts)
>     - Multi-symbol or cross-file text edits that the symbol tools cannot express
>     - New files authored from scratch (use `Write` for those)

**REQUIRED: Self-review the implementation before invoking the reviewer.** Verify:

- Does the implementation fully satisfy every acceptance criterion listed in the Acceptance Criteria section?
- Does the implementation follow the approved plan from T4? If any deviations were made, are they justified?
- Does every code change follow the project's established code style and architectural patterns?
- Does the implementation follow the **Patterns & Code References** from the card, and cover the **Non-Functional Requirements**, **Data & Interface Changes**, and **Observability & Telemetry** the card specified?
- Is error handling comprehensive?
- Are there any code smells, dead code, or hardcoded values that should be configurable?
- Would the dedicated `test-reviewer` sub-agent be able to add comprehensive coverage without redesigning the implementation?
- Have all documentation surfaces affected by the change been identified for the dedicated `documentation-reviewer` sub-agent?
- Are there any leftover TODOs, commented-out code, or debugging artifacts?

Fix any issues found in the self-review before invoking the reviewer.

**Independent review loop:**

Once the self-review is clean, invoke the `implementation-reviewer` sub-agent, providing:

- The full diff of all changed files
- The approved implementation plan from T4
- The acceptance criteria from the Task Details
- The codebase findings from T2 (patterns, conventions, and architectural context)
- The Jira issue key

The sub-agent will return a structured findings report with an overall verdict of either **APPROVED** or **CHANGES REQUIRED**.

- If **APPROVED**: continue with the dedicated testing and documentation completion loops below.
- If **CHANGES REQUIRED**: address every Critical and Major finding, then invoke the `implementation-reviewer` sub-agent again with the updated diff. Repeat until the verdict is APPROVED.
- **Max 3 review iterations.** If the implementation-reviewer returns CHANGES REQUIRED after 3 iterations, use `AskUserQuestion` with header `Reviewer Escalation`, options: `Apply the changes manually and continue` (description: "I'll address the remaining findings — continue after I confirm") / `Skip and continue anyway` (description: "Accept the outstanding findings and proceed to testing") / `Abort` (description: "Stop the workflow here"). Present the outstanding findings before the question.

Do not proceed to the dedicated completion loops until the implementation-reviewer returns an APPROVED verdict.

**Dedicated test completion loop:**

Invoke the `test-reviewer` sub-agent, providing:

- The branch name and base branch — the reviewer fetches the diff itself via `git diff <base-branch>..HEAD`. Do not paste the full diff inline.
- The approved implementation plan from T4, especially the testing expectations
- The acceptance criteria from the Task Details
- The codebase findings from T2, especially testing conventions and nearby test structure
- The baseline verification results from T7, if they identify canonical test commands
- The Jira issue key

The sub-agent will add or update tests as needed, run the relevant test commands, and return a structured report with a status of either **COMPLETE** or **FAILED**.

- If **COMPLETE**: review the report. If it changed any non-test files, invoke the `implementation-reviewer` again with the updated diff before continuing.
- If **FAILED**: use `AskUserQuestion` with header `Test Reviewer Failed`, options: `Apply a manual fix and retry` (description: "I'll address the test failures — continue after I confirm") / `Skip and continue` (description: "Proceed to documentation with the current test state") / `Abort` (description: "Stop the workflow here"). Present the failure report before the question.

**Dedicated documentation completion loop:**

Invoke the `documentation-reviewer` sub-agent, providing:

- The branch name and base branch — the reviewer fetches the diff itself via `git diff <base-branch>..HEAD`. Do not paste the full diff inline.
- The approved implementation plan from T4, especially the documentation expectations
- The acceptance criteria from the Task Details
- The codebase findings from T2, especially documentation conventions and nearby docs
- The Jira issue key

The sub-agent will update inline and repository documentation as needed and return a structured report with a status of either **COMPLETE** or **FAILED**.

- If **COMPLETE**: proceed to T9.
- If **FAILED**: use `AskUserQuestion` with header `Doc Reviewer Failed`, options: `Apply a manual fix and retry` (description: "I'll address the documentation gaps — continue after I confirm") / `Skip and continue` (description: "Proceed to T9 with the current documentation state") / `Abort` (description: "Stop the workflow here"). Present the failure report before the question.
- If the report says user-facing documentation follow-up is `REQUIRED`, record that in T12 and recommend running `/document-card` after this workflow completes.

Do not proceed to T9 until `implementation-reviewer`, `test-reviewer`, and `documentation-reviewer` have all completed successfully.

> **COMPACTION GATE — T8:** Once all three reviewers are complete, follow the Phase Compaction Handoff Contract above. Entity name: `phase-handoff-<KEY>-T8`; `next_phase: T9`; include `reviewer_iterations: impl=N test=N doc=N`; decisions: implementation approach summary and any plan deviations; approval_condition: reviewer verdict. REFERENCES: `plan-<KEY>` from T4 and exploration entities from T2. Emit the Phase Summary block and instruct the user to run `/compact` before proceeding to T9.

### T9 — Post-Implementation Verification

- Invoke the `verification-runner` sub-agent with phase context `post-implementation`, the build/test/lint commands from T7, and a specific assertion for each new or updated test written by `test-reviewer`.
- **All checks must pass.** If the report returns `FAILURES`, fix the failures and re-invoke `verification-runner`. Repeat until it returns `ALL GREEN`.
- If a failure cannot be resolved after reasonable effort, stop and post a comment describing the failure and what was attempted. Do not continue.

### T10 — User Testing

> **Skip in Epic Child Task Mode (confirmed via the Epic Child Mode question at the start) — proceed directly to T11.**

---

**APPROVAL GATE — USER MUST MANUALLY TEST BEFORE PROCEEDING. AUTO MODE DOES NOT BYPASS THIS GATE.**

- Draft a Jira comment with the exact heading `**T10 — User Testing Handoff**` as the verbatim first line — character-for-character, using `**bold**` (not a `##` markdown heading), and never a descriptive substitute such as "Testing ready" or "Fix complete". The comment must include, in this exact order with these exact labels:

    - The branch name
    - A summary of what was implemented
    - **Acceptance Criteria & Testing Steps:** For each acceptance criterion listed in the Task Details, a numbered section with:
        - The criterion restated clearly
        - Step-by-step instructions to verify that criterion is met

**Independent comment review:**

Once the comment body is drafted, invoke the `comment-reviewer` sub-agent, providing:

- The drafted comment body verbatim, exactly as it will be passed to `jira_add_comment`
- The phase label `T10 — User Testing Handoff`
- The branch name and acceptance criteria
- The Jira issue key

The sub-agent will return a structured report with an overall verdict of either **APPROVED** or **CHANGES REQUIRED**.

- If **APPROVED**: call `jira_add_comment` with the reviewed body.
- If **CHANGES REQUIRED**: address every Critical and Major finding, revise the draft, then invoke `comment-reviewer` again with the updated body. Repeat until the verdict is APPROVED.
- **Max 3 review iterations.** If `comment-reviewer` returns CHANGES REQUIRED after 3 iterations, post the comment as-is with the remaining minor findings noted inline at the bottom of the comment body, and continue.

Do not call `jira_add_comment` until `comment-reviewer` returns APPROVED (or the 3-iteration cap is reached). A clean self-check or memory of having run `comment-reviewer` earlier in the workflow does not substitute.

- Present the same testing handoff in the chat — the user should not have to open Jira to see what to test.
- Pause the workflow here and wait. Do not call any tool other than `AskUserQuestion` until the user reports back with an explicit selection. Do not infer approval from silence, from a `continue` keyword, from prior phase success, or from Auto Mode.
- Use `AskUserQuestion` with header `T10 Testing`, options: `Approve — I ran through every step above and every criterion passed (Recommended)` (description: "I have manually tested the implementation and it works as expected") / `Issues found` (description: "One or more problems were found during testing"). Do not proceed until the user selects an option.
- If the user's message accompanying the approval suggests they have NOT actually run through the steps (e.g. "looks good", "go ahead", "skip", "sure", "proceed"), re-ask the question once and require an explicit testing-was-done confirmation. Treat ambiguous approval as the "Issues found" branch until confirmed otherwise.

- If the user identifies issues: for each distinct issue, invoke the `issue-intake` skill (via the `Skill` tool), passing a brief description of the observed behavior, expected behavior, and this task's Jira key as args (e.g. `"Testing found: [description]. Related to: [PROJ-KEY]"`). Work through the issue-intake I0–I6 process with the user to document and triage each issue — it will create a Jira card (Bug or Missing Requirement) for each one. After all issues are documented and their Jira cards are created, return to T8, resolve each issue, re-run T9, and return to this step before proceeding.

---

### T11 — Commit and Push

**PRECONDITION — verify in the chat before running any git command.** State each check and its result before staging anything. If any check fails, STOP and return to T10.

1. The user explicitly selected the "Approve" option at T10 in this conversation. Quote their selection verbatim.
2. No issues were reported by the user after that selection that have not since been addressed and re-approved.
3. The current branch matches the branch confirmed at T6.

Execute the following steps **one at a time, in order**. Report the outcome of each step in the chat before starting the next. Do not pre-batch these into a single tool call sequence — the user must be able to interrupt between any two steps:

**Step 1 — Stage and commit.** Stage all changes and commit with this message format:

```
[{PROJECTKEY}-{ISSUENUMBER}] <concise description of what was done>
```

Example: `[PROJ-1234] Add retry logic with exponential backoff to payment service`

Use imperative mood. Report the commit hash in the chat before proceeding.

**Step 2 — Push the working branch.** Push using `git push origin <branch-name>`. Do not use refspecs. Report the push result before proceeding.

**Step 3 — (Epic child task mode only) Merge and verify.** Switch to the Epic Integration Branch and merge the working branch. Invoke the `verification-runner` sub-agent with phase context `post-implementation` to confirm the integration branch passes the full build, all tests, and all linters. If it returns `FAILURES`, fix them and re-invoke before pushing. Report the final `VERIFICATION REPORT` verdict before proceeding.

**Step 4 — (Epic child task mode only) Push the integration branch.** Push the Epic Integration Branch only after Step 3 passes cleanly. Report the push result before proceeding.

**Step 5 — No Jira transitions here.** Any Jira status transition is part of T12, not T11. Do not transition the issue status from this phase.

### T12 — Summary of Changes

**ALL fields below are REQUIRED. Do not skip any field. If a field does not apply, explicitly state "N/A" with a brief reason.**

Post a comment on this Jira issue with the exact heading `**T12 — Summary of Changes**` as the verbatim first line of the comment body — character-for-character, using `**bold**` (not a `##` markdown heading), and never a descriptive substitute such as "Implementation complete" or "Done".

Begin the comment body with a metadata block: `**Branch:** <branch-name>` and `**Commit:** <commit-hash>`, followed by a `----` horizontal rule.

Then render **every** field below as a bold-labeled section (`**Field name:**`), in this exact order, using these exact field names. Do not rename, merge, reorder, drop, or add fields.

- **What was done:** Concise overview of the changes made.
    
- **Files changed:** List of files created, modified, or deleted.
     
- **Tests added/updated:** Summary of new or modified test coverage completed by `test-reviewer`.
     
- **Documentation added/updated:** Summary of any doc changes, and whether additional user-facing documentation requires a `/document-card` follow-up.

- **Branch / merge status:** Branch name pushed, and in epic child mode the integration branch it was merged back into.
     
- **Deviations from plan:** Any differences between the T4 plan and what was actually implemented, with reasons.
     
- **Release note:** If the change is user-facing, include a 1–2 sentence plain-language release note. If purely internal, state "N/A — internal change."

- **User testing status:** For standard mode, note that T10 user testing passed. For epic child mode, state `Skipped in epic child mode -- handled at epic E9.`

- **Open items:** Follow-up work, known limitations, or unresolved questions.
    

**REQUIRED: Review the summary before posting.** Confirm (1) the first line is exactly `**T12 — Summary of Changes**` in `**bold**` format, (2) the metadata block (`**Branch:**` / `**Commit:**`) is present before the `----` rule, and (3) every mandated field appears as a `**Label:**` section in the specified order with none renamed, dropped, or substituted. If any check fails, rewrite before posting.

**Independent comment review:**

Once the summary body is drafted, invoke the `comment-reviewer` sub-agent, providing:

- The drafted comment body verbatim, exactly as it will be passed to `jira_add_comment`
- The phase label `T12 — Summary of Changes`
- The branch name, commit hash, and files-changed list
- The Jira issue key

The sub-agent will return a structured report with an overall verdict of either **APPROVED** or **CHANGES REQUIRED**.

- If **APPROVED**: call `jira_add_comment` with the reviewed body.
- If **CHANGES REQUIRED**: address every Critical and Major finding, revise the draft, then invoke `comment-reviewer` again with the updated body. Repeat until the verdict is APPROVED.
- **Max 3 review iterations.** If `comment-reviewer` returns CHANGES REQUIRED after 3 iterations, post the comment as-is with the remaining minor findings noted inline at the bottom of the comment body, and continue.

Do not call `jira_add_comment` until `comment-reviewer` returns APPROVED (or the 3-iteration cap is reached). A clean self-check or memory of having run `comment-reviewer` earlier in the workflow does not substitute.

### T13 — Cleanup

- **Standard mode:** Clear the session-scoped knowledge graph nodes created during this task — the `work_item-<JIRA_KEY>` entity and every entity linked to it (`exploration`, `affected_file`, `evidence`, `pattern`, `integration_point`, `risk`, `open_question`, `phase_handoff`, `plan-<JIRA_KEY>`, and any `affected_area` rolled up from them). Use `read_graph` to enumerate, then `delete_entities`. The graph is session-scoped; finishing without cleanup leaves stale state for the next workflow.
- **Epic child task mode:** Do not delete the `work_item-<JIRA_KEY>` entity for this child task or its linked nodes here — the epic-level cleanup at E11 owns wholesale graph teardown after all child tasks complete.

## Completion Criteria

This workflow is complete when **all** of the following are true:

- All phases executed in sequence (T0 through T13)
- All approval gates explicitly confirmed in the chat
- All required Jira comments were posted using the defined comment contract
- Branch changes were committed and pushed successfully
- `implementation-reviewer`, `test-reviewer`, and `documentation-reviewer` all completed successfully
- Standard mode: user testing completed and approved at T10; the T10 approval was captured before any commit or push was made
- Epic child task mode (if used): confirmed via the explicit `Epic Child Mode` AskUserQuestion — never inferred from branch name or other signals
- Commit, push, integration merge, integration push, and any Jira transition each ran as discrete user-visible steps, not as a single chained sequence
- All Jira comments posted by this workflow (T4/T5, T10, T12) were reviewed by `comment-reviewer` and returned APPROVED (or reached the 3-iteration cap) before `jira_add_comment` ran
- T12 summary comment posted using the exact `**T12 — Summary of Changes**` heading and the full mandated field set in order
- T10 handoff comment posted using the exact `**T10 — User Testing Handoff**` heading
- T13 session-scoped knowledge graph cleared
