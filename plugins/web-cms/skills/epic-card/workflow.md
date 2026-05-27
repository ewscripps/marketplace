# EPIC CARD WORKFLOW — EXECUTION CONTRACT

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute epic phases in strict sequential order (E0 through E11).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure as a comment on this Jira issue. Do not continue.
5. Every required output (comments, plans, summaries) must be posted before the phase is considered complete.

**KNOWLEDGE GRAPH SCOPE:** The knowledge graph in this workflow is the authoritative execution state map for the entire epic. It tracks the epic node, all child task nodes (with Jira keys, execution order, and completion status), the integration branch, and dependencies. Existing children present at workflow start are also represented as `task` nodes, distinguished by an `existing: true` observation. If context is lost mid-epic (long session, reconnection, new session), read the graph first to reconstruct exact state. If the graph is empty in a new session, reconstruct state by reading this Jira epic's description and all comments, then querying each child task's status in Jira before continuing.

**APPROVAL GATE BEHAVIOR:** Approval gates are chat-scoped. If explicit approval is not captured before the session ends or context is lost, stop at the gate. On resume, re-present the latest breakdown plan or testing handoff and ask for confirmation again. Never assume a pending approval was granted.

**CLARIFICATION RULE:** Do not assume anything. If required information is missing, ambiguous, conflicting, or underspecified, stop and use `AskUserQuestion` to ask the user for clarification before proceeding.

**RESUMPTION CHECK:** If this workflow resumes after prior work has already been performed, inspect the epic status, the existing Jira comments, and current child task states first to identify the first incomplete phase. If the epic is already **In Progress**, do not repeat E0. If the knowledge graph is empty, rebuild the epic, task, dependency, and branch nodes from the latest approved breakdown, child task descriptions, and Jira task statuses before continuing.

**SERENA PROJECT ACTIVATION:** Before E0, check Serena's project-activation message (emitted on connect via `--project-from-cwd`); if it reports that onboarding has not been performed, call `onboarding` to scope Serena's language server to the current project directory. Serena's symbol tools (`find_symbol`, `find_referencing_symbols`, `get_symbols_overview`, `search_for_pattern`) and any symbol-aware operations invoked by the `codebase-explorer` agent depend on this being done. Do this once at the start of the workflow; do not repeat it between phases.

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

**PHASE COMPACTION HANDOFF CONTRACT:** At designated compaction gates in this workflow, the agent writes a durable `phase_handoff` entity to the knowledge graph and prompts the user to run `/compact`. This prevents auto-compaction from firing mid-phase and discarding phase position — particularly important for long-running epics with multiple child tasks.

**Steps at each gate — execute before instructing `/compact`:**

1. Wait for any background `area-mapper` sub-agent to complete.
2. Create a `phase_handoff` entity in the knowledge graph:
   - **Name:** `phase-handoff-<EPIC-KEY>-<phase-id>` (e.g. `phase-handoff-ELI-900-E5`); for per-child E8 gates use `phase-handoff-<EPIC-KEY>-E8-<child-JIRA-KEY>`.
   - **Observations:** `phase: <id>`, `skill: epic-card`, `jira_key: <epic-key>`, `branch: <integration-branch or "none">`, `head_sha: <sha or "n/a">`, one `decisions: <text>` observation per key decision, `approval_condition: <verbatim user phrasing or "none">`, `next_phase: <id>`, one `open_items: <text>` per open item. For E8 per-child gates only: `epic_key: <EPIC-KEY>`, `integration_branch: <name>`, `child_completed: <JIRA-KEY> (N of M)`, `next_child: <JIRA-KEY or "none — all complete">`.
   - **Relations:** `BELONGS_TO` → `work_item-<EPIC-KEY>`; `SUPERSEDES` → prior `phase_handoff` for this epic (if any); `REFERENCES` → relevant `exploration`, `epic`, `task`, `branch`, and `plan` entity names.
