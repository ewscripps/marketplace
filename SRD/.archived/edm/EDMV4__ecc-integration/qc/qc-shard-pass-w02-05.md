# QC Audit Report: EDMV4 -- ECC Integration, Wave 2 [Shard 5/5]

**Date**: 2026-09-04
**Tickets audited**: `EDMV4-T11`, `EDMV4-T39`, `EDMV4-T40` (3 of 3 assigned)
**Tree audited**: `edm/edmv4-ecc-integration` @ `581db12`, main working tree (no worktree). The one
uncommitted change (`.edm-state.json`) is a `checkpoint-if-active` findings-ledger hash written at
`2026-09-05T03:10:50Z` and is unrelated to all three tickets -- confirmed by diff, and relevant
because `T40` AC8 asserts this exact file is never written by the code under audit.

Commissioned to close code-audit finding CA-006. None of these three carried an acceptance-criteria
verdict in any existing shard; each appears in the earlier shards only as incidental prose.

## Wave placement

All three are **wave 2**, established from the ticket pack and from `git log` on their Target
Components, not assumed:

- `EDMV4-T11` -> `709f745` "EDMV4-T11 build edm-gateguard and register its PreToolUse matcher block",
  2026-09-02 16:27.
- `EDMV4-T39` and `EDMV4-T40` -> `1a4c5f1` "EDMV4-T39/T40 six-category repo-readiness rubric wired to
  edm-state", 2026-09-02 16:27, one commit for both (they share a single Target Component,
  `bin/edm-repo-readiness`).

Both commits sit inside the wave-2 implementer batch (`23ebe0b` 16:04 through `bd582cc` 16:48),
after the wave-1 shard merge (`47811c9` 15:53) and before the wave-2 close (`5aa5f51` 20:47) and the
four wave-2 QC shards (20:49-20:51). The pack agrees: `T11` is Phase 2 and depends on `T06`/`T07`/
`T10`/`T17`, all of which landed in wave 1; `T39`/`T40` are Phase 3 and both depend on `T38`, which
landed in wave 1 (`1f3eb94`, 13:22). Ordinals `w02-01` through `w02-04` are taken, so this is
`w02-05`.

## Summary

| Ticket | Title | Verdict |
|---|---|---|
| `EDMV4-T11` | Build `bin/edm-gateguard` and register its `Edit`/`Write`/`MultiEdit` matcher block | **FAIL** |
| `EDMV4-T39` | Implement the six-category rubric with 0-10 normalization and a version constant | **FAIL** |
| `EDMV4-T40` | Wire the scorecard to the readiness signals EDM already computes | **FAIL** |

**Totals**: 0 PASS, 0 PARTIAL, 3 FAIL, across 33 acceptance criteria (30 PASS, 3 FAIL). Three FAIL
findings (2 P1, 1 P2) plus three P2 observations.

All three verdicts are FAIL on a single AC each, and in every case the surrounding implementation is
sound -- these are not broken features. Two of the three are the same shape: **an acceptance
criterion's own mandated mechanism was quietly relaxed or never built, while the substantive
property it was meant to protect happens to hold today.** That is precisely the class this
initiative has already filed four findings against, so it is graded as FAIL rather than waved
through on the strength of the working code around it.

Every behavioral claim below was executed. `bash plugins/edm/bin/tests/run-all.sh` was run to
completion by this audit: **3289 passed, 0 failed across 8 suites, exit 0**, under `/bin/bash`
3.2.57(1)-release on macOS Darwin 25.6.0. `bash plugins/edm/bin/tests/timing.sh --gateguard` and
`bash plugins/edm/bin/edm-repo-readiness` were each run directly. Nothing below is carried forward
from a ticket's own assertion.

---

## Detailed Findings

### `EDMV4-T11`: Build `bin/edm-gateguard` and register its matcher block -- FAIL

