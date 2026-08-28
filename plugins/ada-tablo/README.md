# Ada-Tablo Plugin

Analysis skills for the Tablo Ada chatbot support system. Used by David and Lauren for weekly and monthly performance reviews.

## Skills

| Skill | Frequency | Purpose |
|-------|-----------|---------|
| `/ada-tablo:weekly-playbook-analysis` | Weekly (Fridays) | Playbook effectiveness review — CSV export, script analysis, baseline comparison, changeset-gated edits |
| `/ada-tablo:weekly-topics-review` | Weekly (Fridays) | Catch-all reduction — topics report analysis, recommendation generation |
| `/ada-tablo:coaching-review` | Monthly | Coaching inventory sync, resolution rate measurement, performance tracking |
| `/ada-tablo:config-health` | Standalone / pre-cutover / pre-promote gate | Structural integrity check — orphan variable reads, unbound action outputs, dangling references, null conflation. Read-only. |
| `/ada-tablo:deterministic-logic` | On demand | Move computable logic out of playbook prose into a code tool (sandboxed Python) or Answers Utility endpoint. Local case-table test, then changeset-gated deploy. |

Two internal helper skills (`preflight`, `commit-results`) handle workspace setup and git operations automatically.

## Writing to Ada

Playbook, coaching, and topic edits go live through a **changeset** model on
`edit_agent_behavior` (playbooks, coaching, knowledge, custom instructions, api tools) and
`edit_agent_config` (topics, intents, test cases/runs, glossary, custom metrics/scorecards) —
stage on a changeset, preview the diff, get explicit user confirmation, then promote. The
older `propose_change` tool has been retired and no longer exists on the live MCP server.
Before promoting any playbook edit, run `/ada-tablo:config-health` on the affected
playbook(s) and a test run pinned to the changeset — see `weekly-playbook-analysis` Steps
9a/9b.

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

## Known Limitations and Security Posture

### Workspace repo (H1 — supply chain)

The Python scripts this plugin invokes live in `DavidG91/ada-tablo-ops`, a personal GitHub account. Scripts are pulled from `main` with no commit pinning and no Scripps org review gate. A compromise of that account would allow arbitrary code execution on any analyst's machine the next time `preflight` runs.

**Current status:** Accepted risk, tracked as a follow-up. Only analysts who trust the repo owner should install this plugin.

**Future mitigation:** Migrate `ada-tablo-ops` to a Scripps GitHub org and add commit-hash pinning in `preflight`. No ETA yet.

### PII and credential handling (M3 — confirmation pending)

Before adding analysts beyond the initial two users, confirm:

- [ ] `DavidG91/ada-tablo-ops` is set to **private** on GitHub
- [ ] `.gitignore` in the workspace repo excludes `.env` (which holds `ADA_API_TOKEN`)
- [ ] GitHub-hosted storage of Tablo customer support data is acceptable under Scripps' data-handling policy

**Owner:** David Gauthier — confirm with security/legal before broader rollout.

## Owned By

David Gauthier and Lauren — Customer Support, Tablo
