# Lens L4 -- Test Quality (Round 4)

Scope: `plugins/edm/bin/tests/` (all seven suites, `_harness.sh`, `run-all.sh`, `timing.sh`,
`fixtures/`) and `plugins/edm/evals/` self-tests. Every open ledger entry whose Lens(es) column
includes L4 was re-read against current code; the round-3 hedged L9 entry CA-238 was
cross-checked as requested.

## Findings (L4: Test Quality)

### L4-01 (P1) -- CA-036's tripwire covers one of the class's two shapes, and a live instance of the uncovered shape sits at top level

`plugins/edm/bin/tests/wave7-smoke.sh:2051-2052` (tripwire at `:5289-5326`)

The three named CA-036 sites ARE fixed. A tripwire with a real synthetic positive control was
added (G5, `wave7:5289-5326`). The problem is the detector's reach: both regex branches require
the failing command to be a quoted command substitution assigned to a bare variable. Three
variants carry the identical `set -e` hazard but are invisible: a plain command followed by
`VAR=$?`, a `local VAR="$(...)"`, and an unquoted `VAR=$(...)`.

One live instance at top level, outside any errexit bracket:
```bash
2050  t43_start="$SECONDS"
2051  bash "$LINT_BIN" --path "${T43_SCRATCH}/nested.md" >/dev/null 2>&1
2052  t43_rc=$?
2053  t43_elapsed=$((SECONDS - t43_start))
2054  [[ "$t43_elapsed" -le 10 && "$t43_rc" -le 1 ]] \
```
`:2054` tolerates exit 1, but under `set -euo pipefail` exit 1 at `:2051` aborts the shell first.
Two further sites are invisible to G5 because no `$?` line follows at all: `wave7:2310` (the
CA-101/CA-038 regression detector) and `wave6:854`. Also un-guarded, introduced by this round's
own CA-147 remediation: `wave7:4104` and `:4123`.

**Fix**: widen G5's regexes to a third alternative covering plain-command-then-bare-`$?`, `local `
prefix, and unquoted `VAR=$(...)`. Convert `wave7:2051-2052` to the `t43_rc=0; ... || t43_rc=$?`
form its sibling at `:2032-2034` already uses.

**Ledger verdict on CA-036: PARTIALLY FIXED -- keep open.**

### L4-02 (P1) -- CA-037's remediation replaced uncontrolled assertions with tautologically controlled ones at 16 sites

`plugins/edm/bin/tests/wave7-smoke.sh:1333-1336` and 15 siblings

`assert_absent_with_control` is correct and well self-tested. The call sites are not: at 16 of
them the control haystack is a literal string authored in the test that contains the needle by
construction, so the control arm is provably dead code. CA-037's stated failure mode -- a wrong
`PLUGIN_DIR` or a mistyped filter reads identically to a clean tree -- is exactly as live as
before, because the `actual` haystacks are built by scans that swallow every error (`2>/dev/null`,
`|| true`, chained inverted filters). Three shipped comments state the opposite.

The correct shape already exists at five sites (`wave6:2473`, `wave7:2654`, `:3944`, G5 `:5317`,
G6 `:5349`) and should be the template.

**Fix**: route the real scan over a scratch tree seeded with one planted violation, or at minimum
use a real in-tree file known to contain the needle.

**Ledger verdict on CA-037: NOT CLOSED -- keep open.**

### L4-03 (P2) -- CA-146 landed six of seven branches; the suite-count floor still has no firing case

`plugins/edm/bin/tests/harness-smoke.sh:375-402`, guard at `run-all.sh:84-88`

Six of eight accounting branches are covered with exact-row assertions. The suite-count floor at
`run-all.sh:85-88` has no case that makes it fire -- branch 6b exits at the missing-preferred
check first; cases 1-5 set the floor to 1. CA-248 established this floor as non-redundant.

**Fix**: one case using existing overrides:
`EDM_RUN_ALL_SUITE_DIR=<one-stub-dir> EDM_RUN_ALL_PREFERRED_ORDER="" EDM_RUN_ALL_MIN_SUITE_COUNT=2`.

