# EDM Plugin -- Conventions for Contributors

This file documents the architectural rules, naming conventions, and configuration model for the EDM Claude Code plugin.
Read this before making changes -- it captures decisions that aren't otherwise visible in the code.

## Architectural rules (do not violate)

### 1. `skills/` is the only entry point -- there is no `commands/`

Per the Claude Code plugin docs, `commands/` is the legacy location for skills-as-flat-files. New plugins use `skills/`.
Both invoke the same way (`/edm:name`), so maintaining both is pure duplication. **Do not re-introduce a `commands/`
directory.**

### 2. Skills are the source of truth for orchestration

Each phase skill (`skills/orchestrator/SKILL.md`, `skills/plan/SKILL.md`, etc.) contains:

- Methodology context (what is EDM, when to use it)
- Step-by-step operational orchestration
- The HITL gate prompts

Agents are invoked from skills, not the other way around.

**Skill-tool composition** (EDMV3-T34; spike recorded as decision D21 in
`SRD/edm/EDMV3__prompt-streamline/decisions.md` and `spike-skill-composition.md`): skills DO load
other skills, via the `Skill` tool. This marketplace's own **git plugin is the in-repository
precedent** -- `skills/commit/SKILL.md` invokes the `jira` plugin's `search-jira` skill exactly
this way today. The orchestrator dispatches; each phase skill owns its phase's complete procedure
exactly once, never duplicated in the orchestrator. Two obligations fall on any caller:

1. **`Skill` must appear in the caller's `allowed-tools`.** The callee's own `allowed-tools`
   governs what the callee itself may do while it runs -- grants are not inherited from, or
   intersected with, the caller's (confirmed live in the D21 spike: a `Bash`-less caller's callee
   ran `Bash` successfully because the callee's own frontmatter granted it).
2. **The caller must handle a target-skill-not-enabled failure gracefully.** An unavailable
   target fails the Skill-tool call with a `tool_use_error: Unknown skill: <name>` -- a clean,
   nameable error, not a silent no-op or a hang (confirmed live in the D21 spike). The caller must
   report the unavailable skill by name and stop; it must never fall back to silently inlining the
   target's procedure.

Context accumulated by the caller (its own reasoning, anything it has read or written this turn)
is visible to the callee automatically -- the callee runs within the **same conversation**, not an
isolated sub-agent context the way a `Task`-spawned agent (`edm-explorer`, `edm-implementer`,
etc.) does.

#### Intent-to-file index

Some behaviors are described in more than one file with no indication which is authoritative
(explorer 02 C3.3). When in doubt about **which file is authoritative**, this table wins:

| I want to change... | Edit this file (authoritative) |
|---|---|
| What a phase does, step by step | `skills/{phase}/SKILL.md` |
| What the explorer agent explores and how it reports | `agents/edm-explorer.md` -- `skills/plan/SKILL.md`'s "AI Execution Pattern" only names when/how many to spawn |
| Gate approval behavior (STOP/WAIT, free-text rejection, options) | `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"` -- every other gate site references it by name, never restates it |
| Severity definitions (P0/P1/P2/NOTED) | `CLAUDE.md Sec."Severity vocabulary"` -- every other site references it by name |
| A `bin/edm-state` subcommand's behavior | `bin/edm-state` itself -- the `bin/` table below only indexes it |
| An audit lens's mandate | `agents/edm-audit-{lens}.md` -- `skills/code-audit/SKILL.md`'s lens table only summarizes |

### 3. Artifacts live in the project's `SRD/` directory and are committed to git

Every artifact EDM produces -- planning notes, SRDs, ticket packs, audit reports, code-audit remediation plans, *
*and `.edm-state.json`** -- is a project deliverable that lives in the repository's `SRD/` directory. Source control IS
the feature:

- A teammate reviews the SRD in a PR before any code is written
- Ticket pack changes show up in code review
- Audit findings are inspectable in commit history
- Multiple developers see the same in-flight initiative state

`${CLAUDE_PLUGIN_DATA}` is reserved for plugin-internal caches only (convention detection, prefix lookup tables). It
does NOT hold initiative artifacts or initiative state.

### 4. State is in the project, not the plugin

`SRD/{PRODUCT}/{PREFIX}__{DESCRIPTION}/.edm-state.json` (or `SRD/{PREFIX}/.edm-state.json` for legacy flat initiatives)
is committed by default. Teams that want per-developer state can add it to `.gitignore` (controlled by the
`commit_state_file` user-config option).

## Project artifact layout

The **canonical layout** (v2.0+) places each initiative inside a product subdirectory:

