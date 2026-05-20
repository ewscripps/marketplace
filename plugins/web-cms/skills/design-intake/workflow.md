# DESIGN INTAKE WORKFLOW — EXECUTION CONTRACT

> **How this works:** The user invokes this workflow by asking the agent to begin defining a new design requirement. The agent drives the entire process interactively — starting by asking the user questions to gather context, then working through design and codebase research phases, and finally creating a fully populated Jira Epic or Task.

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute phases in strict sequential order (R0 through R6).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure in the chat. Do not continue.
5. Every required output must be presented in the chat before the phase is considered complete.
6. Do not create any Jira issue until R5 is reached and approved.

**Note:** Approval gates in this workflow are confirmed in the chat -- no Jira issue exists yet.

**APPROVAL GATE BEHAVIOR:** Approval gates are chat-scoped. If explicit approval is not captured before the session ends or context is lost, stop at the gate. On resume, re-present the latest plan, draft, or summary and ask for confirmation again. Never assume a pending approval was granted.

**CLARIFICATION RULE:** Do not assume anything. If required information is missing, ambiguous, conflicting, or underspecified, stop and use `AskUserQuestion` to ask the user for clarification before proceeding.

**KNOWLEDGE GRAPH SCOPE:** The knowledge graph in this workflow is session-scoped. It accumulates structured context across R0-R4 so that R5 can assemble a complete, grounded Jira issue description. All graph content must be fully materialized into the Jira card description before the session ends -- do not rely on the graph persisting to a future session.

**TOOL PREFERENCE:** Prefer native tools over Bash for filesystem work. All filesystem, search, and directory operations must stay within the current project directory.

- **File I/O (read, write, edit a known file):** Use native `Read`, `Write`, `Edit`.
- **File discovery (find files by name or pattern):** Use native `Glob`.
- **Content search (find text inside files):** Use native `Grep`. For symbolic code search (finding classes, methods, or callers), delegate to the `codebase-explorer` agent, which uses the Serena MCP server.
- **Directory operations (list, metadata, move, mkdir):** Use Bash (`ls`, `stat`, `mv`, `mkdir -p`).
- **Git:** Use Bash for all git operations (`git status`, `git diff`, `git log`, `git push`, `git pull`, `git merge`, `git worktree`, `git remote`, `git stash`, `git rebase`, etc.) and for running build, test, and lint commands.

**SERENA PROJECT ACTIVATION:** Before R0, call `check_onboarding_performed`. If it reports that onboarding has not been performed for this project, call `onboarding` to scope Serena's language server to the current project directory. Serena's symbol tools (`find_symbol`, `find_referencing_symbols`, `get_symbols_overview`, `search_for_pattern`) and any symbol-aware operations invoked by the `codebase-explorer` agent depend on this being done. Do this once at the start of the workflow; do not repeat it between phases.

**TASK TRACKING:** Always use task tracking (`TaskCreate`/`TaskUpdate`) so progress is visible throughout. Create one task per phase at the start of the workflow. Mark each task `in_progress` when starting the phase and `completed` when the phase is done:

- R0 — Intake
- R1 — Jira Context Review
- R2 — Codebase and Design Analysis
- R3 — Stakeholder Q&A
- R4 — Requirements Synthesis
- R5 — Jira Issue Creation or Update
- R6 — Cleanup

**PHASE COMPACTION HANDOFF CONTRACT:** At designated compaction gates in this workflow, the agent writes a durable `phase_handoff` entity to the knowledge graph and prompts the user to run `/compact`. This prevents auto-compaction from discarding phase position, particularly after the large codebase and design analysis at R2.

**Steps at each gate — execute before instructing `/compact`:**

1. Wait for any background `area-mapper` sub-agent to complete.
2. Create a `phase_handoff` entity in the knowledge graph:
   - **Name:** `phase-handoff-<work-item-key>-<phase-id>` (e.g. `phase-handoff-intake-new-hero-component-R2`); use the `work_item_id` recorded at R0.
   - **Observations:** `phase: <id>`, `skill: design-intake`, `jira_key: <key or slug>`, `mode: <new or update>`, one `decisions: <text>` observation per key decision made this phase, `approval_condition: <verbatim user phrasing or "none">`, `next_phase: <id>`, one `open_items: <text>` per open item.
   - **Relations:** `BELONGS_TO` → the `work_item` entity for this run; `SUPERSEDES` → prior `phase_handoff` for this work item (if any); `REFERENCES` → relevant `affected_area`, `design_spec`, `exploration`, `criterion`, and `qa_item` entity names.
