# Changelog

All notable changes to the EDM plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] — 2026-04-30

### Added — Comprehensive Testing Layer (`/edm:test`)

A full multi-layer test orchestration pipeline. Runs after Phase 6 implementation to build thorough, stack-aware coverage — not just "tests exist" but tests that meet configured coverage targets by layer.

#### New skills (3)

| Skill | Description |
|-------|-------------|
| `/edm:test <PREFIX>` | Full pipeline: plan → scaffold → write (parallel) → run → audit → record |
| `/edm:test-plan <PREFIX>` | Preview mode: detect stack + map ACs to layers, no writing |
| `/edm:test-coverage <PREFIX>` | Re-audit coverage against existing tests (no writing) |

#### New agents (10)

| Agent | Model | Color | Role |
|-------|-------|-------|------|
| `edm-test-planner` | opus / high | yellow | Stack detection, AC↔layer mapping, writes `test-plan.md` |
| `edm-test-scaffold` | sonnet / high | blue | Installs missing test deps + config files (asks before installing) |
| `edm-test-unit` | sonnet / high | green | Pure-function unit tests, mocked at boundaries |
| `edm-test-component` | sonnet / high | green | UI component tests (RTL, Vue Test Utils, Svelte, Angular) |
| `edm-test-composable` | sonnet / high | green | React hooks and Vue composables via renderHook / wrapper |
| `edm-test-integration` | sonnet / high | green | Multi-module tests with real DB or HTTP |
| `edm-test-contract` | sonnet / high | green | API contract tests driven by OpenAPI/GraphQL schema |
| `edm-test-e2e` | sonnet / high | green | Playwright/Cypress critical path journeys, page-object pattern |
| `edm-test-a11y` | sonnet / high | green | axe-core scans + keyboard nav, WCAG 2.1 AA |
| `edm-test-coverage-auditor` | opus / max | cyan | Read-only: coverage parse + AC↔test cross-reference + gap findings |

#### New project artifacts

| File | Written by |
|------|-----------|
| `SRD/{PREFIX}/test-plan.md` | `edm-test-planner` |
| `SRD/{PREFIX}/test-coverage.md` | `edm-test-coverage-auditor` |

#### State schema additions

- `test_frameworks_detected: {}` — auto-detected framework per layer; written by `edm-test-planner`.
- `coverage_by_layer: {}` — `{pct, measured_at}` per layer; written by `edm-state record-test-coverage`.
- `phase_durations[N_phase].tests_added` and `.tests_by_layer` — written by `edm-state record-tests-added`.

#### New `userConfig` keys (7)

Coverage targets (defaults match typical project standards): `coverage_target_unit_pct` (80), `coverage_target_component_pct` (70), `coverage_target_integration_pct` (60), `coverage_target_e2e_critical_paths_pct` (100). Framework override strings: `test_framework_unit_override`, `test_framework_component_override`, `test_framework_e2e_override` — pin a framework when auto-detection is ambiguous.

#### New `bin/edm-state` subcommands (3)

`record-test-coverage <PREFIX> <layer> <pct>`, `record-tests-added <PREFIX> <phase> <layer> <count>`, `get-coverage <PREFIX>`.

`metrics-report <PREFIX>` now includes a test coverage table when data is available.

#### Existing files updated

- `agents/edm-implementer.md` — clarified role: write basic smoke tests per ticket; comprehensive coverage comes from `/edm:test` afterward.
- `agents/edm-audit-test-quality.md` — added reference to `/edm:test` as the fix path for L4 findings.
- `skills/implement/SKILL.md` — Step 6 now recommends `/edm:test` before declaring Phase 6 done.
- `skills/orchestrator/SKILL.md` — Step 7b now suggests `/edm:test` between QC pass and final declaration; artifact layout updated to include test artifacts.

### Why

EDM's six-phase process produces well-specified code — but specification alone doesn't guarantee test coverage. Teams using Phase 6 implementers ended up with whatever smoke tests the implementer threw in alongside the code: often shallow, often missing error paths, almost never integration or E2E. The testing layer fills that gap with a structured, parallel, stack-aware pipeline. The `test-plan.md` and `test-coverage.md` artifacts make coverage intent and actuals visible in PRs alongside every other EDM artifact.

---

## [1.2.0] — 2026-05-01

### Changed — Writers upgraded to Opus
- `edm-srd-writer` and `edm-ticket-writer` agents (and their parent skills `skills/srd/`, `skills/tickets/`) now run on `model: opus, effort: high` (was `sonnet, high`). High-stakes artifacts the rest of the methodology depends on benefit from Opus's stronger judgment, even at writing-throughput effort. Audits and QC remain on `opus, max`.

