# Lens L2 -- Dead Code & Unreachable Paths (round 6, pass-6_2026-08-10)

**Tooling note (CA-130's class, sixth consecutive round):** Write/Edit/Bash absent
from this lens's delivered runtime tool set. This report was transcribed by the
orchestrator from the lens agent's final message.

## Findings (L2: Dead Code & Unreachable Paths)

### L2-001 -- P1 -- the two wave-B `schema_version >= 2` enforcement arms are environmentally unreachable for every initiative the current plugin creates; CA-182's class at the two sibling sites its remediation never swept

**Component**: `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-state:2148` and `:2697` (consequences at `:2149-2154`, `:2708-2720`, `:2728-2739`); doc half at `/Users/darryl.porter/projects/marketplace/plugins/edm/CLAUDE.md` Sec."Unverifiable acceptance criteria (D15)".

**Why it is unreachable.** `_cmd_init_render:1755` writes the literal `schema_version: 1`. `schema_at_least "$sv" 2` returns `1` (the middle class), never `2`, for that value. `cmd_migrate_schema` is the only writer that can ever reach 2 -- and it is reachable from no runtime surface: a grep for `migrate-schema` across `plugins/edm/` returns matches only in `bin/edm-state` itself, `bin/tests/wave6-smoke.sh`, `bin/tests/wave7-smoke.sh`, `CLAUDE.md` and `CHANGELOG.md`. **No skill, no agent, no hook mentions it.** `_write_handoff_body:4782` renders the "run `edm-state migrate-schema`" prompt only when `schema_version` is *absent*, so a `schema_version: 1` initiative is never even told to migrate. And `cmd_migrate_schema` additionally requires a non-empty `code-audit/findings-ledger.jsonl` on disk plus zero open PARTIALs before it will even target 2, behind an interactive `yes` confirmation.

Therefore, for every initiative created by the current plugin version:

- `cmd_phase_complete`'s phase-6 open-PARTIAL refusal at `:2149-2154` never executes. The `else` warn at `:2156` always does.
- `cmd_archive`'s AC1e PARTIAL-closure refusal at `:2708-2720` and its AC1f `audit-converged` re-query at `:2728-2739` never execute. The two warn-and-`record_degraded_check` lines at `:2698-2701` always do.

**Why this is a finding and not the documented three-valued model.** The in-code comment at `:2142-2146` presents this as EDMV3-T14 AC6's intentional middle class. That framing is exactly the framing the project has already ruled a defect: **CA-182 was raised P0 and fixed in round 4 for the byte-identical construction one function away** (`cmd_approve_gate`'s convergence precheck ran only at class 2; its own ledger entry reads "*for every initiative created by the current plugin version the precheck is environmentally unreachable*"). CA-182's fix made that precheck unconditional and degraded only its exit-3 arm. The same remediation was not applied to these two sites, so the False Alarm Filter's criterion 2 does not save them -- the comment asserting correctness is the same comment CA-182 invalidated.

**Live consequence.** `CLAUDE.md`'s D15 section states: "*Archive stays hard-blocked until every AC in `partial_verdict_map` carries a `closing_verdict` of PASS or FAIL.*" That sentence is **false in the shipped default configuration** -- `edm-state archive` proceeds with unclosed or FAIL-closed PARTIAL verdicts on any initiative at `schema_version: 1`. CA-316 swept the *approve-gate* half of this documentation class (`CLAUDE.md:847`); the D15 half is unswept.

**Why P1 and not P0.** There is a real compensating control, and it is deliberate: `state_anomalies`' `OPEN_PARTIALS` anomaly is explicitly *not* schema-gated (see the rationale at `:1500-1502`) and is `blocking`, so `edm-state validate` -- and CI's `test:state-validate` job, `.gitlab-ci.yml:434-476` -- still fails on open/FAIL-closed partials. But `cmd_archive` never calls `state_anomalies`, so the archive command itself carries no refusal, and the D15 hard-block is a CI-only property rather than a kernel one.

**Fix (delete or correct: correct).** Mirror CA-182's own prescription at both sites: run each check unconditionally and degrade only on the genuinely-absent shape (`partial_verdict_map` empty / no `findings-ledger.jsonl`), not on the version number. Then either (a) sweep `CLAUDE.md`'s D15 sentence to the shipped contract, or (b) leave D15 as-is once the checks are unconditional, which is the outcome that makes the sentence true. Add a `wave6-smoke.sh` case at `schema_version: 1` with one open PARTIAL asserting `archive` and `phase-complete 6` both exit non-zero -- the coverage gap that let this survive four rounds is that no assertion exercises either check at the version every initiative actually carries.