3. Call `open_nodes` on the new entity and each `REFERENCES` target to confirm writes landed.
4. Emit the Phase Summary block in the chat. The block must contain: phase ID and skill name, work item key, mode, one-line decision summary, verbatim approval condition, next phase ID, handoff entity name, and resume contract ("open_nodes on handoff entity → traverse REFERENCES → continue at `<next-phase>`"). End your turn immediately after the Phase Summary block — do not add any further content. The block must end with this literal line: **"Run `/compact` now, then type `continue` to resume."** Do NOT call `AskUserQuestion` here; the user must be free to run `/compact` in the prompt input without any open question consuming their input. When the user next types `continue` (or any message clearly indicating compaction is done), call `open_nodes` on the `phase_handoff` entity, traverse its `REFERENCES`, and resume at `next_phase`. If the user types a different message instead, handle it normally.

**Cleanup:** Include all `phase_handoff` entities for this work item (prefix `phase-handoff-<work-item-key>-`) in the R6 cleanup enumeration alongside other session-scoped entities.

---

### R0 — Intake

**Objective:** Greet the user and gather all context needed to begin the requirements workflow through natural conversation.

**Agent Actions:**

1. Introduce yourself and briefly explain what this workflow will do and what to expect (phases, approvals, end result).
    
2. Ask the following questions one at a time using `AskUserQuestion`. Wait for each response before asking the next. For closed-enum questions provide the specific options listed below. For open-ended questions, offer `Provide answer` as the first option (with the typed response coming from the auto-injected Other field) and `Skip for now` as the second option if the question is non-blocking.

    - **Project name** (open-ended, blocking): `AskUserQuestion` header `Project Name`, options: `Provide the name` / `I don't have a name yet`.
    - **What kind of thing is it?** (closed-enum, blocking): `AskUserQuestion` header `Project Type`, options: `Module` / `Component` / `Page` / `Something else`.
    - **Description** (open-ended, blocking): `AskUserQuestion` header `Description`, options: `Provide a description` / `I'll describe it differently`.
    - **New or update?** (closed-enum, blocking): `AskUserQuestion` header `New or Update`, options: `New project` / `Update on existing project`.

    **If the user indicates this is a new project**, continue with:
    - **Design scope** (closed-enum, blocking): `AskUserQuestion` header `Design Scope`, options: `Design is fully defined` / `Design is within scope of this project`.
    - **Requested by** (open-ended, blocking): `AskUserQuestion` header `Requested By`, options: `Provide name or team` / `Unknown`.
    - **Existing Jira Epic or Ticket** (open-ended, non-blocking): `AskUserQuestion` header `Existing Jira`, options: `Yes — I'll provide the key` / `No existing card`.
    - **Codebase areas** (open-ended, non-blocking): `AskUserQuestion` header `Codebase Hints`, options: `Yes — I'll name the areas` / `No / Not sure`.
    - **Design assets** (open-ended, non-blocking): `AskUserQuestion` header `Design Assets`, options: `Yes — I'll share them` / `No design assets yet`. Add note: "An HTML export from Claude Design gives the most precise specs — exact colors, spacing, and typography from the CSS. Screenshots or mockups also work."
    - **Design system** (open-ended, non-blocking): `AskUserQuestion` header `Design System`, options: `Yes — I'll name it` / `None / Not applicable`.

    **If the user indicates this is an update on an existing project**, continue with:
    - **Design scope** (closed-enum, blocking): `AskUserQuestion` header `Design Scope`, options: `Design changes are fully defined` / `Design changes are within scope of this project`.
    - **Functional changes** (closed-enum, blocking): `AskUserQuestion` header `Functional Changes`, options: `Yes — functionality changes too` / `No — visual changes only` / `Partially`.
    - **Requested by** (open-ended, blocking): `AskUserQuestion` header `Requested By`, options: `Provide name or team` / `Unknown`.
    - **Existing Jira Epic or Ticket** (open-ended, non-blocking): `AskUserQuestion` header `Existing Jira`, options: `Yes — I'll provide the key` / `No existing card`.
    - **Codebase areas** (open-ended, non-blocking): `AskUserQuestion` header `Codebase Hints`, options: `Yes — I'll name the areas` / `No / Not sure`.
    - **Design assets** (open-ended, non-blocking): `AskUserQuestion` header `Design Assets`, options: `Yes — I'll share them` / `No design assets yet`. Add note: "An HTML export from Claude Design gives the most precise specs. Screenshots or mockups also work."
    - **Design system** (open-ended, non-blocking): `AskUserQuestion` header `Design System`, options: `Yes — I'll name it` / `None / Not applicable`.

