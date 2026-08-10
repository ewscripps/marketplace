#!/usr/bin/env bash
# run-all.sh -- EDMV3-T20 smoke aggregator.
#
# Auto-discovers every plugins/edm/bin/tests/*-smoke.sh suite (AC3: a new suite is picked up by
# the glob, not by being added to a hand-kept list -- an unregistered suite still runs). Runs
# each suite, prints a per-suite pass/fail table and a total, and exits non-zero if any suite
# fails, naming the failing suite(s).
#
# Usage: bash plugins/edm/bin/tests/run-all.sh
# CA-074: -e is intentionally omitted -- the suite loop below seeds `_status=0` then captures
# `_out="$(bash "$suite" 2>&1)" || _status=$?` (CA-315/G39: corrected from a bare `_out=...` then
# a bare `_status=$?` read on the next line, the shape this codebase's own class of bugs elsewhere
# has shown is fragile to an intervening command silently clobbering `$?` before it's read) so a
# failing suite's non-zero exit is captured and reported rather than aborting the aggregator
# before every suite has run (the whole point of an aggregator is to collect every suite's
# result, not stop at the first failure).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# G7/CA-146 (round-3 Wave 7b): EDM_RUN_ALL_SUITE_DIR overrides where suite discovery and
# execution read from, so harness-smoke.sh can point this aggregator at a scratch directory of
# throwaway stub suites and exercise its own PASS/FAIL/CRASH/missing-summary accounting without
# touching the real suite set. Unset (the default) is byte-identical to prior behavior: discovery
# and execution both read from $SCRIPT_DIR. When set, the three real-repo-anchored standalone
# checks below (edm-check-grants/-skill-sync/-vocabulary) are also skipped -- they are meaningless
# against a scratch suite set and their own live-tree state must never leak into an accounting test.
_SUITE_DIR="${EDM_RUN_ALL_SUITE_DIR:-$SCRIPT_DIR}"

# Diagnostic ordering preference (Technical Notes): foundational suites first, lifecycle suites
# last, so a foundational break is reported before a downstream one. This is a SORT HINT only --
# it never gates which suites run. Every file matching *-smoke.sh runs whether or not it is
# named here (AC3); anything discovered but not listed here just runs after the named ones, in
# glob order.
# G7/CA-146: EDM_RUN_ALL_PREFERRED_ORDER and EDM_RUN_ALL_MIN_SUITE_COUNT let harness-smoke.sh's
# scratch-directory cases exercise a single stub suite without also having to satisfy the
# real seven-suite floor and preferred-name set below -- unset (the default, "${VAR-default}"
# so an explicitly-empty override is distinct from "unset") preserves prior behavior exactly.
_PREFERRED_ORDER="${EDM_RUN_ALL_PREFERRED_ORDER-wave3-smoke.sh wave4a-smoke.sh wave4b-smoke.sh wave5-smoke.sh harness-smoke.sh wave6-smoke.sh wave7-smoke.sh}"

# ---- Discover all suites (AC3: glob-driven, not a hand-kept list) -----------------------------
_all_suites=()
while IFS= read -r _f; do
  _all_suites+=("$(basename "$_f")")
done < <(find "$_SUITE_DIR" -maxdepth 1 -name '*-smoke.sh' -type f 2>/dev/null | sort)