3. Call `open_nodes` on the new entity and each `REFERENCES` target to confirm writes landed.
4. Emit the Phase Summary block in the chat. The block must contain: phase ID and skill name, epic key + integration branch + head SHA anchors, child completion status (E8 gates), one-line decision summary, verbatim approval condition, next phase ID, handoff entity name, and resume contract ("open_nodes on handoff entity → traverse REFERENCES → `git status` → continue at `<next-phase>`"). End your turn immediately after the Phase Summary block — do not add any further content. The block must end with this literal line: **"Run `/compact` now, then type `continue` to resume."** Do NOT call `AskUserQuestion` here; the user must be free to run `/compact` in the prompt input without any open question consuming their input. When the user types `continue`, call `open_nodes` on the `phase_handoff` entity, traverse its `REFERENCES`, verify git state, and resume at `next_phase`. Before executing the resumed phase, **re-read that phase's section in this skill's `workflow.md`** so its full instructions survive compaction — in particular, any phase that asks the user clarifying or structured questions MUST use `AskUserQuestion` (per the Clarification Rule), never plain text. Exception: the E8 per-child gate uses its own merged pause defined in that step — follow those instructions instead of this paragraph.

**Cleanup:** Include all `phase_handoff` entities for this epic (prefix `phase-handoff-<EPIC-KEY>-`) in the E11 cleanup enumeration alongside other session-scoped entities.

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
- Write each existing child to the knowledge graph as a `task` node with observations: `existing: true`, `jira_key`, `status` (from Jira), any AC items it covers, any Affected Areas it covers, and `integration_branch_present: true/false`.

If zero children are found, add an observation `existing_children: 0` on the epic node and proceed. The rest of the workflow runs unchanged from the blank-slate path.

If one or more children are found, record `existing_children: N` on the epic node. The E3, E4, E6, E8, E9, and E10 phases have branching behavior for this case, described in each respective phase.

### E2 — Review the Codebase

> **USE KNOWLEDGE GRAPH:** Before spawning explorers, ensure a `work_item-<JIRA_KEY>` entity exists for this epic. Call `search_nodes` with the work item key (e.g. `work_item-ELI-900`); if no entity is returned, create it with observations: `work_type: epic`, `jira_key`, `title`, `summary`, `phase: review`. **Record the entity name** as the `work_item_id` for E2 and pass it to every explorer. The richer `epic` node referenced in E4 is created later for breakdown tracking; the `work_item` node here is the canonical root the explorers attach their findings to.

- Identify all distinct areas of the codebase to explore based on the **Affected Areas** section and the epic goals.
- For each distinct area (service, module, or component), invoke a `codebase-explorer` sub-agent in **parallel**, providing:
    - The target area to explore
    - The question: "What patterns, abstractions, and utilities are in use here, and what architectural considerations affect how this epic's goals can be implemented in this area?"
    - The `work_item_id` (`work_item-<JIRA_KEY>`). All findings the explorer streams to the graph will be linked to this node.
    - The epic description for context
- Wait for all explorers to return. Each non-failed return contains an `Entity:` line with the exploration entity name. `INCOMPLETE` means partial findings are present; consider re-spawning for the same area if coverage matters. `FAILED` means no graph data was written — re-spawn that explorer before proceeding.
- **Post-exploration enrichment:** Spawn the `area-mapper` sub-agent **in the background** (`run_in_background: true`) with the same `work_item_id`. It crystallizes durable area knowledge from this run's graph into Serena project memory for future explorations. Do not wait for it.
- Call `open_nodes` on each `exploration` entity name from the returns. If any entity comes back empty, re-spawn that explorer rather than treating missing data as confirmed. Surface any `open_question` entities in the responses. If any identifies a connection to another area not already explored, dispatch a follow-up `codebase-explorer` (passing the same `work_item_id`) before proceeding.

> **USE SEQUENTIAL THINKING:** Before synthesizing the explorer findings, invoke the `sequentialthinking` tool. Use it to integrate the evidence across all explorer reports, identify the patterns and abstractions that the epic's tasks must respect or extend, surface cross-area coupling that would constrain the breakdown plan in E4, and note any technical debt or risks that should be assigned to specific tasks rather than left implicit. The E4 breakdown is only as strong as the synthesis feeding it — missing cross-area constraints at this step causes task ordering and independence errors downstream. Do not proceed to the synthesis bullets until the reasoning is complete.

