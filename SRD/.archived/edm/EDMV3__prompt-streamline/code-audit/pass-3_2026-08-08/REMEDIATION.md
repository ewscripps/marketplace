# Code Audit Remediation Plan: EDMV3 -- prompt-streamline (Round 3)

## Context

- Audit date: 2026-08-08
- Round: 3 of N. **Round type: full (all 11 lenses ran: L1-L11)** -- this round can satisfy the convergence gate.
- Audited scope: `plugins/edm/**` (bin/, bin/tests/, agents/, skills/, evals/, hooks/, docs/, monitors/) plus repository-root `CLAUDE.md`, `.gitlab-ci.yml`, `.gitignore`, and `SRD/edm/EDMV3__prompt-streamline/**` (srd.md, tickets/, decisions.md, architecture.md) for L9
- Branch: `edm/edmv3-prompt-streamline`
- SRD: `SRD/edm/EDMV3__prompt-streamline/srd.md`
- Ticket pack: `SRD/edm/EDMV3__prompt-streamline/tickets/`
- Cross-round ledger (authoritative): `SRD/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl`
- Deployment target: local + GitLab CI (pipeline not yet first-enabled; image digests are placeholders per NOTED CA-111)
- Remediation waves landed since round 2: Wave 3, 4a, 4b, 5, 6a, 6b

## Convergence Check

**NOT CONVERGED.** `BLOCKING_FILTER` (`bin/edm-state:1150`) includes P2, so every P0, P1 and P2 row below blocks. Only `NOTED` does not.

| Severity | Open before round 3 | Fixed this round | Re-opened | New | **Open after round 3** |
|---|---|---|---|---|---|
| P0 | 2 | 1 (CA-002) | 0 | 0 | **1** |
| P1 | 13 | 12 | 1 (CA-036) | 12 | **17** |
| P2 | 77 | 57 | 0 | 52 | **69** |
| **Total blocking** | **92** | **70** | **1** | **64** | **87** |
| NOTED (non-blocking) | 40 | -- | -- | 3 | 43 |

Four prior P2 findings were **escalated to P1** on this round's evidence: CA-019, CA-142, CA-143, CA-146. One prior P2 was **escalated to P1 as a new ID** (CA-186) on three-lens corroboration.

Remediation throughput was high and real -- **70 of 92 blocking findings (76%) verified closed with fresh evidence**, and no lens found a falsely-closed entry outside the six partials it re-scoped. But the round is further from Approve than the fixed-count suggests, because **21 of the 64 new findings were introduced by this session's own remediation waves**. The gap to convergence is 87 findings, not the ~22 a naive carry-forward would predict.

Realistic path to Approve: close P0 + all 17 P1 in Wave 7, then either close the 69 P2 or explicitly demote a documented subset to NOTED with rationale. A round-4 full pass is required either way -- a partial round cannot satisfy the gate.

## Findings Summary

