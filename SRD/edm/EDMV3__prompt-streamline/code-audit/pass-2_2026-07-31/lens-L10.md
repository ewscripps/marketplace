# Code Audit Lens L10: DRY & Redundancy

- **Date**: 2026-07-31 | **Round**: pass-2 (full, 11 lenses) | **Branch**: `edm/edmv3-prompt-streamline`
- **Method**: every L10-tagged round-1 finding re-checked against the current tree at its cited site,
  then a fresh full-scope pass. Verified by reading, not by running (no Bash tool at runtime).

## Verdict on the centerpiece

`plugins/edm/bin/_edm-lint-lib.sh` **exists and is genuinely sourced** -- by `bin/edm-lint-artifacts:52`,
`bin/edm-check-grants:101` and `bin/edm-check-vocabulary:57`. The fence state machine, the ignore-marker
handling and `is_ignored_line`/`report_violation` now live in exactly one place: a grep for definitions of
`build_line_classes`, `build_ignore_set`, `is_ignored_line` and `report_violation` across `plugins/edm/`
returns only `_edm-lint-lib.sh:3`, `:80`, `:85`. No hand-copy survives in any of the three `bin/` scripts.
`build_ignore_set` no longer exists anywhere in `bin/`.

**But the third consumer named in the prescription was skipped.** `evals/score-artifacts.sh` does not source
the library, `bin/edm-mermaid-rules.awk` was never created, and the scorer's Mermaid rule was brought into
agreement by **copying the canonical body verbatim** rather than by extraction. Where round 1 found two
diverged copies, round 2 finds two byte-for-byte-equivalent copies with no guard holding them together --
one edit away from reproducing CA-019 exactly. That is the single most important item in this report.

## Findings (L10: DRY & Redundancy)

| # | Sev | Type | File A | File B | Canonical | Recommendation |
|---|---|---|---|---|---|---|
| 1 | P2 | Diverged/cloned parallel impl (CA-019, re-open) | `evals/score-artifacts.sh:248-335` | `bin/edm-lint-artifacts:140-211` | `bin/edm-lint-artifacts` | Rule body is now a clone, not a divergence -- but fence recognition and ignore-marker handling still differ. Extract `bin/edm-mermaid-rules.awk` as prescribed |
| 2 | P2 | Restated canonical table, diverged (CA-018, re-open) | `agents/edm-audit-synthesizer.md:85-90` | `agents/edm-srd-auditor.md:65-70` | `CLAUDE.md:216-221` | Legacy scale is gone; the abridged restatement is not. Delete both bullet lists, keep the by-name sentence |
| 3 | P2 | Duplicate utility, 12 copies / 3 shapes (CA-005 L10 half, re-open) | `bin/edm-state:97-99` + 11 more | `bin/edm-sync-canonical-sections:43` | one shared `print_help` | `sed -n '2,45p'` is gone; the copies grew from 5 to 12. Put `print_help` in the shared lib |
| 4 | P2 | Duplicate function (NEW) | `bin/edm-check-grants:127-130` | `bin/edm-check-vocabulary:134-137` | `bin/_edm-lint-lib.sh` | Byte-identical 4-line `ignored_line_set`; the extraction stopped one function short |
| 5 | P2 | Compatibility shim papering over caller divergence (NEW) | `bin/_edm-lint-lib.sh:95-99` | `bin/edm-check-grants:125` vs `edm-lint-artifacts:125` | the callers | The library branches on two spellings of one global; a caller that declares neither is silently uncounted |
| 6 | P2 | Copy-pasted block (CA-096, unchanged) | `bin/tests/run-all.sh:116-131` | `bin/tests/run-all.sh:133-148` | one helper | Still two copies; the predicted third-checker cost has already materialised |
| 7 | P2 | One fact in eleven places, wrong in all eleven (CA-095, worse) | `agents/edm-audit-dry.md:71` + 10 siblings | `skills/code-audit/SKILL.md:59` | the skill | Citation still says `:40`; the target moved from 45 to 59, so the drift grew |
| 8 | P2 | Redundant repeated work (CA-094, unchanged) | `bin/tests/wave7-smoke.sh:1035,1864,2009,2288,2398,2505,2596` | `:3075-3079` | the capture | Seven `--all` scans and 13 `edm-check-grants` runs remain; no grants capture was added |
| 9 | P2 | Divergent derivations of one value (CA-049 L10 half, unchanged) | `bin/tests/wave4b-smoke.sh:6`, `timing.sh:26`, `wave6-smoke.sh:714` | `bin/tests/_harness.sh:39-40` | `_harness.sh` | Four `PLUGIN_DIR` shapes, five inline re-derivations, three identical TMP/trap triples |
| 10 | P2 | Test pins a symbol that no longer exists (CA-010 residue, re-open) | `bin/tests/wave7-smoke.sh:296-299` | `bin/tests/wave7-smoke.sh:1683`, `:2723` | the code | Code half fixed; the assertion still greps `build_ignore_set` and its label still claims "mirrors" |

