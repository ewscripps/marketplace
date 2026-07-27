# Key Decisions

| # | Decision | Chosen | Rationale | Date |
|---|----------|--------|-----------|------|
| D1 | Streamline scope | Large (~50 files) | Medium scope plus structural/governance edits across all 30 agents (count corrected per audit finding B-02) | 2026-07-24 |
| D2 | Convergence-gate schema | Reuse the field | `edm-state approve-gate <PREFIX> code-audit` sets `code_audit_converged` directly; field removed from `cmd_set` allowlist | 2026-07-24 |
| D3 | `edm-init` branch fix | Post-checkout correction | Safer than reordering on the warn-and-continue failure path | 2026-07-24 |
| D4 | Grandfathering | Grandfather existing converged initiatives | No forced re-approval through the new gate | 2026-07-24 |
| D5 | `edm-explorer` write access | Grant `Write` tool | Agent persists its own findings, orchestrator stops proxying | 2026-07-24 |
| D6 | Code-audit deferral policy | No deferral, any severity | P0/P1/P2 all block convergence; NOTED (non-actionable) unaffected | 2026-07-24 |
| D7 | Audience | Team adoption planned | Enforcement kernel (R1) is top priority alongside mechanical fixes | 2026-07-25 |
| D8 | Mermaid `#59;` validation | Skip -- known working | User has seen `#59;` render correctly in org tooling; no fixture-MR ticket | 2026-07-25 |
| D9 | EDMV2 Phase 6 cost root cause | `phase-complete 6` never called | `phase-start 6` fired 2026-06-08T08:49:54Z, complete never did; fix = wire the call + archive lifecycle check; attribution scoping is a separate small ticket | 2026-07-25 |
| D10 | R4 orchestrator refactor | Full dispatcher | Skill-to-skill invocation confirmed working (git plugin precedent); phase procedures live once; gate protocol written once | 2026-07-25 |
| D11 | Platform support | macOS/Linux only | Stated constraint in README/CLAUDE.md; no porting work | 2026-07-25 |
| D12 | `lifecycle_mode=partial` | Dead -- delete | Joins delete list with `TaskCompleted` hook and `record-task-duration` no-op | 2026-07-25 |
| D13 | Universal no-deferral policy | Nothing deferred, ever | Broadens D6 to the whole methodology: all FAIL severities remediated; every PARTIAL closed via mandatory runtime verification before archive; no `--accept-partials` or equivalent escape hatches; no generic `--force` override on phase-complete artifact checks (mode-aware skip-phase records are the only exemption path); no deferral vocabulary in any prompt or template | 2026-07-25 |
| D14 | Phases-as-data | Out of EDMV3 scope | Scope boundary, not a deferral: a separate future initiative decided on its own merits after WS1-WS5 prove out through one real initiative | 2026-07-25 |
| D15 | Unverifiable AC (PARTIAL dead-end, audit finding C-01) | AC is a spec defect: rework it | No BLOCKED verdict, no exemption record. An AC whose runtime environment does not exist is a specification defect: remediation reworks the AC into something verifiable today, or moves the unverifiable clause to a follow-on initiative as a recorded scope boundary (D14 framing) via gate change control. verify-runtime records PASS/FAIL only; archive stays hard-blocked until every AC is closed | 2026-07-25 |
| D16 | Model/effort assignments (Gate 3 revise) | 3 safe downgrades now + measured tiering matrix for everything else | Immediate: edm-explorer and edm-test-coverage-auditor opus/max -> sonnet/high (scan/list work), edm-architect max -> high (writing work). Everything else (11 lenses, SRD/ticket auditors, QC auditor, synthesizer) UNCHANGED until the wave-C tiering matrix runs each agent against the wave-A eval fixture at candidate (model, effort) pairs; cheapest config wins only if it holds 100% P0/P1 recall and >= 80% total recall vs the opus/max baseline; any miss reverts to opus. Results recorded; matrix re-run per model generation. Rationale: hand-picked tiers are unmeasured judgment -- the same prose-not-mechanism sin this initiative exists to fix | 2026-07-26 |

## Finding-to-Commit Ledger

| Finding | Source | Decision | Ticket | Status |
|---------|--------|----------|--------|--------|
