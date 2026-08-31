# Lens L3: Edge Cases & Concurrency

Audit of `plugins/edm-ai-development/bin/edm-state` (+ `edm-init`, `edm-validate-prefix`, `edm-lint-artifacts`) for race conditions, atomicity, lock correctness, empty/null inputs, and partial-failure states. EDMV2 v2.0.0 ("EDMV2"), 2026-06-08.

Critical runtime fact verified on this host: **`flock` is NOT installed** (`command -v flock` → not found). The `mkdir`-based fallback in `with_state_lock` is therefore the code path that actually executes on the macOS dev host and on any host without `util-linux`. All locking analysis below assumes the fallback path is live.

## Findings

| ID | Sev | File:Line | Issue |
|----|-----|-----------|-------|
| L3-01 | P1 | edm-state:408-433, 525-536, 1337-1352, 1483-1503, 557-602, 1090+ (all mutating cmds) | Read-modify-write done OUTSIDE the lock → lost updates under concurrency. Empirically 7 of 8 (and 9 of 10) concurrent writes to the same state file are silently dropped. |
| L3-02 | P1 | edm-state:621-636 (`cmd_checkpoint`) | The Stop/PreCompact checkpoint does `cat` + `jq` + truncating `printf > "$state"` with **no lock and no backup** — bypasses `write_state`/`with_state_lock` entirely. Concurrent with a Phase-6 writer it can clobber a just-written update or be interrupted mid-truncate, corrupting state with no `.bak`. |
| L3-03 | P2 | edm-state:259-262 (`_write_state_body`), 1081, 636 | State is written by truncating in place (`printf … > "$f"`), never via temp-file + atomic `mv`. A crash/SIGKILL between `cp -p .bak` and the completion of the redirect leaves a truncated/partial `.edm-state.json`. Backup limits the blast radius but recovery is manual. |
| L3-04 | P2 | edm-state:621-636 (`cmd_checkpoint`) glob `"$SRD_ROOT"/*/.edm-state.json` | Checkpoint hook only scans the **flat** layout. Product-scoped initiatives (`SRD/{PRODUCT}/{PREFIX}__*/`) are never checkpointed by Stop/PreCompact, so `last_updated`, drift detection, and HANDOFF refresh silently never fire for the canonical v2.0 layout. |
| L3-05 | P2 | edm-state:289-294 (`with_state_lock` flock branch) | When `flock` IS present, a lock-acquire timeout calls `exit 1` inside the `( … ) 200>lockfile` subshell, which only exits the subshell. With `set -e` the parent continues; the mutating command silently performs no write and the caller sees success-ish behavior depending on context. The mkdir branch correctly `die`s; the two branches diverge on timeout semantics. |
| L3-06 | P2 | edm-state:1064-1081 (`cmd_migrate_path`) | Multi-step mutation (`git mv` → `jq` rewrite → truncating write) with no rollback. If the `jq`/write step fails under `set -euo pipefail` after the move, the directory is relocated but `product_name`/`initiative_description` are not updated — and the post-move state write bypasses the lock. A stale `.edm-state.json.bak` from the source is also carried into the destination. |
| L3-07 | P3 | edm-state:691-713 (`cmd_record_test_coverage`), 715-730, 408-433 | Non-numeric numeric args reach `jq --argjson` and abort with a raw `jq: invalid JSON text passed to --argjson` (e.g. `record-test-coverage P unit abc`). No corruption (write never reached), but the error is unguarded and cryptic versus the validated `set`/`current-step` paths. |

---

### L3-01 — Read-modify-write outside the lock causes silent lost updates (P1)

**Problem.** Every mutating subcommand follows the pattern `current="$(read_state …)"` → `new="$(echo "$current" | jq …)"` → `write_state "$prefix" "$new"`. Only the final `write_state` acquires the advisory lock. The read and the in-memory merge happen *before* the lock, and `write_state` overwrites the **entire** file with the writer's stale snapshot. The lock serializes the truncating writes but does nothing to prevent each writer from basing its write on an out-of-date read — the classic lost-update / non-atomic RMW. This is the exact opposite of what the lock was added to do.

