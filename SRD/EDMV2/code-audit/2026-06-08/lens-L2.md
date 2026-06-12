# Lens L2: Dead Code & Unreachable Paths

Audit target: EDM Claude Code plugin v2.0.0 (EDMV2), `plugins/edm-ai-development/`
Scope: `bin/edm-state` (1978 lines), `bin/edm-init`, `bin/edm-validate-prefix`, `bin/edm-lint-artifacts`, `bin/tests/*.sh`, plus skill/agent markdown only where they reference branches/flags that can never trigger.
Mandate: strictly reachability — dead functions, unreachable `case`/`if` arms, guards that can never fire, code after unconditional exit, assigned-but-never-read variables, env-gated branches whose env var is never set.

## Method

1. Extracted all 36 `cmd_*` functions (`grep -oE '^cmd_[a-zA-Z0-9_]+'`) and cross-referenced against the bottom-of-file dispatcher (`case "$cmd" in …`, lines 1935-1978). **Result: all 36 are dispatched exactly once; no orphaned command functions.**
2. Counted call sites for every non-`cmd_` helper (`die`, `require_jq`, `artifact_hash`, `read_bool`, `read_num`, `with_state_lock`, etc.).
3. Cross-referenced hook/monitor wiring (`hooks/hooks.json`, `monitors/monitors.json`) and skill-invoked subcommands against the dispatcher. **Result: every hook/monitor/skill-invoked subcommand exists; no ghost calls.**
4. Traced env-gated branches (`EDM_PRODUCT`, `EDM_DESCRIPTION`, `CLAUDE_PLUGIN_OPTION_*`, all pricing overrides) to their set sites.
5. Scanned for code after unconditional `return`/`exit`/`die`. **Result: none found — all are at branch/function ends.**

## Findings

| ID | Sev | File:Line | Issue |
|----|-----|-----------|-------|
| L2-01 | P2 | `bin/edm-state:336-346` | `read_num()` helper is defined but has zero call sites — dead code |

---

### L2-01 — `read_num()` defined but never called (P2)

**Problem**
`read_num()` (lines 334-346) is a type-coercion helper that normalizes a JSON field to a number whether it is stored as a JSON number or a numeric string. It is fully implemented but **never invoked anywhere in the plugin**. It is the only `read_num` reference in the entire codebase besides its own definition.

**Evidence**
- `grep -n 'read_num' bin/edm-state` returns exactly two lines: the doc comment (`:334`) and the definition (`:336`). No call site.
- Its sibling `read_bool()` (lines 322-332) is consumed at 3 sites: `cmd_archive` (`:819`), `write_handoff_internal` (`:1684`), and the comment-referenced gate path. `read_num` is consumed at **0** sites.
- Every numeric field that *could* flow through `read_num` is instead read with raw jq: `.current_phase` is read via `jq -r '.current_phase // 0'` at `:379, :510, :1097, :1272, :1657`; `.current_step` at `:1243, :1288, :1799`; `qc_shard_threshold` is never read at all in `edm-state`. None routes through `read_num`.

**Why unreachable / dead**
The function is reachable in the trivial sense (it would run if called) but is *dead* because no caller ever calls it. It was added to satisfy a literal acceptance criterion — **EDMV2-T33 AC2** (`SRD/EDMV2/tickets/epics/02-foundation-plumbing.md:352`: "A `read_num <state-json> <field>` helper returns a number for both JSON-number and numeric-string storage"). The ticket's Technical Notes (`:357`) state the helpers are kept "so they can be reused by EDMV2-T30 and the **future** WS-B/WS-E typed readers" — i.e. it was added speculatively for future consumers that were never wired up. QC (`SRD/EDMV2/qc/EDMV2-wave1d.md:101`) marked AC2 PASS on the helper's *behavior* in isolation, not on any consumer using it. Unlike `read_bool` (genuinely consumed by the archive gate per AC4), `read_num` has no AC mandating a consumer, and none exists.

This does **not** qualify for the False Alarm Filter: it is documented as a required *deliverable*, but not documented as intentionally-uncalled or as a reserved no-op (contrast `record-task-duration`, which carries an explicit "Reserved no-op" comment). A defined-but-uncalled function with no explanatory "reserved" comment is dead code regardless of the AC that birthed it.

**Fix (delete vs wire-up)** — two equally valid options:
- **Wire-up (preferred for symmetry):** route the existing numeric readers through it, e.g. `current_phase` reads in `cmd_set`/`cmd_validate`/`write_handoff_internal` and the `current_step` numeric read in `cmd_current_step`, so legacy stringified numeric fields coerce identically to `read_bool`'s treatment of stringified booleans. This realizes the "any consumer of typed fields" intent in the T33 Target-Components line.
- **Delete:** remove lines 334-346. The AC was about correct *coercion behavior*; if no field is ever stored as a numeric string in practice, the helper is pure overhead. If deleted, add a one-line note to the T33 record that AC2's helper was removed as unused.

