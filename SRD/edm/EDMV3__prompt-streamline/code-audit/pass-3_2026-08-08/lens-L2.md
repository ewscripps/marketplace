# Code Audit Lens L2 -- Dead Code & Unreachable Paths

- **Lens**: L2 (Dead Code, Unreachable Paths, Environmentally-Eliminated Branches)
- **Date**: 2026-08-08 | **Round**: pass-3 (full, all 11 lenses) | **Branch**: `edm/edmv3-prompt-streamline`
- **Scope read this round**: `bin/edm-state` (4,607 lines, in full), `bin/_edm-cli-lib.sh` (new), `bin/_edm-lint-lib.sh`, `bin/edm-lint-artifacts`, `bin/edm-check-grants`, `bin/edm-check-vocabulary`, `bin/edm-init`, `bin/edm-validate-prefix`, `bin/edm-compare-eval`, `bin/edm-check-skill-sync`, `bin/edm-sync-canonical-sections`, `bin/tests/run-all.sh`, `bin/tests/_harness.sh`, targeted sweeps of `bin/tests/wave*-smoke.sh`, `evals/run-eval.sh`, `evals/score-artifacts.sh`, `evals/tiering-matrix.sh`, `hooks/hooks.json`, repository-root `.gitlab-ci.yml` and `.gitignore`.

## Headline

**All six L2-tagged `open` ledger entries are now genuinely fixed.** CA-005, CA-007, CA-137, CA-138, CA-139 and CA-140 each verify clean at their cited sites with fresh evidence, and CA-007's residual L1/L3 half (the porcelain-rename mis-parse) is now closed too. No prior L2 finding has regressed.

The fresh pass produced **seven new P2 findings**. Six of the seven are residue introduced by the round-2 remediation itself: three dead symbols in shared libraries created by the CA-049 and CA-156 fixes, a guard the CA-016 fix made unreachable, and -- the most consequential -- an entire three-function cleanup subsystem added by the CA-142/CA-143 fix that **cannot execute in the one case it exists for**, because the CA-025 fix in the same function forks the only writer into a subshell. No P0, no P1.

| ID | Severity | Site | Defect |
|---|---|---|---|
| L2-001 | P2 | `bin/edm-state:535` (subsystem `:513-537`, `:555-557`) | nested-`write_atomic` cleanup drain is unreachable; CA-142 substantively unfixed |
| L2-002 | P2 | `bin/tests/_harness.sh:60`, `:43`, `:44` | CA-049's shared-preamble vehicle has zero callers/readers |
| L2-003 | P2 | `bin/_edm-lint-lib.sh:172`, `:177` | `mermaid_line_set` / `marker_line_set` have zero call sites |
| L2-004 | P2 | `bin/tests/run-all.sh:72` | `_MIN_SUITE_COUNT` floor subsumed by the check directly above it |
| L2-005 | P2 | `bin/edm-check-grants:103` | "unexpected extra argument" die is structurally unreachable |
| L2-006 | P2 | `bin/edm-check-vocabulary:191` | "no files found in scan scope" is structurally unreachable |
| L2-007 | P2 | `.gitlab-ci.yml:245` | `${evals_kb:-0}` default on a value that cannot be empty |

`BLOCKING_FILTER` (`bin/edm-state:1150`) includes P2, so all seven are in the blocking set. All seven are one-to-five-line edits; none needs a design decision.

---

## Part 1 -- Verification of L2-tagged open ledger entries

### CA-005 (P2, L1+L2+L6+L7+L10) -- FIXED, and the L7/L10 half landed too

The L2 half (unreachable help content) and the previously-missing shared extractor are both closed. `bin/_edm-cli-lib.sh` now exists as the single definition of `print_help` (`:28-30`), sourced by all nine `bin/` helpers and all three `evals/` drivers. The round-2 residue I flagged -- `edm-sync-canonical-sections` keying its extractor on the literal `set -euo pipefail` line with no sentinels -- is gone: `edm-sync-canonical-sections:2`/`:35` now carry `EDM-HELP-BEGIN`/`EDM-HELP-END` and `:53` calls the shared `print_help`, with the rationale in place at `:36-38`. The prescribed CI ban also landed: `.gitlab-ci.yml:112-118` fails on any second occurrence of the extractor literal and `:119-125` fails on the hardcoded `sed -n 'A,Bp' "$0"` form.

