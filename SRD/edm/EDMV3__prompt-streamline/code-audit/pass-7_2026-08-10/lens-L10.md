# Lens L10: DRY & Redundancy -- Pass 7 (2026-08-10)

**Tooling note (CA-130's class, eighth consecutive round):** Write/Edit/Bash
absent from this lens's delivered runtime tool set. This report was
transcribed by the orchestrator from the lens agent's final message. Bash
absence again meant no `diff`/`sort`/`uniq` for duplicate detection -- every
comparison below was done by reading and by `Grep`.

## Ledger verdicts on prior L10-attributed findings

| ID | Sev | Verdict this round |
|---|---|---|
| **CA-343** (G23) | P2 | **PARTIALLY RESOLVED -- 1 of 3 sub-parts clean.** See breakdown below. Sub-part (a) coverage epic row: **RESOLVED**. Sub-part (b) gate predicate: **RESOLVED for the gate-approval half, PARTIAL for the skipped-phases half** -- two callers missed, one of them created by round 6's own G4/CA-335 fix (finding L10-101). Sub-part (c) migrate-schema: **PARTIAL** -- the enumeration was routed, the layout knowledge was not, and the new comment overclaims (finding L10-104). |
| **CA-344** (G24) | P2 | **STILL OPEN, as expected -- deliberately deferred in round 6, all five confirmed present at the exact lines the ledger names.** Re-verified individually against current code (L10-105). No divergence has appeared in any of the five since round 6. |
| CA-327 | P2 | Not re-verified this round (closed in round 6). No budget after the CA-343/CA-344 verification and the full-scope sweep. |
| CA-326 | P2 | **Spot-confirmed still in place.** `_wave7_assert_shared_lint_fresh` is defined at `bin/tests/wave7-smoke.sh:1405` (round 6 recorded `:1403`; a 2-line shift, not a removal). Call-site count not re-counted. |
| CA-279, CA-298, CA-309, CA-310, CA-282 | -- | Not re-verified this round (all closed in round 6). |
| CA-037 | P1 | **NOT re-verified, second consecutive round.** The L10 half (ten hand-rolled copies across wave6/wave7) again exceeded available budget without Bash. Flagging explicitly rather than omitting. `assert_absent_with_control` (`_harness.sh:219`) still carries its round-5 "zero production callers" note at `:216-218`, which was read -- but that is not the same claim as "the ten copies are gone." |

## Findings (L10: DRY & Redundancy)

| # | Sev | Type | File A | File B | Canonical | Recommendation |
|---|---|---|---|---|---|---|
| L10-100 | **P1** | Diverged parallel implementation | `bin/edm-compare-eval` (whole file) | `evals/score-artifacts.sh:663-708` | `bin/edm-compare-eval` | Make `--compare` shell out to `edm-compare-eval`, or delete it; correct `edm-compare-eval:4-5`'s false claim; repoint the wave7 tests at the shipped comparer |
| L10-101 | P2 | Missed callers on a landed extraction | `bin/edm-state:845` (helper) | `:2227`, `:5048` | `skipped_phases_str` | Two one-line call-site conversions; correct the helper's docstring count; add the smoke pin the sibling half already has |
| L10-102 | P2 | Diverged parallel renderer (header half) | `bin/edm-state:2502`, `:2515` | `:3309`, `:3319` | neither -- extract | The row was extracted; the header that labels it was not. Three header copies in two mechanisms, all disagreeing |
| L10-103 | P2 | Duplicate function pair | `bin/edm-state:4620-4627` | `:4629-4636` | extract or delete | Collapse to one provenance-link setter; also closes an undocumented `write_handoff_internal` asymmetry |
| L10-104 | P2 | Layout knowledge partially duplicated | `bin/edm-state:2582-2583` | `:135-138` | `list_state_files` | Enumeration routed but both archived shapes re-encoded at the probe; the new comment claims otherwise |
| L10-105 | P2 | **Carried: CA-344's five, unchanged** | see detail | see detail | see detail | Re-verified present; no new divergence |

### Details

#### L10-100 (P1, highest priority this round) -- the eval regression tripwire has two comparers, they have diverged, and the test suite covers the one CI does not run

- **File A**: `plugins/edm/bin/edm-compare-eval` -- the comparer CI actually
  invokes (`plugins/edm/CLAUDE.md`'s `eval:nightly` row: "compares the result
  against the committed baseline via `bin/edm-compare-eval`").
- **File B**: `plugins/edm/evals/score-artifacts.sh:663-708` (`cmd_compare`,
  reached via `--compare <a.json> <b.json>` at `:720-723`) -- a second
  comparer over the same two `scores.json` files.

**The false single-source claim.** `bin/edm-compare-eval:4-5` states:

```
# EDMV3-T39. The scorer (evals/score-artifacts.sh) never compares; it only scores. This script
# owns the comparison so a scoring change and a threshold change stay separately reviewable.
```

The scorer does compare. `evals/README.md:245-246` states the mirror-image
half -- "`--compare` ... is the one piece of comparison logic **in this
file**" -- which is true of that file and misleading about the plugin.
`plugins/edm/CLAUDE.md`'s `eval:nightly` row repeats the claim a third time
("the threshold comparison lives here in CI, not in the scorer"). This is the
same class as CA-012's docstring (round 6's L10-001) and CA-343's own three
"already share one derivation" comments: a comment asserting a drift class is
closed while a second implementation sits in the tree.

**The divergence is real and shipped:**

| Behaviour | `edm-compare-eval` | `score-artifacts.sh --compare` |
|---|---|---|
| `scorer_version` mismatch | refuse, **exit 2** (`:80-84`) | refuse, **exit 1** (`:674-677`) |
| `dimensions_scored` mismatch | refuse, **exit 2** (`:89-94`) | refuse, **exit 1** (`:679-685`) |
| `complete: false` candidate | refuse (`:70-75`), with an explicit note that jq's `//` mishandles `false` | **absent** -- compares an incomplete run silently |
| Acceptance threshold `baseline.total - variance.total_range` | applied (`:102-103`, `:128`) | **absent** |
| "unset" sentinel | `// "unset"` | `// "unknown"` / `// -1` |
| Output shape | human-readable table + verdict | JSON delta object |

**Why this is P1 and not P2.** Three independent aggravators:

1. **The exit-code contract diverges.** Copy A returns 2 for both refusals,
   copy B returns 1. This project treats these codes as load-bearing --
   `bin/tests/wave7-smoke.sh:7742` maintains an explicit per-script
   `g21_die_map` pinning each helper's `die` default (`edm-compare-eval:2`).
   A caller that learned the refusal code from the tested copy reads copy A's
   exit 2 as a usage error rather than a refusal.
2. **The shipped copy's refusal logic is behaviourally untested; the
   unshipped copy's is.** `wave7-smoke.sh:693-707` (T23 AC4) *executes*
   `score-artifacts.sh --compare` for both refusal conditions and the happy
   path. `edm-compare-eval` appears in the entire `bin/tests/` tree only in
   two **static** enumerations -- `:5681` (the CA-154 sentinel-convention
   file list) and `:7742` (the `die`-code map). Nothing executes its
   refusals, its `complete: false` guard, or its threshold. So the plugin's
   green T23 AC4 result is evidence about a code path CI never runs.
3. **The stated rationale is self-defeating.** `score-artifacts.sh:659-662`
   justifies `cmd_compare` as existing "so the exact 'refuse on
   scorer_version or dimensions_scored mismatch' behaviour AC4 requires is
   directly testable." Testing a second implementation of a refusal does not
   make the first one testable -- and the second one is missing one of the
   three refusal conditions the first one enforces.

**Held at P1 rather than P0** on the same logic round 6 used for G1:
`eval:nightly` is `allow_failure: true` and `when: manual` on merge requests,
so a wrong comparison verdict never blocks a merge. The failure mode is a
silently unarmed regression tripwire, not an unguarded merge path.

**False-alarm filter.** (1) Different for good reason? Only partly -- the
JSON-vs-table output split is defensible, but two exit codes for one refusal
and a missing `complete` guard are not. (2) One in test code only? No -- both
are documented user-facing modes (`evals/README.md:243-251`,
`edm-compare-eval:7-29`). (3) Circular dependency? No -- `evals/score-
artifacts.sh` can invoke `bin/edm-compare-eval` (the reverse direction already
exists conceptually and there is no import cycle in bash).

**Fix.** Preferred: delete `cmd_compare` and the `--compare` dispatch arm,
repoint `wave7-smoke.sh:693-707` at `bin/edm-compare-eval` (which gains the
executed refusal coverage it lacks today), and delete the now-accurate-by-
construction claim rewrite. Alternative, if the JSON delta output is wanted:
keep `--compare` as a thin `exec`/shell-out to `edm-compare-eval` with a
`--json` flag, so one implementation owns all three refusals, one exit-code
family and the threshold. Either way, correct `bin/edm-compare-eval:4-5`,
`evals/README.md:245-251` and `plugins/edm/CLAUDE.md`'s `eval:nightly` row in
the same commit as the code change (the G3/CA-334 durability rule).

#### L10-101 (P2) -- `skipped_phases_str` landed with two callers un-converted, and round 6's own G4 fix authored one of them

The helper landed correctly at `bin/edm-state:845`:

```bash
skipped_phases_str() {
  echo "$1" | jq -r '[(.skipped_phases // [])[].phase] | join(" ")'
}
```

Its docstring (`:841-844`) says the derivation "was hand-copied at
cmd_phase_start, cmd_gate_check and cmd_archive (**three** separate literal
copies)". Round 6's own L10-002 counted **four**: `:2034, :2090, :2621,
:3400`. The fix converted three; `:2090` was never in the docstring's list and
was never converted. Two literal copies survive:

- **`bin/edm-state:2227`** (`cmd_phase_complete`) --
  `pc_skipped_str="$(echo "$pc_state" | jq -r '[(.skipped_phases //
  [])[].phase] | join(" ")')"`. This is round 6's `:2090`, shifted.
  Byte-identical jq. `skipped_phases_str "$pc_state"` is a drop-in.