3. After all questions are answered, summarize the gathered context back to the user in a clear, structured format.
    
> **USE KNOWLEDGE GRAPH:** After the R0 approval gate is confirmed, write the core work item to the knowledge graph. Create a `work_item` entity with name `work_item-<key>` where `<key>` is the existing Jira issue key (if provided) or a normalized slug of the title (lowercase, whitespace/punctuation → `-`, trimmed) prefixed with `intake-` (e.g. `work_item-intake-new-hero-component`). Observations: `work_type` (always `feature` for this workflow), `title`, `description`, `requested_by`, `design_system` (if provided), `design_assets` (links or file paths, if provided), `existing_jira_key` (if provided). This is the root node — all subsequent phases will add linked nodes to it. R5 reads the graph entities via `open_nodes` to assemble the Jira issue description. **Record the entity name** — it is the `work_item_id` passed to every `codebase-explorer` call in R2.

> **REQUIRED:** The following context must be confirmed before proceeding:
> 
> - Title or Name
> - Description or Problem Statement (2–4 sentences)
> - Requested By / Identified By (name / team)
> - Related Epic (Jira key, or explicitly "none")
> - Codebase Hints (specific areas, or explicitly "none provided")
> - Design System / Component Library (name and version, or explicitly "none / not applicable")
> - Design Assets (links to Figma, screenshots, or explicitly "none provided")
> - Additional Context (links, notes, constraints, or explicitly "none provided")
> - Existing Jira Card (issue key, or explicitly "none")

> **APPROVAL GATE — FULL STOP.** Present the gathered context as a structured summary in the chat. Then use `AskUserQuestion` with header `R0 Approval`, options: `Approve and proceed (Recommended)` (description: "All fields are accurate and nothing is missing") / `Request changes` (description: "Something needs correction before continuing"). Do not proceed to R1 until approved.

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

> **APPROVAL GATE — FULL STOP.** Present the Jira context summary. Then use `AskUserQuestion` with header `R1 Approval`, options: `Approve and proceed (Recommended)` (description: "Existing card and epic are correct, no duplicate exists") / `Request changes` (description: "Something needs correction before continuing"). Do not proceed to R2 until approved.

---

### R2 — Codebase and Design Analysis

**Objective:** Identify the code surfaces this work item will touch and extract visual specifications from any provided design artifacts.

**Agent Actions:**

1. Identify all distinct areas of the codebase to explore based on the Codebase Hints from R0, the Related Epic from R1, and the work item description. Limit the scope of this exploration to the current project directory.
2. Invoke a `codebase-explorer` sub-agent in **parallel** for each distinct area in this project, providing:
    - The target area to explore
    - A question: "What code, patterns, and conventions are relevant to implementing [product description] in this area?"
    - The `work_item_id` recorded at R0 (the entity name of the `work_item` node). All findings the explorer streams to the graph will be linked to this node.
    - The work item description for context
3. Wait for all explorers to return. Each non-failed return contains an `Entity:` line with the exploration entity name. Treat `INCOMPLETE` as partial: findings are present but the run did not finish; consider re-spawning for the same area if coverage matters. Treat `FAILED` as no findings written — re-spawn that explorer before proceeding.

> **POST-EXPLORATION ENRICHMENT:** Spawn the `area-mapper` sub-agent **in the background** (`run_in_background: true`) with the same `work_item_id`. The mapper crystallizes durable area knowledge from this run's graph into Serena project memory so future explorations of the same areas start with hot context. Do not wait for it — proceed immediately to step 4.
4. Call `open_nodes` on each `exploration` entity name from the returns. If any entity comes back empty, re-spawn that explorer rather than treating missing data as confirmed. Surface any `open_question` entities in the responses. If any identifies a connection to another area not already explored, dispatch a follow-up `codebase-explorer` for that area (passing the same `work_item_id`) before proceeding.
5. Synthesize the findings from the graph into a unified codebase analysis. Read across all `exploration` entities linked to this `work_item_id` and aggregate:
    - **Affected files** — from `affected_file` entities. Group by module / service.
    - **Patterns and conventions** — from `pattern` entities; including CSS variables, theme tokens, component patterns, and style conventions relevant to the design.
    - **Integration points** — from `integration_point` entities.
    - **Risks** — from `risk` entities, ordered by severity.
