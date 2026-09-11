# MANUAL QA PLAN WORKFLOW -- EXECUTION CONTRACT

**STRICT EXECUTION RULES -- NO EXCEPTIONS:**

1. Execute phases in strict sequential order (Q0 through Q4).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure in the chat. Do not continue.
5. Every required output must be presented in the chat before the phase is considered complete.
6. This workflow does not change Jira status, post Jira comments, create branches, commit changes, push, or use destructive git commands. The only allowed Jira mutation is writing the `## Final QA Plan` section into the issue description in Q4, per the **DESCRIPTION SECTION RULE**.

**CLARIFICATION RULE:** Do not assume anything. If required information is missing, ambiguous, conflicting, or underspecified, stop and use `AskUserQuestion` to ask the user for clarification before proceeding.

**TESTER ARTIFACT RULE:** This workflow produces two different outputs and they are **not** interchangeable.

- **The chat output is diagnostic**, for the developer running this workflow. Branch context, scope limits, confidence caveats, budget counts, and workflow limitations belong here.
- **The `## Final QA Plan` section written to Jira is the tester's only artifact.** It contains nothing but the Q4 template. Content that is *required* in the chat output is not thereby *permitted* in the Jira section.

Every instruction in the Jira section must be written for a QA tester who understands the application but is not familiar with the codebase. Use product and workflow language, never implementation language.

**BANNED FROM THE JIRA SECTION** -- never write any of these into `## Final QA Plan`:

1. Base-branch name, diff stats, commit hashes, file counts. (The *target* branch is allowed, on the single `**Test on branch:**` line.)
2. Any file path, directory, class, function, method, variable, or symbol name. (Carve-out: a developer example request may name the *kind* of input needed in product terms -- "the iframe embed markup to paste" -- but never a code identifier or path, and never the example content itself.)
3. `Why it matters` or business-justification prose.
4. `[High|Medium|Low]` priority labels.
5. Workflow limitations, phase labels (`Q0`-`Q4`), sub-agent names, or any statement about what this workflow does or does not do.
6. Process assumptions, confidence caveats, or "reduced confidence" warnings.
7. Acceptance criteria restated verbatim.
8. `Setup:` labels, including `Setup: None`.
9. Hedging language: "should probably", "may", "might", "consider", "if applicable", "as needed".
10. Empty sections or `None.` placeholders, other than the two fixed fallback lines defined in Q4.
11. Unicode emoji of any kind -- Unicode emoji breaks Jira and GitLab integrations. ASCII only.
12. Any reference to a deprecated or unsupported feature from the repository's declared inventory -- by feature name, path, filename pattern, query parameter, or settings field. See the **DEPRECATED SCOPE RULE**.

**CONCISION BUDGET:** The QA plan is a checklist a tester executes, not a report about the change. These limits are hard, and they are verified twice -- by the Q4 self-check and by the `comment-reviewer` gate.

| Rule | Limit |
|------|-------|
| Cases per work type | Bug: max 5 · Task: max 6 · Epic: max 10 |
| Required minimum | At least 1 `[Core]` case; at least 1 `[Regression]` case whenever the diff touches shared code or code with callers outside the changed area |
| Steps per case | 1-6, one action per step, no "and then" compounds |
| Words per step | max 20, imperative mood, starts with a verb |
| `**Pass:**` block | exactly one per case, max 3 lines, max 25 words per line |
| `**Repeat for:**` line | at most one per case, max 20 words, naming 2-5 equivalent inputs |
| Case title | max 12 words |
| `**What changed:**` | one sentence, max 40 words |
| `### Before You Start` | max 5 items, max 20 words each |
| Screenshot requests | max 6 total, max 1 per step, max 2 per case |
| Example requests | max 4 total, max 1 per step |
| `### Before Testing, Confirm With The Developer` | max 3 items |
| Whole section | max 700 words and max 90 lines |

Group cases by user-visible behavior, **not** one case per acceptance criterion. A single case may verify several criteria. Never restate a criterion verbatim.

**One case, one behavior.** A case verifies one coherent behavior and carries one `**Pass:**` condition. If it needs unrelated confirmations, split it into two cases or move the extra to `### Before Testing, Confirm With The Developer`. A case whose pass line reads as a list of separate outcomes is doing too much.

