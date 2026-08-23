I could not write files this round (no `Write` tool in my delivered set -- the CA-130 class; `Bash` was also absent, so all verification below is by direct file read rather than `git log`/`git diff`). Both halves follow.

# Code Audit -- Lens L5: Runtime Hygiene

Round 9 (`pass-9_2026-08-16`), round type: full. Post-remediation verification round.
Scope walked: `plugins/edm/bin/*`, `plugins/edm/bin/tests/*.sh`, `plugins/edm/evals/*.sh`,
`plugins/edm/hooks/hooks.json`, `plugins/edm/README.md`, repository-root `.gitignore` and
`.gitlab-ci.yml`.

**Tooling caveat (CA-130, seventh occurrence).** My delivered tool set was Read, Grep, Glob,
WebFetch, WebSearch, TaskStop -- no `Write` and no `Bash`. Priority-1 verification was therefore
done by reading the files at HEAD and matching them against each finding's prescribed fix, not by
diffing `833a06d..HEAD`. Every "FIXED" below is a statement about the tree as it stands, which is
the load-bearing claim anyway; I could not attribute a fix to a specific commit.

## Priority 1 -- prior-round findings re-verified

| Prior ID | Verdict | Evidence at HEAD |
|---|---|---|
| CA-449 | **FIXED**, all three parts | `/Users/darryl.porter/projects/marketplace/plugins/edm/evals/score-artifacts.sh:756-761` -- both staging files now use the house template form under `${TMPDIR:-/tmp}` with an `edm-score-compare-*` prefix, creation is checked (`\|\| die`, with the second arm cleaning the first), and the four-signal split trap is installed *before* the first `jq` write. The tail-position `rm -f` is gone entirely, so the trap is the only cleanup path. Part 3 landed too: the T61 AC11 tripwire alternation at `bin/tests/wave7-smoke.sh:1137` is now `mktemp( -d)?\)`, with the rationale at `:1134`. No other `trap` exists in `score-artifacts.sh`, so nothing was clobbered. |
| CA-450 | **FIXED** | `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/timing.sh:42-52` -- one process-wide `_timing_cleanup` over all five mode variables (`TMP_PC`/`TMP_LG`/`TMP_SS`/`TMP_LINT`/`TMP_MR`), installed on EXIT plus signal-shaped INT/TERM/HUP. `set -u`-safe via `${VAR:-}`, and `return 0` keeps the loop's short-circuit from tripping `set -e`. `--generate-fixture`'s `DIR` (`:243`) is correctly excluded, matching the finding's explicit "LEAVE --generate-fixture ALONE". |
| CA-446 | **FIXED** at all three named sites | `bin/edm-sync-canonical-sections:90-93` (the CI `--check` fabricated-drift scenario is gone -- INT/TERM/HUP now exit 130/143/129 after cleanup); `bin/edm-lint-artifacts:149-152`; `bin/edm-check-grants:131-134`. |
| CA-447 / L8-006 | **FIXED**, including the first-stage trap | The first-stage trap landed exactly as prescribed: `bin/edm-lint-artifacts:137` arms `trap 'rm -f "$ATTR_PATTERN_FILE"' EXIT INT TERM HUP` immediately after the first `mktemp` at `:133`, and is superseded by the two-file split traps at `:149-152` once `MERMAID_SCAN_FILE` exists. HUP is now present at every named site: `bin/tests/wave7-smoke.sh:25`, `bin/tests/harness-smoke.sh:264`, `bin/tests/_harness.sh:85` and `:114`, plus the two scanners. `edm-check-grants:124-130`'s comment was rewritten to state the actual four-signal convention rather than the weaker "at least EXIT INT TERM" floor. |
| CA-442 | **FIXED** | `bin/edm-state:3636-3642` -- `_cmd_migrate_path_rollback_body` now sweeps `"${_src}/.edm-state.lockd"` after the reverse rename, with a comment naming why `with_state_lock`'s own destination-path cleanup cannot see it. The flock `.lock` file is correctly left alone per CA-169. Mirrors the two forward movers. |
| CA-443 | **FIXED** (clamp half) | `evals/run-eval.sh:188-195` -- `keep` is clamped to a floor of 1 with a named stderr diagnostic citing CA-443, after the digit-only `case` arm. **Half not landed:** the finding also prescribed "a structural guard inside the prune loop that skips the current run ID, so the run in progress is un-prunable BY CONSTRUCTION rather than by arithmetic accident." The loop at `:214-221` still has no current-run-ID check. Not re-filed -- the clamp makes the defect unreachable, and this is L3's finding, not mine. |

