# Lens L4: Test Quality -- Round 6 (EDMV3 prompt-streamline)

**Tooling note (CA-130's class, third consecutive round):** Write, Edit and Bash were absent from
this lens's delivered runtime tool set. This report was transcribed by the orchestrator from the
lens agent's final message. Nothing was executed; findings were established by hand-tracing the
bash/awk under test, using Grep as a live regex oracle where a claim depends on real tree content
(marked "verified live"). Suite-green status (1996 assertions, 0 failed) is taken from the task
statement, not re-run.

## Round-5 L4 ledger entries re-verified against current code

| ID | Round-5 finding | Verdict now |
|---|---|---|
| CA-036 | F-2 tripwire blind to ~850 lines | **Closed and discriminating** (see Noted 1) |
| CA-037 | F-1 pattern outside the control | **Closed on the filed axis** (Noted 2) |
| CA-262 | F-3 perl-dependent p95 assertion | Fix landed in `timing.sh`; **not covered by any executing assertion** -> folded into F-1 |
| CA-311 | F-4 timing.sh fixes have zero covering assertions | **REOPENED -- F-1** |
| CA-263 | F-5 substring-match on a number | **Closed** (Noted 4) |
| CA-312 | F-6 presence-not-exclusivity gate assertions | **Two of three sites fixed; sibling missed -> F-3** |
| CA-313 | F-7 CI job-body terminator untested | **Closed and discriminating** (Noted 5) |

---

## Findings (L4: Test Quality)

### F-1 (P2) -- CA-311 reopened: `timing.sh --self-test` is never executed by anything, so the assertions written to close CA-311 cannot fail

`plugins/edm/bin/tests/timing.sh:96-101` (comment), `:102-173` (`self_test()`), `:217-220` (dispatch).

The round-5 remediation added five real assertions (perl-less `_now`/`_ms_between` fallback,
`_p95` nearest-rank at N=20 and N=10, and the shipped `_P95_SAMPLE_COUNT`). They are correct
assertions. Nothing runs them:

- `run-all.sh:45` discovers suites via `find "$_SUITE_DIR" -maxdepth 1 -name '*-smoke.sh'` --
  `timing.sh` is not a `*-smoke.sh` file (deliberate, CA-328).
- `wave7-smoke.sh` invokes `timing.sh` three times only: `:4281` (bare, usage text), `:4294`
  (`--session-start`), `:4316` (`--generate-fixture`). No `--self-test` invocation exists anywhere
  in `plugins/edm/` or `.gitlab-ci.yml` (grep-verified across `*.sh`/`*.yml`).
- `timing.sh:99-101` states it outright: *"This mode is likewise not auto-discovered by anything;
  run it by hand."*

Consequence: round-5 F-4's defect statement is still literally true today -- reverting
`_P95_SAMPLE_COUNT` from 20 to 10, or reverting `_p95`'s ceiling to `int(0.95*NR)`, or
re-breaking the awk fallback to `systime()`, leaves `run-all.sh` fully green. CA-309
(`timing.sh:76`) and CA-310 (`timing.sh:252`) are in the same position: their fixes are
comment-documented and unexercised, and `--self-test` is now the natural host for their
assertions too.

**False-alarm filter applied**: the non-wiring is *acknowledged* in a comment but not *justified*,
and the REMEDIATION prescription for G35/CA-311 asked specifically for assertions that make a
silent revert fail -- which this does not achieve. Not a false alarm.

**Fix**: wire it, using the in-file precedent that already exists for exactly this shape.
`wave7-smoke.sh:4605-4613` runs `evals/tiering-matrix.sh --self-test`, asserts exit 0, and then
asserts each individual `self-test PASS:` line. Add the twin next to the T67 timing block:

- capture `bash "$TIMING_SH" --self-test 2>&1` with an `|| ec=$?` on the same statement,
- assert exit 0,
- assert each of the five `self-test PASS:` substrings individually (so deleting one assertion
  from `self_test()` fails rather than silently shrinking the run),
- assert the summary line `self-test: PASS (5/5` so the assertion *count* is pinned too.

Cost: ~1s of added runtime (the `sleep 1` in assertion 1).

### F-2 (P2) -- T49 AC6's four self-verification tripwires are case-blind: the producing scan is case-insensitive, the assertion that reads its output is case-sensitive

`wave7-smoke.sh:4206` builds the haystack case-**insensitively**:

```bash
t49_selfverify_hits="$(grep -rni "${t49_dc_pattern}\|${t49_vyo_pattern}\|${t49_cyw_pattern}\|${t49_rvy_pattern}" "${PLUGIN_DIR}/skills" "${PLUGIN_DIR}/agents" 2>/dev/null | grep -v 'skills/verify-runtime/' || true)"
```

The four assertions at `:4214`, `:4218`, `:4222`, `:4226` pass that haystack to
`assert_tree_absent`, which verifies it case-**sensitively**: `_harness.sh:265` runs
`count_matches_strict -- "$pattern"`, and `count_matches_strict` (`_harness.sh:198-207`) is
`command grep -c "$@"` with no `-i`.

Traced failure mode: a real violation written `Double-check your own work` (sentence-initial
capitalization -- the *most likely* form in prose) is found by the `-rni` scan, lands in
`$t49_selfverify_hits`, and is then invisible to the case-sensitive needle. `real_count` is 0 ->
**all four assertions pass over a live violation**. The controls do not save it: each is a
lowercase literal (`:4213`, `:4217`, `:4221`, `:4225`) that the case-sensitive needle matches, so
the control arm passes normally.

Verified live: case-insensitive Grep for all four phrases across `plugins/edm/skills/` and
`plugins/edm/agents/` returns **0 hits**, so this is tripwire blindness, not an escaped
violation. But T49 AC6 exists to guard do-NOT-adopt guard **D1** (no self-verification
instructions in EDM prompts) -- the tripwire cannot see the shape the regression would most
plausibly take.

This is a **new instance of round-5's own class** (the two arms of one assertion constructed with
different matchers), one axis over from CA-037's divergent-literal axis: same literal, divergent
*matcher flags*.

