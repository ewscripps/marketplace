#!/usr/bin/env bash
# _harness.sh — shared smoke-test assertions for the EDM bin/tests/*-smoke.sh suites (CA-014;
# formerly the duplicated G18d preamble). Source it AFTER `set -euo pipefail`:
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_harness.sh"
# Each suite manages its own SCRIPT_DIR / EDM_STATE / PLUGIN_DIR / TMP setup; this file provides
# only the shared counters and assertions so the four suites can never diverge again.

PASS=0
FAIL=0

pass() { echo "  PASS: $*"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL+1)); }

# check <label> <expected-substring> <actual> — pass when <actual> contains <expected-substring>.
check() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" == *"$expected"* ]]; then
    pass "$label"
  else
    fail "$label (expected to contain: '$expected', got: '$actual')"
  fi
}

# check_absent <label> <unexpected-substring> <actual> — pass when <actual> does NOT contain it.
check_absent() {
  local label="$1" unexpected="$2" actual="$3"
  if [[ "$actual" == *"$unexpected"* ]]; then
    fail "$label (expected '$unexpected' to be absent, but it was present)"
  else
    pass "$label"
  fi
}

# check_fails <label> <exit-code> <expected-substring> <actual-output> — pass when
# <exit-code> is non-zero AND <actual-output> contains <expected-substring>.
# (EDMV3-T05/T07 wave6 baseline; broadened by EDMV3-T19.)
check_fails() {
  local label="$1" exit_code="$2" expected="$3" actual="$4"
  if [[ "$exit_code" -eq 0 ]]; then
    fail "$label (expected non-zero exit, got 0)"
  elif [[ "$actual" == *"$expected"* ]]; then
    pass "$label"
  else
    fail "$label (expected to contain: '$expected', got: '$actual')"
  fi
}

# state_snapshot <state-file> — echo the file's current bytes, for later comparison
# via check_state_unchanged. Missing file snapshots as empty string.
state_snapshot() {
  cat "$1" 2>/dev/null || true
}

# check_state_unchanged <label> <state-file> <before-snapshot> — pass when
# <state-file>'s current bytes equal <before-snapshot> (captured via state_snapshot
# before the command under test ran). (EDMV3-T05/T07 wave6 baseline; broadened by
# EDMV3-T19.)
check_state_unchanged() {
  local label="$1" state_file="$2" before="$3" after
  after="$(state_snapshot "$state_file")"
  if [[ "$after" == "$before" ]]; then
    pass "$label"
  else
    fail "$label (state file changed when it should not have)"
  fi
}
