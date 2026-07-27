# Ticket Pack Audit Report: EDMV3 (Auditor 2 -- AC Quality, Sizing, Diagrams, Consistency)

**Date**: 2026-07-25
**Pack**: `tickets/` | **SRD**: srd.md v1.1.0 | **Ground truth**: plugins/edm/
**Verdict**: NEEDS FIXES -- no P0, 6 P1, 42 P2, 15 NOTED.

## Findings

### Coverage

T2-01 | P1 | high | Coverage | T17 AC7 / T18 AC9 / T62 AC6 | HANDOFF generator emits non-ASCII em dashes no ticket fixes, making "HANDOFF is ASCII-only and --all exits 0" ACs unsatisfiable. plugins/edm/bin/edm-state:1754, :1763, :1772 each contain a literal U+2014 in next_action text; HANDOFF.md is written into the initiative directory that lint class 2 scans; T62 AC6 guarantees the lines fire. Fix: add an AC to T17 (wave A) normalizing the three em dashes to `--`, verified by `LC_ALL=C grep -n '[^\x00-\x7F]' plugins/edm/bin/edm-state` returning nothing in that region.

T2-02 | P1 | high | Coverage | T43 AC4/AC5/AC7, T44 AC1/AC5 | Five ACs invoke edm-lint-artifacts with a directory/file path, but the script only accepts a PREFIX (edm-lint-artifacts:37 usage die; :44 resolve-dir); T20 adds --all only. Every command exits 1 "no initiative for prefix". Fix: add an AC to T20 introducing `edm-lint-artifacts --path <dir|file>` (read-only, no state resolution), or rewrite the five verifications through wave7-smoke.sh with an internal helper.

T2-03 | P1 | high | Coverage | T27 AC1 vs T14 AC7 | T27 silently changes `audit_rounds.<type>` from integer to object; contradicts T14 AC7 "no existing field changes type"; breaks jq reads on legacy files (edm-state:1402 writes plain integer; EDMV2 file has audit_rounds.code=2). Fix: explicit C-4 coercion AC on T27 (integer read as {count: N, rounds: []}, asserted against a fixture) and reconcile T14 AC7 naming the widening as the single sanctioned exception.

T2-04 | P1 | medium | Coverage | T02 AC8, T24 AC1/AC10, T25 AC1/AC5, T42 AC9 | Six ACs verify against "a fixture code-audit round" but the only fixture driver (T22) runs plan->srd->audit, never a code audit. Fix: deliver a code-audit-capable path (run-eval.sh --with-code-audit) or re-point at a committed synthetic pass directory under bin/tests/fixtures/code-audit/.

T2-05 | P2 | high | Coverage | T24 AC7 | Verifies against bin/tests/fixtures/lens-L1.jsonl, a fixture no ticket creates. Fix: add creation AC to T24 (one line per severity plus one NOTED line).

