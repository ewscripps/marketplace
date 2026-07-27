# Epic E8 -- WS8: Economics honesty

**Wave**: C (v3.0.0 -> v3.1.0)
**SRD requirements**: EDMV3-70 .. EDMV3-75 (6)
**Tickets**: EDMV3-T50 .. EDMV3-T53 (4)

R5 with the root cause established by D9. The plugin's headline claim is built on data that omits its
dominant cost: EDMV2's Phase 6 recorded 0s and $0.00 despite `audit_rounds.code = 2`.
`phase-start 6` fired at 2026-06-08T08:49:54Z, `phase-complete 6` never did, and archive did not care.

The wave-A archive lifecycle check already makes that specific omission impossible to repeat silently
-- `cmd_archive` now refuses without a terminal-phase `completed_at` -- so this epic wires the call,
makes the numbers honest, and stops presenting a multiple against an unknowable baseline.

All commands are run from the repository root unless stated otherwise.

---

## EDMV3-T50: `phase-complete 6` is actually called

| Field | Value |
|---|---|
| Epic | E8 -- Economics honesty |
| Wave | C |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV3-70 |
| Depends On | EDMV3-T11, EDMV3-T33 |
| Ships-with | -- |
| Target Components | `plugins/edm/skills/orchestrator/SKILL.md` (Phase 6 entry), `plugins/edm/skills/implement/SKILL.md` (Step 8 Declare Done), `plugins/edm/skills/code-audit/SKILL.md`, `plugins/edm/README.md` (command table) |

### Description

D9 settles the root cause: the fix is to wire the call, not to fix attribution (that is EDMV3-T52).

The ownership question is the substance. Three skills could plausibly call `phase-complete 6` and
none of them can invoke the others, so an ordering constraint between two skills that cannot see each
other is not a design. The **orchestrator's Phase 6 entry owns the call**: it invokes
`/edm:verify-runtime` via the Skill tool, then calls `edm-state phase-complete <PREFIX> 6`.
`skills/implement/SKILL.md` is deliberately not given a `Skill` grant, so the ownership is
unambiguous and the tool surface stays minimal.

### Acceptance Criteria

- [ ] AC1 (positive, single owner): the orchestrator's Phase 6 entry invokes `/edm:verify-runtime`
      via the Skill tool and then calls `edm-state phase-complete <PREFIX> 6`.
      Verify: `grep -n 'phase-complete .*6' plugins/edm/skills/orchestrator/SKILL.md` returns the
      call, preceded by the `verify-runtime` Skill invocation.
- [ ] AC2 (negative, implement does not close the phase): `skills/implement/SKILL.md`'s Declare Done
      step ends after the execution report is written and states that Phase 6 closure belongs to the
      orchestrator's Phase 6 entry. It does **not** call `phase-complete 6` itself and is not given a
      `Skill` grant to chain `verify-runtime`.
      Verify: `grep -rl 'phase-complete <PREFIX> 6' plugins/edm/skills/implement/ | wc -l` prints 0,
      and `grep -n '^allowed-tools:' plugins/edm/skills/implement/SKILL.md | grep -c 'Skill'`
      prints 0. (The earlier `grep -c 'Skill' <file>` matched the word inside prose and inside
      `SKILL.md` self-references, so it could never return 0; the assertion is scoped to the
      `allowed-tools` line, which is the thing that must not contain it.)
- [ ] AC3 (negative, code-audit does not either): `skills/code-audit/SKILL.md` does not call
      `phase-complete 6`; the responsibility lives in exactly one place and the other skills
      reference it.
      Verify: `grep -rl 'phase-complete' plugins/edm/skills/code-audit/ | wc -l` prints 0.
- [ ] AC4 (exactly one call site, asserted): a smoke assertion checks that exactly one
      `phase-complete <PREFIX> 6` invocation exists across all skill files.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "exactly one phase-complete 6 call
      site").
