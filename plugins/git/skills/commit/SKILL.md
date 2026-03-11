---
name: commit
description: Create a conventional commit with Jira ticket scope and gitmoji
user-invocable: true
argument-hint: '[optional type override: feat|fix|docs|refactor|test|perf|chore|style|ci|build]'
allowed-tools: Bash(git *), AskUserQuestion, Read, Grep, Glob
---

# Conventional Commit with Jira Scope

Generate a git commit for all staged and unstaged changes using **Conventional Commits** with **gitmoji**, linked to a Jira ticket.

## Commit Message Format

```
<gitmoji> <type>(<TICKET-KEY>): <description>

[optional body]

[optional footer(s)]
```

The scope is always a Jira ticket key (e.g., `SA-42`) unless no ticket applies.

## Step 1: Gather Context

Run these in parallel:

- `git status` (never use `-uall`)
- `git diff --cached --stat` and `git diff --stat`
- `git diff --cached` and `git diff`
- `git diff --staged`
- `git log --oneline -5`
- `git branch --show-current`

## Step 2: Stage Changes if Needed

If there are NO staged changes but there ARE unstaged/untracked changes:

1. Show the user the list of changed files
2. Use AskUserQuestion to ask what to stage:
   - "Stage all changes" — stage everything with `git add` listing specific files
   - "Let me pick files" — let the user specify which files
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

### If NO ticket is found in the branch name follow this process, using tools provided from the Atlassian MCP Server:

1. If a Jira project key is configured:
   a. Call `getAccessibleAtlassianResources` to get the cloudId
   b. Call `searchJiraIssuesUsingJql` with:
   - `jql`: `project = "<PROJECT_KEY>" AND assignee = currentUser() AND status IN ("Dev In Progress", "Dev To Do", "Dev Review", "QA In Progress", "QA To Do") ORDER BY status ASC, updated DESC`
   - `maxResults`: 10
   - `fields`: `["summary", "status", "issuetype", "priority"]`
     c. Present the issues to the user with AskUserQuestion, showing format: `PROJ-123: Issue summary (Status)`
     d. Include a "No ticket" option and a "Type manually" option
2. If NO Jira project is configured in README.md, ask the user:
   - Whether they want to add a Jira project key (and which one - then add it to README.md for future use)
   - Or proceed without a ticket scope

## Step 4: Determine Commit Type

Analyze the staged diff to determine the most appropriate conventional commit type:

| Type       | Gitmoji | When to use                                             |
| ---------- | ------- | ------------------------------------------------------- |
| `feat`     | ✨      | A new feature (MINOR version bump)                      |
| `fix`      | 🐛      | A bug fix (PATCH version bump)                          |
| `docs`     | 📚      | Documentation only changes                              |
| `style`    | 🧼      | Code style (formatting, whitespace, semicolons)         |
| `refactor` | ♻️      | Code change that neither fixes a bug nor adds a feature |
| `perf`     | 🚀      | Performance improvement                                 |
| `test`     | ✅      | Adding or updating tests                                |
| `build`    | 📦      | Build system or external dependencies                   |
| `ci`       | 🏗️      | CI configuration and scripts                            |
| `chore`    | 🧑‍💻      | Other changes that don't modify src or test             |
| `revert`   | 🔁      | Reverting a previous commit                             |

For **breaking changes**, add `!` after the scope AND use 💥 instead of the type's default gitmoji.

If the user passed a type as `$ARGUMENTS`, use that type instead of inferring.

## Step 5: Write Commit Message

Format: `<type>(<TICKET>):<emoji> <short description>`

Rules:

- Short description: lowercase, imperative mood ("add" not "added"), max 72 chars total for first line
- If changes are complex, add a body after a blank line with bullet points

## Scope

Always prefer the Jira ticket key as scope. Only use a module name (e.g., `api`, `ui`) if there's genuinely no ticket.

## Examples

With ticket:

```
feat(PROJ-123):✨ add user login functionality

- Implement OAuth2 flow with token refresh
- Add login form with email validation
- Store session in secure HTTP-only cookie
```

Without ticket:

```
fix:🐛 resolve null pointer in user service
```

Simple change (no body needed):

```
chore(PROJ-45):🔧 update eslint config
```

## Step 6: Confirm and Commit

Present the complete commit message to the user. Use AskUserQuestion with options:

- **Commit** — execute the commit as-is
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
