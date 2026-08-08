# Lens L10: DRY & Redundancy -- Pass 3 (2026-08-08)

## Ledger verdicts (every open entry whose Lens(es) includes L10)

| ID | Lenses | Verdict | Evidence |
|---|---|---|---|
| CA-005 | L1+L2+L6+L7+L10 | **RESOLVED** | `_edm-cli-lib.sh:28-30` is the sole `print_help`; all 9 bin/ helpers + 3 evals/ drivers source it; CI ban landed at `.gitlab-ci.yml:112-125` (both the second-copy ban and the hardcoded-`sed -n 'A,Bp'` ban); smoke guard at `wave7-smoke.sh:4807-4822`; `edm-sync-canonical-sections:2` now has sentinels |
| CA-010 | L6+L7+L10 | **RESOLVED** | `wave7-smoke.sh:310-326` now asserts each consumer *sources* the library and *defines none* of the three helpers locally; `build_ignore_set` survives only in explanatory prose (:305, :308), in no assertion |
| CA-018 | L6+L10 | **RESOLVED** | `edm-audit-synthesizer.md:85` and `edm-srd-auditor.md:69` are now pure by-name references + canonical-sections anchor; no local four-bullet scale at either site |
| CA-019 | L7+L10 | **PARTIAL** -> Findings 1 (P1) and 5 (P2) | `edm-mermaid-rules.awk` was extracted, but only 2 of 3 consumers converted |
| CA-049 | L7+L10 | **PARTIAL** -> Findings 3 and 4 (P2) | root-derivation half fixed in bin/; both new shared helpers have zero adopters |
| CA-094 | L10 | **PARTIAL** -> Finding 2 (P2) | lint half fully converted; grants half missed at 6 sites |
| CA-095 | L10+L11 | **RESOLVED** (L10 half) | all 11 lens files now cite `skills/code-audit/SKILL.md`'s *"Operational Orchestration"* step by name, no line number; `edm-check-grants:13` and `:330-335` likewise by-name |
| CA-096 | L10 | **RESOLVED** | `_standalone_check` extracted at `run-all.sh:150-166`; three call sites (:171, :177, :183) incl. the previously-uninvoked `edm-check-vocabulary` |
| CA-155 | L7+L10 | **RESOLVED** | `_edm-lint-lib.sh:192-197` requires lowercase `violations` and hard-fails otherwise; `VIOLATIONS` has zero occurrences in `bin/`; all three consumers declare `violations=0` (`edm-check-grants:123`, `edm-check-vocabulary:133`, `edm-lint-artifacts:142`) |
| CA-156 | L7+L10 | **MOSTLY RESOLVED** -> Finding 7 (P2) | `ignored_line_set` exists only in the library; the *record-shape parser* is still hand-written 7x |

## Findings

| # | Sev | Type | File A | File B | Canonical | Recommendation |
|---|---|---|---|---|---|---|
| 1 | **P1** | Diverged-capable parallel impl | `bin/edm-mermaid-rules.awk:58-118` | `bin/edm-lint-artifacts:169-219` | `bin/edm-mermaid-rules.awk` | Load the shared rules via `-f` in `mermaid_scan_awk`; delete the private 51-line copy; add a CA-005-shaped CI ban; correct three false headers |
| 2 | P2 | Fix applied to one half, sibling half missed | `wave7-smoke.sh:1278-1279` (capture) | `:3041, :3773, :3816, :3874, :3961, :4198` (live re-runs) | the single capture | Convert all six to `WAVE7_GRANTS_EXIT`; correct the false claim at `:3703-3706` |
| 3 | P2 | Shared helper with zero adopters; duplicates intact | `_harness.sh:60-66` | `wave3:15-16`, `wave4a:15-16`, `wave5:13-14` | `_harness.sh` `harness_scratch_dir` | Convert the three suites, or delete the unused helper |
| 4 | P2 | Shared exports with zero consumers; header contradicts them | `_harness.sh:41-44` | `wave4b:7`, `wave6:10,:710`, `wave7:12`, `harness-smoke:8`, `timing.sh:26` | pick one | Adopt at all five sites and delete `_harness.sh:5`'s contradicting sentence, or delete `:41-44` |
| 5 | P2 | Undocumented behavioural divergence under an "agree" header | `bin/edm-lint-artifacts:233,237` | `evals/score-artifacts.sh:283-322` | `bin/edm-lint-artifacts` | Pass a marker set through, or narrow the claim at `score-artifacts.sh:92-95` |
| 6 | P2 | Copy-pasted block x6 in newest code | `bin/edm-state:566-578, 590-597, 605-612, 615-622` | `bin/edm-state:1014-1028, 1049-1052` | new `_save_traps`/`_restore_traps` | Extract the four-signal sequence; extract `_write_atomic_unwind` |
| 7 | P2 | One record shape, seven parsers | `bin/_edm-lint-lib.sh:169,174,179` | `bin/edm-lint-artifacts:295-298` | `bin/_edm-lint-lib.sh` | Add `project_class <class>` reading the table on stdin; route all seven through it |