**Fix**: make the two arms use the same matcher. Cheapest correct option -- drop `-i` from
`:4206` (the four needles are already lowercase and the AC's own text is the lowercase form), and
add a fifth control seeded with `Double-Check your own work` asserted to be *caught*, so the case
axis itself gets a positive control. Alternative: add an `-i`-passing variant of
`count_matches_strict` and use it at all four sites.

### F-3 (P2) -- CA-312's sweep converted two of three sibling sites; `wave6-smoke.sh:206-207` still proves presence, not exclusivity

`wave6-smoke.sh:205-207`:

```bash
gates_out2="$(call_edm_helper required_gates_for_mode standard standard "1 3" | tr '\n' ' ')"
check "required_gates_for_mode(standard, standard, phases 1+3 skipped) = only gate 3" "3" "$gates_out2"
check_absent "gate 1 absent when its origin phase (1) is skipped" "1 " "$gates_out2 "
```

The label claims *"only gate 3"*. The assertions prove gate 3 present and gate 1 absent --
nothing rules out gate 2. A regression returning `"2 3 "` satisfies `check` (contains `3`) **and**
`check_absent` (contains no `1 `), so a gate-2 leak passes. Gate 2's origin is phase 3, which is
in the skip list here, so gate-2 suppression is precisely what this case is supposed to be
testing.

The comment at `:209-213` names this exact defect class and converts `:214-217` and `:229-232` to
exact string equality -- but `:206`, eight lines above the comment that describes it, was left in
the old shape. Same file, same block, same contract.

**Fix**: match the converted siblings' shape -- `[[ "$gates_out2" == "3 " ]] && pass ... || fail
...` -- and drop the now-redundant `check_absent` at `:207`.

### F-4 (P2) -- the five UserPromptExpansion gate hooks have no executed happy-path case: a hook that blocks an *approved* gate passes every assertion

`wave7-smoke.sh:6137-6190` (CA-298/G1) is a strong test -- it extracts each of the five real hook
commands from `hooks/hooks.json` and executes them against stub `edm-state` binaries. It runs
exactly two cases per hook:

- **Case A** (`:6157-6169`): `resolve-dir` fails -> hook must exit 0 (allow).
- **Case B** (`:6173-6185`): `resolve-dir` succeeds, `gate-check` fails -> hook must exit 2 (block).

There is no **Case C**: `resolve-dir` succeeds *and* `gate-check` succeeds -> hook must exit 0.
The shipped hooks (`hooks/hooks.json:19`, `:32`, `:45`, `:58`, `:71`) end
`... edm-state gate-check "$prefix" srd || exit 2; exit 0`. A regression to
`gate-check "$prefix" srd; exit 2`, or a stray `exit 2` appended after the gate-check line, passes
Case A (returns earlier), passes Case B (exit 2), and **locks the user out of `/edm:srd`,
`/edm:audit-srd`, `/edm:tickets`, `/edm:audit-tickets` and `/edm:implement` permanently, even with
every gate approved**.

The only thing standing against that today is the literal text pin at `:6119`
(`check ... "gate-check \"\$prefix\" ${token} || exit 2"`) -- a substring assertion on the hook's
source text, not on its behavior, and one that a trailing `; exit 2` would not disturb. The suite
otherwise executes the real hook, which makes the missing third case the odd one out rather than a
design choice.

**Fix**: add Case C inside the same `for matcher in ...` loop, reusing the existing scratch/stub
scaffolding (~8 lines): stub `resolve-dir) echo "/tmp/CA298PFX"; exit 0` and `gate-check) exit 0`,
run `$cmdfile`, assert `ec -eq 0`, with the failure message naming that an approved gate must not
block.

### F-5 (P2) -- two new count assertions bypass the harness's own count guard, so a zero count aborts the suite mid-run instead of failing one assertion

`wave7-smoke.sh:7362` and `:7370` (the G51/CA-327 block, added this session):

```bash
g51_call_count="$(grep -c '_lint_report_class_hits "' "${PLUGIN_DIR}/bin/edm-lint-artifacts")"
...
g51_readloop_count="$(grep -c 'while IFS=: read -r lineno _rest' "${PLUGIN_DIR}/bin/edm-lint-artifacts")"
```

Bare `grep -c`, no `|| true`, no `count_matches`. `grep -c` exits 1 on zero matches, so under this
file's own `set -euo pipefail` the assignment at `:7362` aborts the suite -- meaning `:7370-7373`
never run and the `Results: ${PASS} passed, ${FAIL} failed` line at `:7376` is never printed.
`run-all.sh:132-142` then scores the suite CRASH, which is the correct verdict (no masked pass),
but every assertion count from that run is lost and the operator sees a crash rather than the
one-line diagnostic the assertion was written to emit.

`_harness.sh:176-190` documents `count_matches` as existing for exactly this ("*Used by
count-based assertions so a regression becomes one failed assertion, not a crashed suite*"), and
the same suite guards `grep -c` with `|| true` at ~180 other sites (e.g. `:1000`, `:4184`,
`:4190`, `:5796`, `:6381`). So the house pattern is the guarded form; these two sites are the
deviation, not the convention.

**Fix**: `count_matches '_lint_report_class_hits "' "${PLUGIN_DIR}/bin/edm-lint-artifacts"` (or
append `|| true`) at both sites. Not a masked failure -- a diagnostic-quality and convention
finding, filed at P2 only.

---

## Noted / Not Actionable

1. **CA-036 (round-5 F-2) closed and discriminating.** `wave7-smoke.sh:5756` now clears `guarded`
   on `^[[:space:]]*\)"`, which matches the real subshell-probe close idiom (`)" || true` at
   `:4750`, `:4963`; `)"` bare elsewhere). The 7th positive-control fragment at `:5783-5787` places
   a bare `$?` capture after an unpaired `set +e` inside a closed command substitution -- the
   exact previously-blind shape -- and the expected count moved 6->7 at `:5791` with an exact
   `-eq`.
