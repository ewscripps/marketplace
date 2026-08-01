# Code Audit Lens L4: Test Quality

- **Date**: 2026-07-31 | **Round**: pass-2 (full, 11 lenses) | **Branch**: `edm/edmv3-prompt-streamline`
- **Method**: every L4-tagged round-1 finding re-checked against the current tree at its cited
  site (line numbers re-derived, not trusted from the ledger), then a fresh pass over
  `bin/tests/`, `bin/_edm-lint-lib.sh`, `evals/`, `run-all.sh`, `_harness.sh` and the fixture
  corpora. The prior ledger's `status` field was ignored entirely.
- **Note**: no Bash tool was available, so every claim below is derived from file contents and
  static analysis of the shell/regex semantics, not from executing the suite.

**Totals: P0 = 1, P1 = 3, P2 = 11, NOTED = 9. Confirmed fixed this round: 5.**

---

## Verification of round-1 L4 findings

| ID | Round-1 sev | Verdict now | One-line evidence |
|---|---|---|---|
| CA-002 | P0 | **still open** | no test anywhere invokes `update-patterns` on a novel finding |
| CA-016 | P1 | **partially fixed** | CRASH/zero-assertion/no-summary branches landed; no suite-count floor |
| CA-035 | P1 | **partially fixed** | B1/B2 fixed; **B3 now a demonstrable false positive**; B4 unfixed |
| CA-036 | P1 | **FIXED** | all 49 `grep -c` assignments guarded or routed through `count_matches` |
| CA-037 | P1 | **partially fixed** | 3 of ~24 sites controlled; the load-bearing one is correct |
| CA-038 | P1 | **partially fixed** | clean direction only; no indented-*mermaid*-violation fixture |
| CA-039 | P1 | **partially fixed** | dims 3/4 now execute; still zero expected-value assertions |
| CA-040 | P1 | **still open** | zero occurrences of `convergence_exempt` in `bin/tests/` |
| CA-041 | P1 | **FIXED** | frozen-vs-override asserted for all three families + mispricing pinned |
| CA-042 | P1 | **partially fixed** | missing-file half fixed and tested; exit code still discarded |
| CA-043 | P1 | **FIXED** | the `git log` assertion is gone; T34 asserts tree state only |
| CA-045 | P2 | **L4 share fixed** | `wave7:19` trap added; `T43_SCRATCH` now under `${TMP}` |
| CA-099 | P2 | **still open** | the nine `in layout` needles at `wave4b:57-65` are unchanged |
| CA-100 | P2 | **partially fixed** | loop added but passes on a deleted job; self-contradiction remains |
| CA-101 | P2 | **not re-verified** | see "Not examined" |
| CA-102 | P2 | **partially fixed** | E4 fixed; E2's hardcoded line range persists at a fresh site |
| CA-103 | P2 | **FIXED** | `wave7:3413-3421` re-hashes cwd + `EDM_SRD_ROOT` + porcelain |
| CA-104 | P2 | **FIXED** | 80/79 boundary + real-path case + `die` on empty output |

---

## Findings (L4: Test Quality)

### CA-002 (P0, still open) -- `cmd_update_patterns`' rewritten insertion path has zero runtime coverage; the prescribed test was never written

**Sites**: `plugins/edm/bin/edm-state:3676-3716` (`_splice_pattern_file`, `_cmd_update_patterns_body`),
`:3643-3661` (`pattern_insert_line_for`), `:3619-3624` (`pattern_target_heading_for`),
`:3663-3674` (`_render_pattern_entry`), `:3766-3769` (not-writable skip), `:3778-3781`
(missing-heading skip). Only test: `plugins/edm/bin/tests/wave7-smoke.sh:1607-1630`.

The function was substantially rewritten since round 1 -- it now routes through
`with_state_lock "${pattern_file%.md}"` (`:3790`) and a new `write_atomic "$pattern_file"
_splice_pattern_file` (`:3712`). **None of that new code executes in any test.**

The only test that invokes the subcommand at runtime is `t42_ac9_case`:

```bash
1619:  out="$(edm-state update-patterns ZMER srd 2>&1)"
1622:  [[ "$out" == *"no novel findings to append"* ]] \
```

It seeds a deliberately duplicate title (`:1615`), so `new_findings` stays `0` and the entire
`if [[ "$new_findings" -gt 0 ]]` block at `:3705-3713` -- insertion-line computation, the splice,
`write_atomic`, the `pending-review` entry render -- is never entered. An implementation with an
empty `_splice_pattern_file`, a `pattern_insert_line_for` that always returns `0`, or a
`write_atomic` that silently no-ops passes this test unchanged.