**Group equivalent variants instead of dropping them.** When the same steps apply to several inputs, give the case one `**Repeat for:**` line naming them (2-5 inputs, max 20 words) instead of spending a case on each. It counts as **one** case against the cap, and the `**Pass:**` condition must hold for every variant. Use it only when the steps are genuinely identical -- if a variant needs different steps or a different pass condition, it is its own case. One example request can cover the whole variant set, so grouping never multiplies developer requests.

**Never truncate to fit.** Every step and `**Pass:**` line is a complete, grammatical sentence ending in terminal punctuation. To shorten, rewrite the line or split the step -- never clip a word, drop a word, or run two words together. A garbled instruction is worse than a long one: the tester cannot act on it and cannot tell what was intended.

If the analysis produces more cases than the cap allows after grouping variants, keep the highest-value ones and report the trimmed scenarios in the chat output only. Never pad to reach a cap.

**DEVELOPER REQUEST RULE:** This workflow cannot capture screenshots and must never invent sample input. When the tester needs either one, the plan *requests* it from the developer. Both request families share one marker shape, one checklist, and one set of integrity rules.

**Markers (exact, ASCII only, always backticked so the brackets survive the Jira write):**

- `` `[SCREENSHOT NEEDED: S<case>.<seq>]` `` -- a reference image of the intended result.
- `` `[EXAMPLE NEEDED: E<case>.<seq>]` `` -- sample input the tester must use but cannot invent.

`<case>` is the case number; `<seq>` is a 1-based counter within that case -- `S1.1`, `S1.2`, `E2.1`.

- **Placement is per step**, appended to the end of that step's text. Never per case: the tester needs to know which screen to compare against or which input to use at which moment, and the developer needs to know which state to capture or which snippet to supply.
- **Every marker is also aggregated** into the mandatory `### Needed From Developer` checklist -- one row per ID, in ID order, each row typed `(screenshot)` or `(example)`, stating what is needed and back-referencing `(Case N, Step M)`.

**Request a screenshot only when all three hold:**

1. The diff changes a rendering, template, component, style, layout, copy/i18n, or icon/asset file, **and**
2. The step's `Pass:` condition requires a *visual* judgment -- a new or changed element, its position, its styling, its copy, or a visual state (empty, loading, error, disabled, selected, responsive breakpoint), **and**
3. A tester who has never seen the intended design could reach the wrong verdict without a reference image.

**Do not request a screenshot when:** the `Pass:` condition is verifiable non-visually (record created, HTTP status, redirect, log line, email sent, count changed), or the UI involved is pre-existing and unmodified.

**Request an example when** a step tells the tester to paste, upload, enter, or configure content whose exact form determines the outcome and which the tester cannot reasonably invent:

- embed or markup snippets (iframe, social embed, raw HTML)
- request or response payloads and API bodies
- import files with a required shape (CSV, XML, JSON)
- malformed or boundary input for a negative case
- a URL of a specific provider or shape
- a specific configuration or feature-flag value combination

**Do not request an example when** the input is arbitrary or obvious -- "enter any headline", "upload any JPEG", "type a title". A step that reads "paste raw embed markup" with no example request is a defect: the tester has no way to proceed.

- **Never invent the example yourself.** The plan requests it; the developer supplies a real, working artifact. A fabricated snippet that does not load wastes the tester's time and looks authoritative.
- **Never request credentials, tokens, or real customer data** as an example. If a case needs authenticated state, express it as a role or account type in `### Before You Start` instead.
- One example request can cover a whole `**Repeat for:**` variant set -- one ID, one row, naming the input needed for each variant.

**When neither is needed at all**, still emit the `### Needed From Developer` heading, carrying exactly this line and nothing else:

    `- Nothing needed — this change has no visual surface and no example inputs.`

Omitting the heading is a failure. Silence is ambiguous about whether the question was considered; the fixed line states positively that it was.

**DEPRECATED SCOPE RULE:** Some repositories declare features that still execute but are no longer supported. A QA tester must never be asked to verify one. Before writing any test case, build the deprecated inventory and exclude it.

The full contract lives in **`deprecated-scope-protocol.md`** at the plugin root -- read it and apply it. In this workflow specifically:

- Build the inventory per protocol **§1** (lookup order) and **§2** (extract concrete markers, keep them specific).
- Apply **§3**: never infer deprecation yourself from code comments, `@deprecated` annotations, or directory names. The declared inventory is the only authority.
- Apply **§4** (consumer obligations): exclude absolutely -- no case, step, pass condition, screenshot request, or prerequisite may target a deprecated surface, even when the change sits directly beside one and even when the feature is still switched on somewhere. Never write a regression case for a deprecated feature.
- **Flag, do not test.** If the diff itself adds to or modifies a deprecated surface, report it in the Q2 and Q4 **chat output** as `Deprecated surfaces touched by this diff`, naming the file and the feature, so the developer can remove it before QA reaches it. Never convert it into a tester-facing case.
- If the repository declares no such inventory, record `no deprecated inventory declared` and continue.

**BRANCH CONTEXT RULE:** Review the actual branch diff whenever possible. If the target branch cannot be resolved from Jira context or repository state, stop and use `AskUserQuestion` to ask the user how to proceed:
- Header: `Branch Context`
- Question: `The target branch could not be resolved from Jira context or repository state. How would you like to proceed?`
- Options:
    - `Provide the branch name (Recommended)` — Specify the branch to use for diff analysis. Best QA plan accuracy.
    - `Approve Jira-only QA planning` — Continue without a branch diff. QA plan will have reduced confidence.

**SUB-AGENT NAME RESOLUTION:** This workflow refers to its sub-agents by short name (`manual-qa-reviewer`, `comment-reviewer`). The runtime registers them under a different identifier depending on how they are installed. Before invoking one, resolve the short name against the runtime's available-agents list and use the exact registered identifier:

