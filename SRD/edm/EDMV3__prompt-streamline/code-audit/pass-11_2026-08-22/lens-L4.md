# L4: Test Quality -- Round 11

**Scope actually covered:** re-derivation of the 19 assigned IDs against HEAD. Verdict: 8 verified
FIXED, 11 STILL OPEN, 1 new finding. Not covered (declared gap): a fresh full-file sweep of
wave7-smoke.sh (~9,600 lines) and wave6-smoke.sh for *new* L4 classes beyond the assigned set;
wave3, wave4b, timing.sh, and harness-smoke.sh got no coverage at all.

## Findings (L4: Test Quality)

### CA-401 -- bare-capture suite-abort class: STILL OPEN, and now live at the durability pins themselves
plugins/edm/bin/tests/wave7-smoke.sh:5149
```bash
g25_call_site_count="$(grep -c 'schema_at_least "' "$EDM_STATE")"
```
Partially remediated -- the two originally-cited terminal-grep sites now carry a fix comment
(wave7-smoke.sh:1432, "CA-401(b): terminal grep guarded"). The class is not closed. Eleven
unguarded bare captures remain under `set -euo pipefail`: wave7-smoke.sh:5149, :5153, :3946,
:3953, :4021 and wave6-smoke.sh:296, :1205, :1222, :3638, :3645, :3657.

The escalation worth naming: :5149/:5153 are the G25/CA-342 durability pins for the
`schema_at_least` call-site count. The exact regression they exist to catch -- removal of the
last `schema_at_least "` call site -- makes `grep -c` exit 1, the assignment inherits it, and the
suite aborts at :5149 rather than printing the pin's named failure. A pin that dies instead of
failing reports nothing to run-all.sh beyond a crash. Same for :3946/:3953/:4021 (`grep -c
'^### '` over a scratch SRD that can legitimately be empty). Fix: route all eleven through
count_matches / count_matches_strict, the convention the same file documents at :1253-1254.

### CA-402 -- self-matching repo-wide scan: STILL OPEN
plugins/edm/bin/tests/wave7-smoke.sh:2309

`MERMAID_QUOTED='CLAUDE.md Sec."Mermaid diagram conventions"'` still has exactly one occurrence
tree-wide -- its own definition. Zero readers. Its only observable effect remains being the
literal the repo-wide plugin-directory scan below it searches for, guaranteeing a self-hit inside
that scan's floor. No `harness_grep_plugin_excluding_tests()` helper exists in _harness.sh
(confirmed: the harness exports only pass, fail, check, check_fails, count_matches,
count_matches_strict, assert_tree_absent), so the divergent exclusion vocabularies are unchanged.
Fix: delete :2309; add the shared exclusion helper.

### CA-403 -- control provenance: STILL OPEN
plugins/edm/bin/tests/wave7-smoke.sh:1105-1108

The comment at :1105 reads "CA-037: positive control -- the same $T61_BASH4_RE against a
synthetic line containing a real..." -- that documents what the control is, not that its string
was copied from the real pre-fix violation. None of the six cited controls carries a provenance
comment. Each still proves only "the regex matches a string invented to satisfy it." A regex
loosened in a later edit keeps both control and live scan green.

### CA-404 -- scorer exit status discarded: STILL OPEN (diagnosis-only residual)
plugins/edm/bin/tests/wave7-smoke.sh:751-757
```bash
bash "$SCORE_ARTIFACTS" run-dir > out-dim2.json 2>/dev/null
d2="$(jq -r '.dimensions[1].score' out-dim2.json 2>/dev/null)"
```
The determinism half is confirmed closed (:671-672 capture rc_a/rc_b into real stderr files).
The four dimension-extraction sites (:751, :779, :792, :822) are unchanged: no rc capture,
scorer stderr discarded, jq stderr discarded. A crash does fail (the assertion pins a literal
50), so this is diagnosis loss not a false pass -- the message renders "dimension 2 scored ,
expected the hand-computed value 50" with the cause thrown away.

