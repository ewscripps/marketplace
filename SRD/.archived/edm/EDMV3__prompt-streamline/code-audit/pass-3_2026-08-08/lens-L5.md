# EDM Code Audit -- Lens L5: Runtime Hygiene -- Pass 3 (2026-08-08)

Scope: `plugins/edm/` (bin/, bin/tests/, evals/, hooks/hooks.json, docs/) + repository-root `.gitignore` + `.gitlab-ci.yml` runtime-file surface.

## Part A -- Verdicts on every open L5-tagged ledger entry

| ID | Lens(es) | Verdict | Evidence |
|---|---|---|---|
| CA-148 | L5 | **Substantially fixed, one residual** | `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/wave7-smoke.sh:4826-4887` is a real test: it `git init`s a scratch repo, copies the *real* repo-root `.gitignore` into it (`:4833`), runs a real `edm-state init` against a relocated root, then derives the four lock/temp names **using the same formulas as the source** (`:4858-4862`, comment at `:4854-4857` explicitly forbids hand-typed guesses) and asserts `git check-ignore -q` on each. Residual: the enumeration is hand-maintained and omits `.edm-state.lockd.stale.$$` -- which is genuinely unignored. See **L5-1**. |
| CA-149 | L5 | **Fixed** | `/Users/darryl.porter/projects/marketplace/.gitignore:14-20` -- the three patterns are now `**/.edm-state.lock`, `**/.edm-state.lockd/`, `**/*.md.tmp.*` with the rationale comment in place. The test at `wave7-smoke.sh:4839` deliberately uses `artifacts/nested-root` -- not named `SRD`, two levels deep -- so a re-anchored pattern fails the assertion. |
| CA-150 | L5 | **Fixed, both halves** | gitignore half: `/Users/darryl.porter/projects/marketplace/.gitignore:21-23` adds `plugins/edm/docs/*.tmp.*`; the staging path `plugins/edm/docs/canonical-sections.md.tmp.XXXXXX` (created at `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-sync-canonical-sections:73`) is matched by that line **and** by `.gitignore:20`. Trap half: `edm-sync-canonical-sections:76` is now `trap 'rm -f "$tmp"' EXIT INT TERM HUP` with the HUP rationale at `:74-75`. |
| CA-151 | L5 | **Fixed at the named site; class residual** | `/Users/darryl.porter/projects/marketplace/plugins/edm/evals/score-artifacts.sh:509-517` refuses when the canonicalized (`:507`) run dir matches `*/bin/tests/fixtures/*`, unless `--out` is given; help text `:16-20`; fixture README updated at `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/fixtures/code-audit/README.md:49-54`. Residual: the guard names only one of the tree's two tracked fixture directories. See **L5-7**. |
| CA-066 | L5 | **Partially fixed** | Retention now exists in code (`/Users/darryl.porter/projects/marketplace/plugins/edm/evals/run-eval.sh:542-572`, `EDM_EVAL_KEEP_RUNS` default 10, help at `:31-32`) **and** in docs (`/Users/darryl.porter/projects/marketplace/plugins/edm/evals/README.md:43-49`) -- both halves the ledger asked for. Two residuals in the new cleanup code: **L5-3**, **L5-4**. |
| CA-014 | L5+L8 | **L5 half fixed** | Trap at `/Users/darryl.porter/projects/marketplace/plugins/edm/evals/tiering-matrix.sh:147` is now `trap 'rm -f "${tmp:-}"' RETURN EXIT INT TERM`, with the `${tmp:-}` (not `"$tmp"`) `set -u` guard for the post-return EXIT firing explained at `:141-146`. The divergence-sweep half is also closed: `wave7-smoke.sh:951` now greps `"$PLUGIN_DIR/bin/" "$PLUGIN_DIR/evals/"` across nine patterns including `XXXXXX[A-Za-z0-9]`, rationale at `:942-950`. Any remaining CA-014 residue is the L8 half, not mine. |

### Spot-verification of L5-tagged entries marked `fixed` (Wave 6b touched their neighbourhoods)

