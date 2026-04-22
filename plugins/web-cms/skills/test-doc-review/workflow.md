# TEST / DOCUMENTATION REVIEW WORKFLOW -- EXECUTION CONTRACT

**STRICT EXECUTION RULES -- NO EXCEPTIONS:**

1. Execute phases in strict sequential order (TD0 through TD5). If no Jira issue key was provided at invocation, skip TD0 and begin at TD1.
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure in the chat. Do not continue.
5. Every required output must be presented in the chat before the phase is considered complete.
6. This workflow is standalone. Do not mutate Jira status, create branches, commit changes, or post Jira comments unless the user explicitly asks for that outside this workflow.

**CLARIFICATION RULE:** Do not assume anything. If required information is missing, ambiguous, conflicting, or underspecified, stop and ask the user for clarification before proceeding.

**SCOPE RULE:** This workflow is only for independently running the `test-reviewer` and `documentation-reviewer` sub-agents against an in-progress or completed implementation. It does not replace the full task or bug workflow lifecycle.

**CONTEXT FALLBACK RULE:** When TD0 is skipped, gather the missing plan, criteria, and work-type context from the repository state and the user conversation before invoking either reviewer. In no-Jira mode, pass `No Jira issue provided` as the issue-key context to the sub-agents.

**TOOL PREFERENCE:** Prefer native tools over Bash for filesystem work. All filesystem, search, and directory operations must stay within the current project directory.

- **File I/O (read, write, edit a known file):** Use native `Read`, `Write`, `Edit`.
- **File discovery (find files by name or pattern):** Use native `Glob`.
- **Content search (find text inside files):** Use native `Grep`. For symbolic code search (finding classes, methods, or callers), delegate to the `codebase-explorer` agent, which uses the Serena MCP server.
- **Directory operations (list, metadata, move, mkdir):** Use Bash (`ls`, `stat`, `mv`, `mkdir -p`).
- **Git:** Prefer MCP git tools (`git_status`, `git_add`, `git_commit`, `git_diff`, `git_diff_staged`, `git_diff_unstaged`, `git_log`, `git_show`, `git_create_branch`, `git_checkout`, `git_reset`) over running `git` via Bash. Use Bash only for git operations with no MCP equivalent (`git push`, `git pull`, `git merge`, `git worktree`, `git remote`, `git stash`, `git rebase`) and for running build, test, and lint commands.

**TASK TRACKING:** Always use task tracking (`TaskCreate`/`TaskUpdate`) so progress is visible throughout. Create tasks for the following logical groups at the start of the workflow, mark each `in_progress` when starting and `completed` when done:

- **Setup** (TD0–TD1): Understand the review target, gather diff scope
- **Execution** (TD2–TD4): Test review, documentation review, results
- **Completion** (TD5): Summary

---

### TD0 -- Understand the Review Target

> **Skip this phase entirely if no Jira issue key was provided.**

- Retrieve the Jira issue using the provided key. Read its full description.
- Determine the work type from the description structure:
    - **Task:** Contains `## Task Details` and `## Acceptance Criteria`
    - **Bug:** Contains `## Bug Details` and `## Fix Criteria`
    - **Anything else:** Stop and explain that this skill only supports Task and Bug issues because the downstream reviewers expect single-work-item criteria and plan context.
- Extract the criteria, affected areas, and any dependencies.
- For Task issues, check whether the Task Details include an **Epic Integration Branch** field.
- Read the Jira issue comments and recover the latest approved implementation context:
    - **Task:** The latest approved `T4/T5 — Implementation Plan & Approval Request` comment, if present
    - **Bug:** The latest approved `B5/B6 — Fix Plan & Approval Request` comment, if present
- If the approved plan or fix plan cannot be recovered, stop and ask the user to provide the plan or explicitly confirm that review should proceed without it.

> **REQUIRED:** Present a structured target summary in the chat before proceeding:
>
> - Issue key and title
> - Work type: Task or Bug
> - Criteria source identified
> - Approved plan/fix-plan source identified
> - Epic integration branch noted, if applicable

---

### TD1 -- Determine Repository State and Diff Scope

- Detect the current git branch.
- Determine the comparison base branch:
    - **Task with Epic Integration Branch from TD0:** Use the `Epic Integration Branch`
    - **All other Task and Bug work:** Detect the default branch by running `git remote show origin` and reading the `HEAD branch` line, or by checking for `main` / `master` if the remote is unavailable
- Confirm the base branch exists locally or can be resolved by git.
- Gather the cumulative review scope, including both committed and uncommitted work:
    - Diff between the base branch and `HEAD`
    - Any staged or unstaged working tree changes on top of `HEAD`
- Produce:
    - The full diff of all changed files
    - A changed-file list grouped into production files, test files, and documentation files where possible
- If there are no changes relative to the base branch and the working tree is clean, stop and report that there is nothing to review.

> **REQUIRED:** Present a structured repository summary in the chat before proceeding:
>
> - Current branch
> - Base branch
> - Whether uncommitted changes are present
> - Counts of production, test, and documentation files in scope

---

### TD2 -- Gather Reviewer Context

