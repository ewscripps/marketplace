# REQUIREMENTS INTAKE WORKFLOW — EXECUTION CONTRACT

> **How this works:** The user invokes this workflow by asking the agent to begin defining a new requirement. The agent drives the entire process interactively — starting by asking the user questions to gather context, then working through research and synthesis phases, and finally creating a fully populated Jira Epic or Task with a pointer to the appropriate execution skill.

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute phases in strict sequential order (R0 through R6).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure in the chat. Do not continue.
5. Every required output must be presented in the chat before the phase is considered complete.
6. Do not create any Jira issue until R5 is reached and approved.

**Note:** Approval gates in this workflow are confirmed in the chat -- no Jira issue exists yet.

**APPROVAL GATE BEHAVIOR:** Approval gates are chat-scoped. If explicit approval is not captured before the session ends or context is lost, stop at the gate. On resume, re-present the latest plan, draft, or summary and ask for confirmation again. Never assume a pending approval was granted.

**CLARIFICATION RULE:** Do not assume anything. If required information is missing, ambiguous, conflicting, or underspecified, stop and ask the user for clarification before proceeding.

**KNOWLEDGE GRAPH SCOPE:** The knowledge graph in this workflow is session-scoped. It accumulates structured context across R0-R4 so that R5 can assemble a complete, grounded Jira issue description. All graph content must be fully materialized into the Jira card description before the session ends -- do not rely on the graph persisting to a future session.

**TOOL PREFERENCE:** Prefer native tools over Bash for filesystem work. All filesystem, search, and directory operations must stay within the current project directory.

- **File I/O (read, write, edit a known file):** Use native `Read`, `Write`, `Edit`.
- **File discovery (find files by name or pattern):** Use native `Glob`.
- **Content search (find text inside files):** Use native `Grep`. For symbolic code search (finding classes, methods, or callers), delegate to the `codebase-explorer` agent, which uses the Serena MCP server.
- **Directory operations (list, metadata, move, mkdir):** Use Bash (`ls`, `stat`, `mv`, `mkdir -p`).
- **Git:** Prefer MCP git tools (`git_status`, `git_add`, `git_commit`, `git_diff`, `git_diff_staged`, `git_diff_unstaged`, `git_log`, `git_show`, `git_create_branch`, `git_checkout`, `git_reset`) over running `git` via Bash. Use Bash only for git operations with no MCP equivalent (`git push`, `git pull`, `git merge`, `git worktree`, `git remote`, `git stash`, `git rebase`) and for running build, test, and lint commands.

**TASK TRACKING:** Always use task tracking (`TaskCreate`/`TaskUpdate`) so progress is visible throughout. Create tasks for the following logical groups at the start of the workflow, mark each `in_progress` when starting and `completed` when done:

- **Intake** (R0–R1): Gather context, Jira context review
- **Research** (R2–R3): Codebase analysis, clarifying questions
- **Synthesis & Creation** (R4–R6): Requirement synthesis, Jira issue creation/update, completion

---

### R0 — Intake

**DISCOVERY PRE-CHECK:** Before greeting the user, call `read_graph` to check the knowledge graph for a `discovery_summary` entity. If one is present:
1. Acknowledge it immediately: "I found a prior implementation discovery session for: **[topic]**. I'll use those findings as a head start — the codebase areas have already been explored. If this isn't the right context, just say so and I'll start fresh."
2. If the user confirms: add an observation `discovery_confirmed: true` to the `discovery_summary` entity. When asking intake questions in step 3 below, skip the "areas of the codebase you already know are involved" question — the discovery already covers it. Note that R2 (Codebase Analysis) will use the discovery findings and skip spawning new codebase-explorer agents.
3. If the user rejects: proceed with normal intake and do not reference the discovery summary again.

**Objective:** Greet the user and gather all context needed to begin the requirements workflow through natural conversation.

**Agent Actions:**

1. Introduce yourself and briefly explain what this workflow will do and what to expect (phases, approvals, end result).
    
2. Ask the user: **"What type of work is this? Feature, Tech Debt, Research, or Upkeep?"** Wait for the answer before continuing. This determines which question set to use below.

