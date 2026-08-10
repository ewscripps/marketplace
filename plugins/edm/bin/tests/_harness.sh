#!/usr/bin/env bash
# _harness.sh -- shared smoke-test assertions for the EDM bin/tests/*-smoke.sh suites (CA-014;
# formerly the duplicated G18d preamble). Each suite must set SCRIPT_DIR before sourcing this
# file (every suite already needs SCRIPT_DIR for its own EDM_STATE derivation, so this is never
# an extra line), then source it AFTER `set -euo pipefail`:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
#   source "${SCRIPT_DIR}/_harness.sh"
# (G11/CA-049, round 4: this is the form the largest suite, wave7-smoke.sh, actually uses --
# updated here from the previously-documented inline `$(cd ... && pwd)/_harness.sh` form so the
# docstring matches actual practice rather than prescribing a shape most suites do not follow.
# G20/CA-049, round 5: the `${BASH_SOURCE[0]:-$0}` fallback added here too, closing the second
# half of the same mismatch -- wave7-smoke.sh actually carries the fallback, but this docstring's
# own example previously did not, so it modeled wave7's form only halfway.)
# Each suite still manages its own SCRIPT_DIR / EDM_STATE / TMP setup (TMP via harness_scratch_dir
# below, CA-049/G21) -- this file provides the shared counters and assertions, the shared
# _HARNESS_PLUGIN_DIR / _HARNESS_REPO_ROOT root-path exports (every caller reads these instead of
# re-deriving the same cd/pwd chain independently), and harness_scratch_dir, so suites can never
# diverge on any of the three again.

PASS=0
FAIL=0

pass() { echo "  PASS: $*"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL+1)); }

# check <label> <expected-substring> <actual> -- pass when <actual> contains <expected-substring>.
check() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" == *"$expected"* ]]; then
    pass "$label"
  else
    fail "$label (expected to contain: '$expected', got: '$actual')"
  fi
}

# check_absent <label> <unexpected-substring> <actual> -- pass when <actual> does NOT contain it.
check_absent() {
  local label="$1" unexpected="$2" actual="$3"
  if [[ "$actual" == *"$unexpected"* ]]; then
    fail "$label (expected '$unexpected' to be absent, but it was present)"
  else
    pass "$label"
  fi
}

# ---- EDMV3-T19: helpers three new suites (wave6, wave7) would otherwise hand-roll -------------

# Absolute path to plugins/edm/bin, computed once from this file's own location so
# with_scratch_repo can prepend it to PATH regardless of the caller's cwd (bash 3.2: no
# ${BASH_SOURCE[0]%/*} tricks needed, plain cd/pwd is portable).
_HARNESS_TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_HARNESS_BIN_DIR="$(cd "${_HARNESS_TESTS_DIR}/.." && pwd)"
# CA-049: shared plugin-root and repo-root exports so individual suites stop re-deriving the same
# value inline (five suites previously recomputed this a few lines above their own use of it).
_HARNESS_PLUGIN_DIR="$(cd "${_HARNESS_BIN_DIR}/.." && pwd)"
_HARNESS_REPO_ROOT="$(cd "${_HARNESS_PLUGIN_DIR}/../.." && pwd)"

# harness_scratch_dir <outvar> -- create a fresh scratch directory under ${TMPDIR:-/tmp},
# honoring TMPDIR (unlike a bare `mktemp -d` with no template) and installing a cleanup trap on
# EXIT/INT/TERM in the CALLER's own shell so a Ctrl-C during a suite run does not leak the
# directory (CA-049: three older suites hand-rolled a byte-identical bare `mktemp -d` +
# `trap ... EXIT` preamble that did neither of those two things; wave6/wave7 already do both
# correctly inline -- this gives every suite, old and new, the same corrected preamble in one
# place). Takes an out-variable name rather than printing the path for capture via `$(...)`: a
# command substitution runs in a subshell, so a trap installed inside one is gone the instant
# that subshell exits -- before the caller could ever use the directory. Call it directly
# (never via `$(...)`) so the trap lands in the calling script's own shell:
#   harness_scratch_dir SCRATCH
#   echo "$SCRATCH"
# This installs process-wide EXIT/INT/TERM traps, so -- like with_scratch_repo -- do not call it
# more than once per process without capturing and restoring the prior trap yourself.
harness_scratch_dir() {
  local __harness_scratch_outvar="$1"
  local dir
  dir="$(mktemp -d "${TMPDIR:-/tmp}/edm-harness.XXXXXX")" || { fail "harness_scratch_dir: mktemp failed"; return 1; }
  # G72/CA-232: never interpolate a path into a trap body string (CA-159) -- a path containing an
  # apostrophe, backtick, or "$" would terminate the quoting early and corrupt the stored trap
  # body into a syntax error at signal time. Assign to a dedicated NON-local variable first (this
  # trap must still fire after this function returns, so it cannot reference a `local`, which is
  # popped off the local stack the instant the function returns), then reference it INSIDE single
  # quotes so it expands at signal time, not at install time (matching the already-correct
  # deferred-expansion pattern used by with_scratch_repo below, and by edm-lint-artifacts and
  # edm-check-grants).
  _HARNESS_SCRATCH_DIR="$dir"
  trap 'rm -rf "$_HARNESS_SCRATCH_DIR"' EXIT INT TERM
  printf -v "$__harness_scratch_outvar" '%s' "$dir"
}

