# TASK CARD WORKFLOW — EXECUTION CONTRACT

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute phases in strict sequential order (T0 through T13).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure as a comment on this Jira issue. Do not continue.
5. Every required output (comments, plans, summaries) must be posted before the phase is considered complete.

**APPROVAL GATE BEHAVIOR:** Approval gates are chat-scoped. If explicit approval is not captured before the session ends or context is lost, stop at the gate. On resume, re-present the latest plan or testing handoff and ask for confirmation again. Never assume a pending approval was granted.

**KNOWLEDGE GRAPH SCOPE:** The knowledge graph in this workflow is session-scoped and used to track work-item state (affected areas, exploration findings, plan, implementation progress). If this workflow is resumed in a new session and the graph is empty, reconstruct state by reading the Jira issue description and all comments posted in prior phases before continuing.

**CLARIFICATION RULE:** Do not assume anything. If required information is missing, ambiguous, conflicting, or underspecified, stop and ask the user for clarification before proceeding.

**SERENA PROJECT ACTIVATION:** Before T0, call `check_onboarding_performed`. If it reports that onboarding has not been performed for this project, call `onboarding` to scope Serena's language server to the current project directory. Serena's symbol tools (`find_symbol`, `find_referencing_symbols`, `get_symbols_overview`, `search_for_pattern`, and the symbol-aware write tools) will not function correctly without this. Do this once at the start of the workflow; do not repeat it between phases.

**TOOL PREFERENCE:** Prefer native tools over Bash for filesystem work. All filesystem, search, and directory operations must stay within the current project directory.

- **File I/O (read files, write new files, edit non-symbol regions):** Use native `Read`, `Write`, `Edit`.
- **Symbol-aware code edits (methods, classes, functions in existing source files):** Prefer Serena's `replace_symbol_body`, `insert_after_symbol`, `insert_before_symbol`, `rename_symbol`, and `safe_delete_symbol` over native `Edit` when the target is a named code symbol. See the Serena-first editing rule in T8 for the full decision rubric.
- **File discovery (find files by name or pattern):** Use native `Glob`.
- **Content search (find text inside files):** Use native `Grep`. For symbolic code navigation during implementation (locating a method, class, or caller before editing), use Serena's `find_symbol`, `find_referencing_symbols`, `get_symbols_overview`, and `search_for_pattern` directly. For broader codebase analysis that informs planning (architectural patterns, convention discovery, cross-area impact), delegate to the `codebase-explorer` agent.
- **Directory operations (list, metadata, move, mkdir):** Use Bash (`ls`, `stat`, `mv`, `mkdir -p`).
- **Git:** Use Bash for all git operations (`git status`, `git diff`, `git log`, `git push`, `git pull`, `git merge`, `git worktree`, `git remote`, `git stash`, `git rebase`, etc.) and for running build, test, and lint commands.

**JIRA COMMENT CONTRACT:** Keep Jira comments minimal, structured, and durable. Do not narrate every phase. Routine Jira comments are required only at:

- **T4/T5** -- one combined comment containing the reviewed implementation plan and the approval request
- **T11** -- user testing handoff in standard mode only
- **T12** -- final structured summary

Additional Jira comments are allowed only for blocking failures, reposting a revised plan after requested changes, or explicit user-requested status updates. Do not post separate narration comments for T0, T1, T2, T3, T6, T7, T8, T9, T10, or T13.

When a Jira comment heading references workflow phases, use the exact phase label defined here. Do not invent synthetic phase ranges such as `T2-T5` or `T6-T10`. The only routine combined phase heading allowed is `T4/T5` because one comment serves both phases.

> **EPIC CHILD TASK MODE:** If the Task Details include an **Epic Integration Branch** field, this is a child task within a larger epic. Three phases behave differently in epic mode:
>
> - **T6:** Branch from the Epic Integration Branch instead of the default branch.
> - **T10:** After committing, merge the task branch into the Epic Integration Branch. Run the full build, all tests, and all linters on the integration branch to confirm no regressions before exiting the worktree.
> - **T11:** Skip User Testing -- user testing for the epic is handled at the epic level (E9). Proceed directly to T12.
> - **T13:** Do not remove the shared epic worktree in epic child-task mode. Final worktree cleanup for the integration branch is handled at the epic level (E11).

