# Lens L1: Logic, Correctness & Completeness -- EDMV3 Code Audit Round 1 (full)

**Date**: 2026-07-28 | **Round**: pass-1, full | **Branch**: `edm/edmv3-prompt-streamline`

| ID | Sev | Site | Defect |
|---|---|---|---|
| L1-01 | P1 | `bin/edm-lint-artifacts:363` | class 2 PCRE branch reads three fields from a two-field `grep -n` |
| L1-02 | P1 | `.gitlab-ci.yml:275-284` | `test:smoke-bash32` uses `apt-get` on an Alpine-based image |
| L1-03 | P2 | `bin/edm-lint-artifacts:435,436,471` | three `die` messages lost their variable interpolation |
| L1-04 | P2 | `bin/edm-check-grants:66-69` | `usage()` hardcoded `sed` range truncates the exit-code contract |
| L1-05 | P2 | `.gitlab-ci.yml:528-538, 327-336, 474-480` | `cmd; rc=$?` is not `set -e`-safe, so the handling branches are unreachable |
| L1-06 | P2 | `bin/edm-state:2870` | `audit-round-start --lenses ,` aborts silently under `pipefail` |
| L1-07 | P2 | `bin/edm-state:3180` | `record-partial-verdict close` always reports "(was PARTIAL)", reading an always-empty variable |
| L1-08 | P2 | `bin/edm-state:374-376` | `compute_cost_usd` binds `or` as an awk variable, which gawk reserves |

---

## L1-01 (P1) -- class 2's PCRE branch mis-parses `grep -n`, disabling ignore suppression

`bin/edm-lint-artifacts:361-367`:

```bash
      local ignore_set lineno _rest snippet          # _f is NOT declared here
      while IFS=: read -r _f lineno _rest; do        # reads THREE fields
        is_ignored_line "$lineno" "$ignore_set" && continue
        snippet="$(sed -n "${lineno}p" "$file" 2>/dev/null | cut -c1-120 || true)"
        report_violation "unicode" "$file" "$lineno" "$snippet"
      done < <(grep -nP '[^\x00-\x7F]' "$file" 2>/dev/null || true)
```

`grep -n` on a **single** file emits `LINENO:content` -- two fields, no filename prefix (`-H` is not passed). So `_f` gets the line number, `lineno` gets the leading chunk of file content, `_rest` the remainder.

Three consequences:
1. `is_ignored_line "$lineno" "$ignore_set"` compares *line text* against a set of *line numbers* and can never match. **The documented code-fence and `edm-lint-ignore` suppression is entirely inoperative for the unicode class**, contradicting the `--help` promise. Non-ASCII inside a fenced example becomes a false positive.
2. `sed -n "${lineno}p"` receives text, errors into `/dev/null`, so `snippet` is always empty.
3. The emitted record violates the documented `path:line: <class>: <snippet>` contract -- the "line" field holds prose.

Provably an editing slip: the three sibling readers are all two-field and correct -- class 1 at `:349`, the non-PCRE class-2 fallback at `:375`, class 3 at `:392`, and `edm-check-grants:464`. `_f` is also absent from the `local` declaration.

**This is the branch taken on GNU grep, i.e. the alpine CI image where `lint:artifacts` is blocking.** On macOS (BSD grep, no `-P`) the correct fallback runs, so local runs never surface it. The `check_absent "T43 AC9 -- no unicode violation on the live tree"` assertion at `wave7-smoke.sh:1812` passes only because the tree has no non-ASCII outside fences; it cannot detect a mis-parsed line number.

**Fix**: `while IFS=: read -r lineno _rest; do` (drop `_f` entirely). Add a fixture with a non-ASCII character inside a fence and assert `--path` reports zero violations under both branches.

## L1-02 (P1) -- the bash-3.2 job's `before_script` cannot succeed

`.gitlab-ci.yml:275-284` runs `apt-get update && apt-get install -y jq git` against `image: "bash:3.2"`. The official Docker Hub `bash` image is built `FROM alpine` -- it ships `apk`, not `apt-get`. `before_script` fails, the job errors before `script:`, and the bash-3.2 leg of the suite never executes. Every other job in the file correctly uses `apk add --no-cache`.

