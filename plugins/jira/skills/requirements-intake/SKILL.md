---
name: requirements-intake
description: Define new requirements through guided conversation and create a Jira Epic or Task
user-invocable: true
argument-hint: '[feature|tech-debt|research|upkeep]'
allowed-tools: Read, Grep, Glob, AskUserQuestion, mcp__atlassian__*
---

# Requirements Intake Workflow

Guide the user through defining a new requirement and create a fully populated Jira Epic or Task with the appropriate execution workflow embedded.

## Usage

```
/requirements-intake
/requirements-intake feature
/requirements-intake tech-debt
```

---

## Agent Workflow

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute phases in strict sequential order (R0 through R5).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure in the chat. Do not continue.
5. Every required output must be presented in the chat before the phase is considered complete.
6. Do not create any Jira issue until R5 is reached and approved.

**Note:** Approval gates in this workflow are confirmed in the chat — no Jira issue exists yet.

---

### R0 — Intake

**Objective:** Gather all context needed to begin the requirements workflow through natural conversation.

**Agent Actions:**

1. Introduce yourself and briefly explain what this workflow will do.
2. Ask about Work Type: Feature / Tech Debt / Research / Upkeep
3. Based on the answer, gather context **conversationally, one topic at a time:**

**Feature:** Name, description, requestor/team, related Epic, codebase hints, additional context, existing Jira card

**Tech Debt:** Name, current problem, impact of not addressing, owner/team, codebase hints, related Epic, additional context, existing Jira card

**Research:** Name, question to answer, what prompted investigation, expected deliverable, timebox, requestor/team, related Epic, additional context, existing Jira card

**Upkeep:** Name, what needs to be done, driver (maintenance/dependency/compliance/alert), requestor/team, related Epic, codebase hints, additional context, existing Jira card

4. Summarize the gathered context back to the user.

**APPROVAL GATE — FULL STOP.**
Present the gathered context. User must confirm all fields are accurate before proceeding to R1.

---

### R1 — Jira Context Review

**Objective:** Understand existing work, avoid duplication, and anchor the work item in the current project structure.

**Agent Actions:**

1. If an existing Jira card was provided, retrieve and surface its full context.
2. If a related Epic was provided, retrieve its description, status, and child issues.
3. Search Jira for existing issues that overlap with the work item.
4. Identify related Epics or themes.

**APPROVAL GATE — FULL STOP.**
Present Jira context summary. User must confirm no duplicate exists and related Epic is correct.

---

### R2 — Codebase Analysis

**Objective:** Identify the code surfaces this work item will touch.

**Agent Actions:**

1. Identify likely affected areas: services, modules, APIs, DB schemas, UI components.
2. Note existing patterns, abstractions, or conventions relevant to this work.
3. Flag any high-risk or complex areas with explicit reasoning.
4. For Tech Debt: Document current state and remediation direction.
5. For Research: Identify existing code relevant to the research question.
6. For Upkeep: Identify compatibility constraints and rollback considerations.

**APPROVAL GATE — FULL STOP.**
Present codebase analysis. User must confirm scope areas are correct.

---

### R3 — Stakeholder Q&A

**Objective:** Resolve all ambiguities required to write precise, actionable requirements.

**Agent Actions:**

1. Generate clarifying questions by category (Scope, Dependencies, Non-Functional, plus type-specific questions).
2. Mark each as `[BLOCKING]` or `[NICE TO HAVE]`.
3. Present all questions in a **single batch**.
4. Record all answers verbatim.

**APPROVAL GATE — FULL STOP.**
Present all questions and recorded answers. User must confirm blocking answers are accurate.

---

### R4 — Requirements Synthesis

#### R4A — Acceptance Criteria

* **Feature:** Gherkin format (Given / When / Then)
* **Tech Debt:** Outcome-based criteria
* **Research:** Deliverable-based criteria
* **Upkeep:** Outcome-based criteria

#### R4B — Dependencies & Risks

* List hard and soft dependencies
* Build risk register with Likelihood, Impact, and Mitigation

#### R4C — Epic vs. Task Recommendation

Evaluate against: Delivery scope, Output, Codebase surface, Stakeholder coordination, Ambiguity remaining

* Research always defaults to Task
* Upkeep defaults to Task unless spanning multiple services
* Tech Debt defaults to Task unless phased rollout needed
* Feature evaluated neutrally

**APPROVAL GATE — FULL STOP.**
Present full R4 synthesis. User must confirm acceptance criteria, risk register, and Epic vs. Task recommendation.

---

### R5 — Jira Issue Creation or Update

**Objective:** Fetch the correct workflow template and create/update the Jira issue.

**Agent Actions:**

1. Fetch the appropriate workflow template:
   * **Epic** → Page ID `3407249426`
   * **Task** → Page ID `3408461838`

2. Assemble the description with Requirements section + Execution Contract (workflow template)

3. Populate fields: Issue Type, Summary, Description, Labels, Epic Link, Linked Issues

4. **Update-or-create:**
   * If existing card provided: Update that card
   * If no existing card: Create new Jira issue

**APPROVAL GATE — FULL STOP.**
Present fully assembled issue description. User must confirm before creating/updating.

---

## Completion Criteria

* All 6 phases executed in sequence (R0-R5)
* All 6 approval gates explicitly confirmed
* Jira issue created/updated with no placeholder text
* Correct workflow template embedded unmodified
