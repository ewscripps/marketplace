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
├── .claude-plugin/
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

## Contributing

We encourage teams and individuals to contribute plugins to the marketplace. The best plugins package up a set of related skills targeting a specific **team** or **technology**:

- **Team-focused plugins** — Target a specific dev team's workflows and conventions (e.g., `mobile-team`, `frontend`, `backend`, `data-engineering`)
- **Technology-focused plugins** — Target a specific technology stack (e.g., `react`, `roku`, `php`, `swift`, `android`)

A good plugin bundles everything a developer on that team or stack needs: skills for common tasks, MCP server configs for relevant tooling, and conventions that enforce team standards. For example, a `roku` plugin might include skills for SceneGraph component scaffolding and BrightScript linting conventions, while a `mobile-team` plugin might bundle iOS and Android build skills with team-specific release workflows.

To contribute a plugin:

1. Create a new directory under `plugins/` with your plugin name
2. Add skills (as `SKILL.md` files), MCP configs (`.mcp.json`), and conventions as needed
3. Register your plugin in the [marketplace manifest](./.claude-plugin/marketplace.json)
4. Open a pull request

## Project

Jira Project: [ELI](https://ewscripps.atlassian.net/browse/ELI)

## Owned By

**STG Software Engineering Team** — stg@scripps.com
