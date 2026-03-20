---
name: code-review-setup
description: Set up a code review by creating a Jira Code Review issue with Review Details
user-invocable: true
argument-hint: '[release|epic|task|bug]'
allowed-tools: Bash(git *), Read, Grep, Glob, AskUserQuestion, mcp__atlassian__*
---

# Code Review Intake Workflow

Guide the user through setting up a code review, verify the Jira issue and branch exist, and create a fully populated Jira Code Review issue with the Code Review Workflow execution contract embedded.

## Usage

```
/code-review-setup
/code-review-setup release
/code-review-setup task
```

---

## Agent Workflow

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute phases in strict sequential order (CI0 through CI5).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure in the chat. Do not continue.
5. Every required output must be presented in the chat before the phase is considered complete.
6. Do not create any Jira issue until CI5 is reached and approved.

**Note:** Approval gates in this workflow are confirmed in the chat — no Jira issue exists yet.

---

### CI0 — Intake

**Objective:** Gather all context needed to set up the code review through natural conversation.

**Agent Actions:**

1. Introduce yourself and explain what this workflow will do.
2. Ask: What type of work is being reviewed? (Release / Epic / Task / Bug)
3. Gather context conversationally:

**All review types:**
* Branch to review
* Default branch to diff against
* Review goals
* Known risks or areas of concern
* Existing Jira card for this code review

**Release only:**
* Release name (e.g., v2.4.0)
* Jira project key

**Epic, Task, Bug:**
* Jira issue key for the item being reviewed

4. Summarize the gathered context.

**APPROVAL GATE — FULL STOP.**
Present gathered context. User must confirm all fields are accurate.

---

### CI1 — Jira Context Review

**Objective:** Retrieve the review target and all associated work items from Jira.

**Agent Actions:**

1. If existing code review card provided, retrieve its full context.
2. Based on Review Type:

**Release:**
* Retrieve all issues with `fixVersion = "release name"`
* Read each issue's description and acceptance criteria
* Flag issues missing acceptance criteria

**Epic:**
* Retrieve epic and confirm it is an Epic
* Read description, goals, acceptance criteria, comment history
* Retrieve all child issues with `parent = epicKey`
* Flag issues missing acceptance criteria

**Task:**
* Retrieve and confirm it is a Task
* Read description, acceptance criteria, implementation plan from comments

**Bug:**
* Retrieve and confirm it is a Bug
* Read description, fix criteria, steps to reproduce, fix plan from comments
* Note required regression tests

**APPROVAL GATE — FULL STOP.**
Present Jira context summary. User must confirm the retrieved issue/release is correct.

---

### CI2 — Branch Verification

**Objective:** Confirm the branch exists and is in a reviewable state.

**Agent Actions:**

1. Confirm the branch to review exists.
2. Confirm the default branch exists.
3. Confirm there are commits to review beyond the default branch.
4. **Release/Epic only:** Confirm all work item branches are merged. List any missing.

**APPROVAL GATE — FULL STOP.**
Present branch verification. User must confirm branch state is correct.

---

### CI3 — Clarifying Questions

**Objective:** Surface remaining ambiguities affecting scope or depth of review.

**Agent Actions:**

1. Generate clarifying questions by category:

**All types:** Scope exclusions, Project-specific standards, Focus areas (security, performance, etc.)

**Release:** Readiness, Deployment concerns

**Epic:** Integration points, Scope drift

**Task:** Plan deviations

**Bug:** Regression risk, Test coverage

2. Mark each as `[BLOCKING]` or `[NICE TO HAVE]`.
3. Present all questions in a **single batch**.
4. Record all answers verbatim.

**APPROVAL GATE — FULL STOP.**
Present questions and answers. User must confirm blocking answers are accurate.

---

### CI4 — Review Setup

**Objective:** Assemble the fully populated Review Details block.

**Agent Actions:**

Assemble Review Details:

```
## Review Details

**Review Type:** [Release / Epic / Task / Bug]

**Release Name** (Release only): [release name]

**Jira Issue Key** (Epic/Task/Bug only): [issue key]

**Branch to Review:** [branch name]

**Default Branch:** [default branch]

**Review Goals:** [goals from CI0 and CI3]

**Work Items Included** (Release/Epic only):
[KEY — Summary (Status) for each item]

**Known Risks or Areas of Concern:**
[consolidated risks or "None identified"]
```

**APPROVAL GATE — FULL STOP.**
Present Review Details. User must confirm all fields are accurate.

---

### CI5 — Jira Issue Creation or Update

**Objective:** Fetch the Code Review Workflow template and create/update the Jira issue.

**Agent Actions:**

1. Fetch Code Review Workflow Template → Page ID `3408134156`

2. Construct Jira issue description:
   * Section 1: Review Details from CI4
   * Section 2: Code Review Workflow Template (unmodified)

3. Populate fields:
   * Issue Type: Task
   * Summary: `Code Review: [Review Type] — [Release Name or Issue Key]`
   * Labels: `code-review` + review type in lowercase
   * Linked Issues: Link to issue being reviewed (Epic/Task/Bug only)

4. **Update-or-create:**
   * If existing card provided: Update that card
   * If no existing card: Create new Jira issue

**APPROVAL GATE — FULL STOP.**
Present fully assembled issue description. User must confirm before creating/updating.

---

## Completion Criteria

* All 6 phases executed in sequence (CI0-CI5)
* All 6 approval gates confirmed
* Jira Code Review issue created/updated with Review Details populated
* Code Review Workflow Template embedded unmodified
* Review target linked to Code Review issue
