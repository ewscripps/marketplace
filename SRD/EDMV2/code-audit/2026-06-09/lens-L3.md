# Lens L3: Edge Cases & Concurrency — Round 2 (2026-06-09)

## Summary

The Round-1 state-write rewrite is, on the whole, **solid**. The new `rmw_state` / `_rmw_state_body` primitive performs the entire read-modify-write **inside one lock acquisition** with temp-file + atomic `mv`, and I confirmed by reading every `rmw_state` call site that **all 30+ mutating commands now route through it** — the lost-update race (G2) and the atomic-write gap (G9) are genuinely closed. `cmd_checkpoint` (G3) now calls `rmw_state` instead of the old `cat→jq→printf>`.

**However, the most severe Round-1 concurrency finding for `migrate-path` (G12) has REGRESSED in one of its two sub-parts.** The post-move state write in `cmd_migrate_path` was reverted (or never converted) back to a **hand-rolled `cat → jq → printf > tmp && mv` that bypasses `with_state_lock` and the `.bak` backup** — re-introducing exactly the unlocked-write + no-rollback defect G12 was filed for. This is the headline finding of this pass. The input-sanitization half of G12 (and G7) did hold.

One lower-severity item: the flock branch's failure semantics are *fail-closed* (the process aborts under `set -e`), so the original G13 "silent no-op" P1 does **not** recur — but on a flock-host lock timeout the script aborts with exit **99 and no message** instead of the intended `die` (exit 1 + message), a cosmetic divergence from the mkdir branch.

## Findings

### [P1] `cmd_migrate_path` post-move state write bypasses the lock and the `.bak` backup (G12 partial regression) — `bin/edm-state:1114-1120`

**Evidence:**
```bash
  local new_state_file="${dst}/.edm-state.json"
  [[ -f "$new_state_file" ]] || die "migrate-path: state file not found after move: $new_state_file"
  local current new
  current="$(cat "$new_state_file")"
  new="$(echo "$current" | jq --arg p "$product" --arg d "$description" --arg t "$(now_utc)" '
    .product_name = $p | .initiative_description = $d | .last_updated = $t
  ')"
  # Write directly to the new path (state_file_for will now resolve it correctly).
  printf '%s\n' "$new" > "${new_state_file}.tmp.$$" && mv -f "${new_state_file}.tmp.$$" "$new_state_file"
```
This is the *exact* hand-rolled `cat → jq → printf > tmp && mv` shape that the G12 fix mandated be replaced by `rmw_state`. Every other mutator in the file calls `rmw_state "$prefix" '<filter>' --arg ...`; `migrate-path` is now the **sole** mutating command that does not. The G2 REMEDIATION explicitly says (lines 676-677): *"Route the post-move state update through the G2 `rmw_state` primitive (lock + backup + atomic write) instead of `printf > "$new_state_file"`."* That was not done.

**Why it matters:**
1. **No lock.** Although `migrate-path` is operator-initiated and less likely to race than the auto-spawned QC path, the `Stop`/`PreCompact` checkpoint hook fires on *any* assistant turn and calls `rmw_state` against the same initiative. The moment after `git mv`/`mv` relocates the directory, `state_file_for` resolves the **new** path for both this write and a concurrent `checkpoint-if-active`. A checkpoint landing between this `cat` (line 1115) and this `mv` (line 1120) will have its `last_updated` bump silently clobbered — the precise lost-update interleaving G2 eliminated everywhere else.
2. **No `.bak`.** `_rmw_state_body`/`_write_state_body` both do `cp -p "$f" "${f}.bak"` before writing; this path does not. The freshly-moved state file is written with **no backup**, so if the `jq` produces unexpected output or the `mv` is interrupted, there is no clean prior copy at the new location (the source `.bak`, if any, was carried along by `git mv` but is stale and not refreshed).
3. **No rollback on partial failure** (the other half of G12). Under `set -euo pipefail`, if the `jq` at line 1116 or the `cat` at line 1115 fails after the directory move at lines 1105-1109 succeeded, the process aborts with the directory **relocated but `product_name`/`initiative_description` not updated** — an inconsistent on-disk state with no automatic revert. The directory is now at the product-scoped path while state still claims the flat identity.

