# Ticket Pack Audit Report: EDMV3 (Auditor 1 -- Coverage, Dependencies, Critical Path, Version Alignment)

**Date**: 2026-07-25
**Pack**: `tickets/` (README.md + `epics/01..11`, 67 tickets, 3 waves)
**SRD**: srd.md v1.1.0 (120 requirements)
**Verdict**: NEEDS FIXES -- no P0, 5 P1.

## Findings

### Coverage

T1-01 | P1 | high | Coverage | srd.md EDMV3-07 AC11 vs T03 "Out of Scope" and T58 | An SRD Must-Have AC is satisfied by no ticket, and the pack silently overrides it. SRD EDMV3-07 AC11: "The manual ritual at `skills/implement/SKILL.md:162-172` is deleted in the same MR (EDMV3-81)." EDMV3-07 is E1/wave A (T03); EDMV3-81 is E10/wave C (T58). T03's Out of Scope defers the deletion to T58, two waves later. architecture.md step A3 agrees with the same-MR reading (wave A). Not in the pack's 8 declared ambiguities. Fix: raise an SRD change request rewording EDMV3-07 AC11 to "the ritual is deleted by EDMV3-81 once this check exists; the ordering edge is recorded in Sec 11.2" (recommended), or move the deletion into T03. Add as ambiguity 9; reconcile architecture.md A3.

T1-02 | P2 | high | Coverage | README coverage map row EDMV3-106 | Coverage map claims T04 delivers EDMV3-106 but T04's SRD Refs are EDMV3-06, EDMV3-87 only. Fix: add EDMV3-106 to T04's SRD Refs or drop the clause from the row.