3. Ask the following questions **conversationally, one topic at a time.** Do not present questions as a form or list. Wait for each response before asking the next.

    **If Feature:**
    
    - What is the name of this feature?
    - Can you describe what you're trying to build or solve in a few sentences?
    - Who is requesting this, and what team are they on?
    - Is there an existing Jira Epic this should fall under? If so, what's the key?
    - Are there any areas of the codebase you already know are involved — repos, services, modules, or file paths?
    - Is there any additional context that would help define this requirement?
    - Has a Jira card already been created for this? If so, what's the issue key?
    
    **If Tech Debt:**
    
    - What is a short name or title for this tech debt item?
    - What is the current problem — what exists today that needs to be improved or replaced?
    - What is the impact of leaving this unaddressed?
    - Who identified this, and what team owns the affected area?
    - Are there any areas of the codebase you already know are involved?
    - Is there an existing Jira Epic this should be tracked under?
    - Is there any additional context that would help define this requirement?
    - Has a Jira card already been created for this? If so, what's the issue key?
    
    **If Research:**
    
    - What is a short name or title for this research item?
    - What is the specific question you're trying to answer or the uncertainty you're trying to resolve?
    - What prompted this investigation?
    - What would a successful outcome look like?
    - Is there a timebox for this research?
    - Who is requesting this, and what team are they on?
    - Is there an existing Jira Epic this should fall under?
    - Is there any additional context that would help scope the research?
    - Has a Jira card already been created for this? If so, what's the issue key?
    
    **If Upkeep:**
    
    - What is a short name or title for this upkeep item?
    - What needs to be done?
    - What is driving this work — scheduled maintenance, dependency constraint, compliance requirement, alert, or something else?
    - Who is requesting this, and what team are they on?
    - Is there an existing Jira Epic this should fall under?
    - Are there any areas of the codebase you already know are involved?
    - Is there any additional context that would help define this work?
    - Has a Jira card already been created for this? If so, what's the issue key?
4. After all questions are answered, summarize the gathered context back to the user in a clear, structured format.
    

> **USE KNOWLEDGE GRAPH:** After the R0 approval gate is confirmed, write the core work item to the knowledge graph. Create a `work_item` entity with name `work_item-<key>` where `<key>` is the existing Jira issue key (if provided) or a normalized slug of the title (lowercase, whitespace/punctuation → `-`, trimmed) prefixed with `intake-` (e.g. `work_item-intake-add-retry-logic`). Observations: `work_type` (feature / tech_debt / research / upkeep), `title`, `description`, `requested_by`, `existing_jira_key` (if provided). This is the root node — all subsequent phases will add linked nodes to it. R5 reads the full graph to assemble the Jira issue description. **Record the entity name** — it is the `work_item_id` passed to every `codebase-explorer` call in R2.

> **REQUIRED:** The following context must be confirmed before proceeding:
> 
> - Work Type (Feature / Tech Debt / Research / Upkeep)
> - Title or Name
> - Description or Problem Statement (2–4 sentences)
> - Requested By / Identified By (name / team)
> - Related Epic (Jira key, or explicitly "none")
> - Codebase Hints (specific areas, or explicitly "none provided" — N/A for Research)
> - Additional Context (links, notes, constraints, or explicitly "none provided")
> - Existing Jira Card (issue key, or explicitly "none")
> - For Tech Debt only: Impact of not addressing
> - For Research only: Expected deliverable and timebox
> - For Upkeep only: Driver (what is triggering this work)

> **APPROVAL GATE — FULL STOP.** Present the gathered context as a structured summary in the chat. User must confirm all fields are accurate and nothing is missing. Do not proceed to R1 until confirmed.

---

### R1 — Jira Context Review

**Objective:** Understand existing work, avoid duplication, and anchor the work item in the current project structure.

**Agent Actions:**

1. If an Existing Jira Card key was provided in R0, retrieve that issue immediately. Read its full description, any context already captured in the card (summary, acceptance criteria, labels, epic link, linked issues, and comment history). Surface all of this content in the context summary below.
2. If a Related Epic was provided in R0, retrieve its description, status, and all child issues.
3. Search Jira for existing issues that overlap with the work item using keyword and label search.
4. Identify any sibling Epics or themes that appear contextually related.

