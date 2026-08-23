#!/usr/bin/env bash
# harness-smoke.sh -- EDMV3-T19 smoke check for the new _harness.sh helpers:
# with_scratch_repo, check_fails, check_state_unchanged.
# Run from repo root: bash plugins/edm/bin/tests/harness-smoke.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# Shared assertions / counters (CA-014).
source "${SCRIPT_DIR}/_harness.sh"
# G21 (round-3): REPO_ROOT is the shared _HARNESS_REPO_ROOT export, not a second independent
# cd/pwd derivation.
REPO_ROOT="$_HARNESS_REPO_ROOT"

echo "EDMV3-T19 smoke check -- _harness.sh helpers"
echo

# ---- AC1/AC3: with_scratch_repo scaffolds inside the temp tree, not the repo, and PATH ---------
# resolves bare-name sibling scripts to the plugin's own copies.
echo "AC1/AC3 -- with_scratch_repo isolation and PATH"
_captured_cwd=""
_captured_edm_state=""
_ac1_fn() {
  _captured_cwd="$(pwd)"
  _captured_edm_state="$(command -v edm-state)"
  edm-init --product demo --description h TESTH >/dev/null 2>&1
}
with_scratch_repo _ac1_fn

check "with_scratch_repo runs fn with scratch dir as cwd" "/edm-scratch." "$_captured_cwd"
check "with_scratch_repo prepends plugins/edm/bin to PATH" "plugins/edm/bin/edm-state" "$_captured_edm_state"
if [[ -d "${REPO_ROOT}/SRD/demo/TESTH__h" ]]; then
  fail "edm-init scaffolded inside the real repository (should be scratch-only)"
  rm -rf "${REPO_ROOT}/SRD/demo/TESTH__h"
else
  pass "edm-init did not touch the real repository"
fi

# ---- AC2: cleanup on every exit path -------------------------------------------------------
echo
echo "AC2 -- cleanup on failure and on interrupt"

# Same scoping fix as the SIGINT case below: assert on THIS call's scratch directory, not on
# the existence of any edm-scratch.* under ${TMPDIR:-/tmp} (other suites and concurrent agents have their own).
_ac2_failpath="$(mktemp -t edm-harness-ac2fail.XXXXXX)"
_ac2_fail_fn() { pwd > "$_ac2_failpath"; return 1; }
with_scratch_repo _ac2_fail_fn || true
_ac2_failscratch="$(cat "$_ac2_failpath" 2>/dev/null)"
if [ -z "$_ac2_failscratch" ]; then
  fail "failing-function case: function never reported its scratch path"
elif [ -d "$_ac2_failscratch" ]; then
  fail "scratch dir survived a failing test function: $_ac2_failscratch"
else
  pass "scratch dir removed after a failing test function"
fi
rm -f "$_ac2_failpath"

# The child records its own scratch path so this assertion targets exactly that directory.
# Grepping ${TMPDIR:-/tmp} for any `edm-scratch.*` was wrong: other suites (and, on this repo, other
# concurrent worktree agents) legitimately have their own scratch dirs in flight, so the test
# failed on their existence rather than on a real cleanup miss. Scope the check, and poll for
# the child to actually reach its sleep instead of assuming a fixed 0.5s is long enough.
_ac2_pathfile="$(mktemp -t edm-harness-ac2.XXXXXX)"
_ac2_sleep_fn() { pwd > "$_ac2_pathfile"; sleep 5; }
(
  source "${SCRIPT_DIR}/_harness.sh"
  _ac2_pathfile="$_ac2_pathfile"
  with_scratch_repo _ac2_sleep_fn
) &
_child_pid=$!
# Wait (bounded) for the child to have created its scratch dir and entered the function.
_waited=0
while [ ! -s "$_ac2_pathfile" ] && [ "$_waited" -lt 100 ]; do
  sleep 0.1
  _waited=$((_waited + 1))
done
_ac2_scratch="$(cat "$_ac2_pathfile" 2>/dev/null)"
kill -INT "$_child_pid" 2>/dev/null || true
wait "$_child_pid" 2>/dev/null || true
# Bounded poll for cleanup rather than a fixed sleep -- under concurrent load the trap can take
# longer than any single hardcoded interval.
_waited=0
while [ -n "$_ac2_scratch" ] && [ -d "$_ac2_scratch" ] && [ "$_waited" -lt 50 ]; do
  sleep 0.1
  _waited=$((_waited + 1))
