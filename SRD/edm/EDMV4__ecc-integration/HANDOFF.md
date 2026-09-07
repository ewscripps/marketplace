# EDMV4 - Session Handoff

> **Last updated**: 2026-09-07T00:50:03Z by darryl.porter  
> **To resume**: `/edm:orchestrator EDMV4`

## Current Status

- **Phase**: Phase 6 - Implementation
- **Gates approved**: 3 of 3
- **Last gate**: Gate 3 - approved 2026-09-02T16:26:25Z by darryl.porter
- **Product**: edm
- **Description**: ecc-integration
- **Next action**: Ready to archive - run `edm-state archive EDMV4`

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

## Open Code-Audit Findings

not converged: 39 blocking finding(s) for EDMV4 (P0=0 P1=0 P2=39) of 215 considered, 80 NOTED excluded:
  CA-063 P2 edm-bash-gate is a sixth new bin/ script that no ticket names as a deliverable and that T50 AC1, T52 AC4 and T53 AC3 all enumerate around
  CA-066 P2 The gated allow path spawns a second jq on every gated call and no assertion pins the jq-spawn count there; T45 AC6's spy covers only the marker-absent path
  CA-068 P2 T15 AC9's assertion greps the whole of edm-gateguard for once a marker is present rather than the EDM-HELP block the AC names, so the sentence could move out of the help block undetected
  CA-069 P2 The T28 SCOPE_PARAGRAPH check is two substring greps with 44 unchecked characters between them, so a lens rewriting that middle clause passes the contract check
  CA-072 P2 The ASCII sanitizer literal is hand-copied five times across three files with no shared owner, and edm-bash-gate, the fourth consumer, has no sanitizing emit point at all
  CA-074 P2 audit-round-start materializes lenses to ALL_LENS_IDS without subtracting lenses_na and never checks disjointness, so --na-lenses without --lenses guarantees an irreversible partial downgrade
  CA-075 P2 SessionStart marker reconciliation removes a stale Phase-6 marker without recreating one for a genuinely active phase-6 initiative, and the scan-check-delete sequence holds no lock
  CA-080 P2 The EDMV4-T28 band asserts only a lens-file COUNT against ALL_LENS_IDS and never that the fourteen declared lens IDs are distinct and cover L1-L14
  CA-089 P2 The CA-471 completeness check irreversibly downgrades a round to partial if any of the 14 concurrently-written lens JSONL files has not landed yet, with no re-poll and no repair path
  CA-090 P2 The CA-471 completeness gate accepts any parseable bytes, so a placeholder lens-L{N}.jsonl satisfies it and the round converges having proved nothing about content
  CA-091 P2 The three-way completeness backstop is gated on a pass directory and manifest existing, with no else -- a round that produced no pass directory closes silently as round_type=full
  CA-094 P2 EDMV4-T17 AC2 compares two observations of the live EDMV4 state taken at different times and from different cwds, attributing every difference to the removed library
  CA-095 P2 T20/T17-AC9 git-status before/after windows span the live shared worktree, so any concurrent writer fails the assertion and is misattributed
  CA-096 P2 The suite hard-codes this initiative's live SRD artifact paths, so it fails in any other consuming repo and on archive
  CA-097 P2 T48 AC1's positive control is a tautology: it compares the real list count against anchor+1 instead of varying the list
  CA-098 P2 grep -c ... || echo 0 yields a two-line 0-newline-0 value; at :3027 it makes a missing delta file read as a clean zero count
  CA-099 P2 T48 AC4 asserts the generic substring append a and tests none of the three properties its label names
  CA-100 P2 Harvested pattern delta and provenance land at ${CLAUDE_PLUGIN_DATA}/patterns/ with no gitignore coverage; an absolute CLAUDE_PLUGIN_DATA inside any git tree makes both files untracked
  CA-102 P2 Two residual EDMV4-T57 cases run update-patterns with no CLAUDE_PLUGIN_DATA/HOME/XDG_DATA_HOME isolation, creating patterns/*-audit.md in the real host data directory
  CA-103 P2 The harvested delta is host-global rather than project-scoped and grows monotonically with no cap, rotation or eviction while being read into agent context at every audit round
  CA-104 P2 Five scratch dirs use a third idiom -- bare mktemp -d with no trap and a trailing rm a signal skips -- alongside the file's hand-rolled-trap and harness_scratch_dir idioms
  CA-105 P2 ${data}/run/ accumulates one .phase6 + .checked + .denials triple per project key ever used, with no sweep for keys whose project directory no longer exists
  CA-106 P2 edm-gateguard is the only one of the four hook consumers running set -euo pipefail; the other three use set -uo pipefail with no comment explaining the split
  CA-109 P2 Three project-root resolvers have diverged: only edm-state carries the CA-500 git-toplevel containment cross-check, while edm-hookify accepts CLAUDE_PROJECT_DIR on a bare -d test and claims parity in its help text
  CA-112 P2 edm-repo-readiness derives active initiatives from edm-state list piped through awk while edm-stop-gate uses the dedicated active-initiatives subcommand; the two sets differ on phases 0 and 7
  CA-113 P2 A hookify rule author's message is folded verbatim into permissionDecisionReason with no provenance framing, giving any cloned repository a prompt-injection channel into the model
  CA-114 P2 regex_match runs an untrusted Oniguruma pattern with no time bound; the 64 KiB input cap does not bound catastrophic backtracking and the file header claims it does
  CA-116 P2 GateGuard's MultiEdit arm shipped although decisions.md D26 conditions its shipping on a re-test that never happened; the ticket pack and the decision ledger contradict each other
  CA-118 P2 Three byte-identical awk function-body extractors plus a fourth near-variant in wave8-smoke.sh, none shared
  CA-119 P2 _t34_extract_between and _t41_extract_between re-implement _harness.sh's _wave7_extract_between, which the same file already calls at :5569
  CA-121 P2 Five near-identical UserPromptExpansion gate blocks copy-pasted per skill; the implement copy has already diverged with an extra Gate 3.5 clause
  CA-122 P2 file-event hookify rules are unreachable outside an active Phase 6 -- the marker-absent bare exit 0 precedes the hookify call site, an asymmetry the other two events do not share and that is documented nowhere
  CA-126 P2 --gateguard measures through _measure_p95's || true with no correctness probe, so an aborting gateguard still prints budget_status=MET
  CA-127 P2 EDM_GATEGUARD_MAX_DENIALS is never set by any test; only the hardcoded default of 3 is exercised, so the env-reading half of the documented knob is unverified
  CA-128 P2 Rubric signal helpers are only observed at this repository's current values and the sole score assertion is a self-consistency identity that holds for any values, including a never-matching grep
  CA-129 P2 edm-hookify list is invoked once with output discarded to /dev/null; no assertion covers the listing contract, the name fallback, or the omission of disabled rules
  CA-130 P2 MultiEdit tolerant extraction is only driven with the edits[].file_path shape; Claude Code's own single-file shape and the unique de-duplication across both shapes are untested
  CA-131 P2 gg_is_exempt is only driven with a single-entry glob value and the shipped default; the comma-split, empty-element skip, non-** glob form and explicitly-empty value are untested
  CA-132 P2 The per-prefix validate-died continue branch is untested; T46 AC9's two internal-error cases both fail active-initiatives and soft_exit before the loop is reached

## Gates

- Gate 1 - approved 2026-08-31T01:37:17Z by darryl.porter [enforcement: permission-ask]
- Gate 2 - approved 2026-09-02T03:18:49Z by darryl.porter [enforcement: permission-ask]
- Gate 3 - approved 2026-09-02T16:26:25Z by darryl.porter [enforcement: permission-ask]
- Gate code-audit - approved 2026-09-07T00:47:15Z by darryl.porter [enforcement: permission-ask] [39 P2 debt accepted, round 1, by darryl.porter at 2026-09-07T00:47:15Z]

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