The prescribed scratch-copy also did not land. `:1609` and `:1620` hash
`${PLUGIN_DIR}/docs/audit-patterns/srd-audit.md` -- committed plugin source -- and `:1619` calls
bare `edm-state`, so `cmd_update_patterns`' `$0`-relative resolution (`:3728-3736`) points
`pattern_file` at the live document. `with_scratch_repo` redirects cwd, `EDM_SRD_ROOT` and PATH
but not `$0`, so **if de-duplication regresses this test writes into committed plugin source**,
and because the target is the second `##` heading, `_t56_four_heading_contract_check`
(`wave7:2733-2790`) would not catch it either.

`wave7:1003-1004` is not coverage: it greps `$(cat "$EDM_STATE")` for the literal string
`write_atomic "$pattern_file" _splice_pattern_file`. It proves the call site is spelled that way
in the source file, nothing about behaviour.

Still uncovered: the insertion itself, the `pending-review` Append Schema block, the atomic `mv`,
the `---` back-up in `pattern_insert_line_for`, the last-section EOF case, the missing-heading
SKIP whose contract is "never fall back to EOF" (`:3707-3711` and `:3778-3781` -- two separate
copies of the skip, neither exercised), the not-writable skip, `pattern_target_heading_for`, and
idempotence across a second run.

Compounding: `wave7:2632-2640` still prints the T54 BLOCKED-ON-OWNER block claiming AC1-AC12
"require the insertion-logic rewrite at `plugins/edm/bin/edm-state:1576-1692`, out of this batch's
file remit", and `wave7:2906` still records T56 AC8 the same way. The rewrite landed weeks ago;
the blocked-on-owner prose is now stale and reads as a live blocker, which is how this stayed
invisible.

**Fix**: unchanged from the round-1 prescription. Copy `bin/` and `docs/` into the scratch
directory and invoke the scratch binary as `t30_ac2_case` already does; one case with two novel
`###` headings plus a duplicate asserting exactly two entries appended, both carrying
`status: pending-review`, both inside `## Anti-Patterns`, `_t56_four_heading_contract_check`
clean afterwards, the duplicate skipped, and a second run appending nothing; a second case with
the target heading removed asserting the SKIP message and byte-identity. Then revert
`_splice_pattern_file` to `return 0` and confirm both cases fail. Delete the two stale
BLOCKED-ON-OWNER blocks in the same commit.

---

### CA-035 (P1, partially fixed -- B3 is now a demonstrable false positive) -- the T42 AC4 quoting-consistency assertion passes on a tree that violates it

**Site**: `plugins/edm/bin/tests/wave7-smoke.sh:1567-1571`.

The round-1 prescription ("widen the capture to the reference family, then count distinct forms")
was applied, but the widened regex is wrong in a way that inverts the test:

```bash
1568: t42_ac4_forms="$(grep -rho 'CLAUDE\.md Sec\.\\"*"*Mermaid diagram conventions\\"*"*' "${PLUGIN_DIR}/" 2>/dev/null | sort -u | wc -l | tr -d ' ')"
1569: [[ "$t42_ac4_forms" == "1" ]] && pass "T42 AC4 -- exactly one quoting form of the by-name reference is in use"
```

The pattern is single-quoted, so grep receives `\\` literally, and this is BRE (no `-E`): `\\` is
an escaped backslash matching **one literal backslash**, and `"*` then matches zero-or-more
quotes. The regex therefore *requires* a backslash immediately after `Sec.` and immediately after
`conventions`.

The live tree contains two distinct forms:

- unescaped (20 occurrences): `agents/edm-architect.md:31,89`, `agents/edm-srd-writer.md:34,83`,
  `agents/edm-ticket-writer.md:39,99`, `agents/edm-srd-auditor.md:38`,
  `agents/edm-ticket-auditor.md:63,134`, `skills/srd/SKILL.md:80`, `skills/tickets/SKILL.md:50`,
  `skills/audit-srd/SKILL.md:64`, `skills/audit-tickets/SKILL.md:81,93`,
  `docs/audit-patterns/srd-audit.md:86,102`, `docs/audit-patterns/ticket-audit.md:81,96`,
  `bin/tests/fixtures/mermaid/valid/v01-entity-codes.md:4`
- backslash-escaped (1 occurrence): `plugins/edm/skills/srd/SKILL.md:182` --
  `Follow CLAUDE.md Sec.\"Mermaid diagram conventions\" for label text`

Only the single deviant line matches, `sort -u | wc -l` is `1`, and the suite reports PASS. The
argument is airtight regardless of how one reads the BRE: if the regex matched both forms the
count would be `2` and the suite would be red; the suite is green, so it matches only one form --
and the tree provably contains two. **The assertion whose entire purpose is "identical quoting
style across every by-name reference" is blind to 20 of the 21 references and currently reports
green over a real violation.**

Status of the other three CA-035 sub-items:

- **B1 -- FIXED.** `wave6-smoke.sh:3459-3467` replaced the empty expected substring with an
  explicit `case "$t52_attr_mode" in scoped|whole-directory)`.
