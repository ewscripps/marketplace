# Lens L1: Logic, Correctness & Completeness — Round 2 (2026-06-09)

## Summary

All five round-1 L1 fixes (G1, G4, G8, G20, G21) are present in the live code. Four are fully correct. **G8 is only partially fixed**: the per-phase Savings column and the `--all` Cost Ratio column were correctly changed to require `human_baseline > 0` before rendering a multiplier, but the headline **Total Savings** line in the single-initiative report was not — it still guards only the divisor (`$tc > 0`), so a zero human baseline still prints the misleading `0x cheaper` rather than `n/a`. This reproduces against the live `SRD/EDMV2/.edm-state.json`.

No new P0 or P1 logic defects found. The `edm-state` rewrite (the `list_state_files` enumerator, `rmw_state`/`_rmw_state_body` locked-RMW primitive, the coverage-table and metrics jq filters, `phase_name_for`, the gate-review jq `def`s) is logically sound, bash-3.2-safe, and free of stubs/TODO/NotImplementedError. The one finding below is P2 (does not block convergence) and is a residual of an already-tracked finding rather than a new defect.

## Findings

### [P2] G8 incompletely fixed — Total Savings line still prints `0x` for a zero human baseline — `bin/edm-state:985-986`

**Evidence:**
```jq
"  Total: \($ts)s  |  Claude: $\($tc)  |  Human baseline: $\($th)  |  Savings: " +
  (if $tc > 0 then "\(($th / $tc) | tostring | .[0:6])x cheaper" else "n/a" end)
```
The guard is `$tc > 0` (total Claude cost / the divisor). It does not require `$th > 0` (total human baseline / the numerator). Compare the two sibling expressions in the same command that G8 *did* fix to guard both operands:
- per-phase row, `:975`: `if ($v.estimated_cost_usd // 0) > 0 and ($v.human_baseline_usd // 0) > 0 then … else "n/a" end`
- `--all` Cost Ratio, `:913`: `if .total_claude > 0 and .total_human > 0 then … else "n/a" end`

Live repro: `SRD/EDMV2/.edm-state.json` has `estimated_size: "Unknown"` (the `cmd_init` default at `:499`), so every `human_baseline_usd` is `0.00` while phases 1-5 carry nonzero `estimated_cost_usd` (sum `$tc ≈ 30.45 > 0`, `$th = 0`). `metrics-report EDMV2` therefore prints the per-phase rows as `n/a` (fixed) but the footer as `… Human baseline: $0  |  Savings: 0x cheaper` — the exact "AI saved nothing" inversion G8 set out to remove, now surviving only in the headline line a reader is most likely to quote.

**Why it matters:** The savings figure is the user-facing headline of `/edm:metrics`. `0x cheaper` is the literal inverse of the intended message and is inconsistent with the per-phase and aggregate rows directly above/around it, so the same report contradicts itself. The QC artifact `SRD/EDMV2/qc/EDMV2-T04-T10.md` (AC-4/AC-5) establishes `n/a` as the canonical presentation when a ratio is not meaningfully computable, so this is not documented-intentional.

**Suggested fix:** Add the numerator guard, mirroring the sibling expressions:
```jq
(if $tc > 0 and $th > 0 then "\(($th / $tc) | tostring | .[0:6])x cheaper" else "n/a" end)
```

## Round-1 fix verification (L1)

- **G1** (layout-glob omission) — CONFIRMED FIXED. All six enumeration call sites route through `list_state_files`: `cmd_checkpoint` (`:716`), `cmd_active_initiatives` (`:1143`), `cmd_metrics_report --all` (`:915`) and `--calibrate` (`:926`), with `--archived` passed only by the two metrics aggregates. `list_state_files` (`:53-71`) globs both `SRD/*/` and `SRD/*/*/` (plus `.archived/*/` and `.archived/*/*/` when `--archived`), dedups via a bash-3.2-safe linear seen-array, and guards unexpanded globs with `[[ -f ]]`. `cmd_list` (`:534-536`) and `cmd_session_start` (`:1303`) retain their own equivalent two-glob+dedup loops.
- **G4** (`get-coverage` "Tests Added by Phase" iterate-over-string) — CONFIRMED FIXED. `bin/edm-state:805-813` no longer has the trailing `| .[] // .`; the filter ends at `end`, uses `if length == 0 then empty`, and the command ends with `2>/dev/null || true` (`:813`) + `return 0` (`:814`), so success exit is 0 and the section renders when `tests_added > 0`.
- **G8** (misleading `0x` when `human_baseline_usd == 0`) — PARTIALLY FIXED / REGRESSED in one spot. Per-phase row (`:975`) and `--all` Cost Ratio (`:913`) now print `n/a`; the single-initiative **Total** line (`:985-986`) still prints `0x`. See finding above.
- **G20** (`1Phase` label) — CONFIRMED FIXED. `bin/edm-state:974` builds the label as `("Phase " + ($k | sub("_phase$"; "")))` → `Phase 1`. (`phase_name_for` at `:74-85` is the consistent renderer elsewhere.)
- **G21** (heading skip-list prefix over-match) — CONFIRMED FIXED. `bin/edm-state:1600-1601` matches exact whole-heading names `"summary"|"findings"|"recommendations"|"overview"|"appendix"|"legend"` (quoted, no `*`), so a finding titled "Summary of …" is kept.

## Noted / Not Actionable

- **`phase_complete_epoch($s; key)` uses an unquoted `key` filter parameter** (`bin/edm-state:1009-1016`) — intentional jq call-by-name; bound to a string literal (`$pk`) at the call site and verified correct in round-1 (gate-review times reproduced: 2885s/15921s/4420s). Not a defect.
- **`cmd_migrate_path` post-move state write is a direct `printf > tmp && mv`, not `rmw_state`** (`:1116-1120`) — bypasses the lock/backup, but this is the round-1 **G12** finding (P2, L3+L8), out of L1's mandate and already tracked; no new L1 logic error (the jq merge itself is correct and inputs are validated at `:1090-1091`).
- **`record-task-duration` returns 0 with no accumulation** (`:719-724`) — explicitly documented reserved no-op (header `:13`, in-body comment, CLAUDE.md, CHANGELOG); not a stub masquerading as complete. NOTED (carried from round-1).
- **`cmd_init` writes `estimated_size: "Unknown"`** (`:499`) — the root cause feeding G8's zero baseline, but it is the intended safe default (the `SIZE_UNKNOWN` anomaly in `state_anomalies` at `:425-428` nudges the user to set a real size); the fix belongs in the metrics render path (the G8 finding), not here. NOTED.
- **`compute_cost_usd` `*sonnet*|*` catch-all, `--calibrate` upper-middle "median", `group_by(.size+"_"+.phase)` key join, coverage column-width `(15 - length | clamp)`** — all re-verified intentional/correct in round-1's L1 "Noted" section; unchanged in the rewrite. NOTED.

Relevant files: `plugins/edm-ai-development/bin/edm-state` (the one finding is at lines 985-986).