### Details

#### Finding 1 (P1): `edm-lint-artifacts` -- the authoritative linter -- was never converted to the shared Mermaid rule, and three shipped headers claim it was

- **File A**: `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-mermaid-rules.awk:58-118` -- shared `mermaid_trim`, `mermaid_strip_entities`, `mermaid_is_violation`.
- **File B**: `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-lint-artifacts:169-219` -- private `trim`, `strip_entities`, `is_violation` defined inline inside `mermaid_scan_awk`'s awk program. 51 lines, logic-identical to File A modulo the `mermaid_` name prefix: same `%%` carve-out, same `classDef|style|linkStyle` carve-outs, same explicit `k < 10` entity walk, same `sub(/;[[:space:]]*$/, "", stripped)`, same five span regexes, same sequence-diagram arrow-plus-colon check.
- `edm-lint-artifacts` contains **zero** references to `edm-mermaid-rules.awk` or `MERMAID_RULES_AWK` (whole-tree grep), even though `MERMAID_RULES_AWK` is already in its scope -- `_edm-lint-lib.sh:70` sets it and `edm-lint-artifacts:62` sources that file.
- **The shared rule's only real consumer is the eval scorer.** `_edm-lint-lib.sh:74` loads the shared file but calls only the *fence* functions; `mermaid_is_violation` is called from exactly one place in the tree: `evals/score-artifacts.sh:316`. So the canonical semicolon rule now lives in a file consumed only by a non-blocking nightly eval, while the copy the blocking `lint:artifacts` job and the `PreToolUse` git-commit hook actually enforce is the private, unshared one.
- **Three headers assert the conversion happened:**
  - `bin/_edm-lint-lib.sh:30-32`: "delegated to bin/edm-mermaid-rules.awk (CA-019) so this file, **bin/edm-lint-artifacts's own Mermaid scan**, and evals/score-artifacts.sh's standalone scanner all agree on what counts as a fence."
  - `bin/edm-mermaid-rules.awk:19-26`: "both callers plus `bin/edm-lint-artifacts`'s own `mermaid_scan_awk` helper each carried an independent, byte-equivalent copy ... **All three consumers now call the same fence-recognition functions below**."
  - `evals/score-artifacts.sh:92-95`: "so this scorer and bin/_edm-lint-lib.sh/**bin/edm-lint-artifacts** now agree on what counts as a fence and what counts as a violation."
- **Unguarded.** No test and no CI job asserts consumers load the shared file -- compare CA-005, whose identical duplication class got both a CI ban (`.gitlab-ci.yml:112-125`) and a smoke assertion (`wave7-smoke.sh:4807-4810`). `wave7-smoke.sh:923-930` mentions `edm-mermaid-rules.awk` only to *exclude* it from `bash -n`.
- **Why P1**: this is a diverged-capable parallel implementation of a rule enforced on the commit path. It is logic-identical today, so no live behavioural bug -- but a fix applied to the shared file changes what the nightly eval measures and nothing about what CI and the commit hook enforce. It is also the root cause of CA-050/CA-019, now unremediated for a third consecutive round in its most consequential consumer, while three headers state the opposite.
- **Fix**: convert `mermaid_scan_awk` to `awk -f "$MERMAID_RULES_AWK" -v scan_file="$MERMAID_SCAN_FILE" -f <(cat <<'AWK_MAIN' ... AWK_MAIN) "$file"` -- note `-f` and an inline `'program'` cannot be mixed, so the remaining program text must move into a `-f <(...)` heredoc exactly as `_edm-lint-lib.sh:74` and `score-artifacts.sh:285` already do. The bash-3.2 backtick-in-heredoc-in-process-substitution hazard both those sites document is satisfied here: the surviving comments at `:172-175` and `:234-236` contain no backtick. Then delete `:169-219`, rename `is_violation($0)` at `:238` to `mermaid_is_violation($0)`, and add a CI grep banning a second copy of the entity-walk literal.

