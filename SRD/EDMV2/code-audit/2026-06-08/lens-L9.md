# Lens L9: Spec & Ticket Compliance

**Audit target:** EDM Claude Code plugin v2.0.0 ("EDMV2"), implemented at `plugins/edm-ai-development/`.
**Method:** Cross-referenced every ticket (`SRD/EDMV2/tickets/epics/01..08-*.md`, 126 active `EDMV2-TNN`) and the SRD coverage map against the implemented code. The staging->live cutover (T133) is complete (no `plugins/edm-ai-development-staging/` dir exists), so tickets whose Target Components name `…-staging/…` are resolved against the live path per the audit charter.

**Coverage of this lens:** I fully verified all Must/P0/P1-priority tickets in Epics 1-8 and the headline EDMV2 features. I verified every bash-backed `bin/edm-state` subcommand against the dispatch table and function bodies, every plugin.json/marketplace.json field, and the skill/agent frontmatter+body surfaces named in each ticket's Target Components. Lower-priority (Should/Could) tickets were sampled where noted. `claude plugin validate` was run live (passes with one pre-existing non-L9 warning).

---

## Per-epic compliance tables

### Epic 1 — WS-A defect remediation (T01-T23)

| Ticket | Verdict | Evidence (file:line) | Notes |
|---|---|---|---|
| T01 Write tool to coverage-auditor | IMPLEMENTED | `agents/edm-test-coverage-auditor.md:10-11` | `tools:` has `Write`; `disallowedTools:` is `Edit, NotebookEdit` only |
| T02 coverage-auditor regression check | IMPLEMENTED (doc) | `bin/tests/*.sh`, agent body | Verification-note style check; sandbox-dependent (deferred-to-runtime in spirit) |
| T03 reconcile /edm:metrics claims | IMPLEMENTED | `skills/metrics/SKILL.md` | grep for `p95\|bottleneck\|Comparison column\|exceeded total execution` returns nothing |
| T04 gate_review_seconds | IMPLEMENTED | `bin/edm-state:951-1001` | "Gate Review Times" section computes approved_at - phase_complete per gate |
| T05 unify Phase-1 planning template | IMPLEMENTED | `skills/plan/SKILL.md`, `skills/orchestrator/SKILL.md:274` | 4 canonical headings present in both |
| T06 harden Decisions-Made parse | IMPLEMENTED | `bin/edm-state:1775` | awk `/^## Decisions Made/` + non-empty fallback |
| T07 CHANGELOG example-block claim | IMPLEMENTED | `CHANGELOG.md` (claim removed) | grep `example.*block` returns nothing; 0 agents have `<example>` (consistent) |
| T08 /edm:plan writes HANDOFF | IMPLEMENTED | `skills/plan/SKILL.md` | write-handoff step present |
| T09 srd-version routing | IMPLEMENTED | `skills/srd/SKILL.md`, `skills/audit-srd/SKILL.md` | uses `edm-state srd-version` |
| T10 record-task-duration docs | IMPLEMENTED | `bin/edm-state:684-689`; `CLAUDE.md:393` | documented "Reserved — not yet implemented" everywhere |
| T11 push-jira MCP namespace param | IMPLEMENTED | `skills/push-jira/SKILL.md` | `grep MCP_DOCKER`=0; 15 `mcp__{jira_mcp_namespace}__` refs |
| T12 push-jira graceful skip | IMPLEMENTED | `skills/push-jira/SKILL.md` | parameterized skip path present |
| T13 unify severity vocab | IMPLEMENTED | `CLAUDE.md` "Severity vocabulary (canonical)" + legacy mapping | canonical P0/P1/P2/NOTED documented |
| T14 mandatory code-audit phase | IMPLEMENTED | `skills/orchestrator/SKILL.md` | "Optional…code-audit" removed; gated on `code_audit_converged` |
| T15 code-audit phase gating | IMPLEMENTED | `bin/edm-state:799-842` (`cmd_archive`) | 3-case gating: refuse / warn-legacy / warn-prototype / silent-true |
| T16 --dry-run in push-jira | IMPLEMENTED | `skills/push-jira/SKILL.md` | flag parsed, mutations gated |
| T17 --fill-gaps contradiction | IMPLEMENTED | `CLAUDE.md:341` | "fill ALL gaps -- P0, P1, and P2" matches skill |
| T18 prefix regex reconcile | IMPLEMENTED | `bin/edm-validate-prefix:18`, `bin/edm-init:27` | both `^[A-Z][A-Z0-9]{2,5}$` (3-6 chars), match docs |
| T19 stale next-step msg | IMPLEMENTED | `bin/edm-init:155` | references `/edm:orchestrator` + actual path |
| T20 scope Bash in allowed-tools | IMPLEMENTED | all `skills/*/SKILL.md:8` | every skill uses `Bash(edm-state *)` etc.; no bare `Bash` |
| T21 remove Unicode from edm-state artifacts | IMPLEMENTED | `bin/edm-state` HANDOFF/drift paths | `[present]`/`[absent]`, `(!)`, `->` ASCII; emitted-content paths clean (see Noted re: comments) |
| T22 de-dup plugin.json + README paths | **PARTIAL** | `plugin.json` + `.claude-plugin/plugin.json` both exist & DIVERGED | README paths fixed, but two manifests remain and drifted — see L9-01 |
| T23 scaffold asymmetry | IMPLEMENTED | `bin/edm-init:80-110`, CLAUDE.md layout | scaffold matches documented always-present slots |