| # | ID | Sev | Lens(es) | Component | Issue |
|---|---|-----|----------|-----------|-------|
| G1 | CA-182 | P0 | L1+L2+operator | `bin/edm-state:1679-1688` | Code-audit gate unconditionally approvable at `schema_version: 1` -- the value `cmd_init` always writes |
| G2 | CA-142 | P1 | L2+L3 | `bin/edm-state:512-537` | `_EDM_CLEANUP_PATHS` cleanup subsystem is dead code: CA-025's subshell fork makes CA-142's own fix unreachable |
| G3 | CA-143 | P1 | L2+L3 | `bin/edm-state:555-558` | Zero INT/TERM/HUP coverage during the locked write on the mkdir branch (the only branch macOS takes) |
| G4 | CA-184 | P1 | L1+L3 | `bin/edm-state:1045-1046` | `with_state_lock` mkdir branch captures `$?` on the next line -- CA-134's class in the sibling function |
| G5 | CA-036 | P1 | L4 | `bin/tests/wave6-smoke.sh:3657` | RE-OPENED: unguarded command-substitution assignments abort the suite; 3 new sites from the CA-040 fix |
| G6 | CA-189 | P1 | L4 | `bin/tests/wave7-smoke.sh:1859` | CA-035's fix added a hard `bc` dependency no CI image installs; suite CRASHes ~2,900 lines in |
| G7 | CA-146 | P1 | L4 | `bin/tests/run-all.sh:59-141` | NOT IMPLEMENTED: zero test coverage of the aggregator whose exit code is the blocking CI verdict |
| G8 | CA-186 | P1 | L1+L3+L8 | `hooks/hooks.json:86` | Trailing-slash or absolute `srd_root` silently disables all commit-time enforcement (fails open) |
| G9 | CA-187 | P1 | L1+L6 | `bin/edm-lint-artifacts:43-44,:53-55` | This round's remediation inverted two `--help` statements; they now say working enforcement is broken |
| G10 | CA-185 | P1 | L1+L3 | `bin/edm-state:341,:371` | CA-060's fix emits a third `attribution_mode` value no consumer, doc or test accepts |
| G11 | CA-019 | P1 | L1+L7+L10 | `bin/edm-lint-artifacts:169-219` | The blocking linter never adopted the shared Mermaid rule; three headers claim it did |
| G12 | CA-188 | P1 | L3+L5 | `evals/run-eval.sh:553-571` | New retention prune `rm -rf`s unrelated directories under `--out` and mis-computes its keep window |
| G13 | CA-193 | P1 | L11 | `skills/code-audit/SKILL.md:207-213` | CA-164's fix made the lens JSONL schema pointer-only; zero JSONL emitted this round, dim-5 silent |
| G14 | CA-195 | P1 | L11 | `skills/test-plan/SKILL.md:27-29` | CA-098's legacy-flat-path break survives at 17 sites incl. 4 agent launch templates; live-falsified |
| G15 | CA-194 | P1 | L11 | `bin/edm-state:3128-3132` | `current_step` has three consumers and no producer anywhere in the prompt surface |
| G16 | CA-190 | P1 | L9 | `tickets/epics/05:358-361` | T37 AC6 verify sums to 7 not 8; shipped test implements a different contract, no change-control record |
| G17 | CA-191 | P1 | L9 | `tickets/epics/05:593-599` | T39 AC5's verify phrase exists nowhere in `run-eval.sh`; no re-verification record in D23 or CHANGELOG |
| G18 | CA-192 | P1 | L9 | `tickets/epics/05:622-625` | T39 AC9's plotting script does not exist and is described nowhere |
| G19 | CA-017 | P2 | L1+L6 | `bin/edm-lint-artifacts:24-37` | Class enumeration still omits `unreadable`; `CLAUDE.md:744` still says four classes |
| G20 | CA-037 | P2 | L4 | `bin/tests/wave7-smoke.sh:1318-1322` | ~20 expect-zero assertions still carry no positive control (4 named ones fixed) |
| G21 | CA-049 | P2 | L2+L7+L10 | `bin/tests/_harness.sh:41-66` | Three shared test helpers landed with zero callers; the 3 duplicate preambles survive intact |
| G22 | CA-061 | P2 | L3 | `bin/edm-state:1356-1360` | First `gate-check` for a legacy initiative still writes; read-only checkout now reports a lock timeout |
| G23 | CA-064 | P2 | L3 | `evals/score-artifacts.sh:534-539` | Absent `run.json` still scores `complete: true`, contradicting the sibling branch's own rationale |
| G24 | CA-074 | P2 | L7 | `bin/edm-sync-canonical-sections:47` | 4th `die()` shape carries the exact defect CA-074 removed from its sibling |
| G25 | CA-089 | P2 | L9 | `architecture.md:647,:873` | Companion document of record still states the inverse of the shipped tripwire |
| G26 | CA-094 | P2 | L10 | `bin/tests/wave7-smoke.sh:3041` | Grants half of the shared-capture conversion missed at 6 sites under a comment saying none remain |
| G27 | CA-101 | P2 | L4 | `bin/tests/fixtures/mermaid/valid` | No valid fixture proves a legal paren/curly label with a trailing terminator passes |
| G28 | CA-138 | P2 | L2+L4 | `evals/tiering-matrix.sh:308-315` | Hardcoded `6/6` denominator leaves the CA-104 boundary guard itself unguarded |
| G29 | CA-141 | P2 | L3 | `bin/edm-state:967-977` | Invalid-PID reclaim path is still a non-atomic `rm -rf`; PID `0` classified live forever |
| G30 | CA-145 | P2 | L4 | `bin/tests/_harness.sh:177-186` | `count_matches_strict` has zero callers, so the exit-2 collapse is live at ~40 sites |
| G31 | CA-147 | P2 | L4 | `bin/tests/wave7-smoke.sh:3969-3984` | No `timing.sh` measurement mode is ever executed; usage-only stub still passes |
| G32 | CA-156 | P2 | L7+L10 | `bin/_edm-lint-lib.sh:167-180` | Record shape still has 7 parsers (4 outside the library, 3 inside) |
| G33 | CA-163 | P2 | L9 | `decisions.md:29` | D19 half closed; no `decisions.md` entry names T23 or its AC13 rework |
| G34 | CA-166 | P2 | L6+L11 | `skills/code-audit/SKILL.md:127` | Closure block written into REMEDIATION.md every round still calls the `.md` authoritative |
| G35 | CA-168 | P2 | L6+L11 | `bin/edm-state:4044` | `test-coverage-audit.md` loader landed; still write-orphaned, and its header claims auto-update |
| G36 | CA-196 | P2 | L1 | `bin/tests/timing.sh:52-63` | `_p95` floors where nearest-rank ceils -- no mode reports a p95; every published budget is optimistic |
| G37 | CA-197 | P2 | L1 | `bin/tests/timing.sh:302-303` | `--mermaid-ratio` prints a raw ms count labelled as a ratio when the baseline measures 0 ms |
| G38 | CA-198 | P2 | L1 | `bin/edm-state:4537-4539` | `HANDOFF.md` written with no terminating newline (CA-027's fix, CA-133's mechanism) |
| G39 | CA-199 | P2 | L1 | `bin/edm-state:4053-4061` | `cmd_update_patterns` re-derives the plugin root from `$0`; wrong under `source` |
| G40 | CA-200 | P2 | L2 | `bin/_edm-lint-lib.sh:172-180` | `mermaid_line_set`/`marker_line_set` have zero call sites; docstring claims otherwise |
| G41 | CA-201 | P2 | L2 | `bin/edm-check-grants:103` | Two structurally unreachable guards in the two standalone checkers |
| G42 | CA-202 | P2 | L2 | `.gitlab-ci.yml:245` | Dead defensive default on an arithmetic expansion that cannot be empty |
| G43 | CA-203 | P2 | L3 | `bin/edm-state:3099-3104` | `git-lock-check` deletes `.git/index.lock` on a raced, wrong liveness oracle, no age threshold |
| G44 | CA-204 | P2 | L3 | `bin/edm-state:2525-2527` | `metrics-report` renders `nulls`/`$null` for every freshly initialized initiative |
| G45 | CA-205 | P2 | L3 | `evals/run-eval.sh:188-192` | Auth probe is the one untimed network call in a driver whose contract is per-phase timeouts |
| G46 | CA-206 | P2 | L3 | `bin/edm-state:2474,:2852` | `archive`/`migrate-path` rename the tree, live lockdir included, with no lock held |
| G47 | CA-207 | P2 | L3 | `bin/edm-state:346-351` | Token fallback caps the concatenation not each file; `CAP=0` yields a blocking ZERO_TOKENS |
| G48 | CA-208 | P2 | L3 | `bin/edm-state:2487-2495` | `watch-impl` poll swallows every git failure; a rebase silences the monitor permanently |
| G49 | CA-209 | P2 | L3 | `bin/edm-state:944-946` | Exit-code 99 collision: a locked body exiting 99 is reported as a lock timeout |
| G50 | CA-210 | P2 | L4 | `bin/tests/wave5-smoke.sh:49-50` | 20 refusal assertions in wave5/wave4a assert the message and discard the exit code |
| G51 | CA-211 | P2 | L4 | `bin/tests/wave7-smoke.sh:608-610` | CA-039 residual `-lt 100` where 0 is computable; unguarded `sed` under `set -e` at `:2287` |
| G52 | CA-212 | P2 | L5 | `bin/edm-state:984-987` | CA-141's fix created `.lockd.stale.$$` -- no gitignore match, no trap, no test, never cleaned |
| G53 | CA-213 | P2 | L5 | `bin/edm-state:944` | CA-169's one prescribed action never landed: no comment says the flock file must stay |
| G54 | CA-214 | P2 | L5 | `evals/run-eval.sh:549-572` | Retention prune never runs on the failure path, so partial runs accumulate without bound |
| G55 | CA-215 | P2 | L5+L8 | `bin/tests/wave7-smoke.sh:4659` | CA-160's security probe uses a fixed `/tmp` path, never pre-cleaned; plantable false FAIL |
| G56 | CA-216 | P2 | L5 | `bin/tests/wave6-smoke.sh:29` | Restore trap for a mutated **tracked** file omits HUP; CA-150 added it only to the cheaper site |
| G57 | CA-217 | P2 | L5 | `evals/score-artifacts.sh:513-517` | CA-151's fixture guard names one of the tree's two tracked fixture directories |
| G58 | CA-218 | P2 | L6+L11 | `docs/audit-patterns/README.md:72-75` | 3 of 4 call-site citations wrong in the document that IS the library's index |
| G59 | CA-219 | P2 | L6 | `evals/README.md:290` | Cites D26 for a closing command that lives in D28 |
| G60 | CA-220 | P2 | L6 | `.gitlab-ci.yml:57-58` | Anchor comment says "four jobs" against 7 lint jobs and 10 consumers |
| G61 | CA-221 | P2 | L6 | `CLAUDE.md:52-57` | Root registry: 4 stale plugin versions and the `bruno` plugin omitted entirely |
| G62 | CA-222 | P2 | L6 | `CLAUDE.md:19-26` | Plugin Structure diagram shows only the shape `validate:manifest` cannot see for edm |
| G63 | CA-223 | P2 | L6 | `bin/_edm-cli-lib.sh:9-13` | "ONLY place" claim contradicted by the `bin/tests` carve-out in the CI ban it cites |
| G64 | CA-224 | P2 | L6 | `plugins/edm/CLAUDE.md:650` | Hooks table states the linter's exit codes as the hook's; the hook's are the inverse |
| G65 | CA-225 | P2 | L7 | `bin/edm-check-vocabulary:2-53` | Only family member with two doc blocks; already drifted, and `--help` shows the lesser one |
| G66 | CA-226 | P2 | L7 | `evals/score-artifacts.sh:111` | Three evals drivers source the shared library two ways; the assertion was loosened to tolerate it |
| G67 | CA-227 | P2 | L7 | `.gitlab-ci.yml:232` | `lint:file-type-ban` and `test:state-validate` are the only jobs with no job-named verdict |
| G68 | CA-228 | P2 | L7 | `agents/edm-test-integration.md:21-22` | Integration declares an N/A token 3 enumerating sources say cannot exist -> layer vanishes silently |
| G69 | CA-229 | P2 | L7 | `hooks/hooks.json:32` | `edm:audit-srd` hook passes the `srd` token, so the refusal names a command the user did not run |
| G70 | CA-230 | P2 | L7 | `agents/edm-test-component.md:103` | CA-081 residual: 2 of 6 writers add words under a line claiming the strings are identical |
| G71 | CA-231 | P2 | L7 | `bin/_edm-lint-lib.sh:4-7` | Header undercounts consumers (3 vs 4) and names a variable that no longer exists |
| G72 | CA-232 | P2 | L8 | `bin/tests/_harness.sh:64` | CA-159's trap-interpolation class still live in the file all 7 suites source; exemplar cites it |
| G73 | CA-233 | P2 | L8 | `.gitlab-ci.yml:98` | CA-162's widening `bash -n`s two data files; already forced a load-bearing ordering constraint |
| G74 | CA-234 | P2 | L8 | `bin/tests/wave7-smoke.sh:4051` | Network-isolation assertion covers 9 of 11 blocking jobs |
| G75 | CA-235 | P2 | L8 | `bin/tests/wave7-smoke.sh` | CA-157's P1 injection guard has zero regression coverage, unlike both same-wave siblings |
| G76 | CA-236 | P2 | L9 | `srd.md:2853-2856` | 1 of EDMV3-54's 9 touch points anchored; D34 anchored the lens set instead; 2 criteria in tension |
| G77 | CA-237 | P2 | L9 | `tickets/epics/05:494-499` | T38 AC12 verify prints 1 not 0 -- the test's `bin/tests` carve-out was never written into the AC |
| G78 | CA-238 | P2 | L9 | `tickets/epics/05:152-156` | T35 AC4 verify returns 2 hits from the smoke file implementing it; assertion may be RED (hedged) |
| G79 | CA-239 | P2 | L9 | `tickets/epics/05:460-466` | T38 AC6 verify returns 0 because the orchestrator writes the display-cased form |
| G80 | CA-240 | P2 | L9 | `CHANGELOG.md:282-288` | T38 AC8's target is a superseded placeholder saying the mapping has not landed |
| G81 | CA-241 | P2 | L9 | `tickets/epics/03:569-574` | T23 AC13 labelled "verifiable today"; its `jq` half has no file to read |
| G82 | CA-242 | P2 | L9 | `plugins/edm/CLAUDE.md:744` | `bin/` table lists 5 of 9 shipped scripts, with no AC able to catch it |
| G83 | CA-243 | P2 | L9 | `CHANGELOG.md` | No EDMV3-T37 and no EDMV3-T39 entry, though T39 shipped two user-facing scripts and a CI job |
| G84 | CA-244 | P2 | L10 | `bin/edm-state:566-578` | Four-signal trap save/install/restore hand-repeated 6 times, all Wave 4a code |
| G85 | CA-245 | P2 | L11 | `hooks/hooks.json:117` | SubagentStop hook uses `edm-state get`, silently breaking the `qc` pattern-library append |
| G86 | CA-246 | P2 | L11 | `bin/edm-state:1398-1404` | `last_cmd`/`estimated_size` consumed, never produced; `--calibrate`'s size axis collapses |
| G87 | CA-247 | P2 | L11 | `architecture.md:631` | `git-lock-check`/`lint` dispatched but wired to nothing; E1's "live mitigation" has no trigger |

## Detailed Findings

### G1 (P0, lenses L1 + L2 + operator): Code-audit gate is unconditionally approvable at `schema_version: 1`

**Problem**: `cmd_approve_gate`'s convergence precheck at `bin/edm-state:1683-1685` runs only when the schema class resolves to `2`. The `else` arm at `:1687` records a degraded check and falls straight through to the unconditional `.code_audit_converged = true` write at `:1696-1703`. `_cmd_init_render:1483` still writes the literal `schema_version: 1`, `plugins/edm/CLAUDE.md`'s own schema contract confirms `cmd_init` never writes above `1`, nothing auto-migrates, and nothing prompts `migrate-schema` -- so for **every initiative created by the current plugin version** the precheck is environmentally unreachable and the gate is bypassable.

L1 reached this by reading control flow; L2 reached it independently as textbook environmental unreachability. CA-183's sibling fix **did** land at `:1666-1670`, and its own comment at `:1658-1665` names CA-182 as the same bypass shape -- the pair was remediated in the write-up but only one arm shipped. Live-reproduced on EDMV3 itself in round 2.

**Fix**: make the precheck unconditional and degrade only its exit-3 (no JSONL ledger) arm, so a pre-wave-B initiative still gets EDMV3-T28 AC7's tolerance without reopening the bypass:

```bash
  # The convergence precheck is NEVER skipped -- only its exit-3 (no JSONL ledger) arm degrades
  # for a pre-wave-B initiative, matching EDMV3-T28 AC7 without reopening CA-182's bypass.
  local conv_out conv_ec=0
  conv_out="$(cmd_audit_converged "$prefix" 2>&1)" || conv_ec=$?
  if [[ $conv_ec -eq 3 && "$ag_schema_class2" != "2" ]]; then
    record_degraded_check "$prefix" "approve-gate:code-audit-ledger-shape" \
      "schema_version ${ag_schema_version:-absent} < 2 and no findings-ledger.jsonl"
    echo "edm-state approve-gate: [warn] no JSONL findings ledger and schema_version ${ag_schema_version:-absent} < 2 -- convergence not computable" >&2
  else
    [[ $conv_ec -eq 0 ]] || die "code-audit gate refused for ${prefix}: ${conv_out}"
  fi
```