| ID | Verdict | Evidence |
|---|---|---|
| CA-015 | Holds | `write_atomic` (`edm-state:539-623`) is the single staging writer; `mktemp "${dest}.tmp.XXXXXX"` at `:546` replaces `.tmp.$$`; the five call sites (`:639`, `:1526`, `:3256`, `:4037`, `:4539`) all land under `**/*.md.tmp.*` or `.edm-state.json.tmp.*`. |
| CA-029 | Holds | `edm-state:931-932` derives `${lockbase}.lock` / `${lockbase}.lockd`; both matched by `.gitignore:18-19`. Not unlinking the flock file remains correct -- but see **L5-2**. |
| CA-030 | Holds, with a HUP gap | `wave6-smoke.sh:22-29` `cleanup_wave6` restores the tracked file from `$T41_BACKUP`. Gap: **L5-6**. |
| CA-045 | Holds, with one residual | `wave6-smoke.sh:19` and `wave7-smoke.sh:22-23` both use `${TMPDIR:-/tmp}` templates with EXIT/INT/TERM traps. Residual hardcoded `/tmp`: **L5-5**. |
| CA-065 | Holds | `edm-sync-canonical-sections:104` is `mv -f "$tmp" "$DST"` (was `cp`). |
| CA-067 | Holds | One trap at `edm-lint-artifacts:130` covers both `ATTR_PATTERN_FILE` (`:122`) and `MERMAID_SCAN_FILE` (`:129`), installed once at top level rather than per-initiative inside `scan_md_files`. |
| CA-181 | Holds | `_edm-lint-lib.sh`, plus the newer `_edm-cli-lib.sh` and `edm-mermaid-rules.awk`, match no `.gitignore` glob and the tree was clean at session start -- therefore tracked. Do not re-raise. |
| CA-170 / CA-171 | Hold | `timing.sh`'s five measuring modes still `rm -rf` on the happy path (`:156`, `:202`, `:233`, `:260`, `:304`); `--generate-fixture` (`:89-99`) still deliberately retains and prints its tree. `harness-smoke.sh` now has five (was three) inline-`rm -f` mktemp files (`:43/54`, `:61/92`, `:113/131`, `:137/178`, `:217/250`) -- same class, same bounded consequence. |
| CA-169 | **Re-opened on its own action item only** | See **L5-2**. Not re-litigating the unlinking decision. |

---

## Part B -- Findings (L5: Runtime Hygiene)

### L5-1 (P2) -- `.edm-state.lockd.stale.$$` is matched by no `.gitignore` pattern, created with no trap active, and nothing ever cleans it

**File type:** stale-lock aside directory (contains a `pid` file).
**Created at:** `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-state:984-987`

```bash
local stale_aside="${lockdir}.stale.$$"
if mv "$lockdir" "$stale_aside" 2>/dev/null; then
  echo "edm-state: reclaimed stale state lock ${lockdir} (PID ${holder_pid} no longer running)" >&2
  rm -rf "$stale_aside"
fi
```

**In `.gitignore`? No.** Walked every pattern against `SRD/<product>/<INIT>/.edm-state.lockd.stale.12345`:

- `.gitignore:18` `**/.edm-state.lock` -- no
- `.gitignore:19` `**/.edm-state.lockd/` -- no; the trailing slash makes this an exact-name directory match, and the name here has a `.stale.<pid>` suffix
- `.gitignore:10` `.edm-state.json.tmp.*` -- no
- `.gitignore:20` `**/*.md.tmp.*` -- no
- `.gitignore:11-13`, `:23` -- audit-patterns/docs-scoped, and none of the three suffix forms match

The same hole exists for the pattern-library lockbase (`edm-state:4115` passes `${pattern_file%.md}`), i.e. `plugins/edm/docs/audit-patterns/code-audit.lockd.stale.12345` is matched by neither `*.lockd/` nor `*.tmp.*`.

**Accumulation risk:** real. The reclaim runs at `:984` **before** the lock trap is installed at `:1025-1028`, so no signal handler covers `$stale_aside` -- a Ctrl-C or SIGTERM in the window between the `mv` and the `rm -rf` leaves it permanently. If `rm -rf` fails (a group-writable shared checkout where the `mv` succeeds but the aside's contents are another UID's) it is also left permanently, silently -- the `rm` is unchecked. Nothing anywhere in the tree ever sweeps `*.stale.*`: `grep -n '\.stale\.'` across `plugins/edm/` returns only `edm-state:950` (comment), `:984`, and no test at all. One directory accrues per reclaiming PID, in a **tracked** artifact directory, and it will show in `git status` forever.