- Synthesize the findings from the graph. Read across all `exploration` entities linked to this `work_item_id` and aggregate:
    - **Patterns, abstractions, and utilities in use** — from `pattern` entities; cite the `evidence_files` observation when present.
    - **Technical debt, risks, or architectural considerations** — from `risk` entities, ordered by severity, plus any `integration_point` entities that flag cross-area coupling relevant to the breakdown.
    - **How the existing code relates to the goals of this epic** — from `evidence` entities and aggregated `affected_file` entities.

### E3 — Ask Clarifying Questions

**Objective:** Resolve any ambiguities, gaps, or risks about the epic's scope or goals before planning the breakdown.

**Agent Actions:**

1. Review all output from E0, E1, and E2.
2. Identify clarifying questions. Mark each as `[BLOCKING]` or `[NICE TO HAVE]`.
3. Ask each question one at a time using `AskUserQuestion`. Include the `[BLOCKING]` or `[NICE TO HAVE]` tag in the question text. For open-ended questions, offer `Provide answer` / `Skip — non-blocking` (non-blocking only) and rely on the auto-injected "Other" for the typed answer. If there are no clarifying questions, state this in the chat and proceed.
4. Record all answers verbatim. Do not infer or invent answers.
5. **If existing children were found in E1:** For each child that was flagged as potentially out-of-scope, ask the user how to handle it using `AskUserQuestion` with header `Child Disposition`, question `How should [JIRA-KEY] — "[child summary]" be handled?`, options: `Keep and execute as part of this epic` (description: "Include it in the E8 execution sequence") / `Keep but skip execution` (description: "Leave the issue in Jira but do not execute it in E8") / `Exclude from coverage analysis` (description: "Treat it as unrelated to this epic's scope — it stays in Jira but is not factored into coverage or execution"). Record the disposition on each existing child's graph node as a `disposition` observation.

> **REQUIRED:** All BLOCKING questions answered and answers recorded. Remaining unanswered questions listed as open items.

> **APPROVAL GATE — FULL STOP.** Use `AskUserQuestion` with header `E3 Approval`, options: `Approve and proceed (Recommended)` (description: "All blocking answers are accurate and recorded") / `Request changes` (description: "Something needs correction before continuing"). Do not proceed to E4 until approved.

> **COMPACTION GATE — E3:** Once E3 approval is confirmed, follow the Phase Compaction Handoff Contract above. Entity name: `phase-handoff-<EPIC-KEY>-E3`; `next_phase: E4`; decisions: clarifying answers and child-disposition decisions; branch + head SHA: "n/a" (not yet created). REFERENCES: exploration entities from E2 and existing child task nodes from E1. Emit the Phase Summary block and instruct the user to run `/compact` before proceeding to E4.

### E4 — Create Breakdown Plan

> **USE SEQUENTIAL THINKING:** Before producing the breakdown, invoke the `sequentialthinking` tool. Use it to draft the task list, check each task for independence (can it be completed without leaving the codebase unstable?), trace the dependency chain between tasks, identify any gaps in coverage against the epic's acceptance criteria, and verify the execution order is correct. If existing children are present, map them against the epic's AC first before identifying gaps. Revise iteratively before committing. Do not post the breakdown until the reasoning is complete.

> **THINK HARD:** Before finalizing the breakdown, think hard about whether any task completion would leave the codebase in an unstable or inconsistent state that blocks the next task. Dependency-chain errors and false independence assumptions are the most common source of mid-epic blockers — they are far cheaper to catch here than at E8.