```
SRD/                              <- project root, committed to git
+-- {PRODUCT}/                    <- one directory per product area (e.g. "edm", "auth", "billing")
    +-- {PREFIX}__{DESCRIPTION}/  <- initiative directory (double-underscore separator)
        |
        +-- planning.md               <- Phase 1 (Must/always-present)
        +-- srd.md                    <- Phase 2 output (filename configurable) (Must/always-present)
        +-- architecture.md           <- Phase 2: edm-architect diagrams and decisions (Must/always-present)
        +-- explorers/                <- Phase 1: parallel explorer findings, one file per focus area (Must/always-present)
        |   +-- 01-{slug}.md, 02-{slug}.md, ...
        +-- decisions.md              <- running key-decisions and finding-to-commit ledger (Must/always-present)
        +-- audit-srd.md              <- Phase 3 audit findings
        +-- tickets/                  <- Phase 4 (dirname configurable)
        |   +-- README.md             <- index, legend, critical path, coverage map, version-linkage header
        |   +-- audit.md              <- Phase 5 ticket-pack audit
        |   +-- epics/
        |       +-- 01-{epic}.md
        |       +-- 02-{epic}.md
        +-- test-plan.md              <- /edm:test (stack + AC coverage map)
        +-- test-coverage.md          <- /edm:test (coverage by layer + AC<->test cross-ref)
        +-- qc/                       <- Phase 6 QC reports (always-present after first wave)
        |   +-- qc-summary.md         <- merged QC verdict table (single auditor or merged shards)
        |   +-- qc-shard-{NN}.md      <- per-shard reports when ticket count > qc_shard_threshold
        +-- code-audit/               <- /edm:code-audit output
        |   +-- findings-ledger.md    <- persistent cross-round findings ledger (stable CA-NNN IDs)
        |   +-- pass-{N}_{YYYY-MM-DD}/ <- one directory per audit round (N = monotonic counter)
        |       +-- lens-L1.md ... lens-L11.md
        |       +-- lenses-run.txt    <- lens set for this round (full vs. partial)
        |       +-- REMEDIATION.md
        +-- ROLLBACK.md               <- rollback runbook (Should/on-demand; structure: trigger, revert steps, verify, owner)
        +-- exec-report.md            <- post-Phase-6 execution report with mode field (Should/on-demand)
        |   (per-epic variant: epicN-execution-report.md)
        +-- post-deploy/              <- post-deploy verification + analysis-input docs (Could/on-demand)
        |   +-- verification.md       <- smoke-test / deploy verification report
        |   +-- analysis/             <- rate-limit-analysis.md, source-triage.md, cost-analysis.md
        +-- HANDOFF.md                <- auto-generated cross-user resume doc (updated at every phase/gate/stop)
        +-- .edm-state.json           <- gate approvals, phase timestamps, mode fields (committed by default)
```

**Slot annotations**:
- `always-present` -- scaffolded by `edm-init` or written early in the phase flow
- `on-demand` -- created by its owning phase/agent only when the initiative needs it
- `Must/Should/Could` -- priority per SRD EDMV2-38..43

**Canonical artifact homes** (all paths derived from state via `initiative_dir_for()`, never hardcoded):
- `architecture.md` -- canonical home for `edm-architect` diagrams and architecture decisions (EDMV2-38)
- `explorers/` -- canonical home for parallel explorer reports; synthesized into `planning.md` (EDMV2-39)
- `decisions.md` -- initiative-wide key-decisions + finding-to-commit ledger; distinct from `code-audit/findings-ledger.md` which is the code-audit cross-round ledger (EDMV2-40)
- `ROLLBACK.md` -- on-demand rollback runbook; template: trigger conditions, ordered revert steps, verification-after-rollback, owner/contact (EDMV2-41)
- `exec-report.md` -- post-Phase-6 execution report; `mode` field = run mode (e.g., `live-db`, not the adaptation profile) (EDMV2-42)
- `post-deploy/` -- post-deploy verification and analysis-input documents (EDMV2-43)

**Concrete example**: `SRD/edm/EDMV2__enhance-edm-plugin/`

- The **double-underscore** (`__`) separates the PREFIX from the description slug -- never use a single underscore.
- The description slug is lowercase-hyphenated (e.g. `enhance-edm-plugin`, `user-auth-rewrite`).
- PREFIX is **globally unique** across ALL product subdirectories -- two products may not share a PREFIX (see Naming conventions below).

**Existing flat initiatives (`SRD/{PREFIX}/`) continue to work unchanged** (EDMV2-90 backward compat). The resolver
(`state_file_for` in `bin/edm-state`) detects the layout automatically and prefers an existing on-disk path so
in-flight initiatives are never relocated without explicit `edm-state migrate-path` invocation.

Migration from flat to product-scoped is **opt-in** per initiative:

```bash
edm-state migrate-path --product edm --description enhance-edm-plugin EDMV2
```

This uses `git mv` when the initiative is git-tracked, then updates `product_name` and `initiative_description` in state.

The plugin reads root paths from `userConfig`, so teams can relocate the entire tree:

- `${user_config.srd_root}` (default `./SRD`)
- `${user_config.srd_filename}` (default `srd.md`)
- `${user_config.ticket_pack_dirname}` (default `tickets`)

### Existing repository conventions (informational)

The project may contain an `/SRD/` directory with initiatives that pre-date the plugin and use older patterns. The
plugin does NOT migrate these -- they keep their current format. New initiatives created via the plugin use the
product-scoped canonical layout above (or flat layout when `--product`/`--description` are omitted).

## Naming conventions

### Initiative prefix

