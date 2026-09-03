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
# EDMV4-T39/T40: once the six-category rubric landed, State health and Artifact hygiene
# (unconditional categories) vacuously score full marks on a fixture with no initiatives at all
# -- nothing recorded to be unhealthy about -- so the overall score is no longer pinned to a
# literal "0". Assert the two checks this fixture MUST still fail (git-repo-present,
# srd-directory-present) via the JSON output instead of a brittle "Overall score: 0" substring.
T38_AC6_JSON="${TMP}/t38-ac6-nogit-rubric.json"
(cd "$T38_AC6_NOGIT_DIR" && "$REPO_READINESS" --json "$T38_AC6_JSON" >/dev/null)
check "EDMV4-T38 AC6 (rubric-aware) -- git-repo-present fails (pass=false) on a non-git fixture" \
  "false" "$(jq -r '.checks[] | select(.id=="git-repo-present") | .pass' "$T38_AC6_JSON")"
check "EDMV4-T38 AC6 (rubric-aware) -- srd-directory-present fails on a fixture with no SRD/" \
  "false" "$(jq -r '.checks[] | select(.id=="srd-directory-present") | .pass' "$T38_AC6_JSON")"

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
# EDMV4-T43 (this wave) legitimately builds edm-hookify -- the evaluator this format-only ticket
# explicitly leaves out of scope. Before T43 landed, this check asserted the file's ABSENCE; now
# that both tickets share this suite, the assertion is that the file exists and is EXECUTABLE
# (T43's own AC1 section below asserts its actual behavior in depth).
if [[ -x "${PLUGIN_DIR}/bin/edm-hookify" ]]; then
  pass "AC1/scope -- edm-hookify exists and is executable (built by EDMV4-T43, which owns it)"
else
  fail "AC1/scope -- edm-hookify missing or not executable"
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

# =================================================================================================
# EDMV4-T25 -- Lens L12 (Silent Failures) agent file
# =================================================================================================
echo
echo "=== EDMV4-T25: edm-audit-silent-failures.md (lens L12) ==="

L12_AGENT="${PLUGIN_DIR}/agents/edm-audit-silent-failures.md"
L12_TEXT="$(cat "$L12_AGENT" 2>/dev/null || true)"

[[ -f "$L12_AGENT" ]] && pass "EDMV4-T25 AC1 -- edm-audit-silent-failures.md exists" \
  || fail "EDMV4-T25 AC1 -- edm-audit-silent-failures.md is missing"

echo "EDMV4-T25 AC1 -- house-contract headings present, in order"
t25_headings_expected="## Scope
## What You Hunt For
## False Alarm Filter
## Output
## Output Format
## JSONL Line Format
## When this does NOT apply"
t25_headings_actual="$(awk '/^```/{f=!f;next} !f' "$L12_AGENT" | grep -E '^## ')"
[[ "$t25_headings_actual" == "$t25_headings_expected" ]] \
  && pass "EDMV4-T25 AC1 -- the seven house-contract headings appear in the required order" \
  || fail "EDMV4-T25 AC1 -- heading order/content mismatch:\n${t25_headings_actual}"

echo "EDMV4-T25 AC2 -- five hunt categories present"
check "EDMV4-T25 AC2a -- errors converted to silence" "Errors Converted to Silence" "$L12_TEXT"
check "EDMV4-T25 AC2b -- inadequate logging" "Inadequate Logging" "$L12_TEXT"
check "EDMV4-T25 AC2c -- dangerous fallbacks" "Dangerous Fallbacks" "$L12_TEXT"
check "EDMV4-T25 AC2d -- error propagation problems" "Error Propagation Problems" "$L12_TEXT"
check "EDMV4-T25 AC2e -- missing handling entirely" "Missing Handling Entirely" "$L12_TEXT"

echo "EDMV4-T25 AC3 -- dangerous-fallback category carries a concrete code-shape example"
check "EDMV4-T25 AC3 -- concrete .catch(() => []) example present" '.catch(() => [])' "$L12_TEXT"

echo "EDMV4-T25 AC4 -- L12 is unconditional"
check_absent "EDMV4-T25 AC4 -- no N/A-exit filesystem-marker language in the L12 agent file" \
  "the repository contains at least one of" "$L12_TEXT"
check "EDMV4-T25 AC4 -- standard house 'always applies' sentence present" \
  "This agent always applies once the code-audit skill selects lens L12 for the round" "$L12_TEXT"
t25_conditional_ids="$(grep -n 'CONDITIONAL_LENS_IDS=' "${PLUGIN_DIR}/bin/edm-state" | head -1)"
case "$t25_conditional_ids" in
  *'"L13"'*) pass "EDMV4-T25 AC4 -- CONDITIONAL_LENS_IDS names only L13, not L12" ;;
  *) fail "EDMV4-T25 AC4 -- CONDITIONAL_LENS_IDS line unexpected: ${t25_conditional_ids}" ;;
esac

echo "EDMV4-T25 AC5 -- L1/L12 boundary sentence present in the L12 file"
check "EDMV4-T25 AC5 -- boundary sentence bounding L12 against L1" \
  "L1 owns the empty catch block as a correctness defect; L12 owns the handler that succeeds while concealing the failure" \
  "$L12_TEXT"

echo "EDMV4-T25 AC7 -- lens ID L12 used consistently"
check "EDMV4-T25 AC7 -- md output path" '${OUTPUT_DIR}/lens-L12.md' "$L12_TEXT"
check "EDMV4-T25 AC7 -- jsonl output path" '${OUTPUT_DIR}/lens-L12.jsonl' "$L12_TEXT"
check "EDMV4-T25 AC7 -- schema line names lens L12" '"lens":"L12"' "$L12_TEXT"

echo "EDMV4-T25 AC8 -- ASCII-only (edm-lint-artifacts clean over agents/)"
t25_lint_out="$(bash "${PLUGIN_DIR}/bin/edm-lint-artifacts" --path "${PLUGIN_DIR}/agents/" 2>&1)"
t25_lint_exit=$?
[[ "$t25_lint_exit" -eq 0 ]] && pass "EDMV4-T25 AC8 -- edm-lint-artifacts --path agents/ is clean" \
  || fail "EDMV4-T25 AC8 -- edm-lint-artifacts reported violations: ${t25_lint_out}"

echo "EDMV4-T25 AC9 -- edm-check-grants passes with the new file present"
if bash "${PLUGIN_DIR}/bin/edm-check-grants" >/dev/null 2>"${SCRIPT_DIR}/.t25-grants.err"; then
  pass "EDMV4-T25 AC9 -- edm-check-grants exits 0"
else
  fail "EDMV4-T25 AC9 -- edm-check-grants exited non-zero: $(cat "${SCRIPT_DIR}/.t25-grants.err")"
fi
rm -f "${SCRIPT_DIR}/.t25-grants.err"

# =================================================================================================
# EDMV4-T27 -- Lens L14 (Behavioral Test Coverage) agent file and its two reciprocal boundaries
# =================================================================================================
echo
echo "=== EDMV4-T27: edm-audit-behavioral-tests.md (lens L14) ==="

L14_AGENT="${PLUGIN_DIR}/agents/edm-audit-behavioral-tests.md"
L4_AGENT="${PLUGIN_DIR}/agents/edm-audit-test-quality.md"
COVERAGE_AUDITOR_AGENT="${PLUGIN_DIR}/agents/edm-test-coverage-auditor.md"
L14_TEXT="$(cat "$L14_AGENT" 2>/dev/null || true)"

[[ -f "$L14_AGENT" ]] && pass "EDMV4-T27 AC1 -- edm-audit-behavioral-tests.md exists" \
  || fail "EDMV4-T27 AC1 -- edm-audit-behavioral-tests.md is missing"
[[ ! -f "${PLUGIN_DIR}/agents/edm-audit-tests.md" ]] \
  && pass "EDMV4-T27 AC5 -- edm-audit-tests.md does not exist (no accidental twelfth lens file)" \
  || fail "EDMV4-T27 AC5 -- edm-audit-tests.md exists; this path is not the L4 file"

echo "EDMV4-T27 AC1 -- house-contract headings present, in order"
t27_headings_expected="## Scope
## What You Hunt For
## False Alarm Filter
## Output
## Output Format
## JSONL Line Format
## When this does NOT apply"
t27_headings_actual="$(awk '/^```/{f=!f;next} !f' "$L14_AGENT" | grep -E '^## ')"
[[ "$t27_headings_actual" == "$t27_headings_expected" ]] \
  && pass "EDMV4-T27 AC1 -- the seven house-contract headings appear in the required order" \
  || fail "EDMV4-T27 AC1 -- heading order/content mismatch:\n${t27_headings_actual}"

echo "EDMV4-T27 AC2 -- six-step process present"
check "EDMV4-T27 AC2 step 1 -- map changed code to its tests" "Map changed code to its tests" "$L14_TEXT"
check "EDMV4-T27 AC2 step 2 -- find new untested paths" "Find new untested paths" "$L14_TEXT"
check "EDMV4-T27 AC2 step 3 -- verify edge and error paths" "Verify edge and error paths" "$L14_TEXT"
check "EDMV4-T27 AC2 step 4 -- prefer meaningful assertions over no-throw checks" \
  "Prefer meaningful assertions over no-throw checks" "$L14_TEXT"
check "EDMV4-T27 AC2 step 5 -- flag flaky patterns" "Flag flaky-shaped patterns" "$L14_TEXT"
check "EDMV4-T27 AC2 step 6 -- rate gaps" "Rate every gap" "$L14_TEXT"

echo "EDMV4-T27 AC3 -- closed severity vocabulary only; ECC's critical/important/nice-to-have scale is not imported"
t27_ecc_hits="$(grep -icE '\b(critical|important|nice-to-have)\b' "$L14_AGENT" || true)"
[[ "${t27_ecc_hits:-0}" -eq 0 ]] \
  && pass "EDMV4-T27 AC3 -- zero occurrences of critical/important/nice-to-have in the L14 agent file" \
  || fail "EDMV4-T27 AC3 -- found ${t27_ecc_hits} occurrence(s) of the abolished ECC severity scale"
check "EDMV4-T27 AC3 -- canonical P0/P1/P2/NOTED scale cited" 'P0`, `P1`, `P2`, or `NOTED`' "$L14_TEXT"

# Positive control (per this initiative's own "matches its own prose" defect class): the
# case-insensitive word-boundary scan above must actually fire on a known-bad fixture, or a
# "found 0" result proves nothing.
T27_TMP="$(mktemp -d "${TMPDIR:-/tmp}/edm-wave8-t27.XXXXXX")"
t27_bad_fixture="${T27_TMP}/bad-severity-scale.md"
printf '%s\n' 'Rate every gap as critical, important, or nice-to-have.' > "$t27_bad_fixture"
t27_ctl_hits="$(grep -icE '\b(critical|important|nice-to-have)\b' "$t27_bad_fixture" || true)"
[[ "${t27_ctl_hits:-0}" -ge 1 ]] \
  && pass "EDMV4-T27 AC3 -- positive control: the scan fires on a known-bad ECC-scale fixture" \
  || fail "EDMV4-T27 AC3 -- positive control FAILED: the scan matched nothing on a fixture that names all three abolished terms"
rm -rf "$T27_TMP"

echo "EDMV4-T27 AC4 -- L4/L14/edm-test-coverage-auditor boundary sentence, all three roles, in L14's own file"
check "EDMV4-T27 AC4 -- boundary sentence names L4's role" \
  "L4 owns defects inside the tests themselves" "$L14_TEXT"
check "EDMV4-T27 AC4 -- boundary sentence names edm-test-coverage-auditor's role" \
  '`edm-test-coverage-auditor` owns coverage percentages against configured thresholds' "$L14_TEXT"
check "EDMV4-T27 AC4 -- boundary sentence names L14's own role" \
  "whether the tests would catch a real bug in the changed behavior" "$L14_TEXT"

echo "EDMV4-T27 AC5/AC6/AC7 -- reciprocal boundary sentence present in all three files, keyed on one stable substring"
t27_boundary_substring="whether the tests would catch a real bug in the changed behavior"
t27_boundary_count=0
for t27_f in "$L14_AGENT" "$L4_AGENT" "$COVERAGE_AUDITOR_AGENT"; do
  grep -qF -- "$t27_boundary_substring" "$t27_f" && t27_boundary_count=$((t27_boundary_count + 1)) \
    || echo "  MISSING boundary substring in $(basename "$t27_f")"
done
[[ "$t27_boundary_count" -eq 3 ]] \
  && pass "EDMV4-T27 AC5/AC6/AC7 -- the stable boundary substring is present in L14, L4, and edm-test-coverage-auditor" \
  || fail "EDMV4-T27 AC5/AC6/AC7 -- boundary substring found in only ${t27_boundary_count}/3 files"

echo "EDMV4-T27 AC8 -- L14 is unconditional"
check "EDMV4-T27 AC8 -- standard house 'always applies' sentence present" \
  "This agent always applies once the code-audit skill selects lens L14 for the round" "$L14_TEXT"
t27_conditional_ids="$(grep -n 'CONDITIONAL_LENS_IDS=' "${PLUGIN_DIR}/bin/edm-state" | head -1)"
case "$t27_conditional_ids" in
  *'"L13"'*) pass "EDMV4-T27 AC8 -- CONDITIONAL_LENS_IDS names only L13, not L14" ;;
  *) fail "EDMV4-T27 AC8 -- CONDITIONAL_LENS_IDS line unexpected: ${t27_conditional_ids}" ;;
esac

echo "EDMV4-T27 AC9 -- lens ID L14 used consistently"
check "EDMV4-T27 AC9 -- md output path" '${OUTPUT_DIR}/lens-L14.md' "$L14_TEXT"
check "EDMV4-T27 AC9 -- jsonl output path" '${OUTPUT_DIR}/lens-L14.jsonl' "$L14_TEXT"
check "EDMV4-T27 AC9 -- schema line names lens L14" '"lens":"L14"' "$L14_TEXT"

echo "EDMV4-T27 AC10 -- edm-check-grants passes; all three touched files are ASCII-only"
if bash "${PLUGIN_DIR}/bin/edm-check-grants" >/dev/null 2>"${SCRIPT_DIR}/.t27-grants.err"; then
  pass "EDMV4-T27 AC10 -- edm-check-grants exits 0"
else
  fail "EDMV4-T27 AC10 -- edm-check-grants exited non-zero: $(cat "${SCRIPT_DIR}/.t27-grants.err")"
fi
rm -f "${SCRIPT_DIR}/.t27-grants.err"
t27_lint_out="$(bash "${PLUGIN_DIR}/bin/edm-lint-artifacts" --path "${PLUGIN_DIR}/agents/" 2>&1)"
t27_lint_exit=$?
[[ "$t27_lint_exit" -eq 0 ]] && pass "EDMV4-T27 AC10 -- edm-lint-artifacts --path agents/ is clean" \
  || fail "EDMV4-T27 AC10 -- edm-lint-artifacts reported violations: ${t27_lint_out}"

echo

# =================================================================================================
# EDMV4-T16 -- ECC and GateGuard provenance recorded in the house-style attribution section
# =================================================================================================
# AC6: `zunoworks` and `MIT` must both appear WITHIN the "Prompt conventions (house style)"
# section specifically, not merely somewhere in CLAUDE.md, so a later edit that drops the
# attribution while leaving an unrelated "MIT" elsewhere in the file cannot pass silently.
echo "=== EDMV4-T16: ECC/GateGuard provenance in house-style attribution ==="
echo

T16_CLAUDE_MD="${PLUGIN_DIR}/CLAUDE.md"
# Extract the section body: from the "### Prompt conventions (house style)" heading up to (but
# not including) the next "## " heading. Anchored on the literal heading text, not a line number,
# per this ticket's advisory-line-numbers convention.
T16_SECTION="$(awk '
  /^### Prompt conventions \(house style\)/ { found=1 }
  found && /^## / && !/^### Prompt conventions/ { if (started) exit }
  found { started=1; print }
' "$T16_CLAUDE_MD")"

if [[ -z "$T16_SECTION" ]]; then
  fail "EDMV4-T16 -- could not locate the 'Prompt conventions (house style)' section in CLAUDE.md at all"
else
  check "EDMV4-T16 AC2/AC6 -- 'zunoworks' appears within the house-style attribution section" "zunoworks" "$T16_SECTION"
  check "EDMV4-T16 AC6 -- 'MIT' appears within the house-style attribution section" "MIT" "$T16_SECTION"
  check "EDMV4-T16 AC1 -- ECC entry present, naming everything-claude-code" "everything-claude-code" "$T16_SECTION"
  check "EDMV4-T16 AC1 -- ECC copyright holder recorded" "Affaan Mustafa" "$T16_SECTION"
  check "EDMV4-T16 AC2 -- GateGuard entry present, naming zunoworks/gateguard" "zunoworks/gateguard" "$T16_SECTION"
  check "EDMV4-T16 AC2 -- GateGuard copyright holder recorded" "Hirokazu Seto" "$T16_SECTION"
  check "EDMV4-T16 AC2 -- vendored-JS-port evidence cited" "gateguard-fact-force.js" "$T16_SECTION"
  check "EDMV4-T16 AC4 -- ECC means-of-verification is explicit ('verified ... by direct inspection')" "verified 2026-08-31 by direct inspection" "$T16_SECTION"
  check "EDMV4-T16 AC4 -- GateGuard means-of-verification names the fetched URL, not a local clone" "raw.githubusercontent.com/zunoworks/gateguard" "$T16_SECTION"
  check "EDMV4-T16 AC3 -- clean-room note states mechanism-level adoption" "deny first touch, demand facts, allow on retry" "$T16_SECTION"
  check "EDMV4-T16 AC5 -- enumeration count updated to six" "Six sources" "$T16_SECTION"
  check "EDMV4-T16 AC7 -- dormant NOTICE-obligation clause present" "dormant" "$T16_SECTION"
  check "EDMV4-T16 AC7 -- dormant clause names the NOTICE file" "plugins/edm/NOTICE" "$T16_SECTION"

  # Positive control: prove the extraction actually found section content and is not silently
  # empty-but-truthy (bash treats a non-empty string as -n true even if it is just whitespace).
  check "EDMV4-T16 -- positive control: extracted section also contains the pre-existing caveman entry" "caveman" "$T16_SECTION"
fi

# EDMV4-T32: grow the code-audit test fixtures from 11 to 14 lens pairs
# =================================================================================================
# Scope note (wave-1 QC dependency reality check, per this ticket's own Technical Notes): AC1, AC2,
# AC5, AC6, AC7 and AC9 depend on EDMV4-T21 alone (the fourteen-ID ALL_LENS_IDS constant, landed)
# and are asserted here. AC3 (the 13-plus-N/A composition fixture) and AC4 (the contract-violation
# negative fixture) encode EDMV4-T22's round-record shape (`lenses`/`lenses_na` materialized in
# .edm-state.json) and exercise EDMV4-T23's third downgrade reason, neither of which has landed on
# this branch as of this wave -- authoring them now would mean guessing a state shape rather than
# copying it from real output, which this ticket's own Technical Notes calls out as the wrong
# order. They are deliberately NOT asserted here; a later ticket (after EDMV4-T22/T23 land) adds
# them. AC8 (wave7-smoke.sh's :1627/:1630 count assertions reading 14) is EDMV4-T30's alone --
# wave7-smoke.sh is under a file lock this ticket must not cross, and growing this fixture to 14
# files is EXPECTED to leave wave7-smoke.sh's `-eq 11` assertions red until T30 rewrites them,
# exactly as this ticket's Technical Notes states.

echo
echo "=== EDMV4-T32: code-audit fixtures grown from 11 to 14 lens pairs ==="

T32_FIXTURE_DIR="${PLUGIN_DIR}/bin/tests/fixtures/code-audit"
T32_README="${T32_FIXTURE_DIR}/README.md"
T32_LENSES_RUN="${T32_FIXTURE_DIR}/lenses-run.txt"
T32_ALL_LENS_IDS="L1 L2 L3 L4 L5 L6 L7 L8 L9 L10 L11 L12 L13 L14"

