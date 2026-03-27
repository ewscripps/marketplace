---
name: commit
description: Create a conventional commit with Jira ticket scope and gitmoji
user-invocable: true
argument-hint: '[--all|-a] [optional type override: feat|fix|docs|refactor|test|perf|chore|style|ci|build]'
allowed-tools: Bash(git *), AskUserQuestion, Read, Grep, Glob, Skill
---

# Conventional Commit with Jira Scope

Generate a git commit for all staged and unstaged changes using **Conventional Commits** with **gitmoji shortcodes** (e.g., `:sparkles:` not ✨), linked to a Jira ticket. Use shortcode format to avoid breaking GitLab/Jira integrations.

## Commit Message Format

```
<type>(<TICKET-KEY>): <gitmoji shortcode> <description>

[optional body]

[optional footer(s)]
```

The scope is always a Jira ticket key (e.g., `SA-42`) unless no ticket applies.

## Step 1: Gather Context

Run these as separate, parallel Bash tool calls (do NOT chain commands with `&&` or `echo` separators — each must be its own Bash invocation):

- `git status` (never use `-uall`)
- `git diff --cached --stat`
- `git diff --stat`
- `git diff --cached`
- `git diff`
- `git diff --staged`
- `git log --oneline -5`
- `git branch --show-current`

## Step 1.5: Parse Arguments

Check `$ARGUMENTS` for flags and type overrides:

- If `--all` or `-a` is present, set **include-all mode** to true and remove the flag from arguments before checking for a type override.
- Any remaining argument is treated as a type override (e.g., `feat`, `fix`).

## Step 2: Stage Changes if Needed

### If include-all mode is enabled (`--all` or `-a`):

Stage ALL unstaged and untracked files automatically by listing each file explicitly with `git add`. Skip the interactive prompt entirely.

IMPORTANT: NEVER use `git add -A` or `git add .`. Always stage specific files by name, even in include-all mode.

If there are no changes at all, inform the user and stop.

### Otherwise (default behavior):

If there are NO staged changes but there ARE unstaged/untracked changes:

1. Show the user the list of changed files
2. Use AskUserQuestion to ask what to stage:
   - "Stage all changes" — stage everything with `git add` listing specific files
   - "Let me pick files" — let the user specify which files
   - "Abort" — stop the commit process

If there ARE staged changes but also additional unstaged/untracked changes:

1. Show the user what is currently staged and what is not
2. Use AskUserQuestion to ask:
   - "Commit staged only" — proceed with only the currently staged changes
   - "Include all changes" — also stage all remaining unstaged/untracked files before committing
   - "Let me pick files" — let the user specify additional files to stage
   - "Abort" — stop the commit process

IMPORTANT: NEVER use `git add -A` or `git add .`. Always stage specific files by name.

If there are no changes at all, inform the user and stop.

## Step 3: Resolve the Jira project ticket

Parse the current branch name for a Jira ticket using the pattern: `[A-Z][A-Z0-9]+-\d+`

This matches tickets like `PROJ-123` from branches like:

- `PROJ-123-user-login`
- `feature/PROJ-123-add-auth`
- `bugfix/PROJ-123`

### If a ticket IS found:

Use it as the commit scope. Done.

### If NO ticket is found in the branch name:

Look for a Jira project key reference in the repo's `README.md`. It can be either:

- A markdown link: `Jira Project: [SA](https://ewscripps.atlassian.net/browse/SA)`
- A plain key: `Jira Project: SA`

Extract the project key from whichever format is found.

- If found, use that as the project key.
- If not found, ask the user: _"What's your Jira project key? (e.g., SA)"_
  - After they answer, offer to add it to the README as a link:
    ```
    Jira Project: [<PROJECT_KEY>](https://ewscripps.atlassian.net/browse/<PROJECT_KEY>)
    ```
    Append it under a `## Project` heading (create the heading if needed).

### If NO ticket is found in the branch name, search Jira for existing tickets:

> **Requires the `jira` plugin.** The Jira search and ticket creation features below depend on the `jira` plugin being enabled. If a Skill tool call fails because the skill is not found, inform the user: _"The jira plugin is not enabled. Enable it in your marketplace settings for Jira search and ticket creation. For now, you can type a ticket key manually or skip."_ Then fall back to the manual-only options (step 2b below).

1. If a Jira project key is configured (from README.md or user input above):
   - Invoke the `search-jira` skill using the Skill tool: `skill: "search-jira", args: "<PROJECT_KEY>"`
   - The skill returns a formatted list of open issues (it does NOT prompt the user)
   - Display **all** search results to the user as a numbered list (issue key + title) so they can reference them. If there are more than 2 results, note that the remaining issues not shown as quick-pick options can be entered via the free-text "Other" choice in the next step.

