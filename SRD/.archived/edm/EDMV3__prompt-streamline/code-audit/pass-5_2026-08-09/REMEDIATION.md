# Code Audit Remediation Plan: EDMV3 prompt-streamline (Round 5)

## Context

- Audit date: 2026-08-09
- Round: 5 of the EDMV3 prompt-streamline code audit
- Round type: **full** (all 11 lenses ran; see `lenses-run.txt`)
- Audited scope: `plugins/edm/**` in full (bin, bin/tests, evals, hooks, docs, skills, agents),
  repository-root `CLAUDE.md`, `.gitlab-ci.yml`, `.gitignore`, and
  `SRD/edm/EDMV3__prompt-streamline/**`
- Branch: `edm/edmv3-prompt-streamline`
- SRD: `/Users/darryl.porter/projects/marketplace/SRD/edm/EDMV3__prompt-streamline/srd.md`
- Ticket pack: `/Users/darryl.porter/projects/marketplace/SRD/edm/EDMV3__prompt-streamline/tickets/`
- Ledger: `/Users/darryl.porter/projects/marketplace/SRD/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl`
- Deployment target: local (plugin distribution repository; no runtime service)

### Test-suite status (resolves L4's stated concern)

L4 reported suite greenness as **NOT CONFIRMED** because that lens had no Bash tool and could
only re-run the highest-risk repository-wide scans through Grep. That gap is closed out of band:
**the orchestrator executed the full aggregator immediately before this synthesis was requested
and it was 100 percent green -- 1857 assertions passed, 0 failed, across all 7 suites.** The
round-5 convergence decision below therefore rests on an executed run, not on a static sweep.
Recorded in the ledger as `CA-331 (NOTED)` so round 6 does not re-raise it.

### Ledger render is stale

L1, L2 and several other lenses independently noted that `findings-ledger.md` had not been
re-rendered since Wave 8 merged, so all 53 previously-remediated entries still read `open` in the
markdown render. This synthesis used `findings-ledger.jsonl` as authoritative throughout and did
not write the markdown. Run `plugins/edm/bin/edm-state render-ledger` after this file lands.

### What this round looked like

Wave 8 closed a large amount of real work: **32 ledger entries closed this round**, including
9 of round 4's P1 entries. The dominant new pattern is that **Wave 8's own remediations produced
the round's most serious findings**: the headline P1 (G1) is a regression introduced by CA-253's
fix, G3 and G44 are residuals of CA-186's fix, G12 is a guard written for CA-261 that turned out
to be a no-op, and G13 is a citation invalidated by the same commit that corrected it. Six of the
nine P1 entries either were introduced by, or survived, a round-4 remediation.

---

## Findings Summary

51 open findings: 0 P0, 9 P1, 42 P2. Sorted by severity, then by corroborating lens count.

| #   | Sev | CA ID  | Lens(es) | Component | Issue |
|-----|-----|--------|----------|-----------|-------|
| G1  | P1  | CA-298 | L1+L2+L3+L7+L8+L10 | plugins/edm/hooks/hooks.json:19 | CA-253's exit-2 conversion blocks on ANY gate-check failure, not only a refusal |
| G2  | P1  | CA-037 | L4+L7+L10 | plugins/edm/bin/tests/_harness.sh:228 | assert_tree_absent's control is a second independent literal; 16 sites tautological, 10 unconverted |
| G3  | P1  | CA-186 | L1+L3+L8 | plugins/edm/hooks/hooks.json:86 | srd_root values `.`, `./`, `..` and repo-root-absolute still fail open silently |
| G4  | P1  | CA-036 | L3+L4 | plugins/edm/bin/tests/wave7-smoke.sh:5408 | errexit tripwire's `guarded` flag is lexical, blind to ~850 lines (13%) of the suite |
| G5  | P1  | CA-302 | L6+L9 | plugins/edm/CHANGELOG.md:236 | G16 raised sample counts to 20; CHANGELOG says unchanged, T67 AC5/AC14 unreproducible |
| G6  | P1  | CA-193 | L11 | plugins/edm/skills/code-audit/SKILL.md:79 | Step 8a validates JSONL count not schema, and a second spawn site bypasses it |
| G7  | P1  | CA-299 | L9 | SRD/.../srd.md:4076 | CA-254's SRD half never swept; SRD and ticket pack now assert opposite contracts |
| G8  | P1  | CA-300 | L9 | SRD/.../tickets/epics/02:307 | T07 AC5 requires 3 prototype sites; tree has 2 and the AC's own test asserts 2 |
| G9  | P1  | CA-301 | L9 | SRD/.../tickets/epics/03:262 | T21 AC5's second verify half returns 10 where it requires 1; permanently failing |
| G10 | P2  | CA-251 | L1+L3+L8 | plugins/edm/bin/edm-state:3507 | pgrep candidate selection compiles an unvalidated ERE; mv-aside window has a third outcome |
| G11 | P2  | CA-246 | L2+L3+L11 | plugins/edm/bin/edm-state:3602 | last_cmd has two consumers and zero producers (third round) |
| G12 | P2  | CA-261 | L1+L2+L3 | plugins/edm/bin/edm-state:2837 | --calibrate guard tests non-null but init seeds the string "Unknown"; guard is a no-op |
| G13 | P2  | CA-268 | L6+L7+L8 | plugins/edm/bin/edm-state:627 | citation corrected to :124 re-staled to :127 by its own fix; 2 siblings also wrong |
| G14 | P2  | CA-309 | L2+L7+L10 | plugins/edm/bin/tests/timing.sh:326 | --all-lint is the last hand-rolled loop; header claims universal coverage; dead default at :327 |
| G15 | P2  | CA-256 | L3+L5 | plugins/edm/bin/tests/wave7-smoke.sh:5350 | CA-148 enumeration still lists 5 names; sweeps untested; unquoted word-splittable glob |
| G16 | P2  | CA-304 | L1+L3 | plugins/edm/bin/edm-state:3119 | migrate-path: false CA-169 exception rationale, and rollback rename holds no lock |
| G17 | P2  | CA-305 | L3+L8 | plugins/edm/bin/edm-state:1076 | flock timeout marker: no fallback when unwritable; predictable path, truncating redirect |
| G18 | P2  | CA-306 | L3+L6 | plugins/edm/bin/edm-state:594 | _EDM_TRAP_DEPTH docs wrong in two places after CA-257's fix |
| G19 | P2  | CA-308 | L2+L11 | plugins/edm/skills/plan/SKILL.md:53 | current_step vocabulary 2..6 has no producer; resume-to-phase-N unreachable |
| G20 | P2  | CA-049 | L7 | plugins/edm/bin/tests/_harness.sh:6 | two _harness.sh sourcing shapes; fallback convention split across seven suites |
| G21 | P2  | CA-074 | L7 | plugins/edm/bin/edm-validate-prefix:26 | die() is three shapes across twelve scripts, two default codes, untested |
| G22 | P2  | CA-168 | L6 | plugins/edm/docs/audit-patterns/SOURCES.md:19 | sixth sibling still attributes auto-population to the orchestrator; nothing populates it |
| G23 | P2  | CA-195 | L11 | plugins/edm/bin/tests/wave7-smoke.sh:5777 | tripwire needle widened, scope still a hardcoded 19-file enumeration |
| G24 | P2  | CA-233 | L8 | .gitlab-ci.yml:226 | shellcheck excludes only *.txt; in-suite twin excludes only *.awk |
| G25 | P2  | CA-242 | L9 | SRD/.../tickets/epics/11:641 | no AC covers the bin/ script-row list, so the table can go stale unseen |
| G26 | P2  | CA-247 | L11 | plugins/edm/bin/edm-state:4280 | cmd_lint has zero callers; architecture.md:631 citation 250 lines off |
| G27 | P2  | CA-262 | L4 | plugins/edm/bin/tests/wave7-smoke.sh:4214 | positive-p95 regex needs a nonzero digit on perl-less images; G16 halved pass odds |
| G28 | P2  | CA-263 | L4 | plugins/edm/bin/tests/wave7-smoke.sh:4902 | integer routed through a substring matcher; expected 0 matches 10/20/30/100 |
| G29 | P2  | CA-264 | L5 | plugins/edm/bin/tests/wave7-smoke.sh:5120 | line-cap probe fabricates a session JSONL under the real $HOME, outside the trap |
| G30 | P2  | CA-275 | L9 | plugins/edm/CLAUDE.md | CLAUDE.md knob note never added; hook conversion and git-lock-check rewrite unrecorded |
| G31 | P2  | CA-279 | L10 | plugins/edm/hooks/hooks.json:23 | five prompt hooks reimplement the gate mapping in prose, now contradicting the binary |
| G32 | P2  | CA-303 | L1 | plugins/edm/bin/edm-state:3406 | find -mmin rounds up on BSD/macOS, truncates on GNU; bucket and gate diverge a full minute |
| G33 | P2  | CA-307 | L2 | plugins/edm/bin/tests/wave7-smoke.sh:6025 | assertion label still claims to check the deleted _print_literal |
| G34 | P2  | CA-310 | L10 | plugins/edm/bin/tests/timing.sh:158 | --subcommands enumerates one list twice with no default arm |
| G35 | P2  | CA-311 | L4 | plugins/edm/bin/tests/timing.sh:90 | G16/G31's timing.sh fixes have zero covering assertions; awk fallback unexercised |
| G36 | P2  | CA-312 | L4 | plugins/edm/bin/tests/wave6-smoke.sh:210 | gate-suppression assertions prove presence, not exclusivity |
| G37 | P2  | CA-313 | L4 | plugins/edm/bin/tests/wave7-smoke.sh:4288 | CA-271's terminator fix is load-bearing on real content and has no firing test |
| G38 | P2  | CA-314 | L5 | plugins/edm/README.md | plugin runtime files are gitignored only in this repo; edm-state:1057's claim is false off it |
| G39 | P2  | CA-315 | L6 | plugins/edm/bin/edm-state:415 | five stale in-code citations and rationales, no durability guard on the class |
| G40 | P2  | CA-316 | L6 | plugins/edm/CLAUDE.md:847 | schema_version >= 2 claim outdated; evals allow-list derivation does not reproduce |
| G41 | P2  | CA-317 | L7 | .gitlab-ci.yml:164 | three jobs print no job-named failure line; FAIL vs FAILED divergence |
| G42 | P2  | CA-318 | L7 | plugins/edm/bin/edm-state:1127 | two stale-lock reclaimers take opposite fail-safe directions |
| G43 | P2  | CA-319 | L8 | .gitlab-ci.yml:630 | unpinned npm install with install scripts in the one secret-bearing job |
| G44 | P2  | CA-320 | L8 | plugins/edm/hooks/hooks.json:86 | existence guard resolves against hook cwd, not repo root; noisy in non-EDM projects |
| G45 | P2  | CA-321 | L9 | SRD/.../tickets/epics/11:669 | three citations authored the same day as the fix are already wrong |
| G46 | P2  | CA-322 | L9 | SRD/.../tickets/epics/02:316 | T07 AC6 requires two call sites; one exists, comment promises the second |
| G47 | P2  | CA-323 | L9 | SRD/.../tickets/epics/11:465 | T64 AC11 verifies a non-empty scores.json against a directory holding only README.md |
| G48 | P2  | CA-324 | L9 | SRD/.../tickets/epics/06:415 | D41 re-adopted a verification method CHANGELOG.md:75-76 declared invalid (4 sites) |
| G49 | P2  | CA-325 | L9 | SRD/.../tickets/epics/04:524 | T28's count returns 5 but 3 of 5 are comments, so the stated semantics is false |
| G50 | P2  | CA-326 | L10 | plugins/edm/bin/tests/wave7-smoke.sh:4380 | freshness guard reimplemented inline in the same block that calls the helper |
| G51 | P2  | CA-327 | L10 | plugins/edm/bin/edm-lint-artifacts:297 | per-class violation loop is a 4x copy-pasted block; already caused P1 CA-008 |

