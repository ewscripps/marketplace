# EDMTC -- P2 Test-Coverage Debt from EDMV4

**Lifecycle**: `fix-pack`. Phases 1, 2, 3 and 5 are recorded skipped -- the analysis this
initiative works from already exists and was already audited, as EDMV4's own code-audit output.
Re-deriving it through a fresh Phase 1 and SRD would restate conclusions rather than test them.

**Forked from**: `EDMV4` (`edm-state set-forked-from EDMTC EDMV4`)
**Branch**: `edm/edmtc-p2-test-coverage`, based on EDMV4's tip `20d262a` (tag `edm-v3.3.0`)

Branching from EDMV4's tip rather than `main` is deliberate and load-bearing: `main` does not
contain any of the code these 21 findings are against. EDMV4 is 213 commits ahead of it and
unmerged.

## Source of truth

| Input | Path |
|---|---|
| The 21 findings, verbatim | `inherited-findings.jsonl` (this directory) |
| Full prescriptions per finding | `SRD/.archived/edm/EDMV4__ecc-integration/code-audit/pass-1_2026-09-04/REMEDIATION.md` |
| Why they were carried rather than fixed | `SRD/.archived/edm/EDMV4__ecc-integration/code-audit/p2-triage.md` |
| The decision naming EDMTC as owner | `SRD/.archived/edm/EDMV4__ecc-integration/decisions.md` D51 |
| Cross-round ledger they came from | `SRD/.archived/edm/EDMV4__ecc-integration/code-audit/findings-ledger.jsonl` |

The 21 IDs keep their original `CA-NNN` numbers. They are NOT renumbered: they remain open in
EDMV4's archived ledger, and renumbering would sever the only link between the finding and the
lens that raised it.

## Scope

All 21 are group 2 of EDMV4's P2 triage: **test-coverage gaps**. They are one kind of defect --
a check that reports success while verifying less than it claims, or a code path with no check at
all. That homogeneity is why this is a work package and can be scheduled as one, whereas group 5's
18 structural findings were deliberately left unnamed as a design docket.

By owning file:

| File | Findings |
|---|---|
| `bin/tests/wave8-smoke.sh` | CA-068, CA-069, CA-080, CA-094, CA-095, CA-096, CA-098, CA-099, CA-104, CA-118, CA-119 |
| `bin/edm-gateguard` (coverage of) | CA-066, CA-127, CA-130, CA-131 |
| `bin/tests/wave7-smoke.sh` | CA-097, CA-102 |
| `bin/edm-repo-readiness` | CA-128 |
| `bin/edm-hookify` | CA-129 |
| `bin/edm-stop-gate` | CA-132 |
| `bin/tests/timing.sh` | CA-126 |

## The two findings that are not merely coverage

**CA-096** hard-codes EDMV4's live SRD artifact paths, so `wave8-smoke.sh` fails in any other
repository. This one does not degrade our own signal -- it breaks the suite for the next adopter,
which is why D51 argued group 2 needed a named owner rather than silent acceptance.

**CA-094 and CA-095** compare two observations of live, shared state taken at different times, so
they are flaky by construction rather than wrong. Concurrent activity in the worktree changes the
answer between the two reads.

## Non-negotiable for this initiative

Every assertion added or repaired here gets a **negative control** that proves it can fail --
inject the defect into a scratch copy and confirm rejection. EDMV4 fixed fifteen findings of the
"assertion that cannot fail" class, every one a check reporting success while verifying nothing.
An initiative whose entire subject is coverage quality cannot ship a sixteenth.

Guard against the two recurring traps EDMV4 recorded:

- **Self-matching scan** (six instances): a scan whose own comment contains the token it greps for
  fails on the prose describing it. Strip comment lines, or phrase the comment so it cannot
  self-match, and add a positive control injecting a real occurrence on a code line.
- **`var="$(cmd | ...)"` under `set -e`** (twelve instances): aborts the suite mid-run rather than
  failing an assertion. And `$?` after a pipe reads the LAST element's status.

## Verification baseline at fork

`run-all.sh` under GNU bash 3.2.57 on a quiet tree: **3870 passed, 0 failed across 8 suites**
(wave3 14, wave4a 63, wave4b 98, wave5 45, harness 59, wave6 799, wave7 1452, wave8 1336, plus
run-all's own 4 checks). Any assertion count below this after a change is a regression, not a
tidy-up.

`bin/tests/wave7-smoke.sh` asserts a tracked-tree fingerprint invariant and must be run ALONE on a
quiescent tree -- never concurrently with a commit or another suite.
