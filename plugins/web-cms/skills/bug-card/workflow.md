# BUG CARD WORKFLOW — EXECUTION CONTRACT

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute phases in strict sequential order (B0 through B15).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure as a comment on this Jira issue. Do not continue.
5. Every required output (comments, plans, summaries) must be posted before the phase is considered complete.

**KNOWLEDGE GRAPH SCOPE:** The knowledge graph in this workflow is session-scoped and used to track investigation state (hypotheses, affected areas, root cause, fix plan). If this workflow is resumed in a new session and the graph is empty, reconstruct state by reading the Jira issue description and all comments posted in prior phases before continuing.

**APPROVAL GATE BEHAVIOR:** Approval gates are chat-scoped. If explicit approval is not captured before the session ends or context is lost, stop at the gate. On resume, re-present the latest fix plan or testing handoff and ask for confirmation again. Never assume a pending approval was granted.

**CLARIFICATION RULE:** Do not assume anything. If required information is missing, ambiguous, conflicting, or underspecified, stop and ask the user for clarification before proceeding.

**RESUMPTION CHECK:** If this workflow resumes after prior work has already been performed, inspect the issue status and previously posted Jira comments first to identify the first incomplete phase. If the issue is already **In Progress**, do not repeat B0. If the knowledge graph is empty, rebuild the investigation state from the latest reproduction notes, investigation comments, and approved plan before continuing.

**SERENA PROJECT ACTIVATION:** Before B0, call `check_onboarding_performed`. If it reports that onboarding has not been performed for this project, call `onboarding` to scope Serena's language server to the current project directory. Serena's symbol tools (`find_symbol`, `find_referencing_symbols`, `get_symbols_overview`, `search_for_pattern`, and the symbol-aware write tools) will not function correctly without this. Do this once at the start of the workflow; do not repeat it between phases.

**TOOL PREFERENCE:** Prefer native tools over Bash for filesystem work. All filesystem, search, and directory operations must stay within the current project directory.

- **File I/O (read files, write new files, edit non-symbol regions):** Use native `Read`, `Write`, `Edit`.
- **Symbol-aware code edits (methods, classes, functions in existing source files):** Prefer Serena's `replace_symbol_body`, `insert_after_symbol`, `insert_before_symbol`, `rename_symbol`, and `safe_delete_symbol` over native `Edit` when the target is a named code symbol. See the Serena-first editing rule in B10 for the full decision rubric.
- **File discovery (find files by name or pattern):** Use native `Glob`.
- **Content search (find text inside files):** Use native `Grep`. For symbolic code navigation during the fix (locating a method, class, or caller before editing), use Serena's `find_symbol`, `find_referencing_symbols`, `get_symbols_overview`, and `search_for_pattern` directly. For broader codebase analysis that informs the investigation (architectural patterns, cross-area impact), delegate to the `codebase-explorer` agent.
- **Directory operations (list, metadata, move, mkdir):** Use Bash (`ls`, `stat`, `mv`, `mkdir -p`).
- **Git:** Prefer MCP git tools (`git_status`, `git_add`, `git_commit`, `git_diff`, `git_diff_staged`, `git_diff_unstaged`, `git_log`, `git_show`, `git_create_branch`, `git_checkout`, `git_reset`) over running `git` via Bash. Use Bash only for git operations with no MCP equivalent (`git push`, `git pull`, `git merge`, `git worktree`, `git remote`, `git stash`, `git rebase`) and for running build, test, and lint commands.

**WORKTREE DISCIPLINE:** When creating a git worktree, always check out the **real branch name** — do not create a worktree-prefixed or renamed branch (e.g. never `worktree-PROJ-123`). Use `git worktree add <path> <branch-name>` to check out the existing branch in the worktree. All commits must be made on the real branch. Push using `git push origin <branch-name>` — never use refspecs that map a different local branch name to the remote (e.g. never `git push origin worktree-branch:real-branch`). After removing a worktree and returning to the main working directory, run `git fetch origin` and update the local ref with `git branch -f <branch-name> origin/<branch-name>` before checking it out, to ensure the local branch matches the remote.

