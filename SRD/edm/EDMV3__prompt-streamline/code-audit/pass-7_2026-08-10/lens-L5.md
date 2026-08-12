# Lens L5: Runtime Hygiene -- Pass 7 (2026-08-10)

**Tooling note (CA-130's class, 7+ consecutive rounds):** Write absent from
this lens's delivered runtime tool set (Read/Grep/Glob/WebFetch/WebSearch/
TaskStop only). This report was transcribed by the orchestrator from the lens
agent's final message, after two prior stalled attempts.

## Findings (L5: Runtime Hygiene)

### P1-1 -- `code-audit/findings-ledger.lock` and its lock family are matched by no `.gitignore` pattern anywhere

**File type**: advisory lock file (flock), lock directory, atomic stale-aside
directory, pid file.

**Where created**: `plugins/edm/bin/edm-state:4051`

```bash
  with_state_lock "${init_dir}/code-audit/findings-ledger" _cmd_render_ledger_body \
```

`with_state_lock` derives every lock name from that lockbase (`edm-state:
1121-1123`):

```bash
  local lockfile="${lockbase}.lock"
  local lockdir="${lockbase}.lockd"
  local pidfile="${lockdir}/pid"
```

plus `${lockdir}.stale.$$` from `_edm_reclaim_stale_lockdir` (`edm-state:
1083`). So a real code-audit round produces:

- `<init-dir>/code-audit/findings-ledger.lock` -- **permanent**, deliberately
  never unlinked (the CA-169 comment at `edm-state:1160-1172` forbids `rm -f`
  on a flock lockfile because flock keys on the inode)
- `<init-dir>/code-audit/findings-ledger.lockd/`, `.lockd/pid`,
  `.lockd.stale.<pid>` -- transient (trap-cleaned at `edm-state:1340-1343`),
  but untracked during the window

**In `.gitignore`?** No -- not in any of the three places that could cover it:

| Source | Patterns | Matches `findings-ledger.lock`? |
|---|---|---|
| Repo root `.gitignore:15,30` | `plugins/edm/docs/audit-patterns/*.lock*`, `**/.edm-state.lock*` | No -- both require the `.edm-state.` or `docs/audit-patterns/` anchor |
| Per-initiative block written by `edm-state init` (`edm-state:1973-1978`) | `.edm-state.json.bak`, `.edm-state.json.tmp.*`, `.edm-state.lock*`, `*.md.tmp.*` | No |
| Per-initiative block written by `edm-init` (`edm-init:171-176`) | identical four lines | No |

**Accumulation risk**: one permanent untracked file per initiative, and it is
**never swept on archive or migrate**. `_cmd_archive_move_body` (`edm-state:
2929-2952`) and `_cmd_migrate_path_move_body` (`edm-state:3356+`) both sweep
only `${_dst_lockbase}.lockd` / `.lock` / `.lock.timeout.*`, where
`_dst_lockbase` is derived from the **state** lockbase (`edm-state:2932`).
The ledger lockbase is never swept, so an archived initiative carries
`.archived/<PREFIX>/code-audit/findings-ledger.lock` untracked forever.

**Exposure is real, just invisible on this host.** `with_state_lock` only
creates the `.lock` file on the `command -v flock` branch. macOS has no
`flock(1)`, so this development box takes the mkdir branch and the lockdir is
trap-removed -- which is why `SRD/**/*.lock*` currently globs empty here.
Every Linux dev host and every consumer project on Linux takes the flock
branch, and `edm-state render-ledger` runs on **every** code-audit round
(`skills/code-audit/SKILL.md:118`, step 9a).

**Why the existing guards missed it** (three independent near-misses, worth
citing in the remediation):

1. `plugins/edm/bin/tests/wave7-smoke.sh:5715-5810` is the test that exists
   for exactly this class -- "`.gitignore` actually covers the lock/temp
   paths edm-state derives from lockbase". It hardcodes a single lockbase at
   `:5761` (`local lockbase="${state_file%.json}"`) and enumerates six
   `.edm-state`-derived paths at `:5791-5797`. It never enumerates the
   second lockbase, so it passes green over a live gap.
