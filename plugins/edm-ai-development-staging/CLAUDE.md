# EDM Plugin — Conventions for Contributors

This file documents the architectural rules, naming conventions, and configuration model for the EDM Claude Code plugin.
Read this before making changes — it captures decisions that aren't otherwise visible in the code.

## Architectural rules (do not violate)

### 1. `skills/` is the only entry point — there is no `commands/`

Per the Claude Code plugin docs, `commands/` is the legacy location for skills-as-flat-files. New plugins use `skills/`.
Both invoke the same way (`/edm:name`), so maintaining both is pure duplication. **Do not re-introduce a `commands/`
directory.**

### 2. Skills are the source of truth for orchestration

Each phase skill (`skills/orchestrator/SKILL.md`, `skills/plan/SKILL.md`, etc.) contains:

- Methodology context (what is EDM, when to use it)
- Step-by-step operational orchestration
- The HITL gate prompts

Agents are invoked from skills, not the other way around. Skills don't load other skills — they each contain their own
orchestration.

### 3. Artifacts live in the project's `SRD/` directory and are committed to git

Every artifact EDM produces — planning notes, SRDs, ticket packs, audit reports, code-audit remediation plans, *
*and `.edm-state.json`** — is a project deliverable that lives in the repository's `SRD/` directory. Source control IS
the feature:

- A teammate reviews the SRD in a PR before any code is written
- Ticket pack changes show up in code review
- Audit findings are inspectable in commit history
- Multiple developers see the same in-flight initiative state

`${CLAUDE_PLUGIN_DATA}` is reserved for plugin-internal caches only (convention detection, prefix lookup tables). It
does NOT hold initiative artifacts or initiative state.

### 4. State is in the project, not the plugin

`SRD/{PREFIX}/.edm-state.json` is committed by default. Teams that want per-developer state can add it to `.gitignore` (
controlled by the `commit_state_file` user-config option).

## Project artifact layout

```
SRD/                              ← project root, committed to git
├── {PREFIX}/                     ← one directory per initiative
│   ├── planning.md               ← Phase 1 output
│   ├── srd.md                    ← Phase 2 output (filename configurable)
│   ├── audit-srd.md              ← Phase 3 audit findings
│   ├── tickets/                  ← Phase 4 (dirname configurable)
│   │   ├── README.md             ← index, legend, critical path, coverage map, version-linkage header
│   │   ├── audit.md              ← Phase 5 ticket-pack audit
│   │   └── epics/
│   │       ├── 01-{epic}.md
│   │       └── 02-{epic}.md
│   ├── code-audit/
│   │   └── {YYYY-MM-DD}/
│   │       ├── lens-L1.md … lens-L11.md
│   │       └── REMEDIATION.md
│   ├── HANDOFF.md                ← auto-generated cross-user resume doc (updated at every phase/gate/stop)
│   └── .edm-state.json           ← gate approvals, phase timestamps (committed by default)
```

The plugin reads paths from `userConfig`, so teams can relocate the entire tree:

- `${user_config.srd_root}` (default `./SRD`)
- `${user_config.srd_filename}` (default `srd.md`)
- `${user_config.ticket_pack_dirname}` (default `tickets`)

### Existing repository conventions (informational)

The project may contain an `/SRD/` directory with initiatives that pre-date the plugin and use older patterns. The
plugin does NOT migrate these — they keep their current format. New initiatives created via the plugin use the cleaner
directory-per-initiative layout above.

## Naming conventions

### Initiative prefix

3–6 uppercase characters, e.g., `AUTH`, `MIGR`, `TIPS`, `PERF`. Validated by `bin/edm-validate-prefix` for uniqueness
within `SRD/`. Configurable hint: `${user_config.prefix_format_hint}`.

### Requirement IDs (in SRDs)

`{PREFIX}-{NN}` — e.g., `AUTH-01`, `AUTH-02`, …, `AUTH-37`.

### Ticket IDs (in ticket packs)

`{PREFIX}-T{NN}` — e.g., `AUTH-T01`, `AUTH-T02`, …, `AUTH-T48`.

The `T` prefix distinguishes tickets from SRD requirements and prevents global collision across initiatives. **Never use
the legacy `TICK-NN` format**; the plan ID disambiguates initiatives in cross-initiative coverage maps.

### Version-linkage in ticket packs

Every ticket pack `README.md` body's first line MUST be:

```
Generated From: ${user_config.srd_filename} v{srd_version}
```

