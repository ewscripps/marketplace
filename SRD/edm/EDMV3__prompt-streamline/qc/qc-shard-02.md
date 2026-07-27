# QC Audit Report: EDMV3 Wave A -- Shard 2 of 2

**Date**: 2026-07-27
**Tickets audited**: EDMV3-T15, T16, T17, T19, T20, T21, T22, T23, T61, T62, T63, T64
**Tree**: plugins/edm @ 2.1.0
**Method**: static verification (no Bash -- stale cache grants); suite-dependent ACs closed against the orchestrator's run-all.sh 691/691 receipt; environment-dependent ACs PARTIAL with the exact runtime command.

## Summary

| Ticket | Verdict |
|---|---|
| EDMV3-T15 | PARTIAL (AC9 MR-review) |
| EDMV3-T16 | PASS (all 10 ACs) |
| EDMV3-T17 | FAIL (AC8) |
| EDMV3-T19 | FAIL (AC8) |
| EDMV3-T20 | FAIL (AC10) |
| EDMV3-T21 | FAIL (AC3, AC5, AC7; AC10/AC11 runtime) |
| EDMV3-T22 | FAIL (AC3; AC4/AC5 runtime) |
| EDMV3-T23 | PARTIAL (AC8/AC9/AC13 live baseline) |
| EDMV3-T61 | PARTIAL (AC7-jq/AC8/AC10/AC12 runtime) |
| EDMV3-T62 | PASS (all 10 ACs) |
| EDMV3-T63 | PARTIAL (AC5/AC7/AC8-10 runtime) |
| EDMV3-T64 | PARTIAL (AC9-12; AC11 not satisfiable until baseline lands) |

5 FAIL / 5 PARTIAL / 2 PASS. 4 P1 + 2 P2 findings. No P0.

## FAIL findings

**[P1] EDMV3-T17 | bin/edm-state:2917 | AC#8**: phase-6 pending_artifacts branch writes a literal U+2014 (`_(implementation in progress — track...)_`), printed unconditionally into HANDOFF.md at :2951. Every phase-6 write-handoff (phase-complete, gate approval, checkpoint hooks) reintroduces a non-ASCII byte into a committed artifact, reds `edm-lint-artifacts --all` (breaking T63 AC4) and blocks the PreToolUse commit hook. Live: EDMV3 itself is current_phase 6; HANDOFF.md:23 currently shows the T63-normalized `--` form -- artifact fixed, generator not. Fix: `--` at :2917; extend the wave6 ASCII loop (:1162-1180) with a current_phase-6 fixture (existing fixtures skip phases 1/3/5 and never reach case 6).

**[P1] EDMV3-T21 | .gitlab-ci.yml:149 | AC#7**: `image: "bash:3.2"` not digest-pinned; AC7 admits no exception. Also note :10-19 self-documents the alpine/node digests as placeholder captures needing refresh before first live use. Fix: pin, or record an explicitly authorized exception in ticket + plugins/edm/CLAUDE.md beside the macOS-runner note.

**[P1] EDMV3-T20 | wave7-smoke.sh | AC#10**: the three mandated `--path` cases absent (dir recursion, single file, no-edm-state-call with edm-state off PATH). Mode itself correctly implemented and read-only (edm-lint-artifacts:278-307); coverage gap only, but T43/T44 (wave B) build on --path with nothing asserting the contract. AC's own fixture path (bin/tests/fixtures/) does not exist until wave B -- target evals/fixtures/tiny-svc/ or scratch.

**[P1] EDMV3-T21 | wave7-smoke.sh | AC#3**: no case reads `allow_failure: true` for lint:file-type-ban out of .gitlab-ci.yml. T57 AC10's flip and T66 AC11's cross-check have no tripwire.

**[P1] EDMV3-T22 | .gitlab-ci.yml:100-116 | AC#3**: no total-directory-size assertion for plugins/edm/evals/. Fix: `du -sk` gate in lint:file-type-ban failing above the documented ceiling.

**[P2] EDMV3-T21 AC5 vs EDMV3-T61 AC13 -- AC contradiction (pack-level)**: T21 AC5 demands `grep -cE 'wave(3|4a|4b|5|6|7)-smoke' .gitlab-ci.yml` = 0; T61 AC13 demands `grep -n 'wave7-smoke' .gitlab-ci.yml` return a hit. Implementer resolved in T61's favour with documented reasoning (:131-136). Resolution required: pick one, amend the other's Verify with recorded rationale. Minimal: drop the :136 echo, reword :131-136/:141/:164 without the literal token, repoint T61 AC13 at run-all.sh.

**[P2] EDMV3-T19 | wave6-smoke.sh:396, wave7-smoke.sh:140,:251 | AC#8**: `grep -c 'mktemp -d'` = 5/2, AC demands 0. Both offenders create plain dirs or plugin-tree copies -- purposes with_scratch_repo (always git init) structurally cannot serve. Fix: `with_scratch_dir` sibling helper + convert the call sites, or authorized AC amendment recording the exceptions. Do not weaken the assertion.

## PASS highlights

T16: full bypass matrix verified at wave6-smoke.sh:1665-1893 incl. the product_name-hole fixture asserting empty product first (:1798). T62: all ten ACs at file:line incl. the three ACTIVE_EXEMPTION emitters (:760/:772/:782) and record_degraded_check (:796-802). T15 prose: gate at code-audit/SKILL.md:62-72 (header "Convergence", options, approve-gate gated on Approve), remediation gate stateless at :210-226, orchestrator references by name (:565-568, :590).

## Deferred to runtime (close against named evidence)

| Ticket | ACs | Closing evidence |
|---|---|---|
| T15 | AC9 | wave-A MR description before/after blocks |
| T21 | AC10, AC11 | GitLab project-settings + pipelines API responses |
| T22 | AC4, AC5 | network-disabled --provision-only; one live run-eval.sh |
| T23 | AC8, AC9, AC13 | three live baseline runs -> commit baseline/scores.json + max-min table |
| T61 | AC7-jq, AC8, AC10, AC12 | jq review record; shellcheck + bash32 job logs; macOS exception re-confirm |
| T63 | AC5, AC7, AC8-10 | commit --dry-run; template list; git log greps |
| T64 | AC9-12 | eight-row EDMV3-111 checklist; hooks.json diff; receipt+pipeline+baseline; git log |

## Observations (not findings)

- wave7-smoke.sh:397-401 comment stale (says scores.json not retained; .gitlab-ci.yml:395-399 retains it 30 days).
- CHANGELOG.md:23-26 overstates: says baseline "recorded at evals/baseline/"; only the README is there. Reword to pending framing.
- Root CLAUDE.md:54 still says edm v2.0.0 (plugin is 2.1.0).
- EDMV3's own state has no schema_version -- run `edm-state migrate-schema EDMV3` before wave-A merge (SCHEMA_VERSION_MISSING is info, does not red CI).
- T63 AC7 candidate gap: skills/code-audit/SKILL.md closure-note template lacks the ASCII-only instruction.

**Wave-A exit status**: T64 AC11 not satisfiable today -- baseline/scores.json absent. Wave A cannot close until the T23 live baseline capture lands, independent of the FAIL findings.
