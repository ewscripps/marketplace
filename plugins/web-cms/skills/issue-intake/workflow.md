# ISSUE INTAKE WORKFLOW — EXECUTION CONTRACT

> **How this works:** The user invokes this workflow when they encounter unexpected or missing behavior in the software. The agent gathers information, researches the codebase and Jira context, and classifies the issue as either a **Bug** (existing code is broken) or a **Missing Requirement** (the behavior was never implemented). Based on that classification, it either creates a Jira Bug card or transitions into the full Requirements Workflow.

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute phases in strict sequential order (I0 through I5).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure in the chat. Do not continue.
5. Every required output must be presented in the chat before the phase is considered complete.
6. Do not create any Jira issue until I5 is reached and approved.

**Note:** Approval gates in this workflow are confirmed in the chat -- no Jira issue exists yet.

**APPROVAL GATE BEHAVIOR:** Approval gates are chat-scoped. If explicit approval is not captured before the session ends or context is lost, stop at the gate. On resume, re-present the latest classification, draft, or summary and ask for confirmation again. Never assume a pending approval was granted.

**CLARIFICATION RULE:** Do not assume anything. If required information is missing, ambiguous, conflicting, or underspecified, stop and ask the user for clarification before proceeding.

**KNOWLEDGE GRAPH SCOPE:** The knowledge graph in this workflow is session-scoped. It accumulates structured context across I0-I4 so that I5 can assemble a complete, grounded Jira issue description. All graph content must be fully materialized into the Jira card description before the session ends -- do not rely on the graph persisting to a future session.

**TOOL PREFERENCE:** Prefer native tools over Bash for filesystem work. All filesystem, search, and directory operations must stay within the current project directory.

- **File I/O (read, write, edit a known file):** Use native `Read`, `Write`, `Edit`.
- **File discovery (find files by name or pattern):** Use native `Glob`.
- **Content search (find text inside files):** Use native `Grep`. For symbolic code search (finding classes, methods, or callers), delegate to the `codebase-explorer` agent, which uses the Serena MCP server.
- **Directory operations (list, metadata, move, mkdir):** Use Bash (`ls`, `stat`, `mv`, `mkdir -p`).
- **Git:** Use Bash for all git operations (`git status`, `git diff`, `git log`, `git push`, `git pull`, `git merge`, `git worktree`, `git remote`, `git stash`, `git rebase`, etc.) and for running build, test, and lint commands.

**TASK TRACKING:** Always use task tracking (`TaskCreate`/`TaskUpdate`) so progress is visible throughout. Create one task per phase at the start of the workflow. Mark each task `in_progress` when starting the phase and `completed` when the phase is done:

- I0 — Intake
- I1 — Jira Context Review
- I2 — Codebase Analysis
- I3 — Clarifying Questions
- I4 — Classification & Triage
- I5 — Resolution
- I6 — Cleanup

---

### I0 — Intake

**Objective:** Greet the user and gather all information about the unexpected or missing behavior through natural conversation. Do not assume or imply whether this is a bug or a missing requirement — remain neutral until I4.

**If called with pre-populated context (non-empty $ARGUMENTS):** Skip the cold-start introduction. Present the pre-populated fields (observed behavior, expected behavior, related Jira key) as a structured summary and ask the user to confirm or correct them before proceeding to the remaining I0 questions. Only ask about fields that were not pre-populated.

**Agent Actions:**

1. Introduce yourself and briefly explain what this workflow will do and what to expect (phases, classification, end result). Skip this step if called with pre-populated context — the user is already in context from the parent workflow.
    