6. Label any items derived from observations marked `inferred: true` as `[INFERRED]` in the analysis.
7. **Design artifact analysis.** Analyze design artifacts provided in R0 using the approach appropriate to the artifact type:

    **If a Claude Design HTML export was provided:**
    Read the file directly using the `Read` tool. Parse the HTML and CSS to extract exact values — do not infer or estimate. Record:
    - Color palette (exact hex values and CSS variable names from stylesheets)
    - Typography (font-family, font-size, font-weight, line-height from CSS rules, by element role)
    - Spacing and sizing (padding, margin, gap, border-radius values from CSS)
    - Layout and composition (flexbox/grid structure, element hierarchy)
    - Component inventory (all distinct UI components present in the HTML)
    - Interaction states (from CSS pseudo-classes: `:hover`, `:focus`, `:disabled`, or JS-driven state classes)
    - Responsive breakpoints (from `@media` queries)

    **If mockup images or screenshots were provided:**
    Analyze each image visually. Extract and record best estimates for:
    - Color palette (hex values or CSS variable references — mark as `[ESTIMATED]` if uncertain)
    - Typography (font family, size, weight, line-height for each text role)
    - Spacing and sizing (padding, margin, gap, border-radius values)
    - Layout and composition (grid structure, alignment, element positioning)
    - Component inventory (list every distinct UI component visible)
    - Interaction states visible in the mockup (default, hover, active, disabled, loading, error, empty)
    - Responsive or breakpoint indicators (if multiple mockups provided)

    **If a Figma link or other external URL was provided:**
    Note `[EXTERNAL DESIGN TOOL — CANNOT FETCH]`. Use `AskUserQuestion` with header `Design Asset Fallback`, options: `Share a Claude Design HTML export` (description: "Provides the most precise specs — exact colors, spacing, and typography from the CSS") / `Share screenshots or mockup images` (description: "Upload images of each relevant screen and state") / `Provide a manual spec summary` (description: "Type key colors, typography, spacing, and component details in the Other field"). Do not proceed with an empty design analysis — flag this as a gap at the approval gate.

    **If no design artifacts were provided:**
    Note `[NO DESIGN ARTIFACTS PROVIDED]` and flag this in the approval gate summary as a gap.

> **USE KNOWLEDGE GRAPH:** After synthesizing, roll up the explorer-written `affected_file` entities into `affected_area` summary nodes that downstream phases (R4A) read. For each distinct file / module / service / schema / component, create an `affected_area` entity with observations: `name`, `type` (file / module / service / schema / component), `risk` (high / medium / low — taken from the highest-severity `risk` entity linked to any of its `affected_file`s, defaulting to `medium`), and any relevant notes. Mark entries derived only from `inferred: true` observations with `inferred: true`. Link each `affected_area` to the `work_item` node. Also create a `design_spec` node with properties: `colors`, `typography`, `spacing`, `components` (list), `states` (list), `responsive_notes`, and `source` (filename or URL of design artifact, or `[INFERRED]` if derived from codebase analysis). Link it to the `work_item` node. R4A reads these nodes to ensure acceptance criteria cover real visual and interactive surfaces.

> **REQUIRED:** Present all of the following in the chat before proceeding:
> 
> - List of likely affected files / modules / services with rationale
> - Relevant existing patterns or conventions to follow
> - High-risk areas flagged with reasoning
> - Design artifact analysis: extracted visual specs, or explicit note that no artifacts were provided

> **REQUIRED: Review the codebase analysis before presenting.** Verify every item is grounded in actual evidence. Label speculative entries as `[INFERRED]`. Do not present an unreviewed analysis.

> **APPROVAL GATE — FULL STOP.** Present the codebase and design analysis. Then use `AskUserQuestion` with header `R2 Approval`, options: `Approve and proceed (Recommended)` (description: "Scope areas and design analysis are correct and complete") / `Request changes` (description: "Something needs correction before continuing"). Do not proceed to R3 until approved.