> **USE KNOWLEDGE GRAPH:** Write Jira context to the graph as linked nodes. If a related Epic exists, create an `epic` node with properties: `jira_key`, `title`, `status`, and link it to the `work_item` node with a `belongs_to` relationship. For each overlapping issue found, create a `related_issue` node with properties: `jira_key`, `title`, `status`, and link it. If an existing card was provided, add its captured context as properties on the `work_item` node.

> **REQUIRED:** Present all of the following in the chat before proceeding:
> 
> - If an existing card was provided: its full summary, description, and any context already captured
> - Summary of related Epic: title, status, stated goal (if applicable)
> - List of potentially overlapping issues: key, summary, status
> - Explicit confirmation that no duplicate issue already exists

> **APPROVAL GATE — FULL STOP.** Present the Jira context summary. User must confirm the existing card (if any) is correct, no duplicate exists, and the related Epic (if any) is correct. Do not proceed to R2 until confirmed.

---

### R2 — Codebase Analysis

**DISCOVERY PRE-CHECK:** Before spawning codebase-explorer agents, call `read_graph`. If a `discovery_summary` entity with the observation `discovery_confirmed: true` is present, codebase analysis is already complete:
1. Announce: "Codebase analysis is already complete from the prior discovery session. Using [N] affected areas identified in discovery."
2. Re-link the prior discovery's `exploration` entities to this work item: for each `exploration` linked to the discovery's `work_item-discovery-<slug>` node, create an additional `for` relation pointing at the new `work_item-<key>` node. This makes the explorer findings reachable from R4A's normal traversal without copying them.
3. Create an `affected_area` node for each area in the `affected_areas` observation of the `discovery_summary` entity. For each: set `name` = area path, `type` = module (default), `risk` = medium (default). Link each node to the `work_item` node. If the D2 synthesis text includes explicit risk levels for an area, use those instead of the default.
4. Use the `synthesis` observation from the `discovery_summary` entity as the codebase analysis content.
5. Skip Agent Actions steps 1–6 entirely. Present the synthesis as the codebase analysis and proceed directly to the approval gate.

**Objective:** Identify the code surfaces this work item will touch to ground scope and acceptance criteria in reality.

**Agent Actions:**

1. Identify all distinct areas of the codebase to explore based on the Codebase Hints from R0, the Related Epic from R1, and the work item description. Limit the scope of this exploration to the current project directory.
2. Invoke a `codebase-explorer` sub-agent in **parallel** for each distinct area in this project, providing:
    - The target area to explore
    - A question tailored to the work type:
        - **Feature:** "What code, patterns, and conventions are relevant to implementing [feature description] in this area?"
        - **Tech Debt:** "What is the current state of [problem area] — what exists today, why is it problematic, and what does the code look like?"
        - **Research:** "What existing code, architecture, or patterns in this area are relevant to the research question: [question]?"
        - **Upkeep:** "What components, dependencies, or configuration in this area will be touched by [upkeep work], and are there known compatibility constraints or rollback considerations?"
    - The `work_item_id` recorded at R0 (the entity name of the `work_item` node, e.g. `work_item-PROJ-123` or `work_item-intake-<slug>`). All findings the explorer streams to the graph will be linked to this node.
    - The work item description for context
3. Wait for all explorers to return their `EXPLORATION COMPLETE` (or `EXPLORATION FAILED`) pointers. The pointer reports counts of entities written; the findings themselves live in the graph.
4. Call `read_graph` and walk the subgraph rooted at each `exploration` entity for this `work_item_id`. Surface any `open_question` entities. If any open question identifies a connection to another area not already explored, dispatch a follow-up `codebase-explorer` for that area (passing the same `work_item_id`) before proceeding.
5. Synthesize the findings from the graph into a unified codebase analysis. Read across all `exploration` entities linked to this `work_item_id` and aggregate:
    - **Affected files** — collected from `affected_file` entities. Group by module / service for the user-facing analysis.
    - **Patterns and conventions** — from `pattern` entities; cite the `evidence_files` observation when present.
    - **Integration points** — from `integration_point` entities.
    - **Risks** — from `risk` entities, ordered by severity.
    - **Work-type-specific findings** — current state for Tech Debt, known areas for Research, compatibility notes for Upkeep — from the relevant `evidence` and `pattern` entities.
