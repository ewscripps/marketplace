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
report a `PERM_RULES_MISSING` anomaly (informational, never fails validation) when none of the
three scanned settings files (`<project-root>/.claude/settings.local.json`,
`<project-root>/.claude/settings.json`, `${HOME}/.claude/settings.json`) has both patterns
configured, and every gate approval records an
`enforcement` tag (`permission-ask` or `prose-only`) in `.edm-state.json` so the actual
coverage is auditable after the fact instead of assumed. `<project-root>` there is resolved
(CA-448) as `CLAUDE_PROJECT_DIR` when the host exports it and it names a directory, else the
git toplevel, else the caller's cwd -- so running `edm-state` from a subdirectory no longer
misses a correctly-configured project settings file the way a cwd-relative probe did.

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
| `/edm:code-audit <PREFIX> [--lenses L1,L9,L11]` | Post-6 | 14-lens exhaustive audit + synthesizer-produced remediation plan. `--lenses` runs a named subset instead -- `L1,L9,L11` (logic, spec compliance, integration wiring) is the cheap smoke path for a small initiative. A subset round is recorded as `partial` and is **never convergent**, so a full fourteen-lens round is still required before the convergence gate and archive |
| `/edm:verify-runtime <PREFIX>` | 6 closure | Mandatory Phase 6 closure -- drives every PARTIAL verdict to PASS or FAIL via runtime checks; then run `edm-state phase-complete <PREFIX> 6` |
| `/edm:metrics <PREFIX\|--all\|--calibrate> [--with-human-baseline]` | Reporting | Per-phase durations and raw Claude cost by default; gate review times; per-round audit cost; `--with-human-baseline` opts into an estimated human-cost comparison; calibration |
| `/edm:push-jira <PREFIX> [PROJECT_KEY]` | Optional | Sync ticket pack to Jira via Atlassian MCP (idempotent, label-tracked, dependency-linked) |
| `/edm:test <PREFIX>` | Post-6 | Comprehensive testing pipeline: plan -> scaffold -> write (unit/component/composable/integration/contract/E2E/a11y) -> run -> audit coverage |
| `/edm:test-plan <PREFIX>` | Post-6 | Preview test scope only: detect stack + map AC to layers, no test writing |
| `/edm:test-coverage <PREFIX>` | Post-6 | Re-audit coverage against existing tests, update `test-coverage.md` |

All phase skills set `user-invocable: true`. They must NOT set `disable-model-invocation: true` --
that flag blocks every `Skill`-tool call, including the orchestrator's own dispatch of each phase
(`Skill edm:plan cannot be used with Skill tool due to disable-model-invocation`). Each skill's
description says "Invoked explicitly via `/edm:<name>`" so Claude doesn't auto-fire it on casual
prompts; invoke them with the slash commands.

## Agents

| Agent | Phase | Model |
|---|---|---|
| `edm-explorer` | 1 -- Planning | sonnet / high |
| `edm-architect` | 2 -- Architecture | opus / high |
| `edm-srd-writer` | 2 -- SRD content | opus / high |
| `edm-srd-auditor` | 3 -- SRD audit | opus / max (read-only) |
| `edm-ticket-writer` | 4 -- Tickets | opus / high |
| `edm-ticket-auditor` | 5 -- Ticket audit | opus / max (read-only) |
| `edm-implementer` | 6 -- Code | sonnet / high (worktree-isolated) |
| `edm-qc-auditor` | 6 -- QC | opus / max (read-only, auto-spawned) |
| `edm-audit-{logic,dead-code,edge-cases,test-quality,runtime,docs,consistency,security,spec,dry,wiring,silent-failures,type-design,behavioral-tests}` | Code audit | opus / max (read-only, parallel) |
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
| `edm-test-coverage-auditor` | Testing | sonnet / high (cyan, read-only) -- coverage gaps + AC cross-ref |

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
|       |   |-- findings-ledger.jsonl        <- authoritative cross-round findings ledger (stable CA-NNN IDs)
|       |   |-- findings-ledger.md           <- deterministic render of findings-ledger.jsonl (`edm-state render-ledger`)
|       |   `-- pass-{N}_{YYYY-MM-DD}/
|       |       |-- lens-L1.jsonl ... lens-L14.jsonl  <- authoritative per-lens findings (schema in skills/code-audit/SKILL.md)
|       |       |-- lens-L1.md ... lens-L14.md
|       |       |-- lenses-run.txt
|       |       |-- tooling-notes.md          <- on-demand: per-lens stall counts / truncation caveats (absent when delivery was clean)
|       |       `-- REMEDIATION.md
|       `-- .edm-state.json               <- gate approvals, phase timestamps, mode fields (committed by default)
`-- {PREFIX}/                          <- legacy flat layout (still supported, auto-detected)
    `-- ...
```

