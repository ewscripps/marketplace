# Code Audit Remediation Plan: EDMV3 -- prompt-streamline (Round 8)

## Context

- **Audit date**: 2026-08-16
- **Round**: 8 -- **full round, all 11 lenses ran** (`lenses-run.txt`: `Round type: full`, L1-L11)
- **Audited scope**: `plugins/edm/bin/*`, `plugins/edm/bin/tests/*`, `plugins/edm/agents/*.md`,
  `plugins/edm/skills/*/SKILL.md`, `plugins/edm/hooks/hooks.json`,
  `plugins/edm/monitors/monitors.json`, `plugins/edm/evals/*.sh` (+ evals READMEs/fixtures),
  `plugins/edm/CLAUDE.md`, `README.md`, `CHANGELOG.md`, `WHATS_NEW.md`, repository-root
  `.gitlab-ci.yml`, `.gitignore`, `CLAUDE.md`, and the EDMV3 SRD / ticket pack
- **Working tree at**: commit `bdab2ac` (with `dc8a24f`, `dfa71d3`, `3449fde`, `d14e059` as the
  round-7-to-round-8 remediation commits under audit)
- **SRD**: `SRD/edm/EDMV3__prompt-streamline/srd.md`
- **Ticket pack**: `SRD/edm/EDMV3__prompt-streamline/tickets/`
- **Ledger**: `SRD/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl` (471 entries)
- **Deployment target**: local plugin install + GitLab CI (`.gitlab-ci.yml`, scoped to `plugins/edm/**`)

**Round-8 movement**: 32 prior findings confirmed fixed and closed (`resolved_round = 8`);
21 prior findings re-verified still open; 49 new findings raised (`CA-423` .. `CA-471`).
**70 findings open: 0 P0, 9 P1, 61 P2.**

**What is different about this round.** Rounds 5-7 consistently found shipped code correct and
specification text stale. Round 8 contains the **inverse**: the `--accept-p2-debt` feature
(commits `dc8a24f`, `bdab2ac`) is shipped code that contradicts a Won't-Have SRD acceptance
criterion, with no ticket, no SRD change request and no gate change-control record. It is also,
by construction, a feature that makes it easier to converge with open P2s -- landed while 50+ P2s
stand open. Nine findings across five lenses (L1, L2, L3, L4, L9, L11) touch it. It is one work
item, not nine.

**Second theme**: four of this session's own remediation fixes introduced new defects
(CA-397 -> CA-432/CA-433; CA-395 -> CA-434; CA-406 -> CA-435; CA-380 -> CA-436/CA-437;
CA-415 -> CA-438). These are cheap and should land immediately.

---

## Findings Summary

### P0 (0)

None. No lens filed a P0 this round.

### P1 (9) -- fix before shipping