2. Ask the following questions **conversationally, one topic at a time.** Do not present them as a form or list. Wait for each response before asking the next.
    
    **Behavior description:**
    
    - What is a short title or summary for this issue?
    - What were you doing when you encountered it? Walk me through what happened.
    - What did you expect to happen instead?
    - Has this ever worked correctly before, to your knowledge?
    
    **Reproduction:**
    
    - Can you reliably reproduce this? If yes, what are the exact steps?
    - Does it happen every time, or intermittently? If intermittently, how often approximately?
    - Is there anything that makes it more or less likely to occur?
    - Are there any relevant logs, error messages, exceptions, or stack traces available? If yes, please share them.
    
    **Environment:**
    
    - What environment did this occur in? (Production / Staging / Development / Other)
    - What operating system and version?
    - What browser and version, if applicable?
    - What application version or build number, if known?
    - Any other relevant environment details — region, account type, feature flags, etc.?
    
    **Impact & context:**
    
    - How many users or systems are affected, if known?
    - Is there a workaround available? If yes, what is it?
    - Who reported this — name and team?
    - Is there a related Jira Epic or issue this should be linked to? If so, what's the key?
    - Has a Jira card already been created for this issue? If so, what's the issue key?
3. After all questions are answered, summarize the gathered context back to the user in a clear, structured format.
    

> **REQUIRED:** The following context must be confirmed before proceeding:
> 
> - Issue Title
> - Observed Behavior (what happened)
> - Expected Behavior (what should happen)
> - Previously Worked (yes / no / unknown)
> - Reproduction Steps (or "intermittent — no consistent repro steps")
> - Reproduction Rate (always / intermittent / unknown)
> - Logs / Exceptions / Stack Traces (content, or explicitly "none available")
> - Environment: env tier, OS + version, browser + version (if applicable), app version (if known)
> - User / System Impact
> - Workaround (description, or explicitly "none")
> - Reported By (name / team)
> - Related Issue or Epic (Jira key, or explicitly "none")
> - Existing Jira Card (issue key, or explicitly "none")

> **APPROVAL GATE — FULL STOP.** Present the gathered context as a structured summary. User must confirm all fields are accurate and nothing is missing. Do not proceed to I1 until confirmed.

---

### I1 — Jira Context Review

**Objective:** Check for duplicate or related issues and anchor the issue in the current project structure.

**Agent Actions:**

1. If an Existing Jira Card key was provided in I0, retrieve that issue immediately. Read its full description, summary, any context already captured (labels, epic link, linked issues, severity, reproduction steps, environment details, and comment history). Surface all of this content — it will be used to enrich the final Bug description in I5 Path A.
2. Search Jira for existing bugs, tasks, or issues that match or closely overlap with the observed behavior.
3. Search for any known issues, incidents, or investigations already open in the same area.
4. If a Related Issue or Epic was provided in I0, retrieve its description and status.

> **REQUIRED:** Present all of the following in the chat before proceeding:
> 
> - If an existing card was provided: its full summary, description, and any context already captured
> - List of potentially duplicate or related issues: key, summary, status
> - Explicit confirmation that no duplicate issue is already open
> - Summary of related Epic or issue (if applicable)

> **APPROVAL GATE — FULL STOP.** Present the Jira context summary. User must confirm the existing card (if any) is correct, no duplicate exists, and the related Epic (if any) is correct. Do not proceed to I2 until confirmed.

> **USE KNOWLEDGE GRAPH:** After the I1 approval gate is confirmed, write the issue under investigation to the knowledge graph as a `work_item` entity with name `work_item-<key>` where `<key>` is the existing Jira issue key (if provided in I0) or a normalized slug of the issue title prefixed with `issue-` (e.g. `work_item-issue-checkout-button-disabled`). Observations: `title`, `observed_behavior`, `expected_behavior`, `existing_jira_key` (if provided), `phase: investigation`. **Record the entity name** — it is the `work_item_id` passed to every `codebase-explorer` call in I2.

---

### I2 — Codebase Analysis

**Objective:** Determine what the codebase currently does in the affected area — whether logic exists for the expected behavior or not. This is the primary input to classification in I4.

> **USE SEQUENTIAL THINKING:** Before presenting the codebase analysis, invoke the `sequentialthinking` tool. Based on the explorer findings, systematically evaluate the evidence of whether code exists for the expected behavior. A false negative here — concluding code doesn't exist because it wasn't found quickly — is the most common source of misclassification in I4. Work through the evidence, identify any gaps that need further investigation, and resolve them before concluding. Do not present the analysis until the reasoning is complete.

