# Lens L11: Integration Wiring

Audit of the EDM Claude Code plugin v2.0.0 ("EDMV2") at `plugins/edm-ai-development/`.
Scope: executable/structural references that must resolve for the plugin to work end-to-end —
marketplace↔disk paths, skill/agent→`edm-state` subcommands, skill/agent→agent names,
→`userConfig` keys, hooks/monitors→commands, Jira MCP tool names, and stale `*-staging/` paths.
Docs-prose accuracy is explicitly out of scope (owned by L6).

All file:line references below are paths under `plugins/edm-ai-development/` unless noted.

## Findings

| ID | Sev | Reference (file:line) | Target | Resolves? |
|----|-----|-----------------------|--------|-----------|
| L11-01 | P2 | `plugin.json:73` (`mode` userConfig) | Should seed new-initiative `mode` default; nothing reads `${user_config.mode}` / `CLAUDE_PLUGIN_OPTION_MODE` | NO — dead config |
| L11-02 | P2 | `plugin.json:133` (`implementation_mode` userConfig) | Should seed Phase 6 `implementation_mode` default; nothing reads `${user_config.implementation_mode}` | NO — dead config |
| L11-03 | P2 | `plugin.json:79` (`compliance_enabled` userConfig) | Should seed `compliance_enabled` default; nothing reads `${user_config.compliance_enabled}` | NO — dead config |
| L11-04 | P3 | `bin/tests/wave3-smoke.sh:5` | `plugins/edm-ai-development-staging/bin/tests/wave3-smoke.sh` (staging dir does not exist) | NO — stale path in comment |
| L11-05 | P3 | `bin/tests/wave4a-smoke.sh:5` | `plugins/edm-ai-development-staging/bin/tests/wave4a-smoke.sh` (staging dir does not exist) | NO — stale path in comment |

No P0/P1 findings. Every runtime-critical reference (marketplace paths, skill→subcommand,
skill→agent, hooks→command, monitor→command, Jira MCP tool names) resolves correctly.

---

### L11-01 — `mode` userConfig is never consumed (dead config)

**The reference**: `plugin.json:73-78` defines the `mode` userConfig key:
> "Default initiative mode for new initiatives. One of: standard, mini-srd, iac, data-ml, prototype."

**The target it should resolve to**: Either a bin script reading `CLAUDE_PLUGIN_OPTION_MODE`, or a
skill referencing `${user_config.mode}`, so the install-time default flows into a new initiative's
`.edm-state.json`.

**Why it's broken**:
- `bin/edm-init` defaults `MODE="standard"` hardcoded (`edm-init:14`) and only accepts a `--mode` CLI
  flag — it never reads `CLAUDE_PLUGIN_OPTION_MODE` (the only `CLAUDE_PLUGIN_OPTION_*` vars read across
  all of `bin/` are `SRD_ROOT`, `SRD_FILENAME`, `TICKET_PACK_DIRNAME`, `HUMAN_HOURLY_RATE_USD`,
  `COMMIT_STATE_FILE`).
- `edm-state init` writes `mode: "standard"` hardcoded (`edm-state:473`).
- `skills/orchestrator/SKILL.md:130-145` obtains `mode` exclusively from an interactive
  `AskUserQuestion` prompt and persists it via `edm-state set-mode <PREFIX> mode <value>`.
- `grep -rEn '\$\{user_config\.mode\}' skills agents` returns nothing.

The configured default has no effect; new initiatives are always `standard` until the orchestrator
prompt overrides it.

**Fix**: Either (a) have `edm-init` read `MODE="${CLAUDE_PLUGIN_OPTION_MODE:-standard}"` and pass it
through to `edm-state init` (e.g., via `EDM_MODE` env), and have the orchestrator pre-select that mode
as the default `AskUserQuestion` option; or (b) if per-initiative interactive selection is the intended
sole mechanism, remove the `mode` key from `userConfig` (and its CLAUDE.md/CHANGELOG references) to
eliminate the dead config.

### L11-02 — `implementation_mode` userConfig is never consumed (dead config)

**The reference**: `plugin.json:133-138` defines `implementation_mode` ("standard" | "tdd"):
> "Controls the Phase 6 implementation strategy. 'standard' … (default). 'tdd' enforces Red-Green-Refactor…"

**The target it should resolve to**: A read of `${user_config.implementation_mode}` (or
`CLAUDE_PLUGIN_OPTION_IMPLEMENTATION_MODE`) that seeds the Phase 6 mode.