> **COMPACTION GATE — R2:** Once R2 approval is confirmed and any background `area-mapper` has completed, follow the Phase Compaction Handoff Contract above. Entity name: `phase-handoff-<work-item-key>-R2`; `next_phase: R3`; decisions: codebase scope confirmed, design artifact analysis status (complete / gap noted). REFERENCES: all `exploration` entities from R2, the `design_spec` node, and all `affected_area` nodes written to the graph.

---

### R3 — Stakeholder Q&A

**Objective:** Resolve all ambiguities required to write precise, actionable requirements and design specifications.

**Agent Actions:**

1. Review all output from R0, R1, and R2.
    
2. > **USE SEQUENTIAL THINKING:** Before generating the question batch, invoke the `sequentialthinking` tool. Work through each question category below systematically, identify what has already been answered vs. what remains genuinely ambiguous, and ensure full coverage across all relevant categories before presenting the batch. Do not present questions until the reasoning is complete.
    
3. Generate clarifying questions across the following categories:

    **Scope & Functionality:**
    
    - **Scope Boundary** — What is explicitly out of scope for this design implementation?
    - **Functional Behavior** — What exactly should the component or feature do? What interactions are required?
    - **Edge Cases** — What should the UI show when data is loading, empty, errored, or invalid?
    - **User Impact** — Who uses this and how does it change their experience?
    
    **Visual Specifications:**
    
    - **Color** — What are the exact colors (hex, CSS variable, or design token name) for each element? Are there dark mode variants?
    - **Typography** — What font family, size, weight, and line-height apply to each text role?
    - **Spacing & Sizing** — What are the padding, margin, gap, min/max width/height, and border-radius values?
    - **Borders & Shadows** — What border widths, colors, styles, and box-shadow values are used?
    - **Iconography** — What icons are used, and from which icon library or asset set?
    
    **Component States & Interactions:**
    
    - **Interactive States** — What do hover, active/pressed, focus, and disabled states look like?
    - **Async States** — What do loading, empty, error, and success states look like?
    - **Animation & Transitions** — Are there any motion specs (duration, easing, enter/exit behavior)?
    
    **Responsive Behavior:**
    
    - **Breakpoints** — At what screen widths does the layout change, and how?
    - **Mobile Treatment** — Are there mobile-specific layouts, touch targets, or interactions?
    
    **Accessibility:**
    
    - **WCAG Target** — What conformance level is required? `AskUserQuestion` header `WCAG Level`, options: `AA (Recommended)` / `A` / `AAA`.
    - **Color Contrast** — Have contrast ratios been verified for all text and interactive elements?
    - **Keyboard & Screen Reader** — Are there specific focus order, ARIA role, or label requirements?
    
    **Design System Alignment:**
    
    - **Component Reuse** — Which existing components from the design system should be used as-is vs. extended vs. replaced?
    - **Token Overrides** — Does this design deviate from existing design tokens? If so, are new tokens required?
    - **Dependencies** — Does this work depend on or block other features, services, or teams?

4. Mark each question as `[BLOCKING]` or `[NICE TO HAVE]`.

5. Ask each question one at a time using `AskUserQuestion`. For the WCAG level question, use the closed-enum options noted above. For all other questions, offer `Provide answer` / `Skip — non-blocking` (non-blocking only) and rely on the auto-injected "Other" for the typed answer. Include the `[BLOCKING]` or `[NICE TO HAVE]` tag in the question text. Do not ask the next question until the current one is answered.

6. Record all answers verbatim. Do not infer or invent answers.

> **USE KNOWLEDGE GRAPH:** After answers are confirmed, write each Q&A pair to the graph. Create a `qa_item` node with properties: `question`, `answer`, `priority` (blocking / nice_to_have), `category` (scope_boundary / functional / visual_specs / component_states / responsive / accessibility / design_system / etc.). Link each node to the `work_item` node. R4A reads these nodes to derive traceable acceptance criteria.

> **REQUIRED:** Present all BLOCKING questions answered and answers recorded, and remaining unanswered questions listed as open items with owner and target resolution date.

