# REQUIREMENTS INTAKE WORKFLOW — EXECUTION CONTRACT

> **How this works:** This workflow operates in two modes. In **define mode** (no Jira key argument), the agent drives an interactive process — gathering context, researching, synthesizing, and creating a new fully populated Jira Epic or Task. In **fill-out mode** (a Jira key was passed as `$ARGUMENTS`), the agent fleshes out the description of an existing card. If that card is an Epic with child tasks, it iterates each child interactively after updating the parent. In both modes the same R0-R6 phase sequence applies.

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute phases in strict sequential order (R0 through R6).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure in the chat. Do not continue.
5. Every required output must be presented in the chat before the phase is considered complete.
6. Do not create or update any Jira issue until R5 is reached and approved.

**Note:** Approval gates in this workflow are confirmed in the chat. In define mode, no Jira issue exists until R5 creates it. In fill-out mode, the existing issue is not updated until R5 approval.

**APPROVAL GATE BEHAVIOR:** Approval gates are chat-scoped. If explicit approval is not captured before the session ends or context is lost, stop at the gate. On resume, re-present the latest plan, draft, or summary and ask for confirmation again. Never assume a pending approval was granted.

**CLARIFICATION RULE:** Do not assume anything. If required information is missing, ambiguous, conflicting, or underspecified, stop and use `AskUserQuestion` to ask the user for clarification before proceeding.

**KNOWLEDGE GRAPH SCOPE:** The knowledge graph in this workflow is session-scoped. It accumulates structured context across R0-R4 so that R5 can assemble a complete, grounded Jira issue description. All graph content must be fully materialized into the Jira card description before the session ends -- do not rely on the graph persisting to a future session.

**TOOL PREFERENCE:** Prefer native tools over Bash for filesystem work. All filesystem, search, and directory operations must stay within the current project directory.

- **File I/O (read, write, edit a known file):** Use native `Read`, `Write`, `Edit`.
- **File discovery (find files by name or pattern):** Use native `Glob`.
- **Content search (find text inside files):** Use native `Grep`. For symbolic code search (finding classes, methods, or callers), delegate to the `codebase-explorer` agent, which uses the Serena MCP server.
- **Directory operations (list, metadata, move, mkdir):** Use Bash (`ls`, `stat`, `mv`, `mkdir -p`).
- **Git:** Use Bash for all git operations (`git status`, `git diff`, `git log`, `git push`, `git pull`, `git merge`, `git remote`, `git stash`, `git rebase`, etc.) and for running build, test, and lint commands.

**SERENA PROJECT ACTIVATION:** Before R0, check Serena's project-activation message (emitted on connect via `--project-from-cwd`); if it reports that onboarding has not been performed, call `onboarding` to scope Serena's language server to the current project directory. Serena's symbol tools (`find_symbol`, `find_referencing_symbols`, `get_symbols_overview`, `search_for_pattern`) and any symbol-aware operations invoked by the `codebase-explorer` agent depend on this being done. Do this once at the start of the workflow; do not repeat it between phases.

**TASK TRACKING:** Always use task tracking (`TaskCreate`/`TaskUpdate`) so progress is visible throughout. Create one task per phase at the start of the workflow. Mark each task `in_progress` when starting the phase and `completed` when the phase is done:

- R0 — Intake
- R1 — Jira Context Review
- R2 — Codebase Analysis
- R3 — Stakeholder Q&A
- R4 — Requirements Synthesis
- R5 — Jira Issue Creation or Update
- R6 — Cleanup

**PHASE COMPACTION HANDOFF CONTRACT:** At designated compaction gates in this workflow, the agent writes a durable `phase_handoff` entity to the knowledge graph and prompts the user to run `/compact`. This prevents auto-compaction from discarding phase position, particularly in long fill-out + Epic runs with per-child loops.

**Steps at each gate — execute before instructing `/compact`:**

1. Wait for any background `area-mapper` sub-agent to complete.
2. Create a `phase_handoff` entity in the knowledge graph:
   - **Name:** `phase-handoff-<work-item-key>-<phase-id>` (e.g. `phase-handoff-PROJ-123-R4`); use the `work_item_id` recorded at R0. For R5B per-child gates: `phase-handoff-<work-item-key>-R5B-<child-JIRA-KEY>`.
   - **Observations:** `phase: <id>`, `skill: requirements-intake`, `jira_key: <key or slug>`, `mode: <define or fill_out>`, one `decisions: <text>` observation per key decision made this phase, `approval_condition: <verbatim user phrasing or "none">`, `next_phase: <id>`, one `open_items: <text>` per open item. For R5B per-child gates only: `child_completed: <JIRA-KEY>`, `next_child: <JIRA-KEY or "none">`.
   - **Relations:** `BELONGS_TO` → the `work_item` entity for this run; `SUPERSEDES` → prior `phase_handoff` for this work item (if any); `REFERENCES` → relevant `affected_area`, `exploration`, `criterion`, and `qa_item` entity names.
3. Call `open_nodes` on the new entity and each `REFERENCES` target to confirm writes landed.
4. Emit the Phase Summary block in the chat. The block must contain: phase ID and skill name, work item key, mode, one-line decision summary, verbatim approval condition, next phase ID, handoff entity name, and resume contract ("open_nodes on handoff entity → traverse REFERENCES → continue at `<next-phase>`"). For R5B gates: include child completion status. End your turn immediately after the Phase Summary block — do not add any further content. The block must end with this literal line: **"Run `/compact` now, then type `continue` to resume."** Do NOT call `AskUserQuestion` here; the user must be free to run `/compact` in the prompt input without any open question consuming their input. When the user next types `continue` (or any message clearly indicating compaction is done), call `open_nodes` on the `phase_handoff` entity, traverse its `REFERENCES`, and resume at `next_phase`. Before executing the resumed phase, **re-read that phase's section in this skill's `workflow.md`** so its full instructions survive compaction — in particular, any phase that asks the user clarifying or structured questions MUST use `AskUserQuestion` (per the Clarification Rule), never plain text. If the user types a different message instead, handle it normally.

**Cleanup:** Include all `phase_handoff` entities for this work item (prefix `phase-handoff-<work-item-key>-`) in the R6 cleanup enumeration alongside other session-scoped entities.

---

### R0 — Intake