---

## Detailed Findings (P1)

### G1 (P1, CA-298, lenses L1 + L2 + L3 + L7 + L8 + L10): hook exit-2 conversion over-blocks

**Six independent lenses found this. It is the round's headline finding and the highest-confidence
signal in the ledger.** It was introduced by round 4's own CA-253 remediation.

**Problem**: all five UserPromptExpansion command hooks (`hooks.json:19`, `:32`, `:45`, `:58`,
`:71`) now run `edm-state gate-check ... || exit 2`, which treats **every** non-zero gate-check
status as a gate refusal. Only one of gate-check's non-zero paths actually is one:

- a missing state file (`read_state` dies at `edm-state:536`) now hard-blocks
- a missing `jq` (`require_jq` dies) now hard-blocks
- a transient lock timeout on a legacy initiative now hard-blocks

This is reachable with no user error under the supported `commit_state_file=false` configuration,
where a fresh clone legitimately has no state file, so every gated phase skill hard-blocks on
first invocation with an opaque diagnostic. It is also the outlier in its own file: every other
hook degrades to exit 0 when a dependency is missing, and the PreToolUse hook already models the
correct idiom. Worse, the two enforcement layers for the same condition now disagree **in
writing** -- all five sibling prompt hook bodies (`:23`, `:36`, `:49`, `:62`, `:75`) still
instruct that expansion should be allowed when the state file does not exist because that is a
first invocation. CA-253 did not merely make that clause unreachable; it made it actively false.

Invisible to the suite because the only coverage is a static grep of the hook bodies that never
executes one.

**Fix**:
1. In each of the five command hook bodies, insert a resolvability probe before the gate check,
   mirroring the PreToolUse hook's own idiom:
   `edm-state resolve-dir "$prefix" >/dev/null 2>&1 || exit 0` immediately before the
   `gate-check ... || exit 2` line. Alternatively (preferred if you are already in `edm-state`),
   give `cmd_gate_check` a dedicated refusal status so setup errors and refusals are
   distinguishable, and have the hooks convert only that status to exit 2.
2. Pick ONE direction for both halves of the family and make the five prompt bodies match:
   if blocking is correct, delete the first-invocation allowance from all five; if allowing is
   correct, keep the probe from step 1. Do not leave the prose saying one thing and the command
   doing the other.
3. Replace the static grep in `wave7-smoke.sh` with an **executing** case that invokes a hook
   body against a never-init'd prefix and asserts both halves agree.

**Verification**: `jq empty plugins/edm/hooks/hooks.json`; run the new executing case; manually
confirm a fresh clone with `commit_state_file=false` expands a gated phase skill prompt.

**Files affected**: `plugins/edm/hooks/hooks.json`, `plugins/edm/bin/tests/wave7-smoke.sh`,
possibly `plugins/edm/bin/edm-state` (cmd_gate_check).

**Remediate with**: G3, G44 and G31 -- all four are the same twenty lines of the same hook. The
change-control half (no CHANGELOG entry, no CLAUDE.md exit-code contract row) is G30.

---

### G2 (P1, CA-037, lenses L4 + L7 + L10): third pass -- the control is still tautological

