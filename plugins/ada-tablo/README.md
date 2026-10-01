# Ada-Tablo Plugin

Analysis skills for the Tablo Ada chatbot support system. Used by David and Lauren for weekly and monthly performance reviews.

## Skills

| Skill | Frequency | Purpose |
|-------|-----------|---------|
| `/ada-tablo:weekly-playbook-analysis` | On demand (Step 9); Steps 0-8 weekly | Step 9 is the deploy path every other skill hands off to: stage, check the staged diff, config-health on the staged body, the 3-rep test gate, deploy note, then promote or roll out on the user's yes. Steps 0-8 are the older per-playbook metrics review. |
| `/ada-tablo:weekly-topics-review` | Weekly (Fridays) | Catch-all reduction — topics report analysis, recommendation generation |
| `/ada-tablo:coaching-review` | Monthly | Coaching inventory sync and discovery of untracked rules, performance review on the weekly per-rule figures evidence-loop step 3b writes; coaching edits deploy through Step 9 |
| `/ada-tablo:config-health` | Standalone / pre-cutover / gate on a staged changeset or draft | Structural and behavioural integrity check — orphan variable reads, unbound action outputs, dangling references, null conflation, plus how the playbook behaves on a call: destructive warnings delivered with their own trigger, consecutive sends with no ask on voice, fixed messages carrying multi-step instructions, unguarded tool failure paths. Reads the live body, a staged changeset (`--changeset`) or a draft (`--draft`). Playbooks only. Read-only. |
| `/ada-tablo:playbook-authoring` | On demand | Draft or revise a playbook against the measured authoring rules, voice first. Checks the draft with config-health, then hands a change record to `weekly-playbook-analysis` Step 9, or for a `sections` edit a build spec to a `scripts/stage_playbook.py` script. Never deploys. |
| `/ada-tablo:deterministic-logic` | On demand | Move computable logic out of playbook prose into a code tool (sandboxed Python) or Answers Utility endpoint. Local case-table test, stage on a changeset, then the Step 9 gates and deploy. |
| `/ada-tablo:evidence-loop` | Weekly (Fridays) | Whole-population failure ranking with 15 weeks of history, one targeted transcript read David approves, an approval gate with pre-registered predictions, and test-case verification of a staged changeset (3 reps, gate GO/NO-GO). Writes only test cases and test runs. |
| `/ada-tablo:changeset-inspect` | On demand | Early read of a live changeset's before and after numbers for the playbooks, coaching rules and tools it touched, from Ada's own grading. Read-only on Ada. Never a verdict. |
| `/ada-tablo:work W#` | Any non-Friday session | Scoped work session on one item from the Ada-Evidence-Loop TODO. States the deliverable, does only that, files everything else as a finding, hands off to the owning skill, and stops with "Deliverable complete, nothing pending." |

Two internal helper skills (`preflight`, `commit-results`) handle workspace setup and git operations automatically.

## Writing to Ada

Playbook, coaching, and topic edits go live through a **changeset** model on
`edit_agent_behavior` (playbooks, coaching, knowledge, custom instructions, api tools) and
`edit_agent_config` (topics, intents, test cases/runs, glossary, custom metrics/scorecards) —
stage on a changeset, preview the diff, get explicit user confirmation, then promote. The
older `propose_change` tool has been retired and no longer exists on the live MCP server.
Before promoting or rolling out any playbook edit, run `/ada-tablo:config-health --changeset <id>`
on the staged body and the test gate (evidence-loop step 6, 3 reps per case); see
`weekly-playbook-analysis` Step 9. A rollout (`set_rollout`) samples a share of new
conversations up to a cap and has no confirm step, so it is asked first like a promote.

`/ada-tablo:playbook-authoring` sits upstream of all of this and has no write tools at all. It
drafts and checks, then hands the edit to `weekly-playbook-analysis` Step 9. A playbook's
`sections` field is too wide for a model tool call (F71), so a `sections` edit goes instead
through a `scripts/stage_playbook.py` script in the workspace repo, run on the user's yes in the
moment; Step 9 takes over from the staged changeset. The rules it authors
against live in the workspace repo at `reference/playbook_authoring_rules.md`, so they can be
corrected without a plugin release.

The driver selects an `evidence-loop/scripts/payload_<EDIT>.py` builder; new `sections` edits
add a builder registered in its `EDITS` tuple. Shared tree helpers live in
`evidence-loop/scripts/playbook_flow.py`.

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
