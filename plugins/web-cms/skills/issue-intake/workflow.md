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

**CLARIFICATION RULE:** Do not assume anything. If required information is missing, ambiguous, conflicting, or underspecified, stop and use `AskUserQuestion` to ask the user for clarification before proceeding.

**FILE MEMORY SCOPE:** This workflow stores classification state in a per-work-item file-memory directory. `$MEM/work-item.md` is the root (issue title, observed/expected behavior, and the `## Affected Areas` section built in I2); `$MEM/explorations/*.md` hold I2 codebase findings; `$MEM/signals.md` holds the code-evidence, classification signals, and final classification verdict; `$MEM/related-cards.md` holds relevant related Jira cards from I1. Compute `MEM` once with the recipe in `file-memory-protocol.md` §1 (`<work-item-key>` = the Jira key, or `issue-<slug>`); the directory is created after the I1 approval gate. All file content must be fully materialized into the Jira card (Bug path) or carried into requirements-intake (Missing Requirement path) before the session ends. See `file-memory-protocol.md` for schemas and the checkpoint/compaction contract.

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

**SERENA PROJECT ACTIVATION:** Before I0, check Serena's project-activation message (emitted on connect via `--project-from-cwd`); if it reports that onboarding has not been performed, call `onboarding` to scope Serena's language server to the current project directory. Serena's symbol tools (`find_symbol`, `find_referencing_symbols`, `get_symbols_overview`, `search_for_pattern`) and any symbol-aware operations invoked by the `codebase-explorer` agent depend on this being done. Do this once at the start of the workflow; do not repeat it between phases.

**TASK TRACKING:** Always use task tracking (`TaskCreate`/`TaskUpdate`) so progress is visible throughout. Create one task per phase at the start of the workflow. Mark each task `in_progress` when starting the phase and `completed` when the phase is done:

- I0 — Intake
- I1 — Jira Context Review
- I2 — Codebase Analysis
- I3 — Clarifying Questions
- I4 — Classification & Triage
- I5 — Resolution
- I6 — Cleanup

**CHECKPOINT & COMPACTION CONTRACT:** This workflow records position in a single `$MEM/checkpoint.md` file (full schema and contract in `file-memory-protocol.md` §4).

**Per-phase checkpoint — after EVERY phase (I0–I5), automatically, with no chat output and no `/compact` prompt.** Atomically overwrite `$MEM/checkpoint.md` (`Write` to `checkpoint.md.tmp`, then `mv` over `checkpoint.md`) with `checkpoint_type: phase`, the just-completed `phase`, the upcoming `next_phase`, the `references` list, `## Decisions`, and `## Open items`. (Before `$MEM` exists — I0 — there is no checkpoint to write; the first checkpoint is written after I1 bootstraps `$MEM`.)

**Compaction gate (I4) — additionally prompts the user to `/compact`.** Do the per-phase write but with `checkpoint_type: gate`, recording the `classification` verdict (Bug / Missing Requirement) and `severity` (Bug only) in `## Decisions`, then: (1) wait for any background `area-mapper` to finish; (2) emit the Phase Summary block (§4(b)) — phase + skill, work item key, classification verdict, one-line decisions, verbatim approval condition, `next_phase`, the checkpoint file path, and the resume contract; (3) end the turn with the literal line **"Run `/compact` now, then type `continue` to resume."** Do NOT call `AskUserQuestion` at a gate.

**Universal resume rule — on ANY resume, before doing anything else:** `Read $MEM/checkpoint.md` → `Read` every file in its `references` (`signals.md`, `work-item.md`, `explorations/*.md`) → **re-read the `next_phase` section of this `workflow.md`** (any phase asking clarifying/structured questions MUST use `AskUserQuestion`) → continue at `next_phase`. If `$MEM` is absent, restart the affected phase from prior chat. Approval gates stay chat-scoped — never assume a pending approval was granted.

---

### I0 — Intake

**Objective:** Greet the user and gather all information about the unexpected or missing behavior through natural conversation. Do not assume or imply whether this is a bug or a missing requirement — remain neutral until I4.

**If called with pre-populated context (non-empty $ARGUMENTS):** Skip the cold-start introduction. Present the pre-populated fields (observed behavior, expected behavior, related Jira key) as a structured summary. Use `AskUserQuestion` (Header: `Pre-filled Data`, Question: `I've pre-populated these fields from the parent workflow. Are they accurate?`, Options: `Confirmed — continue with these details (Recommended)`, `Needs correction — I'll provide the right details`) before proceeding to the remaining I0 questions. Only ask about fields that were not pre-populated.

