# EPIC CARD WORKFLOW — EXECUTION CONTRACT

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute epic phases in strict sequential order (E0 through E11).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure as a comment on this Jira issue. Do not continue.
5. Every required output (comments, plans, summaries) must be posted before the phase is considered complete.

**KNOWLEDGE GRAPH SCOPE:** The knowledge graph in this workflow is the authoritative execution state map for the entire epic. It tracks the epic node, all child task nodes (with Jira keys, execution order, and completion status), the integration branch, and dependencies. If context is lost mid-epic (long session, reconnection, new session), read the graph first to reconstruct exact state. If the graph is empty in a new session, reconstruct state by reading this Jira epic's description and all comments, then querying each child task's status in Jira before continuing.

**APPROVAL GATE BEHAVIOR:** Approval gates are chat-scoped. If explicit approval is not captured before the session ends or context is lost, stop at the gate. On resume, re-present the latest breakdown plan or testing handoff and ask for confirmation again. Never assume a pending approval was granted.

**CLARIFICATION RULE:** Do not assume anything. If required information is missing, ambiguous, conflicting, or underspecified, stop and ask the user for clarification before proceeding.

**RESUMPTION CHECK:** If this workflow resumes after prior work has already been performed, inspect the epic status, the existing Jira comments, and current child task states first to identify the first incomplete phase. If the epic is already **In Progress**, do not repeat E0. If the knowledge graph is empty, rebuild the epic, task, dependency, and branch nodes from the latest approved breakdown, child task descriptions, and Jira task statuses before continuing.

**SERENA PROJECT ACTIVATION:** Before E0, call `check_onboarding_performed`. If it reports that onboarding has not been performed for this project, call `onboarding` to scope Serena's language server to the current project directory. Serena's symbol tools (`find_symbol`, `find_referencing_symbols`, `get_symbols_overview`, `search_for_pattern`) and any symbol-aware operations invoked by the `codebase-explorer` agent depend on this being done. Do this once at the start of the workflow; do not repeat it between phases.

**TOOL PREFERENCE:** Prefer native tools over Bash for filesystem work. All filesystem, search, and directory operations must stay within the current project directory.

- **File I/O (read, write, edit a known file):** Use native `Read`, `Write`, `Edit`.
- **File discovery (find files by name or pattern):** Use native `Glob`.
- **Content search (find text inside files):** Use native `Grep`. For symbolic code search (finding classes, methods, or callers), delegate to the `codebase-explorer` agent, which uses the Serena MCP server.
- **Directory operations (list, metadata, move, mkdir):** Use Bash (`ls`, `stat`, `mv`, `mkdir -p`).
- **Git:** Prefer MCP git tools (`git_status`, `git_add`, `git_commit`, `git_diff`, `git_diff_staged`, `git_diff_unstaged`, `git_log`, `git_show`, `git_create_branch`, `git_checkout`, `git_reset`) over running `git` via Bash. Use Bash only for git operations with no MCP equivalent (`git push`, `git pull`, `git merge`, `git worktree`, `git remote`, `git stash`, `git rebase`) and for running build, test, and lint commands.

**WORKTREE DISCIPLINE:** When creating a git worktree, always check out the **real branch name** — do not create a worktree-prefixed or renamed branch (e.g. never `worktree-PROJ-123`). Use `git worktree add <path> <branch-name>` to check out the existing branch in the worktree. All commits must be made on the real branch. Push using `git push origin <branch-name>` — never use refspecs that map a different local branch name to the remote (e.g. never `git push origin worktree-branch:real-branch`). After removing a worktree and returning to the main working directory, run `git fetch origin` and update the local ref with `git branch -f <branch-name> origin/<branch-name>` before checking it out, to ensure the local branch matches the remote.

**TASK TRACKING:** Always use task tracking (`TaskCreate`/`TaskUpdate`) so progress is visible throughout. Create tasks for the following logical groups at the start of the workflow, mark each `in_progress` when starting and `completed` when done:

- **Setup** (E0–E1): Transition to In Progress, understand the epic
- **Research & Planning** (E2–E5): Codebase review, clarifying questions, breakdown plan, approval
- **Execution Setup** (E6–E7): Create child tasks in Jira, create integration branch/worktree
- **Child Task Execution** (E8): Execute all child tasks (each child task tracks its own progress via the task-card workflow)
- **Testing & Completion** (E9–E11): User testing, epic summary, cleanup

---

### E0 — Transition Epic to In Progress

**This phase requires TWO separate tool calls. Do not move to E1 until both are complete.**

1. **Tool call 1:** Call `jira_get_transitions` with this issue's key. From the response, find the transition whose target status is **In Progress** and note its **ID**.
2. **Tool call 2:** Call `jira_transition_issue` with this issue's key and that transition ID. This is the call that actually moves the issue. Retrieving transitions alone does nothing -- you MUST call `jira_transition_issue` to complete this phase.