### Confirmed FIXED this round

| ID | Sev (r1) | Evidence |
|---|---|---|
| CA-050 | P2 | `bin/_edm-lint-lib.sh` created and sourced by all three `bin/` consumers; zero surviving copies of the three helpers |
| CA-009 | P1 | Both checkers now call the shared `build_line_classes`, which de-indents at `_edm-lint-lib.sh:28` and does CommonMark run-length fence matching at `:30-51`. One implementation cannot diverge from itself |
| CA-046 | P2 | `.gitlab-ci.yml:42-44` `.alpine_edm` and new `:46-48` `.node_edm`; each digest string appears exactly once; `validate:manifest:373`, `validate:plugin-cli:481`, `eval:nightly:519` all consume an anchor |
| CA-093 | P2 | `audit_required_for_mode_or_legacy()` extracted at `bin/edm-state:678-685`, consumed at `:707` and `:1455`; no third copy; the stale "mirrors cmd_archive" comment is gone and `:698-700` documents the deliberate split |

---

### Details

#### Finding 1 (CA-019, re-open at P2): the scorer's Mermaid rule is now a byte-for-byte clone instead of a divergence

- **File A**: `plugins/edm/evals/score-artifacts.sh:248-335` -- `_scan_mermaid_blocks`, with `strip_entities`
  at `:256-277` and `is_violation` at `:278-299`.
- **File B**: `plugins/edm/bin/edm-lint-artifacts:140-211` -- `mermaid_scan_awk`, with `strip_entities` at
  `:150-161` and `is_violation` at `:162-193`.
- **What was fixed**: all seven rule-body divergences round 1 named are closed. The curly-label form is
  present (`score-artifacts.sh:289`), the sequenceDiagram message rule is present (`:293-297`), entity
  stripping is now the identical explicit 1..10 walk (`:256-277` vs `:150-161`), the trailing-terminator
  strip is present (`:285`), the three `%%` / `classDef` / `style` / `linkStyle` exemptions are present
  (`:280-282`), and the five bracket character classes are identical (`:287-291` vs `:180-184`). Compared
  line by line: the two `is_violation` bodies differ only in brace/whitespace layout. The two committed
  fixtures that round 1 proved scored OK -- `invalid/i04-curly-label.md` and `invalid/i05-sequence-message.md`
  -- would now be caught.
- **Divergence that remains**: fence recognition and ignore markers were not brought over.
  `score-artifacts.sh:303` opens a block only on `/^```[Mm][Ee][Rr][Mm][Aa][Ii][Dd][[:space:]]*$/` and
  `:311` closes only on `/^```[[:space:]]*$/` -- anchored at column 1, exactly three backticks, no info-string
  suffix tolerated. The canonical `_edm-lint-lib.sh:27-51` de-indents (`sub(/^[[:space:]]+/, "", fence_body)`)
  and matches by run length, which is the very change CA-009 existed to propagate. The plugin ships
  `bin/tests/fixtures/mermaid/valid/v12-indented-fence.md` for exactly this case; an indented mermaid fence
  is invisible to the scorer, so dimension 3 silently under-counts rather than mis-scores. The scorer also
  has no `edm-lint-ignore` / `edm-lint-ignore-start` / `-end` handling at all, while the canonical class 4
  filters on `EDM_MARKER_SET` and emits a `U` record for a misused single-line marker
  (`edm-lint-artifacts:203-207`), so `valid/v08-block-form-ignore-escape.md` and
  `valid/v09-fence-open-marker-escape.md` are scored by a rule the linter does not apply.
- **Why this is still a finding and not a false alarm**: the scorer's own header at `:64-82` states the
  duplication is real, names EDMV3-111, and says "the de-duplication worth doing ... is to lift the shared
  semicolon-detection awk into one sourceable file both consume. That is a bin/ change and is not attempted
  here." That is an acknowledgement that the work is owed, not a documented decision to keep two copies --
  and the stated blocker ("that is a bin/ change") is discharged: a `bin/` change landed this cycle in the
  form of `_edm-lint-lib.sh`. The three reasons for not calling the linter directly (dimension 3 is a
  genuine superset, needs a per-block verdict stream, must never exit non-zero) remain sound and are not
  disputed; none of them argues against a shared `awk -f` rule file.