- **B2 -- FIXED.** `wave6-smoke.sh:3473-3477`'s fallback branch now asserts
  `[[ "$t52_input" -eq 101000 ]]`, exactly the prescribed honest whole-directory total.
- **B4 -- NOT fixed.** `wave7-smoke.sh:476-480` is still the self-consistency identity: the jq
  filter recomputes `(sum / dimensions_scored * 10 | round) / 10` and compares it to `.total`.
  It cannot detect a wrong dimension score, a wrong sign, a swapped dimension or a scorer
  returning 0 for everything. Folded into CA-039 below.

**Fix (B3)**: drop the backslash requirement and count the family, e.g.
`grep -rhoE 'CLAUDE\.md Sec\.\\?"?Mermaid diagram conventions\\?"?'`; then either normalise
`skills/srd/SKILL.md:182` to the unescaped form or record it as an intentional carve-out in the
assertion. Verify by asserting the count is `1` *and* that the count of raw matches is >= 11, so
"matched nothing" and "matched only one file" are distinguishable from "one consistent form".

---

### CA-039 (P1, partially fixed) -- three scorer dimensions now execute, but not one of the five carries an expected-value assertion, so an inverted dimension still scores 100 for every input

**Sites**: `plugins/edm/evals/score-artifacts.sh:203-238` (dim 2), `:240-361` (dim 3),
`:363-...` (dim 4); fixture and assertions at `plugins/edm/bin/tests/wave7-smoke.sh:436-486`.

Genuinely improved: the synthetic fixture gained a mermaid block (`wave7:443-446`) and an
`audit-srd.md` (`:448`), and `:471-474` asserts `.dimensions[0..3].score != null`. Dimensions 3
and 4 are no longer dead code -- that half of round-1 D4/D6 is closed.

What did not land, and why it still matters:

1. **No expected value anywhere.** Every dimension assertion is either `!= null` (`:471-474`) or
   the self-consistency identity (`:476-480`). The prescribed
   `.dimensions[N].score == <hand-computed literal>` assertions do not exist.
2. **The vague-AC detector's polarity is still untested.** The fixture's single AC (`:441`,
   "A concrete, testable behavior with a specific numeric threshold") is deliberately not vague,
   so `vague_count` at `score-artifacts.sh:233` is `0` on every run. An empty
   `vague-ac-patterns.txt`, a malformed regex, or a `grep -icE -f` that fails still yields
   `D2_SCORE = 100`. `wave7:519-520` only asserts the pattern file is non-empty.
3. **Dimension 3 only ever sees a valid diagram.** `_scan_mermaid_blocks` (`:248-335`) is invoked
   on one well-formed `flowchart TD`, so a version that unconditionally prints `OK` scores 100.
   The committed `bin/tests/fixtures/mermaid/invalid/` corpus is never fed to the scorer, and
   nothing tests `score-artifacts.sh`'s awk against `_edm-lint-lib.sh`'s over a common corpus --
   two independent implementations of the same rule with no cross-check.
4. **Dimension 4 only exercises the forward direction.** `run-dir/audit-srd.md` (`:448`) names
   `TSVE-01`, a real requirement. Nothing in the fixture names a *fabricated* ID, so the reverse
   half of the bidirectionality check -- the only thing distinguishing dimension 4 from dimension
   1's forward-only coverage-mention check (`score-artifacts.sh:182-193`) -- never runs.

**Fix**: Add a second, vague AC and assert `.dimensions[1].score == 50`; assemble a
second `srd.md` from `bin/tests/fixtures/mermaid/valid/*` and assert dimension 3 == 100, then from
`invalid/*` and assert < 100; add a fabricated `TSVE-99` to `audit-srd.md` and assert dimension 4
against the hand-computed value. Replace `wave7:476-480` with literal expected scores.

---

### CA-040 (P1, still open, unchanged) -- `convergence_exempt`'s whole reason to exist is still untested

**Site**: `plugins/edm/bin/edm-state:687-704` (definition), consumers at `:2131` and `:3196`.

`grep -rn 'convergence_exempt' plugins/edm/` returns six hits in `bin/edm-state` and one in
`CHANGELOG.md:64`. **Zero hits in `bin/tests/`.** No test covers the `lifecycle_mode` half at
either consumer, the `mode == "null"` legacy branch, or -- most importantly -- the deliberate
asymmetry that `approve-gate code-audit` stays refused under `fast-track` while archive and
audit-converged become exempt. A future edit routing `approve-gate` through the helper "for
consistency" opens a gate bypass and nothing fails.

**Fix**: unchanged -- three cases per consumer across the four `mode`/`lifecycle_mode`
combinations, plus one asserting `approve-gate code-audit` still refuses under `fast-track`.

---

