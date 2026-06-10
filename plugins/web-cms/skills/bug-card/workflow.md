# BUG CARD WORKFLOW — EXECUTION CONTRACT

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute phases in strict sequential order (B0 through B15).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure as a comment on this Jira issue. Do not continue.
5. Every required output (comments, plans, summaries) must be posted before the phase is considered complete.

**FILE MEMORY SCOPE:** This workflow stores investigation state in a per-work-item file-memory directory (`work-item.md`, `checkpoint.md`, `plan.md`, `explorations/*.md`, …). Compute its path once with the shared recipe in `file-memory-protocol.md` §1 (`MEM=<…>/web-cms-memory/<JIRA-KEY>`) and reuse that exact path for every read/write. If the workflow is resumed and `$MEM` is absent, reconstruct state by reading the Jira issue description and all comments posted in prior phases before continuing. See `file-memory-protocol.md` for all file schemas, the checkpoint/compaction contract, and the full-context-load rule.

**APPROVAL GATE BEHAVIOR:** Approval gates are chat-scoped. If explicit approval is not captured before the session ends or context is lost, stop at the gate. On resume, re-present the latest fix plan or testing handoff and ask for confirmation again. Never assume a pending approval was granted.

**CLARIFICATION RULE:** Do not assume anything. If required information is missing, ambiguous, conflicting, or underspecified, stop and use `AskUserQuestion` to ask the user for clarification before proceeding.

**RESUMPTION CHECK:** If this workflow resumes after prior work has already been performed, follow the universal resume rule (read `$MEM/checkpoint.md` and its `references`) to identify the first incomplete phase. If the issue is already **In Progress**, do not repeat B0. If `$MEM` is absent, rebuild the investigation state from the latest reproduction notes, investigation comments, and approved plan in Jira before continuing.

**SERENA PROJECT ACTIVATION:** Before B0, check Serena's project-activation message (emitted on connect via `--project-from-cwd`); if it reports that onboarding has not been performed, call `onboarding` to scope Serena's language server to the current project directory. Serena's symbol tools (`find_symbol`, `find_referencing_symbols`, `get_symbols_overview`, `search_for_pattern`, and the symbol-aware write tools) will not function correctly without this. Do this once at the start of the workflow; do not repeat it between phases.

**TOOL PREFERENCE:** Prefer native tools over Bash for filesystem work. All filesystem, search, and directory operations must stay within the current project directory.

- **File I/O (read files, write new files, edit non-symbol regions):** Use native `Read`, `Write`, `Edit`.
- **Symbol-aware code edits (methods, classes, functions in existing source files):** Prefer Serena's `replace_symbol_body`, `insert_after_symbol`, `insert_before_symbol`, `rename_symbol`, and `safe_delete_symbol` over native `Edit` when the target is a named code symbol. See the Serena-first editing rule in B10 for the full decision rubric.
- **File discovery (find files by name or pattern):** Use native `Glob`.
- **Content search (find text inside files):** Use native `Grep`. For symbolic code navigation during the fix (locating a method, class, or caller before editing), use Serena's `find_symbol`, `find_referencing_symbols`, `get_symbols_overview`, and `search_for_pattern` directly. For broader codebase analysis that informs the investigation (architectural patterns, cross-area impact), delegate to the `codebase-explorer` agent.
- **Directory operations (list, metadata, move, mkdir):** Use Bash (`ls`, `stat`, `mv`, `mkdir -p`).
- **Git:** Use Bash for all git operations (`git status`, `git diff`, `git log`, `git push`, `git pull`, `git merge`, `git remote`, `git stash`, `git rebase`, etc.) and for running build, test, and lint commands.

**JIRA COMMENT CONTRACT:** Keep Jira comments minimal, structured, and durable. Do not narrate every phase. Routine Jira comments are required only at:

- **B5/B6** — one combined comment containing the reviewed fix plan and the approval request
- **B12** — user testing handoff
- **B14** — final structured summary

Additional Jira comments are allowed only for blocking failures, reposting a revised plan after requested changes, or explicit user-requested status updates. Do not post separate narration comments for B0, B1, B2, B3, B4, B7, B8, B9, B10, B11, B13, or B15.

When a Jira comment heading references workflow phases, use the exact phase label defined here. Do not invent synthetic phase ranges. The only routine combined phase heading allowed is `B5/B6` because one comment serves both phases.

**Comment formatting:** Pass clean GitHub-flavored markdown to `jira_add_comment`. Never backslash-escape markdown characters — bold is literal `**text**`, never `\*\*text\*\*`. Ensure every bold span has matching `**` delimiters on both sides.

**Comment reviewer gate:** Every `jira_add_comment` call in this workflow (B5/B6, B12, B14) is gated by an `**Independent comment review:**` block, following the same pattern as `plan-reviewer` and `implementation-reviewer`. The `comment-reviewer` sub-agent must return APPROVED (or the 3-iteration cap must be reached) before `jira_add_comment` is called. There are no exceptions.

**COMMIT, PUSH, MERGE & TRANSITION DISCIPLINE — HARD RULE:** Every one of the following is an irreversible action that affects shared state. None may run until the user has explicitly selected the "Approve" option at the B12 User Testing gate **in this same session**:

- `git add` / `git commit` on the working branch
- `git push` of the working branch
- `git merge` into any integration or shared branch
- `git push` of an integration branch
- Any Jira transition that moves the issue out of "In Progress" (e.g. to "In Review", "Done", "Closed")

