#!/usr/bin/env bash
# wave6-smoke.sh -- EDMV3 Epic E2 (Enforcement kernel) wave-A smoke coverage.
# EDMV3-T05: state_anomalies info/blocking class split, cmd_validate exit contract.
# EDMV3-T07: terminal_phase_for_mode / required_gates_for_mode / code_audit_required_for_mode.
# Run from repo root: bash plugins/edm/bin/tests/wave6-smoke.sh
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
"$EDM_STATE" phase-complete ANOMFMT 1 >/dev/null
# EDMV3-T13: phase-start now kernel-enforces phase 2's prerequisite gate (gate 1).
"$EDM_STATE" approve-gate ANOMFMT 1 >/dev/null
"$EDM_STATE" phase-start ANOMFMT 2 >/dev/null
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
info_out="$("$EDM_STATE" validate ANOMFMT 2>&1)"
info_ec=$?
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
"$EDM_STATE" phase-complete ANOMBLK 1 >/dev/null
# Craft a TIME_ORDER fixture directly: completed_at earlier than started_at.
jq '.phase_durations["1_phase"].started_at = "2026-01-02T00:00:00Z"
    | .phase_durations["1_phase"].completed_at = "2026-01-01T00:00:00Z"' \
  "$STATE_ANOMBLK" > "$STATE_ANOMBLK.tmp" && mv "$STATE_ANOMBLK.tmp" "$STATE_ANOMBLK"

set +e
blk_out="$("$EDM_STATE" validate ANOMBLK 2>&1)"
blk_ec=$?
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
"$EDM_STATE" phase-complete ANOMBOTH 1 >/dev/null
# EDMV3-T13: phase-start now kernel-enforces phase 2's prerequisite gate (gate 1).
"$EDM_STATE" approve-gate ANOMBOTH 1 >/dev/null
"$EDM_STATE" phase-start ANOMBOTH 2 >/dev/null
"$EDM_STATE" phase-complete ANOMBOTH 2 >/dev/null
# estimated_size stays "Unknown" -> SIZE_UNKNOWN (info). Craft TIME_ORDER (blocking) too.
jq '.phase_durations["1_phase"].started_at = "2026-01-02T00:00:00Z"
    | .phase_durations["1_phase"].completed_at = "2026-01-01T00:00:00Z"' \
  "$STATE_ANOMBOTH" > "$STATE_ANOMBOTH.tmp" && mv "$STATE_ANOMBOTH.tmp" "$STATE_ANOMBOTH"

set +e
both_out="$("$EDM_STATE" validate ANOMBOTH 2>&1)"
both_ec=$?
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
"$EDM_STATE" phase-complete ANOMZT 1 >/dev/null
jq '.phase_durations["1_phase"].model_used = "claude-test"
    | .phase_durations["1_phase"].tokens.input = 0
    | .phase_durations["1_phase"].tokens.output = 0' \
  "$STATE_ANOMZT" > "$STATE_ANOMZT.tmp" && mv "$STATE_ANOMZT.tmp" "$STATE_ANOMZT"
set +e
zt_out="$("$EDM_STATE" validate ANOMZT 2>&1)"
zt_ec=$?
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

gates_out2="$(call_edm_helper required_gates_for_mode standard standard "1 3" | tr '\n' ' ')"
check "required_gates_for_mode(standard, standard, phases 1+3 skipped) = only gate 3" "3" "$gates_out2"
check_absent "gate 1 absent when its origin phase (1) is skipped" "1 " "$gates_out2 "

gates_out3="$(call_edm_helper required_gates_for_mode prototype standard "3 4 5 6" | tr '\n' ' ')"
check "required_gates_for_mode(prototype, standard, phases 3-6 skipped) = only gate 1 (phase 1 <= terminal 2)" "1" "$gates_out3"

gates_mini="$(call_edm_helper required_gates_for_mode mini-srd standard "2 4 5" | tr '\n' ' ')"
check "required_gates_for_mode(mini-srd, standard, phases 2/4/5 skipped) = only gate 1 (phase1, gates 2/3 origins skipped)" "1" "$gates_mini"

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
proto_hits="$(grep -c 'prototype)' "$EDM_STATE")"
[[ "$proto_hits" -eq 3 ]] && pass "exactly 3 'prototype)' sites in edm-state (single derivation)" \
  || fail "found $proto_hits 'prototype)' sites, expected exactly 3"