> **USE KNOWLEDGE GRAPH:** After the breakdown is finalized, write the epic and all child tasks to the knowledge graph. Create an `epic` node with properties: `jira_key`, `summary`, `status: in_progress`. For existing children (already written as `task` nodes in E1), add a `coverage_status` observation: `covered` (AC fully addressed), `partial` (AC addressed but description is missing required fields), or `gap_filled_by_<new-task-title>` (AC partially addressed; a new task fills the remainder). For new gap-filler tasks, create a `task` node named `task-<EPIC-KEY>-<order>` with observations: `title`, `order` (execution sequence number), `status: pending`, `existing: false`, `ac_format` (`gherkin` for feature/behavioral children, `outcome_based` for maintenance), `acceptance_criteria_draft` (the full draft AC text for this child, verbatim — this is the token that fills `{{TASK-ACCEPTANCE-CRITERION}}` in E6 and must not be summarized or truncated), `affected_areas` (comma-separated list of affected paths for this child), `patterns_summary` (names and canonical `path:line` references of the 1–3 patterns assigned to this child from E2 findings, or "none"), `nfr_notes` (non-functional requirements for this child, or "none"), `data_interface_notes` (data/interface changes for this child, or "none"), `observability_notes` (observability notes for this child, or "none"), and `dependencies_summary` (depends_on task order numbers, or "none"). Link each node to the `epic` node. Write `depends_on` relationships between task nodes. This graph is the authoritative execution state map for the entire epic — E6, E7, E8, E10, and E11 all read from and write back to it. The per-child planning observations are the persistence surface for E6 token-filling: if context is compacted between E5 and E6, E6 reads them rather than re-deriving the per-child assignments from chat.

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
> - **Persist it to the knowledge graph:** add a `diagram` observation (the raw Mermaid source) to the `epic` entity so E8 and downstream phases can read it.

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

Post a single combined Jira comment with the exact heading `**E4/E5 — Breakdown Plan & Approval Request**` before proceeding. This comment must include:

- (If existing children) Inventory table of existing children with status, disposition, and coverage classification.
- (If existing children) Backfill list detailing additive edits planned for Partial children.
- New task list (breakdown plan) for gap-filler tasks, with execution order, dependencies, and rationale. If there are no gaps, state explicitly: "All AC is addressed by existing child tasks. No new tasks will be created."
- Execution order across the full set (existing + new), including where `Done` children are skipped.
- How the combined set satisfies the epic's acceptance criteria.
- Architecture diagram (under `### Architecture` — the Mermaid dependency graph, or a note if skipped)
- `Approval requested: Please approve this breakdown plan before work begins.`

### E5 — Await Breakdown Plan Approval

---

**APPROVAL GATE -- FULL STOP.**

- The approval request Jira record is the combined `E4/E5` comment already posted in E4. Do not post a second Jira comment here unless the plan changed.
- **Present the full breakdown plan in the chat output.** The user should not have to open Jira to review it — display it here before asking for approval.
- Then use `AskUserQuestion` with header `E5 Approval`, options: `Approve and proceed (Recommended)` (description: "Breakdown plan is accurate — begin child task creation") / `Request changes` (description: "Revise the plan before proceeding"). Do not poll Jira for approval.
- If the user selects "Request changes", revise the plan, repost the full combined `E4/E5` comment to Jira, and use `AskUserQuestion` again.
- Only proceed to E6 after "Approve and proceed" is selected.

> **COMPACTION GATE — E5:** Once E5 approval is confirmed, follow the Phase Compaction Handoff Contract above. Entity name: `phase-handoff-<EPIC-KEY>-E5`; `next_phase: E6`; decisions: approved breakdown plan (task count, execution order summary, epic and task node names for REFERENCES); branch + head SHA: "n/a" (not yet created). REFERENCES: epic node and all task nodes from E4. Emit the Phase Summary block and instruct the user to run `/compact` before proceeding to E6.

---

### E6 — Create Child Tasks in Jira

**IMPORTANT:** Each task must be created as a **Child Work Item** of this epic (parent-child relationship). Do NOT create tasks as Linked Work Items. The parent field of each new task must be set to this epic's issue key.

**DO NOT call `jira_create_issue_link` at any point during this phase. Setting the `parent` field in `additional_fields` is the ONLY action needed to establish the parent-child relationship. Any call to `jira_create_issue_link` creates a separate lateral "Related" link that should not exist. Per child task, use one `jira_create_issue` call to create the task with its final description and the parent field already set. No lateral linking calls or follow-up description update calls are allowed.**

**Step 0 — Backfill existing children (only when existing_children > 0).** Before creating any new tasks, perform the backfill edits recorded in E4 for each existing child marked Partial. For each such child:
1. Derive the epic integration branch name using the E7 naming convention: `{PROJECTKEY}-{ISSUENUMBER}-{epic-summary-in-kebab-case}`. This value is needed even before E7 runs so that backfilled children have the correct field set.
2. Call `jira_update_issue` with the additive edits only — insert the missing fields into the existing description without disturbing other content. The most critical edit is adding `**Epic Integration Branch:** <branch-name>` to the `Task Details` section so that `task-card` detects epic child-task mode during E8. If the child is also missing structural sections (e.g. Affected Areas, Scope), insert those sections after the existing `Task Details` block.
3. Update that child's graph node: add a `backfilled: true` observation and record `integration_branch_present: true`.