**Why it's broken**:
- `edm-state init` hardcodes `implementation_mode: "standard"` (`edm-state:476`).
- `skills/orchestrator/SKILL.md:463-469` selects it via an `AskUserQuestion` ("Impl mode") at Phase 6
  start and persists via `edm-state set-mode <PREFIX> implementation_mode <value>`; it reads the value
  back **from state**, never from userConfig.
- `agents/edm-implementer.md` and `agents/edm-qc-auditor.md` reference `implementation_mode` only as a
  **state field**. No `${user_config.implementation_mode}` reference exists anywhere.

A user who sets `implementation_mode: tdd` at install time still gets the interactive prompt defaulting
to Standard on every initiative — the config is inert.

**Fix**: Same pattern as L11-01 — either thread the userConfig default into the orchestrator's Phase 6
prompt (pre-select TDD when configured, and/or skip the prompt), or drop the key if interactive-only
selection is intended.

### L11-03 — `compliance_enabled` userConfig is never consumed (dead config)

**The reference**: `plugin.json:79-84` defines `compliance_enabled` (boolean, default false):
> "When true, the orchestrator enforces compliance checkpoints … Raises audit findings to P0 …"

**The target it should resolve to**: A read of `${user_config.compliance_enabled}` /
`CLAUDE_PLUGIN_OPTION_COMPLIANCE_ENABLED` that seeds the initiative's `compliance_enabled` state.

**Why it's broken**:
- `edm-state init` hardcodes `compliance_enabled: false` (`edm-state:475`).
- `skills/orchestrator/SKILL.md:139-143` sets it from a "Compliance" `AskUserQuestion` toggle, persisted
  via `edm-state set-mode <PREFIX> compliance_enabled true`.
- `skills/tickets/SKILL.md` and `skills/orchestrator/SKILL.md` read `compliance_enabled` only as a
  **state field** (`edm-state get … | jq '.compliance_enabled'`). No `${user_config.compliance_enabled}`
  reference exists.

The install-time default cannot turn compliance on for an environment; every initiative starts
non-compliant until the orchestrator's toggle is set.

**Fix**: Thread the userConfig default into `edm-init`/`edm-state init` and pre-select the orchestrator
"Compliance" toggle accordingly; or remove the key if per-initiative selection is the only intended path.
NOTE: this one is the most likely to matter operationally — a regulated-environment install would
reasonably expect `compliance_enabled: true` to be sticky.

### L11-04 / L11-05 — Stale `edm-ai-development-staging/` path in smoke-test run comments

**The reference**:
- `bin/tests/wave3-smoke.sh:5`: `# Run from repo root: bash plugins/edm-ai-development-staging/bin/tests/wave3-smoke.sh`
- `bin/tests/wave4a-smoke.sh:5`: `# Run from repo root: bash plugins/edm-ai-development-staging/bin/tests/wave4a-smoke.sh`

**The target it should resolve to**: `plugins/edm-ai-development/bin/tests/wave3-smoke.sh` (and `wave4a-…`)
— the live path after the staging→live cutover. The `edm-ai-development-staging/` directory no longer
exists on disk.

**Why it's broken**: These two files were copied/written in the staging tree during Phase 6 and carried
the staging invocation path into the live plugin at cutover; the documented `bash …-staging/…` command
will fail (`No such file or directory`). The script **bodies** are unaffected — both resolve their own
location via `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`, so running them by the correct
live path works. (`wave4b-smoke.sh` uses `$0`-relative resolution and has no staging reference — clean.)

**Fix**: Replace `edm-ai-development-staging` with `edm-ai-development` in line 5 of both files. Severity
P3 because it is a comment-only run hint, not an executed path, and the scripts are dev-only smoke tests
not on any runtime path.

---

## Reference-resolution matrix

