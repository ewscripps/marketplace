# Lens L1: Logic, Correctness & Completeness

Audit of the EDM Claude Code plugin v2.0.0 (EDMV2) bash logic prior to deployment over installed v1.3.0.
Scope: `bin/edm-state`, `bin/edm-init`, `bin/edm-validate-prefix`, `bin/edm-lint-artifacts`.
All findings below were reproduced empirically (jq filters executed against the real `SRD/EDMV2/.edm-state.json`
and synthetic fixtures; bin scripts run end-to-end against a scratch `SRD/` tree).

## Findings

| ID | Sev | File:Line | Issue |
|----|-----|-----------|-------|
| L1-01 | P1 | edm-state:630 | `cmd_checkpoint` (Stop/PreCompact hook) globs flat layout only — product-scoped initiatives get no drift detection, no `last_updated` touch, no HANDOFF/Resume-Point refresh |
| L1-02 | P1 | edm-state:775-784 | `cmd_get_coverage` "Tests Added by Phase" jq filter ends with `.[] // .` over a string → `jq: Cannot iterate over string`; section never renders and command exits 5 |
| L1-03 | P1 | edm-state:1094 | `cmd_active_initiatives` globs flat layout only — violates EDMV2-T35 AC1 ("lists all initiatives whose directory exists"); product-scoped active initiatives are invisible |
| L1-04 | P1 | edm-state:872, 913 | `cmd_metrics_report --all` and `--calibrate` glob flat + archived only — product-scoped (canonical v2.0) initiatives are omitted from all aggregate metrics/calibration |
| L1-05 | P2 | edm-state:581, 234-247 | Savings ratio prints a misleading `0x` (and `Cost Ratio 0x`) whenever `human_baseline_usd == 0`; the `// "Medium"` default in `cmd_phase_complete` is dead because `edm-state init` writes `estimated_size: "Unknown"` (a non-null string) |
| L1-06 | P2 | edm-state:699, 706, 722, 532 | `record-test-coverage` / `record-tests-added` / `approve-gate` pass user args to `--argjson` with no numeric validation → raw `jq: invalid JSON text` crash (vs. `cmd_set`'s friendly `die`) |
| L1-07 | P3 | edm-state:938 | Phase label renders as `1Phase` instead of `Phase 1` — `sub("_phase$";"Phase ")` replaces the suffix, leaving the digit in front |
| L1-08 | P3 | edm-state:1577-1620 | `cmd_update_patterns` heading skip-list (`summary*|findings*|...`) is a prefix match, so a real finding titled e.g. "Summary of auth bypass" is silently dropped from the pattern library |

---

### L1-01 — Checkpoint hook skips product-scoped initiatives (P1)

**Problem.** `cmd_checkpoint` is the target of the `Stop` and `PreCompact` hooks (CLAUDE.md "Hooks behavior"; SRD `:828`, `:841-842`). Its loop iterates `"$SRD_ROOT"/*/.edm-state.json` — the flat layout only. For an initiative in the canonical v2.0 product-scoped layout (`SRD/{PRODUCT}/{PREFIX}__{DESC}/.edm-state.json`), the loop never matches, so on every Stop/PreCompact: (a) drift detection (SRD vs. on-disk hash) never runs, (b) `last_updated` is never refreshed, and (c) `write_handoff_internal` (which also refreshes the Resume Point — the WS-N compaction-resilience feature) is never called. The checkpoint mechanism is effectively dead for the layout the SRD designates canonical.

**Evidence (edm-state:630).**
```bash
  for state in "$SRD_ROOT"/*/.edm-state.json; do
```
Compare `cmd_list` (`:495-497`) and `cmd_session_start` (`:1268`), which correctly scan both layouts:
```bash
  for state in "$SRD_ROOT"/*/.edm-state.json "$SRD_ROOT"/*/*/.edm-state.json; do
```
Reproduced: a product-scoped state at `SRD/edm/EDMV2__demo/.edm-state.json` (phase 4) after `edm-state checkpoint-if-active`:
```
FLAT HANDOFF written:  YES
EDMV2 HANDOFF written: NO   <-- product-scoped skipped
EDMV2 last_updated still 2026-06-08T00:00:00Z (never touched)
```

**Fix.** Add the product-scoped glob to the loop (mirror `:1268`):
`for state in "$SRD_ROOT"/*/.edm-state.json "$SRD_ROOT"/*/*/.edm-state.json; do`. The de-dup pattern from `cmd_session_start` should be carried over to avoid double-processing when a flat path also matches.

**Severity rationale.** P1: a hook-driven safety/continuity feature (drift detection + Resume-Point freshness) is entirely non-functional for the canonical layout the rest of v2.0 steers users toward. Silent — no error surfaces.

---

### L1-02 — `get-coverage` "Tests Added by Phase" filter always errors (P1)

**Problem.** The final jq block in `cmd_get_coverage` builds a string (or comma-separated stream of strings) in its `if/else`, then pipes to `.[] // .`. `.[]` cannot iterate a string, so jq aborts with `Cannot iterate over string` (exit 5) in both the empty and the populated case. The error is swallowed by `2>/dev/null || echo "(no coverage data)"`, so the "Tests Added by Phase" section silently never appears even when `tests_added` data exists — and `get-coverage` returns exit 5, which can break any caller that checks its status.

**Evidence (edm-state:775-784).**
```bash
  jq -r '
    [.phase_durations | to_entries[] | {phase: .key, tests: .value.tests_added, by_layer: .value.tests_by_layer}] |
    map(select(.tests != null and .tests > 0)) |
    if length == 0 then ""
    else
      "# Tests Added by Phase\n",
      (.[] | "  \(.phase): \(.tests) total  \(.by_layer // {} | to_entries | map("\(.key)=\(.value)") | join(", "))")
    end |
    .[] // .
  ' "$state" 2>/dev/null
```
Reproduced: after `record-tests-added FLAT 6 unit 5` + `... integration 3` (state shows `tests_added: 8`), `get-coverage FLAT` exits 5 and prints no "Tests Added by Phase" section.

**Fix.** Remove the trailing `| .[] // .` (the `if/else` already emits a stream of strings that `jq -r` prints line-per-line). If a guaranteed-non-empty output is wanted, replace the whole tail with a plain string join, e.g. accumulate into a single string and emit it, or drop the `2>/dev/null` so the error is at least visible during development.

**Severity rationale.** P1: a documented feature (CLAUDE.md: "`get-coverage` … Print coverage summary"; `phase_durations[N].tests_added`) produces no output and returns a failing exit code. The `2>/dev/null` masks it, so it would ship unnoticed.

---

### L1-03 — `active-initiatives` skips product-scoped initiatives (P1)

**Problem.** `cmd_active_initiatives` loops flat-only. EDMV2-T35 AC1 (tickets epic 02, `:429`) requires it to list "all initiatives whose directory exists, is NOT under `.archived/`, and whose `current_phase` is in 1-6", and the design note (`:439`) says it "reuses the `cmd_list` glob pattern". `cmd_list` was updated to scan both layouts; `cmd_active_initiatives` was not. The orchestrator runs `active-initiatives` on every phase start to warn about multiple concurrent initiatives (AC3) — that multi-active guard misses product-scoped ones.

**Evidence (edm-state:1094).**
```bash
  for state in "$SRD_ROOT"/*/.edm-state.json; do
```
Reproduced: with one flat (FLAT, phase 3) and one product-scoped (EDMV2, phase 4) active initiative:
```
=== active-initiatives ===
  FLAT          phase=3  ...
(EDMV2 missing)
=== list ===   (correctly shows both)
  FLAT  ...
  EDMV2 ...
```

**Fix.** Same as L1-01: extend the glob to include `"$SRD_ROOT"/*/*/.edm-state.json` and de-dup by prefix (reuse the `cmd_session_start` pattern). Continue excluding `.archived/` (the two-level glob does not descend into `.archived/*` because that is one level; verify `.archived/<prefix>` flat archives are excluded as today).

**Severity rationale.** P1: directly violates a stated AC and silently defeats the multi-initiative safety warning for the canonical layout.

---

### L1-04 — Aggregate metrics omit product-scoped initiatives (P1)

**Problem.** `cmd_metrics_report --all` and `--calibrate` glob `"$SRD_ROOT"/*/.edm-state.json` + `"$SRD_ROOT"/.archived/*/.edm-state.json` only. Product-scoped active initiatives (`SRD/{PRODUCT}/{PREFIX}__*/`) are not matched, so they contribute nothing to the aggregate cost/time table or to calibration medians. SRD `:1149` explicitly lists the `metrics-report` globs among the call sites that must move to state-derived/both-layout resolution under EDMV2-88.

**Evidence (edm-state:872 and :913).**
```bash
      for state in "$SRD_ROOT"/*/.edm-state.json "$SRD_ROOT"/.archived/*/.edm-state.json; do        # --all
      ...
      ' "$SRD_ROOT"/*/.edm-state.json "$SRD_ROOT"/.archived/*/.edm-state.json 2>/dev/null || \      # --calibrate
```
Reproduced: `metrics-report --all` with a product-scoped EDMV2 (phase 4) present shows only the FLAT row; EDMV2 is absent.

**Fix.** Add `"$SRD_ROOT"/*/*/.edm-state.json` to both glob lists. Note the existing archived glob is one-level (`.archived/*/`); if archives can also be product-scoped (`.archived/{PRODUCT}/{PREFIX}__*/`) that is a separate gap, but the active product-scoped omission is the actionable one here. De-dup so an initiative matched by both the flat and two-level globs is not counted twice (otherwise costs double).

**Severity rationale.** P1: silently wrong aggregate numbers — the headline cost/savings reporting under-counts every initiative created in the canonical v2.0 layout. Wrong values, not just missing UI.

---

### L1-05 — Misleading `0x` savings; dead `"Medium"` default (P2)

**Problem.** `human_cost_for_phase` returns hours `0` (cost `$0.00`) for any size other than Small/Medium/Large — including `"Unknown"`. `edm-state init` writes `estimated_size: "Unknown"` literally, and `cmd_phase_complete` reads it as `.estimated_size // "Medium"`. Because `"Unknown"` is a non-null string, the `// "Medium"` default never fires, so `human_baseline_usd` is `0.00` for every phase until a user manually `set`s a size. The metrics savings then compute `human/claude = 0/claude`, and the report prints `0x` / `Savings: 0x cheaper` / `Cost Ratio 0x`. `0x` reads as "the AI saved nothing / is infinitely more expensive" — the inverse of the intended message; an honest report would say `n/a`. The real `SRD/EDMV2/.edm-state.json` exhibits exactly this (all phases `human_baseline_usd: 0.00`, every Savings cell `0x`).

**Evidence.**
- edm-state:244 `*)          hours=0    ;;` (Unknown falls here)
- edm-state:581 `size="$(echo "$current" | jq -r '.estimated_size // "Medium"')"` — default is dead given init's `"Unknown"`.
- edm-state:938 / :948-949 — savings guard is `if ($v.estimated_cost_usd // 0) > 0` (guards the divisor, not the zero numerator), so `0/30.45` prints `0x`.
- Real run: `Total: ... | Human baseline: $0 | Savings: 0x cheaper`, every phase row `$0.00 ... 0x`.

**Fix.** Two independent options (do at least one): (a) in the savings expression, treat `human_baseline == 0` as `n/a` (e.g. `if $human > 0 and $claude > 0 then (… )+"x" else "n/a" end`) so a missing baseline is not rendered as `0x`; and/or (b) make the `"Unknown"`→baseline path explicit — either default `human_cost_for_phase` to Medium when size is `Unknown`/empty, or have `cmd_phase_complete` map `"Unknown"`→`"Medium"` before calling it so the documented default actually applies.

**Severity rationale.** P2: misleading metric (operational friction / wrong impression), not a crash or data loss. The SIZE_UNKNOWN anomaly (`state_anomalies`) already nudges users to set a size, which mitigates but does not fix the misleading `0x`.

---

### L1-06 — No numeric validation before `--argjson` (P2)

**Problem.** `cmd_set` validates numeric fields and emits a friendly `die` on bad input (`:424` regex). But `cmd_record_test_coverage` (`pct`), `cmd_record_tests_added` (`count`), and `cmd_approve_gate` (`gate`) feed the user value straight into `--argjson` with no check. A non-numeric value yields a raw `jq: invalid JSON text passed to --argjson` dump with no context. The crash occurs before `write_state`, so state is not corrupted (verified — file remains valid JSON), but the UX is inconsistent with `cmd_set` and the error is unhelpful.

**Evidence.**
- edm-state:699 / :706 `jq --arg l "$layer" --argjson p "$pct" …` (no `[[ "$pct" =~ … ]]` guard)
- edm-state:722 `jq --arg k "$key" --arg l "$layer" --argjson c "$count" …`
- edm-state:532 `jq --argjson g "$gate" …`
- Reproduced: `record-test-coverage FLAT unit N/A` → `jq: invalid JSON text passed to --argjson`; state file still valid afterward.

**Fix.** Add the same numeric guard `cmd_set` uses before each `--argjson` of a user value, e.g.
`[[ "$pct" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || die "record-test-coverage: pct must be numeric; got: $pct"` (and analogously for `count` and `gate`).

**Severity rationale.** P2: friction / inconsistent validation, ugly error. No state corruption (pre-write failure), so not P1.

---

### L1-07 — Phase label renders `1Phase` instead of `Phase 1` (P3)

**Problem.** In the single-initiative per-phase table, the label is built with `sub("_phase$"; "Phase ")`, which strips the `_phase` suffix and appends `"Phase "`, leaving the leading digit in place: `"1_phase"` → `"1Phase "`. Output shows `1Phase`, `2Phase`, … instead of `Phase 1`, `Phase 2`.

**Evidence (edm-state:938).**
```bash
| "  \($k | sub("_phase$"; "Phase ") | .[0:10]) …"
```
Reproduced: `echo '"1_phase"' | jq -r 'sub("_phase$";"Phase ")'` → `1Phase `. Confirmed in the real `metrics-report EDMV2` output (`1Phase`, `2Phase`, …).

**Fix.** Build the label from the captured digit, e.g. `("Phase " + ($k | sub("_phase$";"")))`, or `(.key | ltrimstr-style)` — i.e. prepend `"Phase "` to the number rather than substituting the suffix.

**Severity rationale.** P3: cosmetic; the data is correct, only the column label is malformed.

---

### L1-08 — Pattern-library heading skip-list over-matches by prefix (P3)

**Problem.** `cmd_update_patterns` skips "structural" headings via a `case` on the lowercased title: `summary*|findings*|recommendations*|overview*|appendix*|legend*`. These are prefix globs, so a legitimate finding whose title begins with one of these words (e.g. "Summary of auth bypass", "Findings overview gap") is silently dropped and never appended to the pattern file.

**Evidence (edm-state:1594-1596).**
```bash
    case "$lower_title" in
      summary*|findings*|recommendations*|overview*|appendix*|legend*) continue ;;
    esac
```
Reproduced: "Summary of auth bypass risk" → SKIPPED; "SQL injection in login" → KEPT.

**Fix.** Anchor the match to whole-heading structural sections, e.g. match exact titles (`summary|findings|recommendations|...`) or `summary|summary:*` rather than `summary*`; or require the heading to be a known section name rather than any title that starts with the word.

**Severity rationale.** P3: affects only the advisory audit-pattern library (a learning aid), not state or gate logic, and real finding titles rarely start with these words. Borderline NOTED, but it is a genuine silent-drop so kept as P3.

---

## Noted / Not Actionable

- **`compute_cost_usd` model fall-through (`:217 *sonnet*|*`)** — an unknown model (e.g. `unknown`, `gpt-4`) is priced at Sonnet rates. Intentional safe default per the rate-table comment (`:193-198`); verified `unknown` → $3/Mtok input. Not a bug.
- **`get_session_tokens_since` cache-write split (`:186-187`)** — `.message.usage.cache_creation.ephemeral_5m_input_tokens` / `ephemeral_1h_input_tokens` match the real session JSONL structure exactly (verified against `~/.claude/projects/-Users-darryl-porter-projects-marketplace/*.jsonl`). `fromdateiso8601` correctly parses the trailing `Z`. Timestamps and `.message.model` are present on assistant records. Correct.
- **`session_dir_for_cwd` encoding (`:164`)** — `tr '/.' '-'` reproduces Claude Code's actual directory name (`-Users-darryl-porter-projects-marketplace`) including the `.`→`-` in `darryl.porter`. Documented and correct.
- **Gate-review-time jq filter (`:959-998`)** — fully reproduced against the real state: Gate 1 = 2885s, Gate 2 = 15921s, Gate 3 = 4420s, all hand-verified. The `phase_complete_epoch` started_at+duration fallback, the `$diff < 0` inconsistency guard, and the bound-`. as $state` pattern are all correct. (An apparent "missing Gate 3" during audit was a `sed` truncation artifact, not a code defect.)
- **`--calibrate` median uses upper-middle element (`:908-909 .[length/2|floor]`)** — for even-count groups this returns the upper-of-two rather than their average. Labeled "median" but is an approximation; acceptable for a calibration heuristic and consistent across both duration and cost. Noted, not actionable.
- **`group_by(.size + "_" + .phase)` key join (`:904`)** — underscore concatenation could theoretically collide (`size="A_1",phase="2"` vs `size="A",phase="1_2"`), but `estimated_size` is constrained to Small/Medium/Large and the phase segment is `sub("_phase$";"")` of `N_phase` (a bare integer), so collision cannot occur in practice. Noted.
- **Per-epic / coverage column-width `(15 - length | if . < 0 then 0 else . end)` (`:764`, `:1025`)** — jq's `-` binds tighter than `|`, so this parses as `(15 - length) | clamp`; verified that a 21-char epic name clamps to 0 padding without a negative-`*` error. Correct.
- **`migrate-path` source is flat-only (`:1056 src="${SRD_ROOT}/${prefix}"`)** — by design: migration is the one-way flat→product-scoped move (CLAUDE.md "Migration from flat to product-scoped is opt-in"). Errors cleanly when the source is not a flat dir. Intentional.
- **`record-task-duration` no-op (`:684-689`)** — explicitly documented reserved no-op (header `:13`, body comment `:685-687`); the `TaskCompleted` hook fires safely and records nothing. Documented as intentional/deferred future work, not a stub masquerading as complete. Noted (would be P2 only if it claimed to accumulate durations — it does not).
- **`read_bool` / `read_num` coercion defaults (`:322-346`)** — non-numeric strings fall back to the supplied default (verified `"abc"` → `0`); boolean/string normalization handles legacy string-typed fields. Correct (T33 design).