- **Fix**: lift `strip_entities` + `is_violation` into `plugins/edm/bin/edm-mermaid-rules.awk` and consume
  it from both sides with a two-`-f` awk invocation, exactly as prescribed. That keeps the scorer's framing,
  verdict stream and exit-0 contract untouched. Then port the fence recognition: either have the scorer
  consume `build_line_classes`' `mermaid` and `marker` sets, or at minimum de-indent before matching.
  Add one assertion that the two rule bodies are the same file.
- **Grading note**: reported P2, not P1, because the "produces wrong answers on committed fixtures today"
  basis for the P1 is discharged for the rule body. The residual is a 45-line unguarded clone plus two
  narrower behavioural gaps. Since `BLOCKING_FILTER` includes P2 this does not change convergence, but the
  synthesizer may reasonably keep it at P1 given it is the last surviving limb of root cause 1.

#### Finding 2 (CA-018, re-open at P2): the legacy scale is gone, the diverged restatement is not

- **File A**: `plugins/edm/agents/edm-audit-synthesizer.md:85-90`.
- **File B**: `plugins/edm/agents/edm-srd-auditor.md:65-70` -- the two blocks are identical to each other.
- **Canonical**: `plugins/edm/CLAUDE.md:216-221`.
- **What was fixed**: the abolished legacy P1/P2/P3 definitions are gone. `grep -rn` for
  `Defensive improvements` / `operational friction` across `plugins/edm/agents` and `plugins/edm/skills`
  returns nothing; the only surviving occurrences are `CLAUDE.md:226-229` and its generated copy
  `docs/canonical-sections.md:25-28`, both of which are the canonical backward-compatibility mapping and
  are correct there. The third copy, `skills/code-audit/SKILL.md`, is fully fixed: `:252` now reads
  "Use the canonical P0/P1/P2/NOTED vocabulary from `CLAUDE.md Sec."Severity vocabulary"` -- no local
  restatement or legacy relabeling" with no table. All eleven lens agent files carry the by-name sentence
  and **no restatement of any kind** -- verified individually at `edm-audit-dry.md:77`,
  `edm-audit-consistency.md:75`, `edm-audit-runtime.md:80`, `edm-audit-spec.md:84`, `edm-audit-wiring.md:90`,
  `edm-audit-logic.md:73`, `edm-audit-dead-code.md:71`, `edm-audit-test-quality.md:73`,
  `edm-audit-docs.md:75`, `edm-audit-edge-cases.md:75`, `edm-audit-security.md:81`. No lens, including this
  one, carries a stale P1/P2/P3 scale anywhere.
- **Divergence that remains**: both surviving copies are abridged against the canonical, row by row.
  P0 canonical is "Critical -- blocks implementation, security/legal issue, production failure, or
  architecturally wrong"; both copies read "Critical -- blocks implementation, security/legal, production
  failure", dropping "or architecturally wrong". P1 canonical is "Significant -- material gap, factual
  error, missing requirement, or behavior that must be corrected before shipping"; both copies read
  "Significant -- material gap, factual error", dropping "missing requirement" -- the exact clause round 1
  named as the concrete consequence, in the agent that assigns ledger severity. P2 drops "or nice-to-have";
  NOTED is reworded.
- **Second defect, new this round**: the sentence immediately above each list reads "Do not restate or
  adapt a local scale. The canonical meanings are:" and is then followed by an adapted local restatement.
  The instruction contradicts the four lines under it, in a prompt whose whole job is to be unambiguous.
  This is a half-applied edit: the prohibition was added, the thing it prohibits was left in place.
- **Fix**: delete `edm-audit-synthesizer.md:87-90` and `edm-srd-auditor.md:67-70` and keep the by-name
  sentence alone, as the eleven lenses and `skills/code-audit/SKILL.md` already do. If a summary must
  remain, copy CLAUDE.md's Definition column byte for byte.
