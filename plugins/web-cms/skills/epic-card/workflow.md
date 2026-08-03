# EPIC CARD WORKFLOW — EXECUTION CONTRACT

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute epic phases in strict sequential order (E0 through E11).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure as a comment on this Jira issue. Do not continue.
5. Every required output (comments, plans, summaries) must be posted before the phase is considered complete.

**FILE MEMORY SCOPE:** This workflow's authoritative execution-state map is the epic's file-memory directory. `$MEM/children.md` tracks every child task (Jira key, execution order, dependencies, completion status, and per-child plan detail); `$MEM/plan.md` holds the breakdown narrative + dependency flowchart; `$MEM/work-item.md` is the epic root. Existing children present at workflow start are recorded in `children.md` with `existing: true`. Each child task executes in its OWN sibling directory `<…>/web-cms-memory/<CHILD-KEY>/`. Compute the epic's `MEM` path once with the recipe in `file-memory-protocol.md` §1 (`MEM=<…>/web-cms-memory/<EPIC-KEY>`). If context is lost mid-epic, read `$MEM/checkpoint.md`, `$MEM/children.md`, and `$MEM/plan.md` first to reconstruct exact state. If `$MEM` is absent in a new session, reconstruct from this Jira epic's description and comments, then query each child task's status in Jira before continuing. See `file-memory-protocol.md` §3.8 for the `children.md` schema and §7 for epic cleanup.

**APPROVAL GATE BEHAVIOR:** Approval gates are chat-scoped. If explicit approval is not captured before the session ends or context is lost, stop at the gate. On resume, re-present the latest breakdown plan or testing handoff and ask for confirmation again. Never assume a pending approval was granted.

**CLARIFICATION RULE:** Do not assume anything. If required information is missing, ambiguous, conflicting, or underspecified, stop and use `AskUserQuestion` to ask the user for clarification before proceeding.

**RESUMPTION CHECK:** If this workflow resumes after prior work has already been performed, follow the universal resume rule (read `$MEM/checkpoint.md` and its `references`, including `children.md`) to identify the first incomplete phase. If the epic is already **In Progress**, do not repeat E0. If `$MEM` is absent, rebuild `children.md`, `plan.md`, and `work-item.md` from the latest approved breakdown comment, child task descriptions, and Jira task statuses before continuing. Mid-E8, `children.md` tells you which child is next; that child's own `<CHILD-KEY>/checkpoint.md` tells you where its T-phase stopped (two-level resume).

**SERENA PROJECT ACTIVATION:** Before E0, check Serena's project-activation message (emitted on connect via `--project-from-cwd`); if it reports that onboarding has not been performed, call `onboarding` to scope Serena's language server to the current project directory. Serena's symbol tools (`find_symbol`, `find_referencing_symbols`, `get_symbols_overview`, `search_for_pattern`) and any symbol-aware operations invoked by the `codebase-explorer` agent depend on this being done. Do this once at the start of the workflow; do not repeat it between phases.

**SUB-AGENT NAME RESOLUTION:** This workflow refers to sub-agents by short name (`codebase-explorer`, `plan-reviewer`, `verification-runner`, …). The runtime registers them under different identifiers depending on how they are installed. Before the first sub-agent invocation, resolve each short name against the runtime's available-agents list and use the exact registered identifier:

- If the short name appears verbatim in the list (agents deployed into the project's `.claude/agents/`), use it as-is.
- If installed via the plugin, the registered identifier is `web-cms:<short-name>:<short-name>` — e.g. `verification-runner` → `web-cms:verification-runner:verification-runner`.
- Never invent a partial form such as `web-cms:verification-runner` — it will not resolve. If an invocation fails with an "agent type not found" error, read the available-agents list in the error message, select the entry whose **final segment** equals the short name, and retry with that exact identifier.
- Resolve the scheme once, then reuse it for every subsequent sub-agent invocation in the session (including the T-phase sub-agents spawned during E8 child execution).

**TOOL PREFERENCE:** Prefer native tools over Bash for filesystem work. All filesystem, search, and directory operations must stay within the current project directory.

- **File I/O (read, write, edit a known file):** Use native `Read`, `Write`, `Edit`.
- **File discovery (find files by name or pattern):** Use native `Glob`.
- **Content search (find text inside files):** Use native `Grep`. For symbolic code search (finding classes, methods, or callers), delegate to the `codebase-explorer` agent, which uses the Serena MCP server.
- **Directory operations (list, metadata, move, mkdir):** Use Bash (`ls`, `stat`, `mv`, `mkdir -p`).
- **Git:** Use Bash for all git operations (`git status`, `git diff`, `git log`, `git push`, `git pull`, `git merge`, `git remote`, `git stash`, `git rebase`, etc.) and for running build, test, and lint commands.

**JIRA COMMENT CONTRACT:** Keep Jira comments minimal, structured, and durable. Do not narrate every phase. Routine Jira comments are required only at:

- **E4/E5** — one combined comment containing the reviewed breakdown plan and the approval request
- **E9** — user testing handoff
- **E10** — final epic summary

Additional Jira comments are allowed only for blocking failures, reposting a revised plan after requested changes, or explicit user-requested status updates. Do not post separate narration comments for E0, E1, E2, E3, E6, E7, E8, or E11.

When a Jira comment heading references workflow phases, use the exact phase label defined here. Do not invent synthetic phase ranges. The only routine combined phase heading allowed is `E4/E5` because one comment serves both phases.

**Comment formatting:** Pass clean GitHub-flavored markdown to `jira_add_comment`. Never backslash-escape markdown characters — bold is literal `**text**`, never `\*\*text\*\*`. Ensure every bold span has matching `**` delimiters on both sides.

**Comment reviewer gate:** Every `jira_add_comment` call in this workflow (E4/E5, E9, E10) is gated by an `**Independent comment review:**` block, following the same pattern as `plan-reviewer` and `implementation-reviewer`. The `comment-reviewer` sub-agent must return APPROVED (or the 3-iteration cap must be reached) before `jira_add_comment` is called. There are no exceptions.

**TASK TRACKING:** Always use task tracking (`TaskCreate`/`TaskUpdate`) so progress is visible throughout. Create one task per phase at the start of the workflow. Mark each task `in_progress` when starting the phase and `completed` when the phase is done:

- E0 — Transition Epic to In Progress
- E1 — Understand the Epic
- E2 — Review the Codebase
- E3 — Ask Clarifying Questions
- E4 — Create Breakdown Plan
- E5 — Await Breakdown Plan Approval
- E6 — Create Child Tasks in Jira
- E7 — Verify Epic Integration Branch
- E8 — Execute [JIRA-KEY]: [task title] (one task per child, created in E6 with status `pending`)
- E9 — User Testing
- E10 — Epic Summary
- E11 — Cleanup

**CHECKPOINT & COMPACTION CONTRACT:** This workflow records position in a single `$MEM/checkpoint.md` file (full schema and contract in `file-memory-protocol.md` §4) — critical for long-running epics with many child tasks.

**Per-phase checkpoint — after EVERY phase (E0–E10), automatically, with no chat output and no `/compact` prompt.** Run `git branch --show-current` and `git log --oneline -1` (separate Bash calls), then **atomically overwrite** `$MEM/checkpoint.md` (`Write` to `checkpoint.md.tmp`, then `mv` over `checkpoint.md`) with `checkpoint_type: phase`, the just-completed `phase`, the upcoming `next_phase`, the `references` list (typically `[plan.md, children.md, work-item.md]`), `## Decisions`, and `## Open items`. During E8, also set `child_completed` and `next_child`.

**Compaction gates (E3, E5, E8 per-child, E10) — additionally prompt the user to `/compact`.** Do the per-phase write but with `checkpoint_type: gate`, then: (1) wait for any background `area-mapper` to finish; (2) emit the Phase Summary block (§4(b)) — phase + skill, epic key, integration branch @ head_sha, child completion status (E8), one-line decisions, verbatim approval condition, `next_phase`, the checkpoint file path, and the resume contract; (3) end the turn with the literal line **"Run `/compact` now, then type `continue` to resume."** Do NOT call `AskUserQuestion` at a gate. **Exception:** the E8 per-child gate uses its own merged pause defined in that step — follow those instructions instead of this paragraph.

**Universal resume rule — on ANY resume, before doing anything else:** `Read $MEM/checkpoint.md` → `Read` every file in its `references` (including `children.md`) → verify git against the recorded values → **re-read the `next_phase` section of this `workflow.md`** (any phase asking clarifying/structured questions MUST use `AskUserQuestion`) → continue at `next_phase`. Mid-E8, also enter the in-progress child's `<CHILD-KEY>/` dir and read its `checkpoint.md` to resume that child's T-phase. If `$MEM` is absent, reconstruct from Jira. Approval gates stay chat-scoped — never assume a pending approval was granted.

---

### E0 — Transition Epic to In Progress

**This phase requires TWO separate tool calls. Do not move to E1 until both are complete.**

1. **Tool call 1:** Call `jira_get_transitions` with this issue's key. From the response, find the transition whose target status is **In Progress** and note its **ID**.
2. **Tool call 2:** Call `jira_transition_issue` with this issue's key and that transition ID. This is the call that actually moves the issue. Retrieving transitions alone does nothing -- you MUST call `jira_transition_issue` to complete this phase.

Do not guess transition IDs. Always retrieve them first via tool call 1.

### E1 — Understand the Epic

- Retrieve the Jira issue using the provided key. Read its full description.
- Read the **Task Details** section of the Jira issue description thoroughly. (For epics, this section contains the epic's goals and scope.)
- Identify the goals, acceptance criteria (Acceptance Criteria section), scope boundaries (Scope section), and constraints.
- Note all items in the **Affected Areas** section and any dependencies listed.
- Understand what "done" looks like for this epic as a whole.

**Inventory existing child tasks.** Call `jira_search` with JQL `parent = "<EPIC-KEY>"`. If that returns no results, also try `"Epic Link" = <EPIC-KEY>` (legacy epic-link field used by some Jira projects). For each child found:
- Call `jira_get_issue` to read the child's full description.
- Capture: `key`, `summary`, `status`, AC items present in the description, Affected Areas items present in the description, whether the `Epic Integration Branch` field appears in the description's Task Details section, and whether the child's stated scope looks in-scope for this epic's goals.
- Bootstrap the epic's file memory if not already done: compute `MEM` (recipe in `file-memory-protocol.md` §1), `mkdir -p "$MEM/explorations"`, and `Write $MEM/work-item.md` (`work_type: epic`) if absent. Record each existing child in `$MEM/children.md` (schema §3.8) as an entry with `key`, `title`, `status` (from Jira), `existing: true`, `integration_branch_present: true/false`, and notes on which AC / Affected Areas it covers.

If zero children are found, leave `children.md` uncreated for now (E4 will create it) and proceed. The rest of the workflow runs unchanged from the blank-slate path.

If one or more children are found, `children.md` now lists them. The E3, E4, E6, E8, E9, and E10 phases have branching behavior for this case, described in each respective phase.

### E2 — Review the Codebase

> **BOOTSTRAP FILE MEMORY:** Ensure `$MEM` exists (`mkdir -p "$MEM/explorations"`). If `$MEM/work-item.md` does not exist, `Write` it (schema §3.1) with `work_type: epic`, `jira_key`, `title`, `status: in_progress`, `phase: E2`, `skill: epic-card`, and the epic's goals/scope under `## Description`. Pass the absolute `MEM` path (as `memory_dir`) and a normalized `area_slug` to every explorer — each writes its own `$MEM/explorations/<area_slug>.md`.

- Identify all distinct areas of the codebase to explore based on the **Affected Areas** section and the epic goals.
- For each distinct area (service, module, or component), invoke a `codebase-explorer` sub-agent in **parallel**, providing:
    - The target area to explore
    - The question: "What patterns, abstractions, and utilities are in use here, and what architectural considerations affect how this epic's goals can be implemented in this area?"
    - The `memory_dir` (`$MEM`) and a normalized `area_slug`. The explorer writes its findings to `$MEM/explorations/<area_slug>.md`.
    - The epic description for context
- Wait for all explorers to return. Each non-failed return contains a `File:` line with the exploration file name. `INCOMPLETE` means partial findings are present; consider re-spawning for the same area if coverage matters. `FAILED` means no file was written — re-spawn that explorer before proceeding.
- **Post-exploration enrichment:** Spawn the `area-mapper` sub-agent **in the background** (`run_in_background: true`) with the same `memory_dir` (`$MEM`). It crystallizes durable area knowledge from this run's exploration files into Serena project memory for future explorations. Do not wait for it.
- `Read` each `$MEM/explorations/<area_slug>.md` from the returns. If any file is missing or empty, re-spawn that explorer rather than treating missing data as confirmed. Surface any `open_questions` entries. If any identifies a connection to another area not already explored, dispatch a follow-up `codebase-explorer` (passing the same `memory_dir`) before proceeding.

> **USE SEQUENTIAL THINKING:** Before synthesizing the explorer findings, invoke the `sequentialthinking` tool. Use it to integrate the evidence across all explorer reports, identify the patterns and abstractions that the epic's tasks must respect or extend, surface cross-area coupling that would constrain the breakdown plan in E4, and note any technical debt or risks that should be assigned to specific tasks rather than left implicit. The E4 breakdown is only as strong as the synthesis feeding it — missing cross-area constraints at this step causes task ordering and independence errors downstream. Do not proceed to the synthesis bullets until the reasoning is complete.

- Synthesize the findings from the exploration files. Read across all `$MEM/explorations/*.md` and aggregate:
    - **Patterns, abstractions, and utilities in use** — from each file's `patterns` array; cite `evidence_files` when present.
    - **Technical debt, risks, or architectural considerations** — from `risks` (ordered by severity), plus `integration_points` flagging cross-area coupling relevant to the breakdown.
    - **How the existing code relates to the goals of this epic** — from `evidence` entries and aggregated `affected_files`.

### E3 — Ask Clarifying Questions

**Objective:** Resolve any ambiguities, gaps, or risks about the epic's scope or goals before planning the breakdown.

**Agent Actions:**

1. Review all output from E0, E1, and E2.
2. Identify clarifying questions. Mark each as `[BLOCKING]` or `[NICE TO HAVE]`.
3. Ask each question one at a time using `AskUserQuestion`. Include the `[BLOCKING]` or `[NICE TO HAVE]` tag in the question text. For open-ended questions, offer `Provide answer` / `Skip — non-blocking` (non-blocking only) and rely on the auto-injected "Other" for the typed answer. If there are no clarifying questions, state this in the chat and proceed.
4. Record all answers verbatim. Do not infer or invent answers.
5. **If existing children were found in E1:** For each child that was flagged as potentially out-of-scope, ask the user how to handle it using `AskUserQuestion` with header `Child Disposition`, question `How should [JIRA-KEY] — "[child summary]" be handled?`, options: `Keep and execute as part of this epic` (description: "Include it in the E8 execution sequence") / `Keep but skip execution` (description: "Leave the issue in Jira but do not execute it in E8") / `Exclude from coverage analysis` (description: "Treat it as unrelated to this epic's scope — it stays in Jira but is not factored into coverage or execution"). Record the disposition on each existing child's entry in `$MEM/children.md` (a `disposition` field).

> **REQUIRED:** All BLOCKING questions answered and answers recorded. Remaining unanswered questions listed as open items.

> **APPROVAL GATE — FULL STOP.** Use `AskUserQuestion` with header `E3 Approval`, options: `Approve and proceed (Recommended)` (description: "All blocking answers are accurate and recorded") / `Request changes` (description: "Something needs correction before continuing"). Do not proceed to E4 until approved.

> **COMPACTION GATE — E3:** Once E3 approval is confirmed, follow the Checkpoint & Compaction Contract above (gate path). Write `checkpoint.md` with `phase: E3`, `next_phase: E4`, `checkpoint_type: gate`, `references: [work-item.md, explorations/*.md, children.md]`; `## Decisions`: clarifying answers and child-disposition decisions; branch/head_sha: "none"/"n/a". Emit the Phase Summary block and instruct the user to run `/compact` before proceeding to E4.

### E4 — Create Breakdown Plan

> **FULL CONTEXT LOAD:** Before producing the breakdown, `Glob $MEM` and `Read` every present input file — `work-item.md`, every `explorations/*.md`, `children.md` (existing children), and `clarifications.md`/`related-cards.md` if present (per `file-memory-protocol.md` §5). Build the breakdown on the full context, never a partial read.

> **USE SEQUENTIAL THINKING:** Before producing the breakdown, invoke the `sequentialthinking` tool. Use it to draft the task list, check each task for independence (can it be completed without leaving the codebase unstable?), trace the dependency chain between tasks, identify any gaps in coverage against the epic's acceptance criteria, and verify the execution order is correct. If existing children are present, map them against the epic's AC first before identifying gaps. Revise iteratively before committing. Do not post the breakdown until the reasoning is complete.

> **THINK HARD:** Before finalizing the breakdown, think hard about whether any task completion would leave the codebase in an unstable or inconsistent state that blocks the next task. Dependency-chain errors and false independence assumptions are the most common source of mid-epic blockers — they are far cheaper to catch here than at E8.

> **SELF-INTERROGATION — REQUIRED before finalizing the breakdown.** Answer these two questions explicitly, and route each answer into an artifact:
>
> 1. **What am I least confident about in this breakdown right now?** Name the specific soft spot — a child boundary that may not be truly independent, an ordering that rests on an unverified dependency, a Covered classification based only on the child's description. Route: record each item in the breakdown's rationale/open items so it is visible at E5, and where a user answer would resolve it, ask via `AskUserQuestion` before posting.
> 2. **What could go wrong mid-epic if this breakdown is executed as drafted?** Reason about the failure scenarios: a child leaving shared code half-migrated, two children silently touching the same interface, a `To Do` existing child never completing. Route: fold each concrete scenario into the affected children's Risks/Dependencies entries in the per-child plan detail.
>
> "Nothing" is almost never the true answer to either question. If it genuinely is, state why in one line.

> **WRITE plan.md + children.md:** After the breakdown is finalized, persist it to two files. `Write $MEM/plan.md` (schema §3.3, `plan_type: plan`) with `## Plan` (the full breakdown narrative — task list, execution order, rationale, and the coverage analysis) and `## Flowchart` (the dependency Mermaid from the flowgraph step). `Write $MEM/children.md` (schema §3.8) with one entry per child (existing + new), each carrying: `key` (or `null` until created in E6), `title`, `order` (execution sequence number), `depends_on` (list of prerequisite child keys/orders), `status` (`pending`; `done`/`skipped` for already-closed or skip-disposition existing children), `branch: null`, and — for existing children — `existing: true` plus their `disposition` and `coverage_status` (`covered` / `partial` / `gap_filled_by_<new-task-title>`). Each new gap-filler entry also carries a `plan` sub-object with the per-child token-fill detail: `ac_format` (`gherkin`|`outcome_based`), `acceptance_criteria_draft` (the full draft AC text, verbatim — this fills `{{TASK-ACCEPTANCE-CRITERION}}` in E6 and must not be summarized or truncated), `affected_areas`, `patterns_summary` (names + canonical `path:line` references of the 1–3 patterns assigned from E2 findings, or "none"), `nfr_notes`, `data_interface_notes`, `observability_notes`, and `dependencies_summary`. `children.md` is the authoritative execution-state map for the entire epic — E6, E8, E9, and E11 all read from and write back to it. The per-child `plan` detail is the persistence surface for E6 token-filling: if context is compacted between E5 and E6, E6 reads it rather than re-deriving the assignments from chat.

**If existing children were found in E1 (existing_children > 0):** Produce the breakdown in three parts:

**Part 1 — Coverage matrix.** For each AC item and each Affected Area in the epic, identify which existing children address it (and their current Jira status). Classify each existing child as one of:
- **Covered** — the child's description addresses the AC and Affected Areas it claims, and its `Epic Integration Branch` field is present (or not yet needed).
- **Partial** — the child addresses the AC but its description is missing required fields (e.g. no `Epic Integration Branch` in Task Details, missing Affected Areas section). Record the specific additive edits needed.
- **Out-of-scope** — the child's disposition was set to `Exclude from coverage analysis` in E3; exclude from the coverage matrix entirely.

**Part 2 — Backfill list.** For each child marked Partial, list the exact additive edits that E6 will perform: which fields will be inserted, what the inserted text will look like, and which section they go into. Never plan a full description rewrite — only additive insertions.

**Part 3 — New tasks (gaps).** For every AC item or Affected Area not addressed by any `Covered` or `Partial` child (accounting for E6's planned backfills), decompose into new gap-filler tasks following the standard rules below. Also add new tasks for any AC that existing children only partially satisfy after backfilling.

**If no existing children were found (existing_children = 0):** Decompose the epic into individual tasks directly. Each task must be:

- **Independent:** Completable on its own without leaving the codebase in an unstable state.
- **Ordered:** Sequenced so that dependencies between tasks are respected.
- **Small and focused:** One logical unit of work per task.
- **Testable:** Clear acceptance criteria that can be verified independently.

These same rules apply to new gap-filler tasks in the existing-children path.

> **GENERATE A FLOWGRAPH (best-effort):** Produce a Mermaid `flowchart` showing the child task dependency graph — nodes are child tasks (labelled with their title and execution order number), directed edges represent `depends_on` relationships, and the layout runs left-to-right in execution order. Existing children that will be skipped should be shown with a distinct style (e.g. dashed border). This diagram makes the sequencing reviewable at a glance.
>
> - **Skip it** for epics with a single task or where all tasks are truly independent (no edges). If skipped, state in one line why.
> - **Render it in the chat** as part of the breakdown plan presentation at E5.
> - **Embed it in the Jira description under `## Architecture`** as a ` ```mermaid ` fenced block, immediately after `## Affected Areas`. If the description lacks an `## Architecture` section, add one using `jira_update_issue` (additive edit — update only that section). (Jira Cloud does not render Mermaid natively; it will display as a code block, which is acceptable.) If skipped, set the Architecture section to "None — no diagram for this change."
> - **Persist it** to `plan.md`'s `## Flowchart` section (and optionally `work-item.md`'s `## Architecture`) so E8 and downstream phases can read it.

**REQUIRED:** The breakdown must include ALL of the following:

- (If existing children) Inventory table: each existing child with status, disposition, and coverage classification.
- (If existing children) Backfill list: each Partial child with the exact additive edits planned for E6.
- Task title and summary for each new task
- Execution order across both existing children and new tasks, with rationale
- Dependencies between tasks (including any new task that depends on a `To Do` existing child)
- How the combined set of existing children and new tasks collectively satisfies the epic's acceptance criteria
- **Per child:** its work type and therefore its AC format (Gherkin for feature/behavioral children, outcome-based for maintenance children), plus the relevant **patterns & code references** (from the E2 `pattern`/`evidence`/`integration_point` findings — `path:line` anchors), and any **non-functional**, **data & interface**, or **observability** notes that apply to that child. These feed the E6 token fills; mark "N/A" where a child has none.

**REQUIRED: Review the breakdown plan before posting.** Verify:

- Does every epic AC appear in the coverage matrix as either covered, partial-with-backfill, or gap-filler-assigned?
- Are the backfill edits additive only — no wholesale rewrites?
- Does the execution order respect the status of existing children (skip `Done`, wait on `To Do`)?
- Is every item in the Affected Areas section accounted for across existing children plus new tasks?
- Is each new task truly independent and completable without leaving the codebase unstable?
- Is each new task small and focused on a single logical unit of work?
- Are the acceptance criteria for each new task specific and testable?
- Is the plan consistent with the codebase patterns observed in E2?

If the review reveals issues, revise the plan before posting. Do not post an unreviewed plan.

**Independent plan review:**

Once the self-review is clean, invoke the `plan-reviewer` sub-agent, providing:

- The breakdown plan (full text)
- The epic's acceptance criteria
- The affected areas from the Epic Details
- The existing-children inventory with dispositions (Covered/Partial/Out-of-scope)
- The E2 codebase findings (patterns, conventions, and architectural context)
- The epic's Jira key and work type **Epic**

The sub-agent will return a structured findings report with an overall verdict of either **APPROVED** or **CHANGES REQUIRED**.

- If **APPROVED**: proceed to post the E4/E5 comment below.
- If **CHANGES REQUIRED**: address every Critical and Major finding, revise the breakdown plan, then invoke `plan-reviewer` again. Repeat until the verdict is APPROVED.
- **Max 3 review iterations.** If `plan-reviewer` returns CHANGES REQUIRED after 3 iterations, proceed to post the E4/E5 comment with the outstanding findings noted inline so the user can decide at E5.

Draft a single combined Jira comment with the exact heading `**E4/E5 — Breakdown Plan & Approval Request**` for the comment review below. This comment must include:

- (If existing children) Inventory table of existing children with status, disposition, and coverage classification.
- (If existing children) Backfill list detailing additive edits planned for Partial children.
- New task list (breakdown plan) for gap-filler tasks, with execution order, dependencies, and rationale. If there are no gaps, state explicitly: "All AC is addressed by existing child tasks. No new tasks will be created."
- Execution order across the full set (existing + new), including where `Done` children are skipped.
- How the combined set satisfies the epic's acceptance criteria.
- Architecture diagram (under `### Architecture` — the Mermaid dependency graph, or a note if skipped)
- `Approval requested: Please approve this breakdown plan before work begins.`

**Independent comment review:**

Once the comment body is drafted, invoke the `comment-reviewer` sub-agent, providing:

- The drafted comment body verbatim, exactly as it will be passed to `jira_add_comment`
- The phase label `E4/E5 — Breakdown Plan & Approval Request`
- The epic's acceptance criteria and breakdown plan
- The Jira issue key

The sub-agent will return a structured report with an overall verdict of either **APPROVED** or **CHANGES REQUIRED**.

- If **APPROVED**: call `jira_add_comment` with the reviewed body, then proceed to E5.
- If **CHANGES REQUIRED**: address every Critical and Major finding, revise the draft, then invoke `comment-reviewer` again with the updated body. Repeat until the verdict is APPROVED.
- **Max 3 review iterations.** If `comment-reviewer` returns CHANGES REQUIRED after 3 iterations, post the comment as-is with the remaining minor findings noted inline at the bottom of the comment body, and continue to E5.

Do not call `jira_add_comment` until `comment-reviewer` returns APPROVED (or the 3-iteration cap is reached). A passing plan-reviewer verdict, a clean self-check, or memory of having run `comment-reviewer` earlier in the workflow does not substitute.

### E5 — Await Breakdown Plan Approval

---

**APPROVAL GATE -- FULL STOP.**

- The approval request Jira record is the combined `E4/E5` comment already posted in E4. Do not post a second Jira comment here unless the plan changed.
- **Present the full breakdown plan in the chat output.** The user should not have to open Jira to review it — display it here before asking for approval.
- **BLIND-SPOT CALLOUT (conditional):** After presenting the breakdown and before asking for approval, answer this question for the user: *"What is the biggest thing the user may be missing about this epic's decomposition — what don't they realize?"* Render the answer as a short **What you might be missing** block containing at most two specific, evidence-backed items drawn from the E2 exploration findings (`risks`, `integration_points`), the coverage matrix, or the self-interrogation answers — cite the source for each. Typical candidates: an existing child whose Covered status rests on a thin description, a dependency chain that makes the epic effectively serial, an affected area whose coverage is spread across children in a way that risks integration gaps. If nothing qualifies, write exactly one line — "Nothing notable — the breakdown surfaces the known risks." — and never invent a generic risk to fill the section.
- Then use `AskUserQuestion` with header `E5 Approval`, options: `Approve and proceed (Recommended)` (description: "Breakdown plan is accurate — begin child task creation") / `Request changes` (description: "Revise the plan before proceeding"). Do not poll Jira for approval.
- If the user selects "Request changes", revise the plan, repost the full combined `E4/E5` comment to Jira, and use `AskUserQuestion` again.
- Only proceed to E6 after "Approve and proceed" is selected.

> **REGENERATE DASHBOARD:** After approval, regenerate `$MEM/work-item.html` from the current memory files (per `file-memory-protocol.md` §8) so the user has an up-to-date rendered view of the approved breakdown and dependency flowchart.
>
> **COMPACTION GATE — E5:** Once E5 approval is confirmed, follow the Checkpoint & Compaction Contract above (gate path). Write `checkpoint.md` with `phase: E5`, `next_phase: E6`, `checkpoint_type: gate`, `references: [plan.md, children.md, work-item.md]`; `## Decisions`: approved breakdown plan (task count, execution-order summary); `approval_condition`: verbatim user selection; branch/head_sha: "none"/"n/a". Emit the Phase Summary block and instruct the user to run `/compact` before proceeding to E6.

---

### E6 — Create Child Tasks in Jira

**IMPORTANT:** Each task must be created as a **Child Work Item** of this epic (parent-child relationship). Do NOT create tasks as Linked Work Items. The parent field of each new task must be set to this epic's issue key.

**DO NOT call `jira_create_issue_link` at any point during this phase. Setting the `parent` field in `additional_fields` is the ONLY action needed to establish the parent-child relationship. Any call to `jira_create_issue_link` creates a separate lateral "Related" link that should not exist. Per child task, use one `jira_create_issue` call to create the task with its final description and the parent field already set. No lateral linking calls or follow-up description update calls are allowed.**

**Step 0 — Backfill existing children (only when existing_children > 0).** Before creating any new tasks, perform the backfill edits recorded in E4 for each existing child marked Partial. For each such child:
1. Derive the epic integration branch name using the E7 naming convention: `{PROJECTKEY}-{ISSUENUMBER}-{epic-summary-in-kebab-case}`. This value is needed even before E7 runs so that backfilled children have the correct field set.
2. Call `jira_update_issue` with the additive edits only — insert the missing fields into the existing description without disturbing other content. The most critical edit is adding `**Epic Integration Branch:** <branch-name>` to the `Task Details` section so that `task-card` detects epic child-task mode during E8. If the child is also missing structural sections (e.g. Affected Areas, Scope), insert those sections after the existing `Task Details` block.
3. Update that child's entry in `$MEM/children.md`: set `backfilled: true` and `integration_branch_present: true`.

For each task identified in E4 (new gap-filler tasks only):

1. Derive the epic integration branch name now using the E7 naming convention: `{PROJECTKEY}-{ISSUENUMBER}-{epic-summary-in-kebab-case}` (e.g. `PROJ-900-user-authentication-overhaul`). This value is written into each child task's `Epic Integration Branch` field so T6 can detect epic child-task mode.
2. > **READ children.md:** Read this child's entry in `$MEM/children.md` and its `plan` sub-object (`ac_format`, `acceptance_criteria_draft`, `affected_areas`, `patterns_summary`, `nfr_notes`, `data_interface_notes`, `observability_notes`). Use these as the authoritative source for token-filling below — do not rely on chat context, which may have been lost to compaction between E5 and E6.
3. Populate the task description using the **Standard Task Template** below. Preserve the section structure exactly, but replace every `{{...}}` token with task-specific content before creating the issue. No unresolved placeholder text may be stored in Jira. Specifically:
   - **Acceptance Criteria:** use the `ac_format` field from the child's `plan` sub-object. For `gherkin` children this MUST be the canonical fenced ```gherkin block (`Feature:` + `Scenario:` per behavior; every criterion a Scenario; no plain outcome bullets) — copy the `acceptance_criteria_draft` field verbatim. Maintenance children (`outcome_based`) use outcome-based bullets.
   - **Patterns & Code References:** fill from the `patterns_summary` field. For the 1–3 most important patterns, use `Read` to extract a ≤ ~15-line snippet from the referenced `path:line_range`, prefixed with a `// path:line_range` comment. Write "None — no established pattern to follow." if the field is "none".
   - **Non-Functional Requirements / Data & Interface Changes / Observability & Telemetry:** fill from the `nfr_notes`, `data_interface_notes`, and `observability_notes` fields respectively, or the explicit "None …"/"N/A" line when the field is "none".
3. **Recommend a priority** for the child task based on its risk level, dependency position, and impact on the epic's acceptance criteria. Use `AskUserQuestion` with header `Task Priority` to confirm before creating the issue. Put the recommended priority first with `(Recommended)` appended. Options: one of `Critical (Recommended)` / `High (Recommended)` / `Medium (Recommended)` / `Low (Recommended)` as the first option (only the recommended one gets the label), then the remaining three priorities as subsequent options.
4. Create a new task by calling `jira_create_issue` with `project_key` set to this epic's own project (derived from the epic's issue key — child work items always live in their parent's project; do not ask the user and do not guess a different project) and `additional_fields` set to `{"parent": "EPIC-KEY", "priority": {"name": "High"}}` (substituting this epic's actual issue key and the confirmed priority name) and the assembled task description. This create call establishes the child work item relationship.

> **UPDATE children.md:** After each child task is created in Jira, update its entry in `$MEM/children.md`: set `key` to the new Jira key (e.g. `PROJ-124`) so E8 can reference it directly without searching Jira. If the breakdown changes during creation (e.g. a task is split), update `children.md` to reflect the current state before proceeding.

> **TASK TRACKING:** After each new child task is created in Jira, create a tracking task named `E8 — Execute [JIRA-KEY]: [task title]` (substituting the real key and title) with status `pending`. Also create tracking tasks for any existing children that will be executed in E8 (i.e. those whose disposition is not `Keep but skip execution` and whose current Jira status is not already closed). These tasks represent the E8 execution slots for each child and will be progressed in E8.

---

## Standard Task Template

**Use the section structure below for every child task. Replace every `{{...}}` token with task-specific content before posting the description. No unresolved placeholder text may remain in Jira.**

---

### STANDARD TASK TEMPLATE -- START

## Task Details

**All fields in this section are REQUIRED.**

**Summary:** {{TASK-SUMMARY}}

**Epic Integration Branch:** {{EPIC-INTEGRATION-BRANCH}}

## Overview
{{TASK-OVERVIEW}}

## Context
Parent epic: {{EPIC-KEY}} — {{EPIC-SUMMARY}}

{{TASK-CONTEXT}}

## Acceptance Criteria

[Format per the child's work type, decided in E4. For **feature/behavioral** children, AC
MUST be Gherkin: a single fenced ```gherkin code block headed by `Feature:` with one
`Scenario:` per behavior (Given/When/Then/And); every criterion is a Scenario — no plain
outcome bullets. For **maintenance** children, use outcome-based bullets instead.
Gherkin example shape:
  Feature: <capability>
    Scenario: <behavior>
      Given <precondition>
      When <action>
      Then <expected outcome>
      And <additional expectation>]
{{TASK-ACCEPTANCE-CRITERION}}

## Affected Areas

- `{{AFFECTED-PATH}}` -- {{AFFECTED-AREA-DESCRIPTION}} ({{RISK-LEVEL}} risk)

## Patterns & Code References
{{PATTERNS-AND-CODE-REFERENCES-OR-NONE}}

## Non-Functional Requirements
{{NON-FUNCTIONAL-REQUIREMENTS-OR-NA}}

## Data & Interface Changes
{{DATA-AND-INTERFACE-CHANGES-OR-NONE}}

## Observability & Telemetry
{{OBSERVABILITY-AND-TELEMETRY-OR-NONE}}

## Dependencies

**Hard:** {{HARD-DEPENDENCIES-OR-NONE}}
**Soft:** {{SOFT-DEPENDENCIES-OR-NONE}}

## Scope
**In Scope:**
- {{IN-SCOPE-ITEM}}

**Out of Scope:**
- {{OUT-OF-SCOPE-ITEM-OR-NONE}}

## Risks
{{TASK-SPECIFIC-RISKS-OR-N/A-MANAGED-IN-PARENT-EPIC}}

## Open Items
{{OPEN-ITEMS-OR-NONE}}

### STANDARD TASK TEMPLATE -- END

---

### E7 — Verify Epic Integration Branch

- Run `git branch --show-current` and report the current branch to the user.
- Use `AskUserQuestion` with header `Integration Branch`, options: `Confirm — this is the epic integration branch (Recommended)` (description: "Proceed with child task execution on this branch") / `Wrong branch — switching now` (description: "I need to switch to the correct integration branch before continuing"). If the user selects "Wrong branch", halt and wait for them to switch manually, then verify again.
- The expected integration branch naming convention is:

```
{PROJECTKEY}-{ISSUENUMBER}-{epic-summary-in-kebab-case}
```

Example: `PROJ-900-user-authentication-overhaul`

- This branch is the integration target for the entire epic. All child task branches will be created from and merged back into this branch.

> **RECORD INTEGRATION BRANCH:** Set `epic_integration_branch: <name>` in `$MEM/work-item.md` frontmatter. This lets E8 read the integration branch name from `work-item.md` rather than re-deriving it. (Each child's own working `branch` is recorded in its `children.md` entry when created in E8.)

### E8 — Execute Child Tasks

> **READ children.md:** Before starting each child task, read `$MEM/children.md` to confirm the correct execution order and that all prerequisite children have `status: done`. After each child completes, update its entry to `status: done` and add a `merged_at` timestamp. If context is lost mid-epic and `$MEM` is absent, rebuild `children.md` first from the epic description, the approved breakdown comment, the child task descriptions, and Jira child statuses before continuing — do not guess from memory.

> **USE DEPENDENCY DIAGRAM:** Read `$MEM/plan.md`'s `## Flowchart` (the dependency graph) as a sequencing reference when determining which children are unblocked and ready to execute. If a child's predecessors are not yet `status: done` in `children.md`, hold it regardless of Jira status. If no flowchart was persisted (skipped in E4), rely on the `depends_on` fields in `children.md` instead.

**Pre-step — classify each child before beginning execution.** Read all entries from `$MEM/children.md` in execution order. For each:
- If the entry has `disposition: Keep but skip execution`, set `status: skipped` in `children.md`, mark its tracking task `completed`, and move to the next without invoking `task-card`.
- If the entry has `existing: true` and its current Jira status is already closed (e.g. `Done`, `Closed`, `Resolved`), set `status: done` in `children.md`, mark its tracking task `completed`, and move to the next without invoking `task-card`. These children are counted as covered but are not re-executed.
- All remaining entries (new gap-filler tasks and existing children that are still open and not skipped) enter the execution loop below.

Work through each executable child task **in the order defined in E4**, executing the T0-T13 workflow inline for each one:

1. Read `$MEM/children.md` to confirm all prerequisite children for the next one have `status: done` or `status: skipped` (skipped predecessors do not block execution).
2. Mark the tracking task `E8 — Execute [JIRA-KEY]: [task title]` for this child as `in_progress`.
3. Retrieve the child task's full description from Jira and confirm that the `Task Details` section includes the expected **Epic Integration Branch** value from E7. For existing children, this field was backfilled in E6 Step 0; verify it is present before proceeding.
4. Invoke the `task-card` skill directly with the child task's Jira key (e.g., `/task-card PROJ-124`). The skill detects epic child-task mode from the `Epic Integration Branch` field in the task description and adjusts T6 (verify epic integration branch), T10 (skip user testing), and T11 (merge to integration branch after committing). T0 is performed by the skill itself.
5. Follow the full T0-T13 workflow for this child task. Pause at every approval gate and wait for explicit chat confirmation before proceeding. Jira comments should follow the reduced `task-card` comment contract (T4/T5, T12, and failure comments only) rather than phase-by-phase narration.
6. When the child task's T13 is complete, verify its status:
    - If successful: update the child's entry in `$MEM/children.md` to `status: done` (with `merged_at`). Mark the tracking task `E8 — Execute [JIRA-KEY]: [task title]` as `completed`. Invoke the `verification-runner` sub-agent with phase context `post-implementation` to confirm the integration branch passes the full build, all tests, and all linters. If it returns `FAILURES`, fix them and re-invoke before proceeding to the next task. (The child runs `task-card` in epic child mode, so its own `<CHILD-KEY>/` memory dir is NOT torn down at the child's T13 — E11 owns that.)
    - If failed: stop and report the failure to the user. Do not begin the next child task until the failure is resolved.
7. **Compaction gate and pause between tasks:** After the child completes successfully, write the epic's `$MEM/checkpoint.md` (gate path) with `phase: E8`, `next_phase: E8` (or `E9` if this was the final child), `checkpoint_type: gate`, `child_completed: <JIRA-KEY> (N of M)`, `next_child: <next-JIRA-KEY or "none — proceed to E9">`, `references: [plan.md, children.md, work-item.md]`; `## Decisions`: child completion summary. Emit the Phase Summary block (with the integration branch + child-completion anchors), then end your turn with the following prompt and nothing else: **"Run `/compact` now. After compacting, type `continue` to start the next task, or `stop` to pause the epic here."** Do not begin the next child task until the user types `continue`.
8. Do not begin the next child task until the current one is confirmed complete and the integration branch is clean.

### E9 — User Testing

---

**APPROVAL GATE — USER TESTING REQUIRED.**

- Draft a Jira comment with the exact heading `**E9 — User Testing Handoff**` as the verbatim first line — character-for-character, using `**bold**` (not a `##` markdown heading), and never a descriptive substitute such as "Epic complete" or "Ready for QA". The comment must include, in this exact order with these exact labels:
    
    - A summary of everything that was implemented across all child tasks (including which children were pre-existing and already done at workflow start)
    - **Acceptance Criteria & Testing Steps:** For each acceptance criterion from the Epic's Acceptance Criteria section (read in E1), a numbered section with:
        - The criterion restated clearly
        - Step-by-step end-to-end instructions to verify that criterion is met. Include AC covered by existing children that were already `Done` at workflow start — do not assume those AC were previously verified end-to-end. The user is testing the epic as a whole, after all new and edited work has landed on the integration branch.
    - **Not covered by automated checks:** The specific behaviors the automated builds and tests could not exercise — especially cross-child integration behaviors that no single child's test suite covers — which the user's end-to-end test is the only defense for. Draw these from the children's T12 summaries (test limitations, open items) and any integration risks recorded in `children.md` or the E4 breakdown — be specific (behavior + where to look), never generic. If nothing qualifies, state exactly: "None — automated coverage exercises all criteria."

**Independent comment review:**

Once the comment body is drafted, invoke the `comment-reviewer` sub-agent, providing:

- The drafted comment body verbatim, exactly as it will be passed to `jira_add_comment`
- The phase label `E9 — User Testing Handoff`
- The integration branch name and epic acceptance criteria
- The Jira issue key

The sub-agent will return a structured report with an overall verdict of either **APPROVED** or **CHANGES REQUIRED**.

- If **APPROVED**: call `jira_add_comment` with the reviewed body.
- If **CHANGES REQUIRED**: address every Critical and Major finding, revise the draft, then invoke `comment-reviewer` again with the updated body. Repeat until the verdict is APPROVED.
- **Max 3 review iterations.** If `comment-reviewer` returns CHANGES REQUIRED after 3 iterations, post the comment as-is with the remaining minor findings noted inline at the bottom of the comment body, and continue.

Do not call `jira_add_comment` until `comment-reviewer` returns APPROVED (or the 3-iteration cap is reached). A clean self-check or memory of having run `comment-reviewer` earlier in the workflow does not substitute.

- Present the same testing handoff in the chat — the user should not have to open Jira to see what to test.
- Then use `AskUserQuestion` with header `E9 Testing`, options: `Approve — everything works as expected (Recommended)` (description: "All acceptance criteria passed — proceed to the epic summary") / `Issues found` (description: "One or more problems were found during testing"). Do not proceed until the user selects an option.
    
- **If the user identifies issues, triage each distinct issue before acting on it.** First gather each issue's observed vs. expected behavior conversationally. Then classify each one and route it:

    - **(A) Minor in-scope defect** — a small cross-child integration defect, small enough to fix directly now. **Do NOT run issue-intake and do NOT create a card or child task.** Apply the fix directly on the integration branch, then invoke the `verification-runner` sub-agent with phase context `post-implementation` to confirm the integration branch passes the full build, all tests, and all linters. Return to this step before proceeding.

    - **(B) Deserves its own card** — an unrelated or pre-existing bug that surfaced during testing but was not caused by this epic's work, OR a genuine in-scope gap that is too large or severe to fix in place. Create its own card via the handoff below, then route on whether it blocks this epic:
        - **Blocking** (prevents an epic acceptance criterion from being met, or makes shipping the integrated work unsafe or incorrect): create a new child Task for the issue-intake card following E6 child-task creation rules (set the `parent` field to the epic key — do not call `jira_create_issue_link`), add an entry to `$MEM/children.md`, and invoke the `task-card` skill with the child task's Jira key (epic child-task mode is detected from the `Epic Integration Branch` field, so T10 is skipped automatically). After the follow-up task's T13 completes, update its `children.md` entry to `status: done`, record its merge completion, and return to this step. Do NOT proceed to E10 until all blocking follow-up tasks are done and the integration branch re-verified.
        - **Non-blocking** (the epic's own acceptance criteria still pass; the new card is independent follow-up work): leave the issue-intake card as an independent follow-up linked to the epic — do NOT create or execute a child task now. Record it in `$MEM/children.md` as a deferred follow-up and proceed to **E10**.

    - **When the classification is unclear** (A vs. B, or blocking vs. non-blocking), use `AskUserQuestion` to let the user decide. Do not guess.

    - **Own-card handoff — `issue-intake` is gated (`disable-model-invocation: true`), so you CANNOT invoke it via the `Skill` tool; that call will fail.** Instead: write the checkpoint (gate path) noting the pending handoff and its blocking status, then present each issue's pre-populated context and instruct the user to run `/issue-intake` themselves, giving them the exact ready-to-paste argument string: `Testing found: [observed behavior]. Expected: [expected behavior]. Related to: [PROJ-KEY]`. End your turn and wait. After the user's `/issue-intake` completes and its Jira card is created, resume from the checkpoint at this step and apply the blocking / non-blocking routing above.
    

---

### E10 — Epic Summary

**ALL fields below are REQUIRED. Do not skip any field. If a field does not apply, explicitly state "N/A" with a brief reason.**

After all child tasks are complete and user testing has passed, post a comment with the exact heading `**E10 — Summary of Changes**` as the verbatim first line of the comment body — character-for-character, using `**bold**` (not a `##` markdown heading), and never a descriptive substitute such as "Epic complete" or "Implementation summary".

Begin the comment body with `**Integration branch:** <branch-name>`, followed by a `----` horizontal rule.

Then render **every** field below as a bold-labeled section (`**Field name:**`), in this exact order, using these exact field names. Do not rename, merge, reorder, drop, or add fields.

- **Overview:** What was accomplished across all child tasks.
    
- **Child tasks completed:** Three subsections:
    - **Pre-existing children (executed in E8):** Key, title, status at workflow start, status at completion.
    - **Pre-existing children (skipped — already done or excluded):** Key, title, and reason (already `Done` at workflow start, or `Keep but skip execution` disposition).
    - **Newly created children:** Key, title, status at completion.
    - (If applicable) **Follow-up children created in E9:** Key, title, status.
    
- **Deviations from breakdown plan:** Any tasks that were added, removed, split, or significantly changed, with reasons. Include any backfill edits made to existing children in E6 (e.g. "Added missing Affected Areas section and Epic Integration Branch field to PROJ-201").
    
- **Cumulative release notes:** Consolidated, user-facing release note for the entire epic. If purely internal, state "N/A — internal changes only."

- **Open items:** Follow-up work, known limitations, tech debt introduced, or unresolved questions.
    

**REQUIRED: Review the summary before posting.** Confirm (1) the first line is exactly `**E10 — Summary of Changes**` in `**bold**` format, (2) the `**Integration branch:**` metadata is present before the `----` rule, and (3) every mandated field appears as a `**Label:**` section in the specified order with none renamed, dropped, or substituted, and that "Child tasks completed" lists every task. If any check fails, rewrite before posting.

**Independent comment review:**

Once the summary body is drafted, invoke the `comment-reviewer` sub-agent, providing:

- The drafted comment body verbatim, exactly as it will be passed to `jira_add_comment`
- The phase label `E10 — Summary of Changes`
- The integration branch name and child task list
- The Jira issue key

The sub-agent will return a structured report with an overall verdict of either **APPROVED** or **CHANGES REQUIRED**.

- If **APPROVED**: call `jira_add_comment` with the reviewed body.
- If **CHANGES REQUIRED**: address every Critical and Major finding, revise the draft, then invoke `comment-reviewer` again with the updated body. Repeat until the verdict is APPROVED.
- **Max 3 review iterations.** If `comment-reviewer` returns CHANGES REQUIRED after 3 iterations, post the comment as-is with the remaining minor findings noted inline at the bottom of the comment body, and continue.

Do not call `jira_add_comment` until `comment-reviewer` returns APPROVED (or the 3-iteration cap is reached). A clean self-check or memory of having run `comment-reviewer` earlier in the workflow does not substitute.

> **REGENERATE DASHBOARD:** After the E10 summary comment is posted, regenerate `$MEM/work-item.html` (per `file-memory-protocol.md` §8) so the user has a final rendered view. Optionally `Write $MEM/summary.md` (`summary_type: changes`) with the epic summary body first so the dashboard's Summary section is populated.
>
> **COMPACTION GATE — E10:** Once the E10 summary comment is posted, follow the Checkpoint & Compaction Contract above (gate path). Write `checkpoint.md` with `phase: E10`, `next_phase: E11`, `checkpoint_type: gate`, `references: [plan.md, children.md, work-item.md]`; `## Decisions`: epic completion confirmed, all children done; branch: integration branch name. Emit the Phase Summary block and instruct the user to run `/compact` before proceeding to E11.

### E11 — Cleanup

- Remove the epic's file-memory directory AND every child task's directory in atomic operations. Read `$MEM/children.md` for the child keys; for each child key run `rm -rf "$MEMROOT/<CHILD-KEY>"` (Bash, same `$MEMROOT` as `$MEM`), then finally `rm -rf "$MEM"` for the epic dir itself. Child `task-card` runs in epic child mode do NOT self-clean at their T13, so E11 owns wholesale teardown of the epic dir and every child dir. Each directory removal is atomic — nothing to enumerate node-by-node. Do not retain epic, task, dependency, or checkpoint state once the final Jira record is complete.

---

## Completion Criteria

This workflow is complete when **all** of the following are true:

- All phases executed in sequence (E0 through E11)
- All approval gates explicitly confirmed in the chat
- Breakdown plan reviewed and approved (E4/E5)
- All child task Jira issues created as child work items of the epic (E6–E8)
- All child tasks completed and verified
- User testing completed and approved (E9)
- All Jira comments posted by this workflow (E4/E5, E9, E10) were reviewed by `comment-reviewer` and returned APPROVED (or reached the 3-iteration cap) before `jira_add_comment` ran
- E10 summary comment posted using the exact `**E10 — Summary of Changes**` heading and the full mandated field set in order
- E9 handoff comment posted using the exact `**E9 — User Testing Handoff**` heading
- File-memory directories removed — epic dir + every child dir (E11)
