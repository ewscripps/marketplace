# Findings (L10: DRY & Redundancy) -- Round 11

**Round type**: full. **Delivery**: Write, Edit and Bash all absent from the delivered tool set
(CA-130, **twelfth** consecutive round for this lens). No command was executed; every verdict below
is from reading the tree at HEAD (0b2f304). This lens could not write its own two output files --
contents were returned inline to the orchestrator for persistence.

**Headline**: six of the seven open/new L10 items from round 10 are FIXED at HEAD. CA-502, CA-503,
CA-504 and CA-505 all closed; round-10 Finding 1 landed as CA-513 and round-10 Finding 2 as CA-533.
Only CA-459 carries (documented debt D60). One new P1 found: CA-515's remediation swept 1 of 6
copies of the threshold-shard filename spec, and the smoke suite now pins both the new and the
stale form.

## Part 1 -- Verification of every open L10 ledger entry against the current tree

| Ledger ID | Verdict | Evidence at HEAD |
|---|---|---|
| **CA-459** (P2, L10) -- `assert_tree_absent` vs hand-rolled positive-control blocks | **STILL OPEN, unchanged** | `assert_count_with_control` -- the second helper CA-459 prescribed for the expect-exactly-N family -- still does not exist (grep across `plugins/edm`: zero hits). The canonical helpers remain intact (`bin/tests/_harness.sh`, 11 occurrences of the `assert_tree_absent`/`count_matches_strict` family). The hand-rolled `grep -c ... \|\| true` shape survives at 66 sites: `wave7-smoke.sh` (56), `wave6-smoke.sh` (9), `timing.sh` (1). **Not re-filed** -- carried as documented debt D60 per the round-9 disposition; recorded here as confirmation only. |
| **CA-502** (P2, L10) -- bash-source-file glob written three times, one diverged | **FIXED** | Copy C now matches: `wave7-smoke.sh:1130` reads `for t61_f in "$PLUGIN_DIR"/bin/* "$PLUGIN_DIR"/bin/tests/*.sh "$PLUGIN_DIR"/evals/*.sh` -- `evals/*.sh` added, with the rationale at `:1124-1128` naming the exact gap (a syntax error in `run-eval.sh` caught by CI but not by a local `run-all.sh`, despite CLAUDE.md documenting them as the same check). The missing pin also landed: `:1166-1190` is a new CA-502 block that asserts the **glob-triple itself** (exactly 2 identical three-element for-loops in `.gitlab-ci.yml`, `:1174-1178`), asserts the twin iterates `evals/*.sh` (`:1180-1181`), and carries a discriminating positive control proving a two-element glob does *not* satisfy the three-element pattern (`:1183-1190`). The CA-233 exclusion-only pin at `:1148-1164` is retained alongside it. Both halves of the fix CA-502 prescribed are present. |
| **CA-503** (P2, L10) -- audit-type enum spelled out six times | **FIXED** | `AUDIT_TYPE_ENUM_LIST="code srd tickets"` now exists at `bin/edm-state:809` with a docstring at `:806-808`, beside the four constants that already obeyed the file's own `:799-803` convention. All six in-code sites now derive: `:4529` (usage, `${AUDIT_TYPE_ENUM_LIST// /\|}`), `:4533` (membership `case " $AUDIT_TYPE_ENUM_LIST "`), `:4535` (die message), `:4702`, `:4705`, `:4707`. Pinned at `wave7-smoke.sh:1201-1206`: the constant's literal value is asserted, and both `cmd_audit_round_start` and `cmd_audit_round_complete` bodies are extracted by awk and asserted to contain the membership idiom rather than a re-typed literal. |
| **CA-504** (P2, L10) -- provenance writers do not refresh HANDOFF | **FIXED** | `_cmd_set_provenance_field` at `bin/edm-state:5150-5166` now ends with `write_handoff_internal "$prefix"` at `:5165`. The deliberate asymmetry CA-504 flagged is now documented rather than accidental: `:5157-5162` states that `$other` is intentionally NOT existence-checked (a provenance link may name a not-yet-created follow-on) *and* that `write_handoff_internal` "is not conditional on that: HANDOFF.md must reflect the field this command just wrote regardless of whether the target exists yet". The same distinction is swept into `plugins/edm/CLAUDE.md`'s `supersedes` and `forked_from` state-field rows and its `related_prefixes` paragraph, all three citing CA-504 -- a clean `spec_swept: yes`. |
| **CA-505** (P2, L10) -- Coverage column width declared twice, disagreeing | **FIXED** | Both numbers corrected: `COVERAGE_LAYER_HEADER:1180` is now `%-11s` (matching `COVERAGE_LAYER_ROW_JQ_DEF:1147-1148`'s pct+`%`+9/8/7-space ladder = constant 11 columns) and `COVERAGE_EPIC_HEADER_MEASURED:1182` is now `%-10s` (matching `COVERAGE_EPIC_ROW_JQ_DEF:1156-1157`'s 8/7/6 ladder = constant 10). The comment at `:1165-1179` records the old values and why they were wrong ("they were previously 10 and 9 (off by one), which shifted every trailing Measured At column left by one against its header"), correctly exempts `COVERAGE_EPIC_HEADER` (Coverage is its last column), and honestly scopes the surviving fractional-pct gap. The missing pin also landed: `wave5-smoke.sh:131-144` now compares the **header+underline pair** across `get-coverage` and `metrics-report`, not just the data row. Third-round confirm-by-running request is discharged by inspection. |
| **Round-10 Finding 1** (P1, L10) -> **CA-513** | **FIXED, and fixed well** | `pattern_extract_titles` at `bin/edm-state:5326-5394` no longer hand-rolls a fence tracker. It computes the shared classifier's output once -- `ignored_line_set "$_pxt_report" 2>/dev/null > "$_pxt_ignfile"` at `:5342`, into a `mktemp` file released by a `trap ... RETURN` at `:5340-5341` -- and each awk arm skips those line numbers. The file-based hand-off is justified in-line at `:5334-5338` (a multi-line `-v` value is not portable; macOS awk rejects an embedded newline), citing `edm-lint-artifacts`' own precedent. The comment CA-513 was partly filed against is now honest: `:5317-5325` states the copy "now GENUINELY shares `pattern_insert_line_for`'s mechanism" and names both prior divergence axes explicitly. **Test coverage is real, not nominal**: `wave7-smoke.sh:4277-4315` adds a regression fixture with a `### CA-998` heading inside a **two-space-indented** fence nested under a numbered step (asserted absent, `:4308-4309`), a **four-backtick block quoting a three-backtick block** containing `### CA-996` (asserted absent, `:4310-4311`), and a real `### CA-997` immediately after that block asserted **present** (`:4312-4313`) -- which is the assertion that actually proves fence state did not desync. Residual filed as Finding 2 below. |
| **Round-10 Finding 2** (P2, L10) -> **CA-533** | **FIXED** | `PATTERN_AUDIT_TYPE_ENUM_LIST="srd ticket qc code test-coverage"` at `bin/edm-state:812` (docstring `:810-811`), consumed at `:5561` (usage), `:5565` (membership `case`), `:5567` (die message). The pin is stronger than the one Finding 2 prescribed: `wave7-smoke.sh:1208-1228` asserts the constant's value, asserts `cmd_update_patterns` validates via the membership idiom, and cross-checks **arm counts** of both per-type mapping `case` statements against the constant's word count, so a sixth audit type added to the list without a mapping arm fails a test. `:1230-1247` additionally pins the `pattern_extract_titles` per-type coverage and the `pattern_extraction_status_for` `ticket\|test-coverage` unsupported set with a wildcard-default assertion -- closing exactly the "miss the `pattern_extraction_status_for` arm and it silently reports `no-recognized-findings`" hole Finding 2 named. |
| **CA-512** (NOTED, L10) -- awk-program caching wrapper x3 | **Unchanged; disposition holds** | `_BLC_PROG_CACHE` (`bin/_edm-lint-lib.sh:103`, `:106-107`, `:189`), `_MSA_PROG_CACHE` (`bin/edm-lint-artifacts:226-227`, `:248`), `_SMB_PROG_CACHE` (`evals/score-artifacts.sh:327-328`, `:366`). Still three copies, still no behavioural divergence (copy A pre-initialises at file scope and tests `[[ -z "$_BLC_PROG_CACHE" ]]`; B and C use `${VAR:-}`). Remains NOTED, not re-filed. |
| **CA-115**, **CA-116**, **CA-128**, **CA-129** (NOTED, L10) | **Unchanged; dispositions hold** | No drift found. CA-128's zero-drift claim remains machine-enforced. |
| **CA-009**, **CA-010**, **CA-050**, **CA-093**, **CA-095**, **CA-096**, **CA-046**, **CA-018**, **CA-037** (fixed, L10) | **Still fixed; no regression** | `_edm-lint-lib.sh` remains the single home for `build_line_classes` / `is_ignored_line` / `report_violation`, enforced by `wave7-smoke.sh:468-474`. `ignored_line_set`'s external-caller set is computed and pinned at exactly three files (`wave7-smoke.sh:5161-5179`) -- and CA-513 kept that count correct by routing through the existing caller rather than adding a fourth. |
| **CA-376 `SRD_ROOT` premise** (recorded, not filed) | **Improved: five copies -> four** | `SRD_ROOT="${EDM_SRD_ROOT:-${CLAUDE_PLUGIN_OPTION_SRD_ROOT:-./SRD}}"` now appears at four sites (`bin/edm-init:18`, `bin/edm-state:65`, `bin/edm-lint-artifacts:74`, `bin/edm-validate-prefix:17`); `bin/edm-lint-staged-artifacts` no longer carries a copy. Still not re-filed -- four copies of a one-line env-var default chain is low value -- but see Noted for the standing premise correction. |