**Secondary observation, same mechanism, lower impact (fold into the same pass):** `cmd_audit_converged:4106-4111` -- the `unknown` round_type *refusal* (`return 1`) is likewise unreachable at `schema_version: 1`; only the warn-and-proceed at `:4111` fires. The `partial` refusal at `:4112-4114` is correctly ungated and does fire. Impact is narrow (it needs a `findings-ledger.jsonl` present with no `audit_rounds` entry, i.e. a hand-written ledger), which is why it does not carry its own severity here.

---

### L2-002 -- P2 -- `edm-compare-eval`'s reachable REGRESSION path routes the operator to a fallback branch the project has settled does not exist

**Component**: `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-compare-eval:133-135`.

The regression path prints:

```
edm-compare-eval: adopt the documented fallback (EDMV3-T39 AC7): revert the dispatcher and
edm-compare-eval: ship bin/edm-check-skill-sync instead, recording the comparison in decisions.md.
```

`/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-check-skill-sync:5-9` states the opposite as settled fact: "*EDMV3-T37/T38 deduplicated the phase procedures ... **This is not a fallback for a branch that was not taken (the GO path was taken)**; it is a permanent regression tripwire ... run unconditionally by `bin/tests/run-all.sh` on every invocation of the smoke suite, not only after a comparison failure.*"

So the branch this message routes to is dead in both halves: `edm-check-skill-sync` already ships and already runs unconditionally (so "ship it instead" is a no-op instruction), and "revert the dispatcher" reverses the shipped architecture that `CLAUDE.md`'s architectural rule 2 and `bin/edm-check-skill-sync` itself now enforce. An operator following this line on a genuine score regression would undo the initiative.

This is L2 rather than pure L6 because the dead artifact is a *decision branch preserved as live control-flow guidance* on a reachable path, not merely a stale sentence. Shared surface with L6 (documentation accuracy) -- flag for merge if L6 files the same lines.

**Fix (correct, do not delete the exit path).** Replace the two lines with the real remediation for a score regression on the shipped architecture -- investigate the per-dimension delta table this script already prints, and record the comparison in `decisions.md` -- and drop the "revert the dispatcher / ship edm-check-skill-sync instead" clause entirely. Note in passing that `EDMV3-T39 AC7` is cited here as if it were still a live option; that citation needs the same treatment.

---

### L2-003 -- P2 -- the `''` alternative of run-eval's four numeric-sanity `case` guards is preempted by the `${x:-0}` substitution on the immediately preceding statement (CA-140/CA-202/CA-260 class, four sites)

**Component**: `/Users/darryl.porter/projects/marketplace/plugins/edm/evals/run-eval.sh:616-624`.

```
616  in_tok=$(jq -r '.usage.input_tokens // 0' "$raw" 2>/dev/null); in_tok="${in_tok:-0}"
...
621  case "$in_tok" in ''|*[!0-9]*) in_tok=0 ;; esac
```

`${in_tok:-0}` substitutes on unset **or null**, so by the time control reaches `:621` the variable is guaranteed non-empty. The `''` alternative of the `case` at `:621`, `:622`, `:623` and `:624` can therefore never match -- the empty-capture case it was written for (a `jq` failure on a malformed `raw/*.json`, with the diagnostic already swallowed by `2>/dev/null`) is consumed one line earlier. The `*[!0-9]*` alternative remains live and is the stronger guard.