T2-06 | P2 | high | Coverage | T56 | docs/audit-patterns/SOURCES.md (two ## headings) is neither covered nor exempted by the four-heading contract test. Fix: extend AC4 to name both exemptions (README.md, SOURCES.md) explicitly.

T2-07 | P2 | medium | Coverage | EDMV3-90 row vs T09/T30 SRD Refs | EDMV3-90 is simultaneously a boundary with "no implementation ticket" and an SRD Ref on two tickets. Fix: drop EDMV3-90 from both tickets' SRD Refs; keep the negative ACs as the enforcement record.

T2-08 | NOTED | high | Coverage | README Epics Summary | Requirement and ticket arithmetic reconcile exactly (120; 67). Clean.

### Sizing

T2-09 | P2 | high | Sizing | T37 + T38 Ships-with group | Two L tickets same-MR = an XL delivery unit by the pack's own legend (moves six phase procedures, rewrites 645->300 lines, re-baselines ~30 assertions, carries eval gate). Fix: record the combined unit in the README Ships-with table as one L-class MR of 16-21 pt with an internal two-commit structure, and add an AC to T38 requiring the MR to be two reviewable commits.

T2-10 | P2 | medium | Sizing | T09 | M but L-shaped: rewrites cmd_set, defines whole schema_version contract, creates wave7-smoke.sh; six direct dependents. Fix: resize L, or split schema_version contract into its own S ticket.

T2-11 | P2 | medium | Sizing | T61 | M but adds three CI job families plus two-script sentinel refactor plus hardening. Fix: resize L or move the runner matrix into a separate S ticket.

T2-12 | P2 | medium | Sizing | T67 | M but delivers a committed timing harness, 50-initiative fixture generator, 14 measurement ACs. Fix: resize L, or split the timing script (wave-A S) from the wave-C measurement record.

T2-13 | P2 | medium | Sizing | T02 | S but touches 14 agent files, hand-writes 12 output contracts, runs a spike, requires a fixture audit round. Fix: resize M.

T2-14 | P2 | low | Sizing | T22 | M but headless driver + synthetic repo + four-valued exit contract is characteristically L. Fix: consider L or descope expected.json into T23.

T2-15 | NOTED | high | Sizing | XS share 6% vs 10-20% band | Disclosed with a sound rationale.

T2-16 | NOTED | high | Sizing | T33, T37, T38 L justifications | All three survive scrutiny.

### Dependencies

T2-17 | P1 | high | Dependencies | T02 (Depends On: --) | T02 AC8 requires the eval fixture from T22; undeclared, both wave A so wave order does not save it. Fix: add EDMV3-T22 to T02's Depends On + Mermaid edge, or re-scope AC8 to a hand-built scratch initiative.

T2-18 | P2 | high | Dependencies | T24 | AC10 invokes evals/score-artifacts.sh from T23; undeclared (cross-wave A->B so safe, but invisible). Fix: add the edge or move AC10 to T23.

T2-19 | P2 | high | Dependencies | T36 | Technical Notes hand the implementer a choice of two build orders instead of declaring one. Fix: add EDMV3-T33 to Depends On, delete the "or" clause, add the T33->T36 Mermaid edge.

T2-20 | P2 | high | Dependencies | T63 (wave A) | AC6 asserts wave-B artifacts from a wave-A ticket; cannot close in its wave. Fix: move AC6 to T65 or split T63b.

T2-21 | P2 | medium | Dependencies | T33 | AC11 requires T13's gate-token work; declared only in Technical Notes. Fix: add EDMV3-T13 to Depends On.

T2-22 | P2 | low | Dependencies | T60 AC7 | Reuses T61's test without declaring the dependency. Fix: add the edge or make the manual fallback explicit in the AC.

T2-23 | NOTED | high | Dependencies | Whole graph | Every declared edge drawn, no undeclared edges in the diagram, acyclic, wave-monotone. Unusually clean.

### Critical Path

T2-24 | P2 | high | Critical Path | README | "Sixteen tickets deep" contradicts the chains printed below it; true longest chain is 9. Fix: correct.

T2-25 | P2 | high | Critical Path | README | T09 transitive dependents are 17 (6 direct), not 8. Fix: correct; conclusion is strengthened.

### AC Quality

T2-26 | P1 | high | AC Quality | T62 AC1 | Verification asserts state key `recorded_at`; code writes `skipped_at` (edm-state:1483). Command fails against correct code. Fix: change to has("skipped_at") or add an explicit C-4 rename AC.

T2-27 | P2 | high | AC Quality | T54 AC8 | Reads `.patterns_updated`; actual fields are `patterns_last_updated` / `patterns_updates` (edm-state:1682-1683). Fix: correct the jq.

T2-28 | P2 | high | AC Quality | T54 AC1 | awk range `/^## Anti-Patterns/,/^## /` collapses to a single line (end pattern tested on the start record); grep -c returns 0 unconditionally. Fix: use the guard-flag awk idiom already in wave4b-smoke.sh:101.

T2-29 | P2 | high | AC Quality | T23 AC3 | Malformed jq (`.total` resolves against the array after the pipe) plus an "adapt the path expression" license making it unfalsifiable. Fix: `jq -e '. as $r | ([$r.dimensions[].score] | add / 5 * 10 | round / 10) == $r.total'` and delete the adapt clause.

T2-30 | P2 | high | AC Quality | T03 AC6 | Asserts "exactly five skills missing AskUserQuestion" but only four exist pre-T33 (verified: one allowed-tools occurrence, orchestrator only). Fix: "exactly four", note the fifth arrives with T33.

T2-31 | P2 | high | AC Quality | T49 AC2 | "Three sources" followed by an enumeration of four; verify checks only two. Fix: "Four sources"; extend the verify to assert a URL line for each.

T2-32 | P2 | high | AC Quality | T20 AC3 | Either/or AC passes under both outcomes; an empty wave99 file passes vacuously. Fix: assert the auto-discovery branch with a scratch suite containing exit 1.

T2-33 | P2 | medium | AC Quality | T09 AC13 vs T11 AC7 / T12 AC12 | Pack disagrees with itself on whether literal `--force` may appear in bin/edm-state. Fix: no literal `--force` in bin/edm-state (unknown-argument path only); T09 AC13 expects zero results.

T2-34 | P2 | medium | AC Quality | T05 AC2 vs T06 AC5 (and T10 AC6, T17 AC3, T18 AC7, T51 AC4/AC5, T62 AC3/AC7) | Incompatible anomaly line formats (class-prefixed four-field vs legacy three-field). Fix: update all restatements to the post-T05 four-field format.

T2-35 | P2 | medium | AC Quality | T02 AC7 | Expected result and command output shape mismatch (12 lines not 11; file:count lines not a count). Fix: `grep -lc ... | wc -l` prints 12.

T2-36 | P2 | medium | AC Quality | T46 AC12 (also T50 AC2/AC3, T53 AC1/AC4, T55 AC8, T58 AC6, T34 AC7) | `grep -rc ... returns 0` idiom is wrong (prints file:0 lines, exits 1). Fix: normalize to `grep -rl ... | wc -l` prints 0.

T2-37 | P2 | medium | AC Quality | T22 AC4 | "Run with network disabled" names no mechanism. Fix: name it (unshare -rn or poisoned proxy vars).

T2-38 | P2 | medium | AC Quality | T21 AC3 vs T57 AC6 | Verbatim duplicate scan requirement in two waves with no authority statement. Fix: keep the scan on T57; reduce T21 AC3 to non-blocking add.

T2-39 | P2 | low | AC Quality | T49 AC6 | Negative grep (`verification step`) will false-positive once verify-runtime exists. Fix: narrow to self-verification phrasing or carve out skills/verify-runtime/.

T2-40 | P2 | low | AC Quality | T21 AC10/AC11 | Screenshot/URL-only evidence. Fix: name the API-response inspection target.

T2-41 | P2 | low | AC Quality | Nine tickets above the 6-12 AC band | T33 15, T29 14, T67 14, T09/T23/T28/T46/T54/T61 13. Fix: record the band deviation in the README sizing section.

T2-42 | NOTED | high | AC Quality | D13/D15 sweep | Clean: no deferral vocabulary as disposition; --force/--accept-partials only in labelled negative tests.

T2-43 | NOTED | high | AC Quality | T33, T32, T18 | verify-runtime PASS/FAIL-only + D15 rework path encoded correctly at policy, prompt, data, and archive layers. Strongest chain in the pack.

T2-44 | NOTED | high | AC Quality | High-risk tickets | All eight carry labelled positive AND negative ACs; boundary inputs covered.

T2-45 | NOTED | medium | AC Quality | Manual-QA ACs | Every manual AC names an inspection target; none says "verify manually".

### Diagrams

T2-46 | P2 | high | Diagrams | README Mermaid waveC class line | T53 never classed (66 of 67 nodes colored). Fix: insert T53.

T2-47 | P2 | medium | Diagrams | README Mermaid | T04, T49, T52 isolated without an explanatory note. Fix: one-line note.

T2-48 | NOTED | high | Diagrams | README Mermaid | Syntactically valid, zero semicolons inside the fence, classDef lines clean, node count matches. Live subject for T44 AC7.

### Consistency

T2-49 | P2 | high | Consistency | README T09 row vs epics/02 | SRD Refs disagree (EDMV3-90). Fix: reconcile per T2-07.

T2-50 | P2 | medium | Consistency | T66 AC4 vs plugins/edm/CLAUDE.md bin/ table | The linter row's existing parenthetical names three classes the script does not implement; AC passes even if it survives. Fix: extend AC4 with a zero-results grep on the wrong names.

T2-51 | P2 | medium | Consistency | T29 Description | Sweep counts undercount: ~45 occurrences across 14 files (not ~40/12), incl. CHANGELOG and bin/tests carve-outs. Fix: update, since the ticket sizes from the grep.

T2-52 | P2 | low | Consistency | T29 Target Components | agents/edm-ticket-auditor.md:73 listed as an edit site but is a correct by-name reference with no deferral token. Fix: remove or reclassify as no-change-needed.

T2-53 | P2 | low | Consistency | T08 Target Components | "metrics gate timing near :1052-1068" starts four lines late; loop begins :1048. Fix: correct.

T2-54 | P2 | low | Consistency | T61 AC3 / T20 AC6 | `list --paths` flag invisible to the help-completeness contract. Fix: add the flag to the help line as an explicit item.

T2-55 | P2 | low | Consistency | T21 AC5 vs T20 AC1 | Enumerated CI suite list vs auto-discovering aggregator = two sources of truth. Fix: CI invokes run-all.sh and nothing else.

T2-56 | P2 | low | Consistency | T47 AC6 | Negative diff-grep on bare digits guaranteed to false-positive next to T37. Fix: replace with positive assertions on surviving text.

T2-57 | P2 | low | Consistency | T44 AC1 | Corpus floor does not distinguish valid/ from invalid/ sets. Fix: assert both floors separately.

T2-58 | NOTED | high | Consistency | bash 3.2 | Respected pack-wide; explicit banned-construct ACs; workarounds prescribed in notes.

T2-59 | NOTED | high | Consistency | ASCII | Pack clean (plugin source is not -- see T2-01, owned by T63/T17).

T2-60 | NOTED | high | Consistency | IDs and cross-tables | All clean.

T2-61 | NOTED | medium | Consistency | Smoke-suite naming | wave6/wave7 continue EDMV2 numbering; unrelated to waves A/B/C -- optionally state the mapping once.

T2-62 | NOTED | high | Consistency | Duplicate scan | No merge candidates; closest (T64/T65/T66) is the deliberate per-wave closeout pattern; overlap well under 70%.

T2-63 | NOTED | high | Consistency | Prose vs srd.md/decisions.md | No contradictions found; load-bearing claims spot-checked and exact.

### Version Alignment

NOTED (PASS): Generated From v1.1.0 three-way match.

## Tallies

**Code anchors: 121 checked, 117 exact, 1 marginal (T2-53), 3 failed (T2-26 recorded_at, T2-27 patterns_updated, T2-03 audit_rounds shape).** Behaviour descriptions checked, not just line numbers -- descriptive prose exceptionally accurate.

**AC sample: 60 tickets read in full, 34 audited AC-by-AC. 686 ACs total, mean 10.2, range 7-15. Broken/unfalsifiable verifications: 8 (~1.2%). Vague ACs: zero. Unnamed verification targets: zero.**

**Diagram verdict: PASS WITH ONE FIX** (T53 class; isolated-node note).

## Recommendations (prioritized)

Must fix before Phase 6 (P1): T2-01 (HANDOFF em dashes -> T17 AC), T2-02 (lint path mode), T2-03 (audit_rounds migration), T2-04 (code-audit fixture path), T2-17 (T02 -> T22 edge), T2-26 (recorded_at -> skipped_at).
Same editing pass: T2-46, T2-24/25, T2-27/28/29/32/36, T2-30/31, T2-33/34.
Before wave planning: T2-09 (T37+T38 XL delivery unit), T2-10..T2-14 resizes, T2-19/T2-20.
Batch editorial: T2-05/06/07/18/21/22/35/37..45/49..57.

## Overall Verdict

Strongest ticket pack audited against this methodology: D13/D15 chain encoded at all four layers with no escape hatch outside labelled negative tests; every high-risk ticket has labelled positive and negative ACs; graph 100% edge-faithful and acyclic; 117/121 anchors exact. Blocking: six P1s sharing one root cause -- ACs written against a described system rather than the actual one (HANDOFF em dashes, lint path mode, audit_rounds type change would each stall a sprint). Sizing needs one structural correction: T37+T38 is an XL delivery unit wearing two L labels; T09, T61, T67, T02 undersized. Fix the six P1s, the T53 class line, the two critical-path numbers, and the T37+T38 unit, and the pack is ready for implementation.