### CA-016 (P2 residual, partially fixed) -- the aggregator has no minimum-suite-count floor, so deleting a suite reports ALL SUITES PASSED

**Site**: `plugins/edm/bin/tests/run-all.sh:22-30`, `:60-114`.

Three of the four prescribed items landed and are correct:

- `:92-95` -- non-zero status with no parsed summary prints `CRASH ${_suite}` and contributes
  `_s_fail=1` (`:91`, summed at `:113`).
- `:96-99` -- status 0 with no parsed summary fails, naming the suite.
- The second parser branch is gone; `wave4b-smoke.sh:175` now emits the six-suite
  `Results: N passed, M failed` format, matching all seven suites, so `:65` is the only parser.
- `:77-80` -- a per-suite floor of one assertion (a suite reporting `0 passed, 0 failed` now
  fails).

Not landed: **the minimum suite count.** `:27-30` fails only when *zero* `*-smoke.sh` files are
discovered. `_PREFERRED_ORDER` (`:19`) names seven suites but is documented as a sort hint only
and gates nothing. Delete or rename `wave7-smoke.sh` -- ~830 assertions, the largest suite -- and
`run-all.sh` discovers six, reports `ALL SUITES PASSED`, and exits 0. Every AC of the form
"Verify: `bash plugins/edm/bin/tests/run-all.sh`" rests on this.

**Fix**: assert every name in `_PREFERRED_ORDER` was discovered (fail naming any that were not),
and assert `${#_run_order[@]} -ge 7`.

---

### CA-037 (P2 residual, partially fixed) -- three of roughly two dozen zero-count assertions now carry a positive control

**Fixed, and fixed exactly as prescribed:**

- `wave7-smoke.sh:177-184` -- the `--force` absence check, the single most load-bearing product
  invariant, now routes through the new `assert_absent_with_control` (`_harness.sh:140-149`) with
  `bin/vocabulary-prohibited.txt` as the control haystack. The control's own content is
  independently pinned at `wave7:1367` (`check ... "literal:--force"`), so the control cannot go
  hollow silently. This is the model the class should be rewritten against.
- `wave7-smoke.sh:285-293` -- the `^agent:` zero-count is now controlled by `T03_AC6_OUT`, the
  output of the injected-failure case at `:253-284`. Exactly the prescribed "make the negative
  case the control".
- `wave7-smoke.sh:951-959` -- T58 AC1 gained a control asserting the same needle still matches
  under `agents/`, with a comment explaining why.

**Still uncontrolled** (a repo-wide grep for "positive control" finds only four sites in the
entire suite, `_harness.sh:143` included):

| Site | What goes permanently green |
|---|---|
| `wave6:2430-2432` | The **duplicate** `--force` check. Not collapsed into `assert_absent_with_control` as prescribed. `command grep -c ... 2>/dev/null \|\| true` yields `""` on a bad `$EDM_STATE`; `${t62ac10_force:-0} -eq 0` then passes |
| `wave6:2427-2429` | `EDM_SKIP\|EDM_FORCE\|SKIP_CHECKS` `-z` check over `bin/` -- a typo in any alternative passes |
| `wave7:862-866` | T21 AC5 wave-token count. The prescribed "assert the file is non-empty; control the regex against the literal `wave7-smoke.sh`" was not done |
| `wave7:964-975` | Three T66 AC4 deleted-text zero-counts. The prescribed pinning against `CHANGELOG.md` was not done |
| `wave7:355-357` and `wave7:1026-1029` | The duplicate `code_audit_converged true` absence checks. Neither controlled, neither removed; a key rename makes both vacuous |
| `wave7:336-338` | `grep -cE '(^\|[^a-zA-Z_])(mapfile\|readarray)[[:space:]]'` still requires trailing whitespace, so `mapfile<f` never matches, and no probe proves the regex can fire. (`:736` and `:1891` dropped the trailing-space requirement; this one did not.) The prescribed shared heredoc probe was not added |
| `wave7:1386-1389` | T30 AC10 override-flag `-z` |
| `wave7:2164` | T34 AC5 `check_absent "EDMV3-T34"` |

**Fix**: route the remaining sites through `assert_absent_with_control`; where no natural control
exists, add the one-line comment naming the adjacent control, as `wave7:951-955` now does.

---

### CA-038 (P2 residual, partially fixed) -- only the clean direction of the fence-indentation fix is tested; reverting the detection half keeps the suite green

**Sites**: `plugins/edm/bin/_edm-lint-lib.sh` (relocated `build_line_classes`);
fixture `plugins/edm/bin/tests/fixtures/mermaid/valid/v12-indented-fence.md`; assertions at
`wave7-smoke.sh:1944-1945`, `:1960-1961`.