**Agent Actions:**

1. Introduce yourself and briefly explain what this workflow will do and what to expect (phases, classification, end result). Skip this step if called with pre-populated context — the user is already in context from the parent workflow.
    
2. Gather context in this order. For closed-enum questions, use the specific options below. For remaining open-ended questions, provide 2–3 reasonable options (Other is always available for typed input).

   **a. Issue title (via `AskUserQuestion`, open-ended):** accept any level of specificity.

   **b. Observed and expected behavior — ask conversationally, not via `AskUserQuestion`.**  
   The `AskUserQuestion` free-text field is cramped and discourages detail; a conversational prompt gives the user the full prompt input to write as much as they need. Send this message, then **end your turn and wait** for the user's reply:

   *"Describe what happened and what you expected instead. Walk me through the full picture — what you were doing, what the system did, what it should have done, and any other context that would help explain the difference. The more detail you include, the better the investigation will go."*

   **c. Sufficiency check.** Before continuing, assess whether the observed/expected gap is clearly described. A useful description identifies a specific behavior that occurred, a specific expectation that wasn't met, and at least some context. If the observed or expected behavior is absent or too vague to investigate (e.g., "it's broken" with no detail), ask 1–2 targeted follow-up questions to close the gap. If the description is already sufficient, proceed immediately.

   **d. Has this ever worked (via `AskUserQuestion`):** `AskUserQuestion` (Header: `Prior Behavior`, Question: `Has this ever worked correctly before, to your knowledge?`, Options: `Yes — it used to work`, `No — it has never worked`, `Unknown`)

   **e. Remaining structured questions (via `AskUserQuestion`, one call per question):**

   **Reproduction:**
    
    - Can it be reproduced — `AskUserQuestion` (Header: `Reproducible?`, Question: `Can you reliably reproduce this issue?`, Options: `Yes — I can reproduce it consistently`, `Intermittent — it happens sometimes`, `No — I cannot reproduce it`)
    - Reproduction rate — `AskUserQuestion` (Header: `Rate`, Question: `How often does it occur?`, Options: `Every time (Recommended for consistent bugs)`, `Intermittently — roughly [frequency]`, `Unknown`) — only ask if intermittent
    - Conditions — open-ended: what makes it more or less likely
    - Logs available — `AskUserQuestion` (Header: `Logs`, Question: `Are there relevant logs, error messages, exceptions, or stack traces available?`, Options: `Yes — I'll share them`, `No logs available`)
    
    **Environment:**
    
    - Environment tier — `AskUserQuestion` (Header: `Environment`, Question: `What environment did this occur in?`, Options: `Production`, `Staging`, `Development`, `Other`)
    - OS and version — open-ended
    - Browser and version — `AskUserQuestion` (Header: `Browser`, Question: `Is this browser-related?`, Options: `Yes — I'll specify the browser and version`, `Not applicable — no browser involved`)
    - App version / build — open-ended
    - Other environment details — open-ended (region, account type, feature flags, etc.)
    
    **Impact & context:**
    
    - User / system impact — open-ended
    - Workaround — `AskUserQuestion` (Header: `Workaround`, Question: `Is there a workaround available?`, Options: `Yes — I'll describe it`, `No — there is no workaround`, `Unknown`)
    - Related issue / epic — `AskUserQuestion` (Header: `Related Jira`, Question: `Is there a related Jira Epic or issue this should be linked to?`, Options: `Yes — I'll provide the key`, `No`)
    - Existing card — **Before asking**, run `git rev-parse --abbrev-ref HEAD` and apply a regex match for `[A-Z]+-[0-9]+` against the branch name. If a candidate key is found: `AskUserQuestion` (Header: `Existing Card`, Question: `Has a Jira card already been created for this issue?`, Options: `Yes, <extracted key>` (description: "Use <extracted key> as the existing Jira card for this issue") / `Use a different key` (description: "Type the correct issue key in the Other field") / `No`). If no candidate is found: `AskUserQuestion` (Header: `Existing Card`, Question: `Has a Jira card already been created for this issue?`, Options: `Yes — I'll provide the key`, `No`).
3. After all questions are answered, summarize the gathered context back to the user in a clear, structured format.
    

