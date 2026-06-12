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
