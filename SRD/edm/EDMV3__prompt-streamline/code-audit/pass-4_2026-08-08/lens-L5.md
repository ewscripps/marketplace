# Lens L5 -- Runtime Hygiene (pass 4, round 4, full round)

Scope: `plugins/edm/` (bin/, bin/tests/, evals/, hooks/, docs/, agents/, skills/) plus the
repository-root `.gitignore` and `plugins/edm/evals/runs/.gitignore`.

Method: (1) cross-round ledger filtered to every entry whose Lens(es) column includes L5 and whose
Status is `open`, each re-verified against current code; (2) an independent fresh trace of every
path the code creates at runtime, each walked against every `.gitignore` pattern by hand.

## Verdicts on open L5 ledger entries

| ID | Sev | Ledger status | Round-4 verdict | Evidence |
|----|-----|---------------|-----------------|----------|
| CA-188 | P1 | open (L3+L5) | **FIXED** | `plugins/edm/evals/run-eval.sh:186`, `:189`, `:193`, `:167-171`, `:17-22` |
| CA-212 | P2 | open | **FIXED** | `.gitignore:18-24`, `.gitignore:12`, `plugins/edm/bin/tests/wave7-smoke.sh:5241-5258` |
| CA-213 | P2 | open | **FIXED** | `plugins/edm/bin/edm-state:994-999` |
| CA-214 | P2 | open | **FIXED** | `plugins/edm/evals/run-eval.sh:167-206`, `:225`, `:228`, `:231`; `plugins/edm/evals/README.md:43-50` |
| CA-215 | P2 | open (L5+L8) | **FIXED** | `plugins/edm/bin/tests/wave7-smoke.sh:4999-5016` |
| CA-216 | P2 | open | **FIXED** | `plugins/edm/bin/tests/wave6-smoke.sh:31-34` |
| CA-217 | P2 | open | **FIXED** | `plugins/edm/evals/score-artifacts.sh:522-535` |

All seven open L5 entries are closed. Detail per entry:

**CA-188 (retention prune deletes directories it does not own; off-by-N keep window) -- FIXED.**
Both named defects are gone. The ownership filter is applied *before* both the count and the
window, from one listing: `run-eval.sh:186` is
`run_dirs="$(ls -1t "$OUT_ROOT" 2>/dev/null | grep -E '^[0-9]{8}T[0-9]{6}Z_' || true)"`, `:187`
counts that filtered list, and `:193` windows the same variable with `tail -n "+$((keep + 1))"`, so
the two can no longer disagree. The explicit-root opt-in landed: `OUT_ROOT_EXPLICIT` is set at `:92`
and flipped at `:98`, and `prune_old_runs:168-171` returns early unless
`EDM_EVAL_PRUNE_EXPLICIT_OUT=true`. The `--out` help line now documents the retention behaviour
(`:17-22`), as the finding required, and `evals/README.md:52-59` states it again.

**CA-212 (stale-lock aside matched no gitignore pattern, no test) -- FIXED.**
`.gitignore:24` was widened from an exact-name directory match to `**/.edm-state.lockd*`, which
matches the `${lockdir}.stale.$$` name `_edm_reclaim_stale_lockdir` creates at `edm-state:967-968`;
the rationale is recorded in place at `.gitignore:18-22`. The pattern-library twin is covered by the
pre-existing `plugins/edm/docs/audit-patterns/*.lockd*` at `.gitignore:12`. The test half also
landed: `wave7-smoke.sh:5244` derives `lockdir_stale="${lockdir}.stale.$$"` using the same formula as
the source rather than a hand-typed guess, and `:5258` runs it through the same `git check-ignore -q`
loop against a real copy of the repository `.gitignore` in a scratch repo.