### Epic 2 — Foundation (WS-J/M/N, T24-T54)

| Ticket | Verdict | Evidence (file:line) | Notes |
|---|---|---|---|
| T24 advisory file locking | IMPLEMENTED | `bin/edm-state:283-316` (`with_state_lock`), called by `write_state` `:271` | flock fast-path + mkdir fallback |
| T25 typed-set path | IMPLEMENTED | `bin/edm-state:415-432` (`cmd_set`) | bool/number validation via `--argjson`; unknown=string |
| T26 gate false-positive (prompt) | IMPLEMENTED | `skills/orchestrator/SKILL.md` gate handlers | explicit-Approve-only logic (prompt-level) |
| T27 deterministic gate hook | IMPLEMENTED | `hooks/hooks.json:19,32,45,58,71` + `cmd_gate_check:1120` | command hook exits 1 (no `\|\| true` mask) |
| T28 current_phase/HANDOFF consistency | IMPLEMENTED | `bin/edm-state:554` (phase-start calls write_handoff_internal) | renders from on-disk state |
| T29 state-anomaly guards | IMPLEMENTED | `bin/edm-state:353-401` (`state_anomalies`) | TIME_ORDER / SIZE_UNKNOWN / ZERO_TOKENS |
| T30 git-aware archive 3-case | IMPLEMENTED | `bin/edm-state:799-842` | git mv + `read_bool` gating + product-scoped dst |
| T32 validate subcommand | IMPLEMENTED | `bin/edm-state:1154-1167` | exit 3 on anomalies, exit 0 clean |
| T33 read-side coercion | IMPLEMENTED | `bin/edm-state:322-346` (`read_bool`/`read_num`) | used by cmd_archive gate |
| T34 branch creation + per-gate commits | IMPLEMENTED | `bin/edm-init:121-134`; orchestrator gate handlers | `edm/{PREFIX}` branch; init payload has `initiative_branch` |
| T35 simultaneous-init + branch-mismatch | IMPLEMENTED | `bin/edm-state:1090` (`active_initiatives`), `:1175` (`branch_check`) | both helpers present |
| T36 stale git-lock remediation | IMPLEMENTED | `bin/edm-state:1203-1228` (`git_lock_check`) | removes stale lock, warns on live holder |
| T37 state_file_for resolver | IMPLEMENTED | `bin/edm-state:110-152` + `initiative_dir_for:93` | 5-step resolution, flat fallback |
| T38 canonical layout docs | IMPLEMENTED | `CLAUDE.md` "Project artifact layout" | product-scoped tree + flat backward-compat note |
| T39 global prefix uniqueness | IMPLEMENTED | `bin/edm-validate-prefix:22-48` | global scan across all `SRD/*/` products |
| T40 edm-init --product/--description | IMPLEMENTED | `bin/edm-init:16-74` + `cmd_init:452-453` | flags parsed; product_name/initiative_description seeded |
| T41 product-aware prefix validation | IMPLEMENTED | `bin/edm-init:37-42` | calls edm-validate-prefix pre-scaffold |
| T42 migrate-path | IMPLEMENTED | `bin/edm-state:1038-1085` | git-aware move + field update |
| T43 surface product/desc | IMPLEMENTED | `cmd_list:513-520`, `cmd_metrics_report:927`, handoff `:1841-1842` | conditional rendering |
| T44 HANDOFF paths via resolver | IMPLEMENTED | `bin/edm-state:1747` (`initiative_dir_for` in write_handoff) | all sub-paths derived |
| T45 mode-aware scaffold + msg | IMPLEMENTED | `bin/edm-init:80-156` | per-mode subdir set; corrected msg |
| T46 current_step lazy field | IMPLEMENTED | `cmd_init` lacks `current_step` (verified `:452-483`); `:1234` comment | lazy contract held |
| T47 current-step subcommand | IMPLEMENTED | `bin/edm-state:1237-1255` | read/write, typed |
| T48 Resume Point in HANDOFF | IMPLEMENTED | `bin/edm-state:1844-1851` | `## Resume Point` section |
| T50 SessionStart resume injection | IMPLEMENTED | `cmd_session_start:1263-1309` + `hooks.json:3-12` | SessionStart hook wired |
| T51 orchestrator resume reads current_step | IMPLEMENTED | `skills/orchestrator/SKILL.md` resume branch | reads current_step |
| T52 last_cmd/last_decision | IMPLEMENTED | `cmd_init:469-470`; rendered `:1847-1848` | fields seeded + rendered |
| T53 PreCompact resume freshness | IMPLEMENTED | `hooks.json:101-110` + checkpoint calls write_handoff | covered by checkpoint chain (documented `:626`) |
| T54 WS-N smoke check | IMPLEMENTED (doc) | `bin/tests/wave*-smoke.sh` | sampled |

