# PR / MR CREATION WORKFLOW — EXECUTION CONTRACT

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute phases in strict sequential order (M0 through M7).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure in the chat. Do not continue.
5. Every required output must be presented in the chat before the phase is considered complete.
6. Do not create the PR/MR until M5 is reached and explicitly approved.

**KNOWLEDGE GRAPH SCOPE:** The knowledge graph in this workflow accumulates Jira context (M2), commit and diff data (M3) so that M5 can assemble a grounded PR/MR description. The graph is session-scoped -- do not rely on it persisting to a future session.

**APPROVAL GATE BEHAVIOR:** Approval gates are chat-scoped. If explicit approval is not captured before the session ends or context is lost, stop at the gate. On resume, re-present the latest PR/MR preview and ask for confirmation again. Never assume a pending approval was granted.

**CLARIFICATION RULE:** Do not assume anything. If required information is missing, ambiguous, conflicting, or underspecified, stop and ask the user for clarification before proceeding.

**GIT AND FILESYSTEM TOOL PREFERENCE:** Prefer MCP tools over Bash for git and filesystem operations. For git: use `git_status`, `git_add`, `git_commit`, `git_diff`, `git_diff_staged`, `git_diff_unstaged`, `git_log`, `git_show`, `git_create_branch`, `git_checkout`, and `git_reset` instead of running the equivalent `git` commands via Bash. For filesystem: use `read_file`, `read_multiple_files`, `write_file`, `edit_file`, `list_directory`, `directory_tree`, `search_files`, `create_directory`, `move_file`, and `get_file_info` instead of Bash filesystem commands. Use Bash only for git operations with no MCP equivalent (`git push`, `git pull`, `git merge`, `git worktree`, `git remote`, `git stash`, `git rebase`) and for running build, test, and lint commands.

**TASK TRACKING:** Always use task tracking (`TaskCreate`/`TaskUpdate`) so progress is visible throughout. Create tasks for the following logical groups at the start of the workflow, mark each `in_progress` when starting and `completed` when done:

- **Setup** (M0–M1): Platform detection, context gathering
- **Research** (M2–M3): Jira context, diff analysis
- **Creation** (M4–M7): Assemble description, approval, create PR/MR, completion

---

### M0 — Platform Detection

**Agent performs automatically before asking anything:**

1. Inspect the repository's remote URL:
    - Contains `github.com` → **GitHub** (Pull Request)
    - Contains `gitlab.com` or a known GitLab self-hosted domain → **GitLab** (Merge Request)
    - If the remote URL is ambiguous or points to an unrecognized domain, check which platform API/MCP tool is active in the current environment.
    - If still ambiguous, ask the user: "Is this repository hosted on GitHub or GitLab?"
2. Once the platform is confirmed, use the correct terminology (PR vs MR) for all subsequent phases. Do not mix terminology.

> **REQUIRED:** Platform must be confirmed before proceeding. If auto-detection is ambiguous, wait for explicit user input before continuing to M1.

---

### M1 — Branch Collection & Pre-flight

**Ask the following questions:**

1. What is the **source branch** (the branch containing your changes)?
2. What is the **destination branch** (the branch you are merging into, e.g. `main`, `develop`)?

**Agent performs automatically after branches are provided:**

- Verify the source branch exists in the repository.
- Verify the destination branch exists in the repository.
- Confirm the source branch has commits ahead of the destination branch.

> **REQUIRED:** If any pre-flight check fails, stop and report the specific failure in the chat. Do not proceed until the issue is resolved.

---

### M2 — Context Classification

**Ask:** Is this PR/MR for a **release** or a **non-release** (feature, bug fix, tech debt, etc.)?

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

> **USE KNOWLEDGE GRAPH:** Write each retrieved Jira item to the knowledge graph. For releases, create a `release` node with properties: `name`, `fix_version`, and `tracking_issue_key` (optional). For non-releases, create a `jira_item` node with properties: `jira_key`, `type`, `summary`, `status`. Link items to a `pr_mr` root node representing this PR/MR. M5 reads these nodes to populate the Related Jira Items section of the description.

> **REQUIRED:** Present all of the following in the chat before proceeding:
> 
> - Confirmed type: release or non-release
> - Jira Fix Version / release-tracking issue details retrieved (or explicitly "none provided")
> - Branch naming assessment: compliant or flagged with reason
> - Any missing Jira items, with explicit user confirmation on how to proceed

---

### M3 — Diff & Commit Review

**Agent performs automatically:**

- Retrieve the full list of commits between the source and destination branch.
- Retrieve a summary of file changes (files added, modified, deleted).
- Identify the scope of changes (services, modules, or areas of the codebase affected).

