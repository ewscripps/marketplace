# Lens L1: Logic, Correctness & Completeness -- EDMV3 Code Audit Round 2 (full)

**Date**: 2026-07-31 | **Round**: pass-2, full | **Branch**: `edm/edmv3-prompt-streamline`
**Scope re-read this round**: `plugins/edm/bin/edm-state` (4.2k lines), `bin/edm-lint-artifacts`,
`bin/_edm-lint-lib.sh` (new), `bin/edm-check-grants`, `bin/edm-check-vocabulary`,
`bin/vocabulary-{prohibited,allowlist}.txt`, `bin/tests/_harness.sh`, `bin/tests/run-all.sh`,
targeted reads of `bin/tests/wave7-smoke.sh`, `hooks/hooks.json` (read in full -- was unexamined in
round 1), `evals/run-eval.sh` (containment + aggregation), `evals/tiering-matrix.sh` (mktemp),
help/dispatch surfaces of all nine `bin/` helpers plus the three `evals/` scripts, repository-root
`.gitlab-ci.yml` and `.gitignore`.

## Round-1 L1 finding disposition

| ID | Sev | Round-1 site | Round-2 verdict | Evidence (current tree) |
|---|---|---|---|---|
| CA-001 | P0 | `edm-state:799`, `:1856` | **FIXED** | `edm-state:922` `sv="$(to_int "$sv" 0)"` precedes the `-ge`; `:1949-1951` coerces `current_version` before `-le`/`$(( ))`. All 12 `.current_phase` reads floor inside jq (`:1010`, `:1407`, `:1955`, `:2117`, `:2634`, `:2903`, `:3824`). |
| CA-002 | P0 | `wave7-smoke.sh:1575-1598` | **STILL OPEN** | See finding below -- prescribed cases absent. |
| CA-005 | P1 | `edm-check-grants:66-69` + 2 | **FIXED** | Sentinel extractor now in all named scripts. Minor residue noted. |
| CA-006 | P1 | `.gitlab-ci.yml:281` | **FIXED** | `:298` `apk add --no-cache jq git`; `:303` version assertion added. `grep -c apt-get` = 0. |
| CA-007 | P1 | `.gitlab-ci.yml:327/474/531`, `run-eval.sh:437-455,449` | **PARTIALLY FIXED** | Three CI captures fixed; containment status capture fixed; porcelain rename parse still wrong. |
| CA-008 | P1 | `edm-lint-artifacts:363` | **FIXED** | `:299` `while IFS=: read -r lineno _rest`; `_f` gone; all four class readers two-field. |
| CA-017 | P1 (L1 half) | `edm-lint-artifacts:136-137` | **FIXED (L1 half)** | `:128-131` now says class 4 filters on `EDM_MARKER_SET`, which matches `:345`/`:363`. |
| CA-044 | P1 | `edm-lint-artifacts:435,436,471` | **FIXED** | `:373` `${PREFIX}`, `:374` `${INIT_DIR}`, `:409` `${PATH_ARG}`; `:373` now says `edm-state init ${PREFIX}`. |
| CA-047 | P2 | `edm-state:3180` | **FIXED** | `:3342` `prior_verdict="$(... '.verdict // .prior.verdict // "PARTIAL"')"`, interpolated at `:3382`. |
| CA-051 | P2 | `edm-state:2870` | **FIXED** | `:3072` normalises with `\|\| true`, `:3073` dies explicitly when the result is empty. |
| CA-052 | P2 | `edm-state:374-376` | **FIXED** | `:429-430` `-v orr="$out_rate"` and `o*orr` in the awk body; no `-v or=` remains. |
| CA-113 / CA-114 / CA-117 / CA-118 / CA-122 | NOTED | -- | **STILL NOTED** | Re-verified unchanged and still correctly classified; see Noted section. |

---

## Findings (L1: Logic, Correctness & Completeness)

### CA-002 (P0, re-confirmed OPEN) -- `cmd_update_patterns`' insertion path still has zero test coverage

**Site**: implementation `plugins/edm/bin/edm-state:3676-3716` (`_splice_pattern_file`,
`_cmd_update_patterns_body`), `:3718-3805` (`cmd_update_patterns`); test at
`plugins/edm/bin/tests/wave7-smoke.sh:1607-1630`.