- **`bin/edm-state:5048`** (`_write_handoff_body`) --
  `skipped_for_count="$(echo "$state" | jq -r '[(.skipped_phases //
  [])[].phase] | join(" ")')"`. **This copy did not exist before round 6.**
  It was authored by round 6's **G4/CA-335** fix, whose prescription in
  `pass-6_2026-08-10/REMEDIATION.md:324` contains that exact line. Its own
  adjacent comment (`:5041-5046`) says it derives the count "from the single
  source `required_gates_for_mode()` already uses" -- true of
  `required_gates_for_mode`, false of the input it feeds it, which is
  hand-copied from a helper that landed in the same round for precisely this
  purpose. The helper's docstring even names this use case: "the shared
  input `required_gates_for_mode()` needs."

**Why this matters beyond tidiness.** This is the **third documented
instance in two rounds of two same-round fixes invalidating each other** --
G6/CA-337 (CA-256's fix vs CA-305's rename) and G10/CA-340 (CA-314's and
CA-007's fixes creating new stale citations) were the round-6 pair. G10/
CA-340's durability half is the standing answer to this class, and it is not
yet armed for DRY extractions.

**The asymmetry that let it through.** Round 6 added a real durability pin
for the *sibling* half of the same extraction -- `bin/tests/wave6-smoke.sh:
781-784` asserts the `(.gates_approved // []) | map(select(.gate == $g)) |
length` expression has **exactly one** definition, and `:785-788` asserts
>=3 call sites of the shared helpers. There is **no analogous assertion for
`skipped_phases_str`**, which is exactly why its two survivors are invisible
to a green suite. (`:3277`'s `map(select(.gate == $g)) | first` in
`cmd_metrics_report` is correctly *not* a violation of the `| length` pin --
different shape, needs the approval object, not the count.)

**No definition-order excuse:** `skipped_phases_str` is defined at `:845`,
far above both call sites. `local` scoping is not a factor -- both sites
already hold the state JSON in a variable.

**Fix.**
1. `:2227` -> `pc_skipped_str="$(skipped_phases_str "$pc_state")"`.
2. `:5048` -> `skipped_for_count="$(skipped_phases_str "$state")"`.
3. Correct `:841-844`'s "three separate literal copies" to four, and name
   `cmd_phase_complete` and `_write_handoff_body` as callers.
4. Add the missing smoke pin mirroring `wave6-smoke.sh:781-784`:
   `count_matches_strict` the literal `[(.skipped_phases // [])[].phase] |
   join(" ")` in `bin/edm-state` and assert exactly 1. Use
   `count_matches_strict` (`_harness.sh:198`), not `count_matches` -- the
   expected value is 1, not 0, but the strict form still guards the missing-
   file typo that `_harness.sh:180-185` warns about.

#### L10-102 (P2) -- the coverage row was extracted; the header that labels it was not, and the three header copies disagree

Round 6's L10-001 fix is clean on the row itself: `COVERAGE_EPIC_ROW_JQ_DEF`
(`bin/edm-state:1071-1072`) is referenced from both call sites (`:2509`
get-coverage, `:3321` metrics-report), the docstring at `:1052-1070` honestly
corrects CA-012's overclaim, and `bin/tests/wave5-smoke.sh:112` records the
intent. Verified: no third copy of either row def exists.

What survived is the half round 6 noted but did not scope into the fix --
"each site also hand-writes its own header/underline pair." There are now
**four header copies in two incompatible mechanisms**, all of which must stay
in lockstep with padding constants that live in a third place (the shared jq
defs):

- `bin/edm-state:2502-2503` (get-coverage, layer table) -- hardcoded jq
  string literals with hand-counted spaces
- `bin/edm-state:2515-2516` (get-coverage, epic table) -- same
- `bin/edm-state:3309-3310` (metrics-report, layer table) --
  `printf "  %-14s  %-10s  %-20s\n"`
- `bin/edm-state:3319-3320` (metrics-report, epic table) --
  `printf "  %-15s  %-14s  %-10s\n"`

**The divergence is observable.** The `printf` widths in metrics-report
reproduce the shared row def's padding exactly (`%-15s`/`%-14s` against the
def's 15-wide epic and 14-wide layer clamps), so metrics-report's headers sit
directly over their data columns. get-coverage's hand-counted string literals
do not. By column arithmetic on the exact space counts (confirmed via
anchored Grep: `:2515` is `"  Epic"` + 12 spaces + `"Layer"` + 10 spaces +
`"Coverage"` + 2 spaces + `"Measured At"`), get-coverage's epic header sits
**1 column left** of the layer data, **2 columns left** of the coverage data,
and several columns left of `measured_at`; `:2502`'s layer header is **1
column left** of the coverage data. metrics-report renders the same shared
rows under correctly-positioned headers.

So the two commands print the same shared row under headers that disagree
with each other, and one of them is misaligned against the row it labels.
The misalignment itself **predates** round 6's extraction (round 6 recorded
the padding prefix as already byte-identical across the two sites), so this
is not a regression the extraction introduced -- it is the reason the
extraction did not fix the user-visible symptom. Human-facing only; nothing
parses these tables.