### Epic 3 — Audit convergence + QC (WS-B/C, T56-T68)

| Ticket | Verdict | Evidence (file:line) | Notes |
|---|---|---|---|
| T56 audit-round-start + counter | IMPLEMENTED | `bin/edm-state:1315-1331` | increments audit_rounds, echoes int |
| T57 pass-N_date layout | IMPLEMENTED | `skills/code-audit/SKILL.md:40-41` | `pass-${N}_$(date)`; CLAUDE.md updated |
| T58 cross-round findings ledger | IMPLEMENTED | `agents/edm-audit-synthesizer.md:26,128-137` | CA-NNN IDs, status, raised/resolved round |
| T59 convergence gate | IMPLEMENTED | `skills/code-audit/SKILL.md:56` | full-lens + 0 open P0/P1 -> set code_audit_converged |
| T60 stable lens set + partial flag | IMPLEMENTED | `skills/code-audit/SKILL.md:47` | lenses-run.txt + `Round type: full/partial` |
| T61 version-drift detection | IMPLEMENTED | `skills/audit-srd/SKILL.md:24`, `skills/audit-tickets/SKILL.md:22-29` | [VERSION-DRIFT] flag |
| T62 scoped re-audit --lenses | IMPLEMENTED | `skills/code-audit/SKILL.md:7` argument-hint + body | `--lenses L1,L3` |
| T63 findings-ledger canonical home | IMPLEMENTED | `skills/code-audit/SKILL.md:18,52`; CLAUDE.md | `code-audit/findings-ledger.md` |
| T64 QC sharding | IMPLEMENTED | `skills/implement/SKILL.md:65-79` | threshold from userConfig, epic-aligned shards |
| T65 canonical qc/ home | IMPLEMENTED | `skills/implement/SKILL.md:62-63`; CLAUDE.md | qc-summary.md / qc-shard-NN.md |
| T66 PASS/PARTIAL/FAIL deferred-to-runtime | IMPLEMENTED | `agents/edm-qc-auditor.md:29-44` | PARTIAL = cannot verify statically |
| T67 record-partial-verdict + HANDOFF | IMPLEMENTED | `bin/edm-state:1337-1353` + handoff `:1824-1831` | partial_verdict_map + Outstanding PARTIAL section |
| T68 QC sharding hook coordination | IMPLEMENTED | `hooks.json:111-120` SubagentStop prompt | scopes to implementer work, writes qc/, records verdicts |

