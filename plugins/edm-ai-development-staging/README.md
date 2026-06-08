# EDM Plugin — Enterprise Development Methodology

A Claude Code plugin that packages the Enterprise Development Methodology as user-invocable skills. EDM is a six-phase process for shipping complex software with high confidence, designed for AI-assisted parallel execution.

The plugin produces source-controlled artifacts in your project's `SRD/` directory — every planning doc, SRD, ticket pack, and audit report lives in git alongside your code.

## Install

```bash
# Local install (from the marketplace repo root):
claude plugin install ./plugins/edm-ai-development

# Or development mode (no install required):
claude --plugin-dir ./plugins/edm-ai-development
```

When installed, Claude Code prompts for a few `userConfig` values (defaults are sensible — accept them unless your team uses different paths).

## Slash commands

All EDM phases are user-invocable as `/edm:<name>`:

| Command | Phase | Description |
|---|---|---|
| `/edm:orchestrator <description>` | All 6 | Full methodology end-to-end with all HITL gates |
| `/edm:plan <PREFIX> <description>` | 1 | Planning & Discovery — scope, inventory, go/no-go decision |
| `/edm:srd <PREFIX>` | 2 | SRD Creation — requirements document with `{PREFIX}-NN` IDs |
| `/edm:audit-srd <PREFIX>` | 3 | SRD Audit — 7-category review, remediates all P0/P1 findings |
| `/edm:tickets <PREFIX>` | 4 | Ticket Pack — `{PREFIX}-T{NN}` tickets with 6-12 testable AC each |
| `/edm:audit-tickets <PREFIX>` | 5 | Ticket Audit — 8-dimension validation including SRD version alignment |
| `/edm:implement <PREFIX>` | 6 | Implementation — parallel waves with auto-QC after each wave |
| `/edm:code-audit <PREFIX>` | Post-6 | 11-lens exhaustive audit + synthesizer-produced remediation plan |
| `/edm:metrics <PREFIX\|--all\|--calibrate>` | Reporting | Per-phase durations, gate review times, Claude/human cost comparison, calibration |
| `/edm:push-jira <PREFIX> [PROJECT_KEY]` | Optional | Sync ticket pack to Jira via Atlassian MCP (idempotent, label-tracked, dependency-linked) |
| `/edm:test <PREFIX>` | Post-6 | Comprehensive testing pipeline: plan → scaffold → write (unit/component/composable/integration/contract/E2E/a11y) → run → audit coverage |
| `/edm:test-plan <PREFIX>` | Post-6 | Preview test scope only: detect stack + map AC to layers, no test writing |
| `/edm:test-coverage <PREFIX>` | Post-6 | Re-audit coverage against existing tests, update `test-coverage.md` |

All phase skills set `disable-model-invocation: true` — Claude won't auto-fire them on casual prompts. Use the slash commands explicitly.

## Agents

| Agent | Phase | Model |
|---|---|---|
| `edm-explorer` | 1 — Planning | opus / max |
| `edm-architect` | 2 — Architecture | opus / max |
| `edm-srd-writer` | 2 — SRD content | opus / high |
| `edm-srd-auditor` | 3 — SRD audit | opus / max (read-only) |
| `edm-ticket-writer` | 4 — Tickets | opus / high |
| `edm-ticket-auditor` | 5 — Ticket audit | opus / max (read-only) |
| `edm-implementer` | 6 — Code | sonnet / high (worktree-isolated) |
| `edm-qc-auditor` | 6 — QC | opus / max (read-only, auto-spawned) |
| `edm-audit-{logic,dead-code,edge-cases,test-quality,runtime,docs,consistency,security,spec,dry,wiring}` | Code audit | opus / max (read-only, parallel) |
| `edm-audit-synthesizer` | Code audit | opus / max |
| `edm-test-planner` | Testing | opus / high (yellow) — stack detection, AC↔layer mapping |
| `edm-test-scaffold` | Testing | sonnet / high (blue) — install missing test infra |
| `edm-test-unit` | Testing | sonnet / high (green) — unit tests, mocked |
| `edm-test-component` | Testing | sonnet / high (green) — UI component tests |
| `edm-test-composable` | Testing | sonnet / high (green) — React hooks / Vue composables |
| `edm-test-integration` | Testing | sonnet / high (green) — multi-module / real DB |
| `edm-test-contract` | Testing | sonnet / high (green) — OpenAPI/GraphQL contract tests |
| `edm-test-e2e` | Testing | sonnet / high (green) — Playwright/Cypress journeys |
| `edm-test-a11y` | Testing | sonnet / high (green) — axe-core + keyboard nav |
| `edm-test-coverage-auditor` | Testing | opus / max (cyan, read-only) — coverage gaps + AC cross-ref |