The valid direction landed: `v12-indented-fence.md` places a three-space-indented ```` ```text ````
fence containing `Co-Authored-By: Example Person <example@example.com>` under a numbered step and
asserts the corpus stays clean.

The second prescribed fixture did not land. `bin/tests/fixtures/mermaid/invalid/` still contains
only `i01`-`i05`, every one with a column-0 fence. `plugins/edm/CHANGELOG.md:46` records the bug
as two-sided -- "the contents of an indented plain fence, **and missed violations inside an
indented mermaid fence**". Only the first half is pinned. Revert the de-indentation in the
mermaid-scan path and the suite stays fully green.

The em-dash half of the prescribed valid fixture is also missing: `v12` carries only the
attribution trailer, so class 2 (`unicode`) suppression inside an indented fence is untested.

**Fix**: add `bin/tests/fixtures/mermaid/invalid/i06-indented-mermaid-label.md` -- an indented
```` ```mermaid ```` fence with a raw `;` inside a `[...]` label plus the `expected-line:` marker
the corpus convention uses -- and add an em dash to `v12`.

---

### CA-042 (P2 residual, partially fixed) -- `check_state_unchanged` still discards the command's exit code and output across ~49 call sites

**Site**: `plugins/edm/bin/tests/_harness.sh:168-184`.

The first vacuous-pass mode is fixed and, correctly, tested: `:173-176` fails explicitly when the
baseline hashes to the literal `absent`, and `harness-smoke.sh:125-130` adds the negative case
proving it (`PASS=0 FAIL=1`).

The second is unchanged:

```bash
177:  "$@" >/dev/null 2>&1 || true
```