**Problem**: `_harness.sh:243-262`'s `assert_tree_absent` genuinely closed the path-existence half
(break test 3a: a broken scan target fails by name). But **the control needle is a second literal
independent of the real scan's own pattern**. Break test 3b -- typo the real scan's pattern only,
leaving the seeded scratch file's needle correct -- still **passes at all 16 converted sites**,
while `_harness.sh:228-232`'s docstring claims exactly that cannot happen.

L10 measured the sweep's breadth: it keyed on the **helper name**, so ten hand-rolled copies of
the original tautological shape survive across `wave6-smoke.sh` and `wave7-smoke.sh`, two of them
inside the same ticket blocks whose siblings were converted (`wave6:2479` four lines below the
converted `:2469`; `wave7:1335` twenty-five lines above the converted `:1363`/`:1368`). Each
surviving copy still carries a `CA-037: positive control` comment, presenting itself as the
remediated shape -- which is how an eleventh site gets copied from the wrong template.

L7 adds the last production caller of the older `assert_absent_with_control` at `wave7:185`, which
retains a swallowed-exit-code haystack and no scan-target-existence assertion. L11 corroborates
the class at `wave7:5812` (the `edm-audit-test-quality` leg of the G5/G14 tripwire has no positive
control and cats with stderr discarded).

**Fix**:
1. Use ONE literal for both the real scan and the control needle -- pass the pattern once and
   derive both arms from it.
2. Route the control through a **real scan over a seeded scratch tree via the identical
   pipeline**. Templates already exist and should be copied: `wave7:4345-4364`, `:910`, `:1172`,
   `:3951`, `:4010`.
3. Correct `_harness.sh:228-232`'s docstring, which currently asserts the opposite.
4. Convert the ten hand-rolled sites and **delete their `CA-037: positive control` comments** as
   each is converted.
5. Convert `wave7:185` to `assert_tree_absent`; record that `assert_absent_with_control` then has
   zero production callers.
6. Add a tripwire banning the hand-rolled shape outside `harness-smoke.sh`, which legitimately
   self-tests the older helper.

**Verification**: perform break test 3b by hand -- typo the real scan's pattern at one converted
site and confirm the assertion now FAILS. Then `plugins/edm/bin/tests/run-all.sh`.

**Files affected**: `plugins/edm/bin/tests/_harness.sh`,
`plugins/edm/bin/tests/wave7-smoke.sh`, `plugins/edm/bin/tests/wave6-smoke.sh`.

---

### G3 (P1, CA-186, lenses L1 + L3 + L8): four srd_root values still fail open silently

**Problem**: both round-4 residuals are genuinely closed (the multi-dot-slash and trailing-dot
values close with executing coverage, an absolute value is detected, trailing slashes are stripped
in a loop). A **new set of values in the same fail-open class survives**:

- `srd_root="."` -- survives normalization, is not absolute, and the awk matcher compares against
  a literal `./` prefix git never emits from `--name-only`, so `prefixes` is empty and the hook
  silently exits 0
- `srd_root="./"` -- reduces to empty and takes the same silent path
- `srd_root=".."`
- an absolute srd_root equal to the repository root, which **the fix's own relativization arm
  manufactures into `.`** -- and that relativization arm has zero test coverage, because only
  non-relativizable absolutes are exercised

L8 re-derived the space character by character and confirms every other adversarial value
(backslash, whitespace, embedded newline, glob metacharacters, `//`, `/./`) hits a named
diagnostic. None of the four surviving values appears in `wave7-smoke.sh`'s eight-shape invariant
list, so the round-4 test's own "none of the eight shapes exits 0 silently" invariant is provably
violated by values it does not enumerate.

**Severity note**: all three corroborating lenses rated this residual P2 this round. This
synthesis **holds it at P1** because the round-4 P1 rationale -- a security control that silently
fails open, where the operator cannot distinguish enforced from unenforced -- is unchanged in
substance and only rotated in enumeration. Downgrade in round 6 once the remaining values are
refused loudly.

**Fix**: refuse loudly (exit 1, which IS surfaced in the transcript) whenever the resolved root is
`.`, `..`, empty, or contains a `..` component; or treat those as "no root prefix, scan the whole
path" rather than falling through to exit 0. Extend the test's shape list from eight values to
twelve, including one that exercises the relativization arm.

**Verification**: run the extended shape list; assert no shape reaches exit 0 without a
diagnostic on a channel the operator sees.

**Files affected**: `plugins/edm/hooks/hooks.json`, `plugins/edm/bin/tests/wave7-smoke.sh`.

**Remediate with**: G1, G44, G31.

---

### G4 (P1, CA-036, lenses L3 + L4): the errexit tripwire is blind to 13 percent of the suite

**Problem**: the shape axis is closed and verified discriminating (G5's widened regexes yield
exactly 6 hits from 6 shapes under an exact `-eq` comparison; the seed-zero-then-or-capture
conversions landed; L3's SIGINT-case half is fully closed with every internal failure path
fail-guarded). The **file axis is broken**.

The detector's `guarded` flag is **lexical**: `set +e` sets it, `set -e` clears it. But this
file's dominant subshell-probe idiom -- an assignment from a command substitution that opens with
`set +e` and a trap reset -- never has a matching `set -e`, because the scope closes with the
subshell. Eleven unpaired `set +e` lines therefore create two blind regions:

- `:4543-4988` (446 lines)
- `:5953-6356` (404 lines)

Together about 850 lines, 13 percent of the suite -- and the second region is **exactly the lock
and trap block CA-036's L3 half was filed against**. Traced: reintroducing the exact CA-036 shape
inside either region passes silently; outside them it is caught correctly. No live hazard today
(all twelve real bare-capture sites verified correctly bracketed), but the tripwire cannot see a
reintroduction precisely where one is most likely.

L3 adds one further **live** site at a shape the tripwire structurally cannot see:
`wave6-smoke.sh:2517-2522`, the tree's only concurrency test, reaps two backgrounded
`edm-state set` calls with a bare `wait` under `set -euo pipefail` and no exit-code capture. If
either loses the lock-timeout race the case exists to exercise, the suite CRASHes at `:2521` and
loses roughly 1600 lines of later assertions instead of reporting a named T64 AC8 failure.

**Fix**:
1. Close the bracket at the **subshell boundary** rather than lexically: clear `guarded` on the
   line that closes the command substitution, not on a lexical `set -e`.
2. Add a seventh positive-control fragment placing a hazard after an unpaired `set +e`, and raise
   the expected hit count from 6 to 7.
3. Convert `wave6-smoke.sh:2517-2522` to the seed-zero-then-capture form for both pids
   (`ec=0; wait "$pid" || ec=$?`), asserting both statuses as named assertions.

**Verification**: plant the CA-036 shape inside `:4543-4988` and confirm the tripwire now fires;
confirm the expected count is 7 and the suite is green.

**Files affected**: `plugins/edm/bin/tests/wave7-smoke.sh`,
`plugins/edm/bin/tests/wave6-smoke.sh`.

---

### G5 (P1, CA-302, lenses L6 + L9): T67's evidence is unreproducible and the CHANGELOG asserts the inverse

**Problem**: Wave 8's G16/CA-196 raised `timing.sh`'s p95 sample count from 3/5/10 to **20** in
every measuring mode, which changes what the emitted `p95_ms` means.
`CHANGELOG.md:236-240`'s CA-196 caveat still states the sample counts are 3/5/10 and
**unchanged**, and cross-references a `timing.sh` comment that now says the opposite. The
project's own record affirmatively asserts the inverse of the shipped harness.

The consequence is a broken exit criterion, not a stale sentence: **T67 AC14 (Should) requires
reproducible evidence**, and the T67 AC5 evidence figures at `CHANGELOG.md:223` cannot be
reproduced by any run of the current harness. CA-196's own prescription explicitly required a
`decisions.md` entry recording the choice, and no such entry exists -- deferral is not a
resolution state in this methodology.