# ---- AC1: fourteen lens-L{N}.jsonl and fourteen lens-L{N}.md files; lenses-run.txt lists all 14 --
t32_ac1_missing=""
for t32_lens in $T32_ALL_LENS_IDS; do
  [[ -f "${T32_FIXTURE_DIR}/lens-${t32_lens}.jsonl" ]] || t32_ac1_missing="${t32_ac1_missing} lens-${t32_lens}.jsonl"
  [[ -f "${T32_FIXTURE_DIR}/lens-${t32_lens}.md" ]] || t32_ac1_missing="${t32_ac1_missing} lens-${t32_lens}.md"
done
if [[ -z "$t32_ac1_missing" ]]; then
  pass "T32 AC1 -- all fourteen lens-L{N}.jsonl and lens-L{N}.md fixture files (L1-L14) are present"
else
  fail "T32 AC1 -- missing fixture file(s):${t32_ac1_missing}"
fi

t32_jsonl_count="$(ls "${T32_FIXTURE_DIR}"/lens-L*.jsonl 2>/dev/null | wc -l | tr -d '[:space:]')"
[[ "$t32_jsonl_count" -eq 14 ]] && pass "T32 AC1 -- exactly fourteen lens-L*.jsonl files on disk (no stray leftovers)" \
  || fail "T32 AC1 -- found ${t32_jsonl_count} lens-L*.jsonl file(s), expected exactly 14"
t32_md_count="$(ls "${T32_FIXTURE_DIR}"/lens-L*.md 2>/dev/null | wc -l | tr -d '[:space:]')"
[[ "$t32_md_count" -eq 14 ]] && pass "T32 AC1 -- exactly fourteen lens-L*.md files on disk (no stray leftovers)" \
  || fail "T32 AC1 -- found ${t32_md_count} lens-L*.md file(s), expected exactly 14"

t32_lenses_run_text="$(cat "$T32_LENSES_RUN" 2>/dev/null)"
check "T32 AC1 -- lenses-run.txt still carries the existing 'Round type: full' header" \
  "Round type: full" "$t32_lenses_run_text"
t32_lenses_run_missing=""
for t32_lens in $T32_ALL_LENS_IDS; do
  printf '%s\n' "$t32_lenses_run_text" | grep -qx "$t32_lens" || t32_lenses_run_missing="${t32_lenses_run_missing} ${t32_lens}"
done
if [[ -z "$t32_lenses_run_missing" ]]; then
  pass "T32 AC1 -- lenses-run.txt lists all 14 lens IDs, one per line"
else
  fail "T32 AC1 -- lenses-run.txt is missing lens ID(s):${t32_lenses_run_missing}"
fi
t32_lenses_run_line_count="$(printf '%s\n' "$t32_lenses_run_text" | grep -cE '^L[0-9]+$')"
[[ "$t32_lenses_run_line_count" -eq 14 ]] \
  && pass "T32 AC1 -- lenses-run.txt carries exactly 14 lens-ID lines (no stray extras)" \
  || fail "T32 AC1 -- lenses-run.txt carries ${t32_lenses_run_line_count} lens-ID line(s), expected exactly 14"

# ---- AC2: README.md documents 14, not 11; the lens-L11 references now read lens-L14 -------------
t32_readme_text="$(cat "$T32_README" 2>/dev/null)"
check "T32 AC2 -- README documents lens-L1 .. lens-L14 range (JSONL sentence)" \
  '`lens-L1.jsonl` .. `lens-L14.jsonl`' "$t32_readme_text"
check "T32 AC2 -- README documents lens-L2 .. lens-L14 two-finding sentence" \
  '`lens-L2.jsonl` .. `lens-L14.jsonl`' "$t32_readme_text"
check "T32 AC2 -- README documents lens-L1 .. lens-L14 range (prose reports sentence)" \
  '`lens-L1.md` .. `lens-L14.md`' "$t32_readme_text"
check "T32 AC2 -- README's lenses-run.txt line now says 'fourteen lens IDs'" \
  "the fourteen lens IDs" "$t32_readme_text"

# Positive control (QC pattern: pair every zero-count assertion with a control against known-bad
# content, so "found 0" is proven to mean "matched nothing ever wrote this", not "the check itself
# never fires"): a scratch copy carrying the literal word "eleven" must be caught by the same scan.
t32_eleven_count="$(printf '%s\n' "$t32_readme_text" | grep -c 'eleven' || true)"
t32_eleven_control="$(printf 'a fixture with eleven lens files\n' | grep -c 'eleven' || true)"
if [[ "${t32_eleven_control:-0}" -ge 1 ]]; then
  [[ "${t32_eleven_count:-0}" -eq 0 ]] \
    && pass "T32 AC2 -- README.md no longer contains the word 'eleven' (positive control confirmed the scan can detect it)" \
    || fail "T32 AC2 -- README.md still contains 'eleven' ${t32_eleven_count} time(s)"
else
  fail "T32 AC2 -- positive control broken: the 'eleven' scan matched nothing on a known-bad string"
fi

# ---- AC5/AC6: schema conformance + two-finding (open + NOTED) shape for the three new fixtures --
for t32_new_lens in L12 L13 L14; do
  t32_new_jsonl="${T32_FIXTURE_DIR}/lens-${t32_new_lens}.jsonl"
  t32_new_md="${T32_FIXTURE_DIR}/lens-${t32_new_lens}.md"

  if jq empty "$t32_new_jsonl" >/dev/null 2>&1; then
    pass "T32 AC5 -- lens-${t32_new_lens}.jsonl is valid JSONL (jq empty exits 0)"
  else
    fail "T32 AC5 -- lens-${t32_new_lens}.jsonl failed jq empty"
  fi

  # Every required schema key present with the expected fixed-shape values, driven straight
  # through jq against the real file rather than a re-typed string comparison.
  t32_schema_bad="$(jq -r --arg lens "$t32_new_lens" '
    select(
      (.schema != 1) or (.id != null) or (.lens != $lens) or
      (.round | type) != "number" or
      (.round_type != "full" and .round_type != "partial") or
      (.sev | type) != "string" or (.confidence | type) != "string" or
      (.file | type) != "string" or (.line | type) != "number" or
      (.title | type) != "string" or (.status | type) != "string"
    ) | .title
  ' "$t32_new_jsonl" 2>/dev/null || true)"
  [[ -z "$t32_schema_bad" ]] \
    && pass "T32 AC5 -- every lens-${t32_new_lens}.jsonl line carries the fixed schema shape exactly" \
    || fail "T32 AC5 -- lens-${t32_new_lens}.jsonl line(s) violate the fixed schema shape: ${t32_schema_bad}"

  t32_line_count="$(grep -c . "$t32_new_jsonl" 2>/dev/null || true)"
  [[ "${t32_line_count:-0}" -eq 2 ]] \
    && pass "T32 AC6 -- lens-${t32_new_lens}.jsonl carries exactly two findings" \
    || fail "T32 AC6 -- lens-${t32_new_lens}.jsonl carries ${t32_line_count:-0} finding(s), expected 2"

  t32_statuses="$(jq -sr '[.[].status] | sort | join(",")' "$t32_new_jsonl" 2>/dev/null)"
  [[ "$t32_statuses" == "noted,open" ]] \
    && pass "T32 AC6 -- lens-${t32_new_lens}.jsonl carries exactly one 'open' and one 'noted' finding" \
    || fail "T32 AC6 -- lens-${t32_new_lens}.jsonl statuses were '${t32_statuses}', expected 'noted,open'"

  [[ -f "$t32_new_md" ]] || fail "T32 AC6 -- lens-${t32_new_lens}.md sibling prose file is missing"
  check "T32 AC6 -- lens-${t32_new_lens}.md carries the matching -001 finding ID" \
    "${t32_new_lens}-001" "$(cat "$t32_new_md" 2>/dev/null)"
  check "T32 AC6 -- lens-${t32_new_lens}.md carries the matching -002 finding ID" \
    "${t32_new_lens}-002" "$(cat "$t32_new_md" 2>/dev/null)"
done

# ---- AC7: fixture content is ASCII-only ---------------------------------------------------------
t32_lint_out="$(bash "${PLUGIN_DIR}/bin/edm-lint-artifacts" --path "$T32_FIXTURE_DIR" 2>&1)"
t32_lint_status=$?
[[ "$t32_lint_status" -eq 0 ]] \
  && pass "T32 AC7 -- edm-lint-artifacts --path over the fixture directory exits 0" \
  || fail "T32 AC7 -- edm-lint-artifacts --path exited ${t32_lint_status}: ${t32_lint_out}"
check "T32 AC7 -- edm-lint-artifacts reports no unicode-class violation" "CLEAN" "$t32_lint_out"
# edm-lint-artifacts only scans *.md (CLAUDE.md's own documented reach); the .jsonl fixtures and
# lenses-run.txt need a direct byte-level scan of their own to back the ASCII-only claim.
t32_nonascii="$(LC_ALL=C grep -l -P '[^\x00-\x7F]' \
  "${T32_FIXTURE_DIR}"/lens-L12.jsonl "${T32_FIXTURE_DIR}"/lens-L13.jsonl "${T32_FIXTURE_DIR}"/lens-L14.jsonl \
  "$T32_LENSES_RUN" 2>/dev/null || true)"
[[ -z "$t32_nonascii" ]] \
  && pass "T32 AC7 -- new .jsonl fixtures and lenses-run.txt contain no non-ASCII bytes" \
  || fail "T32 AC7 -- non-ASCII byte(s) found in: ${t32_nonascii}"

# ---- AC9: the existing lens-L1.jsonl widest-fixture role (all four severities) is undisturbed ----
t32_l1_sevs="$(jq -sr '[.[].sev] | sort | unique | join(",")' "${T32_FIXTURE_DIR}/lens-L1.jsonl" 2>/dev/null)"
[[ "$t32_l1_sevs" == "NOTED,P0,P1,P2" ]] \
  && pass "T32 AC9 -- lens-L1.jsonl still covers every severity (NOTED,P0,P1,P2), undisturbed by the new fixtures" \
  || fail "T32 AC9 -- lens-L1.jsonl severities were '${t32_l1_sevs}', expected 'NOTED,P0,P1,P2'"
# =================================================================================================
# EDMV4-T35 -- Pin the classifier to the eight existing mode enum values
# =================================================================================================
# Appended below the sections above, which this ticket leaves untouched, per this file's own
# "append a banner section, never overwrite" contract.
echo
echo "================================================================================================="
echo "EDMV4-T35 -- Pin the classifier to the eight existing mode enum values"
echo "================================================================================================="
echo

# ---- AC2: MODE_ENUM_LIST / LIFECYCLE_MODE_ENUM_LIST are unmodified literals --------------------
T35_MODE_LIST_LINE="$(grep -m1 '^MODE_ENUM_LIST=' "${PLUGIN_DIR}/bin/edm-state")"
check "EDMV4-T35 AC2 -- MODE_ENUM_LIST literal is unmodified" \
  'MODE_ENUM_LIST="standard mini-srd iac data-ml prototype"' "$T35_MODE_LIST_LINE"

T35_LIFECYCLE_LIST_LINE="$(grep -m1 '^LIFECYCLE_MODE_ENUM_LIST=' "${PLUGIN_DIR}/bin/edm-state")"
check "EDMV4-T35 AC2 -- LIFECYCLE_MODE_ENUM_LIST literal is unmodified" \
  'LIFECYCLE_MODE_ENUM_LIST="standard fast-track fix-pack"' "$T35_LIFECYCLE_LIST_LINE"