> **USE KNOWLEDGE GRAPH:** After synthesizing the explorer findings, write investigation conclusions to the graph. Roll up the explorer-written `affected_file` entities into `affected_area` summary nodes for each file, module, or service identified. Create a `code_evidence` node with properties: `code_exists_for_behavior` (true / false / uncertain), `evidence` (specific file names, function names, or confirmed absence — pulled from the explorer-written `evidence` entities), and `inferred` (true / false). Link both to the `work_item` node. I4A reads these nodes as primary classification signals — they must be accurate and grounded.

**Agent Actions:**

1. Identify all distinct areas likely related to the observed behavior based on the reproduction steps, logs, environment details from I0, and any context from the existing Jira card retrieved in I1. Limit the scope of this exploration to the current project directory.
2. Invoke a `codebase-explorer` sub-agent in **parallel** for each distinct area in this project, providing:
    - The target area to explore
    - The question: "Does code exist in this area that is intended to produce [expected behavior]? If it exists, is there evidence it is behaving incorrectly? If it does not exist, confirm its absence clearly."
    - The `work_item_id` recorded after I1 (e.g. `work_item-PROJ-123` or `work_item-issue-<slug>`). All findings the explorer streams to the graph will be linked to this node.
    - The bug description, observed behavior, expected behavior, reproduction steps, and any logs for context
3. Wait for all explorers to return one of `EXPLORATION COMPLETE`, `EXPLORATION INCOMPLETE`, or `EXPLORATION FAILED`. Each non-failed return includes a structured findings block in the text — use it as the resilient source of record alongside the graph. `INCOMPLETE` means partial findings are present; consider re-spawning for the same area if coverage matters.

> **POST-EXPLORATION ENRICHMENT:** Spawn the `area-mapper` sub-agent **in the background** (`run_in_background: true`) with the same `work_item_id`. The mapper crystallizes durable area knowledge from this run's graph into Serena project memory for future explorations. Do not wait for it — proceed immediately to step 4.
4. Call `read_graph` and walk the subgraph rooted at each `exploration` entity for this `work_item_id`. Surface any `open_question` entities. If any identifies a connection to another area not already explored, dispatch a follow-up `codebase-explorer` (passing the same `work_item_id`) before proceeding.
5. Synthesize the findings from the graph. For each area, record whether code exists for the expected behavior with specific evidence (cite `evidence` entities by their `file` and `line_range` observations).
6. Look for any recent changes (commits, deployments, config changes) in the affected areas that may have introduced a regression.
7. Identify relevant error handling paths, edge cases, or known fragile areas — these surface from `risk` entities and from `evidence` entities with `evidence_type: behavior`.
8. Flag any areas of uncertainty with explicit reasoning. Label items derived from observations marked `inferred: true` as `[INFERRED]`.

> **REQUIRED:** Present all of the following in the chat before proceeding:
> 
> - List of likely affected files / modules / services with rationale
> - Whether code exists for the expected behavior — with specific evidence
> - Any recent changes in the affected area that may be relevant
> - Relevant error handling paths or known fragile areas
> - Findings from log / exception / stack trace analysis (if available)
> - Areas of uncertainty flagged with reasoning

> **REQUIRED: Review the codebase analysis before presenting.** Verify every item is grounded in actual evidence. Label speculative entries as `[INFERRED]`. Do not present an unreviewed analysis.

> **APPROVAL GATE — FULL STOP.** Present the codebase analysis. User must confirm affected areas are correct and complete, and the finding on whether code exists is accurate. Do not proceed to I3 until confirmed.

---

### I3 — Clarifying Questions

**Objective:** Resolve remaining ambiguities needed to make a confident classification and define the path forward.

**Agent Actions:**

1. Review all output from I0, I1, and I2.
2. Generate clarifying questions organized by category:
    - **History** — Was this behavior ever present? Is there documentation, a spec, or a prior ticket that describes the expected behavior?
    - **Scope** — Is this isolated to a specific user, account, region, or configuration — or is it broader?
    - **Regression** — Was there a recent deployment, config change, or dependency update that may have introduced this?
    - **Intent** — Is the expected behavior something that was explicitly designed and specified, or is it something the user believes should exist?
    - **Logs / Evidence** — Are there additional error logs, stack traces, or monitoring alerts?