done
if [ -z "$_ac2_scratch" ]; then
  fail "SIGINT case: child never reported its scratch path (could not run the assertion)"
elif [ -d "$_ac2_scratch" ]; then
  fail "scratch dir survived SIGINT: $_ac2_scratch"
else
  pass "scratch dir removed after SIGINT"
fi
rm -f "$_ac2_pathfile"

# ---- AC4: check_fails -----------------------------------------------------------------------
echo
echo "AC4 -- check_fails (positive and negative)"
check_fails "check_fails passes when exit is non-zero and message matches (case-insensitive)" \
  "no such" ls /definitely-not-here

# The negative case is run in a subshell with its own PASS/FAIL counters (unexported plain
# variables, so subshell mutation never leaks back) so the intentional "FAIL:" line it produces
# never pollutes this suite's own tally.
_neg_out="$(
  PASS=0; FAIL=0
  check_fails "probe" "wrong-substring-xyz" ls /definitely-not-here
  echo "PASS=$PASS FAIL=$FAIL"
)"
check "check_fails correctly fails on a non-matching substring" "PASS=0 FAIL=1" "$_neg_out"

# ---- AC5: check_state_unchanged --------------------------------------------------------------
echo
echo "AC5 -- check_state_unchanged (positive and negative)"
STATE_TMP="$(mktemp "${TMPDIR:-/tmp}/edm-harness-state-test.XXXXXX")"
echo '{"a":1}' > "$STATE_TMP"

check_state_unchanged "$STATE_TMP" true

_neg_out2="$(
  PASS=0; FAIL=0
  check_state_unchanged "$STATE_TMP" sh -c "echo x >> '$STATE_TMP'"
  echo "PASS=$PASS FAIL=$FAIL"
)"
check "check_state_unchanged correctly fails when the file is mutated" "PASS=0 FAIL=1" "$_neg_out2"

_neg_out3="$(
  PASS=0; FAIL=0
  check_state_unchanged "${STATE_TMP}.missing" true
  echo "PASS=$PASS FAIL=$FAIL"
)"
check "check_state_unchanged fails when no baseline file exists" "PASS=0 FAIL=1" "$_neg_out3"
rm -f "$STATE_TMP"

# ---- CA-145: count_matches, count_matches_strict (assert_absent_with_control deleted, CA-395) --
echo
echo "CA-145 -- count_matches, count_matches_strict"

CM_FILE="$(mktemp "${TMPDIR:-/tmp}/edm-harness-cm-test.XXXXXX")"
printf 'alpha\nbeta\nalpha again\n' > "$CM_FILE"

# Positive: a real, present pattern counts correctly.
cm_hits="$(count_matches 'alpha' "$CM_FILE")"
[[ "$cm_hits" -eq 2 ]] && pass "count_matches counts a present pattern correctly (2)" \
  || fail "count_matches returned '$cm_hits', expected 2"

# Positive: a genuinely absent pattern (grep exit 1) still prints 0, not an error.
cm_absent="$(count_matches 'zzz-not-present' "$CM_FILE")"
[[ "$cm_absent" -eq 0 ]] && pass "count_matches prints 0 for a genuinely absent pattern (grep exit 1)" \
  || fail "count_matches returned '$cm_absent' for an absent pattern, expected 0"

# CA-145's documented caveat, proven directly: a missing FILE (grep exit 2) collapses to the
# same printed "0" as a genuinely absent pattern -- this is the correctness gap the strict
# variant below exists to close, not a hypothetical.
cm_missing_file="$(count_matches 'alpha' "${CM_FILE}.does-not-exist")"
[[ "$cm_missing_file" -eq 0 ]] && pass "count_matches (documented caveat) also prints 0 for a missing file (grep exit 2)" \
  || fail "count_matches returned '$cm_missing_file' for a missing file, expected the documented 0"

# count_matches_strict: positive (present pattern), still returns 0/prints the real count.
cms_hits_ec=0
cms_hits="$(count_matches_strict 'alpha' "$CM_FILE")" || cms_hits_ec=$?
[[ "$cms_hits" -eq 2 && $cms_hits_ec -eq 0 ]] && pass "count_matches_strict counts a present pattern and returns 0" \
  || fail "count_matches_strict returned '$cms_hits' (ec=$cms_hits_ec), expected 2/0"

