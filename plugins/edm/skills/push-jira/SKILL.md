---
name: push-jira
description: Optionally persist an EDM ticket pack to Jira via the Atlassian MCP. Creates one Jira issue per `{PREFIX}-T{NN}` ticket, links dependencies as Issue Links, and writes the resulting Jira keys back into the ticket pack. Idempotent -- re-running updates existing issues instead of creating duplicates. Invoked explicitly via /edm:push-jira.
user-invocable: true
model: sonnet
effort: high
argument-hint: <PREFIX> [JIRA_PROJECT_KEY] [--dry-run]
allowed-tools: Read, Write, Edit, Bash(edm-state *), Glob, Grep, TodoWrite, mcp__{jira_mcp_namespace}__getAccessibleAtlassianResources, mcp__{jira_mcp_namespace}__atlassianUserInfo, mcp__{jira_mcp_namespace}__getVisibleJiraProjects, mcp__{jira_mcp_namespace}__getJiraProjectIssueTypesMetadata, mcp__{jira_mcp_namespace}__getJiraIssueTypeMetaWithFields, mcp__{jira_mcp_namespace}__createJiraIssue, mcp__{jira_mcp_namespace}__editJiraIssue, mcp__{jira_mcp_namespace}__getJiraIssue, mcp__{jira_mcp_namespace}__searchJiraIssuesUsingJql, mcp__{jira_mcp_namespace}__createIssueLink, mcp__{jira_mcp_namespace}__getIssueLinkTypes
---

# EDM -> Jira: Optional Ticket Pack Synchronization

**Arguments**: $ARGUMENTS

This skill is **optional** -- most EDM workflows produce a ticket pack as a markdown artifact and stop there. Use this skill only when your team also tracks work in Jira and wants the EDM ticket pack mirrored as Jira issues for sprint planning, reporting, or stakeholder visibility.

## Prerequisites

- The Atlassian MCP server is connected (`mcp__{jira_mcp_namespace}__*` tools should be available -- verify with `/mcp`).
- The user has a Jira project to push into (project key, e.g., `MCP`, `TIPS`).
- The ticket pack at `${INIT_DIR}/${user_config.ticket_pack_dirname}/` is finalized and Phase 5 audit has passed.

If any prerequisite is missing, the skill prints a clear "skipping -- Jira not available" message and exits without making changes.

## Operational Orchestration

### Step 1 -- Verify prerequisites
1. Parse arguments: `{PREFIX}` (required), `{JIRA_PROJECT_KEY}` (optional -- falls back to `${user_config.jira_project_key}`), `--dry-run` (flag, default: off).
   - `--dry-run`: when present, the skill produces a plan table of what would be created/updated/linked but makes no mutating MCP calls and does not rewrite ticket-pack files or update `.edm-state.json`.
   - The Jira MCP namespace is read from `${user_config.jira_mcp_namespace}` (default: `plugin_jira_atlassian-mcp-server`). Override this config value if your MCP server is registered under a different namespace (e.g., a legacy Docker-based namespace).
   - Resolve the initiative directory from state (handles both flat and product-scoped layouts):
     ```bash
     INIT_DIR="$(edm-state resolve-dir <PREFIX>)"
     ```
