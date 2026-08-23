# Lens L3: Edge Cases & Concurrency -- Pass 3 (2026-08-08)

Scope audited: `plugins/edm/bin/` (all scripts incl. `_edm-cli-lib.sh`, `_edm-lint-lib.sh`, `bin/tests/`), `agents/`, `skills/`, `evals/`, `hooks/hooks.json`, `docs/`, `monitors/`, plus repo-root `CLAUDE.md`, `.gitlab-ci.yml`, `.gitignore`.

## Part 1: Verdicts on L3-tagged open ledger entries

| ID | Verdict | Evidence |
|---|---|---|
| CA-011 (L1+L3+L6) | **L3 half FIXED** | `hooks/hooks.json:86` now runs `edm-state resolve-dir "$p" >/dev/null 2>&1 || continue` before linting, so a staged initiative deletion is skipped rather than blocking a clean commit; and it no longer branches on any non-zero -- lint exit 1 sets `fail=2` (blocks), lint exit 2 prints and does not block. Non-L3 residue (exit-code doc semantics) belongs to L1/L6. New adjacent defect raised as **L3-005**. |
| CA-025 (L3) | **FIXED** | `bin/edm-state:1044-1045` now runs the mkdir-branch body in a subshell (`_EDM_TRAP_DEPTH=1; ( "$@" )`), matching the flock branch, with the divergence rationale documented at `:1037-1043`. Note this fix is the direct cause of **L3-001**. |
| CA-026 (L3) | **FIXED (both halves)** | Per-initiative body isolated at `bin/edm-state:1977-2022` (`( ... ) || echo "edm-state checkpoint: [warn] skipping ${prefix}: exit $?" >&2`), so a `die`/jq crash skips one initiative, not the rest of the sweep. Prefix-vs-directory mismatch guard at `:1961-1970` refuses to mutate when `state_file_for "$prefix" != "$state"`, closing the stray-`SRD/<other>/` creation. |
| CA-056 (L3) | **FIXED** | `pattern_insert_line_for` at `bin/edm-state:3935-3970` filters `grep -nFx` hits through `ignored_line_set`/`is_ignored_line` and **dies** rather than guessing when the heading occurs more than once outside fences (`:3948-3950`). The pre-flight duplicate scan at `:4001-4011` is fence-filtered the same way. First-match-wins into a fenced example is no longer reachable. |
| CA-058 (L3) | **FIXED** | Both line sets now ride through a temp file: `MERMAID_SCAN_FILE` created at `bin/edm-lint-artifacts:129`, staged at `:163-167`, read by awk via `-v scan_file=` + `getline` at `:220-229`. No `EDM_MERMAID_SET`/`EDM_MARKER_SET` env var remains, so the E2BIG path is gone. The `|| true` consumer is replaced by a captured status at `:399-404` that reports a `scan-error` violation at line 0. |
| CA-059 (L3) | **FIXED** | `_cmd_record_partial_verdict_close_body` (`bin/edm-state:3585-3639`) performs the read, the already-closed decision, and the write inside the single `with_state_lock` acquisition at `:3659`. It calls `_rmw_state_body` directly (not `rmw_state`) to avoid re-acquiring, documented at `:3580-3584`. Two concurrent closes can no longer both take the first-closure branch. |
| CA-061 (L3) | **PARTIALLY FIXED** | The idempotence pre-check landed at `bin/edm-state:1356-1359` (read-only `already` probe, `return 0` on a match), so repeat hook invocations no longer take the write lock. But the **first** invocation for a legacy initiative still calls `rmw_state` (`:1360`), and on a read-only checkout the failure mode is now *worse* than the original `cp -p` abort: `with_state_lock`'s `until mkdir "$lockdir" 2>/dev/null` (`:965`) spins 50 x 0.1 s and then reports a **lock timeout** for an EROFS/EACCES condition. Help text at `:32` still claims `gate-check ... (read-only)`. Raised as **L3-004**. |
| CA-064 (L3) | **PARTIALLY FIXED** | `evals/score-artifacts.sh:532-533` now coerces an unparseable or malformed `complete` to `"false"`. But the **absent-`run.json`** branch at `:538` still hardcodes `complete="true"`. An absent manifest is at least as unknown as an unparseable one. Raised as **L3-007**. |
| CA-133 (L1+L3) | **FIXED** | `bin/edm-state:4024` appends `$'\n'` after the command substitution (`pending_entries="${pending_entries}$(_render_pattern_entry ...)"$'\n'`), restoring the newline `$( )` strips. Verified by trace: each entry is `\n### T (...)\n\n...\n> ...prose.\n`, so the blank line before every subsequent `###` survives and `_splice_pattern_file`'s `printf '%s'` (`:3988`) no longer concatenates the last entry onto the line at `insert_line`. |
| CA-141 (L3) | **PARTIALLY FIXED** | Fixed: the `kill -0`-dead path is atomic via `mv "$lockdir" "${lockdir}.stale.$$"` (`:984-988`); EPERM is distinguished from ESRCH by error text (`:978-982`); both reclaim paths now increment `tries` (`:992`) so the "50 tries" bound is real. **Not fixed:** the invalid-PID branch at `:971` still does a bare, non-atomic `rm -rf "$lockdir"` -- the exact TOCTOU the finding named. Raised as **L3-003**. |
| CA-142 (L3) | **NOT FIXED (mechanism is inert)** | The `_EDM_CLEANUP_PATHS` shared list added at `:512-537` cannot work: `with_state_lock` sets `_EDM_TRAP_DEPTH=1` and then forks `( "$@" )` at `:1045`, so `write_atomic`'s `_edm_cleanup_push "$tmp"` (`:557`) mutates the **subshell's** copy while the draining trap (`:1025-1028`) runs in the **parent**. Raised as **L3-001**. |
| CA-143 (L3) | **PARTIALLY FIXED** | Fixed in the parent shell: the lock's INT/TERM/HUP arms now `exit 130/143/129` (`:1026-1028`) and the EXIT arm is cleanup-only; non-nested `write_atomic` does the same (`:576-578`). **Not fixed inside the critical section:** bash resets inherited traps in a `( )` subshell, and `write_atomic` takes the `nested=1` no-trap path there, so during the actual read-modify-write there is no INT/TERM/HUP handler at all. Folded into **L3-001**. |
| CA-144 (L3) | **FIXED** | `bin/_edm-lint-lib.sh:118-131`: `is_open`/`is_close` are computed unconditionally *before* the `ignore_next` short-circuit, and the `ignore_next` branch calls `apply_fence_open`/`apply_fence_close` before its `next`. Traced: marker on line N, fence opener on N+1 -> opener is emitted as ignored+marker **and** `in_fence` becomes 1, so the closer is no longer mis-parsed as an opener. Suppression inversion is closed. |
| CA-027 (L3) | **FIXED (both halves)** | Lock: `write_handoff_internal` wraps the whole read-render-write in `with_state_lock "${state_file%.json}"` (`:4151`), same lockbase as state mutations. Notes filter: `:4371` is `awk '/^## Notes/{p=1;next} p{print}'` -- captures verbatim to EOF (no truncation at the first user `## `), the blank-line-deleting `grep -v '^[[:space:]]*$'` is gone (rationale at `:4360-4367`), and `:4376` strips exactly one leading blank so the render/read cycle is fixed-point (verified stable, no per-checkpoint growth). |
| CA-063 (L3, marked fixed) | **CONFIRMED FIXED, with a new gap** | `.gitlab-ci.yml:583` declares `timeout: 150m` (9000 s) against 3 x `EDM_EVAL_PHASE_TIMEOUT_SECONDS=2700` (8100 s), leaving ~15 min of headroom. However that headroom is consumed by an **untimed** network call -- raised as **L3-009**. |