A passing build, passing tests, clean self-review, or successful reviewer sub-agent do NOT substitute for user testing approval. **Auto Mode does not lift this rule.** Auto Mode's "bias toward working without stopping" applies to implementation decisions and tool usage — not to workflow approval gates or irreversible shared-state actions. If you cannot quote the user's verbatim B12 approval selection from earlier in this same conversation, STOP and return to B12.

These actions must not be chained. Run each one at a time, reporting the result in the chat before starting the next. Do not pre-batch commit + push + Jira transition in a single tool sequence.

**TASK TRACKING:** Always use task tracking (`TaskCreate`/`TaskUpdate`) so progress is visible throughout. Create one task per phase at the start of the workflow. Mark each task `in_progress` when starting the phase and `completed` when the phase is done:

- B0 — Transition to In Progress
- B1 — Understand the Bug
- B2 — Reproduce the Bug
- B3 — Investigate Root Cause
- B4 — Ask Clarifying Questions
- B5 — Create Fix Plan
- B6 — Await Plan Approval
- B7 — Verify Working Branch
- B8 — Baseline Verification
- B9 — Write a Failing Test
- B10 — Implement the Fix
- B11 — Post-Fix Verification
- B12 — User Testing
- B13 — Commit and Push
- B14 — Summary of Changes
- B15 — Cleanup

**CHECKPOINT & COMPACTION CONTRACT:** This workflow records position in a single `$MEM/checkpoint.md` file (full schema and contract in `file-memory-protocol.md` §4). Two mechanisms:

**Per-phase checkpoint — after EVERY phase (B0–B14), automatically, with no chat output and no `/compact` prompt.** Run `git branch --show-current` and `git log --oneline -1` (separate Bash calls), then **atomically overwrite** `$MEM/checkpoint.md`: `Write` the content to `checkpoint.md.tmp`, then `mv "$MEM/checkpoint.md.tmp" "$MEM/checkpoint.md"`. Set `checkpoint_type: phase`, the just-completed `phase`, the upcoming `next_phase`, the `references` list, `## Decisions`, and `## Open items`. At B10 also set `reviewer_iterations: { impl, test, doc }`. This keeps the recall point current even if auto-compaction or an interruption fires between gates.

**Compaction gates (B4, B6, B10) — additionally prompt the user to `/compact`.** Do the per-phase write but with `checkpoint_type: gate`, then: (1) wait for any background `area-mapper` to finish; (2) emit the Phase Summary block (§4(b)) — phase + skill, Jira key, branch @ head_sha, one-line decisions, verbatim approval condition, reviewer iterations (B10 only), `next_phase`, the checkpoint file path, and the resume contract; (3) end the turn with the literal line **"Run `/compact` now, then type `continue` to resume."** Do NOT call `AskUserQuestion` at a gate — the user's input must stay free for `/compact`.

**Universal resume rule — on ANY resume (a `continue` after `/compact`, an auto-compaction summary, or a fresh re-invocation), before doing anything else:** `Read $MEM/checkpoint.md` → `Read` every file in its `references` → verify git (`git status`, branch, HEAD) against the recorded values and surface drift → **re-read the `next_phase` section of this `workflow.md`** so its full instructions survive compaction (any phase asking clarifying/structured questions MUST use `AskUserQuestion`, never plain text) → continue at `next_phase`. If `$MEM` is absent, reconstruct from Jira (see File Memory Scope). Approval gates stay chat-scoped — never assume a pending approval was granted.

---

### B0 — Transition to In Progress

**This phase requires TWO separate tool calls. Do not move to B1 until both are complete.**

1. **Tool call 1:** Call `jira_get_transitions` with this issue's key. From the response, find the transition whose target status is **In Progress** and note its **ID**.
2. **Tool call 2:** Call `jira_transition_issue` with this issue's key and that transition ID. This is the call that actually moves the issue. Retrieving transitions alone does nothing -- you MUST call `jira_transition_issue` to complete this phase.

Do not guess transition IDs. Always retrieve them first via tool call 1.

### B1 — Understand the Bug

- Retrieve the Jira issue using the provided key. Read its full description.
- Read the **Bug Details** section of the Jira issue description thoroughly.
- Identify the reported behavior (Observed Behavior), expected behavior (Expected Behavior), and reproduction steps (Steps to Reproduce).
- Note the severity, the structured **Affected Areas** list, and any environmental conditions from the Environment section.
- Read the **Patterns & Code References** section if present — the code paths and conventions the fix should follow.

### B2 — Reproduce the Bug

- Follow the **Steps to Reproduce** exactly as described.
- Confirm whether the bug is reproducible and document the results.
- If the bug **cannot be reproduced:** Stop. Post a comment on this Jira issue describing what was tried, the environment used, and the actual results observed. **Do not continue until the reporter provides additional reproduction guidance.**
- If the bug **requires manual UI interaction, browser-specific conditions, or environment-specific setup that cannot be automated:** Proceed to B3 with investigation based on code analysis only. Note this limitation — it will affect B9 (the failing test may need to target the underlying logic rather than the exact user-facing scenario) and must be documented in the B14 summary.
- If the bug **is reproduced:** Note any additional observations (e.g., intermittent behavior, specific conditions required, related error logs or stack traces).

### B3 — Investigate Root Cause