### CA-405 -- presence-only meta-assertion over test scaffolding: STILL OPEN
plugins/edm/bin/tests/wave7-smoke.sh:2862-2865
```bash
t44_check_uses="$(printf '%s\n' "$t44_block" | grep -c 'check_fails\|check "' || true)"
[[ "${t44_check_uses:-0}" -gt 0 ]] && pass "T44 AC8 -- T44's own cases use check/check_fails..."
```
Unchanged. Passes with 39 of 40 T44 assertions deleted. Counts lines, not occurrences
(immaterial at a zero-adjacent threshold). Fix: drop it, or pin an exact count derived from the
block.

### CA-455 -- nine SKIP paths invisible in the aggregate: STILL OPEN
plugins/edm/bin/tests/wave7-smoke.sh:7726 (plus :8210, :8240, :8398, :8428, :8456, :8745, :8814,
:8902) and plugins/edm/bin/tests/run-all.sh:108

All nine `echo "  SKIP: ..."` sites are intact and increment neither counter. _harness.sh still
has no skip() function and no SKIP counter. The per-suite summary is still the two-term
`Results: ${PASS} passed, ${FAIL} failed`, and run-all.sh:108 still parses exactly
`^Results: [0-9]+ passed, [0-9]+ failed`. On macOS -- the documented primary development
platform, which ships no flock(1) -- the G12/CA-345, G49 and G13/CA-347 lock cases never
execute and run-all.sh prints all-suites-passed. A skipped case is still indistinguishable from
a case that never existed.

### CA-456 -- four tautological assertions on a self-written fixture: STILL OPEN
plugins/edm/bin/tests/wave7-smoke.sh:1978-1995

t25_ledger_case writes three literal JSONL lines at :1972-1974 and then asserts they are valid
JSON (:1978-1983), match ^CA-[0-9]{3}$ with confidence/lenses (:1985), have unique ids (:1989),
and carry an in-enum status (:1993). No plugin file is read anywhere in the function. These four
cannot fail for any change to any EDM source file -- only if jq itself broke -- while inflating
the pass count by four. edm-state render-ledger consumes exactly this shape and wave6-smoke.sh
already drives it. The CA-378 pipe-in-title durability case is still absent.

### CA-457 -- six-arm regex proven by a one-arm control: STILL OPEN
plugins/edm/bin/tests/wave7-smoke.sh:1096 (regex), :1108 (control)
```bash
T61_BASH4_RE='declare -A|mapfile|readarray|\$\{[a-zA-Z_]+\^\^\}|\$\{[a-zA-Z_]+,,\}|\{fd\}'
t61_bash4_control="$(printf '%s\n' 'declare -A foo' | grep -cE "$T61_BASH4_RE" || true)"
```
Six arms, control exercises arm 1 only. The two parameter-expansion arms and the named-fd arm
carry non-trivial escaping no control validates -- mis-escape any of them and the "zero
bash-4-only constructs" assertion stays permanently green over a live violation while the
control keeps passing.

### CA-459 -- expect-exactly-N has no canonical helper: STILL OPEN
plugins/edm/bin/tests/_harness.sh:248

assert_tree_absent (:248) is the only canonical form and expresses only "expect zero." No
assert_count_with_control exists. The hand-rolled control blocks remain (e.g.
wave7-smoke.sh:1105-1110): bare grep count with a || true fallback, no path-existence guard,
violating the harness's own docstring rule. The false-pass direction is unchanged -- a wrong
plugin directory or renamed layout yields grep exit 2, the stderr redirect eats the diagnostic,
|| true eats the status, the count reads 0, and the assertion passes as "the leak is absent"
while its control still passes off a synthetic string.

### CA-491 -- CA-441's Task-grant rule has no must-fail case: STILL OPEN
plugins/edm/bin/tests/wave7-smoke.sh:370 (t03_ac6_case, the AskUserQuestion-only must-fail shape)