- **Context**: the prescription said "keep the by-name reference plus the plugin-relative fallback that
  CA-013 lands". That fallback did not land -- `grep -rn 'docs/canonical-sections\.md' plugins/edm/agents
  plugins/edm/skills` still returns zero hits, so the generated file at `docs/canonical-sections.md` still
  has no consumers. CA-013 is L9/L11's finding and is not re-filed here, but its non-landing is the
  standing reason authors keep restating the table.
- **Disclosure**: `agents/edm-audit-dry.md` is this lens's own definition file and
  `agents/edm-audit-synthesizer.md` is the file of the agent that will grade this report. Both are in
  scope, both were read, and this round was graded against `CLAUDE.md:216-221`.

#### Finding 3 (CA-005 L10 half, re-open at P2): the truncating `sed` is gone; the duplication grew from 5 copies to 12

- **What was fixed**: the `usage() { sed -n '2,45p' "$0"; exit 0; }` anti-pattern is gone.
  `bin/edm-check-grants` now carries `# EDM-HELP-BEGIN` / `# EDM-HELP-END` at `:2` / `:59` covering the full
  header including the Output format, the Exit codes contract and the bash-3.2 note, extracted by
  `print_help` at `:62-64`. `evals/run-eval.sh:56-58` and `evals/score-artifacts.sh:90-92` likewise.
  `bin/edm-init:20-22` and `bin/edm-validate-prefix:20-22` now have help blocks and a
  `-h|--help|help` dispatch (`edm-init:38`). The P1 basis -- a silently truncated exit contract -- is
  discharged. Other lenses own the dispatch-uniformity and exit-code axes of CA-005.
- **What was not fixed**: the prescription was "call the shared extractor `print_help`, which the shared
  library in CA-050 should own". The shared library landed and `print_help` did not go into it. The
  one-line extractor is now hand-written twelve times in three mutually incompatible shapes:
  - Shape A, `awk '/^# EDM-HELP-BEGIN/{f=1;next} /^# EDM-HELP-END/{f=0} f' <file>`, which **keeps** the
    leading `# ` on every output line -- eight copies: `bin/edm-state:98`, `bin/edm-check-grants:63`,
    `bin/edm-init:21`, `bin/edm-validate-prefix:21`, `bin/edm-lint-artifacts:61` (inlined in `usage()`
    rather than a named function), `bin/edm-check-vocabulary:70` (also inlined), `evals/run-eval.sh:57`,
    `evals/score-artifacts.sh:91`.
  - Shape B, `awk '/^# EDM-HELP-BEGIN$/{f=1;next} /^# EDM-HELP-END$/{exit} f{sub(/^# ?/,"");print}' <file>`,
    anchored, terminating with `exit`, and **stripping** the `# ` prefix -- three copies:
    `bin/edm-check-skill-sync:28`, `bin/edm-compare-eval:35`, `evals/tiering-matrix.sh:67`.
  - Shape C, `awk '/^# edm-sync-canonical-sections/{f=1} f{print} /^set -euo pipefail/{exit}' "$0" | sed '$d'`
    -- `bin/edm-sync-canonical-sections:43`. This is the variant round 1 named explicitly: it has no
    sentinels at all, is keyed on the literal `^set -euo pipefail`, and needs a `sed '$d'` to trim the line
    it over-reads. Moving or duplicating that one line silently changes what `--help` prints.
  - The file argument splits three further ways: `"$0"` (five sites), `"${BASH_SOURCE[0]}"` (three),
    and `"$1"` supplied by the caller (three).
- **Observable divergence**: `--help` emits `# `-prefixed lines on eight scripts and clean prose on three.
  A thirteenth hand-copy of Shape A sits in the test suite at `bin/tests/wave7-smoke.sh:599`
  (`_t61_help_subcommands`), which the prescription also asked to point at the shared function.
- **Fix**: one `print_help <script-path>` in the shared library (or a second tiny `bin/_edm-cli-lib.sh` if
  a lint library is the wrong home), sourced by all nine `bin/` helpers and the three `evals/` scripts;
  convert `edm-sync-canonical-sections` to sentinels; point `wave7:599` at the shared function; settle the
  `# `-stripping question once. A CI grep banning a second `EDM-HELP-BEGIN` awk literal closes the class.

#### Finding 4 (NEW, P2): `ignored_line_set` is a byte-identical copy in both checkers, and derived a third way in the linter

- **File A**: `plugins/edm/bin/edm-check-grants:127-130`.
- **File B**: `plugins/edm/bin/edm-check-vocabulary:134-137`.
- Both are the same four lines:
  ```bash
  ignored_line_set() {
    local file="$1"
    build_line_classes "$file" | awk -F'	' '$2=="ignored"{print $1}'
  }
  ```
- **File C**: `plugins/edm/bin/edm-lint-artifacts:255` performs the same projection inline against a
  cached classification table (`printf '%s\n' "$_table" | awk -F'\t' '$2=="ignored"{print $1}'`), alongside
  three sibling projections for `mermaid`, `marker` and `unterminated-fence` at `:256-258`.
- **Why it matters**: the extraction stopped one function short of the natural boundary. `build_line_classes`
  emits a four-class table and every consumer has to know the tab-separated record shape to use it; the
  library should expose the projections, not the raw table. The cost is not the eight duplicated lines --
  it is that the record format is now a de facto public contract with three independent parsers, so adding
  a fifth class or changing the separator touches three files that were supposed to have been unified.
