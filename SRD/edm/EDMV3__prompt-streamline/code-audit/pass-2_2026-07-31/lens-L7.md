# Code Audit Lens L7: Cross-File Consistency

- **Date**: 2026-07-31 | **Round**: pass-2 (full, 11 lenses) | **Branch**: `edm/edmv3-prompt-streamline`
- **Scope**: `plugins/edm/**` (bin, bin/tests, skills, agents, hooks, evals, docs, CLAUDE.md,
  CHANGELOG.md, README.md) plus repository-root `.gitlab-ci.yml` and `.gitignore`
- **Method**: every L7-tagged round-1 finding re-checked at its cited site against the current tree,
  then a fresh full pass. The prior ledger's `status` field was ignored as instructed; verdicts below
  are from the code as it stands today.
- **Note**: this agent had no `Write` tool at runtime despite its frontmatter granting one, so both
  halves of this report were returned as text for the orchestrator to persist. Same defect as
  round 1 (CA-130).

## Verification summary of prior L7 findings

| ID | Round-1 severity | Verdict now | One-line basis |
|---|---|---|---|
| CA-005 | P1 | **partially fixed -- open** | `edm-sync-canonical-sections` is the only bash entry point still without `EDM-HELP` sentinels; two extractor shapes and a four-way dispatch split remain |
| CA-006 | P1 | **fixed** | `.gitlab-ci.yml:298` is `apk add --no-cache jq git`; `:303` asserts bash 3.2 |
| CA-009 | P1 | **fixed** | one `build_line_classes`, in `_edm-lint-lib.sh:3`, de-indents at `:28`; both checkers source it |
| CA-010 | P1 | **partially fixed -- open** | the "mirrored VERBATIM" comments are gone, but `wave7-smoke.sh:296-299` still greps for the dead symbol `build_ignore_set` |
| CA-016 | P1 | **fixed** (L7 element) | `wave4b-smoke.sh:175` emits the standard summary; `run-all.sh:65` has one parser; CRASH is distinguished at `:92-99` |
| CA-032 | P1 | **fixed** | `plan/SKILL.md:8` grants `Edit` |
| CA-045 | P2 | **fixed** (L7 element) | `wave7-smoke.sh:18-19` now has a TMPDIR-honoring root and `trap ... EXIT INT TERM` |
| CA-046 | P2 | **fixed** | `.alpine_edm:42` / `.node_edm:46`; each digest spelled once; `validate:manifest:373` uses the anchor |
| CA-048 | P2 | **fixed** | all three curation blocks say "with the `Grep` tool" (`code-audit:325`, `audit-srd:162`, `audit-tickets:180`) |
| CA-049 | P2 | **partially fixed -- open** | `edm-check-vocabulary:56` and `edm-sync-canonical-sections:32` still derive from `$0`; four derivations, two names |
| CA-074 | P2 | **open** | `die()` still has four shapes; `edm-validate-prefix` still inverts the family; neither `set -uo` site got its comment |
| CA-075 | P2 | **fixed** | `needs: []` at `.gitlab-ci.yml:374` and `:482` |
| CA-076 | P2 | **partially fixed -- open** | `git` dropped and the doc count made dynamic; three lint jobs still print no terminal verdict |
| CA-077 | P2 | **fixed** | `update-patterns` moved to step 9a (`code-audit/SKILL.md:78`), before the gate |
| CA-078 | P2 | **fixed** | all four gates append to `decisions.md` (`plan:79`, `audit-srd:49`, `audit-tickets:51`, `code-audit:111`) |
| CA-079 | P2 | **open** | 51 non-ASCII bytes across seven test files; `run-all.sh:50` still prints an em dash to stdout in a blocking job |
| CA-080 | P2 | **partially fixed -- open** | the FAF lead-in is now uniform across all eleven; the trailer and the logic-lens rendering are not |
| CA-081 | P2 | **open** | unchanged: `edm-test-e2e.md:139` is still a bare `"N/A"`; a11y's two strings still disagree |
| CA-112 | NOTED | noted (carried) | floating `bash:3.2` tag at `:294`, rationale at `:284-291`; the `apt-get` half is now fixed |
| CA-115 | NOTED | noted (carried) | deliberate non-suppression on grant source 2 |
| CA-116 | NOTED | noted (carried) | actor-first output shape, now the 5-arg arm of the shared `report_violation` |

