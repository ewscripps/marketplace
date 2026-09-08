# EDMDS -- EDMV4's Structural Design Docket

**Lifecycle**: `mode=mini-srd`, standard lifecycle. Phases 2 through 5 fuse into one audited file
with a merged Gate 2+3, then Phase 6.

**Forked from**: `EDMV4`
**Branch**: `edm/edmds-design-docket`, based on `0a3b665` (EDMTC's tip)
**Sibling**: `EDMTC` closed the other 21 of EDMV4's 39 accepted P2 findings

## Why mini-SRD and not fix-pack

`EDMTC` ran as a fix-pack because its 21 findings were one kind of defect with a prescription each
-- generate tickets, implement, done. **These 18 are the opposite case.** Every one needs a design
decision before a fix is even well-defined:

- Which of three diverged project-root resolvers is correct, and what happens to the other two?
- What should the CA-471 completeness gate mean when it sees a placeholder, or no manifest at all?
- Should the harvested pattern delta be project-scoped, and what bounds its growth?
- Should a rule author's text reach an operator-facing refusal at all?

A fix-pack would force an implementer to answer those silently, one commit at a time, which is how
this initiative's own history says bad decisions get made (`EDMV4` D42, D45, D47 all record a bound
or a claim quietly nudged instead of decided). mini-SRD gives exactly one human checkpoint -- the
merged Gate 2+3 -- where the answers get ratified before any code moves.

## Source of truth

| Input | Path |
|---|---|
| The 18 findings, verbatim | `inherited-findings.jsonl` (this directory) |
| Full prescriptions | `SRD/.archived/edm/EDMV4__ecc-integration/code-audit/pass-1_2026-09-04/REMEDIATION.md` |
| Why they were carried | `SRD/.archived/edm/EDMV4__ecc-integration/code-audit/p2-triage.md` (group 5) |
| Why they were left unnamed | `SRD/.archived/edm/EDMV4__ecc-integration/decisions.md` D51 |

The 18 keep their original `CA-NNN` ids and remain open in EDMV4's archived ledger. That ledger
records what EDMV4 shipped; rewriting it would misdescribe history. EDMDS is the record of closure.

**D51 said these would stay unowned.** That is now superseded: the user asked for them owned, split
three ways. The reasoning D51 gave -- that a design docket is not a work package and a single prefix
would imply a plan that does not exist -- is answered by the three-epic split below, where each epic
IS a coherent decision with a scope, rather than one bucket of eighteen unrelated questions.

## Epic 1 -- Untrusted input and an unratified gate surface (5)

**Run this first.** These are the only findings in the docket that touch a security boundary or a
shipped-without-ratification contract, and they sit in the hook that can refuse a tool call.

| Finding | File | The question |
|---|---|---|
| CA-113 | `bin/edm-gateguard` | A hookify rule author's `message` is folded verbatim into `permissionDecisionReason` with no provenance marker. Should project-authored text reach an operator-facing refusal at all, and if so, how is it fenced and attributed? |
| CA-114 | `bin/edm-hookify` | `regex_match` runs an untrusted Oniguruma pattern with no time bound. The 64 KiB input cap limits SIZE, not TIME -- a catastrophic-backtracking pattern is a committed file away. What bounds it, given no `timeout(1)` on stock macOS? |
| CA-116 | `bin/edm-gateguard` | GateGuard's `MultiEdit` arm shipped although `decisions.md` D26 conditions its shipping on a re-test that never happened. Ratify or withdraw. |
| CA-122 | `bin/edm-gateguard` | `file`-event hookify rules are unreachable outside an active Phase 6, because the marker-absent fast path exits before evaluation. Is that intended scoping or an accidental hole in a documented feature? |
| CA-063 | `bin/edm-bash-gate` | A sixth new `bin/` script that no ticket names as a deliverable. Decide whether it is a deliverable and record it, or explain why it is not. |

CA-114 is the sharpest: an unbounded regex in a blocking hook is a denial-of-service on the
developer's own session, reachable by a source-controlled file that looks like configuration.

## Epic 2 -- Completeness-gate and audit-round semantics (5)

All in `bin/edm-state`. These decide what the audit's own integrity machinery MEANS.