**Reachability:** the mkdir spin-lock branch is the live path on any host without `flock(1)` -- i.e. macOS, this project's primary development platform per `plugins/edm/CLAUDE.md`.

**Why this is Wave-4a-introduced, not pre-existing:** the CA-141 remediation replaced a `kill -0`-then-`rm -rf` sequence with the `mv`-aside idiom. The old code created no new path name; the new one does. `wave7-smoke.sh:4311-4345` (CA-141a) asserts `lockdir=absent` after a reclaim but never asserts absence of `*.stale.*`, so the suite is green over it -- and `wave7-smoke.sh:4870-4874` (the CA-148 gitignore enumeration) does not list it either.

**Fix (two lines, both needed):**
1. `.gitignore` -- widen the two lock-dir patterns so the aside is covered by construction rather than by a third hand-typed line: `**/.edm-state.lockd*` and `plugins/edm/docs/audit-patterns/*.lockd*` (both then also cover the exact-name form; delete the now-redundant `:19`/`:12` slash forms or keep them, harmless).
2. `wave7-smoke.sh:4870-4874` -- add `"${lockdir}.stale.$$"` to the CA-148 `for ca148_entry in ...` list, derived with the same formula as `edm-state:984`, so the class cannot re-open. Optionally add a `check` in the CA-141a case that `find "$tmp141a" -name '*.stale.*'` returns zero.

---

### L5-2 (P2) -- CA-169's one prescribed action never landed: nothing at the flock site records that the lock file must **not** be unlinked

**File type:** `flock(1)` lock file, deliberately never removed.
**Site:** `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-state:944`

```bash
( flock -w 10 200 || exit 99; "$@" ) 200>"${lockfile}" || _lock_ec=$?
```

The ledger's Non-Findings entry 28 (CA-169) reads: *"the round-1 prescription to `rm -f` the flock file after release was deliberately not applied and must stay unapplied -- unlinking a released flock file breaks mutual exclusion... **Add one comment at :829 so a later round does not fix it.**"*

**Verified absent.** `grep -in 'unlink|never remove|do not remove|CA-169'` across `edm-state` returns exactly one hit -- `:3107`, which is the unrelated `git-lock-check` operator message about `.git/index.lock`. The comment block at `:936-942` explains fd 200 and the `|| _lock_ec=$?` errexit positioning, and says nothing about the file's lifetime. Round 1 raised this, round 2 demoted it *conditional on that comment being added*, and the comment is not there.

**Why it belongs to L5:** a lock file that is intentionally left on disk forever is exactly the shape L5 flags, and the only thing standing between that correct design and a future well-intentioned "leaked lock file" fix (which would silently break mutual exclusion for every concurrent `edm-state` writer) is a comment that does not exist. `.gitignore:18` now hides it from `git status`, which removes the *pressure* to fix it but also removes the visible evidence that it is deliberate.

**Fix:** one comment immediately above `edm-state:944`, e.g. *"The lock file is deliberately never unlinked: `flock` mutual exclusion is keyed on the inode, so removing a released lock file lets a later contender create a fresh inode and acquire a lock the current holder is still inside. `.gitignore:18` keeps it out of `git status`. Do not add `rm -f "$lockfile"` here (round-1 finding, deliberately not applied; ledger CA-169)."*

---

### L5-3 (P2) -- `evals/runs/` retention never runs on the failure path, so a stream of partial runs still accumulates without bound

**File type:** eval run directories containing `run.json`, `scores.json`, four artifact `.md` files, and `raw/{plan,srd,audit-srd}.json` + `raw/*.stderr.log` (the full `claude -p` payloads).
**Created at:** `/Users/darryl.porter/projects/marketplace/plugins/edm/evals/run-eval.sh:209` (`mkdir -p "$RUN_DIR/raw"`), `:296` (raw stdout/stderr per phase), `:114-131` (partial `run.json`/`scores.json`), `:540` (final `run.json`).
**Pruned at:** `run-eval.sh:553-572`.

**In `.gitignore`? Yes** -- `/Users/darryl.porter/projects/marketplace/plugins/edm/evals/runs/.gitignore` is `*` + `!.gitignore`, so nothing here reaches `git status`. Disk-only.

