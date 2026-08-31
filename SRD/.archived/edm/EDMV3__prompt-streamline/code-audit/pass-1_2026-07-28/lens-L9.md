# Lens L9: Spec & Ticket Compliance -- EDMV3 Code Audit Round 1 (full)

**Date**: 2026-07-28
**Round**: pass-1, full (11 lenses)
**Tree**: `/Users/darryl.porter/projects/marketplace`, branch `edm/edmv3-prompt-streamline`

**Scope covered**: SRD `srd.md` v1.3.0 (structure plus the requirement bodies for EDMV3-53/54/55/116 and Section 14 traceability), `decisions.md` D1-D32, `tickets/README.md` in full, epics 01, 02, 03, 04 (T24-T26), 05, 06 in full; `plugins/edm/CHANGELOG.md` 3.1.0 + 3.0.0 + wave-A entry. Code cross-checked in `bin/edm-state`, `bin/edm-lint-artifacts`, `bin/edm-check-skill-sync`, `bin/edm-sync-canonical-sections`, `evals/run-eval.sh`, `evals/baseline/README.md`, `.gitlab-ci.yml`, `bin/tests/run-all.sh`, `agents/edm-audit-*.md`, `skills/*/SKILL.md`.

---

## The two originating user requirements: both mechanically enforced

| Requirement | Enforcing code | Verdict |
|---|---|---|
| (1) `code_audit_converged` only becomes true after explicit human approval | `plugins/edm/bin/edm-state:1058` -- `SETTABLE_KEYS` does **not** contain `code_audit_converged`; `:1067` `GATE_BEARING_KEYS="code_audit_converged compliance_gate_approved gates_approved"`; `:1078-1089` unconditional `die` before any mutation, naming `approve-gate <PREFIX> code-audit`; `:1321` the *only* writer is `cmd_approve_gate`'s `code-audit` branch, reached only via `edm-state approve-gate`, the command README/CLAUDE.md put behind the `permissions.ask` rule. Blocking-side corroboration at `:1911`, `:1977`, `:2017` (archive re-queries `audit-converged` rather than trusting the cached boolean) and `:904-914` (`CONVERGED_NO_APPROVAL` blocking anomaly catches a hand-edited flag). Regression coverage: `bin/tests/wave6-smoke.sh:727-737`, `:1679-1687`, `:1721-1725`, `:1791-1794`; prompt-side absence asserted at `bin/tests/wave7-smoke.sh:341-343` and `:994-997`. | **Mechanical, not prose.** Verified. |
| (2) A literal `;` in Mermaid label text is written `#59;` | `plugins/edm/bin/edm-lint-artifacts:213-283` `mermaid_scan_awk()` -- `strip_entities()` at `:223-234` walks the `#<1..10 alnum>;` form explicitly (deliberately not an ERE interval, for bwk/mawk/busybox parity), then `is_violation()` at `:235-266` flags a raw `;` inside `[...]`, `(...)`, `{...}`, `|...|`, `"..."`, or after the first `:` on an arrow line; legal exceptions (`%%`, `classDef`/`style`/`linkStyle`, one trailing statement terminator) are explicit at `:239-250`. Wired as class 4 in `scan_md_files` at `:400-425` with a no-fence short-circuit at `:405-406`. Fixture corpus: 11 `valid/` + 5 `invalid/` = 16 files, satisfying T44 AC1's split floors (10/5/15). Runs on the commit path via `hooks/hooks.json` and in CI via `lint:artifacts`. | **Mechanical, not prose.** Verified. |

The *delivery* of requirement 2's prose half is where the gap is -- see the first P1 below.

---

## Missing Implementations (P1)

### P1-01: EDMV3-116's negative branch is half-landed -- the generated file has zero consumers

**Requirement**: EDMV3-116 ("`CLAUDE.md` by-name references resolve from an installed cache"), negative-branch AC: "the canonical sections are relocated or deterministically duplicated **into a path agents *can* resolve** -- the leading candidate being a `docs/` file inside the plugin **that agent prompts reference by relative path**" (`srd.md:3009-3012`). Ticket: T41 AC4 (`epics/06-mermaid-rule.md:152-158`).