**Fix**:
1. Re-run every timing mode against the shipped 20-sample harness.
2. Replace the T67 evidence figures at `CHANGELOG.md:223` (and the mirrored budget figures in
   `plugins/edm/CLAUDE.md` and the T67 AC rows) with the new measurements.
3. Rewrite the `CHANGELOG.md:236-240` caveat as a **result** rather than a deferral.
4. Add the `decisions.md` entry CA-196 required, naming T67 AC5 and AC14 with before/after text.

**Verification**: `plugins/edm/bin/tests/timing.sh` in each mode; confirm each published figure is
reproducible from a fresh run; confirm the new D-number resolves from both AC rows.

**Files affected**: `plugins/edm/CHANGELOG.md`, `plugins/edm/CLAUDE.md`,
`SRD/edm/EDMV3__prompt-streamline/tickets/epics/11-cross-cutting-delivery.md`,
`SRD/edm/EDMV3__prompt-streamline/tickets/decisions.md`.

**Sequencing**: land **after** G14 and G35 so the harness is final before the numbers are
re-recorded. Re-recording against a harness that is about to change again reproduces this finding.

---

### G6 (P1, CA-193, lens L11): the lens-JSONL contract is delivered but still unenforceable

Fifth consecutive recurrence. Single-lens, but retained at P1 because it is the mechanism that
determines whether any future round's ledger can be built from structured data at all.

**Problem**: the repository-side fix IS present and correct on disk -- `SKILL.md:225-246` is the
fenced launch template, the literal one-line JSONL schema sits at `:235` and the CA-130 fallback
clause at `:236-242`, both inside the fence, and the verbatim-copy requirement is stated twice at
`:72-77` and `:220-223`. Two mechanisms defeat it:

1. **Step 8a at `:79-92` validates COUNT, not SCHEMA.** It globs `lens-L*.jsonl` and compares the
   count against `|LENS_SET|`, so it cannot distinguish eleven correctly-schema'd files from
   eleven files carrying an invented schema. The `wave7-smoke.sh:5749-5752` tripwire asserts the
   four schema tokens exist somewhere in the **file**, not inside the fenced body -- so moving the
   schema back above the fence, the exact CA-193 regression, leaves all four assertions green.
2. **Step 8a is bypassable.** The operative spawn prompt lives in a different section:
   `:258-279`'s `## Synthesizer Phase` restates the spawn under "After all lens reports are
   written" with zero reference to step 8a or `LENS_SET`, and that precondition is satisfied by
   markdown-only reports -- precisely the pass-3 state CA-193 documents.

Delivery-layer evidence this round: the prompt delivered to L11 again carried the pointer form
only; the delivered agent definition was again a stale pre-CA-165 revision missing four on-disk
sections; and the schema survived only because this round's audit scope IS the repository holding
the plugin, so the lens could Read the on-disk definition. That recovery would not exist on an
installed-plugin run against an unrelated project. New measurable consequence: the stale delivered
definition also reverts CA-165's table format, and `score-artifacts.sh:473` counts prose rows by
the lens-prefixed ID pattern, so a report following the delivered template yields `md_count = 0`
and dimension 5 scores that lens 0 against a non-zero `jsonl_count` -- a false failure.

**Fix**:
1. Extend step 8a to validate **content**: `schema`, `lens`, `sev` and `status` keys present,
   `id` null; refuse on findings-ledger-shaped keys (`lenses`, `component`, `raised_round`).
2. Add one clause at `:259` cross-referencing step 8a's precondition, plus an assertion that the
   cross-reference cannot be dropped.
3. In `wave7-smoke.sh`, extract the fenced template **body** and assert the schema tokens appear
   within it, not merely somewhere in the file.

**Verification**: move the schema line above the fence and confirm the tripwire now fails; write
a ledger-shaped JSONL into a scratch pass directory and confirm step 8a refuses.

**Files affected**: `plugins/edm/skills/code-audit/SKILL.md`,
`plugins/edm/bin/tests/wave7-smoke.sh`.

---

### G7 (P1, CA-299, lens L9): CA-254's SRD half was never swept

**Problem**: Wave 8e amended T66 AC4 and T43 AC12 to assert the **absence** of the phrase
"four violation classes", and `wave7-smoke.sh:5475` asserts that absence and is green. But
`srd.md:4076`'s Must-Have acceptance criterion for EDMV3-97 still mandates the phrase's
**presence** in `plugins/edm/CLAUDE.md`'s bin/ row. The SRD and the ticket pack now state
opposite contracts for the same requirement, and since the tree satisfies the ticket pack, the
governing document is the one that is false. Second consecutive round in which an audit
remediation amended a ticket AC without sweeping the SRD requirement that AC implements.

**Fix**: amend `srd.md:4076` to the shipped contract -- the bin/ row defers to `--help`, and
`--help` enumerates all seven emitted violation classes -- and record the rework in
`decisions.md` with before/after text per `tickets/README.md:64-65`.

**Verification**: `grep -n 'four violation classes' SRD/edm/EDMV3__prompt-streamline/srd.md`
returns nothing; the new D-number resolves from the amended AC.

**Files affected**: `SRD/edm/EDMV3__prompt-streamline/srd.md`,
`SRD/edm/EDMV3__prompt-streamline/tickets/decisions.md`.

---

### G8 (P1, CA-300, lens L9): T07 AC5 requires three sites; the tree has two and the test agrees with the tree

**Problem**: T07 AC5 (Must, `epics/02:307`) requires exactly three `prototype)` case sites in
`bin/edm-state` and names `cmd_archive`'s waiver as the third. The waiver was consolidated into
`convergence_exempt()` and the tree has **two**. The AC's own second verify half, shipped as
`wave6-smoke.sh:246`, asserts exactly **two** and is green -- so a passing suite proves a
Must-Have acceptance criterion false, with no `decisions.md` record of the consolidation.
CA-033's and CA-254's class at a third site.

**Fix**: amend T07 AC5 to the shipped two-site contract, name the `convergence_exempt()`
consolidation and the decision that produced it, point the verify at `wave6-smoke.sh:246`, and
record the rework in `decisions.md`.

**Verification**: run the AC's verify as written and confirm it passes; confirm the D-number
resolves.

**Files affected**: `SRD/edm/EDMV3__prompt-streamline/tickets/epics/02-enforcement-kernel.md`,
`SRD/edm/EDMV3__prompt-streamline/tickets/decisions.md`.

---

### G9 (P1, CA-301, lens L9): T21 AC5's second verify half is permanently failing

**Problem**: T21 AC5 (Must, `epics/03:262`), second verify half, requires
`grep -c 'bin/tests/' .gitlab-ci.yml` to return 1. It returns **10**, after CA-162's lint-glob
widening in round 3 and Wave 8's G21/CA-233 edit in the same loops. The AC's substance still
holds (no wave-suite job name appears in the pipeline), but the command as written is permanently
failing and unasserted, so a reader running the pack's own verify concludes a Must-Have criterion
is unmet.

**Fix**: re-express the second half as a count of wave-suite **job names** rather than of the
`bin/tests/` path token, or pin the expected count to the shipped value with a comment naming why
it moves when a lint glob is widened. Record the rework in `decisions.md`.

**Verification**: run both verify halves as written; both pass. Widen a lint glob in a scratch
branch and confirm the amended verify does not spuriously fail.

**Files affected**: `SRD/edm/EDMV3__prompt-streamline/tickets/epics/03-ci-and-fixture-eval.md`,
`SRD/edm/EDMV3__prompt-streamline/tickets/decisions.md`.

---

## P2 Findings (42)