3-6 uppercase characters, e.g., `AUTH`, `MIGR`, `TIPS`, `PERF`. Validated by `bin/edm-validate-prefix` for
**global uniqueness** across ALL product subdirectories in `SRD/` (not just one product). This ensures the PREFIX
is unambiguous in commit scopes, ticket IDs, HANDOFF references, and Jira scopes -- two products sharing a PREFIX
would make all of these ambiguous. Configurable hint: `${user_config.prefix_format_hint}`.

### Requirement IDs (in SRDs)

`{PREFIX}-{NN}` -- e.g., `AUTH-01`, `AUTH-02`, ..., `AUTH-37`.

### Ticket IDs (in ticket packs)

`{PREFIX}-T{NN}` -- e.g., `AUTH-T01`, `AUTH-T02`, ..., `AUTH-T48`.

The `T` prefix distinguishes tickets from SRD requirements and prevents global collision across initiatives. **Never use
the legacy `TICK-NN` format**; the plan ID disambiguates initiatives in cross-initiative coverage maps.

### Version-linkage in ticket packs

Every ticket pack `README.md` body's first line MUST be:

```
Generated From: ${user_config.srd_filename} v{srd_version}
```

The `srd_version` is read from `.edm-state.json`. The `edm-ticket-auditor` (Dimension 8 -- Version Alignment) verifies
this against the current SRD version and flags drift as a P0 finding.

## Agent color scheme (semantic)

| Color     | Agent(s)                                              | Meaning                                 |
|-----------|-------------------------------------------------------|-----------------------------------------|
| `yellow`  | `edm-explorer`                                        | Phase 1 -- discovery                     |
| `blue`    | `edm-architect`, `edm-srd-writer`                     | Phase 2 -- writing                       |
| `orange`  | `edm-srd-auditor`, `edm-ticket-auditor`               | Phase 3 & 5 -- pre-implementation audits |
| `magenta` | `edm-ticket-writer`                                   | Phase 4 -- writing tickets               |
| `green`   | `edm-implementer`                                     | Phase 6 -- building                      |
| `red`     | `edm-qc-auditor`                                      | Phase 6 QC -- final gate                 |
| `cyan`    | all 11 `edm-audit-*` lenses + `edm-audit-synthesizer` | Code audit (one logical operation)      |

When adding a new agent, choose a color that matches the phase. Lens agents always share `cyan`.

## Severity vocabulary (canonical)

All EDM audit agents use the following four-level scale. No agent may define a divergent local scale.

| Level | Meaning | Required action |
|---|---|---|
| **P0** | Critical -- blocks implementation, security/legal issue, production failure, or architecturally wrong | Fix before this phase may be called complete |
| **P1** | Significant -- material gap, factual error, missing requirement, or behavior that must be corrected before shipping | Remediated before the phase or round may be called complete |
| **P2** | Minor -- polish, edge-case, improvement, or nice-to-have | Remediated before convergence |
| **NOTED** | Not actionable -- the issue is intentional, pre-existing, or a known accepted trade-off | Document in "Decisions / Non-Findings"; do not re-investigate |

`NOTED` is not actionable and is distinct from deferral -- a deferral is an actionable finding
postponed to later, and deferral does not exist in this methodology. Every P0, P1 and P2 finding
is remediated before convergence; `NOTED` is the only status that closes a finding without a fix.