**TASK TRACKING:** Always use task tracking (`TaskCreate`/`TaskUpdate`) so progress is visible throughout. Create tasks for the following logical groups at the start of the workflow, mark each `in_progress` when starting and `completed` when done:

- **Setup** (B0–B1): Transition to In Progress, understand the bug
- **Investigation** (B2–B4): Reproduce, root cause analysis, clarifying questions
- **Planning** (B5–B6): Fix plan, approval
- **Implementation** (B7–B12): Branch/worktree, baseline, failing test, fix, post-fix verification, commit/push
- **Testing & Completion** (B13–B15): User testing, summary of changes, cleanup

---

### B0 — Transition to In Progress

**This phase requires TWO separate tool calls. Do not move to B1 until both are complete.**

1. **Tool call 1:** Call `getTransitionsForJiraIssue` with this issue's key. From the response, find the transition whose target status is **In Progress** and note its **ID**.
2. **Tool call 2:** Call `transitionJiraIssue` with this issue's key and that transition ID. This is the call that actually moves the issue. Retrieving transitions alone does nothing -- you MUST call `transitionJiraIssue` to complete this phase.

Do not guess transition IDs. Always retrieve them first via tool call 1.

### B1 — Understand the Bug

- Retrieve the Jira issue using the provided key. Read its full description.
- Read the **Bug Details** section of the Jira issue description thoroughly.
- Identify the reported behavior (Observed Behavior), expected behavior (Expected Behavior), and reproduction steps (Steps to Reproduce).
- Note the severity, the structured **Affected Areas** list, and any environmental conditions from the Environment section.

### B2 — Reproduce the Bug

- Follow the **Steps to Reproduce** exactly as described.
- Confirm whether the bug is reproducible and document the results.
- If the bug **cannot be reproduced:** Stop. Post a comment on this Jira issue describing what was tried, the environment used, and the actual results observed. **Do not continue until the reporter provides additional reproduction guidance.**
- If the bug **requires manual UI interaction, browser-specific conditions, or environment-specific setup that cannot be automated:** Post a comment noting that automated reproduction is not possible and why. Proceed to B3 with investigation based on code analysis only. Note this limitation -- it will affect B9 (the failing test may need to target the underlying logic rather than the exact user-facing scenario).
- If the bug **is reproduced:** Note any additional observations (e.g., intermittent behavior, specific conditions required, related error logs or stack traces).

### B3 — Investigate Root Cause

> **USE SEQUENTIAL THINKING:** Before dispatching explorers or concluding on root cause, invoke the `sequentialthinking` tool. Use it to identify the likely affected areas to investigate in parallel, form initial hypotheses, evaluate the evidence returned by the explorer agents, and revise if needed. Root cause analysis is non-linear — backtrack and explore alternative causes before committing to a conclusion. Do not proceed to B4 until the reasoning is complete.

> **USE KNOWLEDGE GRAPH:** Before spawning explorers, ensure a `work_item-<JIRA_KEY>` entity exists for this bug. Call `read_graph`; if the entity is missing (typical at the start of a fresh session), create it with observations: `work_type: bug`, `jira_key`, `title`, `observed_behavior`, `expected_behavior`. **Record the entity name** as the `work_item_id` for this run. As you investigate, also create a node for each hypothesis with properties: `hypothesis` (description), `status` (`active` / `eliminated`), and `evidence` (what supports or refutes it). When a hypothesis is eliminated, update its status with a `reason` property. The explorer-written `affected_file`, `evidence`, `pattern`, and `risk` entities they stream to the graph are reachable via the `work_item-<JIRA_KEY>` node and feed directly into the fix plan in B5.

