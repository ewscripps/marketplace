# AUTO QA TASK WORKFLOW — EXECUTION CONTRACT

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute phases in strict sequential order (AQ0 through AQ6).
2. Do not skip, reorder, or combine phases.
3. Never transition or modify an issue the user didn't ask about — always confirm the source issue key with the user if there's any ambiguity.
4. Nothing in AQ2 (create), AQ3 (link), or AQ4 (transition) may run until the AQ1 confirmation gate is explicitly approved in this same session.

**CLARIFICATION RULE:** Do not assume anything. If required information is missing, ambiguous, or conflicting, stop and use `AskUserQuestion` to ask the user before proceeding.

---

### AQ0 — Identify the Source Issue

- If an issue key was passed as `$ARGUMENTS` (e.g. `WEBCMS-1234`), use it.
- Otherwise, infer it from context, in this order: a key mentioned earlier in the conversation, the current git branch name (`git branch --show-current` — issue keys are usually embedded, e.g. `feature/WEBCMS-1234-fix-nav`), or the most recent commit message (`git log -1 --format=%s`).
- If you cannot confidently determine the issue key, ask the user for it via `AskUserQuestion`. Do not guess.

### AQ1 — Fetch the Source Issue and Confirm the Plan

Call `jira_get_issue` for the source key. You need:

- **`project_key`** — the QA Task is created in the same project as the source issue.
- **The epic/parent association**, if any. This site uses the `parent` field for Child Work Item relationships (team-managed projects) in some projects and a classic "Epic Link" custom field in others — read whichever the source issue actually has and note which one it is; do not assume. If the source issue has neither, proceed without one and mention that to the user.
- **`summary`** and **`description`** to carry over.
- **Labels/components**, if present — carry these over too so the QA Task shows up in the same filters/boards as the dev task.

**APPROVAL GATE — FULL STOP.** Present a short plan to the user: the QA Task summary and project it will be created in, the epic/parent it will carry over (or "none"), and that the source issue will be transitioned to "Dev Complete" once linked. Use `AskUserQuestion` with header `Confirm QA Handoff`, options: `Create QA Task and mark Dev Complete (Recommended)` (description: "Proceed with the plan above") / `Cancel` (description: "Stop here — do not create or transition anything"). Do not proceed to AQ2 until the user selects the first option.

### AQ2 — Create the QA Task

Call `jira_create_issue` with:

- `project_key`: from AQ1
- `issue_type`: `"QA Task"`
- `summary`: `"QA: " + <source summary>` (keep the original summary intact after the prefix so search/filtering still matches)
- `description`: the source issue's description, followed by a short note:
  ```
  Cloned from <SOURCE-KEY> for QA verification.

  ---
  <original description>
  ```
- `additional_fields`: set the same epic/parent field identified in AQ1 (using whichever field — `parent` or the Epic Link custom field — the source issue actually used), plus the same labels/components if the source had them.

If `jira_create_issue` rejects a field (e.g. "QA Task" requires a field not set here), do not guess a different field name — stop and report the exact error to the user rather than retrying blindly.

### AQ3 — Link the Two Issues with "Tests"

"Tests" is the relationship phrase shown in the Jira UI, not necessarily a link type's literal name — on the ewscripps site the underlying link type is named **"Testing (task)"** (inward: "is tested by", outward: "tests"). Note there is also a distinct "Testing" link type (outward: "was found when testing") — that one is for bug-discovery relationships, not this QA hand-off; don't use it by mistake.

Call `jira_create_issue_link` with:

- `link_type`: `"Testing (task)"`
- `outward_issue_key`: the new QA Task's key (the one performing the "tests" relationship)
- `inward_issue_key`: the source dev task's key

If the call is rejected because this Jira project uses a different link type name for the same "Tests" relationship, do not guess — stop and ask the user rather than picking the closest-sounding type.

### AQ4 — Transition the Source Issue to "Dev Complete"

Call `jira_get_transitions` for the source issue key and find the transition whose name is exactly (case-insensitive) "Dev Complete".

- If found, call `jira_transition_issue` with that transition's id.
- If not found (the issue's current workflow status may not allow it directly), do not force it or pick the closest-sounding transition. Instead, list the transitions that are available and ask the user which one to use, or report that "Dev Complete" isn't reachable from the current status.

### AQ5 — Confirm on Jira

Call `jira_add_comment` on the source issue noting the QA Task was created, e.g. "QA Task \<QA-KEY\> created for verification."

### AQ6 — Report

Tell the user, in plain text (no file or artifact needed):

- The new QA Task's key and a link (`https://ewscripps.atlassian.net/browse/<KEY>`)
- That it's linked to the source issue via "Tests"
- That the source issue was transitioned to "Dev Complete" (or, if AQ4 couldn't complete, what's blocking it)

## Notes

- If the user wants a different summary prefix, naming convention, or wants labels/components excluded, follow their explicit instruction over the defaults above.
