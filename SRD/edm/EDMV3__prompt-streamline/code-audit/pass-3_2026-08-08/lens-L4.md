# Code Audit Pass 3 -- Lens L4: Test Quality

**Initiative:** EDMV3 (`prompt-streamline`) | **Round:** 3 | **Date:** 2026-08-08
**Scope:** `plugins/edm/` tree, focus on `bin/tests/` and `evals/`
**Method:** all 16 ledger entries whose Lens(es) include L4 and whose Status is `open` were re-read at source; each verdict below is from the current code, not from the prior round's report. Fresh sweep across the six waves of new test code followed.

## Verdict summary

| ID | Sev | Round-3 verdict | One-line basis |
|---|---|---|---|
| CA-002 | P0 | **fixed** | real insertion branch exercised against a scratch plugin copy; +2 line-anchored heading delta |
| CA-035 | P1 | **fixed** (new defect introduced) | pattern widened and genuinely discriminating; new hard `bc` dependency |
| CA-039 | P1 | **fixed** (minor residual) | four hand-computed literal expectations; one bound left as `< 100` |
| CA-040 | P1 | **fixed** (new defect introduced) | full 4x2 exemption matrix + CA-183 asymmetry; three unguarded assignments |
| CA-016 | P2 | **fixed** | missing-preferred loop + reachable `_MIN_SUITE_COUNT` floor |
| CA-037 | P2 | **partially fixed** | all 4 named residues closed; ~20 other expect-zero sites unswept |
| CA-038 | P2 | **fixed** | `i06` + em-dash `v12`, both enforced by line-exact assertions |
| CA-042 | P2 | **fixed** | `check_refuses_and_leaves_state` + 5 self-tests; 9 read-only sites all output-asserted |
| CA-085 | P2 | **fixed** (L4 half) | absent-job failure + two injected positive controls |
| CA-099 | P2 | **fixed** | fenced-tree extraction with a non-empty control case |
| CA-100 | P2 | **fixed** | existence, stage, allow_failure and checker-union all asserted |
| CA-101 | P2 | **fixed** (boundary half) | both walk boundaries asserted by line number + exact count 3 |
| CA-102 | P2 | **fixed** | absolute-range `sed` gone; extractor shared; source-of-truth named |
| CA-145 | P2 | **fixed** (small residual) | 9 self-tests incl. the vacuous-control case; strict variant has no callers |
| CA-146 | P2 | **NOT FIXED** | zero coverage of run-all.sh accounting anywhere in the tree |
| CA-147 | P2 | **partially fixed** | seven mode names asserted, but no mode is ever executed |

Of the 14 Wave-5 items claimed closed, **11 are genuinely closed with real positive controls**, 2 are partially closed (CA-037, CA-147), and 1 (CA-146) was not implemented at all. Two of the closures introduced new L4 defects of exactly the class round 2 was closing.

---

## Findings (L4: Test Quality)

### L4-301 (P1) -- CA-146 was not implemented: run-all.sh's accounting has zero test coverage

**Location:** `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/run-all.sh:59-141`

The string `CA-146` appears nowhere under `plugins/edm/`. Every structural precondition the finding named is still true:

- `run-all.sh` is not a `*-smoke.sh` file, so the discovery glob at `:29` never reaches it.
- `harness-smoke.sh` still has no case for it. Its sections are AC1/AC3, AC2, AC4, AC5, CA-145, CA-042, AC6/AC7 -- I read the file end to end.
- The only references anywhere in the suites are `wave7-smoke.sh:382-383`, which greps `$(cat run-all.sh)` for the literal `edm-check-grants`, and `wave7-smoke.sh:1958` / `:2324`, which assert `.gitlab-ci.yml` names the aggregator -- not that it works.

Every branch the CA-016 remediation added or rewrote is uncovered:

| Branch | Line | What passes that should not |
|---|---|---|
| zero assertions | `:104-107` | a suite emitting `Results: 0 passed, 0 failed` |
| non-zero exit with summary | `:108-111` | a suite that exits 1 but reports 0 failures |
| failed assertions | `:112-115` | `_s_fail != 0` not folded into the aggregate |
| CRASH | `:119-123` | a suite that dies before its summary |
| exit 0, no summary | `:124-126` | a suite that prints nothing and exits 0 |
| missing preferred suite | `:67-70` | a deleted/renamed named suite |
| suite-count floor | `:72-75` | a silently shrunk discovered set |

This is the script whose exit code IS the verdict of the blocking `test:smoke` and `test:smoke-bash32` CI jobs. If its accounting inverts, every suite result in the pipeline becomes unreliable and nothing detects it. The round-2 REMEDIATION.md prescribed `harness-smoke.sh # new cases for CA-145, CA-146, CA-158`; CA-145 landed, CA-146 did not.

**Fix.** Add a `CA-146` section to `harness-smoke.sh` that writes throwaway suite scripts into `${TMPDIR:-/tmp}` scratch, runs `run-all.sh` against a `SCRIPT_DIR` override (or refactors the aggregator to accept a suite directory argument), and asserts one case per branch: a suite printing `Results: 0 passed, 0 failed`, a suite printing a clean summary then `exit 1`, a suite printing `Results: 3 passed, 1 failed`, a suite whose first line is `exit 1`, a suite that prints nothing and exits 0, and a discovery set of six. Each case asserts the STATUS column token (`PASS`/`FAIL`/`CRASH`), the `_suite_note` text, and the aggregator's own exit code.

---

### L4-302 (P1) -- the CA-035 remediation makes `wave7-smoke.sh` depend on `bc`, which none of the pinned CI images installs

**Location:** `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/wave7-smoke.sh:1859`

```bash
t42_ac4_raw="$(grep -rhcE 'CLAUDE\.md Sec\.\\?"?Mermaid diagram conventions' "${PLUGIN_DIR}/" 2>/dev/null | paste -sd+ - | bc)"
```

This is the only `bc` invocation anywhere in `plugins/edm/`. All eleven `apk add --no-cache` lines in `.gitlab-ci.yml` (`:85`, `:133`, `:152`, `:165`, `:191`, `:222`, `:268`, `:325`, `:360`, `:389`, `:438`) install only `bash`, `jq`, `git` and `shellcheck`. `bc` is a separate Alpine package and is not in the declared set for either `test:smoke` or `test:smoke-bash32`.

`wave7-smoke.sh:8` is `set -euo pipefail`, so with `bc` absent the pipeline fails, the assignment fails, and the suite aborts at line 1859 -- roughly 2,900 lines and several hundred assertions (T43 through T67, the entire CA-002/CA-133/CA-134/CA-135/CA-136/CA-137/CA-144/CA-154/CA-160 remediation block at `:2344` and `:4540+`) never execute. `run-all.sh:119-123` reports it as CRASH, so it is loud rather than silent, which is why this is P1 and not P0. But it means the two blocking CI jobs whose entire purpose is running this suite can never complete it on the images they are pinned to, and the failure mode is a crash in a case unrelated to whatever a contributor was changing.

**Fix.** Replace the fork with in-suite arithmetic, e.g. `| awk '{s+=$1} END{print s+0}'` (awk is already a hard dependency of every suite), or use the existing `count_matches` helper. Do not add `bc` to eleven `apk add` lines to serve one arithmetic sum.

---

### L4-303 (P2) -- the CA-040 remediation re-introduces the CA-036 class: unguarded command-substitution assignments abort the suite instead of failing an assertion

**Locations (six sites, three of them new this wave):**