**Suggested fix:** Replace lines 1114-1120 with the locked primitive (which also restores the `.bak` and atomicity), and guard the move for rollback:
```bash
  local new_state_file="${dst}/.edm-state.json"
  [[ -f "$new_state_file" ]] || die "migrate-path: state file not found after move: $new_state_file"
  rm -f "${new_state_file}.bak"   # drop stale source-carried backup
  rmw_state "$prefix" \
    '.product_name = $p | .initiative_description = $d | .last_updated = $t' \
    --arg p "$product" --arg d "$description" --arg t "$(now_utc)"
```
`rmw_state` re-resolves the path via `state_file_for` (which now finds the product-scoped dir), takes the lock, makes the `.bak`, and writes atomically. For full G12 rollback coverage, wrap the move so a post-move failure attempts the reverse `mv "$dst" "$src"` (or stage the state rewrite before committing the directory move).

### [P2] flock-branch lock-timeout aborts with raw exit 99 and no message; diverges from the mkdir branch's `die` (G13 residual) — `bin/edm-state:347-351`

**Evidence:**
```bash
    local _lock_ec
    ( flock -w 10 200 || exit 99; "$@" ) 200>"${lockfile}"
    _lock_ec=$?
    [[ $_lock_ec -eq 99 ]] && die "state lock timeout after 10s on ${lockfile} ..."
    return $_lock_ec
```
The script runs under `set -euo pipefail` (line 40). The subshell `( ... ) 200>file` on line 348 is a **standalone compound command** — not part of a `&&`/`||` list, not an `if`/`while` condition, not negated. Under `errexit`, a standalone compound command that returns non-zero triggers an immediate shell exit *before* the next statement runs. So on lock timeout the subshell runs `exit 99`, line 348 returns 99, and `set -e` aborts the whole `edm-state` process **at line 348** — line 349 (`_lock_ec=$?`) and the line-350 `die` are **never reached**.

**Why it matters:** This is materially *better* than the original G13 bug — the process now **fails closed** (hard non-zero exit) on both backends rather than silently no-op'ing while the caller proceeds, so the P1 "lost write looks like success" condition does **not** recur. The residual is a cosmetic divergence: a flock-host timeout exits with code **99 and no diagnostic**, whereas the mkdir branch (line 360) prints a clear `die` message and exits **1**. A caller/operator on Linux sees a bare exit-99 with no explanation; on macOS they see the helpful message.

**Suggested fix:** Make the intent explicit and identical to the mkdir branch by testing the subshell so `errexit` is suppressed for it and the custom `die` always runs:
```bash
    local _lock_ec=0
    ( flock -w 10 200 || exit 99; "$@" ) 200>"${lockfile}" || _lock_ec=$?
    [[ $_lock_ec -eq 99 ]] && die "state lock timeout after 10s on ${lockfile} (another edm-state process may be holding it)"
    return $_lock_ec
```

### [P2] `cmd_init` creates the fresh state file with a non-atomic, unlocked `> "$f"` truncating write — `bin/edm-state:491-522`

**Evidence:**
```bash
  mkdir -p "$(dirname "$f")"
  ...
  jq -n --arg p "$prefix" ... '{ prefix: $p, current_phase: 0, ... }' > "$f"
  echo "initialized $f"
```
`cmd_init` writes the initial state with a direct `> "$f"` redirection — no `with_state_lock`, no temp-file + `mv`. It *is* guarded against clobbering an existing initiative by the early `[[ -f "$f" ]]` return at lines 481-484, so it will not overwrite a populated state file.

**Why it matters:** Lower severity than the migrate-path finding because (a) it only runs at initiative creation, (b) the existence guard prevents clobbering, and (c) a concurrent second `init` of the same prefix is an unusual operator error. But the write is **not atomic**: a `kill -9` / disk-full between the `jq -n` truncation-create and completion leaves a **zero-length or partial `.edm-state.json`**, and unlike every other write path there is no `.bak` and no temp+rename, so the next `read_state` would `die`/fail to parse with no recovery copy. There is also a TOCTOU window between the line-481 `[[ -f "$f" ]]` check and the line-522 write, though the practical blast radius is small.

**Suggested fix:** Write to a temp file and rename, mirroring `_write_state_body`:
```bash
  jq -n --arg p "$prefix" ... '{ ... }' > "${f}.tmp.$$" && mv -f "${f}.tmp.$$" "$f"
```

## Round-1 fix verification (L3)