> **APPROVAL GATE — FULL STOP.** Use `AskUserQuestion` with header `R3 Approval`, options: `Approve and proceed (Recommended)` (description: "All blocking answers are accurate and open items are correctly captured") / `Request changes` (description: "Something needs correction before continuing"). Do not proceed to R4 until approved.

---

### R4 — Requirements Synthesis

**Objective:** Translate all gathered context into acceptance criteria, a risk register, and a scoping recommendation.

---

#### R4A — Acceptance Criteria

> **USE SEQUENTIAL THINKING:** Before writing acceptance criteria, invoke the `sequentialthinking` tool. For each candidate criterion, verify it is: (1) **unambiguous** — only one possible interpretation, (2) **testable** — can be verified without further clarification, and (3) **traceable** — directly derived from an R3 answer or R2 finding. Work through each criterion in sequence and revise any that fail before presenting.

> **USE KNOWLEDGE GRAPH:** After criteria are finalized, write each one to the graph. Create a `criterion` node with properties: `text`, `format` (always `gherkin` for this workflow), and `traceable_to` (the `qa_item`, `affected_area`, or `design_spec` node key it was derived from). Link each node to the `work_item` node. R5 reads these nodes to populate the Acceptance Criteria section verbatim.

Write acceptance criteria in **Gherkin format** (`Given / When / Then`) — one criterion per discrete behavior. Apply the following coverage requirements:

- **Functional behavior:** At least one criterion per core user interaction or visible state.
- **Component states:** At least one criterion per interactive state (hover, focus, disabled) and async state (loading, error, empty) where specs were defined in R3.
- **Visual conformance:** At least one criterion per defined visual specification where objective verification is possible (e.g. contrast ratio, token usage, presence of specific element). Do not write criteria for purely subjective aesthetics.
- **Responsive behavior:** At least one criterion per breakpoint where a layout change was specified.
- **Accessibility:** At least one criterion per WCAG requirement identified in R3.
- **Edge cases and constraints:** At least one criterion per edge case or constraint identified in R3.

> **REQUIRED output:**
> 
> - Minimum 3 criteria covering the primary success state
> - At least 1 criterion per identified component state, edge case, and constraint from R3
> - Visual and accessibility criteria included where specs are defined

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

> **USE SEQUENTIAL THINKING:** Before producing the recommendation, invoke the `sequentialthinking` tool. Evaluate the work item against each criterion in the table below explicitly and in sequence. Note any conflicting signals and stress-test the conclusion before committing to a verdict.

Evaluate the work item against these criteria:

|Criterion|Points to Epic|Points to Task|
|---|---|---|
|Delivery scope|Multiple sprints or workstreams|Single sprint, single owner|
|Output|Multiple deliverable stories/subtasks|Single deliverable|
|Codebase surface|3+ distinct modules or services|1–2 focused areas|
|Stakeholder coordination|Cross-team or cross-functional|Single team|
|Ambiguity remaining|Significant open items|Well-defined, low uncertainty|

> **Note:** Design intake work items are always Features. Evaluate neutrally against the criteria above.

> **REQUIRED output:**
> 
> - Recommendation: **Epic** or **Task**, stated explicitly
> - Rationale: 2–4 sentences referencing the criteria above
> - If Epic: proposed child story breakdown (titles only, 3–6 stories)
> - If Task: confirmation that a single card is sufficient to contain all scope

---

> **REQUIRED: Review the full R4 synthesis before presenting.** Verify every acceptance criterion is unambiguous, testable, and traceable. Remove or revise any that fail this check. Do not present an unreviewed synthesis.

> **APPROVAL GATE — FULL STOP.** Present the full R4 synthesis (acceptance criteria, risk register, Epic vs. Task recommendation). Then use `AskUserQuestion` with header `R4 Approval`, options: `Approve and proceed (Recommended)` (description: "All three sections are accurate — ready to create the Jira issue") / `Request changes` (description: "Something needs correction before continuing"). Do not create a Jira issue of the wrong type.

> **COMPACTION GATE — R4:** Once R4 approval is confirmed, follow the Phase Compaction Handoff Contract above. Entity name: `phase-handoff-<work-item-key>-R4`; `next_phase: R5`; decisions: Epic vs Task recommendation (state which), acceptance criteria count, key risks. REFERENCES: all `criterion` nodes, all `qa_item` nodes, the `design_spec` node, and all `affected_area` nodes.

---