| File:line | Introduced by |
|---|---|
| `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/wave6-smoke.sh:3657` | CA-040 remediation |
| `.../wave6-smoke.sh:3670` | CA-040 remediation |
| `.../wave6-smoke.sh:3679` | CA-040 remediation |
| `.../wave6-smoke.sh:3221` | pre-existing (T50) |
| `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/wave7-smoke.sh:995-996` | pre-existing (T20 AC10) |

```bash
# wave6-smoke.sh:3657
ca040a_out="$("$EDM_STATE" audit-converged ZC40A 2>&1)"; ca040a_ec=$?
[[ $ca040a_ec -eq 0 ]] \
  && pass "CA-040 -- audit-converged exits 0 for mode=prototype (audit-free mode, AC8)" \
  || fail "CA-040 -- audit-converged did not exit 0 for mode=prototype (got $ca040a_ec: $ca040a_out)"
```

`wave6-smoke.sh:6` is `set -euo pipefail`. An assignment whose command substitution exits non-zero is a simple command in errexit position, so the shell exits before `ca040a_ec=$?` is ever evaluated. **The `fail` branch at `:3660`, `:3673` and `:3682` is unreachable code.** The exact regression each of these three cases exists to catch -- an exemption arm that stops exempting -- ends the run at line 3657 rather than producing a named failed assertion, and takes the entire wave-4a remediation block below it (CA-026 at `:3753`, CA-059 at `:3808`, CA-061, roughly 130 further assertions) down with it.

This is the same defect as CA-036, which round 1 raised and round 2 recorded as fixed. It came back inside the fix for CA-040.

The sibling cases in the same block get it right: `:3688` uses `ca040d_out="$(...)" || ca040d_ec=$?`, and the archive cases at `:3700`/`:3707`/`:3714`/`:3729` use `|| true`.

**Fix.** Use the `|| var_ec=$?` form already used at `:3688`, or the `set +e` / `set -e` bracket already used at `:2767-2770` and `:3616-3619`. Then add a grep tripwire to the suite so the class cannot return a third time: assert zero matches for `^[a-zA-Z_0-9]*="\$\(.*\)"; *[a-zA-Z_0-9]*_ec=\$\?` across `bin/tests/*.sh`, with a synthetic positive control.

---

### L4-304 (P2) -- CA-147 residual: `timing.sh`'s seven measurement modes are still never executed

**Location:** `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/wave7-smoke.sh:3969-3984`

The remediation replaced a single `generate-fixture` token grep with a loop over all seven mode names:

```bash
t67_timing_usage="$(bash "$TIMING_SH" 2>&1 || true)"
for t67_mode in --subcommands --phase-complete --ledger --session-start --lint --mermaid-ratio --all-lint; do
  check "T67 AC14 -- timing.sh usage lists measurement mode ${t67_mode}" "$t67_mode" "$t67_timing_usage"
done
```

That closes the "a stub echoing one word passes" hole and does now execute the script once (no-arg usage path). But the stated defect survives one level up: **a `timing.sh` reduced to printing its own usage block and exiting still passes all eight assertions**, because no mode is ever run. I confirmed no measurement mode is invoked anywhere under `bin/tests/`, in `run-all.sh`, or in `.gitlab-ci.yml`.

This matters because `timing.sh` is the sole producer of the committed latency budgets in `CHANGELOG.md`'s T67 table and both budgets in `CLAUDE.md Sec."edm-lint-artifacts latency budgets"` (3,000 ms commit-path and 60,000 ms CI), and because two independent open findings say its measurement path is currently wrong: CA-158 (the perl-less `_now` fallback) and CA-084 (`--mermaid-ratio` calling `perl -e` unconditionally). The `srand()` at `timing.sh:39` is now vestigial but the arithmetic path is still unexercised. A harness whose header at `:7` reads "Every mode is a REAL measurement against a REAL (generated) fixture -- no numbers are invented" is asserted only on its help text.

