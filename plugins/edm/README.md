# EDM Plugin -- Enterprise Development Methodology

A Claude Code plugin that packages the Enterprise Development Methodology as user-invocable skills. EDM is a six-phase process for shipping complex software with high confidence, designed for AI-assisted parallel execution.

The plugin produces source-controlled artifacts in your project's `SRD/` directory -- every planning doc, SRD, ticket pack, and audit report lives in git alongside your code.

## Install

```bash
# Local install (from the marketplace repo root):
claude plugin install ./plugins/edm

# Or development mode (no install required):
claude --plugin-dir ./plugins/edm
```

When installed, Claude Code prompts for a few `userConfig` values (defaults are sensible -- accept them unless your team uses different paths).

## Requirements

- macOS or Linux only. Windows and WSL are unsupported.
- bash 3.2 or newer
- `jq` required
- `git` required

## Documentation

A slide presentation and a full user guide live outside the plugin's shipped source tree, at
the repository root (EDMV3-T57 -- distribution hygiene; these binaries are not needed by the
plugin at runtime):

- [`docs/EDM_Plugin_Presentation.pptx`](../../docs/EDM_Plugin_Presentation.pptx)
- [`docs/EDM_Plugin_User_Guide.docx`](../../docs/EDM_Plugin_User_Guide.docx)

## Required setup: permission `ask` rules

**Required setup.** Add the block below to your project's `.claude/settings.json` (or
`.claude/settings.local.json`) before running any EDM initiative. It forces Claude Code to
stop and require your explicit human approval before it can approve a HITL gate or archive
an initiative -- the strongest available defense-in-depth layer against a transcript-only
"approval" (see `plugins/edm/CLAUDE.md` for the enforcement-tier rationale).

```json
{
  "permissions": {
    "ask": [
      "Bash(edm-state approve-gate*)",
      "Bash(edm-state archive*)"
    ]
  }
}
```

For broader coverage against the bypass shapes documented below, also add these two
absolute-path/wildcard variants (alongside the two entries above) -- Claude Code 2.1.x (the
version this note was verified against) honours both; each is still a literal prefix match,
it just matches a different prefix:

```json
"Bash(*/bin/edm-state approve-gate*)",
"Bash(*/bin/edm-state archive*)"
```

**Matcher limitation (prefix match).** Claude Code's Bash permission matching is a literal
prefix match against the exact command string the tool executes -- it is not a shell-aware
parse of the command. The following invocation shapes all run the same underlying command
but miss the bare-prefix rule above entirely:

- `cd "$INIT_DIR" && edm-state approve-gate PREFIX 1` -- a compound command; the rule only
  matches a command string that *starts with* `edm-state approve-gate`, and this one starts
  with `cd`.
- `"$CLAUDE_PLUGIN_ROOT"/bin/edm-state approve-gate PREFIX 1` -- the absolute-path
  invocation form; caught only by the wildcard/absolute-path variants above, not the bare
  rule.
- an env-prefixed form, e.g. `EDM_SRD_ROOT=./SRD edm-state approve-gate PREFIX 1`.
- `bash -c 'edm-state approve-gate PREFIX 1'` -- the rule matches against the literal string
  `bash -c '...'`, never against the command hidden inside the quotes.

None of these are hypothetical: an agent working under time pressure, or from a different
working directory, will reliably produce at least one of them. Treat the `ask` rule as a
best-effort net, not a guarantee -- `edm-state validate` and `edm-state session-start`
report a `PERM_RULES_MISSING` anomaly (informational, never fails validation) when neither
scanned settings file has both patterns configured, and every gate approval records an
`enforcement` tag (`permission-ask` or `prose-only`) in `.edm-state.json` so the actual
coverage is auditable after the fact instead of assumed.

**Observed behaviour (manual QA, wave A)** -- the observed behaviour for each of the three
invocation shapes below is recorded here. Recorded 2026-07-26 against Claude Code
2.1.220 (`claude --version`). This wave-A pass is a documented-behaviour derivation, not a
live interactive dialog capture: EDM's Phase 6 implementation runs headlessly with no human
present to click an approval prompt, so forcing a live `ask` trigger in that context would
either silently auto-resolve or block the run indefinitely -- neither is a genuine
observation. The three outcomes below follow directly from Claude Code's published Bash
permission-matching behaviour (a literal prefix match against the exact command string, not
a shell-aware parse, per the limitation note above) and should be reconfirmed by a human
teammate running an interactive session before this note is treated as a substitute for
that confirmation:

| Invocation (rules configured per the minimal block above) | Prompt expected? |
|---|---|
| `edm-state approve-gate PREFIX 1` (bare prefix) | Yes -- the command string starts with `edm-state approve-gate`, matching the rule literally. |
| `cd SRD/PREFIX && edm-state approve-gate PREFIX 1` (compound `cd ... &&`) | No -- the command string starts with `cd`, not `edm-state`; the rule never matches and the command runs unprompted. |
| `"$CLAUDE_PLUGIN_ROOT"/bin/edm-state approve-gate PREFIX 1` (absolute path) | No -- same reason; only the wildcard variant (`Bash(*/bin/edm-state approve-gate*)`) closes this shape. |

