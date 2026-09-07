# QC Audit Report: EDMV4 wave-1 residual (Epics 03 / 05 / 06) [Shard 4]

**Date**: 2026-09-02
**Tickets audited**: EDMV4-T17, EDMV4-T38, EDMV4-T42 (3 of 3 assigned)
**Tree audited**: `edm/edmv4-ecc-integration` @ `9a63ac8`; relevant commits `1f3eb94` (T17, T38), `fd60bfd` (T42)
**Suite run**: `bash plugins/edm/bin/tests/wave8-smoke.sh` -> 126 passed, 0 failed
**Implementation mode**: `standard` (`.edm-state.json`) -- the TDD compliance pass does not apply

## Summary

| Ticket | Title | Verdict |
|---|---|---|
| EDMV4-T17 | Build the shared data-directory resolver library | **FAIL** |
| EDMV4-T38 | Create bin/edm-repo-readiness following bin/ house conventions | **PASS** |
| EDMV4-T42 | Define the JSON hookify rule format and its rule directory | **FAIL** |

No AC in this shard was runtime-only. All 29 ACs across the three tickets are statically
verifiable against the tree, so this shard records **zero PARTIAL verdicts** and nothing here
needs `/edm:verify-runtime`.

## Detailed Findings

### EDMV4-T17: Build the shared data-directory resolver library -- FAIL

8 of 10 ACs verified. Two smoke-coverage ACs fail: one asserts against three of its four named
constructs, the other asserts against the filesystem instead of the library.

- [x] **AC1** -- `plugins/edm/bin/_edm-datadir-lib.sh:1-137` exists. `/bin/bash` on this host is
      `GNU bash 3.2.57(1)-release (arm64-apple-darwin25)`; `bash -n` passes under it. Sourcing in
      a fresh `/bin/bash -c` defines exactly `edm_data_dir`, `edm_project_key`, `edm_marker_path`
      (plus the underscore-prefixed `_edm_datadir_creatable`), exits 0, emits nothing on either
      stream, and creates no files. Asserted at `bin/tests/wave8-smoke.sh:324-341`.
- [x] **AC2** -- `bin/edm-state:69` is `[[ -r "${SCRIPT_DIR}/_edm-datadir-lib.sh" ]] && source
      "${SCRIPT_DIR}/_edm-datadir-lib.sh"`, the required `[[ -r ... ]]` guard, rationale at
      `:64-68`. `bin/tests/wave8-smoke.sh:343-366` copies `edm-state` plus its two other libraries
      into a scratch bin dir *without* the datadir library and asserts `list --paths` and
      `validate EDMV4` return the same exit codes as with it present (both 0 either way).
- [x] **AC3** -- Only the three public functions plus one leading-underscore helper are defined
      (`_edm-datadir-lib.sh:69, 84, 113, 131`). Every value is function-local (`:70, 85, 113-114,
      123, 132`); no global is declared anywhere. `bin/tests/wave8-smoke.sh:377-391` diffs
      `compgen -v` before and after sourcing and requires an empty delta;
      `:393-407` sources the library alongside `edm-state` and asserts
      `PATTERN_AUDIT_TYPE_ENUM_LIST` and all three functions survive intact;
      `:370-375` greps `edm-state` for redefinitions of any of the four names.
- [x] **AC4** -- `_edm-datadir-lib.sh:84-110` implements the four steps in order. The
      relative-value fall-through is the `[[ "$candidate" == /* ]]` gate at `:88` and `:94` (a
      relative value fails the test and is skipped, never used); the terminal empty-string case is
      `:108-109`, which prints `""` and returns 0. `bin/tests/wave8-smoke.sh:411-435` covers all
      five cases including both relative fall-throughs.
- [ ] **AC5** -- **FAIL**. Neither half of this AC is exercised against the artifact under test.
      The library creates no subdirectory at all and never names `${data}/patterns/` in *code* --
      only in prose at `_edm-datadir-lib.sh:37-38`, which explicitly disclaims the creation as
      "each consumer's own job ... out of scope here". Only `${data}/run/` appears in code, via
      `edm_marker_path()` at `:135`. The AC5 smoke block at
      `bin/tests/wave8-smoke.sh:437-448` never sources the library and never calls any of its
      three functions: it `mkdir -p`s `${TMP}/t17-ac5-data/patterns` and `.../run` itself,
      `echo`es a file into each, then `ls`-es them back. It is a test of `mkdir` and `echo`,
      vacuously true regardless of what the library does.