> **USE KNOWLEDGE GRAPH:** Write the diff data to the knowledge graph. Create a `commit` node for each commit with properties: `hash`, `message`, `affected_area`. Create a `diff_summary` node with properties: `files_added`, `files_modified`, `files_deleted`, `affected_areas` (list). Link all nodes to the `pr_mr` root node. M5 reads commit and diff nodes to build the Summary and Changes sections of the description — this ensures every change is accounted for and nothing is invented.

> **REQUIRED:** Present a structured diff summary in the chat before proceeding:
> 
> - Total number of commits
> - Files added, modified, and deleted (with counts)
> - Affected areas of the codebase (services, modules, components)

---

### M4 — PR/MR Metadata

**Ask the following questions:**

1. Who should be added as **reviewers**?
2. Who should be the **assignee**? _(defaults to the author if left blank)_
3. Should any **labels** be applied? _(Agent should suggest relevant labels based on context, e.g. `release`, `bug`, `feature`, `tech-debt`, `epic`)_
4. Should this be created as a **draft** PR/MR? _(Recommended for releases, epics, or work still in progress)_

---

### M5 — Description Generation & Review Gate

> **USE SEQUENTIAL THINKING:** Before generating the description, invoke the `sequentialthinking` tool. Use it to trace each commit to a purpose, reconcile the diff summary (M3) with the Jira context (M2), determine what belongs in the Summary vs. Changes sections, and verify that no invented or assumed items are included. Build the description bottom-up from evidence, not top-down from assumption. Do not begin writing the description until the reasoning is complete.

> **USE KNOWLEDGE GRAPH:** Read all nodes from the graph — `commit`, `diff_summary`, `jira_item` / `release`, and `pr_mr` — to assemble the description. The Summary section should synthesize the diff and Jira context. The Changes list should be derived from commit nodes. The Related Jira Items section should be read directly from Jira item nodes. This ensures the description is fully grounded in structured evidence and not reconstructed from memory.

**Agent generates the PR/MR description using the following structure:**

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
- [ ] PR/MR is correctly scoped (no unrelated changes)
```

**REQUIRED: Review the description before presenting.** Verify:

- Summary accurately reflects the diff and Jira context from M3 and M2
- Changes list is grounded in actual commits — no invented or assumed items
- Related Jira items match exactly what was retrieved in M2
- Testing Notes identify genuinely risky or complex areas
- No placeholder text remains in any field

If the review reveals issues, resolve them before presenting. Do not present an unreviewed description.

---

**HARD STOP — REVIEW REQUIRED.**

Present the full PR/MR preview in the chat:

```
PLATFORM:      GitHub / GitLab
TITLE:         [source branch name or release name]
SOURCE:        [source branch]
DESTINATION:   [destination branch]
DRAFT:         Yes / No
REVIEWERS:     [list]
ASSIGNEE:      [name]
LABELS:        [list]

DESCRIPTION:
[full generated description]
```

- Do not create the PR/MR until the user explicitly confirms.
- If the user requests changes, update the relevant fields and re-present the full preview before proceeding.

---

### M6 — PR/MR Creation

Once the user confirms:

1. Create the PR (GitHub) or MR (GitLab) using the confirmed metadata and description.
2. Report back in the chat with:
    - The PR/MR URL
    - The PR/MR number/ID
    - Confirmation that reviewers and assignee were set successfully
3. If any step fails (e.g. branch protection rules, missing permissions), stop immediately, report the specific error in the chat, and suggest corrective action. Do not silently retry or proceed past a failure.

---

### M7 — Cleanup

- Clear the session-scoped knowledge graph before finishing the workflow. Do not retain Jira-context, commit, or diff-summary nodes after the PR/MR description has been created.

---

## Notes

- **Title convention:** Use the source branch name as the PR/MR title. For releases, use the release name or Fix Version (e.g. `Release 2.4.0`). For Jira-linked work, prefer `[PROJ-123] Short description of work`.
- **Branch naming:** Source branches should follow `type/PROJ-key-short-description` or `release/x.x.x`. Flag deviations but do not block on them.
- **Missing Jira items:** Always report missing items but allow the user to override and proceed.
- **Draft PRs/MRs:** Recommend draft mode for releases, epics, or any work flagged as in-progress.
- **Release context:** In Jira, releases are usually tracked by **Fix Version** rather than a standalone Jira issue. Capture a release-tracking issue only if the team also maintains one.

---

## Completion Criteria

This workflow is complete when **all** of the following are true:

- All 8 phases executed in sequence (M0 through M7)
- Platform correctly identified and used consistently throughout
- Pre-flight checks passed, or failures resolved with explicit user input
- Jira context retrieved and verified, or explicitly confirmed as none
- Diff summary presented and acknowledged before description generation
- Full PR/MR preview explicitly confirmed in the chat
- PR/MR created successfully and URL reported in the chat
- M7 cleanup cleared the session-scoped knowledge graph after successful PR/MR creation