**Verification**: new `wave6-smoke.sh` case -- initialize at `schema_version: 1`, seed one blocking finding in `findings-ledger.jsonl`, assert `approve-gate <PFX> code-audit` exits non-zero AND that `code_audit_converged` is still unset in the state file. Add the mirror case at `schema_version: 2` proving the existing pass path is unchanged. Then re-run L1 and L2.

**Files affected**: `plugins/edm/bin/edm-state`, `plugins/edm/bin/tests/wave6-smoke.sh`

---

### G2 + G3 (P1, lenses L2 + L3, with L1 corroboration): Wave 4a's two concurrency fixes cancel each other out

**Problem** -- *the single most important finding this round; three lenses converged on it independently.*

The CA-025 remediation (subshell the mkdir-branch body) and the CA-142/CA-143 remediation (a shared cleanup list drained by the one outer trap) landed in the same wave and are **mutually incompatible**:

1. `with_state_lock` sets `_EDM_TRAP_DEPTH=1` at `:1044` and immediately forks the locked body at `:1045`.
2. `write_atomic`'s only `_edm_cleanup_push` site (`:557`) is gated on that depth, so it appends to the **subshell's** private copy of `_EDM_CLEANUP_PATHS`.
3. The only reader, `_edm_cleanup_paths_run`, runs from the four trap bodies at `:1025-1028` in the **parent**, and therefore always drains an empty list.

So the whole subsystem at `:512-537` -- roughly 25 lines plus a 9-line rationale comment at `:503-511` that states the opposite of the behaviour -- is unreachable by construction (**G2 / CA-142**). And because the nested branch deliberately installs no trap of its own, the **entire locked read-modify-write runs with zero INT/TERM/HUP coverage** on the mkdir branch -- the only branch a host without `flock(1)` takes, i.e. macOS, this project's stated primary development platform (**G3 / CA-143**). All four locked bodies reach it: `_rmw_state_body`, `_cmd_init_body`, `_cmd_update_patterns_body`, `_write_handoff_body`.

Trigger: on macOS run any state mutation and Ctrl-C during the jq render. The parent's INT trap removes the lockdir and exits 130 correctly, but `${dest}.tmp.XXXXXX` is left in the tracked initiative directory with nothing able to remove it. The flock branch never sets the depth flag, so `write_atomic` there installs real traps and does clean up -- an undocumented platform asymmetry in which the primary development platform is the unprotected one.

**Fix**: pick **one** of the two designs, not both. Preferred (option (a), smaller, keeps CA-025):

- Delete the `nested` special case and the entire `_EDM_CLEANUP_PATHS` subsystem (`:512-537`) plus the comment block at `:503-511`.
- Let `write_atomic` install its own trap layer unconditionally, including inside the subshell. A `( )` subshell **resets** inherited traps, so `write_atomic`'s layer there is depth **one**, not two -- the `bin/tests/_harness.sh:49-50` bash-3.2 depth-two constraint the comment invokes does not actually bind, and a subshell's traps cannot disarm the parent's, so CA-142's original "re-disarming the outer cleanup" concern does not arise across the fork.

Option (b) -- revert CA-025's subshelling and document the flock/mkdir divergence instead -- is acceptable but larger. Do not ship both mechanisms again.

**Verification**: a case that hides `flock` from `PATH` (forcing the mkdir branch), runs a state mutation in a child, sends SIGINT mid-write, and asserts (1) no `*.tmp.*` remains in the initiative directory, (2) the lockdir is gone, (3) the child exited 130. Run it on macOS and under `bash:3.2`. Then re-run L1, L2, L3.

**Files affected**: `plugins/edm/bin/edm-state`, `plugins/edm/bin/tests/wave7-smoke.sh`

---

### G4 (P1, lenses L1 + L3): `with_state_lock`'s mkdir branch reintroduces the `$?`-on-the-next-line defect CA-134 was filed to remove

**Problem**: at `bin/edm-state:1045-1046` the forked locked body is followed by `local ec=$?` on the **next line**, in a non-tested position under `set -e`. Four lines above, the flock branch does it correctly (`:944`, rationale at `:940-942`), and `write_atomic:581-586` -- rewritten by CA-134's remediation **this round** -- states the rule generally. The remediation applied it to `write_atomic`'s two sites and skipped the sibling function in the same file.

`with_state_lock` has bare callers today: `rmw_state:654` is `rmw_state`'s last command, and `rmw_state` is called bare from ~30 mutators. On those paths a non-zero locked body aborts the shell **at `:1045`**: `_EDM_TRAP_DEPTH` is never reset to `0`, the saved traps are never restored, and `return $ec` never runs. Worse than `write_atomic`'s version was, because what gets skipped is lock-release bookkeeping rather than a `rm -f`.

**Fix**:

```bash
    _EDM_TRAP_DEPTH=1
    local ec=0
    # CA-134/CA-184: guard the capture on the SAME statement -- see write_atomic's note at :581.
    ( "$@" ) || ec=$?
    _EDM_TRAP_DEPTH=0
```

**Verification**: force the mkdir branch by hiding `flock` from `PATH`, call `rmw_state` bare with a deliberately failing jq filter, and assert both a non-zero return **and** that `${lockbase}.lockd` is gone via the function's own release path, not merely via the EXIT trap. Fold into the same case as G2/G3.

**Files affected**: `plugins/edm/bin/edm-state`, `plugins/edm/bin/tests/wave7-smoke.sh`

---

### G5 (P1, lens L4): RE-OPENED CA-036 -- the CA-040 fix reintroduced the unguarded-command-substitution class

**Problem**: `wave6-smoke.sh:3657`, `:3670` and `:3679` each assign a command substitution and then read the exit code on the next line, under `set -euo pipefail` at `:6`. An assignment whose substitution exits non-zero is a simple command in errexit position, so **the shell exits before the capture is evaluated and the `fail` branches at `:3660`, `:3673` and `:3682` are unreachable code**. The exemption-arm regressions those three cases exist to catch end the run at `:3657` rather than producing a named failed assertion, and take the whole wave-4a remediation block below them (CA-026 at `:3753`, CA-059 at `:3808`, CA-061, ~130 further assertions) with them.

This is exactly CA-036, which round 1 raised and round 2 recorded as fixed. It came back inside the fix for CA-040. Pre-existing siblings at `wave6:3221` and `wave7:995-996`.

**Fix**: use the `|| var_ec=$?` form already used 31 lines later at `:3688`, or the `set +e` / `set -e` bracket already used at `:2767-2770` and `:3616-3619`. Then add a tripwire so the class cannot return a fourth time: assert zero matches for the assignment-then-`$?` shape across `bin/tests/*.sh`, with a synthetic positive control.

**Verification**: `bash bin/tests/wave6-smoke.sh` reaches its summary line and reports a non-zero failed count when an exemption arm is deliberately broken (rather than crashing). The new tripwire fails against its own positive control.

**Files affected**: `plugins/edm/bin/tests/wave6-smoke.sh`, `plugins/edm/bin/tests/wave7-smoke.sh`

---

### G6 (P1, lens L4): the CA-035 fix added a hard `bc` dependency no CI image installs

**Problem**: `wave7-smoke.sh:1859` is the only `bc` invocation anywhere in `plugins/edm/`. All eleven `apk add --no-cache` lines in `.gitlab-ci.yml` (`:85`, `:133`, `:152`, `:165`, `:191`, `:222`, `:268`, `:325`, `:360`, `:389`, `:438`) install only `bash`, `jq`, `git` and `shellcheck`; `bc` is a separate Alpine package, absent from the declared set for both `test:smoke` and `test:smoke-bash32`. Under `set -euo pipefail` the missing binary fails the pipeline, fails the assignment and aborts the suite at `:1859` -- roughly 2,900 lines and several hundred assertions (T43 through T67, plus the entire CA-002/CA-133/CA-134/CA-135/CA-136/CA-137/CA-144/CA-154/CA-160 remediation block) never execute. `run-all.sh:119-123` reports CRASH, so it is loud rather than silent -- hence P1 not P0 -- but the two blocking jobs whose whole purpose is running this suite can never complete it on the images they are pinned to.

**Fix**: replace the fork with in-suite arithmetic. `awk` is already a hard dependency of every suite:

```bash
t42_ac4_raw="$(grep -rhcE 'CLAUDE\.md Sec\.\\?"?Mermaid diagram conventions' "${PLUGIN_DIR}/" 2>/dev/null | awk '{s+=$1} END{print s+0}')"
```

Do **not** add `bc` to eleven `apk add` lines to serve one sum.

**Verification**: `command -v bc || bash bin/tests/wave7-smoke.sh` completes and prints its summary; add a `bin/tests` grep asserting zero `bc` invocations under `plugins/edm/`.

**Files affected**: `plugins/edm/bin/tests/wave7-smoke.sh`

---

### G7 (P1, lens L4): CA-146 was not implemented -- `run-all.sh`'s accounting has zero coverage

**Problem**: the string `CA-146` appears nowhere under `plugins/edm/`. Every structural precondition still holds: `run-all.sh` is not a `*-smoke.sh` so the discovery glob at `:29` never reaches it; `harness-smoke.sh` still has no case for it (its sections are AC1/AC3, AC2, AC4, AC5, CA-145, CA-042, AC6/AC7); and the only references anywhere are `wave7-smoke.sh:382-383` grepping its text and `:1958`/`:2324` asserting the pipeline names it. All seven branches CA-016's remediation added or rewrote are uncovered: zero assertions (`:104-107`), non-zero exit with summary (`:108-111`), failed assertions (`:112-115`), CRASH (`:119-123`), exit 0 with no summary (`:124-126`), missing preferred suite (`:67-70`), suite-count floor (`:72-75`).

This script's exit code **is** the verdict of the blocking `test:smoke` and `test:smoke-bash32` jobs. If its accounting inverts, every suite result in the pipeline becomes unreliable and nothing detects it. Escalated P2 -> P1 on that basis.