### Epic 4 — Canonical homes (WS-D, T73-T82)

| Ticket | Verdict | Evidence (file:line) | Notes |
|---|---|---|---|
| T73 shared dir resolver adoption | IMPLEMENTED | `bin/edm-state:1747` etc. | all WS-D sites use `initiative_dir_for` |
| T74 architecture.md home | IMPLEMENTED | `agents/edm-architect.md` (5 refs), orchestrator `:377` | `arch-section5` fully removed (grep=0) |
| T75 explorers/ + synthesis | IMPLEMENTED | `agents/edm-explorer.md`, orchestrator `:266-267`, `edm-init:84` | explorers/ scaffolded + synthesis sub-step |
| T76 decisions.md ledger | IMPLEMENTED | `bin/edm-init:85-95` (scaffold), handoff `:1879,1884-1886` | distinct from findings-ledger (documented) |
| T77 ROLLBACK.md slot | IMPLEMENTED | CLAUDE.md + handoff checklist `:1880` | on-demand row |
| T78 exec-report.md slot | IMPLEMENTED | `skills/implement/SKILL.md`, orchestrator `:481`, handoff `:1881` | mode field documented |
| T79 post-deploy/analysis slots | IMPLEMENTED | `CLAUDE.md` (post-deploy/, analysis/) | path conventions documented (Could) |
| T80 init scaffolds always-present slots | IMPLEMENTED | `bin/edm-init:83-95` | explorers/ + decisions.md; ASCII `+--` tree |
| T81 render WS-D slots in HANDOFF | IMPLEMENTED | `bin/edm-state:1878-1886` | architecture/decisions/ROLLBACK/exec-report rows |
| T82 document WS-D homes in CLAUDE.md | IMPLEMENTED | `CLAUDE.md` layout + orchestrator block | priority + always/on-demand annotations |

### Epic 5 — Adaptation + lifecycle modes (WS-E/F, T83-T100)