**MODE DETECTION:** Before anything else, inspect `$ARGUMENTS`. If it contains a value matching the pattern `[A-Z][A-Z0-9_]+-\d+` (a Jira issue key), enter **fill-out mode**:
- Record the key as the target for this run. Skip the discovery pre-check (moot when we already know which card to update). Skip step 2 (work type) and step 3 below if the work type can be inferred from the existing card's issue type and description shape — you will confirm it in R1 instead.
- Skip the "Has a Jira card already been created for this?" question in step 3 entirely — the answer is already known.
- Questions whose answers can be read from the existing card (e.g. title, summary, requestor) should be pre-filled from the card's content and confirmed with the user rather than re-asked from scratch.

If `$ARGUMENTS` is empty or absent, enter **define mode** and run R0 exactly as written below.

**DISCOVERY PRE-CHECK:** Before greeting the user (or, in fill-out mode, before presenting the fill-out context summary), call `read_graph` to check the knowledge graph for any entity whose name starts with `discovery_summary-` (the implementation-discovery skill names them `discovery_summary-<topic-slug>` so multiple discoveries in one session do not collide).
1. **If exactly one is present:** acknowledge it immediately: "I found a prior implementation discovery session for: **[topic]** (chosen approach: **[chosen_approach]**, verification: **[verification_status]**). I'll use those findings as a head start — the codebase areas have already been explored and verified. If this isn't the right context, just say so and I'll start fresh."
2. **If multiple are present** (the user ran more than one discovery in this session): list them by `topic` and `chosen_approach`, then use `AskUserQuestion` (Header: `Discovery Pick`, Question: `Multiple discovery sessions were found. Which one is this requirements run for?`, Options: one option per discovery summary labeled `[topic] — [chosen_approach]`, plus `Start fresh — ignore all discoveries`) to ask the user which one to use. Treat the user's pick as the selected `discovery_summary-<slug>`; ignore the others for this run.
3. **If the user confirms a discovery summary:** add an observation `discovery_confirmed: true` to that specific `discovery_summary-<slug>` entity (not to any other). When asking intake questions in step 3 below, skip the "areas of the codebase you already know are involved" question — the discovery already covers it. Note that R2 (Codebase Analysis) will use the discovery findings and skip spawning new codebase-explorer agents.
4. **If the user rejects** (or no discovery summary exists): proceed with normal intake and do not reference the discovery summary again.

**Objective:** Greet the user and gather all context needed to begin the requirements workflow through natural conversation.

**Agent Actions:**

1. Introduce yourself and briefly explain what this workflow will do and what to expect (phases, approvals, end result).
    
2. Use `AskUserQuestion` to ask the work type (Header: `Work Type`, Question: `What type of work is this?`, Options: `Feature` — a new capability or user-facing behavior (acceptance criteria will be written in Gherkin), `Maintenance` — improving, fixing, updating, replacing, or maintaining something that already exists: tech debt, refactors, dependency updates, compliance, or scheduled upkeep (outcome-based acceptance criteria)). Wait for the answer before continuing. This determines which question set to use below. (For open-ended *investigation* before a build decision, that is `/implementation-discovery`, not an intake work type.)

3. Gather the feature or maintenance details in this order:

   **a. Name (via `AskUserQuestion`).**  
   - Feature: `AskUserQuestion` (Header: `Feature Name`, Question: `What is the name of this feature?`)  
   - Maintenance: `AskUserQuestion` (Header: `Item Name`, Question: `What is a short name or title for this maintenance item?`)

   **b. Primary description — ask conversationally, not via `AskUserQuestion`.**  
   The `AskUserQuestion` free-text field is cramped and discourages detail; a conversational prompt gives the user the full prompt input to write as much as they need. Send the appropriate message below, then **end your turn and wait** for the user's reply before continuing.

   - Feature: *"Now describe what you're trying to build or solve. Include as much detail as you have — the goal or problem being addressed, who benefits, the expected outcome, scope, constraints, dependencies, and any relevant context. The more you share, the better the requirements will be defined."*
   - Maintenance: *"Now describe what needs to be done. Include what currently exists and its problems, the expected end state, what specific changes or work are required, and any constraints or dependencies. The more detail you provide, the more precisely the work can be scoped."*

   **c. Sufficiency check.** Before continuing, assess whether the description is detailed enough to define the work clearly — it should cover the goal or problem, the expected outcome, and at least some scope. If it's thin (a single short sentence, missing the "why," or no expected outcome), ask 1–3 targeted follow-up questions to fill the specific gaps. Do not pad a thin description yourself; draw the missing detail out of the user. If the description is already sufficient, proceed immediately.

   **d. Remaining structured questions (via `AskUserQuestion`, one call per question).** Use a short descriptive Header (≤12 chars); for yes/no questions use `Yes, I'll provide it` / `No`; for open-ended free-text questions use 2–3 reasonable options (Other always available).

   **If Feature:**
   - Who is requesting this, and what team are they on?
   - Is there an existing Jira Epic this should fall under? If so, what's the key?
   - Are there any areas of the codebase you already know are involved — repos, services, modules, or file paths?
   - Is there any additional context that would help define this requirement?
   - Has a Jira card already been created for this? If so, what's the issue key?

   **If Maintenance:**
   - What is driving this work — tech-debt cleanup, refactor, scheduled maintenance, dependency constraint, compliance requirement, alert, or something else?
   - What is the impact of leaving this unaddressed?
   - Who identified or is requesting this, and what team owns the affected area?
   - Are there any areas of the codebase you already know are involved?
   - Is there an existing Jira Epic this should be tracked under?
   - Is there any additional context that would help define this work?
   - Has a Jira card already been created for this? If so, what's the issue key?

4. After all questions are answered, summarize the gathered context back to the user in a clear, structured format.
    

> **USE KNOWLEDGE GRAPH:** After the R0 approval gate is confirmed, write the core work item to the knowledge graph. Create a `work_item` entity with name `work_item-<key>` where `<key>` is the existing Jira issue key (if provided via `$ARGUMENTS` or step 3) or a normalized slug of the title (lowercase, whitespace/punctuation → `-`, trimmed) prefixed with `intake-` (e.g. `work_item-intake-add-retry-logic`). Observations: `work_type` (feature / maintenance), `title`, `description`, `requested_by`, `existing_jira_key` (if provided), `mode` (define / fill_out), `existing_issue_type` (Epic / Task — fill-out mode only, populated after R1 retrieves the card). This is the root node — all subsequent phases will add linked nodes to it. R5 reads the full graph to assemble the Jira issue description. **Record the entity name** — it is the `work_item_id` passed to every `codebase-explorer` call in R2.

