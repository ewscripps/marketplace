#!/usr/bin/env bash
# wave4a-smoke.sh — WS-B/C/E/F bash-code smoke check (T56, T67, T83, T96, T97, T98, T99)
# Tests: audit-round-start, record-partial-verdict, set-mode, skip-phase,
#        set-supersedes/set-forked-from, SIZE_UNKNOWN suppression, HANDOFF sections.
# Run from repo root: bash plugins/edm-ai-development-staging/bin/tests/wave4a-smoke.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EDM_STATE="${SCRIPT_DIR}/../edm-state"

PASS=0
FAIL=0

pass() { echo "  PASS: $*"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL+1)); }

check() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" == *"$expected"* ]]; then
    pass "$label"
  else
    fail "$label (expected to contain: '$expected', got: '$actual')"
  fi
}

check_absent() {
  local label="$1" unexpected="$2" actual="$3"
  if [[ "$actual" == *"$unexpected"* ]]; then
    fail "$label (expected '$unexpected' to be absent, but it was present)"
  else
    pass "$label"
  fi
}

# ---- Setup -------------------------------------------------------------------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export EDM_SRD_ROOT="$TMP/SRD"
mkdir -p "$TMP/SRD"

echo "WS-B/C/E/F smoke check — wave4a bash code"
echo

# ---- T56: audit-round-start --------------------------------------------------
echo "T56 — audit-round-start"
"$EDM_STATE" init TSMK >/dev/null
STATE_FILE="$TMP/SRD/TSMK/.edm-state.json"

# First code-audit round
round1="$("$EDM_STATE" audit-round-start TSMK code)"
[[ "$round1" == "1" ]] && pass "first code-audit round = 1" || fail "first code-audit round = '$round1' (expected 1)"

round2="$("$EDM_STATE" audit-round-start TSMK code)"
[[ "$round2" == "2" ]] && pass "second code-audit round = 2" || fail "second code-audit round = '$round2' (expected 2)"

# SRD audit rounds are independent
round_srd="$("$EDM_STATE" audit-round-start TSMK srd)"
[[ "$round_srd" == "1" ]] && pass "first srd round = 1 (independent)" || fail "srd round = '$round_srd' (expected 1)"

stored_code="$(jq -r '.audit_rounds.code' "$STATE_FILE")"
[[ "$stored_code" == "2" ]] && pass "audit_rounds.code stored as 2" || fail "audit_rounds.code = '$stored_code'"

# Invalid type rejected
check "invalid audit type rejected" "unknown audit type" \
  "$("$EDM_STATE" audit-round-start TSMK invalid 2>&1 || true)"

# ---- T67: record-partial-verdict ---------------------------------------------
echo
echo "T67 — record-partial-verdict"
"$EDM_STATE" record-partial-verdict TSMK "TSMK-T01" PASS >/dev/null
"$EDM_STATE" record-partial-verdict TSMK "TSMK-T02" PARTIAL "needs retry logic" >/dev/null
"$EDM_STATE" record-partial-verdict TSMK "TSMK-T03" FAIL "assertion missing" >/dev/null

verdict_t01="$(jq -r '.partial_verdict_map["TSMK-T01"].verdict' "$STATE_FILE")"
[[ "$verdict_t01" == "PASS" ]] && pass "TSMK-T01 verdict = PASS" || fail "TSMK-T01 verdict = '$verdict_t01'"

verdict_t02="$(jq -r '.partial_verdict_map["TSMK-T02"].verdict' "$STATE_FILE")"
note_t02="$(jq -r '.partial_verdict_map["TSMK-T02"].note' "$STATE_FILE")"
[[ "$verdict_t02" == "PARTIAL" ]] && pass "TSMK-T02 verdict = PARTIAL" || fail "TSMK-T02 verdict = '$verdict_t02'"
[[ "$note_t02" == "needs retry logic" ]] && pass "TSMK-T02 note preserved" || fail "TSMK-T02 note = '$note_t02'"

