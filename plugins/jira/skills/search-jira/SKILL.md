---
name: search-jira
description: Search Jira issues by project key using JQL
user-invocable: true
argument-hint: '[PROJECT_KEY]'
allowed-tools: Bash(git *), AskUserQuestion, Read, Grep, Glob
---

# Search Jira Issues

Search for Jira issues in a project using the Atlassian MCP Server. Returns a list of open issues prioritized by the current user's assignments.

## Step 1: Resolve the Jira Project Key

Check `$ARGUMENTS` for a project key. If provided, use it directly.

If not provided, look for a Jira project key reference in the repo's `README.md`. It can be either:

- A markdown link: `Jira Project: [ND](https://ewscripps.atlassian.net/browse/ND)`
- A plain key: `Jira Project: ND`

Extract the project key from whichever format is found.

- If found, use that as the project key.
- If not found, ask the user: _"What's your Jira project key? (e.g., ND)"_
  - After they answer, offer to add it to the README as a link:
    ```
    Jira Project: [<PROJECT_KEY>](https://ewscripps.atlassian.net/browse/<PROJECT_KEY>)
    ```
    Append it under a `## Project` heading (create the heading if needed toward the top of the README).

## Step 2: Search for Issues

Using tools provided from the Atlassian MCP Server:

1. Call `getAccessibleAtlassianResources` to get the cloudId
2. Call `searchJiraIssuesUsingJql` **twice in parallel**:
   - **My tickets** — `project = "<PROJECT_KEY>" AND statusCategory != Done AND assignee = currentUser() ORDER BY updated DESC` / `maxResults`: 5
   - **Others' tickets** — `project = "<PROJECT_KEY>" AND statusCategory != Done AND assignee != currentUser() ORDER BY statusCategory DESC, updated DESC` / `maxResults`: 10
   - Both calls use `fields`: `["summary", "status", "issuetype", "priority", "assignee"]`
3. Merge the two result lists (mine first, then others), deduplicating by issue key, capped at 15 total

## Step 3: Return Results

Return the merged issue list to the caller. Format each issue as:

`PROJ-123: Issue summary (Status) — Assignee`

- Prefix issues assigned to the current user with `★`
- Show up to 10 issues, prioritizing the user's assigned issues at the top

Do NOT prompt the user to select an issue — the calling skill is responsible for presenting choices. Simply output the formatted list so the caller can incorporate it into its own UI.
