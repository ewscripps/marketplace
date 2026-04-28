# MR CREATION WORKFLOW — EXECUTION CONTRACT

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute phases in strict sequential order (M0 through M6).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure in the chat. Do not continue.
5. Every required output must be presented in the chat before the phase is considered complete.
6. Do not create the MR until M4 is reached and explicitly approved.

**SCOPE:** This workflow only targets GitLab merge requests. If the repository's remote URL does not point to GitLab, stop immediately and report the mismatch in the chat. Do not attempt to create a pull request on any other platform.

**KNOWLEDGE GRAPH SCOPE:** The knowledge graph in this workflow accumulates Jira context (M1), commit and diff data (M2) so that M4 can assemble a grounded MR description. The graph is session-scoped -- do not rely on it persisting to a future session.

**APPROVAL GATE BEHAVIOR:** Approval gates are chat-scoped. If explicit approval is not captured before the session ends or context is lost, stop at the gate. On resume, re-present the latest MR preview and ask for confirmation again. Never assume a pending approval was granted.

**CLARIFICATION RULE:** Do not assume anything. If required information is missing, ambiguous, conflicting, or underspecified, stop and ask the user for clarification before proceeding.

**TOOL PREFERENCE:** Prefer native tools over Bash for filesystem work. All filesystem, search, and directory operations must stay within the current project directory.

- **File I/O (read, write, edit a known file):** Use native `Read`, `Write`, `Edit`.
- **File discovery (find files by name or pattern):** Use native `Glob`.
- **Content search (find text inside files):** Use native `Grep`. For symbolic code search (finding classes, methods, or callers), delegate to the `codebase-explorer` agent, which uses the Serena MCP server.
- **Directory operations (list, metadata, move, mkdir):** Use Bash (`ls`, `stat`, `mv`, `mkdir -p`).
- **Git:** Use `Bash` for all git operations (`git status`, `git diff`, `git log`, `git push`, `git pull`, `git merge`, etc.) and for running build, test, and lint commands.

**TASK TRACKING:** Always use task tracking (`TaskCreate`/`TaskUpdate`) so progress is visible throughout. Create one task per phase at the start of the workflow. Mark each task `in_progress` when starting the phase and `completed` when the phase is done:

- M0 — Branch Collection & Pre-flight
- M1 — Context Classification
- M2 — Diff & Commit Review
- M3 — Pre-Creation Confirmation
- M4 — Description Generation & Review Gate
- M5 — MR Creation
- M6 — Cleanup

---

### M0 — Branch Collection & Pre-flight

**Agent performs automatically before asking anything:**

- Inspect the repository's remote URL and confirm it points to GitLab (either `gitlab.com` or a known GitLab self-hosted domain). If the remote URL does not point to GitLab, stop and report the mismatch in the chat.

**Ask the following questions:**

1. What is the **source branch** (the branch containing your changes)?
2. What is the **destination branch** (the branch you are merging into, e.g. `main`, `develop`)?

**Agent performs automatically after branches are provided:**

- Verify the source branch exists in the repository.
- Verify the destination branch exists in the repository.
- Confirm the source branch has commits ahead of the destination branch.

> **REQUIRED:** If the GitLab remote check or any pre-flight check fails, stop and report the specific failure in the chat. Do not proceed until the issue is resolved.

---

### M1 — Context Classification

**Ask:** Is this MR for a **release** or a **non-release** (feature, bug fix, tech debt, etc.)?

#### If RELEASE:

1. Ask: Is there a related **release tracked in Jira**?
    - If yes: Ask for the Jira **Fix Version** name used to track the release.
    - If the team also uses a release-tracking Epic or Task, ask for that Jira key separately as optional context.
    - Fetch all child work items (Stories, Tasks, Bugs) associated with that Fix Version in Jira.
    - Review the commits in the source branch and verify that all work items from the release are represented.
    - Report any Jira items that appear missing from the branch and ask the user how to proceed before continuing.
