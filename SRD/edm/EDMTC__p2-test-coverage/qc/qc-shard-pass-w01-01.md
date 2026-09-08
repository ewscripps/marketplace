# QC Audit Report: EDMTC -- P2 Test-Coverage Debt [Shard 1/1]

**Date**: 2026-09-07
**Tickets audited**: EDMTC-T01 through EDMTC-T06 (6 of 6)
**Tree audited**: `edm/edmtc-p2-test-coverage` at the T04 merge, quiet tree

## Summary

| Ticket | Findings | Verdict |
|---|---|---|
| EDMTC-T01 | CA-068, CA-069, CA-080, CA-099 | PASS |
| EDMTC-T02 | CA-094, CA-095, CA-096, CA-098 | PASS |
| EDMTC-T03 | CA-104, CA-118, CA-119 | PASS |
| EDMTC-T04 | CA-066, CA-127, CA-130, CA-131 | PASS |
| EDMTC-T05 | CA-128, CA-129, CA-132 | PASS |
| EDMTC-T06 | CA-097, CA-102, CA-126 | PASS |

All 21 inherited findings implemented. No PARTIAL verdicts: every AC in this pack is statically
verifiable or was driven end to end, so nothing requires a runtime environment that does not exist.

## Evidence

`/bin/bash plugins/edm/bin/tests/run-all.sh` under GNU bash 3.2.57(1)-release, quiet tree:
**4048 passed, 0 failed across 8 suites**, exit 0.

| Suite | Fork | Final |
|---|---|---|
| wave3 | 14 | 14 |
| wave4a | 63 | 63 |
| wave4b | 98 | 98 |
| wave5 | 45 | 45 |
| harness | 59 | 59 |
| wave6 | 799 | 799 |
| wave7 | 1452 | 1463 |
| wave8 | 1336 (actually 1331 / 3) | 1503 |

Reconciled rather than taken at face value: 4044 across the eight suites plus run-all's own four
checks equals the reported 4048, with no remainder. CC6 holds -- no suite fell below its fork
figure.

`edm-check-grants` 0, `edm-check-vocabulary` 0, `edm-check-skill-sync` 0,
`edm-sync-canonical-sections --check` 0, `claude plugin validate` 0, `edm-lint-artifacts EDMTC` 0.
`edm-gateguard` at 659 lines, inside `EDMV4-T11` AC1's closed 200-660 bound.

## Coverage check, per finding rather than per total

Every one of the 21 inherited IDs was checked for a reference in the suites. This is the check that
matters here: a ticket that is never implemented makes nothing fail, so a green total cannot detect
it. **It caught a real miss** -- EDMTC-T04 had not been launched at all, and CA-066/CA-127/CA-130/
CA-131 were unimplemented while `run-all` reported 3996 passed / 0 failed with the arithmetic
reconciling. T04 was then run and merged.

CA-119 is the one ID with no suite reference, correctly: it is a deletion, removing
`_t34_extract_between` and `_t41_extract_between` in favour of `_harness.sh`'s
`_wave7_extract_between`. Verified directly -- 0 re-implementations remain, 11 call sites route to
the shared helper -- and T03's computed AC4 assertion guards re-introduction.

## Findings the work surfaced beyond its own scope

- **Archiving EDMV4 broke its own suite**, exactly as CA-096 predicted ("fails in any other
  consuming repo and on archive"). Three assertions went red on dangling paths. A fourth, T17 AC2,
  went SILENTLY VACUOUS instead: both arms of its comparison began returning the same unknown-prefix
  error, so it kept passing for a reason unrelated to the property. That is the class this pack
  exists to close, observed live.
- **CA-102's host pollution had already happened.** Pattern files dated Sep 2-4 were found in the
  real host data directory, which is why a naive before/after diff of the current tree read clean.
- **CA-126 was reporting success on failure.** A deliberately broken gateguard measures 19 ms --
  faster than the real one's 25 ms -- and previously printed `budget_status=MET`.

## Carried out of scope, reported not fixed

- `wave6-smoke.sh` also writes `run/<key>.phase6` markers into the real host data directory. Same
  class as CA-102; CA-102 named only the two wave7 sites and nothing guards wave6.
- `CA-087` in wave8 is flaky under machine load (lock contention, not a logic defect).
- De-duplication in `MultiEdit` is not observable end to end: the first denial exits the process, so
  ordering is its only external consequence. The claim rests on projection-level counts with the jq
  program lifted from the binary rather than re-typed.
- `EDM_GATEGUARD_MAX_DENIALS=none` does not reproduce CA-009's fail-open on bash 3.2 under `set -u`
  -- it aborts on an unbound variable. The inversion control uses `-1`, which reproduces the
  documented shape verbatim.

<!-- QC-SHARD-COMPLETE range=T01-T06 assigned=6 audited=6 -->