3. Mark each question as `[BLOCKING]` or `[NICE TO HAVE]`.
4. Present all questions in a **single batch** — do not ask one at a time.
5. Record all answers verbatim. Do not infer or invent answers.

> **USE KNOWLEDGE GRAPH:** After answers are confirmed, write each classification signal to the graph. Create a `classification_signal` node for each answered question with properties: `category` (history / scope / regression / intent / logs_evidence), `answer` (verbatim), and `points_to` (bug / missing_requirement / ambiguous). Link each node to the issue. I4A reads all `classification_signal` and `code_evidence` nodes to produce its verdict.

> **REQUIRED:** Present all BLOCKING questions answered and answers recorded, and remaining unanswered questions listed as open items.

> **APPROVAL GATE — FULL STOP.** Present all questions and recorded answers. User must confirm all blocking answers are accurate. Do not proceed to I4 until confirmed.

---

### I4 — Classification & Triage

**Objective:** Use all gathered context to classify the issue and determine the resolution path.

---

#### I4A — Classification

> **USE SEQUENTIAL THINKING:** Before producing the classification, invoke the `sequentialthinking` tool. Work through each signal in the table below explicitly — note what each signal points to, identify any contradictory signals, and stress-test the conclusion against the strongest counter-evidence. This is the most consequential decision in this workflow — a wrong answer here sends all subsequent work down the wrong path. Do not present the classification until every signal has been evaluated.

> **USE KNOWLEDGE GRAPH:** Read all `classification_signal` and `code_evidence` nodes. For each signal in the table below, find the corresponding node and record what it points to. Tally the signals, weight the strongest evidence (code_evidence is typically the most reliable signal), and produce the verdict. After the verdict is confirmed, write a `classification` node with properties: `verdict` (bug / missing_requirement / ambiguous) and `rationale`. This node is read by I5 to determine the resolution path.

Using all output from I0–I3, classify the issue against the following criteria:

|Signal|Points to Bug|Points to Missing Requirement|
|---|---|---|
|Prior behavior|This worked correctly before|This behavior has never existed|
|Code evidence|Code exists for this behavior but is defective|No code exists to support this behavior|
|Regression signals|Recent commit, deploy, or config change correlates with the problem|No regression signal found|
|Specification|Behavior is documented in a spec, design, or prior ticket|No specification or design describes this behavior|
|Logs / errors|Error logs or exceptions indicate a fault in existing logic|No errors — the system is working as designed, just not as desired|
|User framing|"This used to work" / "This broke"|"This should exist" / "We need this"|

**Classification outcomes:**

- **Bug** — The expected behavior was previously implemented and working, or code clearly exists for it but is defective.
- **Missing Requirement** — The expected behavior was never implemented. The software is behaving as designed; the design is incomplete.
- **Ambiguous** — Insufficient evidence to classify confidently. List the specific signals that are unclear and what additional information is needed.

> **If Ambiguous:** Present the ambiguous signals and missing information to the user. Ask the user to provide the missing information or to make a judgment call on the classification. Once the user provides additional input, re-evaluate the classification using the same signal table. Do not proceed to I5 until the classification resolves to Bug or Missing Requirement.

> **REQUIRED output:**
>
> - Classification: **Bug**, **Missing Requirement**, or **Ambiguous**, stated explicitly
> - Rationale: 3-5 sentences citing specific evidence from I0-I3
> - If Ambiguous: list exactly what additional information is needed and ask the user to resolve

---

#### I4B — Severity / Priority (Bug path only)

_Complete this section only if classification is Bug. Skip if Missing Requirement._

Assign a severity level:

|Severity|Criteria|
|---|---|
|**Critical**|System is down or data loss is occurring; no workaround; affects all or most users|
|**High**|Core functionality is broken or severely degraded; workaround difficult or unavailable|
|**Medium**|Non-core functionality is impacted or a workaround exists; affects a subset of users|
|**Low**|Minor issue with minimal user impact; workaround is easy; cosmetic or edge-case behavior|

> **REQUIRED output:** Severity (Critical / High / Medium / Low), rationale, and scope (isolated or broad).

---

