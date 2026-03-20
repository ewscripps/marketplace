---
name: issue-intake
description: Triage an issue as Bug or Missing Requirement and create appropriate Jira card
user-invocable: true
argument-hint: ''
allowed-tools: Read, Grep, Glob, AskUserQuestion, mcp__atlassian__*
---

# Issue Intake Workflow

Guide the user through reporting an issue, classify it as Bug or Missing Requirement, and create the appropriate Jira card with execution workflow embedded.

## Usage

```
/issue-intake
```

---

## Agent Workflow

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute phases in strict sequential order (I0 through I5).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure in the chat. Do not continue.
5. Every required output must be presented in the chat before the phase is considered complete.
6. Do not create any Jira issue until I5 is reached and approved.

**Note:** Approval gates in this workflow are confirmed in the chat — no Jira issue exists yet.

---

### I0 — Intake

**Objective:** Gather all information about the unexpected or missing behavior through natural conversation.

**Agent Actions:**

1. Introduce yourself and explain what this workflow will do.
2. Ask questions conversationally, one topic at a time:

**Behavior description:**
* Short title/summary
* What were you doing when you encountered it?
* What did you expect to happen instead?
* Has this ever worked correctly before?

**Reproduction:**
* Can you reliably reproduce this? Steps?
* Every time or intermittent?
* Relevant logs, error messages, stack traces?

**Environment:**
* Environment tier (Production/Staging/Dev)
* OS and version, Browser and version (if applicable)
* Application version or build number

**Impact & context:**
* How many users/systems affected?
* Workaround available?
* Who reported this?
* Related Jira Epic or issue?
* Existing Jira card for this issue?

3. Summarize the gathered context.

**APPROVAL GATE — FULL STOP.**
Present gathered context. User must confirm all fields are accurate.

---

### I1 — Jira Context Review

**Objective:** Check for duplicates and anchor in project structure.

**Agent Actions:**

1. If existing Jira card provided, retrieve its full context.
2. Search for existing bugs/tasks that match or overlap.
3. Search for known issues or investigations in the same area.
4. If related Epic provided, retrieve its description and status.

**APPROVAL GATE — FULL STOP.**
Present Jira context summary. User must confirm no duplicate exists.

---

### I2 — Codebase Analysis

**Objective:** Determine whether code exists for the expected behavior.

**Agent Actions:**

1. Identify likely affected areas.
2. Determine whether code exists for the expected behavior:
   * **Yes** = evidence of Bug
   * **No** = evidence of Missing Requirement
3. Look for recent changes that may have introduced a regression.
4. Identify relevant error handling paths.
5. Analyze provided logs/exceptions/stack traces.

**APPROVAL GATE — FULL STOP.**
Present codebase analysis. User must confirm finding on whether code exists is accurate.

---

### I3 — Clarifying Questions

**Objective:** Resolve remaining ambiguities for confident classification.

**Agent Actions:**

1. Generate clarifying questions by category: History, Scope, Regression, Intent, Logs/Evidence
2. Mark each as `[BLOCKING]` or `[NICE TO HAVE]`.
3. Present all questions in a **single batch**.
4. Record all answers verbatim.

**APPROVAL GATE — FULL STOP.**
Present questions and answers. User must confirm blocking answers are accurate.

---

### I4 — Classification & Triage

#### I4A — Classification

Classify using these signals:

| Signal | Points to Bug | Points to Missing Requirement |
|--------|---------------|-------------------------------|
| Prior behavior | Worked before | Never existed |
| Code evidence | Code exists but defective | No code for this behavior |
| Regression signals | Recent change correlates | No regression signal |
| Specification | Documented in spec | No spec describes this |
| Logs/errors | Errors indicate fault | No errors — working as designed |
| User framing | "This broke" | "This should exist" |

**Classification outcomes:** Bug, Missing Requirement, or Ambiguous

#### I4B — Severity (Bug only)

| Severity | Criteria |
|----------|----------|
| Critical | System down, data loss, no workaround, affects all users |
| High | Core functionality broken, workaround difficult, affects significant users |
| Medium | Non-core impacted, workaround exists, affects subset |
| Low | Minor issue, easy workaround, cosmetic or edge-case |

**APPROVAL GATE — FULL STOP.**
Present classification and severity. User must confirm before proceeding.

---

### I5 — Resolution

#### Path A: Bug

1. Fetch Bug Workflow Template → Page ID `3406299154`
2. Write fix criteria (outcome-based acceptance criteria)
3. Construct Bug description with Summary, Observed/Expected Behavior, Steps to Reproduce, Environment, Severity, Workaround, Root Cause (if known), Fix Criteria, Open Items
4. Append full Bug Workflow Template as Execution Contract
5. Create or update Jira Bug issue

**APPROVAL GATE — FULL STOP.**
Present Bug description. User must confirm before creating/updating.

#### Path B: Missing Requirement

1. Inform user the issue is classified as a missing requirement.
2. Fetch Requirements Workflow Template → Page ID `3409608716`
3. Pre-populate R0 context from I0-I4 data.
4. Present pre-populated R0 summary for confirmation.
5. Resume Requirements Workflow from R1 through R5.

**APPROVAL GATE — FULL STOP.**
Present pre-populated R0 context. User must confirm before proceeding to R1.

---

## Completion Criteria

* All phases executed in sequence (I0-I5)
* All approval gates confirmed
* **Bug path:** Jira Bug created/updated with Bug Workflow embedded
* **Missing Requirement path:** Requirements Workflow completed through R5