No regression was introduced by any of these fixes in this lens's dimension. Every widened trap
cleans a resource it actually owns, and none of them clobbers an outer trap that was load-bearing.

## Findings (L5: Runtime Hygiene)

| ID | Sev | File:line | Finding |
|---|---|---|---|
| L5-001 | P2 | `plugins/edm/bin/tests/wave7-smoke.sh:7272` | The G22b scratch tree is created and **never removed on any path** -- one leaked directory per suite run, unconditionally |
| L5-002 | P2 | `plugins/edm/bin/tests/wave7-smoke.sh:5116` (+10 siblings) | Eleven scratch trees are rooted at `${TMPDIR:-/tmp}` instead of the suite's trap-covered `$TMP`, inside subshells that deliberately disarm all four traps, cleaned only by a tail-position `rm -rf` |

### L5-001 [P2] G22b's scratch tree is never removed at all

**File type**: scratch directory containing a full synthetic initiative tree (`SRD/G22RDC/` with a
state file, a per-initiative `.gitignore` and the mode-derived subdirectories).
**Created at**: `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/wave7-smoke.sh:7272`

    tmp_g22b="$(mktemp -d "${TMPDIR:-/tmp}/edm-g22b.XXXXXX")" || exit 1
    cd "$tmp_g22b" || exit 1
    export EDM_SRD_ROOT="${tmp_g22b}/SRD"
    "$EDM_STATE" init G22RDC >/dev/null 2>&1

The `t_g22b_out` subshell spans `:7269-7286`. A grep of the entire 8,000-plus-line suite for
`tmp_g22b` returns exactly three hits -- `:7272`, `:7273`, `:7274` -- and **not one of them is a
removal**. There is no `rm -rf "$tmp_g22b"`, no trap covering it (line `:7271` explicitly clears
all four dispositions), and the suite's own top-level trap at `:25` owns only `$TMP`, which this
path is not under.

**In `.gitignore`?** Not applicable and not the point -- the tree lives under the system temp
directory, so it never reaches `git status`. This is pure unbounded accumulation.

**Why this is not the conditional class in L5-002.** Every sibling scratch site in this suite --
including `tmp_g22a` twenty lines above it, at `:7241`/`:7255`, which is otherwise
character-for-character the same shape -- ends with a tail-position `rm -rf`. G22b alone has
none. The remediation that added G22b clearly copied G22a's preamble and dropped its last line.

**Accumulation risk: the highest of anything this lens has found in the tree.** Unlike CA-450 and
CA-045, which leaked only on a signal or an `errexit` abort, this leaks on the **success path**,
every single time:

- `bin/tests/run-all.sh` discovers `*-smoke.sh` automatically, so every developer honouring
  `plugins/edm/CLAUDE.md`'s "run `bin/tests/run-all.sh` locally before pushing" mints one.
- CI runs the aggregator **twice per pipeline** (`test:smoke` and `test:smoke-bash32`), so every
  merge-request pipeline leaves two on the runner.
- The false-alarm filter is not satisfied on any clause: it is not covered by a gitignore glob
  (n/a), it is not deleted after use (it is never deleted), and it is not on a tmpfs -- macOS
  resolves `TMPDIR` to a per-user `/var/folders/...` directory that survives reboots, and a
  long-lived Linux CI runner sweeps `/tmp` on a timer at best.

