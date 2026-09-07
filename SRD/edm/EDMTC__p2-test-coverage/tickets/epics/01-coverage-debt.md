# Epic 01 -- P2 Test-Coverage Debt

All six tickets. Cross-cutting AC CC1-CC6 in `../README.md` bind every one and are not restated.

---

## EDMTC-T01: Repair four wave8 assertions that verify less than they claim

| Field | Value |
|---|---|
| Epic | Coverage debt |
| Phase | 6 |
| Priority | Must Have |
| Size | S |
| Findings | CA-068, CA-069, CA-080, CA-099 |
| Depends On | -- |
| Target Components | `plugins/edm/bin/tests/wave8-smoke.sh` |

### Description

Four assertions pass today while checking something narrower, broader, or simply other than what
their own label claims. None is failing, which is the problem: each reads as coverage in a review
and is not.

### Acceptance Criteria

- [ ] AC1: CA-068 -- T15 AC9's assertion greps the WHOLE of `edm-gateguard` for "once a marker is
      present" rather than the `EDM-HELP` block the AC names. Scope the grep to that block, so the
      sentence moving out of the help text fails the assertion.
- [ ] AC2: CA-068 control -- a scratch copy with the sentence moved outside the help block is
      rejected.
- [ ] AC3: CA-069 -- the T28 `SCOPE_PARAGRAPH` check is two substring greps with 44 unchecked
      characters between them. Replace with a single anchored whole-line comparison so a lens
      rewriting the middle clause fails. (The group-3 remediation already collapsed this to
      `grep -qxF` when it unwrapped `edm-audit-security.md`; verify that holds and pin it.)
- [ ] AC4: CA-069 control -- a scratch lens with only the middle clause altered is rejected.
- [ ] AC5: CA-080 -- the T28 band asserts a lens-file COUNT against `ALL_LENS_IDS` and never that
      the declared IDs are DISTINCT and cover L1 through L14. Assert the set, not the cardinality.
- [ ] AC6: CA-080 control -- a duplicated ID (count still correct, set wrong) is rejected, and a
      gap (L7 missing, L15 present) is rejected.
- [ ] AC7: CA-099 -- T48 AC4 asserts a generic substring and tests none of the three properties its
      label names. Assert each named property separately so the label and the check agree.
- [ ] AC8: CA-099 control -- each of the three properties is independently falsifiable.
- [ ] AC9: `wave8-smoke.sh` exits 0 with a total at or above the fork baseline.

### Technical Notes

CA-080 is the one worth care: "count equals 14" and "the set is exactly L1..L14" differ precisely
when an ID is duplicated and another missing, which is the realistic drift.

### Out of Scope

The other seven wave8 findings -- T02 and T03 own those.

---

## EDMTC-T02: Make wave8 independent of live shared state and of this repository

| Field | Value |
|---|---|
| Epic | Coverage debt |
| Phase | 6 |
| Priority | Must Have |
| Size | M |
| Findings | CA-094, CA-095, CA-096, CA-098 |
| Depends On | -- |
| Target Components | `plugins/edm/bin/tests/wave8-smoke.sh` |

### Description

Three assertions read live, shared state and attribute every difference to the code under test; a
fourth reads a missing file as a clean zero. CA-096 is the one that leaves this repository: the
suite hard-codes EDMV4's live SRD paths, so it fails in any other consuming repo -- and, now that
EDMV4 is archived, on this one too.

### Acceptance Criteria

- [ ] AC1: CA-096 -- no assertion depends on a path under `SRD/edm/EDMV4__ecc-integration/`.
      Fixtures are built in scratch directories the test owns.
- [ ] AC2: CA-096 -- a grep proves no live-initiative path literal survives anywhere in the suite,
      with a positive control injecting one.
- [ ] AC3: CA-096 -- the suite passes with the EDMV4 initiative directory absent (it is archived;
      assert against the archived-away path, not merely a moved copy).
- [ ] AC4: CA-094 -- T17 AC2 compares two observations of live EDMV4 state taken at different times
      and cwds. Compare a fixture against itself, or compare a single observation against a fixed
      expectation.
- [ ] AC5: CA-095 -- the T20/T17-AC9 git-status windows span the shared worktree, so a concurrent
      writer fails them and is misattributed. Scope each window to a scratch repository.
- [ ] AC6: CA-094/CA-095 control -- each rewritten assertion still fails when the property it
      guards is genuinely violated inside its own fixture.
