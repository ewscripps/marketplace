# Lens L10: DRY & Redundancy -- Pass 5 (2026-08-09)

## Ledger verdicts

| ID | Sev | Verdict |
|---|---|---|
| CA-276 | P2 | **RESOLVED -- fully converted** (2/2 sites, plus bonus `_TOKEN_SUM_ZERO_JSON` hoist) |
| CA-277 | P2 | **RESOLVED -- fully converted** (2/2 sites) |
| CA-278 | P2 | **RESOLVED -- all three converted** (3/3 sites, matching originals exactly) |
| CA-280 | P2 | **RESOLVED, two residuals** -> L10-002, L10-003 |
| CA-281 | P2 | **CONFIRMED still option (b); endorsed** -> Noted L10-012 |
| CA-279 | P2 | **STILL OPEN, now aggravated** -> L10-005 |

Cross-lens extractions also re-verified complete: `_save_traps`/`_restore_traps` (6/6),
`project_class` (7/7), `print_help` (12/12).

## Findings (L10: DRY & Redundancy)

### L10-001 (P2, high) -- `assert_tree_absent` sweep converted 16 sites, left TEN hand-rolled copies

Ten sites across wave6-smoke.sh and wave7-smoke.sh still use the tautological-control shape
`assert_tree_absent` was built to replace -- two of them sit inside the SAME ticket blocks whose
sibling assertions WERE converted (wave6:2479 four lines below the converted :2469; wave7:1335
twenty-five lines above the converted :1363/:1368). Each surviving copy still carries a
`CA-037: positive control` comment, presenting itself as the remediated shape -- which is why a
contributor adding an eleventh site copies the wrong template.

**Fix**: convert all ten; delete the misleading comments as converted; add a tripwire banning the
hand-rolled shape outside harness-smoke.sh (which legitimately self-tests the older helper).

### L10-002 (P2, medium) -- `timing.sh --subcommands` enumerates one list twice, no default arm

The `for cmd_name in get resolve-dir branch-check gate-check` loop and its `case` re-enumerate the
identical four names with no `*)` arm; `p95`/`p95_samples` persist across iterations. Adding a
fifth subcommand without a matching arm silently prints the fourth's measurement under the new
label -- a plausible wrong number in the file whose header claims every number is real.

**Fix**: drive the loop off one name+args list, or add a loud `*) exit 2` fail arm.

### L10-003 (P2, low) -- `--all-lint` is the last surviving hand-rolled timing loop

Behaviourally identical to `_measure_p95 1 ms -- "$EDM_LINT" --all`; not part of CA-280's original
nine (correctly, it's a single-sample budget mode), but it's the working template a contributor
extending the file reads first.

**Fix**: convert to `_measure_p95 1 ms -- ...`, keep the `duration_ms=` key.

### L10-004 (P2, medium) -- hand-rolled duplicate of the CA-094 freshness guard

`_wave7_assert_shared_lint_fresh`'s docstring claims "every reuse site calls this"; `:4380-4389`
reimplements both its checks inline in the SAME T48 block that also calls the real helper at
`:4461` -- one invariant checked twice via two independently-maintained implementations that don't
even agree on success behavior (inline emits pass lines, helper returns 1 silently on drift).

**Fix**: delete the inline copy; use the helper if a pre-block check is wanted.

### L10-005 (P2, medium) -- CA-279 aggravated: prose gate mapping now contradicts the deterministic one

The five prompt hooks' prose still restates the gate mapping with none of `cmd_gate_check`'s
mode/skipped-phase refinements (CA-279's original point). New this round: CA-253's exit-2 fix made
the command hooks BLOCK on a missing state file, while the prompt copy's text ("or if the state
file does not exist -- first invocation, allow expansion") says the opposite. Two copies of one
policy in the same JSON object now give opposite verdicts.

**Fix**: route the prompt bodies through `edm-state gate-check`; delete the now-false clause
regardless. Fold into one pass with CA-253/CA-279.

### L10-006 (P2, medium) -- `edm-lint-artifacts`'s per-class violation loop is a 4x copy-pasted block

Four 11-line blocks differing only in class literal and producing grep. This exact duplication
already caused CA-008 (P1): the PCRE branch read three fields from a two-field grep, disabling
suppression for the unicode class on the branch CI takes, while macOS took the correct fallback --
fixed by hand on both copies, but the structural risk remains for the next change.

**Fix**: extract `_report_grep_hits <class> <file> <ignore-set> -- <grep-cmd...>` using process
substitution (bash 3.2-safe) so `report_violation` stays out of a subshell.

## Noted / Not Actionable

1. Five UserPromptExpansion command hooks are byte-identical apart from one token; JSON has no
   include mechanism, not actionable.
2. `_lock_retry_or_die`'s dynamic-scoping mutation of the caller's `tries` is documented and
   consistent with `_save_traps`/`_unpack_token_fields`'s convention.
3. `_unpack_token_fields` left a 3-line marshalling block duplicated at both call sites (14->4
   lines, not 14->1) -- mechanical, not semantic, retained as-is.
4. CA-282 re-verified: `cmd_metrics_report`'s two forked renderer arms still byte-identical on
   shared columns -- no drift.
5. CA-283 re-verified: three phase blocks in run-eval.sh still diverge only in placement, every
   path still covered.
6. CA-281/G50 option (b) re-verified and endorsed against revisiting -- hoisting the capture would
   widen a no-mutation invariant across ~1000 lines of scratch-tree blocks; do not revisit.

## Meta

`Write` and `Bash` were absent from this lens's delivered runtime tool set (ledger CA-130, sixth
consecutive round). Delivered system prompt was again a reduced revision missing several sections;
schema read off the on-disk agent definition. Both `lens-L10.md` and `lens-L10.jsonl` were
transcribed by the orchestrator.