t03_ac6_case at :370-402 is still the only must-fail case for edm-check-grants. Tree-wide grep
for CA-441, "Task grant", and "allowed-tools.*Task" in wave7-smoke.sh returns nothing. Because
CA-441's own fix granted Task to all twelve skills that need it, the rule's trigger is false
everywhere on the live tree, so the whole family of "exits 0 against the live tree" assertions
(:345, :3028, :3202, :3339, :3447, :3488) passes identically whether the rule works or does not
exist. A mis-escaped detection regex leaves it silently protecting nothing, permanently.

### CA-492 -- zero-round convergence positively pinned with no boundary case: STILL OPEN
plugins/edm/bin/tests/wave6-smoke.sh:817-821

PDEBT6 (:810-821) is unchanged: init, ledger, then approve-gate --accept-p2-debt with no
audit-round-start and no audit-round-complete, asserting exit 0 (:818) and the success message
(:820-821). The suite still positively certifies that an initiative which has never run a
code-audit round can converge, and the CA-425 negative set (:780, :792, :798) still has no
zero-round member. No comment names a decision or its authorizing artifact.

### NEW (round 11) -- the CA-426 stream-separation regression discards the very stream it exists to test
plugins/edm/bin/tests/wave6-smoke.sh:817
```bash
pdebt6_out="$("$EDM_STATE" approve-gate PDEBT6 code-audit --accept-p2-debt 2>/dev/null)" || pdebt6_ec=$?
```
This case exists -- per its own banner at :806, "a warn-and-proceed stderr line must NOT disable
the override (stream separation)" -- precisely to prove that the zero-rounds warn goes to stderr
while the refusal goes to stdout. It throws stderr away and asserts only stdout and the exit
code. Nothing asserts the warn appears on stderr at all. Delete the zero-rounds warn from
cmd_audit_converged entirely, or move it to stdout in a way that still leaves the override
engaged, and this regression pin stays green -- it proves half of a two-stream contract.
Adjacent to CA-492 but a distinct axis (CA-492 is the missing boundary case; this is the
discarded stream). Fix: capture stderr to its own variable (2>"$errfile" or a separate capture)
and add one assertion that the zero-rounds warn text is present on stderr and absent from
stdout.

## Noted / Not Actionable

- CA-493 -- FIXED. .gitlab-ci.yml:571-576 captures LIST_EC on its own statement and fails;
  :598-604 adds the explicit zero-count floor with a named cause.
- CA-494 -- FIXED. .gitlab-ci.yml:818-832 derives RUN_DIR exactly once with a documented
  rationale, and both the absent-directory and missing-run.json cases now exit 1; scoring
  (:835-837) and comparison (:845-856) both have failing else arms.
- CA-523 -- FIXED. wave7-smoke.sh:9340 now carries || true on the ca473_skill_lines capture.
- CA-524 -- FIXED, and fixed well. wave7-smoke.sh:9361 gates the disjointness check and its
  control on [[ -n "$ca473_hook_tok" && -n "$ca473_skill_tok" ]], with an explicit named failure
  at :9374 that distinguishes "skipped, not vacuously passed."
- CA-525 -- FIXED. wave6-smoke.sh:1038-1047 pins the skill's manifest-writing instruction (bare
  lens-per-line, both Round type: headers) with a check_absent positive control on a mutated
  instruction.
- CA-526 -- FIXED. wave6-smoke.sh:956-964 extracts the warn's lens list and asserts exact
  equality, closing the over-reporting blind spot the substring check had.
- CA-527 -- FIXED. wave6-smoke.sh:938-941 and :970-973 add rounds | length == 1 per fixture, so
  double-recording is now detectable.
- CA-528 -- FIXED. wave7-smoke.sh:9275 uses POSIX ^[[:space:]]*#, with the portability rationale
  in a comment at :9272-9274 and a positive control at :9281.
- wave7-smoke.sh:2861 t44_block awk extraction -- not a finding. A reworded "# EDMV3-T44:"
  banner empties the block, the || true yields 0, and the assertion fails. Safe direction.
- wave6-smoke.sh:820 substring check on the P2-count message -- not a finding. Substring
  containment is the right semantic for a message-content check; nothing here needs
  list-exactness.