> **USE SEQUENTIAL THINKING:** Before dispatching explorers or concluding on root cause, invoke the `sequentialthinking` tool. Use it to identify the likely affected areas to investigate in parallel, form initial hypotheses, evaluate the evidence returned by the explorer agents, and revise if needed. Root cause analysis is non-linear — backtrack and explore alternative causes before committing to a conclusion. Do not proceed to B4 until the reasoning is complete.

> **THINK HARD:** Before concluding on root cause, think hard about whether the identified cause is necessary and sufficient to explain the observed behavior — could a different cause produce the same symptoms? A misdiagnosed root cause produces a fix that masks the symptom without resolving the underlying issue.

> **BOOTSTRAP FILE MEMORY:** Compute `MEM` via the recipe in `file-memory-protocol.md` §1 and `mkdir -p "$MEM/explorations"`. If `$MEM/work-item.md` does not exist, `Write` it (schema §3.1) with `work_type: bug`, `jira_key`, `title`, `status: in_progress`, `phase: B3`, `skill: bug-card`, and the bug's observed/expected behavior under `## Description`. Pass the absolute `MEM` path (as `memory_dir`) and a normalized `area_slug` to every explorer — each writes its own `$MEM/explorations/<area_slug>.md`. Track competing root-cause hypotheses in your `sequentialthinking` reasoning; the explorations capture the supporting/refuting `evidence`, and the confirmed root cause is recorded in the fix plan at B5.

- Identify all distinct areas of the codebase likely involved based on the **Affected Areas**, reproduction steps, and any logs or stack traces. Limit the scope of this exploration to the current project directory.
- Invoke a `codebase-explorer` sub-agent in **parallel** for each distinct hypothesis area in this project, providing:
    - The target area to explore
    - The question: "Does the code path for [observed behavior] exist here, and is there evidence of why it might be producing [incorrect behavior]? Look for recent changes, error handling gaps, and related tests."
    - The `memory_dir` (`$MEM`) and a normalized `area_slug` for the area. The explorer writes its findings to `$MEM/explorations/<area_slug>.md`.
    - The bug description, reproduction steps, and any logs for context
- Wait for all explorers to return. Each non-failed return contains a `File:` line with the exploration file name. `INCOMPLETE` means partial findings are present; consider re-spawning for the same area if coverage matters. `FAILED` means no file was written — re-spawn that explorer before proceeding.
- **Post-exploration enrichment:** Spawn the `area-mapper` sub-agent **in the background** (`run_in_background: true`) with the same `memory_dir` (`$MEM`). It crystallizes durable area knowledge from this run's exploration files into Serena project memory for future explorations. Do not wait for it.
- `Read` each `$MEM/explorations/<area_slug>.md` from the returns. If any file is missing or empty, re-spawn that explorer rather than treating missing data as confirmed. Surface any `open_questions` entries. If any identifies a connection to another area not already explored, dispatch a follow-up `codebase-explorer` (passing the same `memory_dir`) before proceeding.
- Synthesize the findings from the exploration files. Evaluate which areas show evidence of the root cause (cite the relevant `evidence` entries by `file` and `line_range`) and which hypotheses can be ruled out.
- Review git history for recent changes to affected areas (cross-reference the `affected_files` paths) that may have introduced a regression.
- Review related tests to understand why existing coverage did not catch this bug — look for `patterns` tagged with test concerns and `risks` flagging coverage gaps.

### B4 — Ask Clarifying Questions

**Objective:** Resolve any ambiguities, gaps, or risks before planning the fix.

**Agent Actions:**

1. Review all output from B0, B1, B2, and B3.
2. Identify clarifying questions. Mark each as `[BLOCKING]` or `[NICE TO HAVE]`.
3. Ask each question one at a time using `AskUserQuestion`. Include the `[BLOCKING]` or `[NICE TO HAVE]` tag in the question text. For open-ended questions, offer `Provide answer` / `Skip — non-blocking` (non-blocking only) and rely on the auto-injected "Other" for the typed answer. If there are no clarifying questions, state this in the chat and proceed.
4. Record all answers verbatim. Do not infer or invent answers.

> **REQUIRED:** All BLOCKING questions answered and answers recorded. Remaining unanswered questions listed as open items.

> **APPROVAL GATE — FULL STOP.** Use `AskUserQuestion` with header `B4 Approval`, options: `Approve and proceed (Recommended)` (description: "All blocking answers are accurate and recorded") / `Request changes` (description: "Something needs correction before continuing"). Do not proceed to B5 until approved.

> **COMPACTION GATE — B4:** Once B4 approval is confirmed, follow the Checkpoint & Compaction Contract above (gate path). Write `checkpoint.md` with `phase: B4`, `next_phase: B5`, `checkpoint_type: gate`, `references: [work-item.md, explorations/*.md]`; `## Decisions`: clarifying answers and the confirmed root-cause hypothesis; branch/head_sha: "none"/"n/a". Emit the Phase Summary block and instruct the user to run `/compact` before proceeding to B5.

### B5 — Create Fix Plan

> **USE SEQUENTIAL THINKING:** Before drafting the fix plan, invoke the `sequentialthinking` tool. Use it to confirm the root cause conclusion from B3 still holds under scrutiny (could a different cause produce the same observable behavior?), reason through the minimal change that addresses the root cause without introducing new bugs or side effects, consider whether the fix interacts with callers or dependents not directly implicated in B3, and evaluate the regression test strategy. Over-engineering and under-scoping are equally risky here — a fix that patches a symptom rather than the cause leaves the bug latent. Do not draft the plan until the reasoning is complete.

