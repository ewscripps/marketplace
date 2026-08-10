# Lens L10: DRY & Redundancy -- Pass 6 (2026-08-10)

**Tooling note (CA-130's class, seventh consecutive round):** Write/Edit/Bash absent
from this lens's delivered runtime tool set. This report was transcribed by the
orchestrator from the lens agent's final message.

## Ledger verdicts on prior L10-attributed findings

| ID | Sev | Verdict this round |
|---|---|---|
| CA-327 | P2 | **RESOLVED -- extraction complete.** All four per-class loops call the shared helper (`plugins/edm/bin/edm-lint-artifacts:328` attribution, `:336` unicode/PCRE, `:346` unicode/fallback, `:358` leaked-tool-tag). `_lint_report_class_hits` (:243-252) is the only copy of the grep->skip-ignored->snippet->report body left anywhere in the plugin; the process-substitution requirement is documented at :237-242. No fifth hand-rolled instance survives. `edm-check-vocabulary:211-232` is a different shape (one whole-fileset grep per token, then allowlist filtering) and is correctly NOT a copy of it. |
| CA-326 | P2 | **RESOLVED -- inline copy deleted.** `bin/tests/wave7-smoke.sh:4555-4561` now calls `_wave7_assert_shared_lint_fresh "T48 (pre-block)"`; the helper (:1403) has 17 call sites and no reimplementation of its two checks survives. |
| CA-279 | P2 | **RESOLVED.** All five UserPromptExpansion prompt bodies now route through `edm-state gate-check <PREFIX> <token>` (`hooks/hooks.json:23, 36, 49, 62, 75`) and explicitly say "never hardcode one here" -- the prose phase-to-gate mapping is gone. |
| CA-298 | P1 | **RESOLVED (L10 half).** The contradiction round 5 found is closed: the prompt half's "resolve-dir fails -> legitimate first invocation, allow expansion" now matches the command half's `edm-state resolve-dir "$prefix" >/dev/null 2>&1 || exit 0` at :19/:32/:45/:58/:71. The two copies of the policy now return the same verdict on a missing/unresolvable initiative. |
| CA-309 | P2 | **RESOLVED as prescribed.** `--all-lint` runs `_measure_p95 1 ms -- "$EDM_LINT" --all` (`bin/tests/timing.sh:430`), keeps the `duration_ms=` key, and the count=1 rationale is documented at :421-428 and cross-referenced from `_p95`'s docstring (:76-78). No hand-rolled `_now`/`_ms_between` timing loop survives in the file. |
| CA-310 | P2 | **RESOLVED as prescribed.** `--subcommands` still enumerates the four names in both the loop and the `case` (`timing.sh:246-251`), but the loud default arm landed at :257 (`exit 1`, naming the unmatched token), which was the sanctioned fix -- the silent stale-`p95` misreport is no longer reachable. |
| CA-282 | NOTED | Re-verified, no drift. `cmd_metrics_report`'s baseline/non-baseline row renderers (`bin/edm-state:2981` vs `:3006`) are still byte-identical on the columns they share (label, duration, cost, tokens, model) and the `--all` arms (:2878 vs :2889) likewise. |
| CA-281 | P2 | Closed-as-accepted last round; not revisited, per that ledger row's explicit instruction. |
| CA-037 | P1 | **NOT re-verified this round** (L4/L7 own the control-arm half; the L10 half is the ten hand-rolled copies). I did not have runtime budget to read wave6/wave7 (11.5k lines) closely enough to count surviving copies honestly, and I will not assert a verdict I did not check. Flagging explicitly rather than silently omitting. |

## Findings (L10: DRY & Redundancy)

| # | Type | File A | File B | Canonical | Recommendation |
|---|---|---|---|---|---|
| L10-001 | Diverged parallel renderer | bin/edm-state:2371-2375 | bin/edm-state:3171-3174 | neither -- extract | Add a `COVERAGE_EPIC_ROW_JQ_DEF` beside CA-012's layer-row def; both call sites reference it |
| L10-002 | Same predicate implemented 3x | bin/edm-state:2029-2046 | bin/edm-state:3398-3415 (+ :2620-2630) | extract `gate_required_and_approved` | One helper for "is this gate required, and approved" |
| L10-003 | Duplicate validator | bin/edm-init:53 | bin/edm-validate-prefix:42 | bin/edm-validate-prefix | Delete edm-init's regex copy; make the delegated call unconditional |
| L10-004 | Duplicate predicate | bin/edm-check-grants:256-263 | bin/edm-check-grants:501-507 | extract `agent_grants_class` | One effective-grant predicate for both directions |
| L10-005 | Copy-pasted block 3x | bin/edm-lint-artifacts:414-432 | :438-463, :486-505 | extract | `_collect_into MD_FILES` + `_summarize_and_exit <label>` |
| L10-006 | Diverged parallel scan | bin/edm-validate-prefix:58-72 | bin/edm-validate-prefix:80-87 | extract | One `_scan_product_dirs_for_prefix` used by both live and archived |
| L10-007 | Layout knowledge duplicated | bin/edm-state:2432-2439 | bin/edm-state:129-148 | list_state_files | Reuse `list_state_files --archived` for the archived-refusal check |
| L10-008 | Duplicate helper | bin/edm-check-grants:360-368 | bin/edm-check-grants:370-375 | extract `_lookback_window` | One window computation, computed once per hit |

### Details

#### L10-001 (P2, highest priority of this set) -- the per-epic coverage row is the half CA-012 did not extract, and the two copies have already diverged
- **File A**: `plugins/edm/bin/edm-state:2371-2375` (`cmd_get_coverage`) -- renders `Epic | Layer | Coverage | Measured At`, with 15-wide epic padding, 14-wide layer padding, and a three-branch pct pad (`8/7/6` spaces) before `measured_at`.
- **File B**: `plugins/edm/bin/edm-state:3171-3174` (`cmd_metrics_report`) -- renders `Epic | Layer | Coverage`, byte-identical 15/14 padding prefix, then stops: no pct pad, no `measured_at`.
- **Divergence**: real and already shipped. The shared prefix is duplicated verbatim; the trailing columns differ, and each site also hand-writes its own header/underline pair (`:2372-2373` vs `:3169-3170`). A padding change made in one is invisible in the other.
- **Why this is the priority one**: `COVERAGE_LAYER_ROW_JQ_DEF`'s own docstring (`:990-994`) says "one renderer, one padding scheme ... prepended to both get-coverage and metrics-report so the two can never diverge again (CA-012)". That claim is true only of the whole-initiative layer row. Both commands also render a per-epic table, and that row was never extracted -- so the file carries a comment asserting the drift class is closed while an unextracted second instance of the same class sits ~800 lines away. A contributor reading CA-012's comment reasonably concludes coverage rendering is single-sourced.
- **Fix**: define `COVERAGE_EPIC_ROW_JQ_DEF` immediately after the layer def, taking the `measured_at` column as an optional suffix (or emit it always and let metrics-report's header include it -- the honest option, since the data is present). Reference it from both sites. Correct CA-012's docstring to name both rows.

#### L10-002 (P2, medium) -- "is the required gate approved, given mode and skipped phases" is written three times
- **File A**: `bin/edm-state:2015-2046` (`cmd_phase_start`).
- **File B**: `bin/edm-state:3390-3415` (`cmd_gate_check`).
- **File C (partial)**: `bin/edm-state:2618-2630` (`cmd_archive` AC1a) -- shares steps 1, 2 and 4 but iterates the required list instead of testing membership.
- A and B are the same seven-step procedure with only the diagnostic string and the `record_degraded_check` label differing:
  1. `mode="$(... '.mode // "null"')"`, `schema_version=... '.schema_version // empty'`
  2. `if [[ "$(schema_at_least "$sv" 1)" == "0" || "$mode" == "null" ]]` -> warn -> `record_degraded_check ... "no schema_version"`
  3. `lifecycle_mode="$(... '.lifecycle_mode // "standard"')"`
  4. `skipped_phases_str="$(... '[(.skipped_phases // [])[].phase] | join(" ")')"` -- this exact jq appears at **:2034, :2090, :2621, :3400** (four sites)
  5. `required_gates_for_mode "$mode" "$lifecycle_mode" "$skipped_phases_str"`
  6. `printf '%s\n' "$required_gates_list" | grep -qx "$gate"`
  7. `(.gates_approved // []) | map(select(.gate == $g)) | length` -- this exact jq appears at **:2039, :2625, :3408**
- **Divergence**: none today -- and that is precisely the finding. The comments at :2026-2028 and :3379-3383 both assert the sites share "the same derivation ... not a second one", which is true only of `required_gates_for_mode`/`gated_phase_for_gate`. Steps 2, 4, 6 and 7 -- the legacy-degradation preamble, the skip-set extraction, the membership test and the approval count -- are independently maintained copies. Two of the three enforcement points for this plugin's central invariant (a gate must be approved before a phase runs) would have to be edited in lockstep for any change to the rule; a fix applied to `gate-check` alone silently leaves the `Skill`-tool path (which bypasses the hooks and reaches `phase-start` directly, per :2004-2007) on the old rule.
- **Fix**: extract two helpers next to `required_gates_for_mode` -- `gate_is_approved <state-json> <gate-num>` (step 7) and `skipped_phases_str <state-json>` (step 4) -- then a `gate_required_and_approved <state-json> <mode> <lifecycle_mode> <gate>` composing steps 3-7. Keep each caller's own diagnostic text and `record_degraded_check` label at the call site; only the derivation moves. `cmd_archive` reuses steps 4 and 7.

#### L10-003 (P2, medium) -- the prefix-format rule is validated by both the dedicated validator and its caller
- **File A**: `bin/edm-validate-prefix:42` -- `^[A-Z][A-Z0-9]{2,5}$`, message "invalid format: prefix must be 3-6 uppercase alphanumeric chars, starting with a letter (got '$PREFIX')", exit 1.
- **File B**: `bin/edm-init:53` -- the same regex, message "prefix must be 3-6 uppercase alphanumeric chars, starting with a letter", exit 1.
- `edm-init` *also* delegates to the validator at :81-86, so on a normal install the format is checked twice with two independently-maintained regexes and two different message strings. `plugins/edm/CLAUDE.md:172-175` names `bin/edm-validate-prefix` as *the* validator ("Validated by `bin/edm-validate-prefix` for global uniqueness"), and `prefix_format_hint` states the rule a third time in prose.
- **Divergence**: none today; the risk is direction-asymmetric. If the format is ever widened (a 2-char prefix, a digit-leading prefix), `edm-init`'s copy rejects valid input *before* the canonical validator is consulted, so the widening appears not to have worked at the primary entry point.
- **Not a false alarm**: there is no comment at :53 claiming the copy is a deliberate fallback, and the guard shape is inconsistent with its neighbour -- :81 guards `edm-validate-prefix` behind `command -v` while :161 calls `edm-state init` unconditionally, so "the validator might not be on PATH" is not a premise this script actually holds.
- **Fix**: delete :53 and make the :81-86 call unconditional (matching the `edm-state` call at :161); or, if the `command -v` guard must stay, replace :53 with a comment naming it the no-validator fallback and add a smoke assertion that the two regex literals are identical.

#### L10-004 (P2, medium) -- the effective-grant predicate is implemented twice, once per direction
- **File A**: `bin/edm-check-grants:256-263` (inside `assert_agent_grant`, positive/must-fail direction):
  `satisfied=1; has_tool "$tools" "$class" || satisfied=0; if [[ -n "$disallowed" ]] && has_tool "$disallowed" "$class"; then satisfied=0; fi`
- **File B**: `bin/edm-check-grants:501-507` (negative/warning direction): the same three statements with `_granted`/`_agent_tools`/`_agent_disallowed`.
- This is the checker's core rule -- "a class is granted iff `tools` lists it AND `disallowedTools` does not" -- and the two copies are the two directions of one check. Both must agree by construction or the tool reports a grant as both unsatisfied and un-instructed, or neither.
- **Divergence**: none today.
- **Fix**: extract `agent_grants_class <tools> <disallowed> <class>` returning 0/1 and call it from both. Roughly 12 lines to 2.

#### L10-005 (P2, low) -- `edm-lint-artifacts`'s three mode arms copy the same collect-and-summarize wrapper
- **File A**: `bin/edm-lint-artifacts:414-417` + `:426-432` (prefix mode).
- **File B**: `:438-441` + `:457-463` (path mode).
- **File C**: `:486-489` + `:499-505` (all mode).
- The `while IFS= read -r -d "" _md_f; do MD_FILES+=("$_md_f"); done < <(collect_md_files ...)` loop appears three times verbatim, and the `if [[ "$violations" -eq 0 ]]; then echo "... CLEAN ..."; exit 0; else echo "... $violations violation(s) found" >&2; exit 1; fi` block appears three times differing only in the label interpolated into both messages.
- **Divergence**: none, but the exit-code contract (0 clean / 1 violations, documented at :42-47 and depended on by the PreToolUse hook, which distinguishes 1 from 2) is encoded three times. A change to that contract is three edits.
- **Not fully covered by EDMV3-111**: the ticket's single-implementation claim is about `scan_md_files` (the scan itself, correctly shared), not about the wrappers.
- **Fix**: `_collect_into <arrayname> <dir>` (or return the count) and `_summarize_and_exit <label> [<scope-suffix>]`. Keeps the three distinct message strings as arguments.

#### L10-006 (P2, low) -- the product-scoped collision scan exists twice in one 90-line script, with diverged guards
- **File A**: `bin/edm-validate-prefix:58-72` (live scan) -- guarded by `[[ -d "$SRD_ROOT" ]]`, skips `.archived` by basename, checks `-d "$product_dir"`, then globs `${product_dir}/${PREFIX}__*/` and `die`s on a hit.
- **File B**: `bin/edm-validate-prefix:80-87` (archived scan) -- no outer `-d` guard on `${SRD_ROOT}/.archived`, no basename skip (correctly, it is inside `.archived`), same inner glob, warns instead of dying.
- **Divergence**: benign today (the inner `[[ -d ]]` tests absorb an unmatched glob, and the doubled separator in `"${SRD_ROOT}/.archived/"/*/` at :80 globs correctly), but the two copies of one "walk product dirs looking for `PREFIX__*`" loop are the reason the two halves already differ in guard structure -- and the archived half is one `set -u`-adjacent edit away from behaving differently on an absent `.archived`.
- **Fix**: `_scan_product_dirs_for_prefix <root> <prefix>` printing each hit; call it twice (once with `$SRD_ROOT` and a `.archived` skip, once with `${SRD_ROOT}/.archived`), and let each caller decide `die` vs warn.

#### L10-007 (P2, low) -- `migrate-schema` re-derives the archived layout instead of asking `list_state_files`
- **File A**: `bin/edm-state:2432-2439` -- hand-globs both archived shapes: `${SRD_ROOT}/.archived/${prefix}/.edm-state.json` and `${SRD_ROOT}/.archived/*/${prefix}__*/.edm-state.json`.
- **File B**: `bin/edm-state:129-148` (`list_state_files --archived`) -- already enumerates exactly those two shapes, deduped.
- `state_file_for` is declared "single source of layout truth" (:208-218) and `list_state_files` is the enumeration half of it; this is a third site that knows the flat-vs-product-scoped archived path shapes. A future layout variant (or an `.archived` nesting change) must be applied here too, and the AC4 refusal silently stops working if it is not.
- **Fix**: `archived_hit="$(list_state_files --archived | grep -m1 -E "/\.archived/(${prefix}/|[^/]+/${prefix}__[^/]*/)\.edm-state\.json$" || true)"`, or add a small `archived_state_file_for <prefix>` helper next to `state_file_for` and call it here.

#### L10-008 (P2, low) -- two adjacent functions each hand-compute the same lookback window
- **File A**: `bin/edm-check-grants:360-368` (`nearby_agent_name`): `lo=$((line - lookback)); [[ $lo -lt 1 ]] && lo=1; sed -n "${lo},${line}p" "$file" ...`
- **File B**: `bin/edm-check-grants:370-375` (`window_mentions_lens`): the identical three lines, different grep.
- `resolve_targets_for_line` (:377-390) can call both for the same hit, so the same `sed` range is also *executed* twice per candidate line -- a small, avoidable cost on top of the duplication.
- **Fix**: `_lookback_window <file> <line> <lookback>` printing the window once; have `resolve_targets_for_line` capture it and pass the text to both matchers.

## Noted / Not Actionable

1. **Five UserPromptExpansion command hooks byte-identical apart from one token** (`hooks.json:19/32/45/58/71`) -- JSON has no include mechanism; unchanged from prior rounds' rationale.
2. **The five prompt bodies duplicate their sibling command hooks' procedure** -- deliberate and self-documented ("this prompt is an advisory second layer, not the primary check"); the duplication is the design, and CA-298's contradiction between the layers is now closed.
3. **CA-282 re-verified**: `cmd_metrics_report`'s forked renderer arms (`:2878`/`:2889`, `:2981`/`:3006`, `:2984`/`:3009`) still agree byte-for-byte on shared columns. No drift. (Note: L10-001 is a *different* pair -- get-coverage vs metrics-report, not baseline vs non-baseline.)
4. **`_unpack_token_fields`'s 3-line marshalling residual at both call sites** -- mechanical, not semantic; retained as-is per round 5.
5. **`_lock_retry_or_die`'s dynamic-scoping mutation of the caller's `tries`** -- documented at :1014-1023 and consistent with `_save_traps`/`_unpack_token_fields`/`_lint_report_class_hits`, which now all rely on the same convention for the same stated reason.
6. **`edm-init`'s `.gitignore` heredoc reproduced in `README.md:219-224`** -- documented as intentional in both places (`edm-init:166-168`, `README.md:215-217`), four data lines, currently identical. Cheap hardening if someone is already there: a smoke assertion comparing the two blocks; not raised as a finding.
7. **`evals/score-artifacts.sh`'s `_scan_mermaid_blocks` vs `_edm-lint-lib.sh`'s `build_line_classes`** -- both load the shared `bin/edm-mermaid-rules.awk` via `-f` (CA-019), and the remaining behavioural difference (score-artifacts honors no `edm-lint-ignore` marker) is stated explicitly at `score-artifacts.sh:99`. Deliberate, documented, single-sourced where it matters.
8. **`edm-check-vocabulary`'s match loop vs `edm-lint-artifacts`'s `_lint_report_class_hits`** -- superficially similar, genuinely different designs (one grep per token across the whole file set vs one grep per class per file) with different suppression inputs. Not a copy.
9. **`SRD_ROOT="${EDM_SRD_ROOT:-${CLAUDE_PLUGIN_OPTION_SRD_ROOT:-./SRD}}"` in four scripts plus the git-commit hook** -- each is an independent entry point with no shared library it could source before resolving its own root (`_edm-cli-lib.sh` is sourced *after* the assignment in three of them); the hook cannot source bash libraries at all. Consistent everywhere it appears.
10. **`_cmd_archive_move_body` vs `_cmd_migrate_path_move_body` lock-name sweeps** -- look like copies but their divergence is deliberate and explained at length (`:3196-3205`): archive removes the destination `.lock`, migrate-path deliberately does not, because migrate-path's destination is the new live home. Documented as an intentional asymmetry, not drift.
11. **CA-283 (`run-eval.sh`'s three phase blocks)** -- carried as NOTED; not re-checked this round (see Meta).

## Meta

- **Coverage this round, stated honestly.** Read in full: `bin/_edm-lint-lib.sh`, `bin/_edm-cli-lib.sh`, `bin/edm-lint-artifacts`, `bin/edm-check-grants`, `bin/edm-check-vocabulary`, `bin/edm-check-skill-sync`, `bin/edm-sync-canonical-sections`, `bin/edm-validate-prefix`, `bin/edm-init`, `bin/tests/timing.sh`, `hooks/hooks.json`, and `bin/edm-state:1-3600`. **Not read closely**: `bin/edm-state:3600-5193` (audit-round/ledger/pattern-library/HANDOFF renderers), `bin/tests/wave6-smoke.sh`, `bin/tests/wave7-smoke.sh`, `bin/tests/_harness.sh`, `bin/tests/run-all.sh`, `evals/*.sh`, `.gitlab-ci.yml`. The two extractions I was asked to verify (CA-327, CA-326) and the four other open L10 rows (CA-279, CA-298, CA-309, CA-310) were all verified directly against current code; CA-037's L10 half was not, and is flagged as such rather than assumed.
- **Tooling gap (ledger CA-130, seventh consecutive round).** `Write`, `Edit` and `Bash` were absent from this lens's delivered runtime tool set, so neither `lens-L10.md` nor `lens-L10.jsonl` could be written; both need orchestrator transcription. Bash absence also meant no `diff`/`sort`/`uniq` was available for duplicate detection -- every comparison above was done by reading and by `Grep`, which biases this round's coverage toward files small enough to read end-to-end and is the direct cause of the coverage gap listed above.

## Suggested JSONL rows for `lens-L10.jsonl`

Same eight findings, all P2, all new this round.

| id | sev | confidence | file | line | title |
|---|---|---|---|---|---|
| L10-001 | P2 | high | plugins/edm/bin/edm-state | 2371 | per-epic coverage row duplicated and diverged between get-coverage and metrics-report; CA-012's "can never diverge again" comment covers only the layer row |
| L10-002 | P2 | high | plugins/edm/bin/edm-state | 3398 | required-gate-approved derivation implemented three times (phase-start, gate-check, archive) including four copies of the skipped-phases extraction and three of the approval count |
| L10-003 | P2 | high | plugins/edm/bin/edm-init | 53 | prefix-format regex duplicated from edm-validate-prefix, which edm-init also delegates to |
| L10-004 | P2 | high | plugins/edm/bin/edm-check-grants | 501 | effective-grant predicate (tools minus disallowedTools) implemented once per direction |
| L10-005 | P2 | medium | plugins/edm/bin/edm-lint-artifacts | 426 | collect-md-files loop and violations-summary/exit block copy-pasted across all three mode arms |
| L10-006 | P2 | medium | plugins/edm/bin/edm-validate-prefix | 80 | product-scoped PREFIX__* collision scan implemented twice with diverged guards |
| L10-007 | P2 | medium | plugins/edm/bin/edm-state | 2432 | migrate-schema hand-globs both archived layouts instead of reusing list_state_files --archived |
| L10-008 | P2 | low | plugins/edm/bin/edm-check-grants | 370 | nearby_agent_name and window_mentions_lens each hand-compute the same lookback window, executed twice per hit |
</content>
