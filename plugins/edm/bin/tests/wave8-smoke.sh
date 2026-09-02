#!/usr/bin/env bash
# wave8-smoke.sh -- EDMV4 Epic 05 (Classifier and Scorecard) / Epic 06 (Hooks and Codemaps) /
# Epic 07 (Inherited Tickets) smoke coverage. New suite file: no prior wave8-smoke.sh existed on
# this branch, so this is the first ticket to create it (EDMV3-T35/T37's own sections, if landed
# later, append banner sections here rather than overwriting -- per epic 05's Technical Notes).
# Run from repo root: bash plugins/edm/bin/tests/wave8-smoke.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# Shared assertions / counters (CA-014).
source "${SCRIPT_DIR}/_harness.sh"
PLUGIN_DIR="$_HARNESS_PLUGIN_DIR"

echo "wave8 smoke check -- EDMV4-T05 / EDMV4-T34 / EDMV4-T48"
echo

# =================================================================================================
# EDMV4-T05 -- Verify the CA-532 and CA-490 fixes and record the eval-baseline scope boundary
# =================================================================================================
# Two regression checks (AC1/AC2), each proven to discriminate (AC5) against a scratch copy.

RUN_EVAL_SH="${PLUGIN_DIR}/evals/run-eval.sh"
COMPARE_EVAL="${PLUGIN_DIR}/bin/edm-compare-eval"

# ---- AC1: CLAUDE_ALLOWED_TOOLS / CLAUDE_DISALLOWED_TOOLS are real bash arrays, expanded [@] ----
t05_ac1_check() {
  local file="$1"
  grep -qE -- '^CLAUDE_ALLOWED_TOOLS=\(' "$file" || return 1
  grep -qE -- '^CLAUDE_DISALLOWED_TOOLS=\(' "$file" || return 1
  grep -qF -- '--allowedTools "${CLAUDE_ALLOWED_TOOLS[@]}"' "$file" || return 1
  grep -qF -- '--disallowedTools "${CLAUDE_DISALLOWED_TOOLS[@]}"' "$file" || return 1
  return 0
}

if t05_ac1_check "$RUN_EVAL_SH"; then
  pass "EDMV4-T05 AC1 -- CLAUDE_ALLOWED_TOOLS/CLAUDE_DISALLOWED_TOOLS are real bash arrays expanded as \${ARRAY[@]} (CA-532 regression check)"
else
  fail "EDMV4-T05 AC1 -- CA-532 regression: run-eval.sh no longer declares/expands the tool lists as bash arrays"
fi

# AC5 positive control for AC1: collapse the array declaration to a space-joined string and
# confirm the check now fails -- proving the check is not vacuously true.
T05_TMP="$(mktemp -d "${TMPDIR:-/tmp}/edm-wave8-t05.XXXXXX")"
trap 'rm -rf "$T05_TMP"' EXIT
trap 'rm -rf "$T05_TMP"; exit 130' INT
trap 'rm -rf "$T05_TMP"; exit 143' TERM
trap 'rm -rf "$T05_TMP"; exit 129' HUP

T05_AC1_BROKEN="${T05_TMP}/run-eval-broken.sh"
sed -E 's/^CLAUDE_ALLOWED_TOOLS=\(.*\)$/CLAUDE_ALLOWED_TOOLS="Read Write Edit Glob"/' "$RUN_EVAL_SH" > "$T05_AC1_BROKEN"
if t05_ac1_check "$T05_AC1_BROKEN"; then
  fail "EDMV4-T05 AC5 -- AC1 check did not discriminate: a space-joined CLAUDE_ALLOWED_TOOLS string still passed"
else
  pass "EDMV4-T05 AC5 -- AC1 check correctly fails when CLAUDE_ALLOWED_TOOLS is collapsed to a space-joined string"
fi