- If TD0 was skipped, build a **standalone review brief** from the diff, changed files, and repository structure. This brief must include:
    - The apparent change goal or implementation intent
    - The behaviors that should be tested
    - The documentation surfaces likely to need updates
    - Any assumptions or ambiguities that require user confirmation
- If TD0 was skipped and the change intent, acceptance expectations, or validation priorities are not clear enough to guide the reviewers, ask the user in the chat for the missing context before proceeding.
- Read all changed production files in full.
- Read nearby tests and nearby documentation relevant to those changed areas.
- Summarize the existing **testing conventions** in use, including:
    - Test framework(s)
    - File naming and placement patterns
    - Shared helpers, fixtures, or snapshots
    - Candidate test commands if they are obvious from the repository
- Summarize the existing **documentation conventions** in use, including:
    - Inline documentation style
    - README or developer-doc locations
    - Config, migration, or example documentation patterns
- For Bug work, capture any regression expectations from the bug description, steps to reproduce, and any pre-existing regression-test notes.
- Identify any user-facing impact that may later require `/document-card`.

> **REQUIRED:** Present a concise reviewer-context summary in the chat before proceeding:
>
> - Review context source: Jira-backed context from TD0 or standalone review brief from TD2
> - Review goals / criteria source
> - Testing conventions
> - Documentation conventions
> - Candidate verification commands (or `Not identified`)
> - User-facing documentation risk: likely / unlikely / unknown

---

### TD3 -- Invoke `test-reviewer`

Invoke the `test-reviewer` sub-agent, providing:

- The full diff of all changed files gathered in TD1
- The approved implementation plan or fix plan from TD0, or the standalone review brief from TD2 when TD0 was skipped
- The acceptance criteria or fix criteria from TD0, or the standalone review goals from TD2 when TD0 was skipped
- The testing conventions and nearby test structure from TD2
- The Jira issue key from TD0, or `No Jira issue provided`
- The candidate verification commands from TD2, if identified
- For Bug work or bug-like standalone review: the regression context from TD2, if available

Wait for the sub-agent to return its `TEST REVIEW REPORT`.

- If the status is **FAILED**: stop and present the report in the chat. Do not proceed.
- If the status is **COMPLETE**: record all test files changed, non-test files changed, scenario coverage results, command results, and any outstanding gaps.
- If the test-reviewer changed any non-test files, do **not** discard or hide that fact. Carry it into TD5 as a follow-up warning because this standalone workflow does not run the broader `implementation-reviewer`.

> **REQUIRED:** Present the `test-reviewer` outcome in the chat before proceeding:
>
> - Status
> - Test files changed
> - Non-test files changed
> - Command results
> - Outstanding gaps

---

### TD4 -- Invoke `documentation-reviewer`

- Refresh the diff and changed-file list after any edits made during TD3.

Invoke the `documentation-reviewer` sub-agent, providing:

- The refreshed full diff of all changed files
- The approved implementation plan or fix plan from TD0, or the standalone review brief from TD2 when TD0 was skipped
- The acceptance criteria or fix criteria from TD0, or the standalone review goals from TD2 when TD0 was skipped
- The documentation conventions and nearby docs from TD2
- The Jira issue key from TD0, or `No Jira issue provided`
- The user-facing impact notes from TD2

Wait for the sub-agent to return its `DOCUMENTATION REVIEW REPORT`.

- If the status is **FAILED**: stop and present the report in the chat. Do not proceed.
- If the status is **COMPLETE**: record all files changed, documentation coverage results, and whether follow-up `/document-card` work is required.

> **REQUIRED:** Present the `documentation-reviewer` outcome in the chat before proceeding:
>
> - Status
> - Files changed
> - Documentation coverage
> - Whether `/document-card` follow-up is required
> - Outstanding gaps

---

### TD5 -- Final Summary and Follow-up

Present a final structured summary in the chat containing ALL of the following:

- **Issue:** Jira key and title, or `No Jira issue provided`
- **Work type:** Task, Bug, or Standalone no-Jira review
- **Current branch / base branch:** The review comparison used
- **Test review outcome:** Status, test files changed, command results, and any remaining gaps
- **Documentation review outcome:** Status, files changed, coverage results, and whether `/document-card` follow-up is required
- **Implementation re-review warning:** If TD3 changed any non-test files, explicitly state that broader implementation review is recommended before merge or release
- **Workflow limitations:** Explicitly state that this skill does **not** perform user testing, branch management, commit/push, Jira summary comments, or final release validation
- **Next steps:** Concise recommended next actions based on the two reviewer reports

Do not mark this workflow complete until every field above is populated.

---

## Completion Criteria

This workflow is complete when **all** of the following are true:

- All phases executed in sequence (TD0 through TD5), with TD0 skipped only when no Jira issue key was provided
- Jira-backed runs confirmed the work item as Task or Bug, and no-Jira runs established a standalone review brief in TD2
- The diff scope was identified successfully
- `test-reviewer` ran and returned a `TEST REVIEW REPORT`
- `documentation-reviewer` ran and returned a `DOCUMENTATION REVIEW REPORT`
- A final summary with concrete next steps was presented in the chat