- Identify all distinct areas of the codebase likely involved based on the **Affected Areas**, reproduction steps, and any logs or stack traces. Limit the scope of this exploration to the current project directory.
- Invoke a `codebase-explorer` sub-agent in **parallel** for each distinct hypothesis area in this project, providing:
    - The target area to explore
    - The question: "Does the code path for [observed behavior] exist here, and is there evidence of why it might be producing [incorrect behavior]? Look for recent changes, error handling gaps, and related tests."
    - The `work_item_id` (`work_item-<JIRA_KEY>`). All findings the explorer streams to the graph will be linked to this node.
    - The bug description, reproduction steps, and any logs for context
- Wait for all explorers to return their `EXPLORATION COMPLETE` (or `EXPLORATION FAILED`) pointers.
- Call `read_graph` and walk the subgraph rooted at each `exploration` entity for this `work_item_id`. Surface any `open_question` entities. If any identifies a connection to another area not already explored, dispatch a follow-up `codebase-explorer` (passing the same `work_item_id`) before proceeding.
- Synthesize the findings from the graph. Evaluate which areas show evidence of the root cause (cite the relevant `evidence` entities by `file` and `line_range`) and which hypotheses can be ruled out. Update each hypothesis node's `status` and `evidence` observations to reflect what the graph now contains.
- Review git history for recent changes to affected areas (cross-reference the `affected_file` paths from the graph) that may have introduced a regression.
- Review related tests to understand why existing coverage did not catch this bug — look for `pattern` entities tagged with test concerns and `risk` entities flagging coverage gaps.

### B4 — Ask Clarifying Questions

- Identify any ambiguities, gaps, or risks before planning the fix.
- If there are clarifying questions: post them as a comment on this Jira issue, then ask the same questions **in the chat** and wait for answers before proceeding. Do not poll Jira for answers.
- If there are no clarifying questions: post a comment on this Jira issue explicitly stating "No clarifying questions -- proceeding to B5."

### B5 — Create Fix Plan

> **USE KNOWLEDGE GRAPH:** Read the hypothesis and affected area nodes written in B3. Write a `root_cause` node with properties: `description`, `affected_files` (linked nodes), and `confirmed_by` (the evidence that settled the conclusion). Write a `fix_plan` node linked to the `root_cause` node. Later phases (B10, B14) should read these nodes rather than re-parsing the plan comment.

**REQUIRED:** The plan must include ALL of the following:

- **Root cause analysis** — a clear explanation of why the bug occurs
- The proposed fix and rationale
- Files to create or modify
- Regression test strategy: the failing test to write in B9 and the additional coverage expected from the dedicated `test-reviewer` sub-agent
- Documentation expectations for the dedicated `documentation-reviewer` sub-agent (inline docs, repository docs, and whether separate `/document-card` follow-up is likely needed)

**REQUIRED: Review the plan before posting.** Verify:

- Does the root cause analysis accurately explain the bug based on the investigation in B3?
- Does the proposed fix directly address the root cause without introducing new issues?
- Is every affected area accounted for?
- Are there any missing steps, gaps in logic, or unstated assumptions?
- Are the regression and follow-up test scenarios comprehensive enough to prevent recurrence, including edge cases?
- Do the documentation expectations cover all likely affected surfaces?
- Is the plan consistent with the codebase patterns and architecture observed in B3?
- Are there any risks or dependencies not addressed?

If the review reveals issues, revise the plan before posting. Do not post an unreviewed plan.

**Independent plan review:**

Once the self-review is clean, invoke the `plan-reviewer` sub-agent, providing:

- The proposed fix plan
- The fix criteria from the Bug Details
- The affected areas from the Bug Details and B3 investigation
- The codebase findings from B3 (patterns, conventions, and architectural context)
- The Jira issue key and work type (bug)

The sub-agent will return a structured findings report with an overall verdict of either **APPROVED** or **CHANGES REQUIRED**.

- If **APPROVED**: post a single combined Jira comment with the exact heading `**B5/B6 — Fix Plan & Approval Request**`, then proceed to B6. This comment must include:

    - The reviewed fix plan
    - Regression test strategy for B9 and follow-up test expectations for the `test-reviewer` sub-agent
    - Documentation expectations for the `documentation-reviewer` sub-agent
    - Risks, dependencies, or open items that affect execution
    - `Approval requested: Please approve this fix plan before work begins.`