# count_matches_strict: genuinely absent pattern still prints 0 and returns 0 (unchanged from
# count_matches for this case -- only the missing-file case is supposed to diverge).
cms_absent_ec=0
cms_absent="$(count_matches_strict 'zzz-not-present' "$CM_FILE")" || cms_absent_ec=$?
[[ "$cms_absent" -eq 0 && $cms_absent_ec -eq 0 ]] && pass "count_matches_strict prints 0/returns 0 for a genuinely absent pattern" \
  || fail "count_matches_strict returned '$cms_absent' (ec=$cms_absent_ec) for an absent pattern, expected 0/0"

# count_matches_strict: THE FIX -- a missing file (grep exit 2) is distinguished, not collapsed.
set +e
cms_missing_ec=0
cms_missing="$(count_matches_strict 'alpha' "${CM_FILE}.does-not-exist")" || cms_missing_ec=$?
set -e
[[ "$cms_missing" == "ERROR" && $cms_missing_ec -eq 2 ]] \
  && pass "count_matches_strict prints ERROR/returns 2 for a missing file, unlike count_matches" \
  || fail "count_matches_strict returned '$cms_missing' (ec=$cms_missing_ec) for a missing file, expected ERROR/2"
rm -f "$CM_FILE"

# CA-395: assert_absent_with_control itself was deleted from _harness.sh (zero production callers
# since G2/CA-037 converted the last one to assert_tree_absent; these three cases existed solely
# to exercise a function nothing else called). assert_tree_absent's own docstring already carries
# the tautological-control rule these cases were guarding.

# ---- CA-042: check_refuses_and_leaves_state ---------------------------------------------------
echo
echo "CA-042 -- check_refuses_and_leaves_state (refuse + state-unchanged combined)"

CRLS_STATE="$(mktemp "${TMPDIR:-/tmp}/edm-harness-crls-test.XXXXXX")"
echo '{"a":1}' > "$CRLS_STATE"

# Positive: command exits non-zero, message matches, state untouched -- all three true at once.
check_refuses_and_leaves_state "refuses cleanly and leaves state alone" "no such" "$CRLS_STATE" \
  ls /definitely-not-here

# Negative: command exits 0 -- must fail regardless of message/state.
_crls_neg_exit0="$(
  PASS=0; FAIL=0
  check_refuses_and_leaves_state "expected refusal but command succeeded" "irrelevant" "$CRLS_STATE" true
  echo "PASS=$PASS FAIL=$FAIL"
)"
check "check_refuses_and_leaves_state fails when the command exits 0" "PASS=0 FAIL=1" "$_crls_neg_exit0"

# Negative: command refuses (non-zero) but the message does not match.
_crls_neg_msg="$(
  PASS=0; FAIL=0
  check_refuses_and_leaves_state "wrong message" "wrong-substring-xyz" "$CRLS_STATE" ls /definitely-not-here
  echo "PASS=$PASS FAIL=$FAIL"
)"
check "check_refuses_and_leaves_state fails on a non-matching message" "PASS=0 FAIL=1" "$_crls_neg_msg"

# Negative: command refuses AND the message matches, but it still mutated state -- the case that
# check_fails alone (without the hash comparison) could never catch.
_crls_neg_state="$(
  PASS=0; FAIL=0
  check_refuses_and_leaves_state "refused but mutated state anyway" "boom" "$CRLS_STATE" \
    sh -c "echo x >> '$CRLS_STATE'; echo boom >&2; exit 1"
  echo "PASS=$PASS FAIL=$FAIL"
)"
check "check_refuses_and_leaves_state fails when the refused command still mutated state" \
  "PASS=0 FAIL=1" "$_crls_neg_state"
rm -f "$CRLS_STATE"

# Negative: no baseline state file at all.
_crls_neg_baseline="$(
  PASS=0; FAIL=0
  check_refuses_and_leaves_state "no baseline" "irrelevant" "${CRLS_STATE}.missing" ls /definitely-not-here
  echo "PASS=$PASS FAIL=$FAIL"
)"
check "check_refuses_and_leaves_state fails when no baseline state file exists" \
  "PASS=0 FAIL=1" "$_crls_neg_baseline"

# ---- AC6/AC7 (meta): existing helpers untouched, bash 3.2 compliance --------------------------
echo
echo "AC6/AC7 -- existing helper behaviour and bash 3.2 compliance"
check "check() passes on matching substring" "needle" "haystack needle here"
check_absent "check_absent() passes when substring is absent" "not-present-xyz" "haystack here"
if bash -n "${SCRIPT_DIR}/_harness.sh"; then
  pass "_harness.sh passes bash -n"