#### Finding 2 (P2): CA-094's grants half -- six live whole-tree `edm-check-grants` runs survive after the shared capture, under a comment saying none do

- **Shared capture**: `bin/tests/wave7-smoke.sh:1278-1279`, with freshness guard `_wave7_assert_shared_lint_fresh` at `:1284-1295`.
- **Correctly converted** (6 sites): `:2477, :2623, :2752, :2859, :2901, :3711`.
- **Still forking a fresh whole-tree run** (6 sites, all *after* `:1279`): `:3041` (T55 AC7), `:3773` (T46 AC4), `:3816` (T46), `:3874` (T47), `:3961` (T49), `:4198` (T48). Every one only tests `exit == 0` -- precisely the value already held in `WAVE7_GRANTS_EXIT`. `:3773` and `:3816` re-run the same whole-tree scan twice inside a single ticket block.
- **Divergence**: `:3703-3706` states "T45, T46, T47, T49 and T48 below still each close with their own separately-named 'full suite stays green' case (AC-traceability preserved), but **all reuse that single capture instead of re-running it**." False for the grants half at four of the five named tickets. Compounding it, the *lint* half of those same four blocks (`:3818, :3876, :3963, :4200`) *was* converted -- one half of each block fixed, the sibling half missed.
- Supporting: `:1282-1283` claims "Every reuse site below calls this before trusting `$WAVE7_ALL_LINT_*` / `$WAVE7_GRANTS_*`", but the last `_wave7_assert_shared_lint_fresh` call is `:3707`; the four lint reuse sites at `:3818-:4200` carry no freshness re-check.
- **Fix**: replace the six live invocations with guarded `WAVE7_GRANTS_EXIT` reads; delete the now-dead `t55_grants_ec`, `t46_grants_exit`, `t46_grants2_exit`, `t47_grants_exit`, `t49_grants_exit`, `t48_grants_exit`; add the missing `_wave7_assert_shared_lint_fresh` calls; correct `:3703-3706`.

#### Finding 3 (P2): `harness_scratch_dir` has zero callers and the three duplicates it was created to replace are all intact

- **Shared helper**: `bin/tests/_harness.sh:60-66`. Its docstring (`:46-59`) names the problem and claims the cure: "CA-049: three older suites hand-rolled a byte-identical bare `mktemp -d` + `trap ... EXIT` preamble that did neither of those two things ... **this gives every suite, old and new, the same corrected preamble in one place**."
- **Zero callers**: `harness_scratch_dir` appears only in `_harness.sh` (definition + docstring) across the entire tree.
- **All three duplicates survive, byte-identical**: `wave3-smoke.sh:15-16`, `wave4a-smoke.sh:15-16`, `wave5-smoke.sh:13-14` -- each `TMP="$(mktemp -d)"` followed by `trap 'rm -rf "$TMP"' EXIT`. Bare `mktemp -d` (ignores `TMPDIR`) and `EXIT`-only (no `INT`/`TERM`) are exactly the two defects the helper exists to fix.
- **Net effect**: the tree moved from three copies of a defective preamble to three copies *plus* one unused correct implementation -- a strictly worse DRY posture than before the remediation.
- Likely adoption blocker, worth recording: the helper takes an out-variable name and must not be called via `$(...)` (`harness_scratch_dir TMP`, documented `:52-57`), and installs process-wide `EXIT/INT/TERM` traps that a suite installing its own trap later must save and restore (`:58-59`).
- **Fix**: convert the three sites to `harness_scratch_dir TMP` + `mkdir -p "$TMP/SRD"`. If the out-var API is judged too awkward, delete `:46-66` rather than ship an unused helper whose docstring claims a conversion that never happened.

#### Finding 4 (P2): `_HARNESS_PLUGIN_DIR` / `_HARNESS_REPO_ROOT` have zero consumers, five inline re-derivations survive (one already spelled differently), and the file's own header contradicts them

