# EDMDS - Session Handoff

> **Last updated**: 2026-09-14T04:08:43Z by darryl.porter  
> **To resume**: `/edm:orchestrator EDMDS`

## Current Status

- **Phase**: Phase 6 - Implementation
- **Gates approved**: 2 of 2
- **Last gate**: Gate 2 - approved 2026-09-13T05:10:16Z by darryl.porter
- **Product**: edm
- **Description**: design-docket
- **Next action**: Phase 6 in progress - run `/edm:orchestrator EDMDS` to continue, then `/edm:test EDMDS` when all tickets pass QC

## Resume Point

- **Phase**: Phase 6 - Implementation

**Pending artifacts for Phase 6 - Implementation**:

_(implementation in progress -- track individual ticket status)_

> Copy-paste to resume: `/edm:orchestrator EDMDS`

## Lifecycle & Mode

- **Mode**: mini-srd
- **Lifecycle mode**: standard
- **Compliance**: false
- **Implementation mode**: standard
- **Forked from**: EDMV4

**Skipped phases:**
- Phase 2: mini-srd: Phase 2 SRD creation fused into a single planning+SRD file (mode phase graph)
- Phase 4: mini-SRD: ticket pack fused into SRD file
- Phase 5: mini-SRD: ticket audit fused into SRD audit

## Gates

- Gate 1 - approved 2026-09-08T16:54:57Z by darryl.porter [enforcement: permission-ask]
- Gate 2 - approved 2026-09-13T05:10:16Z by darryl.porter [enforcement: permission-ask]

## Artifact Checklist

| Artifact | Status |
|----------|--------|
| `./SRD/edm/EDMDS__design-docket/planning.md` | [present] |
| `./SRD/edm/EDMDS__design-docket/srd.md` | [present] |
| `./SRD/edm/EDMDS__design-docket/audit-srd.md` | [present] |
| `./SRD/edm/EDMDS__design-docket/tickets/README.md` | [absent] |
| `./SRD/edm/EDMDS__design-docket/tickets/audit.md` | [absent] |
| `./SRD/edm/EDMDS__design-docket/architecture.md` | [present] |
| `./SRD/edm/EDMDS__design-docket/decisions.md` | [present] |
| `./SRD/edm/EDMDS__design-docket/ROLLBACK.md` | [absent] (on-demand) |
| `./SRD/edm/EDMDS__design-docket/exec-report.md` | [absent] (on-demand) |

## Key Decisions Made

_(none recorded yet - decisions are captured at Gate 1)_

-> See full decision ledger: `./SRD/edm/EDMDS__design-docket/decisions.md`

## Related Initiatives

- Related: EDMTC (./SRD/edm/EDMTC__p2-test-coverage)

## How to Resume

1. Pull the latest branch - all EDM artifacts are committed
2. Open Claude Code in the project root
3. Run: `/edm:orchestrator EDMDS`
4. The orchestrator detects the existing initiative and resumes from **Phase 6 - Implementation**

## Notes

_(Add anything a teammate should know before resuming - context, blockers, preferences)_


**State: Phase 6 implementation, 9 of 40 tickets landed. Gate 2+3 was approved 2026-09-13. The
`run-all.sh` baseline is anchored and green: 4121 passed / 0 failed across 8 suites.**

Landed: `T01`, `T02`, `T04`, `T05`, `T13`, `T14`, `T19`, `T22`, `T35`. In flight at this writing:
`T06`, `T16`, `T25`.

The v1.0.0 / v1.2.0 resume plans that used to sit here are superseded and were removed; those
rounds survive in full as `audit-srd-v1.0.0.md`, `audit-srd-v1.1.0.md` and `audit-srd-v1.2.0.md`.
Round four is `audit-srd.md`. The Gate 2+3 plan that stood here until 2026-09-14 is spent -- the
gate was given, and Phase 6 is well past it.

### Constraints that still bind, with their CURRENT figures

- `run-all.sh` at or above **4048 passed / 0 failed across 8 suites**, GNU bash 3.2.57, anchored by
  `EDMDS-T01` to commit `2963301456abe1f9bb984457096aa36f2c9d68f1` (D56). Measured **4121 / 0** at
  the close of wave 3. The floor and the measurement are different numbers and always were --
  4048 is the floor, the measurement is whatever the tree currently yields.
- `bin/edm-gateguard` at **656** against a CLOSED **200-736** bound, widened from 660 by
  `EDMDS-T05` as **D59** and now single-sourced in `wave8-smoke.sh` as `T11_LINE_MIN`/`T11_LINE_MAX`
  with an assertion pinning the archived ticket text to it. Amending it still edits **two** places.
  D42 and D47 are precedent; **D49 is not** and amended no bound. D59 budgeted the remaining
  headroom: +30 for `T06`/`T07`/`T08` together, +12 for `T11` AC4, +19 for `T30` AC2.
- `CC1-CC8` in `analysis.md`, carried individually into DoD item 7.

### Two checks own the recurring defect classes -- run both, do not skip them

- `./affected-assertions.sh --check` (DoD item 8, `EDMDS-T38 AC6`) -- which EXISTING assertions an
  edit disturbs. **Both checks exit 0 as of the wave-3 close.** Drift is CERTAIN during Phase 6;
  the obligation is on HOW exit 0 is reached: re-read the sites and confirm ownership. Editing the
  baseline to silence it discharges nothing. **Per D92 the ORCHESTRATOR re-emits once per merged
  wave, not each implementer per commit** -- the baseline is inline in one script and concurrent
  implementers cannot each rewrite it. Know also that `--emit-baseline` only PRINTS rows to stdout;
  it does not rewrite `baseline_for()`. That is a half-mechanism and it belongs to `EDMDS-T38`.
- `./control-coverage.sh` (DoD item 10, `EDMDS-T38 AC8`/`AC9`, D90) -- whether a NEW assertion can
  fail. Seven ACs had no control; five revisions shipped at least one.

### Operational facts that cost real time to learn

- **Run every suite from the repository ROOT.** Two `edm-lint-artifacts --all` assertions resolve
  `./SRD` relative to cwd and fail spuriously from `bin/tests/`. One full run was lost to this.
- **Redirect stdin from `/dev/null` for `run-all.sh`.** The suite invokes `bin/edm-stop-gate`,
  which blocks forever reading an inherited stdin that never delivers EOF -- 58 minutes with no
  output and no summary. This is R6's shape inside the harness itself.
- **Implementers stop at roughly 60 turns regardless of the declared `maxTurns: 200`** (D94, open
  for investigation). Resumption is lossless; brief `L` tickets expecting one.
- **Never touch a live agent's worktree, never abandon a dead one's** (D86b, D86c). `ListAgents`
  separates the two cases for one tool call.
- **A mutation harness takes its backup FIRST and `cmp`s it** (D96). T19's backup `cp` failed
  silently and four mutations compounded onto the real `bin/edm-state`.

### What NOT to repeat

The failure mode across four audit rounds is **generalising from a partial check**, and its
sibling, **changing a mechanism without sweeping the prose that describes it**. Round four's own
P0s were three of the second and one of the first, and both shapes recurred during Phase 6 --
`T19` falsified two shipped doc claims outside its own Target Components, and `T04`'s sweep needed
a scope decision recorded (D91). A check that returns nothing is not a clean result until the
check is proven able to fire.