else
  fail "_harness.sh failed bash -n"
fi
if grep -qE 'declare -A|mapfile|readarray' "${SCRIPT_DIR}/_harness.sh"; then
  fail "_harness.sh contains a bash 4+ construct"
else
  pass "_harness.sh contains no bash 4+ construct"
fi

# ---- CA-146 (G7, round-3 Wave 7b): run-all.sh's own result-accounting logic ------------------
# run-all.sh is not itself a *-smoke.sh file, so its own discovery glob never reaches it, and
# until now nothing else exercised the seven branches that classify a suite's output as
# PASS/FAIL/CRASH, detect zero-assertion runs, detect a missing summary, check the
# minimum-suite-count floor, or check for a missing preferred suite. run-all.sh's exit code IS
# the authoritative pass/fail verdict for the whole plugin -- if this accounting silently
# inverted, every suite result would become unreliable with nothing to detect it.
echo
echo "CA-146 -- run-all.sh's PASS/FAIL/CRASH/missing-summary/floor accounting"

RUN_ALL="${SCRIPT_DIR}/run-all.sh"
CA146_SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/edm-harness-ca146.XXXXXX")"
# CA-482: four-arm split -- see the identical fix in _harness.sh for the rationale.
trap 'rm -rf "$CA146_SCRATCH"' EXIT
trap 'rm -rf "$CA146_SCRATCH"; exit 130' INT
trap 'rm -rf "$CA146_SCRATCH"; exit 143' TERM
trap 'rm -rf "$CA146_SCRATCH"; exit 129' HUP

# _ca146_stub <dir> <name> <body...> -- writes one throwaway suite script into <dir>/<name>,
# named to match the *-smoke.sh discovery glob.
_ca146_stub() {
  local dir="$1" name="$2"
  shift 2
  {
    echo '#!/usr/bin/env bash'
    printf '%s\n' "$@"
  } > "${dir}/${name}"
  chmod +x "${dir}/${name}"
}

# Branch 1: zero-assertion suite -- exits 0 and prints the summary line, but 0 passed + 0 failed.
CA146_1="$(mktemp -d "${CA146_SCRATCH}/case1.XXXXXX")"
_ca146_stub "$CA146_1" "onlysuite-smoke.sh" 'echo "Results: 0 passed, 0 failed"' 'exit 0'
CA146_1_ec=0
CA146_1_out="$(EDM_RUN_ALL_SUITE_DIR="$CA146_1" EDM_RUN_ALL_PREFERRED_ORDER="" EDM_RUN_ALL_MIN_SUITE_COUNT=1 bash "$RUN_ALL" 2>&1)" || CA146_1_ec=$?
check "CA-146 branch 1 -- a zero-assertion suite is reported as FAIL" "onlysuite-smoke.sh" "$CA146_1_out"
check "CA-146 branch 1 -- STATUS token is FAIL" \
  "$(printf '%-28s %8s %8s %8s' "onlysuite-smoke.sh" "0" "1" "FAIL")" "$CA146_1_out"
check "CA-146 branch 1 -- note names the zero-assertion case" "suite emitted zero assertions" "$CA146_1_out"
[[ $CA146_1_ec -ne 0 ]] \
  && pass "CA-146 branch 1 -- aggregator's own exit code is non-zero" \
  || fail "CA-146 branch 1 -- aggregator exited 0 despite a FAIL suite"

# Branch 2: clean summary (claims 0 failed) but the suite process itself exits non-zero.
CA146_2="$(mktemp -d "${CA146_SCRATCH}/case2.XXXXXX")"
_ca146_stub "$CA146_2" "onlysuite-smoke.sh" 'echo "Results: 3 passed, 0 failed"' 'exit 1'
CA146_2_ec=0
CA146_2_out="$(EDM_RUN_ALL_SUITE_DIR="$CA146_2" EDM_RUN_ALL_PREFERRED_ORDER="" EDM_RUN_ALL_MIN_SUITE_COUNT=1 bash "$RUN_ALL" 2>&1)" || CA146_2_ec=$?
check "CA-146 branch 2 -- STATUS token is FAIL for a clean summary with a non-zero exit" \
  "$(printf '%-28s %8s %8s %8s' "onlysuite-smoke.sh" "3" "1" "FAIL")" "$CA146_2_out"
