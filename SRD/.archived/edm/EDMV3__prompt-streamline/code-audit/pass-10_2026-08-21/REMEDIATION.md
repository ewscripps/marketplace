# Code Audit Remediation Plan: EDMV3__prompt-streamline (Round 10)

## Context

- Audit date: 2026-08-21
- Round: 10 (**full** -- all 11 lenses L1-L11 ran; `lenses-run.txt` records `Round type: full`)
- Audited scope: working tree at pass-10 start (post-`c3467cb`) -- `plugins/edm/**` (`bin/`, `bin/tests/`, `hooks/`, `skills/`, `agents/`, `evals/`, `docs/`, `CLAUDE.md`, `README.md`, `CHANGELOG.md`), repository-root `.gitlab-ci.yml`, repository-root `CLAUDE.md`, and this initiative's `srd.md` + `tickets/**`
- SRD: `SRD/edm/EDMV3__prompt-streamline/srd.md` (v1.3.0, EDMV3-01..EDMV3-120)
- Ticket pack: `SRD/edm/EDMV3__prompt-streamline/tickets/` (68 tickets, T01..T68)
- Authoritative ledger: `SRD/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl` (536 entries after this round)
- Deployment target: local plugin distribution (marketplace repository); no runtime service

### Round 10 result in one line

**0 P0, 6 P1, 54 P2 open. 15 findings closed this round (the largest single-round close in the initiative). 22 new actionable findings, 2 demoted to NOTED, 14 filtered as not-actionable.**

Convergence is **blocked**: `P0 + P1 = 6`, so `--accept-p2-debt` is not available (it waives P2 only). Three findings additionally carry `spec_swept: "no"`, which independently blocks `audit-converged` and `approve-gate code-audit` by design.

---

## Coverage caveat (CA-466 / CA-130 / CA-388) -- read before trusting any "clean" verdict

Round 10 ran under significant tooling degradation. Full detail is in `pass-10_2026-08-21/tooling-notes.md`; the audit-relevant consequences are:

**All 11 lenses were delivered without `Write`, despite the frontmatter grant on every `agents/edm-audit-*.md`.** This is the standing CA-130 stale-plugin-cache condition, now at its 8th-11th consecutive round depending on lens. No lens could persist its own `lens-L{N}.md`/`.jsonl`; every lens returned both halves inline and the orchestrator transcribed them (fixing only HTML-entity transport artifacts). **No lens's findings were suppressed or truncated by this** -- every lens completed its mandate.

**No lens had `Bash`.** Per-lens self-reports: L1, L2, L3, L4, L6, L7, L9, L10, L11 explicitly had no Bash; L5's report is static throughout; L8 confirms "no file mode was observed and nothing was executed". Consequences that matter for reading this plan:

- **The suite was not run.** The 2313-assertion / 0-failure figure quoted to the lenses is orchestrator-supplied and was independently verified by nobody. L4 flags that CA-455 makes it structurally unobservable from the `Results:` line whether any SKIP path fired on that run.
- **No file mode was observed.** CA-501 (the commit-hook delegate's executable bit) cannot be confirmed or cleared without `Bash`; L11 explicitly asks that it not be closed by absence.
- **Every "FIXED" verdict is read-derived, not diff-derived.** L3 could not run `git log`/`git diff` over `c3467cb`, so it cannot attest to what the fix commit touched outside the sites it read.
- Nine of eleven lenses additionally hit an individual spend limit on first resume and needed a second resume. No content was lost; wall-clock cost roughly doubled.

**Named unaudited surfaces (report as unaudited, not clean):**

| Lens | Not swept this round |
|---|---|
| L2 | `bin/edm-state` outside `:3859-3978`, `bin/edm-mermaid-rules.awk`, **all of `bin/tests/**`**, all of `evals/**` except CA-490 cross-refs, `.gitlab-ci.yml`, `skills/**`, other `agents/*.md`, `docs/**`, both `CLAUDE.md`s, `README.md`, `CHANGELOG.md` |
| L3 | `bin/edm-state:1500-3250`, `:3350-4420`, `:4600-6100` (includes `cmd_phase_start`, `cmd_phase_complete`, `cmd_approve_gate`, `cmd_init`, `cmd_update_patterns`, `_splice_pattern_file`, `cmd_render_ledger`, `_write_handoff_body`, `cmd_record_partial_verdict`, `cmd_git_lock_check`); `run-eval.sh` body; `bin/edm-init`, `edm-validate-prefix`, `edm-check-grants`, `edm-check-vocabulary`, `edm-check-skill-sync`, `edm-compare-eval`, `edm-sync-canonical-sections`, both shared libs; all of `bin/tests/**` beyond trap-shape greps. **Includes the sites of previously-fixed L3 findings CA-027/028/055/056/059/062, which received no regression re-verification.** |
| L6 | Per-agent-frontmatter vs `CLAUDE.md`-table reconciliation across all 30 agents; exhaustive sweeps of `CHANGELOG.md`, `monitors/monitors.json`, `evals/README.md` and the 14 `SKILL.md` files were targeted rather than complete |
| L8 | `skills/**`, `agents/*.md`, `docs/**`, `CHANGELOG.md`, `bin/tests/wave3|4a|4b|5-smoke.sh` were pattern-grepped only, not read end to end |
| L9 | Epics beyond T22/T23/T27/T28/T51/T66/T68 swept at coverage-map/ownership level, not AC-by-AC. T23 AC3's `jq` and T51 AC1's live `duration_seconds` not executed |
| L11 | `evals/fixtures/tiny-svc/**` wiring, `evals/tiering-matrix.sh`, `bin/edm-init`/`edm-sync-canonical-sections`/`edm-check-skill-sync` caller sweeps, the per-skill `allowed-tools` dead-grant sweep. **L11 self-reports roughly 60% of its enumerated scope.** |

**Explicitly not-re-verified carried findings** (L11, session truncated): CA-484, CA-496, CA-501. Of these, CA-484 is closed here on L6's and L9's independent file:line evidence, not on absence. CA-496 and CA-501 remain open, as L11 requested.

**Standing recommendation, now outstanding for six rounds (CA-331 / CA-377):** a Bash-capable pass must run `plugins/edm/bin/tests/run-all.sh` immediately before the convergence gate. L10 additionally notes CA-505's confirm-by-running request is outstanding for a third round. Round 10 cannot satisfy this.

---

## Findings Summary

### P1 (6) -- fix before shipping

| # | Sev | Lens(es) | Component | Issue |
|---|-----|----------|-----------|-------|
| CA-513 | P1 | **L10+L1** | `bin/edm-state:5205,:5216,:5228` | CA-476's fix hand-rolls a column-1 fence tracker 3x; diverged from the de-indenting classifier the same file sources, re-opening the P1 pattern-library pollution through an indented fence |
| CA-514 | P1 | L9 | `bin/edm-state:4767,:2359,:1841`; `agents/edm-audit-synthesizer.md:166` | CA-416's own fix shipped two blocking refusals + a validate anomaly + an authoritative-ledger field with **zero** acceptance criteria |
| CA-515 | P1 | L3 | `skills/implement/SKILL.md:39,:96-97,:103` | CA-473 residual: `qc-shard-pass-{NN}` is keyed on shard ordinal only, so wave 2 overwrites wave 1 and a wave-1 FAIL verdict silently disappears; the skill self-contradicts on the pass's cardinality |
| CA-509 | P1 | L9 | `srd.md:3836`, `:9`, `:20-25` | *Escalated from P2.* The ticket pack asserts an SRD amendment that does not exist; EDMV3-90 AC1/AC4 still forbid the shipped `--accept-p2-debt` flag |
| CA-510 | P1 | L9 | `bin/edm-state:4558`; `skills/code-audit/SKILL.md:104` | *Escalated from P2.* The CA-471 `round_type` downgrade + refuse-to-proceed gate has neither a positive nor a negative AC; T27 and T51 mutually disclaim it |
| CA-106 | P1 | L9 (+L2, L11 on consequence) | `evals/baseline/scores.json` (absent) | *Re-opened from NOTED and escalated.* EDMV3-28 is an undelivered **Must Have**; the only automated prompt-quality tripwire is un-armed, and the absence now blocks CA-490 from being fixable |

### P2 -- new this round (18)

| # | Sev | Lens(es) | Component | Issue |
|---|-----|----------|-----------|-------|
| CA-524 | P2 | L4 | `bin/tests/wave7-smoke.sh:8729,:8735-8739` | CA-473's load-bearing disjointness assertion **and its positive control** both pass on an empty extraction |
| CA-516 | P2 | L1 | `bin/edm-state:5230` | The `qc` extractor arm keys on `**Finding**:`, a label the authoritative QC finding format does not carry -- conforming reports extract zero titles forever |
| CA-518 | P2 | L1 | `.gitlab-ci.yml:328` | `lint:hooks-shell` writes the literal `null` for a command-type hook with no `.command`; both checks pass it and the blocking gate prints OK |
| CA-519 | P2 | L2 | `bin/edm-sync-canonical-sections:120` | `mkdir -p` preempted by `mktemp` 39 lines earlier -- sixth member of a class deleted five times (CA-140/202/260/309/362) |
| CA-520 | P2 | L2 | `bin/edm-init:212` | Comment cites "line 139" for a call at `:165`, 28 lines below the same file's own record of fixing this exact drift |
| CA-521 | P2 | L3 | `bin/edm-lint-staged-artifacts:106` | Selects initiatives from the git index but lints the working tree: a violation staged then fixed unstaged commits clean |
| CA-522 | P2 | L3 | `bin/edm-state:3306,:3327` | CA-208 residual: `watch-impl` re-resolves HEAD when advancing its cursor, so a commit in the window is never reported and never can be |
| CA-523 | P2 | L4 | `bin/tests/wave7-smoke.sh:8715` | New CA-473 case reintroduces the CA-401 bare-capture shape in top-level position; an abort discards the whole CA-416 block |
| CA-525 | P2 | L4 | `bin/tests/wave6-smoke.sh:869+` | Completeness-gate fixtures hand-build the manifest; nothing pins its shape to the `SKILL.md` instruction that writes it |
| CA-526 | P2 | L4 | `bin/tests/wave6-smoke.sh:911-912` | Miss-class assertion is substring containment, so it cannot detect **over**-reporting -- 4th instance of CA-312/454/458 |
| CA-527 | P2 | L4 | `bin/tests/wave6-smoke.sh:894,:914` | `.rounds[-1]` with no `length == 1` assertion; a double-recording regression is invisible in the gate's only mutation detectors |
| CA-528 | P2 | L4 | `bin/tests/wave7-smoke.sh:8653` | GNU-only `\s` in the CA-472 tripwire's only false-negative guard; degrades on BSD grep (macOS = documented primary dev platform) |
| CA-529 | P2 | L7 | `agents/edm-audit-synthesizer.md:5` | `tools` line diverges from all eleven lens agents, and round 9's own sweep note asserts the family is identical |
| CA-530 | P2 | L7 | root `CLAUDE.md:47-51` | Frontmatter template documents `user-invocable: true`; all 14 edm skills use `disable-model-invocation: true` and none carries `user-invocable` |
| CA-531 | P2 | **L7+L6** | `bin/tests/wave7-smoke.sh:8944-8962` | CA-483's tripwire pins 3 of the 4 version sites it was filed against; `CHANGELOG.md` is unpinned and the comment's own arithmetic says four |
| CA-532 | P2 | L8 | `evals/run-eval.sh:410,:450` | `--allowedTools` passed as one space-containing argv element; four `Bash(...)` matchers cannot survive a split, so the documented containment posture is likely not in force |
| CA-533 | P2 | L10 | `bin/edm-state:5409,:5414,:5415` | `update-patterns` audit-type enum re-encoded at 3 validation sites and keyed by 5 `case` statements with no shared list -- larger second instance of CA-503 |
| CA-534 | P2 | L11 | `bin/tests/wave6-smoke.sh:1960-1965` | The only positive fixture for phase-6 sharded-QC writes `qc-shard-01.md`, a name no producer emits post-CA-473; neither real prefix is asserted |
| CA-536 | P2 | L9 | `tickets/epics/04:577-579` | CA-424 swept T28 AC12 but not the sibling AC13 doc obligation, so the new refusal arm is surfaced by no AC |

### P2 -- carried open (36)

Re-verified still-open this round with fresh file:line evidence. Full text in `findings-ledger.jsonl`.

| # | Lens(es) | Component | One-line |
|---|----------|-----------|----------|
| CA-481 | **L3+L5+L7+L8** | `evals/tiering-matrix.sh:154`; `evals/score-artifacts.sh:758` | Four-lens: last trap omitting HUP; untrapped mktemp window; **the prescribed durability pin does not exist** (0 hits for `CA-446`/`CA-447` under `bin/tests/`) |
| CA-490 | **L2+L11+L1** | `bin/edm-compare-eval:61` | Baseline-existence `exit 3` still precedes candidate validation and refusal condition 3; the `complete:false` handshake is unreachable and 2 shipped comments describe it as live |
| CA-497 | **L7+L8** | `bin/edm-lint-staged-artifacts:25` | Only undocumented `set -uo pipefail` in the plugin; adding `-e` "for consistency" silently fails commit-time lint open |
| CA-493 | **L4+L8** | `.gitlab-ci.yml:554` | Blocking `test:state-validate` discards the enumerator's status with no `COUNT` floor: prints "0 initiative(s) checked" then OK, exit 0 |
| CA-501 | **L8+L11** | `bin/edm-lint-staged-artifacts` mode; `hooks.json:86` | Commit-time enforcement depends on an executable bit nothing asserts, on a delegate nothing ever executes. **Not observable this round (no Bash)** |
| CA-502 | **L10+L7** | `.gitlab-ci.yml:106,:242`; `wave7-smoke.sh:1083` | "What is a bash source file" written 3x; the in-suite twin omits `evals/*.sh`; the CA-233 pin covers only the exclusion arm |
| CA-482 | **L3+L7** | `bin/edm-lint-artifacts:137` (+5 sites) | Cleanup-then-resume trap 12 lines above the same file's canonical form, on the binary that runs on every `git commit` |
| CA-491 | **L4+L1** | `wave7-smoke.sh:364` | `missing-task-grant` has no must-fail case (0 hits); the rule at `edm-check-grants:515` is unreachable on the live tree |
| CA-401 | **L4+L1** | `wave6`/`wave7`/`wave4a` (~26 sites) | Unguarded bare count captures under `set -euo pipefail`; a zero-match grep aborts the suite and discards every later assertion |
| CA-453 | **L1+L4** | `wave6-smoke.sh` (absent cases) | Zero of CA-389/CA-390's four prescribed assertions landed; `required_gate_count` appears in no test file |
| CA-459 | **L10+L4** | `_harness.sh:237`; ~14 hand-rolled sites | Canonical control helper vs fourteen hand-rolled copies; `assert_count_with_control` never built |
| CA-479 | **L3+L1** | `bin/edm-state:4537` | Pass-directory glob silently keeps the last match: the CA-471 gate fires spuriously or passes vacuously, with no diagnostic |
| CA-480 | L3 | `bin/edm-state:1354` | A lockdir with no pidfile is never reclaimed; on the macOS `mkdir` branch that bricks the initiative's lock permanently |
| CA-486 | L6 | `plugins/edm/CLAUDE.md:1057` | `lint:shellcheck` row omits the `*.awk` exclusion the sibling row states correctly |
| CA-488 | L6 | `plugins/edm/README.md:210` | `decisions.md` listed as optional/on-demand; it is Must/always-present and load-bearing at runtime |
| CA-489 | L6 | `docs/audit-patterns/README.md:88` | The documented pending-entry count command is a bare `grep -c` over a glob and produces no total |
| CA-492 | L4 | `wave6-smoke.sh:811` | The CA-426 regression pin positively certifies that a zero-round initiative converges; doc-mitigated, spec question answered by L9 |
| CA-494 | L4 | `.gitlab-ci.yml:788,:798` | `eval:nightly` re-derives `RUN_DIR` twice with no `else` arm: scores nothing, compares nothing, says nothing |
| CA-495 | L5 | `wave7-smoke.sh:7700` (+11 sites) | Scratch trees outside the suite's trap-covered root; `:7700` is removed on **no** path and leaks on the success path every run |
| CA-496 | L7 | `wave7-smoke.sh:6328` | CLI-family durability loop hardcodes 9 helpers and omits the 10th; the comment's counts (12/9) should be 13/10 |
| CA-498 | L7 | `bin/edm-check-grants:515` | No `Skill` positive rule, though `CLAUDE.md` names `Skill`-in-`allowed-tools` as the first caller obligation -- CA-441's exact failure mode |
| CA-499 | L8 | `bin/edm-lint-staged-artifacts:1` | Sole hardcoded `#!/bin/bash` among 14 scripts, on the one script all commit-time enforcement routes through; exec 126 is non-blocking |
| CA-500 | L8 | `bin/edm-state:1062` | `CLAUDE_PROJECT_DIR` trusted on a bare `-d` test, feeding the only auditable record that a human-approval control was armed. (b) partially fixed |
| CA-503 | L10 | `bin/edm-state:4442` | `code|srd|tickets` enum at 6 in-code sites; the file documents the opposite rule at `:799-803` and 4 constants obey it |
| CA-504 | L10 | `bin/edm-state:5039-5048` | `_cmd_set_provenance_field` still has no `write_handoff_internal` call and no target-existence check, unlike both siblings |
| CA-505 | L10 | `bin/edm-state:1097,:1106` | Half fixed: the comment is honest now, the two column-width specs still disagree and the header/underline pin never landed |
| CA-507 | L11 | `skills/code-audit/SKILL.md:357-359` | Wiring half fixed (`tooling-notes.md` is named in the spawn prompt); the prescribed durability pin never landed (0 hits for `tooling-notes`/`CA-507`/`CA-466` under `bin/tests/`) |
| CA-511 | L3 | `evals/run-eval.sh:412` | Doc half landed; `run-eval.sh` still validates only the knob's type, so `EDM_EVAL_PHASE_TIMEOUT_SECONDS=3600` inverts the 150m outer timeout silently |
| CA-402, CA-403, CA-404, CA-405, CA-455, CA-456, CA-457 | L4 | `bin/tests/**` | The seven remaining members of the D60 `--accept-p2-debt` candidate set; each individually re-confirmed open this round, none re-filed |

---

## Detailed Findings (P1)

### CA-513 (P1, lenses L10 + L1): the CA-476 fix hand-rolls a fence tracker three times and it diverged from the shared classifier

**Problem.** `pattern_extract_titles`' `code`, `srd` and `qc` arms each open with the same two lines at `bin/edm-state:5205-5206`, `:5216-5217` and `:5228-5229`:

```awk
/^```/ { infence = 1 - infence; next }
infence { next }
```

Three byte-identical copies of a fence state machine, inside one function, added in one commit -- in a file that **already sources** the project's single-sourced fence classifier at `:63` for exactly this purpose, and whose sibling function `pattern_insert_line_for` uses it twenty lines below at `:5300`.

Three behavioural divergences, all unsafe:

1. **Indented fences are invisible to the copy.** `mermaid_fence_run_len` de-indents before counting backticks (`bin/edm-mermaid-rules.awk:120-126`), documented at `:37-46` and `bin/_edm-lint-lib.sh:27-30` precisely because "real markdown often nests a fenced block under a numbered list step". The copy anchors at column 1. So a fenced example finding indented under a numbered remediation step never toggles `infence`, and its `### CA-NNN` heading is harvested into `docs/audit-patterns/code-audit.md` as a `status: pending-review` entry -- a shipped plugin asset thirteen prompt surfaces read as accumulated wisdom. **This is the exact P1 pollution CA-476 was filed to stop, re-opened through a different door**, and it is the third occurrence of CA-009's divergence axis.
2. **Variable-length fences desync it.** The canonical machine records the opener's run length and closes only on a run `>= fence_len` with nothing but whitespace after (`edm-mermaid-rules.awk:145-150`). The copy toggles on any line starting with three backticks, so a four-backtick block quoting a three-backtick block -- the standard idiom for showing fenced content -- inverts `infence` for the rest of the file and silently drops every later finding.
3. `edm-lint-ignore` markers are honoured by the canonical mechanism (`_edm-lint-lib.sh:169-179`) and not by the copy, so "ignored" means two different things in two halves of one command.

**Why this is L10's highest-priority class and not a style nit.** The comment at `:5197-5198` reads *"Fence-aware throughout, for the same reason `pattern_insert_line_for` is (CA-056)"* -- asserting parity with the **shared** mechanism. Within a single command the *destination* file is classified by the canonical de-indenting classifier and the *source* report by a weaker hand-rolled one, under a comment claiming they are the same. That is the CA-343/CA-420/CA-505 comment-asserts-single-sourcing class at a fifth site, introduced by the fix for a P1.

**False Alarm Filter: fails all three clauses.** `edm-state` already sources `_edm-lint-lib.sh` at `:63` with the comment at `:56` naming this purpose; `_edm-lint-lib.sh:4-7` names `bin/edm-state` as a consumer and `:53-55` names edm-state's pattern machinery as an `ignored_line_set` caller **by name** (pinned at `wave7-smoke.sh:4903-4904`) -- so no circular-dependency or portability reason exists. This is production `bin/` code reached by four skills, not test code. And nothing records a decision to use a weaker rule; the comment claims the opposite.

**Fix.**
1. In `bin/edm-state`, compute `ignored_line_set "$report"` once inside `pattern_extract_titles`, pass it to a single awk program as a line-number skip set (`awk -v skip="$set"`), and delete the three `/^```/` togglers. The machinery is already in the file and `pattern_insert_line_for` already does exactly this.
2. If a self-contained arm is genuinely preferred, at minimum change all three trackers to `/^[ \t]*```/` **and** say in the comment that this is a deliberate reduced-fidelity copy.
3. Correct or delete the `:5197-5198` comment so no reader is told the two halves share a mechanism they do not.
4. Convert the fourth copy of the same idiom at `bin/tests/wave7-smoke.sh:7461` in the same pass if a shared helper lands (test-side, cleared on its own merits -- see non-findings).

**Verification.** Add two cases to `wave7-smoke.sh`'s `ca476_extraction_case`: a `### CA-998` heading inside a fence indented two spaces under a numbered step (must extract **nothing**), and a four-backtick block containing a three-backtick block followed by a real `### CA-997` finding (must extract `CA-997`). Both must be red before the fix and green after. The regression fixture for the indented-fence class already exists at `bin/tests/fixtures/mermaid/valid/v12-indented-fence.md` and is cited by name in `edm-mermaid-rules.awk:45`.

**Files affected.** `plugins/edm/bin/edm-state`, `plugins/edm/bin/tests/wave7-smoke.sh`.

---

### CA-514 (P1, lens L9): CA-416's own fix shipped two blocking refusals with zero acceptance criteria

**Problem.** The CA-416 remediation -- whose stated purpose was to stop remediations shipping without their spec sweep -- shipped a second convergence-blocking refusal, a new `validate` anomaly class, and a new authoritative-ledger field, and repeated CA-510's structural defect one round later. What shipped with no AC anywhere:

- a blocking refusal in `audit-converged` (`bin/edm-state:4767`, debt block appended at `:4802`)
- a blocking refusal in `approve-gate code-audit` that `--accept-p2-debt` explicitly cannot waive (`:2359`)
- a new informational anomaly class `SPEC_SWEEP_PENDING` (`:1841`)
- a new filter constant `SPEC_SWEEP_DEBT_FILTER` (`:1597`)
- a new field in the authoritative JSONL ledger schema (`agents/edm-audit-synthesizer.md:166`, rules at `:181-184`)
- a new mandatory row in the remediation-plan format (`:122-130`)

A grep for `spec_swept` across `tickets/` and `srd.md` returns **zero hits**; it lives only in `CONVERGENCE-PLAN.md:110`, `HANDOFF.md` and the ledger. T28 AC1-AC13 (`epics/04:518-579`) enumerate `audit-converged`'s exit conditions branch by branch and omit the sweep-debt exit; T05 does not name the new anomaly class; T25/T26 do not name the new ledger field. This violates `tickets/README.md:66-68`, a stated pack rule: every ticket that adds a gate or refusal carries at least one positive AC and one negative AC.

**Do not remove the mechanism** -- it is a genuine improvement and closes the initiative's five-round stale-citation root cause. This round it is already doing its job: three entries closed here carry `spec_swept: "no"`.

**Fix.** Add to T28 (or T25): a positive AC (a fixed entry at `yes`/`n/a` converges), a negative AC (a fixed entry at `no` refuses `audit-converged` **and** refuses `approve-gate` even with `--accept-p2-debt`, and nothing mutates), and a C-4 AC (an absent field never blocks). Add the new class to T05's anomaly enumeration. Add a doc AC covering `plugins/edm/CLAUDE.md`'s state/ledger field table. Land in the same commit as CA-510's three-branch AC.

**Verification.** `grep -rn spec_swept SRD/edm/EDMV3__prompt-streamline/tickets/` must return the new ACs. The behaviour is already covered by `wave7-smoke.sh:8755-8910`; each new AC's `Verify:` clause must cite one of those existing case labels **verbatim** (CA-368's rule).

