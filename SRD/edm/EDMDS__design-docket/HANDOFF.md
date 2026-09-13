# EDMDS - Session Handoff

> **Last updated**: 2026-09-13T05:10:47Z by darryl.porter  
> **To resume**: `/edm:orchestrator EDMDS`

## Current Status

- **Phase**: Phase 3 - SRD Audit
- **Gates approved**: 2 of 2
- **Last gate**: Gate 2 - approved 2026-09-13T05:10:16Z by darryl.porter
- **Product**: edm
- **Description**: design-docket
- **Next action**: Proceed to Phase 4 - ticket creation (`/edm:orchestrator EDMDS`)

## Resume Point

- **Phase**: Phase 3 - SRD Audit

**Pending artifacts for Phase 3 - SRD Audit**:

_(all phase artifacts present)_

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
4. The orchestrator detects the existing initiative and resumes from **Phase 3 - SRD Audit**

## Notes

_(Add anything a teammate should know before resuming - context, blockers, preferences)_


**State: Phase 3 run four times. srd.md is at v1.7.0 and every P0 and P1 from all four rounds is
remediated. Gate 2+3 is the next action and it is a human's to give.**

The two prior notes in this position (v1.0.0 and v1.2.0 resume plans) are superseded and were
removed; the rounds they describe are preserved in full as `audit-srd-v1.0.0.md`,
`audit-srd-v1.1.0.md` and `audit-srd-v1.2.0.md`. Round four is `audit-srd.md`.

### Where this stands

Four audit rounds, six lanes in the last one, all six delivering. The document is 22 requirements
and 40 tickets in one fused mini-SRD file. Nothing is blocked: the round-three proposal to SPLIT the
initiative and pull four requirements was overtaken -- all four were resolved rather than deferred,
`EDMDS-02` by measurement (D89), `EDMDS-15` by re-deciding on the real assertion set (D54),
`EDMDS-19` by resolving AC7/AC9/AC10, and `AD-DS6` by rewriting its mechanism (D88) rather than
withdrawing it.

### What to do next

1. **Present Gate 2+3.** `mode=mini-srd`, so it is the merged gate. Only an explicit `AskUserQuestion`
   Approve selection records it -- free text is not approval. On Approve: `edm-state approve-gate
   EDMDS 2`, record the skip-phases for 4 and 5, append the Gate 2+3 rows to `decisions.md`, then
   Phase 6.
2. **Phase 6 implements all 40 tickets.** `EDMDS-T01` runs first and anchors the `run-all.sh` figure
   to a sha -- 4048 is a floor with no commit behind it, which four rounds have flagged and no round
   has fixed.

### Two checks own the recurring defect classes -- run both, do not skip them

- `./affected-assertions.sh --check` (DoD item 8, owned by `EDMDS-T38 AC6`) -- which EXISTING
  assertions an edit disturbs. Drift is CERTAIN during Phase 6; the obligation is on HOW exit 0 is
  reached: re-read the sites, confirm ownership, re-emit with `--emit-baseline` in the same commit.
  Editing the baseline to silence it discharges nothing.
- `./control-coverage.sh` (DoD item 10, owned by `EDMDS-T38 AC8`/`AC9`, D90) -- whether a NEW
  assertion can fail. Seven ACs had no control; five revisions shipped at least one.

Both exit 0 at v1.7.0.

### Constraints that still bind

- `run-all.sh` at or above **4048 passed / 0 failed across 8 suites on a quiet tree**, GNU bash
  3.2.57. Still anchored to no commit until `EDMDS-T01` runs.
- `bin/edm-gateguard` at **659** against a CLOSED 200-660 bound. Amending it edits **two** places --
  `bin/tests/wave8-smoke.sh:4056` live and `EDMV4-T11` AC1 under `.archived/`. D47 is the precedent
  that edited both; D42 edited one and is the recorded instance of the failure; **D49 is not
  precedent** and amended no bound.
- CC1-CC8 in `analysis.md`, carried individually into DoD item 7.

### What NOT to repeat

The failure mode across four rounds is **generalising from a partial check**, and its sibling,
**changing a mechanism without sweeping the prose that describes it**. Round four's own P0s were
three of the second and one of the first. A check that returns nothing is not a clean result until
the check is proven able to fire.