- **Supporting observation for another lens**: `edm-check-vocabulary:229` calls `ignored_line_set "$f"`
  from *inside* the per-match loop, so a file with N candidate matches is re-classified N times. That is a
  performance point for L4/L5, not L10, but it is the kind of thing a shared, memoising accessor in the
  library would have prevented.
- **Fix**: add `ignored_line_set`, `mermaid_line_set` and `marker_line_set` to `_edm-lint-lib.sh` next to
  `build_line_classes`, delete both copies, and route `edm-lint-artifacts`' four inline projections through
  them.

#### Finding 5 (NEW, P2): the shared library carries a branch whose only purpose is to absorb a caller naming divergence

- **Site**: `plugins/edm/bin/_edm-lint-lib.sh:95-99`:
  ```bash
  if [[ -n "${violations+x}" ]]; then
    violations=$((violations + 1))
  elif [[ -n "${VIOLATIONS+x}" ]]; then
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
  ```
- **Callers**: `bin/edm-lint-artifacts:125` declares `violations=0`; `bin/edm-check-vocabulary:132` declares
  `violations=0`; `bin/edm-check-grants:125` declares `VIOLATIONS=0`.
- **Why it is a finding**: the extraction unified the code but not the interface. The library now encodes,
  as a runtime branch, the fact that two of its three consumers spell one global lowercase and the third
  spells it uppercase -- a divergence with no reason behind it, imported wholesale from the pre-extraction
  copies. Three consequences: (a) a fourth consumer that declares neither name gets its violations printed
  to stdout and counted nowhere, with no error and no non-zero return, so the script exits 0 on a dirty
  tree -- and two of these scripts are blocking CI jobs; (b) the precedence is lowercase-first, so if
  `edm-check-grants` ever introduces a function-local `violations`, `report_violation` silently bumps the
  local and the real counter stalls; (c) the arity dispatch above it at `:86-93` is a second instance of
  the same pattern -- one function serving two output shapes chosen by argument count.
- **Fix**: rename `edm-check-grants`'s counter to `violations`, delete the `elif` branch, and make the
  no-counter case a hard error rather than a silent no-op (`die`/`return 1`, not an empty `fi`). The
  two-output-shape dispatch at `:86-93` is defensible -- CA-116 records `edm-check-grants`' actor-first
  shape as required by its own AC7 -- but it should select on a named mode argument rather than on `$#`.

#### Finding 6 (CA-096, unchanged, P2): the duplicated standalone-checker block, and the third copy the finding predicted

- **File A**: `plugins/edm/bin/tests/run-all.sh:116-131` -- the `edm-check-grants` invocation block.
- **File B**: `plugins/edm/bin/tests/run-all.sh:133-148` -- the `edm-check-skill-sync` block.
- The two differ only in the script name, the `_grants_` / `_sync_` variable prefix, the echoed heading and
  the label. Every line of control flow is the same. No `_standalone_check` helper exists.
- **The predicted cost has already been paid**: `edm-check-vocabulary` -- the third standalone checker, and
  one of the two that sit in blocking CI jobs -- is not invoked by the aggregator at all. Round 1 called
  this borderline at two copies because "an 8-line `_standalone_check` makes a third checker a one-liner";
  the third checker was instead simply left out. Whether that omission is deliberate belongs to L4, but it
  is the concrete argument for the extraction.
- **Fix**: `_standalone_check <script-name> <label>` returning pass/fail into the aggregate counters; three
  call sites.

#### Finding 7 (CA-095, unchanged and now worse, P2): one fact, eleven places, wrong in all eleven

- **File A**: the shared line in all eleven lens definitions, still citing `skills/code-audit/SKILL.md:40`:
  `edm-audit-dead-code.md:65`, `edm-audit-logic.md:66`, `edm-audit-test-quality.md:67`,
  `edm-audit-consistency.md:69`, `edm-audit-docs.md:69`, `edm-audit-edge-cases.md:69`,
  `edm-audit-dry.md:71`, `edm-audit-runtime.md:74`, `edm-audit-security.md:75`, `edm-audit-spec.md:78`,
  `edm-audit-wiring.md:84`.
- **File B**: the `mkdir -p "${OUTPUT_DIR}"` is at `plugins/edm/skills/code-audit/SKILL.md:59`.
- **Divergence**: it was line 45 at round 1 and is line 59 now. The citation was 5 lines stale; it is 19
  lines stale. This is the concrete cost the finding exists to make visible: the fact drifted further in
  all eleven places simultaneously, during a remediation pass that edited the file it cites.
