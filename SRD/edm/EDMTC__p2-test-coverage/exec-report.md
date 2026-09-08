# Execution Report: EDMTC -- P2 Test-Coverage Debt

mode: fix-pack (lifecycle); no run-mode dependency -- this initiative changes only test code

## Summary

The 21 P2 test-coverage findings EDMV4 accepted as documented debt are closed. Six tickets, all
PASS, no PARTIAL verdicts. `run-all.sh` under GNU bash 3.2.57 on a quiet tree: **4048 passed, 0
failed across 8 suites**, up 178 from the 3870 fork baseline.

Every finding kept its original `CA-NNN` id. They remain open in EDMV4's archived ledger, which is
correct -- that ledger records what EDMV4 shipped, and rewriting it would misdescribe history.
EDMTC is the record of their closure.

## What the work found beyond fixing what it was given

**Archiving EDMV4 broke EDMV4's own test suite.** Three assertions in `wave8-smoke.sh` reached for
`SRD/edm/EDMV4__ecc-integration/`, which `git mv` had moved an hour earlier. CA-096's own text
predicted it: "fails in any other consuming repo and on archive". Verified independently -- four
live-path literals before, zero after, directory genuinely gone.

**One of those four did not go red.** `T17 AC2` went silently vacuous: both arms of its comparison
began returning the same unknown-prefix error, so it kept passing for a reason unrelated to the
property it guards. Had this pack not been opened, the suite would have looked three-red-and-
fixable while carrying one assertion that had stopped meaning anything.

**CA-102's host pollution had already happened.** Pattern files dated 2026-09-02 to 09-04 were
found in the real host data directory. That is why a before/after diff of the current tree read
clean -- the damage predated the measurement.

**CA-126 was reporting success on failure.** `timing.sh --gateguard` measured through
`_measure_p95`'s `|| true`, so an aborting gateguard printed `budget_status=MET`. The control is
the sharp part: a deliberately broken gateguard measures 19 ms, FASTER than the real one's 25 ms,
and now yields `INVALID`.

**Two prescriptions were wrong about their own scope.** CA-118 recorded four duplicate extractors;
there were eight. CA-104 recorded five untrapped scratch sites; by the time T03 ran there were 49,
of which only 21 were the genuine defect -- the rest were already nested under a registered root.

## Out of scope (recorded boundaries, not deferred findings)

- **`_harness.sh` was left read-only.** CA-118's prescription suggested hoisting the shared
  extractor there; it lives in `wave8-smoke.sh` instead, because other suites depend on
  `_harness.sh` and its AC asks for one shared extractor, not a particular home.
- **Two assertions lost live-data coverage by design.** `T45 AC3` no longer verifies a real
  `decisions.md` records a positive Spike A result, and the ledger duplicate-id check no longer
  scans a real ledger; both now test their predicate against fixtures. AC1 forbade depending on the
  live path and AC3 forbade re-pointing at the archive, so fixtures were the only route. Live
  ledger integrity belongs in `edm-state` or the synthesizer, not a smoke suite.

## Known issues

- **`wave6-smoke.sh` writes into the real host data directory** -- `run/<key>.phase6` markers. Same
  class as CA-102, which named only the two wave7 sites. Nothing currently guards wave6.
- **`CA-087` in wave8 is flaky under machine load.** Lock contention, not a logic defect: the lock
  is broken correctly but the subsequent write times out when the machine is busy.
- **`MultiEdit` de-duplication is not observable end to end.** The first denial exits the process,
  so ordering is its only external consequence. The claim rests on projection-level counts with the
  jq program lifted from the binary rather than re-typed.
- **A foreign plugin's data directory still holds EDM's files.** `patterns/{srd,ticket,code}-audit.md`
  dated 2026-09-02 to 09-04 under `copilot-studio-skills-for-copilot-studio/`, plus an `.edm-owned`
  sentinel dated 09-05 that EDMV4's own CA-134 fix wrote there via its C-4 backward-compatibility
  clause. This is the residual D46 recorded. It is outside the repository, so it is a manual
  cleanup for a human, not something this initiative does.

## Outstanding PARTIAL ACs

None. Every AC in this pack was statically verifiable or driven end to end.