**Caveat (no Bash this round):** the column offsets above were computed by
hand from Grep-confirmed exact space counts, not by running `edm-state
get-coverage` and `edm-state metrics-report` and diffing the rendered output.
Confirm the exact offsets by running both before choosing the pad values. The
structural finding -- one shared row, four independently-maintained headers,
two mechanisms -- does not depend on the arithmetic.

**Fix.** Give each row def a matching header/underline def beside it
(`COVERAGE_LAYER_HEADER_JQ_DEF` / `COVERAGE_EPIC_HEADER_JQ_DEF`, emitting both
the header and the underline from the same padding constants the row uses),
and reference them from all four sites -- converting metrics-report's
`printf` pair to the shared def too, so one mechanism owns the widths. Extend
`wave5-smoke.sh:112`'s existing byte-identity assertion to cover the header
rows, not just the shared row columns.

#### L10-103 (P2) -- `set-supersedes` and `set-forked-from` are a 7-line copy-paste pair, and the four provenance setters have diverged on HANDOFF refresh

- **File A**: `bin/edm-state:4620-4627` (`cmd_set_supersedes`)
- **File B**: `bin/edm-state:4629-4636` (`cmd_set_forked_from`)

Structurally identical seven-line bodies -- same arg-count guard, same
`require_jq`, same non-empty check, same single-key `rmw_state` with
`.last_updated`, same confirmation echo -- differing only in the state key
(`.supersedes` / `.forked_from`) and the subcommand name interpolated into the
usage string, the error message and the echo.