- [ ] AC7: CA-098 -- `grep -c ... || echo 0` emits a two-line `0\n0`; at the delta-file site a
      MISSING file reads as a clean zero. Distinguish "zero matches" from "file absent", the latter
      being an error.
- [ ] AC8: CA-098 control -- an absent file is rejected, a present-but-empty file reports 0, and a
      present file reports its true count.
- [ ] AC9: `wave8-smoke.sh` exits 0 with a total at or above the fork baseline.

### Technical Notes

`w8_count_lines` already exists in the suite for exactly CA-098's shape -- prefer extending its use
over a second helper.

### Out of Scope

Extractor and scratch-dir consolidation (T03).

---

## EDMTC-T03: Consolidate wave8's scratch-dir and extractor duplication

| Field | Value |
|---|---|
| Epic | Coverage debt |
| Phase | 6 |
| Priority | Should Have |
| Size | M |
| Findings | CA-104, CA-118, CA-119 |
| Depends On | EDMTC-T01, EDMTC-T02, EDMTC-T04 |
| Target Components | `plugins/edm/bin/tests/wave8-smoke.sh` |

### Description

Three near-identical awk function-body extractors plus a fourth variant, two `_extract_between`
re-implementations of a helper the same file already calls, and five scratch dirs using a third
idiom with no trap. Runs last so it consolidates the bands T01/T02/T04 add rather than being
re-duplicated by them.

### Acceptance Criteria

- [ ] AC1: CA-118 -- one shared awk function-body extractor; all four call sites use it.
- [ ] AC2: CA-119 -- `_t34_extract_between` and `_t41_extract_between` are removed in favour of
      `_harness.sh`'s `_wave7_extract_between`, which this file already calls.
- [ ] AC3: CA-104 -- the five bare `mktemp -d` scratch dirs adopt one idiom; no scratch dir is left
      without cleanup on a signal.
- [ ] AC4: A computed assertion proves only ONE extractor implementation and ONE scratch idiom
      remain, derived by scanning the file rather than by a hardcoded count.
- [ ] AC5: AC4's control -- a re-introduced duplicate is detected.
- [ ] AC6: `CA-027`'s existing registry assertion still passes. Note it compares a STATIC grep of
      `w8_scratch_dir` call sites against the registry's RUNTIME length, so a call site added after
      it fails the count -- place any new call before it or use a self-contained pair.
- [ ] AC7: `wave8-smoke.sh` exits 0 with a total at or above the fork baseline.

### Technical Notes

Consolidation must not reduce the assertion count -- if it does, a check was silently dropped.

### Out of Scope

Behavioural repairs (T01, T02).

---

## EDMTC-T04: Cover edm-gateguard's unexercised paths

| Field | Value |
|---|---|
| Epic | Coverage debt |
| Phase | 6 |
| Priority | Must Have |
| Size | M |
| Findings | CA-066, CA-127, CA-130, CA-131 |
| Depends On | -- |
| Target Components | `plugins/edm/bin/edm-gateguard` (coverage in `wave8-smoke.sh`) |

### Description

Four paths in the gate that fires on every Edit and Write are never driven: the gated allow path's
jq-spawn count, the env half of the denial-budget knob, `MultiEdit`'s single-file payload shape,
and every exempt-glob form beyond a single entry.

### Acceptance Criteria

- [ ] AC1: CA-066 -- an assertion pins the jq-spawn count on the GATED allow path. T45 AC6's spy
      covers only the marker-absent fast path.
- [ ] AC2: CA-066 control -- an injected extra jq invocation is detected.
- [ ] AC3: CA-127 -- `EDM_GATEGUARD_MAX_DENIALS` is exercised with an explicit env value, not only
      the hardcoded default of 3.
- [ ] AC4: CA-127 -- the documented non-numeric fallback is exercised: a bad value warns on stderr
      and falls back to 3, and the gate does not allow every edit (that was CA-009).
- [ ] AC5: CA-130 -- `MultiEdit` extraction is driven with Claude Code's own single-file payload
      shape, not only `edits[].file_path`.
- [ ] AC6: CA-130 -- de-duplication across a batch naming the same path twice is asserted.
- [ ] AC7: CA-131 -- `gg_is_exempt` is driven with a multi-entry comma list, an empty element, a
      non-`**` glob form, and an explicitly empty value.
- [ ] AC8: CA-131 control -- a path that should NOT be exempt is still gated under each form.
- [ ] AC9: `wave8-smoke.sh` exits 0 with a total at or above the fork baseline.