> **THINK HARD:** Before writing the fix plan, think hard about the blast radius of the proposed change — which callers, dependents, or edge-case paths might break if the fix is applied as drafted? A fix that is correct at the point of change but wrong at a caller is a new bug, not a resolved one.

> **FULL CONTEXT LOAD:** Before drafting the fix plan, `Glob $MEM` and `Read` every present input file — `work-item.md`, every `explorations/*.md`, `clarifications.md` and `related-cards.md` if present, and `summary.md` if this work came from `/implementation-discovery` (per `file-memory-protocol.md` §5). The confirmed root-cause analysis is captured as the **Root cause analysis** section of the fix plan written below (and persisted in `plan.md`'s `## Plan`); there is no separate root-cause file.

> **GENERATE A FLOWGRAPH (best-effort):** Produce a Mermaid `flowchart` that contrasts the buggy path with the fixed path — show the root-cause flow (how the bug is triggered) alongside the corrected flow (how the fix intercepts it). Keep it focused on the specific files/functions implicated by the root cause analysis.
>
> - **Skip it** for trivial single-line fixes where a diagram adds no clarity. If skipped, state in one line why.
> - **Render it in the chat** as part of the fix plan presentation at B6.
> - **Embed it in the Jira description under `## Architecture`** as a ` ```mermaid ` fenced block, immediately after `## Affected Areas`. If the description lacks an `## Architecture` section, add one using `jira_update_issue` (additive edit — update only that section). (Jira Cloud does not render Mermaid natively; it will display as a code block, which is acceptable.) If skipped, set the Architecture section to "None — no diagram for this change."
> - **Record the Mermaid source** for the `## Flowchart` section of `plan.md`, written after plan-reviewer approval below. B10 reads `plan.md ## Flowchart` as a surgical guide.

**REQUIRED:** The plan must include ALL of the following:

- **Root cause analysis** — a clear explanation of why the bug occurs
- The proposed fix and rationale
- Files to create or modify
- Regression test strategy: the failing test to write in B9 and the additional coverage expected from the dedicated `test-reviewer` sub-agent
- Documentation expectations for the dedicated `documentation-reviewer` sub-agent (inline docs, repository docs, and whether separate `/document-card` follow-up is likely needed)

**REQUIRED: Review the plan before posting.** Verify:

- Does the root cause analysis accurately explain the bug based on the investigation in B3?
- Does the proposed fix directly address the root cause without introducing new issues?
- Is every affected area accounted for?
- Are there any missing steps, gaps in logic, or unstated assumptions?
- Are the regression and follow-up test scenarios comprehensive enough to prevent recurrence, including edge cases?
- Do the documentation expectations cover all likely affected surfaces?
- Is the plan consistent with the codebase patterns and architecture observed in B3?
- Are there any risks or dependencies not addressed?

If the review reveals issues, revise the plan before posting. Do not post an unreviewed plan.

**Independent plan review:**

Once the self-review is clean, invoke the `plan-reviewer` sub-agent, providing:

- The proposed fix plan
- The fix criteria from the Bug Details
- The affected areas from the Bug Details and B3 investigation
- The Patterns & Code References section from the card (the conventions the fix should follow)
- The codebase findings from B3 (patterns, conventions, and architectural context)
- The Jira issue key and work type (bug)

The sub-agent will return a structured findings report with an overall verdict of either **APPROVED** or **CHANGES REQUIRED**.

- If **APPROVED**:

    > **WRITE plan.md:** `Write $MEM/plan.md` (schema §3.3) with frontmatter `plan_type: fix_plan`, `status: approved`, and `files_to_change` (all files to create or modify), and body sections `## Plan` (the full reviewed fix plan text including the root-cause analysis, verbatim — do not summarize or truncate), `## Flowchart` (the raw Mermaid source showing buggy vs. fixed path, or omit the section if skipped), `## Testing expectations` (the regression-test strategy + follow-up coverage, verbatim), and `## Documentation expectations` (verbatim). This file is what the B6 and B10 checkpoints reference, and B10 reads `## Flowchart` as a surgical guide. If the plan was revised during the review loop, write the **final approved** plan text.

    Draft a single combined Jira comment with the exact heading `**B5/B6 — Fix Plan & Approval Request**` for the comment review below. This comment must include:

    - The reviewed fix plan
    - Architecture diagram (under `### Architecture` — the Mermaid source showing buggy vs. fixed path, or a note if skipped)
    - Regression test strategy for B9 and follow-up test expectations for the `test-reviewer` sub-agent
    - Documentation expectations for the `documentation-reviewer` sub-agent
    - Risks, dependencies, or open items that affect execution
    - `Approval requested: Please approve this fix plan before work begins.`

- If **CHANGES REQUIRED**: address every Critical and Major finding, revise the plan, then invoke the `plan-reviewer` sub-agent again. Repeat until the verdict is APPROVED.
- **Max 3 review iterations.** If the plan-reviewer returns CHANGES REQUIRED after 3 iterations, write `plan.md` (same as the APPROVED path above, using the current plan text with frontmatter `status: review_escalated`), draft the same combined `B5/B6` comment with the outstanding findings noted, and proceed to the comment review below.

**Independent comment review:**

Once the comment body is drafted, invoke the `comment-reviewer` sub-agent, providing:

- The drafted comment body verbatim, exactly as it will be passed to `jira_add_comment`
- The phase label `B5/B6 — Fix Plan & Approval Request`
- The reviewed fix plan and fix criteria
- The Jira issue key

The sub-agent will return a structured report with an overall verdict of either **APPROVED** or **CHANGES REQUIRED**.

- If **APPROVED**: call `jira_add_comment` with the reviewed body, then proceed to B6.
- If **CHANGES REQUIRED**: address every Critical and Major finding, revise the draft, then invoke `comment-reviewer` again with the updated body. Repeat until the verdict is APPROVED.
- **Max 3 review iterations.** If `comment-reviewer` returns CHANGES REQUIRED after 3 iterations, post the comment as-is with the remaining minor findings noted inline at the bottom of the comment body, and continue to B6.

Do not call `jira_add_comment` until `comment-reviewer` returns APPROVED (or the 3-iteration cap is reached). A passing plan-reviewer verdict, a clean self-check, or memory of having run `comment-reviewer` earlier in the workflow does not substitute.

### B6 — Await Plan Approval

---

**APPROVAL GATE -- FULL STOP.**

- The approval request Jira record is the combined `B5/B6` comment already posted in B5. Do not post a second Jira comment here unless the plan changed.
- **Present the full fix plan in the chat output.** The user should not have to open Jira to review it — display it here before asking for approval.
- Then use `AskUserQuestion` with header `B6 Approval`, options: `Approve and proceed (Recommended)` (description: "Fix plan is accurate — begin implementation") / `Request changes` (description: "Revise the plan before proceeding"). Do not poll Jira for approval.
- If the user selects "Request changes", revise the plan, repost the full combined `B5/B6` comment to Jira, and re-`Write $MEM/plan.md` with the updated plan text (whole-file overwrite). Then use `AskUserQuestion` again.
- Only proceed to B7 after "Approve and proceed" is selected.

> **REGENERATE DASHBOARD:** After approval, regenerate `$MEM/work-item.html` from the current memory files (per `file-memory-protocol.md` §8) so the user has an up-to-date rendered view of the approved fix plan and flowchart.
>
> **COMPACTION GATE — B6:** Once B6 approval is confirmed, follow the Checkpoint & Compaction Contract above (gate path). Write `checkpoint.md` with `phase: B6`, `next_phase: B7`, `checkpoint_type: gate`, `references: [plan.md, work-item.md, explorations/*.md]`; `## Decisions`: approved fix plan (one-line summary); `approval_condition`: verbatim user selection; branch/head_sha: "none"/"n/a". Emit the Phase Summary block and instruct the user to run `/compact` before proceeding to B7.

---

### B7 — Verify Working Branch

- Run `git branch --show-current` and report the current branch to the user.
- Use `AskUserQuestion` with header `Working Branch`, options: `Confirm — this is the correct branch (Recommended)` (description: "Proceed with the fix on this branch") / `Wrong branch — switching now` (description: "I need to switch to the correct branch before continuing"). If the user selects "Wrong branch", halt and wait for them to switch manually, then verify again.

### B8 — Baseline Verification

- Invoke the `verification-runner` sub-agent with phase context `baseline` and the build/test/lint commands if already known. It returns a `VERIFICATION REPORT` with a per-category verdict and, for any failures, the failing targets and excerpts.
- **All checks must pass before continuing.** If the report returns `FAILURES`, investigate and resolve them using the failing targets and excerpts from the report. Re-invoke `verification-runner` after fixing. Do not begin the fix until it returns `ALL GREEN`.

### B9 — Write a Failing Test

- Before writing the fix, create a test (or tests) that reproduces the bug in code.
- Run the new test and confirm it **fails for the expected reason.**
- This test serves as both proof of the bug and a permanent regression guard.
- This phase establishes the minimum regression proof. The dedicated `test-reviewer` sub-agent in B10 will expand the coverage after the fix is implemented.
- If the bug cannot be directly reproduced in an automated test (e.g., UI-only behavior, timing-dependent race condition), write a test that targets the underlying logic flaw identified in B3 as closely as possible. Document the test limitation in the B14 summary (Tests added/updated field) — note what the test covers, what it does not, and why a more direct reproduction test was not feasible.

### B10 — Implement the Fix

**ALL of the following are REQUIRED. Do not skip any category.**

- **Full context load:** Before applying the fix, `Glob $MEM` and `Read` `plan.md` (full — `## Plan`, `## Flowchart`, `files_to_change`, testing/doc expectations), every `explorations/*.md`, `work-item.md`, and any `clarifications.md`/`related-cards.md` present (per `file-memory-protocol.md` §5). Use `plan.md ## Flowchart` (buggy-path vs. fixed-path) as a surgical guide — apply the fix exactly where the flow deviates, and verify the corrected path after each change. If no flowchart was persisted (skipped in B5), proceed without it.
- **Code:** Apply the fix according to the plan from B5.
- **Testing handoff:** Keep the implementation and the B9 regression test in a state that the dedicated `test-reviewer` sub-agent can extend and run deterministically. Note any commands, fixtures, or setup that sub-agent will need.
- **Documentation handoff:** Identify the public APIs, configuration surfaces, and repository docs the dedicated `documentation-reviewer` sub-agent must cover.
- Follow existing code style, conventions, and architectural patterns observed in B3.

> **SERENA-FIRST EDITING RULE:** When modifying existing source code to apply the fix, prefer Serena's symbol-aware tools over native `Edit`. Symbol-aware edits produce cleaner diffs, are robust against whitespace or context drift, and — for rename and delete — update references atomically. This matters especially for bug fixes, where the change must be surgical and must not introduce new regressions in adjacent callers.
>
> 1. **Map first.** Use `get_symbols_overview` on the target file to understand its structure before editing.
> 2. **Locate the target.** Use `find_symbol` to jump to the exact symbol implicated by the root cause. Use scoped paths (`ClassName/methodName`) when multiple symbols share a name.
> 3. **Check blast radius.** Run `find_referencing_symbols` on any symbol whose signature or semantics you are changing. A fix that breaks a caller is a new bug.
> 4. **Apply the edit with the right tool:**
>     - **Replacing the body of an existing method, function, or field initializer:** use `replace_symbol_body`.
>     - **Adding a guard clause, helper, or new method next to an existing symbol:** use `insert_after_symbol` or `insert_before_symbol`.
>     - **Renaming a symbol:** use `rename_symbol` — it rewrites the declaration and every reference in one operation.
>     - **Removing a symbol:** use `safe_delete_symbol` — it refuses the delete when callers still exist, preventing broken references.
> 5. **Reserve native `Edit` for:**
>     - Comments, imports, or annotations outside any symbol body
>     - Non-code files (YAML, JSON, markdown, properties, gradle, build scripts)
>     - Multi-symbol or cross-file text edits that the symbol tools cannot express
>     - New files authored from scratch (use `Write` for those)

**REQUIRED: Review the implementation before proceeding.** Verify:

- Does the fix directly and completely address the root cause identified in B3?
- Does the implementation follow the approved fix plan from B5?
- Does the fix avoid introducing new bugs, side effects, or regressions?
- Does every code change follow the project's established code style and architectural patterns, including the **Patterns & Code References** named on the card?
- Is error handling comprehensive?
- Are there any code smells, dead code, or hardcoded values that should be configurable?
- Does the regression test from B9 accurately reproduce the original bug?
- Would the dedicated `test-reviewer` sub-agent be able to add comprehensive regression coverage without redesigning the fix?
- Have all documentation surfaces affected by the fix been identified for the dedicated `documentation-reviewer` sub-agent?
- Are there any leftover TODOs, commented-out code, or debugging artifacts?

Fix any issues found in the self-review before invoking the reviewer.

**Independent review loop:**

Once the self-review is clean, invoke the `implementation-reviewer` sub-agent, providing:

- The full diff of all changed files
- The approved fix plan from B5
- The fix criteria from the Bug Details
- The codebase findings from B3 (patterns, conventions, and architectural context)
- The Jira issue key

The sub-agent will return a structured findings report with an overall verdict of either **APPROVED** or **CHANGES REQUIRED**.

- If **APPROVED**: continue with the dedicated testing and documentation completion loops below.
- If **CHANGES REQUIRED**: address every Critical and Major finding, then invoke the `implementation-reviewer` sub-agent again with the updated diff. Repeat until the verdict is APPROVED.
- **Max 3 review iterations.** If the implementation-reviewer returns CHANGES REQUIRED after 3 iterations, use `AskUserQuestion` with header `Reviewer Escalation`, options: `Apply the changes manually and continue` (description: "I'll address the remaining findings — continue after I confirm") / `Skip and continue anyway` (description: "Accept the outstanding findings and proceed to testing") / `Abort` (description: "Stop the workflow here"). Present the outstanding findings before the question so the user can make an informed decision.

Do not proceed to the dedicated completion loops until the implementation-reviewer returns an APPROVED verdict.

**Dedicated test completion loop:**

Invoke the `test-reviewer` sub-agent, providing:

- The branch name and base branch — the reviewer fetches the diff itself via `git diff <base-branch>..HEAD`. Do not paste the full diff inline.
- The approved fix plan from B5, especially the regression-test strategy
- The fix criteria from the Bug Details
- The codebase findings from B3, especially testing conventions and nearby test structure
- The baseline verification results from B8, if they identify canonical test commands
- The regression-test context from B9
- The Jira issue key

The sub-agent will add or update tests as needed, run the relevant test commands, and return a structured report with a status of either **COMPLETE** or **FAILED**.

- If **COMPLETE**: review the report. If it changed any non-test files, invoke the `implementation-reviewer` again with the updated diff before continuing.
- If **FAILED**: use `AskUserQuestion` with header `Test Reviewer Failed`, options: `Apply a manual fix and retry` (description: "I'll address the test failures — continue after I confirm") / `Skip and continue` (description: "Proceed to documentation with the current test state") / `Abort` (description: "Stop the workflow here"). Present the failure report before the question.

**Dedicated documentation completion loop:**

Invoke the `documentation-reviewer` sub-agent, providing:

- The branch name and base branch — the reviewer fetches the diff itself via `git diff <base-branch>..HEAD`. Do not paste the full diff inline.
- The approved fix plan from B5, especially the documentation expectations
- The fix criteria from the Bug Details
- The codebase findings from B3, especially documentation conventions and nearby docs
- The Jira issue key

The sub-agent will update inline and repository documentation as needed and return a structured report with a status of either **COMPLETE** or **FAILED**.

- If **COMPLETE**: proceed to B11.
- If **FAILED**: use `AskUserQuestion` with header `Doc Reviewer Failed`, options: `Apply a manual fix and retry` (description: "I'll address the documentation gaps — continue after I confirm") / `Skip and continue` (description: "Proceed to B11 with the current documentation state") / `Abort` (description: "Stop the workflow here"). Present the failure report before the question.
- If the report says user-facing documentation follow-up is `REQUIRED`, record that in B14 and recommend running `/document-card` after this workflow completes.

Do not proceed to B11 until `implementation-reviewer`, `test-reviewer`, and `documentation-reviewer` have all completed successfully.

> **COMPACTION GATE — B10:** Once all three reviewers are complete, follow the Checkpoint & Compaction Contract above (gate path). Write `checkpoint.md` with `phase: B10`, `next_phase: B11`, `checkpoint_type: gate`, `reviewer_iterations: { impl: N, test: N, doc: N }`, `references: [plan.md, explorations/*.md, work-item.md]`; `## Decisions`: fix implementation summary and any plan deviations; `approval_condition`: reviewer verdict. Emit the Phase Summary block and instruct the user to run `/compact` before proceeding to B11.

### B11 — Post-Fix Verification

- Invoke the `verification-runner` sub-agent with phase context `post-implementation`, the build/test/lint commands from B8, and specific assertions: the failing test from B9 must now pass, and any additional tests written by `test-reviewer` must pass.
- **All checks must pass.** If the report returns `FAILURES`, fix the failures and re-invoke `verification-runner`. Repeat until it returns `ALL GREEN`.
- Re-run the original **Steps to Reproduce** and confirm the bug no longer occurs. (If the Steps to Reproduce are manual-only, perform them yourself or ask the user — this step is not delegated to `verification-runner`.)

### B12 — User Testing

---

**APPROVAL GATE — USER MUST MANUALLY TEST BEFORE PROCEEDING. AUTO MODE DOES NOT BYPASS THIS GATE.**

- Draft a Jira comment with the exact heading `**B12 — User Testing Handoff**` as the verbatim first line — character-for-character, using `**bold**` (not a `##` markdown heading), and never a descriptive substitute such as "Fix complete" or "Ready for QA". The comment must include, in this exact order with these exact labels:

    - The branch name
    - A summary of what was fixed
    - **Fix Criteria & Testing Steps:** For each expected behavior item from the Bug Details and fix plan, a numbered section with:
        - The criterion/expected behavior restated clearly
        - Step-by-step instructions to verify it now works correctly

**Independent comment review:**

Once the comment body is drafted, invoke the `comment-reviewer` sub-agent, providing:

- The drafted comment body verbatim, exactly as it will be passed to `jira_add_comment`
- The phase label `B12 — User Testing Handoff`
- The branch name and fix criteria
- The Jira issue key

The sub-agent will return a structured report with an overall verdict of either **APPROVED** or **CHANGES REQUIRED**.

- If **APPROVED**: call `jira_add_comment` with the reviewed body.
- If **CHANGES REQUIRED**: address every Critical and Major finding, revise the draft, then invoke `comment-reviewer` again with the updated body. Repeat until the verdict is APPROVED.
- **Max 3 review iterations.** If `comment-reviewer` returns CHANGES REQUIRED after 3 iterations, post the comment as-is with the remaining minor findings noted inline at the bottom of the comment body, and continue.

Do not call `jira_add_comment` until `comment-reviewer` returns APPROVED (or the 3-iteration cap is reached). A clean self-check or memory of having run `comment-reviewer` earlier in the workflow does not substitute.

- Present the same testing handoff in the chat — the user should not have to open Jira to see what to test.
- Pause the workflow here and wait. Do not call any tool other than `AskUserQuestion` until the user reports back with an explicit selection. Do not infer approval from silence, from a `continue` keyword, from prior phase success, or from Auto Mode.
- Use `AskUserQuestion` with header `B12 Testing`, options: `Approve — I ran through every step above and the fix works as expected (Recommended)` (description: "I have manually tested the fix and it works correctly") / `Issues found` (description: "One or more problems were found during testing"). Do not proceed until the user selects an option.
- If the user's message accompanying the approval suggests they have NOT actually run through the steps (e.g. "looks good", "go ahead", "skip", "sure", "proceed"), re-ask the question once and require an explicit testing-was-done confirmation. Treat ambiguous approval as the "Issues found" branch until confirmed otherwise.

- If the user identifies issues: for each distinct issue, invoke the `issue-intake` skill (via the `Skill` tool), passing a brief description of the observed behavior, expected behavior, and this bug's Jira key as args (e.g. `"Testing found: [description]. Related to: [PROJ-KEY]"`). Work through the issue-intake I0–I6 process with the user to document and triage each issue — it will create a Jira card (Bug or Missing Requirement) for each one. After all issues are documented and their Jira cards are created, return to B10, resolve each issue, re-run B11, and return to this step before proceeding.

---

### B13 — Commit and Push

**PRECONDITION — verify in the chat before running any git command.** State each check and its result before staging anything. If any check fails, STOP and return to B12.

1. The user explicitly selected the "Approve" option at B12 in this conversation. Quote their selection verbatim.
2. No issues were reported by the user after that selection that have not since been addressed and re-approved.
3. The current branch matches the branch confirmed at B7.

Execute the following steps **one at a time, in order**. Report the outcome of each step in the chat before starting the next. Do not pre-batch these into a single tool call sequence — the user must be able to interrupt between any two steps:

**Step 1 — Stage and commit.** Stage all changes and commit with this message format:

```
[{PROJECTKEY}-{ISSUENUMBER}] <concise description of what was fixed>
```

Example: `[PROJ-5678] Fix null pointer when looking up user with missing profile`

Use imperative mood. Report the commit hash in the chat before proceeding.

**Step 2 — Push the working branch.** Push using `git push origin <branch-name>`. Do not use refspecs. Report the push result before proceeding.

**Step 3 — No Jira transitions here.** Any Jira status transition is part of B14, not B13. Do not transition the issue status from this phase.

### B14 — Summary of Changes

**ALL fields below are REQUIRED. Do not skip any field. If a field does not apply, explicitly state "N/A" with a brief reason.**

Post a comment on this Jira issue with the exact heading `**B14 — Summary of Changes**` as the verbatim first line of the comment body — character-for-character, using `**bold**` (not a `##` markdown heading), and never a descriptive substitute such as "Implementation complete" or "Fix summary".

Begin the comment body with a metadata block: `**Branch:** <branch-name>` and `**Commit:** <commit-hash>`, followed by a `----` horizontal rule.

Then render **every** field below as a bold-labeled section (`**Field name:**`), in this exact order, using these exact field names. Do not rename, merge, reorder, drop, or add fields.

- **Root cause:** Clear, concise explanation of what caused the bug.
    
- **What was fixed:** Overview of the changes made to resolve the issue.
    
- **Files changed:** List of files created, modified, or deleted.
     
- **Tests added/updated:** Summary of new or modified test coverage, including the regression test from B9 and any expansion completed by `test-reviewer`.
     
- **Documentation added/updated:** Summary of any doc changes, and whether additional user-facing documentation requires a `/document-card` follow-up.
    
- **Deviations from plan:** Any differences between the B5 fix plan and what was actually implemented, with reasons.
    
- **Release note:** If the fix is user-facing, include a 1–2 sentence plain-language release note. If purely internal, state "N/A — internal change."

- **Open items:** Follow-up work, known limitations, or unresolved questions.
    

**REQUIRED: Review the summary before posting.** Confirm (1) the first line is exactly `**B14 — Summary of Changes**` in `**bold**` format, (2) the metadata block (`**Branch:**` / `**Commit:**`) is present before the `----` rule, and (3) every mandated field appears as a `**Label:**` section in the specified order with none renamed, dropped, or substituted. If any check fails, rewrite before posting.

**Independent comment review:**

Once the summary body is drafted, invoke the `comment-reviewer` sub-agent, providing:

- The drafted comment body verbatim, exactly as it will be passed to `jira_add_comment`
- The phase label `B14 — Summary of Changes`
- The branch name, commit hash, and files-changed list
- The Jira issue key

The sub-agent will return a structured report with an overall verdict of either **APPROVED** or **CHANGES REQUIRED**.

- If **APPROVED**: call `jira_add_comment` with the reviewed body.
- If **CHANGES REQUIRED**: address every Critical and Major finding, revise the draft, then invoke `comment-reviewer` again with the updated body. Repeat until the verdict is APPROVED.
- **Max 3 review iterations.** If `comment-reviewer` returns CHANGES REQUIRED after 3 iterations, post the comment as-is with the remaining minor findings noted inline at the bottom of the comment body, and continue.

Do not call `jira_add_comment` until `comment-reviewer` returns APPROVED (or the 3-iteration cap is reached). A clean self-check or memory of having run `comment-reviewer` earlier in the workflow does not substitute.

> **REGENERATE DASHBOARD (B14):** After the B14 summary comment is posted, regenerate `$MEM/work-item.html` (per `file-memory-protocol.md` §8) so the user has a final rendered view. Optionally `Write $MEM/summary.md` (`summary_type: changes`) with the summary body first so the dashboard's Summary section is populated.

### B15 — Cleanup

- Remove the work item's file-memory directory in one atomic operation: `rm -rf "$MEM"` (Bash). This deletes `work-item.md`, `checkpoint.md`, `plan.md`, all `explorations/*.md`, `work-item.html`, and anything else under it — nothing to enumerate, nothing missed. Do not retain investigation state once it has been materialized into Jira comments.

---

## Completion Criteria

This workflow is complete when **all** of the following are true:

- All phases executed in sequence (B0 through B15)
- All approval gates explicitly confirmed in the chat
- Fix plan reviewed and approved (B5/B6)
- All fix commits pushed (B13)
- Build, tests, and linters passing on the fix branch (B11)
- Regression test written and passing (B9)
- User testing completed and approved at B12; the B12 approval was captured before any commit or push was made
- Commit, push, and any Jira transition each ran as discrete user-visible steps, not as a single chained sequence
- All Jira comments posted by this workflow (B5/B6, B12, B14) were reviewed by `comment-reviewer` and returned APPROVED (or reached the 3-iteration cap) before `jira_add_comment` ran
- B14 summary comment posted using the exact `**B14 — Summary of Changes**` heading and the full mandated field set in order
- B12 handoff comment posted using the exact `**B12 — User Testing Handoff**` heading
- File-memory directory removed (`rm -rf "$MEM"`) (B15)
