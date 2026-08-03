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

**FILE MEMORY SCOPE:** This workflow stores session state in a per-work-item file-memory directory. `$MEM/work-item.md` is the root (title, description, and the `## Affected Areas`, `## Patterns & Code References`, `## Architecture` sections built across R2/R4); `$MEM/clarifications.md` holds R3 Q&A; `$MEM/criteria.md` holds R4A acceptance criteria; `$MEM/related-cards.md` holds relevant related Jira cards from R1; `$MEM/explorations/*.md` hold R2 codebase findings; `$MEM/children.md` (fill-out + Epic only) holds the child roster. Compute `MEM` once with the recipe in `file-memory-protocol.md` §1 (`<work-item-key>` = the Jira key, or `intake-<slug>`). All file content must be fully materialized into the Jira card description in R5 before the session ends. See `file-memory-protocol.md` for schemas, the checkpoint/compaction contract, and the full-context-load rule.

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
- R2 — Codebase Analysis
- R3 — Stakeholder Q&A
- R4 — Requirements Synthesis
- R5 — Jira Issue Creation or Update
- R6 — Cleanup

**CHECKPOINT & COMPACTION CONTRACT:** This workflow records position in a single `$MEM/checkpoint.md` file (full schema and contract in `file-memory-protocol.md` §4) — important for long fill-out + Epic runs with per-child loops.

**Per-phase checkpoint — after EVERY phase (R0–R5), automatically, with no chat output and no `/compact` prompt.** Atomically overwrite `$MEM/checkpoint.md` (`Write` to `checkpoint.md.tmp`, then `mv` over `checkpoint.md`) with `checkpoint_type: phase`, the just-completed `phase`, the upcoming `next_phase`, the `references` list, `mode` (define/fill_out), `## Decisions`, and `## Open items`. During R5B, also set `child_completed` and `next_child`.

**Compaction gates (R2, R4, R5B per-child) — additionally prompt the user to `/compact`.** Do the per-phase write but with `checkpoint_type: gate`, then: (1) wait for any background `area-mapper` to finish; (2) emit the Phase Summary block (§4(b)) — phase + skill, work item key, mode, child-completion status (R5B), one-line decisions, verbatim approval condition, `next_phase`, the checkpoint file path, and the resume contract; (3) end the turn with the literal line **"Run `/compact` now, then type `continue` to resume."** Do NOT call `AskUserQuestion` at a gate.

**Universal resume rule — on ANY resume, before doing anything else:** `Read $MEM/checkpoint.md` → `Read` every file in its `references` → **re-read the `next_phase` section of this `workflow.md`** (any phase asking clarifying/structured questions MUST use `AskUserQuestion`) → continue at `next_phase`. If `$MEM` is absent, restart the affected phase from the Jira card and prior chat. Approval gates stay chat-scoped — never assume a pending approval was granted.

---

### R0 — Intake

**MODE DETECTION:** Before anything else, inspect `$ARGUMENTS`. If it contains a value matching the pattern `[A-Z][A-Z0-9_]+-\d+` (a Jira issue key), enter **fill-out mode**:
- Record the key as the target for this run. Skip the discovery pre-check (moot when we already know which card to update). Skip step 2 (work type) and step 3 below if the work type can be inferred from the existing card's issue type and description shape — you will confirm it in R1 instead.
- Skip the "Has a Jira card already been created for this?" question in step 3 entirely — the answer is already known.
- Questions whose answers can be read from the existing card (e.g. title, summary, requestor) should be pre-filled from the card's content and confirmed with the user rather than re-asked from scratch.

If `$ARGUMENTS` is empty or absent, enter **define mode** and run R0 exactly as written below.

