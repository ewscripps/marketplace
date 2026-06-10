# Lens L10: DRY & Redundancy

Scope: `bin/edm-state` (1978 lines), `bin/edm-init`, `bin/edm-validate-prefix`, `bin/edm-lint-artifacts`, `bin/tests/*.sh`, and cross-script / cross-skill duplication. Lens = the same capability existing in 2+ places (not convention drift — that's L7; not single-site bugs — that's L1).

The high-value targets are all in the **bash scripts**, where helper extraction is both possible and worthwhile. Per `edm-ai-development/CLAUDE.md` ("Skills don't load other skills — they each contain their own orchestration"), cross-skill prose repetition is intentional and is recorded under Noted.

All line numbers refer to `plugins/edm-ai-development/bin/edm-state` unless another file is named.

## Findings

| ID | Sev | Locations (file:line × N) | Duplicated capability |
|----|-----|---------------------------|-----------------------|
| L10-01 | **P1** | edm-state:495-497, 630, 872, 913, 1094, 1268 (× 6) | "Enumerate `.edm-state.json` files" reimplemented 6×, with **3 different glob-sets** — flat-only loops silently miss product-scoped initiatives |
| L10-02 | **P1** | edm-state:264-272 (writer) vs 630-636 inline write (× 1 bypass); plus 1081, 483 | `cmd_checkpoint` hand-rolls `cat→jq→printf > "$state"`, bypassing `write_state`/`with_state_lock` — unlocked read-modify-write that diverges from the locked path |
| L10-03 | **P2** | edm-state:1292-1300 (session-start) vs 1660-1669 (handoff); +938, 899 phase-key idiom | Phase-number → display-name map duplicated; the two copies have already diverged (`0) "Not started"` present in one, absent in the other) |
| L10-04 | **P2** | edm-state:953-985 (×2 adjacent), 1128-1130, 656/665, 1697-1699 | Gate ↔ phase mapping (gate 1→phase 1, 2→3, 3→5) re-encoded in 5+ places as ad-hoc literals |
| L10-05 | **P2** | edm-state:742-753 / 762-765 (get-coverage) vs 1011-1014 / 1022-1026 (metrics-report) | Coverage-table jq renderer duplicated; the two copies use **different padding widths** (already diverged) |
| L10-06 | **P2** | bin/tests/wave3-smoke.sh:8-24, wave4a-smoke.sh:8-33, wave4b-smoke.sh:5-31 (× 3) | Test harness preamble (`SCRIPT_DIR`/`EDM_STATE`, `PASS/FAIL`, `pass`/`fail`/`check`/`check_absent`) copy-pasted; wave4b's copy has diverged |
| L10-07 | **P3** | edm-state:499-507 (cmd_list) vs 1273-1281 (cmd_session_start) (× 2) | "Seen-set" de-duplication loop copy-pasted (one keys on path, one on prefix) |
| L10-08 | **P3** | edm-state:836-838 (archive) vs 1066-1070 (migrate-path) (× 2) | Git-aware move (`git mv … 2>/dev/null \|\| mv …` inside `rev-parse --is-inside-work-tree`) duplicated |
| L10-09 | **P3** | edm-state:1762-1770 (× 9) | `"$([[ -f "$x" ]] && echo '[present]' \|\| echo '[absent]')"` repeated 9× in `write_handoff_internal` |

---

### L10-01 — State-file enumeration reimplemented 6×, with diverged layout coverage (P1)

**What's duplicated**: The "loop over every initiative's `.edm-state.json`" pattern appears in six commands. Critically, the glob-set is **not the same across copies**, so the layouts each command actually sees have silently diverged:

| Site | Function | Glob-set | Sees flat? | Sees product-scoped `SRD/*/*/`? | Sees `.archived`? |
|------|----------|----------|:---:|:---:|:---:|
| 495-497 | `cmd_list` | `*/` + `*/*/` | yes | **yes** | no |
| 1268 | `cmd_session_start` | `*/` + `*/*/` | yes | **yes** | no |
| 630 | `cmd_checkpoint` | `*/` only | yes | **NO** | no |
| 1094 | `cmd_active_initiatives` | `*/` only | yes | **NO** | no |
| 872 | `cmd_metrics_report --all` | `*/` + `.archived/*/` | yes | **NO** | yes |
| 913 | `cmd_metrics_report --calibrate` | `*/` + `.archived/*/` | yes | **NO** | yes |

