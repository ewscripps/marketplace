# Lens L2: Dead Code & Unreachable Paths — Round 2 (2026-06-09)

## Summary

Two NEW findings, both **P2**, both confined to `bin/edm-state`. Neither blocks convergence (no P0/P1).

1. The G2 read-modify-write extraction left **`write_state` and its private helper `_write_state_body` as orphaned dead code** — every mutator was converted to `rmw_state`, no call site for `write_state` remains, and there is no "reserved" comment. This is the exact G14-class maintenance trap the round-2 mandate flagged ("orphaned old code left behind after extraction").
2. In `with_state_lock`'s flock branch, the **lock-timeout `die` message is unreachable under `set -e`**, and `return $_lock_ec` can only ever return `0`. The committed code diverged from the reviewed G13 fix (which used an errexit-safe `|| die`); the rewritten `( … ); _lock_ec=$?` form aborts the script at the subshell before the `die`/`return` lines can act on a non-zero status.

I also examined `bin/edm-init`, `bin/edm-lint-artifacts`, `bin/edm-validate-prefix`, and all four smoke tests (`wave3`, `wave4a`, `wave4b`, `wave5`): no dead code there. All 36 `cmd_*` functions are dispatched exactly once; every non-`cmd_` helper except the `write_state` pair has a live caller; `read_state` correctly survived as the read-only primitive (6 call sites).

## Findings

### [P2] `write_state` and `_write_state_body` are dead code after the G2 RMW extraction — `bin/edm-state`:293-306

**Evidence:** A word-boundary search for `write_state` (excluding `rmw_state`/`_rmw_state_body`) across the whole plugin returns only the definition and two comments — no call site:
```
bin/edm-state:291:# T132: backup + write body — called inside the advisory lock by write_state.
bin/edm-state:298:write_state() {
bin/edm-state:319:# Use instead of read_state/write_state for all mutating commands.
```
`_write_state_body` (line 293) has exactly one caller — `write_state` itself (line 305) — so it is transitively dead:
```bash
298  write_state() {
299    local prefix="$1"
300    local content="$2"
...
305    with_state_lock "$lockbase" _write_state_body "$f" "$content"
306  }
```
The G2 remediation converted every mutator to `rmw_state` (51 `rmw_state` call sites confirmed; `cmd_set`, `cmd_approve_gate`, `cmd_phase_complete`, `cmd_checkpoint`, etc.). The two paths that *don't* use `rmw_state` — `cmd_init` (line 522, `jq -n … > "$f"`) and `cmd_migrate_path` (line 1120, `printf … > tmp && mv`) — both write **directly**, not via `write_state`. The remediation plan kept `write_state` conditionally "for the few whole-document replacements" (REMEDIATION.md:220-222), but no such caller materialized. Contrast `read_state`, which legitimately survived with 6 live callers (lines 400, 448, 1163, 1218, 1281, 1353).

**Why it matters:** This is the same maintenance-trap class as round-1's G14 (`read_num`). `write_state` reads as the load-bearing "primary writer" by name, and `_write_state_body` carries the comment "called inside the advisory lock by write_state" — a future maintainer editing the write path would reasonably assume both are in use and route new code through them, when in fact the live write path is `rmw_state`/`_rmw_state_body`. Unlike `cmd_record_task_duration` (which carries an explicit "reserved no-op" comment, correctly NOTED), this pair has no such marker.

**Suggested fix:** Delete `write_state` (lines 298-306) and `_write_state_body` (lines 293-296), and the now-orphaned T132 comment block at 291-292. (Their backup + atomic-write behavior already lives in `_rmw_state_body` at lines 310-315.) If the team prefers to retain `write_state` as a deliberate whole-document-replacement primitive, add a one-line "reserved — no current caller; retained for whole-document replacement" comment so it is not read as live, and consider routing `cmd_init`/`cmd_migrate_path` through it to give it a caller.

### [P2] flock-branch lock-timeout `die` is unreachable under `set -e`; `return $_lock_ec` only ever returns 0 — `bin/edm-state`:348-351

**Evidence:** The script runs under `set -euo pipefail` (line 40). The flock branch:
```bash
344  if command -v flock >/dev/null 2>&1; then
...
347    local _lock_ec
348    ( flock -w 10 200 || exit 99; "$@" ) 200>"${lockfile}"
349    _lock_ec=$?
350    [[ $_lock_ec -eq 99 ]] && die "state lock timeout after 10s on ${lockfile} (another edm-state process may be holding it)"
351    return $_lock_ec
352  fi
```
Line 348 is a **standalone subshell command** — not part of an `if`/`while`/`until` test, not in a `&&`/`||` list, not negated with `!`. Under `errexit`, when that subshell exits non-zero (status `99` on lock timeout via `exit 99`, or the non-zero status of `"$@"`), the shell exits **immediately at line 348**. Execution never reaches line 349, so:
- Line 349 `_lock_ec=$?` runs only when the subshell succeeded → `_lock_ec` is always `0` when reached.
- Line 350's condition `[[ $_lock_ec -eq 99 ]]` is therefore **never true** — the `die` (the friendly "state lock timeout after 10s…" message) is **unreachable**.
- Line 351 `return $_lock_ec` can only return `0`.

