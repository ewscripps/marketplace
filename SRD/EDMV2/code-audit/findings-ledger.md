# Code Audit Findings Ledger: EDMV2

EDM AI-Development plugin v2.0.0 (`plugins/edm-ai-development/`). Cross-round findings ledger.
Severity scale: canonical **P0 / P1 / P2 / NOTED** (`CLAUDE.md` Sec. "Severity vocabulary").

- **Round 1** = `code-audit/2026-06-08/` (full, 11 lenses). 24 findings G1-G24; all remediated in
  `b7e9125` + follow-ons `0ae0f17` / `2f7b7fc` / `df0289c`. Round 1 used a legacy P1/P2/P3 scale; the
  round-1 G-rows below are restated on the canonical scale for cross-round comparability
  (legacy P1 -> P0, legacy P2 -> P1, legacy P3 -> P2, per CLAUDE.md backward-compat mapping).
- **Round 2** = `code-audit/2026-06-09/` (full, 11 lenses). Convergence pass. CA-NNN IDs assigned to
  round-2 open findings. Cross-refs note which round-1 G-finding a round-2 finding re-opens.

Status values: `open`, `fixed`, `partial`. A round-1 G-row marked `fixed` was confirmed held by the
round-2 lenses; `partial` means a lens found the fix incomplete or regressed (the residual is tracked
under a CA-NNN row).

## Round-2 findings (CA-NNN)

| ID     | Severity | Lens(es)               | Component                                                                                    | Status | Round in | Round resolved | Cross-ref |
|--------|----------|------------------------|----------------------------------------------------------------------------------------------|--------|----------|----------------|-----------|
| CA-001 | P1       | L3+L4+L7+L9+L10 (+L1)  | `bin/edm-state:1114-1120` (`cmd_migrate_path`)                                               | open   | 2        |                | re-opens G12 (+G2/G3/G9 class) |
| CA-002 | P1       | L8                     | `bin/edm-state` migrate-path PREFIX; `bin/edm-init` `--product`/`--description`              | open   | 2        |                | re-opens G7 / extends G12 |
| CA-003 | P1       | L9 (+L8 noted)         | `plugin.json` vs `.claude-plugin/plugin.json`                                                | open   | 2        |                | re-opens G5(a) / violates T22 AC1-2 |
| CA-004 | P1       | L4                     | `bin/tests/wave5-smoke.sh` (absent regression coverage)                                      | open   | 2        |                | residual of G19; net for G7/G12 |
| CA-005 | P2       | L1                     | `bin/edm-state:985-986` (`cmd_metrics_report` Total line)                                    | open   | 2        |                | residual of G8 |
| CA-006 | P2       | L2+L3 (+L7)            | `bin/edm-state:347-351` (`with_state_lock` flock branch)                                     | open   | 2        |                | residual of G13 |
| CA-007 | P2       | L2                     | `bin/edm-state:293-306` (`write_state`/`_write_state_body`)                                  | open   | 2        |                | new (G14-class, from G2 extraction) |
| CA-008 | P2       | L3                     | `bin/edm-state:491-522` (`cmd_init`)                                                         | open   | 2        |                | residual of G9 (init path) |
| CA-009 | P2       | L5                     | `.gitignore` / `bin/edm-state:295,314,1120` (`.tmp.$$`)                                      | open   | 2        |                | new (from G9 atomic-write fix) |
| CA-010 | P2       | L11 (+L9)              | `plugin.json` userConfig (`mode`/`compliance_enabled`/`implementation_mode`)                 | open   | 2        |                | re-opens G5(b) / violates srd.md:1302-1303 |
| CA-011 | P2       | L7+L10                 | `bin/edm-state:534-545`, `:1303-1316` (`cmd_list`/`cmd_session_start`)                       | open   | 2        |                | residual of G1/G18 enumerator |
| CA-012 | P2       | L10                    | `bin/edm-state:780/1050`, `:794/1062` (coverage-table renderer)                             | open   | 2        |                | re-opens G18(c) |
| CA-013 | P2       | L10                    | `bin/edm-state:1001-1005,1022,1690-1692,691,701` (gate<->phase topology)                     | open   | 2        |                | re-opens G18(b) |
| CA-014 | P2       | L10 (+L4)              | `bin/tests/*` (`_harness.sh` absent; preamble copy-pasted 4x; wave4b divergent)             | open   | 2        |                | re-opens G18(d) |
| CA-015 | P2       | L10                    | `bin/edm-state:866-868,1105-1106,1755-1763` (`git_aware_mv`/`present_or_absent`)             | open   | 2        |                | residual of G24 |
| CA-016 | P2       | L9                     | `skills/orchestrator/SKILL.md` (Step 1)                                                      | open   | 2        |                | pre-existing; T35 AC3/AC4 (not a regression) |
| CA-017 | P2       | L6                     | `README.md:104-106` (code-audit tree)                                                        | open   | 2        |                | residual of G16 item 2 |
| CA-018 | P2       | L6                     | `bin/edm-state:1966` (`--help` sed slice)                                                     | open   | 2        |                | new (from rewrite line-shift) |
| CA-019 | P2       | L7                     | `skills/audit-srd/SKILL.md:65-69,89-96`                                                       | open   | 2        |                | residual of G17 (sibling skill) |
| CA-020 | P2       | L6                     | `CLAUDE.md:271` (test-coverage-auditor disallowedTools)                                       | open   | 2        |                | residual of G16 item 8 |
| CA-021 | P2       | L6                     | `skills/code-audit/SKILL.md:186` (P1/P2/P3 line)                                              | open   | 2        |                | new (self-contradicts canonical scale) |
| CA-022 | P2       | L6                     | `agents/edm-test-contract.md:4` (GraphQL omission)                                           | open   | 2        |                | residual of G22 L6-09 |
| CA-023 | P2       | L6                     | `README.md:85` (gate-hook command list)                                                      | open   | 2        |                | new doc-accuracy |
| CA-024 | P2       | L6                     | `README.md:108` (mode-fields comment)                                                        | open   | 2        |                | residual of G22 L6-11 |
| CA-025 | P2       | L6                     | `bin/edm-init:3,26` (`--mode` value list)                                                     | open   | 2        |                | new doc-accuracy |
| CA-026 | P2       | L7                     | `agents/edm-audit-logic.md:55` ("+ NOTED" omission)                                          | open   | 2        |                | residual of G22 L7-04 |