## Findings (L3: Edge Cases & Concurrency)

### L3-001 -- P1 -- `_EDM_CLEANUP_PATHS` is pushed in a subshell the draining trap can never see; the mkdir-branch critical section has no signal handler at all
`plugins/edm/bin/edm-state:1044-1045`, `:555-557`, `:1025-1028`, `:512-537`

The CA-025 remediation (subshell the mkdir-branch body) and the CA-142/CA-143 remediation (a shared cleanup-path list drained by the one outer trap) landed in the same wave and are mutually incompatible.

```bash
    _EDM_TRAP_DEPTH=1
    ( "$@" )                      # :1045  -- fork
    local ec=$?
```
and, in `write_atomic`:
```bash
  if [[ "${_EDM_TRAP_DEPTH:-0}" -ge 1 ]]; then
    nested=1
    _edm_cleanup_push "$tmp"      # :557  -- runs INSIDE the subshell
  else
    ... trap ... EXIT INT TERM HUP
  fi
```

Two consequences, both of them the failure modes CA-142/CA-143 were filed against:

1. Bash documents that "commands grouped with parentheses ... are invoked in a subshell environment that is a duplicate of the shell environment, **except that traps caught by the shell are reset** to the values that the shell inherited from its parent at invocation." So inside `( "$@" )` the four traps installed at `:1025-1028` are **not active**, and `write_atomic` deliberately installs none (`nested=1`). During the entire locked write there is zero signal coverage.
2. `_edm_cleanup_push` appends to the subshell's private copy of `_EDM_CLEANUP_PATHS`. The parent's array is never modified, so `_edm_cleanup_paths_run` in the lock's trap (`:1025-1028`) always drains an **empty** list. `_edm_cleanup_pop` (`:522-528`) is equally futile. Every line of `:512-537` is dead code in the only configuration it was written for.

