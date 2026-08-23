# Code Audit -- Lens L5: Runtime Hygiene

Round 8 (pass-8_2026-08-16), round type: full.
Scope: plugins/edm/bin/*, plugins/edm/bin/tests/*, plugins/edm/agents/*.md,
plugins/edm/skills/*/SKILL.md, plugins/edm/hooks/hooks.json, plugins/edm/monitors/monitors.json,
plugins/edm/evals/*.sh, plugins/edm/CLAUDE.md, plugins/edm/README.md, plugins/edm/CHANGELOG.md,
plus repository-root .gitlab-ci.yml and .gitignore.

## Prior-round findings re-verified

| Prior ID | Status | Evidence |
|---|---|---|
| CA-372 | fixed | `bin/tests/fixtures/code-audit/README.md:49` uses `--out "${TMPDIR:-/tmp}/edm-scores.json"`; lines 50-54 carry the CA-151 rationale. No bare `/tmp/scores.json` remains. |
| CA-399 | fixed | `bin/edm-state:5491-5506` wraps the audit-converged errfile in `_save_traps` + EXIT/INT(130)/TERM(143)/HUP(129) traps calling `_write_atomic_cleanup "$_OF_ERRFILE_FOR_TRAP"`, then `_restore_traps`. CA-159 deferred expansion honored. |
| CA-400 | fixed | `bin/tests/_harness.sh:386-395` refuses (`exit 1`) unless `$HOME` is under `${TMPDIR:-/tmp}`, before interpolating it into the session-dir path. |

## Findings (L5: Runtime Hygiene)

| ID | Sev | File:line | Finding |
|---|---|---|---|
| L5-001 | P2 | plugins/edm/evals/score-artifacts.sh:687 | `cmd_compare` temp files: template-less `mktemp`, no cleanup trap, and invisible to the repo's own tripwire |
| L5-002 | P2 | plugins/edm/bin/tests/timing.sh:268 | Five timing modes leak their scratch tree on any failure or interrupt (tail-position `rm -rf`, no trap) under `set -euo pipefail` |

### L5-001 [P2] `cmd_compare` temp files: no template, no trap, and the repo's own guard cannot see them

**File type**: two transient JSON staging files.
**Created at**: `plugins/edm/evals/score-artifacts.sh:687-688`

    ta="$(mktemp)"
    tb="$(mktemp)"
    jq '. + {complete: true}' "$a" > "$ta"
    jq '. + {complete: true}' "$b" > "$tb"
    "${SCRIPT_DIR}/../bin/edm-compare-eval" "$tb" "$ta"
    rc=$?
    rm -f "$ta" "$tb"

**In .gitignore?** Not applicable in the normal case (files land under the system temp
directory, outside any worktree) -- but see the naming defect below, which is what makes this
worth fixing rather than dismissing.

**Three distinct defects in one call site:**

1. **No cleanup trap.** `rm -f` at line 693 is tail-position only. A SIGINT/SIGTERM/SIGHUP
   delivered while `edm-compare-eval` is running -- the longest-lived statement between the
   `mktemp` and the `rm -f` -- leaks both files. This is the identical class already fixed at
   four other sites in this tree: CA-014 (`evals/tiering-matrix.sh:154`, RETURN widened to
   `RETURN EXIT INT TERM`), CA-150 (`bin/edm-sync-canonical-sections:84`, HUP added),
   G37/CA-268 (`bin/edm-check-grants:127`, EXIT widened to `EXIT INT TERM`), and CA-399
   (`bin/edm-state:5499-5502`, this lens's own round-7 finding). This is the last untrapped
   `mktemp` in `bin/` + `evals/`.

2. **Template-less `mktemp`.** Every other `mktemp` in `bin/` and `evals/` uses the house form
   `"${TMPDIR:-/tmp}/edm-<purpose>.XXXXXX"`. These two produce a generic `tmp.XXXXXXXX` with no
   `edm-` prefix, so a leaked pair is unattributable to this plugin during a temp-directory
   sweep -- exactly the diagnosis problem the house naming convention exists to prevent.

3. **The repo's own tripwire cannot catch it.** `bin/tests/wave7-smoke.sh:1033` (T61 AC11 /
   G20/CA-348) greps `bin/` and `evals/` for GNU-only and template-less idioms, including a
   bare `mktemp -d\)`. That alternation matches only the `-d` form; `mktemp)` (no `-d`) walks
   straight past it. So the guard added specifically to stop template-less `mktemp` from
   shipping has a hole the size of the non-directory form, and this call site is sitting in it.

**Accumulation risk**: low-moderate. `--compare` is a low-frequency, developer-invoked mode
(the script's own header calls it a testability affordance for AC4, and CI's `eval:nightly`
uses `bin/edm-compare-eval` directly, not this wrapper), so leaks accrue slowly. But they accrue
in the shared temp directory with untraceable names and nothing prunes them.

**Fix**: adopt the house form and the four-signal trap the sibling sites already use, and close
the tripwire hole so the next occurrence fails CI instead of shipping.

    ta="$(mktemp "${TMPDIR:-/tmp}/edm-compare-a.XXXXXX")" || die "mktemp failed"
    tb="$(mktemp "${TMPDIR:-/tmp}/edm-compare-b.XXXXXX")" || die "mktemp failed"
    _SA_TA="$ta"; _SA_TB="$tb"
    trap 'rm -f "${_SA_TA:-}" "${_SA_TB:-}"' EXIT INT TERM HUP

(paths referenced through dedicated variables inside single quotes, per CA-159). Then widen
`wave7-smoke.sh:1033`'s alternation from `mktemp -d\)` to `mktemp( -d)?\)` so the non-directory
template-less form is banned too.

### L5-002 [P2] Five timing modes leak their scratch tree on any failure or interrupt

**File type**: scratch directory trees (generated markdown corpora, synthetic JSONL ledgers,
scratch SRD roots and fake `$HOME`s).
**Created at**: `plugins/edm/bin/tests/timing.sh:268` (`--phase-complete`), `:301` (`--ledger`),
`:333` (`--session-start`), `:350` (`--lint`), `:378` (`--mermaid-ratio`)

Each mode follows the same shape: `TMP_XX="$(mktemp -d "${TMPDIR:-/tmp}/edm-timing-<mode>.XXXXXX")"`
at the top, work in the middle, a single unguarded `rm -rf "$TMP_XX"` as the last statement of the
`case` arm. There is **no trap anywhere in the file**, and line 24 sets `set -euo pipefail`.

**In .gitignore?** Not applicable -- these live under the system temp directory, so a leak never
reaches `git status`. This is a disk-accumulation and diagnosability finding, not a
git-cleanliness one.

**Why the tail-position `rm -rf` is not enough:**

- Under `-e`, any non-zero command before the tail aborts the script outright. Every mode runs
  several `"$EDM_STATE"` invocations and `_measure_p95` calls that are *not* individually guarded
  (`--ledger:304-305`, `--session-start:336`, `--lint:353`, `--mermaid-ratio:381` all run bare).
  A regression in `edm-state` -- precisely what this harness exists to detect -- takes the script
  down before its own cleanup runs.
- A Ctrl-C during a measurement loop (these are timing runs; some take tens of seconds) leaks
  unconditionally.
- The leak is not trivially sized: `--lint` and `--mermaid-ratio` each generate 30 files x 333
  lines (`:354-360`, `:382-388`), `--mermaid-ratio` then appends a mermaid fence to all 30
  (`:391-394`), and `--ledger` writes a 500-line synthetic JSONL (`:311-321`). Every failed run
  leaves a full copy.
- The file **already knows** the tail-only shape is insufficient: `--mermaid-ratio` hand-rolls an
  extra `rm -rf "$TMP_MR"` at line 402 before its `exit 3` early return. That is the same fix
  applied once, by hand, for one of the several ways out of the arm.

**The correct primitive is already in scope and unused.** `timing.sh:31` sources
`_harness.sh`, which exports `harness_scratch_dir` (`_harness.sh:72-87`) -- built for exactly
this: `mktemp -d` under `${TMPDIR:-/tmp}` plus an `EXIT INT TERM` trap installed in the caller's
own shell, using the CA-159 deferred-expansion form. Its header (`_harness.sh:58-71`) records
that it exists because three older suites hand-rolled a bare `mktemp -d` + trap preamble that did
neither correctly (CA-049). `timing.sh` is the remaining file in `bin/tests/` still carrying the
pre-CA-049 shape; it takes the shared plugin-root export from `_harness.sh` and nothing else.

**Accumulation risk**: moderate. `timing.sh` is not in `run-all.sh`'s discovery glob (it is not
`*-smoke.sh`) and not in CI, so it is developer-invoked -- but it is invoked precisely when
something is slow or broken, i.e. exactly when a mode is most likely to abort mid-run.

**Fix**: install one process-wide trap covering all five modes and drop the per-mode tails --

    _TIMING_SCRATCH=""
    trap 'rm -rf "${_TIMING_SCRATCH:-}"' EXIT INT TERM HUP

setting `_TIMING_SCRATCH` at each `mktemp -d`; or route each mode through
`harness_scratch_dir`, which already does this. Leave `--generate-fixture` (`:225`) alone: it
deliberately publishes its path for reuse by `--subcommands`/`--all-lint` and must not
self-delete (see N1).

## Noted / Not Actionable

- **N1 -- `run-eval.sh --provision-only` deliberately retains its scratch tree.** `cleanup()`
  (`evals/run-eval.sh:248`) skips the `rm -rf` when `PROVISION_ONLY=true`, so every invocation
  mints a `${TMPDIR:-/tmp}/edm-eval-scratch.XXXXXX` git repo (`:266-274`) that nothing prunes.
  Deliberate and correct: the mode's entire contract is to print a path for the caller to
  inspect (`:281`), and deleting it would make the mode useless. Temp-directory resident, never
  in a worktree, and no automated caller exists -- `evals/README.md:63-76` documents it purely as
  a manual network-isolation check. Not actionable.
- **N2 -- `docs/audit-patterns/<type>.lock` persists forever inside the tracked plugin tree.**
  `edm-state update-patterns` locks on `"${pattern_file%.md}"` (`bin/edm-state:5096`), so the
  flock branch creates e.g. `plugins/edm/docs/audit-patterns/srd-audit.lock` and never unlinks
  it (CA-169: flock's exclusion is keyed on the inode, so unlinking a released lock file breaks
  mutual exclusion). Verified covered twice over by the root `.gitignore`: line 15
  (`plugins/edm/docs/audit-patterns/*.lock*`) and line 35 (`**/*.lock`). Also created during CI
  smoke runs -- `bin/tests/wave7-smoke.sh:2096` invokes the real `edm-state update-patterns`
  against the real doc via `with_scratch_repo`'s PATH prepend, and Alpine's busybox provides
  `flock`. `git status` stays clean either way. Not actionable.
- **N3 -- `update-patterns` writes into the plugin's own install directory.** `patterns_dir` is
  `"${SCRIPT_DIR}/../docs/audit-patterns"` (`bin/edm-state:5024`), which sits against
  `plugins/edm/CLAUDE.md`'s bin/ note ("Operates against the project's working directory (no
  plugin-relative paths)"). The runtime-hygiene half -- "may not be writable in production" -- is
  already handled: `bin/edm-state:5056-5059` tests `[[ -w "$pattern_dir" ]]` and skips with a
  named "plugin may be installed read-only" message and exit 0. What remains is a
  documentation-consistency question, which belongs to another lens. Not actionable here.
- **N4 -- flock-timeout marker directory under TMPDIR.** `bin/edm-state:1226-1229` derives
  `${TMPDIR:-/tmp}/edm-state.lock-timeout.${BASHPID:-$$}` and creates it with `mkdir` only in
  the timeout arm; line 1243 removes it before the `die`. A signal landing in the microseconds
  between leaves one empty directory, and line 1227 pre-removes a stale one at the same path on
  the next run with that PID. Empty, ephemeral-mount, self-healing. Not actionable.
- **N5 -- stale justification comments in the root `.gitignore`.** Lines 11-14 and 26-29 justify
  the `*.lock*` widening by naming "the G49 flock-timeout marker path (`${lockfile}.timeout.$$`,
  i.e. `*.lock.timeout.<pid>`)" as an in-tree path. G17/CA-305 relocated that marker under
  TMPDIR (`bin/edm-state:1204-1215`, `:1226`); the only surviving in-tree references are the two
  explicitly-dead backward-compat sweeps at `bin/edm-state:3094` and `:3518`. The widened globs
  remain correct and still wanted (they cover `.lockd.stale.<pid>` and pre-G17 leftovers), so
  nothing is mis-ignored -- only the stated reason is out of date. Comment accuracy, not a
  hygiene defect. Not actionable under L5.
- **N6 -- bare `mktemp -d` in `.gitlab-ci.yml`.** Lines 287 (`lint:hooks-shell`) and 558
  (`validate:manifest`) both use the template-less form the repo's own T61 AC11 tripwire bans --
  the tripwire scans only `bin/` and `evals/`, never the pipeline file. Both install
  `trap 'rm -rf "$TMP"' EXIT`, and both run inside a throwaway CI container, so nothing survives
  the job or reaches a worktree. Line 509 (`test:state-validate`) uses a proper template but has
  no trap (`rm -f` at 530 only) -- same container-ephemeral reasoning. No accumulation. Not
  actionable as runtime hygiene.
- **N7 -- per-initiative `.gitignore` coverage verified complete, no gap found.**
  `bin/edm-init:171-178` and `cmd_init` (`bin/edm-state:2030-2037`) write an identical six-line
  block. Cross-checked against every runtime file EDM creates inside an initiative directory:
  `.edm-state.json.bak`; `.edm-state.json.tmp.*`; `.edm-state.lock` / `.lockd/` /
  `.lockd.stale.<pid>` (matched by `*.lockd*`); `code-audit/findings-ledger.lock` and
  `.lockd*` (the patterns carry no slash, so they match at any depth below the file); and every
  `write_atomic` staging path -- state file (`:719`, `:1981`), `HANDOFF.md` (`:5621`),
  `findings-ledger.md` (`:4177`), `docs/audit-patterns/*.md` (`:5004`) -- all covered by
  `.edm-state.json.tmp.*` or `*.md.tmp.*`. No uncovered runtime file found.
- **N8 -- eval run retention verified sound.** `prune_old_runs` (`evals/run-eval.sh:173-214`) is
  reached from `cleanup()` on every exit path including interrupt (G54), keeps
  `EDM_EVAL_KEEP_RUNS` (default 10), and filters strictly to run-shaped `<TS>_<sha>` names so a
  stray file can neither be pruned nor consume a keep slot (G12). The directory is `*`-ignored by
  `evals/runs/.gitignore`, and CI caps artifact retention at 30 days
  (`.gitlab-ci.yml:743-747`). No accumulation gap.
- **N9 -- `wave6-smoke.sh` mutation of a tracked file is fully trapped.** Line 3700 deliberately
  appends to the tracked, committed `plugins/edm/docs/canonical-sections.md` to prove
  `--check` catches a hand-edit. `cleanup_wave6` (`:24-30`) restores from the backup and is
  installed on `EXIT INT TERM HUP` (`:34`, CA-216) before any mutation. Verified, no gap.
- **N10 -- hooks and monitors create no files.** All nine command-type hooks in
  `hooks/hooks.json` invoke only `edm-state` / `edm-lint-artifacts` (whose own file creation is
  audited above); none redirects to a path of its own. `monitors/monitors.json` declares one
  monitor running `edm-state watch-impl`, whose body (`bin/edm-state:3100-3141`) is a read-only
  `git log` poll with no write of any kind. No `/tmp`, `.log`, `.pid` or `.cache` path appears in
  any `skills/*/SKILL.md`; the only matches under `agents/` are the lens definitions describing
  what to hunt for. Not actionable.
- **N11 -- no runtime writes to `$HOME` or `${CLAUDE_PLUGIN_DATA}`.** `get_session_tokens_since`
  reads `~/.claude/projects/<encoded-cwd>/*.jsonl` and `check_permission_rules` reads the three
  settings files (`bin/edm-state:284`, `:1014`); both are read-only. `bin/edm-check-vocabulary`,
  `bin/edm-compare-eval`, `bin/edm-validate-prefix`, `bin/edm-check-skill-sync` and
  `bin/_edm-lint-lib.sh` create no temp files at all. Not actionable.