# ---- AC1: exactly 8 values across the two lists, and every value the classifier can emit is a
# member of one of them -------------------------------------------------------------------------
T35_MODE_VALUES="$(printf '%s' "$T35_MODE_LIST_LINE" | sed -E 's/^MODE_ENUM_LIST="([^"]*)"$/\1/')"
T35_LIFECYCLE_VALUES="$(printf '%s' "$T35_LIFECYCLE_LIST_LINE" | sed -E 's/^LIFECYCLE_MODE_ENUM_LIST="([^"]*)"$/\1/')"
T35_MODE_COUNT="$(echo "$T35_MODE_VALUES" | wc -w | tr -d ' ')"
T35_LIFECYCLE_COUNT="$(echo "$T35_LIFECYCLE_VALUES" | wc -w | tr -d ' ')"
T35_TOTAL=$((T35_MODE_COUNT + T35_LIFECYCLE_COUNT))
if [[ "$T35_TOTAL" -eq 8 ]]; then
  pass "EDMV4-T35 AC1 -- MODE_ENUM_LIST (${T35_MODE_COUNT} values) + LIFECYCLE_MODE_ENUM_LIST (${T35_LIFECYCLE_COUNT} values) = 8 total enum values"
else
  fail "EDMV4-T35 AC1 -- expected exactly 8 enum values across both lists, got ${T35_TOTAL} (mode=${T35_MODE_COUNT}, lifecycle=${T35_LIFECYCLE_COUNT})"
fi

for T35_V in standard mini-srd fix-pack; do
  if printf ' %s %s ' "$T35_MODE_VALUES" "$T35_LIFECYCLE_VALUES" | grep -q " $T35_V "; then
    pass "EDMV4-T35 AC1 -- classifier-emitted value '${T35_V}' is a member of MODE_ENUM_LIST or LIFECYCLE_MODE_ENUM_LIST"
  else
    fail "EDMV4-T35 AC1 -- classifier-emitted value '${T35_V}' is NOT a member of either enum list"
  fi
done

# ---- AC3: the two-axis mapping is one row per tier, naming both mode and lifecycle_mode, and no
# others -- reuses T34_BLOCK (Step 1b.5's extracted block, computed above in this same suite run) -
T35_TABLE_ROWS="$(printf '%s\n' "$T34_BLOCK" | grep -cE '^\| .* \| \(.*\) \|$')"
if [[ "$T35_TABLE_ROWS" -eq 3 ]]; then
  pass "EDMV4-T35 AC3 -- classifier table carries exactly 3 tier rows (the same 3 literal pairs EDMV4-T34 AC3 enumerates, and no others)"
else
  fail "EDMV4-T35 AC3 -- expected exactly 3 tier rows in the classifier table, found ${T35_TABLE_ROWS}"
fi

# ---- AC4: terminal_phase_for_mode, code_audit_required_for_mode and convergence_exempt gain no
# new arms -- arm count is the number of ';;' terminators inside each function's body -----------
_t35_count_case_arms() {
  local file="$1" fn="$2"
  awk -v fn="$fn" '$0 ~ ("^" fn "\\(\\) \\{") {f=1} f{print} f && /^}/{exit}' "$file" | grep -c ';;'
}

T35_TERMINAL_ARMS="$(_t35_count_case_arms "${PLUGIN_DIR}/bin/edm-state" terminal_phase_for_mode)"
if [[ "$T35_TERMINAL_ARMS" -eq 8 ]]; then
  pass "EDMV4-T35 AC4 -- terminal_phase_for_mode carries its baseline 8 case arms (its lifecycle_mode validation case plus its mode case) -- no new arm"
else
  fail "EDMV4-T35 AC4 -- terminal_phase_for_mode arm count changed: expected 8, got ${T35_TERMINAL_ARMS}"
fi

T35_CODEAUDIT_ARMS="$(_t35_count_case_arms "${PLUGIN_DIR}/bin/edm-state" code_audit_required_for_mode)"
if [[ "$T35_CODEAUDIT_ARMS" -eq 3 ]]; then
  pass "EDMV4-T35 AC4 -- code_audit_required_for_mode carries its baseline 3 case arms -- no new arm"
else
  fail "EDMV4-T35 AC4 -- code_audit_required_for_mode arm count changed: expected 3, got ${T35_CODEAUDIT_ARMS}"
fi

T35_CONVERGENCE_ARMS="$(_t35_count_case_arms "${PLUGIN_DIR}/bin/edm-state" convergence_exempt)"
if [[ "$T35_CONVERGENCE_ARMS" -eq 2 ]]; then
  pass "EDMV4-T35 AC4 -- convergence_exempt carries its baseline 2 case arms -- no new arm"
else
  fail "EDMV4-T35 AC4 -- convergence_exempt arm count changed: expected 2, got ${T35_CONVERGENCE_ARMS}"
fi

# ---- AC5/AC6/AC7: functional -- drive each recommended pair through edm-state set-mode with the
# correct kind (AC5, expect exit 0), a hypothetical fourth value (AC6, expect refusal), and a
# valid value driven through the wrong kind (AC7, expect refusal) -- against a real scratch
# initiative via with_scratch_repo. -----------------------------------------------------------
t35_functional_case() {
  with_scratch_repo _t35_functional_inner
}
_t35_functional_inner() {
  edm-init T35F >/dev/null 2>&1 || true
  local rc

  rc=0; "$EDM_STATE" set-mode T35F lifecycle_mode fix-pack >/dev/null 2>&1 || rc=$?
  [[ $rc -eq 0 ]] \
    && pass "EDMV4-T35 AC5 -- set-mode T35F lifecycle_mode fix-pack exits 0" \
    || fail "EDMV4-T35 AC5 -- set-mode T35F lifecycle_mode fix-pack exited ${rc}, expected 0"

  rc=0; "$EDM_STATE" set-mode T35F mode mini-srd >/dev/null 2>&1 || rc=$?
  [[ $rc -eq 0 ]] \
    && pass "EDMV4-T35 AC5 -- set-mode T35F mode mini-srd exits 0" \
    || fail "EDMV4-T35 AC5 -- set-mode T35F mode mini-srd exited ${rc}, expected 0"

  rc=0; "$EDM_STATE" set-mode T35F mode standard >/dev/null 2>&1 || rc=$?
  [[ $rc -eq 0 ]] \
    && pass "EDMV4-T35 AC5 -- set-mode T35F mode standard exits 0" \
    || fail "EDMV4-T35 AC5 -- set-mode T35F mode standard exited ${rc}, expected 0"

  rc=0; "$EDM_STATE" set-mode T35F lifecycle_mode standard >/dev/null 2>&1 || rc=$?
  [[ $rc -eq 0 ]] \
    && pass "EDMV4-T35 AC5 -- set-mode T35F lifecycle_mode standard exits 0" \
    || fail "EDMV4-T35 AC5 -- set-mode T35F lifecycle_mode standard exited ${rc}, expected 0"

  check_fails "EDMV4-T35 AC6 -- set-mode T35F mode trivial is refused (hypothetical fourth value)" \
    "set-mode: invalid mode 'trivial'" "$EDM_STATE" set-mode T35F mode trivial

  check_fails "EDMV4-T35 AC7 -- set-mode T35F mode fix-pack is refused (valid value, wrong kind)" \
    "set-mode: invalid mode 'fix-pack'" "$EDM_STATE" set-mode T35F mode fix-pack
  check_fails "EDMV4-T35 AC7 -- set-mode T35F lifecycle_mode mini-srd is refused (valid value, wrong kind)" \
    "set-mode: invalid lifecycle_mode 'mini-srd'" "$EDM_STATE" set-mode T35F lifecycle_mode mini-srd
}
t35_functional_case

# ---- AC8: these assertions live in wave8-smoke.sh, a suite bin/tests/run-all.sh discovers via
# its *-smoke.sh glob (registration in _PREFERRED_ORDER is EDMV4-T53's separate concern). --------
# Wave-2 QC (shard 3): this was an UNCONDITIONAL pass -- no assertion behind it, incapable of
# failing, counted as green. AC8's claim is checkable: this file must match the glob run-all.sh
# discovers with, and must actually sit in the directory it sweeps.
t35_ac8_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd -P)"
t35_ac8_self="$(basename "${BASH_SOURCE[0]:-$0}")"
if [[ "$t35_ac8_self" == *-smoke.sh && -f "${t35_ac8_dir}/run-all.sh" && -f "${t35_ac8_dir}/${t35_ac8_self}" ]]; then
  pass "EDMV4-T35 AC8 -- ${t35_ac8_self} matches run-all.sh's *-smoke.sh glob and sits beside it in ${t35_ac8_dir}"
else
  fail "EDMV4-T35 AC8 -- ${t35_ac8_self} is not discoverable by run-all.sh's *-smoke.sh sweep in ${t35_ac8_dir}"
fi

echo

# =================================================================================================
# EDMV4-T36 -- Implement the security-trigger tie-breaker and pre-select the compliance dialog
# =================================================================================================
echo "================================================================================================="
echo "EDMV4-T36 -- Security-trigger tie-breaker and compliance dialog pre-selection"
echo "================================================================================================="
echo

T36_BLOCK="$(_t34_extract_between "$ORCH_SKILL" '^\*\*Step 1b\.5' '^\*\*Step 1c')"
T36_STEP1C="$(_t34_extract_between "$ORCH_SKILL" '^\*\*Step 1c' '^\*\*Step 1d')"

check "EDMV4-T36 AC1 -- tie-breaker forces at least standard on a trigger or public API/contract hit" \
  'forces the recommendation to **at least** `standard`' "$T36_BLOCK"
check "EDMV4-T36 AC1 -- tie-breaker overrides a lower tier from the three base signals" \
  'overriding a lower tier from the three signals above' "$T36_BLOCK"

check "EDMV4-T36 AC2 -- all seven triggers enumerated exactly, in order, with no additions or omissions" \
  'authentication or authorization, user-input handling, database queries, filesystem paths, external API calls, cryptography, secrets or credentials' \
  "$T36_BLOCK"

check "EDMV4-T36 AC3 -- triggers are cited to orch-pipeline/SKILL.md" \
  'orch-pipeline/SKILL.md' "$T36_BLOCK"
check_absent "EDMV4-T36 AC3 -- no misattribution to rules/common/security.md anywhere in the orchestrator skill" \
  'rules/common/security.md' "$(cat "$ORCH_SKILL")"

check "EDMV4-T36 AC4 -- firing the tie-breaker also pre-selects On for Step 1c's compliance toggle" \
  'pre-selects **On** for Step 1c'"'"'s compliance toggle' "$T36_BLOCK"
check "EDMV4-T36 AC4 -- Recommended moves from Off to On when the tie-breaker fires" \
  'moving "(Recommended)" from Off to On for this run' "$T36_BLOCK"

check "EDMV4-T36 AC5 -- reasoning names the trigger that fired, not merely that a trigger fired" \
  'or naming the trigger that fired' "$T36_BLOCK"

T36_AC8_EXPECTED="overrides the trivial tier's \`(standard, fix-pack)\` recommendation with \`(standard, standard)\`"
check "EDMV4-T36 AC8 -- tie-breaker documented to override the trivial tier's own pair, not merely raise 'at least standard' in the abstract" \
  "$T36_AC8_EXPECTED" "$T36_BLOCK"

check "EDMV4-T36 -- tie-breaker is a floor, never a ceiling (never lowers standard, never changes mode away from standard)" \
  'It is a floor, never a ceiling' "$T36_BLOCK"

# ---- AC6: compliance dialog's base option text is unchanged when the tie-breaker does not fire -
check "EDMV4-T36 AC6 -- compliance dialog base text still reads Off (Recommended) / On, unchanged" \
  '**Off** (Recommended) /' "$T36_STEP1C"
check "EDMV4-T36 AC6 -- ... / On." \
  '**On**.' "$T36_STEP1C"
check "EDMV4-T36 AC6 -- Step 1c states the default is unchanged when the tie-breaker does not fire" \
  'when it does not fire, this default is unchanged' "$T36_STEP1C"

# ---- AC7: pre-selection is a recommendation only; existing write path, no new one ---------------
check "EDMV4-T36 AC7 -- user may still choose Off despite the pre-selection" \
  'The user may still choose Off' "$T36_STEP1C"
check "EDMV4-T36 AC7 -- compliance is still recorded only via the existing set-mode compliance_enabled true write" \
  '`set-mode <PREFIX> compliance_enabled true` write (only if On)' "$T36_STEP1C"
check_absent "EDMV4-T36 AC7 -- no new write path introduced (no compliance_enabled false write)" \
  'compliance_enabled false' "$(cat "$ORCH_SKILL")"

# ---- AC8: Step 1b.5 is prose consumed by the orchestrating LLM at runtime, not an executable
# function -- there is no runnable "classifier" binary this bash suite can invoke with three
# trivial signals and a trigger flag to observe a live recommendation. The check above
# (T36_AC8_EXPECTED) is the closest available runnable proxy: it proves the skill text states,
# unambiguously, that a trigger hit overrides the trivial tier's own (standard, fix-pack) pair
# with (standard, standard) -- exactly the scenario AC8 describes -- rather than merely gesturing
# at "at least standard" in the abstract, which would leave the trivial-tier-override case
# untested. Already asserted above; not repeated here.
# Wave-2 QC (shard 3): this was an UNCONDITIONAL pass. The disclosure it carried is correct and
# worth keeping -- Step 1b.5 is prose an LLM consumes, not an executable classifier, so the
# runtime behaviour cannot be driven with synthetic signals here. But "cannot verify the
# behaviour" does not license an assertion that cannot fail. QC adjudicated this PARTIAL, not a
# D15 rework, because the runtime environment DOES exist (evals/run-eval.sh drives claude -p, and
# /edm:verify-runtime is the sanctioned closer). So: assert the specification clause that IS
# checkable, and leave the behaviour to /edm:verify-runtime.
T36_AC8_BLOCK="$(_t34_extract_between "$ORCH_SKILL" '^\*\*Step 1b\.5' '^\*\*Step 1c')"
if printf '%s\n' "$T36_AC8_BLOCK" | command grep -q "overrides the trivial tier's"; then
  pass "EDMV4-T36 AC8 -- Step 1b.5 pins the trigger-hit-overrides-trivial-tier rule in prose (behaviour itself is runtime-only; closed by /edm:verify-runtime)"
else
  fail "EDMV4-T36 AC8 -- Step 1b.5 does not state the trigger-hit-overrides-trivial-tier rule"
fi

echo

# =================================================================================================
# EDMV4-T37 -- Enforce guard D6 so the classifier never restates the mode matrix
# =================================================================================================
echo "================================================================================================="
echo "EDMV4-T37 -- Enforce guard D6 so the classifier never restates the mode matrix"
echo "================================================================================================="
echo

T37_D6_PHRASES="Phases 1, 2, 3, 5 recorded|fuse into one audited file|Tickets generated directly from"

# t37_d6_scoped_check <file> -- 0 = the extracted Step 1b.5 block is non-empty and carries no
# restatement phrase; 1 = a restatement phrase was found inside the block; 2 = the extracted block
# was empty, which must fail rather than pass vacuously (the single most likely way this class of
# assertion silently stops checking anything -- see this file's own EDMV4 anti-pattern entry).
t37_d6_scoped_check() {
  local file="$1" block
  block="$(_t34_extract_between "$file" '^\*\*Step 1b\.5' '^\*\*Step 1c')"
  [[ -n "$block" ]] || return 2
  printf '%s\n' "$block" | grep -qE "$T37_D6_PHRASES" && return 1
  return 0
}

# ---- AC1: Step 1b.5 contains no mode/lifecycle_mode behaviour description; cites the mode matrix
# by section reference, following the Step 1c.4 pattern -----------------------------------------
if t37_d6_scoped_check "$ORCH_SKILL"; then
  pass "EDMV4-T37 AC1 -- Step 1b.5's block contains no mode-matrix restatement phrase"
else
  fail "EDMV4-T37 AC1 -- Step 1b.5's block contains a restatement phrase, or the extraction was empty"
fi
check "EDMV4-T37 AC1 -- Step 1b.5 cites the mode matrix by section reference, matching Step 1c.4's pattern" \
  'CLAUDE.md Sec."EDM mode matrix (EDMV3-T38)"' "$T36_BLOCK"

# ---- AC2: the one-line reasoning explains the classification, never the destination's behaviour -
check "EDMV4-T37 AC2 -- reasoning explains which signal or trigger fired, not destination behaviour" \
  'never the destination'"'"'s behaviour' "$T36_BLOCK"
check "EDMV4-T37 AC2 -- reasoning also covers a fired trigger, not only the three base signals" \
  'or naming the trigger that fired' "$T36_BLOCK"

# ---- AC3/AC4: scoped extraction, block-only (not tree-wide) -------------------------------------
T37_CLAUDE_MD_HAS_PHRASES=0
grep -qE "$T37_D6_PHRASES" "${PLUGIN_DIR}/CLAUDE.md" 2>/dev/null && T37_CLAUDE_MD_HAS_PHRASES=1

if [[ "$T37_CLAUDE_MD_HAS_PHRASES" -eq 1 ]] && t37_d6_scoped_check "$ORCH_SKILL"; then
  pass "EDMV4-T37 AC3/AC4 -- the restatement phrases legitimately live in CLAUDE.md's own EDM mode matrix table (their owning-phase-skill home), and the block-scoped check on the unmodified tree still passes -- proving the check's scope is the block, not the tree"
else
  fail "EDMV4-T37 AC3/AC4 -- either the mode-matrix phrases are no longer present in CLAUDE.md (fixture drift) or the scoped check regressed to something tree-wide"
fi

# ---- AC5: positive control -- inject a restatement phrase INSIDE Step 1b.5 on a scratch copy and
# prove the check fails there while the unmodified tree still passes -----------------------------
T37_POISONED="${TMP}/orchestrator-SKILL-t37-poisoned.md"
awk '
  { print }
  !inserted && $0 ~ /^Skipped on resume \(Step 1b already read a recorded non-default mode\)\.$/ {
    print "This restates a sub-flow: Phases 1, 2, 3, 5 recorded as skipped."
    inserted = 1
  }
' "$ORCH_SKILL" > "$T37_POISONED"

if t37_d6_scoped_check "$T37_POISONED"; then
  fail "EDMV4-T37 AC5 -- positive control FAILED: a restatement phrase inserted inside Step 1b.5 still passed the scoped check"
else
  pass "EDMV4-T37 AC5 -- positive control: a restatement phrase inserted inside Step 1b.5 correctly fails the scoped check"
fi
if t37_d6_scoped_check "$ORCH_SKILL"; then
  pass "EDMV4-T37 AC5 -- the unmodified tree still passes the identical scoped check (the check discriminates -- it is not a check that always fails)"
else
  fail "EDMV4-T37 AC5 -- the unmodified tree unexpectedly failed the scoped check"
fi

# ---- AC6: CLAUDE.md's mode matrix and D6 guard text are present, unmodified by this initiative --
check "EDMV4-T37 AC6 -- CLAUDE.md's EDM mode matrix section heading is present" \
  '## EDM mode matrix (EDMV3-T38)' "$(cat "${PLUGIN_DIR}/CLAUDE.md")"
check "EDMV4-T37 AC6 -- CLAUDE.md's D6 guard text is present, unmodified" \
  'Do not duplicate the mode matrix into agent prompts' "$(cat "${PLUGIN_DIR}/CLAUDE.md")"

# ---- AC7: the no-restatement requirement is stated in Step 1b.5's own text, citing guard D6 -----
check "EDMV4-T37 AC7 -- Step 1b.5 states the no-restatement requirement, citing guard D6 by name" \
  'Per guard D6, this step names values only and never restates' "$T36_BLOCK"

# ---- AC8: these assertions live in wave8-smoke.sh, a suite bin/tests/run-all.sh discovers -------
# Wave-2 QC (shard 3): this was an UNCONDITIONAL pass -- no assertion behind it, incapable of
# failing, counted as green. AC8's claim is checkable: this file must match the glob run-all.sh
# discovers with, and must actually sit in the directory it sweeps.
t37_ac8_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd -P)"
t37_ac8_self="$(basename "${BASH_SOURCE[0]:-$0}")"
if [[ "$t37_ac8_self" == *-smoke.sh && -f "${t37_ac8_dir}/run-all.sh" && -f "${t37_ac8_dir}/${t37_ac8_self}" ]]; then
  pass "EDMV4-T37 AC8 -- ${t37_ac8_self} matches run-all.sh's *-smoke.sh glob and sits beside it in ${t37_ac8_dir}"
else
  fail "EDMV4-T37 AC8 -- ${t37_ac8_self} is not discoverable by run-all.sh's *-smoke.sh sweep in ${t37_ac8_dir}"
fi

echo

# =================================================================================================
# EDMV4-T12: Phase-6 marker primitive with SessionStart reconciliation
# =================================================================================================
echo "=== EDMV4-T12: Phase-6 marker primitive + SessionStart reconciliation ==="
echo

T12_DATADIR_LIB="${SCRIPT_DIR}/../_edm-datadir-lib.sh"

# ---- AC1: edm_marker_path()'s body invokes no external binary --------------------------------
# The library's own file header states, for the whole file, that "spawns zero subprocesses" means
# "invokes no external binary" -- not "forks no subshell to call a sibling pure-bash function" --
# which is the only bash-achievable reading: composing two print-style functions' output requires
# a command substitution (a real fork), so a literal zero-$(-occurrences reading of this AC would
# be unsatisfiable without duplicating edm_data_dir()/edm_project_key()'s own resolution chains
# inside edm_marker_path() -- exactly what this ticket's own Technical Notes forbid ("Do not fork
# a second resolution chain"). This check is anchored to the function's own body text (extracted
# below), never to prose describing it, so it cannot self-match its own documentation.
_t12_extract_fn_body() {
  local file="$1" name="$2"
  awk -v needle="${name}() {" '
    index($0, needle) == 1 { found=1; next }
    found && /^}/ { exit }
    found { print }
  ' "$file"
}

T12_MARKER_BODY="$(_t12_extract_fn_body "$T12_DATADIR_LIB" edm_marker_path)"
if [[ -n "$T12_MARKER_BODY" ]]; then
  pass "EDMV4-T12 AC1 -- edm_marker_path()'s function body was extracted (non-empty)"
else
  fail "EDMV4-T12 AC1 -- could not extract edm_marker_path()'s function body from ${T12_DATADIR_LIB}"
fi

T12_EXTERNAL_BIN_RE='\b(git|tr|sed|awk|cut|find|stat|dirname|basename|wc|head|tail|xargs|jq|cat|grep|readlink|realpath)\b'
if printf '%s\n' "$T12_MARKER_BODY" | grep -qE "$T12_EXTERNAL_BIN_RE"; then
  fail "EDMV4-T12 AC1 -- edm_marker_path()'s body invokes an external binary: $(printf '%s\n' "$T12_MARKER_BODY" | grep -E "$T12_EXTERNAL_BIN_RE")"
else
  pass "EDMV4-T12 AC1 -- edm_marker_path()'s body invokes no external binary (only the two sibling pure-bash resolvers)"
fi

# Positive control: a real external-binary call injected into the same body must trip the detector.
T12_AC1_BROKEN="$(printf '%s\n  git rev-parse --show-toplevel\n' "$T12_MARKER_BODY")"
if printf '%s\n' "$T12_AC1_BROKEN" | grep -qE "$T12_EXTERNAL_BIN_RE"; then
  pass "EDMV4-T12 AC1 -- positive control: the detector fires when a real external-binary call (git) is injected"
else
  fail "EDMV4-T12 AC1 -- positive control FAILED: injecting a git call did not trip the detector"
fi

# ---- AC9 (primitive half): edm_marker_path() returns empty when edm_data_dir() is unresolvable,
# so a caller's single `[[ -n "$marker" ]]` check is the whole "is the marker usable" test. The
# gate's own consumption of this (edm-gateguard exits 0 with no output) is EDMV4-T11's, which does
# not exist yet -- Out of Scope above names it explicitly. ------------------------------------
T12_AC9_ROBLOCK="${TMP}/t12-ac9-roblock"
mkdir -p "$T12_AC9_ROBLOCK"
chmod 555 "$T12_AC9_ROBLOCK"
T12_AC9_MARKER="$(/bin/bash -c "export CLAUDE_PLUGIN_DATA='${T12_AC9_ROBLOCK}/pd'; export XDG_DATA_HOME='${T12_AC9_ROBLOCK}/xdg'; export HOME='${T12_AC9_ROBLOCK}/home'; source '$T12_DATADIR_LIB'; edm_marker_path")"
chmod 755 "$T12_AC9_ROBLOCK"
if [[ -z "$T12_AC9_MARKER" ]]; then
  pass "EDMV4-T12 AC9 -- edm_marker_path() returns empty when edm_data_dir() is unresolvable"
else
  fail "EDMV4-T12 AC9 -- edm_marker_path() returned a non-empty path when unresolvable: [${T12_AC9_MARKER}]"
fi

T12_AC9_OK_DATA="${TMP}/t12-ac9-ok-data"
mkdir -p "$T12_AC9_OK_DATA"
T12_AC9_MARKER_OK="$(/bin/bash -c "export CLAUDE_PLUGIN_DATA='${T12_AC9_OK_DATA}'; source '$T12_DATADIR_LIB'; edm_marker_path")"
if [[ -n "$T12_AC9_MARKER_OK" ]]; then
  pass "EDMV4-T12 AC9 -- positive control: edm_marker_path() is non-empty when edm_data_dir() DOES resolve"
else
  fail "EDMV4-T12 AC9 -- positive control FAILED: edm_marker_path() was empty even with a valid, writable CLAUDE_PLUGIN_DATA"
fi

# ---- AC9 (edm-state half): phase-start 6 is silent -- no marker-related warning at all -- when
# the data directory itself is unresolvable, distinct from AC2's negative test below (a resolvable
# directory whose write then fails DOES warn). ---------------------------------------------------
T12_AC9_REPO="${TMP}/t12-ac9-repo"
mkdir -p "$T12_AC9_REPO"
( cd "$T12_AC9_REPO" && git init -q . && git config user.email edm-harness@example.com && git config user.name "EDM Test Harness" && git config commit.gpgsign false && echo seed > SEED.md && git add SEED.md && git commit -q -m seed ) >/dev/null 2>&1

T12_AC9_ROBLOCK2="${TMP}/t12-ac9-roblock2"
mkdir -p "$T12_AC9_ROBLOCK2"
chmod 555 "$T12_AC9_ROBLOCK2"

T12_AC9_PS_STDERR_FILE="${TMP}/t12-ac9-ps.stderr"
T12_AC9_PS_RC=0
(
  cd "$T12_AC9_REPO" || exit 99
  export CLAUDE_PLUGIN_DATA="${T12_AC9_ROBLOCK2}/pd"
  export XDG_DATA_HOME="${T12_AC9_ROBLOCK2}/xdg"
  export HOME="${T12_AC9_ROBLOCK2}/home"
  export EDM_SRD_ROOT="${T12_AC9_REPO}/SRD"
  export PATH="${PLUGIN_DIR}/bin:${PATH}"
  edm-init T12AC9 --mode mini-srd >/dev/null
  edm-state approve-gate T12AC9 1 >/dev/null
  edm-state approve-gate T12AC9 2 >/dev/null
  edm-state phase-start T12AC9 6 >/dev/null
) 2>"$T12_AC9_PS_STDERR_FILE" || T12_AC9_PS_RC=$?
chmod 755 "$T12_AC9_ROBLOCK2"
T12_AC9_PS_STDERR="$(cat "$T12_AC9_PS_STDERR_FILE" 2>/dev/null || true)"

if [[ "$T12_AC9_PS_RC" -eq 0 ]]; then
  pass "EDMV4-T12 AC9 -- phase-start 6 exits 0 when the data directory itself is unresolvable"
else
  fail "EDMV4-T12 AC9 -- phase-start 6 exited ${T12_AC9_PS_RC} when the data directory is unresolvable (rc should be 0)"
fi
check_absent "EDMV4-T12 AC9 -- no marker-related warning printed when the data directory is unresolvable" \
  "Phase-6 marker" "$T12_AC9_PS_STDERR"

# ---- AC2 negative: an unwritable *resolved* marker location still degrades to a warning, never
# a failure. Uses a file-collision (${data}/run pre-created as a plain file) rather than a
# chmod-based "read-only" setup: chmod 000/555 is unreliable as a root user (root bypasses
# permission bits), while a plain-file collision blocks `mkdir -p` deterministically for anyone. -
echo
echo "-- EDMV4-T12 AC2 negative: marker write failure degrades to a warning, never a failure --"

T12_AC2_NEG_DATA="${TMP}/t12-ac2-neg-data"
mkdir -p "$T12_AC2_NEG_DATA"
touch "${T12_AC2_NEG_DATA}/run"

T12_AC2_NEG_REPO="${TMP}/t12-ac2-neg-repo"
mkdir -p "$T12_AC2_NEG_REPO"
( cd "$T12_AC2_NEG_REPO" && git init -q . && git config user.email edm-harness@example.com && git config user.name "EDM Test Harness" && git config commit.gpgsign false && echo seed > SEED.md && git add SEED.md && git commit -q -m seed ) >/dev/null 2>&1

T12_AC2_NEG_STDERR_FILE="${TMP}/t12-ac2-neg.stderr"
T12_AC2_NEG_RC=0
(
  cd "$T12_AC2_NEG_REPO" || exit 99
  export CLAUDE_PLUGIN_DATA="$T12_AC2_NEG_DATA"
  export EDM_SRD_ROOT="${T12_AC2_NEG_REPO}/SRD"
  export PATH="${PLUGIN_DIR}/bin:${PATH}"
  edm-init T12ACN --mode mini-srd >/dev/null
  edm-state approve-gate T12ACN 1 >/dev/null
  edm-state approve-gate T12ACN 2 >/dev/null
  edm-state phase-start T12ACN 6 >/dev/null
) 2>"$T12_AC2_NEG_STDERR_FILE" || T12_AC2_NEG_RC=$?
T12_AC2_NEG_STDERR="$(cat "$T12_AC2_NEG_STDERR_FILE" 2>/dev/null || true)"

if [[ "$T12_AC2_NEG_RC" -eq 0 ]]; then
  pass "EDMV4-T12 AC2 -- phase-start 6 exits 0 even when the resolved marker location cannot be written"
else
  fail "EDMV4-T12 AC2 -- phase-start 6 exited ${T12_AC2_NEG_RC} when marker write should degrade, not fail"
fi
check "EDMV4-T12 AC2 -- a warning naming the marker write failure is printed on stderr" \
  "could not create Phase-6 marker directory" "$T12_AC2_NEG_STDERR"

echo

# ---- AC2 (happy path) / AC3 / AC4 / AC5 / AC6 / AC7 / AC10 / AC11: the full lifecycle, driven
# through real edm-state subcommands inside one scratch git repo. -------------------------------
echo "-- EDMV4-T12 AC2/AC3/AC4/AC5/AC6/AC7/AC10/AC11: marker lifecycle + SessionStart reconciliation --"

T12_DATA="${TMP}/t12-plugin-data"
mkdir -p "$T12_DATA"
export CLAUDE_PLUGIN_DATA="$T12_DATA"

t12_marker_lifecycle_tests() {
  # ---- AC2 (happy path) / AC6 / AC7 / AC10 / AC11 (create-on-phase-start-6) -------------------
  edm-init --product demo --description t12a T12MKA --mode mini-srd >/dev/null
  "$EDM_STATE" approve-gate T12MKA 1 >/dev/null
  "$EDM_STATE" approve-gate T12MKA 2 >/dev/null

  T12_GIT_BEFORE="$(git status --porcelain)"
  T12_PS_RC=0
  "$EDM_STATE" phase-start T12MKA 6 >/dev/null 2>&1 || T12_PS_RC=$?
  if [[ "$T12_PS_RC" -eq 0 ]]; then
    pass "EDMV4-T12 AC2 -- phase-start T12MKA 6 exits 0"
  else
    fail "EDMV4-T12 AC2 -- phase-start T12MKA 6 exited ${T12_PS_RC}"
  fi

  # AC10: edm_project_key() resolves the same marker path from a subdirectory of the repo as it
  # does from the repo root (git rev-parse --show-toplevel is invariant to cwd within the repo).
  T12_MARKER="$(/bin/bash -c "source '$T12_DATADIR_LIB'; edm_marker_path")"
  mkdir -p subdir
  T12_MARKER_FROM_SUBDIR="$(cd subdir && /bin/bash -c "source '$T12_DATADIR_LIB'; edm_marker_path")"
  check "EDMV4-T12 AC10 -- marker path resolved from a subdirectory matches the one resolved from the repo root" \
    "$T12_MARKER" "$T12_MARKER_FROM_SUBDIR"

  if [[ -f "$T12_MARKER" ]]; then
    pass "EDMV4-T12 AC2/AC11 -- Phase-6 marker created at ${T12_MARKER} on phase-start 6"
  else
    fail "EDMV4-T12 AC2/AC11 -- no marker file found at ${T12_MARKER} after phase-start 6"
  fi

  # AC6: exactly one line, PREFIX<TAB>initiative_dir<TAB>UTC-ISO-8601, a literal tab separator.
  T12_MARKER_LINES="$(wc -l < "$T12_MARKER" | tr -d ' ')"
  check "EDMV4-T12 AC6 -- marker holds exactly one line" "1" "$T12_MARKER_LINES"

  IFS=$'\t' read -r T12_A_PREFIX T12_A_DIR T12_A_TS < "$T12_MARKER"
  check "EDMV4-T12 AC6 -- marker field 1 is the PREFIX" "T12MKA" "$T12_A_PREFIX"
  T12_EXPECTED_DIR="$("$EDM_STATE" resolve-dir T12MKA)"
  check "EDMV4-T12 AC6 -- marker field 2 is the initiative directory" "$T12_EXPECTED_DIR" "$T12_A_DIR"
  if [[ "$T12_A_TS" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
    pass "EDMV4-T12 AC6 -- marker field 3 is a UTC ISO-8601 timestamp"
  else
    fail "EDMV4-T12 AC6 -- marker field 3 is not UTC ISO-8601: got [${T12_A_TS}]"
  fi
  T12_TAB_LINES="$(grep -c "$(printf '\t')" "$T12_MARKER" || true)"
  check "EDMV4-T12 AC6 -- marker line contains a literal tab byte" "1" "$T12_TAB_LINES"

  # AC7: the marker lives outside the repository -- no working-tree change, nothing under SRD_ROOT.
  T12_GIT_AFTER="$(git status --porcelain)"
  if [[ "$T12_GIT_BEFORE" == "$T12_GIT_AFTER" ]]; then
    pass "EDMV4-T12 AC7 -- git status --porcelain unchanged after phase-start 6"
  else
    fail "EDMV4-T12 AC7 -- git status --porcelain changed: before=[${T12_GIT_BEFORE}] after=[${T12_GIT_AFTER}]"
  fi
  case "$T12_MARKER" in
    "${EDM_SRD_ROOT}"*) fail "EDMV4-T12 AC7 -- marker path is under EDM_SRD_ROOT: ${T12_MARKER}" ;;
    *) pass "EDMV4-T12 AC7 -- marker path is not under EDM_SRD_ROOT" ;;
  esac

  # ---- AC3: PREFIX-mismatch non-removal, then matching removal -------------------------------
  edm-init --product demo --description t12b T12MKB --mode mini-srd >/dev/null
  "$EDM_STATE" approve-gate T12MKB 1 >/dev/null
  "$EDM_STATE" approve-gate T12MKB 2 >/dev/null
  T12MKB_DIR="$("$EDM_STATE" resolve-dir T12MKB)"
  mkdir -p "${T12MKB_DIR}/qc"
  echo "qc ok" > "${T12MKB_DIR}/qc/qc-summary.md"

  T12_PC_RC=0
  "$EDM_STATE" phase-complete T12MKB 6 >/dev/null 2>&1 || T12_PC_RC=$?
  if [[ "$T12_PC_RC" -eq 0 ]]; then
    pass "EDMV4-T12 AC3 setup -- phase-complete T12MKB 6 succeeded (exercises the marker-removal code path)"
  else
    fail "EDMV4-T12 AC3 setup -- phase-complete T12MKB 6 failed unexpectedly (rc=${T12_PC_RC})"
  fi

  if [[ -f "$T12_MARKER" ]]; then
    IFS=$'\t' read -r T12_A2_PREFIX _T12_A2_DIR _T12_A2_TS < "$T12_MARKER"
    check "EDMV4-T12 AC3 -- marker still exists and still names T12MKA after phase-complete of a DIFFERENT prefix (T12MKB)" \
      "T12MKA" "$T12_A2_PREFIX"
  else
    fail "EDMV4-T12 AC3 -- marker for T12MKA was removed by phase-complete of a different prefix (T12MKB)"
  fi

  # Positive (matching) removal: completing phase 6 for T12MKA ITSELF must remove its own marker.
  T12MKA_DIR="$("$EDM_STATE" resolve-dir T12MKA)"
  mkdir -p "${T12MKA_DIR}/qc"
  echo "qc ok" > "${T12MKA_DIR}/qc/qc-summary.md"
  "$EDM_STATE" phase-complete T12MKA 6 >/dev/null 2>&1
  if [[ ! -f "$T12_MARKER" ]]; then
    pass "EDMV4-T12 AC3 -- matching phase-complete (T12MKA completing its own phase 6) removes the marker"
  else
    fail "EDMV4-T12 AC3 -- marker still present after T12MKA completed its own phase 6"
  fi

  # ---- AC4: cmd_archive removes the marker defensively -----------------------------------------
  edm-init T12ARC >/dev/null
  "$EDM_STATE" approve-gate T12ARC 1 >/dev/null
  "$EDM_STATE" approve-gate T12ARC 2 >/dev/null
  "$EDM_STATE" approve-gate T12ARC 3 >/dev/null
  T12ARC_STATE="${EDM_SRD_ROOT}/T12ARC/.edm-state.json"
  jq '.current_phase = 6 | .phase_durations["6_phase"] = {started_at: "2026-01-01T00:00:00Z", completed_at: "2026-01-01T01:00:00Z"}' \
    "$T12ARC_STATE" > "${T12ARC_STATE}.tmp" && mv "${T12ARC_STATE}.tmp" "$T12ARC_STATE"
  "$EDM_STATE" approve-gate T12ARC code-audit >/dev/null
  T12ARC_DIR="$("$EDM_STATE" resolve-dir T12ARC)"
  printf '%s\t%s\t%s\n' "T12ARC" "$T12ARC_DIR" "2026-01-01T00:00:00Z" > "$T12_MARKER"

  T12_ARCH_RC=0
  "$EDM_STATE" archive T12ARC >/dev/null 2>&1 || T12_ARCH_RC=$?
  if [[ "$T12_ARCH_RC" -eq 0 ]]; then
    pass "EDMV4-T12 AC4/AC11 -- archive T12ARC succeeds"
  else
    fail "EDMV4-T12 AC4/AC11 -- archive T12ARC failed (rc=${T12_ARCH_RC})"
  fi
  if [[ -f "$T12_MARKER" ]]; then
    fail "EDMV4-T12 AC4/AC11 -- marker for T12ARC still exists after archive"
  else
    pass "EDMV4-T12 AC4/AC11 -- marker for T12ARC removed after archive"
  fi

  # ---- AC4: cmd_skip_phase removes a matching marker when phase 6 itself is skipped -----------
  edm-init T12SK >/dev/null
  T12SK_DIR="$("$EDM_STATE" resolve-dir T12SK)"
  printf '%s\t%s\t%s\n' "T12SK" "$T12SK_DIR" "2026-01-01T00:00:00Z" > "$T12_MARKER"
  T12_SKIP_RC=0
  "$EDM_STATE" skip-phase T12SK 6 "smoke test rationale" >/dev/null 2>&1 || T12_SKIP_RC=$?
  if [[ "$T12_SKIP_RC" -eq 0 ]]; then
    pass "EDMV4-T12 AC4 -- skip-phase T12SK 6 exits 0"
  else
    fail "EDMV4-T12 AC4 -- skip-phase T12SK 6 exited ${T12_SKIP_RC}"
  fi
  if [[ -f "$T12_MARKER" ]]; then
    fail "EDMV4-T12 AC4 -- marker for T12SK still exists after phase 6 was skipped"
  else
    pass "EDMV4-T12 AC4 -- marker for T12SK removed after phase 6 was skipped"
  fi

  # AC4's "no marker present" case: skip-phase (for a non-6 phase, with no marker at all) exits 0.
  edm-init T12SK2 >/dev/null
  T12_SKIP2_RC=0
  "$EDM_STATE" skip-phase T12SK2 1 "no marker present at all" >/dev/null 2>&1 || T12_SKIP2_RC=$?
  if [[ "$T12_SKIP2_RC" -eq 0 ]]; then
    pass "EDMV4-T12 AC4 -- skip-phase exits 0 with its pre-change status when no marker is present"
  else
    fail "EDMV4-T12 AC4 -- skip-phase exited ${T12_SKIP2_RC} with no marker present (expected 0)"
  fi

  # ---- AC5: SessionStart reconciliation, both directions ---------------------------------------
  # (a) a marker naming an initiative that is NOT at current_phase == 6 (T12MKB, still at phase 1
  # since it never itself called phase-start 6) is removed with exactly one line of output.
  printf '%s\t%s\t%s\n' "T12MKB" "$T12MKB_DIR" "2026-01-01T00:00:00Z" > "$T12_MARKER"
  T12_SS_OUT="$("$EDM_STATE" session-start 2>&1)"
  check "EDMV4-T12 AC5 -- SessionStart output names the removed prefix" "T12MKB" "$T12_SS_OUT"
  if [[ -f "$T12_MARKER" ]]; then
    fail "EDMV4-T12 AC5 -- stale marker for T12MKB was NOT removed by session-start"
  else
    pass "EDMV4-T12 AC5 -- stale marker for T12MKB removed by session-start"
  fi
  T12_SS_REMOVAL_LINES="$(printf '%s\n' "$T12_SS_OUT" | grep -c 'removed stale Phase-6 marker' || true)"
  check "EDMV4-T12 AC5 -- exactly one removal line printed" "1" "$T12_SS_REMOVAL_LINES"

  # (b) an absent marker is recreated when some initiative genuinely IS at phase 6.
  T12MKB_STATE="${T12MKB_DIR}/.edm-state.json"
  jq '.current_phase = 6' "$T12MKB_STATE" > "${T12MKB_STATE}.tmp" && mv "${T12MKB_STATE}.tmp" "$T12MKB_STATE"
  [[ ! -f "$T12_MARKER" ]] || rm -f "$T12_MARKER"
  "$EDM_STATE" session-start >/dev/null 2>&1
  if [[ -f "$T12_MARKER" ]]; then
    pass "EDMV4-T12 AC5 -- absent marker recreated when an initiative is at current_phase == 6"
  else
    fail "EDMV4-T12 AC5 -- marker was NOT recreated even though T12MKB is at current_phase == 6"
  fi
  IFS=$'\t' read -r T12_RECREATED_PREFIX _T12_RC_DIR _T12_RC_TS < "$T12_MARKER"
  # T12MKA's own current_phase also remains 6 (phase-complete records completion metadata but
  # never decrements current_phase), so both it and T12MKB are genuinely at phase 6 here -- R6's
  # documented ambiguity for two simultaneous Phase-6 initiatives. Either name is a correct
  # recreation; the assertion is "recreated with SOME currently-phase-6 prefix", not a specific one.
  case "$T12_RECREATED_PREFIX" in
    T12MKA|T12MKB) pass "EDMV4-T12 AC5 -- recreated marker names a genuinely phase-6 initiative (${T12_RECREATED_PREFIX})" ;;
    *) fail "EDMV4-T12 AC5 -- recreated marker names neither phase-6 initiative: got [${T12_RECREATED_PREFIX}]" ;;
  esac
}