**Files affected.** `tickets/epics/04-structured-findings.md`, `tickets/epics/01`-`02` (T05's home), `plugins/edm/CLAUDE.md`.

---

### CA-515 (P1, lens L3): CA-473's fix left `qc-shard-pass-{NN}` non-unique across waves, and the skill contradicts itself on cardinality

**Problem.** CA-473 correctly made the two *mechanisms* disjoint (`qc-shard-impl-` vs `qc-shard-pass-`). It did not make the `pass-` key unique over *time*, and `skills/implement/SKILL.md` gives two incompatible readings:

| Site | Text | Implied cardinality |
|---|---|---|
| `:96-97` | "when this skill itself orchestrates a QC pass **after all implementer waves complete**" | once per initiative |
| `:103` | `ticket_count = len(wave_tickets)` | once **per wave** |
| `:39` | "**After the wave drains**, merge every `qc/qc-shard-impl-*.md` and every `qc/qc-shard-pass-*.md` into `qc/qc-summary.md`" | once per wave |

Two of three readings are per-wave, **including the operative pseudo-code variable an agent will follow**. Under that reading the collision is deterministic. Step 1's own worked example at `:55-57` is a three-wave initiative: wave 1's post-wave pass writes `qc/qc-shard-pass-01.md` and the merge builds `qc-summary.md`; wave 2's pass writes `qc/qc-shard-pass-01.md` **again**, overwriting wave 1's, and the merge regenerates one verdict table from the shard glob -- producing a `qc-summary.md` from which wave 1's pass-shard verdicts have vanished. Nothing reports the loss. As CA-473 itself established, only PARTIAL survives elsewhere (via the locked `record-partial-verdict`); **PASS and FAIL live only in these markdown files**, so a wave-1 FAIL never reaches Step 5's compile step at `:130`.

Hook shards are immune: `qc-shard-impl-{lowest ticket}` is unique across waves by construction. Only the ordinal-keyed `pass-` namespace collides.

**Severity note.** L3 filed this at P2/medium. **Escalated to P1 by the synthesizer on parent-finding parity**: CA-473 was rated P1 for exactly this harm class (silent loss of QC shard verdicts), and this is the same loss through a different door.

**Fix.** Pick one cardinality and state it once.
- If per-initiative: change `:103` to the full ticket set and delete "after the wave drains" from `:39`.
- If per-wave: key the name on wave as well as ordinal (`qc-shard-pass-w{W}-{i:02d}.md`) and widen the merge globs at `:39` and `:114`.

**Verification.** Add a `wave7-smoke.sh` assertion that the pass-shard key expression in `skills/implement/SKILL.md` contains a wave component whenever the merge step is described as per-wave, with a positive control that removes the component and turns red. Note this rewording will trip CA-523 (`wave7-smoke.sh:8715` greps for the literal `writes qc/qc-shard`), so **fix CA-523 first or in the same commit**.

**Files affected.** `plugins/edm/skills/implement/SKILL.md`, `plugins/edm/bin/tests/wave7-smoke.sh`.

---

### CA-509 (P1, lens L9): the ticket pack asserts an SRD amendment that does not exist

**Problem.** `srd.md:9` is still Version 1.3.0; the Revision History at `:20-25` still ends at 1.3.0 with no CR entry for D57/D58. `srd.md:3829-3855` (EDMV3-90) is byte-unchanged: AC1 at `:3836-3837` still asserts that no `--force`, `--accept-partials`, `--skip-checks`, `--yes` "or equivalent bypass flag" exists on `phase-complete`, `archive`, `approve-gate` or `audit-converged`, and AC4 at `:3846-3848` still bans a recorded-exemption category. A repository-wide grep of `srd.md` for `D57`, `D58`, `accept-p2-debt` and `T68` returns **zero matches** -- while `tickets/README.md:601-607` and `:700` and `tickets/epics/04:1215`, `:1222`, `:1260-1261` all assert the amendment exists.

**Escalation rationale.** CA-508 closed the `tickets/README.md` half of this same amendment **this round**, so the pack is now internally consistent in asserting an SRD amendment that does not exist. Two governing artifacts disagree, with the higher authority the one that is wrong on the record, and a shipped flag is forbidden by its own SRD requirement.

**Fix.** Take the pack's own amendment route (CR1-CR6, `tickets/README.md:799-809`): bump `srd.md` to 1.4.0, add the Revision History CR entry naming D57/D58, and amend EDMV3-90 AC1 and AC4 to carve out `--accept-p2-debt` with its recorded rationale. If the change request is refused instead, strip the `(amended)` annotation from both pack sites and withdraw the flag. **Do not leave the two artifacts disagreeing.** Sequence with CA-536.

**Verification.** `grep -n 'accept-p2-debt\|D57\|D58' SRD/edm/EDMV3__prompt-streamline/srd.md` must return the amendment; the Revision History top entry must match `srd.md:9`'s version token.

**Files affected.** `SRD/edm/EDMV3__prompt-streamline/srd.md`.

---

### CA-510 (P1, lens L9): the CA-471 `round_type` gate has neither a positive nor a negative AC

**Problem.** The gate ships (`bin/edm-state:4522-4558`, `ca471_downgrade="partial"` at `:4558` written into the round record at `:4577`/`:4585`, plus `skills/code-audit/SKILL.md:104`'s refuse-to-proceed and `:147-152`), and neither candidate owner gained an AC. T51's criteria are still AC1..AC10 (`epics/08:145-186`) with no round-type or completeness AC and its Out of Scope at `:203` still points at T27; T27's criteria are still AC1, AC1a, AC2..AC6, AC8 (`epics/04:375-423`) with `round_type` derived at round-**start** only, and its Out of Scope at `:445` still points at T51. The mutual disclaim is intact.

**Escalation rationale.** Both mitigating halves this entry pointed at closed this round -- CA-477 (the missing test half) and CA-506 (the operator-facing terminus half) are both FIXED -- so the AC gap is the whole of what remains. And the class reproduced one round later inside the CA-416 fix (CA-514). A convergence-blocking refusal with neither a positive nor a negative AC directly violates `tickets/README.md:66-68`, a stated pack rule rather than a preference.

**Fix.** Add the three-branch AC (positive: a complete round records `full`; negative: a round with a missing/empty/unparseable lens JSONL is downgraded and refuses to converge, and nothing else mutates; C-4: an absent pass directory does not block) to **T51**, and delete the contradicting Out-of-Scope line in **both** T27 and T51 in the same commit.

**Verification.** Each new AC's `Verify:` clause must cite an existing case label verbatim from `wave6-smoke.sh:877-948` (`CA477FULL`, `CA477CLASS`, and the CA-478 CRLF/unterminated cases), which already cover all three branches.

**Files affected.** `tickets/epics/08-economics-honesty.md`, `tickets/epics/04-structured-findings.md`.

---

### CA-106 (P1, lens L9; consequence corroborated by L2 and L11): EDMV3-28 is an undelivered Must Have

**Problem.** `plugins/edm/evals/baseline/scores.json` does not exist -- `evals/baseline/` holds only `README.md`. So T23 AC8's first `Verify:` clause and AC13's second (`jq -e '(.dimensions_scored == 5) and (.complete == true)' .../baseline/scores.json`) are both unsatisfiable in a clean checkout, and **EDMV3-28 ("baseline captured on wave-A code and committed"), a Must Have, is not delivered**. The initiative's only automated prompt-quality tripwire is un-armed.

**Why this is re-opened from NOTED rather than left dispositioned.** CA-106 was NOTED because the absence is honestly recorded (D23/D36; `evals/baseline/README.md:3` heads itself "Status: pending the live baseline capture"). Two things changed:

1. EDMV3-28's **Must-Have** status is unmet with no recorded scope boundary -- which is a different claim from "the baseline is pending".
2. The absence now **blocks a second finding from being fixable**: CA-490's `complete:false` handshake is environmentally unreachable precisely because the default baseline path does not exist. L2, L11 and L1 each confirmed this independently this round. The NOTED disposition rested on the absence being self-contained; it is not.

Note CA-532 (`--allowedTools` passed as one argv element) is a plausible contributing cause of the never-completed run and should be checked before any capture attempt.

**Fix -- this is a scope decision for the human, not a code change.** Two sanctioned routes under the project's own D15 rule:

- **(a)** Capture the live wave-A baseline and commit `scores.json`. This arms the tripwire and makes CA-490's reorder verifiable. Requires `ANTHROPIC_API_KEY` and a real multi-phase run; fix CA-532 first.
- **(b)** Amend T23 AC8/AC13 and the EDMV3-28 coverage-map row (`tickets/README.md:638`) to record the baseline as an explicit out-of-scope boundary with a named follow-on ticket, and qualify the two comments CA-490 names (`.gitlab-ci.yml:775-776`, `plugins/edm/CLAUDE.md:1065`) with "once a baseline is committed".

**Do not** leave EDMV3-28 as an unmet Must Have with no recorded boundary -- that is the state L9 is objecting to, and either route resolves it.

**Verification.** Route (a): `jq -e '(.dimensions_scored == 5) and (.complete == true)' plugins/edm/evals/baseline/scores.json`. Route (b): the EDMV3-28 row reads as a boundary with a named follow-on, and `grep -n 'once a baseline is committed'` matches both comment sites.

**Files affected.** Route (a): `plugins/edm/evals/baseline/scores.json` (new), `plugins/edm/evals/run-eval.sh`. Route (b): `tickets/epics/03-ci-and-fixture-eval.md`, `tickets/README.md`, `.gitlab-ci.yml`, `plugins/edm/CLAUDE.md`.

---

## Detailed Findings (selected P2 -- highest value first)

Full text with fixes and verification for every P2 is in `findings-ledger.jsonl`. The five below are called out because they are false-pass or fail-open paths, which is the class this audit exists to catch.

### CA-524 (P2, lens L4): CA-473's disjointness assertion **and its positive control** both pass on an empty extraction

`[[ "$ca473_hook_tok" != "$ca473_skill_tok" ]]` at `wave7-smoke.sh:8729` is the load-bearing assertion of the CA-473 fix. Non-empty guards at `:8718-8723` `fail` and *continue*; they do not gate `:8729`. If the `sed` at `:8712-8713` stops matching while the skill side still extracts, `ca473_hook_tok` is empty, `"" != "qc-shard-pass-"` is true, and `:8729` reports *"hook token ('') and skill token ('qc-shard-pass-') are disjoint namespaces"* as a **PASS**. The positive control at `:8735-8739` rewrites the *skill* token to equal `$ca473_hook_tok`, so with an empty hook token it degenerates to `"" == ""` and passes too. **One silent extraction regression defeats both the assertion and the control that proves the assertion can fail.**

**Fix.** Gate `:8729` on both tokens being non-empty -- either make the `:8718-8723` guards `return` out of a wrapper function on an empty extraction, or add an explicit `[[ -n "$ca473_hook_tok" && -n "$ca473_skill_tok" ]]` precondition as its own named assertion. **Verification:** blank one `sed` pattern and confirm the case now fails rather than passing. Land with CA-523.

### CA-518 (P2, lens L1): `lint:hooks-shell` prints OK for a hook it never checked

`.gitlab-ci.yml:328` selects on `.type=="command"` but nothing requires a `.command` key. For `{"type":"command"}` with no `command`, `jq -r` emits the literal text `null`; `bash -n` accepts `null` as a well-formed single-word command and `shellcheck --shell=sh` accepts it too. So `:330` and `:337` both print OK, `COUNT` reaches `EXPECTED_COUNT` by construction, and `:351` prints the clean summary. The job is `needs: []` with no `allow_failure` and per `:265-268` covers "the most privileged shell in the plugin". No sibling backstops it -- `edm-check-grants:466` reads `"prompt":` entries, not `.command`.

**Fix.** Add a well-formedness count and fail on mismatch:

```sh
WELLFORMED="$(jq '[.hooks | to_entries[] | .value[] | .hooks[] | select(.type=="command") | select(.command | type=="string" and length > 0)] | length' plugins/edm/hooks/hooks.json)"
if [ "$WELLFORMED" -ne "$EXPECTED_COUNT" ]; then
  echo "lint:hooks-shell: FAILED -- ${EXPECTED_COUNT} command-type hook(s) declared but only ${WELLFORMED} carry a non-empty string .command"
  exit 1
fi
```

**Verification.** A wave7 case that copies `hooks.json` to scratch, deletes one `.command` key, and asserts the job body fails. Nothing today would turn red.

### CA-493 (P2, lenses L4 + L8): a blocking CI gate reports green having validated nothing

`.gitlab-ci.yml:554` runs `edm-state list --paths > "$LIST_FILE"` with no exit-status check under `set -u` only, and `COUNT` has no floor. Any enumerator failure leaves the list empty, the loop iterates zero times, `FAIL` stays 0, `:575` prints `state-validate: 0 initiative(s) checked` and `:580` prints `test:state-validate: OK`, exit 0. The plugin already fixed this exact class one directory over (`run-all.sh`'s `_MIN_SUITE_COUNT`).

**Fix.** `edm-state list --paths > "$LIST_FILE" || { echo "test:state-validate: FAILED -- edm-state list --paths exited $?"; exit 1; }` plus `[ "$COUNT" -ge 1 ] || { echo "...FAILED -- zero initiatives enumerated; the validator scanned nothing"; exit 1; }`. Secondary: arm `trap 'rm -f "$LIST_FILE"' EXIT` beside the `mktemp` to match the sibling jobs at `:293` and `:603`.

### CA-481 (P2, lenses L3 + L5 + L7 + L8): the highest-corroboration finding of the round

Four lenses independently. (a) `evals/tiering-matrix.sh:154` is still `trap 'rm -f "${tmp:-}"' RETURN EXIT INT TERM` -- **no HUP, no signal-shaped exits** -- now the only cleanup trap in `bin/` + `bin/tests/` + `evals/` following neither half of the convention `bin/edm-check-grants:124-130` declares plugin-wide, against nine canonical sibling sites. (b) `evals/score-artifacts.sh:758-763` still has a one-statement untrapped window (L8 reads the die-path half as closed by CA-449 and drops it; L3/L5/L7 keep it). (c) **The prescribed durability pin does not exist** -- a grep for `CA-446|CA-447|CA-481|CA-482` returns zero hits anywhere under `bin/tests/`. Three lenses name (c) as the reason (a), (b) and CA-482's six sites all survived a sweep that named them in scope.

**Fix (one commit, with CA-482).** Convert `:154` to the four-arm split (EXIT cleanup-only keeping `RETURN`; `INT` then `exit 130`; `TERM` then `exit 143`; `HUP` then `exit 129`); arm a first-stage trap immediately after `score-artifacts.sh:758`; convert CA-482's six sites; and land the cross-file sweep assertion -- scan `bin/`, `bin/tests/` and `evals/` for cleanup-trap lines and assert each names HUP and each real-signal arm exits after cleanup, with a planted positive control. **The sweep assertion is the load-bearing half**: without it this class returns.

### CA-495 (P2, lens L5): a scratch tree removed on no path, leaking on the success path every run

`wave7-smoke.sh:7700` creates a template tree under `${TMPDIR:-/tmp}`; a whole-file grep for `tmp_g22b` returns exactly three hits (`:7700`, `:7701`, `:7702`), **none a removal**. `:7699` clears all four trap dispositions and the tree is not under `$TMP`, so the top-level trap at `:25` does not own it. Its character-for-character identical G22a sibling at `:7669` **does** carry the tail removal at `:7683`, so this is a dropped line, not a project pattern. `run-all.sh` auto-discovers the suite and CI runs the aggregator twice per pipeline. Eleven further sites (`:5542`, `:5580`, `:5616`, `:5643`, `:5668`, `:5708`, `:5757`, `:5812`, `:5961`, `:7669`, `:8252`) are rooted outside `$TMP` with a tail-position `rm` as their sole cleanup after clearing all inherited traps.

**Fix.** Change the template root at all twelve sites from `${TMPDIR:-/tmp}` to `$TMP`, leave every `trap -` line untouched, keep the tail removals as a fast path. Then add a `bin/tests` tripwire, since the T61 AC11 sweep at `:1139` filters `/tests/` out and is structurally blind to this class.

---

## Decisions / Non-Findings

Flagged by one or more lenses this round and determined **Not Actionable**. Future audits must not re-investigate these.

1. **L6-01: root `CLAUDE.md:61`'s version token "is pinned by no test"** -- False. `wave7-smoke.sh:8949` extracts it by `sed` and `:8960-8962` asserts it against `plugin.json`; synthesizer read `:8935-8965` directly. L6 grepped only for `Current Plugins`. The real gap (CHANGELOG unpinned) is CA-531.
2. **L1: `.gitlab-ci.yml:343`'s `COUNT` vs `EXPECTED_COUNT` cross-check is a tautology** -- Filter 2; the comment at `:310-311` states this deliberately as a structural, not post-hoc, invariant.
3. **L2: `_edm-lint-lib.sh:214-222` `mermaid_line_set`/`marker_line_set` have zero callers** -- Filter 2; CA-200 closed this and `:51-65` now states the API-completeness position honestly.
4. **L2: `_edm-lint-lib.sh:229-232` `report_violation`'s arity arm is unreachable** -- CA-290, accepted arity defence on a shared function with two incompatible field orders. Do not re-file.
5. **L2: `edm-state:3876-3880` `cmd_gate_check`'s unknown-token `*)` arm is unreachable from all five hooks** -- public-CLI input validation; same reasoning CA-451 used to keep `gated_phase_for_gate`'s arm.
6. **L2: `edm-check-vocabulary:199`/`:141` bare-token fallbacks are unreachable** -- Filter 1; both data files are declared data-not-code and extensible with no code change (`vocabulary-prohibited.txt:11-12`).
7. **L2: `edm-check-grants:546-551` Edit arm is behaviourally redundant** -- executes, documented as intentional at `:530-537`, hedges a future producer.
8. **L2: `edm-check-grants:500`/`:513` dead stores and `:459-465`'s unused loop variable** -- free hedges that can never affect a reported line number; the citation deliberately uses the physical `$lnum` per `:436-441`.
9. **L2: `edm-init:146-159` byte-identical case arms; `:125-127` collision guard** -- both arms execute and carry distinct mode documentation; the guard still narrows a real TOCTOU window containing the unbounded `read` at `:106`.
10. **L2: `edm-check-skill-sync:64`'s `[ -f ] || continue` cannot fire** -- Filter 1; skipping a *missing* phase skill is correct for a moved-procedure tripwire, and manifest completeness is `validate:manifest`'s job.
11. **L2/L1: `edm-lint-artifacts:392-429` class 4 omits `UNREADABLE_FLAGS`; `:137`'s first-stage trap** -- accepted in the CA-376 bundle; the trap is load-bearing for the second-`mktemp` window and documented at `:134-136`. (Its *shape* is CA-482, already filed.)
12. **L1/L3: `edm-lint-staged-artifacts:58`'s `A && B || C` and `:132`'s `code=$?`** -- traced correct in all cases; an assignment inherits its substitution's status, and this file runs `set -uo pipefail` with **no** `-e`, so CA-036 does not apply.
13. **L3: `edm-lint-staged-artifacts:92`'s absolute `EDM_SRD_ROOT`** -- CA-320's deliberate one-value-computed-once fix, not an absolute-root regression.
14. **L11 N4: the code arm accepts round-local `G{N}` IDs, so the same pattern under two G numbers would not de-duplicate** -- the shipped synthesizer format uses stable `CA-NNN` and `G{N}` is required for the abridged template. (Distinct from CA-517, which is the *rejection* of compound forms.)
15. **L11 N2: `CHANGELOG.md:45` names the pre-CA-473 shard path** -- Filter 1; a changelog records what shipped in that version.
16. **L11 N3 / L7 N7: `edm-state:2557`'s glob is wider than its own diagnostic** -- documented as intentional at `:2551-2553`. Only the *fixture* consequence is actionable (CA-534).
17. **L8: `evals/fixtures/tiny-svc/config/settings.json:5` hardcoded `billingApiKey`** -- Filter 1; a self-labelling planted fake in a frozen fixture, and one of the ground-truth gaps scorer dimension 6 measures. Same for the `sk-...` placeholders in `evals/README.md:26`,`:36`.
18. **L8: `plugins/edm/CLAUDE.md:391`,`:399` absolute developer paths** -- prose recording how a one-off licence inspection was performed; never resolved by any code path.
19. **L7 N1/N2/N3: `edm-lint-staged-artifacts`' inverted exit-code contract, mixed diagnostic prefixes, POSIX `[ ]` tests** -- Filters 1-3; the exit-code inversion is dictated by the host's PreToolUse contract and documented in the file header and `CLAUDE.md`.
20. **L7 N4 / L1: bare `help` token accepted by three scripts and not three others** -- CA-289, explicit do-not-re-file. Nothing changed.
21. **L7 N5: `set -uo pipefail` at the four eval/harness sites** -- Filter 1; each carries its CA-074 rationale. Only the undocumented `bin/` instance is filed (CA-497).
22. **L7 N6: `.gitlab-ci.yml:291`'s EXIT-only trap** -- Filter 3; container-ephemeral and outside the `bin/`+`bin/tests/`+`evals/` scope CA-481's convention covers.
23. **L7 N9: `skills/metrics/SKILL.md:8` grants neither `Write` nor `TodoWrite`** -- Filter 3; a read-and-report skill that produces no artifact, so the narrower grant is the correct direction.
24. **L10: `score-artifacts.sh:580-595` vs `:597-610` copy-pasted loops** -- mechanical, no divergence risk a `jq` parse would not catch immediately.
25. **L10: `wave7-smoke.sh:7461`'s fourth hand-rolled fence toggler** -- Filter 2 (test code), and a missed indented fence **widens** rather than narrows that particular scan. Convert opportunistically with CA-513.
26. **L10: `edm-state:5265` `pattern_target_heading_for` ignores its argument** -- CA-114; documented at `:5118-5125` as the intentional extension point coupled to a README mapping row.
27. **L1: no unresolved `TODO`/`FIXME`/`HACK`/`XXX`/stub-return anywhere in scope** -- case-insensitive sweep of `bin/`, `bin/tests/`, `evals/`, `hooks/`, `skills/`, `agents/`, `docs/`, `.gitlab-ci.yml`. Every hit is placeholder-pricing prose, a `TodoWrite` grant, the vague-AC detection token, an anti-stub *instruction*, a documented placeholder-name expansion, the honest absent-baseline record, or fixture comment content.
28. **L9 items 2-11: Won't-Have requirements with no implementing ticket, T27's skipped AC7, T68's `[x]` boxes, the unreconciled `Requirement count` column, T61's L size, the nine over-band AC counts, `_edm-lint-lib.sh`, `monitors/monitors.json`'s absence** -- each carries a written justification at the cited pack line; Filter 1. `monitors/monitors.json` is absent because T59 (EDMV3-84) took the delete branch; the round brief's scope list names a deliberately removed file.
29. **L9 item 10: `edm-lint-staged-artifacts` has no ticket row** -- Filter 2; a necessary implementation detail of the ledger-authorized CA-436 extraction, not new product surface. Recommend naming it in T67 AC8's Target Components at the next sweep; non-blocking.
30. **CA-130 (no `Write`/`Bash` delivered to any lens)** -- host-side, standing do-not-re-file disposition. Counted in `tooling-notes.md` per `skills/code-audit/SKILL.md` step 8b, not re-filed.
31. **L10: CA-376's stated *rationale* for the `SRD_ROOT` duplication is false at HEAD** -- there are five copies, not four, and all five scripts do source `_edm-cli-lib.sh`. The duplication itself is genuinely low value and is not re-filed; recorded for the second consecutive round so a future round does not keep skipping it on a premise that no longer holds. **Action: correct CA-376's rationale text when next editing the ledger.**

### Demoted to NOTED (single-lens, low confidence -- recorded, not dropped)

- **CA-517** (L1, `edm-state:5210`): the code arm's delimiter class `[ \t:(]` excludes `/` and `-`, so `### G21/CA-233`-shaped headings are dropped and `extraction_status` still reports `ok` with a short count. The regex gap is certain; live incidence is unproven (this plan's own headings use the accepted bare form). One-line fix, land opportunistically with CA-513.
- **CA-535** (L7, `skills/verify-runtime/SKILL.md:7`): `argument-hint` quoting diverges with no discernible rule -- `orchestrator:7`'s quoting is required (contains `|`), `verify-runtime:7`'s is not. No behavioural consequence. Two one-token edits, land with CA-530.

---

## Rollout Order

**Stage A -- P1, blocking (6 findings).** Two independent tracks, parallelizable:

- *Track A1 (code, one engineer):* **CA-513** then **CA-515**. CA-513 touches `bin/edm-state`'s pattern extractor plus `wave7-smoke.sh`; CA-515 touches `skills/implement/SKILL.md` plus `wave7-smoke.sh`. **Fix CA-523 before or with CA-515** -- CA-515's rewording will abort the suite at `wave7-smoke.sh:8715`. Fold CA-516 and CA-517 into CA-513's commit (same function, same file).
- *Track A2 (spec/paperwork, one engineer):* **CA-509**, **CA-510**, **CA-514**, **CA-536** as one commit -- they are all AC/SRD edits in `srd.md` and `tickets/epics/04`+`08`, and CA-514 and CA-510 share one convention. Then **CA-106**, which is a human scope decision (route (a) or (b)) and should be settled before Stage A closes.

**Stage B -- P2, grouped by file independence.** Batch into commits that share a file:

1. `bin/tests/wave7-smoke.sh` CA-473-block batch: **CA-523 + CA-524** (do first -- CA-523 unblocks Stage A1).
2. `bin/tests/wave6-smoke.sh` CA-477-block batch: **CA-526 + CA-527 + CA-525 + CA-534**.
3. Trap-convention batch: **CA-481 + CA-482 + CA-495** in one commit, with CA-481(c)'s cross-file sweep assertion as the load-bearing piece.
4. `.gitlab-ci.yml` batch: **CA-518 + CA-493 + CA-494 + CA-502**.
5. `bin/edm-state` DRY batch: **CA-533 + CA-503** (one convention, two enums, one edit) and separately **CA-504 + CA-505**.
6. `bin/edm-lint-staged-artifacts` batch: **CA-497 + CA-499 + CA-501 + CA-521**. CA-501 needs `Bash` to verify.
7. Doc-accuracy batch: **CA-486 + CA-488 + CA-489 + CA-520 + CA-529 + CA-530 + CA-531 + CA-535**.
8. Standalone: **CA-490** (one reorder), **CA-519** (one-line move), **CA-522** (one variable), **CA-528** (one character), **CA-479**, **CA-480**, **CA-498**, **CA-500**, **CA-507**, **CA-511**, **CA-532**.

**Stage C -- the D60 accepted-debt set (7 remaining).** CA-402, CA-403, CA-404, CA-405, CA-455, CA-456, CA-457 plus CA-401, CA-453, CA-459. Each was individually re-confirmed open this round and deliberately not re-filed. L4 confirms none can make a broken production behaviour pass, and the two that could produce a false pass had their concrete sites fixed in the previous Stage C. **These remain the correct `--accept-p2-debt` candidates -- but only once P1 is zero.**

**Do not** attempt convergence during Stage A or B: `--accept-p2-debt` waives P2 only, and three entries carry `spec_swept: "no"` (CA-416, CA-424, CA-476), which independently refuses both `audit-converged` and `approve-gate code-audit` until CA-514, CA-536 and CA-513 land.

---

## Verification Plan

**Must run with `Bash` available -- this round could not.**

```bash
# 1. Syntax / lint (mirrors the blocking CI jobs)
for f in plugins/edm/bin/* plugins/edm/bin/tests/*.sh plugins/edm/evals/*.sh; do
  case "$f" in *.awk|*.txt) continue ;; esac
  bash -n "$f" || echo "SYNTAX FAIL: $f"
done
shellcheck -S warning -e SC1091 plugins/edm/bin/* plugins/edm/bin/tests/*.sh plugins/edm/evals/*.sh
jq empty plugins/edm/hooks/hooks.json plugins/edm/.claude-plugin/plugin.json .claude-plugin/marketplace.json

# 2. Full smoke suite -- the outstanding CA-331/CA-377 request, six rounds running
plugins/edm/bin/tests/run-all.sh
# Expect: every suite's "Results: N passed, 0 failed"; confirm the aggregate assertion
# count has RISEN, and record it. CA-455 means SKIP paths are invisible here -- until
# CA-455 lands, also grep each suite's output for "SKIP" and record what fired.

# 3. Artifact + state validation
plugins/edm/bin/edm-lint-artifacts --all
plugins/edm/bin/edm-check-grants
plugins/edm/bin/edm-check-vocabulary
plugins/edm/bin/edm-check-skill-sync
plugins/edm/bin/edm-state validate EDMV3

# 4. Ledger integrity (this file's own contract)
jq empty SRD/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl
jq -s '[.[] | select(.status=="open")] | group_by(.sev) | map({sev: .[0].sev, n: length})' \
  SRD/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl
# Expect after Stage A: P1 count 0. Expect now: P1 6, P2 54.
jq -s '[.[] | select(.status=="fixed" and .spec_swept=="no")] | map(.id)' \
  SRD/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl
# Expect now: ["CA-416","CA-424","CA-476"]. Must be [] before convergence.
jq -s 'length, ([.[].id] | unique | length)' \
  SRD/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl
# Both numbers must be 536 -- no duplicate IDs.

# 5. Per-finding spot checks that would have caught this round's regressions
grep -c '/\^```/' plugins/edm/bin/edm-state          # CA-513: must be 0 after the fix
grep -rn 'CA-446\|CA-447' plugins/edm/bin/tests/     # CA-481(c): must be non-empty after the fix
grep -rn 'tooling-notes' plugins/edm/bin/tests/      # CA-507: must be non-empty after the fix
grep -rn 'spec_swept' SRD/edm/EDMV3__prompt-streamline/tickets/  # CA-514: must be non-empty
grep -n 'accept-p2-debt' SRD/edm/EDMV3__prompt-streamline/srd.md # CA-509: must be non-empty
```

**Manual smoke (no automated path exists for these):**

1. **CA-521:** in a scratch clone, `git add` an SRD artifact containing an em dash, fix it in the editor without re-staging, `git commit`. Before the fix the commit succeeds; after, it is blocked with exit 2.
2. **CA-501:** `ls -l plugins/edm/bin/edm-lint-staged-artifacts` and confirm mode `0755`; then `chmod 644`, attempt a commit that should be blocked, and confirm the hook now fails loudly rather than exiting 0.
3. **CA-515:** run a two-wave initiative through `/edm:implement` and confirm both waves' pass-shard verdicts survive into `qc/qc-summary.md`.

**Targeted re-audit for round 11.** Re-run the lenses whose findings were fixed: **L1, L3, L4, L6, L7, L9, L10, L11**. In addition, round 11 must be a **full** round with `Bash` and `Write` actually delivered, because:

- L2, L3, L6, L8 and L11 each declared substantial unaudited surface (table above) that must be swept, not assumed clean.
- CA-501 and CA-505 cannot be adjudicated without `Bash`, and CA-505's confirm-by-running request is now three rounds outstanding.
- L3's unaudited ranges include the sites of previously-fixed findings CA-027/028/055/056/059/062, which have had no regression check.
- L2's highest-value re-sweep targets are `bin/edm-state`, `bin/tests/**` and `evals/**`; L11's are `evals/tiering-matrix.sh`, the `tiny-svc` fixture wiring and the per-skill dead-grant sweep.

**Round type:** full (all 11 lenses ran). This round is therefore eligible to count toward the convergence gate, but does not satisfy it: 6 P1 findings are open and three fixed entries carry `spec_swept: "no"`.