- **Exports**: `bin/tests/_harness.sh:41-44`, comment: "CA-049: shared plugin-root and repo-root exports so individual suites stop re-deriving the same value inline (five suites previously recomputed this a few lines above their own use of it)."
- **Zero references** to either name outside the definition (whole-tree grep).
- **Surviving inline derivations**: `wave4b-smoke.sh:7`, `wave6-smoke.sh:10` and `:710`, `wave7-smoke.sh:12`, `harness-smoke.sh:8`, and `timing.sh:26` -- the last already a **divergent spelling** of the identical value: `"$(cd "${SCRIPT_DIR}/.." && cd .. && pwd)"` versus every sibling's `"$(cd "${SCRIPT_DIR}/../.." && pwd)"`.
- **Header contradiction**: `_harness.sh:5` still reads "Each suite manages its own SCRIPT_DIR / EDM_STATE / **PLUGIN_DIR** / TMP setup; this file provides **only** the shared counters and assertions" -- flatly contradicting `:41-44` four lines below. A reader following the header will keep hand-deriving, which is what all five suites do.
- Real constraint on the fix: `wave4b:7` and `wave7:12` define `PLUGIN_DIR` *before* sourcing `_harness.sh` (`:10` / `:20`), so adoption requires reordering.
- **Fix**: pick one direction. Either adopt the exports at all five sites (reordering the two early definitions) and delete the contradicting clause at `:5`, or delete `:41-44` and stop asserting an extraction that has no consumer.

#### Finding 5 (P2): CA-019 residual -- scorer and linter still disagree on ignore-marker suppression, under a header claiming they agree on "what counts as a violation"

- **File A**: `bin/edm-lint-artifacts:233` skips lines in `marker_set` (honouring `edm-lint-ignore-start/end` around a fence) and `:237` reports a single-line `<!-- edm-lint-ignore -->` misused inside a mermaid fence as class `U`.
- **File B**: `evals/score-artifacts.sh:283-322` `_scan_mermaid_blocks` has no ignore handling of any kind -- no marker set, no `edm-lint-ignore` token anywhere in the function.
- **Divergence**: a fenced diagram legitimately wrapped in `edm-lint-ignore-start/end` scores BAD in dimension 3 while the linter reports nothing. `score-artifacts.sh:92-95` asserts the two "now agree on what counts as a fence **and what counts as a violation**."
- Genuinely defensible in one direction: an eval scorer arguably *should* measure raw generation quality rather than lint cleanliness, and it reads fresh agent-generated run artifacts where markers are unlikely. Reported anyway because CA-019 named this clause explicitly and the remediation closed the other three clauses without addressing or documenting this one.
- **Fix**: cheapest correct action is to narrow `:92-95` to state the carve-out and its reason ("suppression markers are deliberately not honoured here because dimension 3 measures generated-artifact quality, not lint cleanliness"), which converts an untrue claim into a documented divergence. Alternatively, thread a marker set through `_scan_mermaid_blocks` mirroring `edm-lint-artifacts`.

#### Finding 6 (P2): the four-signal trap save/install/restore sequence is hand-repeated six times in `bin/edm-state`, all of it Wave 4a code

- `write_atomic`: save at `:566-569`, install at `:575-578`, and the identical four-line `_restore_trap EXIT/INT/TERM/HUP` unwind **three times** at `:593-596`, `:608-611`, `:618-621`.
- `with_state_lock`: save at `:1014-1017`, install at `:1025-1028`, unwind at `:1049-1052`.
- `_restore_trap` (`:490-497`) was extracted -- but only the single-signal primitive; the four-call sequence wrapped around it was not.
- **Concrete cost already paid**: the CA-143 remediation added `HUP` to this class, which required six synchronized edits (four signals x save/install/restore across two functions). All six copies agree today, so this is prophylactic rather than a live bug -- but the next signal, or any change to restore order, needs six more coordinated edits in the file this initiative has already had to re-open for concurrency four times.
- Additionally, `write_atomic`'s three unwind blocks (`:590-597`, `:605-612`, `:615-622`) differ only in whether `return $ec` follows.
- **Fix**: add `_save_traps` / `_restore_traps` (four globals or one serialized string) to collapse six 4-line blocks into six 1-line calls, and `_write_atomic_unwind <nested> <tmp>` to collapse the three near-identical unwinds into one.

#### Finding 7 (P2): CA-156 residual -- `build_line_classes`' tab-separated record shape has seven independent parsers, four of them inline

