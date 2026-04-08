---
name: commit-results
description: Commit and push ada-tablo analysis results to the shared GitHub workspace.
user-invocable: false
allowed-tools: Bash(git *), AskUserQuestion, Read, Glob
---

# Commit Ada-Tablo Results

Stages, commits, and pushes analysis output and reference file updates to the shared workspace repo. Called by analysis skills after completing a run.

**This skill is called by other ada-tablo skills. Do not run it directly.**

The calling skill passes the skill name as an argument (e.g., "playbook", "topics", "coaching").

## Step 1: Check Status

See what changed during this analysis run:

```bash
git -C ~/repos/ada-tablo-ops status --short
```

If there are no changes, inform the user: "No files changed during this run — nothing to commit." Then stop.

## Step 2: Stage Changed Files

Stage each modified or new file **by explicit name**. Do NOT use directory-level staging like `git add output/` or `git add reference/`.

For each file shown in `git status`:

```bash
git -C ~/repos/ada-tablo-ops add path/to/specific/file.csv
```

```bash
git -C ~/repos/ada-tablo-ops add path/to/specific/reference_file.md
```

Only stage files in `output/` and `reference/` directories. If unexpected files appear in the status (e.g., `.env`, `.DS_Store`), do NOT stage them — mention them to the user.

## Step 3: Commit

Use the skill name from the argument and today's date:

```bash
git -C ~/repos/ada-tablo-ops commit -m "[SKILL_NAME] YYYY-MM-DD analysis"
```

Examples:
- `[playbook] 2026-04-08 analysis`
- `[topics] 2026-04-08 review`
- `[coaching] 2026-04-08 review`

Do NOT add AI attribution trailers (no `Co-Authored-By`, no `Generated-By`).

## Step 4: Sync Before Push

Rebase on latest remote to handle concurrent pushes:

```bash
git -C ~/repos/ada-tablo-ops pull --rebase
```

If rebase fails due to conflicts:
1. Inform the user: "There's a merge conflict — another user likely pushed changes while you were working."
2. Show which files conflict
3. Suggest: "You can resolve this manually in ~/repos/ada-tablo-ops, or I can try to help."
4. Do NOT force-push or discard changes.

## Step 5: Push

```bash
git -C ~/repos/ada-tablo-ops push
```

If push fails after a successful rebase, inform the user and suggest checking their GitHub auth with `gh auth status`.

Confirm to the user: "Results committed and pushed to ada-tablo-ops. The other user will see these changes on their next run."

## Notes

- All bash commands are separate calls (no `&&` chaining)
- Never stage `.env`, `.DS_Store`, or files outside `output/` and `reference/`
- Never add AI attribution trailers to commit messages
- Always pull --rebase before push to handle concurrent users
