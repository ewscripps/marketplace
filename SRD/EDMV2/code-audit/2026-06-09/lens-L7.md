# Lens L7: Cross-File Consistency — Round 2 (2026-06-09)

## Summary

The round-1 state-write convergence largely landed: `list_state_files`, `rmw_state`/`_rmw_state_body`, `phase_name_for`, `die`, and prefix validation are all single-sourced, and `with_state_lock`'s two backends now `die` identically on lock timeout (G13 fixed). However, **two sibling-convergence defects survive**, both of the exact class round-1 was supposed to eliminate:

1. **P1** — `cmd_migrate_path` is the lone mutator still on the pre-G2 unlocked `cat → echo|jq → printf > tmp` write path; all ~22 of its siblings use `rmw_state`. This is the G2/G9/G12 fix applied everywhere except here, leaving one mutating path with divergent (unsafe) failure/concurrency semantics.
2. **P2** — `skills/audit-srd/SKILL.md` carries a locally-defined **3-row** severity table (P0/P1/P2, no NOTED, no Noted/Decisions output section) — the precise "divergent local scale" G17 fixed in the `edm-srd-auditor` *agent*, surviving in the sibling skill that drives the same Phase-3 audit.

Plus two P2/cosmetic drifts: two enumerators (`cmd_list`, `cmd_session_start`) still hand-roll the both-layout glob instead of calling `list_state_files`; and `edm-audit-logic.md`'s severity one-liner omits "+ NOTED" that all 10 lens siblings carry.

## Findings

### [P1] `migrate-path` state write bypasses the locked/atomic/backup RMW path that all sibling mutators use — `bin/edm-state:1115-1120` (`cmd_migrate_path`) vs `bin/edm-state:320-327` + every other mutator

**Evidence:** Every mutating subcommand routes its write through `rmw_state "$prefix" '<filter>' …`, which acquires `with_state_lock`, re-reads inside the lock, writes via temp-file+`mv` (`_rmw_state_body:310-315`), and makes a `.bak`. `cmd_migrate_path` alone still does the pre-G2 pattern (`cat` → `echo|jq` → `printf > tmp && mv`), with **no `with_state_lock`** and **no `.bak`** (it picked up only the temp+mv half of the fix). It is the only `cmd_*` that mutates state without `rmw_state` (grep confirms 23 mutators on `rmw_state` and this one on the literal `printf` write).

**Why it matters:** Same defect class as round-1 G2/G3/G12, and G12's own remediation explicitly says to route the post-move update through `rmw_state`. A `migrate-path` running concurrently with a `Stop`/`PreCompact` `checkpoint-if-active` (now locked) on the just-moved file can lose the checkpoint's write or interleave with it, and unlike all siblings leaves no `.bak`. Divergent failure semantics on a mutating path is P1.

**Suggested fix:** Replace lines 1114-1120 with `rmw_state "$prefix" '.product_name = $p | .initiative_description = $d | .last_updated = $t' --arg p "$product" --arg d "$description" --arg t "$(now_utc)"`.

### [P2] Divergent local severity scale survives in the audit-srd skill — `skills/audit-srd/SKILL.md:65-69` + `:89-96` vs `agents/edm-srd-auditor.md:65-70` + `:99`

**Evidence:** The `edm-srd-auditor` agent was fixed under G17 to a 4-row table (P0/P1/P2/**NOTED**) plus a `## NOTED` output section. The **skill** that drives the identical Phase-3 audit still defines its own inline 3-row table (P0/P1/P2, no NOTED, no canonical reference) and its output skeleton has only `## P0`/`## P1`/`## P2` + `## Remediation`. The sibling `skills/audit-tickets/SKILL.md` does NOT restate a scale (it delegates), so audit-srd is the outlier.

**Why it matters:** CLAUDE.md: "No agent may define a divergent local scale." A 3-row inline table is exactly that, and now the agent and its driving skill disagree on severity vocabulary for the same audit. Round-1 G17 caught this in the agent but its Files list named only the two agent `.md` files, missing the skill.

**Suggested fix:** Replace the inline 3-row table at audit-srd SKILL:65-69 with a pointer to the canonical scale (or add the NOTED row) and add a `## NOTED` section to the output skeleton.

### [P2] Two enumerators still hand-roll the both-layout glob instead of `list_state_files` — `bin/edm-state:534-545` (`cmd_list`) and `:1303` (`cmd_session_start`)

**Evidence:** G1/G18 added `list_state_files()` and routed three enumerators through it, but `cmd_list` and `cmd_session_start` were left on their own inline two-glob + seen-array dedup. The both-layout logic now exists in **three** places.

**Why it matters:** Maintenance/DRY hazard, not a current bug — both hand-rolled loops use the correct two-glob form. But the next extension of `list_state_files` will update 4 of 6 enumerators and silently leave these two behind, re-introducing the G1 split.

**Suggested fix:** Replace both inline loops with `while IFS= read -r state; do … done < <(list_state_files)` (keep `cmd_session_start`'s prefix-dedup in the body).

### [P2] `edm-audit-logic` severity one-liner omits "+ NOTED" that all sibling lenses carry — `agents/edm-audit-logic.md:55`

**Evidence:** Ten of eleven `edm-audit-*` lenses write "Use the canonical severity scale (**P0/P1/P2 + NOTED**)…". `edm-audit-logic.md:55` instead writes "P0 / P1 / P2 -- use the canonical scale…" (omits "+ NOTED", different shape). It does still carry the `## Noted / Not Actionable` section, so only the one-liner drifts. Round-1 L7-04 (folded into G22), not applied to this line.

**Suggested fix:** Match the sibling wording.

## Round-1 fix verification (L7)

**G17 (NOTED severity implemented three ways) — PARTIAL.** `edm-srd-auditor.md:65-70` now 4-row + `## NOTED` (`:99`) — agent fixed (residual nit: `description:` at `:4` still "(P0/P1/P2)"). `edm-ticket-auditor.md:73,114` fixed. All 11 lenses + synthesizer consistent except `edm-audit-logic.md:55` one-liner drift. `edm-qc-auditor` omits NOTED — intentional PASS/PARTIAL/FAIL paradigm (documented). PARTIAL because G17 missed the sibling `skills/audit-srd/SKILL.md` 3-row table (P2 finding).

**G13 (flock vs mkdir divergence) — CONFIRMED FIXED.** Both branches `die` on timeout; neither silently no-ops. (Note: L2/L3 flag a cosmetic residual — flock branch aborts at exit 99 under `set -e` before reaching the `die` — graded P2 there.)

**G1/G18 enumerator convergence — MOSTLY FIXED** (two hand-rolled holdouts, P2 finding). **G2/G3/G9 locked-RMW convergence — MOSTLY FIXED** (single un-converged mutator `cmd_migrate_path`, P1 finding).

## Noted / Not Actionable

- `test-coverage` skill `sonnet/high` vs sibling `test`/`test-plan` `opus` — skill model governs the orchestrating conversation; `test-coverage` is a thin wrapper spawning the opus/max `edm-test-coverage-auditor`. Plausibly intentional, undocumented. NOTED.
- `set-supersedes`/`set-forked-from` validate non-empty only, while `set-parent`/`add-related` validate the target exists — documented asymmetry (provenance link vs live link). NOTED.
- `edm-qc-auditor` omits NOTED row — intentional verdict paradigm. NOTED.
- `audit-tickets` skill has no severity table — the correct direction (delegate); audit-srd is the outlier.
- Skill frontmatter uniformity — all 13 share identical key order, `disable-model-invocation: true`, scoped `Bash(edm-state *)`. Consistent. No finding.
