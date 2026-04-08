# Ada-Tablo Plugin

Analysis skills for the Tablo Ada chatbot support system. Used by David and Lauren for weekly and monthly performance reviews.

## Skills

| Skill | Frequency | Purpose |
|-------|-----------|---------|
| `/ada-tablo:weekly-playbook-analysis` | Weekly (Fridays) | Playbook effectiveness review — CSV export, script analysis, baseline comparison |
| `/ada-tablo:weekly-topics-review` | Weekly (Fridays) | Catch-all reduction — topics report analysis, recommendation generation |
| `/ada-tablo:coaching-review` | Monthly | Coaching inventory sync, resolution rate measurement, performance tracking |

Two internal helper skills (`preflight`, `commit-results`) handle workspace setup and git operations automatically.

## Architecture

This plugin uses a **two-repo model**:

- **GitLab marketplace** (this repo) — Distributes skill definitions and Ada MCP config
- **GitHub `DavidG91/ada-tablo-ops`** — Shared workspace with Python scripts, reference data, and analysis output

Skills are delivered through the marketplace. All analysis work happens in the GitHub workspace, where both users commit results so their Claudes can track each other's changes.

## Setup

### 1. Install the plugin

```
/plugin marketplace add https://gitlab.com/scripps/public/marketplace.git
/plugin install ada-tablo@stg-marketplace
```

### 2. First run

Run any skill (e.g., `/ada-tablo:weekly-topics-review`). The preflight step will:
- Clone `ada-tablo-ops` to `~/repos/ada-tablo-ops` (if not already cloned)
- Prompt you to configure your Ada API token in `.env`
- Pull latest changes and show recent activity

### 3. Ada API token

Get your token from https://nuvyyo-gr.ada.support > Settings > Platform > API.

For the MCP server to connect, either:
- Launch Claude Code from `~/repos/ada-tablo-ops` (it reads `.env` automatically), OR
- Set `export ADA_API_TOKEN=your-token` in your shell profile

## Updating

When skills are updated in the marketplace:

```
/plugin marketplace update stg-marketplace
```

Or set `GITLAB_TOKEN` in your environment for automatic updates at startup.

## Owned By

David Gauthier and Lauren — Customer Support, Tablo