- **Two more stale citations, also unchanged**: `bin/edm-check-grants:13` cites
  `skills/code-audit/SKILL.md:44,99` and `:335` cites `skills/code-audit/SKILL.md:92,120` for the lens
  launch template; the template is at `:193` and the synthesizer template at `:222`.
- **Fix**: drop the line numbers and cite the step or section by name in all thirteen places.

#### Finding 8 (CA-094, unchanged, P2): seven whole-tree lints and thirteen whole-tree grant scans in one suite

- **Site**: `plugins/edm/bin/tests/wave7-smoke.sh`. Independent `edm-lint-artifacts --all` invocations
  outside the shared capture: `:1035` (T66 AC12), `:1864` (T43 AC9), `:2009` (T44 AC7), `:2288` (T35),
  `:2398` (T36), `:2505` (T37), `:2596` (T38). Five of the seven discard the output entirely and assert
  only on the exit code.
- **The capture**: `WAVE7_ALL_LINT_OUT` / `_EXIT` at `:3075-3079` still serves only its five original
  consumers (`:3086`, `:3191`, `:3249`, `:3337`, `:3487`) and is still declared *below* seven potential
  consumers, which is why they were not collapsed. The prescription was to hoist it above the first one.
- **The grants half is entirely unaddressed**: no capture was added. Thirteen whole-tree `edm-check-grants`
  runs remain -- `:225`, `:2121`, `:2265`, `:2394`, `:2502`, `:2544`, `:2687`, `:3084`, `:3146`, `:3189`,
  `:3247`, `:3334`, `:3485` -- two of them in the same T46 section (`:3146` and `:3189`), plus a fourteenth
  in `run-all.sh:121`. Nothing between them mutates the tree.
- **What did land nearby**: the CA-103 invariant fingerprint (cwd + `EDM_SRD_ROOT` + `git status --porcelain`)
  is now captured at `:3075-3078` and verified at `:3413-3418`, which is exactly the guard that makes the
  single-capture pattern safe -- so the mechanism for collapsing the remaining twenty invocations is now in
  place and unused.
- **Fix**: hoist the lint capture above `:1035`; add a `WAVE7_GRANTS_*` capture beside it; keep the one
  timed run and the cases that assert on output (`:1866-1869`, `:2011`).

#### Finding 9 (CA-049 L10 half, unchanged, P2): one value, four derivations, five inline re-computations

- **Canonical**: `plugins/edm/bin/tests/_harness.sh:39-40` computes `_HARNESS_TESTS_DIR` and
  `_HARNESS_BIN_DIR` correctly from `${BASH_SOURCE[0]}`. It does not export `_HARNESS_PLUGIN_DIR` or
  `_HARNESS_REPO_ROOT` and has no `harness_scratch_srd_root()`; `:5` still tells each suite to manage its
  own `SCRIPT_DIR` / `EDM_STATE` / `PLUGIN_DIR` / `TMP`.
- **Four `PLUGIN_DIR` derivations**: `wave7-smoke.sh:12` `$(cd "${SCRIPT_DIR}/../.." && pwd)`;
  `wave4b-smoke.sh:6` `$(cd "$(dirname "$0")/../.." && pwd)` -- still the only copy keyed on `$0`, the exact
  divergence round 1 flagged; `timing.sh:26` `$(cd "${SCRIPT_DIR}/.." && cd .. && pwd)`; `wave6-smoke.sh:714`
  `$(cd "$(dirname "$EDM_STATE")/.." && pwd)`, a fourth shape derived from a different variable entirely.
- **`REPO_ROOT`**: `wave6-smoke.sh:10` and `harness-smoke.sh:8` agree; `wave7-smoke.sh:13` and `:3077`
  compute the same path inline twice from `PLUGIN_DIR/../..` under no name.
- **Five inline re-computations of a value assigned one to six lines above**: `wave3:12`, `wave4a:12`,
  `wave5:10`, `wave6:16`, `wave7:16` all write
  `source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_harness.sh"` while `SCRIPT_DIR` already holds
  exactly that. `harness-smoke.sh:11` is the only suite that writes `source "${SCRIPT_DIR}/_harness.sh"`.
- **Three byte-identical TMP/trap/SRD_ROOT triples**: `wave3:15-17`, `wave4a:15-17`, `wave5:13-15`, all
  `TMP="$(mktemp -d)"` / `trap 'rm -rf "$TMP"' EXIT` / `export EDM_SRD_ROOT="$TMP/SRD"`. All three still use
  a bare `mktemp -d` and trap EXIT only, while `wave6:19,29` and `wave7:18-19` use
  `${TMPDIR:-/tmp}` and trap `EXIT INT TERM` -- so the CA-045 hygiene fix reached two of five suites and the
  duplicated preamble is why.