**WORKTREE DISCIPLINE:** Always create worktrees under `.worktrees/<branch-name>` in the project root, using the exact branch name as the directory name. Create the directory first if it does not exist: `mkdir -p .worktrees`. The full creation command is `git worktree add .worktrees/<branch-name> <branch-name>`. Never use a worktree-prefixed or renamed branch (e.g. never `worktree-PROJ-123`). All commits must be made on the real branch. Push using `git push origin <branch-name>` — never use refspecs that map a different local branch name to the remote (e.g. never `git push origin worktree-branch:real-branch`). After removing a worktree and returning to the main working directory, run `git fetch origin` and update the local ref with `git branch -f <branch-name> origin/<branch-name>` before checking it out, to ensure the local branch matches the remote.

**TASK TRACKING:** Always use task tracking (`TaskCreate`/`TaskUpdate`) so progress is visible throughout. Create one task per phase at the start of the workflow. Mark each task `in_progress` when starting the phase and `completed` when the phase is done:

- T0 — Transition to In Progress
- T1 — Understand the Task
- T2 — Review the Codebase
- T3 — Ask Clarifying Questions
- T4 — Create Implementation Plan
- T5 — Await Plan Approval
- T6 — Create Branch and Worktree
- T7 — Baseline Verification
- T8 — Implementation
- T9 — Post-Implementation Verification
- T10 — Commit, Push, and Exit Worktree
- T11 — User Testing
- T12 — Summary of Changes
- T13 — Cleanup

---

### T0 — Transition to In Progress

**This phase requires TWO separate tool calls. Do not move to T1 until both are complete.**

1. **Tool call 1:** Call `getTransitionsForJiraIssue` with this issue's key. From the response, find the transition whose target status is **In Progress** and note its **ID**.
2. **Tool call 2:** Call `transitionJiraIssue` with this issue's key and that transition ID. This is the call that actually moves the issue. Retrieving transitions alone does nothing -- you MUST call `transitionJiraIssue` to complete this phase.

Do not guess transition IDs. Always retrieve them first via tool call 1.

### T1 — Understand the Task

- Retrieve the Jira issue using the provided key. Read its full description.
- Read the **Task Details** section of the Jira issue description thoroughly.
- Identify the goal, acceptance criteria (Acceptance Criteria section), and any constraints.
- Note all items in the **Affected Areas** section and any dependencies listed.

### T2 — Review the Codebase

> **USE KNOWLEDGE GRAPH:** Before spawning explorers, ensure a `work_item-<JIRA_KEY>` entity exists for this task. Call `read_graph`; if missing (typical at the start of a fresh session), create it with observations: `work_type: task`, `jira_key`, `title`, `phase: review`. **Record the entity name** as the `work_item_id` for T2 and pass it to every explorer. Explorer findings stream into the graph as `affected_file`, `evidence`, `pattern`, `integration_point`, and `risk` entities linked to this `work_item` node, and the orchestrator reads them after the explorers return.

- Identify all distinct areas of the codebase to explore based on the **Affected Areas** section and the task goals. Limit the scope of this exploration to the current project directory.
- For each distinct area in this project, invoke a `codebase-explorer` sub-agent in **parallel**, providing:
    - The target area to explore
    - The question: "What patterns, abstractions, utilities, and testing conventions are in use in this area, and what architectural considerations affect how this task's goals can be implemented here?"
    - The `work_item_id` (`work_item-<JIRA_KEY>`). All findings the explorer streams to the graph will be linked to this node.
    - The task description and acceptance criteria for context
- Wait for all explorers to return one of `EXPLORATION COMPLETE`, `EXPLORATION INCOMPLETE`, or `EXPLORATION FAILED`. Each non-failed return includes a structured findings block in the text — use it as the resilient source of record alongside the graph. `INCOMPLETE` means partial findings are present; consider re-spawning for the same area if coverage matters.
- **Post-exploration enrichment:** Spawn the `area-mapper` sub-agent **in the background** (`run_in_background: true`) with the same `work_item_id`. It crystallizes durable area knowledge from this run's graph into Serena project memory for future explorations. Do not wait for it.
- Call `read_graph` and walk the subgraph rooted at each `exploration` entity for this `work_item_id`. Surface any `open_question` entities. If any identifies a connection to another area not already explored, dispatch a follow-up `codebase-explorer` (passing the same `work_item_id`) before proceeding.
- Synthesize the findings from the graph. Read across all `exploration` entities linked to this `work_item_id` and aggregate:
    - **Patterns, abstractions, and utilities in use** — from `pattern` entities; cite the `evidence_files` observation when present.
    - **Existing test coverage and testing patterns** — from `pattern` entities tagged with test concerns and from `evidence` entities with `evidence_type: convention` covering tests.
    - **High-risk areas or architectural considerations** — from `risk` entities (ordered by severity) and `integration_point` entities flagging cross-area coupling.