The generator and the generated file exist (`plugins/edm/bin/edm-sync-canonical-sections`, `plugins/edm/docs/canonical-sections.md`), and the byte-identity guard exists (`bin/tests/wave6-smoke.sh:3067-3099`). But **zero prompt-surface files reference it.** All by-name references across 20 `agents/*.md` and `skills/*/SKILL.md` files still use the bare `` `CLAUDE.md Sec."..."` `` form that D22 *proved by two independent methods* does not resolve from an installed cache. EDMV3-116 is Must Have and its entire purpose is that the references resolve; a generated file no consumer points at does not achieve that.

Evidence: `grep -rn 'canonical-sections\.md' plugins/edm/{agents,skills}` returns **0 hits**. Contrast: `grep -c 'CLAUDE\.md Sec\.' plugins/edm/{agents,skills}` returns 20 files, roughly 50 occurrences (`edm-architect.md:2`, `edm-srd-writer.md:2`, `edm-ticket-auditor.md:3`, `edm-qc-auditor.md:2`, `skills/orchestrator/SKILL.md:5`, `skills/verify-runtime/SKILL.md:3`, all eleven lenses). `plugins/edm/CLAUDE.md:300` and `:718` describe `docs/canonical-sections.md` as the path prompts "should point at" -- as prose intent, not as a landed edit.

### P1-02: governance defect on top of P1-01 -- the largest open item has no named owner

D22's closing paragraph reads: "**Handoff, urgent, not yet done** ... should be picked up as **its own immediate follow-up ticket**." That is a *candidate*, not a named follow-on -- the exact construction D29 forecloses ("a candidate is not a follow-on, and 'candidate' is deferral vocabulary, which D13 bans ... and which therefore cannot stand in the initiative's own decision ledger either"). D29 names exactly one surviving ticket, **EDMV4-T01** (the AC6 budget re-derivation), and it is not this. So the largest open item in the initiative has no named owner and no closing command.

Evidence: `decisions.md:28` (D22, final paragraph) versus `decisions.md:38` (D29, which enumerates T01/T02/T03 and closes T02 and T03).

### P1-03: two mutually unsatisfiable Must-Have requirements, never reconciled through gate change control

EDMV3-54 AC mandates the reference form `` `CLAUDE.md Sec."Mermaid diagram conventions"` `` *exactly*, asserted by `grep -rho ... | sort -u | wc -l` returning 1. EDMV3-116's negative branch mandates a plugin-relative path. Both cannot hold. D22 identifies the collision and states AC7's ordering was violated (T42 landed at `fa108ee`, merged `424f3dc`, before the T41 check ran) -- honestly recorded -- but no change request amends EDMV3-54's AC, so an implementer fixing P1-01 will *break* T42 AC4's smoke assertion.

Evidence: `srd.md:2842-2848` (EDMV3-54 mandates the bare form **and** "The references are verified to actually resolve from an installed plugin cache before this requirement is considered done"); `epics/06:235-238`; `decisions.md:28`.

**Fix for P1-01, P1-02 and P1-03 (one change):** raise a change request that (a) amends EDMV3-54's reference-form AC and T42 AC4 to the `docs/canonical-sections.md` relative-path form, (b) updates the nine prompt-surface files plus the eleven lens/synthesizer files that carry `CLAUDE.md Sec."..."`, (c) re-points `bin/tests/wave7-smoke.sh`'s "eleven Mermaid touch points" and canonical-heading cases at the new form, and (d) records the work as a **named** ticket -- either appended to D29's follow-on initiative as EDMV4-T04 with a scope line and a closing verify command, or landed here. Do not leave it as "a follow-up ticket".

---

## Partial Implementations (P1)

### P1-04: six ACs whose verify command greps `.gitlab-ci.yml` for a wave-suite token that T21 AC5 forbids