> **APPROVAL GATE — FULL STOP.** Present the full I4 classification (and severity if Bug). User must confirm classification is correct, rationale accurately reflects the evidence, and severity is accurate (if Bug). Do not proceed to I5 until confirmed. The confirmed classification determines which I5 path is followed — do not deviate.

---

### I5 — Resolution

Follow the path matching the confirmed classification from I4.

---

#### I5 — Path A: Bug

**Objective:** Create or update the Jira Bug card with all gathered context and a pointer to the bug card execution skill.

**Agent Actions:**

1. Write the fix criteria: outcome-based acceptance criteria describing the state that must be true after the bug is fixed -- one criterion per discrete behavior to restore.
2. Construct the full issue description using the Bug Description Structure below. The description must contain only the structured bug context. Do not embed workflow instructions, skill-invocation text, or placeholder tokens.
3. Populate the following fields:

|Field|Source|
|---|---|
|Issue Type|Bug|
|Summary|Issue title from I0 (max 10 words, present-tense description of broken behavior)|
|Description|Assembled per Bug Description Structure below|
|Priority|Severity from I4B mapped to Jira priority|
|Labels|Derived from affected area + "bug"|
|Epic Link|Recommended epic (see below)|

    **Epic recommendation:** If an epic was already confirmed in I1, present it as the recommendation. If no epic was confirmed, search Jira for open epics in the same project that relate to the affected areas or the component where the bug was found. Recommend the most relevant epic to the user. Present the recommendation and ask the user to: (a) accept the suggested epic, (b) provide a different epic key, or (c) leave blank for no epic. Only set the Epic Link if the user accepts or provides a key. If the user leaves it blank, do not set an Epic Link.

    **API notes for non-standard fields:**
    - **Priority:** Set via `additional_fields`: `{"priority": {"name": "High"}}` (substituting the actual priority name: Critical, High, Medium, or Low).
    - **Labels:** Set via `additional_fields`: `{"labels": ["label1", "label2"]}` on `createJiraIssue`.
    - **Epic Link:** Set via `additional_fields`: `{"epicKey": "EPIC-KEY"}` on `createJiraIssue`. Do not use `createIssueLink` for epic links — that creates a lateral link, not an epic association. Only include this field if the user confirmed an epic.

4. **Update-or-create decision:**
    - **If an existing Jira card was provided in I0:** Update the card's description using `editJiraIssue` with the approved bug description. Do not create a new issue.
    - **If no existing card was provided:** Create a new Jira Bug issue using `createJiraIssue` with the approved bug description. Do not perform a follow-up description update solely to add execution instructions.

**Bug Description Structure:**

```
## Bug Details

**Summary:** [Issue title from I0]

## Overview
[1-2 sentences: what is broken and what the impact is]

## Observed Behavior
[Exact description -- from I0]

## Expected Behavior
[Exact description -- from I0]

## Steps to Reproduce
[Numbered steps, or "Intermittent -- no consistent reproduction steps. Approximate rate: X%"]

## Logs / Exceptions / Stack Traces
[Content from I0 and/or the existing Jira card, or "None provided."]

## Environment
- **Env tier:** [Production / Staging / Development / Other]
- **OS:** [name + version]
- **Browser:** [name + version, or "N/A"]
- **App version / build:** [version or build number, or "unknown"]
- **Other:** [region, account type, feature flags, or "none"]

## Severity
[Critical / High / Medium / Low -- from I4B]

## Scope
[Isolated or broad -- from I4B]

## Workaround
[Description, or "None identified"]

## Affected Areas
[Structured list from I2 codebase analysis. For each area:
file/module/service path, brief description of relevance, and risk level.]
- `[path]` -- [description] ([high/medium/low] risk)

## Root Cause (if known)
[Known or suspected root cause from I2 and I3. If unknown: "Unknown -- investigation required."]

## Fix Criteria
[Outcome-based criteria -- copy verbatim]

## Open Items
[Unresolved questions from I3 with owner and target resolution date, or
"None -- all blocking questions resolved."]
```

> **REQUIRED: Review the full issue description before presenting.** Verify all fields are populated, observed and expected behavior are precise, reproduction steps are exact or marked as intermittent, severity matches I4B, and fix criteria are independently verifiable.