2. Present the user with a **single unified selection** using AskUserQuestion. The call MUST have **exactly 4 options** in this exact order — no more, no fewer, no reordering, no omissions:

   | # | label | description | When chosen |
   |---|-------|-------------|-------------|
   | 1 | `<ISSUE-1_KEY>: <title>` | `Assign this issue to the commit` | Use `ISSUE-1_KEY` as scope |
   | 2 | `<ISSUE-2_KEY>: <title>` | `Assign this issue to the commit` | Use `ISSUE-2_KEY` as scope |
   | 3 | `Create new ticket` | `Create a new Jira issue for this commit` | Invoke `skill: "create-jira-card", args: "<PROJECT_KEY>"`. Use the returned issue key as scope. |
   | 4 | `No ticket` | `Proceed without a Jira ticket scope` | Omit the scope from the commit |

   - Options 1-2: Use the **first 2 issues** from the `search-jira` results. If search returned fewer than 2 issues, fill remaining slots by shifting later options up (minimum 2 options total).
   - The built-in "Other" option already allows the user to type a ticket key manually — do NOT add a separate "Type manually" option.

## Step 3.5: Offer to Create a Ticket Branch

**Skip this step entirely** if the ticket was resolved from the branch name in Step 3 (i.e., the branch already contains the ticket key).

If a ticket key was resolved via Jira search, ticket creation, or manual entry, and the current branch does NOT contain that ticket key:

1. Run `git branch --list "*<TICKET_KEY>*"` to check if a local branch already exists for this ticket.

2. **If a matching branch already exists:**
   Use AskUserQuestion to offer:
   - **"Switch to `<existing-branch-name>`"** — run `git checkout <existing-branch-name>` (staged changes carry over)
   - **"Stay on current branch"** — proceed without switching

3. **If no matching branch exists:**
   Generate a branch name using the pattern `<TICKET_KEY>-<short-description>`:
   - If the Jira issue summary is available (from search or creation), slugify it: lowercase, replace spaces with hyphens, strip special characters, truncate to ~50 chars (e.g., `PROJ-123-add-user-login`)
   - If no summary is available (manual entry), use just the ticket key: `<TICKET_KEY>`

   Use AskUserQuestion to offer:
   - **"Create branch `<generated-branch-name>`"** — run `git checkout -b <generated-branch-name>` (staged changes carry over to the new branch)
   - **"Stay on current branch"** — proceed without switching

## Step 4: Determine Commit Type

Analyze the staged diff to determine the most appropriate conventional commit type:

| Type       | Gitmoji                   | When to use                                             |
| ---------- | ------------------------- | ------------------------------------------------------- |
| `feat`     | `:sparkles:`              | A new feature (MINOR version bump)                      |
| `fix`      | `:bug:`                   | A bug fix (PATCH version bump)                          |
| `docs`     | `:books:`                 | Documentation only changes                              |
| `style`    | `:art:`                   | Code style (formatting, whitespace, semicolons)         |
| `refactor` | `:technologist:`          | Code change that neither fixes a bug nor adds a feature |
| `perf`     | `:rocket:`                | Performance improvement                                 |
| `test`     | `:white_check_mark:`      | Adding or updating tests                                |
| `build`    | `:package:`               | Build system or external dependencies                   |
| `ci`       | `:building_construction:` | CI configuration and scripts                            |
| `chore`    | `:wrench:`                | Other changes that don't modify src or test             |
| `revert`   | `:repeat:`                | Reverting a previous commit                             |

For **breaking changes**, add `!` after the scope AND use `:boom:` instead of the type's default gitmoji.

If the user passed a type as `$ARGUMENTS`, use that type instead of inferring.

## Step 5: Write Commit Message

Format: `<type>(<TICKET>): <gitmoji shortcode> <short description>`

IMPORTANT: Always use gitmoji shortcodes (e.g., `:sparkles:`, `:bug:`) — NEVER use Unicode emoji characters (e.g., ✨, 🐛). Unicode emoji break GitLab and Jira integrations.

Rules:

- Short description: lowercase, imperative mood ("add" not "added"), max 72 chars total for first line
- If changes are complex, add a body after a blank line with bullet points

## Scope

Always prefer the Jira ticket key as scope. Only use a module name (e.g., `api`, `ui`) if there's genuinely no ticket.

## Examples

With ticket:

```
feat(PROJ-123): :sparkles: add user login functionality

- Implement OAuth2 flow with token refresh
- Add login form with email validation
- Store session in secure HTTP-only cookie
```

Without ticket:

```
fix: :bug: resolve null pointer in user service
```

Simple change (no body needed):

```
chore(PROJ-45): :wrench: update eslint config
```

## Step 6: Confirm and Commit

Use AskUserQuestion to confirm the commit. Display the complete commit message inside the **Commit** option's `preview` field so the user can see it in the side panel without it scrolling out of view. The options should be:

- **Commit** — with `preview` set to the full commit message (rendered as a code block in the preview pane)
- **Edit** — let the user modify the message
- **Abort** — cancel

If confirmed, execute using a heredoc:

```bash
git commit -m "$(cat <<'EOF'
<full commit message here>
EOF
)"
```

After committing, run `git status` to verify success and show the result.

## Important: No AI Attribution

NEVER add `Co-Authored-By`, `Generated-By`, or any other trailer, footer, or metadata referencing an AI assistant (e.g., "Claude", "Opus", "GPT", "Copilot") to the commit message. The commit message must contain only the conventional commit content described above.
