---
name: bug-card
description: Execute the Bug Card Workflow on an existing Jira bug issue
user-invocable: true
argument-hint: '<JIRA-BUG-KEY>'
allowed-tools: Bash(git *), Bash(npm *), Bash(yarn *), Bash(pnpm *), Bash(mvn *), Bash(gradle *), Read, Grep, Glob, AskUserQuestion, mcp__atlassian__*
---

# Bug Card Workflow

Execute the full Bug Card Workflow on an existing Jira bug issue.

## Usage

```
/bug-card OR-123
```

---

## Agent Workflow

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute phases in strict sequential order (B0 through B14).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure as a comment on this Jira issue. Do not continue.
5. Every required output (comments, plans, summaries) must be posted before the phase is considered complete.

---

### B0 — Transition to In Progress

* Transition this Jira issue's status to **In Progress** before beginning any work.

### B1 — Understand the Bug

* Read the **Bug Details** above thoroughly.
* Identify the reported behavior, expected behavior, and reproduction steps.
* Note the severity, affected areas, and any environmental conditions.

### B2 — Reproduce the Bug

* Follow the **Steps to Reproduce** exactly as described.
* Confirm whether the bug is reproducible and document the results.
* If the bug **cannot be reproduced:** Stop. Post a comment on this Jira issue describing what was tried, the environment used, and the actual results observed. **Do not continue until the reporter provides additional reproduction guidance.**
* If the bug **is reproduced:** Note any additional observations (e.g., intermittent behavior, specific conditions required, related error logs or stack traces).

### B3 — Investigate Root Cause

* Explore the repository structure, architecture, and conventions, focusing on the **Affected Areas** listed above.
* Trace the code path involved in the reproduction steps to identify the root cause.
* Review git history for recent changes to affected areas that may have introduced a regression.
* Review related tests to understand why existing coverage did not catch this bug.

### B4 — Ask Clarifying Questions

* Identify any ambiguities, gaps, or risks before planning the fix.
* If there are clarifying questions: post them as a comment on this Jira issue and **wait for answers before proceeding.**
* If there are no clarifying questions: post a comment on this Jira issue explicitly stating "No clarifying questions — proceeding to B5."

### B5 — Create Fix Plan

**REQUIRED:** The plan must include ALL of the following:

* **Root cause analysis** — a clear explanation of why the bug occurs
* The proposed fix and rationale
* Files to create or modify
* Tests to add or update to prevent regression
* Documentation to add or update (JSDoc, Javadoc, etc.)

**REQUIRED: Review the plan before posting.** Verify:

* Does the root cause analysis accurately explain the bug based on the investigation in B3?
* Does the proposed fix directly address the root cause without introducing new issues?
* Is every affected area accounted for?
* Are the tests comprehensive enough to prevent regression, including edge cases?
* Is the plan consistent with the codebase patterns and architecture observed in B3?

Post the reviewed plan as a comment on this Jira issue before proceeding.

### B6 — Await Plan Approval

**APPROVAL GATE — FULL STOP.**

* Post a comment on this Jira issue asking the reviewer to approve the fix plan from B5 before work begins.
* Do not proceed until explicit approval is received.
* Only proceed to B7 after explicit approval has been given.

### B7 — Create Branch and Worktree

* Create a new branch from the default branch: `{PROJECTKEY}-{ISSUENUMBER}-{issue-summary-in-kebab-case}`
* Example: `PROJ-5678-fix-null-pointer-in-user-lookup`
* Create a git worktree for the new branch.

### B8 — Baseline Verification

* Run the full build, all tests, and all linters/static analysis.
* **All checks must pass before continuing.**

### B9 — Write a Failing Test

* Before writing the fix, create a test that reproduces the bug in code.
* Run the new test and confirm it **fails for the expected reason**.
* This test serves as both proof of the bug and a permanent regression guard.

### B10 — Implement the Fix

**ALL of the following are REQUIRED:**

* **Code:** Apply the fix according to the plan from B5.
* **Tests:** Add any additional tests beyond B9 to cover related edge cases.
* **Documentation:** Add or update inline documentation for all new or modified public APIs.
* Follow existing code style, conventions, and architectural patterns.

**REQUIRED: Review the implementation before proceeding.** Verify the fix addresses the root cause, follows the approved plan, and doesn't introduce new issues.

### B11 — Post-Fix Verification

* Run the full build, all tests, and all linters/static analysis.
* Confirm the failing test from B9 now **passes**.
* Re-run the original **Steps to Reproduce** and confirm the bug no longer occurs.
* **All checks must pass.**

### B12 — User Testing

**HARD STOP — USER TESTING REQUIRED.**

* Post a comment on this Jira issue notifying the user that the fix is ready for manual testing. Include:
    * A summary of what was fixed
    * Step-by-step instructions for verifying the fix
* Do not proceed until the user has explicitly confirmed the fix is working as expected.

### B13 — Commit

* Stage all changes and commit: `{PROJECTKEY}-{ISSUENUMBER}: <concise description of what was fixed>`
* Example: `PROJ-5678: Fix null pointer when looking up user with missing profile`

### B14 — Summary of Changes

**ALL fields below are REQUIRED.** Post a comment on this Jira issue containing:

* **Root cause:** Clear explanation of what caused the bug.
* **What was fixed:** Overview of the changes made.
* **Files changed:** List of files created, modified, or deleted.
* **Tests added/updated:** Summary of test coverage including the regression test from B9.
* **Documentation added/updated:** Summary of any doc changes.
* **Deviations from plan:** Any differences from the B5 fix plan with reasons.
* **Release note:** 1-2 sentence plain-language release note (or "N/A — internal change").
* **QA Verification Steps:** Prerequisites, steps to confirm fix, expected behavior, edge cases.
* **Open items:** Follow-up work or unresolved questions.
