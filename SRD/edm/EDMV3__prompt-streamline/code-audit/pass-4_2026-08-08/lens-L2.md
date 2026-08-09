# Code Audit Lens L2 -- Dead Code & Unreachable Paths

- **Lens**: L2 (Dead Code, Unreachable Paths, Environmentally-Eliminated Branches)
- **Date**: 2026-08-08 | **Round**: pass-4 (full, all 11 lenses) | **Branch**: `edm/edmv3-prompt-streamline`
- **Scope read this round**: `bin/edm-state` (targeted: lock/atomic-write subsystem `:470-700`, `:930-1150`, token reader `:277-410`, `cmd_approve_gate` `:1780-1875`, `cmd_audit_converged` `:3730-3840`, pattern-library splice `:4283-4360`, anomalies `:1300-1340`, metrics writers `:2042-2090`/`:3661-3700`), `bin/_edm-lint-lib.sh` (full), `bin/edm-check-grants` (parser), `bin/edm-check-vocabulary` (scope/collection), `bin/edm-lint-artifacts` (`scan_md_files` in full), `bin/tests/_harness.sh` (full), `bin/tests/run-all.sh` (full), `evals/run-eval.sh` (full), `evals/score-artifacts.sh` (`main_score`), `evals/tiering-matrix.sh` (`self_test` + dispatch), `hooks/hooks.json` (full), `skills/code-audit/SKILL.md` (full), repository-root `.gitlab-ci.yml` (lint stage).

## Headline

**All eight L2-tagged `open` ledger entries verify FIXED this round**, including both mechanisms round 3 flagged as
"shipped inert". This is the first round in which no carried L2 entry survives.

- **CA-142 / CA-143** (the nested-`write_atomic` cleanup subsystem): genuinely fixed, and fixed by the *right*
  option. The `_EDM_CLEANUP_PATHS` shared-list mechanism is **deleted outright** rather than patched, and
  `write_atomic` now installs its own full four-signal trap layer unconditionally (`bin/edm-state:616-625`).
  The dead-code problem was not moved elsewhere -- the ~25 inert lines and the comment that stated the opposite
  of the behaviour are gone, replaced by a comment (`:570-587`) that correctly describes the fork boundary.
- **CA-049** (the shared test-harness preamble helper): genuinely fixed. `harness_scratch_dir` now has three
  real callers, `_HARNESS_PLUGIN_DIR` four, `_HARNESS_REPO_ROOT` three. The three hand-rolled bare-`mktemp`
  EXIT-only preambles are gone.

The fresh pass produced **three new P2 findings**. Two of the three are residue introduced by Wave 7's own
fixes -- the dominant three-round pattern continues, though at materially lower volume and severity than
rounds 2 and 3. No P0, no P1.

| ID | Sev | Conf | Site | Defect |
|---|---|---|---|---|
| L2-001 | P2 | high | `bin/edm-state:654-656` | `_print_literal` has zero call sites after the G38/CA-198 fix, and the comment retaining it names a consumer that does not exist |
| L2-002 | P2 | medium | `evals/run-eval.sh:188` | `${run_total:-0}` default on a `grep -c` capture that can never be empty -- the exact class the ledger accepts at CA-140 and CA-202, re-introduced by the G12/G54 retention fix |
| L2-003 | P2 | medium | `bin/edm-state:1120-1124` | the `_EDM_TRAP_DEPTH` reentrancy guard is unreachable for the one nesting shape its own comment names (preempted by the mkdir spin-loop at `:1052`), and fully inert on the flock branch |

`BLOCKING_FILTER` (`bin/edm-state`) includes P2, so all three are in the blocking set. All three are one-to-six-line
edits; none needs a design decision.

---

## Part 1 -- Verification of L2-tagged `open` ledger entries

Eight ledger rows carry L2 in their Lens(es) column with Status `open`: CA-182, CA-142, CA-143, CA-049, CA-138,
CA-200, CA-201, CA-202. Each is verdicted below against the current tree.

