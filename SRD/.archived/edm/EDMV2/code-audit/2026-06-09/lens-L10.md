# Lens L10: DRY & Redundancy — Round 2 (2026-06-09)

## Summary

The Round-1 DRY remediation (G18, G1, G24) **partially landed but left several stale duplicates and live divergences behind** — a textbook remediation regression. Three of the four G18 sub-items are NOT single-sourced, and one is fully unfixed:

- **G18(a) phase-name map** — CONFIRMED FIXED (true single source).
- **G18(c) coverage-table renderer** — REGRESSED: still duplicated AND still diverged on padding (the exact hazard the finding was filed to kill). **P2.**
- **G18(d) test-harness preamble** — REGRESSED: the promised `_harness.sh` was never created; all four smoke tests still copy-paste `pass`/`fail`/`check`/`check_absent`, and `wave4b` is incompatibly divergent. **P2.**
- **G18(b) gate↔phase map** — essentially UNFIXED: topology still re-encoded as literals in 5+ spots, including a self-duplication inside a single jq block. **P2.**
- **G1 enumerator** — PARTIAL: 4 of 6 enumerators route through `list_state_files`, but `cmd_list` and `cmd_session_start` retain their own hand-rolled glob+dedup loops. **P2.**
- **G24 seen-set / git-aware-mv / present-or-absent idioms** — UNFIXED (mostly cosmetic). **P2.**

The most serious NEW finding: the **atomic-write idiom was copy-pasted into `cmd_migrate_path` instead of routed through `rmw_state`**, and that copy is **unlocked and skips the `.bak` backup** — a divergent duplicate on the critical state-write path, and a direct miss of the Round-1 G12 fix. **P1.**

The skills do NOT duplicate `edm-state` logic in executable form — they delegate to the binary. Gate/phase repetition in skill markdown is methodology prose (NOTED).

## Findings

### [P1] `cmd_migrate_path` re-implements the atomic-write idiom unlocked + un-backed-up instead of using `rmw_state` — `bin/edm-state:1114-1120` vs canonical `:308-327` + `:293-296`

**Evidence:** The atomic write `printf … > "${f}.tmp.$$" && mv -f "${f}.tmp.$$" "$f"` exists in exactly three places — the two canonical helpers and one hand-rolled copy in migrate-path (`:1114-1120`). The canonical `_rmw_state_body` (`:310-315`) does the same tmp+mv but **additionally** takes the advisory lock (via `rmw_state` → `with_state_lock`) and makes the `cp -p .bak` backup. `cp -p .bak` appears ONLY at `:294` and `:313` — so the migrate-path write at `:1120` is the one mutating write in the whole file that produces no backup, and reads outside any lock.

