# QC Audit Report: EDMV3 Wave A -- Epics E1 + E2 [Shard 1/2]

**Date**: 2026-07-27
**Tickets audited**: EDMV3-T01 through EDMV3-T14 (T18 not in wave A -- skipped)
**Audit method**: static verification by reading implementation + test code (auditor had no Bash tool -- stale plugin-cache grants). Every verify command re-derived by reading the target file; suite-execution ACs corroborated by the orchestrator's fresh run-all.sh receipt (691/691, lint --all CLEAN, edm-check-grants exit 0).
**Implementation mode**: standard.

## Summary

| Ticket | Title | Verdict |
|---|---|---|
| EDMV3-T01 | edm-init branch handshake + regression tests | FAIL (AC9) |
| EDMV3-T02 | Write for the thirteen-agent F3 class | PARTIAL (AC8, AC9, AC10, AC12) |
| EDMV3-T03 | bin/edm-check-grants + AskUserQuestion grants | PARTIAL (AC4, AC11) |
| EDMV3-T04 | README install path + platform constraint | FAIL (AC8) |
| EDMV3-T05 | Split state_anomalies into info/blocking | PARTIAL (AC5) |
| EDMV3-T06 | Permission ask rules + enforcement tags | PARTIAL (AC3) |
| EDMV3-T07 | Mode derivation helpers | FAIL (AC4) |
| EDMV3-T08 | approve-gate code-audit | PASS |
| EDMV3-T09 | cmd_set checked contract | PASS |
| EDMV3-T10 | edm-state migrate-schema | PASS |
| EDMV3-T11 | phase-complete artifact verification | FAIL (AC1) |
| EDMV3-T12 | archive verifies the whole lifecycle | PASS |
| EDMV3-T13 | Gate enforcement in the kernel | FAIL (AC7) |
| EDMV3-T14 | Legacy state grandfathering | FAIL (AC1, AC2) |

**Rollup**: 4 PASS, 4 PARTIAL, 6 FAIL. 3 P1 findings (2 distinct root causes), 3 P2 findings, 0 P0.

## Key findings (detail per non-PASS ticket)

**[P2] EDMV3-T01 | .gitlab-ci.yml:123-136 | AC#9**: `grep -n 'wave6-smoke' .gitlab-ci.yml` returns zero hits. The suite does run via run-all.sh auto-discovery; missing durable pointer only. Fix: one echo line in test:smoke mirroring the wave7 pointer at :136.

**[PARTIAL] EDMV3-T02 | AC#8**: runtime-check: run `/edm:code-audit <FIXTURE> --lenses L1` after plugin-cache refresh; expect `ls <init-dir>/code-audit/pass-*/lens-L1.md | wc -l` = 1 and clean `git status` outside the pass dir. AC#9: `claude plugin validate plugins/edm/` vs baseline 1 warning. AC#10: `bash plugins/edm/bin/edm-check-grants; echo $?` = 0. AC#12: MR-description before/after review.
Advisory: plugins/edm/CLAUDE.md "Testing layer agent inventory" still lists edm-test-coverage-auditor as opus/max, contradicting the D16 sonnet/high frontmatter -- doc drift, fold into the next CLAUDE.md-touching ticket.

**[PARTIAL] EDMV3-T03 | AC#4**: runtime-check: `git stash && bash plugins/edm/bin/edm-check-grants | grep -c '^agent:' && git stash pop` (expect 13); record both counts. AC#11: `claude plugin validate`.

**[P2] EDMV3-T04 | plugins/edm/README.md:1,5,17,102-107,111 + plugins/edm/CLAUDE.md (80 hits) | AC#8**: both edited files carry pre-existing U+2014 em dashes; ticket-added text is ASCII. `edm-lint-artifacts --all` scans SRD initiatives only, so nothing catches these. Fix: normalize to `--`, or state a plugin-doc carve-out in "Artifact content conventions" and amend AC8.

**[PARTIAL] EDMV3-T05 | AC#5**: MR-description names the single SIZE_UNKNOWN blocking->info reclassification (recorded in-code at bin/edm-state:656-661).