# ---- AC6: code_audit_required_for_mode has a definition + call site(s) -------
echo
echo "T07 AC6 -- code_audit_required_for_mode defined and consumed"
cadef_hits="$(grep -c 'code_audit_required_for_mode' "$EDM_STATE")"
[[ "$cadef_hits" -ge 2 ]] && pass "code_audit_required_for_mode has a definition plus at least one call site" \
  || fail "code_audit_required_for_mode total hits = $cadef_hits, expected >= 2 (def + call site)"
# NOTE: the ticket's full "exactly two call sites" verify assumes EDMV3-T08 (cmd_approve_gate's
# code-audit gate token) has also landed; T08 is out of this batch's scope and depends on T07.
# cmd_archive is the one call site T07 delivers -- see final report for the documented gap.

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
check "unknown lifecycle_mode error lists the legal enum" "standard|partial|fast-track|fix-pack" "$bad_lc_out"

check_fails "set-mode rejects unknown mode value (CLI path)" "invalid mode" \
  "$EDM_STATE" set-mode T7SEEDSTD mode bogus-mode
check_state_unchanged "$STATE_T7SEEDSTD" "$EDM_STATE" set-mode T7SEEDSTD mode bogus-mode

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
  init_out="$(edm-init T1CKOF 2>&1)"
  init_ec=$?
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
  # Nested under $TMP (not a fresh /tmp entry) so the suite's own top-level
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
  init_out="$(edm-init T1NOG 2>&1)"
  init_ec=$?
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
check_fails "archive refuses before approval" "archive refused: code_audit_converged=false" \
  "$EDM_STATE" archive T08ARCH
check_state_unchanged "$STATE_T08ARCH" "$EDM_STATE" archive T08ARCH
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
rationale_hits="$(grep -c 'second user of this dedicated-boolean pattern' "$EDM_STATE")"
[[ "$rationale_hits" -ge 1 ]] && pass "design-rationale comment names code-audit as the second dedicated-boolean user" \
  || fail "design-rationale comment not found naming code-audit as second dedicated-boolean user"

# ---- AC10: all state mutation goes through rmw_state -----------------------------------
echo
echo "T08 AC10 -- cmd_approve_gate's three gate branches all mutate via rmw_state"
mutation_hits="$(sed -n '/^cmd_approve_gate() {/,/^}/p' "$EDM_STATE" | grep -c 'rmw_state ')"
[[ "$mutation_hits" -ge 3 ]] \
  && pass "cmd_approve_gate has >=3 rmw_state call sites (3.5 / code-audit / numeric)" \
  || fail "expected >=3 rmw_state call sites inside cmd_approve_gate, found $mutation_hits"

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

check_fails "phase-start refuses without the prerequisite gate" \
  "Gate 1 has not been approved for T13PS; phase 2 cannot start" \
  "$EDM_STATE" phase-start T13PS 2
check "refusal names the exact approve-gate invocation" "edm-state approve-gate T13PS 1" \
  "$("$EDM_STATE" phase-start T13PS 2 2>&1 || true)"
check_state_unchanged "$STATE_T13PS" "$EDM_STATE" phase-start T13PS 2

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
  tok_out="$("$EDM_STATE" gate-check T13TOK "$tok" 2>&1)"
  tok_ec=$?
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

# ---- AC6 (preserve): cmd_gate_check's numeric comparison logic is unchanged -----------
echo
echo "T13 AC6 -- numeric comparison logic (select(.gate == \$g)) preserved verbatim"
select_hits="$(grep -c '(.gates_approved // \[\]) | map(select(.gate == \$g)) | length' "$EDM_STATE")"
[[ "$select_hits" -ge 2 ]] \
  && pass "the original select(.gate == \$g) | length expression still appears (cmd_gate_check + phase-start)" \
  || fail "expected >=2 occurrences of the unchanged numeric comparison expression, found $select_hits"

# ---- AC7 (C-4): legacy state (no mode field) warns and proceeds through phase-start ---
echo
echo "T13 AC7 -- legacy initiative phase-start warns and proceeds"
STATE_T13LEG_DIR="$TMP/SRD/T13LEG"
mkdir -p "$STATE_T13LEG_DIR"
STATE_T13LEG="$STATE_T13LEG_DIR/.edm-state.json"
jq -n '{prefix: "T13LEG", current_phase: 0, gates_approved: [], phase_durations: {}, last_updated: "2020-01-01T00:00:00Z"}' \
  > "$STATE_T13LEG"
check "legacy phase-start (no mode field) warns rather than hard-failing" \
  "legacy initiative (no mode field)" \
  "$("$EDM_STATE" phase-start T13LEG 2 2>&1)"
"$EDM_STATE" phase-start T13LEG 2 >/dev/null 2>&1 \
  && pass "legacy phase-start proceeds (exit 0) despite the missing mode field" \
  || fail "legacy phase-start hard-failed instead of warn-and-proceed"