**Fix**: add a `CA-146` section to `harness-smoke.sh` that writes throwaway suite scripts into `${TMPDIR:-/tmp}` scratch and runs `run-all.sh` against a suite-directory override (refactor the aggregator to accept one if needed). One case per branch: a suite printing `Results: 0 passed, 0 failed`; a suite printing a clean summary then `exit 1`; a suite printing `Results: 3 passed, 1 failed`; a suite whose first line is `exit 1`; a suite that prints nothing and exits 0; and a discovery set of six. Each asserts the STATUS token (`PASS`/`FAIL`/`CRASH`), the `_suite_note` text, and the aggregator's own exit code.

**Verification**: `bash bin/tests/harness-smoke.sh` covers all seven branches; deliberately inverting any one branch turns a named assertion red.

**Files affected**: `plugins/edm/bin/tests/harness-smoke.sh`, possibly `plugins/edm/bin/tests/run-all.sh` (suite-directory argument)

---

### G8 (P1, lenses L1 + L3 + L8): a trailing slash or absolute `srd_root` silently disables all commit-time enforcement

**Problem** -- *three lenses found this independently; escalated to P1 because a security control fails open with no diagnostic.*

`hooks/hooks.json:86`, introduced by the CA-023 remediation, normalizes only a leading `./`:

```sh
srd_root="${EDM_SRD_ROOT:-${CLAUDE_PLUGIN_OPTION_SRD_ROOT:-./SRD}}"; srd_root="${srd_root#./}";
... awk -v root="$srd_root" '{ rl=length(root)+1; if (substr($0,1,rl)==(root "/")) { ... } }'
```

`EDM_SRD_ROOT="SRD/"` makes the awk test compare the staged path's first five characters against `SRD//`, which never matches. An absolute root never matches either, because `git diff --cached --name-only` prints repository-relative paths. Both cases leave `prefixes` empty, `test -z "$prefixes" && exit 0` fires, and **every commit passes unlinted**. Third defect on the same line: `awk -v` applies escape processing to the assignment, mangling a backslash in the path -- the POSIX-awk hazard `_harness.sh:285-290` already documents and works around via `ENVIRON[]`.

The asymmetry is what makes this a defect rather than user error: `edm-state` tolerates the same values (the filesystem collapses `SRD//`) and a direct `edm-lint-artifacts` invocation works fine, so an operator sees every manual path work while automatic enforcement silently disappears.

**Fix**: insert immediately after the existing `srd_root="${srd_root#./}"`:

```sh
while [ "${srd_root%/}" != "$srd_root" ]; do srd_root="${srd_root%/}"; done;
case "$srd_root" in
  /*) echo "[EDM] srd_root is absolute (${srd_root}); commit-time artifact lint cannot match repository-relative staged paths -- set EDM_SRD_ROOT to a repo-relative path or run edm-lint-artifacts manually" >&2; exit 0 ;;
esac;
test -n "$srd_root" || exit 0;
```

and pass the root through the environment (`root="$srd_root" awk '... ENVIRON["root"] ...'`) rather than `-v`.

**Verification**: extract the hook command from `hooks.json` and run it against a scratch repo with `EDM_SRD_ROOT=SRD/`, `EDM_SRD_ROOT=./SRD/` and an absolute value, asserting the violation is still detected (or, for the absolute case, that the diagnostic prints). The existing `wave7-smoke.sh:3370` assertion pins the literal matcher and cannot catch this.

**Files affected**: `plugins/edm/hooks/hooks.json`, `plugins/edm/bin/tests/wave7-smoke.sh`

---

### G9 (P1, lenses L1 + L6): this round's remediation inverted two `--help` statements

**Problem**: two sentences inside `bin/edm-lint-artifacts`' `EDM-HELP` sentinel block -- i.e. inside `--help`, the one operator-facing surface -- were true before this round and are false now:

- `:43-44` still says the PreToolUse hook blocks on any non-zero exit and prints one generic remediation line for both classes. CA-011's fix made it branch on `code -eq 1` vs `code -eq 2` and print **different** lines.
- `:53-55` still says the hook's staged-path matcher is the literal `^SRD/` so relocating `srd_root` drops enforcement. CA-023's fix made the hook derive the root, and `plugins/edm/CLAUDE.md:656-659` now states the opposite -- so the two documents contradict each other, and this one is the `--help` a contributor reads first.

Note the internal contradiction too: `:42` says direct callers, CI and tests can distinguish exit 1 from exit 2; the very next sentence denies it. This is CA-017's own class *reopened* by the remediation rather than closed by it. L6 rates it P1 because it is the surface that tells an operator working enforcement is broken; L1 rates it P2. Taken at the higher.

**Fix**: replace `:43-44` with the exit-1-blocks / exit-2-reports contract and distinct remediation lines; replace `:53-55` with the derived-root contract plus the repo-relative, no-trailing-slash caveat from G8. Make the same edit to `plugins/edm/CLAUDE.md`'s `bin/` table row for `edm-lint-artifacts` (which also still says "four violation classes" -- see G19).

**Verification**: `bash bin/edm-lint-artifacts --help` contains neither `blocks on any non-zero` nor the literal `^SRD/` claim; a `bin/tests` assertion pins both absences with a positive control.

**Files affected**: `plugins/edm/bin/edm-lint-artifacts`, `plugins/edm/CLAUDE.md`, `plugins/edm/bin/tests/wave7-smoke.sh`

---

### G10 (P1, lenses L1 + L3): `get_session_tokens_since` emits a third `attribution_mode` value nothing accepts

**Problem**: the CA-060 remediation replaced `jq -s` with a tolerant `reduce inputs` parse and added a `bad` counter for lines failing `fromjson?` -- then reported that counter **through** `attribution_mode` (`:341`, `:371`), a field that is a two-value enum everywhere else: `plugins/edm/CLAUDE.md:427` and `:436`, the CLAUDE.md state-field table's audit-round row, and a `wave6-smoke.sh:3427-3434` `case` that `fail`s on anything else.

Three consequences. (1) One torn line in a live-appended session JSONL -- the exact condition CA-060 was filed about, and routine when `phase-complete` runs while Claude Code is still appending -- fails the blocking `test:smoke` job. (2) The out-of-enum value is written into committed state at `:1918` and `:3391` and rendered by `metrics-report`, with no `state_anomalies` class covering it. (3) It destroys the information the field exists to carry: a reader can no longer tell whether an `unparseable` figure came from the scoped read or the whole-directory fallback, which is the only question `attribution_mode` answers.

**Fix**: keep the enum two-valued; report the parse failure in its own field. At `:341` and `:371`:

```jq
          attribution_mode: $mode,
          unparseable_lines: $acc.bad
```

Then read `unparseable_lines` alongside `attribution_mode` in `cmd_phase_complete` (`:1884-1894`) and `_cmd_audit_round_complete_body` (`:3366-3376`), pass it as `--arg ul`, and add `| . + {unparseable_lines: ($ul|tonumber)}` to both jq programs. Add a `TORN_TOKEN_LINES` **informational** anomaly in `state_anomalies` when `> 0`, and add the field to CLAUDE.md's state-field table with a C-4 "absent reads as 0" note. `wave6-smoke.sh:3427` then needs no change.

**Verification**: seed a session JSONL with one truncated line; assert `attribution_mode` is `scoped`, `unparseable_lines` is 1, `edm-state validate` reports `TORN_TOKEN_LINES` as informational (not blocking), and `wave6-smoke.sh` stays green.

**Files affected**: `plugins/edm/bin/edm-state`, `plugins/edm/CLAUDE.md`, `plugins/edm/bin/tests/wave6-smoke.sh`

---

### G11 (P1, lenses L1 + L7 + L10): the blocking linter never adopted the shared Mermaid rule, and three headers claim it did

**Problem**: `bin/edm-mermaid-rules.awk` was extracted and the eval scorer's 45-line clone is gone -- but `bin/edm-lint-artifacts:169-219` still defines its own `trim`, `strip_entities` and `is_violation` inline inside `mermaid_scan_awk`, and never loads `MERMAID_RULES_AWK` even though `_edm-lint-lib.sh:70` sets it and `edm-lint-artifacts:62` sources that file. So `mermaid_is_violation` is called from exactly one place in the tree -- `evals/score-artifacts.sh:316` -- meaning the canonical semicolon rule lives in a file consumed only by the **non-blocking nightly eval**, while the copy the blocking `lint:artifacts` job and the `PreToolUse` commit hook enforce is the private, unshared one.

Three shipped headers assert the conversion happened: `_edm-lint-lib.sh:30-32`, `edm-mermaid-rules.awk:19-26` ("All three consumers now call the same fence-recognition functions below"), and `score-artifacts.sh:92-95`. The copies are logic-identical today (compared rule by rule: the `%%` carve-out, the `classDef|style|linkStyle` carve-outs, the entity walk, the single trailing-`;` strip, the five span regexes, the sequence-message rule), so there is no live behavioural bug -- but a fix applied to the shared file changes what the eval measures and nothing about what CI enforces, and no test or CI ban guards the boundary the way CA-005's identical class got both. Escalated P2 -> P1 on three-lens corroboration and third-consecutive-round persistence in its most consequential consumer.

Second, unresolved half: `score-artifacts.sh:283-322` honours no `edm-lint-ignore` marker where `edm-lint-artifacts:233`/`:237` does, under the same header claiming both agree on "what counts as a violation."

**Fix**: convert `mermaid_scan_awk` to load the shared rules. `-f` and an inline program cannot be mixed, so the remaining program text moves into a `-f <(...)` heredoc exactly as `_edm-lint-lib.sh:74` and `score-artifacts.sh:285` already do:

```bash
  awk -f "$MERMAID_RULES_AWK" -v scan_file="$MERMAID_SCAN_FILE" -f <(cat <<'AWK_MAIN'
    { sub(/\r$/, ""); if (!(FNR in mer)) next; if (FNR in ign) next;
      if (index($0, "<!-- edm-lint-ignore -->") > 0) { print "U\t" FNR "\t"; next }
      if (mermaid_is_violation($0)) print "V\t" FNR "\t" substr($0, 1, 120) }
AWK_MAIN
  ) "$file"
```