> **APPROVAL GATE — FULL STOP.** Present the fully assembled Bug description. User must confirm content is accurate and ready before creating or updating the Jira issue.

**Post-creation:**

1. **Link related issues from I1:** For each related issue identified in I1, call `createIssueLink` with `link_type: "Relates to"`, `inward_issue_key` set to the new bug's key, and `outward_issue_key` set to the related issue's key. Do not attempt to set linked issues during `createJiraIssue` — that tool does not support it.

2. **Ask for additional links:** Ask: "Is there an existing Jira issue this bug should be linked to beyond the ones already linked? If yes, provide the issue key." If the user provides a key, call `getJiraIssue` to confirm it exists, then call `createIssueLink` with `link_type: "Relates to"` to create the link. Confirm success. If the user provides no key, skip this step.

3. The bug path cleanup happens in I6 after the durable Jira record is complete. Do not clear the session-scoped graph before that cleanup phase.

---

#### I5 — Path B: Missing Requirement

**Objective:** Transition into the Requirements Workflow (R0–R6), carrying forward all context gathered in this workflow so the user is not asked to repeat themselves.

**Agent Actions:**

1. Inform the user that the issue has been classified as a missing requirement and that you will now follow the Requirements Intake workflow to define and create the appropriate work item.
2. Read the Requirements Intake Workflow from the local skills directory for this project. When invoked from `.claude/skills/issue-intake/`, this is typically the sibling path `../requirements-intake/workflow.md`.
3. Carry forward the structured evidence already gathered in I0–I4. Reuse the existing `classification_signal`, codebase evidence, affected area, and related-issue context when pre-populating the requirements workflow so the user is not asked to repeat themselves.
4. Pre-populate the R0 context using information already gathered in I0–I4. Do not re-ask questions that have already been answered. Map the intake data as follows:

|R0 Field|Source|
|---|---|
|Work Type|Feature (default) — confirm with user if Tech Debt, Research, or Upkeep is more appropriate|
|Title or Name|Issue title from I0|
|Description / Problem Statement|Observed behavior + expected behavior from I0|
|Requested By / Identified By|Reported By from I0|
|Related Epic|Related Epic from I0 / I1|
|Codebase Hints|Affected areas from I2|
|Existing Jira Card|Existing card key from I0 (if provided)|

5. Present the pre-populated R0 summary to the user and confirm it before proceeding — this serves as the R0 approval gate.
6. After the user confirms the pre-populated R0 summary, perform the Requirements Intake R0 post-approval action by writing the `work_item` node to the knowledge graph using the confirmed work type and context. This completes the R0 graph initialization before continuing.
7. Resume the Requirements Workflow from **R1**, following all phases (R1 through R6) exactly as written. All R1–R6 execution rules, approval gates, and self-review requirements apply in full.
8. After the Jira issue has been created or updated at the end of R5, ask: "Is there an existing Jira issue this should be linked to? If yes, provide the issue key." If the user provides a key, call `getJiraIssue` to confirm it exists, then call `createIssueLink` with `link_type: "Relates to"` to create the link. Confirm success.
9. The missing-requirement path cleanup happens in I6 after the carried-over requirements workflow is complete. The Requirements Intake workflow clears the shared session-scoped graph at its cleanup phase; do not finish this path with any issue-intake state left in the graph.

> **APPROVAL GATE — FULL STOP.** Present the pre-populated R0 context summary. User must confirm all fields are accurate and Work Type is correct. Only proceed to R1 after this confirmation.

---

### I6 — Cleanup

**Objective:** Clear the session-scoped knowledge graph for the path that was actually taken, after explicit user confirmation. The bug path owns its own cleanup; the missing-requirement path delegates to Requirements Intake R6.

#### Bug path