**[PARTIAL] EDMV3-T06 | AC#3**: runtime-check: a human runs the three bypass shapes interactively with the ask rules configured and records whether a prompt fired. Present record is a self-disclosed documented-behaviour derivation (Claude Code 2.1.220).

**[P1] EDMV3-T07 | plugins/edm/bin/edm-state:2402-2411 | AC#4**: cmd_set_mode writes .mode only and explicitly declines seeding skipped_phases on mode change (to protect wave4a T96 exact counts). AC requires seeding at creation AND mode change. Fix: merge default_skipped_phases_json_for_mode into skipped_phases on mode change (dedupe by phase) + update wave4a T96 counts, or amend AC4 to creation-only via gate change control.

**PASS**: EDMV3-T08 (all 10 ACs), EDMV3-T09 (all 13), EDMV3-T10 (all 9), EDMV3-T12 (all 12) -- verified at file:line, incl. T12's deleted product_name conjunct surviving only on the sanctioned C-4 legacy branch (:1661, documented :1649-1652, CHANGELOG:66-71).

**[P2] EDMV3-T11 | bin/edm-state:1199-1226 | AC#1**: per-phase map correct and complete, but the extended present_or_absent() nonempty variant (:358-369) has zero call sites -- checks use bare `[[ -s ]]` (the "sixth presence idiom" the AC forbids). Behavior correct; structural miss + dead code. Fix: route the six arms through the helper, or delete the variant and amend AC1.

**[P1] EDMV3-T13 | bin/edm-state:1113-1121 and :2106-2111 | AC#7**: legacy branch keys on `.mode == "null"`, never reads schema_version. The real archived EDMV2 fixture (SRD/.archived/EDMV2/.edm-state.json:121) has mode="standard" and no schema_version -- a genuine pre-EDMV3 initiative gets FULL enforcement at phase-start instead of warn-and-proceed. cmd_gate_check same substitution despite its :2073 "# requires schema_version >= 1" comment. Fix: branch on `schema_at_least "$sv" 1`, keep mode-null as secondary, emit the legacy warn line, call record_degraded_check; apply to both functions; re-point wave6-smoke.sh:668 and the T14 class-1 block at a mode-present/schema-absent fixture.

**[P1] EDMV3-T14 | same root cause | AC#1 + AC#2**: three of four checks degrade correctly (phase-complete artifact, phase-6 PARTIAL, archive); phase-start does not (see T13 AC7). The :1119 warn line names "(no mode field)" and is unreachable for the legacy shape the AC defines. Closes together with the T13 fix.

## Remediation Required (D13: all severities)

1. **P1**: legacy signal `mode` -> `schema_version` in cmd_phase_start (:1113-1121) and cmd_gate_check (:2106-2111); warn lines renamed; record_degraded_check wired; tests re-pointed at the real legacy shape. Closes T13 AC7 + T14 AC1/AC2.
2. **P1**: cmd_set_mode seeds skipped_phases on mode change (dedupe by phase, preserve rationales) + wave4a T96 count updates -- or AC4 amended to creation-only via gate change control. Closes T07 AC4.
3. **P2**: wave6-smoke pointer line in .gitlab-ci.yml test:smoke. Closes T01 AC9.
4. **P2**: README.md + CLAUDE.md em-dash normalization (or explicit carve-out + AC amendment). Closes T04 AC8.
5. **P2**: route the six phase-complete arms through present_or_absent nonempty (or delete the dead variant + amend AC1). Closes T11 AC1.

## Runtime closures needed before wave-A sign-off (PARTIALs)

T02 AC8 (live lens run, post plugin-cache refresh), T02 AC9 / T03 AC11 (claude plugin validate vs baseline), T02 AC10 (edm-check-grants exit 0 -- orchestrator receipt already shows PASS), T02 AC12 / T05 AC5 (MR-description review artifacts), T03 AC4 (pre-T02 count = 13, record both counts), T06 AC3 (human interactive permission-dialog observation).

## Cross-shard note (for shard 2)

`grep -c 'mktemp -d' wave6-smoke.sh` = 4 (:16 suite-level trapped root, :396 non-worktree case, :817-818 T06 settings sandboxes). EDMV3-T16 AC8's verify is literal 0 -- grade deliberately.