### Technical Notes

`EDMV4-T11` AC1 pins `edm-gateguard` to a CLOSED 200-660 line range and it stands at 653. If a fix
needs source changes that push it over, do NOT nudge the ceiling -- escalate. That bound has been
widened twice already (D42, D47).

### Out of Scope

`edm-gateguard`'s own behaviour. These are coverage findings; the code is believed correct.

---

## EDMTC-T05: Cover readiness, hookify list, and stop-gate's died-validate branch

| Field | Value |
|---|---|
| Epic | Coverage debt |
| Phase | 6 |
| Priority | Must Have |
| Size | S |
| Findings | CA-128, CA-129, CA-132 |
| Depends On | -- |
| Target Components | `bin/edm-repo-readiness`, `bin/edm-hookify`, `bin/edm-stop-gate` |

### Description

Three binaries with an unexercised contract each.

### Acceptance Criteria

- [ ] AC1: CA-128 -- rubric signal helpers are driven at values OTHER than this repository's
      current ones, using fixtures.
- [ ] AC2: CA-128 -- the score assertion is not a self-consistency identity. Assert a known
      fixture produces a known score.
- [ ] AC3: CA-128 control -- changing a fixture signal changes the score in the expected direction.
- [ ] AC4: CA-129 -- `edm-hookify list` output is asserted, not discarded to `/dev/null`: the
      listing contract, the name fallback, and the omission of disabled rules.
- [ ] AC5: CA-129 control -- a disabled rule is absent from the listing and an enabled one present.
- [ ] AC6: CA-132 -- the per-prefix "validate died" `continue` branch is driven. T46 AC9's two
      internal-error cases both fail `active-initiatives` and `soft_exit` BEFORE the loop, so they
      never reach it -- the fixture must have a resolvable active initiative whose `validate` dies.
- [ ] AC7: CA-132 -- the branch emits its stderr diagnostic naming the prefix and does NOT block
      (CA-040's fix); both asserted.
- [ ] AC8: All suites exit 0 with totals at or above the fork baseline.

### Technical Notes

CA-132's fixture is the fiddly one: `validate` must DIE (not merely report anomalies) for a prefix
that resolved successfully. A shim `edm-state` on `PATH` is the reliable way.

### Out of Scope

The three binaries' behaviour.

---

## EDMTC-T06: Fix wave7's tautological control and host-polluting cases, and timing's blind budget

| Field | Value |
|---|---|
| Epic | Coverage debt |
| Phase | 6 |
| Priority | Must Have |
| Size | S |
| Findings | CA-097, CA-102, CA-126 |
| Depends On | -- |
| Target Components | `bin/tests/wave7-smoke.sh`, `bin/tests/timing.sh` |

### Description

A positive control that cannot discriminate, two cases that write into the real host data
directory, and a timing budget that reports MET when the thing it measures aborted.

### Acceptance Criteria

- [ ] AC1: CA-097 -- T48 AC1's positive control compares the real list count against `anchor + 1`,
      which holds by construction. Vary the LIST and assert the count follows.
- [ ] AC2: CA-097 control -- the rewritten control fails when the list and the count disagree.
- [ ] AC3: CA-102 -- the two residual T57 cases run `update-patterns` with no
      `CLAUDE_PLUGIN_DATA`/`HOME`/`XDG_DATA_HOME` isolation and create `patterns/*-audit.md` in the
      real host data directory. Isolate all three variables to a scratch root.
- [ ] AC4: CA-102 -- an assertion proves the real host data directory is untouched by a suite run,
      with a positive control that writes there deliberately and is detected.
- [ ] AC5: CA-126 -- `timing.sh --gateguard` measures through `_measure_p95`'s `|| true`, so an
      ABORTING gateguard still prints `budget_status=MET`. Add a correctness probe: the measured
      command must have succeeded and produced the expected decision.
- [ ] AC6: CA-126 control -- a deliberately broken gateguard produces a non-MET status.
- [ ] AC7: `wave7-smoke.sh` and `wave6-smoke.sh` exit 0 at or above baseline; `wave7` is run ALONE
      on a quiescent tree.

### Technical Notes

CA-102 is a real side effect on the developer's machine, not only a test-hygiene point -- the
suite currently pollutes `~/.local/share/edm` or whatever the host resolves.

### Out of Scope

`timing.sh`'s measurement methodology.