Multi-lens P2 entries are listed first; they carry the same corroboration weight as the P1s and
should be treated as the highest-value P2 work.

| #   | CA ID  | Lens(es) | Component | Fix |
|-----|--------|----------|-----------|-----|
| G10 | CA-251 | L1+L3+L8 | bin/edm-state:3507, :3531 | Distinguish pgrep's exit codes (1 = no candidates, >1 = undetermined -> refuse), or drop the ERE by filtering `ps -e -o pid=,args=` through `grep -F`. Re-assert the age gate immediately before the mv-aside and refuse if the lock now reads younger; soften the comment to name the residual. Land the backdated-lock executing test. |
| G11 | CA-246 | L2+L3+L11 | bin/edm-state:3602, :4881 | `estimated_size` half is FIXED (producer at plan/SKILL.md:197). For `last_cmd`: add a producer at the phase skills' Step 0 preflight, or delete both renderer lines and the field. Documenting it a third round is not a resolution state. |
| G12 | CA-261 | L1+L2+L3 | bin/edm-state:2837 | Derive the guard from the SAME jq expression the renderer uses, with an explicit `!= "Unknown"` exclusion, then count the `phase_durations` rows the render groups. Correct the comment (it states the inverse of the shipped predicate) and the second fallback's message at :2860. |
| G13 | CA-268 | L6+L7+L8 | bin/edm-state:627 | Trap half is FIXED. Re-point three exemplar citations: `edm-check-grants:124` -> `:127`, `_harness.sh:104` -> `:110`, `_harness.sh:76` -> `:81-82`. Adopt the by-name form CA-095 uses so insertions cannot re-stale them. Sequence in the final sweep wave. |
| G14 | CA-309 | L2+L7+L10 | bin/tests/timing.sh:326-331 | Route `--all-lint` through `_measure_p95 1 ms -- ...` as `--phase-complete` does, keeping the `duration_ms=` key (deliberate single-sample budget mode). Delete the dead `${actual_initiatives:-0}` default at :327. Narrow the :72-74 header to claim only what is covered. |
| G15 | CA-256 | L3+L5 | bin/edm-state:2722, :3119; wave7-smoke.sh:5350 | Quote the variable and loop the marker glob with a per-file existence test (quoting alone would make both sweeps inert). Add `${lockfile}.timeout.$$` to the CA-148 enumeration using the source's own formula. Add a case planting a timeout marker and asserting the archive sweep removes it. |
| G16 | CA-304 | L1+L3 | bin/edm-state:3119, :3179 | At :3119 remove only `.lockd` and the timeout marker, leaving `.lock` per CA-169, or move the `.lock` removal after `with_state_lock` returns; replace the false same-exception clause. Wrap the rollback rename at :3179 in a fresh `with_state_lock`, and remove the created product directory on that branch. |
| G17 | CA-305 | L3+L8 | bin/edm-state:1076-1085 | Derive the marker under `TMPDIR`; create it with `mkdir` (atomic, fails on any existing name) instead of a truncating symlink-following redirect; add a secondary diagnostic arm so exit 99 with no marker still names the timeout. |
| G18 | CA-306 | L3+L6 | bin/edm-state:594, :1038-1042 | Correct :594 to say the depth is armed around BOTH branches. Rewrite :1038-1042 to state the guard detects ANY nesting regardless of lockbase (it is process-global), or key it on the lockbase if cross-lockbase nesting should stay legal. |
| G19 | CA-308 | L2+L11 | skills/plan/SKILL.md:53-55 | Either add the Step 0 producer instruction to implement/code-audit/verify-runtime so values 2..6 have producers, or narrow the published vocabulary to the value actually written and delete the substitution claim. |
| G20 | CA-049 | L7 | bin/tests/_harness.sh:6; wave3:12, wave4a:12 | Sweep wave3 and wave4a to the documented `source "${SCRIPT_DIR}/_harness.sh"` form; pick one `${BASH_SOURCE[0]:-$0}` fallback convention and apply it to all seven suites; update the docstring example. |
| G21 | CA-074 | L7 | bin/edm-validate-prefix:26 and 11 siblings | Standardize on the two-argument `die()` form defaulting to exit 2 (the majority, rationale already at edm-validate-prefix:22-26). Add one smoke assertion matching the canonical shape across `bin/*` and `evals/*.sh`. |
| G22 | CA-168 | L6 | docs/audit-patterns/SOURCES.md:19 | Five named headers are FIXED. Correct SOURCES.md:19 to name the real producer, or state plainly that the file is maintained by hand (nothing auto-populates it). |
| G23 | CA-195 | L11 | bin/tests/wave7-smoke.sh:5777 | Downgraded P1 -> P2 (substantive sweep complete). Replace the two hardcoded 19-file enumerations with one tree-wide scan over `skills/*/SKILL.md` and `agents/*.md` for both needles, with a three-entry exception list. Give the edm-audit-test-quality leg at :5812 a positive control. |
| G24 | CA-233 | L8 | .gitlab-ci.yml:226; wave7-smoke.sh:948-950 | Two of three halves FIXED. Add `*.awk` to `lint:shellcheck`'s exclusion; add `*.txt` to the in-suite twin; add one assertion that all three loops share the same extension set. |
| G25 | CA-242 | L9 | tickets/epics/11:641 | Extend T66 AC3 or AC4 with a verify that counts the bin/ table rows against the shipped script set, and add the matching smoke assertion so the count is enforced, not asserted in prose. |
| G26 | CA-247 | L11 | bin/edm-state:4280; architecture.md:631 | Decide `cmd_lint`: route the PreToolUse hook through it, or drop the wrapper and its 40-subcommand table row. Re-point architecture.md:631 BY NAME (function is at :3426, cited as :3177-3202). |
| G27 | CA-262 | L4 | bin/tests/wave7-smoke.sh:4214 | Relax the regex to require a digit string with a documented resolution caveat, or key the strict non-zero form off a `command -v perl` probe. Add a comment naming the rank-versus-resolution coupling (G16's N=20 moved the selected rank from max to second-largest, halving pass odds). |
| G28 | CA-263 | L4 | wave7-smoke.sh:4902, :6241 | Replace `check "..." "0" "$var"` with the suite's numeric idiom `[[ "$var" -eq 0 ]]` at both sites (substring match: 0 matches 10/20/30/100; 33 matches 133/233/330). |
| G29 | CA-264 | L5 | wave7-smoke.sh:5117-5131 | Export `HOME` to a scratch directory inside the subshell before the derivation, and replace the hand-rolled path with `session_dir_for_test_cwd`, matching the six wave6 sites. |
| G30 | CA-275 | L9 | plugins/edm/CLAUDE.md | One commit: add the missing CLAUDE.md EDM_RUN_ALL / EDM_EVAL knob-family note; add CHANGELOG entries for the five-hook exit-code conversion and the git-lock-check rewrite; add a CLAUDE.md hooks-table row stating the exit-code contract G1 settles. |
| G31 | CA-279 | L10 | hooks/hooks.json:23 | Route the five prompt bodies through `edm-state gate-check` and let the binary produce the message, rather than restating the phase-to-gate mapping in prose without its mode and skipped-phase refinements. Fix in the same pass as G1. |
| G32 | CA-303 | L1 | bin/edm-state:3406, gate at :3455 | Compute the lock age numerically ONCE (`stat -f %m` / `stat -c %Y` in a labelled platform branch, or a `touch -r` reference file with `! -newer`) and derive both the reported bucket and the gate from it. Correct the docstring: the FLAG is portable, the rounding is not. |
| G33 | CA-307 | L2 | wave7-smoke.sh:6025-6026 | Re-word the label to describe what the needle actually checks, and add a real `check_absent` for the `_print_literal() {` definition. |
| G34 | CA-310 | L10 | bin/tests/timing.sh:158 | Drive the loop from one name-plus-arguments list so the two enumerations cannot diverge, or add a loud `*)` arm that exits non-zero naming the unhandled subcommand. |
| G35 | CA-311 | L4 | bin/tests/timing.sh:90 | Shadow `command -v perl` (idiom at wave7:4558) to force the awk fallback and assert `_now` still works; add two `_p95` argument-vector assertions pinning the nearest-rank index; assert the shipped `_P95_SAMPLE_COUNT` so a silent revert fails. |
| G36 | CA-312 | L4 | wave6-smoke.sh:210, :213 | Assert the exact joined gate string at both sites, as the correct sibling at :203 does, so an extra gate fails rather than satisfies. |
| G37 | CA-313 | L4 | wave7-smoke.sh:4288 | Add one assertion that extracts a job body spanning `.gitlab-ci.yml:198` and asserts a post-198 token is present in the extracted body. |
| G38 | CA-314 | L5 | plugins/edm/README.md; bin/edm-init:158-161 | Add a copy-pasteable consumer `.gitignore` block to README.md (`.edm-state.json.bak`, `.edm-state.json.tmp.*`, `**/.edm-state.lock*`, `**/*.md.tmp.*`). Make edm-init write that full set into the per-initiative `.gitignore` unconditionally, adding `.edm-state.json` only when `commit_state_file != true`. Correct edm-state:1057-1058's false justification. |
| G39 | CA-315 | L6 | bin/edm-state:415 + 4 sites | Re-point five citations/rationales: run-eval.sh:212-214, wave7:983, wave6:3782, edm-state:415-416, run-all.sh:10-13. Prefer the by-name form. **Add the durability guard**: a smoke assertion or CI ban on new `<file>:<digits>` citations in comments, shaped like the sentinel-extractor and entity-walk bans. Without it this class recurs in round 6. |
| G40 | CA-316 | L6 | plugins/edm/CLAUDE.md:847; evals/README.md:84-91 | Correct :847 (CA-182 made the precheck unconditional; `schema_version >= 2` now gates only the degradation arm). Regenerate the evals allow-list derivation from the shipped string, or point at the single authoritative definition and delete the third formula in the code comment. |
| G41 | CA-317 | L7 | .gitlab-ci.yml:164 | Wrap `lint:artifacts`, `lint:grants` and `lint:vocabulary` so each prints a job-named FAILED line before exit 1. Standardize on one of FAIL / FAILED across every job. Add the job name at eval:nightly:652. Add one suite assertion pinning the convention. |
| G42 | CA-318 | L7 | bin/edm-state:1127 | Add an age gate to `with_state_lock`'s invalid-pidfile reclaim path so both reclaimers refuse in the undetermined case, or document why this case is exempt and cross-reference it from `cmd_git_lock_check`. |
| G43 | CA-319 | L8 | .gitlab-ci.yml:630 | Pin both `npm install` lines to explicit versions with the same refresh-procedure note the apk pins carry; add `--ignore-scripts` unless a postinstall is genuinely required; extend T67 AC11 to a weaker pass asserting version pinning on `allow_failure` jobs rather than exempting them. |
| G44 | CA-320 | L8 | hooks/hooks.json:86 | Resolve the existence test against `git rev-parse --show-toplevel`, not the hook's cwd. Refuse loudly only when srd_root was set EXPLICITLY; an unset default that does not exist means the project does not use EDM and must stay silent (this currently emits an error line on every commit in the marketplace's six other plugins). |
| G45 | CA-321 | L9 | tickets/epics/11:669 | Re-point three citations authored the same day as their fixes: T66 AC4's and T43 AC12's wave7-smoke.sh ranges for G9, and D38's Re-verification result (run-eval.sh:435/:500 -> :459/:524). Prefer by-name references. |
| G46 | CA-322 | L9 | tickets/epics/02:316 | Amend T07 AC6 to the one-call-site contract cross-referencing D35/CA-183; delete or rewrite the future-tense comment promising a second consumer; change the shipped test to count invocation sites rather than raw grep hits. |
| G47 | CA-323 | L9 | tickets/epics/11:465 | Relabel T64 AC11 as CA-272 relabelled its sibling (capture-when-a-baseline-exists, verify pointing at the capture procedure), or capture the baseline. Cross-reference D23. |
| G48 | CA-324 | L9 | tickets/epics/06:415 + 3 sites | Replace `git diff --stat is empty` with a tree-state assertion naming the shipped content at T43 AC12, T67 AC8, T64 AC10 and epics/03:180; add a decisions.md line stating the method is not acceptable for a tracked file's content. (T36 AC6 / T13 AC8 are deliberately excluded: historical per-MR claims.) |
| G49 | CA-325 | L9 | tickets/epics/04:524 | Change T28's verify to count invocation sites only, excluding comment lines, and restate the AC's semantics as the number of enforcing call sites (current 5 = 1 def + 1 use + 3 comments). |
| G50 | CA-326 | L10 | wave7-smoke.sh:4380-4389 | Delete the inline reimplementation of `_wave7_assert_shared_lint_fresh` and call the helper if a pre-block check is wanted; correct the docstring's every-reuse-site claim or make it true. |
| G51 | CA-327 | L10 | bin/edm-lint-artifacts:297 | Extract `_report_grep_hits <class> <file> <ignore-set> -- <grep-cmd...>` using process substitution (bash 3.2 safe, keeps `report_violation` out of a subshell) and route all four copy-pasted blocks through it. This duplication already produced P1 CA-008. |