The `srd_version` is read from `.edm-state.json`. The `edm-ticket-auditor` (Dimension 8 — Version Alignment) verifies
this against the current SRD version and flags drift as a P0 finding.

## Agent color scheme (semantic)

| Color     | Agent(s)                                              | Meaning                                 |
|-----------|-------------------------------------------------------|-----------------------------------------|
| `yellow`  | `edm-explorer`                                        | Phase 1 — discovery                     |
| `blue`    | `edm-architect`, `edm-srd-writer`                     | Phase 2 — writing                       |
| `orange`  | `edm-srd-auditor`, `edm-ticket-auditor`               | Phase 3 & 5 — pre-implementation audits |
| `magenta` | `edm-ticket-writer`                                   | Phase 4 — writing tickets               |
| `green`   | `edm-implementer`                                     | Phase 6 — building                      |
| `red`     | `edm-qc-auditor`                                      | Phase 6 QC — final gate                 |
| `cyan`    | all 11 `edm-audit-*` lenses + `edm-audit-synthesizer` | Code audit (one logical operation)      |

When adding a new agent, choose a color that matches the phase. Lens agents always share `cyan`.

## Model and effort assignments

| Role | Model | Effort | Rationale |
|---|---|---|---|
| Planning, audit, QC | `opus` | `max` | Judgment-heavy work — surface subtle issues |
| Writing (SRD, tickets) | `opus` | `high` | High-stakes artifacts the rest of the methodology depends on; opus catches missed requirements and weak ACs that sonnet sometimes misses |
| Implementation | `sonnet` | `high` | Throughput work — well-specified by tickets |
| Code audit lenses + synthesizer | `opus` | `max` | Each lens hunts for subtle, lens-specific issues |
| Jira sync (optional) | `sonnet` | `high` | Mechanical mapping — ticket pack already exists; this just translates fields |

Skills mirror the split: `skills/orchestrator/`, `skills/plan/`, `skills/srd/`, `skills/audit-srd/`, `skills/tickets/`, `skills/audit-tickets/`, `skills/implement/`, `skills/code-audit/` are all on `opus`. The two writers run at `effort: high`; planning, audits, and QC run at `effort: max`. `skills/push-jira/` and `skills/metrics/` run on `sonnet`/`high`.

## Cost tracking

Every `phase-complete` invocation captures token usage from the project's session JSONL files (
`~/.claude/projects/<encoded-cwd>/*.jsonl`) and computes Claude API cost using current Anthropic pricing. The state
schema's `phase_durations[N_phase]` entry includes:

- `tokens.{input, output, cache_read, cache_write}` — raw counts
- `model_used` — the model that handled most of the phase work (last assistant message)
- `estimated_cost_usd` — computed from tokens × per-million-token rates
- `human_baseline_usd` — computed from Phase Timing Guidelines median hours × `${user_config.human_hourly_rate_usd}` (
  default $150/hr)

Pricing constants (per million tokens, USD) are baked in but env-overridable:

| Model | Input | Output | Cache Read | Cache Write 5m | Cache Write 1h |
|---|---|---|---|---|---|
| Opus 4.7 | $5 | $25 | $0.50 | $6.25 | $10.00 |
| Sonnet 4.6 | $3 | $15 | $0.30 | $3.75 | $6.00 |
| Haiku 4.5 | $1 | $5 | $0.10 | $1.25 | $2.00 |