- **`bin/` half**: `edm-check-vocabulary:56` and `edm-sync-canonical-sections:32` still resolve from `$0`,
  while `edm-lint-artifacts:51` and `edm-check-grants:100` use `${BASH_SOURCE[0]:-$0}`. `wave7:31` sources
  `edm-state` in a subshell, so the sourced-script case that makes `$0` wrong is live in this repo.
- **Fix**: export `_HARNESS_PLUGIN_DIR` and `_HARNESS_REPO_ROOT` from `_harness.sh`, add
  `harness_scratch_srd_root()`, and delete the per-suite preambles. Roughly 10 lines added, 35 removed.

#### Finding 10 (CA-010 residue, re-open at P2): the code stopped mirroring; the assertion still asserts a mirror

- **What was fixed**: neither checker claims a mirror any more. `edm-check-vocabulary:50-51` now reads
  "AC9: sources the shared lint helper library used by bin/edm-lint-artifacts so ignore markers, fence
  handling, and violation accounting stay identical across both scanners" -- accurate. `edm-check-grants`'
  header no longer carries the VERBATIM claim. `build_ignore_set` exists nowhere in `plugins/edm/bin/`.
- **What was not fixed**: the assertion that pinned the drift is still pinning it.
  `bin/tests/wave7-smoke.sh:296-299`:
  ```bash
  echo "T03 AC8 -- mirrors (not re-derives) edm-lint-artifacts's report_violation/build_ignore_set/is_ignored_line"
  t03_mirror_hits="$(grep -c 'report_violation\|build_ignore_set\|is_ignored_line' "$EDM_CHECK_GRANTS" || true)"
  [[ "${t03_mirror_hits:-0}" -gt 0 ]] && pass "AC8 -- mirrored helper names present in edm-check-grants" \
    || fail "AC8 -- report_violation/build_ignore_set/is_ignored_line not found in edm-check-grants"
  ```
  One of the three alternates names a symbol that no longer exists anywhere in the tree, so that disjunct
  is dead; the assertion survives only on the other two. Its label and its failure message both describe a
  mirroring relationship that has been deliberately replaced by sourcing -- so the one test guarding the
  new design still describes the old one, and would pass unchanged if the `source` line were deleted and
  the copies pasted back in.
  Two more sites carry the stale vocabulary: `wave7-smoke.sh:1683`
  (`check_absent "T43 AC1 -- build_ignore_set no longer present"`) still asserts on the dead symbol, and
  `wave7-smoke.sh:2723`'s comment still reads "same convention as edm-check-grants mirroring
  edm-lint-artifacts, 'T03 AC8'".
- **Fix**: replace `:296-299` with a behavioural assertion -- that `edm-check-grants` contains
  `source .*_edm-lint-lib.sh` and defines none of the three helpers itself -- and retire the
  `build_ignore_set` grep at `:1683`. Round 1 also asked for a check that any comment claiming a mirrored
  symbol names a symbol that exists in the named file; that does not exist yet and would have caught this.

---

## Noted / Not Actionable

- **CA-115** (`bin/edm-check-grants` deliberately not applying the ignore set to grant source 2) --
  carried forward unchanged as NOTED. The rationale is unaffected by the extraction. I did not re-walk
  every `ignored_line_set` call site in `edm-check-grants` this round, so this is carried on round 1's
  evidence rather than re-verified.