---

## Convergence Statement

**Round 5 does NOT converge.**

| Metric | Value |
|---|---|
| Round type | full (11 of 11 lenses) |
| P0 open | 0 |
| **P1 open** | **9** |
| P2 open | 42 |
| Total open (blocking set) | 51 |
| Deferred (excluded from blocking set) | 0 |
| Closed this round (`resolved_round = 5`) | 32 |
| Total ledger entries | 332 |

The convergence gate requires a full round with **zero P0 and zero P1 open**. Nine P1 entries are
open (`CA-036`, `CA-037`, `CA-186`, `CA-193`, `CA-298`, `CA-299`, `CA-300`, `CA-301`, `CA-302`),
so the gate is refused. Four of the nine are carried forward from earlier rounds and five are new
this round.

Notes for the gate decision:

- The full suite is independently green (1857 passed, 0 failed, 7 suites), so nothing here is a
  broken build; every P1 is a correctness, enforcement or spec-consistency defect that a green
  suite cannot see. Four of the nine P1s are specifically findings the suite is structurally
  incapable of detecting (G1 static grep, G2 tautological control, G4 blind regions, G6 count-only
  gate).
- Two carried P1s were **downgraded** to P2 this round on lens verdict plus closure of their
  original justification: `CA-195` (substantive sweep complete, only the tripwire scope remains)
  and `CA-251` (the removal branch is reachable again). Both downgrades are recorded in the ledger
  with rationale.
- One carried P1 was **held at P1 against three lenses' P2 verdict**: `CA-186`/G3, because the
  round-4 P1 rationale (a security control that silently fails open) is unchanged in substance
  and only rotated in enumeration. If the reviewer disagrees, downgrading G3 leaves 8 P1s open and
  does not change the convergence outcome.
- Round 6 must be a **full round**. Fixes touch findings raised by all 11 lenses, so a partial
  re-audit could not satisfy the gate even if every P1 closed.

---

## Merged Multi-Lens Findings

Six defects were flagged by more than one lens and are recorded as single ledger entries rather
than duplicates. These are the highest-confidence findings of the round.

