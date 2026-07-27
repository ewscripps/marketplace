#!/usr/bin/env bash
# run-all.sh — EDMV3-T20 smoke aggregator.
#
# Auto-discovers every plugins/edm/bin/tests/*-smoke.sh suite (AC3: a new suite is picked up by
# the glob, not by being added to a hand-kept list -- an unregistered suite still runs). Runs
# each suite, prints a per-suite pass/fail table and a total, and exits non-zero if any suite
# fails, naming the failing suite(s).
#
# Usage: bash plugins/edm/bin/tests/run-all.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Diagnostic ordering preference (Technical Notes): foundational suites first, lifecycle suites
# last, so a foundational break is reported before a downstream one. This is a SORT HINT only --
# it never gates which suites run. Every file matching *-smoke.sh runs whether or not it is
# named here (AC3); anything discovered but not listed here just runs after the named ones, in
# glob order.
_PREFERRED_ORDER="wave3-smoke.sh wave4a-smoke.sh wave4b-smoke.sh wave5-smoke.sh harness-smoke.sh wave6-smoke.sh wave7-smoke.sh"

# ---- Discover all suites (AC3: glob-driven, not a hand-kept list) -----------------------------
_all_suites=()
while IFS= read -r _f; do
  _all_suites+=("$(basename "$_f")")
done < <(find "$SCRIPT_DIR" -maxdepth 1 -name '*-smoke.sh' -type f 2>/dev/null | sort)

if [[ ${#_all_suites[@]} -eq 0 ]]; then
  echo "run-all: no *-smoke.sh suites found in $SCRIPT_DIR" >&2
  exit 1
fi

# ---- Build the run order: preferred names first (only if discovered), then anything else -----
_run_order=()
for _name in $_PREFERRED_ORDER; do
  for _s in "${_all_suites[@]+"${_all_suites[@]}"}"; do
    if [[ "$_s" == "$_name" ]]; then
      _run_order+=("$_name")
      break
    fi
  done
done
for _s in "${_all_suites[@]+"${_all_suites[@]}"}"; do
  _already=0
  for _r in "${_run_order[@]+"${_run_order[@]}"}"; do
    [[ "$_r" == "$_s" ]] && _already=1 && break
  done
  [[ $_already -eq 1 ]] || _run_order+=("$_s")
done

echo "EDM smoke aggregator — ${#_run_order[@]} suite(s) discovered"
echo

_total_pass=0
_total_fail=0
_failed_suites=()

printf '%-28s %8s %8s %8s\n' "SUITE" "PASS" "FAIL" "STATUS"
printf '%-28s %8s %8s %8s\n' "----------------------------" "--------" "--------" "--------"

for _suite in "${_run_order[@]+"${_run_order[@]}"}"; do
  _out="$(bash "${SCRIPT_DIR}/${_suite}" 2>&1)"
  _status=$?

  # Extract this suite's own pass/fail counts from its summary line. Two summary formats are
  # in use across existing suites: "Results: N passed, N failed" and "PASS: N  FAIL: N"
  # (anchored to line start so it never matches an individual "  PASS: <label>" assertion line).
  _summary_line="$(printf '%s\n' "$_out" | grep -E '^Results: [0-9]+ passed, [0-9]+ failed' | tail -1)"
  if [[ -n "$_summary_line" ]]; then
    _s_pass="$(printf '%s' "$_summary_line" | sed -E 's/^Results: ([0-9]+) passed.*/\1/')"
    _s_fail="$(printf '%s' "$_summary_line" | sed -E 's/.*, ([0-9]+) failed.*/\1/')"
  else
    _summary_line2="$(printf '%s\n' "$_out" | grep -E '^PASS: [0-9]+  FAIL: [0-9]+' | tail -1)"
    if [[ -n "$_summary_line2" ]]; then
      _s_pass="$(printf '%s' "$_summary_line2" | sed -E 's/^PASS: ([0-9]+).*/\1/')"
      _s_fail="$(printf '%s' "$_summary_line2" | sed -E 's/.*FAIL: ([0-9]+)$/\1/')"
    else
      _s_pass=""
      _s_fail=""
    fi
  fi
  _s_pass="${_s_pass:-0}"
  _s_fail="${_s_fail:-0}"

  if [[ $_status -eq 0 ]]; then
    printf '%-28s %8s %8s %8s\n' "$_suite" "$_s_pass" "$_s_fail" "PASS"
  else
    printf '%-28s %8s %8s %8s\n' "$_suite" "$_s_pass" "$_s_fail" "FAIL"
    _failed_suites+=("$_suite")
    echo "---- ${_suite} output (failed, exit=${_status}) ----"
    printf '%s\n' "$_out"
    echo "---- end ${_suite} output ----"
  fi

  _total_pass=$((_total_pass + _s_pass))
  _total_fail=$((_total_fail + _s_fail))
done

# ---- EDMV3-T03 AC10: edm-check-grants runs as part of the aggregator, not just as a suite case
# it is exercised from (wave7-smoke.sh). Real invocation, not a comment reference: it must
# actually pass 0/1/2 exit contract against the live tree every time run-all.sh runs. ------------
echo
echo "edm-check-grants -- four-source grant/instruction contract check"
_grants_out="$(bash "${SCRIPT_DIR}/../edm-check-grants" 2>&1)"
_grants_ec=$?
if [[ $_grants_ec -eq 0 ]]; then
  echo "  PASS: edm-check-grants (exit 0)"
  _total_pass=$((_total_pass + 1))
else
  echo "  FAIL: edm-check-grants (exit ${_grants_ec})" >&2
  printf '%s\n' "$_grants_out" >&2
  _total_fail=$((_total_fail + 1))
  _failed_suites+=("edm-check-grants")
fi

echo
echo "Total: ${_total_pass} passed, ${_total_fail} failed across ${#_run_order[@]} suite(s)"

if [[ ${#_failed_suites[@]} -eq 0 ]]; then
  echo "run-all: ALL SUITES PASSED"
  exit 0
else
  echo "run-all: FAILED SUITES: ${_failed_suites[*]}" >&2
  exit 1
fi