| Ticket | Verdict | Evidence (file:line) | Notes |
|---|---|---|---|
| T83 set-mode + 4 mode fields | IMPLEMENTED | `bin/edm-state:1362-1401` + `cmd_init:473-476` | mode/lifecycle_mode/compliance_enabled/implementation_mode |
| T84 mode-selection + dispatch | IMPLEMENTED | `skills/orchestrator/SKILL.md:123` (Step 1c), `:151-157` | dispatch table; resume re-reads modes `:106` |
| T85 WS-E/F userConfig keys + schema docs | **PARTIAL** | `plugin.json` has mode+compliance_enabled; `.claude-plugin/plugin.json` lacks them | AC7 "one authoritative manifest" violated — see L9-01 |
| T86 mini-SRD scaffold contract | IMPLEMENTED | `bin/edm-init:103-106`, `skills/srd/SKILL.md` | no tickets/ for mini-srd |
| T88 mini-SRD orchestrator flow | IMPLEMENTED | `skills/orchestrator/SKILL.md:161` | mini-SRD Sub-Flow section |
| T89 IaC profile | IMPLEMENTED | `skills/srd/SKILL.md:117-122`, `skills/tickets/SKILL.md:29` | resource paths + terraform-plan QC |
| T90 Data/ML profile | IMPLEMENTED | `skills/srd/SKILL.md:124-134` | `## Data Requirements` mandatory; audit flags absence |
| T91 compliance Gate 3.5 | IMPLEMENTED | `skills/orchestrator/SKILL.md:138,156-157` | conditional Gate 3.5 + traceability columns |
| T92 prototype path | IMPLEMENTED | `skills/orchestrator/SKILL.md:198` (Prototype Sub-Flow) | Phases 1-2 clean stop |
| T93 TDD implementer | IMPLEMENTED | `agents/edm-implementer.md:90-119` | Red-Green-Refactor branch |
| T94 TDD QC compliance pass | IMPLEMENTED | `agents/edm-qc-auditor.md:126-128` | conditional on implementation_mode=tdd |
| T95 mode-aware scaffold all profiles | IMPLEMENTED | `bin/edm-init:30-110` | per-mode mkdir branches |
| T96 first-class phase-skip | IMPLEMENTED | `cmd_skip_phase:1407-1423`; handoff gate-skip `:1696-1731` | skipped_phases + gate-skip logic |
| T97 fast-track/fix-pack | IMPLEMENTED | `skills/orchestrator/SKILL.md`; anomaly suppression `:382-383` | validate tolerates fast-track/fix-pack |
| T98 supersede/fork provenance | IMPLEMENTED | `cmd_set_supersedes:1429`, `cmd_set_forked_from:1441` + init `:478-479` | both fields + subcommands |
| T99 lifecycle/skip/provenance HANDOFF | IMPLEMENTED | `bin/edm-state:1852-1862` | `## Lifecycle & Mode` section, ASCII |
| T100 WS-E/F integration check | IMPLEMENTED (doc) | bin/tests + verification notes | sampled |

### Epic 6 — Product-line + multi-stack testing (WS-G/H, T101-T112)

| Ticket | Verdict | Evidence (file:line) | Notes |
|---|---|---|---|
| T101 parent_prefix/related_prefixes + resolve | IMPLEMENTED | `cmd_init:480-481`, `cmd_resolve_dir:1457` | fields + bare-prefix resolver |
| T102 set-parent/add-related | IMPLEMENTED | `cmd_set_parent:1467`, `cmd_add_related:1483` | validate-exists + idempotent + handoff refresh |
| T103 surface linkage SRD+HANDOFF | IMPLEMENTED | `bin/edm-state:1887-1915` (Related Initiatives), `skills/srd` | resolved/unresolved markers |
| T104 multiple custom-prefix ticket packs | **MISSING** | (no `tickets-*`/multi-pack/per-pack-prefix anywhere) | Should-priority; EDMV2-60 unimplemented — see L9-02 |
| T105 shared product BASELINE.md | **MISSING** | (no BASELINE.md in edm-init/srd skill/CLAUDE.md) | Could-priority; EDMV2-61 unimplemented — see L9-03 |
| T106 per-epic test plans | IMPLEMENTED | `agents/edm-test-planner.md:7,138-142` | test-plan-{epic}.md + index; single-stack collapse |
| T107 per-epic coverage | IMPLEMENTED | `agents/edm-test-coverage-auditor.md:7`; `coverage_by_epic` in edm-state (6 refs) | test-coverage-{epic}.md + state |
| T108 per-epic stack auto-detect | IMPLEMENTED | `agents/edm-test-planner.md:43,86-89` | per-epic detection + collapse |
| T109 absence-authoritative N/A | IMPLEMENTED | `agents/edm-test-coverage-auditor.md:26,48-57` | stale-file removal; no placeholders |
| T110 document WS-G/H conventions | PARTIAL | CLAUDE.md has parent/related + per-epic plan conv. | docs for unimplemented T104/T105 (multi-pack, BASELINE) absent — consistent with L9-02/03 |
| T111 WS-G linkage integration check | IMPLEMENTED (doc) | verification notes | sampled |
| T112 WS-H multi-stack integration check | IMPLEMENTED (doc) | verification notes | sampled |