| Reference class | Method | OK | BROKEN | Notes |
|---|---|---:|---:|---|
| marketplace.json `skills[]` → disk | 13 paths vs `skills/*/SKILL.md` | 13 | 0 | All present; no orphan skills on disk |
| marketplace.json `agents[]` → disk | 30 paths vs `agents/*.md` | 30 | 0 | All present; no orphan agents on disk |
| skill/agent/hook/monitor → `edm-state <subcommand>` | 26 distinct subcommands vs 36 dispatch arms | 26 | 0 | Programmatic `comm` diff: 0 referenced-but-undispatched |
| `edm-state` subcommand arg-count (signatures) | call sites vs `[[ $# -eq N ]]` guards | all | 0 | incl. `record-test-coverage` optional 4th `epic` arg — call sites updated in lockstep (3-arg whole-initiative + 4-arg per-epic both present & valid) |
| skill/agent → agent name (spawn) | all `edm-*` agent tokens | all | 0 | Every spawned agent exists as `agents/<name>.md` |
| skill/agent → `${user_config.KEY}` | 16 distinct keys referenced | 16 | 0 | All referenced keys exist in `plugin.json` userConfig (no dangling references) |
| `userConfig` keys → referenced (dead-config check) | 19 defined keys | 15 | — | 4 unreferenced: `mode`, `implementation_mode`, `compliance_enabled` (dead — L11-01/02/03); `commit_state_file` is CONSUMED via `CLAUDE_PLUGIN_OPTION_COMMIT_STATE_FILE` in `edm-init:116` (not dead) |
| hooks.json → command/script | `edm-state` {session-start, gate-check, active-initiatives, checkpoint-if-active, record-task-duration, record-partial-verdict}; `edm-lint-artifacts` | all | 0 | All subcommands dispatch; both bin scripts present & executable |
| monitors.json → command | `edm-state watch-impl`; trigger `on-skill-invoke:implement` | 2 | 0 | Subcommand dispatches; `skills/implement` exists |
| Jira MCP tool names | `mcp__{jira_mcp_namespace}__<tool>` in push-jira | all | 0 | Namespace token consistently parameterized; default `plugin_jira_atlassian-mcp-server` matches `jira_mcp_namespace` userConfig and the live MCP server registration; all 11 tool names valid Atlassian MCP tools |
| Stale `*-staging/` paths (skills/agents/hooks/monitors/marketplace) | grep | — | 0 | None in those components. 2 hits in `bin/tests/` comments (L11-04/05). SRD/EDMV2/** hits are initiative artifacts, out of scope |

bin scripts on disk: `edm-state`, `edm-init`, `edm-validate-prefix`, `edm-lint-artifacts` — all present,
all executable (`-rwxr-xr-x`).

---

## Noted / Not Actionable

- **NOTED-A — Staging references in `SRD/EDMV2/**` are historical initiative artifacts, not wiring.**
  Many `plugins/edm-ai-development-staging/` strings appear in `SRD/EDMV2/srd.md`, `SRD/EDMV2/tickets/**`,
  and `SRD/EDMV2/qc/**`. These are the EDMV2 initiative's own committed planning/SRD/ticket/QC documents
  describing the C-5 self-hosting "build in staging, cut over at the end" strategy. They are intentional
  source-controlled records, not executable references in the shipped plugin. `SRD/EDMV2/code-audit/2026-06-08/lens-L6.md:251`
  independently confirms the plugin tree itself is free of stale staging references (the `bin/tests/`
  comment hits in L11-04/05 are the only live exceptions, surfaced here as a structural reference). Out of
  L11 scope (executable/structural references in skills/agents/hooks/monitors/marketplace).

- **NOTED-B — `commit_state_file` userConfig IS wired (not dead config).** Unlike the three mode-family
  keys, `commit_state_file` is consumed: `edm-init:116` reads `CLAUDE_PLUGIN_OPTION_COMMIT_STATE_FILE`
  and writes a local `.gitignore` excluding `.edm-state.json` when false. It does not appear as
  `${user_config.commit_state_file}` in any skill, but that is the correct mechanism (config reaches the
  bin script via the `CLAUDE_PLUGIN_OPTION_*` env var, not a skill template). Resolves.

- **NOTED-C — `coverage_target_*_pct` wildcard reference.** `agents/edm-test-coverage-auditor.md:112`
  references `${user_config.coverage_target_*_pct}` as a glob standing in for all four coverage-target
  keys. Not a literal key; all four concrete keys (`unit`, `component`, `integration`,
  `e2e_critical_paths`) exist in `plugin.json` and are referenced concretely elsewhere. Intentional
  shorthand, resolves.

- **NOTED-D — `${user_config.jira_mcp_namespace}` default vs live MCP registration.** push-jira's
  `allowed-tools` and body use `mcp__{jira_mcp_namespace}__<tool>` with default
  `plugin_jira_atlassian-mcp-server`. This matches the namespace of the `jira` plugin's Atlassian MCP
  server as registered in the harness (confirmed against the available `mcp__plugin_jira_atlassian-mcp-server__*`
  tool set, which includes all 11 tools push-jira lists). Consistent — resolves. (The literal `{…}`
  placeholders in `allowed-tools` rely on userConfig substitution at load time; that is the documented
  v2 mechanism, not a broken reference.)

- **NOTED-E — `record-task-duration` is a reserved no-op.** The `TaskCompleted` hook
  (`hooks.json:127`) calls `edm-state record-task-duration`, which dispatches to `cmd_record_task_duration`
  (`edm-state:684`) — an intentional no-op documented as reserved/future. The reference resolves and runs
  safely; no accumulation yet by design. Not a broken link.