2. Confirm the source branch name follows the release naming convention (e.g. `release/x.x.x`). Flag if it does not.

#### If NON-RELEASE:

1. Ask: Is there a related **Jira card**?
    - If yes: Ask for the Jira card key (e.g. `PROJ-123`).
    - Fetch the Jira card details (type, summary, description, status).
    - If the card is an **Epic**: fetch all child items and verify they are reflected in the branch commits. Report any that appear missing.
    - If the card is a **Task or Bug**: review the commits and confirm the work aligns with the card's summary and description. Flag any significant discrepancies.
2. Confirm the source branch name includes the Jira card key (e.g. `feature/PROJ-123-short-description`). Flag if it does not.

> **USE KNOWLEDGE GRAPH:** Write each retrieved Jira item to the knowledge graph. For releases, create a `release` node with properties: `name`, `fix_version`, and `tracking_issue_key` (optional). For non-releases, create a `jira_item` node with properties: `jira_key`, `type`, `summary`, `status`. Link items to an `mr` root node representing this MR. M4 reads these nodes to populate the Related Jira Items section of the description.

> **REQUIRED:** Present all of the following in the chat before proceeding:
> 
> - Confirmed type: release or non-release
> - Jira Fix Version / release-tracking issue details retrieved (or explicitly "none provided")
> - Branch naming assessment: compliant or flagged with reason
> - Any missing Jira items, with explicit user confirmation on how to proceed

---

### M2 — Diff & Commit Review

**Agent performs automatically:**

- Retrieve the full list of commits between the source and destination branch.
- Retrieve a summary of file changes (files added, modified, deleted).
- Identify the scope of changes (services, modules, or areas of the codebase affected).

> **USE KNOWLEDGE GRAPH:** Write the diff data to the knowledge graph. Create a `commit` node for each commit with properties: `hash`, `message`, `affected_area`. Create a `diff_summary` node with properties: `files_added`, `files_modified`, `files_deleted`, `affected_areas` (list). Link all nodes to the `mr` root node. M4 reads commit and diff nodes to build the Summary and Changes sections of the description — this ensures every change is accounted for and nothing is invented.

> **REQUIRED:** Present a structured diff summary in the chat before proceeding:
> 
> - Total number of commits
> - Files added, modified, and deleted (with counts)
> - Affected areas of the codebase (services, modules, components)

---

### M3 — Pre-Creation Confirmation

**Agent confirms automatically:** Verify that all context from M0–M2 (branches, Jira items, diff summary) is complete and ready for description generation. If anything is missing, stop and resolve before proceeding.

---

### M4 — Description Generation & Review Gate

> **USE SEQUENTIAL THINKING:** Before generating the description, invoke the `sequentialthinking` tool. Use it to trace each commit to a purpose, reconcile the diff summary (M2) with the Jira context (M1), determine what belongs in the Summary vs. Changes sections, and verify that no invented or assumed items are included. Build the description bottom-up from evidence, not top-down from assumption. Do not begin writing the description until the reasoning is complete.

> **USE KNOWLEDGE GRAPH:** Read all nodes from the graph — `commit`, `diff_summary`, `jira_item` / `release`, and `mr` — to assemble the description. The Summary section should synthesize the diff and Jira context. The Changes list should be derived from commit nodes. The Related Jira Items section should be read directly from Jira item nodes. This ensures the description is fully grounded in structured evidence and not reconstructed from memory.

**Agent generates the MR description using the following structure:**

```
## Summary
[Agent-generated summary of changes based on commit history, file diffs,
and Jira card or release context — describes WHAT changed and WHY]

## Changes
- [Bullet list of meaningful changes derived from commits and file diffs]

## Related Jira Items
- [PROJ-123] Card Title — Status
- [PROJ-456] Card Title — Status
(or "No related Jira items" if none provided)

## Testing Notes
[Areas that may need focused review based on scope of changes —
e.g. impacted services, risky refactors, migrations, or configuration changes]

## Checklist
- [ ] Code compiles and passes existing tests
- [ ] No unintended files included (e.g. local configs, debug code)
- [ ] Branch is up to date with destination branch
- [ ] MR is correctly scoped (no unrelated changes)
```

