# QC Report: EDMV2-T03 and EDMV2-T09

**Date verified**: 2026-06-08
**Plugin version**: edm-ai-development-staging (working toward v2.0.0)
**Verified by**: Phase 6 implementation agent (EDMV2 Wave 1c)

---

## EDMV2-T03: Reconcile /edm:metrics skill claims with metrics-report implementation

### What was changed

`skills/metrics/SKILL.md` — three sections edited:

**Mode 1 (lines ~29-32 before, ~29-32 after):**
- Removed: "Comparison column against the Phase Timing Guidelines for the recorded `estimated_size`"
- Removed: "Highlights any phase that ran > 1.5× the expected duration"

**Mode 2 bullet list replaced entirely:**
- Before: "Mean / median / p95 per phase", "Top 3 bottleneck phases (...)", "Initiatives where total gate-review time exceeded total execution time (...)"
- After: accurate description of the `--all` table output (one row per initiative: prefix, size, total time, Claude cost, human cost, cost ratio)

**Mode 3 bullet list replaced:**
- Before: "For each (size, phase), the team's median duration", "Compared against the current guidelines", "Recommended new guideline value"
- After: "For each (size, phase) combination: sample count, median duration in seconds, median Claude cost" — matches the actual jq output in `cmd_metrics_report --calibrate`

### AC Verdict

| AC | Description | Result |
|----|-------------|--------|
| AC-1 | Every metric named in SKILL.md maps to a code path in `cmd_metrics_report` | PASS — Mode 1 now lists only: duration, gate review time, total time (all printed by the single-PREFIX case). Mode 2 lists the six columnar fields (initiative, size, total time, claude cost, human cost, cost ratio) matching the `printf` in `--all`. Mode 3 lists count/median-duration/median-cost matching the jq `--calibrate` output. |
| AC-2 | `gate_review_seconds` references remain (T04 will implement) | PASS — line 62: "The `gate_review_seconds` field separates 'human waiting on review' from 'Claude executing the phase.'" is untouched. |
| AC-3 | The p95 claim removed; no surviving text advertises p95 | PASS — `grep -n "p95" skills/metrics/SKILL.md` returns nothing. |
| AC-4 | Bottleneck-highlighting claims removed; no surviving text advertises bottleneck detection | PASS — `grep -n "bottleneck" skills/metrics/SKILL.md` returns nothing. |
| AC-5 | Guideline-comparison claim removed; no surviving text advertises guideline comparison | PASS — `grep -n "Comparison column" skills/metrics/SKILL.md` returns nothing. |
| AC-6 | Mode 1/2/3 descriptions match what the implementation actually prints | PASS — Mode 1 matches the single-PREFIX jq+printf block (lines 604-627 of bin/edm-state). Mode 2 matches the `--all` printf block (lines 548-565). Mode 3 matches the `--calibrate` jq output (lines 573-592). |
| AC-7 | `grep -n "p95\|bottleneck\|Comparison column\|exceeded total execution"` over the file returns nothing | PASS — verified: command returns no output. |
| AC-8 | No metric is silently added to bin/edm-state in this ticket | PASS — bin/edm-state was not touched in this ticket. |

---

## EDMV2-T09: Route SRD versioning through the srd-version subcommand

### What was changed

**`skills/srd/SKILL.md` — step 5 of Operational Orchestration:**
- Before: `After both complete, verify the SRD file. Set \`srd_version\` in \`.edm-state.json\` to \`1.0.0\`.`
- After: `After both complete, verify the SRD file. \`edm-state srd-version <PREFIX> 1.0.0\``

**`skills/audit-srd/SKILL.md` — step 6 of Operational Orchestration:**
- Before: `Update \`srd_version\` in \`.edm-state.json\`: \`edm-state set <PREFIX> srd_version 1.1.0\``
- After: `Update \`srd_version\` in \`.edm-state.json\`: \`edm-state srd-version <PREFIX> 1.1.0\``

**`bin/edm-state`** — not modified.

### AC Verdict

| AC | Description | Result |
|----|-------------|--------|
| AC-1 | `skills/srd/SKILL.md` sets SRD version via `edm-state srd-version <PREFIX> <version>` | PASS — step 5 now reads: `` `edm-state srd-version <PREFIX> 1.0.0` `` |
| AC-2 | `skills/audit-srd/SKILL.md` sets SRD version via `edm-state srd-version <PREFIX> <version>` | PASS — step 6 now reads: `` `edm-state srd-version <PREFIX> 1.1.0` `` |
| AC-3 | `grep -rn 'set .*srd_version' skills/` returns nothing | PASS — verified: command returns no output. |
| AC-4 | The versioning step updates `srd_version` in `.edm-state.json` | PASS — `cmd_srd_version` at bin/edm-state:477-487 writes `.srd_version = $v` via jq into the state file. |
| AC-5 | The same invocation refreshes `HANDOFF.md` (via srd-version's handoff-refresh side effect) | PASS — `cmd_srd_version` calls `write_handoff_internal "$prefix"` at line 486 unconditionally after writing state. |
| AC-6 | The `cmd_srd_version` subcommand behavior at bin/edm-state is unchanged by this ticket | PASS — bin/edm-state was not modified; `cmd_srd_version` remains identical at lines 477-487. |

---

## Summary

Both tickets PASS all acceptance criteria.

- **T03**: Three false-claim sections removed from `skills/metrics/SKILL.md`. All three modes now accurately describe what `cmd_metrics_report` actually computes and prints. The `gate_review_seconds` interpretation note is preserved for T04. No changes to `bin/edm-state`.
- **T09**: Both skill files updated to call `edm-state srd-version <PREFIX> <version>` instead of `edm-state set <PREFIX> srd_version <version>`. This routes through `cmd_srd_version` which sets the version and refreshes `HANDOFF.md`. No changes to `bin/edm-state`.