# Invalid verdict rejected
check "invalid verdict rejected" "unknown verdict" \
  "$("$EDM_STATE" record-partial-verdict TSMK "TSMK-T04" UNKNOWN 2>&1 || true)"

# ---- T83: set-mode -----------------------------------------------------------
echo
echo "T83 — set-mode"
"$EDM_STATE" set-mode TSMK mode prototype >/dev/null
m="$(jq -r '.mode' "$STATE_FILE")"
[[ "$m" == "prototype" ]] && pass "mode = prototype" || fail "mode = '$m'"

"$EDM_STATE" set-mode TSMK lifecycle_mode fast-track >/dev/null
lm="$(jq -r '.lifecycle_mode' "$STATE_FILE")"
[[ "$lm" == "fast-track" ]] && pass "lifecycle_mode = fast-track" || fail "lifecycle_mode = '$lm'"

"$EDM_STATE" set-mode TSMK compliance_enabled true >/dev/null
ce="$(jq -r '.compliance_enabled' "$STATE_FILE")"
[[ "$ce" == "true" ]] && pass "compliance_enabled = true (boolean)" || fail "compliance_enabled = '$ce'"

"$EDM_STATE" set-mode TSMK implementation_mode tdd >/dev/null
im="$(jq -r '.implementation_mode' "$STATE_FILE")"
[[ "$im" == "tdd" ]] && pass "implementation_mode = tdd" || fail "implementation_mode = '$im'"

# Invalid values rejected
check "invalid mode rejected" "invalid mode" \
  "$("$EDM_STATE" set-mode TSMK mode badvalue 2>&1 || true)"
check "invalid lifecycle_mode rejected" "invalid lifecycle_mode" \
  "$("$EDM_STATE" set-mode TSMK lifecycle_mode badvalue 2>&1 || true)"
check "invalid compliance_enabled rejected" "requires true|false" \
  "$("$EDM_STATE" set-mode TSMK compliance_enabled maybe 2>&1 || true)"
check "invalid implementation_mode rejected" "invalid implementation_mode" \
  "$("$EDM_STATE" set-mode TSMK implementation_mode bdd 2>&1 || true)"

# ---- T96: skip-phase ---------------------------------------------------------
echo
echo "T96 — skip-phase"
# Reset to standard mode for gate-skip tests
"$EDM_STATE" set-mode TSMK mode standard >/dev/null
"$EDM_STATE" set-mode TSMK lifecycle_mode standard >/dev/null

"$EDM_STATE" skip-phase TSMK 1 "fast-track: scope documented elsewhere" >/dev/null
skipped="$(jq -r '.skipped_phases | length' "$STATE_FILE")"
[[ "$skipped" == "1" ]] && pass "skipped_phases has 1 entry" || fail "skipped_phases length = '$skipped'"

phase_num="$(jq -r '.skipped_phases[0].phase' "$STATE_FILE")"
[[ "$phase_num" == "1" ]] && pass "skipped phase = 1" || fail "skipped phase = '$phase_num'"

rationale="$(jq -r '.skipped_phases[0].rationale' "$STATE_FILE")"
[[ "$rationale" == "fast-track: scope documented elsewhere" ]] \
  && pass "skip rationale preserved" || fail "rationale = '$rationale'"

# Replacing existing entry for same phase (idempotent)
"$EDM_STATE" skip-phase TSMK 1 "updated rationale" >/dev/null
skipped2="$(jq -r '.skipped_phases | length' "$STATE_FILE")"
[[ "$skipped2" == "1" ]] && pass "re-skip phase 1 replaces (no duplicate)" || fail "skipped_phases length = '$skipped2'"

# Phase 1 skip should trigger HANDOFF 'Phase 1 skipped' next_action
"$EDM_STATE" write-handoff TSMK >/dev/null
HANDOFF="$TMP/SRD/TSMK/HANDOFF.md"
check "HANDOFF shows phase-1-skipped next_action" "Phase 1 skipped" "$(cat "$HANDOFF")"

