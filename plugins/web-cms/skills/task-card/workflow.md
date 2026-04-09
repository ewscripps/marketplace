# TASK CARD WORKFLOW — EXECUTION CONTRACT

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute phases in strict sequential order (T0 through T13).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure as a comment on this Jira issue. Do not continue.
5. Every required output (comments, plans, summaries) must be posted before the phase is considered complete.

**APPROVAL GATE BEHAVIOR:** Approval gates are chat-scoped. If explicit approval is not captured before the session ends or context is lost, stop at the gate. On resume, re-present the latest plan or testing handoff and ask for confirmation again. Never assume a pending approval was granted.

**CLARIFICATION RULE:** Do not assume anything. If required information is missing, ambiguous, conflicting, or underspecified, stop and ask the user for clarification before proceeding.

**GIT AND FILESYSTEM TOOL PREFERENCE:** Prefer MCP tools over Bash for git and filesystem operations. For git: use `git_status`, `git_add`, `git_commit`, `git_diff`, `git_diff_staged`, `git_diff_unstaged`, `git_log`, `git_show`, `git_create_branch`, `git_checkout`, and `git_reset` instead of running the equivalent `git` commands via Bash. For filesystem: use `read_file`, `read_multiple_files`, `write_file`, `edit_file`, `list_directory`, `directory_tree`, `search_files`, `create_directory`, `move_file`, and `get_file_info` instead of Bash filesystem commands. Use Bash only for git operations with no MCP equivalent (`git push`, `git pull`, `git merge`, `git worktree`, `git remote`, `git stash`, `git rebase`) and for running build, test, and lint commands.

**JIRA COMMENT CONTRACT:** Keep Jira comments minimal, structured, and durable. Do not narrate every phase. Routine Jira comments are required only at:

- **T3** -- clarification status (questions, or explicit no-question note)
- **T4/T5** -- one combined comment containing the reviewed implementation plan and the approval request
- **T11** -- user testing handoff in standard mode only
- **T12** -- final structured summary

Additional Jira comments are allowed only for blocking failures, reposting a revised plan after requested changes, or explicit user-requested status updates. Do not post separate narration comments for T0, T1, T2, T6, T7, T8, T9, or T10.

When a Jira comment heading references workflow phases, use the exact phase label defined here. Do not invent synthetic phase ranges such as `T2-T5` or `T6-T10`. The only routine combined phase heading allowed is `T4/T5` because one comment serves both phases.

> **EPIC CHILD TASK MODE:** If the Task Details include an **Epic Integration Branch** field, this is a child task within a larger epic. Three phases behave differently in epic mode:
>
> - **T6:** Branch from the Epic Integration Branch instead of the default branch.
> - **T10:** After committing, merge the task branch into the Epic Integration Branch. Run the full build, all tests, and all linters on the integration branch to confirm no regressions before exiting the worktree.
> - **T11:** Skip User Testing -- user testing for the epic is handled at the epic level (E9). Proceed directly to T12.
> - **T13:** Do not remove the shared epic worktree in epic child-task mode. Final worktree cleanup for the integration branch is handled at the epic level (E11).

**TASK TRACKING:** Always use task tracking (`TaskCreate`/`TaskUpdate`) so progress is visible throughout. Create tasks for the following logical groups at the start of the workflow, mark each `in_progress` when starting and `completed` when done:

- **Setup** (T0–T1): Transition to In Progress, understand the task
- **Research & Planning** (T2–T5): Codebase review, clarifying questions, implementation plan, approval
- **Implementation** (T6–T10): Branch/worktree, baseline verification, implementation, post-implementation verification, commit/push
- **Testing & Completion** (T11–T13): User testing, summary of changes, cleanup

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

### T2 — Review the Codebase

- Identify all distinct areas of the codebase to explore based on the **Affected Areas** section and the task goals.
- For each distinct area, invoke a `codebase-explorer` sub-agent in **parallel**, providing:
    - The target area to explore
    - The question: "What patterns, abstractions, utilities, and testing conventions are in use in this area, and what architectural considerations affect how this task's goals can be implemented here?"
    - The task description and acceptance criteria for context
- Wait for all explorers to return their findings reports.
- Review each explorer's OPEN QUESTIONS section. If any open question identifies a connection to another area not already explored, dispatch a follow-up `codebase-explorer` for that area before proceeding.
- Synthesize the findings across all reports. Note:
    - Relevant patterns, abstractions, and utilities in use
    - Existing test coverage and testing patterns
    - High-risk areas or architectural considerations that could affect the implementation

### T3 — Ask Clarifying Questions

- Identify any ambiguities, gaps, or risks in the task details.
- If there are clarifying questions: post a comment on this Jira issue with the exact heading `**T3 — Clarifying Questions**`, then ask the same questions **in the chat** and wait for answers before proceeding. Do not poll Jira for answers.
- If there are no clarifying questions: post a comment on this Jira issue with the exact heading `**T3 — Clarifying Questions**` and the body `Status: No clarifying questions -- proceeding to T4.`

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

- **Standard mode:** Branch from the user-specified base branch and create a git worktree.
- **Epic child task mode:** Branch from the **Epic Integration Branch** specified in Task Details, within the epic's existing worktree. Do not ask for a base branch in this mode — the integration branch is already defined.

### T7 — Baseline Verification

- Run the full build, all tests, and all linters/static analysis.
- **All checks must pass before continuing.** If anything fails, investigate and resolve it first. Do not begin implementation on a broken baseline.

### T8 — Implementation

**ALL of the following are REQUIRED. Do not skip any category.**

- **Code:** Write or modify source code according to the implementation plan from T4.
- **Testing handoff:** Leave the implementation in a state that the dedicated `test-reviewer` sub-agent can exercise deterministically. Note any commands, fixtures, or setup that sub-agent will need.
- **Documentation handoff:** Identify the public APIs, configuration surfaces, and repository docs the dedicated `documentation-reviewer` sub-agent must cover.
- Follow existing code style, conventions, and architectural patterns observed in T2.

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
{PROJECTKEY}-{ISSUENUMBER}: <concise description of what was done>
```

Example: `PROJ-1234: Add retry logic with exponential backoff to payment service`

- Use imperative mood for the description.
- Push the branch to the remote.
- **Standard mode:** Exit the worktree and return to the main working directory.
- **Epic child task mode:** After committing, merge the task branch into the Epic Integration Branch. Run the full build, all tests, and all linters on the integration branch to confirm no merge conflicts or regressions. Then exit the worktree.

### T11 — User Testing

> **Skip in Epic Child Task Mode -- proceed directly to T12.**

---

**APPROVAL GATE — USER TESTING REQUIRED.**

- Post a comment on this Jira issue with the exact heading `**T11 — User Testing Handoff**`. The comment must include:

    - The branch name
    - A summary of what was implemented
    - Step-by-step instructions for verifying the new behavior (derived from the acceptance criteria and the implementation plan)
- Do not proceed until the user has completed testing and explicitly approved the implementation in the chat.

- If the user identifies issues: create a new worktree for the branch, return to T8, resolve them, re-run T9 and T10, and return to this step before proceeding.

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

- **Standard mode:** Confirm the task worktree created in T6 has been removed and you have returned to the main working directory. If a follow-up worktree was created during T11, remove it before finishing.
- **Epic child task mode:** Confirm the child task worktree has been exited and no task-specific temporary worktree remains. Do not remove the shared epic integration worktree here.

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
