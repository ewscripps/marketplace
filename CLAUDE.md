# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

STG Plugin Marketplace — a distribution repository for AI coding tool plugins (Claude Code, GitHub Copilot). No build process, tests, or CI/CD. All content is markdown skill definitions and JSON configuration.

Jira Project: [ELI](https://ewscripps.atlassian.net/browse/ELI)

## Architecture

### Plugin Registry

`.claude-plugin/marketplace.json` is the central manifest. Each plugin entry has a `name`, `source` path, `version`, a list of `skills`, and an optional list of `agents` (all relative paths from the plugin root).

### Plugin Structure

```
plugins/<plugin-name>/
├── .mcp.json                    # MCP server config (can be empty)
├── skills/<skill-name>/
│   └── SKILL.md                 # Skill definition with YAML frontmatter
└── agents/
    ├── <agent-name>/AGENT.md    # Shape A: directory-per-agent (e.g. web-cms)
    └── <agent-name>.md          # Shape B: flat file per agent (e.g. edm)
```

Both shapes are in active use -- pick whichever your plugin's own tooling enforces. There is no
repository-wide agent-layout validator; a plugin should verify its own manifest/agent consistency
by whatever means it provides.

### SKILL.md Frontmatter

```yaml
name: skill-name
description: One-line description
user-invocable: true
argument-hint: '[optional args]'
allowed-tools: Bash(git *), AskUserQuestion, Read, Grep, Glob
```

`allowed-tools` defines the tool boundary for the skill. MCP tools are NOT listed here — they're controlled via permissions in `.claude/settings.local.json`.

`user-invocable` and `disable-model-invocation` are NOT synonyms or opposites of each other — the
former gates USER invocation (via `/plugin:skill`), the latter gates MODEL invocation (the model
deciding on its own to invoke the skill) — and this repository's plugins are not consistent about
which they set. `git`, `jira`, `ada-tablo`, `bruno`, `myday` and `edm` follow the template above
(`user-invocable: true`, no `disable-model-invocation`); `web-cms`'s 14 skills set both. `edm` and
`web-cms` also add `model:` and `effort:` keys the template above omits — see
`plugins/edm/CLAUDE.md`'s "Model and effort assignments" section for the assignment table that
governs edm's. When adding a skill to `edm` or `web-cms`, follow that plugin's own existing
sibling skills rather than the bare template above.

### MCP Permission Namespacing

Format: `mcp__<source>_<server-name>__<tool-name>`

Example: `mcp__plugin_jira_atlassian-mcp-server__searchJiraIssuesUsingJql`

### Cross-Plugin Skill Invocation

Skills can call other skills via the `Skill` tool (e.g., `skill: "create-jira-card", args: "SA"`). The calling skill must include `Skill` in its `allowed-tools`. If the target plugin isn't enabled, the call fails — skills should handle this gracefully with a fallback.

## Current Plugins

- **git** (v1.1.0) — `/commit` skill for conventional commits with Jira scope and gitmoji shortcodes. Delegates Jira operations to the jira plugin.
- **jira** (v1.1.0) — `/search-jira` and `/create-jira-card` skills. Uses Atlassian MCP server at `https://mcp.atlassian.com/v1/mcp`.
- **edm** (v3.2.0) — Enterprise Development Methodology: `/edm:orchestrator`, `/edm:plan`, `/edm:srd`, `/edm:audit-srd`, `/edm:tickets`, `/edm:audit-tickets`, `/edm:implement`, `/edm:code-audit`, `/edm:test`, `/edm:test-plan`, `/edm:test-coverage`, `/edm:verify-runtime`, `/edm:push-jira`, and `/edm:metrics` skills implementing a six-phase, HITL-gated development methodology (Planning → SRD → Audit → Tickets → Audit → Implementation) with parallel agent waves, automatic QC, and an 11-lens code audit. Produces source-controlled artifacts in the project's `SRD/` directory.
- **ada-tablo** (v1.2.0) — `/weekly-playbook-analysis`, `/weekly-topics-review`, `/coaching-review` skills for Ada chatbot performance analysis. Uses Ada MCP server. Shared workspace at `DavidG91/ada-tablo-ops` (GitHub).
- **bruno** (v1.1.0) — Bruno API client skills: scaffold and update collections, run collections with the bru CLI, document endpoints and environments, create new requests, and write or fix tests. Defaults to OpenCollection YAML format.
- **web-cms** (v1.0.19) — Intake and execution skills for web CMS Jira workflows, plus specialist review agents (codebase-explorer, documentation-reviewer, implementation-reviewer, manual-qa-reviewer, plan-reviewer, review-analyst, test-reviewer, area-mapper, comment-reviewer, verification-runner) using the directory-per-agent layout.
- **myday** (v1.0.0) — `/myday` skill: morning calendar/Jira briefing, mid-day check-ins, end-of-day reflection, team lookups, PTO tracking, meeting notes with 1:1 success-tracking, reminders, and review prep. Uses its own Atlassian MCP server config (same endpoint as jira plugin, declared independently so it works standalone). Bundles a starter `MyDay/` planner folder (ICS calendar fetch script) and a `myday-config.example.json` for personal config at `~/.claude/myday-config.json`.

## Key Conventions

- Gitmoji must use **shortcodes** (`:sparkles:`, `:bug:`), never Unicode emoji — Unicode breaks GitLab/Jira integrations.
- Commit messages must **never** include AI attribution trailers (`Co-Authored-By`, `Generated-By`, etc.).
- Git commands in skills must run as **separate parallel Bash calls**, never chained with `&&`.
- Never use `git add -A` or `git add .` — always stage files by explicit name.
- The `requires: { "mcp": [...] }` field in marketplace.json does not work in newer Claude Code versions — do not add it.
