# CODE REVIEW WORKFLOW — EXECUTION CONTRACT

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute phases in strict sequential order (CR0 through CR11).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure as a comment on this Jira issue. Do not continue.
5. Every required output (comments, findings, summaries) must be posted before the phase is considered complete.

**FILE MEMORY SCOPE:** This workflow stores review state in a per-review file-memory directory keyed by the review card's Jira key. `$MEM/work-item.md` is the root (review type, mode, scope, and the list of reviewed work items from CR1); `$MEM/findings.md` accumulates the review-analyst findings (CR4), contextual findings (CR5, Diff Review only), and criteria verdicts (CR6) so CR8 can assemble a complete, accurate report. Compute `MEM` with the recipe in `file-memory-protocol.md` §1. **Per-phase checkpoint:** after each phase, atomically overwrite `$MEM/checkpoint.md` (`Write` to `checkpoint.md.tmp`, then `mv` over it) with the just-completed `phase`, `next_phase`, and `references` (`[work-item.md, findings.md]`); this workflow has no `/compact` gates, but the checkpoint keeps resume cheap. See `file-memory-protocol.md` for schemas.

**RESUMPTION CHECK:** If this workflow resumes after prior work has already been performed, read `$MEM/checkpoint.md` (and its `references`) to identify the first incomplete phase. If `$MEM` is absent (new session), reconstruct state by reading this Jira issue's description and all comments posted in prior phases, then rebuild `work-item.md` and `findings.md` before continuing. If the issue is already **In Progress**, do not repeat CR0.

**CLARIFICATION RULE:** Do not assume anything. If required information is missing, ambiguous, conflicting, or underspecified, stop and use `AskUserQuestion` to ask the user for clarification before proceeding.

**SERENA PROJECT ACTIVATION:** Before CR0, check Serena's project-activation message (emitted on connect via `--project-from-cwd`); if it reports that onboarding has not been performed, call `onboarding` to scope Serena's language server to the current project directory. Serena's symbol tools (`find_symbol`, `find_referencing_symbols`, `get_symbols_overview`, `search_for_pattern`) invoked directly in CR5/CR6 and used by the parallel `review-analyst` sub-agents depend on this being done. Do this once at the start of the workflow; do not repeat it between phases.

**SUB-AGENT NAME RESOLUTION:** This workflow refers to sub-agents by short name (`review-analyst`, `comment-reviewer`, …). The runtime registers them under different identifiers depending on how they are installed. Before the first sub-agent invocation, resolve each short name against the runtime's available-agents list and use the exact registered identifier:

- If the short name appears verbatim in the list (agents deployed into the project's `.claude/agents/`), use it as-is.
- If installed via the plugin, the registered identifier is `web-cms:<short-name>:<short-name>` — e.g. `review-analyst` → `web-cms:review-analyst:review-analyst`.
- Never invent a partial form such as `web-cms:review-analyst` — it will not resolve. If an invocation fails with an "agent type not found" error, read the available-agents list in the error message, select the entry whose **final segment** equals the short name, and retry with that exact identifier.
- Resolve the scheme once, then reuse it for every subsequent sub-agent invocation in the session.

**TOOL PREFERENCE:** Prefer native tools over Bash for filesystem work. All filesystem, search, and directory operations must stay within the current project directory.

- **File I/O (read, write, edit a known file):** Use native `Read`, `Write`, `Edit`.
- **File discovery (find files by name or pattern):** Use native `Glob`.
- **Content search (find text inside files):** Use native `Grep`. For symbolic code navigation during the review (locating a changed symbol, finding callers of a modified interface, or mapping file structure before reading), use Serena's `find_symbol`, `find_referencing_symbols`, `get_symbols_overview`, and `search_for_pattern` directly — see the `USE SERENA` callouts in CR5 and CR6.
- **Directory operations (list, metadata, move, mkdir):** Use Bash (`ls`, `stat`, `mv`, `mkdir -p`).
- **Git:** Use Bash for all git operations (`git status`, `git diff`, `git log`, `git push`, `git pull`, `git merge`, `git remote`, `git stash`, `git rebase`, etc.) and for running build, test, and lint commands.

**JIRA COMMENT CONTRACT:** Keep Jira comments minimal, structured, and durable. The only routine Jira comment in this workflow is the **CR8** consolidated findings comment. CR10 posts a brief notification comment. Additional comments are allowed only for blocking failures or explicit user-requested status updates.

**Comment formatting:** Pass clean GitHub-flavored markdown to `jira_add_comment`. Never backslash-escape markdown characters — bold is literal `**text**`, never `\*\*text\*\*`. Ensure every bold span has matching `**` delimiters on both sides.

**Comment reviewer gate:** The structured **CR8** findings comment is gated by an `**Independent comment review:**` block, following the same pattern as `plan-reviewer` and `implementation-reviewer`. The `comment-reviewer` sub-agent must return APPROVED (or the 3-iteration cap must be reached) before `jira_add_comment` is called for CR8 — no exceptions. The brief CR10 notification comment and any blocking-failure comments are exempt from the comment-reviewer gate (they have no mandated field outline) but must still follow the comment-formatting rules above.

**TASK TRACKING:** Always use task tracking (`TaskCreate`/`TaskUpdate`) so progress is visible throughout. Create one task per phase at the start of the workflow. Mark each task `in_progress` when starting the phase and `completed` when the phase is done:

- CR0 — Transition to In Progress
- CR1 — Understand the Review Target
- CR2 — Verify Branch State
- CR3 — Baseline Verification
- CR4 — Review the Code
- CR5 — Review Full Changed Files for Context
- CR6 — Verify Criteria
- CR7 — Ask Clarifying Questions
- CR8 — Compile Review Findings
- CR9 — Create Remediation Task
- CR10 — Notify
- CR11 — Cleanup

---

### CR0 — Transition to In Progress

**This phase requires TWO separate tool calls. Do not move to CR1 until both are complete.**

1. **Tool call 1:** Call `jira_get_transitions` with this issue's key. From the response, find the transition whose target status is **In Progress** and note its **ID**.
2. **Tool call 2:** Call `jira_transition_issue` with this issue's key and that transition ID. This is the call that actually moves the issue. Retrieving transitions alone does nothing -- you MUST call `jira_transition_issue` to complete this phase.

Do not guess transition IDs. Always retrieve them first via tool call 1.

### CR1 — Understand the Review Target

- Retrieve the Jira issue using the provided key and read the **Review Details** section of the issue description thoroughly.
    
- Identify the **Review Mode** (Diff or Implementation) from the Review Details. This determines the behavior of CR2, CR4, and CR5.
    
- Retrieve the Jira issue identified in the Review Details and read its full description.
    
- Based on the Review Type, build a complete picture of what this review covers:
    
    **Release:**
    
    - Retrieve and read the description and acceptance criteria of every work item listed in Work Items Included.
    - Identify the release goals and any known risks.
    - Recover the most recent branch name for each included work item from its latest testing handoff or summary comment when available. Note any missing branch names for CR2.
    
    **Epic:**
    
    - Retrieve the epic description, goals, and acceptance criteria.
    - Retrieve and read the description and acceptance criteria of every child task listed in Work Items Included.
    - Review the approved breakdown plan from the epic's Jira comment history.
    - Recover the most recent branch name for each child task from its latest testing handoff or summary comment when available. Note any missing branch names for CR2.
    
    **Task:**
    
    - Retrieve the task description, acceptance criteria, and affected areas.
    - Review the approved implementation plan from the task's Jira comment history.
    
    **Bug:**
    
    - Retrieve the bug description, fix criteria, steps to reproduce, and affected areas.
    - Review the approved fix plan from the bug's Jira comment history.
    - Note any regression tests that were required to be written as part of the fix.

> **WRITE work-item.md:** After the review target and included work items are identified, bootstrap file memory: compute `MEM` (recipe §1), `mkdir -p "$MEM"`, and `Write $MEM/work-item.md` (schema §3.1) with `work_type: code-review`, `jira_key`, `title`, `status: in_progress`, `phase: CR1`, `skill: code-review`, plus a `reviewed_items` frontmatter list — one entry per included item with `item_key`, `item_type`, `summary`, `status` (Task/Bug reviews have a single entry). CR6 records `criteria_verdicts` against these `item_key`s in `findings.md`.

### CR2 — Verify Branch State

- Check out the branch to review and confirm it exists.

**Diff Review:**
    
- Based on the Review Type:
    
    **Release:** Using the branch names recovered in CR1 (and any explicitly provided in Review Details), confirm all work item branches have been merged into the branch to review. If any required branch name is missing, stop and use `AskUserQuestion` (Header: `Missing Branch`, Question: `The branch name for [work item key] could not be recovered. Please provide the branch name to continue.`, Options: `Provide branch name` — type it using the Other option, `Stop review` — abort the review) before continuing. If any recovered branch is missing, stop and post a comment listing the missing branches. Do not continue.
    
    **Epic:** Using the branch names recovered in CR1 (and any explicitly provided in Review Details), confirm all child task branches have been merged into the integration branch. If any required branch name is missing, stop and use `AskUserQuestion` (Header: `Missing Branch`, Question: `The branch name for [child task key] could not be recovered. Please provide the branch name to continue.`, Options: `Provide branch name` — type it using the Other option, `Stop review` — abort the review) before continuing. If any recovered branch is missing, stop and post a comment. Do not continue.
    
    **Task:** Confirm the task branch exists and is based on the correct default branch (or epic integration branch if this is a child task).
    
    **Bug:** Confirm the bug fix branch exists and is based on the correct default branch.

**Implementation Review:**

- Confirm the branch exists and can be checked out.
- Confirm the files, modules, or services listed in the **Implementation Scope** from Review Details exist on the branch. If any are missing, stop and post a comment listing the missing items. Do not continue.
    

### CR3 — Baseline Verification

- Run the full build, all tests, and all linters/static analysis on the branch to review.
- **All checks must pass before continuing.** If anything fails, post a comment describing the failures. Do not continue.
- **Bug only:** Confirm the regression test written during the fix is present and passing.

### CR4 — Review the Code

> **USE SEQUENTIAL THINKING:** Before dispatching the review analysts, invoke the `sequentialthinking` tool. Confirm that all required context is available and complete. For Diff Review: confirm the diff, work item details, accepted criteria, and approved plan are ready. For Implementation Review: confirm the full source files from the Implementation Scope are read and the work item context is complete. Identify whether this is a Release/Epic review (requires `cross_item_integration`) or a Task/Bug review (skip that category). Resolve any ambiguities before spawning agents.

> **WRITE findings.md:** After all review-analyst sub-agents return their findings, `Write $MEM/findings.md` with a `findings[]` frontmatter array — one entry per finding with `category`, `file`, `description`, `severity`. CR4 always runs before CR5/CR6, so this is always the initial write. This ensures CR8 can assemble the complete report from one file rather than reconstructing it from multiple sub-agent outputs.

**Diff Review:**

Generate the diff between the branch to review and the default branch. Spawn the following `review-analyst` sub-agents **in parallel**. Each receives the full diff, the review type, and the work item context from CR1. Only spawn rows whose `Condition` applies.

|Sub-agent instance|Assigned category|Condition|
|---|---|---|
|review-analyst #1|`code_quality`|Always|
|review-analyst #2|`test_coverage`|Always|
|review-analyst #3|`documentation`|Always|
|review-analyst #4|`security_performance`|Always|
|review-analyst #5|`cross_item_integration`|Release and Epic only|

Wait for all sub-agents to return their findings reports before proceeding.

**Implementation Review:**

Read the full source files for every file, module, or service listed in the **Implementation Scope** from Review Details. Do not generate a diff against any other branch. Spawn the following `review-analyst` sub-agents **in parallel**. Each receives the **full file contents** (not a diff), the review type, the implementation scope, and the work item context from CR1. Instruct each sub-agent to perform a deep-dive review of the complete implementation. Only spawn rows whose `Condition` applies.

|Sub-agent instance|Assigned category|Condition|
|---|---|---|
|review-analyst #1|`code_quality`|Always|
|review-analyst #2|`test_coverage`|Always|
|review-analyst #3|`documentation`|Always|
|review-analyst #4|`security_performance`|Always|
|review-analyst #5|`cross_item_integration`|Release and Epic only|

Wait for all sub-agents to return their findings reports before proceeding.

When all reports are received, write every finding from all reports into `$MEM/findings.md` (see WRITE findings.md above), then proceed to CR5 (Diff Review) or CR6 (Implementation Review — skip CR5).

### CR5 — Review Full Changed Files for Context

> **Implementation Review: Skip this phase entirely.** The full source files were already reviewed in CR4. Proceed directly to CR6.

**Diff Review only:**

> **USE SERENA:** When the Serena MCP server is available, use `get_symbols_overview` (with `depth`) on each changed file to get a structural map of all symbols before reading the full file. This lets you understand how the changed code fits into the file's class/method hierarchy without scanning the entire file linearly. Use `find_referencing_symbols` on any symbol that was added or modified to verify that all downstream consumers are consistent with the change.

> **MERGE into findings.md:** `Read $MEM/findings.md`, add the new contextual findings to the existing `findings[]` array (each with `category: contextual` and `source: full_file_context`), then `Write` the complete updated file. Do not overwrite without reading first — CR4's findings must be preserved.

- For each file modified in the diff, use `get_symbols_overview` to understand the file's full structure, then read the full file to understand the change in its complete context.
- Identify any issues not visible in the diff alone, such as:
    - Changes that are correct in isolation but inconsistent with the rest of the file
    - Missing updates to related code in the same file that should have been changed alongside the diff
    - Pre-existing issues in the file that interact poorly with the new changes
    - Callers or consumers of changed symbols (found via `find_referencing_symbols`) that were not updated

### CR6 — Verify Criteria

> **USE SEQUENTIAL THINKING:** Before verifying criteria, invoke the `sequentialthinking` tool. Use it to map each criterion to the specific code change(s) that implement it, reason through whether the implementation is wired into the expected call paths (not just that the code was written, but that it runs), and identify any criterion where the implementation appears partial or where the evidence for a pass is weaker than expected. A superficial pass/fail without tracing the code paths is the most common failure mode in criteria verification — it produces false-positive "pass" verdicts that let unmet criteria through to production. Do not begin verification until the reasoning is complete.

> **USE SERENA:** When the Serena MCP server is available, use `find_symbol` to locate the code that implements each criterion, and `find_referencing_symbols` to trace that the implementation is actually invoked in the expected code paths. This provides stronger evidence for pass/fail verdicts than reading diffs alone.

> **MERGE into findings.md:** `Read $MEM/findings.md`, add a `criteria_verdicts[]` key (if absent) and append one entry per verified item — `item_key` (Jira key or criterion text), `verdict` (pass / fail / partial), and `rationale` — then `Write` the complete updated file. Do not overwrite without reading first — prior findings must be preserved. CR8 reads `criteria_verdicts[]` to populate the Criteria Verification section.

**REQUIRED:** Verify the criteria for the review target. Do not skip any item.

**Release and Epic:**

- For each work item, read its acceptance criteria and trace the code changes to confirm each criterion is satisfied. Use `find_symbol` to locate implementing code and `find_referencing_symbols` to verify it is wired into the correct code paths.
- If any acceptance criterion is not met, flag it as a finding.
- If acceptance criteria are ambiguous or missing, flag it as a finding.

**Task:**

- Read the acceptance criteria from the task description and trace the code changes to confirm each criterion is satisfied. Use `find_symbol` to locate implementing code and `find_referencing_symbols` to verify integration.
- Verify the implementation matches the approved plan. Flag any unaddressed deviations.

**Bug:**

- Read the fix criteria from the bug description and verify every criterion is satisfied.
- Re-trace the original steps to reproduce and confirm the bug no longer occurs based on the code. Use `find_referencing_symbols` on the fixed code path to confirm no other callers are still exercising the old buggy behavior.
- Verify the regression test identified in the `test_coverage` review-analyst findings would catch a recurrence of this bug.

### CR7 — Ask Clarifying Questions

**Objective:** Resolve any ambiguities, gaps, or risks discovered during the review before compiling findings.

**Agent Actions:**

1. Review all output from CR0 through CR6.
2. Identify clarifying questions. Mark each as `[BLOCKING]` or `[NICE TO HAVE]`.
3. For each clarifying question, use a separate `AskUserQuestion` call in sequence — one question per call. Do not batch multiple questions into one call. Include the `[BLOCKING]` or `[NICE TO HAVE]` tag in the question text. For open-ended questions, use two options: `Provide answer` (description: "Type your response using the Other input field") and, for non-blocking questions only, `Skip` (description: "Skip this non-blocking question"). For closed-enum questions, use the specific enum options. If there are no clarifying questions, state this in the chat and proceed.
4. Record all answers verbatim. Do not infer or invent answers.

> **REQUIRED:** All BLOCKING questions answered and answers recorded. Remaining unanswered questions listed as open items.

> **APPROVAL GATE — FULL STOP.** Use `AskUserQuestion` (Header: `CR7 Approval`, Question: `All clarifying questions have been answered and answers recorded above. Can we proceed to compiling the findings?`, Options: `Approve and proceed (Recommended)` — all blocking answers are accurate, `Request changes` — some answers need revision) to get explicit confirmation. Do not proceed to CR8 until the user approves.

### CR8 — Compile Review Findings

> **USE SEQUENTIAL THINKING:** Before assembling the report, invoke the `sequentialthinking` tool. Use it to read across all `finding` and `criteria_verdict` nodes and determine whether the Overall Assessment is consistent with the evidence — a single Critical finding that the criteria verdicts show is unmitigated must produce a "Changes Required" verdict regardless of other categories. Also reason through whether any findings in different categories are actually symptoms of the same root cause (they should be reported together, not as separate items that inflate the count). A report that lists findings accurately but assigns the wrong verdict — or misses a pattern across categories — is more dangerous than no review at all. Do not assemble the report until the reasoning is complete.

> **THINK HARD:** Before assigning the Overall Assessment verdict, think hard about whether the verdict is consistent with the most severe finding — not the average finding. A verdict of "Approved with Minor Findings" when a Critical finding is present but mislabeled, or when two Major findings together constitute a Critical risk, is the most consequential mistake this phase can make.

> **READ findings.md:** `Read $MEM/findings.md` — all `findings[]` and `criteria_verdicts[]` — to assemble the findings report. Filter `findings[]` by `category` to populate each section; count by `severity` for the Consolidated Findings Count. This is the primary benefit of file memory in this workflow — assembling a complete, accurate report across 5 review categories without relying on working memory after a long review session.

**ALL fields below are REQUIRED. Do not skip any field. If a field does not apply, explicitly state "N/A" with a brief reason.**

Draft a single consolidated comment on this Jira issue with the exact heading `**CR8 — Code Review Findings**` as the verbatim first line, then containing ALL of the following:

- **Review Summary:** Concise overview of what was reviewed, the review type, and the total scope of changes.
- **Criteria Verification:** List each work item (Release/Epic) or the single item (Task/Bug) with its criteria verification result:
    - Release/Epic: Pass / Fail / Partial per work item — with explanation for any non-pass
    - Task: Pass / Fail / Partial per acceptance criterion — with explanation for any non-pass
    - Bug: Pass / Fail per fix criterion — plus explicit confirmation that the regression test is present and the bug no longer occurs
- **Code Quality Findings:** Findings from the `code_quality` review-analyst. For each: file, line or section, description, severity (Critical / Major / Minor / Suggestion).
- **Test Coverage Findings:** Findings from the `test_coverage` review-analyst. For each: affected area, description of gap, severity.
- **Documentation Findings:** Findings from the `documentation` review-analyst. For each: file, what is missing or incorrect, severity.
- **Security and Performance Findings:** Findings from the `security_performance` review-analyst. For each: file, description, severity.
- **Cross-Item Integration Findings:** Findings from the `cross_item_integration` review-analyst (Release/Epic only). Mark "N/A -- single work item" for Task and Bug reviews.
- **Contextual Findings:** Issues found in CR5 (Diff Review only). For each: file, description, severity. Mark "N/A -- Implementation Review (full files reviewed in CR4)" if CR5 was skipped.
- **Overall Assessment:** One of the following verdicts:
    - **Approved** — No critical or major findings. Work is ready to merge / ship.
    - **Approved with Minor Findings** — No critical or major findings, but minor issues or suggestions exist. Work can proceed; findings should be addressed in a follow-up.
    - **Changes Required** — Critical or major findings exist. Work should not proceed until findings are resolved.
- **Consolidated Findings Count:** Total number of findings by severity (Critical / Major / Minor / Suggestion).

**REQUIRED: Review the findings before posting.** Verify every field is populated, every verdict is accurate and justified, all findings are captured, and the Overall Assessment is consistent with the findings. If the review reveals gaps, revise before posting.

**Independent comment review:**

Once the comment body is drafted, invoke the `comment-reviewer` sub-agent, providing:

- The drafted comment body verbatim, exactly as it will be passed to `jira_add_comment`
- The phase label `CR8 — Code Review Findings`
- The overall assessment verdict and the list of work items reviewed
- The Jira issue key

The sub-agent will return a structured report with an overall verdict of either **APPROVED** or **CHANGES REQUIRED**.

- If **APPROVED**: call `jira_add_comment` with the reviewed body.
- If **CHANGES REQUIRED**: address every Critical and Major finding, revise the draft, then invoke `comment-reviewer` again with the updated body. Repeat until the verdict is APPROVED.
- **Max 3 review iterations.** If `comment-reviewer` returns CHANGES REQUIRED after 3 iterations, post the comment as-is with the remaining minor findings noted inline at the bottom of the comment body, and continue.

Do not call `jira_add_comment` until `comment-reviewer` returns APPROVED (or the 3-iteration cap is reached). A clean self-check or memory of having run `comment-reviewer` earlier in the workflow does not substitute.

### CR9 — Create Remediation Task (If Applicable)

- If the overall assessment is **Approved with Minor Findings** or **Changes Required:**

    1. Derive the project key from this review issue's key (the prefix before the hyphen, e.g., `PROJ` from `PROJ-123`).
    2. **Recommend a priority** for the remediation task based on the severity of the findings (Critical findings = High or Critical priority; Major findings only = Medium; Minor findings only = Low). Use `AskUserQuestion` to confirm the priority before creating the issue:
        - Header: `Task Priority`
        - Question: `What priority should the remediation task be set to?`
        - Options (put the recommended one first with `(Recommended)`): `Critical`, `High`, `Medium`, `Low` — derive the recommendation from finding severity.
    3. **Recommend an epic** for the remediation task. Search Jira for open epics in the same project that relate to the code areas covered by the review findings. If the reviewed issue is already linked to an epic, suggest that epic. Use `AskUserQuestion` to confirm the epic:
        - Header: `Epic Link`
        - Question: `Which epic should the remediation task be linked to?`
        - Options:
            - `Use suggested epic: <KEY> (Recommended)` — Link to the suggested epic.
            - `Provide a different epic key` — Type your preferred epic key using the Other input field.
            - `No epic` — Leave the remediation task unlinked to an epic.
        - Only set the Epic Link if the user selects the suggested epic or provides a different key via Other.
    4. Create a new Task by calling `jira_create_issue` with the derived `project_key`, `issue_type: "Task"`, `summary` set to `{PROJECTKEY} [Review Type] Code Review Remediation`, and `additional_fields` set to `{"priority": {"name": "High"}}` (substituting the confirmed priority name; also include `"epicKey": "EPIC-KEY"` if the user confirmed an epic). Populate the `description` with ALL findings that require action, organized by severity (Critical first, then Major, then Minor). For each finding include: the file, description, severity, and the review category it came from.
    5. After the task is created, link it to this review issue by calling `jira_create_issue_link` with `link_type: "Relates to"`, `inward_issue_key` set to the new task's key, and `outward_issue_key` set to this review issue's key.
- If the overall assessment is **Approved:** skip task creation. No further action is required at this phase.
    

### CR10 — Notify

- Post a comment tagging the assignee or reporter with the overall assessment verdict and a link to the CR8 findings comment.
- If a remediation task was created in CR9, include the task key in the notification.

### CR11 — Cleanup

- Remove the review's file-memory directory: `rm -rf "$MEM"` (Bash). Do not retain review findings or criteria verdicts on disk after the consolidated Jira comments exist.

---

## Completion Criteria

This workflow is complete when **all** of the following are true:

- All phases executed in sequence (CR0 through CR11)
- All approval gates explicitly confirmed in the chat
- Issue transitioned to In Progress (CR0)
- Code reviewed across all applicable categories (CR4–CR6)
- CR7 clarifying questions resolved (or confirmed none needed)
- CR8 consolidated findings comment reviewed by `comment-reviewer` (APPROVED or 3-iteration cap reached) before `jira_add_comment` ran, with all required fields populated and overall assessment verdict included
- Remediation task created and linked if findings required action (CR9), or task creation skipped when the overall assessment was Approved
- Assignee or reporter notified with verdict and links (CR10)
- File-memory directory removed (`rm -rf "$MEM"`) (CR11)
