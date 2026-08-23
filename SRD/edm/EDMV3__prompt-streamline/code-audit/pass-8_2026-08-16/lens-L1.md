# Lens L1: Logic, Correctness & Completeness -- Round 8 (pass-8, 2026-08-16)

Scope swept: `plugins/edm/bin/*`, `plugins/edm/bin/tests/*`, `plugins/edm/agents/*.md`,
`plugins/edm/skills/*/SKILL.md`, `plugins/edm/hooks/hooks.json`, `plugins/edm/monitors/monitors.json`,
`plugins/edm/evals/*.sh`, `plugins/edm/CLAUDE.md`, `README.md`, `CHANGELOG.md`, root `.gitlab-ci.yml`.

Tooling caveat (CA-130/CA-388): this lens ran with no `Bash` and no `Write`. Nothing was executed;
every claim below is derived from reading source. jq `//` semantics were verified against the
official jq 1.7 manual rather than by running jq.

## Prior-round verification (the four L1 findings carried into round 8)

| ID | Verdict | Evidence |
|---|---|---|
| CA-389 | **Code fixed, tests NOT landed** | `bin/edm-state:5183-5201` (`G11/CA-389`). Prescribed wave6 assertions absent -- see L1-001 |
| CA-390 | **Code fixed, tests NOT landed** | `bin/edm-state:5349-5360` (`G12/CA-390`). Prescribed wave6 assertion absent -- see L1-001 |
| CA-391 | **FIXED -- close** | `bin/edm-state:2242-2251` + `bin/tests/wave6-smoke.sh:640-655` |
| CA-392 | **FIXED -- close** | commit `dfa71d3`; `wave7-smoke.sh:1802`, `:4319` now use `count_matches_strict`; a tree-wide grep for `grep -c[^)]*|| echo` returns only the two explanatory comments, zero live sites |