# ---- T97: SIZE_UNKNOWN suppression -------------------------------------------
echo
echo "T97 — SIZE_UNKNOWN suppression for fast-track/fix-pack"
"$EDM_STATE" phase-start TSMK 2 >/dev/null

# Without fast-track: SIZE_UNKNOWN anomaly should fire
anomalies_std="$("$EDM_STATE" validate TSMK 2>&1 || true)"
check "SIZE_UNKNOWN anomaly present in standard mode" "SIZE_UNKNOWN" "$anomalies_std"

# With fast-track: SIZE_UNKNOWN should be suppressed
"$EDM_STATE" set-mode TSMK lifecycle_mode fast-track >/dev/null
anomalies_ft="$("$EDM_STATE" validate TSMK 2>&1 || true)"
check_absent "SIZE_UNKNOWN suppressed in fast-track mode" "SIZE_UNKNOWN" "$anomalies_ft"

# With fix-pack: SIZE_UNKNOWN should be suppressed
"$EDM_STATE" set-mode TSMK lifecycle_mode fix-pack >/dev/null
anomalies_fp="$("$EDM_STATE" validate TSMK 2>&1 || true)"
check_absent "SIZE_UNKNOWN suppressed in fix-pack mode" "SIZE_UNKNOWN" "$anomalies_fp"

# Reset
"$EDM_STATE" set-mode TSMK lifecycle_mode standard >/dev/null

# ---- T98: set-supersedes / set-forked-from -----------------------------------
echo
echo "T98 — set-supersedes / set-forked-from"
"$EDM_STATE" set-supersedes TSMK OLDPREFIX >/dev/null
sup="$(jq -r '.supersedes' "$STATE_FILE")"
[[ "$sup" == "OLDPREFIX" ]] && pass "supersedes = OLDPREFIX" || fail "supersedes = '$sup'"

"$EDM_STATE" set-forked-from TSMK SRCPREFIX >/dev/null
ff="$(jq -r '.forked_from' "$STATE_FILE")"
[[ "$ff" == "SRCPREFIX" ]] && pass "forked_from = SRCPREFIX" || fail "forked_from = '$ff'"

# Empty prefix rejected
check "empty supersedes rejected" "non-empty" \
  "$("$EDM_STATE" set-supersedes TSMK "" 2>&1 || true)"
check "empty forked_from rejected" "non-empty" \
  "$("$EDM_STATE" set-forked-from TSMK "" 2>&1 || true)"

# ---- T99: ## Lifecycle & Mode section in HANDOFF.md -------------------------
echo
echo "T99 — Lifecycle & Mode section in HANDOFF.md"
"$EDM_STATE" set-mode TSMK mode iac >/dev/null
"$EDM_STATE" set-mode TSMK lifecycle_mode partial >/dev/null
"$EDM_STATE" set-mode TSMK compliance_enabled true >/dev/null
"$EDM_STATE" set-mode TSMK implementation_mode tdd >/dev/null
"$EDM_STATE" write-handoff TSMK >/dev/null

check "HANDOFF has Lifecycle & Mode section"     "## Lifecycle & Mode"    "$(cat "$HANDOFF")"
check "HANDOFF shows mode = iac"                 "Mode**: iac"            "$(cat "$HANDOFF")"
check "HANDOFF shows lifecycle_mode = partial"   "Lifecycle mode**: partial" "$(cat "$HANDOFF")"
check "HANDOFF shows compliance_enabled = true"  "Compliance**: true"     "$(cat "$HANDOFF")"
check "HANDOFF shows implementation_mode = tdd"  "Implementation mode**: tdd" "$(cat "$HANDOFF")"
check "HANDOFF shows supersedes"                 "Supersedes**: OLDPREFIX" "$(cat "$HANDOFF")"
check "HANDOFF shows forked_from"                "Forked from**: SRCPREFIX" "$(cat "$HANDOFF")"

# Skipped phases section
check "HANDOFF shows skipped phase"              "Phase 1"               "$(cat "$HANDOFF")"