This is the same "coercion inserted above a pre-existing guard leaves the guard's own arm dead" shape as CA-140 (`schema_at_least`'s `-z` disjunct), and the same dead-default family as CA-202, CA-260 and round-5's `timing.sh:327` finding -- all of which this project chose to remove rather than keep, so criterion 3 of the False Alarm Filter argues for filing rather than noting.

**Fix (delete).** Drop the four `; <var>="${<var>:-0}"` re-assignments on `:616-619` and let the `case` at `:621-624` be the single guard -- it already handles empty and non-numeric identically. (`cost` at `:620` has no `case` companion, so its `${cost:-0}` is load-bearing and must stay.)

---

## Noted / Not Actionable

- `bin/edm-state:1125-1129` -- the `elif [[ $_lock_ec -eq 99 ]]` arm reintroduces G49's original 99-misreport shape, but no locked body in the file exits 99 today (`_cmd_init_body` returns 10, `_rmw_state_body` returns 1, `write_atomic` returns jq's status), so the misreport is latent, not live; the arm itself is CA-305's deliberate secondary diagnostic for a failed marker `mkdir`.
- `bin/edm-state:485-494` vs `:502-514` -- the `unknown)` sentinel arm and the `*)` fallback set identical rates, but the arms differ behaviourally (the sentinel arm deliberately suppresses the AC10 warning), so this is not CA-054's byte-identical-duplication shape.
- `bin/edm-state:453-519` `compute_cost_usd` has no arm matching any model in current use -- CA-105, standing.
- `bin/edm-state:1319-1329` `schema_at_least` -- CA-140's dead `-z` disjunct is gone; the surviving `-eq 0` / `-ge min` / `else` triple is exhaustive and all three arms are reachable.
- `bin/edm-state:2013-2017` (now `:2530-2539`) `cmd_migrate_schema`'s advance-by-one -- CA-119, and confirmed *not* a pure no-op: with `current_version=0` and a computed target of 2 it correctly yields 1.
- `bin/edm-state:3063-3075` `has_tiering_data` -- CA-107, no producer of `.tiering_results`, documented in place.
- `bin/edm-state:4495-4500` `pattern_target_heading_for`'s single-arm `case` -- CA-114, the documented extension point.
- `bin/edm-state:4268` `${close_prior_verdict:-PARTIAL}` -- jq's `// "PARTIAL"` makes this near-dead, but an explicitly hand-edited `"verdict": ""` is truthy in jq and would pass through empty, so it is defensive rather than provably unreachable; deliberately not filed alongside L2-003.
- `bin/edm-state:5024-5028` -- the `*)` arm of the `open_findings_summary` case is reachable on `cmd_audit_converged` exit 3 (no ledger), the common case.
- `bin/edm-state` -- `cmd_lint` and its dispatcher arm are gone from the file entirely; CA-247's L2 residual (zero callers) is closed, not reopened.
- `bin/edm-lint-artifacts:365-368` -- the class-4 loop carries no `UNREADABLE_FLAGS` guard unlike its four sibling loops, but an unreadable file's `MERMAID_SETS[$i]` is set to `""` at `:275`, so the `[[ -z "$mermaid_set" ]] && continue` is an equivalent guard, not a missing one.
- `bin/edm-check-grants:509-514` -- the `if [[ "$_class" == "Edit" ]]` arm's body is identical to the first statement of its own `else`, and `${WORKDIR}/Edit_instructed.txt` is never created so the `grep` could never match anyway; the comment at `:489-496` documents this as the intentional always-warn construction that found the synthesizer's unexplained `Edit` grant.
- `bin/edm-check-grants:103-106` and `bin/edm-check-vocabulary:184-188` -- both files carry an explicit G41 comment stating *why* a guard was removed as unreachable; the reasoning checks out in both cases (every surviving path either died or shifted to `$#==0`; `SCOPE_ROOTS` always contributes `CLAUDE.md` and `README.md` or dies).
- `bin/_edm-lint-lib.sh:196-204` -- `mermaid_line_set` / `marker_line_set` have zero external callers; CA-200, documented honestly in place at `:51-62`.
- `bin/tests/timing.sh:86-87` (`_p95`'s two index clamps), `:183` (`_measure_p95`'s arity guard), and the `--self-test` mode having no automated caller -- all covered by CA-328 and the in-file note at `:96-101`; `run-all.sh` deliberately does not discover this file.
- `bin/tests/timing.sh:429` -- `${actual_initiatives:-0}` is gone (round-5 L2-002 closed); the surviving `|| true` on the `grep -c` pipeline is load-bearing under `set -e`, not a dead default.
- `.gitlab-ci.yml:331-332`, `:348-349` -- `${count:-0}` / `${orphan_count:-0}` over a `grep -c` capture is the same dead-default shape as L2-003, already NOTED at this site in round 5 under criterion 3 (consistent inline-in-a-CI-test idiom); not re-filed.
- `.gitlab-ci.yml:661` -- `if [ -f plugins/edm/evals/score-artifacts.sh ]` guards a tracked file, but a shallow or path-filtered checkout could legitimately lack it; cheap and defensible.
- `.gitlab-ci.yml:675-681` (the `0)` and `*)` arms) and `bin/edm-compare-eval:64-136` in full -- environmentally unreachable today only because `evals/baseline/scores.json` has never been captured, so every invocation exits 3 at `:61`; D23, CA-106, CA-323 and CA-332 already record that and the exit-3 path is explicitly designed to report "NOT ARMED" rather than pass silently. (The stale *message* on the regression path is filed separately as L2-002.)
- `.gitlab-ci.yml:400-416` -- `test:smoke-bash32` now installs via `apk add` against `bash:3.2`'s own Alpine base; CA-006's "before_script always fails, `script` never runs" unreachability is closed and did not recur.
- `.gitlab-ci.yml:640-651` -- `eval:nightly`'s trailing `- when: never` is reachable (any non-default, non-MR, non-schedule pipeline with the key set), so it is a real catch-all, not dead.
- `hooks/hooks.json:19/32/45/58/71` and the five sibling prompt bodies -- CA-298 is closed: each command hook now probes `edm-state resolve-dir ... || exit 0` before `gate-check ... || exit 2`, and the "if it fails (no initiative found yet), this is a legitimate first invocation -- allow expansion" clause in every prompt body now matches the deterministic half rather than contradicting it.
- `skills/plan/SKILL.md:46-63` -- CA-308 is closed: the canonical Step 0 block now names all seven substituting skills and their values, and `bin/tests/wave7-smoke.sh`'s "G15" case asserts every one, so `current_step`'s `1`..`6` vocabulary has real producers and the resume-to-phase-N path is no longer environmentally starved.
- `skills/code-audit/SKILL.md:40-56` -- CA-004 is closed and did not recur: `--lenses "${LENS_SET_CSV}"` is passed unconditionally and `:56` states it is not optional even on a full round, so `cmd_audit_round_start`'s `partial` derivation is reachable from its only caller.
- `bin/edm-init:142-155` -- the `standard|iac|data-ml` and `mini-srd` arms have byte-identical bodies (`mkdir -p "$DIR/code-audit"`), but each carries its own distinct documented rationale and the `case` is exhaustive over the five-value enum `:56-59` already validated; this is an L10 (DRY) surface, not dead code.
- `bin/edm-validate-prefix:80` -- the archived-product glob loop is not wrapped in the `[[ -d "$SRD_ROOT" ]]` guard its sibling at `:58` uses, but an unmatched glob yields the literal pattern which the `-d` test rejects, so the loop body is correctly skipped rather than unreachable-by-accident.
- `agents/edm-audit-dead-code.md:5` -- CA-130 reproduces a **sixth** consecutive round, tool-set half only: this lens was delivered with `Read`/`Grep`/`Glob`/`WebFetch`/`WebSearch`/`TaskStop` and **no `Write`, `Edit` or `Bash`**, so it cannot write its own assigned artifact and cannot execute `bin/tests/run-all.sh` to confirm suite greenness. Recorded here rather than re-filed as a finding, per the ledger's existing NOTED entry -- but note the round-5 CA-331 standing recommendation ("a Bash-capable pass should run the aggregator before every convergence gate") applies again: **this lens could not verify the 1996-assertion suite state**, and every claim above is from static reading only.