For each task identified in E4 (new gap-filler tasks only):

1. Derive the epic integration branch name now using the E7 naming convention: `{PROJECTKEY}-{ISSUENUMBER}-{epic-summary-in-kebab-case}` (e.g. `PROJ-900-user-authentication-overhaul`). This value is written into each child task's `Epic Integration Branch` field so T6 can detect epic child-task mode.
2. > **USE KNOWLEDGE GRAPH:** Call `open_nodes` on the `task-<EPIC-KEY>-<order>` entity for this child to read its per-child planning observations (`ac_format`, `acceptance_criteria_draft`, `affected_areas`, `patterns_summary`, `nfr_notes`, `data_interface_notes`, `observability_notes`). Use these observations as the authoritative source for token-filling below — do not rely on chat context, which may have been lost to compaction between E5 and E6.
3. Populate the task description using the **Standard Task Template** below. Preserve the section structure exactly, but replace every `{{...}}` token with task-specific content before creating the issue. No unresolved placeholder text may be stored in Jira. Specifically:
   - **Acceptance Criteria:** use the `ac_format` observation from the task node. For `gherkin` children this MUST be the canonical fenced ```gherkin block (`Feature:` + `Scenario:` per behavior; every criterion a Scenario; no plain outcome bullets) — copy the `acceptance_criteria_draft` observation verbatim. Maintenance children (`outcome_based`) use outcome-based bullets.
   - **Patterns & Code References:** fill from the `patterns_summary` observation. For the 1–3 most important patterns, use `Read` to extract a ≤ ~15-line snippet from the referenced `path:line_range`, prefixed with a `// path:line_range` comment. Write "None — no established pattern to follow." if the observation is "none".
   - **Non-Functional Requirements / Data & Interface Changes / Observability & Telemetry:** fill from the `nfr_notes`, `data_interface_notes`, and `observability_notes` observations respectively, or the explicit "None …"/"N/A" line when the observation is "none".