# ---- AC2: edm-compare-eval's complete!=true refusal runs BEFORE the baseline-existence check ----
# Relative-position comparison (never absolute line numbers), per the ticket's own rationale.
t05_ac2_check() {
  local file="$1" line_a line_b
  line_a="$(grep -n 'cand_complete="\$(jq' "$file" | head -1 | cut -d: -f1)"
  line_b="$(grep -n 'if \[ ! -f "\$BASELINE" \]; then' "$file" | head -1 | cut -d: -f1)"
  [[ -n "$line_a" && -n "$line_b" ]] || return 2
  [[ "$line_a" -lt "$line_b" ]]
}

if t05_ac2_check "$COMPARE_EVAL"; then
  pass "EDMV4-T05 AC2 -- edm-compare-eval's complete!=true refusal precedes the baseline-existence check (CA-490 regression check)"
else
  fail "EDMV4-T05 AC2 -- CA-490 regression: the complete!=true refusal no longer precedes the baseline-existence check"
fi

# AC5 positive control for AC2: swap which of the two anchor lines appears first, and confirm
# the check now fails.
T05_AC2_SWAPPED="${T05_TMP}/edm-compare-eval-swapped"
T05_LINE_A="$(grep -n 'cand_complete="\$(jq' "$COMPARE_EVAL" | head -1 | cut -d: -f1)"
T05_LINE_B="$(grep -n 'if \[ ! -f "\$BASELINE" \]; then' "$COMPARE_EVAL" | head -1 | cut -d: -f1)"
T05_TEXT_A="$(sed -n "${T05_LINE_A}p" "$COMPARE_EVAL")"
T05_TEXT_B="$(sed -n "${T05_LINE_B}p" "$COMPARE_EVAL")"
awk -v la="$T05_LINE_A" -v lb="$T05_LINE_B" -v ta="$T05_TEXT_A" -v tb="$T05_TEXT_B" '
  NR==la {print tb; next}
  NR==lb {print ta; next}
  {print}
' "$COMPARE_EVAL" > "$T05_AC2_SWAPPED"

if t05_ac2_check "$T05_AC2_SWAPPED"; then
  fail "EDMV4-T05 AC5 -- AC2 check did not discriminate: a swapped ordering still passed"
else
  pass "EDMV4-T05 AC5 -- AC2 check correctly fails when the two anchor lines are swapped"
fi

# ---- AC7/AC8: no re-fix attempted -- the two cited fixes are present exactly as verified -------
check "EDMV4-T05 AC8 -- run-eval.sh still expands CLAUDE_DISALLOWED_TOOLS as an array (no re-fix)" \
  'CLAUDE_DISALLOWED_TOOLS=(WebFetch WebSearch KillShell BashOutput)' \
  "$(cat "$RUN_EVAL_SH")"

check "EDMV4-T05 AC8 -- edm-compare-eval still prints the exact lowercase NOT-armed message" \
  'the eval tripwire is NOT armed' \
  "$(cat "$COMPARE_EVAL")"

# ---- AC3: suite registration is EDMV4-T53's job, not this ticket's; record status only ---------
RUN_ALL_SH="${PLUGIN_DIR}/bin/tests/run-all.sh"
if grep -qF 'wave8-smoke.sh' "$RUN_ALL_SH"; then
  pass "EDMV4-T05 AC3 -- wave8-smoke.sh is already registered in run-all.sh's _PREFERRED_ORDER"
else
  echo "  NOTE: EDMV4-T05 AC3 -- wave8-smoke.sh is not yet in run-all.sh's _PREFERRED_ORDER;" \
       "this suite is still discovered and run via run-all.sh's *-smoke.sh glob (AC3 explicitly" \
       "assigns the _PREFERRED_ORDER/_MIN_SUITE_COUNT registration to EDMV4-T53, not this ticket)."
fi

# =================================================================================================
# EDMV4-T34 -- Add a size-classifier pre-step and a lifecycle_mode write path to the orchestrator
# =================================================================================================

ORCH_SKILL="${PLUGIN_DIR}/skills/orchestrator/SKILL.md"

# _t34_extract_between <file> <start-regex> <end-regex> -- prints lines strictly between the
# first line matching <start-regex> (exclusive) and the next line matching <end-regex> (exclusive).
_t34_extract_between() {
  local file="$1"
  T34_START="$2" T34_END="$3" awk '
    $0 ~ ENVIRON["T34_START"] { found=1; next }
    found && $0 ~ ENVIRON["T34_END"] { exit }
    found { print }
  ' "$file"
}

T34_BLOCK="$(_t34_extract_between "$ORCH_SKILL" '^\*\*Step 1b\.5' '^\*\*Step 1c')"

if [[ -n "$T34_BLOCK" ]]; then
  pass "EDMV4-T34 AC1 -- Step 1b.5 section exists between Step 1b and Step 1c"
else
  fail "EDMV4-T34 AC1 -- Step 1b.5 section not found (or empty) between Step 1b and Step 1c"
fi

check "EDMV4-T34 AC1 -- Step 1b.5 carries the same 'Skipped on resume' line as Step 1c" \
  'Skipped on resume (Step 1b already read a recorded non-default mode).' "$T34_BLOCK"

check "EDMV4-T34 AC2 -- Step 1b.5 states exactly three signals and highest-tier-wins, not an average" \
  'files touched, new dependency or contract, and design' "$T34_BLOCK"
check "EDMV4-T34 AC2 -- Step 1b.5 explicitly says this is not an average" \
  'this is not an' "$T34_BLOCK"

check "EDMV4-T34 AC3 -- trivial tier recommends (standard, fix-pack)" \
  '| trivial | (standard, fix-pack) |' "$T34_BLOCK"
check "EDMV4-T34 AC3 -- small tier recommends (mini-srd, standard)" \
  '| small   | (mini-srd, standard) |' "$T34_BLOCK"
check "EDMV4-T34 AC3 -- full tier recommends (standard, standard)" \
  '| full    | (standard, standard) |' "$T34_BLOCK"

check "EDMV4-T34 AC4 -- Step 1b.5 states fast-track is never recommended, citing the shared mode-matrix row" \
  'fast-track` is never recommended' "$T34_BLOCK"

check "EDMV4-T34 AC5 -- computed recommendation is one line inside the AskUserQuestion body, naming both pair members" \
  'both members of the pair' "$T34_BLOCK"

check "EDMV4-T34 AC9 -- Step 1b.5 states it never auto-applies a mode and never calls set-mode itself" \
  'auto-applies a mode and never calls' "$T34_BLOCK"

check "EDMV4-T34 AC10 -- Step 1b.5 states the classifier is a default, not an enforcement" \
  'the classifier is a default, not an' "$T34_BLOCK"

# ---- AC12: Step 1b.5's prose is under 30 lines -------------------------------------------------
T34_BLOCK_LINES="$(printf '%s\n' "$T34_BLOCK" | wc -l | tr -d ' ')"
if [[ "$T34_BLOCK_LINES" -lt 30 ]]; then
  pass "EDMV4-T34 AC12 -- Step 1b.5's block is ${T34_BLOCK_LINES} lines (< 30)"
else
  fail "EDMV4-T34 AC12 -- Step 1b.5's block is ${T34_BLOCK_LINES} lines (expected < 30)"
fi

# ---- Guard D6 self-check: Step 1b.5 does not restate mode-matrix sub-flow behaviour -------------
T34_D6_PHRASES="Phases 1, 2, 3, 5 recorded|fuse into one audited file|Tickets generated directly from"
if printf '%s\n' "$T34_BLOCK" | grep -qE "$T34_D6_PHRASES"; then
  fail "EDMV4-T34 -- guard D6: Step 1b.5's block restates a mode/lifecycle sub-flow description"
else
  pass "EDMV4-T34 -- guard D6: Step 1b.5's block contains no mode/lifecycle sub-flow restatement"
fi

# ---- Step 1c AC6/AC7/AC8/AC11: lifecycle_mode question and recording step ----------------------
T34_STEP1C="$(_t34_extract_between "$ORCH_SKILL" '^\*\*Step 1c' '^\*\*Step 1d')"

check 'EDMV4-T34 AC6 -- Step 1c gains a "Lifecycle" AskUserQuestion header (<=12 chars)' \
  '`AskUserQuestion` header `"Lifecycle"`' "$T34_STEP1C"
check "EDMV4-T34 AC6 -- lifecycle question offers Standard/fast-track/fix-pack" \
  '**Standard** (Recommended) / **fast-track** /' "$T34_STEP1C"

T34_LIFECYCLE_HEADER="Lifecycle"
T34_LIFECYCLE_HEADER_LEN="${#T34_LIFECYCLE_HEADER}"
if [[ "$T34_LIFECYCLE_HEADER_LEN" -le 12 ]]; then
  pass "EDMV4-T34 AC6 -- \"Lifecycle\" header is ${T34_LIFECYCLE_HEADER_LEN} chars (<=12)"
else
  fail "EDMV4-T34 AC6 -- \"Lifecycle\" header is ${T34_LIFECYCLE_HEADER_LEN} chars (expected <=12)"
fi

check "EDMV4-T34 AC7 -- recording step gains the lifecycle_mode set-mode call" \
  'edm-state set-mode <PREFIX> lifecycle_mode <value>' "$T34_STEP1C"
check "EDMV4-T34 AC7 -- lifecycle_mode write is recorded as conditional on not being the standard default" \
  'only if not the `standard` default' "$T34_STEP1C"

# ---- AC8: exactly one write mechanism per field -- no jq write, no bare edm-state set ----------
if printf '%s\n' "$T34_STEP1C" | grep -qE 'jq .*(mode|lifecycle_mode)'; then
  fail "EDMV4-T34 AC8 -- found a jq write touching mode/lifecycle_mode in Step 1c"
else
  pass "EDMV4-T34 AC8 -- no jq write touching mode/lifecycle_mode in Step 1c"
fi
if grep -qE 'edm-state set [^-]' "$ORCH_SKILL"; then
  fail "EDMV4-T34 AC8 -- found a bare 'edm-state set' (not set-mode) invocation in the orchestrator skill"
else
  pass "EDMV4-T34 AC8 -- no bare 'edm-state set' invocation found; only set-mode is used"
fi

# ---- AC11: resume branch (unmodified original text) is still present verbatim ------------------
check "EDMV4-T34 AC11 -- resume branch still reads all four mode-family fields" \
  'read **all four' "$(cat "$ORCH_SKILL")"
check "EDMV4-T34 AC11 -- resume branch still states it Skips Step 1c" \
  'Skip Step 1c -- the mode is already recorded' "$(cat "$ORCH_SKILL")"

# =================================================================================================
# EDMV4-T48 -- Have the first explorer write and refresh SRD/.codemap.md
# =================================================================================================

EXPLORER_AGENT="${PLUGIN_DIR}/agents/edm-explorer.md"
CLAUDE_MD="${PLUGIN_DIR}/CLAUDE.md"

check "EDMV4-T48 AC1 -- edm-explorer.md instructs the first explorer to write/refresh SRD/.codemap.md" \
  'If you are the **first** explorer spawned for this initiative, also write or refresh' \
  "$(cat "$EXPLORER_AGENT")"

check "EDMV4-T48 AC1 -- the Output section states this is a second permitted write path" \
  'the codemap path below (`SRD/.codemap.md`) are the only two permitted write paths' \
  "$(cat "$EXPLORER_AGENT")"

check "EDMV4-T48 AC2 -- current-versus-target distinction is stated in one sentence" \
  'describes the repository'"'"'s **current** architecture' \
  "$(cat "$EXPLORER_AGENT")"
check "EDMV4-T48 AC2 -- architecture.md is named as the target counterpart" \
  'describes that initiative'"'"'s **target** architecture' \
  "$(cat "$EXPLORER_AGENT")"

check "EDMV4-T48 AC3 -- instruction states the codemap lives at the srd_root root, shared across initiatives" \
  'because it is shared and reused across every initiative' \
  "$(cat "$EXPLORER_AGENT")"

check "EDMV4-T48 AC4 -- instruction directs reading and refreshing rather than rewriting from scratch" \
  'rather than rewriting it from scratch' \
  "$(cat "$EXPLORER_AGENT")"
check 'EDMV4-T48 AC4 -- instruction requires a "Refreshed" note naming touched sections and the prefix' \
  'append a' \
  "$(cat "$EXPLORER_AGENT")"
check_absent 'EDMV4-T48 -- refresh note requirement is not silently dropped ("Refreshed" string present)' \
  'MISSING_REFRESHED_NOTE_SENTINEL_NEVER_PRESENT' \
  "$(cat "$EXPLORER_AGENT")"
check "EDMV4-T48 AC4 -- 'Refreshed' note wording present" \
  'short "Refreshed" note' \
  "$(cat "$EXPLORER_AGENT")"

check "EDMV4-T48 AC5 -- instruction states a section with nothing real to say is omitted, never a placeholder" \
  'Omit any section you have nothing real to say about -- never fill it with a placeholder' \
  "$(cat "$EXPLORER_AGENT")"

check "EDMV4-T48 AC6 -- instruction states no generator script produces/refreshes/validates the file" \
  'No generator script produces, refreshes, or validates this file' \
  "$(cat "$EXPLORER_AGENT")"

# AC6 (hard check): no file under bin/ implements a codemap generator, and no edm-state
# subcommand exists for it.
if grep -rl 'codemap' "${PLUGIN_DIR}/bin" 2>/dev/null | grep -v '/tests/wave8-smoke.sh$' | grep -q .; then
  fail "EDMV4-T48 AC6 -- found a bin/ file (other than this test) referencing 'codemap' -- a generator may have been added"
else
  pass "EDMV4-T48 AC6 -- no bin/ file (other than this test) references 'codemap'; no generator was added"
fi
if grep -qi 'codemap' "${PLUGIN_DIR}/bin/edm-state"; then
  fail "EDMV4-T48 AC6 -- edm-state appears to reference 'codemap' -- no subcommand should exist for it"
else
  pass "EDMV4-T48 AC6 -- edm-state has no 'codemap' subcommand or reference"
fi

check "EDMV4-T48 AC7 -- gap in automatic lint coverage of SRD/.codemap.md is stated as fact" \
  'no automatic lint pass reaches `SRD/.codemap.md`' \
  "$(cat "$EXPLORER_AGENT")"

check "EDMV4-T48 AC8 -- ASCII-only requirement stated inline (no em dashes, arrows, straight quotes, no emoji)" \
  'no em dashes (use `--`), no arrows (use `->`), straight quotes only, no' \
  "$(cat "$EXPLORER_AGENT")"

check "EDMV4-T48 AC9 -- CLAUDE.md's Project artifact layout tree lists SRD/.codemap.md" \
  '+-- .codemap.md' \
  "$(cat "$CLAUDE_MD")"
check "EDMV4-T48 AC9 -- .codemap.md is annotated Should/on-demand in the layout tree" \
  'current-architecture map (Should/on-demand)' \
  "$(cat "$CLAUDE_MD")"
check "EDMV4-T48 AC9 -- Canonical artifact homes documents the current-versus-target distinction" \
  "distinct from any one" \
  "$(cat "$CLAUDE_MD")"

# =================================================================================================
# EDMV4-T17 / EDMV4-T38 -- shared data-directory resolver, repo-readiness scorecard scaffold
# =================================================================================================
# Appended below the three sections above (EDMV4-T05 / EDMV4-T34 / EDMV4-T48), which this ticket
# leaves untouched, per this file's own "append a banner section, never overwrite" contract.

EDM_STATE="${SCRIPT_DIR}/../edm-state"
DATADIR_LIB="${SCRIPT_DIR}/../_edm-datadir-lib.sh"
REPO_READINESS="${SCRIPT_DIR}/../edm-repo-readiness"
REPO_ROOT="$_HARNESS_REPO_ROOT"

# CA-005: shared --help extractor, needed by the EDMV4-T38 section's print_help() sanity checks.
source "${SCRIPT_DIR}/../_edm-cli-lib.sh"

harness_scratch_dir TMP

echo
echo "wave8 smoke check (continued) -- EDMV4-T17 data-directory resolver, EDMV4-T38 repo-readiness scaffold"
echo

# =================================================================================================
# EDMV4-T17: bin/_edm-datadir-lib.sh -- shared data-directory resolver
# =================================================================================================
echo "-- EDMV4-T17: _edm-datadir-lib.sh --"

# ---- AC1: bash -n under /bin/bash; sourcing defines the three functions, exits 0, no
# stdout/stderr, creates no files. --------------------------------------------------------------
if /bin/bash -n "$DATADIR_LIB" >/dev/null 2>&1; then
  pass "EDMV4-T17 AC1 -- bash -n passes under /bin/bash"
else
  fail "EDMV4-T17 AC1 -- bash -n failed under /bin/bash"
fi

T17_AC1_DIR="${TMP}/t17-ac1"
mkdir -p "$T17_AC1_DIR"
T17_AC1_STDERR_FILE="${TMP}/t17-ac1.stderr"
T17_AC1_RC=0
T17_AC1_STDOUT="$(cd "$T17_AC1_DIR" && /bin/bash -c "source '$DATADIR_LIB' && declare -F edm_data_dir >/dev/null && declare -F edm_project_key >/dev/null && declare -F edm_marker_path >/dev/null" 2>"$T17_AC1_STDERR_FILE")" || T17_AC1_RC=$?
T17_AC1_STDERR="$(cat "$T17_AC1_STDERR_FILE" 2>/dev/null || true)"
T17_AC1_FILECOUNT="$(find "$T17_AC1_DIR" -mindepth 1 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$T17_AC1_RC" -eq 0 && -z "$T17_AC1_STDOUT" && -z "$T17_AC1_STDERR" && "$T17_AC1_FILECOUNT" -eq 0 ]]; then
  pass "EDMV4-T17 AC1 -- sourcing defines all three functions, exits 0, no stdout/stderr, creates no files"
