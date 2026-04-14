# MANUAL QA PLAN WORKFLOW -- EXECUTION CONTRACT

**STRICT EXECUTION RULES -- NO EXCEPTIONS:**

1. Execute phases in strict sequential order (Q0 through Q4).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure in the chat. Do not continue.
5. Every required output must be presented in the chat before the phase is considered complete.
6. This workflow does not change Jira status, post Jira comments, create branches, commit changes, push, or use destructive git commands. The only allowed Jira mutation is appending the final QA plan to the bottom of the issue description in Q4.

**CLARIFICATION RULE:** Do not assume anything. If required information is missing, ambiguous, conflicting, or underspecified, stop and ask the user for clarification before proceeding.

**TESTER AUDIENCE RULE:** All final QA instructions must be written for a QA tester who understands the application but is not familiar with the codebase. Prefer product and workflow language over implementation language. Only mention file names, symbols, or other internal details when they are necessary for setup or to explain a testing risk.

**BRANCH CONTEXT RULE:** Review the actual branch diff whenever possible. If the target branch cannot be resolved from Jira context or repository state, stop and ask the user to provide the branch name or explicitly approve Jira-only QA planning with reduced confidence.

**GIT AND FILESYSTEM TOOL PREFERENCE:** Prefer MCP tools over Bash for git and filesystem operations. For git: use `git_status`, `git_add`, `git_commit`, `git_diff`, `git_diff_staged`, `git_diff_unstaged`, `git_log`, `git_show`, `git_create_branch`, `git_checkout`, and `git_reset` instead of running the equivalent `git` commands via Bash. For filesystem: use `read_file`, `read_multiple_files`, `write_file`, `edit_file`, `list_directory`, `directory_tree`, `search_files`, `create_directory`, `move_file`, and `get_file_info` instead of Bash filesystem commands. Use Bash only for git operations with no MCP equivalent (`git push`, `git pull`, `git merge`, `git worktree`, `git remote`, `git stash`, `git rebase`) and for running build, test, and lint commands.

**DESCRIPTION APPEND RULE:** Preserve the original Jira description exactly as retrieved in Q0. In Q4, append the final QA plan as a new terminal section at the bottom of that description. Do not edit, delete, reorder, reformat, or normalize any pre-existing description content. If an earlier QA plan section already exists, leave it untouched and append the new one after all existing content.

**TASK TRACKING:** Always use task tracking (`TaskCreate`/`TaskUpdate`) so progress is visible throughout. Create tasks for the following logical groups at the start of the workflow, mark each `in_progress` when starting and `completed` when done:

- **Setup** (Q0–Q1): Understand the QA target, resolve target branch
- **Planning** (Q2–Q3): Build QA plan, review and refine
- **Completion** (Q4): Finalize and publish QA plan

---

### Q0 -- Understand the QA Target

- Retrieve the Jira issue using the provided key. Read its full description and preserve the original description verbatim for the append operation in Q4.
- Determine the work type from the issue type and description structure:
    - **Task:** Contains `## Task Details` and `## Acceptance Criteria`
    - **Bug:** Contains `## Bug Details` and `## Fix Criteria`
    - **Epic:** Epic issue, or an issue whose description uses the epic `## Task Details` structure and represents multi-task scope
    - **Anything else:** Stop and explain that this workflow only supports Task, Bug, and Epic issues.
- Extract the issue summary, criteria, affected areas, dependencies, scope boundaries, and any explicit risks or open items.
- Recover the latest durable execution context from Jira comments when present:
    - **Task:** Latest approved implementation-plan comment, plus the latest user-testing handoff or summary comment if present
    - **Bug:** Latest approved fix-plan comment, plus the latest user-testing handoff or summary comment if present
    - **Epic:** Latest approved breakdown-plan comment, plus the latest testing handoff or summary comment if present
- **Epic only:** Retrieve child issues using JQL `parent = ISSUE-KEY`. Read each child issue's key, summary, status, and the description sections needed to understand integrated behavior. If a completed child task includes a final summary comment, use it to recover cross-task verification context.
- If approved-plan or summary context is missing, continue using the issue description plus repository evidence, but explicitly record the missing context for the final summary.

> **REQUIRED:** Present a structured target summary in the chat before proceeding:
>
> - Issue key and title
> - Work type: Task, Bug, or Epic
> - Criteria source identified
> - Supporting context found from comments (plan, handoff, summary), or what is missing
> - Epic child issue count and coverage notes, if applicable

---

### Q1 -- Resolve Branch and Diff Scope

- Detect the current git branch.
- Determine the comparison base branch:
    - **Standard Task, Bug, and Epic runs:** Detect the default branch by running `git remote show origin` and reading the `HEAD branch` line, or by checking for `main` / `master` if the remote is unavailable.
    - **Epic child task context:** If the Task Details include an `Epic Integration Branch` field and the target branch resolves to a task branch, use the `Epic Integration Branch` as the diff base.
- Determine the target branch using this order:
    1. An explicit branch name recovered from the latest testing handoff or summary comment
    2. For epic child tasks only, an explicitly named integration branch if the task branch is unavailable and the user confirms that broader scope is acceptable
    3. The standard branch naming convention `{PROJECTKEY}-{ISSUENUMBER}-{issue-summary-in-kebab-case}`. For epics, this is the integration-branch convention from the epic workflow.
- Confirm the base branch and target branch exist locally or as remote tracking refs.
- Gather the cumulative review scope:
    - The full diff between the base branch and the target branch
    - Any staged or unstaged changes on top of `HEAD` only when the current branch matches the target branch