2. **CA-037 (round-5 F-1) closed on the axis filed.** Every `assert_tree_absent` call site now
   derives the producing grep's pattern from the same shell variable it passes as the needle
   (`wave7:189-193`, `:1441-1463`, `:1814-1830`, `:2590-2611`, `:4206-4227`;
   `wave6:2502-2527`). The hand-typed control literals fail in the *safe* direction: a typo in the
   pattern variable breaks both the real scan and the needle, the control then reports 0 hits, and
   the assertion fails by name.
3. **`assert_absent_with_control` has zero production callers, and that is enforced.**
   `wave7:196-211` is a live tripwire scoped to exclude only `_harness.sh` and `harness-smoke.sh`
   (the sanctioned self-test host).
4. **CA-263 (round-5 F-5) closed.** `wave7:5125` uses `[[ "$tmp_left" -eq 0 ]]`. The surviving
   `check "... " "tmp_left=0"` sites at `:4762` and `:4971` are safe: the needle carries the
   `key=` prefix, so `tmp_left=10` cannot satisfy `tmp_left=0`.
5. **CA-313 (round-5 F-7) closed and discriminating.** `wave7:4527-4539` extracts
   `lint:vocabulary`'s body with the tightened terminator and asserts a post-`:198` token
   (`CA-162`) survives, paired with a deliberately-truncated positive control proving the needle
   would be absent if the terminator re-loosened.