**Fix.** Execute the cheapest mode once and assert the shape of a real result: generate a 1-initiative fixture, run `--subcommands`, and assert the output contains a positive integer millisecond figure (e.g. matches `p95[^0-9]*[1-9][0-9]*`), plus a non-zero exit is a failure. That single case would also catch CA-084's perl-less abort on the images that fallback exists for.

---

### L4-305 (P2) -- CA-037 residual: roughly twenty expect-zero assertions still carry no positive control

All four residues the finding named by name are genuinely closed with synthetic controls run through the identical pattern:

- duplicate `--force` count: `wave6-smoke.sh:2401-2408`
- three T66 AC4 deleted-text counts: `wave7-smoke.sh:1160-1186`
- both `code_audit_converged` checks: `wave7-smoke.sh:403-405`, `:1299-1309`
- the mapfile regex: `wave7-smoke.sh:373-381`, now `(^|[^a-zA-Z0-9_])(mapfile|readarray)([^a-zA-Z0-9_]|$)` with a `mapfile<f` control. I traced this by hand: `^` satisfies the left boundary, `<` satisfies the right, so the widened pattern does match the form the old one could not.

The general sweep the finding also asked for did not happen. Representative load-bearing sites still uncontrolled:

| Location | What passes that should not |
|---|---|
| `wave7-smoke.sh:1318-1322` and `wave7-smoke.sh:1670-1673` | the same repo-wide `--force\|--accept-partials` grep, duplicated across T66 AC12 and T30 AC10. Both are `[[ -z ]]` over a `grep -rn` with three chained `grep -v` filters and `\|\| true`. A wrong `$PLUGIN_DIR`, a mistyped `-v` filter, or an over-broad filter reads identically to a clean tree, in both copies at once |
| `wave6-smoke.sh:451-455` | T01 AC6. The needle is deliberately assembled from two halves (`_t01_ac6_verb`, `_t01_ac6_field`) so the line cannot self-match -- which is also why nothing proves the assembled needle matches anything |
| `wave6-smoke.sh:719-722` | the two-stage `Step 0` / `deterministic` vocabulary guard, same split-needle construction, same absence of proof |
| `wave6-smoke.sh:3173-3176` and `wave7-smoke.sh:2431-2433` | the `Skill`-grant zero-count on `implement/SKILL.md`, asserted twice, controlled neither time |
| `wave6-smoke.sh:3181-3184` | `grep -rl 'phase-complete' skills/code-audit/` expecting 0 -- a directory-path typo passes |
| `wave5-smoke.sh:181` | `check_absent ... "baseline" "$MR_OUT"`. The natural positive control is one line below at `:182` (`MR_BASELINE_OUT`, which must contain the word) and is not used |

`assert_absent_with_control` (`_harness.sh:190-199`) and `count_matches_strict` (`:177-186`) both exist for exactly this. Total `check_absent` + `assert_absent_with_control` occurrences across the suites: 120.

**Fix.** Convert the six sites above (the two duplicated `--force` scans, the two split-needle guards, the doubled `Skill` grant, the `code-audit/` path scan, and `wave5:181`) to `assert_absent_with_control`, using the adjacent live text as the control haystack where one exists rather than a synthetic string.

---

### L4-306 (P2) -- `tiering-matrix.sh --self-test` reports a hardcoded `6/6`, so deleting the CA-104 boundary test leaves both the self-test and its wave7 assertion green

**Locations:** `/Users/darryl.porter/projects/marketplace/plugins/edm/evals/tiering-matrix.sh:308-315` and `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/wave7-smoke.sh:4188`

```bash
# tiering-matrix.sh:309-314
if [[ "$failures" -eq 0 ]]; then
  echo "self-test: PASS (6/6 promotion-rule assertions verified)"
  return 0
else
  echo "self-test: FAIL (${failures}/6 assertion(s) failed)" >&2
```

```bash
# wave7-smoke.sh:4188
check "T48 -- self-test summary reports 6/6" "self-test: PASS (6/6" "$t48_matrix_out"
```