**Accumulation risk:** the prune block sits after `COMPLETE=true` (`:452`) and after the exit-4 `return` at `:446`, so it is reachable **only on the success path**. Every non-success exit -- a phase timeout (`run_with_timeout` -> 124), a phase's own non-zero exit, a missing expected artifact, a SIGINT/SIGTERM (-> `cleanup()` -> `write_partial_artifacts()` -> `exit 4`) -- mints a full run directory *including* the `raw/` payloads written before the failure, and prunes nothing. A developer iterating on prompt changes against a flaky backend, or a scheduled job whose auth expires, accumulates one directory per attempt forever.

**False-alarm filter applied and not satisfied.** The in-code rationale at `:545-548` reads: *"Pruning runs only here, on the success path, so a partial run under investigation... is never pruned out from under someone still debugging it."* That justifies **not deleting the current run**; it does not justify **never running the prune at all** on a failure. The two are separable -- pruning the oldest N+1 directories cannot touch the run that was just created, since it is the newest by mtime.

**Fix:** extract the `:549-572` block into a `prune_old_runs()` function and call it from both the success path and from `cleanup()` after `write_partial_artifacts()`, keeping the same `EDM_EVAL_KEEP_RUNS` bound. The "never prune the run under investigation" property is preserved for free by the newest-first ordering. Amend `evals/README.md:43-49`, which currently states the success-path-only behaviour as the contract.

---

### L5-4 (P2) -- the new retention prune can delete a *live* run directory: `run_total` counts directories, `ls -1t` lists everything

**Site:** `/Users/darryl.porter/projects/marketplace/plugins/edm/evals/run-eval.sh:554-560`

```bash
run_total="$(find "$OUT_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
...
if [ "$run_total" -gt "$EDM_EVAL_KEEP_RUNS" ]; then
  stale_dirs="$(ls -1t "$OUT_ROOT" | tail -n "+$((EDM_EVAL_KEEP_RUNS + 1))")"
```

The gate counts **directories only** (`-type d`); the offset is then applied to `ls -1t`, which lists **all non-hidden entries**, directories and files alike. Any non-hidden regular file in `OUT_ROOT` consumes one of the `EDM_EVAL_KEEP_RUNS` protected slots, so the `tail -n +K` window slides down into directories that are still inside the keep-set. The `[ -d "$OUT_ROOT/$stale" ] || continue` guard at `:564` skips non-directories from being deleted but does nothing to correct the offset -- it makes the miscount silent rather than preventing it.

**Reachability:** the default `OUT_ROOT` (`evals/runs/`) contains only the hidden `.gitignore`, which `ls -1t` does not list, so today's default path is safe. It is reachable via `--out DIR` -- which the two documented workflows both use: `evals/baseline/README.md:37` (`--out /path/outside/plugins/edm/eval-baseline-runs`, three consecutive runs) and `evals/README.md:38-41`. Put a `notes.md` or a `README` next to the baseline runs and the eleventh run can delete run #2.

**Accumulation/cleanup verdict:** this is a cleanup-correctness defect in newly added cleanup code -- borderline L3 (data loss), reported here because L5 owns the cleanup path. Not a gitignore issue.

**Fix:** enumerate directories once and reuse that list for both the count and the window, e.g. drive the loop from `find "$OUT_ROOT" -mindepth 1 -maxdepth 1 -type d` piped through the same `ls -1t`-equivalent ordering, or filter `ls -1t` output with a `[ -d ]` test *before* applying `tail -n +K` rather than after. Keep the BSD/bash-3.2 constraints noted at `:557-559` (no `find -printf`, no `head -n -N`).

---

### L5-5 (P2) -- `wave7-smoke.sh` writes a fixed-name `/tmp/edm-ca160-proof`, the one site in the suite that ignores `TMPDIR`, and never pre-cleans it

**File type:** injection-proof marker file (a negative-control artifact).
**Sites:** `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/wave7-smoke.sh:4659`, `:4666`, `:4668`

```bash
ca160_rate_out="$(EDM_HUMAN_HOURLY_RATE_USD='150"; touch /tmp/edm-ca160-proof #' bash "$EDM_STATE" --help 2>&1)"
...
[[ ! -e /tmp/edm-ca160-proof ]] \
  && pass "CA-160 -- the malformed rate never reached a shell/jq eval sink" \
  || { fail "..."; rm -f /tmp/edm-ca160-proof; }
```

**In `.gitignore`?** N/A -- outside the repo.