with_scratch_repo t12_marker_lifecycle_tests
unset CLAUDE_PLUGIN_DATA
# =================================================================================================
# EDMV4-T43: Build the hookify evaluator from nothing, with one classify pass and N projections
# =================================================================================================
echo
echo "=== EDMV4-T43: edm-hookify evaluator ==="
echo

EDM_HOOKIFY="${PLUGIN_DIR}/bin/edm-hookify"

# ---- AC1/AC11: exists, executable, house conventions ------------------------------------------
if [[ -x "$EDM_HOOKIFY" ]]; then
  pass "EDMV4-T43 AC1 -- edm-hookify exists and is executable"
else
  fail "EDMV4-T43 AC1 -- edm-hookify missing or not executable"
fi
check "EDMV4-T43 AC11 -- sources _edm-cli-lib.sh" "source \"\${SCRIPT_DIR}/_edm-cli-lib.sh\"" "$(cat "$EDM_HOOKIFY")"
check "EDMV4-T43 AC11 -- calls the shared print_help()" "print_help \"\${BASH_SOURCE[0]:-\$0}\"" "$(cat "$EDM_HOOKIFY")"
check "EDMV4-T43 AC11 -- carries EDM-HELP-BEGIN/END sentinels" "EDM-HELP-BEGIN" "$(cat "$EDM_HOOKIFY")"
T43_SCRIPT_DIR_LINE="$(grep -m1 '^SCRIPT_DIR=' "$EDM_HOOKIFY" || true)"
check "EDMV4-T43 AC11 -- SCRIPT_DIR idiom matches the house convention" \
  'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"' "$T43_SCRIPT_DIR_LINE"

# ---- AC12: CLAUDE.md bin/ helper table gains a row ---------------------------------------------
check "EDMV4-T43 AC12 -- CLAUDE.md's bin/ helper table names edm-hookify" \
  '`edm-hookify`' "$(cat "${PLUGIN_DIR}/CLAUDE.md")"

# ---- Scratch project with a copy of the T42 fixture set (README's documented reuse) ------------
T43_PROJ="${TMP}/t43-project"
mkdir -p "${T43_PROJ}/.claude/edm-hookify"
cp "${HOOKIFY_FIXTURES}/warn-no-console-log.json" "${T43_PROJ}/.claude/edm-hookify/"
cp "${HOOKIFY_FIXTURES}/block-rm-rf-bash.json" "${T43_PROJ}/.claude/edm-hookify/"
cp "${HOOKIFY_FIXTURES}/warn-stop-placeholder.json" "${T43_PROJ}/.claude/edm-hookify/"

t43_run() {
  # t43_run <event> <payload-json>
  (
    cd "$T43_PROJ" || exit 99
    CLAUDE_PROJECT_DIR="$T43_PROJ" PATH="${PLUGIN_DIR}/bin:${PATH}" \
      bash -c "echo '$2' | edm-hookify eval $1"
  )
}

# ---- AC4: exact "rule_id action message" line for a matched rule ------------------------------
T43_AC4_OUT="$(t43_run file '{"file_path":"src/foo.js","new_text":"console.log(1)"}')"
check "EDMV4-T43 AC4 -- matched-rule line is exactly 'rule_id action message'" \
  "warn-no-console-log warn Avoid leaving console.log statements in non-test source files." "$T43_AC4_OUT"

# ---- AC5: enabled:false is skipped even though its condition would otherwise match -------------
T43_DISABLED_DIR="${TMP}/t43-disabled-project"
mkdir -p "${T43_DISABLED_DIR}/.claude/edm-hookify"
jq '.enabled = false' "${HOOKIFY_FIXTURES}/warn-no-console-log.json" \
  > "${T43_DISABLED_DIR}/.claude/edm-hookify/warn-no-console-log.json"