Then delete `:169-219`, add `MERMAID_RULES_AWK` beside the source lines at `:61-62` if not already inherited, and add a CI grep banning a second copy of the entity-walk literal (mirroring `.gitlab-ci.yml:112-125`). For the ignore-marker half, either thread a marker set through `_scan_mermaid_blocks` or narrow `score-artifacts.sh:92-95` to state the carve-out and its reason.

**Verification**: assert every fixture under `bin/tests/fixtures/mermaid/` yields the identical verdict from `edm-lint-artifacts` and from the shared rule; assert `edm-lint-artifacts` contains zero local `strip_entities`/`is_violation` definitions and one `-f "$MERMAID_RULES_AWK"`; the new CI ban fails against a planted second copy.

**Files affected**: `plugins/edm/bin/edm-lint-artifacts`, `plugins/edm/bin/edm-mermaid-rules.awk`, `plugins/edm/evals/score-artifacts.sh`, `.gitlab-ci.yml`, `plugins/edm/bin/tests/wave7-smoke.sh`

---

### G12 (P1, lenses L3 + L5): the new retention prune deletes directories it does not own

**Problem**: `evals/run-eval.sh:553-571` has two distinct defects in one `rm -rf` loop.

1. **No ownership filter.** Run directories are named `${TS}_${GIT_SHA}`, but the prune applies that pattern nowhere. `--out` is a documented first-class flag whose help says only where the run is written -- so `bash run-eval.sh --out ~/eval-archive` against a directory holding twelve unrelated subdirectories silently deletes the oldest two, recursively, on the success path.
2. **Off-by-N.** `run_total` counts with `find -type d`; `stale_dirs` positions by `ls -1t`, which lists **all** non-hidden entries. Any regular file in `OUT_ROOT` consumes a protected slot and slides the `tail -n +K` window down into directories still inside the keep set. The `[ -d ] || continue` guard at `:564` prevents deleting non-directories but does nothing to correct the offset -- it makes the miscount silent rather than preventing it.

The default root holds only a hidden `.gitignore`, so today's default path is safe. But **both** documented workflows use `--out`: `evals/baseline/README.md:37` (three consecutive baseline captures) and `evals/README.md:38-41`.

**Fix**: derive the count and the window from one run-id-filtered directory listing, and require an explicit opt-in before pruning a user-supplied root:

```sh
[ "$OUT_ROOT_EXPLICIT" = "true" ] && [ "$PRUNE_OPT_IN" != "true" ] && return 0
run_dirs="$(ls -1t "$OUT_ROOT" 2>/dev/null | grep -E '^[0-9]{8}T[0-9]{6}Z_' || true)"
run_total="$(printf '%s\n' "$run_dirs" | grep -c . || true)"
stale_dirs="$(printf '%s\n' "$run_dirs" | tail -n "+$((EDM_EVAL_KEEP_RUNS + 1))")"
```

Keep the BSD/bash-3.2 constraints noted at `:557-559`. Document the retention behaviour on the `--out` help line.

**Verification**: scratch root with 12 run-shaped directories plus 3 stray files and 2 unrelated directories; assert exactly the oldest 2 *run-shaped* directories are removed, the strays and unrelated directories survive, and that `--out` without the opt-in prunes nothing.

**Files affected**: `plugins/edm/evals/run-eval.sh`, `plugins/edm/evals/README.md`, `plugins/edm/bin/tests/wave7-smoke.sh`

---

### G13 (P1, lens L11): CA-164's fix made the lens JSONL schema resolvable only by reference, and the reference was empty