This is the single job discharging the T61 AC10 commitment ("only actually running the suite under bash 3.2 proves the constraint holds end-to-end"). As written that commitment is unfulfilled: the constraint is checked only by the static construct grep, which the comment itself calls insufficient.

**Fix**: `- apk add --no-cache jq git` (bash is the image payload). If no runner is available to validate, the job should carry `allow_failure: true` with a comment rather than a command that cannot work.

## L1-03 (P2) -- three `die` messages lost their interpolation

`bin/edm-lint-artifacts:435,436,471`:

```bash
      || die "no initiative for prefix  (run: edm-state init )" 2
      [[ -d "$INIT_DIR" ]] || die "initiative directory not found: " 2
        die "--path target not found: " 2
```

Note the double space where `$PREFIX` was and the dangling `: `. The most common failure modes of this tool -- a typo'd prefix, a bad `--path` -- now produce a message that does not say what was not found, which is exactly the diagnostic the exit-2-vs-exit-1 split exists to make actionable. Line 435 also instructs `edm-state init` with no argument, which `cmd_init` refuses.

**Fix**: restore `${PREFIX}`, `${INIT_DIR}`, `${PATH_ARG}`.

## L1-04 (P2) -- `edm-check-grants --help` truncates its own contract

`bin/edm-check-grants:66-69` is `usage() { sed -n '2,45p' "$0"; exit 0; }`. The header block runs to line 57, so `--help` silently cuts the Output format paragraph (`:46-49`), the Exit codes contract (`:51-52`) and the bash-3.2 note (`:54-57`).

This is the identical defect `bin/edm-state:2-8` and `bin/edm-lint-artifacts:2-5` describe and fix with sentinels; the fix landed in five siblings and missed here. `wave7-smoke.sh:208-213` asserts against that exit contract while `--help` hides it.

**Fix**: wrap `:2-57` in `# EDM-HELP-BEGIN`/`# EDM-HELP-END` and use the awk extractor its siblings use.

## L1-05 (P2) -- exit-code capture in CI script blocks is not `set -e`-safe

GitLab Runner emits `set -eo pipefail` at the top of every generated job script. Under an inherited `-e`, a non-zero exit aborts the block immediately, so `rc=$?` and every branch reading it never execute.

- `.gitlab-ci.yml:531-533` -- `bash edm-compare-eval ...` then `rc=$?` then `case`. `plugins/edm/evals/baseline/scores.json` is intentionally absent, so `edm-compare-eval` exits 3 on **every** run, making the `3) ... NOT ARMED` arm -- the entire point of reserving exit 3 -- dead code in its only consumer.
- `:327-328` -- `out="$(edm-state validate "$prefix" 2>&1)"` then `ec=$?`. A blocking anomaly (exit 3) aborts before `printf '%s\n' "$out"` and before the `BLOCKING anomaly in ${prefix}` line, so the job fails without naming the initiative or the anomaly code, contrary to the AC comment on line 300.
- `:474-475` -- same shape for `claude plugin validate`.

`set -u` on `:310` and `:468` does not clear an inherited `-e`.

**Fix**: use the `|| rc=$?` idiom already used correctly at `edm-state:1308`, `:2023`, `:3883` and `wave7-smoke.sh:3014`:
```bash
rc=0
bash plugins/edm/bin/edm-compare-eval "$RUN_DIR/scores.json" || rc=$?
```

## L1-06 (P2) -- a degenerate `--lenses` value aborts with no message

`bin/edm-state:2870` pipes `--lenses` through `tr`/`sed`/`grep -v '^$'`/`jq`. The guard at `:2855` only requires the argument to be non-empty, so `--lenses ,` (or `,,,`) passes it, then every line is blank, `grep -v '^$'` selects nothing and exits 1, `pipefail` propagates, and `set -e` terminates the script -- **exit 1 with no message**, in a command whose contract is `N=$(edm-state audit-round-start <PREFIX> code)`. The caller gets an empty round number and no diagnostic.

**Fix**: normalise first, then `die` explicitly if the result is empty.

## L1-07 (P2) -- a closure message asserts a prior state it never read

`bin/edm-state:3180` prints `(was ${already_closing_verdict:-PARTIAL})`. Line 3180 is reachable only when `already_closed == "false"`, i.e. `.closing_verdict` is absent, so `already_closing_verdict` is *always* empty there and the `:-PARTIAL` default *always* fires. But the open path accepts `PASS|PARTIAL|FAIL`, so an entry recorded `PASS` or `FAIL` and then closed is reported as "(was PARTIAL)". It reads the wrong field -- the open shape's verdict lives in `.verdict`.