See `CLAUDE.md` for the full v2.0 artifact inventory. That inventory marks `architecture.md`,
`explorers/` and `decisions.md` as always-present (Must), not optional -- `decisions.md` in
particular is load-bearing at runtime: `skills/code-audit/SKILL.md` requires every convergence
approval be appended to it, and `CLAUDE.md`'s D15 section requires scope changes recorded there.
The genuinely optional, on-demand files are `ROLLBACK.md`, `exec-report.md` and `post-deploy/`.

Artifacts are reviewed in PRs. Gate approvals show up in git history. Multiple developers see the same in-flight initiative state.

### Runtime files to `.gitignore` (CA-314)

Every initiative directory accumulates a small set of runtime files that are not artifacts and
should never be committed: a permanent state-file backup (kept forever, for `migrate-path`
rollback), advisory lock files (deliberately never unlinked -- see `bin/edm-state`'s own
`with_state_lock` comment for why removing it would break mutual exclusion), and the transient
temp files `write_atomic` creates while writing any file (`.edm-state.json` or a `.md` artifact)
atomically. Note that `with_state_lock` is called against more than one lockbase -- the state
lockbase (`.edm-state.*`) is not the only one; `render-ledger` locks a second, independent
`code-audit/findings-ledger` lockbase (CA-382, round 7), and a future caller may introduce
others. The two shape-anchored patterns below (`*.lock`, `*.lockd*`) cover ANY lockbase by
construction, rather than requiring a new named pattern each time `with_state_lock` gains a
caller. Both `edm-init` and `edm-state init <PREFIX>` (a publicly documented subcommand that
can be invoked directly, bypassing `edm-init`) write this block into every new initiative's own
`.gitignore` automatically (unconditionally, regardless of `commit_state_file`) -- G11/CA-341
(round 6) closed the gap where only `edm-init`'s copy existed and the direct `edm-state init`
entry point left a new initiative with no `.gitignore` at all. The same block is reproduced here
as a copy-pasteable reference and for initiatives created before this was automatic:

```gitignore
.edm-state.json.bak
.edm-state.json.tmp.*
.edm-state.lock*
*.lock
*.lockd*
*.md.tmp.*
```

`.edm-state.json` itself is tracked and committed by default (`commit_state_file: true`, the
recommended setting -- see "Project artifact layout" above for why). Set `commit_state_file` to
`false` in your plugin config to keep it out of git instead; `edm-init` then adds `.edm-state.json`
to this same per-initiative `.gitignore`.

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

**The post-Phase-6 code audit does not have to be the full fourteen lenses.** For a small
initiative, `/edm:code-audit <PREFIX> --lenses L1,L9,L11` (logic and correctness, spec and ticket
compliance, integration wiring) is a much cheaper smoke path -- three parallel lens agents plus
the synthesizer instead of fourteen. Reserve the full fourteen-lens round for a release candidate, or
for any initiative whose audit result is going to be relied on. A subset round is recorded as
`partial` and is **never convergent**: `edm-state audit-converged` refuses it, so the convergence
gate and `edm-state archive` still require one full round no matter how many partial rounds
preceded it. See `skills/code-audit/SKILL.md` for the lens inventory and the round-type rules.

## Hooks -- what this plugin does without being asked

Installing EDM registers six hook events. **Three of them can block**, so read this section before
your first initiative: two of the three fire on ordinary editing, not only inside an EDM command.

| Event | Matcher | Blocks? | What happens |
|---|---|---|---|
| `SessionStart` | -- | no | Prints any in-progress initiative and its next action (`edm-state session-start`). |
| `UserPromptExpansion` | `edm:(srd\|audit-srd\|tickets\|audit-tickets\|implement)` | **yes** | Refuses to expand a phase command whose prerequisite HITL gate is not approved. Only a real gate refusal blocks (exit 2); a missing binary or an unknown prefix -- the legitimate first-run case -- exits 0. |
| `PreToolUse` | `Edit\|Write\|MultiEdit` | **yes** | `edm-gateguard`. See below. |
| `PreToolUse` | `Bash` (two entries) | **yes** | Entry 1 `edm-bash-gate` runs on every Bash call and evaluates `bash`-event hookify rules. Entry 2 is gated by `"if": "Bash(git commit*)"` and runs `edm-lint-staged-artifacts`, which blocks a commit carrying artifact-lint violations. Neither entry suppresses the other. |
| `Stop` | -- (two entries) | **yes** | Entry 1 checkpoints state. Entry 2 `edm-stop-gate` refuses to end the session while any active initiative has a blocking `edm-state validate` anomaly, or a `stop`-event hookify rule matches with `"action": "block"`. |
| `SubagentStop` | `edm-implementer` | no | Auto-spawns `edm-qc-auditor` to verify the finished implementer's acceptance criteria. |
| `PreCompact` | -- | no | Checkpoints state before context compaction. |