**Centerpiece verdict**: `plugins/edm/bin/_edm-lint-lib.sh` exists and is real. It is sourced by
`edm-lint-artifacts:52`, `edm-check-grants:101` and `edm-check-vocabulary:57` -- **three consumers,
not two** -- and none of the three carries a hand-copied `build_ignore_set`, `is_ignored_line` or
`report_violation` any longer. `build_line_classes` has exactly one definition
(`_edm-lint-lib.sh:3`) and it de-indents (`:28`), so CA-009 is genuinely closed. **But
`evals/score-artifacts.sh` -- the third hand-copy named in root cause #1 of the remediation plan --
does not source the library and still hand-rolls a column-1-anchored fence detector.** See F3 below.

## Findings (L7: Cross-File Consistency)

### F1 (P1, CA-005 re-opened): `edm-sync-canonical-sections` is the last pre-T61 help shape, and the class has no guard

`plugins/edm/bin/edm-sync-canonical-sections:43` versus the fourteen files that now carry sentinels
(`edm-state:9/53`, `edm-lint-artifacts:6/47`, `edm-check-grants:2/59`, `edm-check-vocabulary:73/81`,
`edm-init:2/15`, `edm-validate-prefix:2/14`, `edm-check-skill-sync:2/23`, `edm-compare-eval:2/30`,
`evals/run-eval.sh:4/44`, `evals/score-artifacts.sh:8/87`, `evals/tiering-matrix.sh:2/60`).

The remediation landed everywhere it was asked to except here. `edm-sync-canonical-sections` has no
`EDM-HELP-BEGIN`/`EDM-HELP-END` block at all, and its `--help` is still the third extractor variant:

```bash
awk '/^# edm-sync-canonical-sections/{f=1} f{print} /^set -euo pipefail/{exit}' "$0" | sed '$d'
```

It is keyed on the literal line `set -euo pipefail`, so moving or annotating that line silently
truncates or unbounds the help output -- the precise failure mode the sentinels were introduced to
retire. Three secondary axes of the same finding also survive:

- **Two extractor renderings.** Six scripts keep the `# ` prefix
  (`edm-state:98`, `edm-lint-artifacts:61`, `edm-check-grants:63`, `edm-check-vocabulary:70`,
  `edm-init:21`, `edm-validate-prefix:21`, plus `run-eval.sh:57` and `score-artifacts.sh:91`); three
  strip it and `exit` rather than clearing the flag (`edm-check-skill-sync:28`,
  `edm-compare-eval:35`, `tiering-matrix.sh:67`). The same request yields two visual formats.
- **The extractor's own argument splits three ways**: `"$0"` in six, `"${BASH_SOURCE[0]}"` in five,
  `"$1"` in `edm-state:98` (called with `"$0"` at `:4248`). `"$0"` is wrong for a sourced script,
  which is the same defect as F5 below.
- **Dispatch still splits four ways**: `-h|--help|help` in six, `-h|--help` in four
  (`edm-sync-canonical-sections:42`, `edm-check-skill-sync:30`, `edm-compare-eval:38`,
  `tiering-matrix.sh:70`), plus `edm-state:4247` which additionally accepts the empty string.

The CI grep the remediation asked for (`sed -n '[0-9]*,[0-9]*p' "$0"` banned) does not exist in
`.gitlab-ci.yml`, so nothing prevents the hardcoded-range form from returning.

**Why consistency matters**: `--help` is the exit-code contract's only human-readable surface, and
CI and the smoke suite key off what it prints. One script whose help boundary is a `set` line is a
latent silent truncation.

**Fix**: wrap `edm-sync-canonical-sections`'s header at `:2-29` in the sentinels and call the
same `print_help` shape; settle on one extractor body and `"${BASH_SOURCE[0]}"`; standardise all ten
on `-h|--help|help`; add the banned-form grep to `lint:bash-syntax` or the contract suite.

### F2 (P1, CA-010 re-opened): the one assertion guarding the shared-library boundary still greps for a symbol that exists nowhere

`plugins/edm/bin/tests/wave7-smoke.sh:296-299` against `:1683`.

The prose defect is fixed -- `edm-check-vocabulary:50-51` now correctly reads "sources the shared
lint helper library used by `bin/edm-lint-artifacts`", and `edm-check-grants` makes no mirror claim.
The test did not follow. `:296` still announces:

```
T03 AC8 -- mirrors (not re-derives) edm-lint-artifacts's report_violation/build_ignore_set/is_ignored_line
```

and `:297` greps `edm-check-grants` for `report_violation\|build_ignore_set\|is_ignored_line`,
passing on any hit. `build_ignore_set` no longer exists anywhere in the tree except this assertion
and `:1683`'s `check_absent "T43 AC1 -- build_ignore_set no longer present"` -- so one suite
simultaneously asserts the symbol is gone and describes a second file as mirroring it. Worse for the
architecture this round is meant to protect: the assertion passes on the presence of *call sites*,
so it would pass equally if someone deleted the `source` line and pasted the three helpers back in.
The single test standing guard over the shared-library boundary cannot detect its removal.

**Fix**: replace `:296-299` with a behavioural pair -- assert `edm-check-grants` contains
`source "${SCRIPT_DIR}/_edm-lint-lib.sh"` and contains no `^build_line_classes()` /
`^is_ignored_line()` / `^report_violation()` definition of its own, and assert the same for
`edm-check-vocabulary`. Update the echo text to name `build_line_classes`.

### F3 (P1, new): the shared-library extraction stopped at two of three consumers, and the comment explaining why is now stale

`plugins/edm/evals/score-artifacts.sh:300-334` (and its header rationale at `:64-82`) against
`plugins/edm/bin/_edm-lint-lib.sh:27-58`.

Root cause #1 of the round-1 remediation plan named three hand-copies: `edm-check-grants`,
`edm-check-vocabulary` and `evals/score-artifacts.sh`. Two were converted. The third was fixed *by
re-copying*: the scorer's rule body at `:280-297` has since gained the curly-label form (`:289`),
the sequenceDiagram message rule (`:293-297`), the generalized entity strip (`:256-277`), the
trailing-terminator strip (`:285`) and the three `%%`/`classDef`/`style` exemptions (`:280-282`) --
so most of CA-019's divergence list closed. One axis did not come along:

```awk
if ($0 ~ /^```[Mm][Ee][Rr][Mm][Aa][Ii][Dd][[:space:]]*$/) {   # :303 -- anchored at column 1
if (in_block && $0 ~ /^```[[:space:]]*$/) {                    # :311 -- anchored at column 1
```

against the canonical detector, which de-indents before measuring the backtick run:

```awk
fence_body = line
sub(/^[[:space:]]+/, "", fence_body)     # _edm-lint-lib.sh:27-28
```

So an indented ```mermaid fence -- the shape the de-indent fix was written for, and the shape this
plugin's own `fixtures/mermaid/valid/v12-indented-fence.md` exists to cover -- is invisible to
dimension 3: the block is neither `OK` nor `BAD`, it silently leaves the denominator, and the score
rises. The two implementations of "what is a mermaid fence" now disagree.

Compounding it, the header comment that justified not extracting is now false in its own terms.
`:80-82` reads: *"The de-duplication worth doing is therefore not 'call the linter': it is to lift
the shared semicolon-detection awk into one sourceable file both consume. That is a bin/ change and
is not attempted here."* That `bin/` change landed -- `bin/_edm-lint-lib.sh` exists and two other
consumers use it -- so the file documents an absent precondition that is now present. This is not a
documented-as-intentional exception; it is a stale rationale for work the plan asked for.

**Why consistency matters**: this is the finding the shared library was created to prevent. Two of
three copies converged; a third copy with its own fence grammar is exactly how the class returns.

**Fix**: source `bin/_edm-lint-lib.sh` from `score-artifacts.sh` (the AC6 "nothing beyond bash 3.2
and jq" constraint is not violated by sourcing a bash file -- no new binary is put on PATH), use
`build_line_classes`'s `mermaid` set to bound the blocks, keep the scorer's per-block OK/BAD framing
and its exit-0 contract. Then rewrite `:64-82` to describe what is actually shared and what is
deliberately not. If the source is genuinely refused, port the de-indent to `:303` and `:311` in the
same commit and add a fixture asserting the two agree on `v12-indented-fence.md`.

### F4 (P2, CA-074 re-opened): `die()` still has four shapes across eleven scripts, `edm-validate-prefix` still inverts the family, and it leaks the exit code into its message

Four distinct contracts, none documented as intentional:

| Shape | Sites |
|---|---|
| `code="${2:-1}"` | `edm-lint-artifacts:55`, `edm-validate-prefix:24` |
| `code="${2:-2}"` | `edm-check-grants:67`, `edm-check-vocabulary:64` |
| fixed `exit 1`, no code parameter | `edm-init:24`, `edm-state:61`, `edm-sync-canonical-sections:37` |
| fixed `exit 2`, no code parameter | `edm-check-skill-sync:26`, `edm-compare-eval:33`, `evals/run-eval.sh:60`, `evals/score-artifacts.sh:100`, `evals/tiering-matrix.sh:65` |

`edm-lint-artifacts:55` is unchanged from round 1: every current call site passes an explicit `2`,
so today's behaviour is right, but a future `die` without the literal exits 1 -- indistinguishable
from "violations found", which is the exact confusion the 0/1/2 split exists to prevent, in the one
script whose exit code a `PreToolUse` hook consumes.

Two further elements are also unchanged:

- **`edm-validate-prefix` inverts the family contract** (`:7-10`): `1 = invalid format`,
  `2 = collision`, where every sibling uses `1 = violations found` and `2 = usage or environment
  error`. `:33`'s usage error also exits 1, so format error and usage error are one code.
- **`set -uo pipefail` without `-e` still carries no comment** at `edm-check-skill-sync:24` or
  `edm-compare-eval:31`. The remediation asked for a comment on `edm-compare-eval` (it has a real
  reason -- it captures comparison exit statuses) and `-euo` on `edm-check-skill-sync`; neither
  landed.

**New sub-defect at the same site**: `edm-validate-prefix:24` is

```bash
die() { echo "edm-validate-prefix: $*" >&2; exit "${2:-1}"; }
```

`$*` is the whole argument list and `$2` is the exit code, so all four call sites (`:33`, `:37`,
`:47`, `:62`) print the numeric code as the last word of the diagnostic --
`edm-validate-prefix: collision: SRD/AUTH already exists 2`. Every sibling that takes a code binds
`local msg="$1"` first and prints only that. Two of nine scripts emit a message shape no other
script emits.

**Fix**: `edm-lint-artifacts:55` -> `${2:-2}`; `edm-validate-prefix:24` -> `local msg="$1" code="${2:-1}"`
and re-map its exit codes onto the family (or state the exception in `CLAUDE.md`'s `bin/` table --
silence is the finding); `edm-sync-canonical-sections` -> usage errors exit 2, drift stays 1;
comment both `set -uo` sites or convert `edm-check-skill-sync` to `-euo`.

### F5 (P2, CA-049 re-opened): the plugin root is still resolved four ways under two names, and one of the `$0` sites now sources a library off it

Fixed: `edm-lint-artifacts:51` and `edm-check-grants:100` both use
`"$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"`.

Still open:

- `plugins/edm/bin/edm-check-vocabulary:56` -- `SELF_DIR="$(cd "$(dirname "$0")" && pwd)"`
- `plugins/edm/bin/edm-sync-canonical-sections:32` -- identical
- `plugins/edm/bin/tests/wave4b-smoke.sh:6` -- `PLUGIN_DIR="$(cd "$(dirname "$0")/../.." && pwd)"`,
  where its six sibling suites all use `${BASH_SOURCE[0]}`
- `plugins/edm/bin/tests/wave6-smoke.sh:714` -- a fourth derivation,
  `PLUGIN_DIR="$(cd "$(dirname "$EDM_STATE")/.." && pwd)"`

The `edm-check-vocabulary` case got worse, not better: line 57 is now
`source "${SELF_DIR}/_edm-lint-lib.sh"`, so the `$0`-derived root is load-bearing for a `source`
rather than just for a scan path. If the script is ever sourced (which `wave7-smoke.sh:31` already
does to `edm-state`, establishing that sourcing a `bin/` script is a pattern in this suite), the
`source` fails outright.

Naming is also unresolved: `SELF_DIR` + `PLUGIN_DIR` (vocabulary, sync), `SELF_DIR` alone
(lint-artifacts), `SCRIPT_DIR` + `PLUGIN_ROOT` (grants), `SCRIPT_DIR` alone (skill-sync,
compare-eval, tiering-matrix). Two names for one value.

**Fix**: `${BASH_SOURCE[0]:-$0}` at all four sites; settle on `SCRIPT_DIR` + `PLUGIN_ROOT` (the
majority pair among the scripts that need both) and rename the outliers.

### F6 (P2, new): the shared `report_violation` hard-codes both callers' counter names and silently counts nothing if neither is set

`plugins/edm/bin/_edm-lint-lib.sh:95-99` against `edm-lint-artifacts:125` (`violations=0`),
`edm-check-vocabulary:132` (`violations=0`) and `edm-check-grants:125` (`VIOLATIONS=0`).

```bash
if [[ -n "${violations+x}" ]]; then
  violations=$((violations + 1))
elif [[ -n "${VIOLATIONS+x}" ]]; then
  VIOLATIONS=$((VIOLATIONS + 1))
fi
```

The extraction preserved a pre-existing naming divergence instead of resolving it, and encoded it
into the shared helper as a two-arm probe on which global happens to exist. Three consequences:

1. A fourth consumer that names its counter anything else -- or forgets to declare one -- gets
   violations *printed* and *not counted*, so the script prints findings and exits 0. There is no
   diagnostic on that path; the `else` arm at `:90-93` only fires on a bad argument count.
2. A consumer that declares both (plausible if one is a loop-local) silently increments only the
   lowercase one.
3. The library now has a reason to change whenever a caller renames a variable, which is the
   coupling direction a shared library exists to remove.

**Fix**: have `report_violation` not touch caller state -- return 0 and let each caller do
`report_violation ... && violations=$((violations + 1))`, or export one canonical name
(`EDM_LINT_VIOLATIONS`) that the library owns and all three read. Rename
`edm-check-grants`'s `VIOLATIONS` to match either way.

### F7 (P2, new): `ignored_line_set()` survives as a byte-identical hand-copy in exactly the two files the shared library was created to de-duplicate

`plugins/edm/bin/edm-check-grants:127-130` and `plugins/edm/bin/edm-check-vocabulary:134-137` are
character-for-character identical:

```bash
ignored_line_set() {
  local file="$1"
  build_line_classes "$file" | awk -F'\t' '$2=="ignored"{print $1}'
}
```

`edm-lint-artifacts` legitimately does not use it -- it needs three projections from one
`build_line_classes` call and computes them together at `:254` under the documented single-pass
optimisation at `:234`. That justifies its absence from `edm-lint-artifacts`, not its duplication
across the two checkers. This is a small copy, but it is a hand-copy of a lint helper living in the
two files whose hand-copies produced ten findings last round, and the tab literal inside the awk
`-F` is exactly the kind of byte one editor normalises and the other does not.

**Fix**: move `ignored_line_set` into `_edm-lint-lib.sh` beside `build_line_classes` and delete both
copies.

### F8 (P2, CA-076 re-opened): three of seven lint jobs still print no terminal job-named verdict

`.gitlab-ci.yml:63-83` (`lint:bash-syntax`), `:85-98` (`lint:artifacts`) and `:134-154`
(`lint:shellcheck`) against `:112` (`lint:grants: OK -- ...`), `:125` (`lint:vocabulary: OK -- ...`),
`:177`/`:195` (`file-type-ban: ...`) and `:251` (`lint:pattern-library-contract: OK -- N library
doc(s) ...`).

Two of CA-076's three elements are fixed: `git` is gone from `lint:grants` (`:108`) and
`lint:vocabulary` (`:121`), and the hardcoded "all five library docs" is now the counted
`${doc_count}` computed at `:246`. The verdict element is not. `lint:bash-syntax` and
`lint:shellcheck` end on `[ "$FAIL" -eq 0 ] || exit 1`, so a green log's last line is a per-file
`OK: <path>`; `lint:artifacts` ends on the linter's own output. Four sibling jobs in the same stage
print a job-named terminal line. A reader scanning seven collapsed job logs cannot tell "passed"
from "stopped early" in three of them.

**Fix**: add `echo "lint:bash-syntax: OK -- N file(s) parsed"`, `lint:artifacts: OK` and
`lint:shellcheck: OK -- N file(s) clean` as the last script line of each, counted rather than
asserted.

### F9 (P2, CA-079 re-opened): the aggregator still prints a Unicode em dash to stdout in a blocking job

`plugins/edm/bin/tests/run-all.sh:2` and `:50`:

```bash
# run-all.sh - EDMV3-T20 smoke aggregator.      <- :2 carries U+2014, not the ASCII hyphen shown here
echo "EDM smoke aggregator - ${#_run_order[@]} suite(s) discovered"   <- :50, same
```

Unchanged from round 1. Current non-ASCII byte counts under `bin/`: `wave4a-smoke.sh` 10,
`wave3-smoke.sh` 10, `wave5-smoke.sh` 10, `harness-smoke.sh` 7, `_harness.sh` 11, `run-all.sh` 2,
`wave4b-smoke.sh` 1 -- 51 across seven files, while `wave6-smoke.sh`, `wave7-smoke.sh` and
`timing.sh` are clean. `run-all.sh:50` is the one that reaches stdout on every pipeline via the
blocking `test:smoke` job, so the aggregator emits on stdout the ASCII rule that
`plugins/edm/CLAUDE.md` Sec."Artifact content conventions" states for every artifact this
methodology produces and that the suite itself asserts for `edm-state`'s help text and for every
lens agent's output contract. `_harness.sh` mixes both conventions inside one file.

**Fix**: `run-all.sh:2` and `:50` first (they are the ones printed), then `_harness.sh` and the four
older suites. Consider extending `edm-check-vocabulary`'s scope (which already reaches `bin/`,
`edm-check-vocabulary:112`) or `edm-lint-artifacts` class 2 to cover `bin/tests/*.sh`.

### F10 (P2, CA-080 re-opened): the FAF lead-in was normalised to all eleven lenses; the trailer and the logic-lens rendering were not

Fixed: the sentence "Report every finding at your best-effort confidence level rather than
self-suppressing on uncertainty..." now appears exactly once in each of the eleven lens files.

Not fixed, and now more conspicuous because everything around it converged:

- `plugins/edm/agents/edm-audit-dead-code.md:50` opens the criteria with `Before reporting:` and
  closes at `:55` with `If yes -> "Noted / Not Actionable" with rationale.`
- `plugins/edm/agents/edm-audit-logic.md:51` opens with `Before reporting a finding:` and closes at
  `:56` with `If yes to any -> record as "Noted / Not Actionable" with a one-line rationale.`
- The other nine (e.g. `edm-audit-consistency.md:53-59`) have neither line: lead-in sentence,
  numbered criteria, next heading.

So two of eleven carry a preamble and a trailer the other nine do not, in two non-matching
phrasings each -- and the two trailers differ on whether the criteria are conjunctive ("If yes")
or disjunctive ("If yes to any"), which is a semantic difference, not just wording.

Second element also unchanged: `plugins/edm/agents/edm-audit-logic.md:73` renders the canonical
severity reference as a bulleted field inside a four-item list --
`- **Severity**: use the canonical severity scale (P0/P1/P2 + NOTED) from ...` -- where the other
ten render the identical bare sentence `Use the canonical severity scale (P0/P1/P2 + NOTED) from
...` (`dry:77`, `spec:84`, `docs:75`, `dead-code:71`, `runtime:80`, `test-quality:73`,
`edge-cases:75`, `consistency:75`, `security:81`, `wiring:90`).

**Fix**: delete the two preamble/trailer lines (the shared lead-in already states the rule), and
flatten `edm-audit-logic.md:72-76` to the bare sentence plus the fenced output block the other ten
use.

### F11 (P2, CA-081 re-opened): the test-writer N/A exit tokens are still not uniform and still not substring-distinguishable

Unchanged from round 1 in both halves.

| Agent | Step-0 token | Bottom-of-file string | Prefix-consistent? |
|---|---|---|---|
| `edm-test-component.md` | `:21` `"N/A -- no UI components"` | `:103` `N/A -- no UI components in scope (...)` | yes |
| `edm-test-composable.md` | `:20` `"N/A -- no hooks/composables"` | `:123` `N/A -- no hooks/composables in scope (...)` | yes |
| `edm-test-contract.md` | `:21` `"N/A -- no API contract"` | `:106` `N/A -- no API contract (...)` | yes |
| `edm-test-integration.md` | `:22` `"N/A -- no integration boundary"` | `:106` `N/A -- no integration boundary (...)` | yes |
| `edm-test-a11y.md` | `:20`/`:127` `"N/A -- no UI"` | `:136` `N/A -- no HTML-rendering UI components in scope.` | **no** |
| `edm-test-e2e.md` | `:22`/`:139` `"N/A"` | `:147` `N/A -- no browser-rendered UI, or ...` | bare token |

Two live defects:

1. `edm-test-a11y.md:138-139` claims "This is the same exit token as Step 0's carve-out above, named
   here so the caller can rely on a uniform signal" -- and it is not the same string. Four siblings
   satisfy that claim; a11y does not.
2. `"N/A -- no UI"` (a11y) is a strict prefix of `"N/A -- no UI components"` (component), and
   `"N/A"` (e2e) is a strict prefix of all five siblings. A caller matching by substring, which is
   what "a uniform signal" invites, cannot distinguish the a11y layer from the component layer, and
   matches e2e on every one of them.

**Fix**: widen e2e's Step-0 token to `"N/A -- no e2e target"` (or its bottom-of-file wording) and
a11y's to `"N/A -- no HTML-rendering UI"`, then make each bottom-of-file string begin with its own
Step-0 token verbatim, as the four correct siblings already do.

### F12 (P2, new): scratch-tree trap shapes diverge across the seven suites

| Suite | Root | Trap |
|---|---|---|
| `wave3-smoke.sh:15-16` | `mktemp -d` (bare) | `trap 'rm -rf "$TMP"' EXIT` |
| `wave4a-smoke.sh:15-16` | `mktemp -d` (bare) | `trap 'rm -rf "$TMP"' EXIT` |
| `wave5-smoke.sh:13-14` | `mktemp -d` (bare) | `trap 'rm -rf "$TMP"' EXIT` |
| `wave6-smoke.sh:19,29` | `mktemp -d "${TMPDIR:-/tmp}/edm-wave6.XXXXXX"` | `trap cleanup_wave6 EXIT INT TERM` |
| `wave7-smoke.sh:18-19` | `mktemp -d "${TMPDIR:-/tmp}/edm-wave7.XXXXXX"` | `trap 'rm -rf "$TMP"' EXIT INT TERM` |

CA-045's L7 element is fixed -- wave7 no longer hand-rolls untrapped `/tmp` directories, and its
per-case scratch trees now nest under `$TMP` (e.g. `:255`). What remains is a two-shape residue: the
three older suites trap `EXIT` only, so a `Ctrl-C` during a local run leaks a scratch tree, and they
ignore `TMPDIR`, so on a host with a redirected temp root they write somewhere the other two do not.
Nothing documents the split, and the newer shape is strictly better.

**Fix**: bring `wave3`/`wave4a`/`wave5` onto the wave6/wave7 shape (named template honoring
`TMPDIR`, `EXIT INT TERM`), or lift a `with_scratch_dir` helper into `_harness.sh` beside
`with_scratch_repo` (`_harness.sh:51`) and route all five through it.

## Noted / Not Actionable

- **CA-112 -- `test:smoke-bash32`'s floating `bash:3.2` tag** (`.gitlab-ci.yml:294`): still floating,
  still an authorized named exception with the rationale and the refresh procedure recorded in place
  at `:284-291`. The `apt-get` divergence that shared this job is now fixed (`:298`) and the version
  assertion the remediation asked for is present at `:303`.
- **CA-115 -- grant source 2 is deliberately not fence-suppressed** in `edm-check-grants`: unchanged
  and still correct; the lens launch template lives inside a fence and skipping it would blind the
  checker to the instruction it exists to catch. Not re-litigated.
- **CA-116 -- `edm-check-grants`'s actor-first output shape**: now expressed as the five-argument arm
  of the shared `report_violation` (`_edm-lint-lib.sh:88-89`), called from `edm-check-grants:243`.
  The arity-keyed dual output format is the deliberate accommodation of two documented contracts,
  required by T03 AC7. Only the counter-name half of that function is raised, as F6.
- **`report_violation`'s two output shapes selected by `$#`**: same rationale as above -- the 4-arg
  `path:line: class: snippet` form and the 5-arg `kind: name: class: file:line` form are both
  documented exit contracts (`edm-lint-artifacts:30`, `edm-check-grants:47-50`). The `else` arm at
  `:90-93` names the misuse rather than silently mis-formatting. Sound.
- **Redundant `is_ignored_line` guards**: `edm-check-grants:284,305` and `edm-check-vocabulary:231`
  wrap the call in `[[ -n "$ignore_set" ]] && ...` while `edm-lint-artifacts:286,300,313,331` call it
  bare, and the function already guards `[[ -n "$lineset" ]]` internally (`_edm-lint-lib.sh:82`).
  Cosmetic; no behavioural difference in either direction.
- **`eval:nightly` merging `*node_edm` and then overriding `rules:`** (`.gitlab-ci.yml:519` vs
  `:522-533`): correct -- an explicit key beats a `<<:` merge key in YAML, so the job gets the pinned
  node digest and its own `when:`-bearing rules. It does rely on merge-key precedence for a reader to
  see, and the anchor bundles two concerns one consumer only half-wants, but the behaviour is right
  and the `when:` requirement is documented at `:512-516`. Recorded, not raised.
- **`edm-check-vocabulary` carrying both a long header (`:2-53`) and a short sentinel block
  (`:73-81`)**: the abridgement is still an abridgement -- no contradiction between the two, and the
  sentinel block is the one `--help` prints. Folds away if F1's cleanup normalises the family.
- **`lint:shellcheck` scoped to `bin/*` only** (`.gitlab-ci.yml:145`) while `lint:bash-syntax` also
  covers `bin/tests/*.sh` (`:74`): documented at `:127-133`, test fixtures intentionally loose.
- **CA-024 re-check (shellcheck directives)**: clean. Six `# shellcheck disable=SC2086` comments
  exist, each immediately above its own deliberate word-splitting site and each carrying a `-- reason`
  clause: `edm-check-grants:110`, `:184`, `edm-state:939`, `:1262`, `:2105`, `:3077`, `:4167`. No
  file-level directive, no blanket suppression, no `--exclude` in the CI invocation, and the
  `--include=SC2086,SC2046,SC2048,SC2068` scoping at `:147` is documented at `:127-133`. The comment
  wording is identical across all six except where the reason genuinely differs.
- **CA-032 re-check (plan's `Edit` grant)**: fully consistent. `plan/SKILL.md:8` now grants `Edit`,
  matching `audit-srd:8`, `audit-tickets:8`, `tickets:8`, `srd:8`, `implement:8` and `code-audit:8`;
  Gate 1's append at `plan:79-83` is the same in-place `decisions.md` row shape Gate 2 uses at
  `audit-srd:49-52`. `implement/SKILL.md:8` no longer carries the unused `Bash(grep *)` the round-1
  finding asked to drop.
- **The four gates' `decisions.md` rows**: verified as one shape across all four
  (`| Gate N | <decision> | <chosen> | <rationale> | {date} |`), including the Convergence row's
  extra count detail at `code-audit:115`, which is additive rather than divergent.
- **The eleven lens agents beyond F10**: re-verified uniform -- the two-write-path Output contract,
  the ASCII clause, the `mkdir` explanation, the JSONL-is-authoritative sentence, the JSONL schema
  block and all five enum bullets. Only the lens ID and the mandate body differ, as intended.
- **`run-all.sh`'s minimum-suite-count floor**: `:27-30` fails on zero discovered suites but sets no
  higher floor. That element of CA-016 belongs to L4's accounting mandate, not to cross-file
  consistency; the L7 element (two summary formats, two parsers) is fixed.

## Not examined

`bin/edm-state`'s ~4,200-line subcommand body was compared only at its `set` flags, `die()`,
`print_help` and root-resolution sites, not internally. `hooks/hooks.json` and `monitors/monitors.json`
as a pair. `docs/audit-patterns/*.md` beyond the four-heading contract that CI already enforces. The
seven non-lens agents as a group. Individual assertion bodies inside `wave6-smoke.sh` and
`wave7-smoke.sh` other than the specific cases cited above. `.gitignore` was read for the temp-file
patterns CA-015 asked for but is L5's finding, not reported here.

## Handover notes

- 27 JSONL lines: 18 prior actionable L7 findings (9 fixed, 9 open/partially-fixed), 4 new actionable, 3 carried NOTED, 2 new NOTED.
- Files whose exact text is load-bearing for the open findings: `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-sync-canonical-sections` (line 43), `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/wave7-smoke.sh` (lines 296-299), `/Users/darryl.porter/projects/marketplace/plugins/edm/evals/score-artifacts.sh` (lines 80-82, 303, 311), `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/_edm-lint-lib.sh` (lines 95-99), `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-validate-prefix` (line 24).
- The centerpiece check came out two-thirds positive: the library exists and all three `bin/` consumers use it correctly, but `evals/score-artifacts.sh` was never converted and is the one place where the round-1 root cause is still live.
