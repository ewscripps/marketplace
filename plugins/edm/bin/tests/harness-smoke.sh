#!/usr/bin/env bash
# harness-smoke.sh — EDMV3-T19 smoke check for the new _harness.sh helpers:
# with_scratch_repo, check_fails, check_state_unchanged.
# Run from repo root: bash plugins/edm/bin/tests/harness-smoke.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

# Shared assertions / counters (CA-014).
source "${SCRIPT_DIR}/_harness.sh"

echo "EDMV3-T19 smoke check — _harness.sh helpers"
echo

# ---- AC1/AC3: with_scratch_repo scaffolds inside the temp tree, not the repo, and PATH ---------
# resolves bare-name sibling scripts to the plugin's own copies.
echo "AC1/AC3 — with_scratch_repo isolation and PATH"
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
echo "AC2 — cleanup on failure and on interrupt"

# Same scoping fix as the SIGINT case below: assert on THIS call's scratch directory, not on
# the existence of any edm-scratch.* in /tmp (other suites and concurrent agents have their own).
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
# Grepping /tmp for any `edm-scratch.*` was wrong: other suites (and, on this repo, other
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
echo "AC4 — check_fails (positive and negative)"
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
echo "AC5 — check_state_unchanged (positive and negative)"
STATE_TMP="$(mktemp /tmp/edm-harness-state-test.XXXXXX)"
echo '{"a":1}' > "$STATE_TMP"

check_state_unchanged "$STATE_TMP" true

_neg_out2="$(
  PASS=0; FAIL=0
  check_state_unchanged "$STATE_TMP" sh -c "echo x >> '$STATE_TMP'"
  echo "PASS=$PASS FAIL=$FAIL"
)"
check "check_state_unchanged correctly fails when the file is mutated" "PASS=0 FAIL=1" "$_neg_out2"
rm -f "$STATE_TMP"

# ---- AC6/AC7 (meta): existing helpers untouched, bash 3.2 compliance --------------------------
echo
echo "AC6/AC7 — existing helper behaviour and bash 3.2 compliance"
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

# ---- Summary -----------------------------------------------------------------
echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