## Slash commands

All EDM phases are user-invocable as `/edm:<name>`:

| Command | Phase | Description |
|---|---|---|
| `/edm:orchestrator <description>` | All 6 | Full methodology end-to-end with all HITL gates |
| `/edm:plan <PREFIX> <description>` | 1 | Planning & Discovery -- scope, inventory, go/no-go decision |
| `/edm:srd <PREFIX>` | 2 | SRD Creation -- requirements document with `{PREFIX}-NN` IDs |
| `/edm:audit-srd <PREFIX>` | 3 | SRD Audit -- 7-category review, remediates all P0/P1 findings |
| `/edm:tickets <PREFIX>` | 4 | Ticket Pack -- `{PREFIX}-T{NN}` tickets with 6-12 testable AC each |
| `/edm:audit-tickets <PREFIX>` | 5 | Ticket Audit -- 8-dimension validation including SRD version alignment |
| `/edm:implement <PREFIX>` | 6 | Implementation -- parallel waves with auto-QC after each wave |
| `/edm:code-audit <PREFIX>` | Post-6 | 11-lens exhaustive audit + synthesizer-produced remediation plan |
| `/edm:verify-runtime <PREFIX>` | 6 closure | Mandatory Phase 6 closure -- drives every PARTIAL verdict to PASS or FAIL via runtime checks; then run `edm-state phase-complete <PREFIX> 6` |
| `/edm:metrics <PREFIX\|--all\|--calibrate> [--with-human-baseline]` | Reporting | Per-phase durations and raw Claude cost by default; gate review times; per-round audit cost; `--with-human-baseline` opts into an estimated human-cost comparison; calibration |
| `/edm:push-jira <PREFIX> [PROJECT_KEY]` | Optional | Sync ticket pack to Jira via Atlassian MCP (idempotent, label-tracked, dependency-linked) |
| `/edm:test <PREFIX>` | Post-6 | Comprehensive testing pipeline: plan -> scaffold -> write (unit/component/composable/integration/contract/E2E/a11y) -> run -> audit coverage |
| `/edm:test-plan <PREFIX>` | Post-6 | Preview test scope only: detect stack + map AC to layers, no test writing |
| `/edm:test-coverage <PREFIX>` | Post-6 | Re-audit coverage against existing tests, update `test-coverage.md` |

All phase skills set `disable-model-invocation: true` -- Claude won't auto-fire them on casual prompts. Use the slash commands explicitly.

## Agents

| Agent | Phase | Model |
|---|---|---|
| `edm-explorer` | 1 -- Planning | opus / max |
| `edm-architect` | 2 -- Architecture | opus / max |
| `edm-srd-writer` | 2 -- SRD content | opus / high |
| `edm-srd-auditor` | 3 -- SRD audit | opus / max (read-only) |
| `edm-ticket-writer` | 4 -- Tickets | opus / high |
| `edm-ticket-auditor` | 5 -- Ticket audit | opus / max (read-only) |
| `edm-implementer` | 6 -- Code | sonnet / high (worktree-isolated) |
| `edm-qc-auditor` | 6 -- QC | opus / max (read-only, auto-spawned) |
| `edm-audit-{logic,dead-code,edge-cases,test-quality,runtime,docs,consistency,security,spec,dry,wiring}` | Code audit | opus / max (read-only, parallel) |
| `edm-audit-synthesizer` | Code audit | opus / max |
| `edm-test-planner` | Testing | opus / high (yellow) -- stack detection, AC<->layer mapping |
| `edm-test-scaffold` | Testing | sonnet / high (blue) -- install missing test infra |
| `edm-test-unit` | Testing | sonnet / high (green) -- unit tests, mocked |
| `edm-test-component` | Testing | sonnet / high (green) -- UI component tests |
| `edm-test-composable` | Testing | sonnet / high (green) -- React hooks / Vue composables |
| `edm-test-integration` | Testing | sonnet / high (green) -- multi-module / real DB |
| `edm-test-contract` | Testing | sonnet / high (green) -- OpenAPI/GraphQL contract tests |
| `edm-test-e2e` | Testing | sonnet / high (green) -- Playwright/Cypress journeys |
| `edm-test-a11y` | Testing | sonnet / high (green) -- axe-core + keyboard nav |
| `edm-test-coverage-auditor` | Testing | opus / max (cyan, read-only) -- coverage gaps + AC cross-ref |

## When to Use EDM

| Scenario | Use EDM? |
|---|---|
| New feature touching 10+ files | Yes -- full six phases |
| Large refactor or migration | Yes |
| New service or module | Yes |
| Bug fix (1-3 files) | No -- just fix it |
| Config/dependency update | No -- just do it |
| Exploratory prototype | Partial -- phases 1-2 only |

## The Six Phases