### `edm-gateguard` -- the one most likely to surprise you

While an initiative is in **Phase 6**, the first `Edit` or `Write` to any given file is **denied**,
and the denial asks for four facts: who calls the file, what else already does its job, what data
shapes it touches, and the acceptance criteria of the ticket being implemented. Answer them and the
retry is allowed. The intent is to stop an agent editing a file it has not read.

Outside Phase 6 there is no marker on disk and the gate allows immediately -- one process exec, one
file test, zero `jq` calls.

If it gets in your way:

```bash
export EDM_GATEGUARD=off          # or 0, false, disabled, disable
export EDM_GATEGUARD_DISABLED=1   # second, independent switch -- literal "1" only
```

`SRD/`, common test trees, and generated output (`dist`, `build`, `node_modules`, `.git`) are
exempt by default; override with `EDM_GATEGUARD_EXEMPT_GLOBS`. Denials are capped per session
(`EDM_GATEGUARD_MAX_DENIALS`, default 3) -- past the cap the gate advises on stderr and allows
rather than denying forever.

### Rules as data -- `.claude/edm-hookify/*.json`

Your project can add its own enforcement without forking the plugin. Drop JSON rule files in
`.claude/edm-hookify/` (project root, source-controlled -- a rule changes what is enforced for
every teammate, so it belongs in review). Each rule names an `event` (`file`, `bash`, or `stop`),
a list of `conditions` (all must match), a `message`, and an `action`.

**`action` defaults to `warn`.** A rule blocks only if it carries the literal `"action": "block"`.
A malformed rule file is a setup error: it is named on stderr and skipped, it never blocks, and it
never disables the rest of your rules.

```json
{
  "name": "warn-no-console-log",
  "enabled": true,
  "event": "file",
  "action": "warn",
  "conditions": [
    { "field": "new_text", "operator": "contains", "pattern": "console.log" },
    { "field": "file_path", "operator": "not_contains", "pattern": "/tests/" }
  ],
  "message": "Avoid leaving console.log statements in non-test source files."
}
```

Six operators: `regex_match`, `contains`, `not_contains`, `equals`, `starts_with`, `ends_with`.
`regex_match` uses `jq`'s Oniguruma engine, not POSIX ERE -- test a pattern with `jq -r 'test("...")'`
rather than `grep -E`. Kill switches for all three consumers:

```bash
export EDM_HOOKIFY=off            # or 0, false, disabled, disable
export EDM_HOOKIFY_DISABLED=1     # literal "1" only
```

Full schema, valid `field` values per event, and the documented failure modes are in `CLAUDE.md`'s
"Hookify rule format (canonical)" section.

## Command-line tools (`bin/`)

Every script below is on `PATH` while the plugin is enabled, and each supports `--help`. When
developing the plugin itself, invoke them by explicit path (`bash plugins/edm/bin/edm-state ...`) --
neither `/plugin update` nor `/reload-plugins` reads your working tree, so a bare name runs
whatever last reached the marketplace clone.

| Script | Purpose |
|---|---|
| `edm-init` | Scaffold a new initiative directory (flat or `--product`/`--description` scoped). |
| `edm-validate-prefix` | Check a proposed PREFIX is free across every product subdirectory. |
| `edm-state` | Read/write `.edm-state.json`; 42 subcommands covering phases, gates, audit rounds, metrics, PARTIAL closure, pattern harvest, and `unlock`. |
| `edm-gateguard` | `PreToolUse` Edit/Write/MultiEdit gate (see Hooks above). |
| `edm-hookify` | Evaluator for the rule format above. `list` and `eval <file\|bash\|stop>`. |
| `edm-bash-gate` | `PreToolUse` Bash consumer for `bash`-event rules. |
| `edm-stop-gate` | `Stop` completion gate -- blocking-anomaly and `stop`-event rule enforcement. |
| `edm-lint-artifacts` | Scan artifact markdown for attribution trailers, non-ASCII bytes, leaked tool tags, and raw semicolons in Mermaid labels. `--all` or `--path <dir>` for a manual sweep. |
| `edm-lint-staged-artifacts` | The commit-time body of the git-commit hook: maps staged paths to prefixes and lints each. |
| `edm-repo-readiness` | Score the repository EDM is about to work in across six categories. A category whose probe could not be read is reported `UNMEASURED` and still counts against the score, so the total is a floor rather than a flattering average. |
| `edm-check-verifier-sentinel` | Verify a read-only verifier finished rather than hitting its turn ceiling: reads only the artifact's last line and refuses on a missing sentinel or a short `audited=` count. |
| `edm-check-grants` | Four-source grant/instruction contract check across agent bodies, skill launch templates, hook prompts and tool grants. |
| `edm-check-vocabulary` | Backstop for the abolished-severity-vocabulary policy. |
| `edm-check-skill-sync` | Tripwire: the dispatcher holds no phase procedure, every phase skill owns its own, and no skill sets `disable-model-invocation`. |
| `edm-sync-canonical-sections` | Regenerate `docs/canonical-sections.md` from `CLAUDE.md`'s seven canonical sections; `--check` exits 1 on drift. |
| `edm-compare-eval` | Compare an eval run against the committed baseline, refusing on a scorer-version or dimension mismatch. |