### R5 — Jira Issue Creation or Update

**Objective:** Create or update the Jira issue with all requirements and design specifications.

**Agent Actions:**

1. > **USE KNOWLEDGE GRAPH:** Retrieve the work-item subgraph using `open_nodes` on the `work_item` entity name and each entity name recorded in the R4 `phase_handoff` REFERENCES — `affected_area`, `design_spec`, `qa_item`, `criterion`, `related_issue`, and `epic` nodes — to assemble the Jira issue description. Each section of the description maps directly to a node type. This ensures nothing is missed or invented and the description is fully grounded in the structured context built across R0–R4.
    
2. Assemble the Jira issue description using the description structure below. The description must contain only the structured delivery context for the work item. Do not append workflow instructions, skill-invocation text, or placeholder tokens.
    
3. Populate the following fields:

|Field|Source|
|---|---|
|Issue Type|Epic or Task per R4C|
|Summary|Title + core behavior or problem (max 10 words)|
|Description|Assembled per Description Structure below|
|Priority|Recommended based on risk and impact (see below)|
|Labels|Work type in lowercase + codebase area|
|Epic Link|Recommended epic (Task only — see below)|

    **Priority recommendation:** Before creating the issue, determine the recommended priority based on the risk register from R4B and the overall impact of the work item. Consider: user-facing impact, number of affected areas, dependency urgency, and whether this unblocks other work. Use `AskUserQuestion` with header `Task Priority` to confirm. Put the recommended priority first with `(Recommended)` appended. Options: one of `Critical (Recommended)` / `High (Recommended)` / `Medium (Recommended)` / `Low (Recommended)` as the first option (only the recommended one gets the label), then the remaining three priorities as subsequent options.

    **Epic recommendation (Task issue type only — skip for Epics):** If an epic was already confirmed in R1, present it as the recommendation. If no epic was confirmed, search Jira for open epics in the same project that relate to the affected areas, work type, or goals identified in R0–R4. Use `AskUserQuestion` with header `Epic Link`, options: `Use suggested epic: <KEY> (Recommended)` (description: "Link to the identified epic") / `Provide a different epic key` (description: "Type a different epic key in the Other field") / `No epic` (description: "Create the issue without an epic link"). Only set the Epic Link if the user selects the suggested epic or provides a key via Other.

    **API notes for non-standard fields:**
    - **Priority:** Set via `additional_fields`: `{"priority": {"name": "Medium"}}` (substituting the confirmed priority name: Critical, High, Medium, or Low).
    - **Labels:** Set via `additional_fields`: `{"labels": ["label1", "label2"]}` on `createJiraIssue`.
    - **Epic Link:** Set via `additional_fields`: `{"epicKey": "EPIC-KEY"}` on `createJiraIssue`. Do not use `createIssueLink` for epic links — that creates a lateral link, not an epic association. Only include this field if the user confirmed an epic.

4. **Update-or-create decision:**
    - **If an existing Jira card was provided in R0:** Update that card's description using `editJiraIssue` with the approved description. Do not create a new issue.
    - **If no existing card was provided:** Create a new Jira issue using `createJiraIssue` with the approved description. Do not perform a follow-up description update solely to add execution instructions.

5. **Post-creation linking:** After the issue is created or updated, link hard dependencies from R4B by calling `createIssueLink` for each one. Use `link_type: "Blocks"` for hard dependencies. Do not attempt to set linked issues during `createJiraIssue` — that tool does not support it.

### Description Structure