- **In the library**: `bin/_edm-lint-lib.sh:169`, `:174`, `:179` -- three functions whose bodies differ only in the class string literal.
- **Inline in the canonical linter**: `bin/edm-lint-artifacts:295, :296, :297, :298` -- four copies of `printf '%s\n' "$_table" | awk -F'\t' '$2=="..."{print $1}'`, the fourth with a two-field `$1 "\t" $3` shape.
- The perf rationale at `:283-292` is sound and I accept it -- but it argues for not re-scanning the *file*, not for re-writing the *parser*. A library helper that takes the already-computed table on stdin satisfies both constraints at once, at zero extra awk invocations.
- CA-156's own text set the bar at "three independent parsers outside the library"; the count today is four outside plus three inside, so the record shape is still not single-sourced.
- **Fix**: add `project_class <class>` to `_edm-lint-lib.sh` reading the table on stdin; have the three library projections pipe through it and `edm-lint-artifacts` call it four times against `$_table`.

## Noted / Not Actionable

1. `bin/edm-state:4599` uses `print_help "$0"` where the other eleven callers use the `print_help "${BASH_SOURCE[0]:-$0}"` form `_edm-cli-lib.sh:24-27` prescribes -- the call sits inside the direct-execution guard at `:4554` and the comment at `:4552` states "BASH_SOURCE[0] equals $0 in that case." Documented as correct in place.
2. Four suites source `_harness.sh` via the long inline `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)` re-derivation (`wave3:12`, `wave4a:12`, `wave5:10`, `wave6:16`) while two use `"${SCRIPT_DIR}/_harness.sh"` (`wave4b:10`, `wave7:20`) -- the long form is the documented usage at `_harness.sh:4`, so both shapes are sanctioned; purely cosmetic.
3. `count_matches_strict` (`_harness.sh:177-186`) is a near-clone of `count_matches` (`:165-169`) with zero production callers -- but it is documented as an explicit alternative at `:163`, self-tested at `harness-smoke.sh:157-177`, and unlike `harness_scratch_dir` it leaves no duplicate behind, so it is redundancy with no duplication cost.
4. `mermaid_fence_run_len` (`edm-mermaid-rules.awk:122`) and `mermaid_fence_rest` (`:130`) each carry their own one-line `sub(/^[[:space:]]+/, "", body)` de-indent -- `mermaid_fence_rest` structurally needs the de-indented body itself, so factoring the line out buys nothing.
5. `bin/edm-check-skill-sync:49-73` hand-rolls its own `violations` counter, two report lines and the CLEAN/N-violations epilogue rather than sourcing `_edm-lint-lib.sh` -- its findings carry no line number so neither `report_violation` arity fits without a synthetic `0`, and it needs no line classification at all, so the dependency would exist for one 8-line function.
6. `die()` is defined independently in twelve scripts and `usage()` in five thin wrappers that disagree on whether they `exit` -- this is CA-074 (L7, open); not re-reported under L10.
7. CA-115, CA-116, CA-128, CA-129, CA-173 are already demoted in the ledger's *Decisions / Non-Findings* section; not re-investigated, per that section's instruction.
8. `evals/score-artifacts.sh:610` `cmd_compare` as a second comparison implementation alongside `bin/edm-compare-eval` -- CA-120, already NOTED as deliberate with the reason stated in place.

## Meta

- **CA-130 reproduced a third consecutive round**: this lens's frontmatter grants `Write`, but the delivered runtime tool set was `Read, Grep, Glob, WebFetch, WebSearch, TaskStop`. `SRD/edm/EDMV3__prompt-streamline/code-audit/pass-3_2026-08-08/` exists (it already holds `lenses-run.txt`), so the target directory is not the obstacle. The report above must be transcribed by the launching agent. This strengthens the case for CA-176's proposed explicit orchestrator-persists-both-halves fallback sentence in `skills/code-audit/SKILL.md`.
- Round-3 net: **3 of 10** open L10 ledger entries fully cleared this round (CA-010, CA-018, CA-096) on top of CA-005, CA-095 and CA-155 also now verified clear -- 6 of 10 resolved. The remaining four are partials, and two of the three *new* findings (3 and 4) are duplication the remediation itself introduced: a shared helper created, documented as adopted, and adopted nowhere.