- [ ] AC5 (ordering, direct-invocation path): for users who never run the orchestrator,
      `skills/implement/SKILL.md` Step 8 and the `README.md` command table state the two-command
      sequence -- `/edm:verify-runtime <PREFIX>` then `edm-state phase-complete <PREFIX> 6`. The
      ordering is enforced regardless, because `phase-complete 6` refuses on open PARTIALs.
      Verify: `grep -n 'phase-complete <PREFIX> 6' plugins/edm/README.md plugins/edm/skills/implement/SKILL.md`.
- [ ] AC6 (negative, the artifact check must pass not refuse): the call is placed after
      `qc/qc-summary.md` exists, so EDMV3-T11's artifact check passes rather than refusing.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "orchestrator Phase 6 ordering:
      qc-summary exists before phase-complete 6").
- [ ] AC7 (behavioural, the number is non-zero): a fixture or scratch run produces a non-zero
      `duration_seconds` and a non-zero `estimated_cost_usd` for `6_phase`.
      Verify: after a scratch Phase 6 run,
      `edm-state get TESTX | jq -e '.phase_durations["6_phase"].duration_seconds > 0 and .phase_durations["6_phase"].estimated_cost_usd > 0'`.
- [ ] AC8 (regression guard against the EDMV2 failure mode) **(cross-check, owned by EDMV3-T12)**:
      an initiative that reaches phase 6 and never calls `phase-complete 6` cannot archive, so the
      silent-zero outcome cannot recur.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "archive refuses without terminal
      completed_at").

### Technical Notes

- Depends on EDMV3-T33 because the Phase 6 entry invokes `/edm:verify-runtime`, which does not exist
  until wave B, and on EDMV3-T11 because the artifact check the call must satisfy is defined there.
- Blocks EDMV3-T51 and EDMV3-T48. Nothing about per-round cost or tiering measurement is meaningful
  until Phase 6 itself is measured.

### Out of Scope

- Fixing token attribution -- EDMV3-T52.
- Per-round cost -- EDMV3-T51.
- The `verify-runtime` skill itself -- EDMV3-T33.

---

## EDMV3-T51: Per-round audit cost is captured

| Field | Value |
|---|---|
| Epic | E8 -- Economics honesty |
| Wave | C |
| Priority | Should Have |
| Size | S |
| SRD Refs | EDMV3-71 |
| Depends On | EDMV3-T05, EDMV3-T50 |
| Ships-with | -- |
| Shared record shape | **The audit-round record**, owned by EDMV3-T27 in wave B and extended additively here in wave C. Not a `Ships-with` relationship: same-MR across a wave boundary is unsatisfiable (srd.md v1.2.0 CR3). T27 designed the record with documented slots for the completion timestamp, duration and cost fields this ticket fills. Confirm before starting that those slots are still present in `CLAUDE.md`'s state-field table; if they are not, correct that shape here rather than adding a parallel one. |
| Target Components | `plugins/edm/bin/edm-state` (new `cmd_audit_round_complete`), `:1394-1406` (`cmd_audit_round_start`), `:923` (`cmd_metrics_report`), `:419` (`state_anomalies`), `:206` (`get_session_tokens_since`, the shared token helper), the dispatch table near `:1980-2023`, the `--help` header at `:2-39`, `plugins/edm/skills/code-audit/SKILL.md`, `plugins/edm/CLAUDE.md` (`bin/` table) |

### Description

R5.1. `audit-round-start` exists and increments the round counter, but nothing closes a round, so the
cost of an individual code-audit round is invisible even once Phase 6 as a whole is measured. This
subcommand is named in `planning.md` but was not counted in the new-module estimate -- it is one of
the four scope deltas that took `edm-state` from one new subcommand to four.

### Acceptance Criteria