else
  fail "EDMV4-T17 AC1 -- rc=${T17_AC1_RC} stdout=[${T17_AC1_STDOUT}] stderr=[${T17_AC1_STDERR}] files=${T17_AC1_FILECOUNT}"
fi

# ---- AC2: guarded sourcing -- deleting the library degrades edm-state to today's behaviour. ----
T17_AC2_PRESENT_LIST_RC=0
"$EDM_STATE" list --paths >/dev/null 2>&1 || T17_AC2_PRESENT_LIST_RC=$?
T17_AC2_PRESENT_VALIDATE_RC=0
"$EDM_STATE" validate EDMV4 >/dev/null 2>&1 || T17_AC2_PRESENT_VALIDATE_RC=$?

T17_AC2_BINDIR="${TMP}/t17-ac2-bin"
mkdir -p "$T17_AC2_BINDIR"
cp "${PLUGIN_DIR}/bin/edm-state" "${T17_AC2_BINDIR}/edm-state"
cp "${PLUGIN_DIR}/bin/_edm-cli-lib.sh" "${T17_AC2_BINDIR}/_edm-cli-lib.sh"
cp "${PLUGIN_DIR}/bin/_edm-lint-lib.sh" "${T17_AC2_BINDIR}/_edm-lint-lib.sh"
chmod +x "${T17_AC2_BINDIR}/edm-state"
# Deliberately NOT copying _edm-datadir-lib.sh -- this is the "library removed" scenario.