**Problems, all three of the L5 "unexpected location" class:**
1. **Not `TMPDIR`-honoring.** Every other scratch path in this 4,891-line suite uses `${TMPDIR:-/tmp}` or the trap-covered `${TMP}` (`:22`, `:149`, `:259`, `:768`, `:4279`, `:4317`, `:4353`, `:4378`, `:4425`, `:4467`, `:4542` ...). This is the sole outlier, so the False Alarm Filter's "used consistently everywhere" test fails -- it is an inconsistency, not a project pattern.
2. **Fixed name, no uniquifier.** Two concurrent suite runs (two worktree agents on one machine -- a scenario `harness-smoke.sh:57-59` explicitly documents as normal for this repo) share the path. On a multi-user Linux host, user A's leftover file is not removable by user B, so B's `rm -f` at `:4668` silently no-ops.
3. **Never pre-cleaned.** The assertion is a bare `[[ ! -e ... ]]` on a path the test does not own. Any stale `/tmp/edm-ca160-proof` -- from an earlier run killed between `:4659` and `:4666`, or from an unrelated process -- produces a permanent, unfixable-by-code false FAIL of a blocking smoke assertion.

**Fix:** derive the proof path once as `ca160_proof="${TMP}/edm-ca160-proof"` (inside the trap-covered scratch tree), `rm -f "$ca160_proof"` immediately before `:4659`, and interpolate it into the injection payload. That makes the assertion self-contained, unique per run, and covered by the suite's own `trap 'rm -rf "$TMP"' EXIT INT TERM` at `:23`.

---

### L5-6 (P2) -- the HUP added by the CA-150 remediation was applied to the generator but not to the smoke test that mutates the same **tracked** file

**File type:** in-tree mutation of a tracked, generated file, plus its backup.
**Sites:** mutation at `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/wave6-smoke.sh:3096`; restore trap at `:22-29`

```bash
cleanup_wave6() {
  if [[ -n "${T41_BACKUP:-}" && -n "${T41_CANONICAL:-}" && -f "${T41_BACKUP}" ]]; then
    cp "$T41_BACKUP" "$T41_CANONICAL"
  fi
  rm -f "${T41_BACKUP:-}"
  rm -rf "$TMP"
}
trap cleanup_wave6 EXIT INT TERM        # <-- no HUP
```

`:3096` appends `hand-edited, not regenerated` to `${REPO_ROOT}/plugins/edm/docs/canonical-sections.md` -- a **tracked** file -- and relies on `cleanup_wave6` (or the inline `cp` at `:3104`) to restore it.

Wave 6b's CA-150 fix added `HUP` to `edm-sync-canonical-sections:76`, whose stated rationale is *"a terminal disconnect mid-run (e.g. an SSH session dropping) leaked this staging file just as much as an untrapped INT/TERM would have."* That exact reasoning applies with **greater** force here: the two sites mutate the same file, but the generator's untrapped signal leaks a gitignored *staging* file, whereas this one leaves a **modified tracked file** in the working tree -- a dirty `git status` on `plugins/edm/docs/canonical-sections.md` that a developer will read as real drift, and which fails `edm-sync-canonical-sections --check` and the blocking `T41 AC5` byte-identity assertion on the next run. The remediation was applied to the cheaper of the two sites and not the more expensive one.

**Fix:** `trap cleanup_wave6 EXIT INT TERM HUP` at `wave6-smoke.sh:29`. (For completeness the same one-word addition applies to `wave7-smoke.sh:23`, `edm-lint-artifacts:130`, `tiering-matrix.sh:147`, and `edm-check-grants:121` -- but those all stage under `TMPDIR` and are recorded as Noted below; `wave6-smoke.sh:29` is the only one whose failure mode touches a tracked file.)

---

### L5-7 (P2) -- CA-151's fixture guard names one of the tree's two tracked fixture directories

**File type:** `scores.json` written into a tracked directory.
**Site:** `/Users/darryl.porter/projects/marketplace/plugins/edm/evals/score-artifacts.sh:513-517`

```bash
case "$run_dir" in
  */bin/tests/fixtures/*|*/bin/tests/fixtures)
    [[ -n "$out_file" ]] || die "refusing to write scores.json into a tracked fixture directory ..."
    ;;
esac
```