# with_scratch_repo <fn> -- create a scratch git repository under ${TMPDIR:-/tmp}, `git init` it, commit an
# initial file, then run <fn> with that directory as the working tree, EDM_SRD_ROOT pointed
# inside it, and plugins/edm/bin prepended to PATH (bin/edm-init and bin/edm-validate-prefix
# invoke sibling scripts by bare name, unlike these test suites which call "$EDM_STATE" by
# absolute path).
#
# Cleanup runs on every exit path: normal return, a non-zero return from <fn>, and interrupt
# (INT/TERM) -- via a trap installed before <fn> runs and restored afterwards, so this must not
# be nested (bash 3.2 has no reliable `trap -p` composition; keep the nesting depth at one).
with_scratch_repo() {
  local fn="$1"
  local dir
  dir="$(mktemp -d "${TMPDIR:-/tmp}/edm-scratch.XXXXXX")" || { fail "with_scratch_repo: mktemp failed"; return 1; }

  local prev_dir prev_srd_root prev_path
  local prev_trap_exit prev_trap_int prev_trap_term
  prev_dir="$(pwd)"
  prev_srd_root="${EDM_SRD_ROOT:-}"
  prev_path="$PATH"
  prev_trap_exit="$(trap -p EXIT)"
  prev_trap_int="$(trap -p INT)"
  prev_trap_term="$(trap -p TERM)"

  # Install cleanup before doing anything that could fail or be interrupted.
  trap 'rm -rf "$dir"' EXIT INT TERM

  cd "$dir" || { rm -rf "$dir"; trap - EXIT INT TERM; return 1; }
  git init -q . >/dev/null 2>&1
  git config user.email "edm-harness@example.com"
  git config user.name "EDM Test Harness"
  git config commit.gpgsign false
  echo "scratch repo seeded by with_scratch_repo" > SEED.md
  git add SEED.md >/dev/null 2>&1
  git commit -q -m "initial commit" >/dev/null 2>&1

  export EDM_SRD_ROOT="${dir}/SRD"
  export PATH="${_HARNESS_BIN_DIR}:${PATH}"

  local status=0
  "$fn" || status=$?

  cd "$prev_dir"
  if [[ -n "$prev_srd_root" ]]; then
    export EDM_SRD_ROOT="$prev_srd_root"
  else
    unset EDM_SRD_ROOT
  fi
  export PATH="$prev_path"

  rm -rf "$dir"

  # Restore whatever trap(s) the caller had before we overwrote them (bash 3.2's `trap -p`
  # output is directly eval-able, unlike its associative-array support).
  trap - EXIT INT TERM
  [[ -n "$prev_trap_exit" ]] && eval "$prev_trap_exit"
  [[ -n "$prev_trap_int" ]] && eval "$prev_trap_int"
  [[ -n "$prev_trap_term" ]] && eval "$prev_trap_term"

  return $status
}

# check_fails <label> <expected-message-substring> <cmd...> -- pass when <cmd...> exits non-zero
# AND its combined stdout+stderr contains <expected-message-substring> (case-insensitive, since
# coreutils message casing differs, e.g. "No such file" on both GNU and BSD `ls`). An exit-code-
# only assertion would pass on any unrelated failure, which is the failure mode that matters for
# a suite full of must-fail cases.
check_fails() {
  local label="$1" expected="$2"
  shift 2
  local output status=0
  output="$("$@" 2>&1)" || status=$?

  if [[ $status -eq 0 ]]; then
    fail "$label (expected non-zero exit, got 0; output: '$output')"
    return
  fi

  local output_lc expected_lc
  output_lc="$(printf '%s' "$output" | tr '[:upper:]' '[:lower:]')"
  expected_lc="$(printf '%s' "$expected" | tr '[:upper:]' '[:lower:]')"
  if [[ "$output_lc" == *"$expected_lc"* ]]; then
    pass "$label"
  else
    fail "$label (expected output to contain: '$expected', got: '$output')"
  fi
}