| CA ID | Lenses | What each lens saw |
|---|---|---|
| CA-298 (G1) | L1, L2, L3, L7, L8, L10 | L1/L8: exit-2 conversion treats setup errors as refusals. L2: the prompt hooks' first-invocation clause is now unreachable. L3: transient lock timeout hard-blocks. L7: the two enforcement layers disagree in writing. L10: two copies of one policy in one JSON object give opposite verdicts (CA-279 aggravated). |
| CA-037 (G2) | L4, L7, L10 | L4: the control needle is a second literal, so break test 3b passes at all 16 sites. L10: ten hand-rolled copies survive, still labelled as the remediated shape. L7: the last `assert_absent_with_control` caller keeps a swallowed-exit-code haystack. L11 corroborated at wave7:5812 (NOTED). |
| CA-186 (G3) | L1, L3, L8 | All three independently derived that `.`, `./`, `..` (and, per L8, a repo-root-absolute value via the fix's own relativization) reach exit 0 with no diagnostic on any channel. |
| CA-261 (G12) | L1, L2, L3 | All three independently found that the G30 guard tests `estimated_size != null` while `cmd_init` seeds the literal string `"Unknown"`, making the guard identical to the file count it replaced. L1 and L3 additionally traced the renderer's divergent predicate. |
| CA-268 (G13) | L6, L7, L8 | All three independently found that CA-268's own comment insertion pushed the `edm-check-grants` trap from :124 to :127, invalidating the citation the same commit corrected; L6 and L8 also traced the two `_harness.sh` siblings. |
| CA-036 (G4) | L3, L4 | L4: the tripwire's `guarded` flag is lexical, blinding it to ~850 lines including the exact block CA-036 was filed against. L3: a live instance at a shape the tripwire cannot see (`wave6:2517-2522`, bare `wait` under `set -e`). |
| CA-309 (G14) | L2, L7, L10 | L7/L10: `--all-lint` is the last unconverted hand-rolled loop and the header falsely claims universal coverage. L2: the adjacent dead zero-default at :327, the CA-140/CA-202/CA-260 class at a fourth site. |
| CA-304, CA-305, CA-306, CA-256, CA-302, CA-308, CA-246, CA-251 | 2-3 lenses each | See the P2 table and the ledger for the per-lens split. |

---

## Decisions / Non-Findings

These items were flagged by one or more lenses and determined **Not Actionable**. Future audits
must NOT re-investigate them. Recorded in the ledger as `CA-328` through `CA-332` plus the
standing `CA-282` to `CA-297` set.

1. **L1 `timing.sh:105` `_measure_p95` discards exit status** -- documented intentional at :92-96.
2. **L1/L2 perl-less resolution warning on every call** -- noise; CA-197's refusal protects figures.
3. **L1 `timing.sh` not discovered by run-all.sh** -- all constructs bash 3.2 legal today.
4. **L2 `_p95` index clamps unreachable** -- live defence; formula changed twice in two rounds.
5. **L2 `_measure_p95` arity guard cannot fire** -- same class as accepted CA-290 arity arm.
6. **L2 three call sites never read the samples out-variable** -- documented generic-helper shape.
7. **L2 signal-wrapper exit codes unreachable in run-eval.sh** -- deliberate per AC10; exit 4 first.
8. **L2 `assert_tree_absent`'s error arm is preempted** -- defensive in a loud-failure primitive.
9. **L2 `.gitlab-ci.yml:315` inline dead default** -- criterion 3; the line round 4 already drew.
10. **L3 second Ctrl-C during cleanup abandons cleanup** -- inherent to the CLEANUP_DONE latch.
11. **L3 `COMPLETE=true` precedes run.json's write** -- safe via CA-064; do not revert the coupling.
12. **L3 unchecked pidfile write at edm-state:1150** -- needs a failed small write; louder failures first.
13. **L4/L2 wave7:4214's pass branch is environmentally starved** -- routed to CA-262, not re-filed.
14. **L5 six traps omit HUP** -- all TMPDIR-only resources; standing CA-291.
15. **L5 timing.sh's six untrapped mktemp -d trees** -- TMPDIR-only, manual invocation; CA-170/171.
16. **L5 `.gitlab-ci.yml:432` LIST_FILE mktemp has no trap** -- runner-local and ephemeral.
17. **L5 evals/baseline README's --out target is untracked** -- artifacts are meant to be committed.
18. **L5 CA-169's flock file is never unlinked** -- correct by design; must not be "fixed".
19. **L5 `evals/runs/.gitignore` self-ignoring form** -- walked and verified correct.
20. **L6 stale-looking citations in agent Output-Format fences** -- template illustration, not claims.
21. **L6 `timing.sh:74` vs `:89` two denominators** -- approximating the same collapse, not false.
22. **L6 CHANGELOG:206's "eight budgets"** -- loose restatement of a 14-row table.
23. **L6 evals/README.md:46 names SIGINT/SIGTERM only** -- the operative claim is exact.
24. **L6 qc-audit.md:54's orchestrator attribution** -- EDMV2-seeded advice with its own provenance.
25. **L6 vocabulary-allowlist class ordering** -- cosmetic; the load-bearing constraint is removed.
26. **L7 five command hooks are byte-identical but for one token** -- JSON has no include mechanism.
27. **L7 commit-lint is the only srd_root normalizer** -- POSIX absorbs the difference in bin/.
28. **L7 flock 10s vs mkdir 5s acquire bounds** -- dispositioned NOTED by L3 in round 4 (CA-294).
29. **L7 round-scoped G-numbers collide across rounds** -- cosmetic; no runtime consequence.
30. **L8 lsof's `--` marker may be unsupported on old builds** -- routes to the safe pgrep fallback.
31. **L8 PID recycling onto $PPID and grandparent evasion** -- negligible; subsumed by G10's fix.
32. **L8 run-eval.sh's auth probe uses default permissions** -- fixed literal prompt; CA-086's position.
33. **L8 two developer-local absolute paths in CLAUDE.md** -- licence-verification provenance record.
34. **L8 `for p in $prefixes` unquoted** -- every value already passed a strict uppercase grep.
35. **L9 four allow_failure grep-count ACs are imprecise** -- no reachable wrong conclusion.
36. **L9 T36 AC6 / T13 AC8's `git diff --stat`** -- historical per-MR claims, not tree assertions.
37. **L10 `_lock_retry_or_die`'s dynamic-scoping mutation** -- documented, consistent with siblings.
38. **L10 `_unpack_token_fields`'s 3-line marshalling at both call sites** -- mechanical, not semantic.
39. **L10 CA-282 / CA-283 re-verified** -- no drift in either; standing NOTED.
40. **L10/L4 CA-281 option (b)** -- explicitly endorsed against revisiting; do not re-open.
41. **L11 plan/SKILL.md:60's bare flat path in an existence probe** -- extends CA-297's carve-out.
42. **L11 KillShell/BashOutput granted with no Bash grant** -- CA-179's accepted dead-grant surface.
43. **L11 wave7:129's mislabelled estimated_size assertion** -- no live consequence; G86 covers it.
44. **All 11 lenses: CA-130 reproduces (sixth consecutive round)** -- `Write` granted in frontmatter
    but absent from the delivered tool set; host-side, not a repository defect. All 22 artifacts
    this round were transcribed by the orchestrator. Note that G6's residual is the *repository*
    consequence of this, and IS actionable.

---

## Rollout Order

Six waves. Lanes within a wave own **disjoint file sets** and can run fully in parallel; waves are
sequential. Same structure as round 4's Wave 8a-8g.

### Wave 9a -- P1 defect fixes (3 parallel lanes)

| Lane | Files owned | Findings |
|---|---|---|
| 9a-1 | `plugins/edm/hooks/hooks.json` | G1 (CA-298), G3 (CA-186), G44 (CA-320), G31 (CA-279) |
| 9a-2 | `SRD/.../srd.md`, `tickets/epics/02`, `tickets/epics/03`, `tickets/decisions.md` | G7 (CA-299), G8 (CA-300), G9 (CA-301), G46 (CA-322) |
| 9a-3 | `bin/tests/_harness.sh`, `bin/tests/wave7-smoke.sh`, `bin/tests/wave6-smoke.sh` | G2 (CA-037), G4 (CA-036) |

9a-1 is the highest-value single lane in the plan: four findings, six-lens corroboration on the
first, all inside twenty lines of one file. 9a-3 owns the whole test tree for this wave; every
assertion any other lane wants is deferred to Wave 9e.

### Wave 9b -- P1 remainder plus the bin/edm-state batch (3 parallel lanes)

| Lane | Files owned | Findings |
|---|---|---|
| 9b-1 | `skills/code-audit/SKILL.md`, `skills/plan/SKILL.md` | G6 (CA-193, skill half), G19 (CA-308) |
| 9b-2 | `plugins/edm/CHANGELOG.md`, `plugins/edm/CLAUDE.md`, `evals/README.md`, `tickets/epics/11`, `tickets/decisions.md` | G5 (CA-302), G30 (CA-275), G40 (CA-316) |
| 9b-3 | `plugins/edm/bin/edm-state` | G10, G11, G12, G15 (source half), G16, G17, G18, G26 (cmd_lint half), G32, G42 |

9b-3 is a single-file batch of ten findings, the same shape as round 4's Wave 4a. Order within the
lane: the lock-family items first (G17, G16, G42, G18), then git-lock-check (G10, G32), then the
metrics and field items (G12, G11, G26), then the sweep-line quoting half of G15. 9b-2 must follow
9a-2 because both touch `decisions.md`.

### Wave 9c -- P2 infrastructure (4 parallel lanes) || Wave 9d (parallel, disjoint)

| Lane | Files owned | Findings |
|---|---|---|
| 9c-1 | `.gitlab-ci.yml` | G24 (CI half), G41 (CA-317), G43 (CA-319) |
| 9c-2 | `plugins/edm/bin/tests/timing.sh` | G14 (CA-309), G34 (CA-310) |
| 9c-3 | `plugins/edm/bin/edm-lint-artifacts` | G51 (CA-327) |
| 9c-4 | `plugins/edm/README.md`, `bin/edm-init`, `docs/audit-patterns/SOURCES.md` | G38 (CA-314, shipping half), G22 (CA-168) |
| 9d | `SRD/.../tickets/epics/**` only | G47 (CA-323), G48 (CA-324), G49 (CA-325), G25 (CA-242), G45 (CA-321) |

9c-2 must complete before Wave 9e's G35 (which asserts against the finished harness) and before
G5's re-recorded figures are accepted -- see the sequencing note under G5. 9d is disjoint from
every 9c lane and runs concurrently, but must follow 9a-2.

### Wave 9e -- P2 test-tree consolidation (1 lane, single owner)

Owns `plugins/edm/bin/tests/**` except `timing.sh`. Absorbs every assertion prescribed by
Waves 9a-9d so the test tree has one writer per wave.

- G27 (CA-262), G28 (CA-263), G29 (CA-264), G23 (CA-195), G33 (CA-307), G35 (CA-311),
  G36 (CA-312), G37 (CA-313), G50 (CA-326), plus G15's CA-148 enumeration half and G6's
  fenced-template assertion half and G24's shared-extension-set assertion
- Deferred-in tests: the executing hook-body case from 9a-1, the backdated-lock case and the
  marker-sweep case from 9b-3

### Wave 9f -- comment, citation and family sweeps (1 lane, LAST)

Runs last on purpose: every citation it re-points must be resolved against final line numbers.

- G39 (CA-315): five citations plus the durability guard (CI ban or smoke assertion on new
  `<file>:<digits>` citations in comments) -- the guard is the load-bearing half
- G13 (CA-268): three exemplar citations in the trap-pattern comment block
- G26 (CA-247): the `architecture.md:631` citation half
- G38 (CA-314): the `edm-state:1057-1058` false-justification comment
- G20 (CA-049): harness sourcing shape across seven suites
- G21 (CA-074): `die()` family across twelve scripts plus the pinning assertion

G20 and G21 are cross-cutting mechanical sweeps that touch files owned by 9b-3 and 9e, which is
why they are last rather than parallel.

---

## Verification Plan

Run after each wave, and in full before the round-6 audit.

**Syntax and structure**

```
bash -n plugins/edm/bin/edm-state
bash -n plugins/edm/bin/edm-lint-artifacts
bash -n plugins/edm/bin/edm-init
bash -n plugins/edm/bin/edm-check-grants
for f in plugins/edm/bin/tests/*.sh plugins/edm/evals/*.sh; do bash -n "$f"; done
jq empty plugins/edm/hooks/hooks.json
jq empty .claude-plugin/marketplace.json
```

**Lint (mirrors the blocking CI jobs)**

```
plugins/edm/bin/edm-lint-artifacts --all
plugins/edm/bin/edm-check-grants
plugins/edm/bin/edm-sync-canonical-sections --check
shellcheck plugins/edm/bin/* plugins/edm/bin/tests/*.sh plugins/edm/evals/*.sh
```

`edm-lint-artifacts --all` is also the ASCII / vocabulary gate. Everything written this round is
ASCII-only; re-check after any hand edit that pastes text from a lens report.

**Unit and smoke**

```
plugins/edm/bin/tests/run-all.sh
```

Expected baseline after Wave 9a-9f: at least 1857 assertions passing, 0 failing, 7 suites. The
count should RISE, since Waves 9a and 9e add assertions. A flat count after 9e means an assertion
did not land.

**Targeted break tests (do not skip -- four P1s exist because a green suite could not see them)**

1. G2: typo the real scan's pattern at one converted `assert_tree_absent` site; the assertion must
   FAIL. Restore.
2. G4: plant the CA-036 bare-capture shape inside `wave7-smoke.sh:4543-4988`; the tripwire must
   fire and report 7 expected hits. Remove.
3. G1: with `commit_state_file=false` and no state file present, invoke a gated phase skill prompt;
   expansion must be ALLOWED (or the prompt-half prose must have been deleted to match).
4. G3: set `srd_root` to each of `.`, `./`, `..` and a repo-root-absolute value; each must produce
   a diagnostic the operator sees, never a silent exit 0.
5. G6: move the JSONL schema line above the fence in `skills/code-audit/SKILL.md`; the tripwire
   must fail. Restore.
6. G51/G24: run `plugins/edm/bin/edm-lint-artifacts` against a fixture with an ignored unicode
   violation inside an indented fence on both GNU grep and BSD grep paths.

**Ledger render**

```
plugins/edm/bin/edm-state render-ledger
```

Required: `findings-ledger.md` is stale by 53 entries and several lenses wasted effort
re-deriving closure status because of it.

**Re-audit (round 6)**

Must be a **full round, all 11 lenses**. Findings were fixed across every lens's territory this
round, and the convergence gate cannot be satisfied by a partial round. Give the round-6 brief the
following emphases:

- L1/L8/L7: the hooks.json family after G1, G3, G44, G31 -- four fixes in twenty lines is exactly
  the density that produced this round's headline regression
- L4: execute `run-all.sh` (this round's L4 could not, and flagged it)
- L6/L9: whether G39's durability guard actually prevents a new stale citation, since three of
  this round's citation findings were re-staled by their own remediation
- L9: whether the SRD and ticket pack now agree, after G7, G8, G9