**The diverged half, which is the more interesting one.** Four subcommands
write a cross-initiative prefix link into state. Two of the four call
`write_handoff_internal` after the write and two do not:

| Subcommand | Line | Validates target exists | Refreshes HANDOFF.md |
|---|---|---|---|
| `cmd_set_supersedes` | `:4620` | no | **no** |
| `cmd_set_forked_from` | `:4629` | no | **no** |
| `cmd_set_parent` | `:4658` | yes (`:4664`) | yes (`:4667`) |
| `cmd_add_related` | `:4671` | yes (`:4677`) | yes (`:4687`) |

The **validation** asymmetry is at least consistent with the documentation --
`plugins/edm/CLAUDE.md`'s state-field table claims "validated to exist" for
`parent_prefix` only, and claims nothing for `supersedes`/`forked_from`. The
**HANDOFF-refresh** asymmetry is documented nowhere, and it is observable:
`_write_handoff_body` reads both `supersedes` (`:5038`) and `forked_from`
(`:5039`) into the rendered artifact, so setting either leaves the committed
cross-user resume doc showing the stale value until some unrelated command
happens to rewrite it.

**Severity held low, and note the cheaper fix.** Round 6's **G30/CA-357**
already found both subcommands have zero callers and no user-facing
documentation. If CA-357 resolves by deletion, this finding closes for free
and no extraction is warranted -- so **do not extract a helper before
CA-357 is decided.** If they are kept instead, collapse both into one
`_cmd_set_provenance_link <state-key> <subcommand-label> <prefix> <other>`
and bring the pair in line with `cmd_set_parent`'s `write_handoff_internal`
call in the same edit.