- If the short name appears verbatim in the list (agents deployed into the project's `.claude/agents/`), use it as-is.
- If installed via the plugin, the registered identifier is `web-cms:<short-name>:<short-name>` — e.g. `manual-qa-reviewer` → `web-cms:manual-qa-reviewer:manual-qa-reviewer`.
- Never invent a partial form such as `web-cms:manual-qa-reviewer` — it will not resolve. If an invocation fails with an "agent type not found" error, read the available-agents list in the error message, select the entry whose **final segment** equals the short name, and retry with that exact identifier.

**TOOL PREFERENCE:** Prefer native tools over Bash for filesystem work. All filesystem, search, and directory operations must stay within the current project directory.

- **File reads:** Use native `Read`. This workflow does not write files.
- **File discovery (find files by name or pattern):** Use native `Glob`.
- **Content search (find text inside files):** Use native `Grep`.
- **Directory operations (list, metadata):** Use Bash (`ls`, `stat`).
- **Git:** Use Bash for all git operations (`git status`, `git diff`, `git log`, `git remote`, `git branch`, etc.).

**DESCRIPTION SECTION RULE:** The `## Final QA Plan` section is owned by this workflow and is rewritten wholesale on every run. Preserve everything else in the description exactly as retrieved in Q0.

- If the description already contains a `## Final QA Plan` heading, **replace that section in place**: from the `## Final QA Plan` line through the character immediately before the next `## ` heading at the same level, or through the end of the description if no `## ` heading follows it.
- If no such heading exists, **append** the section at the bottom, separated from the existing content by exactly two newline characters.
- Everything outside the replaced span must be preserved byte-for-byte. Do not edit, delete, reorder, reformat, or normalize any other description content.
- Bounding the replacement at the next `## ` heading matters: other workflows write their own description sections (for example `## Architecture`), and a replace-to-end-of-description would destroy them.
- Never leave two `## Final QA Plan` sections in a description.

**JIRA WRITE CONTRACT:** The `## Final QA Plan` section is written into a Jira description by `jira_update_issue`. Getting the markdown wrong destroys the whole artifact, not one field.

- Pass clean GitHub-flavored markdown. Never backslash-escape markdown characters -- bold is literal `**text**`, never `\*\*text\*\*`. Ensure every bold span has matching `**` delimiters on both sides.
- The string passed to `jira_update_issue` must be byte-identical to the draft the `comment-reviewer` gate approved. Do not re-serialize, re-escape, normalize, or "fix up" the body between approval and write.
- **Square brackets survive only inside backticks.** Bare `[` and `]` are consumed on the way into Jira. Every bracketed token in the artifact -- the `[Core]`/`[Edge]`/`[Regression]` tags and both developer-request markers -- is therefore written as a backticked code span. Never emit a bare `[ ]` checkbox; it will vanish.
- Q4 verifies all of this against the *written* description after the write, not only against the draft.

**TASK TRACKING:** Always use task tracking (`TaskCreate`/`TaskUpdate`) so progress is visible throughout. Create one task per phase at the start of the workflow. Mark each task `in_progress` when starting the phase and `completed` when the phase is done:

- Q0 — Understand the QA Target
- Q1 — Resolve Branch and Diff Scope
- Q2 — Gather Manual QA Context
- Q3 — Invoke `manual-qa-reviewer`
- Q4 — Final QA Plan and Follow-up

---

### Q0 -- Understand the QA Target

- Retrieve the Jira issue using the provided key. Read its full description and preserve the original description verbatim for the write operation in Q4.
- Determine the work type from the issue type and description structure:
    - **Task:** Contains `## Task Details` and `## Acceptance Criteria`
    - **Bug:** Contains `## Bug Details` and `## Fix Criteria`
    - **Epic:** Epic issue, or an issue whose description uses the epic `## Task Details` structure and represents multi-task scope
    - **Anything else:** Stop and explain that this workflow only supports Task, Bug, and Epic issues.
- Record the resolved case cap for this work type from the **CONCISION BUDGET** table (Bug 5, Task 6, Epic 10). This value is passed to the sub-agent in Q3 and checked in Q4.
- Extract the issue summary, criteria, affected areas, dependencies, scope boundaries, and any explicit risks or open items.
- Recover the latest durable execution context from Jira comments when present:
    - **Task:** Latest approved implementation-plan comment, plus the latest user-testing handoff or summary comment if present
    - **Bug:** Latest approved fix-plan comment, plus the latest user-testing handoff or summary comment if present
    - **Epic:** Latest approved breakdown-plan comment, plus the latest testing handoff or summary comment if present
- **Epic only:** Retrieve child issues using JQL `parent = ISSUE-KEY`. Read each child issue's key, summary, status, and the description sections needed to understand integrated behavior. If a completed child task includes a final summary comment, use it to recover cross-task verification context.
- Note whether the description already contains a `## Final QA Plan` section, and whether any `## ` heading follows it. Q4 needs both facts to apply the **DESCRIPTION SECTION RULE**.
- If approved-plan or summary context is missing, continue using the issue description plus repository evidence, but explicitly record the missing context for the chat output.

> **REQUIRED (chat only):** Present a compact target summary, one line per item, before proceeding:
>
> - Issue key and title
> - Work type and resolved case cap
> - Criteria source identified
> - Supporting context found (plan, handoff, summary), or what is missing
> - Existing `## Final QA Plan` section: present or absent, and whether a `## ` heading follows it
> - Epic child issue count, if applicable

---

### Q1 -- Resolve Branch and Diff Scope

- Detect the current git branch.
- Determine the comparison base branch:
    - **Standard Task, Bug, and Epic runs:** Detect the default branch by running `git remote show origin` and reading the `HEAD branch` line, or by checking for `main` / `master` if the remote is unavailable.
    - **Epic child task context:** If the Task Details include an `Epic Integration Branch` field and the target branch resolves to a task branch, use the `Epic Integration Branch` as the diff base.
- Determine the target branch using this order:
    1. An explicit branch name recovered from the latest testing handoff or summary comment
    2. For epic child tasks only, an explicitly named integration branch if the task branch is unavailable — first use `AskUserQuestion` (Header: `Branch Scope`, Question: `The task branch is unavailable. Would you like to use the integration branch instead? This broadens the QA scope beyond this single task.`) with options: `Use integration branch` (description: "Broaden scope to the epic integration branch — covers more changes") and `Stop` (description: "Abort and report that the target branch could not be resolved")
    3. The standard branch naming convention `{PROJECTKEY}-{ISSUENUMBER}-{issue-summary-in-kebab-case}`. For epics, this is the integration-branch convention from the epic workflow.
- Confirm the base branch and target branch exist locally or as remote tracking refs.
- Gather the cumulative review scope:
    - The full diff between the base branch and the target branch
    - Any staged or unstaged changes on top of `HEAD` only when the current branch matches the target branch
- Produce:
    - The full diff of all changed files
    - A changed-file list grouped into production files, test files, documentation files, and configuration files where possible
- If the target branch cannot be resolved, the diff cannot be produced, or the only available branch context would broaden the scope beyond the requested issue, stop and use `AskUserQuestion` to ask the user how to proceed:
    - Header: `Branch Failure`
    - Question: `The target branch could not be resolved or the diff could not be produced. How would you like to proceed?`
    - Options:
        - `Provide a branch or commit reference (Recommended)` — Specify an alternative branch or commit for diff analysis.
        - `Approve Jira-only QA planning` — Continue without a diff. QA plan will have reduced confidence.
        - `Stop` — Abort the workflow.

> **REQUIRED (chat only):** Present a compact repository summary, one line per item, before proceeding:
>
> - Current branch
> - Target branch
> - Base branch
> - Whether uncommitted changes are included in scope
> - Counts of production, test, documentation, and configuration files in scope
> - Any missing or inferred branch context
>
> Of these, **only the target branch** may appear in the Jira section. The base branch, file counts, and scope caveats are chat-only per the **TESTER ARTIFACT RULE**.

---

### Q2 -- Gather Manual QA Context

- Read all changed production files in full.
- Read nearby tests, documentation, and configuration files relevant to those changed areas.
- Identify the user-visible or operator-visible behaviors affected by the change, including:
    - Navigation paths, screens, forms, APIs, commands, or background jobs that surface the behavior
    - Permissions, roles, feature flags, environment setup, or test data required to exercise the change
    - Validation rules, empty states, loading states, error states, retries, or fallback behavior
    - Cross-system side effects such as notifications, persistence, synchronization, exports, imports, or downstream integrations
- **Identify the inputs a tester cannot invent.** For each behavior under test, note whether exercising it requires content whose exact form matters -- embed or markup snippets, payloads, import files, malformed input, provider-specific URLs, or a particular configuration value. These become example requests in Q4. Record `none — every input a tester needs is arbitrary or obvious` when that is the case.
- **Build the deprecated inventory** per the **DEPRECATED SCOPE RULE**: read the repository's declared deprecated/unsupported/legacy sections, extract the concrete markers for each feature, and record them. Then check the changed-file list and diff against those markers and record whether this change touches any deprecated surface.
- **Determine the UI/visual surfaces affected.** List the specific screens, components, and visual states touched by the diff. If the diff contains no rendering, template, style, copy, or asset change, record the literal finding `none — no rendering, template, style, or copy change in the diff`. This is the input the **DEVELOPER REQUEST RULE** consumes; without it, Q3 and Q4 are guessing.
- **Bug work:** Map the original steps to reproduce to the corrected behavior and identify the most likely regression surfaces around the fix.
- **Epic work:** Map the end-to-end workflows and integration points that now span multiple child tasks.
- Translate the technical implementation into plain-language behaviors a QA tester can verify manually.
- Identify anything that is still ambiguous, environment-dependent, or not safely inferable from the available evidence.

> **REQUIRED (chat only):** Present a compact manual-QA context summary, one line per item, before proceeding:
>
> - User-visible change summary
> - Prerequisites, permissions, feature flags, or test data needed
> - **UI/visual surfaces affected**, or the literal `none` finding
> - **Inputs a tester cannot invent**, or the literal `none — every input a tester needs is arbitrary or obvious`
> - **Deprecated inventory:** each declared deprecated feature and its markers, or the literal `no deprecated inventory declared`
> - **Deprecated surfaces touched by this diff:** the file and the feature for each, or `None`. Anything listed here is a developer follow-up, never a tester case.
> - Highest-risk areas for manual testing
> - Assumptions or ambiguities that may affect confidence

---

### Q3 -- Invoke `manual-qa-reviewer`

Invoke the `manual-qa-reviewer` sub-agent, providing:

- The Jira issue key and work type
- The relevant Jira description sections and extracted criteria
- The supporting Jira context from Q0 (plan, summary, handoff, child-task context)
- The target branch and base branch from Q1
- The full diff of all changed files from Q1
- The changed-file list grouped by file type from Q1
- The manual-QA context summary from Q2
- The **UI/visual surfaces affected** finding from Q2
- The **CONCISION BUDGET** table, including the resolved case cap for this work type from Q0
- The **DEVELOPER REQUEST RULE**, including both marker strings, the ID scheme, and the decision rules for screenshots and examples
- The **inputs a tester cannot invent** finding from Q2
- The **deprecated inventory** and the **deprecated surfaces touched by this diff** from Q2, with the instruction that deprecated surfaces are excluded from every case and never become regression coverage
- The **BANNED FROM THE JIRA SECTION** list

Wait for the sub-agent to return its `MANUAL QA REVIEW REPORT`.

- If the status is **FAILED**: stop and present the report in the chat. Do not proceed.
- If the status is **COMPLETE**: record the `QA PLAN BODY` block verbatim, plus the report-only sections (branch context, open questions, summary) and the `BUDGET` line.

> **REQUIRED (chat only):** Present the `manual-qa-reviewer` outcome before proceeding:
>
> - Status
> - `Cases: N of MAX (Core: n, Edge: n, Regression: n)`
> - `Screenshot requests: N` · `Example requests: N`
> - Budget violations, if any
> - Deprecated surfaces excluded from coverage, or `None`
> - Open questions
> - Summary

---

### Q4 -- Final QA Plan and Follow-up

**The pinned artifact.** The section written to Jira must match this template exactly. The heading is `## Final QA Plan` character-for-character -- an H2 markdown heading. This is the one Jira artifact in this plugin that uses a `##` heading; every gated Jira *comment* uses a `**bold**` first line instead. Never use a descriptive substitute such as "QA Steps" or "Testing Plan".

```markdown
## Final QA Plan

**Test on branch:** `{target-branch}` — plan updated {YYYY-MM-DD}
**What changed:** {one sentence, product language, max 40 words}

### Before You Start
1. {account/role, data, feature flag, or environment needed. Max 20 words}

### Test Cases

**Case 1 — {title, max 12 words}** `[Core]`
1. {tester action, imperative, one action, max 20 words}
2. {tester action} `[SCREENSHOT NEEDED: S1.1]`
**Pass:** {observable result, max 25 words}

**Case 2 — {title}** `[Core]`
**Repeat for:** {2-5 equivalent inputs the same steps run against, max 20 words}
1. {tester action} `[EXAMPLE NEEDED: E2.1]`
2. {tester action}
**Pass:** {observable result, and it must hold for every variant}

**Case 3 — {title}** `[Regression]`
1. {tester action}
**Pass:** {observable result}

### Needed From Developer
Attach images to this issue named with their ID. Paste each example in a comment as a fenced code block labeled with its ID.

- **S1.1** (screenshot) — {what the image must show} (Case 1, Step 2)
- **E2.1** (example) — {what input is needed and what it must exercise} (Case 2, Step 1)

### Before Testing, Confirm With The Developer
1. {only questions that change how a tester judges pass or fail}
```

Template rules:

- **One ordered list.** All cases live in a single `### Test Cases` sequence numbered `Case 1..N`, emitted in tag order: every `[Core]` case first, then `[Edge]`, then `[Regression]`. Do not split them into separate sections. The tag is the triage signal for a lead deciding what to cut under time pressure; ordering already carries priority, so there is no separate priority label.
- **Regression coverage is executable.** A regression concern becomes a real `[Regression]` case with steps and a `**Pass:**` line. If a regression risk cannot be expressed as concrete steps, do not emit a stub case -- put it in `### Before Testing, Confirm With The Developer`, or report it in the chat output only.
- **No `Setup:` label.** Setup needed by one case becomes step 1 of that case. Setup shared across cases goes in `### Before You Start`.
- **The `Pass:` line is the verdict.** Every case has exactly one `**Pass:**` block. A case without a pass condition is not a test.
- **Steps are plain numbered lines** -- `1.`, `2.`, `3.` -- with no `[ ]` checkbox. Bare brackets do not survive the Jira write, and a tester cannot tick a description without editing it.
- **Bracketed tokens are always backticked** -- the `` `[Core]` `` tags and both `` `[SCREENSHOT NEEDED: ...]` `` / `` `[EXAMPLE NEEDED: ...]` `` markers. See the **JIRA WRITE CONTRACT**.
- **`**Repeat for:**` is optional**, at most one per case, placed directly under the case heading before step 1.
- **Omit-when-empty applies to exactly one section:** `### Before Testing, Confirm With The Developer` is dropped entirely when there are no blocking questions. Every other heading is mandatory, with these fixed fallback lines instead of a placeholder:
    - No prerequisites → `1. Nothing beyond normal access to the test environment.`
    - Nothing needed from the developer → `- Nothing needed — this change has no visual surface and no example inputs.`

**Step 1 -- Assemble the section.** Take the `QA PLAN BODY` block from the Q3 report and fit it to the template. Fill `{target-branch}` from Q1 and `{YYYY-MM-DD}` with today's date.

**Step 2 -- Run the deterministic self-check.** Print each item with its count or yes/no answer. Every item is a count or a yes/no -- never a judgment call.

1. Case count N ≤ work-type cap MAX? (`N = __`, `MAX = __`)
2. At least 1 `[Core]` case? At least 1 `[Regression]` case, or a stated reason none applies?
3. Cases numbered `1..N` with no gaps, ordered `[Core]` → `[Edge]` → `[Regression]`?
4. Max steps in any case ≤ 6? List any step over 20 words.
5. Exactly one `**Pass:**` block per case, ≤ 3 lines, ≤ 25 words per line?
6. Every step and `**Pass:**` line ends in terminal punctuation (`.` or `?`)? List any that do not -- a line ending mid-word is truncated content and must be rewritten, not padded.
7. At most one `**Repeat for:**` line per case, ≤ 20 words, naming 2-5 inputs, placed before step 1?
8. Zero occurrences of: a file path (a `/` or a dotted filename), `Setup:`, `Why it matters`, a `High`/`Medium`/`Low` priority label, the base-branch name, `Q0`-`Q4`, `manual-qa-reviewer`, "workflow does not"?
9. Zero Unicode emoji, and zero backslash-escaped markdown (`\*`, `\_`, `\#`)?
10. Every bracketed token backticked -- the `[Core]`/`[Edge]`/`[Regression]` tags and every `[SCREENSHOT NEEDED: ...]` / `[EXAMPLE NEEDED: ...]` marker -- and zero bare `[ ]` checkboxes anywhere?
11. Zero references to any deprecated feature from the Q2 inventory -- by name, path, filename pattern, query parameter, or settings field -- in any case title, step, pass condition, prerequisite, or developer request? (Check each marker recorded in Q2 individually and print the marker list you checked.)
12. Developer requests and checklist rows: counts equal, IDs unique, each `<case>` matches the containing case number, every `(Case N, Step M)` back-reference resolves to a real case and an existing step, every row typed `(screenshot)` or `(example)`, screenshots ≤ 6, examples ≤ 4, at most 1 marker per step -- or the fixed nothing-needed line is present?
13. Every step that tells the tester to paste, upload, or enter content whose exact form matters carries an example request? List any that does not.
14. Section totals: `__` words (≤ 700) and `__` lines (≤ 90)?
15. Every mandatory heading present in order, and `### Before Testing, Confirm With The Developer` present only when it has content?

Any failure -- revise the section and re-run the whole check before proceeding. Do not invoke the gate on a section that fails its own check.

**Step 3 -- Gate on `comment-reviewer`.** Invoke the `comment-reviewer` sub-agent with:

- The drafted `## Final QA Plan` section verbatim, exactly as it will be written to Jira
- The phase label `Q4 — Final QA Plan`
- The work type and the resolved case cap
- The target branch, for the reference spot-check
- The deprecated inventory markers from Q2, so the reviewer can scan for them
- The resolved caps for this run, so the reviewer compares rather than recounts

Then:

- **APPROVED** — proceed to Step 4.
- **CHANGES REQUIRED** — fix every Critical and Major finding, re-run the Step 2 self-check, and re-invoke. Maximum 3 iterations. If the third iteration still returns CHANGES REQUIRED, write the section as-is and report the residual findings **in the chat output only**. Never append reviewer findings to the tester's section.

**Step 4 -- Write to Jira.** Apply the **DESCRIPTION SECTION RULE**: replace an existing `## Final QA Plan` section in place, or append if none exists, preserving all other description content byte-for-byte. Call `jira_update_issue` with the full updated description, passing the gate-approved body byte-identically per the **JIRA WRITE CONTRACT**.

**Step 5 -- Verify the write.** The self-check in Step 2 inspects the draft; it cannot see what actually landed. If markdown gets escaped during serialization into the tool call, every pre-write check passes while the written artifact is ruined. So verify against the *written* description: call `jira_get_issue` and assert, printing each result:

1. Zero occurrences of `\*`, `\_`, or `\#` anywhere in the description.
2. Exactly one `## Final QA Plan` heading.
3. Every `S<n>.<m>` and `E<n>.<m>` marker still present, with its brackets and its backticks intact.
4. Every `**Pass:**` block still present -- one per case, matching the case count from Step 2.
5. The `[Core]` / `[Edge]` / `[Regression]` tags still bracketed and backticked.
6. All content outside the `## Final QA Plan` section byte-identical to the Q0 capture.

**On any failure:** report the exact assertion that failed, then re-write **once**. The corrective write must rebuild the description from the **Q0 capture** plus a corrected section -- do **not** re-apply the **DESCRIPTION SECTION RULE** to the text just written. If the escaping mangled the heading itself (`\#\# Final QA Plan`), the rule's find-and-replace cannot locate the section and its append branch would fire, leaving two plans on the card. Rebuilding from Q0 avoids that; the only cost is losing a concurrent human edit made mid-run, which is acceptable within a single run and better than a duplicated plan.

If the second write also fails verification, **stop**. Leave the description as it stands, report which assertion failed and what the written text looks like, and tell the user the section needs a manual fix. Do not attempt a third write.

**Step 6 -- Present the chat output.** Two blocks, clearly labeled:

**Jira section (tester-facing)** — the `## Final QA Plan` section exactly as written, so the user does not have to open Jira to review it.

**Developer notes (chat only, not written to Jira)**:

- **Issue:** Jira key and title
- **Work type:** Task, Bug, or Epic
- **Branch context:** Target branch, base branch, and any limits in the reviewed scope
- **Budget:** Cases N of MAX, screenshot requests N of 6, example requests N of 4, section word and line counts
- **Write verification:** Each Step 5 assertion with its result, and whether a corrective re-write was needed
- **Gate result:** `comment-reviewer` verdict and iteration count, plus any residual findings
- **Trimmed coverage:** Any scenario dropped to respect the case cap, or "None"
- **Deprecated surfaces touched by this diff:** The file and feature for each, flagged as a developer follow-up to resolve before QA, or "None". This never appears in the Jira section.
- **Deprecated coverage excluded:** Any scenario dropped because it targeted a deprecated surface, or "None"
- **Assumptions / open questions:** Anything the user should confirm
- **Confidence warning:** If branch review had to be broadened or the user approved Jira-only planning, explicitly warn that confidence is reduced and explain why. Otherwise omit.
- **Workflow limitations:** State that this workflow does not execute the manual tests, does not change Jira status or post comments, and does not guarantee environment-specific setup beyond what was observable from the issue and repository context.

Do not mark this workflow complete until the self-check passed, the gate was resolved, and the Jira description was updated successfully.

---

## Completion Criteria

This workflow is complete when **all** of the following are true:

- All phases executed in sequence (Q0 through Q4)
- The Jira issue was confirmed as Task, Bug, or Epic
- The related branch and diff scope were identified, or the user explicitly approved reduced-context planning
- `manual-qa-reviewer` ran and returned a `MANUAL QA REVIEW REPORT` with status COMPLETE
- The Q4 deterministic self-check was printed and every item passed
- `comment-reviewer` returned APPROVED for phase label `Q4 — Final QA Plan`, or the 3-iteration cap was reached and the residual findings were reported in the chat
- The deprecated inventory was built (or recorded as not declared), and no case, step, prerequisite, or screenshot request targets a deprecated surface
- The `## Final QA Plan` section conforms to the Q4 template: pinned heading, `**Test on branch:**` and `**What changed:**` lines, `### Before You Start`, one numbered `Case N` list within the work-type cap, `### Needed From Developer` either populated or carrying the fixed nothing-needed line, and no banned content
- The Jira description contains exactly one `## Final QA Plan` section, and all content outside that section is byte-for-byte identical to what was retrieved in Q0
- The Step 5 post-write verification ran against the re-read description and every assertion passed, or a single corrective re-write was applied and then passed
- No step or `**Pass:**` line is truncated, and every bracketed token in the written section is backticked