**CA-389 detail.** The applied fix captures the derivation's stdout once via plain command
substitution (`:5192`) and branches on emptiness (`:5193-5201`) instead of inferring emptiness from
a pipeline exit code, so the old `"0\n3"` two-line capture is gone. Traced by hand:
`standard` -> 3, `prototype` -> 1 (gate 1's phase 1 <= terminal 2; gates 2/3 feed phases 3/5),
`fast-track`/`fix-pack` with phases 1,2,3,5 recorded skipped -> empty output -> 0. Correct.
Errexit is suspended inside `with_state_lock`'s `( ... ) || _lock_ec=$?` subshell (`:1229`), so the
comment's claim that a `die` from `terminal_phase_for_mode` no longer aborts the locked HANDOFF
write holds. **The code half is genuinely closed.**

**CA-390 detail.** `gate_events_count` (`:5357`, raw length) vs `gates_count` (`:5158`,
`unique | length`) with a reconciling note appended when events exceed distinct gates
(`:5358-5360`). Logic verified correct. The finding's optional heading rename
(`## Gates (approval history)`) was not taken; that was an "or" in the prescription, not a
requirement. **The code half is genuinely closed.**

---

## Findings (L1: Logic, Correctness & Completeness)

### L1-001 [P2] CA-389 + CA-390 shipped their code halves with zero test coverage; every prescribed assertion is missing

**File**: `plugins/edm/bin/tests/wave6-smoke.sh` (absent cases) covering
`plugins/edm/bin/edm-state:5199` and `:5358`

CA-389 prescribed three wave6-smoke.sh assertions and CA-390 prescribed one. **None of the four
exist.** Verified: a repo-wide grep for `CA-389` and `CA-390` outside `SRD/` returns exactly two
hits, both source comments in `bin/edm-state`; a grep for the rendered string `Gates approved`
across `bin/tests/` returns one hit and it is a comment (`wave6-smoke.sh:644`), not an assertion.
`required_gate_count` appears nowhere in any test file.

So the `- **Gates approved**: N of M` line emitted at `bin/edm-state:5531` -- the line both findings
are about -- has **no assertion anywhere in the suite**, exactly as CA-389's own closing sentence
warned ("No test anywhere asserts this line today, so the whole CA-335 fix is uncovered"). Both
fixes are one careless edit away from silently regressing, and the class has now regressed twice
(CA-335 -> CA-389/CA-390).

This is the completeness half of two findings whose code halves are correct, not a re-flag of the
code halves. Contrast `CA-391`, which landed code *and* `check_refuses_and_leaves_state` cases in
the same commit.

**Concrete fix** -- add to `bin/tests/wave6-smoke.sh`, beside the existing `G13/CA-391` block:

```bash
# G11/CA-389: the denominator is mode/lifecycle-derived, not a hardcoded 3.
"$EDM_STATE" init T389PROTO >/dev/null
"$EDM_STATE" set-mode T389PROTO mode prototype >/dev/null
check "G11/CA-389 -- prototype renders a denominator of 1" \
  "Gates approved: 0 of 1" "$(cat "$TMP/SRD/T389PROTO/HANDOFF.md")"

"$EDM_STATE" init T389FT >/dev/null
"$EDM_STATE" set-mode T389FT lifecycle_mode fast-track >/dev/null
for p in 1 2 3 5; do
  "$EDM_STATE" skip-phase T389FT "$p" "fast-track: tickets from analysis doc" >/dev/null
done
check "G11/CA-389 -- fast-track renders a denominator of 0, not 3" \
  "Gates approved: 0 of 0" "$(cat "$TMP/SRD/T389FT/HANDOFF.md")"

# G12/CA-390: a re-approved gate leaves numerator and list disagreeing; the note reconciles them.
"$EDM_STATE" init T390DUP >/dev/null
"$EDM_STATE" approve-gate T390DUP 1 >/dev/null
"$EDM_STATE" approve-gate T390DUP 2 >/dev/null
"$EDM_STATE" approve-gate T390DUP 1 >/dev/null
t390_handoff="$(cat "$TMP/SRD/T390DUP/HANDOFF.md")"
check "G12/CA-390 -- the numerator counts distinct gates, not approval events" \
  "Gates approved: 2 of 3" "$t390_handoff"
check "G12/CA-390 -- the reconciling note explains the 3-row list under a count of 2" \
  "3 approval event(s) recorded above for 2 distinct gate(s)" "$t390_handoff"
```

---

### L1-002 [P2] `--accept-p2-debt` engagement is decided by a prefix match at position 0 of a stream that merges stderr, so a stderr warning silently disables the override and produces a self-contradictory refusal

**File**: `plugins/edm/bin/edm-state:2168`, `:2178`, `:2195-2199`

```bash
conv_out="$(cmd_audit_converged "$prefix" 2>&1)" || conv_ec=$?
...
if [[ $conv_ec -eq 1 && $accept_p2_debt -eq 1 && "$conv_out" == "not converged: "* ]]; then
```

`conv_out` merges stderr into stdout, but the engagement test anchors `not converged: ` at
**position 0**. `cmd_audit_converged` has a warn-and-**proceed** arm at `:4476` that writes to
stderr and then still falls through to the `not converged:` stdout line at `:4522`:

```bash
echo "edm-state audit-converged: [warn] no code-audit round has ever been recorded for ${prefix} ..." >&2
```

That arm fires whenever `rounds_count -eq 0` -- a legacy initiative, a hand-edited state file, or
any `audit_rounds.code` still in the bare-integer shape (`coerce_round_entry` yields `rounds: []`,
so `rounds_count` is 0 by construction). In that case `conv_out` begins with the warning, the
prefix test fails, `p2_debt_accepted` stays `0`, and control falls to `:2195`, which dies with:

```
code-audit gate refused for FOO even with --accept-p2-debt (P0=0 P1=0 must both be 0, or the refusal is not a severity refusal): ...
```

The message asserts P0 and P1 "must both be 0" while printing them **as 0** -- because `p2_debt_p0`
/`p2_debt_p1` were never populated (they still hold their `:2177` initialisers). The operator is
told the override failed for a condition the message itself shows is satisfied, with no way to
proceed. Direction is safe (fails closed -- no wrongful convergence), hence P2 rather than P1.

The comment at `:2169-2176` is explicit that the narrowing is deliberate for *other* exit-1 arms
(invalid JSONL, invalid status, unknown/partial round_type) -- all of which return early on stderr
and never emit the stdout line. Those work by luck of ordering, not by design; this arm is the one
that both warns and continues, and it was not considered.

**Concrete fix** -- separate the streams, matching the precedent `_write_handoff_body` already sets
(named at `:4518-4521`: "only a caller that inspects the two streams separately ... can tell the
difference"):

```bash
local conv_out conv_err conv_ec=0 _conv_errfile
_conv_errfile="$(mktemp "${TMPDIR:-/tmp}/edm-state.approve-gate-conv.XXXXXX")"
conv_out="$(cmd_audit_converged "$prefix" 2>"$_conv_errfile")" || conv_ec=$?
conv_err="$(cat "$_conv_errfile" 2>/dev/null || true)"
rm -f "$_conv_errfile"
```

then test `"$conv_out" == "not converged: "*` against stdout only, and interpolate
`${conv_out}${conv_err:+ ($conv_err)}` into the die messages so nothing is lost. (Register the
temp file with the same trap pair `write_atomic` uses -- CA-399 is open on exactly this omission
elsewhere; do not add a second untrapped `mktemp`.) A one-line alternative that closes the false
negative without the plumbing is to widen to a substring test, `"$conv_out" == *"not converged: "*`
-- but then also populate `p2_debt_p0`/`p2_debt_p1` before `:2199` can quote them.

Second, independent half of the same edit: `:2199`'s message must not claim a P0/P1 condition it
never evaluated. Guard it:

```bash
die "code-audit gate refused for ${prefix} even with --accept-p2-debt: the refusal was not a severity refusal (the override applies only to an open-P2-only blocking set): ${conv_out}"
```

when `p2_debt_json` was never computed, and keep the P0/P1-naming form only for the case where the
breakdown really was read.

---

### L1-003 [P2] The two new `--accept-p2-debt` round-number reads bypass `AUDIT_ROUND_COERCE_JQ_DEF`, violating the file's own stated single-coercion invariant

**File**: `plugins/edm/bin/edm-state:2212` and `:3016`

```bash
p2_debt_round="$(echo "$state_json" | jq -r '.audit_rounds.code.count // 0')"   # :2212
debt_round_now="$(echo "$state_json" | jq -r '.audit_rounds.code.count // 0')"  # :3016
```

`AUDIT_ROUND_COERCE_JQ_DEF`'s own docstring at `:1474-1483` states the rule categorically: "no
legacy file is rewritten (AC1a), so **every reader of `audit_rounds.<type>` pipes the raw value
through this one jq `def` first**". Every pre-existing reader obeys it -- `:1604`, `:1624`, `:3323`,
`:4232`, `:4240`, `:4308`, `:4331`, `:4457`. The two T-EDMV4 sites are the only exceptions in the
file.

On a legacy bare-integer `audit_rounds: {"code": 3}` -- the shape `:1476` says the archived EDMV2
fixture literally carries -- `.audit_rounds.code.count` indexes a number with a string. jq raises
`Cannot index number with "count"` and exits 5. The trailing `// 0` does **not** rescue it: per the
jq 1.7 manual, `//` filters only `false`/`null` from its left-hand side and has no error-suppression
semantics (that is `?`/`try`); `gen_definedor` compiles to `FORK`, not the `FORK_OPT` that `try`
uses. Under `set -euo pipefail` (`:54`) the plain assignment then aborts `edm-state` with a raw jq
error and no `die` message.

**Latent, not live today, and the reason is L1-002.** `:2212` is only reached when
`p2_debt_accepted -eq 1`, which requires the `:2178` prefix test to pass -- and on precisely the
bare-integer shape that test fails first (the `:4476` warn prepends to `conv_out`). `:3016` is
gated behind `code_audit_p2_debt_accepted`, which `:2212` must have written. **Fixing L1-002
un-latches this one**, so the two must be fixed in the same commit or the fix for L1-002 converts
a confusing refusal into a jq crash.

**Concrete fix** -- both sites, identical shape, reusing the constant already in scope:

```bash
p2_debt_round="$(echo "$state_json" | jq -r "${AUDIT_ROUND_COERCE_JQ_DEF} (.audit_rounds.code // 0 | coerce_round_entry).count")"
```

and add a wave6 case seeding `jq '.audit_rounds = {"code": 2}'` before
`approve-gate ... --accept-p2-debt`, asserting `code_audit_p2_debt_round == 2` -- the same
bare-integer fixture `wave6-smoke.sh:3075` and `:3955` already use for the other readers.

---

### L1-004 [P2] Residual of CA-392: twelve bare `grep -c` captures still abort the suite under `set -e` instead of producing a named FAIL

**File**: `plugins/edm/bin/tests/wave6-smoke.sh:285, 291, 892, 3248, 3255, 3261, 3267`;
`plugins/edm/bin/tests/wave7-smoke.sh:3621, 3628, 3696, 4296, 4300`

CA-392's four named sites are genuinely fixed. But its stated harm -- "crashing the suite instead of
failing one assertion the way `count_matches` exists to guarantee" -- survives at twelve further
sites in a *second* shape the remediation did not sweep: a bare capture with **no guard at all**.

```bash
g25_call_site_count="$(grep -c 'schema_at_least "' "$EDM_STATE")"      # wave7:4296
t28_bf_def_count="$(grep -c '^BLOCKING_FILTER=' "$EDM_STATE")"        # wave6:3248
```

`grep -c` always prints a count, so the *value* is fine; the *exit status* is 1 on zero matches, the
assignment inherits it, and both suites run under `set -euo pipefail` (`wave7-smoke.sh:8`). Deleting
or renaming `BLOCKING_FILTER` or `schema_at_least` therefore kills the suite at that line and
discards every later assertion -- instead of the intended one-line `fail`, which is the whole reason
`_harness.sh:176-190` exists. Ten of the twelve can genuinely reach zero (the two at `wave6:291`
and `wave6:3261` are synthetic controls with guaranteed matches, same shape but benign).
`wave7-smoke.sh:6875` is *not* in this set: its capture sits inside `[[ ... ]]`, where errexit does
not apply.

Not a false alarm on the consistency test: the harness ships `count_matches` precisely for this, its
docstring says so, and the majority of comparable sites already use it.

**Concrete fix** -- mechanical, one line each: `grep -c X F` -> `count_matches X F` (both suites
already source `_harness.sh`). At `wave7:4296`/`:4300`, where the file argument is a fixed path
whose disappearance must not read as a passing zero, use `count_matches_strict` and assert its exit
status alongside the count, exactly as `wave7:4319` already does:

```bash
g25_status=0
g25_call_site_count="$(count_matches_strict 'schema_at_least "' "$EDM_STATE")" || g25_status=$?
[[ "$g25_status" -eq 0 && "$g25_call_site_count" -eq 6 ]] \
  && pass "G25/CA-342 -- exactly 6 schema_at_least() call sites" \
  || fail "G25/CA-342 -- ${g25_call_site_count} call sites (count_matches_strict status ${g25_status}), CLAUDE.md says 6"
```

---

### L1-005 [P2] Two comments cite `gates_count` at `:5036`; it is at `:5158` -- both citations are wrong by 122 lines

**File**: `plugins/edm/bin/edm-state:2246` and `:5349`

```
# ... CA-335's unique-then-length numerator (see write-handoff's gates_count, :5036) DOES count it   # :2246
# G12/CA-390 (round 7): gates_count (above, :5036) dedupes by .gate via `unique`; ...                # :5349
```

`gates_count` is assigned at `:5158`. Both citations were authored in round 7 against the
then-current offsets and were falsified by the round-7/T-EDMV4 insertions above them. A reader
following either pointer lands inside `write_handoff_internal`'s locked-dispatch region, not on the
numerator, and the `:5349` comment is the load-bearing explanation for why the reconciling note
below it exists.

Distinct from open CA-406 in kind, not just in location: CA-406 flags citations that are *accurate
today but unguarded*. These two are **already wrong**. That both drifted within one round is the
strongest available evidence for CA-406's own prescription. Overlaps L6 (comment accuracy) -- expect
the synthesizer to merge.

**Concrete fix** -- apply CA-406's own remediation (anchor by name, drop the number):

- `:2246` -> `` (see `_write_handoff_body`'s `gates_count`) ``
- `:5349` -> `` gates_count (assigned above in this function) dedupes by .gate via `unique`; ``

Do not re-number them; a fresh number regresses in the next insertion.

---

## Noted / Not Actionable

- **CA-391 -- fixed, close.** `bin/edm-state:2251` tightened to `^[123]$` with a message naming
  `1, 2, 3, 3.5, code-audit`; `wave6-smoke.sh:650-655` adds `check_refuses_and_leaves_state` cases
  for `7` and `0`. Both halves of the prescription landed.
- **CA-392 -- fixed, close.** All four `grep -c ... || echo 0` captures converted (commit
  `dfa71d3`). A tree-wide grep for the defect shape returns only the two explanatory comments at
  `wave7-smoke.sh:1803` and `:4317`. The separate residual class is L1-004, a new finding.
- **CA-389 / CA-390 code halves -- fixed.** Verified line by line above; only the missing test
  coverage (L1-001) remains.
- **`required_gates_for_mode` empty output still conflates "died" with "legitimately zero" for
  `fast-track`/`fix-pack` (`edm-state:5193-5197`).** A corrupt `mode` on a fast-track initiative
  yields `die` -> empty -> `0`, rendering "0 of 0" rather than the safe `3`. The comment at
  `:5188-5191` argues the tradeoff explicitly and the fallback arm at `:5196` is labelled
  "safe fallback, not a silent zero" for every other lifecycle. Documented intentional; window
  requires two simultaneous hand edits.
- **No unresolved `TODO` / `FIXME` / `HACK` / `XXX` / `NotImplementedError` / stub-return anywhere
  in scope.** Tree-wide case-insensitive sweep: every hit is prose *about* those markers
  (`agents/edm-audit-logic.md:33-35`, `agents/edm-implementer.md:46-47`,
  `skills/implement/SKILL.md:67,193`, `evals/vague-ac-patterns.txt:29`) or a `TodoWrite` tool grant
  in frontmatter. Zero live markers, zero `pass`-where-logic-belongs, zero
  always-same-literal returns.
- **`skipped_for_count`'s inline jq at `edm-state:5182` duplicates `skipped_phases_str`.** Already
  open as CA-417 (L10). Not re-flagged.
- **CA-396 / CA-397 / CA-398 / CA-415 appear fixed since the round-7 snapshot** --
  `_lock_timeout_marker` now keys on `${BASHPID:-$$}` (`:1226`), `EDM_STATE_LOCK_WAIT_S`/
  `EDM_STATE_LOCK_MAX_TRIES` are one derived pair (`:1099-1100`), `_lock_retry_or_die` takes
  `<tries>` explicitly (`:1116-1124`), and the fd-200 comment now names fd 9 and the 10+ band
  (`:1164-1170`). Outside L1's mandate; recorded so the owning lenses can confirm rather than
  re-derive.
- **`plugins/edm/WHATS_NEW.md` (untracked) is outside this lens's declared file scope.** Not
  audited. Flagging only that it is a new, uncommitted, unlinted artifact in the plugin root.

## Sources

jq `//` semantics verified against the [jq 1.7 manual](https://jqlang.org/manual/v1.7/) and the
[jq wiki: How to Avoid Pitfalls](https://github.com/jqlang/jq/wiki/How-to:-Avoid-Pitfalls).