The helper still passes identically whether the command refused as intended, was not found, or
died on a syntax error. `grep -rn 'check_refuses_and_leaves_state' plugins/edm/` returns nothing --
the prescribed combined helper (what 45 of the 49 sites actually want: "refused AND left state
alone") was not added. The four genuinely read-only sites still have no preceding output
assertion, and `list --paths` still has no output assertion anywhere.

`harness-smoke.sh:116` (`check_state_unchanged "$STATE_TMP" true`) is itself the illustration: the
command under test is `true`, so the case cannot distinguish the two behaviours.

**Fix**: unchanged -- add `check_refuses_and_leaves_state <label> <expected-msg> <state-file>
<cmd...>` combining `check_fails` with the hash comparison, convert the 45 must-refuse sites, and
precede the four read-only sites with an output assertion.

---

### CA-099 (P2, still open) -- the nine CLAUDE.md "in layout" assertions are unchanged and still prove only that a filename appears somewhere in a 1000-line file

**Site**: `plugins/edm/bin/tests/wave4b-smoke.sh:57-65`.

```bash
57: check "architecture.md in layout" "architecture.md" "$CLAUDE_MD"
...
65: check "pass-{N}_ in layout" "pass-{N}_{YYYY-MM-DD}/" "$CLAUDE_MD"
```

`$CLAUDE_MD` is the whole file. Each label claims the artifact is documented *in the layout
block*; the assertion establishes only that the token occurs somewhere in a document that also
contains a CI table, a state-field table, a pricing table and a mode matrix. Moving
`architecture.md` out of the layout tree and mentioning it once in prose keeps all nine green.
`_wave7_extract_section` (`wave7:2973`) exists for exactly this and is not used here.

**Fix**: extract the fenced layout block once and assert each token against that string. The
other eight short-needle sites named in round 1 (`mode`, `P0`, `AskUserQuestion`, `tdd`, `TDD`,
`escalate`, `qc/`, `set-mode`) were not individually re-verified this round -- see "Not examined".

---

### CA-100 (P2, partially fixed) -- the four-job lint-split loop passes on a job that does not exist, and the suite still contradicts itself about whether the split landed

**Sites**: `plugins/edm/bin/tests/wave7-smoke.sh:1014-1021`, `:3402-3403`.

Landed: `:1015` iterates the four names, `:1016` extracts each job's block, `:1019-1021` asserts
none carries `allow_failure`. `:1022` adds the `--lenses` assertion that CA-004's remediation note
folded into this finding.

Not landed, and load-bearing:

```bash
1016:  t66_job_block="$(awk -v job="^${t66_job}:$" '$0 ~ job {f=1;next} f && /^[^[:space:]][^#]*:$/ {f=0} f' "$GITLAB_CI_YML")"
1017:  [[ "$t66_job_block" == *"allow_failure"* ]] && t66_lint_allow_fail="${t66_lint_allow_fail} ${t66_job}"
```

A job that is absent from `.gitlab-ci.yml` yields an **empty** `t66_job_block`, which contains no
`allow_failure`, and is therefore scored compliant. Delete `lint:vocabulary` from the pipeline
entirely and this assertion still passes. Contrast `:1012-1013`, which do prove existence for
`validate:plugin-cli` and `eval:nightly` by asserting a positive substring. Also absent: the
prescribed assertions that the four jobs are in the `lint` stage and that the union of their
scripts still names all four checkers.

The self-contradiction also survives, relocated. `wave7:3402-3403` prints as suite output:

> `AC10 is a recorded, unfixed gap (decisions.md D26): the four lint checks run as`
> `sequential script lines in one job, not four parallel jobs.`

while `:1015` and `:3383` both enumerate the four split jobs as live, and `plugins/edm/CLAUDE.md`'s
CI table documents the split as landed with `needs: []`. Because `:3402-3403` is an `echo`, not an
assertion, it cannot fail -- it is stale prose that reads as an honest gap record and is now false.

**Fix**: assert each block is non-empty before testing it; assert `stage: lint`; assert the union
of the four scripts names `bash -n`, `edm-lint-artifacts`, `edm-check-grants` and
`edm-check-vocabulary`; delete `:3402-3403`.

---

### CA-102 (P2 residual, partially fixed) -- hardcoded absolute line ranges persist while the helper written to replace them is used at one site

**Fixed**: the E4 alternation count is gone. `wave7:978-981` now loops
`for t66_field in schema_version enforcement round_type closing_verdict` with four separate
`check` calls -- exactly the prescribed four scoped assertions.

**Still open**: `wave7-smoke.sh:372`

```bash
372: T15_STEP10="$(sed -n '69,106p' "$CODE_AUDIT_SKILL")"
```

A hardcoded absolute line range into `skills/code-audit/SKILL.md`, a file other tickets edit
freely; an insertion above line 69 silently changes what the three following assertions
(`:373-375`) examine. `_wave7_extract_section` (`:2973-2980`) was added for precisely this and is
called at exactly one site in the whole suite (`:3004`).

Drift-prone literals also remain at `wave7:987-989` (`-eq 30` agent files), `:990-992` (`-eq 14`
skills) and `:327-328` (`-eq 30` again), none naming a source of truth in the failure message.
`:324-326` is the counter-example and does it right (documented-vs-disk).

**Fix**: replace the `sed -n` range with `_wave7_extract_section`; name the source of truth in the
three literal-count failure messages.

---

### NEW (P2) -- the nine-blocking-job network scan has the same delete-a-job blind spot

**Site**: `plugins/edm/bin/tests/wave7-smoke.sh:3383-3395`.

```bash
3386:  t67_job_body="$(awk -v job="^${t67_job}:$" '...' "$GITLAB_CI_YML")"
3391:  echo "$t67_job_body" | grep -qE 'curl |wget |anthropic\.com' && t67ac11_net_hits="..."
```

Same shape as CA-100: a job missing from `.gitlab-ci.yml` produces an empty body, matches no
network pattern, and is scored clean. Delete `test:smoke` or `lint:shellcheck` from the pipeline
and "no blocking job's script calls curl/wget/anthropic.com" still passes -- while the far more
consequential fact that a blocking job vanished goes unreported. Round 1 did not cite this site.

**Fix**: fail explicitly when `t67_job_body` is empty, naming the job.

---

### NEW (P2) -- the two new shared harness helpers have no self-test, and `count_matches` converts an unreadable path into the passing value

**Sites**: `plugins/edm/bin/tests/_harness.sh:132-136`, `:140-149`;
`plugins/edm/bin/tests/harness-smoke.sh:2-3`.

`count_matches` and `assert_absent_with_control` are the remediation vehicles for CA-036 and
CA-037 respectively and are now relied on at 21 sites across `wave6` and `wave7`.
`harness-smoke.sh`'s header still enumerates only "with_scratch_repo, check_fails,
check_state_unchanged", and neither new helper has a positive or negative case. A regression in
either silently weakens every site that routes through it -- including the `--force` invariant,
whose control is `assert_absent_with_control`'s first branch.

Worse, `count_matches` re-introduces the class it was written to remove, at the "expect zero"
sites:

```bash
134:  count="$(command grep -c "$@" 2>/dev/null)" || count=0
```

`2>/dev/null` plus `|| count=0` collapses "file not found" (grep exit 2) and "no matches" (exit 1)
into the same value. For a caller asserting `-gt 0` that is a correct failure; for a caller
asserting `-eq 0` (e.g. `wave7:3223-3225`) an unreadable or renamed path is indistinguishable from
the invariant holding. The helper's own header comment claims only the crash-avoidance property
and does not warn about this.

**Fix**: add positive/negative cases for both helpers to `harness-smoke.sh` (including one proving
`assert_absent_with_control` fails when the control haystack lacks the needle, which is its whole
point), and either split `count_matches` into a strict variant that fails on grep exit 2, or
document the caveat in its header and require "expect zero" callers to pair it with a control.

---

### NEW (P2) -- `run-all.sh`'s own result accounting is covered by no test

**Site**: `plugins/edm/bin/tests/run-all.sh:60-114`.

This is the accounting layer every "Verify: `bash plugins/edm/bin/tests/run-all.sh`" AC rests on,
and it was substantially rewritten by CA-016's remediation (three new branches: CRASH, zero
assertions, exit-0-without-summary). Nothing tests it. `run-all.sh` is not itself a `*-smoke.sh`
file so it never self-discovers; `harness-smoke.sh` has no case for it; `wave7:339-340` only greps
run-all.sh's **text** for the string `edm-check-grants`. The REMEDIATION plan's verification for
CA-016 ("insert `exit 1` at the top of a suite and confirm the aggregate reports CRASH") was a
manual step, and manual verification of an accounting layer is exactly what leaves it free to
regress.

