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

# ---- EDMV3-T19: helpers three new suites (wave6, wave7) would otherwise hand-roll -------------

# Absolute path to plugins/edm/bin, computed once from this file's own location so
# with_scratch_repo can prepend it to PATH regardless of the caller's cwd (bash 3.2: no
# ${BASH_SOURCE[0]%/*} tricks needed, plain cd/pwd is portable).
_HARNESS_TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_HARNESS_BIN_DIR="$(cd "${_HARNESS_TESTS_DIR}/.." && pwd)"

# with_scratch_repo <fn> — create a scratch git repository under ${TMPDIR:-/tmp}, `git init` it, commit an
# initial file, then run <fn> with that directory as the working tree, EDM_SRD_ROOT pointed
# inside it, and plugins/edm/bin prepended to PATH (bin/edm-init and bin/edm-validate-prefix
# invoke sibling scripts by bare name, unlike these test suites which call "$EDM_STATE" by
# absolute path).
#
# Cleanup runs on every exit path: normal return, a non-zero return from <fn>, and interrupt
# (INT/TERM) — via a trap installed before <fn> runs and restored afterwards, so this must not
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

# check_fails <label> <expected-message-substring> <cmd...> — pass when <cmd...> exits non-zero
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

# count_matches <grep-args...> — grep -c that returns 0 on no match instead of exiting 1 under
# set -e. Used by count-based assertions so a regression becomes one failed assertion, not a
# crashed suite.
count_matches() {
  local count
  count="$(command grep -c "$@" 2>/dev/null)" || count=0
  printf '%s\n' "${count:-0}"
}

# assert_absent_with_control <label> <needle> <actual> <control-label> <control-haystack> —
# passes only when <needle> is absent from <actual> AND present in the positive-control haystack.
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

# _harness_hash_file <file> — sha256 of <file>, or "absent" if it doesn't exist. Tries
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

# check_state_unchanged <state-file> <cmd...> — hashes <state-file>, runs <cmd...>, re-hashes,
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

# ---- EDMV3-T50/T51/T52: cost-tracking test fixtures ------------------------------------------
# session_dir_for_test_cwd — mirrors bin/edm-state's own session_dir_for_cwd() formula exactly
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