- [ ] **AC6** -- **FAIL**. The library itself is compliant -- `grep '< <('`, `grep 'declare -A'`,
      `grep '\^\^'`, `grep 'mapfile'` over `_edm-datadir-lib.sh` all return nothing -- so the
      bash-3.2 property holds. The AC's second clause does not: it requires a smoke test that
      "greps the file for **each of those four** constructs and fails on any hit", and the grep at
      `bin/tests/wave8-smoke.sh:451-452` covers only three of them (`declare -A|readarray|mapfile`
      at `:451`, `\^\^` at `:452`). **Process substitution in a loop condition -- the CA-472
      fd-leak class the AC names explicitly -- is never grepped**, so that regression guard does
      not exist.
- [x] **AC7** -- `edm_data_dir()` (`:84-110`) and `edm_marker_path()` (`:131-136`) invoke no
      external binary; `_edm_datadir_creatable()` (`:69-81`) uses only `[[ -d ]]` / `[[ -w ]]` and
      `${p%/*}`. `edm_project_key()` execs `git rev-parse --show-toplevel` at `:117` only behind
      the `[[ -z "$dir" || ! -d "$dir" ]]` guard at `:116`, and encodes with parameter expansion
      (`:123-124`), not `tr`. The AC's stated assertion is implemented verbatim at
      `bin/tests/wave8-smoke.sh:461-478`: `CLAUDE_PROJECT_DIR` set to a scratch dir, a failing
      `git` stub earlier on `PATH`, all three functions required to succeed.
      *Interpretation note*: `edm_marker_path()` does fork two command substitutions
      (`:133-134`). `_edm-datadir-lib.sh:52-57` states in-file that "spawns zero subprocesses"
      means "invokes no external binary" -- consistent with the AC's own next sentence, which uses
      "spawn" for the `git rev-parse` exec. Graded PASS on that reading; the interpretation is
      declared in the artifact rather than hidden.
- [x] **AC8** -- All four branches are exercised by `bin/tests/wave8-smoke.sh:411-435` by
      manipulating `CLAUDE_PLUGIN_DATA`, `XDG_DATA_HOME` and `HOME`, including both
      relative-value fall-throughs and the all-fail case at `:426-435`, which asserts the returned
      string is empty **and** the exit status is 0 (`[[ "$T17_AC4_F" == "|0" ]]`). `:483-487`
      re-asserts the terminal case under the AC8 label.
- [x] **AC9** -- `bin/tests/wave8-smoke.sh:490-497` snapshots `git status --porcelain` on the repo
      root, invokes `edm_data_dir` and `edm_marker_path` with `CLAUDE_PLUGIN_DATA` unset, and
      re-snapshots. The test asserts before == after rather than the AC's literal "is empty"; the
      equality form is the correct, non-flaky way to prove the property and is a strict
      improvement, so no finding is raised.
- [x] **AC10** -- `plugins/edm/CLAUDE.md:1105` adds the `_edm-datadir-lib.sh` row to the `bin/`
      helper table, naming all three functions and their resolution chains. `architecture.md:109`
      is amended from "sourced by `edm-state`, `edm-gateguard` and `edm-hookify`" to "sourced by
      its two consumers, `edm-state` and `edm-gateguard`", with the `edm-hookify` exclusion and
      its D7/EDMV4-41 rationale stated inline, so AD3's prose now agrees with its own component
      table at `architecture.md:226-227`.

**Findings**:
```
[P1] EDMV4-T17 | plugins/edm/bin/tests/wave8-smoke.sh:437-448 | AC#5: Two subdirectories ... never conflated; a smoke test asserts a patterns/ write does not appear under run/ and vice versa | The AC5 block never sources the library or calls any of its three functions -- it mkdir -p's two scratch directories, echoes a file into each, and ls's them back. The assertion is vacuously true and proves nothing about _edm-datadir-lib.sh. The library additionally names ${data}/patterns/ only in prose (_edm-datadir-lib.sh:37-38), never in code.
[P1] EDMV4-T17 | plugins/edm/bin/tests/wave8-smoke.sh:451-452 | AC#6: A smoke test greps the file for each of those four constructs and fails on any hit | The grep covers three of four: declare -A / readarray / mapfile at :451, ^^ at :452. Process substitution in a loop condition -- the CA-472 fd-leak class the AC names by number -- has no grep, so the regression guard the AC requires does not exist. (The library itself is clean; this is a missing guard, not a live violation.)
```