- If **CHANGES REQUIRED**: address every Critical and Major finding, revise the plan, then invoke the `plan-reviewer` sub-agent again. Repeat until the verdict is APPROVED.
- **Max 3 review iterations.** If the plan-reviewer returns CHANGES REQUIRED after 3 iterations, post the same combined `B5/B6` comment with the outstanding findings noted, and let the user decide in B6.

### B6 — Await Plan Approval

---

**APPROVAL GATE -- FULL STOP.**

- The approval request Jira record is the combined `B5/B6` comment already posted in B5. Do not post a second Jira comment here unless the plan changed.
- Then ask for approval **in the chat**. Do not proceed until the user confirms in the chat. Do not poll Jira for approval.
- If the reviewer requests changes, revise the plan, repost the full combined `B5/B6` comment to Jira, and ask for approval in the chat again.
- Only proceed to B7 after explicit approval has been given in the chat.

---

### B7 — Create Branch and Worktree

- **Ask which branch to branch from:** Before creating the branch, ask the user in the chat which branch to use as the base. Most codebases use a `stage` or `develop` branch as the integration target — suggest these as the default. **Do not branch from `main` unless the user explicitly specifies it.** If the user names a branch, verify it exists on the remote before proceeding.
- Create a new branch from the user-specified base branch using this naming convention:

```
{PROJECTKEY}-{ISSUENUMBER}-{issue-summary-in-kebab-case}
```

Example: `PROJ-5678-fix-null-pointer-in-user-lookup`

- Create a worktree that checks out the branch by its real name: `git worktree add <path> <branch-name>`. Do not create a worktree-prefixed branch.

### B8 — Baseline Verification

- Run the full build, all tests, and all linters/static analysis.
- **All checks must pass before continuing.** If anything fails, investigate and resolve it first. Do not begin the fix on a broken baseline.

### B9 — Write a Failing Test

- Before writing the fix, create a test (or tests) that reproduces the bug in code.
- Run the new test and confirm it **fails for the expected reason.**
- This test serves as both proof of the bug and a permanent regression guard.
- This phase establishes the minimum regression proof. The dedicated `test-reviewer` sub-agent in B10 will expand the coverage after the fix is implemented.
- If the bug cannot be directly reproduced in an automated test (e.g., UI-only behavior, timing-dependent race condition), write a test that targets the underlying logic flaw identified in B3 as closely as possible. Post a comment on the Jira issue noting what the test covers and what it does not, and why a more direct reproduction test was not feasible.

### B10 — Implement the Fix

**ALL of the following are REQUIRED. Do not skip any category.**

- **Code:** Apply the fix according to the plan from B5.
- **Testing handoff:** Keep the implementation and the B9 regression test in a state that the dedicated `test-reviewer` sub-agent can extend and run deterministically. Note any commands, fixtures, or setup that sub-agent will need.
- **Documentation handoff:** Identify the public APIs, configuration surfaces, and repository docs the dedicated `documentation-reviewer` sub-agent must cover.
- Follow existing code style, conventions, and architectural patterns observed in B3.

