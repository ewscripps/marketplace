# EDMV3 SRD Audit -- Round 1 Synthesis

**Audited**: srd.md v1.0.0 (2413 lines, 111 requirements), architecture.md (828 lines)
**Auditors**: 3 parallel `edm-srd-auditor` agents -- A (requirement quality / decision fidelity), B (factual accuracy / diagrams, 96 anchors verified), C (gaps / feasibility / constraints)
**Raw reports**: `audit/auditor-A.md`, `audit/auditor-B.md`, `audit/auditor-C.md`
**Date**: 2026-07-25

## Verdict

**FAIL -- remediate before Gate 2 / Phase 4.** Unanimous across all three auditors. Also unanimous: the SRD is structurally strong (exact priority arithmetic, complete traceability, 85/96 anchors exact, zero Mermaid semicolon violations across all 13 diagrams in both documents).

Per D13, ALL findings (P0/P1/P2) are remediated this round -- no deferrals. NOTED items require no action.

## Counts

| Auditor | P0 | P1 | P2 | NOTED |
|---|---|---|---|---|
| A | 8 | 19 | 26 | 8 |
| B | 2 | 20 | 27 | 11 |
| C | 2 | 17 | 30 | 6 |

Heavy overlap on the majors; deduped below.

## Deduplicated major findings (cross-auditor)

| # | Finding | Sources |
|---|---|---|
| M1 | Wave A hard-depends on Wave B (EDMV3-17/18/22 vs E4); delivery plan unbuildable as ordered | A-01, B-01, C-02 |
| M2 | PARTIAL dead-end: unverifiable AC makes initiative permanently unarchivable under D13 | C-01 |
| M3 | Ledger `deferred` status survives; blocking predicate silently excludes it (D13 bypass) | A-02, B-18 |
| M4 | Computed convergence cannot distinguish partial (--lenses) rounds; 3-lens smoke round can unlock archive | A-03, A-49 |
| M5 | Step 0 preflight is prose (T3) marketed as deterministic; gate-check is a no-op for 3 of 8 skills and mode-blind | A-04, A-09, B-16, C-05 |
| M6 | Vocabulary sweep scope misses hooks.json, bin/tests, qc-audit.md pattern doc; more than 2 smoke assertions go red | A-05, B-06, B-07, C-08, C-09, C-10 |
| M7 | Six Must-Haves contain unresolved either/or ACs | A-06 |
| M8 | schema_version: no backfill (every existing initiative permanently exempt), no value set, wave-A/wave-B gap class stranded | A-07, A-08, A-23, C-07, C-22, C-34 |
| M9 | Five skills ordered to present AskUserQuestion gates without the tool grant; verify-runtime has no frontmatter contract | C-04 |
| M10 | Mode/lifecycle gate matrix undefined: fast-track never approves gate 1 and can never archive; no-audit modes cannot converge | A-10, B-17, B-44, C-06 |
| M11 | Headless eval cannot complete a run (gates unanswerable under claude -p); CLI/credentials unpinned; scorer scale/threshold undefined and contradictory across docs | A-16, A-17, B-10, B-11, C-13, C-18, C-32 |
| M12 | Dispatcher line cap (220 vs ~200) inconsistent and likely unmeetable given retained content | A-26, B-19, C-14 |
| M13 | Agent/skill/hook counts wrong (30 not 26; 13 not 12; 7 not 6) incl. inside a testable AC | A-14, A-29, B-02, B-23, B-24, C-11 |
| M14 | --force zero-results grep vs required negative tests: mutually unsatisfiable Must ACs | A-12, B-08 |
| M15 | SRD-vs-architecture divergence cluster: archive prototype/terminal-phase semantics, phase-6 PARTIAL precondition, update-patterns heading, schema_version settability, gate header string, canonical section name, eval dimension 5 + threshold, 3 file paths, exit codes | B-05, B-12, B-15, B-20, B-38, B-39, B-40, C-21, C-22, C-25, C-26, C-42 |
| M16 | Diagram logic errors: permission-layer inversion (5.2/5.3), forbidden render actor (5.3), orphan/terminal nodes, D-7 skip-branch PARTIAL bypass, D-9 serial chain | A-20, A-31, A-48, B-03, B-04, B-32..B-37, B-48, B-49 |
| M17 | Priority defects: 6 Musts depend on Shoulds; RK-3's only mitigations are Should; 4 over-assigned Musts; -77/-78 inverted pair | A-18, A-19, A-45 |
| M18 | EDM-REVIEW.md has 78 non-ASCII lines; lint exit-0 AC unsatisfiable; commits staging EDMV3 artifacts already fail the hook | C-03 |
| M19 | Permission ask rule trivially evadable (compound/absolute-path invocations); enforcement tag records rule presence, not consent | B-22, C-15 |
| M20 | CLAUDE.md by-name reference resolvability from installed cache never verified (11 new runtime dependencies on it) | C-16 |

