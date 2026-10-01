---
name: preflight
description: Pre-flight check for ada-tablo skills — clones workspace repo, pulls latest, inspects history, and runs the weekly Ada platform contract check.
user-invocable: false
allowed-tools: Bash(git *), Bash(ls *), Bash(cp *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/tests/run_tests.py *), AskUserQuestion, Read, Grep
---

# Ada-Tablo Pre-Flight

Ensures the shared workspace repo is cloned, credentials are configured, and recent activity is surfaced before running an analysis skill.

**This skill is called by other ada-tablo skills. Do not run it directly.**

**Once a session.** Skills nest (work → playbook-authoring → preflight → config-health →
preflight), and eight skills call this one. If preflight already ran in this session, say
"preflight already ran this session" in one line and return; run it again only when the user
asks or the earlier run stopped on a failure.

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

Check the branch and the working tree first, as separate calls:

```bash
git -C ~/repos/ada-tablo-ops branch --show-current
```

```bash
git -C ~/repos/ada-tablo-ops status --porcelain
```

- **On `main` with a clean tree:** pull.
  ```bash
  git -C ~/repos/ada-tablo-ops pull --ff-only
  ```
- **On another branch, or with uncommitted changes:** do not pull. Fetch, and say in one line
  how far the branch is behind `origin/main` and how many files are uncommitted, so the user
  can decide:
  ```bash
  git -C ~/repos/ada-tablo-ops fetch
  ```
  ```bash
  git -C ~/repos/ada-tablo-ops rev-list --count HEAD..origin/main
  ```

If the pull fails (conflicts, or not a fast-forward), inform the user and stop.

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

## Step 5: Platform Contract Check (weekly gate)

The evidence-layer scripts read an **undocumented** Ada export schema and a taxonomy that
has already been retired underneath them once. A retired topic ID returns `"0"` with no
error, so a broken analysis looks exactly like a good week. This step is what catches that
before the numbers are believed.

**Run it if it has not passed in the last 7 days.** Read the state file first:

```
Read ~/.ada-evidence/tablo/test-state/last_weekly_run.json
```

It holds `ran_at`, `exit_code` and `outcome`, and a failing run writes it too. Run the check
when the file is missing, when `ran_at` is more than 7 days old, or when `outcome` is anything
but `pass`. A failed check is therefore rerun on every preflight until it passes, and never
skipped for a week on the strength of its own failure. When the check is skipped because it
passed recently, say so in one line with its date.

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/tests/run_tests.py
```

Roughly 2 seconds on a warm cache. Read the verdict block, not the pytest output.

**How to handle the result:**

| Result | Action |
|---|---|
| All pass | Say so in one line and continue. |
| Any FAIL | **Warn, do not block.** Report which group failed and what the verdict block says it invalidates. Ask the user whether to continue, because a schema failure means this week's numbers may not be comparable to last week's. |
| Live tests skipped | Fine offline. Say the contract check was not verified against Ada this run. |

Do not edit `tests/contract.py` to make a failure go away. Those values are pinned
deliberately; changing one is a decision about what it invalidates, not a fix.

**Targeted mode, for mid-investigation use.** When the parent skill or the user is chasing a
specific playbook, topic or window rather than running the weekly review, run only the
relevant checks:

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/tests/run_tests.py --playbook <playbook_id>
python3 ~/repos/ada-tablo-ops/evidence-loop/tests/run_tests.py --topic <topic_id>
python3 ~/repos/ada-tablo-ops/evidence-loop/tests/run_tests.py --window <start> <end>
```

Use this when a metric looks wrong and you need to know whether the pipeline or the product
moved, before spending transcript budget on the question. The flags combine.

## Step 6: Verify MCP Connectivity

Every calling skill except commit-results reads Ada through the MCP server. If no Ada MCP tool
is available in this session, say so in one line: the calling skill will stop at its first
Ada call. The server reads `ADA_API_TOKEN` (see Step 2).

## Notes

- All bash commands are separate calls (no `&&` chaining)
- The workspace repo path is always `~/repos/ada-tablo-ops`
- This skill edits no files itself. A fast-forward pull on a clean `main` updates the clone, and the contract check writes its state file
