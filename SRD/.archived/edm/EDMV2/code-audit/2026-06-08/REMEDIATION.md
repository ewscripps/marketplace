# Code Audit Remediation Plan: EDM Plugin v2.0.0 (EDMV2)

## Context

This plan consolidates the findings of an eleven-lens orthogonal code audit (L1-L11) of the EDM
Claude Code plugin **v2.0.0** ("EDMV2"), implemented at `plugins/edm-ai-development/`, conducted
**2026-06-08**. Raw lens reports live alongside this file (`lens-L1.md` … `lens-L11.md`).

The audited code is **pre-deployment**: v2.0.0 is intended to deploy over the installed **v1.3.0**
via `claude plugin upgrade`. Every fix below lands **before** that upgrade — there is no migration
of an already-shipped v2.0.0 in the field. That sequencing matters for two reasons: (1) the
concurrency and layout-glob bugs (G1-G3) have not yet corrupted any production state, so we are
preventing failure rather than recovering from it; (2) the `claude plugin validate` /
`.claude-plugin/plugin.json` manifest fix (G5) must be correct at the moment of upgrade or the new
v2.0 userConfig keys never reach the install-time prompt.

A second-pass **False Alarm Filter** was applied to every lens finding: anything documented as
intentional in `SRD/EDMV2/srd.md` or the ticket pack, explained by an in-code comment, or
established as a consistent project pattern was demoted to **Decisions / Non-Findings** (see that
section — it is long by design, to prevent re-investigation). The most severe surviving findings
(all P1s, plus G8) were **re-verified against the live code** by the synthesizer (empirical repro,
not rubber-stamp); verification notes are inline.

**Severity scale used by this plan** (the code-audit skill's scale):
- **P1** — production failure, security gap, or incorrect behavior. Fix before shipping.
- **P2** — operational friction, misleading messages, incomplete docs, unresolved TODO. Fix before shipping.
- **P3** — nice-to-have. Fix if low effort.
- **NOTED** — looks like a problem but is intentional. Documented once; never revisit.

> Note on scale: the v2.0 plugin **internally** uses a P0/P1/P2/NOTED scale for its own audit agents.
> This remediation plan deliberately uses **P1/P2/P3/NOTED** per the code-audit skill. The two are
> not the same axis; findings are graded on the P1/P2/P3 scale here and not relabeled.

After dedup and filtering: **24 findings** — **7 P1, 12 P2, 5 P3** — plus **~30 cleared false
alarms / non-findings**. The corroboration clusters flagged by the audit charter all verified true.

---

## Findings Summary

| # | Sev | Lens(es) | Component | Issue |
|---|-----|----------|-----------|-------|
| **G1** | P1 | L1 (01,03,04), L3 (04), L10 (01) | `bin/edm-state` enumeration | Layout-glob omission: `checkpoint`, `active-initiatives`, `metrics-report --all/--calibrate` glob only flat `SRD/*/`; product-scoped `SRD/*/*/` initiatives silently skipped (violates EDMV2-88) |
| **G2** | P1 | L3 (01), L10 (02), L8 (noted) | `bin/edm-state` write path | Concurrent lost-update race: read-modify-write reads state **before** the lock; ~1/10 concurrent writes survive (empirically proven). Falsifies SRD §1049/§1124 |
| **G3** | P1 | L3 (02), L10 (02) | `cmd_checkpoint` | Stop/PreCompact hook hand-rolls `cat→jq→truncating >` with **no lock and no `.bak`** — bypasses `write_state`/`with_state_lock` entirely |
| **G4** | P1 | L1 (02) | `cmd_get_coverage` | "Tests Added by Phase" jq filter ends `… | .[] // .` over a string → `Cannot iterate over string`; section never renders and `get-coverage` exits 5 even on success (verified) |
| **G5** | P1 | L9 (01), L11 (01,02,03) | `plugin.json` manifests | Wrong/diverged manifest: `claude plugin validate` loads `.claude-plugin/plugin.json`, which is **missing** `mode`, `compliance_enabled`, `qc_shard_threshold`, `implementation_mode`. (a) keys never reach install prompt; (b) three of them are dead config never consumed as new-initiative defaults |
| **G6** | P1 | L8 (01) | `bin/edm-lint-artifacts` | `mapfile -t` is a bash-4 builtin; macOS stock `/bin/bash` is 3.2 → `edm-state lint` and the PreToolUse commit-lint gate abort on the primary host (verified) |
| **G7** | P1 | L8 (02) | `bin/edm-state` resolver | Path-traversal arbitrary write: `PREFIX` is interpolated into the state path with no format validation; `../escaped/X` writes `.edm-state.json` outside `SRD_ROOT` (verified live) |
| **G8** | P2 | L1 (05) | `cmd_metrics_report` / `cmd_phase_complete` | Misleading `0x` savings whenever `human_baseline_usd == 0` (init writes `estimated_size:"Unknown"` → baseline `$0`; dead `// "Medium"` default). Should print `n/a` (verified live: every phase shows `0x`) |
| **G9** | P2 | L3 (03) | `_write_state_body` | No atomic write: truncate-in-place (`printf > "$f"`) instead of temp-file + `mv`; SIGKILL mid-write leaves a partial state file (`.bak` limits blast radius but recovery is manual) |
| **G10** | P2 | L1 (06), L3 (07) | `record-test-coverage` / `record-tests-added` / `approve-gate` | User numeric args reach `jq --argjson` with no validation → raw `jq: invalid JSON text` crash instead of a friendly `die` (no corruption — fails before write) |
| **G11** | P2 | L5 (01,02) | `.gitignore` / `edm-init` | `.edm-state.json.bak` (every write) and `.edm-state.json.lock` (flock hosts) sit beside the committed state file and are **not gitignored** → permanent untracked noise |
| **G12** | P2 | L3 (06), L8 (03) | `cmd_migrate_path` | Multi-step move with no rollback + post-move write bypasses lock/backup; raw `--product`/`--description` are not path-sanitized (confinement bypass, no command-exec) |
| **G13** | P2 | L3 (05) | `with_state_lock` (flock branch) | flock-timeout `exit 1` escapes only the subshell; the mutating command silently no-ops while the caller proceeds. The mkdir branch correctly `die`s — the two branches diverge on failure semantics |
| **G14** | P2 | L2 (01) | `bin/edm-state` | `read_num()` defined (T33 AC2) but has **zero** call sites — dead code with no "reserved" comment (its twin `read_bool` is consumed; maintenance trap) |
| **G15** | P2 | L8 (05) | `cmd_update_patterns` | Appends (`>>`) to plugin-relative `docs/audit-patterns/*.md`; fails silently when the plugin is installed read-only (`~/.claude/plugins`, system path) |
| **G16** | P2 | L6 (01-08), L7 (02) | docs (`README.md`, `CLAUDE.md`, agent frontmatter) | Doc accuracy batch: README shows obsolete flat layout + wrong `code-audit/` dir + dead link + false "TaskCompleted records durations"; CLAUDE.md subcommand/userConfig/hook tables incomplete; `disallowedTools` doc contradicts code |
| **G17** | P2 | L7 (01) | `edm-srd-auditor` / `edm-ticket-auditor` | NOTED severity level implemented three ways; `edm-srd-auditor` drops it entirely (3-row table) — violates CLAUDE.md "No agent may define a divergent local scale" |
| **G18** | P2 | L10 (03,04,05,06) | `bin/edm-state`, `bin/tests` | DRY hardening that *prevents re-divergence*: phase-name map, gate↔phase map, coverage-table renderer (already diverged on padding), and test-harness preamble are each duplicated 2-5× |
| **G19** | P2 | L4 (01-10) | `bin/tests/*.sh` | Test-quality: tautological/empty-region absence assertions (false-positive-prone) + zero smoke coverage for `migrate-path`, per-epic `record-test-coverage`, `set-parent`/`add-related`, and the `.bak` mechanism |
| **G20** | P3 | L1 (07) | `cmd_metrics_report` | Phase label renders `1Phase` instead of `Phase 1` (`sub("_phase$";"Phase ")` leaves the digit in front; verified live) |
| **G21** | P3 | L1 (08) | `cmd_update_patterns` | Heading skip-list (`summary*|findings*|…`) is a prefix match → a real finding titled "Summary of …" is silently dropped from the pattern library |
| **G22** | P3 | L6 (09-12), L7 (03,04,05) | docs / agent frontmatter | Doc nits: `edm-test-contract` omits GraphQL; "Verified May 2026" stale; README state-tree omits mode fields; architect effort exception undocumented; severity one-liner + key-order drift |
| **G23** | P3 | L11 (04,05) | `bin/tests/*.sh` | Two stale `edm-ai-development-staging/` paths in smoke-test run-hint comments (bodies unaffected) |
| **G24** | P3 | L5 (03), L8 (04,06), L10 (07,08,09) | `bin/edm-state` | Low-value cleanups: stale-sidecar `git mv`→`mv` fallback, flock FD-200 hardening, `pgrep`/`xargs` nit, three more duplicated idioms |

---

## [G1] (P1, L1+L3+L10): Layout-glob omission — canonical product-scoped initiatives silently skipped

### Problem
Three `edm-state` commands enumerate only the **flat** `SRD/*/.edm-state.json` layout and silently
miss the **canonical v2.0 product-scoped** `SRD/{PRODUCT}/{PREFIX}__{DESC}/.edm-state.json` layout
(one level deeper). `cmd_list` and `cmd_session_start` correctly scan both `*/` and `*/*/` with
dedup; these three were never updated:

- **`cmd_checkpoint`** (Stop/PreCompact hook) — product-scoped initiatives get **no `last_updated`
  bump, no drift detection, no HANDOFF/Resume-Point refresh**. The compaction-resilience and
  Gate-re-approval safety features are dead for the layout the SRD calls canonical.
- **`cmd_active_initiatives`** — product-scoped active initiatives are reported as nonexistent,
  defeating the orchestrator's multi-initiative concurrency warning (violates EDMV2-T35 AC1, which
  says it "reuses the `cmd_list` glob pattern").
