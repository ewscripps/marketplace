---
name: epic-card
description: Execute the Epic Card Workflow on an existing Jira epic issue
user-invocable: true
argument-hint: '<JIRA-EPIC-KEY>'
allowed-tools: Bash(git *), Bash(npm *), Bash(yarn *), Bash(pnpm *), Bash(mvn *), Bash(gradle *), Read, Grep, Glob, AskUserQuestion, mcp__atlassian__*
---

# Epic Card Workflow

Execute the full Epic Card Workflow on an existing Jira epic issue. Breaks down the epic into child tasks, creates them in Jira, and executes them sequentially.

## Usage

```
/epic-card OR-100
```

---

## Agent Workflow

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute epic phases in strict sequential order (E0 through E10).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure as a comment on this Jira issue. Do not continue.
5. Every required output (comments, plans, summaries) must be posted before the phase is considered complete.

---

### E0 — Transition Epic to In Progress

* Transition this Jira issue's status to **In Progress** before beginning any work.

### E1 — Understand the Epic

* Read the **Epic Details** above thoroughly.
* Identify the goals, acceptance criteria, scope boundaries, and constraints.
* Note all affected areas and dependencies.
* Understand what "done" looks like for this epic as a whole.

### E2 — Review the Codebase

* Explore the repository structure, architecture, and conventions.
* Focus on the **Affected Areas** listed above.
* Identify relevant patterns, abstractions, and utilities already in use.
* Note any technical debt, risks, or architectural considerations that could affect the breakdown.

### E3 — Ask Clarifying Questions

* Identify any ambiguities, gaps, or risks about the epic's scope or goals.
* If there are clarifying questions: post them as a comment and **wait for answers before proceeding.**
* If there are no clarifying questions: post a comment explicitly stating "No clarifying questions — proceeding to E4."

### E4 — Create Breakdown Plan

Decompose the epic into individual tasks. Each task must be:

* **Independent:** Completable without leaving the codebase unstable.
* **Ordered:** Sequenced so dependencies between tasks are respected.
* **Small and focused:** One logical unit of work per task.
* **Testable:** Clear acceptance criteria that can be verified independently.

**REQUIRED:** The breakdown must include:

* Task title and summary for each task
* Execution order and rationale
* Dependencies between tasks
* How the tasks collectively satisfy the epic's acceptance criteria

Post the reviewed breakdown as a comment on this Jira issue before proceeding.

### E5 — Await Breakdown Plan Approval

**APPROVAL GATE — FULL STOP.**

* Post a comment asking the reviewer to approve the breakdown plan from E4.
* Do not proceed until explicit approval is received.

### E6 — Create Child Tasks in Jira

**IMPORTANT:** Each task must be created as a **Child Work Item** of this epic (parent-child relationship). Do NOT create tasks as Linked Work Items.

For each task identified in E4:

1. Create a new task as a **Child Work Item** of this epic.
2. Populate the task description using the **Standard Task Template** with all required fields.
3. Reference this epic as the parent and include the **Epic Integration Branch** name.

### E7 — Create Epic Integration Branch and Worktree

* Create a branch: `{PROJECTKEY}-{ISSUENUMBER}-{epic-summary-in-kebab-case}`
* Example: `PROJ-900-user-authentication-overhaul`
* This branch is the integration target for the entire epic. All child task branches will be created from and merged back into this branch.
* Create a git worktree named after the epic branch.
* Push the integration branch to the remote.

### E8 — Execute Child Tasks

* Work through each child task **in the order defined in E4.**
* For each child task, follow its full workflow (T0-T11) as written in the child task's description.
* **Do not begin the next child task until the current one is fully committed, merged to the integration branch, and its summary is posted.**
* Before starting each subsequent child task, verify the integration branch has passing build, tests, and linters.

### E9 — User Testing

**HARD STOP — USER TESTING REQUIRED.**

* Post a comment notifying the user that all child tasks are complete and ready for manual testing. Include:
    * A summary of everything implemented across all child tasks
    * Step-by-step instructions for verifying the epic's functionality end-to-end
* Do not proceed until the user has explicitly confirmed the implementation is working as expected.

### E10 — Epic Summary

**ALL fields below are REQUIRED.** Post a comment on this Jira issue containing:

* **Overview:** What was accomplished across all child tasks.
* **Child tasks completed:** List each child task key and title with its status.
* **Deviations from breakdown plan:** Any tasks added, removed, split, or changed from E4 plan with reasons.
* **Cumulative release notes:** Consolidated release note summarizing the entire epic's changes.
* **QA Verification Steps:** End-to-end testing instructions including integration testing and edge cases.
* **Open items:** Follow-up work, known limitations, or tech debt introduced.