**Net on Part 1**: **six of seven** round-10 L10 items closed (CA-502, CA-503, CA-504, CA-505, CA-513, CA-533). CA-459 carries as D60 debt. No previously-fixed L10 finding regressed. Both round-10 findings were remediated with pins, and CA-513's remediation introduced only a much-reduced residual (Finding 2) rather than a new defect of equal severity -- the opposite of what happened to CA-476 last round.

## Part 2 -- New findings

| # | Type | File A | File B | Canonical | Recommendation |
|---|---|---|---|---|---|
| 1 | **Diverged parallel spec** (highest-priority L10 class) | `skills/implement/SKILL.md:107`, `:111` (updated) | `skills/implement/SKILL.md:84-85`; `agents/edm-qc-auditor.md:81`; `hooks/hooks.json:117`; `plugins/edm/CLAUDE.md:107`, `:696` (all stale) | the wave-keyed form at `skills/implement/SKILL.md:107`/`:111` | Sweep all five stale copies; **fix `wave7-smoke.sh:9388`, which currently pins the bug**; add a cross-file token-equality pin |
| 2 | Copy-pasted block x3 (residual of the CA-513 fix) | `bin/edm-state:5350-5351` | `bin/edm-state:5361-5362`, `:5383-5384` | neither -- extract a wrapper or pin the arm count | Fold into the CA-533 pin shape; add fence cases for the `srd` and `qc` arms |
| 3 | Duplicate enum literal (CA-503's class, in the eval scorer) | `evals/score-artifacts.sh:147` | `:44-58`, `:163-181`, `:670-671`; `evals/README.md:211-225`; `evals/baseline/README.md:89-113` | `DIM_NAMES:147` | Derive `--describe`'s name tokens from `DIM_NAMES`; leave prose docs |

### Details

#### Finding 1 (P1): CA-515's threshold-shard filename fix swept 1 of 6 copies of that spec -- the agent that actually writes the file still specifies the pre-fix name, and `wave7-smoke.sh` now machine-enforces both the new form and the stale form in the same assertion block

- **File A (the canonical, updated copy)**: `plugins/edm/skills/implement/SKILL.md:107` and `:111` --
  the threshold-sharding pseudo-code now writes
  `qc/qc-shard-pass-w{wave_num:02d}-01.md` (single-shard branch) and
  `qc/qc-shard-pass-w{wave_num:02d}-{i+1:02d}.md` (multi-shard branch). The rationale is recorded at
  `:112-119`: "with an ordinal-only name, wave 2's single-shard pass (ticket_count <= threshold)
  reuses the exact filename wave 1's did (`qc-shard-pass-01.md`) and silently overwrites wave 1's
  PASS/FAIL verdicts, which (like CA-473's hook-vs-threshold collision) are never persisted anywhere
  else."
- **File B (five stale copies, all still specifying the ordinal-only name the fix was meant to
  retire)**:
  1. `plugins/edm/skills/implement/SKILL.md:84-85` -- **the same file, 22 lines above the fixed
     pseudo-code**, in the normative "**QC output paths**" bullet list: "Threshold-shard (this
     skill's post-wave QC) auditor: `<initiative-dir>/qc/qc-shard-pass-{NN}.md`, where `{NN}` is the
     **shard ordinal** (1-based, zero-padded), not a ticket number." A reader of the fixed file gets
     two different answers 22 lines apart.
  2. `plugins/edm/agents/edm-qc-auditor.md:81` -- **the writing agent's own output contract**:
     "`<initiative-dir>/qc/qc-shard-pass-{NN}.md`, where `{NN}` is your **shard ordinal** N,
     zero-padded (e.g. `qc-shard-pass-01.md`) -- never a ticket number." The worked example is
     literally the colliding filename.
  3. `plugins/edm/hooks/hooks.json:117` -- the `SubagentStop` prompt: "`qc-shard-pass-{NN}.md` is the
     separate namespace owned by /edm:implement's own post-wave threshold-shard auditors, keyed by
     shard ordinal rather than by ticket number".
  4. `plugins/edm/CLAUDE.md:107` -- the artifact-layout tree: "`qc-shard-pass-{NN}.md` <- post-wave
     threshold shards ({NN} = shard ordinal)".
  5. `plugins/edm/CLAUDE.md:696` -- the `SubagentStop` hooks-behavior row: "`qc-shard-pass-{NN}.md`,
     the namespace `/edm:implement`'s own post-wave threshold shards use ({NN} = shard ordinal)".
- **Divergence and its consequence**: the two specs name different files. Per
  `plugins/edm/CLAUDE.md`'s own **intent-to-file index** ("What the explorer agent explores and how
  it reports | `agents/edm-explorer.md`"), an agent's own file is authoritative for how that agent
  reports -- so the authoritative spec for the threshold shard's filename is
  `agents/edm-qc-auditor.md:81`, which still says `qc-shard-pass-01.md`. A wave-2 sub-threshold QC
  pass therefore writes the same filename wave 1 wrote and **silently discards wave 1's PASS/FAIL
  verdicts**, which `skills/implement/SKILL.md:90-91` confirms live nowhere else ("Only PARTIAL
  verdicts survive elsewhere (via the locked `record-partial-verdict`); PASS and FAIL live ONLY in
  these markdown files"). That is precisely the clobber CA-515 was filed to close, unfixed at the
  only site that governs the writer's behaviour.
- **Why this is invisible to CI -- the suite pins both sides of the contradiction**:
  - `plugins/edm/bin/tests/wave7-smoke.sh:9387-9388` asserts the literal string
    `qc/qc-shard-pass-{NN}.md` **is present** in `agents/edm-qc-auditor.md` (a CA-473-era check).
  - `plugins/edm/bin/tests/wave7-smoke.sh:9396-9399` asserts the wave-component form
    `qc-shard-pass-w{wave_num:02d}-01.md` / `-{i+1:02d}.md` **is present** in
    `skills/implement/SKILL.md`.
  Both are green today, so the suite actively enforces the stale spec in one file and the new spec in
  another. `:9388` is not merely failing to catch the bug -- it pins it.
  The CA-515 "positive control" at `:9400-9404` only `sed`-transforms the skill file's own string and
  re-checks the same file, so it proves the pattern discriminates but is structurally incapable of
  detecting an unswept sibling document.
- **What is NOT broken (checked, so the fix stays scoped)**: the merge step is unaffected. The
  `qc-shard-pass-*.md` glob at `skills/implement/SKILL.md:39`, `:93-94`, `:122`,
  `agents/edm-qc-auditor.md:85`, `hooks/hooks.json:117` and `bin/edm-state:2642` matches the
  wave-prefixed name unchanged -- exactly as the CA-515 comment at `:118-119` claims. The
  `qc-shard-impl-` / `qc-shard-pass-` **namespace disjointness** (CA-473) also still holds under
  either shape, and `wave6-smoke.sh:2076-2093` still exercises both shapes completing phase 6. The
  defect is purely the un-swept filename spec.
- **False Alarm Filter**: (1) Not a justified difference -- nothing anywhere records a decision to
  give the agent a different filename from the skill that spawns it, and the CA-515 comment's stated
  intent is that the wave component *is* the name. (2) Not test-only -- four of the five stale copies
  are production prompt surfaces (`skills/`, `agents/`, `hooks/`), and the fifth pair is the
  contributor-facing spec. (3) Not a circular-dependency workaround -- the multi-surface duplication
  itself is the accepted prompt-surface pattern here (each agent reads only its own file), which is
  exactly why the sweep obligation exists and why `wave7-smoke.sh:9379-9388` pins the tokens
  cross-file in the first place.
- **Secondary observation (CA-416 class)**: this is also a `spec_swept` failure. The CA-515
  remediating change altered a behavior-governing filename and left five documented copies naming the
  old one, so a `spec_swept: yes` on that entry would be incorrect. Worth checking the ledger entry's
  recorded value.
- **Confidence**: high on the divergence and on the contradictory pins (all six sites and both
  assertions read directly at HEAD). Medium on live frequency -- it requires a multi-wave initiative
  with at least one wave at or below `qc_shard_threshold`.
- **Fix**:
  1. Sweep all five stale copies to the wave-keyed form. `agents/edm-qc-auditor.md:81` is the
     load-bearing one and must change first; replace its `qc-shard-pass-01.md` example with
     `qc-shard-pass-w01-01.md`.
  2. **Change `wave7-smoke.sh:9388`** from asserting `qc/qc-shard-pass-{NN}.md` to asserting the
     wave-component form in `agents/edm-qc-auditor.md`. As written it pins the defect.
  3. Add a cross-file pin in the shape `ca473_tokens` (`wave7-smoke.sh:9340-9375`) already uses:
     extract the `qc-shard-pass-*` filename token from each of the six surfaces and assert all six
     are equal, so the next single-site edit fails a test instead of shipping. That is the structural
     fix -- item 2 alone would leave the other four surfaces unpinned.

#### Finding 2 (P2): the CA-513 fix left the ignored-line-set awk prelude copy-pasted three times inside one function, and only one of the three arms has a fence regression case

- **File A / File B (three byte-identical copies, 34 lines apart, in one function)**:
  `plugins/edm/bin/edm-state:5350-5351`, `:5361-5362`, `:5383-5384`. Each arm of
  `pattern_extract_titles` opens its awk program with the same two lines:
  ```
  BEGIN { while ((getline _pxt_ln < ignfile) > 0) if (_pxt_ln != "") skip[_pxt_ln] = 1 }
  (NR in skip) { next }
  ```
- **What CA-513 correctly fixed, and what it left**: the fence *classification* is now genuinely
  single-sourced -- `ignored_line_set` is called exactly once, at `:5342`, and the shared
  de-indenting, run-length-aware classifier in `bin/_edm-lint-lib.sh` /
  `bin/edm-mermaid-rules.awk` is the only fence authority in the function. That was the whole of the
  P1. What remains is the *consumption* boilerplate: the two-line prelude that loads the skip set and
  applies it.
- **Divergence**: none today -- all three copies are byte-identical. The finding is the extension
  cost and the untested surface, not a live behavioural difference.
- **Why it is worth a P2 rather than a NOTED**: adding a sixth audit type is explicitly contemplated
  in two places (`bin/edm-state:5313`, "adding the matching arm here and the matching row to the
  README"; `docs/audit-patterns/README.md:71`). A new arm that copies the awk skeleton but drops
  `(NR in skip) { next }` silently re-opens CA-476/CA-513 **for that audit type only**, and nothing
  in the suite would catch it: the CA-513 regression block (`wave7-smoke.sh:4277-4315`) drives
  `_ca476_extract code` only. The `srd` arm (`:5360-5369`) and `qc` arm (`:5382-5391`) each carry
  their own independent copy of the prelude and have **no indented-fence and no long-fence case at
  all** -- their fence-awareness is asserted nowhere. So the property "every arm honours the shared
  ignore set" is currently verified for one arm out of three.
- **False Alarm Filter**: (1) Not a justified difference -- the three copies are identical, so there
  is no per-arm requirement being expressed. (2) Not test-only. (3) Not a circular-dependency
  workaround -- the shared library is already sourced at `bin/edm-state:63`.
- **Confidence**: high on the duplication and on the single-arm test coverage (both read directly).
- **Fix** (either is sufficient; the second is cheaper):
  - Extract a one-line helper that prepends the prelude to an arm-specific program body, so the skip
    contract exists once; or
  - Add a `count_matches_strict` pin asserting the number of `(NR in skip) { next }` occurrences in
    `pattern_extract_titles` equals the number of *supported* audit types -- derivable as
    `PATTERN_AUDIT_TYPE_ENUM_LIST` word count minus the two names in the `ticket|test-coverage`
    early-return arm. `wave7-smoke.sh:1217-1228` is already exactly this shape for the mapping-arm
    counts, so this is a copy of an established local idiom.
  - Independently of either: extend the CA-513 fixture to drive the `srd` and `qc` arms with an
    indented fence, so the untested two-thirds becomes tested.

#### Finding 3 (P2): the eval scorer's six dimension names are a second instance of the CA-503/CA-533 class -- one canonical list plus four re-encodings, one of them in code

- **File A (canonical)**: `plugins/edm/evals/score-artifacts.sh:147` --
  `DIM_NAMES=(requirement-id-coverage ac-testability mermaid-parse-success
  coverage-map-bidirectionality lens-jsonl-prose-agreement known-gap-recall)`. This is the list every
  consumer *should* derive from, and `build_dims_json:582` and `build_skipped_json:599` correctly do.
- **File B (re-encodings)**:
  - `evals/score-artifacts.sh:163-181` -- the `--describe` output re-types all six names as prose
    literals. **This is the one in-code second copy.**
  - `evals/score-artifacts.sh:44-58` -- the header docstring re-lists all six.
  - `evals/score-artifacts.sh:670-671` -- `DIM_SCORES=("$D1_SCORE" ... "$D6_SCORE")` and
    `DIM_REASONS=(...)`: two further six-element arrays that must stay index-aligned with `DIM_NAMES`
    by hand.
  - `evals/README.md:211-225` and `evals/baseline/README.md:89-113` re-list all six as prose/JSON.
- **Divergence**: none today. Filed for the same reason CA-503 and CA-533 were: the plugin has
  adopted a "one list, many derivations" convention in `bin/edm-state` (`:799-803`, now honoured by
  six constants) and this file does not follow it. Adding a seventh dimension today costs edits at
  `DIM_NAMES`, `DIM_SCORES`, `DIM_REASONS`, a scorer function, the `--describe` block, the docstring,
  and two READMEs.
- **What reduces this finding's weight, stated plainly**: the *count* is machine-pinned at six
  (`wave7-smoke.sh:648`, `:686`) and `--describe`'s six names are individually pinned
  (`:858`, `:863`), so a silent name drift between `DIM_NAMES` and `--describe` fails a test. The
  index alignment is also indirectly protected -- `dimensions_scored` is read from the data rather
  than assumed (`score-artifacts.sh:684-692`, documented at `evals/README.md:234`), and a malformed
  array fails a `jq` parse immediately. This is genuinely the weakest of the three findings and is
  filed at P2 for convention consistency, not because a live bug is reachable.
- **False Alarm Filter**: the six per-dimension scorer functions and their `D{N}_SCORE`/`D{N}_REASON`
  skip idioms are per-dimension **data and logic**, not duplicated logic -- `score_from_ratio` is
  already correctly shared by all six, and `_scan_mermaid_blocks` correctly consumes the shared
  `edm-mermaid-rules.awk`. Those are not the finding. The prose re-listings in the two READMEs are
  documentation and should stay readable. The finding is narrowly the `--describe` block at
  `:163-181`.
- **Confidence**: high on the duplication; medium on whether it is worth the fix given the existing
  pins.
- **Fix**: derive `--describe`'s dimension-name tokens from `DIM_NAMES` (interpolate the array member
  into each numbered paragraph) so the one in-code re-encoding disappears; leave the docstring and
  the two READMEs as prose. Optionally add a pin asserting
  `${#DIM_NAMES[@]} == ${#DIM_SCORES[@]} == ${#DIM_REASONS[@]}`.

## Noted / Not Actionable

**Confirmed present, already filed, deliberately not re-filed:**
- **CA-459** -- re-confirmed: `assert_count_with_control` still absent, 66 hand-rolled
  `grep -c ... || true` sites. Carried as documented debt D60; excluded from re-filing per the
  standing instruction.
- **CA-512** -- three-copy awk-caching wrapper unchanged (`_edm-lint-lib.sh:103`/`:106-107`/`:189`,
  `edm-lint-artifacts:226-227`/`:248`, `score-artifacts.sh:327-328`/`:366`). NOTED disposition holds.
- **CA-128 / CA-129 / CA-115 / CA-116** -- unchanged; dispositions hold.

**Swept this round and cleared -- no finding:**
- **`hooks/hooks.json` re-checked for drift, none found.** The five `UserPromptExpansion` command
  strings (`:19`, `:32`, `:45`, `:58`, `:71`) are byte-identical modulo the gate token; the five
  prompt bodies (`:23`, `:36`, `:49`, `:62`, `:75`) likewise, with `edm:implement`'s extra Gate-3.5
  clause at `:75` additive rather than divergent. `Stop:96` and `PreCompact:106` remain
  byte-identical. Same CA-376 rationale (JSON has no include mechanism). Not filed.
- **`.gitlab-ci.yml`'s `lint:hooks-shell` writes its jq select-chain three times** (the
  `EXPECTED_COUNT` expression, the `WELLFORMED` variant at `:329`, and the indexed extraction at
  `:340`). Cleared: the three are deliberate variants of one walk (total, narrowed-to-usable, and
  per-index), the comment at `:323-327` documents the narrowing explicitly, and any divergence
  between the count chain and the extraction chain is caught loudly by the `COUNT` vs
  `EXPECTED_COUNT` cross-check at `:356` -- the very mechanism CA-437/CA-474 added. Self-guarded
  triplication, not drift-prone duplication.
- **`wave7-smoke.sh:7546`, `:7594`, `:7709`** -- three copies of a narrower
  `UserPromptExpansion ... select(.type == "command") | .command` jq chain, one per assertion.
  Test-side; cleared under False Alarm Filter 2.
- **`wave7-smoke.sh:7985`** -- the hand-rolled `/^```/ { infence = !infence; next }` toggler is now
  the **only** one left in the tree; CA-513 removed the other three. Still test-side, still scanning
  `SKILL.md` for leaked `srd_root` path literals *inside* fences (so a missed indented fence widens
  rather than narrows the scan). Cleared under Filter 2 -- but it is now a single isolated instance
  and is the cheapest possible follow-on to CA-513 if anyone wants the idiom gone from the tree
  entirely.
- **`evals/score-artifacts.sh:580-595` vs `:597-610`** (`build_dims_json` / `build_skipped_json`) --
  unchanged from the round-10 NOTED. Two ~14-line loops sharing the index-tracking, comma-separator
  and array-wrapping scaffold, differing in the emitted object and one skip condition. Mechanical; a
  separator bug fails a `jq` parse immediately. Recorded, not filed.
- **`evals/run-eval.sh:474-588`** (CA-283's three phase blocks) -- re-checked, unchanged. Still
  copy-pasted in shape, still semantically equivalent, CA-283's prescribed `run_phase` extraction
  still the right fix. No escalation, no re-file.
- **The `qc-shard-impl-` / `qc-shard-pass-` namespace prose across six surfaces** -- the *duplication*
  is the accepted prompt-surface pattern (each agent reads only its own file) and is pinned
  cross-file at `wave7-smoke.sh:9379-9388` and `wave4b-smoke.sh:36`. Not filed as duplication; it is
  the **divergence** within it that is Finding 1.
- **`bin/edm-state`'s `now_utc()`** -- single definition at `:757-758`, and the only other
  `date -u +"%Y-%m-%dT%H:%M:%SZ"` occurrences are in test harness/fixture code
  (`_harness.sh:418`, `wave6-smoke.sh:4469`) that cannot source the CLI's helper. `run-eval.sh:365`
  uses a deliberately different compact format for directory names. No duplication finding.
- **`bin/_edm-lint-lib.sh`** -- `build_line_classes` remains the single definition; `is_ignored_line`
  at `:192`, `ignored_line_set` at `:209`. Enforced by `wave7-smoke.sh:468-474`. The
  external-caller count is computed and pinned at exactly three (`:5161-5179`), and CA-513 kept it
  correct by routing through an existing caller. No regression.
- **`SPEC_SWEEP_DEBT_FILTER` / `BLOCKING_FILTER`** -- re-checked, still one predicate per concern
  with multiple consumers. Correctly DRY. Not filed.

**One standing disposition premise, re-recorded (not a re-file), third consecutive round:** CA-376
dispositions the `SRD_ROOT` duplication on the ground that "the four independent `SRD_ROOT`
derivations have no shared library they could source first". The count half is now **accurate** (four
copies, down from five -- `bin/edm-lint-staged-artifacts` no longer carries one), but the second half
is still false: all four scripts source `bin/_edm-cli-lib.sh`. I am again not re-filing the
duplication itself -- four copies of a one-line env-var default chain is low value -- but the
disposition's stated reason should be corrected so a future round does not keep skipping it on a
premise that no longer holds.

**Tooling caveat for the synthesizer:** CA-130 reproduced for a **twelfth** consecutive round on this
lens -- Write, Edit and Bash all absent; delivered set was Read, Grep, Glob, WebFetch, WebSearch,
TaskStop. Consequence this round: **this lens could not write `lens-L10.md` or `lens-L10.jsonl`
itself** and returned both files' contents inline to the orchestrator for persistence. Every verdict
above is nonetheless read directly from the tree at HEAD and is high confidence except where marked;
CA-505's rendered column output remains the one item a single command would have settled by
observation rather than by reading format strings, now for a fourth round -- though the fix is
verifiable by inspection and is recorded as FIXED on that basis.
