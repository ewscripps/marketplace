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
- **Git:** Use Bash for all git operations (`git status`, `git diff`, `git log`, `git push`, `git pull`, `git merge`, `git worktree`, `git remote`, `git stash`, `git rebase`, etc.) and for running build, test, and lint commands.

**JIRA COMMENT CONTRACT:** Keep Jira comments minimal, structured, and durable. Do not narrate every phase. Routine Jira comments are required only at:

- **E4/E5** — one combined comment containing the reviewed breakdown plan and the approval request
- **E9** — user testing handoff
- **E10** — final epic summary

Additional Jira comments are allowed only for blocking failures, reposting a revised plan after requested changes, or explicit user-requested status updates. Do not post separate narration comments for E0, E1, E2, E3, E6, E7, E8, or E11.

When a Jira comment heading references workflow phases, use the exact phase label defined here. Do not invent synthetic phase ranges. The only routine combined phase heading allowed is `E4/E5` because one comment serves both phases.

**WORKTREE DISCIPLINE:** Always create worktrees under `.worktrees/<branch-name>` in the project root, using the exact branch name as the directory name. Create the directory first if it does not exist: `mkdir -p .worktrees`. The full creation command is `git worktree add .worktrees/<branch-name> <branch-name>`. Never use a worktree-prefixed or renamed branch (e.g. never `worktree-PROJ-123`). All commits must be made on the real branch. Push using `git push origin <branch-name>` — never use refspecs that map a different local branch name to the remote (e.g. never `git push origin worktree-branch:real-branch`). After removing a worktree and returning to the main working directory, run `git fetch origin` and update the local ref with `git branch -f <branch-name> origin/<branch-name>` before checking it out, to ensure the local branch matches the remote.

**TASK TRACKING:** Always use task tracking (`TaskCreate`/`TaskUpdate`) so progress is visible throughout. Create one task per phase at the start of the workflow. Mark each task `in_progress` when starting the phase and `completed` when the phase is done:

- E0 — Transition Epic to In Progress
- E1 — Understand the Epic
- E2 — Review the Codebase
- E3 — Ask Clarifying Questions
- E4 — Create Breakdown Plan
- E5 — Await Breakdown Plan Approval
- E6 — Create Child Tasks in Jira
- E7 — Create Epic Integration Branch and Worktree
- E8 — Execute [JIRA-KEY]: [task title] (one task per child, created in E6 with status `pending`)
- E9 — User Testing
- E10 — Epic Summary
- E11 — Cleanup

---

### E0 — Transition Epic to In Progress

**This phase requires TWO separate tool calls. Do not move to E1 until both are complete.**

1. **Tool call 1:** Call `getTransitionsForJiraIssue` with this issue's key. From the response, find the transition whose target status is **In Progress** and note its **ID**.
2. **Tool call 2:** Call `transitionJiraIssue` with this issue's key and that transition ID. This is the call that actually moves the issue. Retrieving transitions alone does nothing -- you MUST call `transitionJiraIssue` to complete this phase.

Do not guess transition IDs. Always retrieve them first via tool call 1.

### E1 — Understand the Epic

