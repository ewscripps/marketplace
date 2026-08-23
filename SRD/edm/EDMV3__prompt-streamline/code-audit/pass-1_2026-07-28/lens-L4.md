# Code Audit Lens L4: Test Quality

- **Date**: 2026-07-28 | **Round**: pass-1 (full, 11 lenses) | **Branch**: `edm/edmv3-prompt-streamline`
- **Note**: the lens agent had no Write tool at runtime despite its frontmatter granting one, so this file was transcribed by the orchestrator from the agent report. Findings, sites, severities and fixes are unaltered.

**Totals: P0 = 1, P1 = 19, P2 = 19, NOTED = 7.** Open P2 blocks convergence.

## Class A -- zero-count assertions with no positive control (permanently green on a misspelled needle)

A 0 count is produced identically by the invariant holding, a typo in the needle, or a wrong path (`|| true` / `2>/dev/null` turns grep's error into the passing value). Only two sites in the whole suite carry a control: `wave7-smoke.sh:931` and `:3450-3457`.

| ID | Sev | Site | Defect | Fix |
|---|---|---|---|---|
| L4-A1 | P1 | `wave7-smoke.sh:174-177` (T09 AC13) | `--force` absent from `bin/edm-state`; nothing proves the needle can match. Guards the single most load-bearing product invariant (no override flag). Duplicated at `wave6:2418-2420`, `wave7:1007-1011`, `wave7:1354-1357` | Control against `bin/vocabulary-prohibited.txt`, which contains `literal:--force`; collapse the four sites into `assert_absent_with_control` |
| L4-A2 | P1 | `wave7-smoke.sh:224-226` (T03 AC2/AC4) | `^agent:` zero-count. The nearby line 231 matches mid-line inside a `warning:` prefix, so it does not prove the anchored format. `report_violation` may re-prefix and this goes permanently green while unsatisfied agents accumulate | Assert the AC6 injected failure emits a `^agent:` line, making the negative case the control |
| L4-A3 | P2 | `wave7-smoke.sh:322-324`, `:1834-1837`, `:711-721` | `mapfile\|readarray` regex requires trailing whitespace, so `mapfile<file` never matches, and nothing proves it fires | One shared heredoc probe containing `mapfile -t a < f`, `declare -A x`, `${v^^}` |
| L4-A4 | P2 | `wave7-smoke.sh:837-841` (T21 AC5) | Wave-token zero-count passes on a wrong `GITLAB_CI_YML` path | Assert the file is non-empty; control the regex against the literal `wave7-smoke.sh` |
| L4-A5 | P2 | `wave7-smoke.sh:939-950` (T66 AC4) | Three deleted-text zero-counts; no control attempted from anywhere | Pin each needle against `CHANGELOG.md`, which records the removals |
| L4-A6 | P2 | `wave7-smoke.sh:994-997`, `:341-343` | Duplicate `code_audit_converged true` absence checks, neither controlled; a key rename makes both vacuous | Control against `bin/edm-state`'s `SETTABLE_KEYS` refusal; keep one |
| L4-A7 | P2 | `wave7-smoke.sh:1988-1991` (T33 AC4) | Third-verdict-token grep passes on a path typo. `BLOCKED` legitimately appears at `wave6:2844`, so a control is free | Assert the same grep over `bin/tests/` returns non-empty |
| L4-A8 | P2 | `wave7:1625-1628`, `:3158-3160`, `wave6:3187-3190`, `wave7:2014-2016` | Controlled only by undocumented adjacency a future edit can remove | Add a one-line comment naming each control, as `wave7:926-934` does |
| L4-A9 | P2 | `wave7:2119-2121`, `wave6:711-714` | Needle assembled from two halves so the checker's own source is not a hit; a change to either half yields a needle matching nothing | Assert the assembled needle matches a literal probe |
| L4-A10 | P2 | `wave7:2957-2960`, `:3235-3237`, `:2178-2181`, `:2167-2170`, `:1543-1551`, `:2523-2525`, `wave6:2415-2417` | Seven further uncontrolled `-z`/`-eq 0` assertions | Route through one shared helper |

## Class B -- assertions structurally incapable of failing

| ID | Sev | Site | Defect | Fix |
|---|---|---|---|---|
| L4-B1 | P1 | `wave6-smoke.sh:3436-3437` (T52 AC2) | Expected substring is the **empty string**, and `check` is a `*"$expected"*` match, so it passes unconditionally -- reporting PASS when `attribution_mode` is null, absent or garbage. It is the only assertion covering AC2 | Compare against the two legal values explicitly |
| L4-B2 | P1 | `wave6-smoke.sh:3439-3445` (T52 AC4) | The `else` branch passes for any non-`scoped` value including empty. With B1 vacuous, a total regression of session scoping (the feature stopping a second window inflating cost 100x, which the 100000-vs-1000 fixture exists to catch) reports two PASSes. The one assertion that could catch it is gated behind a condition the regression turns off | Assert the mode is legal first; in the fallback branch assert the honest whole-directory total 101000 |
| L4-B3 | P1 | `wave7-smoke.sh:1536-1539` (T42 AC4) | Fixed-literal grep piped to `sort -u \| wc -l` is always 1 given any match, so it can only distinguish "at least one" from "none". It can never detect a second, different quoting form -- the exact opposite of its label | Widen the capture to the reference family, then count distinct forms |
| L4-B4 | P1 | `evals/score-artifacts.sh:485-501` via `wave7:451-455` | The AC3 assertion recomputes the same arithmetic the scorer used, so it is a self-consistency identity. It cannot detect a wrong dimension score, a wrong sign, a swapped dimension, or a scorer returning 0 for everything | Score a fixture with hand-computed values and assert dimension scores and total against literals |
| L4-B5 | P2 | `wave4b-smoke.sh:167` + 16 sites | Needles too short to fail: `mode` matches `model`/`modes`; `P0`, `AskUserQuestion`, `tdd`, `TDD`, `escalate`, `qc/`, `set-mode`, and nine CLAUDE.md "in layout" checks that only prove a filename appears somewhere in a 1000-line file. Labels claim behaviours the words do not establish | Scope each to its section with `_wave7_extract_section`; where the label claims a behaviour, assert the sentence |

## Class C -- unguarded zero-match commands abort the suite instead of failing

Under `set -euo pipefail` a zero-match `grep -c` in an assignment exits the suite, surfacing in `run-all.sh` as `FAILED SUITES` with **zero failed assertions**.

| ID | Sev | Site | Defect | Fix |
|---|---|---|---|---|
| L4-C1 | P1 | `wave7-smoke.sh:1652-1653` (T43 AC1) | Unguarded. If the refactor is reverted or the function renamed -- the regression it exists to catch -- the suite aborts and the remaining ~1800 lines never run | `\|\| true` via a `count_matches` helper |
| L4-C2 | P1 | `wave7-smoke.sh:2146`, `:1458` | Unguarded counts on the canonical Gate PROTOCOL heading and a fence count. A deleted heading aborts rather than fails. `:2615` asserts the same heading *with* `\|\| true`, so the suite is internally inconsistent | Same |
| L4-C3 | P1 | `wave7-smoke.sh:1567-1568`, `:2048` | Unguarded `grep -c '^## '` over pattern docs; a doc reduced to zero headings aborts | Same |
| L4-C4 | P2 | `wave6`: `:228,235,572,579,663,691,1391,1491,2755`; `wave7:3378` | Ten further unguarded counts. `wave6:2755` (`BLOCKING_FILTER` expects exactly 5) and `:691` are the most consequential | Same helper across all |
| L4-C5 | P1 | `run-all.sh:81-96, 133` | `${_s_pass:-0}` means an aborted suite contributes `0 0`, so the aggregate prints `Total: N passed, 0 failed` beside `FAILED SUITES` -- the contradictory output already hit once. Worse, a suite that prints nothing and exits 0 reports `PASS 0 0`, indistinguishable from green. No floor on assertions or suite count | (1) status != 0 with no summary parsed -> `CRASH` and +1 to `_total_fail`; (2) status 0 with no summary -> fail naming the suite; (3) assert a per-suite minimum assertion count |

## Class D -- code changed in this initiative with no test, or only a vacuous one

| ID | Sev | Site | Defect | Fix |
|---|---|---|---|---|
| L4-D1 | **P0** | `bin/edm-state:3547-3591`, `:3431-3449` | `cmd_update_patterns`' heading-targeted insertion has **zero** coverage. The only test (`wave7:1575-1598`) seeds a deliberate duplicate and asserts "no novel findings" plus byte-identity -- both satisfied by a `cmd_update_patterns` that does nothing at all (empty normalizer, `pattern_insert_line_for` returning 0, or a non-matching `grep '^### '` all pass it). No test anywhere inserts a novel finding. Untested: the insertion, the `pending-review` Append Schema block, the atomic `mv`, the per-entry `_insert_line` recomputation, the `---` back-up, the last-section EOF case, the missing-heading SKIP whose contract is "never fall back to EOF", the not-writable skip, and `pattern_target_heading_for`. `wave7:2570-2578` and `:2844-2847` record all of it BLOCKED-ON-OWNER; the code landed and the tests did not | Scratch-copy case: two novel headings plus a duplicate; assert exactly two entries appended, both `pending-review`, both inside `## Anti-Patterns`, `_t56_four_heading_contract_check` clean afterwards, duplicate skipped, second run appends nothing. Separate case with the heading removed asserting the SKIP message and byte-identity |
| L4-D2 | P1 | `wave7-smoke.sh:1575-1598` | `cmd_update_patterns` resolves `pattern_file` from `$0`'s directory, which `with_scratch_repo` does not redirect, so the test writes into committed plugin source if de-duplication regresses. The insertion targets the 2nd heading so the contract check would not catch it either | Copy `bin/` + `docs/` into the scratch dir and invoke the scratch binary, as `t30_ac2_case` already does |
| L4-D3 | P1 | `bin/edm-lint-artifacts:160-166` | The fence-indentation fix has no test in either direction. Zero indented fences in the 16-file corpus; every T43/T44 fixture puts its fence at column 0. **Reverting the change keeps the suite fully green** | Two fixtures: an indented non-mermaid fence containing an attribution-trailer line and an em dash, asserted CLEAN; an indented mermaid fence with a raw `;` in a `[...]` label plus an `expected-line:` marker |
| L4-D4 | P1 | `evals/score-artifacts.sh:242-305` | Dimension 3 is never executed -- the synthetic `srd.md` has no mermaid block, so 35 lines of awk are untested. Its fence regex anchors at column 1, i.e. it has exactly the bug `edm-lint-artifacts` was just fixed for, and nothing tests the two implementations against a common corpus | Score a run whose `srd.md` is assembled from the committed `valid/*` fixtures and assert dimension 3 == 100; repeat with `invalid/*` and assert < 100 |
| L4-D5 | P1 | `evals/score-artifacts.sh:197-232` | The vague-AC detector is never proven to match anything: the fixture's single AC is deliberately not vague, so `vague_count` is 0 on every run. An empty pattern list, a malformed regex, or a failed `grep -f` would score 100 for every input, silently inverting the dimension. Polarity untested | Add a second, vague AC and assert `.dimensions[1].score == 50` |
| L4-D6 | P1 | `evals/score-artifacts.sh:308-363` | Dimension 4 never executes (no `tickets/README.md`, no `audit-srd.md`), so neither the coverage-map path nor the fallback, and neither direction of the bidirectionality check, is ever run. Three of five dimensions never execute; the two that do have no expected-value assertion | Extend the fixture with an `audit-srd.md` naming a real and a fabricated requirement; assert dimension 4 against the hand-computed value |
| L4-D7 | P1 | `bin/edm-state:579-591` | `convergence_exempt`'s whole reason to exist is untested: the `lifecycle_mode` half at either consumer, the `mode == "null"` legacy branch, and -- most importantly -- the deliberate asymmetry that `approve-gate code-audit` stays refused under `fast-track` while archive and audit-converged become exempt. A future edit routing approve-gate through the helper "for consistency" opens a gate bypass silently | Three cases per consumer across the four mode/lifecycle combinations, plus one asserting approve-gate still refuses under `fast-track` |
| L4-D8 | P1 | `wave6:3455-3458`, `:3488-3500`, `:3505-3508` | Three gaps in the pricing tests: "frozen, not env-overridable" is asserted only as `> 0`, which any rate satisfies; only the opus previous-generation arm is tested at all; and the documented silent in-family mispricing has no test, so it can flip either way unnoticed | Assert an override does **not** change a frozen arm; mirror for sonnet and haiku; pin the live generation's behaviour |
| L4-D9 | P2 | `wave7:3318`, `:986-990`, `:3334` | The four-way lint split is asserted by job *name* only. Nothing asserts the jobs exist, are in the lint stage, collectively still invoke every checker, or carry no `allow_failure`. `allow_failure: true` is counted globally (expects 2), so moving it onto a lint job while removing it elsewhere keeps the count and passes. `:3334` records the split as an unfixed gap while `:3318` treats it as landed -- the suite contradicts itself | Iterate the four names; assert existence, stage, no `allow_failure`, and that the union of scripts names all four checkers; scope the `allow_failure` count to named blocks |
| L4-D10 | P2 | `bin/edm-lint-artifacts:213+` | `strip_entities`' explicit 1..10 walk is never tested at its boundary (an 11-character token, or `#;` with zero characters), and the `(...)` / `{...}` spans have no *valid* counterpart proving a legal parenthesised label with a trailing terminator passes | Two lines added to the existing scratch fixture |

## Class E -- assertions coupled to transient state or exact wording

| ID | Sev | Site | Defect | Fix |
|---|---|---|---|---|
| L4-E1 | P1 | `wave7-smoke.sh:2101-2103` | Asserts git *history* (`git log ... \| grep -c 'EDMV3-T34'`), not tree state -- the same shape as the `git diff --stat` assertion already rewritten today. Vacuous on a shallow clone (GitLab's default), a squash, a rebase, a convention change, or outside a work tree, and `2>/dev/null \|\| true` converts every one into a pass | Delete it. The property AC5 wanted is already asserted structurally by T37 AC2 and T38 AC3 |
| L4-E2 | P2 | `wave6:3520`, `wave7:358` | Hard-coded absolute line ranges into files other tickets edit freely; an insertion above silently changes what is asserted | Use `_wave7_extract_section` or an awk range keyed on the heading |
| L4-E3 | P2 | `wave7:313-314`, `:963-968`, `:2461`, `:2477`, `:3362`, `:1861-1867`, `wave6:2756` | Baseline counts that will drift, whose failure message reads as a test defect rather than a drift signal | Name the source of truth in the failure message; prefer documented-vs-disk over documented-vs-literal, as `wave7:310-312` already does |
| L4-E4 | P2 | `wave7-smoke.sh:954-957` | An alternation count `>= 4` is satisfied by `schema_version` appearing four times with the other three fields absent, and cannot fail in practice | Four separate assertions scoped to the state-field table |

## Class F -- `check_state_unchanged` has no self-defence

| ID | Sev | Site | Defect | Fix |
|---|---|---|---|---|
| L4-F1 | P1 | `_harness.sh:131-158`; call sites `wave6:2431-2434` | Two vacuous-pass modes in the helper: `_harness_hash_file` returns the literal `absent` for a missing file, so a typo'd path compares `absent` to `absent` and reports PASS (49 call sites, each with a hand-built path); and `"$@" >/dev/null 2>&1 \|\| true` discards the exit code and all output, so it passes whether the command refused as intended, was not found, or died on a syntax error. The four genuinely read-only sites have no call-site control, and `list --paths` has no output assertion anywhere | Guard `[[ -f ]]` and fail explicitly; expose the exit status, or add `check_refuses_and_leaves_state` combining `check_fails` with the hash comparison -- what 45 of the 49 sites actually want. Precede the four read-only sites with an output assertion |

## Class G -- suite-level structure

| ID | Sev | Site | Defect | Fix |
|---|---|---|---|---|
| L4-G1 | P2 | `wave7-smoke.sh:3009-3014` | The shared-lint invariant ("nothing between here and T48 may mutate the tree or change EDM_SRD_ROOT/cwd") is enforced by a comment only, and five ticket blocks depend on it | Re-hash cwd + `EDM_SRD_ROOT` + a `git status --porcelain` fingerprint before the T48 block and assert it matches |
| L4-G2 | P2 | `wave7-smoke.sh:167`, `:1646-1846` | `neg_case_bogus_key` copies the whole live tree into `/tmp` on every run and a `cp -R` failure kills the suite; `T43_SCRATCH` spans 200 lines with a bare `rm -rf` and no trap. No cross-suite order dependence found | `trap 'rm -rf "$T43_SCRATCH"' EXIT` on creation |
| L4-G3 | P2 | `evals/tiering-matrix.sh:207-231` | The `--self-test` covers 90%, 100% and 70%, so changing `>= 80` to `> 80` passes all three unchanged. This is the single mechanical rule that will retier 15 opus/max agents and its only numeric boundary has no test. Separately `recall_pct` is a bare count ratio while the docstring emphasises specific-finding comparison, and nothing pins the distinction | Add agents at exactly 80% (QUALIFY) and 79% (DISQUALIFIED), plus one matching count with different P2 IDs asserted to qualify with a comment saying that is deliberate |
| L4-G4 | P2 | `evals/tiering-matrix.sh:254-259` | `run_matrix "$MANIFEST"; exit 0` -- an empty agents array or a jq error produces no output and exit 0, claiming a table for no table. Only `--self-test` is exercised | Assert at least one `DECISION` line before exiting 0; add a real-path case |

## Noted / Not Actionable

- `_harness.sh:51-101` `with_scratch_repo` -- trap save/restore correct for the documented depth-1 constraint; `harness-smoke.sh:37-92` covers normal return, failing return and SIGINT with bounded polls. Genuinely good.
- `wave7-smoke.sh:3445-3457` -- the non-ASCII positive control is the correct pattern and the model Class A should be rewritten against.
- The BLOCKED-ON-OWNER blocks (`wave7:2570-2578`, `:2643-2649`, `:2844-2847`, `:3328-3334`, `:973-975`) -- recording an unmet precondition honestly rather than faking a PASS is correct; only T54/T56's are actionable now, filed as L4-D1/D2.
- `wave6:3390` -- `check_state_unchanged` after `check_fails` on the same argv, correctly controlled by adjacency. Cited as the pattern the four uncontrolled sites should adopt.
- `wave7:3204-3210` and `:3293-3311` -- both rewritten today, both now assert properties. Confirmed fixed.
- `wave4a-smoke.sh`, `wave5-smoke.sh` -- overwhelmingly real behavioural assertions with expected values. `wave5:129-130`'s chain is confusing but correct because `fail()` returns 0.
- `run-all.sh:22-48` -- glob discovery with the preferred order as a documented sort hint is sound; the gaps are in result accounting, not discovery.

## Not examined
`evals/run-eval.sh` (read only via callers; spends live API budget, invoked by no suite). `bin/tests/timing.sh` (308 lines) -- surfaced only through two assertions that it is executable and its usage names `generate-fixture`; its seven measurement modes are verified by nothing and the script was not read. `wave6-smoke.sh:800-2600` sampled at the T06/T09/T11/T12/T14/T28/T32/T62/T64 blocks rather than read end to end -- findings from that range are complete with respect to the greps used, but Class B may have further instances only a full read would surface.