**Problem**: `skills/code-audit/SKILL.md:207-213` names two output artifacts but replaced the inline JSONL schema with a **pointer** ("emit the schema documented in your own agent definition's `## JSONL Line Format` section"). This round the pointer had nothing to resolve against: the delivered prompts named one output path, carried no JSONL bullet and no schema pointer, and the delivered agent definitions had no such section (CA-130's stale plugin cache).

Consequence, first-hand: **zero `lens-L*.jsonl` files exist for pass-3**, so the synthesizer's instruction at `:232` to read prose *and* JSONL degrades to prose only -- exactly the CA-020 break the JSONL contract was created to close -- and `evals/score-artifacts.sh:414-417` skips dimension 5 entirely, reporting `null` rather than a failure, so the one metric that would have detected the loss is silent. Before CA-164 a lens carried a *wrong* schema; after CA-164 a lens whose delivered definition lacks the section carries *none*. NOTED CA-128 already records the argument against precisely this trade.

**Fix**: two repository-side changes, both actionable independently of the host artifact:

1. Restore the one-line literal schema **alongside** the pointer in the launch template (cost: one line; benefit: the pointer stops being a single point of failure).
2. Land CA-176's step-8 precondition: refuse to spawn `edm-audit-synthesizer` until one `lens-L{N}.jsonl` exists for every member of `LENS_SET`, and state the orchestrator-persists-both-halves fallback explicitly so a lens without `Write` still yields both artifacts.

**Verification**: `bash bin/edm-check-grants` stays clean; assert `skills/code-audit/SKILL.md` contains both the literal `id` / `lens` / `file` / `line` schema tokens and the by-name pointer; assert the step-8 precondition text exists. Next round: confirm 11 `.jsonl` files are present and dimension 5 scores a number.

**Files affected**: `plugins/edm/skills/code-audit/SKILL.md`, `plugins/edm/bin/tests/wave7-smoke.sh`

---

### G14 (P1, lens L11): CA-098's legacy-flat-path break survives at 17 sites, including 4 agent launch templates

**Problem**: CA-098 was fixed at one site (`skills/code-audit/SKILL.md:44-51` resolves `INIT_DIR` and interpolates it at `:206`). Everywhere else the break is unfixed. Seven skills contain zero occurrences of `resolve-dir` or `INIT_DIR` and hand out literal flat paths: `test-plan:27-29,62-64,71-73`; `test-coverage:28,56-58,63-65`; `test:26,161-162`; `push-jira:21,39,141`; `tickets:15-16,116-117`; `audit-srd:15-16,40,121`; `audit-tickets:15,42,128-129,135-136`. Four of those are **agent launch templates** (`tickets:116-117` to `edm-ticket-writer`, `audit-srd:121` to `edm-srd-auditor`, `audit-tickets:128-129` and `:135-136` to `edm-ticket-auditor`). Ten agents reconstruct the same path: `edm-test-coverage-auditor`, `edm-test-planner`, and all eight test writers.

Live-falsified against this tree: the only initiative is the product-scoped `SRD/edm/EDMV3__prompt-streamline/`, so `/edm:test-plan EDMV3` checks `SRD/EDMV3/`, finds nothing, and prints "No initiative directory at SRD/EDMV3/. Run /edm:plan EDMV3 first." -- a false refusal on the canonical layout, on the initiative that is auditing itself. And `tickets/SKILL.md:116-117` hands `edm-ticket-writer` a flat path while `edm-ticket-writer.md:18` opens by resolving the directory itself: the identical skill-versus-agent disagreement CA-098 named.

**Fix**: mechanical sweep. Each skill adds the two-line preamble `code-audit/SKILL.md:44-51` already models and interpolates `${INIT_DIR}` at every literal; each agent's Inputs block takes `${INIT_DIR}` from its launcher rather than reconstructing it. `agents/edm-qc-auditor.md:77` needs the same change for a different reason -- it reaches for `edm-state get`, which prints state JSON, not a resolved path.

**Verification**: `grep -rl 'srd_root}/{PREFIX}' plugins/edm/skills plugins/edm/agents` returns zero; run `/edm:test-plan EDMV3` (or its step-1.2 path check in a scratch harness) against the product-scoped layout and assert it resolves. Add a `bin/tests` assertion that every skill mentioning an initiative artifact also mentions `resolve-dir`.

**Files affected**: 7 `skills/*/SKILL.md`, 11 `agents/*.md`, `plugins/edm/bin/tests/wave7-smoke.sh`

---

### G15 (P1, lens L11): `current_step` has three consumers and no producer

**Problem**: consumers exist and are load-bearing -- `bin/edm-state:3168`/`:3174` print `Step:` from `session-start` (the SessionStart hook), `:4390`/`:4456` render `- **Step**:` into HANDOFF.md, and `skills/orchestrator/SKILL.md:90-95` reads it on the Resume branch while `:177-181` defines its entire vocabulary (a bare phase number, plus a legacy-value warning branch). Nothing writes it: the only writer is `cmd_current_step`'s write mode (`:3128-3132`), `current_step` is deliberately absent from `SETTABLE_KEYS` (`:1405`) so `edm-state set` cannot write it either, and a tree-wide grep for `current-step` across `skills/`, `agents/`, `hooks/` and `monitors/` returns zero invocations -- the only callers are `wave3-smoke.sh:47` and `:52`.

The instruction that wrote it did not survive the T37/T38 orchestrator restructure; `SRD/.archived/EDMV2/qc/EDMV2-wave3.md:76` quotes it verbatim from the pre-refactor orchestrator. Live evidence: this initiative's own state file carries `"current_step": "6.code-audit-round-1-non-convergent"` at `.edm-state.json:203` -- a *legacy*-shape value, which is itself the proof, because no shipped instruction produces a value in either shape. On an initiative driven purely by the plugin's instructions the field stays absent, both renderer lines are suppressed forever, and resume silently degrades to `current_phase` granularity. `wave7-smoke.sh:2921` exercises the subcommand directly, so it proves the mechanism works and cannot see that nothing calls it.

**Fix**: add `edm-state current-step <PREFIX> <phase-num>` to each phase skill's Step 0 preflight (preferred -- it fires whether or not the run came through the dispatcher), or to `skills/orchestrator/SKILL.md` Step 2 immediately before each dispatch.

**Verification**: run a phase skill's Step 0 in a scratch initiative and assert `current_step` is written in the bare-phase-number shape; assert `session-start` prints the `Step:` line and HANDOFF.md carries the `- **Step**:` row.

**Files affected**: 8 `skills/*/SKILL.md` (or `skills/orchestrator/SKILL.md`), `plugins/edm/bin/tests/wave7-smoke.sh`

---

### G16 (P1, lens L9): T37 AC6's verify sums to 7, not 8, and the shipped test implements a different contract

**Problem**: `tickets/epics/05:358-361` requires `phase-start`/`phase-complete` calls exactly once per phase and states its verify as `grep -rc 'phase-start' plugins/edm/skills/*/SKILL.md` summing to **8**. It sums to **7**, and the distribution is per-*phase*, not per-*skill*: `code-audit` and `verify-runtime` carry no `phase-start` at all; `tickets` carries two (`:33` and `:145`, the fast-track mode-branch duplicate). The shipped smoke case at `wave7-smoke.sh:2830-2843` implements a materially different contract -- one owning *file* per phase, with `phase-complete 6` expected in **three** files -- and records the exceptions only inside its own echo string. The AC's cited case name is not the shipped label. No `decisions.md` entry records a T37 AC6 rework.

**Fix**: amend AC6 to the shipped per-phase contract, adding the "Note -- why the obvious command does not work" block the pack already uses for the same three-file split at `epics/08:72-87` (T50 AC4), and record the rework in `decisions.md` naming T37 AC6 with before/after text.

**Verification**: the amended verify command runs and returns the stated value on the live tree; `decisions.md` contains a T37 AC6 entry.

**Files affected**: `SRD/edm/EDMV3__prompt-streamline/tickets/epics/05-orchestrator-dispatcher.md`, `SRD/edm/EDMV3__prompt-streamline/decisions.md`

---

### G17 (P1, lens L9): T39 AC5's verify phrase exists nowhere, and the required re-verification was never recorded

**Problem**: `tickets/epics/05:593-599` requires the driver's stop-before-gate instruction to be re-verified against the wave-B PROTOCOL wording and verifies with `grep -n 'stop before gate presentation' plugins/edm/evals/run-eval.sh`. That phrase appears **nowhere** in the file -- a case-insensitive search for `stop.{0,20}gate`, `gate presentation`, `STOP_BEFORE` and `stop-before` returns zero hits. The substance exists at `:350-352` and `:415-417` under a third wording, and the final PROTOCOL at `orchestrator/SKILL.md:130` uses a fourth. And no record of the re-verification exists: `CHANGELOG.md` has no `EDMV3-T39` entry at all, and `decisions.md` D23 enumerates AC2/AC3/AC4/AC7 but never AC5. Both halves of the verify fail.

**Fix**: pick one wording as canonical. Either align `run-eval.sh`'s prompt text with the shipped PROTOCOL terminology, or amend AC5 to the wording that shipped. Either way, record the re-verification result in `decisions.md` and add the missing `EDMV3-T39` CHANGELOG entry (see also G83).

**Verification**: the amended verify command returns a hit; `decisions.md` and `CHANGELOG.md` each name T39 AC5.

**Files affected**: `SRD/.../tickets/epics/05-orchestrator-dispatcher.md`, `SRD/.../decisions.md`, `plugins/edm/CHANGELOG.md`, possibly `plugins/edm/evals/run-eval.sh`

---

### G18 (P1, lens L9): T39 AC9's plotting script does not exist and is described nowhere

**Problem**: `tickets/epics/05:622-625` verifies that "the plotting script described in `evals/README.md` runs against them." The naming-convention half is implemented and documented (`evals/README.md:33`), but a case-insensitive search for `plot` across all of `plugins/edm/` returns **zero** matches -- so `evals/README.md` describes no such script, no ticket names one, and `evals/runs/` holds no committed run directories, making even the first half of the verify unrunnable in a clean checkout. The clause originates at `epics/03:559-564` (T23 AC11), which asks only that artifacts be *named or tagged so* a script could be written; T39 AC9 escalated that into a requirement without adding the work.

**Fix**: either build the script (a ~20-line `jq` + column formatter over `evals/runs/*/scores.json`) and document it in `evals/README.md`, or amend AC9 back to T23 AC11's naming-convention wording with a change-control record in `decisions.md`.

**Verification**: if built -- the script runs against two synthetic run directories and prints a total-score series; if amended -- `decisions.md` records the rework and the amended verify passes.

**Files affected**: `SRD/.../tickets/epics/05-orchestrator-dispatcher.md`, `SRD/.../decisions.md`, optionally `plugins/edm/evals/` + `plugins/edm/evals/README.md`

---

## P2 Findings (G19-G87)

All 69 are in the blocking set. Each carries a concrete fix in its ledger entry (`findings-ledger.jsonl`, keyed by CA-NNN) with the full derivation in the named lens report. Grouped below by remediation locality so they can be batched into independent commits.

### Group A -- `bin/edm-state` correctness and concurrency residue (7)

| # | ID | Site | Concrete fix |
|---|---|---|---|
| G22 | CA-061 | `:1356-1360` | Capture `mkdir`'s stderr on first failure; `die` naming the real errno when the message is not `File exists` instead of entering the 50-try loop. Make `record_degraded_check` warn-and-skip when the state directory is unwritable so `gate-check` honours its documented read-only contract. |
| G29 | CA-141 | `:967-977` | Route the invalid-PID case through the same `mv`-aside-then-remove helper the dead-PID case uses; reject `0` alongside non-numeric PIDs; add `sleep 0.1` before `continue`. |
| G44 | CA-204 | `:2525-2527`, `:2537-2538`, `:2619-2621`, `:2643-2644` | Change every `| add)` to `| add // 0)` -- the house pattern already used at `:335-339` and `:365-369`. |
| G46 | CA-206 | `:2474`, `:2852` | Take `with_state_lock "${src_state_file%.json}"` around the check-and-move in `archive` and `migrate-path`; `rm -rf` the lockdir immediately before the rename rather than letting it travel. Fix the rollback's premature `.bak` delete at `:2862`. |
| G47 | CA-207 | `:346-351`, `:312-318` | Loop the session files and `tail -n "$cap"` each one; tighten the cap validator to `^[1-9][0-9]*$` with a message naming the `ZERO_TOKENS` consequence. |
| G48 | CA-208 | `:2487-2495` | Capture the `git log` status; verify `last_sha` with `git cat-file -e`; re-anchor to `HEAD` with one diagnostic line when history was rewritten; advance `last_sha` on every successful poll. |
| G49 | CA-209 | `:944-946` | Replace the `99` timeout sentinel with a distinct out-of-band value and assert no locked body returns it, or detect the timeout by testing for the lock rather than by exit code. |

### Group B -- `bin/edm-state` hygiene, DRY and dead code (5)

| # | ID | Site | Concrete fix |
|---|---|---|---|
| G38 | CA-198 | `:4537-4539` | Add a newline-terminating `_print_line` beside `_print_literal` and use it for HANDOFF.md. Do **not** change `_print_literal` -- the pattern splice at `:3988` depends on its no-newline behaviour. Regenerate committed copies. |
| G39 | CA-199 | `:4053-4061` | Delete the `$0`-derived block; use the existing `BASH_SOURCE`-derived `SCRIPT_DIR` global from `:62`. |
| G43 | CA-203 | `:3099-3104` | Require an mtime age threshold; scope liveness to this repo (`lsof` or `pgrep -f` against `$git_dir`); remove via `mv`-aside; print age and holder evidence before acting. |
| G52 | CA-212 | `:984-987` + `.gitignore` | Widen `**/.edm-state.lockd/` to `**/.edm-state.lockd*` and `docs/audit-patterns/*.lockd` to `*.lockd*`; add the derived `.stale.$$` name to the CA-148 enumeration at `wave7-smoke.sh:4870-4874` using the source's own formula. |
| G53 | CA-213 | `:944` | One comment above the `flock` call: the file is deliberately never unlinked because `flock` exclusion is inode-keyed; `.gitignore:18` hides it; do not add `rm -f` (ledger CA-169). |
| G84 | CA-244 | `:566-578` etc. | Add `_save_traps` / `_restore_traps` to collapse six 4-line blocks into six 1-line calls, and `_write_atomic_unwind <nested> <tmp>` for the three near-identical unwinds. |

### Group C -- shared libraries and checkers (7)

| # | ID | Site | Concrete fix |
|---|---|---|---|
| G19 | CA-017 | `edm-lint-artifacts:24-37`, `CLAUDE.md:744` | Add an `unreadable` row to the help block's class list; change the CLAUDE.md `bin/` row to six documented classes (or point at `--help`). Fold into G9's edit. |
| G24 | CA-074 | `edm-sync-canonical-sections:47` | Give `die()` the two-argument `local msg/code` form its siblings use; copy `edm-validate-prefix:22-25`'s comment. |
| G32 | CA-156 | `_edm-lint-lib.sh:167-180` | Add `project_class <class>` reading the table on stdin; pipe the three library projections through it and have `edm-lint-artifacts:295-298` call it four times against `$_table`. Zero extra `awk` invocations. |
| G40 | CA-200 | `_edm-lint-lib.sh:172-180` | Delete `mermaid_line_set` and `marker_line_set`, or replace the `:38-45` docstring claim with the real position (`ignored_line_set` is shared; the other two are deliberately not offered because of the latency budget). |
| G41 | CA-201 | `edm-check-grants:103`, `edm-check-vocabulary:191-194` | Delete both unreachable guards. One commit. |
| G63 | CA-223 | `_edm-cli-lib.sh:9-13` | One clause: "the only place outside `bin/tests/`, which is exempted because the smoke suite must carry the literal to assert on it." |
| G65 | CA-225 | `edm-check-vocabulary:2-53` | Move `EDM-HELP-BEGIN` to `:1` and `EDM-HELP-END` above `set -euo pipefail`; delete the `:74-82` block. |
| G71 | CA-231 | `_edm-lint-lib.sh:4-7` | "four consumers"; add `bin/edm-state`; change `SELF_DIR` to `SCRIPT_DIR`. |

### Group D -- test-suite quality (8)

| # | ID | Site | Concrete fix |
|---|---|---|---|
| G20 | CA-037 | 6 named sites | Convert to `assert_absent_with_control`, using adjacent live text as the control haystack where one exists. |
| G21 | CA-049 | `_harness.sh:41-66` | Either migrate `wave3`/`wave4a`/`wave5` to `harness_scratch_dir TMP` and the five inline root derivations to the `_HARNESS_*` exports (reordering `wave4b:7` and `wave7:12`), or delete all three symbols and correct both docstrings plus `_harness.sh:5`. Do not leave the current state. |
| G26 | CA-094 | `wave7:3041,3773,3816,3874,3961,4198` | Replace the six live `edm-check-grants` runs with guarded `WAVE7_GRANTS_EXIT` reads; delete the six now-dead `*_exit` vars; add the missing freshness calls; correct `:3703-3706`. |
| G27 | CA-101 | `fixtures/mermaid/valid` | Add one valid fixture with a `(...)` and a `{...}` label each carrying an entity plus a terminator outside the label; add to the CLEAN assertion at `wave7:2279-2280`. |
| G28 | CA-138 | `tiering-matrix.sh:308-315` | Increment `assertions_run` beside each of the six blocks; print `${failures}/${assertions_run}`; change `wave7:4188` to extract the denominator and assert `>= 6`. |
| G30 | CA-145 | `_harness.sh:177-186` | Convert the G20 expect-zero sites to `count_matches_strict` and assert its exit status, not only its printed value. |
| G31 | CA-147 | `wave7:3969-3984` | Generate a 1-initiative fixture, run `--subcommands` once, assert a positive integer millisecond figure and a zero exit. Also catches a perl-less abort. |
| G50 | CA-210 | `wave5`/`wave4a`, 20 sites | Mechanical substitution to `check_fails`; `check_refuses_and_leaves_state` for the five state-mutating cases. |
| G51 | CA-211 | `wave7:608-610`, `:2287` | Assert `== 0` with the derivation in a comment; move the `expected=` extraction inside the existing `set +e` bracket and `fail` with the fixture name when empty. |
| G75 | CA-235 | `wave7-smoke.sh` | Two `check_fails` cases against `phase-start` and `phase-complete` asserting `phase-num must be 1-6`, plus a proof-file assertion, mirroring the CA-160 shape with the suite's own `$TMP`. |

### Group E -- runtime hygiene (4)

| # | ID | Site | Concrete fix |
|---|---|---|---|
| G54 | CA-214 | `run-eval.sh:549-572` | Extract `prune_old_runs()` and call it from `cleanup()` as well as the success path; amend `evals/README.md:43-49`. |
| G55 | CA-215 | `wave7:4659` | `ca160_proof="${TMP}/edm-ca160-proof"`; `rm -f` before the probe; interpolate into the payload. |
| G56 | CA-216 | `wave6:29` | Add `HUP` to `trap cleanup_wave6`. |
| G57 | CA-217 | `score-artifacts.sh:513-517` | Widen the `case` to `*/fixtures/*` and `*/fixtures`; update the `--out` help note at `:16-20`. |
| G72 | CA-232 | `_harness.sh:64` | Use the deferred form with a dedicated variable; correct `edm-state:563-564`'s three exemplar citations to `:130`, `:121`, `:92`. |

### Group F -- CI pipeline (5)

| # | ID | Site | Concrete fix |
|---|---|---|---|
| G42 | CA-202 | `.gitlab-ci.yml:245` | Delete the dead `${evals_kb:-0}` default. |
| G60 | CA-220 | `:57-58` | "seven lint jobs plus three non-lint consumers", or drop the count. |
| G67 | CA-227 | `:232`, `:423`/`:426` | One terminal `lint:file-type-ban: OK -- ...` line carrying the size figure; `test:state-validate: OK`. |
| G73 | CA-233 | `:98`, `:198` | Give both loops `case "$f" in *.awk|*.txt) continue ;; esac`; delete the ordering constraint from `bin/vocabulary-allowlist.txt:41-44`. |
| G74 | CA-234 | `wave7:4051` | Add `lint:file-type-ban` and `lint:pattern-library-contract`; better, derive the blocking set from the pipeline file and keep the missing-job failure as the guard on that derivation. |

### Group G -- documentation accuracy (8)

| # | ID | Site | Concrete fix |
|---|---|---|---|
| G58 | CA-218 | `docs/audit-patterns/README.md:72-75` | Replace the three line citations with the by-name step form (e.g. `skills/code-audit/SKILL.md` step 9a). |
| G59 | CA-219 | `evals/README.md:290` | D26 -> D28. |
| G61 | CA-221 | root `CLAUDE.md:52-57` | Refresh git 1.1.0, jira 1.1.0, ada-tablo 1.2.0, web-cms 1.0.19; add a `bruno` 1.1.0 row. |
| G62 | CA-222 | root `CLAUDE.md:19-26` | Show both agent layouts; note that `validate:manifest` enforces the flat form for edm. |
| G64 | CA-224 | `plugins/edm/CLAUDE.md:650` | "`edm-lint-artifacts` exit 1 -> the hook exits **2**, the PreToolUse blocking code; exit 2 -> the hook exits 0 and does not block." |
| G66 | CA-226 | `evals/*.sh` | Settle on `"${SCRIPT_DIR}/../bin/_edm-cli-lib.sh"` (2 of 3 already); tighten `wave7:4818` to the literal form `:4812` uses. |
| G70 | CA-230 | `edm-test-component.md:103`, `edm-test-composable.md:123` | Drop ` in scope` from both. |
| G82 | CA-242 | `plugins/edm/CLAUDE.md:744` | Add rows for `edm-check-grants`, `edm-check-vocabulary`, `edm-compare-eval`, `edm-check-skill-sync`; extend T66 AC3/AC4 to cover the script list. |

### Group H -- integration wiring and prompt-surface (6)

| # | ID | Site | Concrete fix |
|---|---|---|---|
| G34 | CA-166 | `code-audit/SKILL.md:127`, `CLAUDE.md:840`, `:108`, `README.md:192` | Name the `.jsonl` authoritative in the closure template; change `CLAUDE.md:840`'s parenthetical to "(rendered by `edm-state render-ledger` from the authoritative `findings-ledger.jsonl`, which `edm-audit-synthesizer` writes)"; add the `.jsonl` to both layout blocks. |
| G35 | CA-168 | `edm-state:4044-4069` + README | Add a fifth `test-coverage` audit type mapping to `test-coverage-audit.md` with report path `${_dir}/test-coverage.md`, invoked from `skills/test-coverage` and `skills/test`; add the three `README.md` rows. Or delete the "Auto-updated" claim at `test-coverage-audit.md:4` and record seed-only status. |
| G68 | CA-228 | `edm-test-integration.md` / `edm-test-planner.md:78-82` | Pick one: add the integration N/A rule to the planner and both enumerations, or delete the carve-out from `:21-22`, `:96-98`, `:104-107`. |
| G69 | CA-229 | `hooks/hooks.json:32` | Pass `audit-srd` instead of `srd`. |
| G85 | CA-245 | `hooks/hooks.json:117` | Name `edm-state resolve-dir` in step 4, matching `:86`. |
| G86 | CA-246 | `edm-state:1398-1404` | Have `skills/plan/SKILL.md` record `estimated_size` at Gate 1; decide `last_cmd`'s direction (add the orchestrator instruction or drop the two unreachable renderer lines and the key); correct the `last_decision` attribution to `skills/srd/SKILL.md`. |
| G87 | CA-247 | `architecture.md:631` | Add the sanctioned `PreToolUse` git matcher, or amend `:631` to state E1's mitigation is operator-invoked and correct the citation to `:3082-3111`. For `cmd_lint`, route the commit hook through it or drop the wrapper and its `CLAUDE.md:741` entry. |

### Group I -- spec and ticket-pack compliance (9)

| # | ID | Site | Concrete fix |
|---|---|---|---|
| G23 | CA-064 | `score-artifacts.sh:534-539` | `complete="false"` in the absent-`run.json` branch, with a `complete_reason` field naming the cause. |
| G25 | CA-089 | `architecture.md:647`, `:873`, `edm-check-skill-sync:3,10-13` | Rewrite both architecture passages to the shipped inverted assertion and unconditional retention; retitle the script header and drop the superseded AC7-requires-a-fallback reason. |
| G33 | CA-163 | `decisions.md` | Add a decision entry naming T23 and its AC13 rework with before/after text. |
| G36 | CA-196 | `timing.sh:52-63` | `idx = int(0.95*NR); if (idx < 0.95*NR) idx = idx + 1`; raise sample counts to 20 (or rename the key to `max_ms`); re-run every mode and re-record the figures in CHANGELOG.md and CLAUDE.md. |
| G37 | CA-197 | `timing.sh:302-303` | Refuse with `ratio=UNMEASURABLE` and exit 3 when either p95 is `<= 0`. |
| G76 | CA-236 | `srd.md:2819-2856` | Either sweep EDMV3-54's nine touch points (D34's named EDMV4-T04 scope) or narrow the CLAUDE.md claim to the lens set; reconcile the two adjacent criteria. |
| G77 | CA-237 | `epics/05:494-499` | Write the `bin/tests` carve-out into the AC text, following `epics/02:553-556`. |
| G78 | CA-238 | `epics/05:152-156` | Add the `bin/tests` carve-out to both the AC and the shipped grep, or assemble the needle from parts so the assertion cannot self-match. **L4 must confirm whether `wave7:2586` is currently red.** |
| G79 | CA-239 | `epics/05:460-466` | Make the verify case-insensitive or name the display form `mini-SRD`. |
| G80 | CA-240 | `CHANGELOG.md:282-288` | Replace the superseded placeholder with the published `current_step` mapping (also discharges `orchestrator/SKILL.md:180-181`). |
| G81 | CA-241 | `epics/03:569-574` | Capture the baseline via D23's closing command, or re-label AC13 as blocked-on-D23 and record the rework. |
| G83 | CA-243 | `CHANGELOG.md` | Add an `EDMV3-T39` entry naming `edm-compare-eval`, `edm-check-skill-sync` and the CI job; add a T37 entry or record in `decisions.md` that T38's covers the pair. |

