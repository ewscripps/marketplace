---
name: preflight
description: Pre-flight check for ada-tablo skills — clones workspace repo, pulls latest, inspects history.
user-invocable: false
allowed-tools: Bash(git *), Bash(ls *), Bash(cp *), AskUserQuestion, Read, Grep
---

# Ada-Tablo Pre-Flight

Ensures the shared workspace repo is cloned, credentials are configured, and recent activity is surfaced before running an analysis skill.

**This skill is called by other ada-tablo skills. Do not run it directly.**

## Step 1: Check Workspace Repo

Check if the ada-tablo-ops workspace exists:

```bash
ls ~/repos/ada-tablo-ops/CLAUDE.md
```

**If the directory does not exist:**

Ask the user: "The ada-tablo analysis skills require the shared workspace repo (ada-tablo-ops). Can I clone it to ~/repos/ada-tablo-ops?"

If they agree:

```bash
git clone https://github.com/DavidG91/ada-tablo-ops.git ~/repos/ada-tablo-ops
```

If clone fails, stop and report the error. The user may need to run `gh auth login` or check their GitHub access.

## Step 2: Verify Credentials

Check that `.env` exists and has a real token (not the placeholder):

```bash
ls ~/repos/ada-tablo-ops/.env
```

**If `.env` does not exist:**

```bash
cp ~/repos/ada-tablo-ops/.env.example ~/repos/ada-tablo-ops/.env
```

Then ask the user: "Please add your Ada API token to ~/repos/ada-tablo-ops/.env — get it from https://nuvyyo-gr.ada.support > Settings > Platform > API."

Wait for confirmation before proceeding.

**If `.env` exists, verify it has a real token:**

Use the Grep tool to check the `.env` file for the token value. If it still contains `your-token-here`, ask the user to update it.

**MCP Token Note:** The Ada MCP server reads `ADA_API_TOKEN` from the environment. For the token to resolve automatically, the user should either:
- Launch Claude Code from `~/repos/ada-tablo-ops` (Claude Code loads `.env` files from the working directory)
- OR set `export ADA_API_TOKEN=...` in their shell profile (`~/.zshrc` or `~/.bashrc`)

## Step 3: Pull Latest

Sync with the shared workspace:

```bash
git -C ~/repos/ada-tablo-ops pull
```

If pull fails due to merge conflicts, inform the user and stop.

## Step 4: Inspect Recent History

Check what the other user has done recently:

```bash
git -C ~/repos/ada-tablo-ops log --oneline -10
```

Summarize relevant findings for the calling skill:
- When was the last analysis run, and by whom?
- Were any reference files updated?
- Are there recent output files that overlap with what we're about to do?

Report this context to the user before the parent skill continues.

## Step 5: Verify MCP Connectivity (Coaching Review Only)

If this preflight was invoked by the coaching-review skill, the skill will need Ada MCP tools (`search_coaching`, `get_ada_metric`). Inform the user:

"This skill uses the Ada MCP server. If you haven't used it before, you may be prompted to approve MCP tool access when the skill calls Ada. Make sure your `ADA_API_TOKEN` is set (see Step 2)."

## Notes

- All bash commands are separate calls (no `&&` chaining)
- The workspace repo path is always `~/repos/ada-tablo-ops`
- This skill does not modify any files — it only reads and reports