Do not guess transition IDs. Always retrieve them first via tool call 1.

### E1 — Understand the Epic

- Retrieve the Jira issue using the provided key. Read its full description.
- Read the **Task Details** section of the Jira issue description thoroughly. (For epics, this section contains the epic's goals and scope.)
- Identify the goals, acceptance criteria (Acceptance Criteria section), scope boundaries (Scope section), and constraints.
- Note all items in the **Affected Areas** section and any dependencies listed.
- Understand what "done" looks like for this epic as a whole.

### E2 — Review the Codebase

- Identify all distinct areas of the codebase to explore based on the **Affected Areas** section and the epic goals.
- For each distinct area (service, module, or component), invoke a `codebase-explorer` sub-agent in **parallel**, providing:
    - The target area to explore
    - The question: "What patterns, abstractions, and utilities are in use here, and what architectural considerations affect how this epic's goals can be implemented in this area?"
    - The epic description for context
- Wait for all explorers to return their findings reports.
- Review each explorer's OPEN QUESTIONS section. If any open question identifies a connection to another area not already explored, dispatch a follow-up `codebase-explorer` for that area before proceeding.
- Synthesize the findings across all reports. Note:
    - Relevant patterns, abstractions, and utilities in use
    - Technical debt, risks, or architectural considerations that could affect the breakdown
    - How the existing code relates to the goals of this epic

### E3 — Ask Clarifying Questions

- Identify any ambiguities, gaps, or risks about the epic's scope or goals.
- If there are clarifying questions: post them as a comment on this Jira issue, then ask the same questions **in the chat** and wait for answers before proceeding. Do not poll Jira for answers.
- If there are no clarifying questions: post a comment explicitly stating "No clarifying questions -- proceeding to E4."

### E4 — Create Breakdown Plan

> **USE SEQUENTIAL THINKING:** Before producing the breakdown, invoke the `sequentialthinking` tool. Use it to draft the task list, check each task for independence (can it be completed without leaving the codebase unstable?), trace the dependency chain between tasks, identify any gaps in coverage against the epic's acceptance criteria, and verify the execution order is correct. Revise iteratively before committing. Do not post the breakdown until the reasoning is complete.

> **USE KNOWLEDGE GRAPH:** After the breakdown is finalized, write the epic and all child tasks to the knowledge graph. Create an `epic` node with properties: `jira_key`, `summary`, `status: in_progress`. For each child task, create a `task` node with properties: `title`, `order` (execution sequence number), `status: pending`, and link it to the epic node. Write `depends_on` relationships between tasks that have dependencies. This graph is the authoritative execution state map for the entire epic — E6, E7, E8, E10, and E11 all read from and write back to it.

Decompose the epic into individual tasks. Each task must be:

- **Independent:** Completable on its own without leaving the codebase in an unstable state.
- **Ordered:** Sequenced so that dependencies between tasks are respected.
- **Small and focused:** One logical unit of work per task.
- **Testable:** Clear acceptance criteria that can be verified independently.

**REQUIRED:** The breakdown must include ALL of the following:

- Task title and summary for each task
- Execution order and rationale
- Dependencies between tasks
- How the tasks collectively satisfy the epic's acceptance criteria

**REQUIRED: Review the breakdown plan before posting.** Verify:

- Do the tasks collectively satisfy every acceptance criterion listed in the Acceptance Criteria section?
- Is every item in the Affected Areas section accounted for across the tasks?
- Is each task truly independent and completable without leaving the codebase unstable?
- Is the execution order correct — are all inter-task dependencies respected?
- Is each task small and focused on a single logical unit of work?
- Are the acceptance criteria for each task specific and testable?
- Are there any gaps where work falls between tasks and would not be covered?
- Is the plan consistent with the codebase patterns observed in E2?

If the review reveals issues, revise the plan before posting. Do not post an unreviewed plan.

Post a single combined Jira comment with the exact heading `**E4/E5 — Breakdown Plan & Approval Request**` before proceeding. This comment must include:

- The reviewed breakdown plan
- Execution order and rationale
- Dependencies between tasks
- How the tasks collectively satisfy the epic's acceptance criteria
- `Approval requested: Please approve this breakdown plan before work begins.`

### E5 — Await Breakdown Plan Approval

---

**APPROVAL GATE -- FULL STOP.**

- The approval request Jira record is the combined `E4/E5` comment already posted in E4. Do not post a second Jira comment here unless the plan changed.
- Then ask for approval **in the chat**. Do not proceed until the user confirms in the chat. Do not poll Jira for approval.
- If the reviewer requests changes, revise the plan, repost the full combined `E4/E5` comment to Jira, and ask for approval in the chat again.
- Only proceed to E6 after explicit approval has been given in the chat.

---

### E6 — Create Child Tasks in Jira

**IMPORTANT:** Each task must be created as a **Child Work Item** of this epic (parent-child relationship). Do NOT create tasks as Linked Work Items. The parent field of each new task must be set to this epic's issue key.

**DO NOT call `jira_create_issue_link` at any point during this phase. Setting the `parent` field in `additional_fields` is the ONLY action needed to establish the parent-child relationship. Any call to `jira_create_issue_link` creates a separate lateral "Related" link that should not exist. Per child task, use one `jira_create_issue` call to create the task with its final description and the parent field already set. No lateral linking calls or follow-up description update calls are allowed.**

For each task identified in E4:

1. Derive the epic integration branch name now using the E7 naming convention: `{PROJECTKEY}-{ISSUENUMBER}-{epic-summary-in-kebab-case}` (e.g. `PROJ-900-user-authentication-overhaul`). This value is written into each child task's `Epic Integration Branch` field so T6 can detect epic child-task mode.
2. Populate the task description using the **Standard Task Template** below. Preserve the section structure exactly, but replace every `{{...}}` token with task-specific content before creating the issue. No unresolved placeholder text may be stored in Jira.
3. **Recommend a priority** for the child task based on its risk level, dependency position, and impact on the epic's acceptance criteria. Use Jira priority values: Critical, High, Medium, or Low. Present the recommended priority to the user for confirmation before creating the issue.
4. Create a new task by calling `jira_create_issue` with `additional_fields` set to `{"parent": "EPIC-KEY", "priority": {"name": "High"}}` (substituting this epic's actual issue key and the confirmed priority name) and the assembled task description. This create call establishes the child work item relationship.

> **USE KNOWLEDGE GRAPH:** After each child task is created in Jira, update its node in the knowledge graph. Add the `jira_key` property to the task node (e.g. `PROJ-124`) so E8 can reference it directly without searching Jira. If the breakdown plan changes during creation (e.g. a task is split), update the graph to reflect the current state before proceeding.

---

## Standard Task Template

**Use the section structure below for every child task. Replace every `{{...}}` token with task-specific content before posting the description. No unresolved placeholder text may remain in Jira.**

---

### STANDARD TASK TEMPLATE -- START

## Task Details

**All fields in this section are REQUIRED.**

**Summary:** {{TASK-SUMMARY}}

**Epic Integration Branch:** {{EPIC-INTEGRATION-BRANCH}}

## Overview
{{TASK-OVERVIEW}}

## Context
Parent epic: {{EPIC-KEY}} — {{EPIC-SUMMARY}}

{{TASK-CONTEXT}}

## Acceptance Criteria

- {{TASK-ACCEPTANCE-CRITERION}}

## Affected Areas

- `{{AFFECTED-PATH}}` -- {{AFFECTED-AREA-DESCRIPTION}} ({{RISK-LEVEL}} risk)

## Dependencies

**Hard:** {{HARD-DEPENDENCIES-OR-NONE}}
**Soft:** {{SOFT-DEPENDENCIES-OR-NONE}}

## Scope
**In Scope:**
- {{IN-SCOPE-ITEM}}

**Out of Scope:**
- {{OUT-OF-SCOPE-ITEM-OR-NONE}}

## Risks
{{TASK-SPECIFIC-RISKS-OR-N/A-MANAGED-IN-PARENT-EPIC}}

## Open Items
{{OPEN-ITEMS-OR-NONE}}

### STANDARD TASK TEMPLATE -- END

---

### E7 — Create Epic Integration Branch and Worktree

- **Ask which branch to branch from:** Before creating the integration branch, ask the user in the chat which branch to use as the base. Most codebases use a `stage` or `develop` branch as the integration target — suggest these as the default. **Do not branch from `main` unless the user explicitly specifies it.** If the user names a branch, verify it exists on the remote before proceeding.
- Create a branch from the user-specified base branch using this naming convention:

```
{PROJECTKEY}-{ISSUENUMBER}-{epic-summary-in-kebab-case}
```

Example: `PROJ-900-user-authentication-overhaul`

- This branch is the integration target for the entire epic. All child task branches will be created from and merged back into this branch.
- Create a worktree that checks out the integration branch by its real name: `git worktree add <path> <branch-name>`. Do not create a worktree-prefixed branch. This worktree is used for child task implementation before manual testing begins.
- Remove this worktree before E9 so the integration branch can be checked out locally for manual testing. After removing the worktree, sync the local branch: `git fetch origin` followed by `git branch -f <branch-name> origin/<branch-name>`. If E9 feedback requires additional fixes, recreate the worktree for that follow-up task work and remove it again (with the same sync step) before returning to E9.
- Push the integration branch to the remote using `git push origin <branch-name>`. Do not use refspecs.

> **USE KNOWLEDGE GRAPH:** Write a `branch` node with properties: `name` (the integration branch name), `type: integration`, and link it to the epic node. This allows E8 to read the integration branch name from the graph rather than re-deriving it.

### E8 — Execute Child Tasks

> **USE KNOWLEDGE GRAPH:** Before starting each child task, read the task nodes from the graph to confirm the correct execution order and that all prerequisite tasks have `status: done`. After each child task completes, update its node to `status: done` and add a `merged_at` timestamp. If context is lost mid-epic (long session, reconnection) and the graph is empty, rebuild the graph first from the epic description, the approved breakdown comment, the child task descriptions, and Jira child task statuses before continuing — do not guess from memory.

Work through each child task **in the order defined in E4**, executing the T0-T13 workflow inline for each one:

1. Read the knowledge graph to confirm all prerequisite tasks for the next task have `status: done`.
2. Retrieve the child task's full description from Jira and confirm that the `Task Details` section includes the expected **Epic Integration Branch** value from E7.
3. Invoke the `task-card` skill directly with the child task's Jira key (e.g., `/task-card PROJ-124`). The skill detects epic child-task mode from the `Epic Integration Branch` field in the task description and adjusts T6 (branch from integration branch), T10 (merge to integration branch), T11 (skip user testing), and T13 (do not remove the shared epic integration worktree). T0 is performed by the skill itself.
4. Follow the full T0-T13 workflow for this child task. Pause at every approval gate and wait for explicit chat confirmation before proceeding. Jira comments should follow the reduced `task-card` comment contract (T3, T4/T5, T12, and failure comments only) rather than phase-by-phase narration.
5. When the child task's T13 is complete, verify its status:
    - If successful: update the task's knowledge graph node to `status: done`. Verify the integration branch passes the full build, all tests, and all linters before proceeding to the next task.
    - If failed: stop and report the failure to the user. Do not begin the next child task until the failure is resolved.
6. **Pause between tasks:** After completing each child task, confirm with the user in the chat before starting the next one.
7. Do not begin the next child task until the current one is confirmed complete and the integration branch is clean.
8. After the final child task is complete, exit the epic worktree created in E7 and return to the main working directory before proceeding to E9. The worktree may be removed now or in E11, but it must not remain active for manual testing.

### E9 — User Testing

---

**APPROVAL GATE — USER TESTING REQUIRED.**

- Before notifying the user, confirm the epic worktree from E7 has been removed and the integration branch is no longer checked out there. Manual testing should happen with the branch checked out normally outside the removed worktree.
- Post a comment notifying the user that all child tasks are complete and the epic is ready for manual testing. The comment must include:
    
    - A summary of everything that was implemented across all child tasks
    - Step-by-step instructions for verifying the epic's functionality end-to-end (derived from the acceptance criteria and breakdown plan)
- Do not proceed until the user has completed testing and explicitly approved the implementation in the chat.
    
- If the user identifies issues, recreate a worktree for the epic integration branch, create a new child task following the E6 child-task creation rules, and add that task to the knowledge graph before execution. Then invoke the `task-card` skill directly with the new child task's Jira key; epic child-task mode will be detected from the `Epic Integration Branch` field, so T11 user testing is skipped automatically. After that follow-up task's T13 completes, update its knowledge graph node to `status: done`, record its merge completion, remove the recreated epic worktree again, and then return to this step.
    

---

### E10 — Epic Summary

**ALL fields below are REQUIRED. Do not skip any field. If a field does not apply, explicitly state "N/A" with a brief reason.**

After all child tasks are complete and user testing has passed, post a comment containing ALL of the following:

- **Overview:** What was accomplished across all child tasks.
    
- **Child tasks completed:** List each child task key and title with its status.
    
- **Deviations from breakdown plan:** Any tasks that were added, removed, split, or significantly changed, with reasons.
    
- **Cumulative release notes:** Consolidated, user-facing release note for the entire epic. If purely internal, state "N/A — internal changes only."
    
- **QA Verification Steps:** End-to-end manual testing instructions for a QA engineer, including:
    
    - Integration testing between changes across child tasks
    - Full user workflows or scenarios enabled by the epic
    - Expected results for each verification step
    - Edge cases that span multiple tasks
- **Open items:** Follow-up work, known limitations, tech debt introduced, or unresolved questions.
    

**REQUIRED: Review the summary before posting.** Verify every field is present, "Child tasks completed" lists every task, and QA Verification Steps cover end-to-end verification. If the review reveals gaps, revise before posting.

### E11 — Cleanup

- Confirm no epic integration-branch worktree remains. Under the normal path it may already have been removed before E9; if one was recreated during E9 follow-up work, remove it before finishing.
- Clear the session-scoped knowledge graph before finishing the workflow. Do not retain epic, task, dependency, or branch state in the graph once the final Jira record is complete.
