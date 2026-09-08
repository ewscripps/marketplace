# EDMDS - Session Handoff

> **Last updated**: 2026-09-08T18:18:11Z by darryl.porter  
> **To resume**: `/edm:orchestrator EDMDS`

## Current Status

- **Phase**: Phase 3 - SRD Audit
- **Gates approved**: 1 of 2
- **Last gate**: Gate 1 - approved 2026-09-08T16:54:57Z by darryl.porter
- **Product**: edm
- **Description**: design-docket
- **Next action**: HITL Gate 2 pending - run `/edm:orchestrator EDMDS` to present SRD for team approval

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
- Phase 4: mini-srd: ticket pack fused into SRD file (mode phase graph)
- Phase 5: mini-srd: ticket audit fused into SRD audit (mode phase graph)

## Gates

- Gate 1 - approved 2026-09-08T16:54:57Z by darryl.porter [enforcement: permission-ask]

## Artifact Checklist

| Artifact | Status |
|----------|--------|
| `./SRD/edm/EDMDS__design-docket/planning.md` | [present] |
| `./SRD/edm/EDMDS__design-docket/srd.md` | [present] |
| `./SRD/edm/EDMDS__design-docket/audit-srd.md` | [present] |
| `./SRD/edm/EDMDS__design-docket/tickets/README.md` | [absent] |
| `./SRD/edm/EDMDS__design-docket/tickets/audit.md` | [absent] |
| `./SRD/edm/EDMDS__design-docket/architecture.md` | [absent] |
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

## Notes -- resume point (2026-09-08)

**State: Phase 3 complete, SRD v1.0.0 FAILED audit. Do not enter Gate 2+3.**

Combined audit result across both lanes: **8 P0, 32 P1, 26 P2**. Full report in `audit-srd.md`,
which is the only document that needs reading to resume -- `planning.md` and `explorers/01-04` are
inputs it already accounts for.

### Start here, in this order

1. **Reverse AD1 and rewrite EDMDS-02.** Both lanes independently found AD1's central claim false:
   the plugin DOES have a machine-enforced untrusted-content labelling precedent
   (`edm-stop-gate:113-124`'s `stop_gate_emit_blocking`, pinned at `wave8-smoke.sh:7922-7929`).
   EDMDS-02's rejection of option 1 rests on that false claim. Separately, "put it on stderr" does
   not leave the model-facing channel -- exit 2 plus stderr IS that channel for three of four
   consumers. Cost option 1 against the real precedent before deciding.
2. **Add the Phase-4 half.** `srd.md` has no `## --- Ticket List ---`, no `EDMDS-T{NN}` ids, no
   Size, no Target Components, no `Generated From:` line -- see `skills/srd/SKILL.md:126-142` for
   the prescribed layout. Do this AFTER the decisions settle; ticket ids written against
   requirements that are about to change would only need rewriting.
3. **Fix the closure model.** Goal 1's "or record a reasoned decision not to close" and EDMDS-17
   AC3's "descoped" are statuses the canonical vocabulary does not admit. CA-114 needs splitting:
   remediate the false-header half, reclassify the unbounded-`regex_match` half `NOTED`.
4. **Resolve EDMDS-11's self-contradiction.** AC1 and AC5 are mutually exclusive (the CA-500
   cross-check IS a `git rev-parse`), and AC1 spends the `EDMV4-T07` AC8 fast-path budget that
   EDMDS-04's own rationale invokes to reject a change.
5. Then the remaining P1s, then re-audit, then Gate 2+3.

### Two audit P2s already fixed

`related_prefixes` now links EDMTC, and this file is refreshed. Everything else in the audit is
outstanding.

### Constraints that still bind

- `run-all.sh` at or above **4048 passed / 0 failed** (GNU bash 3.2.57, quiet tree). Note the audit
  flags this figure as anchored to no commit, with two `bin/`-touching commits landed since.
- `bin/edm-gateguard` is at **659** lines against `EDMV4-T11` AC1's closed 200-660 bound. One line.
  Amend by recorded decision if exceeded -- never nudge (D42, D47, D49 precedent).
- CC1-CC8 in `analysis.md`. The audit found six of eight missing from the DoD; carry them in.

### What is NOT blocked

Nothing here depends on information we lack. Every P0 and P1 is actionable from `audit-srd.md`
alone.