I confirmed `errexit` is active in this context: no caller wraps `with_state_lock`/`write_state`/`rmw_state` in a condition or command substitution (grep for `(if|&&|\|\||!|while|until).*(rmw_state|write_state|with_state_lock)` and `$(rmw_state|…)` both return nothing), so nothing locally disables `-e`. The reviewed G13 fix in REMEDIATION.md:711-716 used the errexit-safe form `( … ) … || die "…"`; the committed code diverged to the `_lock_ec=$?` form, which reintroduces the very class of bug G13 set out to fix.

Net effect on a flock host (Linux/CI) when the 10s lock wait times out: the process **does** fail closed with a non-zero exit (so there is no silent no-op or lost write — G13's core safety property holds), but the exit code is **99** instead of `1`, and the intended human-readable message never prints. The mkdir fallback branch (lines 357-360) still `die`s correctly, so the two backends diverge on failure messaging — partially re-opening G13.

**Why it matters:** Environmentally unreachable error message: the operator on the platform where `flock` exists gets a bare exit-99 with no explanation, while the macOS mkdir path gives a clear `die`. It is P2, not P1, because the failure still propagates a non-zero status (no corruption, no clobbered write); only the diagnostic message and the unified exit semantics G13 promised are lost.

**Suggested fix:** Restore the errexit-safe form so the subshell's status is consumed by `||` (which exempts it from `set -e`):
```bash
if command -v flock >/dev/null 2>&1; then
  ( flock -w 10 200 || exit 99; "$@" ) 200>"${lockfile}" && return 0
  local _lock_ec=$?
  [[ $_lock_ec -eq 99 ]] && die "state lock timeout after 10s on ${lockfile} (another edm-state process may be holding it)"
  return "$_lock_ec"
fi
```
or, matching the reviewed G13 fix directly, `( … ) 200>"${lockfile}" || die "state lock timeout after 10s on ${lockfile}"`. Either makes the timeout `die` reachable and unifies failure semantics with the mkdir branch.

## Round-1 fix verification (L2)

**G14 (`read_num` dead code): CONFIRMED FIXED.** A search for `read_num` across the entire plugin returns **zero matches** — the helper was removed (the "delete" option from REMEDIATION.md:746-748), not merely commented. No "reserved" marker is needed since the function no longer exists. Its twin `read_bool` remains live (callers at `bin/edm-state`:844 in `cmd_archive` and :1677 in `write_handoff_internal`). No regression of G14 itself.

Note, however, the NEW finding above (`write_state`/`_write_state_body`) is a **G14-class regression introduced by a *different* round-1 fix** (G2's RMW extraction) — the same "orphaned-after-extraction dead helper with no reserved comment" pattern, just on a different symbol.

## Noted / Not Actionable

- **`cmd_checkpoint` drift-loop `*)` arm — `bin/edm-state`:708-710.** `case "$artifact_name" in … *)` is never reached in practice: `.artifact_hashes` is written only by `record_artifact_hash`, which is called only with `"srd"` (line 648) and `"tickets"` (line 651), so `$artifact_name` can only be one of those two. The `*)` arm is a forward-compatible default for a future third hashed artifact (e.g. `architecture.md`) and is idiomatic defensive `case` coding — not a maintenance trap. NOTED.
- **`human_cost_for_phase` `*)  hours=0` arm — `bin/edm-state`:278.** Reachable for any size other than Small/Medium/Large (e.g. the literal `"Unknown"` that `cmd_init` writes). This is the same path round-1 **G8** addressed at the *consumer* (savings now print `n/a`, not `0x`); the `*)` arm itself is a legitimate default, not dead. NOTED.
- **`compute_cost_usd` `*sonnet*|*` catch-all — `bin/edm-state`:251.** Intentional "price unknown models at Sonnet rates" safe default (rate-table comment); already cleared in round 1's Non-Findings. NOTED.
- **`state_file_for` AC6 product-only glob branch — `bin/edm-state`:177-182.** Reachable only when `EDM_PRODUCT` is set but `EDM_DESCRIPTION` is not and no on-disk match exists (the `edm-init` interactive-slug path can produce this env shape). A documented resolution tier (comment "AC6"), not dead. NOTED.
- **G18 test-harness (`_harness.sh`) was not created; each smoke test still defines its own `pass`/`fail`/`check`/`check_absent`.** This is an L10/DRY shortfall, not L2 dead code: every locally-defined helper in `wave3`/`wave4a`/`wave4b`/`wave5` has live call sites within its own file. Out of L2 mandate; flag to L10 if in scope. NOTED.

Relevant files: `plugins/edm-ai-development/bin/edm-state` (both findings), plus reviewed-clean `bin/edm-init`, `bin/edm-lint-artifacts`, `bin/edm-validate-prefix`, and `bin/tests/{wave3,wave4a,wave4b,wave5}-smoke.sh`.