1. **Enumerate.** Call `read_graph`. Identify every entity that should be deleted in this cleanup:
   - The intake `work_item` entity for this issue and every entity linked to it: `classification_signal`, `code_evidence`, `affected_area`, plus the explorer-written subgraph from I2 (`exploration`, `affected_file`, `evidence`, `pattern`, `integration_point`, `risk`, `open_question`).
   - Any upstream **implementation-discovery** state still in the graph: the `discovery_summary-<slug>` entity, the `work_item-discovery-<slug>` work item, the verification-round and first-round `exploration` subgraph linked to it (including any finding entities marked `superseded: true`, which must still be deleted — supersession marks them as non-canonical, not as already-removed), and any structured `open_question` entities reified at D5 (sources `d3_discussion` and `d4_verification`). These persist intentionally from a prior `/implementation-discovery` run; if discovery happened earlier in this session and the user opened a bug instead of running requirements-intake, I6 owns reaping the discovery state too.
   - Any other intake-scoped entities created during I0–I5 that link back to the work item.

2. **Present the cleanup plan to the user.** Build a short, structured summary in the chat:

   ```
   ## I6 Cleanup Plan (Bug path)

   The following session-scoped knowledge-graph entities will be deleted now that the Jira bug card is finalized:

   ### From this Issue Intake
   - work_item: <name>
   - classification_signal / code_evidence: <total count>
   - affected_area: <count>
   - exploration: <count>
   - affected_file / evidence / pattern / integration_point / risk / open_question: <total count>
   - <any other intake-scoped entities, listed by type and count>

   ### From upstream Implementation Discovery (if present)
   - discovery_summary-<slug>: <name, or "none">
   - work_item-discovery-<slug>: <name, or "none">
   - verification-round explorations: <count, or "none">

   Total entities to delete: <N>
   ```

   If the upstream-discovery section reports "none" across the board, state explicitly that no implementation-discovery state was found in the graph for this run.

3. > **APPROVAL GATE — FULL STOP.** Ask the user: **"Proceed with cleanup of these entities?"** Do not run `delete_entities` until the user explicitly confirms (e.g., "yes", "proceed", "go ahead"). On any negative or ambiguous response, do NOT delete. Instead, leave the graph untouched, note in the chat that cleanup was skipped at the user's request, and end this path — the entities will remain in the graph until the Claude Code session ends.

4. **Execute deletion.** On explicit confirmation, call `delete_entities` with the full list enumerated in step 1. After deletion, report a one-line confirmation in the chat: "Cleanup complete: <N> entities deleted."

5. Do not retain classification, evidence, affected-area, or upstream-discovery state after the durable Jira record is complete, except when the user explicitly declined cleanup at step 3.

#### Missing Requirement path

This path delegates cleanup to the carried-over Requirements Intake workflow's gated R6 cleanup, which sweeps both issue-intake state (`classification_signal`, `code_evidence`) and any upstream implementation-discovery state along with the requirements work item.

1. Confirm Requirements Intake completed through its R6 (gated) cleanup phase.
2. If R6 ran and the user confirmed cleanup, no further action is required from this path.
3. If R6 ran and the user declined cleanup at the R6 gate, surface that decision in the chat as the final state of this path so the user knows discovery and issue-intake entities remain in the graph until the Claude Code session ends. Do not call `delete_entities` from this path; the gate decision belongs to R6.
4. If R6 did not run for any reason (Requirements Intake aborted before R6), call `read_graph`, enumerate the issue-intake-scoped entities (`work_item`, `classification_signal`, `code_evidence`, plus any I2 exploration subgraph still linked), and apply the same gated cleanup pattern as the Bug path above to those entities only — do not touch implementation-discovery or requirements work-item entities, since those remain owned by Requirements Intake R6.

---

## Completion Criteria

This workflow is complete when **all** of the following are true:

- All 7 phases executed in sequence (I0–I6)
- All approval gates explicitly confirmed in the chat
- All self-review checks passed before presenting output
- **Bug path:** Jira Bug updated or created, issue linking offered, and no workflow or skill-invocation instructions were embedded in the description
- **Missing Requirement path:** R0 context confirmed, R0 knowledge-graph initialization completed, Requirements Workflow completed through R5, issue linking offered
- I6 cleanup completed for the selected path: either the user confirmed cleanup at the I6 gate (Bug path) or the carried-over Requirements Intake R6 gate (Missing Requirement path) and the listed entities — including any upstream implementation-discovery state — were deleted, or the user explicitly declined cleanup at the gate
