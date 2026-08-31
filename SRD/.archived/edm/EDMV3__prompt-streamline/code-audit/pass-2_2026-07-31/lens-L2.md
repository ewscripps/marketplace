# Code Audit Lens L2 -- Dead Code & Unreachable Paths

- **Lens**: L2 (Dead Code, Unreachable Paths, Environmentally-Eliminated Branches)
- **Date**: 2026-07-31
- **Round**: pass-2 (full, all 11 lenses)
- **Round type**: full -- whole scope re-verified, not a diff against pass-1
- **Branch**: `edm/edmv3-prompt-streamline`
- **Initiative**: EDMV3 (`SRD/edm/EDMV3__prompt-streamline`)
- **Scope covered**: `plugins/edm/bin/**` (all 9 helpers + the new `_edm-lint-lib.sh`),
  `plugins/edm/evals/*.sh`, `plugins/edm/hooks/hooks.json`, `plugins/edm/CLAUDE.md` (pricing
  contract), repository-root `.gitlab-ci.yml`, `.gitignore`

## Headline

**Every one of the nine L2-tagged pass-1 findings is fixed at its cited site.** All three
pass-1 P1s (CA-006, CA-007, CA-008) and the three L2-owned P2s (CA-047, CA-053, CA-054) verify
clean against the current tree with fresh evidence. CA-044's pass-1 fix has not regressed. All
seven NOTED dispositions still hold on their merits, including CA-105 (D32) and CA-107 (D28),
both of which I re-checked specifically and am **not** re-raising.

The fresh full pass produced **four new P2 findings**, all of them small, all of them
one-to-five-line deletions, and three of the four are residue left behind by the pass-1
remediation itself (a guard that the new coercion made unreachable, a clamp that made a
following sign test unreachable, a duplicated self-test assertion). No new P0 or P1.

## Findings summary

| ID | Severity | Status | Site | Defect |
|---|---|---|---|---|
| CA-005 | P1 | **fixed** | `bin/edm-check-grants:2-63`, `evals/run-eval.sh:4-57`, `evals/score-artifacts.sh:8-91` | L2 half (unreachable help content) closed on all three |
| CA-006 | P1 | **fixed** | `.gitlab-ci.yml:292-304` | `apk` + a real bash-3.2 assertion; `script:` now reachable |
| CA-007 | P1 | **fixed** | `.gitlab-ci.yml:347`, `:494`, `:552`; `evals/run-eval.sh:443` | all four status captures now observe failure |
| CA-008 | P1 | **fixed** | `bin/edm-lint-artifacts:299` | two-field read; ignore-set suppression live in CI again |
| CA-012 | P1 | **fixed** | `plugins/edm/CLAUDE.md:448-465` | documents the eight real arms and the real diagnostic |
| CA-044 | P1 | **fixed (no regression)** | `bin/edm-lint-artifacts:373, 374, 409` | three interpolations still present |
| CA-047 | P2 | **fixed** | `bin/edm-state:3342, 3382` | reads the real `.verdict`; no fabricated "(was PARTIAL)" |
| CA-053 | P2 | **fixed** | `evals/run-eval.sh:223-226` vs `:294-296` | the two comments now agree |
| CA-054 | P2 | **fixed** | `bin/edm-state:4112` | redundant `prototype)` arm deleted; single `${mode}` line |
| **new** | P2 | open | `bin/edm-state:988-1158` | `state_anomalies`' `found` accumulator: 12 writes, zero reads |
| **new** | P2 | open | `evals/tiering-matrix.sh:238-242` | duplicate self-test assertion that cannot fail independently; skews the `N/6` denominator |
| **new** | P2 | open | `evals/score-artifacts.sh:145-147` | negative-rounding branch unreachable behind the clamp two lines above it |
| **new** | P2 | open | `bin/edm-state:922-923` | `-z "$sv"` disjunct made unreachable by the CA-001 `to_int` coercion |

**Totals this round**: 0 P0, 0 P1, 4 P2 open; 9 prior L2 findings confirmed fixed; 16 NOTED
(7 carried, 9 new).

`BLOCKING_FILTER` (`bin/edm-state:964`) includes P2, so the four new findings are in the
blocking set. All four are mechanical deletions; none requires a design decision.