**DISCOVERY PRE-CHECK:** Before greeting the user (or, in fill-out mode, before presenting the fill-out context summary), `Glob $MEMROOT/discovery-*/summary.md` (compute `$MEMROOT` via the recipe in `file-memory-protocol.md` §1) to find any prior `/implementation-discovery` summary (dirs are named `discovery-<topic-slug>` so multiple discoveries in one session do not collide). `Read` each `summary.md` frontmatter (`topic_slug`, `chosen_approach`, `verification_status`, `discovery_confirmed`).
1. **If exactly one is present:** acknowledge it immediately: "I found a prior implementation discovery session for: **[topic]** (chosen approach: **[chosen_approach]**, verification: **[verification_status]**). I'll use those findings as a head start — the codebase areas have already been explored and verified. If this isn't the right context, just say so and I'll start fresh."
2. **If multiple are present** (the user ran more than one discovery in this session): list them by `topic` and `chosen_approach`, then use `AskUserQuestion` (Header: `Discovery Pick`, Question: `Multiple discovery sessions were found. Which one is this requirements run for?`, Options: one option per discovery summary labeled `[topic] — [chosen_approach]`, plus `Start fresh — ignore all discoveries`) to ask the user which one to use. Treat the user's pick as the selected `discovery-<slug>/summary.md`; ignore the others for this run.
3. **If the user confirms a discovery summary:** set `discovery_confirmed: true` in that specific `discovery-<slug>/summary.md` frontmatter (`Edit`), not in any other. When asking intake questions in step 3 below, skip the "areas of the codebase you already know are involved" question — the discovery already covers it. Note that R2 (Codebase Analysis) will use the discovery findings and skip spawning new codebase-explorer agents.
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
   - Existing Jira card — **Before asking**, run `git rev-parse --abbrev-ref HEAD` and apply a regex match for `[A-Z]+-[0-9]+` against the branch name. If a candidate key is found: `AskUserQuestion` (Header: `Existing Card`, options: `Yes, <extracted key>` (description: "Use <extracted key> as the existing Jira card for this work") / `Use a different key` (description: "Type the correct issue key in the Other field") / `No existing card`). If no candidate is found: `AskUserQuestion` (Header: `Existing Card`, options: `Yes — I'll provide the key` (description: "Type the issue key in the Other field") / `No existing card`).
   - Existing Jira Epic — Ask only if the existing card confirmed above is not itself an Epic. If an existing card was confirmed: `AskUserQuestion` (Header: `Related Epic`, Question: `Is there a Jira Epic this should fall under?`, options: `Already linked via the card` (description: "The card is already linked to its Epic — no separate input needed") / `Yes — I'll provide the key` (description: "Type the Epic key in the Other field") / `No`). If no existing card was provided: `AskUserQuestion` (Header: `Related Epic`, Question: `Is there a Jira Epic this should fall under?`, options: `Yes — I'll provide the key` (description: "Type the Epic key in the Other field") / `No`).
   - Are there any areas of the codebase you already know are involved — repos, services, modules, or file paths?
   - Is there any additional context that would help define this requirement?

   **If Maintenance:**
   - What is driving this work — tech-debt cleanup, refactor, scheduled maintenance, dependency constraint, compliance requirement, alert, or something else?
   - What is the impact of leaving this unaddressed?
   - Are there any areas of the codebase you already know are involved?
   - Existing Jira card — **Before asking**, run `git rev-parse --abbrev-ref HEAD` and apply a regex match for `[A-Z]+-[0-9]+` against the branch name. If a candidate key is found: `AskUserQuestion` (Header: `Existing Card`, options: `Yes, <extracted key>` (description: "Use <extracted key> as the existing Jira card for this work") / `Use a different key` (description: "Type the correct issue key in the Other field") / `No existing card`). If no candidate is found: `AskUserQuestion` (Header: `Existing Card`, options: `Yes — I'll provide the key` (description: "Type the issue key in the Other field") / `No existing card`).
   - Existing Jira Epic — Ask only if the existing card confirmed above is not itself an Epic. If an existing card was confirmed: `AskUserQuestion` (Header: `Related Epic`, Question: `Is there a Jira Epic this should be tracked under?`, options: `Already linked via the card` (description: "The card is already linked to its Epic — no separate input needed") / `Yes — I'll provide the key` (description: "Type the Epic key in the Other field") / `No`). If no existing card was provided: `AskUserQuestion` (Header: `Related Epic`, Question: `Is there a Jira Epic this should be tracked under?`, options: `Yes — I'll provide the key` (description: "Type the Epic key in the Other field") / `No`).
   - Is there any additional context that would help define this work?

4. After all questions are answered, summarize the gathered context back to the user in a clear, structured format.
    

> **BOOTSTRAP FILE MEMORY:** After the R0 approval gate is confirmed, compute `MEM` (recipe §1) where `<work-item-key>` is the existing Jira issue key (if provided via `$ARGUMENTS` or step 3) or a normalized slug of the title prefixed with `intake-` (e.g. `intake-add-retry-logic`). `mkdir -p "$MEM/explorations"` and `Write $MEM/work-item.md` (schema §3.1) with `work_type` (feature/maintenance), `jira_key` (or null), `title`, `status: in_progress`, `phase: R0`, `skill: requirements-intake`, `mode` (define/fill_out), and the full description under `## Description` (capture verbatim — do not summarize or truncate). `existing_issue_type` is filled after R1. This is the root file; subsequent phases add `## Affected Areas`, `## Patterns & Code References`, and `## Architecture` sections plus the sibling files, and R5 reads them all to assemble the Jira issue description. The `MEM` path (as `memory_dir`) is passed to every `codebase-explorer` call in R2.