> **REQUIRED:** The following context must be confirmed before proceeding:
> 
> - Work Type (Feature / Maintenance)
> - Title or Name
> - Description or Problem Statement (capture in full — do not summarize or truncate the user's input)
> - Requested By / Identified By (name / team)
> - Related Epic (Jira key, or explicitly "none")
> - Codebase Hints (specific areas, or explicitly "none provided")
> - Additional Context (links, notes, constraints, or explicitly "none provided")
> - Existing Jira Card (issue key from `$ARGUMENTS` or step 3, or explicitly "none" for define mode)
> - For Maintenance: Driver (what is triggering this work) and impact of not addressing

> **APPROVAL GATE — FULL STOP.** Present the gathered context as a structured summary. Use `AskUserQuestion` (Header: `R0 Approval`, Question: `Does the context summary above accurately capture what you want to define? Are all fields correct and complete?`, Options: `Approve and proceed (Recommended)` — all fields are accurate and nothing is missing, `Request changes` — some fields need correction). Do not proceed to R1 until the user approves.

---

### R1 — Jira Context Review

**Objective:** Understand existing work, avoid duplication, and anchor the work item in the current project structure.

**Agent Actions:**

1. If an Existing Jira Card key was provided in R0 (or via `$ARGUMENTS`), retrieve that issue immediately using `jira_get_issue`. Read its full description, any context already captured in the card (summary, acceptance criteria, labels, epic link, linked issues, and comment history). Surface all of this content in the context summary below. Determine the issue type: Epic or Task. Update the `existing_issue_type` observation on the `work_item` node.

2. **Fill-out mode — Epic with children.** If the existing card is an Epic, also enumerate its child tasks: call `jira_search` with JQL `parent = "<EPIC-KEY>"`. If that returns no results, also try `"Epic Link" = <EPIC-KEY>`. For each child found, call `jira_get_issue` to read the full description and capture: `key`, `summary`, `status`, and which work-type-template sections (Overview, Acceptance Criteria, Affected Areas, Scope, etc.) are already present. Write each child as a `child_work_item-<KEY>` entity in the graph with observations: `parent_epic`, `jira_key`, `summary`, `status`, `existing_sections_present` (comma-separated list of section headings found), `existing_sections_missing` (sections in the appropriate work-type template that are absent or stub-only). These nodes drive the per-child loop at R5B.

3. If a Related Epic was provided in R0 (define mode, or as context for a Task fill-out), retrieve its description, status, and all child issues.
4. Search Jira for existing issues that overlap with the work item using keyword and label search.
5. Identify any sibling Epics or themes that appear contextually related.

> **USE KNOWLEDGE GRAPH:** Write Jira context to the graph as linked nodes. If a related Epic exists, create an `epic` node with properties: `jira_key`, `title`, `status`, and link it to the `work_item` node with a `belongs_to` relationship. For each overlapping issue found, create a `related_issue` node with properties: `jira_key`, `title`, `status`, and link it. If an existing card was provided, add its captured context as properties on the `work_item` node. For fill-out + Epic: the `child_work_item-<KEY>` entities created in step 2 are already linked to the `work_item` node.

> **REQUIRED:** Present all of the following in the chat before proceeding:
> 
> - If an existing card was provided: its full summary, description, issue type, and any context already captured.
> - If an existing Epic with children (fill-out mode): a table of existing child issues — key, summary, status, and a note on which template sections are already present vs. missing.
> - Summary of related Epic: title, status, stated goal (if applicable)
> - List of potentially overlapping issues: key, summary, status
> - Explicit confirmation that no duplicate issue already exists

> **APPROVAL GATE — FULL STOP.** Present the Jira context summary. Use `AskUserQuestion` (Header: `R1 Approval`, Question: `Does the Jira context look correct? Is the existing card (if any) right, is there no duplicate, and is the related Epic (if any) correct?`, Options: `Approve and proceed (Recommended)` — Jira context is correct, `Request changes` — something needs correction). Do not proceed to R2 until the user approves.

---

### R2 — Codebase Analysis

**DISCOVERY PRE-CHECK:** Before spawning codebase-explorer agents, call `read_graph`. If a `discovery_summary-<slug>` entity with the observation `discovery_confirmed: true` is present (set during R0), codebase analysis is already complete:
1. **Announce:** "Codebase analysis is already complete from the prior discovery session for `[chosen_approach]` (verification status: [verification_status]). Using [N] affected areas identified in discovery." If `verification_status` is `accepted_with_open_questions`, also surface a one-line note that open questions from verification are carried into this intake.
2. **Re-link explorations to this work item, filtering superseded entities.** For each `exploration` entity linked to the discovery's `work_item-discovery-<slug>` node (both first-round and verification-round, distinguished by the `round` observation), create an additional `for` relation pointing at the new `work_item-<key>` node so explorer findings are reachable from R4A's normal traversal. **Do not** re-link any individual finding entity (`evidence`, `pattern`, `integration_point`, `risk`, `affected_file`, `open_question`) that carries the observation `superseded: true` — those were contradicted at D4 and the verification round wrote replacement entities. R4A traversal must walk the linked subgraph and skip every entity tagged `superseded: true` before consuming evidence.
3. **Create `affected_area` nodes from the discovery_summary.** For each area in the `affected_areas` observation: set `name` = area path, `type` = module (default), `risk` = medium (default). Link each node to the new `work_item` node. If the `synthesis_chosen` text includes explicit risk levels for an area, use those instead of the default. (Recall that `affected_areas` was pruned at D5 to the chosen approach; do not pull in unchosen-option areas from `synthesis_full`.)
4. **Use `synthesis_chosen` as the codebase analysis content** — NOT `synthesis_full`. The `synthesis_full` observation carries unchosen options for a `multiple_options` run and is retained for record only; using it would leak rejected-option evidence into requirements. `synthesis_chosen` is the canonical human-readable analysis for this intake and reflects any D4 revisions.
5. **Surface open questions as structured input to R3 / R4.** Walk the discovery subgraph for `open_question` entities linked (via `contains`) to `work_item-discovery-<slug>`. Each one — both D3-origin (`source: d3_discussion`) and D4-origin (`source: d4_verification`) — should be carried into this intake as a candidate clarifying question for R3 and as a candidate risk for R4. The `open_questions` string observation on `discovery_summary-<slug>` is a human-readable index of the same set; the entities are canonical and should be preferred.
6. Skip Agent Actions steps 1–6 entirely. Present the `synthesis_chosen` as the codebase analysis and proceed directly to the approval gate.

**Objective:** Identify the code surfaces this work item will touch to ground scope and acceptance criteria in reality.

**Agent Actions:**

1. Identify all distinct areas of the codebase to explore based on the Codebase Hints from R0, the Related Epic from R1, and the work item description. Limit the scope of this exploration to the current project directory.
2. Invoke a `codebase-explorer` sub-agent in **parallel** for each distinct area in this project, providing:
    - The target area to explore
    - A question tailored to the work type:
        - **Feature:** "What code, patterns, and conventions are relevant to implementing [feature description] in this area?"
        - **Maintenance:** "What is the current state of [problem area] — what exists today, why does it need to change, what components/dependencies/configuration will be touched, and are there compatibility or rollback considerations?"
    - The `work_item_id` recorded at R0 (the entity name of the `work_item` node, e.g. `work_item-PROJ-123` or `work_item-intake-<slug>`). All findings the explorer streams to the graph will be linked to this node.
    - The work item description for context
3. Wait for all explorers to return. Each non-failed return contains an `Entity:` line with the exploration entity name. Treat `INCOMPLETE` as partial: findings are present but the run did not finish; consider re-spawning for the same area if coverage matters. Treat `FAILED` as no findings written — re-spawn that explorer before proceeding.

> **POST-EXPLORATION ENRICHMENT:** Spawn the `area-mapper` sub-agent **in the background** (`run_in_background: true`) with the same `work_item_id`. The mapper crystallizes durable area knowledge from this run's graph into Serena project memory so future explorations of the same areas start with hot context. Do not wait for it — proceed immediately to step 4.
4. Call `open_nodes` on each `exploration` entity name from the returns. If any entity comes back empty, re-spawn that explorer rather than treating missing data as confirmed. Surface any `open_question` entities in the responses. If any identifies a connection to another area not already explored, dispatch a follow-up `codebase-explorer` for that area (passing the same `work_item_id`) before proceeding.
5. Synthesize the findings from the graph into a unified codebase analysis. Read across all `exploration` entities linked to this `work_item_id` and aggregate:
    - **Affected files** — collected from `affected_file` entities. Group by module / service for the user-facing analysis.
    - **Patterns and conventions** — from `pattern` entities; cite the `evidence_files` observation when present.
    - **Integration points** — from `integration_point` entities.
    - **Risks** — from `risk` entities, ordered by severity.
    - **Work-type-specific findings** — for Maintenance, the current state of the affected area plus any compatibility/rollback considerations — from the relevant `evidence` and `pattern` entities.
6. Label any items derived from `evidence` or `affected_file` observations marked `inferred: true` as `[INFERRED]` in the user-facing analysis.

> **USE KNOWLEDGE GRAPH:** After synthesizing, roll up the explorer-written `affected_file` entities into `affected_area` summary nodes that downstream phases (R4A) read. For each distinct file / module / service / schema / component, create an `affected_area` entity with observations: `name`, `type` (file / module / service / schema / component), `risk` (high / medium / low — taken from the highest-severity `risk` entity that links to any of its `affected_file`s, defaulting to `medium`), and any relevant notes. Mark entries derived only from `inferred: true` observations with `inferred: true`. Link each `affected_area` to the `work_item` node. The granular `affected_file` and `evidence` entities remain in the graph alongside — R4A may walk into them for fine-grained checks.

> **REQUIRED:** Present all of the following in the chat before proceeding:
> 
> - List of likely affected files / modules / services with rationale
> - Relevant existing patterns or conventions to follow
> - High-risk areas flagged with reasoning
> - Work-type-specific analysis (for Maintenance: current state and compatibility/rollback notes)

> **REQUIRED: Review the codebase analysis before presenting.** Verify every item is grounded in actual evidence. Label speculative entries as `[INFERRED]`. Do not present an unreviewed analysis.

> **APPROVAL GATE — FULL STOP.** Present the codebase analysis. Use `AskUserQuestion` (Header: `R2 Approval`, Question: `Are the scope areas correct and complete? Does the codebase analysis look accurate?`, Options: `Approve and proceed (Recommended)` — scope areas are correct and complete, `Request changes` — something needs revision). Do not proceed to R3 until the user approves.

> **COMPACTION GATE — R2:** Once R2 approval is confirmed, follow the Phase Compaction Handoff Contract above. Entity name: `phase-handoff-<work-item-key>-R2`; `next_phase: R3`; decisions: confirmed scope areas and work type; mode. REFERENCES: exploration entities and affected_area nodes from R2. Emit the Phase Summary block and instruct the user to run `/compact` before proceeding to R3.

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
    
    **Feature and Maintenance:**
    
    - **Data & Interface** `[NICE TO HAVE]` — Does this add or change any data models, schemas/migrations, APIs, endpoints, events, or config contracts? Capture the concrete request/response shapes, field names, or migration steps where known.
    - **Observability** `[NICE TO HAVE]` — What should be logged, measured, traced, or alerted on, and what signal will confirm the change is working in production?
    
    **Feature only:**
    
    - **Functional** — What exactly should the feature do?
    - **Edge Cases** — What happens when X, Y, Z?
    - **User Impact** — Who uses this and how does it change their experience?
    
    **Maintenance only:**
    
    - **Remediation Approach** — Is there a preferred approach or known constraints on how this should be fixed or updated?
    - **Regression Risk** — What existing behavior must be preserved?
    - **Risk & Rollback** — What is the rollback plan? What is the blast radius?
    - **Testing** — How will the change be verified as safe?
    - **Rollout & Scheduling** — Does this need to be done incrementally, and is there a required maintenance window or deadline?
4. Mark each question as `[BLOCKING]` or `[NICE TO HAVE]`.
    
5. Ask each question using a separate `AskUserQuestion` call in sequence — one question per call. Include the `[BLOCKING]` or `[NICE TO HAVE]` tag in the question text. For open-ended questions, use two options: `Provide answer` (description: "Type your response using the Other input field") and, for non-blocking questions only, `Skip` (description: "Skip this non-blocking question"). For closed-enum questions, use specific options.
    
6. Record all answers verbatim. Do not infer or invent answers.
    

> **USE KNOWLEDGE GRAPH:** After answers are confirmed, write each Q&A pair to the graph. Create a `qa_item` node with properties: `question`, `answer`, `priority` (blocking / nice_to_have), `category` (scope_boundary / dependencies / non_functional / data_interface / observability / functional / edge_cases / etc.). Link each node to the `work_item` node. R4A reads these nodes to derive traceable acceptance criteria; R5 reads the `non_functional`, `data_interface`, and `observability` nodes to populate their dedicated description sections.

> **REQUIRED:** Present all BLOCKING questions answered and answers recorded, and remaining unanswered questions listed as open items with owner and target resolution date.

> **APPROVAL GATE — FULL STOP.** Present all questions and recorded answers. Use `AskUserQuestion` (Header: `R3 Approval`, Question: `Are all blocking answers accurate and open items correctly captured?`, Options: `Approve and proceed (Recommended)` — all blocking answers are correct, `Request changes` — some answers need revision). Do not proceed to R4 until the user approves.

---

### R4 — Requirements Synthesis

**Objective:** Translate all gathered context into acceptance criteria, a risk register, and a scoping recommendation.

---

#### R4A — Acceptance Criteria

> **USE SEQUENTIAL THINKING:** Before writing acceptance criteria, invoke the `sequentialthinking` tool. For each candidate criterion, verify it is: (1) **unambiguous** — only one possible interpretation, (2) **testable** — can be verified without further clarification, and (3) **traceable** — directly derived from an R3 answer or R2 finding. Work through each criterion in sequence and revise any that fail before presenting.

> **THINK HARD:** Before finalizing the criteria, think hard about traceability and testability specifically — criteria that sound reasonable but cannot be independently verified without additional clarification are design defects, not just gaps. Poor criteria quality is the single most consistent source of scope creep and rework in downstream execution.

> **USE KNOWLEDGE GRAPH:** After criteria are finalized, write each one to the graph. Create a `criterion` node with properties: `text`, `format` (gherkin / outcome_based), and `traceable_to` (the `qa_item` or `affected_area` node key it was derived from). Link each node to the `work_item` node. R5 reads these nodes to populate the Acceptance Criteria section verbatim.

Write acceptance criteria appropriate to the work type:

- **Feature:** Use **Gherkin format**. This is a hard requirement, not a preference. Render the **entire** acceptance-criteria set as a single fenced ` ```gherkin ` code block headed by one `Feature:` line, with one `Scenario:` per discrete behavior and `Given` / `When` / `Then` (plus `And` where needed) steps under each. **Every** Feature criterion must be a `Scenario` — do **not** mix plain outcome bullets (e.g. "X is a valid enum value", "all six fields are mapped") into a Feature card's acceptance criteria; fold such facts into a `Then`/`And` step of the relevant Scenario, or move them to another section (Scope, Data & Interface Changes). Set `criterion.format = gherkin` for every Feature criterion. Canonical shape:

  ```gherkin
  Feature: <capability name>

    Scenario: <discrete behavior>
      Given <precondition>
      When <action>
      Then <expected outcome>
      And <additional expectation>

    Scenario: <next behavior>
      Given <precondition>
      When <action>
      Then <expected outcome>
  ```

- **Maintenance:** Use **outcome-based criteria** — describe the measurable, verifiable end state that must be true after the work is complete.

> **REQUIRED output:**
> 
> - Minimum 3 criteria covering the primary success state
> - At least 1 criterion per identified edge case, constraint, or regression risk from R3
> - Non-functional criteria included where applicable

> **GHERKIN FORMAT CHECK (Feature only) — FULL STOP before persisting criteria.** Re-read every Feature acceptance criterion. Each must be a `Given / When / Then` `Scenario` inside the single fenced ` ```gherkin ` block under one `Feature:` line. If any criterion is a plain outcome statement, rewrite it as a Scenario (or relocate it out of Acceptance Criteria). Do not mix formats within a Feature card's AC. Only after this check passes may you write the `criterion` nodes and proceed.

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
> - **Maintenance** defaults to Task unless the work spans multiple services or requires a phased or coordinated rollout.
> - **Feature** should be evaluated neutrally against the criteria above.

> **REQUIRED output:**
> 
> - Recommendation: **Epic** or **Task**, stated explicitly
> - Rationale: 2–4 sentences referencing the criteria above
> - If Epic: proposed child story breakdown (titles only, 3–6 stories)
> - If Task: confirmation that a single card is sufficient to contain all scope

> **Fill-out mode note:** In fill-out mode the issue type is already fixed by the existing Jira card. Do not recommend switching types — that is a Jira admin action outside the scope of this workflow. If the synthesized requirements suggest the existing type is wrong, surface it as an open item with a note, but proceed with the existing type. Record the confirmed type on the `work_item` node as `confirmed_issue_type`.

---

#### R4D — Behavior Flowgraph (best-effort)

> **REUSE EXISTING DIAGRAM:** Before generating a flowgraph, call `open_nodes` on the `discovery_summary` entity for this work item (if one exists) and check for a `diagram` observation written by `/implementation-discovery`. If one exists, use it as the starting point and refine it to reflect the requirements-level behavior — do not start from scratch.

> **GENERATE A FLOWGRAPH (best-effort):** Produce a Mermaid `flowchart` that visualizes the intended feature behavior — map the user-facing flow or system behavior through the acceptance criteria. Nodes should represent meaningful states, actions, or decision points (e.g. form submitted → validation → success/error), not abstract phases.
>
> - **Skip it** for single-criterion or trivially linear changes where a diagram adds no clarity. If skipped, state in one line why.
> - **Render it in the chat** as part of the R4 synthesis presentation at the approval gate.
> - **The diagram will be embedded in the Jira description under `## Architecture`** by R5 when it assembles the description from the templates below. No additional action needed here beyond persistence.
> - **Persist it to the knowledge graph:** add a `diagram` observation (the raw Mermaid source) to the `work_item` entity so R5 and downstream execution skills can read it.

---

#### R4E — Patterns & Code References

> **USE KNOWLEDGE GRAPH:** Traverse the exploration subgraph for this work item — from `work_item` follow the incoming `for` relations to each `exploration` node, then its `contains` findings — and collect the `pattern` (name, description, evidence_files), `evidence` (claim, file, line_range, confidence), and `integration_point` (with_area, interface, description, direction) entities. Skip any entity marked `superseded: true`. When discovery was reused (R2 discovery pre-check), also include the re-linked discovery exploration subgraph and the patterns embedded in `synthesis_chosen`.

1. Select the established patterns and conventions this work must follow, plus the concrete code anchors that demonstrate them. Prefer high-`confidence`, code-grounded `evidence`; drop `inferred: true` items unless clearly labelled `[INFERRED]`.
2. For the **1–3 most important** patterns, use `Read` to open the referenced `file` at its `line_range` and extract a short (≤ ~15-line) illustrative snippet. Prefix each snippet with a `// <path>:<line_range>` comment. Keep snippets minimal — the file is the source of truth; do not paste whole functions.
3. List the integration points the work must respect.
4. If no established pattern applies (greenfield area), record "None — no established pattern to follow." Do not fabricate a pattern.

> **USE KNOWLEDGE GRAPH:** Persist a `pattern_ref` rollup node linked to the `work_item` (mirrors the R2 `affected_area` rollup) with observations: `patterns` (name + description + canonical `path:line` each), `code_references` (`path:line_range` + what to mirror), `snippets` (extracted snippet text with its `path:line_range` header), and `integration_points`. R5 reads this node to populate the `## Patterns & Code References` section.

> **REQUIRED:** Present the Patterns & Code References list (patterns, code references, the 1–3 snippets, integration points) as part of the R4 synthesis at the approval gate below.

---

> **REQUIRED: Review the full R4 synthesis before presenting.** Verify every acceptance criterion is unambiguous, testable, and traceable. Remove or revise any that fail this check. Do not present an unreviewed synthesis.

> **APPROVAL GATE — FULL STOP.** Present the full R4 synthesis (acceptance criteria, risk register, Epic vs. Task recommendation, and Patterns & Code References). Use `AskUserQuestion` (Header: `R4 Approval`, Question: `Is the full R4 synthesis correct — acceptance criteria, risk register, Epic vs. Task recommendation, and Patterns & Code References?`, Options: `Approve and proceed (Recommended)` — the synthesis is correct, `Request changes` — something needs revision). Do not create a Jira issue of the wrong type. Do not proceed until the user approves.

> **COMPACTION GATE — R4:** Once R4 approval is confirmed, follow the Phase Compaction Handoff Contract above. Entity name: `phase-handoff-<work-item-key>-R4`; `next_phase: R5`; decisions: issue type recommendation (Epic or Task), criterion count, key risks; approval_condition: verbatim user phrasing if any conditional approval was given. REFERENCES: criterion nodes, qa_item nodes, affected_area nodes, pattern_ref node. Emit the Phase Summary block and instruct the user to run `/compact` before proceeding to R5.

---

### R5 — Jira Issue Creation or Update

**Objective:** Create or update the Jira issue with all requirements and a pointer to the appropriate execution skill.

**Agent Actions:**

1. > **USE KNOWLEDGE GRAPH:** Read the full graph — `work_item`, `affected_area`, `qa_item`, `criterion`, `pattern_ref`, `related_issue`, and `epic` nodes — to assemble the Jira issue description. Each section of the description maps directly to a node type: the `## Patterns & Code References` section comes from the `pattern_ref` rollup (R4E); the `## Non-Functional Requirements`, `## Data & Interface Changes`, and `## Observability & Telemetry` sections come from the `qa_item` nodes whose `category` is `non_functional`, `data_interface`, and `observability` respectively. This ensures nothing is missed or invented and the description is fully grounded in the structured context built across R0–R4.
    
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

    **Priority recommendation:** Before creating the issue, recommend a priority based on the risk register from R4B and the overall impact of the work item. Consider: user-facing impact, number of affected areas, dependency urgency, and whether this unblocks other work. Use `AskUserQuestion` to confirm the priority (Header: `Priority`, Question: `What priority should this issue be set to?`, Options: one of `Critical`, `High`, `Medium`, `Low` — put the recommended one first with `(Recommended)` based on the risk and impact assessment).

    **Epic recommendation (Task issue type only — skip for Epics):** If an epic was already confirmed in R1, present it as the recommendation. If no epic was confirmed, search Jira for open epics in the same project that relate to the affected areas, work type, or goals identified in R0-R4. Use `AskUserQuestion` to confirm the epic (Header: `Epic Link`, Question: `Which epic should this task be linked to?`, Options: `Use suggested epic: <KEY> (Recommended)` — link to the suggested epic, `Provide a different epic key` — type your preferred key using the Other input, `No epic` — leave this task unlinked to an epic). Only set the Epic Link if the user selects the suggested epic or provides a different key via Other.

    **API notes for non-standard fields:**
    - **Priority:** Set via `additional_fields`: `{"priority": {"name": "Medium"}}` (substituting the confirmed priority name: Critical, High, Medium, or Low).
    - **Labels:** Set via `additional_fields`: `{"labels": ["label1", "label2"]}` on `jira_create_issue`.
    - **Epic Link:** Set via `additional_fields`: `{"epicKey": "EPIC-KEY"}` on `jira_create_issue`. Do not use `jira_create_issue_link` for epic links — that creates a lateral link, not an epic association. Only include this field if the user confirmed an epic.

4. **Create or update decision — three-way branch:**

    - **Define mode (no existing card):** Create a new Jira issue using `jira_create_issue` with the approved description. Do not perform a follow-up description update solely to add execution instructions. This is today's default path.

    - **Fill-out mode — existing card is a Task:** Update the card's description using `jira_update_issue` with the freshly assembled description (full overwrite — existing content from R1 informed the synthesis but does not constrain the R5 output). Present the assembled description in the chat before calling the tool. The approval gate at the end of this phase is scoped to: "This description will overwrite the existing description on `<JIRA-KEY>`."

    - **Fill-out mode — existing card is an Epic:** Update the parent Epic's description using `jira_update_issue` with the freshly assembled description (same overwrite rule as above). After the parent is updated and the approval gate below is passed, proceed to **R5B — Per-Child Iteration** defined below.

5. **Post-creation/update linking:** After the issue is created or updated, link hard dependencies from R4B by calling `jira_create_issue_link` for each one. Use `link_type: "Blocks"` for hard dependencies. Do not attempt to set linked issues during `jira_create_issue` — that tool does not support it.

---

#### R5B — Per-Child Iteration (fill-out mode + Epic only)

Execute this sub-phase only when the existing card is an Epic and child tasks were enumerated in R1. Skip entirely for define mode and for fill-out mode on a Task.

For each `child_work_item-<KEY>` node in the graph, in stable order (by Jira key):

1. **R5B.1 — Per-child Q&A.** Use `AskUserQuestion` to confirm: the child's work type (Feature / Maintenance — inferred from its description shape and pre-filled for confirmation), and any blocking gap flagged by `existing_sections_missing` from R1. Keep it to at most 3 questions per child; defer anything `[NICE TO HAVE]`. Allow the user to skip any question by selecting `Skip — non-blocking`.

2. **R5B.2 — Per-child synthesis.** Use `sequentialthinking` to draft a description for this child using the appropriate work-type template (from the Description Structure section above). Inputs: the parent epic's freshly written AC (from R5A), this child's existing description, R2 codebase findings relevant to this child's scope, and the per-child Q&A answers from R5B.1. The synthesized description must:
   - Be fully populated with no placeholder text.
   - Include a Context section that references the parent epic key and summary.
   - Use the correct AC format for the work type. For **Feature** children, AC MUST be Gherkin: a single fenced ` ```gherkin ` block headed by `Feature:` with one `Scenario:` per behavior (Given/When/Then/And) and no plain outcome bullets mixed in (see the R4A canonical shape). **Maintenance** children use outcome-based criteria.
   - Not perform a coverage check across siblings — that is `epic-card`'s job.

3. **R5B.3 — Per-child approval.** Present the synthesized description in the chat. Use `AskUserQuestion` with header `R5B: <KEY>`, question `Review the synthesized description for <KEY> — [child summary]. How do you want to proceed?`, options: `Approve and update Jira` (description: "Overwrite this child's Jira description with the synthesized version") / `Skip this child` (description: "Leave this child's description unchanged and move to the next") / `Request changes` (description: "Revise the description before updating"). On `Request changes`, revise and re-present. On `Skip this child`, add `skipped: true` to the child node and continue to the next child.

4. **R5B.4 — Update child.** On approval, call `jira_update_issue` with the approved description for this child. Add `updated_at: <timestamp>` to the child node.

5. **R5B.5 — Compaction gate (between children).** After updating this child in Jira, follow the Phase Compaction Handoff Contract above before starting the next child. Entity name: `phase-handoff-<work-item-key>-R5B-<child-JIRA-KEY>`; `next_phase: R5B-<next-child-JIRA-KEY>` (or `R6` if this was the last child); decisions: this child updated (or skipped); include `child_completed: <JIRA-KEY>` and `next_child: <next-JIRA-KEY or "none">` observations. REFERENCES: the `child_work_item-<KEY>` node for this child. Emit the Phase Summary block and instruct the user to run `/compact` before continuing to the next child.

After the loop completes, present a summary in the chat: "Updated parent epic `<KEY>` and `N` of `M` child tasks." (where M is total children enumerated and N is how many were updated, not skipped).

> **USE KNOWLEDGE GRAPH:** After each child update, mark the `child_work_item-<KEY>` node with `updated_at` or `skipped: true`. If context is lost mid-loop (session ends), read the graph on resume to identify the next un-actioned child and continue from there. Do not re-present children already marked `updated_at` or `skipped: true`.

---

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

## Architecture
[Behavior flowchart from R4D — paste the Mermaid source here as a ```mermaid block.
If the flowgraph was skipped in R4D, write: "None — no diagram for this change."]