- [ ] AC1 (positive): `edm-state audit-round-complete <PREFIX> <code|srd|tickets>` records a
      completion timestamp, duration, and token and cost totals for the round, keyed by audit type
      and round number.
      Verify: `edm-state audit-round-start TESTX code && sleep 1 && edm-state audit-round-complete TESTX code && edm-state get TESTX | jq -e '.audit_rounds.code.rounds[-1].duration_seconds > 0'`.
- [ ] AC2 (one cost computation, not two): token capture reuses the same helper as `phase-complete`
      (`get_session_tokens_since` at `bin/edm-state:206`) so the two cannot compute cost differently.
      Verify: `grep -c 'get_session_tokens_since' plugins/edm/bin/edm-state` shows the helper called
      from both `cmd_phase_complete` and `cmd_audit_round_complete`, with no second implementation.
- [ ] AC3 (called at the right point): `skills/code-audit/SKILL.md` calls it at the end of each
      round, after the synthesizer returns and the ledger is rendered.
      Verify: `grep -n 'audit-round-complete' plugins/edm/skills/code-audit/SKILL.md` returns a line
      after the `render-ledger` call.
- [ ] AC4 (negative, an unclosed round is visible): a round that starts and never completes is
      visible -- `edm-state validate` reports an `OPEN_AUDIT_ROUND` anomaly in the canonical
      four-field format `info  OPEN_AUDIT_ROUND  audit_rounds  <description>` (EDMV3-T05 AC2), the
      description naming the audit type and round number -- so the EDMV2 failure mode is detectable
      rather than silent.
      Verify: `edm-state audit-round-start TESTX code && edm-state validate TESTX | grep -n '^info  OPEN_AUDIT_ROUND  audit_rounds'`.
- [ ] AC5 (the anomaly is informational): the `info` class in AC4's first field is what keeps an
      open round from turning `validate` non-zero (EDMV3-T05). The class is declared at the emit
      site, not inferred by the consumer.
      Verify: `edm-state validate TESTX; echo "exit=$?"` prints `exit=0` when the open round is the
      only anomaly, and the emitted line's first field is `info`.
- [ ] AC6 (metrics surface): `metrics-report` renders per-round cost below the phase table when round
      data exists, and omits the section when it does not.
      Verify: `edm-state metrics-report TESTX | grep -n 'per-round'` after a completed round, and
      the section absent before one.
- [ ] AC7 (C-4): legacy state files with rounds recorded but no completions render without error.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "legacy audit_rounds render without
      error").
- [ ] AC8 (surfaced): the subcommand appears in the `--help` block, the dispatch table, and the
      `CLAUDE.md` `bin/` table.
      Verify: `edm-state --help | grep -n audit-round-complete` and
      `grep -n 'audit-round-complete' plugins/edm/CLAUDE.md`.
- [ ] AC9 (negative, double completion): completing a round twice exits non-zero naming the existing
      completion, and mutates nothing.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "second audit-round-complete
      refused" plus `check_state_unchanged`).
- [ ] AC10 (atomicity and bash 3.2): all state mutation goes through `rmw_state` and the change
      passes `bash -n`.
      Verify: `bash -n plugins/edm/bin/edm-state` and `jq -e . <state-file>` after a concurrent
      double invocation.

### Technical Notes

- **Resolved in srd.md v1.2.0 (CR3).** EDMV3-71 previously carried `Ships-with: EDMV3-120` across a
  wave boundary, which is unsatisfiable -- same-MR means one merge request, and waves B and C are
  different merge requests by construction. Both requirements now carry a `Shared shape:` note
  instead, mirrored in this ticket's field table and EDMV3-T27's. Nothing about the work changes:
  this ticket is an **additive extension** of a documented shape rather than a second edit of it.
- The audit-round record is an object on every file, legacy ones included, because EDMV3-T27 AC1a
  coerces a bare integer `N` to `{count: N, rounds: []}` at read time. AC7's legacy case exercises
  exactly that path, so it must be run against a fixture carrying the pre-widening integer shape.