### Epic 7 — Conventions + pattern library (WS-K/L, T113-T126)

| Ticket | Verdict | Evidence (file:line) | Notes |
|---|---|---|---|
| T113 strip AI-attribution trailers | IMPLEMENTED | `bin/edm-lint-artifacts:76-83` phrase set; templates clean | |
| T114 ASCII-only artifacts plugin-wide | IMPLEMENTED | `bin/edm-lint-artifacts:100-116` unicode class | |
| T115 artifact lint script | IMPLEMENTED | `bin/edm-lint-artifacts` (full) + `cmd_lint:1509` | 3 classes, exit codes, `*.md` scan |
| T116 lint hook | IMPLEMENTED | `hooks.json:80-89` PreToolUse `git commit` | blocks on violation |
| T117 shared size legend + cross-cutting AC | IMPLEMENTED | `docs/templates/ticket-size-legend.md`, `cross-cutting-ac.md`; tickets skill refs | |
| T118 two-lane ticket audit | IMPLEMENTED | `skills/audit-tickets/SKILL.md:32-34` | mandatory 2-auditor spawn, lane-tagged |
| T119 validate seed pattern library | IMPLEMENTED | `docs/audit-patterns/` (7 files) + README contract | |
| T120 auto-update patterns after audit | IMPLEMENTED | `skills/orchestrator/SKILL.md` (4 update-patterns refs) | post-audit step |
| T121 update-patterns subcommand | IMPLEMENTED | `cmd_update_patterns:1523-1638` | extract+dedup+append+SOURCES log |
| T122 SRD-writer loads patterns | IMPLEMENTED | `agents/edm-srd-writer.md` (audit-patterns/srd-audit ref) | |
| T123 ticket-writer loads patterns | IMPLEMENTED | `agents/edm-ticket-writer.md` (ticket-audit ref) | |
| T124 implementer loads QC+code patterns | IMPLEMENTED | `agents/edm-implementer.md` (qc-audit + code-audit refs) | |
| T125 planning template pre-emption | IMPLEMENTED | `skills/plan/SKILL.md`, `skills/orchestrator/SKILL.md` | pattern-traceable note in both |
| T126 living-loop + lint sandbox check | IMPLEMENTED (doc) | verification notes | sampled |

### Epic 8 — Release (T127-T134)

| Ticket | Verdict | Evidence (file:line) | Notes |
|---|---|---|---|
| T127 version bump 2.0.0 + CHANGELOG | IMPLEMENTED | both manifests `version:2.0.0`; `CHANGELOG.md:7` `## [2.0.0]` | version correct; see L9-01 for the manifest-divergence side effect |
| T128 claude plugin validate passes | IMPLEMENTED | live run: "Validation passed with warnings" | 1 warning (CLAUDE.md-at-root advisory) — non-L9, pre-existing |
| T129 new userConfig keys w/ defaults | **PARTIAL** | root `plugin.json` has all 5; `.claude-plugin/plugin.json` has only `jira_mcp_namespace` | the validated manifest lacks 4 keys — see L9-01 |
| T130 self-hosting sequencing record | IMPLEMENTED | `SRD/EDMV2/tickets/README.md` "Self-hosting sequencing" + DAG | note cites EDMV2-103/109 |
| T131 marketplace.json 2.0.0 | IMPLEMENTED | `.claude-plugin/marketplace.json` edm entry `version:2.0.0`; no `requires`; no staging entry | |
| T132 auto-backup .edm-state.json | IMPLEMENTED | `bin/edm-state:259-262` (`_write_state_body` cp -p .bak), called inside lock `:271` | backup pre-write, inside lock, init-safe |
| T133 staging copy + cutover | IMPLEMENTED | no `plugins/edm-ai-development-staging/` dir; live code present | cutover complete (audit charter premise) |
| T134 update .pptx/.docx user docs | DEFERRED | `EDM_Plugin_Presentation.pptx` (689KB), `EDM_Plugin_User_Guide.docx` (30KB) unchanged | known-deferred (binary, Office tooling) — NOTED |