## When to Use EDM

| Scenario | Use EDM? |
|---|---|
| New feature touching 10+ files | Yes — full six phases |
| Large refactor or migration | Yes |
| New service or module | Yes |
| Bug fix (1-3 files) | No — just fix it |
| Config/dependency update | No — just do it |
| Exploratory prototype | Partial — phases 1-2 only |

## The Six Phases

```
Phase 1      HITL     Phase 2      Phase 3      HITL     Phase 4       Phase 5      HITL     Phase 6
Planning --> GATE --> SRD     -->  Audit   --> GATE --> Tickets --> Audit    --> GATE --> Implementation
             #1      Creation     (SRD)        #2      Creation    (Tickets)    #3       + QC + Remediation
```

Three HITL gates require explicit human sign-off. The plugin enforces them via the `UserPromptExpansion` hook — `/edm:srd`, `/edm:tickets`, and `/edm:implement` will refuse to expand if the prerequisite gate isn't approved.

## Project artifact layout

Every artifact lives in your project's `SRD/` directory and is committed to git:

```
SRD/
└── {PREFIX}/
    ├── planning.md               ← Phase 1
    ├── srd.md                    ← Phase 2 (filename configurable)
    ├── audit-srd.md              ← Phase 3
    ├── tickets/                  ← Phase 4 (dirname configurable)
    │   ├── README.md             ← index, legend, critical path, coverage map, version-linkage header
    │   ├── audit.md              ← Phase 5 audit
    │   └── epics/
    │       ├── 01-{epic}.md
    │       └── 02-{epic}.md
    ├── code-audit/
    │   └── {YYYY-MM-DD}/
    │       ├── lens-L1.md … lens-L11.md
    │       └── REMEDIATION.md
    └── .edm-state.json           ← gate approvals, phase timestamps (committed by default)
```

Artifacts are reviewed in PRs. Gate approvals show up in git history. Multiple developers see the same in-flight initiative state.

## Phase Timing Guidelines

| Initiative Size | Total Estimate |
|---|---|
| Small (10-20 tickets) | 1-2 days |
| Medium (30-50 tickets) | 3-5 days |
| Large (50-85 tickets) | 5-10 days |

Run `/edm:metrics --calibrate` after a few completed initiatives to recalibrate these from your team's actual data.

## Plugin features

- **Hooks** (`hooks/hooks.json`): SessionStart prints in-progress initiatives; UserPromptExpansion enforces gate approval; Stop/PreCompact checkpoint state; SubagentStop auto-fires `edm-qc-auditor` after every implementer; TaskCompleted records per-task durations.
- **Background monitor** (`monitors/monitors.json`): during Phase 6, tails `git log` and reports each ticket commit as a notification.
- **Worktree isolation**: parallel `edm-implementer` agents each get their own git worktree automatically — no manual setup, no merge conflicts mid-wave.
- **State persistence**: `bin/edm-state` tracks each initiative's phase, gate approvals, timing, cost, and test coverage in `SRD/{PREFIX}/.edm-state.json`. Survives across sessions.
- **Resume**: a teammate cloning the repo can pick up an in-progress initiative — the state is in git.
- **`userConfig`**: prompts for output paths, conventions, coverage targets, and framework overrides at install time.
- **Comprehensive testing**: `/edm:test` runs 10 specialist agents (planner, scaffold, 7 writers, coverage auditor) in parallel waves, producing `test-plan.md` and `test-coverage.md` with AC->test cross-reference. Stack-aware -- automatically marks layers N/A for backend-only or CLI projects.
- **Multi-stack testing** (v2.0+): for initiatives spanning multiple technology stacks (e.g., a Python backend epic and a Vue frontend epic), the test planner detects the stack per epic and produces `test-plan-{epic}.md` / `test-coverage-{epic}.md` per epic, each scoped to that epic's frameworks and coverage targets. Single-stack initiatives use the same `test-plan.md` / `test-coverage.md` behavior as before.
- **Product-line linkage** (v2.0+): link related initiatives with `edm-state set-parent <PREFIX> <PARENT>` and `edm-state add-related <PREFIX> <RELATED>`. Linkage fields appear in HANDOFF.md so teams can navigate across child/sibling initiatives without losing context.

## See also

- `CLAUDE.md` — plugin conventions for contributors
- `CHANGELOG.md` — version history
- The Claude Code plugin docs: `code.claude.com/docs/en/plugins`
- The full remediation plan that produced this plugin: `../EDM_PLUGIN_REMEDIATION_PLAN.md`