**Trigger.** On macOS -- where `command -v flock` fails and this is the *only* branch taken -- run any state mutation (`edm-state phase-complete`, `approve-gate`, `checkpoint-if-active`, `write-handoff`, `update-patterns`) and Ctrl-C during the jq render. The parent's INT trap removes the lockdir and exits 130 (correct), but `${dest}.tmp.XXXXXX` is left behind in the tracked initiative directory because the parent's drain list is empty. The flock branch (`:944`) never sets `_EDM_TRAP_DEPTH`, so `write_atomic` there installs real traps and *does* clean up -- an undocumented platform asymmetry in which the primary development platform is the unprotected one.

**Fix.** Do not communicate cleanup state across a fork. Either (a) drop the `nested` path entirely and let `write_atomic` save/restore its own trap layer inside the subshell -- the subshell's reset traps mean this is depth one, not depth two, so the `bin/tests/_harness.sh:49-50` constraint the comment at `:503-511` cites does not actually apply here; or (b) stop subshelling the mkdir-branch body (revert CA-025 and document the flock/mkdir divergence instead). Option (a) is smaller and keeps CA-025. Whichever is chosen, delete or re-justify `_EDM_CLEANUP_PATHS`, `_edm_cleanup_push`, `_edm_cleanup_pop`, `_edm_cleanup_paths_run` and the comment block at `:503-511`, which all currently document behaviour that does not occur.

### L3-002 -- P1 -- `run-eval.sh --out DIR` retention `rm -rf`s arbitrary sibling directories in a user-supplied path, and counts a different set than it prunes
`plugins/edm/evals/run-eval.sh:553-571` (with `--out` documented at `:17`, `:78-80`)

```bash
run_total="$(find "$OUT_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
if [ "$run_total" -gt "$EDM_EVAL_KEEP_RUNS" ]; then
  stale_dirs="$(ls -1t "$OUT_ROOT" | tail -n "+$((EDM_EVAL_KEEP_RUNS + 1))")"
  ...
      rm -rf "${OUT_ROOT:?}/$stale"
```

Two distinct defects in one `rm -rf` loop:

1. **No ownership filter.** Run directories are named `${TS}_${GIT_SHA}` (`:207`), i.e. `^[0-9]{8}T[0-9]{6}Z_`. The prune applies that name pattern nowhere. `--out` is a documented, first-class flag whose help text says only "Write the run directory under DIR instead of evals/runs/" -- nothing warns that DIR becomes a managed retention root. `bash run-eval.sh --out ~/eval-archive` against a directory holding 12 unrelated subdirectories silently deletes the oldest two, recursively, on the success path.
2. **Off-by-N between the guard and the list.** `run_total` counts directories only (`find -type d`); `stale_dirs` positions by `ls -1t`, which lists **all** non-dot entries. With 11 run directories plus 3 stray files, the guard sees 11 > 10 and `tail -n +11` returns entries 11..14 of a 14-entry list -- so a run directory that is inside the "10 most recent directories" window can be pruned while a file occupies a keep slot.

**Fix.** Filter both the count and the prune list to the run-id pattern (`ls -1t "$OUT_ROOT" | grep -E '^[0-9]{8}T[0-9]{6}Z_'`) so the two operate on the same set, and skip pruning entirely when `OUT_ROOT` was supplied via `--out` (or require an explicit `--prune` opt-in for that case). Document the retention behaviour on the `--out` help line.

