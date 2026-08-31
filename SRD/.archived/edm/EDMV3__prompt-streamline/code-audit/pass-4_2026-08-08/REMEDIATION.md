# Code Audit Remediation Plan: EDMV3 -- prompt-streamline (Round 4)

## Context

- Audit date: 2026-08-08
- Round: 4 (pass-4_2026-08-08)
- Round type: **full** (all 11 lenses ran: L1 L2 L3 L4 L5 L6 L7 L8 L9 L10 L11) -- eligible for convergence
- Audited scope: `plugins/edm/**` (bin/, bin/tests/, evals/, hooks/, skills/, agents/, docs/, monitors/), plus repository-root `CLAUDE.md`, `.gitlab-ci.yml`, `.gitignore`, and the initiative's own `SRD/edm/EDMV3__prompt-streamline/**`
- Branch: `edm/edmv3-prompt-streamline` (HEAD 4022300, Wave 7a-7g remediation landed)
- SRD: `SRD/edm/EDMV3__prompt-streamline/srd.md`
- Ticket pack: `SRD/edm/EDMV3__prompt-streamline/tickets/`
- Ledger: `SRD/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl` (authoritative, updated
  by this round's merge -- 297 entries)
- **`findings-ledger.md` is currently the stale round-3 render.** It is a generated projection and
  `edm-state render-ledger` is its only sanctioned writer, so this synthesis deliberately did not
  hand-edit it. Run `plugins/edm/bin/edm-state render-ledger EDMV3` to refresh it before reading it
  or committing.
- Deployment target: local plugin + GitLab CI (`.gitlab-ci.yml`, scoped to `plugins/edm/**`)

## Convergence Statement

**Convergence is NOT reached.**

| Metric | Count |
|---|---|
| Open P0 | **0** |
| Open P1 | **10** |
| Open P2 | **43** |
| **Total open (blocking set)** | **53** |
| Closed this round (`resolved_round = 4`) | 68 |
| Demoted to NOTED by the False Alarm Filter this round | 13 |
| Total ledger entries after merge | 297 |

The round was a full round and therefore eligible, but the blocking set is non-empty.
`BLOCKING_FILTER` at `plugins/edm/bin/edm-state:1244` is
`(.status == "open" or .status == "deferred") and (.sev == "P0" or .sev == "P1" or .sev == "P2")`,
so all 53 open findings block -- P2 included. `edm-state audit-converged EDMV3` will exit 1.

Two things are worth stating plainly, because they are the real result of this round:

1. **The round-3 P0 is closed and no new P0 was raised.** CA-182 (`cmd_approve_gate`'s
   environmentally unreachable convergence precheck -- the code-audit gate being unconditionally
   approvable for every initiative the current plugin creates) is FIXED, verified independently by
   L1 and L2 against the environmental constraint that made it a P0. Zero lenses filed a P0 this
   round. That is the first round with an empty P0 set.
2. **Closure rate is 68 of 87 carried-open findings (78 percent), and the P1 tier collapsed from
   18 to 10** -- but 34 of the 53 open findings are new, and 21 of those 34 were introduced by
   Wave 7's own remediation. That remediation-introduces-residue pattern is now four rounds old and
   is itself the dominant risk to convergence; see "Rollout Order" note 3.

## Findings Summary

43 of the 53 open findings are P2. Severity order, then lens count within tier.

### P0 (0)

None.

### P1 (10)

| # | Ledger ID | Sev | Lens(es) | Component | Issue |
|---|---|-----|----------|-----------|-------|
| G1 | CA-036 | P1 | L3+L4 | plugins/edm/bin/tests/wave7-smoke.sh:2051-2052 | errexit tripwire covers one of the class's shapes; live instance at top level turns a regression into a suite CRASH |
| G2 | CA-037 | P1 | L4 | plugins/edm/bin/tests/wave7-smoke.sh:1333-1336 | 16 expect-zero assertions have tautological positive controls -- control arm is dead code |
| G3 | CA-186 | P1 | L1+L3+L8 | plugins/edm/hooks/hooks.json:86 | commit-lint hook still fails OPEN in two srd_root shapes; diagnostic unreachable on the exit-0 path |
| G4 | CA-193 | P1 | L11 | plugins/edm/skills/code-audit/SKILL.md:218-226 | lens JSONL schema and CA-130 fallback were elided from the delivered prompt; step 8a is unchecked prose |
| G5 | CA-195 | P1 | L11 | plugins/edm/agents/edm-test-coverage-auditor.md:21 | legacy-flat-path class survives at 12 sites under the bare `SRD/{PREFIX}/` spelling, outside the tripwire needle |
| G6 | CA-251 | P1 | L1+L8 | plugins/edm/bin/edm-state:3381 | git-lock-check's pgrep ERE self-matches, so the removal branch is unreachable and the subcommand cannot remediate |
| G7 | CA-252 | P1 | L1+L3 | plugins/edm/evals/run-eval.sh:209-231 | cleanup()'s INT/TERM arms return instead of exiting; a Ctrl-C keeps running against a deleted scratch dir |
| G8 | CA-253 | P1 | L8 | plugins/edm/hooks/hooks.json:19 | all five UserPromptExpansion gate hooks refuse with exit 1, which does not block -- only exit 2 does |
| G9 | CA-254 | P1 | L9 | SRD/.../tickets/epics/11-cross-cutting-delivery.md:662 | T66 AC4 and T43 AC12 verify a string Wave 7c deleted; a green suite asserts their inverse |
| G10 | CA-255 | P1 | L9 | SRD/.../tickets/epics/05-orchestrator-dispatcher.md:645 | three AC reworks landed with no decisions.md record; two of them affirmatively claim the record exists |

### P2 (43)

| # | Ledger ID | Lens(es) | Component | Issue | Fix |
|---|---|----------|-----------|-------|-----|
| G11 | CA-049 | L7 | bin/tests/_harness.sh:4 | zero-caller half closed; two sourcing shapes and a fallback split survive, and the docstring example is the form the largest suite does not use | One sweep to the canonical form; update the :4 example |
| G12 | CA-074 | L7 | bin/edm-sync-canonical-sections:51 | named hybrid fixed; die() is still four shapes across twelve scripts, untested, plus two evals prefix conventions | Standardize on the two-arg form; add one smoke assertion |
| G13 | CA-145 | L4 | bin/tests/_harness.sh:189-198 | count_matches_strict has exactly one production caller; ~19 count_matches and ~45 bare `grep -c \|\| true` expect-zero sites remain | Convert the CA-037 sites and assert exit status |
| G14 | CA-146 | L4 | bin/tests/harness-smoke.sh:375-402 | six of eight run-all.sh accounting branches covered; the minimum-suite-count floor has no firing case (P1 -> P2) | One case using EDM_RUN_ALL_* overrides |
| G15 | CA-168 | L6 | docs/audit-patterns/test-coverage-audit.md:4 | wiring closed; all five pattern docs still name the orchestrator as auto-updater where README.md:71-72 names the phase skill | Change five headers to the phase skill |
| G16 | CA-196 | L1 | bin/tests/timing.sh:67-78 | ceiling fixed, so p95 now returns the MAX for every sample count in use while the key is still p95_ms; published budgets are pre-fix figures | Raise N to 20, or rename to max_ms and update four docs; record in decisions.md |
| G17 | CA-206 | L3 | bin/edm-state:2657-2661 | lock now held across both renames, but removed BEFORE the rename with two process launches in the window -- CA-141's TOCTOU one function away | Rename first, then remove lock names at the destination |
| G18 | CA-207 | L3 | bin/edm-state:378-382 | per-file cap landed; files lacking a trailing newline still splice, losing both messages at the boundary | Emit a newline after each file inside the loop |
| G19 | CA-227 | L7 | .gitlab-ci.yml:246 | success-path OK line landed; failure-path job-named FAILED line missing in three jobs | Add a job-named FAILED line before each exit 1 |
| G20 | CA-228 | L7 | agents/edm-test-unit.md:103-105 | two of three N/A enumerations now admit integration; edm-test-unit still lists five while citing the planner as its source | Change :104 to the six-layer set |
| G21 | CA-233 | L8 | .gitlab-ci.yml:105-107 | NOT FIXED: bash-syntax excludes only *.awk, shellcheck has no filter, so two data files are linted as bash and a prose ordering constraint is load-bearing for a blocking job | Exclude awk and txt in both loops; delete the prose constraint |
| G22 | CA-242 | L9 | SRD/.../epics/11-cross-cutting-delivery.md:641 | table repaired to nine scripts; no AC covers the script list, so it can go stale again undetected | Extend T66 AC3/AC4 with a row-count verify plus the smoke assertion |
| G23 | CA-246 | L3+L11 | bin/edm-state:1398-1404 | last_cmd and estimated_size still have zero producers; both consequences live; the guard test greps the enum, not a call site | Produce estimated_size at plan Gate 1; decide last_cmd; fix the guard test |
| G24 | CA-247 | L11 | SRD/.../architecture.md:631 | prose corrected but the citation was re-staled by the same edit; cmd_lint still has zero callers | Re-point the citation and add a citer comment; route or drop cmd_lint |
| G25 | CA-256 | L3+L5 | bin/edm-state:1010 | NEW (G49 residue): the flock timeout-marker path matches no .gitignore pattern, is covered by no trap, and is in no test enumeration | Widen both lock patterns to suffix-tolerant; add to the CA-148 enumeration and the two pre-rename cleanups |
| G26 | CA-257 | L2+L3 | bin/edm-state:1120-1124 | NEW: the reentrancy guard sits behind the mkdir spin loop, so the self-deadlock it names is reported as a 5 s contention timeout; fully inert on the flock branch | Move the check above the loop; set the depth on both branches; correct the comment |
| G27 | CA-258 | L1 | bin/edm-state:3327 | NEW: the age bucket ends at 1 minute (`-mmin +1`, true at >=2 min) while the action gate uses `-mmin +0`; the two disagree over [60s,120s) on a destructive path | Add a 0 bucket with its own label, or restate the guard message in matching units |
| G28 | CA-259 | L2 | bin/edm-state:654-662 | NEW: _print_literal has zero call sites after the CA-198 fix, and the comment retaining it names a pattern-library splice that never called it | Delete it, or state the real position; re-word the mislabelled assertion |
| G29 | CA-260 | L2 | evals/run-eval.sh:188 | NEW: `${run_total:-0}` after a `grep -c` capture that always prints a digit -- the CA-140/CA-202 class re-introduced by the retention fix | Delete :188 |
| G30 | CA-261 | L3 | bin/edm-state:2765 | NEW: metrics-report --calibrate guards on state-file count, not qualifying rows, so with no estimated_size producer the insufficient-data fallback never fires and it prints a header and nothing | Count filtered rows first; emit the fallback when zero |
| G31 | CA-262 | L4 | bin/tests/wave7-smoke.sh:4134 | NEW: the CA-147 positive-p95 assertion is probabilistic -- no perl on the pinned images, so the awk fallback yields 0 unless a sample crosses a second boundary, in a blocking job | Relax to a digits match with a caveat, or gate the strict form on `command -v perl` |
| G32 | CA-263 | L4 | bin/tests/wave7-smoke.sh:4811-4812 | NEW: numeric equality asserted through check(), a substring match -- "0" matches 10/20/30 | Use the numeric `-eq` idiom used elsewhere |
| G33 | CA-264 | L5 | bin/tests/wave7-smoke.sh:5020-5034 | NEW: the CA-160 line-cap probe writes a session JSONL into the real `${HOME}/.claude/projects/`, outside the scratch tree and outside the trap; the only $HOME use in 6,084 lines | Override HOME to a scratch dir and call session_dir_for_test_cwd |
| G34 | CA-265 | L6 | plugins/edm/CLAUDE.md:984 | NEW: CA-220's mirror site -- CLAUDE.md still says the .alpine_edm anchor covers "all seven jobs" where it has ten consumers, and .gitlab-ci.yml:56-60 was corrected to ten | Say ten consumers, matching the pipeline file |
| G35 | CA-266 | L6 | plugins/edm/CLAUDE.md:961,:966 | NEW: the CI table's lint:bash-syntax and lint:shellcheck rows both describe pre-CA-162 scope and omit evals/*.sh plus three CI bans | Name all three globs in both rows |
| G36 | CA-267 | L6 | bin/edm-state:3867 | NEW: two stale path:line citations -- implement/SKILL.md:98 where the call is at :117, and evals/baseline/README.md:11 pointing at help text and the new retention block instead of the auth gate | Re-point both; prefer the by-name step form CA-095 adopted |
| G37 | CA-268 | L6+L7+L8 | bin/edm-check-grants:124 | NEW: the last EXIT-only cleanup trap in bin/+evals/ where every sibling covers at least EXIT INT TERM; edm-state:604 cites it at the wrong line (:121, trap is at :124) | Add INT TERM; correct the citation |
| G38 | CA-269 | L7 | .gitlab-ci.yml:138 | NEW: the Wave-7 CA-019 entity-walk CI ban omits the bin/tests/ carve-out its two siblings carry, which is why CA-019 still has no smoke positive control | Append the carve-out; add the positive-control assertion |
| G39 | CA-270 | L7 | bin/tests/wave7-smoke.sh:303-325 | NEW: the CA-010 boundary assertion enumerates three shared-lint consumers where the library header now says four; edm-state's no-redefinition half is unguarded | Add edm-state to the loop at :312 |
| G40 | CA-271 | L8 | bin/tests/wave7-smoke.sh:4203,:4226 | NEW: the job-body extractor's terminator regex admits a column-0 comment ending in a colon, silently truncating a job body and hiding a later network call | Tighten the regex to exclude comment lines |
| G41 | CA-272 | L9 | SRD/.../epics/06-mermaid-rule.md:53 | NEW: T40 AC2's verify greps case-sensitively for a sentence that ships capitalized -- the defect CA-239 fixed for T38 AC6, sweep missed this sibling | Make the verify case-insensitive |
| G42 | CA-273 | L9 | SRD/.../epics/06-mermaid-rule.md:163 | NEW: T41 AC5 and Target Components name the wrong smoke suite and a case label that exists nowhere; the real assertions are at wave6-smoke.sh:3138-3195 | Re-point the AC at the shipped suite and labels |
| G43 | CA-274 | L9 | bin/tests/run-all.sh:196 | NEW (CA-089 fourth site): the assertion label still reads "fallback tripwire" after the AC, architecture.md and the script header all say it is not a fallback | Re-word the label |
| G44 | CA-275 | L9 | bin/tests/run-all.sh:21 | NEW: three audit-introduced config knobs (EDM_SMOKE_SUITES, EDM_EVAL_KEEP_RUNS, EDM_SRD_ROOT) have no ticket and no CHANGELOG entry | Add CHANGELOG entries and one CLAUDE.md note; keep the knobs |
| G45 | CA-276 | L10 | bin/edm-state:341 | NEW: two byte-identical 23-line jq token-sum programs whose only difference is already a `--arg` | Hoist into one _TOKEN_SUM_JQ string |
| G46 | CA-277 | L10 | bin/edm-state:2042 | NEW: 14-line token-unpack block copy-pasted between cmd_phase_complete and _cmd_audit_round_complete_body | Extract _unpack_token_fields |
| G47 | CA-278 | L10 | bin/edm-state:1062 | NEW: with_state_lock's retry-accounting tail exists in three copies under a comment that calls it shared | Extract one shared tail |
| G48 | CA-279 | L10 | hooks/hooks.json:23 | NEW: the five prompt hooks reimplement cmd_gate_check's mapping in prose with none of its mode or skipped-phase refinements | Route through edm-state gate-check |
| G49 | CA-280 | L10 | bin/tests/timing.sh:126 | NEW: the p95 sample loop is hand-repeated nine times, so G16's sample-count change needs nine synchronized edits | Extract _measure_p95; land before G16 |
| G50 | CA-281 | L10 | bin/tests/wave7-smoke.sh:232 | NEW (CA-094 residual): a duplicate whole-tree edm-check-grants run survives, and the hoisted capture's comment falsely claims it is the earliest point that needs it | Hoist above T03; correct the comment |
| G51 | CA-284 | L11 | plugins/edm/README.md:195 | NEW: lens-L{N}.jsonl is absent from both artifact-layout blocks though it is authoritative and a blocking precondition | Add it to both blocks, first |
| G52 | CA-285 | L11 | skills/orchestrator/SKILL.md:165 | NEW: the orchestrator never mentions /edm:test though CLAUDE.md says the flow suggests it at the end of Phase 6 | Add the suggestion, or correct CLAUDE.md |
| G53 | CA-286 | L11 | evals/score-artifacts.sh:429 | NEW: dimension 5 keys solely on the absence of lens-L*.jsonl and never consults lens-L*.md, so "no round" and "round with zero JSONL" score identically | Consult .md presence; report a failure, not null |

Two further L10 duplication findings were filed at **low** confidence and are therefore demoted to
NOTED rather than carried as P2 (CA-282, CA-283); see Decisions items 12 and 13. They are retained
in the ledger with their rationale, not deleted.

## Detailed Findings (P1)

### G1 / CA-036 (P1, lenses L3 + L4): errexit tripwire covers one shape; a live instance CRASHes the suite

**Problem**. The three named wave6 sites are fixed and the prescribed tripwire landed with a real
synthetic positive control (G5 of round 3, `wave7-smoke.sh:5289-5326`). The detector's reach is the
residual: both regex branches require the failing command to be a *quoted command substitution
assigned to a bare variable*, so three variants carrying the identical `set -e` hazard are
invisible -- a plain command followed by a bare exit-code read, a `local`-prefixed assignment, and
an unquoted substitution.

One live instance sits at top level outside any errexit bracket:

```bash
2050  t43_start="$SECONDS"
2051  bash "$LINT_BIN" --path "${T43_SCRATCH}/nested.md" >/dev/null 2>&1
2052  t43_rc=$?
2054  [[ "$t43_elapsed" -le 10 && "$t43_rc" -le 1 ]] \
```

`:2054` tolerates exit 1, but under `set -euo pipefail` the exit 1 at `:2051` aborts the shell
first, so the tolerance is unreachable and a real regression becomes a suite-wide CRASH rather than
a named failed assertion. Two further sites are invisible to the tripwire because no exit-code line
follows at all (`wave7:2310`, `wave6:854`), and two more were introduced by this round's own CA-147
remediation (`wave7:4104`, `:4123`).

L3 corroborates at a different site in the same class: the new SIGINT regression case at
`wave7-smoke.sh:4745-4818` is genuinely discriminating, but it is called bare under `set -e` with
two `return 1` paths, and its `kill -INT` at `:4799` is unguarded where the sibling at `:4788`
carries a trailing or-true. On a slow CI runner a recorded FAIL becomes a CRASH that loses every
assertion after it.

**Fix**.
1. `wave7-smoke.sh:5289-5326`: add a third alternative to both tripwire regexes covering
   (a) a plain command line followed by a line matching `^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=\$\?`,
   (b) the same shapes with a `local ` prefix, (c) an unquoted `VAR=$(...)`.
   Keep the existing synthetic positive control and add one per new alternative.
2. `wave7-smoke.sh:2051-2052`: convert to the form the sibling at `:2032-2034` already uses --
   seed `t43_rc=0` before the call and capture with `|| t43_rc=$?` on the same statement.
3. `wave7:2310`, `wave6:854`, `wave7:4104`, `:4123`: same conversion.
4. `wave7-smoke.sh:4745-4818`: call the case with a trailing `|| true`, add `|| true` to the
   `kill -INT` at `:4799`, and add a fourth assertion that `$dest` is absent after the interrupt.

**Verification**. `bash plugins/edm/bin/tests/wave7-smoke.sh` completes with a summary line (not a
CRASH). Then break `edm-lint-artifacts` deliberately so it exits 1 on the T43 fixture and confirm
the suite reports a *named failed assertion* at T43 rather than terminating. Then add a deliberate
plain-command-then-exit-code line in a scratch copy and confirm the widened tripwire flags it.
`bash plugins/edm/bin/tests/run-all.sh` reports no CRASH for any suite.

**Files affected**: `plugins/edm/bin/tests/wave7-smoke.sh`, `plugins/edm/bin/tests/wave6-smoke.sh`.

---

### G2 / CA-037 (P1, lens L4): 16 expect-zero assertions have tautological positive controls

**Problem**. ESCALATED P2 -> P1. `assert_absent_with_control` is itself correct and well
self-tested. The call sites are not: at 16 of them the control haystack is a literal string
authored in the test that contains the needle by construction, so the control arm is *provably dead
code* -- it proves the matcher works against a string the test just wrote, never that the real scan
was capable of finding anything. The real haystacks are still produced by scans that swallow every
error (discarded stderr, trailing or-true, chained inverted filters), so CA-037's original failure
mode -- a wrong `PLUGIN_DIR` or a mistyped filter reading identically to a clean tree -- is exactly
as live as before, and in both copies of the duplicated repo-wide scans at once. Three shipped
comments state the opposite. This is the second consecutive round in which a remediation for this
finding produced the appearance of coverage rather than coverage.

**Fix**. The correct shape already exists at five sites and is the template: `wave6:2473`,
`wave7:2654`, `wave7:3944`, and the two new tripwires at `:5317` and `:5349`. For each of the 16
sites, either
(a) run the real scan over a scratch tree seeded with exactly one planted violation and assert the
    scan finds that one, then re-run against the real tree and assert zero; or
(b) at minimum, point the control at a real in-tree file known to contain the needle, so a broken
    `PLUGIN_DIR` fails the control.
Do this in the same edit as G13 (CA-145): convert the site to `count_matches_strict` and assert its
exit status as well as its printed value, which closes both findings at that site at once.

**Verification**. For each converted site, temporarily set `PLUGIN_DIR` to a nonexistent path and
confirm the assertion FAILS (today it passes). Then restore and confirm it passes. `bash
plugins/edm/bin/tests/harness-smoke.sh` still green.

**Files affected**: `plugins/edm/bin/tests/wave7-smoke.sh`, `plugins/edm/bin/tests/wave6-smoke.sh`,
`plugins/edm/bin/tests/wave5-smoke.sh`, `plugins/edm/bin/tests/_harness.sh`.

---

### G3 / CA-186 (P1, lenses L1 + L3 + L8): commit-lint hook still fails OPEN in two srd_root shapes

**Problem**. PARTIALLY FIXED. All three defects CA-186 named are genuinely closed, with a real
end-to-end positive control at `wave7-smoke.sh:5369-5436`: trailing slashes are stripped by a loop,
an absolute value is refused with a named diagnostic, and the root reaches awk through `ENVIRON[]`
rather than `-v` so backslash escape processing no longer mangles it. Two residual bypasses remain,
and both still fail **open** on a security control.

1. (L8, P1) An absolute `srd_root` is now *detected*, but the hook still `exit 0`s after writing its
   diagnostic to stderr. Claude Code sends an exit-0 hook's stderr to the debug log only, never the
   transcript -- so the operator experiences the same silent loss of all commit-time artifact
   enforcement as before. The diagnostic exists and is unreachable.
2. (L3 and L8 independently) Only **one** leading `./` is stripped, and the trailing-slash collapse
   runs *before* the absolute check. So `.`, `./`, `././SRD` and `SRD/.` all still disable
   enforcement, some with no message on any channel.

**Lens disagreement, resolved**: L1 verdicted CA-186 fully fixed and filed the multi-`./` case as
Not Actionable on the grounds that no documented workflow produces such a value. Resolved toward
L3 + L8 on two-lens corroboration and on direction: a security control that fails open does not get
the documented-workflow defence, because the operator cannot tell the difference between "enforced"
and "silently not enforced".

**Fix** (`plugins/edm/hooks/hooks.json:86`):
1. Loop the `./` strip exactly as the trailing-slash strip is looped:
   `while [ "${srd_root#./}" != "$srd_root" ]; do srd_root="${srd_root#./}"; done`.
2. Move the absolute-path check **ahead** of the trailing-slash collapse, so `/` is classified as
   absolute rather than reduced to empty.
3. For an absolute value, first try to relativize it under the repository root
   (`git rev-parse --show-toplevel`); only if that fails, emit the diagnostic and `exit 1`, which IS
   surfaced in the transcript. Do not use exit 2 here -- exit 2 blocks the commit, and a
   misconfigured root should not block, it should be loud.
4. Add a `test -d "$srd_root"` positive control so a root that does not exist is named.

**Verification**. In a scratch repo with one staged artifact containing a known violation, run the
hook body with `EDM_SRD_ROOT` set to each of `SRD`, `./SRD`, `././SRD`, `SRD/`, `SRD/.`, `/`,
`/abs/path/SRD`, and the empty string. Assert: the four relative shapes all *block* (hook exit 2),
the absolute shapes print a transcript-visible diagnostic and exit 1, and no shape exits 0
silently. Extend the `wave7-smoke.sh:5369-5436` control to cover all eight.

**Files affected**: `plugins/edm/hooks/hooks.json`, `plugins/edm/bin/tests/wave7-smoke.sh`.

---

### G4 / CA-193 (P1, lens L11): lens JSONL schema elided from the delivered prompt; step 8a unchecked

**Problem**. PARTIALLY FIXED, and the residual has moved from the file to the mechanism. The
repository-side fix landed exactly as prescribed: `skills/code-audit/SKILL.md:218-226` now carries
the one-line literal JSONL schema *alongside* the pointer, plus a CA-130 fallback clause. The
observable result is a real improvement -- all eleven `lens-L{N}.jsonl` files exist for pass-4 where
pass-3 had none, so `score-artifacts.sh` dimension 5 has input again and this synthesis read both
halves.

But the prompt actually *delivered* to L11 this round carried the pointer form only: the literal
schema line and the fallback clause were both elided, and the delivered agent definition again had
no `## JSONL Line Format` section to resolve the pointer against. The schema survived this round
only because the launching agent transcribed all eleven JSONL files by hand. The mechanism is
therefore still one elision away from the CA-020 break it was created to close.

**Fix**.
1. `skills/code-audit/SKILL.md:218-226`: make the schema line and the fallback clause
   non-elidable -- put them inside the fenced launch template body rather than as prose bullets
   above it, so they travel with the prompt text that is interpolated verbatim.
2. Land CA-176's prescription, now load-bearing: convert step 8a from a prose precondition into a
   **checked** one. Before spawning the synthesizer, `Glob` the pass directory for
   `lens-L*.jsonl` and refuse to proceed unless the count equals `|LENS_SET|`, naming the missing
   lenses. A dropped half then fails at the gate instead of an audit round later.
3. Keep CA-176 as a NOTED standalone; its prescription is now carried here.

**Verification**. Run `/edm:code-audit EDMV3` with a deliberately emptied `lens-L7.jsonl` and
confirm step 8 refuses and names L7. Then confirm a normal round proceeds. Grep the rendered launch
template for the literal schema string to prove it is inside the interpolated body.

**Files affected**: `plugins/edm/skills/code-audit/SKILL.md`.

---

### G5 / CA-195 (P1, lens L11): legacy-flat-path class survives at 12 sites under the bare spelling

**Problem**. PARTIALLY FIXED. Every one of the seventeen sites CA-195 enumerated is converted, and
L11 verified the resolve-dir preamble and the interpolated `INIT_DIR` at each. The sweep keyed on
the spelling the finding happened to name, so the class survives at twelve further sites under the
bare `SRD/{PREFIX}/` spelling -- four skills and three agents -- all of them outside the G14
tripwire's needle. For those twelve the live consequence CA-195 was raised for is unchanged: on a
product-scoped initiative (which is the only kind this repository has) the literal path does not
exist, the skill checks it, finds nothing, and prints a false refusal telling the operator to run an
earlier phase.

**Fix**.
1. Sweep the twelve remaining sites to the resolved `${INIT_DIR}`, using the two-line
   `edm-state resolve-dir` preamble that `skills/code-audit/SKILL.md:44-51` models. Agents take the
   resolved directory from their launcher rather than re-deriving it.
2. Widen the G14 tripwire needle to match the bare `SRD/{PREFIX}/` spelling as well as the
   `srd_root`-prefixed one -- otherwise the next sweep misses the same set again. This is the
   load-bearing half: the tripwire is what makes the sweep durable.

**Verification**. `grep -rn 'SRD/{PREFIX}' plugins/edm/skills plugins/edm/agents` returns zero
outside deliberate legacy-layout prose. Run `/edm:test-plan EDMV3` and confirm it resolves the
product-scoped directory instead of printing a false refusal. The widened tripwire fails when a
bare-spelling literal is re-introduced into a scratch copy.

**Files affected**: `plugins/edm/skills/{test-plan,test-coverage,test,push-jira}/SKILL.md`,
`plugins/edm/agents/edm-test-coverage-auditor.md`, `plugins/edm/agents/edm-test-planner.md`,
`plugins/edm/agents/edm-qc-auditor.md`, `plugins/edm/bin/tests/wave7-smoke.sh` (tripwire).

---

### G6 / CA-251 (P1, lenses L1 + L8): git-lock-check's pgrep probe self-matches, so it can never remediate

**Problem**. NEW, introduced by this round's own CA-203 remediation, and filed independently by L1
and L8 at the same site. The replacement liveness probe at `bin/edm-state:3381` is
`holder_evidence="$(pgrep -f -- "$git_dir" ...)"`, and it is wrong in three compounding ways while
the comment at `:3368-3375` asserts the opposite:

1. `git_dir` comes from `git rev-parse --git-dir` at `:3338`, which prints the **relative** string
   `.git` from the top of a work tree -- the normal invocation point. The pattern is four
   characters, not a repository-identifying path.
2. `pgrep -f` takes an extended regex, so `.` is a wildcard: `.git` matches any command line
   containing any character followed by `git` -- `/usr/lib/git-core/...`, `digit`, `legit`, an
   unrelated repository's git. The probe is host-wide, which is exactly the failure the comment
   claims to have eliminated.
3. It self-matches. The invoking process's own command line ends in ` git-lock-check`, and `pgrep`
   excludes only itself, not its ancestors, so ` git` matches and `holder_evidence` is non-empty.

Net effect: whenever `lsof` reports nothing -- a genuinely stale lock, the only case this subcommand
exists for -- the pgrep fallback fires, `:3384-3389` prints "possible holder evidence was found",
and the removal branch at `:3391-3404` is unreachable. The subcommand can no longer perform its
documented remediation. L8 adds a second direction: an invalid-ERE `GIT_DIR` empties the evidence
and removes the lock with **no** liveness check at all.

This is invisible to the suite: `wave7-smoke.sh:5804-5811` greps the function body for the literal
source text `pgrep -f -- "$git_dir"` and never executes the branch (`:5821` runs the command only in
a repo with no lock file).

**Fix** (`plugins/edm/bin/edm-state:3327-3404`):
1. Resolve the git dir to an absolute path before using it as a scope:
   `git_dir="$(git rev-parse --absolute-git-dir)"`.
2. Keep `lsof` as the primary oracle. For the fallback, match as a **fixed string**, not an ERE:
   pipe `pgrep -af -- "$abs_git_dir"` output through `grep -F -- "$abs_git_dir"`.
3. Exclude this process's own ancestry (`$$`, `$PPID`) from the candidate PID set.
4. If neither `lsof` nor a literal-capable `pgrep` is available, print "liveness could not be
   determined" and refuse, rather than guessing in either direction.
5. Fold in G27 (CA-258) while in this function: the age bucket and the action gate must use the
   same threshold.

**Verification**. Add an executing test, not a source grep: create a scratch repo, `touch
.git/index.lock`, backdate its mtime past the age gate, and assert (a) the removal path IS taken and
the lock file is gone, (b) with a live `git` process holding the real lock the removal is refused,
(c) with `GIT_DIR` set to a string containing ERE metacharacters the command still refuses rather
than removing. Then confirm the printed age string agrees with the action taken.

**Files affected**: `plugins/edm/bin/edm-state`, `plugins/edm/bin/tests/wave7-smoke.sh`.

---

### G7 / CA-252 (P1, lenses L1 + L3): run-eval's cleanup trap returns instead of exiting

**Problem**. NEW, aggravated by this round's CA-214 remediation, filed by L1 and L3 independently.
`cleanup()` is installed on `EXIT INT TERM` at `evals/run-eval.sh:231`, but only one of its two
terminal branches actually terminates. When `STARTED=true` and `COMPLETE != true` it calls `exit 4`
at `:226`; on every other path it falls through to `prune_old_runs; return "$ec"` at `:228-229`.

A returning trap handler resumes the interrupted script, and `set -e` is deliberately off (`:63`).
So a Ctrl-C before `STARTED=true` (set at `:401`, i.e. during the bounded auth probe at `:300` or
`provision_scratch` at `:324`) kills the child, deletes `SCRATCH_DIR` at `:220-222`, and then lets
execution continue against a directory that no longer exists. The observable result is `exit 2` with
"no working Claude auth" or "failed to initialize scratch git repository" reported for what was a
user interrupt. L3 adds that the `CLEANUP_DONE` latch at `:213` makes the interrupt
**unrepeatable** -- a second Ctrl-C is a no-op -- and that this permanently disables
`write_partial_artifacts` and the documented exit-4 contract on the interrupt path.

Compounding: `local ec=$?` at `:210` captures the last command's status, not `130`/`143`, so even
the exiting branch cannot report a signal-conventional code. This is exactly the missing-terminal-
exit class the CA-143 remediation fixed in `bin/edm-state` (`:622-625`, `:1115-1118`) and did not
sweep into this sibling driver.

**Fix** (`plugins/edm/evals/run-eval.sh:209-231`):
1. Make `cleanup` the EXIT body only; it must never call `exit`.
2. Install separate signal wrappers: `trap 'cleanup; exit 130' INT` and
   `trap 'cleanup; exit 143' TERM`, matching `edm-state:622-625`.
3. Move the `exit 4` decision into the EXIT body only, and leave the `CLEANUP_DONE` guard as-is so
   the second entry is a no-op rather than a double prune.
4. Add `HUP` while here (see NOTED CA-291): this is the longest-running process in the tree.

**Verification**. Start `run-eval.sh` and Ctrl-C during the auth probe; assert exit status 130, no
"no working Claude auth" message, and that `SCRATCH_DIR` is gone. Repeat after `STARTED=true` and
assert exit 4 with `run.json` written by `write_partial_artifacts`. Confirm `prune_old_runs` ran on
both paths.

**Files affected**: `plugins/edm/evals/run-eval.sh`.

---

### G8 / CA-253 (P1, lens L8): the five gate hooks refuse with exit 1, which does not block

**Problem**. NEW. All five UserPromptExpansion gate hooks (`hooks/hooks.json:19`, `:32`, `:45`,
`:58`, `:71`) refuse by exiting 1. Claude Code treats a non-zero-but-not-2 hook exit as
non-blocking and proceeds with the expansion anyway; only exit 2 blocks. So the deterministic half
of HITL gate enforcement -- the half that is supposed to stop a phase skill running before its gate
is approved -- does not enforce. This is the same exit-1-versus-exit-2 semantics that CA-011 settled
for the PreToolUse commit hook and that CA-224 documented in the CLAUDE.md hooks table; the
UserPromptExpansion family was never converted.

Severity is P1 rather than P0 because the *advisory* half still works (the refusal message is shown,
so an attentive operator stops) and because `edm-state`'s own gate checks refuse independently
inside each phase skill. It is a defence-in-depth layer that is silently inert, not the only layer.

**Fix** (`plugins/edm/hooks/hooks.json`): change both `exit 1` sites in each of the five hooks to
`exit 2`. Drop the `2>&1` from the `gate-check` invocation so the diagnostic goes to stderr, which
is where Claude Code reads a blocking hook's message from. Do not change the empty-`$ARGUMENTS`
guard's exit code in the same edit without re-checking CA-087's disposition.

**Verification**. With `code_audit_gate` unapproved, invoke `/edm:implement EDMV3` and assert the
expansion is *blocked* and the refusal text appears in the transcript. Approve the gate and confirm
it proceeds. Add a `wave7-smoke.sh` assertion that all five hook bodies contain `exit 2` and no
bare `exit 1` on the refusal path.

**Files affected**: `plugins/edm/hooks/hooks.json`, `plugins/edm/bin/tests/wave7-smoke.sh`,
`plugins/edm/CLAUDE.md` (hooks table row, if it states the code).

---

### G9 / CA-254 (P1, lens L9): T66 AC4 and T43 AC12 verify a string this round's remediation deleted

**Problem**. NEW, and self-inflicted by Wave 7c. Both `epics/11:662` (T66 AC4) and
`epics/06:402-404` (T43 AC12) state their verify as a grep of `plugins/edm/CLAUDE.md` for the
literal phrase "four violation classes". Wave 7c's CA-017/CA-187 remediation deleted that phrase --
correctly, because the linter emits seven classes, not four -- and rewrote `CLAUDE.md:762` to defer
to `--help`. `wave7-smoke.sh:5475` now asserts the phrase's **absence**.

So two Must-Have acceptance criteria are permanently unpassable, and a green suite asserts their
inverse, with no `decisions.md` record of the AC rework. This is CA-033's class exactly, reopened by
this round's own remediation.

**Fix**.
1. Amend both ACs to the shipped contract: the verify should assert that the `bin/` table row
   defers to `--help` and that `edm-lint-artifacts --help` enumerates all seven emitted classes,
   which is what actually ships and is what `wave7-smoke.sh:5475-5478` and `:2228-2234` assert.
2. Record the rework in `decisions.md` as a D-numbered entry naming T66 AC4 and T43 AC12, with the
   before and after AC text quoted, per the change-control requirement at `tickets/README.md:64-65`.
   Fold this into G10's single decisions.md commit.

**Verification**. Run both amended verify commands and confirm they pass on the current tree.
Confirm `decisions.md` names both ACs. `bash plugins/edm/bin/tests/wave7-smoke.sh` still green.

**Files affected**: `SRD/edm/EDMV3__prompt-streamline/tickets/epics/11-cross-cutting-delivery.md`,
`SRD/edm/EDMV3__prompt-streamline/tickets/epics/06-mermaid-rule.md`,
`SRD/edm/EDMV3__prompt-streamline/decisions.md`.

---

### G10 / CA-255 (P1, lens L9): three AC reworks landed with no decisions.md record; two claim one exists

**Problem**. NEW, merged from three sites that share one root cause and one fix location. Wave 7f
reworked three acceptance criteria correctly, and none of the three reworks was recorded in
`decisions.md` as the pack's own change-control convention requires:

- **T39 AC5** (`epics/05:645`) and **T39 AC9** (`epics/05:670`) each now assert that the rework is
  "recorded in decisions.md". No such record exists: a search for the terminology, for "re-verif",
  and for T39 across `decisions.md` returns nothing relevant; D23 still enumerates only AC2, AC3,
  AC4 and AC7; D37 names T39 only for a CHANGELOG bullet. These two are **affirmatively false
  cross-references inside an acceptance criterion**, which is why the merged finding is P1.
- **T37 AC6** (`epics/05:374`) was correctly rewritten to the shipped per-phase contract (closing
  CA-190's substance) but carries no record either. That half is the P2 shape -- omission rather
  than false claim.

`tickets/README.md:64-65` and CLAUDE.md's unverifiable-AC contract both require an AC rework to be
recorded in `decisions.md` and in the ticket's audit trail. CA-163 was this same class one round ago
and was closed by adding D36; the convention exists and was simply not applied three more times.

**Fix**. One commit against `decisions.md`:
1. Add a D-numbered entry recording the T39 AC5 rework: the terminology that shipped in
   `run-eval.sh:350-352`/`:415-417` and `orchestrator/SKILL.md:130`, the AC's amended wording, and
   the re-verification result.
2. Add a D-numbered entry recording the T39 AC9 walk-back to T23 AC11's naming-convention wording
   and the fact that no plotting script was built.
3. Add a D-numbered entry recording the T37 AC6 per-phase rework, mirroring D36's shape.
4. Add G9's T66 AC4 / T43 AC12 entry in the same commit.
5. In all three tickets, replace "recorded in decisions.md" with the actual D number, so the
   cross-reference resolves instead of asserting.

**Verification**. For each of the four ACs, run its verify command and confirm it passes. Grep
`decisions.md` for each D number from the ticket text and confirm the reference resolves. Confirm
`CHANGELOG.md` and `decisions.md` do not disagree on T39.

**Files affected**: `SRD/edm/EDMV3__prompt-streamline/decisions.md`,
`SRD/edm/EDMV3__prompt-streamline/tickets/epics/05-orchestrator-dispatcher.md`,
`SRD/edm/EDMV3__prompt-streamline/tickets/epics/11-cross-cutting-delivery.md`,
`SRD/edm/EDMV3__prompt-streamline/tickets/epics/06-mermaid-rule.md`.

---

## Decisions / Non-Findings

Items flagged by one or more lenses this round and determined Not Actionable. Future audits should
NOT re-investigate these. Each carries a ledger ID so it renders in the ledger's Decisions section.

1. **CA-287 (L1) `evals/run-eval.sh:248-252`** -- `--provision-only` exits after the trap install so
   `prune_old_runs` runs in a mode documented as self-contained; bounded and harmless.
2. **CA-288 (L1) `bin/edm-compare-eval:108-119`** -- per-dimension delta table joins positionally;
   safe by construction (fixed DIM_NAMES order plus an enforced equality precheck).
3. **CA-289 (L1+L7) `bin/edm-compare-eval:41-44`** -- accepts `-h`/`--help` but not the bare `help`
   token eleven siblings accept; L1 deferred it to L7, L7 declined to file it.
4. **CA-290 (L2) `bin/_edm-lint-lib.sh:211-214`** -- `report_violation`'s arity guard cannot fire
   today; retained deliberately on a function four binaries consume with two field orders.
5. **CA-291 (L5) six traps omit HUP** (`run-eval.sh:231`, `edm-lint-artifacts:141`,
   `_harness.sh:76`/`:104`, `harness-smoke.sh:292`, `wave7-smoke.sh:25`, `tiering-matrix.sh:147`) --
   all own TMPDIR-only or gitignored self-reclaiming resources; the two tracked-file sites are fixed.
6. **CA-292 (L5) `evals/run-eval.sh:196`** -- prune window still positions with `ls -1t`, so an
   adversarially named regular file consumes a keep slot; keeps one run too many, never deletes one.
7. **CA-293 (L2+L3) `bin/edm-state:536-553`** -- `_restore_traps` ordering inside the locked subshell
   and the fixed-global save/restore pair cannot collide; both orderings end the critical section at
   the same point.
8. **CA-294 (L3) `bin/edm-state:1012` vs `:1052`** -- mkdir branch gives up after about 5 s, flock
   branch after 10 s; neither bound is close to binding.
9. **CA-295 (L4) `bin/tests/` about 40 unguarded setup captures** -- preconditions, not assertion
   subjects; `harness-smoke.sh:311`'s weak first assertion is redundant behind a strong block.
10. **CA-296 (L6) `.gitlab-ci.yml:22-23` and two agent Output samples** -- the package-set sentence is
    an approximation beside an exact pinning claim; the stale citations sit inside fenced template
    illustrations, not factual claims.
11. **CA-297 (L11) `skills/orchestrator/SKILL.md` flat-path probe, `agents/edm-qc-auditor.md:77`** --
    prose shorthand beside an already-correct `edm-validate-prefix` call, and a deliberate reference
    to the legacy layout as a concept rather than a path.
12. **CA-282 (L10) `bin/edm-state:2812`** -- three forked jq renderer expressions in
    `cmd_metrics_report`; filed at low confidence with no live drift demonstrated, so demoted rather
    than carried. Cheap hardening only.
13. **CA-283 (L10) `evals/run-eval.sh:442`** -- three copy-pasted phase blocks whose drift is in
    statement placement, not semantics; filed at low confidence, no input shown for which the three
    disagree on outcome. A future round should re-check placement before closing.

Items 12 and 13 are demotions, not dismissals: the False Alarm Filter retains a low-confidence
single-lens finding at `sev: NOTED` with its rationale recorded rather than discarding it, so both
remain in the ledger and neither is re-investigated from scratch next round.

Prior NOTED entries re-confirmed unchanged and not re-investigated: CA-105, CA-106, CA-107, CA-108,
CA-109, CA-110, CA-111, CA-112, CA-113, CA-114, CA-115, CA-116, CA-117, CA-118, CA-119, CA-120,
CA-121, CA-122, CA-123, CA-124, CA-125, CA-126, CA-128, CA-129, CA-131, CA-132, CA-169, CA-170,
CA-171, CA-172, CA-173, CA-174, CA-175, CA-177, CA-178, CA-179, CA-180, CA-181, CA-248, CA-249,
CA-250.

Two prior NOTED entries changed status in substance without becoming actionable on their own:

- **CA-130 (updated, all 11 lenses)** -- the missing-`Write`-tool artifact reproduced a **fifth**
  consecutive round: all eleven lenses reported `Write` absent from the delivered runtime tool set
  despite the frontmatter grant, and all 22 output files were transcribed by the launching agent.
  The stale-agent-definition half **narrowed**: L2 and L3 confirmed their delivered definitions
  matched the on-disk files this round, while L7, L10 and L11 reported pre-CA-165 revisions missing
  up to four sections. So the stale plugin cache is intermittent per-agent rather than uniform.
  This round also *proved the mitigation works*: step 8a was followed by all eleven lenses and every
  `lens-L{N}.jsonl` exists for pass-4 where pass-3 had none. Still host-side, not a repository
  defect; the repository-side half that remains open is G4 (CA-193).
- **CA-176 (NOTED, retained)** -- the step-8 JSONL precondition. Its prescription is now carried
  inside G4 (CA-193) because a fourth recurrence of the delivery-layer break made it load-bearing.
  The standalone entry stays NOTED so it is not double-counted in the blocking set.

Four lens disagreements were adjudicated rather than filed twice:

1. **CA-186 residual** -- L1 said fixed and Not Actionable; L3 and L8 said partially fixed.
   Resolved toward L3+L8 (see G3).
2. **CA-168** -- L11 verdicted fixed end to end on wiring evidence; L6 verdicted partially fixed on
   header evidence. Resolved toward L6; the header claim is inside CA-168's original text and L6
   owns documentation accuracy (G15).
3. **CA-049 residual** -- L10 ruled the two `_harness.sh` sourcing shapes both sanctioned; L7 filed
   the docstring-versus-practice mismatch. Resolved toward L7, at P2 (G11).
4. **`edm-check-grants:124` EXIT-only trap** -- L5 filtered it as a consistent project pattern; L7
   filed it as the last EXIT-only trap in a family where every sibling covers more, and L8
   independently flagged the accompanying stale citation. Resolved toward L7+L8 as G37 (CA-268),
   at P2.

## Rollout Order

Waves 8a through 8e touch **disjoint file territory** and can be run in parallel worktrees.
Wave 8f must run **after** 8a, 8b and 8c because it adds the regression cases those fixes need.
Wave 8g is disjoint from all of them.

| Wave | Territory | Findings | P1s | Parallel with |
|---|---|---|---|---|
| 8a | `plugins/edm/bin/edm-state`, `.gitignore` | G6, G17, G18, G23(code), G25, G26, G27, G28, G30, G36(code), G37(citation), G45, G46, G47 | G6 | 8b, 8c, 8d, 8e |
| 8b | `plugins/edm/hooks/hooks.json` | G3, G8, G48 | G3, G8 | 8a, 8c, 8d, 8e |
| 8c | `plugins/edm/evals/**` | G7, G29, G36(baseline README), G53 | G7 | 8a, 8b, 8d, 8e |
| 8d | `plugins/edm/skills/**`, `plugins/edm/agents/**`, `plugins/edm/docs/audit-patterns/**` | G4, G5(prompt half), G15, G20, G52 | G4, G5 | 8a, 8b, 8c, 8e |
| 8e | `SRD/edm/EDMV3__prompt-streamline/**` (tickets, decisions.md, architecture.md) + `CHANGELOG.md` | G9, G10, G22, G24(prose), G41, G42, G44(changelog) | G9, G10 | 8a, 8b, 8c, 8d |
| 8f | `plugins/edm/bin/tests/**` | G1, G2, G5(tripwire), G11, G13, G14, G16, G31, G32, G33, G39, G40, G43, G49, G50 | G1, G2 | after 8a/8b/8c |
| 8g | `.gitlab-ci.yml`, `plugins/edm/CLAUDE.md`, root `CLAUDE.md`, `plugins/edm/README.md`, other `bin/` scripts | G12, G19, G21, G34, G35, G37(trap), G38, G51 | none | any |

Sequencing notes:

1. **Do G49 (CA-280) before G16 (CA-196).** Extracting `_measure_p95` first turns G16 from nine
   synchronized edits into one. Both are in 8f, so order them inside the wave.
2. **Do G2 (CA-037) and G13 (CA-145) in the same edit per site.** Converting a site to
   `count_matches_strict` and giving it a real positive control closes both findings at that site
   at once; doing them separately means touching all 16 sites twice.
3. **8f is where the round's real risk sits.** Twenty-one of the 34 new findings were introduced by
   Wave 7's own remediation, and the two P1s in 8f (G1, G2) are both *remediations that produced the
   appearance of coverage rather than coverage*. Every new or widened assertion in 8f must be proven
   by breaking the thing it guards and observing a named failure -- not by observing that the suite
   is green. That is the single highest-value discipline for reaching convergence in round 5.
4. **Cross-wave file overlaps to serialize by hand**: G23 (CA-246) needs a line in
   `skills/plan/SKILL.md` (8d) as well as `bin/edm-state` (8a); G24 (CA-247) needs a `cmd_lint`
   decision in `bin/edm-state` (8a) alongside its `architecture.md` prose (8e); G44 (CA-275) needs a
   `plugins/edm/CLAUDE.md` note (8g) alongside its CHANGELOG entries (8e); G36 (CA-267) spans
   `bin/edm-state` (8a) and `evals/baseline/README.md` (8c). Assign each split to its primary wave
   and let the secondary wave pick up the one-line companion edit.
5. **Nothing here is a P0, so no fix is shipping-blocking on its own.** The gate that is blocked is
   convergence, and it is blocked by the whole 53-item set, not by any single finding.

## Verification Plan

Run from the repository root. `plugins/edm/bin/*` must be invoked by explicit path -- a bare
`edm-*` command resolves to a stale plugin cache (see MEMORY.md).

```
# Syntax and static analysis (mirrors the blocking lint stage)
bash -n plugins/edm/bin/edm-state
for f in plugins/edm/bin/* plugins/edm/bin/tests/*.sh plugins/edm/evals/*.sh; do
  case "$f" in *.awk|*.txt) continue ;; esac
  bash -n "$f" || echo "SYNTAX FAIL: $f"
done
shellcheck plugins/edm/bin/edm-state plugins/edm/bin/edm-check-grants plugins/edm/evals/run-eval.sh
jq -e . plugins/edm/hooks/hooks.json >/dev/null
jq -se . SRD/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl >/dev/null

# Project linters and artifact conventions
plugins/edm/bin/edm-lint-artifacts --all
plugins/edm/bin/edm-check-grants
plugins/edm/bin/edm-check-vocabulary
plugins/edm/bin/edm-sync-canonical-sections --check
plugins/edm/bin/edm-check-skill-sync

# Full suite (this is the verdict of the blocking test:smoke jobs)
bash plugins/edm/bin/tests/run-all.sh          # must print a summary, never CRASH
bash plugins/edm/bin/tests/harness-smoke.sh

# State and ledger
plugins/edm/bin/edm-state validate EDMV3
plugins/edm/bin/edm-state render-ledger EDMV3   # regenerate findings-ledger.md from the JSONL
plugins/edm/bin/edm-state audit-converged EDMV3 # expect exit 1 until the blocking set is empty
```

Manual smoke tests that no automated check covers today:

1. **G6**: scratch repo, backdated `.git/index.lock`, assert `git-lock-check` actually removes it;
   then with a live holder, assert it refuses.
2. **G3 / G8**: exercise the hooks with each `EDM_SRD_ROOT` shape and with an unapproved gate, and
   confirm blocking behaviour and transcript-visible messages.
3. **G7**: Ctrl-C `run-eval.sh` before and after `STARTED=true`; assert 130 and 4 respectively.
4. **G1 / G2**: break the thing each widened assertion guards and confirm a *named failed
   assertion*, not a green run and not a CRASH.

Re-audit (targeted) after remediation: re-run the lenses that surfaced fixed findings --
**L1, L2, L3, L4, L5, L6, L7, L8, L9, L10, L11**. Because every lens has at least one open finding
in this plan, round 5 must be a **full** round; a partial round cannot satisfy the convergence gate.

## Post-Remediation Closure

The cross-round ledger at
`SRD/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl` is the authoritative record;
`findings-ledger.md` is a deterministic render produced by `edm-state render-ledger` and must not be
hand-edited. After remediation, re-run the audit round so each fixed finding is verified against the
tree rather than against the commit message, and let the synthesizer set `resolved_round` -- do not
mark a finding fixed in the ledger by hand.