# count_matches <grep-args...> -- grep -c that returns 0 on no match instead of exiting 1 under
# set -e. Used by count-based assertions so a regression becomes one failed assertion, not a
# crashed suite.
# CAVEAT (CA-145): this collapses grep exit 1 (no match; a real zero count) and grep exit 2
# (file not found, unreadable, or a bad pattern) into the identical printed value "0" -- and 0
# is the PASSING value for every expect-zero caller. A typo'd or deleted path silently reads as
# "the thing we asserted is absent, is absent" instead of failing loudly. Any caller whose
# expected count is 0 MUST pair this with a positive control (assert_absent_with_control below)
# rather than call count_matches bare, OR use count_matches_strict, which does not collapse the
# two exit codes.
count_matches() {
  local count
  count="$(command grep -c "$@" 2>/dev/null)" || count=0
  printf '%s\n' "${count:-0}"
}

# count_matches_strict <grep-args...> -- like count_matches, but does not collapse grep's two
# distinct non-zero exit codes (CA-145 fix): "no match" (grep exit 1) still prints 0 and returns
# 0, exactly like count_matches always has, but "file not found / unreadable / bad pattern" (grep
# exit 2) prints the literal string "ERROR" on stdout and returns 2, so a caller that checks this
# function's own exit status (not only its printed count) fails loudly on a missing-file typo
# instead of silently reading a passing zero.
count_matches_strict() {
  local count status
  count="$(command grep -c "$@" 2>/dev/null)" && status=0 || status=$?
  if [[ $status -eq 2 ]]; then
    printf '%s\n' "ERROR"
    return 2
  fi
  printf '%s\n' "${count:-0}"
  return 0
}

# assert_absent_with_control <label> <needle> <actual> <control-label> <control-haystack> --
# passes only when <needle> is absent from <actual> AND present in the positive-control haystack.
# CA-037/CA-145 (G2/G13, round 4): this primitive is itself correct and well self-tested -- the
# defect was at 16 CALL SITES that authored <control-haystack> as a hand-typed literal string
# containing <needle> by construction, making the control arm provably dead code. Do NOT add a
# new tautological-control call site; use assert_tree_absent below instead, which forces the
# control to come from something a real scan is capable of producing.
# G2/CA-037 (round 5): this helper's last production caller (wave7-smoke.sh's T09 AC13) has been
# converted to assert_tree_absent. It now has zero production callers; the only remaining callers
# are this file's own self-tests in harness-smoke.sh, which exercise it deliberately.
assert_absent_with_control() {
  local label="$1" needle="$2" actual="$3" control_label="$4" control_haystack="$5"
  if [[ "$control_haystack" != *"$needle"* ]]; then
    fail "$label (positive control '${needle}' missing from ${control_label})"
  elif [[ "$actual" == *"$needle"* ]]; then
    fail "$label (expected '${needle}' to be absent, but it was present)"
  else
    pass "$label"
  fi
}