> **REQUIRED:** The following context must be confirmed before proceeding:
> 
> - Work Type (Feature / Maintenance)
> - Title or Name
> - Description or Problem Statement (capture in full — do not summarize or truncate the user's input)
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

2. **Fill-out mode — Epic with children.** If the existing card is an Epic, also enumerate its child tasks: call `jira_search` with JQL `parent = "<EPIC-KEY>"`. If that returns no results, also try `"Epic Link" = <EPIC-KEY>`. For each child found, call `jira_get_issue` to read the full description and capture: `key`, `summary`, `status`, and which work-type-template sections (Overview, Acceptance Criteria, Affected Areas, Scope, etc.) are already present. Record them in `$MEM/children.md` (schema §3.8) — one entry per child with `key`, `title` (summary), `status`, `existing_sections_present` (list of section headings found), and `existing_sections_missing` (template sections that are absent or stub-only). These entries drive the per-child loop at R5B.

3. If a Related Epic was provided in R0 (define mode, or as context for a Task fill-out), retrieve its description, status, and all child issues.
4. Search Jira for existing issues that overlap with the work item using keyword and label search. **Related-card capture:** for each candidate that passes the relevance bar (materially informs scope, design, or implementation — not merely a duplicate to flag), call `jira_get_issue` to read its description and append it to `$MEM/related-cards.md` (schema §3.7) with `key`, `title`, `status`, `relationship` (overlaps | depends-on | prior-art | same-area | superseded-by), a one-line `why_relevant`, and a concise excerpt of the pertinent section (never the whole description). Log any candidate that fails the bar in the chat rather than storing it. R4 reads `related-cards.md` and distills material cards into the new card; pure duplicates are still surfaced at the R1 gate.
5. Identify any sibling Epics or themes that appear contextually related.

> **RECORD JIRA CONTEXT:** If a related Epic exists, set `related_epic: <key>` in `$MEM/work-item.md` frontmatter. Overlapping/related issues are captured in `$MEM/related-cards.md` (step 4 above). If an existing card was provided, fold its captured context into `work-item.md`'s `## Description`. For fill-out + Epic, the child entries are in `$MEM/children.md` (step 2).

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

**DISCOVERY PRE-CHECK:** Before spawning codebase-explorer agents, `Read` the `discovery-<slug>/summary.md` confirmed in R0 (the one with `discovery_confirmed: true`). If present, codebase analysis is already complete:
1. **Announce:** "Codebase analysis is already complete from the prior discovery session for `[chosen_approach]` (verification status: [verification_status]). Using [N] affected areas identified in discovery." If `verification_status` is `accepted_with_open_questions`, also surface a one-line note that open questions from verification are carried into this intake.
2. **Copy the discovery explorations into this work item.** Copy each `discovery-<slug>/explorations/*.md` into `$MEM/explorations/` (Bash `cp`) so R4A/R4E read them via the normal `$MEM/explorations/*.md` path. Skip any exploration file (or finding) marked superseded at D4 — the verification round wrote replacements.
3. **Record affected areas in `work-item.md`.** Write the discovery's affected areas (from `summary.md`'s `affected_areas`) into `$MEM/work-item.md`'s `## Affected Areas` section: each area path with type (module default) and risk (use any explicit risk level from `## Synthesis (chosen)`, else medium). Use only the chosen approach's areas — do not pull in unchosen-option areas.
4. **Use `summary.md`'s `## Synthesis (chosen)` as the codebase analysis content** — not any unchosen-option record. It is the canonical human-readable analysis for this intake and reflects any D4 revisions.
5. **Surface open questions as structured input to R3 / R4.** Read `summary.md`'s `## Open questions` — each (both D3-origin and D4-origin) is carried into this intake as a candidate clarifying question for R3 and a candidate risk for R4.
6. Skip Agent Actions steps 1–6 entirely. Present the synthesis as the codebase analysis and proceed directly to the approval gate.

**Objective:** Identify the code surfaces this work item will touch to ground scope and acceptance criteria in reality.

**Agent Actions:**

1. Identify all distinct areas of the codebase to explore based on the Codebase Hints from R0, the Related Epic from R1, and the work item description. Limit the scope of this exploration to the current project directory.
2. Invoke a `codebase-explorer` sub-agent in **parallel** for each distinct area in this project, providing:
    - The target area to explore
    - A question tailored to the work type:
        - **Feature:** "What code, patterns, and conventions are relevant to implementing [feature description] in this area?"
        - **Maintenance:** "What is the current state of [problem area] — what exists today, why does it need to change, what components/dependencies/configuration will be touched, and are there compatibility or rollback considerations?"
    - The `memory_dir` (`$MEM`) and a normalized `area_slug`. The explorer writes its findings to `$MEM/explorations/<area_slug>.md`.
    - The work item description for context