### L3-003 -- P2 -- CA-141 residual: the invalid-PID reclamation path is still a non-atomic `rm -rf` of a lock another contender may already hold
`plugins/edm/bin/edm-state:967-977` (the `rm -rf` at `:971`)

```bash
      if [[ -z "$holder_pid" || ! "$holder_pid" =~ ^[0-9]+$ ]]; then
        echo "edm-state: removing stale state lock ${lockdir} (invalid PID '${holder_pid:-missing}')" >&2
        rm -rf "$lockdir"
```

The sibling branch 13 lines below correctly uses `mv "$lockdir" "${lockdir}.stale.$$"` so that at most one contender ever removes a given lockdir. This branch does not. Contenders B and C can both read the same garbage pidfile, C can win the removal and then `mkdir` and claim the lock, and B's subsequent `rm -rf` deletes C's brand-new **live** lockdir -- mutual exclusion is lost with no diagnostic on either side. Reachable whenever `echo $$ > "$pidfile"` (`:1006`, `2>/dev/null || true`) leaves a truncated or empty file, e.g. on a full filesystem.

Two smaller issues in the same loop:

- `^[0-9]+$` accepts `0`, and `kill -0 0` targets the caller's whole process group, so it always succeeds. A pidfile containing `0` is therefore classified live forever: 50 tries, then a hard `die`, with no reclamation possible.
- `stale_aside="${lockdir}.stale.$$"` (`:984`) is created before `rm -rf "$stale_aside"` (`:987`) with **no trap covering the window** (the traps are installed later, at `:1025`), and `.gitignore:19` (`**/.edm-state.lockd/`) does not match `.edm-state.lockd.stale.12345/`. A death between the `mv` and the `rm` leaves an untracked directory inside a tracked initiative tree that no ignore glob covers.

**Fix.** Route the invalid-PID case through the same `mv`-aside-then-remove sequence as the dead-PID case (they can share one helper). Reject `0` alongside non-numeric values. Add `**/.edm-state.lockd.stale.*/` to `.gitignore`, or reuse a single `${lockdir}.stale` name already covered by `**/.edm-state.lockd*`.

### L3-004 -- P2 -- `with_state_lock`'s mkdir branch cannot distinguish contention from a permanently impossible `mkdir`, and reports the wrong cause after a 5 s stall
`plugins/edm/bin/edm-state:965`, `:1001-1003`; related help text at `:32`

`until mkdir "$lockdir" 2>/dev/null; do` discards errno entirely. `EROFS` (read-only checkout), `EACCES`, and `ENOENT` on the parent are all indistinguishable from "another process holds the lock", so the loop burns 50 x 0.1 s and then reports:

```
state lock timeout after 50 tries on <lockdir>
```

This is the live consequence of CA-061's residual first-invocation write: on a read-only checkout, `edm-state gate-check <PREFIX> <cmd>` for a legacy initiative -- reached from all five `UserPromptExpansion` hooks -- stalls ~5 s and then blames lock contention for a permissions problem, while `--help` still advertises the subcommand as `(read-only)`. The flock branch behaves better here: a failed `200>"${lockfile}"` redirect surfaces bash's real "Read-only file system" text.

**Fix.** Capture `mkdir`'s stderr on the first failed attempt; if the directory does not exist afterwards **and** the message is not `File exists`, `die` immediately naming the real error rather than entering the retry loop. Separately, make `record_degraded_check` non-fatal when the state file's directory is not writable (warn and skip the persist) so `gate-check` honours its own documented read-only contract on the first legacy invocation, not just on later ones.

### L3-005 -- P2 -- the commit hook normalizes only a leading `./` in `srd_root`, so a trailing slash silently disables all commit-time artifact enforcement
`plugins/edm/hooks/hooks.json:86`

```
srd_root="${EDM_SRD_ROOT:-${CLAUDE_PLUGIN_OPTION_SRD_ROOT:-./SRD}}"; srd_root="${srd_root#./}";
... awk -v root="$srd_root" '{ rl=length(root)+1; if (substr($0,1,rl)==(root "/")) { ... } }'
```

With `EDM_SRD_ROOT=SRD/` (or `./SRD/`), `root` becomes `SRD/`, `rl` becomes 5, and the comparison is `substr($0,1,5) == "SRD//"` -- which never matches any real staged path. `prefixes` is empty, the hook takes `test -z "$prefixes" && exit 0`, and every commit passes with no lint and no diagnostic.

