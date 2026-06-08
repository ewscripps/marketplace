# EDMV2 SRD Audit Report

**SRD version audited:** 1.0.0
**Remediated SRD version:** 1.0.1
**Audit date:** 2026-06-08
**Auditors:** edm-srd-auditor x3 (parallel, section-split)
**Methodology:** 7-category audit across Feature Gaps, Factual Mistakes, Diagram Errors, Competing Requirements, Reuse Opportunities, Specification Quality, Additional Concerns

---

## Summary

| Severity | Found | Remediated | Deferred |
|----------|-------|------------|---------|
| P0 | 6 | 6 | 0 |
| P1 | 24 | 24 | 0 |
| P2 | 21 | 0 | 21 |

All P0 and P1 findings remediated in srd.md v1.0.1. Two new requirements added: EDMV2-104 and EDMV2-105. P2 findings are logged for awareness; none block ticket creation or Gate 2 approval.

---

## P0 Findings (all remediated)

| ID | Title | Category | Fix Applied |
|----|-------|----------|------------|
| F-A-01 | Agent count 29 -> 30 throughout SRD | Factual Mistakes | Changed all "29 agents" / "8+11+10=29" to "30 agents" / "8+11+1+10=30" in Document Info, §3.1, §5.0, §5.1, §5.2.4 |
| F-A-02 | Ticket count contradicts Gate-1-approved baseline | Competing Requirements | Document Info now reads "~95-115 tickets (revised up from Gate-1 baseline of ~75-90 by WS-L/M/N additions)"; Revision History updated |
| F-B-01 | Active-initiative predicate references non-existent top-level `completed_at` field | Factual Mistakes | Detection predicate changed everywhere to "directory exists AND not under `.archived/` AND `current_phase` 1-6"; §6 note added explaining completion is inferred from directory location |
| F-B-02 | §6.1 schema table omits five fields required by §5.4 and §8 | Competing Requirements | Added `last_cmd`, `last_decision`, `lifecycle_mode`, `supersedes`, `forked_from` to §6.1 with types and defaults |
| F-B-03 | `mode` vs `lifecycle_mode` -- one field or two | Competing Requirements | Resolved as two orthogonal fields; `set-mode <PREFIX> <kind> <value>` subcommand signature; EDMV2-44 updated; §5.4, §6.1, §8.1 aligned |
| F-C-01 | Archive gating breaks backward compat for entire existing corpus | Competing Requirements | Three-case rule: absent field (v1 legacy) = warn-only; explicit false + v2 marker = refuse; true = proceed. EDMV2-15, §8.2, §10.2 updated |

---

## P1 Findings (all remediated)

