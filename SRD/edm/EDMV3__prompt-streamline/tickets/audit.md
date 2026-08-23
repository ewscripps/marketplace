# EDMV3 Ticket Pack Audit -- Round 1 Synthesis

**Audited**: tickets/ (README.md + epics/01..11, 67 tickets EDMV3-T01..T67) against srd.md v1.1.0
**Auditors**: 2 parallel `edm-ticket-auditor` agents -- 1 (coverage/dependencies/critical path/version alignment), 2 (AC quality/sizing/diagrams/consistency; 121 anchors verified, 117 exact)
**Raw reports**: `../audit/ticket-auditor-1.md`, `../audit/ticket-auditor-2.md`
**Date**: 2026-07-25

## Verdict

**NEEDS FIXES -- zero P0, 11 P1 (5 + 6), ~62 P2, 26 NOTED.** Both auditors: structurally the strongest pack they have audited (100% edge-faithful acyclic DAG, D13/D15 encoded at all four layers, 117/121 anchors exact, zero vague ACs). Blocking classes: (a) cross-wave AC hygiene -- wave-A tickets carrying ACs unsatisfiable at wave-A close; (b) ACs written against a described system rather than the actual one (HANDOFF em dashes, lint path mode, audit_rounds type change); (c) five genuine SRD defects surfaced through the pack.

Per D13, ALL findings (P1+P2) are remediated this round. NOTED items require no action.

## SRD change requests (srd.md v1.1.0 -> v1.2.0)

The audit confirmed 5 of the pack's 8 declared ambiguities are real SRD defects (plus 2 undeclared):

| CR | SRD target | Change |
|---|---|---|
| CR1 | EDMV3-07 AC11 | Reword: the implement-skill ritual "is deleted by EDMV3-81 once this check exists; the ordering edge is recorded in Sec 11.2" (wave-C deletion stands; same-MR wording was the defect) |
| CR2 | EDMV3-26 | Dependencies -> EDMV3-25 only; new AC: stop-before-gate contract re-verified against the final PROTOCOL by EDMV3-52, material change invalidates the baseline; soft edge added to Sec 11.2 |
| CR3 | EDMV3-120 + EDMV3-71 | Cross-wave `Ships-with` deleted; replaced by a `Shared shape:` note naming the audit-round record and its two owners (designed in wave B, extended additively in wave C) |
| CR4 | EDMV3-91 + EDMV3-96 | Both gain an explicit Wave split block (same shape as EDMV3-11/-17/-22/-113): wave A lands the mechanism, each later wave's subcommand carries its own help/usage AC |
| CR5 | EDMV3-41 + EDMV3-45 | EDMV3-41 Dependencies += EDMV3-46 (the Skill grant); EDMV3-45 Dependencies += EDMV3-41 |
| CR6 | EDMV3-27 | Scorer emits `dimensions_scored` in scores.json; comparisons refuse runs with different dimensions_scored; wave-A baseline scores 4 dimensions and says so |
| CR7 | architecture.md Build Sequence A3, A8 | A3: class check reads four sources (not three) and the ritual deletion moves to wave C per CR1; A8: `required_gates_for_mode()` (not the mode-blind `gated_phase_for_gate`) |

Ambiguities 4-8 (schema_version wave-C value, scoped-grant spike, EDMV3-72 either/or, monitor-lifecycle conditional, EDMV3-116 negative branch) are NOT defects -- they are sanctioned execution-time decisions with named owners. The README ambiguity list is split accordingly.

## Arbitration rulings (pack remediation)