The asymmetry is what makes this a defect rather than a user error: `bin/edm-state` tolerates the same value (`state_file_for` builds `SRD//PFX/.edm-state.json`, which POSIX resolves fine) and so does `bin/edm-lint-artifacts` when invoked directly. So an operator who sets a trailing slash sees every direct invocation work correctly while the automatic enforcement silently disappears.

**Fix.** Strip trailing slashes as well: `srd_root="${srd_root#./}"; while [ "${srd_root%/}" != "$srd_root" ]; do srd_root="${srd_root%/}"; done`. Better, add a positive-control assertion in `bin/tests/` that a trailing-slash `EDM_SRD_ROOT` still yields the expected prefix set (the existing assertion at `wave7-smoke.sh:3370` pins the literal matcher and would not catch this).

### L3-006 -- P2 -- `git-lock-check` deletes `.git/index.lock` on a TOCTOU'd, wrong liveness oracle
`plugins/edm/bin/edm-state:3099-3104`

```bash
  git_pids="$(pgrep -x git 2>/dev/null | paste -sd ' ' - || true)"
  if [[ -z "$git_pids" ]]; then
    echo "stale .git/index.lock detected (no git process running); removing..."
    rm -f "$lock_file"
```

Three problems on a destructive path:

1. **TOCTOU.** Between `pgrep` and `rm -f`, a `git add`/`git commit` can start and take the lock. The `rm -f` then deletes a live lock, permitting a second concurrent index write and index corruption.
2. **Wrong oracle, both directions.** `pgrep -x git` matches only processes named exactly `git` -- it misses `git-remote-https`, `git-upload-pack`, an IDE's embedded libgit2/JGit, and any wrapper-renamed git, all of which can legitimately hold the lock; and it matches `git` processes belonging to *unrelated repositories anywhere on the host*, which needlessly refuses the remediation.
3. The classic staleness signal -- the lock file's mtime -- is not consulted at all, and there is no confirmation or `--force` gate.

The comment at `:3097-3098` documents the heuristic but not the race, so this is not covered by the false-alarm filter.

**Fix.** Require an age threshold (e.g. refuse unless `mtime` is older than 60 s), scope liveness to the repository (`lsof "$lock_file"` where available, or match `pgrep -f` against `$git_dir`), and remove via `mv "$lock_file" "$lock_file.stale.$$" && rm -f "$lock_file.stale.$$"` so a losing racer cannot delete a lock a winner just took. Print the lock's age and holder evidence before acting.

### L3-007 -- P2 -- CA-064 residual: an entirely absent `run.json` still scores as `complete: true`
`plugins/edm/evals/score-artifacts.sh:534-539`

```bash
  else
    run_id="$(basename "$run_dir")"
    git_sha="unknown"
    plugin_version="unknown"
    complete="true"
```

The CA-064 remediation fixed the unparseable and malformed cases (`:532-533`) with an explicit rationale that unknown must never resolve to `true` because `edm-compare-eval` keys the partial-run handshake off this value. The absent-file branch immediately below contradicts that rationale: a run directory with no manifest at all -- which is precisely what a run killed before `write_partial_artifacts` could execute leaves behind -- is stamped `complete: true` and is therefore eligible for baseline comparison.

**Fix.** Set `complete="false"` in the `else` branch and name the reason in the emitted JSON (e.g. a `complete_reason: "run.json absent"` field), matching the direction the sibling branch already documents.

### L3-008 -- P2 -- `metrics-report` renders `nulls` and `$null` for any initiative with an empty `phase_durations`
`plugins/edm/bin/edm-state:2525-2527`, `:2537-2538`, `:2619-2621`, `:2643-2644`

`[] | add` is `null` in jq, not `0`. Every `add` in the metrics renderers is unguarded:

```
total_seconds: ([$phases[].duration_seconds // 0] | add),
```

`cmd_init` writes `phase_durations: {}` (`:1493`), so **every freshly initialized initiative** produces output like:

```
  PFX           ?         nulls       $null
  Total: nulls  |  Claude: $null
```

from both `metrics-report --all` and `metrics-report <PREFIX>`. This fails the "consistent project pattern" test of the false-alarm filter: `get_session_tokens_since` applies `add // 0` correctly at `:335-339` and `:365-369`, so the guard is the house pattern and these four sites are the omission. The `--with-human-baseline` savings arms happen to be safe only because `null > 0` is false, which routes them to `"n/a"` by accident rather than by design.