## Round-1 findings (G1-G24) -- round-2 status

| ID  | Sev (canon) | Lens(es) (R1) | Component                        | Status  | Round in | Round resolved | Round-2 note |
|-----|-------------|---------------|----------------------------------|---------|----------|----------------|--------------|
| G1  | P1          | L1+L3+L10     | `bin/edm-state` enumeration      | partial | 1        | 2 (4 of 6)     | helper landed; `cmd_list`/`cmd_session_start` holdouts -> CA-011 |
| G2  | P0          | L3+L10+L8     | `bin/edm-state` write path       | fixed   | 1        | 2              | `rmw_state` locks all mutators (L3) except migrate-path -> CA-001 |
| G3  | P0          | L3+L10        | `cmd_checkpoint`                 | fixed   | 1        | 2              | routes through `rmw_state` (L3) |
| G4  | P0          | L1            | `cmd_get_coverage`               | fixed   | 1        | 2              | trailing `.[]//.` removed; exits 0 (L1) |
| G5  | P1          | L9+L11        | `plugin.json` manifests          | partial | 1        | 2              | keys present (fixed); dedup -> CA-003; dead config -> CA-010 |
| G6  | P0          | L8            | `bin/edm-lint-artifacts`         | fixed   | 1        | 2              | `mapfile` removed; zero bash-4 constructs (L8) |
| G7  | P0          | L8            | `bin/edm-state` resolver         | partial | 1        | 2              | `state_file_for` guarded; migrate-path PREFIX + edm-init -> CA-002; untested -> CA-004 |
| G8  | P1          | L1            | `cmd_metrics_report`             | partial | 1        | 2              | per-phase/`--all` fixed; Total line still `0x` -> CA-005 |
| G9  | P1          | L3            | `_write_state_body`              | partial | 1        | 2              | locked path atomic (fixed); `cmd_init` -> CA-008; `.tmp` -> CA-009 |
| G10 | P1          | L1+L3         | record-* / approve-gate          | fixed   | 1        | 2              | numeric guards present (L3) |
| G11 | P1          | L5            | `.gitignore` / `edm-init`        | fixed   | 1        | 2              | root `.gitignore` lists all 3 sidecars (L5); `.tmp` -> CA-009 |
| G12 | P1          | L3+L8         | `cmd_migrate_path`               | partial | 1        | 2              | input sanitize held; lock/`.bak`/rollback regressed -> CA-001 |
| G13 | P1          | L3            | `with_state_lock` (flock)        | partial | 1        | 2              | core fail-closed fixed; flock exit-99/no-message -> CA-006 |
| G14 | P1          | L2            | `read_num` dead code             | fixed   | 1        | 2              | `read_num` deleted (L2); new orphan `write_state` -> CA-007 |
| G15 | P1          | L8            | `cmd_update_patterns`            | fixed   | 1        | 2              | `-w` guard + return 0 (L8) |
| G16 | P1          | L6+L7         | docs batch                       | partial | 1        | 2              | most fixed; README code-audit tree -> CA-017; disallowedTools -> CA-020 |
| G17 | P1          | L7            | srd/ticket auditor NOTED         | partial | 1        | 2              | agents fixed; audit-srd SKILL 3-row -> CA-019 |
| G18 | P1          | L10           | DRY hardening                    | partial | 1        | 2              | (a) fixed; (b)->CA-013, (c)->CA-012, (d)->CA-014 |
| G19 | P1          | L4            | `bin/tests/*`                    | partial | 1        | 2              | wave5 added + de-tautologized; G7 net missing -> CA-004; metrics untested -> CA-005 net |
| G20 | P2          | L1            | `cmd_metrics_report` (`1Phase`)  | fixed   | 1        | 2              | label now `Phase 1` (L1) |
| G21 | P2          | L1            | `cmd_update_patterns` skip-list  | fixed   | 1        | 2              | exact whole-heading match (L1) |
| G22 | P2          | L6+L7         | docs nits                        | partial | 1        | 2              | several fixed; GraphQL->CA-022, mode-fields->CA-024, "+NOTED"->CA-026 |
| G23 | P2          | L11           | stale staging paths in tests     | fixed   | 1        | 2              | zero staging refs remain (L11) |
| G24 | P2          | L5+L8+L10     | low-value cleanups               | partial | 1        | 2              | sidecar/FD/pgrep fixed; git_aware_mv/present_or_absent -> CA-015 |

## Convergence

Round 2 is a **full** round (11 lenses), so it is eligible to satisfy the convergence gate.
Blocking set = open **P0 + P1**. Open P0: **0**. Open P1: **4** (CA-001, CA-002, CA-003, CA-004).
**Convergence NOT reached.** Recommended next step after remediation: a partial re-audit of
L3/L4/L7/L8/L9 (the lenses that surfaced the open P1s); a partial round cannot itself record
convergence -- a subsequent full round is required to close the gate.
