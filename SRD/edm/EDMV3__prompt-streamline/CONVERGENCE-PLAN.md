# EDMV3 Convergence Plan

Written 2026-08-16, after code-audit round 8 (pass-8). Companion to
`code-audit/pass-8_2026-08-16/REMEDIATION.md` (the per-finding detail) -- this document is the process diagnosis and the
route to convergence, not a restatement of the findings.

## 1. Where we actually are

| Metric                 | Value                               |
|------------------------|-------------------------------------|
| Rounds completed       | 8 full rounds                       |
| Total findings ever    | 471                                 |
| Fixed                  | 335 (71%)                           |
| Open                   | 69 (0 P0, 8 P1, 61 P2)              |
| NOTED (non-actionable) | 67                                  |
| Round-8 cost           | ~\$49; each full round runs \$30-60 |

**The divergence problem, in one table** -- open findings by the round that raised them:

| Raised in round | Still open |
|-----------------|------------|
| 6               | 1          |
| 7               | 20         |
| 8               | 48         |

Round 8 closed 32 findings and minted 48. The audit generates findings faster than remediation closes them. Fixing
harder does not converge this series; **changing what each fix commit is required to contain** does.

**Where the 61 open P2s live**:

| Class                                                                            | Count | Examples                                   |
|----------------------------------------------------------------------------------|-------|--------------------------------------------|
| Test-infrastructure meta-findings (`bin/tests/*` -- assertions about assertions) | ~23   | CA-401-405, CA-453-459                     |
| Production code (`bin/`, `hooks/`, `evals/`)                                     | ~30   | CA-344, CA-409-414, CA-417-421, CA-442-452 |
| Doc/ticket-text staleness                                                        | ~10   | CA-407, CA-463-470                         |

## 2. Diagnosis: the three failure loops (from the audit's own cross-round record)

These are not opinions; each is documented across multiple rounds in the ledger.

### Loop 1 -- fixes ship without their guard, so the next edit silently regresses them

- CA-397's fix (this session) broke the CA-169 inode-safety test anchor (`flock -w 10 200` ->
  `flock -w "$VAR" 200`), leaving three assertions passing **vacuously** (CA-433) -- the *second*
  recurrence of that exact anchor breaking (first: G38/CA-314).
- The same fix added `EDM_STATE_LOCK_WAIT_S` with no validation, in a file that validates every other env knob (CA-432).
- CA-389/CA-390's code fixes landed without any of the four prescribed test assertions (CA-453); no test anywhere
  asserts the "Gates approved: N of M" line either fix is about.
- L10's four-data-point observation: every extraction that shipped **with** a single-definition pin stayed fixed
  (BLOCKING_FILTER, canonical sections, assert_tree_absent); every one that shipped without one grew un-converted
  duplicate callers (skipped_phases_str, coverage headers).

### Loop 2 -- named-sites-only sweeps, so the class survives the fix

- CA-317 (job-named FAILED lines) took **4 consecutive rounds**, each round fixing the named sites and missing siblings,
  until round 7 replaced the hand list with a whole-file sweep -- which closed it permanently in one edit.
- CA-233 (extension exclusions) took 3 rounds the same way.
- CA-392's fix (this session) converted the 4 named `grep -c` sites; round 8 found **12 more** of the identical class in
  a sibling suite (folded into CA-401).

### Loop 3 -- code fixes never sweep the prose that names the behavior

- CA-416: no ledger field, AC, or remediation-format row obliges a same-commit doc sweep. The stale-citation class has
  recurred **five consecutive rounds** (CA-368 -> fixed -> fresh instance L9-006 in the very AC-file the fix touched).
  Escalated to P1 in round 8 because the fix for the class itself was prescribed in round 7 and not built.

**One structural observation on the audit target itself**: `wave7-smoke.sh` is ~8,000 lines of assertions, many of which
grep `edm-state`'s literal source text. It is the single largest finding generator (14 of 69 open; a large share of the
335 fixed). Every code fix risks breaking a source-text anchor (Loop 1), and every new assertion is new audit surface.
This is a self-feeding loop unless assertion growth is capped.

## 3. The remediation rules (apply to EVERY commit from here to convergence)