2. `plugins/edm/README.md:208-227` ("Runtime files to `.gitignore`
   (CA-314)") describes "**the** advisory lock file" in the singular and
   reproduces the same four-line block as the copy-pasteable reference for
   pre-automation initiatives.
3. `edm-init:163-170`'s own comment describes the block as covering "the
   lock file family (`with_state_lock`'s `.lock`/`.lockd`)" -- true of the
   shape, false of the coverage, because the patterns are name-anchored to
   `.edm-state` rather than shape-anchored.

**Fix** (all five parts, or the gap reopens):
- Add shape-anchored patterns to both generator blocks (`edm-state:
  1973-1978`, `edm-init:171-176`): `*.lock`, `*.lockd/`, `*.lockd.stale.*`.
  Shape-anchored, not `findings-ledger.lock*`, so a fourth lockbase added
  later is covered by construction.
- Mirror them into `README.md:222-227` and into the repo-root `.gitignore`
  (this repo's own `SRD/edm/EDMV3__prompt-streamline/` has **no**
  per-initiative `.gitignore` -- see Noted 13 -- so root coverage is what
  protects the dogfooded tree).
- Extend `_cmd_archive_move_body` and `_cmd_migrate_path_move_body` to sweep
  the ledger lockbase at the destination too.
- Extend `wave7-smoke.sh:5791-5797` to iterate **every** `with_state_lock`
  lockbase, derived by grepping the call sites in `bin/edm-state` rather
  than hand-listed, so a lockbase added later fails a test instead of
  drifting silently (the same computed-assertion technique `wave6-smoke.sh`
  already uses for the `schema_at_least(` call-site count).

### P2-1 -- `_write_handoff_body`'s stderr temp file has no cleanup trap, on the plugin's highest-frequency code path

**File type**: temp file under `${TMPDIR:-/tmp}`.

**Where created**: `plugins/edm/bin/edm-state:5318`

```bash
  _of_errfile="$(mktemp "${TMPDIR:-/tmp}/edm-state.audit-converged-stderr.XXXXXX" 2>/dev/null || true)"
```

Removed at `:5322` on the normal path only. **No `trap` covers it.** It runs
inside `with_state_lock`'s locked subshell (called from
`write_handoff_internal`, `edm-state:4998`), and that trap layer
(`edm-state:1340-1343`) owns only `$_STATE_LOCKDIR` -- its INT/TERM/HUP arms
`exit 130`/`143`/`129` without touching the errfile.

**In `.gitignore`?** N/A -- lands in `TMPDIR`, never in a repo, so it does
not surface in `git status`. That is why this is P2 and not P1.

**Accumulation risk**: real, because of frequency. `write-handoff` is reached
from `checkpoint-if-active`, which `hooks/hooks.json:96` and `:106` wire to
**both** the `Stop` and `PreCompact` events -- it fires on essentially every
turn boundary. Each Ctrl-C landing inside a handoff write leaks one file with
no rotation and no cleanup other than the OS's own `/tmp` reaper.

**Inconsistent with every sibling in the codebase**, which is what makes it a
finding rather than a style note: `edm-check-grants:127` (EXIT INT TERM),
`edm-lint-artifacts:141` (EXIT INT TERM), `edm-sync-canonical-sections:84`
(EXIT INT TERM HUP), `write_atomic` `edm-state:672-675` (EXIT INT TERM HUP),
`evals/tiering-matrix.sh:154` (RETURN EXIT INT TERM), `bin/tests/
_harness.sh:85` (EXIT INT TERM). G37/CA-268's comment at `edm-check-
grants:124` asserts that site was "the last EXIT-only cleanup trap in
bin/+evals/" -- the sweep behind that claim could not have found this one,
because it has **no** trap at all and a grep for `trap ... EXIT` does not
surface an absent trap.

**Fix**: register the errfile through the existing `_save_traps`/
`_restore_traps` pair already used by `write_atomic`, or restructure to keep
the `2>&1` fallback path (`edm-state:5326`) as the only path. Also add the
trap-coverage assertion in the same shape as `wave7-smoke.sh:5193-5197` so
the next untrapped `mktemp` in `bin/edm-state` fails a test -- the current
assertions check `write_atomic`'s trap arms specifically, not "every
`mktemp` in this file is trapped".

### P2-2 -- `session_dir_for_test_cwd` has no precondition guard against the invoking user's real `$HOME`

**File type**: fabricated session JSONL fixtures written into
`~/.claude/projects/<encoded-cwd>/`.

**Where created**: `plugins/edm/bin/tests/_harness.sh:390-392`

```bash
session_dir_for_test_cwd() {
  echo "${HOME}/.claude/projects/$(pwd | tr '/.' '-')"
}
```

Callers `mkdir -p "$sess_dir"` and stage `*.jsonl` into it
(`wave7-smoke.sh:5519-5522`, `:7451-7453`, `:7488-7491`; `wave6-smoke.sh:
3735`, `:3788`, `:3908`, `:3959`, `:4043`).

**Current state**: all eight call sites correctly `export HOME=<scratch>`
first -- round 6's G28/CA-351 and G29/CA-264 fixes hold, verified site by
site. The finding is the **absent precondition**, not a live leak: the
helper interpolates whatever `$HOME` happens to be, and its own doc comment
(`_harness.sh:387-389`) documents the encoding formula but never states that
the caller must have exported a scratch `HOME` first.

**In `.gitignore`?** N/A and that is the trap -- the path is outside any
repo, so a regression here is invisible to `git status`, to
`lint:file-type-ban`, and to the `git status --porcelain` containment check
`evals/run-eval.sh:579` performs on its own scratch tree. It also actively
corrupts real data: `get_session_tokens_since` (`edm-state:365`) attributes
cost by picking the most-recently-modified `*.jsonl` in that directory as the
driving session (`attribution_mode: scoped`), so a stray fixture becomes the
"driving session" for the developer's next real `phase-complete` or
`audit-round-complete`.

**Accumulation risk**: unbounded -- nothing ever prunes
`~/.claude/projects/`.

**Fix**: have the helper refuse (via `fail`) when `$HOME` does not resolve
under `${TMPDIR:-/tmp}` or the suite's own `$TMP`, and state the precondition
in its comment. Two consecutive rounds have now found a member of this class
(CA-264 in round 5, CA-351 in round 6); a precondition assertion in the
shared helper is what stops a third.

## Noted / Not Actionable

1. **`.edm-state.lock` left on disk forever** (`edm-state:1205`) --
   documented at length as mandatory for flock inode semantics (CA-169,
   `edm-state:1160-1172`), and covered by root `.gitignore:30` plus both
   per-initiative generator blocks. Correct as written.
2. **`.edm-state.json.bak` never rotated** -- permanent by design for
   `migrate-path` rollback (`edm-init:163-167`); a single file overwritten
   each write, not a growing set; gitignored in all three places.
3. **`write_atomic`'s `${dest}.tmp.XXXXXX` staging files** (`edm-state:644`)
   -- full EXIT/INT/TERM/HUP trap layer (`:672-675`), plus
   `_write_atomic_unwind` on both error returns. Every current call site's
   destination is `.json` or `.md`, so `.edm-state.json.tmp.*` and
   `*.md.tmp.*` cover them; the root `.gitignore`'s `**/*.md.tmp.*` covers
   arbitrary depth. No `.jsonl`/`.txt` destination exists today (checked all
   six call sites: `:1924`, `:4031`, `:4870`, `:5437`, and `rmw_state` at
   `:719`).
4. **`plugins/edm/docs/audit-patterns/<name>.lock*`** from `with_state_lock
   "${pattern_file%.md}"` (`edm-state:4962`) -- covered by root
   `.gitignore:15` (`*.lock*`, widened for exactly this by G25/CA-256). In a
   consumer install the patterns directory lives in the plugin cache, not
   the consumer's repo, and `cmd_update_patterns` skips outright when it is
   not writable (`:4922-4925`).
5. **`docs/canonical-sections.md.tmp.XXXXXX`** (`edm-sync-canonical-
   sections:81`) -- trapped EXIT INT TERM HUP (`:84`), covered by root
   `.gitignore:34` (CA-150).
6. **`evals/runs/<RUN_ID>/`** -- `plugins/edm/evals/runs/.gitignore` is `*`
   + `!.gitignore`; retention-pruned to `EDM_EVAL_KEEP_RUNS` (default 10,
   `run-eval.sh:180-211`); CI retains them as 30-day artifacts
   (`.gitlab-ci.yml:693`); and the 100KB evals ceiling measures `git
   ls-files` only, saying so explicitly on stdout (`.gitlab-ci.yml:
   288-306`). This is the reference implementation of the pattern the rest
   of this lens is asking for.
7. **`--out-dir` skipping pruning, and `--provision-only` leaving
   `SCRATCH_DIR` behind** (`run-eval.sh:18`, `:248`, `:277-281`) -- both are
   the documented contract of an operator-named path; `--provision-only`'s
   whole purpose is to hand the caller a tree to inspect.
8. **`${TMPDIR:-/tmp}/edm-eval-scratch.XXXXXX`** (`run-eval.sh:266`) --
   `cleanup()` trap, plus a `git status --porcelain` containment assertion
   on the scratch tree at `:579`.
9. **All test-harness scratch directories** (`_harness.sh:75`, `:101`;
   `wave7-smoke.sh:24`; `timing.sh:225,268,301,333,350,378`) -- `mktemp -d`
   under `${TMPDIR:-/tmp}` (never a bare template-less `mktemp -d`, which
   `wave7-smoke.sh:1024` now bans by grep), EXIT/INT/TERM traps, and
   deferred-expansion trap bodies per CA-159/G72/CA-232. `timing.sh:270`
   additionally exports a scratch `HOME`.
10. **`hooks/hooks.json` creates no files at all.** Every command hook is
    `command -v`-guarded and writes only to stdout/stderr; the `git commit`
    hook's `srd_root`/`check_dir`/`prefixes`/`staged` are shell variables,
    and its only side effect is `edm-lint-artifacts`' own (trapped,
    TMPDIR-resident) temp files. Nothing in this file is in L5 scope.
11. **The flock branch installs no trap layer** (unlike the mkdir branch at
    `edm-state:1340-1343`) -- correct: the kernel releases the flock when
    FD 200 closes on process death, and the lockfile is intentionally
    permanent, so there is no resource for a trap to own.
12. **`${TMPDIR:-/tmp}/edm-state.lock-timeout.$$`** (`edm-state:1202`) --
    round 5's G17/CA-305 moved it out of the tracked artifact directory and
    switched creation to atomic `mkdir`; round 6's G13/CA-347 gated the
    existence probe on `_lock_ec -eq 99` so a pre-planted marker on a
    shared `/tmp` can no longer misreport a successful write as a timeout.
    Per-PID, outside any repo, and removed on the only branch that creates
    it. The residual window (a signal delivered in the microseconds between
    the subshell's `mkdir` and the outer `die` at `:1220`) leaks one empty
    directory in `TMPDIR` and does not justify a trap.
13. **This repo's own `SRD/edm/EDMV3__prompt-streamline/` has no
    per-initiative `.gitignore`** -- it predates G11/CA-341, and the root
    `.gitignore` covers the `.edm-state.*` family here, so there is no live
    leak. Recorded rather than raised because it explains why the
    dogfooded tree could never have surfaced P1-1 on its own: this repo is
    protected by root patterns that a consumer project does not have, and
    it runs on macOS where the `.lock` file is never created. Do not "fix"
    it by adding a per-initiative `.gitignore` in isolation -- fix the
    generators (P1-1) and the file appears correctly on the next
    `edm-init`.
14. **`edm-lint-artifacts:141`, `_harness.sh:85`, and `edm-check-
    grants:127` omit HUP** where `write_atomic` and `edm-sync-canonical-
    sections` include it -- cosmetic. All three cover EXIT plus the two
    signals a CI runner or an interactive Ctrl-C actually delivers; a
    SIGHUP-only exit path for these three is not reachable in the
    environments this plugin supports.

## Scope covered / not covered

Covered in full: `bin/edm-state` (all six `write_atomic` call sites, all
eleven `with_state_lock` call sites, both `mktemp` sites, both destination
lock sweeps), `hooks/hooks.json` (all six events), `bin/edm-init`,
`bin/edm-lint-artifacts`, `bin/edm-check-grants`, `bin/edm-sync-canonical-
sections`, `bin/tests/_harness.sh`, the `session_dir_for_test_cwd` call-site
sweep across `wave6-smoke.sh` and `wave7-smoke.sh`, `bin/tests/run-all.sh`,
`bin/tests/timing.sh`, all three `evals/*.sh`, `evals/runs/.gitignore`, the
root `.gitignore`, and the `lint:file-type-ban` evals-size ceiling.

Not reached within budget: per-assertion review of `wave3/wave4a/wave4b/
wave5/harness-smoke.sh` scratch handling (all five route through
`_harness.sh`'s audited helpers per the G21/CA-049 comments at
`wave3-smoke.sh:15` and `wave4a-smoke.sh:15`, so residual risk is low), and
the `docs/audit-patterns/` living-library files as write targets.
</content>