> **SERENA-FIRST EDITING RULE:** When modifying existing source code to apply the fix, prefer Serena's symbol-aware tools over native `Edit`. Symbol-aware edits produce cleaner diffs, are robust against whitespace or context drift, and — for rename and delete — update references atomically. This matters especially for bug fixes, where the change must be surgical and must not introduce new regressions in adjacent callers.
>
> 1. **Map first.** Use `get_symbols_overview` on the target file to understand its structure before editing.
> 2. **Locate the target.** Use `find_symbol` to jump to the exact symbol implicated by the root cause. Use scoped paths (`ClassName/methodName`) when multiple symbols share a name.
> 3. **Check blast radius.** Run `find_referencing_symbols` on any symbol whose signature or semantics you are changing. A fix that breaks a caller is a new bug.
> 4. **Apply the edit with the right tool:**
>     - **Replacing the body of an existing method, function, or field initializer:** use `replace_symbol_body`.
>     - **Adding a guard clause, helper, or new method next to an existing symbol:** use `insert_after_symbol` or `insert_before_symbol`.
>     - **Renaming a symbol:** use `rename_symbol` — it rewrites the declaration and every reference in one operation.
>     - **Removing a symbol:** use `safe_delete_symbol` — it refuses the delete when callers still exist, preventing broken references.
> 5. **Reserve native `Edit` for:**
>     - Comments, imports, or annotations outside any symbol body
>     - Non-code files (YAML, JSON, markdown, properties, gradle, build scripts)
>     - Multi-symbol or cross-file text edits that the symbol tools cannot express
>     - New files authored from scratch (use `Write` for those)

**REQUIRED: Review the implementation before proceeding.** Verify:

- Does the fix directly and completely address the root cause identified in B3?
- Does the implementation follow the approved fix plan from B5?
- Does the fix avoid introducing new bugs, side effects, or regressions?
- Does every code change follow the project's established code style and architectural patterns?
- Is error handling comprehensive?
- Are there any code smells, dead code, or hardcoded values that should be configurable?
- Does the regression test from B9 accurately reproduce the original bug?
- Would the dedicated `test-reviewer` sub-agent be able to add comprehensive regression coverage without redesigning the fix?
- Have all documentation surfaces affected by the fix been identified for the dedicated `documentation-reviewer` sub-agent?
- Are there any leftover TODOs, commented-out code, or debugging artifacts?

Fix any issues found in the self-review before invoking the reviewer.

**Independent review loop:**

Once the self-review is clean, invoke the `implementation-reviewer` sub-agent, providing:

- The full diff of all changed files
- The approved fix plan from B5
- The fix criteria from the Bug Details
- The codebase findings from B3 (patterns, conventions, and architectural context)
- The Jira issue key

The sub-agent will return a structured findings report with an overall verdict of either **APPROVED** or **CHANGES REQUIRED**.

- If **APPROVED**: continue with the dedicated testing and documentation completion loops below.
- If **CHANGES REQUIRED**: address every Critical and Major finding, then invoke the `implementation-reviewer` sub-agent again with the updated diff. Repeat until the verdict is APPROVED.
- **Max 3 review iterations.** If the implementation-reviewer returns CHANGES REQUIRED after 3 iterations, stop and escalate to the user in the chat. Present the remaining findings and ask for guidance on how to proceed.

Do not proceed to the dedicated completion loops until the implementation-reviewer returns an APPROVED verdict.

**Dedicated test completion loop:**

Invoke the `test-reviewer` sub-agent, providing:

- The full diff of all changed files
- The approved fix plan from B5, especially the regression-test strategy
- The fix criteria from the Bug Details
- The codebase findings from B3, especially testing conventions and nearby test structure
- The baseline verification results from B8, if they identify canonical test commands
- The regression-test context from B9
- The Jira issue key

The sub-agent will add or update tests as needed, run the relevant test commands, and return a structured report with a status of either **COMPLETE** or **FAILED**.

- If **COMPLETE**: review the report. If it changed any non-test files, invoke the `implementation-reviewer` again with the updated diff before continuing.
- If **FAILED**: stop and escalate to the user in the chat. Present the report and ask how to proceed.

**Dedicated documentation completion loop:**

Invoke the `documentation-reviewer` sub-agent, providing:

- The full diff of all changed files after test completion
- The approved fix plan from B5, especially the documentation expectations
- The fix criteria from the Bug Details
- The codebase findings from B3, especially documentation conventions and nearby docs
- The Jira issue key

The sub-agent will update inline and repository documentation as needed and return a structured report with a status of either **COMPLETE** or **FAILED**.