6. Label any items derived from `evidence` or `affected_file` observations marked `inferred: true` as `[INFERRED]` in the user-facing analysis.

> **USE KNOWLEDGE GRAPH:** After synthesizing, roll up the explorer-written `affected_file` entities into `affected_area` summary nodes that downstream phases (R4A) read. For each distinct file / module / service / schema / component, create an `affected_area` entity with observations: `name`, `type` (file / module / service / schema / component), `risk` (high / medium / low — taken from the highest-severity `risk` entity that links to any of its `affected_file`s, defaulting to `medium`), and any relevant notes. Mark entries derived only from `inferred: true` observations with `inferred: true`. Link each `affected_area` to the `work_item` node. The granular `affected_file` and `evidence` entities remain in the graph alongside — R4A may walk into them for fine-grained checks.

> **REQUIRED:** Present all of the following in the chat before proceeding:
> 
> - List of likely affected files / modules / services with rationale
> - Relevant existing patterns or conventions to follow
> - High-risk areas flagged with reasoning
> - Work-type-specific analysis (current state for Tech Debt, known areas for Research, compatibility notes for Upkeep)

> **REQUIRED: Review the codebase analysis before presenting.** Verify every item is grounded in actual evidence. Label speculative entries as `[INFERRED]`. Do not present an unreviewed analysis.

> **APPROVAL GATE — FULL STOP.** Present the codebase analysis. User must confirm scope areas are correct and complete. Do not proceed to R3 until confirmed.

---

### R3 — Stakeholder Q&A

**Objective:** Resolve all ambiguities required to write precise, actionable requirements.

**Agent Actions:**

1. Review all output from R0, R1, and R2.
    
2. > **USE SEQUENTIAL THINKING:** Before generating the question batch, invoke the `sequentialthinking` tool. Work through each question category below systematically, identify what has already been answered vs. what remains genuinely ambiguous, and ensure full coverage across all relevant categories before presenting the batch. Do not present questions until the reasoning is complete.
    
3. Generate clarifying questions. Use the categories relevant to the work type:
    
    **All work types:**
    
    - **Scope Boundary** — What is explicitly out of scope?
    - **Dependencies** — What does this work depend on or block?
    - **Non-Functional** — Performance, security, accessibility, or compliance expectations?
    
    **Feature only:**
    
    - **Functional** — What exactly should the feature do?
    - **Edge Cases** — What happens when X, Y, Z?
    - **User Impact** — Who uses this and how does it change their experience?
    
    **Tech Debt only:**
    
    - **Remediation Approach** — Is there a preferred approach or known constraints on how this should be fixed?
    - **Regression Risk** — What existing behavior must be preserved?
    - **Rollout** — Does this need to be done incrementally?
    
    **Research only:**
    
    - **Success Criteria** — What does a complete, useful answer look like?
    - **Constraints** — Are there any technical, time, or resource constraints?
    - **Audience** — Who will consume the output and make decisions based on it?
    - **Output Format** — Is there a required format for the deliverable?
    
    **Upkeep only:**
    
    - **Risk & Rollback** — What is the rollback plan? What is the blast radius?
    - **Testing** — How will the change be verified as safe?
    - **Scheduling** — Is there a required maintenance window or deadline?
4. Mark each question as `[BLOCKING]` or `[NICE TO HAVE]`.
    
5. Present all questions in a **single batch** — do not ask one at a time.
    
6. Record all answers verbatim. Do not infer or invent answers.
    

> **USE KNOWLEDGE GRAPH:** After answers are confirmed, write each Q&A pair to the graph. Create a `qa_item` node with properties: `question`, `answer`, `priority` (blocking / nice_to_have), `category` (scope_boundary / dependencies / functional / etc.). Link each node to the `work_item` node. R4A reads these nodes to derive traceable acceptance criteria.

> **REQUIRED:** Present all BLOCKING questions answered and answers recorded, and remaining unanswered questions listed as open items with owner and target resolution date.

> **APPROVAL GATE — FULL STOP.** Present all questions and recorded answers. User must confirm all blocking answers are accurate and open items are correctly captured. Do not proceed to R4 until confirmed.

---

### R4 — Requirements Synthesis