The absolute size is small (a few KB per run), which is what holds this at P2 rather than P1 --
but "small, unconditional, and nothing ever reclaims it" is precisely the accumulation-without-
cleanup pattern this lens exists to catch, and it is the only site in the plugin with no cleanup
statement of any kind.

**Fix**: root it under the suite's own trap-covered scratch root so the top-level trap at `:25`
reclaims it by construction, which is what ~45 sibling sites in this same file already do:

    tmp_g22b="$(mktemp -d "${TMP}/edm-g22b.XXXXXX")" || exit 1

That single-token change also closes L5-002 for this site. Adding a bare `rm -rf "$tmp_g22b"`
before `:7286` would fix the unconditional leak but leave the conditional one. Consider also a
computed tripwire in this suite asserting that every `mktemp -d` in `bin/tests/*.sh` either
interpolates `${TMP}` or is paired with a trap -- the existing T61 AC11 sweep at `:1137` scans
`bin/` and `evals/` only and explicitly excludes `/tests/`, so nothing structural would catch a
recurrence.

### L5-002 [P2] Eleven scratch trees sit outside the suite's trap-covered root, with all traps deliberately disarmed

**File type**: scratch directory trees (synthetic lockbases, lockdirs and pidfiles, scratch
`SRD/` roots, marker files).
**Created at**, all in `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/wave7-smoke.sh`:
`:5116` (CA-159), `:5154` (CA-141a), `:5190` (CA-141b), `:5217` (CA-141d), `:5242` (G42),
`:5282` (CA-141c), `:5331` (CA-142), `:5386` (CA-025), `:5535` (CA-184), `:7241` (G22a),
`:7826` (G49). (`:7272`, the twelfth, is L5-001.)

Each follows the same shape:

    t_ca159_out="$(
      set +e
      trap - EXIT INT TERM HUP
      tmp159="$(mktemp -d "${TMPDIR:-/tmp}/edm-ca159.XXXXXX")" || exit 1
      ...
      rm -rf "$tmp159"
    )" || true

**The trap clearing at the top of each subshell is correct and must stay** -- the comment at
`:5105-5114` explains it precisely: `with_state_lock`/`write_atomic` save and restore whatever
trap was active when they install their own, so restoring the *inherited* copy of the parent's
`rm -rf "$TMP"` would delete the shared scratch root out from under every later test. That is not
the defect. The defect is that, having correctly disarmed the only trap that would have covered
them, these sites then root their own scratch at `${TMPDIR:-/tmp}` rather than under `$TMP`,
leaving a tail-position `rm -rf` as the sole cleanup for a resource that now has no handler at all.

**In `.gitignore`?** Not applicable -- temp-directory resident, never in a worktree.

**Two concrete abort paths, not hypotheticals:**

1. **`errexit` re-enters these subshells.** `set +e` at the top is silently undone by
   `source "$EDM_STATE"`, whose own top-level `set -euo pipefail` applies to the sourcing shell.
   The suite knows this -- `:5163-5165` states it explicitly ("sourcing edm-state re-enables
   errexit in this subshell (its own top-level `set -euo pipefail` overrides the `set +e`
   above)"). Several statements after that point are unguarded: `:5251`
   `stderr_out="$(cat "${tmp142}/stderr")"` aborts the G42 subshell if `with_state_lock` never
   wrote the file -- i.e. exactly when a regression in the code under test is present. Same shape
   at `:5159`, `:5169`, `:5247-5249`. This is CA-450's own aggravator verbatim: "a regression in
   `edm-state`, PRECISELY WHAT THIS HARNESS EXISTS TO DETECT, takes the script down before its
   own cleanup runs."
2. **A Ctrl-C leaks these and only these.** SIGINT reaches the whole foreground process group.
   The parent's INT trap reclaims `$TMP`, covering ~45 sibling scratch dirs; these eleven, having
   cleared their dispositions, die with no handler. `:7241`'s G22a case additionally leaves a
   `chmod 555` directory behind if it is interrupted between `:7248` and `:7252`.

**The consistent-project-pattern filter fails cleanly.** Roughly 45 `mktemp` calls in this same
file use the `"${TMP}/edm-...XXXXXX"` form (`:182`, `:226`, `:366`, `:916-917`, `:2299`, `:3597`
through `:3984`, `:5039`, `:5436`, `:5588` through `:5937`, `:6115` through `:6762`, ...), and
`wave6-smoke.sh:456-458` carries an explicit comment stating the rule -- "Nested under `$TMP` (not
a fresh `${TMPDIR:-/tmp}` entry) so the suite's own top-level trap already covers cleanup on every
exit path". These eleven are the inconsistency, not the pattern. Nothing about the tests requires
a root outside `$TMP`: every one of them only needs a writable directory to host a lockbase.