The `6` is a string constant. Nothing counts assertions executed -- only `failures` is ever incremented. Delete any of the six assertion blocks and the self-test still prints `6/6` and `wave7-smoke.sh:4188` still passes. That includes the pair at `:287-298` (`synthetic-agent-d-eighty-qualifies` at exactly 80 percent, `synthetic-agent-e-seventy-nine-disqualified` at 79) which IS the CA-104 remediation -- the only thing pinning `>= 80` against `> 80`. So the guard against the CA-104 regression is itself unguarded, and the wave7 assertion that looks like it protects the count actually protects only a literal.

Round 2 raised the same shape as CA-138 against this file (a byte-identical duplicated assertion, seven increment sites against a hardcoded `/6`). The duplicate assertion is gone and the site count now genuinely is 6, so that half is fixed; the hardcoded denominator is not.

**Fix.** Add `assertions_run=$((assertions_run + 1))` beside each of the six blocks, print `${failures}/${assertions_run}`, and change `wave7-smoke.sh:4188` to extract the denominator and assert `>= 6` rather than matching the literal string.

---

### L4-307 (P2) -- twenty refusal assertions in the three older suites assert the message and never the exit code

**Locations:** `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/wave5-smoke.sh` lines 49-50, 52-53, 55-56, 58-59, 71-72, 120-121, 124-125, 138-139, 140-141; `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/wave4a-smoke.sh` lines 49-50, 68-69, 91-92, 93-94, 95-96, 97-98, 178-179, 180-181, 276-277.

```bash
# wave5-smoke.sh:49-50
check "path-traversal product rejected" "must contain only" \
  "$("$EDM_STATE" migrate-path --product "../evil" --description safe MIGR2 2>&1 || true)"
```

`|| true` discards the exit code and the assertion is a substring match on combined output. **A regression where `migrate-path` prints the "must contain only" diagnostic as a warning and then performs the move passes this test.** Two of the eleven wave5 sites do carry a companion post-condition that would notice (`:63` and `:137` assert nothing escaped `SRD_ROOT`); the other nine, including all three path-traversal input validations at `:49-56` and the duplicate-target guard at `:71-72`, have no post-condition at all.

`check_fails` (`_harness.sh:134-153`) does exactly the right thing -- non-zero exit AND case-insensitive message from one invocation -- and its own header explains why: "An exit-code-only assertion would pass on any unrelated failure, which is the failure mode that matters for a suite full of must-fail cases." It is used roughly thirty times across wave6 and wave7. wave5 and wave4a were never swept onto it. This is the same class as CA-043, which round 2 closed at one wave7 site.

**Fix.** Mechanical substitution: `check "<label>" "<msg>" "$(CMD 2>&1 || true)"` becomes `check_fails "<label>" "<msg>" CMD`. For the five wave5 state-mutating cases (`migrate-path`, `set-parent`, `add-related`), prefer `check_refuses_and_leaves_state` so the post-condition is proven from the same execution.

---

### L4-308 (P2) -- `count_matches_strict` was added as the CA-145 fix and has no callers

**Location:** `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/_harness.sh:177-186`

The exit-2 collapse in `count_matches` (a missing or unreadable file printing the same `0` a genuinely absent pattern prints, where `0` is the passing value for every expect-zero caller) is now documented as an explicit caveat at `:158-164` and proven directly by a self-test at `harness-smoke.sh:153-155`. `count_matches_strict` closes it by printing `ERROR` and returning 2, and is self-tested at `harness-smoke.sh:170-177`.

But every count site in the tree still uses either bare `count_matches` (`wave7-smoke.sh:1890-1891`) or a bare `grep -c ... || true` (about forty sites). The mechanism exists, is documented, and is tested; nothing consumes it, so the defect it was built to prevent is still live at every one of those sites.