---

## Decisions / Non-Findings

These items were flagged this round and determined **Not Actionable**. They are recorded as `NOTED` in the ledger (`sev: NOTED`, excluded from the blocking set). Future audits should **not** re-investigate them.

**New this round (3):**

1. **L2 flagged `run-all.sh:71-75`'s `_MIN_SUITE_COUNT` floor as unreachable** (CA-248, L2+L4) -- L4 disproved it: dropping a name from `_PREFERRED_ORDER` *and* deleting that suite defeats the name loop but not the floor. Guards are complementary.
2. **L7 flagged `edm-state:4599`'s `print_help "$0"` as the only non-conforming call site** (CA-249, L6+L7+L10) -- inside the direct-execution dispatch guard at `:4554`, so `$0` and `BASH_SOURCE[0]` are equal by construction. L6 and L10 both ruled it correct in place.
3. **Three lenses noted a vestigial `srand()` at `timing.sh:39`** (CA-250, L1+L6+L8) -- CA-158's fix removed the `rand()` term; only `systime()` is printed, so the seeding has no effect on any emitted value.

**Updated this round (1) -- important operational finding, not a code defect:**

4. **CA-130 reproduced a fourth consecutive round, now with much stronger evidence.** `Write` was absent from **every** lens's delivered runtime tool set despite the frontmatter grant (L2, L6, L7, L10 and L11 each reported it independently; L10 enumerated the delivered set as `Read, Grep, Glob, WebFetch, WebSearch, TaskStop`), so all eleven prose reports and all eleven JSONL files required orchestrator transcription. **New: the agent definitions delivered as system prompts are demonstrably an older revision than the on-disk files** -- the delivered `edm-audit-wiring` definition carried no `## Scope`, no `## Output` and no `## JSONL Line Format` section, and used the pre-CA-165 Output Format table, while the on-disk file has all of them at `:78-86`, `:95-97`, `:114-139`. This is the **stale plugin cache** behaviour this repository's `MEMORY.md` already records for bare `edm-*` command resolution, now confirmed for agent definitions. Host/environment artifact, not a repository defect -- but it is why zero JSONL exists this round, and the operational mitigation is to run the audit from an explicitly path-resolved plugin directory (or refresh the plugin cache) before treating any lens's self-reported contract as authoritative. The repository-side hardening that makes a round robust to it is **G13 (CA-193)**.