**CA-213 (no comment recording that the flock file must never be unlinked) -- FIXED.**
`edm-state:994-999` now carries the comment, immediately above the acquisition at `:1012`. It names
CA-169, gives the inode-keyed rationale ("unlinking a released lock file lets a later contender
open()+flock() a freshly created inode at the same path"), and names the `.gitignore` line that
hides the file. The narrow sanctioned exception is separately documented where it is taken, at
`edm-state:2646-2659` and `:3028-3035`.

**CA-214 (retention ran only on the success path) -- FIXED.**
The prune is extracted into `prune_old_runs()` at `run-eval.sh:167-206` and called from `cleanup()`
on both arms -- `:225` on the partial/exit-4 path and `:228` on every other path -- under
`trap cleanup EXIT INT TERM` at `:231`. There is no longer a call site at the bottom of the success
path; `:627-632` explicitly records that the EXIT trap is the single call site. `evals/README.md:45-50`
was amended to state the every-exit-path contract, as the finding required.

**CA-215 (fixed `/tmp` security-probe path) -- FIXED.**
`wave7-smoke.sh:5004` is now `ca160_proof="${TMP}/edm-ca160-proof"` with `rm -f "$ca160_proof"` at
`:5005` immediately before the probe, and `$TMP` is the suite's own trap-covered, TMPDIR-honouring
scratch root (`:24-25`). The rationale is recorded at `:4999-5003`. The fix was also applied
forward: the two new CA-157 injection probes added this wave use the same shape at `:5050` and
`:5059`, each with its own pre-probe `rm -f`.

**CA-216 (wave6 trap missing HUP over a tracked-file mutation) -- FIXED.**
`wave6-smoke.sh:34` is `trap cleanup_wave6 EXIT INT TERM HUP`, with the rationale at `:31-33`
naming the tracked-file consequence. `cleanup_wave6` (`:24-30`) restores `T41_CANONICAL` from
`T41_BACKUP` and removes both the backup and `$TMP`.

**CA-217 (second tracked fixture root unguarded) -- FIXED.**
`score-artifacts.sh:532` is now `*/fixtures/*|*/fixtures)`, a segment match that covers both tracked
fixture roots (`bin/tests/fixtures/` and `evals/fixtures/tiny-svc/`) rather than enumerating one,
and `:533` dies unless an explicit `--out` is supplied. The reasoning that a real run directory can
never match is recorded at `:527-529`, and the help text at `:17-21` was updated to say both roots.

## Findings (L5: Runtime Hygiene)

### L5-1 (P2) -- `with_state_lock`'s new flock timeout-marker file matches no `.gitignore` pattern, is covered by no trap, and is enumerated by no test

**File type**: side-channel marker file (lock-adjacent), created inside a git-TRACKED directory.

**Where it is created**: `plugins/edm/bin/edm-state:1010` derives it and `:1012` writes it:

```bash
_lock_timeout_marker="${lockfile}.timeout.$$"
rm -f "$_lock_timeout_marker" 2>/dev/null || true
( flock -w 10 200 || { : > "$_lock_timeout_marker" 2>/dev/null; exit 99; }; "$@" ) 200>"${lockfile}" || _lock_ec=$?
```

This is new this wave -- the G49 remediation that replaced the exit-99 lock-timeout sentinel with a
marker file. `lockfile` is `${lockbase}.lock`, so the marker resolves to two shapes, both in tracked
directories:

- `<initiative-dir>/.edm-state.lock.timeout.<pid>` -- lockbase is `${state_file%.json}` at
  `edm-state:684`, `:1686`, `:2640`, `:3084`, `:3633`, `:3714`, `:3957`, `:4447`.
- `plugins/edm/docs/audit-patterns/<doc>.lock.timeout.<pid>` -- lockbase is `${pattern_file%.md}` at
  `edm-state:4411`.

**Is it in `.gitignore`? No.** Every pattern walked by hand against
`.edm-state.lock.timeout.12345` and `code-audit-patterns.lock.timeout.12345`:

| `.gitignore` line | Pattern | Matches? | Why not |
|---|---|---|---|
| `:9` | `.edm-state.json.bak` | no | exact name |
| `:10` | `.edm-state.json.tmp.*` | no | requires `.json.tmp.` |
| `:11` | `plugins/edm/docs/audit-patterns/*.lock` | no | `*.lock` requires the name to **end** in `.lock`; this one ends in `.<pid>` |
| `:12` | `plugins/edm/docs/audit-patterns/*.lockd*` | no | requires the literal `lockd`; this is `lock.` |
| `:13` | `plugins/edm/docs/audit-patterns/*.tmp.*` | no | requires `.tmp.` |
| `:23` | `**/.edm-state.lock` | no | exact basename match |
| `:24` | `**/.edm-state.lockd*` | no | requires `.edm-state.lockd` prefix; this is `.edm-state.lock.` |
| `:25` | `**/*.md.tmp.*` | no | requires `.md.tmp.` |
| `:28` | `plugins/edm/docs/*.tmp.*` | no | requires `.tmp.` |

Note the near-miss: `:24`'s CA-212 widening was to `.lockd*`, which is one character away from
covering this but does not, because the marker hangs off `.lock`, not `.lockd`.

**Accumulation risk: real, unbounded, and visible in `git status` forever.** No trap covers the
window. The flock branch of `with_state_lock` installs **no signal traps at all** -- the only trap
layer in the function is on the mkdir branch at `edm-state:1115-1118`, and `write_atomic`'s layer at
`:622-625` is scoped to its own staging file and is not installed until the locked body runs. The
marker is written inside the subshell and removed by the parent at `:1014`; between those two
points, and for the whole preceding `flock -w 10` wait during which the interrupt that produces this
state is delivered, nothing will remove it. One file accrues per PID that experiences a lock
timeout, inside a tracked artifact directory, and nothing ever reclaims it (the pre-clean at `:1011`
only helps if the same PID number recurs). `_cmd_archive_move_body:2659` and
`_cmd_migrate_path_move_body:3035` remove `${_lockbase}.lockd` and `${_lockbase}.lock` before their
renames but not this name, so a leaked marker also travels into `.archived/`.

**No test enumerates it.** The CA-148 `.gitignore` coverage case at `wave7-smoke.sh:5253-5258`
enumerates exactly five derived names -- lockfile, lockdir, state staging tmp, markdown staging tmp,
and (new this wave) the lockdir stale-aside. The timeout marker is absent, so the regression class
CA-148 exists to prevent is re-opened for this one name. The G49 tests at `wave7-smoke.sh:6035-6038`
assert only that the marker mechanism exists in the source text; the live sub-case at `:6050-6076`
asserts the timeout message and never checks for a leftover file.

This is CA-212's class exactly: a new path name introduced by a remediation, matched by no pattern,
covered by no trap, enumerated by no test. Reachability is Linux/CI (the branch requires `flock(1)`,
so macOS takes the mkdir branch) plus 10 s of genuine contention -- reachable via the unprompted
`Stop`/`PreCompact` `checkpoint-if-active` hooks racing a phase command, but uncommon, which caps
this at P2.

**Fix**: make the two lock patterns suffix-tolerant so the marker is covered by construction rather
than by enumeration -- `**/.edm-state.lock*` at `.gitignore:23` and
`plugins/edm/docs/audit-patterns/*.lock*` at `:11`. Both new forms subsume their current exact-name
lines *and* the `.lockd*` lines at `:24`/`:12`, so this is a net simplification, and nothing tracked
anywhere in the tree matches either. Then add the derived name to the enumeration at
`wave7-smoke.sh:5253-5258` using the same `${lockfile}.timeout.$$` formula the source uses, and add
`${_lockbase}.lock.timeout.*` to the two pre-rename cleanups at `edm-state:2659` and `:3035`.

### L5-2 (P2) -- the CA-160 line-cap probe writes a session-JSONL fixture into the developer's REAL `${HOME}/.claude/projects/`, outside the suite's scratch tree and outside its cleanup trap

**File type**: fabricated Claude Code session JSONL plus its containing directory, created under the
invoking user's real home directory.

**Where it is created**: `plugins/edm/bin/tests/wave7-smoke.sh:5020-5034`:

```bash
ca160b_scratch="$(mktemp -d "${TMP}/edm-ca160b.XXXXXX")"
(
  cd "$ca160b_scratch" || exit 1
  sess_dir="${HOME}/.claude/projects/$(pwd | tr '/.' '-')"
  mkdir -p "$sess_dir"
  jq -cn '...' > "${sess_dir}/a.jsonl"
  ...
  rm -rf "$sess_dir"
) > "${TMP}/ca160b.out" 2>&1 || true
```

`:5023` is the **only** occurrence of `$HOME` anywhere in this 6,084-line suite, and `HOME` is never
overridden in the file, so this resolves to the real home directory of whoever runs the suite --
including a contributor running `bin/tests/run-all.sh` locally, which `plugins/edm/CLAUDE.md`
("Testing changes", step 5) instructs every contributor to do before pushing.

**Is it in `.gitignore`?** Not applicable and not the point -- it is outside the repository, so it
never reaches `git status`. The defect is the location and the missing cleanup coverage, which is
squarely in this lens's third category (files written to unexpected locations).

**The false-alarm filter's consistent-project-pattern test fails.** Every other site in the tree that
needs a synthetic sessions directory first redirects `HOME` at a `mktemp -d` scratch tree inside the
suite's own trap-covered root: `wave6-smoke.sh:884-886`, `:3303-3305`, `:3356-3358`, `:3476-3481`,
`:3527-3529`, `:3611-3613`, and `timing.sh:150-151` (`export HOME="${TMP_PC}/home"`). The shared
helper written for exactly this, `_harness.sh:324-327`'s `session_dir_for_test_cwd`, is used by
wave6 at `:3482` *after* its HOME override; `wave7-smoke.sh:5023` re-derives the identical
`${HOME}/.claude/projects/$(pwd | tr '/.' '-')` expression by hand and skips the override. So this is
the single outlier against seven sibling sites plus a purpose-built helper, not a project pattern.

**Accumulation risk: bounded but real, and invisible to every cleanup the suite has.** `rm -rf
"$sess_dir"` at `:5033` is the subshell's last statement and runs only on the success path. The
subshell inherits the file's `set -euo pipefail` (`:8`), so a failure of `cd`, `mkdir -p` or the `jq`
write aborts before it -- and the whole block is `|| true`-swallowed at `:5034`, so the abort is
silent. A `Ctrl-C` during the probe does the same: the suite's `trap 'rm -rf "$TMP"' EXIT INT TERM`
at `:25` covers `$TMP`, and `$sess_dir` is not under `$TMP`. Each such run leaves one directory
containing one JSONL under the user's home, and nothing in the tree ever reclaims it. Secondary:
under `set -u` an unset `HOME` makes `:5023` an unbound-variable abort that the `|| true` converts
into two empty greps at `:5035-5036` and a confusing pair of failed assertions rather than a named
error.

**Fix**: add `export HOME="$(mktemp -d "${TMP}/ca160b-home.XXXXXX")"` inside the subshell before
`:5023` and replace the hand-rolled path with a call to `session_dir_for_test_cwd`
(`_harness.sh:327`), matching the six wave6 sites. Behaviour-identical -- `session_dir_for_cwd`
(`edm-state:272`) reads `${HOME}` at runtime, which is precisely why the wave6 override works.

## Fresh runtime-file inventory (independent of the ledger)

Every path the tree creates at runtime, traced from `mktemp`/`mkdir`/`touch`/`cat >`/`: >`/`>` and
`write_atomic` call sites, then walked against `.gitignore`. Two entries are the findings above;
the other eighteen are clean.

| # | Runtime path | Created at | Gitignored? | Cleanup | Verdict |
|---|---|---|---|---|---|
| 1 | `<init-dir>/.edm-state.json` | `edm-state:1677`, `edm-init:119` | tracked by design (`commit_state_file`) | n/a | OK |
| 2 | `<init-dir>/.edm-state.json.bak` | `edm-state:670` (every `rmw_state`) | `.gitignore:9` | overwritten in place, one per initiative | OK |
| 3 | `<dest>.tmp.XXXXXX` (4 dests: state, HANDOFF.md, findings-ledger.md, pattern docs) | `edm-state:597` | `.gitignore:10`, `:25`, `:13`, `:28` | trap EXIT/INT/TERM/HUP `:622-625`, then `mv -f` `:640` | OK |
| 4 | `<lockbase>.lock` | `edm-state:1012` (`200>`) | `.gitignore:23`, `:11` | deliberately never unlinked -- CA-169, comment `:994-999` | OK |
| 5 | `<lockbase>.lockd/` and its `pid` file | `edm-state:1052` | `.gitignore:24`, `:12` (dir match ignores contents) | trap `:1115-1118`, `rm -rf` `:1145` | OK |
| 6 | `<lockbase>.lockd.stale.<pid>/` | `edm-state:968` | `.gitignore:24`, `:12` | `rm -rf` `:970` | OK (CA-212) |
| 7 | **`<lockbase>.lock.timeout.<pid>`** | `edm-state:1010`, `:1012` | **no pattern matches** | `rm -f` `:1011`/`:1014`, no trap | **L5-1** |
| 8 | `.git/index.lock.stale.<pid>` | `edm-state:3398` | inside `.git/` -- never surfaced by `git status` | `rm -f` `:3400` | OK |
| 9 | `<init-dir>/code-audit/`, `explorers/`, `decisions.md` | `edm-state:3550`, `edm-init:122-143` | tracked by design | n/a | OK |
| 10 | `${TMPDIR}/edm-lint-attribution.*`, `${TMPDIR}/edm-lint-mermaid-scan.*` | `edm-lint-artifacts:133`, `:140` | outside repo | trap EXIT INT TERM `:141`; hoisted to script scope so the hot commit-hook path enters the window once per process | OK |
| 11 | `${TMPDIR}/edm-check-grants.*/` (+ 6 files inside) | `edm-check-grants:123`, `:196-232`, `:431` | outside repo | trap EXIT only `:124` | noted |
| 12 | `plugins/edm/docs/canonical-sections.md.tmp.*` | `edm-sync-canonical-sections:81` | `.gitignore:28`, `:25` | trap EXIT INT TERM HUP `:84` | OK |
| 13 | `${TMPDIR}/edm-tiering-matrix-selftest.*` | `tiering-matrix.sh:140` | outside repo | trap RETURN EXIT INT TERM `:147` | OK |
| 14 | `plugins/edm/evals/runs/<TS>_<SHA>/**` (raw payloads, stderr logs, run.json, scores.json) | `run-eval.sh:320`, `:143`, `:148`, `:624` | `plugins/edm/evals/runs/.gitignore:6` (`*`, with `!.gitignore`) | `prune_old_runs` on every exit path; CI artifact `expire_in: 30 days` (`.gitlab-ci.yml:642`) | OK |
| 15 | eval scratch fixture clone (`mktemp -d`, full fixture copy + git repo) | `run-eval.sh:235` | outside repo | `cleanup:220-222` under trap EXIT INT TERM `:231` | noted |
| 16 | `<run-dir>/scores.json` or `--out FILE` | `score-artifacts.sh:630` | run dir gitignored; tracked fixture roots refused at `:532-533` | n/a | OK |
| 17 | seven suites' scratch trees (~60 `mktemp` sites) | `wave7:24`, `wave6:21`, `_harness.sh:66`/`:92`, `harness-smoke.sh:291`, `timing.sh:104-288` | all under `${TMPDIR:-/tmp}` | per-suite traps; `timing.sh` `rm -rf` per mode | OK |
| 18 | fake-`HOME` sessions dirs | `wave6:3482` etc., `timing.sh:150` | under `$TMP` | suite trap | OK |
| 19 | **`${HOME}/.claude/projects/<enc-cwd>/a.jsonl`** | `wave7-smoke.sh:5023-5026` | outside repo **and** outside `$TMP` | `rm -rf` `:5033`, success path only | **L5-2** |
| 20 | CI job scratch | `.gitlab-ci.yml:466` | runner-local | trap EXIT `:467` | OK |

Categories hunted and **not** present anywhere in the tree: PID files outside a lockdir, SQLite/`.db`
files, `__pycache__`/`*.pyc`/`.cache/`/`dist/`/`build/`, downloaded artifacts or model files,
generated configs or secrets written to disk, and unrotated log files (the only logs are
`<run-dir>/raw/*.stderr.log`, which are inside the retention-managed, gitignored `evals/runs/`).

## Noted / Not Actionable

1. **`run-eval.sh:231`'s `trap cleanup EXIT INT TERM` omits HUP** while the driver's own header
   (`:36-40`) and `evals/README.md:45-46` both state that pruning runs on "every exit path". This is
   the longest-running process in the tree (up to 3 x 2700 s), so a terminal disconnect mid-run is
   the most likely occurrence of the class anywhere. Not filed: both resources at risk are already
   safe -- the scratch clone (`:235`) is under `TMPDIR` (ephemeral, never in `git status`), and an
   unpruned `RUN_DIR` sits inside `evals/runs/`, which `evals/runs/.gitignore:6` ignores wholesale
   and which the *next* successful run's prune reclaims because it matches the run-ID shape. Filter
   criteria 1 and 3 both apply. Cheap hardening if someone is in the file anyway: add `HUP`.
2. **`edm-check-grants:124` uses `trap 'rm -rf "$WORKDIR"' EXIT`** where its two sibling checkers use
   `EXIT INT TERM` (`edm-lint-artifacts:141`) and `EXIT INT TERM HUP`
   (`edm-sync-canonical-sections:84`). The leaked resource is a `${TMPDIR:-/tmp}` scratch directory
   holding six small text files -- ephemeral, never in `git status`. Filter criterion 3.
3. **Five further traps omit HUP** -- `edm-lint-artifacts:141`, `_harness.sh:76` and `:104`,
   `harness-smoke.sh:292`, `wave7-smoke.sh:25`, `tiering-matrix.sh:147`. All own `TMPDIR`-only
   resources. Filter criterion 3. Listed together so a future round does not re-file them one at a
   time; the two sites where the resource was a tracked file (CA-150, CA-216) are both fixed.
4. **`prune_old_runs`'s window is computed from `ls -1t`, not `find -type d`**, so a regular *file*
   whose name matches `^[0-9]{8}T[0-9]{6}Z_` would still consume one keep slot; the `[ -d ]` test at
   `run-eval.sh:196` prevents deleting it but does not correct the offset. This is the surviving
   sliver of CA-188 defect 2. Not actionable: the run-ID naming filter added by the same fix means
   only a deliberately adversarial filename can reach it, nothing in the tree creates such a file,
   and the consequence is keeping one run too many rather than deleting one too few.
5. **`edm-state:3398`'s `.git/index.lock.stale.<pid>`** is created inside `.git/`, which git never
   reports in `git status`, and is removed on the next line (`:3400`). Filter criterion 1/3. (The
   *correctness* of the surrounding removal is CA-203, L3's territory, not this lens's.)
6. **`.edm-state.json.bak` is never deleted** (`edm-state:670` writes it on every state mutation).
   Not accumulation: it is one file per initiative, overwritten in place rather than appended to,
   and `.gitignore:9` is unanchored so it stays covered through an `srd_root` relocation, an
   `archive`, and a `migrate-path`. Deliberate -- `edm-state:3090-3093` documents why a carried-over
   `.bak` must survive a rollback.
7. **CA-169 (NOTED, prior round) remains correctly unapplied and is now documented.** The flock file
   at `edm-state:1012` is deliberately never unlinked; the comment CA-213 asked for is at `:994-999`.
   Do not "fix" this.
8. **CA-170 / CA-171 (NOTED, prior rounds) unchanged and still correct.** `timing.sh` carries no
   trap on any mode and `harness-smoke.sh:45`/`:63`/`:115` use inline `rm -f`, but every scratch
   tree honours `TMPDIR` and the measuring modes `rm -rf` on the happy path (`timing.sh:171` etc.),
   so the residue is bounded ephemeral disk and never reaches `git status`.
9. **CA-181 (NOTED, round 2) not re-investigated.** `_edm-lint-lib.sh` tracked-status was resolved
   against a stale snapshot last round; nothing this round suggests it regressed.
10. **`plugins/edm/evals/runs/.gitignore` uses `*` + `!.gitignore`**, which is the correct
    self-ignoring form -- the directory survives in git so `run-eval.sh:320`'s `mkdir -p` has a
    parent, while no run output can ever be staged. Verified rather than assumed, because
    `run-eval.sh:627` and `README.md:60-61` both make load-bearing claims about it.

## Meta

`Write` was absent from this lens's delivered runtime tool set despite the frontmatter grant
(ledger CA-130). Both `lens-L5.md` and `lens-L5.jsonl` were transcribed by the orchestrator from
the agent's returned text.