```
Phase 1      HITL     Phase 2      Phase 3      HITL     Phase 4       Phase 5      HITL     Phase 6
Planning --> GATE --> SRD     -->  Audit   --> GATE --> Tickets --> Audit    --> GATE --> Implementation
             #1      Creation     (SRD)        #2      Creation    (Tickets)    #3       + QC + Remediation
```

Three HITL gates require explicit human sign-off. The plugin enforces them via the `UserPromptExpansion` hook -- the SRD, audit, ticket, and implement phase commands (`/edm:srd`, `/edm:audit-srd`, `/edm:tickets`, `/edm:audit-tickets`, `/edm:implement`) will refuse to expand if the prerequisite gate isn't approved.

## Project artifact layout

Every artifact lives in your project's `SRD/` directory and is committed to git:

```
SRD/
|-- {PRODUCT}/                         <- v2.0 canonical: product subdirectory (e.g. "auth", "billing")
|   `-- {PREFIX}__{description}/       <- initiative directory (double-underscore separator)
|       |-- planning.md                    <- Phase 1
|       |-- srd.md                         <- Phase 2 (filename configurable)
|       |-- audit-srd.md                   <- Phase 3
|       |-- tickets/                       <- Phase 4 (dirname configurable)
|       |   |-- README.md                  <- index, legend, critical path, coverage map, version-linkage header
|       |   |-- audit.md                   <- Phase 5 audit
|       |   `-- epics/
|       |       |-- 01-{epic}.md
|       |       `-- 02-{epic}.md
|       |-- code-audit/
|       |   |-- findings-ledger.md           <- cross-round findings ledger (stable CA-NNN IDs)
|       |   `-- pass-{N}_{YYYY-MM-DD}/
|       |       |-- lens-L1.md ... lens-L11.md
|       |       |-- lenses-run.txt
|       |       `-- REMEDIATION.md
|       `-- .edm-state.json               <- gate approvals, phase timestamps, mode fields (committed by default)
`-- {PREFIX}/                          <- legacy flat layout (still supported, auto-detected)
    `-- ...
```

See `CLAUDE.md` for the full v2.0 artifact inventory including optional on-demand files (`decisions.md`, `ROLLBACK.md`, `exec-report.md`, `post-deploy/`).

Artifacts are reviewed in PRs. Gate approvals show up in git history. Multiple developers see the same in-flight initiative state.

## Phase Timing Guidelines

This table is an estimate pending calibration -- judgment-based, not yet regenerated from measured
Phase 6 data (EDMV3-T50/T51 now instrument that data; run `/edm:metrics --calibrate` once a few
initiatives complete to regenerate it from real numbers).

| Initiative Size | Total Estimate |
|---|---|
| Small (10-20 tickets) | 1-2 days |
| Medium (30-50 tickets) | 3-5 days |
| Large (50-85 tickets) | 5-10 days |

Run `/edm:metrics --calibrate` after a few completed initiatives to recalibrate these from your team's actual data.

## Plugin features

- **Hooks** (`hooks/hooks.json`): SessionStart prints in-progress initiatives; UserPromptExpansion enforces gate approval; PreToolUse blocks `git commit` on artifact violations; Stop/PreCompact checkpoint state; SubagentStop auto-fires `edm-qc-auditor` after every implementer; TaskCompleted is reserved (per-task accumulation not yet implemented).
- **Background monitor** (`monitors/monitors.json`): during Phase 6, tails `git log` and reports each ticket commit as a notification.
- **Worktree isolation**: parallel `edm-implementer` agents each get their own git worktree automatically -- no manual setup, no merge conflicts mid-wave.
- **State persistence**: `bin/edm-state` tracks each initiative's phase, gate approvals, timing, cost, and test coverage in `SRD/{PREFIX}/.edm-state.json`. Survives across sessions.
- **Resume**: a teammate cloning the repo can pick up an in-progress initiative -- the state is in git.
- **`userConfig`**: prompts for output paths, conventions, coverage targets, and framework overrides at install time.
- **Comprehensive testing**: `/edm:test` runs 10 specialist agents (planner, scaffold, 7 writers, coverage auditor) in parallel waves, producing `test-plan.md` and `test-coverage.md` with AC->test cross-reference. Stack-aware -- automatically marks layers N/A for backend-only or CLI projects.
- **Multi-stack testing** (v2.0+): for initiatives spanning multiple technology stacks (e.g., a Python backend epic and a Vue frontend epic), the test planner detects the stack per epic and produces `test-plan-{epic}.md` / `test-coverage-{epic}.md` per epic, each scoped to that epic's frameworks and coverage targets. Single-stack initiatives use the same `test-plan.md` / `test-coverage.md` behavior as before.
- **Product-line linkage** (v2.0+): link related initiatives with `edm-state set-parent <PREFIX> <PARENT>` and `edm-state add-related <PREFIX> <RELATED>`. Linkage fields appear in HANDOFF.md so teams can navigate across child/sibling initiatives without losing context.

## See also

- `CLAUDE.md` -- plugin conventions for contributors
- `CHANGELOG.md` -- version history
- The Claude Code plugin docs: `code.claude.com/docs/en/plugins`
