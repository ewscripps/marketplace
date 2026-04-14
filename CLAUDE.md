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
└── agents/<agent-name>/
    └── AGENT.md                 # Agent definition with YAML frontmatter
```

### SKILL.md Frontmatter

```yaml
name: skill-name
description: One-line description
user-invocable: true
argument-hint: '[optional args]'
allowed-tools: Bash(git *), AskUserQuestion, Read, Grep, Glob
```

`allowed-tools` defines the tool boundary for the skill. MCP tools are NOT listed here — they're controlled via permissions in `.claude/settings.local.json`.

### MCP Permission Namespacing

Format: `mcp__<source>_<server-name>__<tool-name>`

Example: `mcp__plugin_jira_atlassian-mcp-server__searchJiraIssuesUsingJql`

### Cross-Plugin Skill Invocation

Skills can call other skills via the `Skill` tool (e.g., `skill: "create-jira-card", args: "SA"`). The calling skill must include `Skill` in its `allowed-tools`. If the target plugin isn't enabled, the call fails — skills should handle this gracefully with a fallback.

## Current Plugins

- **git** (v1.0.8) — `/commit` skill for conventional commits with Jira scope and gitmoji shortcodes. Delegates Jira operations to the jira plugin.
- **jira** (v1.0.0) — `/search-jira` and `/create-jira-card` skills. Uses Atlassian MCP server at `https://mcp.atlassian.com/v1/mcp`.
- **ada-tablo** (v1.0.0) — `/weekly-playbook-analysis`, `/weekly-topics-review`, `/coaching-review` skills for Ada chatbot performance analysis. Uses Ada MCP server. Shared workspace at `DavidG91/ada-tablo-ops` (GitHub).
- **web-cms** (v1.0.0) — Intake and execution skills for web CMS Jira workflows, plus 7 specialist review agents (codebase-explorer, documentation-reviewer, implementation-reviewer, manual-qa-reviewer, plan-reviewer, review-analyst, test-reviewer).

## Key Conventions

- Gitmoji must use **shortcodes** (`:sparkles:`, `:bug:`), never Unicode emoji — Unicode breaks GitLab/Jira integrations.
- Commit messages must **never** include AI attribution trailers (`Co-Authored-By`, `Generated-By`, etc.).
- Git commands in skills must run as **separate parallel Bash calls**, never chained with `&&`.
- Never use `git add -A` or `git add .` — always stage files by explicit name.
- The `requires: { "mcp": [...] }` field in marketplace.json does not work in newer Claude Code versions — do not add it.