| Finding | The question |
|---|---|
| CA-089 | The CA-471 completeness check irreversibly downgrades a round to `partial` if any of the concurrent lens JSONL is missing. Is irreversibility correct, or should a repaired round be re-completable? |
| CA-090 | The gate accepts any parseable bytes, so a placeholder `lens-L{N}.jsonl` satisfies it and the round converges having proved nothing about content. What is the minimum a lens artifact must contain? |
| CA-091 | The three-way backstop is gated on a pass directory and manifest existing, so a round producing NO manifest -- arguably the strongest non-delivery signal -- escapes entirely. What should absence mean? |
| CA-074 | `audit-round-start` materializes `lenses` to `ALL_LENS_IDS` without subtracting `lenses_na`, so the union rule that derives `round_type` is computed from a set that double-counts. |
| CA-075 | `SessionStart` marker reconciliation removes a stale Phase-6 marker without recreating one for a genuinely active initiative. |

CA-090 and CA-091 are the load-bearing pair: together they decide whether "the round converged" is
a claim about delivery or merely about file existence.

## Epic 3 -- Resolver divergence, data-directory lifecycle, and duplication (8)

| Finding | File | The question |
|---|---|---|
| CA-109 | `bin/edm-hookify` | Three project-root resolvers have diverged; only `edm-state` carries the CA-500 git-toplevel cross-check. Which is canonical? |
| CA-112 | `bin/edm-repo-readiness` | Derives active initiatives by piping `edm-state list` through awk, while `edm-state` has its own accessor. Same class as CA-109. |
| CA-072 | three files | The ASCII sanitizer literal is hand-copied five times with no shared owner. |
| CA-121 | `hooks/hooks.json` | Five near-identical `UserPromptExpansion` gate blocks copy-pasted per skill, and the `implement` copy has already drifted. |
| CA-100 | `bin/_edm-datadir-lib.sh` | Harvested delta and provenance land in the data dir with no `.gitignore` coverage decision. |
| CA-103 | `bin/edm-state` | The harvested delta is host-global rather than project-scoped and grows monotonically with no cap. |
| CA-105 | `bin/edm-gateguard` | `${data}/run/` accumulates a `.phase6` + `.checked` + `.denials` triple per project key ever used, with no reaping. |
| CA-106 | `bin/edm-gateguard` | It is the only one of four hook consumers running `set -euo pipefail`; the other three do not. Which posture is right for a hook? |

CA-109 and CA-112 are one decision. CA-100, CA-103 and CA-105 are one decision about data-directory
lifecycle and scoping. CA-072 and CA-121 are the same duplication question at two sites.

## Constraints carried from EDMV4 and EDMTC

- **CC1**: every assertion added gets a NEGATIVE CONTROL proving it can fail. EDMV4 fixed fifteen
  findings of the "assertion that cannot fail" class; EDMTC's whole subject was that class, and an
  agent there still caught itself writing one.
- **CC2**: no self-matching scans (six recorded instances).
- **CC3**: no `var="$(cmd | ...)"` under `set -e` (twelve recorded instances); never `$?` after a pipe.
- **CC4**: bash 3.2 floor; required binaries stay `bash`, `jq`, `git`.
- **CC5**: ASCII only; `wave8-smoke.sh` stays executable and new bands go BEFORE its own
  `Results:`/`exit` lines.
- **CC6**: `run-all.sh` stays at or above **4048 passed, 0 failed across 8 suites** (the EDMTC exit
  figure, GNU bash 3.2.57, quiet tree). A lower count is a regression.
- **CC7**: `EDMV4-T11` AC1 pins `bin/edm-gateguard` to a CLOSED 200-660 line range and it stands at
  **659** -- one line of headroom. Epic 1 and Epic 3 both touch that file. Do not nudge the bound;
  it has been widened twice already (D42, D47) and each widening was recorded as a decision.
- **CC8**: a scratch directory uses one of EDMTC-T03's two sanctioned forms. A third form is
  detected and fails.

## Known context a design decision here must not re-break

- **CA-134's residual**: EDM's data-directory ownership test treats a directory carrying `patterns/`
  as EDM-owned, for C-4 backward compatibility. That is why a foreign plugin's directory stayed
  claimed. Epic 3's CA-100/103/105 decisions touch the same resolver -- a stricter rule must not
  abandon existing installs, which a sentinel-only test provably did (58 failing assertions).
- **`wave6-smoke.sh` writes markers into the real host data directory.** Not in this docket, same
  class as CA-102, currently unguarded. Epic 3 is the natural home if the lifecycle decision covers it.