**Carried from prior rounds (40):** the ledger's own "Decisions / Non-Findings" section (CA-105 through CA-132, CA-169 through CA-181) was re-verified by the owning lenses at current line numbers this round and none was re-opened. Do not re-investigate.

---

## Rollout Order

**A Wave 7 is required.** Three of this round's P1 findings and roughly eighteen P2s were *introduced by Waves 3-6b themselves*, which is the defining characteristic of this round: the remediation velocity is high, but the "fixed one site, missed the mirror" and "shipped the mechanism inert" patterns are recurring. Wave 7 must therefore be sequenced so the re-fixes land **before** any further breadth work, and every re-fix must carry the regression test the original fix omitted.

### Wave 7a -- concurrency re-fix in `bin/edm-state` (G2, G3, G4, G29, G52, G53) -- **must land first, single-threaded**

CA-142, CA-143, CA-184, CA-141, CA-212, CA-213. These all touch `with_state_lock` / `write_atomic` / the lock-reclaim path and **must not be parallelized** -- the round-3 defect is precisely that two independently-correct fixes to this region were composed without checking their interaction. Pick one trap design (option (a) in G2), delete the inert mechanism and its comment, fix the `$?` capture, make the invalid-PID reclaim atomic, widen the `.gitignore` lock globs, and add the CA-169 guard comment. Gate on the new SIGINT-during-locked-write test passing on **both** macOS (mkdir branch) and `bash:3.2` (flock branch).

### Wave 7b -- P0 gate bypass + test-suite executability (G1, G5, G6, G7) -- parallel with 7a

CA-182, CA-036, CA-189, CA-146. Independent files. G6 (`bc`) and G5 (unguarded substitution) are prerequisites for trusting *any* subsequent suite run, so they should land in the same commit as the P0 fix. G7 adds the `harness-smoke.sh` coverage that makes the blocking CI verdict trustworthy.

### Wave 7c -- fail-open and doc-inversion fixes (G8, G9, G10, G19, G64) -- parallel

CA-186, CA-187, CA-185, CA-017, CA-224. The hook `srd_root` normalization, the two inverted `--help` passages, the `attribution_mode` enum, the class-count undercount and the hooks-table exit codes. These form one coherent "what the hook actually does, stated correctly in all four places" commit.

### Wave 7d -- shared-mechanism completion (G11, G21, G26, G30, G32, G40, G84) -- parallel

CA-019, CA-049, CA-094, CA-145, CA-156, CA-200, CA-244. Every one of these is "the extraction landed but the consumers did not." Batch them so the shared-library boundary is settled in one pass, and add the CI ban / smoke assertion for each so a fourth round cannot find them again.

### Wave 7e -- prompt-surface wiring (G13, G14, G15, G34, G35, G68, G69, G85, G86) -- parallel, prose-only

CA-193, CA-195, CA-194, CA-166, CA-168, CA-228, CA-229, CA-245, CA-246. All `skills/`, `agents/`, `hooks/` and `CLAUDE.md` edits, no executable change except G35's fifth `update-patterns` arm. G13 and G14 are the highest-value: G13 makes the next round's JSONL half robust to the stale cache, G14 unbreaks 17 live call paths.

### Wave 7f -- spec and ticket-pack change control (G16, G17, G18, G25, G33, G76, G77, G78, G79, G80, G81, G82, G83) -- parallel, batched

CA-190, CA-191, CA-192, CA-089, CA-163, CA-236, CA-237, CA-238, CA-239, CA-240, CA-241, CA-242, CA-243. Thirteen AC-text, `decisions.md`, `architecture.md` and `CHANGELOG.md` corrections. One commit per document. **G78 must be confirmed against a live suite run first** -- if `wave7:2586` is currently red, it is a Wave 7b item, not a 7f item.

### Wave 7g -- remaining P2s (all other G-numbers) -- deferrable within the wave

Groups A (remainder), E, F, G. Low-risk, mechanical, independent. If Wave 7 must be cut for time, this is the batch to defer -- but note that **deferring does not unblock convergence**, because `BLOCKING_FILTER` includes P2. Anything deferred must instead be explicitly demoted to `NOTED` with a documented rationale, which is a gate decision, not a synthesizer decision.

---

## Verification Plan

**Syntax and lint (all must be clean):**

```bash
for f in plugins/edm/bin/*; do case "$f" in *.awk|*.txt) continue ;; esac; bash -n "$f" || echo "FAIL $f"; done
for f in plugins/edm/bin/tests/*.sh plugins/edm/evals/*.sh; do bash -n "$f" || echo "FAIL $f"; done
shellcheck --include=SC2086,SC2046,SC2048,SC2068 plugins/edm/bin/* plugins/edm/bin/tests/*.sh plugins/edm/evals/*.sh
bash plugins/edm/bin/edm-lint-artifacts --all
bash plugins/edm/bin/edm-check-grants
bash plugins/edm/bin/edm-check-vocabulary
bash plugins/edm/bin/edm-check-skill-sync
bash plugins/edm/bin/edm-sync-canonical-sections --check
jq -e . SRD/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl >/dev/null
```

**Test suites:**

```bash
bash plugins/edm/bin/tests/run-all.sh          # must reach its summary; no CRASH rows
bash plugins/edm/bin/tests/harness-smoke.sh    # must now include the CA-146 section (G7)
```

Confirm `run-all.sh` reports a non-zero failed count (not a crash) when an exemption arm is deliberately broken -- that is the G5 acceptance signal. Confirm `wave7-smoke.sh` completes on a host without `bc` -- that is the G6 signal.

**Integration / manual smoke:**

1. **G1**: scratch initiative at `schema_version: 1` with one blocking finding -> `edm-state approve-gate <PFX> code-audit` must exit non-zero and leave `code_audit_converged` unset.
2. **G2/G3/G4**: on macOS (no `flock`), start a state mutation and send SIGINT mid-write -> no `*.tmp.*` in the initiative directory, no lockdir, child exits 130. Repeat under `bash:3.2`.
3. **G8**: run the extracted hook command against a scratch repo with `EDM_SRD_ROOT=SRD/`, `./SRD/`, and an absolute path -> violation still detected (or diagnostic printed).
4. **G12**: `--out` scratch root with 12 run-shaped directories + 3 stray files + 2 unrelated directories -> only the oldest 2 run-shaped directories pruned, and nothing pruned without the opt-in.
5. **G14**: `/edm:test-plan EDMV3` (or its step-1.2 path check) must resolve the product-scoped layout instead of refusing.
6. **G15**: run a phase skill's Step 0 -> `current_step` written; `session-start` prints `Step:`; HANDOFF.md carries the row.

**Ledger and artifact regeneration (required, see Known Gap below):**

```bash
plugins/edm/bin/edm-state render-ledger EDMV3
plugins/edm/bin/edm-state audit-converged EDMV3; echo "exit=$?"   # expect 1 until Wave 7 closes the set
```

**Re-audit (targeted, after Wave 7):** re-run the lens agents whose lenses own the fixed findings. Given the spread this round, that is effectively **all eleven** -- Wave 7 touches every lens's surface. A **full round 4 is required**; a partial round cannot satisfy the convergence gate. When launching it, first confirm the plugin cache is fresh (see Non-Finding 4) so the JSONL half of every lens's output actually lands.

**Post-Remediation Closure:** the cross-round ledger at `code-audit/findings-ledger.jsonl` is the authoritative record; `findings-ledger.md` is a deterministic render of it produced by `edm-state render-ledger`. Update the ledger, not the render.

---

## Known Gap in This Round's Artifacts

`findings-ledger.jsonl` (250 entries) is fully updated and is the authoritative source. **`findings-ledger.md` has NOT been re-rendered and still shows the round-2 (2026-07-31) state.**

Reason: this synthesizer ran without a `Bash` tool, so `edm-state render-ledger EDMV3` could not be invoked. The markdown carries `<!-- GENERATED FILE ... Do not hand-edit; edits are overwritten on the next render. -->`, and `cmd_render_ledger` additionally calls `record_artifact_hash` -- so hand-transcribing 250 rows would both risk silent divergence from the JSONL and register a wrong artifact hash, which `cmd_checkpoint`'s drift loop would then flag. Fabricating a "generated" file was judged worse than leaving it stale and saying so.

**Required action before the round-3 gate is presented:**

```bash
plugins/edm/bin/edm-state render-ledger EDMV3
```

That one command reconciles the render, records the correct artifact hash, and makes `audit-converged` and the open-findings summary in `metrics-report` / HANDOFF read from consistent data. Everything else in this plan is complete and self-consistent against the JSONL.