**Fix**: add a `harness-smoke.sh` case that copies `run-all.sh` into a scratch directory alongside
three stub suites -- one green, one printing `Results: 0 passed, 1 failed` and exiting 1, one
exiting 1 with no summary line -- and asserts the aggregate prints `CRASH`, names each failing
suite, and reports a non-zero `Total: ... failed`.

---

### NEW (P2) -- `timing.sh`'s seven measurement modes are covered by one grep for a single token

**Sites**: `plugins/edm/bin/tests/wave7-smoke.sh:3342-3348`; script at
`plugins/edm/bin/tests/timing.sh` (308 lines).

```bash
3344: [[ -x "$TIMING_SH" ]] && pass "T67 AC14 -- bin/tests/timing.sh is executable"
3347: check "T67 AC14 -- timing.sh usage lists all seven measurement modes" \
3348:   "generate-fixture" "$(bash "$TIMING_SH" 2>&1 || true)"
```

The label claims seven modes; the assertion establishes that the usage text contains one token.
A `timing.sh` reduced to `echo generate-fixture; exit 0` passes both assertions. This is the
script that produces the committed latency numbers in `CHANGELOG.md`'s EDMV3-T67 table and the two
budgets documented in `plugins/edm/CLAUDE.md` ("`edm-lint-artifacts` latency budgets"), and
`wave7:3397-3403` explicitly declines to re-run the measurements in the suite. Round 1 listed
`timing.sh` under "Not examined", so this is a new finding rather than a re-raise.

**Fix**: assert all seven mode names appear in the usage text, and add one fast smoke case
invoking a single cheap mode against a tiny generated fixture and asserting it emits a parseable
millisecond figure.

---

## Noted / Not Actionable

- **CA-036 -- confirmed fixed.** Every `grep -c` in an assignment across `wave6`/`wave7` (49
  sites) now carries `|| true`, `|| echo 0`, or routes through `count_matches`. The four
  specifically named sites (`wave7:1652`, `:2146`, `:1458`, `:1567`, `:2048` in round-1
  numbering) resolve to `:1657`, `:2207`, `:1490`, `:1599-1600`, `:2111`, all guarded. The
  internal inconsistency round 1 flagged (`:2615` guarded while `:2146` was not) is gone.
- **CA-041 -- confirmed fixed, to the letter.** `wave6:3491-3505` asserts each frozen
  previous-generation output rate against an exact literal *and* that setting
  `EDM_{OPUS,SONNET,HAIKU}_OUTPUT_RATE=999` does not change it -- three families, not just opus.
  `wave6:3534-3547` pins the documented in-family mispricing: `claude-opus-5-20260501` warns
  naming the model, contains "WARNING", and prices at the `4.0000` Sonnet placeholder, while the
  legacy `unknown` sentinel stays silent. This is the best-executed of the round-1 test fixes.
- **CA-043 -- confirmed fixed.** The `git log ... | grep -c 'EDMV3-T34'` assertion is gone. The
  T34 block (`wave7:2126-2198`) now asserts tree state only (`:2164`). No `git log` assertion
  remains anywhere in `bin/tests/`; the only remaining mention is prose at `wave7:691` describing
  `watch-impl`. `wave7:3357-3361` records, in a comment, exactly why the equivalent
  `git diff --stat` assertion was replaced -- good practice worth keeping.
- **CA-103 -- confirmed fixed, to the letter.** `wave7:3413-3421` re-checks `pwd`,
  `EDM_SRD_ROOT`, and a `git status --porcelain` fingerprint against the values captured before
  the shared-lint block, with two separate assertions. Exactly the prescription.
- **CA-104 -- confirmed fixed, both halves.** `tiering-matrix.sh:244-293` adds
  `synthetic-agent-d-eighty-qualifies` (8/10 -> `recall_pct` 80.0, QUALIFIES) and
  `synthetic-agent-e-seventy-nine-disqualified` (7.9/10 -> 79.0, DISQUALIFIED). Changing
  `$pct >= 80` at `:90` to `> 80` now breaks agent-d, so the boundary is genuinely pinned.
  Agent-d's `P2-9`/`P2-10` are absent from its baseline yet it still qualifies, with `:283`
  stating that is deliberate -- the prescribed pinning of the recall-count-vs-specific-finding
  distinction. `run_matrix` now dies on empty output (`:127`) and on output containing no
  `DECISION` line (`:128`), and `:295-301` adds the real-path invocation case. The
  `--self-test` is wired into CI through `wave7:3466-3475`, which also asserts the `6/6` summary.
