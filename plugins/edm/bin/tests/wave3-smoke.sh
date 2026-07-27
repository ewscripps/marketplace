#!/usr/bin/env bash
# wave3-smoke.sh — WS-N compaction-resilience smoke check (T54)
# Tests: current-step read/write, session-start output, last_cmd/last_decision
# in init payload, Resume Point presence in HANDOFF.md.
# Run from repo root: bash plugins/edm/bin/tests/wave3-smoke.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EDM_STATE="${SCRIPT_DIR}/../edm-state"

# Shared assertions / counters (CA-014).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_harness.sh"

# ---- Setup -------------------------------------------------------------------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export EDM_SRD_ROOT="$TMP/SRD"
mkdir -p "$TMP/SRD"

echo "WS-N smoke check — wave3 compaction resilience"
echo

# ---- T52: last_cmd and last_decision in init payload -------------------------
echo "T52 — last_cmd / last_decision in init payload"
"$EDM_STATE" init TSMK >/dev/null
STATE_FILE="$TMP/SRD/TSMK/.edm-state.json"
[[ -f "$STATE_FILE" ]] || { fail "state file not created"; exit 1; }

last_cmd="$(jq -r '.last_cmd' "$STATE_FILE")"
last_decision="$(jq -r '.last_decision' "$STATE_FILE")"
[[ "$last_cmd" == "" ]] && pass "last_cmd initialised as empty string" || fail "last_cmd = '$last_cmd' (expected '')"
[[ "$last_decision" == "" ]] && pass "last_decision initialised as empty string" || fail "last_decision = '$last_decision' (expected '')"

# current_step must be ABSENT (null) — not pre-initialised (T46 lazy contract)
current_step_raw="$(jq -r '.current_step' "$STATE_FILE")"
[[ "$current_step_raw" == "null" ]] && pass "current_step absent from init payload (lazy)" || fail "current_step present at init = '$current_step_raw' (expected null)"

# ---- T47: current-step read/write -------------------------------------------
echo
echo "T47 — current-step subcommand"

# Read when absent → empty string
step_read="$("$EDM_STATE" current-step TSMK)"
[[ -z "$step_read" ]] && pass "current-step read returns empty when absent" || fail "current-step read = '$step_read' (expected empty)"

# Write a string step
"$EDM_STATE" current-step TSMK "2.srd"
step_read="$("$EDM_STATE" current-step TSMK)"
[[ "$step_read" == "2.srd" ]] && pass "current-step write/read string '2.srd'" || fail "current-step = '$step_read' (expected '2.srd')"

# Write a numeric step
"$EDM_STATE" current-step TSMK 3
step_read="$("$EDM_STATE" current-step TSMK)"
[[ "$step_read" == "3" ]] && pass "current-step write/read numeric '3'" || fail "current-step = '$step_read' (expected '3')"

# ---- T52 set: last_cmd and last_decision via cmd_set -------------------------
echo
echo "T52 — set last_cmd / last_decision via cmd_set"
"$EDM_STATE" set TSMK last_cmd "edm-state phase-start TSMK 2"
"$EDM_STATE" set TSMK last_decision "Use product-scoped layout"
lc="$("$EDM_STATE" get TSMK | jq -r '.last_cmd')"
ld="$("$EDM_STATE" get TSMK | jq -r '.last_decision')"
[[ "$lc" == "edm-state phase-start TSMK 2" ]] && pass "last_cmd set correctly" || fail "last_cmd = '$lc'"
[[ "$ld" == "Use product-scoped layout" ]] && pass "last_decision set correctly" || fail "last_decision = '$ld'"

# ---- T48: Resume Point in HANDOFF.md ----------------------------------------
echo
echo "T48 — Resume Point section in HANDOFF.md"
# EDMV3-T13: phase-start now kernel-enforces phase 2's prerequisite gate (gate 1).
"$EDM_STATE" approve-gate TSMK 1 >/dev/null
"$EDM_STATE" phase-start TSMK 2 >/dev/null
"$EDM_STATE" write-handoff TSMK >/dev/null
HANDOFF="$TMP/SRD/TSMK/HANDOFF.md"
[[ -f "$HANDOFF" ]] || { fail "HANDOFF.md not created"; exit 1; }

check "Resume Point header present"       "## Resume Point"             "$(cat "$HANDOFF")"
check "Phase line in Resume Point"        "Phase 2"                     "$(cat "$HANDOFF")"
check "Last command in Resume Point"      "edm-state phase-start TSMK 2" "$(cat "$HANDOFF")"
check "Last decision in Resume Point"     "Use product-scoped layout"    "$(cat "$HANDOFF")"
check "Copy-paste resume line present"    "/edm:orchestrator TSMK"       "$(cat "$HANDOFF")"

# ---- T50: session-start output -----------------------------------------------
echo
echo "T50 — session-start emits active initiative"
# TSMK is at phase 2 — should appear in session-start output
session_out="$("$EDM_STATE" session-start 2>/dev/null)"
check "session-start shows active initiative" "TSMK"               "$session_out"
check "session-start shows phase name"        "Phase 2"            "$session_out"
check "session-start shows last_cmd"          "edm-state phase-start TSMK 2" "$session_out"
check "session-start shows resume command"    "/edm:orchestrator TSMK"   "$session_out"

# Phase 0 initiative should NOT appear
"$EDM_STATE" init TSMK2 >/dev/null
session_out2="$("$EDM_STATE" session-start 2>/dev/null)"
if echo "$session_out2" | grep -q "TSMK2"; then
  fail "session-start showed phase-0 initiative TSMK2 (should be hidden)"
else
  pass "session-start hides phase-0 initiative"
fi

# ---- Summary -----------------------------------------------------------------
echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