These convert the three loops into commit-time obligations. They are the actual fix for "fixing issues causes
regressions."

- **R1 -- Fix the class, not the site.** Before committing, grep the whole tree for the defect *shape* (not the reported
  line numbers). The commit closes every instance, or the commit message names the surviving instances and why they
  stay.
- **R2 -- The guard ships in the same commit.** A fix with prescribed test assertions lands them in the same commit --
  never "tests later" (that produced CA-453). A new shared helper lands its single-definition pin in the same commit
  (L10's standing rule). No exceptions.
- **R3 -- Anchor check before touching `bin/edm-state`.** Grep `bin/tests/` for any literal source text the edit
  changes; update the anchors in the same commit. (This is the CA-433 loop. A one-liner before each edit:
  `grep -rn '<old literal>' plugins/edm/bin/tests/`.)
- **R4 -- Same-commit doc sweep.** Any commit changing behavior named in an AC, comment, README, or CLAUDE.md updates
  that text in the same commit. Land CA-416's ledger-field mechanism first (Stage B below) so this is tracked, not
  remembered.
- **R5 -- Full verification before commit.** `bash -n` all touched scripts, scoped shellcheck,
  `bash plugins/edm/bin/tests/run-all.sh` green. (Already practiced this session; it caught the CA-398 die-in-subshell
  regression before it shipped. Keep it.)
- **R6 -- No new source-text-grep assertions.** New tests assert *behavior* (run the command, check the output/exit
  code), not source text, unless pinning a comment/invariant is the entire point. Stops the wave7 self-feeding loop from
  growing.

## 4. The route to convergence

Five stages. Stages A-C are work; D is the verification round; E is the gate. Detailed per-finding ordering lives in
REMEDIATION.md's Rollout Order -- this is the schedule and the decision structure.

### Stage A -- Close the 8 P1s (est. 1 focused session)

| Cluster                                              | Findings                                                                                                                                                                                                                                               | Size                                                            |
|------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------|
| A1. accept-p2-debt hardening (feature STAYS per D58) | CA-424 (amend T28 AC12 + record the EDMV3-90 change per D58), CA-425 (3 safety-guard tests), plus P2 siblings CA-426+427 (one commit -- stream split un-latches the coercion bug), CA-428, CA-429, CA-431 (CHANGELOG, version bump, state-field table) | ~6 small commits, strict internal order per REMEDIATION Stage 2 |
| A2. QC hook rewrite                                  | CA-440 (concurrent overwrite) + CA-411 + CA-412 (+ CA-409, CA-410: one gate procedure, widened prefix class) -- one edit to `hooks.json` + `implement/SKILL.md` merge step + CLAUDE.md table cell                                                      | 1 commit                                                        |
| A3. Task grants                                      | CA-441 -- three frontmatter lines + one `edm-check-grants` rule so the next skill can't repeat it (R2)                                                                                                                                                 | 1 commit                                                        |
| A4. CI-docs counts                                   | CA-460 -- fix 3 stale count sites + computed assertions so counts self-maintain (R2)                                                                                                                                                                   | 1 commit                                                        |
| A5. Eval tripwire                                    | CA-461 (field-name fix + equality assertion), CA-462 (wire `expected.json` as a 6th scorer dimension + `scorer_version` bump -- largest single item, ~50-80 lines)                                                                                     | 2 commits                                                       |
| A6. CA-416 mechanism                                 | Add the `spec/AC text swept: yes/no/n-a` field to the synthesizer's ledger template + remediation format. **Land before Stage B** so B's sweeps are tracked                                                                                            | 1 commit                                                        |

### Stage B -- Production-code P2s (~30 findings, est. 1-2 sessions)

Work REMEDIATION Stage 4's batches 1-4, 8-11 (trap hygiene, env-knob validation, eval wiring, count-capture class, hook
extraction, DRY, correctness residue, wiring residue), one commit per batch, under rules R1-R6. Two high-leverage items:

- **Batch 8 (hook extraction)**: extracting `hooks.json:86`'s body to
  `bin/edm-lint-staged-artifacts` closes CA-413 + CA-414 + CA-436 in one refactor and makes the plugin's most privileged
  shell testable. Do this one first.