- **CA-116** (`edm-check-grants`' actor-first output shape and its unconditional `Edit` warning) --
  carried forward unchanged as NOTED, required by its own AC7. Note that the shape difference is now
  expressed as the arity branch at `_edm-lint-lib.sh:86-93`; the *shape* remains justified, only the
  dispatch mechanism is criticised in Finding 5.
- **CA-128** (the ~36-line lens JSONL skeleton deliberately not factored to a single reference) --
  re-verified in `agents/edm-audit-dry.md:98-123` and unchanged. The reasoning still holds: each lens runs
  in its own context with no guarantee it reads a referenced doc before writing, and the cost of a missed
  reference is a lost finding. Still no drift observed. Still no smoke assertion that the eleven blocks are
  byte-identical modulo the L-number -- that remains the cheap insurance, unbuilt.
- **CA-129** (`lint:pattern-library-contract` at `.gitlab-ci.yml:205` duplicating the smoke suite's
  four-heading check) -- carried forward as NOTED on round 1's rule-by-rule comparison. I did not re-diff
  the two rule sets this round.
- `docs/canonical-sections.md` duplicating two `CLAUDE.md` sections -- still deliberate, generated and
  one-directional. Re-verified: `bin/edm-sync-canonical-sections:54-79` reads only `CLAUDE.md` and writes
  only the destination with no transformation of the section text, `--check` diffs and exits 1 at `:81-89`,
  and `wave6-smoke.sh:3110` and `:3146-3150` assert byte identity of both section spans. Correctly
  allowlisted at `bin/vocabulary-allowlist.txt:36`. Not a finding. (That the generated file still has zero
  consumers is CA-013's problem, not this lens's.)
- `.gitlab-ci.yml` repeated `before_script` package installs -- **demoted from the round-1 note**. What was
  five verbatim `apk add --no-cache bash jq git` lines is now three distinct minimal sets:
  `bash jq git` at `:90`, `:267`, `:327`; `bash jq` at `:108`, `:121`, `:376`; `bash` at `:68`, `:210`;
  plus `bash shellcheck` at `:139`, `bash git` at `:167` and `jq git` at `:298`. The sets genuinely differ
  per job and the file's stated convention is that each job justifies its own packages, so an anchor would
  now hide a real per-job decision. Leave as is.
- `.gitlab-ci.yml:64-83` vs `:134-160`'s file-loop-with-FAIL-flag skeleton -- unchanged from round 1's
  assessment: the file sets and the commands differ and the abstraction costs more than it saves.
- The eleven lens and ten test-writer agent skeletons -- intended by design. The eleven lens files were
  re-checked for the severity clause and the write-path clause this round and are uniform apart from
  `edm-audit-logic.md:73`'s bullet rendering, which is CA-080 (L7) and is not re-filed here. The ten
  test-writer definitions were again not diffed line by line.
- `edm-check-vocabulary`'s help text appearing twice in one file (the full header at `:2-53` and the
  abridged sentinel block at `:73-81`) -- an abridgement with no contradiction between them. Absorbed by
  Finding 3 if the shared `print_help` lands.
- `agents/edm-qc-auditor.md:70` and `edm-test-coverage-auditor.md` mapping conditions to severities rather
  than redefining them -- still legitimate specialisation; both cite the canonical scale first.
- `bin/edm-state`'s `code_audit_required_for_mode` / `audit_required_for_mode_or_legacy` /
  `convergence_exempt` trio -- verified correctly factored, three functions, no fourth copy, and the
  deliberate difference in `cmd_approve_gate`'s consumption is documented in place at `:698-700`.

## Not examined

`hooks/hooks.json` and `monitors/monitors.json` were not read this round, so duplication between hook
prompt text and skill body text remains unassessed for a second round -- it is the largest untouched
surface in this lens. Also not read: `.gitignore`, `plugins/edm/README.md`, `CHANGELOG.md`, the ten
test-writer agent definitions, `docs/` beyond `canonical-sections.md` and `audit-patterns/README.md`,
the bodies of `wave3/4a/5-smoke.sh` (preambles only), `wave6-smoke.sh`'s ~20 near-identical seed blocks,
and the bodies of `bin/edm-init`, `bin/edm-validate-prefix` and `evals/run-eval.sh` beyond their help
machinery. `bin/edm-check-grants:200-600` and `bin/edm-state` were read only at the sites named above.
All findings above are from direct reading; nothing was executed.

## Summary for the coordinator

Round-2 L10 disposition across the 15 L10-tagged round-1 findings: **4 fixed** (CA-009, CA-046, CA-050, CA-093), **8 still open** (CA-005, CA-010, CA-018, CA-019, CA-049, CA-094, CA-095, CA-096), **4 NOTED carried forward** (CA-115, CA-116, CA-128, CA-129), plus **2 new** findings. CA-010, CA-018 and CA-019 are re-opened at reduced severity (P1 to P2) because their P1 bases are genuinely discharged.

The centerpiece verdict: `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/_edm-lint-lib.sh` is real and genuinely sourced by all three `bin/` consumers, with zero surviving hand-copies -- but `/Users/darryl.porter/projects/marketplace/plugins/edm/evals/score-artifacts.sh` was left out of the extraction entirely and its Mermaid rule was fixed by cloning the canonical awk verbatim instead. `bin/edm-mermaid-rules.awk` does not exist. CA-050's claim that CA-009/CA-010 shared its root cause holds for CA-009 (eliminated outright); CA-010's code half is eliminated but its test half still greps a dead symbol at `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/wave7-smoke.sh:296-299`.