### CA-007 (P1, L1+L2+L11) -- FIXED, including the residual half

The L2 half (unreachable CI status branches) was closed in round 2 and has not regressed. The residue I explicitly flagged so the synthesizer would not close CA-007 whole -- `run-eval.sh` slicing `path="${line:3}"` and scoring a rename whose destination escapes `SRD/` as contained -- is now fixed at `evals/run-eval.sh:465-471`:

```bash
  xy="${line%%"${line#??}"}"
  path="${line:3}"
  case "$xy" in
    R*|C*) path="${path##* -> }" ;;  # porcelain rename/copy: the destination is what matters
  esac
```

Traced by hand against `R  SRD/x -> outside/y`: `xy` resolves to `R `, `path` to `outside/y`, which fails the `SRD/*` case at `:473` and is accumulated as a violation. The one check that would catch the eval driver mutating the host tree now works in both directions.

### CA-137 (P2, L2) -- FIXED

`state_anomalies` (`bin/edm-state:1169-1332`) no longer declares or assigns `found`; it ends at an unconditional `return 0` (`:1331`) with the header comment at `:1161` describing exactly that. A whole-file grep for `local found=` now returns two sites only -- `cmd_list:1586` (read at `:1608`) and `cmd_active_initiatives:2880` (read at `:2892`) -- both genuinely consumed, which is precisely the distinction round 2 asked the remediation to preserve. Twelve dead stores removed, no accumulator wired up as a competing source of truth against `cmd_validate`'s class parse.

### CA-138 (P2, L2) -- FIXED

`evals/tiering-matrix.sh:242-247` is no longer a byte-identical copy of the branch-1 assertion. It is now a distinct Branch-3 assertion against `synthetic-agent-c-no-qualifier` (a fixture the manifest at `:192-211` supplies), with its own PASS echo at `:243`. The count is now honest: exactly six assertion sites (`:223`, `:233`, `:242`, `:287`, `:293`, `:301`) and exactly six `failures` increments (`:227`, `:237`, `:246`, `:291`, `:297`, `:305`), so the `6/6` denominator at `:310` and `:313` matches. D28's quoted evidence is no longer skewed.

### CA-139 (P2, L2) -- FIXED

`evals/score-artifacts.sh:169-173` now clamps and then rounds unconditionally, with the reason recorded in place:

```bash
      if (v > 100) v = 100
      # CA-139: v is clamped to >= 0 immediately above with no intervening assignment, so a
      # negative branch here is structurally unreachable -- round half-up unconditionally.
      r = int(v + 0.5)
```

`round_int` (`:156-158`) is untouched, as round 2 asked -- it is a separate helper with a genuinely reachable negative branch.

### CA-140 (P2, L2) -- FIXED

`bin/edm-state:1105-1109`: the `-z "$sv"` disjunct is gone and the reason is recorded where the next reader will find it.

```bash
  sv="$(to_int "$sv" 0)"
  # CA-140: `-z` was dead -- to_int with a default never returns empty ...
  if [[ "$sv" -eq 0 ]]; then
```

The three-valued comment block at `:1095-1104` is preserved verbatim, as asked.

### Previously-fixed L2 entries -- no regressions