**Evidence (file:line + code).** `cmd_record_partial_verdict`, edm-state:1346-1351:
```bash
current="$(read_state "$prefix")"                 # READ — no lock held
new="$(echo "$current" | jq … '
  .partial_verdict_map[$tk] = {verdict: $v, …}
  | .last_updated = $ts ')"                        # MERGE onto stale snapshot
write_state "$prefix" "$new"                        # lock acquired only HERE; full-file overwrite
```
Same shape in `cmd_set` (411-433), `cmd_approve_gate` (529-536), `cmd_phase_start` (546-554), `cmd_phase_complete` (561-602), `cmd_add_related` (1491-1500), `cmd_audit_round_start` (1324-1329), `record_artifact_hash` (76-87), etc. `write_state` (264-272) is the *only* place the lock is taken:
```bash
write_state() { … with_state_lock "$lockbase" _write_state_body "$f" "$content"; }
```

**Empirical proof.** 8 concurrent `record-partial-verdict` calls, each adding a *distinct* ticket key, then 3 trials of 10 concurrent calls:
```
Launching 8 concurrent record-partial-verdict calls … Actual count: 1   (Keys present: TKT-06)
Trial 1: survived 1/10    Trial 2: survived 1/10    Trial 3: survived 1/10
```
7/8 and 9/10 verdicts are silently lost — last-writer-wins on the whole document.

**Trigger scenario.** Phase 6 runs MULTIPLE `edm-implementer` agents in parallel git worktrees, and the `SubagentStop` hook auto-spawns `edm-qc-auditor` which calls `edm-state record-partial-verdict <PREFIX> <ticket> PARTIAL …` (hooks.json `SubagentStop` step 6). Two auditors finishing close together each read the same `partial_verdict_map`, add their own ticket, and write back — one verdict is permanently dropped from the QC record the HANDOFF and gate logic depend on. `approve-gate`, `phase-complete`, and `record-tests-added` racing against a checkpoint exhibit the same loss.

**Fix.** Move the entire read-modify-write under one lock acquisition, not just the write. Either (a) refactor so a single locked critical section does `read → jq → write` (pass the prefix + a jq filter into a `with_state_lock` wrapper that re-reads inside the lock), or (b) make the jq transform read the file itself inside the lock: `with_state_lock "$lockbase" _rmw_state "$f" "$jq_filter" "$@"` where `_rmw_state` runs `jq … "$f" > "$f.tmp" && mv …`. The key invariant: the read that feeds the merge must occur after the lock is held.