### Added — `/edm:push-jira` (optional Jira synchronization)
- New skill `skills/push-jira/SKILL.md`. Pushes the ticket pack to a Jira project via the Atlassian MCP server.
- Idempotent — re-runs update existing issues instead of creating duplicates. Tracks EDM tickets in Jira via labels (`edm-{prefix}-t{nn}`); no Jira custom fields required.
- Preserves Jira-side state (status, comments, worklog) across re-runs.
- Dependencies become Issue Links of type `Blocks` (or `Relates`).
- Writes Jira keys back into the source ticket pack: `## AUTH-T01: …  ([MCP-1234](https://….atlassian.net/browse/MCP-1234))`.
- Writes a sync summary to `${ticket_pack_dirname}/jira-sync.md`.
- Tracks `jira_synced_at` and `jira_project_key` in `.edm-state.json`.
- Skips gracefully with a friendly message if the Atlassian MCP isn't connected — strictly opt-in.
- New userConfig key `jira_project_key` (optional, no default).

### Fixed — Pricing constants updated to current Anthropic rates (verified May 2026)
Per [docs.anthropic.com/en/docs/about-claude/pricing](https://docs.anthropic.com/en/docs/about-claude/pricing):

| Model | Input | Output | Cache Read | Cache Write 5m | Cache Write 1h |
|---|---|---|---|---|---|
| Opus 4.7 | $5 (was $15) | $25 (was $75) | $0.50 (was $1.50) | $6.25 (was $18.75) | $10.00 (NEW) |
| Sonnet 4.6 | $3 | $15 | $0.30 | $3.75 | $6.00 (NEW) |
| Haiku 4.5 | $1 (was $0.80) | $5 (was $4) | $0.10 (was $0.08) | $1.25 (was $1) | $2.00 (NEW) |

Cache writes are now tracked separately by TTL (5-minute vs 1-hour) because they have different rates. Token reading parses `cache_creation.ephemeral_5m_input_tokens` and `cache_creation.ephemeral_1h_input_tokens` from session JSONLs.

New env var overrides: `EDM_OPUS_CACHE_WRITE_5M_RATE`, `EDM_OPUS_CACHE_WRITE_1H_RATE`, etc. (likewise for Sonnet and Haiku).

State schema's `tokens` field changes from `{input, output, cache_read, cache_write}` to `{input, output, cache_read, cache_write_5m, cache_write_1h}`.

### Why
Pricing accuracy: prior cost numbers in v1.1.0 reports were ~3× too high for Opus phases due to outdated rate constants, undermining the credibility of the human-baseline savings ratio. Now corrected.

Writers upgraded: surveying real EDM runs, the most common quality issue at HITL Gate 2 was vague or incomplete acceptance criteria from sonnet-written tickets. Opus catches more.

Jira: requested by teams that need EDM artifacts visible alongside their existing sprint planning workflow.

---

## [1.1.0] — 2026-05-01

### Added — Cost tracking per phase
- `bin/edm-state` reads token usage from Claude Code's session JSONL files (`~/.claude/projects/<encoded-cwd>/*.jsonl`) and computes per-phase Claude API cost from token counts × Anthropic pricing.
- `phase-complete` now records: `tokens.{input,output,cache_read,cache_write}`, `model_used`, `estimated_cost_usd`, and `human_baseline_usd`.
- `metrics-report <PREFIX>` shows: Phase | Duration | Claude Cost | Human Cost | Savings (ratio) | Tokens | Model. Total row reports overall savings vs. human baseline (e.g., "42× cheaper").
- `metrics-report --all` aggregates costs across all initiatives.
- `metrics-report --calibrate` now includes median cost per (size, phase) alongside median duration.
- New userConfig key `human_hourly_rate_usd` (default $150) drives the human-baseline computation.
- Pricing is overridable via env vars: `EDM_OPUS_INPUT_RATE`, `EDM_SONNET_OUTPUT_RATE`, `EDM_HAIKU_CACHE_READ_RATE`, etc.
- Path-encoding fix: `~/.claude/projects/<cwd>` encodes both `/` and `.` as `-`.

### Why
EDM's value proposition rests on the cost-of-rework argument. Now teams can prove it numerically: "this initiative cost the team $X in Claude API; the same work would have cost $Y in human time at our $/hr rate." Stakeholder conversations get easier when the savings ratio is in the report.

---

## [1.0.0] — 2026-04-30

Initial release. Implements the EDM Plugin Remediation Plan.

### Added — Architecture
- Single-source-of-truth model: skills/ is the only entry point; no commands/ directory.
- Project-resident artifacts: every output lives in `SRD/{PREFIX}/` and is committed to git.
- Initiative state file at `SRD/{PREFIX}/.edm-state.json` (committed by default; configurable).

### Added — Skills (8 phase skills + 1 reporting skill)
- `/edm:orchestrator` — full 6-phase methodology with HITL gates
- `/edm:plan` — Phase 1 Planning & Discovery
- `/edm:srd` — Phase 2 SRD Creation
- `/edm:audit-srd` — Phase 3 SRD Audit (7 categories)
- `/edm:tickets` — Phase 4 Ticket Pack Creation (with version-linkage header)
- `/edm:audit-tickets` — Phase 5 Ticket Pack Audit (8 dimensions including version alignment)
- `/edm:implement` — Phase 6 Implementation + automatic QC + remediation
- `/edm:code-audit` — Post-Phase 6 11-lens exhaustive audit
- `/edm:metrics` — per-phase duration reporting and calibration

All phase skills carry `disable-model-invocation: true`. Planning, audit, and QC skills run on `model: opus, effort: max`.

### Added — Agents (20 total)
- Phase agents: `edm-explorer`, `edm-architect` (with Write tool), `edm-srd-writer`, `edm-srd-auditor`, `edm-ticket-writer`, `edm-ticket-auditor`, `edm-implementer` (with `isolation: worktree`), `edm-qc-auditor`.
- 11 code-audit lens agents (`edm-audit-logic`, `…-dead-code`, `…-edge-cases`, `…-test-quality`, `…-runtime`, `…-docs`, `…-consistency`, `…-security`, `…-spec`, `…-dry`, `…-wiring`) plus `edm-audit-synthesizer` for plan aggregation.
- All read-only audit agents have `disallowedTools: Write, Edit, NotebookEdit`.
- `maxTurns` set on every agent. Semantic color scheme applied.

### Added — Hooks (`hooks/hooks.json`)
- `SessionStart` — prints in-progress initiatives via `edm-state list`.
- `UserPromptExpansion` (matcher: `edm:(srd|tickets|implement)`) — blocks expansion if the prerequisite HITL gate isn't approved.
- `Stop` and `PreCompact` — opportunistically checkpoint state.
- `SubagentStop` (matcher: `edm-implementer`) — auto-spawns `edm-qc-auditor` after every implementer completes.
- `TaskCompleted` — records per-task durations for `/edm:metrics`.

### Added — Helper scripts (`bin/`)
- `edm-state` — read/write `SRD/{PREFIX}/.edm-state.json` with subcommands: `get`, `set`, `init`, `list`, `approve-gate`, `phase-start`, `phase-complete`, `checkpoint-if-active`, `record-task-duration`, `archive`, `watch-impl`, `metrics-report`.
- `edm-init` — scaffold a new initiative directory.
- `edm-validate-prefix` — verify prefix uniqueness and format.

### Added — Background monitor (`monitors/monitors.json`)
- `edm-impl-progress` — during `/edm:implement`, tails git log for ticket commits and emits notifications.

### Added — Configuration (`plugin.json` `userConfig`)
- `srd_root` (directory, default `./SRD`)
- `srd_filename` (string, default `srd.md`)
- `ticket_pack_dirname` (string, default `tickets`)
- `prefix_format_hint` (string, default `UPPERCASE 3-6 chars (AUTH, MIGR, TIPS)`)
- `commit_state_file` (boolean, default `true`)

### Added — Documentation
- `README.md` — user-facing install and usage
- `CLAUDE.md` — contributor conventions (architectural rules, layout, naming, colors, models, hooks, bin scripts, userConfig)
- `CHANGELOG.md` — this file

### Conventions
- Initiative prefix: 3–6 uppercase chars (e.g., `AUTH`, `MIGR`).
- SRD requirement IDs: `{PREFIX}-NN` (e.g., `AUTH-01`).
- Ticket IDs: `{PREFIX}-T{NN}` (e.g., `AUTH-T01`) — never the legacy `TICK-NN`.
- Version linkage: ticket pack `README.md` body's first line is `Generated From: srd.md v{srd_version}`.

### Known limitations
- Multi-developer concurrent edits to `.edm-state.json` are not file-locked (intentional — gate approvals are sequenced by HITL anyway).
- Existing `/SRD/` initiatives in this repository (TIPS, deep-chat-gui, microsoft_graph_mcp, etc.) use older naming conventions; the plugin does not migrate them. New initiatives use the cleaner directory-per-initiative layout.
- `edm-implementer` is generic with stack detection; language-specialized variants (Python, Go, TypeScript, etc.) are deferred to a future release.