| # | Sev | Lens(es) | Component | Issue |
|---|-----|----------|-----------|-------|
| CA-423 | P1 | L9 | `srd.md:3836` vs `bin/edm-state:2087` | `--accept-p2-debt` is a bypass flag on `approve-gate`; EDMV3-90 AC1 (Won't Have) forbids it and is unamended |
| CA-424 | P1 | L9 | `epics/04:547` vs `bin/edm-state:2178-2195` | T28 AC12 ("refuses when it fails") is now false for one input class; no AC describes the new branch |
| CA-425 | P1 | L4 | `wave6-smoke.sh:657-745` | The entire `--accept-p2-debt` safety guard (non-severity refusals + 2 usage `die()` arms) has zero tests |
| CA-440 | P1 | L3 | `hooks.json:117` + `implement/SKILL.md:35,37,114` | 6-10 concurrent auto-spawned QC auditors full-file-`Write` the same `qc/qc-summary.md`; FAIL verdicts silently lost |
| CA-441 | P1 | L7 | `skills/test`, `test-plan`, `test-coverage` `SKILL.md:8` | Three testing skills spawn agents but omit `Task` from `allowed-tools`; all 8 siblings grant it |
| CA-460 | P1 | **L6+L7+L2** | `CLAUDE.md:1011-1036`, `.gitlab-ci.yml:56-60,:78-83` | `lint:hooks-shell` (blocking) is absent from the CI table; "seven lint jobs"/"ten consumers" are 8/11 |
| CA-461 | P1 | L6 | `evals/baseline/README.md:91-104` | Runbook prescribes `variance.total_max_minus_min`; `edm-compare-eval:102` reads `variance.total_range` |
| CA-462 | P1 | L11 | `evals/fixtures/tiny-svc/expected.json` | Ground truth has no consumer; the eval scores self-consistency only, so the baseline tripwire is blind |
| CA-416 | P1 | L9 | ledger + synthesizer templates | *(escalated from P2)* No same-commit spec/AC sweep obligation exists; root cause of 4 fresh instances this round |

### P2 -- accept-p2-debt cluster (6 more)

| # | Sev | Lens(es) | Component | Issue |
|---|-----|----------|-----------|-------|
| CA-426 | P2 | **L1+L2** (+L3) | `bin/edm-state:2168,:2178,:2195-2199` | Engagement prefix-tests position 0 of a `2>&1`-merged stream; a stderr warn silently disables the override, and the refusal prints `P0=0 P1=0` from uninitialised locals |
| CA-427 | P2 | **L1+L3** | `bin/edm-state:2212, :3016` | Both new `.audit_rounds.code.count` reads bypass `AUDIT_ROUND_COERCE_JQ_DEF`; jq hard-errors on the documented legacy bare-integer shape |
| CA-428 | P2 | L3 | `bin/edm-state:3015-3017` | Debt-round staleness gate reaches `[[ -eq ]]` without `to_int` (CA-157 class) |
| CA-429 | P2 | L11 | `bin/edm-state:2222-2223` | `_accepted_at`/`_accepted_by` written, read nowhere; byte-identical duplicates of two keys with three readers |
| CA-430 | P2 | L9 | feature-wide | No ticket in any pack; the label `T-EDMV4` resolves to no pack on disk |
| CA-431 | P2 | L9 | `CHANGELOG.md:7`, `plugin.json:4`, `CLAUDE.md:241` | No CHANGELOG entry, no version bump, five new state fields absent from the state-field table |

### P2 -- regressions introduced by this session's own remediation (7)

| # | Sev | Lens(es) | Component | Issue |
|---|-----|----------|-----------|-------|
| CA-432 | P2 | L3 | `bin/edm-state:1099-1100` | *(from CA-397)* `EDM_STATE_LOCK_WAIT_S` unvalidated at top level; `0.5` aborts every subcommand at load, `abc` fabricates a lock timeout |
| CA-433 | P2 | L3 | `wave7-smoke.sh:4904-4912` | *(from CA-397)* G53 awk anchor encodes the old literal `-w 10`; three CA-169 assertions now pass vacuously (2nd recurrence after G38/CA-314) |
| CA-434 | P2 | L2 | `wave7-smoke.sh:195-211`, `_harness.sh:183`, `harness-smoke.sh:135,137` | *(from CA-395)* Tripwire + two docstrings outlived the deleted `assert_absent_with_control` |
| CA-435 | P2 | L6 | `wave7-smoke.sh:7835-7842,:7848,:7874` | *(from CA-406)* G10/CA-340 allowlist justification describes deleted text; `g10_allowlist_2` now filters nothing |
| CA-436 | P2 | L8 | `.gitlab-ci.yml:275-314` | *(from CA-380)* `lint:hooks-shell` is blocking and likely red on first run, with no place to put a shellcheck directive |
| CA-437 | P2 | L8 | `.gitlab-ci.yml:291` | *(from CA-380)* Newline-splits extracted hook commands; `COUNT` over-reports with no cross-check |
| CA-438 | P2 | L8 | `bin/edm-state:1164-1170` | *(from CA-415)* The corrected fd-200 rationale has no durability pin anywhere in `bin/tests/` |

### P2 -- correctness, concurrency and runtime hygiene (13)

| # | Sev | Lens(es) | Component | Issue |
|---|-----|----------|-----------|-------|
| CA-439 | P2 | **L1+L3** | `bin/edm-state:2246,:5349,:1216-1220` | Three load-bearing comments authored alongside fixes are false: `gates_count` cited at `:5036` (is `:5158`); the BASHPID rationale describes the wrong process |
| CA-442 | P2 | L3 | `bin/edm-state:3531-3539` | `migrate-path` rollback leaks a live lockdir into the restored source directory; both forward movers sweep for exactly this |
| CA-443 | P2 | L3 | `evals/run-eval.sh:180-206` | `EDM_EVAL_KEEP_RUNS=0` prunes the run just written; `eval:nightly` then reports green having evaluated nothing |
| CA-444 | P2 | L3 | `evals/run-eval.sh:292-313,:395` | `EDM_EVAL_PHASE_TIMEOUT_SECONDS` unvalidated; a non-numeric value disables the timeout and the model call runs unbounded (defeats G45) |
| CA-445 | P2 | L3 | `bin/edm-state:2527-2532` | A space in a recorded artifact path truncates `file_path`; drift detection fails silently **open** for that initiative |
| CA-446 | P2 | L3 | `bin/edm-sync-canonical-sections:84` | Trap cleans up and **resumes** on INT/TERM/HUP (CA-143 contract); `--check` (the CI mode) reports a fabricated "out of sync" verdict |
| CA-447 | P2 | **L7+L8** | 6 sites, incl. `bin/edm-lint-artifacts:141` | Two trap signal sets coexist; 6 sites omit HUP against the CA-150 precedent. `edm-lint-artifacts` runs on **every git commit** |
| CA-448 | P2 | L8 | `bin/edm-state:1032` | `check_permission_rules` resolves `settings.json` against process cwd: false `prose-only` from a subdirectory, false `permission-ask` from an unrelated project |
| CA-449 | P2 | L5 | `evals/score-artifacts.sh:687-693` | Last untrapped `mktemp` in `bin/`+`evals/`: no trap, no template, and the T61 AC11 tripwire regex cannot match the non-`-d` form |
| CA-450 | P2 | L5 | `bin/tests/timing.sh:268,301,333,350,378` | Five modes leak their scratch tree on failure/interrupt; `harness_scratch_dir` is sourced and unused |
| CA-451 | P2 | L2 | `bin/edm-state:831, :902` | `gated_phase == "null"` guards structurally unreachable; also a future silent-skip hazard if a 4th gate is added |
| CA-452 | P2 | L2 | `evals/run-eval.sh:150-154` | Partial-run stub `scores.json` has no reachable consumer; `edm-compare-eval` refusal condition 3 is dead from CI |
| CA-401 | P2 | **L4+L1** | `wave7-smoke.sh` (15 sites) + `wave6-smoke.sh` (7 sites) | *(carried)* Unguarded count captures abort the whole suite under `set -e`; L1 extended the class to a second suite and a second shape |

### P2 -- test quality (7)

| # | Sev | Lens(es) | Component | Issue |
|---|-----|----------|-----------|-------|
| CA-453 | P2 | L1 | `wave6-smoke.sh` (absent) | CA-389 + CA-390 shipped code with **zero** tests; all 4 prescribed assertions missing; nothing asserts the `Gates approved` line |
| CA-454 | P2 | L4 | `wave7-smoke.sh:2480,:4474,:4495` | Exit-code assertions use substring `check()`, so 10/20/100/101... all pass an "exits 0" assertion |
| CA-455 | P2 | L4 | `wave7-smoke.sh` (9 sites) | Nine SKIP paths increment no counter; on macOS three lock-contract cases vanish under `ALL SUITES PASSED` |
| CA-456 | P2 | L4 | `wave7-smoke.sh:1659-1689` | Four assertions run against a fixture the test wrote three lines earlier; cannot fail for any source change |
| CA-457 | P2 | L4 | `wave7-smoke.sh:951,:963,:967` | Six-arm `T61_BASH4_RE` proven by a one-arm control; a mis-escaped arm stays permanently green |
| CA-458 | P2 | L4 | `wave6-smoke.sh:203,:210,:221` | CA-312 residual: the site both fix comments cite as the "already-correct model" is itself a substring match |
| CA-459 | P2 | L10 | `_harness.sh:235,:198` vs ~17 sites | CA-037's L10 half: 16 of 17 hand-rolled controls use the CA-145-unsafe shape with no path-existence guard; live false pass at `wave7:1438` |
| CA-402 | P2 | L4 | `wave7-smoke.sh:2001,:2044,:2045,:2124` | *(carried)* Repo-wide scan self-matches; `MERMAID_QUOTED` has zero readers and is the contaminant; 4 exclusion vocabularies; one `-i` outlier |
| CA-403 | P2 | L4 | `wave7-smoke.sh` (6 controls) | *(carried)* Positive controls authored to satisfy the regex, not copied from real pre-fix text |
| CA-404 | P2 | L4 | `wave7-smoke.sh:607,:635,:648,:678` | *(carried, narrowed)* Determinism half fixed; four scorer-extraction sites still discard rc and stderr |
| CA-405 | P2 | L4 | `wave7-smoke.sh:2547` | *(carried, narrowed to 1 of 3)* T44 AC8 meta-assertion passes with 39 of 40 assertions deleted |

### P2 -- documentation, spec text and wiring (18)

| # | Sev | Lens(es) | Component | Issue |
|---|-----|----------|-----------|-------|
| CA-463 | P2 | **L6+L11** | `evals/fixtures/tiny-svc/README.md:38-42` | Names `du -sk` as the 100KB enforcement; the job sums git-tracked bytes and excludes `runs/` |
| CA-464 | P2 | L6 | `evals/baseline/README.md:11-13` | The `run-eval.sh:309-327` citation re-staled in the sentence boasting about correcting its predecessor |
| CA-465 | P2 | **L6+L9** | `plugins/edm/WHATS_NEW.md` (untracked) | Unticketed new top-level doc: stale round counter, false "fully-audited" claim, invisible to `edm-check-vocabulary`'s `SCOPE_ROOTS` |
| CA-466 | P2 | L11 | `skills/code-audit/SKILL.md:108-120` | `tooling-notes.md` has no consumer and no entry in either artifact inventory |
| CA-467 | P2 | L10 | 11 lens agents + `SKILL.md:303` | JSONL schema literal hand-maintained in 12 files with only a presence check, while the plugin ships a generator+`--check` for this class |
| CA-468 | P2 | L9 | `epics/11:671-672` | T66 AC3 cites a case label that exists nowhere in the suite (fresh CA-368-class instance) |
| CA-469 | P2 | L9 | `epics/04:763-769` | T30 AC4 stale in both halves: 5 classes vs 7 shipped; both verify counts wrong by construction |
| CA-470 | P2 | L9 | `epics/04:677-681` | T29 AC12's normative catch-all is unsatisfiable as written; the three-filter pipeline does not reproduce the allowlist |
| CA-471 | P2 | **L10+L9+L8** | `skills/code-audit/SKILL.md` | No round-completeness check: `pass-7/` has **zero** `.jsonl` files, `pass-6/lens-L10.jsonl` absent, and nothing failed |
| CA-407 | P2 | L6 | `CLAUDE.md:880-886` | *(carried, corrected)* Names `wave6-smoke.sh` where the assertion is `wave7-smoke.sh:4290-4305`, and understates the guard (3 totals checked, not 1) |
| CA-408 | P2 | L6 | `wave7-smoke.sh:223-225` | *(carried, attribution corrected)* T03 banner has only a trailing divider; prior round wrongly attributed this to `bin/edm-state` |
| CA-409 | P2 | L7 | `hooks.json:19` vs `:23` | *(carried)* Two independently-derived first-invocation procedures for the same five gates |
| CA-410 | P2 | L7 | `hooks.json:86` | *(carried, direction now answered)* Commit-hook prefix regex is a third family matching neither; fails open. **Widen, do not tighten** |
| CA-411 | P2 | L7 | `hooks.json:117` | *(carried)* SubagentStop QC prompt hardcodes `qc-summary.md`, ignoring the sharding rule three other sources describe |
| CA-412 | P2 | L7 | `hooks.json:117` | *(carried)* SubagentStop prompt references `<PREFIX>` with no derivation instruction, unlike its five siblings |
| CA-413 | P2 | L8 | `hooks.json:86` | *(carried)* Lexical relativization defeated by a symlinked repo path; commit-time artifact lint silently stops enforcing |
| CA-414 | P2 | L8 | `hooks.json:86` | *(carried)* `echo "$staged"` + default `core.quotePath` is interpreter-dependent; one staged path becomes two lines on ash |
| CA-344 | P2 | L10 | 5 sites in `bin/` helpers | *(carried)* Five mechanical duplications, all still present, none diverged |
| CA-417 | P2 | L10 | `bin/edm-state:2350, :5182` | *(carried)* `skipped_phases_str`'s two un-converted callers survive; docstring still undercounts them |
| CA-418 | P2 | L10 | `bin/edm-state:2625,:2638,:3455,:3465` | *(carried)* One shared coverage row, four hand-maintained headers in two mechanisms with provably different dash counts |
| CA-419 | P2 | L10 | `bin/edm-state:4754-4770` | *(carried)* Identical 7-line twins; both omit the `write_handoff_internal` refresh their siblings perform |
| CA-420 | P2 | L10 | `bin/edm-state:2705-2706` | *(carried)* Archived-layout case patterns still hand-encoded; the comment claims otherwise |
| CA-421 | P2 | L11 | `bin/edm-state:1861` | *(carried)* `test_frameworks_detected` written every run, read by nothing; provenance comment names two non-consumers |
| CA-422 | P2 | L11 | `wave7-smoke.sh:99` | *(carried)* `caller_contract_scan` checks producers only; CA-429 is direct proof the gap is live |

---

## Detailed Findings

### WORK ITEM 1 -- `--accept-p2-debt` (CA-423, CA-424, CA-425, CA-426, CA-427, CA-428, CA-429, CA-430, CA-431)

**Nine findings, five lenses, ONE feature.** L9 found the spec-compliance angle, L1 and L2
independently found the same stream-merging bug, L3 confirmed both bugs by reading
`with_state_lock` in full, L4 found the missing tests, L11 found the orphan state keys. These are
kept as distinct findings because they have distinct fixes and distinct lens mandates -- but they
are **one coordinated remediation pass**, not nine independent ones, and the sequencing between
them is load-bearing.

#### CA-423 (P1, L9): `--accept-p2-debt` violates EDMV3-90 AC1, a Won't-Have

**Problem.** `srd.md:3836-3837` states: *"No `--force`, `--accept-partials`, `--skip-checks`,
`--yes`, **or equivalent bypass flag** exists on `phase-complete`, `archive`, `approve-gate`, or
`audit-converged`."* AC4 adds that a recorded-exemption category *"would be an override flag with
a state field instead of a command-line argument"*. Shipped code provides **both halves**:
`edm-state approve-gate <PREFIX> code-audit --accept-p2-debt` (`bin/edm-state:2085-2093`)
converges an initiative `cmd_audit_converged` has just refused, and records the exemption in five
state fields (`:2210-2227`).

Both mechanisms the pack names as keeping this boundary true **pass, because they ban flag NAMES
rather than the class**: `vocabulary-prohibited.txt:18-19` bans only `accept-partials` and
`force`; T30 AC10's grep (`epics/04:797`) searches those same two literals. `decisions.md:66`
(D57) records the decision, but a decision record is not the gate change-control route D13/D15
require, and it does not amend the SRD it contradicts. `tickets/README.md:688` still asserts the
boundary intact.

EDMV3-86, -87, -88 and -89 were re-verified intact. Only EDMV3-90 is breached.

**Fix.** This is a **product decision, not an engineering one** -- surface it to the human before
touching code. Two acceptable outcomes:
- (a) **Keep the flag**: raise an SRD change request against EDMV3-90 AC1 and AC4, approve it at a
  gate, amend `srd.md:3836-3837` and `tickets/README.md:688`, and record the amendment in
  `decisions.md` alongside D57.
- (b) **Withdraw the flag**: revert `dc8a24f` and `bdab2ac`. This closes CA-423, CA-424, CA-425,
  CA-426, CA-427, CA-428, CA-429, CA-430 and CA-431 in one commit.

In **either** case, re-express both enforcement mechanisms as a **class check** -- any new long
option on `phase-complete`, `archive`, `approve-gate` or `audit-converged` must be justified
against EDMV3-90 -- rather than a name list, so the next bypass flag is caught by the mechanism
instead of by a lens.

**Verification.** `grep -n 'accept-p2-debt' plugins/edm/bin/edm-state` returns either zero hits
(outcome b) or hits plus an amended `srd.md:3836`. Add a wave7 case asserting that every long
option accepted by those four subcommands appears in a named allowlist in `srd.md`.

**Files affected.** `SRD/edm/EDMV3__prompt-streamline/srd.md`,
`SRD/edm/EDMV3__prompt-streamline/tickets/README.md`,
`SRD/edm/EDMV3__prompt-streamline/decisions.md`, `plugins/edm/bin/vocabulary-prohibited.txt`,
`SRD/edm/EDMV3__prompt-streamline/tickets/epics/04-structured-findings.md`.

---

#### CA-424 (P1, L9): T28 AC12 is false for one input class

**Problem.** `epics/04:547-550` states that `cmd_approve_gate <PREFIX> code-audit` *"calls the
check and refuses when it fails"*. `bin/edm-state:2178-2195` now inspects the refusal and, when
`conv_ec -eq 1` with P0=0, P1=0, P2>0 and the flag passed, records convergence anyway. No AC
describes the new branch. Every existing smoke case stays green because the flag-absent path is
unchanged.

**Fix.** Amend T28 AC12 to describe all three input classes explicitly:
(i) refuses without the flag; (ii) refuses **with** the flag when the refusal is not a severity
refusal (partial/unknown round type, invalid JSONL, invalid status lines); (iii) converges with
the flag when the blocking set is open-P2-only. Land the negative ACs together with the tests
that are missing (CA-425). **If CA-423 resolves as (b), this AC needs no amendment.**

**Verification.** `grep -n 'accept-p2-debt' SRD/edm/EDMV3__prompt-streamline/tickets/epics/04-structured-findings.md`
returns the three new AC clauses.

**Files affected.** `SRD/edm/EDMV3__prompt-streamline/tickets/epics/04-structured-findings.md`.

---

#### CA-425 (P1, L4): the entire safety guard has zero tests

**Problem.** The comment at `bin/edm-state:2171-2176` states the property that makes the feature
safe: *"Deliberately narrow: only the genuine 'blocking findings remain' refusal qualifies -- not
a partial/unknown round type, invalid JSONL, or invalid status lines, all of which also exit 1
from `cmd_audit_converged` but say nothing about severity and must not be silently bypassed by
this flag."* **Nothing asserts it.**

`wave6-smoke.sh:657-745` is the complete coverage and covers only the open-P1 refusal, the success
path plus three state fields, the HANDOFF row, archive-immediately, and archive-refuses-stale-debt.
There is no case passing `--accept-p2-debt` against a partial round, malformed JSONL, or an
invalid status line. The two usage `die()` arms at `:2090` and `:2092` are untested.

L4 separately cleared the P0 arm as **transitively covered**: P0/P1/P2 all derive from one shared
`BLOCKING_FILTER` through one `_audit_ledger_breakdown` helper checked in a single condition, so
the open-P1 test also exercises the P0 path.

**Fix.** Add three cases to `wave6-smoke.sh`'s T-EDMV4 block:

```bash
# (a) a partial round is not a severity refusal
"$EDM_STATE" audit-round-start T_P2D code --lenses L1 >/dev/null
"$EDM_STATE" audit-round-complete T_P2D code >/dev/null
check_refuses_and_leaves_state "partial round refuses even with --accept-p2-debt" \
  "$EDM_STATE" approve-gate T_P2D code-audit --accept-p2-debt

# (b) malformed ledger is not a severity refusal
printf '%s\n' 'not json at all' >> "$TMP/SRD/T_P2D/code-audit/findings-ledger.jsonl"
check_refuses_and_leaves_state "invalid JSONL refuses even with --accept-p2-debt" \
  "$EDM_STATE" approve-gate T_P2D code-audit --accept-p2-debt

# (c) the flag is code-audit-only
check_fails "--accept-p2-debt on gate 2 refuses, naming the code-audit restriction" \
  "only applies to the code-audit gate" \
  "$EDM_STATE" approve-gate T_P2D 2 --accept-p2-debt
```

**Sequence AFTER CA-426**, whose fix changes what the guard reads.

**Verification.** `bash plugins/edm/bin/tests/wave6-smoke.sh` -- three new PASS lines; then
deliberately widen the `:2178` prefix test to `*"not converged: "*` and confirm case (a) turns red.

**Files affected.** `plugins/edm/bin/tests/wave6-smoke.sh`.

---

#### CA-426 (P2, lenses L1 + L2, corroborated by L3): engagement test reads a stderr-merged stream

**Problem.** Found **independently by two lenses** and confirmed by a third -- the highest-confidence
signal in this round.

```bash
conv_out="$(cmd_audit_converged "$prefix" 2>&1)" || conv_ec=$?          # :2168
...
if [[ $conv_ec -eq 1 && $accept_p2_debt -eq 1 && "$conv_out" == "not converged: "* ]]; then   # :2178
```

`conv_out` merges stderr into stdout, but the engagement test anchors `not converged: ` at
**position 0**. `cmd_audit_converged` has a warn-and-**proceed** arm at `:4476` that writes to
stderr and then still falls through to the `not converged:` stdout line at `:4522`. That arm fires
whenever `rounds_count -eq 0` -- a legacy initiative, a hand-edited state file, or any
`audit_rounds.code` still in the documented bare-integer shape (`coerce_round_entry` yields
`rounds: []`, so `rounds_count` is 0 **by construction**).

In that state `conv_out` begins with the warning, the prefix test fails, `p2_debt_accepted` stays
`0`, and the `elif` at `:2195` dies with:

```
code-audit gate refused for FOO even with --accept-p2-debt (P0=0 P1=0 must both be 0, or the refusal is not a severity refusal): ...
```

The message asserts P0 and P1 "must both be 0" while printing them **as 0** -- because
`p2_debt_p0`/`p2_debt_p1` still hold their `:2177` initialisers. The operator is told the override
failed for a condition the message itself shows is satisfied, with no way to proceed.

Direction is **safe** (fails closed -- no wrongful convergence), hence P2 rather than P1. The
comment at `:2169-2176` shows the narrowing was deliberate for the *other* exit-1 arms, all of
which return early on stderr and never emit the stdout line -- those work by luck of ordering, not
by design.

**Fix** -- separate the streams, matching the precedent G15/CA-353 already set at `:4514-4522`:

```bash
local conv_out conv_err conv_ec=0 _conv_errfile
_conv_errfile="$(mktemp "${TMPDIR:-/tmp}/edm-state.approve-gate-conv.XXXXXX")"
# register with the same trap pair write_atomic uses -- do NOT add a second untrapped mktemp (CA-399)
conv_out="$(cmd_audit_converged "$prefix" 2>"$_conv_errfile")" || conv_ec=$?
conv_err="$(cat "$_conv_errfile" 2>/dev/null || true)"
rm -f "$_conv_errfile"
```

then test `"$conv_out" == "not converged: "*` against **stdout only**, and interpolate
`${conv_out}${conv_err:+ ($conv_err)}` into the die messages so nothing is lost.

**Second, independent half of the same edit** -- `:2199` must not claim a condition it never
evaluated:

```bash
die "code-audit gate refused for ${prefix} even with --accept-p2-debt: the refusal was not a severity refusal (the override applies only to an open-P2-only blocking set): ${conv_out}"
```

when `p2_debt_json` was never computed; keep the P0/P1-naming form only where the breakdown was
really read.

**Verification.** Seed a state file with `audit_rounds: {"code": 3}`, run
`approve-gate <PFX> code-audit --accept-p2-debt`, and confirm the override now engages (rather
than dying with the self-contradictory message). Requires CA-427 in the same commit.

**Files affected.** `plugins/edm/bin/edm-state`, `plugins/edm/bin/tests/wave6-smoke.sh`.

---

#### CA-427 (P2, lenses L1 + L3): both new round-number reads bypass the coercion constant

**Problem.** Also found by **two lenses independently**.

```bash
p2_debt_round="$(echo "$state_json" | jq -r '.audit_rounds.code.count // 0')"   # :2212
debt_round_now="$(echo "$state_json" | jq -r '.audit_rounds.code.count // 0')"  # :3016
```

`AUDIT_ROUND_COERCE_JQ_DEF`'s docstring at `:1474-1483` states the rule categorically: *"no legacy
file is rewritten (AC1a), so **every reader** of `audit_rounds.<type>` pipes the raw value through
this one jq `def` first"*, and `CLAUDE.md`'s state-field table restates it as the C-4 contract.
Every pre-existing reader obeys it (`:1604`, `:1624`, `:3323`, `:4232`, `:4240`, `:4308`, `:4331`,
`:4457`). These two are the **only** exceptions in the file.

On a legacy bare-integer `audit_rounds: {"code": 3}` -- the shape `:1476` says the archived EDMV2
fixture literally carries -- jq raises `Cannot index number with "count"` and exits 5. The trailing
`// 0` does **not** rescue it: per the jq 1.7 manual, `//` filters only `false`/`null` and has no
error-suppression semantics (that is `?`/`try`). Under `set -euo pipefail` the assignment aborts
`edm-state` with a raw jq error naming neither the command nor the cause.

**Latent today only because CA-426's prefix bug masks the path.** Fixing CA-426 **un-latches this
one** -- the two must land in the same commit, or the CA-426 fix converts a confusing refusal into
a jq crash.

**Fix** -- both sites, identical shape, reusing the constant already in scope:

```bash
p2_debt_round="$(echo "$state_json" | jq -r "${AUDIT_ROUND_COERCE_JQ_DEF} (.audit_rounds.code // 0 | coerce_round_entry).count")"
```

Consider a shared `_audit_round_count <state-json> <type>` helper so the fourth reader cannot
diverge again. Add the wave6 case seeding `jq '.audit_rounds = {"code": 2}'` before
`approve-gate ... --accept-p2-debt`, asserting `code_audit_p2_debt_round == 2` -- the same
bare-integer fixture `wave6-smoke.sh:3075` and `:3955` already use.

**Verification.** As CA-426. Both sites must be covered: `:2212` (approve-gate) and `:3016`
(archive).

**Files affected.** `plugins/edm/bin/edm-state`, `plugins/edm/bin/tests/wave6-smoke.sh`.

---

#### CA-428 (P2, L3), CA-429 (P2, L11), CA-430 (P2, L9), CA-431 (P2, L9)

- **CA-428** -- `bin/edm-state:3015-3017` compares two jq-derived values with `[[ -eq ]]` without
  `to_int`. `to_int`'s docstring (`:109-114`) is unambiguous: *"Every value from any external
  source ... that reaches an arithmetic context MUST pass through here first (CA-157)"*, with a
  confirmed bash-3.2.57 reproduction. `.edm-state.json` is a committed, shared artifact that
  arrives from git, a merge conflict, or a hand edit.
  **Fix**: `debt_round_at_accept="$(to_int "$(... jq -r '.code_audit_p2_debt_round // -1')" -1)"`
  and the equivalent for `debt_round_now` (after CA-427's coercion). Land in the same commit.
- **CA-429** -- `code_audit_p2_debt_accepted_at` / `_accepted_by` (`:2222-2223`) have **zero**
  readers tree-wide. They are byte-identical duplicates of `code_audit_gate_approved_at` (`:2215`)
  and `code_audit_gate_approver` (`:2216`), written 7 lines earlier from the same `--arg` bindings,
  and *those* are read at `:1649`, `:3444` and `:5323-5324`.
  **Fix**: drop both assignments; update `CLAUDE.md:241`, `docs/canonical-sections.md:38` and
  `skills/code-audit/SKILL.md:190` to list the three surviving keys. Or give the pair a reader in
  the same commit -- the natural one is HANDOFF's debt row at `:5329-5332`.
- **CA-430** -- no ticket in any pack; `T-EDMV4` resolves to nothing (`SRD/**/EDMV4*` matches zero
  paths). **Fix**: open a real ticket with the four ACs named in CA-424, or fold into CA-423(b).
- **CA-431** -- no CHANGELOG entry, no version bump (`plugin.json:4` is still `3.1.0`), and the
  five new state fields are absent from `CLAUDE.md`'s state-field table, whose own preamble claims
  it *"is the whole state-field reference"*. **Fix**: add the CHANGELOG entry, bump the version,
  add the table rows with their absent-value (C-4) semantics.

---

### WORK ITEM 2 -- regressions from this session's own remediation

These are **quick, low-risk, mechanical fixes**. Every one is a defect introduced by a fix that
landed between round 7 and round 8. They should land first, before anything else, because they are
cheap and because two of them (CA-433, CA-438) currently leave safety guards inert.

#### CA-432 (P2, L3): `EDM_STATE_LOCK_WAIT_S` is unvalidated -- from the CA-397 fix

**Problem.** `bin/edm-state:1099-1100`:

```bash
EDM_STATE_LOCK_WAIT_S="${EDM_STATE_LOCK_WAIT_S:-10}"
EDM_STATE_LOCK_MAX_TRIES=$(( EDM_STATE_LOCK_WAIT_S * 10 ))
```

These run at **top level** under `set -euo pipefail` (`:54`), so they execute on every invocation
of every subcommand -- including read-only ones -- and on every `source` of the file, which the
smoke suites do.

- `EDM_STATE_LOCK_WAIT_S=0.5` (the obvious value for a sub-second test wait; `flock -w` accepts
  fractional seconds): bash arithmetic rejects it, the assignment returns non-zero, `set -e`
  aborts. `edm-state get`, `validate`, `--help` -- everything -- **dies at load** with a raw bash
  error and no diagnostic.
- `EDM_STATE_LOCK_WAIT_S=abc`: `flock -w abc` fails immediately, so `:1229` creates the timeout
  marker and exits 99, and the parent dies with *"state lock timeout after abcs"* -- a fabricated
  timeout on the **first** attempt with zero contention.

The file establishes the opposite convention twice under the CA-160 rule (`HUMAN_HOURLY_RATE_USD`
at `:84-85`, `EDM_TOKEN_READ_LINE_CAP` at `:393-394`). The comment at `:1097` **explicitly
advertises this knob for testing**, yet no test sets it -- so the first person to use it as
documented hits this.

**Fix** -- one line, immediately after `:1099`:

```bash
[[ "$EDM_STATE_LOCK_WAIT_S" =~ ^[1-9][0-9]*$ ]] \
  || die "invalid EDM_STATE_LOCK_WAIT_S: '${EDM_STATE_LOCK_WAIT_S}' (expected a positive whole number of seconds)"
```

**Verification.** `EDM_STATE_LOCK_WAIT_S=0.5 edm-state --help` must print the named `die` message,
not a raw bash arithmetic error. `EDM_STATE_LOCK_WAIT_S=abc edm-state validate <PFX>` likewise.

**Files affected.** `plugins/edm/bin/edm-state`, `plugins/edm/bin/tests/wave7-smoke.sh` (add the
two refusal cases -- this knob has no test today).

---

#### CA-433 (P2, L3): the CA-169 inode-safety guard now passes vacuously -- from the CA-397 fix

**Problem.** `wave7-smoke.sh:4904-4912`:

```bash
t_g53_flock_line="$(awk '/^    \( flock -w 10 200/{print NR; exit}' "$EDM_STATE")"
t_g53_ca169_line="$(awk '/# CA-169: never `rm -f/{print NR; exit}' "$EDM_STATE")"
t_g53_before_flock="$(sed -n "${t_g53_ca169_line:-1},${t_g53_flock_line:-1}p" "$EDM_STATE")"
```

The CA-397 fix rewrote `bin/edm-state:1229` from `( flock -w 10 200 ...` to
`( flock -w "$EDM_STATE_LOCK_WAIT_S" 200 ...`. The awk anchor no longer matches, so
`t_g53_flock_line` is **empty**, `${...:-1}` substitutes `1`, and `sed -n "1175,1p"` (addr2 below
addr1) emits **one line** -- the CA-169 comment itself.

All three assertions still **pass**, vacuously: the extracted line contains `CA-169`, contains
`never`, and does not contain the braced `rm -f` literal (the comment writes it unbraced). The
guard that exists to stop a future round from "cleaning up" the deliberately-never-unlinked flock
file -- the file whose unlinking breaks inode-keyed mutual exclusion outright -- now inspects one
line instead of a ~55-line range and **cannot fail**.

**This is the second recurrence.** G38/CA-314 already fixed this same assertion once, for the same
reason, and the fix chosen then re-broke on the next edit to the anchored line.

**Fix** -- anchor on something that does not encode the timeout value, **and** fail loudly:

```bash
t_g53_flock_line="$(awk '/^    \( flock -w /{print NR; exit}' "$EDM_STATE")"
[[ -n "$t_g53_flock_line" ]] || fail "G53 -- could not locate the flock() call; anchor is stale"
[[ -n "$t_g53_ca169_line" ]] || fail "G53 -- could not locate the CA-169 comment; anchor is stale"
```

**Verification.** Temporarily rename the flock call and confirm the suite now **fails** with the
named "anchor is stale" message rather than passing.

**Files affected.** `plugins/edm/bin/tests/wave7-smoke.sh`.

---

#### CA-434, CA-435, CA-436, CA-437, CA-438

- **CA-434** (L2, from CA-395) -- `wave7-smoke.sh:195-211`'s tripwire outlived its subject. Its
  pass message at `:210` asserts the function *"is called only from harness-smoke.sh's
  self-tests"*; there are now zero self-tests, zero call sites and no function. Its fail arm
  cannot fire: a new call would be a call to an undefined function, aborting under `set -e` with
  exit 127 first; and the one edit that *would* reintroduce the class is excluded at `:208`.
  `_harness.sh:183` and `harness-smoke.sh:135,137` still direct callers to the deleted helper.
  **Fix**: delete `:195-211` (or repoint it at `_harness.sh` alone and rewrite the false pass
  message), and repoint the three doc references at `count_matches_strict` / `assert_tree_absent`.
- **CA-435** (L6, from CA-406) -- `wave7-smoke.sh:7836-7838` justifies an allowlist entry by
  describing a `hooks.json:117` quote in `edm-check-grants` that CA-406 deleted. No line in
  `bin/edm-check-grants` matches `g10_citation_regex` today, so `g10_allowlist_2` filters nothing.
  **Fix**: drop `g10_allowlist_2`, its use at `:7848` and its synthetic control at `:7874`, and
  reword `:7834-7839` to name only `.gitlab-ci.yml:198`.
- **CA-436** (L8, from CA-380, **medium confidence -- unconfirmed by execution**) --
  `lint:hooks-shell` is blocking and scoped to SC2086/SC2046/SC2048/SC2068, and `hooks.json:86`
  contains `for p in $prefixes` and `exit $fail`, both canonical SC2086 shapes. A
  `# shellcheck disable` directive **cannot be added**, because the hook is a single
  `;`-separated line inside a JSON string. **Fix, in order**: (1) run
  `jq -r '.hooks | to_entries[] | .value[] | .hooks[] | select(.type=="command") | .command' plugins/edm/hooks/hooks.json | shellcheck --shell=sh --include=SC2086,SC2046,SC2048,SC2068 -`
  **before first enablement**. If it reports, either have the job prepend
  `# shellcheck shell=sh` + `# shellcheck disable=SC2086` to each written `cmdfile`, or take
  CA-380's *first* option and extract to `bin/edm-lint-staged-artifacts` -- **which also closes
  CA-413 and CA-414 in the same edit** and is the highest-leverage route.
- **CA-437** (L8, from CA-380) -- the job newline-splits extracted commands, so a multi-line
  `.command` is checked as N independent fragments and `COUNT` over-reports. All nine current
  commands are single-line, so no live defect -- but the backstop mis-parses exactly the case most
  in need of checking. **Fix**: NUL-delimit the extraction (`jq -j` emitting `\0`, read with
  `read -r -d ''`), and assert `COUNT` equals the jq length of the command-type hook array.
- **CA-438** (L8, residue of CA-415) -- the corrected fd-200 rationale landed; the durability pin
  did not. `grep -rn 'CA-415\|BASH_XTRACEFD' plugins/edm/bin/tests/` returns **zero**. Nothing
  fails if the comment is shortened back to the wording that produced CA-415. **Fix**: assert
  `with_state_lock`'s region contains `BASH_XTRACEFD` and `Do not lower this`, plus a
  `check_absent` for a flock redirection on any fd below 100. **Sequence after CA-433**, or this
  pin inherits the same anchor fragility.

---

### WORK ITEM 3 -- P1s outside the accept-p2-debt cluster

#### CA-440 (P1, L3): concurrent QC auditors overwrite `qc/qc-summary.md`

**Problem.** `skills/implement/SKILL.md:35` spawns **6-10 `edm-implementer` agents in parallel per
wave**. `:37` states the `SubagentStop` hook fires *after each implementer completes* and
auto-spawns an `edm-qc-auditor`. The hook prompt (`hooks.json:117`, step 5) instructs every one of
those auditors, unconditionally, to *"Write the QC report to `<initiative-dir>/qc/qc-summary.md`"*
-- one fixed path, full-file `Write` semantics, no shard suffix, no append, no lock, no merge.

When two or more implementers in a wave finish close together (the **normal** case for a wave of
independent tickets), N auditors write the same path and the last writer wins. Step 5 of the skill
(`:114`) then *"Compile all FAIL findings from `qc/qc-summary.md`"* -- so the FAIL verdicts of
every overwritten auditor are **silently absent from remediation**. They are never persisted
anywhere else: only PARTIALs reach state via `record-partial-verdict` (which *is* correctly
locked); PASS and FAIL live only in that markdown file.

The shard mechanism at `SKILL.md:84-99` is a **different path** -- skill-orchestrated, keyed on
ticket count vs `qc_shard_threshold`, run "after all implementer waves complete", with an explicit
merge. The authors solved the multi-writer collision for the skill path and left the hook path
exposed.

**Relationship to CA-411 (open, L7).** Same hook site, **different defect class**. CA-411 frames
it as a config-consistency gap; this is concurrent full-file overwrite causing silent verdict loss,
and it is what makes CA-411's fix load-bearing rather than cosmetic. **Cross-linked, not merged,
and not demoted to CA-411's P2.**

**Fix** -- one edit to one JSON string, closing **CA-440 + CA-411 + CA-412** together:
- Give the hook prompt a per-subagent unique output path: *"write `qc/qc-shard-<ticket-id>.md`;
  if you were given no assigned ticket range, write `qc/qc-summary.md`"* (this also satisfies
  CA-411's shard-awareness requirement).
- Add a **step 0** naming where `<PREFIX>` comes from -- the epic file read at step 1, or the
  `{PREFIX}-T{NN}` ticket IDs in the implementer's commit messages (CA-412).
- Have `/edm:implement` Step 4 merge every `qc/qc-shard-*.md` into `qc-summary.md` once the wave
  drains -- **the merge step already exists at `SKILL.md:98`**.
- Update `CLAUDE.md:686`'s hooks-table cell to name both outputs.

Alternative: serialise by having the auditor append under an `edm-state`-mediated lock. Either
way, do not leave a single fixed path written by 6-10 concurrent agents.

**Verification.** Run `/edm:implement` on a wave of 3+ independent tickets where at least two
auditors return FAIL, and confirm both FAILs reach Step 5's remediation list. Add a wave7 case
asserting the `SubagentStop` prompt string contains a shard-path token and a `<PREFIX>` derivation
instruction.

**Files affected.** `plugins/edm/hooks/hooks.json`, `plugins/edm/skills/implement/SKILL.md`,
`plugins/edm/CLAUDE.md`, `plugins/edm/bin/tests/wave7-smoke.sh`.

---

#### CA-441 (P1, L7): three testing skills spawn agents without `Task`

**Problem.** `skills/test/SKILL.md:8`, `skills/test-plan/SKILL.md:8` and
`skills/test-coverage/SKILL.md:8` all omit `Task` from `allowed-tools`, while all eight Phase-1..6
agent-spawning skills grant it. `skills/test` spawns **10** agents (`edm-test-planner` `:46`,
`edm-test-scaffold` `:72`, seven writers `:90-96`, `edm-test-coverage-auditor` `:125`);
`test-plan` spawns one (`:39`); `test-coverage` spawns one (`:38`).

Per `CLAUDE.md` Sec."Skills are the source of truth for orchestration", grants are **not inherited
from a caller** -- the callee's own `allowed-tools` governs. So as written, `/edm:test`,
`/edm:test-plan` and `/edm:test-coverage` cannot spawn anything.

`bin/edm-check-grants` **structurally cannot catch this**: source 4 (`scan_skill_tool_usage`,
`:454-480`) is scoped to `AskUserQuestion` only, and source 2 cross-references *agent* grants,
never the skill's own.

**Fix.**
1. Add `Task` to `allowed-tools` in all three SKILL.md frontmatter lines (one line each).
2. Extend `edm-check-grants` source 4 with a second positive rule: a skill body containing a spawn
   instruction (`Spawn `/`Agent:`/`spawn ... edm-`) whose `allowed-tools` lacks `Task` is a
   `missing-task-grant` violation -- otherwise the next skill added has the same hole.

**Verification note.** Confirm at runtime whether `allowed-tools` is actually enforced for `Task`
in the pinned Claude Code version (CI pins 2.1.226; `README.md:87-103`'s matcher observations are
dated against 2.1.220) before concluding these three skills are hard-broken rather than merely
inconsistent. **The frontmatter fix is unconditional either way** -- three skills should not differ
from their eight siblings.

**Verification.** `bash plugins/edm/bin/edm-check-grants` reports the new rule with zero
violations; run `/edm:test-plan <PREFIX>` and confirm the planner agent spawns.

**Files affected.** `plugins/edm/skills/test/SKILL.md`, `plugins/edm/skills/test-plan/SKILL.md`,
`plugins/edm/skills/test-coverage/SKILL.md`, `plugins/edm/bin/edm-check-grants`.

---

#### CA-460 (P1, lenses L6 + L7 + L2): CI job inventory and both job-graph counts are stale

**Problem.** Three lenses. `lint:hooks-shell` (CA-380's own remediation) landed without updating
**any** of the three sources that enumerate the lint jobs.

`.gitlab-ci.yml` defines **eight** lint jobs: `lint:bash-syntax` (`:85`), `lint:artifacts`
(`:154`), `lint:grants` (`:175`), `lint:vocabulary` (`:194`), `lint:shellcheck` (`:227`),
**`lint:hooks-shell` (`:275`)**, `lint:file-type-ban` (`:322`), `lint:pattern-library-contract`
(`:370`). `<<: *alpine_edm` has **eleven** consumers (`:87, :156, :177, :196, :229, :277, :324,
:372, :425, :496, :545`).

- `CLAUDE.md:1013-1019` has **no row** for `lint:hooks-shell`; `:1032` says "all seven
  concurrently"; `:1036` says "all ten consumers".
- `.gitlab-ci.yml:56-58` says "seven of them today ... ten consumers total" **and names the exact
  `grep -c` command whose output (11) contradicts the number it states (10)**.
- `.gitlab-ci.yml:78-82`'s "the lint stage has since grown three more the same way" list omits the
  fourth one grown the same way.

**Why P1**: `lint:hooks-shell` is **blocking** (`needs: []`, no `allow_failure`) and is the only
job that lints the plugin's most privileged shell -- every command-type hook string in
`hooks/hooks.json`. That surface has a blocking gate invisible in contributor-facing documentation.
And the anchor comment exists specifically so a digest refresh is a single-line change across all
consumers -- a stale consumer count defeats its own stated purpose.

**Fix.**
1. Add to `CLAUDE.md`'s CI job table:
   `| lint | lint:hooks-shell (CA-380) | Yes | bash -n + shellcheck --shell=sh over every command-type hook command string in hooks/hooks.json |`
2. `CLAUDE.md:1032` "all seven" -> "all eight"; `:1036` "all ten consumers" -> "all eleven consumers".
3. `.gitlab-ci.yml:56-58` "seven of them today" -> "eight of them today"; "ten consumers total" ->
   "eleven consumers total"; `:78-82` "grown three more" -> "grown four more" and add
   `lint:hooks-shell` to the parenthetical.
4. **Make it self-maintaining** -- reuse `wave7-smoke.sh`'s existing blocking-job derivation
   (`:4580-4615`) to assert every `stage: lint` job key appears as a row in `CLAUDE.md`'s CI table,
   and compare `grep -c '^lint:'` and `grep -c '<<: \*alpine_edm'` against the numbers the
   paragraphs state, in the shape `:4296` already uses.

**Verification.** `grep -c '^lint:' .gitlab-ci.yml` -> 8; `grep -c '<<: \*alpine_edm' .gitlab-ci.yml`
-> 11; both new assertions PASS in `wave7-smoke.sh`; then add a dummy lint job and confirm the
suite turns red.

**Files affected.** `plugins/edm/CLAUDE.md`, `.gitlab-ci.yml`, `plugins/edm/bin/tests/wave7-smoke.sh`.

---

#### CA-461 (P1, L6): the baseline runbook prescribes a field name nothing reads

**Problem.** `evals/baseline/README.md:91-104` instructs the operator to arm the eval tripwire by
adding:

```json
"variance": {
  "total_max_minus_min": 0.0,
  "per_dimension_max_minus_min": { }
}
```

`bin/edm-compare-eval:102` reads `jq -r '.variance.total_range // 0'`. The string
`total_max_minus_min` occurs **nowhere else in the repository**, and nothing consumes
`per_dimension_max_minus_min`. `edm-compare-eval`'s own help header (`:14-16`) and
`CLAUDE.md:785` both name `variance.total_range`.

**Why P1**: an operator following this runbook *exactly* arms the tripwire with the documented
"a missing variance record is treated as 0 -- strict" fallback silently engaged. Every subsequent
run then compares against `threshold = baseline.total - 0`, so ordinary run-to-run noise is
reported as `REGRESSION` (exit 1), with a `variance allowed: 0` line on screen that looks
deliberate rather than like a misconfiguration. This is the **one** document that tells a human how
to arm the tripwire, and it costs **three live eval runs** to find out.

**Fix.** Change the example to `"variance": { "total_range": 0.0 }`; either rename
`per_dimension_max_minus_min` to something a consumer will read, or state plainly that nothing
consumes it today. **Durability**: assert in the smoke suite that the field name in the README's
JSON example equals the jq path in `bin/edm-compare-eval` (the two strings must be equal), with a
positive control.

**Verification.** `grep -o 'total_[a-z_]*' plugins/edm/evals/baseline/README.md` and
`grep -o '\.variance\.[a-z_]*' plugins/edm/bin/edm-compare-eval` must agree.

**Files affected.** `plugins/edm/evals/baseline/README.md`, `plugins/edm/bin/tests/wave7-smoke.sh`.

---

#### CA-462 (P1, L11): the tiny-svc ground truth has no consumer

**Problem.** `evals/fixtures/tiny-svc/expected.json` enumerates six known, countable gaps
(GAP-01..GAP-06) in the frozen eval subject, carries a version contract, and is cross-referenced by
five source-file comments plus `evals/README.md:277`. **Nothing executable reads it**: neither
`score-artifacts.sh` nor `run-eval.sh` nor `bin/edm-compare-eval` nor any smoke suite contains the
string `expected.json`, `GAP-0`, or any case-insensitive reference to it. All five scorer
dimensions are computed over the run's **own output files**.

The fixture README states the intended wiring in so many words (`:22-25`): the gaps *"are
enumerated in `expected.json` alongside this README **so the eval scorer (`score-artifacts.sh`,
EDMV3-T23) has ground truth to check a produced SRD against, rather than only a self-consistency
check.**"* The named consumer is in scope, exists, and does not consume it.

**Why P1**: this is load-bearing for the **only** automated regression detector this initiative has
for prompt quality. `eval:nightly` feeds `scores.json` to `edm-compare-eval` against a committed
baseline; because no dimension consults ground truth, an eval run whose SRD surfaces **zero** of
the six known gaps can score **identically** to one that surfaces all six. `CLAUDE.md:345` already
records that the baseline itself is uncaptured, so nothing else compensates.

**Fix.** Add a sixth scorer dimension, `known-gap-recall`, to `score-artifacts.sh`: read
`fixtures/tiny-svc/expected.json` and, for each `GAP-NN` entry, grep the run's `srd.md` for its
declared marker (add an `id`/`match` regex field to each entry for this purpose), scoring
`100 * matched/total`. It **must** follow the file's existing skip contract -- emit `score: null`
and a `dimensions_skipped` reason when the run directory is not the tiny-svc fixture -- and it
**must** bump `scorer_version` so `edm-compare-eval`'s version handshake (`:81`) refuses to compare
across the change rather than silently mixing five- and six-dimension totals.

If a sixth dimension is out of scope, the honest alternative is to correct
`evals/fixtures/tiny-svc/README.md:22-25` and `evals/README.md:277` to state that `expected.json`
is human-reference-only -- but that leaves the tripwire blind, so wiring it is the better route.

**Verification.** `bash plugins/edm/evals/score-artifacts.sh <run-dir>` emits six dimensions;
delete one gap's marker from a synthetic `srd.md` and confirm the dimension score drops.

**Files affected.** `plugins/edm/evals/score-artifacts.sh`,
`plugins/edm/evals/fixtures/tiny-svc/expected.json`, `plugins/edm/bin/edm-compare-eval`,
`plugins/edm/evals/README.md`, `plugins/edm/bin/tests/wave7-smoke.sh`.

---

#### CA-416 (P1, L9 -- escalated from P2): no same-commit spec/AC sweep obligation

**Problem.** Verified again this round: **no** `spec/AC text swept in same commit` field, or any
equivalent, exists anywhere in `plugins/edm/`. The synthesizer's Findings Ledger Format field rules
(`agents/edm-audit-synthesizer.md:159-168`) enumerate only `id`, `status`, `confidence`, `lenses`,
`raised_round`, `resolved_round`. The Remediation Plan Format (`:87-147`) carries
Problem / Fix / Verification / Files affected and no doc-sweep obligation.

**Escalated to P1** because it is the named structural root cause of the stale-citation class, it
is in its second round unbuilt, and the class produced **four fresh instances this round**:
CA-468, CA-469, CA-470 and CA-431 -- the **fifth consecutive round**.

**Fix.** Add a mandatory `spec_swept` field (`yes` / `no` / `n-a`) to the findings-ledger entry
template **and** to the synthesizer's Remediation Plan Format, and have the remediation gate refuse
to mark a wave done while any `fixed` entry carries `no`.

**Verification.** `grep -c 'spec_swept' plugins/edm/agents/edm-audit-synthesizer.md` >= 2; a
synthetic ledger entry with `spec_swept: no` must block the wave.

**Files affected.** `plugins/edm/agents/edm-audit-synthesizer.md`,
`plugins/edm/skills/code-audit/SKILL.md`, `plugins/edm/bin/tests/wave7-smoke.sh`.

---

### WORK ITEM 4 onward -- P2 detail

Full problem statements, evidence and concrete fixes for every remaining P2 are recorded in the
ledger at `SRD/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl` (one line per
finding, `CA-401`..`CA-471`). They are grouped for rollout below. The highest-leverage groupings:

- **Trap hygiene (CA-446 + CA-447)** -- two lenses, overlapping file set, one pass. CA-446 is
  "the trap does not `exit` on a signal, so the caller resumes and reports a fabricated verdict";
  CA-447 is "six traps omit HUP against the CA-150 precedent". Fix both across
  `edm-sync-canonical-sections:84`, `edm-lint-artifacts:141`, `edm-check-grants:127`,
  `wave7-smoke.sh:25`, `harness-smoke.sh:264`, `_harness.sh:85,:113` in one commit, and rewrite
  `edm-check-grants:125-126`'s comment to state the actual convention rather than a floor.
- **Unvalidated env knobs (CA-432 + CA-443 + CA-444)** -- one convention (CA-160), three sites,
  one commit. All three currently fail in a direction that is silent or misleading.
- **`eval:nightly` reports green having evaluated nothing (CA-443 + CA-452)** -- two independent
  routes to the same false-green outcome.
- **Bare count captures (CA-401 + CA-459)** -- one class, two directions. CA-401 is the
  suite-abort direction (`set -e` kills the run); CA-459 is the false-pass direction (grep exit 2
  swallowed, assertion passes as "absent"). Both fix by routing through
  `count_matches` / `count_matches_strict`; CA-459 additionally needs a new
  `assert_count_with_control` helper for the "expect exactly N" family.
- **The one-string hook edit (CA-440 + CA-411 + CA-412)** -- three findings, one JSON string.
- **The hook-extraction route (CA-436 option b + CA-413 + CA-414)** -- extracting `hooks.json:86`'s
  body to `bin/edm-lint-staged-artifacts` closes all three at once and is the single
  highest-leverage refactor available this round.
- **Stale spec/AC text (CA-468 + CA-469 + CA-470)** -- three ticket-pack edits, one commit,
  all downstream of CA-416.

---

## Decisions / Non-Findings

These items were flagged by one or more lenses but determined **Not Actionable**. Future audits
should **not** re-investigate them.

1. **L8 flagged `eval:nightly` uploading `raw/*.stderr.log` for 30 days from the one
   secret-bearing job** -- Low confidence, single lens; synthetic fixture, no known CLI path echoes
   the key. **NOTED**.
2. **L4-05's `:1710` sub-item (grep -c vs occurrence count)** -- Pattern is `^- \`` , anchored at
   line start; at most one match per line, so no off-by-one is possible. **False alarm.**
3. **L4-05's `:1718` sub-item (`grep -ci 'defer'` unanchored)** -- Threshold is exactly zero, so
   over-matching can only cause a false *failure*, never a false pass. **False alarm.**
4. **L4-02's `:2768` / `:2824` self-match sub-items** -- Both build needles from two runtime
   halves, so the contiguous phrase never appears in the file's own source. **Already handled.**
5. **L4: `--accept-p2-debt`'s P0 arm has no dedicated test** -- Transitively covered: P0/P1/P2
   derive from one `BLOCKING_FILTER` through one helper checked in a single condition.
6. **L1: `required_gates_for_mode` empty output conflates "died" with "legitimately zero"** --
   Tradeoff argued explicitly at `edm-state:5188-5191`; requires two simultaneous hand edits.
7. **L2-N02: `mermaid_line_set` / `marker_line_set` have zero callers** -- Documented at
   `_edm-lint-lib.sh:56-65` as retained for API completeness. Filter 2.
8. **L2-N03: `.lock.timeout.*` sweep loops cannot match a current-version marker** -- Deliberate
   pre-G17 backward-compat, test-covered by a planted synthetic marker. Filters 1 and 2.
9. **L2-N04: `lifecycle_mode == "partial"` branch is unwritable by `set-mode`** -- Reachable from a
   pre-D12 state file; documented C-4 read-compat.
10. **L2-N05: `score_from_ratio`'s `d <= 0` arm unreachable from all six callers** -- General
    library guard with a documented contract; deliberately *not* the CA-393 shape.
11. **L2-N06 / L2-N07: dead `-n "$f"` conjunct and unreachable `-z "$max_num"` half** -- Zero-cost;
    in the latter case the sibling half is genuinely reachable.
12. **L2-N09: `grep -c ${x:-0}` fallbacks at `score-artifacts.sh:484`, `.gitlab-ci.yml:389/:406`** --
    The CA-140/CA-202/CA-260 class already accepted in-tree.
13. **L2-N10: `edm-init:121`'s `-d $DIR` collision guard is preempted** -- Reachable when
    `edm-validate-prefix` is off PATH, and closes a TOCTOU window.
14. **L3: `approve-gate --accept-p2-debt`'s unlocked read-to-write window** -- Closed downstream:
    `cmd_archive` re-verifies P0/P1 at `:3021` and a stale debt round fails closed at `:3017`.
15. **L3: TMPDIR timeout marker leaks one empty directory on SIGKILL** -- Bounded to one empty dir,
    reclaimed on the next run with that PID, cannot manufacture a false timeout.
16. **L3: mkdir branch's effective timeout slightly exceeds `EDM_STATE_LOCK_WAIT_S`** -- Nominal
    parity is what CA-397 asked for; sub-second parity between two backends is not achievable.
17. **L3: `_harness.sh:113` interpolates a `local` into a trap that can outlive the function** --
    Test-only path; `:142` clears the trap on the normal return.
18. **L3: `wave7-smoke.sh:5806`'s comment names the pre-CA-396 marker shape** -- Comment-only, in a
    test that deliberately exercises the legacy name; no assertion depends on it.
19. **L5-N1: `run-eval.sh --provision-only` retains its scratch git repo** -- The mode's entire
    contract is to print a path for inspection; deleting it makes the mode useless.
20. **L5-N2: `docs/audit-patterns/<type>.lock` persists in the tracked tree** -- CA-169 design;
    covered twice by root `.gitignore` (lines 15 and 35); `git status` stays clean.
21. **L5-N5: root `.gitignore` justification comments name the pre-G17 in-tree marker path** --
    Comment accuracy only; the widened globs remain correct and wanted.
22. **L5-N6: bare `mktemp -d` in `.gitlab-ci.yml:287,:558` and untrapped `LIST_FILE` at `:509`** --
    Container-ephemeral, with traps or trivial scope; no accumulation.
23. **L6-N1: Unicode em dash in `CHANGELOG.md:7`** -- Documented carve-out from the shipped-surface
    ASCII sweep (`wave7-smoke.sh:4844-4846`).
24. **L6-N2: `run-all.sh:71`'s "~830 assertions" undercounts (~980 today)** -- Explicitly
    approximate and illustrative; no behavior depends on it.
25. **L6-N3 / N4 / N5 / N6 / N7 / N8** -- Mermaid touch-point count correct and conservative;
    `edm-compare-eval:82`'s "can weight differently" is about future scorer freedom;
    `evals/README.md:7`'s "three parts" are named inside two rows; `Sec."10. Convergence gate"`
    resolves unambiguously and is generated; repo-root `CLAUDE.md:7` is a deliberate
    simplification; `README.md:87-103` self-dates and self-versions and asks for reconfirmation.
26. **L7-N01: `set -uo pipefail` in `evals/` and `run-all.sh` vs `set -euo pipefail` in `bin/`** --
    Documented rationale at each site. Filters 1 and 3.
27. **L7-N02 / N03 / N04 / N05 / N06** -- `argument-hint` quoting parses identically;
    `disallowedTools` key order is not semantic; the `maxTurns` spread is documented in two
    inventory tables; the `## Scope` clause's adopting set is coherent; the `[EDM]` vs
    script-name diagnostic prefixes are two internally-uniform layers.
28. **L8-N01: CA-381 (`$ARGUMENTS` validated after the sink)** -- Remains NOTED per its recorded
    disposition; both proposed fixes were empirically tested and neither is correct without first
    settling the host's argument-delivery mechanism. *(Housekeeping: that disposition's own
    "Deferred pending..." wording conflicts with the severity vocabulary's abolition of deferral --
    reword the disposition text, do not re-investigate the finding.)*
29. **L8-N02: placeholder image digests and floating `bash:3.2` tag** -- Already CA-111 (NOTED),
    documented in the file header and `CLAUDE.md`.
30. **L8-N03: the `deferred` status token is not a convergence bypass** -- `BLOCKING_FILTER`
    includes it and `coerce_status` rewrites it to `open` before any count. Verified good.
31. **L8-N04: bare `Bash` on auto-spawned / implementer / test-writer agents** -- Documented
    compensating rationale (D17 spike); cross-checked by `edm-check-grants`.
32. **L8-N05: the only `eval()` in production code** -- Operates on bash's own `trap -p` output;
    no external data reaches it.
33. **L8-N09 / N10: `acceptEdits` + prefix `Bash` matchers; prompt visible in the process table** --
    Both accurately documented as bounded tradeoffs; `bypassPermissions` deliberately unused;
    prompt content is frozen fixture text.
34. **L8-N11: hardcoded developer-machine paths in `CLAUDE.md:384`** -- Licence-provenance record
    documenting a local clone inspection; naming the machine is the point.
35. **L8-N12: `for p in $prefixes` word-split, `ENVIRON`-passing awk, per-command env prefix** --
    All intentional and correct with compensating controls. *(The linter's reaction is separate:
    CA-436.)*
36. **L8-N13 / N14: systemd sandboxing, SQL injection, SSRF, cryptographic failures** -- Categories
    not applicable; no unit files, no database, no caller-supplied-URL client, no stored secret.
37. **L10-N03: `_unpack_token_fields` residual is a 10-line byte-identical block** -- Held NOTED
    out of respect for two deliberate acceptances, but **flagged as inconsistent with CA-344's P2
    for the same class**: if CA-344's five are batched, include this.
38. **L10-N04 / N05 / N06 / N07 / N08 / N09 / N10 / N12 / N13 / N14 / N16** --
    `check_refuses_and_leaves_state` duplication is the CA-042 fix; `count_matches` vs
    `count_matches_strict` difference *is* the point (CA-145); per-script `die()` is a pinned
    deliberate matrix; hasher preference order is cosmetic; JSON has no include mechanism;
    `SRD_ROOT` resolution is per-entry-point; the two lock-name sweeps diverge deliberately;
    `_scan_mermaid_blocks` shares the awk rules file; `add_related`'s jq is genuinely different
    work; `edm-validate-prefix` cannot source the resolver without inverting the dependency;
    `edm-check-vocabulary` vs `_lint_report_class_hits` are genuinely different designs.
39. **L10-N15: CA-283 (three phase blocks in `run-eval.sh`)** -- Carried NOTED and **not re-checked
    this round**; recorded as *unaudited, not clean*.
40. **L11-N1..N11: `git-lock-check`, six operator-run subcommands, `init`/`record-branch`, the two
    advisory `WARN_UNUSED` keys, all 30 agents, all 20 `userConfig` keys, all five hook event
    families, nine further state keys, `timing.sh`/`tiering-matrix.sh`, six template/fixture
    files** -- All verified wired or documented as intentionally human-invoked. Filter 1.
41. **L9-N2..N10: CA-369 residual "and nothing else"; nine `git diff`/`git log` verify forms;
    T67 AC6's Mermaid ratio; `evals/baseline/scores.json` absence; T67 AC9/AC13; T28 AC9's
    understatement of `BLOCKING_FILTER`; `CLAUDE.md:338-339`'s EDMV4-T04 claim; the three
    sanctioned `bin/` library files; the `find` derivation excluding `_edm-*.sh`** -- All
    recorded gaps, standing carve-outs, or D48/D27 scoping distinctions. Not re-filed.
42. **L3: `eval:nightly`'s 150m outer timeout vs the ~140m inner budget** -- Direction is correct
    (outer > inner). Folded into CA-444's fix as a one-comment recommendation, not a separate
    finding.
43. **L1/L9/L10: CA-130 (Write and/or Bash absent from delivered lens tool sets)** -- Reproduced for
    the 8th/9th consecutive round by L8, L9 and L10. Remains NOTED with a do-not-re-file
    disposition. **The actionable consequence** -- that nothing verifies each lens's JSONL landed --
    is filed separately as CA-471.

---

## Rollout Order

### Stage 0 -- Decision gate (blocks Stage 1; human required)

**CA-423** is a product decision, not an engineering one. Put it to the human **before writing
code**: keep `--accept-p2-debt` behind an approved SRD change request against EDMV3-90, or withdraw
it. Everything in Stage 2 depends on the answer, and outcome (b) closes nine findings in one revert.

### Stage 1 -- Quick, low-risk fixes from this session's own remediation (parallel, ~1 commit)

These are **the cheapest work in this plan** and two of them currently leave safety guards inert.
None depends on Stage 0. File-independent, so parallelisable.

| Order | Finding | Effort | Why first |
|---|---|---|---|
| 1a | **CA-433** (L3-8) | 2 lines | The CA-169 inode-safety guard **cannot currently fail**. Second recurrence of this class. Blocks CA-438. |
| 1b | **CA-432** (L3-2) | 1 line + 2 tests | A documented-for-testing knob kills every subcommand at load. |
| 1c | **CA-434** (L2-001) | delete 17 lines + 3 docstrings | A tripwire whose subject no longer exists, plus live misdirection toward a deleted helper. |
| 1d | **CA-435** (L6-F6) | delete 3 fragments + reword | An allowlist entry that filters nothing and a justification describing deleted text. |
| 1e | **CA-438** (L8-007) | 2 assertions | *After 1a.* Pins the corrected fd-200 rationale. |
| 1f | **CA-437** (L8-004) | ~4 lines | NUL-delimit the hook extraction; assert `COUNT`. |
| 1g | **CA-436** (L8-003) | **run the command first** | Blocking CI job may be red on first run. Investigation, then one of two fixes. |

### Stage 2 -- The `--accept-p2-debt` cluster (ONE coordinated work item)

*Only if Stage 0 resolves as "keep".* If it resolves as "withdraw", revert `dc8a24f` + `bdab2ac`
and skip to Stage 3.

**Strict internal ordering** -- these are not independent:

1. **CA-426 + CA-427 together, in one commit.** CA-426's fix *un-latches* CA-427; landing CA-426
   alone converts a confusing refusal into a raw jq crash on a documented-supported input.
2. **CA-428** in the same commit (`to_int` on both jq-derived values, after CA-427's coercion).
3. **CA-429** (drop the two orphan state keys, or give them a reader).
4. **CA-425** (the three missing safety-guard tests) -- **after** 1-3, because the fix changes what
   the guard reads.
5. **CA-423 + CA-424 + CA-430 + CA-431** (SRD change request, T28 AC12 amendment, new ticket,
   CHANGELOG + version bump + state-field table rows) -- the paperwork half, one commit.

### Stage 3 -- Remaining P1s (parallel, file-independent)

| Finding | Note |
|---|---|
| **CA-440 + CA-411 + CA-412** | One edit to one JSON string in `hooks.json:117`, plus the `SKILL.md` merge step and the `CLAUDE.md:686` table cell. |
| **CA-441** | Three one-line frontmatter edits + one `edm-check-grants` rule. Run the runtime check noted in the finding. |
| **CA-460** | Three doc/comment sources + two computed assertions. Coordinate with 1f/1g -- same job. |
| **CA-461** | One README example + one equality assertion. |
| **CA-462** | The largest single item: a sixth scorer dimension, a fixture-schema addition, and a `scorer_version` bump. |
| **CA-416** | Template change in the synthesizer + code-audit skill. **Land this before Stage 4**, so Stage 4's doc sweeps are themselves obliged. |

### Stage 4 -- P2 batches (grouped by shared root cause; one commit each)

1. **Trap hygiene**: CA-446 + CA-447 (+ the `edm-check-grants:125-126` comment rewrite).
2. **Unvalidated env knobs**: CA-443 + CA-444 (CA-432 already landed in Stage 1).
3. **Eval wiring**: CA-452 (+ CA-449, CA-450 -- same `evals/` and `bin/tests/` hygiene pass).
4. **Bare count captures**: CA-401 + CA-459 (add `assert_count_with_control`, convert both suites,
   land the durability pin in the same commit).
5. **Test-quality batch**: CA-453, CA-454, CA-455, CA-456, CA-457, CA-458, CA-402, CA-403, CA-404,
   CA-405.
6. **Spec/AC text sweep**: CA-468 + CA-469 + CA-470 (downstream of CA-416; one commit).
7. **Docs batch**: CA-407, CA-408, CA-439, CA-463, CA-464, CA-465, CA-466.
8. **Hook robustness via extraction**: CA-413 + CA-414 (+ CA-436 if option (b) was chosen) --
   extract `hooks.json:86`'s body to `bin/edm-lint-staged-artifacts`. Highest-leverage refactor
   available; closes three findings at once.
9. **DRY batch**: CA-344 (+ L10-N03), CA-417, CA-418, CA-419, CA-420, CA-467.
10. **Correctness residue**: CA-442, CA-445, CA-448, CA-451.
11. **Wiring residue**: CA-409, CA-410 (widen, do not tighten -- direction confirmed), CA-421,
    CA-422, CA-471.

**Sequencing note on CA-422 and CA-429**: CA-422 (consumer-side durability check) is the mechanism
that would have caught CA-429, CA-421 and CA-384. Landing CA-422 *before* Stage 4 item 11's other
work makes the rest self-enforcing.

---

## Verification Plan

### Syntax / static

```bash
bash -n plugins/edm/bin/edm-state
for f in plugins/edm/bin/edm-* plugins/edm/bin/_edm-*.sh plugins/edm/evals/*.sh plugins/edm/bin/tests/*.sh; do
  case "$f" in *.awk|*.txt) continue ;; esac
  bash -n "$f" || echo "SYNTAX FAIL: $f"
done
shellcheck --shell=bash plugins/edm/bin/edm-state plugins/edm/bin/edm-*
jq empty SRD/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl
jq -e '.' plugins/edm/hooks/hooks.json >/dev/null
```

### Hook lint (CA-436 -- run this BEFORE enabling the blocking job)

```bash
jq -r '.hooks | to_entries[] | .value[] | .hooks[] | select(.type=="command") | .command' \
  plugins/edm/hooks/hooks.json \
  | shellcheck --shell=sh --include=SC2086,SC2046,SC2048,SC2068 -
```

### Test suites

```bash
bash plugins/edm/bin/tests/run-all.sh          # must print ALL SUITES PASSED
bash plugins/edm/bin/tests/wave6-smoke.sh      # CA-425, CA-427, CA-453, CA-458
bash plugins/edm/bin/tests/wave7-smoke.sh      # CA-433, CA-438, CA-454..CA-457, CA-459, CA-460
bash plugins/edm/bin/tests/harness-smoke.sh    # CA-434
bash plugins/edm/bin/tests/timing.sh --self-test
bash plugins/edm/evals/tiering-matrix.sh --self-test
```

**Run `run-all.sh` on a host WITH `flock(1)`** (Linux or a container) as well as on macOS -- until
CA-455 lands, three lock-contract cases silently vanish on macOS under `ALL SUITES PASSED`.

### Lint / contract checks

```bash
bash plugins/edm/bin/edm-check-grants                     # CA-441
bash plugins/edm/bin/edm-check-vocabulary                 # CA-465
bash plugins/edm/bin/edm-lint-artifacts <PREFIX>          # CA-447
bash plugins/edm/bin/edm-sync-canonical-sections --check  # CA-446
bash plugins/edm/bin/edm-check-skill-sync                 # CA-467
grep -c '^lint:' .gitlab-ci.yml                           # CA-460 -> 8
grep -c '<<: \*alpine_edm' .gitlab-ci.yml                 # CA-460 -> 11
```

### Integration / manual smoke

1. **CA-426 + CA-427**: seed `.edm-state.json` with `audit_rounds: {"code": 3}` (bare integer),
   then `edm-state approve-gate <PFX> code-audit --accept-p2-debt`. Must engage the override (or
   refuse with an accurate message) -- **not** die with a raw jq error, and **not** print
   `P0=0 P1=0 must both be 0`.
2. **CA-432**: `EDM_STATE_LOCK_WAIT_S=0.5 edm-state --help` must print the named `die`, not a raw
   bash arithmetic error.
3. **CA-433**: temporarily rename the `flock` call in `edm-state` and confirm `wave7-smoke.sh`
   now **fails** with "anchor is stale" rather than passing.
4. **CA-440**: run `/edm:implement` on a wave of 3+ independent tickets with 2+ FAIL verdicts;
   confirm **both** FAILs reach Step 5's remediation list.
5. **CA-441**: run `/edm:test-plan <PREFIX>` and confirm the planner agent actually spawns.
6. **CA-443**: `EDM_EVAL_KEEP_RUNS=0 bash plugins/edm/evals/run-eval.sh --provision-only` must
   leave the current run directory intact.
7. **CA-461**: arm `evals/baseline/scores.json` following the README verbatim, then run
   `bin/edm-compare-eval`; the `variance allowed:` line must reflect the configured value, not 0.
8. **CA-462**: run the scorer against the tiny-svc fixture; delete one GAP marker from a synthetic
   `srd.md` and confirm `known-gap-recall` drops.

### Targeted re-audit (round 9)

Re-run the lens agents whose lenses surfaced findings fixed in this pass. If Stages 0-3 are
completed, that is:

**L1, L2, L3, L4, L6, L7, L8, L9, L11** (+ **L10** if Stage 4's DRY batch lands).

Because the accept-p2-debt cluster spans L1, L2, L3, L4, L9 and L11, and because CA-460 spans
L2/L6/L7, a **full 11-lens round is the practical choice** for round 9 -- a partial round covering
fewer than nine lenses would not satisfy the convergence gate anyway.

**Blocking precondition for round 9 (CA-471)**: verify that every lens named in `lenses-run.txt`
produced a matching `lens-L{N}.jsonl`. `pass-7/` produced **zero** JSONL files and
`pass-6/lens-L10.jsonl` is absent; round 8 produced all eleven, but nothing enforces it.