**Fix.** Convert the expect-zero count sites named in L4-305 to `count_matches_strict` and assert its exit status, not only its printed value. The `2>/dev/null` inside both helpers means a missing-file diagnostic is already discarded, so the exit code is the only remaining signal.

---

### L4-309 (P2, minor) -- two residual weak assertions in otherwise-strong new blocks

1. `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/wave7-smoke.sh:608-610` -- the CA-039 all-invalid corpus case asserts `"$d3" -lt 100` where the value is computable and should be `0`. It is the only non-literal expectation in a block whose three siblings all assert hand-computed exact values (`50`, `100`, `80`) with the arithmetic spelled out. A scorer that returned 99 for an all-invalid corpus passes.

2. `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/wave7-smoke.sh:2287` -- inside `t44_ac4_case`, `expected="$(sed -n '1p' "$f" | grep -oE 'expected-line: [0-9]+' | grep -oE '[0-9]+')"` is unguarded under `set -e` while the sibling `actual=` two lines below is correctly bracketed by `set +e` / `set -e`. The loop globs all of `invalid/*.md`, but the marker-existence loop at `:2270-2275` only covers the six hardcoded names, so a seventh invalid fixture added without an `expected-line:` marker crashes the suite instead of failing it.

**Fix.** (1) Assert `== 0` with the derivation in a comment. (2) Move `expected=` inside the existing `set +e` bracket and `fail` with the fixture name when it comes back empty.

---

### L4-310 (P2, minor) -- CA-101 residual: no valid fixture proves a legal parenthesised or curly label with a trailing terminator passes