CA-006 (`.gitlab-ci.yml:359-366`: `apk add`, plus the live `grep -q 'version 3\.2'` assertion at `:365`), CA-008 (`bin/edm-lint-artifacts:325`, `:339`, `:352`, `:370` -- all four class readers now the identical two-field `IFS=: read -r lineno _rest`), CA-012 (`plugins/edm/CLAUDE.md` "How `compute_cost_usd` picks a rate row after D32" matches `bin/edm-state:392-451` arm for arm, and CA-152's arm-order claim is now corrected in the same passage), CA-044 (`bin/edm-lint-artifacts:427`, `:428`, `:463` -- all three interpolations present), CA-047 (`bin/edm-state:3598` reads `.verdict // .prior.verdict // "PARTIAL"`; `:3665` interpolates it), CA-053, CA-054 (`bin/edm-state:4463`, single unconditional `- **Mode**: ${mode}` line).

---

## Part 2 -- New findings

### L2-001 (P2, high) -- the nested-`write_atomic` cleanup subsystem cannot run in the only case it exists for

`plugins/edm/bin/edm-state:535` (subsystem: `:512-537`, consumer branch `:555-557`, trap install `:1025-1028`, fork `:1044-1045`).

Three functions and a nine-line rationale comment were added by the CA-142/CA-143 remediation so that a `write_atomic` call nested inside `with_state_lock`'s mkdir branch registers its temp file on a shared list which the lock's already-installed trap drains. The chain is provably inert. Following it from the code alone, with no appeal to bash version nuances:

1. `_EDM_CLEANUP_PATHS` is declared at `:513` in the top-level shell.
2. The only writer is `_edm_cleanup_push` (`:515-517`), called from exactly one site: `write_atomic:557`, inside `if [[ "${_EDM_TRAP_DEPTH:-0}" -ge 1 ]]` (`:555`).
3. `_EDM_TRAP_DEPTH` is set to `1` at exactly one site, `with_state_lock:1044` -- immediately before `( "$@" )` at `:1045` -- and reset to `0` at `:1047` immediately after. Nothing else runs between the two.
4. Therefore every `write_atomic` call that takes the nested branch necessarily executes **inside that subshell**, and its `_EDM_CLEANUP_PATHS` append is discarded when the subshell exits.
5. The only reader is `_edm_cleanup_paths_run` (`:532-537`), invoked only from the four trap bodies at `:1025-1028`, which are installed in and fire in the **parent** shell.

So the list the trap drains is always empty and the loop body `rm -f "$p" 2>/dev/null || true` at `:535` is unreachable. `_edm_cleanup_pop` (`:522-528`) is dead for the same reason.

This is not merely tidy-up. The nested branch deliberately installs **no** trap of its own (the `else` at `:558-578` is the only trap-installing path), so during a locked read-modify-write on a host without `flock` -- macOS, this codebase's stated bash 3.2 target and primary development platform -- an INT/TERM/HUP leaves `<dest>.tmp.XXXXXX` on disk with nothing anywhere able to remove it. All four locked bodies reach this branch: `_rmw_state_body` (`:639`), `_cmd_init_body` (`:1526`), `_cmd_update_patterns_body` (`:4037`), `_write_handoff_body` (`:4539`).

The comment at `:508-511` states the opposite of the behaviour: "the ALREADY-installed outer trap drains this list before it removes the lockdir, so both cleanups happen under the one active trap layer."

**Severity note**: held at P2 rather than P1 because every leaked temp name is matched by `.gitignore` (`:10` `.edm-state.json.tmp.*`, `:20` `**/*.md.tmp.*`, `:13` `plugins/edm/docs/audit-patterns/*.tmp.*`), so the runtime consequence is bounded to ignored disk residue and never reaches `git status`. The dead-code weight is the ~25 inert lines plus a comment asserting the opposite.

**Fix**: either (a) push the temp path onto a file-backed list rather than a shell array, so the registration survives the fork, or (b) drop the nested special case and let `write_atomic` install its own traps inside the subshell -- a subshell's own trap installation is effective within that subshell, and it cannot disarm the parent's trap, so the CA-142 concern about "re-disarming the outer cleanup" does not arise across a `( )` boundary. **Do not close CA-142 on the strength of the current code**; the mechanism it prescribed is present but inoperative.

### L2-002 (P2, high) -- CA-049's shared-preamble vehicle has no callers, and the suites it was written for still hand-roll the bad preamble

`plugins/edm/bin/tests/_harness.sh:60-66` (`harness_scratch_dir`), `:43` (`_HARNESS_PLUGIN_DIR`), `:44` (`_HARNESS_REPO_ROOT`).

- `harness_scratch_dir` -- a 7-line function under a 21-line docstring -- has **zero call sites** anywhere in `plugins/edm/`. It is not even self-tested in `harness-smoke.sh`.
- `_HARNESS_PLUGIN_DIR` is read at exactly one place, `:44`, to compute `_HARNESS_REPO_ROOT`, which is then **never read at all**. Both are dead, and computing them costs two `cd`+`pwd` subshells on every suite start.
- By contrast `_HARNESS_BIN_DIR` (`:40`) is genuinely live (`:104`, `wave6-smoke.sh:416`).

The docstrings assert the opposite of the shipped state. `:49-51`: "three older suites hand-rolled a byte-identical bare `mktemp -d` + `trap ... EXIT` preamble that did neither of those two things ... this gives every suite, old and new, the same corrected preamble in one place." `:41-42`: "shared plugin-root and repo-root exports so individual suites stop re-deriving the same value inline (five suites previously recomputed this)."

Verified against the suites: `bin/tests/wave3-smoke.sh:15-16` and `bin/tests/wave4a-smoke.sh:15-16` still read exactly

```bash
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
```

-- no `TMPDIR` honoring, EXIT-only trap, no INT/TERM -- the precise shape `harness_scratch_dir` was added to eliminate.

**Fix**: either migrate `wave3-smoke.sh` and `wave4a-smoke.sh` to `harness_scratch_dir` (which closes CA-049's substance and makes the function live), or delete all three symbols and correct the two docstrings. Do not leave the current state, where the library claims a migration that did not happen. **Do not close CA-049 on the presence of these symbols.**

### L2-003 (P2, high) -- two projection functions in the shared lint library have no call sites

`plugins/edm/bin/_edm-lint-lib.sh:172-175` (`mermaid_line_set`), `:177-180` (`marker_line_set`).

A whole-tree grep across `bin/`, `evals/`, `bin/tests/` and every prose surface returns call sites only for the third sibling, `ignored_line_set` (`edm-check-vocabulary:227`, `edm-check-grants:273`, `:295`, `edm-state:3938`, `:4001`). `mermaid_line_set` and `marker_line_set` are referenced nowhere but their own definitions and docstrings.

The library's own docstring (`:38-45`) says these exist "so all three consumers derive the `ignored`/`mermaid`/`marker` sets identically instead of each re-deriving the same projection locally (CA-156)". But the only consumer that needs the mermaid and marker sets -- `edm-lint-artifacts` -- **deliberately declines to use them**, and documents why at `edm-lint-artifacts:283-292`: routing through the three per-class functions would cost three extra per-file `awk` invocations against the documented 3,000 ms commit-path and 60,000 ms CI budgets, so it derives all four projections from one `build_line_classes` table at `:294-298`. The two facts contradict each other; neither is wrong on its own terms, and the result is two dead functions.

**Fix**: delete both, or keep them and replace the docstring claim with the real position -- that `ignored_line_set` is the shared projection and the mermaid/marker projections are deliberately not offered as separate passes because of the latency budget. Deleting is cleaner; a shared library with dead exports invites the next contributor to use the slow path.

### L2-004 (P2, high) -- the minimum-suite-count floor cannot fire behind the check immediately above it

`plugins/edm/bin/tests/run-all.sh:71-75`.

`_PREFERRED_ORDER` (`:23`) names exactly seven suites. The block at `:59-70` exits 1 if **any** of those seven names was not discovered. Only then does `:71-75` test `${#_run_order[@]} -lt 7`. Since reaching `:72` guarantees all seven preferred names are in `_run_order`, the length is always at least 7 and the message at `:73` -- "only N suite(s) discovered, expected at least 7" -- can never print.

The comment at `:54-58` advertises both protections as independent: "Assert every name `_PREFERRED_ORDER` expects was actually discovered, naming any that were not, **and** assert a minimum suite count so a silent shrink of the discovered set is never invisible." The second half is delivered entirely by the first. CA-016's stated regression (deleting or renaming `wave7-smoke.sh` drops ~830 assertions while the aggregate reports ALL SUITES PASSED) is genuinely caught -- by the name check alone.

Note for the filter: the floor would become reachable if `_PREFERRED_ORDER` ever shrank below seven names while `_MIN_SUITE_COUNT` stayed at 7 -- i.e. only through a mismatch between two hand-maintained constants. Reported rather than noted because the comment currently misdescribes what protects the suite set.

**Fix (cheapest correct)**: one comment line at `:71` stating the floor is a backstop for a `_PREFERRED_ORDER` that shrinks, and is unreachable while the two constants agree. Deleting `:71-75` is also acceptable.

### L2-005 (P2, high) -- `edm-check-grants`' "unexpected extra argument" die is structurally unreachable

`plugins/edm/bin/edm-check-grants:103`: `[[ $# -eq 0 ]] || die "unexpected extra argument: $1" 2`

Every path through the argument parser at `:88-102` leaves `$#` at 0:

- `$#` was already 0, so the `if` block is skipped;
- `--list-sources` requires `$# -eq 1` (else it dies at `:91`) and then `shift`s to 0;
- `--*` dies at `:96`;
- any positional dies at `:99`.

`$#` can therefore never be non-zero at `:103`, and the extra-argument case for `--list-sources` is already covered by its own, more specific message at `:91`. Confirming the line has never executed: under this file's `set -u`, `$1` at `:103` would itself be an unbound-variable error if it were ever reached.

Contrast `edm-lint-artifacts:105`, whose identically-worded die sits inside a real `while` loop over multiple arguments and is reachable -- so this is not a project-wide idiom.

**Fix**: delete `:103`.

### L2-006 (P2, high) -- `edm-check-vocabulary`'s "no files found in scan scope" is structurally unreachable

`plugins/edm/bin/edm-check-vocabulary:191-194`.

`SCOPE_ROOTS` (`:105-114`) includes two plain files, `${PLUGIN_ROOT}/CLAUDE.md` and `${PLUGIN_ROOT}/README.md`. The build loop at `:173-189` appends each `-f` root unconditionally (`:184-185`) and `die`s at `:187` on any root that is neither a directory nor a file. So on every path that reaches `:191`, `FILES` holds at least two entries, and `${#FILES[@]} -eq 0` cannot be true -- the informational message and its `exit 0` are dead.

**Fix**: delete `:191-194`. (Group with L2-005 -- same class, adjacent files, one commit.)

### L2-007 (P2, medium) -- dead defensive default on an arithmetic expansion

`.gitlab-ci.yml:244-245`:

```sh
      evals_kb="$(( (evals_bytes + 1023) / 1024 ))"
      evals_kb="${evals_kb:-0}"
```

Arithmetic expansion always produces a non-empty string (or, on a malformed operand, a hard shell error -- and this block runs under `set -e` from `:225`). `${evals_kb:-0}` can therefore never substitute. This is the exact class the ledger already accepts as a P2 at CA-140. Confidence medium only because the enclosing block runs under whatever `/bin/sh` the runner selects, and I cannot execute it here; on every POSIX shell, `$(( ))` yields a value or fails.

**Fix**: delete `:245`.

---

## Noted / Not Actionable

Carried dispositions, each re-verified at its current line numbers this round:

| ID | File:Line | Rationale |
|---|---|---|
| N-01 | `bin/edm-state:389-451` | **CA-105** holds: no pricing arm matches any live model; D32 records it, T52 AC9 leaves the figures unrepriced, verified rate rows are assigned to EDMV4. Not re-raised. |
| N-02 | `bin/edm-state:2687-2706` | **CA-107** holds: the Tiered-vs-Untiered section is gated on `.tiering_results`, which no producer writes; the in-code comment at `:2688-2693` says so and D28 records the matrix as deliberately not yet run. |
| N-03 | `bin/edm-state:3903-3908` | **CA-114** holds: `pattern_target_heading_for`'s single `*)` arm is the documented extension point, contractually coupled to a README mapping row. |
| N-04 | `bin/edm-check-grants:503-508` | **CA-116** holds: the `Edit` arm sets `_has_instruction=0` with no lookup, identical to the `else` branch's initial value. Documented as intentional at `:486-490`; advisory-only, never affects the exit code. |
| N-05 | `bin/edm-state:2258` | **CA-119** holds: `target_version=$((current_version + 1))` is a no-op today (max target 2), retained as defence against `schema_version: 3`, which CLAUDE.md records as deliberately unassigned. |
| N-06 | `evals/score-artifacts.sh:610-655` | **CA-120** holds: `cmd_compare` is a second comparison implementation CI does not use, retained with the reason stated at `:606-609` and reachable via the `--compare` dispatch arm at `:667-671`. |
| N-07 | `evals/tiering-matrix.sh:326` | **CA-121** holds: the `--*)` unknown-flag guard cannot see `-h`/`--help` because both exit earlier -- a deliberate two-stage parse. |
| N-08 | `bin/_edm-lint-lib.sh:136-139` | **CA-122** holds: an `edm-lint-ignore-end` occurring inside a fence still closes the ignore block and its line is emitted in no class; requires a mermaid source line containing that literal HTML comment. |

New this round:

| ID | File:Line | Rationale |
|---|---|---|
| N-09 | `bin/edm-state:587-622` | `write_atomic`'s two failure branches are now guarded on the same statement (`|| ec=$?`) by the CA-134 fix, so both are reachable from any call position, bare or tested. Round 2's N-1 caveat is closed, not merely unexercised. |
| N-10 | `bin/edm-state:552-553` | The `unsupported trap nesting depth` internal check cannot fire (`_EDM_TRAP_DEPTH` is only ever 0 or 1, and `with_state_lock:1034` dies before setting 2). Documented at `:548-551` as an intentional loud-failure sanity check. |
| N-11 | `bin/edm-state:4032` | The `-z "$insert_line"` disjunct remains near-dead (`pattern_insert_line_for` always prints, via `:3952` or `:3967`); reachable only on an awk failure. One-token defensive residue, unchanged from round 2's N-5. |
| N-12 | `bin/edm-state:4030-4036` | The in-lock missing-heading SKIP is **more** reachable than in round 2, not less: the outer `grep -qxF` at `:4103` is fence-unaware while `pattern_insert_line_for` is fence-aware (CA-056), so a heading that exists only inside a fence now legitimately passes the outer check and lands here. Not dead. The outer check's fence-blindness is CA-056's own open item. |
| N-13 | `bin/edm-state:3665` | `${close_prior_verdict:-PARTIAL}` is reachable only when `.verdict` is the empty string (jq's `//` falls through on null/false, not `""`). Harmless CA-047 residue; no longer fabricates a prior state. |
| N-14 | `bin/edm-state:3621` | The `re-closed` branch emits `prior_verdict` as the second tab-separated field, which the consumer at `:3662-3663` ignores (the message hardcodes `(was FAIL)`, correct by construction from the `:3601` guard). Uniform two-field protocol on both branches; consistent-shape, not dead logic. |
| N-15 | `bin/edm-state:2336-2338` | For a legacy (no `schema_version`) flat-layout initiative with no `product_name`, the `converged=false` archive refusal cannot fire. Documented at `:2324-2327` as deliberate preservation of pre-T12 behaviour for that class only; the unconditional refusal is at `:2396-2406`. |
| N-16 | `bin/edm-check-grants:431-437` | Both `while IFS= read -r ln` loops in `scan_hook_prompts` bind `ln` and pass `$lnum`, so `ln` is a dead binding and iterations after the first are no-ops. Explained at `:410-413`: each `"prompt"` value is one physical line, so `$lnum` is the correct citation and the loop is deliberately an "at least one instruction exists" test. |
| N-17 | `bin/edm-check-vocabulary:2-53` | The long contributor header is never printed; `--help` renders only the sentinel block at `:74-82`, which is self-contained (usage, output format, all three exit codes). Maintainer comment, not truncated help. |
| N-18 | `bin/_edm-lint-lib.sh:187-190` | `report_violation`'s "expected 4 or 5 args" arm cannot fire today (every call site is statically 4- or 5-arg), but it is an arity guard on a function three shipped binaries now consume, with two incompatible field orders. Keep. |
| N-19 | `bin/edm-init:140-144` | `mini-srd)`'s body is identical to `standard|iac|data-ml)`'s. Both arms are reachable, the `case` is exhaustive over the five values validated at `:49-52`, and each arm's comment states a different reason for the same effect. The empty `prototype)` arm at `:145-147` is a deliberate explicit no-op. |
| N-20 | `bin/edm-lint-artifacts:381-384` | Class 4 does not test `UNREADABLE_FLAGS`, but `MERMAID_SETS[$i]` is set to `""` for an unreadable file at `:277`, so `[[ -z "$mermaid_set" ]] && continue` at `:384` is an equivalent guard. |
| N-21 | `hooks/hooks.json:86` | The `code -eq 2` non-blocking arm is reachable, but **not via the cause its own documentation names**. `plugins/edm/CLAUDE.md`'s hooks table gives "e.g. no initiative for that prefix" as the example -- exactly the case the same CA-011 fix now filters out with `edm-state resolve-dir "$p" || continue` earlier in the line. The surviving triggers are an `mktemp` failure (`edm-lint-artifacts:122`, `:129`) and a TOCTOU race. Branch is live; the doc example is dead. Handing the prose half to L6. |
| N-22 | `.gitlab-ci.yml:355-366` | `test:smoke-bash32` combines a floating `bash:3.2` tag with hard-pinned `apk add jq=1.8.1-r0 git=2.49.1-r0`. An Alpine package-revision bump removes the pinned version from the index, `before_script` fails, and `script:` -- including the bash-3.2 assertion at `:365` -- never runs: structurally CA-006's shape. Noted, not raised: the header at `:30-34` names and accepts this exact failure mode ("will fail loudly ... which is the property this fix is actually buying"), and a failed job is a failed pipeline, not silent. Cross-referenced to CA-161. |
| N-23 | `.gitlab-ci.yml:601` | `if [ -f plugins/edm/evals/score-artifacts.sh ]` is trivially true in any full checkout; defensive against a partial artifact restore. Unchanged from round 2's N-10. |
| N-24 | `bin/tests/_harness.sh:177-186` | `count_matches_strict` is exercised only by its own self-test (`harness-smoke.sh:158-177`) and by no production assertion. Not unreachable, so out of L2's mandate; whether the CA-145 fix should have migrated the ~21 expect-zero callers to it (rather than pairing them with `assert_absent_with_control`, the other sanctioned remedy per `:162-164`) is L4's call. |
| N-25 | `bin/tests/run-all.sh:104-107` | The zero-assertion branch is reachable: it requires a suite that prints `Results: 0 passed, 0 failed`, which the summary-line parse at `:92-99` can produce. Not dead. |
| N-26 | `bin/edm-state:1682-1688` | **Cross-lens corroboration of CA-182 (P0, still open), not a new finding.** `cmd_approve_gate`'s convergence precheck runs only at `ag_schema_class2 == "2"`. `_cmd_init_render:1483` writes the literal `schema_version: 1`, and `plugins/edm/CLAUDE.md`'s own schema_version contract confirms "`cmd_init` never writes anything above `1`". So for every initiative created by `edm-init`/`cmd_init` that has not had an operator manually run `migrate-schema` -- which nothing prompts -- the precheck at `:1683-1685` is **environmentally unreachable** and control falls to the permissive `record_degraded_check` branch at `:1687`, which records the approval unconditionally. This is textbook L2 environmental unreachability and independently confirms CA-182 is still open. CA-183's sibling fix (the fast-track refusal at `:1666-1670`) is correctly placed *before* the schema gate and does work. |

---

## Coverage note

Read in full: `bin/edm-state` (all 4,607 lines), `bin/_edm-cli-lib.sh`, `bin/_edm-lint-lib.sh`, `bin/edm-lint-artifacts`, `bin/edm-check-grants`, `bin/edm-check-vocabulary`, `bin/edm-init`, `bin/edm-validate-prefix`, `bin/edm-compare-eval`, `bin/edm-check-skill-sync`, `bin/edm-sync-canonical-sections`, `bin/tests/run-all.sh`, `bin/tests/_harness.sh`, `hooks/hooks.json`, `.gitlab-ci.yml`, `.gitignore`. Read in relevant part: `evals/run-eval.sh`, `evals/score-artifacts.sh`, `evals/tiering-matrix.sh`, `plugins/edm/CLAUDE.md`, `agents/edm-audit-dead-code.md`.

Round 2's stated coverage gap -- `bin/tests/*-smoke.sh` bodies -- was addressed by targeted structural sweep rather than full line-by-line read (the three wave suites total roughly 12,000 lines): `run-all.sh` and `_harness.sh` read in full, all shared-helper call sites resolved by grep across the whole tree, and every `mktemp`/`trap` preamble enumerated. That is what produced L2-002 and L2-004. A full read of `wave6-smoke.sh` and `wave7-smoke.sh` bodies for dead assertions and fixtures for removed paths remains the largest unswept surface for this lens; L4 is the better owner of assertion quality, but a fourth round could close the residue with one dedicated pass.

Not opened this round: `skills/**` and `agents/**` prose beyond this lens's own definition, `docs/**`, `monitors/monitors.json` (both prose-only surfaces with no executable branching for this lens).

## Meta

CA-130 reproduced a third consecutive round: `Write` was absent from this lens's runtime tool set despite the frontmatter grant. This report was returned as text for transcription by the orchestrator.

**Two things the parent agent should action:**

1. **Do not close CA-142 or CA-049 on the presence of their remediation symbols.** L2-001 and L2-002 show both fixes shipped inert code -- the mechanism exists, is documented as working, and cannot run. Those two ledger rows should stay open with the new evidence attached rather than being marked fixed.