- **`cmd_metrics_report --all` and `--calibrate`** — product-scoped initiatives contribute nothing
  to the aggregate cost/time table or calibration medians; headline numbers under-count every
  initiative created the v2.0 way.

This is exactly the "missed reference leaves an artifact written to the wrong directory" risk the
SRD calls out at `srd.md:1149`, which **explicitly lists the `metrics-report` globs** among the call
sites that must move to state-derived/both-layout resolution under EDMV2-88 ("All artifact paths must
be derivable from state … never hardcoded to the flat `SRD/{PREFIX}` layout", `srd.md:1226`).

### Evidence (file:line)
- `bin/edm-state:630` — `for state in "$SRD_ROOT"/*/.edm-state.json; do` (checkpoint)
- `bin/edm-state:1094` — same flat-only glob (active-initiatives)
- `bin/edm-state:872` — `… "$SRD_ROOT"/*/.edm-state.json "$SRD_ROOT"/.archived/*/.edm-state.json` (`--all`)
- `bin/edm-state:913` — same pair as a `jq -s` arg list (`--calibrate`)
- Correct reference: `bin/edm-state:495-497` (`cmd_list`) and `:1268` (`cmd_session_start`) use
  `"$SRD_ROOT"/*/.edm-state.json "$SRD_ROOT"/*/*/.edm-state.json` with a seen-set dedup.
- **Verified by synthesizer**: confirmed the three call sites still carry the single-glob form in the
  live `bin/edm-state`; `cmd_list`/`cmd_session_start` carry the two-glob+dedup form.

### Fix (concrete)
Land this together with **G18**'s enumerator extraction. Add one helper and route all six loops
through it so every consumer has identical layout coverage by construction:

```bash
# Emits each unique state-file path, one per line, across all supported layouts.
# Pass --archived to additionally include SRD/.archived/.
list_state_files() {
  local include_archived="${1:-}"
  local globs=("$SRD_ROOT"/*/.edm-state.json "$SRD_ROOT"/*/*/.edm-state.json)
  [[ "$include_archived" == "--archived" ]] && \
    globs+=("$SRD_ROOT"/.archived/*/.edm-state.json "$SRD_ROOT"/.archived/*/*/.edm-state.json)
  local f; local -A seen=()
  for f in "${globs[@]}"; do
    [[ -f "$f" ]] || continue
    [[ -n "${seen[$f]:-}" ]] && continue
    seen[$f]=1
    printf '%s\n' "$f"
  done
}
```

Then rewrite each loop as `while IFS= read -r state; do … done < <(list_state_files [--archived])`.
Pass `--archived` for the two `metrics-report` aggregates only. (Note the archived glob is currently
one-level `.archived/*/`; the helper above also covers `.archived/*/*/` so product-scoped archives
aggregate too — a latent gap L1-04 flagged as separate-but-related.) `bash --version` on the dev host
is 3.2, which **does** support `local -A` associative arrays (added in 4.0) — **it does not.** Use a
3.2-safe dedup (linear seen-array as `cmd_list` does today, or a sorted-unique `printf | sort -u`)
instead of `local -A`. See G6 for the bash-3.2 constraint.

### Verification
- Create one flat (`SRD/FLAT/`) and one product-scoped (`SRD/edm/PROD__demo/`) active initiative.
- `edm-state active-initiatives` lists **both**.
- `edm-state metrics-report --all` shows **both** rows (and `--calibrate` includes both in medians).
- `edm-state checkpoint-if-active` bumps `last_updated` and writes `HANDOFF.md` for **both** (diff
  `last_updated` before/after on the product-scoped state).

### Files
`plugins/edm-ai-development/bin/edm-state` (`cmd_checkpoint`, `cmd_active_initiatives`,
`cmd_metrics_report`; add `list_state_files`).

---

## [G2] (P1, L3+L10+L8): Concurrent lost-update race — read-modify-write outside the lock

### Problem
Every mutating subcommand follows `current="$(read_state …)"` → `new="$(echo "$current" | jq …)"` →
`write_state "$prefix" "$new"`. **Only `write_state` takes the advisory lock**; the read and the
in-memory merge happen *before* the lock, and `write_state` overwrites the **entire** file with the
writer's stale snapshot. The lock serializes the truncating writes but does nothing to prevent each
writer basing its write on an out-of-date read — the classic lost-update / non-atomic RMW. This is
the exact opposite of what the lock was added to do.

The triggering scenario is the **documented v2.0 concurrency hotspot**: Phase 6 runs multiple
`edm-implementer` agents in parallel git worktrees, and the `SubagentStop` hook auto-spawns
`edm-qc-auditor`, which calls `edm-state record-partial-verdict <PREFIX> <ticket> PARTIAL …`. Two
auditors finishing close together each read the same `partial_verdict_map`, add their own ticket, and
write back — one verdict is permanently dropped from the QC record the HANDOFF and gate logic depend
on.

This **falsifies the SRD's stated guarantee** twice over:
- `srd.md:1124` — "Concurrent write: WS-J advisory lock in `write_state()` serializes; the second
  writer waits **rather than clobbering**." It clobbers.
- `srd.md:1049` — "All writes pass through `write_state()` … the single point where the WS-J
  advisory lock is added." The lock guards only the final overwrite, not the RMW.

### Evidence (file:line)
- `bin/edm-state:1346-1351` — `cmd_record_partial_verdict`: `current="$(read_state …)"` (no lock) →
  `jq` merge → `write_state` (lock here only).
- Same shape verified at: `cmd_set` (`:408-433`), `cmd_approve_gate` (`:525-536`), `cmd_phase_start`
  (`:546-554`), `cmd_phase_complete` (`:557-602`), `cmd_add_related` (`:1491-1500`),
  `cmd_audit_round_start` (`:1324-1329`).
- `write_state` (`:264-272`) is the **only** lock acquisition site.
- **Empirical proof (L3, reproduced)**: 8 concurrent `record-partial-verdict` calls each adding a
  distinct ticket key → only **1** survives; three trials of 10 concurrent calls → **1/10** survived
  each time. L8 independently reproduced 10 parallel `set` calls collapsing to 1 surviving key.
- **Verified by synthesizer**: confirmed `cmd_record_partial_verdict`, `cmd_set`, and
  `cmd_phase_complete` all read state outside the lock and that `write_state` is the sole locker.

### Fix (concrete)
Move the **entire** read-modify-write under one lock acquisition. The cleanest form is a locked RMW
wrapper that re-reads the file *inside* the lock and applies a jq filter to a temp file, then renames
(this also delivers G9's atomic write):

```bash
# _rmw_state_body <state-file> <jq-filter> [jq-args...]   (runs INSIDE with_state_lock)
_rmw_state_body() {
  local f="$1"; shift
  local filter="$1"; shift
  [[ -f "$f" ]] && cp -p "$f" "${f}.bak"          # T132 backup, preserved
  jq "$@" "$filter" "$f" > "${f}.tmp.$$" && mv -f "${f}.tmp.$$" "$f"   # atomic
}

# rmw_state <PREFIX> <jq-filter> [jq-args...]
rmw_state() {
  local prefix="$1"; shift
  local filter="$1"; shift
  local f lockbase
  f="$(state_file_for "$prefix")"; lockbase="${f%.json}"
  mkdir -p "$(dirname "$f")"
  with_state_lock "$lockbase" _rmw_state_body "$f" "$filter" "$@"
}
```

Convert each mutator from `read_state → jq(echo) → write_state` to a single `rmw_state "$prefix"
'<filter>' --arg … ` call. The invariant to enforce: **the read that feeds the merge occurs after the
lock is held.** Keep `read_state` for the read-only display commands (`get`, `list`, `metrics-report`,
`session-start`).

### Verification
- **Concurrency re-test (required):** rerun L3's harness — N concurrent
  `record-partial-verdict <PREFIX> TKT-$i PARTIAL` with distinct keys; assert
  `jq '.partial_verdict_map | length'` equals **N** (was 1/N). Repeat for concurrent `set` of
  distinct keys. Run on both the mkdir-lock host (macOS) and a flock host if available.
- Single-writer behavior unchanged: existing wave3/wave4a smoke tests still pass.

### Files
`plugins/edm-ai-development/bin/edm-state` (all mutators; add `rmw_state`/`_rmw_state_body`;
`write_state` may remain for the few whole-document replacements, or be reimplemented on the new
primitive).

---

## [G3] (P1, L3+L10): `checkpoint-if-active` bypasses the lock and the backup

### Problem
`cmd_checkpoint` is the only mutator that does **not** call `write_state`. It reads each state file
with `cat`, transforms with `jq`, and writes back with a **truncating** `printf '%s\n' "$new" >
"$state"` — **no `with_state_lock`, no `cp -p .bak`**. It fires from the `Stop` and `PreCompact`
hooks, which can trigger at any moment, including while a Phase-6 implementer or an auto-spawned QC
auditor is mid-write to the same file.

Two failure interleavings: (1) checkpoint's `cat` reads the file the writer is about to replace, the
writer writes, then checkpoint truncates and writes its stale `.last_updated`-only version — the
writer's update is lost; (2) the writer's locked write and checkpoint's unlocked truncate interleave
at the filesystem level → a torn/partial JSON file, and because checkpoint never made a `.bak`, no
clean prior copy is guaranteed. This both extends the G2 race to an unpredictable hook *and* defeats
the T132 backup it was supposed to benefit from. It also violates the SRD's own premise that "all
writes pass through `write_state()`" (`srd.md:1049`).

### Evidence (file:line)
- `bin/edm-state:632-636`:
  ```bash
  current="$(cat "$state")"
  new="$(echo "$current" | jq --arg t "$(now_utc)" '.last_updated = $t')"
  printf '%s\n' "$new" > "$state"          # no lock, no .bak, truncates in place
  ```
- Contrast `write_state` (`:264-272`) → `with_state_lock` → `_write_state_body` (the T132 backup).
- **Verified by synthesizer**: confirmed `cmd_checkpoint` performs the inline `cat`/`jq`/`printf >`
  and never calls `write_state`/`with_state_lock`.

### Fix (concrete)
Route the checkpoint's `last_updated` bump through the locked RMW primitive from G2, re-reading inside
the lock so it cannot clobber a concurrent update:

```bash
# inside the (G1-fixed) checkpoint loop, replace the cat/jq/printf with:
rmw_state "$prefix" '.last_updated = $t' --arg t "$(now_utc)"
```

Drift detection stays read-only (it only `echo`s warnings) and is unaffected. `write_handoff_internal`
already runs after the bump.

### Verification
- Concurrency re-test: run `checkpoint-if-active` in a tight loop concurrently with N
  `record-partial-verdict` calls; assert no verdict is lost and the file always parses as valid JSON.
- Confirm `.edm-state.json.bak` now appears after a checkpoint write (it did not before).

### Files
`plugins/edm-ai-development/bin/edm-state` (`cmd_checkpoint`).

---

## [G4] (P1, L1): `get-coverage` "Tests Added by Phase" filter always errors (exit 5)

### Problem
The final jq block in `cmd_get_coverage` builds a string (or comma-separated stream of strings) in its
`if/else`, then pipes the whole thing to `.[] // .`. `.[]` cannot iterate a string, so jq aborts with
`Cannot iterate over string` (exit 5) in **both** the empty and the populated case. The error is
swallowed by `2>/dev/null`, so the "Tests Added by Phase" section silently never appears **even when
`tests_added` data exists**, and `get-coverage` returns **exit 5** — which can break any caller that
checks its status.

### Evidence (file:line)
- `bin/edm-state:776-784` — the offending filter ends with `… | .[] // .`.
- **Verified empirically by synthesizer** against the live EDMV2 state:
  - `edm-state get-coverage EDMV2` → **exit 5** with no tests-added data.
  - After `record-tests-added EDMV2 6 unit 5` + `… integration 3` (`tests_added: 8`),
    `get-coverage EDMV2` → **still exit 5**, and the "Tests Added by Phase" section **never renders**.
  - Isolated filter repro: `… | .[] // .` over the built string → `jq: error … Cannot iterate over
    string`, exit 5.

### Fix (concrete)
Remove the trailing `| .[] // .`. The `if/else` already emits a stream of strings that `jq -r` prints
one per line. If the empty case should print nothing, return `empty` rather than `""`:

```jq
[.phase_durations | to_entries[] | {phase: .key, tests: .value.tests_added, by_layer: .value.tests_by_layer}]
| map(select(.tests != null and .tests > 0))
| if length == 0 then empty
  else
    "# Tests Added by Phase",
    (.[] | "  \(.phase): \(.tests) total  \(.by_layer // {} | to_entries | map("\(.key)=\(.value)") | join(", "))")
  end
```

Also drop the `2>/dev/null` on this specific jq (or keep it but ensure the command's overall exit code
is 0 on success) so a future filter error is visible rather than masked. Verify the command's final
exit status is 0 when coverage data is present.

### Verification
- `record-tests-added <P> 6 unit 5`; `get-coverage <P>` prints a "# Tests Added by Phase" block with
  `6_phase: 5 total  unit=5` **and exits 0**.
- `get-coverage <P>` on an initiative with no tests prints the "(no coverage …)" line and exits 0.

### Files
`plugins/edm-ai-development/bin/edm-state` (`cmd_get_coverage`).

---

## [G5] (P1, L9+L11): Duplicate/diverged `plugin.json` + dead mode config

This finding has **two parts**: (a) the validator/loader reads the wrong, key-incomplete manifest;
(b) three of the missing keys are dead config that nothing consumes even where present.

### Problem — part (a): wrong manifest
Both `plugins/edm-ai-development/plugin.json` (root) and
`plugins/edm-ai-development/.claude-plugin/plugin.json` exist. Per the Claude Code spec and this
repo's CLAUDE.md, **`.claude-plugin/plugin.json` is canonical** — and `claude plugin validate`
confirms it loads that file. But the canonical file defines only **`jira_mcp_namespace`** of the five
T129 keys; it is **missing `mode`, `compliance_enabled`, `qc_shard_threshold`, and
`implementation_mode`**. The root `plugin.json` has all five but is **not** the file the
validator/loader reads. Net user-facing effect: at `claude plugin upgrade`, the install-time prompt
will not surface those four keys, so the v2.0 features they configure cannot be set the documented
way. This breaks EDMV2-T22 AC1/AC2 ("exactly one authoritative manifest; no second copy can drift" —
they have drifted), T129 AC1/AC3-AC6, and T85 AC7.

### Problem — part (b): dead config
Even once surfaced, three of those keys are **never consumed** as new-initiative defaults — the
orchestrator sets them per-initiative interactively, so the install-time default is inert:
- `mode` — `edm-init` hardcodes `MODE="standard"` and only reads a `--mode` CLI flag; `edm-state init`
  hardcodes `mode: "standard"`; the orchestrator obtains mode from an `AskUserQuestion` and persists
  via `set-mode`. No `${user_config.mode}` / `CLAUDE_PLUGIN_OPTION_MODE` read exists.
- `implementation_mode` — hardcoded `"standard"` in `edm-state init`; orchestrator selects it via
  Phase-6 `AskUserQuestion`. No userConfig read.
- `compliance_enabled` — hardcoded `false`; orchestrator sets it via a toggle. No userConfig read.
  (This is the one most likely to matter operationally — a regulated-environment install would expect
  `compliance_enabled: true` to be sticky.)
- (`qc_shard_threshold` **is** referenced — `skills/implement/SKILL.md` reads
  `user_config.qc_shard_threshold` — so it is *not* dead config; it only needs to be present in the
  canonical manifest, which part (a) fixes.)

### Evidence (file:line)
- `claude plugin validate plugins/edm-ai-development` stdout: `Validating plugin manifest:
  …/.claude-plugin/plugin.json` (the loader's choice, verified live).
- `jq '.userConfig | keys' .claude-plugin/plugin.json` omits `mode`, `compliance_enabled`,
  `qc_shard_threshold`, `implementation_mode`; `jq … plugin.json` (root) has all 19 keys. **Verified
  by synthesizer** via a `diff` of the two key sets — exactly those four keys differ.
- The only `CLAUDE_PLUGIN_OPTION_*` vars read across all `bin/`: `SRD_ROOT`, `SRD_FILENAME`,
  `TICKET_PACK_DIRNAME`, `HUMAN_HOURLY_RATE_USD`, `COMMIT_STATE_FILE` (verified via grep). No
  `…_MODE`, `…_COMPLIANCE_ENABLED`, `…_IMPLEMENTATION_MODE`.
- `bin/edm-init:14` `MODE="standard"`; `bin/edm-state:473-476` hardcoded mode fields. **Verified.**
- `grep -rEn 'user_config\.(mode|implementation_mode|compliance_enabled)' skills agents bin` → nothing.

### Fix (concrete)
**Part (a) — collapse to one manifest.** Make `.claude-plugin/plugin.json` the single source of truth
containing the **full** key set, then remove the root `plugin.json` (or replace it with a symlink to
the canonical one if any tooling expects a root copy). Confirm `claude plugin validate` still passes
and `jq '.userConfig | keys'` on the loaded file now includes all five T129 keys.

**Part (b) — resolve the three dead keys.** For each of `mode`, `implementation_mode`,
`compliance_enabled`, pick one:
- **Wire them** (preferred for `compliance_enabled`): have `edm-init` read
  `CLAUDE_PLUGIN_OPTION_<KEY>` (defaulting to today's hardcoded value), thread it to `edm-state init`
  via an env var so the new initiative's state is seeded from the install default, and have the
  orchestrator **pre-select** that value as the default `AskUserQuestion` option.
- **Remove them** from `userConfig` (and their CLAUDE.md/CHANGELOG references) if per-initiative
  interactive selection is the intended sole mechanism — eliminating the dead config and the user's
  false expectation that the setting sticks.

Be consistent: do not leave a key in the manifest that nothing reads.

### Verification
- `claude plugin validate plugins/edm-ai-development` → passes; only the pre-existing CLAUDE.md-root
  advisory warning remains.
- `jq '.userConfig | keys' plugins/edm-ai-development/.claude-plugin/plugin.json` lists all five
  T129 keys (or the agreed reduced set if some are removed).
- Exactly one `plugin.json` on disk (or root is a symlink); no second copy can drift.
- If wired: set `CLAUDE_PLUGIN_OPTION_COMPLIANCE_ENABLED=true`, run `edm-init`, and confirm the new
  `.edm-state.json` has `compliance_enabled: true`.

### Files
`plugins/edm-ai-development/.claude-plugin/plugin.json`, `plugins/edm-ai-development/plugin.json`
(remove/symlink); if wiring: `bin/edm-init`, `bin/edm-state` (`cmd_init`),
`skills/orchestrator/SKILL.md`; doc sync in `CLAUDE.md` / `CHANGELOG.md`.

---

## [G6] (P1, L8): `mapfile` breaks `edm-lint-artifacts` on macOS bash 3.2

### Problem
`edm-lint-artifacts` collects markdown files with `mapfile -t MD_FILES`. `mapfile`/`readarray` are
**bash 4.0+** builtins. macOS ships `/bin/bash` **3.2.57** (Apple never shipped bash 4 due to GPLv3),
and `#!/usr/bin/env bash` resolves to that 3.2 on a stock host. Under `set -euo pipefail`, the failed
builtin aborts the script, so `edm-state lint <PREFIX>` (which delegates here) and — more importantly
— the **`PreToolUse: git commit` lint gate** are non-functional on the stated dev/primary platform.
The SRD makes macOS a **first-class supported platform** (C-3, `02-foundation-plumbing.md:36`), so a
hard break there is P1, not NOTED.

### Evidence (file:line)
- `bin/edm-lint-artifacts:60` — `mapfile -t MD_FILES < <( find … | sort )`.
- **Verified empirically by synthesizer** on the dev host: `bash --version` and `/bin/bash --version`
  both report `3.2.57(1)-release`. With `edm-state` on PATH and a resolvable initiative,
  `/bin/bash bin/edm-lint-artifacts LINTT` → `line 60: mapfile: command not found`. Minimal repro
  `/bin/bash -c 'mapfile -t X < <(printf "a\n")'` → `mapfile: command not found` (exit 127).
- `bin/edm-state` itself contains **no** bash-4 constructs and runs on 3.2 — the break is isolated to
  this one file. (Caveat for **G1**: do not introduce `local -A` associative arrays in the fix, for
  the same 3.2 reason.)

### Fix (concrete)
Replace `mapfile` with a 3.2-safe read loop:
```bash
MD_FILES=()
while IFS= read -r f; do MD_FILES+=("$f"); done < <(
  find "$INIT_DIR" -not -path '*/.git/*' -not -path '*/.archived/*' -name '*.md' 2>/dev/null | sort
)
```

### Verification
- `/bin/bash bin/edm-lint-artifacts <PREFIX>` runs to completion on macOS bash 3.2 (clean exit on a
  clean initiative; non-zero with `path:line: class:` output on a seeded violation).
- `edm-state lint <PREFIX>` works.
- Grep the whole plugin for other bash-4 builtins (`mapfile`, `readarray`, `${var^^}`, `${var,,}`,
  `local -A`, `declare -A`, `&>>`) before sign-off — confirm `edm-lint-artifacts:60` was the only one.

### Files
`plugins/edm-ai-development/bin/edm-lint-artifacts`.

---

## [G7] (P1, L8): Path-traversal arbitrary write via unvalidated `PREFIX`

### Problem
`edm-init` and `edm-validate-prefix` enforce `^[A-Z][A-Z0-9]{2,5}$`, but **`edm-state` accepts any
string as `PREFIX`** and interpolates it directly into the on-disk path via `state_file_for()` →
`write_state()`. `write_state` does `mkdir -p "$(dirname "$f")"` then writes, so `..` segments in
`PREFIX` walk out of `SRD_ROOT`. `init`, `set`, `srd-version`, `approve-gate`, `record-*`,
`current-step`, `set-mode`, `archive`, and `migrate-path` all reach this path. `PREFIX` frequently
arrives from LLM-generated or artifact-sourced text — the `UserPromptExpansion` hooks do
`prefix=$(echo "$ARGUMENTS" | awk '{print $1}')` and pass it straight to `edm-state`. The result is a
create/overwrite primitive on any `<dir>/.edm-state.json` the process can reach (the filename
component is fixed, so it cannot target arbitrary filenames — which bounds the blast radius and keeps
this P1 rather than P0; there is no command execution, `_write_state_body` uses quoted `cp`/`printf`).

### Evidence (file:line)
- `bin/edm-state:110-152` (`state_file_for`, `${prefix}` unsanitized), `:264-272` (`write_state`,
  `mkdir -p "$(dirname "$f")"` then write).
- **Verified empirically by synthesizer** (`EDM_SRD_ROOT=/tmp/l8test/SRD`):
  ```
  $ edm-state init '../escaped/INJECTED'
  initialized /tmp/l8test/SRD/../escaped/INJECTED/.edm-state.json
  $ ls /tmp/l8test/escaped/INJECTED/.edm-state.json        # OUTSIDE SRD_ROOT — present
  $ edm-state set '../escaped/INJECTED' attacker_controlled yes
  $ jq -r .attacker_controlled /tmp/l8test/escaped/INJECTED/.edm-state.json  ->  yes
  ```

### Fix (concrete)
Validate `PREFIX` once, centrally, at the top of the `edm-state` dispatcher (or in `state_file_for`),
so every subcommand inherits it. Reject anything that is not the canonical prefix format:
```bash
validate_prefix() {
  [[ "$1" =~ ^[A-Z][A-Z0-9]{2,5}$ ]] || die "invalid PREFIX '$1' (expected ^[A-Z][A-Z0-9]{2,5}$; no '/' or '..')"
}
```
Call it for every subcommand that takes a `<PREFIX>` argument. (Fold the **G12** product/description
sanitization into the same pass.)

### Verification
- `edm-state init '../escaped/X'` → `die` with the format error, exit non-zero, **no file written
  outside `SRD_ROOT`**.
- `edm-state set 'A/B' k v`, `edm-state init 'lower'`, `edm-state init '..'` → all rejected.
- Valid prefixes (`EDMV2`, `ABC`) still work end-to-end.

### Files
`plugins/edm-ai-development/bin/edm-state` (dispatcher and/or `state_file_for`; one shared
`validate_prefix`).

---

## [G8] (P2, L1): Misleading `0x` savings when human baseline is `$0`

### Problem
`human_cost_for_phase` returns `0` hours (cost `$0.00`) for any size other than Small/Medium/Large —
**including `"Unknown"`**. `edm-state init` writes `estimated_size: "Unknown"` literally, and
`cmd_phase_complete` reads `.estimated_size // "Medium"` — but because `"Unknown"` is a non-null
string, the `// "Medium"` default **never fires** (dead default). So `human_baseline_usd` is `0.00`
for every phase until a user manually `set`s a size. The metrics report then computes
`human/claude = 0/claude` and prints `0x` per phase and `Savings: 0x cheaper` in the total. `0x` reads
as "the AI saved nothing" — the inverse of the intended message; an honest report says `n/a`.

Note the **divisor** guard is already correct (`if estimated_cost_usd > 0 … else "n/a"`), which is why
phase 6 (zero claude cost) correctly shows `n/a`. The bug is the unguarded **zero numerator**.

### Evidence (file:line)
- `bin/edm-state:244` — `*) hours=0 ;;` (Unknown falls here).
- `bin/edm-state:581` — `size="$(echo "$current" | jq -r '.estimated_size // "Medium"')"` (dead default
  given init's `"Unknown"`).
- `bin/edm-state:938`, `:948-949` — savings expressions guard only `estimated_cost_usd > 0`.
- **Verified empirically by synthesizer** — `edm-state metrics-report EDMV2` against the live state
  (`estimated_size: "Unknown"`, all `human_baseline_usd: 0.00`) prints every phase row as `… $0.00 …
  0x …` and the total as `Human baseline: $0  |  Savings: 0x cheaper`.

### Fix (concrete)
Do at least one of:
- **(a)** In the savings expressions, treat a zero (or null) human baseline as `n/a` rather than
  rendering `0x`: `if ($claude > 0 and $human > 0) then ((…)|…)+"x" else "n/a" end`. (Apply in both
  the per-phase row and the total, and in the `--all` `Cost Ratio` column.)
- **(b)** Make the `"Unknown"`→baseline path explicit: have `cmd_phase_complete` map
  `"Unknown"`/empty → `"Medium"` before calling `human_cost_for_phase` (so the documented default
  actually applies), or default `human_cost_for_phase`'s `*)` arm to the Medium row.

(a) is the honest minimum; (b) additionally restores a meaningful baseline. The existing
`SIZE_UNKNOWN` state-anomaly already nudges users to set a size, so (a) + the anomaly is sufficient.

### Verification
- With `estimated_size: "Unknown"`, `metrics-report` shows `n/a` (not `0x`) in every Savings cell and
  the total.
- After `set estimated_size Medium`, the rows show a real `Nx` multiple.

### Files
`plugins/edm-ai-development/bin/edm-state` (`cmd_metrics_report` savings expressions; optionally
`cmd_phase_complete` / `human_cost_for_phase`).

---

## [G9] (P2, L3): No atomic write — truncate-in-place can leave a partial state file

### Problem
`_write_state_body` makes the backup then writes with shell redirection `> "$1"`, which truncates the
target first and streams the new content. A crash, `kill -9`, disk-full, or container OOM between
truncation and completion leaves `.edm-state.json` truncated/empty. T132's `cp -p .bak` mitigates
(the prior version survives) but there is no temp-file + `mv`, so the live file is never replaced
atomically, and there is no automatic restore-from-`.bak`.

### Evidence (file:line)
- `bin/edm-state:259-262` — `[[ -f "$1" ]] && cp -p "$1" "${1}.bak"; printf '%s\n' "$2" > "$1"`.
- **Verified by synthesizer** — confirmed the truncating redirect; L3 separately verified the `.bak`
  correctly holds the prior version (so T132 itself is fine — see Non-Findings).

### Fix (concrete)
Write to a temp file in the same directory and `mv` into place (rename is atomic on the same
filesystem). This is **delivered for free** by the G2 `_rmw_state_body` helper
(`jq … > "${f}.tmp.$$" && mv -f "${f}.tmp.$$" "$f"`). If `write_state` is retained for whole-document
replacement, apply the same temp+mv there:
```bash
_write_state_body() {
  [[ -f "$1" ]] && cp -p "$1" "${1}.bak"
  printf '%s\n' "$2" > "${1}.tmp.$$" && mv -f "${1}.tmp.$$" "$1"
}
```
Optionally add a `read_state` fallback that warns and offers `.bak` when the primary fails to parse.

### Verification
- Interrupt a write (e.g. inject a `kill` after the temp write but before `mv` in a test build);
  confirm `.edm-state.json` is either fully old or fully new, never truncated.
- Normal writes still produce a valid file and a `.bak` holding the prior version.

### Files
`plugins/edm-ai-development/bin/edm-state` (`_write_state_body` and/or the G2 `_rmw_state_body`).

---

## [G10] (P2, L1+L3): Validate numeric args before `jq --argjson`

### Problem
`cmd_set` validates numeric/boolean fields and emits a friendly `die`. But `cmd_record_test_coverage`
(`pct`), `cmd_record_tests_added` (`count`), and `cmd_approve_gate` (`gate`) feed the user value
straight into `--argjson` with no check. A non-numeric value yields a raw `jq: invalid JSON text
passed to --argjson` dump with no context. The crash occurs **before** `write_state`, so state is not
corrupted (verified — the file remains valid JSON), but the UX is inconsistent with `cmd_set`.

### Evidence (file:line)
- `bin/edm-state:699`, `:706` (`--argjson p "$pct"`), `:722` (`--argjson c "$count"`), `:532`
  (`--argjson g "$gate"`).
- L1/L3 reproduced: `record-test-coverage <P> unit N/A` → `jq: invalid JSON text passed to --argjson`;
  state file still valid afterward.

### Fix (concrete)
Add the same guard `cmd_set` uses before each `--argjson` of a user value:
```bash
[[ "$pct"   =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || die "record-test-coverage: pct must be numeric; got: $pct"
[[ "$count" =~ ^-?[0-9]+$ ]]            || die "record-tests-added: count must be an integer; got: $count"
[[ "$gate"  =~ ^[0-9]+$ ]]              || die "approve-gate: gate must be an integer; got: $gate"
```

### Verification
- `record-test-coverage <P> unit abc` → friendly `die`, exit non-zero, state untouched.
- Valid numeric values still record correctly.

### Files
`plugins/edm-ai-development/bin/edm-state` (`cmd_record_test_coverage`, `cmd_record_tests_added`,
`cmd_approve_gate`).

---

## [G11] (P2, L5): `.bak` / `.lock` sidecars are not gitignored

### Problem
`_write_state_body` runs `cp -p "$1" "${1}.bak"` before every write (19 `write_state` call sites), so
`SRD/{…}/.edm-state.json.bak` is (re)created on essentially every EDM operation — **inside the
committed tree, beside the file git tracks** — and is **never gitignored**. On flock hosts (Linux/CI)
`.edm-state.json.lock` is likewise created and never removed. The root `.gitignore` covers only
`.claude/`, `.serena/`, `.DS_Store`, `/.idea/`; `edm-init` writes a per-initiative `.gitignore`
excluding only `.edm-state.json`, and **only when `commit_state_file=false`** (not the default). Every
user on the default config gets permanent `?? …/.edm-state.json.bak` in `git status`, and a
directory-level `git add` can accidentally commit it.

### Evidence (file:line)
- `bin/edm-state:260` (`.bak`), `:294` (`.lock` on flock path, never `rm`'d).
- `bin/edm-init:116-119` — the only `.gitignore` EDM writes, non-default branch only.
- **Verified by synthesizer**: `git check-ignore -v SRD/EDMV2/.edm-state.json.bak` → exit 1 (not
  ignored); root `.gitignore` confirmed to contain nothing EDM-related.

### Fix (concrete)
Add a root-level rule (and document that EDM adopters add the same to their project root):
```gitignore
# EDM runtime sidecars — never commit (the .edm-state.json itself IS committed by design)
.edm-state.json.bak
.edm-state.json.lock
.edm-state.lockd/
```
And make `edm-init` emit these **unconditionally** into the per-initiative `.gitignore` (independent
of `commit_state_file`):
```bash
{
  echo ".edm-state.json.bak"
  echo ".edm-state.json.lock"
  echo ".edm-state.lockd/"
  [[ "$COMMIT_STATE" != "true" ]] && echo ".edm-state.json"
} > "$DIR/.gitignore"
```
(The `.lockd/` dir is already self-cleaning, but ignoring it is cheap insurance against `kill -9`
leftovers.)

### Verification
- After any `edm-state set`, `git status` shows **no** `.bak`/`.lock`/`.lockd` entries.
- `git check-ignore SRD/<P>/.edm-state.json.bak` → exit 0.
- `.edm-state.json` itself is still tracked under the default `commit_state_file=true`.

### Files
`/Users/darryl.porter/projects/marketplace/.gitignore`,
`plugins/edm-ai-development/bin/edm-init`.

---

## [G12] (P2, L3+L8): `migrate-path` — no rollback, unlocked write, unsanitized inputs

### Problem
`cmd_migrate_path` does `git mv`/`mv` of the whole initiative directory, then re-reads and rewrites
the moved state file with a **direct truncating write that bypasses `with_state_lock` and the T132
backup**. If the post-move `jq`/write fails under `set -euo pipefail`, the directory is relocated but
`product_name`/`initiative_description` are not updated — inconsistent on-disk state with no automatic
revert. A stale source `.edm-state.json.bak` is also carried into the destination. Separately,
`dst="${SRD_ROOT}/${product}/${prefix}__${description}"` interpolates **raw** `--product`/
`--description`; `..`/`/` in either escapes the product subtree (confinement bypass — `git mv`/`mv`
are correctly quoted, so **no command execution**, verified by L8).

### Evidence (file:line)
- `bin/edm-state:1059` (raw `dst`), `:1065-1081` (move then unlocked truncating write).
- L8 verified `--product 'p; touch …'` becomes a literal directory name (no exec); **synthesizer
  verified** `update-patterns`/migrate write paths and the unsanitized prefix path (G7).

### Fix (concrete)
- Route the post-move state update through the **G2 `rmw_state`** primitive (lock + backup + atomic
  write) instead of `printf > "$new_state_file"`.
- Sanitize inputs (folds into G7): `product`/`description` against `^[a-z0-9][a-z0-9-]*$`, reject
  `/`/`..`; validate `PREFIX` with the shared `validate_prefix`.
- Guard the operation so a failure after the move attempts to `git mv`/`mv` back (or stage the rewrite
  before committing the move). Remove/ignore the source `.bak` so it is not carried over.

### Verification
- `migrate-path --product '../x' …` and `--product 'a/b' …` → rejected, no directory created outside
  the product subtree.
- A normal `migrate-path` relocates the dir, updates `product_name`/`initiative_description` via the
  locked writer, leaves a `.bak`, and no stale source `.bak` rides along.
- Smoke coverage added (see G19 / L4-08).

### Files
`plugins/edm-ai-development/bin/edm-state` (`cmd_migrate_path`).

---

## [G13] (P2, L3): flock-timeout `exit 1` escapes only the subshell

### Problem
In the `flock` branch, the lock body runs in `( … ) 200>lockfile`. On timeout it runs `exit 1`, which
terminates only the **subshell**; under `set -e` the parent continues, so the mutating command can end
up having performed **no write** while the caller sees success-ish flow. The `mkdir` fallback handles
the same condition with `die` (hard process exit). The two lock backends therefore diverge on failure
semantics for the identical "could not acquire lock" case — and the divergence is host-dependent
(flock only exists on Linux).

### Evidence (file:line)
- `bin/edm-state:291-294` (subshell `exit 1`) vs `:303` (`die` in the mkdir branch). **Synthesizer
  read-confirmed** both branches in `with_state_lock`.

### Fix (concrete)
Propagate the subshell status and fail closed identically to the mkdir branch:
```bash
if command -v flock >/dev/null 2>&1; then
  ( flock -w 10 200 || exit 1; "$@" ) 200>"${lockfile}" \
    || die "edm-state: state lock timeout after 10s on ${lockfile}"
fi
```

### Verification
- On a flock host, hold the lock >10s from another process; the blocked command `die`s with a clear
  message and non-zero exit (not a silent no-op).
- macOS (mkdir) behavior unchanged.

### Files
`plugins/edm-ai-development/bin/edm-state` (`with_state_lock`).

---

## [G14] (P2, L2): `read_num()` is dead code

### Problem
`read_num()` (a JSON-number/numeric-string coercion helper added for EDMV2-T33 AC2) is fully
implemented but has **zero call sites**. Its twin `read_bool()` is consumed (archive gate,
`write_handoff_internal`); every numeric field is read with raw `jq` instead of routing through
`read_num`. The T33 Technical Notes kept it "for future WS-B/WS-E typed readers" that were never
wired. Unlike `record-task-duration` it carries **no** "reserved no-op" comment, so it reads as a
maintenance trap (future readers assume it is load-bearing).

### Evidence (file:line)
- `bin/edm-state:334` (comment), `:336` (definition). **Verified by synthesizer**:
  `grep -n 'read_num' bin/edm-state` returns only those two lines — no caller.

### Fix (concrete)
Two valid options:
- **Wire-up (preferred for symmetry with `read_bool`):** route the existing numeric reads
  (`current_phase` in `cmd_set`/`write_handoff_internal`, `current_step` in `cmd_current_step`)
  through `read_num` so legacy stringified-numeric fields coerce identically.
- **Delete:** remove lines 334-346 and add a one-line note to the T33 record that AC2's helper was
  removed as unused.

### Verification
- After wire-up: a state file with `current_phase: "3"` (string) and `current_phase: 3` (number) both
  behave identically. After delete: `grep read_num` returns nothing and all smoke tests pass.

### Files
`plugins/edm-ai-development/bin/edm-state`.

---

## [G15] (P2, L8): `update-patterns` writes to a possibly read-only plugin tree

### Problem
`cmd_update_patterns` resolves `patterns_dir="${script_dir}/../docs/audit-patterns"` from `$0` and
appends novel findings with `>> "$pattern_file"`. When the plugin is installed read-only (system path
or a managed `~/.claude/plugins`), the append fails — silent data loss for the pattern library. The
design assumes the plugin tree is writable, which is not true for the normal install location.

### Evidence (file:line)
- `bin/edm-state:1540-1541` (`patterns_dir` from `$0`), `:1617` (`>> "$pattern_file"`). **Synthesizer
  read-confirmed** the plugin-relative append target.

### Fix (concrete)
Detect a non-writable target and warn + skip (the function already has a "skipping" path for a missing
file), or relocate the pattern library to a writable project/`CLAUDE_PLUGIN_DATA` location:
```bash
if [[ ! -w "$patterns_dir" || ( -e "$pattern_file" && ! -w "$pattern_file" ) ]]; then
  echo "edm-state: pattern library not writable ($patterns_dir); skipping pattern update" >&2
  return 0
fi
```

### Verification
- `chmod -R a-w` the plugin's `docs/audit-patterns`, run `update-patterns` → clean warning + exit 0,
  no crash.
- Writable tree → patterns still append as before.

### Files
`plugins/edm-ai-development/bin/edm-state` (`cmd_update_patterns`).

---

## [G16] (P2, L6+L7): Documentation accuracy batch

### Problem
A cluster of doc-vs-code mismatches in the user-facing/contributor docs. None changes runtime
behavior, but all mislead a reader and several name nonexistent paths/features. Batched into one
docs-only commit:

1. **README artifact tree is the obsolete flat layout** (L6-02, the highest-impact doc issue) —
   `README.md:91-108` shows `SRD/{PREFIX}/`, not the canonical v2.0 `SRD/{PRODUCT}/{PREFIX}__{DESC}/`
   that `edm-init` creates; missing `explorers/`, `decisions.md`, `architecture.md`, `qc/`,
   `HANDOFF.md`. **Verified.**
2. **README `code-audit/` subdir name wrong** (L6-03) — shows `code-audit/{YYYY-MM-DD}/`; real layout
   is `code-audit/pass-{N}_{YYYY-MM-DD}/` (confirmed by `edm-state:1560` glob). Also omits
   `findings-ledger.md`. **Verified.**
3. **README claims "TaskCompleted records per-task durations"** (L6-04) — it is an explicit reserved
   no-op (CLAUDE.md/CHANGELOG correctly say "reserved"). Overstates capability.
4. **README dead link** (L6-07) — `README.md:139` links `../EDM_PLUGIN_REMEDIATION_PLAN.md`; file
   exists at neither `plugins/` nor repo root. **Verified.**
5. **CLAUDE.md `edm-state` subcommand list omits ~18 real subcommands** (L6-01, L6-08) — including
   `init`, `validate`, `gate-check`, `session-start`, `migrate-path`, `resolve-dir`, `current-step`,
   etc.; `set-mode` shown without its `<PREFIX> <kind> <value>` signature. Replace with a complete
   inventory or a pointer to the authoritative `bin/edm-state:4-39` usage header.
6. **CLAUDE.md `userConfig` reference lists only 5 of 18 keys** (L6-05) — omits the 13 added in
   v1.1-v2.0. Either complete it or replace with "plugin.json is the single source of truth; current
   keys: …".
7. **`PreToolUse: git commit` lint hook + `edm-lint-artifacts` script are undocumented** (L6-06) — a
   commit-blocking gate a contributor would not know exists. Add rows to the hooks and bin tables.
8. **`edm-test-coverage-auditor` `disallowedTools` doc contradicts code** (L7-02) — `CLAUDE.md:271`
   says `Write, Edit, NotebookEdit`; the agent allows Write (it must write `test-coverage.md`). Fix
   the doc to `Edit, NotebookEdit (Write required)`.

### Fix (concrete)
Edit the docs as above. For the subcommand/userConfig lists, prefer pointing at the single
authoritative source (the `edm-state` usage header; the `.claude-plugin/plugin.json` userConfig block
after G5) to avoid future drift.

### Verification
Re-grep each claim against code: README tree matches `edm-init` scaffold + `CLAUDE.md:45-86`;
`code-audit/pass-{N}_…` matches `edm-state:1560`; no dead links (`ls` the link target); every
dispatched subcommand appears in some CLAUDE.md table; userConfig list matches the canonical manifest;
hooks table includes `PreToolUse | git commit`.

### Files
`plugins/edm-ai-development/README.md`, `plugins/edm-ai-development/CLAUDE.md`.

---

## [G17] (P2, L7): NOTED severity level implemented three ways across auditors

### Problem
CLAUDE.md's "Severity vocabulary (canonical)" defines a four-level scale (P0/P1/P2/**NOTED**) and
states "No agent may define a divergent local scale." The read-only auditors diverge: the 11
`edm-audit-*` lenses implement NOTED fully (table row + `## Noted / Not Actionable` output section);
`edm-ticket-auditor` **names** NOTED but gives it no output home; `edm-srd-auditor` **drops it
entirely** (3-row severity table, no NOTED output section, description advertises only "(P0/P1/P2)").
The clearest violator is `edm-srd-auditor` — a 3-level table is exactly the "divergent local scale"
the doc forbids, and intentional/pre-existing items have nowhere to land (risk: mis-graded as P2 or
silently dropped).

### Evidence (file:line)
- `agents/edm-srd-auditor.md:4`, `:65-69` (3-row table), `:89-96` (no NOTED section).
- `agents/edm-ticket-auditor.md:73` (names NOTED), output skeleton has no NOTED home.
- Correct reference: `agents/edm-audit-logic.md:50`, `:64` (full implementation).

### Fix (concrete)
- `edm-srd-auditor.md`: add a NOTED row to the severity table, a `## Noted / Not Actionable` (or
  "Decisions / Non-Findings") section to the output skeleton, and update the description to
  "(P0/P1/P2 + NOTED)".
- `edm-ticket-auditor.md`: add a `## Noted / Not Actionable` section to its output skeleton.

### Verification
`grep -l 'Noted / Not Actionable' agents/edm-srd-auditor.md agents/edm-ticket-auditor.md` matches
both; severity tables in both are four-row.

### Files
`plugins/edm-ai-development/agents/edm-srd-auditor.md`,
`plugins/edm-ai-development/agents/edm-ticket-auditor.md`.

---

## [G18] (P2, L10): DRY hardening to prevent re-divergence

### Problem
Four capabilities are duplicated 2-5× in the bash scripts, and **two have already diverged** — the
duplication is not cosmetic, it is a live correctness hazard the next edit will re-trip:
- **Phase-number → display-name map** (L10-03) — `case` block in `cmd_session_start` (no `0)` arm) vs
  `write_handoff_internal` (has `0) "Not started"`); already inconsistent.
- **Gate↔phase map** (L10-04) — "gate 1→phase 1, 2→3, 3→5" re-encoded as literals in 5+ spots
  (`:964-967`, `:985`, `:1127-1130`, `:656/665`, `:1697-1699`); the compliance "Gate 3.5" work will
  require lockstep edits.
- **Coverage-table jq renderer** (L10-05) — duplicated in `get-coverage` vs `metrics-report` with
  **different padding widths** (already diverged); same data aligns differently per command.
- **Test-harness preamble** (L10-06) — `PASS/FAIL`/`pass`/`fail`/`check`/`check_absent` copy-pasted
  across the three smoke tests; wave4b re-implemented `check`/`check_absent` incompatibly.

### Fix (concrete)
- `phase_name <n>` shell helper (with the `0) Not started` arm), called from both `case` sites.
- Define the gate/phase topology once (`gated_phase_for_gate()` / `gate_for_command()` in bash; a
  single `def gated_phase_key` in the metrics jq, deriving the numeric form from it).
- A single coverage-table jq `def` / `render_coverage` shell function used by both commands; pick one
  padding scheme.
- `bin/tests/_harness.sh` defining the shared counters/asserts/`EDM_STATE` resolution; each smoke test
  `source`s it. (Test-only — the "skills are self-contained" rule does not apply.)

This **lands together with G1** (the `list_state_files` enumerator is the same refactor surface) so the
state-write path changes once. Keep all helpers bash-3.2-safe (no `local -A` — see G6).

### Verification
Behavior identical pre/post (smoke tests pass); HANDOFF, SessionStart, and metrics now render phase
names and coverage alignment from a single source.

### Files
`plugins/edm-ai-development/bin/edm-state`, `plugins/edm-ai-development/bin/tests/*.sh` (+ new
`_harness.sh`).

---

## [G19] (P2, L4): Test-quality fixes and the highest-risk coverage gaps

### Problem
- **False-positive-prone assertions** that pass even if the feature is deleted:
  - L4-01 — tautological `check_absent` for PASS-ticket exclusion (the section is jq-filtered to
    `verdict=="PARTIAL"`, so a PASS ticket can never appear regardless of code).
  - L4-02 — negative grep over a sliced region: `grep -A40 'mini-SRD Sub-Flow'` is empty if the
    heading is removed, so deleting the whole sub-flow makes the test pass.
  - L4-03/04/05 — `2>/dev/null` / `… 2>&1 || true` on the command under test lets a crash-to-empty
    read as success for the negative assertions (`session-start` phase-0 hidden; SIZE_UNKNOWN
    suppressed).
- **Zero smoke coverage** for state-mutating v2.0 paths: `migrate-path` (L4-08 — highest risk, FS move
  + state mutation; also exercises the G7/G12 sanitization), per-epic `record-test-coverage`
  (L4-06), `set-parent`/`add-related` (L4-07), and the `.bak` auto-backup mechanism (L4-09).

### Fix (concrete)
- Convert tautological/empty-region absence checks to positive/count assertions (e.g. assert the
  PARTIAL section *contains* the PARTIAL ticket and the entry count equals the number of PARTIAL
  verdicts; gate the mini-SRD negative check on a non-empty region first).
- For invalid-input rejections, assert non-zero exit alongside the substring; for the fast-track
  suppression, assert `validate` exits **0** (clean) before `check_absent SIZE_UNKNOWN`.
- Add smoke tests for `migrate-path` (flat→product move + field update + rejection of `..`),
  per-epic `record-test-coverage`/`get-coverage`, `set-parent`/`add-related` (validate-exists +
  idempotent append), and a `.bak`-appears-after-overwrite assertion.

These tests also serve as the regression net for G1/G2/G3/G4/G7/G12.

### Verification
New tests pass against the fixed code and **fail** against the pre-fix code (confirm they would have
caught the bug). Existing assertions still pass.

### Files
`plugins/edm-ai-development/bin/tests/wave3-smoke.sh`, `wave4a-smoke.sh`, `wave4b-smoke.sh` (+ a new
`wave5-smoke.sh` if grouping the new mutating-path coverage separately).

---

## [G20] (P3, L1): Phase label renders `1Phase` instead of `Phase 1`

### Problem & Evidence
`cmd_metrics_report`'s single-initiative per-phase table builds the label with `sub("_phase$"; "Phase
")`, which strips the suffix and appends `"Phase "`, leaving the digit in front: `"1_phase"` →
`"1Phase "`. **Verified live**: `metrics-report EDMV2` prints `1Phase`, `2Phase`, … (data is correct,
only the label is malformed). `bin/edm-state:938`.

### Fix
Prepend `"Phase "` to the number: `("Phase " + ($k | sub("_phase$";"")))`.

### Verification
`metrics-report <P>` shows `Phase 1`, `Phase 2`, … in the leftmost column.

### Files
`plugins/edm-ai-development/bin/edm-state` (`cmd_metrics_report`).

---

## [G21] (P3, L1): Pattern-library heading skip-list over-matches by prefix

### Problem & Evidence
`cmd_update_patterns` skips structural headings via `case` globs `summary*|findings*|
recommendations*|overview*|appendix*|legend*` — prefix matches, so a real finding titled e.g.
"Summary of auth bypass" is silently dropped from the pattern library. `bin/edm-state:1594-1596`.

### Fix
Anchor to whole-heading structural names (exact `summary|findings|…` or `summary|summary:*`), not any
title starting with the word.

### Verification
"Summary of auth bypass risk" is **kept**; a bare "Summary" heading is skipped.

### Files
`plugins/edm-ai-development/bin/edm-state` (`cmd_update_patterns`).

---

## [G22] (P3, L6+L7): Documentation nits

Batch with G16 (docs-only):
- L6-09 — `edm-test-contract.md:4` description says "OpenAPI/Swagger"; body + README include GraphQL.
  Change to "OpenAPI/Swagger/GraphQL".
- L6-10 — "Verified May 2026" pricing note (`CLAUDE.md:225`, `edm-state:193`) is one month stale; bump
  to the release month or drop the month (constants are correct).
- L6-11 — README `.edm-state.json` tree comment omits "mode fields" that CLAUDE.md lists.
- L6-12 — `archive` convergence gate (refuses on `code_audit_converged=false`) is undocumented; add a
  one-line note with its `prototype`/legacy bypasses.
- L7-03 — CLAUDE.md effort table is silent on `edm-architect` being `opus/max` (README documents it);
  add the exception note.
- L7-04 — `edm-audit-logic.md:55` severity one-liner omits "+ NOTED"; align with siblings.
- L7-05 — `edm-test-coverage-auditor.md` places `disallowedTools` 3rd; all 15 siblings place it last.
  Move it to the end.

### Files
`plugins/edm-ai-development/README.md`, `CLAUDE.md`, `agents/edm-test-contract.md`,
`agents/edm-audit-logic.md`, `agents/edm-test-coverage-auditor.md`.

---

## [G23] (P3, L11): Stale `edm-ai-development-staging/` paths in test comments

### Problem & Evidence
`bin/tests/wave3-smoke.sh:5` and `wave4a-smoke.sh:5` carry run-hint comments
`# Run from repo root: bash plugins/edm-ai-development-staging/bin/tests/…` — the staging dir no
longer exists post-cutover. Bodies are unaffected (they resolve their own location). `wave4b` is
clean.

### Fix
Replace `edm-ai-development-staging` with `edm-ai-development` in line 5 of both files.

### Files
`plugins/edm-ai-development/bin/tests/wave3-smoke.sh`, `wave4a-smoke.sh`.

---

## [G24] (P3, L5+L8+L10): Low-value cleanups

Bundle opportunistically; none blocks shipping. **Mostly subsumed by earlier fixes:**
- L5-03 — stale `.bak`/`.lock` can flip `cmd_archive`/`migrate-path` from `git mv` to plain `mv`,
  dragging sidecars into `.archived/`. **Resolved transitively by G11** (gitignored sidecars). Optional
  defense-in-depth: `rm -f` the sidecars before the move.
- L8-04 — flock FD 200 is a fixed high FD; prefer `exec {fd}>` dynamic allocation **or** keep 200 with
  a comment asserting exclusive ownership. (Note: dynamic FDs are bash-4 — keep the documented-200
  form on the 3.2 path. Hardening only.)
- L8-06 — `pgrep -x git | tr | xargs` in `git-lock-check`: the `xargs` trim is redundant given `tr`.
  Cosmetic.
- L10-07/08/09 — "seen-set" dedup loop (subsumed by G18/G1's enumerator), git-aware-move duplication
  (`git_aware_mv` helper), and the `[present]/[absent]` ternary repeated 9× (`present_or_absent`
  helper). All maintainability-only; fold in if touching those blocks.

### Files
`plugins/edm-ai-development/bin/edm-state`.

---

## Decisions / Non-Findings

Cleared false alarms and intentional behaviors. **Do not re-investigate** — each carries its rationale.

**Locking / backup primitives (verified correct):**
- **`flock` absent on macOS does NOT disable locking.** `with_state_lock` falls back to an atomic
  `mkdir` spin-lock (50 × 0.1s) with a PID file and `trap … EXIT INT TERM HUP` cleanup — SRD C-3 /
  EDMV2-T24 AC2/AC3. Verified live by L3 and L8 (writes serialize; `.lockd` cleaned up). The lost-update
  bug (G2) is a *where-the-lock-is-applied* defect, independent of backend; it reproduces on the mkdir
  path too.
- **T132 auto-backup (`.edm-state.json.bak`) is implemented correctly.** `cp -p` runs immediately
  before each write; the `.bak` holds the *prior* version and is not clobbered before the new write
  succeeds (L3 verified empirically across sequential writes). The gaps are atomicity (G9) and that
  `cmd_checkpoint` skips it (G3) — tracked there, not as a T132 defect.
- **mkdir-lock cleanup + trap, empty-`epic` arg handling, zero-token cost path, missing-PREFIX
  `die`** — all verified correct by L3. NOTED.

**Cost / metrics arithmetic (hand-verified by L1):**
- `compute_cost_usd` cost math; cache-write `ephemeral_5m`/`ephemeral_1h` split matching the real
  session JSONL; `fromdateiso8601` trailing-`Z` handling; `session_dir_for_cwd` `tr '/.' '-'` encoding
  (reproduces Claude Code's actual dir name incl. the `.`→`-` in `darryl.porter`); gate-review-seconds
  (Gate 1=2885s, Gate 2=15921s, Gate 3=4420s — re-verified live by the synthesizer). The `--all`
  `Cost Ratio` and single-initiative Savings **already** emit `n/a` for zero *divisor* (verified live);
  only the zero *numerator* is wrong (G8).
- `compute_cost_usd` `*sonnet*|*` catch-all prices unknown models at Sonnet rates — intentional safe
  default (rate-table comment). `--calibrate` median uses the upper-middle element for even counts — an
  accepted calibration heuristic. `group_by(.size + "_" + .phase)` underscore key cannot collide given
  constrained sizes + integer phase. Column-width `(15 - length | clamp)` parses correctly. All NOTED.

**Reserved / intentional no-ops:**
- **`record-task-duration` is a documented reserved no-op** (explicit comment + CLAUDE.md +
  CHANGELOG, satisfies EDMV2-T10). Not a stub masquerading as complete. NOTED. (Contrast `read_num`,
  G14, which has *no* such comment → kept as a finding.)
- **T134 (.pptx/.docx user docs)** — documented deferral (binary, needs Office tooling); both files
  unchanged on disk. NOTED, not a gap.

**Security / portability (verified by L8):**
- **`git mv`/`mv` in archive & migrate-path are NOT command-injectable** — all variables in command
  position are double-quoted; a `;`-bearing `--product` becomes a literal directory name (verified).
  The residual is path *confinement* (G12), not execution.
- **`jq --argjson` is not an injection surface** — `--argjson` parses a standalone JSON value, never
  interpolated into the filter; free-text uses `--arg` (stored verbatim). Verified.
- **`date` flags, `mktemp -d`, `sed` (stdin form), `grep -P` (probed with `LC_ALL=C` fallback), no
  `python3`, no `sed -i`/`readlink -f`/`stat`** — all POSIX-portable / guarded. NOTED. (The one genuine
  portability break is `mapfile`, G6.)
- **Env-var propagation** (`EDM_*_RATE`, `CLAUDE_PLUGIN_OPTION_*`, `EDM_PRODUCT`/`DESCRIPTION`) uses
  safe `${VAR:-default}`; `edm-init` correctly exports product/description for the child `init`. NOTED.

**Dead-code / reachability (verified by L2):**
- All 36 `cmd_*` functions are dispatched exactly once; every hook/monitor/skill-invoked subcommand
  exists; no code after unconditional exit; `EDM_STATE` "57 occurrences" was an uppercase-substring
  false positive (test-harness var + script-name substring). The only true dead code is `read_num`
  (G14). NOTED.

**Cross-file consistency (verified by L7):** no bare `Bash` in any skill; uniform skill frontmatter; no
legacy/divergent severity scale survives except the NOTED gap (G17); `jira_mcp_namespace` consistently
parameterized (literal default only as documentation); no Unicode emoji; model/effort/color/maxTurns
otherwise match CLAUDE.md+README; `tools:` lists byte-identical within role classes;
`${user_config.<key>}` spelled consistently. The `edm-qc-auditor` PASS/PARTIAL/FAIL verdict paradigm is
intentional/documented. NOTED.

**Spec/ticket compliance (verified by L9) — Should/Could features intentionally absent:**
- **L9-02 / EDMV2-T104 (multiple custom-prefix ticket packs)** — Should-priority, unimplemented;
  single-pack v1.x behavior unaffected. A missing *enhancement*, not a regression. Not promoted.
- **L9-03 / EDMV2-T105 (shared product `BASELINE.md`)** — Could-priority, unimplemented; absence is a
  clean no-op per the ticket's own AC3. Not promoted.
- **L9-04 / EDMV2-T110 (doc coverage)** — partial *only* because T104/T105 were not built; T110 AC6
  ("no advertised-but-absent feature") is satisfied by the omission. Downstream of L9-02/03, not an
  independent defect. Not promoted.
- **`claude plugin validate` CLAUDE.md-at-root warning** — generic Claude Code advisory, unrelated to
  any EDMV2 AC; T128 (exit 0) satisfied. NOTED.
- **Non-ASCII bytes in `bin/edm-state`/`bin/edm-init` source** — em-dashes/arrows appear only in `#`
  comments and `read -r` prompt prose, never in emitted artifacts (HANDOFF/drift/scaffold/archive all
  use ASCII `+--`/`(!)`/`->`/`[present]`); `edm-lint-artifacts` correctly scans only `*.md`. Not a
  T21/T114 violation. NOTED.

**Integration wiring (verified by L11):** every marketplace→disk path, skill→subcommand,
skill→agent, hook→command, monitor→command, and Jira MCP tool name resolves. `commit_state_file` IS
consumed (via `CLAUDE_PLUGIN_OPTION_COMMIT_STATE_FILE` in `edm-init:116`) — not dead config.
`coverage_target_*_pct` glob and `jira_mcp_namespace` default both resolve. Staging strings in
`SRD/EDMV2/**` are historical initiative artifacts, not wiring. NOTED.

**Runtime hygiene (verified by L5):** `.edm-state.json` is committed by design; `HANDOFF.md`,
`decisions.md`, `explorers/`, `code-audit/`, `architecture.md` are versioned deliverables;
`.edm-state.lockd/` self-cleans; `.git/index.lock` is only *removed* (never created);
`migrate-path` has no temp file to leak; hooks/monitors create no files; `edm-lint-artifacts` is
read-only. The actionable hygiene gap is the ungitignored `.bak`/`.lock` (G11). NOTED.

---

## Rollout Order

Fixes are grouped by **subsystem** so related edits land in one commit. All work is pre-deployment; nothing
is committed/pushed until the user asks. Branch off `main` first.

### Batch 1 — State-write path (the big one): G1 + G2 + G3 + G7 + G9 + G18 + G24(partial)
One commit touching `bin/edm-state`'s enumeration, locking, and write path. These are deeply
interdependent: G18's `list_state_files` enumerator *is* the G1 fix surface; G2's `rmw_state`/
`_rmw_state_body` primitive *is* the G9 atomic-write and the G3 checkpoint fix; G7's `validate_prefix`
guards every write entry. Doing them together avoids rewriting the same functions twice.
- Add `list_state_files`, `phase_name`, gate↔phase helpers, `rmw_state`/`_rmw_state_body`,
  `validate_prefix` (all **bash-3.2-safe** — no `local -A`).
- Convert all mutators to `rmw_state`; route `cmd_checkpoint` through it; fix the three flat-only globs.
- Keep `read_state` for read-only commands.
- Scope: `bin/edm-state`. Commit message scope: `edm-state` state-write path.

### Batch 2 — Portability + remaining edm-state logic: G6 + G4 + G8 + G10 + G13 + G14 + G15 + G20 + G21 + G24(rest)
- G6 (`mapfile`) is in `bin/edm-lint-artifacts` — **could be its own tiny commit** (isolated, P1, easy
  to verify), or ride with this batch. Recommend a **standalone G6 commit** first given it's a P1 on a
  separate file with a one-line fix.
- The rest are independent single-function edits in `bin/edm-state` (get-coverage filter, savings `n/a`,
  numeric guards, flock-timeout `die`, read_num decision, update-patterns writability, `Phase N` label,
  skip-list anchor, FD/xargs nits).
- Scope: `bin/edm-lint-artifacts` (G6 standalone), then `bin/edm-state`.

### Batch 3 — Manifest (standalone, deployment-critical): G5
- Collapse to one `.claude-plugin/plugin.json` with the full key set; remove/symlink root
  `plugin.json`; wire or remove the three dead mode keys; sync CLAUDE.md/CHANGELOG.
- Must be correct at upgrade time. Scope: `plugin.json` files (+ doc sync). Keep separate so a manifest
  revert doesn't drag code with it.

### Batch 4 — Hygiene: G11
- Root `.gitignore` + `edm-init` per-initiative `.gitignore`. Two files, no logic risk.
- Scope: repo `.gitignore` + `bin/edm-init`.

### Batch 5 — Tests: G19 + G18(test-harness part)
- New `_harness.sh`, de-tautologized assertions, new mutating-path coverage. Lands **after** Batches
  1-2 so the new tests assert the fixed behavior (and are confirmed to fail against pre-fix code).
- Scope: `bin/tests/`.

### Batch 6 — Docs + agents (no runtime impact): G16 + G17 + G22
- All Markdown/frontmatter. Can land anytime, but **after** G5 so the userConfig/subcommand docs
  reference the corrected manifest. G23 (stale staging comments) folds in here as a trivial test-comment
  edit.
- Scope: `README.md`, `CLAUDE.md`, `agents/*.md`, `bin/tests/*.sh` (comments only).

**Ordering rationale:** P1s first (Batches 1-3 + standalone G6); Batch 1 before Batch 5 (tests assert
fixed behavior); Batch 3 before Batch 6 (docs cite the fixed manifest). Batches 3/4/6 are independent of
Batch 1 and can proceed in parallel if multiple hands are available.

---

## Verification Plan

### 1. Syntax checks (every edited script)
```bash
bash -n plugins/edm-ai-development/bin/edm-state
bash -n plugins/edm-ai-development/bin/edm-init
bash -n plugins/edm-ai-development/bin/edm-lint-artifacts
bash -n plugins/edm-ai-development/bin/edm-validate-prefix
bash -n plugins/edm-ai-development/bin/tests/*.sh
# Guard against re-introducing bash-4 constructs (G6):
grep -nE 'mapfile|readarray|local -A|declare -A|\$\{[A-Za-z_]+\^\^?\}|\$\{[A-Za-z_]+,,?\}|&>>' \
  plugins/edm-ai-development/bin/*   # expect: no matches
```

### 2. The 3 smoke tests (run under the host's `/bin/bash` 3.2 to catch portability regressions)
```bash
/bin/bash plugins/edm-ai-development/bin/tests/wave3-smoke.sh
/bin/bash plugins/edm-ai-development/bin/tests/wave4a-smoke.sh
/bin/bash plugins/edm-ai-development/bin/tests/wave4b-smoke.sh
# plus the new mutating-path suite from G19:
/bin/bash plugins/edm-ai-development/bin/tests/wave5-smoke.sh   # if added
```

### 3. `claude plugin validate` (G5)
```bash
claude plugin validate plugins/edm-ai-development
# Expect: "Validation passed with warnings" with ONLY the pre-existing CLAUDE.md-root advisory.
jq '.userConfig | keys' plugins/edm-ai-development/.claude-plugin/plugin.json
# Expect: includes mode, compliance_enabled, qc_shard_threshold, implementation_mode (or the agreed
# reduced set if dead keys were removed). Exactly one plugin.json on disk (or root is a symlink).
```

### 4. Manual smoke steps (per-fix, in a scratch `EDM_SRD_ROOT`)
- **G1:** flat + product-scoped active initiatives; `active-initiatives`, `metrics-report --all`, and
  `checkpoint-if-active` all see **both** (diff `last_updated` on the product-scoped state pre/post
  checkpoint).
- **G4:** `record-tests-added <P> 6 unit 5` then `get-coverage <P>` → prints "# Tests Added by Phase"
  and **exits 0**.
- **G6:** `/bin/bash bin/edm-lint-artifacts <P>` runs to completion on bash 3.2.
- **G7:** `edm-state init '../escaped/X'` → `die`, no file outside `SRD_ROOT`.
- **G8:** `metrics-report <P>` with `estimated_size:"Unknown"` shows `n/a` (not `0x`).
- **G11:** after `edm-state set …`, `git status` shows no `.bak`/`.lock`/`.lockd`.
- **G20:** `metrics-report <P>` shows `Phase 1`, not `1Phase`.

### 5. Concurrency re-test (the lost-update fix — REQUIRED, G2 + G3)
Re-run the L3 harness against the fixed code; it must now survive **all** writers:
```bash
# N distinct verdicts written concurrently; expect length == N (was 1/N pre-fix)
P=CTEST; export EDM_SRD_ROOT=$(mktemp -d)/SRD
edm-state init "$P"
N=12
for i in $(seq 1 $N); do edm-state record-partial-verdict "$P" "TKT-$i" PARTIAL "n$i" & done; wait
test "$(edm-state get "$P" | jq '.partial_verdict_map | length')" -eq "$N" && echo PASS || echo FAIL
# Repeat for concurrent `set` of distinct keys, and for checkpoint-if-active looping concurrently
# with record-partial-verdict (assert no lost verdict AND the file always parses as valid JSON).
```
Run on the macOS mkdir-lock host and, if available, a flock (Linux) host — both must pass, and both
must show `.edm-state.json.bak` present after writes (G3/G9).