1. **Dependency edges added**: T33 += T38, T13; T36 += T33 (and T33's AC11 Step 0 clause deleted -- T36 owns Step 0 for all eight skills); T03 += T09; T04 += T09; T26 += T43; T33 += T43; T02 += T22; T24 += T23; T60 += T61.
2. **Duplicated Ships-with/Depends-On pairs**: the Depends On edge is removed where it duplicates Ships-with (T03->T15, T24->T25, T29->T30, T37->T38); Mermaid and the longest-chain narrative re-derived afterward.
3. **T27/T51**: Ships-with replaced by `Shared record shape:` notes per CR3; removed from the README same-MR table.
4. **T63 AC6** (wave-B artifacts) moves to T65, which gains `EDMV3-95 (wave-B artifacts)` in SRD Refs and an explicit AC. Pack-wide convention adopted: a wave-N ticket's ACs are all verifiable at wave-N close; later-wave clauses move to that wave's closeout ticket as named rows (T64 AC9 is the model).
5. **T61 AC3/AC5** scoped to subcommands existing at the wave-A boundary; the four-subcommand help assertion moves to T66 AC3 (per CR4's wave split).
6. **HANDOFF em dashes** (auditor 2's top find): T17 gains the normalization AC for `bin/edm-state:1754,:1763,:1772`.
7. **Lint path mode**: T20 gains `edm-lint-artifacts --path <dir|file>` (read-only, no state resolution); T43/T44 verifications invoke it.
8. **audit_rounds migration**: T27 gains the C-4 coercion AC (integer read as `{count: N, rounds: []}`, asserted against a fixture with `audit_rounds: {code: 2}`); T14 AC7 names the widening as the single sanctioned exception.
9. **Code-audit fixture**: a committed synthetic pass directory `bin/tests/fixtures/code-audit/` (created by T24, with `lens-L1.jsonl` covering every severity plus a NOTED line) is the verification subject for T24/T25/T42 ACs; T02 AC8 re-scoped to a single-lens (L1) live spot run against the eval fixture -- verifies the grant class without an 11-lens opus round.
10. **--force literal ruling**: no literal `--force` anywhere in `bin/edm-state` (unknown-argument error path only); T09 AC13 expects zero results; T11/T12 negative tests unchanged (they live in bin/tests/, carved out).
11. **Anomaly line format**: post-T05 four-field class-prefixed format propagated to T06 AC5, T10 AC6, T17 AC3, T18 AC7, T51 AC4/AC5, T62 AC3/AC7.
12. **Broken verification commands fixed as specified**: T62 AC1 (`skipped_at`), T54 AC8 (`patterns_last_updated`/`patterns_updates`), T54 AC1 (guard-flag awk), T23 AC3 (jq rewrite, adapt clause deleted), T20 AC3 (auto-discovery branch with an exit-1 scratch suite), T02 AC7 (`grep -lc | wc -l` = 12), T46 AC12 + T50 AC2/AC3 + T53 AC1/AC4 + T55 AC8 + T58 AC6 + T34 AC7 (`grep -rl | wc -l` idiom), T03 AC6 ("exactly four"), T49 AC2 ("Four sources", verify all four), T22 AC4 (named network-disable mechanism), T07 AC5 (absolute count/location assertion), T47 AC6 (positive assertions on surviving text), T44 AC1 (both corpus floors).
13. **Sizing**: T09 M->L, T61 M->L, T67 M->L, T02 S->M (justifications written); T22 stays M with a note; README Ships-with table records T37+T38 as ONE L-class delivery unit (16-21 pt) and T38 gains a two-reviewable-commits AC; AC-band overages recorded in the README sizing section.
14. **Critical-path narrative**: longest chain corrected to nine (T07->T08->T09->T11->T50->T51->T48->T53->T66); T09 transitive dependents corrected to 17 (6 direct).
15. **Diagram**: T53 added to the waveC class line; combined `waveBLarge` classDef so L tickets keep wave identity; one-line note that T04/T49/T52 are intentionally isolated. Diagram re-derived after ruling 2's edge removals.
16. **Coverage bookkeeping**: Won't-Have IDs stripped from SRD Refs (T04, T14, T30, T38, T09-epic-file), negative-enforcement stays in ACs and the coverage-map disposition column; EDMV3-106 added to T04's SRD Refs; Epics Summary gains the ownership-count footnote; SOURCES.md added to T56 AC4's explicit exemptions; README same-MR rows 1 and 4 merged; T09 README/epic SRD Refs reconciled.
17. **EDMV3-69 before/after ACs** added to T24, T36, T42, T53, T58 (and remainder audited); T49 AC7's grep restated accordingly.
18. **Cross-check ACs** labelled uniformly `(cross-check, owned by T##)`; T27 AC7 moves to T48.
19. **Editorial P2s** (T1-05/-16/-24/-26/-32/-33, T2-05/-38/-39/-40/-50/-51/-52/-53/-54/-55/-56/-57, T21 AC5 single-source suite list, T29 counts ~45/14, T2-61 wave-numbering note): each applied per the auditor's stated fix.
20. **Versioning**: srd.md -> v1.2.0 (CR1-CR6 + changelog); architecture.md updated per CR7; tickets/README.md `Generated From: srd.md v1.2.0`.

## Remediation output

- srd.md 1.1.0 -> 1.2.0 (7 change requests)
- architecture.md Build Sequence reconciled (CR7)
- tickets/ pack: all 11 P1 + all P2 findings applied; DAG re-derived; README statistics corrected
- This synthesis + raw reports persisted under `../audit/`