The guard's own stated purpose (`:509-512`) is *"refuse to deposit scores.json into a tracked fixture directory."* The tree has two tracked fixture directories: `plugins/edm/bin/tests/fixtures/` (guarded) and `plugins/edm/evals/fixtures/tiny-svc/` (not guarded -- `evals/README.md:255-257` documents it as the frozen fixture). Pointing the scorer at the latter passes the `[[ -d ]]` check at `:506`, skips the guard, scores all five dimensions as `null`, and writes an untracked `scores.json` at `:603` into a tracked directory with no `.gitignore` glob covering it -- the exact outcome CA-151 was filed for. It would then appear in `git status` and, being tracked-directory-resident, is a plausible accidental commit.

**Reachability:** lower than the guarded site (nothing documents scoring the tiny-svc fixture, and `evals/README.md:175-180` describes the scorer's input as a run directory). Reported as a class residual rather than a live defect.

**Fix:** widen the `case` to `*/fixtures/*|*/fixtures` -- the two tracked fixture roots are the only `fixtures/` directories under `plugins/edm/`, and a real `run-eval.sh` output directory (`runs/<ts>_<sha>/`) can never match, so there is no false-refusal risk. Update the `--out`-required note in the help text at `:16-20`.

---

## Noted / Not Actionable

1. **`.gitignore:23` `plugins/edm/docs/*.tmp.*` is redundant with `.gitignore:20` `**/*.md.tmp.*`** for the only path it was added to cover (`docs/canonical-sections.md.tmp.XXXXXX`) -- both lines landed in Wave 6b. Harmless, and `:21-22` documents the intent for a future reader; keeping it also covers a hypothetical non-`.md` staging file under `docs/`.
2. **`edm-state:944`'s flock file is never unlinked** -- deliberate and correct (ledger CA-169). Only the missing guard comment is raised, as L5-2.
3. **`edm-lint-artifacts:130`, `edm-check-grants:121`, `tiering-matrix.sh:147`, `wave7-smoke.sh:23`, `wave3/4a/5-smoke.sh` traps omit HUP** -- every one of them stages under `${TMPDIR:-/tmp}` (or a bare `mktemp -d`, which resolves to `$TMPDIR`), so a HUP leak is bounded ephemeral disk and never reaches `git status`. Same rationale the ledger already accepted for CA-170.
4. **`harness-smoke.sh:43, 61, 113, 137, 217` -- five mktemp files with inline `rm -f` and no trap** -- grown from three since round 2; identical class, identical bounded consequence. Consistent with ledger CA-171.
5. **`timing.sh --generate-fixture` (`:89-99`) deliberately retains its scratch tree** and prints `FIXTURE_DIR=` for `--subcommands`/`--all-lint` to consume via `--dir`. Documented as intentional at `:87-88`, `:98`. Consistent with ledger CA-170.
6. **`run-eval.sh --provision-only` (`:172-176`) deliberately retains its `mktemp -d` tree** -- `cleanup()` at `:146` skips removal when `PROVISION_ONLY=true`, and the caller is handed the path on stdout. Documented at `:18-22` and `evals/README.md:51-64`; the mode's whole purpose is to leave a tree for network-disabled inspection.
7. **`harness-smoke.sh:30-35` `rm -rf "${REPO_ROOT}/SRD/demo/TESTH__h"`** -- this is the correct shape, not a defect: it is a `fail`-then-clean negative assertion proving `with_scratch_repo` kept `edm-init` out of the real repository. Leave it.
8. **`edm-init:160` writes a generated `<init>/.gitignore`** containing `.edm-state.json`, only when `commit_state_file` is false. An intended, user-committed artifact of the documented `commit_state_file` option, not runtime residue.
9. **`edm-state:638` `cp -p "$f" "${f}.bak"` on every `rmw_state`** -- matched by `.gitignore:9` `.edm-state.json.bak` (unanchored, so relocation-safe), overwritten in place, exactly one per initiative. Bounded. (`edm-state:2862` additionally `rm -f`s a source-carried `.bak` on `migrate-path`.) The per-hook-invocation write cost is ledger CA-061 (L3), not L5.
10. **The smoke suite takes a real lock on the real tracked pattern library**: `wave7-smoke.sh:1910` runs `edm-state update-patterns ZMER srd` through the PATH-resolved real binary, so `cmd_update_patterns` (`edm-state:4053-4068`) resolves `plugins/edm/docs/audit-patterns/srd-audit.md` and `with_state_lock` (`:4115`) creates `plugins/edm/docs/audit-patterns/srd-audit.lock` in the developer's working tree, permanently. Covered by `.gitignore:11`; the seeded finding is a deliberate duplicate so `write_atomic` is never entered and the tracked `.md` is byte-unchanged (asserted at `:1911`, `:1917-1918`). Not actionable -- except that the `.lockd.stale.$$` variant of the same path is L5-1.
11. **`score-artifacts.sh:603` writes `scores.json` non-atomically with no trap** -- destination is inside a gitignored run directory, and the scorer is a pure read-then-write with no signal-sensitive critical section. Bounded.
12. **`.gitlab-ci.yml:399` `LIST_FILE` has an inline `rm -f` (`:420`) and no trap; `:448` has both `mktemp -d` and a trap (`:449`)** -- the CI container filesystem is discarded at job end.
13. **`.gitlab-ci.yml:622-626` publishes `plugins/edm/evals/runs/` as an artifact with `expire_in: 30 days`** -- bounded retention on the CI side, and the checkout-resident copy is covered by `evals/runs/.gitignore`.
14. **`bin/tests/fixtures/code-audit/README.md:49` documents `--out /tmp/scores.json`** -- a hardcoded, fixed-name `/tmp` path in an example command that would collide across users on a shared host. Documentation, not code; the file never reaches `git status`. Cheap improvement (`--out "${TMPDIR:-/tmp}/scores.json"`) but not a defect.
15. **`_harness.sh:64` interpolates `$dir` into its trap body at install time** (`trap 'rm -rf "'"$dir"'"' EXIT INT TERM`) rather than deferring expansion like `edm-state:565`. Checked against the CA-159 failure mode and it is safe: the value lands *inside* the resulting body's double quotes, so an apostrophe in `TMPDIR` does not terminate the quoting. Not a leak.
16. **`hooks/hooks.json` creates no runtime files of its own** -- all five `UserPromptExpansion` command hooks and the `PreToolUse` commit hook are read-only; `SessionStart` (`:8`) and `Stop`/`PreCompact` (`:96`, `:106`) route through `edm-state`, whose file surface is fully enumerated in Part C. The `SubagentStop` prompt (`:117`) instructs `mkdir -p <initiative-dir>/qc` and a write to `qc/qc-summary.md` -- an intended tracked artifact.

---

## Part C -- Fresh runtime-file inventory (every file the code creates, traced independently of the ledger)

| Path created | Creator (file:line) | `.gitignore` coverage | Cleanup / accumulation | Verdict |
|---|---|---|---|---|
| `<init>/.edm-state.json` | `edm-state:1526`; `edm-init:154` | none -- intended tracked artifact | one per initiative | OK |
| `<init>/.edm-state.json.bak` | `edm-state:638` | `.gitignore:9` | overwritten in place | OK |
| `<init>/.edm-state.json.tmp.XXXXXX` | `edm-state:546` | `.gitignore:10` | trap EXIT/INT/TERM/HUP `:575-578` + `mv` `:602` | OK |
| `<init>/.edm-state.lock` | `edm-state:944` | `.gitignore:18` | never unlinked, by design | OK (L5-2 = missing guard comment) |
| `<init>/.edm-state.lockd/` + `/pid` | `edm-state:965`, `:1006` | `.gitignore:19` | trap `:1025-1028` + `rm -rf` `:1048` | OK |
| `<init>/.edm-state.lockd.stale.$$/` | `edm-state:984-987` | **none** | none, ever | **L5-1** |
| `<init>/HANDOFF.md`, `decisions.md`, `code-audit/findings-ledger.{md,jsonl}`, `explorers/`, `code-audit/` | `edm-state:4539`, `:3255-3256`; `edm-init:119-148` | none -- intended tracked artifacts | n/a | OK |
| `<init>/*.md.tmp.XXXXXX` (HANDOFF / ledger staging) | `edm-state:546` | `.gitignore:20` | trap + `mv` | OK |
| `<init>/.gitignore` | `edm-init:160` (only when `commit_state_file=false`) | none -- intended tracked | one per initiative | Noted 8 |
| `docs/audit-patterns/<type>-audit.lock`, `.lockd/` | `edm-state:931-932` via `:4115` | `.gitignore:11-12` | lockdir removed; lockfile retained by design | OK |
| `docs/audit-patterns/<type>-audit.lockd.stale.$$/` | `edm-state:984` | **none** | none, ever | **L5-1** |
| `docs/audit-patterns/<type>-audit.md.tmp.XXXXXX` | `edm-state:546` via `:4037` | `.gitignore:13` + `:20` | trap + `mv` | OK |
| `docs/canonical-sections.md.tmp.XXXXXX` | `edm-sync-canonical-sections:73` | `.gitignore:20` + `:23` | trap EXIT/INT/TERM/**HUP** `:76` | OK (CA-150 closed) |
| `docs/canonical-sections.md` (regenerated in place) | `edm-sync-canonical-sections:104` | tracked; atomic `mv -f` | n/a | OK (CA-065 closed) |
| `docs/canonical-sections.md` (mutated then restored by the suite) | `wave6-smoke.sh:3096` / `:22-29` | tracked | restore trap lacks HUP | **L5-6** |
| `${TMPDIR}/edm-lint-attribution.*`, `${TMPDIR}/edm-lint-mermaid-scan.*` | `edm-lint-artifacts:122`, `:129` | outside repo | one trap `:130`, installed once at top level | Noted 3 |
| `${TMPDIR}/edm-check-grants.*/` | `edm-check-grants:120` | outside repo | trap EXIT `:121` | Noted 3 |
| `${TMPDIR}/edm-tiering-matrix-selftest.*` | `tiering-matrix.sh:140` | outside repo | trap RETURN/EXIT/INT/TERM `:147` | OK (CA-014 closed) |
| `evals/runs/<ts>_<sha>/{run.json,scores.json,*.md,raw/*.json,raw/*.stderr.log}` | `run-eval.sh:114-130`, `:209`, `:296`, `:540`; `score-artifacts.sh:603` | `evals/runs/.gitignore` (`*` + `!.gitignore`) | prune `:553-572`, success path only | **L5-3**, **L5-4** |
| `$(mktemp -d)` fixture scratch tree + throwaway git repo | `run-eval.sh:159-167` | outside repo | `cleanup()` `:146-148` EXIT/INT/TERM; retained under `--provision-only` | Noted 6 |
| Test scratch trees (~40 sites) | `_harness.sh:63`, `:80`; `wave3:15`; `wave4a:15`; `wave5:13`; `wave6:19`; `wave7:22`; `timing.sh:89,133,163,209,239,273`; `harness-smoke.sh:43,61,113,137,217` | outside repo | traps or inline `rm` | Noted 3, 4, 5 |
| `/tmp/edm-ca160-proof` | `wave7-smoke.sh:4659`, checked `:4666`, cleaned only on FAIL `:4668` | outside repo | never pre-cleaned; fixed name | **L5-5** |
| `${TMPDIR}/edm-state-validate.*`, `$(mktemp -d)` (CI) | `.gitlab-ci.yml:399`, `:448` | ephemeral container | `rm -f :420`; trap `:449` | Noted 12 |
| CI artifact `plugins/edm/evals/runs/` | `.gitlab-ci.yml:622-626` | n/a | `expire_in: 30 days` | OK |

No PID files outside the lock directory, no SQLite/`*.db` creation, no `__pycache__`/`dist`/`build`/`.cache` surface, no downloaded model or binary artifacts, and no secrets written to disk anywhere in scope. The only log files are `raw/*.stderr.log` inside run directories, whose lifetime is the run directory's (L5-3/L5-4).

## Summary

| Severity | Count | IDs |
|---|---|---|
| P0 | 0 | -- |
| P1 | 0 | -- |
| P2 | 7 | L5-1 ... L5-7 |
| NOTED | 16 | -- |

Wave 6b's five L5 remediations verify as follows: **CA-149 closed**, **CA-150 closed (both halves)**, **CA-148 closed with one enumeration gap (L5-1)**, **CA-151 closed at the named site, class residual (L5-7)**, **CA-066 partially closed -- the retention policy now exists in code and docs, but only fires on the success path (L5-3) and can over-prune (L5-4)**. The highest-value new finding is **L5-1**: the CA-141 concurrency remediation (Wave 4a) introduced a new path name, `.edm-state.lockd.stale.$$`, that no `.gitignore` glob matches, no trap covers, no test enumerates, and nothing ever cleans -- reintroducing, in a new spelling, exactly the untracked-lock-residue class CA-029/CA-148/CA-149 were filed to eliminate.