**Accumulation risk**: moderate. Bounded per interrupted or aborted run rather than per run, but
the suite runs in CI twice per pipeline and locally before every push, and nothing prunes.

**Fix**: change `"${TMPDIR:-/tmp}/edm-<case>.XXXXXX"` to `"${TMP}/edm-<case>.XXXXXX"` at all
eleven sites and keep the `trap -` lines exactly as they are. The parent's own EXIT/INT/TERM/HUP
trap then reclaims them on every path, the existing tail `rm -rf` calls stay valid as a fast-path
optimisation, and the comment at `:5105-5114` becomes true of the cleanup story end to end. Do
this in the same commit as L5-001. `:5535` (CA-184) is at top level rather than in a subshell and
takes the same one-token change.

## Noted / Not Actionable

- **N1 -- `evals/tiering-matrix.sh:154` is now the last trap in the plugin omitting HUP, and it
  resumes on INT/TERM.** `trap 'rm -f "${tmp:-}"' RETURN EXIT INT TERM` -- no HUP, and no
  signal-shaped exit, so it is simultaneously the residue of CA-291 and of CA-446. It was named in
  CA-291's NOTED site list and was outside CA-447's prescribed site set, so the sweep correctly did
  not touch it; after that sweep it stands alone. The resource is a `${TMPDIR:-/tmp}`-rooted file
  in a `--self-test` mode that is developer-invoked. Standing under CA-291's do-not-re-file
  disposition; recorded only so the "one signal set across the plugin" claim in
  `edm-check-grants:124-130` is read with this one exception in mind.
- **N2 -- `bin/tests/harness-smoke.sh:115`, `:139`, `:191`.** Three `mktemp` files with inline
  `rm -f` and no trap. Re-verified present and unchanged. CA-171 (NOTED) carries the do-not-re-file
  disposition; `:263-264`'s scratch dir, which *is* trapped, was correctly widened to four signals
  by CA-447.
- **N3 -- bare `mktemp -d` in `.gitlab-ci.yml:290` and `:572`.** Unchanged. Both install
  `trap 'rm -rf "$TMP"' EXIT` and run inside a throwaway container; `:523` uses a proper template
  with an inline `rm -f`. Round-8 N6's container-ephemeral reasoning holds. Not actionable.
- **N4 -- per-initiative `.gitignore` coverage re-verified complete.** `bin/edm-state:2092-2099`
  (`cmd_init`) and the mirrored heredoc in `bin/edm-init` (following the CA-314 comment at `:167`)
  write the identical six-line block. I walked every runtime write into an initiative directory
  against it: the backup (`edm-state:738`, `cp -p "$f" "${f}.bak"`) matches `.edm-state.json.bak`;
  all five `write_atomic` destinations -- state file (`:739`, `:2043`), `findings-ledger.md`
  (`:4286`), `docs/audit-patterns/*.md` (`:5150`), `HANDOFF.md` (`:5773`) -- produce
  `<dest>.tmp.XXXXXX` (`edm-state:664`) covered by `.edm-state.json.tmp.*` or `*.md.tmp.*`; the
  lock family (`.lock`, `.lockd/`, `.lockd/pid`, `.lockd.stale.<pid>`) is covered by the
  shape-anchored `*.lock` / `*.lockd*` pair. No uncovered runtime file found. `cmd_init` returns
  early on `init_ec -eq 10` (`:2078-2080`) *before* the `cat >`, so a re-init cannot clobber a
  hand-extended per-initiative ignore file.