3. Wait for all explorers to return. Each non-failed return contains a `File:` line with the exploration file name. Treat `INCOMPLETE` as partial: findings are present but the run did not finish; consider re-spawning for the same area if coverage matters. Treat `FAILED` as no file written — re-spawn that explorer before proceeding.

> **POST-EXPLORATION ENRICHMENT:** Spawn the `area-mapper` sub-agent **in the background** (`run_in_background: true`) with the same `memory_dir` (`$MEM`). The mapper crystallizes durable area knowledge from this run's exploration files into Serena project memory so future explorations of the same areas start with hot context. Do not wait for it — proceed immediately to step 4.
4. `Read` each `$MEM/explorations/<area_slug>.md` from the returns. If any file is missing or empty, re-spawn that explorer rather than treating missing data as confirmed. Surface any `open_questions` entries. If any identifies a connection to another area not already explored, dispatch a follow-up `codebase-explorer` for that area (passing the same `memory_dir`) before proceeding.
5. Synthesize the findings from the exploration files into a unified codebase analysis. Read across all `$MEM/explorations/*.md` and aggregate:
    - **Affected files** — collected from each file's `affected_files` array. Group by module / service for the user-facing analysis.
    - **Patterns and conventions** — from `patterns`; cite `evidence_files` when present.
    - **Integration points** — from `integration_points`.
    - **Risks** — from `risks`, ordered by severity.
    - **Work-type-specific findings** — for Maintenance, the current state of the affected area plus any compatibility/rollback considerations — from the relevant `evidence` and `patterns` entries.
6. Label any items derived from `evidence` or `affected_files` entries marked `inferred: true` as `[INFERRED]` in the user-facing analysis.

> **WRITE Affected Areas to work-item.md:** After synthesizing, roll up the explorations' `affected_files` into an `## Affected Areas` section in `$MEM/work-item.md` that downstream phases (R4A, R5) read. For each distinct file / module / service / schema / component, write: `name`, `type` (file / module / service / schema / component), `risk` (high / medium / low — taken from the highest-severity `risk` that links to any of its files, defaulting to `medium`), and any relevant notes. Mark entries derived only from `inferred: true` findings as `[INFERRED]`. The granular `explorations/*.md` files remain alongside — R4A/R4E read them for fine-grained checks.

> **REQUIRED:** Present all of the following in the chat before proceeding:
> 
> - List of likely affected files / modules / services with rationale
> - Relevant existing patterns or conventions to follow
> - High-risk areas flagged with reasoning
> - Work-type-specific analysis (for Maintenance: current state and compatibility/rollback notes)

> **REQUIRED: Review the codebase analysis before presenting.** Verify every item is grounded in actual evidence. Label speculative entries as `[INFERRED]`. Do not present an unreviewed analysis.

> **APPROVAL GATE — FULL STOP.** Present the codebase analysis. Use `AskUserQuestion` (Header: `R2 Approval`, Question: `Are the scope areas correct and complete? Does the codebase analysis look accurate?`, Options: `Approve and proceed (Recommended)` — scope areas are correct and complete, `Request changes` — something needs revision). Do not proceed to R3 until the user approves.

> **COMPACTION GATE — R2:** Once R2 approval is confirmed, follow the Checkpoint & Compaction Contract above (gate path). Write `checkpoint.md` with `phase: R2`, `next_phase: R3`, `checkpoint_type: gate`, `mode`, `references: [work-item.md, explorations/*.md, related-cards.md]`; `## Decisions`: confirmed scope areas and work type. Emit the Phase Summary block and instruct the user to run `/compact` before proceeding to R3.

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
    

> **WRITE clarifications.md:** After answers are confirmed, append each Q&A pair to `$MEM/clarifications.md` (schema §3.5) as an `items[]` entry with `question`, `answer`, `priority` (blocking / nice_to_have), and `category` (scope_boundary / dependencies / non_functional / data_interface / observability / functional / edge_cases / etc.). R4A reads these to derive traceable acceptance criteria; R5 reads the `non_functional`, `data_interface`, and `observability` items to populate their dedicated description sections.

> **REQUIRED:** Present all BLOCKING questions answered and answers recorded, and remaining unanswered questions listed as open items with owner and target resolution date.

> **APPROVAL GATE — FULL STOP.** Present all questions and recorded answers. Use `AskUserQuestion` (Header: `R3 Approval`, Question: `Are all blocking answers accurate and open items correctly captured?`, Options: `Approve and proceed (Recommended)` — all blocking answers are correct, `Request changes` — some answers need revision). Do not proceed to R4 until the user approves.

---

### R4 — Requirements Synthesis

**Objective:** Translate all gathered context into acceptance criteria, a risk register, and a scoping recommendation.