**Fix.** Change every `| add)` in these four blocks to `| add // 0)`.

### L3-009 -- P2 -- the eval driver's auth probe is an untimed network call inside a driver whose entire contract is per-phase timeouts
`plugins/edm/evals/run-eval.sh:188-192`

```bash
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  if ! claude -p "Reply with exactly: OK" --model haiku >/dev/null 2>&1; then
```

Every other model call in this driver goes through `run_with_timeout "$PHASE_TIMEOUT_SECONDS" ...` (`:295`). This one does not. On a hung connection it blocks indefinitely: the driver never reaches `STARTED=true`, so the EXIT trap's partial-artifact path (`:149-152`) is skipped, and `eval:nightly` burns its whole `timeout: 150m` (`.gitlab-ci.yml:583`) and fails as a GitLab timeout -- indistinguishable from the slow-phase case CA-063 was filed to make distinguishable, and with no `run.json` written at all (which then reads as `complete: true` via **L3-007**).

**Fix.** Wrap the probe: `run_with_timeout 60 /dev/null /dev/null claude -p ... || die "no working Claude auth ..."`. `run_with_timeout` is defined at `:255` but only after this check, so either move the function definition above the credential gate or inline a short bounded poll.

### L3-010 -- P2 -- `archive` and `migrate-path` rename the initiative directory, live lock directory included, with no lock held
`plugins/edm/bin/edm-state:2474` (archive), `:2852` and `:2859`/`:2866` (migrate-path rollback)

Both commands call `git_aware_mv "$src" "$dst"` outside any `with_state_lock` acquisition, and the lockbase is derived from `state_file_for` -- which the move itself changes. A concurrent `checkpoint-if-active` (Stop/PreCompact hooks fire unprompted), `record-partial-verdict`, or `write-handoff` on the same initiative therefore:

- holds `SRD/PFX/.edm-state.lockd`, which the rename relocates **while it is held**, so its trap's `rm -rf "$_STATE_LOCKDIR"` targets a path that no longer exists and the lockdir is leaked at the destination (inside `.archived/`, where nothing will ever reclaim it);
- has its `mktemp "${dest}.tmp.XXXXXX"` fail with ENOENT mid-write, which `write_atomic` reports as `mktemp failed` (`:546`) -- a message that names none of the actual cause;
- is neither serialized against nor detected by either command.

`migrate-path` additionally leaves the `mkdir -p "${SRD_ROOT}/${product}"` from `:2849` in place when it rolls back, and deletes the carried-over `.bak` at `:2862` before the write that the rollback at `:2866` would want it for.

**Fix.** Take `with_state_lock "${src_state_file%.json}"` around the check-and-move in both commands (the lock body may perform the rename; it just must not itself call `rmw_state`), and remove the lockdir before the rename rather than letting it travel. Since the lock's own directory sits inside the moved tree, an explicit `rm -rf "${lockbase}.lockd" "${lockbase}.lock"` immediately before the rename -- while still holding logical exclusion -- is the simplest correct ordering.

### L3-011 -- P2 -- the whole-directory token fallback caps the concatenation rather than each file, contradicting its own comment and silently undercounting
`plugins/edm/bin/edm-state:346-351`, and the `EDM_TOKEN_READ_LINE_CAP` boundary at `:312-318`

The comment at `:350` states "Each file is independently line-capped for the same reason as the scoped branch above." The code is:

```bash
  cat "$sessions_dir"/*.jsonl 2>/dev/null | tail -n "$_token_read_cap" | jq -Rn ...
```

`tail` is applied to the concatenation, so with more than one session file the cap keeps only the tail of the final file(s) and silently discards every earlier session's assistant messages -- exactly the sum this fallback exists to produce. `cat` across files without trailing newlines also splices two JSON objects into one unparseable line, which `fromjson?` counts into `bad` and downgrades `attribution_mode` to `"unparseable"` without any indication that tokens were lost.

Related boundary: `EDM_TOKEN_READ_LINE_CAP=0` satisfies the `^[0-9]+$` validator at `:317` and makes `tail -n 0` emit nothing, so tokens are recorded as 0 -- which `state_anomalies` then reports as the **blocking** `ZERO_TOKENS` anomaly (`:1201-1212`). A configuration value the validator accepts produces a blocking validate failure with no connection back to the cause.