`_edm-cli-lib.sh`, `_edm-datadir-lib.sh` and `_edm-lint-lib.sh` are **sourced, never executed** --
the leading underscore marks them as libraries even though `bin/` is on `PATH`.

### Where plugin data lives

`_edm-datadir-lib.sh` resolves a writable data root for the Phase-6 marker, gate session state and
the harvested pattern delta: `$CLAUDE_PLUGIN_DATA` if it is absolute and **EDM-owned**, else
`$XDG_DATA_HOME/edm`, else `~/.local/share/edm`. None of this lives in your repository.

"EDM-owned" means the directory does not exist yet, is empty, carries EDM's own `run/` or
`patterns/`, or carries an `.edm-owned` sentinel. A populated directory belonging to another
plugin is skipped. This matters because EDM is often invoked by explicit path, where the host has
no reason to have pointed `$CLAUDE_PLUGIN_DATA` at EDM -- without the ownership test, EDM wrote its
pattern library into whichever plugin happened to be active.

## Plugin features

- **Hooks** (`hooks/hooks.json`): six events, three of which can block -- see "Hooks -- what this plugin does without being asked" above for the full table, `edm-gateguard`'s Phase-6 fact-forcing behaviour, and every kill switch.
- **Background monitor** (`monitors/monitors.json`): during Phase 6, tails `git log` and reports each ticket commit as a notification.
- **Worktree isolation**: parallel `edm-implementer` agents each get their own git worktree automatically -- no manual setup, no merge conflicts mid-wave.
- **State persistence**: `bin/edm-state` tracks each initiative's phase, gate approvals, timing, cost, and test coverage in `SRD/{PREFIX}/.edm-state.json`. Survives across sessions.
- **Resume**: a teammate cloning the repo can pick up an in-progress initiative -- the state is in git.
- **`userConfig`**: prompts for output paths, conventions, coverage targets, and framework overrides at install time.
- **Comprehensive testing**: `/edm:test` runs 10 specialist agents (planner, scaffold, 7 writers, coverage auditor) in parallel waves, producing `test-plan.md` and `test-coverage.md` with AC->test cross-reference. Stack-aware -- automatically marks layers N/A for backend-only or CLI projects.
- **Multi-stack testing** (v2.0+): for initiatives spanning multiple technology stacks (e.g., a Python backend epic and a Vue frontend epic), the test planner detects the stack per epic and produces `test-plan-{epic}.md` / `test-coverage-{epic}.md` per epic, each scoped to that epic's frameworks and coverage targets. Single-stack initiatives use the same `test-plan.md` / `test-coverage.md` behavior as before.
- **Product-line linkage** (v2.0+): link related initiatives with `edm-state set-parent <PREFIX> <PARENT>` and `edm-state add-related <PREFIX> <RELATED>`. Linkage fields appear in HANDOFF.md so teams can navigate across child/sibling initiatives without losing context. Provenance links use the same mechanism: `edm-state set-supersedes <PREFIX> <OTHER>` records that `<PREFIX>` supersedes `<OTHER>`, and `edm-state set-forked-from <PREFIX> <OTHER>` records that `<PREFIX>` was forked from `<OTHER>` -- both also render in HANDOFF.md.

## See also

- `CLAUDE.md` -- plugin conventions for contributors
- `CHANGELOG.md` -- version history
- `NOTICE` -- third-party attribution (GateGuard and everything-claude-code, both MIT); the fact-prompt text in `edm-gateguard` is reused from GateGuard rather than re-authored
- The Claude Code plugin docs: `code.claude.com/docs/en/plugins`