- **N5 -- root `.gitignore:35`'s `**/*.lock` is broad, but harmless here and correctly scoped for
  consumers.** In this repository it would silently untrack a `Cargo.lock`/`Gemfile.lock`/
  `poetry.lock` if one were ever added; none exists and the marketplace has no build step. The
  consumer-facing copy is *not* this pattern -- `README.md:228-235`'s block is explicitly framed
  as a **per-initiative** `.gitignore` (`:221-226`) and is written into the initiative directory,
  where `*.lock` cannot reach a project-root dependency lockfile. No footgun shipped. Recorded, not
  filed.
- **N6 -- `bin/edm-lint-staged-artifacts` creates no files at all.** Newly in this round's named
  scope. It is pure `git diff --cached` -> `awk` -> subprocess dispatch; no `mktemp`, no
  redirection to a path, no `mkdir`. Clean.
- **N7 -- `hooks/hooks.json` gained no runtime-file surface from CA-440's fix.** The SubagentStop
  prompt (`:117`) now instructs `mkdir -p <initiative-dir>/qc` and a write to
  `qc/qc-shard-{NN}.md`. Both are documented, tracked artifacts (`plugins/edm/CLAUDE.md`'s layout
  lists `qc/qc-shard-{NN}.md`), bounded by ticket count, and overwritten rather than appended on
  a re-run. No other hook redirects to a path of its own. Not a hygiene surface.
- **N8 -- eval retention and scratch handling re-verified sound.** `evals/runs/.gitignore` is
  self-ignoring (`*` + `!.gitignore`); `prune_old_runs` is reached from `cleanup()` which is the
  body of all four traps (`run-eval.sh:271-274`), so a partial or interrupted run is
  retention-managed; the run-ID shape filter at `:204` means a stray file can neither be pruned nor
  consume a keep slot; `--provision-only`'s deliberate retention (`:260`) stands under round-8 N1.
  CA-292's surviving keep-window sliver is fully closed by the `grep -E '^[0-9]{8}T[0-9]{6}Z_'`
  filter now being applied *before* both the count and the window.
- **N9 -- CA-169's never-unlink rationale is intact and now correctly scoped.**
  `bin/edm-state:1228-1240` carries the inode-keyed explanation plus the G11/CA-341 correction
  naming both `cmd_init` and `edm-init` as writers of the per-initiative ignore file, and
  explicitly disowns the earlier version that cited this repository's root `.gitignore`. Do not
  "fix" the leaked lock file.
- **N10 -- `_harness.sh`'s `with_scratch_repo` references a `local` inside its trap body
  (`:100`, `:114`), unlike `harness_scratch_dir`, which uses a deliberate non-local (`:84`) and
  documents why.** Verified safe: the trap is installed at `:114` and torn down at `:143` before
  the function returns, so it only ever fires while `dir` is in dynamic scope. The asymmetry with
  the sibling helper's own comment (`:78-83`) is a readability question for another lens, not a
  leak.
- **N11 -- CA-130 recurred.** No `Write` and no `Bash` in the delivered tool set, so this report
  and its JSONL are returned inline per `skills/code-audit/SKILL.md`'s step-8a fallback, and the
  `833a06d..HEAD` diff review the round asked for was replaced by a read-based verification of the
  tree at HEAD. Flagged for the synthesizer's tooling-notes.