---

## Part 1 -- Verification of pass-1 L2-tagged findings

### CA-005 (P1, L1+L2+L6+L7+L10) -- FIXED (L2 half)

The L2 half of this finding was "hardcoded `sed -n 'A,Bp'` ranges stop short of their own
headers, making documented exit-code contracts unreachable output". All three cited sites now
use the sentinel convention plus an awk extractor:

- `plugins/edm/bin/edm-check-grants:2` `# EDM-HELP-BEGIN` ... `:59` `# EDM-HELP-END`, extracted
  by `print_help()` at `:62-64`. The Output-format paragraph (`:47-50`) and the **Exit codes**
  contract (`:52-53`) are inside the block.
- `plugins/edm/evals/run-eval.sh:4`/`:44` sentinels, `print_help()` at `:56-58`. The four-value
  exit contract, including the exit 2 and exit 4 rows CI keys off, is at `:32-43` -- inside.
- `plugins/edm/evals/score-artifacts.sh:8`/`:87` sentinels, `print_help()` at `:90-92`. The
  `total` normalization rule and the non-negotiable jq expression are at `:48-62` -- inside.

Two scripts that had no help at all now do: `bin/edm-init:2-15` + `print_help()` at `:20-22`,
and `bin/edm-validate-prefix:2-14` + `print_help()` at `:20-22`.

Verification: `grep -rn "sed -n '[0-9]*,[0-9]*p' \"\$0\"" plugins/edm/` returns nothing.

**Residual, not L2**: `bin/edm-sync-canonical-sections:43` is still a third extractor variant
keyed on `^set -euo pipefail`, and it carries no sentinels. I checked its **output**: it prints
lines 2-29, i.e. the entire header, so no documented content is unreachable. The
standardisation half of CA-005 belongs to L7 and I take no position on it.

### CA-006 (P1) -- FIXED

`.gitlab-ci.yml:292-304`. `before_script` is now `- apk add --no-cache jq git` (`:298`), which
is correct for the Alpine-based official `bash` image, so `script:` is reachable. The assertion
the pass-1 report asked for is present:

```yaml
    - bash --version | head -1 | grep -q 'version 3\.2'
```

at `:303`, with the CA-006 rationale in the comment at `:301-302`. A future image bump cannot
now pass this job while proving nothing. `grep -c 'apt-get' .gitlab-ci.yml` returns 0.

### CA-007 (P1, L1+L2+L3+L11) -- FIXED (L2 half)

All three CI sites now initialise the status variable and capture with `|| var=$?`, which keeps
the command in a tested position so GitLab's inherited `set -eo pipefail` cannot abort at the
assignment. Every branch that reads the status is reachable again:

- `.gitlab-ci.yml:347-356` (blocking `test:state-validate`): `ec=0` then
  `out="$(edm-state validate "$prefix" 2>&1)" || ec=$?`, then the `-eq 3` BLOCKING arm, the
  `-ne 0` unexpected-exit arm, the remaining loop iterations, and the `${COUNT} initiative(s)
  checked` summary at `:359`. The sweep-all-then-fail-once design works as designed.
- `.gitlab-ci.yml:494-500`: `CLI_EC=0` then `OUT="$(claude plugin validate ... 2>&1)" ||
  CLI_EC=$?`; the structural-error message at `:498` is reachable.
- `.gitlab-ci.yml:552-558`: `rc=0` then `bash plugins/edm/bin/edm-compare-eval ... || rc=$?`,
  then the `case` whose `3)` arm prints `NOT ARMED`. Since no baseline is committed (D23), exit
  3 is the guaranteed path on the first real nightly, and it now reports.
- `plugins/edm/evals/run-eval.sh:443-447`: the containment check no longer expands
  `$(cd ... && git status --porcelain)` inside a heredoc. It is now
  `containment_status=0; containment_output="$(cd "$SCRATCH_DIR" && git status --porcelain
  2>/dev/null)" || containment_status=$?` followed by a `die` when non-zero, so a failed check
  can no longer read as `containment: clean`.