### EDMV4-T38: Create bin/edm-repo-readiness following bin/ house conventions -- PASS

All 9 acceptance criteria verified.

- [x] **AC1** -- `plugins/edm/bin/edm-repo-readiness` exists at mode `-rwxr-xr-x`; `test -x`
      passes (`bin/tests/wave8-smoke.sh:507-511`). New row in the `bin/ helper scripts` table at
      `plugins/edm/CLAUDE.md:1116`, carrying the usage line and the 0/2 exit contract.
- [x] **AC2** -- `edm-repo-readiness:36` sources `_edm-cli-lib.sh` relative to `SCRIPT_DIR`;
      `:46-49` implements `usage()` as `print_help "${BASH_SOURCE[0]:-$0}"` against its own
      `# EDM-HELP-BEGIN` (`:8`) / `# EDM-HELP-END` (`:32`) sentinels. `grep "sed -n"` over the file
      returns nothing -- no hardcoded line range. `:2-7` explains why the file deliberately does
      not spell the banned form out literally (self-match avoidance).
- [x] **AC3** -- Executed directly: `edm-repo-readiness --help` exits 0 and prints the sentinel
      block verbatim, including the usage line `edm-repo-readiness [<PREFIX>] [--json <path>]`
      (`:19`). Also asserted at `bin/tests/wave8-smoke.sh:526-533`.
- [x] **AC4** -- `edm-repo-readiness:35` is byte-identical to `edm-lint-artifacts:74`,
      `edm-compare-eval:39` and `edm-state:61`: `SCRIPT_DIR="$(cd "$(dirname
      "${BASH_SOURCE[0]:-$0}")" && pwd)"`. Confirmed by direct four-way diff, not by the test's
      own claim. The `timing.sh:26` variant (no `:-$0` fallback) was correctly not copied.
- [x] **AC5** -- `edm-repo-readiness:40-44` carries `local msg="$1" code="${2:-2}"`, byte-matching
      `edm-compare-eval:44-48` and `evals/run-eval.sh:85-89` modulo the script-name prefix in the
      stderr line.
- [x] **AC6** -- Exit 0 on a scored repository regardless of score (`:134`, unconditional
      `exit 0`). Exit 2 on every setup/usage path via `die()`'s default: unknown flag (`:72-74`),
      `--json` with no path or an empty path (`:67-68`), an extra positional (`:76`), missing `jq`
      (`:55`). `bin/tests/wave8-smoke.sh:550-559` runs the script in a non-git scratch directory
      (the deliberately low-scoring fixture the AC requires), asserts exit 0 and
      `Overall score: 0`; `:561-575` asserts exit 2 for the unknown-flag and bare-`--json` cases.
- [x] **AC7** -- Human text goes to stdout only (`:112-122`); the sole JSON document is written to
      the `--json <path>` file (`:126-131`), built with `jq -n` + `--argjson`/`--arg`, never string
      concatenation. `bin/tests/wave8-smoke.sh:579` greps captured stdout for `{` and finds none;
      `:580-584` confirms no `--json-to-stdout` case arm exists. The `jq -r` at `:120` emits raw
      text lines, not a JSON document.
- [x] **AC8** -- `set -euo pipefail` at `edm-repo-readiness:33`. No deviation, so the
      CA-074 documented-exception path does not apply.
- [x] **AC9** -- `grep -nE 'declare -A|readarray|mapfile'` and `grep '\^\^'` over the file both
      return nothing (`bin/tests/wave8-smoke.sh:598-604`); `/bin/bash -n` (bash 3.2.57) passes
      (`:605-609`). Required binaries stay `bash`, `jq` (guarded at `:55`) and `git` (`:93`).

**Ticket-specific gotcha, checked and clear**: `edm-repo-readiness` never invokes `edm-state` at
all -- the only occurrences of the string are in comments at `:15` and `:85` deferring the wiring
to `EDMV4-T40`. The `set -euo pipefail` abort-on-informational-anomaly hazard (`out="$(edm-state
validate "$p")" || rc=$?`, flagged in `EDMV4-T40`'s Technical Notes at
`tickets/epics/05-classifier-and-scorecard.md:648-651`) therefore cannot arise in this ticket, and
nothing here sources `edm-state`.