**Fix**: read `.verdict` into `prior_verdict` and interpolate that.

## L1-08 (P2) -- `compute_cost_usd` binds a gawk built-in name as a variable

`bin/edm-state:374-376` passes `-v or="$out_rate"`. `or` is one of gawk's bit-manipulation built-ins (`and`, `or`, `xor`, `compl`, `lshift`, `rshift`), and gawk refuses to bind a built-in function name as a variable -- `-v or=...` is a fatal error, not a warning. On any host where `awk` is gawk (Fedora/RHEL and many Linux distributions), every `phase-complete` and `audit-round-complete` fails at the cost computation rather than degrading.

bwk awk (macOS), mawk (Debian/Ubuntu) and busybox awk (the alpine CI image) do not reserve `or`, which is why neither the dev environment nor CI surfaces it. This function is in scope for this initiative (its rate arms were rewritten this wave), and the file already takes explicit care over awk-dialect portability elsewhere, so this is an inconsistency in a managed constraint rather than an accepted trade-off.

**Fix**: rename to `orr` (one line, two occurrences).

---

## Noted / Not Actionable

- `bin/edm-state:3407-3412` -- `pattern_target_heading_for()` ignores `$1` and always returns `## Anti-Patterns`. Documented at `:3373-3380` as the intentional extension point, contractually coupled to adding a README mapping row.
- `bin/edm-lint-artifacts:136-137` -- the comment says the block-form escape valve works because "class 4 skips any line that is ignored"; class 4 actually filters on `MARKER_SETS`, not `IGNORE_SETS` (`:425`), and must, since every mermaid line is also in the ignored set. Code correct, comment misstates why. Prose defect.
- `bin/edm-lint-artifacts:184` -- an `edm-lint-ignore-end` occurring *inside* a fence still closes the ignore block and its line is emitted in no class. Requires a mermaid source line containing that literal HTML comment.
- `bin/edm-state:767-776` -- `schema_at_least`'s `[[ "$sv" -ge "$min" ]]` aborts on a non-integer `schema_version`. Reachable only via a hand-edited state file; `migrate-schema` is the single writer and coerces with `tonumber`, and `cmd_set` refuses the field.
- `bin/tests/wave7-smoke.sh:358` -- `T15_STEP10="$(sed -n '69,106p' ...)"`. Currently correct, but the same hardcoded-line-range brittleness T61 abolished for help blocks, applied to a prose file that will shift.
- `bin/tests/run-all.sh:2,50` -- literal U+2014 em dashes, one in runtime console output. Convention violation, not a logic defect.
- `bin/edm-check-grants:227-241` -- `has_tool()` runs `set -- $list` unquoted with `IFS=','`, so each item is subject to pathname expansion. Safe for every value on disk (`Bash(git *)` matches no file, `nullglob` off), and `$1`/`$2` are read into locals before the positionals are clobbered.
- `bin/edm-init:159` -- `git rev-parse --verify "$BRANCH"` is not qualified to `refs/heads/`, so a branch name that also resolves as a commit-ish takes the "exists" path. Pre-existing and unreachable for the names this script generates.

## Not examined

Read in full: `bin/edm-state`, `bin/edm-lint-artifacts`, `bin/edm-check-grants`, `bin/edm-check-vocabulary`, `bin/edm-compare-eval`, `bin/edm-check-skill-sync`, `bin/edm-sync-canonical-sections`, `bin/edm-init`, `bin/edm-validate-prefix`, `bin/tests/_harness.sh`, `bin/tests/run-all.sh`, `.gitlab-ci.yml`, `bin/vocabulary-prohibited.txt`.

Not read (targeted greps only): `bin/tests/wave7-smoke.sh:735-3462`, the other five smoke suites, `bin/tests/timing.sh`, `evals/run-eval.sh`, `evals/score-artifacts.sh`, `evals/tiering-matrix.sh`, `hooks/hooks.json`, `bin/vocabulary-allowlist.txt`, and the test fixtures. **`hooks/hooks.json` was in scope and is unexamined.**