This is identical to round-1 G3 (`cmd_checkpoint`'s unlocked `cat→jq→printf>`, remediated) and is the literal target of G12 ("Route the post-move state update through `rmw_state` … instead of `printf > "$new_state_file"`") — that instruction was not carried out.

**Why it matters:** (1) Correctness/safety: every other mutator serializes through `with_state_lock` and leaves a `.bak`; this one diverges, so a concurrent writer or a crash mid-`mv` during migration loses the backup safety net (and re-opens the G2/G3 race window). (2) DRY: a third copy of the write primitive that will not inherit future fixes to `_rmw_state_body` — the divergence is where the next bug hides.

**Suggested fix:** Replace the manual block with `rmw_state "$prefix" '.product_name=$p|.initiative_description=$d|.last_updated=$t' --arg p "$product" --arg d "$description" --arg t "$(now_utc)"` (the move has happened, so `state_file_for` resolves the new path).

### [P2] Coverage-table jq renderer still duplicated AND diverged on padding — `bin/edm-state:780` vs `:1050`; `:794` vs `:1062`

**Evidence:** G18(c) was filed because the coverage table is rendered in both `get-coverage` and `metrics-report` with different padding. The duplicate still exists and is still diverged: the whole-initiative layer row pads pct 8/7/6 in `get-coverage` (`:780`) vs 9/8/7 in `metrics-report` (`:1050`), and the key column has a negative-clamp guard in one copy but not the other. The per-epic block is likewise duplicated (`:794` vs `:1059-1062`), and the header strings are duplicated. No shared `def render_coverage` exists; the G18(c) fix was not implemented.

**Suggested fix:** Extract one jq `def coverage_table` (and per-epic) or a `render_coverage` shell function called from both commands; pick one padding scheme (the clamped form at `:1050`).

### [P2] Test-harness preamble never extracted — `_harness.sh` absent; preamble copy-pasted 4× and `wave4b` diverged — `bin/tests/wave3:11-24`, `wave4a:11-33`, `wave5:9-31`, `wave4b:7-30`

**Evidence:** G18(d) promised `bin/tests/_harness.sh` defining the shared counters/asserts; no such file exists. All four tests define their own `PASS`/`FAIL` and `check`/`check_absent`, diverged into **two incompatible families**: wave3/4a/5 use `[[ "$actual" == *"$expected"* ]]` with signature `check <label> <expected> <actual>`; wave4b uses `grep -qF "$pattern"` with reordered signature `check <label> <pattern> <content>`. The 3rd positional arg means different things and the match semantics differ (glob-substring vs fixed-string grep).

**Why it matters:** Test-only (no prod impact) but genuine copy-paste-with-divergence: a fix to one harness doesn't reach the others, and the two incompatible `check` contracts trap the next test author.

**Suggested fix:** Create `bin/tests/_harness.sh`; `source` it from all four; reconcile onto one `check` contract (the glob-substring form used by 3 of 4).

### [P2] Gate↔phase topology still re-encoded as literals in 5+ spots, incl. a self-duplication inside one jq block — `bin/edm-state:1001-1005`, `:1022`, `:1690-1692`, `:691`, `:701`

**Evidence:** G18(b) was filed because "gate 1→phase 1, 2→3, 3→5" is re-encoded in many places. No helper was added. The topology is still scattered and now duplicated *within a single jq invocation*: `:1001-1005` defines `gated_phase_key(g)` (gate→phase-key string), and `:1022` re-derives the SAME mapping as a number (`if $g==1 then 1 elif $g==2 then 3 else 5`). Plus gate→feeding-phase in HANDOFF skip flags (`:1690-1692`) and artifact→gate in the drift handler (`:691`,`:701`).

**Why it matters:** The upcoming "Gate 3.5" compliance work requires editing each site in lockstep, and the `:1001` vs `:1022` pair can silently disagree. Maintainability-grade, P2 — but unambiguously unfixed.

**Suggested fix:** Add `gated_phase_for_gate()` and derive both the `N_phase` key and skip-flag checks from it; in the metrics jq, derive `$gated_phase_num` from `gated_phase_key` instead of the parallel literal.

### [P2] `cmd_list` and `cmd_session_start` retain hand-rolled enumeration+dedup instead of `list_state_files` — `bin/edm-state:534-545`, `:1303-1316` vs helper `:53-71`

**Evidence:** G1 added `list_state_files` and required all six enumerators to route through it; four do, but `cmd_list` and `cmd_session_start` still inline the dual-glob loop + linear seen-array. The seen-array dedup idiom exists three times. (G24/L10-07 item, supposed to be folded in.)

**Why it matters:** Lower severity — all three cover both layouts today, so no behavioral gap. But it is the same latent-divergence surface G1 closed; `cmd_session_start`'s prefix-dedup vs `list_state_files`'s path-dedup is already a subtle difference.

**Suggested fix:** Convert `cmd_list` to `while IFS= read -r state; do … done < <(list_state_files)`; for `cmd_session_start` keep the prefix-dedup wrapper over the helper.

### [P2] `git mv … || mv` and the `[present]/[absent]` ternary still duplicated — `bin/edm-state:866-868` & `:1105-1106`; `:1755-1763` (×9)

**Evidence:** The git-aware move block is identical in `cmd_archive` (`:866-868`) and `cmd_migrate_path` (`:1105-1106`); the present/absent ternary is repeated nine times verbatim at `:1755-1763`. (G24 L10-08/L10-09 helpers `git_aware_mv`/`present_or_absent`, not extracted.)

**Why it matters:** Purely maintainability — no divergence yet. G24 rated these "fold in if touching"; the migrate-path block IS being touched by the P1 fix, so `git_aware_mv` extraction is now low-effort.

**Suggested fix:** Extract `git_aware_mv()` (both move sites) and `present_or_absent()` (nine `s_*` assignments).

## Round-1 fix verification (L10)

| Item | Status | Location |
|---|---|---|
| **G18(a)** phase-name map | **CONFIRMED FIXED** — single `phase_name_for` (with `0) Not started`), both call sites | def `:74-85`; callers `:1327`,`:1662` |
| **G18(b)** gate↔phase map | **REGRESSED / UNFIXED** — no helper; topology literal in 5+ spots, self-dup within one jq block | `:1001-1005`,`:1022`,`:1690-1692`,`:691`,`:701` |
| **G18(c)** coverage-table renderer | **REGRESSED** — two copies, diverged padding (8/7/6 vs 9/8/7) + clamp guard; no shared def | `:780` vs `:1050`; `:794` vs `:1062` |
| **G18(d)** test-harness preamble | **REGRESSED** — `_harness.sh` absent; copy-pasted 4×; `wave4b` incompatibly divergent | no `_harness.sh`; `wave3:11-24` etc. |
| **G1** both-layout enumerator | **PARTIAL** — helper used by 4 of 6; `cmd_list`/`cmd_session_start` hand-rolled | `:53-71`; holdouts `:534-545`,`:1303-1316` |
| **G24** three idioms | **UNFIXED** — seen-set dup, `git_aware_mv` dup, `present_or_absent` ×9 | `:534-545`/`:1303-1316`; `:866-868`/`:1105-1106`; `:1755-1763` |

## Noted / Not Actionable

- Skills do not duplicate `edm-state` logic — they shell out to the binary. Correct delegation. NOTED.
- Gate/phase tables in `skills/orchestrator/SKILL.md` — methodology documentation, expected repetition. NOTED.
- `docs/audit-patterns/code-audit.md` (modified in git status) — a knowledge corpus the audit consumes, not duplicated program logic. NOTED.
- `cmd_set` numeric/boolean validation regexes recurring in approve-gate/record-*/current-step/skip-phase — short, field-specific input guards (G10), co-located, not one extractable utility without losing the field message. NOTED.
- The tmp+mv idiom in `_write_state_body` vs `_rmw_state_body` — two intentional canonical primitives sharing the line; both locked + backed-up. The *third* copy (migrate-path) is the only problem. NOTED.
- Per-epic coverage layer-column padding `(14 - length | clamp)` agrees across the two per-epic copies; only the whole-initiative copies diverge. Folded into the single G18(c) finding. NOTED.