- Blocks EDMV3-T48: a tiering measurement taken before per-round cost is instrumented measures
  nothing (EDMV3-104's explicit ordering note).

### Out of Scope

- `round_type` recording -- EDMV3-T27 (wave B).
- The tiering comparison that consumes this data -- EDMV3-T48.
- Attribution correctness -- EDMV3-T52. This ticket records whatever the shared helper returns; T52
  makes what it returns honest.

---

## EDMV3-T52: Token attribution and the pricing table become honest

| Field | Value |
|---|---|
| Epic | E8 -- Economics honesty |
| Wave | C |
| Priority | Should Have |
| Size | S |
| SRD Refs | EDMV3-72, EDMV3-73 |
| Depends On | -- |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/edm-state:206-225` (`get_session_tokens_since`), `session_dir_for_cwd`, `:233-262` (`compute_cost_usd`), `:923` (`cmd_metrics_report`), `plugins/edm/CLAUDE.md` (Cost tracking section and pricing table), `plugins/edm/README.md` (timing table), `SRD/edm/EDMV3__prompt-streamline/decisions.md` |

### Description

Two halves of F6 that are not the missing call. `get_session_tokens_since` sums *every* session JSONL
in the project directory since the phase-start timestamp, so any concurrent session inflates a
phase's cost. The code path is unambiguous even though it has not been tested with two live sessions.
And the hardcoded pricing table is for Opus 4.7, Sonnet 4.6 and Haiku 4.5 -- one model generation
stale -- so every computed cost is wrong even where the token counts are right.

EDMV3-72 is deliberately an either/or requirement, and this ticket records the choice rather than
pre-deciding it.

### Acceptance Criteria

- [ ] AC1 (either/or, and the choice is recorded): either (a) attribution is scoped to the driving
      session's JSONL, identified by a mechanism documented in the function's comment block, or
      (b) the number is relabelled everywhere it surfaces as "project activity during phase" rather
      than a phase cost. The choice and its rationale are recorded in `decisions.md` and the
      limitation is stated in the function's comment.
      Verify: `grep -n 'token attribution' SRD/edm/EDMV3__prompt-streamline/decisions.md` names the
      branch taken and its rationale, and
      `sed -n '206,230p' plugins/edm/bin/edm-state` shows the comment.
- [ ] AC2 (branch (a) fallback): if (a) is chosen, a fallback to the current whole-directory
      behaviour exists when the driving session cannot be identified, and the recorded value carries
      a flag indicating which mode produced it.
      Verify: `jq -e '.phase_durations["6_phase"].attribution_mode' <state-file>` returns
      `scoped` or `whole-directory`.
- [ ] AC3 (branch (b) consistency): if (b) is chosen, `metrics-report` output, `HANDOFF.md`,
      `CLAUDE.md` "Cost tracking" and the README timing table all use the honest label consistently.
      Verify: `grep -rn 'project activity during phase' plugins/edm/bin/edm-state plugins/edm/CLAUDE.md plugins/edm/README.md`
      returns a hit in each.
- [ ] AC4 (behavioural test, either branch): a smoke test with two synthetic session JSONL files in
      the session directory asserts the chosen behaviour.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "two synthetic sessions produce the
      documented attribution").
- [ ] AC5 (negative, no rewriting of history): existing recorded values in archived state files are
      not rewritten. The change is forward-looking only.
      Verify: `git status --porcelain SRD/.archived/` prints nothing after the change.
- [ ] AC6 (positive, pricing refreshed): the pricing constants in `bin/edm-state` are updated to the
      current published rates for the model generation the plugin actually runs on, with input,
      output, cache-read and both cache-write TTL rates.
      Verify: `sed -n '233,262p' plugins/edm/bin/edm-state` shows the current-generation identifiers
      and rates.
- [ ] AC7 (no drift between the table and the code): the `CLAUDE.md` pricing table matches the
      script's constants exactly, and a smoke assertion compares the two so they cannot drift. The
      verification date and source URL in `CLAUDE.md` are updated.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "CLAUDE.md pricing table matches
      script constants").
- [ ] AC8 (override mechanism preserved): the existing environment-variable override mechanism is
      preserved, and the override names are updated if model identifiers change.
      Verify: `EDM_OPUS_INPUT_RATE=99 edm-state metrics-report TESTX` reflects the override.
- [ ] AC9 (C-4, old identifiers still cost): model-identifier matching in `compute_cost_usd` handles
      both the previous and current generation identifiers, so archived state files with old
      `model_used` values still render a cost rather than falling through to zero.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "archived state with a previous-
      generation model_used renders a non-zero cost").
- [ ] AC10 (negative, unknown model warns rather than costing zero): an unknown model identifier
      produces an explicit warning rather than silently costing zero.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "unknown model_used warns"),
      asserting both the warning text and that the reported cost is not silently 0.

### Technical Notes

- AC10 is the sharpest of the ten. Silently costing zero is exactly how F6 stayed invisible for a
  full initiative; a warning is the difference between a wrong number and an unnoticed one.
- The two halves are batched because both live in the same two functions and the same `CLAUDE.md`
  section, and because shipping a refreshed pricing table over a wrong token count would replace one
  dishonest number with another.
- No dependency on EDMV3-T50 or EDMV3-T51: this ticket makes the computation honest regardless of who
  calls it.

### Out of Scope

- Wiring `phase-complete 6` -- EDMV3-T50.
- Removing the human-baseline comparison -- EDMV3-T53.
- Backfilling archived cost figures (explicitly forbidden by AC5).

---

## EDMV3-T53: The human-baseline ROI table leaves default output and metrics reflect tiering

| Field | Value |
|---|---|
| Epic | E8 -- Economics honesty |
| Wave | C |
| Priority | Should Have |
| Size | S |
| SRD Refs | EDMV3-74, EDMV3-75 |
| Depends On | EDMV3-T48, EDMV3-T50, EDMV3-T51 |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/edm-state:923` (`cmd_metrics_report`), `:268-281` (`human_cost_for_phase`), `plugins/edm/skills/metrics/SKILL.md`, `plugins/edm/README.md` (timing table), `plugins/edm/bin/tests/wave5-smoke.sh:175`, `plugins/edm/.claude-plugin/plugin.json` (`human_hourly_rate_usd` description) |

### Description

R5.4. A tool that mis-measures its own cost while computing a multiple against a $150/hr human
baseline invites exactly the scrutiny it cannot survive. The Claude cost is knowable and actionable;
the human baseline is unknowable per initiative.

The metrics-surface half ships here because it is the same output: once Phase 6 is measured
(EDMV3-T50), rounds are measured (EDMV3-T51) and lenses are tiered (EDMV3-T48), the report should make
the effect visible, so a cost number can finally steer a decision instead of only producing a slide.

### Acceptance Criteria

- [ ] AC1 (positive, honest default): `edm-state metrics-report` default output shows raw cost and
      duration per phase and in total, and does **not** show a human-baseline comparison or a
      multiple.
      Verify: `edm-state metrics-report TESTX | grep -l 'baseline\|multiple\|savings' | wc -l`
      prints 0 -- or equivalently `edm-state metrics-report TESTX > /tmp/mr.out && grep -rl 'baseline\|multiple\|savings' /tmp/mr.out | wc -l`
      prints 0. (`grep -c` prints `0` but exits 1, so under `set -e` it fails the verification block
      while reporting the correct answer.)
- [ ] AC2 (data not lost): `human_baseline_usd` continues to be recorded in state so historical data
      is not lost and the comparison remains reconstructable.
      Verify: `edm-state get TESTX | jq -e '.phase_durations["1_phase"].human_baseline_usd != null'`.
- [ ] AC3 (opt-in view, with its caveat): an explicit opt-in flag renders the comparison for anyone
      who wants it, and its output states the baseline rate used and that the baseline is an
      estimate.
      Verify: `edm-state metrics-report TESTX --with-human-baseline | grep -n 'estimate'`.
- [ ] AC4 (skill matches): `skills/metrics/SKILL.md` is updated to match and no longer presents the
      multiple as a headline.
      Verify: `grep -rli 'multiple\|ROI' plugins/edm/skills/metrics/ | wc -l` prints 0 once the
      opt-in description's own occurrences are excluded by the ignore marker, or the surviving hits
      are enumerated in the ticket and every one is inside the opt-in description.
- [ ] AC5 (README timing table): the `README.md` timing table is either regenerated from real data or
      labelled as an estimate pending calibration.
      Verify: `grep -n 'estimate pending calibration\|regenerated' plugins/edm/README.md`.
- [ ] AC6 (config key retained, description updated): the `human_hourly_rate_usd` userConfig key is
      retained and its description reflects that it now feeds an opt-in view.
      Verify: `jq -r '.userConfig.human_hourly_rate_usd.description' plugins/edm/.claude-plugin/plugin.json`
      mentions the opt-in view.
- [ ] AC7 (negative, the re-baseline that this change forces): `bin/tests/wave5-smoke.sh:175` is
      re-baselined in the same merge request. It asserts
      `check "metrics-report savings n/a for zero-cost initiative (G8)" "n/a" "$MR_OUT"` against
      default `metrics-report` output, and removing the human-baseline comparison from that output
      reds it. CI lands in wave A and blocks merge, so this is a pipeline stop rather than a stale
      test.
      Verify: `bash plugins/edm/bin/tests/wave5-smoke.sh; echo "exit=$?"` prints `exit=0`.
- [ ] AC8 (positive, code-audit section): `metrics-report` renders a code-audit section showing rounds
      run, lenses per round, and cost per round.
      Verify: `edm-state metrics-report TESTX | grep -n 'rounds run\|lenses per round'` after a
      completed round.
- [ ] AC9 (tiering comparison, where data exists): where tiering data is available, the report shows
      the cost of the tiered configuration against the untiered one for the same lens set. Where it
      is not, the section is omitted rather than rendered empty.
      Verify: `edm-state metrics-report <fixture-prefix> | grep -n 'tiered'` after EDMV3-T48's
      measurement, and the section absent on an initiative with no tiering data.
- [ ] AC10 (`--calibrate` still works, now with data): `--calibrate` continues to work and now has
      Phase 6 data to calibrate against.
      Verify: `edm-state metrics-report TESTX --calibrate` exits 0 and its output references a
      non-zero `6_phase` duration.
- [ ] AC11 (lint clean): output remains ASCII-only and passes the artifact lint when written into an
      initiative directory.
      Verify: `edm-state metrics-report TESTX > <init-dir>/metrics.md && bash plugins/edm/bin/edm-lint-artifacts --all`
      exits 0.
- [ ] AC12 (prose-change convention, EDMV3-69): `skills/metrics/SKILL.md` is prompt text, so the
      merge request shows before and after for each changed block plus one sentence on why the new
      wording is better -- specifically for the removal of the multiple as a headline (AC4) and for
      the opt-in flag's caveat wording (AC3).
      Verify: the MR description contains a before/after block per edited section of
      `skills/metrics/SKILL.md`.

### Technical Notes

- AC9's "where data exists" phrasing is deliberate and comes from the SRD's priority note: no Must
  Have requirement may depend on a Should Have, so the dependent AC is stated conditionally. This
  ticket is itself Should, but the pattern is preserved so a reader does not read a hard dependency
  where the SRD placed a soft one.
- Depends on EDMV3-T48 for the tiering figures, T50 for Phase 6 duration and T51 for per-round cost.
  All three are wave C, so no cross-wave edge is created.

### Out of Scope

- Changing `human_hourly_rate_usd`'s default value.
- Backfilling the comparison into archived initiatives.
- The tiering measurement itself -- EDMV3-T48.