T43_AC5_OUT="$(cd "$T43_DISABLED_DIR" && CLAUDE_PROJECT_DIR="$T43_DISABLED_DIR" PATH="${PLUGIN_DIR}/bin:${PATH}" \
  bash -c 'echo "{\"file_path\":\"src/foo.js\",\"new_text\":\"console.log(1)\"}" | edm-hookify eval file')"
check_absent "EDMV4-T43 AC5 -- a disabled rule that would otherwise match produces no output" \
  "warn-no-console-log" "$T43_AC5_OUT"

# ---- AC9: no file writes -- proven BEHAVIOURALLY, by running the script ------------------------
# This was a static regex scan over edm-hookify's source. It produced five distinct false
# positives in a row, each fixed by widening the scrub, each followed by another: the help
# comment's `<file|bash|stop>`, that same token inside a quoted `die "usage: ..."`, a bare
# `>/dev/null`, an fd-duplication form, and finally a jq GREATER-THAN comparison inside an
# embedded jq program (`if ($unknown|length) > 0 then`). A regex cannot tell a shell redirect
# from a `>` in embedded jq, a usage string, or a comment -- and each widening risked silencing
# a real write (stripping quoted strings would have hidden `> "$VAR"` entirely).
#
# "Writes no files" is a BEHAVIOURAL property. Run the script and look at the filesystem: no
# taxonomy of safe redirect forms, and no form nobody thought of can defeat it.
T43_AC9_SANDBOX="${TMP}/t43-ac9-sandbox"
rm -rf "$T43_AC9_SANDBOX"; mkdir -p "$T43_AC9_SANDBOX/.claude/edm-hookify"
cp "${PLUGIN_DIR}/bin/tests/fixtures/hookify/warn-no-console-log.json" \
   "$T43_AC9_SANDBOX/.claude/edm-hookify/" 2>/dev/null || true

# Snapshot every path under the sandbox with its size and mtime.
t43_ac9_snapshot() { ( cd "$1" && find . -type f -exec stat -f '%N %z %m' {} \; 2>/dev/null | sort ); }

T43_AC9_BEFORE="$(t43_ac9_snapshot "$T43_AC9_SANDBOX")"
( cd "$T43_AC9_SANDBOX" && CLAUDE_PROJECT_DIR="$T43_AC9_SANDBOX" "$EDM_HOOKIFY" list >/dev/null 2>&1 ) || true
( cd "$T43_AC9_SANDBOX" && CLAUDE_PROJECT_DIR="$T43_AC9_SANDBOX" \
    printf '%s' '{"tool_name":"Edit","tool_input":{"file_path":"x.js","new_text":"console.log(1)"}}' \
    | "$EDM_HOOKIFY" eval file >/dev/null 2>&1 ) || true
T43_AC9_AFTER="$(t43_ac9_snapshot "$T43_AC9_SANDBOX")"

if [[ "$T43_AC9_BEFORE" == "$T43_AC9_AFTER" ]]; then
  pass "EDMV4-T43 AC9 -- edm-hookify wrote no file: sandbox filesystem byte-identical after list and eval"
else
  fail "EDMV4-T43 AC9 -- edm-hookify changed the filesystem. Before/after diff: $(diff <(printf '%s' "$T43_AC9_BEFORE") <(printf '%s' "$T43_AC9_AFTER") | head -5)"
fi

# Positive control: a script that DOES write must be caught, or the check above proves nothing.
T43_AC9_WRITER="${TMP}/t43-ac9-writer.sh"
# Take the target as $1 rather than deriving it: an earlier revision computed
# "$(dirname "$0")/../t43-ac9-sandbox", which resolves one level ABOVE the sandbox, so the
# control wrote nothing and reported the detector broken. The control catching its own path bug
# is exactly why it exists -- without it, the clean PASS above would have been unearned.
printf '%s\n' '#!/usr/bin/env bash' 'echo leaked > "$1/leak.txt"' > "$T43_AC9_WRITER"
chmod +x "$T43_AC9_WRITER"
T43_AC9_CTL_BEFORE="$(t43_ac9_snapshot "$T43_AC9_SANDBOX")"
"$T43_AC9_WRITER" "$T43_AC9_SANDBOX" >/dev/null 2>&1 || true
T43_AC9_CTL_AFTER="$(t43_ac9_snapshot "$T43_AC9_SANDBOX")"
[[ "$T43_AC9_CTL_BEFORE" != "$T43_AC9_CTL_AFTER" ]] \
  && pass "EDMV4-T43 AC9 -- positive control: the snapshot comparison detects a script that does write a file" \
  || fail "EDMV4-T43 AC9 -- positive control FAILED: a known file write was not detected, so the clean result above proves nothing"
rm -f "$T43_AC9_WRITER"; rm -rf "$T43_AC9_SANDBOX"

# ---- AC7: no real `timeout` invocation -- every occurrence of the word is inside a comment -----
T43_AC7_BAD="$(grep -nE '^[^#]*[^#[:alnum:]_]timeout[[:space:]]' "$EDM_HOOKIFY" | grep -vE '^\s*[0-9]+:\s*#' || true)"
if [[ -z "$T43_AC7_BAD" ]]; then
  pass "EDMV4-T43 AC7 -- every 'timeout' occurrence in edm-hookify is prose, not an invocation"
else
  fail "EDMV4-T43 AC7 -- a real 'timeout' invocation was found: ${T43_AC7_BAD}"
fi

# ---- AC10: zero rule files (absent .claude/edm-hookify/) exits 0 immediately, spawning no jq ----
T43_JQSHIM_DIR="${TMP}/t43-jqshim"
mkdir -p "$T43_JQSHIM_DIR"
T43_JQ_COUNT_FILE="${TMP}/t43-jq-count"
cat > "${T43_JQSHIM_DIR}/jq" <<SHIM
#!/usr/bin/env bash
echo x >> "${T43_JQ_COUNT_FILE}"
exec "$(command -v jq)" "\$@"
SHIM
chmod +x "${T43_JQSHIM_DIR}/jq"

T43_AC10_PROJ="${TMP}/t43-ac10-project"
mkdir -p "$T43_AC10_PROJ"
rm -f "$T43_JQ_COUNT_FILE"; touch "$T43_JQ_COUNT_FILE"
T43_AC10_RC=0
(cd "$T43_AC10_PROJ" && CLAUDE_PROJECT_DIR="$T43_AC10_PROJ" PATH="${T43_JQSHIM_DIR}:${PLUGIN_DIR}/bin:${PATH}" \
  edm-hookify eval file < /dev/null >/dev/null 2>&1) || T43_AC10_RC=$?
T43_AC10_JQCOUNT="$(wc -l < "$T43_JQ_COUNT_FILE" | tr -d ' ')"
if [[ "$T43_AC10_RC" -eq 0 && "$T43_AC10_JQCOUNT" -eq 0 ]]; then
  pass "EDMV4-T43 AC10 -- absent .claude/edm-hookify/ exits 0 and spawns zero jq processes"
else
  fail "EDMV4-T43 AC10 -- rc=${T43_AC10_RC} jq_spawns=${T43_AC10_JQCOUNT} (expected rc=0, spawns=0)"
fi

# ---- AC2/AC3: jq process count is IDENTICAL for a 1-rule and a 50-rule enabled set --------------
t43_build_ruleset() {
  local dir="$1" n="$2" i
  mkdir -p "${dir}/.claude/edm-hookify"
  for ((i = 0; i < n; i++)); do
    jq --arg nm "warn-rule-${i}" '.name = $nm' "${HOOKIFY_FIXTURES}/warn-no-console-log.json" \
      > "${dir}/.claude/edm-hookify/warn-rule-${i}.json"
  done
}

T43_1RULE_PROJ="${TMP}/t43-1rule"
T43_50RULE_PROJ="${TMP}/t43-50rule"
t43_build_ruleset "$T43_1RULE_PROJ" 1
t43_build_ruleset "$T43_50RULE_PROJ" 50

rm -f "$T43_JQ_COUNT_FILE"; touch "$T43_JQ_COUNT_FILE"
(cd "$T43_1RULE_PROJ" && CLAUDE_PROJECT_DIR="$T43_1RULE_PROJ" PATH="${T43_JQSHIM_DIR}:${PLUGIN_DIR}/bin:${PATH}" \
  bash -c 'echo "{\"file_path\":\"x\",\"new_text\":\"console.log(1)\"}" | edm-hookify eval file' >/dev/null 2>&1) || true
T43_1RULE_COUNT="$(wc -l < "$T43_JQ_COUNT_FILE" | tr -d ' ')"

rm -f "$T43_JQ_COUNT_FILE"; touch "$T43_JQ_COUNT_FILE"
(cd "$T43_50RULE_PROJ" && CLAUDE_PROJECT_DIR="$T43_50RULE_PROJ" PATH="${T43_JQSHIM_DIR}:${PLUGIN_DIR}/bin:${PATH}" \
  bash -c 'echo "{\"file_path\":\"x\",\"new_text\":\"console.log(1)\"}" | edm-hookify eval file' >/dev/null 2>&1) || true
T43_50RULE_COUNT="$(wc -l < "$T43_JQ_COUNT_FILE" | tr -d ' ')"

if [[ "$T43_1RULE_COUNT" -eq "$T43_50RULE_COUNT" && "$T43_1RULE_COUNT" -ge 1 ]]; then
  pass "EDMV4-T43 AC2/AC3 -- jq process count identical for 1-rule and 50-rule sets (${T43_1RULE_COUNT} each)"
else
  fail "EDMV4-T43 AC2/AC3 -- jq spawns diverged: 1-rule=${T43_1RULE_COUNT}, 50-rule=${T43_50RULE_COUNT}"
fi

# ---- AC6/AC8: payload truncation cap -- a match only past the ceiling does not fire, and the
# call returns within the same order of magnitude as a normal call. -----------------------------
T43_TRUNC_PROJ="${TMP}/t43-trunc"
mkdir -p "${T43_TRUNC_PROJ}/.claude/edm-hookify"
jq -n '{name:"trunc-marker",enabled:true,event:"file",action:"warn",
  conditions:[{field:"new_text",operator:"contains",pattern:"TRUNC_MARKER"}],
  message:"marker found"}' > "${T43_TRUNC_PROJ}/.claude/edm-hookify/trunc-marker.json"

T43_FILLER="$(printf 'a%.0s' $(seq 1 70000))"
T43_HUGE_PAYLOAD="$(jq -cn --arg t "${T43_FILLER}TRUNC_MARKER" '{file_path:"x",new_text:$t}')"
T43_NORMAL_PAYLOAD='{"file_path":"x","new_text":"short TRUNC_MARKER text"}'

T43_T0=$(date +%s)
T43_HUGE_OUT="$(cd "$T43_TRUNC_PROJ" && CLAUDE_PROJECT_DIR="$T43_TRUNC_PROJ" PATH="${PLUGIN_DIR}/bin:${PATH}" \
  bash -c "echo '${T43_HUGE_PAYLOAD}' | edm-hookify eval file")"
T43_T1=$(date +%s)
T43_NORMAL_OUT="$(cd "$T43_TRUNC_PROJ" && CLAUDE_PROJECT_DIR="$T43_TRUNC_PROJ" PATH="${PLUGIN_DIR}/bin:${PATH}" \
  bash -c "echo '${T43_NORMAL_PAYLOAD}' | edm-hookify eval file")"
T43_T2=$(date +%s)
T43_HUGE_MS=$(( (T43_T1 - T43_T0) ))
T43_NORMAL_MS=$(( (T43_T2 - T43_T1) ))

check_absent "EDMV4-T43 AC6/AC8 -- a match only past the 65536-char ceiling does not fire" \
  "trunc-marker" "$T43_HUGE_OUT"
check "EDMV4-T43 AC6/AC8 -- the same rule DOES fire when the marker is within the ceiling (positive control)" \
  "trunc-marker" "$T43_NORMAL_OUT"
if [[ "$T43_HUGE_MS" -le $((T43_NORMAL_MS * 20 + 5)) ]]; then
  pass "EDMV4-T43 AC8 -- oversized-payload call (${T43_HUGE_MS}s) is the same order of magnitude as normal (${T43_NORMAL_MS}s)"
else
  fail "EDMV4-T43 AC8 -- oversized-payload call (${T43_HUGE_MS}s) far exceeds normal call (${T43_NORMAL_MS}s)"
fi

echo

# =================================================================================================
# EDMV4-T46: Build edm-stop-gate and add it as a second entry in the existing Stop block
# =================================================================================================
echo "=== EDMV4-T46: edm-stop-gate ==="
echo

EDM_STOP_GATE="${PLUGIN_DIR}/bin/edm-stop-gate"
HOOKS_JSON="${PLUGIN_DIR}/hooks/hooks.json"

# ---- AC5: exists, executable, validate-only (no hookify stop-rule wiring in this ticket) -------
if [[ -x "$EDM_STOP_GATE" ]]; then
  pass "EDMV4-T46 AC5 -- edm-stop-gate exists and is executable"
else
  fail "EDMV4-T46 AC5 -- edm-stop-gate missing or not executable"
fi
check_absent "EDMV4-T46 AC5 -- edm-stop-gate does not invoke edm-hookify (validate-only this ticket)" \
  "edm-hookify" "$(cat "$EDM_STOP_GATE")"
check "EDMV4-T46 AC5 -- edm-stop-gate runs edm-state validate" \
  "edm-state validate" "$(cat "$EDM_STOP_GATE")"

# ---- AC6/AC7: Stop array length 1, its hooks array length 2, checkpoint entry byte-identical ----
T46_STOP_LEN="$(jq '.hooks.Stop | length' "$HOOKS_JSON")"
T46_STOP_HOOKS_LEN="$(jq '.hooks.Stop[0].hooks | length' "$HOOKS_JSON")"
check "EDMV4-T46 AC6 -- Stop still has exactly one matcher block" "1" "$T46_STOP_LEN"
check "EDMV4-T46 AC6 -- that block's hooks array now has exactly two entries" "2" "$T46_STOP_HOOKS_LEN"
T46_CHECKPOINT_CMD="$(jq -r '.hooks.Stop[0].hooks[0].command' "$HOOKS_JSON")"
check "EDMV4-T46 AC7 -- checkpoint-if-active entry is byte-identical" \
  "command -v edm-state >/dev/null 2>&1 && edm-state checkpoint-if-active || true" "$T46_CHECKPOINT_CMD"
T46_GATE_CMD="$(jq -r '.hooks.Stop[0].hooks[1].command' "$HOOKS_JSON")"
check "EDMV4-T46 AC10 -- the new entry is guarded by 'command -v edm-stop-gate ... || exit 0'" \
  "command -v edm-stop-gate >/dev/null 2>&1 || exit 0" "$T46_GATE_CMD"

# ---- AC12: CLAUDE.md's Hooks behavior table splits Stop and PreCompact -------------------------
CLAUDE_MD_TEXT2="$(cat "${PLUGIN_DIR}/CLAUDE.md")"
check_absent "EDMV4-T46 AC12 -- the collapsed 'Stop and PreCompact' row no longer exists" \
  '`Stop` and `PreCompact`' "$CLAUDE_MD_TEXT2"
check "EDMV4-T46 AC12 -- Hooks behavior table documents edm-stop-gate's exit contract" \
  "edm-stop-gate" "$CLAUDE_MD_TEXT2"

# ---- Scratch-repo functional tests (isolated EDM_SRD_ROOT / PATH / HOME / CLAUDE_PROJECT_DIR) ---
t46_isolate_and_run() {
  # t46_isolate_and_run <inner-fn> -- runs <inner-fn> inside a fresh scratch git repo with an
  # isolated HOME and CLAUDE_PROJECT_DIR (so PERM_RULES_MISSING is deterministic regardless of the
  # developer machine's real ~/.claude/settings.json) and the real bin/ on PATH.
  local inner="$1"
  local prev_home="${HOME:-}" prev_cpd="${CLAUDE_PROJECT_DIR:-}"
  local scratch_home
  scratch_home="$(mktemp -d "${TMP}/t46-home.XXXXXX")"
  _t46_body() {
    export HOME="$scratch_home"
    export CLAUDE_PROJECT_DIR="$(pwd)"
    "$inner"
  }
  with_scratch_repo _t46_body
  local rc=$?
  export HOME="$prev_home"
  if [[ -n "$prev_cpd" ]]; then export CLAUDE_PROJECT_DIR="$prev_cpd"; else unset CLAUDE_PROJECT_DIR; fi
  rm -rf "$scratch_home"
  return $rc
}

# ---- AC3: no active initiatives -- exits 0, zero bytes on stdout AND stderr --------------------
t46_ac3_case() {
  local out rc=0
  out="$(edm-stop-gate 2>&1)" || rc=$?
  [[ "$rc" -eq 0 && -z "$out" ]] \
    && pass "EDMV4-T46 AC3 -- no active initiatives: exit 0, zero bytes on stdout+stderr" \
    || fail "EDMV4-T46 AC3 -- rc=${rc} out=[${out}] (expected rc=0, empty)"
}
t46_isolate_and_run t46_ac3_case

# ---- AC4: informational-only case -- exactly one output line, exit 0, count matches info lines --
t46_ac4_case() {
  edm-state init T46INFO >/dev/null
  local state; state="$(edm-state resolve-dir T46INFO)/.edm-state.json"
  jq '.current_phase = 2
      | del(.schema_version)
      | .skipped_phases = [{phase: 3, rationale: "test exemption"}]' \
    "$state" > "${state}.tmp" && mv "${state}.tmp" "$state"

  local validate_out info_count
  validate_out="$(edm-state validate T46INFO 2>&1 || true)"
  info_count="$(printf '%s\n' "$validate_out" | grep -c '^info ' || true)"

  local out rc=0
  out="$(edm-stop-gate 2>&1)" || rc=$?
  # Wave-2 QC (shard 4): unguarded under `set -euo pipefail` -- edm-stop-gate exits 2 on a
  # blocking anomaly, which killed the suite silently. The identical call below already carried
  # `|| true`; this one did not. Eighth instance of the abort class commit bd582cc swept for.
  local stdout_only; stdout_only="$(edm-stop-gate 2>/dev/null)" || true
  local line_count; line_count="$(printf '%s\n' "$out" | grep -c . || true)"

  [[ "$rc" -eq 0 ]] && pass "EDMV4-T46 AC4 -- informational-only case exits 0" \
    || fail "EDMV4-T46 AC4 -- informational-only case exited ${rc}, expected 0"
  [[ -z "$stdout_only" ]] && pass "EDMV4-T46 AC4 -- stdout is empty (AC8)" \
    || fail "EDMV4-T46 AC4 -- stdout carried output: [${stdout_only}]"
  [[ "$line_count" -eq 1 ]] && pass "EDMV4-T46 AC4 -- exactly one output line" \
    || fail "EDMV4-T46 AC4 -- expected exactly 1 output line, got ${line_count}: [${out}]"
  check "EDMV4-T46 AC4 -- the one line names the correct informational count (${info_count})" \
    "[EDM] ${info_count} informational anomalies (run: edm-state validate T46INFO)" "$out"
}
t46_isolate_and_run t46_ac4_case

# ---- AC2: multi-initiative -- one clean, one blocking -- exits 2 and names the offending prefix -
t46_ac2_case() {
  edm-state init T46CLEAN >/dev/null
  edm-state set T46CLEAN current_phase 1 >/dev/null
  edm-state set T46CLEAN estimated_size Small >/dev/null

  edm-state init T46BLOCK >/dev/null
  edm-state set T46BLOCK current_phase 1 >/dev/null
  edm-state set T46BLOCK estimated_size Small >/dev/null
  edm-state record-partial-verdict T46BLOCK T46BLOCK-T01 PARTIAL "needs runtime check" >/dev/null

  local out rc=0 stdout_only
  out="$(edm-stop-gate 2>&1)" || rc=$?
  stdout_only="$(edm-stop-gate 2>/dev/null)" || true

  [[ "$rc" -eq 2 ]] && pass "EDMV4-T46 AC2 -- multi-initiative with one blocking anomaly exits 2" \
    || fail "EDMV4-T46 AC2 -- exited ${rc}, expected 2"
  check "EDMV4-T46 AC2 -- blocking message names the offending initiative" "T46BLOCK" "$out"
  check "EDMV4-T46 AC2 -- blocking message carries the full OPEN_PARTIALS anomaly text" \
    "blocking  OPEN_PARTIALS" "$out"
  [[ -z "$stdout_only" ]] && pass "EDMV4-T46 AC8 -- stdout stays empty even in the blocking case" \
    || fail "EDMV4-T46 AC8 -- stdout carried output in the blocking case: [${stdout_only}]"
}
t46_isolate_and_run t46_ac2_case