- Retrieve the Jira issue using the provided key. Read its full description.
- Read the **Task Details** section of the Jira issue description thoroughly. (For epics, this section contains the epic's goals and scope.)
- Identify the goals, acceptance criteria (Acceptance Criteria section), scope boundaries (Scope section), and constraints.
- Note all items in the **Affected Areas** section and any dependencies listed.
- Understand what "done" looks like for this epic as a whole.

### E2 — Review the Codebase

> **USE KNOWLEDGE GRAPH:** Before spawning explorers, ensure a `work_item-<JIRA_KEY>` entity exists for this epic. Call `read_graph`; if missing, create it with observations: `work_type: epic`, `jira_key`, `title`, `summary`, `phase: review`. **Record the entity name** as the `work_item_id` for E2 and pass it to every explorer. The richer `epic` node referenced in E4 is created later for breakdown tracking; the `work_item` node here is the canonical root the explorers attach their findings to.

- Identify all distinct areas of the codebase to explore based on the **Affected Areas** section and the epic goals.
- For each distinct area (service, module, or component), invoke a `codebase-explorer` sub-agent in **parallel**, providing:
    - The target area to explore
    - The question: "What patterns, abstractions, and utilities are in use here, and what architectural considerations affect how this epic's goals can be implemented in this area?"
    - The `work_item_id` (`work_item-<JIRA_KEY>`). All findings the explorer streams to the graph will be linked to this node.
    - The epic description for context
- Wait for all explorers to return one of `EXPLORATION COMPLETE`, `EXPLORATION INCOMPLETE`, or `EXPLORATION FAILED`. Each non-failed return includes a structured findings block in the text — use it as the resilient source of record alongside the graph. `INCOMPLETE` means partial findings are present; consider re-spawning for the same area if coverage matters.
- **Post-exploration enrichment:** Spawn the `area-mapper` sub-agent **in the background** (`run_in_background: true`) with the same `work_item_id`. It crystallizes durable area knowledge from this run's graph into Serena project memory for future explorations. Do not wait for it.
- Call `read_graph` and walk the subgraph rooted at each `exploration` entity for this `work_item_id`. Surface any `open_question` entities. If any identifies a connection to another area not already explored, dispatch a follow-up `codebase-explorer` (passing the same `work_item_id`) before proceeding.
- Synthesize the findings from the graph. Read across all `exploration` entities linked to this `work_item_id` and aggregate:
    - **Patterns, abstractions, and utilities in use** — from `pattern` entities; cite the `evidence_files` observation when present.
    - **Technical debt, risks, or architectural considerations** — from `risk` entities, ordered by severity, plus any `integration_point` entities that flag cross-area coupling relevant to the breakdown.
    - **How the existing code relates to the goals of this epic** — from `evidence` entities and aggregated `affected_file` entities.

### E3 — Ask Clarifying Questions

**Objective:** Resolve any ambiguities, gaps, or risks about the epic's scope or goals before planning the breakdown.

**Agent Actions:**

1. Review all output from E0, E1, and E2.
2. Identify clarifying questions. Mark each as `[BLOCKING]` or `[NICE TO HAVE]`.
3. Present all questions in a **single batch** — do not ask one at a time.
4. Ask all questions **in the chat** and wait for answers before proceeding. If there are no clarifying questions, state this in the chat and proceed.
5. Record all answers verbatim. Do not infer or invent answers.

> **REQUIRED:** All BLOCKING questions answered and answers recorded. Remaining unanswered questions listed as open items.

> **APPROVAL GATE — FULL STOP.** Present all questions and recorded answers. User must confirm all blocking answers are accurate. Do not proceed to E4 until confirmed.

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
- **Present the full breakdown plan in the chat output.** The user should not have to open Jira to review it — display it here before asking for approval.
- Then ask for approval **in the chat**. Do not proceed until the user confirms in the chat. Do not poll Jira for approval.
- If the reviewer requests changes, revise the plan, repost the full combined `E4/E5` comment to Jira, and ask for approval in the chat again.
- Only proceed to E6 after explicit approval has been given in the chat.

---

### E6 — Create Child Tasks in Jira

**IMPORTANT:** Each task must be created as a **Child Work Item** of this epic (parent-child relationship). Do NOT create tasks as Linked Work Items. The parent field of each new task must be set to this epic's issue key.

**DO NOT call `createIssueLink` at any point during this phase. Setting the `parent` field in `additional_fields` is the ONLY action needed to establish the parent-child relationship. Any call to `createIssueLink` creates a separate lateral "Related" link that should not exist. Per child task, use one `createJiraIssue` call to create the task with its final description and the parent field already set. No lateral linking calls or follow-up description update calls are allowed.**

For each task identified in E4:

1. Derive the epic integration branch name now using the E7 naming convention: `{PROJECTKEY}-{ISSUENUMBER}-{epic-summary-in-kebab-case}` (e.g. `PROJ-900-user-authentication-overhaul`). This value is written into each child task's `Epic Integration Branch` field so T6 can detect epic child-task mode.
2. Populate the task description using the **Standard Task Template** below. Preserve the section structure exactly, but replace every `{{...}}` token with task-specific content before creating the issue. No unresolved placeholder text may be stored in Jira.
3. **Recommend a priority** for the child task based on its risk level, dependency position, and impact on the epic's acceptance criteria. Use Jira priority values: Critical, High, Medium, or Low. Present the recommended priority to the user for confirmation before creating the issue.
4. Create a new task by calling `createJiraIssue` with `additional_fields` set to `{"parent": "EPIC-KEY", "priority": {"name": "High"}}` (substituting this epic's actual issue key and the confirmed priority name) and the assembled task description. This create call establishes the child work item relationship.

> **USE KNOWLEDGE GRAPH:** After each child task is created in Jira, update its node in the knowledge graph. Add the `jira_key` property to the task node (e.g. `PROJ-124`) so E8 can reference it directly without searching Jira. If the breakdown plan changes during creation (e.g. a task is split), update the graph to reflect the current state before proceeding.

> **TASK TRACKING:** After each child task is created in Jira, create a tracking task named `E8 — Execute [JIRA-KEY]: [task title]` (substituting the real key and title) with status `pending`. These tasks represent the E8 execution slots for each child and will be progressed in E8.

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
- Create the worktree: `mkdir -p .worktrees && git worktree add .worktrees/<branch-name> <branch-name>`. Do not create a worktree-prefixed branch. This worktree is used for child task implementation before manual testing begins.
- Remove this worktree before E9 so the integration branch can be checked out locally for manual testing: `git worktree remove .worktrees/<branch-name>`. Then sync the local branch: `git fetch origin` followed by `git branch -f <branch-name> origin/<branch-name>`. If E9 feedback requires additional fixes, recreate the worktree (`mkdir -p .worktrees && git worktree add .worktrees/<branch-name> <branch-name>`) for that follow-up task work, then remove it again (`git worktree remove .worktrees/<branch-name>`, then sync) before returning to E9.
- Push the integration branch to the remote using `git push origin <branch-name>`. Do not use refspecs.

> **USE KNOWLEDGE GRAPH:** Write a `branch` node with properties: `name` (the integration branch name), `type: integration`, and link it to the epic node. This allows E8 to read the integration branch name from the graph rather than re-deriving it.

### E8 — Execute Child Tasks

> **USE KNOWLEDGE GRAPH:** Before starting each child task, read the task nodes from the graph to confirm the correct execution order and that all prerequisite tasks have `status: done`. After each child task completes, update its node to `status: done` and add a `merged_at` timestamp. If context is lost mid-epic (long session, reconnection) and the graph is empty, rebuild the graph first from the epic description, the approved breakdown comment, the child task descriptions, and Jira child task statuses before continuing — do not guess from memory.

Work through each child task **in the order defined in E4**, executing the T0-T13 workflow inline for each one:

1. Read the knowledge graph to confirm all prerequisite tasks for the next task have `status: done`.
2. Mark the tracking task `E8 — Execute [JIRA-KEY]: [task title]` for this child as `in_progress`.
3. Retrieve the child task's full description from Jira and confirm that the `Task Details` section includes the expected **Epic Integration Branch** value from E7.
4. Invoke the `task-card` skill directly with the child task's Jira key (e.g., `/task-card PROJ-124`). The skill detects epic child-task mode from the `Epic Integration Branch` field in the task description and adjusts T6 (branch from integration branch), T10 (merge to integration branch), T11 (skip user testing), and T13 (do not remove the shared epic integration worktree). T0 is performed by the skill itself.
5. Follow the full T0-T13 workflow for this child task. Pause at every approval gate and wait for explicit chat confirmation before proceeding. Jira comments should follow the reduced `task-card` comment contract (T4/T5, T12, and failure comments only) rather than phase-by-phase narration.
6. When the child task's T13 is complete, verify its status:
    - If successful: update the task's knowledge graph node to `status: done`. Mark the tracking task `E8 — Execute [JIRA-KEY]: [task title]` as `completed`. Verify the integration branch passes the full build, all tests, and all linters before proceeding to the next task.
    - If failed: stop and report the failure to the user. Do not begin the next child task until the failure is resolved.
7. **Pause between tasks:** After completing each child task, confirm with the user in the chat before starting the next one.
8. Do not begin the next child task until the current one is confirmed complete and the integration branch is clean.
9. After the final child task is complete, remove the epic worktree: `git worktree remove .worktrees/<branch-name>`. Sync the local branch: `git fetch origin` followed by `git branch -f <branch-name> origin/<branch-name>`. Return to the main working directory before proceeding to E9.

### E9 — User Testing

---

**APPROVAL GATE — USER TESTING REQUIRED.**

- Before notifying the user, confirm the epic worktree from E7 has been removed and the integration branch is no longer checked out there. Manual testing should happen with the branch checked out normally outside the removed worktree.
- Post a comment notifying the user that all child tasks are complete and the epic is ready for manual testing. The comment must include:
    
    - A summary of everything that was implemented across all child tasks
    - **Acceptance Criteria & Testing Steps:** For each acceptance criterion from the Epic's Acceptance Criteria section (read in E1), a numbered section with:
        - The criterion restated clearly
        - Step-by-step end-to-end instructions to verify that criterion is met across all child tasks
- Present the same testing handoff in the chat — the user should not have to open Jira to see what to test.
- Do not proceed until the user has completed testing and explicitly approved the implementation in the chat.
    
- If the user identifies issues: for each distinct issue, invoke the `issue-intake` skill (via the `Skill` tool), passing a brief description of the observed behavior, expected behavior, and this epic's Jira key as args (e.g. `"Testing found: [description]. Related to: [PROJ-KEY]"`). Work through the issue-intake I0–I6 process with the user to document and triage each issue — it will create a Jira card (Bug or Missing Requirement) for each one. After all issues are documented and their Jira cards are created, recreate the worktree (`mkdir -p .worktrees && git worktree add .worktrees/<branch-name> <branch-name>`). For each issue card created by issue-intake, create a new child Task following E6 child-task creation rules (set the `parent` field to the epic key — do not call `createIssueLink`), and add it to the knowledge graph. Invoke the `task-card` skill with each child task's Jira key; epic child-task mode will be detected from the `Epic Integration Branch` field, so T11 user testing is skipped automatically. After each follow-up task's T13 completes, update its knowledge graph node to `status: done` and record its merge completion. Once all follow-up tasks are done, remove the worktree again (`git worktree remove .worktrees/<branch-name>`, then sync), and return to this step.
    

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

- Confirm `.worktrees/<branch-name>` has been removed. Under the normal path it was removed in E8. If one was recreated during E9 follow-up work and not yet removed, run `git worktree remove .worktrees/<branch-name>` now.
- Clear the session-scoped knowledge graph before finishing the workflow. This includes the `work_item-<JIRA_KEY>` entity for the epic, the separate `epic` / `task` / `branch` nodes used for breakdown tracking, and the explorer-written subgraph from E2 (`exploration`, `affected_file`, `evidence`, `pattern`, `integration_point`, `risk`, `open_question`) along with any per-child-task subgraphs that were not deleted by the child task workflows in epic child-task mode. Use `read_graph` to enumerate, then `delete_entities`. Do not retain epic, task, dependency, or branch state in the graph once the final Jira record is complete.

---

## Completion Criteria

This workflow is complete when **all** of the following are true:

- All phases executed in sequence (E0 through E11)
- All approval gates explicitly confirmed in the chat
- Breakdown plan reviewed and approved (E4/E5)
- All child task Jira issues created as child work items of the epic (E6–E8)
- All child tasks completed and verified
- User testing completed and approved (E9)
- E10 epic summary comment posted to Jira with all required fields populated
- Epic integration-branch worktree removed (E11)
- Session-scoped knowledge graph cleared (E11)