| ID | Verdict | Evidence (file:line) |
|---|---|---|
| **G2** (lost-update RMW outside lock) | **CONFIRMED FIXED** | `rmw_state` (`:320-327`) acquires the lock then `_rmw_state_body` (`:310-315`) re-reads the file *inside* the lock, applies the jq filter, and atomically renames. I read every mutator — `cmd_set` (`:459/465/469`), `cmd_approve_gate` (`:570`), `cmd_phase_start` (`:582`), `cmd_phase_complete` (`:623`), `cmd_record_partial_verdict` (`:1368`), `cmd_record_test_coverage` (`:734/739`), `cmd_record_tests_added` (`:753`), `cmd_audit_round_start` (`:1350`), `cmd_set_mode` (`:1391/1398/1403/1410`), `cmd_skip_phase` (`:1428`), `cmd_add_related` (`:1494`), `cmd_set_parent` (`:1481`), `cmd_current_step` (`:1286/1288`), `cmd_update_patterns` (`:1629`), `record_artifact_hash` (`:116`) — **all** use `rmw_state`. No surviving lost-update on any mutating path. |
| **G3** (`checkpoint` bypassed lock/`.bak`) | **CONFIRMED FIXED** | `cmd_checkpoint:670` — `rmw_state "$prefix" '.last_updated = $t' --arg t "$(now_utc)"`. The old inline `cat`/`jq`/`printf >` is gone; drift detection (`:672-714`) is read-only. Loop driven by `list_state_files` (`:716`) so both layouts covered (G1). |
| **G9** (no atomic write) | **CONFIRMED FIXED** (for the locked path) | `_write_state_body:295` and `_rmw_state_body:314` both `... > "${f}.tmp.$$" && mv -f "${f}.tmp.$$" "$f"`. `.bak` (`cp -p`) precedes the write in both. **Caveat:** `cmd_init:522` and `cmd_migrate_path:1120` still bypass temp+rename/`.bak` — see P2/P1 findings (migrate-path is the regression). |
| **G10** (numeric args → raw `jq --argjson` crash) | **CONFIRMED FIXED** | `cmd_approve_gate:568` `[[ "$gate" =~ ^[0-9]+$ ]] \|\| die`; `cmd_record_test_coverage:731` `[[ "$pct" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] \|\| die`; `cmd_record_tests_added:750` `[[ "$count" =~ ^[0-9]+$ ]] \|\| die`. |
| **G12** (`migrate-path`: no rollback, unlocked write, unsanitized inputs) | **PARTIAL / REGRESSED** | **Sanitization HELD:** `:1090-1091` validate `--product`/`--description` against `^[A-Za-z0-9_-]+$`; `state_file_for:145` validates PREFIX. **Lock/backup/rollback REGRESSED:** `:1114-1120` is back to the hand-rolled write with no `with_state_lock`, no `.bak`, no move-rollback. See P1 finding. |
| **G13** (flock-timeout `exit 1` escaped only the subshell → silent no-op) | **CONFIRMED FIXED (core) / cosmetic residual** | P1 core defect does not recur (fail-closed on both backends). Residual: flock-host abort carries exit 99 with no message rather than `die` exit 1. See P2 finding. |

## Noted / Not Actionable

- **No lock re-entrancy / deadlock.** `cmd_phase_complete` calls `rmw_state` (`:623`) then `record_artifact_hash` (`:648/651`) which itself calls `rmw_state` (`:116`) — sequential, not nested; each acquires/releases independently. NOTED.
- **`write_handoff_internal` writes HANDOFF.md, not the state file** — its lock-free `cat`/`jq` reads and final `} > "$handoff_path"` are correct by design (derived single-writer-per-turn artifact). NOTED.
- **Empty-array `set -u` expansions are bash-3.2 safe** — all `${arr[@]}` over possibly-empty arrays use `"${arr[@]+"${arr[@]}"}"` (`:64`, `:541`, `:1311`); `_calib_files` guarded by count check at `:927`. NOTED.
- **`record-test-coverage`/`record-tests-added` count math is concurrency-safe** now inside `rmw_state` (recomputed from totals inside the lock). NOTED.
- **`cmd_record_task_duration` reserved no-op** (`:719-724`) — documented; `TaskCompleted` hook wraps `|| true`. NOTED.
- **`watch-impl` infinite `while true`** (`:882-890`) — a monitor by design (5s poll), not a request-scoped call. NOTED.
- **SubagentStop is a `prompt` hook** — concurrent QC auditors are separate processes; lost-update safety delegated to `rmw_state` (verified under G2). Checkpoint hooks wrap `|| true` (appropriate best-effort; writes themselves locked + atomic). NOTED.
