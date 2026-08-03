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

**FILE MEMORY SCOPE:** This workflow stores session state in a per-work-item file-memory directory. `$MEM/work-item.md` is the root (title, description, and the `## Affected Areas`, `## Design Spec`, `## Patterns & Code References`, `## Architecture` sections built across R2/R4); `$MEM/clarifications.md` holds R3 Q&A; `$MEM/criteria.md` holds R4A acceptance criteria; `$MEM/related-cards.md` holds relevant related Jira cards from R1; `$MEM/explorations/*.md` hold R2 codebase findings. Compute `MEM` once with the recipe in `file-memory-protocol.md` §1 (`<work-item-key>` = the Jira key, or `intake-<slug>`). All file content must be fully materialized into the Jira card description in R5 before the session ends. See `file-memory-protocol.md` for schemas, the checkpoint/compaction contract, and the full-context-load rule.

**SUB-AGENT NAME RESOLUTION:** This workflow refers to sub-agents by short name (`codebase-explorer`, `area-mapper`). The runtime registers them under different identifiers depending on how they are installed. Before the first sub-agent invocation, resolve each short name against the runtime's available-agents list and use the exact registered identifier:

- If the short name appears verbatim in the list (agents deployed into the project's `.claude/agents/`), use it as-is.
- If installed via the plugin, the registered identifier is `web-cms:<short-name>:<short-name>` — e.g. `codebase-explorer` → `web-cms:codebase-explorer:codebase-explorer`.
- Never invent a partial form such as `web-cms:codebase-explorer` — it will not resolve. If an invocation fails with an "agent type not found" error, read the available-agents list in the error message, select the entry whose **final segment** equals the short name, and retry with that exact identifier.
- Resolve the scheme once, then reuse it for every subsequent sub-agent invocation in the session.

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
- R2 — Codebase and Design Analysis
- R3 — Stakeholder Q&A
- R4 — Requirements Synthesis
- R5 — Jira Issue Creation or Update
- R6 — Cleanup

**CHECKPOINT & COMPACTION CONTRACT:** This workflow records position in a single `$MEM/checkpoint.md` file (full schema and contract in `file-memory-protocol.md` §4) — important after the large codebase and design analysis at R2.

**Per-phase checkpoint — after EVERY phase (R0–R5), automatically, with no chat output and no `/compact` prompt.** Atomically overwrite `$MEM/checkpoint.md` (`Write` to `checkpoint.md.tmp`, then `mv` over `checkpoint.md`) with `checkpoint_type: phase`, the just-completed `phase`, the upcoming `next_phase`, the `references` list, `mode`, `## Decisions`, and `## Open items`.

**Compaction gates (R2, R4) — additionally prompt the user to `/compact`.** Do the per-phase write but with `checkpoint_type: gate`, then: (1) wait for any background `area-mapper` to finish; (2) emit the Phase Summary block (§4(b)) — phase + skill, work item key, mode, one-line decisions, verbatim approval condition, `next_phase`, the checkpoint file path, and the resume contract; (3) end the turn with the literal line **"Run `/compact` now, then type `continue` to resume."** Do NOT call `AskUserQuestion` at a gate.

**Universal resume rule — on ANY resume, before doing anything else:** `Read $MEM/checkpoint.md` → `Read` every file in its `references` → **re-read the `next_phase` section of this `workflow.md`** (any phase asking clarifying/structured questions MUST use `AskUserQuestion`) → continue at `next_phase`. If `$MEM` is absent, restart the affected phase from the Jira card and prior chat. Approval gates stay chat-scoped — never assume a pending approval was granted.

---

### R0 — Intake

**DISCOVERY PRE-CHECK:** Before greeting the user, `Glob $MEMROOT/discovery-*/summary.md` (compute `$MEMROOT` via the recipe in `file-memory-protocol.md` §1) to find any prior `/implementation-discovery` summary (dirs are named `discovery-<topic-slug>` so multiple discoveries in one session do not collide). `Read` each `summary.md` frontmatter (`topic_slug`, `chosen_approach`, `verification_status`, `discovery_confirmed`).
1. **If exactly one is present:** acknowledge it immediately: "I found a prior implementation discovery session for: **[topic]** (chosen approach: **[chosen_approach]**, verification: **[verification_status]**). I'll use those findings as a head start — the codebase areas have already been explored and verified. If this isn't the right context, just say so and I'll start fresh."
2. **If multiple are present** (the user ran more than one discovery in this session): list them by `topic` and `chosen_approach`, then use `AskUserQuestion` (Header: `Discovery Pick`, Question: `Multiple discovery sessions were found. Which one is this design run for?`, Options: one option per discovery summary labeled `[topic] — [chosen_approach]`, plus `Start fresh — ignore all discoveries`). Treat the user's pick as the selected `discovery-<slug>/summary.md`; ignore the others for this run.
3. **If the user confirms a discovery summary:** set `discovery_confirmed: true` in that specific `discovery-<slug>/summary.md` frontmatter (`Edit`), not in any other. When asking intake questions below, skip the **Codebase areas** question — the discovery already covers it. Note that R2 will use the discovery findings and skip spawning new codebase-explorer agents (the design artifact analysis in R2 still runs — discovery does not cover visual specs).
4. **If the user rejects** (or no discovery summary exists): proceed with normal intake and do not reference the discovery summary again.

**Objective:** Greet the user and gather all context needed to begin the requirements workflow through natural conversation.

**Agent Actions:**

1. Introduce yourself and briefly explain what this workflow will do and what to expect (phases, approvals, end result).
    
2. Gather context in this order:

   **a. Name and type (via `AskUserQuestion`, one call each):**
    - **Project name** (open-ended, blocking): `AskUserQuestion` header `Project Name`, options: `Provide the name` / `I don't have a name yet`.
    - **What kind of thing is it?** (closed-enum, blocking): `AskUserQuestion` header `Project Type`, options: `Module` / `Component` / `Page` / `Something else`.

   **b. Description — ask conversationally, not via `AskUserQuestion`.**  
   The `AskUserQuestion` free-text field is cramped and discourages detail; a conversational prompt gives the user the full prompt input to write as much as they need. Send this message, then **end your turn and wait** for the user's reply:

   *"Now describe what you're designing. Include as much detail as you have — what it is, who uses it, what it needs to do (behavior and interactions), what it should look like (layout, visual style, states), any constraints or design system requirements, and the context it lives in. The more you share here, the more precisely the design can be defined."*

   **c. Sufficiency check.** Before continuing, assess whether the description is detailed enough to define a design. It should cover at minimum what the thing is and what it needs to do. If it's too thin — a single short phrase, no behavior described, no intended user or context — ask 1–3 targeted follow-up questions to fill the specific gaps. Do not invent design details yourself; draw them out of the user. If the description is already sufficient, proceed immediately.

   **d. Remaining structured questions (via `AskUserQuestion`, one call each):**
    - **New or update?** (closed-enum, blocking): `AskUserQuestion` header `New or Update`, options: `New project` / `Update on existing project`.

    **If the user indicates this is a new project**, continue with:
    - **Design scope** (closed-enum, blocking): `AskUserQuestion` header `Design Scope`, options: `Design is fully defined` / `Design is within scope of this project`.
    - **Existing Jira card** (open-ended, non-blocking): **Before asking**, run `git rev-parse --abbrev-ref HEAD` and apply a regex match for `[A-Z]+-[0-9]+` against the branch name. If a candidate key is found: `AskUserQuestion` (header `Existing Card`, options: `Yes, <extracted key>` (description: "Use <extracted key> as the existing Jira card") / `Use a different key` (description: "Type the correct key in the Other field") / `No existing card`). If no candidate is found: `AskUserQuestion` (header `Existing Card`, options: `Yes — I'll provide the key` / `No existing card`).
    - **Existing Jira Epic** (open-ended, non-blocking): Ask only if the existing card confirmed above is not itself an Epic. If an existing card was confirmed: `AskUserQuestion` (header `Related Epic`, options: `Already linked via the card` (description: "The card is already linked to its Epic — no separate input needed") / `Yes — I'll provide the key` (description: "Type the Epic key in the Other field") / `No`). If no existing card was provided: `AskUserQuestion` (header `Related Epic`, options: `Yes — I'll provide the key` (description: "Type the Epic key in the Other field") / `No`).
    - **Codebase areas** (open-ended, non-blocking): `AskUserQuestion` header `Codebase Hints`, options: `Yes — I'll name the areas` / `No / Not sure`.
    - **Design assets** (open-ended, non-blocking): `AskUserQuestion` header `Design Assets`, options: `Yes — I'll share them` / `No design assets yet`. Add note: "An HTML export from Claude Design gives the most precise specs — exact colors, spacing, and typography from the CSS. Screenshots or mockups also work."
    - **Design system** (open-ended, non-blocking): `AskUserQuestion` header `Design System`, options: `Yes — I'll name it` / `None / Not applicable`.

    **If the user indicates this is an update on an existing project**, continue with:
    - **Design scope** (closed-enum, blocking): `AskUserQuestion` header `Design Scope`, options: `Design changes are fully defined` / `Design changes are within scope of this project`.
    - **Functional changes** (closed-enum, blocking): `AskUserQuestion` header `Functional Changes`, options: `Yes — functionality changes too` / `No — visual changes only` / `Partially`.
    - **Existing Jira card** (open-ended, non-blocking): **Before asking**, run `git rev-parse --abbrev-ref HEAD` and apply a regex match for `[A-Z]+-[0-9]+` against the branch name. If a candidate key is found: `AskUserQuestion` (header `Existing Card`, options: `Yes, <extracted key>` (description: "Use <extracted key> as the existing Jira card") / `Use a different key` (description: "Type the correct key in the Other field") / `No existing card`). If no candidate is found: `AskUserQuestion` (header `Existing Card`, options: `Yes — I'll provide the key` / `No existing card`).
    - **Existing Jira Epic** (open-ended, non-blocking): Ask only if the existing card confirmed above is not itself an Epic. If an existing card was confirmed: `AskUserQuestion` (header `Related Epic`, options: `Already linked via the card` (description: "The card is already linked to its Epic — no separate input needed") / `Yes — I'll provide the key` (description: "Type the Epic key in the Other field") / `No`). If no existing card was provided: `AskUserQuestion` (header `Related Epic`, options: `Yes — I'll provide the key` (description: "Type the Epic key in the Other field") / `No`).
    - **Codebase areas** (open-ended, non-blocking): `AskUserQuestion` header `Codebase Hints`, options: `Yes — I'll name the areas` / `No / Not sure`.
    - **Design assets** (open-ended, non-blocking): `AskUserQuestion` header `Design Assets`, options: `Yes — I'll share them` / `No design assets yet`. Add note: "An HTML export from Claude Design gives the most precise specs. Screenshots or mockups also work."
    - **Design system** (open-ended, non-blocking): `AskUserQuestion` header `Design System`, options: `Yes — I'll name it` / `None / Not applicable`.

3. After all questions are answered, summarize the gathered context back to the user in a clear, structured format.
    
> **BOOTSTRAP FILE MEMORY:** After the R0 approval gate is confirmed, compute `MEM` (recipe §1) where `<work-item-key>` is the existing Jira issue key (if provided) or a normalized slug of the title prefixed with `intake-` (e.g. `intake-new-hero-component`). `mkdir -p "$MEM/explorations"` and `Write $MEM/work-item.md` (schema §3.1) with `work_type: feature`, `jira_key` (or null), `title`, `status: in_progress`, `phase: R0`, `skill: design-intake`, and the full description under `## Description` (verbatim — do not summarize). Note `design_system` and `design_assets` in `## Description` if provided. This is the root file; subsequent phases add `## Affected Areas`, `## Design Spec`, `## Patterns & Code References`, and `## Architecture` sections plus the sibling files, and R5 reads them all. The `MEM` path (as `memory_dir`) is passed to every `codebase-explorer` call in R2.

> **REQUIRED:** The following context must be confirmed before proceeding:
> 
> - Title or Name
> - Description or Problem Statement (capture in full — do not summarize or truncate the user's input)
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
3. Search Jira for existing issues that overlap with the work item using keyword and label search. **Related-card capture:** for each candidate that passes the relevance bar (materially informs scope, design, or implementation — not merely a duplicate to flag), call `jira_get_issue` to read its description and append it to `$MEM/related-cards.md` (schema §3.7) with `key`, `title`, `status`, `relationship` (overlaps | depends-on | prior-art | same-area | superseded-by), a one-line `why_relevant`, and a concise excerpt of the pertinent section (never the whole description). Log any candidate that fails the bar in the chat rather than storing it. R4 reads `related-cards.md` and distills material cards into the card; pure duplicates are still surfaced at the R1 gate.
4. Identify any sibling Epics or themes that appear contextually related.

> **RECORD JIRA CONTEXT:** If a related Epic exists, set `related_epic: <key>` in `$MEM/work-item.md` frontmatter. Overlapping/related issues are captured in `$MEM/related-cards.md` (step 3 above). If an existing card was provided, fold its captured context into `work-item.md`'s `## Description`.

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

**DISCOVERY PRE-CHECK:** Before spawning codebase-explorer agents, `Read` the `discovery-<slug>/summary.md` confirmed in R0 (the one with `discovery_confirmed: true`). If present, the codebase-exploration portion of this phase is already complete:
1. **Announce:** "Codebase analysis is already complete from the prior discovery session for `[chosen_approach]` (verification status: [verification_status]). Using [N] affected areas identified in discovery." If `verification_status` is `accepted_with_open_questions`, also surface a one-line note that open questions from verification are carried into this intake.
2. **Copy the discovery explorations into this work item.** Copy each `discovery-<slug>/explorations/*.md` into `$MEM/explorations/` (Bash `cp`) so R4A/R4E read them via the normal `$MEM/explorations/*.md` path. Skip any exploration file (or finding) marked superseded at D4 — the verification round wrote replacements.
3. **Record affected areas in `work-item.md`.** Write the discovery's affected areas (from `summary.md`'s `affected_areas`) into `$MEM/work-item.md`'s `## Affected Areas` section, with risk from `## Synthesis (chosen)` where given (else medium).
4. **Use `summary.md`'s `## Synthesis (chosen)` as the codebase analysis content.**
5. **Surface open questions as structured input to R3 / R4.** Read `summary.md`'s `## Open questions` and carry each into this intake as a candidate clarifying question (R3) and candidate risk (R4).
6. **Skip Agent Actions steps 1–6 (codebase exploration) entirely. Still perform step 7 (Design artifact analysis)** — discovery does not extract visual specs. Present the synthesis plus the design artifact analysis as the combined R2 analysis, then proceed to the approval gate.

**Agent Actions:**

1. Identify all distinct areas of the codebase to explore based on the Codebase Hints from R0, the Related Epic from R1, and the work item description. Limit the scope of this exploration to the current project directory.
2. Invoke a `codebase-explorer` sub-agent in **parallel** for each distinct area in this project, providing:
    - The target area to explore
    - A question: "What code, patterns, and conventions are relevant to implementing [product description] in this area?"
    - The `memory_dir` (`$MEM`) and a normalized `area_slug`. The explorer writes its findings to `$MEM/explorations/<area_slug>.md`.
    - The work item description for context
3. Wait for all explorers to return. Each non-failed return contains a `File:` line with the exploration file name. Treat `INCOMPLETE` as partial: findings are present but the run did not finish; consider re-spawning for the same area if coverage matters. Treat `FAILED` as no file written — re-spawn that explorer before proceeding.

> **POST-EXPLORATION ENRICHMENT:** Spawn the `area-mapper` sub-agent **in the background** (`run_in_background: true`) with the same `memory_dir` (`$MEM`). The mapper crystallizes durable area knowledge from this run's exploration files into Serena project memory so future explorations of the same areas start with hot context. Do not wait for it — proceed immediately to step 4.
4. `Read` each `$MEM/explorations/<area_slug>.md` from the returns. If any file is missing or empty, re-spawn that explorer rather than treating missing data as confirmed. Surface any `open_questions` entries. If any identifies a connection to another area not already explored, dispatch a follow-up `codebase-explorer` for that area (passing the same `memory_dir`) before proceeding.
5. Synthesize the findings from the exploration files into a unified codebase analysis. Read across all `$MEM/explorations/*.md` and aggregate:
    - **Affected files** — from each file's `affected_files` array. Group by module / service.
    - **Patterns and conventions** — from `patterns`; including CSS variables, theme tokens, component patterns, and style conventions relevant to the design.
    - **Integration points** — from `integration_points`.
    - **Risks** — from `risks`, ordered by severity.
6. Label any items derived from entries marked `inferred: true` as `[INFERRED]` in the analysis.
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

> **WRITE Affected Areas + Design Spec to work-item.md:** After synthesizing, roll up the explorations' `affected_files` into an `## Affected Areas` section in `$MEM/work-item.md` that downstream phases (R4A, R5) read. For each distinct file / module / service / schema / component, write: `name`, `type`, `risk` (high / medium / low — from the highest-severity `risk` linked to any of its files, defaulting to `medium`), and any notes. Mark inferred-only entries `[INFERRED]`. Also write a `## Design Spec` section capturing `colors`, `typography`, `spacing`, `components` (list), `states` (list), `responsive_notes`, and `source` (filename or URL of the design artifact, or `[INFERRED]` if derived from codebase analysis). R4A reads these to ensure acceptance criteria cover real visual and interactive surfaces; R5 reads them to populate the card's Affected Areas, Visual Specifications, and Component States sections.

> **REQUIRED:** Present all of the following in the chat before proceeding:
> 
> - List of likely affected files / modules / services with rationale
> - Relevant existing patterns or conventions to follow
> - High-risk areas flagged with reasoning
> - Design artifact analysis: extracted visual specs, or explicit note that no artifacts were provided

> **REQUIRED: Review the codebase analysis before presenting.** Verify every item is grounded in actual evidence. Label speculative entries as `[INFERRED]`. Do not present an unreviewed analysis.

> **APPROVAL GATE — FULL STOP.** Present the codebase and design analysis. Then use `AskUserQuestion` with header `R2 Approval`, options: `Approve and proceed (Recommended)` (description: "Scope areas and design analysis are correct and complete") / `Request changes` (description: "Something needs correction before continuing"). Do not proceed to R3 until approved.

> **COMPACTION GATE — R2:** Once R2 approval is confirmed and any background `area-mapper` has completed, follow the Checkpoint & Compaction Contract above (gate path). Write `checkpoint.md` with `phase: R2`, `next_phase: R3`, `checkpoint_type: gate`, `mode`, `references: [work-item.md, explorations/*.md, related-cards.md]`; `## Decisions`: codebase scope confirmed, design artifact analysis status (complete / gap noted).

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

> **WRITE clarifications.md:** After answers are confirmed, append each Q&A pair to `$MEM/clarifications.md` (schema §3.5) as an `items[]` entry with `question`, `answer`, `priority` (blocking / nice_to_have), and `category` (scope_boundary / functional / visual_specs / component_states / responsive / accessibility / design_system / etc.). R4A reads these to derive traceable acceptance criteria.

> **REQUIRED:** Present all BLOCKING questions answered and answers recorded, and remaining unanswered questions listed as open items with owner and target resolution date.

> **APPROVAL GATE — FULL STOP.** Use `AskUserQuestion` with header `R3 Approval`, options: `Approve and proceed (Recommended)` (description: "All blocking answers are accurate and open items are correctly captured") / `Request changes` (description: "Something needs correction before continuing"). Do not proceed to R4 until approved.

---

### R4 — Requirements Synthesis

**Objective:** Translate all gathered context into acceptance criteria, a risk register, and a scoping recommendation.

> **FULL CONTEXT LOAD:** Before synthesizing, `Glob $MEM` and `Read` every present input file — `work-item.md` (description + `## Affected Areas` + `## Design Spec`), every `explorations/*.md`, `clarifications.md`, and `related-cards.md` (per `file-memory-protocol.md` §5). Synthesize on the full context, never a partial read.

---

#### R4A — Acceptance Criteria

> **USE SEQUENTIAL THINKING:** Before writing acceptance criteria, invoke the `sequentialthinking` tool. For each candidate criterion, verify it is: (1) **unambiguous** — only one possible interpretation, (2) **testable** — can be verified without further clarification, and (3) **traceable** — directly derived from an R3 answer or R2 finding. Work through each criterion in sequence and revise any that fail before presenting.

> **WRITE criteria.md:** After criteria are finalized, `Write $MEM/criteria.md` (schema §3.6) with `format: gherkin` and a `criteria[]` array — each entry `text` + `traceable_to` (the `clarifications.md` item, affected-area, or design-spec element it was derived from) — plus the verbatim gherkin block in the body. R5 reads this to populate the Acceptance Criteria section verbatim.

Write acceptance criteria in **Gherkin format**. This is a hard requirement. Render the **entire** acceptance-criteria set as a single fenced ` ```gherkin ` code block headed by one `Feature:` line, with one `Scenario:` per discrete behavior and `Given`/`When`/`Then` (+ `And`) steps. **Every** criterion must be a `Scenario` — do not mix plain outcome bullets into the AC. Canonical shape:

```gherkin
Feature: <component or capability>

  Scenario: <behavior or state>
    Given <precondition>
    When <action>
    Then <expected outcome>
    And <additional expectation>
```

Apply the following coverage requirements:

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

#### R4D — UI Flow Flowgraph (best-effort)

> **GENERATE A FLOWGRAPH (best-effort):** Produce a Mermaid `flowchart` that visualizes the UI navigation and component-state flow — nodes are screens, components, or states; edges are user interactions or transitions (e.g. button click → modal open, form submit → loading → success/error). Ground nodes in the component names and states identified in R2 and R3.
>
> - **Skip it** for single-component, single-state changes where a diagram adds no clarity. If skipped, state in one line why.
> - **Render it in the chat** as part of the R4 synthesis presentation at the approval gate.
> - **The diagram will be embedded in the Jira description under `## Architecture`** by R5 when it assembles the description from the template below. No additional action needed here beyond persistence.
> - **Persist it** to `$MEM/work-item.md`'s `## Architecture` section (as a ```mermaid block) so R5 and downstream execution skills can read it.

---

#### R4E — Patterns & Code References

> **READ explorations:** Read all `$MEM/explorations/*.md` and collect `patterns` (name, description, evidence_files), `evidence` (claim, file, line_range, confidence), and `integration_points` entries, plus the `## Design Spec` conventions from `work-item.md`. Skip any marked `inferred: true` unless clearly labelled. When discovery was reused (R2 pre-check), the copied discovery explorations are already under `$MEM/explorations/`.

1. Select the established **component-reuse, design-token, and style conventions** this work must follow, and the concrete code anchors that demonstrate them (existing components to reuse vs. extend, token files, style modules). Prefer high-`confidence`, code-grounded evidence.
2. For the **1–3 most important** patterns, use `Read` to open the referenced `file` at its `line_range` and extract a short (≤ ~15-line) snippet, prefixed with a `// <path>:<line_range>` comment. Keep snippets minimal — the file is source of truth.
3. List integration points the work must respect. If no established pattern applies, record "None — no established pattern to follow."

> **WRITE Patterns & Code References to work-item.md:** Persist the selected patterns into `$MEM/work-item.md`'s `## Patterns & Code References` section: `patterns`, `code_references`, `snippets`, `integration_points`. R5 reads this section to populate the card's `## Patterns & Code References`.

> **REQUIRED:** Present the Patterns & Code References list as part of the R4 synthesis at the approval gate below.

---

> **REQUIRED: Review the full R4 synthesis before presenting.** Verify every acceptance criterion is unambiguous, testable, and traceable. Remove or revise any that fail this check. Do not present an unreviewed synthesis.

> **BLIND-SPOT CALLOUT (conditional):** After presenting the synthesis and before asking for approval, answer this question for the user: *"What is the biggest thing the user may be missing about this design work — what don't they realize?"* Render the answer as a short **What you might be missing** block containing at most two specific, evidence-backed items drawn from the R2 exploration findings (`risks`, `integration_points`, component-reuse conventions), related cards, or the R3 answers — cite the source for each. Typical candidates: an existing component that should be extended instead of built, a design-token or accessibility constraint that reshapes the visual spec, a state or breakpoint the mockups never showed. If nothing qualifies, write exactly one line — "Nothing notable — the synthesis surfaces the known risks." — and never invent a generic risk to fill the section.

> **APPROVAL GATE — FULL STOP.** Present the full R4 synthesis (acceptance criteria, risk register, Epic vs. Task recommendation, and Patterns & Code References). Then use `AskUserQuestion` with header `R4 Approval`, options: `Approve and proceed (Recommended)` (description: "The synthesis is accurate — ready to create the Jira issue") / `Request changes` (description: "Something needs correction before continuing"). Do not create a Jira issue of the wrong type.

> **REGENERATE DASHBOARD:** After approval, regenerate `$MEM/work-item.html` from the current memory files (per `file-memory-protocol.md` §8) so the user has an up-to-date rendered view.
>
> **COMPACTION GATE — R4:** Once R4 approval is confirmed, follow the Checkpoint & Compaction Contract above (gate path). Write `checkpoint.md` with `phase: R4`, `next_phase: R5`, `checkpoint_type: gate`, `mode`, `references: [work-item.md, criteria.md, clarifications.md, related-cards.md, explorations/*.md]`; `## Decisions`: Epic vs Task recommendation (state which), acceptance criteria count, key risks.

---

### R5 — Jira Issue Creation or Update

**Objective:** Create or update the Jira issue with all requirements and design specifications.

**Agent Actions:**

1. > **FULL CONTEXT LOAD:** `Glob $MEM` and `Read` the full set to assemble the Jira issue description — `work-item.md` (`## Description`, `## Affected Areas`, `## Design Spec`, `## Patterns & Code References`, `## Architecture`), `clarifications.md` (Visual Specs / Component States / NFR / Accessibility items by category — accessibility stays in its own dedicated section), `criteria.md` (Acceptance Criteria verbatim), and `related-cards.md` (distill material cards into `## Dependencies` / `## Patterns & Code References` / `## Context`). This ensures nothing is missed or invented and the description is fully grounded in the structured context built across R0–R4.
    
2. Assemble the Jira issue description using the description structure below. The description must contain only the structured delivery context for the work item. Do not append workflow instructions, skill-invocation text, or placeholder tokens.
    
3. Populate the following fields:

|Field|Source|
|---|---|
|Project|User-confirmed at the Project selection gate below|
|Issue Type|Epic or Task per R4C|
|Summary|Title + core behavior or problem (max 10 words)|
|Description|Assembled per Description Structure below|
|Priority|Recommended based on risk and impact (see below)|
|Labels|Work type in lowercase + codebase area|
|Epic Link|Recommended epic (Task only — see below)|

    **Project selection (new-card path only — skip when updating an existing card, whose project is fixed by its key):** Never guess the Jira project; an educated guess that is usually right still creates cards in the wrong space when it isn't. Before any other field confirmation:

    1. Determine the recommended project key from the strongest evidence available: the project of material related cards in `$MEM/related-cards.md` (R1), the project of an epic confirmed in R1, or the project of any Jira issue the user referenced during intake. Call `jira_get_all_projects` to validate the candidate key and identify plausible alternates. If no evidence points to a project, work from that list alone.
    2. Use `AskUserQuestion` (Header: `Jira Project`, Question: `Which Jira project should this card be created in?`, Options: `<KEY> — <project name> (Recommended)` first with a description naming the specific evidence, then up to two alternates with their evidence; the user can type any other key via the auto-injected Other input). When there is no evidence-backed recommendation, present the most plausible projects from the list without a `(Recommended)` tag and say so plainly — do not manufacture a recommendation.
    3. Record the confirmed key in `$MEM/work-item.md` frontmatter as `jira_project: <KEY>`. On resume, if `jira_project` is already recorded, use it without re-asking. Pass it as the `project_key` on `jira_create_issue` — never a key the user did not confirm.

    **Priority recommendation:** Before creating the issue, determine the recommended priority based on the risk register from R4B and the overall impact of the work item. Consider: user-facing impact, number of affected areas, dependency urgency, and whether this unblocks other work. Use `AskUserQuestion` with header `Task Priority` to confirm. Put the recommended priority first with `(Recommended)` appended. Options: one of `Critical (Recommended)` / `High (Recommended)` / `Medium (Recommended)` / `Low (Recommended)` as the first option (only the recommended one gets the label), then the remaining three priorities as subsequent options.

    **Epic recommendation (Task issue type only — skip for Epics):** If an epic was already confirmed in R1, present it as the recommendation. If no epic was confirmed, search Jira for open epics in the same project that relate to the affected areas, work type, or goals identified in R0–R4. Use `AskUserQuestion` with header `Epic Link`, options: `Use suggested epic: <KEY> (Recommended)` (description: "Link to the identified epic") / `Provide a different epic key` (description: "Type a different epic key in the Other field") / `No epic` (description: "Create the issue without an epic link"). Only set the Epic Link if the user selects the suggested epic or provides a key via Other.

    **API notes for non-standard fields:**
    - **Priority:** Set via `additional_fields`: `{"priority": {"name": "Medium"}}` (substituting the confirmed priority name: Critical, High, Medium, or Low).
    - **Labels:** Set via `additional_fields`: `{"labels": ["label1", "label2"]}` on `jira_create_issue`.
    - **Epic Link:** Set via `additional_fields`: `{"epicKey": "EPIC-KEY"}` on `jira_create_issue`. Do not use `jira_create_issue_link` for epic links — that creates a lateral link, not an epic association. Only include this field if the user confirmed an epic.

4. **Update-or-create decision:**
    - **If an existing Jira card was provided in R0:** Update that card's description using `jira_update_issue` with the approved description. Do not create a new issue.
    - **If no existing card was provided:** Create a new Jira issue using `jira_create_issue` with the approved description. Do not perform a follow-up description update solely to add execution instructions.

5. **Post-creation linking:** After the issue is created or updated, link hard dependencies from R4B by calling `jira_create_issue_link` for each one. Use `link_type: "Blocks"` for hard dependencies. Do not attempt to set linked issues during `jira_create_issue` — that tool does not support it.

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
[Structured list from `work-item.md`'s `## Affected Areas` (built in R2). For each area:
file/module/service path, brief description of relevance, and risk level.]
- `[path]` -- [description] ([high/medium/low] risk)

## Architecture
[UI navigation and component-state flowchart from R4D — paste the Mermaid source here as a ```mermaid block.
If the flowgraph was skipped in R4D, write: "None — no diagram for this change."]

## Patterns & Code References
[From `work-item.md`'s `## Patterns & Code References` (built in R4E) — component-reuse, design-token,
and style conventions to follow. References are durable; snippets are illustrative and may drift — the
referenced file is source of truth. "None — no established pattern to follow." if greenfield.]
**Patterns to follow:**
- **[name]** — [description]. Canonical example: `[path:line]`.
**Code references:**
- `[path:line_range]` — [what to mirror]
**Illustrative snippets (1–3 most important only):** each in a fenced code block, prefixed
with a `// [path:line_range]` comment, ≤ ~15 lines, read from the referenced range.
**Integration points:**
- [with_area] via [interface] — [description] ([direction]), or "None identified."

## Non-Functional Requirements
[Performance and compliance expectations raised in R3 (accessibility is captured in its own
section below). Verifiable target where possible; "None specified" per line if N/A.]
- **Performance:** [budget/target, e.g. LCP, bundle size, or N/A]
- **Compliance:** [requirement, or N/A]

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
[Gherkin from R4A — copy verbatim. Render as a single fenced gherkin code block headed by
`Feature:`, with one `Scenario:` per behavior (Given/When/Then/And). Every criterion is a
Scenario — no plain outcome bullets. Example shape:
  Feature: <component/capability>
    Scenario: <behavior or state>
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

---

> **REQUIRED: Review the full issue description before presenting.** Verify: (1) all fields are populated with no placeholder text, (2) the Acceptance Criteria is a single fenced ` ```gherkin ` block headed by `Feature:` where every criterion is a `Scenario` (Given/When/Then) with no plain outcome bullets mixed in — rewrite any that are not, (3) the Affected Areas field is populated from R2 codebase analysis, (4) Patterns & Code References is populated from `work-item.md`'s `## Patterns & Code References` (built in R4E) (or explicit "None"), with any snippet carrying its `// path:line_range` header, (5) all defined Visual Specifications are populated from `work-item.md`'s `## Design Spec` (built in R2), (6) Component States covers all states defined in R3, (7) Non-Functional Requirements and Accessibility Requirements reflect R3 answers, (8) no workflow instructions or skill-invocation text were embedded, and (9) the issue type matches the R4C recommendation. For any section where no specs were defined, write "Not defined." — do not leave placeholder text.

> **APPROVAL GATE — FULL STOP.** Present the fully assembled issue description in the chat. Then use `AskUserQuestion` with header `R5 Approval`, options: `Approve and proceed (Recommended)` (description: "Content is accurate — create or update the Jira issue") / `Request changes` (description: "Something needs correction before creating"). Do not create or update the Jira issue until approved.

---

### R6 — Cleanup

**Objective:** Remove the work item's file-memory directory (and any upstream implementation-discovery directory) after explicit user confirmation, now that everything is materialized into the Jira issue.

**Agent Actions:**

1. **Enumerate.** List the directories that will be removed:
   - `$MEM` — this intake's work-item directory (`work-item.md`, `clarifications.md`, `criteria.md`, `related-cards.md`, `explorations/*.md`, `checkpoint.md`, `work-item.html`).
   - Any upstream **implementation-discovery** directory reused at R0/R2: `$MEMROOT/discovery-<slug>/`. These persist intentionally from a prior `/implementation-discovery` run; if discovery was reused, design-intake R6 owns reaping it once the card is final.

2. **Present the cleanup plan to the user.** Build a short, structured summary in the chat:

   ```
   ## R6 Cleanup Plan

   The following file-memory directories will be removed now that the Jira issue is finalized:

   - This design intake: web-cms-memory/<work-item-key>/  (<file count> files)
   - Upstream implementation discovery (if reused): web-cms-memory/discovery-<slug>/  (or "none — no discovery reused")
   ```

   If no implementation-discovery directory was reused, state that explicitly.

3. > **APPROVAL GATE — FULL STOP.** Use `AskUserQuestion` with header `R6 Cleanup`, options: `Proceed with cleanup (Recommended)` (description: "Remove the listed file-memory directories") / `Skip cleanup` (description: "Leave them in place; they remain on disk"). Do not run `rm -rf` until the user selects "Proceed with cleanup". On "Skip cleanup", leave the directories in place, note in the chat that cleanup was skipped at the user's request, and end the workflow.

4. **Execute deletion.** On explicit confirmation, `rm -rf "$MEM"` and (if a discovery was reused) `rm -rf "$MEMROOT/discovery-<slug>"` (Bash). Each removal is atomic. Report a one-line confirmation: "Cleanup complete: removed <N> directories."

5. Do not leave requirements state on disk after it has been fully materialized into the Jira issue, except when the user explicitly declined cleanup at step 3.

---

## Completion Criteria

This workflow is complete when **all** of the following are true:

- All 7 phases executed in sequence (R0-R6)
- All 7 approval gates explicitly confirmed in the chat (R0–R6 inclusive; R6 is the cleanup confirmation)
- All self-review checks passed before presenting output
- Jira issue updated (existing card) or created (new card) with all requirements populated, no unresolved placeholder text, and no embedded workflow or skill-invocation instructions
- Task Details section includes a structured Affected Areas field populated from R2 codebase analysis
- Visual Specifications, Component States, Responsive Behavior, and Accessibility Requirements sections are all populated (or explicitly state "Not defined." for unspecified areas)
- R6 cleanup either removed the work-item file-memory directory (and any upstream implementation-discovery directory) after the Jira record was finalized, or the user explicitly declined cleanup at the R6 approval gate