- Produce:
    - The full diff of all changed files
    - A changed-file list grouped into production files, test files, documentation files, and configuration files where possible
- If the target branch cannot be resolved, the diff cannot be produced, or the only available branch context would broaden the scope beyond the requested issue, stop and ask the user how to proceed.

> **REQUIRED:** Present a structured repository summary in the chat before proceeding:
>
> - Current branch
> - Target branch
> - Base branch
> - Whether uncommitted changes are included in scope
> - Counts of production, test, documentation, and configuration files in scope
> - Any missing or inferred branch context

---

### Q2 -- Gather Manual QA Context

- Read all changed production files in full.
- Read nearby tests, documentation, and configuration files relevant to those changed areas.
- Identify the user-visible or operator-visible behaviors affected by the change, including:
    - Navigation paths, screens, forms, APIs, commands, or background jobs that surface the behavior
    - Permissions, roles, feature flags, environment setup, or test data required to exercise the change
    - Validation rules, empty states, loading states, error states, retries, or fallback behavior
    - Cross-system side effects such as notifications, persistence, synchronization, exports, imports, or downstream integrations
- **Bug work:** Map the original steps to reproduce to the corrected behavior and identify the most likely regression surfaces around the fix.
- **Epic work:** Map the end-to-end workflows and integration points that now span multiple child tasks.
- Translate the technical implementation into plain-language behaviors a QA tester can verify manually.
- Identify anything that is still ambiguous, environment-dependent, or not safely inferable from the available evidence.

> **REQUIRED:** Present a concise manual-QA context summary in the chat before proceeding:
>
> - User-visible change summary
> - Prerequisites, permissions, feature flags, or test data needed
> - Highest-risk areas for manual testing
> - Candidate edge cases or negative scenarios
> - Assumptions or ambiguities that may affect confidence

---

### Q3 -- Invoke `manual-qa-reviewer`

Invoke the `manual-qa-reviewer` sub-agent, providing:

- The Jira issue key and work type
- The relevant Jira description sections and extracted criteria
- The supporting Jira context from Q0 (plan, summary, handoff, child-task context)
- The target branch and base branch from Q1
- The full diff of all changed files from Q1
- The changed-file list grouped by file type from Q1
- The manual-QA context summary from Q2

Wait for the sub-agent to return its `MANUAL QA REVIEW REPORT`.

- If the status is **FAILED**: stop and present the report in the chat. Do not proceed.
- If the status is **COMPLETE**: record the change summary, prerequisites, core scenarios, edge-case scenarios, regression watch list, and open questions.

> **REQUIRED:** Present the `manual-qa-reviewer` outcome in the chat before proceeding:
>
> - Status
> - Number of core scenarios
> - Number of edge-case or negative scenarios
> - Open questions
> - Summary

---

### Q4 -- Final QA Plan and Follow-up

- Review the `MANUAL QA REVIEW REPORT` before presenting it as the final QA plan. Verify every scenario:
    - Is written in application language rather than code-centric language
    - Includes any required setup or prerequisite state
    - Includes exact tester actions in order
    - Includes clear expected results
    - Covers happy-path verification, regression checks, and meaningful edge or negative cases
    - Is specific enough for a QA tester to execute without needing to inspect the codebase
- If any scenario is too vague, overly technical, or missing expected results, revise the final presentation before completing the workflow.

Present a final structured summary in the chat containing ALL of the following:

- **Issue:** Jira key and title
- **Work type:** Task, Bug, or Epic
- **Branch context:** Target branch, base branch, and any limits in the reviewed scope
- **Change summary:** Plain-language summary of what changed
- **Prerequisites:** Environment, data, permissions, feature flags, or setup notes
- **Core manual QA scenarios:** Step-by-step tester flows with expected results
- **Edge cases and negative scenarios:** Additional manual checks that should be run because of risk, error handling, or adjacent behavior
- **Regression watch list:** Nearby areas that should be spot-checked even if they were not the primary change
- **Assumptions / open questions:** Anything the tester or user should confirm before relying on the plan
- **Workflow limitations:** Explicitly state that this workflow does not execute the manual tests, change Jira, or guarantee environment-specific setup beyond what was observable from the issue and repository context

After reviewing the final QA plan, append it to the Jira issue description:

- Use the exact description text captured in Q0 as the prefix.
- Append the QA plan as a new terminal markdown section with the heading `## Final QA Plan`.
- The appended section must contain the final QA plan content from this phase: branch context, change summary, prerequisites, core manual QA scenarios, edge cases and negative scenarios, regression watch list, assumptions / open questions, and workflow limitations.
- Insert the new section only at the bottom of the description. If the original description is non-empty, separate it from the appended section with exactly two newline characters.
- Call `jira_update_issue` with the full updated description.
- Do not modify any text that existed before the appended `## Final QA Plan` section.

If branch review had to be broadened or the user approved Jira-only planning, explicitly warn that confidence is reduced and explain why.

Do not mark this workflow complete until every field above is populated and the Jira description has been updated successfully.

---

## Completion Criteria

This workflow is complete when **all** of the following are true:

- All phases executed in sequence (Q0 through Q4)
- The Jira issue was confirmed as Task, Bug, or Epic
- The related branch and diff scope were identified, or the user explicitly approved reduced-context planning
- `manual-qa-reviewer` ran and returned a `MANUAL QA REVIEW REPORT`
- A final tester-friendly QA plan was presented in the chat with prerequisites, core scenarios, and edge cases
- The Jira issue description was updated by appending the final QA plan at the bottom without changing any earlier description content
