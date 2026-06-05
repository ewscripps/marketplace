---
name: create-jira-card
description: Create a new Jira issue (story, bug, task, etc.) in a project
user-invocable: true
argument-hint: '[PROJECT_KEY]'
allowed-tools: Bash(git *), Bash(command *), Bash(twg *), AskUserQuestion, Read, Grep, Glob, Skill
---

# Create a Jira Card

Create a new Jira issue using the TWG CLI (preferred) or the Atlassian MCP Server (fallback). Walks the user through selecting a project, issue type, and providing details, then creates the issue and returns the key.

## Step 1: Resolve the Jira Project Key

Check `$ARGUMENTS` for a project key. If provided, use it directly.

If not provided, look for a Jira project key reference in the repo's `README.md`. It can be either:

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

## Step 2: Gather Issue Details

Use AskUserQuestion to ask the user for the issue type:

- **Dev Task** — A dev task or feature
- **Bug** — A defect or issue
- **Support Task** — A development task related to support work
- **Task** — A general task that doesn't fit the other categories

Then ask the user for:

1. **Summary** (required) — A short title for the issue. Use AskUserQuestion with a free-text prompt: _"What's the issue summary/title?"_
2. **Description** (optional) — Ask: _"Add a description? (or press Enter to skip)"_

If the user is in the middle of a commit workflow and there are staged changes, suggest a summary based on the diff context (let the user confirm or edit).

## Step 3: Create and Transition the Issue

Run `command -v twg` to check if the TWG CLI is installed.

### TWG Path (if installed)

Load the `twg` skill via the Skill tool, then:

1. Run `twg jira workitem field create-metadata --space "<PROJECT_KEY>" --type "<ISSUE_TYPE>"` to discover required custom fields for the selected issue type.
2. Create the issue:
   ```
   twg jira workitem create \
     --space "<PROJECT_KEY>" \
     --type "<ISSUE_TYPE>" \
     --summary "<SUMMARY>" \
     --description $'<DESCRIPTION>' \
     --assignee me
   ```
   - `--description` **must use `$'...'` ANSI-C quoting** so `\n` becomes a real newline, not a literal backslash-n.
   - Omit `--description` if the user skipped it.
   - Add `--field customfield_XXX=<value>` for any required custom fields found in step 1.
3. Transition the new issue to In Progress:
   - Run `twg jira workitem transition --id <NEW_KEY>` (omit `--transition-id`) to list available transitions.
   - Look for **"Dev In Progress"** (case-insensitive). If not found, look for **"In Progress"**.
   - If found: `twg jira workitem transition --id <NEW_KEY> --transition-id "Dev In Progress"`
   - If neither transition is available, skip silently.

### MCP Fallback (if TWG not installed)

1. Call `getAccessibleAtlassianResources` from the Atlassian MCP Server to get the `cloudId`.
2. Call `createJiraIssue` with:
   - `cloudId`: from above
   - `projectKey`: from Step 1
   - `issueType`: from Step 2 (use the Jira issue type name: "Dev Task", "Bug", "Support Task", "Task")
   - `summary`: from Step 2
   - `description`: from Step 2 (if provided)
   - `assignToMe`: `true` — always assign the new issue to the authenticated user
   - If `assignToMe` is not accepted or returns an error, retry without it and skip assignment silently.
3. Transition the created issue to In Progress:
   - Call `getTransitionsForJiraIssue` with the `cloudId` and new issue key.
   - Look for **"Dev In Progress"** (case-insensitive). If not found, look for **"In Progress"**.
   - If found, call `transitionJiraIssue` with the `cloudId`, issue key, and transition `id`.
   - If neither transition is available, skip silently.

## Step 4: Confirm Creation

Display the created issue to the user:

```
Created: <PROJ-KEY> — <summary>
https://ewscripps.atlassian.net/browse/<PROJ-KEY>
```

Return the issue key (e.g., `PROJ-123`) so it can be used by the calling workflow (e.g., as a commit scope).