#### L10-104 (P2) -- `migrate-schema` routed the enumeration through `list_state_files` but kept both archived path shapes, and the new comment claims otherwise

The enumeration half of round 6's fix genuinely landed: `bin/edm-state:2587`
now reads `done < <(list_state_files --archived)` and the two hand-globs are
gone.

The **shape knowledge** did not move. `:2582-2583` re-encodes both archived
layouts as `case` patterns:

```bash
      "${SRD_ROOT}/.archived/${prefix}/.edm-state.json") archived_hit="$_ms_f" ;;
      "${SRD_ROOT}"/.archived/*/"${prefix}__"*/.edm-state.json) archived_hit="$_ms_f" ;;
```

against `list_state_files`' own two shapes at `:137-138`. The new comment at
`:2575-2578` claims: "routed through `list_state_files`' already-deduped
enumeration instead, **so a future archived layout variant only needs to be
taught to `list_state_files`, not to every probe of it**." That claim is
false for this site as written -- a third archived shape taught to
`list_state_files` (say a nested `.archived/PRODUCT/SUBPRODUCT/PREFIX__
desc/`) would be enumerated but would match neither `case` arm, `archived_hit`
would stay empty, and the AC4 archived-initiative refusal would silently stop
firing for that shape. Same class as the CA-012 docstring round 6's L10-001
corrected: a comment asserting a drift class is closed, one file-local edit
short of being true.

**Partial mitigation, stated fairly:** this site genuinely needs *some*
per-prefix knowledge, because `list_state_files` does not filter by prefix.
So the residual is smaller than the original finding, and the honest framing
is "the comment overclaims by exactly the amount the fix left behind."

**Fix.** Add `archived_state_file_for <prefix>` next to `state_file_for`
(which `:208-218` declares the "single source of layout truth"), owning both
the `list_state_files --archived` call and the prefix filter, and call it
here; then the comment's claim becomes true. Cheaper alternative: narrow the
comment to "the enumeration is shared; the two shape patterns below are still
local to this probe."

#### L10-105 (P2) -- CA-344's five duplications, individually re-verified as still present and undiverged

Deferred in round 6 with the rationale "five mechanical duplications, no
divergence, no false claim." Re-read all five against current code; the
rationale still holds and no divergence has appeared.

1. **Prefix-format regex duplicated** -- `bin/edm-init:53`
   (`^[A-Z][A-Z0-9]{2,5}$`, message "prefix must be 3-6 uppercase alphanumeric
   chars, starting with a letter") vs `bin/edm-validate-prefix:42-44` (same
   regex, message adds `(got '$PREFIX')`). `edm-init` still delegates to the
   validator at `:81-86` behind `command -v`, so the format is still checked
   twice on a normal install. Unchanged.