**Severity rationale.** P1 (corruption / data-loss under concurrency per this lens's scale). It is the documented concurrency surface (Phase-6 parallel implementers + auto-QC), it is reproducible 100% of the time, it silently destroys committed QC verdicts and gate/phase records, and it directly falsifies the SRD's stated guarantee (§ "Concurrent write: … the second writer waits rather than clobbering", srd.md:1124, and "All writes pass through `write_state()` … the single point where the WS-J advisory lock is added", srd.md:1049). Not P0 only because it corrupts tracking/metadata rather than user source code, and the staging-copy mitigation (EDMV2-109) keeps the live plugin out of the blast radius.

---

### L3-02 — `checkpoint-if-active` bypasses the lock and the backup entirely (P1)

**Problem.** `cmd_checkpoint` does not call `write_state`. It reads each state file with `cat`, transforms with `jq`, and writes back with a truncating `printf '%s\n' "$new" > "$state"` — no `with_state_lock`, no `cp -p .bak`. It runs from the `Stop` and `PreCompact` hooks, which can fire at any moment, including while a Phase-6 implementer or an auto-spawned QC auditor is mid-write to the same file.

**Evidence (file:line + code).** edm-state:632-636:
```bash
current="$(cat "$state")"
new="$(echo "$current" | jq --arg t "$(now_utc)" '.last_updated = $t')"
printf '%s\n' "$new" > "$state"          # no lock, no .bak, truncates in place
```
Contrast with `write_state` (264-272) which routes through `with_state_lock` + `_write_state_body` (the T132 backup). `grep` confirms `cmd_checkpoint` is the only mutator that writes the canonical state file outside `write_state`.

**Trigger scenario.** During Phase 6, the user hits a Stop or a compaction triggers PreCompact → `edm-state checkpoint-if-active`. Simultaneously an `edm-implementer`/`edm-qc-auditor` runs `edm-state record-partial-verdict`. Interleavings: (1) checkpoint's `cat` reads the file the writer is about to replace, then the writer writes, then checkpoint truncates and writes its stale `.last_updated`-only version — the writer's update is lost; (2) the writer's locked write and checkpoint's unlocked truncate interleave at the filesystem level → a torn/partial JSON file, and because checkpoint never made a `.bak`, the prior good copy is whatever `write_state` last left (possibly already overwritten).

**Fix.** Route the checkpoint write through `write_state`/`with_state_lock` (or at minimum acquire the same per-file lock and write via temp-file + `mv`). Re-read inside the lock before applying the `.last_updated` bump so it cannot clobber a concurrent update.

**Severity rationale.** P1 — same data-loss/corruption class as L3-01, on a hook that fires unpredictably and frequently during the precise window (Phase 6) the SRD flags as the concurrency hotspot. It also defeats the T132 backup it was supposed to benefit from. Not P0 for the same reason as L3-01 (metadata, not source; staging-copy mitigation).

---

### L3-03 — No atomic write: truncate-in-place can leave a partial state file (P2)

**Problem.** `_write_state_body` makes the backup then writes with shell redirection `> "$1"`, which truncates the target first and streams the new content. A crash, `kill -9`, disk-full, or container OOM between truncation and completion leaves `.edm-state.json` truncated/empty. T132's `cp -p` backup mitigates this (the prior version survives in `.edm-state.json.bak`), but there is no temp-file + `mv` so the live file is never replaced atomically, and there is no automatic restore-from-`.bak` path.

**Evidence (file:line + code).** edm-state:259-262:
```bash
_write_state_body() {
  [[ -f "$1" ]] && cp -p "$1" "${1}.bak"     # backup OK (verified: holds prior version)
  printf '%s\n' "$2" > "$1"                    # truncate-in-place, not atomic
}
```
Verified backup correctness: after three sequential `set` calls, `.edm-state.json` = "third" and `.edm-state.json.bak` = "second" (the immediately-prior good copy). So **T132 is implemented correctly for the single-step case** — the file is genuinely backed up before each write and the backup is not clobbered before the new write succeeds. The gap is atomicity, not the backup.

**Trigger scenario.** Process killed (compaction timeout, user Ctrl-C twice, OOM) between the `cp` and the end of the `printf` redirect on a multi-KB state file. Next `read_state` either succeeds on a truncated-but-valid-prefix file (unlikely) or every subsequent `jq` parse fails with the file empty/half-written; recovery requires a human to notice `.bak` and copy it back.

**Fix.** Write to a temp file in the same directory and `mv` into place: `printf '%s\n' "$2" > "${1}.tmp.$$" && mv -f "${1}.tmp.$$" "$1"` (rename is atomic on the same filesystem). Keep the `cp -p .bak` before the rename. Optionally add a `read_state` fallback that warns and offers `.bak` when the primary fails to parse.

**Severity rationale.** P2 — requires an abnormal-termination window (narrower than the always-present L3-01/L3-02 races), and the existing `.bak` means data is recoverable rather than lost. Worth fixing because the fix is one line and the failure mode is total state-file corruption.

---

### L3-04 — Checkpoint hook ignores product-scoped layout (P2)

**Problem.** `cmd_checkpoint` globs only `"$SRD_ROOT"/*/.edm-state.json` — the flat layout. The canonical v2.0 layout is `SRD/{PRODUCT}/{PREFIX}__{DESCRIPTION}/.edm-state.json`, one level deeper. Those initiatives are never touched by the Stop/PreCompact hook, so their `last_updated` is never bumped, **artifact drift is never detected**, and HANDOFF is never refreshed on stop/compaction.

**Evidence (file:line + code).** edm-state:630 `for state in "$SRD_ROOT"/*/.edm-state.json; do`. Compare `cmd_session_start` (1268) and `cmd_list` (496-497), which correctly scan both `SRD/*/.edm-state.json` **and** `SRD/*/*/.edm-state.json`. The checkpoint loop was not updated for WS-M.

**Trigger scenario.** Any initiative created with `edm-init --product X --description Y` (the documented canonical path, e.g. `SRD/edm/EDMV2__enhance-edm-plugin/`). User edits the SRD after Gate 2, hits Stop → checkpoint runs but skips the directory, so the drift warning that should say "re-run /edm:audit-srd and re-approve Gate 2" never appears. Silent loss of a safety check.

**Fix.** Add `"$SRD_ROOT"/*/*/.edm-state.json` to the checkpoint glob (with the same de-dup the other commands use), or iterate the resolver. Combine with the L3-02 fix so both layouts get locked, backed-up checkpoints.

**Severity rationale.** P2 — not corruption, but a documented safety feature (drift detection / Gate re-approval prompt) silently no-ops for the layout the docs call canonical. Edge-case in that it only bites product-scoped initiatives, which is why it is not P1.

---

### L3-05 — flock timeout `exit 1` only escapes the subshell (P2)

**Problem.** In the `flock` branch, the lock body runs in a `( … ) 200>lockfile` subshell. On timeout it runs `exit 1`, which terminates only the subshell. Under `set -e` the parent shell's behavior on a failing command substitution/subshell in this position is inconsistent across contexts, and the mutating command may end up having performed no write while the surrounding command flow proceeds. The `mkdir` fallback branch handles the same condition with `die` (hard `exit 1` from the main shell), so the two lock implementations have different failure semantics for the identical "could not acquire lock" case.

**Evidence (file:line + code).** edm-state:291-294:
```bash
(
  flock -w 10 200 || { echo "… state lock timeout …" >&2; exit 1; }
  "$@"
) 200>"${lockfile}"
```
vs the fallback's `die "state lock timeout …"` at 303 (exits the whole process).

**Trigger scenario.** On a Linux host with `flock` present, a long-held lock (another `edm-state` blocked > 10s) makes the subshell exit 1; the calling skill/hook may treat the command as having run. Divergent from the macOS path, so behavior differs by host.

**Fix.** Propagate the subshell failure explicitly: capture the subshell exit status and `die`/`return` on non-zero, e.g. `( … ) 200>"$lockfile" || die "state lock timeout on $lockfile"`. Make both branches fail closed identically.

**Severity rationale.** P2 — host-dependent (only the flock path, which is *not* the dev host) and surfaces as a missed write + confusing success rather than corruption. Still a lock-correctness divergence worth normalizing.

---

### L3-06 — `migrate-path` is a multi-step mutation with no rollback and an unlocked write (P2)

**Problem.** `cmd_migrate_path` performs `git mv`/`mv` of the whole initiative directory, then re-reads and rewrites the moved state file with a **direct truncating write that bypasses `with_state_lock` and the T132 backup**. If the `jq` transform or the write fails (and `set -euo pipefail` will abort), the directory has already moved but `product_name`/`initiative_description` are not set, leaving an inconsistent on-disk state with no automatic revert. Additionally, any `.edm-state.json.bak` in the source is moved along, so the destination inherits a stale backup.

**Evidence (file:line + code).** edm-state:1065-1081:
```bash
git mv "$src" "$dst" 2>/dev/null || mv "$src" "$dst"   # step 1 (irreversible w/o rollback)
…
current="$(cat "$new_state_file")"
new="$(echo "$current" | jq … '.product_name=$p | .initiative_description=$d | .last_updated=$t')"
printf '%s\n' "$new" > "$new_state_file"               # step 2: no lock, no .bak
```

**Trigger scenario.** `edm-state migrate-path --product edm --description foo EDMV2` invoked while a Stop/checkpoint or another writer touches the file mid-migration, or where the post-move `jq` fails (malformed pre-existing state). Result: initiative relocated but state half-updated; resolver now finds it at the new path with missing product fields, and a concurrent checkpoint could write to the old or new path during the window.

**Fix.** (a) Route the post-move state update through `write_state` (lock + backup + the L3-03 atomic write). (b) Guard the whole operation so a failure after the move attempts to `git mv`/`mv` back, or stage the rewrite *before* committing the move. (c) Remove/ignore the source `.bak` so it is not carried over.

**Severity rationale.** P2 — `migrate-path` is explicitly opt-in and operator-invoked (not on a hot concurrent path), so the exposure window is small; but it is a multi-step mutation with no rollback that the prompt's mandate calls out, and it re-introduces the unlocked/unbacked write the rest of the file avoids.

---

### L3-07 — Numeric args crash `jq --argjson` ungracefully (P3)

**Problem.** `record-test-coverage`, `record-tests-added`, and the typed branch of `set` pass the user value straight to `jq --argjson`. A non-numeric value aborts jq with a raw parser error rather than a friendly `die`. No corruption occurs (the write is never reached), but the UX is inconsistent with the validated paths (`set current_phase`, `current-step`) that regex-check first.

**Evidence (file:line + code).** edm-state:699/706 (`--argjson p "$pct"`), 722 (`--argjson c "$count"`). Reproduced: `record-test-coverage T4 unit abc` → `jq: invalid JSON text passed to --argjson`. Compare `cmd_set` (423-426) which validates `current_phase`/`qc_shard_threshold` with `[[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]` before `--argjson`.

**Trigger scenario.** A skill or hook passes an empty or non-numeric percentage/count (e.g. a coverage tool emitting `N/A`). The command dies with a confusing jq error mid-flow.

**Fix.** Validate `pct`/`count` with the same numeric regex used in `cmd_set` before calling jq, and `die` with a clear message on mismatch.

**Severity rationale.** P3 — no data integrity impact (fails before write); purely a missing-input-guard / error-clarity nit on the edge of this lens's scope.

---

## Noted / Not Actionable

- **T132 auto-backup (`_write_state_body`, edm-state:259-262) is correctly implemented.** Per the mandate's instruction to verify rather than assume: the file is copied to `.edm-state.json.bak` (preserving perms via `cp -p`) immediately before each `write_state` redirect, and the backup is not clobbered before the new write succeeds. Verified empirically (`.json.bak` held the prior version after sequential writes). The only gaps are that it is single-step-only (does not help with the RMW races, L3-01/L3-02) and is not paired with an atomic rename (L3-03) — tracked there, not here. (NOTED for T132 itself.)

- **mkdir fallback lock cleanup + trap (edm-state:307-314).** The fallback writes its PID, sets `trap "rm -rf …" EXIT INT TERM HUP`, runs the command, removes the lockdir, and clears the trap. Verified no `.lockd` is left behind after normal completion. The trap correctly handles interrupt/termination during the critical section. Acquisition (`mkdir`) and release are atomic on local filesystems, as the comment states. This is a sound advisory-lock primitive — the defect is *where* it is applied (write-only), not the primitive (L3-01). NOTED.

- **Empty optional `epic` arg in `record-test-coverage` (edm-state:695-712).** Passing `""` as the 4th arg is handled correctly: the `[[ -n "$epic" ]]` guard routes an empty epic to whole-initiative `coverage_by_layer`, not a bogus `coverage_by_epic[""]` entry. Verified (stored under `coverage_by_layer`). Working as intended. NOTED.

- **Zero-token sessions / cost computation (`compute_cost_usd`, edm-state:225-227).** No division-by-zero risk: token counts are the numerator and the divisor is the constant `1000000`. `get_session_tokens_since` returns all-zero JSON when no sessions/usage exist (177-178, 190). `phase-complete` guards the whole token block behind `[[ -n "$started_at" ]]` (568). Zero tokens → `$0.0000`, no error. NOTED.

- **Missing PREFIX / nonexistent initiative.** `read_state` (249-254) `die`s with a clear "no state file for <PREFIX>" when the file is absent; arg-count guards (`[[ $# -eq N ]] || die`) precede every command. `set -euo pipefail` makes unset vars fail fast. These are consistent, intentional fail-fast patterns. NOTED.

- **Missing-`flock` does NOT silently disable locking.** On the macOS dev host (no flock, verified), `with_state_lock` falls through to the functioning mkdir spin-lock rather than no-op'ing. So writes are still serialized; the RMW lost-update (L3-01) is a logic issue independent of which lock backend is used (reproduced on the mkdir path). The macOS "no flock" concern raised in the prompt is therefore mitigated by design. NOTED.

- **`state_file_for` multi-match / ambiguous prefix (edm-state:125-132).** When >1 product-scoped dir matches a prefix it warns to stderr and uses the first — but global prefix uniqueness is enforced at creation by `edm-validate-prefix` (EDMV2-87, srd.md:1.0.5). Consistent project pattern; a best-effort guard, not a concurrency defect. NOTED.

- **`phase-complete` duration jq uses `if .started_at`.** In jq an empty string is truthy, so a stored `started_at:""` would reach `fromdateiso8601` and error. In practice `phase-start` always writes a valid timestamp and `// empty` (564) keeps the bash var clean; the field is never set to `""`. Theoretical only, not reachable via the documented flow. NOTED.
