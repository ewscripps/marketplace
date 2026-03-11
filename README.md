# STG Plugin Marketplace

A plugin marketplace for AI coding tools like [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and [GitHub Copilot](https://github.com/features/copilot). It provides a shared collection of plugins that standardize workflows, enforce coding conventions, and integrate with team tooling across AI-assisted development environments.

## Overview

AI coding assistants are powerful out of the box, but teams need consistent behavior across developers — commit formats, Jira integration, code review standards, and more. This marketplace solves that by packaging reusable **plugins** (with skills, MCP server configs, and conventions) that any supported AI tool can consume.

### What's included

- **Skills** — Prompt-based capabilities that teach AI tools team-specific workflows (e.g., conventional commits with Jira scope and gitmoji)
- **MCP Servers** — Pre-configured [Model Context Protocol](https://modelcontextprotocol.io/) server connections that give AI tools access to external services like Atlassian Jira and Confluence
- **Conventions** — Shared rules and patterns that keep AI-generated code aligned with team standards

## Plugins

| Plugin | Description |
| ------ | ----------- |
| [git](./plugins/git) | Git workflow plugin — conventional commits with Jira ticket scope, gitmoji, and Atlassian MCP integration |

## Project Structure

```
marketplace/
├── .github/plugin/
│   └── marketplace.json      # Marketplace manifest (plugin registry)
├── plugins/
│   └── <plugin-name>/
│       ├── .mcp.json          # MCP server configuration
│       └── skills/
│           └── <skill-name>/
│               └── SKILL.md   # Skill definition
└── README.md
```

## Getting Started

Install a plugin by pointing your AI tool's configuration at this repository. Plugins are defined in the [marketplace manifest](./.github/plugin/marketplace.json) and can be consumed by any compatible AI coding assistant.

## Project

Jira Project: [ELI](https://ewscripps.atlassian.net/browse/ELI)

## Owned By

**STG Software Engineering Team** — stg@scripps.com