The code was rewritten as prescribed -- `with_state_lock "${pattern_file%.md}"` at `:3790`,
`write_atomic` at `:3712`, and the read-only guard now correctly tests the *directory*
(`:3764-3769`, `[[ ! -w "$pattern_dir" ]]`). **The test half was not written.** Verified directly:

- The only `update-patterns` execution in the whole suite is still `t42_ac9_case`
  (`wave7-smoke.sh:1607-1630`), which seeds one deliberately duplicate title and asserts
  `"no novel findings to append"` plus byte-identity of `srd-audit.md`. Both assertions still pass
  against an implementation that inserts nothing at all.
- The two prescribed cases do not exist. `grep -n 'update-patterns' plugins/edm/bin/tests/` returns
  five hits only: `:1002-1003` (a *source grep* for the string `mv`, not an execution), `:1619`,
  `:1623-1624`, and the BLOCKED-ON-OWNER echo blocks.
- `wave7-smoke.sh:2632-2640` still prints the full BLOCKED-ON-OWNER list -- AC1 (heading-targeted
  insertion), AC2 (missing-heading SKIP), AC3 (no orphan), AC4, AC5, AC6, AC7 (atomic insertion),
  AC8, AC9 (`pending-review`), AC10, AC11, AC12 -- naming
  `plugins/edm/bin/edm-state:1576-1692` as out of remit.
- `wave7-smoke.sh:2895-2907` still reads "coordination point for future update-patterns cases" and
  "`T56 AC8 -- BLOCKED-ON-OWNER (bin/edm-state): the ten-update-patterns-runs case requires T54's
  insertion-logic rewrite`". That rewrite has now landed; the note was not retired and the cases
  were not added.
- The scratch-binary half is also not done. `_harness.sh:78` prepends `_HARNESS_BIN_DIR` -- the
  **real** `plugins/edm/bin` -- to `PATH`, and `cmd_update_patterns:3730-3736` derives
  `patterns_dir` from `$0`'s directory. So `edm-state update-patterns` invoked from
  `with_scratch_repo` still resolves to the committed
  `plugins/edm/docs/audit-patterns/srd-audit.md`. If de-duplication regresses, the test writes into
  committed plugin source, exactly as filed.

**Concrete fix** (unchanged from the round-1 prescription, plus one addition): copy `bin/` and
`docs/` into the scratch tree and invoke the scratch binary as `t30_ac2_case` already does; add one
case with two novel `### ` headings plus a duplicate asserting exactly two entries appended, both
carrying `status: pending-review`, both between `## Anti-Patterns` and `## Pre-Flight Checklist`,
`_t56_four_heading_contract_check` clean afterwards, the duplicate skipped, and a second run
appending nothing; add a second case with `## Anti-Patterns` removed from the scratch document,
asserting the `skipping (nothing appended, no end-of-file fallback)` message on stderr, exit 0, and
byte-identity. Then delete the stale BLOCKED-ON-OWNER blocks at `:2632-2640` and `:2895-2907`.
**Addition**: assert the byte content of the appended block, not only its presence -- the new
finding below is precisely the class of defect a presence-only assertion cannot see.

---

### CA-007 (P1, re-confirmed PARTIALLY FIXED) -- the porcelain rename form is still mis-parsed

**Site**: `plugins/edm/evals/run-eval.sh:450-457`, specifically `:452`.

Three of the four sub-sites are fixed. `.gitlab-ci.yml:347-356` now uses
`ec=0; out="$(edm-state validate "$prefix" 2>&1)" || ec=$?` and branches on 3 / non-zero, naming
the prefix; `:494-500` uses `CLI_EC=0; OUT="$(...)" || CLI_EC=$?`; `:552-558` uses
`rc=0; bash .../edm-compare-eval ... || rc=$?` with the `3) ... NOT ARMED` arm now reachable.
`run-eval.sh:443-447` now captures the containment status separately and dies when git status
could not be read.

The fourth sub-site is unchanged:

```bash
# plugins/edm/evals/run-eval.sh:450-457
while IFS= read -r line; do
  [ -z "$line" ] && continue
  path="${line:3}"
  case "$path" in
    SRD/*) ;;
    *) CONTAINMENT_VIOLATIONS="..." ;;
  esac
```

`git status --porcelain` emits a rename as `R  <old> -> <new>`. `${line:3}` yields
`SRD/foo.md -> ../../evil.md`, which matches the `SRD/*` glob, so **a rename whose destination
escapes `SRD/` is scored as contained**. This is the AC9/EDMV3-93 safety property; it is the one
check that would catch the eval driver mutating the host tree.

