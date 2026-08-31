# Lens L9 -- Spec & Ticket Compliance (pass 5, round 5)

Initiative: EDMV3 -- prompt-streamline

## Round-4 L9 open entries -- disposition

| Ledger ID | Verdict |
|---|---|
| CA-254 | **PARTIALLY FIXED -- ticket half closed, SRD half never swept** (new finding) |
| CA-255 | **FIXED, all three halves** |
| CA-242 | **STILL OPEN, untouched by Wave 8** |
| CA-272 | **FIXED** |
| CA-273 | **FIXED** |
| CA-274 | **FIXED** |
| CA-275 | **PARTIALLY FIXED -- CHANGELOG half landed, CLAUDE.md half did not** |

## Findings (L9: Spec & Ticket Compliance)

### Missing Implementations (P1)

**CA-254's SRD half was never swept.** Wave 8e amended two ticket ACs to assert the "four
violation classes" phrase's ABSENCE, but `srd.md:4076`'s Must-Have AC still mandates its PRESENCE.
The SRD and the ticket pack now assert opposite contracts for the same requirement.

**T07 AC5** (`epics/02:307`, Must): requires exactly 3 `prototype)` sites in `bin/edm-state`
naming `cmd_archive`'s waiver as the third. The waiver was consolidated into `convergence_exempt()`
-- the tree has 2. `wave6-smoke.sh:246`, the AC's own second verify half, asserts exactly 2 and is
green. A passing suite proves the Must-Have AC false. No decisions.md record.

**T21 AC5** (`epics/03:262`, Must), second verify half: requires `grep -c 'bin/tests/' .gitlab-ci.yml`
== 1; returns 10 after CA-162's lint-glob widening and Wave 8's G21/CA-233 edit in the same loops.
Substance still holds, but permanently failing and unasserted.

**T67 AC14** (Should): Wave 8's G16/CA-196 raised timing.sh's sample count 3/5/10 -> 20, changing
what p95_ms means. `CHANGELOG.md:239` now affirmatively states the opposite of the shipped
harness; the T67 AC5 evidence row's three-sample figure can't be reproduced; no decisions.md
record despite CA-196 explicitly requiring one.

### Partial Implementations (P1)

| Ticket | Requires | Code Does | File:Line |
|---|---|---|---|
| T66/T43 | Amend ACs + record rework | Done for tickets; NOT done for the SRD requirement they implement -- opposite contracts | srd.md:4076 vs epics/11:663 |
| T67 | Reproducible evidence | Evidence table and its own caveat both predate the Wave-8 harness change | CHANGELOG.md:223,238-239 vs timing.sh:88-90 |

### Scope Creep (P2)

- **CA-253's shipped hook conversion** (exit 1 -> exit 2, five hooks) is user-visible enforcement
  behavior change with no ticket, no CHANGELOG entry, no exit-code contract in CLAUDE.md's hooks
  table. Recommendation: keep the change (sanctioned remediation), add a CHANGELOG note and
  CLAUDE.md contract row.
- **CA-251's git-lock-check rewrite** -- same treatment, no CHANGELOG entry.
- `_edm-cli-lib.sh`, `edm-mermaid-rules.awk` are NOT creep (prescribed by committed REMEDIATION
  docs, CA-175's precedent applies).

### Additional P2 findings

1. **CA-242 unremediated** -- no AC covers the bin/ script-row list; table accurate today but
   nothing can catch it going stale.
2. **Three stale citations authored the same day as the fix** -- T66 AC4 cites the wrong
   wave7-smoke.sh range for G9, T43 AC12 same, D38's re-verification result cites run-eval.sh:435/
   500 (actually :459/:524).
3. **T07 AC6** requires `code_audit_required_for_mode` to have exactly two call sites; has one
   (the second consumer deliberately routes elsewhere per D35/CA-183), while a comment still
   promises the second in future tense and the shipped test counts raw grep hits instead.
4. **T64 AC11** (Must, wave-A exit criterion) verifies `test -s .../baseline/scores.json` against
   a directory holding only README.md -- same unrunnable-half shape as CA-239->CA-272, never
   relabelled.
5. **CA-275's CLAUDE.md half unapplied** -- CHANGELOG entries landed, the prescribed CLAUDE.md
   note did not.
6. **D41 retained an invalid verification method** (`git diff --stat hooks.json is empty`) that
   CHANGELOG.md:75-76 formally declared invalid for exactly this file, in T43 AC12, T67 AC8 itself,
   T64 AC10, and epics/03:180.
7. **T28's BLOCKING_FILTER count** returns 5 as claimed but the composition (1 def, 1 real use, 3
   comments) means deleting the only real use keeps the count green -- CA-090's class.

## Cross-check: did Wave 8's non-spec fixes invalidate an existing AC verify?

**Broken by a later change**: timing.sh (T67 AC5/AC14), .gitlab-ci.yml lint jobs (T21 AC5), and
bin/edm-state's mode-derivation consolidation (T07 AC5/AC6) -- all filed above.

**Checked and still resolving correctly**: T66 AC3's 40-subcommand contract, T67 AC2's token-cap
visibility, T09 AC13's zero-`--force` requirement, T59's enum/watch-impl ACs, CA-259's deletion
(no AC references `_print_literal`), T61/T67 AC10's grep hits, the `:80-90` hooks.json citations.

## D38-D41 quality assessment against the D36/D37 bar

**Verdict: meets the bar, with one defect.** All four carry an explicit Re-verification result
clause D36/D37 lack -- an improvement addressing CA-255's root cause. Before-text fidelity is
better than the bar (D19's caveat about paraphrased before-forms doesn't recur). Cross-reference
closure is complete: all five reworked ACs now name their D number and it resolves. Defect: D38's
Re-verification result cites the wrong line numbers (finding #2 above) -- on this one axis it's
below the bar it was measured against.

## Noted / Not Actionable

1. `_edm-cli-lib.sh`/`edm-mermaid-rules.awk` correctly excluded from CLAUDE.md's bin/ table (they
   aren't PATH-exposed executables).
2. `evals/baseline/scores.json` absence already recorded in D23/CA-106; only the T64 AC11
   labelling gap is new.
3. Four `allow_failure` grep-count ACs have command imprecision but no reachable wrong conclusion.
4. T36 AC6/T13 AC8's `git diff --stat` usage is a historical per-merge-request claim, not a
   tree-state assertion -- excluded from finding #6 deliberately.
5. `lint:shellcheck`'s missing `*.awk` exclusion is an L8-owned residual, noted for cross-lens
   visibility only.
6. **CA-130 reproduces a sixth consecutive round.**

## Meta

`Write` was absent from this lens's delivered runtime tool set (ledger CA-130, sixth consecutive
round). Both `lens-L9.md` and `lens-L9.jsonl` were transcribed by the orchestrator.