check "CA-146 branch 2 -- note names the non-zero-exit-despite-clean-summary case" \
  "suite exited non-zero" "$CA146_2_out"
[[ $CA146_2_ec -ne 0 ]] \
  && pass "CA-146 branch 2 -- aggregator's own exit code is non-zero" \
  || fail "CA-146 branch 2 -- aggregator exited 0 despite a FAIL suite"

# Branch 3: the inverse inconsistency -- the summary itself reports a failed assertion, but the
# suite process exits 0.
CA146_3="$(mktemp -d "${CA146_SCRATCH}/case3.XXXXXX")"
_ca146_stub "$CA146_3" "onlysuite-smoke.sh" 'echo "Results: 3 passed, 1 failed"' 'exit 0'
CA146_3_ec=0
CA146_3_out="$(EDM_RUN_ALL_SUITE_DIR="$CA146_3" EDM_RUN_ALL_PREFERRED_ORDER="" EDM_RUN_ALL_MIN_SUITE_COUNT=1 bash "$RUN_ALL" 2>&1)" || CA146_3_ec=$?
check "CA-146 branch 3 -- STATUS token is FAIL when the summary reports a failed assertion" \
  "$(printf '%-28s %8s %8s %8s' "onlysuite-smoke.sh" "3" "1" "FAIL")" "$CA146_3_out"
check "CA-146 branch 3 -- note names the reported-failed-assertions case" \
  "suite reported failed assertions" "$CA146_3_out"
[[ $CA146_3_ec -ne 0 ]] \
  && pass "CA-146 branch 3 -- aggregator's own exit code is non-zero" \
  || fail "CA-146 branch 3 -- aggregator exited 0 despite a FAIL suite"

# Branch 4: CRASH -- the suite's first line is `exit 1`, so it dies before emitting any summary.
CA146_4="$(mktemp -d "${CA146_SCRATCH}/case4.XXXXXX")"
_ca146_stub "$CA146_4" "onlysuite-smoke.sh" 'exit 1'
CA146_4_ec=0
CA146_4_out="$(EDM_RUN_ALL_SUITE_DIR="$CA146_4" EDM_RUN_ALL_PREFERRED_ORDER="" EDM_RUN_ALL_MIN_SUITE_COUNT=1 bash "$RUN_ALL" 2>&1)" || CA146_4_ec=$?
check "CA-146 branch 4 -- STATUS token is CRASH when the suite dies with no summary" \
  "$(printf '%-28s %8s %8s %8s' "onlysuite-smoke.sh" "0" "1" "CRASH")" "$CA146_4_out"
check "CA-146 branch 4 -- note names the crashed-before-summary case" \
  "suite crashed before emitting Results summary" "$CA146_4_out"
check "CA-146 branch 4 -- the dedicated CRASH line is also printed" "CRASH onlysuite-smoke.sh" "$CA146_4_out"
[[ $CA146_4_ec -ne 0 ]] \
  && pass "CA-146 branch 4 -- aggregator's own exit code is non-zero" \
  || fail "CA-146 branch 4 -- aggregator exited 0 despite a CRASH suite"

# Branch 5: exits 0 but prints nothing at all -- a missing summary that is NOT a crash.
CA146_5="$(mktemp -d "${CA146_SCRATCH}/case5.XXXXXX")"
_ca146_stub "$CA146_5" "onlysuite-smoke.sh" 'exit 0'
CA146_5_ec=0
CA146_5_out="$(EDM_RUN_ALL_SUITE_DIR="$CA146_5" EDM_RUN_ALL_PREFERRED_ORDER="" EDM_RUN_ALL_MIN_SUITE_COUNT=1 bash "$RUN_ALL" 2>&1)" || CA146_5_ec=$?
check "CA-146 branch 5 -- STATUS token is FAIL (not CRASH) for a silent exit-0 suite" \
  "$(printf '%-28s %8s %8s %8s' "onlysuite-smoke.sh" "0" "1" "FAIL")" "$CA146_5_out"
check "CA-146 branch 5 -- note names the missing-summary-but-exit-0 case" \
  "suite exited 0 without emitting Results summary" "$CA146_5_out"
check_absent "CA-146 branch 5 -- the dedicated CRASH line is NOT printed for this branch" \
  "CRASH onlysuite-smoke.sh" "$CA146_5_out"