**Objective:** Translate all gathered context into acceptance criteria, a risk register, and a scoping recommendation.

---

#### R4A — Acceptance Criteria

> **USE SEQUENTIAL THINKING:** Before writing acceptance criteria, invoke the `sequentialthinking` tool. For each candidate criterion, verify it is: (1) **unambiguous** — only one possible interpretation, (2) **testable** — can be verified without further clarification, and (3) **traceable** — directly derived from an R3 answer or R2 finding. Work through each criterion in sequence and revise any that fail before presenting.

> **USE KNOWLEDGE GRAPH:** After criteria are finalized, write each one to the graph. Create a `criterion` node with properties: `text`, `format` (gherkin / outcome_based / deliverable_based), and `traceable_to` (the `qa_item` or `affected_area` node key it was derived from). Link each node to the `work_item` node. R5 reads these nodes to populate the Acceptance Criteria section verbatim.

Write acceptance criteria appropriate to the work type:

- **Feature:** Use **Gherkin format** (`Given / When / Then`) — one criterion per discrete behavior.
- **Tech Debt:** Use **outcome-based criteria** — describe the measurable state that must be true after the work is complete.
- **Research:** Use **deliverable-based criteria** — describe what must exist and what questions must be answered for the research to be considered complete.
- **Upkeep:** Use **outcome-based criteria** — describe the verifiable end state.

> **REQUIRED output:**
> 
> - Minimum 3 criteria covering the primary success state
> - At least 1 criterion per identified edge case, constraint, or regression risk from R3
> - Non-functional criteria included where applicable

---

#### R4B — Dependencies & Risks

1. List **hard dependencies** — Jira issues, services, or teams that must be resolved before this work can ship.
2. List **soft dependencies** — things that could delay or complicate delivery but are not blockers.
3. Build a risk register:

|Risk|Likelihood (H/M/L)|Impact (H/M/L)|Mitigation|
|---|---|---|---|
|[describe risk]|H / M / L|H / M / L|[proposed mitigation]|

---

#### R4C — Epic vs. Task Recommendation

> **USE SEQUENTIAL THINKING:** Before producing the recommendation, invoke the `sequentialthinking` tool. Evaluate the work item against each criterion in the table below explicitly and in sequence. Note any conflicting signals, apply the work-type guidance, and stress-test the conclusion before committing to a verdict.

Evaluate the work item against these criteria:

|Criterion|Points to Epic|Points to Task|
|---|---|---|
|Delivery scope|Multiple sprints or workstreams|Single sprint, single owner|
|Output|Multiple deliverable stories/subtasks|Single deliverable|
|Codebase surface|3+ distinct modules or services|1–2 focused areas|
|Stakeholder coordination|Cross-team or cross-functional|Single team|
|Ambiguity remaining|Significant open items|Well-defined, low uncertainty|

> **Guidance by work type:**
> 
> - **Research** always defaults to Task.
> - **Upkeep** defaults to Task unless the work spans multiple services or requires coordinated rollout.
> - **Tech Debt** defaults to Task unless remediation spans multiple services or requires a phased rollout.
> - **Feature** should be evaluated neutrally against the criteria above.

> **REQUIRED output:**
> 
> - Recommendation: **Epic** or **Task**, stated explicitly
> - Rationale: 2–4 sentences referencing the criteria above
> - If Epic: proposed child story breakdown (titles only, 3–6 stories)
> - If Task: confirmation that a single card is sufficient to contain all scope

---

> **REQUIRED: Review the full R4 synthesis before presenting.** Verify every acceptance criterion is unambiguous, testable, and traceable. Remove or revise any that fail this check. Do not present an unreviewed synthesis.

> **APPROVAL GATE — FULL STOP.** Present the full R4 synthesis (acceptance criteria, risk register, Epic vs. Task recommendation). User must confirm all three sections before proceeding. Do not create a Jira issue of the wrong type.

---

### R5 — Jira Issue Creation or Update

**Objective:** Create or update the Jira issue with all requirements and a pointer to the appropriate execution skill.

**Agent Actions:**