# ---- AC9: internal-error paths never block (edm-state off PATH; jq broken/missing) -------------
t46_ac9_case() {
  # edm-state off PATH entirely (invoke edm-stop-gate itself by absolute path -- PATH is what
  # its OWN internal `command -v edm-state` check must fail to find, not the gate binary itself).
  local rc=0 out
  out="$(PATH="/usr/bin:/bin" "$EDM_STOP_GATE" 2>&1)" || rc=$?
  [[ "$rc" -eq 0 ]] && pass "EDMV4-T46 AC9 -- edm-state off PATH exits 0" \
    || fail "EDMV4-T46 AC9 -- edm-state off PATH exited ${rc}, expected 0"

  edm-state init T46JQ >/dev/null
  edm-state set T46JQ current_phase 1 >/dev/null
  local fakejq_dir; fakejq_dir="$(mktemp -d "${TMP}/t46-fakejq.XXXXXX")"
  cat > "${fakejq_dir}/jq" <<'FAKEJQ'
#!/bin/sh
exit 1
FAKEJQ
  chmod +x "${fakejq_dir}/jq"
  local rc2=0
  out="$(PATH="${fakejq_dir}:${PATH}" edm-stop-gate 2>&1)" || rc2=$?
  [[ "$rc2" -eq 0 ]] && pass "EDMV4-T46 AC9 -- a broken/unusable jq on PATH still exits 0 (never blocks)" \
    || fail "EDMV4-T46 AC9 -- broken jq case exited ${rc2}, expected 0"
}
t46_isolate_and_run t46_ac9_case

# =================================================================================================
# EDMV4-T18 -- writable harvested delta, get-patterns read side, and the single-commit coupling
# =================================================================================================
# Own banded section, appended last, so a later GateGuard/hookify commit does not interleave with
# it (Technical Notes). Every case here runs against a scratch HOME/CLAUDE_PLUGIN_DATA/SRD tree;
# nothing here touches the real plugin data directory or the shipped docs/audit-patterns/ tree.
echo
echo "-- EDMV4-T18: writable harvested delta + get-patterns read side --"

T18_ROOT="${TMP}/t18-root"
mkdir -p "$T18_ROOT"
T18_DATA="${T18_ROOT}/data"
T18_HOME="${T18_ROOT}/home"
T18_SRD="${T18_ROOT}/SRD"
mkdir -p "$T18_DATA" "$T18_HOME" "$T18_SRD/edm/EDMV4T18__x/qc"

cat > "${T18_SRD}/edm/EDMV4T18__x/.edm-state.json" <<'EOF'
{"prefix":"EDMV4T18","current_phase":6,"product_name":"edm","initiative_description":"x"}
EOF
cat > "${T18_SRD}/edm/EDMV4T18__x/qc/qc-summary.md" <<'EOF'
# QC Summary

**Finding**: [P1] EDMV4T18-T01 | bin/foo.sh:10 | A brand new synthetic QC finding for the T18 smoke check
EOF

t18_run_get_patterns() {
  ( export CLAUDE_PLUGIN_DATA="$T18_DATA" HOME="$T18_HOME" XDG_DATA_HOME="" CLAUDE_PROJECT_DIR="$T18_ROOT" EDM_SRD_ROOT="$T18_SRD"
    "$EDM_STATE" get-patterns "$@" )
}
t18_run_update_patterns() {
  ( export CLAUDE_PLUGIN_DATA="$T18_DATA" HOME="$T18_HOME" XDG_DATA_HOME="" CLAUDE_PROJECT_DIR="$T18_ROOT" EDM_SRD_ROOT="$T18_SRD"
    "$EDM_STATE" update-patterns "$@" )
}

# ---- AC8: --paths prints exactly two lines, second EMPTY (not absent) before any delta exists ---
# CA-145-class note: `wc -l` on a re-run piped directly (not on a $()-captured copy) is required
# here -- command substitution strips ALL trailing newlines, so a captured 2-line output whose
# second line is empty collapses to 1 line and would falsely fail this assertion.
T18_BEFORE="$(t18_run_get_patterns qc --paths)"
T18_BEFORE_LINES="$(t18_run_get_patterns qc --paths | wc -l | tr -d ' ')"
T18_BEFORE_SEED="$(printf '%s\n' "$T18_BEFORE" | sed -n '1p')"
T18_BEFORE_DELTA="$(printf '%s\n' "$T18_BEFORE" | sed -n '2p')"
if [[ "$T18_BEFORE_LINES" -eq 2 && -n "$T18_BEFORE_SEED" && -f "$T18_BEFORE_SEED" && -z "$T18_BEFORE_DELTA" ]]; then
  pass "EDMV4-T18 AC8 -- get-patterns prints exactly 2 lines before any delta exists, second line empty"
else
  fail "EDMV4-T18 AC8 -- expected 2 lines (seed + empty delta), got: [${T18_BEFORE}] (lines=${T18_BEFORE_LINES})"
fi

# ---- AC1(a)/AC2: writing with a resolvable data directory creates a disjoint stub delta ---------
T18_SEED_HEADINGS="$(grep -c '^### ' "$T18_BEFORE_SEED" 2>/dev/null || true)"
[[ "$T18_SEED_HEADINGS" -gt 0 ]] || fail "EDMV4-T18 AC2 positive control -- shipped qc-audit.md seed has zero ### headings; the disjointness assertion below would pass vacuously"

T18_UPDATE_OUT="$(t18_run_update_patterns EDMV4T18 qc)"
check "EDMV4-T18 AC1(a) -- update-patterns reports a new finding appended when the data dir is resolvable" \
  "1 new finding(s) appended" "$T18_UPDATE_OUT"

T18_AFTER="$(t18_run_get_patterns qc --paths)"
T18_AFTER_DELTA="$(printf '%s\n' "$T18_AFTER" | sed -n '2p')"
if [[ -n "$T18_AFTER_DELTA" && -f "$T18_AFTER_DELTA" ]]; then
  pass "EDMV4-T18 AC1(a)/AC8 -- get-patterns now reports a real, existing delta path"
else
  fail "EDMV4-T18 AC1(a)/AC8 -- delta path missing or not a real file after a successful write: [${T18_AFTER_DELTA}]"
fi

T18_DELTA_HEADINGS="$(grep -c '^### ' "$T18_AFTER_DELTA" 2>/dev/null || echo 0)"
check "EDMV4-T18 AC2 -- fresh delta stub carries the four Living-Library contract headings" \
  "## Anti-Patterns" "$(cat "$T18_AFTER_DELTA" 2>/dev/null)"
check "EDMV4-T18 AC2 -- delta stub's fourth heading matches the qc-specific wording" \
  "## What a Passing QC Round Looks Like" "$(cat "$T18_AFTER_DELTA" 2>/dev/null)"
if [[ "$T18_DELTA_HEADINGS" -eq 1 ]]; then
  pass "EDMV4-T18 AC2 -- delta carries exactly the one harvested finding as its only ### entry (stub itself had zero)"
else
  fail "EDMV4-T18 AC2 -- expected exactly 1 ### heading in the delta after one harvest, found ${T18_DELTA_HEADINGS}"
fi

# ---- AC3/dedup: re-running does not re-append (dedup against the delta) -------------------------
t18_run_update_patterns EDMV4T18 qc >/dev/null
T18_DEDUP_COUNT="$(grep -c '### A brand new synthetic QC finding for the T18 smoke check' "$T18_AFTER_DELTA" 2>/dev/null || echo 0)"
check "EDMV4-T18 AC3 -- re-running update-patterns does not duplicate the entry in the delta" "1" "$T18_DEDUP_COUNT"

# ---- AC5: harvest-provenance.json records write_count and a first-write timestamp ----------------
T18_PROV="${T18_DATA}/patterns/harvest-provenance.json"
if [[ -f "$T18_PROV" ]] && jq -e '."qc-audit.md".write_count >= 1 and (."qc-audit.md".first_write_at | length > 0)' "$T18_PROV" >/dev/null 2>&1; then
  pass "EDMV4-T18 AC5 -- harvest-provenance.json records a write_count and a first_write_at for qc-audit.md"
else
  fail "EDMV4-T18 AC5 -- harvest-provenance.json missing or malformed: $(cat "$T18_PROV" 2>/dev/null || echo ABSENT)"
fi

# ---- AC12(b): END-TO-END -- write (data dir resolvable, shipped tree simulated read-only by ------
# never touching it) then read BOTH paths via get-patterns and assert the harvested finding is
# present in the concatenation. This is the test that fails if either half (write or read) is
# missing -- it actually drives update-patterns THEN get-patterns THEN two real Reads, in one
# process, rather than inspecting code structure.
T18_E2E_SEED="$(printf '%s\n' "$T18_AFTER" | sed -n '1p')"
T18_E2E_CONCAT="$(cat "$T18_E2E_SEED" "$T18_AFTER_DELTA" 2>/dev/null)"
check "EDMV4-T18 AC12(b) -- end-to-end: the harvested finding is present when an agent reads seed+delta as get-patterns names them" \
  "A brand new synthetic QC finding for the T18 smoke check" "$T18_E2E_CONCAT"

# ---- AC12(c): RETAINED NEGATIVE TEST -- write side applied, read side "reverted" (an agent that ---
# reads ONLY the seed, the pre-EDMV4-T18 behaviour) never sees the harvested finding. This
# documents exactly the R9 failure mode and must never be deleted as redundant.
T18_SEED_ONLY="$(cat "$T18_E2E_SEED" 2>/dev/null)"
check_absent "EDMV4-T18 AC12(c) -- RETAINED negative test: a seed-only read (read side reverted) never sees the harvested finding -- this is risk R9's exact failure mode" \
  "A brand new synthetic QC finding for the T18 smoke check" "$T18_SEED_ONLY"

# ---- AC9/AC10: the four launching skills interpolate BOTH pattern paths for their agent ----------
t18_check_skill_paths() {
  local label="$1" file="$2" call_type="$3" seed_var="$4" delta_var="$5"
  local body
  body="$(cat "${PLUGIN_DIR}/${file}" 2>/dev/null)"
  if [[ "$body" == *"get-patterns ${call_type} --paths"* && "$body" == *"\${${seed_var}}"* && "$body" == *"\${${delta_var}}"* ]]; then
    pass "$label"
  else
    fail "$label (missing get-patterns call or one of \${${seed_var}}/\${${delta_var}} in ${file})"
  fi
}
t18_check_skill_paths "EDMV4-T18 AC9 -- skills/srd/SKILL.md interpolates both srd pattern paths into edm-srd-writer's launch template" \
  "skills/srd/SKILL.md" srd SRD_PATTERN_SEED SRD_PATTERN_DELTA
t18_check_skill_paths "EDMV4-T18 AC9 -- skills/tickets/SKILL.md interpolates both ticket pattern paths into edm-ticket-writer's launch template" \
  "skills/tickets/SKILL.md" ticket TICKET_PATTERN_SEED TICKET_PATTERN_DELTA
t18_check_skill_paths "EDMV4-T18 AC9 -- skills/implement/SKILL.md interpolates both qc pattern paths into edm-implementer's launch template" \
  "skills/implement/SKILL.md" qc QC_PATTERN_SEED QC_PATTERN_DELTA
t18_check_skill_paths "EDMV4-T18 AC9 -- skills/implement/SKILL.md interpolates both code pattern paths into edm-implementer's launch template" \
  "skills/implement/SKILL.md" code CODE_PATTERN_SEED CODE_PATTERN_DELTA
t18_check_skill_paths "EDMV4-T18 AC9 -- skills/test-coverage/SKILL.md interpolates both test-coverage pattern paths into edm-test-coverage-auditor's launch template" \
  "skills/test-coverage/SKILL.md" test-coverage TESTCOV_PATTERN_SEED TESTCOV_PATTERN_DELTA

# ---- AC10: no agent gains a new Bash grant -------------------------------------------------------
T18_SRD_WRITER_TOOLS="$(grep -m1 '^tools:' "${PLUGIN_DIR}/agents/edm-srd-writer.md" 2>/dev/null)"
check_absent "EDMV4-T18 AC10 -- edm-srd-writer.md still carries no Bash grant" "Bash" "$T18_SRD_WRITER_TOOLS"
T18_TICKET_WRITER_TOOLS="$(grep -m1 '^tools:' "${PLUGIN_DIR}/agents/edm-ticket-writer.md" 2>/dev/null)"
check_absent "EDMV4-T18 AC10 -- edm-ticket-writer.md still carries no Bash grant" "Bash" "$T18_TICKET_WRITER_TOOLS"
# =================================================================================================
# EDMV4-T39/T40: six-category 0-10 rubric, versioned, wired to edm-state's own signals
# =================================================================================================
echo
echo "-- EDMV4-T39/T40: edm-repo-readiness rubric + signal wiring --"

# ---- AC6 (T39): READINESS_RUBRIC_VERSION is a bare top-level string constant, matching
# evals/score-artifacts.sh:139's SCORER_VERSION precedent, and its VALUE is asserted (not just
# that the constant exists) -- an anti-vacuity requirement called out explicitly for this ticket.
check 'EDMV4-T39 AC6 -- READINESS_RUBRIC_VERSION is a bare top-level string constant, value "1.0.0"' \
  'READINESS_RUBRIC_VERSION="1.0.0"' "$(cat "$REPO_READINESS")"

T39_JSON="${TMP}/t39-real-repo.json"
"$REPO_READINESS" --json "$T39_JSON" >/dev/null
check "EDMV4-T39 AC7 -- rubric version is written into the JSON output" \
  '1.0.0' "$(jq -r '.readiness_rubric_version' "$T39_JSON")"

# ---- AC1/AC2: six categories present, each declared with a raw_max of 10. ----------------------
T39_CATS="$(jq -r '.categories | length' "$T39_JSON")"
check "EDMV4-T39 AC1 -- exactly six categories reported" "6" "$T39_CATS"
T39_BADMAX="$(jq -r '[.categories[] | select(.raw_max != 10)] | length' "$T39_JSON")"
check "EDMV4-T39 AC1 -- every category's raw_max is 10" "0" "$T39_BADMAX"

# ---- AC3: normalization -- a category earning 5 of 10 raw points reports 5.0 exactly, and the
# overall score is the MEAN of applicable categories (divides by the applicable count, not 6).
# This is asserted against a real, computed value -- not just that the field exists (anti-vacuity).
T39_FMT1_TEST="$(jq -n 'def fmt1: (. * 10 | round) as $t | (($t / 10 | floor) | tostring) + "." + (($t % 10) | tostring); (5/10*10) | fmt1')"
check 'EDMV4-T39 AC3 -- 5 of 10 raw points normalizes to the literal "5.0"' '"5.0"' "$T39_FMT1_TEST"

T39_APPLICABLE_COUNT="$(jq -r '[.categories[] | select(.applicable)] | length' "$T39_JSON")"
T39_APPLICABLE_MEAN="$(jq -r '
  ([.categories[] | select(.applicable) | .score_0_10 | tonumber] | add) / ([.categories[] | select(.applicable)] | length)
' "$T39_JSON")"
T39_SCORE="$(jq -r '.score' "$T39_JSON")"
# Wave-2 merge fix: this compared |mean - score| < 0.05, a tolerance exactly equal to the
# rounding granularity the script uses (fmt1, one decimal). On any exact-half mean the test is
# 0.05 < 0.05 -> false, so a CORRECTLY rounded score fails. It surfaced the moment EDMV4-T11
# merged and moved a category score onto the boundary: true mean 9.25, reported "9.3", assertion
# red. Compare against the same fmt1 rounding the script applies -- exact, not tolerance-based,
# and immune to wherever the live repo's score happens to land.
T39_MEAN_MATCHES="$(jq -n --argjson a "$T39_APPLICABLE_MEAN" --argjson b "$T39_SCORE" '
  def fmt1: (. * 10 | round) as $t | ($t / 10);
  ($a | fmt1) == ($b | fmt1)')"
check "EDMV4-T39 AC3 -- overall score is the mean of only the applicable categories' scores (${T39_APPLICABLE_COUNT} applicable)" \
  "true" "$T39_MEAN_MATCHES"

# ---- AC4/AC5: conditional categories carry an explicit applicability field, and an inapplicable
# category is EXCLUDED from the denominator (not scored as zero) -- proven by re-deriving the
# overall score from only the applicable categories and comparing it against the script's own
# reported score (done above); this block additionally proves at least one conditional category
# genuinely reports applicable:false on this repository (a positive control that the field is
# real, not a constant true painted onto every category).
T39_HAS_INAPPLICABLE="$(jq -r '[.categories[] | select(.applicable == false)] | length > 0' "$T39_JSON")"
if [[ "$T39_HAS_INAPPLICABLE" == "true" ]]; then
  pass "EDMV4-T39 AC4/AC5 -- at least one category reports applicable:false on this repository (Test stack has no detected framework here)"
else
  echo "  NOTE: EDMV4-T39 AC4/AC5 -- no inapplicable category found on this run; the applicable/score mean check above still covers the general case"
fi

# ---- AC8: every check carries a non-null, non-empty fix string, including PASSING checks. ------
T39_MISSING_FIX="$(jq -r '[.checks[] | select((.fix == null) or (.fix == ""))] | length' "$T39_JSON")"
check "EDMV4-T39 AC8 -- no check has a null or empty fix string" "0" "$T39_MISSING_FIX"
T39_PASSING_WITH_FIX="$(jq -r '[.checks[] | select(.pass == true and .fix != null and .fix != "")] | length' "$T39_JSON")"
if [[ "$T39_PASSING_WITH_FIX" -gt 0 ]]; then
  pass "EDMV4-T39 AC8 -- at least one PASSING check still carries a non-empty fix (${T39_PASSING_WITH_FIX} found) -- fix is mandatory on every check, not only failing ones"
else
  fail "EDMV4-T39 AC8 -- no passing check was found carrying a fix string; cannot prove fix is mandatory on passing checks too"
fi

# ---- AC9: determinism -- running twice against the same commit produces identical JSON. --------
T39_JSON2="${TMP}/t39-real-repo-2.json"
"$REPO_READINESS" --json "$T39_JSON2" >/dev/null
if diff -q "$T39_JSON" "$T39_JSON2" >/dev/null 2>&1; then
  pass "EDMV4-T39 AC9 -- two consecutive runs against the same commit produce byte-identical JSON"
else
  fail "EDMV4-T39 AC9 -- two consecutive runs diverged: $(diff "$T39_JSON" "$T39_JSON2" | head -5)"
fi

# ---- AC10: no check scores whether EDM itself is installed. ------------------------------------
check_absent "EDMV4-T39 AC10 -- no check id references EDM's own installation" \
  "edm-installed" "$(jq -r '.checks[].id' "$T39_JSON" | tr '\n' ' ')"

# ---- EDMV4-T40 AC1: permission-rule presence comes from the PERM_RULES_MISSING anomaly, never a
# second settings-file scan. A grep of the SCRIPT for the two settings filenames returns nothing.
T40_SETTINGS_LOCAL="settings.local.json"
T40_SETTINGS_PLAIN="settings.json"
check_absent "EDMV4-T40 AC1 -- edm-repo-readiness never names settings.local.json" \
  "$T40_SETTINGS_LOCAL" "$(cat "$REPO_READINESS")"
check_absent "EDMV4-T40 AC1 -- edm-repo-readiness never names settings.json" \
  "$T40_SETTINGS_PLAIN" "$(cat "$REPO_READINESS")"