> **REQUIRED:** The following context must be confirmed before proceeding:
> 
> - Issue Title
> - Observed Behavior (capture in full — do not summarize or truncate the user's input)
> - Expected Behavior (capture in full — do not summarize or truncate the user's input)
> - Previously Worked (yes / no / unknown)
> - Reproduction Steps (or "intermittent — no consistent repro steps")
> - Reproduction Rate (always / intermittent / unknown)
> - Logs / Exceptions / Stack Traces (content, or explicitly "none available")
> - Environment: env tier, OS + version, browser + version (if applicable), app version (if known)
> - User / System Impact
> - Workaround (description, or explicitly "none")
> - Related Issue or Epic (Jira key, or explicitly "none")
> - Existing Jira Card (issue key, or explicitly "none")

> **APPROVAL GATE — FULL STOP.** Present the gathered context as a structured summary. Use `AskUserQuestion` (Header: `I0 Approval`, Question: `Are all fields accurate and nothing is missing?`, Options: `Approve and proceed (Recommended)`, `Request changes`). Do not proceed to I1 until the user approves.

---

### I1 — Jira Context Review

**Objective:** Check for duplicate or related issues and anchor the issue in the current project structure.

**Agent Actions:**

1. If an Existing Jira Card key was provided in I0, retrieve that issue immediately. Read its full description, summary, any context already captured (labels, epic link, linked issues, severity, reproduction steps, environment details, and comment history). Surface all of this content — it will be used to enrich the final Bug description in I5 Path A.
2. Search Jira for existing bugs, tasks, or issues that match or closely overlap with the observed behavior. **Related-card capture:** for each candidate that passes the relevance bar (materially informs the investigation, root cause, or fix — not merely a possible duplicate to flag), call `jira_get_issue` to read its description and append it to `$MEM/related-cards.md` (schema §3.7) with `key`, `title`, `status`, `relationship` (overlaps | prior-art | same-area | superseded-by), a one-line `why_relevant`, and a concise excerpt of the pertinent section. Log candidates that fail the bar in the chat rather than storing them. (Create `$MEM` first per the bootstrap step below if it does not yet exist.)
3. Search for any known issues, incidents, or investigations already open in the same area; capture any materially relevant one into `related-cards.md` the same way.
4. If a Related Issue or Epic was provided in I0, retrieve its description and status.

> **REQUIRED:** Present all of the following in the chat before proceeding:
> 
> - If an existing card was provided: its full summary, description, and any context already captured
> - List of potentially duplicate or related issues: key, summary, status
> - Explicit confirmation that no duplicate issue is already open
> - Summary of related Epic or issue (if applicable)

> **APPROVAL GATE — FULL STOP.** Present the Jira context summary. Use `AskUserQuestion` (Header: `I1 Approval`, Question: `Is the Jira context correct? Is the existing card (if any) right, is there no duplicate, and is the related Epic (if any) correct?`, Options: `Approve and proceed (Recommended)`, `Request changes`). Do not proceed to I2 until the user approves.

> **BOOTSTRAP FILE MEMORY:** After the I1 approval gate is confirmed, compute `MEM` (recipe §1) where `<work-item-key>` is the existing Jira issue key (if provided in I0) or a normalized slug of the issue title prefixed with `issue-` (e.g. `issue-checkout-button-disabled`). `mkdir -p "$MEM/explorations"` and `Write $MEM/work-item.md` (schema §3.1) with `work_type: bug` (provisional — confirmed at I4), `jira_key` (or null), `title`, `status: in_progress`, `phase: I1`, `skill: issue-intake`, and the observed/expected behavior under `## Description`. (If `related-cards.md` was already written during I1 steps 2–3, it lives under this same `$MEM`.) The `MEM` path (as `memory_dir`) is passed to every `codebase-explorer` call in I2.

---

### I2 — Codebase Analysis

**Objective:** Determine what the codebase currently does in the affected area — whether logic exists for the expected behavior or not. This is the primary input to classification in I4.

**DISCOVERY PRE-CHECK:** Before spawning codebase-explorer agents, `Glob $MEMROOT/discovery-*/summary.md` (compute `$MEMROOT` via the recipe in `file-memory-protocol.md` §1) and `Read` each `summary.md` frontmatter. A prior `/implementation-discovery` run may already have mapped the area this issue touches.
1. **If one or more are present:** briefly describe each by `topic_slug` and `chosen_approach`, then use `AskUserQuestion` (Header: `Discovery Reuse`, Question: `A prior implementation-discovery session explored related code. Use its findings to seed this investigation?`, Options: `Yes — reuse the discovery findings`, `No — investigate fresh`). If multiple exist, list them and let the user pick one or decline.
2. **If the user reuses one:** set `discovery_confirmed: true` in that `discovery-<slug>/summary.md` frontmatter. Copy its `discovery-<slug>/explorations/*.md` into `$MEM/explorations/` (Bash `cp`), skipping any file/finding marked superseded. Seed the `## Affected Areas` (in `work-item.md`) and the I4 code-evidence input from the discovery's `affected_areas` and `## Synthesis (chosen)` — treat these as a starting map of *where the expected behavior would live*, not a conclusion about the defect. Then run Agent Actions steps 1–8 focused on confirming whether the described code actually exists and behaves correctly, rather than re-exploring from scratch. Discovery is approach-oriented, so still verify live behavior against the observed/expected gap before concluding in I4.
3. **If the user declines (or none exist):** proceed with normal investigation.

> **USE SEQUENTIAL THINKING:** Before presenting the codebase analysis, invoke the `sequentialthinking` tool. Based on the explorer findings, systematically evaluate the evidence of whether code exists for the expected behavior. A false negative here — concluding code doesn't exist because it wasn't found quickly — is the most common source of misclassification in I4. Work through the evidence, identify any gaps that need further investigation, and resolve them before concluding. Do not present the analysis until the reasoning is complete.

> **WRITE Affected Areas + signals.md:** After synthesizing the explorer findings, write investigation conclusions to files. Roll up the explorations' `affected_files` into a `## Affected Areas` section in `$MEM/work-item.md` (one entry per file / module / service identified, with risk). Then `Write $MEM/signals.md` with a `code_evidence` block in frontmatter: `code_exists_for_behavior` (true / false / uncertain), `evidence` (specific file names, function names, or confirmed absence — pulled from the explorations' `evidence` entries), and `inferred` (true / false). I4A reads `signals.md` as a primary classification signal — it must be accurate and grounded.

**Agent Actions:**

1. Identify all distinct areas likely related to the observed behavior based on the reproduction steps, logs, environment details from I0, and any context from the existing Jira card retrieved in I1. Limit the scope of this exploration to the current project directory.
2. Invoke a `codebase-explorer` sub-agent in **parallel** for each distinct area in this project, providing:
    - The target area to explore
    - The question: "Does code exist in this area that is intended to produce [expected behavior]? If it exists, is there evidence it is behaving incorrectly? If it does not exist, confirm its absence clearly."
    - The `memory_dir` (`$MEM`) and a normalized `area_slug`. The explorer writes its findings to `$MEM/explorations/<area_slug>.md`.
    - The bug description, observed behavior, expected behavior, reproduction steps, and any logs for context
3. Wait for all explorers to return. Each non-failed return contains a `File:` line with the exploration file name. `INCOMPLETE` means partial findings are present; consider re-spawning for the same area if coverage matters. `FAILED` means no file was written — re-spawn that explorer before proceeding.

> **POST-EXPLORATION ENRICHMENT:** Spawn the `area-mapper` sub-agent **in the background** (`run_in_background: true`) with the same `memory_dir` (`$MEM`). The mapper crystallizes durable area knowledge from this run's exploration files into Serena project memory for future explorations. Do not wait for it — proceed immediately to step 4.
4. `Read` each `$MEM/explorations/<area_slug>.md` from the returns. If any file is missing or empty, re-spawn that explorer rather than treating missing data as confirmed. Surface any `open_questions` entries. If any identifies a connection to another area not already explored, dispatch a follow-up `codebase-explorer` (passing the same `memory_dir`) before proceeding.
5. Synthesize the findings from the exploration files. For each area, record whether code exists for the expected behavior with specific evidence (cite `evidence` entries by their `file` and `line_range`).
6. Look for any recent changes (commits, deployments, config changes) in the affected areas that may have introduced a regression.
7. Identify relevant error handling paths, edge cases, or known fragile areas — these surface from `risks` and from `evidence` entries with `evidence_type: behavior`.
8. Flag any areas of uncertainty with explicit reasoning. Label items derived from entries marked `inferred: true` as `[INFERRED]`.

> **REQUIRED:** Present all of the following in the chat before proceeding:
> 
> - List of likely affected files / modules / services with rationale
> - Whether code exists for the expected behavior — with specific evidence
> - Any recent changes in the affected area that may be relevant
> - Relevant error handling paths or known fragile areas
> - Findings from log / exception / stack trace analysis (if available)
> - Areas of uncertainty flagged with reasoning

> **REQUIRED: Review the codebase analysis before presenting.** Verify every item is grounded in actual evidence. Label speculative entries as `[INFERRED]`. Do not present an unreviewed analysis.

> **APPROVAL GATE — FULL STOP.** Present the codebase analysis. Use `AskUserQuestion` (Header: `I2 Approval`, Question: `Are the affected areas correct and complete, and is the finding on whether code exists accurate?`, Options: `Approve and proceed (Recommended)`, `Request changes`). Do not proceed to I3 until the user approves.

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
4. Ask each question using a separate `AskUserQuestion` call in sequence — one question per call. Include the `[BLOCKING]` or `[NICE TO HAVE]` tag in the question text. For open-ended questions, use two options: `Provide answer` (description: "Type your response using the Other input field") and, for non-blocking questions only, `Skip` (description: "Skip this non-blocking question"). For closed-enum questions, use specific options.
5. Record all answers verbatim. Do not infer or invent answers.

> **WRITE signals.md:** After answers are confirmed, append each classification signal to `$MEM/signals.md` as a `classification_signals[]` entry with `category` (history / scope / regression / intent / logs_evidence), `answer` (verbatim), and `points_to` (bug / missing_requirement / ambiguous). I4A reads all `classification_signals` plus the `code_evidence` block to produce its verdict.

> **REQUIRED:** Present all BLOCKING questions answered and answers recorded, and remaining unanswered questions listed as open items.

> **APPROVAL GATE — FULL STOP.** Present all questions and recorded answers. Use `AskUserQuestion` (Header: `I3 Approval`, Question: `Are all blocking answers accurate?`, Options: `Approve and proceed (Recommended)`, `Request changes`). Do not proceed to I4 until the user approves.

---

### I4 — Classification & Triage

**Objective:** Use all gathered context to classify the issue and determine the resolution path.

---

#### I4A — Classification

> **USE SEQUENTIAL THINKING:** Before producing the classification, invoke the `sequentialthinking` tool. Work through each signal in the table below explicitly — note what each signal points to, identify any contradictory signals, and stress-test the conclusion against the strongest counter-evidence. This is the most consequential decision in this workflow — a wrong answer here sends all subsequent work down the wrong path. Do not present the classification until every signal has been evaluated.

> **THINK HARD:** Before committing to the classification verdict, think hard about the strongest piece of counter-evidence — the signal that most strongly contradicts your tentative conclusion. If you cannot articulate why that counter-signal is outweighed, the classification is not ready. A Bug sent down the Missing Requirement path loses its regression test; a Missing Requirement sent down the Bug path creates a broken fix that cannot reproduce.

> **READ + WRITE signals.md:** Read `$MEM/signals.md` — all `classification_signals` and the `code_evidence` block. For each signal in the table below, record what it points to. Tally the signals, weight the strongest evidence (`code_evidence` is typically the most reliable signal), and produce the verdict. After the verdict is confirmed, set `classification: { verdict: bug|missing_requirement|ambiguous, rationale: <text> }` in `signals.md` frontmatter. I5 reads this to determine the resolution path.

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

> **If Ambiguous:** Present the ambiguous signals and missing information. Use `AskUserQuestion` to ask for missing information or a judgment call — one question per call. For classification judgment calls, use (Header: `Classification`, Question: `Based on the available evidence, which classification best fits?`, Options: `Bug — existing code is broken`, `Missing Requirement — the behavior was never implemented`). Once additional input is provided, re-evaluate the classification using the same signal table. Do not proceed to I5 until the classification resolves to Bug or Missing Requirement.

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

> **APPROVAL GATE — FULL STOP.** Present the full I4 classification (and severity if Bug). Use `AskUserQuestion` (Header: `I4 Approval`, Question: `Is the classification correct, does the rationale accurately reflect the evidence, and is the severity accurate (if Bug)?`, Options: `Approve and proceed (Recommended)`, `Request changes`). Do not proceed to I5 until the user approves. The confirmed classification determines which I5 path is followed — do not deviate.

> **COMPACTION GATE — I4:** Once I4 approval is confirmed, follow the Checkpoint & Compaction Contract above (gate path). Write `checkpoint.md` with `phase: I4`, `next_phase: I5`, `checkpoint_type: gate`, `references: [signals.md, work-item.md, explorations/*.md]`; `## Decisions`: classification verdict (Bug or Missing Requirement) and severity (Bug only); `approval_condition`: verbatim user phrasing. Emit the Phase Summary block and instruct the user to run `/compact` before proceeding to I5.

---

### I5 — Resolution

Follow the path matching the confirmed classification from I4.

---

#### I5 — Path A: Bug

**Objective:** Create or update the Jira Bug card with all gathered context and a pointer to the bug card execution skill.

> **FULL CONTEXT LOAD:** `Glob $MEM` and `Read` `work-item.md` (`## Affected Areas`), `signals.md` (classification + code evidence), `related-cards.md`, and every `explorations/*.md` before assembling the Bug card.

**Agent Actions:**

1. Write the fix criteria: outcome-based acceptance criteria describing the state that must be true after the bug is fixed -- one criterion per discrete behavior to restore.
2. **Assemble the Patterns & Code References section** by reading `$MEM/explorations/*.md`: collect the `patterns`, `evidence` (file/line_range/claim), and `integration_points` entries relevant to the fix. For the 1–3 most important, use `Read` to extract a ≤ ~15-line snippet from the referenced range, each prefixed with a `// path:line_range` comment. If nothing beyond the Affected Areas applies, write "None — none beyond the affected areas above."
3. Construct the full issue description using the Bug Description Structure below. The description must contain only the structured bug context. Do not embed workflow instructions, skill-invocation text, or placeholder tokens.
4. Populate the following fields:

|Field|Source|
|---|---|
|Project|User-confirmed at the Project selection gate below|
|Issue Type|Bug|
|Summary|Issue title from I0 (max 10 words, present-tense description of broken behavior)|
|Description|Assembled per Bug Description Structure below|
|Priority|Severity from I4B mapped to Jira priority|
|Labels|Derived from affected area + "bug"|
|Epic Link|Recommended epic (see below)|

    **Project selection (new-card path only — skip when updating an existing card, whose project is fixed by its key):** Never guess the Jira project; an educated guess that is usually right still creates cards in the wrong space when it isn't. Before any other field confirmation:

    1. Determine the recommended project key from the strongest evidence available: the project of the related work item this issue was reported against (e.g. a testing-found bug passed a `Related to: [PROJ-KEY]` reference), the project of material related cards in `$MEM/related-cards.md` (I1), or the project of an epic confirmed in I1. Call `jira_get_all_projects` to validate the candidate key and identify plausible alternates. If no evidence points to a project, work from that list alone.
    2. Use `AskUserQuestion` (Header: `Jira Project`, Question: `Which Jira project should this bug be created in?`, Options: `<KEY> — <project name> (Recommended)` first with a description naming the specific evidence, then up to two alternates with their evidence; the user can type any other key via the auto-injected Other input). When there is no evidence-backed recommendation, present the most plausible projects from the list without a `(Recommended)` tag and say so plainly — do not manufacture a recommendation.
    3. Record the confirmed key in `$MEM/work-item.md` frontmatter as `jira_project: <KEY>`. On resume, if `jira_project` is already recorded, use it without re-asking. Pass it as the `project_key` on `jira_create_issue` — never a key the user did not confirm.

    **Epic recommendation:** If an epic was already confirmed in I1, present it as the recommendation. If no epic was confirmed, search Jira for open epics in the same project that relate to the affected areas or the component where the bug was found. Use `AskUserQuestion` to confirm the epic (Header: `Epic Link`, Question: `Which epic should this bug be linked to?`, Options: `Use suggested epic: <KEY> (Recommended)` — link to the suggested epic, `Provide a different epic key` — type your preferred key using the Other input, `No epic` — leave this bug unlinked to an epic). Only set the Epic Link if the user selects the suggested epic or provides a different key via Other.

    **API notes for non-standard fields:**
    - **Priority:** Set via `additional_fields`: `{"priority": {"name": "High"}}` (substituting the actual priority name: Critical, High, Medium, or Low).
    - **Labels:** Set via `additional_fields`: `{"labels": ["label1", "label2"]}` on `jira_create_issue`.
    - **Epic Link:** Set via `additional_fields`: `{"epicKey": "EPIC-KEY"}` on `jira_create_issue`. Do not use `jira_create_issue_link` for epic links — that creates a lateral link, not an epic association. Only include this field if the user confirmed an epic.

5. **Update-or-create decision:**
    - **If an existing Jira card was provided in I0:** Update the card's description using `jira_update_issue` with the approved bug description. Do not create a new issue.
    - **If no existing card was provided:** Create a new Jira Bug issue using `jira_create_issue` with the approved bug description. Do not perform a follow-up description update solely to add execution instructions.

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
[Structured list from `work-item.md`'s `## Affected Areas` (built in I2). For each area:
file/module/service path, brief description of relevance, and risk level.]
- `[path]` -- [description] ([high/medium/low] risk)

## Root Cause (if known)
[Known or suspected root cause from I2 and I3. If unknown: "Unknown -- investigation required."]

## Patterns & Code References
[Relevant code paths and conventions for the fix, from the I2 `$MEM/explorations/*.md`
`patterns`/`evidence`/`integration_points` entries. References are durable; snippets are illustrative
and may drift — the referenced file is source of truth. "None — none beyond the affected areas above." if N/A.]
**Patterns to follow:**
- **[name]** — [description]. Canonical example: `[path:line]`.
**Code references:**
- `[path:line_range]` — [what to mirror / where the buggy path lives]
**Illustrative snippets (1–3 most important only):** each in a fenced code block, prefixed
with a `// [path:line_range]` comment, ≤ ~15 lines, read from the referenced range.
**Integration points:**
- [with_area] via [interface] — [description] ([direction]), or "None identified."

## Fix Criteria
[Outcome-based criteria -- copy verbatim]

## Open Items
[Unresolved questions from I3 with owner and target resolution date, or
"None -- all blocking questions resolved."]
```

> **REQUIRED: Review the full issue description before presenting.** Verify all fields are populated, observed and expected behavior are precise, reproduction steps are exact or marked as intermittent, severity matches I4B, and fix criteria are independently verifiable.

> **APPROVAL GATE — FULL STOP.** Present the fully assembled Bug description. Use `AskUserQuestion` (Header: `I5A Approval`, Question: `Is the bug description accurate and ready to be created or updated in Jira?`, Options: `Approve and create / update (Recommended)`, `Request changes`). Do not create or update the Jira issue until the user approves.

**Post-creation:**

1. **Link related issues from I1:** For each related issue identified in I1, call `jira_create_issue_link` with `link_type: "Relates to"`, `inward_issue_key` set to the new bug's key, and `outward_issue_key` set to the related issue's key. Do not attempt to set linked issues during `jira_create_issue` — that tool does not support it.

2. **Ask for additional links:** Use `AskUserQuestion` (Header: `Additional Links`, Question: `Is there an existing Jira issue this bug should be linked to beyond the ones already linked?`, Options: `Yes — I'll provide the issue key` — type the key using the Other input, `No — no additional links needed`). If the user provides a key, call `jira_get_issue` to confirm it exists, then call `jira_create_issue_link` with `link_type: "Relates to"` to create the link. Confirm success.

3. The bug path cleanup happens in I6 after the durable Jira record is complete. Do not remove the file-memory directory before that cleanup phase.

---

#### I5 — Path B: Missing Requirement

**Objective:** Transition into the Requirements Workflow (R0–R6), carrying forward all context gathered in this workflow so the user is not asked to repeat themselves.

**Agent Actions:**

1. Inform the user that the issue has been classified as a missing requirement and that you will now follow the Requirements Intake workflow to define and create the appropriate work item.
2. Read the Requirements Intake Workflow from the local skills directory for this project. When invoked from `.claude/skills/issue-intake/`, this is typically the sibling path `../requirements-intake/workflow.md`.
3. Carry forward the structured evidence already gathered in I0–I4 by **reusing issue-intake's existing `$MEM` as the requirements work-item directory** — its `explorations/*.md`, `related-cards.md`, `signals.md`, and `work-item.md` are already in place, so R2/R4 read them directly. Do not bootstrap a second directory and do not re-ask answered questions.
4. Pre-populate the R0 context using information already gathered in I0–I4. Do not re-ask questions that have already been answered. Map the intake data as follows:

|R0 Field|Source|
|---|---|
|Work Type|Feature (default) — use `AskUserQuestion` (Header: `Work Type`, Question: `What type of work is this? Feature is the default for missing requirements.`, Options: `Feature (Recommended)` — new capability or user-facing behavior, `Maintenance` — improving, fixing, updating, or maintaining existing code (tech debt, refactors, dependency updates, compliance, upkeep))|
|Title or Name|Issue title from I0|
|Description / Problem Statement|Observed behavior + expected behavior from I0|
|Related Epic|Related Epic from I0 / I1|
|Codebase Hints|Affected areas from I2|
|Existing Jira Card|Existing card key from I0 (if provided)|

5. Present the pre-populated R0 summary to the user and confirm it before proceeding — this serves as the R0 approval gate.
6. After the user confirms the pre-populated R0 summary, perform the Requirements Intake R0 post-approval action against issue-intake's existing `$MEM`: update `work-item.md` with the confirmed work type and requirements context (do not create a second directory). This completes the R0 initialization before continuing.
7. Resume the Requirements Workflow from **R1**, following all phases (R1 through R6) exactly as written. All R1–R6 execution rules, approval gates, and self-review requirements apply in full.
8. After the Jira issue has been created or updated at the end of R5, use `AskUserQuestion` (Header: `Additional Links`, Question: `Is there an existing Jira issue this should be linked to?`, Options: `Yes — I'll provide the issue key` — type the key using the Other input, `No — no additional links needed`). If the user provides a key, call `jira_get_issue` to confirm it exists, then call `jira_create_issue_link` with `link_type: "Relates to"` to create the link. Confirm success.
9. The missing-requirement path cleanup happens in I6 after the carried-over requirements workflow is complete. The Requirements Intake workflow removes the shared file-memory directory at its cleanup phase; do not finish this path with any issue-intake state left on disk.

> **APPROVAL GATE — FULL STOP.** Present the pre-populated R0 context summary. Use `AskUserQuestion` (Header: `I5B Approval`, Question: `Are all fields accurate and is the Work Type correct?`, Options: `Approve and proceed (Recommended)`, `Request changes`). Only proceed to R1 after the user approves.

---

### I6 — Cleanup

**Objective:** Remove the file-memory directory for the path that was actually taken, after explicit user confirmation. The bug path owns its own cleanup; the missing-requirement path delegates to Requirements Intake R6.

#### Bug path

1. **Enumerate.** List the directories that will be removed:
   - `$MEM` — this issue's work-item directory (`work-item.md`, `signals.md`, `related-cards.md`, `explorations/*.md`, `checkpoint.md`).
   - Any upstream **implementation-discovery** directory reused at I2: `$MEMROOT/discovery-<slug>/`. If discovery happened earlier in this session and the user opened a bug instead of running requirements-intake, I6 owns reaping it.

2. **Present the cleanup plan to the user:**

   ```
   ## I6 Cleanup Plan (Bug path)

   The following file-memory directories will be removed now that the Jira bug card is finalized:

   - This issue intake: web-cms-memory/<work-item-key>/  (<file count> files)
   - Upstream implementation discovery (if reused): web-cms-memory/discovery-<slug>/  (or "none — no discovery reused")
   ```

   If no implementation-discovery directory was reused, state that explicitly.

3. > **APPROVAL GATE — FULL STOP.** Use `AskUserQuestion` (Header: `I6 Cleanup`, Question: `Proceed with cleanup of these directories?`, Options: `Proceed with cleanup (Recommended)` — remove the listed file-memory directories, `Skip cleanup` — leave them on disk until removed). Do not run `rm -rf` until the user selects Proceed.

4. **Execute deletion.** On explicit confirmation, `rm -rf "$MEM"` and (if a discovery was reused) `rm -rf "$MEMROOT/discovery-<slug>"` (Bash). Each removal is atomic. Report a one-line confirmation: "Cleanup complete: removed <N> directories."

5. Do not retain classification, evidence, affected-area, or upstream-discovery state on disk after the durable Jira record is complete, except when the user explicitly declined cleanup at step 3.

#### Missing Requirement path

This path delegates cleanup to the carried-over Requirements Intake workflow's gated R6 cleanup. Because Path B **reuses issue-intake's `$MEM`** as the requirements work-item directory, that single directory (holding `signals.md`, `related-cards.md`, `explorations/*.md`, and `work-item.md`) plus any upstream implementation-discovery directory are removed by R6.

1. Confirm Requirements Intake completed through its R6 (gated) cleanup phase.
2. If R6 ran and the user confirmed cleanup, no further action is required from this path.
3. If R6 ran and the user declined cleanup at the R6 gate, surface that decision in the chat as the final state of this path so the user knows the file-memory directories remain on disk until removed. Do not run `rm -rf` from this path; the gate decision belongs to R6.
4. If R6 did not run for any reason (Requirements Intake aborted before R6), apply the same gated cleanup pattern as the Bug path above to issue-intake's `$MEM` directory only (`rm -rf "$MEM"`) — do not touch any implementation-discovery directory, since that remains owned by Requirements Intake R6.

---

## Completion Criteria

This workflow is complete when **all** of the following are true:

- All 7 phases executed in sequence (I0–I6)
- All approval gates explicitly confirmed in the chat
- All self-review checks passed before presenting output
- **Bug path:** Jira Bug updated or created, issue linking offered, and no workflow or skill-invocation instructions were embedded in the description
- **Missing Requirement path:** R0 context confirmed, R0 file-memory initialization completed, Requirements Workflow completed through R5, issue linking offered
- I6 cleanup completed for the selected path: either the user confirmed cleanup at the I6 gate (Bug path) or the carried-over Requirements Intake R6 gate (Missing Requirement path) and the listed file-memory directories — including any upstream implementation-discovery directory — were removed, or the user explicitly declined cleanup at the gate