## Coverage note (read this before treating the round as L2-complete)

Full reads this round: `bin/edm-state` (all 5194 lines), `bin/edm-lint-artifacts`, `bin/_edm-lint-lib.sh`, `bin/_edm-cli-lib.sh`, `bin/edm-init`, `bin/edm-validate-prefix`, `bin/edm-check-grants`, `bin/edm-check-vocabulary`, `bin/edm-check-skill-sync`, `bin/edm-sync-canonical-sections`, `bin/edm-compare-eval`, `bin/tests/timing.sh`, `evals/run-eval.sh`, `hooks/hooks.json`, `.gitlab-ci.yml`, `skills/plan/SKILL.md` (Step 0 region).

Targeted-grep only, **not** fully re-read: `evals/score-artifacts.sh`, `evals/tiering-matrix.sh`, `bin/edm-mermaid-rules.awk`, the seven `bin/tests/*-smoke.sh` suites, `bin/tests/_harness.sh`, `bin/tests/run-all.sh`, and the remaining `skills/*/SKILL.md` + `agents/*.md` prompt bodies and `docs/`. Round 5's L2 raised nothing new in the eval scorers, and the prior L2 entries there (CA-120, CA-121, CA-139) are all closed or NOTED, but a follow-on pass with `Bash` should re-walk the smoke suites specifically -- three of the last four L2 findings (round-5 L2-002 and L2-004, CA-307) were *inside* `bin/tests/`, and that is the surface I was least able to cover with the tools delivered.
</content>
