---
name: commit-results
description: Commit and push ada-tablo analysis results to the shared GitHub workspace.
user-invocable: false
allowed-tools: Bash(git *), AskUserQuestion, Read, Glob
---

# Commit Ada-Tablo Results

Stages, commits, and pushes the run's output, reference updates and code changes to the shared workspace repo. Called by analysis skills after completing a run.

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

What may be staged:
- `output/` and `reference/`: the run's results and reference updates.
- Code and its tests and docs: `scripts/`, `evidence-loop/scripts/`, `evidence-loop/tests/`,
  `evidence-loop/docs/`, `evidence-loop/ui/`. A script the run wrote or changed (a
  `stage_*.py`, `changeset_inspect.py`, `loop_status.py`) is part of the result; leaving it out
  means the commit records numbers the committed code cannot reproduce.

Before staging, list every file you mean to stage, grouped by those two kinds, and ask the user
with AskUserQuestion: stage all of them (Recommended), results only, or stop. Stage only what the
answer covers.

Never stage `.env`, `.DS_Store`, anything under `~/.ada-evidence/`, or any other path outside
those directories. If one appears in the status, mention it to the user and leave it.

## Step 3: Commit

Use the skill name from the argument and today's date:

```bash
git -C ~/repos/ada-tablo-ops commit -m "[SKILL_NAME] YYYY-MM-DD analysis"
```

Examples:
- `[playbook] 2026-04-08 analysis`
- `[topics] 2026-04-08 review`
- `[coaching] 2026-04-08 review`

End the message with the generated-by-Claude attribution footer the session's instructions give
for commits (David's root CLAUDE.md requires it). Pass the message with one `-m` for the subject
and one `-m` for the footer.

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

Check which branch is checked out:

```bash
git -C ~/repos/ada-tablo-ops branch --show-current
```

```bash
git -C ~/repos/ada-tablo-ops push
```

This pushes the checked-out branch, nothing else. If push fails after a successful rebase, inform the user and suggest checking their GitHub auth with `gh auth status`.

Confirm to the user, naming the branch. On `main`: "Results committed and pushed to main. The other user will see these changes on their next run." On any other branch: "Results committed and pushed to <branch>. Lauren's preflight reads main, so she sees none of this until <branch> is merged to main." Do not merge; that is the user's call.

## Notes

- All bash commands are separate calls (no `&&` chaining)
- Never stage `.env`, `.DS_Store`, or files outside the directories Step 2 lists
- End every commit message with the generated-by-Claude attribution footer
- Say which branch was pushed; only `main` reaches the other user
- Always pull --rebase before push to handle concurrent users