**Concrete fix**: branch on the status field before slicing.

```bash
xy="${line%%"${line#??}"}"          # first two status characters
path="${line:3}"
case "$xy" in
  R*|C*) path="${path##* -> }" ;;   # porcelain rename/copy: destination is what matters
esac
case "$path" in SRD/*) ;; *) CONTAINMENT_VIOLATIONS=... ;; esac
```

Add a unit case that stages `git mv SRD/x.md ../escape.md` in a scratch tree and asserts
`containment: VIOLATION`.

---

### NEW (P2) -- `_splice_pattern_file` drops the entry's trailing newline, so the last appended entry is concatenated onto the line at the insertion point

**Site**: `plugins/edm/bin/edm-state:3699` (accumulation) and `:3676-3681` (`_splice_pattern_file`).

`_render_pattern_entry` (`:3663-3674`) ends with
`printf '> and how to prevent it -- ... not yet curated prose.\n'`. It is consumed through command
substitution at `:3699`:

```bash
pending_entries="${pending_entries}$(_render_pattern_entry "$raw_title" "$prefix" "$audit_type" "$today")"
```

`$( )` strips **all** trailing newlines, so `pending_entries` never ends in `\n`. The splice then
writes it with no terminator:

```bash
# :3676-3681
_splice_pattern_file() {
  head -n "$((insert_line - 1))" "$pattern_file"
  printf '%s' "$pending_entries"        # <-- no trailing newline
  tail -n "+${insert_line}" "$pattern_file"
}
```

Two consequences:

1. **Multi-entry appends have no blank line before the second and subsequent `### ` headings.**
   Entry N ends `...prose.` and entry N+1 begins with its own leading `\n` (`:3665`), which merely
   terminates entry N's last line. Only the first entry gets the blank separator the document
   convention uses.
2. **The last entry's final line is glued to the line at `insert_line`.** Today this is masked:
   `pattern_insert_line_for` (`:3643-3661`) backs up over trailing blanks and the `---` rule, so
   for the four shipped library docs `insert_line` lands on a blank line (verified for
   `docs/audit-patterns/code-audit.md`: `## Anti-Patterns` at 70, `---` at 101,
   `## Pre-Flight Checklist` at 103 -> `insert_line` = 100, a blank line), and gluing onto an empty
   line is a no-op. But when a section's last content line is immediately followed by the next
   `^## ` with no blank between them, `awk`'s `j = ins - 1` finds a non-blank, non-`---` line and
   returns `ins` itself -- the heading line. The append then produces
   `> ...not yet curated prose.## Pre-Flight Checklist`, destroying a `##` heading. The blocking
   `lint:pattern-library-contract` job (`.gitlab-ci.yml:224`) would then fail with
   "expected exactly 4 '##' headings, found 3", on a document the tool itself corrupted.

This is unreachable by any existing test because CA-002's insertion coverage does not exist.

**Concrete fix** -- restore the newline the command substitution strips, per entry, at `:3699`:

```bash
pending_entries="${pending_entries}$(_render_pattern_entry "$raw_title" "$prefix" "$audit_type" "$today")"$'\n'
```

That gives every entry a terminator, so entry N+1's leading `\n` becomes a real blank line and the
final entry cannot merge with `tail`'s first line. Leave `_splice_pattern_file`'s `printf '%s'` as
it is once this lands (changing that instead fixes only consequence 2, not consequence 1).

---

### NEW (P2) -- `write_atomic`'s status capture is only correct because every current caller happens to suspend `errexit`

**Site**: `plugins/edm/bin/edm-state:479-512`, specifically `:491-492` and `:500-501`.

```bash
  "$@" > "$tmp"
  ec=$?
  ...
  mv -f "$tmp" "$dest"
  ec=$?
```

`edm-state` runs under `set -euo pipefail` (`:54`). This is the same `cmd; rc=$?` shape the
round-1 remediation plan named as root cause 2 and replaced everywhere else with `|| rc=$?`
(`edm-state:1371`, `:3164`, `:3790`; `.gitlab-ci.yml:348`, `:495`, `:553`). It survives here only
because all five call sites are currently in `errexit`-suspended positions -- `:528` (`if !`),
`:1337` (via `with_state_lock ... || init_ec=$?` at `:1371`), `:3007`, `:3712` and `:4188` (all
`|| die` / `|| return 1`). Two problems follow:

1. The next bare `write_atomic "$dest" renderer` added anywhere in this file changes behaviour from
   "return the renderer's status, having removed the temp file and restored the caller's traps" to
   "abort the whole process at `:491` with the temp file removed only by the EXIT trap and the
   caller's saved traps never restored". Nothing in the helper's own contract comment warns of this.
2. On the `flock` branch `:1337` executes inside the `( flock -w 10 200 || exit 99; "$@" )` subshell
   at `:830`. Whether bash's `errexit`-suspension state propagates into a subshell created inside a
   tested AND-OR list is implementation-dependent, so the one bare call in the tree is relying on
   behaviour that is not portable across the two target shells (bash 3.2 on macOS vs bash 5.x /
   busybox on the CI image).

**Concrete fix** -- make the helper self-contained rather than caller-dependent, at `:491-501`:

```bash
  ec=0
  "$@" > "$tmp" || ec=$?
  if [[ $ec -ne 0 ]]; then ... fi
  mv -f "$tmp" "$dest" || ec=$?
  if [[ $ec -ne 0 ]]; then ... fi
```

Add a smoke case that calls `write_atomic` bare with a renderer that `return 1`s and asserts the
process survives, the destination is unchanged, and no `*.tmp.*` file is left behind.

---

### NEW (P2) -- `cmd_migrate_schema` silently rewrites a corrupt `schema_version` to `1` instead of reporting it, contradicting both its own comment and the function's "never lowers" contract

**Site**: `plugins/edm/bin/edm-state:1944-1951`, `:2002`, `:2012-2018`; contract claim at `:1915`.

The CA-001 coercion added at `:1949-1951` carries this comment:

```
# ... only a present-but-non-integer value is coerced, to 0, which then fails the `-le` guard
# and is reported rather than acted on.
```

Trace the actual path for a hand-written `"schema_version": "2.0"`:

- `:1950` -> `current_version="0"`.
- `:2002` prints `recorded schema_version: 0` -- the operator is shown `0`, not `"2.0"`, so the
  corruption is hidden rather than surfaced.
- `:2012` `[[ -n "0" ]]` is **true**.
- `:2013` `[[ "$target_version" -le "0" ]]` with `target_version` of 1 or 2 is **false**, so the
  `die` does not fire -- the comment's "fails the `-le` guard and is reported" is exactly inverted.
- `:2017` `target_version=$((0 + 1))` = 1, and `:2018` prints
  `advancing schema_version: 0 -> 1`.