- **CA-422 (consumer-side SETTABLE_KEYS check)**: land before the wiring batch -- it is the mechanism that would have
  caught three prior write-only-key findings, and makes the rest self-enforcing.

### Stage C -- Triage the remaining ~33 P2s (meta-debt decision, est. half a session)

The ~23 test-infrastructure P2s and ~10 doc-text P2s are the debt-acceptance candidates -- this is **exactly the case
`--accept-p2-debt` was built for** (D57). Split them:

- **Fix now (cheap, in Stage B's batches)**: anything that is a one-liner or rides an existing batch -- e.g. CA-408 (one
  divider line), CA-430/CA-463-466 (doc-text corrections riding the CA-416 sweep), CA-434/CA-435 (deletions).
- **Accept as documented debt**: the genuinely low-consequence meta-findings -- control-provenance quality (CA-403),
  grep -c line-vs-occurrence counts (CA-405), positive-control arm coverage (CA-457-class), and similar
  tests-about-tests polish. They stay open in the ledger, named in HANDOFF, honestly carried.

Target: enter Stage D with P1=0 and the P2 set split into "fixed" and "consciously accepted."

### Stage D -- Round 9: the verification round (est. 1 session + ~$50)

One full 11-lens round, run under a **remediation freeze** (no fixes land between lens launch and synthesis -- round 8
proved the pre-briefed re-verification flow works: 32 closures confirmed). Two known tooling preconditions:

- **CA-471 / CA-130**: lens agents may arrive without `Write` (8 consecutive rounds). Round 8's procedure --
  orchestrator persists both halves verbatim, then runs the step-8a schema check on every JSONL -- worked; treat it as
  the standing procedure, and verify all 22 files exist before spawning the synthesizer.
- Brief every lens with its own open-findings list and explicit "confirm fixed vs re-flag"
  instructions (round 8's template).

Expected outcome given Stages A-C: **P0=0, P1=0, P2 = the consciously-accepted residual** (plus whatever genuinely new
defects round 9 surfaces in the Stage A-B diffs -- budget for a small targeted fix pass + a `--lenses` partial re-check
if needed, remembering a partial round is never convergent; the final round must be full).

### Stage E -- Converge and close

1. `edm-state audit-converged EDMV3` -- confirm P0=0, P1=0.
2. Convergence gate: **Converge now** -> `edm-state approve-gate EDMV3 code-audit
   --accept-p2-debt` (records debt count/round; ledger keeps accepted P2s visible as open).
3. `decisions.md` row + REMEDIATION closure note + `edm-state write-handoff`.
4. Remaining lifecycle: `/edm:verify-runtime` for any open PARTIALs, exec-report, then
   `edm-state archive EDMV3` (its staleness guard re-verifies P0/P1 and the debt round).

## 5. Effort summary

| Stage               | Est. effort      | Exit criterion                                        |
|---------------------|------------------|-------------------------------------------------------|
| A -- P1s            | 1 session        | `audit-converged` shows P1=0                          |
| B -- production P2s | 1-2 sessions     | Stage-4 batches 1-4, 8-11 committed, run-all.sh green |
| C -- triage         | 0.5 session      | Every remaining P2 tagged fix-now or accept           |
| D -- round 9        | 1 session + ~$50 | Full round, P0=0 P1=0                                 |
| E -- converge       | 0.5 session      | `code_audit_converged=true` with documented debt      |

Total: roughly 4-5 focused sessions. The alternative -- continuing to fix P2s round-over-round without rules R1-R6 --
has produced a *growing* open count for two consecutive rounds and has no projected convergence point.

## 6. What this plan deliberately does NOT do

- It does not waive any P0/P1 -- those are never acceptable debt, and the gate enforces that.
- It does not shrink the 11-lens audit or weaken any gate -- the audit is working (it caught this session's own
  regression before it shipped); the process around *remediation* is what changes.
- It does not rewrite wave7-smoke.sh wholesale -- R6 just stops the source-text-grep pattern from growing, and Stage B's
  batch 4 converts the crash-prone captures where they already exist.