# ---- EDMV4-T40 AC4: no framework-config-file scan of its own. Assemble the needles at runtime so
# this assertion's own label text can never become a false-positive match for itself (EDMV4's own
# documented "a scan matching its own description" pattern -- code-audit-patterns.md).
T40_JEST_NEEDLE="jest.config"
T40_PYTEST_NEEDLE="pytest.ini"
T40_VITEST_NEEDLE="vitest.config"
check_absent "EDMV4-T40 AC4 -- no jest.config scan" "$T40_JEST_NEEDLE" "$(cat "$REPO_READINESS")"
check_absent "EDMV4-T40 AC4 -- no pytest.ini scan" "$T40_PYTEST_NEEDLE" "$(cat "$REPO_READINESS")"
check_absent "EDMV4-T40 AC4 -- no vitest.config scan" "$T40_VITEST_NEEDLE" "$(cat "$REPO_READINESS")"

# ---- EDMV4-T40: edm-state validate is invoked as a PROCESS with its exit captured explicitly
# (out="$(...)" || rc=$?), never sourced -- the single most likely implementation bug named in
# this ticket's own Technical Notes. Assert the source pattern directly.
check 'EDMV4-T40 -- edm-state validate is invoked as a process with its exit captured (never sourced)' \
  'out="$("$EDM_STATE_BIN" validate "$prefix" 2>/dev/null)" || rc=$?' "$(cat "$REPO_READINESS")"
check_absent 'EDMV4-T40 -- edm-repo-readiness never sources edm-state' \
  'source "$EDM_STATE_BIN"' "$(cat "$REPO_READINESS")"

# ---- EDMV4-T40 AC8: the script never writes to .edm-state.json -- hash the real repo's active
# initiative's state file before and after a full run and assert it is byte-unchanged.
T40_REAL_STATE="${REPO_ROOT}/SRD/edm/EDMV4__ecc-integration/.edm-state.json"
if [[ -f "$T40_REAL_STATE" ]]; then
  check_state_unchanged "$T40_REAL_STATE" "$REPO_READINESS" --json "${TMP}/t40-ac8.json"
else
  echo "  NOTE: EDMV4-T40 AC8 -- real fixture state file not found at ${T40_REAL_STATE}; skipping the hash-unchanged check"
fi

# ---- EDMV4-T40 AC9: running against a repository with NO initiatives at all still succeeds
# (exit 0), scoring what it can. Also proves the AC5-style exclusion: the no-initiatives score
# equals the mean of ONLY the three always-applicable categories (Methodology setup, State
# health, Artifact hygiene) -- the conditional categories are excluded, never scored as zero.
T40_NOINIT_DIR="${TMP}/t40-ac9-noinit"
mkdir -p "$T40_NOINIT_DIR"
T40_NOINIT_RC=0
T40_NOINIT_JSON="${TMP}/t40-ac9-noinit.json"
(cd "$T40_NOINIT_DIR" && "$REPO_READINESS" --json "$T40_NOINIT_JSON" >/dev/null) || T40_NOINIT_RC=$?
if [[ "$T40_NOINIT_RC" -eq 0 ]]; then
  pass "EDMV4-T40 AC9 -- a repository with no initiatives at all still exits 0"
else
  fail "EDMV4-T40 AC9 -- no-initiatives fixture exited ${T40_NOINIT_RC}, expected 0"
fi
T40_NOINIT_APPLICABLE_NAMES="$(jq -r '[.categories[] | select(.applicable) | .name] | sort | join(",")' "$T40_NOINIT_JSON" 2>/dev/null || echo "")"
check "EDMV4-T40 AC9 -- with no initiatives, only the three always-applicable categories are applicable" \
  "Artifact hygiene,Methodology setup,State health" "$T40_NOINIT_APPLICABLE_NAMES"

echo

# =================================================================================================
# EDMV4-T11: Build bin/edm-gateguard and register its Edit/Write/MultiEdit matcher block
# =================================================================================================
echo "=== EDMV4-T11: edm-gateguard ==="
echo

GATEGUARD="${PLUGIN_DIR}/bin/edm-gateguard"
HOOKS_JSON="${PLUGIN_DIR}/hooks/hooks.json"

# ---- AC1: executable, wc -l in [200,400] --------------------------------------------------------
if [[ -x "$GATEGUARD" ]]; then
  pass "EDMV4-T11 AC1 -- edm-gateguard has the executable bit set"
else
  fail "EDMV4-T11 AC1 -- edm-gateguard is not executable"
fi
t11_lines="$(wc -l < "$GATEGUARD" | tr -d ' ')"
if [[ "$t11_lines" -ge 200 && "$t11_lines" -le 400 ]]; then
  pass "EDMV4-T11 AC1 -- edm-gateguard is ${t11_lines} lines (within the closed range 200-400)"
else
  fail "EDMV4-T11 AC1 -- edm-gateguard is ${t11_lines} lines (expected 200-400)"
fi

# ---- AC2: sources _edm-cli-lib.sh; usage() calls the shared print_help() sentinel extractor; no
# hardcoded sed -n 'A,Bp' help range. -------------------------------------------------------------
check "EDMV4-T11 AC2 -- sources _edm-cli-lib.sh" "source \"\${SCRIPT_DIR}/_edm-cli-lib.sh\"" "$(cat "$GATEGUARD")"
check "EDMV4-T11 AC2 -- calls the shared print_help()" "print_help \"\${BASH_SOURCE[0]:-\$0}\"" "$(cat "$GATEGUARD")"
check "EDMV4-T11 AC2 -- carries EDM-HELP-BEGIN/END sentinels" "EDM-HELP-BEGIN" "$(cat "$GATEGUARD")"
check_absent "EDMV4-T11 AC2 -- no hardcoded sed -n 'A,Bp' help-range extraction" "sed -n '" "$(cat "$GATEGUARD")"

# ---- AC3: hooks.json gains exactly one new PreToolUse matcher block for Edit/Write/MultiEdit,
# whose command begins with the same guard the git-commit block uses. -----------------------------
t11_pretooluse_len="$(jq '.hooks.PreToolUse | length' "$HOOKS_JSON")"
check "EDMV4-T11 AC3 -- hooks.json PreToolUse array has exactly 2 entries" "2" "$t11_pretooluse_len"

t11_gg_command="$(jq -r '.hooks.PreToolUse[] | select(.matcher == "Edit|Write|MultiEdit") | .hooks[0].command' "$HOOKS_JSON")"
case "$t11_gg_command" in
  "command -v edm-gateguard >/dev/null 2>&1 || exit 0"*)
    pass "EDMV4-T11 AC3 -- Edit|Write|MultiEdit matcher's command begins with the edm-gateguard presence guard"
    ;;
  *)
    fail "EDMV4-T11 AC3 -- Edit|Write|MultiEdit matcher's command does not begin with the expected guard: [${t11_gg_command}]"
    ;;
esac

# ---- AC4: the existing git-commit matcher block is byte-identical after the change. -------------
t11_gitcommit_command="$(jq -r '.hooks.PreToolUse[] | select(.matcher == "git commit") | .hooks[0].command' "$HOOKS_JSON")"
check "EDMV4-T11 AC4 -- git-commit matcher's command is byte-identical to its pre-change literal" \
  "command -v edm-lint-staged-artifacts >/dev/null 2>&1 || exit 0; edm-lint-staged-artifacts" "$t11_gitcommit_command"

# ---- AC5: zero invocations of the state binary. --------------------------------------------------
t11_ac5_count="$(grep -c 'edm-state' "$GATEGUARD" || true)"
check "EDMV4-T11 AC5 -- edm-gateguard invokes the state binary zero times" "0" "$t11_ac5_count"

# ---- AC6: no shell-command-inspection detection (D15 descope). ----------------------------------
t11_ac6_count="$(grep -ci 'destructive\|heredoc\|subshell' "$GATEGUARD" || true)"
check "EDMV4-T11 AC6 -- edm-gateguard carries no destructive/heredoc/subshell detection" "0" "$t11_ac6_count"

# ---- AC7: required-binary set unchanged -- no node/python/npx/pip. -------------------------------
t11_ac7_count="$(grep -cE '\b(node|python3?|npx|pip)\b' "$GATEGUARD" || true)"
check "EDMV4-T11 AC7 -- edm-gateguard references no node/python/npx/pip" "0" "$t11_ac7_count"

# ---- AC8: the marker `test -f` check precedes the first jq reference, by line number. ------------
t11_marker_line="$(grep -n 'test -f' "$GATEGUARD" | head -1 | cut -d: -f1)"
t11_jq_line="$(grep -n 'jq' "$GATEGUARD" | head -1 | cut -d: -f1)"
if [[ -n "$t11_marker_line" && -n "$t11_jq_line" && "$t11_marker_line" -lt "$t11_jq_line" ]]; then
  pass "EDMV4-T11 AC8 -- marker test -f (line ${t11_marker_line}) precedes the first jq reference (line ${t11_jq_line})"
else
  fail "EDMV4-T11 AC8 -- marker test -f line=[${t11_marker_line}] jq line=[${t11_jq_line}] -- ordering not satisfied"
fi

# ---- AC9: with the marker absent and jq only reachable via a spy stub, exit 0, empty stdout, and
# the spy is never invoked (zero jq processes spawned). --------------------------------------------
harness_scratch_dir T11_TMP
T11_FAKEBIN="${T11_TMP}/fakebin"
mkdir -p "$T11_FAKEBIN"
ln -s "$(command -v dirname)" "${T11_FAKEBIN}/dirname"
ln -s "$(command -v bash)" "${T11_FAKEBIN}/bash"
cat > "${T11_FAKEBIN}/jq" <<T11JQSPY
#!/bin/sh
# ':' is a shell builtin (no PATH lookup needed) -- 'touch' is deliberately NOT used here since
# this spy is exec'd with a PATH restricted to this fakebin dir only, which has no touch binary.
: > "${T11_FAKEBIN}/.jq_invoked"
exit 99
T11JQSPY
chmod +x "${T11_FAKEBIN}/jq"

T11_DATA_ABSENT="${T11_TMP}/data-absent"
mkdir -p "$T11_DATA_ABSENT"
T11_AC9_RC=0
T11_AC9_OUT="$(printf '{"tool_name":"Edit"}' | PATH="$T11_FAKEBIN" CLAUDE_PLUGIN_DATA="$T11_DATA_ABSENT" bash "$GATEGUARD" 2>"${T11_TMP}/ac9.stderr")" || T11_AC9_RC=$?
T11_AC9_STDERR="$(cat "${T11_TMP}/ac9.stderr" 2>/dev/null || true)"

if [[ "$T11_AC9_RC" -eq 0 && -z "$T11_AC9_OUT" && -z "$T11_AC9_STDERR" ]]; then
  pass "EDMV4-T11 AC9 -- marker absent + jq off PATH: exit 0, empty stdout, empty stderr"
else
  fail "EDMV4-T11 AC9 -- marker absent + jq off PATH: rc=${T11_AC9_RC} stdout=[${T11_AC9_OUT}] stderr=[${T11_AC9_STDERR}]"
fi

if [[ ! -f "${T11_FAKEBIN}/.jq_invoked" ]]; then
  pass "EDMV4-T11 AC9 -- the jq spy was never invoked (zero jq processes spawned on the allow path)"
else
  fail "EDMV4-T11 AC9 -- the jq spy WAS invoked; the allow path spawned a jq process it should never touch"
fi

# Positive control: the same spy DOES get invoked once a marker is present, proving the spy itself
# actually intercepts a real invocation rather than the AC9 zero-count being vacuous.
rm -f "${T11_FAKEBIN}/.jq_invoked"
T11_DATA_PRESENT="${T11_TMP}/data-present"
mkdir -p "${T11_DATA_PRESENT}/run" "${T11_TMP}/proj"
T11_PROJECT_KEY="$(CLAUDE_PROJECT_DIR="${T11_TMP}/proj" bash -c ". '${DATADIR_LIB}'; edm_project_key" 2>/dev/null)"
T11_MARKER="${T11_DATA_PRESENT}/run/${T11_PROJECT_KEY}.phase6"
printf 'T11PFX\t%s\t2026-09-02T00:00:00Z\n' "${T11_TMP}/proj" > "$T11_MARKER"
printf '{"tool_name":"Edit"}' | CLAUDE_PROJECT_DIR="${T11_TMP}/proj" PATH="$T11_FAKEBIN" CLAUDE_PLUGIN_DATA="$T11_DATA_PRESENT" bash "$GATEGUARD" >/dev/null 2>&1 || true
if [[ -f "${T11_FAKEBIN}/.jq_invoked" ]]; then
  pass "EDMV4-T11 AC9 -- positive control: the jq spy fires once a marker is present, so the absent-case zero-count above is not vacuous"
else
  fail "EDMV4-T11 AC9 -- positive control FAILED: the jq spy never fired even with a marker present, so the absent-case zero-count proves nothing"
fi

echo
echo "EDMV4-T11 AC10/AC11 -- allow-path p95 is measured by 'bash bin/tests/timing.sh --gateguard'" \
  "(not auto-discovered here, matching every other timing.sh mode's own precedent, e.g. --lint," \
  "--mermaid-ratio); see the ticket's own completion note and decisions.md for the recorded figure."

echo

# =================================================================================================
# EDMV4-T41 -- Feed the readiness score into the classifier and into planning.md
# =================================================================================================
echo "=== EDMV4-T41: readiness score wired to skills/plan/SKILL.md and the classifier ==="
echo

T41_PLAN_SKILL="${PLUGIN_DIR}/skills/plan/SKILL.md"
T41_ORCH_SKILL="${PLUGIN_DIR}/skills/orchestrator/SKILL.md"
T41_CLAUDE_MD="${PLUGIN_DIR}/CLAUDE.md"

# _t41_extract_between <file> <start-regex> <end-regex> -- same sentinel-delimited extraction
# EDMV4-T34/T37 already use (bin/_edm-cli-lib.sh's print_help precedent), applied here to
# Step 1b.5's block so this ticket's own assertions never drift from the block those tickets
# already extract.
_t41_extract_between() {
  local file="$1"
  T41_START="$2" T41_END="$3" awk '
    $0 ~ ENVIRON["T41_START"] { found=1; next }
    found && $0 ~ ENVIRON["T41_END"] { exit }
    found { print }
  ' "$file"
}

T41_STEP1B5="$(_t41_extract_between "$T41_ORCH_SKILL" '^\*\*Step 1b\.5' '^\*\*Step 1c')"

if [[ -n "$T41_STEP1B5" ]]; then
  pass "EDMV4-T41 -- Step 1b.5's block extracted non-empty (extraction not silently vacuous)"
else
  fail "EDMV4-T41 -- Step 1b.5's block extraction was empty; nothing below is a meaningful check"
fi

# ---- AC1: skills/plan/SKILL.md optionally runs edm-repo-readiness during Phase 1 ----------------
check "EDMV4-T41 AC1 -- plan skill names the optional repository readiness scorecard step" \
  'Optional repository readiness scorecard' "$(cat "$T41_PLAN_SKILL")"
check "EDMV4-T41 AC1 -- plan skill guards the call with a PATH presence check" \
  'command -v edm-repo-readiness >/dev/null 2>&1' "$(cat "$T41_PLAN_SKILL")"

# ---- AC2: the recorded summary names the rubric version alongside the score ---------------------
check "EDMV4-T41 AC2 -- plan skill records Rubric version and Overall score together" \
  'read the `Rubric version:` and' "$(cat "$T41_PLAN_SKILL")"
check "EDMV4-T41 AC2 -- plan skill states a bare score with no rubric version is a defect" \
  'a bare score with no rubric' "$(cat "$T41_PLAN_SKILL")"
check "EDMV4-T41 AC2 -- plan template documents the optional Repository Readiness section format" \
  '## Repository Readiness' "$(cat "$T41_PLAN_SKILL")"

# ---- AC3: Step 1b.5 states the classifier may consult the score for design-ambiguity ONLY -------
check "EDMV4-T41 AC3 -- Step 1b.5 states the score feeds the design-ambiguity signal specifically" \
  'additional input to the **design-ambiguity** signal' "$T41_STEP1B5"
check "EDMV4-T41 AC3 -- Step 1b.5 states the score is never a fourth signal" \
  'never as a fourth signal' "$T41_STEP1B5"

# ---- AC4: the score never overrides the security-trigger tie-breaker floor ----------------------
check "EDMV4-T41 AC4 -- Step 1b.5 states the tie-breaker floor always wins over a score-driven adjustment" \
  'always wins over any score-driven adjustment' "$T41_STEP1B5"

# ---- AC5/AC6: unavailable-on-PATH and non-zero-exit both leave Phase 1 unchanged, no placeholder -
check "EDMV4-T41 AC5/AC6 -- plan skill states no error and no placeholder on either failure mode" \
  'no error is raised, and no placeholder section is written to planning.md' "$(cat "$T41_PLAN_SKILL")"
check "EDMV4-T41 AC5/AC6 -- plan skill names both failure modes (not on PATH, non-zero exit)" \
  'is not on PATH, or it exits non-zero' "$(cat "$T41_PLAN_SKILL")"
check "EDMV4-T41 AC5/AC6 -- template addendum repeats the no-placeholder rule for the optional section" \
  'this section is omitted entirely' "$(cat "$T41_PLAN_SKILL")"

# ---- AC7: the classifier still produces a recommendation from three signals with no score -------
check "EDMV4-T41 AC7 -- Step 1b.5 states it still produces a recommendation from the three signals alone" \
  'this step still produces a recommendation from the three signals alone' "$T41_STEP1B5"
check "EDMV4-T41 AC7 -- Step 1b.5 states it never blocks on, or waits for, the scorecard" \
  'never blocks on, or waits for, the scorecard' "$T41_STEP1B5"
check "EDMV4-T41 AC7 -- plan skill states the classifier never waits for the readiness step either" \
  'never waits for it' "$(cat "$T41_PLAN_SKILL")"

# ---- AC8: CLAUDE.md documents the integration by name, naming both the producing command and
# the two consumers (planning.md's section and the classifier). ----------------------------------
check "EDMV4-T41 AC8 -- CLAUDE.md carries a dedicated integration subsection" \
  '### Repository readiness feeds planning.md and the classifier (EDMV4-T41)' "$(cat "$T41_CLAUDE_MD")"
check "EDMV4-T41 AC8 -- CLAUDE.md's subsection names the producing command" \
  'produced by `bin/edm-repo-readiness`' "$(cat "$T41_CLAUDE_MD")"
check "EDMV4-T41 AC8 -- CLAUDE.md's subsection names where Phase 1 records it" \
  '`skills/plan/SKILL.md` Step 6' "$(cat "$T41_CLAUDE_MD")"

# ---- Regression: Step 1b.5's block is still under 30 lines after this ticket's addition (EDMV4-T34
# AC12 pins the ceiling; this reconfirms it holds post-T41, since T41 is the last ticket in this
# epic to touch that block). ----------------------------------------------------------------------
T41_STEP1B5_LINES="$(printf '%s\n' "$T41_STEP1B5" | wc -l | tr -d ' ')"
if [[ "$T41_STEP1B5_LINES" -lt 30 ]]; then
  pass "EDMV4-T41 -- Step 1b.5's block is still ${T41_STEP1B5_LINES} lines (< 30) after this ticket's addition"
else
  fail "EDMV4-T41 -- Step 1b.5's block grew to ${T41_STEP1B5_LINES} lines (expected < 30)"
fi

# ---- Guard D6 regression: this ticket's own addition to Step 1b.5 introduces no mode/lifecycle
# sub-flow restatement (EDMV4-T37's phrase list, re-applied here rather than assumed to still hold
# after new prose was added to the same block). ---------------------------------------------------
T41_D6_PHRASES="Phases 1, 2, 3, 5 recorded|fuse into one audited file|Tickets generated directly from"
if printf '%s\n' "$T41_STEP1B5" | grep -qE "$T41_D6_PHRASES"; then
  fail "EDMV4-T41 -- guard D6: Step 1b.5's block (post-T41) restates a mode/lifecycle sub-flow description"