Severity P2 (maintainability): no incorrect behavior today — it is inert — but it is a maintenance trap (future readers assume it is load-bearing) and a divergence from the consumed `read_bool` twin.

---

## Noted / Not Actionable

- **`cmd_record_task_duration` (`:684-689`) — reserved no-op.** Body is `return 0` with an explicit three-line comment ("Reserved no-op — TaskCompleted hook wires here but accumulation is not yet implemented"). Wired in `hooks/hooks.json` `TaskCompleted` (`:127`) and documented in CLAUDE.md ("TaskCompleted — Reserved"). Intentional per the False Alarm Filter; explicitly called out as NOTED in the lens mandate. Not dead code.

- **`compute_cost_usd` `*sonnet*|*` arm (`:217`).** The trailing `*` catch-all makes the leading `*sonnet*` pattern technically redundant (anything reaching this arm already failed `*opus*` and `*haiku*`). The `*sonnet*` token is documentation-only — it signals intent ("sonnet is the default model") and is still matched first. Reachable, not dead; redundant-pattern-for-readability is a deliberate, common style. Not a reachability finding. (If a style lens cares, that is L-style's call, not L2's.)

- **`human_cost_for_phase` default arm `*) hours=0` (`:244`).** Reachable: `cmd_phase_complete` does not validate the phase argument, and `estimated_size` legitimately defaults to `"Unknown"` (`:460, :581`), which forms no matching `${size}-${phase}` key (e.g. `Unknown-2`), so the default arm fires. Correct defensive fallback. Not dead.

- **`artifact_hash` final `md5 -q … || echo "unhashable"` fallback (`:65`).** Reachable only on a host lacking sha256sum, shasum, AND md5sum. Defensive portability code; the dev host is macOS (has `shasum`) so it is not normally taken, but it is not *unreachable* in principle (e.g. a minimal CI image). Defensive, not dead.

- **`state_file_for` AC6 branch — "product known, description unknown" glob (`:143-148`).** Within `edm-init`'s own subprocess this env state never occurs (it always exports `EDM_PRODUCT`+`EDM_DESCRIPTION` together at `:52-53`/`:62-63`, or neither). **However**, `state_file_for` is called by ~30 other subcommands invoked directly by skills/hooks where a user's shell may have `EDM_PRODUCT` set without `EDM_DESCRIPTION`. So the branch is reachable via external env and is documented as resolver AC6 (EDMV2-T37). Not dead.

- **`state_file_for` "multiple matches" warning (`:128-132`).** Fires when two product-scoped dirs share a PREFIX. `edm-validate-prefix` enforces global PREFIX uniqueness at init, but manual filesystem edits or merges can still produce duplicates, so the guard is a legitimate defensive path, not one made dead by an earlier check. Not dead.

- **`with_state_lock` mkdir spin-lock fallback (`:296-315`) and `flock -w 10` timeout message (`:292`).** The flock fast-path vs. mkdir fallback is gated on `command -v flock`; both branches are reachable depending on host (flock is absent on stock macOS, present on Linux). The `flock -w 10` timeout message fires on a real >10s concurrent holder — reachable under contention (this is exactly what EDMV2-T24 AC6's parallel-write test exercises). Note: the lens mandate hypothesized a "`flock -w 1800`" guard; the actual value is `-w 10`, and the message is reachable. Not dead.

- **`cmd_git_lock_check` stale-removal path (`:1219-1222`).** Falls off the end of the function (implicit `return 0`) after the `rm`/echo — this is intended success behavior, not unreachable code. The `else` branch returns 1. Both reachable. Not dead.

- **Dispatcher `""|-h|--help|help` and `*` arms (`:1972-1977`).** Both reachable (no-arg/help invocation; unknown subcommand). Not dead.

- **`cmd_archive` three-case convergence gate (`:824-831`).** The `converged=="false" && -n "$product_name"` refuse-branch, the `prototype` warn-branch, and the `absent` legacy warn-branch are each reachable and match SRD EDMV2-T30 / srd.md:199 verbatim. The implicit "converged==true proceeds silently" path is the documented fourth case. All intentional and reachable. Not dead.

- **README/CLAUDE.md subcommand tables vs. dispatcher.** Reverse-direction check (mandate noted L6/L11 own docs): every subcommand the docs mention maps to a dispatched arm, and every skill-invoked subcommand exists in the dispatcher. No documented-but-undispatched commands and no skill ghost-calls. Nothing for L2 here.

- **`EDM_STATE` "57 occurrences" — false positive.** An uppercase-substring grep flagged `EDM_STATE` 57 times; these are (a) the test-harness variable `EDM_STATE="…/edm-state"` in `bin/tests/*.sh` and (b) the uppercased substring of the script name. There is no `EDM_STATE` env-gated branch in the production scripts. No env-gated dead branch.

- **All pricing-override env vars (`EDM_OPUS_INPUT_RATE`, etc.).** Read with `${VAR:-default}` defaults; the harness/operator may set them at runtime. Defaulted-but-overridable is by design (documented in CLAUDE.md cost section). The default-taken path and the override-taken path are both reachable. Not dead.
