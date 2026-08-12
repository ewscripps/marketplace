# Lens L1: Logic, Correctness & Completeness -- Round 7

**Tooling note (CA-130's class, eighth consecutive round):** delivered tool set
was Read, Grep, Glob, WebFetch, WebSearch, TaskStop -- no Write, Edit, or Bash.
This report was transcribed by the orchestrator from the lens agent's final
message. Bash also absent, so **suite greenness is NOT independently confirmed
by this lens**; every finding below is derived from static reading of the
current tree at `edm/edmv3-prompt-streamline` @ `4022300`.

**Scope read:** `plugins/edm/bin/edm-state` (targeted: 54-130, 540-780,
780-960, 1040-1420, 1790-2230, 3180-3400, 3480-3600, 3685-3881, 4225-4395,
4985-5210, 5330-5390), `plugins/edm/hooks/hooks.json` (all),
`plugins/edm/bin/tests/_harness.sh` (all), `bin/tests/wave6-smoke.sh` +
`bin/tests/wave7-smoke.sh` (targeted: the round-6 fix assertions and the
count-collapsing sweep), `plugins/edm/CLAUDE.md`, plus a full-tree
incompleteness-marker sweep across `bin/`, `hooks/`, `evals/`, `skills/`,
`agents/`, `docs/`.

## Findings (L1: Logic, Correctness & Completeness)

### L1-001 -- P1 -- `plugins/edm/hooks/hooks.json:23, :36, :49, :62, :75`

**Round 6's own G12/CA-345 fix introduced this.** All five
`UserPromptExpansion` **prompt** bodies still carry, at step 4:

> `4. Otherwise run `edm-state gate-check <PREFIX> srd` (...). If it exits
> non-zero, BLOCK the expansion and show the user its stderr diagnostic
> verbatim`

Their sibling **command** hooks (`:19, :32, :45, :58, :71`) were rewired in
round 6 to the opposite contract:

```bash
edm-state gate-check "$prefix" srd; ec=$?; if [ "$ec" -eq 3 ]; then exit 2; fi; exit 0
```

`cmd_gate_check` (`bin/edm-state:3518`, `GATE_CHECK_REFUSED=3`) returns `3`
**only** for a genuine unapproved gate, and `1` for every setup/usage failure.
The command hook therefore allows expansion on any non-refusal; the prompt
beside it instructs the model to block on any non-zero. `plugins/edm/
CLAUDE.md`'s "Hooks behavior" row states the contract as: *"a missing
`edm-state` binary or an unresolvable prefix ... exits 0, non-blocking; an
invalid prefix argument or an actual `edm-state gate-check` refusal exits 2,
blocking. **Only a real gate refusal blocks -- a setup condition never
does**."* The prompt violates that row.

The prompt's own step 3 (`resolve-dir`) covers only the missing-state-file
case. The remaining reachable divergences are exactly the cases
`wave7-smoke.sh` now asserts the command hook must **allow**:
- **Case D, `wave7-smoke.sh:6491-6506`** -- `require_jq` dies on a host
  without jq (exit 1). Command hook: exit 0. Prompt: BLOCK.
- **`wave7-smoke.sh:6527-6558`** -- `record_degraded_check`'s write lock is
  contended and `with_state_lock` dies with the timeout (exit 1, the
  G9/CA-339 legacy-first-invocation path). Command hook: exit 0. Prompt:
  BLOCK.
- Corrupt/unreadable `.edm-state.json`: `mode="$(echo "$state" | jq -r
  '.mode // "null"')"` (`bin/edm-state:3556`) fails the assignment under
  `set -e` -> exit 1. Command hook: exit 0. Prompt: BLOCK.

Before round 6 the command hook was `gate-check ... || exit 2`, so the
prompt's "any non-zero" clause was *correct*. The fix changed one of the two
layers only. This is the same shape CA-298 was filed for, now inverted.

**Concrete fix** -- replace step 4 in all five prompt bodies (the token
varies per matcher) with the refusal-code-specific form, so the advisory
layer resolves the same contract the binary does:

> `4. Otherwise run \`edm-state gate-check <PREFIX> srd\` (resolves the
> correct gate number from the initiative's mode and skipped_phases -- never
> hardcode one here). Exit code 3 is its dedicated gate-refusal status and is
> the ONLY status that blocks: BLOCK the expansion and show the user its
> stderr diagnostic verbatim (it already names the missing gate and the
> exact remediation command). Exit 0 allows expansion. ANY OTHER non-zero
> status is a setup or usage error (missing jq, a contended state lock, an
> unreadable state file) and must NOT block -- allow expansion and report the
> diagnostic without refusing.`

Then extend `ca253_gate_hooks_exit2_case` (`wave7-smoke.sh:6373`) with a
per-matcher assertion over the `prompt`-type hook text: `check_absent "...
prompt no longer says any non-zero blocks" "If it exits non-zero, BLOCK"`
plus `check "... prompt names exit code 3 as the sole blocking status" "Exit
code 3"`. The prompt bodies are currently asserted for the `(read-only)`
parenthetical only (`:6623`), so nothing pins this clause today.

### L1-002 -- P2 -- `plugins/edm/bin/edm-state:5049-5051`

Round 6's CA-335 fix for the hardcoded HANDOFF denominator is correct for 3 of
5 lifecycle configurations and **still renders `3` for the two that need
`0`**, because its error fallback cannot distinguish "the derivation failed"
from "the derivation legitimately returned zero gates":

```bash
required_gate_count="$( (required_gates_for_mode "$mode" "$lifecycle_mode" "$skipped_for_count" \
    | grep -c . ) 2>/dev/null || echo 3 )"
[[ "$required_gate_count" =~ ^[1-9][0-9]*$ ]] || required_gate_count=3
```

`gated_phase_for_gate` (`:774`) maps gate 1->phase 1, gate 2->phase 3, gate
3->phase 5. `skills/tickets/SKILL.md:145-148` records `skip-phase 1`, `2`,
`3`, `5` for `lifecycle_mode=fast-track|fix-pack`, so **all three gated
phases are skipped** and `required_gates_for_mode` emits nothing. `grep -c .`
then prints `0` *and exits 1*, so under `pipefail` the `|| echo 3` arm also
fires: the captured value is the two-line string `0\n3`, the
`^[1-9][0-9]*$` test fails, and the denominator lands on `3`. A fast-track
initiative renders `- **Gates approved**: 0 of 3`, telling a teammate three
gates are outstanding on a lifecycle that requires none.

Re-derived for every configuration: `standard`->3 (correct), `prototype`+
`skip 3 4 5 6`->1 (correct, fixed by CA-335), `mini-srd`+`skip 4 5`->2
(correct, fixed), `fast-track`->3 (**wrong, should be 0**), `fix-pack`->3
(**wrong, should be 0**). Widening the regex to `^[0-9]+$` alone does **not**
fix it -- the value is `0\n3`, not `0`.

**Durability half:** no test anywhere asserts this line. A tree-wide grep for
`Gates approved`, `required_gate_count` and `of 3` across `bin/tests/`
returns only two unrelated fixture hits (`fixtures/code-audit/lens-L1.
{jsonl,md}`, a "retry count of 3" fixture finding). Round 6's own
recommendation ("Add one assertion pinning `1` as the denominator for a
`prototype` initiative and one pinning that a double `approve-gate 1` still
renders `1 of N`") did not land, so the whole fix is uncovered and a future
edit can revert it to a literal with no test failing.

**Concrete fix** -- separate the two outcomes by testing the *function's*
status, not the pipeline's:

```bash
  local skipped_for_count required_gate_count required_gates_list
  skipped_for_count="$(echo "$state" | jq -r '[(.skipped_phases // [])[].phase] | join(" ")')"
  if required_gates_list="$(required_gates_for_mode "$mode" "$lifecycle_mode" "$skipped_for_count" 2>/dev/null)"; then
    required_gate_count="$(printf '%s' "$required_gates_list" | grep -c . || true)"
  else
    # hand-edited invalid mode/lifecycle_mode: terminal_phase_for_mode died -- fall back to
    # the standard three rather than aborting the locked HANDOFF write.
    required_gate_count=3
  fi
  [[ "$required_gate_count" =~ ^[0-9]+$ ]] || required_gate_count=3
```

and add three `wave6-smoke.sh` assertions beside the existing
`required_gates_for_mode` cases (`:202-240`): `prototype` renders `of 1`,
`fast-track` renders `of 0`, and a double `approve-gate 1` still renders
`1 of `.

### L1-003 -- P2 -- `plugins/edm/bin/edm-state:5024` vs `:5146-5152`

CA-335's other half deduped the HANDOFF **numerator** but not the HANDOFF
**gate list**, so one generated document now carries two disagreeing counts
of the same thing.

`:5024` -- `gates_count="$(echo "$state" | jq -r '[(.gates_approved //
[])[].gate] | unique | length')"` (distinct gates).
`:5146-5152` -- `gate_list_numeric` maps `(.gates_approved // [])` with no
`unique`, emitting **one row per entry**.

`cmd_checkpoint`'s drift path explicitly instructs re-approval ("re-approve
Gate 2 before creating tickets"), so after a documented re-approval
HANDOFF.md's `## Current Status` reads `- **Gates approved**: 2 of 3` while
its own `## Gates` section three headings later lists three rows (`Gate 1`,
`Gate 2`, `Gate 2`). The fix comment at `:5016-5022` reasons about
`gates_count` and `last_gate` explicitly and never mentions
`gate_list_numeric`, so this is an overlooked site rather than a sanctioned
divergence.

There are now **three** counting conventions for one field: deduped
(`:5024`), per-event (`:5146`), per-event (`cmd_metrics_report`, `:2619`
rendered at `:2661` as `gates_approved: N`; and `cmd_list`, `:2010` rendered
at `:2015/:2018` as `gates_approved=%d`). The two `gates_approved`-labelled
renderers are defensible -- the label *is* the array field name -- but the
two inside one HANDOFF document are not.

**Concrete fix** -- keep the per-event list (the approval audit trail is
genuinely useful) and make the mismatch self-explaining rather than silent.
At `:5380` change the heading and add a reconciling note only when the two
differ:

```bash
  local gate_history_note=""
  local gate_entry_count
  gate_entry_count="$(echo "$state" | jq -r '(.gates_approved // []) | length')"
  if [[ "$gate_entry_count" -gt "$gates_count" ]]; then
    gate_history_note="_(${gate_entry_count} approval events across ${gates_count} distinct gate(s) -- a gate re-approved after drift detection appears once per approval.)_"
  fi
```
render `## Gates (approval history)` at `:5380` and `printf '%s\n\n'
"$gate_history_note"` when non-empty. Add a `wave6-smoke.sh` case: after
`approve-gate 1`, `approve-gate 2`, `approve-gate 2`, assert HANDOFF.md
contains both `2 of 3` and the reconciling note.

### L1-004 -- P2 -- `plugins/edm/bin/edm-state:2128`

`cmd_approve_gate`'s numeric-gate validation accepts any non-negative
integer:

```bash
[[ "$gate" =~ ^[0-9]+$ ]] || die "approve-gate: gate-num must be numeric; got: $gate"
```

There are exactly three numeric gates (`gated_phase_for_gate` at `:774`
returns `null` for anything else; `required_gates_for_mode` at `:829`
iterates `for g in 1 2 3`). `edm-state approve-gate FOO 0` or `... 7`
therefore appends `{gate: 0}` / `{gate: 7}` to `gates_approved` and exits 0
with `approved gate 7 for FOO`. Consequences: no enforcement path ever looks
for it (`gate_is_approved`'s `select(.gate == $g)` never matches), but
CA-335's new `unique | length` numerator **does** count it -- a stray
`approve-gate FOO 7` on a prototype initiative renders `- **Gates
approved**: 2 of 1`. `last_gate` (`:5025`) renders `Gate 7 - approved ...`,
and the `## Gates` list gains a permanent phantom row.

This is an outlier against the file's own convention: `cmd_phase_start`
validates `^[1-6]$` (`:2144`, added by CA-157 for exactly this reason) and
`cmd_skip_phase` validates the same range. The `--help`/usage string
(`:2025`) enumerates the enum as `<gate-num>|3.5|code-audit` without stating
the range, so nothing documents `7` as legal.

**Concrete fix:**

```bash
[[ "$gate" =~ ^[123]$ ]] || die "approve-gate: gate-num must be 1, 2 or 3 (or 3.5 / code-audit); got: $gate"
```

and a `wave6-smoke.sh` `check_refuses_and_leaves_state` case for
`approve-gate <PFX> 7` and `approve-gate <PFX> 0`, asserting the state file
is byte-unchanged.

### L1-005 -- P2 -- `bin/tests/wave6-smoke.sh:1543`; `bin/tests/wave7-smoke.sh:1784, :2953, :4289`

Four assertion sites bypass the harness's own `count_matches` and
reintroduce the exact defect it exists to prevent, producing a malformed
two-line value:

```bash
claude_md_hits="$(grep -c 'migrate-schema' "${SCRIPT_DIR}/../../CLAUDE.md" 2>/dev/null || echo 0)"
[[ "${claude_md_hits:-0}" -ge 1 ]] && pass ... || fail ...
```

On no match (or a missing/renamed file -- grep exit 2), `grep -c` prints `0`
**and** exits non-zero, so `|| echo 0` also fires and the captured value is
`0\n0`. `[[ "0\n0" -ge 1 ]]` is not a false comparison -- it is a bash
**arithmetic syntax error** on the embedded newline, so the assertion
reports as `FAIL` accompanied by a raw `bash: 0: syntax error in expression`
on stderr rather than the intended named failure. `_harness.sh:186-190`
ships `count_matches` precisely so "a regression becomes one failed
assertion, not a crashed suite", and `wave7-smoke.sh:2961` uses it correctly
eleven lines below one of the offenders.

Direction is safe (all four are expect->=1 assertions, so they fail rather
than falsely pass), which is why this is P2 and not higher -- but a
maintainer debugging a genuine `CLAUDE.md` regression gets an arithmetic
error instead of `FAIL: AC9 -- migrate-schema not found in plugins/edm/
CLAUDE.md`.

**Concrete fix** -- at all four sites, replace `"$(grep -c PATTERN FILE
2>/dev/null || echo 0)"` with `"$(count_matches PATTERN FILE)"`; at
`wave7-smoke.sh:1784` and `:4289`, where a missing file would also read as a
passing-shaped zero, prefer `count_matches_strict` and assert its exit
status alongside the printed count (the `assert_tree_absent` pattern at
`_harness.sh:264-265`).

## Noted / Not Actionable

1. **Zero unresolved incompleteness markers in production code.** Full-tree
   sweep for `TODO|FIXME|HACK|XXX`, `NotImplementedError`, `not
   implemented`, `unimplemented`, `placeholder`, `stub`, bare `pass`, and
   empty `catch`/`except`. Every hit is legitimate:
   `bin/tests/fixtures/mermaid/valid/v03-comment-semicolon.md:9` (`%% TODO`
   *is* the fixture under test); `evals/fixtures/tiny-svc/src/worker/
   processor.js:18` (deliberately-defective eval fixture);
   `bin/edm-state:4811` + `docs/audit-patterns/README.md:42` (the
   pattern-library append schema's specified stub text, awaiting human
   curation by design); `bin/edm-state:519-521` and `:1397` (placeholder
   *pricing* and a real constant, both explained in place);
   `bin/edm-state:993` (a comment recording that a former T08 stub was
   replaced); `skills/implement/SKILL.md:67,193,264` and
   `agents/edm-audit-spec.md:41` (prohibitions on stubs, i.e. the rule
   text). No function in `bin/`, `hooks/` or `evals/` returns hardcoded data
   in place of a real computation.
2. **G25/CA-342's computed assertion re-derived independently and is exactly
   right.** `wave7-smoke.sh:4270-4279` asserts 6 `schema_at_least "` call
   sites and 5 `# requires schema_version >= ` comment lines. Counted from
   the tree: call sites at `:2099, :2161, :2219, :2746, :3558, :4263` (6);
   comment lines at `:2150, :2212, :2743, :3508, :3549` (5). Four call
   sites carry a comment (`cmd_phase_start`, `cmd_phase_complete`,
   `cmd_archive`, `cmd_gate_check` -- which has two, a docstring-level one at
   `:3508` and an inline one at `:3549`, hence 5 comments for 4 sites); the
   two without are `cmd_approve_gate`'s precheck and `cmd_audit_converged`,
   exactly as `CLAUDE.md:843-854` states. The `check "... states the
   corrected 6-call-site/2-missing split" "Four of the six"` needle matches
   `CLAUDE.md:843`.
3. **`_git_lock_age_bucket_label` (`bin/edm-state:3709`) re-derived from
   scratch: correct and monotone.** `age_min` 0->"less than 1 minute",
   1->"at least 1 minute", 2->"more than 1 minute(s)", 5->"more than 1
   minute(s)", 6->"more than 5 minute(s)", 60->"more than 30 minute(s)",
   61->"more than 60 minute(s)", 121->"more than 120 minute(s)". No
   off-by-one; every boundary uses strict `>` against the bucket and the
   `>= 1` floor arm closes the 1-minute gap.
4. **CA-335's `die`-containment reasoning holds.** `_write_handoff_body`
   runs inside `with_state_lock` (`:4998`), but `required_gates_for_mode`'s
   `terminal_phase_for_mode` `die` (`:815`) fires inside the `$( ( ... |
   grep -c . ) )` command substitution's own subshell, so `exit` never
   reaches the locked body and the lockdir/flock release path is
   unaffected. The comment at `:5044-5046` is accurate.
5. **`_rmw_state_body:718`** -- `[[ -f "$f" ]] && cp -p "$f" "${f}.bak"`
   under `set -e`. Not an errexit abort: the failing `[[` is a non-final
   member of an `&&` list (bash's documented exemption) and is not the
   function's last statement. Consistent idiom throughout the file.
6. **`with_state_lock`'s negative-age path** (`:1291`, `(( _lockdir_age_s >=
   1 ))` with a future mtime from clock skew) refuses to reclaim. Fails in
   the documented refuse-on-unknown direction that G45/CA-318 established;
   not a defect.
7. **`cmd_git_lock_check:3832`** -- `awk -v me="$$" -v parent="$PPID"`
   inside `$( )`. Correct: bash does not reset `$$` or `$PPID` in a
   subshell, so both name the real `edm-state` process as intended.
8. **`bin/edm-state:4281-4284`** -- `jq -r 'FILTER' -s FILE` places `-s`
   after the filter, unlike the conventional `jq -s 'FILTER' FILE` at
   `:4359`. jq accepts options in any position; stylistic only.
9. **`bin/edm-state:2114-2115`** -- `initiative_dir_for "$prefix"` evaluated
   twice (test, then assignment). Redundant work, not a correctness issue.
10. **`_harness.sh:113`** -- `trap 'rm -rf "$dir"' EXIT INT TERM`
    references a `local`, which the file's own comment at `:76-83` warns
    against. Safe here and documented at `:95-97`: `with_scratch_repo`
    clears the trap at `:142` before returning, so the trap can only fire
    while its own frame is live.
11. **`bin/edm-state:4080`/`:4289`** -- `audit-converged`'s invalid-status
    filter accepts `deferred` while the diagnostic enumerates
    `open|fixed|noted`. Deliberate (`BLOCKING_FILTER` at `:1469` coerces
    `deferred`->open per EDMV3-T25 AC4); already round-6 NOTED. Do not
    re-file.
12. **`bin/edm-state:2942-2943`** (`--calibrate` upper median),
    **`edm-validate-prefix:80`** (doubled slash), **`edm-lint-artifacts:
    365-402`** (missing but behaviourally-redundant `UNREADABLE_FLAGS`
    guard), **`edm-state:485-494`** (`unknown` arm position, sanctioned by
    D32), **`pattern_target_heading_for`** (CA-114), **`edm-compare-
    eval:47-50`** (CA-289), **`edm-check-grants:437-443`** (unused `ln`) --
    all re-verified unchanged and still correctly NOTED from rounds 5-6.

## Round-6 L1 closure spot-checks (re-verified against the tree, not trusted from the ledger)

- **L1-001 / CA-335 -- PARTIALLY FIXED.** Numerator dedup landed correctly
  (`:5024`). Denominator derivation landed and is correct for
  `standard`/`prototype`/`mini-srd`, **wrong for `fast-track`/`fix-pack`** --
  see L1-002. The gate *list* was not deduped -- see L1-003. No test
  coverage landed -- see L1-002's durability half.
- **L1-002 / CA-088's division-by-zero in `evals/score-artifacts.sh`** --
  not re-read this round (no Bash to run the scorer, and the file fell
  outside the four priority files); carry forward for a Bash-capable pass.
- **L1-003 / CA-340 -- FIXED.** `bin/edm-init:169` now re-points by name
  ("G10/CA-340 (round 6): re-pointed by name, not line number"), and
  `wave7-smoke.sh:7794-7849` adds a shape-restricted ban on new
  file-and-line citations in comments, with a working positive control and
  a proven-non-tautological allowlist filter (both directions asserted at
  `:7845-7849`).
- **G12/CA-345 -- FIXED in the command hooks, REGRESSED in the prompt
  bodies.** See L1-001.
- **G13/CA-347 -- FIXED.** The timeout-marker probe is now gated on
  `_lock_ec -eq 99` *first* (`:1217-1218`), so a pre-planted unremovable
  marker can no longer misreport a successful locked write as a timeout;
  the secondary `mkdir`-failed arm at `:1224` still names the timeout
  rather than leaking a bare 99.
- **G23/CA-343 -- FIXED, genuinely single-sourced.** `skipped_phases_str`
  (`:845`), `gate_is_approved` (`:854`) and `gate_required_and_approved`
  (`:874`) exist and are the only definitions; `cmd_phase_start` (`:2174`),
  `cmd_gate_check` (`:3567`) and `cmd_archive` (`:2768-2774`) all route
  through them. `COVERAGE_EPIC_ROW_JQ_DEF` (`:1071`) closes the per-epic
  renderer divergence and is consumed by both `:3321` and
  `cmd_get_coverage`.
- **G45/CA-318 -- FIXED.** `with_state_lock:1290` now calls the shared
  `_git_lock_age_seconds` and has three distinguishable outcomes (reclaim /
  age-unknown-refuse / too-young-refuse), replacing the `|| echo 0` default
  that reclaimed unconditionally on the error path.
- **G16/CA-304 -- FIXED, both halves.** `_cmd_migrate_path_move_body:
  3365-3375` removes `.lockd` plus the legacy timeout glob and deliberately
  leaves `.lock` in place with a corrected rationale;
  `_cmd_migrate_path_rollback_body:3385` exists and runs under the
  destination lockbase's lock.
- **Re-derived and confirmed accurate:** `BLOCKING_FILTER` (`:1469`)
  implements P0/P1/P2 + open|deferred with NOTED excluded, exactly as
  `CLAUDE.md`'s severity section defines; `AUDIT_ROUND_COERCE_JQ_DEF`
  (`:1457`) handles the bare-integer legacy shape; `cmd_audit_converged`'s
  three-field `round_type|lenses|count` pack/unpack (`:4310-4318`) parses
  correctly including the empty-`rounds[]` case (`"unknown||0"` ->
  `unknown`, `""`, `0`); `gated_phase_for_gate` (1->1, 2->3, 3->5) is
  consistent across all six consumers.

## Meta

`Write` absent from the delivered tool set despite the frontmatter grant
(ledger CA-130, **eighth consecutive round**) -- this report needed
orchestrator transcription. `Bash` also absent, so suite greenness is **NOT
CONFIRMED**; CA-331's standing recommendation (a Bash-capable pass runs
`bin/tests/run-all.sh` before the convergence gate) applies again, and this
round it matters more than usual: L1-002 and L1-005 both concern assertions
that either do not exist or fail with malformed values, neither of which a
static read can distinguish from a green suite.
</content>