## Patterns & Code References
[From the R4E pattern_ref rollup. References are durable; snippets are illustrative and
may drift — the referenced file is the source of truth. "None — no established pattern to
follow." if greenfield.]
**Patterns to follow:**
- **[name]** — [description]. Canonical example: `[path:line]`.
**Code references:**
- `[path:line_range]` — [what to mirror]
**Illustrative snippets (1–3 most important only):** each in a fenced code block, prefixed
with a `// [path:line_range]` comment, ≤ ~15 lines, read from the referenced range.
**Integration points:**
- [with_area] via [interface] — [description] ([direction]), or "None identified."

## Non-Functional Requirements
[From R3 qa_item nodes with category non_functional. Verifiable target where possible;
"None specified" per line if N/A.]
- **Performance:** [...]
- **Security / Privacy:** [...]
- **Accessibility:** [...]
- **Compliance:** [...]

## Data & Interface Changes
[From R3 qa_item nodes with category data_interface. "None — no data or interface changes." if N/A.]
- **Data model / migrations:** [...]
- **APIs / endpoints:** [method, path, request shape, response shape]
- **Events / messages / config:** [...]

## Observability & Telemetry
[From R3 qa_item nodes with category observability. "None — no new instrumentation." if N/A.]
- **Logs / metrics / traces:** [...]
- **Alerts / dashboards:** [...]
- **Success signal (prod):** [...]

## Scope
**In Scope:**
- [...]
**Out of Scope:**
- [...]

## Acceptance Criteria
[Gherkin from R4A — copy verbatim. Render as a single fenced gherkin code block headed by
`Feature:`, with one `Scenario:` per behavior (Given/When/Then/And). Every criterion is a
Scenario — no plain outcome bullets. Example shape:
  Feature: <capability>
    Scenario: <behavior>
      Given <precondition>
      When <action>
      Then <expected outcome>
      And <additional expectation>]

## Dependencies
**Hard:** - [PROJ-XXX] -- [description]
**Soft:** - [description]

## Risks
[Risk register table from R4B -- copy verbatim]

## Open Items
[Unresolved questions from R3 with owner and target resolution date, or
"None -- all blocking questions resolved."]
```

**Maintenance:**

```
## Task Details

**Summary:** [Title from R0]

## Overview
[2-3 sentences: what needs to change and why]

## Driver
[What is triggering this work — tech-debt cleanup, refactor, scheduled maintenance,
dependency constraint, compliance requirement, or alert.]

## Current State
[Description of what exists today -- specific files, modules, patterns, behaviors,
versions, or dependencies that need to change.]

## Impact of Not Addressing
[Consequences of leaving this unresolved]

## Additional Context
[Links, notes, prior remediation attempts, version constraints, deadlines, or "None provided."]

## Remediation Approach
[High-level description of how this will be done]

## Affected Areas
[Structured list from R2 codebase analysis affected_area nodes. For each area:
file/module/service path, brief description of relevance, and risk level.]
- `[path]` -- [description] ([high/medium/low] risk)

## Architecture
[Behavior flowchart from R4D — paste the Mermaid source here as a ```mermaid block.
If the flowgraph was skipped in R4D, write: "None — no diagram for this change."]

## Patterns & Code References
[From the R4E pattern_ref rollup. References are durable; snippets are illustrative and
may drift — the referenced file is the source of truth. "None — no established pattern to
follow." if greenfield.]
**Patterns to follow:**
- **[name]** — [description]. Canonical example: `[path:line]`.
**Code references:**
- `[path:line_range]` — [what to mirror]
**Illustrative snippets (1–3 most important only):** each in a fenced code block, prefixed
with a `// [path:line_range]` comment, ≤ ~15 lines, read from the referenced range.
**Integration points:**
- [with_area] via [interface] — [description] ([direction]), or "None identified."

## Non-Functional Requirements
[From R3 qa_item nodes with category non_functional. Verifiable target where possible;
"None specified" per line if N/A.]
- **Performance:** [...]
- **Security / Privacy:** [...]
- **Accessibility:** [...]
- **Compliance:** [...]

## Data & Interface Changes
[From R3 qa_item nodes with category data_interface. "None — no data or interface changes." if N/A.]
- **Data model / migrations:** [...]
- **APIs / endpoints:** [method, path, request shape, response shape]
- **Events / messages / config:** [...]

## Observability & Telemetry
[From R3 qa_item nodes with category observability. "None — no new instrumentation." if N/A.]
- **Logs / metrics / traces:** [...]
- **Alerts / dashboards:** [...]
- **Success signal (prod):** [...]

## Compatibility & Rollback
[Known breaking changes, compatibility constraints, and rollback plan, or "None — no compatibility impact."]

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

> **REQUIRED: Review the full issue description before presenting.** Verify the correct description template was used, all fields are populated with no placeholder text, acceptance criteria match R4A output verbatim, the Affected Areas field is populated from R2 codebase analysis, no workflow instructions or skill-invocation text were embedded, and the issue type matches the R4C recommendation. Additionally verify:
> - **Patterns & Code References** is populated from the R4E `pattern_ref` rollup (or the explicit "None — no established pattern to follow."); any snippet carries its `// path:line_range` header.
> - **Non-Functional Requirements**, **Data & Interface Changes**, and **Observability & Telemetry** are populated from their `qa_item` categories, or each carries its explicit "None …" line — no placeholder text.
> - **For a Feature card:** the Acceptance Criteria is a single fenced ` ```gherkin ` block headed by `Feature:`, every criterion is a `Scenario` (Given/When/Then), and no plain outcome bullets are mixed in. If any are, rewrite before presenting.

> **APPROVAL GATE — FULL STOP.** Present the fully assembled issue description for final review. Use `AskUserQuestion` (Header: `R5 Approval`, Question: `Is the issue description accurate and ready to be created or updated in Jira?`, Options: `Approve and create / update (Recommended)` — content is accurate and ready, `Request changes` — something needs revision). Do not create or update the Jira issue until the user approves.

---

### R6 — Cleanup

**Objective:** Clear the session-scoped knowledge graph before finishing the workflow, including any upstream implementation-discovery state, after explicit user confirmation.

**Agent Actions:**

1. **Enumerate.** Call `read_graph`. Identify every entity that should be deleted in this cleanup:
   - The intake `work_item` entity for this issue and every entity linked to it: `affected_area`, `pattern_ref`, `exploration`, `affected_file`, `evidence`, `pattern`, `integration_point`, `risk`, `open_question`, `phase_handoff` (all entities with prefix `phase-handoff-<work-item-key>-`).
   - Any `child_work_item-<KEY>` entities created during R1 (fill-out mode + Epic path) — including those marked `skipped: true` and those with `updated_at` recorded.
   - Any `classification_signal` / `code_evidence` carried over from issue-intake (Missing Requirement path).
   - Any upstream **implementation-discovery** state still in the graph, including any `phase_handoff` entities created by the discovery workflow (prefix `phase-handoff-discovery-<slug>-`): the `discovery_summary-<slug>` entity, the `work_item-discovery-<slug>` work item, the verification-round and first-round `exploration` subgraph linked to it (including any finding entities marked `superseded: true`, which must still be deleted — supersession marks them as non-canonical, not as already-removed), and any structured `open_question` entities reified at D5 (sources `d3_discussion` and `d4_verification`). These persist intentionally from a prior `/implementation-discovery` run and R6 owns reaping them. Note that they are reachable both through the `summarizes` relation from `discovery_summary-<slug>` and through the `for` re-link added at R2 step 2.
   - Any other intake-scoped entities created during R0–R5 that link back to the work item.

2. **Present the cleanup plan to the user.** Build a short, structured summary in the chat:

   ```
   ## R6 Cleanup Plan

   The following session-scoped knowledge-graph entities will be deleted now that the Jira issue is finalized:

   ### From this Requirements Intake
   - work_item: <name>
   - affected_area: <count>
   - exploration: <count>
   - affected_file / evidence / pattern / integration_point / risk / open_question: <total count>
   - <any other intake-scoped entities, listed by type and count>

   ### From fill-out mode child iteration (fill-out + Epic only)
   - child_work_item-<KEY>: <count, or "none — define mode or Task fill-out">

   ### From upstream Implementation Discovery (if present)
   - discovery_summary-<slug>: <name, or "none">
   - work_item-discovery-<slug>: <name, or "none">
   - verification-round explorations: <count, or "none">

   ### From upstream Issue Intake (Missing Requirement path only)
   - classification_signal / code_evidence: <total count, or "none">

   Total entities to delete: <N>
   ```

   If the upstream-discovery section reports "none" across the board, state explicitly that no implementation-discovery state was found in the graph for this run.

3. > **APPROVAL GATE — FULL STOP.** Use `AskUserQuestion` (Header: `R6 Cleanup`, Question: `Proceed with cleanup of these entities?`, Options: `Proceed with cleanup (Recommended)` — delete all listed knowledge-graph entities, `Skip cleanup` — leave the graph untouched; entities will remain until the Claude Code session ends). Do not run `delete_entities` until the user selects Proceed. On any other response, do NOT delete.

4. **Execute deletion.** On explicit confirmation, call `delete_entities` with the full list enumerated in step 1. After deletion, report a one-line confirmation in the chat: "Cleanup complete: <N> entities deleted."

5. Do not leave requirements state in the graph after it has been fully materialized into the Jira issue, except when the user explicitly declined cleanup at step 3.

---

## Completion Criteria

This workflow is complete when **all** of the following are true:

- All 7 phases executed in sequence (R0-R6)
- All 7 approval gates explicitly confirmed in the chat (R0–R6 inclusive; R6 is the cleanup confirmation)
- All self-review checks passed before presenting output
- Jira issue updated (existing card) or created (new card) with all requirements populated, no unresolved placeholder text, and no embedded workflow or skill-invocation instructions
- Task Details section includes a structured Affected Areas field populated from R2 codebase analysis
- **Fill-out mode + Epic:** Every `child_work_item-<KEY>` node is marked either `updated_at` (description written to Jira) or `skipped: true` (user elected to skip)
- R6 cleanup either cleared the session-scoped knowledge graph (including `child_work_item` entities, and any upstream implementation-discovery and issue-intake entities) after the Jira record is finalized, or the user explicitly declined cleanup at the R6 approval gate