6. **`check "..." "0" "$ca140_*"` at `wave7:5197-5200`** is the substring-on-a-number shape, but
   `schema_at_least` (`bin/edm-state:1307-1330`) can only ever echo a bare `0`, `1` or `2` -- no
   wider value can satisfy the needle. Not a live false-pass.
7. **`count_matches`'s exit-1/exit-2 collapse** is documented as a caveat at `_harness.sh:180-185`
   with a mandatory pairing rule, and `count_matches_strict` exists for the strict case.
   Intentional and self-documented.
8. **`_harness.sh:303`'s `"$@" >/dev/null 2>&1 || true`** inside `check_state_unchanged` is
   deliberate -- that helper asserts only byte-identity of the state file.
   `check_refuses_and_leaves_state` (`:320-353`) is the exit-code + message + hash variant that
   CA-042 converted the 45 sites needing all three to.
9. **`run-all.sh:104-105`'s `_status=0` seed + same-statement `|| _status=$?`, and the deliberate
   omission of `-e`,** are documented at `:10-16` and are the correct aggregator shape.
10. **The `2>/dev/null || true` capture idiom feeding `check`/`check_absent` haystacks** (e.g.
    `wave7:220`, `:2435`, `:2695`, `:5867`) fails in the safe direction: a missing file yields an
    empty haystack and `check` on an empty haystack fails. Not the masking class.
11. **`wave7:4479-4495` / `:4514-4517`** (CA-085 and CA-319 positive controls) are genuine, not
    tautological: the pin needle is asserted *absent* from a deliberately-unpinned string, which
    discriminates pinned from unpinned rather than restating the needle.
12. **`evals/tiering-matrix.sh --self-test` IS wired** (`wave7:4605-4613`, exit-0 check plus one
    assertion per promotion-rule branch). Recorded here because it is the in-repo precedent that
    makes F-1 cheap to fix, not because anything is wrong with it.
13. **G23/CA-195's fence scanner (`wave7:6385-6422`)** carries a two-sided positive control -- one
    hit inside a fence must fire, one prose hit outside must not, with an exact `-eq 1` -- plus a
    >=20-file discovery floor. Correct as written.

---

## Suite-run status -- NOT CONFIRMED BY THIS LENS

`run-all.sh` was not executed (no Bash). Every claim above rests on static tracing; where a claim
depends on real tree content (F-2's live-violation check, the four `assert_tree_absent`
pattern-variable sites, the `timing.sh --self-test` non-wiring) Grep was used as the oracle and
the result is stated as verified live. Recommend a Bash-capable pass re-runs the aggregator after
F-1/F-3's fixes land, since F-1's fix adds five assertions and F-3's change alters one assertion's
shape.

## Meta

`Write`, `Edit` and `Bash` were absent from this lens's delivered runtime tool set -- the CA-130
class, third consecutive round. Suggested ledger IDs for the five findings: F-1 reopens
**CA-311**; F-2, F-3 (residual of **CA-312**), F-4 and F-5 are new.
</content>