- **`total_findings: 7.9` at `tiering-matrix.sh:271`** -- a fractional finding count is not a
  state the real manifest can be in, so the "79 percent" case tests the arithmetic rather than a
  representable input. It does catch the `>=` -> `>` mutation, which is the point of the
  prescription, so this is a stylistic quibble rather than a defect. Preferable long-term:
  `baseline.total_findings: 100` with a candidate at `79`.
- **CA-035 B1/B2 -- confirmed fixed** (`wave6:3459-3467`, `:3473-3477`). The session-scoping
  regression the `100000`-vs-`1000` fixture exists to catch would now produce a real FAIL in
  either branch.
- **CA-045's L4-visible half -- fixed.** `wave7-smoke.sh:19` now carries
  `trap 'rm -rf "$TMP"' EXIT INT TERM`, and `T43_SCRATCH` is created under `${TMP}`
  (`:1678`), so the 200-line T43 block and its bare `rm -rf` at `:1903` are trap-covered.
  `_harness.sh:66` already had it. The remaining wave6 trees and the fake-`HOME` concern belong
  to L5/L7/L8 and are not re-adjudicated here.
- **`harness-smoke.sh:125-130`** -- the new negative case for the missing-baseline path is
  correct and is exactly what CA-042 asked for on that half. `:103-108` and `:118-123` use the
  same subshell-with-local-counters idiom, which is the right way to assert a helper's failure
  path without polluting the tally.
- **`wave7:3525-3535` and `wave6:2270-2276`** -- both pre-existing positive controls remain
  correct and remain the two best examples in the suite.
- **The `edm-check-grants` and `edm-check-skill-sync` invocations at `run-all.sh:116-148`** --
  real invocations with real exit-code assertions folded into the aggregate tally, not comment
  references. Sound.
- **`wave7:997-999`, `:3397-3401`** -- BLOCKED / measured-elsewhere records that are still
  accurate (the T48 lens retiering genuinely has not run; the T67 timing numbers genuinely are
  recorded in `CHANGELOG.md`). Recording an unmet precondition honestly rather than faking a PASS
  remains correct. The T54/T56 blocks at `wave7:2632-2640` and `:2906` are the exception and are
  filed under CA-002 because the precondition they name has since been met.

## Not examined

- **CA-101** (`strip_entities`' explicit 1..10 walk and the `(...)`/`{...}` valid counterpart) --
  the walk is present in both implementations (`evals/score-artifacts.sh:256-277` and the shared
  lint library), but I did not read `bin/_edm-lint-lib.sh` or the T43 scratch fixtures at
  `wave7:1679-1903` closely enough to say whether the two prescribed boundary lines were added.
  Reported as unverified rather than guessed.
- **CA-099's remaining eight short needles** (`mode`, `P0`, `AskUserQuestion`, `tdd`, `TDD`,
  `escalate`, `qc/`, `set-mode`) -- only the nine "in layout" checks at `wave4b:57-65` were
  re-read. Those nine are confirmed unchanged.
- `evals/run-eval.sh` -- read only through its callers; spends live API budget and is invoked by
  no suite. Unchanged position from round 1.
- `wave6-smoke.sh:800-2400` -- sampled at the T07/T08/T13/T28/T59/T62 blocks rather than read end
  to end. Findings from that range are complete with respect to the greps used
  (`grep -c`, `-eq 0`, positive-control comments, `count_matches`), not with respect to a full
  read.

## Headline for the synthesizer

**CA-002 (P0) did not land at all.** The prescribed insertion-logic test was never written; the only runtime invocation of `update-patterns` in the entire suite is the de-duplication case at `plugins/edm/bin/tests/wave7-smoke.sh:1607-1630`, which drives `new_findings` to `0` and never enters the write path. Both stale BLOCKED-ON-OWNER blocks (`wave7:2632-2640`, `:2906`) still claim the owner's code has not landed, which is how it stayed invisible.

**One new P1 false positive was introduced by the round-1 remediation itself.** `wave7-smoke.sh:1568`'s widened regex requires a literal backslash (BRE `\\`), so it matches only the one deviant reference at `plugins/edm/skills/srd/SKILL.md:182` and reports "exactly one quoting form" over a tree containing twenty unescaped references plus that one. Green suite, violated invariant.

Five findings are genuinely fixed to the letter of the prescription (CA-036, CA-041, CA-043, CA-103, CA-104); five are partially fixed with a smaller residual (CA-016, CA-037, CA-038, CA-039, CA-042); two are untouched (CA-040, CA-099).