**Residual, not L2**: `run-eval.sh:452` is still `path="${line:3}"`, so a porcelain rename
record `R  SRD/x -> outside/y` still slices to a string beginning `SRD/` and passes the
containment case at `:453-457`. That is CA-007's L1/L3 half; it is a mis-parse, not an
unreachable path, and I flag it here only so the synthesizer does not close CA-007 whole on my
evidence alone.

### CA-008 (P1, L1+L2+L3) -- FIXED

`plugins/edm/bin/edm-lint-artifacts:299` now reads:

```bash
      while IFS=: read -r lineno _rest; do
```

Two fields, matching the two-field `grep -n` output. The stray `_f` is gone. All four class
readers are now identical in shape and correct: class 1 `:285`, class 2 PCRE `:299`, class 2
`LC_ALL=C` fallback `:312`, class 3 `:330`. Consequences of the fix, each verified at its site:
`is_ignored_line "$lineno" "$ignore_set"` at `:300` now compares a line number against a set of
line numbers, so the `edm-lint-ignore` / code-fence escape valve works for the unicode class on
GNU grep -- the branch the blocking `lint:artifacts` job takes; `sed -n "${lineno}p"` at `:301`
gets a numeric expression, so `snippet` is populated; and the emitted record satisfies the
`path:line: <class>: <snippet>` contract documented at `:30`.

Pass-1 N1 still holds and I re-confirm it: both PCRE branches are live (`_has_pcre_grep` at
`:107-110`, `if` at `:293`, `else` at `:305`). Delete neither.

### CA-012 (P1, L2+L6) -- FIXED

`plugins/edm/CLAUDE.md:448-465`. The subsection is retitled "How `compute_cost_usd` picks a rate
row after D32" and now enumerates the eight actual arms in their actual order (previous-gen
frozen rows, current-gen explicit rows, the literal `unknown` sentinel, the `*)` fallback),
matching `bin/edm-state:368-427` arm for arm. Critically, the inverted diagnostic is corrected:
`:460-463` now states "an unrecognized model in a known family no longer matches silently.
`claude-opus-5-20260501` ... now falls through to `*)`, emits the warning, and gets placeholder
Sonnet-tier pricing until a human updates the table." That is the true behaviour.

### CA-044 (P1) -- still fixed, no regression

`bin/edm-lint-artifacts:373` (`... prefix ${PREFIX} (run: edm-state init ${PREFIX})`), `:374`
(`... not found: ${INIT_DIR}`), `:409` (`--path target not found: ${PATH_ARG}`). All three
interpolations present; no double spaces, no `init )` with an empty argument.

### CA-047 (P2, L1+L2) -- FIXED

`bin/edm-state:3342` now derives the prior verdict from the state file rather than defaulting:

```bash
    prior_verdict="$(echo "$existing" | jq -r '.verdict // .prior.verdict // "PARTIAL"')"
```

and `:3382` interpolates it. The field read is `.verdict` -- the open shape's actual verdict
field -- with `.prior.verdict` as the nested-closure fallback, exactly the wrong-field half of
the pass-1 finding. A PASS- or FAIL-closed entry is no longer reported as "(was PARTIAL)". The
FAIL re-closure path at `:3365` prints "(was FAIL)" inside a branch guarded by
`already_closing_verdict == "FAIL"` at `:3345`, so that string is correct by construction.

(The residual shell-level `${prior_verdict:-PARTIAL}` at `:3382` is now near-dead -- see Noted
N-6. It no longer fabricates anything.)

### CA-053 (P2) -- FIXED

`plugins/edm/evals/run-eval.sh:223-226` no longer claims `--bare` is what makes AC8 true. It
now reads "No `--bare`: verified live on claude 2.1.220 that `--bare` strips stored
subscription/OAuth credentials and turns an otherwise valid logged-in machine into 'Not logged
in'." That agrees with the NOTE at `:294-296` and with the invocation at `:285-293`, which
passes no `--bare`. The two comments in one function no longer contradict each other.

### CA-054 (P2) -- FIXED

The `prototype)` case arm whose output was byte-identical to its `*)` fallback is gone. The
mode is now rendered by a single unconditional line in `write_handoff_internal`:

```bash
    printf '%s\n' "- **Mode**: ${mode}"
```