# assert_tree_absent <label> <grep-pattern> <actual-haystack> <control-haystack> <path...> --
# G2/CA-037 + G13/CA-145 combined fix for assert_absent_with_control's tautological-control
# class (16 call sites across wave5/6/7-smoke.sh, round 4). Two independent defects, closed in
# one call:
#   1. (CA-037's path-existence half) <path...> are the real directories/files the caller's own
#      scan (which produced <actual-haystack>) was scoped to; each is asserted to exist BEFORE
#      the needle check runs, so a wrong PLUGIN_DIR or a mistyped directory fails this assertion
#      directly instead of reading identically to a genuinely clean, correctly-scoped tree.
#   2. (CA-145) both haystacks are then routed through count_matches_strict (via stdin, so
#      <actual-haystack> may still be the output of a caller-composed multi-step filter
#      pipeline) and its own exit status is asserted alongside its printed value -- a malformed
#      pattern (grep exit 2) is now a NAMED failure instead of a silently-passing zero.
#
# G2/CA-037 residual (round 5): the helper's own two protections above are real, but the CALLER
# is still responsible for a third property this function cannot enforce by itself -- that
# <grep-pattern> is the SAME literal the caller used to build <actual-haystack>'s own grep
# command. Every caller MUST assign the pattern to one shell variable and reference that same
# variable both when constructing <actual-haystack> and when passing <grep-pattern> here; do NOT
# type the pattern out a second time. If those two occurrences are allowed to diverge (typed
# independently), a typo in the haystack-producing grep is invisible: the control (built from an
# independently-authored, correct literal) still passes, and the mismatched real haystack simply
# reads as "nothing found" -- a false clean. Where the caller's own scan additionally applies a
# filter chain (e.g. `| grep -v tests/`), the control-producing content should be run through
# that identical chain (inject a synthetic hit into a scratch copy of real content and re-derive
# it with the caller's own pipeline) rather than checked as a bare literal, so a filter that
# widens to swallow real hits also swallows the synthetic one and the control itself fails.
assert_tree_absent() {
  local label="$1" pattern="$2" actual="$3" control="$4"
  shift 4
  local _p
  for _p in "$@"; do
    [[ -e "$_p" ]] || { fail "$label (scan target missing: ${_p} -- broken path, not a clean tree)"; return; }
  done
  local control_ec=0 control_count real_ec=0 real_count
  control_count="$(printf '%s\n' "$control" | count_matches_strict -- "$pattern")" || control_ec=$?
  real_count="$(printf '%s\n' "$actual" | count_matches_strict -- "$pattern")" || real_ec=$?
  if [[ $control_ec -ne 0 || "${control_count:-0}" -lt 1 ]]; then
    fail "$label (positive control broken: count_matches_strict found ${control_count:-0} '${pattern}' occurrence(s) in the control haystack, ec=${control_ec} -- the matcher itself is not proven capable of finding a real hit)"
  elif [[ $real_ec -ne 0 ]]; then
    fail "$label (count_matches_strict errored scanning the real haystack, ec=${real_ec})"
  elif [[ "${real_count:-0}" -eq 0 ]]; then
    pass "$label"
  else
    fail "$label (expected '${pattern}' to be absent, found ${real_count} occurrence(s))"
  fi
}

# _harness_hash_file <file> -- sha256 of <file>, or "absent" if it doesn't exist. Tries
# `shasum -a 256` first, falling back to `sha256sum` (macOS/Linux divergence, EDMV3-106).
_harness_hash_file() {
  local file="$1"
  [[ -f "$file" ]] || { echo "absent"; return 0; }
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | cut -d' ' -f1
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | cut -d' ' -f1
  else
    echo "unhashable"
  fi
}

# check_state_unchanged <state-file> <cmd...> -- hashes <state-file>, runs <cmd...>, re-hashes,
# and asserts byte identity. Used to prove a command that claims to be read-only (e.g.
# `edm-state list --paths`) never mutates the state file it reads.
check_state_unchanged() {
  local state_file="$1"
  shift
  local before after
  before="$(_harness_hash_file "$state_file")"
  if [[ "$before" == "absent" ]]; then
    fail "state unchanged: $state_file (baseline file missing before command ran)"
    return
  fi
  "$@" >/dev/null 2>&1 || true
  after="$(_harness_hash_file "$state_file")"
  if [[ "$before" == "$after" ]]; then
    pass "state unchanged: $state_file"
  else
    fail "state changed: $state_file (hash before: $before, after: $after)"
  fi
}

# check_refuses_and_leaves_state <label> <expected-message-substring> <state-file> <cmd...> --
# CA-042 fix. Combines check_fails (non-zero exit + message substring, case-insensitive) with
# check_state_unchanged's before/after hash comparison in ONE invocation of <cmd...>, instead of
# the previous pattern of calling check_fails and check_state_unchanged back to back against the
# same command -- two separate invocations asserting two separate things, neither of which alone
# proves the other. This is what 45 of the 49 check_state_unchanged call sites this replaced
# actually wanted: proof that the command both refused AND left state untouched, from a single
# real execution.
check_refuses_and_leaves_state() {
  local label="$1" expected="$2" state_file="$3"
  shift 3
  local before after output status=0

  before="$(_harness_hash_file "$state_file")"
  if [[ "$before" == "absent" ]]; then
    fail "$label (baseline state file missing before command ran: $state_file)"
    return
  fi

  output="$("$@" 2>&1)" || status=$?
  after="$(_harness_hash_file "$state_file")"

  if [[ $status -eq 0 ]]; then
    fail "$label (expected non-zero exit, got 0; output: '$output')"
    return
  fi

  local output_lc expected_lc
  output_lc="$(printf '%s' "$output" | tr '[:upper:]' '[:lower:]')"
  expected_lc="$(printf '%s' "$expected" | tr '[:upper:]' '[:lower:]')"
  if [[ "$output_lc" != *"$expected_lc"* ]]; then
    fail "$label (expected output to contain: '$expected', got: '$output')"
    return
  fi

  if [[ "$before" != "$after" ]]; then
    fail "$label (command refused as expected but state changed: $state_file, hash before: $before, after: $after)"
    return
  fi

  pass "$label"
}

