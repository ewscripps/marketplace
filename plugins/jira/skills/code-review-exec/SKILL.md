---
name: code-review-exec
description: Execute a code review on an existing Jira Code Review issue
user-invocable: true
argument-hint: '<JIRA-CODE-REVIEW-KEY>'
allowed-tools: Bash(git *), Bash(npm *), Bash(yarn *), Bash(pnpm *), Bash(mvn *), Bash(gradle *), Read, Grep, Glob, AskUserQuestion, mcp__atlassian__*
---

# Code Review Workflow

Execute the full Code Review Workflow on an existing Jira Code Review issue.

## Usage

```
/code-review-exec OR-789
```

---

## Agent Workflow

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute phases in strict sequential order (CR0 through CR10).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure as a comment on this Jira issue. Do not continue.
5. Every required output (comments, findings, summaries) must be posted before the phase is considered complete.

---

### CR0 — Transition to In Progress

* Transition this Jira issue's status to **In Progress** before beginning any work.

### CR1 — Understand the Review Target

* Read the **Review Details** section above thoroughly.
* Retrieve the Jira issue identified in the Review Details.

**Based on Review Type:**

**Release:** Retrieve and read description/acceptance criteria of every work item listed.

**Epic:** Retrieve epic description, goals, acceptance criteria, and all child tasks. Review approved breakdown plan from comment history.

**Task:** Retrieve description, acceptance criteria, affected areas. Review approved implementation plan from comment history.

**Bug:** Retrieve description, fix criteria, steps to reproduce, affected areas. Review approved fix plan from comment history. Note required regression tests.

### CR2 — Verify Branch State

* Check out the branch to review and confirm it exists.

**Release:** Confirm all work item branches are merged. If any missing, stop and post comment listing missing branches.

**Epic:** Confirm all child task branches are merged into integration branch. If any missing, stop and post comment.

**Task:** Confirm task branch exists and is based on correct default branch.

**Bug:** Confirm bug fix branch exists and is based on correct default branch.

### CR3 — Baseline Verification

* Run the full build, all tests, and all linters/static analysis.
* **All checks must pass before continuing.** If anything fails, post a comment describing failures. Do not continue.
* **Bug only:** Confirm the regression test is present and passing.

### CR4 — Review the Diff

**REQUIRED:** Review the full diff covering ALL categories:

**CR4a — Code Quality and Standards**
* Code style, conventions, architectural patterns
* Code smells, anti-patterns, dead code, unnecessary complexity
* Error handling and logging
* Naming conventions
* Hardcoded values that should be configurable

**CR4b — Test Coverage and Quality**
* Every code change has corresponding test coverage
* Tests cover happy paths, edge cases, error scenarios
* Tests follow project's existing patterns
* Untested code paths identified
* Test assertions are meaningful
* **Bug only:** Regression test accurately reproduces original bug behavior

**CR4c — Documentation Completeness**
* All new/modified public APIs have inline documentation
* Documentation accurately describes current behavior
* Missing or incomplete documentation identified

**CR4d — Security and Performance**
* Security vulnerabilities (injection, exposed secrets, auth issues)
* Performance impacts (N+1 queries, unnecessary allocations, missing caching)
* Input validation and output encoding
* Sensitive data handling

**CR4e — Cross-Item Integration** (Release/Epic only)
* Conflicts, duplication, inconsistencies across work items
* Duplicate utilities, overlapping logic, divergent approaches
* Shared interfaces/models compatibility
* *Skip for Task/Bug — mark "N/A — single work item"*

### CR5 — Review Full Changed Files for Context

* For each modified file, review the full file to understand change in complete context.
* Identify issues not visible in diff alone:
  * Changes correct in isolation but inconsistent with rest of file
  * Missing updates to related code
  * Pre-existing issues that interact poorly with new changes

### CR6 — Verify Criteria

**Release/Epic:** For each work item, read acceptance criteria and trace code changes to confirm each is satisfied. Flag any unmet criteria.

**Task:** Read acceptance criteria and trace code changes. Verify implementation matches approved plan. Flag deviations and unmet criteria.

**Bug:** Read fix criteria and verify each is satisfied. Re-trace original steps to reproduce and confirm bug no longer occurs. Verify regression test would catch recurrence.

### CR7 — Ask Clarifying Questions

* Identify any ambiguities, gaps, or risks discovered during review.
* If there are clarifying questions: post them as a comment and **wait for answers before proceeding.**
* If none: post a comment stating "No clarifying questions — proceeding to CR8."

### CR8 — Compile Review Findings

**ALL fields below are REQUIRED.** Post a consolidated comment on this Jira issue containing:

* **Review Summary:** What was reviewed, review type, total scope
* **Criteria Verification:** Pass/Fail/Partial per work item or criterion with explanations
* **Code Quality Findings:** File, line/section, description, severity (Critical/Major/Minor/Suggestion)
* **Test Coverage Findings:** Affected area, gap description, severity
* **Documentation Findings:** File, what's missing/incorrect, severity
* **Security and Performance Findings:** File, description, severity
* **Cross-Item Integration Findings:** Affected work items, description, severity (or "N/A — single work item")
* **Contextual Findings:** From CR5, file, description, severity
* **Overall Assessment:**
  * **Approved** — No critical or major findings. Ready to merge.
  * **Approved with Minor Findings** — No critical/major, but minor issues exist. Can proceed; address in follow-up.
  * **Changes Required** — Critical or major findings exist. Must resolve before proceeding.
* **Consolidated Findings Count:** Total by severity

### CR9 — Create Remediation Task (If Applicable)

* If **Approved with Minor Findings** or **Changes Required:**
  1. Create a new Task under same Jira project
  2. Link to this review issue
  3. Populate with ALL findings requiring action, organized by severity
  4. Summary: `[PROJ-KEY] [Review Type] Code Review Remediation`

* If **Approved:** Post comment stating "No remediation task required — review approved with no actionable findings."

### CR10 — Notify

* Post a comment tagging the assignee/reporter with:
  * Overall assessment verdict
  * Link to CR8 findings comment
  * Remediation task key (if created in CR9)