| ID | Title | Category | Fix Applied |
|----|-------|----------|------------|
| F-A-03 | "Four modes" vs five profiles inconsistency in §1/§2 | Specification Quality | Reworded to "four adaptation profiles via `mode` field + orthogonal `compliance_enabled` flag"; Glossary updated |
| F-A-04 | EDMV2-03 cites wrong line numbers for metrics skill (44-46 off by one) | Factual Mistakes | Citation corrected to "skill lines 31, 33, 43-45, 64" |
| F-A-05 | EDMV2-03/04 contradictory on whether metrics are added or removed | Competing Requirements | EDMV2-03 now specifies default outcome: p95/bottleneck/guideline removed; `gate_review_seconds` implemented per EDMV2-04 or also removed if deferred |
| F-A-06 | EDMV2-13 omits `edm-test-coverage-auditor` from severity unification scope | Feature Gaps | Added to EDMV2-13 enumeration and verification clause |
| F-A-07 | EDMV2-21 misses Unicode `->` arrows at edm-state:380/390 | Factual Mistakes | Citation expanded to include lines 380 and 390; §11.2 G15 row updated |
| F-A-08 | §5.6 Risk 2 path-construction citation too narrow | Factual Mistakes | Expanded to ":704-708 path vars, :726 handoff path, :751-755 rendered checklist paths" |
| F-A-09 | EDMV2-32/33 QC shard threshold undefined | Specification Quality | Threshold defined: >20 tickets shards; max 12 per shard; epic-boundary alignment; `qc_shard_threshold` userConfig key added |
| F-A-10 | WS-D canonical paths use "e.g." -- architecture.md filename missing | Specification Quality | Canonical names made normative: `architecture.md`, `decisions.md`, `ROLLBACK.md`, `exec-report.md`; §5.2.6 and §6.3 updated |
| F-A-11 | §3.1 WS-A "all 29 agents" scopes tickets incorrectly | Factual Mistakes | Fixed to "all 30 agents" (root cause same as F-A-01) |
| F-B-04 | Archive "refuses or warns" is ambiguous | Specification Quality | Resolved by F-C-01 three-case rule; §8.2 archive row updated to match |
| F-B-05 | §8.5 userConfig keys collide with per-initiative state fields | Competing Requirements | `product_name` removed from userConfig; `mode`/`compliance_enabled` kept as defaults with explicit precedence note (state > userConfig > built-in) |
| F-B-06 | EDMV2-60 multi-pack unmodeled in §6 data model | Feature Gaps | `ticket_packs` array field added to §6.1; `tickets-{slug}/` convention documented in §6.3 |
| F-B-07 | EDMV2-61 product baseline has no artifact slot in §6.3 | Feature Gaps | `SRD/{PRODUCT}/BASELINE.md` path documented in §6.3 as opt-in product-level artifact |
| F-B-08 | EDMV2-46 compliance columns untestable | Specification Quality | Concrete column set defined: `Regulation` + `Control` columns in ticket README; `Regulatory Evidence` field in epic ACs; verification updated |
| F-B-09 | §8 omits `write-handoff`/`metrics-report` surfacing `product_name`/`initiative_description` | Feature Gaps | Both subcommand rows in §8.2 updated to reference EDMV2-91 product/description surfacing |
| F-B-10 | §9 omits WS-F lifecycle-mode and WS-G related-initiatives UX | Feature Gaps | Added §9.6 (lifecycle mode rendering) and §9.7 (Related Initiatives section) |
| F-B-11 | Methodology doc line citations unverifiable from this repo | Factual Mistakes | Note added to §4.5 and EDMV2-34 explaining citations reference external `scripps-mcp/` repo; requirements are self-contained |
| F-B-12 | §7 omits gate bypass scope limitation and block contract | Specification Quality | Scope limitation note added; block contract specified: non-zero exit + "[EDM GATE BLOCKED]" message |
| F-C-02 | §10.4 self-hosting sequencing contradicts §5.7 on G18/WS-J ordering | Competing Requirements | EDMV2-103 and §10.4 clarified: "first" applies to foundational schema/resolver; consumers (e.g., G18 archive gating) follow per §5.7 |
| F-C-03 | No requirement for marketplace.json version bump | Feature Gaps | EDMV2-104 added (Must): marketplace.json edm-ai-development version bumped to 2.0.0 in lockstep with plugin.json; §10.2 corrected |
| F-C-04 | EDMV2-96 SessionStart multi-initiative selection unspecified | Specification Quality | Selection semantics added: most-recently-updated initiative wins; others listed below; injection path must remain non-failing |
| F-C-05 | EDMV2-66 deterministic gate over-promises | Specification Quality | Rescoped to "three matched gated commands only"; explicit assumption on `command`-hook block behavior added |
| F-C-06 | EDMV2-92 `current_step` null vs absent contradiction | Competing Requirements | Lazy-creation model adopted (absent from init, created on first write, read with `// null` fallback); §6.1 default changed to "absent"; §5.4 annotated |
| F-C-07 | §10 missing rollback/failure-recovery story for self-hosting risk | Specification Quality | §10.5 added with recovery procedure; EDMV2-105 added (Must): state backup + offline test before edm-state mutations |

---

## P2 Findings (deferred -- no Gate 2 impact)