Each states its verify command as a `grep` for a literal wave-suite token in `.gitlab-ci.yml`: `grep -n 'wave6-smoke' .gitlab-ci.yml` (T01 AC9, T16 AC10) and `grep -n 'wave7-smoke' .gitlab-ci.yml` (T61 AC13, T42 AC12, T44 AC6, T56's CI row).

**All six return zero hits and therefore cannot pass as written.** `grep -cE 'wave(3|4a|4b|5|6|7)-smoke' .gitlab-ci.yml` returns **0**, which is exactly what T21 AC5 *requires* (`epics/03:262`). D19 ruled T21 AC5 wins and stated T61 AC13 and T01 AC9 "are AMENDED to assert the suite runs via `run-all.sh` auto-discovery instead" -- but **the amendment was applied only to `.gitlab-ci.yml`'s job comment and `wave7-smoke.sh`'s T21 AC5 case, never to the ticket text.** The four ACs D19 does not even name (T16 AC10, T42 AC12, T44 AC6, T56) were never considered.

Evidence -- ACs: `epics/01-mechanical-fixes.md:86`, `epics/02-enforcement-kernel.md:1254`, `epics/11-cross-cutting-delivery.md:153`, `epics/06-mermaid-rule.md:279`, `epics/06-mermaid-rule.md:481`, `epics/09-pattern-library-curation.md:294`. Code side: `.gitlab-ci.yml:238` (`# AC5: this job's script is the aggregator invocation and nothing else`), `:252`, `:254-255`; `bin/tests/run-all.sh:19` holds the suite list.

**Fix:** rewrite all six verify clauses to the D19-sanctioned form -- `grep -n 'run-all.sh' .gitlab-ci.yml` returns the single invocation **and** `bash plugins/edm/bin/tests/run-all.sh` names the suite in its per-suite summary. Add a note to D19 stating six ACs were affected, not two.

### P1-05: T22 AC8's auth contract was superseded by D20 in code but never reworked in the ticket

The AC (`epics/03:400-403`) states: "the driver **requires** `ANTHROPIC_API_KEY`. Run locally without it, it exits with a usage message naming the variable. Verify: `env -u ANTHROPIC_API_KEY bash plugins/edm/evals/run-eval.sh; echo "exit=$?"` prints the variable name and `exit=2`."

**The AC text was never reworked, so its verify command fails on the documented environment.** D20 replaced the env-var-only gate with two sanctioned auth paths; on a machine with an authenticated `claude` CLI (the state D20 verified live) `env -u ANTHROPIC_API_KEY bash run-eval.sh` **starts a real, costed run** instead of exiting 2. D15 says an AC whose stated precondition does not match the runtime is a spec defect to be *reworked*; D20 reworked the code and recorded the decision but left the AC standing. The script's own header block carries the same stale contract.

Evidence -- code: `evals/run-eval.sh:164` ("Two sanctioned auth paths"), `:173-175` (dies only when **both** paths fail). Stale prose: `evals/run-eval.sh:23-24` ("`ANTHROPIC_API_KEY` **Required** for a real run ... Missing: exit 2 naming this variable") and `:34`. Stale closing command: `evals/baseline/README.md:10`, `:24`, `:28` all presuppose an exported key.

**Fix:** rewrite T22 AC8 to "refuses to start with no working auth at all, naming both sanctioned paths", verified by `env -u ANTHROPIC_API_KEY PATH=/usr/bin:/bin bash run-eval.sh; echo exit=$?` returning `exit=2`; correct `run-eval.sh:23-24,34` and `baseline/README.md:24,28` to the two-path wording.

---

## Scope Creep (P2)

### P2-01: `bin/edm-check-skill-sync` was built despite an explicit prohibition, and does the inverse of what the spec describes

**T39 explicitly forbade building it.** `epics/05:628`: "`bin/edm-check-skill-sync` is written **only** on the fallback path. **Do not build it speculatively.**" `epics/05:101` repeats it ("EDMV3-T39, and **only on NO-GO**"). AC7 is conditional: "**if the comparison fails**, the documented fallback is adopted -- revert the dispatcher change and ship `bin/edm-check-skill-sync` instead". The dispatcher shipped; the comparison never ran (D23); the fallback was not adopted.

Two distinct problems, both worth closing:

1. The script exists in violation of an explicit ticket prohibition. Its own header at `:5-14` acknowledges this and argues for it, and D23 records it as shipped, but **neither T39 AC7 nor T39's Technical Notes nor `srd.md:2754` was amended** -- so the tree contradicts the spec with no change-control record.
2. **It does not do what the spec says it should.** EDMV3-52 / T39 AC7 specify "a script asserting the duplicated orchestration blocks **are identical**" (`srd.md:2754`, `epics/05:603-605`); the shipped script asserts the **inverse** -- that `## Operational Orchestration` appears in *no* phase-skill copy inside the dispatcher and in *every* phase skill (`bin/edm-check-skill-sync:42-60`). That is a re-purposed anti-duplication guard, not the specified sync-checker.

**Fix:** amend `srd.md` EDMV3-52 and T39 AC7 to describe the guard that actually shipped and why the not-taken branch was still built and wired, or delete the script and its `run-all.sh` call. Do not leave the SRD describing a script the tree does not contain.

---

## Field-name and boundary-record defects (P2)

### P2-02: T06 AC10 names three state fields the code does not write

The AC names the code-audit gate's three sibling scalars as `code_audit_converged_at`, `code_audit_converged_approver`, `code_audit_converged_enforcement`. **The code writes different names**: `code_audit_gate_approved_at`, `code_audit_gate_approver`, `code_audit_gate_enforcement` (plus `code_audit_gate_ledger`). The AC's verify command only checks that `code_audit_converged` stays type `boolean`, so the naming divergence is invisible to the test that is supposed to close the AC. `bin/edm-state` and `CLAUDE.md` are internally consistent on the `_gate_` names; only the ticket disagrees.

Evidence -- AC: `epics/02-enforcement-kernel.md:185-193`. Code: `bin/edm-state:1322-1325`; anomaly reader `:912`; HANDOFF renderer `:2345`.

**Fix:** amend T06 AC10 to the three `code_audit_gate_*` names (the shipped names are the better ones -- they parallel `compliance_gate_*`) and add a `jq -e 'has("code_audit_gate_approved_at") and has("code_audit_gate_approver") and has("code_audit_gate_enforcement")'` assertion so the names are actually checked.

### P2-03: T23 AC13's precondition is permanently gone, so no closing command can satisfy it

"the baseline is captured **before the first wave-B commit**. This ticket is a wave-A exit criterion." Wave B shipped at 3.0.0 and wave C at 3.1.0, so **no closing command can ever satisfy this AC** -- its precondition is permanently gone. D23 records the missing baseline at length with a valid closing command, and the wave-A CHANGELOG entry records it in one clause (`CHANGELOG.md:545-546`), but **neither addresses AC13's temporal clause**, and D23 is framed entirely around T39, never naming T23. Under D15 this is a specification defect requiring rework, and D13 forbids leaving it.

Evidence -- AC: `epics/03-ci-and-fixture-eval.md:566-569`. Absent artifact: `plugins/edm/evals/baseline/scores.json` does not exist (`ls plugins/edm/evals/baseline/` returns `README.md` only). Recorded: `decisions.md:29` (D23); `CHANGELOG.md:545-546`; `evals/baseline/README.md:3-20`.

**Fix:** rework T23 AC13 into something verifiable today -- for example "the baseline is captured and committed, and `git log -1 --format=%cI plugins/edm/evals/baseline/scores.json` is recorded in `CHANGELOG.md` alongside the SHA the run was taken against" -- and extend D23 to name T23 AC8/AC9/AC13 explicitly, not only T39 AC1.

### P2-04: the ticket pack contradicts itself on which SRD revision its coverage map derives from

The header at `tickets/README.md:3` says `Generated From: srd.md v1.3.0` and **agrees** with `srd.md` v1.3.0. But the same file contradicts itself twice: `:10` records `| SRD | ../srd.md **v1.2.0** (120 requirements ...) |` and `:576` opens the SRD Coverage Map with "Every requirement in `../srd.md` **v1.2.0** appears exactly once below". `:759` and `:772` also anchor CR1-CR6 to v1.2.0 (correct as history). So the answer to "do they agree" is: the header does, the pack's own metadata table and its Coverage Map do not. A reader reconciling coverage against v1.3.0 is reading a map that declares itself derived from the previous revision.

Evidence: `tickets/README.md:3` versus `:10` versus `:576`.

**Fix:** bump `:10` and `:576` to v1.3.0, or add one sentence stating the v1.3.0 delta introduced no requirement changes so the v1.2.0-derived coverage map remains exact. Leave `:759`/`:772` at v1.2.0 -- they are correctly historical.

---

## Noted / Not Actionable

- **`SETTABLE_KEYS` widening** to `coverage_by_epic`, `test_frameworks_detected` (`bin/edm-state:1058`). Justified in the comment at `:1056-1057` as existing call sites in `agents/edm-test-coverage-auditor.md` / `agents/edm-test-planner.md`; T09 AC11 names only `test_layer_skipped`, `last_decision`, `estimated_size` as "known live call sites". **NOTED** -- T09 AC5 requires the allowlist to enumerate "every legal key" and AC11/AC12 make callers the source of truth, so keys derived from live callers are in scope by construction. Recorded only because a reader comparing AC11's three named keys against the twelve-key list will wonder.
- **D23** (eval baseline never captured across seven attempts) -- verified genuinely recorded: names the seven attempts and the six driver defects they fixed, states exactly what shipped versus what is open, and carries an executable closing command (`decisions.md:29`). `bin/edm-compare-eval`'s distinct exit 3 for "no baseline -- tripwire not armed" is the mechanical guarantee that an absent baseline cannot read as a pass. Recorded boundary, not a gap.
- **D28** (tiering matrix built, never run; all 15 contested assignments unchanged) -- verified recorded with rationale, a `--self-test` proving all three logic branches, a provenance header on `CLAUDE.md`'s Model and effort table stating it is not matrix-derived, and a full closing command (`decisions.md:36`; `CHANGELOG.md:148-156`). T48 AC11 and T67 AC12's tiering half are covered by it. Recorded boundary.
- **D26 as amended** -- verified: AC5 PASS with the re-profiled 70,168 ms to 1,021 ms figure and its root cause corrected in place; AC10 PASS with the four-job split; AC6 passing at 1.19x with the budget *shape* still explicitly called malformed and carried to a named follow-on. The entry supersedes its own earlier wrong figures rather than leaving them standing (`decisions.md:34`; `CHANGELOG.md:194-249`). Recorded boundary.
- **D27** (AC9 blocking-pipeline duration, AC13 eval-run duration) -- verified recorded as `verified-locally-pending-pipeline` in the CHANGELOG budget table rather than asserted PASS, with the missing dependency named in each case (`decisions.md:35`; `CHANGELOG.md:204`, `:208`). Recorded boundary.
- **D29** (one surviving follow-on, EDMV4-T01) -- verified: T02 and T03 are marked CLOSED with the commits that closed them and their satisfied verify commands, T01 carries a scope line and a closing verify command, and the entry is amended in place rather than left describing finished work (`decisions.md:38`). The one gap in D29 is that it does **not** absorb D22's handoff -- reported above as P1-02.
- **D30** (`git ls-files` accepted over `find`) -- verified: a decision record, not a job comment; argues equivalence on the CI surface via `GIT_CLEAN_FLAGS=-ffdx`, closes the untracked-becomes-tracked path twice over, and records both forms measured returning 0 on the live tree. AC5's text and the Technical Notes are amended to match (`decisions.md:39`). Accepted trade-off.
- **D32** (pricing table has no row for the models actually used) -- verified: the family-wildcard defect is fixed in code (explicit `*opus-4-8*` / `*sonnet-4-7*` / `*haiku-4-6*` arms ahead of the warning arm), the $25.869 figure is left as recorded rather than repriced against invented rates per T52 AC9, a reproduce command is given, and the outstanding work (verified Sonnet 5 / Fable 5 / Opus 5 rows) is stated as belonging to EDMV4 (`decisions.md:41`). Accepted trade-off -- though note this is the *second* item pointed at EDMV4 without a ticket number, alongside D22's handoff.
- **D8 / EDMV3-88** (no Mermaid renderer spike) -- verified as a recorded boundary with no ticket by construction; the deterministic lint class ships regardless (T43) and T44's corpus validates the rule, not the renderer.
- **T38 AC11** ("the eval artifact is a hard acceptance criterion ... the MR has `scores.json` attached and T39's comparison job is green") -- unmet, but covered by D23's explicit "Risk accepted knowingly: T37/T38 landed with 1124/1124 suite coverage and the T2-09 two-commit reviewable structure, but without the empirical regression number the review named as their mitigation." Recorded boundary with a closing command; folded into D23 rather than reported separately.
- **EDMV3-30/31 (T24)** -- verified satisfied, not prose-only: `"schema":1` present in all eleven lens files, `every finding` present in all eleven, `count match does not imply` present in all eleven plus `architecture.md`, `contract violation` present in all twelve code-audit agents (T02 AC7's expected count of 12), and the AC0 fixture is on disk at `bin/tests/fixtures/code-audit/` with all eleven `lens-L*.jsonl`/`.md` pairs plus `lenses-run.txt`.
- **EDMV3-37 (T28)** -- verified: `BLOCKING_FILTER` is defined exactly once at `bin/edm-state:809` and includes open **P2**, matching the convergence-gate description the wave-C sweep corrected (`skills/code-audit/SKILL.md:79`, `:247`); the five-occurrence count (1 definition + 4 consumers) is asserted at `bin/tests/wave6-smoke.sh:2754-2757`. Legacy `deferred` is re-opened rather than skipped, per T25 AC4.
- **D12 / R2 / R8 / T60 gate closure** -- spot-checked against the Finding-to-Commit Ledger (`decisions.md:47-52`) and found genuinely closed with reproducible greps and a fourth `claude plugin validate` run taken against the current tree rather than inferred from the deletions.

---

## Not verified (commands named, not run)

Every AC in epics 01-06 and the T61 block of epic 11 was read, and those whose subject was reachable by grep were cross-checked. The following were **not** independently executed and are asserted only by the CHANGELOG / QC-shard record:

1. `bash plugins/edm/bin/tests/run-all.sh` -- the 1401-assertion suite. Every AC of the form "Verify: `bash plugins/edm/bin/tests/wave{6,7}-smoke.sh` (case "...")" rests on this. The *named cases exist* for T08 AC1/AC4, T09 AC1-AC3, T17 AC3, T14 AC3, T16 AC1/AC4, T28 AC9/AC11, T41 AC4/AC5, T59 (both halves) and T66 AC12, confirmed by grepping the suite files, but the suite was not run from this lens.
2. `claude plugin validate plugins/edm/` -- T02 AC9, T03 AC11, T60 AC1. Asserted four times in `decisions.md:52`.
3. `bash plugins/edm/bin/edm-check-grants` -- T02 AC10, T03 AC2/AC4, T35 AC8, T38 AC4/AC13.
4. `bash plugins/edm/bin/tests/timing.sh --lint` / `--mermaid-ratio` -- the T67 budget table figures (D26).
5. `bash plugins/edm/evals/score-artifacts.sh plugins/edm/bin/tests/fixtures/code-audit/` -- T24 AC10's dimension-5 non-null cross-check.
6. `bash plugins/edm/evals/tiering-matrix.sh --self-test` -- D28's 3/3 claim.
7. Epics **07 (T45-T49), 08 (T50-T53), 09 (T54-T56), 10 (T57-T60)** and epic **11's T62-T67** -- AC bodies not read line by line. All fall inside the T45-T67 range the two QC shards audited and remediated, and that coverage was relied on per this lens's brief. The one exception surfaced from epic 09 is the T56 CI-row verify command (`grep -n 'wave7-smoke' .gitlab-ci.yml`), reported as part of P1-04 -- which suggests the shards did not catch this class either, so a targeted re-sweep of T45-T67 for `.gitlab-ci.yml`-literal verify commands is worth one grep.

---

## Summary

**Total actionable: 5 P1 (three of which share one root cause -- the EDMV3-116 reference-form gap), 4 P2. Zero P0.**

No finding here is postponable: D6/D13 make open P2 blocking, so all nine need a fix or a `NOTED` argument before this round converges.
