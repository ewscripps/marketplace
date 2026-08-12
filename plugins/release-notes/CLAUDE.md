# release-notes Plugin — Contributor Guide

## Overview

This plugin automates release-note generation from Jira fix-versions and GitLab/git history, publishing drafts to Confluence and dropping a formatted email HTML for stakeholder notification.

## Skills

| Skill | Purpose |
|---|---|
| `generate-release-notes` | Orchestrates the full release-note pipeline: spawns Jira and SCM collector agents in parallel, drafts customer-facing notes and an internal companion doc, then invokes the Confluence publisher and writes the email HTML to the configured drop folder. Invoked with a version string, e.g. `/generate-release-notes 2.8.0`. |
| `release-notes-config` | Bootstrap or update the `.release-notes.yml` config file for the current product repo. Walks the developer through setting up platform names, Jira project keys, repo paths, Confluence space, and the email drop folder. Run once before the first `/generate-release-notes` invocation. |

## Agents

| Agent | Purpose |
|---|---|
| `rn-jira-collector` | Per-project Jira data collector. Fetches all tickets with a given fix version, reads their comments, and returns a validated JSON shard. Spawned in parallel by the release-notes orchestrator (one per platform). |
| `rn-scm-collector` | Per-repo SCM data collector. Resolves the commit range, walks git log and GitLab MRs, extracts Jira ticket keys, and returns keyed commits/MRs, the unassociated subset, and change-shape signals. Spawned in parallel by the release-notes orchestrator (one per platform). |
| `rn-confluence-publisher` | Confluence publisher. Builds or locates the page hierarchy (root -> project -> release -> parent -> 2 children), smart-merges existing pages (reading as ADF, writing as markdown), and creates missing pages. Spawned once per release by the orchestrator after drafting is complete. |

## Conventions

The following rules are marketplace-wide hard rules and MUST be followed in all commits, code, and agent/skill content in this plugin:

- **Gitmoji shortcodes only** — use `:sparkles:`, `:bug:`, etc. Never Unicode emoji characters. Unicode emoji breaks GitLab/Jira integrations.
- **No AI attribution trailers in commits** — do not include `Co-Authored-By`, `Generated-By`, or any similar trailer in any commit message.
- **Git commands run as separate parallel Bash calls** — never chain git commands with `&&`.
- **Never `git add -A` or `git add .`** — always stage files by explicit name (e.g. `git add path/to/file.md`).
- **MCP tools are NOT listed in `allowed-tools` in SKILL.md** — MCP tool permissions are controlled via `.claude/settings.local.json`, not in skill frontmatter.

## Atlassian Cloud ID

The Atlassian Cloud ID for ewscripps.atlassian.net is:

```
f1b0109f-4589-41f1-be54-d5789b627577
```

Use this constant when MCP tools require a `cloudId` parameter.

## Known Atlassian MCP Tool Names

All tools are under the namespace `mcp__claude_ai_Atlassian__*`:

| Tool name | Purpose |
|---|---|
| `getAccessibleAtlassianResources` | List accessible Atlassian sites (use to get cloud ID) |
| `searchJiraIssuesUsingJql` | Search Jira issues with a JQL query |
| `getJiraIssue` | Fetch a single Jira issue by key |
| `getJiraProjectVersions` | List fix versions for a Jira project |
| `getConfluenceSpaces` | List Confluence spaces |
| `searchConfluenceUsingCql` | Search Confluence pages with a CQL query |
| `getConfluencePage` | Fetch a single Confluence page by ID |
| `getConfluencePageDescendants` | List child pages of a Confluence page |
| `createConfluencePage` | Create a new Confluence page |
| `updateConfluencePage` | Update the content of an existing Confluence page |