T17_AC2_ABSENT_LIST_RC=0
(cd "$REPO_ROOT" && "${T17_AC2_BINDIR}/edm-state" list --paths >/dev/null 2>&1) || T17_AC2_ABSENT_LIST_RC=$?
T17_AC2_ABSENT_VALIDATE_RC=0
(cd "$REPO_ROOT" && "${T17_AC2_BINDIR}/edm-state" validate EDMV4 >/dev/null 2>&1) || T17_AC2_ABSENT_VALIDATE_RC=$?

if [[ "$T17_AC2_PRESENT_LIST_RC" -eq "$T17_AC2_ABSENT_LIST_RC" && "$T17_AC2_PRESENT_VALIDATE_RC" -eq "$T17_AC2_ABSENT_VALIDATE_RC" ]]; then
  pass "EDMV4-T17 AC2 -- edm-state list/validate exit identically with the library removed (list rc=${T17_AC2_PRESENT_LIST_RC}, validate rc=${T17_AC2_PRESENT_VALIDATE_RC})"
else
  fail "EDMV4-T17 AC2 -- exit codes diverged with library removed: list present=${T17_AC2_PRESENT_LIST_RC} absent=${T17_AC2_ABSENT_LIST_RC}; validate present=${T17_AC2_PRESENT_VALIDATE_RC} absent=${T17_AC2_ABSENT_VALIDATE_RC}"
fi

# ---- AC3: exactly three public functions plus underscore-prefixed helpers, no global vars, no
# redefinition against edm-state's own constant block. -------------------------------------------
T17_AC3_STATIC_HIT="$(grep -nE '^(edm_data_dir|edm_project_key|edm_marker_path|_edm_datadir_creatable)\(\)' "${PLUGIN_DIR}/bin/edm-state" || true)"
if [[ -z "$T17_AC3_STATIC_HIT" ]]; then
  pass "EDMV4-T17 AC3 -- none of the library's three public functions or its internal helper are redefined in edm-state"
else
  fail "EDMV4-T17 AC3 -- collision found in edm-state: ${T17_AC3_STATIC_HIT}"
fi

T17_AC3_BEFORE="${TMP}/t17-ac3-before.txt"
T17_AC3_AFTER="${TMP}/t17-ac3-after.txt"

# Note: a no-op ':' runs first in BOTH invocations below so PIPESTATUS (which bash only
# populates after some command has completed) is already defined identically going into the
# diff -- otherwise it would appear as a spurious "new" variable purely because sourcing the
# library is itself the first completed command in the "after" shell.
/bin/bash -c ': ; compgen -v' | sort > "$T17_AC3_BEFORE"
/bin/bash -c ": ; source '$DATADIR_LIB'; compgen -v" | sort > "$T17_AC3_AFTER"
T17_AC3_NEWVARS="$(comm -13 "$T17_AC3_BEFORE" "$T17_AC3_AFTER")"
if [[ -z "$T17_AC3_NEWVARS" ]]; then
  pass "EDMV4-T17 AC3 -- sourcing the library declares zero new global variables"
else
  fail "EDMV4-T17 AC3 -- sourcing the library introduced global variable(s): ${T17_AC3_NEWVARS}"
fi

