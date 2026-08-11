#!/usr/bin/env bash
# wave6-smoke.sh -- EDMV3 Epic E2 (Enforcement kernel) wave-A smoke coverage.
# EDMV3-T05: state_anomalies info/blocking class split, cmd_validate exit contract.
# EDMV3-T07: terminal_phase_for_mode / required_gates_for_mode / code_audit_required_for_mode.
# Run from repo root: bash plugins/edm/bin/tests/wave6-smoke.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
EDM_STATE="${SCRIPT_DIR}/../edm-state"

# Ensure bin/ is on PATH so edm-lint-artifacts --all can find edm-state
export PATH="${SCRIPT_DIR}/..:${PATH}"

# Shared assertions / counters (CA-014).
source "${SCRIPT_DIR}/_harness.sh"
# G21 (round-3): REPO_ROOT is the shared _HARNESS_REPO_ROOT export, not a second independent
# cd/pwd derivation.
REPO_ROOT="$_HARNESS_REPO_ROOT"

# ---- Setup -------------------------------------------------------------------
TMP="$(mktemp -d "${TMPDIR:-/tmp}/edm-wave6.XXXXXX")"
T41_BACKUP=""
T41_CANONICAL=""
cleanup_wave6() {
  if [[ -n "${T41_BACKUP:-}" && -n "${T41_CANONICAL:-}" && -f "${T41_BACKUP}" ]]; then
    cp "$T41_BACKUP" "$T41_CANONICAL"
  fi
  rm -f "${T41_BACKUP:-}"
  rm -rf "$TMP"
}
# G56/CA-216: HUP added -- cleanup_wave6 restores a TRACKED, committed file (T41_CANONICAL) from
# a backup after this suite deliberately mutates it. Omitting HUP left a terminal disconnect
# mid-test with no automatic restore, corrupting a tracked file in the working tree.
trap cleanup_wave6 EXIT INT TERM HUP
export EDM_SRD_ROOT="$TMP/SRD"
mkdir -p "$TMP/SRD"

echo "wave6 smoke check -- EDMV3-T05 anomaly classes, EDMV3-T07 mode helpers"
echo

# =================================================================================
# EDMV3-T05: state_anomalies info/blocking class split, cmd_validate exit contract
# =================================================================================

# ---- AC2/AC1: canonical four-field format, class token on every emit line ------
echo "T05 AC1/AC2 -- canonical four-field anomaly format"
"$EDM_STATE" init ANOMFMT >/dev/null
STATE_ANOMFMT="$TMP/SRD/ANOMFMT/.edm-state.json"
"$EDM_STATE" phase-start ANOMFMT 1 >/dev/null
# EDMV3-T11: phase-complete now requires each phase's artifact to be present and non-empty.
echo "planning notes" > "$TMP/SRD/ANOMFMT/planning.md"
"$EDM_STATE" phase-complete ANOMFMT 1 >/dev/null
# EDMV3-T13: phase-start now kernel-enforces phase 2's prerequisite gate (gate 1).
"$EDM_STATE" approve-gate ANOMFMT 1 >/dev/null
"$EDM_STATE" phase-start ANOMFMT 2 >/dev/null
echo "srd notes" > "$TMP/SRD/ANOMFMT/srd.md"
"$EDM_STATE" phase-complete ANOMFMT 2 >/dev/null
# estimated_size is still "Unknown" and current_phase (2) >= 2 -> SIZE_UNKNOWN (info) fires.
anom_out="$("$EDM_STATE" validate ANOMFMT 2>&1 || true)"
check "SIZE_UNKNOWN anomaly text present" "SIZE_UNKNOWN" "$anom_out"
check "SIZE_UNKNOWN carries class 'info'" "info  SIZE_UNKNOWN" "$anom_out"

anomaly_line="$(echo "$anom_out" | grep 'SIZE_UNKNOWN' | head -1)"
field_count="$(echo "$anomaly_line" | awk -F'  ' '{c=0; for (i=1;i<=NF;i++) if ($i != "") c++; print c}')"
[[ "$field_count" -ge 4 ]] && pass "anomaly line has >=4 fields (class/CODE/field/description)" \
  || fail "anomaly line has $field_count fields, expected >=4: '$anomaly_line'"
first_field="$(echo "$anomaly_line" | awk -F'  ' '{print $1}')"
[[ "$first_field" == "info" || "$first_field" == "blocking" ]] \
  && pass "anomaly line's first field is a legal class token" \
  || fail "anomaly line's first field '$first_field' is not info|blocking"

# ---- AC3 (positive): info-only validate exits 0 with output -------------------
echo
echo "T05 AC3 -- info-only validate exits 0 with output"
set +e
info_ec=0
info_out="$("$EDM_STATE" validate ANOMFMT 2>&1)" || info_ec=$?
set -e
[[ $info_ec -eq 0 ]] && pass "info-only validate exits 0" || fail "info-only validate exited $info_ec"
check "info-only validate prints the SIZE_UNKNOWN anomaly" "SIZE_UNKNOWN" "$info_out"

# ---- AC4 (negative): one blocking anomaly exits 3 ------------------------------
echo
echo "T05 AC4 -- one blocking anomaly exits 3"
"$EDM_STATE" init ANOMBLK >/dev/null
STATE_ANOMBLK="$TMP/SRD/ANOMBLK/.edm-state.json"
"$EDM_STATE" set ANOMBLK estimated_size Small >/dev/null   # suppress SIZE_UNKNOWN
"$EDM_STATE" phase-start ANOMBLK 1 >/dev/null
# EDMV3-T11: phase-complete now requires phase 1's artifact (planning.md) present + non-empty.
echo "planning notes" > "$TMP/SRD/ANOMBLK/planning.md"
"$EDM_STATE" phase-complete ANOMBLK 1 >/dev/null
# Craft a TIME_ORDER fixture directly: completed_at earlier than started_at.
jq '.phase_durations["1_phase"].started_at = "2026-01-02T00:00:00Z"
    | .phase_durations["1_phase"].completed_at = "2026-01-01T00:00:00Z"' \
  "$STATE_ANOMBLK" > "$STATE_ANOMBLK.tmp" && mv "$STATE_ANOMBLK.tmp" "$STATE_ANOMBLK"

set +e
blk_ec=0
blk_out="$("$EDM_STATE" validate ANOMBLK 2>&1)" || blk_ec=$?
set -e
[[ $blk_ec -eq 3 ]] && pass "single blocking anomaly (TIME_ORDER) exits 3" || fail "exited $blk_ec, expected 3"
check "TIME_ORDER anomaly text present" "TIME_ORDER" "$blk_out"
check "TIME_ORDER carries class 'blocking'" "blocking  TIME_ORDER" "$blk_out"
check_absent "no info-class anomaly present (size was set)" "SIZE_UNKNOWN" "$blk_out"

# ---- AC4 (negative): both classes present -> exits 3 and lists both -----------
echo
echo "T05 AC4 -- both classes present exits 3 and lists both"
"$EDM_STATE" init ANOMBOTH >/dev/null
STATE_ANOMBOTH="$TMP/SRD/ANOMBOTH/.edm-state.json"
"$EDM_STATE" phase-start ANOMBOTH 1 >/dev/null
# EDMV3-T11: phase-complete now requires each phase's artifact to be present and non-empty.
echo "planning notes" > "$TMP/SRD/ANOMBOTH/planning.md"
"$EDM_STATE" phase-complete ANOMBOTH 1 >/dev/null
# EDMV3-T13: phase-start now kernel-enforces phase 2's prerequisite gate (gate 1).
"$EDM_STATE" approve-gate ANOMBOTH 1 >/dev/null
"$EDM_STATE" phase-start ANOMBOTH 2 >/dev/null
echo "srd notes" > "$TMP/SRD/ANOMBOTH/srd.md"
"$EDM_STATE" phase-complete ANOMBOTH 2 >/dev/null
# estimated_size stays "Unknown" -> SIZE_UNKNOWN (info). Craft TIME_ORDER (blocking) too.
jq '.phase_durations["1_phase"].started_at = "2026-01-02T00:00:00Z"
    | .phase_durations["1_phase"].completed_at = "2026-01-01T00:00:00Z"' \
  "$STATE_ANOMBOTH" > "$STATE_ANOMBOTH.tmp" && mv "$STATE_ANOMBOTH.tmp" "$STATE_ANOMBOTH"

set +e
both_ec=0
both_out="$("$EDM_STATE" validate ANOMBOTH 2>&1)" || both_ec=$?
set -e
[[ $both_ec -eq 3 ]] && pass "both classes present exits 3" || fail "exited $both_ec, expected 3"
check "both-classes output lists SIZE_UNKNOWN (info)" "info  SIZE_UNKNOWN" "$both_out"
check "both-classes output lists TIME_ORDER (blocking)" "blocking  TIME_ORDER" "$both_out"

# ---- AC5: no behaviour change for existing codes (ZERO_TOKENS stays blocking) --
echo
echo "T05 AC5 -- ZERO_TOKENS remains blocking (no silent reclassification)"
"$EDM_STATE" init ANOMZT >/dev/null
STATE_ANOMZT="$TMP/SRD/ANOMZT/.edm-state.json"
"$EDM_STATE" set ANOMZT estimated_size Small >/dev/null
"$EDM_STATE" phase-start ANOMZT 1 >/dev/null
# EDMV3-T11: phase-complete now requires phase 1's artifact (planning.md) present + non-empty.
echo "planning notes" > "$TMP/SRD/ANOMZT/planning.md"
"$EDM_STATE" phase-complete ANOMZT 1 >/dev/null
jq '.phase_durations["1_phase"].model_used = "claude-test"
    | .phase_durations["1_phase"].tokens.input = 0
    | .phase_durations["1_phase"].tokens.output = 0' \
  "$STATE_ANOMZT" > "$STATE_ANOMZT.tmp" && mv "$STATE_ANOMZT.tmp" "$STATE_ANOMZT"
set +e
zt_ec=0
zt_out="$("$EDM_STATE" validate ANOMZT 2>&1)" || zt_ec=$?
set -e
[[ $zt_ec -eq 3 ]] && pass "ZERO_TOKENS still exits 3 (blocking, unchanged)" || fail "exited $zt_ec, expected 3"
check "ZERO_TOKENS carries class 'blocking'" "blocking  ZERO_TOKENS" "$zt_out"

# ---- AC6: session-start renders both classes, visually distinguished ----------
echo
echo "T05 AC6 -- session-start renders both classes, visually distinguished"
ss_out="$("$EDM_STATE" session-start 2>&1)"
check "session-start shows [info] marker for ANOMBOTH's SIZE_UNKNOWN" "[info]" "$ss_out"
check "session-start shows [BLOCKING] marker for ANOMBOTH's TIME_ORDER" "[BLOCKING]" "$ss_out"

# ---- AC8: validate is read-only (state byte-identical before/after) -----------
echo
echo "T05 AC8 -- validate leaves state byte-identical"
# check_state_unchanged (T19 canonical, exec-style) runs the command itself and hashes
# the state file before/after -- one call per case replaces the snapshot/run/compare triple.
check_state_unchanged "$STATE_ANOMFMT" "$EDM_STATE" validate ANOMFMT
check_state_unchanged "$STATE_ANOMBLK" "$EDM_STATE" validate ANOMBLK
check_state_unchanged "$STATE_ANOMBOTH" "$EDM_STATE" validate ANOMBOTH

# =================================================================================
# EDMV3-T07: terminal_phase_for_mode / required_gates_for_mode / code_audit_required_for_mode
# =================================================================================

# call_edm_helper <function-name> [args...] -- sources edm-state (dispatch-guarded,
# EDMV3-T07) in a subshell and calls <function-name>, printing its stdout and
# returning its exit code. The subshell isolates die()'s `exit 1` so a helper
# failure never aborts this suite.
call_edm_helper() {
  local fn="$1"; shift
  ( source "$EDM_STATE" >/dev/null 2>&1; "$fn" "$@" )
}

# ---- AC1: terminal phase per (mode, lifecycle_mode) pair, every legal pair ----
echo
echo "T07 AC1 -- terminal phase per (mode, lifecycle_mode) pair"
MODES="standard mini-srd iac data-ml prototype"
LIFECYCLES="standard partial fast-track fix-pack"
for m in $MODES; do
  for lc in $LIFECYCLES; do
    expected=6
    [[ "$m" == "prototype" ]] && expected=2
    got="$(call_edm_helper terminal_phase_for_mode "$m" "$lc")"
    [[ "$got" == "$expected" ]] \
      && pass "mode pair ($m, $lc) -> terminal phase $expected" \
      || fail "mode pair ($m, $lc) -> got $got, expected $expected"
  done
done

# ---- AC2: required gates per mode --------------------------------------------
echo
echo "T07 AC2 -- required gates per mode"
gates_out="$(call_edm_helper required_gates_for_mode standard standard "" | tr '\n' ' ')"
check "required_gates_for_mode(standard, standard, none-skipped) = all 3 gates" "1 2 3" "$gates_out"

# G47/CA-312 (round 6): this was the sibling CA-312 missed -- check() is a substring match, and
# these two assertions only proved gate 3 PRESENT ("3" matches "3 " or "2 3 ") and gate 1 ABSENT;
# nothing ruled out gate 2, and gate 2's origin phase (3) is not in this case's skip list ("1
# 3"), so gate-2 suppression is exactly what this case is supposed to test but didn't. A
# regression returning "2 3 " would satisfy both the old substring check and the old
# check_absent. Asserted as exact string equality instead, matching :203's own already-correct
# shape; the check_absent is now redundant (subsumed by the exact match) and dropped.
gates_out2="$(call_edm_helper required_gates_for_mode standard standard "1 3" | tr '\n' ' ')"
[[ "$gates_out2" == "3 " ]] \
  && pass "required_gates_for_mode(standard, standard, phases 1+3 skipped) = only gate 3" \
  || fail "required_gates_for_mode(standard, standard, phases 1+3 skipped) = '${gates_out2}', expected exactly '3 '"

# G36/CA-312: check() is a substring match, so an expected "1" is satisfied by an actual "1 2 "
# just as much as by "1 " -- these two cases prove PRESENCE where the contract they guard is
# EXCLUSIVITY (gate suppression is the entire purpose of the prototype and mini-srd modes here),
# so a regression that returns the full gate list instead of the suppressed subset would pass
# both. Asserted as exact string equality instead, matching :203's own already-correct shape.
gates_out3="$(call_edm_helper required_gates_for_mode prototype standard "3 4 5 6" | tr '\n' ' ')"
[[ "$gates_out3" == "1 " ]] \
  && pass "required_gates_for_mode(prototype, standard, phases 3-6 skipped) = only gate 1 (phase 1 <= terminal 2)" \
  || fail "required_gates_for_mode(prototype, standard, phases 3-6 skipped) = '${gates_out3}', expected exactly '1 '"

# G36/CA-312: this case's expected value was ALSO wrong, masked by the same substring bug --
# gate 2's origin phase is 3 (audit-srd), not 2, so mini-srd's real skipped-phases contract
# (phases 4 and 5 only, per skills/audit-srd/SKILL.md's `skip-phase <PREFIX> 4`/`5` calls -- SRD
# writing itself, phase 2, still happens for mini-srd, just fused with what would be phase-4
# content) never skips gate 2's origin. CLAUDE.md's "merged Gate 2+3" is a UI label for gate 2
# covering both SRD and ticket-pack review in one approval event, not a suppression of gate 2
# itself -- only gate 3 (origin phase 5) is actually excluded. Input corrected from the
# unrealistic "2 4 5" to the real "4 5" skip set; the result is unaffected either way since gate
# 2's origin (phase 3) is in neither list, but the realistic input avoids implying phase 2 is
# ever skipped for this mode.
gates_mini="$(call_edm_helper required_gates_for_mode mini-srd standard "4 5" | tr '\n' ' ')"
[[ "$gates_mini" == "1 2 " ]] \
  && pass "required_gates_for_mode(mini-srd, standard, phases 4/5 skipped) = gates 1 and 2 (gate 3's origin, phase 5, is skipped; gate 2's origin, phase 3, is not)" \
  || fail "required_gates_for_mode(mini-srd, standard, phases 4/5 skipped) = '${gates_mini}', expected exactly '1 2 '"

# ---- AC4: edm-init seeds skipped_phases for mini-srd / prototype --------------
echo
echo "T07 AC4 -- edm-init seeds skipped_phases from the mode phase graph"
export EDM_MODE="mini-srd"
"$EDM_STATE" init T7SEED1 >/dev/null
unset EDM_MODE
STATE_T7SEED1="$TMP/SRD/T7SEED1/.edm-state.json"
seed_len1="$(jq -r '.skipped_phases | length' "$STATE_T7SEED1")"
[[ "$seed_len1" -gt 0 ]] && pass "mini-srd fresh init seeds skipped_phases (length=$seed_len1)" \
  || fail "mini-srd fresh init skipped_phases length = $seed_len1, expected > 0"
seed_rationale1="$(jq -r '.skipped_phases[0].rationale' "$STATE_T7SEED1")"
check "seeded rationale names the mode (mini-srd)" "mini-srd" "$seed_rationale1"

export EDM_MODE="prototype"
"$EDM_STATE" init T7SEED2 >/dev/null
unset EDM_MODE
STATE_T7SEED2="$TMP/SRD/T7SEED2/.edm-state.json"
seed_len2="$(jq -r '.skipped_phases | length' "$STATE_T7SEED2")"
[[ "$seed_len2" -eq 4 ]] && pass "prototype fresh init seeds 4 skipped phases (3,4,5,6)" \
  || fail "prototype fresh init skipped_phases length = $seed_len2, expected 4"

"$EDM_STATE" init T7SEEDSTD >/dev/null
STATE_T7SEEDSTD="$TMP/SRD/T7SEEDSTD/.edm-state.json"
seed_len_std="$(jq -r '.skipped_phases | length' "$STATE_T7SEEDSTD")"
[[ "$seed_len_std" -eq 0 ]] && pass "standard fresh init leaves skipped_phases empty" \
  || fail "standard fresh init skipped_phases length = $seed_len_std, expected 0"

# ---- AC5: single mode derivation (no second mode-to-phase/gate mapping) -------
echo
echo "T07 AC5 -- single mode derivation"
proto_hits="$(count_matches 'prototype)' "$EDM_STATE")"
[[ "$proto_hits" -eq 2 ]] && pass "exactly 2 'prototype)' sites in edm-state (single derivation, CA-054 removed redundant arm)" \
  || fail "found $proto_hits 'prototype)' sites, expected exactly 2"

# ---- AC6 (G46/CA-322): code_audit_required_for_mode has exactly ONE direct call site --------
echo
echo "T07 AC6 -- code_audit_required_for_mode has exactly one direct call site"
# G46/CA-322: count_matches counted every raw occurrence of the name (definition, comments, the
# die() message) as if it were a call site, so this assertion passed on the definition plus a
# comment mentioning it and could not see a missing or an extra real call site. The invocation
# shape -- name, space, opening quote -- excludes the definition line (`code_audit_required_for_mode() {`,
# no quote), every comment (prose, no quote-after-space), and the die() message (a colon, not a
# quote, follows the name).
cadef_hits="$(grep -c 'code_audit_required_for_mode "' "$EDM_STATE")"
[[ "$cadef_hits" -eq 1 ]] \
  && pass "T07 AC6 -- code_audit_required_for_mode has exactly one direct call site (inside audit_required_for_mode_or_legacy)" \
  || fail "T07 AC6 -- code_audit_required_for_mode has ${cadef_hits} direct call site(s), expected exactly 1"
# Positive control: prove the invocation-shape needle actually discriminates a real call from a
# comment mention, rather than passing vacuously because the pattern never matches anything.
cadef_control="$(printf '%s\n' '# code_audit_required_for_mode is mentioned here in prose' 'code_audit_required_for_mode "$mode"' | grep -c 'code_audit_required_for_mode "')"
[[ "$cadef_control" -eq 1 ]] \
  && pass "T07 AC6 -- positive control: the invocation-shape needle matches the real call and not the comment" \
  || fail "T07 AC6 -- positive control broken: expected exactly 1 match, got ${cadef_control}"
# D35/CA-183 (decisions.md): cmd_approve_gate's code-audit branch deliberately consumes this
# function THROUGH audit_required_for_mode_or_legacy(), not by calling it a second time
# directly -- so a second direct call site is never expected, not merely "not yet landed".
check "T07 AC6 -- cmd_approve_gate consumes code_audit_required_for_mode through the shared wrapper" \
  'audit_required="$(audit_required_for_mode_or_legacy "$mode")"' \
  "$(awk '/^cmd_approve_gate\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"

# ---- AC7: unknown mode/lifecycle_mode fails loudly, does not default ---------
echo
echo "T07 AC7 -- unknown mode/lifecycle_mode errors, does not default"
# check_fails (T19 canonical, exec-style) runs the command itself and asserts non-zero
# exit plus a message substring in one call.
set +e
bad_mode_out="$(call_edm_helper terminal_phase_for_mode bogus-mode standard 2>&1)"
set -e
check_fails "unknown mode fails loudly naming the value" "unknown mode 'bogus-mode'" \
  call_edm_helper terminal_phase_for_mode bogus-mode standard
check "unknown mode error lists the legal enum" "standard|mini-srd|iac|data-ml|prototype" "$bad_mode_out"

set +e
bad_lc_out="$(call_edm_helper terminal_phase_for_mode standard bogus-lc 2>&1)"
set -e
check_fails "unknown lifecycle_mode fails loudly naming the value" "unknown lifecycle_mode 'bogus-lc'" \
  call_edm_helper terminal_phase_for_mode standard bogus-lc
check "unknown lifecycle_mode error lists the legal enum" "standard|fast-track|fix-pack" "$bad_lc_out"

check_refuses_and_leaves_state "set-mode rejects unknown mode value (CLI path)" "invalid mode" "$STATE_T7SEEDSTD" "$EDM_STATE" set-mode T7SEEDSTD mode bogus-mode

# ---- AC8: every (mode, lifecycle_mode) pair covered; bash 3.2 compatibility --
# Satisfied by the AC1 loop above: it enumerates all 5 x 4 = 20 legal pairs and
# emits one "mode pair (...)" assertion line per pair, so
# `bash bin/tests/wave6-smoke.sh 2>&1 | grep -c 'mode pair'` == 20. bash 3.2
# compatibility (no associative arrays, `bash -n` clean) is checked directly
# against bin/edm-state, not re-asserted here.

# =================================================================================
# EDMV3-T01: edm-init branch handshake correction (post-checkout record-branch)
# =================================================================================
echo
echo "T01 -- edm-init branch handshake correction"

# ---- AC1/AC2/AC5: new-branch path -- branch recorded equals HEAD --------------
t01_case_new_branch() {
  local orig_branch
  orig_branch="$(git rev-parse --abbrev-ref HEAD)"
  edm-init T1NEW >/dev/null

  local state="SRD/T1NEW/.edm-state.json"
  local recorded head
  recorded="$(jq -r '.initiative_branch' "$state")"
  head="$(git rev-parse --abbrev-ref HEAD)"

  [[ "$recorded" == "$head" ]] \
    && pass "T01 AC1 -- branch recorded equals HEAD ($head)" \
    || fail "T01 AC1 -- branch recorded equals HEAD (recorded='$recorded', HEAD='$head')"
  [[ "$recorded" == "edm/t1new" ]] \
    && pass "T01 AC2 -- new branch path: initiative_branch equals newly created branch name" \
    || fail "T01 AC2 -- new branch path: expected 'edm/t1new', got '$recorded'"
  [[ "$head" != "$orig_branch" ]] \
    && pass "T01 AC2 -- new branch path: HEAD moved off the pre-init branch" \
    || fail "T01 AC2 -- new branch path: HEAD is still '$orig_branch'"

  set +e
  edm-state branch-check T1NEW >/dev/null 2>&1
  local bc_ec=$?
  set -e
  [[ $bc_ec -eq 0 ]] \
    && pass "T01 AC5 -- branch-check exits 0 (new branch case)" \
    || fail "T01 AC5 -- branch-check exited $bc_ec (new branch case)"
}
with_scratch_repo t01_case_new_branch

# ---- AC3/AC5: existing-branch path ---------------------------------------------
t01_case_existing_branch() {
  local base_branch
  base_branch="$(git rev-parse --abbrev-ref HEAD)"
  git checkout -q -b edm/t1exst
  git checkout -q "$base_branch"

  edm-init T1EXST >/dev/null

  local state="SRD/T1EXST/.edm-state.json"
  local recorded
  recorded="$(jq -r '.initiative_branch' "$state")"
  [[ "$recorded" == "edm/t1exst" ]] \
    && pass "T01 AC3 -- existing branch path: initiative_branch equals pre-existing branch" \
    || fail "T01 AC3 -- existing branch path: expected 'edm/t1exst', got '$recorded'"

  set +e
  edm-state branch-check T1EXST >/dev/null 2>&1
  local bc_ec=$?
  set -e
  [[ $bc_ec -eq 0 ]] \
    && pass "T01 AC5 -- branch-check exits 0 (existing branch case)" \
    || fail "T01 AC5 -- branch-check exited $bc_ec (existing branch case)"
}
with_scratch_repo t01_case_existing_branch

# ---- AC4/AC5: checkout-failure warn-and-continue path --------------------------
# Shims 'git' earlier on PATH so 'checkout -b' fails while every other subcommand
# passes through to the real git (Technical Notes' recommended simulation).
t01_case_checkout_failure() {
  local orig_branch
  orig_branch="$(git rev-parse --abbrev-ref HEAD)"

  local real_git shim_dir
  real_git="$(command -v git)"
  shim_dir="$PWD/.git-shim"
  mkdir -p "$shim_dir"
  cat > "$shim_dir/git" <<GITSHIM_EOF
#!/usr/bin/env bash
# Test double: fails 'checkout -b' only; passes every other subcommand through.
if [[ "\$1" == "checkout" && "\$2" == "-b" ]]; then
  echo "fatal: simulated checkout -b failure" >&2
  exit 1
fi
exec "$real_git" "\$@"
GITSHIM_EOF
  chmod +x "$shim_dir/git"
  export PATH="$shim_dir:$PATH"

  local init_out init_ec
  set +e
  init_ec=0
  init_out="$(edm-init T1CKOF 2>&1)" || init_ec=$?
  set -e
  [[ $init_ec -eq 0 ]] \
    && pass "T01 AC4 -- checkout failure keeps origin branch: edm-init still exits 0" \
    || fail "T01 AC4 -- checkout failure keeps origin branch: edm-init exited $init_ec ($init_out)"
  check "T01 AC4 -- checkout failure keeps origin branch: [warn] line unchanged" \
    "[warn] branch creation failed; staying on current branch" "$init_out"

  local state="SRD/T1CKOF/.edm-state.json"
  local recorded current
  recorded="$(jq -r '.initiative_branch' "$state")"
  current="$(git rev-parse --abbrev-ref HEAD)"
  [[ "$recorded" == "$orig_branch" ]] \
    && pass "T01 AC4 -- checkout failure keeps origin branch: initiative_branch equals original branch" \
    || fail "T01 AC4 -- checkout failure keeps origin branch: expected '$orig_branch', got '$recorded'"
  [[ "$current" == "$orig_branch" ]] \
    && pass "T01 AC4 -- checkout failure keeps origin branch: HEAD stayed on original branch" \
    || fail "T01 AC4 -- checkout failure keeps origin branch: HEAD moved to '$current'"

  set +e
  edm-state branch-check T1CKOF >/dev/null 2>&1
  local bc_ec=$?
  set -e
  [[ $bc_ec -eq 0 ]] \
    && pass "T01 AC5 -- branch-check exits 0 (checkout-failure case)" \
    || fail "T01 AC5 -- branch-check exited $bc_ec (checkout-failure case)"
}
with_scratch_repo t01_case_checkout_failure

# ---- AC1: correction is a no-op outside a git worktree -------------------------
t01_case_non_worktree() {
  local nongit_dir
  # Nested under $TMP (not a fresh ${TMPDIR:-/tmp} entry) so the suite's own top-level
  # `trap 'rm -rf "$TMP"' EXIT` (set at the top of this file) already covers cleanup on
  # every exit path -- normal, failure, and interrupt -- without a second trap layer.
  nongit_dir="$(mktemp -d "$TMP/edm-t01-nongit.XXXXXX")" || { fail "T01 AC1 -- non-worktree mktemp failed"; return 1; }
  local prev_dir prev_srd_root prev_path
  prev_dir="$(pwd)"
  prev_srd_root="${EDM_SRD_ROOT:-}"
  prev_path="$PATH"
  cd "$nongit_dir"
  export EDM_SRD_ROOT="${nongit_dir}/SRD"
  # edm-init and edm-state invoke sibling scripts by bare name (see with_scratch_repo's own
  # comment above), and this case does not go through with_scratch_repo (it must NOT be a git
  # worktree), so prepend plugins/edm/bin to PATH here the same way that helper does.
  export PATH="${_HARNESS_BIN_DIR}:${PATH}"

  local init_out init_ec
  set +e
  init_ec=0
  init_out="$(edm-init T1NOG 2>&1)" || init_ec=$?
  set -e
  [[ $init_ec -eq 0 ]] \
    && pass "T01 AC1 -- correction is a no-op outside a git worktree: edm-init still exits 0" \
    || fail "T01 AC1 -- correction is a no-op outside a git worktree: edm-init exited $init_ec ($init_out)"
  check_absent "T01 AC1 -- correction is a no-op outside a git worktree: no Branch: line printed" \
    "Branch:" "$init_out"

  cd "$prev_dir"
  if [[ -n "$prev_srd_root" ]]; then
    export EDM_SRD_ROOT="$prev_srd_root"
  else
    unset EDM_SRD_ROOT
  fi
  export PATH="$prev_path"
  rm -rf "$nongit_dir"
}
t01_case_non_worktree

# ---- AC6: initiative_branch stays out of the cmd_set allowlist -----------------
echo
echo "T01 AC6 -- initiative_branch is not a cmd_set-settable key (allowlist containment)"
# Built from two halves, and neither half is repeated verbatim in this file's own comments or
# labels below, so this containment check can never be a false-positive hit against its own
# source line when the ticket's literal verify command re-runs the same grep externally.
_t01_ac6_verb="edm-state set "
_t01_ac6_field="initiative_branch"
# `|| true` guards the zero-matches case: grep exits 1 when nothing matches, and under this
# file's `set -euo pipefail` that would otherwise abort the whole suite right here on the
# expected-clean (zero-hit) outcome -- the one outcome this check exists to confirm.
_t01_ac6_hits="$( { grep -rn "${_t01_ac6_verb}.*${_t01_ac6_field}" "${SCRIPT_DIR}/.." 2>/dev/null \
  | grep -v "$(basename "${BASH_SOURCE[0]}")" || true; } | wc -l | tr -d ' ')"
[[ "$_t01_ac6_hits" -eq 0 ]] \
  && pass "T01 AC6 -- no cmd_set call site targets the branch field (allowlist containment holds)" \
  || fail "T01 AC6 -- found $_t01_ac6_hits cmd_set call site(s) targeting the branch field"
# EDMV3-T08: approve-gate accepts the code-audit gate token; gates_approved stays integral
# =================================================================================

# ---- AC1/AC5: normal approval sets the boolean + sibling metadata, success message ----
echo
echo "T08 AC1/AC5 -- approve-gate code-audit sets the boolean; success message format"
"$EDM_STATE" init T08NORM >/dev/null
STATE_T08NORM="$TMP/SRD/T08NORM/.edm-state.json"
pre_converged="$(jq -r '.code_audit_converged' "$STATE_T08NORM")"
[[ "$pre_converged" == "false" ]] && pass "code_audit_converged starts false" \
  || fail "code_audit_converged pre-state = '$pre_converged', expected false"

t08_out="$("$EDM_STATE" approve-gate T08NORM code-audit)"
check "approve-gate code-audit success message" "approved code-audit gate for T08NORM at" "$t08_out"

post_converged="$(jq -r '.code_audit_converged' "$STATE_T08NORM")"
[[ "$post_converged" == "true" ]] && pass "code_audit_converged flips to true" \
  || fail "code_audit_converged post-state = '$post_converged', expected true"

approver_out="$(jq -r '.code_audit_gate_approver' "$STATE_T08NORM")"
[[ "$approver_out" == "${USER:-unknown}" ]] && pass "code_audit_gate_approver recorded from \$USER" \
  || fail "code_audit_gate_approver = '$approver_out', expected '${USER:-unknown}'"

approved_at_out="$(jq -r '.code_audit_gate_approved_at' "$STATE_T08NORM")"
[[ -n "$approved_at_out" ]] && pass "code_audit_gate_approved_at recorded" \
  || fail "code_audit_gate_approved_at empty after approval"

[[ -f "$TMP/SRD/T08NORM/HANDOFF.md" ]] && pass "write_handoff_internal called (HANDOFF.md written)" \
  || fail "HANDOFF.md missing after approve-gate code-audit"

# ---- AC2: gates_approved gains no entry; length unchanged, no non-integer member -------
echo
echo "T08 AC2 -- gates_approved length unchanged, no non-integer member"
"$EDM_STATE" approve-gate T08NORM 1 >/dev/null
gates_len_before="$(jq -r '.gates_approved | length' "$STATE_T08NORM")"
"$EDM_STATE" approve-gate T08NORM code-audit >/dev/null   # re-approve; must not grow gates_approved
gates_len_after="$(jq -r '.gates_approved | length' "$STATE_T08NORM")"
[[ "$gates_len_before" == "$gates_len_after" ]] \
  && pass "gates_approved length unchanged by code-audit gate ($gates_len_after)" \
  || fail "gates_approved length changed: $gates_len_before -> $gates_len_after"
all_numeric="$(jq -e '[.gates_approved[].gate] | map(type == "number") | all' "$STATE_T08NORM")"
[[ "$all_numeric" == "true" ]] && pass "gates_approved contains no non-integer member" \
  || fail "gates_approved has a non-numeric gate entry"

# ---- AC3: wave-A interim -- ledger: absent, enforcement recorded, no convergence pre-check ----
echo
echo "T08 AC3 -- wave-A interim: ledger absent, enforcement recorded, no pre-check"
"$EDM_STATE" init T08INTERIM >/dev/null
STATE_T08INTERIM="$TMP/SRD/T08INTERIM/.edm-state.json"
# No numeric gate (1/2/3) is approved at all here -- proves no convergence pre-check
# blocks this call (that pre-check is EDMV3-T28, wave B, not yet landed).
"$EDM_STATE" approve-gate T08INTERIM code-audit >/dev/null
ledger_out="$(jq -r '.code_audit_gate_ledger' "$STATE_T08INTERIM")"
check "code_audit_gate_ledger recorded as absent (wave-A interim)" "absent" "$ledger_out"
enforcement_out="$(jq -r '.code_audit_gate_enforcement' "$STATE_T08INTERIM")"
[[ -n "$enforcement_out" ]] && pass "code_audit_gate_enforcement recorded (check_permission_rules helper)" \
  || fail "code_audit_gate_enforcement empty"
gates0_len="$(jq -r '.gates_approved | length' "$STATE_T08INTERIM")"
[[ "$gates0_len" == "0" ]] \
  && pass "code-audit gate approved with zero numeric gates pre-approved (no pre-check ran)" \
  || fail "gates_approved length = $gates0_len, expected 0 (a pre-check would have required gates first)"

# ---- AC4: mode exemption -- exemption reason recorded rather than an approval ----------
echo
echo "T08 AC4 -- fast-track records CONVERGENCE_NOT_REQUIRED rather than an approval"
# code_audit_required_for_mode() is exempt only for mode=prototype (EDMV3-T07 AC6) -- the
# reduced-lifecycle mode this ticket's case name ("fast-track") refers to: it terminates at
# Phase 2 (terminal_phase_for_mode=2) and never reaches a code-audit round.
export EDM_MODE="prototype"
"$EDM_STATE" init T08EXEMPT >/dev/null
unset EDM_MODE
STATE_T08EXEMPT="$TMP/SRD/T08EXEMPT/.edm-state.json"
exempt_out="$("$EDM_STATE" approve-gate T08EXEMPT code-audit)"
check "exemption message records CONVERGENCE_NOT_REQUIRED" "CONVERGENCE_NOT_REQUIRED" "$exempt_out"
exempt_enforcement="$(jq -r '.code_audit_gate_enforcement' "$STATE_T08EXEMPT")"
check "code_audit_gate_enforcement = CONVERGENCE_NOT_REQUIRED" "CONVERGENCE_NOT_REQUIRED" "$exempt_enforcement"
exempt_converged="$(jq -r '.code_audit_converged' "$STATE_T08EXEMPT")"
[[ "$exempt_converged" == "false" ]] \
  && pass "exempt mode leaves code_audit_converged false (exemption is not an approval)" \
  || fail "code_audit_converged = '$exempt_converged', expected false"
exempt_approved_at="$(jq -r '.code_audit_gate_approved_at' "$STATE_T08EXEMPT")"
[[ -z "$exempt_approved_at" ]] && pass "exempt mode records no approved_at" \
  || fail "code_audit_gate_approved_at = '$exempt_approved_at', expected empty"

# ---- AC6: archive refuses before approval, permits after ------------------------------
echo
echo "T08 AC6 -- archive refuses before approval, permits after"
"$EDM_STATE" init T08ARCH >/dev/null
"$EDM_STATE" set T08ARCH product_name testprod >/dev/null
STATE_T08ARCH="$TMP/SRD/T08ARCH/.edm-state.json"
# EDMV3-T12: archive now also enforces gates/terminal-phase/completed_at (AC1a-AC1c) before
# reaching the convergence check this test is scoped to -- satisfy those three directly via
# jq so this test stays about T08's own AC (the code-audit gate), not a full lifecycle replay.
"$EDM_STATE" approve-gate T08ARCH 1 >/dev/null
"$EDM_STATE" approve-gate T08ARCH 2 >/dev/null
"$EDM_STATE" approve-gate T08ARCH 3 >/dev/null
jq '.current_phase = 6 | .phase_durations["6_phase"] = {started_at: "2026-01-01T00:00:00Z", completed_at: "2026-01-01T01:00:00Z"}' \
  "$STATE_T08ARCH" > "${STATE_T08ARCH}.tmp" && mv "${STATE_T08ARCH}.tmp" "$STATE_T08ARCH"
check_refuses_and_leaves_state "archive refuses before approval" "archive refused: code_audit_converged=false" "$STATE_T08ARCH" "$EDM_STATE" archive T08ARCH
[[ -f "$STATE_T08ARCH" ]] && pass "archive refusal leaves the initiative directory in place" \
  || fail "initiative directory moved despite refusal"
"$EDM_STATE" approve-gate T08ARCH code-audit >/dev/null
"$EDM_STATE" archive T08ARCH >/dev/null \
  && pass "archive permits once code-audit gate is approved" \
  || fail "archive still refused after code-audit gate approval"
[[ -d "$TMP/SRD/.archived/testprod/T08ARCH" ]] \
  && pass "archived directory relocated to .archived/testprod/T08ARCH" \
  || fail "archived directory not found at expected destination"

# ---- AC7: --help header block and dispatch updated for the new gate token -------------
echo
echo "T08 AC7 -- --help header names the code-audit gate token"
help_out="$("$EDM_STATE" --help)"
check "help usage line names code-audit gate token" "code-audit" "$help_out"

# ---- AC8: metrics gate-review timing loop surfaces code-audit in its own row ----------
echo
echo "T08 AC8 -- metrics-report surfaces the code-audit gate in its own row"
metrics_out="$("$EDM_STATE" metrics-report T08NORM)"
check "metrics-report shows a dedicated code-audit gate row" "Gate code-audit review:" "$metrics_out"

# ---- AC9: design-rationale comment names code-audit as the second dedicated-boolean user ----
echo
echo "T08 AC9 -- design-rationale comment extended for code-audit"
rationale_hits="$(count_matches 'second user of this dedicated-boolean pattern' "$EDM_STATE")"
[[ "$rationale_hits" -ge 1 ]] && pass "design-rationale comment names code-audit as the second dedicated-boolean user" \
  || fail "design-rationale comment not found naming code-audit as second dedicated-boolean user"

# ---- AC10: all state mutation goes through rmw_state -----------------------------------
echo
echo "T08 AC10 -- cmd_approve_gate's three gate branches all mutate via rmw_state"
mutation_hits="$(sed -n '/^cmd_approve_gate() {/,/^}/p' "$EDM_STATE" | grep -c 'rmw_state ' || true)"
[[ "$mutation_hits" -ge 3 ]] \
  && pass "cmd_approve_gate has >=3 rmw_state call sites (3.5 / code-audit / numeric)" \
  || fail "expected >=3 rmw_state call sites inside cmd_approve_gate, found $mutation_hits"

# =================================================================================
# G1 (round-3 Wave 7b, CA-182 REOPENED): the code-audit gate is unconditionally approvable at
# schema_version < 2. Previously the convergence precheck ran ONLY when schema_version >= 2 --
# `_cmd_init_render` always writes the literal schema_version: 1, so for EVERY initiative
# created by the current plugin version the precheck was environmentally unreachable and the
# gate was approvable regardless of open findings. Fixed: the precheck now always runs; only its
# exit-3 (no JSONL ledger) arm still degrades, and only for a pre-wave-B initiative.
# =================================================================================
echo
echo "G1 -- approve-gate code-audit refuses on a blocking finding even at schema_version 1"
"$EDM_STATE" init G1SCHEMA1 >/dev/null
STATE_G1SCHEMA1="$TMP/SRD/G1SCHEMA1/.edm-state.json"
g1s1_schema_pre="$(jq -r '.schema_version' "$STATE_G1SCHEMA1")"
[[ "$g1s1_schema_pre" == "1" ]] \
  && pass "G1 -- edm-init writes schema_version 1 by default (the environmentally-unreachable case CA-182 exploited)" \
  || fail "G1 -- edm-init wrote schema_version '${g1s1_schema_pre}', expected 1 (test fixture assumption invalid)"
mkdir -p "$TMP/SRD/G1SCHEMA1/code-audit"
G1S1_JSONL="$TMP/SRD/G1SCHEMA1/code-audit/findings-ledger.jsonl"
cat > "$G1S1_JSONL" <<'EOF'
{"schema":1,"id":"CA-901","sev":"P0","status":"open","lenses":["L1"],"confidence":"high","component":"a.py","title":"G1 regression fixture -- open P0","raised_round":1,"resolved_round":null,"round":1,"round_type":"full"}
EOF
check_refuses_and_leaves_state "G1 -- approve-gate code-audit refuses at schema_version 1 with an open P0" \
  "code-audit gate refused" "$STATE_G1SCHEMA1" "$EDM_STATE" approve-gate G1SCHEMA1 code-audit
g1s1_converged="$(jq -r '.code_audit_converged' "$STATE_G1SCHEMA1")"
[[ "$g1s1_converged" == "false" ]] \
  && pass "G1 -- code_audit_converged is still unset (false) after the refusal (the gate-bypass regression, closed)" \
  || fail "G1 -- code_audit_converged = '${g1s1_converged}', expected false"

# ---- Mirror (negative): schema_version 2 with the identical fixture -- proves the pre-existing
# schema>=2 refusal path (T28 AC12 above) is unchanged by this fix. -------------------------
echo
echo "G1 -- mirror: approve-gate code-audit refuses identically at schema_version 2 (pass path unchanged)"
"$EDM_STATE" init G1SCHEMA2 >/dev/null
STATE_G1SCHEMA2="$TMP/SRD/G1SCHEMA2/.edm-state.json"
jq '.schema_version = 2' "$STATE_G1SCHEMA2" > "${STATE_G1SCHEMA2}.tmp" && mv "${STATE_G1SCHEMA2}.tmp" "$STATE_G1SCHEMA2"
mkdir -p "$TMP/SRD/G1SCHEMA2/code-audit"
G1S2_JSONL="$TMP/SRD/G1SCHEMA2/code-audit/findings-ledger.jsonl"
cp "$G1S1_JSONL" "$G1S2_JSONL"
"$EDM_STATE" audit-round-start G1SCHEMA2 code >/dev/null   # full round (no --lenses)
check_refuses_and_leaves_state "G1 mirror -- approve-gate code-audit refuses at schema_version 2 with an open P0" \
  "code-audit gate refused" "$STATE_G1SCHEMA2" "$EDM_STATE" approve-gate G1SCHEMA2 code-audit
g1s2_converged="$(jq -r '.code_audit_converged' "$STATE_G1SCHEMA2")"
[[ "$g1s2_converged" == "false" ]] \
  && pass "G1 mirror -- code_audit_converged is still unset (false) after the refusal" \
  || fail "G1 mirror -- code_audit_converged = '${g1s2_converged}', expected false"

# ---- Mirror (positive): the same schema_version 2 initiative, once remediated, still
# approves cleanly -- the existing pass path is provably unaffected by this fix. -------------
echo
echo "G1 -- mirror positive: a converged initiative at schema_version 2 still approves cleanly"
jq -cs 'map(.status = "fixed") | .[]' "$G1S2_JSONL" > "${G1S2_JSONL}.tmp" && mv "${G1S2_JSONL}.tmp" "$G1S2_JSONL"
"$EDM_STATE" approve-gate G1SCHEMA2 code-audit >/dev/null \
  && pass "G1 mirror positive -- approve-gate succeeds once the blocking finding is remediated" \
  || fail "G1 mirror positive -- approve-gate still refused after remediation"
g1s2_converged_after="$(jq -r '.code_audit_converged' "$STATE_G1SCHEMA2")"
[[ "$g1s2_converged_after" == "true" ]] \
  && pass "G1 mirror positive -- code_audit_converged flips to true after remediation" \
  || fail "G1 mirror positive -- code_audit_converged = '${g1s2_converged_after}', expected true"

# =================================================================================
# EDMV3-T13: gate enforcement moves into the kernel; gate-check becomes complete
# =================================================================================

# ---- AC1/AC2: phase-start refuses without the prerequisite gate; mutates nothing ------
echo
echo "T13 AC1/AC2 -- phase-start refuses without the prerequisite gate"
"$EDM_STATE" init T13PS >/dev/null
STATE_T13PS="$TMP/SRD/T13PS/.edm-state.json"
pre_phase="$(jq -r '.current_phase' "$STATE_T13PS")"
[[ "$pre_phase" == "0" ]] && pass "current_phase starts at 0" || fail "current_phase = '$pre_phase', expected 0"

check_refuses_and_leaves_state "phase-start refuses without the prerequisite gate" "Gate 1 has not been approved for T13PS; phase 2 cannot start" "$STATE_T13PS" "$EDM_STATE" phase-start T13PS 2
check "refusal names the exact approve-gate invocation" "edm-state approve-gate T13PS 1" \
  "$("$EDM_STATE" phase-start T13PS 2 2>&1 || true)"

echo
echo "T13 AC1 -- phase-start succeeds once the prerequisite gate is approved"
"$EDM_STATE" approve-gate T13PS 1 >/dev/null
"$EDM_STATE" phase-start T13PS 2 >/dev/null \
  && pass "phase-start succeeds once gate 1 is approved" \
  || fail "phase-start still refused after gate 1 approval"
post_phase="$(jq -r '.current_phase' "$STATE_T13PS")"
[[ "$post_phase" == "2" ]] && pass "current_phase advances to 2 after successful phase-start" \
  || fail "current_phase = '$post_phase', expected 2"

# ---- AC3: all eight phase-skill tokens resolve to a documented gate -------------------
echo
echo "T13 AC3 -- each of the eight phase-skill tokens resolves"
"$EDM_STATE" init T13TOK >/dev/null
tok_resolved=0
for tok in plan srd audit-srd tickets audit-tickets implement code-audit verify-runtime; do
  set +e
  tok_ec=0
  tok_out="$("$EDM_STATE" gate-check T13TOK "$tok" 2>&1)" || tok_ec=$?
  set -e
  # A resolved token either passes (plan, no prerequisite) or fails naming a specific numeric
  # Gate -- neither is the old silent `*) return 0` fall-through this ticket removes.
  if [[ "$tok" == "plan" ]]; then
    [[ $tok_ec -eq 0 ]] && tok_resolved=$((tok_resolved + 1)) \
      || fail "gate-check plan should pass (no prerequisite gate), exited $tok_ec"
  else
    if [[ $tok_ec -ne 0 && "$tok_out" == *"Gate "* ]]; then
      tok_resolved=$((tok_resolved + 1))
    else
      fail "gate-check ${tok} did not resolve to a documented gate (exit=$tok_ec, out='$tok_out')"
    fi
  fi
done
[[ "$tok_resolved" -eq 8 ]] && pass "all eight phase-skill tokens resolve (plan + 7 gated tokens)" \
  || fail "only $tok_resolved/8 phase-skill tokens resolved"

# ---- AC4: unknown gate-check token is a hard error, not a silent pass-through ---------
echo
echo "T13 AC4 -- unknown gate-check token errors (hard-error default branch)"
check_fails "unknown gate-check token errors" \
  "unknown gated command 'bogus-token'" \
  "$EDM_STATE" gate-check T13TOK bogus-token
check_fails "unknown gate-check token lists the valid tokens" \
  "plan srd audit-srd tickets audit-tickets implement code-audit verify-runtime" \
  "$EDM_STATE" gate-check T13TOK bogus-token

# ---- AC5: mode awareness -- fast-track passes gate-check tickets without gate 2 -------
echo
echo "T13 AC5 -- fast-track passes gate-check tickets without gate 2"
"$EDM_STATE" init T13FT >/dev/null
"$EDM_STATE" skip-phase T13FT 3 "fast-track: SRD audit fused elsewhere" >/dev/null
# Gate 2's feeding phase (3, audit-srd) is skipped -- required_gates_for_mode() excludes gate 2,
# so gate-check tickets must pass even though gate 2 was never approved.
"$EDM_STATE" gate-check T13FT tickets >/dev/null 2>&1 \
  && pass "gate-check tickets passes when gate 2's origin phase (3) is skipped" \
  || fail "gate-check tickets wrongly blocked despite phase 3 (gate 2's origin) being skipped"

# ---- AC6 (preserve, updated by G23/CA-343): the gate-approval numeric comparison logic is
# preserved in substance, but is no longer hand-copied at each call site. G23/CA-343 extracted
# the "is this gate approved" predicate cmd_phase_start, cmd_gate_check and cmd_archive each
# used to compute independently into a single shared gate_is_approved() helper (composed, for
# the single-gate callers, via gate_required_and_approved()) -- so the raw comparison expression
# itself now has exactly ONE definition, and this test's job changes from "count >=2 hand-copies"
# to "count == 1 definition, plus every former call site now routes through the shared helper."
echo
echo "T13 AC6 -- numeric comparison logic (select(.gate == \$g)) now has exactly one shared definition (G23/CA-343)"
select_hits="$(count_matches '(.gates_approved // \[\]) | map(select(.gate == \$g)) | length' "$EDM_STATE")"
[[ "$select_hits" -eq 1 ]] \
  && pass "the select(.gate == \$g) | length expression has exactly one definition (inside gate_is_approved)" \
  || fail "expected exactly 1 occurrence of the gate-approval comparison expression (single shared def, G23/CA-343), found $select_hits"
gate_is_approved_callers="$(grep -cE 'gate_is_approved "|gate_required_and_approved "' "$EDM_STATE")"
[[ "$gate_is_approved_callers" -ge 3 ]] \
  && pass "cmd_phase_start, cmd_gate_check and cmd_archive all route through the shared gate_is_approved/gate_required_and_approved helpers (G23/CA-343)" \
  || fail "expected >=3 call sites of gate_is_approved/gate_required_and_approved (cmd_phase_start, cmd_gate_check, cmd_archive), found $gate_is_approved_callers"

# ---- G23/CA-343 (b): phase-start, gate-check and archive agree, live, on a mini-srd
# initiative with skipped phases -- not just "each independently passes its own suite", but
# the three commands agree on the SAME gate (gate 3, whose origin phase 5 mini-srd skips) for
# the SAME initiative in the SAME test. mini-srd seeds skipped_phases {2,4,5} at edm-init
# (bin/edm-state:~976-978), so required_gates_for_mode(mini-srd, standard, "2 4 5") = "1 2"
# only -- gate 3 is not required by any of the three commands' independent derivations.
echo
echo "G23/CA-343 -- phase-start, gate-check and archive agree that gate 3 is not required for a mini-srd initiative with skipped phases"
edm-init --product demo --description g23mini G23MIN --mode mini-srd >/dev/null
G23MIN_DIR="$TMP/SRD/demo/G23MIN__g23mini"
G23MIN_STATE="${G23MIN_DIR}/.edm-state.json"
g23_skipped_len="$(jq -r '(.skipped_phases // []) | length' "$G23MIN_STATE")"
[[ "$g23_skipped_len" -eq 3 ]] \
  && pass "G23/CA-343 -- fixture sanity: mini-srd seeded 3 skipped phases (2, 4, 5)" \
  || fail "G23/CA-343 -- fixture sanity failed: mini-srd seeded ${g23_skipped_len} skipped phase(s), expected 3"
# Approve only gates 1 and 2 -- the two required_gates_for_mode says ARE required. Gate 3 is
# deliberately never approved.
"$EDM_STATE" approve-gate G23MIN 1 >/dev/null
"$EDM_STATE" approve-gate G23MIN 2 >/dev/null

# gate-check: implement is gated on gate 3 -- must exit 0 (not required) without gate 3 ever
# being approved.
g23_gc_ec=0
"$EDM_STATE" gate-check G23MIN implement >/dev/null 2>&1 || g23_gc_ec=$?
[[ "$g23_gc_ec" -eq 0 ]] \
  && pass "G23/CA-343 -- gate-check agrees gate 3 is not required for mini-srd (exit 0 without approval)" \
  || fail "G23/CA-343 -- gate-check refused implement for mini-srd despite gate 3 not being required (exit ${g23_gc_ec})"

# phase-start: phase 6's prerequisite gate is also gate 3 (phase_start_prerequisite_gate maps
# phase 6 -> gate 3, since gate 3's origin phase 5 immediately precedes phase 6) -- must also
# agree gate 3 is not required and let phase 6 start.
g23_ps_ec=0
"$EDM_STATE" phase-start G23MIN 6 >/dev/null 2>&1 || g23_ps_ec=$?
[[ "$g23_ps_ec" -eq 0 ]] \
  && pass "G23/CA-343 -- phase-start agrees gate 3 is not required for mini-srd (phase 6 starts without approval)" \
  || fail "G23/CA-343 -- phase-start refused into phase 6 for mini-srd despite gate 3 not being required (exit ${g23_ps_ec})"

# archive: its per-gate loop must also agree -- whatever else archive refuses on (terminal
# phase, convergence), its gate-approval check must never name gate 3 among the missing gates.
g23_arch_out="$("$EDM_STATE" archive G23MIN 2>&1)" || true
check_absent "G23/CA-343 -- archive's gate-approval check never names gate 3 as missing for mini-srd" \
  "gate(s) 3" "$g23_arch_out"
check_absent "G23/CA-343 -- archive's gate-approval check never names gate 3 alongside other gates for mini-srd" \
  ", 3" "$g23_arch_out"

# ---- AC7 (C-4): legacy state (mode present, schema_version absent -- the real EDMV2 shape)
# warns and proceeds through phase-start -----------------------------------------------
echo
echo "T13 AC7 -- legacy initiative (mode present, schema_version absent) phase-start warns and proceeds"
STATE_T13LEG_DIR="$TMP/SRD/T13LEG"
mkdir -p "$STATE_T13LEG_DIR"
STATE_T13LEG="$STATE_T13LEG_DIR/.edm-state.json"
jq -n '{prefix: "T13LEG", mode: "standard", current_phase: 0, gates_approved: [], phase_durations: {}, last_updated: "2020-01-01T00:00:00Z"}' \
  > "$STATE_T13LEG"
check "legacy phase-start (mode present, schema_version absent) warns rather than hard-failing" \
  "legacy initiative (no schema_version)" \
  "$("$EDM_STATE" phase-start T13LEG 2 2>&1)"
"$EDM_STATE" phase-start T13LEG 2 >/dev/null 2>&1 \
  && pass "legacy phase-start proceeds (exit 0) despite the missing schema_version" \
  || fail "legacy phase-start hard-failed instead of warn-and-proceed"
leg_phase="$(jq -r '.current_phase' "$STATE_T13LEG")"
[[ "$leg_phase" == "2" ]] && pass "legacy phase-start still advances current_phase" \
  || fail "current_phase = '$leg_phase', expected 2"

# ---- AC8: UserPromptExpansion hooks are retained unchanged ----------------------------
echo
echo "T13 AC8 -- hooks.json UserPromptExpansion gate-check call sites unchanged"
HOOKS_JSON="$(cd "$(dirname "$EDM_STATE")/.." && pwd)/hooks/hooks.json"
hook_gate_check_hits="$(count_matches 'gate-check' "$HOOKS_JSON")"
# G31/CA-279 (round 5): the five "prompt"-type hooks now delegate to `edm-state gate-check`
# rather than restating the phase-to-gate mapping in prose, adding one more "gate-check" mention
# per matcher alongside its sibling "command"-type hook's own call -- 5 command + 5 prompt = 10.
[[ "$hook_gate_check_hits" -eq 10 ]] \
  && pass "hooks.json has exactly 10 gate-check mentions (5 command call sites + 5 prompt-hook delegation mentions, G31/CA-279)" \
  || fail "hooks.json has $hook_gate_check_hits gate-check mentions, expected 10"
check_absent "hooks.json does not reference the new code-audit token" "gate-check \"\$prefix\" code-audit" "$(cat "$HOOKS_JSON")"
check_absent "hooks.json does not reference the new verify-runtime token" "gate-check \"\$prefix\" verify-runtime" "$(cat "$HOOKS_JSON")"
check_absent "hooks.json does not reference the new plan token" "gate-check \"\$prefix\" plan" "$(cat "$HOOKS_JSON")"

# ---- AC9: vocabulary guard -- no single line calls the preflight block that word ------
echo
echo "T13 AC9 -- vocabulary guard: no line names the preflight block with that word"
# G21/CA-049: the shared _HARNESS_PLUGIN_DIR export (set once in _harness.sh), not a second,
# independent cd/pwd re-derivation of the plugin root from SCRIPT_DIR.
PLUGIN_DIR="$_HARNESS_PLUGIN_DIR"
# Mirrors the ticket's literal verify command (line-level co-occurrence, not file-level --
# edm-state legitimately uses each word separately on unrelated lines, e.g. "deterministic
# gate enforcement" in the gate-check docblock and "Step 0" in an unrelated hook-typo
# comment; neither is the violation this guard targets). Excludes bin/tests/ (this
# suite's own assertion text would otherwise self-match) and builds the two needle words
# from parts so this line itself can never register as a hit.
guard_needle_a="Step"; guard_needle_a="${guard_needle_a} 0"
guard_needle_b="determin"; guard_needle_b="${guard_needle_b}istic"
vocab_hits="$(grep -rn "$guard_needle_a" "$PLUGIN_DIR" 2>/dev/null | grep -v '/bin/tests/' \
  | grep -ci "$guard_needle_b" || true)"
# G20 (round-3): positive control proving the same two-stage co-occurrence pipeline would
# actually catch a line containing both guarded terms together, so the zero count above is a
# real absence rather than a broken pipeline silently matching nothing.
vocab_control_hits="$(printf '%s\n' "synthetic control: ${guard_needle_a} gate uses ${guard_needle_b} enforcement" | grep "$guard_needle_a" | grep -ci "$guard_needle_b" || true)"
if [[ "${vocab_control_hits:-0}" -lt 1 ]]; then
  fail "positive control broken: a synthetic co-occurrence line was not caught by the vocabulary guard"
else
  [[ "$vocab_hits" -eq 0 ]] && pass "no line describes the preflight block with that word (positive control confirms the scan works)" \
    || fail "found $vocab_hits line(s) combining the two guarded terms on one line -- vocabulary guard violated"
fi

# =================================================================================
# EDMV3-T09: cmd_set becomes a checked contract -- allowlist, gate refusals, schema_version
# =================================================================================
echo
echo "T09 -- cmd_set allowlist, gate-bearing refusals, schema_version"

"$EDM_STATE" init T09GATE >/dev/null
STATE_T09GATE="$TMP/SRD/T09GATE/.edm-state.json"

# ---- AC1: code_audit_converged refused, naming approve-gate code-audit ---------
echo
echo "T09 AC1 -- code_audit_converged refused, naming approve-gate code-audit"
check_refuses_and_leaves_state "set code_audit_converged refused" "edm-state approve-gate <PREFIX> code-audit" "$STATE_T09GATE" "$EDM_STATE" set T09GATE code_audit_converged true

# ---- AC2: refusal precedes mutation, for every supplied value ------------------
echo
echo "T09 AC2 -- refusal happens before mutation, for true/false/garbage"
check_refuses_and_leaves_state "T09 AC2 -- set code_audit_converged=false refused (same class, false value)" \
  "edm-state approve-gate <PREFIX> code-audit" "$STATE_T09GATE" "$EDM_STATE" set T09GATE code_audit_converged false
check_refuses_and_leaves_state "T09 AC2 -- set code_audit_converged=garbage refused (same class, invalid value)" \
  "edm-state approve-gate <PREFIX> code-audit" "$STATE_T09GATE" "$EDM_STATE" set T09GATE code_audit_converged garbage

# ---- AC3: the whole gate-bearing class refuses, no partial mutation -----------
echo
echo "T09 AC3 -- compliance_gate_approved and gates_approved refuse entirely"
check_refuses_and_leaves_state "set compliance_gate_approved refused" "edm-state approve-gate <PREFIX> 3.5" "$STATE_T09GATE" "$EDM_STATE" set T09GATE compliance_gate_approved true
check_refuses_and_leaves_state "set gates_approved refused" "edm-state approve-gate <PREFIX> <gate-num>" "$STATE_T09GATE" "$EDM_STATE" set T09GATE gates_approved true

# ---- AC5: a known key still succeeds -------------------------------------------
echo
echo "T09 AC5 -- known key succeeds"
"$EDM_STATE" set T09GATE last_decision "T09 smoke check" >/dev/null \
  && pass "known key succeeds (last_decision via cmd_set)" \
  || fail "known key succeeds: last_decision unexpectedly refused"
ld_out="$(jq -r '.last_decision' "$STATE_T09GATE")"
[[ "$ld_out" == "T09 smoke check" ]] && pass "last_decision persisted correctly" \
  || fail "last_decision = '$ld_out', expected 'T09 smoke check'"

# ---- AC6: unknown key refused, lists the full sorted valid-key list -----------
echo
echo "T09 AC6 -- unknown key lists valid keys"
check_refuses_and_leaves_state "unknown key lists valid keys" "unknown key 'totally_made_up_key'" "$STATE_T09GATE" "$EDM_STATE" set T09GATE totally_made_up_key 1
unk_out="$("$EDM_STATE" set T09GATE totally_made_up_key 1 2>&1 || true)"
check "unknown key error lists compliance_enabled" "compliance_enabled" "$unk_out"
check "unknown key error lists test_frameworks_detected" "test_frameworks_detected" "$unk_out"

# ---- AC7: existing typed validation and its error strings are unchanged -------
echo
echo "T09 AC7 -- existing typed validation preserved verbatim"
check_fails "compliance_enabled still requires true|false (verbatim message)" \
  "requires a boolean value (true|false); got: maybe" \
  "$EDM_STATE" set T09GATE compliance_enabled maybe
check_fails "current_phase still requires a numeric value (verbatim message)" \
  "requires a numeric value; got: abc" \
  "$EDM_STATE" set T09GATE current_phase abc

# ---- AC8: schema_version is an integer, written by cmd_init, readable via get --
echo
echo "T09 AC8 -- schema_version is 1 for a wave-A-created initiative, readable via get"
sv_rc=0
sv_out="$("$EDM_STATE" get T09GATE | jq -e '.schema_version == 1')" || sv_rc=$?
[[ "$sv_out" == "true" ]] && pass "schema_version = 1 for a wave-A-created initiative" \
  || fail "schema_version != 1 (jq -e result: $sv_out, rc: $sv_rc)"

# Ticket's literal verify path: edm-init (the wrapper, not cmd_init directly) in a
# scratch repo, product-scoped, then `edm-state get <PREFIX> | jq -e`.
t09_ac8_case_edm_init() {
  edm-init --product demo --description sv TESTV >/dev/null
  local sv_scratch
  sv_scratch="$(edm-state get TESTV | jq -e '.schema_version == 1' 2>&1)"
  [[ "$sv_scratch" == "true" ]] \
    && pass "T09 AC8 -- edm-init --product/--description scratch-repo path: schema_version == 1" \
    || fail "T09 AC8 -- edm-init scratch-repo path: jq -e result '$sv_scratch', expected true"
}
with_scratch_repo t09_ac8_case_edm_init

# ---- AC9: schema_version is refused via cmd_set, naming migrate-schema --------
echo
echo "T09 AC9 -- set schema_version refused naming migrate-schema"
check_refuses_and_leaves_state "set schema_version refused naming migrate-schema" "edm-state migrate-schema <PREFIX>" "$STATE_T09GATE" "$EDM_STATE" set T09GATE schema_version 2

# =================================================================================
# EDMV3-T06: permission `ask` rule detection, PERM_RULES_MISSING anomaly, enforcement tags
# =================================================================================
echo
echo "T06 -- permission ask-rule detection and honest enforcement tags"

# Isolated scratch cwd + isolated HOME so this suite's outcome never depends on the
# developer machine's real ~/.claude/settings.json (AC4/AC6 fail-safe requires this to be
# deterministic, not "whatever happens to be on the box that runs it").
T06_HOME="$(mktemp -d "${TMP}/t06-home.XXXXXX")"
T06_CWD="$(mktemp -d "${TMP}/t06-cwd.XXXXXX")"
T06_PREV_HOME="${HOME:-}"
T06_PREV_PWD="$(pwd)"
mkdir -p "$T06_HOME/.claude" "$T06_CWD/.claude"
cd "$T06_CWD"
export HOME="$T06_HOME"

t06_restore_env() {
  cd "$T06_PREV_PWD"
  export HOME="$T06_PREV_HOME"
}

# ---- AC4/AC6 -- no settings files anywhere -> prose-only, fail-safe direction ---
echo
echo "T06 AC4/AC6 -- no settings files present -> prose-only (fail-safe default)"
"$EDM_STATE" init T06NONE >/dev/null
STATE_T06NONE="$TMP/SRD/T06NONE/.edm-state.json"
"$EDM_STATE" approve-gate T06NONE 1 >/dev/null
enf_none="$(jq -r '.gates_approved[0].enforcement' "$STATE_T06NONE")"
[[ "$enf_none" == "prose-only" ]] && pass "no settings files -> enforcement=prose-only" \
  || fail "no settings files -> enforcement='$enf_none', expected prose-only"

# ---- AC4 -- detection scans all three files; each alone is sufficient (union) --
echo
echo "T06 AC4 -- detection across the three scanned files"
cat > "$T06_CWD/.claude/settings.local.json" <<'JSON'
{"permissions": {"ask": ["Bash(edm-state approve-gate*)"]}}
JSON
cat > "$T06_CWD/.claude/settings.json" <<'JSON'
{"permissions": {"ask": ["Bash(edm-state archive*)"]}}
JSON
"$EDM_STATE" init T06UNION >/dev/null
"$EDM_STATE" approve-gate T06UNION 1 >/dev/null
enf_union="$(jq -r '.gates_approved[0].enforcement' "$TMP/SRD/T06UNION/.edm-state.json")"
[[ "$enf_union" == "permission-ask" ]] \
  && pass "AC4 -- one pattern per file (union across settings.local.json + settings.json) -> permission-ask" \
  || fail "AC4 union case -> enforcement='$enf_union', expected permission-ask"
rm -f "$T06_CWD/.claude/settings.local.json" "$T06_CWD/.claude/settings.json"

# ---- AC4 -- ~/.claude/settings.json alone is sufficient ------------------------
cat > "$T06_HOME/.claude/settings.json" <<'JSON'
{"permissions": {"ask": ["Bash(edm-state approve-gate*)", "Bash(edm-state archive*)"]}}
JSON
"$EDM_STATE" init T06HOMESET >/dev/null
"$EDM_STATE" approve-gate T06HOMESET 1 >/dev/null
enf_home="$(jq -r '.gates_approved[0].enforcement' "$TMP/SRD/T06HOMESET/.edm-state.json")"
[[ "$enf_home" == "permission-ask" ]] \
  && pass "AC4 -- ~/.claude/settings.json alone -> permission-ask" \
  || fail "AC4 home-settings case -> enforcement='$enf_home', expected permission-ask"

# ---- AC6 -- malformed settings JSON reports missing ----------------------------
echo
echo "T06 AC6 -- malformed settings JSON reports missing"
rm -f "$T06_HOME/.claude/settings.json"
echo '{not valid json' > "$T06_CWD/.claude/settings.local.json"
cat > "$T06_CWD/.claude/settings.json" <<'JSON'
{"permissions": {"ask": ["Bash(edm-state archive*)"]}}
JSON
"$EDM_STATE" init T06MALFORMED >/dev/null
"$EDM_STATE" approve-gate T06MALFORMED 1 >/dev/null
enf_malformed="$(jq -r '.gates_approved[0].enforcement' "$TMP/SRD/T06MALFORMED/.edm-state.json")"
[[ "$enf_malformed" == "prose-only" ]] \
  && pass "AC6 -- malformed settings JSON reports missing (prose-only, not permission-ask)" \
  || fail "AC6 malformed-JSON case -> enforcement='$enf_malformed', expected prose-only"
rm -f "$T06_CWD/.claude/settings.local.json" "$T06_CWD/.claude/settings.json"

# ---- AC5 -- PERM_RULES_MISSING appears without rules, disappears with rules ----
echo
echo "T06 AC5 -- PERM_RULES_MISSING appears without rules and disappears with rules"
"$EDM_STATE" init T06PERM >/dev/null
"$EDM_STATE" set T06PERM estimated_size Small >/dev/null
perm_missing_out="$("$EDM_STATE" validate T06PERM 2>&1 || true)"
check "PERM_RULES_MISSING appears without rules" "info  PERM_RULES_MISSING" "$perm_missing_out"

cat > "$T06_CWD/.claude/settings.json" <<'JSON'
{"permissions": {"ask": ["Bash(edm-state approve-gate*)", "Bash(edm-state archive*)"]}}
JSON
perm_present_out="$("$EDM_STATE" validate T06PERM 2>&1 || true)"
check_absent "PERM_RULES_MISSING disappears with rules" "PERM_RULES_MISSING" "$perm_present_out"

# session-start also surfaces (or omits) the same anomaly (AC5 "surfaces in both").
ss_missing_out="$(rm -f "$T06_CWD/.claude/settings.json"; "$EDM_STATE" session-start 2>&1 || true)"
check "session-start surfaces PERM_RULES_MISSING when rules absent" "PERM_RULES_MISSING" "$ss_missing_out"
cat > "$T06_CWD/.claude/settings.json" <<'JSON'
{"permissions": {"ask": ["Bash(edm-state approve-gate*)", "Bash(edm-state archive*)"]}}
JSON
ss_present_out="$("$EDM_STATE" session-start 2>&1 || true)"
check_absent "session-start omits PERM_RULES_MISSING when rules present" "PERM_RULES_MISSING" "$ss_present_out"
rm -f "$T06_CWD/.claude/settings.json"

# ---- AC7 -- warning only: validate exit code stays 0 either way ---------------
echo
echo "T06 AC7 -- validate exit code is 0 both with and without the rules present"
set +e
"$EDM_STATE" validate T06PERM >/dev/null 2>&1
ec_no_rules=$?
set -e
[[ $ec_no_rules -eq 0 ]] && pass "AC7 -- validate exit 0 without rules present" \
  || fail "AC7 -- validate exited $ec_no_rules without rules present, expected 0"

cat > "$T06_CWD/.claude/settings.json" <<'JSON'
{"permissions": {"ask": ["Bash(edm-state approve-gate*)", "Bash(edm-state archive*)"]}}
JSON
set +e
"$EDM_STATE" validate T06PERM >/dev/null 2>&1
ec_with_rules=$?
set -e
[[ $ec_with_rules -eq 0 ]] && pass "AC7 -- validate exit 0 with rules present" \
  || fail "AC7 -- validate exited $ec_with_rules with rules present, expected 0"

# ---- AC8/AC9 -- enforcement tag, positive and negative -------------------------
echo
echo "T06 AC8/AC9 -- approval with/without rules records the correct enforcement tag"
"$EDM_STATE" init T06ENF >/dev/null
"$EDM_STATE" approve-gate T06ENF 1 >/dev/null   # rules present from the block above
enf_with="$(jq -r '.gates_approved[0].enforcement' "$TMP/SRD/T06ENF/.edm-state.json")"
[[ "$enf_with" == "permission-ask" ]] \
  && pass "AC8 -- approval with rules records permission-ask" \
  || fail "AC8 -- enforcement='$enf_with', expected permission-ask"

rm -f "$T06_CWD/.claude/settings.json"
"$EDM_STATE" approve-gate T06ENF 2 >/dev/null   # rules now absent
enf_without="$(jq -r '.gates_approved[1].enforcement' "$TMP/SRD/T06ENF/.edm-state.json")"
[[ "$enf_without" == "prose-only" ]] \
  && pass "AC9 -- approval without rules records prose-only" \
  || fail "AC9 -- enforcement='$enf_without', expected prose-only"

# ---- AC10 -- sibling scalar keys; read_bool / booleans unaffected -------------
echo
echo "T06 AC10 -- compliance/code-audit sibling scalar keys, read_bool and boolean shape unaffected"
"$EDM_STATE" init T06SIB >/dev/null
STATE_T06SIB="$TMP/SRD/T06SIB/.edm-state.json"
before_rb="$(jq -r '.compliance_gate_approved // false' "$STATE_T06SIB")"
"$EDM_STATE" approve-gate T06SIB 3.5 >/dev/null
after_rb="$(jq -r '.compliance_gate_approved' "$STATE_T06SIB")"
[[ "$before_rb" == "false" && "$after_rb" == "true" ]] \
  && pass "AC10 -- read_bool-observed compliance_gate_approved unchanged shape before/after sibling keys exist" \
  || fail "AC10 -- compliance_gate_approved before='$before_rb' after='$after_rb'"
cga_type="$(jq -r '(.compliance_gate_approved | type)' "$STATE_T06SIB")"
[[ "$cga_type" == "boolean" ]] && pass "AC10 -- compliance_gate_approved stays type boolean" \
  || fail "AC10 -- compliance_gate_approved type is '$cga_type', expected boolean"
check "AC10 -- compliance_gate_approved_at sibling key written" "compliance_gate_approved_at" \
  "$(jq -c '.' "$STATE_T06SIB")"
cga_enf="$(jq -r '.compliance_gate_enforcement' "$STATE_T06SIB")"
[[ "$cga_enf" == "prose-only" || "$cga_enf" == "permission-ask" ]] \
  && pass "AC10 -- compliance_gate_enforcement recorded a legal enforcement value" \
  || fail "AC10 -- compliance_gate_enforcement='$cga_enf'"

"$EDM_STATE" approve-gate T06SIB code-audit >/dev/null
cac_type="$(jq -r '(.code_audit_converged | type)' "$STATE_T06SIB")"
[[ "$cac_type" == "boolean" ]] && pass "AC10 -- code_audit_converged stays type boolean" \
  || fail "AC10 -- code_audit_converged type is '$cac_type', expected boolean"

# ---- AC12 -- C-4: legacy state (predating enforcement field) renders without tag
echo
echo "T06 AC12 -- legacy state renders HANDOFF without enforcement tag"
"$EDM_STATE" init T06LEGACY >/dev/null
STATE_T06LEGACY="$TMP/SRD/T06LEGACY/.edm-state.json"
# Craft a pre-EDMV3-T06 compliance-gate approval: approved=true with no approved_at/
# approver/enforcement siblings, exactly what cmd_approve_gate wrote before this ticket.
jq '.compliance_gate_approved = true' "$STATE_T06LEGACY" > "$STATE_T06LEGACY.tmp" \
  && mv "$STATE_T06LEGACY.tmp" "$STATE_T06LEGACY"
"$EDM_STATE" write-handoff T06LEGACY >/dev/null
legacy_handoff="$TMP/SRD/T06LEGACY/HANDOFF.md"
check "AC12 -- legacy compliance gate 3.5 row renders" "Gate 3.5" "$(cat "$legacy_handoff")"
check_absent "AC12 -- legacy compliance gate row omits enforcement tag" "enforcement:" "$(cat "$legacy_handoff")"

t06_restore_env
rm -rf "$T06_HOME" "$T06_CWD"

# =================================================================================
# EDMV3-T17: HANDOFF and anomalies surface the new lifecycle facts (wave A)
# =================================================================================
echo
echo "T17 -- HANDOFF gate list, four-state next_action, CONVERGED_NO_APPROVAL, ASCII fix"

# ---- AC1 -- HANDOFF gate list renders code-audit and Gate 3.5 with all 4 fields
echo
echo "T17 AC1 -- HANDOFF gate list renders code-audit and Gate 3.5 rows with all four fields"
"$EDM_STATE" init T17GATES >/dev/null
"$EDM_STATE" approve-gate T17GATES 3.5 >/dev/null
"$EDM_STATE" approve-gate T17GATES code-audit >/dev/null
"$EDM_STATE" write-handoff T17GATES >/dev/null
handoff_t17gates="$(cat "$TMP/SRD/T17GATES/HANDOFF.md")"
check "AC1 -- code-audit gate row present" "code-audit" "$handoff_t17gates"
check "AC1 -- Gate 3.5 row present" "Gate 3.5" "$handoff_t17gates"
ca_row="$(echo "$handoff_t17gates" | grep 'Gate code-audit' | head -1)"
check "AC1 -- code-audit row shows approver" "$(id -un 2>/dev/null || echo "${USER:-unknown}")" "$ca_row"
check "AC1 -- code-audit row shows enforcement tag" "enforcement:" "$ca_row"

# ---- AC1 -- exemption visibility (mode with no code-audit round) --------------
echo
echo "T17 AC1 -- code-audit row shows exemption when the mode requires no audit round"
"$EDM_STATE" init T17EXEMPT >/dev/null
"$EDM_STATE" set-mode T17EXEMPT mode prototype >/dev/null
"$EDM_STATE" approve-gate T17EXEMPT code-audit >/dev/null
"$EDM_STATE" write-handoff T17EXEMPT >/dev/null
handoff_exempt="$(cat "$TMP/SRD/T17EXEMPT/HANDOFF.md")"
check "AC1 -- exemption row present" "CONVERGENCE_NOT_REQUIRED" "$handoff_exempt"

# ---- AC2 -- phase-6 next_action distinguishes four states ---------------------
echo
echo "T17 AC2 -- phase-6 next_action four states"
"$EDM_STATE" init T17NEXT >/dev/null
"$EDM_STATE" approve-gate T17NEXT 1 >/dev/null
"$EDM_STATE" approve-gate T17NEXT 2 >/dev/null
"$EDM_STATE" approve-gate T17NEXT 3 >/dev/null
"$EDM_STATE" phase-start T17NEXT 6 >/dev/null
"$EDM_STATE" write-handoff T17NEXT >/dev/null
next_in_progress="$(grep '^- \*\*Next action\*\*' "$TMP/SRD/T17NEXT/HANDOFF.md")"

"$EDM_STATE" record-partial-verdict T17NEXT T17NEXT-T01 PARTIAL "needs runtime check" >/dev/null
"$EDM_STATE" write-handoff T17NEXT >/dev/null
next_partial="$(grep '^- \*\*Next action\*\*' "$TMP/SRD/T17NEXT/HANDOFF.md")"

"$EDM_STATE" record-partial-verdict T17NEXT T17NEXT-T01 PASS "runtime verified" >/dev/null
jq '.phase_durations["6_phase"].completed_at = "2026-07-26T00:00:00Z"' \
  "$TMP/SRD/T17NEXT/.edm-state.json" > "$TMP/SRD/T17NEXT/.edm-state.json.tmp" \
  && mv "$TMP/SRD/T17NEXT/.edm-state.json.tmp" "$TMP/SRD/T17NEXT/.edm-state.json"
"$EDM_STATE" write-handoff T17NEXT >/dev/null
next_awaiting_gate="$(grep '^- \*\*Next action\*\*' "$TMP/SRD/T17NEXT/HANDOFF.md")"

"$EDM_STATE" approve-gate T17NEXT code-audit >/dev/null
next_ready="$(grep '^- \*\*Next action\*\*' "$TMP/SRD/T17NEXT/HANDOFF.md")"

check "AC2 -- state 1 (implementation in progress)" "in progress" "$next_in_progress"
check "AC2 -- state 2 (awaiting runtime verification of open PARTIALs)" "PARTIAL" "$next_partial"
check "AC2 -- state 3 (awaiting the convergence gate)" "convergence gate" "$next_awaiting_gate"
check "AC2 -- state 4 (ready to archive)" "Ready to archive" "$next_ready"
[[ "$next_in_progress" != "$next_partial" && "$next_partial" != "$next_awaiting_gate" \
   && "$next_awaiting_gate" != "$next_ready" && "$next_in_progress" != "$next_ready" ]] \
  && pass "AC2 -- all four next_action strings are distinct" \
  || fail "AC2 -- next_action strings collided: '$next_in_progress' / '$next_partial' / '$next_awaiting_gate' / '$next_ready'"

# ---- AC3 -- CONVERGED_NO_APPROVAL fires on a hand-set flag, and not on legacy --
echo
echo "T17 AC3 -- CONVERGED_NO_APPROVAL fires on a hand-set flag with four fields and class blocking"
"$EDM_STATE" init T17CONV >/dev/null
STATE_T17CONV="$TMP/SRD/T17CONV/.edm-state.json"
jq '.code_audit_converged = true' "$STATE_T17CONV" > "$STATE_T17CONV.tmp" && mv "$STATE_T17CONV.tmp" "$STATE_T17CONV"
set +e
conv_ec=0
conv_out="$("$EDM_STATE" validate T17CONV 2>&1)" || conv_ec=$?
set -e
check "AC3 -- CONVERGED_NO_APPROVAL present" "blocking  CONVERGED_NO_APPROVAL  code_audit_converged" "$conv_out"
[[ $conv_ec -eq 3 ]] && pass "AC3 -- CONVERGED_NO_APPROVAL is class blocking (validate exits 3)" \
  || fail "AC3 -- validate exited $conv_ec, expected 3"

echo
echo "T17 AC3 -- does not fire on a legacy file (no schema_version)"
"$EDM_STATE" init T17LEGACYCONV >/dev/null
STATE_T17LEGACYCONV="$TMP/SRD/T17LEGACYCONV/.edm-state.json"
jq 'del(.schema_version) | .code_audit_converged = true' "$STATE_T17LEGACYCONV" \
  > "$STATE_T17LEGACYCONV.tmp" && mv "$STATE_T17LEGACYCONV.tmp" "$STATE_T17LEGACYCONV"
legacyconv_out="$("$EDM_STATE" validate T17LEGACYCONV 2>&1 || true)"
check_absent "AC3 -- CONVERGED_NO_APPROVAL absent for legacy (no schema_version) file" \
  "CONVERGED_NO_APPROVAL" "$legacyconv_out"

# ---- AC4 -- severity declared, informational anomaly does not flip exit code --
echo
echo "T17 AC4 -- an initiative whose only anomaly is informational exits 0"
"$EDM_STATE" init T17SEV >/dev/null
set +e
sev_ec=0
sev_out="$("$EDM_STATE" validate T17SEV 2>&1)" || sev_ec=$?
set -e
echo "exit=$sev_ec"
[[ $sev_ec -eq 0 ]] && pass "AC4 -- informational-only anomalies leave validate exit 0" \
  || fail "AC4 -- validate exited $sev_ec, expected 0"

# ---- AC5 -- Notes section preserved across regeneration -----------------------
echo
echo "T17 AC5 -- Notes section preserved across HANDOFF regeneration"
"$EDM_STATE" init T17NOTES >/dev/null
"$EDM_STATE" write-handoff T17NOTES >/dev/null
notes_path="$TMP/SRD/T17NOTES/HANDOFF.md"
python3 -c "
import re
with open('$notes_path') as f:
    content = f.read()
content = content.replace('## Notes', '## Notes' + chr(10) + 'A teammate note that must survive regeneration.', 1)
with open('$notes_path', 'w') as f:
    f.write(content)
" 2>/dev/null || {
  awk '{print} /^## Notes$/{print "A teammate note that must survive regeneration."}' "$notes_path" > "$notes_path.tmp" \
    && mv "$notes_path.tmp" "$notes_path"
}
"$EDM_STATE" write-handoff T17NOTES >/dev/null
check "AC5 -- Notes content preserved across regeneration" \
  "A teammate note that must survive regeneration." "$(cat "$notes_path")"

# ---- CA-027 remediation (code-audit round 2): blank lines and a user "## " subheading -----
# inside Notes must survive verbatim, and the read-render-write must be lock-serialized.
# Round-1's fix only proved a single content LINE survives (AC5 above); CA-027 named two
# still-live defects the single-line case cannot catch: a `grep -v` pass that silently deleted
# every blank line in the user's own prose on every rewrite, and an `awk` stop condition
# (`p && /^## /{p=0}`) that truncated the Notes block at the FIRST `## ` a user typed inside
# their own notes, since `## Notes` is unconditionally the last generated heading.
echo
echo "CA-027 remediation: blank lines and a user-authored '## ' subheading survive write-handoff"
"$EDM_STATE" init ZCA27 >/dev/null
"$EDM_STATE" write-handoff ZCA27 >/dev/null
ca027_notes_path="$TMP/SRD/ZCA27/HANDOFF.md"
awk '{print} /^## Notes$/{
  print ""
  print "First paragraph of a real note."
  print ""
  print "## My Own Subheading"
  print "Text the user wrote under their own heading -- must not be truncated here."
  print ""
  print "Second paragraph, after a blank line and the user'\''s own heading."
}' "$ca027_notes_path" > "${ca027_notes_path}.tmp" && mv "${ca027_notes_path}.tmp" "$ca027_notes_path"
ca027_before="$(awk '/^## Notes/{f=1} f' "$ca027_notes_path")"
"$EDM_STATE" write-handoff ZCA27 >/dev/null
ca027_after="$(awk '/^## Notes/{f=1} f' "$ca027_notes_path")"
check "CA-027 -- first paragraph survives regeneration" \
  "First paragraph of a real note." "$ca027_after"
check "CA-027 -- a user-authored '## ' subheading inside Notes is NOT truncated away" \
  "## My Own Subheading" "$ca027_after"
check "CA-027 -- text under the user's own subheading survives" \
  "must not be truncated here" "$ca027_after"
check "CA-027 -- the second paragraph after the user's subheading also survives" \
  "Second paragraph, after a blank line" "$ca027_after"
ca027_blank_count="$(grep -c '^$' "$ca027_notes_path" || true)"
[[ "$ca027_blank_count" -gt 0 ]] \
  && pass "CA-027 -- blank lines inside the Notes block are preserved, not stripped" \
  || fail "CA-027 -- every blank line was deleted from the Notes block (the pre-fix grep -v regression)"
[[ "$ca027_before" == "$ca027_after" ]] \
  && pass "CA-027 -- the Notes block is byte-identical across two write-handoff runs" \
  || fail "CA-027 -- Notes block changed across regeneration runs (before != after)"

# ---- AC6 -- C-4: legacy HANDOFF omits new sections rather than erroring -------
echo
echo "T17 AC6 -- legacy initiative (no mode/schema_version) omits new sections without erroring"
"$EDM_STATE" init T17OLDINIT >/dev/null
STATE_T17OLDINIT="$TMP/SRD/T17OLDINIT/.edm-state.json"
jq 'del(.schema_version, .mode, .code_audit_converged, .compliance_gate_approved)' \
  "$STATE_T17OLDINIT" > "$STATE_T17OLDINIT.tmp" && mv "$STATE_T17OLDINIT.tmp" "$STATE_T17OLDINIT"
set +e
"$EDM_STATE" write-handoff T17OLDINIT >/dev/null 2>&1
oldinit_ec=$?
set -e
[[ $oldinit_ec -eq 0 ]] && pass "AC6 -- write-handoff on a legacy state file does not error" \
  || fail "AC6 -- write-handoff exited $oldinit_ec on a legacy state file"
oldinit_handoff="$(cat "$TMP/SRD/T17OLDINIT/HANDOFF.md")"
check_absent "AC6 -- legacy HANDOFF omits a code-audit gate row" "Gate code-audit" "$oldinit_handoff"
check_absent "AC6 -- legacy HANDOFF omits a Gate 3.5 row" "Gate 3.5" "$oldinit_handoff"

# ---- AC7/AC8 -- generator's own next_action strings are ASCII-only ------------
echo
echo "T17 AC7/AC8 -- next_action strings for skipped phases 1, 3, 5 are ASCII-only"
"$EDM_STATE" init T17ASCII1 >/dev/null
"$EDM_STATE" skip-phase T17ASCII1 1 "smoke test" >/dev/null
"$EDM_STATE" write-handoff T17ASCII1 >/dev/null
ascii1_next="$(grep '^- \*\*Next action\*\*' "$TMP/SRD/T17ASCII1/HANDOFF.md")"
check "AC7 -- phase 1 skipped next_action present" "skipped" "$ascii1_next"

"$EDM_STATE" init T17ASCII3 >/dev/null
"$EDM_STATE" approve-gate T17ASCII3 1 >/dev/null
"$EDM_STATE" phase-start T17ASCII3 2 >/dev/null
"$EDM_STATE" skip-phase T17ASCII3 3 "smoke test" >/dev/null
"$EDM_STATE" write-handoff T17ASCII3 >/dev/null
ascii3_next="$(grep '^- \*\*Next action\*\*' "$TMP/SRD/T17ASCII3/HANDOFF.md")"
check "AC7 -- phase 3 skipped next_action present" "skipped" "$ascii3_next"

"$EDM_STATE" init T17ASCII5 >/dev/null
"$EDM_STATE" approve-gate T17ASCII5 1 >/dev/null
"$EDM_STATE" approve-gate T17ASCII5 2 >/dev/null
"$EDM_STATE" phase-start T17ASCII5 4 >/dev/null
"$EDM_STATE" skip-phase T17ASCII5 5 "smoke test" >/dev/null
"$EDM_STATE" write-handoff T17ASCII5 >/dev/null
ascii5_next="$(grep '^- \*\*Next action\*\*' "$TMP/SRD/T17ASCII5/HANDOFF.md")"
check "AC7 -- phase 5 skipped next_action present" "skipped" "$ascii5_next"

# current_phase 6 fixture (shard-2 QC remediation): phases 1/3/5 above never reach the
# phase-6 pending_artifacts branch (bin/edm-state's `case "$phase" in ... 6)` arm), so a
# non-ASCII regression there (EDMV3-T17 AC8 shard-2 finding) went undetected by this loop
# until now. Drive current_phase to 6 via the three gate approvals rather than skip-phase.
"$EDM_STATE" init T17ASCII6 >/dev/null
"$EDM_STATE" approve-gate T17ASCII6 1 >/dev/null
"$EDM_STATE" phase-start T17ASCII6 2 >/dev/null
"$EDM_STATE" phase-start T17ASCII6 3 >/dev/null
"$EDM_STATE" approve-gate T17ASCII6 2 >/dev/null
"$EDM_STATE" phase-start T17ASCII6 4 >/dev/null
"$EDM_STATE" phase-start T17ASCII6 5 >/dev/null
"$EDM_STATE" approve-gate T17ASCII6 3 >/dev/null
"$EDM_STATE" phase-start T17ASCII6 6 >/dev/null
"$EDM_STATE" write-handoff T17ASCII6 >/dev/null
ascii6_pending="$(grep '^- \*\*Pending artifacts\*\*\|implementation in progress' "$TMP/SRD/T17ASCII6/HANDOFF.md" || true)"
check "AC8 -- phase 6 pending_artifacts note present" "implementation in progress" "$ascii6_pending"

# Portable ASCII check: delete every byte in the ASCII range (octal 000-177, POSIX `tr`
# range syntax works identically under GNU and BSD `tr`, unlike `grep`'s `\x` hex-escape
# bracket-expression support, which BSD/macOS grep 2.6.0-FreeBSD does NOT implement --
# empirically confirmed to false-positive-match plain ASCII text with `[^\x00-\x7F]`. Any
# bytes surviving the deletion are non-ASCII.
_t17_nonascii_bytes() {
  LC_ALL=C tr -d '\000-\177' < "$1" | wc -c | tr -d ' '
}

ascii_all_clean=true
for _t17_f in "$TMP/SRD/T17ASCII1/HANDOFF.md" "$TMP/SRD/T17ASCII3/HANDOFF.md" "$TMP/SRD/T17ASCII5/HANDOFF.md" \
              "$TMP/SRD/T17ASCII6/HANDOFF.md"; do
  [[ "$(_t17_nonascii_bytes "$_t17_f")" -eq 0 ]] || ascii_all_clean=false
done
if [[ "$ascii_all_clean" == "true" ]]; then
  pass "AC7/AC8 -- HANDOFF for an initiative with skipped phases 1, 3, 5 and a current_phase-6 initiative is ASCII-only"
else
  fail "AC7/AC8 -- HANDOFF for skipped phases 1, 3, 5, or the current_phase-6 fixture, contains non-ASCII bytes"
fi

# Bounded on the unique "Derive what to do next" comment through that specific case
# block's own `esac` -- NOT a bare `case "$phase" in` pattern, which also matches two
# unrelated case blocks elsewhere in the file (out of AC7's scope, per the ticket's own
# "next_action block only" scope note).
case_block_nonascii_count="$(awk '/# Derive what to do next from current phase \+ gates approved/,/^  esac$/' "$EDM_STATE" \
  | LC_ALL=C tr -d '\000-\177' | wc -c | tr -d ' ')"
if [[ "$case_block_nonascii_count" -eq 0 ]]; then
  pass "AC7 -- next_action case block in bin/edm-state is ASCII-only"
else
  fail "AC7 -- next_action case block in bin/edm-state still contains non-ASCII bytes"
fi

# =================================================================================
# EDMV3-T10: edm-state migrate-schema backfills schema_version on existing initiatives
# =================================================================================
echo
echo "T10 -- migrate-schema backfill, honest versioning, SCHEMA_VERSION_MISSING"

# ---- AC1/AC6: report fields printed; SCHEMA_VERSION_MISSING is informational --------------
echo
echo "T10 AC1/AC6 -- migrate-schema report fields; SCHEMA_VERSION_MISSING is informational"
"$EDM_STATE" init MIGSCH1 >/dev/null
STATE_MIGSCH1="$TMP/SRD/MIGSCH1/.edm-state.json"
jq 'del(.schema_version)' "$STATE_MIGSCH1" > "$STATE_MIGSCH1.tmp" && mv "$STATE_MIGSCH1.tmp" "$STATE_MIGSCH1"

set +e
migsch1_validate_ec=0
migsch1_validate_out="$("$EDM_STATE" validate MIGSCH1 2>&1)" || migsch1_validate_ec=$?
set -e
[[ $migsch1_validate_ec -eq 0 ]] && pass "AC6 -- SCHEMA_VERSION_MISSING does not flip validate's exit code" \
  || fail "AC6 -- validate exited $migsch1_validate_ec, expected 0"
check "AC6 -- SCHEMA_VERSION_MISSING anomaly text present" "info  SCHEMA_VERSION_MISSING" "$migsch1_validate_out"

_t10_migsch1_migrate() { echo yes | "$EDM_STATE" migrate-schema MIGSCH1; }
migsch1_report="$(_t10_migsch1_migrate)"
check "AC1 -- report shows current_phase" "current_phase" "$migsch1_report"
check "AC1 -- report shows gates_approved" "gates_approved" "$migsch1_report"
check "AC1 -- report shows terminal-phase completed_at" "completed_at" "$migsch1_report"
check "AC1 -- report shows findings ledger status" "findings ledger" "$migsch1_report"
check "AC1 -- report shows unclosed PARTIAL count" "unclosed PARTIAL" "$migsch1_report"
migsch1_sv="$(jq -r '.schema_version' "$STATE_MIGSCH1")"
[[ "$migsch1_sv" == "1" ]] && pass "AC1 -- schema_version stamped as 1 on a legacy state file" \
  || fail "AC1 -- schema_version = '$migsch1_sv', expected 1"

# ---- AC3 (negative): second migration attempt refused, naming the recorded value ----------
echo
echo "T10 AC3 -- second migration attempt refused naming the recorded value"
_t10_migsch1_noconfirm() { "$EDM_STATE" migrate-schema MIGSCH1 < /dev/null; }
check_refuses_and_leaves_state "second migrate-schema attempt refused" "already has schema_version=1" "$STATE_MIGSCH1" _t10_migsch1_noconfirm

# ---- AC3 (advance-by-one): once a higher shape is satisfied, advances by exactly one ------
echo
echo "T10 AC3 -- advances by exactly one once version-2 shapes are satisfied"
mkdir -p "$TMP/SRD/MIGSCH1/code-audit"
echo '{"id":"CA-001"}' > "$TMP/SRD/MIGSCH1/code-audit/findings-ledger.jsonl"
migsch1_advance_out="$(_t10_migsch1_migrate)"
check "AC3 -- advance message names 1 -> 2" "1 -> 2" "$migsch1_advance_out"
migsch1_sv2="$(jq -r '.schema_version' "$STATE_MIGSCH1")"
[[ "$migsch1_sv2" == "2" ]] && pass "AC3 -- schema_version advances by exactly one (1 -> 2)" \
  || fail "AC3 -- schema_version = '$migsch1_sv2', expected 2"

# ---- AC2 (honest version, negative): markdown-only ledger + open PARTIAL migrates to 1 ----
echo
echo "T10 AC2 -- markdown ledger + open PARTIAL migrates to 1, not 2"
"$EDM_STATE" init MIGSCH2 >/dev/null
STATE_MIGSCH2="$TMP/SRD/MIGSCH2/.edm-state.json"
jq 'del(.schema_version)' "$STATE_MIGSCH2" > "$STATE_MIGSCH2.tmp" && mv "$STATE_MIGSCH2.tmp" "$STATE_MIGSCH2"
mkdir -p "$TMP/SRD/MIGSCH2/code-audit"
echo "# Findings Ledger" > "$TMP/SRD/MIGSCH2/code-audit/findings-ledger.md"
"$EDM_STATE" record-partial-verdict MIGSCH2 MIGSCH2-T01 PARTIAL "needs runtime check" >/dev/null
echo yes | "$EDM_STATE" migrate-schema MIGSCH2 >/dev/null
migsch2_sv="$(jq -r '.schema_version' "$STATE_MIGSCH2")"
[[ "$migsch2_sv" == "1" ]] && pass "AC2 -- markdown ledger + open PARTIAL migrates to 1, not 2" \
  || fail "AC2 -- schema_version = '$migsch2_sv', expected 1"

# ---- AC2 (honest version, positive): JSONL ledger + closed PARTIALs advances to 2 ---------
echo
echo "T10 AC2 -- JSONL ledger with closed PARTIALs advances to 2 on first migration"
"$EDM_STATE" init MIGSCH3 >/dev/null
STATE_MIGSCH3="$TMP/SRD/MIGSCH3/.edm-state.json"
jq 'del(.schema_version)' "$STATE_MIGSCH3" > "$STATE_MIGSCH3.tmp" && mv "$STATE_MIGSCH3.tmp" "$STATE_MIGSCH3"
mkdir -p "$TMP/SRD/MIGSCH3/code-audit"
echo '{"id":"CA-001"}' > "$TMP/SRD/MIGSCH3/code-audit/findings-ledger.jsonl"
"$EDM_STATE" record-partial-verdict MIGSCH3 MIGSCH3-T01 PASS "runtime verified" >/dev/null
echo yes | "$EDM_STATE" migrate-schema MIGSCH3 >/dev/null
migsch3_sv="$(jq -r '.schema_version' "$STATE_MIGSCH3")"
[[ "$migsch3_sv" == "2" ]] && pass "AC2 -- JSONL ledger + zero open PARTIALs migrates directly to 2" \
  || fail "AC2 -- schema_version = '$migsch3_sv', expected 2"

# ---- AC4 (negative, archived): refuses on an archived initiative; never touches it --------
echo
echo "T10 AC4 -- archived initiative refused; state stays byte-identical"
"$EDM_STATE" init MIGSCH4 >/dev/null
jq 'del(.schema_version)' "$TMP/SRD/MIGSCH4/.edm-state.json" > "$TMP/SRD/MIGSCH4/.edm-state.json.tmp" \
  && mv "$TMP/SRD/MIGSCH4/.edm-state.json.tmp" "$TMP/SRD/MIGSCH4/.edm-state.json"
mkdir -p "$TMP/SRD/.archived"
mv "$TMP/SRD/MIGSCH4" "$TMP/SRD/.archived/MIGSCH4"
STATE_MIGSCH4_ARCH="$TMP/SRD/.archived/MIGSCH4/.edm-state.json"
_t10_migsch4_archived() { "$EDM_STATE" migrate-schema MIGSCH4 < /dev/null; }
check_refuses_and_leaves_state "archived initiative refused" "is archived" "$STATE_MIGSCH4_ARCH" _t10_migsch4_archived

# G23/CA-343: the AC4 archived-probe now routes through list_state_files --archived instead of
# hand-globbing both archived shapes itself -- exercise the PRODUCT-SCOPED shape too (the shape
# above only covers the flat one), so a future change to either enumeration path is still
# caught by both.
echo
echo "G23/CA-343 -- product-scoped archived initiative also refused via the shared list_state_files enumeration"
edm-init --product demo --description migsch6 MSCH6 >/dev/null
jq 'del(.schema_version)' "$TMP/SRD/demo/MSCH6__migsch6/.edm-state.json" \
  > "$TMP/SRD/demo/MSCH6__migsch6/.edm-state.json.tmp" \
  && mv "$TMP/SRD/demo/MSCH6__migsch6/.edm-state.json.tmp" "$TMP/SRD/demo/MSCH6__migsch6/.edm-state.json"
mkdir -p "$TMP/SRD/.archived/demo"
mv "$TMP/SRD/demo/MSCH6__migsch6" "$TMP/SRD/.archived/demo/MSCH6__migsch6"
STATE_MSCH6_ARCH="$TMP/SRD/.archived/demo/MSCH6__migsch6/.edm-state.json"
_t_g23_migsch6_archived() { "$EDM_STATE" migrate-schema MSCH6 < /dev/null; }
check_refuses_and_leaves_state "G23/CA-343 -- product-scoped archived initiative refused" "is archived" "$STATE_MSCH6_ARCH" _t_g23_migsch6_archived

# ---- AC7 (negative, confirmation required): no input piped refuses, no changes made -------
echo
echo "T10 AC7 (confirmation gate) -- refuses without a piped/typed confirmation"
"$EDM_STATE" init MIGSCH5 >/dev/null
STATE_MIGSCH5="$TMP/SRD/MIGSCH5/.edm-state.json"
jq 'del(.schema_version)' "$STATE_MIGSCH5" > "$STATE_MIGSCH5.tmp" && mv "$STATE_MIGSCH5.tmp" "$STATE_MIGSCH5"
_t10_migsch5_noinput() { "$EDM_STATE" migrate-schema MIGSCH5 < /dev/null; }
check_refuses_and_leaves_state "migrate-schema refuses without a piped/typed confirmation" "confirmation not received" "$STATE_MIGSCH5" _t10_migsch5_noinput

# ---- AC7 (hand-removal detectable): validate + HANDOFF render the migration prompt --------
echo
echo "T10 AC7 -- hand-removing schema_version fires the anomaly and HANDOFF renders the prompt"
echo yes | "$EDM_STATE" migrate-schema MIGSCH5 >/dev/null   # first stamp it, so removal is a real downgrade
jq 'del(.schema_version)' "$STATE_MIGSCH5" > "$STATE_MIGSCH5.tmp" && mv "$STATE_MIGSCH5.tmp" "$STATE_MIGSCH5"
migsch5_val_out="$("$EDM_STATE" validate MIGSCH5 2>&1)"
check "AC7 -- SCHEMA_VERSION_MISSING fires after hand-removal" "SCHEMA_VERSION_MISSING" "$migsch5_val_out"
"$EDM_STATE" write-handoff MIGSCH5 >/dev/null
migsch5_handoff="$(cat "$TMP/SRD/MIGSCH5/HANDOFF.md")"
check "AC7 -- HANDOFF.md renders the migration prompt" "edm-state migrate-schema MIGSCH5" "$migsch5_handoff"

# ---- AC5 (single writer) / AC9 (surfaced in --help, dispatch, CLAUDE.md) ------------------
echo
echo "T10 AC5/AC9 -- schema_version stays a single-writer field; surfaced in --help and CLAUDE.md"
check_fails "AC5 -- cmd_set still refuses schema_version, naming migrate-schema" \
  "edm-state migrate-schema <PREFIX>" \
  "$EDM_STATE" set MIGSCH2 schema_version 9
migsch_help_out="$("$EDM_STATE" --help)"
check "AC9 -- --help lists migrate-schema" "migrate-schema" "$migsch_help_out"
claude_md_hits="$(grep -c 'migrate-schema' "${SCRIPT_DIR}/../../CLAUDE.md" 2>/dev/null || echo 0)"
[[ "${claude_md_hits:-0}" -ge 1 ]] && pass "AC9 -- CLAUDE.md bin/ table lists migrate-schema" \
  || fail "AC9 -- migrate-schema not found in plugins/edm/CLAUDE.md"

# =================================================================================
# EDMV3-T11: phase-complete verifies the phase produced its artifact, with no force path
# =================================================================================
echo
echo "T11 -- phase-complete per-phase artifact verification"

# ---- AC1/AC2: per-phase artifact absent refuses (no mutation); present succeeds ----------
echo
echo "T11 AC1/AC2 -- per-phase artifact check (absent refuses, present succeeds)"

_t11_case() {
  local prefix="$1" phase="$2" artifact_rel="$3"
  "$EDM_STATE" init "$prefix" >/dev/null
  local dir="$TMP/SRD/$prefix"
  local state="${dir}/.edm-state.json"

  check_refuses_and_leaves_state "T11 AC2 -- phase ${phase} artifact absent refuses (${prefix})" "phase ${phase} artifact missing or empty" "$state" "$EDM_STATE" phase-complete "$prefix" "$phase"

  mkdir -p "$(dirname "${dir}/${artifact_rel}")"
  echo "content" > "${dir}/${artifact_rel}"
  "$EDM_STATE" phase-complete "$prefix" "$phase" >/dev/null \
    && pass "T11 AC1 -- phase ${phase} artifact present succeeds (${prefix})" \
    || fail "T11 AC1 -- phase ${phase} artifact present still refused (${prefix})"
}

_t11_case T11P1 1 "planning.md"
_t11_case T11P2 2 "srd.md"
_t11_case T11P3 3 "audit-srd.md"
_t11_case T11P4 4 "tickets/README.md"
_t11_case T11P5 5 "tickets/audit.md"

# Phase 6 gets its own case: qc/qc-summary.md (the base positive/negative pair, distinct
# from AC3's shard-only variant below).
"$EDM_STATE" init T11P6 >/dev/null
STATE_T11P6="$TMP/SRD/T11P6/.edm-state.json"
check_refuses_and_leaves_state "T11 AC2 -- phase 6 artifact absent refuses (T11P6)" "phase 6 artifact missing or empty" "$STATE_T11P6" "$EDM_STATE" phase-complete T11P6 6
mkdir -p "$TMP/SRD/T11P6/qc"
echo "# QC Summary" > "$TMP/SRD/T11P6/qc/qc-summary.md"
"$EDM_STATE" phase-complete T11P6 6 >/dev/null \
  && pass "T11 AC1 -- phase 6 artifact (qc-summary.md) present succeeds (T11P6)" \
  || fail "T11 AC1 -- phase 6 artifact present still refused (T11P6)"

# ---- AC3 (positive, sharded phase 6): qc-shard-01.md only still completes ----------------
echo
echo "T11 AC3 -- shard-only phase 6 completes"
"$EDM_STATE" init T11SHARD >/dev/null
mkdir -p "$TMP/SRD/T11SHARD/qc"
echo "# Shard 1" > "$TMP/SRD/T11SHARD/qc/qc-shard-01.md"
"$EDM_STATE" phase-complete T11SHARD 6 >/dev/null \
  && pass "T11 AC3 -- shard-only phase 6 completes" \
  || fail "T11 AC3 -- shard-only phase 6 still refused"

# ---- AC1 (shard-1 QC remediation): all six artifact-presence checks route through
# present_or_absent's nonempty variant, not a re-derived bare `[[ -s ]]` ------------------
echo
echo "T11 AC1 -- artifact-presence checks route through present_or_absent nonempty, not a bare [[ -s ]]"
t11_pc_block="$(awk '/^cmd_phase_complete\(\) \{/{f=1} f{print} f && /^\}/{exit}' "$EDM_STATE")"
t11_helper_hits="$(printf '%s\n' "$t11_pc_block" | grep -c 'present_or_absent "[^"]*" nonempty' || true)"
[[ "$t11_helper_hits" -ge 6 ]] \
  && pass "T11 AC1 -- cmd_phase_complete has >=6 present_or_absent ... nonempty call sites" \
  || fail "T11 AC1 -- expected >=6 present_or_absent ... nonempty call sites in cmd_phase_complete, found $t11_helper_hits"
check_absent "T11 AC1 -- cmd_phase_complete's artifact case block has no bare [[ -s ]] check" \
  '[[ -s "' "$t11_pc_block"

# ---- AC4: phase 6 with open PARTIAL refuses naming verify-runtime (requires schema_version >= 2) --
echo
echo "T11 AC4 -- phase 6 with open PARTIAL refuses naming verify-runtime (schema_version >= 2)"
"$EDM_STATE" init T11PARTIAL >/dev/null
STATE_T11PARTIAL="$TMP/SRD/T11PARTIAL/.edm-state.json"
jq '.schema_version = 2' "$STATE_T11PARTIAL" > "$STATE_T11PARTIAL.tmp" && mv "$STATE_T11PARTIAL.tmp" "$STATE_T11PARTIAL"
mkdir -p "$TMP/SRD/T11PARTIAL/qc"
echo "# QC Summary" > "$TMP/SRD/T11PARTIAL/qc/qc-summary.md"
"$EDM_STATE" record-partial-verdict T11PARTIAL T11PARTIAL-T01 PARTIAL "needs runtime check" >/dev/null
check_refuses_and_leaves_state "T11 AC4 -- phase 6 with open PARTIAL refuses naming verify-runtime" "verify-runtime" "$STATE_T11PARTIAL" "$EDM_STATE" phase-complete T11PARTIAL 6
"$EDM_STATE" record-partial-verdict T11PARTIAL T11PARTIAL-T01 PASS "runtime verified" >/dev/null
"$EDM_STATE" phase-complete T11PARTIAL 6 >/dev/null \
  && pass "T11 AC4 -- phase 6 completes once the PARTIAL is closed" \
  || fail "T11 AC4 -- phase 6 still refused after the PARTIAL was closed"

# ---- AC4 (G2/CA-333, round 6: this degradation was removed) -- schema_version 1 now
# refuses on the open-PARTIAL check exactly like schema_version 2 above, instead of
# warning and proceeding. `_cmd_init_render` writes the literal schema_version 1 for every
# initiative the current plugin creates, so the old >= 2 gate made this refusal
# environmentally unreachable in the shipped default -- the same class CA-182 fixed for
# cmd_approve_gate's code-audit precheck. -------------------------------------------------
echo
echo "T11 AC4/G2/CA-333 -- schema_version 1 now refuses on the open-PARTIAL check (no longer degraded)"
"$EDM_STATE" init T11PARTIALV1 >/dev/null
mkdir -p "$TMP/SRD/T11PARTIALV1/qc"
echo "# QC Summary" > "$TMP/SRD/T11PARTIALV1/qc/qc-summary.md"
"$EDM_STATE" record-partial-verdict T11PARTIALV1 T11PARTIALV1-T01 PARTIAL "needs runtime check" >/dev/null
STATE_T11PARTIALV1="$TMP/SRD/T11PARTIALV1/.edm-state.json"
check_refuses_and_leaves_state "T11 AC4/G2/CA-333 -- schema_version 1 refuses on the open-PARTIAL check naming verify-runtime" \
  "verify-runtime" "$STATE_T11PARTIALV1" "$EDM_STATE" phase-complete T11PARTIALV1 6
"$EDM_STATE" record-partial-verdict T11PARTIALV1 T11PARTIALV1-T01 PASS "runtime verified" >/dev/null
"$EDM_STATE" phase-complete T11PARTIALV1 6 >/dev/null \
  && pass "T11 AC4/G2/CA-333 -- schema_version 1 phase 6 completes once the PARTIAL is closed" \
  || fail "T11 AC4/G2/CA-333 -- schema_version 1 phase 6 still refused after the PARTIAL was closed"

# ---- AC5: skipped-phase exemption for the artifact; phase 6's PARTIAL check is NOT exempted --
echo
echo "T11 AC5 -- skipped-phase artifact exemption; phase 6 PARTIAL check has no such exemption"
"$EDM_STATE" init T11SKIP2 >/dev/null
"$EDM_STATE" skip-phase T11SKIP2 2 "mini-srd fused SRD" >/dev/null
"$EDM_STATE" phase-complete T11SKIP2 2 >/dev/null \
  && pass "T11 AC5 -- skipped phase 2 completes without srd.md" \
  || fail "T11 AC5 -- skipped phase 2 still refused despite the skip record"

"$EDM_STATE" init T11SKIP6 >/dev/null
STATE_T11SKIP6="$TMP/SRD/T11SKIP6/.edm-state.json"
jq '.schema_version = 2' "$STATE_T11SKIP6" > "$STATE_T11SKIP6.tmp" && mv "$STATE_T11SKIP6.tmp" "$STATE_T11SKIP6"
"$EDM_STATE" skip-phase T11SKIP6 6 "zero-ticket phase 6" >/dev/null
"$EDM_STATE" record-partial-verdict T11SKIP6 T11SKIP6-T01 PARTIAL "needs runtime check" >/dev/null
check_fails "T11 AC5 -- skipped phase 6 still refuses on an open PARTIAL" \
  "verify-runtime" \
  "$EDM_STATE" phase-complete T11SKIP6 6

# ---- AC6: mode seeding makes the phase-2 exemption reachable on a fresh mini-srd initiative --
echo
echo "T11 AC6 -- fresh mini-srd initiative's phase-complete 2 succeeds (mode-seeded skip)"
export EDM_MODE="mini-srd"
"$EDM_STATE" init T11MINI >/dev/null
unset EDM_MODE
"$EDM_STATE" phase-complete T11MINI 2 >/dev/null \
  && pass "T11 AC6 -- fresh mini-srd phase-complete 2 succeeds" \
  || fail "T11 AC6 -- fresh mini-srd phase-complete 2 refused despite mode seeding"

# ---- AC7 (negative, no force path): --force is an unknown-argument error, not a bypass ---
echo
echo "T11 AC7 -- phase-complete --force is an unknown argument"
check_fails "T11 AC7 -- phase-complete --force is an unknown argument" \
  "usage: edm-state phase-complete" \
  "$EDM_STATE" phase-complete T11P1 1 --force

# ---- AC8 (C-4): legacy state (no schema_version) warns and proceeds ----------------------
echo
echo "T11 AC8 -- legacy phase-complete warns and proceeds"
"$EDM_STATE" init T11LEGACY >/dev/null
STATE_T11LEGACY="$TMP/SRD/T11LEGACY/.edm-state.json"
jq 'del(.schema_version)' "$STATE_T11LEGACY" > "$STATE_T11LEGACY.tmp" && mv "$STATE_T11LEGACY.tmp" "$STATE_T11LEGACY"
set +e
legacy_pc_ec=0
legacy_pc_out="$("$EDM_STATE" phase-complete T11LEGACY 1 2>&1)" || legacy_pc_ec=$?
set -e
check "T11 AC8 -- legacy phase-complete warns rather than hard-failing" \
  "[warn] legacy initiative" "$legacy_pc_out"
[[ $legacy_pc_ec -eq 0 ]] && pass "T11 AC8 -- legacy phase-complete proceeds (exit 0) despite no planning.md" \
  || fail "T11 AC8 -- legacy phase-complete exited $legacy_pc_ec, expected 0"

# ---- AC9 (preserve): artifact-hash recording still works for phase 2 ---------------------
echo
echo "T11 AC9 -- artifact-hash recording preserved for phase 2"
"$EDM_STATE" init T11HASH >/dev/null
echo "# SRD" > "$TMP/SRD/T11HASH/srd.md"
"$EDM_STATE" phase-complete T11HASH 2 >/dev/null
hash_check="$("$EDM_STATE" get T11HASH | jq -r '.artifact_hashes.srd.hash // "null"')"
[[ -n "$hash_check" && "$hash_check" != "null" ]] \
  && pass "T11 AC9 -- artifact_hashes.srd.hash recorded after phase-complete 2" \
  || fail "T11 AC9 -- artifact_hashes.srd.hash missing/null after phase-complete 2"

# ---- AC10: comment states the three fixed filenames are not user-configurable -----------
echo
echo "T11 AC10 -- comment documents the fixed vs. configurable artifact filenames"
ac10_hits="$(sed -n '/^cmd_phase_complete() {/,/^}/p' "$EDM_STATE" | grep -c 'NOT user-configurable' || true)"
[[ "$ac10_hits" -ge 1 ]] && pass "T11 AC10 -- comment present inside cmd_phase_complete" \
  || fail "T11 AC10 -- comment not found inside cmd_phase_complete"

# =================================================================================
# EDMV3-T12: archive verifies the whole lifecycle (wave-A sub-checks)
# =================================================================================
echo
echo "T12 -- archive lifecycle verification (gates, terminal phase, completed_at, convergence)"

# ---- AC1 (negative, gates): every gate required_gates_for_mode() returns must be approved --
echo
echo "T12 AC1 -- archive refuses on missing gates, naming each"
"$EDM_STATE" init T12GATE >/dev/null
STATE_T12GATE="$TMP/SRD/T12GATE/.edm-state.json"
check_refuses_and_leaves_state "T12 AC1 -- archive refuses naming all three missing gates" "gate(s) 1, 2, 3 not approved" "$STATE_T12GATE" "$EDM_STATE" archive T12GATE
[[ -d "$TMP/SRD/T12GATE" ]] && pass "T12 AC1 -- refusal leaves the initiative directory in place" \
  || fail "T12 AC1 -- initiative directory moved despite refusal"

"$EDM_STATE" approve-gate T12GATE 1 >/dev/null
"$EDM_STATE" approve-gate T12GATE 2 >/dev/null
check_fails "T12 AC1 -- archive with gates 1 and 2 but not 3 refuses naming gate 3" \
  "gate(s) 3 not approved" \
  "$EDM_STATE" archive T12GATE

# ---- AC2 (negative, terminal phase): current_phase must equal the derived terminal phase --
echo
echo "T12 AC2 -- archive at current_phase 5 refuses (terminal phase is derived, not hardcoded)"
"$EDM_STATE" init T12PHASE >/dev/null
STATE_T12PHASE="$TMP/SRD/T12PHASE/.edm-state.json"
"$EDM_STATE" approve-gate T12PHASE 1 >/dev/null
"$EDM_STATE" approve-gate T12PHASE 2 >/dev/null
"$EDM_STATE" approve-gate T12PHASE 3 >/dev/null
"$EDM_STATE" set T12PHASE current_phase 5 >/dev/null
check_refuses_and_leaves_state "T12 AC2 -- archive at current_phase 5 refuses" "has not reached the terminal phase (6)" "$STATE_T12PHASE" "$EDM_STATE" archive T12PHASE

# ---- AC3 (negative, completed_at): the terminal phase's completed_at must be recorded -----
echo
echo "T12 AC3 -- archive without terminal completed_at refuses"
"$EDM_STATE" init T12COMPLETED >/dev/null
STATE_T12COMPLETED="$TMP/SRD/T12COMPLETED/.edm-state.json"
"$EDM_STATE" approve-gate T12COMPLETED 1 >/dev/null
"$EDM_STATE" approve-gate T12COMPLETED 2 >/dev/null
"$EDM_STATE" approve-gate T12COMPLETED 3 >/dev/null
"$EDM_STATE" set T12COMPLETED current_phase 6 >/dev/null
check_refuses_and_leaves_state "T12 AC3 -- archive without terminal completed_at refuses" "has no completed_at recorded" "$STATE_T12COMPLETED" "$EDM_STATE" archive T12COMPLETED

# ---- AC4/AC5 (negative, convergence, unconditional on product_name): converged=false -------
echo
echo "T12 AC4/AC5 -- converged=false refuses naming approve-gate code-audit (flat-layout, no product_name)"
"$EDM_STATE" init T12CONV >/dev/null
STATE_T12CONV="$TMP/SRD/T12CONV/.edm-state.json"
"$EDM_STATE" approve-gate T12CONV 1 >/dev/null
"$EDM_STATE" approve-gate T12CONV 2 >/dev/null
"$EDM_STATE" approve-gate T12CONV 3 >/dev/null
jq '.current_phase = 6 | .phase_durations["6_phase"] = {started_at: "2026-01-01T00:00:00Z", completed_at: "2026-01-01T01:00:00Z"}' \
  "$STATE_T12CONV" > "$STATE_T12CONV.tmp" && mv "$STATE_T12CONV.tmp" "$STATE_T12CONV"
t12conv_product="$(jq -r '.product_name' "$STATE_T12CONV")"
[[ -z "$t12conv_product" ]] && pass "T12 AC5 -- fixture is flat-layout (product_name empty)" \
  || fail "T12 AC5 -- fixture unexpectedly has product_name='$t12conv_product'"
check_refuses_and_leaves_state "T12 AC4 -- archive with converged=false refuses naming approve-gate code-audit" "edm-state approve-gate T12CONV code-audit" "$STATE_T12CONV" "$EDM_STATE" archive T12CONV

# ---- AC6: no wave-A archive refusal names a wave-B command --------------------------------
echo
echo "T12 AC6 -- no wave-A refusal names a wave-B command"
t12conv_out="$("$EDM_STATE" archive T12CONV 2>&1 || true)"
check_absent "T12 AC6 -- convergence refusal does not name verify-runtime" "verify-runtime" "$t12conv_out"
check_absent "T12 AC6 -- convergence refusal does not name audit-converged" "audit-converged" "$t12conv_out"

# ---- AC7 (positive, happy path): a fully compliant initiative archives successfully --------
echo
echo "T12 AC7 -- fully compliant standard-lifecycle initiative archives successfully"
"$EDM_STATE" init T12HAPPY >/dev/null
"$EDM_STATE" set T12HAPPY product_name testprod >/dev/null
STATE_T12HAPPY="$TMP/SRD/T12HAPPY/.edm-state.json"
"$EDM_STATE" approve-gate T12HAPPY 1 >/dev/null
"$EDM_STATE" approve-gate T12HAPPY 2 >/dev/null
"$EDM_STATE" approve-gate T12HAPPY 3 >/dev/null
jq '.current_phase = 6 | .phase_durations["6_phase"] = {started_at: "2026-01-01T00:00:00Z", completed_at: "2026-01-01T01:00:00Z"}' \
  "$STATE_T12HAPPY" > "$STATE_T12HAPPY.tmp" && mv "$STATE_T12HAPPY.tmp" "$STATE_T12HAPPY"
"$EDM_STATE" approve-gate T12HAPPY code-audit >/dev/null
"$EDM_STATE" archive T12HAPPY >/dev/null \
  && pass "T12 AC7 -- fully compliant initiative archives successfully" \
  || fail "T12 AC7 -- compliant initiative was refused"
[[ -d "$TMP/SRD/.archived/testprod/T12HAPPY" ]] \
  && pass "T12 AC7 -- archived to the expected product-scoped destination" \
  || fail "T12 AC7 -- archived directory not found at expected destination"

# ---- AC8: prototype waives convergence only, not gate/phase/completed_at ------------------
echo
echo "T12 AC8 -- prototype waives convergence only (not the gate/phase/completed_at checks)"
export EDM_MODE="prototype"
"$EDM_STATE" init T12PROTO >/dev/null
unset EDM_MODE
STATE_T12PROTO="$TMP/SRD/T12PROTO/.edm-state.json"
check_refuses_and_leaves_state "T12 AC8 -- prototype without gate 1 still refuses" "gate(s) 1 not approved" "$STATE_T12PROTO" "$EDM_STATE" archive T12PROTO

"$EDM_STATE" approve-gate T12PROTO 1 >/dev/null
jq '.current_phase = 2 | .phase_durations["2_phase"] = {started_at: "2026-01-01T00:00:00Z", completed_at: "2026-01-01T01:00:00Z"}' \
  "$STATE_T12PROTO" > "$STATE_T12PROTO.tmp" && mv "$STATE_T12PROTO.tmp" "$STATE_T12PROTO"
proto_out="$("$EDM_STATE" archive T12PROTO 2>&1)"
check "T12 AC8 -- prototype warning text preserved" \
  "[warn] no code-audit round in this phase graph (mode=prototype, lifecycle_mode=standard) -- skipping the convergence check" "$proto_out"
[[ -d "$TMP/SRD/.archived/T12PROTO" ]] \
  && pass "T12 AC8 -- prototype archives at its own terminal phase (2) once its checks pass" \
  || fail "T12 AC8 -- prototype archive did not relocate the directory"

# ---- AC9: audit-free lifecycle_modes record CONVERGENCE_NOT_REQUIRED, not silence ---------
echo
echo "T12 AC9 -- fast-track archives with CONVERGENCE_NOT_REQUIRED recorded"
"$EDM_STATE" init T12FAST >/dev/null
STATE_T12FAST="$TMP/SRD/T12FAST/.edm-state.json"
"$EDM_STATE" set-mode T12FAST lifecycle_mode fast-track >/dev/null
"$EDM_STATE" approve-gate T12FAST 1 >/dev/null
"$EDM_STATE" approve-gate T12FAST 2 >/dev/null
"$EDM_STATE" approve-gate T12FAST 3 >/dev/null
jq '.current_phase = 6 | .phase_durations["6_phase"] = {started_at: "2026-01-01T00:00:00Z", completed_at: "2026-01-01T01:00:00Z"}' \
  "$STATE_T12FAST" > "$STATE_T12FAST.tmp" && mv "$STATE_T12FAST.tmp" "$STATE_T12FAST"
fast_out="$("$EDM_STATE" archive T12FAST 2>&1)"
check "T12 AC9 -- fast-track archive message names CONVERGENCE_NOT_REQUIRED" \
  "CONVERGENCE_NOT_REQUIRED" "$fast_out"
exemption_hit="$(jq -e '.archive_exemptions[]? | select(. == "CONVERGENCE_NOT_REQUIRED")' "$TMP/SRD/.archived/T12FAST/.edm-state.json" 2>&1)"
[[ "$exemption_hit" == '"CONVERGENCE_NOT_REQUIRED"' ]] \
  && pass "T12 AC9 -- archive_exemptions records CONVERGENCE_NOT_REQUIRED (not silent)" \
  || fail "T12 AC9 -- archive_exemptions missing CONVERGENCE_NOT_REQUIRED (got: $exemption_hit)"

# ---- AC10 (negative): a missing state file is reported (warned), not silently permitted ---
echo
echo "T12 AC10 -- archive with deleted state file warns MISSING_STATE_FILE"
"$EDM_STATE" init T12MISSING >/dev/null
rm -f "$TMP/SRD/T12MISSING/.edm-state.json"
missing_out="$("$EDM_STATE" archive T12MISSING 2>&1)"
check "T12 AC10 -- archive with deleted state file warns MISSING_STATE_FILE" \
  "MISSING_STATE_FILE" "$missing_out"
[[ -d "$TMP/SRD/.archived/T12MISSING" ]] \
  && pass "T12 AC10 -- archive still proceeds (unchecked move) despite the missing state file" \
  || fail "T12 AC10 -- archive did not relocate the directory despite the warning-only path"

# ---- AC11: skipped_phases is respected -- mini-srd archives with its seeded skips ---------
echo
echo "T12 AC11 -- mini-srd archives with seeded skips (gate 3 not required)"
export EDM_MODE="mini-srd"
"$EDM_STATE" init T12MINI >/dev/null
unset EDM_MODE
STATE_T12MINI="$TMP/SRD/T12MINI/.edm-state.json"
# mini-srd seeds skipped_phases 2, 4, 5 at init (EDMV3-T07 AC4). gated_phase_for_gate maps
# gate 1->phase1 (not skipped), gate 2->phase3 (not skipped), gate 3->phase5 (skipped) --
# so only gates 1 and 2 are required.
"$EDM_STATE" approve-gate T12MINI 1 >/dev/null
"$EDM_STATE" approve-gate T12MINI 2 >/dev/null
jq '.current_phase = 6 | .phase_durations["6_phase"] = {started_at: "2026-01-01T00:00:00Z", completed_at: "2026-01-01T01:00:00Z"}' \
  "$STATE_T12MINI" > "$STATE_T12MINI.tmp" && mv "$STATE_T12MINI.tmp" "$STATE_T12MINI"
"$EDM_STATE" approve-gate T12MINI code-audit >/dev/null
"$EDM_STATE" archive T12MINI >/dev/null \
  && pass "T12 AC11 -- mini-srd archives with seeded skips (gate 3 not required)" \
  || fail "T12 AC11 -- mini-srd archive refused despite seeded skips"

# ---- AC12 (negative, no override flags): --force / --accept-partials are unknown args -----
echo
echo "T12 AC12 -- archive --force / --accept-partials are unknown-argument errors"
check_fails "T12 AC12 -- archive --force is an unknown argument" \
  "usage: edm-state archive" \
  "$EDM_STATE" archive T12GATE --force
check_fails "T12 AC12 -- archive --accept-partials is an unknown argument" \
  "usage: edm-state archive" \
  "$EDM_STATE" archive T12GATE --accept-partials

# ---- Regression (batch requirement): the three-command bypass fails at both steps ---------
echo
echo "T12 REGRESSION -- three-command bypass (edm-init -> set converged -> archive) fails at step 2 and step 3"
"$EDM_STATE" init T12BYPASS >/dev/null
STATE_T12BYPASS="$TMP/SRD/T12BYPASS/.edm-state.json"
# Step 2: attempt the bypass via `set` -- must fail (EDMV3-T09 AC1).
check_refuses_and_leaves_state "T12 REGRESSION -- step 2 (set code_audit_converged true) fails" "edm-state approve-gate <PREFIX> code-audit" "$STATE_T12BYPASS" "$EDM_STATE" set T12BYPASS code_audit_converged true

# Variant: hand-edit the state file directly (bypassing `set` entirely) to flip the boolean,
# then attempt step 3 (archive) at phase 0 -- must still be refused, on gate grounds (T12
# AC1), well before convergence is ever consulted.
jq '.code_audit_converged = true' "$STATE_T12BYPASS" > "$STATE_T12BYPASS.tmp" && mv "$STATE_T12BYPASS.tmp" "$STATE_T12BYPASS"
check_refuses_and_leaves_state "T12 REGRESSION -- hand-edited converged=true at phase 0 is still refused (gate grounds)" "gate(s) 1, 2, 3 not approved" "$STATE_T12BYPASS" "$EDM_STATE" archive T12BYPASS
[[ -d "$TMP/SRD/T12BYPASS" ]] \
  && pass "T12 REGRESSION -- three-command bypass fails at both step 2 and step 3; directory never moved" \
  || fail "T12 REGRESSION -- initiative directory was archived despite the bypass"

# =================================================================================
# EDMV3-T16: the three-command bypass becomes a must-fail smoke suite
# =================================================================================
# This block is tests-only (T16 Out of Scope: no production-code change -- every refusal it
# asserts is implemented by EDMV3-T09 through EDMV3-T13, already covered individually above).
# It adds the ticket's own literal reproduction (--product/--description, edm-init by bare
# name, per AC8) rather than reusing the T12 REGRESSION fixture above, which predates T16 and
# uses the flat "$EDM_STATE" init / shared-$TMP style T16 AC8 supersedes for new cases.
# Every case below uses with_scratch_repo / check_fails / check_state_unchanged (EDMV3-T19) --
# no hand-rolled `mktemp -d` in this block. 13 "must-fail:"-labeled cases are added across
# AC1/AC2 (3), AC4 (9) and AC5 (1); AC6 adds two mode-archival positives; AC7's happy path
# runs last per the ticket's ordering note (a bug that makes everything pass must be caught by
# the must-fail count, not masked by a green happy path).
echo
echo "T16 -- three-command bypass matrix (must-fail cases), mode cases, and the happy path"

# ---- AC1/AC2/AC3: the reviewer's exact reproduction, product-scoped -----------------------
echo
echo "T16 AC1/AC2/AC3 -- the three-command bypass: edm-init -> set converged -> archive"
t16_bypass_case() {
  edm-init --product demo --description bypass-test TESTX >/dev/null
  local init_dir state_file
  init_dir="$(edm-state resolve-dir TESTX)"
  state_file="${init_dir}/.edm-state.json"

  # Command 2: edm-state set TESTX code_audit_converged true -- must fail naming approve-gate.
  check_refuses_and_leaves_state "must-fail: T16 AC1 -- bypass command 2 (set code_audit_converged true) refused" "approve-gate" "$state_file" edm-state set TESTX code_audit_converged true

  # Command 3, first attempt: hand-edit the state file directly (bypassing `set` entirely) to
  # force the flag, then archive at phase 0 -- refused on gate grounds, naming the missing gates.
  jq '.code_audit_converged = true' "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
  check_refuses_and_leaves_state "must-fail: T16 AC2 -- bypass command 3 refused after hand-edit (missing gates)" "gate(s) 1, 2, 3 not approved" "$state_file" edm-state archive TESTX

  # Command 3, second attempt: approve every gate the bypass forgot -- still refused, this time
  # naming the wrong current_phase, proving the gate check is not the only thing in the way.
  edm-state approve-gate TESTX 1 >/dev/null
  edm-state approve-gate TESTX 2 >/dev/null
  edm-state approve-gate TESTX 3 >/dev/null
  check_fails "must-fail: T16 AC2 -- bypass command 3 still refused once gates are approved (wrong current_phase)" \
    "current_phase (0) has not reached the terminal phase (6)" \
    edm-state archive TESTX

  # AC3: nothing moved -- the initiative directory still exists at its original path.
  [[ -d "$init_dir" ]] \
    && pass "T16 AC3 -- initiative directory unmoved after both refusals" \
    || fail "T16 AC3 -- initiative directory missing after refusals (was it archived despite the bypass?)"
}
with_scratch_repo t16_bypass_case

# ---- AC4: must-fail matrix -----------------------------------------------------------------
echo
echo "T16 AC4 -- must-fail matrix: phase-complete/archive/set/phase-start refusals"
t16_matrix_case() {
  # 1. phase-complete with the artifact absent (phase 1, no planning.md).
  edm-init --product demo --description mx1 MX1 >/dev/null
  edm-state phase-start MX1 1 >/dev/null
  local mx1_dir; mx1_dir="$(edm-state resolve-dir MX1)"
  check_refuses_and_leaves_state "must-fail: T16 AC4 -- phase-complete refuses when the phase artifact is absent" "phase 1 artifact missing or empty" "${mx1_dir}/.edm-state.json" edm-state phase-complete MX1 1

  # 2. archive with gates 1 and 2 approved but not 3.
  edm-init --product demo --description mx2 MX2 >/dev/null
  edm-state approve-gate MX2 1 >/dev/null
  edm-state approve-gate MX2 2 >/dev/null
  check_fails "must-fail: T16 AC4 -- archive with gates 1 and 2 but not 3 refuses naming gate 3" \
    "gate(s) 3 not approved" \
    edm-state archive MX2

  # 3. archive at current_phase == 5.
  edm-init --product demo --description mx3 MX3 >/dev/null
  edm-state approve-gate MX3 1 >/dev/null
  edm-state approve-gate MX3 2 >/dev/null
  edm-state approve-gate MX3 3 >/dev/null
  edm-state set MX3 current_phase 5 >/dev/null
  check_fails "must-fail: T16 AC4 -- archive at current_phase 5 refuses" \
    "current_phase (5) has not reached the terminal phase (6)" \
    edm-state archive MX3

  # 4. set with an unknown key.
  edm-init --product demo --description mx4 MX4 >/dev/null
  local mx4_dir; mx4_dir="$(edm-state resolve-dir MX4)"
  check_refuses_and_leaves_state "must-fail: T16 AC4 -- set with an unknown key refuses" "unknown key 'totally_bogus_key'" "${mx4_dir}/.edm-state.json" edm-state set MX4 totally_bogus_key 1

  # 5-7. set on each of the three gate-bearing fields.
  check_refuses_and_leaves_state "must-fail: T16 AC4 -- set code_audit_converged refuses (gate-bearing field 1/3)" "approve-gate <PREFIX> code-audit" "${mx4_dir}/.edm-state.json" edm-state set MX4 code_audit_converged true
  check_refuses_and_leaves_state "must-fail: T16 AC4 -- set compliance_gate_approved refuses (gate-bearing field 2/3)" "approve-gate <PREFIX> 3.5" "${mx4_dir}/.edm-state.json" edm-state set MX4 compliance_gate_approved true
  check_refuses_and_leaves_state "must-fail: T16 AC4 -- set gates_approved refuses (gate-bearing field 3/3)" "approve-gate <PREFIX> <gate-num>" "${mx4_dir}/.edm-state.json" edm-state set MX4 gates_approved true

  # 8. set schema_version.
  check_refuses_and_leaves_state "must-fail: T16 AC4 -- set schema_version refuses naming migrate-schema" "migrate-schema <PREFIX>" "${mx4_dir}/.edm-state.json" edm-state set MX4 schema_version 2

  # 9. phase-start into a phase whose prerequisite gate is unapproved.
  edm-init --product demo --description mx5 MX5 >/dev/null
  local mx5_dir; mx5_dir="$(edm-state resolve-dir MX5)"
  check_refuses_and_leaves_state "must-fail: T16 AC4 -- phase-start refuses into a phase whose prerequisite gate is unapproved" "Gate 1 has not been approved" "${mx5_dir}/.edm-state.json" edm-state phase-start MX5 2
}
with_scratch_repo t16_matrix_case

# ---- AC5: flat-layout case, the second hole (no --product) --------------------------------
echo
echo "T16 AC5 -- flat-layout archive refused (converged=false, no product_name)"
t16_flat_case() {
  edm-init FLATX >/dev/null   # no --product/--description -> flat SRD/FLATX/ layout
  local flat_dir flat_state product_val
  flat_dir="$(edm-state resolve-dir FLATX)"
  flat_state="${flat_dir}/.edm-state.json"
  product_val="$(edm-state get FLATX | jq -r '.product_name')"
  [[ -z "$product_val" ]] \
    && pass "T16 AC5 -- fixture is genuinely flat-layout (product_name empty)" \
    || fail "T16 AC5 -- fixture unexpectedly has product_name='$product_val'"

  edm-state approve-gate FLATX 1 >/dev/null
  edm-state approve-gate FLATX 2 >/dev/null
  edm-state approve-gate FLATX 3 >/dev/null
  jq '.current_phase = 6 | .phase_durations["6_phase"] = {started_at: "2026-01-01T00:00:00Z", completed_at: "2026-01-01T01:00:00Z"}' \
    "$flat_state" > "${flat_state}.tmp" && mv "${flat_state}.tmp" "$flat_state"
  check_fails "must-fail: T16 AC5 -- flat-layout archive refused (converged=false, no product_name)" \
    "approve-gate FLATX code-audit" \
    edm-state archive FLATX
}
with_scratch_repo t16_flat_case

# ---- AC6: mode cases -- fast-track and mini-srd each archive with their own skips ----------
echo
echo "T16 AC6 -- mode cases: fast-track and mini-srd each archive with their seeded/recorded skips"
t16_fasttrack_case() {
  edm-init --product demo --description ft FASTX >/dev/null
  edm-state set-mode FASTX lifecycle_mode fast-track >/dev/null
  # Fast-track's sub-flow (orchestrator/SKILL.md) records all four skips explicitly --
  # skipped_phases is NOT auto-seeded for lifecycle_mode (only `mode` is, EDMV3-T07 AC4).
  edm-state skip-phase FASTX 1 "fast-track: planning skipped -- tickets from analysis doc" >/dev/null
  edm-state skip-phase FASTX 2 "fast-track: SRD skipped -- tickets from analysis doc" >/dev/null
  edm-state skip-phase FASTX 3 "fast-track: SRD audit skipped" >/dev/null
  edm-state skip-phase FASTX 5 "fast-track: ticket audit skipped" >/dev/null
  local skipped_count
  skipped_count="$(edm-state get FASTX | jq '.skipped_phases | length')"
  [[ "$skipped_count" -eq 4 ]] \
    && pass "T16 AC6 -- fast-track records all four skipped phases the sub-flow prescribes" \
    || fail "T16 AC6 -- fast-track skipped_phases length = $skipped_count, expected 4"

  edm-state approve-gate FASTX 3 >/dev/null   # the single ticket-review gate the sub-flow names
  local fastx_state; fastx_state="$(edm-state resolve-dir FASTX)/.edm-state.json"
  jq '.current_phase = 6 | .phase_durations["6_phase"] = {started_at: "2026-01-01T00:00:00Z", completed_at: "2026-01-01T01:00:00Z"}' \
    "$fastx_state" > "${fastx_state}.tmp" && mv "${fastx_state}.tmp" "$fastx_state"
  edm-state archive FASTX >/dev/null \
    && pass "T16 AC6 -- fast-track archives successfully with its recorded skips" \
    || fail "T16 AC6 -- fast-track archive was refused despite the recorded skips"
}
with_scratch_repo t16_fasttrack_case

t16_minisrd_case() {
  edm-init --product demo --description mini MINIX --mode mini-srd >/dev/null
  local skipped_count
  skipped_count="$(edm-state get MINIX | jq '.skipped_phases | length')"
  [[ "$skipped_count" -eq 3 ]] \
    && pass "T16 AC6 -- mini-srd seeds skipped_phases (2, 4, 5) automatically at edm-init" \
    || fail "T16 AC6 -- mini-srd skipped_phases length = $skipped_count, expected 3"

  edm-state approve-gate MINIX 1 >/dev/null
  edm-state approve-gate MINIX 2 >/dev/null   # gate 3 (phase 5) is exempt: its origin phase is skipped
  local minix_state; minix_state="$(edm-state resolve-dir MINIX)/.edm-state.json"
  jq '.current_phase = 6 | .phase_durations["6_phase"] = {started_at: "2026-01-01T00:00:00Z", completed_at: "2026-01-01T01:00:00Z"}' \
    "$minix_state" > "${minix_state}.tmp" && mv "${minix_state}.tmp" "$minix_state"
  edm-state approve-gate MINIX code-audit >/dev/null
  edm-state archive MINIX >/dev/null \
    && pass "T16 AC6 -- mini-srd archives successfully with only gates 1 and 2 approved" \
    || fail "T16 AC6 -- mini-srd archive was refused despite the seeded skips"
}
with_scratch_repo t16_minisrd_case

# ---- AC7: happy path, run last -- proves refusal is targeted, not blanket -----------------
echo
echo "T16 AC7 -- happy path: a fully compliant standard-lifecycle initiative archives"
t16_happy_case() {
  edm-init --product demo --description happy HAPX >/dev/null
  edm-state approve-gate HAPX 1 >/dev/null
  edm-state approve-gate HAPX 2 >/dev/null
  edm-state approve-gate HAPX 3 >/dev/null
  local hapx_dir hapx_state
  hapx_dir="$(edm-state resolve-dir HAPX)"
  hapx_state="${hapx_dir}/.edm-state.json"
  jq '.current_phase = 6 | .phase_durations["6_phase"] = {started_at: "2026-01-01T00:00:00Z", completed_at: "2026-01-01T01:00:00Z"}' \
    "$hapx_state" > "${hapx_state}.tmp" && mv "${hapx_state}.tmp" "$hapx_state"
  edm-state approve-gate HAPX code-audit >/dev/null
  edm-state archive HAPX >/dev/null \
    && pass "T16 AC7 -- fully compliant standard-lifecycle initiative archives successfully" \
    || fail "T16 AC7 -- compliant initiative was refused"

  local srd_root product_dir_name init_dir_name archived_path
  init_dir_name="$(basename "$hapx_dir")"
  product_dir_name="$(basename "$(dirname "$hapx_dir")")"
  srd_root="$(dirname "$(dirname "$hapx_dir")")"
  archived_path="${srd_root}/.archived/${product_dir_name}/${init_dir_name}"
  [[ -d "$archived_path" ]] \
    && pass "T16 AC7 -- archived to the expected product-scoped destination" \
    || fail "T16 AC7 -- archived directory not found at expected destination ($archived_path)"
}
with_scratch_repo t16_happy_case

# EDMV3-T18 AC11: the bypass matrix's unclosed-PARTIAL case is filled in in the dedicated
# EDMV3-T18 section below ("T18 AC11 -- bypass matrix: archive with an unclosed PARTIAL"),
# once the PARTIAL closure representation and the archive-side closure check it depends on
# (EDMV3-T32, EDMV3-T18 AC1e) exist.
# EDMV3-T16 end
# EDMV3-T14: schema_version three-valued degradation wiring, C-4 field-stability
# contract, legacy read-compat assertions.
# =================================================================================
echo
echo "T14 -- three-valued degradation, C-4 field stability, legacy read-compat"

# ---- AC1/AC2 (class 1, absent schema_version): every new check (T11 artifact, T11 PARTIAL,
# T12 archive, T13 phase-start) warns and proceeds on a legacy file, and each warning is
# prefixed "[warn] legacy initiative" and names the check that was skipped. -----------------
echo
echo "T14 AC1/AC2 -- every new check degrades to warn-and-proceed on a legacy (no schema_version) file"
mkdir -p "$TMP/SRD/T14LEGACY"
STATE_T14LEGACY="$TMP/SRD/T14LEGACY/.edm-state.json"
# mode present, schema_version absent -- the real EDMV2 shape (a genuine pre-EDMV3 initiative
# already carries mode="standard"; schema_version is what's actually missing).
jq -n '{
  prefix: "T14LEGACY",
  mode: "standard",
  current_phase: 6,
  gates_approved: [],
  phase_durations: {"6_phase": {"started_at": "2020-01-01T00:00:00Z"}},
  partial_verdict_map: {"T14LEGACY-T01": {verdict: "PARTIAL", note: "open", recorded_at: "2020-01-01T00:00:00Z"}},
  code_audit_converged: true,
  last_updated: "2020-01-01T00:00:00Z"
}' > "$STATE_T14LEGACY"

# check 1: phase-complete artifact verification (T11) -- no planning.md on disk, must not die.
t14leg_pc1_ec=0
t14leg_pc1_out="$("$EDM_STATE" phase-complete T14LEGACY 1 2>&1)" || t14leg_pc1_ec=$?
check "T14 AC2 -- phase-complete artifact check names 'phase 1' when it warns" \
  "[warn] legacy initiative" "$t14leg_pc1_out"
check "T14 AC2 -- phase-complete artifact check names the skipped phase" \
  "phase 1" "$t14leg_pc1_out"
[[ $t14leg_pc1_ec -eq 0 ]] && pass "T14 AC1 -- phase-complete artifact check (T11) warns and proceeds rather than hard-failing" \
  || fail "T14 AC1 -- phase-complete artifact check hard-failed on a legacy file (exit $t14leg_pc1_ec)"

# check 2: phase-complete open-PARTIAL check -- G2/CA-333 (round 6) made this check
# unconditional (moved out of the legacy/current split entirely, matching `edm-state
# validate`'s OPEN_PARTIALS anomaly, which is deliberately not schema-gated because
# partial_verdict_map predates schema_version). A truly legacy (no schema_version) file with a
# genuine open PARTIAL now refuses here too, not just a schema_version:1 file (T14MIDDLE
# below) -- there is no longer a "warns and proceeds despite an unresolved PARTIAL" path at
# any schema_version.
t14leg_pc6_ec=0
t14leg_pc6_out="$("$EDM_STATE" phase-complete T14LEGACY 6 2>&1)" || t14leg_pc6_ec=$?
check "T14 AC2/G2/CA-333 -- phase-complete PARTIAL refusal names 'phase 6'" \
  "phase 6" "$t14leg_pc6_out"
[[ $t14leg_pc6_ec -ne 0 ]] && pass "T14 AC2/G2/CA-333 -- phase-complete now refuses on an open PARTIAL even for a truly legacy (no schema_version) file" \
  || fail "T14 AC2/G2/CA-333 -- phase-complete succeeded despite an open PARTIAL on a legacy file (exit $t14leg_pc6_ec)"

# check 3: archive -- the wave-A lifecycle checks (gates/phase/completed_at) still warn and
# proceed rather than hard-failing (unchanged), but G2/CA-333 made the separate PARTIAL-closure
# check (AC1e) unconditional too, so this SAME fixture -- which happens to carry a genuine open
# PARTIAL -- now refuses on that check instead of completing the archive. A dedicated
# no-open-PARTIAL fixture (T14LEGACY2 below) isolates the original wave-A-only claim.
t14leg_arch_ec=0
t14leg_arch_out="$("$EDM_STATE" archive T14LEGACY 2>&1)" || t14leg_arch_ec=$?
check "T14 AC2 -- archive names the skipped check class when it warns" \
  "skipping wave-A lifecycle checks" "$t14leg_arch_out"
check "T14 AC2/G2/CA-333 -- archive still refuses on the open PARTIAL even for a legacy file" \
  "unclosed or FAIL-closed PARTIAL verdict" "$t14leg_arch_out"
[[ $t14leg_arch_ec -ne 0 ]] && pass "T14 AC2/G2/CA-333 -- archive refuses this legacy fixture (open PARTIAL), even though its wave-A checks alone would have warned and proceeded" \
  || fail "T14 AC2/G2/CA-333 -- archive unexpectedly succeeded despite the open PARTIAL (exit $t14leg_arch_ec)"
[[ ! -d "$TMP/SRD/.archived/T14LEGACY" ]] \
  && pass "T14 AC2/G2/CA-333 -- the refused archive left T14LEGACY un-moved" \
  || fail "T14 AC2/G2/CA-333 -- T14LEGACY was archived despite the refusal"

# ---- Dedicated no-open-PARTIAL legacy fixture: isolates the ORIGINAL wave-A-only claim (T12)
# that missing gates/phase/completed_at degrade to warn-and-proceed on a truly legacy file,
# now that T14LEGACY above (which happens to carry an open PARTIAL) demonstrates a different,
# separately-enforced refusal instead. --------------------------------------------------------
mkdir -p "$TMP/SRD/T14LEGACY2"
STATE_T14LEGACY2="$TMP/SRD/T14LEGACY2/.edm-state.json"
jq -n '{
  prefix: "T14LEGACY2",
  mode: "standard",
  current_phase: 6,
  gates_approved: [],
  phase_durations: {"6_phase": {"started_at": "2020-01-01T00:00:00Z"}},
  partial_verdict_map: {},
  code_audit_converged: true,
  last_updated: "2020-01-01T00:00:00Z"
}' > "$STATE_T14LEGACY2"
t14leg2_arch_ec=0
t14leg2_arch_out="$("$EDM_STATE" archive T14LEGACY2 2>&1)" || t14leg2_arch_ec=$?
check "T14 AC1 -- archive names the skipped check class when it warns (no-open-PARTIAL legacy fixture)" \
  "skipping wave-A lifecycle checks" "$t14leg2_arch_out"
[[ $t14leg2_arch_ec -eq 0 ]] && pass "T14 AC1 -- archive lifecycle checks (T12) warn and proceed rather than hard-failing" \
  || fail "T14 AC1 -- archive hard-failed on a legacy file with no open PARTIAL (exit $t14leg2_arch_ec)"
[[ -d "$TMP/SRD/.archived/T14LEGACY2" ]] \
  && pass "T14 AC1 -- legacy initiative archives successfully despite missing gates/phase/completed_at" \
  || fail "T14 AC1 -- legacy initiative was not archived"

# check 4: phase-start kernel gate check (T13) -- mode present, schema_version absent (the
# real EDMV2 shape), must not die. phase-start's C-4 signal is schema_version (via the shared
# schema_at_least() helper), same as every other wave-A check -- exercised here as one of the
# "four" this AC counts, not re-implemented.
mkdir -p "$TMP/SRD/T14LEGSTART"
STATE_T14LEGSTART="$TMP/SRD/T14LEGSTART/.edm-state.json"
jq -n '{prefix: "T14LEGSTART", mode: "standard", current_phase: 1, gates_approved: [], phase_durations: {}, last_updated: "2020-01-01T00:00:00Z"}' \
  > "$STATE_T14LEGSTART"
t14leg_ps_ec=0
t14leg_ps_out="$("$EDM_STATE" phase-start T14LEGSTART 2 2>&1)" || t14leg_ps_ec=$?
check "T14 AC2 -- phase-start names the skipped check when it warns" \
  "skipping kernel gate enforcement" "$t14leg_ps_out"
[[ $t14leg_ps_ec -eq 0 ]] && pass "T14 AC1 -- phase-start kernel gate check (T13) warns and proceeds rather than hard-failing" \
  || fail "T14 AC1 -- phase-start hard-failed on a legacy file (exit $t14leg_ps_ec)"

# ---- AC3 (D4 grandfathering, positive): code_audit_converged=true set under the old flow
# archives without being asked to re-approve through the new gate. Uses T14LEGACY2 (no open
# PARTIAL), not T14LEGACY, since T14LEGACY's archive attempt above now refuses on the
# separately-enforced G2/CA-333 PARTIAL check before ever reaching this far. ---------------
echo
echo "T14 AC3 -- pre-set converged flag (old flow) archives without re-approval through the new gate"
check_absent "T14 AC3 -- archive does not ask to re-approve the code-audit gate for a legacy converged=true file" \
  "approve-gate T14LEGACY2 code-audit" "$t14leg2_arch_out"

# ---- AC4 (end-to-end legacy fixture): copy the real v2.0 archived state file into a scratch
# initiative and run get/validate/phase-complete/archive end to end. ----------------------
echo
echo "T14 AC4 -- real archived EDMV2 state file, copied into a scratch initiative, runs end to end"
REAL_EDMV2_FIXTURE="${REPO_ROOT}/SRD/.archived/EDMV2/.edm-state.json"
[[ -f "$REAL_EDMV2_FIXTURE" ]] \
  && pass "T14 AC4 -- source fixture SRD/.archived/EDMV2/.edm-state.json exists" \
  || fail "T14 AC4 -- source fixture not found at $REAL_EDMV2_FIXTURE"
mkdir -p "$TMP/SRD/T14EDMV2"
STATE_T14EDMV2="$TMP/SRD/T14EDMV2/.edm-state.json"
cp "$REAL_EDMV2_FIXTURE" "$STATE_T14EDMV2"
jq '.prefix = "T14EDMV2"' "$STATE_T14EDMV2" > "$STATE_T14EDMV2.tmp" && mv "$STATE_T14EDMV2.tmp" "$STATE_T14EDMV2"

t14edmv2_get_ec=0
t14edmv2_get_out="$("$EDM_STATE" get T14EDMV2 2>&1)" || t14edmv2_get_ec=$?
[[ $t14edmv2_get_ec -eq 0 ]] && pass "T14 AC4 -- edm-state get reads the copied EDMV2 fixture without error" \
  || fail "T14 AC4 -- edm-state get errored on the copied EDMV2 fixture (exit $t14edmv2_get_ec)"

t14edmv2_validate_ec=0
t14edmv2_validate_out="$("$EDM_STATE" validate T14EDMV2 2>&1)" || t14edmv2_validate_ec=$?
check "T14 AC4 -- validate flags the missing schema_version informationally" \
  "SCHEMA_VERSION_MISSING" "$t14edmv2_validate_out"
[[ $t14edmv2_validate_ec -eq 0 ]] && pass "T14 AC4 -- validate exits 0 (informational, not blocking)" \
  || fail "T14 AC4 -- validate exited $t14edmv2_validate_ec, expected 0"

t14edmv2_pc_ec=0
t14edmv2_pc_out="$("$EDM_STATE" phase-complete T14EDMV2 6 2>&1)" || t14edmv2_pc_ec=$?
check "T14 AC4 -- phase-complete warns and proceeds against the real fixture" \
  "[warn] legacy initiative" "$t14edmv2_pc_out"
[[ $t14edmv2_pc_ec -eq 0 ]] && pass "T14 AC4 -- phase-complete succeeds against the real fixture (schema_version absent, mode present)" \
  || fail "T14 AC4 -- phase-complete hard-failed against the real fixture (exit $t14edmv2_pc_ec)"

t14edmv2_arch_ec=0
t14edmv2_arch_out="$("$EDM_STATE" archive T14EDMV2 2>&1)" || t14edmv2_arch_ec=$?
check "T14 AC4 -- archive warns and proceeds against the real fixture" \
  "[warn] legacy initiative" "$t14edmv2_arch_out"
[[ $t14edmv2_arch_ec -eq 0 ]] && pass "T14 AC4 -- archive succeeds end-to-end against the real fixture" \
  || fail "T14 AC4 -- archive hard-failed against the real fixture (exit $t14edmv2_arch_ec)"
[[ -d "$TMP/SRD/.archived/T14EDMV2" ]] \
  && pass "T14 AC4 -- real fixture's scratch copy archived successfully end to end" \
  || fail "T14 AC4 -- scratch copy of the real fixture was not archived"

# ---- AC5 (class 3, negative): a current-schema_version initiative is fully enforced -- no
# "[warn] legacy" line appears anywhere. ---------------------------------------------------
echo
echo "T14 AC5 -- current-version initiative is fully enforced (no legacy warn line anywhere)"
"$EDM_STATE" init T14CURRENT >/dev/null
STATE_T14CURRENT="$TMP/SRD/T14CURRENT/.edm-state.json"
t14cur_sv="$(jq -r '.schema_version' "$STATE_T14CURRENT")"
[[ "$t14cur_sv" == "1" ]] && pass "T14 AC5 -- fresh initiative is created at schema_version 1 (current wave-A version)" \
  || fail "T14 AC5 -- fresh initiative schema_version = '$t14cur_sv', expected 1"
t14cur_pc_out="$("$EDM_STATE" phase-complete T14CURRENT 1 2>&1 || true)"
check_absent "T14 AC5 -- phase-complete on a current-version initiative shows no legacy warn line" \
  "[warn] legacy" "$t14cur_pc_out"
t14cur_arch_out="$("$EDM_STATE" archive T14CURRENT 2>&1 || true)"
check_absent "T14 AC5 -- archive refusal on a current-version initiative shows no legacy warn line" \
  "[warn] legacy" "$t14cur_arch_out"

# ---- AC6 (historical middle class -- G2/CA-333, round 6, removed this specific degradation):
# schema_version 1 used to warn-and-proceed through the phase-6 open-PARTIAL check (a >=2-gated
# check) while fully enforcing every >=1 check. G2/CA-333 found that gate environmentally
# unreachable: `_cmd_init_render` writes the literal schema_version 1 for every initiative the
# current plugin creates and nothing auto-migrates it, so this refusal never fired in the
# shipped default -- the same defect class CA-182 fixed one function over
# (cmd_approve_gate's code-audit precheck). The check now runs unconditionally, mirroring
# CA-182's own remediation, so schema_version 1 is fully enforced here too, just like every
# >=1 check already was. ------
echo
echo "T14 AC6 -- schema_version 1 fully enforces the >=1 gate-check AND the phase-6 open-PARTIAL check (G2/CA-333: no longer degraded)"
t14cur_ps_out="$("$EDM_STATE" phase-start T14CURRENT 2 2>&1 || true)"
check_absent "T14 AC6 -- schema_version 1 fully enforces the >=1 gate-check (no legacy warn)" \
  "[warn] legacy" "$t14cur_ps_out"
mkdir -p "$TMP/SRD/T14MIDDLE"
STATE_T14MIDDLE="$TMP/SRD/T14MIDDLE/.edm-state.json"
jq -n '{
  prefix: "T14MIDDLE", schema_version: 1, current_phase: 6, gates_approved: [],
  phase_durations: {"6_phase": {started_at: "2020-01-01T00:00:00Z"}},
  partial_verdict_map: {"T14MIDDLE-T01": {verdict: "PARTIAL", note: "open", recorded_at: "2020-01-01T00:00:00Z"}},
  last_updated: "2020-01-01T00:00:00Z"
}' > "$STATE_T14MIDDLE"
# schema_version 1 satisfies the >=1 artifact check in full (EDMV3-T09 AC10), so the phase-6
# artifact must actually be present here -- this fixture is exercising the phase-6 open-PARTIAL
# check specifically, not the >=1 artifact check.
mkdir -p "$TMP/SRD/T14MIDDLE/qc"
echo "# QC summary" > "$TMP/SRD/T14MIDDLE/qc/qc-summary.md"
t14mid_ec=0
t14mid_out="$("$EDM_STATE" phase-complete T14MIDDLE 6 2>&1)" || t14mid_ec=$?
check "T14 AC6/G2/CA-333 -- schema_version 1 refuses phase-complete 6 on the open PARTIAL, naming verify-runtime" \
  "unresolved PARTIAL verdict" "$t14mid_out"
check_absent "T14 AC6/G2/CA-333 -- the retired 'schema_version 1 < 2' degradation line no longer appears" \
  "schema_version 1 < 2" "$t14mid_out"
[[ $t14mid_ec -ne 0 ]] && pass "T14 AC6/G2/CA-333 -- schema_version 1 now refuses on an open PARTIAL (the degradation that made this environmentally unreachable is gone)" \
  || fail "T14 AC6/G2/CA-333 -- schema_version 1 phase-complete 6 unexpectedly succeeded despite an open PARTIAL (exit $t14mid_ec)"

# ---- AC7 (additive fields, no null-propagation on legacy reads): jq reads across the real
# legacy fixture never propagate null into a field a caller treats as present. -------------
echo
echo "T14 AC7 -- jq reads on the legacy fixture produce no nulls for fields C-4 defaults cover"
# T14EDMV2's scratch copy was already archived by the AC4 block above (git_aware_mv falls
# back to plain mv outside a git worktree, matching every other archive test in this suite).
t14nulls="$(jq -e '
  (.mode // "default-ok") as $mode |
  (.schema_version // "absent-ok") as $sv |
  (.skipped_phases // []) as $sp |
  (.audit_rounds.code // 0) as $ac |
  (.partial_verdict_map // {}) as $pvm |
  ($mode != null and $sv != null and $sp != null and $ac != null and $pvm != null)
' "$TMP/SRD/.archived/T14EDMV2/.edm-state.json" 2>&1)"
[[ "$t14nulls" == "true" ]] && pass "T14 AC7 -- every C-4-defaulted field reads non-null on the real legacy fixture" \
  || fail "T14 AC7 -- a jq read produced null on the legacy fixture (result: $t14nulls)"

# ---- AC8 (legacy artifact shapes readable): a markdown-only findings ledger, a
# partial_verdict_map in the pre-closure shape, and lifecycle_mode: "partial" all read
# without error. ----------------------------------------------------------------------------
echo
echo "T14 AC8 -- legacy artifact/state shapes read without error"

# shape 1: markdown-only findings ledger (no JSONL sibling).
"$EDM_STATE" init T14MDLEDGER >/dev/null
mkdir -p "$TMP/SRD/T14MDLEDGER/code-audit"
echo "# Findings Ledger (markdown-only, pre-JSONL shape)" > "$TMP/SRD/T14MDLEDGER/code-audit/findings-ledger.md"
t14mdledger_ec=0
t14mdledger_out="$("$EDM_STATE" get T14MDLEDGER 2>&1)" || t14mdledger_ec=$?
[[ $t14mdledger_ec -eq 0 ]] && pass "T14 AC8 -- markdown-only findings ledger: edm-state get reads without error" \
  || fail "T14 AC8 -- edm-state get errored with a markdown-only findings ledger present (exit $t14mdledger_ec)"

# shape 2: partial_verdict_map in the pre-closure shape (verdict/note/recorded_at, no
# closure/resolution field -- that shape does not exist until EDMV3-T28, wave B).
"$EDM_STATE" init T14PVMSHAPE >/dev/null
"$EDM_STATE" record-partial-verdict T14PVMSHAPE T14PVMSHAPE-T01 PARTIAL "pre-closure shape" >/dev/null
t14pvm_ec=0
t14pvm_out="$("$EDM_STATE" get T14PVMSHAPE 2>&1)" || t14pvm_ec=$?
[[ $t14pvm_ec -eq 0 ]] && pass "T14 AC8 -- pre-closure partial_verdict_map shape: edm-state get reads without error" \
  || fail "T14 AC8 -- edm-state get errored on the pre-closure partial_verdict_map shape (exit $t14pvm_ec)"
check "T14 AC8 -- pre-closure partial_verdict_map entry is present as recorded" \
  '"verdict": "PARTIAL"' "$t14pvm_out"

# shape 3: lifecycle_mode: "partial" state file. "partial" is a dead value removed from
# LIFECYCLE_MODE_ENUM_LIST by the delete-list epic (D12, EDMV3-T57..T60), so it can no longer
# be written via `set-mode` -- this simulates a pre-delete-list on-disk file by writing the
# dead value directly, matching every other C-4 legacy-shape fixture in this suite.
"$EDM_STATE" init T14LCPARTIAL >/dev/null
# A LEGACY file carrying the removed `partial` value cannot be produced by the current
# binary (set-mode refuses it, EDMV3-T59 / D12) -- plant it directly, which is what a
# pre-removal state file actually looks like on disk.
jq '.lifecycle_mode = "partial"' "$TMP/SRD/T14LCPARTIAL/.edm-state.json" > "$TMP/lcp.tmp" \
  && mv "$TMP/lcp.tmp" "$TMP/SRD/T14LCPARTIAL/.edm-state.json"
t14lcpartial_ec=0
t14lcpartial_out="$("$EDM_STATE" get T14LCPARTIAL 2>&1)" || t14lcpartial_ec=$?
[[ $t14lcpartial_ec -eq 0 ]] && pass "T14 AC8 -- lifecycle_mode: partial state file: edm-state get reads without error" \
  || fail "T14 AC8 -- edm-state get errored on a lifecycle_mode: partial state file (exit $t14lcpartial_ec)"
check "T14 AC8 -- lifecycle_mode: partial is recorded as set" \
  '"lifecycle_mode": "partial"' "$t14lcpartial_out"

# The anomaly half of the same C-4 contract (EDMV3-T59 AC3, "legacy lifecycle_mode partial
# reads and reports an anomaly"): reading the planted file is only half the behaviour -- the
# operator must also be TOLD the value is stale, or a legacy file silently keeps a removed
# enum value forever. `validate` emits it in the canonical four-field format
# (class/CODE/field/description, EDMV3-T05 AC2) at class `info`, so it is reported without
# flipping the exit code -- reading a pre-removal file is not a defect.
set +e
t14lcpartial_val_ec=0
t14lcpartial_val="$("$EDM_STATE" validate T14LCPARTIAL 2>&1)" || t14lcpartial_val_ec=$?
set -e
check "T14 AC8 / T59 AC3 -- LEGACY_LIFECYCLE_MODE anomaly present in canonical four-field format" \
  "info  LEGACY_LIFECYCLE_MODE  lifecycle_mode" "$t14lcpartial_val"
check "T14 AC8 / T59 AC3 -- the anomaly names the initiative and the removed value" \
  "T14LCPARTIAL carries the removed lifecycle_mode 'partial'" "$t14lcpartial_val"
check "T14 AC8 / T59 AC3 -- the anomaly states the value is read as 'standard'" \
  "(read as 'standard')" "$t14lcpartial_val"
check "T14 AC8 / T59 AC3 -- the anomaly names the command that clears it" \
  "set-mode T14LCPARTIAL lifecycle_mode standard" "$t14lcpartial_val"
[[ $t14lcpartial_val_ec -eq 0 ]] \
  && pass "T14 AC8 / T59 AC3 -- LEGACY_LIFECYCLE_MODE is class info (validate still exits 0, non-blocking)" \
  || fail "T14 AC8 / T59 AC3 -- validate exited $t14lcpartial_val_ec on a legacy lifecycle_mode file, expected 0 (info is non-blocking)"
# Negative half of the class claim: no line of this initiative's anomaly output is `blocking`,
# so the exit-0 above is genuinely "info only", not "a blocking line that failed to fire".
# Guarded with `|| true` -- a zero-match grep exits 1 and would abort the suite under
# `set -euo pipefail`.
t14lcpartial_blocking="$(printf '%s\n' "$t14lcpartial_val" | grep -c '^blocking ' || true)"
[[ "$t14lcpartial_blocking" -eq 0 ]] \
  && pass "T14 AC8 / T59 AC3 -- a legacy lifecycle_mode file raises no blocking anomaly" \
  || fail "T14 AC8 / T59 AC3 -- $t14lcpartial_blocking blocking anomaly line(s) fired on a legacy lifecycle_mode file"

# ---- AC9 (both layouts): flat and product-scoped layouts continue to resolve; migrate-path
# continues to work and is not a prerequisite for anything. --------------------------------
echo
echo "T14 AC9 -- flat layout resolves for a legacy (no schema_version) initiative"
t14leg_product="$(jq -r '.product_name // ""' "$STATE_T14LEGSTART")"
[[ -z "$t14leg_product" ]] && pass "T14 AC9 -- T14LEGSTART is flat-layout (no product_name)" \
  || fail "T14 AC9 -- T14LEGSTART unexpectedly has product_name='$t14leg_product'"
[[ -f "$TMP/SRD/T14LEGSTART/.edm-state.json" ]] \
  && pass "T14 AC9 -- flat-layout path SRD/T14LEGSTART/.edm-state.json resolves and is untouched by relocation" \
  || fail "T14 AC9 -- flat-layout state file missing at the expected path"
"$EDM_STATE" migrate-path --product demo --description t14 T14LEGSTART >/dev/null 2>&1 \
  && pass "T14 AC9 -- migrate-path continues to work on a legacy (no schema_version) initiative" \
  || fail "T14 AC9 -- migrate-path failed on a legacy initiative"
[[ -f "$TMP/SRD/demo/T14LEGSTART__t14/.edm-state.json" ]] \
  && pass "T14 AC9 -- product-scoped layout resolves after migrate-path" \
  || fail "T14 AC9 -- product-scoped path not found after migrate-path"

# ---- AC10 (bounded, negative): a non-archived initiative with no schema_version keeps
# raising SCHEMA_VERSION_MISSING on every validate call until migrated -- grandfathering
# never becomes a permanent exemption. ------------------------------------------------------
echo
echo "T14 AC10 -- SCHEMA_VERSION_MISSING persists on every validate call until migrated (not a permanent exemption)"
"$EDM_STATE" init T14BOUND >/dev/null
STATE_T14BOUND="$TMP/SRD/T14BOUND/.edm-state.json"
jq 'del(.schema_version)' "$STATE_T14BOUND" > "$STATE_T14BOUND.tmp" && mv "$STATE_T14BOUND.tmp" "$STATE_T14BOUND"
t14bound_out1="$("$EDM_STATE" validate T14BOUND 2>&1)"
check "T14 AC10 -- unmigrated non-archived initiative raises SCHEMA_VERSION_MISSING (call 1)" \
  "SCHEMA_VERSION_MISSING" "$t14bound_out1"
t14bound_out2="$("$EDM_STATE" validate T14BOUND 2>&1)"
check "T14 AC10 -- the anomaly persists on a second validate call (not a one-time notice)" \
  "SCHEMA_VERSION_MISSING" "$t14bound_out2"
echo yes | "$EDM_STATE" migrate-schema T14BOUND >/dev/null 2>&1
t14bound_out3="$("$EDM_STATE" validate T14BOUND 2>&1)"
check_absent "T14 AC10 -- once migrated, SCHEMA_VERSION_MISSING no longer fires (exemption is bounded, not open-ended)" \
  "SCHEMA_VERSION_MISSING" "$t14bound_out3"

# ---- AC11 (no archived initiative modified): nothing under SRD/.archived/ (the real
# project directory, not the scratch TMP tree) is modified by this initiative. --------------
echo
echo "T14 AC11 -- nothing under the real SRD/.archived/ is modified by this test run"
t14archived_status="$(cd "$REPO_ROOT" && git status --porcelain SRD/.archived/ 2>&1)"
[[ -z "$t14archived_status" ]] \
  && pass "T14 AC11 -- git status --porcelain SRD/.archived/ is empty (nothing modified)" \
  || fail "T14 AC11 -- SRD/.archived/ was modified: $t14archived_status"

# =================================================================================
# EDMV3-T59 AC2: the narrowed lifecycle_mode enum stays narrowed (D12)
# =================================================================================
# Companion to the T14 AC8 / T59 AC3 read-half above: that case proves a file already
# carrying the removed `partial` value still READS and reports an informational anomaly.
# This one proves the value can never be WRITTEN back in. Without it the enum is only
# pinned by a generic bad-value case (wave4a-smoke.sh's `badvalue`), which would keep
# passing if `partial` were quietly re-added to LIFECYCLE_MODE_ENUM_LIST -- exactly the
# re-widening this ticket removed it to prevent.
echo
echo "T59 AC2 -- set-mode lifecycle_mode partial refused, naming the three surviving values"
"$EDM_STATE" init T59ENUM >/dev/null
STATE_T59ENUM="$TMP/SRD/T59ENUM/.edm-state.json"
set +e
t59enum_ec=0
t59enum_out="$("$EDM_STATE" set-mode T59ENUM lifecycle_mode partial 2>&1)" || t59enum_ec=$?
set -e
[[ $t59enum_ec -ne 0 ]] \
  && pass "T59 AC2 -- set-mode lifecycle_mode partial exits non-zero" \
  || fail "T59 AC2 -- set-mode lifecycle_mode partial exited 0 (the removed value was accepted)"
check "T59 AC2 -- the refusal names the rejected value" \
  "invalid lifecycle_mode 'partial'" "$t59enum_out"
# The three surviving members, asserted individually rather than as one concatenated
# "standard|fast-track|fix-pack" literal, so a re-ordering of LIFECYCLE_MODE_ENUM_LIST does
# not read as a regression while a genuinely dropped member still does.
check "T59 AC2 -- the refusal names the surviving value 'standard'"   "standard"   "$t59enum_out"
check "T59 AC2 -- the refusal names the surviving value 'fast-track'" "fast-track" "$t59enum_out"
check "T59 AC2 -- the refusal names the surviving value 'fix-pack'"   "fix-pack"   "$t59enum_out"
check_absent "T59 AC2 -- the removed value is not offered back as a legal choice" \
  "expected: standard|fast-track|fix-pack|partial" "$t59enum_out"
# Byte-identity, not a field re-read: cmd_set_mode dies inside the enum guard BEFORE it
# reaches rmw_state, so nothing at all should be written -- not lifecycle_mode, and not the
# last_updated timestamp that every successful write bumps alongside it.
check_refuses_and_leaves_state "T59 AC2 -- set-mode lifecycle_mode partial refuses AND leaves state byte-identical" \
  "invalid lifecycle_mode 'partial'" "$STATE_T59ENUM" "$EDM_STATE" set-mode T59ENUM lifecycle_mode partial
# Positive control: the same subcommand on a surviving enum member DOES write, so the
# byte-identity assertion above is proving a refusal, not a broken/no-op code path.
"$EDM_STATE" set-mode T59ENUM lifecycle_mode fast-track >/dev/null
t59enum_live="$(jq -r '.lifecycle_mode' "$STATE_T59ENUM")"
[[ "$t59enum_live" == "fast-track" ]] \
  && pass "T59 AC2 -- positive control: a surviving enum member still writes (lifecycle_mode = fast-track)" \
  || fail "T59 AC2 -- positive control failed: lifecycle_mode = '$t59enum_live', expected fast-track"

# =================================================================================
# EDMV3-T61 AC6: a prefix argument cannot be used to traverse outside SRD_ROOT
# =================================================================================
# The ticket's own Verify line names `edm-state audit-converged '../../etc'` -- audit-converged
# is a wave-B subcommand (EDMV3-T18) that does not exist yet at this wave-A boundary (srd.md
# v1.2.0 CR4's wave split, the same one EDMV3-T61 AC3/AC5 document). The mechanism under test --
# state_file_for()'s character-class guard, which every PREFIX-taking command routes through
# before any path is constructed -- is wave-A and already covers every wave-A command; this case
# exercises it via `resolve-dir`, a wave-A read-only command that (like the future
# audit-converged) takes a bare PREFIX and returns a constructed path, so it is the closest
# available equivalent. G7/CA-002/CA-004 in wave5-smoke.sh already lock the same guard down for
# init/set/migrate-path; this case adds resolve-dir to that regression net.
echo
echo "T61 AC6 -- path-traversal prefix refused"
set +e
t61_trav_ec=0
t61_trav_out="$("$EDM_STATE" resolve-dir '../../etc' 2>&1)" || t61_trav_ec=$?
set -e
[[ $t61_trav_ec -ne 0 ]] && pass "T61 AC6 -- path-traversal prefix exits non-zero" \
  || fail "T61 AC6 -- path-traversal prefix exited 0 (expected non-zero)"
check "T61 AC6 -- path-traversal prefix reports a validation error" "invalid PREFIX" "$t61_trav_out"
[[ ! -e "$TMP/etc" ]] && pass "T61 AC6 -- path-traversal prefix wrote nothing outside SRD_ROOT" \
  || fail "T61 AC6 -- path-traversal prefix escaped SRD_ROOT"

# =================================================================================
# G14/CA-352 (round 6): state_file_for refuses rather than guesses when two product-scoped
# directories exist for the same PREFIX -- the previous behavior warned to stderr and silently
# returned matches[0] in glob order, which every automated caller (resolve-dir's own callers
# among them) discards, so two developers on one repo could have a mutator write to two
# different initiatives with no diagnostic reaching either of them.
# =================================================================================
echo
echo "G14/CA-352 -- state_file_for refuses when two product-scoped directories exist for one PREFIX"
g14_dup_case() {
  local dir_a dir_b out ec=0
  dir_a="$TMP/SRD/prod-a/G14DUP__foo"
  dir_b="$TMP/SRD/prod-b/G14DUP__bar"
  mkdir -p "$dir_a" "$dir_b"
  printf '{"schema_version":1,"current_phase":0}' > "${dir_a}/.edm-state.json"
  printf '{"schema_version":1,"current_phase":0}' > "${dir_b}/.edm-state.json"
  out="$("$EDM_STATE" resolve-dir G14DUP 2>&1)" || ec=$?
  [[ $ec -ne 0 ]] \
    && pass "G14/CA-352 -- resolve-dir refuses (non-zero exit) on a duplicated PREFIX across two product-scoped directories" \
    || fail "G14/CA-352 -- resolve-dir exited 0 on a duplicated PREFIX (silently picked one): $out"
  check "G14/CA-352 -- the refusal names the first candidate path" "${dir_a}/.edm-state.json" "$out"
  check "G14/CA-352 -- the refusal names the second candidate path" "${dir_b}/.edm-state.json" "$out"
  rm -rf "$dir_a" "$dir_b" "$TMP/SRD/prod-a" "$TMP/SRD/prod-b"
}
g14_dup_case

# =================================================================================
# EDMV3-T62: every exemption leaves an audit trail
# =================================================================================

# ---- AC1 (positive, rationale required): phase/rationale/skipped_at all recorded ----------
echo
echo "T62 AC1 -- skip-phase records phase, a non-empty rationale, and skipped_at"
"$EDM_STATE" init T62AC1 >/dev/null
"$EDM_STATE" skip-phase T62AC1 2 "mini-srd fuses planning and SRD" >/dev/null
t62ac1_ok="$("$EDM_STATE" get T62AC1 | jq -e '.skipped_phases[0] | has("phase") and (.rationale | length > 0) and has("skipped_at")' 2>/dev/null || echo false)"
[[ "$t62ac1_ok" == "true" ]] && pass "T62 AC1 -- skipped_phases[0] has phase, non-empty rationale, and skipped_at" \
  || fail "T62 AC1 -- skipped_phases[0] missing one of phase/rationale/skipped_at"

# ---- AC2 (negative, breaking change): an empty rationale is refused -----------------------
echo
echo "T62 AC2 -- skip-phase with an empty rationale is refused"
"$EDM_STATE" init T62AC2 >/dev/null
STATE_T62AC2="$TMP/SRD/T62AC2/.edm-state.json"
check_refuses_and_leaves_state "T62 AC2 -- skip-phase with an empty rationale is refused" "empty rationale" "$STATE_T62AC2" "$EDM_STATE" skip-phase T62AC2 2 ""

echo
echo "T62 AC2 -- CHANGELOG.md documents the breaking change"
T62_CHANGELOG="${PLUGIN_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}/CHANGELOG.md"
check "T62 AC2 -- CHANGELOG names the skip-phase empty-rationale refusal" \
  "skip-phase refusing an empty rationale" "$(cat "$T62_CHANGELOG" 2>/dev/null || true)"

# ---- AC3 (C-4, pre-existing empty rationales are read and surfaced) -----------------------
echo
echo "T62 AC3 -- legacy empty rationale reads and reports an informational anomaly"
"$EDM_STATE" init T62AC3 >/dev/null
STATE_T62AC3="$TMP/SRD/T62AC3/.edm-state.json"
jq '.skipped_phases = [{phase: 3, rationale: "", skipped_at: "2026-01-01T00:00:00Z"}]' "$STATE_T62AC3" \
  > "$STATE_T62AC3.tmp" && mv "$STATE_T62AC3.tmp" "$STATE_T62AC3"
t62ac3_get_ec=0
"$EDM_STATE" get T62AC3 >/dev/null 2>&1 || t62ac3_get_ec=$?
[[ $t62ac3_get_ec -eq 0 ]] && pass "T62 AC3 -- legacy empty-rationale entry reads without error" \
  || fail "T62 AC3 -- edm-state get errored on a legacy empty-rationale entry"
t62ac3_validate_ec=0
t62ac3_validate_out="$("$EDM_STATE" validate T62AC3 2>&1)" || t62ac3_validate_ec=$?
check "T62 AC3 -- validate reports the canonical four-field EMPTY_SKIP_RATIONALE line" \
  "info  EMPTY_SKIP_RATIONALE  skipped_phases" "$t62ac3_validate_out"
check "T62 AC3 -- the anomaly names the phase and the initiative" "phase 3 of T62AC3" "$t62ac3_validate_out"
[[ $t62ac3_validate_ec -eq 0 ]] && pass "T62 AC3 -- validate exits 0 (info class never blocks)" \
  || fail "T62 AC3 -- validate exited ${t62ac3_validate_ec}, expected 0 for an info-only anomaly"

# ---- AC4 (seeded entries satisfy the same rule): mode-seeded skips carry a non-empty
# rationale naming the mode, same as a manual skip-phase call. ------------------------------
echo
echo "T62 AC4 -- mode-seeded skipped_phases entries carry a non-empty rationale"
export EDM_MODE="mini-srd"
"$EDM_STATE" init T62AC4 >/dev/null
unset EDM_MODE
t62ac4_ok="$("$EDM_STATE" get T62AC4 | jq -e '[.skipped_phases[].rationale | length > 0] | all' 2>/dev/null || echo false)"
[[ "$t62ac4_ok" == "true" ]] && pass "T62 AC4 -- every mini-srd-seeded skipped_phases entry has a non-empty rationale" \
  || fail "T62 AC4 -- a mini-srd-seeded skipped_phases entry has an empty rationale"
t62ac4_names_mode="$("$EDM_STATE" get T62AC4 | jq -r '[.skipped_phases[].rationale] | join(" ")')"
check "T62 AC4 -- the seeded rationale names the mode" "mini-srd" "$t62ac4_names_mode"

# ---- AC5 (legacy degradation is recoverable from state, not just console) -----------------
echo
echo "T62 AC5 -- skipped-check record persists in state (degraded_checks)"
"$EDM_STATE" init T62AC5 >/dev/null
STATE_T62AC5="$TMP/SRD/T62AC5/.edm-state.json"
jq 'del(.mode)' "$STATE_T62AC5" > "$STATE_T62AC5.tmp" && mv "$STATE_T62AC5.tmp" "$STATE_T62AC5"
t62ac5_ps_out="$("$EDM_STATE" phase-start T62AC5 1 2>&1)"
check "T62 AC5 -- legacy phase-start still prints the [warn] legacy initiative line" \
  "[warn] legacy initiative" "$t62ac5_ps_out"
t62ac5_degraded="$(jq -e '.degraded_checks | length > 0' "$STATE_T62AC5" 2>/dev/null || echo false)"
[[ "$t62ac5_degraded" == "true" ]] && pass "T62 AC5 -- degraded_checks is non-empty after a legacy phase-start" \
  || fail "T62 AC5 -- degraded_checks is empty or absent after a legacy phase-start"
check "T62 AC5 -- degraded_checks names the skipped check" "kernel-gate-enforcement" \
  "$(jq -r '.degraded_checks[0].check' "$STATE_T62AC5" 2>/dev/null || true)"

# ---- AC6 (HANDOFF renders exemptions) ------------------------------------------------------
echo
echo "T62 AC6 -- HANDOFF renders skipped phases and their rationales"
"$EDM_STATE" write-handoff T62AC1 >/dev/null
T62AC1_HANDOFF="$TMP/SRD/T62AC1/HANDOFF.md"
check "T62 AC6 -- HANDOFF.md has a Skipped phases section" "Skipped phases" \
  "$(cat "$T62AC1_HANDOFF" 2>/dev/null || true)"
check "T62 AC6 -- HANDOFF.md names the skipped phase and its rationale" \
  "mini-srd fuses planning and SRD" "$(cat "$T62AC1_HANDOFF" 2>/dev/null || true)"

# ---- AC7 (validate reports every active exemption, informationally) -----------------------
echo
echo "T62 AC7 -- validate reports every active exemption informationally, exit 0"
t62ac7_ec=0
t62ac7_out="$("$EDM_STATE" validate T62AC1 2>&1)" || t62ac7_ec=$?
check "T62 AC7 -- validate reports the canonical four-field ACTIVE_EXEMPTION line" \
  "info  ACTIVE_EXEMPTION  skipped_phases" "$t62ac7_out"
[[ $t62ac7_ec -eq 0 ]] && pass "T62 AC7 -- validate exits 0 with an active exemption present" \
  || fail "T62 AC7 -- validate exited ${t62ac7_ec}, expected 0"
# Cross-check against T62AC5's degraded_checks entry too (the other exemption category).
t62ac7_degraded_out="$("$EDM_STATE" validate T62AC5 2>&1)"
check "T62 AC7 -- validate reports a degraded_checks entry as ACTIVE_EXEMPTION too" \
  "info  ACTIVE_EXEMPTION  degraded_checks" "$t62ac7_degraded_out"

# ---- AC8 (preserve): the prototype archive warning text is unchanged ----------------------
echo
echo "T62 AC8 -- prototype archive warning text preserved"
export EDM_MODE="prototype"
"$EDM_STATE" init T62AC8 >/dev/null
unset EDM_MODE
STATE_T62AC8="$TMP/SRD/T62AC8/.edm-state.json"
"$EDM_STATE" approve-gate T62AC8 1 >/dev/null
jq '.current_phase = 2 | .phase_durations["2_phase"] = {started_at: "2026-01-01T00:00:00Z", completed_at: "2026-01-01T01:00:00Z"}' \
  "$STATE_T62AC8" > "$STATE_T62AC8.tmp" && mv "$STATE_T62AC8.tmp" "$STATE_T62AC8"
t62ac8_out="$("$EDM_STATE" archive T62AC8 2>&1)"
check "T62 AC8 -- prototype archive warning text preserved" \
  "[warn] no code-audit round in this phase graph (mode=prototype, lifecycle_mode=standard) -- skipping the convergence check" "$t62ac8_out"

# ---- AC9 (every approval carries its enforcement tag) --------------------------------------
echo
echo "T62 AC9 -- every gates_approved entry carries its enforcement tag"
"$EDM_STATE" init T62AC9 >/dev/null
"$EDM_STATE" approve-gate T62AC9 1 >/dev/null
t62ac9_ok="$("$EDM_STATE" get T62AC9 | jq -e '[.gates_approved[] | has("enforcement")] | all' 2>/dev/null || echo false)"
[[ "$t62ac9_ok" == "true" ]] && pass "T62 AC9 -- every gates_approved entry has an enforcement key" \
  || fail "T62 AC9 -- a gates_approved entry is missing its enforcement key"

# ---- AC10 (negative, no unrecorded exemption path exists) ----------------------------------
echo
echo "T62 AC10 -- no unrecorded exemption path (no override flag/env var/mode shortcut)"
# CA-037: this was a bare [[ -z ... ]] with no proof the scan pattern could ever match anything --
# a typo'd pattern or an accidentally-scoped find would pass identically to a genuinely clean
# tree. Route each of the three OR'd tokens through assert_tree_absent separately (G2/CA-037 +
# G13/CA-145, round 4; so a failure names exactly which token was found, not just "an
# override-flag-shaped token"), each with its own genuinely seeded positive control.
t62ac10_tokens=(EDM_SKIP EDM_FORCE SKIP_CHECKS)
t62ac10_or_pattern="${t62ac10_tokens[0]}\|${t62ac10_tokens[1]}\|${t62ac10_tokens[2]}"
t62ac10_grep="$(command grep -rn "$t62ac10_or_pattern" "${SCRIPT_DIR}/.." 2>/dev/null | command grep -v '/tests/' || true)"
# G2/CA-037 + G13/CA-145: each iteration's control is now a genuinely seeded scratch file (not a
# hand-typed literal), and "${SCRIPT_DIR}/.." is asserted to exist before each needle check runs
# -- routed through the shared assert_tree_absent (_harness.sh), which closes CA-145 too by
# asserting count_matches_strict's own exit status alongside its printed value.
# G2/CA-037 residual (round 5): the OR'd producing pattern is now built from the same
# $t62ac10_tokens array the loop iterates, closing the divergent-typo class between the real
# scan and each per-token check. Each control's literal text comes from a case statement keyed
# on the token, not from re-interpolating the loop variable -- so a typo in the token list itself
# (which would corrupt both the producing pattern and the arg2 check identically) leaves no case
# arm matching and the control is empty, correctly failing "positive control broken" rather than
# silently mirroring the same typo into a self-consistent false pass.
for t62ac10_needle in "${t62ac10_tokens[@]}"; do
  case "$t62ac10_needle" in
    EDM_SKIP)    t62ac10_control_text='if [ -n "$EDM_SKIP" ]; then true; fi' ;;
    EDM_FORCE)   t62ac10_control_text='if [ -n "$EDM_FORCE" ]; then true; fi' ;;
    SKIP_CHECKS) t62ac10_control_text='if [ -n "$SKIP_CHECKS" ]; then true; fi' ;;
    *)           t62ac10_control_text='' ;;
  esac
  t62ac10_control_file="${TMP}/edm-t62-${t62ac10_needle}-control.txt"
  printf '%s\n' "$t62ac10_control_text" > "$t62ac10_control_file"
  assert_tree_absent "T62 AC10 -- no ${t62ac10_needle} token anywhere in bin/ (excluding tests/)" \
    "$t62ac10_needle" "$t62ac10_grep" "$(cat "$t62ac10_control_file")" "${SCRIPT_DIR}/.."
  rm -f "$t62ac10_control_file"
done
# CA-037: same gap for the literal --force/--accept-partials count -- a positive control proves
# the same grep -c invocation would report >=1 against a line that actually contains the flag,
# so the "0" below is a real absence, not an untested pattern silently matching nothing.
# G2/CA-037 residual (round 5): the pattern is now one variable used by both the real count and
# the control count, instead of two independently-typed copies of the same literal.
t62ac10_force_or_pattern='--force\|--accept-partials'
t62ac10_force="$(command grep -c -- "$t62ac10_force_or_pattern" "$EDM_STATE" 2>/dev/null || true)"
t62ac10_force_control="$(printf '%s\n' 'synthetic control line: --force' | command grep -c -- "$t62ac10_force_or_pattern" || true)"
if [[ "${t62ac10_force_control:-0}" -lt 1 ]]; then
  fail "T62 AC10 -- positive control broken: a synthetic --force line was not counted by the same grep -c"
else
  [[ "${t62ac10_force:-0}" -eq 0 ]] && pass "T62 AC10 -- no --force/--accept-partials literal in bin/edm-state (positive control confirms the count would be >=1 if present)" \
    || fail "T62 AC10 -- found ${t62ac10_force} occurrence(s) of a literal override flag in bin/edm-state"
fi

# =================================================================================
# EDMV3-T64: wave-A closeout -- read-only commands and concurrent mutation smoke
# =================================================================================

# ---- AC7 (EDMV3-92, negative): read-only commands leave the state byte-identical ----------
echo
echo "T64 AC7 -- read-only commands leave the state byte-identical"
"$EDM_STATE" init T64AC7 >/dev/null
STATE_T64AC7="$TMP/SRD/T64AC7/.edm-state.json"
validate_t64ac7="$("$EDM_STATE" validate T64AC7 2>&1 || true)"
[[ -n "$validate_t64ac7" ]] && pass "T64 AC7 -- validate emits read-only output" \
  || fail "T64 AC7 -- validate produced no output"
get_t64ac7="$("$EDM_STATE" get T64AC7 2>/dev/null || true)"
check "T64 AC7 -- get emits the initiative prefix" '"prefix": "T64AC7"' "$get_t64ac7"
gate_t64ac7="$("$EDM_STATE" gate-check T64AC7 srd 2>&1 || true)"
[[ -n "$gate_t64ac7" ]] && pass "T64 AC7 -- gate-check emits refusal output without mutating state" \
  || fail "T64 AC7 -- gate-check produced no output"
list_t64ac7="$("$EDM_STATE" list --paths 2>/dev/null || true)"
check "T64 AC7 -- list --paths emits the initiative directory" "$TMP/SRD/T64AC7" "$list_t64ac7"
check_state_unchanged "$STATE_T64AC7" "$EDM_STATE" validate T64AC7
check_state_unchanged "$STATE_T64AC7" "$EDM_STATE" get T64AC7
check_state_unchanged "$STATE_T64AC7" "$EDM_STATE" gate-check T64AC7 srd
check_state_unchanged "$STATE_T64AC7" "$EDM_STATE" list --paths

# ---- AC8 (EDMV3-92, concurrency): two concurrent mutations both land ----------------------
echo
echo "T64 AC8 -- two concurrent mutations both land"
"$EDM_STATE" init T64AC8 >/dev/null
STATE_T64AC8="$TMP/SRD/T64AC8/.edm-state.json"
"$EDM_STATE" set T64AC8 estimated_size Medium >/dev/null &
t64ac8_pid1=$!
# G29/CA-356: re-keyed from qc_shard_threshold, deleted from SETTABLE_KEYS (dead settable key,
# zero producers/readers) -- current_phase is any other numeric settable key, which is all this
# concurrency case actually needs (it does not care which key it races on).
"$EDM_STATE" set T64AC8 current_phase 1 >/dev/null &
t64ac8_pid2=$!
# G4/CA-036 (round 5): a bare `wait "$pid"` under this file's own `set -euo pipefail` takes on
# the reaped job's own exit status -- if either backgrounded `edm-state set` loses the
# lock-timeout race this case exists to exercise, `wait` itself aborts the whole suite instead
# of reaching a named T64 AC8 failure. Seed-zero-then-capture on the same statement so a losing
# race reports here, not as a suite-wide CRASH.
t64ac8_ec1=0
wait "$t64ac8_pid1" || t64ac8_ec1=$?
t64ac8_ec2=0
wait "$t64ac8_pid2" || t64ac8_ec2=$?
[[ "$t64ac8_ec1" -eq 0 ]] && pass "T64 AC8 -- first backgrounded edm-state set (estimated_size) exited 0" \
  || fail "T64 AC8 -- first backgrounded edm-state set (estimated_size) exited ${t64ac8_ec1} (expected 0)"
[[ "$t64ac8_ec2" -eq 0 ]] && pass "T64 AC8 -- second backgrounded edm-state set (current_phase) exited 0" \
  || fail "T64 AC8 -- second backgrounded edm-state set (current_phase) exited ${t64ac8_ec2} (expected 0)"
if jq -e . "$STATE_T64AC8" >/dev/null 2>&1; then
  pass "T64 AC8 -- state file is valid JSON after two concurrent mutations"
else
  fail "T64 AC8 -- state file is not valid JSON after two concurrent mutations"
fi
t64ac8_size="$(jq -r '.estimated_size' "$STATE_T64AC8")"
t64ac8_phase="$(jq -r '.current_phase' "$STATE_T64AC8")"
[[ "$t64ac8_size" == "Medium" ]] && pass "T64 AC8 -- first concurrent mutation (estimated_size) landed" \
  || fail "T64 AC8 -- estimated_size is '$t64ac8_size', expected 'Medium'"
[[ "$t64ac8_phase" == "1" ]] && pass "T64 AC8 -- second concurrent mutation (current_phase) landed" \
  || fail "T64 AC8 -- current_phase is '$t64ac8_phase', expected '1'"

# =================================================================================
# EDMV3-T26: edm-state render-ledger produces the markdown deterministically
# =================================================================================
echo
echo "T26 -- render-ledger renders findings-ledger.md deterministically from the JSONL"

"$EDM_STATE" init T26LEDGER >/dev/null
T26_DIR="$TMP/SRD/T26LEDGER"
mkdir -p "${T26_DIR}/code-audit"
T26_JSONL="${T26_DIR}/code-audit/findings-ledger.jsonl"
T26_MD="${T26_DIR}/code-audit/findings-ledger.md"
cat > "$T26_JSONL" <<'EOF'
{"schema":1,"id":"CA-001","sev":"P0","status":"fixed","lenses":["L1","L4"],"confidence":"high","component":"src/auth/handler.py","title":"Stub returns hardcoded data","raised_round":1,"resolved_round":1,"round":1,"round_type":"full"}
{"schema":1,"id":"CA-002","sev":"NOTED","status":"noted","lenses":["L8"],"confidence":"high","component":"src/api/server.js","title":"hardcoded port documented as intentional","raised_round":1,"resolved_round":null,"round":1,"round_type":"full"}
{"schema":1,"id":"CA-003","sev":"P1","status":"open","lenses":["L9"],"confidence":"medium","component":"(missing)","title":"--dry-run flag not built","raised_round":1,"resolved_round":null,"round":1,"round_type":"full"}
EOF

# ---- AC1 (positive): the table + Decisions / Non-Findings section --------------------------
t26_out="$("$EDM_STATE" render-ledger T26LEDGER)"
[[ -f "$T26_MD" ]] && pass "T26 AC1 -- render-ledger writes findings-ledger.md" \
  || fail "T26 AC1 -- findings-ledger.md not written"
check "T26 AC1 -- rendered ledger has the Decisions / Non-Findings section" \
  "Decisions / Non-Findings" "$(cat "$T26_MD" 2>/dev/null)"
check "T26 AC1 -- rendered ledger names CA-001" "CA-001" "$(cat "$T26_MD" 2>/dev/null)"
check "T26 AC1 -- rendered ledger names CA-003 (open P1)" "CA-003" "$(cat "$T26_MD" 2>/dev/null)"
check "T26 AC1 -- CA-002 (NOTED) appears in the Decisions section, not the findings table" \
  "hardcoded port documented as intentional" "$(cat "$T26_MD" 2>/dev/null)"

# ---- AC2 (deterministic): running it twice produces byte-identical output ------------------
cp "$T26_MD" "$TMP/T26_a.md"
"$EDM_STATE" render-ledger T26LEDGER >/dev/null
if diff -q "$TMP/T26_a.md" "$T26_MD" >/dev/null 2>&1; then
  pass "T26 AC2 -- render-ledger is deterministic (byte-identical across two runs)"
else
  fail "T26 AC2 -- render-ledger output differs across two runs"
fi

# ---- AC3 (generated-file header) -----------------------------------------------------------
t26_head3="$(head -3 "$T26_MD")"
check "T26 AC3 -- header names the file as generated and not to be hand-edited" \
  "GENERATED FILE" "$t26_head3"

# ---- AC4/AC5 (hand-edit detected by the drift loop, then overwritten on re-render) ---------
echo "HAND EDITED CONTENT" >> "$T26_MD"
t26_checkpoint_out="$("$EDM_STATE" checkpoint-if-active 2>&1 || true)"
check "T26 AC4 -- checkpoint-if-active's drift loop names findings-ledger.md" \
  "findings-ledger.md" "$t26_checkpoint_out"
"$EDM_STATE" render-ledger T26LEDGER >/dev/null
check_absent "T26 AC5 -- re-running render-ledger overwrites the hand-edit" \
  "HAND EDITED CONTENT" "$(cat "$T26_MD" 2>/dev/null)"

# ---- AC6 (atomic write, static assertion) --------------------------------------------------
check "T26 AC6 -- render-ledger writes via write_atomic helper (atomic temp-file-plus-rename)" \
  "write_atomic" \
  "$(grep -n 'write_atomic.*md_path\|write_atomic.*ledger' "$EDM_STATE" || true)"

# ---- AC8 (lint clean, minus the not-yet-landed Mermaid class from EDMV3-T43) ---------------
t26_lint_ec=0
t26_lint_out="$(bash "${SCRIPT_DIR}/../edm-lint-artifacts" --path "$T26_MD" 2>&1)" || t26_lint_ec=$?
[[ $t26_lint_ec -eq 0 ]] && pass "T26 AC8 -- edm-lint-artifacts --path exits 0 against the rendered ledger" \
  || fail "T26 AC8 -- edm-lint-artifacts --path exited ${t26_lint_ec}: ${t26_lint_out}"

# ---- AC9 (surfaced in --help and the dispatch table) ---------------------------------------
check "T26 AC9 -- render-ledger documented in --help" \
  "render-ledger" "$("$EDM_STATE" --help 2>&1)"
check "T26 AC9 -- render-ledger wired in the dispatch table" \
  "render-ledger)" "$(grep -n 'render-ledger)' "$EDM_STATE" || true)"

# ---- AC10 (negative, no ledger) -------------------------------------------------------------
"$EDM_STATE" init T26NOLEDGER >/dev/null
check_fails "T26 AC10 -- render-ledger with no JSONL refuses, naming 'no code audit has run'" \
  "no code audit has run" "$EDM_STATE" render-ledger T26NOLEDGER
[[ ! -f "$TMP/SRD/T26NOLEDGER/code-audit/findings-ledger.md" ]] \
  && pass "T26 AC10 -- no findings-ledger.md written when the JSONL is absent" \
  || fail "T26 AC10 -- findings-ledger.md was written despite the missing JSONL"

# ---- G18/CA-378 (pipe-escaping): a pipe-bearing title must not shift table columns ----------
echo
echo "G18 -- render-ledger escapes pipes in cell-bound fields (case patterns, regexes, glob sets)"
"$EDM_STATE" init T26PIPE >/dev/null
T26PIPE_DIR="$TMP/SRD/T26PIPE"
mkdir -p "${T26PIPE_DIR}/code-audit"
T26PIPE_JSONL="${T26PIPE_DIR}/code-audit/findings-ledger.jsonl"
T26PIPE_MD="${T26PIPE_DIR}/code-audit/findings-ledger.md"
cat > "$T26PIPE_JSONL" <<'EOF'
{"schema":1,"id":"CA-901","sev":"P1","status":"open","lenses":["L1"],"confidence":"high","component":"a|b.sh","title":"case \"$x\" in ''|*[!0-9]*) fails; glob set *.awk|*.txt; enum open|fixed|noted","raised_round":1,"resolved_round":null,"round":1,"round_type":"full"}
EOF
"$EDM_STATE" render-ledger T26PIPE >/dev/null
g18_row="$(grep '^| CA-901' "$T26PIPE_MD" || true)"
check "G18 -- pipe-bearing title's literal pipes are escaped (backslash-pipe), not raw" \
  '\|*[!0-9]*' "$g18_row"
g18_cells="$(printf '%s' "$g18_row" | perl -pe 's/\\\|//g' | awk -F'|' '{print NF-2}')"
[[ "$g18_cells" == "8" ]] && pass "G18 -- pipe-bearing row still has exactly 8 cells once escaped pipes are discounted" \
  || fail "G18 -- pipe-bearing row has ${g18_cells} cells, expected 8"

# Every rendered row (header + data rows) must have exactly 8 cells once escaped pipes are
# discounted -- protects the shape even if a future field addition regresses alignment (G18).
g18_bad_rows=0
while IFS= read -r g18_line; do
  case "$g18_line" in
    '| ID '*|'|----'*|'| CA-'*)
      g18_n="$(printf '%s' "$g18_line" | perl -pe 's/\\\|//g' | awk -F'|' '{print NF-2}')"
      [[ "$g18_n" == "8" ]] || g18_bad_rows=$((g18_bad_rows + 1))
      ;;
  esac
done < "$T26PIPE_MD"
[[ "$g18_bad_rows" -eq 0 ]] && pass "G18 -- every table row (header + data) has exactly 8 cells" \
  || fail "G18 -- ${g18_bad_rows} table row(s) do not have exactly 8 cells"

# =================================================================================
# G17/CA-354 (round 6): read+render+write_atomic and record_artifact_hash used to run as three
# independently-atomic but un-sequenced steps, so two concurrent render-ledger invocations could
# interleave (last-hash-wins racing last-content-wins) and leave a recorded hash that does not
# match the file actually on disk -- surfacing later as a phantom cmd_checkpoint drift warning.
# Fixed by moving read+render+write_atomic under one with_state_lock; verify the two can no
# longer disagree by actually racing two invocations and checking the recorded hash afterward.
# =================================================================================
echo
echo "G17/CA-354 -- two concurrent render-ledger invocations: the recorded hash matches the on-disk .md's actual hash"
"$EDM_STATE" init T17RLRACE >/dev/null
T17RLRACE_DIR="$TMP/SRD/T17RLRACE"
mkdir -p "${T17RLRACE_DIR}/code-audit"
cat > "${T17RLRACE_DIR}/code-audit/findings-ledger.jsonl" <<'EOF'
{"schema":1,"id":"CA-001","sev":"P1","status":"open","lenses":["L1"],"confidence":"high","component":"a.py","title":"race fixture finding one","raised_round":1,"resolved_round":null,"round":1,"round_type":"full"}
{"schema":1,"id":"CA-002","sev":"P2","status":"open","lenses":["L4"],"confidence":"medium","component":"b.py","title":"race fixture finding two","raised_round":1,"resolved_round":null,"round":1,"round_type":"full"}
EOF
t17rlrace_ec1=0 t17rlrace_ec2=0
"$EDM_STATE" render-ledger T17RLRACE >/dev/null 2>&1 &
t17rlrace_pid1=$!
"$EDM_STATE" render-ledger T17RLRACE >/dev/null 2>&1 &
t17rlrace_pid2=$!
wait "$t17rlrace_pid1" || t17rlrace_ec1=$?
wait "$t17rlrace_pid2" || t17rlrace_ec2=$?
[[ $t17rlrace_ec1 -eq 0 && $t17rlrace_ec2 -eq 0 ]] \
  && pass "G17/CA-354 -- both concurrent render-ledger invocations exit 0 (no lock-trap collision)" \
  || fail "G17/CA-354 -- concurrent render-ledger exit codes were ${t17rlrace_ec1}/${t17rlrace_ec2}, expected 0/0"

t17rlrace_md="${T17RLRACE_DIR}/code-audit/findings-ledger.md"
t17rlrace_actual_hash="$(bash -c "source '$EDM_STATE' >/dev/null 2>&1; artifact_hash '${t17rlrace_md}'")"
t17rlrace_recorded_hash="$(jq -r '.artifact_hashes.findings_ledger.hash // "absent"' "${T17RLRACE_DIR}/.edm-state.json")"
[[ -n "$t17rlrace_actual_hash" && "$t17rlrace_actual_hash" == "$t17rlrace_recorded_hash" ]] \
  && pass "G17/CA-354 -- the recorded artifact hash matches the on-disk file's actual hash after the race" \
  || fail "G17/CA-354 -- recorded hash '${t17rlrace_recorded_hash}' != actual hash '${t17rlrace_actual_hash}' after concurrent renders"

check "G17/CA-354 -- the .md file itself is still well-formed after the race (not truncated/interleaved)" \
  "CA-001" "$(cat "$t17rlrace_md" 2>/dev/null)"
check "G17/CA-354 -- both findings survived the race" \
  "CA-002" "$(cat "$t17rlrace_md" 2>/dev/null)"

t17rlrace_checkpoint_out="$("$EDM_STATE" checkpoint-if-active 2>&1 || true)"
check_absent "G17/CA-354 -- checkpoint-if-active reports no phantom drift for T17RLRACE after the race" \
  "T17RLRACE" "$t17rlrace_checkpoint_out"

# =================================================================================
# EDMV3-T27: rounds record their lens set, so a partial round can never compute convergence
# =================================================================================
echo
echo "T27 -- audit-round-start records lens set + round_type; audit_rounds widens to {count, rounds}"

"$EDM_STATE" init T27ROUND >/dev/null
STATE_T27ROUND="$TMP/SRD/T27ROUND/.edm-state.json"

# ---- AC1 (positive, full round -- no --lenses given) ---------------------------------------
round_full="$("$EDM_STATE" audit-round-start T27ROUND code)"
[[ "$round_full" == "1" ]] && pass "T27 AC1 -- audit-round-start still echoes the round number (1)" \
  || fail "T27 AC1 -- audit-round-start echoed '$round_full', expected 1"
full_round_type="$(jq -r '.audit_rounds.code.rounds[-1].round_type' "$STATE_T27ROUND")"
[[ "$full_round_type" == "full" ]] && pass "T27 AC1 -- omitting --lenses records round_type=full" \
  || fail "T27 AC1 -- round_type = '$full_round_type', expected full"

# ---- AC1 (positive, partial round -- --lenses given a strict subset) -----------------------
round_partial="$("$EDM_STATE" audit-round-start T27ROUND code --lenses L1,L9,L11)"
[[ "$round_partial" == "2" ]] && pass "T27 AC1 -- second round still echoes 2 (unchanged external contract)" \
  || fail "T27 AC1 -- audit-round-start echoed '$round_partial', expected 2"
"$EDM_STATE" get T27ROUND | jq -e '.audit_rounds.code.rounds[-1].round_type == "partial"' >/dev/null \
  && pass "T27 AC1 -- --lenses L1,L9,L11 records round_type=partial" \
  || fail "T27 AC1 -- round_type is not 'partial' after a 3-of-11 lens round"
partial_lenses="$(jq -r '.audit_rounds.code.rounds[-1].lenses | join(",")' "$STATE_T27ROUND")"
[[ "$partial_lenses" == "L1,L9,L11" ]] && pass "T27 AC1 -- the recorded lens set matches --lenses exactly" \
  || fail "T27 AC1 -- recorded lenses = '$partial_lenses', expected L1,L9,L11"

# ---- AC1 (full round via an explicit --lenses listing all eleven) --------------------------
round_all11="$("$EDM_STATE" audit-round-start T27ROUND code --lenses L1,L2,L3,L4,L5,L6,L7,L8,L9,L10,L11)"
all11_round_type="$(jq -r '.audit_rounds.code.rounds[-1].round_type' "$STATE_T27ROUND")"
[[ "$all11_round_type" == "full" ]] && pass "T27 AC1 -- --lenses listing all eleven records round_type=full" \
  || fail "T27 AC1 -- round_type = '$all11_round_type', expected full for an explicit all-11 listing"

# ---- srd/tickets audit types: independent counters, always full (no lens concept) ----------
round_srd27="$("$EDM_STATE" audit-round-start T27ROUND srd)"
[[ "$round_srd27" == "1" ]] && pass "T27 -- srd round type is independent of code's counter" \
  || fail "T27 -- srd round = '$round_srd27', expected 1"
srd_round_type="$(jq -r '.audit_rounds.srd.rounds[-1].round_type' "$STATE_T27ROUND")"
[[ "$srd_round_type" == "full" ]] && pass "T27 -- srd audit type has no lens concept, records round_type=full" \
  || fail "T27 -- srd round_type = '$srd_round_type', expected full"

# ---- AC1a (C-4, the sanctioned type widening): a legacy bare-integer audit_rounds.<type> is
# coerced on the very next write, rather than erroring or losing the existing count -----------
echo
echo "T27 AC1a -- legacy bare-integer audit_rounds.code coerces on the next write"
"$EDM_STATE" init T27LEGACY >/dev/null
STATE_T27LEGACY="$TMP/SRD/T27LEGACY/.edm-state.json"
jq '.audit_rounds = {"code": 2}' "$STATE_T27LEGACY" > "$STATE_T27LEGACY.tmp" && mv "$STATE_T27LEGACY.tmp" "$STATE_T27LEGACY"
pre_legacy_type="$(jq -r '.audit_rounds.code | type' "$STATE_T27LEGACY")"
[[ "$pre_legacy_type" == "number" ]] && pass "T27 AC1a -- fixture starts with the legacy bare-integer shape" \
  || fail "T27 AC1a -- fixture audit_rounds.code type = '$pre_legacy_type', expected number"
"$EDM_STATE" audit-round-start T27LEGACY code >/dev/null
legacy_count="$(jq -r '.audit_rounds.code.count' "$STATE_T27LEGACY")"
[[ "$legacy_count" == "3" ]] && pass "T27 AC1a -- coerced count continues from the legacy integer (2 -> 3)" \
  || fail "T27 AC1a -- audit_rounds.code.count = '$legacy_count', expected 3"
legacy_rounds_len="$(jq -r '.audit_rounds.code.rounds | length' "$STATE_T27LEGACY")"
[[ "$legacy_rounds_len" == "1" ]] && pass "T27 AC1a -- only the new round is recorded in detail (no fabricated history)" \
  || fail "T27 AC1a -- rounds array length = '$legacy_rounds_len', expected 1 (the two legacy rounds have no per-round detail)"

# ---- AC8 (atomicity and bash 3.2): valid JSON after the write, bash -n on the script --------
echo
echo "T27 AC8 -- audit-round-start leaves valid JSON; bin/edm-state passes bash -n"
jq -e . "$STATE_T27ROUND" >/dev/null 2>&1 \
  && pass "T27 AC8 -- state file is valid JSON after audit-round-start" \
  || fail "T27 AC8 -- state file is not valid JSON after audit-round-start"
bash -n "$EDM_STATE" && pass "T27 AC8 -- bin/edm-state passes bash -n" \
  || fail "T27 AC8 -- bin/edm-state failed bash -n"

# ---- Negative: unknown audit type / malformed --lenses still refused -----------------------
echo
check_fails "T27 -- unknown audit type still refused" "unknown audit type" \
  "$EDM_STATE" audit-round-start T27ROUND bogus
check_fails "T27 -- --lenses with no value refused" "requires a non-empty" \
  "$EDM_STATE" audit-round-start T27ROUND code --lenses
check_fails "T27 -- unknown flag after audit type refused" "unknown argument" \
  "$EDM_STATE" audit-round-start T27ROUND code --bogus L1

# ---- Surfaced in --help -----------------------------------------------------------------
t27_help_line="$("$EDM_STATE" --help 2>&1 | grep 'audit-round-start' || true)"
check "T27 -- --lenses documented on the audit-round-start help line" "--lenses" "$t27_help_line"

# =================================================================================
# EDMV3-T28: edm-state audit-converged computes convergence over one blocking predicate
# =================================================================================
echo
echo "T28 -- audit-converged computes convergence via the shared BLOCKING_FILTER predicate"

"$EDM_STATE" init T28CONV >/dev/null
STATE_T28CONV="$TMP/SRD/T28CONV/.edm-state.json"
jq '.schema_version = 2' "$STATE_T28CONV" > "$STATE_T28CONV.tmp" && mv "$STATE_T28CONV.tmp" "$STATE_T28CONV"
T28_DIR="$TMP/SRD/T28CONV"
T28_JSONL="${T28_DIR}/code-audit/findings-ledger.jsonl"

# ---- AC6 (negative, no ledger vs no findings) -- missing jsonl exits 3 ---------------------
check_fails "T28 AC6 -- audit-converged with no ledger exits 3 naming 'no audit has run'" \
  "no code audit has run" "$EDM_STATE" audit-converged T28CONV
set +e
"$EDM_STATE" audit-converged T28CONV >/dev/null 2>&1
t28_noledger_ec=$?
set -e
[[ $t28_noledger_ec -eq 3 ]] && pass "T28 AC6 -- exit code is 3 for a missing ledger" \
  || fail "T28 AC6 -- exit code = $t28_noledger_ec, expected 3"

# ---- AC1 (positive, empty ledger -- "no findings" wording) ---------------------------------
mkdir -p "${T28_DIR}/code-audit"
: > "$T28_JSONL"
"$EDM_STATE" audit-round-start T28CONV code >/dev/null   # full round (no --lenses)
t28_empty_ec=0
t28_empty_out="$("$EDM_STATE" audit-converged T28CONV)" || t28_empty_ec=$?
[[ $t28_empty_ec -eq 0 ]] && pass "T28 AC1/AC6 -- an empty ledger converges (exit 0)" \
  || fail "T28 AC1/AC6 -- empty ledger exited $t28_empty_ec, expected 0"
check "T28 AC6 -- empty ledger uses the 'no findings' wording, distinct from 'no ledger'" \
  "no findings recorded" "$t28_empty_out"

# ---- AC2/AC5 (negative): open P0/P1/P2 plus a re-opened legacy 'deferred' line all block ---
cat > "$T28_JSONL" <<'EOF'
{"schema":1,"id":"CA-001","sev":"P0","status":"open","lenses":["L1"],"confidence":"high","component":"a.py","title":"open P0 finding","raised_round":1,"resolved_round":null,"round":1,"round_type":"full"}
{"schema":1,"id":"CA-002","sev":"P1","status":"open","lenses":["L4"],"confidence":"high","component":"b.py","title":"open P1 finding","raised_round":1,"resolved_round":null,"round":1,"round_type":"full"}
{"schema":1,"id":"CA-003","sev":"P2","status":"open","lenses":["L10"],"confidence":"medium","component":"c.py","title":"open P2 finding","raised_round":1,"resolved_round":null,"round":1,"round_type":"full"}
{"schema":1,"id":"CA-004","sev":"NOTED","status":"noted","lenses":["L8"],"confidence":"high","component":"d.py","title":"intentional, not actionable","raised_round":1,"resolved_round":null,"round":1,"round_type":"full"}
{"schema":1,"id":"CA-005","sev":"P1","status":"fixed","lenses":["L9"],"confidence":"medium","component":"e.py","title":"fixed finding","raised_round":1,"resolved_round":1,"round":1,"round_type":"full"}
{"schema":1,"id":"CA-006","sev":"P2","status":"deferred","lenses":["L7"],"confidence":"low","component":"f.py","title":"legacy deferred line","raised_round":1,"resolved_round":null,"round":1,"round_type":"full"}
EOF
check_fails "T28 AC2 -- open P0/P1/P2 findings fail convergence" \
  "not converged" "$EDM_STATE" audit-converged T28CONV
t28_blocking_out="$("$EDM_STATE" audit-converged T28CONV 2>&1 || true)"
check "T28 AC2 -- blocking output names CA-001 (open P0)" "CA-001" "$t28_blocking_out"
check "T28 AC2 -- blocking output names CA-002 (open P1)" "CA-002" "$t28_blocking_out"
check "T28 AC2 -- blocking output names CA-003 (open P2)" "CA-003" "$t28_blocking_out"
check "T28 AC5 -- legacy 'deferred' line CA-006 is re-opened and named in the blocking set" \
  "CA-006" "$t28_blocking_out"
check_absent "T28 -- fixed finding CA-005 is not in the blocking output" "CA-005" "$t28_blocking_out"
check "T28 AC2 -- per-severity counts printed (P0=1 P1=1 P2=2, deferred counted at its own severity)" \
  "P0=1 P1=1 P2=2" "$t28_blocking_out"
set +e
"$EDM_STATE" audit-converged T28CONV >/dev/null 2>&1
t28_blocking_ec=$?
set -e
[[ $t28_blocking_ec -eq 1 ]] && pass "T28 AC3 -- exit code is 1 when blocking findings remain" \
  || fail "T28 AC3 -- exit code = $t28_blocking_ec, expected 1"

# ---- AC12 (wiring): approve-gate code-audit refuses on an open P0 --------------------------
check_refuses_and_leaves_state "T28 AC12 -- approve-gate refuses on an open P0" "code-audit gate refused" "$STATE_T28CONV" "$EDM_STATE" approve-gate T28CONV code-audit

# ---- Remediate: close every blocking finding, leaving only the fixed/NOTED entries ---------
jq -cs '
  map(if (.id == "CA-001" or .id == "CA-002" or .id == "CA-003" or .id == "CA-006")
      then .status = "fixed" else . end)
  | .[]
' "$T28_JSONL" > "${T28_JSONL}.tmp" && mv "${T28_JSONL}.tmp" "$T28_JSONL"

# ---- AC11 (four consumers agree on one fixture ledger, after remediation) ------------------
t28_conv_ec=0
t28_conv_out="$("$EDM_STATE" audit-converged T28CONV)" || t28_conv_ec=$?
[[ $t28_conv_ec -eq 0 ]] && pass "T28 AC11 -- consumer 1 (audit-converged) agrees: converged after remediation" \
  || fail "T28 AC11 -- audit-converged still exits $t28_conv_ec after remediation"
# Advance to phase 6 first so write_handoff_internal's Phase-6 next_action branch (consumer 4)
# is actually exercised below -- at phase 0 it would render the generic "Not started" message
# regardless of code_audit_converged.
jq '.current_phase = 6' "$STATE_T28CONV" > "$STATE_T28CONV.tmp" && mv "$STATE_T28CONV.tmp" "$STATE_T28CONV"
"$EDM_STATE" approve-gate T28CONV code-audit >/dev/null \
  && pass "T28 AC11/AC12 -- consumer 2 (approve-gate code-audit) agrees: approval now succeeds" \
  || fail "T28 AC11/AC12 -- approve-gate code-audit still refuses after remediation"
t28_converged_field="$(jq -r '.code_audit_converged' "$STATE_T28CONV")"
[[ "$t28_converged_field" == "true" ]] \
  && pass "T28 AC11 -- consumer 3 (cmd_archive's boolean check) agrees: code_audit_converged=true" \
  || fail "T28 AC11 -- code_audit_converged = '$t28_converged_field', expected true"
t28_handoff_out="$(cat "${T28_DIR}/HANDOFF.md" 2>/dev/null || true)"
check "T28 AC11 -- consumer 4 (write_handoff_internal) agrees: HANDOFF reflects the converged state" \
  "Ready to archive" "$t28_handoff_out"

# ---- AC4 (negative, partial round): a partial round blocks even a clean ledger -------------
"$EDM_STATE" audit-round-start T28CONV code --lenses L1,L2 >/dev/null
check_fails "T28 AC4 -- a partial round fails naming the lens list, even with a clean ledger" \
  "last round was partial" "$EDM_STATE" audit-converged T28CONV
t28_partial_out="$("$EDM_STATE" audit-converged T28CONV 2>&1 || true)"
check "T28 AC4 -- the partial round's lens list is named" "L1,L2" "$t28_partial_out"
# Restore a full round so this fixture doesn't leak a partial state to later tests.
"$EDM_STATE" audit-round-start T28CONV code >/dev/null

# ---- AC7 (C-4, legacy migration is not a fresh audit) --------------------------------------
echo
echo "T28 AC7 -- legacy markdown-only ledger (schema_version < 2) exits 3 with a warning"
"$EDM_STATE" init T28LEGACYMD >/dev/null
mkdir -p "$TMP/SRD/T28LEGACYMD/code-audit"
echo "# Code Audit Findings Ledger" > "$TMP/SRD/T28LEGACYMD/code-audit/findings-ledger.md"
check_fails "T28 AC7 -- legacy markdown-only ledger exits non-zero with a legacy warning" \
  "legacy initiative" "$EDM_STATE" audit-converged T28LEGACYMD
set +e
"$EDM_STATE" audit-converged T28LEGACYMD >/dev/null 2>&1
t28_legacymd_ec=$?
set -e
[[ $t28_legacymd_ec -eq 3 ]] && pass "T28 AC7 -- legacy markdown-only ledger exits 3 (same code as 'no ledger', distinct wording)" \
  || fail "T28 AC7 -- exit code = $t28_legacymd_ec, expected 3"

# ---- AC8 (positive, audit-free modes) -------------------------------------------------------
echo
echo "T28 AC8 -- audit-free mode exits 0 with the exemption wording"
export EDM_MODE="prototype"
"$EDM_STATE" init T28EXEMPT >/dev/null
unset EDM_MODE
t28_exempt_ec=0
t28_exempt_out="$("$EDM_STATE" audit-converged T28EXEMPT)" || t28_exempt_ec=$?
[[ $t28_exempt_ec -eq 0 ]] && pass "T28 AC8 -- prototype mode exits 0 without a ledger" \
  || fail "T28 AC8 -- prototype mode exited $t28_exempt_ec, expected 0"
check "T28 AC8 -- exemption wording names the mode" \
  "no code audit is required for this mode" "$t28_exempt_out"

# ---- AC3 (exit-2 is never used inside cmd_audit_converged) ----------------------------------
t28_body="$(awk '/^cmd_audit_converged\(\) \{/{f=1} f{print} f && /^\}/{exit}' "$EDM_STATE")"
t28_exit2="$(printf '%s\n' "$t28_body" | grep -c 'exit 2' || true)"
[[ "${t28_exit2:-0}" -eq 0 ]] && pass "T28 AC3 -- cmd_audit_converged never uses exit 2" \
  || fail "T28 AC3 -- found ${t28_exit2} 'exit 2' occurrence(s) in cmd_audit_converged"

# ---- AC9 (blocking predicate defined once, one real invocation site; semantics corrected per
# G49/CA-325 -- the original count treated 3 comments mentioning the bare name as if they were
# enforcing call sites, so the assertion stayed green at 5 whether or not the real invocation
# still existed) --------------------------------------------------------------------------------
echo
echo "T28 AC9 -- BLOCKING_FILTER defined once and evaluated at exactly one real invocation site"
t28_bf_def_count="$(grep -c '^BLOCKING_FILTER=' "$EDM_STATE")"
[[ "$t28_bf_def_count" -eq 1 ]] \
  && pass "T28 AC9 -- BLOCKING_FILTER is defined exactly once" \
  || fail "T28 AC9 -- BLOCKING_FILTER definition count = ${t28_bf_def_count}, expected 1"
# The $ sigil requires an actual variable EXPANSION, not just the bare name -- this is what
# excludes the three comments (which mention "BLOCKING_FILTER" in prose, never "$BLOCKING_FILTER")
# from counting as enforcing usage.
t28_bf_invoke_count="$(grep -c '\$BLOCKING_FILTER' "$EDM_STATE")"
[[ "$t28_bf_invoke_count" -eq 1 ]] \
  && pass "T28 AC9 -- BLOCKING_FILTER has exactly one real invocation site (inside cmd_audit_converged)" \
  || fail "T28 AC9 -- BLOCKING_FILTER real invocation count = ${t28_bf_invoke_count}, expected 1"
# Positive control: prove the $ -sigil needle actually discriminates a real expansion from a bare
# comment mention, rather than passing vacuously.
t28_bf_control="$(printf '%s\n' '# BLOCKING_FILTER mentioned here in prose' 'select('"'"'$BLOCKING_FILTER'"'"')' | grep -c '\$BLOCKING_FILTER')"
[[ "$t28_bf_control" -eq 1 ]] \
  && pass "T28 AC9 -- positive control: the \$ -sigil needle matches the real expansion and not the comment" \
  || fail "T28 AC9 -- positive control broken: expected exactly 1 match, got ${t28_bf_control}"
# The four named consumers reach the predicate INDIRECTLY, by calling cmd_audit_converged --
# three via this exact call shape; the fourth is the direct CLI dispatch entry itself.
t28_cac_callers="$(grep -c 'cmd_audit_converged "\$prefix"' "$EDM_STATE")"
[[ "$t28_cac_callers" -ge 3 ]] \
  && pass "T28 AC9 -- at least three internal callers reach cmd_audit_converged (got ${t28_cac_callers})" \
  || fail "T28 AC9 -- only ${t28_cac_callers} internal caller(s) reach cmd_audit_converged, expected >= 3"

# ---- AC13 (surfaced) -------------------------------------------------------------------------
check "T28 AC13 -- audit-converged documented in --help" \
  "audit-converged" "$("$EDM_STATE" --help 2>&1)"
check "T28 AC13 -- audit-converged wired in the dispatch table" \
  "audit-converged)" "$(grep -n 'audit-converged)' "$EDM_STATE" || true)"

# ---- Read-only guarantee (Technical Notes: takes no lock, mutates nothing) ------------------
# CA-042: an explicit output assertion on this exact invocation, not only the byte-identity
# check below -- T28CONV was restored to a clean full round at AC4 above, so audit-converged is
# expected to succeed here (unlike the partial/legacy/exempt fixtures exercised earlier in this
# block), and this line is what actually proves that rather than assuming it from AC11's earlier
# (differently-invoked) converged=true check.
set +e
t28_roguard_ec=0
t28_roguard_out="$("$EDM_STATE" audit-converged T28CONV 2>&1)" || t28_roguard_ec=$?
set -e
[[ $t28_roguard_ec -eq 0 ]] && pass "T28 read-only guarantee -- audit-converged T28CONV exits 0 (clean full round)" \
  || fail "T28 read-only guarantee -- audit-converged T28CONV exited ${t28_roguard_ec}, expected 0 (output: $t28_roguard_out)"
check_state_unchanged "$STATE_T28CONV" "$EDM_STATE" audit-converged T28CONV

# =================================================================================
# EDMV3-T32: record-partial-verdict supports closure without losing the original note
# =================================================================================
echo
echo "T32 -- record-partial-verdict close preserves the prior note and enforces single closure"

"$EDM_STATE" init T32PV >/dev/null
STATE_T32PV="$TMP/SRD/T32PV/.edm-state.json"

# ---- AC1/AC2 (positive, note preserved; closed entry shape) --------------------------------
"$EDM_STATE" record-partial-verdict T32PV T32PV-T01 PARTIAL "needs retry-logic runtime check" >/dev/null
"$EDM_STATE" record-partial-verdict T32PV T32PV-T01 close PASS "post-deploy/verification.md#t32pv-t01" >/dev/null
t32_ac1_note="$(jq -r '.partial_verdict_map["T32PV-T01"].prior.note' "$STATE_T32PV")"
[[ "$t32_ac1_note" == "needs retry-logic runtime check" ]] \
  && pass "T32 AC1 -- closure preserves the prior note under .prior.note" \
  || fail "T32 AC1 -- .prior.note = '$t32_ac1_note', expected the original note"
t32_ac2_shape="$(jq -e '.partial_verdict_map["T32PV-T01"] | has("prior") and has("closing_verdict") and has("closed_at") and has("verification_ref")' "$STATE_T32PV" 2>/dev/null || echo false)"
[[ "$t32_ac2_shape" == "true" ]] \
  && pass "T32 AC2 -- closed entry has prior/closing_verdict/closed_at/verification_ref" \
  || fail "T32 AC2 -- closed entry is missing one or more of the four expected keys"
t32_ac2_prior_verdict="$(jq -r '.partial_verdict_map["T32PV-T01"].prior.verdict' "$STATE_T32PV")"
[[ "$t32_ac2_prior_verdict" == "PARTIAL" ]] \
  && pass "T32 AC2 -- prior.verdict is the original PARTIAL" \
  || fail "T32 AC2 -- prior.verdict = '$t32_ac2_prior_verdict', expected PARTIAL"
t32_ac2_closing="$(jq -r '.partial_verdict_map["T32PV-T01"].closing_verdict' "$STATE_T32PV")"
[[ "$t32_ac2_closing" == "PASS" ]] && pass "T32 AC2 -- closing_verdict = PASS" \
  || fail "T32 AC2 -- closing_verdict = '$t32_ac2_closing', expected PASS"

# ---- AC3 (negative, single closure) ---------------------------------------------------------
check_refuses_and_leaves_state "T32 AC3 -- second closure attempt refused, naming the existing closure" "already closed" "$STATE_T32PV" "$EDM_STATE" record-partial-verdict T32PV T32PV-T01 close FAIL "some-other-ref"

# ---- AC4 (positive, the sanctioned exception): FAIL then re-close appends to history --------
"$EDM_STATE" record-partial-verdict T32PV T32PV-T02 PARTIAL "needs check" >/dev/null
"$EDM_STATE" record-partial-verdict T32PV T32PV-T02 close FAIL "post-deploy/verification.md#t32pv-t02-fail" >/dev/null
"$EDM_STATE" record-partial-verdict T32PV T32PV-T02 close PASS "post-deploy/verification.md#t32pv-t02-pass" >/dev/null
t32_ac4_history_len="$(jq -r '.partial_verdict_map["T32PV-T02"].closure_history | length' "$STATE_T32PV")"
[[ "$t32_ac4_history_len" == "2" ]] \
  && pass "T32 AC4 -- FAIL then re-close appends to closure_history (length 2)" \
  || fail "T32 AC4 -- closure_history length = '$t32_ac4_history_len', expected 2"
t32_ac4_final="$(jq -r '.partial_verdict_map["T32PV-T02"].closing_verdict' "$STATE_T32PV")"
[[ "$t32_ac4_final" == "PASS" ]] && pass "T32 AC4 -- the current closing_verdict reflects the re-close (PASS)" \
  || fail "T32 AC4 -- closing_verdict = '$t32_ac4_final', expected PASS"
t32_ac4_first_fail="$(jq -r '.partial_verdict_map["T32PV-T02"].closure_history[0].closing_verdict' "$STATE_T32PV")"
[[ "$t32_ac4_first_fail" == "FAIL" ]] \
  && pass "T32 AC4 -- the original FAIL closure is preserved in closure_history[0]" \
  || fail "T32 AC4 -- closure_history[0].closing_verdict = '$t32_ac4_first_fail', expected FAIL"

# ---- AC5 (negative, unknown ticket) ----------------------------------------------------------
check_refuses_and_leaves_state "T32 AC5 -- closing an unknown ticket is refused" "unknown ticket" "$STATE_T32PV" "$EDM_STATE" record-partial-verdict T32PV T32PV-NOSUCHTICKET close PASS "ref"

# ---- AC6 (existing callers unchanged): the open/record form still works exactly as before ----
"$EDM_STATE" record-partial-verdict T32PV T32PV-T03 PASS >/dev/null
t32_ac6_verdict="$(jq -r '.partial_verdict_map["T32PV-T03"].verdict' "$STATE_T32PV")"
[[ "$t32_ac6_verdict" == "PASS" ]] && pass "T32 AC6 -- the unchanged open/record form still writes {verdict, note, recorded_at}" \
  || fail "T32 AC6 -- open/record form verdict = '$t32_ac6_verdict', expected PASS"
t32_ac6_no_closure_keys="$(jq -r '.partial_verdict_map["T32PV-T03"] | has("closing_verdict")' "$STATE_T32PV")"
[[ "$t32_ac6_no_closure_keys" == "false" ]] \
  && pass "T32 AC6 -- a plain open/record entry carries no closure fields" \
  || fail "T32 AC6 -- a plain open/record entry unexpectedly has closing_verdict"

# ---- AC7 (C-4, legacy entry shape reads as unclosed) -----------------------------------------
jq '.partial_verdict_map["T32PV-LEGACY"] = {verdict: "PARTIAL", note: "pre-T32 shape", recorded_at: "2020-01-01T00:00:00Z"}' \
  "$STATE_T32PV" > "$STATE_T32PV.tmp" && mv "$STATE_T32PV.tmp" "$STATE_T32PV"
t32_ac7_unclosed="$(jq -r '.partial_verdict_map["T32PV-LEGACY"] | has("closing_verdict")' "$STATE_T32PV")"
[[ "$t32_ac7_unclosed" == "false" ]] \
  && pass "T32 AC7 -- a legacy-shape entry (no closure fields) reads as unclosed" \
  || fail "T32 AC7 -- legacy entry unexpectedly reports has(closing_verdict)=true"

# ---- AC9 (negative, no third verdict): BLOCKED (or any non-PASS/FAIL) closing verdict refused
"$EDM_STATE" record-partial-verdict T32PV T32PV-T04 PARTIAL "needs check" >/dev/null
check_refuses_and_leaves_state "T32 AC9 -- a BLOCKED closing verdict is refused, naming the two legal values" "PASS|FAIL" "$STATE_T32PV" "$EDM_STATE" record-partial-verdict T32PV T32PV-T04 close BLOCKED "ref"

# ---- AC8 (atomicity): every write goes through rmw_state; bin/edm-state passes bash -n -------
bash -n "$EDM_STATE" && pass "T32 AC8 -- bin/edm-state passes bash -n" \
  || fail "T32 AC8 -- bin/edm-state failed bash -n"
jq -e . "$STATE_T32PV" >/dev/null 2>&1 && pass "T32 AC8 -- state file is valid JSON after every T32 write" \
  || fail "T32 AC8 -- state file is not valid JSON"

# ---- AC6 (existing callers, hooks/skill single-write path stays green) -----------------------
echo
echo "T32 AC6 -- wave4b-smoke.sh (existing PARTIAL-recording callers) stays green"
t32_wave4b_ec=0
t32_wave4b_out="$(bash "${SCRIPT_DIR}/wave4b-smoke.sh" 2>&1)" || t32_wave4b_ec=$?
[[ $t32_wave4b_ec -eq 0 ]] && pass "T32 AC6 -- wave4b-smoke.sh exits 0 (existing single-write callers unaffected)" \
  || fail "T32 AC6 -- wave4b-smoke.sh exited ${t32_wave4b_ec}"

# ---- Surfaced in --help -----------------------------------------------------------------
t32_help_lines="$("$EDM_STATE" --help 2>&1 | grep 'record-partial-verdict' || true)"
check "T32 -- the 'close' usage form is documented in --help" "close" "$t32_help_lines"

# =================================================================================
# EDMV3-T18: archive blocks unclosed PARTIALs and gains its wave-B sub-checks
# =================================================================================
echo
echo "T18 -- archive PARTIAL-closure check, audit-converged re-query, OPEN_PARTIALS anomaly, HANDOFF findings summary"

# ---- AC1: closed PARTIAL entry shape (closing_verdict/closed_at/verification_ref) --------
echo
echo "T18 AC1 -- closed PARTIAL entry shape carries all three closure keys"
"$EDM_STATE" init T18SHAPE >/dev/null
"$EDM_STATE" record-partial-verdict T18SHAPE T18SHAPE-T01 PARTIAL "needs runtime check" >/dev/null
"$EDM_STATE" record-partial-verdict T18SHAPE T18SHAPE-T01 close PASS "post-deploy/verification.md#t18shape-t01" >/dev/null
STATE_T18SHAPE="$TMP/SRD/T18SHAPE/.edm-state.json"
jq -e '.partial_verdict_map["T18SHAPE-T01"] | has("closing_verdict") and has("closed_at") and has("verification_ref")' \
  "$STATE_T18SHAPE" >/dev/null \
  && pass "T18 AC1 -- closed PARTIAL entry has closing_verdict, closed_at, verification_ref" \
  || fail "T18 AC1 -- closed PARTIAL entry is missing one of the three closure keys"
t18shape_ref="$(jq -r '.partial_verdict_map["T18SHAPE-T01"].verification_ref' "$STATE_T18SHAPE")"
check "T18 AC1 -- verification_ref points at a post-deploy/verification.md section" \
  "post-deploy/verification.md#" "$t18shape_ref"

# ---- Shared helper: bring an initiative to phase 6 with an approved, converged code-audit
# gate over a clean, full-round ledger (schema_version stamped 2 so the wave-B checks below
# are fully enforced rather than degraded). ------------------------------------------------
t18_seed_converged() {
  local prefix="$1"
  edm-init --product demo --description "t18-${prefix}" "$prefix" >/dev/null
  local dir state
  dir="$(edm-state resolve-dir "$prefix")"
  state="${dir}/.edm-state.json"
  jq '.schema_version = 2' "$state" > "${state}.tmp" && mv "${state}.tmp" "$state"
  edm-state approve-gate "$prefix" 1 >/dev/null
  edm-state approve-gate "$prefix" 2 >/dev/null
  edm-state approve-gate "$prefix" 3 >/dev/null
  mkdir -p "${dir}/code-audit"
  printf '%s\n' '{"id":"CA-900","sev":"P2","status":"fixed","title":"t18 fixture fixed finding"}' \
    > "${dir}/code-audit/findings-ledger.jsonl"
  jq '.audit_rounds.code = {count: 1, rounds: [{round_type: "full", lenses: ["L1","L2","L3","L4","L5","L6","L7","L8","L9","L10","L11"]}]}' \
    "$state" > "${state}.tmp" && mv "${state}.tmp" "$state"
  edm-state approve-gate "$prefix" code-audit >/dev/null
  jq '.current_phase = 6 | .phase_durations["6_phase"] = {started_at: "2026-01-01T00:00:00Z", completed_at: "2026-01-01T01:00:00Z"}' \
    "$state" > "${state}.tmp" && mv "${state}.tmp" "$state"
}

# ---- AC2: archive refuses with an open (unclosed) PARTIAL --------------------------------
echo
echo "T18 AC2 -- archive refuses with an open PARTIAL, naming verify-runtime and no override"
t18_ac2_case() {
  t18_seed_converged T18OPN
  edm-state record-partial-verdict T18OPN T18OPN-T01 PARTIAL "needs retry-logic runtime check" >/dev/null
  check_fails "T18 AC2 -- archive refuses with an open PARTIAL" \
    "verify-runtime" \
    edm-state archive T18OPN
  check_fails "T18 AC2 -- refusal names the open ticket" \
    "t18opn-t01" \
    edm-state archive T18OPN
  check_refuses_and_leaves_state "T18 AC2 -- refusal states no override exists" "no override exists" "$(edm-state resolve-dir T18OPN)/.edm-state.json" edm-state archive T18OPN
}
with_scratch_repo t18_ac2_case

# ---- AC3: archive refuses with a FAIL-closed PARTIAL --------------------------------------
echo
echo "T18 AC3 -- archive refuses with a FAIL-closed PARTIAL (no third closure verdict)"
t18_ac3_case() {
  t18_seed_converged T18FLC
  edm-state record-partial-verdict T18FLC T18FLC-T01 PARTIAL "needs retry-logic runtime check" >/dev/null
  edm-state record-partial-verdict T18FLC T18FLC-T01 close FAIL "post-deploy/verification.md#t18flc-t01" >/dev/null
  check_fails "T18 AC3 -- archive refuses with a FAIL-closed PARTIAL" \
    "verify-runtime" \
    edm-state archive T18FLC
  check_fails "T18 AC3 -- refusal names the FAIL-closed ticket" \
    "t18flc-t01" \
    edm-state archive T18FLC
}
with_scratch_repo t18_ac3_case

# ---- AC4: archive succeeds when every PARTIAL entry is PASS-closed ------------------------
echo
echo "T18 AC4 -- archive succeeds once every PARTIAL entry is PASS-closed"
t18_ac4_case() {
  t18_seed_converged T18PSC
  edm-state record-partial-verdict T18PSC T18PSC-T01 PARTIAL "needs retry-logic runtime check" >/dev/null
  edm-state record-partial-verdict T18PSC T18PSC-T01 close PASS "post-deploy/verification.md#t18psc-t01" >/dev/null
  edm-state archive T18PSC >/dev/null \
    && pass "T18 AC4 -- archive succeeds with all PARTIALs PASS-closed" \
    || fail "T18 AC4 -- archive was refused despite every PARTIAL being PASS-closed"
}
with_scratch_repo t18_ac4_case

# ---- AC5: audit-converged re-query corroborates (or contradicts) the cached boolean -------
echo
echo "T18 AC5 -- archive re-queries audit-converged rather than trusting the cached boolean alone"
t18_ac5_case() {
  t18_seed_converged T18RCK
  local dir; dir="$(edm-state resolve-dir T18RCK)"
  # A late-arriving blocking finding is appended to the ledger AFTER the code-audit gate was
  # already approved -- the cached code_audit_converged boolean is stale (still true), but a
  # fresh ledger re-query must catch it.
  printf '%s\n' '{"id":"CA-901","sev":"P0","status":"open","title":"late-arriving blocking finding"}' \
    >> "${dir}/code-audit/findings-ledger.jsonl"
  check_refuses_and_leaves_state "T18 AC5 -- archive refuses when the audit-converged re-query exits 1" "CA-901" "${dir}/.edm-state.json" edm-state archive T18RCK

  # Remove the late finding -- the re-query now exits 0 and archive proceeds.
  printf '%s\n' '{"id":"CA-900","sev":"P2","status":"fixed","title":"t18 fixture fixed finding"}' \
    > "${dir}/code-audit/findings-ledger.jsonl"
  edm-state archive T18RCK >/dev/null \
    && pass "T18 AC5 -- archive proceeds once the audit-converged re-query exits 0" \
    || fail "T18 AC5 -- archive still refused after the ledger re-query would have exited 0"
}
with_scratch_repo t18_ac5_case

# ---- AC6 (historical three-valued degradation -- G2/CA-333, round 6, removed this
# degradation): both wave-B archive sub-checks (PARTIAL-closure, audit-converged re-query) used
# to warn-and-proceed for BOTH legacy (no schema_version) and schema_version:1 initiatives.
# G2/CA-333 found this environmentally unreachable in the shipped default (every initiative the
# current plugin creates sits at schema_version 1 forever) and made both checks run
# UNCONDITIONALLY -- the same fix class as CA-182's cmd_approve_gate precheck. The
# "skipping PARTIAL-closure check" / "skipping audit-converged re-query" strings no longer
# exist anywhere in bin/edm-state; a genuine open PARTIAL now refuses archive regardless of
# schema_version, legacy included.
echo
echo "T18 AC6 -- legacy and schema_version:1 initiatives now fully enforce both wave-B checks (G2/CA-333: no longer degraded)"
check_absent "T18 AC6/G2/CA-333 -- the retired 'skipping PARTIAL-closure check' string no longer appears anywhere in bin/edm-state" \
  "skipping PARTIAL-closure check" "$(cat "${SCRIPT_DIR}/../edm-state")"
check_absent "T18 AC6/G2/CA-333 -- the retired 'skipping audit-converged re-query' string no longer appears anywhere in bin/edm-state" \
  "skipping audit-converged re-query" "$(cat "${SCRIPT_DIR}/../edm-state")"
check "T18 AC6/G2/CA-333 -- legacy (no schema_version) archive now refuses on the open PARTIAL rather than warning and proceeding" \
  "unclosed or FAIL-closed PARTIAL verdict" "$t14leg_arch_out"
[[ $t14leg_arch_ec -ne 0 ]] && pass "T18 AC6/G2/CA-333 -- legacy archive now refuses (degradation removed)" \
  || fail "T18 AC6/G2/CA-333 -- legacy archive unexpectedly succeeded despite the open PARTIAL (exit $t14leg_arch_ec)"
t14mid_arch_ec=0
t14mid_arch_out="$("$EDM_STATE" archive T14MIDDLE 2>&1)" || t14mid_arch_ec=$?
check "T18 AC6/G2/CA-333 -- schema_version 1 archive now refuses on the open PARTIAL rather than warning and proceeding" \
  "unclosed or FAIL-closed PARTIAL verdict" "$t14mid_arch_out"
[[ $t14mid_arch_ec -ne 0 ]] && pass "T18 AC6/G2/CA-333 -- schema_version 1 archive now refuses (the degradation that made this environmentally unreachable is gone)" \
  || fail "T18 AC6/G2/CA-333 -- schema_version 1 archive unexpectedly succeeded despite the open PARTIAL (exit $t14mid_arch_ec)"

# ---- G2/CA-333 compensating control: re-run `edm-state validate` against this SAME
# schema_version:1 fixture with one open PARTIAL and confirm the OPEN_PARTIALS anomaly (never
# schema-gated -- its own comment in bin/edm-state states the underlying partial_verdict_map
# predates schema_version entirely) still fires -- it is the compensating control the
# REMEDIATION plan named as the reason this was P1 rather than P0, and it must not regress now
# that archive/phase-complete enforce the same fact directly. ------------------------------
t14mid_validate_ec=0
t14mid_validate_out="$("$EDM_STATE" validate T14MIDDLE 2>&1)" || t14mid_validate_ec=$?
check "G2/CA-333 compensating control -- OPEN_PARTIALS still fires for the schema_version:1 fixture" \
  "blocking  OPEN_PARTIALS  partial_verdict_map" "$t14mid_validate_out"
check "G2/CA-333 compensating control -- OPEN_PARTIALS names the open ticket" \
  "T14MIDDLE-T01" "$t14mid_validate_out"
[[ $t14mid_validate_ec -eq 3 ]] && pass "G2/CA-333 compensating control -- validate exits 3 (blocking class) for the schema_version:1 open-PARTIAL fixture" \
  || fail "G2/CA-333 compensating control -- validate exited $t14mid_validate_ec, expected 3"

# ---- G2/CA-333 secondary site: cmd_audit_converged's "unknown round_type" refusal was
# likewise unreachable at schema_version:1 (the same class as the two checks above); now
# unconditional, degrading only when NO round has ever been recorded for this audit type
# (genuinely-absent data), never on the schema_version number. -----------------------------
echo
echo "G2/CA-333 -- cmd_audit_converged's unknown-round-type refusal is unconditional (no longer schema-gated)"
t14aud_case() {
  local scratch
  scratch="$(mktemp -d "${TMP}/edm-g2-audconv.XXXXXX")" || { fail "G2/CA-333 audit-converged -- mktemp failed"; return 1; }
  mkdir -p "${scratch}/SRD/T14AUDCONV/code-audit"
  printf '%s\n' '{"id":"CA-1","status":"open","sev":"P1","title":"x"}' \
    > "${scratch}/SRD/T14AUDCONV/code-audit/findings-ledger.jsonl"
  jq -n '{prefix: "T14AUDCONV", schema_version: 1, last_updated: "2020-01-01T00:00:00Z"}' \
    > "${scratch}/SRD/T14AUDCONV/.edm-state.json"

  # Case 1: no audit_rounds.code entry recorded at all (genuinely-absent data) -- must WARN and
  # proceed to the real blocking-set computation (not die on the round-type gate itself).
  local out1 ec1=0
  out1="$(EDM_SRD_ROOT="${scratch}/SRD" "$EDM_STATE" audit-converged T14AUDCONV 2>&1)" || ec1=$?
  check "G2/CA-333 -- no recorded round warns rather than refusing on the round-type gate" \
    "no code-audit round has ever been recorded" "$out1"
  check_absent "G2/CA-333 -- no recorded round does not hit the round-type refusal message" \
    "has an unknown round_type" "$out1"

  # Case 2: a round WAS recorded but omitted round_type (real ambiguity) -- must refuse,
  # regardless of schema_version being only 1.
  jq '.audit_rounds = {"code": {"count": 1, "rounds": [{"completed_at": "2026-01-01T00:00:00Z"}]}}' \
    "${scratch}/SRD/T14AUDCONV/.edm-state.json" > "${scratch}/SRD/T14AUDCONV/.edm-state.json.tmp" \
    && mv "${scratch}/SRD/T14AUDCONV/.edm-state.json.tmp" "${scratch}/SRD/T14AUDCONV/.edm-state.json"
  local out2 ec2=0
  out2="$(EDM_SRD_ROOT="${scratch}/SRD" "$EDM_STATE" audit-converged T14AUDCONV 2>&1)" || ec2=$?
  check "G2/CA-333 -- a recorded round with no round_type refuses, naming the round-type gate" \
    "has an unknown round_type" "$out2"
  [[ $ec2 -ne 0 ]] && pass "G2/CA-333 -- schema_version 1 with a real ambiguous round now refuses (no longer environmentally unreachable)" \
    || fail "G2/CA-333 -- schema_version 1 with an ambiguous round unexpectedly exited 0 (exit $ec2)"

  rm -rf "$scratch"
}
t14aud_case

# ---- AC7: OPEN_PARTIALS anomaly in the canonical four-field format ------------------------
echo
echo "T18 AC7 -- OPEN_PARTIALS anomaly fires in the canonical four-field format"
"$EDM_STATE" init T18ANOM >/dev/null
"$EDM_STATE" record-partial-verdict T18ANOM T18ANOM-T01 PARTIAL "needs runtime check" >/dev/null
set +e
t18anom_ec=0
t18anom_out="$("$EDM_STATE" validate T18ANOM 2>&1)" || t18anom_ec=$?
set -e
check "T18 AC7 -- OPEN_PARTIALS anomaly present in canonical four-field format" \
  "blocking  OPEN_PARTIALS  partial_verdict_map" "$t18anom_out"
check "T18 AC7 -- OPEN_PARTIALS names the open ticket" \
  "T18ANOM-T01" "$t18anom_out"
[[ $t18anom_ec -eq 3 ]] && pass "T18 AC7 -- OPEN_PARTIALS is class blocking (validate exits 3)" \
  || fail "T18 AC7 -- validate exited $t18anom_ec, expected 3"

# ---- AC8: HANDOFF renders an open-findings summary sourced from findings-ledger.jsonl -----
echo
echo "T18 AC8 -- HANDOFF renders an open-findings summary from findings-ledger.jsonl when present"
"$EDM_STATE" init T18FINDINGS >/dev/null
mkdir -p "$TMP/SRD/T18FINDINGS/code-audit"
printf '%s\n' '{"id":"CA-950","sev":"P1","status":"open","title":"needs remediation before archive"}' \
  > "$TMP/SRD/T18FINDINGS/code-audit/findings-ledger.jsonl"
"$EDM_STATE" write-handoff T18FINDINGS >/dev/null
t18findings_handoff="$(cat "$TMP/SRD/T18FINDINGS/HANDOFF.md")"
check "T18 AC8 -- HANDOFF renders the Open Code-Audit Findings section" \
  "## Open Code-Audit Findings" "$t18findings_handoff"
check "T18 AC8 -- HANDOFF names the open blocking finding" \
  "CA-950" "$t18findings_handoff"

"$EDM_STATE" init T18NOLEDGER >/dev/null
"$EDM_STATE" write-handoff T18NOLEDGER >/dev/null
t18noledger_handoff="$(cat "$TMP/SRD/T18NOLEDGER/HANDOFF.md")"
check_absent "T18 AC8 -- HANDOFF omits the findings section entirely when no ledger exists (absence is authoritative)" \
  "## Open Code-Audit Findings" "$t18noledger_handoff"

# =================================================================================
# G15/CA-353 (round 6): a ledger-error diagnostic (invalid JSONL) must never render verbatim
# under HANDOFF's "Open Code-Audit Findings" heading as if it were the findings summary --
# `_write_handoff_body` used to merge cmd_audit_converged's stdout and stderr with `2>&1`, so
# an "invalid JSONL" stderr diagnostic rendered identically to a real blocking-findings list.
# =================================================================================
echo
echo "G15/CA-353 -- a malformed findings-ledger.jsonl renders a distinct 'unavailable' row, not the raw diagnostic"
"$EDM_STATE" init T18BADLEDGER >/dev/null
mkdir -p "$TMP/SRD/T18BADLEDGER/code-audit"
printf '%s\n' 'not valid json at all {{{' \
  > "$TMP/SRD/T18BADLEDGER/code-audit/findings-ledger.jsonl"
"$EDM_STATE" write-handoff T18BADLEDGER >/dev/null
t18badledger_handoff="$(cat "$TMP/SRD/T18BADLEDGER/HANDOFF.md")"
check "G15/CA-353 -- HANDOFF still renders the Open Code-Audit Findings heading" \
  "## Open Code-Audit Findings" "$t18badledger_handoff"
check_absent "G15/CA-353 -- the raw 'invalid JSONL' diagnostic never appears in the rendered HANDOFF" \
  "invalid JSONL" "$t18badledger_handoff"
check "G15/CA-353 -- a distinct labeled 'unavailable' row is rendered instead" \
  "- **Open findings**: unavailable (ledger error; run edm-state audit-converged T18BADLEDGER)" \
  "$t18badledger_handoff"

# ---- AC9 (preserve): HANDOFF still auto-regenerates, Notes preserved, ASCII-only ----------
echo
echo "T18 AC9 -- HANDOFF regeneration/ASCII/Notes preservation unaffected (wave5-smoke.sh, edm-lint-artifacts)"
t18_wave5_ec=0
t18_wave5_out="$(bash "${SCRIPT_DIR}/wave5-smoke.sh" 2>&1)" || t18_wave5_ec=$?
[[ $t18_wave5_ec -eq 0 ]] && pass "T18 AC9 -- wave5-smoke.sh stays green" \
  || fail "T18 AC9 -- wave5-smoke.sh exited ${t18_wave5_ec}"
t18_lint_ec=0
t18_lint_out="$(bash "${SCRIPT_DIR}/../edm-lint-artifacts" --all 2>&1)" || t18_lint_ec=$?
[[ $t18_lint_ec -eq 0 ]] && pass "T18 AC9 -- edm-lint-artifacts --all exits 0" \
  || fail "T18 AC9 -- edm-lint-artifacts --all failed (exit ${t18_lint_ec}): ${t18_lint_out}"

# ---- AC10: no --accept-partials (or any) override flag exists on archive -----------------
echo
echo "T18 AC10 -- archive --accept-partials is an unknown argument (no override exists)"
check_fails "T18 AC10 -- archive --accept-partials is refused as a usage error" \
  "usage: edm-state archive" \
  "$EDM_STATE" archive T18ANOM --accept-partials

# ---- AC11: bypass matrix's unclosed-PARTIAL case (T16 AC4 placeholder, now filled in) -----
echo
echo "T18 AC11 -- bypass matrix: archive with an unclosed PARTIAL"
t18_ac11_case() {
  t18_seed_converged T18BYP
  edm-state record-partial-verdict T18BYP T18BYP-T01 PARTIAL "needs retry-logic runtime check" >/dev/null
  check_refuses_and_leaves_state "must-fail: T18 AC11 -- bypass matrix: archive with an unclosed PARTIAL refuses" "verify-runtime" "$(edm-state resolve-dir T18BYP)/.edm-state.json" edm-state archive T18BYP
}
with_scratch_repo t18_ac11_case

# =================================================================================
# EDMV3-T41: CLAUDE.md by-name references verified NOT to resolve from an installed cache
# (negative branch) -- generated docs/canonical-sections.md + byte-identity guard.
#
# Note on suite placement: the ticket's own Target Components name
# plugins/edm/bin/tests/wave7-smoke.sh for the AC5 byte-identity case. This wave's file-
# ownership split assigns wave6-smoke.sh (not wave7-smoke.sh) to the agent implementing T41, so
# the equivalent case is implemented here instead -- same assertion, different suite file.
# =================================================================================
echo
echo "T41 -- generated docs/canonical-sections.md is byte-identical to CLAUDE.md and CI-guarded"

SYNC_BIN="${SCRIPT_DIR}/../edm-sync-canonical-sections"
CANONICAL_SECTIONS_MD="${REPO_ROOT}/plugins/edm/docs/canonical-sections.md"

# ---- AC4: the generated file exists under docs/ with the required header -----------------
echo
echo "T41 AC4 -- generated docs/canonical-sections.md exists with the 'generated from CLAUDE.md' header"
[[ -f "$CANONICAL_SECTIONS_MD" ]] \
  && pass "T41 AC4 -- plugins/edm/docs/canonical-sections.md exists" \
  || fail "T41 AC4 -- plugins/edm/docs/canonical-sections.md not found"
check "T41 AC4 -- header names 'generated from CLAUDE.md'" \
  "generated from CLAUDE.md" "$(cat "$CANONICAL_SECTIONS_MD" 2>/dev/null)"
check "T41 AC4 -- generated file carries the Severity vocabulary section" \
  "## Severity vocabulary (canonical)" "$(cat "$CANONICAL_SECTIONS_MD" 2>/dev/null)"
check "T41 AC4 -- generated file carries the Mermaid diagram conventions section" \
  "## Mermaid diagram conventions (canonical)" "$(cat "$CANONICAL_SECTIONS_MD" 2>/dev/null)"

# ---- AC5: byte-identity guard -- committed copy matches a fresh --check run, and a hand-edit
# to the copy (without re-running the generator) is caught. ---------------------------------
echo
echo "T41 AC5 -- byte-identity guard: committed copy matches CLAUDE.md; a hand-edit fails"
bash "$SYNC_BIN" --check >/dev/null 2>&1 \
  && pass "T41 AC5 -- committed docs/canonical-sections.md is in sync with CLAUDE.md (--check exits 0)" \
  || fail "T41 AC5 -- committed docs/canonical-sections.md is OUT OF SYNC with CLAUDE.md"

T41_CANONICAL="$CANONICAL_SECTIONS_MD"
T41_BACKUP="$(mktemp "${TMP}/t41-canonical.XXXXXX")"
cp "$CANONICAL_SECTIONS_MD" "$T41_BACKUP"
printf '\nhand-edited, not regenerated\n' >> "$CANONICAL_SECTIONS_MD"
set +e
bash "$SYNC_BIN" --check >/dev/null 2>&1
t41_check_ec=$?
set -e
[[ $t41_check_ec -ne 0 ]] \
  && pass "T41 AC5 -- hand-editing the copy without regenerating makes --check fail" \
  || fail "T41 AC5 -- --check did not catch a hand-edit to the generated copy"
cp "$T41_BACKUP" "$CANONICAL_SECTIONS_MD"
rm -f "$T41_BACKUP"
T41_BACKUP=""
bash "$SYNC_BIN" --check >/dev/null 2>&1 \
  && pass "T41 AC5 -- restoring the generated copy makes --check pass again" \
  || fail "T41 AC5 -- --check still failing after restoring the generated copy"

# ---- AC5 (continued): the extracted section text is byte-identical to its CLAUDE.md source,
# not merely present -- diff the two sections directly rather than trusting --check alone. ---
echo
echo "T41 AC5 -- extracted sections diff byte-identical against their CLAUDE.md source spans"
t41_claude_md="${REPO_ROOT}/plugins/edm/CLAUDE.md"
t41_sev_src="$(awk '/^## Severity vocabulary \(canonical\)$/{f=1;print;next} f && /^## /{exit} f{print}' "$t41_claude_md")"
t41_sev_dst="$(awk '/^## Severity vocabulary \(canonical\)$/{f=1;print;next} f && /^## /{exit} f{print}' "$CANONICAL_SECTIONS_MD")"
[[ "$t41_sev_src" == "$t41_sev_dst" ]] \
  && pass "T41 AC5 -- Severity vocabulary section is byte-identical between CLAUDE.md and the generated copy" \
  || fail "T41 AC5 -- Severity vocabulary section diverged between CLAUDE.md and the generated copy"
t41_mmd_src="$(awk '/^## Mermaid diagram conventions \(canonical\)$/{f=1;print;next} f && /^## /{exit} f{print}' "$t41_claude_md")"
t41_mmd_dst="$(awk '/^## Mermaid diagram conventions \(canonical\)$/{f=1;print;next} f && /^## /{exit} f{print}' "$CANONICAL_SECTIONS_MD")"
[[ "$t41_mmd_src" == "$t41_mmd_dst" ]] \
  && pass "T41 AC5 -- Mermaid diagram conventions section is byte-identical between CLAUDE.md and the generated copy" \
  || fail "T41 AC5 -- Mermaid diagram conventions section diverged between CLAUDE.md and the generated copy"

# ---- AC2/AC6: the resolvability finding, install method, Claude Code version and date are
# recorded in decisions.md as D22, naming which branch (negative) was taken. ------------------
echo
echo "T41 AC2/AC6 -- decisions.md records the resolution finding (D22) and states the branch taken"
DECISIONS_MD="${REPO_ROOT}/SRD/edm/EDMV3__prompt-streamline/decisions.md"
check "T41 AC2 -- decisions.md names the check performed" \
  "CLAUDE.md by-name reference resolution" "$(cat "$DECISIONS_MD" 2>/dev/null)"
t41_d22_line="$(grep -n 'CLAUDE.md by-name reference resolution' "$DECISIONS_MD" | head -1)"
check "T41 AC2 -- D22 entry names a Claude Code version" \
  "2.1.220" "$t41_d22_line"
check "T41 AC2 -- D22 entry names the install method checked" \
  "installed cache" "$t41_d22_line"
check "T41 AC6 -- D22 entry states the negative branch was taken" \
  "negative" "$t41_d22_line"

# =================================================================================
# EDMV3-T50: phase-complete 6 is actually called.
# AC1/AC2/AC3/AC4/AC5 wire skills/orchestrator, skills/implement and skills/code-audit SKILL.md --
# the skills-side sweep, landed here. AC8 is already covered by T12 AC3 above ("archive without
# terminal completed_at refuses"). AC6 and AC7 are pure edm-state behaviour and are covered below.
# =================================================================================

# ---- AC1 (positive, single owner): the orchestrator's Phase 6 entry invokes /edm:verify-runtime
# via the Skill tool and then calls phase-complete 6, in that order. ---------------------------
echo
echo "T50 AC1 -- orchestrator's Phase 6 entry invokes verify-runtime via the Skill tool, then phase-complete 6"
ORCH_T50="${PLUGIN_DIR}/skills/orchestrator/SKILL.md"
t50ac1_vr_line="$(grep -n '/edm:verify-runtime' "$ORCH_T50" | head -1 | cut -d: -f1)"
t50ac1_pc_line="$(grep -n 'phase-complete <PREFIX> 6' "$ORCH_T50" | head -1 | cut -d: -f1)"
[[ -n "$t50ac1_vr_line" && -n "$t50ac1_pc_line" && "$t50ac1_vr_line" -le "$t50ac1_pc_line" ]] \
  && pass "T50 AC1 -- verify-runtime Skill invocation precedes phase-complete 6 (lines ${t50ac1_vr_line} <= ${t50ac1_pc_line})" \
  || fail "T50 AC1 -- expected verify-runtime line <= phase-complete line, got vr=${t50ac1_vr_line:-absent} pc=${t50ac1_pc_line:-absent}"
check "T50 AC1 -- orchestrator invokes verify-runtime" \
  "invoke \`/edm:verify-runtime <PREFIX>\`" "$(cat "$ORCH_T50")"
check "T50 AC1 -- orchestrator's Phase 6 entry names the Skill tool" \
  "via the \`Skill\`" "$(cat "$ORCH_T50")"

# ---- AC2 (negative, implement does not close the phase): Declare Done ends after the exec
# report and states ownership belongs to the orchestrator; no Skill grant to chain verify-runtime. ---
echo
echo "T50 AC2 -- implement/SKILL.md does not close Phase 6 itself and carries no Skill grant"
IMPL_T50="${PLUGIN_DIR}/skills/implement/SKILL.md"
check "T50 AC2 -- Step 8 states Phase 6 closure belongs to the orchestrator, not this skill" \
  "Phase 6 is closed by the orchestrator" "$(cat "$IMPL_T50")"
check_absent "T50 AC2 -- Operational Orchestration list no longer instructs phase-complete 6 as an owned step" \
  "9. \`edm-state phase-complete" "$(cat "$IMPL_T50")"
t50ac2_skill_grant="$(grep -n '^allowed-tools:' "$IMPL_T50" | grep -c 'Skill' || true)"
[[ "${t50ac2_skill_grant:-0}" -eq 0 ]] \
  && pass "T50 AC2 -- implement/SKILL.md's allowed-tools line carries no Skill grant" \
  || fail "T50 AC2 -- allowed-tools line unexpectedly grants Skill"

# ---- AC3 (negative, code-audit does not either): the responsibility lives in exactly one place. --
echo
echo "T50 AC3 -- code-audit/SKILL.md never calls phase-complete"
t50ac3_hits="$(grep -rl 'phase-complete' "${PLUGIN_DIR}/skills/code-audit/" 2>/dev/null | wc -l | tr -d ' ' || true)"
[[ "${t50ac3_hits:-0}" -eq 0 ]] \
  && pass "T50 AC3 -- code-audit/SKILL.md contains no phase-complete call" \
  || fail "T50 AC3 -- found phase-complete reference(s) in skills/code-audit/"

# ---- AC4 (exactly one call site, asserted): exactly one file owns the automatic call
# (orchestrator); the other two matches (implement, verify-runtime) are the T37 AC6-documented
# direct-invocation restatements for users who never run the orchestrator (AC5). ----------------
echo
echo "T50 AC4 -- exactly one owning phase-complete 6 call site, plus the two documented direct-invocation restatements"
t50ac4_total="$(grep -rl 'phase-complete <PREFIX> 6' "${PLUGIN_DIR}/skills/"*/SKILL.md 2>/dev/null | wc -l | tr -d ' ' || true)"
t50ac4_owner="$(grep -rl 'single owner of that call' "${PLUGIN_DIR}/skills/"*/SKILL.md 2>/dev/null | wc -l | tr -d ' ' || true)"
[[ "${t50ac4_total:-0}" -eq 3 && "${t50ac4_owner:-0}" -eq 1 ]] \
  && pass "T50 AC4 -- exactly one owning call site (orchestrator) plus two documented direct-invocation restatements" \
  || fail "T50 AC4 -- total files=${t50ac4_total} (expected 3), owner markers=${t50ac4_owner} (expected 1)"

# ---- AC5 (ordering, direct-invocation path): implement Step 8 and README.md state the
# two-command sequence for users who never run the orchestrator. --------------------------------
echo
echo "T50 AC5 -- direct-invocation path: implement Step 8 and README.md state the two-command sequence"
check "T50 AC5 -- implement/SKILL.md states the verify-runtime call" \
  "/edm:verify-runtime <PREFIX>" "$(cat "$IMPL_T50")"
check "T50 AC5 -- implement/SKILL.md states phase-complete 6" \
  "phase-complete <PREFIX> 6" "$(cat "$IMPL_T50")"
check "T50 AC5 -- README.md command table states phase-complete 6" \
  "phase-complete <PREFIX> 6" "$(cat "${PLUGIN_DIR}/README.md")"

# ---- AC6 (ordering precondition): phase-complete 6 succeeds once qc-summary.md exists, i.e.
# EDMV3-T11's artifact check passes rather than refuses -- the invariant the orchestrator's
# Phase 6 ordering (verify-runtime, then phase-complete 6, called after qc-summary.md is
# written) depends on. -------------------------------------------------------------------------
echo
echo "T50 AC6 -- orchestrator Phase 6 ordering: qc-summary exists before phase-complete 6"
"$EDM_STATE" init T50ORDER >/dev/null
"$EDM_STATE" approve-gate T50ORDER 1 >/dev/null
"$EDM_STATE" approve-gate T50ORDER 2 >/dev/null
"$EDM_STATE" approve-gate T50ORDER 3 >/dev/null
"$EDM_STATE" phase-start T50ORDER 6 >/dev/null
mkdir -p "$TMP/SRD/T50ORDER/qc"
echo "# QC Summary" > "$TMP/SRD/T50ORDER/qc/qc-summary.md"
t50order_ec=0
t50order_out="$("$EDM_STATE" phase-complete T50ORDER 6 2>&1)" || t50order_ec=$?
[[ $t50order_ec -eq 0 ]] \
  && pass "T50 AC6 -- orchestrator Phase 6 ordering: qc-summary exists before phase-complete 6" \
  || fail "T50 AC6 -- phase-complete 6 refused despite qc-summary.md present: $t50order_out"

# ---- AC7 (behavioural, the number is non-zero): a scratch run with a staged session JSONL
# fixture produces non-zero duration_seconds and estimated_cost_usd for 6_phase -- the exact
# figure the EDMV2 defect (D9) left at 0s/$0.00. -------------------------------------------------
echo
echo "T50 AC7 -- phase 6 duration_seconds and estimated_cost_usd are non-zero after a real run"
T50_HOME="$(mktemp -d "${TMP}/t50-home.XXXXXX")"
T50_CWD="$(mktemp -d "${TMP}/t50-cwd.XXXXXX")"
T50_PREV_HOME="${HOME:-}"
T50_PREV_PWD="$(pwd)"
cd "$T50_CWD"
export HOME="$T50_HOME"
T50_SESS_DIR="$(session_dir_for_test_cwd)"
"$EDM_STATE" init T50PH6 >/dev/null
"$EDM_STATE" approve-gate T50PH6 1 >/dev/null
"$EDM_STATE" approve-gate T50PH6 2 >/dev/null
"$EDM_STATE" approve-gate T50PH6 3 >/dev/null
"$EDM_STATE" phase-start T50PH6 6 >/dev/null
sleep 1
# Staged AFTER phase-start: get_session_tokens_since filters on timestamp >= started_at, so a
# fixture timestamped before phase-start would be (correctly) excluded.
stage_session_jsonl "$T50_SESS_DIR" "session-1.jsonl" "claude-sonnet-4-6-20260601" 1000 500
mkdir -p "$TMP/SRD/T50PH6/qc"
echo "# QC Summary" > "$TMP/SRD/T50PH6/qc/qc-summary.md"
"$EDM_STATE" phase-complete T50PH6 6 >/dev/null
t50_dur="$(jq -r '.phase_durations["6_phase"].duration_seconds' "$TMP/SRD/T50PH6/.edm-state.json")"
t50_cost="$(jq -r '.phase_durations["6_phase"].estimated_cost_usd' "$TMP/SRD/T50PH6/.edm-state.json")"
[[ "$t50_dur" -gt 0 ]] 2>/dev/null \
  && pass "T50 AC7 -- phase 6 duration_seconds > 0 (${t50_dur}s)" \
  || fail "T50 AC7 -- duration_seconds = '$t50_dur', expected > 0"
awk -v c="$t50_cost" 'BEGIN{exit !(c>0)}' \
  && pass "T50 AC7 -- phase 6 estimated_cost_usd > 0 (\$${t50_cost})" \
  || fail "T50 AC7 -- estimated_cost_usd = '$t50_cost', expected > 0"
cd "$T50_PREV_PWD"
export HOME="$T50_PREV_HOME"
rm -rf "$T50_HOME" "$T50_CWD"

# =================================================================================
# EDMV3-T51: per-round audit cost is captured (audit-round-complete)
# AC2 and AC8 are grep-verified directly below (not a smoke-test case). AC1/AC4/AC5/AC6/AC7/AC9/AC10
# are covered here. AC3 (skills/code-audit/SKILL.md calling audit-round-complete after
# render-ledger) is asserted immediately below.
# =================================================================================

# ---- AC3 (called at the right point): skills/code-audit/SKILL.md calls audit-round-complete
# at the end of each round, after the synthesizer returns and the ledger is rendered. -----------
echo
echo "T51 AC3 -- code-audit/SKILL.md calls audit-round-complete after render-ledger"
CODE_AUDIT_SKILL_T51="${PLUGIN_DIR}/skills/code-audit/SKILL.md"
t51ac3_rl_line="$(grep -n 'edm-state render-ledger' "$CODE_AUDIT_SKILL_T51" | head -1 | cut -d: -f1)"
t51ac3_arc_line="$(grep -n 'edm-state audit-round-complete' "$CODE_AUDIT_SKILL_T51" | head -1 | cut -d: -f1)"
[[ -n "$t51ac3_rl_line" && -n "$t51ac3_arc_line" && "$t51ac3_rl_line" -lt "$t51ac3_arc_line" ]] \
  && pass "T51 AC3 -- audit-round-complete call (line ${t51ac3_arc_line}) follows render-ledger call (line ${t51ac3_rl_line})" \
  || fail "T51 AC3 -- expected render-ledger line < audit-round-complete line, got rl=${t51ac3_rl_line:-absent} arc=${t51ac3_arc_line:-absent}"

# ---- AC1 (positive): records completion timestamp, duration, tokens and cost, keyed by
# audit type and round number. ------------------------------------------------------------------
echo
echo "T51 AC1 -- audit-round-complete records duration, tokens and cost for the round"
T51_HOME="$(mktemp -d "${TMP}/t51-home.XXXXXX")"
T51_CWD="$(mktemp -d "${TMP}/t51-cwd.XXXXXX")"
T51_PREV_HOME="${HOME:-}"
T51_PREV_PWD="$(pwd)"
cd "$T51_CWD"
export HOME="$T51_HOME"
T51_SESS_DIR="$(session_dir_for_test_cwd)"
"$EDM_STATE" init T51ROUND >/dev/null
STATE_T51ROUND="$TMP/SRD/T51ROUND/.edm-state.json"
"$EDM_STATE" audit-round-start T51ROUND code >/dev/null
sleep 1
stage_session_jsonl "$T51_SESS_DIR" "session-1.jsonl" "claude-sonnet-4-6-20260601" 2000 800
t51_complete_out="$("$EDM_STATE" audit-round-complete T51ROUND code 2>&1)"
t51_dur="$(jq -r '.audit_rounds.code.rounds[-1].duration_seconds' "$STATE_T51ROUND")"
t51_cost="$(jq -r '.audit_rounds.code.rounds[-1].estimated_cost_usd' "$STATE_T51ROUND")"
[[ "$t51_dur" -gt 0 ]] 2>/dev/null \
  && pass "T51 AC1 -- round duration_seconds > 0 (${t51_dur}s)" \
  || fail "T51 AC1 -- round duration_seconds = '$t51_dur', expected > 0 (output: $t51_complete_out)"
awk -v c="$t51_cost" 'BEGIN{exit !(c>0)}' \
  && pass "T51 AC1 -- round estimated_cost_usd > 0 (\$${t51_cost})" \
  || fail "T51 AC1 -- round estimated_cost_usd = '$t51_cost', expected > 0"
check "T51 AC1 -- round completed_at recorded" \
  "true" "$(jq -r '.audit_rounds.code.rounds[-1].completed_at != null' "$STATE_T51ROUND")"

# ---- AC4/AC5 (negative, an unclosed round is visible as an info anomaly): audit-round-start
# with no matching audit-round-complete surfaces OPEN_AUDIT_ROUND, informational only. ---------
echo
echo "T51 AC4/AC5 -- unclosed audit round surfaces OPEN_AUDIT_ROUND (info, does not fail validate)"
"$EDM_STATE" init T51OPEN >/dev/null
"$EDM_STATE" set T51OPEN estimated_size Small >/dev/null   # suppress SIZE_UNKNOWN noise
"$EDM_STATE" audit-round-start T51OPEN srd >/dev/null
t51open_ec=0
t51open_validate_out="$("$EDM_STATE" validate T51OPEN 2>&1)" || t51open_ec=$?
check "T51 AC4 -- OPEN_AUDIT_ROUND anomaly present, canonical four-field format" \
  "info  OPEN_AUDIT_ROUND  audit_rounds" "$t51open_validate_out"
[[ $t51open_ec -eq 0 ]] \
  && pass "T51 AC5 -- OPEN_AUDIT_ROUND is informational; validate still exits 0" \
  || fail "T51 AC5 -- validate exited $t51open_ec with only an OPEN_AUDIT_ROUND anomaly present"

# ---- AC6 (metrics surface): metrics-report renders a per-round section only once a round has
# completed. --------------------------------------------------------------------------------
echo
echo "T51 AC6 -- metrics-report renders per-round cost only once a round has completed"
mr_before_complete="$("$EDM_STATE" metrics-report T51OPEN 2>&1)"
check_absent "T51 AC6 -- no per-round section before any round completes" \
  "per-round" "$mr_before_complete"
sleep 1
stage_session_jsonl "$T51_SESS_DIR" "session-2.jsonl" "claude-sonnet-4-6-20260601" 500 200
"$EDM_STATE" audit-round-complete T51OPEN srd >/dev/null
mr_after_complete="$("$EDM_STATE" metrics-report T51OPEN 2>&1)"
check "T51 AC6 -- per-round section present once a round completes" \
  "per-round" "$mr_after_complete"
check "T51 AC6 -- per-round section names 'rounds run'" \
  "rounds run" "$mr_after_complete"

cd "$T51_PREV_PWD"
export HOME="$T51_PREV_HOME"
rm -rf "$T51_HOME" "$T51_CWD"

# ---- AC7 (C-4): legacy state files with rounds recorded but no completions render without
# error -- both the pre-widening bare-integer shape and the post-widening {count, rounds}
# shape with no completed round. ---------------------------------------------------------------
echo
echo "T51 AC7 -- legacy audit_rounds shapes render via metrics-report without error"
"$EDM_STATE" init T51LEGACY1 >/dev/null
STATE_T51LEGACY1="$TMP/SRD/T51LEGACY1/.edm-state.json"
jq '.audit_rounds = {"code": 3}' "$STATE_T51LEGACY1" > "$STATE_T51LEGACY1.tmp" && mv "$STATE_T51LEGACY1.tmp" "$STATE_T51LEGACY1"
set +e
t51legacy1_ec=0
t51legacy1_out="$("$EDM_STATE" metrics-report T51LEGACY1 2>&1)" || t51legacy1_ec=$?
set -e
[[ $t51legacy1_ec -eq 0 ]] \
  && pass "T51 AC7 -- bare-integer legacy audit_rounds.code renders via metrics-report without error" \
  || fail "T51 AC7 -- metrics-report exited $t51legacy1_ec on bare-integer legacy shape: $t51legacy1_out"

"$EDM_STATE" init T51LEGACY2 >/dev/null
STATE_T51LEGACY2="$TMP/SRD/T51LEGACY2/.edm-state.json"
jq '.audit_rounds = {code: {count: 1, rounds: [{round: 1, lenses: [], round_type: "full", started_at: "2026-07-01T00:00:00Z"}]}}' \
  "$STATE_T51LEGACY2" > "$STATE_T51LEGACY2.tmp" && mv "$STATE_T51LEGACY2.tmp" "$STATE_T51LEGACY2"
set +e
t51legacy2_ec=0
t51legacy2_out="$("$EDM_STATE" metrics-report T51LEGACY2 2>&1)" || t51legacy2_ec=$?
set -e
[[ $t51legacy2_ec -eq 0 ]] \
  && pass "T51 AC7 -- started-but-never-completed round renders via metrics-report without error" \
  || fail "T51 AC7 -- metrics-report exited $t51legacy2_ec on an unclosed round: $t51legacy2_out"
check_absent "T51 AC7 -- no per-round section for a round with no completion" \
  "per-round" "$t51legacy2_out"

# ---- AC9 (negative, double completion): completing a round twice refuses, names the existing
# completion, and mutates nothing. --------------------------------------------------------------
echo
echo "T51 AC9 -- second audit-round-complete refused, naming the existing completion"
"$EDM_STATE" init T51DBL >/dev/null
STATE_T51DBL="$TMP/SRD/T51DBL/.edm-state.json"
"$EDM_STATE" audit-round-start T51DBL tickets >/dev/null
"$EDM_STATE" audit-round-complete T51DBL tickets >/dev/null
check_refuses_and_leaves_state "T51 AC9 -- second audit-round-complete refuses, naming the existing completion" "already completed" "$STATE_T51DBL" "$EDM_STATE" audit-round-complete T51DBL tickets

# ---- AC10 (atomicity and bash 3.2): bash -n passes; state is valid JSON after a double
# invocation (the lock serializes what a true concurrent pair of invocations would race on;
# this exercises the identical write path). ------------------------------------------------------
echo
echo "T51 AC10 -- bash -n passes; state remains valid JSON after a double invocation"
bash -n "$EDM_STATE" \
  && pass "T51 AC10 -- bin/edm-state passes bash -n" \
  || fail "T51 AC10 -- bin/edm-state failed bash -n"
jq -e . "$STATE_T51DBL" >/dev/null 2>&1 \
  && pass "T51 AC10 -- state file is valid JSON after a double audit-round-complete invocation" \
  || fail "T51 AC10 -- state file is not valid JSON after a double audit-round-complete invocation"

# =================================================================================
# EDMV3-T52: token attribution and the pricing table become honest
# =================================================================================

# ---- AC4 (behavioural, either branch): two synthetic session JSONL files in the sessions
# directory -- an older, unrelated one and the driving one -- and get_session_tokens_since
# (via phase-complete) scopes to the driving (most-recently-modified) session only. -----------
echo
echo "T52 AC4 -- two synthetic sessions produce the documented attribution"
T52_HOME="$(mktemp -d "${TMP}/t52-home.XXXXXX")"
T52_CWD="$(mktemp -d "${TMP}/t52-cwd.XXXXXX")"
T52_PREV_HOME="${HOME:-}"
T52_PREV_PWD="$(pwd)"
cd "$T52_CWD"
export HOME="$T52_HOME"
T52_SESS_DIR="$(session_dir_for_test_cwd)"
"$EDM_STATE" init T52ATTR >/dev/null
"$EDM_STATE" approve-gate T52ATTR 1 >/dev/null
"$EDM_STATE" approve-gate T52ATTR 2 >/dev/null
"$EDM_STATE" approve-gate T52ATTR 3 >/dev/null
"$EDM_STATE" phase-start T52ATTR 6 >/dev/null
sleep 1
# Older, unrelated concurrent session -- a second Claude Code window on the same project.
stage_session_jsonl "$T52_SESS_DIR" "session-old.jsonl" "claude-sonnet-4-7-20260701" 100000 50000
sleep 1
# The driving session -- staged last, so it is the most-recently-modified file.
stage_session_jsonl "$T52_SESS_DIR" "session-driving.jsonl" "claude-sonnet-4-7-20260701" 1000 500
mkdir -p "$TMP/SRD/T52ATTR/qc"
echo "# QC Summary" > "$TMP/SRD/T52ATTR/qc/qc-summary.md"
"$EDM_STATE" phase-complete T52ATTR 6 >/dev/null
STATE_T52ATTR="$TMP/SRD/T52ATTR/.edm-state.json"
t52_attr_mode="$(jq -r '.phase_durations["6_phase"].attribution_mode' "$STATE_T52ATTR")"
case "$t52_attr_mode" in
  scoped|whole-directory)
    pass "T52 AC2 -- attribution_mode is scoped or whole-directory (${t52_attr_mode})"
    ;;
  *)
    fail "T52 AC2 -- attribution_mode was '${t52_attr_mode}', expected scoped or whole-directory"
    ;;
esac
t52_input="$(jq -r '.phase_durations["6_phase"].tokens.input' "$STATE_T52ATTR")"
if [[ "$t52_attr_mode" == "scoped" ]]; then
  [[ "$t52_input" -eq 1000 ]] \
    && pass "T52 AC4 -- scoped attribution: input tokens = 1000 (driving session only, not 101000)" \
    || fail "T52 AC4 -- scoped attribution recorded input=$t52_input, expected 1000 (the old concurrent session leaked in)"
else
  [[ "$t52_input" -eq 101000 ]] \
    && pass "T52 AC4 -- whole-directory fallback records the honest 101000 input total" \
    || fail "T52 AC4 -- whole-directory fallback recorded input=$t52_input, expected 101000"
fi
cd "$T52_PREV_PWD"
export HOME="$T52_PREV_HOME"
rm -rf "$T52_HOME" "$T52_CWD"

# ---- G10 (round-3 Wave 7c remediation): a torn/truncated session-JSONL line must not leak a
# third value into attribution_mode -- it stays a strict scoped|whole-directory enum, and the
# parse-failure count surfaces separately as unparseable_lines / the informational
# TORN_TOKEN_LINES anomaly. -----------------------------------------------------------------------
echo
echo "G10 -- a torn JSONL line keeps attribution_mode two-valued and is counted separately"
G10_HOME="$(mktemp -d "${TMP}/g10-home.XXXXXX")"
G10_CWD="$(mktemp -d "${TMP}/g10-cwd.XXXXXX")"
G10_PREV_HOME="${HOME:-}"
G10_PREV_PWD="$(pwd)"
cd "$G10_CWD"
export HOME="$G10_HOME"
G10_SESS_DIR="$(session_dir_for_test_cwd)"
"$EDM_STATE" init G10TORN >/dev/null
"$EDM_STATE" approve-gate G10TORN 1 >/dev/null
"$EDM_STATE" approve-gate G10TORN 2 >/dev/null
"$EDM_STATE" approve-gate G10TORN 3 >/dev/null
"$EDM_STATE" phase-start G10TORN 6 >/dev/null
sleep 1
# One well-formed line, then a deliberately truncated line (no closing brace/quote) that fails
# fromjson?, then a second well-formed line -- exercises the reduce loop's .bad accumulator with
# real, not synthetic-count, torn input.
stage_session_jsonl "$G10_SESS_DIR" "session-driving.jsonl" "claude-sonnet-4-7-20260701" 200 100
printf '%s\n' '{"type":"assistant","timestamp":"2026-08-08T00:00:00Z","message":{model' \
  >> "${G10_SESS_DIR}/session-driving.jsonl"
jq -cn --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '
  {type:"assistant", timestamp:$ts, message:{model:"claude-sonnet-4-7-20260701",
   usage:{input_tokens:50,output_tokens:25,cache_read_input_tokens:0,
          cache_creation:{ephemeral_5m_input_tokens:0,ephemeral_1h_input_tokens:0}}}}
' >> "${G10_SESS_DIR}/session-driving.jsonl"
mkdir -p "$TMP/SRD/G10TORN/qc"
echo "# QC Summary" > "$TMP/SRD/G10TORN/qc/qc-summary.md"
"$EDM_STATE" phase-complete G10TORN 6 >/dev/null
STATE_G10TORN="$TMP/SRD/G10TORN/.edm-state.json"
g10_attr_mode="$(jq -r '.phase_durations["6_phase"].attribution_mode' "$STATE_G10TORN")"
case "$g10_attr_mode" in
  scoped|whole-directory)
    pass "G10 -- attribution_mode stayed a documented two-value enum despite the torn line (${g10_attr_mode})"
    ;;
  *)
    fail "G10 -- attribution_mode was '${g10_attr_mode}', expected scoped or whole-directory (never a third value)"
    ;;
esac
g10_unparseable="$(jq -r '.phase_durations["6_phase"].unparseable_lines' "$STATE_G10TORN")"
[[ "$g10_unparseable" == "1" ]] \
  && pass "G10 -- unparseable_lines recorded exactly 1 for the single torn line" \
  || fail "G10 -- unparseable_lines = '$g10_unparseable', expected 1"
g10_input="$(jq -r '.phase_durations["6_phase"].tokens.input' "$STATE_G10TORN")"
if [[ "$g10_attr_mode" == "scoped" ]]; then
  [[ "$g10_input" -eq 250 ]] \
    && pass "G10 -- scoped attribution still sums the two well-formed lines (input=250), skipping only the torn one" \
    || fail "G10 -- scoped attribution recorded input=$g10_input, expected 250"
fi
g10_validate_out="$("$EDM_STATE" validate G10TORN 2>&1)"
check "G10 -- edm-state validate reports TORN_TOKEN_LINES" "TORN_TOKEN_LINES" "$g10_validate_out"
check "G10 -- TORN_TOKEN_LINES is informational, not blocking" "info  TORN_TOKEN_LINES" "$g10_validate_out"
g10_validate_ec=0
"$EDM_STATE" validate G10TORN >/dev/null 2>&1 || g10_validate_ec=$?
[[ "$g10_validate_ec" -eq 0 ]] \
  && pass "G10 -- TORN_TOKEN_LINES alone does not flip validate's exit code" \
  || fail "G10 -- edm-state validate exited ${g10_validate_ec} on TORN_TOKEN_LINES alone, expected 0"
cd "$G10_PREV_PWD"
export HOME="$G10_PREV_HOME"
rm -rf "$G10_HOME" "$G10_CWD"

# ---- AC9 (positive, previous-generation model_used renders a non-zero cost): both a direct
# compute_cost_usd call and a full phase-complete run with a previous-generation model in the
# staged session JSONL. -------------------------------------------------------------------------
echo
echo "T52 AC9 -- previous-generation model_used renders a non-zero cost"
t52_prevgen_cost="$(call_edm_helper compute_cost_usd "claude-opus-4-7-20260201" 1000000 0 0 0 0)"
awk -v c="$t52_prevgen_cost" 'BEGIN{exit !(c>0)}' \
  && pass "T52 AC9 -- compute_cost_usd on a previous-generation opus identifier is non-zero (\$${t52_prevgen_cost})" \
  || fail "T52 AC9 -- compute_cost_usd on a previous-generation opus identifier = '$t52_prevgen_cost', expected > 0"
t52_prevgen_opus_output="$(call_edm_helper compute_cost_usd "claude-opus-4-7-20260201" 0 1000000 0 0 0)"
t52_prevgen_opus_override="$(EDM_OPUS_OUTPUT_RATE=999 call_edm_helper compute_cost_usd "claude-opus-4-7-20260201" 0 1000000 0 0 0)"
[[ "$t52_prevgen_opus_output" == "25.0000" && "$t52_prevgen_opus_override" == "25.0000" ]] \
  && pass "T52 AC9 -- previous-generation opus output rate stays frozen at 25.0000 even when EDM_OPUS_OUTPUT_RATE is set" \
  || fail "T52 AC9 -- previous-generation opus output rate drifted (default=${t52_prevgen_opus_output}, override=${t52_prevgen_opus_override})"
t52_prevgen_sonnet_output="$(call_edm_helper compute_cost_usd "claude-sonnet-4-6-20260201" 0 1000000 0 0 0)"
t52_prevgen_sonnet_override="$(EDM_SONNET_OUTPUT_RATE=999 call_edm_helper compute_cost_usd "claude-sonnet-4-6-20260201" 0 1000000 0 0 0)"
[[ "$t52_prevgen_sonnet_output" == "15.0000" && "$t52_prevgen_sonnet_override" == "15.0000" ]] \
  && pass "T52 AC9 -- previous-generation sonnet output rate stays frozen at 15.0000 even when EDM_SONNET_OUTPUT_RATE is set" \
  || fail "T52 AC9 -- previous-generation sonnet output rate drifted (default=${t52_prevgen_sonnet_output}, override=${t52_prevgen_sonnet_override})"
t52_prevgen_haiku_output="$(call_edm_helper compute_cost_usd "claude-haiku-4-5-20260201" 0 1000000 0 0 0)"
t52_prevgen_haiku_override="$(EDM_HAIKU_OUTPUT_RATE=999 call_edm_helper compute_cost_usd "claude-haiku-4-5-20260201" 0 1000000 0 0 0)"
[[ "$t52_prevgen_haiku_output" == "5.0000" && "$t52_prevgen_haiku_override" == "5.0000" ]] \
  && pass "T52 AC9 -- previous-generation haiku output rate stays frozen at 5.0000 even when EDM_HAIKU_OUTPUT_RATE is set" \
  || fail "T52 AC9 -- previous-generation haiku output rate drifted (default=${t52_prevgen_haiku_output}, override=${t52_prevgen_haiku_override})"

T52B_HOME="$(mktemp -d "${TMP}/t52b-home.XXXXXX")"
T52B_CWD="$(mktemp -d "${TMP}/t52b-cwd.XXXXXX")"
T52B_PREV_HOME="${HOME:-}"
T52B_PREV_PWD="$(pwd)"
cd "$T52B_CWD"
export HOME="$T52B_HOME"
T52B_SESS_DIR="$(session_dir_for_test_cwd)"
"$EDM_STATE" init T52PREVGEN >/dev/null
"$EDM_STATE" approve-gate T52PREVGEN 1 >/dev/null
"$EDM_STATE" approve-gate T52PREVGEN 2 >/dev/null
"$EDM_STATE" approve-gate T52PREVGEN 3 >/dev/null
"$EDM_STATE" phase-start T52PREVGEN 6 >/dev/null
sleep 1
stage_session_jsonl "$T52B_SESS_DIR" "session-1.jsonl" "claude-opus-4-7-20260201" 1000 500
mkdir -p "$TMP/SRD/T52PREVGEN/qc"
echo "# QC Summary" > "$TMP/SRD/T52PREVGEN/qc/qc-summary.md"
"$EDM_STATE" phase-complete T52PREVGEN 6 >/dev/null
t52_prevgen_recorded_cost="$(jq -r '.phase_durations["6_phase"].estimated_cost_usd' "$TMP/SRD/T52PREVGEN/.edm-state.json")"
awk -v c="$t52_prevgen_recorded_cost" 'BEGIN{exit !(c>0)}' \
  && pass "T52 AC9 -- a real phase-complete run with a previous-generation model_used records a non-zero cost (\$${t52_prevgen_recorded_cost})" \
  || fail "T52 AC9 -- recorded cost = '$t52_prevgen_recorded_cost', expected > 0"
cd "$T52B_PREV_PWD"
export HOME="$T52B_PREV_HOME"
rm -rf "$T52B_HOME" "$T52B_CWD"

# ---- AC10 (negative, unknown model warns rather than costing zero) ----------------------------
echo
echo "T52 AC10 -- unknown in-family generations warn and use the Sonnet placeholder cost"
t52_unknown_stderr="$(call_edm_helper compute_cost_usd "claude-opus-5-20260501" 1000000 0 0 0 0 2>&1 1>/dev/null)"
t52_unknown_cost="$(call_edm_helper compute_cost_usd "claude-opus-5-20260501" 1000000 0 0 0 0 2>/dev/null)"
check "T52 AC10 -- unrecognized model_used emits an explicit warning naming the model" \
  "claude-opus-5-20260501" "$t52_unknown_stderr"
check "T52 AC10 -- warning text says WARNING" "WARNING" "$t52_unknown_stderr"
[[ "$t52_unknown_cost" == "4.0000" ]] \
  && pass "T52 AC10 -- unknown generation uses the documented Sonnet placeholder cost (\$${t52_unknown_cost})" \
  || fail "T52 AC10 -- unknown generation cost = '$t52_unknown_cost', expected 4.0000"
# The pre-existing "unknown" sentinel (no session data at all) stays silent -- a real zero, not
# an unrecognized-model silent zero.
t52_sentinel_stderr="$(call_edm_helper compute_cost_usd "unknown" 0 0 0 0 0 2>&1 1>/dev/null)"
check_absent "T52 AC10 -- the pre-existing 'unknown' no-session sentinel does not warn" \
  "WARNING" "$t52_sentinel_stderr"

# ---- AC8 (override mechanism preserved): current-generation env var overrides still work. -----
echo
echo "T52 AC8 -- the environment-variable override mechanism is preserved"
t52_override_cost="$(EDM_OPUS_INPUT_RATE=99 call_edm_helper compute_cost_usd "claude-opus-4-8-20260701" 1000000 0 0 0 0)"
[[ "$t52_override_cost" == "99.0000" ]] \
  && pass "T52 AC8 -- EDM_OPUS_INPUT_RATE=99 override reflected in compute_cost_usd (\$${t52_override_cost})" \
  || fail "T52 AC8 -- EDM_OPUS_INPUT_RATE=99 override produced '$t52_override_cost', expected 99.0000"

# ---- AC1 (the choice is recorded) ----------------------------------------------------------
echo
echo "T52 AC1 -- decisions.md names the branch taken and the function comment states the mechanism"
DECISIONS_MD_T52="${REPO_ROOT}/SRD/edm/EDMV3__prompt-streamline/decisions.md"
check "T52 AC1 -- decisions.md names the token attribution decision" \
  "token attribution" "$(cat "$DECISIONS_MD_T52" 2>/dev/null)"
t52_d23_line="$(grep -n 'token attribution' "$DECISIONS_MD_T52" | head -1)"
check "T52 AC1 -- D23 entry names branch (a)" \
  "Branch (a)" "$t52_d23_line"
# Extract the comment block by content, not by absolute line range. This assertion used to be
# `sed -n '226,246p'`, which silently pointed at unrelated lines the moment anything was inserted
# above it -- it broke when a security guard was added near the top of bin/edm-state, and it could
# equally have passed against text that happened to contain the needle. Anchor on the function the
# comment documents and read the contiguous comment block immediately above it.
t52_ac1_block="$(awk '
  /^get_session_tokens_since\(\)/ { for (i = 1; i <= n; i++) print buf[i]; exit }
  /^#/ { buf[++n] = $0; next }
  { n = 0 }
' "$EDM_STATE")"
check "T52 AC1 -- get_session_tokens_since's comment block documents the driving-session mechanism" \
  "driving session" "$t52_ac1_block"
[[ -n "$t52_ac1_block" ]] \
  && pass "T52 AC1 -- the comment block was located by anchor (extraction is not vacuous)" \
  || fail "T52 AC1 -- no comment block found above get_session_tokens_since; the anchor is wrong, so the assertion above proves nothing"

# =================================================================================
# EDMV3-T53: the human-baseline ROI table leaves default output; metrics reflect tiering
# AC4 (skills/metrics/SKILL.md no longer presents the human-baseline comparison as a
# headline) is a SKILL.md edit out of scope this batch (T37/T38 dispatcher refactor owns
# that file); reported as blocked-on-skills-owner. AC7's wave5-smoke.sh re-baseline is a
# regression fix, not a new case here. AC6 (plugin.json description) already verified below.
# =================================================================================

echo
echo "T53 AC1 -- default metrics-report output has no human-baseline comparison or multiple"
"$EDM_STATE" init T53DEFAULT >/dev/null
"$EDM_STATE" phase-start T53DEFAULT 1 >/dev/null
echo "planning notes" > "$TMP/SRD/T53DEFAULT/planning.md"
"$EDM_STATE" phase-complete T53DEFAULT 1 >/dev/null
t53_default_out="$("$EDM_STATE" metrics-report T53DEFAULT 2>&1)"
t53_default_hits=0
printf '%s' "$t53_default_out" | grep -qi 'baseline\|multiple\|savings' && t53_default_hits=1
[[ "$t53_default_hits" -eq 0 ]] \
  && pass "T53 AC1 -- default output contains none of baseline/multiple/savings" \
  || fail "T53 AC1 -- default output unexpectedly mentions baseline/multiple/savings: $t53_default_out"

echo
echo "T53 AC2 -- human_baseline_usd continues to be recorded in state (data not lost)"
check "T53 AC2 -- human_baseline_usd recorded on phase 1 despite not being shown by default" \
  "true" "$(jq -r '.phase_durations["1_phase"].human_baseline_usd != null' "$TMP/SRD/T53DEFAULT/.edm-state.json")"

echo
echo "T53 AC3 -- --with-human-baseline opt-in view states the estimate caveat"
t53_baseline_out="$("$EDM_STATE" metrics-report T53DEFAULT --with-human-baseline 2>&1)"
check "T53 AC3 -- --with-human-baseline renders the human-baseline comparison" \
  "Human baseline" "$t53_baseline_out"
check "T53 AC3 -- --with-human-baseline states it is an estimate" \
  "estimate" "$(echo "$t53_baseline_out" | tr '[:upper:]' '[:lower:]')"

echo
echo "T53 AC6 -- plugin.json human_hourly_rate_usd description reflects the opt-in view"
check "T53 AC6 -- plugin.json description mentions the opt-in view" \
  "opt-in" "$(jq -r '.userConfig.human_hourly_rate_usd.description' "${REPO_ROOT}/plugins/edm/.claude-plugin/plugin.json")"

echo
echo "T53 AC8 -- metrics-report code-audit section names rounds run and lenses per round"
"$EDM_STATE" audit-round-start T53DEFAULT code >/dev/null
sleep 1
"$EDM_STATE" audit-round-complete T53DEFAULT code >/dev/null
t53_code_audit_out="$("$EDM_STATE" metrics-report T53DEFAULT 2>&1)"
check "T53 AC8 -- 'rounds run' present once a code-audit round completes" \
  "rounds run" "$t53_code_audit_out"
check "T53 AC8 -- 'lenses per round' present once a code-audit round completes" \
  "lenses per round" "$t53_code_audit_out"

echo
echo "T53 AC9 -- tiered-vs-untiered section omitted when no tiering data exists (T48 not landed)"
check_absent "T53 AC9 -- no 'Tiered vs Untiered' section without tiering_results data" \
  "Tiered vs Untiered" "$t53_default_out"

echo
echo "T53 AC10 -- --calibrate still works and now has Phase 6 data to calibrate against"
"$EDM_STATE" init T53CALIB >/dev/null
"$EDM_STATE" approve-gate T53CALIB 1 >/dev/null
"$EDM_STATE" approve-gate T53CALIB 2 >/dev/null
"$EDM_STATE" approve-gate T53CALIB 3 >/dev/null
"$EDM_STATE" set T53CALIB estimated_size Small >/dev/null
"$EDM_STATE" phase-start T53CALIB 6 >/dev/null
sleep 1
mkdir -p "$TMP/SRD/T53CALIB/qc"
echo "# QC Summary" > "$TMP/SRD/T53CALIB/qc/qc-summary.md"
"$EDM_STATE" phase-complete T53CALIB 6 >/dev/null
set +e
t53_calib_ec=0
t53_calib_out="$("$EDM_STATE" metrics-report --calibrate 2>&1)" || t53_calib_ec=$?
set -e
[[ $t53_calib_ec -eq 0 ]] \
  && pass "T53 AC10 -- --calibrate exits 0" \
  || fail "T53 AC10 -- --calibrate exited $t53_calib_ec: $t53_calib_out"
check "T53 AC10 -- --calibrate output references phase 6" \
  "Small_phase_6" "$t53_calib_out"

# =================================================================================
# G12/CA-261 (round 5, third pass): the row-count guard tested `estimated_size != null`,
# but init seeds the literal string "Unknown" (non-null), so every state file satisfied the
# guard regardless of whether estimated_size was ever really set -- and the guard never
# checked phase_durations at all, so when the true calibration-worthy dataset was empty,
# --calibrate printed a bare header with no fallback message at all, not even a wrong row
# (an empty phase_durations object naturally contributes zero rows to the renderer regardless
# of the size filter). Isolated in a scratch SRD_ROOT via with_scratch_repo -- this file's
# earlier T53 AC10 case has already given the SHARED SRD_ROOT a real Small/phase-6 row, so an
# un-isolated check here would see that unrelated data and could not observe the guard firing.
# =================================================================================
echo
echo "G12/CA-261 -- --calibrate's row-count guard correctly excludes the Unknown sentinel and requires real phase_durations"

g12_unknown_case() {
  "$EDM_STATE" init G12UNKNOWN >/dev/null
  local out
  out="$("$EDM_STATE" metrics-report --calibrate 2>&1)"
  check "G12/CA-261 -- an Unknown-sized, phase-less initiative alone yields insufficient data, not a bare empty header" \
    "insufficient data" "$out"
  check_absent "G12/CA-261 -- no Unknown_phase_* row is ever rendered" \
    "Unknown_phase" "$out"
}
with_scratch_repo g12_unknown_case

g12_empty_case() {
  "$EDM_STATE" init G12EMPTY >/dev/null
  "$EDM_STATE" set G12EMPTY estimated_size Medium >/dev/null
  local out
  out="$("$EDM_STATE" metrics-report --calibrate 2>&1)"
  check "G12/CA-261 -- a real-sized initiative with no completed phases still yields insufficient data (the residual this pass closes)" \
    "insufficient data" "$out"
  check_absent "G12/CA-261 -- no Medium_phase_* row is rendered with zero phase_durations" \
    "Medium_phase" "$out"
}
with_scratch_repo g12_empty_case

echo
echo "T53 AC11 -- metrics-report output stays ASCII-only and passes the artifact lint"
t53_lint_dir="${TMP}/SRD/T53DEFAULT"
"$EDM_STATE" metrics-report T53DEFAULT > "${t53_lint_dir}/metrics.md"
t53_nonascii="$(LC_ALL=C grep -n '[^ -~	]' "${t53_lint_dir}/metrics.md" || true)"
[[ -z "$t53_nonascii" ]] \
  && pass "T53 AC11 -- metrics-report output is ASCII-only" \
  || fail "T53 AC11 -- non-ASCII bytes found in metrics-report output: $t53_nonascii"

# =================================================================================
# CA-040 remediation (code-audit round 2): convergence_exempt coverage at both consumers
# =================================================================================
# CA-040 (P1): convergence_exempt() (bin/edm-state, cited by name per CA-315/G39 -- a line-range
# citation here had already gone stale) has zero test coverage at either
# consumer (cmd_archive, cmd_audit_converged) across the four mode/lifecycle_mode combinations
# that matter, and the deliberate asymmetry -- approve-gate code-audit stays refused under
# fast-track/fix-pack while archive and audit-converged treat it as convergence_exempt -- was
# entirely undocumented by a test. Writing this case is what surfaced CA-183: at schema_version
# >= 2, approve-gate's code-audit branch delegated straight to cmd_audit_converged, which shares
# convergence_exempt() with cmd_archive, so fast-track silently passed approve-gate too, exactly
# contradicting the asymmetry this section's own code comment already claimed -- now fixed.
echo
echo "=== CA-040 remediation: convergence_exempt at cmd_audit_converged and cmd_archive ==="

# Every case below uses "$EDM_STATE" init (flat layout, state-only) rather than the edm-init
# wrapper script -- edm-init also does a real `git checkout -b` against whatever repository
# this suite happens to run inside (T01's branch handshake), which has no place in a state-only
# convergence_exempt() test and would otherwise leave stray branches in the enclosing repo.

# ---- audit-converged: mode=prototype (exempt regardless of lifecycle_mode) ---------------
"$EDM_STATE" init ZC40A >/dev/null
"$EDM_STATE" set-mode ZC40A mode prototype >/dev/null
ca040a_ec=0
ca040a_out="$("$EDM_STATE" audit-converged ZC40A 2>&1)" || ca040a_ec=$?
[[ $ca040a_ec -eq 0 ]] \
  && pass "CA-040 -- audit-converged exits 0 for mode=prototype (audit-free mode, AC8)" \
  || fail "CA-040 -- audit-converged did not exit 0 for mode=prototype (got $ca040a_ec: $ca040a_out)"
check "CA-040 -- audit-converged names the exemption for mode=prototype" \
  "no code audit is required" "$ca040a_out"

# ---- audit-converged: mode=standard, lifecycle_mode=fast-track (exempt via lifecycle) -----
"$EDM_STATE" init ZC40B >/dev/null
"$EDM_STATE" set-mode ZC40B mode standard >/dev/null
"$EDM_STATE" set-mode ZC40B lifecycle_mode fast-track >/dev/null
ca040b_state="$TMP/SRD/ZC40B/.edm-state.json"
jq '.schema_version = 2' "$ca040b_state" > "${ca040b_state}.tmp" && mv "${ca040b_state}.tmp" "$ca040b_state"
ca040b_ec=0
ca040b_out="$("$EDM_STATE" audit-converged ZC40B 2>&1)" || ca040b_ec=$?
[[ $ca040b_ec -eq 0 ]] \
  && pass "CA-040 -- audit-converged exits 0 for mode=standard/lifecycle_mode=fast-track" \
  || fail "CA-040 -- audit-converged did not exit 0 for fast-track (got $ca040b_ec: $ca040b_out)"

# ---- audit-converged: mode=standard, lifecycle_mode=fix-pack (exempt via lifecycle) -------
"$EDM_STATE" init ZC40C >/dev/null
"$EDM_STATE" set-mode ZC40C mode standard >/dev/null
"$EDM_STATE" set-mode ZC40C lifecycle_mode fix-pack >/dev/null
ca040c_ec=0
ca040c_out="$("$EDM_STATE" audit-converged ZC40C 2>&1)" || ca040c_ec=$?
[[ $ca040c_ec -eq 0 ]] \
  && pass "CA-040 -- audit-converged exits 0 for mode=standard/lifecycle_mode=fix-pack" \
  || fail "CA-040 -- audit-converged did not exit 0 for fix-pack (got $ca040c_ec: $ca040c_out)"

# ---- audit-converged: mode=standard, lifecycle_mode=standard (NOT exempt -- real check runs) --
"$EDM_STATE" init ZC40D >/dev/null
"$EDM_STATE" set-mode ZC40D mode standard >/dev/null
ca040d_ec=0
ca040d_out="$("$EDM_STATE" audit-converged ZC40D 2>&1)" || ca040d_ec=$?
[[ $ca040d_ec -eq 3 ]] \
  && pass "CA-040 -- audit-converged is NOT exempt for mode=standard/lifecycle_mode=standard (falls through to the real no-ledger check, exit 3)" \
  || fail "CA-040 -- expected exit 3 (no ledger, not exempt) for standard/standard, got $ca040d_ec: $ca040d_out"

# ---- archive: same four combinations, exercised via the shared convergence_exempt() ------
# archive has additional prerequisites (gates, terminal phase) unrelated to convergence_exempt,
# so these cases assert on the specific convergence clause rather than a bare exit code: a
# convergence-exempt combination must never cite code_audit_converged/findings-ledger in its
# refusal, while a non-exempt one must.
"$EDM_STATE" init ZC40E >/dev/null
"$EDM_STATE" set-mode ZC40E mode prototype >/dev/null
ca040e_out="$("$EDM_STATE" archive ZC40E 2>&1)" || true
check_absent "CA-040 -- archive's refusal for mode=prototype never cites the convergence gate (exempt)" \
  "code_audit_converged" "$ca040e_out"

"$EDM_STATE" init ZC40F >/dev/null
"$EDM_STATE" set-mode ZC40F mode standard >/dev/null
"$EDM_STATE" set-mode ZC40F lifecycle_mode fast-track >/dev/null
ca040f_out="$("$EDM_STATE" archive ZC40F 2>&1)" || true
check_absent "CA-040 -- archive's refusal for lifecycle_mode=fast-track never cites the convergence gate (exempt)" \
  "code_audit_converged" "$ca040f_out"

"$EDM_STATE" init ZC40G >/dev/null
"$EDM_STATE" set-mode ZC40G mode standard >/dev/null
"$EDM_STATE" set-mode ZC40G lifecycle_mode fix-pack >/dev/null
ca040g_out="$("$EDM_STATE" archive ZC40G 2>&1)" || true
check_absent "CA-040 -- archive's refusal for lifecycle_mode=fix-pack never cites the convergence gate (exempt)" \
  "code_audit_converged" "$ca040g_out"

"$EDM_STATE" init ZC40H >/dev/null
"$EDM_STATE" set-mode ZC40H mode standard >/dev/null
# Satisfy the gate/terminal-phase/completed_at prerequisites archive checks before it ever
# reaches the convergence clause this case targets (same shape as T08 AC6 above), so a
# not-exempt refusal is guaranteed to be ABOUT convergence, not an earlier prerequisite.
"$EDM_STATE" approve-gate ZC40H 1 >/dev/null
"$EDM_STATE" approve-gate ZC40H 2 >/dev/null
"$EDM_STATE" approve-gate ZC40H 3 >/dev/null
ca040h_state="$TMP/SRD/ZC40H/.edm-state.json"
jq '.current_phase = 6 | .phase_durations["6_phase"] = {started_at: "2026-01-01T00:00:00Z", completed_at: "2026-01-01T01:00:00Z"}' \
  "$ca040h_state" > "${ca040h_state}.tmp" && mv "${ca040h_state}.tmp" "$ca040h_state"
ca040h_out="$("$EDM_STATE" archive ZC40H 2>&1)" || true
check "CA-040 -- archive's refusal for mode=standard/lifecycle_mode=standard DOES reach the real convergence gate (not exempt)" \
  "code_audit_converged" "$ca040h_out"

# ---- CA-183: the deliberate asymmetry -- approve-gate code-audit stays refused under a
# convergence_exempt lifecycle_mode, even though archive/audit-converged both exempt it. -------
"$EDM_STATE" init ZC40I >/dev/null
"$EDM_STATE" set-mode ZC40I mode standard >/dev/null
"$EDM_STATE" set-mode ZC40I lifecycle_mode fast-track >/dev/null
ca040i_state="$TMP/SRD/ZC40I/.edm-state.json"
jq '.schema_version = 2' "$ca040i_state" > "${ca040i_state}.tmp" && mv "${ca040i_state}.tmp" "$ca040i_state"
check_fails "CA-183/CA-040 -- approve-gate code-audit still refuses under lifecycle_mode=fast-track, unlike archive/audit-converged" \
  "never exempts a lifecycle_mode" \
  "$EDM_STATE" approve-gate ZC40I code-audit
ca040i_converged="$(jq -r '.code_audit_converged' "$ca040i_state")"
[[ "$ca040i_converged" == "false" ]] \
  && pass "CA-183/CA-040 -- code_audit_converged stays false after the refused fast-track approve-gate attempt" \
  || fail "CA-183/CA-040 -- code_audit_converged was set to '${ca040i_converged}' despite the refusal -- gate bypass regression"
# CA-040 remediation end

# =================================================================================
# Code-audit round-2 remediation, Wave 4a: CA-026, CA-059, CA-061
# =================================================================================
echo
echo "CA-026 -- checkpoint sweep isolates a per-initiative failure instead of aborting the sweep"

# ---- CA-026: one initiative's checkpoint body failing does not abort the rest of the sweep -----
ca026_case() {
  "$EDM_STATE" init AAAABROKEN >/dev/null
  "$EDM_STATE" init ZZZZHEALTHY >/dev/null
  local broken_dir="SRD/AAAABROKEN" healthy_state="SRD/ZZZZHEALTHY/.edm-state.json"
  local healthy_before
  healthy_before="$(jq -r '.last_updated' "$healthy_state")"
  # G22 (round-3 Wave 7g-1): with_state_lock's mkdir branch now dies immediately on a real
  # permission error instead of spin-retrying for ~5 seconds before giving up -- a deliberate
  # speed improvement, but it means the whole init+checkpoint sequence below can now complete
  # within the SAME second-granularity now_utc() tick. Sleep past that tick so the "did
  # last_updated change" assertion below is not a coin flip on wall-clock timing.
  sleep 1

  # Force rmw_state (and therefore with_state_lock) to fail for AAAABROKEN specifically, from
  # INSIDE the checkpoint sweep's per-initiative body -- the exact failure surface CA-026 wraps
  # in a subshell. Root can bypass a directory's own write bit, so this sub-case is skipped
  # (not faked as a pass) when running as root.
  if [[ "$(id -u)" -eq 0 ]]; then
    echo "CA-026 -- skipping the permission-induced-failure sub-case: running as root, which bypasses the write-bit denial this case depends on"
  else
    chmod 555 "$broken_dir"
    local ckpt_out ckpt_ec=0
    ckpt_out="$("$EDM_STATE" checkpoint-if-active 2>&1)" || ckpt_ec=$?
    chmod 755 "$broken_dir"

    [[ $ckpt_ec -eq 0 ]] \
      && pass "CA-026 -- checkpoint-if-active itself exits 0 even though one initiative's body failed" \
      || fail "CA-026 -- checkpoint-if-active exited ${ckpt_ec}, expected 0 (a per-initiative failure must not propagate to the sweep's own exit code)"
    check "CA-026 -- the sweep names the failing initiative and continues rather than aborting silently" \
      "skipping AAAABROKEN" "$ckpt_out"

    local healthy_after
    healthy_after="$(jq -r '.last_updated' "$healthy_state")"
    [[ "$healthy_after" != "$healthy_before" ]] \
      && pass "CA-026 -- an initiative queued after the failing one in iteration order still gets checkpointed" \
      || fail "CA-026 -- healthy initiative's last_updated did not change (${healthy_before}) -- sweep aborted before reaching it"
  fi
}
with_scratch_repo ca026_case

# ---- CA-026: a state file whose .prefix disagrees with its own directory is skipped with a
# warning rather than causing a stray SRD/<other-prefix>/ directory to be created ----------------
ca026_mismatch_case() {
  "$EDM_STATE" init ZMISMATCH >/dev/null
  local state="SRD/ZMISMATCH/.edm-state.json"
  jq '.prefix = "SOMEOTHERPREFIX"' "$state" > "${state}.tmp" && mv "${state}.tmp" "$state"

  local ckpt_out ckpt_ec=0
  ckpt_out="$("$EDM_STATE" checkpoint-if-active 2>&1)" || ckpt_ec=$?
  check "CA-026 -- a prefix/directory mismatch is named and skipped rather than mutated" \
    "resolves to" "$ckpt_out"
  [[ ! -d "SRD/SOMEOTHERPREFIX" ]] \
    && pass "CA-026 -- no stray SRD/<other-prefix>/ directory was created for the mismatched entry" \
    || fail "CA-026 -- a stray SRD/SOMEOTHERPREFIX/ directory was created during the sweep"
}
with_scratch_repo ca026_mismatch_case

echo
echo "CA-059 -- record-partial-verdict close checks and writes under a single lock acquisition"

# ---- CA-059: two concurrent close calls on the same entry cannot both succeed as a first
# closure (the check-then-lock race the fix closes) -----------------------------------------------
ca059_case() {
  "$EDM_STATE" init T59RACE >/dev/null
  "$EDM_STATE" record-partial-verdict T59RACE T59RACE-T01 PARTIAL "needs runtime check" >/dev/null
  local state="SRD/T59RACE/.edm-state.json"
  local out1_file out2_file ec1=0 ec2=0
  out1_file="$(mktemp "${TMPDIR:-/tmp}/edm-ca059-1.XXXXXX")"
  out2_file="$(mktemp "${TMPDIR:-/tmp}/edm-ca059-2.XXXXXX")"

  "$EDM_STATE" record-partial-verdict T59RACE T59RACE-T01 close PASS "race-ref-pass" > "$out1_file" 2>&1 &
  local pid1=$!
  "$EDM_STATE" record-partial-verdict T59RACE T59RACE-T01 close FAIL "race-ref-fail" > "$out2_file" 2>&1 &
  local pid2=$!
  wait "$pid1" || ec1=$?
  wait "$pid2" || ec2=$?

  if { [[ $ec1 -eq 0 && $ec2 -ne 0 ]] || [[ $ec1 -ne 0 && $ec2 -eq 0 ]]; }; then
    pass "CA-059 -- exactly one of two concurrent close calls on the same entry succeeds (close-once invariant holds under race)"
  else
    fail "CA-059 -- expected exactly one success, got ec1=${ec1} ec2=${ec2} (both succeeding means the check-then-lock race landed; both failing means neither closed)"
  fi

  local loser_out
  if [[ $ec1 -ne 0 ]]; then loser_out="$(cat "$out1_file")"; else loser_out="$(cat "$out2_file")"; fi
  check "CA-059 -- the losing concurrent close call is refused, naming the existing closure" \
    "already closed" "$loser_out"

  jq -e . "$state" >/dev/null 2>&1 \
    && pass "CA-059 -- state file is valid JSON after the concurrent close race (no torn write)" \
    || fail "CA-059 -- state file is not valid JSON after the concurrent close race"

  local has_closure
  has_closure="$(jq -r '.partial_verdict_map["T59RACE-T01"] | has("closing_verdict")' "$state" 2>/dev/null || echo false)"
  [[ "$has_closure" == "true" ]] \
    && pass "CA-059 -- the entry carries a recorded closure after the race" \
    || fail "CA-059 -- the entry has no closing_verdict after the race"

  rm -f "$out1_file" "$out2_file"
}
with_scratch_repo ca059_case

# ---- CA-059: sequential proxy -- close once, then immediately close again with a different
# verdict; the second call must be refused, not silently accepted as a second first closure ------
ca059_sequential_case() {
  "$EDM_STATE" init T59SEQ >/dev/null
  "$EDM_STATE" record-partial-verdict T59SEQ T59SEQ-T01 PARTIAL "needs check" >/dev/null
  "$EDM_STATE" record-partial-verdict T59SEQ T59SEQ-T01 close PASS "first-ref" >/dev/null
  check_fails "CA-059 -- an immediate second close with a different verdict is refused, not accepted as a new first closure" \
    "already closed" "$EDM_STATE" record-partial-verdict T59SEQ T59SEQ-T01 close FAIL "second-ref"
  local closing
  closing="$(jq -r '.partial_verdict_map["T59SEQ-T01"].closing_verdict' "SRD/T59SEQ/.edm-state.json")"
  [[ "$closing" == "PASS" ]] \
    && pass "CA-059 -- the original PASS closure is preserved (not overwritten by the refused second call)" \
    || fail "CA-059 -- closing_verdict = '${closing}', expected PASS (the refused second call must not have mutated it)"
}
with_scratch_repo ca059_sequential_case

echo
echo "CA-061 -- gate-check's degraded-check recording short-circuits before taking the write lock"

# ---- CA-061: repeating an already-recorded degraded check does not rewrite the state file -------
ca061_case() {
  "$EDM_STATE" init T61DEGR >/dev/null
  local state="SRD/T61DEGR/.edm-state.json"
  jq 'del(.schema_version)' "$state" > "${state}.tmp" && mv "${state}.tmp" "$state"

  # First call: a genuinely new (check, reason) pair -- this call is expected to write.
  "$EDM_STATE" gate-check T61DEGR srd >/dev/null 2>&1 || true
  local hash_after_first
  hash_after_first="$(_harness_hash_file "$state")"

  # Second call: identical (check, reason) -- CA-061's short-circuit must skip rmw_state entirely.
  "$EDM_STATE" gate-check T61DEGR srd >/dev/null 2>&1 || true
  local hash_after_second
  hash_after_second="$(_harness_hash_file "$state")"

  [[ "$hash_after_first" == "$hash_after_second" ]] \
    && pass "CA-061 -- repeating an already-recorded degraded check does not rewrite the state file" \
    || fail "CA-061 -- state file hash changed on the second identical gate-check call (before: ${hash_after_first}, after: ${hash_after_second})"

  local degraded_count
  degraded_count="$(jq -r '.degraded_checks | length' "$state")"
  [[ "$degraded_count" == "1" ]] \
    && pass "CA-061 -- degraded_checks still records exactly one entry (idempotent content, not just an idempotent write-skip)" \
    || fail "CA-061 -- degraded_checks has ${degraded_count} entry/entries, expected 1"

  # A DIFFERENT (check, reason) pair for the same initiative must still be recorded -- the
  # short-circuit is keyed on the pair, not a blanket "never write again for this prefix".
  "$EDM_STATE" record-partial-verdict T61DEGR T61DEGR-T99 PARTIAL "unrelated" >/dev/null
  local hash_after_unrelated
  hash_after_unrelated="$(_harness_hash_file "$state")"
  [[ "$hash_after_unrelated" != "$hash_after_second" ]] \
    && pass "CA-061 -- an unrelated write still reaches the state file (the short-circuit only skips a repeated identical pair)" \
    || fail "CA-061 -- an unrelated write did not change the state file hash"
}
with_scratch_repo ca061_case

# ---- CA-061: static guard -- record_degraded_check reads state before calling rmw_state --------
t_ca061_body="$(awk '/^record_degraded_check\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"
check "CA-061 -- record_degraded_check short-circuits (reads and compares) before its rmw_state call" \
  "read_state" "$t_ca061_body"

# ---- Summary -----------------------------------------------------------------
echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