leg_phase="$(jq -r '.current_phase' "$STATE_T13LEG")"
[[ "$leg_phase" == "2" ]] && pass "legacy phase-start still advances current_phase" \
  || fail "current_phase = '$leg_phase', expected 2"

# ---- AC8: UserPromptExpansion hooks are retained unchanged ----------------------------
echo
echo "T13 AC8 -- hooks.json UserPromptExpansion gate-check call sites unchanged"
HOOKS_JSON="$(cd "$(dirname "$EDM_STATE")/.." && pwd)/hooks/hooks.json"
hook_gate_check_hits="$(grep -c 'gate-check' "$HOOKS_JSON")"
[[ "$hook_gate_check_hits" -eq 5 ]] \
  && pass "hooks.json still has exactly 5 gate-check call sites (srd x2, tickets, audit-tickets, implement)" \
  || fail "hooks.json has $hook_gate_check_hits gate-check call sites, expected 5 (unchanged)"
check_absent "hooks.json does not reference the new code-audit token" "gate-check \"\$prefix\" code-audit" "$(cat "$HOOKS_JSON")"
check_absent "hooks.json does not reference the new verify-runtime token" "gate-check \"\$prefix\" verify-runtime" "$(cat "$HOOKS_JSON")"
check_absent "hooks.json does not reference the new plan token" "gate-check \"\$prefix\" plan" "$(cat "$HOOKS_JSON")"

# ---- AC9: vocabulary guard -- no single line calls the preflight block that word ------
echo
echo "T13 AC9 -- vocabulary guard: no line names the preflight block with that word"
PLUGIN_DIR="$(cd "$(dirname "$EDM_STATE")/.." && pwd)"
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
[[ "$vocab_hits" -eq 0 ]] && pass "no line describes the preflight block with that word" \
  || fail "found $vocab_hits line(s) combining the two guarded terms on one line -- vocabulary guard violated"

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
check_fails "set code_audit_converged refused" \
  "edm-state approve-gate <PREFIX> code-audit" \
  "$EDM_STATE" set T09GATE code_audit_converged true

# ---- AC2: refusal precedes mutation, for every supplied value ------------------
echo
echo "T09 AC2 -- refusal happens before mutation, for true/false/garbage"
check_state_unchanged "$STATE_T09GATE" "$EDM_STATE" set T09GATE code_audit_converged true
check_state_unchanged "$STATE_T09GATE" "$EDM_STATE" set T09GATE code_audit_converged false
check_state_unchanged "$STATE_T09GATE" "$EDM_STATE" set T09GATE code_audit_converged garbage

# ---- AC3: the whole gate-bearing class refuses, no partial mutation -----------
echo
echo "T09 AC3 -- compliance_gate_approved and gates_approved refuse entirely"
check_fails "set compliance_gate_approved refused" \
  "edm-state approve-gate <PREFIX> 3.5" \
  "$EDM_STATE" set T09GATE compliance_gate_approved true
check_state_unchanged "$STATE_T09GATE" "$EDM_STATE" set T09GATE compliance_gate_approved true
check_fails "set gates_approved refused" \
  "edm-state approve-gate <PREFIX> <gate-num>" \
  "$EDM_STATE" set T09GATE gates_approved true
check_state_unchanged "$STATE_T09GATE" "$EDM_STATE" set T09GATE gates_approved true

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
check_fails "unknown key lists valid keys" \
  "unknown key 'totally_made_up_key'" \
  "$EDM_STATE" set T09GATE totally_made_up_key 1
unk_out="$("$EDM_STATE" set T09GATE totally_made_up_key 1 2>&1 || true)"
check "unknown key error lists compliance_enabled" "compliance_enabled" "$unk_out"
check "unknown key error lists test_frameworks_detected" "test_frameworks_detected" "$unk_out"
check_state_unchanged "$STATE_T09GATE" "$EDM_STATE" set T09GATE totally_made_up_key 1

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
sv_out="$("$EDM_STATE" get T09GATE | jq -e '.schema_version == 1')"
[[ "$sv_out" == "true" ]] && pass "schema_version = 1 for a wave-A-created initiative" \
  || fail "schema_version != 1 (jq -e result: $sv_out)"

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
check_fails "set schema_version refused naming migrate-schema" \
  "edm-state migrate-schema <PREFIX>" \
  "$EDM_STATE" set T09GATE schema_version 2
check_state_unchanged "$STATE_T09GATE" "$EDM_STATE" set T09GATE schema_version 2

# ---- Summary -----------------------------------------------------------------
echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