> **FULL CONTEXT LOAD:** Before synthesizing, `Glob $MEM` and `Read` every present input file — `work-item.md` (description + `## Affected Areas`), every `explorations/*.md`, `clarifications.md`, and `related-cards.md` (per `file-memory-protocol.md` §5). Synthesize on the full context, never a partial read.

---

#### R4A — Acceptance Criteria

> **USE SEQUENTIAL THINKING:** Before writing acceptance criteria, invoke the `sequentialthinking` tool. For each candidate criterion, verify it is: (1) **unambiguous** — only one possible interpretation, (2) **testable** — can be verified without further clarification, and (3) **traceable** — directly derived from an R3 answer or R2 finding. Work through each criterion in sequence and revise any that fail before presenting.

> **THINK HARD:** Before finalizing the criteria, think hard about traceability and testability specifically — criteria that sound reasonable but cannot be independently verified without additional clarification are design defects, not just gaps. Poor criteria quality is the single most consistent source of scope creep and rework in downstream execution.

> **WRITE criteria.md:** After criteria are finalized, `Write $MEM/criteria.md` (schema §3.6) with `format` (gherkin / outcome_based) and a `criteria[]` array — each entry `text` + `traceable_to` (the `clarifications.md` item id or affected-area it was derived from) — plus the verbatim criteria block in the body. R5 reads this to populate the Acceptance Criteria section verbatim.

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

> **REUSE EXISTING DIAGRAM:** Before generating a flowgraph, if a discovery was reused, `Read` the discovery's `summary.md` (and any architecture diagram it carried). If one exists, use it as the starting point and refine it to reflect the requirements-level behavior — do not start from scratch.

> **GENERATE A FLOWGRAPH (best-effort):** Produce a Mermaid `flowchart` that visualizes the intended feature behavior — map the user-facing flow or system behavior through the acceptance criteria. Nodes should represent meaningful states, actions, or decision points (e.g. form submitted → validation → success/error), not abstract phases.
>
> - **Skip it** for single-criterion or trivially linear changes where a diagram adds no clarity. If skipped, state in one line why.
> - **Render it in the chat** as part of the R4 synthesis presentation at the approval gate.
> - **The diagram will be embedded in the Jira description under `## Architecture`** by R5 when it assembles the description from the templates below. No additional action needed here beyond persistence.
> - **Persist it** to `$MEM/work-item.md`'s `## Architecture` section (as a ```mermaid block) so R5 and downstream execution skills can read it.

---

#### R4E — Patterns & Code References

> **READ explorations:** Read all `$MEM/explorations/*.md` and collect the `patterns` (name, description, evidence_files), `evidence` (claim, file, line_range, confidence), and `integration_points` (with_area, interface, description, direction) entries. Skip any marked `inferred: true` unless clearly labelled. When discovery was reused (R2 discovery pre-check), the copied discovery explorations are already under `$MEM/explorations/`.

1. Select the established patterns and conventions this work must follow, plus the concrete code anchors that demonstrate them. Prefer high-`confidence`, code-grounded `evidence`; drop `inferred: true` items unless clearly labelled `[INFERRED]`.
2. For the **1–3 most important** patterns, use `Read` to open the referenced `file` at its `line_range` and extract a short (≤ ~15-line) illustrative snippet. Prefix each snippet with a `// <path>:<line_range>` comment. Keep snippets minimal — the file is the source of truth; do not paste whole functions.
3. List the integration points the work must respect.
4. If no established pattern applies (greenfield area), record "None — no established pattern to follow." Do not fabricate a pattern.

> **WRITE Patterns & Code References to work-item.md:** Persist the selected patterns into `$MEM/work-item.md`'s `## Patterns & Code References` section: `patterns` (name + description + canonical `path:line` each), `code_references` (`path:line_range` + what to mirror), `snippets` (extracted snippet text with its `path:line_range` header), and `integration_points`. R5 reads this section to populate the card's `## Patterns & Code References`.

> **REQUIRED:** Present the Patterns & Code References list (patterns, code references, the 1–3 snippets, integration points) as part of the R4 synthesis at the approval gate below.

---

> **REQUIRED: Review the full R4 synthesis before presenting.** Verify every acceptance criterion is unambiguous, testable, and traceable. Remove or revise any that fail this check. Do not present an unreviewed synthesis.

> **BLIND-SPOT CALLOUT (conditional):** After presenting the synthesis and before asking for approval, answer this question for the user: *"What is the biggest thing the user may be missing about this requirement — what don't they realize?"* Render the answer as a short **What you might be missing** block containing at most two specific, evidence-backed items drawn from the R2 exploration findings (`risks`, `integration_points`), related cards, or the R3 answers — cite the source (exploration file, card key, or `path:line`) for each. This is the last moment before the requirement is locked into a card that every downstream phase treats as ground truth — typical candidates: hidden coupling that makes the work bigger than the user believes, prior art that changes the approach, a scope implication of an R3 answer the user may not have connected. If nothing qualifies, write exactly one line — "Nothing notable — the synthesis surfaces the known risks." — and never invent a generic risk to fill the section.