**Each location (file:line)**:
- `edm-state:495-497` — `cmd_list` (flat + product-scoped, with dedup)
- `edm-state:1268` — `cmd_session_start` (flat + product-scoped, with dedup)
- `edm-state:630` — `cmd_checkpoint` (flat only)
- `edm-state:1094` — `cmd_active_initiatives` (flat only)
- `edm-state:872` — `cmd_metrics_report --all` (flat + archived)
- `edm-state:913` — `cmd_metrics_report --calibrate` (flat + archived)

**Have they diverged? (the risk)**: Yes — this is the most dangerous finding in the lens. The product-scoped layout (`SRD/{PRODUCT}/{PREFIX}__{DESCRIPTION}/`) is the documented **canonical v2.0+ layout** (per `CLAUDE.md`). Yet `cmd_checkpoint` (the Stop/PreCompact hook), `cmd_active_initiatives`, and both `metrics-report` aggregates enumerate **only the flat `SRD/*/`** layout. For any initiative created with `--product`/`--description`, the checkpoint hook will not touch `last_updated`, will not run drift detection, and will not refresh `HANDOFF.md`; `active-initiatives` will report it as nonexistent; and the metrics tables will omit it entirely. `cmd_list` and `cmd_session_start` got the two-layout treatment; the other four were left on the old single-glob form. Same intent, four different behaviors — a textbook divergent duplicate.

**Fix (extract to helper)**: Add one enumerator that is the single source of truth for "which state files exist," e.g.:

```bash
# Emits each unique state-file path, one per line, across all supported layouts.
# Pass --archived to additionally include SRD/.archived/.
list_state_files() {
  local include_archived="${1:-}"
  local globs=("$SRD_ROOT"/*/.edm-state.json "$SRD_ROOT"/*/*/.edm-state.json)
  [[ "$include_archived" == "--archived" ]] && globs+=("$SRD_ROOT"/.archived/*/.edm-state.json "$SRD_ROOT"/.archived/*/*/.edm-state.json)
  local f; local -A seen=()
  for f in "${globs[@]}"; do
    [[ -f "$f" ]] || continue
    [[ -n "${seen[$f]:-}" ]] && continue
    seen[$f]=1
    printf '%s\n' "$f"
  done
}
```

Then rewrite all six loops as `while IFS= read -r state; do … done < <(list_state_files [--archived])`. This both removes the duplication and forces every consumer onto identical layout coverage. (Note for L1: the divergence itself is also a correctness bug; flagged here because the root cause is the duplicated enumeration.)

---

### L10-02 — Unlocked inline read-modify-write in `cmd_checkpoint` bypasses `write_state` (P1)

**What's duplicated**: The canonical state mutator is `write_state` (264-272), which routes the write through `with_state_lock` (283-316, flock/mkdir advisory lock) and takes a `.bak` backup via `_write_state_body` (259-262). `cmd_checkpoint` re-implements the read-modify-write by hand instead of calling it.

**Each location (file:line)**:
- `edm-state:264-272` — `write_state` (the shared, locked writer).
- `edm-state:632-636` — `cmd_checkpoint`: `current="$(cat "$state")"; new="$(echo "$current" | jq … '.last_updated = $t')"; printf '%s\n' "$new" > "$state"` — no lock, no backup.
- (Context) `edm-state:1081` `cmd_migrate_path` and `483` `cmd_init` also write directly, but those are defensible: at those points `state_file_for` would not yet resolve the just-moved/just-created path, so the shared writer can't be used without extra plumbing. Note them, don't fault them.

**Have they diverged? (the risk)**: Yes, behaviorally. `cmd_checkpoint` is invoked from the **Stop and PreCompact hooks** — exactly the events most likely to fire concurrently with a foreground `edm-state` mutation (e.g. a `phase-complete` triggered by the same agent turn). Because the checkpoint path takes no `flock`, it can interleave with a locked writer and clobber or truncate `.edm-state.json`, and it leaves no `.bak`. Every other mutating command in the file funnels through `write_state`; this one quietly does not. It is also the only loop that both reads and writes per-iteration, so the unlocked window is per-initiative.

**Fix (extract to helper)**: Replace the inline write at 636 with the shared writer. Since the lock is keyed on the file, the cleanest form is a tiny touch helper layered on the existing primitives:

```bash
# touch_last_updated <state-file-path>  — locked, backed-up bump of last_updated.
touch_last_updated() {
  local f="$1" lockbase="${1%.json}" cur new
  cur="$(cat "$f")"
  new="$(echo "$cur" | jq --arg t "$(now_utc)" '.last_updated = $t')"
  with_state_lock "$lockbase" _write_state_body "$f" "$new"
}
```

Call it from the checkpoint loop instead of the hand-rolled `cat`/`jq`/`printf >`. (Drift detection stays read-only and is unaffected.)

---

### L10-03 — Phase-number → display-name map duplicated and already diverged (P2)

**What's duplicated**: The mapping `1→"Phase 1 - Planning"`, `2→"Phase 2 - SRD Creation"`, … `6→"Phase 6 - Implementation"` is written out as a full `case "$phase"` block twice, and a third phase-label idiom (`sub("_phase$"; "Phase ")`) lives inside the metrics jq.

**Each location (file:line)**:
- `edm-state:1292-1300` — `cmd_session_start` (`case` block; **no** `0)` arm).
- `edm-state:1660-1669` — `write_handoff_internal` (`case` block; **has** `0) "Not started"`).
- `edm-state:938` and `899` — `cmd_metrics_report` renders phase labels via jq `sub("_phase$"; "Phase ")` / `sub("_phase$"; "")`, a separate idiom for the same concept.

**Have they diverged? (the risk)**: Already diverged — the handoff copy maps phase 0 to `"Not started"`; the session-start copy has no phase-0 arm (it filters to 1-6 upstream, so the omission is currently harmless, but the two lists are maintained independently). When phase names or numbering change (e.g. an inserted Gate-3.5 compliance phase), an editor must find and update three different encodings; missing one yields inconsistent HANDOFF vs. SessionStart vs. metrics labels.

**Fix (extract to helper)**: One shell helper, `phase_name <n>`, returning the label (including the `0) Not started` arm), called from both `case` sites. The jq sites in metrics can either call it via `--arg` per row or keep the jq `sub` but at minimum the two bash `case` blocks should collapse to one helper.

---

### L10-04 — Gate ↔ phase mapping re-encoded in 5+ places (P2)

**What's duplicated**: The fixed relationship "Gate 1 gates Phase 1, Gate 2 gates Phase 3, Gate 3 gates Phase 5" (and its inverse, command → required gate) is hard-coded as literals in several independent spots rather than defined once.

**Each location (file:line)**:
- `edm-state:964-967` — jq `def gated_phase_key(g)`: `1→"1_phase"`, `2→"3_phase"`, `3→"5_phase"`.
- `edm-state:985` — adjacent inline `(if $g == 1 then 1 elif $g == 2 then 3 else 5 end)` — the *same* map, re-expressed one line away from the def above.
- `edm-state:1127-1130` — `cmd_gate_check`: command→gate (`srd|audit-srd→1`, `tickets→2`, `audit-tickets|implement→3`).
- `edm-state:656` and `665` — `cmd_checkpoint` drift messages hard-code `gate == 2` (srd) and `gate == 3` (tickets).
- `edm-state:1697-1699` — `write_handoff_internal` gate-skip flags hard-code phases 1/3/5 as the gates' feeder phases.

**Have they diverged? (the risk)**: Not yet behaviorally inconsistent, but it is a maintenance hazard with a real failure mode: if the gate/phase topology ever changes (the compliance mode already contemplates a "Gate 3.5"), these five sites must all be edited in lockstep. The two copies at 964-967 and 985 are especially egregious — the same `1/3/5` map twice within ~20 lines.

**Fix (extract to helper)**: Define the topology once. In bash, a small lookup (`gated_phase_for_gate()` / `gate_for_command()`); inside the metrics jq, define `gated_phase_key` once and derive the numeric form from it (`gated_phase_key($g) | sub("_phase$";"") | tonumber`) rather than re-listing `1/3/5`.

---

### L10-05 — Coverage-table jq renderer duplicated with diverged padding (P2)

**What's duplicated**: The jq that renders the per-layer coverage table (`coverage_by_layer | to_entries → "  <layer pad>  <pct>%<pad>  <measured_at>"`) and the per-epic table exists in both `cmd_get_coverage` and `cmd_metrics_report`.