# T67: Outstanding PARTIAL Verdicts section in HANDOFF
"$EDM_STATE" write-handoff TSMK >/dev/null
check "HANDOFF has Outstanding PARTIAL Verdicts section" "## Outstanding PARTIAL Verdicts" "$(cat "$HANDOFF")"
check "HANDOFF shows PARTIAL ticket"             "TSMK-T02"              "$(cat "$HANDOFF")"
check "HANDOFF shows PARTIAL note"               "needs retry logic"     "$(cat "$HANDOFF")"
check_absent "HANDOFF omits PASS ticket from PARTIAL section" "TSMK-T01" \
  "$(grep -A5 'Outstanding PARTIAL' "$HANDOFF" || echo '')"

# Section order: Resume Point < Lifecycle & Mode < Outstanding PARTIAL < Gates
rp_line="$(grep -n '## Resume Point' "$HANDOFF" | head -1 | cut -d: -f1)"
lm_line="$(grep -n '## Lifecycle & Mode' "$HANDOFF" | head -1 | cut -d: -f1)"
pv_line="$(grep -n '## Outstanding PARTIAL Verdicts' "$HANDOFF" | head -1 | cut -d: -f1)"
gates_line="$(grep -n '## Gates' "$HANDOFF" | head -1 | cut -d: -f1)"
if [[ -n "$rp_line" && -n "$lm_line" && -n "$pv_line" && -n "$gates_line" ]]; then
  if [[ "$rp_line" -lt "$lm_line" && "$lm_line" -lt "$pv_line" && "$pv_line" -lt "$gates_line" ]]; then
    pass "HANDOFF section order: Resume < Lifecycle < PARTIAL < Gates"
  else
    fail "HANDOFF section order wrong (RP=$rp_line LM=$lm_line PV=$pv_line G=$gates_line)"
  fi
else
  fail "HANDOFF missing one or more expected sections (RP=$rp_line LM=$lm_line PV=$pv_line G=$gates_line)"
fi

# ---- init payload: new fields present ----------------------------------------
echo
echo "T56/T67/T83/T96/T98 — init payload has all new fields"
"$EDM_STATE" init TSMK2 >/dev/null
STATE2="$TMP/SRD/TSMK2/.edm-state.json"
audit_rounds="$(jq -r '.audit_rounds | type' "$STATE2")"
[[ "$audit_rounds" == "object" ]] && pass "audit_rounds initialised as {}" || fail "audit_rounds type = '$audit_rounds'"

pvm="$(jq -r '.partial_verdict_map | type' "$STATE2")"
[[ "$pvm" == "object" ]] && pass "partial_verdict_map initialised as {}" || fail "partial_verdict_map type = '$pvm'"

mode_init="$(jq -r '.mode' "$STATE2")"
[[ "$mode_init" == "standard" ]] && pass "mode default = standard" || fail "mode = '$mode_init'"

lm_init="$(jq -r '.lifecycle_mode' "$STATE2")"
[[ "$lm_init" == "standard" ]] && pass "lifecycle_mode default = standard" || fail "lifecycle_mode = '$lm_init'"

ce_init="$(jq -r '.compliance_enabled' "$STATE2")"
[[ "$ce_init" == "false" ]] && pass "compliance_enabled default = false (boolean)" || fail "compliance_enabled = '$ce_init'"

im_init="$(jq -r '.implementation_mode' "$STATE2")"
[[ "$im_init" == "standard" ]] && pass "implementation_mode default = standard" || fail "implementation_mode = '$im_init'"

sp_init="$(jq -r '.skipped_phases | type' "$STATE2")"
[[ "$sp_init" == "array" ]] && pass "skipped_phases initialised as []" || fail "skipped_phases type = '$sp_init'"

sup_init="$(jq -r '.supersedes' "$STATE2")"
[[ "$sup_init" == "" ]] && pass "supersedes default = empty string" || fail "supersedes = '$sup_init'"

ff_init="$(jq -r '.forked_from' "$STATE2")"
[[ "$ff_init" == "" ]] && pass "forked_from default = empty string" || fail "forked_from = '$ff_init'"

# ---- Summary -----------------------------------------------------------------
echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