> **APPROVAL GATE — FULL STOP.** Present the full R4 synthesis (acceptance criteria, risk register, Epic vs. Task recommendation, and Patterns & Code References). Use `AskUserQuestion` (Header: `R4 Approval`, Question: `Is the full R4 synthesis correct — acceptance criteria, risk register, Epic vs. Task recommendation, and Patterns & Code References?`, Options: `Approve and proceed (Recommended)` — the synthesis is correct, `Request changes` — something needs revision). Do not create a Jira issue of the wrong type. Do not proceed until the user approves.

> **REGENERATE DASHBOARD:** After approval, regenerate `$MEM/work-item.html` from the current memory files (per `file-memory-protocol.md` §8) so the user has an up-to-date rendered view of the synthesized requirements and flowchart.
>
> **COMPACTION GATE — R4:** Once R4 approval is confirmed, follow the Checkpoint & Compaction Contract above (gate path). Write `checkpoint.md` with `phase: R4`, `next_phase: R5`, `checkpoint_type: gate`, `mode`, `references: [work-item.md, criteria.md, clarifications.md, related-cards.md, explorations/*.md]`; `## Decisions`: issue type recommendation (Epic or Task), criterion count, key risks; `approval_condition`: verbatim user phrasing if any conditional approval was given. Emit the Phase Summary block and instruct the user to run `/compact` before proceeding to R5.

---

### R5 — Jira Issue Creation or Update

**Objective:** Create or update the Jira issue with all requirements and a pointer to the appropriate execution skill.

**Agent Actions:**

1. > **FULL CONTEXT LOAD:** `Glob $MEM` and `Read` the full set to assemble the Jira issue description — `work-item.md` (`## Description`, `## Affected Areas`, `## Patterns & Code References`, `## Architecture`), `clarifications.md` (the `non_functional`, `data_interface`, `observability` items populate their dedicated description sections), `criteria.md` (Acceptance Criteria verbatim), and `related-cards.md` (distill material related cards into `## Dependencies` / `## Patterns & Code References` / `## Context`). This ensures nothing is missed or invented and the description is fully grounded in the structured context built across R0–R4.
    