### CA-182 (P0, L1+L2+operator) -- **FIXED**

`bin/edm-state:1823-1846`. The precheck is now **unconditional**:

```bash
    local conv_out conv_ec=0
    conv_out="$(cmd_audit_converged "$prefix" 2>&1)" || conv_ec=$?          # :1839  -- always runs
    if [[ $conv_ec -eq 3 && "$ag_schema_class2" != "2" ]]; then             # :1840  -- only exit-3 degrades
      record_degraded_check ...
    else
      [[ $conv_ec -eq 0 ]] || die "code-audit gate refused for ${prefix}: ${conv_out}"   # :1845
    fi
```

Exactly the prescribed remediation: the schema class no longer gates whether the precheck runs, only whether its
exit-3 (no JSONL ledger) arm degrades. Traced against the environmental constraint that made this a P0 --
`_cmd_init_render` still writes the literal `schema_version: 1` and nothing auto-migrates, so `ag_schema_class2`
is `!= "2"` for every initiative the current plugin creates. Under the old code that made the whole precheck
unreachable; under the new code a schema-1 initiative with a `findings-ledger.jsonl` carrying one open P2 gets
`conv_ec=1`, falls to the `else` at `:1844`, and dies at `:1845`. The gate is no longer unconditionally approvable.
The rationale is recorded in place at `:1828-1834` naming CA-182.

CA-183's sibling refusal is still correctly ordered *before* the schema-derived block, at `:1817-1821`, so the
pair is now symmetric -- which was the finding's core complaint.

Residual (not raised): the degrade arm at `:1840-1843` still approves the gate for a schema-1 initiative that has
never run a code audit at all. That is EDMV3-T28 AC7's documented caller-side degradation and exactly what the
ledger's own prescribed fix asked for, so it passes False Alarm Filter criterion 2.

### CA-142 (P1, L2+L3) -- **FIXED**, and fixed by deletion rather than by relocation

`bin/edm-state:570-588`, `:590-646`. The entire `_EDM_CLEANUP_PATHS` subsystem (`_edm_cleanup_push`,
`_edm_cleanup_pop`, `_edm_cleanup_paths_run` and the nine-line rationale comment) is **gone from the tree** -- a
repository-wide grep for `_EDM_CLEANUP_PATHS`, `_edm_cleanup_push`, `_edm_cleanup_pop` and
`_edm_cleanup_paths_run` returns hits only in prior-round audit artifacts under `SRD/`, none in `plugins/edm/`.

`write_atomic` no longer has a nested/non-nested split. `:616-625` installs `_save_traps` plus all four signal
traps unconditionally, on every call, in whatever process the call happens to be in. The `if [[
"${_EDM_TRAP_DEPTH:-0}" -ge 1 ]]` branch that gated trap installation is deleted.