T1-03 | P2 | high | Coverage | README coverage statistics vs T04/T14/T30/T38/T09 | Statistics table says zero Won't-Have requirements covered by tickets while four tickets declare Won't-Have SRD Refs (T04: 87, T14: 89, T30: 90, T38: 86; epic file T09: 90). Fix: pick one convention and apply to all five (recommend: strip Won't-Have IDs from SRD Refs, keep negative-enforcement notes in coverage-map disposition column).

T1-04 | P2 | high | Coverage | EDMV3-69 AC1 / T49 AC7 vs T24, T36, T42, T53, T58 | Prompt-text tickets missing the required before/after AC; T49 AC7's grep returns 0 for epics/03, /08, /10. Fix: add the before/after AC to T24, T36, T42, T53, T58 and audit the remainder, or narrow EDMV3-69 AC1 + T49 AC7.

T1-05 | P2 | medium | Coverage | README Epics Summary requirement counts | Counts are SRD-ownership counts, not delivered-by-this-epic's-tickets counts (E11 credited 26, its tickets carry 16). Fix: footnote "Requirement count is the SRD Sec 14.2 ownership count; cross-epic deliveries visible in the coverage map."

T1-06 | P2 | medium | Coverage | T63 AC6 vs T65 SRD Refs | T63 (wave A) AC6 covers wave-B artifacts "checked at T65", but T65 does not carry EDMV3-95. Fix: add "EDMV3-95 (wave-B artifacts)" to T65's SRD Refs with an explicit AC.

T1-07 | NOTED | high | Coverage | EDMV3-88 | Only requirement with zero ticket references; correct by construction (D8 forbids the ticket).

### Sizing

T1-08 | P2 | medium | Sizing | T61 (M) | Undersized: four cross-cutting requirements, 13 ACs, sentinel refactor of two scripts, bidirectional help test, shellcheck job, bash 3.2 image, macOS runner. Fix: split (T61a wave A / T61b wave C addendum) or promote to L with justification.

T1-09 | P2 | medium | Sizing | T09 (M) | Undersized: four requirements, 13 ACs, new wave7-smoke.sh suite that three other tickets consume; most schedule-critical node (17 transitive dependents). Fix: size L, or split the caller-contract test into its own S ticket.

### Dependencies

T1-10 | P1 | high | Dependencies | T33 AC8 vs T38 AC4 | Undeclared edge: T33 adds a Skill-tool invocation to the orchestrator body; only T38 adds `Skill` to the orchestrator's allowed-tools; T03's grant checker reds CI in the interval. Adding T38 to T33's Depends On creates no cycle. Fix: add the edge, or move the orchestrator Phase 6 wiring into T38/T50.

T1-11 | P1 | medium | Dependencies | T36 AC1 vs T33 | Undeclared edge plus a latent circular constraint the prose resolves two contradictory ways (T36 asserts Step 0 in 8 skills incl. verify-runtime which T33 creates; T33 AC11 requires the Step 0 block T36 defines). Fix: add EDMV3-T33 to T36's Depends On and delete T33 AC11's Step 0 clause (T36 adds it), recording the choice in both tickets.

T1-12 | P2 | high | Dependencies | T03 AC9, T04 AC6 vs T09 | Implicit dependency on wave7-smoke.sh, created by T09; neither ticket declares it. Fix: add EDMV3-T09 to T03 and T04's Depends On.

T1-13 | P2 | high | Dependencies | T26 AC8, T33 AC15, T63 AC6 vs T43 | Three ACs require the fourth (Mermaid) lint class with no declared edge to T43. Fix: add EDMV3-T43 to T26's and T33's Depends On; for T63, move AC6 to T65.

T1-14 | P2 | high | Dependencies | T15/T03, T25/T24, T30/T29, T38/T37 | Four of six Ships-with groups also declare a Depends On edge between the same tickets, contradicting the pack's own field definition ("Same merge request, no build-order relationship"). Fix: delete the duplicated Depends On edge and keep Ships-with; re-derive the Mermaid and longest-chain narrative.

T1-15 | P2 | high | Dependencies | T27 Ships-with T51 (cross-wave) | Reciprocal but unsatisfiable as same-MR (wave B vs C). Fix: replace with a `Shared record shape:` note in both tickets; remove from the README same-MR table; raise the SRD change request against EDMV3-120's Ships-with EDMV3-71.

T1-16 | P2 | medium | Dependencies | T21 AC3 vs T57 | "Non-blocking until T57 clears it" state has no tracking edge and T57's ACs describe adding the check, not flipping it. Fix: add a flip-to-blocking AC to T57 and a cross-check row to T66 AC11.

T1-17 | NOTED | high | Dependencies | T01 AC9, T04 AC8, T63 | Forward references correctly neutralized with explicit "checked at wave close" language; model handling.

### Critical Path

T1-18 | P2 | high | Critical Path | README "Longest chain" | "Sixteen tickets deep" is wrong; independent longest-path computation over all edges gives 9 nodes: T07 -> T08 -> T09 -> T11 -> T50 -> T51 -> T48 -> T53 -> T66. Fix: state nine.

T1-19 | P2 | high | Critical Path | README T09 narrative | "Eight tickets depend on it transitively" understates by 2x: transitive closure is 17 (direct 6). Fix: correct to 17.

T1-20 | NOTED | high | Critical Path | Independent DAG extraction | 118 edges, topological sort succeeds, max level 8; exact bidirectional match with the Mermaid; no wave inversions.

### AC Quality

T1-21 | P1 | high | AC Quality / Wave integrity | T61 AC3, AC5 | Two ACs on a wave-A Must ticket unsatisfiable at wave-A close: they enumerate four subcommands of which three are wave B/C; the hedging sentence silently redefines the criterion mid-AC. Under the pack's own D15 rule an unverifiable AC is a spec defect. Fix: scope AC3/AC5 to "every subcommand that exists at this ticket's wave boundary"; move the four-subcommand assertion to T66 AC3. Also give EDMV3-91 the same wave-split treatment as EDMV3-96 (the pack flags 96 only, missing 91 -- root cause of this finding).

T1-22 | P2 | high | AC Quality | T09, T23, T28, T29, T33, T46, T54, T61, T67 | Nine tickets exceed the 6-12 AC band (13-15 ACs). Fix: accept with a one-line note per ticket, or decompose the worst (T61, T67, T29).

T1-23 | P2 | high | AC Quality | T23 AC3 vs its own Technical Notes | AC and note give mutually exclusive score-total instructions (mean of 5 vs null-excluded dimension 5); note diverges from SRD EDMV3-27's "exactly five". Fix: scorer records `dimensions_scored`; CI comparison refuses to compare runs with different dimensions_scored; SRD change request against EDMV3-27's normalization AC.

T1-24 | P2 | medium | AC Quality / Wave integrity | T11 AC4 | Positive branch requires schema_version >= 2, which wave A cannot produce. Fix: state that the wave-A smoke case constructs a synthetic schema_version:2 fixture, or split into wave-A warn case + wave-B refusal case owned by T18.

T1-25 | P2 | medium | AC Quality | T61 AC3, T63 AC6/AC7, T64 AC12 | Wave-A tickets carrying ACs only evaluable at later waves. Fix: adopt one convention pack-wide -- wave-N ACs verifiable at wave-N close; later-wave clauses move to that wave's closeout (T64 AC9 already models this).

T1-26 | P2 | medium | AC Quality | T07 AC5 | Expected count not stated ("the count inside the two helpers plus the waiver"). Fix: absolute number or location assertion.

T1-27 | P2 | low | AC Quality | T24 AC10, T25 AC4, T27 AC7, T50 AC8, T60 AC7 | Borrowed/cross-check ACs unlabeled. Fix: label uniformly `(cross-check, owned by T##)`; move T27 AC7 (owner is wave-C T48) to T48 alone.

### Diagrams

T1-28 | P2 | high | Diagrams | README Mermaid waveC class line | T53 declared and edged but never colored (17 IDs for 18 wave-C tickets). Fix: insert T53.

T1-29 | P2 | medium | Diagrams | README Mermaid | T04, T49, T52 are orphan nodes with zero edges (factually correct). Fix: add a one-line note that they are intentionally isolated.

T1-30 | NOTED | high | Diagrams | README Mermaid | Syntax valid, EDMV3-53 rule obeyed (zero literal `;` in labels), all edges declared. Cosmetic: `large` classDef replaces wave color for T33/T37/T38; a combined waveBLarge classDef is the clean fix.

### Consistency

T1-31 | P2 | high | Consistency | README T09 row vs epics/02 | SRD Refs differ (epic file adds EDMV3-90). Only ID-level divergence found in 67 tickets. Fix: reconcile per T1-03.

T1-32 | P2 | medium | Consistency | README Same-MR groupings rows 1 and 4 | Table lists a three-way vocabulary-sweep group no ticket declares; tickets declare a single four-way set. Fix: merge rows.

T1-33 | P2 | low | Consistency | T56 AC1/AC4 vs docs/audit-patterns/ | SOURCES.md is neither covered nor explicitly exempted by the four-heading contract test. Fix: add SOURCES.md to AC4's explicit exemption list.

T1-34 | NOTED | high | Consistency | All 67 tickets | ID format, cross-table agreement clean (sole exception T1-31).

T1-35 | NOTED | high | Consistency | Epic files vs README | Ranges, counts, sizing arithmetic all exact.

### Version Alignment

T1-36 | NOTED (PASS) | high | Version alignment | README line 3 | `Generated From: srd.md v1.1.0` matches srd.md and .edm-state.json.

T1-37 | NOTED | high | Version alignment | Wave labels | 2.1.0/3.0.0/3.1.0 consistent across README, srd.md Sec 11.1, architecture.md, T64/T65/T66 ACs; 300-line dispatcher cap consistent.

T1-38 | P2 | medium | Version alignment | architecture.md A3/A8 vs srd.md v1.1.0 | architecture.md Build Sequence stale in three places: A3 three-source class check (srd requires four), A3 ritual deletion in wave A (see T1-01), A8 `gated_phase_for_gate` (srd replaced with `required_gates_for_mode()`). Pack follows srd.md correctly. Fix: reconcile architecture.md A3/A8.

## Coverage Tally

Forward: all 120 requirements accounted for; 115 in-scope covered, 5 Won't-Have as boundaries, zero orphans. Reverse: all 67 tickets carry valid refs. Spot-check 20 rows: 17 exact, 3 fail (T1-02, T1-03, EDMV3-87 -> T61). One SRD Must AC uncovered (T1-01).

## DAG Verdict

ACYCLIC -- independent extraction (118 edges), topological sort, exact bidirectional Mermaid match, wave-monotone. Caveats: 4 undeclared edges in fact (T33->T38, T36->T33, T03/T04->T09, T26/T33/T63->T43); 4 Ships-with pairs double as Depends On edges; narrative statistics wrong (T1-18, T1-19).

## Ambiguity Assessments (8 declared + 2 undeclared)

1. EDMV3-26 dep on EDMV3-47 (wave B) vs EDMV3-28 baseline-before-wave-B: GENUINE contradiction, P1. Resolution: EDMV3-26 Dependencies -> EDMV3-25 only; add re-verification AC (EDMV3-52 re-verifies against final PROTOCOL, material change invalidates baseline); add soft edge to Sec 11.2.
2. EDMV3-120 Ships-with EDMV3-71 cross-wave: GENUINE, unsatisfiable, P2. Resolution: delete Ships-with; `Shared shape:` note naming record and owners.
3. EDMV3-96 dependency set spans all waves: GENUINE and under-reported -- EDMV3-91 has the identical problem un-flagged. P2 (P1 in ticket consequence T1-21). Resolution: give both a Wave split block like EDMV3-11/-17/-22/-113.
4. EDMV3-13 AC5 wave-C schema_version value: NOT an ambiguity -- execution-time decision with stated rule and owner (T66 AC2). Reclassify.
5. EDMV3-03 AC4/AC5 two-branch spec: NOT an ambiguity -- sanctioned check-then-decide spike. Reclassify.
6. EDMV3-72 either/or: NOT an ambiguity -- intentional either/or with recording obligation. Reclassify.
7. EDMV3-84 conditional: NOT an ambiguity -- same class. Reclassify.
8. EDMV3-116 negative branch open-ended: PARTIALLY -- appropriate design contingency; optionally name the default candidate path.
9. (undeclared) EDMV3-07 AC11 same-MR vs wave-C placement: YES -- see T1-01. P1.
10. (undeclared) EDMV3-41 missing dep on EDMV3-46 (Skill grant); EDMV3-45 missing dep on EDMV3-41: YES. P1. Resolution: add both edges; propagate to T33/T38 and T36/T33.

Recommend splitting the README list into "SRD change requests" (1, 2, 3, 9, 10) and "decisions deferred to execution, with named owners" (4, 5, 6, 7, 8).

## Overall Verdict

Materially above the bar for structural integrity, materially short on cross-wave AC hygiene. Five P1s must close before Phase 6: EDMV3-07 AC11 silent override; T33->T38 undeclared grant edge; T36<->T33 latent circular constraint; T61 AC3/AC5 unsatisfiable at wave-A close; EDMV3-26's wave-A-depends-on-wave-B eval-baseline edge. Below that: wrong critical-path narrative numbers, one uncolored node, four Ships-with/Depends-On double declarations, nine AC-band overages. The wave-seam class is systematic; do not start Phase 6 until the five P1s and the double-declaration are resolved.