| ID | Title | Category |
|----|-------|----------|
| F-A-12 | Confirm no non-ASCII crept into SRD (pre-commit lint check) | Additional Concerns |
| F-A-13 | EDMV2-29 bundles SRD-drift and ticket-pack-drift into one requirement | Specification Quality |
| F-A-14 | EDMV2-29 ticket-pack drift detection duplicates existing Dimension 8 | Reuse Opportunities |
| F-A-15 | §2.2 missing explicit runtime-independence non-goal for corpus | Additional Concerns |
| F-A-16 | §5.3.C diagram shows `phase-complete 7` -- EDM has only 6 phases | Diagram Errors |
| F-A-17 | §5.3.A diagram ambiguous on SessionStart reading from HANDOFF vs re-deriving from state | Diagram Errors |
| F-A-18 | EDMV2-10 (G7) defers implement-vs-no-op decision without a default | Specification Quality |
| F-A-19 | §5.2.2 says "current 16 subcommands" but dispatch block exposes 17 | Factual Mistakes |
| F-B-13 | §6.2 typed-value coercion doesn't enumerate which fields are "known-typed" | Specification Quality |
| F-B-14 | §6.3 architecture-doc and decision-ledger slots lack concrete filenames | Specification Quality |
| F-B-15 | §8.4 "new lint hook event" doesn't name the hook event | Specification Quality |
| F-B-16 | §6.1 `current_step` default inconsistency between table and §5.4 | Specification Quality |
| F-B-17 | No migrate-path rollback/atomicity spec | Additional Concerns |
| F-B-18 | WS-H `{epic}` token undefined in per-epic test artifact filenames | Specification Quality |
| F-B-19 | EDMV2-47 IaC profile "resource paths" unspecified | Specification Quality |
| F-C-08 | §11.2 G2 and G18 severity grades inconsistent with §1 and planning.md | Factual Mistakes |
| F-C-09 | EDMV2-91 `cmd_list` glob won't find new-layout initiatives (one level deeper) | Specification Quality |
| F-C-10 | §11.3 glossary missing 8+ terms from §4/§8 | Additional Concerns |
| F-C-11 | EDMV2-99 (PreCompact) is redundant with EDMV2-94/95 | Reuse Opportunities |
| F-C-12 | §10.2 backward-compat claim doesn't address v1 stringified booleans | Backward Compatibility |
| F-C-13 | §10.1 major-version bump rationale contradicts "no breaking change" | Specification Quality |

---

## Requirements Added During Audit

| ID | Section | Priority | Description |
|----|---------|---------|------------|
| EDMV2-104 | §4.14 / Release | Must | `.claude-plugin/marketplace.json` version field bumped to 2.0.0 in lockstep with plugin.json |
| EDMV2-105 | §10.5 | Must | Before any `bin/edm-state` mutation on a live EDMV2 run: back up `.edm-state.json` and test offline |

**Total requirements after remediation:** 105

---

## Key Architectural Decisions Made During Audit

1. **Two separate mode fields:** `mode` (adaptation profile: standard/mini-srd/iac/data-ml/prototype) + `lifecycle_mode` (lifecycle variant: standard/partial/fast-track/fix-pack) -- orthogonal, not combined.
2. **Active-initiative detection:** directory not under `.archived/` AND `current_phase` in 1-6. No top-level `completed_at` field exists or will be added.
3. **Archive gating (G18):** three-case rule -- absent field (v1 legacy) = warn-only; explicit `false` + v2 marker = refuse; `true` = proceed.
4. **`current_step` lifecycle:** lazy creation (absent from init; created on first `current-step` write; read with `// null` fallback). Not pre-initialized.
5. **QC shard threshold:** 20 tickets triggers sharding; max 12 per shard; epic-boundary alignment preferred.
6. **WS-D canonical artifact paths:** `architecture.md`, `decisions.md`, `ROLLBACK.md`, `exec-report.md`, `explorers/` (all normative, not "e.g.").
7. **UserConfig vs state precedence:** per-initiative state overrides userConfig defaults; `product_name` is per-initiative only (removed from userConfig).

---

## Audit Coverage

All 103 EDMV2-NN requirements (v1.0.0) reviewed. 105 requirements in v1.0.1 (2 added). All sections covered:

| Auditor | Scope | P0 | P1 | P2 |
|---------|-------|----|----|-----|
| Group A | §1-5, EDMV2-01..43 | 2 | 9 | 8 |
| Group B | §6-9, EDMV2-44..65 | 3 | 9 | 7 |
| Group C | §10-11, EDMV2-66..103 | 1 | 6 | 6 |
| **Total** | | **6** | **24** | **21** |