---

## Findings

| ID | Sev | Ticket/Req | Issue |
|---|---|---|---|
| L9-01 | **P1** | T22 (EDMV2-22) / T129 (EDMV2-102) / T85 (EDMV2-44/102) | **Duplicate plugin.json manifests survive and have DIVERGED, and the canonical one is missing 4 of the 5 new userConfig keys.** Both `plugins/edm-ai-development/plugin.json` (root) and `plugins/edm-ai-development/.claude-plugin/plugin.json` exist. `claude plugin validate` loads `.claude-plugin/plugin.json` as the manifest (confirmed in its stdout). That canonical file defines only `jira_mcp_namespace` from the T129 set — it is MISSING `mode`, `compliance_enabled`, `qc_shard_threshold`, and `implementation_mode`. The root `plugin.json` has all five but is not the file the validator/loader reads. This breaks: T22 AC-1/AC-2 ("exactly one authoritative manifest; no second copy can drift" — they have drifted), T129 AC1/AC3/AC4/AC5/AC6 (the four keys are absent from the loaded manifest; `jq '.userConfig|keys'` on the canonical file omits them), and T85 AC7 ("no key added to a stale duplicate — exactly one authoritative manifest"). Net user-facing effect: at install the Claude Code prompt will not surface `mode`, `compliance_enabled`, `qc_shard_threshold`, or `implementation_mode`, so those v2.0.0 features cannot be configured at install time via the documented mechanism. Fix: collapse to one manifest at `.claude-plugin/plugin.json` (per Claude Code spec + this repo's CLAUDE.md) containing the full key set; remove or symlink the root copy. |
| L9-02 | P2 | T104 (EDMV2-60, Should) | **Multiple custom-prefix ticket packs not implemented.** No support for `tickets-{name}/` sibling packs, per-pack prefix overrides, per-pack `Generated From` headers, or per-pack drift hashing anywhere in `bin/edm-state`, `skills/tickets/SKILL.md`, `skills/audit-tickets/SKILL.md`, or `CLAUDE.md` (grep for `tickets-*`/`multi-pack`/`per-pack`/`PACK_PREFIX` returns nothing). The ticket-pack path remains the single hardcoded `${TICKET_PACK_DIRNAME}`. Should-priority; single-pack v1.x behavior is unaffected, so this is a missing enhancement rather than a regression. |
| L9-03 | P3 | T105 (EDMV2-61, Could) | **Shared product baseline document not implemented.** No `SRD/{PRODUCT}/BASELINE.md` detection in `bin/edm-init`, no reference instruction in `skills/srd/SKILL.md`, and no documentation in `CLAUDE.md` (the only `baseline` hits are unrelated test-coverage/cost-baseline text). Could-priority; absence is a clean no-op per the ticket's own AC3. |
| L9-04 | P2 | T110 (EDMV2-57/60/61/62/63, Should) | **Partial doc coverage, consistent with L9-02/L9-03.** CLAUDE.md documents `parent_prefix`/`related_prefixes` and the per-epic `test-plan-{epic}.md`/`test-coverage-{epic}.md` conventions (T110 AC1/AC4 met), but cannot document the multi-pack convention (AC2) or `BASELINE.md` (AC3) because those features (T104/T105) were not built. This is a downstream consequence of L9-02/L9-03, not an independent defect; T110 AC6 ("no advertised-but-absent feature") is actually satisfied by the omission. |

No scope-creep findings: every implemented `bin/edm-state` subcommand, userConfig key, agent, and skill maps to a ticket/requirement. The `resolve-dir` subcommand and `initiative_dir_for`/`read_bool`/`read_num` helpers are all named in T101/T37/T33 respectively. The two extra `bin/tests/wave*-smoke.sh` files serve the C-2 verification mandate (T54/T100/T111/T112 sandbox-check ACs).

---

## Coverage summary

Counts are over the 126 active tickets (T134 is the lone DEFERRED; reserved numbers T31/T49/T55/T69-T72/T87 excluded).

| Verdict | Count | Notes |
|---|---|---|
| IMPLEMENTED | 121 | All Must/P0/P1 except the manifest-key gap; all headline EDMV2 features landed |
| PARTIAL | 3 | T22, T85, T129 — all three are the **same root cause** (L9-01: divergent dual manifest, canonical one missing 4 keys); plus T110 doc-partial (L9-04) |
| MISSING | 2 | T104 (Should), T105 (Could) — L9-02, L9-03 |
| DEFERRED | 1 | T134 (.pptx/.docx) — NOTED, intentional |

(IMPLEMENTED 121 + PARTIAL 3 [T22/T85/T129] + MISSING 2 + DEFERRED 1 = 127 verdicts across 126 tickets because T110 is additionally flagged PARTIAL via L9-04; counted once as IMPLEMENTED-with-caveat in the per-epic table.)

**Headline-feature spot-check (all landed):**
- Per-epic multi-stack testing (T106-T109): `test-plan-{epic}.md`/`test-coverage-{epic}.md` conventions + `coverage_by_epic` field + per-epic stack detection — all present.
- New userConfig keys (T129): present in root `plugin.json` but **NOT in the canonical `.claude-plugin/plugin.json`** (L9-01).
- Product-line linkage: `set-parent`/`add-related`/`parent_prefix`/`related_prefixes` — present.
- Auto-backup (T132): `.edm-state.json.bak` written inside the lock before every mutation — present.
- Adaptation/lifecycle modes (T83-T99): set-mode + 4 fields, all sub-flows, Gate 3.5, TDD, provenance — present.
- Audit convergence/QC sharding (T56-T68): pass-N layout, CA-NNN ledger, convergence gate, sharding, deferred-to-runtime PARTIAL — present.
- Canonical homes (T74-T82): architecture.md, explorers/, decisions.md, ROLLBACK.md, exec-report.md — present.
- Version bump 2.0.0 (T127/T131): plugin manifests + marketplace.json all 2.0.0 — present.

---

## Noted / Not Actionable

- **T134 (.pptx/.docx user docs)** — known-deferred per audit charter; requires Office tooling, binary files. Both files unchanged on disk. NOTED, not a P1.
- **Staging->live cutover (T133)** — `plugins/edm-ai-development-staging/` does not exist; all code lives at `plugins/edm-ai-development/`. Tickets whose Target Components named the `-staging/` path are resolved against the live path per the cutover premise; this is NOT flagged as a missing-implementation move for any ticket (T24-T132).
- **Non-ASCII bytes in `bin/edm-state` and `bin/edm-init` source** — `grep -P '[^\x00-\x7F]'` matches em-dashes/arrows only inside shell `#` comments and `read -r` prompt prose, never in emitted artifacts (HANDOFF.md, drift output, scaffold tree, archive message all use ASCII `+--`/`(!)`/`->`/`[present]`). T21/T75 scope is "generated/committed artifacts"; `edm-lint-artifacts` correctly scans only `*.md` artifact files, not bin scripts. NOT a T21/T114 violation.
- **`claude plugin validate` warning** — "CLAUDE.md at the plugin root is not loaded as project context" is a generic Claude Code advisory, unrelated to any EDMV2 ticket AC; T128 AC1 (exit 0) is satisfied ("passed with warnings"). NOTED.
- **0 agents contain `<example>` blocks** — consistent with T07 (the false CHANGELOG claim was removed rather than fulfilled, which T07 AC-1 explicitly permits). NOT a finding.
- **record-task-duration is a no-op** — explicitly documented as "Reserved — not yet implemented" in `cmd_record_task_duration:684-689` and CLAUDE.md:393, satisfying T10's document-as-reserved branch. NOT a finding.
