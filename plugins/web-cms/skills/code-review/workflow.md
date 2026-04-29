# CODE REVIEW WORKFLOW — EXECUTION CONTRACT

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute phases in strict sequential order (CR0 through CR11).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure as a comment on this Jira issue. Do not continue.
5. Every required output (comments, findings, summaries) must be posted before the phase is considered complete.

**KNOWLEDGE GRAPH SCOPE:** The knowledge graph in this workflow accumulates review target context from CR1, findings from parallel review-analyst sub-agents (CR4), contextual findings from CR5 (Diff Review only), and criteria verdicts (CR6) so that CR8 can assemble a complete, accurate report. The graph is session-scoped. If this workflow is resumed in a new session and the graph is empty, reconstruct state by reading this Jira issue's description and all comments posted in prior phases, then rebuild the `work_item`, finding, and criteria nodes before continuing.

**RESUMPTION CHECK:** If this workflow resumes after prior work has already been performed, inspect the issue status and previously posted review comments first to identify the first incomplete phase. If the issue is already **In Progress**, do not repeat CR0.

**CLARIFICATION RULE:** Do not assume anything. If required information is missing, ambiguous, conflicting, or underspecified, stop and ask the user for clarification before proceeding.

**SERENA PROJECT ACTIVATION:** Before CR0, call `check_onboarding_performed`. If it reports that onboarding has not been performed for this project, call `onboarding` to scope Serena's language server to the current project directory. Serena's symbol tools (`find_symbol`, `find_referencing_symbols`, `get_symbols_overview`, `search_for_pattern`) invoked directly in CR5/CR6 and used by the parallel `review-analyst` sub-agents depend on this being done. Do this once at the start of the workflow; do not repeat it between phases.

**TOOL PREFERENCE:** Prefer native tools over Bash for filesystem work. All filesystem, search, and directory operations must stay within the current project directory.

- **File I/O (read, write, edit a known file):** Use native `Read`, `Write`, `Edit`.
- **File discovery (find files by name or pattern):** Use native `Glob`.
- **Content search (find text inside files):** Use native `Grep`. For symbolic code navigation during the review (locating a changed symbol, finding callers of a modified interface, or mapping file structure before reading), use Serena's `find_symbol`, `find_referencing_symbols`, `get_symbols_overview`, and `search_for_pattern` directly — see the `USE SERENA` callouts in CR5 and CR6.
- **Directory operations (list, metadata, move, mkdir):** Use Bash (`ls`, `stat`, `mv`, `mkdir -p`).
- **Git:** Use Bash for all git operations (`git status`, `git diff`, `git log`, `git push`, `git pull`, `git merge`, `git worktree`, `git remote`, `git stash`, `git rebase`, etc.) and for running build, test, and lint commands.

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

1. **Tool call 1:** Call `getTransitionsForJiraIssue` with this issue's key. From the response, find the transition whose target status is **In Progress** and note its **ID**.
2. **Tool call 2:** Call `transitionJiraIssue` with this issue's key and that transition ID. This is the call that actually moves the issue. Retrieving transitions alone does nothing -- you MUST call `transitionJiraIssue` to complete this phase.

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

> **USE KNOWLEDGE GRAPH:** After the review target and included work items are identified, write them to the knowledge graph as `work_item` nodes before proceeding. For Release and Epic reviews, create one `work_item` node per included item with properties `item_key`, `item_type`, `summary`, and `status`. For Task and Bug reviews, create a single `work_item` node for the reviewed issue with the same properties. CR6 links `criteria_verdict` nodes to these `work_item` nodes.

### CR2 — Verify Branch State

- Check out the branch to review and confirm it exists.

**Diff Review:**
    
- Based on the Review Type:
    
    **Release:** Using the branch names recovered in CR1 (and any explicitly provided in Review Details), confirm all work item branches have been merged into the branch to review. If any required branch name is missing, stop and ask the user to provide it before continuing. If any recovered branch is missing, stop and post a comment listing the missing branches. Do not continue.
    
    **Epic:** Using the branch names recovered in CR1 (and any explicitly provided in Review Details), confirm all child task branches have been merged into the integration branch. If any required branch name is missing, stop and ask the user to provide it before continuing. If any recovered branch is missing, stop and post a comment. Do not continue.
    
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

> **USE KNOWLEDGE GRAPH:** After all review-analyst sub-agents return their findings, write each finding to the knowledge graph as a `finding` node before proceeding. For each finding: `category`, `file`, `description`, `severity`. This ensures CR8 can assemble the complete report from the graph rather than reconstructing it from multiple sub-agent outputs.

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

When all reports are received, write every finding from all reports to the knowledge graph as `finding` nodes (see USE KNOWLEDGE GRAPH above), then proceed to CR5 (Diff Review) or CR6 (Implementation Review — skip CR5).

### CR5 — Review Full Changed Files for Context

> **Implementation Review: Skip this phase entirely.** The full source files were already reviewed in CR4. Proceed directly to CR6.

**Diff Review only:**

> **USE SERENA:** When the Serena MCP server is available, use `get_symbols_overview` (with `depth`) on each changed file to get a structural map of all symbols before reading the full file. This lets you understand how the changed code fits into the file's class/method hierarchy without scanning the entire file linearly. Use `find_referencing_symbols` on any symbol that was added or modified to verify that all downstream consumers are consistent with the change.