**Fix.** Loop the files and `tail -n "$cap"` each one (`for f in "$sessions_dir"/*.jsonl; do tail -n "$cap" "$f"; done`), or fix the comment to say the cap is global. Reject `0` in the validator (`^[1-9][0-9]*$`) with a message naming the ZERO_TOKENS consequence.

### L3-012 -- P2 -- `watch-impl`'s poll swallows every git failure, so a rebased-away `last_sha` silences the monitor for the rest of the session
`plugins/edm/bin/edm-state:2487-2495`

```bash
    new_commits="$(git log --pretty=format:'%h %s' "${last_sha}..HEAD" 2>/dev/null | grep -E '[A-Z]+-T[0-9]+' || true)"
```

`2>/dev/null` plus `|| true` collapses three distinguishable outcomes into one: no new ticket commits, a `git log` failure, and an unresolvable `last_sha`. If the branch is rebased or amended and the old commit becomes unreachable and is later pruned, `git log "${last_sha}..HEAD"` fails on every subsequent poll and the monitor emits nothing for the remaining lifetime of the session -- the same indistinguishable-silence failure CA-083 fixed for the *initial* read (`:2484-2486` now hard-fails) but which survives in the loop. Because CLAUDE.md documents the monitor as running for the whole session with no EDM-side kill switch, the silence is permanent and there is no signal that implementation progress is no longer being surfaced.

Secondary: `last_sha` advances only when a matching commit is found (`:2493`), so a long run of non-ticket commits makes the scanned range grow without bound -- one `git log` over an ever-larger range every 5 s.

**Fix.** Capture the exit status of the `git log`; on failure, verify `last_sha` with `git cat-file -e "${last_sha}^{commit}"` and, when it is gone, re-seed `last_sha="$(git rev-parse HEAD)"` and emit one line saying history was rewritten and the monitor re-anchored. Advance `last_sha` to `HEAD` on every successful poll, not only on a match.

### L3-013 -- P2 -- two residual status-capture defects in `with_state_lock` that CA-134's remediation fixed in `write_atomic` but not here
`plugins/edm/bin/edm-state:944-946` and `:1045-1046`

1. **Exit-code collision, flock branch.** `( flock -w 10 200 || exit 99; "$@" ) || _lock_ec=$?` followed by `[[ $_lock_ec -eq 99 ]] && die "state lock timeout after 10s ..."`. A locked body that exits 99 for its own reasons is reported as a lock timeout that never happened. `99` is not reserved anywhere and `_rmw_state_body`/`_cmd_init_body` already use out-of-band codes (`return 10` at `:1524`), so the sentinel space is in active use.
2. **CA-134's exact pattern, mkdir branch.**
   ```bash
       _EDM_TRAP_DEPTH=1
       ( "$@" )
       local ec=$?
   ```
   CA-134's remediation moved `write_atomic`'s captures onto the same statement (`"$@" > "$tmp" || ec=$?` at `:587`, `mv -f ... || ec=$?` at `:602`) with a comment explaining that a bare call followed by a separate `ec=$?` "changes this from return the renderer's exit status to abort the process immediately". The identical shape survives one function away, in the more consequential place: under errexit the failing subshell aborts before `:1046-1052`, so `_EDM_TRAP_DEPTH` is never reset, the trap restoration never runs, and the caller's non-zero return path (`if ! rmw_state ...`, e.g. `cmd_migrate_path:2863`) is replaced by process death. The lockdir itself survives only because the EXIT trap happens to cover it.

**Fix.** Use `( "$@" ) || ec=$?` with `ec` declared before the call, mirroring `write_atomic`. Replace the `99` sentinel with a distinct out-of-band value and assert in `bin/tests/` that no locked body returns it, or better, detect the timeout by testing for the lock rather than by exit code.

## Noted / Not Actionable