1. > **USE KNOWLEDGE GRAPH:** Read the full graph — `work_item`, `affected_area`, `qa_item`, `criterion`, `related_issue`, and `epic` nodes — to assemble the Jira issue description. Each section of the description maps directly to a node type. This ensures nothing is missed or invented and the description is fully grounded in the structured context built across R0–R4.
    
2. Assemble the Jira issue description using the requirements-only description structure matching the work type below. The description must contain only the structured delivery context for the work item. Do not append workflow instructions, skill-invocation text, or placeholder tokens.
    
3. Populate the following fields:

|Field|Source|
|---|---|
|Issue Type|Epic or Task per R4C|
|Summary|Title + core behavior or problem (max 10 words)|
|Description|Assembled per Description Structure below|
|Priority|Recommended based on risk and impact (see below)|
|Labels|Work type in lowercase + codebase area|
|Epic Link|Recommended epic (Task only — see below)|

    **Priority recommendation:** Before creating the issue, recommend a priority based on the risk register from R4B and the overall impact of the work item. Consider: user-facing impact, number of affected areas, dependency urgency, and whether this unblocks other work. Use Jira priority values: Critical, High, Medium, or Low. Present the recommended priority to the user for confirmation.

    **Epic recommendation (Task issue type only — skip for Epics):** If an epic was already confirmed in R1, present it as the recommendation. If no epic was confirmed, search Jira for open epics in the same project that relate to the affected areas, work type, or goals identified in R0-R4. Recommend the most relevant epic to the user. Present the recommendation and ask the user to: (a) accept the suggested epic, (b) provide a different epic key, or (c) leave blank for no epic. Only set the Epic Link if the user accepts or provides a key. If the user leaves it blank, do not set an Epic Link.

    **API notes for non-standard fields:**
    - **Priority:** Set via `additional_fields`: `{"priority": {"name": "Medium"}}` (substituting the confirmed priority name: Critical, High, Medium, or Low).
    - **Labels:** Set via `additional_fields`: `{"labels": ["label1", "label2"]}` on `createJiraIssue`.
    - **Epic Link:** Set via `additional_fields`: `{"epicKey": "EPIC-KEY"}` on `createJiraIssue`. Do not use `createIssueLink` for epic links — that creates a lateral link, not an epic association. Only include this field if the user confirmed an epic.

4. **Update-or-create decision:**
    - **If an existing Jira card was provided in R0:** Update that card's description using `editJiraIssue` with the approved description. Do not create a new issue.
    - **If no existing card was provided:** Create a new Jira issue using `createJiraIssue` with the approved description. Do not perform a follow-up description update solely to add execution instructions.

5. **Post-creation linking:** After the issue is created or updated, link hard dependencies from R4B by calling `createIssueLink` for each one. Use `link_type: "Blocks"` for hard dependencies. Do not attempt to set linked issues during `createJiraIssue` — that tool does not support it.

### Description Structure

**Feature:**

```
## Task Details

**Summary:** [Title from R0]

## Overview
[2-3 sentences: what the feature does and why it exists]

## Context
[Relevant background from Jira review and codebase analysis. Include any context
already captured in the existing Jira card retrieved in R1, if applicable.]

## Additional Context
[Links, notes, prior discussions, designs, constraints, or "None provided."]

## Affected Areas
[Structured list from R2 codebase analysis affected_area nodes. For each area:
file/module/service path, brief description of relevance, and risk level.]
- `[path]` -- [description] ([high/medium/low] risk)

## Scope
**In Scope:**
- [...]
**Out of Scope:**
- [...]

## Acceptance Criteria
[Gherkin format from R4A -- copy verbatim]

## Dependencies
**Hard:** - [PROJ-XXX] -- [description]
**Soft:** - [description]

## Risks
[Risk register table from R4B -- copy verbatim]

## Open Items
[Unresolved questions from R3 with owner and target resolution date, or
"None -- all blocking questions resolved."]
```

**Tech Debt:**