2. **Effective-grant predicate, once per direction** --
   `bin/edm-check-grants:256-263` (`assert_agent_grant`, positive) vs
   `:501-507` (AC3 negative loop). Byte-equivalent three-statement `tools`-
   minus-`disallowedTools` rule. Unchanged.
3. **Lookback window computed twice** -- `bin/edm-check-grants:360-368`
   (`nearby_agent_name`) vs `:370-375` (`window_mentions_lens`), identical
   `lo=$((line - lookback)); [[ $lo -lt 1 ]] && lo=1; sed -n
   "${lo},${line}p"`. `resolve_targets_for_line:377-390` can still call both
   for one hit, so the `sed` range is still *executed* twice per candidate
   line. Unchanged.
4. **`edm-lint-artifacts`' three mode arms** -- the `while IFS= read -r -d
   "" _md_f` collect loop at `:414-417`, `:438-441`, `:486-489`, and the
   violations-summary/exit block at `:426-432`, `:457-463`, `:499-505`. The
   0-clean/1-violations exit contract the `PreToolUse` hook depends on is
   still encoded three times. Unchanged.
5. **Product-dir collision scan twice in one 90-line script** --
   `bin/edm-validate-prefix:58-72` (live, guarded by `[[ -d "$SRD_ROOT" ]]`,
   `.archived` basename skip, `die`s) vs `:80-87` (archived, no outer `-d`
   guard, no basename skip, warns). The doubled separator at `:80`
   (`"${SRD_ROOT}/.archived/"/*/`) is still present and still globs
   correctly. Unchanged.

All five remain P2 with the round-6 rationale intact. Sequence them behind
L10-100 and L10-101.

## Noted / Not Actionable

1. **`check_refuses_and_leaves_state` duplicates `check_fails`' substring
   logic and `check_state_unchanged`'s hash compare** (`bin/tests/
   _harness.sh:320-353` vs `:155`, `:294-310`). **Deliberate and well-argued**
   at `:312-319`: composing the two would require two separate executions of
   the command under test, "neither of which alone proves the other"
   (CA-042). False-alarm filter criterion 1 applies squarely -- this is the
   rare case where the duplication is the fix.
2. **`count_matches` vs `count_matches_strict`** (`_harness.sh:186`, `:198`)
   -- near-identical four-line bodies, but the difference *is* the point
   (CA-145: the strict form refuses to collapse grep's exit 1 and exit 2),
   and `:180-185` documents when each is correct. Not a copy.
3. **Per-script `die()` in nine `bin/` helpers and three `evals/` drivers**
   -- each carries its own script-name prefix and its own exit-code family
   contract (documented at `edm-validate-prefix:22-25`, `edm-compare-
   eval:39-40`), and `wave7-smoke.sh:7742` pins the per-script default codes
   as a deliberate matrix. `_edm-cli-lib.sh` shares only `print_help`.
   Intentional; not a finding.
4. **`date -u +"%Y-%m-%dT%H:%M:%SZ"` at `bin/tests/wave6-smoke.sh:3972` and
   `bin/tests/_harness.sh:402`** against `now_utc` (`edm-state:738`) -- both
   are test-side fixture builders that must not depend on the binary under
   test. False-alarm filter criterion 2. `evals/run-eval.sh:348` uses a
   deliberately different compact format for directory names;
   `skills/push-jira/SKILL.md:165` is prompt text.
5. **`_harness_hash_file` (`_harness.sh:279`) vs `artifact_hash`
   (`edm-state:171`)** -- same class as #4: the harness cannot hash via the
   binary it is testing. The two also branch on different tool preference
   orders (`shasum`-first vs `sha256sum`-first), which is cosmetic given both
   produce SHA-256.
6. **`cmd_set_parent` vs `cmd_add_related`** (`edm-state:4658`, `:4671`) --
   share the validate-then-write-then-refresh skeleton, but `add_related`'s
   idempotent list-append jq is genuinely different work from a scalar set.
   Not raised (the `supersedes`/`forked_from` pair in L10-103 is the real
   copy).
7. **Five UserPromptExpansion command hooks byte-identical apart from one
   token** (`hooks.json:19/32/45/58/71`) -- JSON has no include mechanism.
   Unchanged from prior rounds.
8. **The five prompt bodies duplicating their sibling command hooks'
   procedure** -- deliberate, self-documented advisory second layer.
9. **`SRD_ROOT="${EDM_SRD_ROOT:-${CLAUDE_PLUGIN_OPTION_SRD_ROOT:-./SRD}}"` in
   four scripts plus the git-commit hook** -- each is an independent entry
   point that resolves its root before `_edm-cli-lib.sh` is sourced; the
   hook cannot source bash libraries at all. Consistent everywhere.
10. **`_cmd_archive_move_body` vs `_cmd_migrate_path_move_body` lock-name
    sweeps** -- divergence deliberate and explained at length. Unchanged.
11. **`evals/score-artifacts.sh`'s `_scan_mermaid_blocks` vs
    `_edm-lint-lib.sh`'s `build_line_classes`** -- both load the shared
    `bin/edm-mermaid-rules.awk` via `-f` (CA-019); the one behavioural
    difference is stated at `score-artifacts.sh:99`. Note this is the
    *scanning* half of `score-artifacts.sh` and is correctly single-sourced
    -- unlike its *comparison* half, which is L10-100.
12. **`edm-check-vocabulary`'s match loop vs `_lint_report_class_hits`** --
    genuinely different designs. Unchanged from round 6.
13. **CA-283 (`run-eval.sh`'s three phase blocks)** -- carried as NOTED;
    not re-checked (see Meta).

## Meta

- **Coverage this round, stated honestly.** Read in full or in the relevant
  part: `bin/edm-state` (the extraction sites `:836-887`, `:1052-1072`,
  `:2214-2243`, `:2486-2525`, `:2570-2599`, `:3298-3330`, `:4618-4688`,
  `:5010-5078`, plus `:1-850` by grep sweep), `bin/edm-validate-prefix`
  (whole), `bin/edm-init:40-94`, `bin/edm-check-grants:248-269`/`:352-390`/
  `:488-517`, `bin/edm-lint-artifacts:405-507`, `bin/edm-compare-eval`
  (whole), `evals/score-artifacts.sh:655-734`, `bin/_edm-cli-lib.sh` (whole),
  `bin/tests/_harness.sh:180-368`, `bin/tests/wave6-smoke.sh:760-809`, and
  targeted greps across `evals/` and `bin/tests/`.
- **Not read closely** (report as unaudited, not clean): `bin/edm-state:
  5100-end` (the HANDOFF next-action ladder and the pattern-library
  renderers), `bin/tests/wave6-smoke.sh` and `wave7-smoke.sh` in full (~11.5k
  lines -- the direct cause of CA-037's L10 half going unverified a second
  round), `bin/tests/run-all.sh`, `bin/tests/timing.sh`, `evals/run-eval.sh`,
  `evals/tiering-matrix.sh`, `.gitlab-ci.yml`, `bin/edm-check-vocabulary`,
  `bin/edm-check-skill-sync`, `bin/edm-sync-canonical-sections`,
  `bin/_edm-lint-lib.sh`.
- **Tooling gap (ledger CA-130, eighth consecutive round).** `Write`, `Edit`
  and `Bash` absent from this lens's delivered tool set. Bash absence meant
  no `diff`/`sort`/`uniq` for duplicate detection and no ability to *run*
  the two coverage commands (L10-102's caveat) or the two eval comparers
  (L10-100's exit codes were read from source, not observed). **CA-331
  remains a precondition, not a nicety.**
- **One durability recommendation, cross-cutting.** L10-101 is the third
  instance in two rounds of two same-round fixes invalidating each other,
  and the first where a DRY extraction and a sibling fix collided. G10/
  CA-340's durability guard covers stale *citations* only. Recommend
  extending it: when a remediation extracts a helper, the same commit must
  add a `count_matches_strict`-based single-definition pin for the extracted
  literal (the shape `wave6-smoke.sh:781-784` already uses for the gate-
  approval half), and any other fix landing in the same round must be
  re-grepped against the new helper before the round closes.
</content>