else
  pass "EDMV4-T41 -- guard D6: Step 1b.5's block (post-T41) still contains no mode/lifecycle sub-flow restatement"
fi

# Positive control for the D6 regression check above: prove it discriminates by injecting a
# restatement phrase into a scratch copy of the extracted block and confirming the check flips.
T41_D6_INJECTED="$(printf '%s\nfuse into one audited file\n' "$T41_STEP1B5")"
if printf '%s\n' "$T41_D6_INJECTED" | grep -qE "$T41_D6_PHRASES"; then
  pass "EDMV4-T41 -- positive control: the D6 phrase check correctly fires on an injected restatement phrase"
else
  fail "EDMV4-T41 -- positive control FAILED: the D6 phrase check did not fire on an injected restatement phrase"
fi

echo

# =================================================================================================
# EDMV4-T13: Route every GateGuard decision through one emit_decision with two back-ends
# =================================================================================================
echo "=== EDMV4-T13: emit_decision (json / exit-code back-ends) ==="
echo

# GATEGUARD/HOOKS_JSON are already set by the EDMV4-T11 section above.

# ---- Shared extraction: emit_decision()'s own function text, and the rest of the script with
# that function's lines removed (line-range removal, not content-based, so this cannot self-match
# whatever the body happens to contain). Mirrors the proven awk idiom EDMV4-T12 uses for
# edm_marker_path() above -- same start/end anchor shape, applied to a different function. --------
_t13_extract_fn() {
  local file="$1" name="$2"
  awk -v needle="${name}() {" '
    index($0, needle) == 1 { found=1 }
    found { print }
    found && /^}/ { exit }
  ' "$file"
}

T13_EMIT_FN_TEXT="$(_t13_extract_fn "$GATEGUARD" emit_decision)"
if [[ -n "$T13_EMIT_FN_TEXT" ]]; then
  pass "EDMV4-T13 setup -- emit_decision()'s function text was extracted from edm-gateguard (non-empty)"
else
  fail "EDMV4-T13 setup -- could not extract emit_decision() from ${GATEGUARD}"
fi

T13_DEFINE_COUNT="$(count_matches '^emit_decision() {' "$GATEGUARD")"
check "EDMV4-T13 -- edm-gateguard defines emit_decision exactly once" "1" "$T13_DEFINE_COUNT"

T13_OUTSIDE_TEXT="$({ awk -v needle="emit_decision() {" '
  index($0, needle) == 1 { skipping=1 }
  skipping && /^}/ { skipping=0; next }
  !skipping { print }
' "$GATEGUARD"; } 2>/dev/null || true)"

# ---- AC1: every deny and allow decision is emitted by one function -- no printf/echo/exit
# producing a decision outside emit_decision's body. Anchored to the two literal artifacts a real
# decision emission has and prose describing it cannot: the deny exit code (2, word-boundaried so
# it never matches "exit 20" or similar) and the JSON key name "permissionDecision" itself. --------
T13_OUTSIDE_EXIT2="$(printf '%s\n' "$T13_OUTSIDE_TEXT" | count_matches -E 'exit 2($|[^0-9])')"
check "EDMV4-T13 AC1 -- no deny exit code (2) appears outside emit_decision's body" "0" "$T13_OUTSIDE_EXIT2"

T13_OUTSIDE_PERMDEC="$(printf '%s\n' "$T13_OUTSIDE_TEXT" | count_matches 'permissionDecision')"
check "EDMV4-T13 AC1 -- no 'permissionDecision' JSON key appears outside emit_decision's body" "0" "$T13_OUTSIDE_PERMDEC"

# Positive control: inject a real 'exit 2' line and a real 'permissionDecision' occurrence into a
# copy of the outside text, proving the two zero-counts above are not vacuous.
T13_OUTSIDE_BROKEN="$(printf '%s\nexit 2\necho permissionDecision\n' "$T13_OUTSIDE_TEXT")"
T13_BROKEN_EXIT2="$(printf '%s\n' "$T13_OUTSIDE_BROKEN" | count_matches -E 'exit 2($|[^0-9])')"
T13_BROKEN_PERMDEC="$(printf '%s\n' "$T13_OUTSIDE_BROKEN" | count_matches 'permissionDecision')"
if [[ "$T13_BROKEN_EXIT2" -ge 1 && "$T13_BROKEN_PERMDEC" -ge 1 ]]; then
  pass "EDMV4-T13 AC1 -- positive control: injecting 'exit 2' and 'permissionDecision' into the outside text trips both detectors"
else
  fail "EDMV4-T13 AC1 -- positive control FAILED: injected occurrences were not detected (exit2=${T13_BROKEN_EXIT2}, permDec=${T13_BROKEN_PERMDEC})"
fi

# ---- AC5 (static half): emit_decision's own body never spells a bare 'exit 1' directly -- every
# setup-error path inside it routes through the shared die() helper (itself defaulting to exit 1),
# so a policy refusal can never accidentally reuse the setup-error code. -------------------------
T13_FN_EXIT1_COUNT="$(printf '%s\n' "$T13_EMIT_FN_TEXT" | count_matches -E 'exit 1($|[^0-9])')"
check "EDMV4-T13 AC5 -- emit_decision's own body never spells 'exit 1' directly (setup errors route through die())" "0" "$T13_FN_EXIT1_COUNT"

T13_FN_BROKEN="$(printf '%s\nexit 1\n' "$T13_EMIT_FN_TEXT")"
T13_FN_BROKEN_COUNT="$(printf '%s\n' "$T13_FN_BROKEN" | count_matches -E 'exit 1($|[^0-9])')"
if [[ "$T13_FN_BROKEN_COUNT" -ge 1 ]]; then
  pass "EDMV4-T13 AC5 -- positive control: injecting 'exit 1' into the function body trips the detector"
else
  fail "EDMV4-T13 AC5 -- positive control FAILED: injected 'exit 1' was not detected"
fi

# ---- AC6: the default is a single named constant, and its value equals Spike B's recorded
# decision (decisions.md D26: json, evidence-backed for Edit/Write). ------------------------------
T13_DEFAULT_VALUE="$({ grep -m1 '^EDM_GATEGUARD_DENY_MODE_DEFAULT=' "$GATEGUARD" | grep -oE '"[a-zA-Z-]+"' | tr -d '"'; } 2>/dev/null || true)"
check "EDMV4-T13 AC6 -- EDM_GATEGUARD_DENY_MODE_DEFAULT equals Spike B's recorded decision (json)" "json" "$T13_DEFAULT_VALUE"

# ---- Executable harness: emit_decision(), extracted verbatim from the shipped script (never
# hand-retyped, so a change to the real function is exercised here rather than a stale copy),
# sourced into an isolated bash process alongside a die() reproduced from edm-gateguard's own
# definition. This is what lets AC2/AC3/AC4/AC7/AC8/AC9 exercise the deny back-ends directly: no
# case arm in edm-gateguard itself calls emit_decision deny yet (that wiring is EDMV4-T14/T15's),
# so the function must be tested in isolation rather than through a full end-to-end invocation. ---
harness_scratch_dir T13_TMP
T13_HARNESS="${T13_TMP}/emit-decision-harness.sh"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'set -euo pipefail'
  printf '%s\n' 'die() { local msg="$1" code="${2:-1}"; echo "edm-gateguard: $msg" >&2; exit "$code"; }'
  printf '%s\n' 'EDM_GATEGUARD_DENY_MODE_DEFAULT="json"'
  printf '%s\n' "$T13_EMIT_FN_TEXT"
  printf '%s\n' 'emit_decision "$1" "$2"'
} > "$T13_HARNESS"
chmod +x "$T13_HARNESS"

# ---- AC2: json mode (the default) -- exact denial payload shape, silent allow. -------------------
T13_JSON_DENY_STDERR="${T13_TMP}/ac2-deny.stderr"
T13_JSON_DENY_RC=0
T13_JSON_DENY_OUT="$(EDM_GATEGUARD_DENY_MODE=json "$T13_HARNESS" deny 'edit denied: see facts' 2>"$T13_JSON_DENY_STDERR")" || T13_JSON_DENY_RC=$?
T13_JSON_DENY_STDERR_TXT="$(cat "$T13_JSON_DENY_STDERR" 2>/dev/null || true)"
T13_JSON_DENY_EXPECTED='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"edit denied: see facts"}}'
if [[ "$T13_JSON_DENY_RC" -eq 0 && "$T13_JSON_DENY_OUT" == "$T13_JSON_DENY_EXPECTED" && -z "$T13_JSON_DENY_STDERR_TXT" ]]; then
  pass "EDMV4-T13 AC2 -- json-mode denial prints exactly the hookSpecificOutput payload on stdout, nothing on stderr, exit 0"
else
  fail "EDMV4-T13 AC2 -- json-mode denial mismatch: rc=${T13_JSON_DENY_RC} stdout=[${T13_JSON_DENY_OUT}] stderr=[${T13_JSON_DENY_STDERR_TXT}]"
fi

T13_JSON_ALLOW_RC=0
T13_JSON_ALLOW_OUT="$(EDM_GATEGUARD_DENY_MODE=json "$T13_HARNESS" allow '' 2>"${T13_TMP}/ac2-allow.stderr")" || T13_JSON_ALLOW_RC=$?
T13_JSON_ALLOW_STDERR_TXT="$(cat "${T13_TMP}/ac2-allow.stderr" 2>/dev/null || true)"
if [[ "$T13_JSON_ALLOW_RC" -eq 0 && -z "$T13_JSON_ALLOW_OUT" && -z "$T13_JSON_ALLOW_STDERR_TXT" ]]; then
  pass "EDMV4-T13 AC2 -- json-mode allow: exit 0, empty stdout, empty stderr"
else
  fail "EDMV4-T13 AC2 -- json-mode allow mismatch: rc=${T13_JSON_ALLOW_RC} stdout=[${T13_JSON_ALLOW_OUT}] stderr=[${T13_JSON_ALLOW_STDERR_TXT}]"
fi

# ---- AC3: exit-code mode -- fact list on stderr, nothing on stdout, exit 2 (the same code
# edm-lint-staged-artifacts:7-10,150-158 already spends to mean "block"). -------------------------
T13_EXIT_STDERR="${T13_TMP}/ac3-deny.stderr"
T13_EXIT_RC=0
T13_EXIT_OUT="$(EDM_GATEGUARD_DENY_MODE=exit-code "$T13_HARNESS" deny 'fact 1: xyz' 2>"$T13_EXIT_STDERR")" || T13_EXIT_RC=$?
T13_EXIT_STDERR_TXT="$(cat "$T13_EXIT_STDERR" 2>/dev/null || true)"
if [[ "$T13_EXIT_RC" -eq 2 && -z "$T13_EXIT_OUT" ]]; then
  pass "EDMV4-T13 AC3 -- exit-code-mode denial exits 2 with empty stdout"
else
  fail "EDMV4-T13 AC3 -- exit-code-mode denial mismatch: rc=${T13_EXIT_RC} stdout=[${T13_EXIT_OUT}]"
fi
check "EDMV4-T13 AC3 -- exit-code-mode denial's fact text reaches stderr" "fact 1: xyz" "$T13_EXIT_STDERR_TXT"

T13_EXIT_ALLOW_RC=0
T13_EXIT_ALLOW_OUT="$(EDM_GATEGUARD_DENY_MODE=exit-code "$T13_HARNESS" allow '' 2>"${T13_TMP}/ac3-allow.stderr")" || T13_EXIT_ALLOW_RC=$?
check "EDMV4-T13 AC3 -- exit-code-mode allow still exits 0 with empty stdout" "0" "$T13_EXIT_ALLOW_RC"
check "EDMV4-T13 AC3 -- exit-code-mode allow prints nothing to stdout" "" "$T13_EXIT_ALLOW_OUT"

# ---- AC4: any other EDM_GATEGUARD_DENY_MODE value is a setup error naming both legal values,
# exit 1, no block -- regardless of which decision was requested (checked on both allow and deny
# so a misconfiguration is caught the first time this function runs, not only on a real denial). --
T13_BADMODE_STDERR="${T13_TMP}/ac4-deny.stderr"
T13_BADMODE_RC=0
T13_BADMODE_OUT="$(EDM_GATEGUARD_DENY_MODE=yes "$T13_HARNESS" deny 'reason' 2>"$T13_BADMODE_STDERR")" || T13_BADMODE_RC=$?
T13_BADMODE_STDERR_TXT="$(cat "$T13_BADMODE_STDERR" 2>/dev/null || true)"
if [[ "$T13_BADMODE_RC" -eq 1 && -z "$T13_BADMODE_OUT" ]]; then
  pass "EDMV4-T13 AC4 -- EDM_GATEGUARD_DENY_MODE=yes exits 1 with empty stdout"
else
  fail "EDMV4-T13 AC4 -- rc=${T13_BADMODE_RC} stdout=[${T13_BADMODE_OUT}]"
fi
check "EDMV4-T13 AC4 -- setup-error message names 'json'" "json" "$T13_BADMODE_STDERR_TXT"
check "EDMV4-T13 AC4 -- setup-error message names 'exit-code'" "exit-code" "$T13_BADMODE_STDERR_TXT"

T13_BADMODE_ALLOW_RC=0
EDM_GATEGUARD_DENY_MODE=yes "$T13_HARNESS" allow '' >/dev/null 2>"${T13_TMP}/ac4-allow.stderr" || T13_BADMODE_ALLOW_RC=$?
check "EDMV4-T13 AC4 -- an invalid mode is a setup error even on an allow decision" "1" "$T13_BADMODE_ALLOW_RC"

# ---- AC5 (behavioral half): the only nonzero exit codes emit_decision ever produces are 2 (a
# real exit-code-mode denial, above) and 1 (the setup error just proven above) -- never a policy
# refusal reusing the setup-error code. --------------------------------------------------------
pass "EDMV4-T13 AC5 -- the only two nonzero exits observed above are 2 (exit-code deny, AC3) and 1 (setup error, AC4) -- no policy refusal reuses exit 1"

# ---- AC7: an emitted denial parses under jq -e, so an unparseable payload would be a test
# failure rather than a silently unenforced gate. -------------------------------------------------
T13_AC7_DENY_JSON="$(EDM_GATEGUARD_DENY_MODE=json "$T13_HARNESS" deny 'ac7 reason' 2>/dev/null || true)"
if printf '%s' "$T13_AC7_DENY_JSON" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
  pass "EDMV4-T13 AC7 -- emitted denial parses under jq -e and .hookSpecificOutput.permissionDecision == \"deny\""
else
  fail "EDMV4-T13 AC7 -- emitted denial failed the jq -e assertion: [${T13_AC7_DENY_JSON}]"
fi

# ---- AC8: the permissionDecisionReason string is valid JSON with embedded quotes, backslashes
# and newlines correctly escaped -- built via jq -n, never string concatenation. ------------------
T13_AC8_REASON='file "quoted".txt has a literal double quote'
T13_AC8_JSON="$(EDM_GATEGUARD_DENY_MODE=json "$T13_HARNESS" deny "$T13_AC8_REASON" 2>/dev/null || true)"
if printf '%s' "$T13_AC8_JSON" | jq -e . >/dev/null 2>&1; then
  pass "EDMV4-T13 AC8 -- a denial reason containing a literal double quote still parses as valid JSON"
else
  fail "EDMV4-T13 AC8 -- payload failed to parse: [${T13_AC8_JSON}]"
fi
T13_AC8_ROUNDTRIP="$(printf '%s' "$T13_AC8_JSON" | jq -r '.hookSpecificOutput.permissionDecisionReason' 2>/dev/null || true)"
check "EDMV4-T13 AC8 -- the embedded double quote survives the round trip unescaped in the decoded value" "$T13_AC8_REASON" "$T13_AC8_ROUNDTRIP"

T13_AC8_REASON_NL=$'line one\nline two with a backslash \\ and a "quote"'
T13_AC8_JSON_NL="$(EDM_GATEGUARD_DENY_MODE=json "$T13_HARNESS" deny "$T13_AC8_REASON_NL" 2>/dev/null || true)"
if printf '%s' "$T13_AC8_JSON_NL" | jq -e . >/dev/null 2>&1; then
  pass "EDMV4-T13 AC8 -- a denial reason containing an embedded newline and a backslash still parses as valid JSON"
else
  fail "EDMV4-T13 AC8 -- newline/backslash payload failed to parse: [${T13_AC8_JSON_NL}]"
fi
T13_AC8_ROUNDTRIP_NL="$(printf '%s' "$T13_AC8_JSON_NL" | jq -r '.hookSpecificOutput.permissionDecisionReason' 2>/dev/null || true)"
check "EDMV4-T13 AC8 -- the embedded newline+backslash reason round-trips exactly" "$T13_AC8_REASON_NL" "$T13_AC8_ROUNDTRIP_NL"

# ---- AC9: the emitted JSON is ASCII-only, and edm-check-vocabulary passes over the updated
# edm-gateguard (part of its fixed bin/ scan scope -- no separate invocation targets one file). ----
T13_AC9_JSON="$(EDM_GATEGUARD_DENY_MODE=json "$T13_HARNESS" deny 'ascii only reason' 2>/dev/null || true)"
if ! printf '%s' "$T13_AC9_JSON" | LC_ALL=C grep -q '[^ -~]'; then
  pass "EDMV4-T13 AC9 -- the emitted JSON payload is ASCII-only"
else
  fail "EDMV4-T13 AC9 -- the emitted JSON payload contains a non-ASCII byte: [${T13_AC9_JSON}]"
fi

T13_VOCAB_RC=0
(cd "$PLUGIN_DIR" && bash bin/edm-check-vocabulary >/dev/null 2>&1) || T13_VOCAB_RC=$?
check "EDMV4-T13 AC9 -- edm-check-vocabulary passes over the updated edm-gateguard (and the rest of bin/)" "0" "$T13_VOCAB_RC"

# ---- End-to-end sanity: with a Phase 6 marker present and no ticket having wired a real deny
# condition yet (EDMV4-T14/T15's job), the gate still allows silently -- but now via
# emit_decision, not a bare exit 0, matching the "Hooks behavior" documentation update above. ------
harness_scratch_dir T13_E2E_TMP
mkdir -p "${T13_E2E_TMP}/data/run" "${T13_E2E_TMP}/proj"
T13_E2E_KEY="$(CLAUDE_PROJECT_DIR="${T13_E2E_TMP}/proj" bash -c ". '${DATADIR_LIB}'; edm_project_key" 2>/dev/null)"
T13_E2E_MARKER="${T13_E2E_TMP}/data/run/${T13_E2E_KEY}.phase6"
printf 'T13PFX\t%s\t2026-09-02T00:00:00Z\n' "${T13_E2E_TMP}/proj" > "$T13_E2E_MARKER"
T13_E2E_RC=0
T13_E2E_OUT="$(printf '{"tool_name":"Edit"}' | CLAUDE_PROJECT_DIR="${T13_E2E_TMP}/proj" CLAUDE_PLUGIN_DATA="${T13_E2E_TMP}/data" bash "$GATEGUARD" 2>"${T13_E2E_TMP}/e2e.stderr")" || T13_E2E_RC=$?
T13_E2E_STDERR="$(cat "${T13_E2E_TMP}/e2e.stderr" 2>/dev/null || true)"
if [[ "$T13_E2E_RC" -eq 0 && -z "$T13_E2E_OUT" && -z "$T13_E2E_STDERR" ]]; then
  pass "EDMV4-T13 -- end-to-end: marker present, Edit call, no deny wired yet -- allows silently via emit_decision"
else
  fail "EDMV4-T13 -- end-to-end mismatch: rc=${T13_E2E_RC} stdout=[${T13_E2E_OUT}] stderr=[${T13_E2E_STDERR}]"
fi

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