# _wave7_extract_between <file> <start-regex> <end-regex> -- prints the lines strictly between
# the first line matching <start-regex> (exclusive) and the next line matching <end-regex>
# (exclusive), or EOF if <end-regex> never matches again. CA-102: this is the general form behind
# _wave7_extract_section below, and is also what replaces a `sed -n 'A,Bp'` hardcoded line-number
# range with an anchor-based extraction that survives the target file growing or shrinking above
# the extracted block.
# Deliberately passes the two regexes through the environment (ENVIRON[]) rather than `awk -v`:
# POSIX awk applies the SAME backslash-escape processing to a `-v var=value` assignment that it
# applies to a string literal in the program text, so `-v s='^10\. \*\*Foo\*\*'` silently becomes
# the regex `^10. **Foo**` (both backslashes stripped) -- "**" is then two adjacent quantifiers
# with no atom to repeat, which matches nothing on every awk this was tested against. Environment
# variables carry no such processing, so a caller's regex reaches awk's regex engine byte-for-byte.
_wave7_extract_between() {
  local file="$1"
  WAVE7_EXTRACT_START="$2" WAVE7_EXTRACT_END="$3" awk '
    $0 ~ ENVIRON["WAVE7_EXTRACT_START"] { found=1; next }
    found && $0 ~ ENVIRON["WAVE7_EXTRACT_END"] { exit }
    found { print }
  ' "$file"
}

# _wave7_extract_section <file> <heading-regex> -- prints the body of the first '## ' section
# whose heading matches <heading-regex>, up to (not including) the next '## ' heading or EOF.
# Originally a wave7-smoke.sh-local helper (EDMV3-T45); moved here (CA-102/CA-099) so every
# suite can replace a `sed -n 'A,Bp'` / bare-substring-anywhere-in-the-file assertion with a
# real, anchor-based section extraction instead of just this one call site.
_wave7_extract_section() {
  local file="$1" heading="$2"
  _wave7_extract_between "$file" "^## ${heading}\$" "^## "
}

# ---- EDMV3-T50/T51/T52: cost-tracking test fixtures ------------------------------------------
# session_dir_for_test_cwd -- mirrors bin/edm-state's own session_dir_for_cwd() formula exactly
# (same `tr '/.' '-'` encoding of $HOME + $(pwd)) so a test can predict, and stage fixtures
# into, the exact directory get_session_tokens_since() will read at call time.
session_dir_for_test_cwd() {
  echo "${HOME}/.claude/projects/$(pwd | tr '/.' '-')"
}

# stage_session_jsonl <sessions_dir> <filename> <model> <input_tokens> <output_tokens> [<timestamp>]
# Writes one synthetic assistant-message JSONL line in the exact shape
# get_session_tokens_since() (bin/edm-state) parses: .type == "assistant", .timestamp,
# .message.model, .message.usage.{input_tokens,output_tokens,cache_read_input_tokens,
# cache_creation.ephemeral_{5m,1h}_input_tokens}. Creates <sessions_dir> if absent. Lets a test
# inject deterministic token/model data without depending on real Claude Code session history.
stage_session_jsonl() {
  local sessions_dir="$1" filename="$2" model="$3" input_tokens="$4" output_tokens="$5"
  local ts="${6:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"
  mkdir -p "$sessions_dir"
  jq -cn --arg ts "$ts" --arg model "$model" --argjson in "$input_tokens" --argjson out "$output_tokens" '
    {
      type: "assistant",
      timestamp: $ts,
      message: {
        model: $model,
        usage: {
          input_tokens: $in,
          output_tokens: $out,
          cache_read_input_tokens: 0,
          cache_creation: {ephemeral_5m_input_tokens: 0, ephemeral_1h_input_tokens: 0}
        }
      }
    }
  ' > "${sessions_dir}/${filename}"
}