The replacement comment at `:570-587` is accurate rather than inverted. It states the fork-boundary reasoning
correctly ("a `( )` subshell fork resets what `trap -p` reports for the forked process ... so that trap layer is
nesting-depth ONE from the subshell's own perspective") and explicitly records why the previous mechanism was
dead. This is the disposition round 3's L2 asked for -- "pick ONE of the two designs, not both" -- and the
chosen design is the one that works.

I specifically checked whether the dead-code problem was relocated rather than removed. It was not: the only
surviving reference to `_EDM_TRAP_DEPTH` is the reentrancy guard, which is L2-003 below and is a different,
much smaller issue than the subsystem it replaced.

### CA-143 (P1, L2+L3) -- **FIXED**

`bin/edm-state:616-625` (inside the fork) and `:1102-1118` (the parent). The critical section now has signal
coverage on both sides of the fork boundary:

- Parent (`with_state_lock` mkdir branch): `_save_traps` at `:1102`, then EXIT/INT/TERM/HUP at `:1115-1118`
  removing the lockdir, with INT/TERM/HUP exiting `130`/`143`/`129` and the EXIT arm cleanup-only.
- Subshell (`write_atomic`, called from inside `( "$@" )`): `_save_traps` at `:616`, then EXIT/INT/TERM/HUP at
  `:622-625` removing the staging temp file, same exit-code discipline.

The platform asymmetry the finding named is closed: a locked read-modify-write interrupted on a host without
`flock(1)` -- macOS, the stated primary development platform -- now has both resources covered, each by the
process that owns it, with no cross-process coordination needed. I verified the fixed-global save/restore pair
(`_EDM_SAVED_TRAP_EXIT` etc., `:542-553`) cannot collide: `with_state_lock`'s own `_save_traps` runs only on the
mkdir branch in the parent, and the only thing that executes between `:1102` and `:1146` in that process is the
fork at `:1143`, so a nested `write_atomic` always operates on the subshell's private copy. The safety argument
recorded at `:536-541` is correct as written.

### CA-049 (P2, L2+L7+L10) -- **FIXED** (L2 half; L7/L10 residual halves are not this lens's call)

The shared-preamble vehicle is live at every site round 3 found empty:

- `harness_scratch_dir` -- three callers: `bin/tests/wave3-smoke.sh:17`, `bin/tests/wave4a-smoke.sh:17`,
  `bin/tests/wave5-smoke.sh:15`, each in the documented out-variable form `harness_scratch_dir TMP` with a
  `G21 (round-3)` comment above it. The byte-identical bare `TMP="$(mktemp -d)"` / `trap 'rm -rf "$TMP"' EXIT`
  preamble the helper was written to eliminate no longer appears in any of the three.
- `_HARNESS_PLUGIN_DIR` -- four readers: `wave4b-smoke.sh:12`, `wave6-smoke.sh:773`, `wave7-smoke.sh:17`,
  `timing.sh:31`.
- `_HARNESS_REPO_ROOT` -- three readers: `wave6-smoke.sh:18`, `wave7-smoke.sh:18`, `harness-smoke.sh:13`.

The header at `_harness.sh:5-9` no longer contradicts the exports; it now names all three (`TMP via
harness_scratch_dir below, CA-049/G21`) and the `_HARNESS_PLUGIN_DIR` / `_HARNESS_REPO_ROOT` pair explicitly.
The `harness_scratch_dir` trap-body interpolation that L3/L8 raised separately is also corrected to the deferred
form at `:75-76`.

### CA-138 (P2, L2+L4) -- **FIXED** (both halves)

`evals/tiering-matrix.sh`. The denominator is no longer a string constant. `assertions_run` is declared at
`:223`, incremented immediately before each of the six assertion blocks (`:227`, `:238`, `:248`, `:294`, `:301`,
`:310`), and is what both terminal lines print: `:320` `"self-test: PASS (${assertions_run}/${assertions_run}
promotion-rule assertions verified)"` and `:323` `"self-test: FAIL (${failures}/${assertions_run} ...)"`.
Deleting any assertion block now lowers the printed denominator instead of leaving a green `6/6`.

The consumer half landed too: `wave7-smoke.sh:4362` extracts the denominator with
`grep -oE 'self-test: PASS \([0-9]+/[0-9]+' | grep -oE '[0-9]+/[0-9]+' | cut -d/ -f2` rather than matching a
literal string, so the CA-104 boundary pair at `:294-307` is now guarded by something that can see it disappear.

### CA-200 (P2, L2) -- **FIXED** by the second option its own remediation prescribed

`bin/_edm-lint-lib.sh:196-204`. `mermaid_line_set` and `marker_line_set` still have zero external callers --
confirmed by a whole-tree grep across `bin/`, `bin/tests/`, `evals/`, `skills/`, `agents/`, `hooks/` and `docs/`,
which returns only their own definitions and docstrings. But the ledger's prescribed fix was "delete both, **or**
keep them and replace the docstring claim with the real position", and the docstring has been rewritten to the
real position, verbatim honest, at `:51-62`:

> "Honest position on actual callers (G40, corrected -- the prior wording here overstated it): only
> `ignored_line_set` has external callers today ... `mermaid_line_set` and `marker_line_set` have no external
> caller -- `bin/edm-lint-artifacts` is the only consumer that would need them, and it deliberately bypasses all
> three ... They remain for API completeness ... not because a caller currently needs them."

The contradiction that made this a finding -- a library asserting three shared projections exist so three
consumers derive them identically, while the only consumer that needs two of them documents at
`edm-lint-artifacts:254-263` why it refuses to use them -- is resolved in the direction of truth. Both statements
now agree. Carried forward as a NOTED line (N-03) rather than re-raised.

### CA-201 (P2, L2) -- **FIXED** (both halves, both by deletion plus an explanatory comment)

- `bin/edm-check-grants:103-106`: the unreachable `[[ $# -eq 0 ]] || die "unexpected extra argument: $1" 2` is
  deleted. In its place is a `G41` comment stating exactly why no guard belongs there ("every path through the
  if-block above that could leave `$# > 0` already died ... By the time control reaches here `$#` is always 0,
  making a repeated guard unreachable"). The parser at `:88-102` is otherwise unchanged, so the reasoning still
  holds.
- `bin/edm-check-vocabulary:184-188`: the unreachable empty-`FILES` message and its `exit 0` are deleted, again
  with a `G41` comment recording the invariant ("`SCOPE_ROOTS` always includes `CLAUDE.md` and `README.md` as
  plain files ... `FILES` therefore always holds at least those two entries by the time control reaches here").
  Verified against the current `SCOPE_ROOTS` (`:98-107`, still eight roots, two of them plain files) and the
  build loop (`:166-182`, `elif [[ -f "$root" ]]` appends unconditionally, `else` dies).

### CA-202 (P2, L2) -- **FIXED**

`.gitlab-ci.yml:262-263`. The block now reads

```sh
      evals_kb="$(( (evals_bytes + 1023) / 1024 ))"
      if [ "$evals_kb" -gt 100 ]; then
```

with no intervening `${evals_kb:-0}`. The dead defensive default is gone and nothing else in the block changed.

---

## Part 2 -- New findings

### L2-001 (P2, high) -- `_print_literal` is dead, and the comment that keeps it alive names a consumer that does not exist

**File**: `plugins/edm/bin/edm-state:654-656` (the function), `:658-662` (the comment retaining it).

The G38/CA-198 remediation added `_print_line` (`:663-665`) and moved the only production caller,
`write-handoff`, onto it:

```bash
  write_atomic "$handoff_path" _print_line "$handoff_content" || die ...    # :4835
```

`_print_literal` now has **zero call sites anywhere in the repository**. A whole-tree grep returns four hits:
the definition at `:654`, two mentions inside `_print_line`'s own comment at `:658` and `:660`, and one
assertion label in `wave7-smoke.sh:5752`.

The comment that justifies keeping it is factually wrong:

```bash
# _print_line <text> -- sibling of _print_literal, but appends a terminating newline
# (G38). Use this for any write_atomic call whose content is a complete document (e.g.
# HANDOFF.md) that should end with a newline; _print_literal itself is left unchanged
# because a pattern-library splice elsewhere in this file depends on its exact
# no-newline behavior.                                                        # :658-662
```

There is no such splice. The pattern-library writer is `_splice_pattern_file` (`:4283-4288`), invoked at `:4335`
via `write_atomic "$pattern_file" _splice_pattern_file ...`, and it emits its own `printf '%s' "$pending_entries"`
inline at `:4286`. It has never called `_print_literal`. The claim originates in round 3's L1 report, which
prescribed "do NOT change `_print_literal`; the pattern-library splice at `:3988` depends on its exact no-newline
behaviour" -- that premise was mistaken, the remediation faithfully carried it into a shipped comment, and the
result is a retained-for-a-nonexistent-reason dead function.

Why this matters beyond tidiness: the two functions differ by exactly one `\n`, and the surviving comment tells
the next contributor that `_print_literal` is load-bearing for a writer that is one of only two atomic document
writers in the file. A future edit that "restores" a caller to `_print_literal` re-introduces CA-198's
missing-trailing-newline defect on a git-tracked artifact, with the comment appearing to sanction it.

The one shipped assertion does not catch this. `wave7-smoke.sh:5752-5753` is labelled
`"G38 -- _print_line is a distinct sibling of _print_literal, which is left unmodified"` but its needle is the
literal string `_print_line() {` -- it asserts nothing whatsoever about `_print_literal`.

**Fix**: delete `_print_literal` (`:654-656`) and drop the false clause from `:660-662`, leaving `_print_line`
as the single renderer. If it is kept instead, replace the clause with the real position (no current consumer;
retained as the no-newline counterpart to `_print_line`) -- the same honest-docstring remedy CA-200 accepted --
and re-word the `wave7-smoke.sh:5752` label so it stops claiming a check it does not perform.

### L2-002 (P2, medium) -- dead defensive default on a `grep -c` capture, re-introducing the CA-140 / CA-202 class inside Wave 7's own retention fix

**File**: `plugins/edm/evals/run-eval.sh:186-188`.

```sh
  run_dirs="$(ls -1t "$OUT_ROOT" 2>/dev/null | grep -E '^[0-9]{8}T[0-9]{6}Z_' || true)"
  run_total="$(printf '%s\n' "$run_dirs" | grep -c . || true)"
  run_total="${run_total:-0}"                                              # :188 -- can never substitute
```

`printf '%s\n' "$run_dirs"` always writes at least one byte, and `grep -c .` always prints exactly one decimal
integer -- `0` on no match, with the non-zero exit that `|| true` absorbs. The command substitution at `:187`
therefore always yields a non-empty digit string, so the `:-0` default at `:188` has no input that can trigger it.

This is precisely the class the ledger already accepts as a P2 twice: CA-140 (`schema_at_least`'s `-z "$sv"`
disjunct after a `to_int` coercion that always prints) and CA-202 (`${evals_kb:-0}` after an arithmetic
expansion). Both were introduced by a remediation and both were filed. This one was introduced by the G12/G54
`prune_old_runs` remediation in Wave 7 and is the same shape at a new site.

**False Alarm Filter applied.** Criterion 3 (used consistently everywhere in the file) is the only one that could
save it, and it fails on inspection. The file's other `${x:-0}` uses -- `:580-584`, after `jq -r ... 2>/dev/null`
-- are genuinely live, because a `jq` parse failure produces empty output; and `:175-177`'s `case "$keep" in
''|*[!0-9]*)` guards a value that came from a `${VAR:-10}` expansion where the empty alternative is likewise
unreachable but is one alternative inside an idiomatic pattern list, not a standalone statement. `:188` is a
standalone assignment whose entire purpose cannot occur. Not the same shape.

**Fix**: delete `:188`. Confidence is medium only because I could not execute the pipeline here; on every POSIX
shell `grep -c` prints a count or the shell errors.

### L2-003 (P2, medium) -- the `_EDM_TRAP_DEPTH` reentrancy guard is unreachable for the nesting shape its own comment names, and fully inert on the flock branch

**File**: `plugins/edm/bin/edm-state:1120-1124`, with `:1052` (the preempting loop) and `:1012` (the flock branch).

```bash
    # Assert the nesting-depth-one constraint before handing control to the locked body --
    # with_state_lock is not reentrant (a nested call would deadlock on `mkdir` against itself
    # anyway), so a non-zero depth here means a caller is nesting with_state_lock calls.
    [[ "${_EDM_TRAP_DEPTH:-0}" -eq 0 ]] \
      || die "with_state_lock: internal: lock trap already active (_EDM_TRAP_DEPTH=${_EDM_TRAP_DEPTH}) -- nested with_state_lock calls are not supported"
```

`_EDM_TRAP_DEPTH` survives the CA-142 re-fix as a reentrancy detector only. It is set to `1` at exactly one site
(`:1141`), immediately before the fork at `:1143`, and reset at `:1144`. So the guard can only observe a non-zero
depth inside that subshell.

But the guard sits **after** the `until mkdir "$lockdir"` loop at `:1052-1093`, so it is only reached once the
lock has been acquired. Trace the nesting case the comment itself names -- a locked body re-entering
`with_state_lock` on the *same* lockbase:

1. `mkdir "$lockdir"` fails: the outer lock holds it.
2. `$pidfile` holds the parent's `$$`. Bash does not change `$$` in a subshell, so the value is the live parent's
   PID and `kill -0` succeeds at `:1069`.
3. The loop spins 50 times at `0.1s` and dies at `:1090` with
   `"state lock timeout after 50 tries on ${lockdir} (held by PID N)"`.

Control never reaches `:1123`. The self-deadlock the guard exists to name is reported five seconds later as a
lock-contention timeout naming the caller's own PID -- the single most confusing possible diagnostic for that
condition, and the guard that would have named it correctly is unreachable behind the failure it is guarding.

The guard **is** reachable, but only for a case its comment does not describe: a locked body taking a lock on a
*different* lockbase (mkdir succeeds, inherited depth is 1, guard fires). No locked body does this today --
`_rmw_state_body`, `_cmd_init_body`, `_cmd_update_patterns_body`, `_write_handoff_body`,
`_cmd_archive_move_body`, `_cmd_migrate_path_move_body`, `_cmd_audit_round_start_body`,
`_cmd_audit_round_complete_body` and `_cmd_record_partial_verdict_close_body` all use `write_atomic` directly
rather than re-entering the lock, and `:3880` records that discipline explicitly.

Third, an undocumented platform asymmetry: the flock branch (`:1012`) never sets `_EDM_TRAP_DEPTH`, so on a host
with `flock(1)` the guard is inert for *both* nesting shapes. A cross-lockbase nested call is caught on macOS and
silently permitted in CI.

**False Alarm Filter applied.** Criterion 2 (documented intentional safety net) is a genuine partial defence and
is why this is P2 rather than higher -- the guard is explicitly an internal assertion. It does not fully save the
finding, because the documentation is what is wrong: the comment asserts the guard covers a case it structurally
cannot reach, which is the difference between a safety net and a safety net that reads as covering more than it
does.

**Fix**, cheapest correct: move the depth check above the `until mkdir` loop (before `:1052`) so the
same-lockbase self-deadlock is named as reentrancy instead of as a 5-second contention timeout; set
`_EDM_TRAP_DEPTH=1` around the flock branch's subshell at `:1012` too, so both branches behave identically; and
correct the comment at `:1120-1122` to state which nesting shapes the guard actually detects.

---

## Noted / Not Actionable

Carried dispositions, each re-verified at its current line numbers this round.

| ID | File:Line | Rationale |
|---|---|---|
| N-01 | `bin/edm-state:412-483` | **CA-105** holds: no pricing arm matches any live model; D32 records it, T52 AC9 leaves the figures unrepriced, verified rate rows assigned to EDMV4. |
| N-02 | `bin/edm-state` Tiered-vs-Untiered block | **CA-107** holds: gated on `.tiering_results`, which no producer writes; stated in place and recorded in D28. |
| N-03 | `bin/_edm-lint-lib.sh:196-204` | **CA-200, now closed**: `mermaid_line_set` / `marker_line_set` still have zero callers, but `:51-62` now states that position honestly and explains why `edm-lint-artifacts` deliberately bypasses all three. Documented-as-intentional. Do not re-file. |
| N-04 | `bin/edm-state:4283-4288` | **CA-114** holds: `pattern_target_heading_for`'s single `*)` arm is the documented extension point. |
| N-05 | `bin/edm-state` `cmd_migrate_schema` advance-by-one | **CA-119** holds: no-op today, retained as defence against `schema_version: 3`, which CLAUDE.md records as deliberately unassigned. |
| N-06 | `evals/score-artifacts.sh` `cmd_compare` | **CA-120** holds: second comparison implementation CI does not use, retained with the reason stated in place and reachable via `--compare`. |
| N-07 | `evals/tiering-matrix.sh:336-338` | **CA-121** holds: the `--*)` unknown-flag arm cannot see `-h`/`--help` because `:328-335`'s two-stage parse exits first. Deliberate. |
| N-08 | `bin/_edm-lint-lib.sh:153-156` | **CA-122** holds: an `edm-lint-ignore-end` inside a fence still closes the ignore block and its line is emitted in no class; requires a mermaid source line containing that literal HTML comment. |
| N-09 | `bin/tests/run-all.sh:84-88` | **CA-248** holds and is now *more* clearly correct: `_MIN_SUITE_COUNT` is overridable via `EDM_RUN_ALL_MIN_SUITE_COUNT` (`:84`) and `_PREFERRED_ORDER` via `EDM_RUN_ALL_PREFERRED_ORDER` (`:36`), so `harness-smoke.sh` can drive a one-stub scratch set that defeats the name loop and still reaches the floor. Complementary, not subsumed. Do not re-file. |
| N-10 | `bin/_edm-lint-lib.sh:211-214` | `report_violation`'s "expected 4 or 5 args" arm cannot fire today (every call site is statically 4- or 5-arg), but it is an arity guard on a function four shipped binaries consume with two incompatible field orders. Keep. |
| N-11 | `bin/edm-lint-artifacts:358-361` | Class 4 does not test `UNREADABLE_FLAGS` where the other four classes do, but `MERMAID_SETS[$i]` is set to `""` for an unreadable file at `:248`, so `[[ -z "$mermaid_set" ]] && continue` at `:361` is an equivalent guard. Unchanged from round 3's N-20. |
| N-12 | `evals/run-eval.sh:585-588` | The `''` alternative in `case "$in_tok" in ''\|*[!0-9]*)` is unreachable because `:580` already applied `${in_tok:-0}`, but it is one alternative inside an idiomatic pattern list used identically at four adjacent sites and at `:175-177` -- consistent project pattern (filter criterion 3), unlike L2-002's standalone statement. |
| N-13 | `bin/edm-state:3747-3750` | `cmd_audit_converged`'s `convergence_exempt` early return cannot be reached *from `cmd_approve_gate`* -- both of its disjuncts are handled with an earlier return (`:1798-1807`) or `die` (`:1817-1821`). Not dead: `cmd_audit_converged` is a dispatched subcommand in its own right and the guard is live on that entry point. Deliberate layering, documented at `:844-846`. |
| N-14 | `evals/score-artifacts.sh:551-554` | The `complete` out-of-enum coercion looks unreachable because jq's `if/then/else` always yields `"true"` or `"false"`, but a zero-byte `run.json` makes jq read no inputs, emit nothing and exit 0, so `$complete` is `""` and the branch fires. Reachable; correct as written. |
| N-15 | `hooks/hooks.json:86` | `test -n "$srd_root" || exit 0` is reachable after CA-186's normalization: `EDM_SRD_ROOT="./"` or `"/"` both reduce to the empty string through the `#./` strip plus the trailing-slash loop. Not a dead guard. |
| N-16 | `bin/edm-state:340-365` vs `:367-406` | The whole-directory token fallback is reachable by two routes -- an empty/absent `driving_session` (the documented TOCTOU case) and a non-zero exit from the scoped `tail | jq` pipeline, since `:364`'s `&& return 0` only returns on success. Not dead. |
| N-17 | `bin/edm-state:1307-1335` | The new `TORN_TOKEN_LINES` informational anomaly (CA-185's remediation) is live on both surfaces -- `phase_durations` at `:1321-1322` and `audit_rounds` at `:1333-1334` -- and both producers write the field (`:2078`, `:3688`). Wired end to end, not a write-only field. |
| N-18 | `bin/edm-state:591-597` | `write_atomic`'s four early-return guards (usage, missing dest dir, unwritable dest dir, `mktemp` failure) all precede `_save_traps`, so none of them can leave a half-installed trap layer. Reachable and correctly ordered. |
| N-19 | `skills/code-audit/SKILL.md:73-81` | Step 8a's "if a lens's delivered agent definition lacked a `Write` tool this round" branch is not hypothetical -- it is the path this very report is taking. Live, and the highest-value instruction added in Wave 7. |
| N-20 | `agents/edm-audit-dead-code.md` (all eleven lens agents) | **CA-130 reproduces a FOURTH consecutive round.** `Write` was absent from this lens's delivered runtime tool set (delivered set: Read, Grep, Glob, WebFetch, WebSearch, TaskStop) despite the frontmatter grant at `:5`. Unlike round 3, the delivered definition **did** carry the `## Scope`, `## Output` and `## JSONL Line Format` sections matching the on-disk file, so the stale-revision half of CA-130 did not recur -- only the tool-set half. Host-side artifact, not a repository defect; the repository-side mitigation (`skills/code-audit/SKILL.md:73-81`) is now in place and was followed. |

---

## Coverage note

Read in full this round: `bin/_edm-lint-lib.sh`, `bin/tests/_harness.sh`, `bin/tests/run-all.sh`,
`evals/run-eval.sh`, `hooks/hooks.json`, `skills/code-audit/SKILL.md`, `bin/edm-lint-artifacts`'s
`scan_md_files`, `evals/tiering-matrix.sh`'s `self_test` and dispatch, `.gitlab-ci.yml`'s lint stage.
Read in targeted depth: `bin/edm-state` -- the complete lock/atomic-write subsystem (`:470-700`, `:930-1150`),
the token reader (`:277-410`), `cmd_approve_gate` (`:1780-1875`), `cmd_audit_converged` (`:3730-3840`),
`convergence_exempt` (`:826-862`), the pattern-library splice (`:4283-4360`), the anomaly renderers
(`:1300-1340`) and both metrics writers -- plus every call site of every symbol named in an open L2 ledger row,
resolved by whole-tree grep.

**Largest unswept surface, carried from round 3 and still open**: full line-by-line reads of
`bin/tests/wave6-smoke.sh` and `bin/tests/wave7-smoke.sh` bodies (roughly 11,000 lines combined) for dead
assertions and orphaned fixtures. This round swept them by symbol resolution rather than sequential read, which
is what surfaced L2-001's dead function and the mis-labelled assertion guarding it, but it cannot find a dead
assertion whose symbols are all live. L4 remains the better owner of assertion quality; the L2 residue there is
bounded to fixtures and helpers with no callers.

Not opened this round: `agents/**` prose beyond this lens's own definition, `docs/**`,
`monitors/monitors.json` -- prose-only surfaces with no executable branching for this lens.

## Meta

Two things for the parent agent:

1. **CA-142, CA-143 and CA-049 can be closed.** Round 3's L2 explicitly warned "do not close CA-142 or CA-049
   on the presence of their remediation symbols." That caution is now discharged by evidence rather than by
   assumption: CA-142's mechanism was deleted rather than patched, and CA-049's three symbols have nine real
   readers between them. CA-182, CA-138, CA-200, CA-201 and CA-202 close too.
2. **CA-130 needs its fourth-round update.** The tool-set half reproduced; the stale-agent-definition half did
   not. That is a meaningful narrowing of the entry and worth recording, because it means the repository-side
   mitigations (CA-193's literal schema, `skills/code-audit/SKILL.md`'s step 8a) are now the only thing standing
   between this failure mode and a lost lens -- and they held.