- [x] **AC1** -- `bin/edm-gateguard` exists, `test -x` passes, `wc -l` is **447**.
      **Graded against 200-500, not the ticket's literal 200-400**, because `decisions.md` D42
      (2026-09-03) raised the ceiling with a recorded rationale after `T52`'s AC6-mandated
      sanitization pushed the file past 400: the band was sized in Phase 2 for a structural port
      that five later tickets (`T13`, `T14`, `T15`, `T45`, `T52`) each added AC-required code to.
      The bound was **widened, not removed** -- `wave8-smoke.sh:3304-3309` asserts the closed range
      200-500 and carries D42's reasoning at the assertion (`:3291-3303`), which is what D42 itself
      required of the next ticket needing more. 447 is inside. See the P2 observation below on the
      un-swept ticket text.
- [x] **AC2** -- `:51` sources `_edm-cli-lib.sh`; `usage()` at `:61-64` calls
      `print_help "${BASH_SOURCE[0]:-$0}"`; the sentinel block spans `# EDM-HELP-BEGIN` (`:16`) to
      `# EDM-HELP-END` (`:47`). `grep -c "sed -n '"` over the script returns **0**, and
      `wave8-smoke.sh:3316` asserts that absence. The needle is real, not invented: `sed -n '` is
      live code at `bin/edm-check-verifier-sentinel:102-104` and is named as the banned form in
      `bin/edm-state:3,176`, `bin/edm-lint-artifacts:3` and `bin/_edm-cli-lib.sh:14`, so
      `check_absent` here is hunting a form this codebase actually uses elsewhere.
- [ ] **AC3** -- **FAIL**. See finding below.
- [x] **AC4** -- `wave8-smoke.sh:3343-3345` extracts
      `.hooks.PreToolUse[] | select(.matcher == "git commit") | .hooks[0].command` and compares it
      against the full literal
      `command -v edm-lint-staged-artifacts >/dev/null 2>&1 || exit 0; edm-lint-staged-artifacts`.
      Re-derived independently with `jq`: byte-identical.
- [x] **AC5** -- `grep -c 'edm-state'` over non-comment lines returns **0** (the single raw match is
      a comment CA-009 added explaining why the numeric guard was inlined rather than delegated).
      The comment-stripped scan is paired with a positive control at `wave8-smoke.sh:3359-3363` that
      injects a real `edm-state get PFX` call on a code line and requires the scan to still count it
      -- so narrowing the pattern to fix a self-match did not make the assertion unfailable, which
      is the trap this exact ticket's AC5 was remediated for once already (`a37784a`).
- [x] **AC6** -- `grep -ci 'destructive\|heredoc\|subshell'` returns **0**. D15's descope holds; none
      of ECC's 741 lines of shell tokenizer surface leaked in.
- [x] **AC7** -- `grep -cE '\b(node|python3?|npx|pip)\b'` returns **0**. The required-binary set is
      unchanged.
- [x] **AC8** -- the marker `test -f` is at `:101`; the first `jq` reference by `grep -n` is `:106`,
      and `wave8-smoke.sh:3374-3380` asserts `101 < 106`, which is the method the AC prescribes
      verbatim. The substantive property is stronger than the assertion measures: `:106` is a
      comment, and the *real* `command -v jq` precondition is at `:120`, well below both the marker
      resolution (`:97`), the marker test (`:101`) and the stale-marker check (`:108-114`). There is
      no top-of-script `require_jq`.
- [x] **AC9** -- `wave8-smoke.sh:3382-3429` restricts `PATH` to a fakebin holding a `jq` **spy**
      that records its own invocation, runs the gate with the marker absent, and asserts exit 0,
      empty stdout, empty stderr, and that the spy file was never created. It is paired with a
      positive control at `:3416-3429` that re-runs the identical fixture **with** a marker present
      and requires the spy to fire -- so the zero-count is proven non-vacuous rather than assumed.
      `wave8-smoke.sh` returned 781 passed / 0 failed in this audit's run.
- [x] **AC10** -- `bin/tests/timing.sh:473-521` adds the `--gateguard` arm, in the same `case` and
      using the same `_measure_p95` helper as `--lint`/`--all-lint`. It measures **both** branches
      as required: marker-absent (`:496-497`) and marker-present (`:499-512`), the latter writing a
      real tab-separated marker naming an existing directory so the full gate (and its per-edit
      `stat`) actually runs rather than short-circuiting. Executed live by this audit:
      ```
      TIMING gateguard_allow_absent  p95_ms=49  (marker absent, payload=126 bytes, 20 samples, this host)
      TIMING gateguard_allow_present p95_ms=144 (marker present, payload=126 bytes, 20 samples, this host)
      ```
      Both measured figures carry their fixture size. See the P2 observation below on the third
      line.
