# Lens L1 -- Logic, Correctness & Completeness (round 11, full)

Scope this round: re-verification of the eight open L1-tagged ledger entries
(CA-401, CA-453, CA-479, CA-490, CA-491, CA-513, CA-516, CA-518) against HEAD
(0b2f304), plus fix-quality review of the four that landed. Four are fixed and
verified, three are unchanged and still open, one is half-landed.

## Findings (L1: Logic, Correctness & Completeness)

### P2 -- CA-401 (residual): bare `grep -c` captures still abort two suites on a zero count
`plugins/edm/bin/tests/wave6-smoke.sh:296`, `:1205`, `:1222`, `:3638`, `:3645`, `:3657`;
`plugins/edm/bin/tests/wave7-smoke.sh:3946`, `:3953`, `:4021`

PARTIALLY REMEDIATED, and the fixed half should be recorded: the terminal-grep-in-a-pipeline
shape CA-401 named first (`$({ grep -oE ... || true; } | head -1 | grep -oE '^[0-9]+')`) is
GONE -- a repo-wide search for `head -1 | grep -oE` and `head -1 | grep -o ` across
`plugins/edm/bin/tests/` returns zero matches. `count_matches` is now used 68 times across four
suite files.

What survives is the second shape L1 originally contributed: a bare command-substitution capture
of `grep -c` with neither `|| true` nor `count_matches`. `grep -c` always PRINTS a count, so the
value is fine; the exit status is 1 on zero matches, the assignment inherits it, and
`wave6-smoke.sh:6` is `set -euo pipefail`. Six of the nine sites grep the live `bin/edm-state`
for a symbol, so a rename kills the suite at that line and discards every later assertion instead
of producing the one-line fail the assertion exists to give:

- `:296` -- `cadef_hits="$(grep -c 'code_audit_required_for_mode "' "$EDM_STATE")"`
- `:1205` -- `gate_is_approved_callers="$(grep -cE 'gate_is_approved "|gate_required_and_approved "' "$EDM_STATE")"`
- `:1222` -- `ca417_callers="$(grep -cE 'skipped_phases_str "' "$EDM_STATE")"`
- `:3638` -- `t28_bf_def_count="$(grep -c '^BLOCKING_FILTER=' "$EDM_STATE")"` (the exact
  BLOCKING_FILTER example CA-401's round-8 text used)
- `:3645` -- `t28_bf_invoke_count="$(grep -c '\$BLOCKING_FILTER' "$EDM_STATE")"`
- `:3657` -- `t28_cac_callers="$(grep -c 'cmd_audit_converged "\$prefix"' "$EDM_STATE")"`

The three `wave7-smoke.sh` sites (`grep -c '^### '` at `:3946`, `:3953`, `:4021`) count headings
in a scratch fixture the test itself writes, so reaching zero requires the fixture template to
change -- same shape, lower reachability, listed for completeness rather than as an equal risk.

Fix: route all nine through `count_matches` (the helper already exists and is the project's
consistent convention -- e.g. `wave6-smoke.sh:639`, `wave7-smoke.sh:3298`), using
`count_matches_strict` plus an exit-status assertion at the six `$EDM_STATE` sites where a
symbol's disappearance must not read as a passing zero.

### P2 -- CA-453: the four prescribed gates-approved assertions still do not exist
`plugins/edm/bin/tests/wave6-smoke.sh` (absent cases), covering
`plugins/edm/bin/edm-state:5754`, `:5772`, `:5938` and the rendered line at `:6110`

UNCHANGED since round 8; re-verified three ways at HEAD. (a) `required_gate_count` -- the
denominator variable, at `edm-state:5754`/`:5772` and rendered at `:6110` as
`- **Gates approved**: ${gates_count} of ${required_gate_count}` -- appears in NO file under
`bin/tests/`. (b) The string `Gates approved` appears in `bin/tests/` exactly once, at
`wave6-smoke.sh:655`, and it is a COMMENT, not an assertion. (c) The reconciling note text
built at `edm-state:5938` (`_Note: N approval event(s) recorded above for M distinct gate(s)...`)
has no assertion anywhere. Note the ledger's `component` field is now stale: the rendered line
moved from `:5531` to `:6110`.

So both the CA-389 and CA-390 code halves remain uncovered, and the class has now regressed twice
(CA-335 -> CA-389/CA-390). Fix is unchanged from the ledger: add the four cases beside the
existing G13/CA-391 block at `wave6-smoke.sh:660-666` -- prototype renders denominator 1;
fast-track with phases 1/2/3/5 skipped renders 0 and not 3; `approve-gate 1, 2, 1` renders
numerator 2 of 3 (distinct gates, not approval events); and the reconciling note text appears in
the same HANDOFF.

### P2 -- CA-491: the CA-441 Task-grant rule still has no must-fail case
`plugins/edm/bin/tests/wave7-smoke.sh:370-401` (absent case), covering
`plugins/edm/bin/edm-check-grants:512-523`

UNCHANGED since round 9. The rule is intact and has moved to `edm-check-grants:512-523` (ledger
says `:506-517`). Its trigger at `:515` is
`grep -qiE '(^|[^a-zA-Z])spawn[^a-zA-Z].*edm-|^Agent: edm-'` and the report call at `:522` is
`mark_and_maybe_report skill "$skillname" Task "$f" "$task_ln"`. Coverage at HEAD: `t03_ac6_case`
(`wave7-smoke.sh:370-401`) asserts only `missing-askuserquestion-grant` (`:397`), and a repo-wide
search of `bin/tests/` for `CA-441`, `Task grant`, `task_grant`, `missing-task` and `MISSING_TASK`
returns nothing. Because CA-441's own fix granted `Task` to every skill that needs it, `:521`'s
condition is false everywhere on the live tree, so `mark_and_maybe_report` is never reached and
the `edm-check-grants exits 0` family of assertions passes identically whether the rule works or
does not exist.

Both folded-in limits also still hold verbatim: `:517` derives the reported line from a
whole-file `grep -niE` while the trigger is derived from `$body`, so a reported line can land in
frontmatter (byte-identical to the AskUserQuestion rule at `:500`); and `:515`'s spawn
alternative requires the verb and the `edm-` prefix on ONE line, so a multi-line spawn
instruction escapes it. The `^Agent: edm-` alternative still has no control proving it can match
at all.

Fix: clone `t03_ac6_case` for the Task rule -- strip the `Task` grant from a scratch copy of one
skill that carries a spawn instruction, assert exit 1 and the reported failure class name -- plus
one synthetic control line per regex alternative, each failing by alternative name.

### P2 -- CA-518 (residual): the code half landed, the prescribed pin did not
`.gitlab-ci.yml:322-333` (fixed), `plugins/edm/bin/tests/wave7-smoke.sh` (absent case)

The code half is FIXED and matches the prescription exactly: `.gitlab-ci.yml:329` now computes
`WELLFORMED` with the prescribed `select(.command | type=="string" and length > 0)` narrowing,
and `:330-333` fails the job naming both numbers. A hook declaring `{"type":"command"}` with no
`.command` key can no longer reach `bash -n`/`shellcheck` as the four-byte string `null`.

The test half did not land. No file under `plugins/edm/bin/tests/` references `WELLFORMED` or
`EXPECTED_COUNT` -- so deleting `:329-333` tomorrow turns nothing red, exactly the condition
CA-518's own fix text called out ("there is no assertion today that would turn red"). This is the
CA-453 shape at a new site, on a `needs: []` job with no `allow_failure` guarding the plugin's
most privileged shell.

Fix: add the prescribed wave7 case -- copy `hooks/hooks.json` to scratch, delete one `.command`
key, run the same two `jq` expressions the job body uses, and assert `WELLFORMED != EXPECTED_COUNT`.
The suite already has the pattern for asserting against `$GITLAB_CI_YML` (e.g.
`wave7-smoke.sh:1378`) and for extracting hook commands with the indexed `jq` walk
(`wave7-smoke.sh:5520`, `:7109`).

## Verified Fixed This Round (no longer findings)

- **CA-479 -- FIXED**, `plugins/edm/bin/edm-state:4629-4651`. Pass-directory resolution now
  collects every `pass-${round_num}_*` match into `_pass_cands`, warns naming ALL of them when
  the count exceeds one, and selects the newest by `-nt` instead of keeping whatever the glob
  yielded last. Fix quality checked on three axes and all pass: the no-match case leaves the
  array empty so `_pass_dir` stays `""` and the `[[ -n "$_pass_dir" && -f "$_manifest" ]]` guard
  at `:4653` preserves the C-4 carve-out; the unmatched-glob literal is rejected by the
  `[[ -d ]]` test at `:4640`; and it is bash-3.2/`set -u` safe, because the only expansion
  reachable with a possibly-empty array is the count form `${#_pass_cands[@]}` -- `${_pass_cands[*]}`
  (`:4643`) and `${_pass_cands[@]}` (`:4644`) are both inside the `-gt 1` branch and `[0]`
  (`:4650`) is inside the `-eq 1` branch. Ledger `component` is stale (`:4453` -> `:4626`).

- **CA-490 -- FIXED**, `plugins/edm/bin/edm-compare-eval:62-75`. Refusal condition 3 (the
  `complete:false` handshake) now sits ABOVE the baseline-existence check, which moved to `:77-81`
  and keeps its exit-3 meaning. The `has("complete")` form at `:70` is correct and its comment
  correctly explains why `.complete // "null"` would be wrong (jq's `//` treats `false` as empty).
  Pinned by `wave7-smoke.sh:9241-9255`, which asserts exit 2 with no baseline present, asserts the
  message names the `complete:false` condition, and `check_absent`s the NOT-ARMED message -- so the
  two remediation comments (`.gitlab-ci.yml`, `plugins/edm/CLAUDE.md:1066`) now describe a
  reachable path.

- **CA-513 -- FIXED**, `plugins/edm/bin/edm-state:5317-5342`. All three hand-rolled column-1
  fence trackers are gone: `infence` has ZERO occurrences in `bin/edm-state`. The function now
  computes `ignored_line_set "$_pxt_report"` once (`:5342`) and passes it as a skip set, which is
  the same de-indenting, run-length-aware, `edm-lint-ignore`-honouring classifier
  `pattern_insert_line_for` (`:5452`) and `cmd_update_patterns` (`:5515`) use, so the parity the
  comment asserts now actually holds. Both prescribed regression cases exist:
  `wave7-smoke.sh:4308` (heading inside an INDENTED fence is not extracted), `:4310` (heading
  inside a 4-backtick-quoting-3-backtick fence is not extracted), and `:4312` (the real finding
  after the nested-fence block IS extracted -- proving the state machine did not desync).

- **CA-516 -- FIXED**, `plugins/edm/bin/edm-state:5385`. The qc arm is now the prescribed
  alternation, byte-for-byte:
  `NF >= 2 && ($0 ~ /^\*\*Finding\*\*:/ || $0 ~ /^\[[A-Za-z0-9]+\][ \t]+[A-Za-z0-9_-]+-T[0-9]+[ \t]*\|/)`,
  so a shard auditor following the unlabelled `## Finding Format` spec no longer extracts zero
  titles forever. Pinned by `wave7-smoke.sh:4407-4446`, including the positive control at `:4445`
  (a bracketed-severity line missing the pipe shape extracts nothing).

## Noted / Not Actionable

1. **`plugins/edm/bin/edm-state:5772`** -- `required_gate_count="$(printf '%s\n' "$required_gates_output" | grep -c .)"`
   is a `grep -c` in a command substitution in production code under `set -euo pipefail`
   (`edm-state:54`), i.e. the CA-401 shape. Not actionable: the `[[ -z "$required_gates_output" ]]`
   branch at `:5766` guarantees the input is non-empty before this line is reached, so `grep -c .`
   cannot exit 1 here, and the comment at `:5756-5764` documents that reasoning explicitly as the
   CA-389 fix. (Filter 2.)

2. **CA-516's document-reconciliation half** (`agents/edm-qc-auditor.md:59-63`,
   `skills/implement/SKILL.md:122-126` still carry the unlabelled finding-line form). Not
   actionable: the fix took the accept-both-shapes branch of CA-516's own prescription, so two
   documented shapes is now the intended contract the code implements rather than a drift.
   (Filter 1.)

3. **`.gitlab-ci.yml:355`** -- the `COUNT` vs `EXPECTED_COUNT` cross-check is a tautology, since
   `COUNT` is incremented in lockstep with `IDX` at `:337-338` before any work happens. Not
   actionable: the comment at `:310-311` states this deliberately as a structural rather than
   post-hoc invariant, and CA-518 already declined to file it. (Filter 2.)

## Coverage gaps in this round

Round 11's L1 pass was scoped to re-verification of the eight assigned open entries and the
fix-quality review above. It did NOT include a fresh-eyes logic sweep of the ~530 lines added to
`plugins/edm/bin/edm-state` since round 10 outside the `pattern_extract_titles` /
`cmd_audit_round_complete` / `write_handoff` regions touched by the assigned findings. A
subsequent round should treat `bin/edm-state` as unswept for new L1 defects.