Verified May 2026 against [docs.anthropic.com/en/docs/about-claude/pricing](https://docs.anthropic.com/en/docs/about-claude/pricing).

Override with `EDM_OPUS_INPUT_RATE`, `EDM_SONNET_OUTPUT_RATE`, `EDM_HAIKU_CACHE_READ_RATE`, `EDM_OPUS_CACHE_WRITE_5M_RATE`, `EDM_OPUS_CACHE_WRITE_1H_RATE`, etc. when rates change.

Cache writes are tracked separately by TTL (5-minute vs 1-hour) because they have different rates. Claude Code typically uses 1-hour caching for system prompts and tool definitions, so `cache_write_1h` is usually the dominant figure.

Token reading depends on the path encoding `~/.claude/projects/{cwd_with_slashes_and_dots_as_hyphens}/*.jsonl`. The
`session_dir_for_cwd` helper in `bin/edm-state` handles this.

## Testing layer

`/edm:test <PREFIX>` runs comprehensive multi-layer test coverage after Phase 6 implementation. It
is user-invocable, not auto-triggered. The `/edm:orchestrator` flow suggests it at the end of
Phase 6, but the user decides whether to run it.

### Test artifacts (project-resident, source-controlled)

Two new artifacts are added to `SRD/{PREFIX}/`:

| File | Written by | Purpose |
|------|-----------|---------|
| `test-plan.md` | `edm-test-planner` | Stack detection, AC↔layer mapping, writer task assignments |
| `test-coverage.md` | `edm-test-coverage-auditor` | Coverage by layer vs. targets, AC↔test cross-reference, P0/P1/P2 gaps |

Test code itself lives in the project's existing test directories — `SRD/` artifacts document
*intent and coverage*, not the tests themselves.

### Testing layer agent inventory

| Agent | Model/Effort | Color | maxTurns | Role |
|-------|-------------|-------|---------|------|
| `edm-test-planner` | opus / high | yellow | 30 | Detect stack; map tickets → test layers; write `test-plan.md` |
| `edm-test-scaffold` | sonnet / high | blue | 30 | Install missing test deps, write config files |
| `edm-test-unit` | sonnet / high | green | 50 | Pure-function unit tests, mock-isolated |
| `edm-test-component` | sonnet / high | green | 50 | UI component tests (RTL, Vue Test Utils, etc.) |
| `edm-test-composable` | sonnet / high | green | 50 | React hooks / Vue composables |
| `edm-test-integration` | sonnet / high | green | 50 | Multi-module / real DB / HTTP tests |
| `edm-test-contract` | sonnet / high | green | 50 | API contract tests (OpenAPI/Swagger-driven) |
| `edm-test-e2e` | sonnet / high | green | 60 | Playwright/Cypress full user journeys |
| `edm-test-a11y` | sonnet / high | green | 30 | axe-core + keyboard nav, WCAG 2.1 AA |
| `edm-test-coverage-auditor` | opus / max | cyan | 25 | Read-only: parse coverage, cross-ref AC, find gaps |

`edm-test-coverage-auditor` is `cyan` (read-only audit lens, like the code-audit lenses). Test
writers are `green` (build code, like `edm-implementer`). Planner is `yellow` (discovery, like
`edm-explorer`). Scaffold is `blue` (writes infrastructure, like `edm-architect`).

`edm-test-coverage-auditor` has `disallowedTools: Write, Edit, NotebookEdit`.

### Coverage targets (userConfig)

| Key | Default | Description |
|-----|---------|-------------|
| `coverage_target_unit_pct` | 80 | Minimum unit test coverage % |
| `coverage_target_component_pct` | 70 | Minimum component test coverage % |
| `coverage_target_integration_pct` | 60 | Minimum integration test coverage % |
| `coverage_target_e2e_critical_paths_pct` | 100 | % of critical paths with E2E coverage |
| `test_framework_unit_override` | `""` | Pin unit framework (e.g., `jest`, `vitest`, `pytest`) |
| `test_framework_component_override` | `""` | Pin component framework |
| `test_framework_e2e_override` | `""` | Pin E2E framework (`playwright` or `cypress`) |

### State schema additions

`.edm-state.json` gains two new top-level fields (added by `edm-state init`, `{}` default):

```json
{
  "test_frameworks_detected": { "unit": "pytest", "component": null, "e2e": "playwright" },
  "coverage_by_layer": {
    "unit": { "pct": 82.4, "measured_at": "2026-05-01T..." },
    "integration": { "pct": 65.1, "measured_at": "2026-05-01T..." }
  }
}
```

`phase_durations[N_phase]` gains `tests_added` (total) and `tests_by_layer` (per layer) counts
when `edm-state record-tests-added` is called.

### New bin/edm-state subcommands

| Subcommand | Usage |
|-----------|-------|
| `record-test-coverage <PREFIX> <layer> <pct>` | Record coverage % for one layer |
| `record-tests-added <PREFIX> <phase> <layer> <count>` | Increment test count for phase+layer |
| `get-coverage <PREFIX>` | Print coverage summary |

`metrics-report <PREFIX>` now includes a test coverage table below the cost/time table if
coverage data has been recorded.

### When to invoke /edm:test

Run it after all Phase 6 implementation waves complete and before declaring the initiative done.
For `--fill-gaps` mode (fill ALL gaps — P0, P1, and P2 — in an existing coverage report), pass the flag:
`/edm:test {PREFIX} --fill-gaps`.

### Layers that are N/A

Each test-writer agent self-identifies when its layer doesn't apply and exits cleanly:
- `component`, `composable`, `a11y`, `e2e` are N/A for backend-only or CLI-only projects.
- `contract` is N/A for projects without an API schema.
- `composable` is N/A for projects without React hooks or Vue composables.

The planner marks them N/A in `test-plan.md` so writers skip them without being spawned.

## Optional: Jira synchronization

`skills/push-jira/SKILL.md` (invoked as `/edm:push-jira <PREFIX> [PROJECT_KEY]`) optionally pushes the ticket pack to Jira via the Atlassian MCP. It is **strictly opt-in**:

- The skill checks `mcp__{jira_mcp_namespace}__atlassianUserInfo` first (namespace defaults to `plugin_jira_atlassian-mcp-server`; override via `${user_config.jira_mcp_namespace}`); if unavailable, it skips with a friendly message.
- Tickets are tracked in Jira via labels (`edm-{prefix}-t{nn}`) — no custom Jira fields required.
- Re-running is idempotent: existing issues are updated, not duplicated.
- Status, comments, and worklog on Jira issues are preserved across re-runs.
- Dependencies become Issue Links of type `Blocks` (or `Relates` if `Blocks` isn't available).
- Each ticket file gets a Jira link appended after first push: `## AUTH-T01: …  ([MCP-1234](https://….atlassian.net/browse/MCP-1234))`.
- A summary of all sync actions is written to `${user_config.srd_root}/{PREFIX}/${user_config.ticket_pack_dirname}/jira-sync.md`.

The skill does NOT push during active implementation (Phase 6) — let the markdown ticket pack stay authoritative. Re-sync after the initiative completes if desired.

The `userConfig.jira_project_key` value provides a default; otherwise the user must pass `<PROJECT_KEY>` as the second argument.

## Hooks behavior

`hooks/hooks.json` configures:

| Event                                                          | Effect                                                        |
|----------------------------------------------------------------|---------------------------------------------------------------|
| `SessionStart`                                                 | Print in-progress initiatives via `edm-state list`            |
| `UserPromptExpansion` matching `edm:(srd\|tickets\|implement)` | Block expansion if the prerequisite HITL gate isn't approved  |
| `Stop` and `PreCompact`                                        | Checkpoint state via `edm-state checkpoint-if-active`         |
| `SubagentStop` matching `edm-implementer`                      | Auto-spawn `edm-qc-auditor` to verify the just-completed work |
| `TaskCompleted`                                                | Record per-task durations for `/edm:metrics` reporting        |

These are part of the methodology — do not disable them in normal operation.

## `bin/` helper scripts

Scripts in `bin/` are added to PATH while the plugin is enabled. Skills call them by bare name.

| Script                | Purpose                                                                                                                                                                                                                                     |
|-----------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `edm-state`           | Read/write `.edm-state.json` files; subcommands: `get`, `set`, `list`, `approve-gate`, `checkpoint-if-active`, `archive`, `phase-start`, `phase-complete`, `record-task-duration`, `write-handoff`, `watch-impl`, `metrics-report` |
| `edm-init`            | Scaffold a new `SRD/{PREFIX}/` directory with empty state file                                                                                                                                                                              |
| `edm-validate-prefix` | Verify a proposed prefix doesn't collide with existing initiatives                                                                                                                                                                          |

Operates against the project's working directory (no plugin-relative paths). All scripts must be POSIX-compatible bash (
`#!/bin/bash` or `#!/usr/bin/env bash`).

## `userConfig` reference

Prompted at install time. See `plugin.json` for the live schema. Keys:

- `srd_root` — output root directory (default `./SRD`)
- `srd_filename` — SRD file inside `{PREFIX}/` (default `srd.md`)
- `ticket_pack_dirname` — ticket pack subdir name (default `tickets`)
- `prefix_format_hint` — hint shown when prompting for prefix (default `UPPERCASE 3-6 chars`)
- `commit_state_file` — whether `.edm-state.json` is git-tracked (default `true`)

Skills reference values as `${user_config.srd_root}` etc.

## Testing changes

After modifying any plugin component:

1. `claude plugin validate edm-plugin/` — schema and frontmatter check
2. Test in a sandbox: `claude --plugin-dir ./edm-plugin`
3. Run `/reload-plugins` to pick up changes without restarting
4. Verify agents appear in `/agents`, skills in `/help`

## Related documentation

- `README.md` — user-facing install + usage
- `CHANGELOG.md` — version history
- The official Claude Code plugin docs: `code.claude.com/docs/en/plugins`, `code.claude.com/docs/en/plugins-reference`
- Existing initiatives at `/SRD/` — informational reference for the legacy convention