- [x] **AC11** -- recorded twice, both with fixture size and host, and both stating explicitly
      whether the target was met. Commit `709f745`'s body: "Measured allow-path (marker absent) p95:
      25-42ms across runs, fixture = one Edit tool_input payload (126 bytes), 20 samples, on this
      host (Apple M4 Max, macOS 26.6.2) -- comfortably under the 50ms design target". `decisions.md`
      D34 records the same in the ledger ("**42 ms** ... 126-byte `Edit` `tool_input` payload, 20
      samples, nearest-rank p95, on Apple M4 Max / macOS 26.6.2 ... **Budget MET**"), and correctly
      frames it as "a design target, not a verified property" until measured. The implementer's
      refusal to write outside its Target Components, with the coordinator closing the gap, is the
      right shape and D34 says so.

**Finding**: [P1] `EDMV4-T11` | `plugins/edm/bin/tests/wave8-smoke.sh:3325-3330` | AC#3: the AC's
mandated assertion was relaxed from an equality to a bound, and the relaxation is recorded only in a
code comment.

AC3 has two conjuncts. The first holds: `hooks.json` carries exactly one `Edit|Write|MultiEdit`
matcher block (verified independently --
`jq '[.hooks.PreToolUse[] | select(.matcher == "Edit|Write|MultiEdit")] | length'` returns `1`), and
its command begins with the required guard `command -v edm-gateguard >/dev/null 2>&1 || exit 0`,
asserted at `:3332-3340`.

The second conjunct is not met. AC3 says the smoke assertion "runs `jq '.hooks.PreToolUse | length'`
and asserts the result is **2**". `:3325-3330` runs that `jq` and then asserts
`[[ "$t11_pretooluse_len" -ge 2 ]]` against a live value of **3**. The comment at `:3318-3324`
explains why -- `EDMV4-T45` legitimately added a matcher-disjoint `Bash` block -- and the reasoning
is correct. The problem is what the relaxed form no longer catches: `>= 2` on an array that is 3
today and only grows cannot fail, and nothing anywhere asserts the count of `Edit|Write|MultiEdit`
blocks is exactly one, so a duplicated gateguard block would pass silently (`:3332`'s `select` would
emit two commands, and the `case` glob `"command -v edm-gateguard ..."*` matches a multi-line string
just as happily as a single-line one). The AC's own words -- "gains **exactly one** new PreToolUse
matcher block" -- are the property that stopped being enforced.

The process gap is the sharper half. `T11` AC1 hit the structurally identical problem (a number
pinned in Phase 2, invalidated by a later ticket's AC-mandated work) and it was resolved the right
way: escalated, decided, recorded as `decisions.md` D42, rationale planted at the assertion. AC3's
identical drift was resolved by an implementer writing a comment. `grep` over `decisions.md` finds
four `EDMV4-T11` entries -- covering the AC9 spy, AC11's p95, AC1's ceiling, and a Claude Code
version caveat -- and **none** covering AC3's count. Two instances of one class, two different
standards, three days apart.

### `EDMV4-T39`: Six-category rubric, 0-10 normalization, version constant -- FAIL

Graded against a live run of `bin/edm-repo-readiness` against this repository:

```
Methodology setup:   applicable=true  raw=10/10  score=10.0
State health:        applicable=true  raw=7/10   score=7.0
Test stack:          applicable=false raw=0/10   score=0.0
Coverage posture:    applicable=false raw=0/10   score=0.0
Convergence history: applicable=true  raw=10/10  score=10.0
Artifact hygiene:    applicable=true  raw=10/10  score=10.0
overall=9.3   checks=18   empty_fix=0   passing_checks_carrying_a_fix=12
```

- [x] **AC1** -- six categories, and every one reports `raw_max: 10` (asserted at
      `wave8-smoke.sh:3158-3159`; re-derived live above). Point budgets sum correctly per category:
      Methodology setup 3+2+5, State health 3+2+2+1+1+1, Test stack 6+4, Coverage posture 4+3+3,
      Convergence history 4+3+3, Artifact hygiene 10. Conditional markers match the SRD exactly at
      `:420-431`: Test stack on a detected framework, Coverage posture on **Test stack's own**
      predicate (`--argjson coverage "$TESTSTACK_APPLICABLE"`, `:422` -- the two share one computed
      value, so they cannot disagree), Convergence history on `ARCHIVED_COUNT >= 1`; the other three
      hardcoded `true`.
- [x] **AC2** -- the six categories are declared contiguously at `:350-414` under banner comments
      that each name the category, its raw total and its conditional predicate together --
      e.g. `# ---- Test stack (10 pts, conditional on any detected test framework) ----` at `:381`,
      immediately above its two checks. A reader sees one category's whole definition without
      scrolling. See the P2 observation below on the second, executable copy of the predicate.
- [x] **AC3** -- normalization is `fmt1` in `jq` (`:442`), never bash integer arithmetic, so `5` and
      `5.0` cannot both appear; `wave8-smoke.sh:3164-3165` asserts 5-of-10 renders the literal
      `"5.0"`. The overall score is the mean of applicable categories only (`:459-462`), and the
      live run confirms it divides by 4, not 6: `(10.0+7.0+10.0+10.0)/4 = 9.25 -> "9.3"`.
      `wave8-smoke.sh:3167-3182` re-derives that mean from the emitted JSON and compares it against
      the reported `.score` using the script's own `fmt1` rounding -- an exact comparison, not a
      tolerance, which is the wave-2 merge fix for a `< 0.05` tolerance that failed on exact halves.
- [x] **AC4** -- every category object carries an explicit `applicable` boolean (`:451`), computed
      via `has()` rather than `//` because `jq`'s `//` treats `false` as absent and would silently
      restore a computed `false` to `true` -- the trap is called out in the code at `:443-446`.
      Live category keys: `applicable,name,raw_earned,raw_max,score_0_10`.
- [x] **AC5** -- inapplicable categories are filtered out of `$applicable_cats` before the mean
      (`:459`), so an excluded category is arithmetically identical to one that was never defined.
      Two categories report `applicable=false` on this repository, so the positive control at
      `wave8-smoke.sh:3190-3195` takes its pass branch live rather than degrading to its NOTE. The
      applicable-but-not-full direction is covered incidentally too: State health scores 7/10 and
      stays in the denominator.
- [x] **AC6** -- `:114` is `READINESS_RUBRIC_VERSION="1.0.0"`, a bare top-level string constant,
      matching `evals/score-artifacts.sh:139`'s `SCORER_VERSION="1.1.0"` form exactly. No new
      versioning scheme. `wave8-smoke.sh:3147-3148` asserts the literal including its value, not
      merely the constant's existence.
- [ ] **AC7** -- **FAIL**. See finding below.
- [x] **AC8** -- `_rr_mk_check` (`:341-346`) is the single constructor for every check object and
      takes all six fields as required positional arguments, so `id`/`category`/`points`/
      `description`/`pass`/`fix` are structural rather than per-call discipline. Live: 0 of 18
      checks has a null or empty `fix`, and **12 passing checks carry one** -- which is the half of
      the AC that matters ("mandatory on every check, not only failing ones") and is asserted with a
      dedicated non-zero count at `wave8-smoke.sh:3200-3205` rather than folded into the null check.
- [x] **AC9** -- determinism verified directly by this audit: two consecutive runs into a fresh
      scratch directory produced **byte-identical** JSON. The emitted document carries no timestamp
      at all (top-level keys are exactly
      `categories,checks,prefix,readiness_rubric_version,score`), so the AC's "or the JSON carries
      no timestamp" branch is the one taken. `wave8-smoke.sh:3207-3214` runs the same diff.
      (An initial comparison of mine appeared to diverge; it was a filename collision in shared
      `/tmp` with a concurrent process writing a different build's output, not the script. Re-tested
      in an isolated directory, which is the result recorded here.)
- [x] **AC10** -- no check scores whether EDM itself is installed. The 18 check ids are all
      properties of the target repository (`git-repo-present`, `srd-directory-present`,
      `permission-ask-rules-configured`, six `state-health-*`, two test-stack, three coverage, three
      convergence, `artifact-lint-clean`); none probes for the plugin's own presence. `:261-263`
      records the guard in-file, naming correction 7's self-serving `harness-audit.js` pattern, and
      `wave8-smoke.sh:3217-3218` scans the emitted ids.
- [x] **AC11** -- scope ownership is documented in the help block at `:29-34`, at the granularity the
      AC needs: it names which categories `<PREFIX>` scopes (State health, Test stack, Coverage
      posture, and *Artifact hygiene's lint scan*) and which stay repository-wide (*Methodology
      setup's git/SRD checks*, Convergence history). Splitting two categories at sub-check
      granularity is exactly what makes the report's totals unambiguous under a `<PREFIX>`. The one
      genuinely shared computation, `TESTSTACK_APPLICABLE`, is documented at `:251-258` naming both
      owning categories and why it is computed once.
- [x] **AC12** -- `run-all.sh`: 3289 passed, 0 failed, exit 0. The new assertions live in
      `wave8-smoke.sh`, which `run-all.sh` auto-discovers (8 suites discovered; `_MIN_SUITE_COUNT`
      is 8 at `run-all.sh:102`, so the backstop is tight rather than slack).

**Finding**: [P1] `EDMV4-T39` | `plugins/edm/bin/edm-repo-readiness` (whole file) | AC#7: the
refuse-on-version-mismatch contract is not documented anywhere, and nothing asserts it.

AC7 is a conjunction and only its first half landed. The rubric version **is** written into the JSON
output (`:464`, `readiness_rubric_version: $version`; verified live as `"1.0.0"`, asserted at
`wave8-smoke.sh:3152-3153`). The second half -- "the script **documents** that a future comparator
must **refuse** rather than silently pass on a version mismatch, matching `edm-compare-eval:85-91`'s
`scorer_version` refusal" -- has no implementation at all.

A scan of the entire file for `refus`, `mismatch`, `comparator`, `scorer_version` and
`compare-eval` returns four hits, none of which is this contract: `:5` cites `edm-compare-eval` for
the `print_help` idiom, `:48` for the two-argument `die()` form, `:113` cites
`evals/score-artifacts.sh` for the version-constant precedent, and `:445` cites a `cand_complete`
comment in `edm-compare-eval` about a *different* boolean's `//` trap. Nothing tells a future
comparator author what to do when two scorecards carry different `READINESS_RUBRIC_VERSION` values.

This is the whole of what AC7 asked for beyond version presence -- the ticket's own Out of Scope
section says so explicitly: "Building a comparator for two scorecard JSON files; **AC7 only requires
the version be present and the refusal contract documented**." One of two required things is
missing, and the smoke assertion covers only the one that is present, so the gap is invisible to the
suite. Graded P1 because a version string whose consumption contract is undefined is the failure
mode `READINESS_RUBRIC_VERSION` exists to prevent: the next author's cheapest path is to compare two
scorecards and let a mismatch through, which is precisely the silent pass `edm-compare-eval:87-91`
refuses.

The precedent to mirror is four lines:

```
cand_sv="$(jq -r '.scorer_version // "unset"' "$CANDIDATE")"
base_sv="$(jq -r '.scorer_version // "unset"' "$BASELINE")"
if [ "$cand_sv" != "$base_sv" ]; then
  echo "edm-compare-eval: REFUSED -- scorer_version mismatch ..." >&2
```

### `EDMV4-T40`: Wire the scorecard to the signals EDM already computes -- FAIL

- [x] **AC1** -- permission-rule presence is read from the `PERM_RULES_MISSING` anomaly surfaced by
      `edm-state validate` (`:275-276`, via `_rr_any_prefix_validate_has`), never re-scanned.
      `grep -c "settings\.local\.json\|settings\.json"` over the script returns **0**;
      `wave8-smoke.sh:3222-3227` asserts both filenames absent. The needles are constructed into
      variables first (`:3222-3223`) so the assertion's own label cannot self-match -- the pattern
      this initiative filed five findings against.
- [x] **AC2** -- all five named anomalies are read from `validate`'s output and nothing else:
      `OPEN_PARTIALS` (`:281-282`), `CONVERGED_NO_APPROVAL` (`:283-284`), `OPEN_AUDIT_ROUND`
      (`:287-288`), `TORN_TOKEN_LINES` (`:289-290`), `SPEC_SWEEP_PENDING` (`:291-292`), plus a
      forward-compatible catch-all for any other blocking type (`:172-189`) that avoids hardcoding
      an exhaustive list that would drift as `state_anomalies()` grows. The matcher is anchored
      (`^(blocking|info)[[:space:]]+${needle}([[:space:]]|$)`, `:160`) so `OPEN_PARTIALS` cannot
      match `OPEN_AUDIT_ROUND`. `.edm-state.json` appears twice in the file and neither is a state
      read: `:20` is a comment, `:304` is a `find -name` file **count** for the archived tally.
      Crucially, `_rr_validate_output` (`:142-147`) captures `validate`'s exit explicitly
      (`out="$(...)" || rc=$?`) -- the ticket's Technical Notes call an unguarded call "the single
      most likely implementation bug in this ticket", and `wave8-smoke.sh:3242-3245` pins both the
      capture form and the absence of any `source "$EDM_STATE_BIN"`.
- [x] **AC3** -- the blocking/informational split is declared in-script at `:278-280` and, more
      usefully, per-check: each State health check's `description` carries its own class and cost
      ("(blocking, 3pt cost)" `:363`, "(blocking, 2pt cost)" `:366` and `:369`, "(informational, 1pt
      cost)" `:372`, `:375`, `:378`). A reader can see why a repository lost the points it lost from
      the report alone -- 3+2+2 blocking and 1+1+1 informational, summing to the category's 10.
- [x] **AC4** -- test-stack signals come from `edm-state get-coverage`'s "Detected Frameworks" lines
      (`:196-210`), parsed to handle both the flat and per-epic render shapes with one rule.
      `grep -cE "jest\.config|pytest\.ini|vitest\.config"` returns **0**;
      `wave8-smoke.sh:3232-3237` asserts each, again with runtime-assembled needles.
- [x] **AC5** -- coverage posture compares against `COVERAGE_TARGET_{UNIT,COMPONENT,INTEGRATION}_PCT`
      (`:119-121`), each read through the house
      `EDM_<NAME>` -> `CLAUDE_PLUGIN_OPTION_<NAME>` -> default chain that `bin/edm-state` already
      uses for `SRD_ROOT`. The values reach the checks as interpolated variables at `:391`, `:394`,
      `:397` -- no percentage literal appears in a comparison. Defaults 80/70/60 agree with
      `plugin.json`'s `userConfig`.
- [x] **AC6** -- cost and duration history is read from `edm-state metrics-report --calibrate`
      (`:312-314`) and `metrics-report --all` (`:316-321`); no second cost derivation exists.
- [ ] **AC7** -- **FAIL**. See finding below.
- [x] **AC8** -- verified directly rather than trusted: I hashed
      `SRD/edm/EDMV4__ecc-integration/.edm-state.json` with `shasum -a 256`, ran
      `edm-repo-readiness` both bare and `<PREFIX>`-scoped, and re-hashed -- **unchanged**. The
      script holds no write path to a state file (the only `>` redirections are `:497`'s
      `--json` target and `/dev/null`), and `edm-state` is only ever invoked with read subcommands
      (`get`, `list`, `validate`, `get-coverage`, `metrics-report`). `wave8-smoke.sh:3247-3254`
      automates the same check via `check_state_unchanged`, which fails loudly on a missing baseline
      (`_harness.sh:298-301`) rather than passing vacuously. The AC's "for every initiative in the
      fixture repository" is satisfied because this repository has exactly one non-archived
      initiative -- `find SRD -name .edm-state.json -not -path '*/.archived/*'` returns one path.
- [x] **AC9** -- a repository with no initiatives at all exits 0 and scores what it can:
      `wave8-smoke.sh:3260-3272` runs the script from an empty scratch directory, asserts exit 0,
      and additionally asserts the applicable set collapses to exactly
      `Artifact hygiene,Methodology setup,State health` -- proving the three conditional categories
      are excluded rather than scored zero, which is the substantive half and a stronger check than
      the exit code alone.
- [x] **AC10** -- `run-all.sh`: 3289 passed, 0 failed, exit 0; the assertions live in the
      auto-discovered `wave8-smoke.sh`.

**Finding**: [P2] `EDMV4-T40` | `plugins/edm/bin/edm-repo-readiness:264-267` and `:269-270` | AC#7:
two self-detecting checks carry no comment explaining why no existing source covers them.

AC7 states its own verdict language: "Any signal the script genuinely must detect itself carries a
one-line in-file comment explaining why no existing source covers it. **A check with no such comment
and no `edm-state` call is a defect.**"

Three signals in this script are self-detected. Exactly one carries the required justification --
`_rr_archived_count` at `:296-301`, which is a model of what the AC wants (it names the AC, explains
that `edm-state list` deliberately excludes `.archived/` per EDMV3-111, notes that
`metrics-report --all` mixes active and archived rows without labeling them, and states that it
mirrors `list_state_files()`'s own recognized shapes).

The other two have none:

- `GIT_REPO_PRESENT` (`:264-267`) runs `git rev-parse --is-inside-work-tree` with no `edm-state`
  call and no explanation. The nearest comment, `:261-263`, is about AC10's self-installation guard
  and says nothing about why this signal is detected here.
- `SRD_DIR_PRESENT` (`:269-270`) tests `[[ -d "$SRD_ROOT" ]]`, where `SRD_ROOT` is itself a **second,
  independent re-derivation** of `srd_root` at `:67`
  (`"${EDM_SRD_ROOT:-${CLAUDE_PLUGIN_OPTION_SRD_ROOT:-./SRD}}"`) duplicating the chain `bin/edm-state`
  and `bin/edm-lint-staged-artifacts` already own. This is the CA-409 "two independent procedures for
  one predicate drift apart silently" class -- exactly what AC7's comment requirement exists to force
  an author to confront before writing it.

Graded P2 rather than P1: the scoring behavior is correct today, both derivations currently agree
with `edm-state`'s, and the remediation is two comment lines. It is graded FAIL rather than waved
through because AC7 pre-declares this state a defect in its own text, and because the
`srd-directory-present` case is a real duplicated derivation rather than a cosmetic omission -- the
comment it needs should say so, not rubber-stamp it.

---

## Observations (P2, recorded, not remediation-blocking)

**`EDMV4-T11` AC1 -- the ticket text was never swept to match D42.** `tickets/epics/02-gateguard.md:64-66`
still reads "a count in the closed range 200 to 400", while `decisions.md` D42 raised it to 500 on
2026-09-03 and `wave8-smoke.sh:3305` enforces 200-500. The epic file's last write predates D42, so
the pack and the executable assertion now disagree by 100 lines. This is the `spec_swept` discipline
CA-416 already enforces on code-audit findings, applied to a gate decision instead: amend AC1's text
to the ratified bound and cite D42, so a later reader grading this ticket from the pack alone does
not reach the opposite verdict from the one recorded here.

**`EDMV4-T11` AC10 -- one printed figure omits its fixture size.** `timing.sh:515` and `:517` print
`budget_status=MET (allow-path, marker-absent, p95 49ms <= 50ms design target, SRD Sec.9.1/9.3)` --
two figures, no input size on that line. AC10 requires the mode state "the fixture size alongside
**every** figure it prints", citing CLAUDE.md's rule that a budget is never quoted without its input
size; the two measurement lines at `:497` and `:512` comply, this third one does not. Appending
`, payload=${GG_PAYLOAD_BYTES} bytes, 20 samples` to both branches of the `if` closes it. Worth
noting alongside this: today's measured p95 was **49 ms** against the 50 ms target, with samples
spanning 25-75 ms -- still MET, but a good deal tighter than D34's recorded 42 ms and outside the
"runs varied 25-42 ms" spread D34 records. D34's own framing ("on one host, once") already covers
this; it is recorded here so the next reader does not treat 42 ms as a stable property.

**`EDMV4-T39` AC2 -- the conditional predicate has a second, executable home.** The banner comments
at `:350`, `:361`, `:381`, `:389`, `:400`, `:411` are what satisfy AC2, and they do. But the
predicate that actually reaches the JSON is `CATEGORY_APPLICABILITY_JSON` at `:420-431`, a mapping
keyed by bare category-name strings, ~40 lines away and computed from variables at `:243-258` and
`:302-309`. Editing a banner changes nothing; renaming a category in one place and not the other
silently makes `has($catname)` miss and `:451`'s `else true` default turn a conditional category
unconditional. No assertion covers the banner-to-mapping correspondence.

**`EDMV4-T39` AC11 -- one check's category placement is undocumented.** `permission-ask-rules-configured`
(`:357-359`, Methodology setup, 5 pts) draws on the same `edm-state validate` anomaly stream as all
six State health checks. Its placement is deliberate and defensible -- setup versus in-flight health
-- but no comment says so, and it is the one check in the rubric where a reader could reasonably
expect a different category. AC11 is graded PASS on the scope documentation at `:29-34`; this is the
category-ownership sentence that would make it airtight.

---

## Remediation Required

**P1 -- `EDMV4-T39` AC7: document the refuse-on-version-mismatch contract.**
Add a comment beside `READINESS_RUBRIC_VERSION` at `bin/edm-repo-readiness:112-114` stating that a
future scorecard comparator must **refuse** (exit non-zero, naming both versions) on a
`readiness_rubric_version` mismatch rather than silently comparing across rubrics, and cite
`edm-compare-eval:85-91` as the form to copy. Then give it an assertion: `wave8-smoke.sh`'s
`EDMV4-T39 AC7` block currently checks only that the version reaches the JSON (`:3152-3153`); add a
`check` that the script's text carries the refusal contract, paired with a positive control the way
`T11` AC5's scan at `:3359-3363` and `T55` AC9's detector at `:872-880` already are. Without the
control, a substring check on a comment is the same unfailable assertion this initiative has filed
four findings against.

**P1 -- `EDMV4-T11` AC3: restore the exact-count property, and record the change.**
Two parts, and the second is the one that outlives the fix.
First, at `wave8-smoke.sh:3325-3330`, keep the `>= 2` sanity bound if useful but add the assertion
AC3's substance actually needs:
`jq '[.hooks.PreToolUse[] | select(.matcher == "Edit|Write|MultiEdit")] | length'` must equal **1**.
That is the "exactly one new matcher block" claim, it is immune to `T45` and any future
matcher-disjoint block, and it catches the duplication the current form cannot. Consider also
capturing `.hooks[0].command` into a variable and asserting it contains no newline before the `case`
at `:3333`, so a two-block payload cannot satisfy the prefix glob.
Second, record the count change in `decisions.md` the way D42 recorded AC1's ceiling change. Both are
the same class -- a Phase-2 number invalidated by a later ticket's AC-mandated work -- and resolving
one at the gate and the other in a code comment is the inconsistency worth closing, not the number
itself.

**P2 -- `EDMV4-T40` AC7: justify the two unexplained self-detections.**
Add one comment line above `GIT_REPO_PRESENT` (`:264`) stating why no `edm-state` subcommand exposes
"is the target a git working tree", and one above `SRD_DIR_PRESENT` (`:269`) that names the real
issue: `SRD_ROOT` at `:67` re-derives the `EDM_SRD_ROOT` / `CLAUDE_PLUGIN_OPTION_SRD_ROOT` / `./SRD`
chain that `bin/edm-state` and `bin/edm-lint-staged-artifacts` already own, and the two must be kept
in step. Match `_rr_archived_count`'s comment at `:296-301` for depth -- that one is the standard the
AC is asking for.

**PARTIAL closure**: none. This shard produced no PARTIAL verdicts, so there is nothing for
`/edm:verify-runtime` to close and nothing to persist via `edm-state record-partial-verdict`. Every
acceptance criterion in all three tickets was resolvable statically or by direct execution on this
host; no AC required a runtime environment this project does not have, so no D15 specification
defect is raised either.

<!-- QC-SHARD-COMPLETE range=T11,T39,T40 assigned=3 audited=3 -->
