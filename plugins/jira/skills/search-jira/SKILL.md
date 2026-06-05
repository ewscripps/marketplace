---
name: search-jira
description: Search Jira issues by project key using JQL
user-invocable: true
argument-hint: '[PROJECT_KEY]'
allowed-tools: Bash(git *), Bash(command *), Bash(twg *), AskUserQuestion, Read, Grep, Glob, Skill
---

# Search Jira Issues

Search for Jira issues in a project using the TWG CLI (preferred) or the Atlassian MCP Server (fallback). Returns a list of open issues prioritized by the current user's assignments.

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

Run `command -v twg` to check if the TWG CLI is installed.

### TWG Path (if installed)

Load the `twg` skill via the Skill tool, then run the following **in parallel**:

- **My tickets** — `twg jira workitem query --jql 'project = "<PROJECT_KEY>" AND statusCategory != Done AND assignee = currentUser() ORDER BY updated DESC' --first 5 --output json`
- **Others' tickets** — `twg jira workitem query --jql 'project = "<PROJECT_KEY>" AND statusCategory != Done AND assignee != currentUser() ORDER BY statusCategory DESC, updated DESC' --first 10 --output json`

Parse results from `.data.issues[]` — each item has `key`, `summary`, `status`, `assignee`, `url`, `updated`. Merge the two lists (mine first), deduplicate by `key`, cap at 15 total.

**JQL notes:**
- Always use `statusCategory != Done` (not `status != Done`) — statusCategory is workflow-agnostic and works across all project configurations.
- `currentUser()` requires parentheses — `currentUser` without them is invalid.
- Quote multi-word values: `project = "MY PROJECT"` not `project = MY PROJECT`.

### MCP Fallback (if TWG not installed)

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