## Arbitration decisions (orchestrator + user)

Where auditors offered options or documents disagreed, the remediation applies these rulings:

1. **M1**: split the archive check across waves. Wave A lands gates + mode-derived terminal-phase + phase-6 completed_at + `code_audit_converged` boolean; the PARTIAL-closure and `audit-converged` sub-checks are wired in Wave B. EDMV3-17/18/22 ACs split accordingly; all cross-wave edges added to Sec 11.2; Wave A exit criterion restated.
2. **M2 (user decision D15)**: no BLOCKED verdict. An unverifiable AC is a spec defect -- reworked into something verifiable now, or its unverifiable clause moved to a follow-on initiative as a recorded scope boundary via gate change control. verify-runtime stays PASS/FAIL-only.
3. **M3**: status enum is exactly `open | fixed | noted`, stated once in EDMV3-30 and enforced at read time; legacy `deferred` entries re-open on first read; synthesizer edit sites :60-61, :116, :137, :140, :157 named.
4. **M4**: rounds record their lens set; `audit-converged` requires the latest round to be full and exits non-zero naming the partial lens list otherwise.
5. **M5**: gate enforcement moves into the kernel -- `phase-start` refuses when the phase's prerequisite gate (mode-derived) is unapproved. `cmd_gate_check` gains `plan`/`code-audit`/`verify-runtime` tokens, mode/skipped-phase awareness via the same derivation as archive, and a hard-error default branch. Step 0 stays as defense-in-depth and is no longer described as deterministic anywhere.
6. **M6**: sweep scope = `skills/`, `agents/`, `docs/` (incl. `qc-audit.md`), `hooks/hooks.json`, `monitors/monitors.json`, `CLAUDE.md`, `README.md`, `bin/` with a documented allowlist for the checker's pattern files and negative tests. hook token becomes `runtime-check:`. All red-going smoke assertions (wave4b:36,38,40 + Step-7 orchestrator assertions + wave5:175) enumerated and re-baselined in the same MR as their text changes.
7. **M7 either/ors resolved**: -01 dedicated code path; -20 upgraded to AskUserQuestion and retitled the remediation gate (defers to -49); -25 fixture excluded (with C-31 rewording re the eval run dir); -26 driver stops each phase skill before gate presentation with pre-seeded `approve-gate`; -39 local severity tables deleted in favor of by-name references; -46 mode sub-flows move to phase skills/CLAUDE.md; -23 root `.gitlab-ci.yml` with `rules:changes` scoping + always-on default-branch run; -91 shellcheck pinned in CI with EDMV3-106-style fallback wording.
8. **M8**: `schema_version` is an integer: 1 (wave A), 2 (wave B), 3 (wave C, only if shapes change). New Must: `edm-state migrate-schema <PREFIX>` backfills after operator confirmation; `SCHEMA_VERSION_MISSING` informational anomaly for non-archived initiatives. Per-check minimum versions stated; present-but-lower versions degrade warn-and-proceed for newer checks only. Not settable via `cmd_set`; advanced only by `migrate-schema` (architecture.md aligned).
9. **M9**: new requirement grants `AskUserQuestion` to code-audit, plan, audit-srd, audit-tickets, verify-runtime; full frontmatter contract for verify-runtime; `edm-check-grants` extended to skill `allowed-tools` (agent bodies + skill launch templates + hook prompts + skill bodies).
10. **M10**: new helpers `terminal_phase_for_mode()` and `required_gates_for_mode()` (both mode + lifecycle_mode aware) are the single derivation used by phase-start, gate-check, phase-complete, and archive. Fast-track/fix-pack record `skip-phase 1` plus a named gate approval. Modes that never run a code audit are exempt from convergence with a recorded reason. Smoke matrix gains fast-track and flat-layout cases. `edm-init`/`set-mode` seed `skipped_phases` from the mode's phase graph (single exemption source); mini-srd characterization corrected.
11. **M11**: eval driver invokes each phase skill with an explicit stop-before-gate contract and pre-seeded approvals; `claude` CLI + `ANTHROPIC_API_KEY` pinned as eval-job dependencies; job skips (not fails) when the secret is absent; partial runs score as failure with a distinct exit. Scorer: exactly five dimensions, each normalized 0-100 higher-is-better, unweighted mean, dimension set versioned in scores.json; scorer emits scores only; CI compares against baseline with tolerance = max-min of the three baseline runs, same scorer version only. Validate stage is two-tier: deterministic jq/frontmatter check always blocks; `claude plugin validate` conditional on CLI availability.
12. **M12**: dispatcher cap re-derived at 300 lines with the derivation shown (retained-content list + EDMV3-59's additions); single number in all three documents; smoke test asserts 300.
13. **M13**: 30 agents / 13 skills / 7 hook families corrected everywhere, including EDMV3-64/-81 and decisions.md D1; a smoke assertion ties the documented count to `ls agents/*.md | wc -l`.
14. **M14**: override-flag greps exclude `bin/tests/` and the vocabulary pattern files (EDMV3-12 AC5's carve-out wording applied uniformly).
15. **M15**: srd.md and architecture.md reconciled in one editing pass. Rulings: terminal phase is mode-derived (D-8 shape wins; prototype waives only convergence); phase-complete 6 requires zero open PARTIALs (architecture wins; EDMV3-16 gains the AC); update-patterns default heading is `## Anti-Patterns` with skip-and-message when absent (srd.md wins); gate header is "Convergence"; canonical section name is `## Mermaid diagram conventions (canonical)`; fixture path is `plugins/edm/evals/fixtures/tiny-svc/` plus `expected.json` (architecture wins); vocabulary files are `bin/vocabulary-prohibited.txt` + `bin/vocabulary-allowlist.txt`; exit-code contract binds new `bin/edm-check-*` scripts (0/1/2), `audit-converged` uses 0/1/3 (3 = no ledger), `cmd_validate` keeps 3; Gate 3.5 / code-audit gate metadata stored as sibling scalar keys (`*_approved_at`, `*_approver`, `*_enforcement`), `read_bool` untouched.
16. **M16**: all diagram fixes applied as specified by A-20/B-03/B-04/B-05/B-32..B-37/B-48/B-49 (permission layer upstream of the kernel; synthesizer writes JSONL, skill calls render-ledger; TOCTOU re-check drawn; orphan nodes connected; D-7 skip branch keeps the PARTIAL gate; D-9 parallelized).
17. **M17**: EDMV3-09, -10, -24 promoted to Must; -71/-73/-66 Must-dependents restated conditionally; -32, -80 demoted to Should; -68 Should; -78 promoted to Must (curation loop closes in one ticket with -77).
18. **M18**: EDM-REVIEW.md is ASCII-normalized as part of this remediation (new AC under EDMV3-95); stated policy: imported documents are ASCII-normalized on import.
19. **M19**: prefix-match limitation documented plainly; recommended rule set includes the compound/absolute-path shapes the plugin itself emits; wave-A manual QA case exercises `cd ... && edm-state approve-gate`; Sec 5.1's "cannot be bypassed" claim scoped to prompt drift/compaction/persuasion.
20. **M20**: new Must AC (wave B, before EDMV3-54 lands): verify from an installed plugin cache that agents resolve `CLAUDE.md Sec."..."` references; if they cannot, the canonical sections are relocated/duplicated deterministically with a sync smoke assertion.

All remaining P2s (counts, anchor ranges, wording, licensing note A-47, harness helpers C-40, reuse notes C-37..C-41/B-43, branch-check scoping C-36, current_step migration C-48, downgrade story C-17, evals size budget C-30, D13 template renames A-40/C-47, entity-syntax wording A-43, unfalsifiable-AC rewrites A-34..A-44/C-33, explorer cap N=4 A-37, recall threshold 80%/any-P0-P1 A-35, tiering target as measured outcome A-36) are remediated per each finding's stated fix.

## Remediation output

- srd.md 1.0.0 -> 1.1.0 (all findings applied, changelog entry in Document Info)
- architecture.md revised in the same pass (divergence cluster eliminated)
- planning.md: dispatcher figure aligned; complexity estimate corrected (3 subcommands, 3 bin scripts, 13 grants, 8 phase-skill edits)
- decisions.md: D15 recorded; D1 count corrected
- EDM-REVIEW.md: ASCII-normalized
