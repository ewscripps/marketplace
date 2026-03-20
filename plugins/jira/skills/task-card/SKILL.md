---
name: task-card
description: Execute the Task Card Workflow on an existing Jira task issue
user-invocable: true
argument-hint: '<JIRA-TASK-KEY>'
allowed-tools: Bash(git *), Bash(npm *), Bash(yarn *), Bash(pnpm *), Bash(mvn *), Bash(gradle *), Read, Grep, Glob, AskUserQuestion, mcp__atlassian__*
---

# Task Card Workflow

Execute the full Task Card Workflow on an existing Jira task issue.

## Usage

```
/task-card OR-456
```

---

## Agent Workflow

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute phases in strict sequential order (T0 through T12).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure as a comment on this Jira issue. Do not continue.
5. Every required output (comments, plans, summaries) must be posted before the phase is considered complete.

---

### T0 — Transition to In Progress

* Transition this Jira issue's status to **In Progress** before beginning any work.

### T1 — Understand the Task

* Read the **Task Details** above thoroughly.
* Identify the goal, acceptance criteria, and any constraints.
* Note all affected areas and dependencies.

### T2 — Review the Codebase

* Explore the repository structure, architecture, and conventions.
* Focus on the **Affected Areas** listed above.
* Identify relevant patterns, abstractions, and utilities already in use.
* Review related tests to understand existing coverage and testing patterns.

### T3 — Ask Clarifying Questions

* Identify any ambiguities, gaps, or risks in the task details.
* If there are clarifying questions: post them as a comment on this Jira issue and **wait for answers before proceeding.**
* If there are no clarifying questions: post a comment explicitly stating "No clarifying questions — proceeding to T4."

### T4 — Create Implementation Plan

**REQUIRED:** The plan must include ALL of the following:

* Files to create or modify
* Logic changes and new functionality
* Tests to add or update
* Documentation to add or update (JSDoc, Javadoc, etc.)

**REQUIRED: Review the plan before posting.** Verify it satisfies all acceptance criteria, accounts for affected areas, and is consistent with codebase patterns.

Post the reviewed plan as a comment on this Jira issue before proceeding.

### T5 — Await Plan Approval

**APPROVAL GATE — FULL STOP.**

* Post a comment asking the reviewer to approve the implementation plan from T4.
* Do not proceed until explicit approval is received.
* Only proceed to T6 after explicit approval has been given.

### T6 — Create Branch and Worktree

* Create a new branch: `{PROJECTKEY}-{ISSUENUMBER}-{issue-summary-in-kebab-case}`
* Example: `PROJ-1234-add-retry-logic-to-payment-service`
* Create a git worktree for the new branch.

### T7 — Baseline Verification

* Run the full build, all tests, and all linters/static analysis.
* **All checks must pass before continuing.**

### T8 — Implementation

**ALL of the following are REQUIRED:**

* **Code:** Write or modify source code according to the plan from T4.
* **Tests:** Create new tests and update existing tests to cover all changes.
* **Documentation:** Add or update inline documentation for all new or modified public APIs.
* Follow existing code style, conventions, and architectural patterns.

**REQUIRED: Review the implementation before proceeding.** Verify it satisfies acceptance criteria, follows the approved plan, and has comprehensive test coverage.

### T9 — Post-Implementation Verification

* Run the full build, all tests, and all linters/static analysis.
* **All checks must pass.**

### T10 — User Testing

**HARD STOP — USER TESTING REQUIRED.**

* Post a comment notifying the user that the implementation is ready for manual testing. Include:
    * A summary of what was implemented
    * Step-by-step instructions for verifying the new behavior
* Do not proceed until the user has explicitly confirmed the implementation is working as expected.

### T11 — Commit

* Stage all changes and commit: `{PROJECTKEY}-{ISSUENUMBER}: <concise description of what was done>`
* Example: `PROJ-1234: Add retry logic with exponential backoff to payment service`

### T12 — Summary of Changes

**ALL fields below are REQUIRED.** Post a comment on this Jira issue containing:

* **What was done:** Concise overview of the changes made.
* **Files changed:** List of files created, modified, or deleted.
* **Tests added/updated:** Summary of new or modified test coverage.
* **Documentation added/updated:** Summary of any doc changes.
* **Deviations from plan:** Any differences from the T4 plan with reasons.
* **Release note:** 1-2 sentence plain-language release note (or "N/A — internal change").
* **QA Verification Steps:** Prerequisites, exact steps, expected results, edge cases.
* **Open items:** Follow-up work or unresolved questions.