So a file claiming shape 2 is stamped down to `1` after a `yes`, which contradicts the function
header at `:1915` ("Never lowers `schema_version`"). Every wave-B check (`cmd_archive`'s
PARTIAL-closure and audit-converged re-query at `:2172-2178`, `cmd_phase_complete`'s open-PARTIAL
check at `:1661`, `cmd_approve_gate`'s convergence precheck at `:1478`) silently degrades to
warn-and-proceed afterwards.

**Concrete fix** -- keep the coercion but make the non-integer case its own refusal, between
`:1944` and `:1949`:

```bash
if [[ -n "$current_version" && "$current_version" != "$(to_int "$current_version" "")" ]]; then
  die "migrate-schema: ${prefix} has a non-integer schema_version ('${current_version}'); repair the state file by hand -- refusing to guess a version"
fi
[[ -n "$current_version" ]] && current_version="$(to_int "$current_version" 0)"
```

and correct the comment at `:1945-1948` to describe the refusal rather than the `-le` guard.

---

### NEW (P2) -- two `get-coverage` renderers abort the process instead of degrading when the state file is unparseable

**Site**: `plugins/edm/bin/edm-state:1847-1858` and `:1860-1872`.

`cmd_get_coverage` runs four `jq -r` renderers over `"$state"`. The last two carry a fallback
(`:1879` `|| echo "  (no coverage data)"`, `:1888` `|| true`); the first two do not -- both end
`' "$state" 2>/dev/null` with no `||` guard. Under `set -euo pipefail` (`:54`), a state file that
`[[ -f ]]` at `:1843` accepts but jq cannot parse makes `:1858` exit 5, which aborts
`edm-state get-coverage` **with no message at all** (jq's diagnostic is already discarded by
`2>/dev/null`). The two later renderers were written to degrade; the two earlier ones were not, and
the difference is silent.

**Concrete fix**: append `|| true` to `:1858` and `:1872`, matching `:1888`, and add a single
`jq -e . "$state" >/dev/null 2>&1 || die "get-coverage: unparseable state file at $state"` guard
after `:1843` so the failure has a name.

---

### NEW (P2) -- `lint:file-type-ban`'s over-budget message ends in a colon that promises a listing it never prints

**Site**: `.gitlab-ci.yml:191-194`.

```yaml
      if [ "$evals_kb" -gt 100 ]; then
        echo "file-type-ban: tracked plugins/edm/evals/ content is ${evals_kb}KB, exceeds the documented 100KB budget:"
        exit 1
      fi
```

The trailing `:` is the sibling idiom used at `:173-174`, `:404`, `:407`, `:422`, `:425` and
`:443-444`, where each is immediately followed by the `printf`/`sed` that emits the offending list.
Here the only remaining statement is `exit 1`, so the blocking job tells a contributor their evals
directory is over budget and then names nothing -- they must recompute the per-file sizes by hand
to find what grew.

**Concrete fix**: emit the same per-file breakdown the total was computed from, between the `echo`
and the `exit`:

```bash
        git ls-files -- plugins/edm/evals \
          | while IFS= read -r f; do [ -f "$f" ] || continue; printf '  %8s  %s\n' "$(wc -c < "$f")" "$f"; done \
          | sort -rn
        exit 1
```

---

## Noted / Not Actionable

- **CA-113** (`bin/tests/run-all.sh:2`, `:50`; `bin/tests/_harness.sh:2`, `:14`, `:24`, `:42`) --
  literal U+2014 em dashes remain, including `:50`'s runtime console line. Still correctly
  classified: `vocabulary-allowlist.txt:25-28` carves out `plugins/edm/bin/tests/` explicitly, and
  no lint invocation reaches this tree (`CLAUDE.md` Sec."Artifact content conventions" says so in
  terms). The one actionable residue is already CA-079.
- **CA-114** (`edm-state:3619-3624`) -- `pattern_target_heading_for` still ignores `$1` and always
  returns `$PATTERN_DEFAULT_TARGET_HEADING`. Documented at `:3585-3592` as the intentional
  extension point, contractually coupled to adding a README mapping row. Unchanged, still not a
  defect.
- **CA-117** (`edm-check-grants:179-194`) -- `has_tool` still runs `set -- $list` unquoted under
  `IFS=','`. Carries `# shellcheck disable=SC2086 -- deliberate word-splitting` at `:184`; no tool
  token on disk matches a pathname and `nullglob` is off. Unchanged.
- **CA-118** (`edm-init:159`) -- `git rev-parse --verify "$BRANCH"` still unqualified to
  `refs/heads/`. Pre-existing, unreachable for the names this script generates. Unchanged.
- **CA-122** (`_edm-lint-lib.sh:60-63`) -- an `edm-lint-ignore-end` inside a fence still closes the
  ignore block and its own line is emitted in no class, because the `next` at `:62` precedes the
  in-fence `ignored` emission at `:65`. Requires a mermaid source line containing that literal HTML
  comment. Moved file, same behaviour, same rationale.
- **`hooks/hooks.json:86` exit-code collapse** -- read in full this round (it was unexamined in my
  round-1 report). The hook still exits `$fail` (1) for both the violation and the
  usage/environment class, but the contract text was brought into line rather than the code:
  `edm-lint-artifacts:33-35` now states "The current PreToolUse git-commit hook blocks on any
  non-zero exit and prints one generic remediation line for both classes of failure", and the
  hook's own message at `:86` now reads "Fix artifact violations **or edm-lint-artifacts
  setup/usage errors**". Documented-as-intentional -> not an L1 finding. The residual half -- that
  a `PreToolUse` hook must exit 2 to block, so `exit 1` does not actually block while
  `CLAUDE.md` Sec."Hooks behavior" says it does -- is CA-011's (L3+L6) territory and is confirmed
  still open there; not re-filed here.
- **`edm-state:2705-2708` (`gate-check` writes state)** -- `record_degraded_check` at `:2707` takes
  the write lock inside a command whose own `--help` line (`:31`) says "(read-only)", and five
  `UserPromptExpansion` hooks call it. The undeduplicated-append half is now fixed
  (`record_degraded_check:1173` guards with `any($existing[]?; .check == $c and .reason == $r)`),
  but the write itself remains. Already filed as CA-061 (L3); not re-filed as a new L1 ID.
- **`hooks/hooks.json:32` uses the `srd` token for the `edm:audit-srd` matcher** while `:58` uses
  `audit-tickets` for `edm:audit-tickets`. Asymmetric, but behaviourally identical:
  `cmd_gate_check:2680` maps `srd|audit-srd` to the same `required_gate=1`. Consistency nit, not a
  logic defect.
- **`edm-check-vocabulary` carries two help blocks** -- the full header at `:2-53` and an
  abbreviated sentinel block at `:73-81`, so `--help` prints the short one and the eight-root scope
  list, the allowlist semantics and the performance note are not shown. CA-005's mechanism
  (sentinels + awk) did land here, so the round-1 defect class is closed; the duplication is an L2/L7
  concern, not L1.
- **`edm-sync-canonical-sections:42`** accepts only `-h|--help`, not the bare `help` the other eight
  helpers accept. Dispatch-shape inconsistency, CA-005's L7 half; no incorrect behaviour.
- **`edm-state:1274-1279` accepts negative and fractional `current_phase`** -- the regex
  `^-?[0-9]+(\.[0-9]+)?$` permits `-1` and `3.7` through the sanctioned `cmd_set` path. Harmless in
  practice: every arithmetic reader floors inside jq, `cmd_phase_complete` keys off the CLI
  argument rather than state, and `cmd_archive:2118` still refuses a mismatch. Validation
  looseness, no reachable defect.
- **`edm-lint-artifacts:265-269`** assigns `lineno`, `snippet` and `_fence_diag` before the first
  `local` declaration at `:283`, so those three leak into the global scope for the duration of the
  run. No reader outside `scan_md_files` consumes them; cosmetic.
- **`bin/tests/run-all.sh` (CA-016)** -- the CRASH arm (`:92-95`), the exit-0-without-summary arm
  (`:96-99`) and the zero-assertion arm (`:77-80`) all landed, and the aggregate can no longer print
  `0 failed` beside `FAILED SUITES`. The remaining prescribed item (a per-suite minimum assertion
  count above 1, and a minimum suite count above 0) is L4/L7; not re-filed here.
- **`.gitignore:9-16`** now covers `.edm-state.json.bak`, `SRD/**/.edm-state.lock{,d/}`,
  `.edm-state.json.tmp.*`, `plugins/edm/docs/audit-patterns/*.{lock,lockd/,tmp.*}` and
  `SRD/**/*.md.tmp.*` -- CA-015's belt-and-braces half is confirmed landed.
- **`evals/tiering-matrix.sh:135`** -- `mktemp "${TMPDIR:-/tmp}/edm-tiering-matrix-selftest.XXXXXX"`,
  suffix removed, so the macOS `mkstemp(3)` EINVAL path is closed (CA-014's L1-adjacent half). The
  `trap ... RETURN`-only half at `:136` is unchanged and remains L5's.

## Coverage statement

Read in full this round: `bin/_edm-lint-lib.sh`, `bin/edm-lint-artifacts`, `bin/edm-check-grants`,
`bin/edm-check-vocabulary`, `bin/vocabulary-prohibited.txt`, `bin/vocabulary-allowlist.txt`,
`bin/tests/_harness.sh`, `bin/tests/run-all.sh`, `hooks/hooks.json`, `.gitlab-ci.yml`, `.gitignore`.
`bin/edm-state` read in full across `:1-2350` and `:2600-3820`, with targeted reads of `:3820-4200`
(handoff) driven by grep. Targeted reads of `bin/tests/wave7-smoke.sh` (`:1002-1003`, `:1560-1640`,
`:2590-2660`, `:2720-2910`) and `evals/run-eval.sh` (`:420-525`).

Not read this round (targeted greps only): `bin/tests/wave{3,4a,4b,5,6}-smoke.sh`,
`bin/tests/harness-smoke.sh`, `bin/tests/timing.sh`, `evals/score-artifacts.sh` body,
`evals/tiering-matrix.sh` body outside `:120-140`, `bin/edm-compare-eval`,
`bin/edm-check-skill-sync`, `bin/edm-sync-canonical-sections`, `bin/edm-init`,
`bin/edm-validate-prefix` bodies, `skills/**`, `agents/**`, `docs/**`, `CHANGELOG.md`, `README.md`
(prose surfaces -- L6/L10 own these).