**Ledger verdict on CA-146: MOSTLY FIXED -- keep open for the floor branch only, downgrade P1->P2.**

### L4-04 (P2) -- CA-145's `count_matches_strict` still has one production caller

`plugins/edm/bin/tests/_harness.sh:189-198`

Correct and self-tested, but production callers tree-wide are just `wave7-smoke.sh:3942`/`:3944`.
Everything else uses bare `count_matches` or `grep -c ... || true`, collapsing grep exit 2 into
the same `0` that a genuine absence prints.

**Fix**: convert the expect-zero sites named in CA-037 to `count_matches_strict`.

**Ledger verdict on CA-145: NOT CLOSED -- keep open.**

### L4-05 (P2) -- new CA-147 measurement assertion is probabilistic on the pinned CI images

`plugins/edm/bin/tests/wave7-smoke.sh:4134`

No `apk add` line installs `perl`, so `timing.sh`'s whole-second-resolution awk fallback yields 0
for any sample not straddling a second boundary. The `[1-9]` regex depends on at least one of 40
sampled invocations crossing a boundary, in a blocking job.

**Fix**: relax to `p95_ms=[0-9]+` with a documented caveat, or key the strict form off
`command -v perl`.

### L4-06 (P2) -- numeric equality asserted through `check()`, a substring match

`plugins/edm/bin/tests/wave7-smoke.sh:4811-4812`

`"0"` is a substring of `"10"`/`"20"`/`"30"`. Works today only because realistic values are 0/1.

**Fix**: use `[[ "$tmp_left" -eq 0 ]]` idiom, matching numeric assertions used elsewhere.

## Cross-check requested by round 3

### CA-238 (L9, hedged): **FALSIFIED on the current tree.** The T35 AC4 case was rewritten in
this round's G20 sweep to assemble both needles from split fragments at runtime, so the repo-wide
scan cannot self-match. No failing assertion for L4 to confirm; the AC-text half remains L9's.

## Suite executability end to end (CA-189 follow-up)

Confirmed clean. Zero `bc` invocations remain under `plugins/edm/`. G6 is a correctly built
tripwire. All hard-dependency binaries present on pinned alpine images; optional binaries
(`perl`, `shasum`/`sha256sum`) are `command -v`-guarded. The remaining crash hazard is the
errexit class in L4-01, not a missing binary.

## Noted / Not Actionable

1. CA-101 -- VERIFIED FIXED (fixture with entity-inside-label plus real terminator).
2. CA-138 -- VERIFIED FIXED (real `assertions_run` counter, denominator extracted not matched).
3. CA-210 -- VERIFIED FIXED, both halves, correctly triaged for non-mutating exceptions.
4. CA-211 -- VERIFIED FIXED, both halves.
5. CA-147 core -- VERIFIED FIXED (two real measurement paths, not just usage text).
6. CA-039 -- VERIFIED genuinely discriminating (hand-computed literal dimension values).
7. G2/G3/G4 SIGINT-during-locked-write case -- VERIFIED genuinely discriminating; only nit is
   L4-06's substring form.
8. `wave7-smoke.sh:506-509` plain-command shape is errexit-suspended by `with_scratch_repo`'s
   `"$fn" || status=$?` -- not live, covered by L4-01's detector widening.
9. Unguarded setup captures (~40 sites) are preconditions, not assertion subjects -- not filed.
10. `harness-smoke.sh:311`'s weak first assertion is redundant, not load-bearing (strong block
    follows).
11. `run-all.sh`'s three test-only env overrides are the right trade -- documented, default to
    prior behaviour, correctly gate off real-tree checkers.
12. **Write tool absent from the delivered runtime tool set for a fifth consecutive round**
    (ledger CA-130). Host-side, not a repository defect.

## Meta

`Write` was absent from this lens's delivered runtime tool set despite the frontmatter grant
(ledger CA-130). Both `lens-L4.md` and `lens-L4.jsonl` were transcribed by the orchestrator.
