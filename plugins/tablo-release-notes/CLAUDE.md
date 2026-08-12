# tablo-release-notes Plugin — Contributor Guide

## Overview

This plugin generates release notes for Tablo client-app builds from Jira fix-versions and GitLab/git history, publishing drafts to Confluence.

> **Scope:** This plugin is specific to **Tablo client applications** (Android,
> Apple, Roku). It assumes Tablo's Jira projects, Tablo's git tag conventions
> (including the `fast/release/` tag namespace on `tablo-android`), and the
> Scripps Atlassian site. It is not a general-purpose release-notes tool.

## Skills

| Skill | Purpose |
|---|---|
| `generate-release-notes` | Orchestrates the full release-note pipeline: spawns Jira and SCM collector agents in parallel, drafts customer-facing notes and an internal companion doc, then invokes the Confluence publisher. Invoked with a build version, e.g. `/generate-release-notes 2.2-alpha.1`. |
| `release-notes-config` | Bootstrap or update the `.release-notes.yml` config file for the current product repo. Walks the developer through setting up platform names, Jira project keys, repo paths, tag scoping, and the Confluence space. Run once before the first `/generate-release-notes` invocation. |

## Agents

| Agent | Purpose |
|---|---|
| `rn-jira-collector` | Per-project Jira data collector. Fetches all tickets with a given fix version, reads their comments, and returns a validated JSON shard. Spawned in parallel by the release-notes orchestrator (one per platform). |
| `rn-scm-collector` | Per-repo SCM data collector. Resolves the commit range, walks git log and GitLab MRs, extracts Jira ticket keys, and returns keyed commits/MRs, the unassociated subset, and change-shape signals. Spawned in parallel by the release-notes orchestrator (one per platform). |
| `rn-confluence-publisher` | Confluence publisher. Builds or locates the page hierarchy (root -> project -> release -> parent -> 2 children), smart-merges existing pages (reading as ADF, writing as markdown), and creates missing pages. Spawned once per release by the orchestrator after drafting is complete. |

## Version and tag semantics

The canonical implementation is the Python block in
`skills/generate-release-notes/workflow.md`, delimited by
`# --- rn:version (canonical) ---` / `# --- end rn:version ---`. It is the
**only** copy. The orchestrator writes it to `$TMPDIR/rn_version.py` at the start
of a run and `rn-scm-collector` imports it from there — never re-implement version
or tag parsing in an agent file.

`dev/verify_version_rules.py` extracts that block and asserts it against real tag
fixtures. Run it after any change to the block:

```bash
python3 plugins/tablo-release-notes/dev/verify_version_rules.py
```

**Grammar:** `<line>[-(alpha|beta|rc|final|release)[.N]]`, where `line` is
`major.minor[.patch]`. `-final` and `-release` both mean the public build, and a
leading `v` on the argument is accepted.

**Range rule:** the first build of a phase is cumulative from the previous public
release; later builds in that phase are deltas from the previous build of that
same phase. So `2.2-alpha.1` and `2.2-beta.1` each cover the whole line, while
`2.2-alpha.2` covers only what changed since `2.2-alpha.1`.

**Baselines** use "highest lower index", never "index − 1" —
`fast/release/v2.1` really does have `beta.2`/`beta.3` with no `beta.1`, and
`rc.1` then `rc.4`–`rc.7`.

**Tag scoping:** only tags under a platform's `tag_prefix` are considered. This is
load-bearing for `tablo-android`, whose unprefixed `v2.x` tags are a legacy
codebase; without the prefix a baseline search would span two unrelated
codebases. Never rank tags with `git tag --sort=-version:refname` — it sorts
`v2.2-beta.1` above `v2.2`.

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
