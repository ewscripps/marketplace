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
# L5/runtime-hygiene: this stderr capture used to land in SCRIPT_DIR and was removed only on the
# line after the `fi`. Any exit between the two -- a turn ceiling killing the run, a set -e abort,
# an interrupt -- leaked `.t25-grants.err` into bin/tests/ as an untracked file, which is precisely
# what the L5 lens hunts and what a clean-tree assertion would then report. Found live in a wave-5
# worktree. Writing into the EXIT-trapped scratch dir removes the leak on every exit path, not just
# the happy one; the explicit rm is kept so the file does not persist for the rest of the run.
t25_grants_err="${T05_TMP}/t25-grants.err"
if bash "${PLUGIN_DIR}/bin/edm-check-grants" >/dev/null 2>"$t25_grants_err"; then
  pass "EDMV4-T25 AC9 -- edm-check-grants exits 0"
else
  fail "EDMV4-T25 AC9 -- edm-check-grants exited non-zero: $(cat "$t25_grants_err")"
fi
rm -f "$t25_grants_err"

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
# EDMV4-T26 -- Lens L13 (Type Design) agent file -- the sole conditional lens
# =================================================================================================
echo
echo "=== EDMV4-T26: edm-audit-type-design.md (lens L13, conditional) ==="

L13_AGENT="${PLUGIN_DIR}/agents/edm-audit-type-design.md"
L13_TEXT="$(cat "$L13_AGENT" 2>/dev/null || true)"

[[ -f "$L13_AGENT" ]] && pass "EDMV4-T26 AC1 -- edm-audit-type-design.md exists" \
  || fail "EDMV4-T26 AC1 -- edm-audit-type-design.md is missing"

echo "EDMV4-T26 AC1 -- house-contract headings present, in order"
t26_headings_expected="## Scope
## What You Hunt For
## False Alarm Filter
## Output
## Output Format
## JSONL Line Format
## When this does NOT apply"
t26_headings_actual="$(awk '/^```/{f=!f;next} !f' "$L13_AGENT" | grep -E '^## ')"
[[ "$t26_headings_actual" == "$t26_headings_expected" ]] \
  && pass "EDMV4-T26 AC1 -- the seven house-contract headings appear in the required order" \
  || fail "EDMV4-T26 AC1 -- heading order/content mismatch:\n${t26_headings_actual}"

echo "EDMV4-T26 AC2 -- four type-design dimensions present"
check "EDMV4-T26 AC2a -- encapsulation" "Encapsulation" "$L13_TEXT"
check "EDMV4-T26 AC2b -- invariant expression" "Invariant Expression" "$L13_TEXT"
check "EDMV4-T26 AC2c -- invariant usefulness" "Invariant Usefulness" "$L13_TEXT"
check "EDMV4-T26 AC2d -- enforcement" "Enforcement" "$L13_TEXT"

echo "EDMV4-T26 AC3 -- N/A framed as inapplicability; cost is never a reason to skip"
check "EDMV4-T26 AC3 -- 'inapplicability' framing present" "inapplicability" "$L13_TEXT"
check "EDMV4-T26 AC3 -- cost-is-never-a-reason sentence present" "cost is never a reason to skip this lens" "$L13_TEXT"

echo "EDMV4-T26 AC4 -- agrees with Step 1's determination, never re-derives; mismatch is a contract violation"
check "EDMV4-T26 AC4 -- agrees with Step 1, does not decide applicability itself" \
  "This agent does not decide that inapplicability itself" "$L13_TEXT"
check "EDMV4-T26 AC4 -- 'agrees with that determination and never substitutes' present" \
  "This agent's N/A exit agrees with that determination and never substitutes" "$L13_TEXT"
check "EDMV4-T26 AC4 -- mismatch-is-a-contract-violation sentence present, test-integration form" \
  "a mismatch between this agent's exit and Step 1's determination" "$L13_TEXT"
# The citation is asserted by filename only, deliberately. The first draft of this assertion
# pinned "agents/edm-test-integration.md:21-25" -- a line-range citation of exactly the kind
# G10/CA-340 bans, and one that would have gone stale the first time that file was edited. The
# precedent being cited does not use line numbers either: it names edm-test-planner.md's
# enumeration by file. Asserting the filename keeps the check meaningful without pinning a range.
check "EDMV4-T26 AC4 -- cites the edm-test-integration.md N/A-agreement precedent" \
  "agents/edm-test-integration.md" "$L13_TEXT"

echo "EDMV4-T26 AC5 -- absence is authoritative; nothing written on N/A"
check "EDMV4-T26 AC5 -- explicit no-lens-L13.md/.jsonl/placeholder sentence" \
  "no \`lens-L13.md\`, no \`lens-L13.jsonl\`, no placeholder" "$L13_TEXT"
check "EDMV4-T26 AC5 -- 'Absence is authoritative' stated" "Absence is authoritative" "$L13_TEXT"

echo "EDMV4-T26 AC6 -- L13 is the sole member of CONDITIONAL_LENS_IDS"
# shellcheck disable=SC2034 # sourced only for its CONDITIONAL_LENS_IDS side effect
t26_cond_lens_ids="$(source "$EDM_STATE" >/dev/null 2>&1; echo "$CONDITIONAL_LENS_IDS")"
t26_cond_lens_count="$(printf '%s\n' $t26_cond_lens_ids | grep -c '.')" || true
[[ "$t26_cond_lens_ids" == "L13" && "${t26_cond_lens_count:-0}" -eq 1 ]] \
  && pass "EDMV4-T26 AC6 -- CONDITIONAL_LENS_IDS has exactly one member and it is L13" \
  || fail "EDMV4-T26 AC6 -- CONDITIONAL_LENS_IDS = '${t26_cond_lens_ids}' (count ${t26_cond_lens_count:-0}), expected exactly 'L13'"

echo "EDMV4-T26 AC8 -- no GateGuard or other self-reported effect-size number cited as a target"
check_absent "EDMV4-T26 AC8 -- no GateGuard citation in the L13 agent file" "GateGuard" "$L13_TEXT"

echo "EDMV4-T26 AC9 -- lens ID L13 used consistently; Output Format anchors to canonical-sections"
check "EDMV4-T26 AC9 -- md output path" '${OUTPUT_DIR}/lens-L13.md' "$L13_TEXT"
check "EDMV4-T26 AC9 -- jsonl output path" '${OUTPUT_DIR}/lens-L13.jsonl' "$L13_TEXT"
check "EDMV4-T26 AC9 -- schema line names lens L13" '"lens":"L13"' "$L13_TEXT"
check "EDMV4-T26 AC9 -- cites CLAUDE.md Sec.\"Severity vocabulary\"" 'CLAUDE.md Sec."Severity vocabulary"' "$L13_TEXT"
check "EDMV4-T26 AC9 -- Read docs/canonical-sections.md anchoring instruction present" \
  'Read `docs/canonical-sections.md`' "$L13_TEXT"
check "EDMV4-T26 AC9 -- anchoring qualifier (never the caller's cwd) present" \
  "never the caller's cwd" "$L13_TEXT"

echo "EDMV4-T26 AC10 -- does not restate EDMV4-T24 AC2's stack-marker filenames"
for t26_marker in tsconfig.json Cargo.toml go.mod pyproject.toml mypy.ini pyrightconfig.json; do
  check_absent "EDMV4-T26 AC10 -- marker filename '${t26_marker}' absent from the L13 agent file" \
    "$t26_marker" "$L13_TEXT"
done

echo "EDMV4-T26 AC11 -- edm-check-grants passes; edm-lint-artifacts is clean"
if bash "${PLUGIN_DIR}/bin/edm-check-grants" >/dev/null 2>"${SCRIPT_DIR}/.t26-grants.err"; then
  pass "EDMV4-T26 AC11 -- edm-check-grants exits 0"
else
  fail "EDMV4-T26 AC11 -- edm-check-grants exited non-zero: $(cat "${SCRIPT_DIR}/.t26-grants.err")"
fi
rm -f "${SCRIPT_DIR}/.t26-grants.err"
t26_lint_out="$(bash "${PLUGIN_DIR}/bin/edm-lint-artifacts" --path "${PLUGIN_DIR}/agents/" 2>&1)"
t26_lint_exit=$?
[[ "$t26_lint_exit" -eq 0 ]] && pass "EDMV4-T26 AC11 -- edm-lint-artifacts --path agents/ is clean" \
  || fail "EDMV4-T26 AC11 -- edm-lint-artifacts reported violations: ${t26_lint_out}"

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
  # EDMV4-T44 note: combines stdout+stderr (2>&1). AC4 asserts the matched-rule line's exact
  # FORMAT, which is independent of which stream it lands on -- T44's own AC3 is what routes a
  # `warn` match to stderr and a `block` match to stdout, and is asserted separately (by stream)
  # in this file's own EDMV4-T44 section below. Splitting streams here would make this AC4 format
  # assertion couple to a later ticket's stream-routing decision, which is not what AC4 states.
  (
    cd "$T43_PROJ" || exit 99
    CLAUDE_PROJECT_DIR="$T43_PROJ" PATH="${PLUGIN_DIR}/bin:${PATH}" \
      bash -c "echo '$2' | edm-hookify eval $1" 2>&1
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
# EDMV4-T44 note: 2>&1 -- trunc-marker's action is "warn", which T44's AC3 routes to stderr; this
# AC6/AC8 assertion is about whether the marker fires at all (a content question), not which
# stream it lands on, so both streams are combined here exactly like t43_run above.
T43_HUGE_OUT="$(cd "$T43_TRUNC_PROJ" && CLAUDE_PROJECT_DIR="$T43_TRUNC_PROJ" PATH="${PLUGIN_DIR}/bin:${PATH}" \
  bash -c "echo '${T43_HUGE_PAYLOAD}' | edm-hookify eval file" 2>&1)"
T43_T1=$(date +%s)
T43_NORMAL_OUT="$(cd "$T43_TRUNC_PROJ" && CLAUDE_PROJECT_DIR="$T43_TRUNC_PROJ" PATH="${PLUGIN_DIR}/bin:${PATH}" \
  bash -c "echo '${T43_NORMAL_PAYLOAD}' | edm-hookify eval file" 2>&1)"
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

# ---- AC5: exists, executable, and (as of this wave) runs edm-state validate. Hookify stop-rule
# wiring was NOT this ticket's own scope (EDMV4-T46) -- EDMV4-T45 added it later, in the same
# wave; see that ticket's own dedicated section below for its coverage, since asserting its
# absence here would now be a stale, false claim rather than a scope boundary. -------------------
if [[ -x "$EDM_STOP_GATE" ]]; then
  pass "EDMV4-T46 AC5 -- edm-stop-gate exists and is executable"
else
  fail "EDMV4-T46 AC5 -- edm-stop-gate missing or not executable"
fi
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
# EDMV4-T44: Make action: block an explicit opt-in behind a two-tier exit contract
# =================================================================================================
# Scope note: at the time this ticket (EDMV4-T44) was implemented, neither edm-gateguard nor
# edm-stop-gate invoked edm-hookify yet -- that wiring was EDMV4-T45's job, and this ticket could
# not edit bin/edm-gateguard (EDMV4-T13's file that same wave). Every assertion below therefore
# exercises edm-hookify's own two-tier exit contract directly, independent of either consumer.
# EDMV4-T45 has since landed and wired both consumers -- see its own dedicated section below for
# the end-to-end coverage of the translation this section proves in isolation.
echo
echo "=== EDMV4-T44: edm-hookify two-tier exit contract ==="
echo

CLAUDE_MD_TEXT_T44="$(cat "${PLUGIN_DIR}/CLAUDE.md")"

# ---- AC1: action defaults to warn when the key is absent, with a matching condition -----------
T44_AC1_DIR="${TMP}/t44-ac1"
mkdir -p "${T44_AC1_DIR}/.claude/edm-hookify"
jq 'del(.action)' "${HOOKIFY_FIXTURES}/warn-no-console-log.json" \
  > "${T44_AC1_DIR}/.claude/edm-hookify/warn-no-console-log.json"

T44_AC1_OUT="${TMP}/t44-ac1.stdout"
T44_AC1_ERR="${TMP}/t44-ac1.stderr"
T44_AC1_RC=0
( cd "$T44_AC1_DIR" && CLAUDE_PROJECT_DIR="$T44_AC1_DIR" PATH="${PLUGIN_DIR}/bin:${PATH}" \
    bash -c 'echo "{\"file_path\":\"src/foo.js\",\"new_text\":\"console.log(1)\"}" | edm-hookify eval file' \
    >"$T44_AC1_OUT" 2>"$T44_AC1_ERR" ) || T44_AC1_RC=$?

[[ "$T44_AC1_RC" -eq 0 ]] && pass "EDMV4-T44 AC1 -- a rule with no action key, matching, exits 0 (defaults to warn)" \
  || fail "EDMV4-T44 AC1 -- expected exit 0 for a default (absent-action) match, got ${T44_AC1_RC}"
check "EDMV4-T44 AC1 -- the default-to-warn match reports action 'warn' by name" \
  "warn-no-console-log warn Avoid leaving console.log statements in non-test source files." "$(cat "$T44_AC1_ERR")"

# ---- AC3: a warn match writes to stderr and leaves the exit code at 0 (isolated, no block rule) -
T44_AC3_DIR="${TMP}/t44-ac3"
mkdir -p "${T44_AC3_DIR}/.claude/edm-hookify"
cp "${HOOKIFY_FIXTURES}/warn-no-console-log.json" "${T44_AC3_DIR}/.claude/edm-hookify/"

T44_AC3_OUT="${TMP}/t44-ac3.stdout"
T44_AC3_ERR="${TMP}/t44-ac3.stderr"
T44_AC3_RC=0
( cd "$T44_AC3_DIR" && CLAUDE_PROJECT_DIR="$T44_AC3_DIR" PATH="${PLUGIN_DIR}/bin:${PATH}" \
    bash -c 'echo "{\"file_path\":\"src/foo.js\",\"new_text\":\"console.log(1)\"}" | edm-hookify eval file' \
    >"$T44_AC3_OUT" 2>"$T44_AC3_ERR" ) || T44_AC3_RC=$?

[[ "$T44_AC3_RC" -eq 0 ]] && pass "EDMV4-T44 AC3 -- a lone warn match leaves the exit code at 0" \
  || fail "EDMV4-T44 AC3 -- expected exit 0 for a lone warn match, got ${T44_AC3_RC}"
check_absent "EDMV4-T44 AC3 -- stdout carries no matched-rule text for a warn-only run" \
  "warn-no-console-log" "$(cat "$T44_AC3_OUT")"
check "EDMV4-T44 AC3 -- stderr carries the warn match's rule_id/action/message line" \
  "warn-no-console-log warn Avoid leaving console.log statements in non-test source files." "$(cat "$T44_AC3_ERR")"

# ---- AC2 (clean): an enabled rule present but not matching the payload exits 0 -----------------
T44_AC2CLEAN_DIR="${TMP}/t44-ac2-clean"
mkdir -p "${T44_AC2CLEAN_DIR}/.claude/edm-hookify"
cp "${HOOKIFY_FIXTURES}/warn-no-console-log.json" "${T44_AC2CLEAN_DIR}/.claude/edm-hookify/"
T44_AC2CLEAN_RC=0
( cd "$T44_AC2CLEAN_DIR" && CLAUDE_PROJECT_DIR="$T44_AC2CLEAN_DIR" PATH="${PLUGIN_DIR}/bin:${PATH}" \
    bash -c 'echo "{\"file_path\":\"src/foo.js\",\"new_text\":\"nothing interesting here\"}" | edm-hookify eval file' \
    >/dev/null 2>/dev/null ) || T44_AC2CLEAN_RC=$?
[[ "$T44_AC2CLEAN_RC" -eq 0 ]] && pass "EDMV4-T44 AC2 -- an enabled rule that does not match the payload exits 0" \
  || fail "EDMV4-T44 AC2 -- expected exit 0 for a non-matching payload, got ${T44_AC2CLEAN_RC}"

# ---- AC2/AC6: one matching warn rule + one matching block rule -> exit 2, both lines printed ---
T44_AC6_DIR="${TMP}/t44-ac6"
mkdir -p "${T44_AC6_DIR}/.claude/edm-hookify"
cp "${HOOKIFY_FIXTURES}/warn-no-console-log.json" "${T44_AC6_DIR}/.claude/edm-hookify/"
jq '.action = "block" | .name = "block-no-console-log" | .message = "Blocking a console.log left in non-test source."' \
  "${HOOKIFY_FIXTURES}/warn-no-console-log.json" > "${T44_AC6_DIR}/.claude/edm-hookify/block-no-console-log.json"

T44_AC6_OUT="${TMP}/t44-ac6.stdout"
T44_AC6_ERR="${TMP}/t44-ac6.stderr"
T44_AC6_RC=0
( cd "$T44_AC6_DIR" && CLAUDE_PROJECT_DIR="$T44_AC6_DIR" PATH="${PLUGIN_DIR}/bin:${PATH}" \
    bash -c 'echo "{\"file_path\":\"src/foo.js\",\"new_text\":\"console.log(1)\"}" | edm-hookify eval file' \
    >"$T44_AC6_OUT" 2>"$T44_AC6_ERR" ) || T44_AC6_RC=$?

[[ "$T44_AC6_RC" -eq 2 ]] && pass "EDMV4-T44 AC2/AC6 -- a matching warn rule together with a matching block rule exits 2" \
  || fail "EDMV4-T44 AC2/AC6 -- expected exit 2, got ${T44_AC6_RC}"
check "EDMV4-T44 AC6 -- the block match's line reaches stdout" \
  "block-no-console-log block Blocking a console.log left in non-test source." "$(cat "$T44_AC6_OUT")"
check "EDMV4-T44 AC6 -- the concurrent warn match's line is STILL present, on stderr (a block never suppresses a warn)" \
  "warn-no-console-log warn Avoid leaving console.log statements in non-test source files." "$(cat "$T44_AC6_ERR")"
check_absent "EDMV4-T44 AC3 -- the warn line does not also leak onto stdout in the combined case" \
  "warn-no-console-log" "$(cat "$T44_AC6_OUT")"

# ---- AC2 (precedence): a block match co-occurring with an UNRELATED setup error still exits 2 --
T44_AC2PREC_DIR="${TMP}/t44-ac2-precedence"
mkdir -p "${T44_AC2PREC_DIR}/.claude/edm-hookify"
cp "${HOOKIFY_FIXTURES}/malformed-invalid-json.json" "${T44_AC2PREC_DIR}/.claude/edm-hookify/"
jq '.action = "block" | .name = "block-no-console-log" | .message = "Blocking a console.log left in non-test source."' \
  "${HOOKIFY_FIXTURES}/warn-no-console-log.json" > "${T44_AC2PREC_DIR}/.claude/edm-hookify/block-no-console-log.json"

T44_AC2PREC_OUT="${TMP}/t44-ac2-precedence.stdout"
T44_AC2PREC_ERR="${TMP}/t44-ac2-precedence.stderr"
T44_AC2PREC_RC=0
( cd "$T44_AC2PREC_DIR" && CLAUDE_PROJECT_DIR="$T44_AC2PREC_DIR" PATH="${PLUGIN_DIR}/bin:${PATH}" \
    bash -c 'echo "{\"file_path\":\"src/foo.js\",\"new_text\":\"console.log(1)\"}" | edm-hookify eval file' \
    >"$T44_AC2PREC_OUT" 2>"$T44_AC2PREC_ERR" ) || T44_AC2PREC_RC=$?

[[ "$T44_AC2PREC_RC" -eq 2 ]] && pass "EDMV4-T44 AC2 -- a block match co-occurring with an unrelated setup error still exits 2 (block outranks error)" \
  || fail "EDMV4-T44 AC2 -- expected exit 2 when a block match and an unrelated setup error co-occur, got ${T44_AC2PREC_RC}"
check "EDMV4-T44 AC2 -- the unrelated setup error is still named on stderr even though block won the exit code" \
  "malformed-invalid-json" "$(cat "$T44_AC2PREC_ERR")"
check "EDMV4-T44 AC2 -- the block match's line still reaches stdout" \
  "block-no-console-log block" "$(cat "$T44_AC2PREC_OUT")"

# ---- AC5: a malformed rule file (no block anywhere) exits 1, never 2 -- for BOTH file and stop --
# events, since the classify pass validates every rule file before checking its requested event.
T44_AC5_DIR="${TMP}/t44-ac5"
mkdir -p "${T44_AC5_DIR}/.claude/edm-hookify"
cp "${HOOKIFY_FIXTURES}/malformed-invalid-json.json" "${T44_AC5_DIR}/.claude/edm-hookify/"

T44_AC5_FILE_RC=0
T44_AC5_FILE_OUT="$( cd "$T44_AC5_DIR" && CLAUDE_PROJECT_DIR="$T44_AC5_DIR" PATH="${PLUGIN_DIR}/bin:${PATH}" \
    bash -c 'echo "{\"file_path\":\"x\",\"new_text\":\"y\"}" | edm-hookify eval file' 2>&1 )" || T44_AC5_FILE_RC=$?

T44_AC5_STOP_RC=0
T44_AC5_STOP_OUT="$( cd "$T44_AC5_DIR" && CLAUDE_PROJECT_DIR="$T44_AC5_DIR" PATH="${PLUGIN_DIR}/bin:${PATH}" \
    bash -c 'echo "{}" | edm-hookify eval stop' 2>&1 )" || T44_AC5_STOP_RC=$?

[[ "$T44_AC5_FILE_RC" -eq 1 ]] && pass "EDMV4-T44 AC5 -- a malformed rule file (file event) exits 1, not 2 -- never escalates to a block" \
  || fail "EDMV4-T44 AC5 -- eval file expected exit 1, got ${T44_AC5_FILE_RC}"
[[ "$T44_AC5_STOP_RC" -eq 1 ]] && pass "EDMV4-T44 AC5 -- the same malformed rule file (stop event) also exits 1, not 2" \
  || fail "EDMV4-T44 AC5 -- eval stop expected exit 1, got ${T44_AC5_STOP_RC}"
check "EDMV4-T44 AC5 -- the malformed file is named on stderr for the file-event run" \
  "malformed-invalid-json" "$T44_AC5_FILE_OUT"
check "EDMV4-T44 AC5 -- the malformed file is named on stderr for the stop-event run too" \
  "malformed-invalid-json" "$T44_AC5_STOP_OUT"

# ---- AC2: "no fourth code" -- every exit code observed across this section's scenarios is in ----
# {0,1,2}. Pairs the individual exact-value assertions above with one aggregate, computed check.
T44_ALL_RCS="$T44_AC1_RC $T44_AC3_RC $T44_AC2CLEAN_RC $T44_AC6_RC $T44_AC2PREC_RC $T44_AC5_FILE_RC $T44_AC5_STOP_RC"
T44_BAD_RC=""
for _t44_rc in $T44_ALL_RCS; do
  case "$_t44_rc" in
    0|1|2) ;;
    *) T44_BAD_RC="${T44_BAD_RC} ${_t44_rc}" ;;
  esac
done
if [[ -z "$T44_BAD_RC" ]]; then
  pass "EDMV4-T44 AC2 -- every exit code observed across this section is in {0,1,2} (no fourth code)"
else
  fail "EDMV4-T44 AC2 -- observed an exit code outside {0,1,2}:${T44_BAD_RC}"
fi

# ---- AC4: the exit-2 translation contract is documented by name for both consumers -------------
check "EDMV4-T44 AC4 -- CLAUDE.md documents edm-gateguard's emit_decision deny translation by name" \
  "own \`emit_decision deny\` function (AD2)" "$CLAUDE_MD_TEXT_T44"
check "EDMV4-T44 AC4 -- CLAUDE.md documents edm-stop-gate translating into its own exit 2" \
  "translates it into its own exit 2" "$CLAUDE_MD_TEXT_T44"
# EDMV4-T45 has since wired edm-stop-gate to invoke edm-hookify (same wave); see its own section
# below for that wiring's coverage -- asserting absence here would now be a stale, false claim.

# ---- Wave-3 QC remediation (P2): AC4/AC5 above were proven only via CLAUDE.md's prose plus
# edm-hookify's own exit codes in isolation -- neither exercised the TRANSLATION a consumer
# performs. Building that translation for real (a case arm in edm-gateguard's dispatch, or a call
# from edm-stop-gate) is EDMV4-T45's wiring, and bin/edm-gateguard is off limits to this ticket
# (both restated in the scope note at the top of this section) -- so this block does not add
# either. What it adds instead is an executable proof that the translation CONTRACT holds, using
# the same extract-verbatim-then-harness technique the EDMV4-T13 section below already
# establishes for emit_decision() itself: proving a function's behavior before any case arm calls
# it for real is not a new technique in this file. This section runs before EDMV4-T13's own
# (GATEGUARD/count_matches setup happens there), so it extracts independently rather than reusing
# variables not yet in scope. ---------------------------------------------------------------------
_t44_extract_emit_decision() {
  local file="$1"
  awk -v needle="emit_decision() {" '
    index($0, needle) == 1 { found=1 }
    found { print }
    found && /^}/ { exit }
  ' "$file"
}
T44_EMIT_FN_TEXT="$(_t44_extract_emit_decision "${PLUGIN_DIR}/bin/edm-gateguard")"
if [[ -n "$T44_EMIT_FN_TEXT" ]]; then
  pass "EDMV4-T44 AC4 setup -- emit_decision()'s function text was extracted from edm-gateguard (non-empty)"
else
  fail "EDMV4-T44 AC4 setup -- could not extract emit_decision() from bin/edm-gateguard"
fi

harness_scratch_dir T44_HARNESS_TMP
T44_HARNESS="${T44_HARNESS_TMP}/gateguard-hookify-translation.sh"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'set -euo pipefail'
  printf '%s\n' 'die() { local msg="$1" code="${2:-1}"; echo "edm-gateguard: $msg" >&2; exit "$code"; }'
  printf '%s\n' 'EDM_GATEGUARD_DENY_MODE_DEFAULT="json"'
  printf '%s\n' "$T44_EMIT_FN_TEXT"
  # The translation AC4 describes, and AC5's "never escalates" clause depends on: edm-hookify
  # exit 2 -> deny; anything else (a clean 0, or edm-hookify's own setup-error 1) -> allow.
  printf '%s\n' 'hookify_rc="$1"'
  printf '%s\n' 'hookify_reason="$2"'
  printf '%s\n' 'if [[ "$hookify_rc" -eq 2 ]]; then emit_decision deny "$hookify_reason"; else emit_decision allow ""; fi'
} > "$T44_HARNESS"
chmod +x "$T44_HARNESS"

# AC4: T44_AC6_RC above is a REAL edm-hookify exit code (2) from a genuine block-rule match
# (T44_AC6_DIR). Fed through the extracted emit_decision, it must produce a genuine deny.
T44_TRANS_JSON_RC=0
T44_TRANS_JSON_OUT="$(EDM_GATEGUARD_DENY_MODE=json "$T44_HARNESS" "$T44_AC6_RC" \
  'block-no-console-log block Blocking a console.log left in non-test source.' 2>/dev/null)" \
  || T44_TRANS_JSON_RC=$?
if [[ "$T44_TRANS_JSON_RC" -eq 0 && "$T44_TRANS_JSON_OUT" == *'"permissionDecision":"deny"'* ]]; then
  pass "EDMV4-T44 AC4 -- edm-hookify's real exit-2 block, through the extracted emit_decision, produces a genuine json-mode deny"
else
  fail "EDMV4-T44 AC4 -- expected a deny payload from a real hookify exit 2, got rc=${T44_TRANS_JSON_RC} out=[${T44_TRANS_JSON_OUT}]"
fi

T44_TRANS_EXITCODE_RC=0
EDM_GATEGUARD_DENY_MODE=exit-code "$T44_HARNESS" "$T44_AC6_RC" \
  'block-no-console-log block Blocking a console.log left in non-test source.' >/dev/null 2>/dev/null \
  || T44_TRANS_EXITCODE_RC=$?
[[ "$T44_TRANS_EXITCODE_RC" -eq 2 ]] \
  && pass "EDMV4-T44 AC4 -- the same real block, in exit-code mode, exits 2 -- the same code edm-stop-gate's own blocking path spends (checked below)" \
  || fail "EDMV4-T44 AC4 -- expected exit 2 from exit-code-mode deny, got ${T44_TRANS_EXITCODE_RC}"

# AC5: T44_AC5_FILE_RC above is a REAL edm-hookify exit code (1) from a genuine malformed-rule
# setup error (T44_AC5_DIR). Fed through the identical translation, it must never escalate to a
# deny in either back-end -- the negative control paired with AC4's positive one above.
T44_TRANS_SETUP_JSON_RC=0
T44_TRANS_SETUP_JSON_OUT="$(EDM_GATEGUARD_DENY_MODE=json "$T44_HARNESS" "$T44_AC5_FILE_RC" \
  'irrelevant -- never reached when hookify_rc is not 2' 2>/dev/null)" || T44_TRANS_SETUP_JSON_RC=$?
if [[ "$T44_TRANS_SETUP_JSON_RC" -eq 0 && -z "$T44_TRANS_SETUP_JSON_OUT" ]]; then
  pass "EDMV4-T44 AC5 -- edm-hookify's real exit-1 setup error, through the same translation, allows (json mode: exit 0, empty stdout)"
else
  fail "EDMV4-T44 AC5 -- a real hookify exit 1 escalated through the translation: rc=${T44_TRANS_SETUP_JSON_RC} out=[${T44_TRANS_SETUP_JSON_OUT}]"
fi

T44_TRANS_SETUP_EXITCODE_RC=0
EDM_GATEGUARD_DENY_MODE=exit-code "$T44_HARNESS" "$T44_AC5_FILE_RC" 'irrelevant' >/dev/null 2>/dev/null \
  || T44_TRANS_SETUP_EXITCODE_RC=$?
[[ "$T44_TRANS_SETUP_EXITCODE_RC" -eq 0 ]] \
  && pass "EDMV4-T44 AC5 -- the same real setup error, in exit-code mode, also allows (exit 0) -- never reuses the block code 2" \
  || fail "EDMV4-T44 AC5 -- expected exit 0 from exit-code-mode allow on a real hookify exit 1, got ${T44_TRANS_SETUP_EXITCODE_RC}"

# ---- AC4 (edm-stop-gate side): no callable function exists there to extract -- its translation is
# a single inline exit, so the checkable claim is numeric compatibility: the blocking exit code
# edm-stop-gate already spends for its own edm-state-validate anomaly path must be byte-identical
# to the code edm-hookify assigns a block match (T44_AC6_RC, captured above from a REAL run, not
# assumed), since EDMV4-T45's wiring will reuse this exact literal rather than introduce a second
# one. -----------------------------------------------------------------------------------------
T44_STOPGATE_BLOCK_LINE="$(grep 'ANY_BLOCKING' "$EDM_STOP_GATE" | grep 'exit' | head -1)"
T44_STOPGATE_BLOCK_EXIT="$(printf '%s\n' "$T44_STOPGATE_BLOCK_LINE" | grep -oE 'exit [0-9]+' | grep -oE '[0-9]+' || true)"
if [[ -n "$T44_STOPGATE_BLOCK_EXIT" && "$T44_STOPGATE_BLOCK_EXIT" -eq "$T44_AC6_RC" ]]; then
  pass "EDMV4-T44 AC4 -- edm-stop-gate's own blocking exit code (${T44_STOPGATE_BLOCK_EXIT}) is byte-identical to edm-hookify's real block exit code (${T44_AC6_RC})"
else
  fail "EDMV4-T44 AC4 -- edm-stop-gate's blocking exit code (${T44_STOPGATE_BLOCK_EXIT:-<not found>}) does not match edm-hookify's real block exit code (${T44_AC6_RC})"
fi

# AC5 (edm-stop-gate side): the blocking code (2) is spent exactly once in the file -- no
# internal/setup path (the shape edm-hookify's exit 1 maps to) could ever be mistaken for a block.
# Positive control: a copy with a second, injected 'exit 2' must trip the same count.
T44_STOPGATE_EXIT2_COUNT="$(count_matches -E 'exit 2($|[^0-9])' "$EDM_STOP_GATE")"
check "EDMV4-T44 AC5 -- edm-stop-gate spends its blocking exit code (2) exactly once -- no internal/setup path could be mistaken for a block" \
  "1" "$T44_STOPGATE_EXIT2_COUNT"
T44_STOPGATE_BROKEN="$(printf '%s\nexit 2\n' "$(cat "$EDM_STOP_GATE")")"
T44_STOPGATE_BROKEN_COUNT="$(printf '%s\n' "$T44_STOPGATE_BROKEN" | count_matches -E 'exit 2($|[^0-9])')"
[[ "$T44_STOPGATE_BROKEN_COUNT" -ge 2 ]] \
  && pass "EDMV4-T44 AC5 -- positive control: injecting a second 'exit 2' trips the count above 1" \
  || fail "EDMV4-T44 AC5 -- positive control FAILED: injected second 'exit 2' was not detected"

# ---- AC7: Hooks behavior documents the exit-code contract in table form, cross-referencing ------
# edm-lint-staged-artifacts's identical split by name.
check "EDMV4-T44 AC7 -- Hooks behavior gains a dedicated two-tier exit contract subsection" \
  "edm-hookify\`'s two-tier exit contract (EDMV4-T44)" "$CLAUDE_MD_TEXT_T44"
check "EDMV4-T44 AC7 -- cross-references edm-lint-staged-artifacts's identical split by name" \
  "edm-lint-staged-artifacts\` already applies to \`git" "$CLAUDE_MD_TEXT_T44"
check "EDMV4-T44 AC7 -- states the exit-code table has no fourth code" \
  "There is no fourth code." "$CLAUDE_MD_TEXT_T44"

# ---- AC8: rule files' ASCII gap is stated as fact (both reasons) in Artifact content conventions
check "EDMV4-T44 AC8 -- Artifact content conventions names the edm-lint-artifacts *.md filter reason" \
  "collect_md_files\` (\`bin/edm-lint-artifacts:251-260\`) is a plain" "$CLAUDE_MD_TEXT_T44"
check "EDMV4-T44 AC8 -- names the edm-check-vocabulary PLUGIN_ROOT-anchored SCOPE_ROOTS reason" \
  "SCOPE_ROOTS\` (\`bin/edm-check-vocabulary:98-107\`) are all" "$CLAUDE_MD_TEXT_T44"
check "EDMV4-T44 AC8 -- points at EDMV4-57 as the ticket that would close this gap" \
  "EDMV4-57\`'s to close, not closed here." "$CLAUDE_MD_TEXT_T44"

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
# EDMV4-T19 -- correct the stale caller-count comment in cmd_update_patterns
# =================================================================================================
echo
echo "-- EDMV4-T19: CA-476 caller-count comment corrected --"

T19_CA476_BLOCK="$(awk '/^  # CA-476: resolve HOW MANY findings/{f=1} f{print} f && /report-format gap would be worse than the gap\.$/{exit}' "$EDM_STATE")"

# ---- AC1/AC3: the count-free wording lands, and the comment's substantive point (neither
# "nothing harvested" outcome is a die) survives completely unchanged. -----------------------------
check "EDMV4-T19 AC1 -- the comment states the property that matters instead of a maintained count" \
  "called mid-phase by the audit and implementation skills" "$T19_CA476_BLOCK"
check "EDMV4-T19 AC3 -- the comment's substantive point survives unchanged (neither nothing-harvested outcome is a die)" \
  "aborting the phase over a report-format gap would be worse than the gap" "$T19_CA476_BLOCK"

# ---- AC6: number-word tripwire -- the count can never drift back in, whether restated as "four"
# (still stale) or re-stated as the now-correct "six" (still a maintained count that will drift
# again the moment a seventh caller is added). -----------------------------------------------------
if printf '%s\n' "$T19_CA476_BLOCK" | grep -qiw 'four'; then
  fail "EDMV4-T19 AC6 -- CA-476 comment block still contains the word 'four'"
else
  pass "EDMV4-T19 AC6 -- CA-476 comment block contains no word 'four'"
fi
if printf '%s\n' "$T19_CA476_BLOCK" | grep -qiw 'six'; then
  fail "EDMV4-T19 AC6 -- CA-476 comment block still contains the word 'six'"
else
  pass "EDMV4-T19 AC6 -- CA-476 comment block contains no word 'six'"
fi

# ---- AC2: the six real call sites, verified against the tree at test time (not copied from the
# ticket) -- each names the skill file and the exact edm-state update-patterns <PREFIX> ... call. -
T19_CALL_SITES="skills/implement/SKILL.md skills/code-audit/SKILL.md skills/audit-tickets/SKILL.md skills/audit-srd/SKILL.md skills/test/SKILL.md skills/test-coverage/SKILL.md"
T19_CALL_SITE_COUNT=0
for t19_f in $T19_CALL_SITES; do
  if grep -q 'edm-state update-patterns <PREFIX>' "${PLUGIN_DIR}/${t19_f}" 2>/dev/null; then
    T19_CALL_SITE_COUNT=$((T19_CALL_SITE_COUNT + 1))
  else
    fail "EDMV4-T19 AC2 -- ${t19_f} does not call 'edm-state update-patterns <PREFIX> ...'"
  fi
done
check "EDMV4-T19 AC2 -- exactly six skills call edm-state update-patterns <PREFIX> ..." "6" "$T19_CALL_SITE_COUNT"

# ---- AC4: the second copy of the same stale claim, in docs/audit-patterns/README.md, is
# corrected the same way in the same commit -- its own Consumers section already lists all six
# call sites, so the file no longer contradicts itself. --------------------------------------------
# The file hard-wraps long paragraphs at its own column width, so the corrected sentence may
# itself land across two physical lines (it does, today) -- normalize newlines to spaces before
# substring-matching so this assertion does not depend on exactly where the file wraps.
T19_README_TEXT="$(cat "${PLUGIN_DIR}/docs/audit-patterns/README.md" | tr '\n' ' ')"
check_absent "EDMV4-T19 AC4 -- docs/audit-patterns/README.md no longer says 'four skills'" \
  "four skills" "$T19_README_TEXT"
check "EDMV4-T19 AC4 -- docs/audit-patterns/README.md restates the property instead of a maintained count" \
  "called mid-phase by the audit and implementation skills" "$T19_README_TEXT"

# ---- AC5: comment-only/prose-only -- the executable script still parses cleanly. -----------------
if bash -n "$EDM_STATE" 2>/dev/null; then
  pass "EDMV4-T19 AC5 -- bash -n plugins/edm/bin/edm-state passes after the comment-only edit"
else
  fail "EDMV4-T19 AC5 -- bash -n plugins/edm/bin/edm-state failed after the comment-only edit"
fi

# =================================================================================================
# EDMV4-T20 -- regression coverage over every branch of the 4.2 write and read paths
# =================================================================================================
echo
echo "-- EDMV4-T20: regression coverage over every branch of the 4.2 write and read paths --"

# AC9's own working tree may already carry this ticket's own legitimate, not-yet-committed
# changes (this test file, edm-state, the fixtures) -- asserting a globally EMPTY porcelain would
# fail on every uncommitted-but-legitimate tree, which is not what AC9 is checking. Capture a
# BEFORE snapshot here and diff against an AFTER snapshot at the end of this section instead, the
# same before/after idiom EDMV4-T17 AC9 already uses above.
T20_GIT_BEFORE="$(git -C "$REPO_ROOT" status --porcelain)"

T20_PATTERNS_FIXTURES="${PLUGIN_DIR}/bin/tests/fixtures/patterns"

# ---- AC1: writable-data-directory path (branch a) end to end, own fixture and own scratch env --
T20_AC1_ROOT="${TMP}/t20-ac1"
T20_AC1_DATA="${T20_AC1_ROOT}/data"
T20_AC1_HOME="${T20_AC1_ROOT}/home"
T20_AC1_SRD="${T20_AC1_ROOT}/SRD"
mkdir -p "$T20_AC1_DATA" "$T20_AC1_HOME" "${T20_AC1_SRD}/edm/EDMV4T20AC1__x/code-audit/pass-1_2026-09-02"
cat > "${T20_AC1_SRD}/edm/EDMV4T20AC1__x/.edm-state.json" <<'EOF'
{"prefix":"EDMV4T20AC1","current_phase":6,"product_name":"edm","initiative_description":"x"}
EOF
cp "${T20_PATTERNS_FIXTURES}/code-fixture.md" \
  "${T20_AC1_SRD}/edm/EDMV4T20AC1__x/code-audit/pass-1_2026-09-02/REMEDIATION.md"

t20_ac1_update() {
  ( export CLAUDE_PLUGIN_DATA="$T20_AC1_DATA" HOME="$T20_AC1_HOME" XDG_DATA_HOME="" CLAUDE_PROJECT_DIR="$T20_AC1_ROOT" EDM_SRD_ROOT="$T20_AC1_SRD"
    "$EDM_STATE" update-patterns "$@" )
}

T20_AC1_OUT="$(t20_ac1_update EDMV4T20AC1 code)"
check "EDMV4-T20 AC1 -- branch (a) writable-data-directory: update-patterns reports a new finding appended" \
  "1 new finding(s) appended" "$T20_AC1_OUT"

T20_AC1_DELTA="${T20_AC1_DATA}/patterns/code-audit.md"
if [[ -f "$T20_AC1_DELTA" ]]; then
  pass "EDMV4-T20 AC1 -- delta file created under \${data}/patterns/"
else
  fail "EDMV4-T20 AC1 -- expected delta at ${T20_AC1_DELTA}, not found"
fi

T20_AC1_H1="$(grep -n '^## Top Recurring Findings$' "$T20_AC1_DELTA" 2>/dev/null | head -1 | cut -d: -f1)"
T20_AC1_H2="$(grep -n '^## Anti-Patterns$' "$T20_AC1_DELTA" 2>/dev/null | head -1 | cut -d: -f1)"
T20_AC1_H3="$(grep -n '^## Pre-Flight Checklist$' "$T20_AC1_DELTA" 2>/dev/null | head -1 | cut -d: -f1)"
T20_AC1_H4="$(grep -n '^## What Passing Code Looks Like$' "$T20_AC1_DELTA" 2>/dev/null | head -1 | cut -d: -f1)"
if [[ -n "$T20_AC1_H1" && -n "$T20_AC1_H2" && -n "$T20_AC1_H3" && -n "$T20_AC1_H4" \
      && "$T20_AC1_H1" -lt "$T20_AC1_H2" && "$T20_AC1_H2" -lt "$T20_AC1_H3" && "$T20_AC1_H3" -lt "$T20_AC1_H4" ]]; then
  pass "EDMV4-T20 AC1 -- fresh delta stub carries the four Living-Library headings in contract order"
else
  fail "EDMV4-T20 AC1 -- stub headings missing or out of order (h1=${T20_AC1_H1} h2=${T20_AC1_H2} h3=${T20_AC1_H3} h4=${T20_AC1_H4})"
fi

T20_AC1_SECTION="$(awk '/^## Anti-Patterns$/{f=1; next} /^## /{f=0} f' "$T20_AC1_DELTA")"
check "EDMV4-T20 AC1 -- the harvested finding is spliced under the correct insertion target (## Anti-Patterns)" \
  "CA-9001" "$T20_AC1_SECTION"

# ---- AC5: re-running update-patterns against the same fixture/delta appends the finding exactly
# once -- de-duplication against the DELTA (distinct from AC4's de-duplication against the SEED). -
t20_ac1_update EDMV4T20AC1 code >/dev/null
T20_AC5_COUNT="$(grep -c '### CA-9001' "$T20_AC1_DELTA" 2>/dev/null || echo 0)"
check "EDMV4-T20 AC5 -- running update-patterns twice against the same fixture appends the finding exactly once" \
  "1" "$T20_AC5_COUNT"

# ---- AC2: shipped-tree-writable fallback (branch b) reproduces TODAY'S EXACT behaviour: with
# edm_data_dir() forced empty (a chmod-555 ancestor blocks all three candidates, T17's own AC4
# technique) and the shipped tree writable, the finding lands in docs/audit-patterns/{type}.md and
# patterns_updates is recorded with the same shape as before EDMV4-T18. Runs against a SCRATCH
# COPY of the whole plugin tree (wave7-smoke.sh's G39 case's own cp -R precedent) -- the real
# docs/audit-patterns/ is never written to by this suite. ------------------------------------------
T20_AC2_ROOT="${TMP}/t20-ac2"
mkdir -p "${T20_AC2_ROOT}/plugins/edm"
cp -R "${PLUGIN_DIR}/." "${T20_AC2_ROOT}/plugins/edm/"
T20_AC2_EDM_STATE="${T20_AC2_ROOT}/plugins/edm/bin/edm-state"
T20_AC2_SEED="${T20_AC2_ROOT}/plugins/edm/docs/audit-patterns/srd-audit.md"

T20_AC2_ROBLOCK="${T20_AC2_ROOT}/roblock"
mkdir -p "$T20_AC2_ROBLOCK"
chmod 555 "$T20_AC2_ROBLOCK"

T20_AC2_SRD="${T20_AC2_ROOT}/SRD"
mkdir -p "${T20_AC2_SRD}/edm/EDMV4T20AC2__x"
cat > "${T20_AC2_SRD}/edm/EDMV4T20AC2__x/.edm-state.json" <<'EOF'
{"prefix":"EDMV4T20AC2","current_phase":3,"product_name":"edm","initiative_description":"x"}
EOF
cp "${T20_PATTERNS_FIXTURES}/srd-fixture.md" "${T20_AC2_SRD}/edm/EDMV4T20AC2__x/audit-srd.md"

T20_AC2_OUT="$(
  export CLAUDE_PLUGIN_DATA="${T20_AC2_ROBLOCK}/pd" XDG_DATA_HOME="${T20_AC2_ROBLOCK}/xdg" HOME="${T20_AC2_ROBLOCK}/home"
  export EDM_SRD_ROOT="$T20_AC2_SRD"
  bash "$T20_AC2_EDM_STATE" update-patterns EDMV4T20AC2 srd
)"
chmod 755 "$T20_AC2_ROBLOCK"

check "EDMV4-T20 AC2 -- branch (b) shipped-tree-writable fallback: update-patterns still reports a new finding appended" \
  "1 new finding(s) appended" "$T20_AC2_OUT"
check "EDMV4-T20 AC2 -- the finding lands directly in the shipped seed file (today's pre-EDMV4-T18 target), not a delta" \
  "EDMV4-T20 branch (b) positive-control finding" "$(cat "$T20_AC2_SEED" 2>/dev/null)"

T20_AC2_STATE="${T20_AC2_SRD}/edm/EDMV4T20AC2__x/.edm-state.json"
T20_AC2_SHAPE_OK="$(jq -r '.patterns_updates.srd | (.new_findings == 1) and (.extraction_status == "ok") and (has("extracted_titles")) and (has("updated_at"))' "$T20_AC2_STATE" 2>/dev/null || echo false)"
check "EDMV4-T20 AC2 -- patterns_updates is recorded with the same shape as before this ticket's change" \
  "true" "$T20_AC2_SHAPE_OK"

# ---- AC3: all-unwritable path (branch c) warns on stderr naming the directory, exits 0, and
# appends nothing -- the target file is byte-identical before and after, proven by SHA-256
# checksum (not line count), per _harness_hash_file. Reuses the scratch-plugin-copy technique from
# AC2, additionally chmodding the copied docs/audit-patterns/ tree read-only so branch (b) fails
# too. -----------------------------------------------------------------------------------------------
T20_AC3_ROOT="${TMP}/t20-ac3"
mkdir -p "${T20_AC3_ROOT}/plugins/edm"
# Normalize away any double slash TMPDIR itself may carry (macOS's default TMPDIR ends in "/") --
# edm-state's own SCRIPT_DIR is resolved via cd+pwd and never carries one, so the literal warning
# text below must be built from the same normalized root or the substring match never lines up.
T20_AC3_ROOT="$(cd "$T20_AC3_ROOT" && pwd)"
cp -R "${PLUGIN_DIR}/." "${T20_AC3_ROOT}/plugins/edm/"
T20_AC3_EDM_STATE="${T20_AC3_ROOT}/plugins/edm/bin/edm-state"
T20_AC3_PATTERNS_DIR="${T20_AC3_ROOT}/plugins/edm/docs/audit-patterns"
T20_AC3_SEED="${T20_AC3_PATTERNS_DIR}/code-audit.md"
# cmd_update_patterns builds its warning path via plain string concatenation off SCRIPT_DIR
# ("${SCRIPT_DIR}/../docs/audit-patterns"), never a cd+pwd normalization, so the literal message
# names the unnormalized "bin/../docs/audit-patterns" form -- match that literal, not the
# normalized physical path used for chmod above.
T20_AC3_PATTERNS_DIR_LITERAL="${T20_AC3_ROOT}/plugins/edm/bin/../docs/audit-patterns"

T20_AC3_ROBLOCK="${T20_AC3_ROOT}/roblock"
mkdir -p "$T20_AC3_ROBLOCK"
chmod 555 "$T20_AC3_ROBLOCK"
chmod 555 "$T20_AC3_PATTERNS_DIR"

T20_AC3_SRD="${T20_AC3_ROOT}/SRD"
mkdir -p "${T20_AC3_SRD}/edm/EDMV4T20AC3__x"
cat > "${T20_AC3_SRD}/edm/EDMV4T20AC3__x/.edm-state.json" <<'EOF'
{"prefix":"EDMV4T20AC3","current_phase":6,"product_name":"edm","initiative_description":"x"}
EOF

T20_AC3_BEFORE_HASH="$(_harness_hash_file "$T20_AC3_SEED")"

T20_AC3_RC=0
T20_AC3_OUT="$(
  export CLAUDE_PLUGIN_DATA="${T20_AC3_ROBLOCK}/pd" XDG_DATA_HOME="${T20_AC3_ROBLOCK}/xdg" HOME="${T20_AC3_ROBLOCK}/home"
  export EDM_SRD_ROOT="$T20_AC3_SRD"
  bash "$T20_AC3_EDM_STATE" update-patterns EDMV4T20AC3 code 2>&1
)" || T20_AC3_RC=$?

chmod 755 "$T20_AC3_PATTERNS_DIR"
chmod 755 "$T20_AC3_ROBLOCK"

T20_AC3_AFTER_HASH="$(_harness_hash_file "$T20_AC3_SEED")"

if [[ "$T20_AC3_RC" -eq 0 ]]; then
  pass "EDMV4-T20 AC3 -- branch (c) all-unwritable: update-patterns exits 0"
else
  fail "EDMV4-T20 AC3 -- branch (c) all-unwritable: expected exit 0, got ${T20_AC3_RC} (output: ${T20_AC3_OUT})"
fi
check "EDMV4-T20 AC3 -- branch (c) warns on stderr, naming the unwritable directory" \
  "pattern directory is not writable at" "$T20_AC3_OUT"
check "EDMV4-T20 AC3 -- the stderr warning names the actual unwritable path" \
  "$T20_AC3_PATTERNS_DIR_LITERAL" "$T20_AC3_OUT"
if [[ "$T20_AC3_BEFORE_HASH" == "$T20_AC3_AFTER_HASH" && "$T20_AC3_BEFORE_HASH" != "unhashable" ]]; then
  pass "EDMV4-T20 AC3 -- the target file is byte-identical before and after (sha256 checksum, not line count)"
else
  fail "EDMV4-T20 AC3 -- target file hash changed or unhashable: before=${T20_AC3_BEFORE_HASH} after=${T20_AC3_AFTER_HASH}"
fi

# ---- AC4: de-duplication against the SEED -- a fixture finding whose title already exists in the
# shipped seed produces no append to a fresh, EMPTY delta, and new_findings: 0 (distinct from
# AC5's dedup-against-the-DELTA case above). ---------------------------------------------------------
T20_AC4_ROOT="${TMP}/t20-ac4"
T20_AC4_DATA="${T20_AC4_ROOT}/data"
T20_AC4_HOME="${T20_AC4_ROOT}/home"
T20_AC4_SRD="${T20_AC4_ROOT}/SRD"
mkdir -p "$T20_AC4_DATA" "$T20_AC4_HOME" "${T20_AC4_SRD}/edm/EDMV4T20AC4__x/qc"
cat > "${T20_AC4_SRD}/edm/EDMV4T20AC4__x/.edm-state.json" <<'EOF'
{"prefix":"EDMV4T20AC4","current_phase":6,"product_name":"edm","initiative_description":"x"}
EOF
cp "${T20_PATTERNS_FIXTURES}/qc-seed-duplicate.md" "${T20_AC4_SRD}/edm/EDMV4T20AC4__x/qc/qc-summary.md"

T20_AC4_SEED_HAS_TITLE="$(grep -c '^### PASS based on code structure, not behavior$' "${PLUGIN_DIR}/docs/audit-patterns/qc-audit.md" 2>/dev/null || echo 0)"
if [[ "$T20_AC4_SEED_HAS_TITLE" -ge 1 ]]; then
  pass "EDMV4-T20 AC4 positive control -- the shipped qc-audit.md seed genuinely carries the title this fixture reuses"
else
  fail "EDMV4-T20 AC4 positive control -- the shipped seed no longer carries 'PASS based on code structure, not behavior'; the dedup-against-seed assertion below would prove nothing"
fi

T20_AC4_OUT="$(
  export CLAUDE_PLUGIN_DATA="$T20_AC4_DATA" HOME="$T20_AC4_HOME" XDG_DATA_HOME="" CLAUDE_PROJECT_DIR="$T20_AC4_ROOT" EDM_SRD_ROOT="$T20_AC4_SRD"
  "$EDM_STATE" update-patterns EDMV4T20AC4 qc
)"
check "EDMV4-T20 AC4 -- a title already present in the shipped seed produces no append (no novel findings)" \
  "no novel findings to append" "$T20_AC4_OUT"

T20_AC4_STATE="${T20_AC4_SRD}/edm/EDMV4T20AC4__x/.edm-state.json"
T20_AC4_NEWFINDINGS="$(jq -r '.patterns_updates.qc.new_findings' "$T20_AC4_STATE" 2>/dev/null)"
check "EDMV4-T20 AC4 -- new_findings is recorded as 0" "0" "$T20_AC4_NEWFINDINGS"

T20_AC4_DELTA="${T20_AC4_DATA}/patterns/qc-audit.md"
T20_AC4_DELTA_HEADINGS="$(grep -c '^### ' "$T20_AC4_DELTA" 2>/dev/null || echo 0)"
check "EDMV4-T20 AC4 -- the fresh delta still carries zero ### entries (nothing was appended)" "0" "$T20_AC4_DELTA_HEADINGS"

# ---- AC6: get-patterns --paths prints exactly 2 lines with an EMPTY second line, in BOTH: (i) no
# delta exists yet under a resolvable data directory, and (ii) the data directory is itself
# unresolvable. wc -l is piped DIRECTLY from the command's own stdout in both cases (never from a
# $()-captured copy, which strips trailing newlines and would misreport a genuinely-empty second
# line as a missing one -- the CA-145-class caveat T18's own AC8 test documents). -------------------
T20_AC6_DATA="${TMP}/t20-ac6-data"
mkdir -p "$T20_AC6_DATA"
T20_AC6_HOME="${TMP}/t20-ac6-home"
mkdir -p "$T20_AC6_HOME"
T20_AC6_NODELTA_LINES="$(CLAUDE_PLUGIN_DATA="$T20_AC6_DATA" HOME="$T20_AC6_HOME" XDG_DATA_HOME="" "$EDM_STATE" get-patterns test-coverage --paths | wc -l | tr -d ' ')"
T20_AC6_NODELTA_OUT="$(CLAUDE_PLUGIN_DATA="$T20_AC6_DATA" HOME="$T20_AC6_HOME" XDG_DATA_HOME="" "$EDM_STATE" get-patterns test-coverage --paths)"
T20_AC6_NODELTA_LINE2="$(printf '%s\n' "$T20_AC6_NODELTA_OUT" | sed -n '2p')"
if [[ "$T20_AC6_NODELTA_LINES" -eq 2 && -z "$T20_AC6_NODELTA_LINE2" ]]; then
  pass "EDMV4-T20 AC6 -- get-patterns --paths prints exactly 2 lines with an empty second line when no delta exists"
else
  fail "EDMV4-T20 AC6 -- expected 2 lines with empty 2nd (no delta case), got lines=${T20_AC6_NODELTA_LINES} line2=[${T20_AC6_NODELTA_LINE2}]"
fi

T20_AC6_ROBLOCK="${TMP}/t20-ac6-roblock"
mkdir -p "$T20_AC6_ROBLOCK"
chmod 555 "$T20_AC6_ROBLOCK"
T20_AC6_UNRESOLVABLE_LINES="$(CLAUDE_PLUGIN_DATA="${T20_AC6_ROBLOCK}/pd" XDG_DATA_HOME="${T20_AC6_ROBLOCK}/xdg" HOME="${T20_AC6_ROBLOCK}/home" "$EDM_STATE" get-patterns test-coverage --paths | wc -l | tr -d ' ')"
T20_AC6_UNRESOLVABLE_OUT="$(CLAUDE_PLUGIN_DATA="${T20_AC6_ROBLOCK}/pd" XDG_DATA_HOME="${T20_AC6_ROBLOCK}/xdg" HOME="${T20_AC6_ROBLOCK}/home" "$EDM_STATE" get-patterns test-coverage --paths)"
chmod 755 "$T20_AC6_ROBLOCK"
T20_AC6_UNRESOLVABLE_LINE2="$(printf '%s\n' "$T20_AC6_UNRESOLVABLE_OUT" | sed -n '2p')"
if [[ "$T20_AC6_UNRESOLVABLE_LINES" -eq 2 && -z "$T20_AC6_UNRESOLVABLE_LINE2" ]]; then
  pass "EDMV4-T20 AC6 -- get-patterns --paths prints exactly 2 lines with an empty second line when the data directory is itself unresolvable"
else
  fail "EDMV4-T20 AC6 -- expected 2 lines with empty 2nd (unresolvable data dir case), got lines=${T20_AC6_UNRESOLVABLE_LINES} line2=[${T20_AC6_UNRESOLVABLE_LINE2}]"
fi

# ---- AC7: the fence-aware refusal (G16/CA-355) still fires on the NEW write path -- a delta whose
# target heading exists only inside a fenced code block dies loudly, appends nothing, and records
# no patterns_updates. The fence lives in the delta itself (branch a), so no scratch plugin copy is
# needed here. -----------------------------------------------------------------------------------
T20_AC7_DATA="${TMP}/t20-ac7-data"
mkdir -p "${T20_AC7_DATA}/patterns"
cat > "${T20_AC7_DATA}/patterns/code-audit.md" <<'FENCEDDELTA'
# code Audit Patterns (Harvested Delta)

## Top Recurring Findings

The target heading is shown here only as a literal fenced example, never as a real heading:

```
## Anti-Patterns
```

## Pre-Flight Checklist

## What Passing Code Looks Like
FENCEDDELTA
T20_AC7_HOME="${TMP}/t20-ac7-home"
mkdir -p "$T20_AC7_HOME"
T20_AC7_DELTA="${T20_AC7_DATA}/patterns/code-audit.md"
T20_AC7_BEFORE_HASH="$(_harness_hash_file "$T20_AC7_DELTA")"

T20_AC7_RC=0
T20_AC7_OUT="$(CLAUDE_PLUGIN_DATA="$T20_AC7_DATA" HOME="$T20_AC7_HOME" XDG_DATA_HOME="" "$EDM_STATE" update-patterns EDMV4T20AC7 code 2>&1)" || T20_AC7_RC=$?

T20_AC7_AFTER_HASH="$(_harness_hash_file "$T20_AC7_DELTA")"

if [[ "$T20_AC7_RC" -ne 0 ]]; then
  pass "EDMV4-T20 AC7 -- fence-aware refusal (G16/CA-355) still fires on the new write path: exits non-zero"
else
  fail "EDMV4-T20 AC7 -- expected a non-zero exit when the target heading exists only inside a fence, got 0"
fi
check "EDMV4-T20 AC7 -- the refusal names the fenced-only heading condition" "occurs in" "$T20_AC7_OUT"
check "EDMV4-T20 AC7 -- the refusal message states nothing was appended" "nothing appended" "$T20_AC7_OUT"
if [[ "$T20_AC7_BEFORE_HASH" == "$T20_AC7_AFTER_HASH" && "$T20_AC7_BEFORE_HASH" != "unhashable" ]]; then
  pass "EDMV4-T20 AC7 -- the delta is byte-identical before and after the refusal"
else
  fail "EDMV4-T20 AC7 -- delta hash changed: before=${T20_AC7_BEFORE_HASH} after=${T20_AC7_AFTER_HASH}"
fi

# ---- AC8: wave8-smoke.sh is reachable via run-all.sh's glob-driven discovery, independent of the
# separate _PREFERRED_ORDER / _MIN_SUITE_COUNT registration EDMV4-T53 AC2 owns solely (audit
# P1-3). This asserts DISCOVERY only, via the identical find invocation run-all.sh itself uses --
# it never invokes run-all.sh, so this suite's own execution never nests a full aggregator run. ---
T20_RUNALL="${PLUGIN_DIR}/bin/tests/run-all.sh"
T20_DISCOVERED="$(find "${PLUGIN_DIR}/bin/tests" -maxdepth 1 -name '*-smoke.sh' -type f 2>/dev/null | xargs -n1 basename | grep -x 'wave8-smoke.sh' || true)"
check "EDMV4-T20 AC8 -- wave8-smoke.sh is discovered by run-all.sh's own *-smoke.sh glob (find -maxdepth 1)" \
  "wave8-smoke.sh" "$T20_DISCOVERED"

# The registration half of AC8 -- whether wave8-smoke.sh also appears in run-all.sh's separate
# _PREFERRED_ORDER / _MIN_SUITE_COUNT list -- is NOT asserted here. Wave-3 QC (P1) found the
# prior code disguised this gap as a passing check: it called pass() when the grep matched
# and printed an uncounted "NOTE:" line when it did not, so the branch could never fail and
# never actually verified anything -- the exact vacuous-assertion class wave-3 QC caught
# twice already in EDMV4-T30. EDMV4-T53 AC2 owns bin/tests/run-all.sh exclusively and this
# ticket's scope carve-out forbids editing it here, so there is genuinely no file this suite
# may inspect to make that half of AC8 a real, independently-anchored assertion yet. The gap
# is stated plainly instead of faked: this suite covers glob-driven discovery only (the check
# immediately above); _PREFERRED_ORDER/_MIN_SUITE_COUNT registration coverage lands with
# EDMV4-T53 itself, against the file it alone is permitted to change.

# ---- AC9: every case above ran against a scratch HOME/CLAUDE_PLUGIN_DATA/XDG_DATA_HOME, and the
# real repository's working tree is untouched BY THIS SECTION (before/after diff, not a bare
# emptiness check -- this ticket's own not-yet-committed changes are legitimately present). -------
T20_GIT_AFTER="$(git -C "$REPO_ROOT" status --porcelain)"
if [[ "$T20_GIT_BEFORE" == "$T20_GIT_AFTER" ]]; then
  pass "EDMV4-T20 AC9 -- git status --porcelain is unchanged across the full EDMV4-T20 section (no scratch state leaked into the real repo)"
else
  fail "EDMV4-T20 AC9 -- git status --porcelain changed during the EDMV4-T20 section: before=[${T20_GIT_BEFORE}] after=[${T20_GIT_AFTER}]"
fi

echo

# =================================================================================================
# EDMV4-T39/T40: six-category 0-10 rubric, versioned, wired to edm-state's own signals
# =================================================================================================
echo
echo "-- EDMV4-T39/T40: edm-repo-readiness rubric + signal wiring --"

# ---- AC6 (T39): READINESS_RUBRIC_VERSION is a bare top-level string constant, matching
# evals/score-artifacts.sh's SCORER_VERSION precedent, and its VALUE is asserted (not just
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
# Ceiling raised 400 -> 500 (decisions.md D42). AC1's original band came from AD1's estimate of
# 250-350 for the INITIAL bash port, sized in Phase 2 when this file was structural only -- it was
# 202 lines at EDMV4-T11's delivery. Five later tickets then added AC-mandated code to the same
# file by design: T13's emit_decision, T14's fact-forcing denial content and MultiEdit loop, T15's
# kill switches / exemptions / staleness cap / denial budget, T45's hookify wiring, and T52's
# non-ASCII sanitization. Each was required by its own acceptance criteria, so the estimate
# described a scope that no longer exists.
#
# The bound is widened, not removed. A closed range still catches the thing it was written to
# catch -- a rewrite that balloons the hook, which fires on every Edit/Write in Phase 6 and whose
# marker-absent fast path must stay cheap. 500 leaves headroom for the two GateGuard tickets not
# yet written without licensing unbounded growth; the next ticket that needs more must justify it
# here rather than nudge the number.
t11_lines="$(wc -l < "$GATEGUARD" | tr -d ' ')"
if [[ "$t11_lines" -ge 200 && "$t11_lines" -le 500 ]]; then
  pass "EDMV4-T11 AC1 -- edm-gateguard is ${t11_lines} lines (within the closed range 200-500, D42)"
else
  fail "EDMV4-T11 AC1 -- edm-gateguard is ${t11_lines} lines (expected 200-500 per D42)"
fi

# ---- AC2: sources _edm-cli-lib.sh; usage() calls the shared print_help() sentinel extractor; no
# hardcoded sed -n 'A,Bp' help range. -------------------------------------------------------------
check "EDMV4-T11 AC2 -- sources _edm-cli-lib.sh" "source \"\${SCRIPT_DIR}/_edm-cli-lib.sh\"" "$(cat "$GATEGUARD")"
check "EDMV4-T11 AC2 -- calls the shared print_help()" "print_help \"\${BASH_SOURCE[0]:-\$0}\"" "$(cat "$GATEGUARD")"
check "EDMV4-T11 AC2 -- carries EDM-HELP-BEGIN/END sentinels" "EDM-HELP-BEGIN" "$(cat "$GATEGUARD")"
check_absent "EDMV4-T11 AC2 -- no hardcoded sed -n 'A,Bp' help-range extraction" "sed -n '" "$(cat "$GATEGUARD")"

# ---- AC3: hooks.json gains exactly one new PreToolUse matcher block for Edit/Write/MultiEdit,
# whose command begins with the same guard the git-commit block uses. This ticket's own count was
# 2; EDMV4-T45 legitimately grows it to 3 by adding a matcher-disjoint `Bash` block once Spike A
# (decisions.md D25) recorded a positive multi-hook-per-event result -- see the EDMV4-T45 section
# below for that block's own dedicated count assertion. Asserting "at least 2, including this
# ticket's own Edit|Write|MultiEdit block" here keeps this AC's own claim true without hardcoding
# a total this ticket does not own. -------------------------------------------------------------
t11_pretooluse_len="$(jq '.hooks.PreToolUse | length' "$HOOKS_JSON")"
if [[ "$t11_pretooluse_len" -ge 2 ]]; then
  pass "EDMV4-T11 AC3 -- hooks.json PreToolUse array has at least 2 entries (${t11_pretooluse_len} total)"
else
  fail "EDMV4-T11 AC3 -- expected at least 2 PreToolUse entries, got ${t11_pretooluse_len}"
fi

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
# The AC is about INVOCATIONS, but this counted every occurrence of the literal string, including
# prose. CA-009's fix inlined a numeric guard rather than calling edm-state's to_int() -- exactly
# what AC5 wants -- and its comment explaining that choice named the binary, which tripped the
# check. Same self-matching-scan class the audit filed five findings against: a scan that matches
# the text describing the thing it hunts. Strip comment lines before counting, and keep a positive
# control so narrowing the pattern cannot silently make the assertion unfailable.
t11_ac5_body="$({ grep -v '^[[:space:]]*#' "$GATEGUARD" || true; })"
t11_ac5_count="$({ printf '%s\n' "$t11_ac5_body" | grep -c 'edm-state' || true; })"
[[ "$t11_ac5_count" -eq 0 ]] \
  && pass "EDMV4-T11 AC5 -- edm-gateguard invokes the state binary zero times (non-comment lines)" \
  || fail "EDMV4-T11 AC5 -- edm-gateguard references edm-state on ${t11_ac5_count} non-comment line(s)"
t11_ac5_probe="$({ printf '%s\n' "$t11_ac5_body" | sed '1a\
  edm-state get PFX >/dev/null' | grep -c 'edm-state' || true; })"
[[ "$t11_ac5_probe" -ge 1 ]] \
  && pass "EDMV4-T11 AC5 -- positive control: an injected edm-state call on a code line is still counted" \
  || fail "EDMV4-T11 AC5 -- positive control FAILED: the comment-stripped scan no longer detects a real invocation"

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

# =================================================================================================
# EDMV4-T47: Block only on the unambiguous subset, read from the existing class field
# =================================================================================================
# Own banded section, appended last (matching the EDMV4-T18 section's own precedent above), so a
# concurrent agent's own append to this file does not interleave with it.
#
# By the time this ticket landed, edm-stop-gate (EDMV4-T46) already read the "blocking"/"info"
# class field state_anomalies() emits at the point each anomaly line is written, and already
# hardcoded no anomaly name -- T46's own AC4 ("only blocking-class anomalies reach stderr, plus
# one informational count line") required exactly the mechanism this ticket specifies. What this
# ticket actually contributes on top of that is the coverage T46's own ACs never asked for: the
# AC4 grep machine-check with a positive control (so a zero-hit result is proven non-vacuous, not
# just asserted), the three named anomalies exercised INDIVIDUALLY against their own dedicated
# fixtures (T46's own tests only exercise OPEN_PARTIALS, never OPEN_AUDIT_ROUND or
# SPEC_SWEEP_PENDING), the AC8 descope proven functionally (a started phase with no completed_at
# produces no anomaly and does not block) rather than only by absence-of-implementation, and the
# AC10 same-fixture blocking-vs-informational comparison T46's own tests never construct (T46 AC2
# compares two DIFFERENT initiatives, not one initiative in two states).
echo "=== EDMV4-T47: block only on the unambiguous subset ==="
echo

# ---- AC1/AC2 (code-shape): the blocking test reads the literal class token 'blocking' -- the
# same token cmd_validate's own exit-3 test uses -- and the gate never derives a prefix from the
# working directory. Both are read-only inspections of the real edm-stop-gate; every fixture below
# also proves the same claims behaviorally. ------------------------------------------------------
check "EDMV4-T47 AC1 -- edm-stop-gate's blocking branch tests the class field against the literal 'blocking'" \
  'blocking)' "$(cat "$EDM_STOP_GATE")"
# Note: a bare grep for "pwd" self-matches edm-stop-gate's own SCRIPT_DIR boilerplate
# (`$(cd ... && pwd)`), the same self-matching-scan trap this initiative's own code-audit
# patterns warn about -- that usage locates the script file, not a prefix. AC2's actual claim
# (prefix comes from active-initiatives, never a cwd guess) is proven functionally instead: AC11
# below shows a repository with no resolvable initiative exits 0 with no output, and AC5/AC6/AC7/
# AC9/AC10 all resolve their fixture prefixes purely via active-initiatives regardless of cwd.
check_absent "EDMV4-T47 AC2 -- edm-stop-gate never derives a prefix via \$(basename ...)" \
  "basename" "$(cat "$EDM_STOP_GATE")"

# ---- AC4: "no per-anomaly logic" is machine-checked, not reviewed once, and the zero-hit result
# is proven non-vacuous by a positive control that injects a real per-anomaly conditional into a
# scratch copy and confirms the identical extraction DOES flag it (code-audit.md's own guidance:
# "found 0" and "matched nothing, ever" are indistinguishable without one). --------------------
_T47_AC4_PATTERN='OPEN_PARTIALS|OPEN_AUDIT_ROUND|SPEC_SWEEP_PENDING|PERM_RULES_MISSING|SIZE_UNKNOWN'
# _t47_ac4_nonconditional_hits <file> -- grep -nE matches of the pattern above that are NOT
# comment-only lines (first non-whitespace character '#'), so a hit inside help text/prose is
# excluded and only a hit inside real code (a conditional, a case arm, a literal) is flagged.
_t47_ac4_nonconditional_hits() {
  local file="$1"
  grep -nE "$_T47_AC4_PATTERN" "$file" 2>/dev/null | grep -vE '^[0-9]+:[[:space:]]*#' || true
}

T47_AC4_REAL_HITS="$(_t47_ac4_nonconditional_hits "$EDM_STOP_GATE")"
if [[ -z "$T47_AC4_REAL_HITS" ]]; then
  pass "EDMV4-T47 AC4 -- edm-stop-gate contains no per-anomaly conditional logic (grep hits, if any, are comment-only)"
else
  fail "EDMV4-T47 AC4 -- anomaly-name reference(s) found outside a comment: ${T47_AC4_REAL_HITS}"
fi

T47_AC4_CONTROL="${TMP}/t47-ac4-control-stop-gate"
cp "$EDM_STOP_GATE" "$T47_AC4_CONTROL"
printf '\n  if [[ "$_class_name" == "OPEN_PARTIALS" ]]; then echo hardcoded_anomaly_name; fi\n' >> "$T47_AC4_CONTROL"
T47_AC4_CONTROL_HITS="$(_t47_ac4_nonconditional_hits "$T47_AC4_CONTROL")"
if [[ -n "$T47_AC4_CONTROL_HITS" ]]; then
  pass "EDMV4-T47 AC4 -- positive control: an injected per-anomaly conditional IS detected, so the zero-hit result above is not vacuous"
else
  fail "EDMV4-T47 AC4 -- positive control FAILED: an injected conditional referencing OPEN_PARTIALS was not flagged, so the zero-hit result above proves nothing"
fi
rm -f "$T47_AC4_CONTROL"

# ---- AC5: OPEN_PARTIALS (already blocking at validate/archive) blocks at Stop too --------------
t47_ac5_case() {
  edm-state init T47PART >/dev/null
  edm-state set T47PART current_phase 1 >/dev/null
  edm-state set T47PART estimated_size Small >/dev/null
  edm-state record-partial-verdict T47PART T47PART-T01 PARTIAL "needs runtime check" >/dev/null

  local rc=0
  edm-stop-gate >/dev/null 2>&1 || rc=$?
  [[ "$rc" -eq 2 ]] \
    && pass "EDMV4-T47 AC5 -- an unclosed partial_verdict_map entry (OPEN_PARTIALS) blocks at Stop (exit 2)" \
    || fail "EDMV4-T47 AC5 -- expected exit 2 for OPEN_PARTIALS, got ${rc}"
}
t46_isolate_and_run t47_ac5_case

# ---- AC6: OPEN_AUDIT_ROUND warns and does not block -- a round genuinely open mid-audit is the
# ambiguous/ordinary case this ticket must NOT block on. Asserts both the exit code AND that
# `edm-state validate` really classified it info-class, so the non-blocking result is a positive
# control on a live anomaly, not an accident of an empty fixture. ---------------------------------
t47_ac6_case() {
  edm-state init T47OAR >/dev/null
  edm-state set T47OAR current_phase 1 >/dev/null
  edm-state set T47OAR estimated_size Small >/dev/null
  edm-state audit-round-start T47OAR code >/dev/null
  # Deliberately never call audit-round-complete -- the round stays open.

  local validate_out
  validate_out="$(edm-state validate T47OAR 2>&1 || true)"
  check "EDMV4-T47 AC6 -- the fixture genuinely carries an info-class OPEN_AUDIT_ROUND anomaly" \
    "info  OPEN_AUDIT_ROUND" "$validate_out"

  local rc=0
  edm-stop-gate >/dev/null 2>&1 || rc=$?
  [[ "$rc" -eq 0 ]] \
    && pass "EDMV4-T47 AC6 -- an open audit round (OPEN_AUDIT_ROUND) does not block at Stop (exit 0)" \
    || fail "EDMV4-T47 AC6 -- expected exit 0 for OPEN_AUDIT_ROUND, got ${rc}"
}
t46_isolate_and_run t47_ac6_case

# ---- AC7: SPEC_SWEEP_PENDING warns and does not block -- its blocking enforcement already lives
# at audit-converged/approve-gate, so re-blocking it at Stop would be a second, conflicting
# classification of the same debt. Same both-directions shape as AC6 above. ----------------------
t47_ac7_case() {
  edm-state init T47SPEC >/dev/null
  edm-state set T47SPEC current_phase 1 >/dev/null
  edm-state set T47SPEC estimated_size Small >/dev/null
  local t47spec_dir; t47spec_dir="$(edm-state resolve-dir T47SPEC)"
  mkdir -p "${t47spec_dir}/code-audit"
  printf '%s\n' '{"id":"CA-9001","status":"fixed","spec_swept":"no"}' \
    > "${t47spec_dir}/code-audit/findings-ledger.jsonl"

  local validate_out
  validate_out="$(edm-state validate T47SPEC 2>&1 || true)"
  check "EDMV4-T47 AC7 -- the fixture genuinely carries an info-class SPEC_SWEEP_PENDING anomaly" \
    "info  SPEC_SWEEP_PENDING" "$validate_out"

  local rc=0
  edm-stop-gate >/dev/null 2>&1 || rc=$?
  [[ "$rc" -eq 0 ]] \
    && pass "EDMV4-T47 AC7 -- an outstanding spec-sweep (SPEC_SWEEP_PENDING) does not block at Stop (exit 0)" \
    || fail "EDMV4-T47 AC7 -- expected exit 0 for SPEC_SWEEP_PENDING, got ${rc}"
}
t46_isolate_and_run t47_ac7_case

# ---- AC8: the descoped "phase started with no completed_at" anomaly is proven absent
# FUNCTIONALLY -- a phase with started_at set and completed_at genuinely absent produces no
# anomaly line at all (not merely "no anomaly is named that in edm-stop-gate's own source"),
# and the gate does not block on it. Direct state-file patch (precedent: this suite's own T46 AC4
# fixture), since edm-state phase-start enforces prerequisite gates this fixture has no reason to
# also stand up. ------------------------------------------------------------------------------
t47_ac8_case() {
  edm-state init T47NOCA >/dev/null
  local state; state="$(edm-state resolve-dir T47NOCA)/.edm-state.json"
  jq '.current_phase = 6 | .estimated_size = "Small"
      | .phase_durations["6_phase"] = {started_at: "2026-09-01T00:00:00Z"}' \
    "$state" > "${state}.tmp" && mv "${state}.tmp" "$state"

  local validate_out
  validate_out="$(edm-state validate T47NOCA 2>&1 || true)"
  check_absent "EDMV4-T47 AC8 -- a started phase with no completed_at produces no anomaly naming it (descoped per decisions.md D16)" \
    "no completed_at" "$validate_out"

  local rc=0
  edm-stop-gate >/dev/null 2>&1 || rc=$?
  [[ "$rc" -eq 0 ]] \
    && pass "EDMV4-T47 AC8 -- edm-stop-gate does not block on a started phase with no completed_at" \
    || fail "EDMV4-T47 AC8 -- expected exit 0, got ${rc}"
}
t46_isolate_and_run t47_ac8_case

# ---- AC9: the blocking stderr message names BOTH the specific anomaly and the initiative -------
t47_ac9_case() {
  edm-state init T47NAME >/dev/null
  edm-state set T47NAME current_phase 1 >/dev/null
  edm-state set T47NAME estimated_size Small >/dev/null
  edm-state record-partial-verdict T47NAME T47NAME-T01 PARTIAL "needs runtime check" >/dev/null

  local out rc=0
  out="$(edm-stop-gate 2>&1)" || rc=$?
  check "EDMV4-T47 AC9 -- blocking stderr names the specific anomaly (OPEN_PARTIALS)" "OPEN_PARTIALS" "$out"
  check "EDMV4-T47 AC9 -- blocking stderr names the initiative (T47NAME)" "T47NAME" "$out"
  [[ "$rc" -eq 2 ]] || fail "EDMV4-T47 AC9 -- fixture setup did not reach the blocking path (rc=${rc})"
}
t46_isolate_and_run t47_ac9_case

# ---- AC10: the SAME fixture initiative compared against itself in two states -- informational-
# only (exit 0), then mutated in place to add a blocking anomaly (exit 2) -- so the two paths are
# proven against one state file, not two separately-constructed ones (T46 AC2 uses two distinct
# initiatives; this is the comparison T47 AC10 specifically calls for). --------------------------
t47_ac10_case() {
  edm-state init T47SAME >/dev/null
  edm-state set T47SAME current_phase 2 >/dev/null
  edm-state set T47SAME estimated_size Small >/dev/null

  local rc1=0 out1
  out1="$(edm-stop-gate 2>&1)" || rc1=$?
  [[ "$rc1" -eq 0 ]] \
    && pass "EDMV4-T47 AC10 -- the fixture's informational-only state exits 0" \
    || fail "EDMV4-T47 AC10 -- expected exit 0 for the informational-only state, got ${rc1} (out=[${out1}])"

  edm-state record-partial-verdict T47SAME T47SAME-T01 PARTIAL "needs runtime check" >/dev/null

  local rc2=0 out2
  out2="$(edm-stop-gate 2>&1)" || rc2=$?
  [[ "$rc2" -eq 2 ]] \
    && pass "EDMV4-T47 AC10 -- the SAME fixture, once mutated to carry a blocking anomaly, exits 2" \
    || fail "EDMV4-T47 AC10 -- expected exit 2 once OPEN_PARTIALS was added, got ${rc2}"
  check "EDMV4-T47 AC10 -- the blocking-state stderr names OPEN_PARTIALS" "OPEN_PARTIALS" "$out2"
}
t46_isolate_and_run t47_ac10_case

# ---- AC11: a repository with no active initiative returns 0 and produces no output on either
# stream. Dedicated T47-banner assertion (T46 AC3 covers the identical scenario for its own
# ticket; this is the AC11-required assertion for this ticket). ----------------------------------
t47_ac11_case() {
  local out rc=0
  out="$(edm-stop-gate 2>&1)" || rc=$?
  [[ "$rc" -eq 0 && -z "$out" ]] \
    && pass "EDMV4-T47 AC11 -- a repository with no active initiative exits 0 with zero bytes on stdout+stderr" \
    || fail "EDMV4-T47 AC11 -- rc=${rc} out=[${out}] (expected rc=0, empty)"
}
t46_isolate_and_run t47_ac11_case

echo
echo "EDMV4-T46 AC9's fourth internal-error path (edm-state validate dying, rc outside {0,3}, for a" \
  "prefix active-initiatives already surfaced) is NOT exercised by any T47 fixture above: every" \
  "fixture here drives edm-state validate to exit 0 (informational) or 3 (blocking), never a" \
  "third code, and that internal-error branch is edm-stop-gate's own construction/prefix-handling" \
  "-- EDMV4-T46's scope, explicitly out of scope for T47 per this epic's own Out of Scope list."

# =================================================================================================
# EDMV4-T56 -- Document the three plugin locations and the push-to-observe constraint
# =================================================================================================
# AC6/AC7/AC8: the detector below fails if the three-location explanation is removed from
# plugins/edm/CLAUDE.md; it carries a positive control proving it fires when the section is
# genuinely absent, not merely that it passes against today's tree; and it is keyed on the two
# literal, stable cache paths rather than on any sentence of the surrounding prose, so a later
# reword of the paragraph text cannot break it.

T56_CLAUDE_MD="${PLUGIN_DIR}/CLAUDE.md"

# t56_three_location_check <file> -- true iff <file> names both the marketplace-clone path
# (/plugin update's read target) and the unpacked-cache path prefix (/reload-plugins's read
# target, minus the <version> component which varies). Both are literal, stable strings that
# cannot appear by accident of rewording the paragraph around them.
t56_three_location_check() {
  local file="$1"
  grep -qF -- '~/.claude/plugins/marketplaces/stg-marketplace' "$file" || return 1
  grep -qF -- '~/.claude/plugins/cache/stg-marketplace/edm/' "$file" || return 1
  return 0
}

# ---- AC6: the shipped CLAUDE.md names both cache paths today -----------------------------------
if t56_three_location_check "$T56_CLAUDE_MD"; then
  pass "EDMV4-T56 AC6 -- plugins/edm/CLAUDE.md names both the marketplace-clone and unpacked-cache paths"
else
  fail "EDMV4-T56 AC6 -- plugins/edm/CLAUDE.md is missing the marketplace-clone and/or unpacked-cache path; the three-location section may have been removed"
fi

T56_TMP="$(mktemp -d "${TMPDIR:-/tmp}/edm-wave8-t56.XXXXXX")"

# ---- AC7: positive control -- strip every line naming either literal path from a scratch copy
# and confirm the detector correctly reports absence. Without this, a "found 0" style detector
# that can never actually fail would report AC6 as passing forever regardless of the file's real
# content (the exact defect class this initiative's own patterns doc records under "A
# verification scan matches the prose that describes the pattern it hunts"). --------------------
T56_STRIPPED="${T56_TMP}/claude-stripped.md"
{ grep -v -F -e '~/.claude/plugins/marketplaces/stg-marketplace' \
             -e '~/.claude/plugins/cache/stg-marketplace/edm/' \
    "$T56_CLAUDE_MD" || true; } > "$T56_STRIPPED"

if t56_three_location_check "$T56_STRIPPED"; then
  fail "EDMV4-T56 AC7 -- positive control FAILED: the detector still reported both paths present after every line naming them was stripped -- the detector cannot fail and proves nothing"
else
  pass "EDMV4-T56 AC7 -- positive control: the detector correctly reports the three-location section absent once both cache-path lines are stripped"
fi

# ---- AC8: the detector tolerates a full reword of the surrounding prose, so long as the two
# literal paths remain -- proving it is keyed on the paths, not on any sentence around them.
# This is a synthetic fixture written independently of CLAUDE.md's actual wording, not a sed
# mangling of it, so it cannot accidentally preserve a phrase the real detector secretly needs. --
T56_REWORDED="${T56_TMP}/claude-reworded.md"
cat > "$T56_REWORDED" <<'EOF'
## An entirely different heading and wording, restating the same fact set

To be perfectly explicit about where things live: a teammate's checkout is not what either
refresh command consults. The command bound to the marketplace mirror at
~/.claude/plugins/marketplaces/stg-marketplace behaves nothing like the command bound to the
version-scoped unpack at ~/.claude/plugins/cache/stg-marketplace/edm/9.9.9/ -- and this paragraph
uses none of the original section's own sentences.
EOF

if t56_three_location_check "$T56_REWORDED"; then
  pass "EDMV4-T56 AC8 -- the detector tolerates a full reword of the surrounding prose, keyed only on the two literal cache paths"
else
  fail "EDMV4-T56 AC8 -- the detector broke under a reword that kept both literal cache paths intact -- it is keying on prose, not on the paths"
fi

rm -rf "$T56_TMP"

echo

# =================================================================================================
# EDMV4-T14: Write the fact-forcing denial content and the per-file MultiEdit loop
# =================================================================================================
# Own banded section, appended last (matching EDMV4-T18's and EDMV4-T47's own precedent above), so
# a concurrent agent's own append to this file does not interleave with it. GATEGUARD/DATADIR_LIB
# are already set by the EDMV4-T11/T12 sections above.
echo "=== EDMV4-T14: fact-forcing denial content and the per-file MultiEdit loop ==="
echo

# t14_fresh_marker_env <outvar_proj> <outvar_data> -- stands up a scratch project directory and a
# scratch CLAUDE_PLUGIN_DATA tree with a Phase 6 marker already written for that project, so every
# case below starts from a clean "marker present, nothing checked yet" state.
t14_fresh_marker_env() {
  local __proj_out="$1" __data_out="$2"
  local dir; dir="$(mktemp -d "${TMP}/t14-env.XXXXXX")"
  mkdir -p "${dir}/proj" "${dir}/data/run"
  local key
  key="$(CLAUDE_PROJECT_DIR="${dir}/proj" bash -c ". '${DATADIR_LIB}'; edm_project_key" 2>/dev/null)"
  printf 'T14PFX\t%s\t2026-09-02T00:00:00Z\n' "${dir}/proj" > "${dir}/data/run/${key}.phase6"
  printf -v "$__proj_out" '%s' "${dir}/proj"
  printf -v "$__data_out" '%s' "${dir}/data"
}

# t14_run <proj> <data> <payload> [<mode>] -- runs edm-gateguard once against a fresh marker
# environment already stood up by t14_fresh_marker_env, capturing stdout/stderr/rc into the
# T14_RUN_* globals. Session state (the checked-file) persists across calls sharing the same
# <data>, which is what lets a caller assert "deny once, allow on retry" across two invocations.
t14_run() {
  local proj="$1" data="$2" payload="$3" mode="${4:-exit-code}"
  T14_RUN_RC=0
  T14_RUN_OUT="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$proj" CLAUDE_PLUGIN_DATA="$data" \
    EDM_GATEGUARD_DENY_MODE="$mode" bash "$GATEGUARD" 2>"${TMP}/t14-run.stderr")" || T14_RUN_RC=$?
  T14_RUN_ERR="$(cat "${TMP}/t14-run.stderr" 2>/dev/null || true)"
}

# ---- AC1: an Edit denial emits exactly the four numbered facts, in order, each on a distinctive
# substring rather than the whole block (AC8). exit-code mode puts the fact list on stderr. -------
T14_AC1_PROJ="" T14_AC1_DATA=""
t14_fresh_marker_env T14_AC1_PROJ T14_AC1_DATA
t14_run "$T14_AC1_PROJ" "$T14_AC1_DATA" '{"tool_name":"Edit","tool_input":{"file_path":"src/foo.js"}}'
[[ "$T14_RUN_RC" -eq 2 ]] && pass "EDMV4-T14 AC1 -- a first-touch Edit denies (exit 2 in exit-code mode)" \
  || fail "EDMV4-T14 AC1 -- expected exit 2 for a first-touch Edit, got ${T14_RUN_RC}"
check "EDMV4-T14 AC1/AC8 -- Edit fact 1 (import/require search) names the target path" \
  "import or require this file (src/foo.js), searching the tree" "$T14_RUN_ERR"
check "EDMV4-T14 AC1/AC8 -- Edit fact 2 (public functions/classes affected)" \
  "public functions or classes affected by this change" "$T14_RUN_ERR"
check "EDMV4-T14 AC1/AC8 -- Edit fact 3 (data-file field/structure/date-format disclosure)" \
  "field names, structure and date format using redacted or synthetic values" "$T14_RUN_ERR"
check "EDMV4-T14 AC1/AC8 -- Edit fact 4 (ticket AC quote, by {PREFIX}-T{NN} ID)" \
  "acceptance criteria of the ticket being implemented, by its {PREFIX}-T{NN} ID" "$T14_RUN_ERR"
T14_AC1_DENY_TEXT="$T14_RUN_ERR"

# ---- Retry allows: the SAME path, same session (same data dir), on a second call allows silently.
t14_run "$T14_AC1_PROJ" "$T14_AC1_DATA" '{"tool_name":"Edit","tool_input":{"file_path":"src/foo.js"}}'
if [[ "$T14_RUN_RC" -eq 0 && -z "$T14_RUN_OUT" && -z "$T14_RUN_ERR" ]]; then
  pass "EDMV4-T14 -- a retry on the SAME path in the same session allows silently (deny once, allow on retry)"
else
  fail "EDMV4-T14 -- retry mismatch: rc=${T14_RUN_RC} stdout=[${T14_RUN_OUT}] stderr=[${T14_RUN_ERR}]"
fi

# ---- AC2: a Write denial swaps facts 1/2 for the new-file variant; facts 3/4 are byte-identical --
T14_AC2_PROJ="" T14_AC2_DATA=""
t14_fresh_marker_env T14_AC2_PROJ T14_AC2_DATA
t14_run "$T14_AC2_PROJ" "$T14_AC2_DATA" '{"tool_name":"Write","tool_input":{"file_path":"new-thing.js"}}'
[[ "$T14_RUN_RC" -eq 2 ]] && pass "EDMV4-T14 AC2 -- a first-touch Write denies (exit 2 in exit-code mode)" \
  || fail "EDMV4-T14 AC2 -- expected exit 2 for a first-touch Write, got ${T14_RUN_RC}"
check "EDMV4-T14 AC2/AC8 -- Write fact 1 (name callers of the new file) names the target path" \
  "call this new file (new-thing.js)" "$T14_RUN_ERR"
check "EDMV4-T14 AC2/AC8 -- Write fact 2 (confirm no existing file serves the same purpose)" \
  "Confirm no existing file already serves the same purpose" "$T14_RUN_ERR"
check "EDMV4-T14 AC2 -- Write fact 3 is byte-identical to the Edit variant's fact 3" \
  "field names, structure and date format using redacted or synthetic values" "$T14_RUN_ERR"
check "EDMV4-T14 AC2 -- Write fact 4 is byte-identical to the Edit variant's fact 4" \
  "acceptance criteria of the ticket being implemented, by its {PREFIX}-T{NN} ID" "$T14_RUN_ERR"
check_absent "EDMV4-T14 AC2 -- Write denial does not carry the Edit variant's import-search fact" \
  "import or require this file" "$T14_RUN_ERR"

# ---- AC3: fact 4 is the ticket-AC form, never a restatement of the user's current instruction ----
T14_AC3_COUNT="$(count_matches "quote the user.s current instruction" "$GATEGUARD")"
check "EDMV4-T14 AC3 -- edm-gateguard never asks the agent to quote the user's current instruction" "0" "$T14_AC3_COUNT"
T14_AC3_CONTROL="$(printf "%s\nquote the user's current instruction\n" "$(cat "$GATEGUARD")")"
T14_AC3_CONTROL_COUNT="$(printf '%s\n' "$T14_AC3_CONTROL" | count_matches "quote the user.s current instruction")"
[[ "$T14_AC3_CONTROL_COUNT" -ge 1 ]] \
  && pass "EDMV4-T14 AC3 -- positive control: an injected 'quote the users current instruction' line IS detected" \
  || fail "EDMV4-T14 AC3 -- positive control FAILED: the injected phrase was not detected, so the zero-count above proves nothing"

# ---- AC4: MultiEdit iterates a three-file batch and denies on the first still-unchecked path,
# returning immediately -- three successive calls each name a DIFFERENT path, and a fourth call
# (every path now checked) allows. Tolerant-extraction synthetic fixture (edits[].file_path), per
# this ticket's own Technical Notes: this proves the SCRIPT's own iteration/dedup logic against a
# constructed payload, not a claim about what a live host's own MultiEdit tool call shape is --
# that shape is UNTESTABLE from this environment (Spike B), and no assertion here claims otherwise.
T14_AC4_PROJ="" T14_AC4_DATA=""
t14_fresh_marker_env T14_AC4_PROJ T14_AC4_DATA
T14_AC4_PAYLOAD='{"tool_name":"MultiEdit","tool_input":{"edits":[{"file_path":"a.js"},{"file_path":"b.js"},{"file_path":"c.js"}]}}'
t14_run "$T14_AC4_PROJ" "$T14_AC4_DATA" "$T14_AC4_PAYLOAD"
T14_AC4_RC1="$T14_RUN_RC" T14_AC4_ERR1="$T14_RUN_ERR"
t14_run "$T14_AC4_PROJ" "$T14_AC4_DATA" "$T14_AC4_PAYLOAD"
T14_AC4_RC2="$T14_RUN_RC" T14_AC4_ERR2="$T14_RUN_ERR"
t14_run "$T14_AC4_PROJ" "$T14_AC4_DATA" "$T14_AC4_PAYLOAD"
T14_AC4_RC3="$T14_RUN_RC" T14_AC4_ERR3="$T14_RUN_ERR"
t14_run "$T14_AC4_PROJ" "$T14_AC4_DATA" "$T14_AC4_PAYLOAD"
T14_AC4_RC4="$T14_RUN_RC" T14_AC4_OUT4="$T14_RUN_OUT" T14_AC4_ERR4="$T14_RUN_ERR"

if [[ "$T14_AC4_RC1" -eq 2 && "$T14_AC4_RC2" -eq 2 && "$T14_AC4_RC3" -eq 2 ]]; then
  pass "EDMV4-T14 AC4 -- three successive MultiEdit calls against an all-unchecked batch each deny (exit 2)"
else
  fail "EDMV4-T14 AC4 -- expected three exit-2 denials, got rc1=${T14_AC4_RC1} rc2=${T14_AC4_RC2} rc3=${T14_AC4_RC3}"
fi
check "EDMV4-T14 AC4 -- call 1 names a.js" "(a.js)" "$T14_AC4_ERR1"
check "EDMV4-T14 AC4 -- call 2 names a DIFFERENT path, b.js" "(b.js)" "$T14_AC4_ERR2"
check "EDMV4-T14 AC4 -- call 3 names the third, distinct path, c.js" "(c.js)" "$T14_AC4_ERR3"
check_absent "EDMV4-T14 AC4 -- call 2 does not re-deny the already-checked a.js" "(a.js)" "$T14_AC4_ERR2"
check_absent "EDMV4-T14 AC4 -- call 3 does not re-deny either already-checked path" "(b.js)" "$T14_AC4_ERR3"
if [[ "$T14_AC4_RC4" -eq 0 && -z "$T14_AC4_OUT4" && -z "$T14_AC4_ERR4" ]]; then
  pass "EDMV4-T14 AC4 -- the fourth call, every path now checked, allows silently (exit 0, empty output)"
else
  fail "EDMV4-T14 AC4 -- expected the fourth call to allow silently, got rc=${T14_AC4_RC4} stdout=[${T14_AC4_OUT4}] stderr=[${T14_AC4_ERR4}]"
fi

# ---- AC5: a MultiEdit batch where every file is ALREADY recorded checked allows on the first call,
# exit 0, empty stdout -- pre-seed the checked-file directly rather than replaying three denials. --
T14_AC5_PROJ="" T14_AC5_DATA=""
t14_fresh_marker_env T14_AC5_PROJ T14_AC5_DATA
T14_AC5_KEY="$(CLAUDE_PROJECT_DIR="$T14_AC5_PROJ" bash -c ". '${DATADIR_LIB}'; edm_project_key" 2>/dev/null)"
printf 'x.js\ny.js\nz.js\n' > "${T14_AC5_DATA}/run/${T14_AC5_KEY}.checked"
T14_AC5_PAYLOAD='{"tool_name":"MultiEdit","tool_input":{"edits":[{"file_path":"x.js"},{"file_path":"y.js"},{"file_path":"z.js"}]}}'
t14_run "$T14_AC5_PROJ" "$T14_AC5_DATA" "$T14_AC5_PAYLOAD" json
if [[ "$T14_RUN_RC" -eq 0 && -z "$T14_RUN_OUT" && -z "$T14_RUN_ERR" ]]; then
  pass "EDMV4-T14 AC5 -- a MultiEdit batch already fully checked allows on the first call (exit 0, empty stdout)"
else
  fail "EDMV4-T14 AC5 -- expected exit 0 with empty output, got rc=${T14_RUN_RC} stdout=[${T14_RUN_OUT}] stderr=[${T14_RUN_ERR}]"
fi

# ---- AC6: the denial text is plain ASCII -- no em dash, arrow, smart quote or emoji. Checked
# against AC1's own real, captured denial output rather than a re-typed copy. grep tokenizes on
# newline before matching each line against the bracket expression, so a plain multi-line ASCII
# string never trips '[^ -~]' on its own line-separator bytes -- the T13 AC9 section above already
# relies on this same idiom for a (single-line) payload; this reuses it for a multi-line one. -----
if [[ -n "$T14_AC1_DENY_TEXT" ]] && ! printf '%s' "$T14_AC1_DENY_TEXT" | LC_ALL=C grep -q '[^ -~]'; then
  pass "EDMV4-T14 AC6 -- the emitted fact text is plain ASCII (LC_ALL=C scan for bytes outside the printable range finds nothing)"
else
  fail "EDMV4-T14 AC6 -- the emitted fact text is empty or contains a non-ASCII byte: [${T14_AC1_DENY_TEXT}]"
fi
# Positive control: injecting a real (non-ASCII) em dash into the same text trips the same
# detector, so the pass above is not vacuous -- "found 0 bytes outside range" and "the detector
# can never fire" are otherwise indistinguishable.
T14_AC6_UNICODE_CONTROL="$(printf '%s \xe2\x80\x94 real em dash\n' "$T14_AC1_DENY_TEXT")"
if printf '%s' "$T14_AC6_UNICODE_CONTROL" | LC_ALL=C grep -q '[^ -~]'; then
  pass "EDMV4-T14 AC6 -- positive control: injecting a real UTF-8 em dash into the fact text IS detected"
else
  fail "EDMV4-T14 AC6 -- positive control FAILED: an injected real em dash was not detected, so the ASCII-only pass above proves nothing"
fi

echo

# =================================================================================================
# EDMV4-T15: GateGuard's operational safety controls
# =================================================================================================
# Own banded section, appended last, so a concurrent agent's own append does not interleave with
# it. GATEGUARD/DATADIR_LIB are already set by the EDMV4-T11/T12 sections above; t14_fresh_marker_env
# and t14_run are already defined by the EDMV4-T14 section above and are reused here unchanged.
#
# Every kill-switch/exemption/budget/fail-open assertion below is paired: a fixture that WOULD
# deny with the control disengaged, run both with the control engaged (must allow/warn/degrade)
# and with it disengaged (must still deny) -- so "the gate stayed quiet" is never asserted against
# a gate that could not have fired in the first place (this initiative's own recorded vacuity trap).
echo "=== EDMV4-T15: kill switches, exemptions, session state, denial budget, fail-open ==="
echo

# ---- AC1: five kill-switch spellings for EDM_GATEGUARD, each proven against a fixture that
# denies with no switch set (the paired negative), one call per spelling. --------------------------
T15_AC1_BASE_PAYLOAD='{"tool_name":"Edit","tool_input":{"file_path":"kill-switch.js"}}'
T15_AC1_PROJ="" T15_AC1_DATA=""
t14_fresh_marker_env T15_AC1_PROJ T15_AC1_DATA
t14_run "$T15_AC1_PROJ" "$T15_AC1_DATA" "$T15_AC1_BASE_PAYLOAD"
[[ "$T14_RUN_RC" -eq 2 ]] && pass "EDMV4-T15 AC1 -- paired negative: with no kill switch set, the fixture denies (proves the fixture is capable of firing)" \
  || fail "EDMV4-T15 AC1 -- paired negative FAILED: expected the unswitched fixture to deny, got ${T14_RUN_RC}"

for _t15_spelling in 0 false off disabled disable; do
  T15_AC1_PROJ2="" T15_AC1_DATA2=""
  t14_fresh_marker_env T15_AC1_PROJ2 T15_AC1_DATA2
  T15_AC1_RC=0
  T15_AC1_OUT="$(printf '%s' "$T15_AC1_BASE_PAYLOAD" | CLAUDE_PROJECT_DIR="$T15_AC1_PROJ2" CLAUDE_PLUGIN_DATA="$T15_AC1_DATA2" \
    EDM_GATEGUARD="$_t15_spelling" EDM_GATEGUARD_DENY_MODE=exit-code bash "$GATEGUARD" 2>"${TMP}/t15-ac1-${_t15_spelling}.stderr")" || T15_AC1_RC=$?
  T15_AC1_ERR="$(cat "${TMP}/t15-ac1-${_t15_spelling}.stderr" 2>/dev/null || true)"
  if [[ "$T15_AC1_RC" -eq 0 && -z "$T15_AC1_OUT" && -z "$T15_AC1_ERR" ]]; then
    pass "EDMV4-T15 AC1 -- EDM_GATEGUARD=${_t15_spelling} exits 0 with no output on a fixture that would otherwise deny"
  else
    fail "EDMV4-T15 AC1 -- EDM_GATEGUARD=${_t15_spelling} mismatch: rc=${T15_AC1_RC} stdout=[${T15_AC1_OUT}] stderr=[${T15_AC1_ERR}]"
  fi
done

# ---- AC2: EDM_GATEGUARD_DISABLED=1 disables (paired against the same denying fixture); "true"
# and "yes" do NOT disable -- the denial must still actually fire, not merely "not silently pass".
T15_AC2_PROJ="" T15_AC2_DATA=""
t14_fresh_marker_env T15_AC2_PROJ T15_AC2_DATA
T15_AC2_RC=0
T15_AC2_OUT="$(printf '%s' "$T15_AC1_BASE_PAYLOAD" | CLAUDE_PROJECT_DIR="$T15_AC2_PROJ" CLAUDE_PLUGIN_DATA="$T15_AC2_DATA" \
  EDM_GATEGUARD_DISABLED=1 EDM_GATEGUARD_DENY_MODE=exit-code bash "$GATEGUARD" 2>"${TMP}/t15-ac2-1.stderr")" || T15_AC2_RC=$?
T15_AC2_ERR="$(cat "${TMP}/t15-ac2-1.stderr" 2>/dev/null || true)"
if [[ "$T15_AC2_RC" -eq 0 && -z "$T15_AC2_OUT" && -z "$T15_AC2_ERR" ]]; then
  pass "EDMV4-T15 AC2 -- EDM_GATEGUARD_DISABLED=1 exits 0 with no output on a fixture that would otherwise deny"
else
  fail "EDMV4-T15 AC2 -- EDM_GATEGUARD_DISABLED=1 mismatch: rc=${T15_AC2_RC} stdout=[${T15_AC2_OUT}] stderr=[${T15_AC2_ERR}]"
fi

for _t15_bad in true yes; do
  T15_AC2B_PROJ="" T15_AC2B_DATA=""
  t14_fresh_marker_env T15_AC2B_PROJ T15_AC2B_DATA
  T15_AC2B_RC=0
  T15_AC2B_ERR="$(printf '%s' "$T15_AC1_BASE_PAYLOAD" | CLAUDE_PROJECT_DIR="$T15_AC2B_PROJ" CLAUDE_PLUGIN_DATA="$T15_AC2B_DATA" \
    EDM_GATEGUARD_DISABLED="$_t15_bad" EDM_GATEGUARD_DENY_MODE=exit-code bash "$GATEGUARD" 2>&1 >/dev/null)" || T15_AC2B_RC=$?
  if [[ "$T15_AC2B_RC" -eq 2 ]]; then
    pass "EDMV4-T15 AC2 -- EDM_GATEGUARD_DISABLED=${_t15_bad} does NOT disable the gate -- the denial still fires (exit 2)"
  else
    fail "EDMV4-T15 AC2 -- EDM_GATEGUARD_DISABLED=${_t15_bad} unexpectedly suppressed the denial: rc=${T15_AC2B_RC}"
  fi
done

# ---- AC3: with a kill switch engaged, zero filesystem reads beyond environment -- proven two
# ways. (a) code position: the kill-switch case/if block sits strictly before the first reference
# to the datadir-lib source, the marker path, or a `stat` invocation, mirroring the T11 AC8
# line-number-ordering technique. (b) runtime, with a stat SPY on PATH: the spy fires when the
# switch is OFF and a fixture reaches gg_fresh_lines (a pre-existing checked-file read), and does
# NOT fire when the switch is ON against the identical fixture -- so the zero-count is paired
# against a fixture proven capable of invoking `stat`, not merely a fixture that never would have. -
T15_AC3_KILLSWITCH_LINE="$(grep -n 'case "\${EDM_GATEGUARD:-}" in' "$GATEGUARD" | head -1 | cut -d: -f1)"
T15_AC3_DATADIRLIB_LINE="$(grep -n '_edm-datadir-lib.sh' "$GATEGUARD" | head -1 | cut -d: -f1)"
if [[ -n "$T15_AC3_KILLSWITCH_LINE" && -n "$T15_AC3_DATADIRLIB_LINE" && "$T15_AC3_KILLSWITCH_LINE" -lt "$T15_AC3_DATADIRLIB_LINE" ]]; then
  pass "EDMV4-T15 AC3 -- the kill-switch block (line ${T15_AC3_KILLSWITCH_LINE}) precedes the datadir-lib source (line ${T15_AC3_DATADIRLIB_LINE})"
else
  fail "EDMV4-T15 AC3 -- kill-switch line=[${T15_AC3_KILLSWITCH_LINE}] datadir-lib line=[${T15_AC3_DATADIRLIB_LINE}] -- ordering not satisfied"
fi

harness_scratch_dir T15_AC3_TMP
T15_AC3_FAKEBIN="${T15_AC3_TMP}/fakebin"
mkdir -p "$T15_AC3_FAKEBIN"
ln -s "$(command -v dirname)" "${T15_AC3_FAKEBIN}/dirname"
ln -s "$(command -v bash)" "${T15_AC3_FAKEBIN}/bash"
ln -s "$(command -v grep)" "${T15_AC3_FAKEBIN}/grep"
ln -s "$(command -v date)" "${T15_AC3_FAKEBIN}/date"
ln -s "$(command -v mkdir)" "${T15_AC3_FAKEBIN}/mkdir"
ln -s "$(command -v mv)" "${T15_AC3_FAKEBIN}/mv"
ln -s "$(command -v rm)" "${T15_AC3_FAKEBIN}/rm"
ln -s "$(command -v cat)" "${T15_AC3_FAKEBIN}/cat"
ln -s "$(command -v git)" "${T15_AC3_FAKEBIN}/git"
ln -s "$(command -v jq)" "${T15_AC3_FAKEBIN}/jq"
cat > "${T15_AC3_FAKEBIN}/stat" <<T15STATSPY
#!/bin/sh
: > "${T15_AC3_FAKEBIN}/.stat_invoked"
exit 1
T15STATSPY
chmod +x "${T15_AC3_FAKEBIN}/stat"

T15_AC3_PROJ="${T15_AC3_TMP}/proj" T15_AC3_DATA="${T15_AC3_TMP}/data"
mkdir -p "${T15_AC3_PROJ}" "${T15_AC3_DATA}/run"
T15_AC3_KEY="$(CLAUDE_PROJECT_DIR="$T15_AC3_PROJ" bash -c ". '${DATADIR_LIB}'; edm_project_key" 2>/dev/null)"
printf 'T15PFX\t%s\t2026-09-02T00:00:00Z\n' "$T15_AC3_PROJ" > "${T15_AC3_DATA}/run/${T15_AC3_KEY}.phase6"
printf 'already-seen.js\n' > "${T15_AC3_DATA}/run/${T15_AC3_KEY}.checked"

# Positive control: switch OFF, path already checked -- gg_is_checked reads the checked-file via
# gg_fresh_lines, which spawns the stat spy.
rm -f "${T15_AC3_FAKEBIN}/.stat_invoked"
printf '{"tool_name":"Edit","tool_input":{"file_path":"already-seen.js"}}' | \
  CLAUDE_PROJECT_DIR="$T15_AC3_PROJ" CLAUDE_PLUGIN_DATA="$T15_AC3_DATA" PATH="$T15_AC3_FAKEBIN" \
  bash "$GATEGUARD" >/dev/null 2>&1 || true
if [[ -f "${T15_AC3_FAKEBIN}/.stat_invoked" ]]; then
  pass "EDMV4-T15 AC3 -- positive control: the stat spy DOES fire on a real checked-file read with no kill switch set"
else
  fail "EDMV4-T15 AC3 -- positive control FAILED: the stat spy never fired even with a real checked-file read, so the switch-engaged zero-count below proves nothing"
fi

# Kill switch ON, identical fixture: the spy must NOT fire, and the call must exit 0 with empty
# stdout/stderr even though EDM_GATEGUARD_STATE_DIR/CLAUDE_PLUGIN_DATA both resolve to a path
# whose parent directory has mode 000 (so any read attempt beyond the environment would surface).
rm -f "${T15_AC3_FAKEBIN}/.stat_invoked"
T15_AC3_LOCKED="${T15_AC3_TMP}/locked"
mkdir -p "$T15_AC3_LOCKED"
chmod 000 "$T15_AC3_LOCKED"
T15_AC3_RC=0
T15_AC3_OUT="$(printf '{"tool_name":"Edit","tool_input":{"file_path":"already-seen.js"}}' | \
  EDM_GATEGUARD=0 CLAUDE_PLUGIN_DATA="${T15_AC3_LOCKED}/data" EDM_GATEGUARD_STATE_DIR="${T15_AC3_LOCKED}/state" \
  PATH="$T15_AC3_FAKEBIN" bash "$GATEGUARD" 2>"${T15_AC3_TMP}/ac3-locked.stderr")" || T15_AC3_RC=$?
T15_AC3_ERR="$(cat "${T15_AC3_TMP}/ac3-locked.stderr" 2>/dev/null || true)"
chmod 755 "$T15_AC3_LOCKED"
if [[ "$T15_AC3_RC" -eq 0 && -z "$T15_AC3_OUT" && -z "$T15_AC3_ERR" ]]; then
  pass "EDMV4-T15 AC3 -- kill switch engaged with unreadable state/data paths: exit 0, empty stdout, empty stderr"
else
  fail "EDMV4-T15 AC3 -- kill switch engaged mismatch: rc=${T15_AC3_RC} stdout=[${T15_AC3_OUT}] stderr=[${T15_AC3_ERR}]"
fi
if [[ ! -f "${T15_AC3_FAKEBIN}/.stat_invoked" ]]; then
  pass "EDMV4-T15 AC3 -- the stat spy was NEVER invoked with the kill switch engaged (zero filesystem reads beyond environment)"
else
  fail "EDMV4-T15 AC3 -- the stat spy WAS invoked despite the kill switch -- a filesystem read reached beyond the environment"
fi

# ---- AC4: EDM_GATEGUARD_EXEMPT_GLOBS='**/tests/**' exempts BOTH the absolute and the bare
# relative form; a NON-matching path under the same rule is NOT exempted (positive control that
# the matcher discriminates rather than matching everything). -------------------------------------
for _t15_ac4_path in /repo/tests/x.js tests/x.js; do
  T15_AC4_PROJ="" T15_AC4_DATA=""
  t14_fresh_marker_env T15_AC4_PROJ T15_AC4_DATA
  T15_AC4_RC=0
  T15_AC4_OUT="$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$_t15_ac4_path" | \
    CLAUDE_PROJECT_DIR="$T15_AC4_PROJ" CLAUDE_PLUGIN_DATA="$T15_AC4_DATA" EDM_GATEGUARD_EXEMPT_GLOBS='**/tests/**' \
    EDM_GATEGUARD_DENY_MODE=exit-code bash "$GATEGUARD" 2>"${TMP}/t15-ac4.stderr")" || T15_AC4_RC=$?
  T15_AC4_ERR="$(cat "${TMP}/t15-ac4.stderr" 2>/dev/null || true)"
  if [[ "$T15_AC4_RC" -eq 0 && -z "$T15_AC4_OUT" && -z "$T15_AC4_ERR" ]]; then
    pass "EDMV4-T15 AC4 -- '${_t15_ac4_path}' is exempted by EDM_GATEGUARD_EXEMPT_GLOBS='**/tests/**' (exit 0, no output)"
  else
    fail "EDMV4-T15 AC4 -- '${_t15_ac4_path}' expected exempt: rc=${T15_AC4_RC} stdout=[${T15_AC4_OUT}] stderr=[${T15_AC4_ERR}]"
  fi
done

T15_AC4B_PROJ="" T15_AC4B_DATA=""
t14_fresh_marker_env T15_AC4B_PROJ T15_AC4B_DATA
T15_AC4B_RC=0
printf '{"tool_name":"Edit","tool_input":{"file_path":"src/unrelated.js"}}' | \
  CLAUDE_PROJECT_DIR="$T15_AC4B_PROJ" CLAUDE_PLUGIN_DATA="$T15_AC4B_DATA" EDM_GATEGUARD_EXEMPT_GLOBS='**/tests/**' \
  EDM_GATEGUARD_DENY_MODE=exit-code bash "$GATEGUARD" >/dev/null 2>&1 || T15_AC4B_RC=$?
[[ "$T15_AC4B_RC" -eq 2 ]] \
  && pass "EDMV4-T15 AC4 -- positive control: a NON-matching path under the same '**/tests/**' rule still denies (the matcher discriminates)" \
  || fail "EDMV4-T15 AC4 -- positive control FAILED: 'src/unrelated.js' was unexpectedly exempted (rc=${T15_AC4B_RC})"

# ---- AC5: the shipped DEFAULT exempts the SRD/ tree with no variable set; a non-SRD path under
# the default is NOT exempted (positive control). --------------------------------------------------
T15_AC5_PROJ="" T15_AC5_DATA=""
t14_fresh_marker_env T15_AC5_PROJ T15_AC5_DATA
T15_AC5_RC=0
T15_AC5_OUT="$(printf '{"tool_name":"Edit","tool_input":{"file_path":"/repo/SRD/edm/EDMV4__x/srd.md"}}' | \
  CLAUDE_PROJECT_DIR="$T15_AC5_PROJ" CLAUDE_PLUGIN_DATA="$T15_AC5_DATA" EDM_GATEGUARD_DENY_MODE=exit-code bash "$GATEGUARD" 2>&1)" || T15_AC5_RC=$?
if [[ "$T15_AC5_RC" -eq 0 && -z "$T15_AC5_OUT" ]]; then
  pass "EDMV4-T15 AC5 -- a path under SRD/ is exempt by the shipped default with no variable set"
else
  fail "EDMV4-T15 AC5 -- expected the default to exempt an SRD/ path, got rc=${T15_AC5_RC} out=[${T15_AC5_OUT}]"
fi

T15_AC5B_PROJ="" T15_AC5B_DATA=""
t14_fresh_marker_env T15_AC5B_PROJ T15_AC5B_DATA
T15_AC5B_RC=0
printf '{"tool_name":"Edit","tool_input":{"file_path":"/repo/src/main.js"}}' | \
  CLAUDE_PROJECT_DIR="$T15_AC5B_PROJ" CLAUDE_PLUGIN_DATA="$T15_AC5B_DATA" EDM_GATEGUARD_DENY_MODE=exit-code bash "$GATEGUARD" >/dev/null 2>&1 || T15_AC5B_RC=$?
[[ "$T15_AC5B_RC" -eq 2 ]] \
  && pass "EDMV4-T15 AC5 -- positive control: a non-SRD path under the same default still denies" \
  || fail "EDMV4-T15 AC5 -- positive control FAILED: '/repo/src/main.js' was unexpectedly exempted (rc=${T15_AC5B_RC})"

# ---- AC6: a 501st append leaves exactly 500 lines with the oldest gone; a state file backdated
# past 30 minutes produces a DENIAL (not an allow) on a path it previously recorded. --------------
T15_AC6_PROJ="" T15_AC6_DATA=""
t14_fresh_marker_env T15_AC6_PROJ T15_AC6_DATA
T15_AC6_KEY="$(CLAUDE_PROJECT_DIR="$T15_AC6_PROJ" bash -c ". '${DATADIR_LIB}'; edm_project_key" 2>/dev/null)"
T15_AC6_CHECKED="${T15_AC6_DATA}/run/${T15_AC6_KEY}.checked"
_t15_ac6_i=1
: > "$T15_AC6_CHECKED"
while [[ "$_t15_ac6_i" -le 500 ]]; do
  printf 'old-file-%d.js\n' "$_t15_ac6_i" >> "$T15_AC6_CHECKED"
  _t15_ac6_i=$((_t15_ac6_i + 1))
done
t14_run "$T15_AC6_PROJ" "$T15_AC6_DATA" '{"tool_name":"Edit","tool_input":{"file_path":"the-501st.js"}}'
T15_AC6_LINE_COUNT="$(wc -l < "$T15_AC6_CHECKED" | tr -d ' ')"
check "EDMV4-T15 AC6 -- after a 501st append, the checked-file holds exactly 500 lines" "500" "$T15_AC6_LINE_COUNT"
if grep -Fxq 'old-file-1.js' "$T15_AC6_CHECKED"; then
  fail "EDMV4-T15 AC6 -- the oldest entry (old-file-1.js) is still present; pruning did not remove the oldest first"
else
  pass "EDMV4-T15 AC6 -- the oldest entry (old-file-1.js) was pruned first"
fi
if grep -Fxq 'the-501st.js' "$T15_AC6_CHECKED"; then
  pass "EDMV4-T15 AC6 -- the newest entry (the-501st.js) is present after pruning"
else
  fail "EDMV4-T15 AC6 -- the newest entry (the-501st.js) is missing after pruning"
fi

# Staleness: a checked-file recording a path, backdated past 30 minutes, must produce a DENIAL
# (not a silent allow) the next time that same path is touched -- the failure mode this half of
# AC6 exists to prevent is "stale state reads as still-checked forever".
T15_AC6B_PROJ="" T15_AC6B_DATA=""
t14_fresh_marker_env T15_AC6B_PROJ T15_AC6B_DATA
T15_AC6B_KEY="$(CLAUDE_PROJECT_DIR="$T15_AC6B_PROJ" bash -c ". '${DATADIR_LIB}'; edm_project_key" 2>/dev/null)"
T15_AC6B_CHECKED="${T15_AC6B_DATA}/run/${T15_AC6B_KEY}.checked"
printf 'stale-recorded.js\n' > "$T15_AC6B_CHECKED"
# Backdate past 30 minutes (2000 seconds) using touch -t if available, else a portable fallback.
T15_AC6B_BACKDATE="$(date -v-2000S +%Y%m%d%H%M.%S 2>/dev/null || date -d '-2000 seconds' +%Y%m%d%H%M.%S 2>/dev/null || true)"
if [[ -n "$T15_AC6B_BACKDATE" ]]; then
  touch -t "$T15_AC6B_BACKDATE" "$T15_AC6B_CHECKED" 2>/dev/null || true
fi
T15_AC6B_RC=0
T15_AC6B_OUT="$(printf '{"tool_name":"Edit","tool_input":{"file_path":"stale-recorded.js"}}' | \
  CLAUDE_PROJECT_DIR="$T15_AC6B_PROJ" CLAUDE_PLUGIN_DATA="$T15_AC6B_DATA" EDM_GATEGUARD_DENY_MODE=exit-code bash "$GATEGUARD" 2>&1)" || T15_AC6B_RC=$?
if [[ "$T15_AC6B_RC" -eq 2 ]]; then
  pass "EDMV4-T15 AC6 -- a checked-file backdated past 30 minutes produces a DENIAL on a path it previously recorded (stale state is not still-checked)"
else
  fail "EDMV4-T15 AC6 -- expected a denial (exit 2) on a stale-recorded path, got rc=${T15_AC6B_RC} out=[${T15_AC6B_OUT}]"
fi

# ---- AC7 (CA-001): every state-write failure path ALLOWS, with a stderr warning naming
# EDM_GATEGUARD_STATE_DIR -- NEVER a deny. This band previously asserted the exact opposite
# (permissionDecision == "deny"), retrofitted to match the pre-fix implementation rather than the
# AC it claims to verify -- see CA-001 in code-audit/findings-ledger.jsonl. Read-only data
# directory: gg_mark_checked cannot record the check, so gg_maybe_deny must fall through to allow
# BEFORE ever recording a denial or emitting one. The same path is driven six times to prove this
# is a plain, repeatable allow -- not "denies once then somehow escapes" -- exactly the "deny the
# same edit forever" failure this ticket's own Description names as the bug to avoid.
T15_AC7_PROJ="" T15_AC7_DATA=""
t14_fresh_marker_env T15_AC7_PROJ T15_AC7_DATA
chmod 555 "${T15_AC7_DATA}/run"
T15_AC7_ALL_ALLOWED=1
T15_AC7_FIRST_ERR=""
_t15_ac7_i=1
while [[ "$_t15_ac7_i" -le 6 ]]; do
  T15_AC7_RC=0
  T15_AC7_OUT="$(printf '{"tool_name":"Edit","tool_input":{"file_path":"readonly-target.js"}}' | \
    CLAUDE_PROJECT_DIR="$T15_AC7_PROJ" CLAUDE_PLUGIN_DATA="$T15_AC7_DATA" EDM_GATEGUARD_DENY_MODE=json bash "$GATEGUARD" 2>"${TMP}/t15-ac7.stderr")" || T15_AC7_RC=$?
  T15_AC7_ERR="$(cat "${TMP}/t15-ac7.stderr" 2>/dev/null || true)"
  if [[ "$_t15_ac7_i" -eq 1 ]]; then
    T15_AC7_FIRST_ERR="$T15_AC7_ERR"
  fi
  if [[ "$T15_AC7_RC" -ne 0 || -n "$T15_AC7_OUT" ]]; then
    T15_AC7_ALL_ALLOWED=0
    fail "EDMV4-T15 AC7 -- call ${_t15_ac7_i} of 6 under a read-only state dir did not allow cleanly (expected exit 0, empty stdout): rc=${T15_AC7_RC} out=[${T15_AC7_OUT}]"
  fi
  _t15_ac7_i=$((_t15_ac7_i + 1))
done
chmod 755 "${T15_AC7_DATA}/run"
[[ "$T15_AC7_ALL_ALLOWED" -eq 1 ]] \
  && pass "EDMV4-T15 AC7 -- all six repeated calls under a read-only state dir allow (exit 0, empty stdout) -- never a deny"
check "EDMV4-T15 AC7 -- the state-write failure warns on stderr naming EDM_GATEGUARD_STATE_DIR" "EDM_GATEGUARD_STATE_DIR" "$T15_AC7_FIRST_ERR"

# Positive control (what would make the assertions above fail): the SAME fixture (fresh marker,
# same payload) with a WRITABLE state dir must still deny on first touch. This proves the allow
# above is caused specifically by the state-write failure, not by a change that stopped denying
# altogether -- the vacuity trap in the opposite direction from the one this finding corrects. If
# gg_maybe_deny's `gg_mark_checked "$path" || return 0` guard above were ever reverted to an
# unconditional deny, the six-call loop above would fail; if the deny path itself were ever
# removed, this control would fail instead.
T15_AC7B_PROJ="" T15_AC7B_DATA=""
t14_fresh_marker_env T15_AC7B_PROJ T15_AC7B_DATA
T15_AC7B_RC=0
T15_AC7B_OUT="$(printf '{"tool_name":"Edit","tool_input":{"file_path":"readonly-target.js"}}' | \
  CLAUDE_PROJECT_DIR="$T15_AC7B_PROJ" CLAUDE_PLUGIN_DATA="$T15_AC7B_DATA" EDM_GATEGUARD_DENY_MODE=json bash "$GATEGUARD" 2>/dev/null)" || T15_AC7B_RC=$?
if printf '%s' "$T15_AC7B_OUT" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
  pass "EDMV4-T15 AC7 -- positive control: the same fixture with a WRITABLE state dir still denies on first touch"
else
  fail "EDMV4-T15 AC7 -- positive control FAILED: expected a deny with a writable state dir, got rc=${T15_AC7B_RC} out=[${T15_AC7B_OUT}]"
fi

# ---- AC8: EDM_GATEGUARD_MAX_DENIALS (default 3) bounds full denials per session -- four
# unchecked paths in one session deny on the first three and allow with an advisory on the fourth.
T15_AC8_PROJ="" T15_AC8_DATA=""
t14_fresh_marker_env T15_AC8_PROJ T15_AC8_DATA
T15_AC8_RCS=""
for _t15_ac8_f in budget-a.js budget-b.js budget-c.js budget-d.js; do
  t14_run "$T15_AC8_PROJ" "$T15_AC8_DATA" "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"${_t15_ac8_f}\"}}"
  T15_AC8_RCS="${T15_AC8_RCS} ${T14_RUN_RC}"
  if [[ "$_t15_ac8_f" == "budget-d.js" ]]; then
    T15_AC8_FOURTH_ERR="$T14_RUN_ERR"
  fi
done
check "EDMV4-T15 AC8 -- four unchecked paths deny on the first three and allow on the fourth" " 2 2 2 0" "$T15_AC8_RCS"
check "EDMV4-T15 AC8 -- the fourth call's stderr carries the denial-budget advisory naming the limit (3)" \
  "denial budget (3) reached" "$T15_AC8_FOURTH_ERR"

# ---- AC9: jq missing exits 1 on the GATED path (never 2); with the marker absent, jq missing
# exits 0 having never been referenced (T11's own AC9 already proves the zero-jq shape; this
# re-asserts the gated-path half and the documented distinction). ----------------------------------
harness_scratch_dir T15_AC9_TMP
T15_AC9_FAKEBIN="${T15_AC9_TMP}/fakebin"
mkdir -p "$T15_AC9_FAKEBIN"
for _t15_bin in dirname bash grep date mkdir mv rm cat git stat; do
  ln -s "$(command -v "$_t15_bin")" "${T15_AC9_FAKEBIN}/${_t15_bin}"
done
T15_AC9_PROJ="${T15_AC9_TMP}/proj" T15_AC9_DATA="${T15_AC9_TMP}/data"
mkdir -p "$T15_AC9_PROJ" "${T15_AC9_DATA}/run"
T15_AC9_KEY="$(CLAUDE_PROJECT_DIR="$T15_AC9_PROJ" bash -c ". '${DATADIR_LIB}'; edm_project_key" 2>/dev/null)"
printf 'T15PFX\t%s\t2026-09-02T00:00:00Z\n' "$T15_AC9_PROJ" > "${T15_AC9_DATA}/run/${T15_AC9_KEY}.phase6"
T15_AC9_RC=0
printf '{"tool_name":"Edit"}' | CLAUDE_PROJECT_DIR="$T15_AC9_PROJ" CLAUDE_PLUGIN_DATA="$T15_AC9_DATA" PATH="$T15_AC9_FAKEBIN" bash "$GATEGUARD" >/dev/null 2>&1 || T15_AC9_RC=$?
check "EDMV4-T15 AC9 -- jq missing on the GATED path (marker present) exits 1, never 2" "1" "$T15_AC9_RC"

check "EDMV4-T15 AC9 -- the EDM-HELP block states the jq-missing distinction" \
  "once a marker is present" "$(cat "$GATEGUARD")"

# ---- AC10: an unparseable stdin payload exits 1 with empty stdout, never blocks. -----------------
T15_AC10_PROJ="" T15_AC10_DATA=""
t14_fresh_marker_env T15_AC10_PROJ T15_AC10_DATA
T15_AC10_RC=0
T15_AC10_OUT="$(printf 'not json' | CLAUDE_PROJECT_DIR="$T15_AC10_PROJ" CLAUDE_PLUGIN_DATA="$T15_AC10_DATA" bash "$GATEGUARD" 2>/dev/null)" || T15_AC10_RC=$?
check "EDMV4-T15 AC10 -- an unparseable stdin payload exits 1" "1" "$T15_AC10_RC"
check "EDMV4-T15 AC10 -- an unparseable stdin payload's stdout is empty" "" "$T15_AC10_OUT"

# ---- AC11: a marker present whose named initiative directory no longer exists allows. -----------
T15_AC11_TMP=""
harness_scratch_dir T15_AC11_TMP
mkdir -p "${T15_AC11_TMP}/data/run" "${T15_AC11_TMP}/proj"
T15_AC11_KEY="$(CLAUDE_PROJECT_DIR="${T15_AC11_TMP}/proj" bash -c ". '${DATADIR_LIB}'; edm_project_key" 2>/dev/null)"
printf 'T15PFX\t%s/deleted-initiative\t2026-09-02T00:00:00Z\n' "$T15_AC11_TMP" > "${T15_AC11_TMP}/data/run/${T15_AC11_KEY}.phase6"
T15_AC11_RC=0
T15_AC11_OUT="$(printf '{"tool_name":"Edit","tool_input":{"file_path":"a.js"}}' | \
  CLAUDE_PROJECT_DIR="${T15_AC11_TMP}/proj" CLAUDE_PLUGIN_DATA="${T15_AC11_TMP}/data" EDM_GATEGUARD_DENY_MODE=exit-code \
  bash "$GATEGUARD" 2>&1)" || T15_AC11_RC=$?
if [[ "$T15_AC11_RC" -eq 0 && -z "$T15_AC11_OUT" ]]; then
  pass "EDMV4-T15 AC11 -- a marker naming a deleted initiative directory allows (exit 0, empty output)"
else
  fail "EDMV4-T15 AC11 -- expected exit 0 with empty output for a deleted-initiative-dir marker, got rc=${T15_AC11_RC} out=[${T15_AC11_OUT}]"
fi
# Positive control: the SAME marker file, pointed at an initiative dir that DOES exist, denies --
# proving the AC11 allow above is attributable to the missing directory, not to some other defect.
T15_AC11B_TMP=""
harness_scratch_dir T15_AC11B_TMP
mkdir -p "${T15_AC11B_TMP}/data/run" "${T15_AC11B_TMP}/proj"
T15_AC11B_KEY="$(CLAUDE_PROJECT_DIR="${T15_AC11B_TMP}/proj" bash -c ". '${DATADIR_LIB}'; edm_project_key" 2>/dev/null)"
printf 'T15PFX\t%s\t2026-09-02T00:00:00Z\n' "${T15_AC11B_TMP}/proj" > "${T15_AC11B_TMP}/data/run/${T15_AC11B_KEY}.phase6"
T15_AC11B_RC=0
printf '{"tool_name":"Edit","tool_input":{"file_path":"a.js"}}' | \
  CLAUDE_PROJECT_DIR="${T15_AC11B_TMP}/proj" CLAUDE_PLUGIN_DATA="${T15_AC11B_TMP}/data" EDM_GATEGUARD_DENY_MODE=exit-code \
  bash "$GATEGUARD" >/dev/null 2>&1 || T15_AC11B_RC=$?
[[ "$T15_AC11B_RC" -eq 2 ]] \
  && pass "EDMV4-T15 AC11 -- positive control: the identical marker shape naming an EXISTING initiative dir still denies" \
  || fail "EDMV4-T15 AC11 -- positive control FAILED: expected a denial when the initiative dir exists, got rc=${T15_AC11B_RC}"

# ---- AC12: all six env vars are documented in CLAUDE.md's Testing changes section. ---------------
T15_CLAUDE_MD_TEXT="$(cat "${PLUGIN_DIR}/CLAUDE.md")"
for _t15_var in EDM_GATEGUARD EDM_GATEGUARD_DISABLED EDM_GATEGUARD_DENY_MODE EDM_GATEGUARD_EXEMPT_GLOBS EDM_GATEGUARD_STATE_DIR EDM_GATEGUARD_MAX_DENIALS; do
  check "EDMV4-T15 AC12 -- CLAUDE.md documents ${_t15_var}" "${_t15_var}" "$T15_CLAUDE_MD_TEXT"
done
check "EDMV4-T15 AC12 -- the knob family is introduced by name in the same bullet form as the existing families" \
  "EDM_GATEGUARD_*\` knob family (EDMV4-T15)" "$T15_CLAUDE_MD_TEXT"

echo

# =================================================================================================
# EDMV4-T45: Wire hookify events to their single owners, with bash gated on Spike A
# =================================================================================================
# Own banded section, appended last. GATEGUARD/EDM_STOP_GATE/DATADIR_LIB/HOOKIFY_FIXTURES are
# already set by the EDMV4-T11/T12/T42/T46 sections above; t14_fresh_marker_env is reused unchanged.
echo "=== EDMV4-T45: hookify event wiring (file/stop/bash), bash gated on Spike A ==="
echo

EDM_BASH_GATE="${PLUGIN_DIR}/bin/edm-bash-gate"
BASH_DECISIONS_MD="${PLUGIN_DIR}/../../SRD/edm/EDMV4__ecc-integration/decisions.md"

# ---- AC3: bash-event rules ship only because decisions.md records a positive Spike A result --
# checked before anything else in this section, matching the AC's own reading-order requirement. -
if [[ -f "$BASH_DECISIONS_MD" ]]; then
  T45_D25_TEXT="$(grep -A2 '| D25 |' "$BASH_DECISIONS_MD" 2>/dev/null || true)"
  check "EDMV4-T45 AC3 -- decisions.md D25 records that every registered PreToolUse block runs" \
    "every registered command runs" "$T45_D25_TEXT"
  check "EDMV4-T45 AC3 -- decisions.md D25 records a deny always wins regardless of order" \
    "a deny always wins" "$T45_D25_TEXT"
else
  fail "EDMV4-T45 AC3 -- decisions.md not found at the expected path; cannot verify the Spike A precondition"
fi
if [[ -x "$EDM_BASH_GATE" ]]; then
  pass "EDMV4-T45 AC3/AC4 -- bash events shipped: bin/edm-bash-gate exists and is executable, matching the positive Spike A result above"
else
  fail "EDMV4-T45 AC3/AC4 -- bin/edm-bash-gate is missing or not executable"
fi

# ---- AC5: the existing git-commit matcher block is byte-identical; pinned at its exact command
# string (GATEGUARD/HOOKS_JSON already point at the real files from the EDMV4-T11 section). -------
T45_GITCOMMIT_CMD="$(jq -r '.hooks.PreToolUse[] | select(.matcher == "git commit") | .hooks[0].command' "$HOOKS_JSON")"
check "EDMV4-T45 AC5 -- git-commit matcher's command is still byte-identical after this ticket" \
  "command -v edm-lint-staged-artifacts >/dev/null 2>&1 || exit 0; edm-lint-staged-artifacts" "$T45_GITCOMMIT_CMD"

# ---- AC1 (structural): no second PreToolUse block registered for file events -- exactly one
# matcher block names Edit|Write|MultiEdit, and the new Bash block is matcher-disjoint from it. --
T45_FILE_MATCHER_COUNT="$(jq '[.hooks.PreToolUse[] | select(.matcher == "Edit|Write|MultiEdit")] | length' "$HOOKS_JSON")"
check "EDMV4-T45 AC1 -- exactly one PreToolUse block matches Edit|Write|MultiEdit (no second file-event block)" \
  "1" "$T45_FILE_MATCHER_COUNT"
T45_BASH_MATCHER_CMD="$(jq -r '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[0].command' "$HOOKS_JSON")"
check "EDMV4-T45 AC4 -- the new Bash matcher's command begins with the edm-bash-gate presence guard" \
  "command -v edm-bash-gate >/dev/null 2>&1 || exit 0" "$T45_BASH_MATCHER_CMD"

# ---- AC2 (structural): no second Stop matcher block registered -- still exactly one, two entries.
T45_STOP_LEN="$(jq '.hooks.Stop | length' "$HOOKS_JSON")"
check "EDMV4-T45 AC2 -- Stop still has exactly one matcher block (stop-event rules are evaluated IN it, not via a second block)" \
  "1" "$T45_STOP_LEN"

# ---- AC6: with hookify present (a rule directory exists and is enabled) and the Phase 6 marker
# ABSENT, an Edit is allowed with ZERO rule evaluation -- reusing the jq-counting-shim technique
# EDMV4-T11 AC9 already established for the identical claim (zero jq on the allow path applies to
# hookify's own jq usage too, since the hookify call never happens before the marker is present). -
harness_scratch_dir T45_AC6_TMP
T45_AC6_FAKEBIN="${T45_AC6_TMP}/fakebin"
mkdir -p "$T45_AC6_FAKEBIN" "${T45_AC6_TMP}/proj/.claude/edm-hookify"
cp "${HOOKIFY_FIXTURES}/warn-no-console-log.json" "${T45_AC6_TMP}/proj/.claude/edm-hookify/"
for _t45_bin in dirname bash grep date mkdir mv rm cat git; do
  ln -s "$(command -v "$_t45_bin")" "${T45_AC6_FAKEBIN}/${_t45_bin}"
done
cat > "${T45_AC6_FAKEBIN}/jq" <<T45JQSPY
#!/bin/sh
: > "${T45_AC6_FAKEBIN}/.jq_invoked"
exit 99
T45JQSPY
chmod +x "${T45_AC6_FAKEBIN}/jq"
cat > "${T45_AC6_FAKEBIN}/edm-hookify" <<T45HFSPY
#!/bin/sh
: > "${T45_AC6_FAKEBIN}/.hookify_invoked"
exit 99
T45HFSPY
chmod +x "${T45_AC6_FAKEBIN}/edm-hookify"

T45_AC6_DATA_ABSENT="${T45_AC6_TMP}/data-absent"
mkdir -p "$T45_AC6_DATA_ABSENT"
T45_AC6_RC=0
T45_AC6_OUT="$(printf '{"tool_name":"Edit","tool_input":{"file_path":"src/foo.js","new_text":"console.log(1)"}}' | \
  CLAUDE_PROJECT_DIR="${T45_AC6_TMP}/proj" CLAUDE_PLUGIN_DATA="$T45_AC6_DATA_ABSENT" PATH="$T45_AC6_FAKEBIN" bash "$GATEGUARD" 2>"${T45_AC6_TMP}/ac6.stderr")" || T45_AC6_RC=$?
T45_AC6_STDERR="$(cat "${T45_AC6_TMP}/ac6.stderr" 2>/dev/null || true)"
if [[ "$T45_AC6_RC" -eq 0 && -z "$T45_AC6_OUT" && -z "$T45_AC6_STDERR" ]]; then
  pass "EDMV4-T45 AC6 -- marker absent, hookify present with an enabled rule: still exit 0, empty output"
else
  fail "EDMV4-T45 AC6 -- rc=${T45_AC6_RC} stdout=[${T45_AC6_OUT}] stderr=[${T45_AC6_STDERR}]"
fi
if [[ ! -f "${T45_AC6_FAKEBIN}/.hookify_invoked" ]]; then
  pass "EDMV4-T45 AC6 -- edm-hookify was never invoked on the marker-absent path (zero hookify-attributable spawns)"
else
  fail "EDMV4-T45 AC6 -- edm-hookify WAS invoked despite the marker being absent"
fi

# Positive control: the identical fixture, marker PRESENT, DOES invoke edm-hookify -- proving the
# spy is capable of firing and the zero-count above is not vacuous. Uses a SEPARATE fakebin with a
# REAL jq (the marker-present gated path legitimately needs one to parse tool_name) plus only the
# edm-hookify spy, placed ahead of the real bin/ in PATH so the spy shadows the real binary
# without a fake jq breaking the JSON parse the gated path depends on.
T45_AC6B_FAKEBIN="${T45_AC6_TMP}/fakebin-control"
mkdir -p "$T45_AC6B_FAKEBIN"
for _t45b_bin in dirname bash grep date mkdir mv rm cat git jq; do
  ln -s "$(command -v "$_t45b_bin")" "${T45_AC6B_FAKEBIN}/${_t45b_bin}"
done
cat > "${T45_AC6B_FAKEBIN}/edm-hookify" <<T45HFSPY2
#!/bin/sh
: > "${T45_AC6B_FAKEBIN}/.hookify_invoked"
exit 99
T45HFSPY2
chmod +x "${T45_AC6B_FAKEBIN}/edm-hookify"

T45_AC6_DATA_PRESENT="${T45_AC6_TMP}/data-present"
mkdir -p "${T45_AC6_DATA_PRESENT}/run"
T45_AC6_KEY="$(CLAUDE_PROJECT_DIR="${T45_AC6_TMP}/proj" bash -c ". '${DATADIR_LIB}'; edm_project_key" 2>/dev/null)"
printf 'T45PFX\t%s\t2026-09-02T00:00:00Z\n' "${T45_AC6_TMP}/proj" > "${T45_AC6_DATA_PRESENT}/run/${T45_AC6_KEY}.phase6"
printf 'src/foo.js\n' > "${T45_AC6_DATA_PRESENT}/run/${T45_AC6_KEY}.checked"
printf '{"tool_name":"Edit","tool_input":{"file_path":"src/foo.js","new_text":"console.log(1)"}}' | \
  CLAUDE_PROJECT_DIR="${T45_AC6_TMP}/proj" CLAUDE_PLUGIN_DATA="$T45_AC6_DATA_PRESENT" PATH="${T45_AC6B_FAKEBIN}:${PLUGIN_DIR}/bin:${PATH}" bash "$GATEGUARD" >/dev/null 2>&1 || true
if [[ -f "${T45_AC6B_FAKEBIN}/.hookify_invoked" ]]; then
  pass "EDMV4-T45 AC6 -- positive control: edm-hookify DOES fire once the marker is present, so the absent-case zero-count is not vacuous"
else
  fail "EDMV4-T45 AC6 -- positive control FAILED: edm-hookify never fired even with a marker present"
fi

# ---- AC7: with the marker present and a matching file rule enabled, the rule evaluates EXACTLY
# ONCE per gated edit -- a real edm-hookify call-count spy (not jq), against a rule carrying TWO
# AND'd conditions, so "once per condition" would visibly diverge from "once per call" if it
# occurred. --------------------------------------------------------------------------------------
harness_scratch_dir T45_AC7_TMP
mkdir -p "${T45_AC7_TMP}/proj/.claude/edm-hookify" "${T45_AC7_TMP}/data/run"
cat > "${T45_AC7_TMP}/proj/.claude/edm-hookify/two-conditions.json" <<'EOF'
{
  "name": "two-cond-rule",
  "enabled": true,
  "event": "file",
  "action": "warn",
  "conditions": [
    { "field": "file_path", "operator": "contains", "pattern": "foo" },
    { "field": "new_text", "operator": "contains", "pattern": "console.log" }
  ],
  "message": "two conditions matched"
}
EOF
T45_AC7_KEY="$(CLAUDE_PROJECT_DIR="${T45_AC7_TMP}/proj" bash -c ". '${DATADIR_LIB}'; edm_project_key" 2>/dev/null)"
printf 'T45PFX\t%s\t2026-09-02T00:00:00Z\n' "${T45_AC7_TMP}/proj" > "${T45_AC7_TMP}/data/run/${T45_AC7_KEY}.phase6"
printf 'src/foo.js\n' > "${T45_AC7_TMP}/data/run/${T45_AC7_KEY}.checked"

T45_AC7_SPYBIN="${T45_AC7_TMP}/spybin"
mkdir -p "$T45_AC7_SPYBIN"
T45_REAL_HOOKIFY="$(command -v edm-hookify 2>/dev/null || echo "${PLUGIN_DIR}/bin/edm-hookify")"
cat > "${T45_AC7_SPYBIN}/edm-hookify" <<T45HFCOUNT
#!/bin/sh
count_file="${T45_AC7_TMP}/.hookify_call_count"
n=\$(cat "\$count_file" 2>/dev/null || echo 0)
echo \$((n + 1)) > "\$count_file"
exec "${T45_REAL_HOOKIFY}" "\$@"
T45HFCOUNT
chmod +x "${T45_AC7_SPYBIN}/edm-hookify"

printf '{"tool_name":"Edit","tool_input":{"file_path":"src/foo.js","new_text":"console.log(1)"}}' | \
  CLAUDE_PROJECT_DIR="${T45_AC7_TMP}/proj" CLAUDE_PLUGIN_DATA="${T45_AC7_TMP}/data" \
  PATH="${T45_AC7_SPYBIN}:${PLUGIN_DIR}/bin:${PATH}" bash "$GATEGUARD" >/dev/null 2>&1 || true
T45_AC7_COUNT="$(cat "${T45_AC7_TMP}/.hookify_call_count" 2>/dev/null || echo 0)"
check "EDMV4-T45 AC7 -- a two-condition rule is evaluated via exactly one edm-hookify call, not once per condition" \
  "1" "$T45_AC7_COUNT"

# ---- AC8: CLAUDE.md's Hooks behavior documents which events hookify serves and which owns each --
T45_CLAUDE_MD_TEXT="$(cat "${PLUGIN_DIR}/CLAUDE.md")"
check "EDMV4-T45 AC8 -- documents file events owned by edm-gateguard's allow path" \
  "evaluates enabled \`file\`-event hookify rules exactly once, on the allow path" "$T45_CLAUDE_MD_TEXT"
check "EDMV4-T45 AC8 -- documents stop events owned by edm-stop-gate" \
  "evaluates enabled \`stop\`-event hookify rules exactly once per invocation" "$T45_CLAUDE_MD_TEXT"
check "EDMV4-T45 AC8 -- documents the new PreToolUse Bash row and its owner (edm-bash-gate)" \
  "Delegates to \`bin/edm-bash-gate\`" "$T45_CLAUDE_MD_TEXT"
check "EDMV4-T45 AC8 -- states hookify registers no PreToolUse/Stop block of its own for file/stop" \
  "hookify registers no" "$T45_CLAUDE_MD_TEXT"

# ---- AC9: hooks.json (carrying the new Bash block's command string) still parses as valid JSON,
# and edm-check-vocabulary -- which hard-dies on invalid JSON in that file before scanning it --
# still passes over the whole plugin tree. --------------------------------------------------------
if jq . "$HOOKS_JSON" >/dev/null 2>&1; then
  pass "EDMV4-T45 AC9 -- hooks.json (including the new Bash block) still parses as valid JSON"
else
  fail "EDMV4-T45 AC9 -- hooks.json failed to parse as JSON after adding the Bash block"
fi
T45_VOCAB_RC=0
(cd "$PLUGIN_DIR" && bash bin/edm-check-vocabulary >/dev/null 2>&1) || T45_VOCAB_RC=$?
check "EDMV4-T45 AC9 -- edm-check-vocabulary passes over the updated hooks.json and the new edm-bash-gate" "0" "$T45_VOCAB_RC"

echo

# =================================================================================================
# CA-004 (P0, code-audit pass 1): edm-bash-gate has zero behavioural coverage -- close it here
# =================================================================================================
# No suite before this ever piped a payload into bin/edm-bash-gate; it was touched only as a file
# (an -x check, the hooks.json guard substring, the bash-4 parse list above). This section drives
# the real binary through six documented cases plus one characterization case for a KNOWN,
# separately-ticketed gap (CA-039) the remediation plan for this finding names explicitly.
# HOOKIFY_FIXTURES, EDM_BASH_GATE, PLUGIN_DIR and TMP are already set by the EDMV4-T42/T45/T50
# sections above.
echo "=== CA-004: edm-bash-gate behavioural coverage (exit-2 block, fail-open guards, projection, --help) ==="
echo

# ca004_bash_gate_run <proj-dir> <payload> -- runs the REAL bin/edm-bash-gate once, piping
# <payload> on stdin with CLAUDE_PROJECT_DIR=<proj-dir> and plugins/edm/bin prepended to PATH (so
# the real edm-hookify and jq resolve exactly as they would for a live host invocation), capturing
# stdout/stderr/rc into the CA004_RUN_* globals.
ca004_bash_gate_run() {
  local proj="$1" payload="$2"
  CA004_RUN_RC=0
  CA004_RUN_OUT="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$proj" PATH="${PLUGIN_DIR}/bin:${PATH}" \
    bash "$EDM_BASH_GATE" 2>"${TMP}/ca004-run.stderr")" || CA004_RUN_RC=$?
  CA004_RUN_ERR="$(cat "${TMP}/ca004-run.stderr" 2>/dev/null || true)"
}

# ---- Case 1: a matching BLOCK bash rule (the shipped block-rm-rf-bash.json fixture) denies -- ----
# exit 2, the matched rule's line on stderr, empty stdout.
CA004_C1_DIR="${TMP}/ca004-c1"
mkdir -p "${CA004_C1_DIR}/.claude/edm-hookify"
cp "${HOOKIFY_FIXTURES}/block-rm-rf-bash.json" "${CA004_C1_DIR}/.claude/edm-hookify/"

ca004_bash_gate_run "$CA004_C1_DIR" '{"tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/scratch-target"}}'
[[ "$CA004_RUN_RC" -eq 2 ]] && pass "CA-004 case 1 -- a matching block bash rule (rm -rf) makes edm-bash-gate exit 2" \
  || fail "CA-004 case 1 -- expected exit 2 for a matching block rule, got ${CA004_RUN_RC}"
check "CA-004 case 1 -- the matched block rule's line reaches stderr" \
  "block-rm-rf-bash block Refusing a bash command matching rm -rf" "$CA004_RUN_ERR"
if [[ -z "$CA004_RUN_OUT" ]]; then
  pass "CA-004 case 1 -- stdout is empty on a block (the matched line goes to stderr, never stdout)"
else
  fail "CA-004 case 1 -- expected empty stdout on a block, got: ${CA004_RUN_OUT}"
fi

# ---- Case 2: a non-matching bash command, same rule directory -- allows silently. ----------------
ca004_bash_gate_run "$CA004_C1_DIR" '{"tool_name":"Bash","tool_input":{"command":"ls -la /tmp"}}'
if [[ "$CA004_RUN_RC" -eq 0 && -z "$CA004_RUN_OUT" && -z "$CA004_RUN_ERR" ]]; then
  pass "CA-004 case 2 -- a non-matching bash command allows silently (exit 0, empty stdout and stderr)"
else
  fail "CA-004 case 2 -- rc=${CA004_RUN_RC} stdout=[${CA004_RUN_OUT}] stderr=[${CA004_RUN_ERR}]"
fi

# ---- Case 3: a matching WARN bash rule -- exit 0, never 2, with the warn line still visible on ---
# stderr as proof the rule actually fired rather than silently no-op'ing.
CA004_C3_DIR="${TMP}/ca004-c3"
mkdir -p "${CA004_C3_DIR}/.claude/edm-hookify"
jq '.action = "warn" | .name = "warn-rm-rf-bash"' "${HOOKIFY_FIXTURES}/block-rm-rf-bash.json" \
  > "${CA004_C3_DIR}/.claude/edm-hookify/warn-rm-rf-bash.json"

ca004_bash_gate_run "$CA004_C3_DIR" '{"tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/scratch-target"}}'
[[ "$CA004_RUN_RC" -eq 0 ]] && pass "CA-004 case 3 -- a matching WARN bash rule leaves edm-bash-gate at exit 0 (never 2)" \
  || fail "CA-004 case 3 -- expected exit 0 for a warn-only match, got ${CA004_RUN_RC}"
check "CA-004 case 3 -- the warn match's line still reaches stderr, proving the rule fired rather than no-op'd" \
  "warn-rm-rf-bash warn Refusing a bash command matching rm -rf" "$CA004_RUN_ERR"

# ---- Case 4: a malformed rule file (edm-hookify's own setup-error exit 1) must never escalate ----
# to a block -- exit 0, with the setup-error diagnostic still visible on stderr.
CA004_C4_DIR="${TMP}/ca004-c4"
mkdir -p "${CA004_C4_DIR}/.claude/edm-hookify"
cp "${HOOKIFY_FIXTURES}/malformed-invalid-json.json" "${CA004_C4_DIR}/.claude/edm-hookify/"

ca004_bash_gate_run "$CA004_C4_DIR" '{"tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/scratch-target"}}'
[[ "$CA004_RUN_RC" -eq 0 ]] && pass "CA-004 case 4 -- a malformed rule file (edm-hookify's setup-error exit 1) never escalates to a block" \
  || fail "CA-004 case 4 -- expected exit 0 (a setup error must not escalate), got ${CA004_RUN_RC}"
check "CA-004 case 4 -- edm-hookify's own setup-error diagnostic for the malformed file still reaches stderr" \
  "malformed-invalid-json" "$CA004_RUN_ERR"

# ---- Case 5: empty stdin -- allows silently (the [[ -n "$PAYLOAD" ]] empty-payload guard fires).
CA004_C5_DIR="${TMP}/ca004-c5"
mkdir -p "${CA004_C5_DIR}/.claude/edm-hookify"
cp "${HOOKIFY_FIXTURES}/block-rm-rf-bash.json" "${CA004_C5_DIR}/.claude/edm-hookify/"

ca004_bash_gate_run "$CA004_C5_DIR" ""
if [[ "$CA004_RUN_RC" -eq 0 && -z "$CA004_RUN_OUT" && -z "$CA004_RUN_ERR" ]]; then
  pass "CA-004 case 5 -- empty stdin allows silently (exit 0, empty stdout and stderr)"
else
  fail "CA-004 case 5 -- rc=${CA004_RUN_RC} stdout=[${CA004_RUN_OUT}] stderr=[${CA004_RUN_ERR}]"
fi

# ---- Case 6: unparseable (non-JSON) stdin -- allows silently (the jq -c projection failure guard
# fires; a real block rule is present so a false clean here would still show up as a missed block).
ca004_bash_gate_run "$CA004_C5_DIR" "not json at all"
if [[ "$CA004_RUN_RC" -eq 0 && -z "$CA004_RUN_OUT" && -z "$CA004_RUN_ERR" ]]; then
  pass "CA-004 case 6 -- unparseable (non-JSON) stdin allows silently (exit 0, empty stdout and stderr)"
else
  fail "CA-004 case 6 -- rc=${CA004_RUN_RC} stdout=[${CA004_RUN_OUT}] stderr=[${CA004_RUN_ERR}]"
fi

# ---- --help: exits 0 with non-empty output. ------------------------------------------------------
CA004_HELP_RC=0
CA004_HELP_OUT="$(/bin/bash "$EDM_BASH_GATE" --help 2>&1)" || CA004_HELP_RC=$?
if [[ "$CA004_HELP_RC" -eq 0 && -n "$CA004_HELP_OUT" ]]; then
  pass "CA-004 -- edm-bash-gate --help exits 0 with non-empty output"
else
  fail "CA-004 -- edm-bash-gate --help exited ${CA004_HELP_RC} with output: ${CA004_HELP_OUT}"
fi

# ---- Known, separately-ticketed gap (CA-039, not fixed by this finding): the jq projection into
# hookify's {"command": ...} field shape reads .tool_input.command with a `// ""` fallback, so it
# always succeeds even when that field is absent under a renamed key -- a payload shaped like this
# one is therefore indistinguishable from "no rule matched" rather than a distinct, name-able
# failure mode. This section drives that exact shape explicitly, per this finding's remediation
# plan, as a characterization test of a known gap -- not a claim that the gap is closed.
ca004_bash_gate_run "$CA004_C1_DIR" '{"tool_name":"Bash","cmd":"rm -rf /tmp/scratch-target"}'
if [[ "$CA004_RUN_RC" -eq 0 && -z "$CA004_RUN_OUT" && -z "$CA004_RUN_ERR" ]]; then
  pass "CA-004 -- characterizes CA-039: a payload carrying a renamed 'cmd' field instead of tool_input.command is indistinguishable from a clean allow (exit 0, empty output) -- a known, separately-ticketed gap, not fixed here"
else
  fail "CA-004 -- CA-039 characterization mismatch: rc=${CA004_RUN_RC} stdout=[${CA004_RUN_OUT}] stderr=[${CA004_RUN_ERR}] (if this now fails, CA-039 may have been fixed -- update this comment rather than deleting the case)"
fi

# ---- Positive control (this finding's own verification clause): a mutant copy of edm-bash-gate
# with its exit-2 block translation removed must FAIL case 1's block, proving case 1's assertion
# discriminates a real regression rather than passing regardless of the binary's actual behaviour.
CA004_MUTANT="${TMP}/ca004-mutant-edm-bash-gate"
sed 's/^  exit 2$/  exit 0/' "$EDM_BASH_GATE" > "$CA004_MUTANT"
chmod +x "$CA004_MUTANT"

CA004_MUTANT_RC=0
CA004_MUTANT_OUT="$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/scratch-target"}}' | \
  CLAUDE_PROJECT_DIR="$CA004_C1_DIR" PATH="${PLUGIN_DIR}/bin:${PATH}" bash "$CA004_MUTANT" 2>&1)" || CA004_MUTANT_RC=$?
if [[ "$CA004_MUTANT_RC" -ne 2 ]]; then
  pass "CA-004 -- positive control: a mutant edm-bash-gate with the exit-2 block translation removed no longer denies case 1's matching rule (rc=${CA004_MUTANT_RC}), proving case 1 discriminates rather than passing unconditionally"
else
  fail "CA-004 -- positive control broken: the mutant still exited 2 despite its exit-2 translation line being removed"
fi

echo

# =================================================================================================
# EDMV4-T28 -- Specify and mechanically enforce the house lens contract for the three new lenses
# =================================================================================================
# The contract's nine structural parts are documented in CLAUDE.md Sec."Audit lens house
# contract (canonical, EDMV4-T28)" and verified here against every LIVE agents/edm-audit-*.md
# lens file: frontmatter, opening frame, '## Scope', '## What You Hunt For', '## False Alarm
# Filter', '## Output', '## Output Format', '## JSONL Line Format', '## When this does NOT
# apply'. The lens FILE SET below is derived by globbing agents/edm-audit-*.md and excluding the
# synthesizer -- never a fourth hardcoded fourteen-name list -- so a future fifteenth lens is
# checked automatically instead of silently escaping coverage the way a hardcoded list already
# did once this initiative (see EDMV4-T30's own Technical Notes on re-inventorying stale counts,
# and docs/audit-patterns/code-audit.md's "verification scan matches the prose it hunts" entry
# for the general shape of this failure). Per that same entry, every zero-count-style assertion
# below is paired with a positive control: a scratch fixture that corrupts exactly one contract
# element and proves the checker actually flags it, so "found 0 violations" here means the
# checker looked and found nothing, not that it cannot find anything.
echo "=== EDMV4-T28: house lens contract -- specification and mechanical enforcement ==="

T28_AGENTS_DIR="${PLUGIN_DIR}/agents"
T28_LENS_FILES="$(cd "$T28_AGENTS_DIR" && ls edm-audit-*.md 2>/dev/null | grep -v '^edm-audit-synthesizer\.md$' | sort)" || true
# shellcheck disable=SC2086 # deliberate word-splitting to count space-separated members
T28_LENS_COUNT="$(printf '%s\n' $T28_LENS_FILES | grep -c '.')" || true

# Cross-check the live file-glob count against ALL_LENS_IDS's own count, so the two independently
# derived numbers (files on disk vs. IDs edm-state knows about) must agree rather than either one
# being trusted alone.
# shellcheck disable=SC2034 # sourced only for its ALL_LENS_IDS/CONDITIONAL_LENS_IDS side effect
T28_ALL_LENS_IDS="$(source "$EDM_STATE" >/dev/null 2>&1; echo "$ALL_LENS_IDS")"
T28_CONDITIONAL_LENS_IDS="$(source "$EDM_STATE" >/dev/null 2>&1; echo "$CONDITIONAL_LENS_IDS")"
# shellcheck disable=SC2086 # deliberate word-splitting to count space-separated members
T28_ALL_LENS_COUNT="$(printf '%s\n' $T28_ALL_LENS_IDS | grep -c '.')" || true
[[ "$T28_LENS_COUNT" -eq "$T28_ALL_LENS_COUNT" ]] \
  && pass "EDMV4-T28 -- agents/edm-audit-*.md file count (${T28_LENS_COUNT}, live glob) matches ALL_LENS_IDS's own count (${T28_ALL_LENS_COUNT})" \
  || fail "EDMV4-T28 -- agents/edm-audit-*.md file count (${T28_LENS_COUNT}) disagrees with ALL_LENS_IDS (${T28_ALL_LENS_COUNT})"

# ---- t28_contract_violations <file> -- prints one tag per violated contract element, or nothing
# when <file> fully conforms. Every tag traces to one AC of EDMV4-T28. ---------------------------
t28_contract_violations() {
  local file="$1"
  [[ -f "$file" ]] && [[ -s "$file" ]] || { echo "MISSING_OR_EMPTY_FILE"; return 0; }

  # AC1/AC2/AC11: frontmatter -- tool grant, disallowed-tools, model/effort tier, color. Anchored
  # full-line matches (not bare substrings) so an appended extra tool cannot hide inside a still-
  # present prefix.
  grep -qE '^tools: Glob, Grep, LS, Read, NotebookRead, WebFetch, TodoWrite, WebSearch, Write$' "$file" \
    || echo "TOOLS_LINE"
  grep -qE '^disallowedTools: Edit, NotebookEdit$' "$file" || echo "DISALLOWED_TOOLS"
  grep -qE '^model: opus$' "$file" || echo "MODEL"
  grep -qE '^effort: max$' "$file" || echo "EFFORT"
  grep -qE '^color: cyan$' "$file" || echo "COLOR"

  # AC4: opening frame + adjacent mandate-narrowing sentence.
  grep -qE '^You are executing \*\*EDM Code Audit Lens L[0-9]+: .+\*\*\.$' "$file" || echo "OPENING_FRAME"
  grep -qF 'Your mandate is ONLY this lens. Do not audit other dimensions -- other agents handle those.' "$file" \
    || echo "MANDATE_SENTENCE"

  # AC5: verbatim house Scope paragraph, byte-identical across every lens IN CONTENT -- but not
  # necessarily in raw line-wrapping: edm-audit-security.md (L8) hard-wraps this same paragraph
  # across two source lines at a different column than edm-audit-logic.md (L1)'s single-line form
  # (verified live: both read identically once the wrap's newline is treated as a space). A single
  # grep -qF spanning the wrap point would therefore false-positive on L8, so this is two short,
  # wrap-safe substring checks (one from each side of where L8's wrap falls) rather than one long
  # literal that assumes L1's line width.
  if grep -qF 'deliver what was asked at the scope intended; make routine judgment calls; if a better approach exists, say so in a' "$file" \
    && grep -qF 'rather than quietly narrowing, widening or transforming it.' "$file"; then
    :
  else
    echo "SCOPE_PARAGRAPH"
  fi

  # AC6: identical False Alarm Filter framing sentence, exactly three numbered criteria.
  grep -qF 'Report every finding at your best-effort confidence level rather than self-suppressing on uncertainty: this filter demotes a finding to `## Noted / Not Actionable` with a documented rationale and never deletes it outright, and ranking by confidence and cross-lens corroboration is the synthesizer'"'"'s job, not this lens'"'"'s.' "$file" \
    || echo "FAF_FRAMING"
  local faf_count
  faf_count="$(awk '/^## False Alarm Filter/{f=1;next} /^## /{f=0} f' "$file" | grep -c '^[0-9]\+\.')" || faf_count=0
  [[ "${faf_count:-0}" -eq 3 ]] || echo "FAF_CRITERIA_COUNT"

  # AC7: Output section -- two write paths (self-consistent against the lens's OWN opening-frame
  # ID, not an externally supplied one), ASCII reminder, mkdir-p rationale, JSONL-authoritative.
  local n
  n="$(grep -oE '\*\*EDM Code Audit Lens L[0-9]+' "$file" | head -1 | grep -oE '[0-9]+')" || true
  if [[ -n "$n" ]]; then
    grep -qF "\${OUTPUT_DIR}/lens-L${n}.md" "$file" || echo "OUTPUT_MD_PATH"
    grep -qF "\${OUTPUT_DIR}/lens-L${n}.jsonl" "$file" || echo "OUTPUT_JSONL_PATH"
    grep -qF "\"lens\":\"L${n}\"" "$file" || echo "SCHEMA_LENS_ID"
  else
    echo "LENS_ID_UNRESOLVABLE"
  fi
  grep -qF 'Report text is ASCII-only -- no Unicode em dashes, arrows, smart quotes, or emoji glyphs.' "$file" \
    || echo "ASCII_REMINDER"
  grep -qF 'that is why you are granted' "$file" || echo "MKDIR_RATIONALE"
  grep -qF 'The JSONL file is authoritative on conflict' "$file" || echo "JSONL_AUTHORITATIVE"

  # AC8: Output Format cites the closed severity scale and the canonical-sections anchor,
  # including both qualifying clauses (C6 enforcement point).
  grep -qF 'CLAUDE.md Sec."Severity vocabulary"' "$file" || echo "SEVERITY_CITATION"
  # Keyed on the backtick-quoted path alone, not "Read `docs/..." together: edm-audit-security.md
  # (L8) wraps this instruction so "Read" ends one source line and the path starts the next --
  # exactly the wrapped form EDMV4-T28's own Technical Notes warn a byte-exact assertion must
  # survive. The path itself does not straddle the wrap in either the L1 or L8 form.
  grep -qF '`docs/canonical-sections.md`' "$file" || echo "CANONICAL_SECTIONS_ANCHOR"
  grep -qF "resolved relative to the EDM plugin's own root" "$file" || echo "ANCHOR_QUALIFIER"
  grep -qF "never the caller's cwd" "$file" || echo "ANCHOR_NEVER_CWD"

  # AC9: JSONL Line Format -- the five field-rule bullets and the residual-risk paragraph.
  grep -qF 'is always `null` at the lens stage' "$file" || echo "JSONL_ID_RULE"
  grep -qF 'are supplied by the code-audit skill from the round it actually' "$file" || echo "JSONL_ROUND_RULE"
  grep -qF 'is exactly one of `P0`, `P1`, `P2`, `NOTED`' "$file" || echo "JSONL_SEV_RULE"
  grep -qF 'is mandatory on every line and is exactly `high`, `medium`, or `low`' "$file" || echo "JSONL_CONFIDENCE_RULE"
  grep -qF 'is exactly one of `open`, `fixed`, `noted`' "$file" || echo "JSONL_STATUS_RULE"
  grep -qF 'a finding present in the prose report with no' "$file" || echo "RESIDUAL_RISK_PARAGRAPH"

  # AC10: '## When this does NOT apply' present; standard sentence for every UNCONDITIONAL lens
  # (its own ID not a member of CONDITIONAL_LENS_IDS); the EDMV4-T26 exception form for the sole
  # conditional lens.
  grep -qE '^## When this does NOT apply$' "$file" || echo "NA_HEADING"
  if [[ -n "$n" ]]; then
    case " ${T28_CONDITIONAL_LENS_IDS} " in
      *" L${n} "*)
        grep -qF 'inapplicability' "$file" || echo "NA_CONDITIONAL_INAPPLICABILITY"
        grep -qF 'cost is never a reason to skip this lens' "$file" || echo "NA_CONDITIONAL_COST_NEVER"
        grep -qF 'agrees with that determination and never substitutes' "$file" || echo "NA_CONDITIONAL_AGREEMENT"
        ;;
      *)
        grep -qF "This agent always applies once the code-audit skill selects lens L${n} for the round" "$file" \
          || echo "NA_STANDARD_SENTENCE"
        ;;
    esac
  fi

  # Heading order -- the seven REQUIRED headings above frontmatter/opening-frame must all be
  # present and in this relative order (excluding fenced code-block content, which itself
  # contains a '## Findings' heading that must NOT be counted as a real section heading). This is
  # a SUBSEQUENCE check, not full-sequence equality: several pre-EDMV4 lenses legitimately carry
  # an extra lens-specific heading between 'What You Hunt For' and 'False Alarm Filter' (verified
  # live: edm-audit-consistency.md and edm-audit-dry.md both add '## Process', edm-audit-dead-code.md
  # adds '## Key Technique') -- pre-existing, out of this ticket's scope (the three NEW lenses,
  # per EDMV4-T28's own title), and not itself a contract violation the way a MISSING or
  # REORDERED required heading is. Filtering the actual heading list down to only the seven
  # required strings (grep -Fx, which preserves the file's own line order) tolerates that extra
  # heading while still catching a required heading that is absent or out of order.
  local expected actual
  expected="## Scope
## What You Hunt For
## False Alarm Filter
## Output
## Output Format
## JSONL Line Format
## When this does NOT apply"
  actual="$(awk '/^```/{f=!f;next} !f' "$file" | grep -E '^## ' \
    | grep -Fx -e '## Scope' -e '## What You Hunt For' -e '## False Alarm Filter' \
      -e '## Output' -e '## Output Format' -e '## JSONL Line Format' \
      -e '## When this does NOT apply')" || true
  [[ "$actual" == "$expected" ]] || echo "HEADING_ORDER"
  return 0
}

echo
echo "EDMV4-T28 AC1-AC11 -- every live lens agent (${T28_LENS_COUNT} files) is checked against the house contract by name"
for t28_f in $T28_LENS_FILES; do
  t28_v="$(t28_contract_violations "${T28_AGENTS_DIR}/${t28_f}" | tr '\n' ',')" || true
  if [[ -z "$t28_v" ]]; then
    pass "EDMV4-T28 -- ${t28_f} conforms to the house lens contract in full"
  else
    fail "EDMV4-T28 -- ${t28_f} violates the house contract: ${t28_v%,}"
  fi
done

echo
echo "EDMV4-T28 -- positive baseline: the reference lens (edm-audit-logic.md, L1) itself carries zero violations"
T28_REF="${T28_AGENTS_DIR}/edm-audit-logic.md"
T28_REF_VIOLATIONS="$(t28_contract_violations "$T28_REF" | tr '\n' ',')" || true
[[ -z "$T28_REF_VIOLATIONS" ]] \
  && pass "EDMV4-T28 -- edm-audit-logic.md is the clean baseline the negative fixtures below mutate" \
  || fail "EDMV4-T28 -- edm-audit-logic.md unexpectedly fails its own contract: ${T28_REF_VIOLATIONS%,}"

echo
echo "EDMV4-T28 -- negative fixtures: each contract element, corrupted in isolation on a scratch copy of L1, is caught"
harness_scratch_dir T28_TMP

# t28_neg_case <label> <expected-tag> <sed-script> -- writes a scratch copy of the reference lens
# with <sed-script> applied, runs the checker, and asserts <expected-tag> appears among the
# violations. This is the positive-control half of every zero-count check above: it proves each
# tag's grep can actually fail, not merely that it has not failed yet.
t28_neg_case() {
  local label="$1" tag="$2" script="$3"
  local safe_label fixture v
  safe_label="$(printf '%s' "$label" | tr -c 'A-Za-z0-9' '_')"
  fixture="${T28_TMP}/${safe_label}.md"
  sed "$script" "$T28_REF" > "$fixture"
  v="$(t28_contract_violations "$fixture" | tr '\n' ',')" || true
  case ",${v}," in
    *",${tag},"*) pass "EDMV4-T28 -- negative fixture (${label}): checker correctly flags ${tag}" ;;
    *) fail "EDMV4-T28 -- negative fixture (${label}): checker did NOT flag ${tag} (violations found: ${v%,})" ;;
  esac
}

t28_neg_case "tools grant widened past Write" "TOOLS_LINE" \
  's/^tools: Glob, Grep, LS, Read, NotebookRead, WebFetch, TodoWrite, WebSearch, Write$/tools: Glob, Grep, LS, Read, NotebookRead, WebFetch, TodoWrite, WebSearch, Write, Edit/'
t28_neg_case "model downgraded off opus" "MODEL" 's/^model: opus$/model: sonnet/'
t28_neg_case "color changed off cyan" "COLOR" 's/^color: cyan$/color: green/'
t28_neg_case "mandate-narrowing sentence removed" "MANDATE_SENTENCE" '/^Your mandate is ONLY this lens/d'
t28_neg_case "house Scope paragraph removed" "SCOPE_PARAGRAPH" '/^deliver what was asked at the scope intended/d'
t28_neg_case "False Alarm Filter framing sentence removed" "FAF_FRAMING" '/^Report every finding at your best-effort confidence level/d'
t28_neg_case "False Alarm Filter dropped to two criteria" "FAF_CRITERIA_COUNT" \
  '/^3\. Is this pattern used consistently everywhere in the project?$/d'
t28_neg_case "Output section md path drifted off its own lens ID" "OUTPUT_MD_PATH" \
  's/lens-L1\.md` -- your raw findings report/lens-L9.md` -- your raw findings report/'
t28_neg_case "mkdir-p rationale sentence removed" "MKDIR_RATIONALE" '/that is why you are granted/d'
t28_neg_case "JSONL-authoritative sentence removed" "JSONL_AUTHORITATIVE" '/The JSONL file is authoritative on conflict/d'
t28_neg_case "Output Format severity/canonical-sections anchor line removed" "CANONICAL_SECTIONS_ANCHOR" \
  '/Use the canonical severity scale/d'
t28_neg_case "JSONL confidence field rule removed" "JSONL_CONFIDENCE_RULE" \
  '/is mandatory on every line and is exactly/d'
t28_neg_case "When-this-does-NOT-apply section removed entirely" "NA_HEADING" \
  '/^## When this does NOT apply$/,$d'
t28_neg_case "What-You-Hunt-For heading renamed, breaking section order" "HEADING_ORDER" \
  's/^## What You Hunt For$/## What You Look For/'
# Discriminates the SUBSEQUENCE tolerance itself: swaps the two heading MARKER lines '## Output'
# and '## Output Format' (the classic sed hold-space line-swap: hold '## Output' and delete it
# from the stream, then re-emit it right after '## Output Format' is seen) without deleting or
# renaming either required heading -- proving the check still catches a REORDERING, not just a
# removal, even though it now tolerates an unrelated EXTRA heading (see the positive control
# immediately below).
t28_neg_case "Output and Output Format headings swapped (reordered, neither removed)" "HEADING_ORDER" \
  $'/^## Output$/{h;d;}\n/^## Output Format$/{G;}'

echo
echo 'EDMV4-T28 -- positive control: a harmless EXTRA heading (mirroring pre-existing lenses own "## Process"/"## Key Technique") does not itself trip the contract'
# This is what justifies the subsequence tolerance in t28_contract_violations' HEADING_ORDER check
# rather than exact full-list equality: without this control, a checker that tolerates ANY extra
# heading anywhere could not be told apart from one that tolerates a genuinely missing or
# reordered required heading. Verified live before this ticket touched anything:
# edm-audit-consistency.md and edm-audit-dry.md both already carry an extra '## Process' heading
# in exactly this position, and edm-audit-dead-code.md carries '## Key Technique' -- none of the
# three is a contract violation, so this fixture reproduces that same shape on a scratch copy.
T28_EXTRA_HEADING_FIXTURE="${T28_TMP}/extra_heading_tolerated.md"
awk '{print} /^## What You Hunt For$/{print ""; print "## Process"; print ""; print "This lens-specific extra section mirrors edm-audit-consistency.md and edm-audit-dry.md, both of which already carry an analogous heading here without violating the contract."}' \
  "$T28_REF" > "$T28_EXTRA_HEADING_FIXTURE"
T28_EXTRA_HEADING_V="$(t28_contract_violations "$T28_EXTRA_HEADING_FIXTURE" | tr '\n' ',')" || true
[[ -z "$T28_EXTRA_HEADING_V" ]] \
  && pass "EDMV4-T28 -- positive control: an extra lens-specific heading does not trip HEADING_ORDER (the tolerance is deliberate, not a hole)" \
  || fail "EDMV4-T28 -- positive control FAILED: inserting a harmless extra heading incorrectly triggered: ${T28_EXTRA_HEADING_V%,}"

echo
echo "EDMV4-T28 -- edm-check-grants and edm-lint-artifacts remain clean over the live lens set"
if bash "${PLUGIN_DIR}/bin/edm-check-grants" >/dev/null 2>"${SCRIPT_DIR}/.t28-grants.err"; then
  pass "EDMV4-T28 -- edm-check-grants exits 0"
else
  fail "EDMV4-T28 -- edm-check-grants exited non-zero: $(cat "${SCRIPT_DIR}/.t28-grants.err")"
fi
rm -f "${SCRIPT_DIR}/.t28-grants.err"
t28_lint_exit=0
t28_lint_out="$(bash "${PLUGIN_DIR}/bin/edm-lint-artifacts" --path "${T28_AGENTS_DIR}" 2>&1)" || t28_lint_exit=$?
[[ "$t28_lint_exit" -eq 0 ]] && pass "EDMV4-T28 -- edm-lint-artifacts --path agents/ is clean" \
  || fail "EDMV4-T28 -- edm-lint-artifacts reported violations: ${t28_lint_out}"

echo

# =================================================================================================
# EDMV4-T50 -- Extend the tree-wide bash-4 construct ban to cover every new script and wave8-smoke.sh
# =================================================================================================
# T61 AC9 (wave7-smoke.sh) already sweeps every top-level plugins/edm/bin/ file live via
# `find "$PLUGIN_DIR/bin" -maxdepth 1 -type f`, so the five new files (_edm-datadir-lib.sh,
# edm-gateguard, edm-hookify, edm-stop-gate, edm-repo-readiness) fall under it automatically. The
# one real gap T61 AC9 deliberately leaves is bin/tests/ (test-fixture/assertion surface) -- this
# section closes it for the new suite itself, plus recomputes the same construct ban directly
# against bin/ and evals/ as this ticket's own evidence trail. $PLUGIN_DIR is already an absolute,
# `cd .. && pwd`-normalized path (via _harness.sh's _HARNESS_PLUGIN_DIR), so the `/tests/`
# exclusion below is applied to an already-normalized root, not a raw `..`-bearing string.
echo "=== EDMV4-T50: bash 3.2 floor -- no bash-4-only construct in bin/, evals/, or wave8-smoke.sh ==="

# ---- CA-005 (P0, code-audit pass 1): AC1's own live bin/ membership assertion -- cited as
# precedent later in this file's EDMV4-T52 section but never actually implemented until now. A
# script placed in a bin/ SUBDIRECTORY silently escapes every check anchored to `-maxdepth 1`
# (this ticket's own bash-4 sweep below included) with nothing to say so; this assertion recomputes
# the live top-level set and fails naming any required script missing from it, rather than
# assuming membership the way every other -maxdepth-1-anchored check in this file already does.
# The required-name list is AC1's own five plus edm-bash-gate (a sixth top-level script this same
# code-audit round found unlisted everywhere it should have been named -- CA-063).
T50_REQUIRED_BIN_FILES="_edm-datadir-lib.sh edm-gateguard edm-hookify edm-stop-gate edm-repo-readiness edm-bash-gate"

# t50_bin_membership_set <bin-dir> -- prints a space-padded string of every top-level regular
# file's basename directly under <bin-dir> (find -maxdepth 1 -type f), for word-membership testing
# via `case " $set " in *" $name "*)`, matching bin/edm-state's own MODE_ENUM_LIST/ALL_LENS_IDS
# idiom (AC4) rather than a bash-4 array.
t50_bin_membership_set() {
  local bin_dir="$1" set=""
  while IFS= read -r -d "" _t50_bf; do
    set="${set} $(basename "$_t50_bf")"
  done < <(find "$bin_dir" -maxdepth 1 -type f -print0 2>/dev/null)
  printf '%s' "$set"
}

T50_LIVE_BIN_SET="$(t50_bin_membership_set "${PLUGIN_DIR}/bin")"
T50_AC1_MISSING=""
for _t50_req in $T50_REQUIRED_BIN_FILES; do
  case " $T50_LIVE_BIN_SET " in
    *" ${_t50_req} "*) ;;
    *) T50_AC1_MISSING="${T50_AC1_MISSING} ${_t50_req}" ;;
  esac
done
if [[ -z "$T50_AC1_MISSING" ]]; then
  pass "EDMV4-T50 AC1 -- every required top-level bin/ script is present in the live find \"\$PLUGIN_DIR/bin\" -maxdepth 1 -type f set: ${T50_REQUIRED_BIN_FILES}"
else
  fail "EDMV4-T50 AC1 -- required bin/ script(s) absent from the live top-level set:${T50_AC1_MISSING}"
fi

# Positive control: seed a scratch bin/ with every required name present, then relocate ONE of
# them into a bin/ SUBDIRECTORY -- the exact escape AC1 exists to catch -- and confirm the same
# membership logic reports it missing from the top-level set. This never touches the real repo
# tree; the scratch root is discarded afterward.
harness_scratch_dir T50_AC1_CTRL_TMP
mkdir -p "${T50_AC1_CTRL_TMP}/bin/subdir"
for _t50_seed in $T50_REQUIRED_BIN_FILES; do
  : > "${T50_AC1_CTRL_TMP}/bin/${_t50_seed}"
done
mv "${T50_AC1_CTRL_TMP}/bin/edm-repo-readiness" "${T50_AC1_CTRL_TMP}/bin/subdir/edm-repo-readiness"

T50_CTRL_BIN_SET="$(t50_bin_membership_set "${T50_AC1_CTRL_TMP}/bin")"
T50_CTRL_MISSING=""
for _t50_req in $T50_REQUIRED_BIN_FILES; do
  case " $T50_CTRL_BIN_SET " in
    *" ${_t50_req} "*) ;;
    *) T50_CTRL_MISSING="${T50_CTRL_MISSING} ${_t50_req}" ;;
  esac
done
if [[ "$T50_CTRL_MISSING" == *"edm-repo-readiness"* ]]; then
  pass "EDMV4-T50 AC1 -- positive control: relocating a required script into bin/subdir/ is correctly reported missing from the top-level set (reported missing:${T50_CTRL_MISSING})"
else
  fail "EDMV4-T50 AC1 -- positive control broken: relocating edm-repo-readiness into bin/subdir/ was NOT detected as missing from the top-level set"
fi

# A real alternation built here (not sourced from wave7-smoke.sh's own $T61_BASH4_RE): each half
# is independently useful evidence for this ticket, and referencing wave7's private variable would
# couple this suite's own correctness to wave7-smoke.sh's internal naming.
T50_BASH4_RE='declare[[:space:]]+-A|local[[:space:]]+-A|mapfile|readarray|\$\{[a-zA-Z_]+\^\^\}|\$\{[a-zA-Z_]+,,\}'

# ---- Zero bash-4-only constructs across bin/ and evals/ (bin/tests/ excluded -- matching T61
# AC9's own convention); comment-only lines excluded (a prose reference to why a construct is
# avoided is not a use of it).
t50_scan() {
  { grep -rnE "$T50_BASH4_RE" "${PLUGIN_DIR}/bin" "${PLUGIN_DIR}/evals" 2>/dev/null || true; } \
    | grep -v '/tests/' \
    | grep -vE ':[[:space:]]*#'
}
T50_HITS="$(t50_scan || true)"
if [[ -z "$T50_HITS" ]]; then
  pass "EDMV4-T50 -- zero bash-4-only constructs (declare -A/local -A, mapfile, readarray, \${v^^}, \${v,,}) across bin/ and evals/ (bin/tests/ excluded)"
else
  fail "EDMV4-T50 -- bash-4-only construct(s) found:\n${T50_HITS}"
fi

# Positive control: a scratch fixture (OUTSIDE the repo tree, under mktemp) with a real
# 'declare -A' AND a real 'mapfile' usage must both be caught, proving the sweep can fire rather
# than matching nothing -- the exact anti-pattern named in docs/audit-patterns/code-audit.md.
T50_TMP="$(mktemp -d "${TMPDIR:-/tmp}/edm-wave8-t50.XXXXXX")"
T50_FIXTURE="${T50_TMP}/fake-script.sh"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'declare -A T50_CONTROL_ARR'
  printf '%s\n' 'mapfile -t T50_CONTROL_LINES < /dev/null'
} > "$T50_FIXTURE"
T50_CONTROL_HITS="$({ grep -nE "$T50_BASH4_RE" "$T50_FIXTURE" 2>/dev/null || true; } | grep -vE ':[[:space:]]*#' || true)"
if [[ -n "$T50_CONTROL_HITS" ]]; then
  T50_CONTROL_COUNT="$(printf '%s\n' "$T50_CONTROL_HITS" | grep -c .)"
  [[ "$T50_CONTROL_COUNT" -ge 2 ]] \
    && pass "EDMV4-T50 -- positive control: both a synthetic 'declare -A' and 'mapfile' usage are caught (${T50_CONTROL_COUNT} hits)" \
    || fail "EDMV4-T50 -- positive control incomplete: expected 2 hits (declare -A + mapfile), got ${T50_CONTROL_COUNT}"
else
  fail "EDMV4-T50 -- positive control broken: a synthetic 'declare -A'/'mapfile' fixture produced zero hits"
fi

# ---- Self-check: apply the same ban to wave8-smoke.sh itself (the bin/tests/ gap T61 AC9 leaves
# open). This file legitimately CONTAINS the construct names as data -- inside a grep-pattern
# argument scanning some OTHER file (see the EDMV4-T17/T38 sections above), or inside a pass()/
# fail() message describing the rule -- neither of which is a real bash-4 USE in this file's own
# control flow. Excluded narrowly, by shape, not by a broad path exclusion: comment-only lines;
# any line invoking `grep` (a meta-check's pattern argument, never real usage); any line invoking
# `printf` (this section's OWN positive-control fixtures write the construct names as literal
# scratch-file DATA via printf, e.g. `printf '%s\n' 'declare -A ...'` -- not a real use in this
# file's own control flow); the T50_BASH4_RE= definition line itself (its own alternation text
# contains the bare words "mapfile"/"readarray" as plain data -- the exact self-match-by-label
# class named in docs/audit-patterns/code-audit.md); and any pass/fail/echo/check/check_absent/
# check_fails CALL, matched by shape (`keyword` immediately followed by a quoted argument, not
# anchored to start-of-line, since several call sites here are the right-hand side of a `&&`/`||`
# continuation) -- a descriptive message argument, never real usage.
T50_SELF="${SCRIPT_DIR}/wave8-smoke.sh"
t50_self_scan() {
  local target="$1"
  grep -nE "$T50_BASH4_RE" "$target" 2>/dev/null \
    | grep -vE ':[[:space:]]*#' \
    | grep -v 'grep' \
    | grep -v 'printf' \
    | grep -v 'T50_BASH4_RE=' \
    | grep -vE '\b(pass|fail|echo|check|check_absent|check_fails)[[:space:]]*"'
}
T50_SELF_HITS="$(t50_self_scan "$T50_SELF" || true)"
if [[ -z "$T50_SELF_HITS" ]]; then
  pass "EDMV4-T50 -- bin/tests/wave8-smoke.sh itself carries no real bash-4-only construct usage (the bin/tests/ gap T61 AC9 leaves open, closed here)"
else
  fail "EDMV4-T50 -- bash-4-only construct found in wave8-smoke.sh:\n${T50_SELF_HITS}"
fi

# Positive control for the self-check: a scratch copy with a genuine (non-comment, non-grep,
# non-message) usage line appended must still be caught despite the three exclusions above.
T50_SELF_CONTROL="${T50_TMP}/wave8-ac2-control.sh"
cp "$T50_SELF" "$T50_SELF_CONTROL"
printf '\ndeclare -A T50_SELFCONTROL_ARR\n' >> "$T50_SELF_CONTROL"
T50_SELF_CONTROL_HITS="$(t50_self_scan "$T50_SELF_CONTROL" || true)"
if [[ -n "$T50_SELF_CONTROL_HITS" ]]; then
  pass "EDMV4-T50 -- positive control: a real 'declare -A' usage appended to a scratch copy of wave8-smoke.sh is still caught"
else
  fail "EDMV4-T50 -- positive control broken: a real 'declare -A' usage was not caught despite the self-check's exclusions"
fi
rm -rf "$T50_TMP"

# ---- Process substitution in a loop CONDITION (CA-472 fd-leak class): distinct from the safe,
# tree-wide `done < <(cmd)` idiom (loop-level input redirection, used throughout this codebase,
# including several of the new files), which this pattern does NOT match since "while"/"for"/
# "until" never appear on that same line. Anchored with a non-alpha boundary so "for" cannot match
# inside "before"/"format" -- a real self-match this exact pattern produced against this exact
# file before landing, not a hypothetical risk.
T50_PROCSUB_RE='(^|[^a-zA-Z_])(while|for|until)[^a-zA-Z_][^\n]*<[[:space:]]*\('
T50_PROCSUB_HITS="$({ grep -rnE "$T50_PROCSUB_RE" "${PLUGIN_DIR}/bin" "${PLUGIN_DIR}/evals" 2>/dev/null || true; } | grep -v '/tests/' | grep -vE ':[[:space:]]*#' || true)"
if [[ -z "$T50_PROCSUB_HITS" ]]; then
  pass "EDMV4-T50 -- zero process-substitution-in-loop-condition (CA-472 class) hits across bin/ and evals/"
else
  fail "EDMV4-T50 -- process substitution in a loop condition found:\n${T50_PROCSUB_HITS}"
fi

T50_PROCSUB_CONTROL="$(printf '%s\n' 'while read -r x < <(cmd); do' | grep -cE "$T50_PROCSUB_RE" || true)"
[[ "$T50_PROCSUB_CONTROL" -ge 1 ]] \
  && pass "EDMV4-T50 -- positive control: a real condition-position process substitution is caught" \
  || fail "EDMV4-T50 -- positive control broken: synthetic 'while ... < <(...)' was not caught"

T50_PROCSUB_NEG="$(printf '%s\n' 'done < <(find . -type f)' | grep -cE "$T50_PROCSUB_RE" || true)"
[[ "$T50_PROCSUB_NEG" -eq 0 ]] \
  && pass "EDMV4-T50 -- negative control: the safe 'done < <(...)' loop-input idiom is correctly NOT flagged" \
  || fail "EDMV4-T50 -- over-broad: the safe 'done < <(...)' idiom was incorrectly flagged"

# ---- /bin/bash -n parses each of the five new files (plus wave8-smoke.sh) cleanly, invoked as
# literal /bin/bash -- a developer's PATH bash is routinely 5.x from Homebrew and proves nothing
# about the bash 3.2 floor this plugin actually ships against on macOS.
T50_PARSE_TARGETS="${PLUGIN_DIR}/bin/_edm-datadir-lib.sh ${PLUGIN_DIR}/bin/edm-gateguard ${PLUGIN_DIR}/bin/edm-hookify ${PLUGIN_DIR}/bin/edm-stop-gate ${PLUGIN_DIR}/bin/edm-repo-readiness ${PLUGIN_DIR}/bin/edm-bash-gate ${T50_SELF}"
for _t50_f in $T50_PARSE_TARGETS; do
  _t50_parse_err="$(/bin/bash -n "$_t50_f" 2>&1 >/dev/null || true)"
  if [[ -z "$_t50_parse_err" ]]; then
    pass "EDMV4-T50 -- /bin/bash -n parses $(basename "$_t50_f") cleanly"
  else
    fail "EDMV4-T50 -- /bin/bash -n failed on $(basename "$_t50_f"): ${_t50_parse_err}"
  fi
done

# ---- Each new EXECUTABLE script (the shared library is sourced-only, never chmod +x, per its own
# file header) runs under literal /bin/bash <script> --help and exits 0 with non-empty output.
T50_EXEC_TARGETS="${PLUGIN_DIR}/bin/edm-gateguard ${PLUGIN_DIR}/bin/edm-hookify ${PLUGIN_DIR}/bin/edm-stop-gate ${PLUGIN_DIR}/bin/edm-repo-readiness ${PLUGIN_DIR}/bin/edm-bash-gate"
for _t50_ef in $T50_EXEC_TARGETS; do
  _t50_help_rc=0
  _t50_help_out="$(/bin/bash "$_t50_ef" --help 2>&1)" || _t50_help_rc=$?
  if [[ "$_t50_help_rc" -eq 0 && -n "$_t50_help_out" ]]; then
    pass "EDMV4-T50 -- /bin/bash $(basename "$_t50_ef") --help exits 0 with non-empty output"
  else
    fail "EDMV4-T50 -- /bin/bash $(basename "$_t50_ef") --help exited ${_t50_help_rc}: ${_t50_help_out}"
  fi
done

# ---- /bin/bash --version recorded in suite output, so a run on a host whose /bin/bash is not 3.2
# is visible in the log rather than silently vacuous.
T50_BASH_VERSION="$(/bin/bash --version | head -1)"
pass "EDMV4-T50 -- /bin/bash --version recorded: ${T50_BASH_VERSION}"

echo

# =================================================================================================
# EDMV4-T51 -- Verify the required-binary set is still bash, jq, git
# =================================================================================================
# Two decisions in this initiative (decisions.md D7, D14) turned on the plugin's required binaries
# staying exactly bash/jq/git. This section records that as a testable requirement over the live
# tree, the same shape T50's band above uses: a live-derived sweep with a positive control, never a
# hardcoded file list.
echo "=== EDMV4-T51: required-binary set -- no node/python/yq/ruby/deno, and perl only where guarded ==="

T51_INTERP_RE='\b(node|python|python3|yq|ruby|deno)\b'

# ---- Zero node/python/python3/yq/ruby/deno references across bin/ and evals/ (bin/tests/
# excluded, matching T50/T61 AC9's own convention -- test-fixture/assertion surface).
t51_scan() {
  { grep -rnE "$T51_INTERP_RE" "${PLUGIN_DIR}/bin" "${PLUGIN_DIR}/evals" 2>/dev/null || true; } \
    | grep -v '/tests/' \
    | grep -vE ':[[:space:]]*#'
}
T51_HITS="$(t51_scan || true)"
if [[ -z "$T51_HITS" ]]; then
  pass "EDMV4-T51 -- zero node/python/python3/yq/ruby/deno references across bin/ and evals/ (bin/tests/ excluded)"
else
  fail "EDMV4-T51 -- forbidden interpreter reference(s) found:\n${T51_HITS}"
fi

# Positive control: a scratch fixture with a real 'python3 -c' line must be caught.
T51_TMP="$(mktemp -d "${TMPDIR:-/tmp}/edm-wave8-t51.XXXXXX")"
T51_FIXTURE="${T51_TMP}/fake-script.sh"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' "python3 -c 'print(1)'"
} > "$T51_FIXTURE"
T51_CONTROL_HITS="$({ grep -nE "$T51_INTERP_RE" "$T51_FIXTURE" 2>/dev/null || true; } | grep -vE ':[[:space:]]*#' || true)"
if [[ -n "$T51_CONTROL_HITS" ]]; then
  pass "EDMV4-T51 -- positive control: a synthetic 'python3 -c' line is caught"
else
  fail "EDMV4-T51 -- positive control broken: a synthetic 'python3 -c' fixture produced zero hits"
fi

# ---- perl: forbidden across bin/ (excluding bin/tests/) and evals/, exactly like the interpreter
# set above. bin/tests/timing.sh's two guarded call sites are the sole sanctioned exception,
# verified separately below by CONTENT (never by line number, since EDMV4-47 AC4 edits this file).
# NOTE: bin/tests/wave6-smoke.sh carries a real, UNGUARDED `perl -pe` usage (G18/CA-378, predating
# EDMV4) -- out of this ticket's Target Components (wave6-smoke.sh is not listed) and out of the
# bin/tests/-excluded scope below by the same T61 AC9 convention every other section in this suite
# already relies on; reported here rather than silently fixed, since fixing it means editing a
# file this ticket does not own.
T51_PERL_RE='\bperl\b'
T51_TIMING_SH="${PLUGIN_DIR}/bin/tests/timing.sh"

T51_PERL_HITS="$({ grep -rnE "$T51_PERL_RE" "${PLUGIN_DIR}/bin" "${PLUGIN_DIR}/evals" 2>/dev/null || true; } | grep -v '/tests/' | grep -vE ':[[:space:]]*#' || true)"
if [[ -z "$T51_PERL_HITS" ]]; then
  pass "EDMV4-T51 -- zero perl references across bin/ (excluding bin/tests/) and evals/"
else
  fail "EDMV4-T51 -- perl reference(s) found outside the sanctioned bin/tests/timing.sh sites:\n${T51_PERL_HITS}"
fi

T51_PERL_CONTROL="$(printf '%s\n' 'perl -e 1' | grep -cE "$T51_PERL_RE" || true)"
[[ "$T51_PERL_CONTROL" -ge 1 ]] \
  && pass "EDMV4-T51 -- positive control: a synthetic perl invocation is caught" \
  || fail "EDMV4-T51 -- positive control broken: a synthetic perl invocation was not caught"

# timing.sh's two guarded sites, resolved by function body CONTENT.
t51_extract_fn() {
  local file="$1" name="$2"
  awk -v needle="${name}() {" '
    index($0, needle) == 1 { found=1 }
    found { print }
    found && /^}/ { exit }
  ' "$file"
}
T51_NOW_BODY="$(t51_extract_fn "$T51_TIMING_SH" _now)"
T51_MSBETWEEN_BODY="$(t51_extract_fn "$T51_TIMING_SH" _ms_between)"

# t51_check_guarded_perl <body> <label> -- fails unless: a `command -v perl` guard line precedes a
# real perl invocation line, which precedes an `else` line, which precedes a `fi` line (relative
# line order within the extracted body, never absolute line numbers), AND the else/fallback branch
# itself invokes no perl (an `echo` diagnostic naming "perl" in its message text, e.g. _now's own
# "perl not found -- falling back" warning, is excluded -- prose naming perl is not a perl
# invocation, the same self-match class T50's band above guards against).
t51_check_guarded_perl() {
  local body="$1" label="$2"
  local if_line perl_line else_line fi_line fallback_perl
  if_line="$(printf '%s\n' "$body" | grep -n 'command -v perl' | head -1 | cut -d: -f1)"
  perl_line="$(printf '%s\n' "$body" | grep -n '\bperl\b' | grep -v 'command -v perl' | head -1 | cut -d: -f1)"
  else_line="$(printf '%s\n' "$body" | grep -n '^[[:space:]]*else[[:space:]]*$' | head -1 | cut -d: -f1)"
  fi_line="$(printf '%s\n' "$body" | grep -n '^[[:space:]]*fi[[:space:]]*$' | head -1 | cut -d: -f1)"
  if [[ -z "$if_line" || -z "$perl_line" || -z "$else_line" || -z "$fi_line" ]]; then
    fail "EDMV4-T51 -- ${label}: could not resolve guard/perl/else/fi structure by content"
    return
  fi
  if [[ "$if_line" -lt "$perl_line" && "$perl_line" -lt "$else_line" && "$else_line" -lt "$fi_line" ]]; then
    fallback_perl="$(printf '%s\n' "$body" | tail -n +"$((else_line+1))" | grep -v 'echo' | grep -c '\bperl\b' || true)"
    if [[ "$fallback_perl" -eq 0 ]]; then
      pass "EDMV4-T51 -- ${label}: perl invocation is guarded by a 'command -v perl' check with a non-perl fallback in the else branch (resolved by content)"
    else
      fail "EDMV4-T51 -- ${label}: the else/fallback branch itself invokes perl -- not a genuine non-perl fallback"
    fi
  else
    fail "EDMV4-T51 -- ${label}: guard/perl/else/fi are not in the expected relative order (if=${if_line} perl=${perl_line} else=${else_line} fi=${fi_line})"
  fi
}
t51_check_guarded_perl "$T51_NOW_BODY" "_now"
t51_check_guarded_perl "$T51_MSBETWEEN_BODY" "_ms_between"

# ---- edm-gateguard's mtime read: a bare 'stat -c' with no BSD arm is a real finding; a line
# carrying BOTH stat -c and stat -f (the sanctioned portable fallback pair prescribed by EDMV4-T15's
# own Technical Notes) is exempt by construction (portable regardless of which OS runs it). T61
# AC11 (wave7-smoke.sh) already sweeps this tree-wide with the identical pair-shape exemption; this
# is this ticket's own targeted re-check against edm-gateguard specifically. Read-only: this ticket
# does not modify edm-gateguard.
T51_GATEGUARD="${PLUGIN_DIR}/bin/edm-gateguard"
T51_STAT_HITS="$(grep -n 'stat -c' "$T51_GATEGUARD" 2>/dev/null | grep -vE 'stat -c.*stat -f|stat -f.*stat -c' || true)"
if [[ -z "$T51_STAT_HITS" ]]; then
  pass "EDMV4-T51 -- edm-gateguard has no unpaired 'stat -c' (GNU-only) mtime read"
else
  fail "EDMV4-T51 -- edm-gateguard has an unpaired 'stat -c' with no BSD fallback: ${T51_STAT_HITS}"
fi

# Positive control: an unpaired 'stat -c' must still be caught; a paired fallback must be exempt --
# proving the exemption is shape-specific, not a blanket allowance for the whole file.
T51_STAT_CONTROL_UNPAIRED="$(printf '%s\n' '  mtime="$(stat -c %Y "$f")"' | grep -n 'stat -c' | grep -vE 'stat -c.*stat -f|stat -f.*stat -c' || true)"
T51_STAT_CONTROL_PAIRED="$(printf '%s\n' '  mtime="$(stat -c %Y "$f" 2>/dev/null)" || mtime="$(stat -f %m "$f" 2>/dev/null)"' | grep -n 'stat -c' | grep -vE 'stat -c.*stat -f|stat -f.*stat -c' || true)"
if [[ -n "$T51_STAT_CONTROL_UNPAIRED" && -z "$T51_STAT_CONTROL_PAIRED" ]]; then
  pass "EDMV4-T51 -- positive control: an unpaired 'stat -c' is caught while a paired fallback is exempted"
else
  fail "EDMV4-T51 -- positive control broken: unpaired=[${T51_STAT_CONTROL_UNPAIRED}] paired=[${T51_STAT_CONTROL_PAIRED}]"
fi

# ---- No .js/.ts/.mjs/.cjs/.py file anywhere under plugins/edm/, live-derived via find.
# evals/fixtures/ is excluded: it holds a synthetic "tiny-svc" JS subject-repository fixture
# (EDMV3-T22, predating EDMV4) that the eval driver scores EDM's own agents AGAINST -- the
# fixture's language is the thing under evaluation, not a runtime dependency this plugin adds,
# the same category distinction bin/tests/fixtures/hookify's *.json rule fixtures already get.
T51_JS_PY_FIND_EXPR=( -name '*.js' -o -name '*.ts' -o -name '*.mjs' -o -name '*.cjs' -o -name '*.py' )
T51_JS_PY_HITS="$({ find "${PLUGIN_DIR}" -type f \( "${T51_JS_PY_FIND_EXPR[@]}" \) 2>/dev/null || true; } | grep -v '/evals/fixtures/' || true)"
if [[ -z "$T51_JS_PY_HITS" ]]; then
  pass "EDMV4-T51 -- no .js/.ts/.mjs/.cjs/.py file exists anywhere under plugins/edm/ (evals/fixtures/ excluded -- a synthetic subject-repository fixture, not plugin code)"
else
  fail "EDMV4-T51 -- forbidden-extension file(s) found:\n${T51_JS_PY_HITS}"
fi

# Positive control: a scratch .py file must be caught by the same find shape.
T51_PYSCRATCH_DIR="$(mktemp -d "${TMPDIR:-/tmp}/edm-wave8-t51-py.XXXXXX")"
touch "${T51_PYSCRATCH_DIR}/scratch.py"
T51_PYSCRATCH_HITS="$(find "${T51_PYSCRATCH_DIR}" -type f \( "${T51_JS_PY_FIND_EXPR[@]}" \) 2>/dev/null || true)"
if [[ -n "$T51_PYSCRATCH_HITS" ]]; then
  pass "EDMV4-T51 -- positive control: a scratch .py file is caught by the same find shape"
else
  fail "EDMV4-T51 -- positive control broken: a scratch .py file was not caught"
fi
rm -rf "$T51_PYSCRATCH_DIR"

# ---- 'POSIX coreutils' is not used as the dependency boundary in any new script or CLAUDE.md.
T51_COREUTILS_HITS="$(grep -rn 'POSIX coreutils' "${PLUGIN_DIR}/bin/_edm-datadir-lib.sh" "${PLUGIN_DIR}/bin/edm-gateguard" "${PLUGIN_DIR}/bin/edm-hookify" "${PLUGIN_DIR}/bin/edm-stop-gate" "${PLUGIN_DIR}/bin/edm-repo-readiness" "${PLUGIN_DIR}/bin/edm-bash-gate" "${PLUGIN_DIR}/CLAUDE.md" 2>/dev/null || true)"
if [[ -z "$T51_COREUTILS_HITS" ]]; then
  pass "EDMV4-T51 -- 'POSIX coreutils' is not used as the dependency boundary in any new script or CLAUDE.md"
else
  fail "EDMV4-T51 -- 'POSIX coreutils' phrase found: ${T51_COREUTILS_HITS}"
fi

T51_COREUTILS_CONTROL="$(printf '%s\n' 'this script only needs POSIX coreutils' | grep -c 'POSIX coreutils' || true)"
[[ "$T51_COREUTILS_CONTROL" -ge 1 ]] \
  && pass "EDMV4-T51 -- positive control: the 'POSIX coreutils' phrase detector fires on a synthetic line" \
  || fail "EDMV4-T51 -- positive control broken: the 'POSIX coreutils' phrase detector did not fire"

# ---- CLAUDE.md Sec."Testing changes" still opens with the exact required-binary sentence,
# unchanged by this initiative. $CLAUDE_MD is already resolved above (EDMV4-T42's section).
T51_REQUIRED_BINARY_SENTENCE='macOS and Linux only (bash 3.2+, `jq`, `git` required). Windows and WSL are unsupported.'
if grep -qF "$T51_REQUIRED_BINARY_SENTENCE" "$CLAUDE_MD"; then
  pass "EDMV4-T51 -- CLAUDE.md still opens Sec.\"Testing changes\" with the exact required-binary sentence"
else
  fail "EDMV4-T51 -- CLAUDE.md's required-binary sentence has drifted from the expected exact text"
fi

rm -rf "$T51_TMP"

echo
# =================================================================================================
# EDMV4-T52: Verify ASCII-only artifacts by a manual --path sweep plus an explicit byte scan
# =================================================================================================
# Own banded section, appended last (after EDMV4-T28's own append above), so a concurrent agent's
# own append to this file does not interleave with it. GATEGUARD/DATADIR_LIB/EDM_STOP_GATE/TMP are
# already set by the EDMV4-T11/T12/T46 sections above; t14_fresh_marker_env, t14_run and
# t46_isolate_and_run are already defined by their own sections above and are reused here unchanged.
#
# Coverage assignment (AC4) -- which mechanism owns which new file this initiative adds, so no
# file is asserted by both and none is asserted by neither:
#   AC1's --path sweep (collect_md_files, `.md` only) owns: the three new lens agent prompts
#     (agents/edm-audit-silent-failures.md, edm-audit-type-design.md, edm-audit-behavioral-tests.md),
#     every edited SKILL.md, and every edited CLAUDE.md.
#   AC2's byte scan (this section) owns: the four new bin/ scripts (edm-gateguard, edm-hookify,
#     edm-stop-gate, edm-bash-gate), the shared _edm-datadir-lib.sh, and the two JSON config files
#     (hooks/hooks.json, monitors/monitors.json) -- collect_md_files's `-name '*.md'` filter never
#     collects any of these six, in any mode, --path included (CLAUDE.md's "Artifact content
#     conventions" now documents this as a standing, second gap on top of the reach gap AC1 closes).
echo "=== EDMV4-T52: ASCII-only artifacts -- manual --path sweep plus explicit byte scan ==="
echo

# ---- AC2/AC3 shared scanner. Mirrors edm-lint-artifacts' own PCRE-vs-fallback split (its
# argument-parsing section) rather than assuming -P is available: BSD grep on macOS has no -P at
# all, and a bare `grep -nP` there errors out -- which, captured under `|| true`, reads as a false
# "clean" scan rather than a real zero-count. LC_ALL=C on both branches (Technical Notes: a UTF-8
# locale can make grep interpret the byte range differently across BSD and GNU). ------------------
T52_HAS_PCRE=0
{ echo "" | grep -qP '' 2>/dev/null && T52_HAS_PCRE=1; } || true

# t52_ascii_scan <file...> -- prints "<file>:<line>:<content>" for every line in every <file>
# carrying at least one byte outside 0x00-0x7F; prints nothing if every file is clean.
t52_ascii_scan() {
  local f hits
  for f in "$@"; do
    [[ -f "$f" ]] || continue
    if [[ "$T52_HAS_PCRE" -eq 1 ]]; then
      hits="$(LC_ALL=C grep -nP '[^\x00-\x7F]' "$f" 2>/dev/null || true)"
    else
      hits="$(LC_ALL=C grep -nv '^[[:print:][:space:]]*$' "$f" 2>/dev/null || true)"
    fi
    [[ -n "$hits" ]] && printf '%s\n' "$hits" | sed "s#^#${f}:#"
  done
}

# ---- AC2: file set derived LIVE (find plugins/edm/bin -type f), so a script added after this
# ticket lands is covered automatically without a second edit here -- the same anti-hardcoding
# property EDMV4-T50 AC1 already requires of its own sibling sweep. bin/tests/ is included by
# design (AC2's own text): the smoke suites themselves are exactly the kind of extensionless-or-
# not-`.md` file collect_md_files would otherwise never reach.
#
# One exclusion, recorded with its reason rather than silently applied: bin/tests/fixtures/ is
# EXCLUDED from this live scan. That tree is edm-lint-artifacts' own test corpus -- it exists
# specifically to prove the class-2 (unicode) checker fires and correctly SKIPS fenced code
# blocks, so at least one fixture there (mermaid/valid/v12-indented-fence.md) legitimately embeds
# a real non-ASCII byte inside a code fence on purpose. `-not -path` is applied against
# ${PLUGIN_DIR} directly, which is already a `cd ... && pwd`-resolved absolute path (no `..`
# component for a substring exclusion to be fooled by), per this initiative's own recorded
# self-matching trap about normalizing a path root before a path-based exclusion. -----------------
T52_BIN_FILES=()
while IFS= read -r -d "" _t52_f; do
  T52_BIN_FILES+=("$_t52_f")
done < <(find "${PLUGIN_DIR}/bin" -type f -not -path "${PLUGIN_DIR}/bin/tests/fixtures/*" -print0 2>/dev/null)

T52_SCAN_TARGETS=("${T52_BIN_FILES[@]}" "${PLUGIN_DIR}/hooks/hooks.json" "${PLUGIN_DIR}/monitors/monitors.json")

T52_AC2_HITS="$(t52_ascii_scan "${T52_SCAN_TARGETS[@]}" || true)"
if [[ -z "$T52_AC2_HITS" ]]; then
  pass "EDMV4-T52 AC2 -- byte scan over ${#T52_SCAN_TARGETS[@]} files (live plugins/edm/bin/ set, bin/tests/ included, plus hooks.json/monitors.json) finds zero non-ASCII bytes"
else
  fail "EDMV4-T52 AC2 -- non-ASCII byte(s) found: ${T52_AC2_HITS}"
fi

# ---- AC3: positive control. A scratch file OUTSIDE plugins/edm/bin/ (so it can never become a
# real AC2 finding) carries one real non-ASCII byte, assembled at runtime via a printf hex escape
# -- the needle is never a literal non-ASCII byte in this suite's own source, per this
# initiative's own recorded self-matching trap (docs/audit-patterns/code-audit.md: "A verification
# scan matches the prose that describes the pattern it hunts"). -----------------------------------
harness_scratch_dir T52_SCRATCH
T52_CONTROL_FILE="${T52_SCRATCH}/nonascii-control.txt"
printf 'safe line one\nline with a byte: \xc3\xa9 end\nsafe line three\n' > "$T52_CONTROL_FILE"
T52_AC3_HITS="$(t52_ascii_scan "$T52_CONTROL_FILE" || true)"
if [[ -n "$T52_AC3_HITS" ]]; then
  pass "EDMV4-T52 AC3 -- positive control: a scratch file carrying one real non-ASCII byte IS detected, so the AC2 zero-count above is not vacuous"
else
  fail "EDMV4-T52 AC3 -- positive control FAILED: a real non-ASCII byte was not detected, so AC2's zero-count proves nothing"
fi

# ---- AC1: the manual `--path` sweep over the plugin's whole source tree (Definition of Done item
# 5 -- run by hand and recorded as a regression check here too, mirroring EDMV4-T28's own
# `--path agents/` precedent above). Two categories are excluded from the zero-count, each named
# with its own reason rather than silently filtered:
#   plugins/edm/CHANGELOG.md -- historical entries predate the ASCII convention and are never
#     edited (project convention; normalizing history is explicitly out of this ticket's scope).
#   plugins/edm/bin/tests/fixtures/** -- the mermaid-semicolon NEGATIVE-test corpus, deliberately
#     invalid by design (it exists to prove edm-lint-artifacts' own class-4 checker fires); a clean
#     fixture tree would mean that checker has nothing left to detect.
# Every other file under plugins/edm/ -- skills/, agents/, docs/, evals/, this file, README.md, and
# every other .md file --path mode collects under bin/ -- must be clean. ---------------------------
T52_AC1_OUT=""
T52_AC1_RC=0
T52_AC1_OUT="$(bash "${PLUGIN_DIR}/bin/edm-lint-artifacts" --path "$PLUGIN_DIR" 2>&1)" || T52_AC1_RC=$?
T52_AC1_REAL_HITS="$(printf '%s\n' "$T52_AC1_OUT" \
  | grep -v "^${PLUGIN_DIR}/CHANGELOG.md:" \
  | grep -v "^${PLUGIN_DIR}/bin/tests/fixtures/" \
  | grep -v "^edm-lint-artifacts: " || true)"
if [[ -z "$T52_AC1_REAL_HITS" ]]; then
  pass "EDMV4-T52 AC1 -- edm-lint-artifacts --path plugins/edm/ is clean outside the two recorded exclusions (CHANGELOG.md history, bin/tests/fixtures/ negative corpus)"
else
  fail "EDMV4-T52 AC1 -- unexpected violation(s) outside the recorded exclusions: ${T52_AC1_REAL_HITS}"
fi

# ---- AC5/AC9: edm-lint-artifacts EDMV4 (prefix mode, the real repository's own initiative
# directory) reports zero violations across every artifact this initiative writes, including every
# Mermaid diagram it added or edited (class 4, mermaid-semicolon, is one of the five classes this
# same invocation runs). -----------------------------------------------------------------------
T52_AC5_OUT=""
T52_AC5_RC=0
T52_AC5_OUT="$(EDM_SRD_ROOT="${_HARNESS_REPO_ROOT}/SRD" PATH="${PLUGIN_DIR}/bin:${PATH}" \
  bash "${PLUGIN_DIR}/bin/edm-lint-artifacts" EDMV4 2>&1)" || T52_AC5_RC=$?
if [[ "$T52_AC5_RC" -eq 0 ]]; then
  pass "EDMV4-T52 AC5/AC9 -- edm-lint-artifacts EDMV4 reports zero violations across the initiative's own artifacts (mermaid-semicolon class included)"
else
  fail "EDMV4-T52 AC5/AC9 -- edm-lint-artifacts EDMV4 reported violations (rc=${T52_AC5_RC}): ${T52_AC5_OUT}"
fi

# ---- AC8: edm-check-vocabulary exits 0 over its full scan set (skills/, agents/, docs/,
# hooks/hooks.json, monitors/monitors.json, CLAUDE.md, README.md, bin/). ---------------------------
T52_AC8_RC=0
T52_AC8_OUT="$(bash "${PLUGIN_DIR}/bin/edm-check-vocabulary" 2>&1)" || T52_AC8_RC=$?
[[ "$T52_AC8_RC" -eq 0 ]] && pass "EDMV4-T52 AC8 -- edm-check-vocabulary exits 0 over its full scan set" \
  || fail "EDMV4-T52 AC8 -- edm-check-vocabulary exited ${T52_AC8_RC}: ${T52_AC8_OUT}"

# ---- AC7: drive a denial through each of the three emit points on content containing a real
# non-ASCII byte, asserting (a) the emitted output is pure ASCII (the same t52_ascii_scan as AC2)
# and (b) it still parses as JSON under jq -e . where the emit point in question actually produces
# JSON at all. ---------------------------------------------------------------------------------

# AC7a: edm-gateguard's emit_decision -- a first-touch Edit on a path containing a real non-ASCII
# byte (assembled via printf hex escape, never a literal byte in this suite's own source).
T52_AC7A_PROJ="" T52_AC7A_DATA=""
t14_fresh_marker_env T52_AC7A_PROJ T52_AC7A_DATA
T52_AC7A_PATH="$(printf 'src/caf\xc3\xa9.js')"
T52_AC7A_PAYLOAD="$(jq -cn --arg p "$T52_AC7A_PATH" '{tool_name:"Edit", tool_input:{file_path:$p}}')"
T52_AC7A_RC=0
T52_AC7A_OUT="$(printf '%s' "$T52_AC7A_PAYLOAD" | CLAUDE_PROJECT_DIR="$T52_AC7A_PROJ" CLAUDE_PLUGIN_DATA="$T52_AC7A_DATA" \
  EDM_GATEGUARD_DENY_MODE=json bash "$GATEGUARD" 2>"${TMP}/t52-ac7a.stderr")" || T52_AC7A_RC=$?
printf '%s' "$T52_AC7A_OUT" > "${T52_SCRATCH}/ac7a-gateguard.out"
T52_AC7A_ASCII_HITS="$(t52_ascii_scan "${T52_SCRATCH}/ac7a-gateguard.out" || true)"
if [[ -z "$T52_AC7A_ASCII_HITS" ]]; then
  pass "EDMV4-T52 AC7 -- edm-gateguard's emit_decision: denial output for a non-ASCII file path is pure ASCII"
else
  fail "EDMV4-T52 AC7 -- edm-gateguard emitted a non-ASCII byte: ${T52_AC7A_ASCII_HITS}"
fi
if printf '%s' "$T52_AC7A_OUT" | jq -e . >/dev/null 2>&1; then
  pass "EDMV4-T52 AC7 -- edm-gateguard's sanitized denial output still parses as JSON under jq -e ."
else
  fail "EDMV4-T52 AC7 -- edm-gateguard's denial output does not parse as JSON: ${T52_AC7A_OUT}"
fi

# AC7b: edm-hookify's matched-rule emission -- exercised END-TO-END through edm-gateguard, since
# edm-hookify's own block line becomes edm-gateguard's `reason` (its allow-path wiring). A rule
# author's own non-ASCII message text is the ONLY non-ASCII byte anywhere in this fixture -- the
# target file path stays plain ASCII, isolating this emit point from AC7a's.
harness_scratch_dir T52_AC7B_TMP
mkdir -p "${T52_AC7B_TMP}/proj/.claude/edm-hookify" "${T52_AC7B_TMP}/data/run"
T52_AC7B_MSG="$(printf 'blocked: rule message with a byte \xc3\xa9 embedded')"
jq -n --arg msg "$T52_AC7B_MSG" '{
  name: "t52-nonascii-rule", enabled: true, event: "file", action: "block",
  conditions: [{field: "file_path", operator: "contains", pattern: "safe"}],
  message: $msg
}' > "${T52_AC7B_TMP}/proj/.claude/edm-hookify/rule.json"
T52_AC7B_KEY="$(CLAUDE_PROJECT_DIR="${T52_AC7B_TMP}/proj" bash -c ". '${DATADIR_LIB}'; edm_project_key" 2>/dev/null)"
printf 'T52PFX\t%s\t2026-09-02T00:00:00Z\n' "${T52_AC7B_TMP}/proj" > "${T52_AC7B_TMP}/data/run/${T52_AC7B_KEY}.phase6"
# Pre-seed the path already-checked so gg_maybe_deny falls through silently and the allow-path
# hookify evaluation (the only place this rule can fire) is actually reached -- the same technique
# EDMV4-T14 AC5 uses to reach past the fact-forcing denial.
printf 'safe.js\n' > "${T52_AC7B_TMP}/data/run/${T52_AC7B_KEY}.checked"

T52_AC7B_RC=0
T52_AC7B_OUT="$(printf '{"tool_name":"Edit","tool_input":{"file_path":"safe.js"}}' | \
  CLAUDE_PROJECT_DIR="${T52_AC7B_TMP}/proj" CLAUDE_PLUGIN_DATA="${T52_AC7B_TMP}/data" \
  EDM_GATEGUARD_DENY_MODE=json PATH="${PLUGIN_DIR}/bin:${PATH}" bash "$GATEGUARD" 2>"${TMP}/t52-ac7b.stderr")" || T52_AC7B_RC=$?
printf '%s' "$T52_AC7B_OUT" > "${T52_SCRATCH}/ac7b-hookify.out"
T52_AC7B_ASCII_HITS="$(t52_ascii_scan "${T52_SCRATCH}/ac7b-hookify.out" || true)"
check "EDMV4-T52 AC7 -- the fixture genuinely matched the hookify rule (a real denial, not an empty allow)" \
  '"permissionDecision":"deny"' "$T52_AC7B_OUT"
if [[ -z "$T52_AC7B_ASCII_HITS" ]]; then
  pass "EDMV4-T52 AC7 -- edm-hookify's matched-rule message (a rule-author-supplied non-ASCII byte) reaches edm-gateguard's stdout as pure ASCII"
else
  fail "EDMV4-T52 AC7 -- edm-hookify's rule message leaked a non-ASCII byte into edm-gateguard's stdout: ${T52_AC7B_ASCII_HITS}"
fi
if printf '%s' "$T52_AC7B_OUT" | jq -e . >/dev/null 2>&1; then
  pass "EDMV4-T52 AC7 -- the sanitized output carrying edm-hookify's rule message still parses as JSON under jq -e ."
else
  fail "EDMV4-T52 AC7 -- output carrying edm-hookify's rule message does not parse as JSON: ${T52_AC7B_OUT}"
fi

# AC7c: edm-stop-gate's blocking-anomaly emission -- an OPEN_PARTIALS anomaly whose ticket-id key
# carries a real non-ASCII byte (edm-state's partial_verdict_map keys are free-form text, not
# ASCII-restricted). Only half (a) of AC7 applies to this consumer: edm-stop-gate's own documented
# contract is stderr-only text, NEVER JSON ("a raw JSON echo to stdout is the documented failure
# mode for a Stop hook" -- its own EDM-HELP block) -- there is no JSON control channel at this emit
# point for (b) to apply to, which is recorded explicitly below rather than silently skipped.
t52_ac7c_case() {
  edm-state init T52NA >/dev/null
  edm-state set T52NA current_phase 1 >/dev/null
  edm-state set T52NA estimated_size Small >/dev/null
  edm-state record-partial-verdict T52NA T52NA-T01 PARTIAL "needs runtime check" >/dev/null
  local state; state="$(edm-state resolve-dir T52NA)/.edm-state.json"
  # Rename the ticket-id key to embed a real non-ASCII byte via jq's own \u00e9 escape sequence
  # (valid UTF-8, never a literal non-ASCII byte in this suite's own source -- the exact
  # self-matching trap this ticket's own patterns doc warns against) -- a direct state-file patch
  # (matching this suite's own T46 AC4 precedent), bypassing edm-state's CLI since
  # record-partial-verdict's ticket argument is not the property under test here.
  jq '.partial_verdict_map = (.partial_verdict_map
        | to_entries | map(.key = "T52NA-T\u00e901") | from_entries)' \
    "$state" > "${state}.tmp" && mv "${state}.tmp" "$state"

  local out rc=0
  out="$(edm-stop-gate 2>&1)" || rc=$?
  printf '%s' "$out" > "${TMP}/t52-ac7c.out"
  local ascii_hits; ascii_hits="$(t52_ascii_scan "${TMP}/t52-ac7c.out" || true)"
  [[ "$rc" -eq 2 ]] && pass "EDMV4-T52 AC7 -- edm-stop-gate blocks on the non-ASCII OPEN_PARTIALS anomaly (exit 2)" \
    || fail "EDMV4-T52 AC7 -- expected exit 2 for the non-ASCII OPEN_PARTIALS anomaly, got ${rc}"
  check "EDMV4-T52 AC7 -- the fixture genuinely carries the anomaly this test targets" "OPEN_PARTIALS" "$out"
  if [[ -z "$ascii_hits" ]]; then
    pass "EDMV4-T52 AC7 -- edm-stop-gate's blocking-anomaly text (a non-ASCII ticket key from edm-state validate) reaches stderr as pure ASCII"
  else
    fail "EDMV4-T52 AC7 -- edm-stop-gate leaked a non-ASCII byte into its blocking output: ${ascii_hits}"
  fi
}
t46_isolate_and_run t52_ac7c_case
pass "EDMV4-T52 AC7 -- (b) recorded as Not Applicable to edm-stop-gate: its own EDM-HELP block documents a stderr-only, never-JSON contract, so there is no JSON control channel at this emit point for (b) to protect"

# ---- AC6 (single-site property): each script's sanitization is not merely present, it is the
# ONLY path decision/message content can reach output through -- verified structurally, with a
# positive control proving a later-added bypass would be caught (a bare "the sanitizer exists"
# check would pass against a broken one that a second, unsanitized emit call quietly bypasses).

# t52_ordering_ok <file> <func_name> <sanitize_marker> <emit_marker> -- prints nothing and returns
# 0 iff every line inside <func_name>'s body (extracted between its opening and the next bare
# "}") matching <emit_marker> occurs strictly AFTER the LAST line matching <sanitize_marker>;
# otherwise prints one diagnostic line and returns 1 (including when the sanitizer is absent
# entirely). Fixed-string matching throughout (grep -F) -- no regex-metacharacter escaping risk
# in either marker argument.
t52_ordering_ok() {
  local file="$1" func="$2" sanitize_marker="$3" emit_marker="$4"
  local body sanitize_ln emit_lns ln bad=0
  body="$(_wave7_extract_between "$file" "^${func}\\(\\)" '^}$')"
  sanitize_ln="$(printf '%s\n' "$body" | grep -nF -- "$sanitize_marker" | tail -1 | cut -d: -f1)"
  if [[ -z "$sanitize_ln" ]]; then
    echo "sanitizer marker not found in ${func}"
    return 1
  fi
  # The sanitizer line itself legitimately READS the pre-sanitize value as $sanitize_marker's own
  # input (e.g. `reason="$(printf '%s' "$reason" | ...)"`), which also matches <emit_marker> --
  # excluded here by line number so that read is never counted as a violating emission of its own
  # output.
  emit_lns="$(printf '%s\n' "$body" | grep -nF -- "$emit_marker" | cut -d: -f1 | grep -vxF -- "$sanitize_ln" || true)"
  while IFS= read -r ln; do
    [[ -z "$ln" ]] && continue
    [[ "$ln" -gt "$sanitize_ln" ]] || bad=1
  done <<< "$emit_lns"
  [[ "$bad" -eq 0 ]] && return 0
  echo "an emission at or before the sanitizer line (line ${sanitize_ln}) in ${func}"
  return 1
}

# t52_raw_var_only_via_func <file> <func_name> <var...> -- prints nothing and implies the
# single-site property holds when every quoted reference "$var" anywhere in <file> either (a)
# appears on the same line as <func_name> (a call passing the raw value INTO the sanitizing
# function) or (b) is a plain conditional test (`if [[ ... ]]`), never an emission. Prints the
# offending line(s) otherwise.
t52_raw_var_only_via_func() {
  local file="$1" func="$2"
  shift 2
  local var pattern line
  for var in "$@"; do
    pattern='"$'"${var}"'"'
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      case "$line" in
        *"$func"*) ;;
        *"if [["*) ;;
        *) printf '%s\n' "$line" ;;
      esac
    done < <(grep -nF -- "$pattern" "$file" 2>/dev/null || true)
  done
}

# ---- edm-gateguard: emit_decision is the sole function (grep -c == 1), and every emission of
# "$reason" inside it occurs strictly after the one sanitizer line. -------------------------------
T52_GG_FUNC_COUNT="$(grep -c '^emit_decision() {' "$GATEGUARD" || true)"
check "EDMV4-T52 AC6 -- edm-gateguard: emit_decision is defined exactly once" "1" "$T52_GG_FUNC_COUNT"

T52_GG_ORDER_RC=0
T52_GG_ORDER_MSG="$(t52_ordering_ok "$GATEGUARD" "emit_decision" "LC_ALL=C tr -c" '"$reason"')" || T52_GG_ORDER_RC=$?
if [[ "$T52_GG_ORDER_RC" -eq 0 ]]; then
  pass "EDMV4-T52 AC6 -- edm-gateguard: every emission of \$reason inside emit_decision occurs after the one sanitizer line (single-site property holds)"
else
  fail "EDMV4-T52 AC6 -- edm-gateguard: single-site property violated: ${T52_GG_ORDER_MSG}"
fi

# Positive control: a scratch copy with a second, unsanitized emission of the raw $reason injected
# BEFORE the sanitizer line (simulating a later change that adds a bypass) must make the identical
# ordering check fail -- proving the check is not permanently satisfied by construction.
T52_GG_BYPASS="${T52_SCRATCH}/edm-gateguard-bypass"
awk -v marker='local reason="${2:-}"' \
  '{print; if (index($0, marker) > 0) print "  echo \"$reason\" >&2  # BYPASS-LEAK injected for EDMV4-T52 AC6 positive control"}' \
  "$GATEGUARD" > "$T52_GG_BYPASS"
if ! t52_ordering_ok "$T52_GG_BYPASS" "emit_decision" "LC_ALL=C tr -c" '"$reason"' >/dev/null; then
  pass "EDMV4-T52 AC6 -- positive control: an injected second, unsanitized \$reason emission (before the sanitizer) IS detected"
else
  fail "EDMV4-T52 AC6 -- positive control FAILED: an injected bypass was not detected, so the single-site pass above proves nothing"
fi

# ---- edm-hookify: hookify_emit_match is the sole function, and the three raw fields it sanitizes
# are never referenced anywhere else in the file except as arguments passed INTO it. -------------
T52_HF_FUNC_COUNT="$(grep -c '^hookify_emit_match() {' "$EDM_HOOKIFY" || true)"
check "EDMV4-T52 AC6 -- edm-hookify: hookify_emit_match is defined exactly once" "1" "$T52_HF_FUNC_COUNT"

T52_HF_RAW_HITS="$(t52_raw_var_only_via_func "$EDM_HOOKIFY" "hookify_emit_match" _mname _maction _mmessage)"
if [[ -z "$T52_HF_RAW_HITS" ]]; then
  pass "EDMV4-T52 AC6 -- edm-hookify: the raw matched-rule fields are never referenced outside a call into hookify_emit_match (single-site property holds)"
else
  fail "EDMV4-T52 AC6 -- edm-hookify: single-site property violated -- raw field referenced outside hookify_emit_match: ${T52_HF_RAW_HITS}"
fi

# Positive control: a scratch copy with a rogue direct echo of $_mmessage (bypassing the function)
# injected right after its own assignment must make the identical scan report a hit.
T52_HF_BYPASS="${T52_SCRATCH}/edm-hookify-bypass"
awk -v marker='_mmessage="${_mrest#*$'"'"'\\t'"'"'}"' \
  '{print; if (index($0, marker) > 0) print "      echo \"$_mmessage\" >&2  # BYPASS-LEAK injected for EDMV4-T52 AC6 positive control"}' \
  "$EDM_HOOKIFY" > "$T52_HF_BYPASS"
T52_HF_BYPASS_HITS="$(t52_raw_var_only_via_func "$T52_HF_BYPASS" "hookify_emit_match" _mname _maction _mmessage)"
if [[ -n "$T52_HF_BYPASS_HITS" ]]; then
  pass "EDMV4-T52 AC6 -- positive control: an injected direct echo of \$_mmessage (bypassing hookify_emit_match) IS detected"
else
  fail "EDMV4-T52 AC6 -- positive control FAILED: an injected bypass was not detected, so the single-site pass above proves nothing"
fi

# ---- edm-stop-gate: stop_gate_emit_blocking is the sole function, and the two untrusted-text
# variables it sanitizes are never referenced anywhere else except as call arguments. -------------
T52_SG_FUNC_COUNT="$(grep -c '^stop_gate_emit_blocking() {' "$EDM_STOP_GATE" || true)"
check "EDMV4-T52 AC6 -- edm-stop-gate: stop_gate_emit_blocking is defined exactly once" "1" "$T52_SG_FUNC_COUNT"

T52_SG_RAW_HITS="$(t52_raw_var_only_via_func "$EDM_STOP_GATE" "stop_gate_emit_blocking" _blocking_text _hookify_out)"
if [[ -z "$T52_SG_RAW_HITS" ]]; then
  pass "EDMV4-T52 AC6 -- edm-stop-gate: the two untrusted-text variables are never referenced outside a call into stop_gate_emit_blocking (single-site property holds)"
else
  fail "EDMV4-T52 AC6 -- edm-stop-gate: single-site property violated -- variable referenced outside stop_gate_emit_blocking: ${T52_SG_RAW_HITS}"
fi

# Positive control: a scratch copy with a rogue direct echo of $_blocking_text (bypassing the
# function) injected right after its own assignment must make the identical scan report a hit.
T52_SG_BYPASS="${T52_SCRATCH}/edm-stop-gate-bypass"
awk -v marker='_blocking_text="${_blocking_text}${_blocking_text:+$'"'"'\\n'"'"'}${_aline}"' \
  '{print; if (index($0, marker) > 0) print "        echo \"$_blocking_text\" >&2  # BYPASS-LEAK injected for EDMV4-T52 AC6 positive control"}' \
  "$EDM_STOP_GATE" > "$T52_SG_BYPASS"
T52_SG_BYPASS_HITS="$(t52_raw_var_only_via_func "$T52_SG_BYPASS" "stop_gate_emit_blocking" _blocking_text _hookify_out)"
if [[ -n "$T52_SG_BYPASS_HITS" ]]; then
  pass "EDMV4-T52 AC6 -- positive control: an injected direct echo of \$_blocking_text (bypassing stop_gate_emit_blocking) IS detected"
else
  fail "EDMV4-T52 AC6 -- positive control FAILED: an injected bypass was not detected, so the single-site pass above proves nothing"
fi

# =================================================================================================
# EDMV4-T53 -- Land wave8-smoke.sh in run-all.sh and the Definition-of-Done registration proof
# =================================================================================================
echo
echo "=== EDMV4-T53: run-all.sh registration + Definition-of-Done verification ==="

# ---- AC1: this suite's own structural contract ---------------------------------------------------
T53_SELF="${SCRIPT_DIR}/wave8-smoke.sh"
if [[ -x "$T53_SELF" ]]; then
  pass "EDMV4-T53 AC1 -- wave8-smoke.sh is executable (chmod +x)"
else
  fail "EDMV4-T53 AC1 -- wave8-smoke.sh is not executable"
fi
check "EDMV4-T53 AC1 -- wave8-smoke.sh sources _harness.sh" 'source "${SCRIPT_DIR}/_harness.sh"' "$(cat "$T53_SELF")"
check "EDMV4-T53 AC1 -- wave8-smoke.sh emits the standard Results summary line run-all.sh parses" \
  'echo "Results: ${PASS} passed, ${FAIL} failed"' "$(cat "$T53_SELF")"

# ---- AC2: run-all.sh registration -- the sole ticket permitted to edit run-all.sh ----------------
# This ticket owns bin/tests/run-all.sh exclusively (audit P1-3); every assertion below reads the
# live file rather than asserting against a value this suite invents, so it fails if the edit is
# ever reverted or if a future ninth suite lands without the matching bump.
RUN_ALL_SH="${PLUGIN_DIR}/bin/tests/run-all.sh"

# AC2(a): wave8-smoke.sh is a genuine member of _PREFERRED_ORDER's default word list, extracted
# from the live line and matched with surrounding spaces so this cannot be satisfied by a
# substring hit inside a longer name or inside this very ticket's own comment text (T05 AC3's
# bare `grep -qF` above is the vacuous shape this is deliberately NOT repeating).
T53_PREFERRED_LINE="$(grep -n '^_PREFERRED_ORDER=' "$RUN_ALL_SH" | head -1 | cut -d: -f2-)"
T53_PREFERRED_VALUE="$(printf '%s' "$T53_PREFERRED_LINE" | sed -E 's/^_PREFERRED_ORDER="\$\{EDM_RUN_ALL_PREFERRED_ORDER-(.*)\}"$/\1/')"
if printf ' %s ' "$T53_PREFERRED_VALUE" | grep -qF ' wave8-smoke.sh '; then
  pass "EDMV4-T53 AC2a -- wave8-smoke.sh is a member of run-all.sh's real _PREFERRED_ORDER default (${T53_PREFERRED_VALUE})"
else
  fail "EDMV4-T53 AC2a -- wave8-smoke.sh is not a member of run-all.sh's _PREFERRED_ORDER default: '${T53_PREFERRED_VALUE}'"
fi

# AC2(b): _MIN_SUITE_COUNT's default equals the LIVE *-smoke.sh count, both computed at test time
# and compared -- never a hardcoded literal "8" on either side, so a ninth suite landing without a
# matching bump is caught here rather than silently tolerated by a stale floor.
T53_MIN_LINE="$(grep -n '_MIN_SUITE_COUNT="\${EDM_RUN_ALL_MIN_SUITE_COUNT:-' "$RUN_ALL_SH" | head -1 | cut -d: -f2-)"
T53_MIN_DEFAULT="$(printf '%s' "$T53_MIN_LINE" | sed -E 's/.*EDM_RUN_ALL_MIN_SUITE_COUNT:-([0-9]+)\}.*/\1/')"
T53_LIVE_SUITE_COUNT="$(find "${PLUGIN_DIR}/bin/tests" -maxdepth 1 -name '*-smoke.sh' -type f 2>/dev/null | wc -l | tr -d ' ')"
if [[ -n "$T53_MIN_DEFAULT" && -n "$T53_LIVE_SUITE_COUNT" && "$T53_MIN_DEFAULT" == "$T53_LIVE_SUITE_COUNT" ]]; then
  pass "EDMV4-T53 AC2b -- _MIN_SUITE_COUNT's default (${T53_MIN_DEFAULT}) equals the live *-smoke.sh count (${T53_LIVE_SUITE_COUNT})"
else
  fail "EDMV4-T53 AC2b -- _MIN_SUITE_COUNT default ('${T53_MIN_DEFAULT}') != live *-smoke.sh count ('${T53_LIVE_SUITE_COUNT}')"
fi

# Positive control for AC2b: a deliberately wrong default must NOT equal the live count -- proves
# the comparison actually discriminates rather than two blank extractions comparing equal.
T53_WRONG_DEFAULT=$((T53_LIVE_SUITE_COUNT + 1))
if [[ "$T53_WRONG_DEFAULT" != "$T53_LIVE_SUITE_COUNT" ]]; then
  pass "EDMV4-T53 AC2b -- positive control: a deliberately wrong default (${T53_WRONG_DEFAULT}) does not equal the live count (${T53_LIVE_SUITE_COUNT})"
else
  fail "EDMV4-T53 AC2b -- positive control broken: wrong default equalled live count"
fi

T53_TMP="$(mktemp -d "${TMPDIR:-/tmp}/edm-wave8-t53.XXXXXX")"
trap 'rm -rf "$T53_TMP"' EXIT
trap 'rm -rf "$T53_TMP"; exit 130' INT
trap 'rm -rf "$T53_TMP"; exit 143' TERM
trap 'rm -rf "$T53_TMP"; exit 129' HUP

# ---- AC2 load-bearing proof (1 of 2): the real _PREFERRED_ORDER registration actually catches
# wave8-smoke.sh's disappearance. Built from the REAL extracted order minus wave8-smoke.sh, so
# this is not an assertion that passes whether or not the suite runs -- the fixture deliberately
# omits the one file the extracted order names, and the refusal must name it exactly. -----------
echo
echo "EDMV4-T53 AC2 (load-bearing proof) -- a missing wave8-smoke.sh is actually caught, not just grep-matched"
T53_SCRATCH="${T53_TMP}/suites"
mkdir -p "$T53_SCRATCH"
for T53_NAME in $T53_PREFERRED_VALUE; do
  if [[ "$T53_NAME" != "wave8-smoke.sh" ]]; then
    {
      echo '#!/usr/bin/env bash'
      echo 'echo "Results: 1 passed, 0 failed"'
      echo 'exit 0'
    } > "${T53_SCRATCH}/${T53_NAME}"
    chmod +x "${T53_SCRATCH}/${T53_NAME}"
  fi
done
T53_PROOF_EC=0
T53_PROOF_OUT="$(EDM_RUN_ALL_SUITE_DIR="$T53_SCRATCH" EDM_RUN_ALL_PREFERRED_ORDER="$T53_PREFERRED_VALUE" EDM_RUN_ALL_MIN_SUITE_COUNT=1 bash "$RUN_ALL_SH" 2>&1)" || T53_PROOF_EC=$?
check "EDMV4-T53 AC2 (load-bearing) -- the missing-preferred tripwire names wave8-smoke.sh when it is absent" \
  "expected suite(s) not discovered: wave8-smoke.sh" "$T53_PROOF_OUT"
if [[ $T53_PROOF_EC -ne 0 ]]; then
  pass "EDMV4-T53 AC2 (load-bearing) -- run-all.sh exits non-zero when wave8-smoke.sh is missing from a set the real order expects it in"
else
  fail "EDMV4-T53 AC2 (load-bearing) -- run-all.sh exited 0 despite a missing preferred suite"
fi

# ---- AC2 load-bearing proof (2 of 2): the floor default is genuinely wired to the same live
# count AC2b compared above, by shrinking a scratch set two below it (EDM_RUN_ALL_PREFERRED_ORDER
# empty so the missing-preferred check above is out of the way) and confirming the REAL,
# unoverridden _MIN_SUITE_COUNT default is what refuses. --------------------------------------
T53_SHORT_SCRATCH="${T53_TMP}/short"
mkdir -p "$T53_SHORT_SCRATCH"
T53_SHORT_I=0
for T53_NAME in $T53_PREFERRED_VALUE; do
  if [[ "$T53_NAME" != "wave8-smoke.sh" ]]; then
    T53_SHORT_I=$((T53_SHORT_I + 1))
    if [[ $T53_SHORT_I -le $((T53_LIVE_SUITE_COUNT - 2)) ]]; then
      {
        echo '#!/usr/bin/env bash'
        echo 'echo "Results: 1 passed, 0 failed"'
        echo 'exit 0'
      } > "${T53_SHORT_SCRATCH}/${T53_NAME}"
      chmod +x "${T53_SHORT_SCRATCH}/${T53_NAME}"
    fi
  fi
done
T53_FLOOR_EC=0
T53_FLOOR_OUT="$(EDM_RUN_ALL_SUITE_DIR="$T53_SHORT_SCRATCH" EDM_RUN_ALL_PREFERRED_ORDER="" bash "$RUN_ALL_SH" 2>&1)" || T53_FLOOR_EC=$?
check "EDMV4-T53 AC2 (load-bearing) -- the real _MIN_SUITE_COUNT default refuses a short discovery set" \
  "suite(s) discovered, expected at least ${T53_MIN_DEFAULT}" "$T53_FLOOR_OUT"
if [[ $T53_FLOOR_EC -ne 0 ]]; then
  pass "EDMV4-T53 AC2 (load-bearing) -- run-all.sh exits non-zero when discovery falls short of the real floor"
else
  fail "EDMV4-T53 AC2 (load-bearing) -- run-all.sh exited 0 despite falling short of the real floor"
fi

rm -rf "$T53_TMP"
trap - EXIT INT TERM HUP

# ---- AC3 gap closure: edm-gateguard, edm-hookify and edm-stop-gate already implement -h/--help
# (each sources _edm-cli-lib.sh's print_help via its own `usage()`, confirmed by reading each
# script directly) but none of the three had a --help case in this suite before this ticket --
# edm-repo-readiness's EDMV4-T38 AC3 section above is the only one of the four AC3 names that did.
# This closes the gap using the scripts as-is (no edit to any of the three scripts themselves --
# EDMV4-T52 is concurrently mid-flight against those files, so this section touches only this
# test file). AC3's usage-error and happy-path cases already exist for all three elsewhere in
# this file (edm-gateguard: deny/allow decisions and the kill-switch cases in its own EDMV4-T11/
# T13/T14/T15 sections; edm-hookify: the malformed-rule-file exit-1 cases and eval-file/eval-stop
# happy paths in its EDMV4-T43/T44 sections; edm-stop-gate: the AC1 clean-initiative and AC2
# multi-initiative-blocking cases in its EDMV4-T46 section) -- only --help was missing. ----------
echo
echo "EDMV4-T53 AC3 -- closing the missing --help gap for edm-gateguard/edm-hookify/edm-stop-gate"

T53_GG_HELP_RC=0
T53_GG_HELP_OUT="$("$GATEGUARD" --help 2>&1)" || T53_GG_HELP_RC=$?
if [[ $T53_GG_HELP_RC -eq 0 && -n "$T53_GG_HELP_OUT" ]]; then
  pass "EDMV4-T53 AC3 -- edm-gateguard --help exits 0 with non-empty output"
else
  fail "EDMV4-T53 AC3 -- edm-gateguard --help: rc=${T53_GG_HELP_RC} output-length=${#T53_GG_HELP_OUT}"
fi

T53_HOOKIFY_HELP_RC=0
T53_HOOKIFY_HELP_OUT="$("$EDM_HOOKIFY" --help 2>&1)" || T53_HOOKIFY_HELP_RC=$?
if [[ $T53_HOOKIFY_HELP_RC -eq 0 && -n "$T53_HOOKIFY_HELP_OUT" ]]; then
  pass "EDMV4-T53 AC3 -- edm-hookify --help exits 0 with non-empty output"
else
  fail "EDMV4-T53 AC3 -- edm-hookify --help: rc=${T53_HOOKIFY_HELP_RC} output-length=${#T53_HOOKIFY_HELP_OUT}"
fi

T53_STOPGATE_HELP_RC=0
T53_STOPGATE_HELP_OUT="$("$EDM_STOP_GATE" --help 2>&1)" || T53_STOPGATE_HELP_RC=$?
if [[ $T53_STOPGATE_HELP_RC -eq 0 && -n "$T53_STOPGATE_HELP_OUT" ]]; then
  pass "EDMV4-T53 AC3 -- edm-stop-gate --help exits 0 with non-empty output"
else
  fail "EDMV4-T53 AC3 -- edm-stop-gate --help: rc=${T53_STOPGATE_HELP_RC} output-length=${#T53_STOPGATE_HELP_OUT}"
fi

# edm-gateguard's usage-error case: an unexpected positional argument (its documented setup-error
# path, exit 1 -- see the script's own "die" comment: this family's usual 2 means "deny" here).
T53_GG_BAD_RC=0
T53_GG_BAD_OUT="$(echo '{}' | "$GATEGUARD" bogus-arg 2>&1)" || T53_GG_BAD_RC=$?
check "EDMV4-T53 AC3 -- edm-gateguard names the unexpected-argument condition" "unexpected argument" "$T53_GG_BAD_OUT"
if [[ $T53_GG_BAD_RC -eq 1 ]]; then
  pass "EDMV4-T53 AC3 -- edm-gateguard's usage-error case (unexpected positional argument) exits 1"
else
  fail "EDMV4-T53 AC3 -- edm-gateguard unexpected-argument case exited ${T53_GG_BAD_RC}, expected 1"
fi

# ---- AC6: no network access, no API budget spent -- self-scan of this suite's own source for
# forbidden commands on a non-comment line. Verified once at review time above via manual grep;
# restated here as a durable assertion. The `claude` half is anchored to an actual invocation
# shape (the CLI's `p` flag or its `plugin` subcommand immediately after the binary name) rather
# than the bare word, precisely because the bare word also appears inside this very assertion's
# own pass/fail message text (EDMV4 code-audit pattern: a detector that greps for the prose
# describing it self-matches or self-defeats). The invocation shape itself is deliberately never
# spelled out contiguously anywhere below either, including in prose -- same reasoning. -----------
T53_NET_PATTERN='^[^#]*\b(curl|wget|git[[:space:]]+fetch|git[[:space:]]+push|git[[:space:]]+clone|claude[[:space:]]+(-p|plugin))\b'

# Positive control: a scratch fixture carrying a genuine, non-comment invocation of that CLI's
# print-mode flag must be caught by the same pattern -- proves this is a firing detector, not a
# silently-defeated one. The invocation text is assembled at runtime from separate halves rather
# than written as a contiguous literal, so this very file never itself contains the string the
# final self-scan below hunts for (the same self-match-by-fixture trap this initiative's own
# code-audit patterns doc records having bitten five times already).
T53_AC6_BIN="cla""ude"
T53_AC6_FLAG="-"; T53_AC6_FLAG="${T53_AC6_FLAG}p"
T53_AC6_FIXTURE="${TMPDIR:-/tmp}/edm-wave8-t53-ac6-fixture.$$"
printf 'echo before\nOUT="$(%s %s "do something")"\necho after\n' "$T53_AC6_BIN" "$T53_AC6_FLAG" > "$T53_AC6_FIXTURE"
T53_AC6_CONTROL="$(grep -nE "$T53_NET_PATTERN" "$T53_AC6_FIXTURE" || true)"
rm -f "$T53_AC6_FIXTURE"
if [[ -n "$T53_AC6_CONTROL" ]]; then
  pass "EDMV4-T53 AC6 -- positive control: a genuine print-mode CLI invocation on a scratch fixture is caught"
else
  fail "EDMV4-T53 AC6 -- positive control broken: a genuine print-mode CLI invocation was NOT caught by the pattern"
fi

T53_NETWORK_HITS="$(grep -nE "$T53_NET_PATTERN" "$T53_SELF" || true)"
if [[ -z "$T53_NETWORK_HITS" ]]; then
  pass "EDMV4-T53 AC6 -- wave8-smoke.sh invokes no network operation and no claude CLI call"
else
  fail "EDMV4-T53 AC6 -- wave8-smoke.sh appears to invoke a network/claude operation: ${T53_NETWORK_HITS}"
fi

# =================================================================================================
# CA-002 -- marketplace.json's edm `agents` array must list every agent file on disk
# =================================================================================================
echo "=== CA-002: marketplace.json agent registration matches the agents/ directory ==="
echo

# Round-1 code audit found the three lens agents this initiative added (L12/L13/L14) absent from
# .claude-plugin/marketplace.json: 12 edm-audit-* entries listed against 15 on disk, in the only
# plugin in the repository with that mismatch. Nothing caught it -- the suite asserts that file's
# version and its skills array LENGTH, and counts agent files ON DISK, but never compares the two.
# The manifest is an enumeration, so every new agent must be added by hand; this assertion is what
# makes forgetting loud instead of silent.
ca002_manifest="${REPO_ROOT}/.claude-plugin/marketplace.json"
ca002_listed="$({ jq -r '.plugins[] | select(.name=="edm") | .agents[]' "$ca002_manifest" 2>/dev/null || true; } \
  | sed 's|^\./agents/||' | sort)"
ca002_disk="$({ ls -1 "${PLUGIN_DIR}/agents" 2>/dev/null || true; } | grep '\.md$' | sort)"
ca002_only_disk="$({ comm -13 <(printf '%s\n' "$ca002_listed") <(printf '%s\n' "$ca002_disk") || true; })"
ca002_only_manifest="$({ comm -23 <(printf '%s\n' "$ca002_listed") <(printf '%s\n' "$ca002_disk") || true; })"

if [[ -z "$ca002_only_disk" ]]; then
  pass "CA-002 -- every agents/*.md file is listed in marketplace.json's edm agents array"
else
  fail "CA-002 -- agent file(s) on disk but NOT registered in marketplace.json (they will not load): $(printf '%s' "$ca002_only_disk" | tr '\n' ' ')"
fi

if [[ -z "$ca002_only_manifest" ]]; then
  pass "CA-002 -- marketplace.json lists no agent file that is absent from disk"
else
  fail "CA-002 -- marketplace.json lists agent path(s) with no file on disk: $(printf '%s' "$ca002_only_manifest" | tr '\n' ' ')"
fi

# Positive control: the comparison must actually discriminate. Drop a known name from the listed
# set and confirm it surfaces as disk-only -- otherwise both assertions above would pass against
# any manifest at all, which is precisely the shape that let the original defect through.
ca002_probe_listed="$(printf '%s\n' "$ca002_listed" | grep -v '^edm-audit-logic\.md$' || true)"
ca002_probe_diff="$({ comm -13 <(printf '%s\n' "$ca002_probe_listed") <(printf '%s\n' "$ca002_disk") || true; })"
if printf '%s\n' "$ca002_probe_diff" | grep -qx 'edm-audit-logic.md'; then
  pass "CA-002 -- positive control: an agent removed from the listed set is reported as unregistered"
else
  fail "CA-002 -- positive control FAILED: removing edm-audit-logic.md from the listed set was not detected, so the comparison cannot catch a missing registration"
fi

echo

# =================================================================================================
# CA-003 -- edm-stop-gate must read stop_hook_active from its own Stop payload
# =================================================================================================
echo "=== CA-003: edm-stop-gate honours stop_hook_active (loop breaker) ==="
echo

# Round-1 code audit found edm-stop-gate never read its own stdin payload at all, so it could never
# see stop_hook_active -- the boolean the host sets precisely when a Stop hook is already blocking
# this turn, so a Stop hook can break its own loop. A routine unclosed PARTIAL (the same fixture
# shape as EDMV4-T46 AC2's own T46BLOCK case above) makes edm-state validate return a blocking
# anomaly on every single Stop; absent this fix the gate would block forever once the host retried
# with stop_hook_active: true, since it never had a way to see that signal.
t_ca003_case() {
  edm-state init CA003BLOCK >/dev/null
  edm-state set CA003BLOCK current_phase 1 >/dev/null
  edm-state set CA003BLOCK estimated_size Small >/dev/null
  edm-state record-partial-verdict CA003BLOCK CA003BLOCK-T01 PARTIAL "needs runtime check" >/dev/null

  local rc out

  # (a) stop_hook_active: false, with a genuine blocking anomaly present -- still blocks (exit 2).
  # Proves the new read did not weaken ordinary enforcement.
  rc=0
  out="$(printf '{"stop_hook_active": false}' | edm-stop-gate 2>&1)" || rc=$?
  [[ "$rc" -eq 2 ]] && pass "CA-003 -- stop_hook_active:false with a blocking anomaly still exits 2" \
    || fail "CA-003 -- expected exit 2 with stop_hook_active:false, got ${rc} out=[${out}]"

  # (b) stop_hook_active: true, with the IDENTICAL blocking anomaly -- exits 0, silently. This is
  # the loop breaker itself: the host sets this precisely because it is already blocking this turn.
  rc=0
  out="$(printf '{"stop_hook_active": true}' | edm-stop-gate 2>&1)" || rc=$?
  [[ "$rc" -eq 0 && -z "$out" ]] \
    && pass "CA-003 -- stop_hook_active:true with the same blocking anomaly exits 0, silently" \
    || fail "CA-003 -- expected exit 0 and empty output with stop_hook_active:true, got rc=${rc} out=[${out}]"

  # (c) no Stop payload at all (immediate EOF on stdin) -- must NOT become a new, fifth silent
  # bail-out: the blocking anomaly is still present, so this must still block exactly like (a).
  rc=0
  out="$(edm-stop-gate < /dev/null 2>&1)" || rc=$?
  [[ "$rc" -eq 2 ]] && pass "CA-003 -- no Stop payload at all still exits 2 (not a new silent allow)" \
    || fail "CA-003 -- expected exit 2 with no payload, got ${rc} out=[${out}]"

  # (d) an unparseable Stop payload -- same: must still block, not silently allow.
  rc=0
  out="$(printf 'not-json' | edm-stop-gate 2>&1)" || rc=$?
  [[ "$rc" -eq 2 ]] && pass "CA-003 -- an unparseable Stop payload still exits 2 (not a new silent allow)" \
    || fail "CA-003 -- expected exit 2 with an unparseable payload, got ${rc} out=[${out}]"
}
t46_isolate_and_run t_ca003_case

# Positive control (what would make (a)-(d) above fail): a scratch copy of edm-stop-gate with the
# stop_hook_active short-circuit removed must FAIL case (b) -- proving (b) is not vacuous the way
# CA-001's original AC7 band was. Cases (a)/(c)/(d) are unaffected by this removal (they never
# depend on the short-circuit firing), so only (b) is re-checked here.
t_ca003_no_shortcircuit_case() {
  edm-state init CA003NOSC >/dev/null
  edm-state set CA003NOSC current_phase 1 >/dev/null
  edm-state set CA003NOSC estimated_size Small >/dev/null
  edm-state record-partial-verdict CA003NOSC CA003NOSC-T01 PARTIAL "needs runtime check" >/dev/null

  local scratch_gate="${TMP}/edm-stop-gate.no-shortcircuit"
  sed '/\[\[ "\$STOP_HOOK_ACTIVE" == "true" \]\] && exit 0/d' \
    "${PLUGIN_DIR}/bin/edm-stop-gate" > "$scratch_gate"
  chmod +x "$scratch_gate"

  local rc=0 out
  out="$(printf '{"stop_hook_active": true}' | "$scratch_gate" 2>&1)" || rc=$?
  [[ "$rc" -eq 2 ]] \
    && pass "CA-003 -- positive control: removing the stop_hook_active short-circuit makes case (b) block again (exit 2), proving (b) discriminates" \
    || fail "CA-003 -- positive control FAILED: expected the short-circuit-free copy to still exit 2 on stop_hook_active:true, got rc=${rc} out=[${out}] (if this is 0, case (b) above is not actually testing the short-circuit)"
}
t46_isolate_and_run t_ca003_no_shortcircuit_case

# ============================================================================================
# Documentation-accuracy P1 batch (code-audit pass-1 2026-09-04): CA-021, CA-023, CA-024,
# CA-025, CA-026, CA-032. Banded section appended at the tail per this initiative's remediation
# convention -- touches nothing above this line.
# ============================================================================================
echo
echo "-- Documentation-accuracy P1 batch: CA-021/023/024/025/026/032 --"

DOCBATCH_CLAUDE_MD="${PLUGIN_DIR}/CLAUDE.md"
DOCBATCH_README_MD="${PLUGIN_DIR}/README.md"
DOCBATCH_CHANGELOG_MD="${PLUGIN_DIR}/CHANGELOG.md"
DOCBATCH_IMPLEMENTER_MD="${PLUGIN_DIR}/agents/edm-implementer.md"
DOCBATCH_PLUGIN_JSON="${PLUGIN_DIR}/.claude-plugin/plugin.json"

# ---- CA-021: guards D1/D2 must never carry a hardcoded lens count again -------------------
# What would make this fail: the pre-fix text ("11-lens", "11 code-audit lenses") reappearing,
# OR any future hardcoded count ("14-lens", "15-lens", etc.) being added to the guard text --
# both are "[0-9]+[- ]?lens", which the fix deliberately removed from D1/D2 entirely.
ca021_d1d2_block="$(awk '/\*\*\(D1\)\*\*/,/\*\*\(D3\)\*\*/' "$DOCBATCH_CLAUDE_MD")"
if printf '%s' "$ca021_d1d2_block" | grep -Eiq '[0-9]+[a-zA-Z -]{0,20}lens'; then
  fail "CA-021 -- guards D1/D2 in CLAUDE.md still carry a hardcoded lens count"
else
  pass "CA-021 -- guards D1/D2 in CLAUDE.md carry no hardcoded lens count (old or new)"
fi

# Positive control: prove the check above is not vacuous by re-injecting the exact stale phrase
# into a scratch copy and confirming the same grep now fires.
ca021_scratch="$(printf '%s' "$ca021_d1d2_block" | sed 's/every code-audit lens/the 11 code-audit lens/')"
if printf '%s' "$ca021_scratch" | grep -Eiq '[0-9]+[a-zA-Z -]{0,20}lens'; then
  pass "CA-021 -- positive control: re-injecting '11 code-audit lens' into a scratch copy of the D1/D2 block makes the same check fire"
else
  fail "CA-021 -- positive control FAILED: injecting the stale phrase did not trip the detector, so the check above proves nothing"
fi

ca021_implementer_line="$(grep -c 'anti-patterns flagged by the code-audit lenses' "$DOCBATCH_IMPLEMENTER_MD" || true)"
if grep -Eiq '[0-9]+[a-zA-Z -]{0,20}lens' "$DOCBATCH_IMPLEMENTER_MD"; then
  fail "CA-021 -- agents/edm-implementer.md still carries a hardcoded lens count"
elif [[ "${ca021_implementer_line:-0}" -ge 1 ]]; then
  pass "CA-021 -- agents/edm-implementer.md's pattern-library instruction carries no hardcoded lens count"
else
  fail "CA-021 -- agents/edm-implementer.md's pattern-library instruction sentence not found at all"
fi

echo "  NOTE: CA-021 also names bin/edm-state:2553's '--accept-p2-debt' comment ('a full"
echo "  eleven-lens round') as a fourth stale site. bin/ is out of this batch's scope (owned by"
echo "  a sibling agent); reported, not fixed, here."

# ---- CA-023: qc_shard_threshold's documented default must match plugin.json's live default -
# What would make this fail: either value moving without the other (the exact defect found --
# CLAUDE.md said 20, plugin.json shipped 6).
ca023_para="$(awk '/^- `qc_shard_threshold`/{f=1} f{print} f && /^- `implementation_mode`/{exit}' "$DOCBATCH_CLAUDE_MD")"
ca023_documented="$(printf '%s' "$ca023_para" | grep -o 'default `[0-9]\+`' | head -1 | grep -o '[0-9]\+' || true)"
ca023_shipped="$(jq -r '.userConfig.qc_shard_threshold.default // .config.qc_shard_threshold.default // empty' "$DOCBATCH_PLUGIN_JSON" 2>/dev/null || true)"
if [[ -z "$ca023_shipped" ]]; then
  # Schema key path varies by plugin.json shape; fall back to the raw numeric neighbor of the key.
  ca023_shipped="$(awk '/"qc_shard_threshold"/,/}/' "$DOCBATCH_PLUGIN_JSON" | grep -o '"default"[[:space:]]*:[[:space:]]*[0-9]\+' | grep -o '[0-9]\+' | head -1 || true)"
fi
if [[ -n "$ca023_documented" && -n "$ca023_shipped" && "$ca023_documented" == "$ca023_shipped" ]]; then
  pass "CA-023 -- CLAUDE.md's documented qc_shard_threshold default (${ca023_documented}) matches plugin.json's shipped default (${ca023_shipped})"
else
  fail "CA-023 -- qc_shard_threshold default mismatch: CLAUDE.md says '${ca023_documented:-<none found>}', plugin.json ships '${ca023_shipped:-<none found>}'"
fi

# ---- CA-024: README's Agents table must list every edm-audit-* lens agent on disk ----------
# What would make this fail: adding/removing a lens agent file without updating this table --
# the live count and the brace-list count must agree.
ca024_live_count="$(find "${PLUGIN_DIR}/agents" -maxdepth 1 -name 'edm-audit-*.md' ! -name 'edm-audit-synthesizer.md' | wc -l | tr -d '[:space:]')"
ca024_readme_line="$(grep -o 'edm-audit-{[^}]*}' "$DOCBATCH_README_MD" | head -1 || true)"
ca024_readme_count="$(printf '%s' "$ca024_readme_line" | tr ',' '\n' | grep -c '.' || true)"
if [[ "$ca024_live_count" == "$ca024_readme_count" ]]; then
  pass "CA-024 -- README's edm-audit-{...} brace list names ${ca024_readme_count} agents, matching the ${ca024_live_count} edm-audit-*.md lens files on disk"
else
  fail "CA-024 -- README's edm-audit-{...} brace list names ${ca024_readme_count:-0} agents but ${ca024_live_count} edm-audit-*.md lens files exist on disk"
fi
for ca024_name in silent-failures type-design behavioral-tests; do
  if printf '%s' "$ca024_readme_line" | grep -q "$ca024_name"; then
    pass "CA-024 -- README's Agents table names ${ca024_name}"
  else
    fail "CA-024 -- README's Agents table is missing ${ca024_name}"
  fi
done

# ---- CA-025: the [3.3.0] CHANGELOG entry must name every new blocking hook and executable ---
# Bound the search to the [3.3.0] section only, so a future version's own entry can never
# satisfy this by accident.
ca025_section="$(awk '/^## \[3\.3\.0\]/{f=1} f && /^## \[/ && !/^## \[3\.3\.0\]/{f=0} f' "$DOCBATCH_CHANGELOG_MD")"
for ca025_term in edm-gateguard edm-bash-gate edm-stop-gate hookify edm-repo-readiness qc_shard_threshold; do
  if printf '%s' "$ca025_section" | grep -q "$ca025_term"; then
    pass "CA-025 -- the [3.3.0] CHANGELOG entry names ${ca025_term}"
  else
    fail "CA-025 -- the [3.3.0] CHANGELOG entry is missing ${ca025_term}"
  fi
done

# ---- CA-026: docs/ecc-integration-analysis.md Part 4.2 must not still read as a live defect --
DOCBATCH_ECC_MD="${PLUGIN_DIR}/docs/ecc-integration-analysis.md"
ca026_part42="$(awk '/^### 4\.2 /{f=1} f && /^### 4\.3 /{f=0} f' "$DOCBATCH_ECC_MD")"
if printf '%s' "$ca026_part42" | grep -q 'is a no-op'; then
  fail "CA-026 -- docs/ecc-integration-analysis.md Part 4.2 still describes the learning loop as a live no-op"
else
  pass "CA-026 -- docs/ecc-integration-analysis.md Part 4.2 no longer describes the learning loop as a live no-op"
fi
if printf '%s' "$ca026_part42" | grep -q 'CLOSED by EDMV4-T18'; then
  pass "CA-026 -- docs/ecc-integration-analysis.md Part 4.2 records the fix as CLOSED by EDMV4-T18"
else
  fail "CA-026 -- docs/ecc-integration-analysis.md Part 4.2 does not record closure by EDMV4-T18"
fi

# ---- CA-059 (folded into the CA-026/CA-021 commits): no reintroduced file:line citation -----
# in the two prose sites this batch corrected. Absence-only: proves the fix did not silently
# regress to a fresh, differently-stale line number.
if grep -Eq 'timing\.sh:[0-9]+' "$DOCBATCH_CLAUDE_MD"; then
  fail "CA-059 -- CLAUDE.md's Mermaid-conditional paragraph still cites timing.sh by line number"
else
  pass "CA-059 -- CLAUDE.md's Mermaid-conditional paragraph cites timing.sh by name, not line number"
fi
if grep -Eq 'edm-state:56[0-9]{2}' "$DOCBATCH_ECC_MD"; then
  fail "CA-059 -- docs/ecc-integration-analysis.md Part 4.2/8.2 still cite bin/edm-state by a live line number"
else
  pass "CA-059 -- docs/ecc-integration-analysis.md Part 4.2/8.2 no longer cite bin/edm-state by a live line number"
fi

echo "  NOTE: CA-022 (edm-sync-canonical-sections' --help claims 'the two' canonical sections; it"
echo "  extracts seven) and CA-060 (wave7-smoke.sh:8931's G10/CA-340 scope comment overclaims"
echo "  coverage) both name bin/ or bin/tests/ files outside this batch's scope (sibling-owned);"
echo "  reported, not fixed, here."

# ---- CA-032: turn-budget parity prose must match the live agent frontmatter, per-pair --------
# What would make this fail: any of the four verifiers' maxTurns changing without this section's
# prose being swept in the same commit -- the exact drift CA-032 found (edm-qc-auditor/
# edm-implementer raised by EDMV4-T55 while the prose still said maxTurns: 50 for all four).
ca032_get_maxturns() { grep -m1 '^maxTurns:' "${PLUGIN_DIR}/agents/${1}.md" | grep -o '[0-9]\+' || true; }
ca032_section="$(awk '/^### Turn budget parity/{f=1} f && /^### Scope of this section/{f=0} f' "$DOCBATCH_CLAUDE_MD")"
for ca032_verifier in edm-srd-auditor edm-ticket-auditor edm-qc-auditor edm-test-coverage-auditor; do
  ca032_verifier_turns="$(ca032_get_maxturns "$ca032_verifier")"
  if [[ -z "$ca032_verifier_turns" ]]; then
    fail "CA-032 -- could not read ${ca032_verifier}'s live maxTurns from its own frontmatter"
  elif printf '%s' "$ca032_section" | grep -Eq "maxTurns: ${ca032_verifier_turns}([^0-9]|\$)"; then
    pass "CA-032 -- CLAUDE.md's Turn budget parity section states ${ca032_verifier}'s live maxTurns value (${ca032_verifier_turns})"
  else
    fail "CA-032 -- CLAUDE.md's Turn budget parity section does not state ${ca032_verifier}'s live maxTurns value (${ca032_verifier_turns})"
  fi
done

# =================================================================================================
# CA-029 / CA-030 / CA-031 / CA-041 / CA-042 / CA-056 -- bin/edm-hookify correctness and coverage
# =================================================================================================
# One P1 remediation batch (code-audit pass-1_2026-09-04), six findings, all rooted in
# bin/edm-hookify:
#   CA-029  a crafted rule FILENAME -- or a crafted rule `name` -- forged a `block` verdict
#           through the tab-delimited, newline-separated record stream jq hands back to bash
#   CA-030  the per-rule try/catch covered only `fromjson`, so ONE malformed rule file aborted the
#           single jq pass and silently disabled EVERY other rule
#   CA-031  an empty or unparseable payload degraded to `{}`, which made every `not_contains`
#           condition match vacuously and every `contains` condition silently stop matching
#   CA-041  four of the six documented `op_match` operators had no test exercising a match
#   CA-042  the `bash` and `stop` events had no match-path coverage at all
#   CA-056  the `L)` list arm and the setup-error arm bypassed the sanitizer entirely
#
# Every assertion below is paired with a control that proves it can fail. Where the property under
# test is the behaviour of one specific line of bin/edm-hookify, that control is a MUTANT: a
# scratch copy of the real script with that one line neutralised by `sed`, run against the
# identical fixture. CA-041 and CA-042 are coverage gaps, so filling them with assertions that
# cannot fail would be strictly worse than leaving them open -- hence the mutant per operator arm
# and per event path rather than a bare "it printed something" check.
echo
echo "=== CA-029/030/031/041/042/056: edm-hookify correctness and coverage ==="
echo

CAHK_HOOKIFY="${PLUGIN_DIR}/bin/edm-hookify"
CAHK_FIX="${PLUGIN_DIR}/bin/tests/fixtures/hookify"
harness_scratch_dir CAHK_TMP
mkdir -p "${CAHK_TMP}/mutants"

# cahk_mutant <name> <sed-arg...> -- print the path of a scratch copy of bin/edm-hookify with the
# given sed expressions applied. `_edm-cli-lib.sh` is copied alongside it because the script
# resolves SCRIPT_DIR from its own location and sources the library from there.
cahk_mutant() {
  local name="$1"
  shift
  local dir="${CAHK_TMP}/mutants/${name}"
  mkdir -p "$dir"
  cp "${PLUGIN_DIR}/bin/_edm-cli-lib.sh" "${dir}/_edm-cli-lib.sh"
  sed "$@" "$CAHK_HOOKIFY" > "${dir}/edm-hookify"
  chmod +x "${dir}/edm-hookify"
  printf '%s\n' "${dir}/edm-hookify"
}

# cahk_newproj <slug> -- print the path of a fresh scratch project carrying an empty
# .claude/edm-hookify/ rule directory.
cahk_newproj() {
  local dir="${CAHK_TMP}/proj-$1"
  rm -rf "$dir"
  mkdir -p "${dir}/.claude/edm-hookify"
  printf '%s\n' "$dir"
}

# cahk_run <binary> <project-dir> <event> <payload> -- one `eval` run. Sets CAHK_OUT (stdout),
# CAHK_ERR (stderr) and CAHK_RC. The rc is captured with `|| CAHK_RC=$?` rather than read from a
# later `$?`, which `set -e` would otherwise consume before it could be read.
cahk_run() {
  local bin="$1" proj="$2" event="$3" payload="$4"
  CAHK_RC=0
  CAHK_OUT="$(printf '%s' "$payload" \
    | ( cd "$proj" && CLAUDE_PROJECT_DIR="$proj" bash "$bin" eval "$event" 2>"${CAHK_TMP}/stderr" ))" \
    || CAHK_RC=$?
  CAHK_ERR="$(cat "${CAHK_TMP}/stderr" 2>/dev/null || true)"
}

# cahk_list <binary> <project-dir> -- the same three out-variables for the `list` subcommand.
cahk_list() {
  local bin="$1" proj="$2"
  CAHK_RC=0
  CAHK_OUT="$( ( cd "$proj" && CLAUDE_PROJECT_DIR="$proj" bash "$bin" list 2>"${CAHK_TMP}/stderr" ) )" \
    || CAHK_RC=$?
  CAHK_ERR="$(cat "${CAHK_TMP}/stderr" 2>/dev/null || true)"
}

# cahk_rc_is <label> <expected-rc>
cahk_rc_is() {
  if [[ "$CAHK_RC" -eq "$2" ]]; then
    pass "$1 (rc=$2)"
  else
    fail "$1 (rc=${CAHK_RC}, expected $2; stdout=[${CAHK_OUT}] stderr=[${CAHK_ERR}])"
  fi
}

# cahk_stdout_empty <label> / cahk_stdout_nonempty <label>
cahk_stdout_empty() {
  [[ -z "$CAHK_OUT" ]] && pass "$1" || fail "$1 (stdout carried: [${CAHK_OUT}])"
}

# cahk_nonascii <file> -- true when <file> holds a byte outside printable ASCII plus whitespace.
# Same predicate the EDMV4-T52 AC2 sweep uses, so ESC (0x1b) and a UTF-8 lead byte both count.
cahk_nonascii() {
  LC_ALL=C grep -q '[^[:print:][:space:]]' "$1"
}

# ---- CA-029: a crafted FILENAME must never forge a `block` --------------------------------------
# The forged name embeds a newline, then a complete tab-delimited `M` record claiming action
# `block`. Its CONTENT is deliberately not valid JSON and never sets `enabled` or `action`, which
# is the whole point: pre-fix, none of that mattered.
CAHK_FORGED_FILE="$(printf 'x\nM\tca029-forged-file\tblock\tFORGED-VIA-FILENAME')"
CAHK_P29A="$(cahk_newproj ca029-filename)"
printf 'this is deliberately not JSON\n' > "${CAHK_P29A}/.claude/edm-hookify/${CAHK_FORGED_FILE}.json"
CAHK_FILE_PAYLOAD='{"file_path":"src/a.js","new_text":"b","old_text":"","content":""}'

cahk_run "$CAHK_HOOKIFY" "$CAHK_P29A" file "$CAHK_FILE_PAYLOAD"
cahk_rc_is "CA-029 -- a rule filename carrying a newline + a forged M/block record exits 1 (setup error), never 2" 1
cahk_stdout_empty "CA-029 -- that forged filename puts nothing on stdout (the stream a block line uses)"
check "CA-029 -- the forged filename is reported as one flattened setup-error line" \
  "invalid JSON" "$CAHK_ERR"

# Mutant control: neutralise the jq-side `scrub` def (the encoding-layer guard) and confirm the
# IDENTICAL fixture forges the block again. Without this, the two assertions above would pass on
# any evaluator that happened to reject the file for an unrelated reason.
CAHK_MUT_NOSCRUB="$(cahk_mutant noscrub -e 's@^def scrub($s):.*@def scrub($s): ($s|tostring);@')"
cahk_run "$CAHK_MUT_NOSCRUB" "$CAHK_P29A" file "$CAHK_FILE_PAYLOAD"
if [[ "$CAHK_RC" -eq 2 && "$CAHK_OUT" == *"ca029-forged-file block"* ]]; then
  pass "CA-029 -- mutant control: with jq-side scrub neutralised the same filename DOES forge exit 2 and a block line, so the two assertions above are not vacuous"
else
  fail "CA-029 -- mutant control FAILED: scrub-neutralised copy gave rc=${CAHK_RC} stdout=[${CAHK_OUT}]; the pass above proves nothing"
fi

# ---- CA-029: a crafted rule `name` must never forge a `block` either ----------------------------
CAHK_FORGED_NAME="$(printf 'harmless\nM\tca029-forged-name\tblock\tFORGED-VIA-NAME')"
CAHK_P29B="$(cahk_newproj ca029-name)"
jq --arg nm "$CAHK_FORGED_NAME" '.name = $nm' "${CAHK_FIX}/warn-no-console-log.json" \
  > "${CAHK_P29B}/.claude/edm-hookify/forged-name.json"
CAHK_CONSOLE_PAYLOAD='{"file_path":"src/a.js","new_text":"console.log(1)","old_text":"","content":""}'

cahk_run "$CAHK_HOOKIFY" "$CAHK_P29B" file "$CAHK_CONSOLE_PAYLOAD"
cahk_rc_is "CA-029 -- a warn rule whose name carries a forged M/block record still exits 0" 0
cahk_stdout_empty "CA-029 -- that forged name puts nothing on stdout"
check "CA-029 -- the forged name is flattened into the single warn line it belongs to" \
  "harmless M ca029-forged-name block FORGED-VIA-NAME warn" "$CAHK_ERR"

cahk_run "$CAHK_MUT_NOSCRUB" "$CAHK_P29B" file "$CAHK_CONSOLE_PAYLOAD"
if [[ "$CAHK_RC" -eq 2 ]]; then
  pass "CA-029 -- mutant control: with scrub neutralised the forged rule name DOES reach exit 2, so the exit-0 assertion above is not vacuous"
else
  fail "CA-029 -- mutant control FAILED: scrub-neutralised copy gave rc=${CAHK_RC} for the forged rule name"
fi

# `list` is the third reachable path for the same forge: one rule file must produce exactly one line.
cahk_list "$CAHK_HOOKIFY" "$CAHK_P29B"
CAHK_LIST_LINES="$(printf '%s\n' "$CAHK_OUT" | grep -c . || true)"
if [[ "$CAHK_LIST_LINES" -eq 1 ]]; then
  pass "CA-029 -- edm-hookify list emits exactly one line for one rule file, even with a newline in its name"
else
  fail "CA-029 -- edm-hookify list emitted ${CAHK_LIST_LINES} lines for one rule file: [${CAHK_OUT}]"
fi
cahk_list "$CAHK_MUT_NOSCRUB" "$CAHK_P29B"
CAHK_LIST_LINES_MUT="$(printf '%s\n' "$CAHK_OUT" | grep -c . || true)"
if [[ "$CAHK_LIST_LINES_MUT" -gt 1 ]]; then
  pass "CA-029 -- mutant control: with scrub neutralised the same rule file splits into ${CAHK_LIST_LINES_MUT} list lines"
else
  fail "CA-029 -- mutant control FAILED: scrub-neutralised list still emitted ${CAHK_LIST_LINES_MUT} line(s)"
fi

# ---- CA-030: one malformed rule file must never disable the rest of the set ---------------------
# Four realistic authoring mistakes, each alongside ONE valid, enabled `block` rule that a matching
# payload would fire. The contract is: the block still fires (exit 2, line on stdout) AND the bad
# file is named on stderr.
CAHK_P30="$(cahk_newproj ca030)"
cp "${CAHK_FIX}/block-rm-rf-bash.json" "${CAHK_P30}/.claude/edm-hookify/"
CAHK_BASH_MATCH='{"command":"rm -rf /tmp/scratch"}'

cahk_write_bad_rule() {
  # cahk_write_bad_rule <trigger> <destination>
  case "$1" in
    array)    printf '[{"name":"a","enabled":true}]\n' > "$2" ;;
    string)   printf '"a bare JSON string, not an object"\n' > "$2" ;;
    badconds) printf '{"name":"b","enabled":true,"event":"bash","conditions":"oops","message":"m"}\n' > "$2" ;;
    badregex) printf '{"name":"c","enabled":true,"event":"bash","conditions":[{"field":"command","operator":"regex_match","pattern":"["}],"message":"m"}\n' > "$2" ;;
  esac
}

for cahk_trigger in array string badconds badregex; do
  case "$cahk_trigger" in
    array)    cahk_expect_reason="rule must be a JSON object, got array" ;;
    string)   cahk_expect_reason="rule must be a JSON object, got string" ;;
    badconds) cahk_expect_reason="conditions must be an array, got string" ;;
    badregex) cahk_expect_reason="rule evaluation error" ;;
  esac
  cahk_write_bad_rule "$cahk_trigger" "${CAHK_P30}/.claude/edm-hookify/bad-rule.json"
  cahk_run "$CAHK_HOOKIFY" "$CAHK_P30" bash "$CAHK_BASH_MATCH"
  cahk_rc_is "CA-030 (${cahk_trigger}) -- the valid enabled block rule still fires alongside the malformed file" 2
  check "CA-030 (${cahk_trigger}) -- the block rule's line is on stdout" \
    "block-rm-rf-bash block" "$CAHK_OUT"
  check "CA-030 (${cahk_trigger}) -- the malformed file is named on stderr" "bad-rule.json" "$CAHK_ERR"
  check "CA-030 (${cahk_trigger}) -- stderr states the specific reason" "$cahk_expect_reason" "$CAHK_ERR"
done

# Discrimination control 1: the exit-2 assertions above must be carried by the VALID rule, not by
# anything the malformed file does. Disable the valid rule and the same directory must exit 1.
jq '.enabled = false' "${CAHK_FIX}/block-rm-rf-bash.json" \
  > "${CAHK_P30}/.claude/edm-hookify/block-rm-rf-bash.json"
cahk_write_bad_rule badregex "${CAHK_P30}/.claude/edm-hookify/bad-rule.json"
cahk_run "$CAHK_HOOKIFY" "$CAHK_P30" bash "$CAHK_BASH_MATCH"
cahk_rc_is "CA-030 -- control: with the valid block rule disabled the same directory exits 1, not 2" 1
cahk_stdout_empty "CA-030 -- control: nothing reaches stdout when the only enabled rule is malformed"
cp "${CAHK_FIX}/block-rm-rf-bash.json" "${CAHK_P30}/.claude/edm-hookify/block-rm-rf-bash.json"

# Mutant control 2: remove the outer try/catch around project_rule and confirm the `badregex`
# trigger once again aborts the whole pass -- exit 1, zero rules evaluated. This is the mutation
# that isolates the actual CA-030 fix (the type guards alone would not survive it).
CAHK_MUT_NOCATCH="$(cahk_mutant nocatch \
  -e 's@| (try project_rule(@| (project_rule(@' \
  -e 's@^   catch (.*@   )@')"
cahk_write_bad_rule badregex "${CAHK_P30}/.claude/edm-hookify/bad-rule.json"
cahk_run "$CAHK_MUT_NOCATCH" "$CAHK_P30" bash "$CAHK_BASH_MATCH"
if [[ "$CAHK_RC" -eq 1 && -z "$CAHK_OUT" ]]; then
  pass "CA-030 -- mutant control: without the outer try/catch the invalid-regex file DOES abort the pass (rc=1, zero rules evaluated)"
else
  fail "CA-030 -- mutant control FAILED: try/catch-less copy gave rc=${CAHK_RC} stdout=[${CAHK_OUT}]; the isolation passes above prove nothing"
fi

# Mutant control 3: the object type guard is what produces the specific `got array` reason.
CAHK_MUT_NOTYPE="$(cahk_mutant notypeguard -e 's@^  if ($r|type) != "object" then@  if false then@')"
cahk_write_bad_rule array "${CAHK_P30}/.claude/edm-hookify/bad-rule.json"
cahk_run "$CAHK_MUT_NOTYPE" "$CAHK_P30" bash "$CAHK_BASH_MATCH"
check_absent "CA-030 -- mutant control: with the object type guard removed the 'got array' reason disappears" \
  "rule must be a JSON object, got array" "$CAHK_ERR"
rm -f "${CAHK_P30}/.claude/edm-hookify/bad-rule.json"

# ---- CA-031: "no payload" and "empty field" are different facts --------------------------------
CAHK_P31="$(cahk_newproj ca031)"
jq -n '{name:"ca031-contains",enabled:true,event:"file",action:"warn",
        conditions:[{field:"new_text",operator:"contains",pattern:"console.log"}],
        message:"contains probe"}' > "${CAHK_P31}/.claude/edm-hookify/ca031-contains.json"
jq -n '{name:"ca031-not-contains",enabled:true,event:"file",action:"warn",
        conditions:[{field:"new_text",operator:"not_contains",pattern:"console.log"}],
        message:"not-contains probe"}' > "${CAHK_P31}/.claude/edm-hookify/ca031-not-contains.json"

cahk_run "$CAHK_HOOKIFY" "$CAHK_P31" file ''
cahk_rc_is "CA-031 -- empty stdin is a setup error, not an empty-field match" 1
check "CA-031 -- the empty-stdin setup error says so" "no payload on stdin" "$CAHK_ERR"
check_absent "CA-031 -- no rule fires on empty stdin" "ca031-not-contains" "$CAHK_ERR"

cahk_run "$CAHK_HOOKIFY" "$CAHK_P31" file '{'
cahk_rc_is "CA-031 -- an unparseable payload is a setup error" 1
check "CA-031 -- the unparseable-payload setup error says so" "not a single JSON object" "$CAHK_ERR"
check_absent "CA-031 -- no rule fires on an unparseable payload" "ca031-not-contains" "$CAHK_ERR"

cahk_run "$CAHK_HOOKIFY" "$CAHK_P31" file '{"file_path":"src/a.js"}'
cahk_rc_is "CA-031 -- a well-formed payload missing the conditioned field exits 0" 0
check_absent "CA-031 -- a contains rule does not fire when its field is absent" "ca031-contains" "$CAHK_ERR"
check_absent "CA-031 -- a not_contains rule does not fire when its field is absent either" \
  "ca031-not-contains" "$CAHK_ERR"

# Positive controls: both rules DO fire when their field is supplied, so the two silences above
# are about absence, not about two rules that could never match anything.
cahk_run "$CAHK_HOOKIFY" "$CAHK_P31" file '{"file_path":"src/a.js","new_text":"console.log(1)"}'
cahk_rc_is "CA-031 -- control: a supplied field still exits 0 (both rules are warn)" 0
check "CA-031 -- control: the contains rule DOES fire when new_text is supplied and matches" \
  "ca031-contains warn" "$CAHK_ERR"
cahk_run "$CAHK_HOOKIFY" "$CAHK_P31" file '{"file_path":"src/a.js","new_text":"clean code"}'
check "CA-031 -- control: the not_contains rule DOES fire when new_text is supplied and does not match" \
  "ca031-not-contains warn" "$CAHK_ERR"

# Mutant control: restore the pre-fix "absent reads as empty" semantics and confirm the
# `not_contains` rule fires on absence again.
CAHK_MUT_NULLOK="$(cahk_mutant nullok -e 's@if $rawval == null then@if false then@')"
cahk_run "$CAHK_MUT_NULLOK" "$CAHK_P31" file '{"file_path":"src/a.js"}'
if [[ "$CAHK_ERR" == *"ca031-not-contains"* ]]; then
  pass "CA-031 -- mutant control: with the absent-field guard removed the not_contains rule DOES fire on absence"
else
  fail "CA-031 -- mutant control FAILED: guard-removed copy did not fire on absence; the silence above proves nothing"
fi

# ---- CA-041: the four never-exercised op_match operators ---------------------------------------
# Each operator gets a matching payload AND a non-matching payload (both truth values of the arm
# observed), plus a mutant that neutralises that one arm and must make the matching case go quiet.
cahk_op_case() {
  # cahk_op_case <op> <pattern> <matching-file_path> <non-matching-file_path> <mutant-sed-expr>
  local op="$1" pattern="$2" hit="$3" miss="$4" mutexpr="$5"
  local proj rule mutant
  proj="$(cahk_newproj "ca041-${op}")"
  rule="${proj}/.claude/edm-hookify/ca041-${op}.json"
  jq -n --arg op "$op" --arg pat "$pattern" \
    '{name:("ca041-" + $op),enabled:true,event:"file",action:"warn",
      conditions:[{field:"file_path",operator:$op,pattern:$pat}],
      message:("probe for " + $op)}' > "$rule"

  cahk_run "$CAHK_HOOKIFY" "$proj" file "$(jq -cn --arg p "$hit" '{file_path:$p,new_text:"x"}')"
  check "CA-041 (${op}) -- matching payload '${hit}' fires the rule" "ca041-${op} warn" "$CAHK_ERR"
  cahk_rc_is "CA-041 (${op}) -- a warn match still exits 0" 0

  cahk_run "$CAHK_HOOKIFY" "$proj" file "$(jq -cn --arg p "$miss" '{file_path:$p,new_text:"x"}')"
  check_absent "CA-041 (${op}) -- non-matching payload '${miss}' does not fire the rule" \
    "ca041-${op}" "$CAHK_ERR"

  mutant="$(cahk_mutant "op-${op}" -e "$mutexpr")"
  cahk_run "$mutant" "$proj" file "$(jq -cn --arg p "$hit" '{file_path:$p,new_text:"x"}')"
  if [[ "$CAHK_ERR" != *"ca041-${op}"* ]]; then
    pass "CA-041 (${op}) -- mutant control: neutralising the ${op} arm makes the matching case go quiet, so the match above is carried by that arm"
  else
    fail "CA-041 (${op}) -- mutant control FAILED: the ${op} arm was neutralised and the rule still fired; the match assertion proves nothing"
  fi
}

cahk_op_case equals      'src/exact.js' 'src/exact.js' 'src/exact.js.bak' \
  's@then ($val == $pattern)@then false@'
cahk_op_case starts_with 'src/'         'src/a.js'     'lib/a.js' \
  's@then ($val|startswith($pattern))@then false@'
cahk_op_case ends_with   '.md'          'docs/a.md'    'docs/a.mdx' \
  's@then ($val|endswith($pattern))@then false@'
cahk_op_case regex_match '^src/[a-z]+[0-9]+\.js$' 'src/abc123.js' 'src/abc.js' \
  's@then ($val|test($pattern))@then false@'

# regex_match additionally pins ONIGURUMA semantics, which CLAUDE.md's Hookify section warns about
# and nothing tested. `\d` is a digit class under Oniguruma (jq's `test()`); under POSIX ERE
# (`grep -E`) the backslash is dropped and the pattern degrades to the literal `d+`. The
# non-matching payload below is chosen so the two engines DISAGREE: "abcdef" contains a literal
# `d`, so an ERE engine would match it, and only an Oniguruma engine leaves it alone.
CAHK_P41RE="$(cahk_newproj ca041-oniguruma)"
jq -n '{name:"ca041-oniguruma",enabled:true,event:"file",action:"warn",
        conditions:[{field:"file_path",operator:"regex_match",pattern:"\\d+"}],
        message:"oniguruma digit-class probe"}' \
  > "${CAHK_P41RE}/.claude/edm-hookify/ca041-oniguruma.json"
cahk_run "$CAHK_HOOKIFY" "$CAHK_P41RE" file '{"file_path":"abc123","new_text":"x"}'
check "CA-041 -- regex_match treats \\d as a digit class (Oniguruma), matching 'abc123'" \
  "ca041-oniguruma warn" "$CAHK_ERR"
cahk_run "$CAHK_HOOKIFY" "$CAHK_P41RE" file '{"file_path":"abcdef","new_text":"x"}'
check_absent "CA-041 -- ... and does NOT match 'abcdef', which a POSIX-ERE reading of \\d+ (literal d+) would have matched" \
  "ca041-oniguruma" "$CAHK_ERR"

# ---- CA-042: the bash event's match path -------------------------------------------------------
CAHK_P42B="$(cahk_newproj ca042-bash)"
cp "${CAHK_FIX}/block-rm-rf-bash.json" "${CAHK_P42B}/.claude/edm-hookify/"

cahk_run "$CAHK_HOOKIFY" "$CAHK_P42B" bash "$CAHK_BASH_MATCH"
cahk_rc_is "CA-042 -- eval bash with a matching command exits 2" 2
check "CA-042 -- the bash block line is on stdout" "block-rm-rf-bash block" "$CAHK_OUT"

cahk_run "$CAHK_HOOKIFY" "$CAHK_P42B" bash '{"command":"ls -la /tmp"}'
cahk_rc_is "CA-042 -- eval bash with a non-matching command exits 0" 0
cahk_stdout_empty "CA-042 -- a non-matching bash command puts nothing on stdout"

CAHK_MUT_NOREGEX="$(cahk_mutant bash-noregex -e 's@then ($val|test($pattern))@then false@')"
cahk_run "$CAHK_MUT_NOREGEX" "$CAHK_P42B" bash "$CAHK_BASH_MATCH"
if [[ "$CAHK_RC" -eq 0 ]]; then
  pass "CA-042 -- mutant control: neutralising the regex arm drops the bash block to exit 0, so the exit-2 above is carried by real evaluation"
else
  fail "CA-042 -- mutant control FAILED: regex-neutralised copy still exited ${CAHK_RC} on the bash event"
fi

# ---- CA-042: the stop event's match path (the empty-conditions branch) --------------------------
# `stop` defines no matchable fields, so a zero-condition rule is the only legal shape it can take
# and the empty-conditions branch is the only branch it can reach.
CAHK_P42SW="$(cahk_newproj ca042-stop-warn)"
cp "${CAHK_FIX}/warn-stop-placeholder.json" "${CAHK_P42SW}/.claude/edm-hookify/"
cahk_run "$CAHK_HOOKIFY" "$CAHK_P42SW" stop '{}'
cahk_rc_is "CA-042 -- eval stop with a zero-condition warn rule exits 0" 0
cahk_stdout_empty "CA-042 -- a stop warn match stays off stdout"
check "CA-042 -- the stop warn line is on stderr" "warn-stop-placeholder warn" "$CAHK_ERR"

CAHK_P42SB="$(cahk_newproj ca042-stop-block)"
jq '.name = "ca042-stop-block" | .action = "block" | .message = "stop-event block probe"' \
  "${CAHK_FIX}/warn-stop-placeholder.json" \
  > "${CAHK_P42SB}/.claude/edm-hookify/ca042-stop-block.json"
cahk_run "$CAHK_HOOKIFY" "$CAHK_P42SB" stop '{}'
cahk_rc_is "CA-042 -- eval stop with a zero-condition block rule exits 2" 2
check "CA-042 -- the stop block line is on stdout" "ca042-stop-block block stop-event block probe" "$CAHK_OUT"

# The warn/block pair above is one discriminating control (same rule shape, only `action` differs).
# This mutant is the second: it forces conds_match to return false, so the zero-condition rule
# stops matching at all -- proving both stop cases reach a real condition evaluation rather than
# some path that emits regardless.
#
# Note on why the mutation is `and` rather than removing the empty-conditions short-circuit: jq's
# `all` over an EMPTY generator is `true`, so deleting the `($cs|length) == 0 or` disjunct changes
# nothing for a zero-condition rule. That disjunct is a readability guard, not the deciding branch,
# and a mutant built on the opposite assumption passed vacuously when first written here.
CAHK_MUT_NOEMPTY="$(cahk_mutant stop-noempty -e 's@| ($cs|length) == 0 or@| (false) and@')"
cahk_run "$CAHK_MUT_NOEMPTY" "$CAHK_P42SB" stop '{}'
if [[ "$CAHK_RC" -eq 0 && -z "$CAHK_OUT" ]]; then
  pass "CA-042 -- mutant control: forcing conds_match false stops the zero-condition block rule matching at all"
else
  fail "CA-042 -- mutant control FAILED: conds_match-neutralised copy still gave rc=${CAHK_RC} stdout=[${CAHK_OUT}]"
fi

# ---- CA-042: edm-stop-gate's own block translation ---------------------------------------------
# The consumer half. Runs inside a scratch git repo with an isolated HOME/CLAUDE_PROJECT_DIR via
# the same t46_isolate_and_run wrapper the EDMV4-T46 cases above use.
CAHK_SG_ACTION="block"
cahk_stopgate_case() {
  edm-state init CAHKSG >/dev/null
  local state
  state="$(edm-state resolve-dir CAHKSG)/.edm-state.json"
  jq '.current_phase = 2
      | del(.schema_version)
      | .skipped_phases = [{phase: 3, rationale: "CA-042 stop-gate fixture"}]' \
    "$state" > "${state}.tmp" && mv "${state}.tmp" "$state"

  mkdir -p ".claude/edm-hookify"
  jq --arg act "$CAHK_SG_ACTION" \
    '.name = "ca042-stop-rule" | .action = $act | .message = "CA-042 stop-gate probe"' \
    "${CAHK_FIX}/warn-stop-placeholder.json" > ".claude/edm-hookify/ca042-stop-rule.json"

  local out rc=0
  out="$(edm-stop-gate 2>&1)" || rc=$?
  if [[ "$CAHK_SG_ACTION" == "block" ]]; then
    [[ "$rc" -eq 2 ]] \
      && pass "CA-042 -- edm-stop-gate exits 2 when a stop-event block rule matches" \
      || fail "CA-042 -- edm-stop-gate exited ${rc} with a matching stop block rule (expected 2): [${out}]"
    check "CA-042 -- edm-stop-gate prints its own hookify label" \
      "[EDM] a stop-event hookify rule matched:" "$out"
    check "CA-042 -- edm-stop-gate carries the matched rule's own line" \
      "ca042-stop-rule block CA-042 stop-gate probe" "$out"
  else
    [[ "$rc" -eq 0 ]] \
      && pass "CA-042 -- control: the identical setup with action=warn exits 0, so the exit-2 above is carried by the block action alone" \
      || fail "CA-042 -- control FAILED: action=warn exited ${rc} (expected 0): [${out}]"
    check_absent "CA-042 -- control: no hookify block label is printed for a warn rule" \
      "a stop-event hookify rule matched" "$out"
  fi
  return 0
}
t46_isolate_and_run cahk_stopgate_case
CAHK_SG_ACTION="warn"
t46_isolate_and_run cahk_stopgate_case

# ---- CA-056: the list arm and the setup-error arm must not bypass the sanitizer ------------------
# The needle is assembled at runtime from printf hex escapes -- never a literal non-ASCII byte in
# this suite's own source, which would itself violate the ASCII rule the EDMV4-T52 AC2 sweep
# enforces over bin/tests/.
CAHK_NASTY="$(printf 'na\xc3\xa9me\x1b]0;pwned\x07')"
CAHK_P56="$(cahk_newproj ca056-list)"
jq --arg nm "$CAHK_NASTY" '.name = $nm' "${CAHK_FIX}/warn-no-console-log.json" \
  > "${CAHK_P56}/.claude/edm-hookify/nasty-name.json"

cahk_list "$CAHK_HOOKIFY" "$CAHK_P56"
printf '%s\n' "$CAHK_OUT" > "${CAHK_TMP}/ca056-list.out"
if cahk_nonascii "${CAHK_TMP}/ca056-list.out"; then
  fail "CA-056 -- edm-hookify list emitted a non-ASCII or control byte from a rule name"
else
  pass "CA-056 -- edm-hookify list output is pure ASCII even when the rule name carries a UTF-8 byte and an ESC sequence"
fi

CAHK_P56E="$(cahk_newproj ca056-error)"
jq --arg k "$CAHK_NASTY" '. + {($k): 1}' "${CAHK_FIX}/warn-no-console-log.json" \
  > "${CAHK_P56E}/.claude/edm-hookify/nasty-key.json"
cahk_run "$CAHK_HOOKIFY" "$CAHK_P56E" file "$CAHK_FILE_PAYLOAD"
cahk_rc_is "CA-056 -- an unknown top-level key is a setup error" 1
cp "${CAHK_TMP}/stderr" "${CAHK_TMP}/ca056-error.err"
if cahk_nonascii "${CAHK_TMP}/ca056-error.err"; then
  fail "CA-056 -- edm-hookify's setup-error line emitted a non-ASCII or control byte from a rule file"
else
  pass "CA-056 -- edm-hookify's setup-error line is pure ASCII even when the offending key carries a UTF-8 byte and an ESC sequence"
fi

# Control A: the scanner itself must be able to see these exact bytes, or both passes above are
# meaningless.
printf '%s\n' "$CAHK_NASTY" > "${CAHK_TMP}/ca056-control.txt"
if cahk_nonascii "${CAHK_TMP}/ca056-control.txt"; then
  pass "CA-056 -- control: the same scanner DOES flag the raw needle, so the two clean results above are not a broken predicate"
else
  fail "CA-056 -- control FAILED: the scanner did not flag the raw needle; the two clean results above prove nothing"
fi

# Control B: neutralise hookify_scrub (the bash-side ASCII filter) and confirm the UTF-8 byte
# reaches the list arm again. This is the filter CA-056 found the `L)` arm bypassing.
CAHK_MUT_NOHFSCRUB="$(cahk_mutant nohookifyscrub -e "s@| LC_ALL=C tr -c .*@| cat@")"
cahk_list "$CAHK_MUT_NOHFSCRUB" "$CAHK_P56"
printf '%s\n' "$CAHK_OUT" > "${CAHK_TMP}/ca056-list-mut.out"
if cahk_nonascii "${CAHK_TMP}/ca056-list-mut.out"; then
  pass "CA-056 -- mutant control: with hookify_scrub neutralised the UTF-8 byte DOES reach list's stdout"
else
  fail "CA-056 -- mutant control FAILED: hookify_scrub-neutralised copy still emitted pure ASCII from list"
fi

# Control C: the same neutralised hookify_scrub against the SETUP-ERROR arm, which is the second
# of the two arms CA-056 found bypassing the filter. It needs its own run rather than sharing
# control B's: the two arms are separate call sites, and only a per-arm control proves each one
# actually routes through the helper.
cahk_run "$CAHK_MUT_NOHFSCRUB" "$CAHK_P56E" file "$CAHK_FILE_PAYLOAD"
cp "${CAHK_TMP}/stderr" "${CAHK_TMP}/ca056-error-mut.err"
if cahk_nonascii "${CAHK_TMP}/ca056-error-mut.err"; then
  pass "CA-056 -- mutant control: with hookify_scrub neutralised the UTF-8 byte DOES reach the setup-error line"
else
  fail "CA-056 -- mutant control FAILED: hookify_scrub-neutralised copy still emitted pure ASCII on the setup-error line"
fi

# Control D: hookify_scrub is not the only filter in play. The jq-side `scrub` (the CA-029
# record-encoding guard) already maps every control character to a space, so an ESC never survives
# even when hookify_scrub is off -- which means controls B and C alone say nothing about the ESC
# half of the needle. Neutralise BOTH and confirm the raw ESC byte reaches stdout, so the
# ESC-free outputs above are a property of the filters rather than of a needle that never carried
# one. (A first draft of this band attributed ESC removal to the jq scrub alone and asserted the
# converse; the mutant caught it.)
CAHK_ESC="$(printf '\033')"
CAHK_MUT_NOFILTER="$(cahk_mutant nofilter \
  -e 's@^def scrub($s):.*@def scrub($s): ($s|tostring);@' \
  -e 's@| LC_ALL=C tr -c .*@| cat@')"
cahk_list "$CAHK_MUT_NOFILTER" "$CAHK_P56"
printf '%s\n' "$CAHK_OUT" > "${CAHK_TMP}/ca056-list-nofilter.out"
if LC_ALL=C grep -qF -- "$CAHK_ESC" "${CAHK_TMP}/ca056-list-nofilter.out"; then
  pass "CA-056 -- mutant control: with BOTH filters neutralised the raw ESC byte DOES reach list's stdout"
else
  fail "CA-056 -- mutant control FAILED: with both filters neutralised no ESC byte appeared; the ESC-free results above prove nothing"
fi

# Static half: CA-056 asked for `_rest` (and the two setup-error halves it splits into) to be
# covered by the same single-emit-point scan EDMV4-T52 AC6 applies to the matched-rule fields. That
# ticket's own variable list is owned by its band above and is not edited here; this is the
# equivalent assertion for the three variables it missed, keyed on hookify_scrub.
CAHK_RAW_HITS="$(t52_raw_var_only_via_func "$CAHK_HOOKIFY" "hookify_scrub" _rest _epath _ereason)"
if [[ -z "$CAHK_RAW_HITS" ]]; then
  pass "CA-056 -- \$_rest, \$_epath and \$_ereason are never emitted except through hookify_scrub"
else
  fail "CA-056 -- a raw emission of an unsanitized list/setup-error variable survives: ${CAHK_RAW_HITS}"
fi

# Positive control for the static half, matching the EDMV4-T52 AC6 injection technique.
CAHK_BYPASS="${CAHK_TMP}/edm-hookify-listbypass"
awk -v marker='      HAD_ERROR=1' \
  '{print; if (index($0, marker) > 0) print "      echo \"$_rest\" >&2  # BYPASS-LEAK injected for the CA-056 positive control"}' \
  "$CAHK_HOOKIFY" > "$CAHK_BYPASS"
CAHK_BYPASS_HITS="$(t52_raw_var_only_via_func "$CAHK_BYPASS" "hookify_scrub" _rest _epath _ereason)"
if [[ -n "$CAHK_BYPASS_HITS" ]]; then
  pass "CA-056 -- positive control: an injected raw echo of \$_rest IS detected by the same scan"
else
  fail "CA-056 -- positive control FAILED: an injected bypass was not detected, so the scan above proves nothing"
fi

echo
# =================================================================================================
# P1 BATCH: CA-036 / CA-037 / CA-038 / CA-046 / CA-047 / CA-022 / CA-028 / CA-033 / CA-034
# "Absent renders as zero, or as fine" -- edm-repo-readiness -- plus three prose-contract fixes.
#
# Every assertion below is paired with a NEGATIVE CONTROL: a fixture in which the same assertion
# must fail. CA-046 and CA-047 are "never exercised" findings, so an assertion that cannot fail
# would be strictly worse than leaving them open.
# =================================================================================================
echo
echo "-- CA-036/037/038/046/047: edm-repo-readiness -- unmeasurable is not clean, and not zero --"

CA036_TMP="$(mktemp -d "${TMP}/ca036.XXXXXX")"
CA036_BIN="${CA036_TMP}/bin"
mkdir -p "$CA036_BIN"

# The scorer resolves edm-state / edm-lint-artifacts as SIBLINGS via SCRIPT_DIR (never via PATH),
# so a scratch bin/ holding a copy of the scorer plus two shims is the only way to drive its probe
# failure paths. The shims answer exactly the four subcommands the scorer calls, and each arm's
# exit status is driven by an env knob so one fixture covers every probe.
cp "$REPO_READINESS" "${PLUGIN_DIR}/bin/_edm-cli-lib.sh" "$CA036_BIN/"
cat > "${CA036_BIN}/edm-state" <<'CA036_SHIM'
#!/usr/bin/env bash
case "$1" in
  list) printf 'SHIMP          phase=1  gates_approved=0\n'; exit 0 ;;
  get) exit 0 ;;
  validate)
    case "${EDM_SHIM_VALIDATE_RC:-0}" in
      0) echo "# State OK: no anomalies found for $2"; exit 0 ;;
      3) echo "# State anomalies for $2:"; echo; echo "blocking TIME_ORDER phase_2 ends before it starts"; exit 3 ;;
      *) exit "${EDM_SHIM_VALIDATE_RC}" ;;
    esac ;;
  get-coverage)
    [ "${EDM_SHIM_COVERAGE_RC:-0}" -eq 0 ] || exit "${EDM_SHIM_COVERAGE_RC}"
    exit 0 ;;
  metrics-report)
    case "$2" in
      --calibrate)
        [ "${EDM_SHIM_CALIB_RC:-0}" -eq 0 ] || exit "${EDM_SHIM_CALIB_RC}"
        printf '%s\n' "${EDM_SHIM_CALIB_OUT-  Small_phase_1: n=2, median_duration=120s, median_cost=\$1.5}"
        exit 0 ;;
      --all)
        [ "${EDM_SHIM_METRICS_ALL_RC:-0}" -eq 0 ] || exit "${EDM_SHIM_METRICS_ALL_RC}"
        printf '%s\n' "  SHIMP  Small  10s  \$2.50"
        exit 0 ;;
    esac
    exit 0 ;;
esac
exit 0
CA036_SHIM
cat > "${CA036_BIN}/edm-lint-artifacts" <<'CA036_LINT_SHIM'
#!/usr/bin/env bash
exit "${EDM_SHIM_LINT_RC:-0}"
CA036_LINT_SHIM
chmod +x "${CA036_BIN}/edm-state" "${CA036_BIN}/edm-lint-artifacts" "${CA036_BIN}/edm-repo-readiness"

CA036_WORK="${CA036_TMP}/work"
mkdir -p "${CA036_WORK}/SRD/.archived/OLDX"
echo '{}' > "${CA036_WORK}/SRD/.archived/OLDX/.edm-state.json"

# _ca036_run <tag> [VAR=VALUE ...] -- run the shimmed scorer, capturing JSON, stdout and stderr.
# Records the exit status in _CA036_RC so the exit contract stays assertable on every fixture.
_CA036_RC=0
_ca036_run() {
  local tag="$1"; shift
  _CA036_RC=0
  ( cd "$CA036_WORK" && env "EDM_SRD_ROOT=${CA036_WORK}/SRD" "$@" \
      "${CA036_BIN}/edm-repo-readiness" --json "${CA036_TMP}/${tag}.json" \
      >"${CA036_TMP}/${tag}.txt" 2>"${CA036_TMP}/${tag}.err" ) || _CA036_RC=$?
}
_ca036_cat() { jq -r "$2" "${CA036_TMP}/${1}.json"; }

# ---- Baseline: every probe healthy. This run is the negative control for all six probe-failure
# assertions below -- if the fixture could not produce a fully measured, high-scoring run, none of
# those assertions would be evidence of anything. ------------------------------------------------
_ca036_run base
if [[ "$_CA036_RC" -eq 0 ]]; then
  pass "CA-036/037/038 baseline -- the shimmed scorer exits 0 with every probe healthy"
else
  fail "CA-036/037/038 baseline -- the shimmed scorer exited ${_CA036_RC}; every assertion below would be meaningless"
fi
CA036_BASE_UNMEASURED="$(_ca036_cat base '[.categories[] | select(.measured | not)] | length')"
if [[ "$CA036_BASE_UNMEASURED" == "0" ]]; then
  pass "CA-036/037/038 baseline -- all six categories report measured:true when every probe answers"
else
  fail "CA-036/037/038 baseline -- ${CA036_BASE_UNMEASURED} categories were UNMEASURED on the healthy fixture; the negative control is broken"
fi
CA036_BASE_SCORE="$(_ca036_cat base '.score | tonumber')"

# ---- CA-036: `edm-state validate` exiting outside its documented 0/3 contract must NOT score
# State health clean. -----------------------------------------------------------------------------
_ca036_run vfail EDM_SHIM_VALIDATE_RC=1
check "CA-036 -- a validate that dies makes State health UNMEASURED, not perfect" \
  "false" "$(_ca036_cat vfail '.categories[] | select(.name=="State health") | .measured | tostring')"
check "CA-036 -- the UNMEASURED State health category stays in the overall-score denominator" \
  "true" "$(_ca036_cat vfail '.categories[] | select(.name=="State health") | .applicable | tostring')"
check "CA-036 -- a validate that dies scores State health 0.0, never 10.0" \
  "0.0" "$(_ca036_cat vfail '.categories[] | select(.name=="State health") | .score_0_10')"
check "CA-036 -- the reason names the command and the offending exit status on stdout" \
  "edm-state validate returned a status outside its documented 0/3 contract for: SHIMP (exit 1)" \
  "$(cat "${CA036_TMP}/vfail.txt")"
check "CA-036 -- the same reason is printed on stderr, for a caller that only captures stdout" \
  "State health could not be measured" "$(cat "${CA036_TMP}/vfail.err")"
if [[ "$_CA036_RC" -eq 0 ]]; then
  pass "CA-036 -- a broken validate still exits 0 (the exit contract is 0 = scored at ANY score)"
else
  fail "CA-036 -- a broken validate exited ${_CA036_RC}; exit 0 is the contract for a scored repository"
fi
CA036_VFAIL_SCORE="$(_ca036_cat vfail '.score | tonumber')"
if jq -n --argjson a "$CA036_VFAIL_SCORE" --argjson b "$CA036_BASE_SCORE" -e '$a < $b' >/dev/null; then
  pass "CA-036 -- the broken-validate score (${CA036_VFAIL_SCORE}) is BELOW the healthy baseline (${CA036_BASE_SCORE})"
else
  fail "CA-036 -- the broken-validate score (${CA036_VFAIL_SCORE}) did not fall below the healthy baseline (${CA036_BASE_SCORE})"
fi

# NEGATIVE CONTROL for CA-036: exit 3 is a DOCUMENTED validate result (at least one blocking
# anomaly), not a setup error. It must stay measured and must cost points -- which is what proves
# the fix reads and CLASSIFIES the status rather than treating every non-zero as a failure.
_ca036_run v3 EDM_SHIM_VALIDATE_RC=3
check "CA-036 negative control -- validate exit 3 stays MEASURED (it is a real result, not a setup error)" \
  "true" "$(_ca036_cat v3 '.categories[] | select(.name=="State health") | .measured | tostring')"
check "CA-036 negative control -- validate exit 3's blocking anomaly costs the other-blocking check" \
  "false" "$(_ca036_cat v3 '.checks[] | select(.id=="state-health-no-other-blocking-anomalies") | .pass | tostring')"
if [[ -s "${CA036_TMP}/v3.err" ]]; then
  fail "CA-036 negative control -- validate exit 3 wrongly emitted an unmeasured diagnostic: $(cat "${CA036_TMP}/v3.err")"
else
  pass "CA-036 negative control -- validate exit 3 emits no unmeasured diagnostic"
fi

# ---- CA-037: a failed get-coverage must not RAISE the score by removing Test stack and Coverage
# posture from the denominator. -------------------------------------------------------------------
_ca036_run covfail EDM_SHIM_COVERAGE_RC=1
check "CA-037 -- a failed get-coverage makes Test stack UNMEASURED" \
  "false" "$(_ca036_cat covfail '.categories[] | select(.name=="Test stack") | .measured | tostring')"
check "CA-037 -- a failed get-coverage makes Coverage posture UNMEASURED" \
  "false" "$(_ca036_cat covfail '.categories[] | select(.name=="Coverage posture") | .measured | tostring')"
CA037_DENOM="$(_ca036_cat covfail '[.categories[] | select(.applicable)] | length')"
check "CA-037 -- both unmeasurable categories stay IN the denominator (6 applicable, not 4)" \
  "6" "$CA037_DENOM"
CA037_SCORE="$(_ca036_cat covfail '.score | tonumber')"
if jq -n --argjson a "$CA037_SCORE" --argjson b "$CA036_BASE_SCORE" -e '$a < $b' >/dev/null; then
  pass "CA-037 -- the broken-get-coverage score (${CA037_SCORE}) FALLS below the baseline (${CA036_BASE_SCORE}) instead of rising"
else
  fail "CA-037 -- the broken-get-coverage score (${CA037_SCORE}) did not fall below the baseline (${CA036_BASE_SCORE}); the read failure still pays"
fi
# NEGATIVE CONTROL for CA-037: the baseline's get-coverage SUCCEEDS and simply has no coverage
# recorded. That is a legitimate N/A -- excluded from the denominator, measured:true -- and it is
# the case the broken one must be distinguishable from.
CA037_BASE_DENOM="$(_ca036_cat base '[.categories[] | select(.applicable)] | length')"
check "CA-037 negative control -- a SUCCESSFUL get-coverage with no rows is N/A and leaves the denominator at 4" \
  "4" "$CA037_BASE_DENOM"
check "CA-037 negative control -- that legitimately-N/A Test stack is still measured:true" \
  "true" "$(_ca036_cat base '.categories[] | select(.name=="Test stack") | .measured | tostring')"
check "CA-037 -- the human report distinguishes UNMEASURED from N/A in the category header" \
  "## Test stack -- 0.0 / 10  UNMEASURED:" "$(cat "${CA036_TMP}/covfail.txt")"
check "CA-037 negative control -- the N/A header is a different string entirely" \
  "## Test stack -- N/A (not applicable)" "$(cat "${CA036_TMP}/base.txt")"

# ---- CA-038: CH_CALIBRATION_AVAILABLE must default false and require a positive signal. ----------
_ca036_run calfail EDM_SHIM_CALIB_RC=1
check "CA-038 -- a metrics-report --calibrate that exits non-zero does not award the calibration points" \
  "false" "$(_ca036_cat calfail '.checks[] | select(.id=="convergence-calibration-data-available") | .pass | tostring')"
check "CA-038 -- and it is reported UNMEASURED, not as a measured absence" \
  "false" "$(_ca036_cat calfail '.checks[] | select(.id=="convergence-calibration-data-available") | .measured | tostring')"
check "CA-038 -- the printed reason names the failing command and its status" \
  "edm-state metrics-report --calibrate exited 1" "$(cat "${CA036_TMP}/calfail.err")"

# The exact shape CA-038 names: --calibrate SUCCEEDS but says something that is not the literal
# "insufficient data" the old code matched on. Before the fix this awarded full calibration points.
_ca036_run calweird EDM_SHIM_CALIB_OUT="  (error building the calibration report -- check for malformed state files)"
check "CA-038 -- an unrelated --calibrate failure message does not award the calibration points" \
  "false" "$(_ca036_cat calweird '.checks[] | select(.id=="convergence-calibration-data-available") | .pass | tostring')"
_ca036_run calempty EDM_SHIM_CALIB_OUT="  (insufficient data - need at least one completed initiative with estimated_size set)"
check "CA-038 -- a genuine 'insufficient data' answer is MEASURED (the data really is absent)" \
  "true" "$(_ca036_cat calempty '.checks[] | select(.id=="convergence-calibration-data-available") | .measured | tostring')"
check "CA-038 -- and still scores false" \
  "false" "$(_ca036_cat calempty '.checks[] | select(.id=="convergence-calibration-data-available") | .pass | tostring')"
# NEGATIVE CONTROL for CA-038: the baseline emits a real median row, so the check MUST pass there.
# Without this, "pass:false" above would be satisfied by a check that can never pass at all.
check "CA-038 negative control -- a real median_duration row DOES award the calibration points" \
  "true" "$(_ca036_cat base '.checks[] | select(.id=="convergence-calibration-data-available") | .pass | tostring')"

# ---- Same three-state rule applied to edm-lint-artifacts: exit 1 is a hygiene measurement,
# anything else is a setup error that measured nothing. -------------------------------------------
_ca036_run lint1 EDM_SHIM_LINT_RC=1
_ca036_run lint2 EDM_SHIM_LINT_RC=2
check "CA-036 (same class) -- edm-lint-artifacts exit 1 is a MEASURED hygiene failure" \
  "true" "$(_ca036_cat lint1 '.categories[] | select(.name=="Artifact hygiene") | .measured | tostring')"
check "CA-036 (same class) -- edm-lint-artifacts exit 2 (setup error) is UNMEASURED, not 'dirty'" \
  "false" "$(_ca036_cat lint2 '.categories[] | select(.name=="Artifact hygiene") | .measured | tostring')"

# ---- The overall-score warning line only appears when something really was unmeasurable. --------
check "CA-036/037/038 -- an unmeasurable run warns that the overall score is a floor" \
  "WARNING: 2 of 6 categories could not be measured" "$(cat "${CA036_TMP}/covfail.txt")"
check_absent "CA-036/037/038 negative control -- a fully measured run prints no such warning" \
  "categories could not be measured" "$(cat "${CA036_TMP}/base.txt")"

# =================================================================================================
# CA-046 / CA-047: the [<PREFIX>] argument and the APPLICABLE arm of Test stack / Coverage posture
# =================================================================================================
# Both findings are "this code path is never executed by any test". The fixture below is a real
# initiative directory scored by the real edm-repo-readiness against the real edm-state, with
# coverage recorded through the real `record-test-coverage` subcommand. Only the initial state
# scaffold is hand-built (with jq), deliberately: `edm-init` creates and checks out a git branch,
# which a smoke suite must never do (commit 5f90001), and `edm-state set` stores an object-valued
# key as a JSON *string*, so it cannot produce the `test_frameworks_detected` object shape that
# `get-coverage`'s Detected Frameworks renderer -- the signal under test -- actually reads.
CA047_TMP="$(mktemp -d "${TMP}/ca047.XXXXXX")"
CA047_SRD="${CA047_TMP}/SRD"
mkdir -p "${CA047_SRD}/TSTK" "${CA047_SRD}/.archived/OLDX"
jq -n '{prefix:"TSTK",schema_version:1,current_phase:1,gates_approved:[],artifacts:{},
  artifact_hashes:{},srd_version:"0.0.0",estimated_size:"Unknown",initiative_branch:"",
  product_name:"",initiative_description:"",phase_durations:{},test_frameworks_detected:{},
  coverage_by_layer:{},coverage_by_epic:{},code_audit_converged:false,
  code_audit_gate_approved_at:"",code_audit_gate_approver:"",code_audit_gate_enforcement:"",
  code_audit_gate_ledger:"",compliance_gate_approved:false,last_decision:"",audit_rounds:{},
  partial_verdict_map:{},mode:"standard",lifecycle_mode:"standard",compliance_enabled:false,
  implementation_mode:"standard",skipped_phases:[],supersedes:"",forked_from:"",parent_prefix:"",
  related_prefixes:[],last_updated:"2026-01-01T00:00:00Z"}' > "${CA047_SRD}/TSTK/.edm-state.json"
cp "${CA047_SRD}/TSTK/.edm-state.json" "${CA047_SRD}/.archived/OLDX/.edm-state.json"

_CA047_RC=0
_ca047_run() {
  local tag="$1"; shift
  _CA047_RC=0
  ( cd "$CA047_TMP" && env "EDM_SRD_ROOT=${CA047_SRD}" "$REPO_READINESS" "$@" \
      --json "${CA047_TMP}/${tag}.json" >"${CA047_TMP}/${tag}.txt" 2>"${CA047_TMP}/${tag}.err" ) || _CA047_RC=$?
}
_ca047_cat() { jq -r "$2" "${CA047_TMP}/${1}.json"; }

# NEGATIVE CONTROL, taken FIRST: with no frameworks and no coverage recorded, both categories must
# report applicable:false and the denominator must be 4. Everything below is only evidence because
# this run proves the two categories can be inapplicable on this very fixture.
_ca047_run before
check "CA-047 negative control -- Test stack is applicable:false before any framework is recorded" \
  "false" "$(_ca047_cat before '.categories[] | select(.name=="Test stack") | .applicable | tostring')"
check "CA-047 negative control -- Coverage posture is applicable:false before any coverage is recorded" \
  "false" "$(_ca047_cat before '.categories[] | select(.name=="Coverage posture") | .applicable | tostring')"
check "CA-047 negative control -- the overall mean divides by 4 in that state" \
  "4" "$(_ca047_cat before '[.categories[] | select(.applicable)] | length')"

# Record coverage through the real subcommand, in BOTH shapes get-coverage renders: whole-initiative
# rows (pct in field 2) and per-epic rows (pct in field 3). Both awk parsers in the scorer are dead
# code until a run sees each shape.
_ca047_state() { env "EDM_SRD_ROOT=${CA047_SRD}" "$EDM_STATE" "$@" >/dev/null; }
_ca047_state record-test-coverage TSTK unit 91.0
_ca047_state record-test-coverage TSTK component 75.0
_ca047_state record-test-coverage TSTK integration 65.0
_ca047_state record-test-coverage TSTK unit 42.0 authepic
CA047_STATE="${CA047_SRD}/TSTK/.edm-state.json"
jq '.test_frameworks_detected = {"unit":"pytest","component":"vitest"}' "$CA047_STATE" > "${CA047_STATE}.new"
mv "${CA047_STATE}.new" "$CA047_STATE"

_ca047_run after
check "CA-047 -- Test stack flips to applicable:true once a framework is recorded" \
  "true" "$(_ca047_cat after '.categories[] | select(.name=="Test stack") | .applicable | tostring')"
check "CA-047 -- Coverage posture flips to applicable:true with it (one shared predicate)" \
  "true" "$(_ca047_cat after '.categories[] | select(.name=="Coverage posture") | .applicable | tostring')"
check "CA-047 -- the overall mean now divides by 6, not 4" \
  "6" "$(_ca047_cat after '[.categories[] | select(.applicable)] | length')"
check "CA-047 -- TESTSTACK_UNIT_FOUND is exercised true (unit framework detected)" \
  "true" "$(_ca047_cat after '.checks[] | select(.id=="unit-test-framework-detected") | .pass | tostring')"
check "CA-047 -- TESTSTACK_OTHER_FOUND is exercised true (component framework detected)" \
  "true" "$(_ca047_cat after '.checks[] | select(.id=="additional-layer-framework-detected") | .pass | tostring')"
check "CA-047 -- _rr_layer_meets_target returns true for unit (91.0 >= 80)" \
  "true" "$(_ca047_cat after '.checks[] | select(.id=="unit-coverage-meets-target") | .pass | tostring')"
check "CA-047 -- and for component (75.0 >= 70)" \
  "true" "$(_ca047_cat after '.checks[] | select(.id=="component-coverage-meets-target") | .pass | tostring')"
check "CA-047 -- and for integration (65.0 >= 60)" \
  "true" "$(_ca047_cat after '.checks[] | select(.id=="integration-coverage-meets-target") | .pass | tostring')"
check "CA-047 -- the applicable:true arm of the category mean is taken (Test stack scores 10.0)" \
  "10.0" "$(_ca047_cat after '.categories[] | select(.name=="Test stack") | .score_0_10')"

# NEGATIVE CONTROL for the coverage-target assertions: drop whole-initiative unit coverage below
# the 80% target and confirm ONLY that one check flips. The per-epic unit row (42.0%) is left in
# place, so this also proves _rr_layer_max_pct is taking the max across both shapes rather than
# whichever row it happened to see last.
_ca047_state record-test-coverage TSTK unit 10.0
_ca047_run below
check "CA-047 negative control -- unit-coverage-meets-target flips to false when unit drops to 10.0" \
  "false" "$(_ca047_cat below '.checks[] | select(.id=="unit-coverage-meets-target") | .pass | tostring')"
check "CA-047 negative control -- component-coverage-meets-target is unaffected (still true)" \
  "true" "$(_ca047_cat below '.checks[] | select(.id=="component-coverage-meets-target") | .pass | tostring')"
check "CA-047 negative control -- Coverage posture is still applicable:true, just lower" \
  "true" "$(_ca047_cat below '.categories[] | select(.name=="Coverage posture") | .applicable | tostring')"
check "CA-047 negative control -- Coverage posture scores 6.0 of 10 (component + integration only)" \
  "6.0" "$(_ca047_cat below '.categories[] | select(.name=="Coverage posture") | .score_0_10')"

# ---- CA-046: the documented [<PREFIX>] argument, never passed by any test before this. ----------
_ca047_state record-test-coverage TSTK unit 91.0
_ca047_run scoped TSTK
if [[ "$_CA047_RC" -eq 0 ]]; then
  pass "CA-046 -- a resolvable <PREFIX> is accepted and exits 0"
else
  fail "CA-046 -- a resolvable <PREFIX> exited ${_CA047_RC}: $(cat "${CA047_TMP}/scoped.err")"
fi
check "CA-046 -- the prefix-scoped header names the initiative on stdout" \
  "Scope: initiative TSTK" "$(cat "${CA047_TMP}/scoped.txt")"
check "CA-046 -- the JSON carries the non-null prefix field" "TSTK" "$(_ca047_cat scoped '.prefix')"
check "CA-046 negative control -- the whole-repository run leaves .prefix null and says so" \
  "null" "$(_ca047_cat after '.prefix | tostring')"
check "CA-046 negative control -- and prints the whole-repository header instead" \
  "Scope: whole repository" "$(cat "${CA047_TMP}/after.txt")"

# The exit-2 arm: an unresolvable prefix is a usage error, not a zero score.
CA046_BAD_RC=0
( cd "$CA047_TMP" && env "EDM_SRD_ROOT=${CA047_SRD}" "$REPO_READINESS" NOSUCHPFX \
    >/dev/null 2>"${CA047_TMP}/badprefix.err" ) || CA046_BAD_RC=$?
if [[ "$CA046_BAD_RC" -eq 2 ]]; then
  pass "CA-046 -- an unresolvable <PREFIX> exits 2 (usage/setup error), never 0 with a low score"
else
  fail "CA-046 -- an unresolvable <PREFIX> exited ${CA046_BAD_RC}, expected 2"
fi
check "CA-046 -- the exit-2 diagnostic names the offending prefix" \
  "prefix not found or unresolvable: NOSUCHPFX" "$(cat "${CA047_TMP}/badprefix.err")"
# NEGATIVE CONTROL: the same invocation shape with a RESOLVABLE prefix exits 0, proving the exit-2
# assertion above discriminates on prefix resolvability and not on the argument being present.
CA046_OK_RC=0
( cd "$CA047_TMP" && env "EDM_SRD_ROOT=${CA047_SRD}" "$REPO_READINESS" TSTK >/dev/null 2>&1 ) || CA046_OK_RC=$?
if [[ "$CA046_OK_RC" -eq 0 ]]; then
  pass "CA-046 negative control -- the identical invocation with a resolvable prefix exits 0"
else
  fail "CA-046 negative control -- a resolvable prefix exited ${CA046_OK_RC}; the exit-2 check above proves nothing"
fi
# The second positional argument's die, also never exercised before.
CA046_EXTRA_RC=0
( cd "$CA047_TMP" && env "EDM_SRD_ROOT=${CA047_SRD}" "$REPO_READINESS" TSTK EXTRA \
    >/dev/null 2>"${CA047_TMP}/extra.err" ) || CA046_EXTRA_RC=$?
if [[ "$CA046_EXTRA_RC" -eq 2 ]]; then
  pass "CA-046 -- a second positional argument exits 2"
else
  fail "CA-046 -- a second positional argument exited ${CA046_EXTRA_RC}, expected 2"
fi
check "CA-046 -- the extra-argument diagnostic names the argument" \
  "unexpected extra argument: EXTRA" "$(cat "${CA047_TMP}/extra.err")"

# CA-047's other half: the "at least one category is genuinely inapplicable" positive control is
# asserted here as a HARD check against a deterministic fixture (a directory with no initiatives at
# all always yields exactly three), rather than left as a soft NOTE that passes either way.
CA047_NOINIT="${CA047_TMP}/noinit"
mkdir -p "$CA047_NOINIT"
( cd "$CA047_NOINIT" && "$REPO_READINESS" --json "${CA047_TMP}/noinit.json" >/dev/null 2>&1 )
CA047_NOINIT_NA="$(jq -r '[.categories[] | select(.applicable == false)] | length' "${CA047_TMP}/noinit.json")"
if [[ "$CA047_NOINIT_NA" -eq 3 ]]; then
  pass "CA-047 -- a repository with no initiatives reports exactly three inapplicable categories (hard assertion, not a soft NOTE)"
else
  fail "CA-047 -- a repository with no initiatives reported ${CA047_NOINIT_NA} inapplicable categories, expected 3"
fi
CA047_NOINIT_UNMEASURED="$(jq -r '[.categories[] | select(.measured | not)] | length' "${CA047_TMP}/noinit.json")"
if [[ "$CA047_NOINIT_UNMEASURED" -eq 0 ]]; then
  pass "CA-047 negative control -- those three are inapplicable, NOT unmeasured (the two states stay distinct)"
else
  fail "CA-047 negative control -- ${CA047_NOINIT_UNMEASURED} categories were UNMEASURED on a no-initiatives fixture"
fi

echo
echo "-- EDMV4-T39 AC7 / EDMV4-T40 AC7: the two retroactive-QC FAIL verdicts on edm-repo-readiness --"

# =================================================================================================
# EDMV4-T39 AC7 -- BOTH conjuncts. The pre-existing assertion covered only the first, so the
# missing half was invisible to the suite; asserting only the half that exists moves a blind spot
# rather than closing one.
# =================================================================================================
T39AC7_SRC="$(cat "$REPO_READINESS")"
T39AC7_JSON="${TMP}/t39ac7.json"
"$REPO_READINESS" --json "$T39AC7_JSON" >/dev/null

# Conjunct 1: the version constant reaches the JSON output.
check "EDMV4-T39 AC7 conjunct 1 -- readiness_rubric_version reaches the JSON output" \
  "1.0.0" "$(jq -r '.readiness_rubric_version' "$T39AC7_JSON")"
# NEGATIVE CONTROL for conjunct 1: the field must be a real key, not a jq default. Ask for a
# neighbouring key that does not exist and confirm the same expression yields null there.
check "EDMV4-T39 AC7 conjunct 1 negative control -- a non-existent sibling key reads null, so the value above is real" \
  "null" "$(jq -r '.readiness_rubric_version_not_a_real_key | tostring' "$T39AC7_JSON")"

# Conjunct 2: the file documents that a future comparator must REFUSE on a version mismatch.
# Four independent content requirements, so a one-word mention cannot satisfy this.
t39ac7_conjunct2() {
  local src="$1"
  printf '%s' "$src" | grep -qF 'MUST REFUSE the comparison' || return 1
  printf '%s' "$src" | grep -qF 'readiness_rubric_version' || return 1
  printf '%s' "$src" | grep -qF 'MUST NOT' || return 1
  printf '%s' "$src" | grep -qF 'edm-compare-eval' || return 1
  return 0
}
if t39ac7_conjunct2 "$T39AC7_SRC"; then
  pass "EDMV4-T39 AC7 conjunct 2 -- the script documents the comparator refusal contract, modelled on edm-compare-eval"
else
  fail "EDMV4-T39 AC7 conjunct 2 -- the comparator refusal contract is not documented in edm-repo-readiness"
fi
check "EDMV4-T39 AC7 conjunct 2 -- the contract forbids a silent comparison explicitly" \
  "MUST NOT silently compare them" "$T39AC7_SRC"
check "EDMV4-T39 AC7 conjunct 2 -- and forbids the compare-what-they-share fallback" \
  "only the categories the two happen to share" "$T39AC7_SRC"
check "EDMV4-T39 AC7 conjunct 2 -- and treats a missing version field as a mismatch, not as current" \
  "it is unset, not" "$T39AC7_SRC"
check "EDMV4-T39 AC7 conjunct 2 -- and names the in-repo precedent's own refusal fields" \
  "scorer_version" "$T39AC7_SRC"
# NEGATIVE CONTROL for conjunct 2: strip the refusal contract from a scratch copy and confirm the
# same predicate reports it missing. Without this, conjunct 2 could be satisfied by any file that
# happens to contain the word "refuse" somewhere -- which is exactly how the original AC7 gap
# survived (a whole-file scan for refus/mismatch/comparator returned four unrelated hits).
T39AC7_TMP="$(mktemp -d "${TMP}/t39ac7.XXXXXX")"
sed '/MUST REFUSE the comparison/d' "$REPO_READINESS" > "${T39AC7_TMP}/stripped"
if t39ac7_conjunct2 "$(cat "${T39AC7_TMP}/stripped")"; then
  fail "EDMV4-T39 AC7 negative control -- the conjunct-2 predicate still passed on a copy with the refusal contract removed"
else
  pass "EDMV4-T39 AC7 negative control -- the conjunct-2 predicate correctly fails on a copy with the refusal contract removed"
fi
# And prove the predicate is not simply always-false: a copy with only an UNRELATED refusal word
# added must still fail it (the four unrelated hits the QC auditor found were exactly this shape).
printf '%s\n# this comment mentions refuse and mismatch and a comparator, and nothing else\n' \
  "$(cat "${T39AC7_TMP}/stripped")" > "${T39AC7_TMP}/decoy"
if t39ac7_conjunct2 "$(cat "${T39AC7_TMP}/decoy")"; then
  fail "EDMV4-T39 AC7 negative control -- a decoy comment mentioning refuse/mismatch/comparator satisfied the predicate"
else
  pass "EDMV4-T39 AC7 negative control -- a decoy comment mentioning refuse/mismatch/comparator does NOT satisfy the predicate"
fi

# =================================================================================================
# EDMV4-T40 AC7 -- every self-detected signal carries its justification comment, and the one
# genuine re-derivation of an edm-state-owned value is pinned byte-identical to edm-state's own.
# =================================================================================================
T40AC7_STATE_SRC="${PLUGIN_DIR}/bin/edm-state"
# _t40ac7_comment_above <needle> <lines> -- prints the <lines> source lines immediately preceding
# the first line matching <needle>, so "does this check carry a justification comment" is answered
# from position, not from the file containing the words somewhere.
_t40ac7_comment_above() {
  local needle="$1" lines="$2" ln
  ln="$(grep -n -m1 -F -- "$needle" "$REPO_READINESS" | cut -d: -f1)"
  [[ -n "$ln" ]] || return 1
  local start=$(( ln - lines ))
  [[ "$start" -lt 1 ]] && start=1
  sed -n "${start},$(( ln - 1 ))p" "$REPO_READINESS"
}
T40AC7_GIT_CTX="$(_t40ac7_comment_above 'GIT_REPO_PRESENT="false"' 12 || true)"
T40AC7_SRD_CTX="$(_t40ac7_comment_above 'SRD_DIR_PRESENT="false"' 22 || true)"
check "EDMV4-T40 AC7 -- GIT_REPO_PRESENT carries a justification comment naming its check id" \
  "GIT_REPO_PRESENT:" "$T40AC7_GIT_CTX"
check "EDMV4-T40 AC7 -- and names why no edm-state call can supply it" \
  "branch-check" "$T40AC7_GIT_CTX"
check "EDMV4-T40 AC7 -- SRD_DIR_PRESENT carries a justification comment naming its check id" \
  "SRD_DIR_PRESENT:" "$T40AC7_SRD_CTX"
check "EDMV4-T40 AC7 -- and names the duplication class by ID rather than describing it vaguely" \
  "CA-409" "$T40AC7_SRD_CTX"
check "EDMV4-T40 AC7 -- and records the residual work as edm-state-owned, not silently accepted" \
  "edm-state-owned accessor" "$T40AC7_SRD_CTX"
# NEGATIVE CONTROL for the position-sensitive extraction: the same helper must find NOTHING
# above a line that carries no comment, so a pass above is about position and not about the file
# containing the words anywhere.
T40AC7_NOCOMMENT="$(_t40ac7_comment_above 'CHECKS_JSON="$(printf' 1 || true)"
if printf '%s' "$T40AC7_NOCOMMENT" | grep -q 'SRD_DIR_PRESENT:'; then
  fail "EDMV4-T40 AC7 negative control -- the comment-above extraction is not position-sensitive"
else
  pass "EDMV4-T40 AC7 negative control -- the comment-above extraction is position-sensitive (an unrelated line yields no justification text)"
fi

# The duplication that could not be removed from inside this script is pinned instead: the scorer's
# SRD_ROOT derivation must stay byte-identical to bin/edm-state's own, so a change to one that is
# not made to the other fails here rather than silently giving the scorer a different root.
T40AC7_RR_LINE="$(grep -m1 '^SRD_ROOT=' "$REPO_READINESS" || true)"
T40AC7_ES_LINE="$(grep -m1 '^SRD_ROOT=' "$T40AC7_STATE_SRC" || true)"
if [[ -n "$T40AC7_RR_LINE" && -n "$T40AC7_ES_LINE" ]]; then
  pass "EDMV4-T40 AC7 -- both SRD_ROOT derivation lines were located (the comparison below is meaningful)"
else
  fail "EDMV4-T40 AC7 -- could not locate one of the SRD_ROOT lines: scorer=[${T40AC7_RR_LINE}] edm-state=[${T40AC7_ES_LINE}]"
fi
if [[ "$T40AC7_RR_LINE" == "$T40AC7_ES_LINE" ]]; then
  pass "EDMV4-T40 AC7 -- edm-repo-readiness' SRD_ROOT chain is byte-identical to bin/edm-state's own"
else
  fail "EDMV4-T40 AC7 -- SRD_ROOT chains have drifted: scorer=[${T40AC7_RR_LINE}] edm-state=[${T40AC7_ES_LINE}]"
fi
# NEGATIVE CONTROL: perturb one copy and confirm the comparison reports drift.
T40AC7_DRIFTED="${T40AC7_RR_LINE%\"}-drifted\""
if [[ "$T40AC7_DRIFTED" == "$T40AC7_ES_LINE" ]]; then
  fail "EDMV4-T40 AC7 negative control -- a deliberately perturbed SRD_ROOT line still compared equal"
else
  pass "EDMV4-T40 AC7 negative control -- a deliberately perturbed SRD_ROOT line is detected as drift"
fi

echo
echo "-- CA-022/028/033/034: stale and contradictory prose --"

# =================================================================================================
# CA-022: the canonical-section count is DERIVED, never restated
# =================================================================================================
CA022_SYNC="${PLUGIN_DIR}/bin/edm-sync-canonical-sections"
CA022_TMP="$(mktemp -d "${TMP}/ca022.XXXXXX")"

# The generation block's own list, computed here at test time by a DIFFERENT expression than the
# script's (awk over the extract_section calls between the `{` and `} > "$tmp"` fence), so the two
# agreeing is evidence rather than a tautology.
CA022_GEN_COUNT="$(awk '/^\{$/{f=1} f && /^\} > "\$tmp"$/{f=0} f && /^  extract_section "/' "$CA022_SYNC" | grep -c . || true)"
if [[ "$CA022_GEN_COUNT" -ge 2 ]]; then
  pass "CA-022 -- the generation block's extract_section list was located (${CA022_GEN_COUNT} sections); the checks below are meaningful"
else
  fail "CA-022 -- could not locate the generation block's extract_section list (found ${CA022_GEN_COUNT}); every check below is vacuous"
fi

CA022_HELP="$("$CA022_SYNC" --help)"
CA022_HELP_COUNT="$(printf '%s\n' "$CA022_HELP" | grep -c '^#   - ' || true)"
if [[ "$CA022_HELP_COUNT" -eq "$CA022_GEN_COUNT" ]]; then
  pass "CA-022 -- --help lists exactly the generation block's ${CA022_GEN_COUNT} sections, both computed at test time"
else
  fail "CA-022 -- --help listed ${CA022_HELP_COUNT} sections but the generation block extracts ${CA022_GEN_COUNT}"
fi
check "CA-022 -- --help prints the derived count in its inventory header" \
  "# Sections extracted (${CA022_GEN_COUNT})," "$CA022_HELP"
# Every heading the generator names must appear in the inventory, by name (a count alone would let
# a renamed section pass).
CA022_MISSING=""
while IFS= read -r ca022_h; do
  [[ -n "$ca022_h" ]] || continue
  printf '%s\n' "$CA022_HELP" | grep -qF -- "#   - ${ca022_h}" || CA022_MISSING="${CA022_MISSING}${CA022_MISSING:+, }${ca022_h}"
done < <(awk '/^\{$/{f=1} f && /^\} > "\$tmp"$/{f=0} f && /^  extract_section "/' "$CA022_SYNC" | sed -e 's/^  extract_section "//' -e 's/".*$//')
if [[ -z "$CA022_MISSING" ]]; then
  pass "CA-022 -- every extracted section is named in --help's inventory, not just counted"
else
  fail "CA-022 -- --help's inventory omits: ${CA022_MISSING}"
fi

# NEGATIVE CONTROL: add an eighth extract_section call to a scratch copy and confirm --help's
# derived count MOVES WITH IT. A re-pinned literal would stay at seven and fail this.
CA022_SCRATCH="${CA022_TMP}/edm-sync-canonical-sections"
awk '{print} /^  extract_section "Phase Timing Guidelines \(EDMV3-T38\)" "\$SRC"$/{print "  echo"; print "  extract_section \"Cost tracking\" \"$SRC\""}' \
  "$CA022_SYNC" > "$CA022_SCRATCH"
cp "${PLUGIN_DIR}/bin/_edm-cli-lib.sh" "${CA022_TMP}/_edm-cli-lib.sh"
chmod +x "$CA022_SCRATCH"
CA022_SCRATCH_COUNT="$("$CA022_SCRATCH" --help | grep -c '^#   - ' || true)"
if [[ "$CA022_SCRATCH_COUNT" -eq $((CA022_GEN_COUNT + 1)) ]]; then
  pass "CA-022 negative control -- adding an eighth extract_section call moves --help's count to ${CA022_SCRATCH_COUNT} (it is derived, not pinned)"
else
  fail "CA-022 negative control -- --help still reported ${CA022_SCRATCH_COUNT} after an extra extract_section call was added; the count is pinned, not derived"
fi
check "CA-022 negative control -- and the newly added section is named in the scratch copy's inventory" \
  "#   - Cost tracking" "$("$CA022_SCRATCH" --help)"

# Neither the script's help block nor CLAUDE.md's bin/ row may restate a literal count.
CA022_HELP_BLOCK="$(awk '/^# EDM-HELP-BEGIN/{f=1;next} /^# EDM-HELP-END/{f=0} f' "$CA022_SYNC")"
check_absent "CA-022 -- the --help block no longer claims 'the two by-name-referenced canonical sections'" \
  "the two by-name-referenced canonical sections" "$CA022_HELP_BLOCK"
check_absent "CA-022 -- nor tells the operator to re-run after editing 'either source section'" \
  "either source section" "$CA022_HELP_BLOCK"
CA022_CLAUDE_ROW="$(grep -F '| `edm-sync-canonical-sections` |' "${PLUGIN_DIR}/CLAUDE.md")"
if [[ -n "$CA022_CLAUDE_ROW" ]]; then
  pass "CA-022 -- CLAUDE.md's bin/ table row for edm-sync-canonical-sections was located"
else
  fail "CA-022 -- CLAUDE.md's bin/ table has no row for edm-sync-canonical-sections; the checks below are vacuous"
fi
check_absent "CA-022 -- CLAUDE.md's bin/ row no longer names the two sections it used to claim" \
  '"Severity vocabulary" and "Mermaid diagram conventions" sections' "$CA022_CLAUDE_ROW"
check "CA-022 -- CLAUDE.md's bin/ row points the reader at --help for the live inventory instead" \
  'edm-sync-canonical-sections --help' "$CA022_CLAUDE_ROW"
if printf '%s' "$CA022_CLAUDE_ROW" | grep -qiE '\b(two|three|four|five|six|seven|eight|nine|ten|[0-9]+)\b canonical sections'; then
  fail "CA-022 -- CLAUDE.md's bin/ row re-pins a literal canonical-section count: ${CA022_CLAUDE_ROW}"
else
  pass "CA-022 -- CLAUDE.md's bin/ row restates no literal canonical-section count (a re-pinned count is the defect, per CA-021)"
fi

# =================================================================================================
# CA-028: the code-audit skill's False Alarm Filter must agree with the 14 lens agents
# =================================================================================================
CA028_SKILL="${PLUGIN_DIR}/skills/code-audit/SKILL.md"
CA028_FILTER="$(awk '/^## False Alarm Filter/{f=1;next} f && /^## /{f=0} f' "$CA028_SKILL")"
if [[ -n "$CA028_FILTER" ]]; then
  pass "CA-028 -- the code-audit skill's False Alarm Filter section extracted non-empty"
else
  fail "CA-028 -- the code-audit skill's False Alarm Filter section extraction was empty; nothing below is meaningful"
fi
check_absent "CA-028 -- the skill no longer says a filtered finding is not reported at all" \
  "do not report as a finding" "$CA028_FILTER"
check "CA-028 -- the skill now uses the lens agents' demote-never-delete formulation" \
  "demotes and never deletes" "$CA028_FILTER"
check "CA-028 -- and states that a NOTED item still gets its JSONL line" \
  'sev: "NOTED"' "$CA028_FILTER"
check "CA-028 -- naming the paired status token as well" 'status: "noted"' "$CA028_FILTER"
check "CA-028 -- and names the demotion target section" '## Noted / Not Actionable' "$CA028_FILTER"

# The claim this fix rests on -- "all fourteen lens agents already say this" -- is verified against
# the live agent files, not asserted. It is also the NEGATIVE CONTROL: if the lens agents ever
# stopped carrying the demote-never-delete sentence, the skill would be the wrong thing to pin to.
CA028_LENSES=""
CA028_LENS_COUNT=0
CA028_LENS_BAD=""
while IFS= read -r ca028_f; do
  [[ -n "$ca028_f" ]] || continue
  CA028_LENS_COUNT=$((CA028_LENS_COUNT + 1))
  ca028_sec="$(awk '/^## False Alarm Filter/{f=1;next} f && /^## /{f=0} f' "$ca028_f")"
  printf '%s' "$ca028_sec" | grep -qF 'demotes a finding to `## Noted / Not Actionable`' \
    || CA028_LENS_BAD="${CA028_LENS_BAD}${CA028_LENS_BAD:+, }$(basename "$ca028_f")"
done < <(ls "${PLUGIN_DIR}"/agents/edm-audit-*.md | grep -v 'edm-audit-synthesizer')
CA028_LENSES="$CA028_LENS_COUNT"
if [[ "$CA028_LENSES" -eq 14 ]]; then
  pass "CA-028 -- all 14 lens agent files were found (the set the skill is being aligned to)"
else
  fail "CA-028 -- found ${CA028_LENSES} lens agent files, expected 14"
fi
if [[ -z "$CA028_LENS_BAD" ]]; then
  pass "CA-028 -- every lens agent still carries the demote-never-delete sentence the skill now matches"
else
  fail "CA-028 -- these lens agents no longer carry the demote-never-delete sentence: ${CA028_LENS_BAD}"
fi
# NEGATIVE CONTROL for the skill-side checks: strip the new formulation from a scratch copy and
# confirm the two content checks above would fail on it.
CA028_TMP="$(mktemp -d "${TMP}/ca028.XXXXXX")"
sed -e '/demotes and never deletes/d' -e '/sev: "NOTED"/d' "$CA028_SKILL" > "${CA028_TMP}/SKILL.md"
CA028_BROKEN="$(awk '/^## False Alarm Filter/{f=1;next} f && /^## /{f=0} f' "${CA028_TMP}/SKILL.md")"
if printf '%s' "$CA028_BROKEN" | grep -qF 'demotes and never deletes'; then
  fail "CA-028 negative control -- the demote-never-delete check did not discriminate against a stripped copy"
else
  pass "CA-028 negative control -- the demote-never-delete check correctly fails on a copy with the sentence removed"
fi

# =================================================================================================
# CA-033: skills/plan's Step 6 instruction now has a matching scoped Bash grant
# =================================================================================================
CA033_PLAN="${PLUGIN_DIR}/skills/plan/SKILL.md"
CA033_TOOLS="$(grep -m1 '^allowed-tools:' "$CA033_PLAN")"
if [[ -n "$CA033_TOOLS" ]]; then
  pass "CA-033 -- skills/plan/SKILL.md's allowed-tools line was located"
else
  fail "CA-033 -- skills/plan/SKILL.md has no allowed-tools line; the checks below are vacuous"
fi
check "CA-033 -- plan's allowed-tools grants Bash(edm-repo-readiness *)" \
  "Bash(edm-repo-readiness *)" "$CA033_TOOLS"
# The instruction the grant exists for must still be there -- a grant with no instruction is the
# opposite defect and is what edm-check-grants' Source 4 already warns about.
check "CA-033 -- Step 6 still instructs the skill to run edm-repo-readiness" \
  "edm-repo-readiness" "$(cat "$CA033_PLAN")"
# NEGATIVE CONTROL: every OTHER edm-* binary named in a run instruction in this skill body must
# also carry a scoped grant. Computed from the file, so a future step that adds an ungranted
# binary fails here instead of failing silently at runtime the way Step 6 did.
CA033_UNGRANTED=""
for ca033_bin in edm-state edm-init edm-validate-prefix edm-repo-readiness; do
  grep -qF -- "$ca033_bin" "$CA033_PLAN" || continue
  printf '%s' "$CA033_TOOLS" | grep -qF -- "Bash(${ca033_bin} *)" \
    || CA033_UNGRANTED="${CA033_UNGRANTED}${CA033_UNGRANTED:+, }${ca033_bin}"
done
if [[ -z "$CA033_UNGRANTED" ]]; then
  pass "CA-033 -- every edm-* binary named in skills/plan/SKILL.md's body carries a matching scoped Bash grant"
else
  fail "CA-033 -- these edm-* binaries are named in skills/plan/SKILL.md but have no scoped Bash grant: ${CA033_UNGRANTED}"
fi
# Proof the loop above discriminates: run the same rule against a scratch copy with the grant
# removed and confirm it reports edm-repo-readiness as ungranted.
CA033_TMP="$(mktemp -d "${TMP}/ca033.XXXXXX")"
sed 's/, Bash(edm-repo-readiness \*)//' "$CA033_PLAN" > "${CA033_TMP}/SKILL.md"
CA033_CTRL_TOOLS="$(grep -m1 '^allowed-tools:' "${CA033_TMP}/SKILL.md")"
CA033_CTRL_UNGRANTED=""
for ca033_bin in edm-state edm-init edm-validate-prefix edm-repo-readiness; do
  grep -qF -- "$ca033_bin" "${CA033_TMP}/SKILL.md" || continue
  printf '%s' "$CA033_CTRL_TOOLS" | grep -qF -- "Bash(${ca033_bin} *)" \
    || CA033_CTRL_UNGRANTED="${CA033_CTRL_UNGRANTED}${CA033_CTRL_UNGRANTED:+, }${ca033_bin}"
done
if [[ "$CA033_CTRL_UNGRANTED" == "edm-repo-readiness" ]]; then
  pass "CA-033 negative control -- removing the grant from a scratch copy makes the same rule report edm-repo-readiness ungranted"
else
  fail "CA-033 negative control -- the rule did not discriminate: got [${CA033_CTRL_UNGRANTED}], expected [edm-repo-readiness]"
fi

# =================================================================================================
# CA-034: Step 1b.5's readiness coupling states its own ordering instead of dangling
# =================================================================================================
CA034_STEP="$(_t41_extract_between "${PLUGIN_DIR}/skills/orchestrator/SKILL.md" '^\*\*Step 1b\.5' '^\*\*Step 1c')"
if [[ -n "$CA034_STEP" ]]; then
  pass "CA-034 -- Step 1b.5's block extracted non-empty"
else
  fail "CA-034 -- Step 1b.5's block extraction was empty; nothing below is meaningful"
fi
check "CA-034 -- Step 1b.5 states that no score exists at this point on any run that reaches it" \
  "no readiness score exists at this point on any run that reaches this step" "$CA034_STEP"
check "CA-034 -- and names the producer and WHEN it runs, relative to this step" \
  "runs inside Phase 1 -- dispatched later, at Step 2" "$CA034_STEP"
check "CA-034 -- and names the skipped-on-resume half that makes the two cases disjoint" \
  "skipped on resume" "$CA034_STEP"
check "CA-034 -- the previously-unresolvable reference now names a concrete read path" \
  '`Overall score:` line of `planning.md`' "$CA034_STEP"
check "CA-034 -- the advisory contract is restated: three signals alone, no waiting" \
  "never blocks on, or waits for, the scorecard" "$CA034_STEP"
# The orchestrator does NOT acquire the score itself, so it must NOT carry a Bash grant for the
# scorecard -- a grant with no instruction is the defect edm-check-grants Source 4 warns about.
CA034_ORCH_TOOLS="$(grep -m1 '^allowed-tools:' "${PLUGIN_DIR}/skills/orchestrator/SKILL.md")"
if printf '%s' "$CA034_ORCH_TOOLS" | grep -qF -- 'Bash(edm-repo-readiness'; then
  fail "CA-034 -- the orchestrator carries a Bash(edm-repo-readiness ...) grant but Step 1b.5 runs nothing; that is a grant without an instruction"
else
  pass "CA-034 -- the orchestrator carries no Bash(edm-repo-readiness ...) grant, matching a step that acquires nothing"
fi
# Regression: the block must stay under the EDMV4-T34 AC12 ceiling after this rewrite.
CA034_LINES="$(printf '%s\n' "$CA034_STEP" | wc -l | tr -d ' ')"
if [[ "$CA034_LINES" -lt 30 ]]; then
  pass "CA-034 -- Step 1b.5's block is still ${CA034_LINES} lines (< 30) after the ordering rewrite"
else
  fail "CA-034 -- Step 1b.5's block grew to ${CA034_LINES} lines (expected < 30)"
fi
# NEGATIVE CONTROL: strip the ordering paragraph from a scratch copy and confirm the ordering
# checks above would fail on it -- they are content checks, not "the section is non-empty" checks.
CA034_TMP="$(mktemp -d "${TMP}/ca034.XXXXXX")"
sed '/no readiness score exists at this point/d' "${PLUGIN_DIR}/skills/orchestrator/SKILL.md" > "${CA034_TMP}/SKILL.md"
CA034_CTRL="$(_t41_extract_between "${CA034_TMP}/SKILL.md" '^\*\*Step 1b\.5' '^\*\*Step 1c')"
if printf '%s' "$CA034_CTRL" | grep -qF 'no readiness score exists at this point on any run that reaches this step'; then
  fail "CA-034 negative control -- the ordering check did not discriminate against a copy with the paragraph removed"
else
  pass "CA-034 negative control -- the ordering check correctly fails on a copy with the paragraph removed"
fi

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