### T3 — Ask Clarifying Questions

**Objective:** Resolve any ambiguities, gaps, or risks in the task details before planning the implementation.

**Agent Actions:**

1. Review all output from T0, T1, and T2.
2. Identify clarifying questions. Mark each as `[BLOCKING]` or `[NICE TO HAVE]`.
3. Present all questions in a **single batch** — do not ask one at a time.
4. Ask all questions **in the chat** and wait for answers before proceeding. If there are no clarifying questions, state this in the chat and proceed.
5. Record all answers verbatim. Do not infer or invent answers.

> **REQUIRED:** All BLOCKING questions answered and answers recorded. Remaining unanswered questions listed as open items.

> **APPROVAL GATE — FULL STOP.** Present all questions and recorded answers. User must confirm all blocking answers are accurate. Do not proceed to T4 until confirmed.

### T4 — Create Implementation Plan

**REQUIRED:** The plan must include ALL of the following:

- Files to create or modify
- Logic changes and new functionality
- Testing expectations for the dedicated `test-reviewer` sub-agent (scenarios, regressions, edge cases, commands, and any required fixtures or setup)
- Documentation expectations for the dedicated `documentation-reviewer` sub-agent (inline docs, repository docs, and whether separate `/document-card` follow-up is likely needed)

**REQUIRED: Review the plan before posting.** Verify:

- Does the plan fully satisfy every acceptance criterion listed in the Acceptance Criteria section?
- Is every item in the Affected Areas section accounted for?
- Are there any missing steps, gaps in logic, or unstated assumptions?
- Are the testing expectations comprehensive enough to cover the changes, including edge cases and error scenarios?
- Do the documentation expectations cover all likely affected surfaces?
- Is the plan consistent with the codebase patterns and architecture observed in T2?
- Are there any risks or dependencies not addressed?

If the review reveals issues, revise the plan before posting. Do not post an unreviewed plan.

**Independent plan review:**

Once the self-review is clean, invoke the `plan-reviewer` sub-agent, providing:

- The proposed implementation plan
- The acceptance criteria from the Task Details
- The affected areas from the Task Details
- The codebase findings from T2 (patterns, conventions, and architectural context)
- The Jira issue key and work type

The sub-agent will return a structured findings report with an overall verdict of either **APPROVED** or **CHANGES REQUIRED**.

- If **APPROVED**: post a single combined Jira comment with the exact heading `**T4/T5 — Implementation Plan & Approval Request**`, then proceed to T5. This comment must include:

    - The reviewed implementation plan
    - Testing expectations for the `test-reviewer` sub-agent
    - Documentation expectations for the `documentation-reviewer` sub-agent
    - Risks, dependencies, or open items that affect execution
    - `Approval requested: Please approve this implementation plan before work begins.`
- If **CHANGES REQUIRED**: address every Critical and Major finding, revise the plan, then invoke the `plan-reviewer` sub-agent again. Repeat until the verdict is APPROVED.
- **Max 3 review iterations.** If the plan-reviewer returns CHANGES REQUIRED after 3 iterations, post the same combined `T4/T5` comment with the outstanding findings noted, and let the user decide in T5.

### T5 — Await Plan Approval

---

**APPROVAL GATE -- FULL STOP.**

- The approval request Jira record is the combined `T4/T5` comment already posted in T4. Do not post a second Jira comment here unless the plan changed.
- **Present the full implementation plan in the chat output.** The user should not have to open Jira to review it — display it here before asking for approval.
- Then ask for approval **in the chat**. Do not proceed until the user confirms in the chat. Do not poll Jira for approval.
- If the reviewer requests changes, revise the plan, repost the full combined `T4/T5` comment to Jira, and ask for approval in the chat again.
- Only proceed to T6 after explicit approval has been given in the chat.

---

### T6 — Create Branch and Worktree

- **Standard mode — ask which branch to branch from:** Before creating the branch, ask the user in the chat which branch to use as the base. Most codebases use a `stage` or `develop` branch as the integration target — suggest these as the default. **Do not branch from `main` unless the user explicitly specifies it.** If the user names a branch, verify it exists on the remote before proceeding.
- Create a new branch using this naming convention:

```
{PROJECTKEY}-{ISSUENUMBER}-{issue-summary-in-kebab-case}
```

Example: `PROJ-1234-add-retry-logic-to-payment-service`

- **Standard mode:** Create the branch from the user-specified base branch, then create the worktree: `mkdir -p .worktrees && git worktree add .worktrees/<branch-name> <branch-name>`. Do not create a worktree-prefixed branch.
- **Epic child task mode:** Create the branch from the **Epic Integration Branch** specified in Task Details, within the epic's existing worktree. Do not ask for a base branch in this mode — the integration branch is already defined.

### T7 — Baseline Verification

- Run the full build, all tests, and all linters/static analysis.
- **All checks must pass before continuing.** If anything fails, investigate and resolve it first. Do not begin implementation on a broken baseline.

### T8 — Implementation

**ALL of the following are REQUIRED. Do not skip any category.**

- **Code:** Write or modify source code according to the implementation plan from T4.
- **Testing handoff:** Leave the implementation in a state that the dedicated `test-reviewer` sub-agent can exercise deterministically. Note any commands, fixtures, or setup that sub-agent will need.
- **Documentation handoff:** Identify the public APIs, configuration surfaces, and repository docs the dedicated `documentation-reviewer` sub-agent must cover.
- Follow existing code style, conventions, and architectural patterns observed in T2.

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
- **Max 3 review iterations.** If the implementation-reviewer returns CHANGES REQUIRED after 3 iterations, stop and escalate to the user in the chat. Present the remaining findings and ask for guidance on how to proceed.

Do not proceed to the dedicated completion loops until the implementation-reviewer returns an APPROVED verdict.

**Dedicated test completion loop:**

Invoke the `test-reviewer` sub-agent, providing:

- The full diff of all changed files
- The approved implementation plan from T4, especially the testing expectations
- The acceptance criteria from the Task Details
- The codebase findings from T2, especially testing conventions and nearby test structure
- The baseline verification results from T7, if they identify canonical test commands
- The Jira issue key

The sub-agent will add or update tests as needed, run the relevant test commands, and return a structured report with a status of either **COMPLETE** or **FAILED**.

- If **COMPLETE**: review the report. If it changed any non-test files, invoke the `implementation-reviewer` again with the updated diff before continuing.
- If **FAILED**: stop and escalate to the user in the chat. Present the report and ask how to proceed.

**Dedicated documentation completion loop:**

Invoke the `documentation-reviewer` sub-agent, providing:

- The full diff of all changed files after test completion
- The approved implementation plan from T4, especially the documentation expectations
- The acceptance criteria from the Task Details
- The codebase findings from T2, especially documentation conventions and nearby docs
- The Jira issue key

The sub-agent will update inline and repository documentation as needed and return a structured report with a status of either **COMPLETE** or **FAILED**.

- If **COMPLETE**: proceed to T9.
- If **FAILED**: stop and escalate to the user in the chat. Present the report and ask how to proceed.
- If the report says user-facing documentation follow-up is `REQUIRED`, record that in T12 and recommend running `/document-card` after this workflow completes.

Do not proceed to T9 until `implementation-reviewer`, `test-reviewer`, and `documentation-reviewer` have all completed successfully.

### T9 — Post-Implementation Verification

- Run the full build, all tests, and all linters/static analysis.
- Confirm the new or updated tests written by `test-reviewer` pass under the final verification run.
- **All checks must pass.** If anything fails, fix and re-run this phase.
- If a failure cannot be resolved after reasonable effort, stop and post a comment describing the failure and what was attempted. Do not continue.

### T10 — Commit, Push, and Exit Worktree

- Stage all changes and commit with this message format:

```
[{PROJECTKEY}-{ISSUENUMBER}] <concise description of what was done>
```

Example: `[PROJ-1234] Add retry logic with exponential backoff to payment service`

- Use imperative mood for the description.
- Push the branch to the remote using `git push origin <branch-name>`. Do not use refspecs.
- **Standard mode:** Exit the worktree and remove it: `git worktree remove .worktrees/<branch-name>`. Then sync the local branch: `git fetch origin` followed by `git branch -f <branch-name> origin/<branch-name>`. Return to the main working directory.
- **Epic child task mode:** After committing, merge the task branch into the Epic Integration Branch. Run the full build, all tests, and all linters on the integration branch to confirm no merge conflicts or regressions. Then exit the worktree.

### T11 — User Testing

> **Skip in Epic Child Task Mode -- proceed directly to T12.**

---