3. **Recommend a priority** for the child task based on its risk level, dependency position, and impact on the epic's acceptance criteria. Use `AskUserQuestion` with header `Task Priority` to confirm before creating the issue. Put the recommended priority first with `(Recommended)` appended. Options: one of `Critical (Recommended)` / `High (Recommended)` / `Medium (Recommended)` / `Low (Recommended)` as the first option (only the recommended one gets the label), then the remaining three priorities as subsequent options.
4. Create a new task by calling `jira_create_issue` with `additional_fields` set to `{"parent": "EPIC-KEY", "priority": {"name": "High"}}` (substituting this epic's actual issue key and the confirmed priority name) and the assembled task description. This create call establishes the child work item relationship.

> **USE KNOWLEDGE GRAPH:** After each child task is created in Jira, update its node in the knowledge graph. Add the `jira_key` property to the task node (e.g. `PROJ-124`) so E8 can reference it directly without searching Jira. If the breakdown plan changes during creation (e.g. a task is split), update the graph to reflect the current state before proceeding.

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

> **USE KNOWLEDGE GRAPH:** Write a `branch` node with properties: `name` (the integration branch name), `type: integration`, and link it to the epic node. This allows E8 to read the integration branch name from the graph rather than re-deriving it.

### E8 — Execute Child Tasks

> **USE KNOWLEDGE GRAPH:** Before starting each child task, read the task nodes from the graph to confirm the correct execution order and that all prerequisite tasks have `status: done`. After each child task completes, update its node to `status: done` and add a `merged_at` timestamp. If context is lost mid-epic (long session, reconnection) and the graph is empty, rebuild the graph first from the epic description, the approved breakdown comment, the child task descriptions, and Jira child task statuses before continuing — do not guess from memory.

> **USE DEPENDENCY DIAGRAM:** Call `open_nodes` on the `epic` entity and read the `diagram` observation. Use the dependency flowchart as a sequencing reference when determining which tasks are unblocked and ready to execute. If a task's predecessors are not yet `status: done`, hold that task regardless of Jira status. If no diagram was persisted (skipped in E4), rely on the `depends_on` graph relationships instead.

**Pre-step — classify each child before beginning execution.** Read all `task` nodes from the graph in execution order. For each node:
- If the node has `disposition: Keep but skip execution`, record `status: skipped` on the graph node, mark its tracking task `completed`, and move to the next task without invoking `task-card`.
- If the node has `existing: true` and its current Jira status is already closed (e.g. `Done`, `Closed`, `Resolved`), record `status: done` on the graph node, mark its tracking task `completed`, and move to the next task without invoking `task-card`. These children are counted as covered but are not re-executed.
- All remaining nodes (new gap-filler tasks and existing children that are still open and not skipped) enter the execution loop below.

Work through each executable child task **in the order defined in E4**, executing the T0-T13 workflow inline for each one:

1. Read the knowledge graph to confirm all prerequisite tasks for the next task have `status: done` or `status: skipped` (skipped predecessors do not block execution).
2. Mark the tracking task `E8 — Execute [JIRA-KEY]: [task title]` for this child as `in_progress`.
3. Retrieve the child task's full description from Jira and confirm that the `Task Details` section includes the expected **Epic Integration Branch** value from E7. For existing children, this field was backfilled in E6 Step 0; verify it is present before proceeding.
4. Invoke the `task-card` skill directly with the child task's Jira key (e.g., `/task-card PROJ-124`). The skill detects epic child-task mode from the `Epic Integration Branch` field in the task description and adjusts T6 (verify epic integration branch), T10 (skip user testing), and T11 (merge to integration branch after committing). T0 is performed by the skill itself.
5. Follow the full T0-T13 workflow for this child task. Pause at every approval gate and wait for explicit chat confirmation before proceeding. Jira comments should follow the reduced `task-card` comment contract (T4/T5, T12, and failure comments only) rather than phase-by-phase narration.
6. When the child task's T13 is complete, verify its status:
    - If successful: update the task's knowledge graph node to `status: done`. Mark the tracking task `E8 — Execute [JIRA-KEY]: [task title]` as `completed`. Verify the integration branch passes the full build, all tests, and all linters before proceeding to the next task.
    - If failed: stop and report the failure to the user. Do not begin the next child task until the failure is resolved.
7. **Compaction gate and pause between tasks:** After the child task completes successfully, follow the Phase Compaction Handoff Contract above. Entity name: `phase-handoff-<EPIC-KEY>-E8-<child-JIRA-KEY>`; `next_phase: E8-<next-child-JIRA-KEY>` (or `E9` if this was the final child); include epic anchors: `epic_key: <EPIC-KEY>`, `integration_branch: <name>`, `child_completed: <JIRA-KEY> (N of M)`, `next_child: <next-JIRA-KEY or "none — proceed to E9">`; decisions: child completion summary. REFERENCES: the epic node, the completed child's task node, and the branch node. After emitting the Phase Summary block, end your turn with the following prompt and nothing else: **"Run `/compact` now. After compacting, type `continue` to start the next task, or `stop` to pause the epic here."** Do not begin the next child task until the user types `continue`.
8. Do not begin the next child task until the current one is confirmed complete and the integration branch is clean.

### E9 — User Testing

---

**APPROVAL GATE — USER TESTING REQUIRED.**

- Post a comment notifying the user that all child tasks are complete and the epic is ready for manual testing. The comment must include:
    
    - A summary of everything that was implemented across all child tasks (including which children were pre-existing and already done at workflow start)
    - **Acceptance Criteria & Testing Steps:** For each acceptance criterion from the Epic's Acceptance Criteria section (read in E1), a numbered section with:
        - The criterion restated clearly
        - Step-by-step end-to-end instructions to verify that criterion is met. Include AC covered by existing children that were already `Done` at workflow start — do not assume those AC were previously verified end-to-end. The user is testing the epic as a whole, after all new and edited work has landed on the integration branch.
- Present the same testing handoff in the chat — the user should not have to open Jira to see what to test.
- Then use `AskUserQuestion` with header `E9 Testing`, options: `Approve — everything works as expected (Recommended)` (description: "All acceptance criteria passed — proceed to the epic summary") / `Issues found` (description: "One or more problems were found during testing"). Do not proceed until the user selects an option.
    
- If the user identifies issues: for each distinct issue, invoke the `issue-intake` skill (via the `Skill` tool), passing a brief description of the observed behavior, expected behavior, and this epic's Jira key as args (e.g. `"Testing found: [description]. Related to: [PROJ-KEY]"`). Work through the issue-intake I0–I6 process with the user to document and triage each issue — it will create a Jira card (Bug or Missing Requirement) for each one. After all issues are documented and their Jira cards are created, create a new child Task for each issue card following E6 child-task creation rules (set the `parent` field to the epic key — do not call `jira_create_issue_link`), and add it to the knowledge graph. Invoke the `task-card` skill with each child task's Jira key; epic child-task mode will be detected from the `Epic Integration Branch` field, so T10 user testing is skipped automatically. After each follow-up task's T13 completes, update its knowledge graph node to `status: done` and record its merge completion. Once all follow-up tasks are done, return to this step.
    

---

### E10 — Epic Summary

**ALL fields below are REQUIRED. Do not skip any field. If a field does not apply, explicitly state "N/A" with a brief reason.**

After all child tasks are complete and user testing has passed, post a comment containing ALL of the following:

- **Overview:** What was accomplished across all child tasks.
    
- **Child tasks completed:** Three subsections:
    - **Pre-existing children (executed in E8):** Key, title, status at workflow start, status at completion.
    - **Pre-existing children (skipped — already done or excluded):** Key, title, and reason (already `Done` at workflow start, or `Keep but skip execution` disposition).
    - **Newly created children:** Key, title, status at completion.
    - (If applicable) **Follow-up children created in E9:** Key, title, status.
    
- **Deviations from breakdown plan:** Any tasks that were added, removed, split, or significantly changed, with reasons. Include any backfill edits made to existing children in E6 (e.g. "Added missing Affected Areas section and Epic Integration Branch field to PROJ-201").
    
- **Cumulative release notes:** Consolidated, user-facing release note for the entire epic. If purely internal, state "N/A — internal changes only."
    
- **QA Verification Steps:** End-to-end manual testing instructions for a QA engineer, including:
    
    - Integration testing between changes across child tasks
    - Full user workflows or scenarios enabled by the epic
    - Expected results for each verification step
    - Edge cases that span multiple tasks
- **Open items:** Follow-up work, known limitations, tech debt introduced, or unresolved questions.
    

**REQUIRED: Review the summary before posting.** Verify every field is present, "Child tasks completed" lists every task, and QA Verification Steps cover end-to-end verification. If the review reveals gaps, revise before posting.

> **COMPACTION GATE — E10:** Once the E10 summary comment is posted, follow the Phase Compaction Handoff Contract above. Entity name: `phase-handoff-<EPIC-KEY>-E10`; `next_phase: E11`; decisions: epic completion confirmed, all children done; branch: integration branch name. REFERENCES: epic node, branch node. Emit the Phase Summary block and instruct the user to run `/compact` before proceeding to E11.

### E11 — Cleanup

- Clear the session-scoped knowledge graph before finishing the workflow. This includes the `work_item-<JIRA_KEY>` entity for the epic, the separate `epic` / `task` / `branch` / `phase_handoff` nodes used for breakdown tracking and compaction state, and the explorer-written subgraph from E2 (`exploration`, `affected_file`, `evidence`, `pattern`, `integration_point`, `risk`, `open_question`) along with any per-child-task subgraphs that were not deleted by the child task workflows in epic child-task mode. Use `read_graph` to enumerate, then `delete_entities`. Do not retain epic, task, dependency, branch, or handoff state in the graph once the final Jira record is complete.

---

## Completion Criteria

This workflow is complete when **all** of the following are true:

- All phases executed in sequence (E0 through E11)
- All approval gates explicitly confirmed in the chat
- Breakdown plan reviewed and approved (E4/E5)
- All child task Jira issues created as child work items of the epic (E6–E8)
- All child tasks completed and verified
- User testing completed and approved (E9)
- E10 epic summary comment posted to Jira with all required fields populated
- Session-scoped knowledge graph cleared (E11)