> **USE KNOWLEDGE GRAPH:** Write contextual findings discovered here using the same `finding` node structure as CR4, with `category: contextual` and a `source: full_file_context` property to distinguish them from diff findings.

- For each file modified in the diff, use `get_symbols_overview` to understand the file's full structure, then read the full file to understand the change in its complete context.
- Identify any issues not visible in the diff alone, such as:
    - Changes that are correct in isolation but inconsistent with the rest of the file
    - Missing updates to related code in the same file that should have been changed alongside the diff
    - Pre-existing issues in the file that interact poorly with the new changes
    - Callers or consumers of changed symbols (found via `find_referencing_symbols`) that were not updated

### CR6 — Verify Criteria

> **USE SERENA:** When the Serena MCP server is available, use `find_symbol` to locate the code that implements each criterion, and `find_referencing_symbols` to trace that the implementation is actually invoked in the expected code paths. This provides stronger evidence for pass/fail verdicts than reading diffs alone.

> **USE KNOWLEDGE GRAPH:** For each work item or criterion verified, write a `criteria_verdict` node with properties: `item_key` (Jira key or criterion text), `verdict` (pass / fail / partial), and `rationale`. Link it to the relevant work item node. CR8 reads these nodes to populate the Criteria Verification section of the findings report.

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
3. Present all questions in a **single batch** — do not ask one at a time.
4. Ask all questions **in the chat** and wait for answers before proceeding. If there are no clarifying questions, state this in the chat and proceed.
5. Record all answers verbatim. Do not infer or invent answers.

> **REQUIRED:** All BLOCKING questions answered and answers recorded. Remaining unanswered questions listed as open items.

> **APPROVAL GATE — FULL STOP.** Present all questions and recorded answers. User must confirm all blocking answers are accurate. Do not proceed to CR8 until confirmed.

### CR8 — Compile Review Findings

> **USE KNOWLEDGE GRAPH:** Read all `finding` nodes and `criteria_verdict` nodes from the graph to assemble the findings report. Query nodes by `category` to populate each section. Count nodes by `severity` for the Consolidated Findings Count. This is the primary benefit of the knowledge graph in this workflow — assembling a complete, accurate report across 5 review categories without relying on working memory after a long review session.

**ALL fields below are REQUIRED. Do not skip any field. If a field does not apply, explicitly state "N/A" with a brief reason.**

Post a single consolidated comment on this Jira issue containing ALL of the following:

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

### CR9 — Create Remediation Task (If Applicable)

- If the overall assessment is **Approved with Minor Findings** or **Changes Required:**

    1. Derive the project key from this review issue's key (the prefix before the hyphen, e.g., `PROJ` from `PROJ-123`).
    2. **Recommend a priority** for the remediation task based on the severity of the findings (Critical findings = High or Critical priority; Major findings only = Medium; Minor findings only = Low). Present the recommended priority to the user for confirmation before creating the issue.
    3. **Recommend an epic** for the remediation task. Search Jira for open epics in the same project that relate to the code areas covered by the review findings. If the reviewed issue is already linked to an epic, suggest that epic. Present the recommendation and ask the user to: (a) accept the suggested epic, (b) provide a different epic key, or (c) leave blank for no epic. Only set the Epic Link if the user accepts or provides a key.
    4. Create a new Task by calling `createJiraIssue` with the derived `project_key`, `issue_type: "Task"`, `summary` set to `{PROJECTKEY} [Review Type] Code Review Remediation`, and `additional_fields` set to `{"priority": {"name": "High"}}` (substituting the confirmed priority name; also include `"epicKey": "EPIC-KEY"` if the user confirmed an epic). Populate the `description` with ALL findings that require action, organized by severity (Critical first, then Major, then Minor). For each finding include: the file, description, severity, and the review category it came from.
    5. After the task is created, link it to this review issue by calling `createIssueLink` with `link_type: "Relates to"`, `inward_issue_key` set to the new task's key, and `outward_issue_key` set to this review issue's key.
- If the overall assessment is **Approved:** skip task creation. No further action is required at this phase.
    

### CR10 — Notify

- Post a comment tagging the assignee or reporter with the overall assessment verdict and a link to the CR8 findings comment.
- If a remediation task was created in CR9, include the task key in the notification.

### CR11 — Cleanup

- Clear the session-scoped knowledge graph before finishing the workflow. Do not retain review findings or criteria verdict nodes after the consolidated Jira comments exist.

---

## Completion Criteria

This workflow is complete when **all** of the following are true:

- All phases executed in sequence (CR0 through CR11)
- All approval gates explicitly confirmed in the chat
- Issue transitioned to In Progress (CR0)
- Code reviewed across all applicable categories (CR4–CR6)
- CR7 clarifying questions resolved (or confirmed none needed)
- CR8 consolidated findings comment posted to Jira with all required fields populated and overall assessment verdict included
- Remediation task created and linked if findings required action (CR9), or no-remediation comment posted if approved
- Assignee or reporter notified with verdict and links (CR10)
- Session-scoped knowledge graph cleared (CR11)