at `bin/edm-state:4112`. Grepping every remaining `prototype)` arm in the file confirms each
survivor is materially distinct from its siblings: `:623` (`echo 2`, versus `echo 6` for the
other four modes), `:672` (`echo false`, versus `echo true`). `default_skipped_phases_json_for_mode`
(`:723-742`) uses `if/elif/else` with three different bodies. No duplicated-arm residue.

---

## Part 2 -- New findings (fresh pass)

### L2-N1 (P2) -- `state_anomalies` accumulates into a variable nothing ever reads

`plugins/edm/bin/edm-state:988-1158`. `local found=0` is declared at `:988` and assigned
`found=1` at twelve sites -- `:993`, `:1016`, `:1022`, `:1047`, `:1057`, `:1070`, `:1092`,
`:1103`, `:1116`, `:1135`, `:1146`, `:1156` -- one per anomaly class. The function then ends
with an unconditional `return 0` at `:1158`. `found` is never read, and no caller can read it:
it is `local`, and the two consumers derive what they need from the emitted text instead --
`cmd_validate:2765-2771` re-parses the class field out of `$anomalies` to compute
`blocking_count`, and `cmd_session_start:2932-2938` just renders every line.

This is vestigial from the pre-EDMV3-T05 contract, when any anomaly flipped the exit code; the
class split replaced that with the text-derived `blocking_count`. The header comment at `:975`
("Exits 0 and emits nothing when no anomalies found") documents the current behaviour, so the
variable contradicts nothing -- it is simply twelve dead stores in the single most-edited
function in the file, and every new anomaly class added since has dutifully copied the dead
assignment forward (the `ACTIVE_EXEMPTION` blocks at `:1135`, `:1146` and `:1156` are the three
most recent).

Distinguish from the two live twins so this is not "fixed" in the wrong place:
`cmd_list`'s `found` (`:1397`, read at `:1419`) and `cmd_active_initiatives`' (`:2631`, read at
`:2643`) are both genuinely consumed. Only `state_anomalies`' is dead.

**Fix**: delete the declaration and all twelve assignments. Do not "wire it up" -- a return
code from `state_anomalies` would be a second, competing source of truth against
`cmd_validate`'s class parse, which is the thing EDMV3-T05 AC2 made canonical.

### L2-N2 (P2) -- a self-test assertion that cannot fail independently, and a denominator that no longer matches

`plugins/edm/evals/tiering-matrix.sh:238-242`:

```bash
  if echo "$out" | grep -qxF "DECISION synthetic-agent-a-qualifies: sonnet/high (cheapest qualifying config, tier 1)"; then
    :
  else
    failures=$((failures + 1))
  fi
```

The condition is byte-identical to the branch-1 assertion already evaluated 26 lines earlier at
`:212`, against the same unchanged `$out`. It therefore has no state in which it can fail while
`:212` passes, and no state in which it can pass while `:212` fails -- it is a pure duplicate
whose only possible effect is to double-count one failure.

Two concrete consequences:

1. The success arm is `:` -- it prints nothing, so a reader of a passing `--self-test` log sees
   six PASS lines and has no way to know a seventh check ran.