[[ $CA146_5_ec -ne 0 ]] \
  && pass "CA-146 branch 5 -- aggregator's own exit code is non-zero" \
  || fail "CA-146 branch 5 -- aggregator exited 0 despite a FAIL suite"

# Branch 6: the minimum-suite-count floor and missing-preferred-suite check, exercised against
# the real default _PREFERRED_ORDER/_MIN_SUITE_COUNT (no override) -- a positive case with
# exactly the seven real names present, and a negative case with one of them missing.
CA146_6_NAMES="wave3-smoke.sh wave4a-smoke.sh wave4b-smoke.sh wave5-smoke.sh harness-smoke.sh wave6-smoke.sh wave7-smoke.sh"
CA146_6="$(mktemp -d "${CA146_SCRATCH}/case6.XXXXXX")"
for _ca146_name in $CA146_6_NAMES; do
  _ca146_stub "$CA146_6" "$_ca146_name" 'echo "Results: 1 passed, 0 failed"' 'exit 0'
done
CA146_6_ec=0
CA146_6_out="$(EDM_RUN_ALL_SUITE_DIR="$CA146_6" bash "$RUN_ALL" 2>&1)" || CA146_6_ec=$?
check "CA-146 branch 6a -- exactly the seven real suite names satisfies the floor and preferred-name check" \
  "ALL SUITES PASSED" "$CA146_6_out"
check_absent "CA-146 branch 6a -- no missing-preferred-suite refusal on a complete discovery set" \
  "expected suite(s) not discovered" "$CA146_6_out"
check_absent "CA-146 branch 6a -- no suite-count-floor refusal on a complete discovery set" \
  "suite(s) discovered, expected at least" "$CA146_6_out"
[[ $CA146_6_ec -eq 0 ]] \
  && pass "CA-146 branch 6a -- aggregator's own exit code is 0 for an all-passing complete set" \
  || fail "CA-146 branch 6a -- aggregator exited ${CA146_6_ec} despite every stub suite passing"

rm -f "${CA146_6}/wave7-smoke.sh"
CA146_6B_ec=0
CA146_6B_out="$(EDM_RUN_ALL_SUITE_DIR="$CA146_6" bash "$RUN_ALL" 2>&1)" || CA146_6B_ec=$?
check "CA-146 branch 6b -- a missing preferred suite is named in the refusal" \
  "expected suite(s) not discovered: wave7-smoke.sh" "$CA146_6B_out"
[[ $CA146_6B_ec -ne 0 ]] \
  && pass "CA-146 branch 6b -- aggregator's own exit code is non-zero when a preferred suite is missing" \
  || fail "CA-146 branch 6b -- aggregator exited 0 despite a missing preferred suite"

# Branch 7 (G14/CA-146): the minimum-suite-count floor itself actually firing. Branches 1-5 above
# all pass EDM_RUN_ALL_MIN_SUITE_COUNT=1, a floor any non-empty stub set satisfies, and branch 6
# uses the real default floor (7) against exactly seven discovered stub suites -- so nothing above
# ever drives the floor's own refusal branch (`only N suite(s) discovered, expected at least M`).
# One stub suite against a floor of 2 does, with EDM_RUN_ALL_PREFERRED_ORDER="" so the
# missing-preferred-suite check (which would otherwise fire first) is out of the way.
CA146_7="$(mktemp -d "${CA146_SCRATCH}/case7.XXXXXX")"
_ca146_stub "$CA146_7" "onlysuite-smoke.sh" 'echo "Results: 1 passed, 0 failed"' 'exit 0'
CA146_7_ec=0
CA146_7_out="$(EDM_RUN_ALL_SUITE_DIR="$CA146_7" EDM_RUN_ALL_PREFERRED_ORDER="" EDM_RUN_ALL_MIN_SUITE_COUNT=2 bash "$RUN_ALL" 2>&1)" || CA146_7_ec=$?
check "CA-146 branch 7 (G14) -- the minimum-suite-count floor refuses when discovery falls short" \
  "only 1 suite(s) discovered, expected at least 2" "$CA146_7_out"
[[ $CA146_7_ec -ne 0 ]] \
  && pass "CA-146 branch 7 (G14) -- aggregator's own exit code is non-zero when the floor refuses" \
  || fail "CA-146 branch 7 (G14) -- aggregator exited 0 despite the suite-count floor refusing"

rm -rf "$CA146_SCRATCH"
trap - EXIT INT TERM HUP

# ---- Summary -----------------------------------------------------------------
echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
