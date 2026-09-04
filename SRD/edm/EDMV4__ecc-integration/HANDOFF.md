# EDMV4 - Session Handoff

> **Last updated**: 2026-09-04T01:40:29Z by darryl.porter  
> **To resume**: `/edm:orchestrator EDMV4`

## Current Status

- **Phase**: Phase 6 - Implementation
- **Gates approved**: 3 of 3
- **Last gate**: Gate 3 - approved 2026-09-02T16:26:25Z by darryl.porter
- **Product**: edm
- **Description**: ecc-integration
- **Next action**: Awaiting the convergence gate - run `/edm:code-audit EDMV4`, then `edm-state approve-gate EDMV4 code-audit`

## Resume Point

- **Phase**: Phase 6 - Implementation
- **Step**: 6
- **Last decision**: architecture.md written by edm-architect

**Pending artifacts for Phase 6 - Implementation**:

_(implementation in progress -- track individual ticket status)_

> Copy-paste to resume: `/edm:orchestrator EDMV4`

## Lifecycle & Mode

- **Mode**: standard
- **Lifecycle mode**: standard
- **Compliance**: false
- **Implementation mode**: standard

## Gates

- Gate 1 - approved 2026-08-31T01:37:17Z by darryl.porter [enforcement: permission-ask]
- Gate 2 - approved 2026-09-02T03:18:49Z by darryl.porter [enforcement: permission-ask]
- Gate 3 - approved 2026-09-02T16:26:25Z by darryl.porter [enforcement: permission-ask]

## Artifact Checklist

| Artifact | Status |
|----------|--------|
| `./SRD/edm/EDMV4__ecc-integration/planning.md` | [present] |
| `./SRD/edm/EDMV4__ecc-integration/srd.md` | [present] |
| `./SRD/edm/EDMV4__ecc-integration/audit-srd.md` | [present] |
| `./SRD/edm/EDMV4__ecc-integration/tickets/README.md` | [present] |
| `./SRD/edm/EDMV4__ecc-integration/tickets/audit.md` | [present] |
| `./SRD/edm/EDMV4__ecc-integration/architecture.md` | [present] |
| `./SRD/edm/EDMV4__ecc-integration/decisions.md` | [present] |
| `./SRD/edm/EDMV4__ecc-integration/ROLLBACK.md` | [absent] (on-demand) |
| `./SRD/edm/EDMV4__ecc-integration/exec-report.md` | [absent] (on-demand) |

## Key Decisions Made

- **Where 5.1 lives**: **Its own initiative.** The bounded implementer/QC remediation loop is
  Large by itself and its cost-ceiling precondition is design work distinct from every other item.
  Splitting it means the remaining eleven items are not gated behind that design phase. EDMV4
  records it as a named follow-on rather than an unnamed candidate, per the D13/D14 precedent.
- **GateGuard implementation (4.1)**: **Resolve in SRD.** Deferred to Phase 2 architecture,
  contingent on Spikes A and B and the `zunoworks/gateguard` licence check. Phase 2 chooses
  between vendoring the three Node files (~2,042 lines, adds a Node runtime dependency) and a bash
  rewrite (400-600 lines excluding the two harder helper files).
- **Hookify rule format (5.3)**: **JSON rule files.** jq-native, adds no required binary, and
  matches how every other structured file in `bin/` is consumed. ECC compatibility buys nothing
  here because ECC has no evaluator to inherit -- only the format was ever reusable, and EDM is
  free to choose a better-fitting one.
- **L13 stack-conditionality (4.4)**: **Auto-N/A plus a new `round_type` state.** Follow the test
  layer's N/A-agreement precedent (`edm-test-integration.md:21-25`): code-audit Step 1 detects the
  stack, L13 exits N/A on untyped code, and `round_type` learns to distinguish an auto-N/A lens
  from an operator-requested subset so a 13-of-14 round can still read as `full`. This keeps L13's
  conditionality framed as genuine inapplicability, satisfying the D2 guard.
- **EDMV4-T05 baseline**: **Recorded as an explicit scope boundary with a named follow-on.** Both
  named bugs (CA-532, CA-490) are already fixed and verified, so T05's code work is complete. The
  live capture of `evals/baseline/scores.json` stays a decision for whoever owns the
  `ANTHROPIC_API_KEY`, per `evals/baseline/README.md`'s own recorded position that it must not be
  spent by an agent verifying its own ticket. T05 closes as verification plus a boundary record.
- **EDMV4-T04 scope**: **All 14 verified files, plus a third canonical section.** Anchor the full
  verified set rather than the 8 `CLAUDE.md` names, and add "Unverifiable acceptance criteria
  (D15)" as a third generated section so `edm-qc-auditor.md:39`'s orphaned citation resolves.
  Requires re-running `edm-sync-canonical-sections` and re-verifying its `--check` drift assertion
  in the same ticket.
- **Codemaps (5.5)**: **The `SRD/.codemap.md` interim.** The first explorer of an initiative writes
  a reusable current-architecture codemap that later initiatives read and refresh. No generator is
  built. This is the cheapest way to test a premise the source document itself flags as unmeasured,
  and it avoids the failure mode ECC hit (a generator whose Data Flow and External Dependencies
  sections are literal placeholders).
- **The eleven corrections**: **Written back into `ecc-integration-analysis.md`.** Amend the source
  document in place, in the Part 8.2 style it already uses to self-correct twice, so the next
  reader gets the corrected version instead of re-deriving the same eleven findings. `planning.md`
  keeps the correction table as the audit record of what changed.

-> See full decision ledger: `./SRD/edm/EDMV4__ecc-integration/decisions.md`

## How to Resume

1. Pull the latest branch - all EDM artifacts are committed
2. Open Claude Code in the project root
3. Run: `/edm:orchestrator EDMV4`
4. The orchestrator detects the existing initiative and resumes from **Phase 6 - Implementation**

## Notes

_(Add anything a teammate should know before resuming - context, blockers, preferences)_