**Findings**: none.

### EDMV4-T42: Define the JSON hookify rule format and its rule directory -- FAIL

7 of 10 ACs verified. Three fail: one on the AC's own literal grep (self-matching label), one on
the never-gitignored clause, and one on a false statement in the fixture set's shipped README.

- [ ] **AC1** -- **FAIL (literal grep clause only)**. Substance is met: the format is JSON read
      with `jq` only (`CLAUDE.md:826-832`), no YAML parser exists anywhere in `bin/`, and the
      required binary set stays `bash`/`jq`/`git`. But the AC states a literal check, and it now
      returns a hit: `git grep -n 'yaml\|yml' plugins/edm/bin/` matches
      `plugins/edm/bin/tests/wave8-smoke.sh:698`, the AC1 assertion's own label string
      (`check_absent "AC1 -- fixture filenames name no yaml/yml" "yaml"`). This is the identical
      self-matching class the same file guards against at `:807-809` ("an unanchored pattern
      matched it, the same self-matching class that defeated EDMV4-T21 AC7 and EDMV4-T04's
      sweep"). Anyone re-running AC1's stated command from now on gets a false positive.
- [x] **AC2** -- `CLAUDE.md:853-873` defines the schema table with exactly the six top-level keys
      and their types: `name` (string), `enabled` (boolean), `event` (`file`|`stop`|`bash`),
      `action` (optional, `warn`|`block`), `conditions` (array), `message` (string). The `action`
      default is stated twice -- as a table cell at `:864` and as a load-bearing format property
      at `:868-873` ("a property of the format, not of any evaluator"). The unknown-top-level-key
      setup error naming the rule file and the offending key is at `:855-857`.
- [x] **AC3** -- Condition shape (`field`, `operator`, `pattern`) at `CLAUDE.md:875-881`. AND
      semantics are stated in one explicit sentence, in bold, at `:883`: "**All conditions in a
      rule's `conditions` array must match for the rule to fire (AND semantics).**" -- stated
      rather than left to be inferred, and reinforced against the worked example at `:955-957`.
      `warn-no-console-log.json` carries the two conditions the sentence describes.
- [x] **AC4** -- Exactly six operators, enumerated in the table at `CLAUDE.md:887-897`
      (`regex_match`, `contains`, `not_contains`, `equals`, `starts_with`, `ends_with`). `:887-889`
      states that any other operator string is a setup error whose stderr line names both the rule
      file path and the offending operator. `bin/tests/wave8-smoke.sh:750-753` asserts the count is
      6 and that `malformed-unknown-operator.json` resolves to `bad-operator:matches`.
- [x] **AC5** -- Per-event field constraint at `CLAUDE.md:905-921`: `file` ->
      `file_path`/`new_text`/`old_text`/`content`, `bash` -> `command`, `stop` -> none (`:912`).
      The out-of-event field is a setup error naming the rule, the event and the field
      (`:905-907`). The `stop` event's empty field set is stated explicitly *and* its consequence
      spelled out at `:918-921` (a `stop` rule's `conditions` must be empty).
      `bin/tests/wave8-smoke.sh:756-759` asserts `malformed-out-of-event-field.json` resolves to
      `bad-field:command`.
- [ ] **AC6** -- **FAIL (never-gitignored clause only)**. The discovery half is complete:
      `CLAUDE.md:836-843` fixes the path at `.claude/edm-hookify/*.json` relative to the project
      root and reproduces the CA-448 three-step resolution verbatim (`CLAUDE_PROJECT_DIR` when it
      names a real directory, else `git rev-parse --show-toplevel`, else `.`), naming
      `check_permission_rules()` as the precedent. The failing clause is "the directory is
      **source-controlled**, never gitignored": in this repository it is gitignored.
      `git check-ignore -v .claude/edm-hookify/x.json` returns exit 0 with
      `.gitignore:1:.claude/` -- the root `.gitignore` blanket-ignores `.claude/`, so the first
      rule file committed here is silently dropped, defeating the "source control IS the feature"
      rationale the section rests on (`CLAUDE.md:845-852`).
- [x] **AC7** -- Documented once. `grep -rn '^## Hookify rule format' plugins/edm/` returns
      exactly one hit, `CLAUDE.md:818`; the section is correctly **not** mirrored into
      `docs/canonical-sections.md` (0 hits there). Verb-first naming convention at `:922-935`,
      with `warn-*.json`, `block-*.json` and `require-*.json` each defined and the "documentation
      for humans only, no evaluator reads the filename" rule stated at `:932-935`. Worked example
      rule file at `:937-957`.
- [x] **AC8** -- Three failure modes at `CLAUDE.md:959-978`, each with one concrete example:
      patterns too broad (`:964-966`, bare `log` matching "login" and "dialog"), patterns too
      specific (`:967-971`, `console\.log\(['"]debug['"]\)` breaking on a reformat), and
      shell/JSON escaping traps (`:972-978`, `"pattern": "rm\\s+-rf"` versus a pasted
      shell-escaped `rm\ -rf`). All three are the modes the AC names.
- [x] **AC9** -- The setup-error contract is documented at `CLAUDE.md:980-990`: path named on
      stderr, that file alone skipped, every other valid rule still loaded, never blocking, and
      the consumer exits non-zero -- explicitly cross-referenced to the two-tier
      `edm-lint-staged-artifacts` precedent. All four malformed shapes are fixtured, and
      `bin/tests/wave8-smoke.sh:644-695` discriminates each to its own distinct named reason
      (`invalid-json`, `missing-key:message`, `bad-operator:matches`, `bad-field:command`).
      *Scope note (NOTED, not a defect)*: the AC's "the evaluator exits 1" clause names behavior
      this ticket's own Out of Scope assigns to `EDMV4-T43`/`T44`
      (`tickets/epics/06-hooks-and-codemaps.md:118-120`). The documentation says "exits non-zero"
      rather than pinning `1`, which is the correct call for a format-only ticket -- pinning `1`
      here would pre-empt `EDMV4-T44`'s exit-code contract.
- [ ] **AC10** -- **FAIL**. The fixture inventory itself is correct and complete: four valid rules
      covering all three events (`warn-no-console-log.json` and `require-ticket-id-reference.json`
      = `file`, `block-rm-rf-bash.json` = `bash`, `warn-stop-placeholder.json` = `stop`) and one
      instance of each of AC9's four malformed shapes. The defect is in the set's own shipped
      documentation: `bin/tests/fixtures/hookify/README.md:12-14` states that the implicit-`action`
      default "is demonstrated by omitting the key entirely in a malformed fixture below". **No
      fixture in the directory omits `action`** -- all seven parseable files carry it explicitly,
      and the eighth (`malformed-invalid-json.json`) is deliberately unparseable. The README names
      `EDMV4-T43` as the expected downstream consumer of this directory (`README.md:47-49`), so a
      T43 implementer who trusts this sentence will write a test for the format's `action` default
      against inputs that cannot exercise it.

**Scope guards, all verified clean** (these were the constraints most at risk of over-build):

| Constraint | Result |
|---|---|
| `bin/edm-hookify` must NOT exist (evaluator is `EDMV4-T43`'s) | Absent -- `ls` confirms; asserted at `wave8-smoke.sh:702-706` |
| No `list`/`eval` subcommand, no exit-code contract, no hook registration | None present anywhere |
| No YAML support, converter, or ECC importer | None; no YAML parser in `bin/` |
| No default rule files shipped; `.claude/edm-hookify/` is project-owned | Directory absent from the repo; fixtures live under `bin/tests/fixtures/hookify/` only |
| `run-all.sh` `_PREFERRED_ORDER` / `_MIN_SUITE_COUNT` untouched (`EDMV4-T53`'s) | `grep wave8 run-all.sh` returns nothing; `_MIN_SUITE_COUNT` still 7, `_PREFERRED_ORDER` still seven suites. **All three tickets correctly abstained.** |
| `_edm-datadir-lib.sh` non-executable (sourced-only, `_edm-cli-lib.sh` precedent) | Mode `-rw-r--r--`. Correct, not a defect. |
| Initiative artifact lint | `edm-lint-artifacts EDMV4` -> CLEAN |

**Findings**:
```
[P2] EDMV4-T42 | plugins/edm/bin/tests/wave8-smoke.sh:698 | AC#1: git grep -n 'yaml\|yml' plugins/edm/bin/ returns no new hit from this ticket | The ticket introduced exactly one new hit -- its own assertion label, check_absent "AC1 -- fixture filenames name no yaml/yml" "yaml". Substance (no YAML parser, no new binary) is intact; the AC's stated mechanical check now returns a permanent false positive. Same self-matching class this file guards against at :807-809.
[P2] EDMV4-T42 | .gitignore:1 | AC#6: the directory is source-controlled, never gitignored | The root .gitignore blanket-ignores .claude/, so git check-ignore -v .claude/edm-hookify/x.json exits 0 (.gitignore:1:.claude/). The documented "source control IS the feature" contract (CLAUDE.md:845-852) is unenforced and contradicted in the repository that ships the format. No rule file exists yet, so there is no live data loss.
[P1] EDMV4-T42 | plugins/edm/bin/tests/fixtures/hookify/README.md:12-14 | AC#10: A fixture rule set ... so EDMV4-T43's smoke tests have inputs that do not have to be built inline | Factual error: the README states the implicit-action default "is demonstrated by omitting the key entirely in a malformed fixture below". No fixture omits action -- all 7 parseable fixtures carry it explicitly. The README names EDMV4-T43 as the consumer of this directory (README.md:47-49), so the false claim propagates.
```

## Remediation Required

Ordered by severity, then by cost to fix.

1. **[P1] EDMV4-T42 -- `bin/tests/fixtures/hookify/README.md:12-14`.** Two clean options; the
   first is preferable because it also closes the unfixtured-default gap for `EDMV4-T43`:
   - Add a fifth valid fixture (e.g. `warn-action-default.json`) that omits `action` entirely,
     and leave the README sentence as written; or
   - Delete the parenthetical "(implicit-default form is demonstrated by omitting the key entirely
     in a malformed fixture below, but ...)" and state plainly that every fixture in this set
     carries an explicit `action`, with the implicit default documented at `CLAUDE.md:864/:868`
     rather than fixtured.

2. **[P1] EDMV4-T17 AC6 -- `bin/tests/wave8-smoke.sh:451-452`.** Add the fourth construct's grep
   beside the existing two. The CA-472 class is process substitution feeding a loop, so the
   pattern to add is a `< <(` / `done <\s*<(` search over `_edm-datadir-lib.sh`, failing on any
   hit. One added `grep -n` and one added condition in the existing `if`.

3. **[P1] EDMV4-T17 AC5 -- `bin/tests/wave8-smoke.sh:437-448`.** Replace the `mkdir`/`echo`/`ls`
   block with one that actually exercises the library: source `_edm-datadir-lib.sh` with
   `CLAUDE_PLUGIN_DATA` pointed at a scratch root, call `edm_marker_path()`, and assert the result
   sits under `${data}/run/` and **not** under `${data}/patterns/` -- then assert the converse for
   the `patterns/` sibling path. If the library is genuinely meant to expose no `patterns/` accessor
   (its `_edm-datadir-lib.sh:37-38` header says creation is `EDMV4-08`/`EDMV4-T18`'s job), say so in
   the test's own comment so the reduced assertion is a recorded decision rather than an accident.

4. **[P2] EDMV4-T42 AC1 -- `bin/tests/wave8-smoke.sh:698`.** Reword the assertion label so it does
   not contain the literal tokens its own AC greps for (e.g. "fixture filenames name no
   YAML-family extension"), or anchor AC1's stated command to exclude assertion labels. Either
   restores the AC's grep to a meaningful zero.

5. **[P2] EDMV4-T42 AC6 -- `.gitignore:1`.** Add a negation so the project-owned rule directory can
   actually be committed in this repository, e.g. `!.claude/edm-hookify/` and
   `!.claude/edm-hookify/*.json` after the blanket `.claude/` line. If the human judges that this
   marketplace repository is not a consuming project and the convention binds only downstream
   projects, this is correctly closed as NOTED at the gate rather than fixed -- but it should be an
   explicit decision, not silence, because `CLAUDE.md:845-852` asserts the property unconditionally.

No PARTIAL verdicts were recorded in this shard, so nothing here is deferred to
`/edm:verify-runtime`.

<!-- QC-SHARD-COMPLETE range=EDMV4-T17..EDMV4-T42 assigned=3 audited=3 -->
