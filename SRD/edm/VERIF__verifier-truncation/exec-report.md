# Execution Report: VERIF

mode: local (no deploy surface -- this initiative changes plugin prompt text, one new `bin/`
script, four skill consumers and the smoke suite; nothing runs in a hosted environment)

## Summary

Shipped **EDM 3.2.2**. Eleven tickets, five waves, all committed on
`edm/verif-verifier-truncation`. `bin/tests/run-all.sh`: **2375 passed, 0 failed across 7 suites**.

The defect: a read-only verifier agent that stops at its `maxTurns` ceiling produces partial output
that its consumer merges as if complete. Worst case is `edm-qc-auditor` -- hook-spawned and
unwatched -- where a truncated shard becomes a false PASS on the gate that decides whether Phase 6
work is done.

| Ticket | Commit | Delivered |
|---|---|---|
| T01 | `d7d376d` | Sentinel contract, `CLAUDE.md` Sec."Verifier completion sentinel (canonical)" |
| T02 | `d31bbf8` | `edm-qc-auditor` emits `QC-SHARD-COMPLETE` as the final line |
| T03 | `14fe325`, `42a0671` | `bin/edm-check-verifier-sentinel` + merge-step refusal in `skills/implement/SKILL.md` |
| T04 | `f7b1425` | Negative tests and mutation guards for both refusal paths |
| T05 | `99bec9a` | `edm-srd-auditor` + `skills/audit-srd/SKILL.md` |
| T06 | `22a6bcb` | `edm-ticket-auditor` + `skills/audit-tickets/SKILL.md` |
| T07 | `e53c53f` | `edm-test-coverage-auditor` + `skills/test-coverage/SKILL.md` |
| T08 | `27fe072` | Smoke assertion: the instruction is present in all four prompts |
| T09 | `306b0bf` | Four read-only verifiers raised `maxTurns` 25 -> 50 |
| T10 | `3a4bfcd` | Pre-verification step in the two audit skills |
| T11 | `cb69970` | 3.2.2 across all four version sites; retired T64's hardcoded version literal |

Supporting commits not tied to a ticket: `fe3a3d4` and `1d9f1cc` (smoke-suite fixture paths broken
by the EDMV2/EDMV3 archival, plus two vocabulary violations in the imported ECC analysis).

## QC verdict

`qc/qc-shard-pass-w01-01.md` -- **8 PASS, 3 FAIL, 0 PARTIAL**, all 11 tickets audited.

Zero PARTIALs is by design, per decision D4: no AC asserts model behavior ("the agent reliably
emits X"), because such an AC is unverifiable statically, would sit in `partial_verdict_map`
forever and hard-block archive under D15. The ACs instead assert that the instruction exists and is
unambiguous (grep-verifiable) and that the consumer refuses input lacking it (fixture-verifiable).
**The prompt asks; the consumer refuses; only the second half has to be reliable.**

All three FAILs are remediated:

1. **P1 -- the count arm trusted the artifact it polices.** `assigned=` (agent-supplied) outranked
   `[expected-count]` (dispatcher-supplied), so `range=T01-T08 assigned=1 audited=1` passed.
   Reproduced at exit 0 in both paths. Fixed in `42a0671` by inverting to a trust ordering;
   recorded as D8. **Introduced by this initiative's own T01 review fix** -- the comparison got
   simpler and the trust model went backwards with it.
2. **P2 -- the three-field grammar deviation was recorded nowhere.** Now D7.
3. **P2 -- T11 AC4** required the marketplace `description` be re-checked against the real skill
   and agent counts. It was checked and is accurate (14 skills, 30 agents), but the check was not
   stated in the commit body. Recorded here instead.

## Out of Scope (recorded boundaries)

Decisions made on their own merits, not postponed findings:

- **Proportional auditor fan-out** -- scaling auditor count to artifact size rather than the fixed
  "2-3". T09's raise may make it unnecessary; with the sentinel in place, recurrence is now
  observable rather than guessed at.
- **Producer budget parity.** `edm-implementer` (60) and the code-audit lenses (30) were excluded
  deliberately: raising both sides preserves the verifier/producer asymmetry rather than closing
  it. See Known Issues -- the evidence against this boundary strengthened considerably during
  execution.
- **A missing shard is still undetected.** See Known Issues; needs its own ticket.

## Known Issues

1. **A shard that was never written is not detected (P1, needs a ticket).**
   `skills/implement/SKILL.md:129` globs `qc-shard-*.md`; a file that does not exist does not match,
   the loop iterates zero times, and the merge proceeds anyway. Nothing compares shards found
   against implementers dispatched. The sentinel cannot close this by construction -- a file that
   does not exist has no last line. Independently graded P1 by the QC auditor: strictly worse than
   truncation, because there is no partial evidence at all. **Demonstrated live in this
   initiative** -- the `SubagentStop` hook produced no shards for any of the five implementer
   waves, and only a manual check caught it. The dispatcher already knows the ranges it launched,
   so the fix is an assertion, not a new mechanism.

2. **T09's raise does not reach any agent until the plugin is reinstalled.** Agents spawn from the
   installed cache. The QC auditor for this very initiative ran at the old `maxTurns: 25` and
   truncated with zero output on its first attempt. `/plugin` update plus `/reload-plugins` is
   required for 3.2.2 to take effect.

3. **Nine agent turn-ceiling events across this initiative**, at three budgets: `edm-implementer`
   (60) six times, `edm-srd-writer` (50) twice, `edm-qc-auditor` (25) once. Two left uncommitted or
   half-applied work that only a between-wave consistency check caught. The producer-parity
   boundary above was recorded before this evidence accumulated and should be revisited.

4. **`G1/CA-036` is flaky.** A `sleep 0.1` then `kill -INT` race in `wave7-smoke.sh`. Identical
   code produced 4 failures on one run and 5 on another. Not touched here.

5. **Worktree isolation did not hold during this session.** Two agents independently reported their
   assigned worktree being checked out to unrelated branches (`edm/g23min-g23mini`,
   `edm/msch6-migsch6`) mid-run, confirmed via `git reflog`. No history was lost; at least two test
   runs were invalidated, and both agents correctly distrusted their own results rather than
   reporting them.

6. **EDMV3 was archived by `git mv` alone, never via `edm-state archive`.** It carries no `status`
   or `archived_at` and still reads `current_phase: 6`. While it sat under `SRD/edm/` it looked
   active to state sweeps and acquired a spurious phase-6 completion, caught by `T14 AC11` and
   reverted. Now under `.archived/` it is correctly excluded, but its state file still misrepresents
   it as in-flight.

## Outstanding PARTIAL ACs

None. `partial_verdict_map` is empty; see the QC verdict above for why.