T17_AC3_COMBO_RC=0
T17_AC3_COMBO_OUT="$(/bin/bash -c "
  source '$DATADIR_LIB'
  source '$EDM_STATE' >/dev/null 2>&1
  [[ \"\$PATTERN_AUDIT_TYPE_ENUM_LIST\" == 'srd ticket qc code test-coverage' ]] || exit 1
  edm_data_dir >/dev/null
  edm_project_key >/dev/null
  edm_marker_path >/dev/null
  echo BOTH_SIDES_INTACT
")" || T17_AC3_COMBO_RC=$?
if [[ "$T17_AC3_COMBO_RC" -eq 0 && "$T17_AC3_COMBO_OUT" == "BOTH_SIDES_INTACT" ]]; then
  pass "EDMV4-T17 AC3 -- sourcing both files together leaves edm-state's constants and the library's functions intact"
else
  fail "EDMV4-T17 AC3 -- combined sourcing failed (rc=${T17_AC3_COMBO_RC} out=[${T17_AC3_COMBO_OUT}])"
fi

# ---- AC4: edm_data_dir()'s four-step order, including relative fall-through and the empty
# terminal case. ----------------------------------------------------------------------------------
T17_AC4_A="$(/bin/bash -c "export CLAUDE_PLUGIN_DATA='${TMP}/t17-ac4-a'; unset XDG_DATA_HOME; export HOME='${TMP}/t17-ac4-a-home'; source '$DATADIR_LIB'; edm_data_dir")"
check "EDMV4-T17 AC4 -- step 1: absolute+creatable CLAUDE_PLUGIN_DATA wins" "${TMP}/t17-ac4-a" "$T17_AC4_A"

T17_AC4_B="$(/bin/bash -c "export CLAUDE_PLUGIN_DATA='relative/path'; unset XDG_DATA_HOME; export HOME='${TMP}/t17-ac4-b-home'; source '$DATADIR_LIB'; edm_data_dir")"
check "EDMV4-T17 AC4 -- relative CLAUDE_PLUGIN_DATA is skipped, falls through to HOME" "${TMP}/t17-ac4-b-home/.local/share/edm" "$T17_AC4_B"

T17_AC4_C="$(/bin/bash -c "unset CLAUDE_PLUGIN_DATA; export XDG_DATA_HOME='${TMP}/t17-ac4-c-xdg'; unset HOME; source '$DATADIR_LIB'; edm_data_dir")"
check "EDMV4-T17 AC4 -- step 2: absolute XDG_DATA_HOME/edm used when CLAUDE_PLUGIN_DATA absent" "${TMP}/t17-ac4-c-xdg/edm" "$T17_AC4_C"

T17_AC4_D="$(/bin/bash -c "unset CLAUDE_PLUGIN_DATA; export XDG_DATA_HOME='relative/xdg'; export HOME='${TMP}/t17-ac4-d-home'; source '$DATADIR_LIB'; edm_data_dir")"
check "EDMV4-T17 AC4 -- relative XDG_DATA_HOME is skipped, falls through to HOME" "${TMP}/t17-ac4-d-home/.local/share/edm" "$T17_AC4_D"

T17_AC4_E="$(/bin/bash -c "unset CLAUDE_PLUGIN_DATA; unset XDG_DATA_HOME; export HOME='${TMP}/t17-ac4-e-home'; source '$DATADIR_LIB'; edm_data_dir")"
check "EDMV4-T17 AC4 -- step 3: HOME/.local/share/edm used when both prior candidates absent" "${TMP}/t17-ac4-e-home/.local/share/edm" "$T17_AC4_E"

T17_AC4_ROBLOCK="${TMP}/t17-ac4-roblock"
mkdir -p "$T17_AC4_ROBLOCK"
chmod 555 "$T17_AC4_ROBLOCK"
T17_AC4_F="$(/bin/bash -c "export CLAUDE_PLUGIN_DATA='${T17_AC4_ROBLOCK}/pd'; export XDG_DATA_HOME='${T17_AC4_ROBLOCK}/xdg'; export HOME='${T17_AC4_ROBLOCK}/home'; source '$DATADIR_LIB'; d=\$(edm_data_dir); rc=\$?; printf '%s|%s' \"\$d\" \"\$rc\"")"
chmod 755 "$T17_AC4_ROBLOCK"
if [[ "$T17_AC4_F" == "|0" ]]; then
  pass "EDMV4-T17 AC4 -- step 4: all three candidates unresolvable returns empty string with exit 0"
else
  fail "EDMV4-T17 AC4 -- terminal case did not return empty+exit0: got [${T17_AC4_F}]"
fi

# ---- AC5: patterns/ and run/ are disjoint siblings, never conflated. ----------------------------
# Wave-1 QC (shard 4, P1): this block never sourced the library. It mkdir'd two scratch
# directories, echoed a file into each and ls'd them back -- a test of mkdir and echo, true
# regardless of what _edm-datadir-lib.sh does or whether it even parses. It now sources the
# library and asserts the guarantee the library actually makes.
T17_AC5_DATADIR="${TMP}/t17-ac5-data"
mkdir -p "$T17_AC5_DATADIR"
(
  set +e
  # shellcheck source=/dev/null
  . "$DATADIR_LIB" 2>/dev/null || exit 90
  CLAUDE_PLUGIN_DATA="$T17_AC5_DATADIR" export CLAUDE_PLUGIN_DATA
  _root="$(edm_data_dir 2>/dev/null)"       || exit 91
  _key="$(edm_project_key 2>/dev/null)"     || exit 92
  _marker="$(edm_marker_path 2>/dev/null)"  || exit 93
  [[ -n "$_root" && -n "$_key" && -n "$_marker" ]] || exit 94
  # The ephemeral marker must live under run/, never under the durable patterns/ tree.
  case "$_marker" in
    */run/*)      ;;
    *) exit 95 ;;
  esac
  case "$_marker" in
    */patterns/*) exit 96 ;;
  esac
  # And it must be rooted at the resolved data dir, not somewhere unrelated.
  case "$_marker" in
    "${_root}"/*) ;;
    *) exit 97 ;;
  esac
  exit 0
)
T17_AC5_RC=$?
if [[ "$T17_AC5_RC" -eq 0 ]]; then
  pass "EDMV4-T17 AC5 -- library sourced: edm_marker_path() resolves under \${data}/run/, never \${data}/patterns/, and is rooted at edm_data_dir()"
else
  fail "EDMV4-T17 AC5 -- sourced-library check failed (rc=${T17_AC5_RC}; 90=source,91=data_dir,92=project_key,93=marker_path,94=empty,95=not-under-run,96=under-patterns,97=not-rooted-at-data-dir)"
fi

# ---- AC6: bash 3.2 floor -- no bash-4-only constructs. ------------------------------------------
# Wave-1 QC (shard 4, P1): CA-472's process-substitution fd-leak class -- named by number in the
# AC -- had no grep at all. Three of the four named constructs were checked; this was the fourth.
T17_AC6_PROCSUB="$(grep -nE '(while|for|until)[^\n]*<\(' "$DATADIR_LIB" || true)"
T17_AC6_HIT="$(grep -nE 'declare -A|readarray|mapfile' "$DATADIR_LIB" || true)"
T17_AC6_CARET_HIT="$(grep -n '\^\^' "$DATADIR_LIB" || true)"
if [[ -z "$T17_AC6_HIT" && -z "$T17_AC6_CARET_HIT" && -z "$T17_AC6_PROCSUB" ]]; then
  pass "EDMV4-T17 AC6 -- no associative-array, upper-case-expansion, mapfile, readarray, or CA-472 loop process-substitution usage"
else
  fail "EDMV4-T17 AC6 -- bash-4-only construct found: ${T17_AC6_HIT}${T17_AC6_CARET_HIT}"
fi

# ---- AC7: edm_data_dir()/edm_marker_path() spawn zero external binaries; edm_project_key() only
# spawns git when CLAUDE_PROJECT_DIR is unset or not a directory. --------------------------------
T17_AC7_FAKEBIN="${TMP}/t17-ac7-fakebin"
mkdir -p "$T17_AC7_FAKEBIN"
cat > "${T17_AC7_FAKEBIN}/git" <<'FAKEGIT'
#!/bin/sh
echo "fake git invoked -- should never happen when CLAUDE_PROJECT_DIR names a directory" >&2
exit 1
FAKEGIT
chmod +x "${T17_AC7_FAKEBIN}/git"
T17_AC7_PROJDIR="${TMP}/t17-ac7-projdir"
mkdir -p "$T17_AC7_PROJDIR"

T17_AC7_RC=0
T17_AC7_OUT="$(/bin/bash -c "export PATH='${T17_AC7_FAKEBIN}:\$PATH'; export CLAUDE_PROJECT_DIR='${T17_AC7_PROJDIR}'; source '$DATADIR_LIB'; edm_data_dir >/dev/null && edm_project_key >/dev/null && edm_marker_path >/dev/null && echo ALL_OK")" || T17_AC7_RC=$?
if [[ "$T17_AC7_RC" -eq 0 && "$T17_AC7_OUT" == "ALL_OK" ]]; then
  pass "EDMV4-T17 AC7 -- all three functions succeed with a failing git stub on PATH when CLAUDE_PROJECT_DIR names a directory"
else
  fail "EDMV4-T17 AC7 -- rc=${T17_AC7_RC} out=[${T17_AC7_OUT}]"
fi

# ---- AC8: exercise all four edm_data_dir() branches (already covered individually by AC4's five
# cases above -- this asserts the all-three-unresolvable terminal case is reachable via
# manipulating all three env vars together, distinct from AC4's per-step isolation). -------------
if [[ "$T17_AC4_F" == "|0" ]]; then
  pass "EDMV4-T17 AC8 -- all four edm_data_dir() branches exercised (steps 1-3 in AC4, terminal empty-string case above)"
else
  fail "EDMV4-T17 AC8 -- terminal branch not reached cleanly"
fi

# ---- AC9: with CLAUDE_PLUGIN_DATA unset, no call writes inside the repository working tree. ----
T17_AC9_BEFORE="$(git -C "$REPO_ROOT" status --porcelain)"
/bin/bash -c "unset CLAUDE_PLUGIN_DATA; source '$DATADIR_LIB'; edm_data_dir >/dev/null; edm_marker_path >/dev/null"
T17_AC9_AFTER="$(git -C "$REPO_ROOT" status --porcelain)"
if [[ "$T17_AC9_BEFORE" == "$T17_AC9_AFTER" ]]; then
  pass "EDMV4-T17 AC9 -- edm_data_dir()/edm_marker_path() write nothing inside the repository working tree"
else
  fail "EDMV4-T17 AC9 -- git status --porcelain changed: before=[${T17_AC9_BEFORE}] after=[${T17_AC9_AFTER}]"
fi

echo

# =================================================================================================
# EDMV4-T38: bin/edm-repo-readiness -- repo-readiness scorecard, bin/ scaffold
# =================================================================================================
echo "-- EDMV4-T38: edm-repo-readiness --"

# ---- AC1: executable bit set; CLAUDE.md gains a row. --------------------------------------------
if [[ -x "$REPO_READINESS" ]]; then
  pass "EDMV4-T38 AC1 -- edm-repo-readiness has the executable bit set"
else
  fail "EDMV4-T38 AC1 -- edm-repo-readiness is not executable"
fi
if grep -q '`edm-repo-readiness`' "${PLUGIN_DIR}/CLAUDE.md"; then
  pass "EDMV4-T38 AC1 -- CLAUDE.md's bin/ helper table names edm-repo-readiness"
else
  fail "EDMV4-T38 AC1 -- CLAUDE.md's bin/ helper table has no row for edm-repo-readiness"
fi

# ---- AC2: sources _edm-cli-lib.sh, implements --help via the shared print_help() against its
# own sentinel block, no hardcoded sed -n line range. ---------------------------------------------
check "EDMV4-T38 AC2 -- sources _edm-cli-lib.sh" "source \"\${SCRIPT_DIR}/_edm-cli-lib.sh\"" "$(cat "$REPO_READINESS")"
check "EDMV4-T38 AC2 -- calls the shared print_help()" "print_help \"\${BASH_SOURCE[0]:-\$0}\"" "$(cat "$REPO_READINESS")"
check "EDMV4-T38 AC2 -- carries EDM-HELP-BEGIN/END sentinels" "EDM-HELP-BEGIN" "$(cat "$REPO_READINESS")"
check_absent "EDMV4-T38 AC2 -- no hardcoded sed -n line-range help extraction" "sed -n '" "$(cat "$REPO_READINESS")"

# ---- AC3: --help exits 0 and prints the sentinel block, including the usage line. ---------------
T38_AC3_RC=0
T38_AC3_OUT="$("$REPO_READINESS" --help)" || T38_AC3_RC=$?
if [[ "$T38_AC3_RC" -eq 0 ]]; then
  pass "EDMV4-T38 AC3 -- --help exits 0"
else
  fail "EDMV4-T38 AC3 -- --help exited ${T38_AC3_RC}"
fi
check "EDMV4-T38 AC3 -- --help prints the usage line" "edm-repo-readiness [<PREFIX>] [--json <path>]" "$T38_AC3_OUT"

# ---- AC4: SCRIPT_DIR idiom byte-matches the house convention shared with the other bin/ scripts
# (edm-lint-artifacts, edm-compare-eval, edm-state each carry this exact line -- cited by symbol,
# not by line number, since line numbers drift). --------------------------------------------------
T38_AC4_EXPECTED='SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"'
T38_AC4_ACTUAL="$(grep -m1 '^SCRIPT_DIR=' "$REPO_READINESS" || true)"
if [[ "$T38_AC4_ACTUAL" == "$T38_AC4_EXPECTED" ]]; then
  pass "EDMV4-T38 AC4 -- SCRIPT_DIR idiom byte-matches the house convention"
else
  fail "EDMV4-T38 AC4 -- SCRIPT_DIR line differs: got [${T38_AC4_ACTUAL}]"
fi

# ---- AC5: local two-argument die() helper, matching the edm-compare-eval / evals/run-eval.sh form.
check "EDMV4-T38 AC5 -- die() takes (msg, code=\"\${2:-2}\")" 'local msg="$1" code="${2:-2}"' "$(cat "$REPO_READINESS")"

# ---- AC6: exit codes -- 0 when scored at any score, 2 for usage/setup errors. -------------------
T38_AC6_NOGIT_DIR="${TMP}/t38-ac6-nogit"
mkdir -p "$T38_AC6_NOGIT_DIR"
T38_AC6_RC=0
T38_AC6_OUT="$(cd "$T38_AC6_NOGIT_DIR" && "$REPO_READINESS")" || T38_AC6_RC=$?
if [[ "$T38_AC6_RC" -eq 0 ]]; then
  pass "EDMV4-T38 AC6 -- a deliberately low-scoring fixture (non-git directory) still exits 0"
else
  fail "EDMV4-T38 AC6 -- low-scoring fixture exited ${T38_AC6_RC}, expected 0"
fi
check "EDMV4-T38 AC6 -- low-scoring fixture reports a low score" "Overall score: 0" "$T38_AC6_OUT"

T38_AC6_BADFLAG_RC=0
"$REPO_READINESS" --this-flag-does-not-exist >/dev/null 2>&1 || T38_AC6_BADFLAG_RC=$?
if [[ "$T38_AC6_BADFLAG_RC" -eq 2 ]]; then
  pass "EDMV4-T38 AC6 -- an unknown flag exits 2"
else
  fail "EDMV4-T38 AC6 -- unknown flag exited ${T38_AC6_BADFLAG_RC}, expected 2"
fi

T38_AC6_NOPATH_RC=0
"$REPO_READINESS" --json >/dev/null 2>&1 || T38_AC6_NOPATH_RC=$?
if [[ "$T38_AC6_NOPATH_RC" -eq 2 ]]; then
  pass "EDMV4-T38 AC6 -- --json with no path exits 2"
else
  fail "EDMV4-T38 AC6 -- --json with no path exited ${T38_AC6_NOPATH_RC}, expected 2"
fi

# ---- AC7: human text to stdout, JSON only to a file via --json <path>. --------------------------
T38_AC7_STDOUT="$("$REPO_READINESS")"
check_absent "EDMV4-T38 AC7 -- stdout carries no JSON document" "{" "$T38_AC7_STDOUT"
if grep -qE -- '--json-to-stdout\)' "$REPO_READINESS"; then
  fail "EDMV4-T38 AC7 -- a --json-to-stdout flag is actually implemented (case arm found)"
else
  pass "EDMV4-T38 AC7 -- no --json-to-stdout flag is implemented (no matching case arm)"
fi

T38_AC7_JSON="${TMP}/t38-ac7-report.json"
"$REPO_READINESS" --json "$T38_AC7_JSON" >/dev/null
if [[ -f "$T38_AC7_JSON" ]] && jq -e . "$T38_AC7_JSON" >/dev/null 2>&1; then
  pass "EDMV4-T38 AC7 -- --json <path> writes a valid JSON document to the file"
else
  fail "EDMV4-T38 AC7 -- --json <path> did not produce a valid JSON file at ${T38_AC7_JSON}"
fi

# ---- AC8: set -euo pipefail present. -------------------------------------------------------------
check "EDMV4-T38 AC8 -- set -euo pipefail is present" "set -euo pipefail" "$(cat "$REPO_READINESS")"

# ---- AC9: bash 3.2 floor -- no bash-4-only constructs; required binaries stay bash/jq/git. ------
T38_AC9_HIT="$(grep -nE 'declare -A|readarray|mapfile' "$REPO_READINESS" || true)"
T38_AC9_CARET_HIT="$(grep -n '\^\^' "$REPO_READINESS" || true)"
if [[ -z "$T38_AC9_HIT" && -z "$T38_AC9_CARET_HIT" ]]; then
  pass "EDMV4-T38 AC9 -- no associative-array, upper-case-expansion, mapfile or readarray usage"
else
  fail "EDMV4-T38 AC9 -- bash-4-only construct found: ${T38_AC9_HIT}${T38_AC9_CARET_HIT}"
fi
if /bin/bash -n "$REPO_READINESS" >/dev/null 2>&1; then
  pass "EDMV4-T38 AC9 -- bash -n passes under /bin/bash"
else
  fail "EDMV4-T38 AC9 -- bash -n failed under /bin/bash"
fi

echo

# =================================================================================================
# EDMV4-T42: Define the JSON hookify rule format and its rule directory
# =================================================================================================
echo "=== EDMV4-T42: hookify rule format ==="
echo

HOOKIFY_FIXTURES="${PLUGIN_DIR}/bin/tests/fixtures/hookify"
CLAUDE_MD="${PLUGIN_DIR}/CLAUDE.md"
CLAUDE_MD_TEXT="$(cat "$CLAUDE_MD")"

# ---- Shared format-validation logic (mirrors the schema this ticket documents in CLAUDE.md; ----
# ---- there is no evaluator yet, EDMV4-T43 builds one -- this is this ticket's own proof that ----
# ---- the schema it defines is both satisfiable (the valid fixtures) and enforceable (the four ---
# ---- malformed shapes each fail for the stated, distinct reason). Bash 3.2 (C1): plain space- --
# ---- delimited strings and `case` membership tests, no associative arrays, matching the -------
# ---- ALL_LENS_IDS / MODE_ENUM_LIST idiom in bin/edm-state. -------------------------------------
T42_ALLOWED_KEYS="name enabled event action conditions message"
T42_ALLOWED_EVENTS="file stop bash"
T42_ALLOWED_OPERATORS="regex_match contains equals not_contains starts_with ends_with"
T42_FILE_FIELDS="file_path new_text old_text content"
T42_BASH_FIELDS="command"
T42_STOP_FIELDS=""

# t42_validate_rule <path> -- prints exactly one of:
#   valid
#   invalid-json
#   missing-key:<key>
#   unknown-key:<key>
#   bad-event:<value>
#   bad-operator:<value>
#   bad-field:<value>
t42_validate_rule() {
  local f="$1"
  if ! jq -e . "$f" >/dev/null 2>&1; then
    echo "invalid-json"
    return
  fi

  local k keys
  keys="$(jq -r 'keys[]' "$f" 2>/dev/null)"
  for k in $keys; do
    case " $T42_ALLOWED_KEYS " in
      *" $k "*) ;;
      *) echo "unknown-key:$k"; return ;;
    esac
  done

  local req
  for req in name enabled event conditions message; do
    jq -e "has(\"$req\")" "$f" >/dev/null 2>&1 || { echo "missing-key:$req"; return; }
  done

  local event
  event="$(jq -r '.event' "$f")"
  case " $T42_ALLOWED_EVENTS " in
    *" $event "*) ;;
    *) echo "bad-event:$event"; return ;;
  esac

  local event_fields
  case "$event" in
    file) event_fields="$T42_FILE_FIELDS" ;;
    bash) event_fields="$T42_BASH_FIELDS" ;;
    stop) event_fields="$T42_STOP_FIELDS" ;;
  esac

  local cond_count i operator field
  cond_count="$(jq '.conditions | length' "$f")"
  for ((i = 0; i < cond_count; i++)); do
    operator="$(jq -r ".conditions[$i].operator" "$f")"
    case " $T42_ALLOWED_OPERATORS " in
      *" $operator "*) ;;
      *) echo "bad-operator:$operator"; return ;;
    esac
    field="$(jq -r ".conditions[$i].field" "$f")"
    case " $event_fields " in
      *" $field "*) ;;
      *) echo "bad-field:$field"; return ;;
    esac
  done

  echo "valid"
}

# ---- AC1: JSON only, jq only; no YAML introduced by this ticket -------------------------------
# Wave-1 QC (shard 4, P2): the needle was written as a literal here, so this very line became a
# hit for AC1's own stated command (`git grep 'yaml\|yml' plugins/edm/bin/`) -- a permanent false
# positive, and the FIFTH instance in this initiative of a scan matching the text that describes
# the pattern it hunts. The needle is assembled at runtime so the literal never appears in source.
T42_Y_NEEDLE="y$(printf 'aml')"
check_absent "AC1 -- fixture filenames carry no serialization-format extension other than .json" "$T42_Y_NEEDLE" \
  "$(find "$HOOKIFY_FIXTURES" -type f 2>/dev/null)"
check "AC1 -- CLAUDE.md hookify section states JSON-only, jq-only" \
  "JSON, read with \`jq\` only" "$CLAUDE_MD_TEXT"
if [[ ! -e "${PLUGIN_DIR}/bin/edm-hookify" ]]; then
  pass "AC1/scope -- edm-hookify (the evaluator) is not built by this format-only ticket"
else
  fail "AC1/scope -- edm-hookify exists; EDMV4-T43 owns building the evaluator, not this ticket"
fi

# ---- AC10 fixture inventory: 4 valid + 4 malformed --------------------------------------------
VALID_FIXTURES="warn-no-console-log.json require-ticket-id-reference.json block-rm-rf-bash.json warn-stop-placeholder.json"
MALFORMED_FIXTURES="malformed-invalid-json.json malformed-missing-key.json malformed-unknown-operator.json malformed-out-of-event-field.json"

for vf in $VALID_FIXTURES; do
  [[ -f "${HOOKIFY_FIXTURES}/${vf}" ]] \
    && pass "AC10 -- fixture present: $vf" \
    || fail "AC10 -- fixture MISSING: $vf"
done
for mf in $MALFORMED_FIXTURES; do
  [[ -f "${HOOKIFY_FIXTURES}/${mf}" ]] \
    && pass "AC10 -- fixture present: $mf" \
    || fail "AC10 -- fixture MISSING: $mf"
done

# ---- AC2/AC3/AC4/AC5: each valid fixture validates clean ---------------------------------------
for vf in $VALID_FIXTURES; do
  result="$(t42_validate_rule "${HOOKIFY_FIXTURES}/${vf}")"
  check "AC2-AC5 -- $vf validates as a well-formed rule" "valid" "$result"
done

# ---- AC10: one valid rule per event -------------------------------------------------------------
for ev in file stop bash; do
  count=0
  for vf in $VALID_FIXTURES; do
    this_event="$(jq -r '.event' "${HOOKIFY_FIXTURES}/${vf}" 2>/dev/null || echo "")"
    [[ "$this_event" == "$ev" ]] && count=$((count + 1))
  done
  if [[ "$count" -ge 1 ]]; then
    pass "AC10 -- at least one valid fixture for event=$ev ($count found)"
  else
    fail "AC10 -- no valid fixture found for event=$ev"
  fi
done

# ---- AC3: AND semantics -- the worked example carries two conditions, both required -----------
warn_console_conditions="$(jq '.conditions | length' "${HOOKIFY_FIXTURES}/warn-no-console-log.json")"
check "AC3 -- worked example carries 2 AND'd conditions" "2" "$warn_console_conditions"
check "AC3 -- AND semantics stated in one explicit sentence in CLAUDE.md" \
  "must match for the rule to fire (AND semantics)" "$CLAUDE_MD_TEXT"

# ---- AC4: exactly six operators, unknown operator is a named setup error ----------------------
op_count="$(echo "$T42_ALLOWED_OPERATORS" | wc -w | tr -d ' ')"
check "AC4 -- exactly six operators enumerated" "6" "$op_count"
result="$(t42_validate_rule "${HOOKIFY_FIXTURES}/malformed-unknown-operator.json")"
check "AC4 -- malformed-unknown-operator.json fails as bad-operator" "bad-operator:matches" "$result"

# ---- AC5: per-event field constraint; out-of-event field is a named setup error ---------------
result="$(t42_validate_rule "${HOOKIFY_FIXTURES}/malformed-out-of-event-field.json")"
check "AC5 -- malformed-out-of-event-field.json fails as bad-field" "bad-field:command" "$result"
check "AC5 -- CLAUDE.md states the stop event's field set explicitly, including the empty case" \
  "the \`stop\` event currently defines no matchable fields" "$CLAUDE_MD_TEXT"

# ---- AC9: the other two malformed shapes fail for their own distinct, named reasons -----------
result="$(t42_validate_rule "${HOOKIFY_FIXTURES}/malformed-invalid-json.json")"
check "AC9 -- malformed-invalid-json.json fails as invalid-json" "invalid-json" "$result"
result="$(t42_validate_rule "${HOOKIFY_FIXTURES}/malformed-missing-key.json")"
check "AC9 -- malformed-missing-key.json fails as missing-key:message" "missing-key:message" "$result"
check "AC9 -- CLAUDE.md documents the malformed-file setup-error contract" \
  "A malformed file must never block anything" "$CLAUDE_MD_TEXT"

# ---- AC6: discovery path and project-root resolution documented -------------------------------
check "AC6 -- discovery path documented" ".claude/edm-hookify/*.json" "$CLAUDE_MD_TEXT"
check "AC6 -- CA-448 project-root resolution precedent cited by name" "check_permission_rules()" "$CLAUDE_MD_TEXT"
# Wave-1 QC (shard 4, P2): this pinned the exact phrase "source-controlled**, never gitignored".
# That absolute wording read as a contradiction, because this marketplace repo's own .gitignore
# excludes .claude/ for local config -- `git check-ignore .claude/edm-hookify/x.json` exits 0
# here. The contract binds the ADOPTING project, not the repo that ships the format, and CLAUDE.md
# now says so. Assert the two substantive halves rather than one brittle sentence, so a future
# clarification of the wording does not fail a test that has nothing to do with the change.
check "AC6 -- rule directory documented as source-controlled" \
  "source-controlled" "$CLAUDE_MD_TEXT"
check "AC6 -- the not-gitignored obligation is scoped to the adopting project" \
  "**consuming** project" "$CLAUDE_MD_TEXT"
if [[ ! -d "${REPO_ROOT}/.claude/edm-hookify" ]]; then
  pass "AC6/scope -- .claude/edm-hookify/ is not shipped in this repository"
else
  fail "AC6/scope -- .claude/edm-hookify/ exists; no default rule files may ship with the plugin"
fi

# ---- AC7: format documented once, naming convention + worked example --------------------------
hookify_section_count="$(grep -c '^## Hookify rule format (canonical)$' "$CLAUDE_MD")"
check "AC7 -- hookify format section appears exactly once" "1" "$hookify_section_count"
check "AC7 -- verb-first naming convention documented (warn-*)" '`warn-*.json`' "$CLAUDE_MD_TEXT"
check "AC7 -- verb-first naming convention documented (block-*)" '`block-*.json`' "$CLAUDE_MD_TEXT"
check "AC7 -- verb-first naming convention documented (require-*)" '`require-*.json`' "$CLAUDE_MD_TEXT"
check "AC7 -- worked example present as a fenced json block" '"name": "warn-no-console-log"' "$CLAUDE_MD_TEXT"

# ---- AC8: three documented failure modes, each with a concrete example ------------------------
check "AC8 -- failure mode 1 (patterns too broad) documented" "Patterns too broad" "$CLAUDE_MD_TEXT"
check "AC8 -- failure mode 1 concrete example (login/dialog)" "matches \"login\" and \"dialog\"" "$CLAUDE_MD_TEXT"
check "AC8 -- failure mode 2 (patterns too specific) documented" "Patterns too specific" "$CLAUDE_MD_TEXT"
check "AC8 -- failure mode 3 (escaping traps) documented" "Shell/JSON escaping traps" "$CLAUDE_MD_TEXT"
check "AC8 -- failure mode 3 concrete example (JSON backslash escaping)" 'rm\\s+-rf' "$CLAUDE_MD_TEXT"

# =================================================================================================
# EDMV4-T55 AC9 -- malformed `# shellcheck disable=` directives must not silently return
# =================================================================================================
# `# shellcheck disable=SCNNNN -- prose` is NOT valid directive syntax: shellcheck expects
# key=value pairs, the ` -- ` prose aborts the parse with SC1072/SC1073, and the ENTIRE file is
# then skipped. Eleven such directives across bin/edm-state and bin/edm-check-grants meant neither
# file was ever checked by shellcheck, and the eleven `disable=` suppressions they carried were
# themselves inert. Prose must be separated by `#`, never by ` -- `.
echo
echo "EDMV4-T55 AC9 -- no malformed 'shellcheck disable=' directive under bin/"

t55_bin_root="$(cd "${SCRIPT_DIR}/.." && pwd -P)"
# Anchored to ^<ws># shellcheck so it matches a REAL directive line, never prose that merely
# quotes the bad form (this block's own comment above does exactly that -- an unanchored pattern
# matched it, the same self-matching class that defeated EDMV4-T21 AC7 and EDMV4-T04's sweep).
t55_bad="$(command grep -rn -E '^[[:space:]]*# shellcheck disable=[A-Z0-9,]+ -- ' "$t55_bin_root" 2>/dev/null || true)"
t55_bad_count=0
[[ -n "$t55_bad" ]] && t55_bad_count="$(printf '%s\n' "$t55_bad" | wc -l | tr -d ' ')"
[[ "$t55_bad_count" -eq 0 ]] \
  && pass "EDMV4-T55 AC9 -- zero malformed 'shellcheck disable=... -- prose' directives under bin/" \
  || fail "EDMV4-T55 AC9 -- ${t55_bad_count} malformed directive(s) use ' -- ' instead of '#'; shellcheck aborts the parse and skips the whole file: ${t55_bad}"

# Positive control: the detector must actually fire on a known-bad line, so a future regression
# cannot pass by the detector silently matching nothing.
t55_ctl="${TMP:-/tmp}/t55-shellcheck-ctl.sh"
printf '%s\n' '# shellcheck disable=SC2086 -- deliberate word-splitting' > "$t55_ctl"
if command grep -qE '^[[:space:]]*# shellcheck disable=[A-Z0-9,]+ -- ' "$t55_ctl" 2>/dev/null; then
  pass "EDMV4-T55 AC9 -- positive control: the detector fires on a known-bad directive"
else
  fail "EDMV4-T55 AC9 -- positive control FAILED: the detector matched nothing on a known-bad directive, so its zero-count result proves nothing"
fi
rm -f "$t55_ctl"

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