- If **COMPLETE**: proceed to B11.
- If **FAILED**: stop and escalate to the user in the chat. Present the report and ask how to proceed.
- If the report says user-facing documentation follow-up is `REQUIRED`, record that in B14 and recommend running `/document-card` after this workflow completes.

Do not proceed to B11 until `implementation-reviewer`, `test-reviewer`, and `documentation-reviewer` have all completed successfully.

### B11 — Post-Fix Verification

- Run the full build, all tests, and all linters/static analysis.
- Confirm the failing test from B9 and any additional tests written by `test-reviewer` now **pass**.
- Re-run the original **Steps to Reproduce** and confirm the bug no longer occurs.
- **All checks must pass.** If anything fails, fix and re-run this phase.

### B12 — Commit, Push, and Exit Worktree

- Stage all changes and commit with this message format:

```
[{PROJECTKEY}-{ISSUENUMBER}] <concise description of what was fixed>
```

Example: `[PROJ-5678] Fix null pointer when looking up user with missing profile`

- Use imperative mood for the description.
- Push the branch to the remote using `git push origin <branch-name>`. Do not use refspecs.
- Exit the worktree, remove it, then sync the local branch: `git fetch origin` followed by `git branch -f <branch-name> origin/<branch-name>`. Return to the main working directory.

### B13 — User Testing

---

**APPROVAL GATE — USER TESTING REQUIRED.**

- Post a comment on this Jira issue notifying the user that the fix is committed and pushed to the branch. The comment must include:

    - The branch name
    - A summary of what was fixed
    - Step-by-step instructions for verifying the fix (derived from the Steps to Reproduce and the fix plan)
- Do not proceed until the user has completed testing and explicitly approved the fix in the chat.

- If the user identifies issues: create a new worktree for the branch, return to B10, resolve them, re-run B11 and B12, and return to this step before proceeding.


---

### B14 — Summary of Changes

**ALL fields below are REQUIRED. Do not skip any field. If a field does not apply, explicitly state "N/A" with a brief reason.**

Post a comment on this Jira issue containing ALL of the following:

- **Root cause:** Clear, concise explanation of what caused the bug.
    
- **What was fixed:** Overview of the changes made to resolve the issue.
    
- **Files changed:** List of files created, modified, or deleted.
     
- **Tests added/updated:** Summary of new or modified test coverage, including the regression test from B9 and any expansion completed by `test-reviewer`.
     
- **Documentation added/updated:** Summary of any doc changes, and whether additional user-facing documentation requires a `/document-card` follow-up.
    
- **Deviations from plan:** Any differences between the B5 fix plan and what was actually implemented, with reasons.
    
- **Release note:** If the fix is user-facing, include a 1–2 sentence plain-language release note. If purely internal, state "N/A — internal change."
    
- **QA Verification Steps:** Step-by-step manual testing instructions for a QA engineer, including:
    
    - Prerequisites (environment, test data, configuration)
    - Steps to confirm the bug no longer occurs
    - Steps to verify the correct/expected behavior
    - Edge cases or related scenarios to verify no regressions
- **Open items:** Follow-up work, known limitations, or unresolved questions.
    

**REQUIRED: Review the summary before posting.** Verify every field is present and populated (or explicitly marked "N/A"), and that QA Verification Steps are detailed enough for a QA engineer to follow without additional context. If the review reveals gaps, revise before posting.

### B15 — Cleanup

- Confirm the bug-fix worktree has been removed and you have returned to the main working directory. If a follow-up worktree was created during B13, remove it before finishing.
- Clear the session-scoped knowledge graph before finishing the workflow. This includes the `work_item-<JIRA_KEY>` entity and every entity linked to it: hypothesis nodes, `affected_area`, `root_cause`, `fix_plan`, plus the explorer-written subgraph (`exploration`, `affected_file`, `evidence`, `pattern`, `integration_point`, `risk`, `open_question`). Use `read_graph` to enumerate, then `delete_entities`. Do not retain investigation state once it has been materialized into Jira comments.
