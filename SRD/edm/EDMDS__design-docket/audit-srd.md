# SRD Audit Report: EDMDS -- EDMV4's Structural Design Docket

**SRD Version Audited**: 1.3.0 (round four, dispatched against v1.3.0; remediated through v1.7.0)
**Audit Date**: 2026-09-13
**Prior rounds**: `audit-srd-v1.2.0.md` (10 P0, 48 P1, 41 P2, FAIL), `audit-srd-v1.1.0.md`
(14 P0, 73 P1, 63 P2, FAIL), `audit-srd-v1.0.0.md` (8 P0, 32 P1, 26 P2, FAIL)

Round four. Six lanes were dispatched against v1.3.0 and all six delivered -- the first round in
which none was lost to over-scoping. Remediation ran in five increments rather than one, because
three lanes landed findings that changed decisions the later lanes were still auditing.

| Lane | Scope | P0 | P1 | P2 | Landed in |
|---|---|---|---|---|---|
| A | Epics 1-2 | 7 | 13 | 12 | v1.4.0 |
| B | Sections 1-3 | 1 | 7 | 8 | v1.4.0 |
| C | Ticket List | 8 | 31 | 24 | v1.5.0 |
| D | Sections 4, 6 and `architecture.md` | 3 | 16 | 14 | v1.5.0 |
| E | Requirements `EDMDS-01`-`EDMDS-16` | see below | see below | not recorded | v1.6.0 |
| F | Requirements `EDMDS-17`-`EDMDS-22` | see below | 23 | not recorded | v1.6.0 |
| **Recorded total** | | **19 + 4** | **67 + 23** | **58 + unrecorded** | |

Lanes E and F contributed **four P0s between them**, all four being contradictions BETWEEN
requirements rather than within one. Their individual P0/P2 splits are not recoverable: the lane
reports were consumed as they arrived and never persisted to disk, so this table reconstructs them
from `srd.md`'s own revision history. **That is a process defect, recorded here rather than tidied
away** -- rounds one through three wrote per-lane counts into this file as the lanes returned, and
round four did not. The remediation is verifiable in the document either way; the accounting is not.

**Verdict on v1.3.0: FAIL.** Verdict on v1.7.0 is deferred to Gate 2+3, which is a human's to give.

## What round four was dispatched to answer

Round three rewrote `AD-DS6`'s mechanism (D88) because the derivation it shipped was narrower than
the prose it replaced. Round four asked whether that held, and whether the remediation METHOD had
changed -- three consecutive rounds had reintroduced defects in the course of fixing others.

It held. `AD-DS6` drew no further mechanism findings. The method did not.

## The three findings that changed the document's shape

1. **The remediation method itself, diagnosed by lane A.** Three of its seven P0s were contradictions
   created by rewriting an acceptance criterion without sweeping the prose above it: `EDMDS-02`'s
   Decision block still claimed "all four surfaces" after AC6b split them, `EDMDS-04 AC3` mandated
   documenting the opposite of what AC4 implements, and `EDMDS-07`'s target still named the pattern
   D88 had already replaced in the script. One defect class, three instances, all self-inflicted by
   the previous round's fix.

2. **A lane challenged the orchestrator's own measurement, and was right (D89).** D87 had concluded
   "stdout is ignored by the host". The experiment behind it established only that a stdout `allow`
   failed to OVERRIDE an exit-2 deny -- consistent both with stdout being unread and with stdout
   being read but outranked for the decision. A lane isolated the difference and proposed the
   discriminating test. Run twice: **the model quoted the stdout reason both times**. So both streams
   reach the model at exit 2 and stdout outranks stderr, `AD-DS1` reverses to the label shape v1.1.0
   had, and `EDMDS-02 AC6`'s stdout `message` was a worse regression than the one it replaced. Four
   revisions of this decision, and the answer is where it started -- what changed is that it is now
   measured rather than argued.

3. **A security gap four revisions old.** Every consumer of a hookify rule received the rule id and
   the rule file path on the model-facing channel. Both are project-authored, and both had ridden
   that channel since v1.0.0 without any revision noticing. Closed in v1.4.0.

## The class this round finally mechanized

Seven acceptance criteria promised an assertion and named no control: `EDMDS-03 AC4`,
`EDMDS-05 AC1`, `EDMDS-06 AC3` and `AC3b`, `EDMDS-17 AC5`, `EDMDS-18 AC3`, `EDMDS-20 AC2`. An
assertion with no control is one that cannot fail, which is Goal 3 and CC1, and five consecutive
revisions shipped at least one.

Three of the seven were found by lanes reading the document. That is exactly how the other four
survived: reading finds instances, not classes. `control-coverage.sh` now derives them --
`affected-assertions.sh` answers which EXISTING assertions an edit disturbs, and nothing answered
whether a NEW assertion can fail. It is controlled by the rule it enforces: stripping
`EDMDS-09 AC3`'s control language makes it report `EDMDS-09 AC2`. Recorded as D90, bound by
Definition of Done item 10, owned by `EDMDS-T38 AC8`/`AC9`.

## Close-out state at v1.7.0

| Check | Result |
|---|---|
| `./control-coverage.sh` | exit 0 -- every assertion-bearing AC names a control |
| `./affected-assertions.sh --check` | exit 0 |
| `edm-lint-artifacts EDMDS` | CLEAN |
| `edm-state` `srd_version` | 1.7.0, matching the document |

These are the document-scoped checks. The Definition of Done's code-scoped items -- `run-all.sh`,
the four `edm-check-*` binaries, `claude plugin validate`, `timing.sh --gateguard` -- are Phase 6
obligations and are owned by `EDMDS-T38 AC7`. Nothing in Phase 3 runs them.

## The pattern across four rounds

The orchestrator's failure mode, restated because it has not changed: **generalising from a partial
check**, and its sibling, **changing a mechanism without sweeping the prose that describes it**.
Round four's own P0s are three instances of the second and one of the first (D87).

What demonstrably works against the first is measuring instead of reasoning -- D89 is the clearest
case, and the lane that forced it did so by naming what the experiment had NOT isolated. What works
against the second is a derived check rather than a careful read: `affected-assertions.sh` for
existing assertions, `control-coverage.sh` for new ones. Both were built after the class they catch
had already recurred three times or more.

## Not audited

`architecture.md` has been audited once, by lane D, in its 905-line state. `upgrade-path.md`,
`analysis.md` and `planning.md` are inputs this round's lanes read but did not audit.
