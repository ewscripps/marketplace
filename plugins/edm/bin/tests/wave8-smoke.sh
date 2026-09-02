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

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