**APPROVAL GATE — USER TESTING REQUIRED.**

- Post a comment on this Jira issue with the exact heading `**T11 — User Testing Handoff**`. The comment must include:

    - The branch name
    - A summary of what was implemented
    - **Acceptance Criteria & Testing Steps:** For each acceptance criterion listed in the Task Details, a numbered section with:
        - The criterion restated clearly
        - Step-by-step instructions to verify that criterion is met
- Present the same testing handoff in the chat — the user should not have to open Jira to see what to test.
- Do not proceed until the user has completed testing and explicitly approved the implementation in the chat.

- If the user identifies issues: for each distinct issue, invoke the `issue-intake` skill (via the `Skill` tool), passing a brief description of the observed behavior, expected behavior, and this task's Jira key as args (e.g. `"Testing found: [description]. Related to: [PROJ-KEY]"`). Work through the issue-intake I0–I6 process with the user to document and triage each issue — it will create a Jira card (Bug or Missing Requirement) for each one. After all issues are documented and their Jira cards are created, recreate the worktree (`mkdir -p .worktrees && git worktree add .worktrees/<branch-name> <branch-name>`), return to T8, resolve each issue, re-run T9 and T10 (which removes the worktree again), and return to this step before proceeding.

---

### T12 — Summary of Changes

**ALL fields below are REQUIRED. Do not skip any field. If a field does not apply, explicitly state "N/A" with a brief reason.**

Post a comment on this Jira issue with the exact heading `**T12 — Summary of Changes**` containing ALL of the following:

- **What was done:** Concise overview of the changes made.
    
- **Files changed:** List of files created, modified, or deleted.
     
- **Tests added/updated:** Summary of new or modified test coverage completed by `test-reviewer`.
     
- **Documentation added/updated:** Summary of any doc changes, and whether additional user-facing documentation requires a `/document-card` follow-up.

- **Branch / merge status:** Branch name pushed, and in epic child mode the integration branch it was merged back into.
     
- **Deviations from plan:** Any differences between the T4 plan and what was actually implemented, with reasons.
     
- **Release note:** If the change is user-facing, include a 1–2 sentence plain-language release note. If purely internal, state "N/A — internal change."

- **User testing status:** For standard mode, note that T11 user testing passed. For epic child mode, state `Skipped in epic child mode -- handled at epic E9.`
     
- **QA Verification Steps:** Step-by-step manual testing instructions for a QA engineer, including:
    
    - Prerequisites (environment, test data, configuration)
    - Exact steps to test the new behavior
    - Expected results for each step
    - Edge cases or negative scenarios to verify
- **Open items:** Follow-up work, known limitations, or unresolved questions.
    

**REQUIRED: Review the summary before posting.** Verify every field is present and populated (or explicitly marked "N/A"), and that QA Verification Steps are detailed enough for a QA engineer to follow without additional context. If the review reveals gaps, revise before posting.

### T13 — Cleanup

- **Standard mode:** Confirm `.worktrees/<branch-name>` has been removed. If it still exists (e.g. a follow-up worktree was created during T11 and not yet removed by T10), run `git worktree remove .worktrees/<branch-name>` now. Confirm you have returned to the main working directory.
- **Epic child task mode:** Confirm the child task worktree has been exited and no task-specific temporary worktree remains. Do not remove the shared epic integration worktree here.
- **Standard mode:** Clear the session-scoped knowledge graph nodes created during this task — the `work_item-<JIRA_KEY>` entity and every entity linked to it (`exploration`, `affected_file`, `evidence`, `pattern`, `integration_point`, `risk`, `open_question`, and any `affected_area` rolled up from them). Use `read_graph` to enumerate, then `delete_entities`. The graph is session-scoped; finishing without cleanup leaves stale state for the next workflow.
- **Epic child task mode:** Do not delete the `work_item-<JIRA_KEY>` entity for this child task or its linked nodes here — the epic-level cleanup at E11 owns wholesale graph teardown after all child tasks complete.

## Completion Criteria

This workflow is complete when **all** of the following are true:

- All phases executed in sequence (T0 through T13)
- All approval gates explicitly confirmed in the chat
- All required Jira comments were posted using the defined comment contract
- Branch changes were committed and pushed successfully
- `implementation-reviewer`, `test-reviewer`, and `documentation-reviewer` all completed successfully
- Standard mode: user testing completed and approved at T11
- T12 summary comment posted successfully
- T13 cleanup verified the workflow ended with no lingering task-specific worktree
