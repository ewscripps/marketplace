# Code Audit Lens L2 -- Dead Code & Unreachable Paths

Round: pass-5 (full, all 11 lenses)

## Headline

**All three L2-tagged open ledger entries verify FIXED**: CA-257 (reentrancy guard), CA-259
(_print_literal), CA-260 (${run_total:-0}), two of three closed by deletion.

**All five Wave 8 extractions are clean** -- checked specifically for the failure mode where a
helper lives alongside surviving copies of the old code, and it did not happen at any of the five
(_TOKEN_SUM_JQ, _unpack_token_fields, _lock_retry_or_die, _measure_p95, _print_line).

Six new P2 findings, five of them Wave 8 residue -- consistent with the round's dominant pattern.

## Part 1 -- Ledger verification

### CA-257 -- FIXED, all three halves
`bin/edm-state:1025-1042`. Guard moved above both acquisition branches; flock branch now arms
`_EDM_TRAP_DEPTH` at :1078; comment rewritten to state accurately what's detected. Verified
reachable: depth is set in the parent before both forks, inherited by the locked body's subshell.

### CA-259 -- FIXED by deletion; one sub-edit didn't land (L2-004)
`_print_literal` gone tree-wide; false retaining comment replaced with an accurate one naming
G28/CA-259. `_print_line` is the sole renderer.

### CA-260 -- FIXED
`evals/run-eval.sh:186-191`. Standalone `${run_total:-0}` deleted, replaced with a comment naming
the class.

## Part 2 -- New findings

### L2-001 (P2, high) -- G30/CA-261's guard cannot discriminate

`bin/edm-state:2835-2841`: the new row-count guard tests `estimated_size != null`, but
`_cmd_init_render:1696` seeds `estimated_size: "Unknown"` -- a non-null string. So the guard is
functionally identical to the file count it replaced. Independently confirmed by L1 and L3.
CA-261's actual symptom (`.phase_durations` empty on init) is untouched.

**Fix**: count the rows the render actually groups (`select(estimated_size != null and != "Unknown") | .phase_durations | to_entries | length`), correct the comment.

### L2-002 (P2, high) -- dead default at a fourth sibling site

`bin/tests/timing.sh:326-327`: `actual_initiatives="${actual_initiatives:-0}"` after a `grep -c`
capture that always prints a digit -- the CA-140/CA-202/CA-260 class, inside the same file G49
edited this wave.

**Fix**: delete line 327.

### L2-003 (P2, medium) -- Wave 8 made the prompt hooks' "first invocation" clause unreachable

`hooks/hooks.json:23,36,49,62,75`: all five prompt hooks still say "allow expansion if the state
file does not exist," but G8/CA-253's exit-2 conversion means the sibling command hook now blocks
that exact case (`read_state` dies on a missing file). Same defect independently confirmed by L1,
L3, L7, L10.

**Fix**: pick one direction for both halves.

### L2-004 (P2, high) -- assertion label names a deleted function

`bin/tests/wave7-smoke.sh:6025-6026`: label claims "_print_literal ... is left unmodified" but the
needle only checks `_print_line() {`. Re-wording this was part of CA-259's own prescription and
didn't land; now the function it references doesn't exist.

**Fix**: reword the label; add a real `check_absent` for `_print_literal() {`.

### L2-005 (P2, medium) -- last_cmd renderers still permanently suppressed

`bin/edm-state:3602`, `:4881`: zero producers anywhere in skills/agents/hooks. G23 fixed the
comment, left the dead code. L2 half of open CA-246 -- merge, don't open a new ID.

### L2-006 (P2, medium) -- current_step vocabulary has one writer

`skills/plan/SKILL.md:53-55`: documents a `1`..`6` vocabulary and claims implement/code-audit/
verify-runtime substitute `6`, but no such instruction exists in any of those skills. Values `2`-`6`
have no producer, so the dispatcher's resume-to-phase-N path is environmentally unreachable.
Co-owned with L11 (CA-194's originating lens).

## Noted / Not Actionable

1. `timing.sh:76-85` -- `_p95`'s index clamps are unreachable today but the formula changed twice
   in two rounds; keep as live defence.
2. `timing.sh:100` -- `_measure_p95`'s arity guard cannot fire from any call site; same class as
   CA-290's accepted arity arm.
3. `timing.sh:110` -- three of eleven call sites never read `<outvar>_samples`; documented generic-
   helper behavior.
4. `run-eval.sh:253-255` -- signal-wrapper exit codes unreachable because cleanup takes exit 4
   first; deliberate per AC10.
5. `_harness.sh:255-256` -- `assert_tree_absent`'s error arm is preempted by the control arm;
   defensive in a loud-failure primitive.
6. `.gitlab-ci.yml:315-316,332-333` -- same dead-default shape as L2-002 but inline in a test
   rather than standalone; the criterion-3 line round 4 already drew.
7. `wave7-smoke.sh:4214` -- positive-p95 pass branch environmentally starved (no perl); CA-262's
   fix didn't land and G16's N=20 made it harder. Route to CA-262, L4 owns.
8. `edm-state:2860-2861` -- second calibrate fallback reachable but misreports its cause;
   wrong-diagnostic half is L1/L6.
9. `edm-state:4280` -- cmd_lint still zero callers; unchanged residual of open CA-247 (L11-owned).
10. `wave7-smoke.sh:4676` vs `:4723` -- two blocks assert the same `_lock_retry_or_die` window
    under different labels; L4/L10 territory.
11. `_edm-lint-lib.sh:196` -- CA-200 unchanged, do not re-file.
12. Carried L2 NOTED set (CA-105,107,114,116,119,120,121,248,290,293) re-verified unchanged.
13. **CA-130 reproduces a fifth consecutive round** -- tool-set half only, stale-definition half
    did not recur.

## Meta

`Write` was absent from this lens's delivered runtime tool set despite the frontmatter grant
(ledger CA-130, fifth consecutive round for L2 specifically). Both `lens-L2.md` and
`lens-L2.jsonl` were transcribed by the orchestrator.

**Note for synthesis**: `findings-ledger.md` is stale relative to `findings-ledger.jsonl` (missing
CA-267 through CA-295, all round-4 entries still show `open`). Run `edm-state render-ledger`
before this round's synthesis.