2. Verify Atlassian MCP is reachable: call `mcp__{jira_mcp_namespace}__atlassianUserInfo`. If it fails, print:
   > "Jira MCP not available (tried {jira_mcp_namespace}__atlassianUserInfo). To enable Jira sync: configure the MCP server with namespace '{jira_mcp_namespace}' (see `CLAUDE.md Sec."Optional: Jira synchronization"` for the `jira_mcp_namespace` userConfig option). Skipping."
   > and exit successfully (this is not an error -- the skill is optional). This applies even in `--dry-run` mode. (Read `docs/canonical-sections.md`, resolved relative to the EDM plugin's own root -- `plugins/edm/` in this repository, or the installed plugin's cache root, never the caller's cwd, for the actual section text; a bare `CLAUDE.md Sec."..."` reference does not resolve because CLAUDE.md at the plugin root is not loaded as runtime context.)
3. Resolve `cloudId` via `mcp__{jira_mcp_namespace}__getAccessibleAtlassianResources`. Use the first one; if multiple, ask the user.
4. Verify the project key exists via `mcp__{jira_mcp_namespace}__getVisibleJiraProjects` (filter by `query: <JIRA_PROJECT_KEY>`).
5. Resolve the issue type for tickets: call `mcp__{jira_mcp_namespace}__getJiraProjectIssueTypesMetadata` and pick `Task` (or `Story` if `Task` isn't available).

### Step 2 -- Read the ticket pack
1. Find epic files: `${INIT_DIR}/${user_config.ticket_pack_dirname}/epics/*.md`.
2. For each ticket in each epic, parse:
   - **Ticket ID**: `{PREFIX}-T{NN}` from the section heading
   - **Title**: imperative verb phrase from the heading
   - **Metadata table**: Epic, Phase, Priority, Size, SRD Refs, Depends On, Target Components
   - **Description**: text under "### Description"
   - **Acceptance Criteria**: checkboxes under "### Acceptance Criteria"
   - **Technical Notes**: text under "### Technical Notes"
   - **Out of Scope**: text under "### Out of Scope"

### Step 3 -- Check for existing Jira issues (idempotency)
For each ticket, search Jira for an existing issue with the EDM ticket ID in its labels or description.
Use JQL via `mcp__{jira_mcp_namespace}__searchJiraIssuesUsingJql`:
```
project = "<JIRA_PROJECT_KEY>" AND labels = "edm-{prefix}-t{nn}"
```
(EDM ticket IDs are stored as Jira labels, lowercased: `edm-auth-t01`. Labels are searchable and don't require custom fields.)

- **If found**: action is UPDATE (existing Jira key noted for step output / dry-run plan).
- **If not found**: action is CREATE.

In **dry-run mode**: after completing the search, print the plan table (see "Dry-run output" section below) and exit -- do not proceed to Steps 4-8.

In **normal mode**:
- **If found**: update the existing issue via `mcp__{jira_mcp_namespace}__editJiraIssue`. Preserve the Jira issue's current status, comments, worklog, and any custom fields.
- **If not found**: create a new issue via `mcp__{jira_mcp_namespace}__createJiraIssue`.

### Step 4 -- Format the issue body

```
Source: EDM ticket pack {ticket pack path}, ticket {PREFIX}-T{NN}

h2. Description

{description from ticket}

h2. Acceptance Criteria

* (/) AC1: ...
* (x) AC2: ...
...

h2. Technical Notes

{technical notes}

h2. Out of Scope

{out of scope}

h2. EDM Metadata

|| Field || Value ||
| Epic | {epic} |
| Phase | {phase} |
| Priority | {priority} |
| Size | {size} |
| SRD Refs | {srd refs} |
| Target Components | {target components} |
```

(Use Jira's wiki markup: `h2.` for headings, `|| Header ||` and `| cell |` for tables, `(/)` `(x)` for checkboxes.)

### Step 5 -- Set Jira fields on the issue

| Jira field | Source |
|---|---|
| `summary` | `{PREFIX}-T{NN}: {title}` |
| `description` | the formatted body from Step 4 |
| `issuetype` | `Task` (or `Story`) |
| `priority` | mapping: Must Have -> `High`, Should Have -> `Medium`, Could Have -> `Low` |
| `labels` | `["edm", "edm-{prefix}", "edm-{prefix}-t{nn}", "edm-epic-{epic_slug}"]` |

### Step 6 -- Create dependency links

After all issues are created, iterate again and for every ticket with a non-empty `Depends On`:
1. Look up the Jira key for the dependency ticket.
2. In **normal mode**: call `mcp__{jira_mcp_namespace}__createIssueLink` with link type `Blocks`:
   - `inwardIssue`: the dependency's Jira key (the blocker)
   - `outwardIssue`: this ticket's Jira key (the blocked)
3. In **dry-run mode**: this step is already captured in the plan table printed at Step 3 exit; skip.

Cross-reference link types via `mcp__{jira_mcp_namespace}__getIssueLinkTypes` if `Blocks` isn't available; fall back to `Relates`.

### Step 7 -- Persist the Jira keys back to the ticket pack

**Normal mode only** (skip entirely in dry-run mode):

For each ticket, append a Jira reference line to its Markdown source so future runs (and humans) can see the link without re-querying Jira:

In the epic file, replace the original ticket header:
```markdown
## {PREFIX}-T{NN}: {title}
```

with:
```markdown
## {PREFIX}-T{NN}: {title} ([{JIRA_KEY}]({jira_url}))
```

Where `{jira_url}` = `https://{site}.atlassian.net/browse/{JIRA_KEY}`.

Also write a summary file at `${INIT_DIR}/${user_config.ticket_pack_dirname}/jira-sync.md`:

```markdown
# Jira Sync -- {PREFIX}

Last synced: {timestamp}
Jira project: {JIRA_PROJECT_KEY}
Cloud: {cloudId}

| EDM Ticket | Jira Key | Status | Action |
|---|---|---|---|
| {PREFIX}-T01 | MCP-1234 | To Do | created |
| {PREFIX}-T02 | MCP-1235 | In Progress | updated (preserved status) |
| ... |
```

### Step 8 -- Report

Print summary to user: created N, updated M, links N, errors 0.

## Dry-run output

When `--dry-run` is passed, after reading the ticket pack (Step 2) and checking existing issues (Step 3), print the following plan and exit without making any mutating calls:

```
DRY RUN -- no Jira writes will be made.

Plan for {PREFIX} -> {JIRA_PROJECT_KEY}:

| EDM Ticket | Action | Jira Key (if updating) | Summary |
|---|---|---|---|
| {PREFIX}-T01 | CREATE | -- | {title} |
| {PREFIX}-T02 | UPDATE | MCP-1235 | {title} |
| ... |

Dependency links that WOULD be created:
| From | To | Type |
|---|---|---|
| {PREFIX}-T02 (MCP-1235) | {PREFIX}-T01 (MCP-1234) | Blocks |
| ... |

To apply: re-run without --dry-run.
```

If there are no dependency links, omit that table. The output must be clearly labeled as a plan/preview, not a record of completed work.

## Behavior on errors

- **MCP unavailable** (namespace `{jira_mcp_namespace}` not reachable): skip with friendly message (see Step 1.2). Applies in both normal and dry-run modes.
- **Project key invalid**: error out with list of accessible projects.
- **Single issue create/update fails**: log the failure, continue with remaining tickets, report failures at the end (don't abort the whole sync).
- **Link creation fails**: warn but don't fail the sync (issues exist; manual linking is acceptable).

## Anti-patterns

- **Don't push to Jira before HITL Gate 3**. The ticket pack must be approved first; otherwise teammates will see churn in Jira every time you re-audit.
- **Don't push during active implementation**. Tickets in flight may have a different status in Jira than in the source pack -- let the source pack stay authoritative until merge.
- **Don't synthesize fields Jira doesn't have**. If the project doesn't have a `Story Points` field exposed via the MCP, skip the size mapping rather than failing.

## When to re-run

- After any Phase 5 audit that adds, removes, or rewrites tickets -- re-running picks up changes.
- After a manual SRD revision triggers Phase 4 + Phase 5 again -- re-running propagates the changes.
- Routine drift between the ticket pack and Jira -> consider this a smell; the source pack should be the truth, not Jira state.

## Optional: human review before push

For first-time use on a ticket pack, use dry-run mode:
- Add `--dry-run` to args; the skill reads all tickets and existing Jira issues but prints only the plan of what would be created/updated/linked -- no `createJiraIssue`, `editJiraIssue`, or `createIssueLink` calls are made, and no ticket-pack files or `.edm-state.json` are written.
- Useful for verifying field mapping, label schema, and dependency-link logic before any state hits Jira.
- If MCP is unavailable, `--dry-run` still skips cleanly with the same message as normal mode.

## See also

- The Atlassian MCP server: configured per-machine via `claude mcp add` or in `.mcp.json`. Register it under the namespace matching `${user_config.jira_mcp_namespace}` (default: `plugin_jira_atlassian-mcp-server`).
- The idempotency mechanism is the JQL label search in Step 3 (`labels = "edm-{prefix}-t{nn}"`), not `.edm-state.json` -- this skill does not write any Jira-related field to state (G6/CA-384, round 7).