**REQUIRED: Review the description before presenting.** Verify:

- Summary accurately reflects the diff and Jira context from M2 and M1
- Changes list is grounded in actual commits — no invented or assumed items
- Related Jira items match exactly what was retrieved in M1
- Testing Notes identify genuinely risky or complex areas
- No placeholder text remains in any field

**DESCRIPTION FORMATTING:** The description must be clean, renderable markdown with real line breaks. Do not use escaped newline sequences (`\n`, `\\n`) anywhere in the description string. When the description is passed to the MR creation tool in M5, it must contain actual newlines — not escape sequences that render as literal `\n` in the MR body. If the creation tool accepts a string parameter, ensure the string contains real newline characters, not the two-character literal `\n`.

If the review reveals issues, resolve them before presenting. Do not present an unreviewed description.

---

**HARD STOP — REVIEW REQUIRED.**

Present the full MR preview in the chat:

```
TITLE:         <[PROJ-123] Short description — per title convention in Notes>
SOURCE:        <source branch>
DESTINATION:   <destination branch>

DESCRIPTION:
<full generated description>
```

- Do not create the MR until the user explicitly confirms.
- If the user requests changes, update the relevant fields and re-present the full preview before proceeding.

---

### M5 — MR Creation

Once the user confirms:

1. Create the MR on GitLab using the confirmed title and description. **Critical: pass the description with real newlines, not escaped `\n` sequences.**
   - **Preferred:** Use the `mcp__plugin_web-cms_gitlab__gitlab_create_merge_request` tool. Pass the source branch, destination branch, title, and description. The description string must contain actual newline characters so the markdown renders correctly in the MR — verify the tool call does not serialize newlines as literal `\n` or `\\n` text.
   - **Fallback:** If the MCP tool is unavailable or fails, use the `glab` CLI with a heredoc to preserve formatting (e.g. `glab mr create --source-branch ... --target-branch ... --title "..." --description "$(cat <<'EOF' ... EOF)"`).
   - Do not set reviewers, assignees, labels, or draft status — these are not reliably supported via the API and should be set manually after creation.
2. Report back in the chat with:
    - The MR URL
    - The MR ID
3. If any step fails (e.g. branch protection rules, missing permissions), stop immediately, report the specific error in the chat, and suggest corrective action. Do not silently retry or proceed past a failure.

---

### M6 — Cleanup

- Clear the session-scoped knowledge graph before finishing the workflow. Do not retain Jira-context, commit, or diff-summary nodes after the MR description has been created.

---

## Notes

- **Title convention:** For Jira-linked work, use the format `[PROJ-123] Short description of work` (Jira key in square brackets, space, imperative-mood description). For releases, use `Release x.x.x` or the Fix Version name (e.g. `Release 2.4.0`). Do not fall back to the raw branch name as the title.
- **Branch naming:** Source branches should follow `type/PROJ-key-short-description` or `release/x.x.x`. Flag deviations but do not block on them.
- **Missing Jira items:** Always report missing items but allow the user to override and proceed.
- **Release context:** In Jira, releases are usually tracked by **Fix Version** rather than a standalone Jira issue. Capture a release-tracking issue only if the team also maintains one.

---

## Completion Criteria

This workflow is complete when **all** of the following are true:

- All 7 phases executed in sequence (M0 through M6)
- Repository confirmed as GitLab-hosted
- Pre-flight checks passed, or failures resolved with explicit user input
- Jira context retrieved and verified, or explicitly confirmed as none
- Diff summary presented and acknowledged before description generation
- Full MR preview explicitly confirmed in the chat
- MR created successfully and URL reported in the chat
- M6 cleanup cleared the session-scoped knowledge graph after successful MR creation