2. Assemble the Jira issue description using the requirements-only description structure matching the work type below. The description must contain only the structured delivery context for the work item. Do not append workflow instructions, skill-invocation text, or placeholder tokens.
    
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

    **Project selection (define mode only — fill-out mode inherits the existing card's project from its key):** Never guess the Jira project; an educated guess that is usually right still creates cards in the wrong space when it isn't. Before any other field confirmation:

    1. Determine the recommended project key from the strongest evidence available: the project of material related cards in `$MEM/related-cards.md` (R1), the project of an epic confirmed in R1, or the project of any Jira issue the user referenced during intake. Call `jira_get_all_projects` to validate the candidate key and identify plausible alternates. If no evidence points to a project, work from that list alone.
    2. Use `AskUserQuestion` (Header: `Jira Project`, Question: `Which Jira project should this card be created in?`, Options: `<KEY> — <project name> (Recommended)` first with a description naming the specific evidence (e.g. "related card ELI-900 lives here"), then up to two alternates with their evidence; the user can type any other key via the auto-injected Other input). When there is no evidence-backed recommendation, present the most plausible projects from the list without a `(Recommended)` tag and say so plainly — do not manufacture a recommendation.
    3. Record the confirmed key in `$MEM/work-item.md` frontmatter as `jira_project: <KEY>`. On resume, if `jira_project` is already recorded, use it without re-asking. Pass it as the `project_key` on `jira_create_issue` — never a key the user did not confirm.

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

For each child entry in `$MEM/children.md`, in stable order (by Jira key):

1. **R5B.1 — Per-child Q&A.** Use `AskUserQuestion` to confirm: the child's work type (Feature / Maintenance — inferred from its description shape and pre-filled for confirmation), and any blocking gap flagged by `existing_sections_missing` from R1. Keep it to at most 3 questions per child; defer anything `[NICE TO HAVE]`. Allow the user to skip any question by selecting `Skip — non-blocking`.

2. **R5B.2 — Per-child synthesis.** Use `sequentialthinking` to draft a description for this child using the appropriate work-type template (from the Description Structure section above). Inputs: the parent epic's freshly written AC (from R5A), this child's existing description, R2 codebase findings relevant to this child's scope, and the per-child Q&A answers from R5B.1. The synthesized description must:
   - Be fully populated with no placeholder text.
   - Include a Context section that references the parent epic key and summary.
   - Use the correct AC format for the work type. For **Feature** children, AC MUST be Gherkin: a single fenced ` ```gherkin ` block headed by `Feature:` with one `Scenario:` per behavior (Given/When/Then/And) and no plain outcome bullets mixed in (see the R4A canonical shape). **Maintenance** children use outcome-based criteria.
   - Not perform a coverage check across siblings — that is `epic-card`'s job.

3. **R5B.3 — Per-child approval.** Present the synthesized description in the chat. Use `AskUserQuestion` with header `R5B: <KEY>`, question `Review the synthesized description for <KEY> — [child summary]. How do you want to proceed?`, options: `Approve and update Jira` (description: "Overwrite this child's Jira description with the synthesized version") / `Skip this child` (description: "Leave this child's description unchanged and move to the next") / `Request changes` (description: "Revise the description before updating"). On `Request changes`, revise and re-present. On `Skip this child`, set `skipped: true` on the child entry in `children.md` and continue to the next child.

4. **R5B.4 — Update child.** On approval, call `jira_update_issue` with the approved description for this child. Set `updated_at: <timestamp>` on the child entry in `children.md`.

5. **R5B.5 — Compaction gate (between children).** After updating this child in Jira, follow the Checkpoint & Compaction Contract above (gate path) before starting the next child. Write `checkpoint.md` with `phase: R5B`, `next_phase: R5B` (or `R6` if this was the last child), `checkpoint_type: gate`, `child_completed: <JIRA-KEY>`, `next_child: <next-JIRA-KEY or "none">`, `references: [children.md, work-item.md]`; `## Decisions`: this child updated (or skipped). Emit the Phase Summary block and instruct the user to run `/compact` before continuing to the next child.

After the loop completes, present a summary in the chat: "Updated parent epic `<KEY>` and `N` of `M` child tasks." (where M is total children enumerated and N is how many were updated, not skipped).

> **UPDATE children.md:** After each child update, set `updated_at` or `skipped: true` on the child entry in `$MEM/children.md`. If context is lost mid-loop (session ends), read `children.md` on resume to identify the next un-actioned child and continue from there. Do not re-present children already marked `updated_at` or `skipped: true`.

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
[Structured list from `work-item.md`'s `## Affected Areas` (built in R2). For each area:
file/module/service path, brief description of relevance, and risk level.]
- `[path]` -- [description] ([high/medium/low] risk)

## Architecture
[Behavior flowchart from R4D — paste the Mermaid source here as a ```mermaid block.
If the flowgraph was skipped in R4D, write: "None — no diagram for this change."]

## Patterns & Code References
[From `work-item.md`'s `## Patterns & Code References` (built in R4E). References are durable; snippets
are illustrative and may drift — the referenced file is the source of truth. "None — no established
pattern to follow." if greenfield.]
**Patterns to follow:**
- **[name]** — [description]. Canonical example: `[path:line]`.
**Code references:**
- `[path:line_range]` — [what to mirror]
**Illustrative snippets (1–3 most important only):** each in a fenced code block, prefixed
with a `// [path:line_range]` comment, ≤ ~15 lines, read from the referenced range.
**Integration points:**
- [with_area] via [interface] — [description] ([direction]), or "None identified."

## Non-Functional Requirements
[From `clarifications.md` items with category non_functional. Verifiable target where possible;
"None specified" per line if N/A.]
- **Performance:** [...]
- **Security / Privacy:** [...]
- **Accessibility:** [...]
- **Compliance:** [...]

## Data & Interface Changes
[From `clarifications.md` items with category data_interface. "None — no data or interface changes." if N/A.]
- **Data model / migrations:** [...]
- **APIs / endpoints:** [method, path, request shape, response shape]
- **Events / messages / config:** [...]

## Observability & Telemetry
[From `clarifications.md` items with category observability. "None — no new instrumentation." if N/A.]
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
[Structured list from `work-item.md`'s `## Affected Areas` (built in R2). For each area:
file/module/service path, brief description of relevance, and risk level.]
- `[path]` -- [description] ([high/medium/low] risk)

## Architecture
[Behavior flowchart from R4D — paste the Mermaid source here as a ```mermaid block.
If the flowgraph was skipped in R4D, write: "None — no diagram for this change."]

## Patterns & Code References
[From `work-item.md`'s `## Patterns & Code References` (built in R4E). References are durable; snippets
are illustrative and may drift — the referenced file is the source of truth. "None — no established
pattern to follow." if greenfield.]
**Patterns to follow:**
- **[name]** — [description]. Canonical example: `[path:line]`.
**Code references:**
- `[path:line_range]` — [what to mirror]
**Illustrative snippets (1–3 most important only):** each in a fenced code block, prefixed
with a `// [path:line_range]` comment, ≤ ~15 lines, read from the referenced range.
**Integration points:**
- [with_area] via [interface] — [description] ([direction]), or "None identified."

## Non-Functional Requirements
[From `clarifications.md` items with category non_functional. Verifiable target where possible;
"None specified" per line if N/A.]
- **Performance:** [...]
- **Security / Privacy:** [...]
- **Accessibility:** [...]
- **Compliance:** [...]

## Data & Interface Changes
[From `clarifications.md` items with category data_interface. "None — no data or interface changes." if N/A.]
- **Data model / migrations:** [...]
- **APIs / endpoints:** [method, path, request shape, response shape]
- **Events / messages / config:** [...]

## Observability & Telemetry
[From `clarifications.md` items with category observability. "None — no new instrumentation." if N/A.]
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
> - **Patterns & Code References** is populated from `work-item.md`'s `## Patterns & Code References` (built in R4E) (or the explicit "None — no established pattern to follow."); any snippet carries its `// path:line_range` header.
> - **Non-Functional Requirements**, **Data & Interface Changes**, and **Observability & Telemetry** are populated from their `clarifications.md` item categories, or each carries its explicit "None …" line — no placeholder text.
> - **For a Feature card:** the Acceptance Criteria is a single fenced ` ```gherkin ` block headed by `Feature:`, every criterion is a `Scenario` (Given/When/Then), and no plain outcome bullets are mixed in. If any are, rewrite before presenting.

> **APPROVAL GATE — FULL STOP.** Present the fully assembled issue description for final review. Use `AskUserQuestion` (Header: `R5 Approval`, Question: `Is the issue description accurate and ready to be created or updated in Jira?`, Options: `Approve and create / update (Recommended)` — content is accurate and ready, `Request changes` — something needs revision). Do not create or update the Jira issue until the user approves.

---

### R6 — Cleanup

**Objective:** Remove the work item's file-memory directory (and any upstream implementation-discovery directory) after explicit user confirmation, now that everything is materialized into the Jira issue.

**Agent Actions:**

1. **Enumerate.** List the directories that will be removed:
   - `$MEM` — this intake's work-item directory (`work-item.md`, `clarifications.md`, `criteria.md`, `related-cards.md`, `explorations/*.md`, `children.md` if present, `checkpoint.md`, `work-item.html`).
   - Any upstream **implementation-discovery** directory reused at R0/R2: `$MEMROOT/discovery-<slug>/`. These persist intentionally from a prior `/implementation-discovery` run, and R6 owns reaping them once the requirements card is final.
   - (Fill-out + Epic) `children.md` lives inside `$MEM` and is removed with it. The child tasks' own execution directories, if any, are owned by their execution workflows — do not remove those here.

2. **Present the cleanup plan to the user.** Build a short, structured summary in the chat:

   ```
   ## R6 Cleanup Plan

   The following file-memory directories will be removed now that the Jira issue is finalized:

   - This requirements intake: web-cms-memory/<work-item-key>/  (<file count> files)
   - Upstream implementation discovery (if reused): web-cms-memory/discovery-<slug>/  (or "none — no discovery reused")
   ```

   If no implementation-discovery directory was reused, state that explicitly.

3. > **APPROVAL GATE — FULL STOP.** Use `AskUserQuestion` (Header: `R6 Cleanup`, Question: `Proceed with cleanup of these directories?`, Options: `Proceed with cleanup (Recommended)` — remove the listed file-memory directories, `Skip cleanup` — leave them in place; they will remain on disk). Do not run `rm -rf` until the user selects Proceed. On any other response, do NOT delete.

4. **Execute deletion.** On explicit confirmation, `rm -rf "$MEM"` and (if a discovery was reused) `rm -rf "$MEMROOT/discovery-<slug>"` (Bash). Each removal is atomic — nothing to enumerate node-by-node. Report a one-line confirmation: "Cleanup complete: removed <N> directories."

5. Do not leave requirements state on disk after it has been fully materialized into the Jira issue, except when the user explicitly declined cleanup at step 3.

---

## Completion Criteria

This workflow is complete when **all** of the following are true:

- All 7 phases executed in sequence (R0-R6)
- All 7 approval gates explicitly confirmed in the chat (R0–R6 inclusive; R6 is the cleanup confirmation)
- All self-review checks passed before presenting output
- Jira issue updated (existing card) or created (new card) with all requirements populated, no unresolved placeholder text, and no embedded workflow or skill-invocation instructions
- Task Details section includes a structured Affected Areas field populated from R2 codebase analysis
- **Fill-out mode + Epic:** Every child entry in `children.md` is marked either `updated_at` (description written to Jira) or `skipped: true` (user elected to skip)
- R6 cleanup either removed the work-item file-memory directory (and any upstream implementation-discovery directory) after the Jira record is finalized, or the user explicitly declined cleanup at the R6 approval gate