**Backward-compatibility mapping** (from the synthesizer's legacy P1/P2/P3 scale used before v2.0):
- Legacy P1 (production failure / security) -> **P0**
- Legacy P2 (operational friction / must-fix) -> **P1**
- Legacy P3 (defensive improvement / nice-to-have) -> **P2**
- NOTED -> unchanged

## Mermaid diagram conventions (canonical)

All EDM agents that author or audit Mermaid diagrams follow these conventions. No agent may define a divergent local rule.

Mermaid's `;` is a lexer-level statement separator, and this is reserved even where the `;` appears inside label text -- the parser does not distinguish "inside a label" from "between statements," so a literal semicolon inside a node, edge or message label breaks the diagram.

**The rule:** a literal semicolon in Mermaid label, node, edge or message text is written as the entity code `#59;` -- `#` followed by either a base-10 code point or an entity name, then `;`, with no leading ampersand. `&#59;` is not this project's convention; `#59;` is correct.

Before (raw semicolon inside a label -- breaks the diagram):

<!-- edm-lint-ignore-start -->
```mermaid
flowchart TD
    A[Wait; then retry] --> B[Done]
```
<!-- edm-lint-ignore-end -->

After (entity code, no leading ampersand -- renders correctly):

```mermaid
flowchart TD
    A[Wait#59; then retry] --> B[Done]
```

Quoting label text is not a reliable substitute for the entity code across every diagram type. A `sequenceDiagram` message's text after the `:` is unquoted, so it is especially exposed to this failure -- there is no quote to protect it there.

The following remain legal and are **not** violations of this rule:
- A statement-terminating `;` at the end of a line, outside any label.
- `;` on a `%%` comment line.
- `;` terminating a `classDef`, `style`, or `linkStyle` directive.

Other entity codes follow the same form, so the rule generalizes: `#quot;` (double quote), `#35;` (`#`), and so on.

This section's heading string, `## Mermaid diagram conventions (canonical)`, is referenced by name from the eleven touch points inventoried in `architecture.md` and asserted by a smoke test -- do not rename it without updating every reference.
## Unverifiable acceptance criteria (D15)

An unverifiable acceptance criterion -- one whose stated runtime environment does not exist in
the project (no staging deploy, no live database, no browser harness) -- is a specification
defect, not a fourth verdict. `/edm:verify-runtime` (EDMV3-T33) records exactly two closing
verdicts, PASS or FAIL, for every entry in `partial_verdict_map`; there is no `BLOCKED`,
`WAIVED`, or `N/A-runtime` value anywhere in this methodology.

When an AC's runtime environment genuinely does not exist, there are exactly two sanctioned
responses:

1. **Rework the AC** into something verifiable in the environment that does exist -- the usual
   outcome. Most "PARTIAL forever" ACs are testable with a narrower, still-meaningful claim.
2. **Move the unverifiable clause out of scope** as a recorded boundary for a follow-on
   initiative, using the D14 scope-boundary framing -- a decision made on its own merits, not a
   postponed finding.

Both routes are a scope change to an approved ticket, so both go through gate change control:
presented at the relevant gate with the rationale, approved or rejected by the human via the
canonical `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"`, and recorded in `decisions.md` and
the ticket's audit trail. **The implementer cannot descope an AC by declaring it unverifiable** --
only a human, at a gate, can accept route (1) or (2). Archive stays hard-blocked until every AC in
`partial_verdict_map` carries a `closing_verdict` of PASS or FAIL.

## Model and effort assignments

| Role | Model | Effort | Rationale |
|---|---|---|---|
| Planning, audit, QC | `opus` | `max` | Judgment-heavy work -- surface subtle issues |
| Writing (SRD, tickets) | `opus` | `high` | High-stakes artifacts the rest of the methodology depends on; opus catches missed requirements and weak ACs that sonnet sometimes misses |
| Implementation | `sonnet` | `high` | Throughput work -- well-specified by tickets |
| Code audit lenses + synthesizer | `opus` | `max` | Each lens hunts for subtle, lens-specific issues |
| Jira sync (optional) | `sonnet` | `high` | Mechanical mapping -- ticket pack already exists; this just translates fields |

Skills mirror the split: `skills/orchestrator/`, `skills/plan/`, `skills/srd/`, `skills/audit-srd/`, `skills/tickets/`, `skills/audit-tickets/`, `skills/implement/`, `skills/code-audit/` are all on `opus`. The two writers run at `effort: high`; planning, audits, and QC run at `effort: max`. `skills/push-jira/` and `skills/metrics/` run on `sonnet`/`high`.

## Cost tracking

Every `phase-complete` invocation captures token usage from the project's session JSONL files (
`~/.claude/projects/<encoded-cwd>/*.jsonl`) and computes Claude API cost using current Anthropic pricing. The state
schema's `phase_durations[N_phase]` entry includes:

- `tokens.{input, output, cache_read, cache_write}` -- raw counts
- `model_used` -- the model that handled most of the phase work (last assistant message)
- `estimated_cost_usd` -- computed from tokens x per-million-token rates
- `human_baseline_usd` -- computed from Phase Timing Guidelines median hours x `${user_config.human_hourly_rate_usd}` (
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
| `test-plan.md` | `edm-test-planner` | Stack detection, AC<->layer mapping, writer task assignments |
| `test-coverage.md` | `edm-test-coverage-auditor` | Coverage by layer vs. targets, AC<->test cross-reference, P0/P1/P2 gaps |

Test code itself lives in the project's existing test directories -- `SRD/` artifacts document
*intent and coverage*, not the tests themselves.

### Testing layer agent inventory

| Agent | Model/Effort | Color | maxTurns | Role |
|-------|-------------|-------|---------|------|
| `edm-test-planner` | opus / high | yellow | 30 | Detect stack; map tickets -> test layers; write `test-plan.md` |
| `edm-test-scaffold` | sonnet / high | blue | 30 | Install missing test deps, write config files |
| `edm-test-unit` | sonnet / high | green | 50 | Pure-function unit tests, mock-isolated |
| `edm-test-component` | sonnet / high | green | 50 | UI component tests (RTL, Vue Test Utils, etc.) |
| `edm-test-composable` | sonnet / high | green | 50 | React hooks / Vue composables |
| `edm-test-integration` | sonnet / high | green | 50 | Multi-module / real DB / HTTP tests |
| `edm-test-contract` | sonnet / high | green | 50 | API contract tests (OpenAPI/GraphQL-driven) |
| `edm-test-e2e` | sonnet / high | green | 60 | Playwright/Cypress full user journeys |
| `edm-test-a11y` | sonnet / high | green | 30 | axe-core + keyboard nav, WCAG 2.1 AA |
| `edm-test-coverage-auditor` | sonnet / high | cyan | 25 | Read-only: parse coverage, cross-ref AC, find gaps |

`edm-test-coverage-auditor` is `cyan` (read-only audit lens, like the code-audit lenses). Test
writers are `green` (build code, like `edm-implementer`). Planner is `yellow` (discovery, like
`edm-explorer`). Scaffold is `blue` (writes infrastructure, like `edm-architect`).

`edm-test-coverage-auditor` has `disallowedTools: Edit, NotebookEdit` (Write is required -- it writes `test-coverage.md`).

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

`.edm-state.json` gains these top-level fields (added by `edm-state init`, defaults shown):

```json
{
  "test_frameworks_detected": { "unit": "pytest", "component": null, "e2e": "playwright" },
  "coverage_by_layer": {
    "unit": { "pct": 82.4, "measured_at": "2026-05-01T..." },
    "integration": { "pct": 65.1, "measured_at": "2026-05-01T..." }
  },
  "coverage_by_epic": {
    "auth": {
      "unit": { "pct": 84.1, "measured_at": "2026-05-01T..." }
    },
    "dashboard": {
      "unit": { "pct": 75.0, "measured_at": "2026-05-01T..." }
    }
  },
  "parent_prefix": "",
  "related_prefixes": []
}
```

`test_frameworks_detected` is keyed by epic slug for multi-stack initiatives (e.g.,
`{"auth":{"unit":"pytest"},"dashboard":{"unit":"vitest","component":"@testing-library/vue"}}`),
or flat for single-stack initiatives.

`coverage_by_layer` holds whole-initiative coverage for single-stack initiatives.
`coverage_by_epic` holds per-epic coverage for multi-stack initiatives (additive; keyed by epic slug).

`parent_prefix` is the bare PREFIX of the parent initiative in a product line (set via
`edm-state set-parent <PREFIX> <PARENT>`; validated to exist).

`related_prefixes` is an append-only list of related initiative prefixes (set via
`edm-state add-related <PREFIX> <RELATED>`; idempotent).

`phase_durations[N_phase]` gains `tests_added` (total) and `tests_by_layer` (per layer) counts
when `edm-state record-tests-added` is called.

### New bin/edm-state subcommands

| Subcommand | Usage |
|-----------|-------|
| `record-test-coverage <PREFIX> <layer> <pct> [<epic>]` | Record coverage % for one layer (with epic = per-epic, without = whole-initiative) |
| `record-tests-added <PREFIX> <phase> <layer> <count>` | Increment test count for phase+layer |
| `get-coverage <PREFIX>` | Print coverage summary (whole-initiative and per-epic) |
| `set-parent <PREFIX> <PARENT>` | Set parent_prefix (validates PARENT exists) |
| `add-related <PREFIX> <RELATED>` | Append to related_prefixes (idempotent) |

`metrics-report <PREFIX>` now includes a test coverage table below the cost/time table if
coverage data has been recorded -- both whole-initiative and per-epic when available.

### When to invoke /edm:test

Run it after all Phase 6 implementation waves complete and before declaring the initiative done.
For `--fill-gaps` mode (fill ALL gaps -- P0, P1, and P2 -- in an existing coverage report), pass the flag:
`/edm:test {PREFIX} --fill-gaps`.

### Layers that are N/A and per-epic test plans

Each test-writer agent self-identifies when its layer doesn't apply and exits cleanly:
- `component`, `composable`, `a11y`, `e2e` are N/A for backend-only or CLI-only epics.
- `contract` is N/A for epics without an API schema.
- `composable` is N/A for epics without React hooks or Vue composables.

N/A designations are recomputed each run -- never inherited from a previous plan. When a layer
is N/A, no placeholder file or coverage row is written (absence is authoritative).

**Per-epic test plan filename convention** (multi-stack initiatives):
- `test-plan-{epic-slug}.md` -- per-epic plan file (e.g., `test-plan-auth.md`, `test-plan-dashboard.md`)
- `test-plan.md` -- top-level index listing each epic, its stack, and a link to its per-epic plan

**Per-epic coverage filename convention** (multi-stack initiatives):
- `test-coverage-{epic-slug}.md` -- per-epic coverage report
- `test-coverage.md` -- top-level summary with cross-epic coverage table

The epic slug is derived from the epic ticket-pack filename: `epics/NN-{slug}.md` -> `{slug}`.

When all epics share the same stack (single-stack initiative), the planner produces only
`test-plan.md` and the coverage auditor produces only `test-coverage.md` -- v1.x behavior is preserved.

## Optional: Jira synchronization

`skills/push-jira/SKILL.md` (invoked as `/edm:push-jira <PREFIX> [PROJECT_KEY]`) optionally pushes the ticket pack to Jira via the Atlassian MCP. It is **strictly opt-in**:

- The skill checks `mcp__{jira_mcp_namespace}__atlassianUserInfo` first (namespace defaults to `plugin_jira_atlassian-mcp-server`; override via `${user_config.jira_mcp_namespace}`); if unavailable, it skips with a friendly message.
- Tickets are tracked in Jira via labels (`edm-{prefix}-t{nn}`) -- no custom Jira fields required.
- Re-running is idempotent: existing issues are updated, not duplicated.
- Status, comments, and worklog on Jira issues are preserved across re-runs.
- Dependencies become Issue Links of type `Blocks` (or `Relates` if `Blocks` isn't available).
- Each ticket file gets a Jira link appended after first push: `## AUTH-T01: ...  ([MCP-1234](https://....atlassian.net/browse/MCP-1234))`.
- A summary of all sync actions is written to `${user_config.srd_root}/{PREFIX}/${user_config.ticket_pack_dirname}/jira-sync.md`.

The skill does NOT push during active implementation (Phase 6) -- let the markdown ticket pack stay authoritative. Re-sync after the initiative completes if desired.

The `userConfig.jira_project_key` value provides a default; otherwise the user must pass `<PROJECT_KEY>` as the second argument.

## Hooks behavior

`hooks/hooks.json` configures:

| Event                                                                                  | Effect                                                        |
|----------------------------------------------------------------------------------------|---------------------------------------------------------------|
| `SessionStart`                                                                         | Emit Resume Point for active initiatives via `edm-state session-start` |
| `UserPromptExpansion` matching `edm:(srd\|audit-srd\|tickets\|audit-tickets\|implement)` | Block expansion if the prerequisite HITL gate isn't approved  |
| `PreToolUse` matching `git commit`                                                     | Run `edm-lint-artifacts` -- block commit if active-initiative artifacts have violations |
| `Stop` and `PreCompact`                                                                | Checkpoint state via `edm-state checkpoint-if-active`         |
| `SubagentStop` matching `edm-implementer`                                              | Auto-spawn `edm-qc-auditor`; write verdict to `qc/qc-summary.md`; persist PARTIAL verdicts via `edm-state record-partial-verdict` |
| `TaskCompleted`                                                                        | Reserved -- per-task duration accumulation not yet implemented |

These are part of the methodology -- do not disable them in normal operation.

## Artifact content conventions

Every artifact this plugin produces or templates is **ASCII-only**: no em dashes, no arrows (use `->`), no smart
quotes, no emoji glyphs. `edm-lint-artifacts` class 2 enforces this at commit time over every tracked artifact tree.

**Imported third-party documents are ASCII-normalized on import** -- when an external document (a design review, a
vendor report, a pasted analysis) is copied into an initiative's directory, the person or agent performing the
import replaces non-ASCII characters (em dashes become `--`, arrows become `->`, smart quotes become straight quotes)
before it is committed, so the document's meaning is unchanged but its bytes pass the same lint the rest of the
initiative's artifacts pass. Wrapping an imported document in `edm-lint-ignore` markers instead of normalizing it is
not an acceptable substitute -- an exempted document in an initiative's own directory is a standing invitation to
exempt the next one.
## Required setup: permission `ask` rules (EDMV3-T06)

See `README.md`'s "Required setup: permission ask rules" section for the full rationale, the
matcher-limitation note, and the wave-A manual-QA record -- not re-explained here. The
required block, added to `.claude/settings.json` (or `.claude/settings.local.json`):

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

`check_permission_rules()` in `bin/edm-state` scans for these two patterns and feeds the
result into the `enforcement` field (`permission-ask` | `prose-only`) recorded on every gate
approval, and into the informational `PERM_RULES_MISSING` anomaly when absent.

## `bin/` helper scripts

Scripts in `bin/` are added to PATH while the plugin is enabled. Skills call them by bare name.

| Script                | Purpose                                                                                                                                                                                                                                     |
|-----------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `edm-state`           | Read/write `.edm-state.json` files; 37 subcommands: `init`, `get`, `set`, `list`, `active-initiatives`, `migrate-path`, `migrate-schema`, `approve-gate`, `phase-start`, `phase-complete`, `checkpoint-if-active`, `record-task-duration`, `record-test-coverage`, `record-tests-added`, `get-coverage`, `srd-version`, `archive`, `write-handoff`, `watch-impl`, `metrics-report`, `validate`, `gate-check`, `branch-check`, `git-lock-check`, `current-step`, `session-start`, `audit-round-start`, `record-partial-verdict`, `set-mode`, `skip-phase`, `set-supersedes`, `set-forked-from`, `resolve-dir`, `set-parent`, `add-related`, `update-patterns`, `lint` |
| `edm-init`            | Scaffold a new initiative directory (`SRD/{PREFIX}/` or `SRD/{PRODUCT}/{PREFIX}__{desc}/`) with empty state file |
| `edm-validate-prefix` | Verify a proposed prefix doesn't collide with existing initiatives across all product subdirectories |
| `edm-lint-artifacts`  | Scan `.md` artifact files for four violation classes -- attribution trailers, non-ASCII bytes, leaked tool-invocation tags, and a literal `;` inside Mermaid label/edge/message text; called by the `PreToolUse` git-commit hook |

### `.edm-state.json` mode-family fields

| Field | Type | Default | Purpose |
|---|---|---|---|
| `mode` | string enum | `standard` | Adaptation profile: `standard`, `mini-srd`, `iac`, `data-ml`, `prototype` |
| `lifecycle_mode` | string enum | `standard` | Lifecycle variant: `standard`, `partial`, `fast-track`, `fix-pack` |
| `compliance_enabled` | boolean | `false` | When true, adds Gate 3.5 compliance review and regulatory-traceability columns |
| `implementation_mode` | string enum | `standard` | Phase 6 mode: `standard` or `tdd` (Red-Green-Refactor per ticket) |
| `skipped_phases` | array of objects | `[]` | Intentionally skipped phases; each: `{phase: N, rationale: "..."}` |
| `supersedes` | string | `""` | Prefix of the initiative this supersedes (provenance link) |
| `forked_from` | string | `""` | Prefix of the initiative this forked from (provenance link) |

All fields default safely so v1.x state files without them work unchanged (C-4 backward compatibility).

**`mode` vs `lifecycle_mode`** -- orthogonal: an initiative can be `mode=iac` AND `lifecycle_mode=fast-track` simultaneously. Set independently via `edm-state set-mode <PREFIX> mode|lifecycle_mode <value>`.

### `.edm-state.json` `schema_version` contract (EDMV3-T09)

`schema_version` is an integer, written once by `cmd_init` for the wave the running plugin version
belongs to, and advanced only by `edm-state migrate-schema` -- never by `cmd_set` (making it
`cmd_set`-settable would reopen the hand-flip path the `SETTABLE_KEYS` allowlist exists to close).
Absent `schema_version` is the legacy pre-EDMV3 signal (grandfathered, C-4).

| Version | Wave | Shape it certifies | Minimum version required by |
|---|---|---|---|
| `1` | A | gates, mode-derived terminal phase, phase-6 `completed_at`, artifact checks, `cmd_set` allowlist | EDMV3-16, EDMV3-17, EDMV3-115 (`>= 1`) |
| `2` | B | JSONL findings ledger, PARTIAL closure representation, audit round-type recording, gate `enforcement` tags | EDMV3-18, EDMV3-36, EDMV3-42, EDMV3-120 (`>= 2`) |
| `3` | C | assigned only if a state shape actually changes in wave C; otherwise wave C leaves the value at `2` rather than bumping it for symmetry | none yet -- decided by EDMV3-T66 only if needed |

**Three-valued degradation.** A present-but-lower `schema_version` is a distinct state from both
"legacy/absent" (no enforcement at all) and "fully compliant" (every check applies normally): a
check whose required version is *above* the recorded `schema_version` degrades to warn-and-proceed
naming the check; a check *at or below* the recorded version applies normally. Each check that
consults `schema_version` records its own minimum in a `# requires schema_version >= N` comment at
the check in `bin/edm-state`. EDMV3-T09 defines this contract and lands the one such comment for
the check that exists as of wave A (EDMV3-115, `cmd_gate_check`); the degradation *behaviour*
itself is implemented per-check by the ticket that owns that check. EDMV3-T14 wires the shared
`schema_at_least()` helper into the wave-A checks (`cmd_phase_complete`, `cmd_archive`) and tests
the whole class end to end, including the real archived EDMV2 fixture; EDMV3-T18 (wave B) is where
the version-2 checks themselves are built.

**`decisions.md` vs `code-audit/findings-ledger.md`** -- distinct files with distinct scopes:
- `decisions.md` = initiative-wide key decisions and finding-to-commit ledger (written by orchestrator at gates and Phase 6)
- `code-audit/findings-ledger.md` = cross-round code audit findings ledger with stable CA-NNN IDs (written by `edm-audit-synthesizer`)

Operates against the project's working directory (no plugin-relative paths). All scripts must be POSIX-compatible bash (
`#!/bin/bash` or `#!/usr/bin/env bash`).

## `userConfig` reference

Prompted at install time. See `.claude-plugin/plugin.json` for the live schema. Keys:

- `srd_root` -- output root directory (default `./SRD`)
- `srd_filename` -- SRD file inside the initiative directory (default `srd.md`)
- `ticket_pack_dirname` -- ticket pack subdirectory name (default `tickets`)
- `prefix_format_hint` -- hint shown when prompting for a prefix (default `UPPERCASE 3-6 chars`)
- `commit_state_file` -- whether `.edm-state.json` is git-tracked (default `true`)
- `human_hourly_rate_usd` -- human developer rate for cost comparison in `/edm:metrics` (default `150`)
- `jira_project_key` -- default Jira project key for `/edm:push-jira`; leave empty to require explicit arg (default `""`)
- `jira_mcp_namespace` -- MCP namespace for Atlassian tools (default `plugin_jira_atlassian-mcp-server`)
- `coverage_target_unit_pct` -- minimum unit test coverage % (default `80`)
- `coverage_target_component_pct` -- minimum component test coverage % (default `70`)
- `coverage_target_integration_pct` -- minimum integration test coverage % (default `60`)
- `coverage_target_e2e_critical_paths_pct` -- % of critical paths requiring E2E coverage (default `100`)
- `test_framework_unit_override` -- pin unit test framework, e.g. `jest`, `pytest` (default `""`)
- `test_framework_component_override` -- pin component test framework (default `""`)
- `test_framework_e2e_override` -- pin E2E framework, e.g. `playwright`, `cypress` (default `""`)
- `mode` -- default initiative mode: `standard`, `mini-srd`, `iac`, `data-ml`, `prototype` (default `standard`)
- `compliance_enabled` -- enforce compliance checkpoints when true (default `false`)
- `qc_shard_threshold` -- ticket count above which QC spawns multiple `edm-qc-auditor` shards (default `20`)
- `implementation_mode` -- Phase 6 mode: `standard` or `tdd` Red-Green-Refactor (default `standard`)

Skills reference values as `${user_config.srd_root}` etc.

## Testing changes

macOS and Linux only (bash 3.2+, `jq`, `git` required). Windows and WSL are unsupported.

After modifying any plugin component:

1. `claude plugin validate plugins/edm/` -- schema and frontmatter check
2. Test in a sandbox: `claude --plugin-dir ./plugins/edm`
3. Run `/reload-plugins` to pick up changes without restarting
4. Verify agents appear in `/agents`, skills in `/help`
5. Run `bash plugins/edm/bin/tests/run-all.sh` locally before pushing -- this is the same
   command CI runs and is the fastest way to catch a regression before opening an MR.

### CI (EDMV3-T21)

A GitLab CI pipeline (`.gitlab-ci.yml`, repository root) runs automatically on every merge
request whose changes touch `plugins/edm/**`, and on every pipeline on the default branch
regardless of what changed (so the pipeline cannot go stale behind an unrelated merge). It has
four stages:

| Stage | Job | Blocking? | What it does |
|---|---|---|---|
| `lint` | `lint:shell-and-artifacts` | Yes | `bash -n` over every file in `bin/` (incl. `bin/tests/*.sh`), `edm-lint-artifacts --all`, `edm-check-grants` |
| `lint` | `lint:file-type-ban` | No (`allow_failure: true` until EDMV3-T57) | Scans tracked files under `plugins/` for banned types (`.pptx`, `.docx`, `.DS_Store`) |
| `lint` | `lint:shellcheck` (EDMV3-T61) | Yes | `shellcheck` over every file directly in `bin/`, scoped to the unquoted-expansion class of findings (SC2086/SC2046/SC2048/SC2068) -- pre-existing style findings outside that class are out of scope |
| `test` | `test:smoke` | Yes | `bash plugins/edm/bin/tests/run-all.sh` -- the single aggregator invocation; no suite is enumerated in the pipeline file, so a new `*-smoke.sh` suite runs in CI automatically (this is where `wave7-smoke.sh`'s help-completeness case, EDMV3-T61 AC2/AC13, runs) |
| `test` | `test:smoke-bash32` (EDMV3-T61) | Yes | The same `run-all.sh` aggregator run a second time under a pinned `bash:3.2` image, proving the bash-3.2 compatibility constraint (EDMV3-91/106) end-to-end rather than only asserting it by grep |
| `test` | `test:state-validate` | Yes | `edm-state validate` across every tracked, non-archived initiative; informational anomalies are reported, a blocking anomaly fails the job |
| `validate` | `validate:manifest` | Yes (tier 1) | Deterministic `jq`-only check: every skill/agent on disk is declared in `.claude-plugin/marketplace.json` and vice versa, every `SKILL.md`/agent frontmatter block parses, every declared tool name is well-formed |
| `validate` | `validate:plugin-cli` | No (`allow_failure: true`, tier 2) | `claude plugin validate plugins/edm/`, compared against the committed warning-count baseline in `.gitlab/edm-validate-baseline.txt`; skips cleanly if the `claude` CLI isn't in the runner image |
| `eval` | `eval:nightly` | No (`allow_failure: true`) | Runs the headless eval driver (`plugins/edm/evals/run-eval.sh`) against the `tiny-svc` fixture. `when: manual` on a normal pipeline; runs automatically on a scheduled nightly pipeline. Skipped outright (not failed) when `ANTHROPIC_API_KEY` is unset |

All job images are pinned by digest (`@sha256:...`) rather than a floating tag, with one
documented, explicitly authorized exception: `test:smoke-bash32`'s `bash:3.2` image (EDMV3-T61,
re-confirmed EDMV3 wave-A QC remediation) is not yet digest-pinned -- no registry-connected
environment was available to capture its digest while that ticket was implemented (the same
constraint that left the alpine/node digests as placeholder captures, per the header note at the
top of `.gitlab-ci.yml`). It MUST be pinned to a real `@sha256:...` digest, using the digest
refresh procedure documented at the top of `.gitlab-ci.yml`, before this job is first relied on
against a live GitLab runner fleet.

**macOS runner (EDMV3-T61 AC12, named exception taken):** CI does not currently exercise the
suites on a macOS runner in addition to Linux -- no macOS runner class is confirmed registered
against this project's GitLab runner fleet, and (unlike a Docker Hub image) a macOS runner is
real hardware that must already be provisioned and tagged, not something a pipeline-file edit can
create. The macOS/Linux divergence points this would have caught (`sed -i`, `grep -P` family,
`stat -c`/`stat -f`, and the `shasum`/`sha256sum` choice) are instead covered by targeted
assertions: `bin/tests/wave7-smoke.sh`'s "T61 AC11" case greps for every divergence point outside
its one documented detection branch, and `bin/tests/_harness.sh`'s `_harness_hash_file` already
branches on `shasum` vs `sha256sum` availability. Revisit adding a macOS runner once one is
confirmed available in this project's fleet.

## Related documentation

- `README.md` -- user-facing install + usage
- `CHANGELOG.md` -- version history
- The official Claude Code plugin docs: `code.claude.com/docs/en/plugins`, `code.claude.com/docs/en/plugins-reference`
- Existing initiatives at `/SRD/` -- informational reference for the legacy convention