The boundary half of CA-101 is properly closed -- `wave7-smoke.sh:2056-2085` puts an 11-character entity-shaped token (one over the `1..10` walk's ceiling) on line 6 of `invalid1.md` and a zero-character `#;` (one under its floor) on line 7, asserts each **by line number** (`invalid1.md:6: mermaid-semicolon`, `invalid1.md:7: mermaid-semicolon`), and pins the total at exactly 3 so neither boundary can be swallowed behind line 5's unrelated hit. That is a real, discriminating test of the off-by-one bounds.

The second half is still open. `fixtures/mermaid/valid/v06-flowchart-quoted-commas-parens.md` exists and `invalid/i04-curly-label.md` covers the curly violation, but I found no valid fixture asserting that a **legal** `(...)` or `{...}` label span carrying a trailing terminator passes. So a `strip_entities` change that over-consumed a parenthesised or curly span would show up as a false negative in the invalid corpus only, not as a false positive anywhere.

**Fix.** Add one valid fixture with a `(...)` label and a `{...}` label each containing a `#59;` entity plus a statement-terminating `;` outside the label, and add it to the `valid/` CLEAN assertion at `wave7-smoke.sh:2279-2280`.

---

## Noted / Not Actionable

1. **`run-all.sh:71-75`'s `_MIN_SUITE_COUNT=7` looks unreachable given the missing-preferred loop above it** -- it is reachable: dropping a name from `_PREFERRED_ORDER` *and* deleting that suite defeats the name loop but not the floor. The two guards are complementary, not redundant.

2. **`wave7-smoke.sh:4068-4080` deliberately does not ban bare `apk add` / `apt-get` in the CI network scan** -- the reason is stated in place (every blocking job legitimately bootstraps its own toolchain from the image index) and the widened `npm install` half carries its own positive control at `:4104-4110`.

3. **`ca039_dim3_valid_corpus_case` excludes `v08` and `v09` from the valid corpus** -- documented in place at `wave7-smoke.sh:579-585` as real cross-implementation divergence owned by CA-019, deliberately not re-litigated in a dimension-3 scoring case.

4. **`score-artifacts.sh` dimension 5 is asserted only as `!= null`** (`wave7-smoke.sh:1457-1458`) -- an incomplete assertion by L4's standards, but it is already tracked as CA-165 (L11), which identifies the root cause (the metric counts a leading `L{N}-NNN` local ID that only the hand-authored fixture emits). Do not double-file.

5. **`check_state_unchanged` still discards exit code and output at `_harness.sh:227`** -- correct now that all nine remaining callers are read-only commands and each has a separate output assertion on the same command (`wave6-smoke.sh:54`/`93`/`121` for the three `validate` calls, `:2419-2428` for the four T64 AC7 commands, `:2768-2772` for `audit-converged`).

6. **`check_absent` is used 120 times, often with no explicit positive control** -- the dominant pattern pairs it with a positive `check` on the same extracted string (`wave7-smoke.sh:438`/`440`, `:448`/`449`, `:1041`/`1042`, `:2280`/`2281`, `:3169`/`3171`), which fails if the extraction anchor drifts and is a genuine implicit control. Consistent project pattern; only the sites in L4-305 lack both forms.

7. **`harness-smoke.sh:63-91` spawns a child, sleeps, and sends SIGINT** -- timing-dependent, but both waits are bounded polls (not fixed sleeps) with the rationale written out at `:56-60` and `:78-79`, and the assertion is scoped to the child's own reported scratch path rather than any `edm-scratch.*` under `TMPDIR`.

8. **`wave7-smoke.sh:4673-4686` writes under the real `$HOME/.claude/projects/`** -- consistent with `_harness.sh:314 session_dir_for_test_cwd`, the sanctioned pattern for cost-tracking tests, and the encoded path is derived from a unique scratch cwd so it cannot collide with a real session directory. Isolation/hygiene residue belongs to L5.

9. **`harness-smoke.sh:158-159` and `:165-166` read `$?` after an unbracketed `count_matches_strict` assignment** -- correct only because those two calls return 0 by construction; the one call that returns 2 is properly bracketed at `:171-174`. Cosmetic asymmetry, no live defect.

10. **`wave6-smoke.sh:3669` and `:3739` hand-edit `schema_version` to 2 with `jq ... > tmp && mv`** -- a deliberate fixture-shaping step, not a bypass; `migrate-schema` would additionally require interactive confirmation, and CA-182 (the schema-gated approve-gate bypass) is the finding that owns whether that gating is right.

11. **`tiering-matrix.sh:276` uses `"total_findings": 7.9`** -- a non-integer finding count is semantically odd, but it is the cheapest way to land exactly one percentage point under the `>= 80` floor, and the intent is stated in the comment at `:239-241`.

12. **`.gitlab-ci.yml` never names `wave7-smoke.sh`** -- by design (`run-all.sh` auto-discovery, T20 AC3, asserted with a positive control at `wave7-smoke.sh:1049-1060`).

---

## Recommended ledger status transitions

| ID | Current | Proposed |
|---|---|---|
| CA-002, CA-016, CA-038, CA-042, CA-085, CA-099, CA-100, CA-102 | open | **fixed** (resolved_round 3) |
| CA-035, CA-040 | open | **fixed** (resolved_round 3), with the two new findings filed separately |
| CA-039, CA-101, CA-145 | open | remain open, re-scoped to the narrower residual described above |
| CA-037, CA-147 | open | remain open (partially fixed) |
| CA-146 | open | remain open, **escalate P2 -> P1** (not implemented; guards the blocking CI verdict) |

## Fixing the gaps

The coverage gaps here (L4-301 run-all.sh accounting, L4-304 timing.sh execution, L4-310 the missing valid fixture) are new-test work rather than repairs to existing tests. `/edm:test EDMV3` would route them to the unit and integration test-writer agents; `/edm:test EDMV3 --fill-gaps` after reading `SRD/edm/EDMV3__prompt-streamline/test-coverage.md` would target only these three. L4-302, L4-303, L4-305, L4-306, L4-307, L4-308 and L4-309 are all mechanical edits to existing assertions and are cheaper to fold into a remediation wave than to route through the test writers.