if [[ ${#_all_suites[@]} -eq 0 ]]; then
  echo "run-all: no *-smoke.sh suites found in $_SUITE_DIR" >&2
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

# ---- CA-016: a zero-suite guard above catches total deletion, but does nothing if a named
# suite (e.g. wave7-smoke.sh, ~830 assertions) is deleted or renamed while other suites survive --
# _run_order would still be non-empty and the aggregate would report ALL SUITES PASSED. Assert
# every name _PREFERRED_ORDER expects was actually discovered, naming any that were not, and
# assert a minimum suite count so a silent shrink of the discovered set is never invisible.
_missing_preferred=()
for _name in $_PREFERRED_ORDER; do
  _found=0
  for _r in "${_run_order[@]+"${_run_order[@]}"}"; do
    [[ "$_r" == "$_name" ]] && _found=1 && break
  done
  [[ $_found -eq 1 ]] || _missing_preferred+=("$_name")
done
if [[ ${#_missing_preferred[@]} -gt 0 ]]; then
  echo "run-all: expected suite(s) not discovered: ${_missing_preferred[*]}" >&2
  exit 1
fi
_MIN_SUITE_COUNT="${EDM_RUN_ALL_MIN_SUITE_COUNT:-7}"
if [[ ${#_run_order[@]} -lt $_MIN_SUITE_COUNT ]]; then
  echo "run-all: only ${#_run_order[@]} suite(s) discovered, expected at least ${_MIN_SUITE_COUNT}" >&2
  exit 1
fi

echo "EDM smoke aggregator -- ${#_run_order[@]} suite(s) discovered"
echo

_total_pass=0
_total_fail=0
_failed_suites=()

printf '%-28s %8s %8s %8s\n' "SUITE" "PASS" "FAIL" "STATUS"
printf '%-28s %8s %8s %8s\n' "----------------------------" "--------" "--------" "--------"

for _suite in "${_run_order[@]+"${_run_order[@]}"}"; do
  _status=0
  _out="$(bash "${_SUITE_DIR}/${_suite}" 2>&1)" || _status=$?

  # Extract this suite's own pass/fail counts from its standard summary line.
  _summary_line="$(printf '%s\n' "$_out" | grep -E '^Results: [0-9]+ passed, [0-9]+ failed' | tail -1)"
  if [[ -n "$_summary_line" ]]; then
    _s_pass="$(printf '%s' "$_summary_line" | sed -E 's/^Results: ([0-9]+) passed.*/\1/')"
    _s_fail="$(printf '%s' "$_summary_line" | sed -E 's/.*, ([0-9]+) failed.*/\1/')"
  else
    _s_pass=""
    _s_fail=""
  fi
  _suite_status="PASS"
  _suite_note=""
  if [[ -n "${_s_pass:-}" && -n "${_s_fail:-}" ]]; then
    _suite_assertions=$((_s_pass + _s_fail))
    if [[ $_suite_assertions -lt 1 ]]; then
      _suite_status="FAIL"
      _suite_note="suite emitted zero assertions"
      _s_fail=$((_s_fail + 1))
    elif [[ $_status -ne 0 ]]; then
      _suite_status="FAIL"
      _suite_note="suite exited non-zero"
      [[ $_s_fail -ge 1 ]] || _s_fail=$((_s_fail + 1))
    elif [[ $_s_fail -ne 0 ]]; then
      _suite_status="FAIL"
      _suite_note="suite reported failed assertions"
    fi
  else
    _s_pass=0
    _s_fail=1
    if [[ $_status -ne 0 ]]; then
      _suite_status="CRASH"
      _suite_note="suite crashed before emitting Results summary"
      echo "CRASH ${_suite}"
    else
      _suite_status="FAIL"
      _suite_note="suite exited 0 without emitting Results summary"
    fi
  fi

  if [[ "$_suite_status" == "PASS" ]]; then
    printf '%-28s %8s %8s %8s\n' "$_suite" "$_s_pass" "$_s_fail" "$_suite_status"
  else
    printf '%-28s %8s %8s %8s\n' "$_suite" "$_s_pass" "$_s_fail" "$_suite_status"
    _failed_suites+=("$_suite")
    echo "---- ${_suite} output (${_suite_note}, exit=${_status}) ----"
    printf '%s\n' "$_out"
    echo "---- end ${_suite} output ----"
  fi

  _total_pass=$((_total_pass + _s_pass))
  _total_fail=$((_total_fail + _s_fail))
done

# ---- CA-096: _standalone_check <script-path> <label> -- runs a standalone checker script (one
# that is not a *-smoke.sh suite, so run-all.sh's own discovery loop above never reaches it) and
# folds its 0/non-zero exit into the aggregate counters exactly the two blocks below used to do
# by hand. This replaced two near-identical 15-line blocks (EDMV3-T03 AC10's edm-check-grants
# case and EDMV3-T39 AC7's edm-check-skill-sync case) and is also what makes it cheap to add the
# third call below: edm-check-vocabulary is a standalone checker in the same shape, run directly
# by the blocking lint:vocabulary CI job, that this aggregator never actually invoked before now.
_standalone_check() {
  local script_path="$1" label="$2"
  local out ec
  echo
  echo "$label"
  ec=0
  out="$(bash "$script_path" 2>&1)" || ec=$?
  if [[ $ec -eq 0 ]]; then
    echo "  PASS: $(basename "$script_path") (exit 0)"
    _total_pass=$((_total_pass + 1))
  else
    echo "  FAIL: $(basename "$script_path") (exit ${ec})" >&2
    printf '%s\n' "$out" >&2
    _total_fail=$((_total_fail + 1))
    _failed_suites+=("$(basename "$script_path")")
  fi
}

# G7/CA-146: these three real-repo-anchored checks are skipped under EDM_RUN_ALL_SUITE_DIR --
# they check this actual plugin tree, which is meaningless (and, worse, a source of unrelated
# real-tree flakiness) when run-all.sh is being pointed at a scratch suite directory for an
# accounting-logic test.
if [[ -z "${EDM_RUN_ALL_SUITE_DIR:-}" ]]; then
  # EDMV3-T03 AC10: edm-check-grants runs as part of the aggregator, not just as a suite case it is
  # exercised from (wave7-smoke.sh). Real invocation, not a comment reference: it must actually pass
  # the 0/1/2 exit contract against the live tree every time run-all.sh runs.
  _standalone_check "${SCRIPT_DIR}/../edm-check-grants" \
    "edm-check-grants -- four-source grant/instruction contract check"

  # EDMV3-T39 AC7: the dispatcher-duplication tripwire runs every time too. It guards the branch
  # that was NOT taken (deduplication shipped instead), so it should always be clean -- which is
  # exactly why a silent regression here would otherwise go unnoticed.
  # G43/CA-274: label reworded to drop "fallback" framing -- per edm-check-skill-sync's own header
  # this is a permanent regression tripwire proving the deduplication holds, not a fallback for an
  # untaken branch.
  _standalone_check "${SCRIPT_DIR}/../edm-check-skill-sync" \
    "edm-check-skill-sync -- dispatcher holds no phase procedure (EDMV3-T39 AC7 regression tripwire)"

  # CA-096: edm-check-vocabulary -- one of the two standalone checkers a blocking CI lint job
  # (lint:vocabulary) runs directly -- was never wired into this aggregator at all. This call is
  # the fix.
  _standalone_check "${SCRIPT_DIR}/../edm-check-vocabulary" \
    "edm-check-vocabulary -- abolished-vocabulary and override-flag backstop (EDMV3-T30)"
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
