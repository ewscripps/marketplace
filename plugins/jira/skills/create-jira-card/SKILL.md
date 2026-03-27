---
name: create-jira-card
description: Create a new Jira issue (story, bug, task, etc.) in a project
user-invocable: true
argument-hint: '[PROJECT_KEY]'
allowed-tools: Bash(git *), AskUserQuestion, Read, Grep, Glob
---

# Create a Jira Card

Create a new Jira issue using the Atlassian MCP Server. Walks the user through selecting a project, issue type, and providing details, then creates the issue and returns the key.

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

## Step 2: Get Atlassian Cloud ID

Call `getAccessibleAtlassianResources` from the Atlassian MCP Server to get the cloudId for the authenticated Atlassian instance.

## Step 3: Gather Issue Details

Use AskUserQuestion to ask the user for the issue type:

- **Dev Task** — A dev task or feature
- **Bug** — A defect or issue
- **Support Task** — A development task related to support work
- **Task** — A general task that doesn't fit the other categories

Then ask the user for:

1. **Summary** (required) — A short title for the issue. Use AskUserQuestion with a free-text prompt: _"What's the issue summary/title?"_
2. **Description** (optional) — Ask: _"Add a description? (or press Enter to skip)"_

If the user is in the middle of a commit workflow and there are staged changes, suggest a summary based on the diff context (let the user confirm or edit).

## Step 4: Create the Issue

Call `createJiraIssueUsingApi` from the Atlassian MCP Server with:

- `cloudId`: from Step 2
- `projectKey`: from Step 1
- `issueType`: from Step 3 (use the Jira issue type name: "Dev Task", "Bug", "Support Task", "Task")
- `summary`: from Step 3
- `description`: from Step 3 (if provided)
- `assignToMe`: `true` — always set this to assign the newly created issue to the authenticated user

If `createJiraIssueUsingApi` does not accept `assignToMe` or returns an error related to it, retry the call without it and skip assignment silently.

## Step 5: Transition to In Progress

After creating the issue, transition it to an active status:

1. Call `getJiraIssueTransitions` with the `cloudId` and the new issue's key to get available transitions.
2. Look for a transition named **"Dev In Progress"** (case-insensitive match). If not found, look for **"In Progress"**.
3. If a matching transition is found, call `transitionJiraIssue` with the `cloudId`, issue key, and the transition's `id`.
4. If neither transition is available, skip silently — do not error or prompt the user.

## Step 6: Confirm Creation

Display the created issue to the user:

```
Created: <PROJ-KEY> — <summary>
https://ewscripps.atlassian.net/browse/<PROJ-KEY>
```

Return the issue key (e.g., `PROJ-123`) so it can be used by the calling workflow (e.g., as a commit scope).