```
## Task Details

**Summary:** [Title from R0]

## Overview
[2-3 sentences: what the feature does and why it exists]

## Context
[Relevant background from Jira review and codebase analysis. Include any context
already captured in the existing Jira card retrieved in R1, if applicable.]

## Design Assets
[Links to Figma files, screenshots, or design documents provided in R0, or "None provided."]

## Design System
[Name and version of the design system or component library this conforms to, or "None / not applicable."]

## Affected Areas
[Structured list from R2 codebase analysis affected_area nodes. For each area:
file/module/service path, brief description of relevance, and risk level.]
- `[path]` -- [description] ([high/medium/low] risk)

## Visual Specifications
[Extracted from R2 design artifact analysis and R3 Q&A. Cover each sub-section where defined:]

**Colors:**
- [Element name]: `[hex or token]`

**Typography:**
| Role | Font Family | Size | Weight | Line Height |
|------|-------------|------|--------|-------------|
| [role] | [family] | [size] | [weight] | [line-height] |

**Spacing & Sizing:**
- [Element name]: padding `[value]`, margin `[value]`, border-radius `[value]`

**Borders & Shadows:**
- [Element name]: `[spec]`

**Iconography:**
- [Icon name]: [library/asset source]

## Component States
[For each component, list all defined states and their visual treatment. Omit states not defined in R3:]
- **[Component name]:**
  - Default: [description]
  - Hover: [description]
  - Active/Pressed: [description]
  - Focus: [description]
  - Disabled: [description]
  - Loading: [description]
  - Error: [description]
  - Empty: [description]

## Responsive Behavior
[Breakpoint-by-breakpoint layout changes, or "No responsive breakpoints defined."]
| Breakpoint | Layout / Treatment |
|------------|--------------------|
| [breakpoint] | [description] |

## Animation & Transitions
[Motion specs for any defined transitions, or "No animation defined."]

## Accessibility Requirements
- **WCAG Level:** [A / AA / AAA, or "Not specified"]
- **Color Contrast:** [Requirements, or "Not specified"]
- **Keyboard Navigation:** [Focus order or key behavior requirements, or "Not specified"]
- **Screen Reader:** [ARIA roles, labels, or announcements required, or "Not specified"]

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

---

> **REQUIRED: Review the full issue description before presenting.** Verify: (1) all fields are populated with no placeholder text, (2) acceptance criteria match R4A output verbatim, (3) the Affected Areas field is populated from R2 codebase analysis, (4) all defined Visual Specifications are populated from the R2 `design_spec` node, (5) Component States covers all states defined in R3, (6) Accessibility Requirements reflect R3 answers, (7) no workflow instructions or skill-invocation text were embedded, and (8) the issue type matches the R4C recommendation. For any section where no specs were defined, write "Not defined." — do not leave placeholder text.

> **APPROVAL GATE — FULL STOP.** Present the fully assembled issue description in the chat. Then use `AskUserQuestion` with header `R5 Approval`, options: `Approve and proceed (Recommended)` (description: "Content is accurate — create or update the Jira issue") / `Request changes` (description: "Something needs correction before creating"). Do not create or update the Jira issue until approved.

---

### R6 — Cleanup

**Objective:** Clear the session-scoped knowledge graph before finishing the workflow, after explicit user confirmation.

**Agent Actions:**

1. **Enumerate.** Call `read_graph`. Identify every entity that should be deleted in this cleanup:
   - The intake `work_item` entity for this issue and every entity linked to it: `affected_area`, `design_spec`, `exploration`, `affected_file`, `evidence`, `pattern`, `integration_point`, `risk`, `open_question`, `qa_item`, `criterion`, `related_issue`, `epic`, `phase_handoff`.
   - Any other intake-scoped entities created during R0–R5 that link back to the work item.

2. **Present the cleanup plan to the user.** Build a short, structured summary in the chat:

   ```
   ## R6 Cleanup Plan

   The following session-scoped knowledge-graph entities will be deleted now that the Jira issue is finalized:

   - work_item: <name>
   - affected_area: <count>
   - design_spec: <count>
   - exploration: <count>
   - affected_file / evidence / pattern / integration_point / risk / open_question: <total count>
   - qa_item / criterion: <total count>
   - related_issue / epic: <total count>
   - phase_handoff: <count>
   - <any other intake-scoped entities, listed by type and count>

   Total entities to delete: <N>
   ```

3. > **APPROVAL GATE — FULL STOP.** Use `AskUserQuestion` with header `R6 Cleanup`, options: `Proceed with cleanup (Recommended)` (description: "Delete all session-scoped entities listed above") / `Skip cleanup` (description: "Leave the graph untouched — entities remain until the session ends"). Do not run `delete_entities` until the user selects "Proceed with cleanup". On "Skip cleanup", leave the graph untouched, note in the chat that cleanup was skipped at the user's request, and end the workflow.

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
- Visual Specifications, Component States, Responsive Behavior, and Accessibility Requirements sections are all populated (or explicitly state "Not defined." for unspecified areas)
- R6 cleanup either cleared the session-scoped knowledge graph after the Jira record was finalized, or the user explicitly declined cleanup at the R6 approval gate