```
## Task Details

**Summary:** [Title from R0]

## Overview
[2-3 sentences: what the problem is and why it needs to be addressed]

## Current State
[Description of what exists today -- specific files, modules, patterns, or
behaviors that are problematic.]

## Impact of Not Addressing
[Consequences of leaving this unresolved]

## Additional Context
[Links, notes, prior remediation attempts, or "None provided."]

## Remediation Approach
[High-level description of how this will be fixed]

## Affected Areas
[Structured list from R2 codebase analysis affected_area nodes. For each area:
file/module/service path, brief description of relevance, and risk level.]
- `[path]` -- [description] ([high/medium/low] risk)

## Scope
**In Scope:** - [...]
**Out of Scope:** - [...]

## Acceptance Criteria
[Outcome-based criteria from R4A -- copy verbatim]

## Dependencies
**Hard:** - [PROJ-XXX] -- [description]
**Soft:** - [description]

## Risks
[Risk register table from R4B -- copy verbatim]

## Open Items
[Unresolved questions or "None -- all blocking questions resolved."]
```

**Research:**

```
## Task Details

**Summary:** [Title from R0]

## Overview
[2-3 sentences: what question is being investigated and why it matters]

## Research Question
[The specific question or uncertainty this research is intended to resolve]

## Background
[What prompted this investigation and what depends on the outcome]

## Additional Context
[Links, notes, prior investigations, or "None provided."]

## Timebox
[Time allocated, or "None defined."]

## Expected Deliverable
[The specific output required]

## Audience
[Who will consume this research and act on it]

## Affected Areas
[Structured list from R2 codebase analysis affected_area nodes, or
"N/A -- research task, no code areas directly affected."]

## Scope
**In Scope:** - [...]
**Out of Scope:** - [...]

## Acceptance Criteria
[Deliverable-based criteria from R4A -- copy verbatim]

## Dependencies
**Hard:** - [PROJ-XXX] -- [description]
**Soft:** - [description]

## Risks
[Risk register table from R4B -- copy verbatim]

## Open Items
[Unresolved questions or "None -- all blocking questions resolved."]
```

**Upkeep:**

```
## Task Details

**Summary:** [Title from R0]

## Overview
[2-3 sentences: what needs to be done and why]

## Driver
[What is triggering this work]

## Additional Context
[Version constraints, breaking changes, deadlines, or "None provided."]

## Affected Areas
[Structured list from R2 codebase analysis affected_area nodes. For each area:
file/module/service path, brief description of relevance, and risk level.]
- `[path]` -- [description] ([high/medium/low] risk)

## Compatibility & Rollback
[Known breaking changes, compatibility constraints, and rollback plan]

## Scope
**In Scope:** - [...]
**Out of Scope:** - [...]

## Acceptance Criteria
[Outcome-based criteria from R4A -- copy verbatim]

## Dependencies
**Hard:** - [PROJ-XXX] -- [description]
**Soft:** - [description]

## Risks
[Risk register table from R4B -- copy verbatim]

## Open Items
[Unresolved questions or "None -- all blocking questions resolved."]
```

---

> **REQUIRED: Review the full issue description before presenting.** Verify the correct description template was used, all fields are populated with no placeholder text, acceptance criteria match R4A output verbatim, the Affected Areas field is populated from R2 codebase analysis, no workflow instructions or skill-invocation text were embedded, and the issue type matches the R4C recommendation.

> **APPROVAL GATE — FULL STOP.** Present the fully assembled issue description in the chat for final review. User must confirm content is accurate and ready before creating or updating the Jira issue.

---

### R6 — Cleanup

- Clear the session-scoped knowledge graph before finishing the workflow. This includes the `work_item` entity and every entity linked to it: `affected_area`, `exploration`, `affected_file`, `evidence`, `pattern`, `integration_point`, `risk`, `open_question`, plus any `discovery_summary` consumed at R2 and any `classification_signal` / `code_evidence` carried over from issue-intake. Use `read_graph` to enumerate, then `delete_entities`. Do not leave requirements state in the graph after it has been fully materialized into the Jira issue.

---

## Completion Criteria

This workflow is complete when **all** of the following are true:

- All 7 phases executed in sequence (R0-R6)
- All 6 approval gates explicitly confirmed in the chat
- All self-review checks passed before presenting output
- Jira issue updated (existing card) or created (new card) with all requirements populated, no unresolved placeholder text, and no embedded workflow or skill-invocation instructions
- Task Details section includes a structured Affected Areas field populated from R2 codebase analysis
- R6 cleanup cleared the session-scoped knowledge graph after the Jira record was finalized