**Each location (file:line)**:
- `edm-state:742-753` (whole-initiative) and `762-765` (per-epic) — `cmd_get_coverage`.
- `edm-state:1011-1014` (whole-initiative) and `1022-1026` (per-epic) — `cmd_metrics_report`.

**Have they diverged? (the risk)**: Yes — the percentage-column padding already differs between the two copies. `get-coverage` pads `pct<10 → 8 spaces, <100 → 7, else 6`; `metrics-report` pads `pct<10 → 9 spaces, <100 → 8, else 7`. So the same coverage data renders with different column alignment depending on which command printed it, and the `measured_at` column is present in one per-epic copy but dropped in the other. Any future column change must be made twice and the two are already out of sync.

**Fix (extract to helper)**: Move the rendering into a single jq program (a `def coverage_table:` / `def epic_coverage_table:` reused by both commands, e.g. via a shared jq snippet string or a `render_coverage` shell function that both call). Pick one padding scheme.

---

### L10-06 — Test harness preamble copy-pasted across 3 smoke tests, one diverged (P2)

**What's duplicated**: The boilerplate that every smoke test opens with — locate `edm-state`, init `PASS`/`FAIL` counters, and define `pass`/`fail`/`check`/`check_absent` — is duplicated verbatim across the three test files.

**Each location (file:line)**:
- `bin/tests/wave3-smoke.sh:8-24` — `SCRIPT_DIR`, `EDM_STATE`, `PASS/FAIL`, `pass`, `fail`, `check`.
- `bin/tests/wave4a-smoke.sh:8-33` — identical `SCRIPT_DIR`/`EDM_STATE`/`PASS/FAIL`/`pass`/`fail`/`check` plus `check_absent`.
- `bin/tests/wave4b-smoke.sh:5-31` — `PASS/FAIL`/`check`/`check_absent` only; **drops** `SCRIPT_DIR`/`EDM_STATE`/`pass`/`fail` and uses `PLUGIN_DIR` instead.

**Have they diverged? (the risk)**: Yes. wave4b's `check`/`check_absent` were re-implemented with inlined `echo "  PASS"`/`PASS=$((PASS+1))` instead of delegating to `pass`/`fail` like wave3/4a, so the success-line format and counter handling now live in two incompatible shapes. A change to test output format (or to how `edm-state` is located) must be applied in three places and the bodies have already drifted.

**Fix (extract to helper)**: Add `bin/tests/_harness.sh` defining `PASS/FAIL`, `pass`, `fail`, `check`, `check_absent`, and the `SCRIPT_DIR`/`EDM_STATE` resolution; have each smoke test `source "$(dirname "${BASH_SOURCE[0]}")/_harness.sh"`. This is test-only code, so the "skills are self-contained" rule does not apply.

---

### L10-07 — "Seen-set" de-duplication loop copy-pasted (P3)

**What's duplicated**: The array-membership-then-append idiom used to de-duplicate across the two-layout glob.

**Each location (file:line)**:
- `edm-state:499-507` — `cmd_list`, keyed on the state-file `$state` path (`seen_paths`).
- `edm-state:1273-1281` — `cmd_session_start`, keyed on `$prefix` (`seen_prefixes`).

**Have they diverged? (the risk)**: Low — the two are structurally identical bar the key. No behavioral divergence today. If L10-01's `list_state_files` helper is adopted (it dedups by path internally via an associative array), `cmd_list`'s loop disappears entirely and `cmd_session_start`'s remaining prefix-dedup becomes a 3-line associative-array check rather than a hand-rolled linear scan.

**Fix (extract to helper)**: Subsumed by L10-01. Otherwise a `seen_add <name> <value> → rc` helper backed by a bash associative array.

---

### L10-08 — Git-aware move duplicated (P3)

**What's duplicated**: "Move a directory, using `git mv` when inside a worktree and falling back to plain `mv`."

**Each location (file:line)**:
- `edm-state:836-838` — `cmd_archive` (`if git -C "$src" rev-parse --is-inside-work-tree …; then git mv … || mv …; else mv …; fi`).
- `edm-state:1066-1070` — `cmd_migrate_path` (identical structure).

**Have they diverged? (the risk)**: Low — currently identical. Maintenance hazard only: a change to the move semantics (e.g. handling `git mv` of an untracked dir, or adding `--` to guard against dash-prefixed paths) must be made in both.

**Fix (extract to helper)**: `git_aware_mv <src> <dst>` wrapping the `rev-parse` guard + `git mv || mv` + plain-`mv` fallback; call from both.