2. `:305` prints `self-test: PASS (6/6 promotion-rule assertions verified)` and `:308` prints
   `self-test: FAIL (${failures}/6 assertion(s) failed)`, but there are **seven** sites that can
   increment `failures` (`:216`, `:226`, `:235`, `:241`, `:286`, `:292`, `:300`). A single real
   branch-1 regression reports `2/6` for one broken assertion. D28 cites this self-test by name
   as the evidence that the promotion rule is verified ("All three assertions pass ... exits 0,
   3/3"), so the count is load-bearing prose, not decoration.

**Fix**: delete `:238-242`. Leave the `6` denominator alone -- it is correct for the six
distinct assertions at `:212`, `:222`, `:231`, `:282`, `:288`, `:296`.

### L2-N3 (P2) -- a sign test behind a clamp that makes the negative case impossible

`plugins/edm/evals/score-artifacts.sh:139-150`, inside `score_from_ratio`:

```awk
      v = 100 * n / d
      if (v < 0) v = 0
      if (v > 100) v = 100
      r = (v < 0) ? int(v - 0.5) : int(v + 0.5)
```

`:145` clamps `v` to `>= 0` unconditionally. `:147` then tests `(v < 0)` on the same variable in
the same `BEGIN` block with no intervening assignment, so the `int(v - 0.5)` arm is structurally
unreachable for every input, including a negative numerator, a negative denominator, and NaN
propagation (the `d <= 0` early return at `:143` already handles the last).

`score_from_ratio` is the shared normalizer for dimensions 1, 2, 3, 4 and 5, so this is the one
rounding path the whole scorer runs through -- worth keeping legible.

Related but **not** a finding: `round_int` at `:133-135` has a real negative branch. It is a
general-purpose helper whose current callers (`:198` a mean of three clamped scores, `:470` a
mean of clamped per-lens scores) never go negative, but there is no clamp inside `round_int`
making the branch impossible, so it is defensive, not dead.

**Fix**: `r = int(v + 0.5)` -- one line.

### L2-N4 (P2) -- a guard the CA-001 remediation made unreachable

`plugins/edm/bin/edm-state:922-923`:

```bash
  sv="$(to_int "$sv" 0)"
  if [[ -z "$sv" || "$sv" -eq 0 ]]; then
```

`to_int` (`:84-89`) is a two-arm `case` that prints either `"${2:-0}"` or `"$1"`. Called with an
explicit second argument of `0`, it prints a non-empty string on every input -- `0` for the
empty/non-numeric arm, the digits for the numeric arm. Command substitution strips trailing
newlines but `printf` emits none. So after `:922`, `sv` is provably non-empty and the `-z "$sv"`
disjunct at `:923` can never be true.

This is residue from the pass-1 CA-001 fix: `sv="$1"` used to be able to arrive empty (the
callers all read `jq -r '.schema_version // empty'`), and the coercion line inserted above the
test closed that. The remaining `-eq 0` disjunct does all the work and is correct -- it is what
maps both "absent" and "present but non-integer" onto the legacy class, exactly as the comment
at `:919-921` describes.

**Fix**: `if [[ "$sv" -eq 0 ]]; then`. Keep the comment block at `:912-921` verbatim -- it is
the only place the arithmetic-context injection rationale is stated for this field.

---

## Noted / Not Actionable

Carried NOTED dispositions, each re-verified against the current tree this round:

- **CA-105** `bin/edm-state:365-427` -- still no pricing arm for any live model; the arm set is
  unchanged (`*opus-4-7*`, `*sonnet-4-6*`, `*haiku-4-5*` frozen; `*opus-4-8*`, `*haiku-4-6*`,
  `unknown`, `*sonnet-4-7*`, `*)`). **`decisions.md` D32 still records this in full**, leaves
  the $25.869 figure as recorded per EDMV3-T52 AC9, and assigns verified Sonnet 5 / Fable 5 /
  Opus 5 rate rows to EDMV4. Confirmed as an accepted, tracked gap. **Not re-raised.** The
  documentation half (CA-012) is now fixed, so the code and the prose agree that a warned figure
  is a placeholder.
- **CA-107** `bin/edm-state:2438-2457` -- the Tiered-vs-Untiered section is still gated on
  `.tiering_results`, which no producer writes (`grep tiering_results plugins/edm/` returns only
  `:2440`, `:2444`, `:2446`, `:2453`). The in-code comment at `:2439-2444` states this plainly
  and gives T48 a concrete target shape; **D28** records the matrix as built, unit-verified and
  deliberately not run pending D23's baseline. Disposition holds.
- **CA-114** `bin/edm-state:3619-3624` -- `pattern_target_heading_for`'s single-`*)` case.
  Documented at `:3585-3592` as the extension point, contractually coupled to adding a README
  mapping row. Unchanged; holds.
- **CA-116** `bin/edm-check-grants:498-511` -- the `Edit` arm sets `_has_instruction=0` with no
  lookup, identical in effect to the `else` arm's initial value. Documented at `:486-493` as
  intentional ("Edit has no instruction-detection path at all ... that is intentional: it is
  exactly the class of over-grant this AC exists to surface"), advisory-only, never affects the
  exit code. Holds.
- **CA-119** `bin/edm-state:2013-2017` -- `target_version=$((current_version + 1))` is a no-op
  today (max target 2, so 1->2 either way). Defensive against `schema_version: 3`, which
  CLAUDE.md records as deliberately unassigned. Holds. *Out-of-lens observation for L6*: the
  comment at `:1945-1948` says a present-but-non-integer value "fails the `-le` guard and is
  reported rather than acted on", but a value coerced to `0` passes the guard and advances to 1;
  that is a prose/code mismatch, not a dead branch.
- **CA-120** `evals/score-artifacts.sh:598-643` -- `cmd_compare`, a second comparison
  implementation CI does not use, retained deliberately with the reason at `:594-597` and
  exercised by `wave7-smoke.sh`. Reachable via the `--compare` dispatch arm at `:655-659`. Holds.
- **CA-121** `evals/tiering-matrix.sh:321` -- the `--*)` unknown-flag guard cannot see `-h` or
  `--help` because both exit at `:70`. Deliberate two-stage parse. Holds.

New this round:

- **N-1** `bin/edm-state:479-512` (`write_atomic`) -- `"$@" > "$tmp"; ec=$?` at `:491-492` looks
  like the CA-007 shape but is **not** one. Every call site puts the function in a tested
  position, which disables `set -e` for its whole body: `:528` (`if ! write_atomic`), `:1337`
  (reached via `with_state_lock ... || init_ec=$?` at `:1371`), `:3007`, `:3712`, `:4188` (all
  `|| die` / `|| return 1`). Both failure branches (`:493-499`, `:502-508`) and the trap
  restoration are reachable. Recorded so a future round does not misread it -- and so that
  anyone adding a *bare* `write_atomic ...` call site knows it would make them unreachable.
- **N-2** `bin/edm-state:397-406` (`unknown)` pricing arm) -- reachable, not shadowed.
  `get_session_tokens_since` emits the literal `unknown` at `:279`, `:316`, `:346` and `:349`,
  and no wildcard arm above it matches the string. Deliberately silent per the comment at
  `:398-400`.
- **N-3** `bin/edm-check-grants:434-440` -- both `while IFS= read -r ln` loops in
  `scan_hook_prompts` bind `ln` and then pass `$lnum` to `assert_agent_grant`, so `ln` is a dead
  binding and iterations after the first are no-ops (`mark_and_maybe_report` dedupes per actor
  via `reported_agent.txt` at `:239`). Explained by the comment at `:413-416`: each `"prompt"`
  value is one physical line, so `$lnum` *is* the correct citation and the loop is deliberately
  an "at least one instruction exists" test. Style, not dead logic.
- **N-4** `bin/edm-state:3706-3711` -- `_cmd_update_patterns_body`'s missing-heading SKIP
  duplicates the outer `grep -qxF` check at `:3778`. Not dead: the outer check runs unlocked and
  the body runs under `with_state_lock "${pattern_file%.md}"` (`:3790`), so this is a genuine
  re-validation inside the lock. `grep -qxF` and awk's `$0 == h` are equivalent whole-line
  comparisons, so the two cannot disagree except across a concurrent write -- which is exactly
  what the lock exists for.
- **N-5** `bin/edm-state:3707` -- the `-z "$insert_line"` disjunct is near-dead
  (`pattern_insert_line_for`'s awk always prints, via `:3650` or `:3658`). Reachable only on an
  awk failure. One-token defensive residue; left alone deliberately rather than bundled with
  L2-N4, since unlike `to_int` there is no in-function guarantee of non-emptiness.
- **N-6** `bin/edm-state:3382` -- `${prior_verdict:-PARTIAL}` is now reachable only when
  `.verdict` is the empty string (jq's `//` falls through on null/false, not on `""`). Harmless
  residue of the CA-047 fix; it no longer fabricates a prior state, because the jq expression
  itself now supplies the real value. Not worth a finding.
- **N-7** `bin/edm-init:137-150` -- the `mini-srd)` arm's body (`mkdir -p "$DIR/code-audit"`) is
  identical to the `standard|iac|data-ml)` arm's. Superficially the CA-054 shape, but both arms
  are reachable, the `case` is exhaustive over the five values validated at `:51-54` with no
  `*)`, and each arm's comment states a different reason for the same effect. The empty
  `prototype)` arm at `:147-149` is a deliberate explicit no-op. Duplication, not dead code.
- **N-8** `bin/edm-check-vocabulary:2-53` -- the long contributor header is never printed;
  `--help` prints only the short sentinel block at `:73-81`. Unlike CA-005 this is not silent
  truncation: the sentinel block is self-contained and states usage, output format and all three
  exit codes. The long block is a maintainer comment. Left as-is.
- **N-9** `bin/_edm-lint-lib.sh:90-93` -- the `report_violation` "expected 4 or 5 args" arm.
  Every call site is statically 4-arg (`edm-lint-artifacts:245, 269, 288, 302, 315, 333, 362`;
  `edm-check-vocabulary:239`) or 5-arg (`edm-check-grants:243`), so the arm cannot fire today.
  It is a shared-library arity guard on a function three scripts now consume -- exactly the case
  where a defensive check earns its place. Keep.
- **N-10** `.gitlab-ci.yml:539` -- `if [ -f plugins/edm/evals/score-artifacts.sh ]` is
  trivially true in any full checkout. Defensive against a partial artifact restore. Keep.
- **N-11** `bin/edm-check-skill-sync` -- pass-1 flagged this as unexamined and "the profile most
  likely to hide an L2 finding". Examined in full this round. It is genuinely wired
  (`bin/tests/run-all.sh:137-141`, a real invocation with exit-code handling), its
  `PROCEDURE_MARKER` loop at `:53-60` covers eight skills that all exist on disk, and both its
  violation paths and its CLEAN path are reachable. No L2 finding. Whether it should have been
  built at all is CA-089's question (L9), not mine.
- **N-12** `bin/edm-check-vocabulary:212, 214` -- both greps now pass `-H`, so the three-field
  parse at `:221-224` is correct even when `FILES` holds a single file. This closes pass-1's N11
  ("the CA-008 shape latent here"); the latent risk is gone, not merely unexercised.
- **N-13** `.gitlab-ci.yml:145-153` (`lint:shellcheck`) -- the loop globs `plugins/edm/bin/*`,
  which now includes `_edm-lint-lib.sh`, `vocabulary-prohibited.txt` and
  `vocabulary-allowlist.txt`. `--include=SC2086,SC2046,SC2048,SC2068` filters everything else, so
  the `.txt` files produce no included finding and the job's pass/fail semantics are unchanged.
  Not an unreachable path.
- **N-14** `bin/edm-state:3210-3217` (`cmd_audit_converged`) -- both arms `return 3` with
  materially different diagnostics (legacy markdown-only ledger vs no audit at all). Correct;
  re-confirms pass-1's N13 at its new line numbers.
- **N-15** `bin/edm-lint-artifacts:341-364` (class 4) -- unlike classes 1-3 it does not test
  `UNREADABLE_FLAGS`, but `MERMAID_SETS[$i]` is set to `""` for an unreadable file at `:247`, so
  `[[ -z "$mermaid_set" ]] && continue` at `:344` is an equivalent guard. Not a missing branch.

---

## Coverage note

Read in full this round: `bin/edm-state` (4,255 lines), `bin/edm-lint-artifacts`,
`bin/_edm-lint-lib.sh`, `bin/edm-check-grants`, `bin/edm-check-vocabulary`, `bin/edm-init`,
`bin/edm-validate-prefix`, `bin/edm-check-skill-sync`, `bin/edm-sync-canonical-sections`,
`bin/edm-compare-eval`, `evals/run-eval.sh`, `evals/score-artifacts.sh`,
`evals/tiering-matrix.sh`, `.gitlab-ci.yml`. Targeted: `plugins/edm/CLAUDE.md` pricing contract
(CA-012), `decisions.md` D28/D32 (CA-105/CA-107 dispositions).

Not opened this round: `bin/tests/*-smoke.sh` bodies beyond `run-all.sh`'s
`edm-check-skill-sync` invocation and the `tiering-matrix.sh` self-test, `hooks/hooks.json`
prompt bodies, `skills/**` and `agents/**` prose. The smoke suites remain the largest unswept
surface for this lens -- dead assertions and fixtures for removed paths -- and were also
unswept in pass-1; L4 (test quality) is the better owner, but if a third round runs, one L2
sweep of `bin/tests/` would close the gap.