1. **The flock file is never unlinked after release** (`bin/edm-state:944`) -- CA-169 records this as a fix that must stay unapplied, since unlinking a released flock file breaks mutual exclusion; `.gitignore:18` now matches the name.
2. **`cmd_watch_impl`'s `while true` loop has no exit condition** (`:2487`) -- documented in `plugins/edm/CLAUDE.md` Sec."Monitors behavior" as host-managed with the lifetime and `TaskStop` stop path stated explicitly.
3. **The invalid-PID retry branch has no `sleep 0.1` before `continue`** (`:976`) -- it tight-loops, but `tries` is incremented on that path (the CA-141 fix) so the loop is bounded, and `mkdir` succeeds on the next pass in the normal case.
4. **The outer `grep -qxF "$target_heading"` guard in `cmd_update_patterns` (`:4103`) is not fence-aware** -- unlike `pattern_insert_line_for`. A heading that exists only inside a fence passes this guard and is then correctly rejected by the fence-aware resolver, which prints a skip. The guard can only produce a false *skip*, never a mis-splice.
5. **`mermaid_scan_awk`'s `getline < scan_file` cannot distinguish a failed open (-1) from an empty set** (`bin/edm-lint-artifacts:222`) -- the staging write is checked one statement earlier at `:167` and reports through the new `scan-error` class, so the unchecked window is a single statement wide.
6. **`_splice_pattern_file` uses `head -n "$((insert_line - 1))"`, which would drop everything at `insert_line == 1`** (`:3987`) -- unreachable: `pattern_insert_line_for` prints `j+1` where `j >= start >= 1`, so the minimum is 2, and the `insert_line == 0` skip is handled at `:4032`.
7. **`harness_scratch_dir` interpolates the path into its trap body at install time** (`bin/tests/_harness.sh:64`, the form CA-159 banned) while `with_scratch_repo:92` uses the correct deferred form -- test-only code path, and the paths are `mktemp -d` outputs with no apostrophes.
8. **An `edm-lint-ignore` marker inside a plain (non-mermaid) fence now re-classifies that fence's closing line as ignored+marker** (`bin/_edm-lint-lib.sh:141-146` interacting with the CA-144 reordering) -- an extra `marker_line_set` entry for a line that is emitted in no class otherwise; no violation class consumes it in a way that changes a verdict.
9. **`run_with_timeout` leaves a ~microsecond window between `wait "$pid"` returning and `CURRENT_CHILD_PID=""`** (`evals/run-eval.sh:272-274`) in which the trap would `kill` an already-reaped PID -- guarded by `2>/dev/null`, and the reuse required for real harm is not plausible at this window width.
10. **`.gitlab-ci.yml` declares no `resource_group` on any job** -- every lint, test and validate job is read-only against a fresh checkout and shares no cache or artifact write target, so concurrent pipelines cannot interfere.
11. **`cmd_render_ledger` writes `findings-ledger.md` with `write_atomic` and no lock** (`:3256`) -- correct: the markdown is a pure, deterministic projection of `findings-ledger.jsonl` (stated at `:3196-3198`), so concurrent renders converge on identical bytes; there is no read-modify-write to serialize.
12. **`migrate-path` leaves an empty `SRD/<product>/` behind on rollback** (`:2849` vs `:2859`/`:2866`) -- git does not track empty directories and no consumer enumerates product directories independently of initiative directories.

## Summary for the orchestrator

**Ledger verdicts (14 entries checked):** FIXED -- CA-011 (L3 half), CA-025, CA-026, CA-027, CA-056, CA-058, CA-059, CA-133, CA-144, CA-063 (confirm). PARTIALLY FIXED -- CA-061, CA-064, CA-141, CA-143. NOT FIXED -- CA-142.

**New findings:** 2 x P1, 11 x P2, 12 x Noted.

**The one thing to act on first:** Wave 4a's two concurrency remediations cancel each other out. `plugins/edm/bin/edm-state:1044-1045` forks the locked body (CA-025's fix) and `:555-557` pushes cleanup state into that fork (CA-142's fix), so `_EDM_CLEANUP_PATHS` at `:512-537` -- roughly 25 lines plus a 9-line rationale comment -- is unreachable-by-construction dead code, and the mkdir branch (the only branch macOS takes) runs its entire critical section with no signal handler. Anyone re-remediating this must pick one of the two designs, not both; the `bash 3.2 nesting depth one` constraint the comment at `:503-511` invokes does not actually bind, because a `( )` subshell resets inherited traps and `write_atomic`'s own layer inside it is depth one.

Key files: `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-state`, `/Users/darryl.porter/projects/marketplace/plugins/edm/evals/run-eval.sh`, `/Users/darryl.porter/projects/marketplace/plugins/edm/evals/score-artifacts.sh`, `/Users/darryl.porter/projects/marketplace/plugins/edm/hooks/hooks.json`, `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/_edm-lint-lib.sh`, `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-lint-artifacts`, `/Users/darryl.porter/projects/marketplace/.gitignore`.