---

### L10-09 — `[present]/[absent]` ternary repeated 9× (P3)

**What's duplicated**: `s_x="$([[ -f "$path" ]] && echo '[present]' || echo '[absent]')"` for the nine artifacts in the HANDOFF Artifact Checklist.

**Each location (file:line)**: `edm-state:1762-1770` (nine consecutive lines: planning, srd, audit-srd, tickets, audit-tickets, architecture, decisions, rollback, exec-report).

**Have they diverged? (the risk)**: None — all nine are character-identical. Pure verbosity / mild maintenance smell.

**Fix (extract to helper)**: A one-line helper `present_or_absent() { [[ -f "$1" ]] && echo '[present]' || echo '[absent]'; }`, then `s_planning="$(present_or_absent "$planning_path")"` etc. Minor; bundle with any future edit to that block.

---

## Noted / Not Actionable

- **`die()` defined in all four bin scripts** (edm-state:47, edm-init:8, edm-lint-artifacts:22, edm-validate-prefix:13) — **NOTED**. These are four independent executables on PATH, not a single program; there is no sourced common library, and each `die()` intentionally carries its own `edm-state:` / `edm-init:` / etc. message prefix for diagnosability. `edm-validate-prefix`'s variant additionally takes a custom exit code (`exit "${2:-1}"`) by design. Factoring would require introducing a sourced `lib.sh`, which is a larger architectural change than the duplication warrants; the copies are tiny and have not diverged in intent.
- **`SRD_ROOT="${EDM_SRD_ROOT:-${CLAUDE_PLUGIN_OPTION_SRD_ROOT:-./SRD}}"` (and the `SRD_FILENAME`/`TICKET_PACK_DIRNAME` siblings) repeated in all four bin scripts** (edm-state:42-45, edm-init:6, edm-lint-artifacts:19-20, edm-validate-prefix:10) — **NOTED**. Same rationale: separate executables with no shared sourced file. The env-resolution lines are identical across scripts (no divergence) and are the required per-script config preamble. Worth a shared `lib.sh` only if one is introduced for other reasons.
- **PREFIX format regex `^[A-Z][A-Z0-9]{2,5}$` in edm-init:27 and edm-validate-prefix:18** — **NOTED, with a caveat**. This is *intentional* layered validation, not accidental duplication: `edm-init` calls `edm-validate-prefix` (edm-init:37-42) as the authoritative uniqueness+format check, and its own inline regex is a fast fail-early guard for the case where `edm-validate-prefix` is not on PATH. The mandate explicitly listed "PREFIX validation duplicated between `edm-validate-prefix` and inline checks in `edm-state`" as a candidate — note that `edm-state` itself does **not** contain this prefix regex (verified: the only two occurrences are in edm-init and edm-validate-prefix), so that specific suspected duplicate does not exist. Because the two copies are byte-identical and one is a documented fallback, this is not actionable; if desired, edm-init could drop its inline check and rely solely on the delegated call, but the current form is a reasonable defense-in-depth.
- **Cross-skill orchestration prose** (gate-check / phase-start / phase-complete / path-resolution preambles repeated across `skills/plan`, `skills/srd`, `skills/audit-srd`, `skills/tickets`, `skills/audit-tickets`, `skills/implement`, `skills/orchestrator`) — **NOTED / intentional**. `edm-ai-development/CLAUDE.md` is explicit: "Skills are the source of truth for orchestration … Skills don't load other skills — they each contain their own orchestration." The repeated `edm-state phase-start/phase-complete/gate-check` invocations are the required per-phase contract, not factorable shared code, and they delegate the actual logic to the single `edm-state` binary (so the real implementation is already DRY — only the *invocation* is repeated, which the plugin format mandates). No divergent copies that cause inconsistency were found across these skills. Treated as NOTED per the False-Alarm Filter.
- **`now_utc` (date `+%Y-%m-%dT%H:%M:%SZ`) vs `today` (date `+%Y-%m-%d`) — edm-state:275 vs 1586** — **NOTED**. Not a duplicated date idiom: `now_utc()` is the single timestamp helper used everywhere, and the one `date -u +"%Y-%m-%d"` at 1586 (`cmd_update_patterns`) is a deliberately *different* format (date-only, for pattern-library headings). Two different outputs, not two implementations of the same thing.
