#!/usr/bin/env bash
# wave7-smoke.sh -- EDMV3-T09 (EDMV3-15) contract-suite coverage: the check-script /
# caller-contract tests that are NOT lifecycle smoke cases (those live in wave6-smoke.sh).
# This suite asserts that `cmd_set`'s SETTABLE_KEYS allowlist and its real callers across
# skills/agents/hooks/bin can never drift apart silently, and that the no-override-flag
# scope boundary (EDMV3-90) holds for bin/edm-state.
# Run from repo root: bash plugins/edm/bin/tests/wave7-smoke.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
EDM_STATE="${SCRIPT_DIR}/../edm-state"

# Shared assertions / counters (CA-014). Sourced BEFORE the PLUGIN_DIR/GITLAB_CI_YML derivations
# below (reordered, G21/CA-049) so both read the shared _HARNESS_PLUGIN_DIR / _HARNESS_REPO_ROOT
# exports instead of each re-deriving the same cd/pwd chain independently.
source "${SCRIPT_DIR}/_harness.sh"
PLUGIN_DIR="$_HARNESS_PLUGIN_DIR"
GITLAB_CI_YML="${_HARNESS_REPO_ROOT}/.gitlab-ci.yml"

# CA-005: shared --help extractor -- _t61_help_subcommands below sources this instead of
# hand-copying the sentinel-extraction awk literal a thirteenth time.
source "${SCRIPT_DIR}/../_edm-cli-lib.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/edm-wave7.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT INT TERM
PATH="${PLUGIN_DIR}/bin:$PATH"

echo "wave7 smoke check -- EDMV3-T09 cmd_set caller-contract and no-override-flag guard"
echo

# ---- Shared helpers -------------------------------------------------------------

# _wave7_settable_keys -- SETTABLE_KEYS as sourced directly from the real bin/edm-state
# (dispatch-guarded, EDMV3-T07 AC8 precedent) so this test consumes the exact same
# constant cmd_set validates against, never a re-typed copy (EDMV3-13 AC "one place").
_wave7_settable_keys() {
  ( source "$EDM_STATE" >/dev/null 2>&1; echo "$SETTABLE_KEYS" )
}

# WAVE7_IGNORE_KEYS -- documented ignore list (AC12): tokens that are documentation
# placeholders in usage/help text, not real state keys. An explicit literal list, not a
# loose `<.*>` regex -- a loose regex would also hide a genuinely drifted key that
# happens to look bracketed, which is the exact failure mode this ticket closes.
WAVE7_IGNORE_KEYS="<key>"

# caller_contract_scan <plugin-root> -- scans <plugin-root>/skills/**/SKILL.md,
# <plugin-root>/agents/*.md, <plugin-root>/hooks/hooks.json, and the top-level files
# directly inside <plugin-root>/bin/ (bin/tests/ is test-fixture surface, not caller
# surface, and is deliberately excluded -- it is full of intentionally-invalid keys for
# negative testing) for `edm-state set <PREFIX> <key>` invocations. For each extracted
# key:
#   - prints "MISS <key> <file>:<lineno>" if the key is absent from SETTABLE_KEYS
#   - prints "WARN_UNUSED <key>" once per allowlisted key with zero callers found
#     (informational -- surfaces dead schema fields, never fails the scan)
# Returns 1 iff at least one MISS line was printed; 0 otherwise. Never mutates state
# (read-only grep over the tree).
caller_contract_scan() {
  local root="$1"
  local settable
  settable="$(_wave7_settable_keys)"

  local -a scan_files=()
  local f
  while IFS= read -r f; do scan_files+=("$f"); done \
    < <(find "$root/skills" -name 'SKILL.md' -type f 2>/dev/null | sort)
  while IFS= read -r f; do scan_files+=("$f"); done \
    < <(find "$root/agents" -maxdepth 1 -name '*.md' -type f 2>/dev/null | sort)
  [[ -f "$root/hooks/hooks.json" ]] && scan_files+=("$root/hooks/hooks.json")
  while IFS= read -r f; do scan_files+=("$f"); done \
    < <(find "$root/bin" -maxdepth 1 -type f 2>/dev/null | sort)

  local found_keys="" miss=0
  local line lineno content after key
  for f in "${scan_files[@]+"${scan_files[@]}"}"; do
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      lineno="${line%%:*}"
      content="${line#*:}"
      after="${content#*edm-state set }"
      key="$(printf '%s' "$after" | awk '{print $2}')"
      [[ -z "$key" ]] && continue

      # Documented ignore list (AC12) -- documentation placeholders are not real keys.
      case " $WAVE7_IGNORE_KEYS " in
        *" $key "*) continue ;;
      esac

      found_keys="$found_keys $key"
      case " $settable " in
        *" $key "*) ;;
        *)
          echo "MISS $key ${f}:${lineno}"
          miss=1
          ;;
      esac
    done < <(grep -n 'edm-state set ' "$f" 2>/dev/null)
  done

  # Inverse direction (AC12, advisory): an allowlisted key nobody in the scanned tree
  # ever calls is a dead schema field made visible -- reported, never failed.
  local k
  for k in $settable; do
    case " $found_keys " in
      *" $k "*) ;;
      *) echo "WARN_UNUSED $k" ;;
    esac
  done

  [[ $miss -eq 0 ]]
}

# =================================================================================
# EDMV3-T09 AC11/AC12: the cmd_set allowlist and its real callers are a checked contract
# =================================================================================

# ---- AC11 (positive): zero misses against the live tree at the moment this lands ----
echo "T09 AC11 -- every set caller key is allowlisted"
set +e
live_ec=0
live_out="$(caller_contract_scan "$PLUGIN_DIR" 2>&1)" || live_ec=$?
set -e
[[ $live_ec -eq 0 ]] && pass "every set caller key is allowlisted (zero MISS lines against the live tree)" \
  || fail "caller-contract scan found MISS line(s) against the live tree:\n$live_out"
check_absent "no MISS line against the live tree" "MISS " "$live_out"
check "known live call site test_layer_skipped is covered" "test_layer_skipped" \
  "$(grep -rn 'edm-state set ' "$PLUGIN_DIR/skills" 2>/dev/null)"
check "known live call site last_decision is covered" "last_decision" \
  "$(grep -rn 'edm-state set ' "$PLUGIN_DIR/skills" 2>/dev/null)"
check "known live call site estimated_size is covered" "estimated_size" \
  "$(grep -n 'edm-state set ' "$EDM_STATE" 2>/dev/null)"

# ---- AC12 (positive, ignore list): the <key> doc placeholder never registers as a MISS ----
echo
echo "T09 AC12 -- documentation placeholder <key> is excluded by the explicit ignore list"
check_absent "the <key> placeholder is never reported as a MISS" "MISS <key>" "$live_out"

# ---- AC12 (positive, inverse direction is a warning, not a failure) ------------------
echo
echo "T09 AC12 -- allowlisted keys with no live caller are a warning, not a failure"
check "product_name (test-only caller) is reported as WARN_UNUSED" "WARN_UNUSED product_name" "$live_out"
check "compliance_enabled (set-mode-only caller) is reported as WARN_UNUSED" "WARN_UNUSED compliance_enabled" "$live_out"
[[ $live_ec -eq 0 ]] && pass "WARN_UNUSED lines do not fail the scan (advisory only)" \
  || fail "scan exited non-zero despite only WARN_UNUSED lines being present"

# ---- AC12 (negative, inverse of the positive case): an injected unknown key fails,
# naming both the key and the calling file:line -----------------------------------
echo
echo "T09 AC12 -- an injected unknown key fails the scan, naming the file and line"
neg_case_bogus_key() {
  local scratch
  scratch="$(mktemp -d "${TMP}/edm-wave7-neg.XXXXXX")" || { fail "AC12 -- mktemp failed"; return 1; }

  mkdir -p "$scratch/bin"
  cp -R "$PLUGIN_DIR/skills" "$scratch/skills"
  cp -R "$PLUGIN_DIR/agents" "$scratch/agents"
  cp -R "$PLUGIN_DIR/hooks" "$scratch/hooks"
  local bf
  while IFS= read -r bf; do cp "$bf" "$scratch/bin/"; done \
    < <(find "$PLUGIN_DIR/bin" -maxdepth 1 -type f 2>/dev/null)

  local target="$scratch/skills/implement/SKILL.md"
  printf '\nInjected for EDMV3-T09 AC12 negative case: edm-state set X bogus_key 1\n' >> "$target"

  local out ec
  set +e
  ec=0
  out="$(caller_contract_scan "$scratch" 2>&1)" || ec=$?
  set -e

  [[ $ec -ne 0 ]] && pass "AC12 -- injected unknown key fails the scan" \
    || fail "AC12 -- scan did not fail on injected bogus_key"
  check "AC12 -- failure names the key" "bogus_key" "$out"
  check "AC12 -- failure names the file:line" "${target}:" "$out"

  rm -rf "$scratch"
}
neg_case_bogus_key

# =================================================================================
# EDMV3-T09 AC13: no override flag reintroduced -- the literal --force never appears
# =================================================================================
echo
echo "T09 AC13 -- no literal --force anywhere in bin/edm-state"
# G2/CA-037 residual (round 5): converted from assert_absent_with_control (whose control here was
# already a real in-tree file, not a tautological literal, but which discarded the real scan's
# stderr/exit code and never asserted $EDM_STATE exists) to assert_tree_absent, which closes both
# gaps and retires assert_absent_with_control's last production caller -- it is now exercised
# only by harness-smoke.sh's own self-tests.
t09ac13_force_pattern='--force'
force_hits="$(grep -n -- "$t09ac13_force_pattern" "$EDM_STATE" 2>/dev/null || true)"
assert_tree_absent "no literal --force in bin/edm-state" \
  "$t09ac13_force_pattern" "$force_hits" \
  "$(cat "${PLUGIN_DIR}/bin/vocabulary-prohibited.txt" 2>/dev/null)" "$EDM_STATE"

# =================================================================================
# G2/CA-037 (round 5): tripwire -- assert_absent_with_control now has zero production callers
# (its last one, T09 AC13 above, is converted). Ban any NEW call site outside harness-smoke.sh,
# which legitimately self-tests the helper -- otherwise the next tautological-control site
# quietly reintroduces the class this remediation just closed.
# Scoped to every *.sh in this directory EXCEPT harness-smoke.sh (the sanctioned self-test) and
# this file itself, which necessarily mentions the banned name by name in this very comment
# block and in its own labels -- those are prose about the ban, not a call site.
# =================================================================================
echo
echo "=== G2/CA-037 tripwire: assert_absent_with_control has no production callers ==="
g2_awc_this_file="${SCRIPT_DIR}/$(basename "${BASH_SOURCE[0]}")"
g2_awc_hits="$(grep -rl 'assert_absent_with_control' "$SCRIPT_DIR"/*.sh 2>/dev/null \
  | grep -v '/_harness\.sh$' | grep -v '/harness-smoke\.sh$' | grep -vF "$g2_awc_this_file" || true)"
[[ -z "$g2_awc_hits" ]] \
  && pass "G2/CA-037 -- assert_absent_with_control is called only from harness-smoke.sh's self-tests" \
  || fail "G2/CA-037 -- assert_absent_with_control called outside harness-smoke.sh in: $g2_awc_hits (use assert_tree_absent instead)"

# =================================================================================
# EDMV3-T04 -- README install path regression guard (AC6). Do not add unrelated cases
# to this block; append a new commented block instead if another ticket needs one.
# =================================================================================
echo
echo "T04 AC6 -- README install path regression guard"
README_MD="${PLUGIN_DIR}/README.md"
readme_content="$(cat "$README_MD" 2>/dev/null || true)"
check "README install path present" "./plugins/edm" "$readme_content"
check_absent "README stale path absent" "edm-ai-development" "$readme_content"
# EDMV3-T04 end
# EDMV3-T03: bin/edm-check-grants -- four-source grant/instruction contract checker
# =================================================================================
EDM_CHECK_GRANTS="${SCRIPT_DIR}/../edm-check-grants"

echo
echo "T03 AC1 -- --list-sources prints exactly four source labels"
t03_sources_ec=0
t03_sources_out="$(bash "$EDM_CHECK_GRANTS" --list-sources 2>&1)" || t03_sources_ec=$?
t03_sources_count="$(printf '%s\n' "$t03_sources_out" | grep -c '.' || true)"
[[ $t03_sources_ec -eq 0 ]] && pass "--list-sources exits 0" || fail "--list-sources exited $t03_sources_ec"
[[ "$t03_sources_count" -eq 4 ]] && pass "--list-sources prints exactly four lines" \
  || fail "--list-sources printed $t03_sources_count line(s), expected 4:\n$t03_sources_out"
check "source label: agent-bodies" "agent-bodies" "$t03_sources_out"
check "source label: skill-launch-templates" "skill-launch-templates" "$t03_sources_out"
check "source label: hook-prompt-text" "hook-prompt-text" "$t03_sources_out"
check "source label: skill-allowed-tools-vs-body" "skill-allowed-tools-vs-body" "$t03_sources_out"

echo
echo "T03 AC7 -- exit contract: usage error is exit 2"
t03_bogus_ec=0
set +e
bash "$EDM_CHECK_GRANTS" --bogus-flag >/dev/null 2>&1 || t03_bogus_ec=$?
set -e
[[ $t03_bogus_ec -eq 2 ]] && pass "unknown flag exits 2" || fail "unknown flag exited $t03_bogus_ec, expected 2"

echo
echo "T03 AC2/AC4 -- every agent grant is satisfied against the live (post-EDMV3-T02) tree"
# G50/CA-281 (round 4): this is a deliberate second live invocation, not the CA-094 duplicate it
# was once flagged as -- it runs immediately after this same block's own --list-sources/
# --bogus-flag exit-contract checks, testing edm-check-grants itself, well before the CA-094
# hoisted WAVE7_GRANTS_EXIT capture even exists (see that capture's own comment for the full
# rationale). Left as its own run rather than folded into the later hoist.
set +e
t03_live_ec=0
t03_live_out="$(bash "$EDM_CHECK_GRANTS" 2>&1)" || t03_live_ec=$?
set -e
[[ $t03_live_ec -eq 0 ]] && pass "edm-check-grants exits 0 against the live tree" \
  || fail "edm-check-grants exited $t03_live_ec against the live tree:\n$t03_live_out"

echo
echo "T03 AC3 -- grant-without-instruction warnings are advisory, never block the exit code"
check "a known over-grant (edm-implementer Edit) is reported as a warning" \
  "warning: grant-without-instruction: agent: edm-implementer: Edit:" "$t03_live_out"
[[ $t03_live_ec -eq 0 ]] && pass "warnings present but exit is still 0 (advisory only)" \
  || fail "a warning-only run should still exit 0"

echo
echo "T03 AC5 -- AskUserQuestion granted to the four gate-presenting skills (plus orchestrator, unchanged)"
check "code-audit/SKILL.md grants AskUserQuestion" "AskUserQuestion" \
  "$(grep 'allowed-tools' "$PLUGIN_DIR/skills/code-audit/SKILL.md")"
check "plan/SKILL.md grants AskUserQuestion" "AskUserQuestion" \
  "$(grep 'allowed-tools' "$PLUGIN_DIR/skills/plan/SKILL.md")"
check "audit-srd/SKILL.md grants AskUserQuestion" "AskUserQuestion" \
  "$(grep 'allowed-tools' "$PLUGIN_DIR/skills/audit-srd/SKILL.md")"
check "audit-tickets/SKILL.md grants AskUserQuestion" "AskUserQuestion" \
  "$(grep 'allowed-tools' "$PLUGIN_DIR/skills/audit-tickets/SKILL.md")"
check "orchestrator/SKILL.md still grants AskUserQuestion (unchanged)" "AskUserQuestion" \
  "$(grep 'allowed-tools' "$PLUGIN_DIR/skills/orchestrator/SKILL.md")"

echo
echo "T03 AC6 -- must-fail: a skill body needing AskUserQuestion without the grant fails the run"
t03_ac6_case() {
  local scratch
  scratch="$(mktemp -d "${TMP}/edm-cg-ac6.XXXXXX")" || { fail "AC6 -- mktemp failed"; return 1; }

  mkdir -p "$scratch/bin"
  cp -R "$PLUGIN_DIR/agents" "$scratch/agents"
  cp -R "$PLUGIN_DIR/skills" "$scratch/skills"
  cp -R "$PLUGIN_DIR/hooks" "$scratch/hooks"
  cp "$EDM_CHECK_GRANTS" "$scratch/bin/edm-check-grants"
  cp "${SCRIPT_DIR}/../_edm-lint-lib.sh" "$scratch/bin/_edm-lint-lib.sh"
  cp "${SCRIPT_DIR}/../_edm-cli-lib.sh" "$scratch/bin/_edm-cli-lib.sh"
  chmod +x "$scratch/bin/edm-check-grants"

  # Strip AskUserQuestion from the scratch copy of plan/SKILL.md's allowed-tools line only.
  local target="$scratch/skills/plan/SKILL.md"
  sed -i.bak 's/, AskUserQuestion$//' "$target"
  rm -f "${target}.bak"

  local out ec
  set +e
  ec=0
  out="$(bash "$scratch/bin/edm-check-grants" 2>&1)" || ec=$?
  set -e

  [[ $ec -eq 1 ]] && pass "AC6 -- missing AskUserQuestion on a gate skill fails the run" \
    || fail "AC6 -- expected exit 1, got $ec"
  check "AC6 -- failure names skills/plan/SKILL.md" "skills/plan/SKILL.md" "$out"
  check "AC6 -- failure class is missing-askuserquestion-grant" "missing-askuserquestion-grant" "$out"

  T03_AC6_OUT="$out"
  rm -rf "$scratch"
}
t03_ac6_case
t03_live_agents="$(printf '%s\n' "$t03_live_out" | grep -E '^agent:|missing-askuserquestion-grant' || true)"
t03_control_agents="$(printf '%s\n' "${T03_AC6_OUT:-}" | grep -E '^agent:|missing-askuserquestion-grant' || true)"
if [[ -z "$t03_control_agents" ]]; then
  fail "zero unsatisfied agents against the live tree (positive control produced no failure marker)"
elif [[ -z "$t03_live_agents" ]]; then
  pass "zero unsatisfied agents against the live tree"
else
  fail "found unsatisfied agent line(s) against the live tree: $t03_live_agents"
fi

echo
echo "CA-010 -- AC8's shared-lint-library boundary: each of the four consumers sources"
echo "_edm-lint-lib.sh (bin/edm-lint-artifacts, edm-check-grants, edm-check-vocabulary, and"
echo "bin/edm-state, G39/CA-270, are peer consumers of it, not of one another) and defines none of"
echo "build_line_classes/is_ignored_line/report_violation itself. The prior version of this"
echo "assertion greped for the presence of report_violation/build_ignore_set/is_ignored_line call"
echo "sites and passed on any hit -- it would have passed unchanged even with the source line"
echo "deleted and the three helpers pasted back in locally, which is exactly the regression this"
echo "boundary exists to catch. It also grepped for build_ignore_set, a symbol that has never"
echo "existed in this tree post-extraction, so a hit on it never asserted anything real."
for ca010_consumer in edm-lint-artifacts edm-check-grants edm-check-vocabulary edm-state; do
  ca010_file="${PLUGIN_DIR}/bin/${ca010_consumer}"
  ca010_sources="$(grep -cE 'source .*_edm-lint-lib\.sh' "$ca010_file" 2>/dev/null || true)"
  [[ "${ca010_sources:-0}" -gt 0 ]] \
    && pass "CA-010 -- ${ca010_consumer} sources _edm-lint-lib.sh" \
    || fail "CA-010 -- ${ca010_consumer} does not source _edm-lint-lib.sh"

  ca010_bad_defs=""
  for ca010_fn in build_line_classes is_ignored_line report_violation; do
    if grep -qE "^${ca010_fn}\(\)" "$ca010_file"; then
      ca010_bad_defs="${ca010_bad_defs}${ca010_fn} "
    fi
  done
  [[ -z "$ca010_bad_defs" ]] \
    && pass "CA-010 -- ${ca010_consumer} defines none of build_line_classes/is_ignored_line/report_violation locally" \
    || fail "CA-010 -- ${ca010_consumer} redefines locally: ${ca010_bad_defs}(should come only from _edm-lint-lib.sh)"
done

echo
echo "T03 AC9 -- documented agent count matches disk (count-drift guard)"
t03_disk_count="$(ls "$PLUGIN_DIR"/agents/*.md 2>/dev/null | wc -l | tr -d '[:space:]')"
# CLAUDE.md documents the 11 edm-audit-* lenses collectively ("all 11 `edm-audit-*` lenses"), not
# by individual backtick mention (unlike every other agent) -- so the drift guard is two parts:
# every OTHER agent named individually by backtick token that matches a real agents/*.md file,
# plus the wildcard-with-explicit-count phrase for the lens class.
t03_claude_md="$PLUGIN_DIR/CLAUDE.md"
t03_named_count=0
t03_agent_base=""
for _af in "$PLUGIN_DIR"/agents/*.md; do
  [[ -f "$_af" ]] || continue
  t03_agent_base="$(basename "$_af" .md)"
  if grep -qF "\`${t03_agent_base}\`" "$t03_claude_md"; then
    t03_named_count=$((t03_named_count + 1))
  fi
done
t03_wildcard_count="$(grep -oE 'all [0-9]+ `edm-audit-\*`' "$t03_claude_md" \
  | grep -oE '[0-9]+' | head -1)"
t03_wildcard_count="${t03_wildcard_count:-0}"
t03_documented_total=$((t03_named_count + t03_wildcard_count))
check "CLAUDE.md documents the lens class as \"all N \`edm-audit-*\`\"" "edm-audit-*\`" \
  "$(grep -o 'all [0-9]* `edm-audit-\*`[^|]*' "$t03_claude_md" || true)"
[[ "$t03_documented_total" -eq "$t03_disk_count" ]] \
  && pass "documented agent count ($t03_documented_total) matches disk ($t03_disk_count)" \
  || fail "documented agent count ($t03_named_count individually-named + $t03_wildcard_count lens wildcard = $t03_documented_total) does not match disk ($t03_disk_count)"
[[ "$t03_disk_count" -eq 30 ]] && pass "disk agent count is 30 (baseline: ls \$PLUGIN_DIR/agents/*.md, EDMV3-T03)" \
  || fail "disk agent count is $t03_disk_count, expected 30 (source of truth: ls \$PLUGIN_DIR/agents/*.md)"

echo
echo "T03 AC10 -- bash 3.2 compatible (no associative arrays/mapfile) and referenced by run-all.sh"
bash -n "$EDM_CHECK_GRANTS" && pass "edm-check-grants passes bash -n" \
  || fail "edm-check-grants failed bash -n"
# CA-037: both checks below used to be uncontrolled (check_absent / bare [[ -z ]]) with no proof
# either pattern could ever match a real hit.
# G2/CA-037 + G13/CA-145: no legitimate in-tree "declare -A" exists (it is banned everywhere for
# bash 3.2 compatibility), so the positive control is a genuinely seeded scratch file rather
# than a hand-typed literal, and $EDM_CHECK_GRANTS is asserted to exist before the needle check.
t03_declarea_control="${TMP}/edm-t03-declareA-control.txt"
printf 'declare -A foo\n' > "$t03_declarea_control"
assert_tree_absent "no associative array declarations (declare -A)" "declare -A" \
  "$(cat "$EDM_CHECK_GRANTS")" "$(cat "$t03_declarea_control")" "$EDM_CHECK_GRANTS"
rm -f "$t03_declarea_control"
# CA-037: the trailing [[:space:]] requirement meant a mapfile/readarray call immediately
# followed by redirection with no space (e.g. "mapfile<f") could never match -- a real bug, not
# just an untested one. Widened to any non-identifier boundary character (or end of line) so
# "mapfile<f", "mapfile(...)", and the space-separated form all match, while "mapfile_helper"
# (part of a longer identifier) still correctly does not. The wider boundary also now matches
# "readarray." at the end of a prose sentence, so comment-only lines are excluded (same
# convention T61 AC9 below already uses) -- a prose mention of why the construct is avoided is
# not a use of it.
t03_mapfile_usage="$( { grep -nE '(^|[^a-zA-Z0-9_])(mapfile|readarray)([^a-zA-Z0-9_]|$)' "$EDM_CHECK_GRANTS" 2>/dev/null \
  | grep -vE '^[0-9]+:[[:space:]]*#' || true; } | wc -l | tr -d ' ')"
t03_mapfile_control="$(printf '%s\n' 'mapfile<f' | grep -cE '(^|[^a-zA-Z0-9_])(mapfile|readarray)([^a-zA-Z0-9_]|$)' || true)"
if [[ "${t03_mapfile_control:-0}" -lt 1 ]]; then
  fail "T03 AC10 -- positive control broken: 'mapfile<f' (no space before redirection) was not caught by the pattern"
else
  [[ "${t03_mapfile_usage:-0}" -eq 0 ]] && pass "no mapfile/readarray command usage (positive control confirms mapfile<f-style usage would be caught)" \
    || fail "found mapfile/readarray usage in edm-check-grants"
fi
check "run-all.sh references edm-check-grants (AC10 smoke-aggregator half)" "edm-check-grants" \
  "$(cat "${SCRIPT_DIR}/run-all.sh")"

# =================================================================================
# EDMV3-T15: prompts present the convergence gate instead of setting the flag
# =================================================================================
# The blocking dependency recorded in the prior version of this block (prose in
# code-audit/SKILL.md and orchestrator/SKILL.md not yet written) has landed in the same MR as
# this change. AC1, AC4 and AC7 were already true (AC7 is covered by the "T03 AC5" block above
# -- code-audit/SKILL.md grants AskUserQuestion); AC2, AC3, AC5, AC6 and AC8 are now asserted
# for real against the live skill text. AC9 (MR description before/after block) is a review
# artifact, not a runnable assertion, and is intentionally not covered here.
echo
echo "T15 AC1 -- code-audit/SKILL.md no longer instructs the model to set the flag directly"
CODE_AUDIT_SKILL="${PLUGIN_DIR}/skills/code-audit/SKILL.md"
ORCH_SKILL="${PLUGIN_DIR}/skills/orchestrator/SKILL.md"
t15_pattern="code_audit_converged true"
t15_skills_grep="$(grep -rn "$t15_pattern" "${PLUGIN_DIR}/skills/" 2>/dev/null || true)"
# CA-037: check_absent alone never proved the grep pattern itself could match anything -- a typo'd
# pattern or an accidentally-scoped directory would pass identically to a genuinely clean prompt
# set.
# G2/CA-037 + G13/CA-145: the control is a genuinely seeded scratch file (no skill legitimately
# contains this phrase anymore -- that is the whole point of T15 AC1), and
# "${PLUGIN_DIR}/skills/" is asserted to exist before the needle check runs.
# G2/CA-037 residual (round 5): the producing grep and the check below now share one variable
# ($t15_pattern) instead of two independently-typed literals, so a typo in the pattern breaks
# both identically. The control below stays a SEPARATE, independently-typed literal (not built
# from $t15_pattern) -- if it were also derived from the variable, a typo would poison the
# control too and the mismatch would go undetected again.
t15_skills_control="${TMP}/edm-t15-flag-control.txt"
printf 'edm-state set <PREFIX> code_audit_converged true\n' > "$t15_skills_control"
assert_tree_absent "no prompt anywhere instructs 'edm-state set <PREFIX> code_audit_converged true'" \
  "$t15_pattern" "$t15_skills_grep" "$(cat "$t15_skills_control")" "${PLUGIN_DIR}/skills/"
rm -f "$t15_skills_control"

echo
echo "T15 AC2 -- Step 10 presents the Convergence gate via AskUserQuestion and gates approve-gate on Approve"
CA_CONTENT="$(cat "$CODE_AUDIT_SKILL")"
check "Convergence header present" '"Convergence"' "$CA_CONTENT"
check "Convergence gate options Approve/Revise/No-Go present" \
  "**Approve** (record convergence now), **Revise**" "$CA_CONTENT"
check "approve-gate code-audit command present" \
  "edm-state approve-gate <PREFIX> code-audit" "$CA_CONTENT"
check "free-text-is-never-approval referenced by name at the convergence gate (EDMV3-T35 re-baseline: restatement replaced by the by-name Gate PROTOCOL reference)" \
  "Gate PROTOCOL" "$CA_CONTENT"

echo
echo "T15 AC3 -- Step 10 states the compute -> present -> approve -> record order explicitly"
# CA-102: this used to pin three assertions to a hardcoded `sed -n '69,106p'` absolute line-number
# range in a file other tickets edit freely -- any line inserted or removed above line 69 silently
# shifts the window without the assertion ever failing (or, worse, capturing the wrong content and
# failing for an unrelated reason). Anchored to step 10's own numbered-list marker and the next
# marker (step 11) instead, so the extracted text tracks the actual step regardless of line drift.
T15_STEP10="$(_wave7_extract_between "$CODE_AUDIT_SKILL" '^10\. \*\*Convergence gate\*\*' '^11\. ')"
check "convergence gate ordering text" "compute -> present -> approve -> record" "$T15_STEP10"
check "Step 10 compute sub-step precedes present" "**Compute**" "$T15_STEP10"
check "Step 10 present sub-step follows compute" "**Present** the gate via" "$T15_STEP10"

echo
echo "T15 AC4 -- gate summary states computed P0/P1/P2/NOTED counts"
check "code-audit/SKILL.md gate text names all four severity counts (P0/P1/P2/NOTED)" \
  "P0" "$(grep -o 'P0.*P1.*P2.*NOTED[^.]*' "$CODE_AUDIT_SKILL" || true)"

echo
echo "T15 AC5 -- orchestrator's Phase 6 dispatch entry invokes the gate protocol by name, not a restatement (EDMV3-T38 re-baseline: '### Step 8' no longer exists -- the dispatcher's Phase 6 entry in '## Step 2 -- Dispatch each phase' item 6 is the relocated text)"
T15_STEP8="$(awk '/^6\. \*\*Phase 6/{f=1} /^## Resume and Compaction/{f=0} f' "$ORCH_SKILL")"
check "Phase 6 entry names the Convergence gate by reference to /edm:code-audit Step 10" \
  "/edm:code-audit\` Step 10 presents the Convergence" "$T15_STEP8"
check_absent "Phase 6 entry does not restate the gate's own STOP-and-WAIT protocol locally" \
  "STOP and WAIT" "$T15_STEP8"

echo
echo "T15 AC6 -- the remediation gate is distinct, uses AskUserQuestion, and records no state"
check "code-audit/SKILL.md names the remediation gate" "remediation gate" "$CA_CONTENT"
T15_REMEDIATION_SECTION="$(awk '/^## Remediation Gate \(Code Audit\)/{f=1} /^## /{if(f && $0 !~ /^## Remediation Gate/) exit} f' <<< "$CA_CONTENT")"
check "remediation gate section present" "## Remediation Gate (Code Audit)" "$CA_CONTENT"
check "remediation gate uses AskUserQuestion" "AskUserQuestion" "$T15_REMEDIATION_SECTION"
check_absent "remediation gate records no state (no approve-gate call in its own section)" \
  "edm-state approve-gate" "$T15_REMEDIATION_SECTION"

echo
echo "T15 AC8 -- completion checklist names the Convergence gate; Post-Remediation Closure note preserved (EDMV3-T38 re-baseline: the orchestrator's '### Step 9' checklist moved into skills/implement/SKILL.md's own 'Step 8: Declare Done' checklist -- EDMV3-T37)"
T15_STEP9="$(cat "${PLUGIN_DIR}/skills/implement/SKILL.md")"
check "completion checklist names the Convergence gate" "Convergence gate" "$T15_STEP9"
check "Post-Remediation Closure section still present" "Post-Remediation Closure" "$CA_CONTENT"
# EDMV3-T15 end

# =================================================================================
# EDMV3-T23: mechanical scorer, committed baseline, and eval cadence
# =================================================================================
# Batch scope note (recorded here rather than silently worked around): this batch's file
# remit is plugins/edm/evals/* plus this suite's own appends -- bin/edm-state is out of scope
# for this agent/batch to edit. Concretely:
#   - AC11 (the eval job's `expire_in: 30 days` scores.json artifact publishing) landed with
#     EDMV3-T21's `.gitlab-ci.yml`: `eval:nightly`'s `artifacts:` block retains
#     `plugins/edm/evals/runs/` (where score-artifacts.sh writes each run's `scores.json`) for
#     30 days. Asserted below (shard-2 QC remediation -- this comment previously said it was
#     still pending after the pipeline file already landed it).
#   - AC8, AC9 and AC13 require three REAL baseline runs against wave-A code, each costing
#     live Anthropic API spend (run-eval.sh's claude -p invocations). This suite does not
#     spend that budget on its own initiative -- plugins/edm/evals/baseline/scores.json is
#     therefore intentionally absent (not faked, not stubbed) as of this ticket landing.
#     plugins/edm/evals/baseline/README.md documents this plainly, gives the exact command
#     to capture it (`bash plugins/edm/evals/run-eval.sh` x3, then
#     `bash plugins/edm/evals/score-artifacts.sh <run-dir>` per run), and is exercised below
#     for its documentation-level content instead.
# Everything else the scorer itself is responsible for (AC1-AC7, AC10, AC12, and the
# documentation half of AC8/AC9) is verified below against a synthetic run directory this
# suite constructs by hand, per score-artifacts.sh's own determinism/no-comparison contract.
echo
echo "T23 AC1/AC3/AC6 -- exactly five dimensions, exact total expression, deterministic"
SCORE_ARTIFACTS="${PLUGIN_DIR}/evals/score-artifacts.sh"
bash -n "$SCORE_ARTIFACTS" && pass "score-artifacts.sh passes bash -n" \
  || fail "score-artifacts.sh failed bash -n"
check_absent "no associative array declarations (declare -A)" "declare -A" \
  "$(cat "$SCORE_ARTIFACTS")"

t23_score_synthetic_run() {
  mkdir -p run-dir
  {
    echo '#### TSVE-01: sample requirement'
    echo '- **Acceptance Criteria**:'
    echo '    - [ ] A concrete, testable behavior with a specific numeric threshold.'
    echo
    echo '```mermaid'
    echo 'flowchart TD'
    echo '    A[Ready] --> B[Done]'
    echo '```'
  } > run-dir/srd.md
  echo 'Coverage discussion: TSVE-01' > run-dir/audit-srd.md
  echo "run-dir/srd.md written, TSVE-01 present" > /dev/null

  local rc_a=0 rc_b=0
  bash "$SCORE_ARTIFACTS" run-dir > out-a.json 2> err-a.json || rc_a=$?
  bash "$SCORE_ARTIFACTS" run-dir > out-b.json 2> err-b.json || rc_b=$?

  [[ "$rc_a" -eq 0 && "$rc_b" -eq 0 ]] \
    && pass "score-artifacts.sh exits 0 scoring a minimal synthetic run (AC5, never non-zero on a low score)" \
    || fail "score-artifacts.sh did not exit 0 on both runs (rc_a=$rc_a rc_b=$rc_b)"

  if diff -q out-a.json out-b.json >/dev/null 2>&1; then
    pass "score-artifacts.sh is deterministic -- byte-identical output across two invocations (AC6)"
  else
    fail "score-artifacts.sh output differs across two invocations of the same run directory"
  fi

  local dim_count
  dim_count="$(jq -e '.dimensions | length' out-a.json 2>/dev/null || echo "ERR")"
  [[ "$dim_count" == "5" ]] && pass "scores.json has exactly 5 dimensions (AC1)" \
    || fail "scores.json has $dim_count dimensions, expected exactly 5"

  jq -e '.dimensions[0].score != null and .dimensions[1].score != null and .dimensions[2].score != null and .dimensions[3].score != null' \
    out-a.json >/dev/null 2>&1 \
    && pass "dimensions 1-4 all execute on the synthetic run fixture" \
    || fail "expected dimensions 1-4 to score non-null on the synthetic run fixture"

  jq -e '. as $r | ([$r.dimensions[].score | select(. != null)] | add) as $sum
         | $r.dimensions_scored as $n | (($sum / $n * 10 | round) / 10) == $r.total' \
    out-a.json >/dev/null 2>&1 \
    && pass "scores.json.total satisfies the exact AC3 jq expression" \
    || fail "scores.json.total does not satisfy the exact AC3 jq expression"

  jq -e '.dimensions_skipped[] | select(.name == "lens-jsonl-prose-agreement")' out-a.json >/dev/null 2>&1 \
    && pass "dimension 5 (lens-jsonl-prose-agreement) is null/skipped with no code-audit round present (wave-A shape)" \
    || fail "dimension 5 was not skipped for a run with no code-audit round"
}
with_scratch_repo t23_score_synthetic_run

# =================================================================================
# CA-039 remediation (code-audit round 2): expected-value assertions for dimensions 2-4
# =================================================================================
# CA-039 (P1): every prior assertion on dimensions 2-4 was `!= null` or the AC3
# self-consistency identity (kept above, still useful for what it verifies), neither of
# which can catch a wrong dimension score, a swapped dimension, or a scorer that returns 0
# for everything. The three cases below hand-compute an expected score against
# score-artifacts.sh's own documented formula (score_from_ratio: round(100*num/den)) and
# assert the literal value, so a real regression in any of these three dimensions now fails
# the suite instead of passing silently.
echo
echo "=== CA-039 remediation: literal expected-value assertions (dimensions 2, 3, 4) ==="

ca039_dim2_vague_case() {
  mkdir -p run-dir
  {
    echo '#### TSVE-01: sample requirement'
    echo '- **Acceptance Criteria**:'
    echo '    - [ ] A concrete, testable behavior with a specific numeric threshold.'
    echo '    - [ ] The system should work as expected.'
  } > run-dir/srd.md
  echo 'Coverage discussion: TSVE-01' > run-dir/audit-srd.md

  bash "$SCORE_ARTIFACTS" run-dir > out-dim2.json 2>/dev/null
  local d2
  d2="$(jq -r '.dimensions[1].score' out-dim2.json 2>/dev/null)"
  # 2 AC bullets, 1 matches vague-ac-patterns.txt's "should work" -- score_from_ratio(2-1, 2) = 50.
  [[ "$d2" == "50" ]] \
    && pass "CA-039 -- dimension 2 (ac-testability) scores the hand-computed 50 for 1 vague of 2 ACs" \
    || fail "CA-039 -- dimension 2 scored ${d2}, expected the hand-computed value 50"
}
with_scratch_repo ca039_dim2_vague_case

ca039_dim3_valid_corpus_case() {
  mkdir -p run-dir
  local vdir="${MERMAID_FIXTURES_DIR:-${PLUGIN_DIR}/bin/tests/fixtures/mermaid}/valid"
  local f
  for f in "$vdir"/*.md; do
    # v08 and v09 are valid only under edm-lint-artifacts' own edm-lint-ignore-start/-end and
    # fence-open-marker conventions (EDMV3-T43 AC6) -- score-artifacts.sh's _scan_mermaid_blocks
    # is a separate, independent scanner (CA-019) that does not implement either suppression
    # convention, so v08's deliberately-violating fence genuinely scores BAD here and v09's fence
    # is not even recognized as mermaid. That is real, already-tracked cross-implementation
    # divergence (CA-019's scope), not a dimension-3 scoring defect -- excluded here so this case
    # asserts dimension 3's actual job (diagram validity) without redoing CA-019's work.
    case "$(basename "$f")" in
      v08-block-form-ignore-escape.md|v09-fence-open-marker-escape.md) continue ;;
    esac
    cat "$f" >> run-dir/srd.md
  done

  bash "$SCORE_ARTIFACTS" run-dir > out-dim3-valid.json 2>/dev/null
  local d3
  d3="$(jq -r '.dimensions[2].score' out-dim3-valid.json 2>/dev/null)"
  [[ "$d3" == "100" ]] \
    && pass "CA-039 -- dimension 3 (mermaid-parse-success) scores 100 against the genuinely-clean valid fixtures" \
    || fail "CA-039 -- dimension 3 scored ${d3} against the clean valid corpus, expected 100"
}
with_scratch_repo ca039_dim3_valid_corpus_case

ca039_dim3_invalid_corpus_case() {
  mkdir -p run-dir
  cat "${MERMAID_FIXTURES_DIR:-${PLUGIN_DIR}/bin/tests/fixtures/mermaid}/invalid"/*.md > run-dir/srd.md

  bash "$SCORE_ARTIFACTS" run-dir > out-dim3-invalid.json 2>/dev/null
  local d3
  d3="$(jq -r '.dimensions[2].score' out-dim3-invalid.json 2>/dev/null)"
  # G51/CA-211: the exact expected value is computable, not merely bounded. Every fixture in
  # invalid/ carries exactly one ```mermaid``` block with exactly one designed violation (zero
  # good blocks out of N total), so score_from_ratio(0, N) = 0 exactly -- a scorer that returned
  # 99 would incorrectly pass a "< 100" bound but must fail this exact-value assertion.
  [[ -n "$d3" && "$d3" != "null" && "$d3" -eq 0 ]] \
    && pass "CA-039 -- dimension 3 scores exactly 0 against the committed all-invalid fixture corpus (got ${d3})" \
    || fail "CA-039 -- dimension 3 scored ${d3} against the all-invalid corpus, expected exactly 0"
}
with_scratch_repo ca039_dim3_invalid_corpus_case

ca039_dim4_fabricated_id_case() {
  mkdir -p run-dir
  {
    echo '#### TSVE-01: first requirement'
    echo '- **Acceptance Criteria**:'
    echo '    - [ ] A concrete, testable behavior with a specific numeric threshold.'
    echo
    echo '#### TSVE-02: second requirement'
    echo '- **Acceptance Criteria**:'
    echo '    - [ ] Another concrete, testable behavior with a specific numeric threshold.'
  } > run-dir/srd.md
  {
    echo 'Coverage discussion: TSVE-01 and TSVE-02 are both covered.'
    echo 'This audit also references TSVE-99, a fabricated ID absent from srd.md, to exercise'
    echo 'the reverse (backward) half of the bidirectionality check.'
  } > run-dir/audit-srd.md

  bash "$SCORE_ARTIFACTS" run-dir > out-dim4.json 2>/dev/null
  local d4
  d4="$(jq -r '.dimensions[3].score' out-dim4.json 2>/dev/null)"
  # srd_ids={TSVE-01,TSVE-02} (2), target_ids={TSVE-01,TSVE-02,TSVE-99} (3).
  # forward_hits=2 (both srd IDs found in target), backward_hits=2 (TSVE-99 is NOT found in
  # srd_ids, so only 2 of the 3 target IDs match back). denom=2+3=5, numerator=2+2=4.
  # score_from_ratio(4,5) = round(100*4/5) = 80.
  [[ "$d4" == "80" ]] \
    && pass "CA-039 -- dimension 4 (coverage-map-bidirectionality) scores the hand-computed 80 with one fabricated reverse ID" \
    || fail "CA-039 -- dimension 4 scored ${d4}, expected the hand-computed value 80"
}
with_scratch_repo ca039_dim4_fabricated_id_case
# CA-039 remediation end

echo
echo "T23 AC4 -- --compare refuses on scorer_version and dimensions_scored mismatch"
t23_compare_refusal() {
  jq -n '{scorer_version:"1.0.0",dimensions_scored:4,dimensions:[{name:"a",score:80},{name:"b",score:90},{name:"c",score:70},{name:"d",score:60},{name:"e",score:null}],total:75.0}' \
    > base.json
  jq '.scorer_version = "1.0.1"' base.json > bumped-version.json
  jq '.dimensions_scored = 5' base.json > bumped-dims.json

  check_fails "--compare refuses on scorer_version mismatch, naming it" "scorer_version mismatch" \
    bash "$SCORE_ARTIFACTS" --compare base.json bumped-version.json
  check_fails "--compare refuses on dimensions_scored mismatch, naming it" "dimensions_scored mismatch" \
    bash "$SCORE_ARTIFACTS" --compare base.json bumped-dims.json

  bash "$SCORE_ARTIFACTS" --compare base.json base.json >/dev/null 2>&1 \
    && pass "--compare succeeds (exit 0) when scorer_version and dimensions_scored both match" \
    || fail "--compare unexpectedly refused two identical scores.json files"
}
with_scratch_repo t23_compare_refusal

echo
echo "T23 AC2 -- --describe prints the five dimension definitions verbatim"
t23_describe_output="$(bash "$SCORE_ARTIFACTS" --describe)"
check "describe names dimension 1 (requirement-id-coverage)" "requirement-id-coverage" "$t23_describe_output"
check "describe names dimension 2 (ac-testability)" "ac-testability" "$t23_describe_output"
check "describe names dimension 3 (mermaid-parse-success)" "mermaid-parse-success" "$t23_describe_output"
check "describe names dimension 4 (coverage-map-bidirectionality)" "coverage-map-bidirectionality" "$t23_describe_output"
check "describe names dimension 5 (lens-jsonl-prose-agreement)" "lens-jsonl-prose-agreement" "$t23_describe_output"

echo
echo "T23 AC7 -- vague-ac-patterns.txt is the single source, named by architecture.md"
VAGUE_PATTERNS="${PLUGIN_DIR}/evals/vague-ac-patterns.txt"
[[ -s "$VAGUE_PATTERNS" ]] && pass "vague-ac-patterns.txt exists and is non-empty" \
  || fail "vague-ac-patterns.txt missing or empty"
check_absent "no vague-AC regex list is duplicated inline in score-artifacts.sh" \
  "should work" "$(grep -v '^#' "$SCORE_ARTIFACTS")"

echo
echo "T23 AC8/AC9/AC10 -- baseline/README.md documents the four-dimension, tripwire framing"
BASELINE_README="${PLUGIN_DIR}/evals/baseline/README.md"
[[ -f "$BASELINE_README" ]] && pass "evals/baseline/README.md exists" \
  || fail "evals/baseline/README.md missing"
check "baseline/README.md states this is a four-dimension baseline" "four-dimension" \
  "$(cat "$BASELINE_README" 2>/dev/null)"
check "baseline/README.md records the max - min variance methodology" "max - min" \
  "$(cat "$BASELINE_README" 2>/dev/null)"
check "baseline/README.md states the tripwire framing" "tripwire" \
  "$(cat "$BASELINE_README" 2>/dev/null)"
check "baseline/README.md states re-versioning invalidates the baseline" "invalidates the baseline" \
  "$(cat "$BASELINE_README" 2>/dev/null)"
check "baseline/README.md records a run-artifact location outside plugins/edm" "outside plugins/edm" \
  "$(cat "$BASELINE_README" 2>/dev/null)"
[[ ! -f "${PLUGIN_DIR}/evals/baseline/scores.json" ]] \
  && pass "baseline/scores.json is intentionally absent pending the 3 live baseline runs (not faked)" \
  || fail "baseline/scores.json exists -- verify it was captured from real live runs, not fabricated"

echo
echo "T23 AC11 -- eval:nightly retains scores.json (via plugins/edm/evals/runs/) as a 30-day pipeline artifact"
t23_eval_job_block="$(awk '/^eval:nightly:/{f=1;next} f && /^[a-zA-Z]/{f=0} f' "$GITLAB_CI_YML")"
check "T23 AC11 -- eval:nightly job found in .gitlab-ci.yml" "artifacts" "$t23_eval_job_block"
check "T23 AC11 -- artifacts retained for 30 days" "expire_in: 30 days" "$t23_eval_job_block"
check "T23 AC11 -- artifacts path covers plugins/edm/evals/runs/ (where scores.json is written)" \
  "plugins/edm/evals/runs/" "$t23_eval_job_block"

echo
echo "T23 AC12 -- evals/README.md documents cost/duration and rejects 'CI will catch it'"
EVALS_README="${PLUGIN_DIR}/evals/README.md"
check "evals/README.md documents approximate cost per run" "cost" \
  "$(grep -i 'cost' "$EVALS_README" 2>/dev/null || true)"
check "evals/README.md names 'CI will catch it' as an invalid justification to skip a run" \
  "CI will catch it" "$(cat "$EVALS_README" 2>/dev/null)"
# EDMV3-T23 end

# =================================================================================
# EDMV3-T61: sentinel-delimited help block, bidirectional help-vs-dispatch test, and the
# generic zero-argument usage guard (wave-A scope: every subcommand present at this wave's
# dispatch boundary -- migrate-schema included, audit-converged/render-ledger/
# audit-round-complete land in later waves and are covered when they land, EDMV3-T66 AC3).
# =================================================================================

# _t61_dispatch_labels <edm-state-path> -- one case-label token per line from the live dispatch
# table's `case "$cmd" in ... esac` block, pipe-groups split onto separate lines, with the help
# pseudo-labels ("" / -h / --help / help) and the wildcard (*) filtered out. A label line is
# identified structurally (the text before its first ")" contains no whitespace) rather than by
# position, so a `die "...(...)"` message line elsewhere in the block is never mistaken for a
# label.
_t61_dispatch_labels() {
  local f="$1"
  awk '
    /^case "\$cmd" in/ {f=1; next}
    f && /^esac/ {f=0}
    f {
      line=$0
      gsub(/^[ \t]+/, "", line)
      idx = index(line, ")")
      if (idx > 0) {
        label = substr(line, 1, idx-1)
        if (label !~ / /) print label
      }
    }
  ' "$f" \
  | tr '|' '\n' \
  | grep -vxF '""' | grep -vxF -- '-h' | grep -vxF -- '--help' | grep -vxF 'help' | grep -vxF '*' \
  | sort -u
}

# _t61_help_subcommands <edm-state-path> -- one subcommand token per line documented inside the
# EDM-HELP-BEGIN/EDM-HELP-END sentinel block: the word immediately after "edm-state " on any doc
# line shaped "#   edm-state <name> ...". Filters the lone "-" token the header's own
# description line ("# edm-state - read/write ...") would otherwise contribute.
_t61_help_subcommands() {
  local f="$1"
  print_help "$f" \
    | grep -E '^#[[:space:]]+edm-state [a-zA-Z0-9_-]+' \
    | sed -E 's/^#[[:space:]]+edm-state ([a-zA-Z0-9_-]+).*/\1/' \
    | grep -vxF '-' \
    | sort -u
}

# _t61_bidirectional_check <edm-state-path> -- prints one "MISSING FROM HELP: <name>" or
# "MISSING FROM DISPATCH: <name>" line per mismatch; returns 1 iff any mismatch was found.
_t61_bidirectional_check() {
  local f="$1"
  local dispatch_file help_file miss=0 name
  dispatch_file="$(mktemp "${TMP}/edm-t61-dispatch.XXXXXX")"
  help_file="$(mktemp "${TMP}/edm-t61-help.XXXXXX")"
  _t61_dispatch_labels "$f" > "$dispatch_file"
  _t61_help_subcommands "$f" > "$help_file"

  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    echo "MISSING FROM HELP: $name"
    miss=1
  done < <(comm -23 "$dispatch_file" "$help_file")

  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    echo "MISSING FROM DISPATCH: $name"
    miss=1
  done < <(comm -13 "$dispatch_file" "$help_file")

  rm -f "$dispatch_file" "$help_file"
  return $miss
}

echo
echo "T61 AC2/AC3 -- help and dispatch agree in both directions"
set +e
t61_bidi_ec=0
t61_bidi_out="$(_t61_bidirectional_check "$EDM_STATE" 2>&1)" || t61_bidi_ec=$?
set -e
[[ $t61_bidi_ec -eq 0 ]] && pass "help and dispatch agree in both directions (zero mismatches)" \
  || fail "help and dispatch disagree:\n$t61_bidi_out"
check_absent "no MISSING FROM HELP line against the live tree" "MISSING FROM HELP" "$t61_bidi_out"
check_absent "no MISSING FROM DISPATCH line against the live tree" "MISSING FROM DISPATCH" "$t61_bidi_out"

echo
echo "T61 AC3 -- migrate-schema (wave A) and the list --paths flag are documented"
t61_help_out="$(bash "$EDM_STATE" --help 2>&1)"
check "help documents migrate-schema" "migrate-schema" "$t61_help_out"
t61_list_paths_line="$(printf '%s\n' "$t61_help_out" | grep -E 'list.*--paths' || true)"
[[ -n "$t61_list_paths_line" ]] \
  && pass "help documents list with the --paths flag on list's own line" \
  || fail "help output has no line matching 'list.*--paths'"

echo
echo "T61 AC4 -- help output is ASCII-only"
t61_help_nonascii="$(printf '%s\n' "$t61_help_out" | LC_ALL=C grep -n '[^ -~]' || true)"
[[ -z "$t61_help_nonascii" ]] && pass "T61 AC4 -- help output has zero non-ASCII lines" \
  || fail "T61 AC4 -- non-ASCII line(s) in help output: $t61_help_nonascii"

echo
echo "T61 AC2 -- negative: a dispatch entry with no matching help line fails, naming it"
t61_neg_case() {
  local scratch
  scratch="$(mktemp "${TMP}/edm-t61-neg.XXXXXX")" || { fail "T61 AC2 negative -- mktemp failed"; return 1; }
  # Inject a dispatch-only entry (bogus-new-cmd) with no corresponding help doc line, immediately
  # above the closing `esac` -- case arm order is irrelevant to bash, so this is always valid.
  awk '/^esac/{print "  bogus-new-cmd) die \"nope\" ;;"} {print}' "$EDM_STATE" > "$scratch"

  local out ec
  set +e
  ec=0
  out="$(_t61_bidirectional_check "$scratch" 2>&1)" || ec=$?
  set -e

  [[ $ec -ne 0 ]] && pass "T61 AC2 negative -- injected dispatch-only entry fails the check" \
    || fail "T61 AC2 negative -- injecting an undocumented dispatch entry did not fail the check"
  check "T61 AC2 negative -- failure names the injected subcommand" "bogus-new-cmd" "$out"

  rm -f "$scratch"
}
t61_neg_case

echo
echo "T61 AC5 -- every dispatch entry that requires arguments emits a usage: line on zero arguments"
# Documented allowlist (not a hardcoded subcommand list the guard itself uses -- the SET under
# test is still the live dispatch table via _t61_dispatch_labels): these entries are legitimately
# callable with zero arguments by design, so asserting a usage: line on zero args would be
# asserting a false contract for them.
#   - list, active-initiatives, checkpoint-if-active, git-lock-check, session-start: every
#     required argument is optional or absent by design.
#   - metrics-report: dispatches on an optional first arg (<PREFIX>|--all|--calibrate); zero
#     args is a valid "no scope" invocation path handled inside the command itself.
#   - watch-impl: an intentional infinite loop (tails git log until interrupted) -- it has no
#     usage-line concept and invoking it in a test would hang forever, not fail fast.
# Every name below must correspond to a live dispatch label. The duration-recording subcommand
# EDMV3-T58 deleted was listed here until that deletion landed; the entry then matched nothing
# and was removed with it (the deletion itself stays pinned by the T66 AC3 --help case further
# down, which is why that case names it and this comment does not). A name with no live
# dispatch entry is dead weight that also silently pre-exempts a future subcommand reusing it.
T61_ZERO_ARG_SAFE="list active-initiatives checkpoint-if-active git-lock-check session-start metrics-report watch-impl"
t61_usage_fail=0
t61_usage_names=""
while IFS= read -r t61_sub; do
  [[ -n "$t61_sub" ]] || continue
  case " $T61_ZERO_ARG_SAFE " in
    *" $t61_sub "*) continue ;;
  esac
  t61_out="$("$EDM_STATE" "$t61_sub" 2>&1)" || true
  # die() prefixes every message with "edm-state: " (e.g. "edm-state: usage: edm-state get
  # <PREFIX>"), so the assertion is "contains usage:", not line-anchored -- an anchored
  # ^usage: (as the ticket's own Verify line literally shows) never matches this codebase's
  # existing die() format and would falsely report every subcommand as non-compliant.
  if ! printf '%s\n' "$t61_out" | grep -q 'usage:'; then
    t61_usage_fail=1
    t61_usage_names="${t61_usage_names} ${t61_sub}"
  fi
done < <(_t61_dispatch_labels "$EDM_STATE")
[[ $t61_usage_fail -eq 0 ]] && pass "every non-exempt dispatch entry emits a usage: line on zero arguments" \
  || fail "these subcommand(s) did not emit a usage: line on zero arguments:${t61_usage_names}"

echo
echo "T61 AC5 -- migrate-schema (wave-A new subcommand) emits usage: on zero arguments"
t61_ms_out="$("$EDM_STATE" migrate-schema 2>&1)" || true
check "migrate-schema zero-args emits usage:" "usage: edm-state migrate-schema <PREFIX>" "$t61_ms_out"

echo
echo "T61 AC5 -- edm-check-grants carries set -euo pipefail"
# Anywhere in the file, not anchored to the first 5 lines -- every bin/ script here (edm-state,
# edm-lint-artifacts, edm-check-grants) carries a multi-line header/usage comment block before
# `set -euo pipefail`, consistent with this codebase's established convention; the ticket's own
# Verify line's `head -5` would falsely report 0 against that same, pre-existing convention.
# CA-037: a bare >=1 threshold on its own never proved this exact grep pattern is a working
# pattern rather than a typo -- cross-check the identical pattern against bin/edm-state, which is
# independently known (grep it yourself) to carry `set -euo pipefail`, as a real positive control.
# G2/CA-037 residual (round 5): one shared pattern variable for both files, not two
# independently-typed copies.
t61_pipefail_pattern='^set -euo pipefail'
t61_cg_pipefail_control="$(grep -c "$t61_pipefail_pattern" "$EDM_STATE" || true)"
if [[ "${t61_cg_pipefail_control:-0}" -lt 1 ]]; then
  fail "T61 AC5 -- positive control broken: the pattern found zero '^set -euo pipefail' in bin/edm-state, which is known to carry it"
else
  t61_cg_pipefail="$(grep -c "$t61_pipefail_pattern" "$EDM_CHECK_GRANTS" || true)"
  [[ "${t61_cg_pipefail:-0}" -ge 1 ]] && pass "edm-check-grants has set -euo pipefail (positive control confirms the pattern works against a known-good file)" \
    || fail "edm-check-grants set -euo pipefail count: ${t61_cg_pipefail:-0}"
fi

echo
echo "T61 AC9 -- no bash-4-only construct in any real bin/ script (bin/tests/ excluded -- test-fixture/assertion surface, same convention T09's caller_contract_scan already uses; comment-only mentions excluded -- a prose reference to why a construct is avoided is not a use of it)"
T61_BASH4_RE='declare -A|mapfile|readarray|\$\{[a-zA-Z_]+\^\^\}|\$\{[a-zA-Z_]+,,\}|\{fd\}'
t61_bash4_hits=""
while IFS= read -r t61_bf; do
  [[ -f "$t61_bf" ]] || continue
  while IFS= read -r t61_bl; do
    [[ -n "$t61_bl" ]] || continue
    t61_bash4_hits="${t61_bash4_hits}${t61_bf}:${t61_bl}"$'\n'
  done < <(grep -nE "$T61_BASH4_RE" "$t61_bf" 2>/dev/null | grep -vE '^[0-9]+:[[:space:]]*#')
done < <(find "$PLUGIN_DIR/bin" -maxdepth 1 -type f 2>/dev/null)
# CA-037: positive control -- the same $T61_BASH4_RE against a synthetic line containing a real
# bash-4-only construct, proving the alternation as a whole can actually fire before trusting the
# empty result above.
t61_bash4_control="$(printf '%s\n' 'declare -A foo' | grep -cE "$T61_BASH4_RE" || true)"
if [[ "${t61_bash4_control:-0}" -lt 1 ]]; then
  fail "T61 AC9 -- positive control broken: a synthetic 'declare -A foo' line was not caught by \$T61_BASH4_RE"
else
  [[ -z "$t61_bash4_hits" ]] && pass "T61 AC9 -- zero bash-4-only constructs found in real bin/ scripts (positive control confirms the pattern works)" \
    || fail "T61 AC9 -- bash-4-only construct(s) found:\n$t61_bash4_hits"
fi

echo
echo "T61 AC10 -- bash -n passes over every file in plugins/edm/bin/ (incl. bin/tests/*.sh)"
# CA-019: edm-mermaid-rules.awk is a plain awk source file (loaded via -f, never executed as
# bash), excluded here the same way .gitlab-ci.yml's real lint:bash-syntax job excludes it.
# G24/CA-233 (round 5): *.txt added alongside *.awk -- bin/vocabulary-allowlist.txt and
# bin/vocabulary-prohibited.txt are data files matched by the bin/* glob above, and this loop
# was syntax-checking them as bash source before this fix, the same class of gap the two real CI
# jobs (lint:bash-syntax, lint:shellcheck) were also fixed for.
t61_bashn_fail=0
for t61_f in "$PLUGIN_DIR"/bin/* "$PLUGIN_DIR"/bin/tests/*.sh; do
  [[ -f "$t61_f" ]] || continue
  case "$t61_f" in
    *.awk|*.txt) continue ;;
  esac
  bash -n "$t61_f" 2>/dev/null || { t61_bashn_fail=1; echo "  bash -n FAILED: $t61_f"; }
done
[[ $t61_bashn_fail -eq 0 ]] && pass "T61 AC10 -- bash -n passes over every bin/ and bin/tests/ file" \
  || fail "T61 AC10 -- bash -n failed on at least one file (see output above)"

# =================================================================================
# G24/CA-233 (round 5, third pass): lint:bash-syntax's exclusion was already fixed to *.awk|*.txt
# in an earlier wave; lint:shellcheck and this suite's own T61 AC10 twin were each missing one of
# the two extensions (shellcheck missed *.awk, T61 AC10 missed *.txt) -- both fixed above. Assert
# all three loops share the identical exclusion set so a future edit to just one of them cannot
# silently re-diverge the other two.
# =================================================================================
echo
echo "=== G24/CA-233: lint:bash-syntax, lint:shellcheck and this suite's own T61 AC10 twin all share the same *.awk|*.txt exclusion ==="
g24_ci_content="$(cat "$GITLAB_CI_YML" 2>/dev/null)"
g24_ci_exclusion_count="$(printf '%s\n' "$g24_ci_content" | grep -c '\*\.awk|\*\.txt) continue ;;' || true)"
[[ "${g24_ci_exclusion_count:-0}" -eq 2 ]] \
  && pass "G24/CA-233 -- .gitlab-ci.yml's lint:bash-syntax and lint:shellcheck both exclude *.awk and *.txt identically" \
  || fail "G24/CA-233 -- expected exactly 2 identical '*.awk|*.txt) continue ;;' lines in .gitlab-ci.yml (lint:bash-syntax + lint:shellcheck), found ${g24_ci_exclusion_count:-0} -- the two jobs' exclusion sets have diverged"
check "G24/CA-233 -- this suite's own T61 AC10 twin uses the identical exclusion set" \
  '*.awk|*.txt) continue ;;' "$(cat "${PLUGIN_DIR}/bin/tests/wave7-smoke.sh" 2>/dev/null)"

echo
echo "T61 AC11 -- macOS/Linux divergence points (sed -i, grep -P family, stat -c/-f, mktemp template suffix, date -d, readlink -f, sort -V, head -n -N, printf %q) are all inside a detection branch"
# -[a-zA-Z]*P (not a literal "grep -P") so this also catches grep -qP / -nP, the actual forms
# used by edm-lint-artifacts' PCRE-detection-and-fallback branch -- a literal "grep -P" search
# (as the ticket's own Verify command uses) misses those by one character and would falsely
# report zero hits, i.e. "nothing to check" rather than "checked and confined".
# CA-014: widened on two axes. Directory set now covers evals/ (not just bin/) -- the exact
# class that produced this finding (a GNU-only mktemp template regressed in evals/tiering-matrix.sh)
# lives outside bin/ and neither mechanism meant to protect the bash-3.2/BSD constraint would have
# seen a regression there under the old, bin/-only sweep. Pattern set now also covers three more
# GNU-only idioms this codebase must never depend on: a mktemp template with trailing characters
# after the XXXXXX run (BSD mktemp rejects a suffix there), `date -d`, `readlink -f`, `sort -V`,
# and `head -n -N` (negative count) -- none are used anywhere in bin/ or evals/ today, so this
# sweep currently reports zero hits for all four; it exists to catch a future regression, not a
# present one.
t61_divergence_hits="$(grep -rnE 'sed -i|grep -[a-zA-Z]*P|stat -c|stat -f|XXXXXX[A-Za-z0-9]|date -d|readlink -f|sort -V|head -n -[0-9]|printf %q' "$PLUGIN_DIR/bin/" "$PLUGIN_DIR/evals/" 2>/dev/null | grep -v '/tests/' || true)"
t61_divergence_outside_branch="$(printf '%s\n' "$t61_divergence_hits" | grep -v 'edm-lint-artifacts:' || true)"
[[ -z "$t61_divergence_outside_branch" ]] \
  && pass "T61 AC11 -- every divergence-point hit (bin/ and evals/) is inside edm-lint-artifacts' detection branch" \
  || fail "T61 AC11 -- divergence point(s) found outside the detection branch:\n$t61_divergence_outside_branch"
check "T61 AC11 -- edm-lint-artifacts' PCRE detection uses the documented grep -qP probe" \
  "grep -qP" "$t61_divergence_hits"
# EDMV3-T61 end

# =================================================================================
# EDMV3-T20 AC10 (shard-2 QC remediation): edm-lint-artifacts --path mode coverage --
# directory recursion, a single named file, and the read-only (no edm-state call) contract.
# The mode itself was already implemented (edm-lint-artifacts:278-307) but had zero assertions.
# =================================================================================
EDM_LINT_ARTIFACTS="${SCRIPT_DIR}/../edm-lint-artifacts"

echo
echo "T20 AC10 -- --path <dir> recurses into subdirectories and finds a nested violation"
t20_path_dir_case() {
  local scratch
  scratch="$(mktemp -d "${TMP}/edm-t20-path-dir.XXXXXX")" || { fail "T20 --path dir -- mktemp failed"; return 1; }
  mkdir -p "$scratch/a/b/c"
  printf '# top-level note\n\nClean ASCII content.\n' > "$scratch/top.md"
  printf '# nested note\n\nAlso clean ASCII content, three levels deep.\n' > "$scratch/a/b/c/nested.md"
  # An attribution-trailer violation buried two levels deep -- proves recursion actually reaches
  # it, not just the top-level file.
  printf '# violation note\n\nCo-Authored-By: Someone <someone@example.com>\n' > "$scratch/a/b/violation.md"

  local out ec
  set +e
  ec=0
  out="$("$EDM_LINT_ARTIFACTS" --path "$scratch" 2>&1)" || ec=$?
  set -e

  [[ $ec -ne 0 ]] && pass "T20 -- --path <dir> recursion finds a violation nested two levels deep" \
    || fail "T20 -- --path <dir> did not detect the nested violation (exit $ec):\n$out"
  check "T20 -- --path <dir> names the nested violation file" "a/b/violation.md" "$out"

  rm -rf "$scratch"
}
t20_path_dir_case

echo
echo "T20 AC10 -- --path <file> lints exactly the one named file"
t20_path_file_ec=0
t20_path_file_out="$("$EDM_LINT_ARTIFACTS" --path "${PLUGIN_DIR}/evals/fixtures/tiny-svc/README.md" 2>&1)" || t20_path_file_ec=$?
[[ $t20_path_file_ec -eq 0 ]] && pass "T20 -- --path <file> against a known-clean single file exits 0" \
  || fail "T20 -- --path <file> unexpectedly reported violations:\n$t20_path_file_out"
check "T20 -- --path <file> output names the file, not a directory-wide scan" \
  "tiny-svc/README.md" "$t20_path_file_out"

echo
echo "T20 AC10 -- --path never calls edm-state (read-only contract holds with edm-state off PATH)"
t20_path_no_edmstate_case() {
  local scratch scrub_path
  scratch="$(mktemp -d "${TMP}/edm-t20-path-noedm.XXXXXX")" || { fail "T20 --path no-edm-state -- mktemp failed"; return 1; }
  printf '# clean note\n\nNo violations here.\n' > "$scratch/note.md"

  # A PATH with only /usr/bin and /bin -- enough for find/sort/grep/sed/cut/tr to resolve, but
  # with every real bin/ directory (where edm-state actually lives) excluded.
  scrub_path="/usr/bin:/bin"
  local control ec out
  control="$(PATH="$scrub_path" command -v edm-state 2>&1 || true)"
  [[ -z "$control" ]] && pass "T20 -- edm-state is genuinely absent from the scrubbed PATH (control check)" \
    || fail "T20 -- edm-state still resolves on the scrubbed PATH ($control) -- test setup invalid"

  set +e
  ec=0
  out="$(PATH="$scrub_path" "$EDM_LINT_ARTIFACTS" --path "$scratch" 2>&1)" || ec=$?
  set -e
  [[ $ec -eq 0 ]] && pass "T20 -- --path succeeds with edm-state removed from PATH (no edm-state call)" \
    || fail "T20 -- --path failed with edm-state off PATH (exit $ec):\n$out"
  check_absent "T20 -- --path output never reports edm-state as missing" "edm-state not found" "$out"

  rm -rf "$scratch"
}
t20_path_no_edmstate_case
# EDMV3-T20 end

# =================================================================================
# EDMV3-T57 AC10 (was the EDMV3-T21 AC3 tripwire): lint:file-type-ban is now blocking.
# EDMV3-T57 relocated plugins/edm/'s two banned files, recorded a clean six-plugin scan, and
# flipped this job to blocking in the same merge request -- the tripwire case above (asserting
# `allow_failure: true` was still present) has served its purpose and is replaced by its own
# negative assertion: the flip landed and stayed landed. T66 AC11 cross-checks this at wave-C
# close.
# =================================================================================
echo
echo "T57 AC10 -- lint:file-type-ban no longer carries allow_failure (flipped to blocking)"
t21_ban_block="$(awk '/^lint:file-type-ban:/{f=1;next} f && /^[a-zA-Z]/{f=0} f' "$GITLAB_CI_YML")"
check "T57 AC10 -- lint:file-type-ban block found in .gitlab-ci.yml" "before_script" "$t21_ban_block"
check_absent "T57 AC10 -- lint:file-type-ban no longer carries allow_failure" "allow_failure" "$t21_ban_block"
# EDMV3-T57 AC10 end

# ---- AC5 (D19 amendment, decisions.md): no literal wave-suite token anywhere in
# .gitlab-ci.yml -- suites run via run-all.sh auto-discovery and are never hand-named. -------
echo
echo "T21 AC5 -- zero literal wave-suite tokens anywhere in .gitlab-ci.yml"
# CA-037: positive control -- the identical alternation against a synthetic line naming one of
# the wave-suite tokens, proving the pattern can actually match before trusting the zero below.
# G2/CA-037 residual (round 5): both greps below now share one pattern variable instead of two
# independently-typed copies of the same regex.
t21_wave_token_pattern='wave(3|4a|4b|5|6|7)-smoke'
t21_wave_token_control="$(printf '%s\n' 'bash plugins/edm/bin/tests/wave6-smoke.sh' | grep -cE "$t21_wave_token_pattern" || true)"
if [[ "${t21_wave_token_control:-0}" -lt 1 ]]; then
  fail "T21 AC5 -- positive control broken: a synthetic 'wave6-smoke' line was not caught by the pattern"
else
  t21_wave_token_hits="$(grep -cE "$t21_wave_token_pattern" "$GITLAB_CI_YML" || true)"
  t21_wave_token_hits="${t21_wave_token_hits:-0}"
  [[ "$t21_wave_token_hits" -eq 0 ]] \
    && pass "T21 AC5 -- .gitlab-ci.yml names zero literal wave-suite tokens (run-all.sh auto-discovery only; positive control confirms the pattern works)" \
    || fail "T21 AC5 -- found $t21_wave_token_hits literal wave-suite token(s) in .gitlab-ci.yml"
fi

echo
echo "T64 AC1 -- plugin.json and marketplace.json versions agree"
REPO_ROOT_T64="$(cd "$PLUGIN_DIR/../.." && pwd)"
t64_plugin_version="$(jq -r '.version' "$PLUGIN_DIR/.claude-plugin/plugin.json")"
t64_marketplace_version="$(jq -r '.plugins[] | select(.name=="edm") | .version' "$REPO_ROOT_T64/.claude-plugin/marketplace.json")"
[[ "$t64_plugin_version" == "$t64_marketplace_version" ]] \
  && pass "T64 AC1 -- plugin.json and marketplace.json versions agree ($t64_plugin_version)" \
  || fail "T64 AC1 -- plugin.json version '$t64_plugin_version' != marketplace.json edm entry '$t64_marketplace_version'"
# Superseded by EDMV3-T66 (wave-C closeout): the version literal this case asserts moved from
# T64's wave-A "2.1.0" through T65's wave-B "3.0.0" to T66's wave-C "3.1.0" -- each closeout
# ticket bumps the same field, and only the latest one's literal is current. This is the
# version-agreement half of the check (both manifests move together); T66's own wave6-smoke.sh
# cases assert the "3.1.0" value itself plus the schema_version decision.
[[ "$t64_plugin_version" == "3.1.0" ]] \
  && pass "T64 AC1 -- plugin.json version is 3.1.0 (EDMV3-T66 wave-C closeout)" \
  || fail "T64 AC1 -- plugin.json version is '$t64_plugin_version', expected '3.1.0'"

# =================================================================================
# EDMV3-T66: wave-C closeout -- version 3.1.0 and CLAUDE.md reference tables match reality
# =================================================================================
CLAUDE_MD_T66="${PLUGIN_DIR}/CLAUDE.md"

echo
echo "T66 AC1 -- versions agree (CHANGELOG.md wave-C entry present)"
check "T66 AC1 -- CHANGELOG.md has a 3.1.0 heading" "## [3.1.0]" "$(cat "${PLUGIN_DIR}/CHANGELOG.md")"

echo
echo "T66 AC2 -- schema_version decision recorded: stays at 2, no wave-C shape change"
check "T66 AC2 -- CHANGELOG.md records the schema_version decision" "schema_version" "$(cat "${PLUGIN_DIR}/CHANGELOG.md")"
check "T66 AC2 -- CLAUDE.md state-field table records the not-assigned decision" \
  "not assigned (EDMV3-T66 decision)" "$(cat "$CLAUDE_MD_T66")"
_t66ac2_fresh_schema_case() {
  "$EDM_STATE" init T66SCHEMA >/dev/null
  local sv
  sv="$("$EDM_STATE" get T66SCHEMA | jq -r '.schema_version')"
  # cmd_init's stamped value (1, EDMV3-T09) is a separate question from this ticket's decision
  # (whether wave C needed a NEW certified shape, value 3): it did not, so the contract table's
  # top row stays unchanged and this case only confirms init's existing, unmodified behavior.
  [[ "$sv" == "1" ]] \
    && pass "T66 AC2 -- a fresh initiative's cmd_init-stamped schema_version (1) is unchanged by the wave-C decision" \
    || fail "T66 AC2 -- fresh initiative schema_version = '$sv', expected '1'"
}
with_scratch_repo _t66ac2_fresh_schema_case

echo
echo "T66 AC3 -- subcommand count and membership match the dispatch table exactly"
t66ac3_dispatch_count="$({ grep -cE '^  [a-z][a-z0-9_-]*\)[[:space:]]+cmd_' "$EDM_STATE" || true; })"
t66ac3_claude_count="$({ grep -oE '[0-9]+ subcommands' "$CLAUDE_MD_T66" || true; } | head -1 | grep -oE '^[0-9]+')"
[[ "$t66ac3_dispatch_count" == "$t66ac3_claude_count" ]] \
  && pass "T66 AC3 -- CLAUDE.md's documented subcommand count ($t66ac3_claude_count) matches the dispatch table ($t66ac3_dispatch_count)" \
  || fail "T66 AC3 -- CLAUDE.md says $t66ac3_claude_count subcommands, dispatch table has $t66ac3_dispatch_count"
t66ac3_missing=""
for t66_c in audit-converged render-ledger audit-round-complete migrate-schema; do
  grep -q -- "$t66_c" "$CLAUDE_MD_T66" || t66ac3_missing="${t66ac3_missing} ${t66_c}"
done
[[ -z "$t66ac3_missing" ]] \
  && pass "T66 AC3 -- CLAUDE.md's bin/ table names all four wave-B/C subcommands" \
  || fail "T66 AC3 -- CLAUDE.md's bin/ table is missing:${t66ac3_missing}"
t66ac3_help_missing=""
for t66_c in audit-converged render-ledger audit-round-complete migrate-schema; do
  "$EDM_STATE" --help 2>&1 | grep -q -- "$t66_c" || t66ac3_help_missing="${t66ac3_help_missing} ${t66_c}"
done
[[ -z "$t66ac3_help_missing" ]] \
  && pass "T66 AC3 -- --help enumerates all four wave-B/C subcommands" \
  || fail "T66 AC3 -- --help is missing:${t66ac3_help_missing}"
t66ac3_rtd="$("$EDM_STATE" --help 2>&1 | grep -c record-task-duration || true)"
[[ "${t66ac3_rtd:-0}" -eq 0 ]] \
  && pass "T66 AC3 -- record-task-duration is absent from --help (deleted, EDMV3-T58)" \
  || fail "T66 AC3 -- record-task-duration still appears in --help"

echo
echo "T58 AC1 -- implement no longer names edm-test-coverage-auditor"
# The other half of the same delete-list ticket as the T66 AC3 --help case above.
# EDMV3-T58 removed the coverage auditor from the Phase 6 implement flow -- it belongs to
# /edm:test, which owns coverage. The condition has held since the reference was deleted, but
# nothing pinned it, so a later edit could reintroduce the spawn silently and nothing would
# fail. `grep -c` is guarded with `|| true`: a zero-match grep exits 1, which would abort the
# whole suite under `set -euo pipefail` -- and zero is precisely the passing value here.
T58_IMPLEMENT_SKILL="${PLUGIN_DIR}/skills/implement/SKILL.md"
t58ac1_pattern='edm-test-coverage-auditor'
t58ac1_count="$(grep -c "$t58ac1_pattern" "$T58_IMPLEMENT_SKILL" || true)"
[[ "${t58ac1_count:-0}" -eq 0 ]] \
  && pass "T58 AC1 -- zero occurrences of edm-test-coverage-auditor in skills/implement/SKILL.md" \
  || fail "T58 AC1 -- skills/implement/SKILL.md names edm-test-coverage-auditor ${t58ac1_count} time(s)"
# Positive control for the zero above: a zero-occurrence assertion also passes when the needle
# is misspelled or the path is wrong, which would make it a permanently-green no-op. Prove the
# identical needle still matches where the agent legitimately survives. Scoped to agents/
# (the agent's own definition, plus edm-audit-test-quality's reference to it) rather than to
# the whole plugin, which would include this suite's own text and be self-satisfying.
# G2/CA-037 residual (round 5): one shared pattern variable, not two independently-typed copies.
t58ac1_live="$({ grep -rl "$t58ac1_pattern" "${PLUGIN_DIR}/agents/" 2>/dev/null || true; } | wc -l | tr -d ' ')"
[[ "${t58ac1_live:-0}" -gt 0 ]] \
  && pass "T58 AC1 -- positive control: the same needle still matches ${t58ac1_live} file(s) under agents/, so the zero above is real" \
  || fail "T58 AC1 -- positive control failed: 'edm-test-coverage-auditor' matches nothing under agents/, so the zero-occurrence assertion above is vacuous"

echo
echo "T66 AC4 -- linter row, hook row and mode row are accurate (wrong class names gone)"
# G19 (round-3 Wave 7c): the hardcoded "four violation classes" count drifted true as classes
# were added, so the bin/ table row now points readers at `--help` instead of a count that goes
# stale again the next time a class is added.
check "T66 AC4 -- bin/ table points readers at edm-lint-artifacts --help rather than a hardcoded class count" \
  "edm-lint-artifacts --help" "$(cat "$CLAUDE_MD_T66")"
# CA-037: three deleted-text counts, none previously proving their own grep pattern could match
# anything -- each gets a synthetic positive control run through the identical pattern first.
# G2/CA-037 residual (round 5): each pattern is now one variable shared by its control grep and
# its real grep, instead of two independently-typed copies.
t66ac4_wrong_classes_pattern='missing version header\|orphan file\|oversized ticket'
t66ac4_wrong_classes_control="$(printf '%s\n' 'a row mentioning missing version header' | grep -c "$t66ac4_wrong_classes_pattern" || true)"
if [[ "${t66ac4_wrong_classes_control:-0}" -lt 1 ]]; then
  fail "T66 AC4 -- positive control broken: a synthetic 'missing version header' line was not caught"
else
  t66ac4_wrong_classes="$({ grep -rl "$t66ac4_wrong_classes_pattern" "$CLAUDE_MD_T66" || true; } | wc -l | tr -d ' ')"
  [[ "${t66ac4_wrong_classes:-0}" -eq 0 ]] \
    && pass "T66 AC4 -- no reference to the three never-implemented violation classes (positive control confirms the pattern works)" \
    || fail "T66 AC4 -- found a reference to a never-implemented violation class"
fi
t66ac4_taskcompleted_pattern='TaskCompleted'
t66ac4_taskcompleted_control="$(printf '%s\n' 'a row mentioning TaskCompleted' | grep -c "$t66ac4_taskcompleted_pattern" || true)"
if [[ "${t66ac4_taskcompleted_control:-0}" -lt 1 ]]; then
  fail "T66 AC4 -- positive control broken: a synthetic 'TaskCompleted' line was not caught"
else
  t66ac4_taskcompleted="$({ grep -rl "$t66ac4_taskcompleted_pattern" "$CLAUDE_MD_T66" || true; } | wc -l | tr -d ' ')"
  [[ "${t66ac4_taskcompleted:-0}" -eq 0 ]] \
    && pass "T66 AC4 -- Hooks behavior table drops TaskCompleted (positive control confirms the pattern works)" \
    || fail "T66 AC4 -- TaskCompleted still referenced in CLAUDE.md"
fi
t66ac4_lcpartial_pattern='lifecycle_mode.*partial'
t66ac4_lcpartial_control="$(printf '%s\n' 'lifecycle_mode row still says partial' | grep -c "$t66ac4_lcpartial_pattern" || true)"
if [[ "${t66ac4_lcpartial_control:-0}" -lt 1 ]]; then
  fail "T66 AC4 -- positive control broken: a synthetic 'lifecycle_mode ... partial' line was not caught"
else
  t66ac4_lcpartial="$({ grep -rl "$t66ac4_lcpartial_pattern" "$CLAUDE_MD_T66" || true; } | wc -l | tr -d ' ')"
  [[ "${t66ac4_lcpartial:-0}" -eq 0 ]] \
    && pass "T66 AC4 -- lifecycle_mode row drops partial (positive control confirms the pattern works)" \
    || fail "T66 AC4 -- lifecycle_mode row still mentions partial"
fi

echo
echo "T66 AC5 -- state-field table documents schema_version/enforcement/round_type/closing_verdict"
for t66_field in schema_version enforcement round_type closing_verdict; do
  check "T66 AC5 -- ${t66_field} is documented in the state-field table" "$t66_field" "$(cat "$CLAUDE_MD_T66")"
done

echo
echo "T66 AC6 -- documented agent and skill counts match reality"
t66ac6_agent_disk="$(ls "${PLUGIN_DIR}/agents/"*.md | wc -l | tr -d ' ')"
t66ac6_skill_manifest="$(jq -r '.plugins[] | select(.name=="edm") | .skills | length' "$(cd "$PLUGIN_DIR/../.." && pwd)/.claude-plugin/marketplace.json")"
[[ "$t66ac6_agent_disk" -eq 30 ]] \
  && pass "T66 AC6 -- 30 agent files on disk (source of truth: ls \$PLUGIN_DIR/agents/*.md, same baseline as T03 AC9)" \
  || fail "T66 AC6 -- found $t66ac6_agent_disk agent file(s) on disk, expected 30 (source of truth: ls \$PLUGIN_DIR/agents/*.md)"
[[ "$t66ac6_skill_manifest" -eq 14 ]] \
  && pass "T66 AC6 -- 14 skills declared in marketplace.json (post verify-runtime; source of truth: .claude-plugin/marketplace.json .plugins[].skills)" \
  || fail "T66 AC6 -- marketplace.json declares $t66ac6_skill_manifest skill(s), expected 14 (source of truth: .claude-plugin/marketplace.json .plugins[].skills)"

echo
echo "T66 AC7 -- Testing changes section names CI as the primary verification path"
check "T66 AC7 -- CI is the primary verification path" "CI is the primary verification path" "$(cat "$CLAUDE_MD_T66")"
echo "T66 AC7 -- lens tiering table update: BLOCKED on EDMV3-T48 (out of this ticket's scope, not"
echo "  yet run -- all 11 lens agents remain opus/max on disk). Recorded honestly in CHANGELOG.md"
echo "  rather than asserted here as a passing case (D15: an unmet precondition is not faked)."

echo
echo "T66 AC9 -- update-patterns writes atomically; audit-round-complete routes through rmw_state"
check "T66 AC9 -- update-patterns' insertion path is an atomic mv into the docs/audit-patterns/*.md target" \
  'write_atomic "$pattern_file" _splice_pattern_file' "$(cat "$EDM_STATE")"
t66ac9_arc_body="$(awk '/^cmd_audit_round_complete\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"
check "T66 AC9 -- cmd_audit_round_complete completes via with_state_lock" "with_state_lock" "$t66ac9_arc_body"

echo
echo "T66 AC11 -- allow_failure is scoped to only the plugin-cli validate and eval jobs"
# G40/CA-271 (round 4): the terminator regex excludes '#' from the FIRST character class too, not
# just the rest of the line -- the previous `^[^[:space:]][^#]*:$` treated '#' as a valid first
# character (it is not whitespace), so a column-0 comment line ending in a colon (e.g. "# See:")
# was misread as the next job's header and silently truncated the block being extracted.
t66_validate_plugin_block="$(awk '/^validate:plugin-cli:/{f=1;next} f && /^[^[:space:]#][^#]*:$/ {f=0} f' "$GITLAB_CI_YML")"
t66_eval_block="$(awk '/^eval:nightly:/{f=1;next} f && /^[^[:space:]#][^#]*:$/ {f=0} f' "$GITLAB_CI_YML")"
check "T66 AC11 -- validate:plugin-cli carries allow_failure" "allow_failure: true" "$t66_validate_plugin_block"
check "T66 AC11 -- eval:nightly carries allow_failure" "allow_failure: true" "$t66_eval_block"
# CA-100: an absent job (deleted, renamed, or a typo in the loop's own job-name list) yields an
# EMPTY t66_job_block, which has no "allow_failure" substring and was silently scored compliant --
# the far more consequential fact (the job does not exist at all) went unreported. Assert
# existence and `stage: lint` before testing the block's content, and assert the union of the
# four jobs' scripts actually names all four checkers CA-100 says this split job graph must run.
t66_lint_allow_fail=""
t66_lint_missing=""
t66_lint_not_lint_stage=""
t66_lint_union=""
for t66_job in lint:bash-syntax lint:artifacts lint:grants lint:vocabulary; do
  t66_job_block="$(awk -v job="^${t66_job}:$" '$0 ~ job {f=1;next} f && /^[^[:space:]#][^#]*:$/ {f=0} f' "$GITLAB_CI_YML")"
  if [[ -z "$t66_job_block" ]]; then
    t66_lint_missing="${t66_lint_missing} ${t66_job}"
    continue
  fi
  [[ "$t66_job_block" == *"stage: lint"* ]] || t66_lint_not_lint_stage="${t66_lint_not_lint_stage} ${t66_job}"
  [[ "$t66_job_block" == *"allow_failure"* ]] && t66_lint_allow_fail="${t66_lint_allow_fail} ${t66_job}"
  t66_lint_union="${t66_lint_union}
${t66_job_block}"
done
[[ -z "$t66_lint_missing" ]] \
  && pass "T66 AC11 -- all four split lint jobs exist in .gitlab-ci.yml" \
  || fail "T66 AC11 -- job(s) not found in .gitlab-ci.yml:${t66_lint_missing}"
[[ -z "$t66_lint_not_lint_stage" ]] \
  && pass "T66 AC11 -- all four split lint jobs declare stage: lint" \
  || fail "T66 AC11 -- job(s) missing 'stage: lint':${t66_lint_not_lint_stage}"
[[ -z "$t66_lint_allow_fail" ]] \
  && pass "T66 AC11 -- none of the four split lint jobs carry allow_failure" \
  || fail "T66 AC11 -- split lint job(s) unexpectedly carry allow_failure:${t66_lint_allow_fail}"
t66_lint_union_missing=""
for t66_checker in "bash -n" "edm-lint-artifacts" "edm-check-grants" "edm-check-vocabulary"; do
  printf '%s' "$t66_lint_union" | grep -qF -- "$t66_checker" || t66_lint_union_missing="${t66_lint_union_missing} '${t66_checker}'"
done
[[ -z "$t66_lint_union_missing" ]] \
  && pass "T66 AC11 -- the union of the four lint jobs' scripts names bash -n, edm-lint-artifacts, edm-check-grants and edm-check-vocabulary" \
  || fail "T66 AC11 -- the four lint jobs' scripts are missing:${t66_lint_union_missing}"
check "T66 AC11 -- code-audit uses audit-round-start with --lenses" "--lenses" "$(grep 'audit-round-start' "${PLUGIN_DIR}/skills/code-audit/SKILL.md" || true)"

# ---- CA-094: whole-tree edm-lint-artifacts --all / edm-check-grants: run ONCE here, asserted by
# every block below that used to run its own redundant whole-tree scan. G50/CA-281 (round 4):
# this is NOT the earliest point in the suite that runs edm-check-grants against the live tree --
# the T03 AC2/AC4 block far above (~line 231) runs its own separate `bash "$EDM_CHECK_GRANTS"`
# invocation, deliberately kept as its own live run rather than folded into this hoist: T03's
# block is testing edm-check-grants ITSELF (its --list-sources/--bogus-flag exit contract
# immediately before it, in the same self-contained section) before the INVARIANT below -- which
# governs every consumer of THIS capture -- even exists, and predates it in the file. Hoisting
# T03's check into this capture would entangle an early, standalone binary-under-test assertion
# with a shared, invariant-tracked capture 1000+ lines later for no behavioral gain (both runs
# scan the same unmutated live tree; nothing between the two positions changes cwd, EDM_SRD_ROOT,
# or the tracked SRD tree). This hoist IS, however, the earliest point for every OTHER consumer:
# it replaces what were seven separate redundant whole-tree scans further below. Five of those
# seven earlier scans discarded their own output entirely; the two that inspect content (T43 AC9,
# T44 AC7) get the real captured text below instead of a second live invocation.
# INVARIANT: nothing from this line to the end of the file may mutate the tracked SRD tree or
# change EDM_SRD_ROOT/cwd -- every consumer below re-checks the fingerprint before reusing the
# captured values, so a violation fails loudly by name rather than silently reading stale output.
WAVE7_ALL_LINT_CWD="$(pwd)"
WAVE7_ALL_LINT_SRD_ROOT="${EDM_SRD_ROOT:-}"
WAVE7_ALL_LINT_GIT_STATUS="$(git -C "$PLUGIN_DIR/../.." status --porcelain 2>/dev/null || true)"
WAVE7_ALL_LINT_EXIT=0
WAVE7_ALL_LINT_OUT="$(bash "${PLUGIN_DIR}/bin/edm-lint-artifacts" --all 2>&1)" || WAVE7_ALL_LINT_EXIT=$?
WAVE7_GRANTS_EXIT=0
WAVE7_GRANTS_OUT="$(bash "${PLUGIN_DIR}/bin/edm-check-grants" 2>&1)" || WAVE7_GRANTS_EXIT=$?

# _wave7_assert_shared_lint_fresh <label> -- fails loudly, naming <label>, if the tracked tree,
# cwd, or EDM_SRD_ROOT drifted since the shared lint/grants capture above. Every reuse site below
# calls this before trusting $WAVE7_ALL_LINT_* / $WAVE7_GRANTS_*.
_wave7_assert_shared_lint_fresh() {
  local label="$1"
  if [[ "$(pwd)" != "$WAVE7_ALL_LINT_CWD" || "${EDM_SRD_ROOT:-}" != "$WAVE7_ALL_LINT_SRD_ROOT" ]]; then
    fail "${label} -- shared-lint invariant violated: cwd or EDM_SRD_ROOT drifted since capture"
    return 1
  fi
  if [[ "$(git -C "$PLUGIN_DIR/../.." status --porcelain 2>/dev/null || true)" != "$WAVE7_ALL_LINT_GIT_STATUS" ]]; then
    fail "${label} -- shared-lint invariant violated: tracked-tree fingerprint changed since capture"
    return 1
  fi
  return 0
}

echo
echo "T66 AC12 -- Definition-of-Done spot-check (four mechanical checks)"
t66ac12_flag_leak_pattern='code_audit_converged true'
t66ac12_flag_leak="$({ grep -c "$t66ac12_flag_leak_pattern" "${PLUGIN_DIR}/skills/"*/SKILL.md 2>/dev/null || true; } | awk -F: '{s+=$2} END{print s+0}')"
# CA-037: positive control proving the same grep -c invocation would actually report >=1 against
# a line that legitimately contains the needle, so the "0" above is a real absence.
# G2/CA-037 residual (round 5): one shared pattern variable, not two independently-typed copies.
t66ac12_flag_leak_control="$(printf '%s\n' 'synthetic control: code_audit_converged true' | grep -c "$t66ac12_flag_leak_pattern" || true)"
if [[ "${t66ac12_flag_leak_control:-0}" -lt 1 ]]; then
  fail "T66 AC12 -- positive control broken: a synthetic 'code_audit_converged true' line was not counted"
else
  [[ "${t66ac12_flag_leak:-0}" -eq 0 ]] \
    && pass "T66 AC12 -- no prompt sets code_audit_converged true directly (positive control confirms the count would be >=1 if present)" \
    || fail "T66 AC12 -- found a direct code_audit_converged true instruction"
fi
t66ac12_orch_lines="$(wc -l < "${PLUGIN_DIR}/skills/orchestrator/SKILL.md" | tr -d ' ')"
[[ "$t66ac12_orch_lines" -le 300 ]] \
  && pass "T66 AC12 -- orchestrator/SKILL.md is $t66ac12_orch_lines lines (<= 300)" \
  || fail "T66 AC12 -- orchestrator/SKILL.md is $t66ac12_orch_lines lines, expected <= 300"
_wave7_assert_shared_lint_fresh "T66 AC12"
[[ "$WAVE7_ALL_LINT_EXIT" -eq 0 ]] \
  && pass "T66 AC12 -- edm-lint-artifacts --all exits 0 (captured once; CA-094)" \
  || fail "T66 AC12 -- edm-lint-artifacts --all exited $WAVE7_ALL_LINT_EXIT (captured once; output: ${WAVE7_ALL_LINT_OUT})"
t66ac12_force_pattern='--force'
t66ac12_accept_pattern='--accept-partials'
t66ac12_force_hits="$(grep -rn -- "${t66ac12_force_pattern}\|${t66ac12_accept_pattern}" "${PLUGIN_DIR}/bin" "${PLUGIN_DIR}/skills" "${PLUGIN_DIR}/agents" 2>/dev/null \
  | grep -v tests/ | grep -v 'vocabulary-' | grep -v "refused:" || true)"
# G20 (round-3): this repo-wide escape-hatch scan had no proof either OR'd needle could ever
# match -- routed through assert_tree_absent per needle (G2/CA-037 + G13/CA-145, round 4). The
# control is a genuinely seeded scratch file rather than a hand-typed literal, and each of the
# three scanned directories is asserted to exist before the needle check runs (a broken
# PLUGIN_DIR previously read identically to a genuinely clean tree).
# G2/CA-037 residual (round 5): the producing grep's OR'd pattern is now built from the same two
# variables ($t66ac12_force_pattern/$t66ac12_accept_pattern) passed to assert_tree_absent below,
# instead of a third, independently-typed copy of each literal -- a typo in either pattern now
# breaks the real scan and the check identically. Each control is additionally routed through the
# same three-stage filter chain the real scan applies, so a filter widened to swallow real hits
# swallows the synthetic one too.
t66ac12_force_control="${TMP}/edm-t66-force-control.txt"
printf -- '--force\n' | grep -v tests/ | grep -v 'vocabulary-' | grep -v "refused:" > "$t66ac12_force_control"
assert_tree_absent "T66 AC12 -- no --force escape hatch outside tests/vocabulary/refusal text" \
  "$t66ac12_force_pattern" "$t66ac12_force_hits" "$(cat "$t66ac12_force_control")" \
  "${PLUGIN_DIR}/bin" "${PLUGIN_DIR}/skills" "${PLUGIN_DIR}/agents"
t66ac12_accept_control="${TMP}/edm-t66-accept-control.txt"
printf -- '--accept-partials\n' | grep -v tests/ | grep -v 'vocabulary-' | grep -v "refused:" > "$t66ac12_accept_control"
assert_tree_absent "T66 AC12 -- no --accept-partials escape hatch outside tests/vocabulary/refusal text" \
  "$t66ac12_accept_pattern" "$t66ac12_force_hits" "$(cat "$t66ac12_accept_control")" \
  "${PLUGIN_DIR}/bin" "${PLUGIN_DIR}/skills" "${PLUGIN_DIR}/agents"
rm -f "$t66ac12_force_control" "$t66ac12_accept_control"
# EDMV3-T66 end

# =================================================================================
# EDMV3-T24: every lens emits JSONL with confidence under a two-path output contract.
# This block asserts the eleven lens agent prompts (agents/edm-audit-*.md, excluding the
# synthesizer, which is not a lens) and the committed AC0 fixture at
# bin/tests/fixtures/code-audit/. Batch scope note: this agent's remit for this batch is
# agents/edm-audit-*.md, skills/code-audit/SKILL.md, and this wave7-smoke.sh append block --
# bin/edm-state, bin/edm-lint-artifacts and plugins/edm/CLAUDE.md are out of scope and are not
# touched here (owned by other agents this batch).
# =================================================================================
LENS_AGENTS="edm-audit-logic edm-audit-dead-code edm-audit-edge-cases edm-audit-test-quality edm-audit-runtime edm-audit-docs edm-audit-consistency edm-audit-security edm-audit-spec edm-audit-dry edm-audit-wiring"
CODE_AUDIT_FIXTURE_DIR="${PLUGIN_DIR}/bin/tests/fixtures/code-audit"
ARCHITECTURE_MD="$(cd "$PLUGIN_DIR/../.." && pwd)/SRD/edm/EDMV3__prompt-streamline/architecture.md"

echo
echo "T24 AC0 -- committed synthetic code-audit pass fixture exists with the required shape"
t24_jsonl_count="$(ls "${CODE_AUDIT_FIXTURE_DIR}"/lens-L*.jsonl 2>/dev/null | wc -l | tr -d '[:space:]')"
[[ "$t24_jsonl_count" -eq 11 ]] && pass "T24 AC0 -- eleven lens-L*.jsonl fixture files present" \
  || fail "T24 AC0 -- found $t24_jsonl_count lens-L*.jsonl fixture file(s), expected 11"
t24_md_count="$(ls "${CODE_AUDIT_FIXTURE_DIR}"/lens-L*.md 2>/dev/null | wc -l | tr -d '[:space:]')"
[[ "$t24_md_count" -eq 11 ]] && pass "T24 AC0 -- eleven lens-L*.md fixture prose reports present" \
  || fail "T24 AC0 -- found $t24_md_count lens-L*.md fixture file(s), expected 11"
[[ -f "${CODE_AUDIT_FIXTURE_DIR}/lenses-run.txt" ]] && pass "T24 AC0 -- lenses-run.txt present" \
  || fail "T24 AC0 -- lenses-run.txt missing"
check "T24 AC0 -- lenses-run.txt carries the Round type: header" "Round type: full" \
  "$(cat "${CODE_AUDIT_FIXTURE_DIR}/lenses-run.txt" 2>/dev/null)"
[[ -s "${CODE_AUDIT_FIXTURE_DIR}/README.md" ]] && pass "T24 AC0 -- fixture README.md present and non-empty" \
  || fail "T24 AC0 -- fixture README.md missing or empty"
check "T24 AC0 -- fixture README states it is hand-authored, not captured" "hand-authored" \
  "$(cat "${CODE_AUDIT_FIXTURE_DIR}/README.md" 2>/dev/null)"
t24_l1_sevs="$(jq -sr '[.[].sev] | sort | unique | join(",")' "${CODE_AUDIT_FIXTURE_DIR}/lens-L1.jsonl" 2>/dev/null)"
[[ "$t24_l1_sevs" == "NOTED,P0,P1,P2" ]] \
  && pass "T24 AC0 -- lens-L1.jsonl covers every severity (NOTED,P0,P1,P2)" \
  || fail "T24 AC0 -- lens-L1.jsonl severities were '$t24_l1_sevs', expected 'NOTED,P0,P1,P2'"
check "T24 AC0 -- lens-L1.jsonl carries a fixed-status line" '"status":"fixed"' \
  "$(cat "${CODE_AUDIT_FIXTURE_DIR}/lens-L1.jsonl" 2>/dev/null)"
check "T24 AC0 -- lens-L1.jsonl carries a legacy deferred-status line for the re-open fixture" '"status":"deferred"' \
  "$(cat "${CODE_AUDIT_FIXTURE_DIR}/lens-L1.jsonl" 2>/dev/null)"

echo
echo "T24 AC1 -- eleven lens prompts instruct a JSONL sibling"
t24_ac1_count=0
for t24_agent in $LENS_AGENTS; do
  grep -q "one JSON object per line, one line for every finding" "${PLUGIN_DIR}/agents/${t24_agent}.md" \
    && t24_ac1_count=$((t24_ac1_count + 1))
done
[[ "$t24_ac1_count" -eq 11 ]] && pass "T24 AC1 -- eleven lens prompts instruct a JSONL sibling" \
  || fail "T24 AC1 -- only $t24_ac1_count/11 lens prompts instruct a JSONL sibling"

echo
echo "T24 AC2 -- lens JSONL schema text present in eleven files"
t24_ac2_count=0
for t24_agent in $LENS_AGENTS; do
  t24_hits="$(grep -c '"schema":1' "${PLUGIN_DIR}/agents/${t24_agent}.md" 2>/dev/null || true)"
  [[ "${t24_hits:-0}" -ge 1 ]] && t24_ac2_count=$((t24_ac2_count + 1))
done
[[ "$t24_ac2_count" -eq 11 ]] && pass "T24 AC2 -- eleven lens files carry the fixed schema text" \
  || fail "T24 AC2 -- only $t24_ac2_count/11 lens files carry '\"schema\":1'"

echo
echo "T24 AC3 -- no lens declares a deferred status (scoped to this ticket's own JSONL Line Format section)"
t24_ac3_fail=0
for t24_agent in $LENS_AGENTS; do
  t24_section="$(awk '/^## JSONL Line Format/{f=1} f' "${PLUGIN_DIR}/agents/${t24_agent}.md")"
  if printf '%s' "$t24_section" | grep -qi 'deferred'; then
    t24_ac3_fail=1
    echo "  FOUND 'deferred' in ${t24_agent}.md JSONL Line Format section"
  fi
done
[[ "$t24_ac3_fail" -eq 0 ]] && pass "T24 AC3 -- no lens JSONL Line Format section declares a deferred status" \
  || fail "T24 AC3 -- at least one lens JSONL Line Format section mentions 'deferred'"

echo
echo "T24 AC4 -- confidence is mandatory in every lens prompt"
t24_ac4_count=0
for t24_agent in $LENS_AGENTS; do
  t24_hits="$(grep -c 'confidence' "${PLUGIN_DIR}/agents/${t24_agent}.md" 2>/dev/null || true)"
  [[ "${t24_hits:-0}" -ge 1 ]] && t24_ac4_count=$((t24_ac4_count + 1))
done
[[ "$t24_ac4_count" -eq 11 ]] && pass "T24 AC4 -- eleven lens files mandate confidence" \
  || fail "T24 AC4 -- only $t24_ac4_count/11 lens files mention confidence"

echo
echo "T24 AC5 -- scope stated literally: 'every finding' in every lens prompt"
t24_ac5_count=0
for t24_agent in $LENS_AGENTS; do
  t24_hits="$(grep -c 'every finding' "${PLUGIN_DIR}/agents/${t24_agent}.md" 2>/dev/null || true)"
  [[ "${t24_hits:-0}" -ge 1 ]] && t24_ac5_count=$((t24_ac5_count + 1))
done
[[ "$t24_ac5_count" -eq 11 ]] && pass "T24 AC5 -- eleven lens files state 'every finding'" \
  || fail "T24 AC5 -- only $t24_ac5_count/11 lens files state 'every finding'"

echo
echo "T24 AC6/AC8 -- eleven lens files contain the two-path contract text"
t24_ac6_count=0
for t24_agent in $LENS_AGENTS; do
  t24_output_section="$(awk '/^## Output$/{f=1} f && /^## Output Format/{exit} f' "${PLUGIN_DIR}/agents/${t24_agent}.md")"
  if printf '%s' "$t24_output_section" | grep -q "authoritative on conflict" \
    && printf '%s' "$t24_output_section" | grep -q "exactly one corresponding"; then
    t24_ac6_count=$((t24_ac6_count + 1))
  fi
done
[[ "$t24_ac6_count" -eq 11 ]] && pass "T24 AC6/AC8 -- eleven lens '## Output' sections state the JSONL-authoritative, one-line-per-finding contract" \
  || fail "T24 AC6/AC8 -- only $t24_ac6_count/11 lens '## Output' sections state the two-path contract"

echo
echo "T24 AC7 -- every emitted line of every fixture JSONL file is valid JSON"
t24_ac7_bad=0
for t24_n in 1 2 3 4 5 6 7 8 9 10 11; do
  t24_f="${CODE_AUDIT_FIXTURE_DIR}/lens-L${t24_n}.jsonl"
  [[ -f "$t24_f" ]] || { t24_ac7_bad=1; echo "  MISSING: $t24_f"; continue; }
  while IFS= read -r t24_line; do
    [[ -z "$t24_line" ]] && continue
    echo "$t24_line" | jq -e . >/dev/null 2>&1 || { t24_ac7_bad=1; echo "  BAD JSON in $t24_f: $t24_line"; }
  done < "$t24_f"
done
[[ "$t24_ac7_bad" -eq 0 ]] && pass "T24 AC7 -- every line of every fixture lens-L*.jsonl file is valid JSON" \
  || fail "T24 AC7 -- at least one fixture JSONL line failed to parse (see above)"

echo
echo "T24 AC9 -- residual risk (count match does not imply content match) documented in edm-audit-logic.md and architecture.md"
check "T24 AC9 -- edm-audit-logic.md states the residual-risk sentence" "count match does not imply" \
  "$(cat "${PLUGIN_DIR}/agents/edm-audit-logic.md" 2>/dev/null)"
check "T24 AC9 -- architecture.md states the residual-risk sentence" "count match does not imply" \
  "$(cat "$ARCHITECTURE_MD" 2>/dev/null)"

echo
echo "T24 AC10 -- eval scorer dimension 5 scores non-null against the committed fixture"
t24_ac10_case() {
  local scratch
  scratch="$(mktemp -d "${TMP}/edm-t24-ac10.XXXXXX")" || { fail "T24 AC10 -- mktemp failed"; return 1; }
  cp -R "${CODE_AUDIT_FIXTURE_DIR}/." "$scratch/"
  local d5
  d5="$(bash "${PLUGIN_DIR}/evals/score-artifacts.sh" "$scratch" 2>/dev/null | jq -e '.dimensions[4].score != null' 2>/dev/null)"
  [[ "$d5" == "true" ]] && pass "T24 AC10 -- score-artifacts.sh dimension 5 (lens-jsonl-prose-agreement) is non-null against the fixture" \
    || fail "T24 AC10 -- dimension 5 was null or the scorer failed against the fixture"
  rm -rf "$scratch"
}
t24_ac10_case
# EDMV3-T24 end

# =================================================================================
# EDMV3-T25: the synthesizer emits the authoritative JSONL ledger and ranks by
# confidence instead of discarding uncorroborated findings. The synthesizer is an LLM
# agent with no bin/ entry point to invoke directly, so every assertion here is either
# a prompt-text contract (grep/awk against the committed agent/skill prose) or a
# hand-constructed ledger fixture proving the JSONL shape's structural properties
# (AC1, AC3, AC10) -- consistent with the T24 block above.
# Batch scope note: this agent's remit for this batch is agents/edm-audit-
# synthesizer.md, skills/code-audit/SKILL.md, and this wave7-smoke.sh append block.
# One AC is explicitly out of scope for this batch and is NOT asserted here:
#   - AC4 (a legacy 'deferred' line re-opens at read time; `edm-state audit-converged`
#     exits non-zero naming it) is owned by EDMV3-T28 -- the ticket's own text says so
#     ("implemented in EDMV3-T28 and asserted here against the same fixture ledger"),
#     and `edm-state audit-converged` does not exist yet.
# AC8 (the eleven lens '## False Alarm Filter' sections get an identical framing
# sentence about demote-not-delete) was escalated from this batch's original file
# boundary and lands in a follow-up batch that edits agents/edm-audit-{logic,
# dead-code,edge-cases,test-quality,runtime,docs,consistency,security,spec,dry,
# wiring}.md directly; it is asserted below.
# =================================================================================
SYNTHESIZER_AGENT="${PLUGIN_DIR}/agents/edm-audit-synthesizer.md"
SYNTH_CONTENT="$(cat "$SYNTHESIZER_AGENT")"

echo
echo "T25 AC1 -- synthesizer names findings-ledger.jsonl as its authoritative ledger output"
check "T25 AC1 -- findings-ledger.jsonl named as the ledger output" "findings-ledger.jsonl" "$SYNTH_CONTENT"
check "T25 AC1 -- authoritative record language present" "authoritative" "$SYNTH_CONTENT"
check "T25 AC1 -- CA-NNN id format documented" "CA-001" "$SYNTH_CONTENT"
check "T25 AC1 -- confidence field documented" "confidence" "$SYNTH_CONTENT"
check "T25 AC1 -- lenses field documented" '"lenses"' "$SYNTH_CONTENT"

echo
echo "T25 AC1/AC3/AC10 -- hand-constructed ledger fixture: valid JSON, unique CA-NNN ids, confidence+lenses present, status enum exactly open|fixed|noted"
t25_ledger_case() {
  local scratch
  scratch="$(mktemp -d "${TMP}/edm-t25-ledger.XXXXXX")" || { fail "T25 AC1/AC10 -- mktemp failed"; return 1; }
  local ledger="$scratch/findings-ledger.jsonl"
  {
    echo '{"schema":1,"id":"CA-001","sev":"P1","status":"fixed","confidence":"high","lenses":["L1","L4"],"file":"src/auth/handler.py","line":42,"title":"Stub returns hardcoded data","raised_round":1,"resolved_round":2}'
    echo '{"schema":1,"id":"CA-002","sev":"P0","status":"open","confidence":"high","lenses":["L9"],"file":"(missing)","line":null,"title":"--dry-run flag not built","raised_round":1,"resolved_round":null}'
    echo '{"schema":1,"id":"CA-003","sev":"NOTED","status":"noted","confidence":"low","lenses":["L7"],"file":"svc-a/config.yaml","line":null,"title":"Timeout inconsistency","raised_round":2,"resolved_round":null}'
  } > "$ledger"

  local bad=0 t25_line
  while IFS= read -r t25_line; do
    [[ -z "$t25_line" ]] && continue
    echo "$t25_line" | jq -e . >/dev/null 2>&1 || bad=1
  done < "$ledger"
  [[ $bad -eq 0 ]] && pass "T25 AC10 -- every line of the ledger fixture is valid JSON" \
    || fail "T25 AC10 -- at least one ledger fixture line failed to parse"

  jq -se 'all(.id | test("^CA-[0-9]{3}$")) and all(has("confidence") and has("lenses"))' "$ledger" >/dev/null 2>&1 \
    && pass "T25 AC1 -- every line carries a CA-NNN id plus confidence and lenses fields" \
    || fail "T25 AC1 -- ledger fixture failed the id/confidence/lenses jq assertion"

  jq -se '(map(.id) | length) == (map(.id) | unique | length)' "$ledger" >/dev/null 2>&1 \
    && pass "T25 AC10 -- ledger fixture IDs are unique" \
    || fail "T25 AC10 -- ledger fixture IDs are not unique"

  jq -se 'all(.status == "open" or .status == "fixed" or .status == "noted")' "$ledger" >/dev/null 2>&1 \
    && pass "T25 AC3 -- ledger fixture status values are exactly open|fixed|noted" \
    || fail "T25 AC3 -- ledger fixture contains a status value outside open|fixed|noted"

  rm -rf "$scratch"
}
t25_ledger_case

echo
echo "T25 AC2 -- synthesizer does not write findings-ledger.md; every mention is a legacy-read reference or an explicit forbid"
t25_ac2_case() {
  local bad=0 line
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    case "$line" in
      *legacy*) ;;
      *"not write"*|*"Not write"*|*"never write"*|*"Never write"*|*"contract violation"*) ;;
      *) bad=1; echo "  UNQUALIFIED MENTION: $line" ;;
    esac
  done < <(grep -n 'findings-ledger.md' "$SYNTHESIZER_AGENT")
  [[ $bad -eq 0 ]] && pass "T25 AC2 -- every findings-ledger.md mention is a legacy-read reference or an explicit forbid" \
    || fail "T25 AC2 -- found an unqualified findings-ledger.md mention (see above)"
}
t25_ac2_case
t25_output_section="$(awk '/^## Output$/{f=1} f && /^## Second-Pass/{exit} f' "$SYNTHESIZER_AGENT")"
t25_output_bullets="$(printf '%s\n' "$t25_output_section" | grep -c '^- `' || true)"
[[ "${t25_output_bullets:-0}" -eq 2 ]] && pass "T25 AC2 -- Output section names exactly two permitted write paths" \
  || fail "T25 AC2 -- Output section has ${t25_output_bullets:-0} write-path bullet(s), expected 2"
check_absent "T25 AC2 -- Output section's write paths do not include a bare findings-ledger.md bullet" \
  '- `<initiative-dir>/code-audit/findings-ledger.md`' "$t25_output_section"

echo
echo "T25 AC3 -- deferred abolished from the synthesizer prompt; status enum is exactly open|fixed|noted"
t25_defer_count="$(grep -ci 'defer' "$SYNTHESIZER_AGENT" || true)"
[[ "${t25_defer_count:-0}" -eq 0 ]] && pass "T25 AC3 -- zero case-insensitive 'defer' occurrences in the synthesizer prompt" \
  || fail "T25 AC3 -- found ${t25_defer_count} 'defer' occurrence(s) in the synthesizer prompt"
check "T25 AC3 -- status enum stated as open, fixed, noted" 'open`, `fixed`, `noted' "$SYNTH_CONTENT"

echo
echo "T25 AC5 -- cross-round semantics preserved: fixed/resolved_round/raised_round/re-open language present"
check "T25 AC5 -- resolved_round tracked" "resolved_round" "$SYNTH_CONTENT"
check "T25 AC5 -- re-open language present" "re-open" "$SYNTH_CONTENT"
check "T25 AC5 -- raised_round tracked" "raised_round" "$SYNTH_CONTENT"

echo
echo "T25 AC6 -- blind corroboration discard phrase absent from the synthesizer prompt"
check_absent "T25 AC6 -- 'low corroboration' (the old blind-discard phrase) is absent" \
  "low corroboration" "$SYNTH_CONTENT"
check "T25 AC6 -- confidence-ranking rule present (low confidence retained but demoted)" \
  "confidence: low" "$SYNTH_CONTENT"
check "T25 AC6 -- demotion language present, not discard" "is retained but demoted" "$SYNTH_CONTENT"

echo
echo "T25 AC7 -- synthesizer prompt states no finding is removed"
check "T25 AC7 -- 'No finding is ever removed' stated" "No finding is ever removed" "$SYNTH_CONTENT"
check "T25 AC7 -- substantive false-alarm criteria (documented trade-off) preserved" \
  "known trade-off explicitly accepted" "$SYNTH_CONTENT"

echo
echo "T25 AC8 -- all eleven lens agents carry an identical False Alarm Filter framing sentence, no criterion removed"
t25_ac8_framing="Report every finding at your best-effort confidence level rather than self-suppressing on uncertainty: this filter demotes a finding to \`## Noted / Not Actionable\` with a documented rationale and never deletes it outright, and ranking by confidence and cross-lens corroboration is the synthesizer's job, not this lens's."
t25_ac8_case() {
  local lens_files="edm-audit-logic.md edm-audit-dead-code.md edm-audit-edge-cases.md edm-audit-test-quality.md edm-audit-runtime.md edm-audit-docs.md edm-audit-consistency.md edm-audit-security.md edm-audit-spec.md edm-audit-dry.md edm-audit-wiring.md"
  local count=0 f
  for f in $lens_files; do
    grep -qF "$t25_ac8_framing" "${PLUGIN_DIR}/agents/${f}" && count=$((count+1)) \
      || echo "  MISSING framing sentence in ${f}"
  done
  [[ "$count" -eq 11 ]] && pass "T25 AC8 -- eleven occurrences of the framing sentence" \
    || fail "T25 AC8 -- found framing sentence in only ${count}/11 lens agent files"
}
t25_ac8_case

echo
echo "T25 AC9 -- legacy markdown-only prior ledger is read without error (C-4)"
check "T25 AC9 -- Mission bullet documents legacy findings-ledger.md fallback" \
  "legacy \`<initiative-dir>/code-audit/findings-ledger.md\` if only that exists" "$SYNTH_CONTENT"
check "T25 AC9 -- Process step documents legacy findings-ledger.md fallback" \
  "If only a legacy \`findings-ledger.md\` exists, read that instead" "$SYNTH_CONTENT"

echo
echo "T25 -- skills/code-audit/SKILL.md's synthesizer launch reflects the JSONL-authoritative contract"
CA_CONTENT_T25="$(cat "${PLUGIN_DIR}/skills/code-audit/SKILL.md")"
check "T25 -- SKILL.md Step 9 writes findings-ledger.jsonl as the authoritative record" \
  "the authoritative record" "$CA_CONTENT_T25"
check "T25 -- SKILL.md Step 9 states the synthesizer does not write findings-ledger.md" \
  "does not write \`findings-ledger.md\`" "$CA_CONTENT_T25"
check "T25 -- SKILL.md Synthesizer Phase launch prompt reads findings-ledger.jsonl with legacy fallback" \
  "findings-ledger.jsonl (or the legacy" "$CA_CONTENT_T25"
check "T25 -- SKILL.md Synthesizer Phase launch prompt forbids writing findings-ledger.md" \
  "Do not write findings-ledger.md yourself" "$CA_CONTENT_T25"
# EDMV3-T25 end
# ---- EDMV3-T30/T31: bin/edm-check-vocabulary and the implement/QC PARTIAL-lifecycle sweep -----
echo
echo "=== EDMV3-T30/T31: no-deferral-vocabulary checker and PARTIAL-lifecycle sweep ==="
CHECK_VOCAB="${PLUGIN_DIR}/bin/edm-check-vocabulary"
VOCAB_PROHIBITED="${PLUGIN_DIR}/bin/vocabulary-prohibited.txt"
VOCAB_ALLOWLIST="${PLUGIN_DIR}/bin/vocabulary-allowlist.txt"

echo "T30 AC1 -- --list-scope prints all eight scan roots"
t30_scope="$(bash "$CHECK_VOCAB" --list-scope 2>&1)"
for t30_root in "plugins/edm/skills" "plugins/edm/agents" "plugins/edm/docs" \
                "plugins/edm/hooks/hooks.json" "plugins/edm/monitors/monitors.json" \
                "plugins/edm/CLAUDE.md" "plugins/edm/README.md" "plugins/edm/bin"; do
  check "T30 AC1 -- --list-scope includes ${t30_root}" "$t30_root" "$t30_scope"
done

echo
echo "T30 AC6 -- usage/environment error exits 2 on an unrecognized flag"
t30_bogus_status=0
bash "$CHECK_VOCAB" --bogus >/dev/null 2>&1 || t30_bogus_status=$?
[[ "$t30_bogus_status" -eq 2 ]] && pass "T30 AC6 -- --bogus exits 2" \
  || fail "T30 AC6 -- --bogus exited $t30_bogus_status, expected 2"

echo
echo "T30 AC3 -- prohibited-token list is data (>= 7 non-blank lines), not an inline list in the script"
t30_prohibited_count="$(grep -c . "$VOCAB_PROHIBITED" 2>/dev/null || echo 0)"
[[ "$t30_prohibited_count" -ge 7 ]] && pass "T30 AC3 -- vocabulary-prohibited.txt has >= 7 non-blank lines ($t30_prohibited_count)" \
  || fail "T30 AC3 -- vocabulary-prohibited.txt has only $t30_prohibited_count non-blank lines"
check_absent "T30 AC3 -- edm-check-vocabulary has no literal abolished-word token" "defer" \
  "$(tr '[:upper:]' '[:lower:]' < "$CHECK_VOCAB")"
check "T30 AC3 -- word: mode present" "word:defer" "$(cat "$VOCAB_PROHIBITED")"
check "T30 AC3 -- literal: mode present" "literal:--force" "$(cat "$VOCAB_PROHIBITED")"

echo
echo "T30 AC4 -- allowlist documents each justified class with a one-line comment"
VOCAB_ALLOWLIST_TXT="$(cat "$VOCAB_ALLOWLIST")"
check "T30 AC4 -- CLAUDE.md NOTED-vs-deferral class" "NOTED-versus-deferral clarification in CLAUDE.md" "$VOCAB_ALLOWLIST_TXT"
check "T30 AC4 -- checker's own prohibited-list class" "vocabulary-prohibited.txt|" "$VOCAB_ALLOWLIST_TXT"
check "T30 AC4 -- checker's own allowlist-file class" "vocabulary-allowlist.txt|" "$VOCAB_ALLOWLIST_TXT"
check "T30 AC4 -- CHANGELOG.md history class" "plugins/edm/CHANGELOG.md|" "$VOCAB_ALLOWLIST_TXT"
check "T30 AC4 -- bin/tests/ negative-test carve-out class" "plugins/edm/bin/tests/|" "$VOCAB_ALLOWLIST_TXT"
check "T30 AC4 -- edm-audit-spec.md False-Alarm-Filter class" "plugins/edm/agents/edm-audit-spec.md|" "$VOCAB_ALLOWLIST_TXT"

echo
echo "T30 AC9 -- sources shared lint library rather than re-deriving the file walk"
check "T30 AC9 -- sources _edm-lint-lib.sh" "_edm-lint-lib.sh" "$(cat "$CHECK_VOCAB")"
# CA-156: edm-check-vocabulary no longer calls build_line_classes directly -- it calls the
# shared ignored_line_set (also from _edm-lint-lib.sh) instead of carrying its own local
# byte-identical copy of that one-line wrapper. Asserting the wrapper's own name is used, not
# the lower-level function it wraps, is the correct post-CA-156 shape of this AC.
check "T30 AC9 -- uses ignored_line_set from shared lib" "ignored_line_set" "$(cat "$CHECK_VOCAB")"
check_absent "T30 AC9 -- does not redefine ignored_line_set locally" "ignored_line_set() {" "$(cat "$CHECK_VOCAB")"

echo
echo "T30 AC10 -- override-flag grep (repo-wide, documented carve-outs) is clean"
t30_force_pattern='--force'
t30_accept_pattern='--accept-partials'
t30_override_hits="$(grep -rn -- "${t30_force_pattern}\|${t30_accept_pattern}" "${PLUGIN_DIR}/bin" "${PLUGIN_DIR}/skills" "${PLUGIN_DIR}/agents" 2>/dev/null \
  | grep -v "${PLUGIN_DIR}/bin/tests/" | grep -v vocabulary- | grep -v 'refused:' || true)"
# G20 (round-3): same repo-wide escape-hatch scan as T66 AC12 above -- routed through
# assert_tree_absent per needle (G2/CA-037 + G13/CA-145, round 4): genuinely seeded scratch
# controls, and the three scanned directories are asserted to exist before the needle check runs.
# G2/CA-037 residual (round 5): see T66 AC12's comment above -- same one-variable-per-pattern
# fix, and each control now passes through the same filter chain the real scan applies.
t30_force_control="${TMP}/edm-t30-force-control.txt"
printf -- '--force\n' | grep -v "${PLUGIN_DIR}/bin/tests/" | grep -v vocabulary- | grep -v 'refused:' > "$t30_force_control"
assert_tree_absent "T30 AC10 -- no stray --force outside bin/tests/ and the vocabulary checker's own files" \
  "$t30_force_pattern" "$t30_override_hits" "$(cat "$t30_force_control")" \
  "${PLUGIN_DIR}/bin" "${PLUGIN_DIR}/skills" "${PLUGIN_DIR}/agents"
t30_accept_control="${TMP}/edm-t30-accept-control.txt"
printf -- '--accept-partials\n' | grep -v "${PLUGIN_DIR}/bin/tests/" | grep -v vocabulary- | grep -v 'refused:' > "$t30_accept_control"
assert_tree_absent "T30 AC10 -- no stray --accept-partials outside bin/tests/ and the vocabulary checker's own files" \
  "$t30_accept_pattern" "$t30_override_hits" "$(cat "$t30_accept_control")" \
  "${PLUGIN_DIR}/bin" "${PLUGIN_DIR}/skills" "${PLUGIN_DIR}/agents"
rm -f "$t30_force_control" "$t30_accept_control"

echo
echo "T30 AC11 -- bash 3.2 syntax check and CI wiring"
bash -n "$CHECK_VOCAB" && pass "T30 AC11 -- bash -n edm-check-vocabulary" || fail "T30 AC11 -- bash -n edm-check-vocabulary failed"
check "T30 AC11 -- edm-check-vocabulary wired into .gitlab-ci.yml lint stage" "edm-check-vocabulary" \
  "$(cat "$GITLAB_CI_YML" 2>/dev/null)"

echo
echo "T30 AC2 -- JSON-escaped prompt strings: a scratch hooks.json carrying the abolished token is caught"
t30_ac2_case() {
  local scratch
  scratch="$(mktemp -d "${TMP}/edm-t30-ac2.XXXXXX")" || { fail "T30 AC2 -- mktemp failed"; return 1; }
  mkdir -p "$scratch/plugins/edm"
  cp -R "${PLUGIN_DIR}/." "$scratch/plugins/edm/"
  # Reinsert the abolished token into the scratch copy's hooks.json prompt text only
  # (sed -i.bak: GNU and BSD/macOS sed both accept an attached, no-space backup suffix).
  sed -i.bak 's/runtime-check: note/deferred-to-runtime note/' "$scratch/plugins/edm/hooks/hooks.json"
  rm -f "$scratch/plugins/edm/hooks/hooks.json.bak"
  local out status
  out="$(bash "$scratch/plugins/edm/bin/edm-check-vocabulary" 2>&1)" || status=$?
  status="${status:-0}"
  if [[ "$status" -eq 1 ]] && [[ "$out" == *"hooks/hooks.json"* ]]; then
    pass "T30 AC2 -- reinserted token in a scratch hooks.json is caught, naming hooks/hooks.json"
  else
    fail "T30 AC2 -- expected exit 1 naming hooks/hooks.json, got exit=$status output: $out"
  fi
  rm -rf "$scratch"
}
t30_ac2_case
# EDMV3-T30 end

# ---- EDMV3-T31: implement/QC PARTIAL-lifecycle sweep, verified against the checker ------------
echo
echo "T30 AC12/T31 -- the checker's remaining violations, if any, are outside this ticket pair's file boundary"
t30_scan_out="$(bash "$CHECK_VOCAB" 2>&1 || true)"
check_absent "T31 -- skills/implement/SKILL.md carries no checker violation" "skills/implement/SKILL.md:" "$t30_scan_out"
check_absent "T31 -- agents/edm-qc-auditor.md carries no checker violation" "agents/edm-qc-auditor.md:" "$t30_scan_out"
check_absent "T31 -- hooks/hooks.json carries no checker violation" "hooks/hooks.json:" "$t30_scan_out"
check_absent "T30 -- CLAUDE.md carries no checker violation (its NOTED-clarification is allowlisted)" "plugins/edm/CLAUDE.md:" "$t30_scan_out"

echo
echo "T31 AC1/AC2/AC3 -- skills/implement/SKILL.md: every-severity FAIL compilation, PARTIAL lifecycle rewritten"
IMPL_SKILL="$(cat "${PLUGIN_DIR}/skills/implement/SKILL.md")"
check_absent "T31 AC1 -- no severity-filtered FAIL compilation" "P0/P1 FAIL" "$IMPL_SKILL"
check "T31 AC1 -- FAIL compilation is at every severity" "at every severity" "$IMPL_SKILL"
check_absent "T31 AC2 -- abolished 'do not require remediation' sentence is gone" "do not require remediation" "$IMPL_SKILL"
check "T31 AC2 -- PARTIAL closure via mandatory verify-runtime" "mandatory \`/edm:verify-runtime\` step" "$IMPL_SKILL"
check "T31 AC3 -- Declare Done requires verify-runtime" "Every outstanding PARTIAL closed via \`/edm:verify-runtime\`" "$IMPL_SKILL"
check_absent "T31 AC4 -- no residual deferred-to-runtime token" "deferred-to-runtime" "$IMPL_SKILL"
check "T31 AC5 -- Out of Scope (recorded boundaries) section" "## Out of Scope (recorded boundaries)" "$IMPL_SKILL"
check "T31 AC6 -- Runtime-check note exec-report column" "Runtime-check note" "$IMPL_SKILL"

echo
echo "T31 AC7/AC8 -- agents/edm-qc-auditor.md: PARTIAL semantics preserved, abolished sentence rewritten"
QC_AUDITOR="$(cat "${PLUGIN_DIR}/agents/edm-qc-auditor.md")"
check "T31 AC7 -- Never invent a PASS survives verbatim" "Never invent a PASS for something you cannot verify" "$QC_AUDITOR"
check_absent "T31 AC7 -- no residual deferred-to-runtime token" "deferred-to-runtime" "$QC_AUDITOR"
check "T31 AC8 -- abolished PARTIAL-remediation sentence rewritten to name verify-runtime closure" \
  "closed by the mandatory \`/edm:verify-runtime\` step" "$QC_AUDITOR"

echo
echo "T31 AC11 -- hooks/hooks.json: runtime-check token, still valid JSON"
jq -e . "${PLUGIN_DIR}/hooks/hooks.json" >/dev/null 2>&1 \
  && pass "T31 AC11 -- hooks.json is valid JSON" || fail "T31 AC11 -- hooks.json failed to parse"
t31_hooks_defer_count="$(jq -r '.. | strings' "${PLUGIN_DIR}/hooks/hooks.json" 2>/dev/null | grep -c 'deferred-to-runtime' || true)"
[[ "${t31_hooks_defer_count:-0}" -eq 0 ]] && pass "T31 AC11 -- no deferred-to-runtime string inside any hooks.json JSON value" \
  || fail "T31 AC11 -- hooks.json still contains deferred-to-runtime in a JSON string value"
check "T31 AC11 -- hooks.json prompt uses runtime-check token" "runtime-check:" "$(cat "${PLUGIN_DIR}/hooks/hooks.json")"
# EDMV3-T31 end

# =================================================================================
# EDMV3-T40: canonical Mermaid diagram conventions section in plugins/edm/CLAUDE.md.
# =================================================================================
CLAUDE_MD_CONTENT="$(cat "${PLUGIN_DIR}/CLAUDE.md")"

echo
echo "T40 AC1 -- canonical Mermaid heading string, placed between Severity vocabulary and Model/effort"
t40_heading_order="$({ grep -n '^## ' "${PLUGIN_DIR}/CLAUDE.md" || true; } | grep -A2 'Severity vocabulary')"
check "T40 AC1 -- canonical Mermaid heading string present" \
  "## Mermaid diagram conventions (canonical)" "$CLAUDE_MD_CONTENT"
[[ "$(printf '%s\n' "$t40_heading_order" | sed -n '2p')" == *'Mermaid diagram conventions (canonical)'* ]] \
  && pass "T40 AC1 -- Mermaid section immediately follows Severity vocabulary" \
  || fail "T40 AC1 -- Mermaid section is not immediately after Severity vocabulary (got: $t40_heading_order)"

echo
echo "T40 AC2 -- register matches the Severity vocabulary precedent"
check "T40 AC2 -- 'No agent may define a divergent local rule' present" \
  "No agent may define a divergent local rule" "$CLAUDE_MD_CONTENT"

echo
echo "T40 AC3 -- problem stated: ';' is a lexer-level statement separator"
check "T40 AC3 -- 'statement separator' present" "statement separator" "$CLAUDE_MD_CONTENT"

echo
echo "T40 AC4 -- rule stated, both entity forms (base-10 code point and entity name)"
check "T40 AC4 -- '#59;' present" '#59;' "$CLAUDE_MD_CONTENT"
check "T40 AC4 -- 'entity name' present" "entity name" "$CLAUDE_MD_CONTENT"

echo
echo "T40 AC5 -- worked examples: at least one incorrect and one correct, both fenced"
t40_ac5_fence_count="$(sed -n '/Mermaid diagram conventions/,/^## /p' "${PLUGIN_DIR}/CLAUDE.md" | grep -c '```' || true)"
[[ "${t40_ac5_fence_count:-0}" -ge 2 ]] \
  && pass "T40 AC5 -- at least two fenced code blocks in the Mermaid section (found ${t40_ac5_fence_count})" \
  || fail "T40 AC5 -- fewer than two fenced blocks in the Mermaid section (found ${t40_ac5_fence_count:-0})"

echo
echo "T40 AC6 -- quoting caveat names sequenceDiagram's unquoted message text"
check "T40 AC6 -- 'sequenceDiagram' present" "sequenceDiagram" "$CLAUDE_MD_CONTENT"

echo
echo "T40 AC7 -- legal exceptions enumerated (end-of-line, %% comment, classDef/style/linkStyle)"
check "T40 AC7 -- 'classDef' exception present" "classDef" "$CLAUDE_MD_CONTENT"
check "T40 AC7 -- 'linkStyle' exception present" "linkStyle" "$CLAUDE_MD_CONTENT"
check "T40 AC7 -- '%%' comment-line exception present" '%%' "$CLAUDE_MD_CONTENT"

echo
echo "T40 AC8 -- generalization to other entity codes"
check "T40 AC8 -- '#quot;' present" '#quot;' "$CLAUDE_MD_CONTENT"

echo
echo "T40 AC9 -- Mermaid section content is ASCII-only"
# Uses the portable [:print:]/[:space:] fallback (bin/edm-lint-artifacts's own PCRE-unavailable
# path, EDMV3-T43/EDMV3-106) rather than a raw '[^\x00-\x7F]' class -- BSD grep on macOS has no -P
# and treats '\x00'/'\x7F' as literal characters, not hex escapes, which would false-positive on
# nearly every line.
t40_ac9_nonascii="$(LC_ALL=C sed -n '/Mermaid diagram conventions/,/^## Model and effort/p' "${PLUGIN_DIR}/CLAUDE.md" | LC_ALL=C grep -nv '^[[:print:][:space:]]*$' || true)"
[[ -z "$t40_ac9_nonascii" ]] \
  && pass "T40 AC9 -- Mermaid section is ASCII-only" \
  || fail "T40 AC9 -- non-ASCII byte(s) found in the Mermaid section: $t40_ac9_nonascii"

echo
echo "T40 AC10 -- canonical Mermaid heading string, and architecture.md uses the same name"
check "T40 AC10 -- architecture.md references the same heading string" \
  "Mermaid diagram conventions" "$(cat "$ARCHITECTURE_MD" 2>/dev/null)"
# EDMV3-T40 end

# =================================================================================
# EDMV3-T42: eleven Mermaid touch points carry a by-name reference (nine prompt-surface
# files) or a pattern-library ### entry (two docs), and rule presence is asserted.
# =================================================================================
MERMAID_REF='Mermaid diagram conventions'
MERMAID_QUOTED='CLAUDE.md Sec."Mermaid diagram conventions"'

echo
echo "T42 AC1 -- three authoring agents reference the section"
for _t42_f in edm-architect.md edm-srd-writer.md edm-ticket-writer.md; do
  _t42_c="$(grep -c "$MERMAID_REF" "${PLUGIN_DIR}/agents/${_t42_f}" || true)"
  [[ "${_t42_c:-0}" -gt 0 ]] \
    && pass "T42 AC1 -- agents/${_t42_f} references the Mermaid section" \
    || fail "T42 AC1 -- agents/${_t42_f} has no Mermaid section reference"
done

echo
echo "T42 AC2 -- two auditing agents reference the section and add an explicit literal-; check"
check "T42 AC2 -- edm-srd-auditor.md states the literal-semicolon check" \
  "literal semicolon" "$(cat "${PLUGIN_DIR}/agents/edm-srd-auditor.md")"
check "T42 AC2 -- edm-ticket-auditor.md states the raw-; check" \
  'raw `;`' "$(cat "${PLUGIN_DIR}/agents/edm-ticket-auditor.md")"
for _t42_f in edm-srd-auditor.md edm-ticket-auditor.md; do
  _t42_c="$(grep -c "$MERMAID_REF" "${PLUGIN_DIR}/agents/${_t42_f}" || true)"
  [[ "${_t42_c:-0}" -gt 0 ]] \
    && pass "T42 AC2 -- agents/${_t42_f} references the Mermaid section" \
    || fail "T42 AC2 -- agents/${_t42_f} has no Mermaid section reference"
done

echo
echo "T42 AC3 -- four skills reference the section"
t42_ac3_missing=""
for _t42_s in srd tickets audit-srd audit-tickets; do
  grep -q "$MERMAID_REF" "${PLUGIN_DIR}/skills/${_t42_s}/SKILL.md" \
    || t42_ac3_missing="${t42_ac3_missing} ${_t42_s}"
done
[[ -z "$t42_ac3_missing" ]] \
  && pass "T42 AC3 -- all four skills (srd, tickets, audit-srd, audit-tickets) reference the section" \
  || fail "T42 AC3 -- missing skill(s):${t42_ac3_missing}"

echo
echo "T42 AC4 -- identical quoting style across every by-name reference"
# CA-035: the prior pattern was single-quoted with a literal '\\"*"*', which (BRE, no -E) requires
# an actual backslash before Sec. and before "conventions" -- only the one deliberately-escaped
# line at skills/srd/SKILL.md matched, so sort -u | wc -l was always 1 and the assertion was blind
# to the other 20 references. The widened pattern below matches the reference family itself
# (backslash before the quote optional), so a real divergence in quoting style is now visible; the
# raw-count floor distinguishes "matched nothing" and "matched only one file" from "one true form".
t42_ac4_forms="$(grep -rhoE 'CLAUDE\.md Sec\.\\?"?Mermaid diagram conventions\\?"?' "${PLUGIN_DIR}/" 2>/dev/null | sort -u | wc -l | tr -d ' ')"
t42_ac4_raw="$(grep -rhcE 'CLAUDE\.md Sec\.\\?"?Mermaid diagram conventions' "${PLUGIN_DIR}/" 2>/dev/null | awk '{s+=$1} END{print s+0}')"
[[ "$t42_ac4_forms" == "1" && "$t42_ac4_raw" -ge 11 ]] \
  && pass "T42 AC4 -- exactly one quoting form of the by-name reference is in use (${t42_ac4_raw} references)" \
  || fail "T42 AC4 -- found ${t42_ac4_forms} distinct quoting forms across ${t42_ac4_raw} references, expected 1 form across >= 11"

echo
echo "T42 AC5 -- no touch point restates the rule content (the nine prompt-surface files)"
t42_ac5_restated=""
for _t42_f in agents/edm-architect.md agents/edm-srd-writer.md agents/edm-ticket-writer.md \
              agents/edm-srd-auditor.md agents/edm-ticket-auditor.md \
              skills/srd/SKILL.md skills/tickets/SKILL.md skills/audit-srd/SKILL.md skills/audit-tickets/SKILL.md; do
  grep -q '#59' "${PLUGIN_DIR}/${_t42_f}" && t42_ac5_restated="${t42_ac5_restated} ${_t42_f}"
done
[[ -z "$t42_ac5_restated" ]] \
  && pass "T42 AC5 -- none of the nine prompt-surface touch points restate the #59; entity code" \
  || fail "T42 AC5 -- rule restated in:${t42_ac5_restated}"

echo
echo "T42 AC6 -- concrete audit check text names sequenceDiagram message semicolons"
check "T42 AC6 -- edm-ticket-auditor.md names sequenceDiagram message text after ':'" \
  "sequenceDiagram message" "$(cat "${PLUGIN_DIR}/agents/edm-ticket-auditor.md")"

echo
echo "T42 AC7/AC8 -- pattern-library entries are ### under the existing ## Anti-Patterns, four-## contract intact"
[[ -n "$(grep -n '^### ' "${PLUGIN_DIR}/docs/audit-patterns/srd-audit.md" | grep -i mermaid || true)" ]] \
  && pass "T42 AC7 -- srd-audit.md has a Mermaid ### entry" \
  || fail "T42 AC7 -- srd-audit.md has no Mermaid ### entry"
[[ -n "$(grep -n '^### ' "${PLUGIN_DIR}/docs/audit-patterns/ticket-audit.md" | grep -i mermaid || true)" ]] \
  && pass "T42 AC7 -- ticket-audit.md has a Mermaid ### entry" \
  || fail "T42 AC7 -- ticket-audit.md has no Mermaid ### entry"

t42_srd_hh_count="$(count_matches '^## ' "${PLUGIN_DIR}/docs/audit-patterns/srd-audit.md")"
t42_tkt_hh_count="$(count_matches '^## ' "${PLUGIN_DIR}/docs/audit-patterns/ticket-audit.md")"
[[ "$t42_srd_hh_count" -eq 4 && "$t42_tkt_hh_count" -eq 4 ]] \
  && pass "T42 AC8 -- both pattern docs still have exactly four ## headings (no new ## added)" \
  || fail "T42 AC8 -- srd-audit.md has ${t42_srd_hh_count} ## headings, ticket-audit.md has ${t42_tkt_hh_count} (expected 4 each)"

echo
echo "T42 AC9 -- new entry titles are de-duplication-safe and ASCII-only"
t42_ac9_case() {
  local before_hash after_hash out
  before_hash="$(_harness_hash_file "${PLUGIN_DIR}/docs/audit-patterns/srd-audit.md")"

  edm-init ZMER >/dev/null 2>&1
  {
    echo "# Mock SRD Audit"
    echo
    echo "### literal semicolon inside a mermaid label"
    echo "Duplicate-titled finding to prove de-duplication skips it."
  } > "SRD/ZMER/audit-srd.md"

  out="$(edm-state update-patterns ZMER srd 2>&1)"
  after_hash="$(_harness_hash_file "${PLUGIN_DIR}/docs/audit-patterns/srd-audit.md")"

  [[ "$out" == *"no novel findings to append"* ]] \
    && pass "T42 AC9 -- update-patterns recognizes the normalized-duplicate title and appends nothing" \
    || fail "T42 AC9 -- update-patterns did not report 'no novel findings to append' (got: $out)"

  [[ "$before_hash" == "$after_hash" ]] \
    && pass "T42 AC9 -- docs/audit-patterns/srd-audit.md is byte-unchanged after the de-dup run" \
    || fail "T42 AC9 -- docs/audit-patterns/srd-audit.md changed hash (before=$before_hash after=$after_hash)"
}
with_scratch_repo t42_ac9_case

t42_ac9_nonascii_srd="$(LC_ALL=C grep -nv '^[[:print:][:space:]]*$' "${PLUGIN_DIR}/docs/audit-patterns/srd-audit.md" || true)"
t42_ac9_nonascii_tkt="$(LC_ALL=C grep -nv '^[[:print:][:space:]]*$' "${PLUGIN_DIR}/docs/audit-patterns/ticket-audit.md" || true)"
[[ -z "$t42_ac9_nonascii_srd" && -z "$t42_ac9_nonascii_tkt" ]] \
  && pass "T42 AC9 -- srd-audit.md and ticket-audit.md are ASCII-only" \
  || fail "T42 AC9 -- non-ASCII byte(s) found (srd: $t42_ac9_nonascii_srd | ticket: $t42_ac9_nonascii_tkt)"

echo
echo "T42 AC10 -- rule-presence smoke: canonical heading plus all eleven touch points"
check "T42 AC10 -- CLAUDE.md carries the canonical heading" \
  "## Mermaid diagram conventions (canonical)" "$CLAUDE_MD_CONTENT"
t42_ac10_missing=""
for _t42_f in agents/edm-architect.md agents/edm-srd-writer.md agents/edm-ticket-writer.md \
              agents/edm-srd-auditor.md agents/edm-ticket-auditor.md \
              skills/srd/SKILL.md skills/tickets/SKILL.md skills/audit-srd/SKILL.md skills/audit-tickets/SKILL.md \
              docs/audit-patterns/srd-audit.md docs/audit-patterns/ticket-audit.md; do
  grep -qi "$MERMAID_REF" "${PLUGIN_DIR}/${_t42_f}" 2>/dev/null || t42_ac10_missing="${t42_ac10_missing} ${_t42_f}"
done
[[ -z "$t42_ac10_missing" ]] \
  && pass "T42 AC10 -- all eleven touch points carry the reference or pattern-library entry" \
  || fail "T42 AC10 -- missing touch point(s):${t42_ac10_missing}"
check "T42 AC10 -- CLAUDE.md's correct example uses the #59; entity code" \
  '#59;' "$CLAUDE_MD_CONTENT"

echo
echo "T42 AC11 -- orchestrator carries none of the skill-side references (post-WS5 file set)"
t42_ac11_orch_count="$(grep -c "$MERMAID_REF" "${PLUGIN_DIR}/skills/orchestrator/SKILL.md" || true)"
[[ "${t42_ac11_orch_count:-0}" -eq 0 ]] \
  && pass "T42 AC11 -- orchestrator SKILL.md carries zero Mermaid section references" \
  || fail "T42 AC11 -- orchestrator SKILL.md unexpectedly references the Mermaid section (count=${t42_ac11_orch_count})"

echo
echo "T42 AC12 -- rule-presence test runs in CI"
# .gitlab-ci.yml never names wave7-smoke.sh literally -- test:smoke's script is the run-all.sh
# aggregator invocation, which auto-discovers every bin/tests/*-smoke.sh suite (EDMV3-T20 AC3),
# so wave7-smoke.sh (and this T42 case) runs in CI without needing its own pipeline line.
check "T42 AC12 -- .gitlab-ci.yml's test:smoke job runs the run-all.sh aggregator" \
  "bin/tests/run-all.sh" "$(cat "$GITLAB_CI_YML" 2>/dev/null)"
# EDMV3-T42 end

# =================================================================================
# EDMV3-T43: edm-lint-artifacts gains the Mermaid violation class on a one-pass line
# classifier. This batch's own fixtures are self-contained (mktemp scratch files) --
# the committed bin/tests/fixtures/mermaid/{valid,invalid}/ corpus proving zero false
# positives at scale is EDMV3-T44's deliverable, asserted in that ticket's own block below.
# =================================================================================
LINT_BIN="${PLUGIN_DIR}/bin/edm-lint-artifacts"
T43_SCRATCH="$(mktemp -d "${TMP}/edm-t43-mermaid.XXXXXX")"
t43_write() { printf '%s\n' "$2" > "${T43_SCRATCH}/$1"; }

echo
echo "T43 AC1 -- one-pass classifier replaces the per-class helper"
# CA-010: the former check_absent here (asserting the string "build_ignore_set" was absent from
# edm-lint-artifacts) is retired. That symbol has never existed anywhere in this tree
# post-extraction, so a check for its absence never asserted anything real -- see this file's
# own CA-010 block above for the actual structural boundary assertion.
# build_line_classes is defined in the shared library and called from edm-lint-artifacts
LINT_LIB="${SCRIPT_DIR}/../_edm-lint-lib.sh"
t43_def_count="$(count_matches '^build_line_classes()' "$LINT_LIB")"
t43_call_count="$(count_matches '_table="\$(build_line_classes' "$LINT_BIN")"
[[ "$t43_def_count" -eq 1 && "$t43_call_count" -eq 1 ]] \
  && pass "T43 AC1 -- exactly one build_line_classes definition (in shared lib) and one call site" \
  || fail "T43 AC1 -- found ${t43_def_count} definition(s) and ${t43_call_count} call site(s), expected 1 each"

echo
echo "T43 AC2 -- mermaid line set excludes non-mermaid fences"
t43_write nonmermaid.md 'Header

```text
A[Wait; then retry] --> B[Done]
```
'
t43_write mermaid-control.md 'Header

```mermaid
A[Wait; then retry] --> B[Done]
```
'
check_fails "T43 AC2 -- (control) the same content in a mermaid fence DOES violate" "mermaid-semicolon" \
  bash "$LINT_BIN" --path "${T43_SCRATCH}/mermaid-control.md"
bash "$LINT_BIN" --path "${T43_SCRATCH}/nonmermaid.md" >/dev/null 2>&1 \
  && pass "T43 AC2 -- a raw ';' inside a non-mermaid (text) fence is never flagged" \
  || fail "T43 AC2 -- a non-mermaid fence was incorrectly flagged"

echo
echo "T43 AC3 -- malformed fences: unterminated and nested, no hang, no mis-crash"
t43_write unterminated.md 'Header

```mermaid
flowchart TD
    A[Ok] --> B[Done]
'
t43_start="$SECONDS"
t43_rc=0
t43_unterminated_out="$(bash "$LINT_BIN" --path "${T43_SCRATCH}/unterminated.md" 2>&1)" || t43_rc=$?
t43_elapsed=$((SECONDS - t43_start))
[[ "$t43_elapsed" -le 10 && "$t43_rc" -eq 1 ]] \
  && pass "T43 AC3 -- unterminated fence terminates promptly and exits 1 (took ${t43_elapsed}s)" \
  || fail "T43 AC3 -- unterminated fence took ${t43_elapsed}s or exited ${t43_rc} (expected <=10s, exit 1)"
check "T43 AC3 -- unterminated fence emits the dedicated violation class" "unterminated-fence" "$t43_unterminated_out"

t43_write nested.md 'Header

```mermaid
flowchart TD
    A[Ok] --> B[Done]
```stray
    C[Also ok] --> D[End]
```
'
t43_start="$SECONDS"
t43_rc=0
bash "$LINT_BIN" --path "${T43_SCRATCH}/nested.md" >/dev/null 2>&1 || t43_rc=$?
t43_elapsed=$((SECONDS - t43_start))
[[ "$t43_elapsed" -le 10 && "$t43_rc" -le 1 ]] \
  && pass "T43 AC3 -- nested-looking fence does not hang or crash (took ${t43_elapsed}s, exit ${t43_rc})" \
  || fail "T43 AC3 -- nested-looking fence took ${t43_elapsed}s or exited ${t43_rc} (expected <=10s, exit 0/1)"

t43_write four-backtick.md 'Header

````mermaid
flowchart TD
    A[Inner three-backtick example follows] --> B[Still in fence]
    ```text
    literal sample
    ```
    C[Wait; then retry] --> D[Done]
````
'
check_fails "T43 AC3 -- a four-backtick mermaid fence stays open across inner triple-backtick examples" "mermaid-semicolon" \
  bash "$LINT_BIN" --path "${T43_SCRATCH}/four-backtick.md"

echo
echo "T43 AC4 -- the class fires on a raw ';' inside a label span"
t43_write invalid1.md 'Header

```mermaid
flowchart TD
    A[Wait; then retry] --> B[Done]
    C[Entity boundary #abcdefghijk; still violates] --> D[Done]
    E[#; still violates] --> F[Done]
```
'
check_fails "T43 AC4 -- a raw ';' inside [...] is flagged as mermaid-semicolon" "mermaid-semicolon" \
  bash "$LINT_BIN" --path "${T43_SCRATCH}/invalid1.md"

# CA-101 (carried from code-audit round 1, closed here): the check_fails call above only proves
# the class fires SOMEWHERE in invalid1.md -- it would still pass if line 5's plain "Wait;" were
# the only line actually flagged and both entity-length boundary lines (6: an 11-character token,
# one past strip_entities' 1..10 walk ceiling; 7: "#;" with zero characters, one short of its
# floor) were silently mis-treated as legal entities and swallowed. Assert each boundary line is
# flagged BY LINE NUMBER, individually, so a regression in the walk's off-by-one bounds fails here
# specifically rather than staying invisible behind line 5's unrelated pass.
set +e
t43_boundary_out="$(bash "$LINT_BIN" --path "${T43_SCRATCH}/invalid1.md" 2>&1)"
set -e
check "T43 AC4 (CA-101) -- an 11-character entity-shaped token (over the 1..10 walk's ceiling) still violates, at its own line" \
  "invalid1.md:6: mermaid-semicolon" "$t43_boundary_out"
check "T43 AC4 (CA-101) -- a zero-character '#;' (under the 1..10 walk's floor) still violates, at its own line" \
  "invalid1.md:7: mermaid-semicolon" "$t43_boundary_out"
t43_boundary_count="$(printf '%s\n' "$t43_boundary_out" | grep -c 'mermaid-semicolon' || true)"
[[ "${t43_boundary_count:-0}" -eq 3 ]] \
  && pass "T43 AC4 (CA-101) -- exactly 3 violations in invalid1.md (line 5 plain + both boundary lines 6/7)" \
  || fail "T43 AC4 (CA-101) -- found ${t43_boundary_count} violation(s), expected 3"

echo
echo "T43 AC5 -- zero false positives on the legal cases"
{
  printf '%s\n' 'Header'
  printf '\n'
  printf '%s\n' '```mermaid'
  printf '%s\n' 'flowchart TD'
  printf '%s\n' '    A[Wait#59; then retry] --> B[Done]'
  printf '%s\n' '    A["ratio 3,4 (ok)"] --> C[End]'
  printf '%s\n' '    classDef done fill:#f9f,stroke:#333;'
  printf '%s\n' '    style A fill:#bbf,stroke:#333;'
  printf '%s\n' '    linkStyle 0 stroke:#333;'
  printf '%s\n' '    %% a comment; with a semicolon is fine'
  printf '%s\n' '    D[Quote#quot;here] --> E[Hash#35;here]'
  printf '%s\n' '```'
  printf '\n'
  printf '%s\n' '```mermaid'
  printf '%s\n' 'sequenceDiagram'
  printf '%s\n' '    Alice->>Bob: hello there, no problem'
  printf '%s\n' '```'
} > "${T43_SCRATCH}/valid1.md"
bash "$LINT_BIN" --path "${T43_SCRATCH}/valid1.md" >/dev/null 2>&1 \
  && pass "T43 AC5 -- entity codes, trailing ;, %% comments, classDef/style/linkStyle, and a clean sequenceDiagram all pass" \
  || fail "T43 AC5 -- a legal case was incorrectly flagged"

echo
echo "T43 AC6 -- the escape valve: block-form suppresses a fence; single-line on fence-open suppresses; single-line inside a fence is unsupported"
t43_write blockform.md 'Header

<!-- edm-lint-ignore-start -->
```mermaid
flowchart TD
    A[Wait; then retry] --> B[Done]
```
<!-- edm-lint-ignore-end -->
'
bash "$LINT_BIN" --path "${T43_SCRATCH}/blockform.md" >/dev/null 2>&1 \
  && pass "T43 AC6 -- block-form markers suppress a fence" \
  || fail "T43 AC6 -- block-form markers did not suppress the fence"

t43_write openline.md 'Header

```mermaid <!-- edm-lint-ignore -->
flowchart TD
    A[Wait; then retry] --> B[Done]
    C[Entity boundary #abcdefghijk; still violates] --> D[Done]
    E[#; still violates] --> F[Done]
```
'
bash "$LINT_BIN" --path "${T43_SCRATCH}/openline.md" >/dev/null 2>&1 \
  && pass "T43 AC6 -- single-line marker on the fence-open line suppresses the fence" \
  || fail "T43 AC6 -- single-line marker on the fence-open line did not suppress the fence"

t43_write insidefence.md 'Header

```mermaid
flowchart TD
    A[Ok] --> B[Done]
    <!-- edm-lint-ignore -->
    C[Also; bad] --> D[End]
```
'
check_fails "T43 AC6 -- single-line marker inside a fence produces the unsupported message" "unsupported" \
  bash "$LINT_BIN" --path "${T43_SCRATCH}/insidefence.md"

echo
echo "T43 AC7 -- output format and exit code unchanged"
set +e
t43_out="$(bash "$LINT_BIN" --path "${T43_SCRATCH}/invalid1.md" 2>&1)"
set -e
echo "$t43_out" | grep -Eq '^[^:]+:[0-9]+: mermaid-semicolon: ' \
  && pass "T43 AC7 -- output matches path:line: <class>: <snippet>" \
  || fail "T43 AC7 -- output did not match the expected format (got: $t43_out)"

echo
echo "T43 AC8 -- header block lists four classes"
t43_header="$(awk '/^# Violation classes/{f=1} f{print} /^# Output format/{exit}' "$LINT_BIN")"
check "T43 AC8 -- header names attribution" "attribution" "$t43_header"
check "T43 AC8 -- header names unicode" "unicode" "$t43_header"
check "T43 AC8 -- header names leaked-tool-tag" "leaked-tool-tag" "$t43_header"
check "T43 AC8 -- header names mermaid-semicolon" "mermaid-semicolon" "$t43_header"

echo
echo "T43 AC9 -- the three existing classes behave identically after the refactor"
# A true before/after diff was captured manually during implementation: `edm-lint-artifacts
# --all` output was byte-identical (both CLEAN, 0 violations) comparing the pre-refactor
# committed script (via `git stash`) against the post-refactor script. This ongoing assertion
# proves the CURRENT tree still produces zero attribution/unicode/leaked-tool-tag violations,
# i.e. the refactor has not regressed the three pre-existing classes against the live tree.
# CA-094: reuses the shared whole-tree capture (before T66 AC12) instead of a fresh --all run.
_wave7_assert_shared_lint_fresh "T43 AC9"
[[ "$WAVE7_ALL_LINT_EXIT" -eq 0 ]] || fail "T43 AC9 -- edm-lint-artifacts --all exited ${WAVE7_ALL_LINT_EXIT} (captured once): ${WAVE7_ALL_LINT_OUT}"
check "T43 AC9 -- --all is still CLEAN across the tree post-refactor" "CLEAN" "$WAVE7_ALL_LINT_OUT"
check_absent "T43 AC9 -- no attribution violation on the live tree" ": attribution: " "$WAVE7_ALL_LINT_OUT"
check_absent "T43 AC9 -- no unicode violation on the live tree" ": unicode: " "$WAVE7_ALL_LINT_OUT"
check_absent "T43 AC9 -- no leaked-tool-tag violation on the live tree" ": leaked-tool-tag: " "$WAVE7_ALL_LINT_OUT"

echo
echo "T43 AC10 -- performance budget (measured manually: 0.096s before, 0.097s after -- ~1.01x, well under 1.40x)"
t43_perf_start="$SECONDS"
t43_perf_ec=0
bash "$LINT_BIN" --all >/dev/null 2>&1 || t43_perf_ec=$?
t43_perf_elapsed=$((SECONDS - t43_perf_start))
[[ "$t43_perf_elapsed" -le 15 ]] \
  && pass "T43 AC10 -- --all completes within a sane absolute bound (${t43_perf_elapsed}s)" \
  || fail "T43 AC10 -- --all took ${t43_perf_elapsed}s, unexpectedly slow"
t43_write nofence.md 'Header

No mermaid fence anywhere in this file, just prose.
'
check_absent "T43 AC10 -- a file with no mermaid fence short-circuits (no mermaid-semicolon output)" \
  "mermaid-semicolon" "$(bash "$LINT_BIN" --path "${T43_SCRATCH}/nofence.md" 2>&1)"

echo
echo "T43 AC11 -- bash 3.2 compliance"
bash -n "$LINT_BIN" && pass "T43 AC11 -- edm-lint-artifacts passes bash -n" \
  || fail "T43 AC11 -- edm-lint-artifacts failed bash -n"
t43_bash4_hits="$(grep -nE 'declare -A|mapfile|readarray|\{fd\}' "$LINT_BIN" || true)"
[[ -z "$t43_bash4_hits" ]] \
  && pass "T43 AC11 -- no declare -A / mapfile / readarray / {fd} redirection" \
  || fail "T43 AC11 -- found bash 4+ construct(s): $t43_bash4_hits"

echo
echo "T43 AC12 -- no hook change needed; CLAUDE.md's bin/ table points at edm-lint-artifacts --help"
check "T43 AC12 -- hooks.json's PreToolUse still invokes edm-lint-artifacts" \
  "edm-lint-artifacts" "$(cat "${PLUGIN_DIR}/hooks/hooks.json" 2>/dev/null)"
# G19 (round-3 Wave 7c): the hardcoded "four violation classes" count drifted true as classes
# were added (mermaid-semicolon, unterminated-fence, scan-error, unreadable all landed after
# this row was first written) -- the row now points at --help rather than a count.
check "T43 AC12 -- CLAUDE.md's bin/ table points readers at edm-lint-artifacts --help rather than a hardcoded class count" \
  "edm-lint-artifacts --help" "$CLAUDE_MD_CONTENT"

rm -rf "$T43_SCRATCH"
# EDMV3-T43 end

# =================================================================================
# EDMV3-T44: the committed bin/tests/fixtures/mermaid/{valid,invalid}/ corpus proves the
# EDMV3-T43 Mermaid lint class has zero false positives and zero false negatives.
# =================================================================================
MERMAID_FIXTURES_DIR="${PLUGIN_DIR}/bin/tests/fixtures/mermaid"
MERMAID_VALID_DIR="${MERMAID_FIXTURES_DIR}/valid"
MERMAID_INVALID_DIR="${MERMAID_FIXTURES_DIR}/invalid"

echo
echo "T44 AC1 -- corpus size and split, each side's floor asserted separately"
t44_valid_count="$(ls "${MERMAID_VALID_DIR}"/*.md 2>/dev/null | wc -l | tr -d ' ')"
t44_invalid_count="$(ls "${MERMAID_INVALID_DIR}"/*.md 2>/dev/null | wc -l | tr -d ' ')"
[[ "$t44_valid_count" -ge 10 ]] && pass "T44 AC1 -- valid/ has >=10 files (found ${t44_valid_count})" \
  || fail "T44 AC1 -- valid/ has only ${t44_valid_count} files, expected >=10"
[[ "$t44_invalid_count" -ge 5 ]] && pass "T44 AC1 -- invalid/ has >=5 files (found ${t44_invalid_count})" \
  || fail "T44 AC1 -- invalid/ has only ${t44_invalid_count} files, expected >=5"
t44_sum=$((t44_valid_count + t44_invalid_count))
[[ "$t44_sum" -ge 15 ]] && pass "T44 AC1 -- combined corpus has >=15 files (found ${t44_sum})" \
  || fail "T44 AC1 -- combined corpus has only ${t44_sum} files, expected >=15"

echo
echo "T44 AC2 -- valid/ coverage: entity codes, terminator, comment, directives, sequence, quoted labels, non-mermaid fence"
[[ -n "$(grep -l '#59;' "${MERMAID_VALID_DIR}"/*.md 2>/dev/null || true)" ]] \
  && pass "T44 AC2 -- a valid fixture covers #59;" || fail "T44 AC2 -- no valid fixture covers #59;"
[[ -n "$(grep -l '#quot;' "${MERMAID_VALID_DIR}"/*.md 2>/dev/null || true)" ]] \
  && pass "T44 AC2 -- a valid fixture covers #quot;" || fail "T44 AC2 -- no valid fixture covers #quot;"
[[ -n "$(grep -l '#35;' "${MERMAID_VALID_DIR}"/*.md 2>/dev/null || true)" ]] \
  && pass "T44 AC2 -- a valid fixture covers #35;" || fail "T44 AC2 -- no valid fixture covers #35;"
[[ -n "$(grep -l 'classDef' "${MERMAID_VALID_DIR}"/*.md 2>/dev/null || true)" ]] \
  && pass "T44 AC2 -- a valid fixture covers classDef" || fail "T44 AC2 -- no valid fixture covers classDef"
[[ -n "$(grep -l 'linkStyle' "${MERMAID_VALID_DIR}"/*.md 2>/dev/null || true)" ]] \
  && pass "T44 AC2 -- a valid fixture covers linkStyle" || fail "T44 AC2 -- no valid fixture covers linkStyle"
[[ -n "$(grep -l 'sequenceDiagram' "${MERMAID_VALID_DIR}"/*.md 2>/dev/null || true)" ]] \
  && pass "T44 AC2 -- a valid fixture covers a clean sequenceDiagram" || fail "T44 AC2 -- no valid fixture covers sequenceDiagram"
[[ -n "$(grep -l '```text' "${MERMAID_VALID_DIR}"/*.md 2>/dev/null || true)" ]] \
  && pass "T44 AC2 -- a valid fixture covers a non-Mermaid fence" || fail "T44 AC2 -- no valid fixture covers a non-Mermaid fence"
[[ -n "$(grep -l '%%' "${MERMAID_VALID_DIR}"/*.md 2>/dev/null || true)" ]] \
  && pass "T44 AC2 -- a valid fixture covers a %% comment with a semicolon" || fail "T44 AC2 -- no valid fixture covers a %% comment"
[[ -f "${MERMAID_VALID_DIR}/v12-indented-fence.md" ]] \
  && pass "T44 AC2 -- an indented-fence fixture is present" || fail "T44 AC2 -- v12-indented-fence.md is missing"
# CA-038: v12 also now carries an em dash inside its indented fence, proving class 2 (unicode) is
# suppressed inside an INDENTED fence specifically -- the earlier version of this fixture only
# proved suppression at column-0 fences (every other valid/ fixture).
t44_v12_content="$(cat "${MERMAID_VALID_DIR}/v12-indented-fence.md")"
check "T44 AC2 (CA-038) -- v12's indented fence contains a real em dash" $'\xe2\x80\x94' "$t44_v12_content"
bash "$LINT_BIN" --path "${MERMAID_VALID_DIR}/v12-indented-fence.md" >/dev/null 2>&1 \
  && pass "T44 AC2 (CA-038) -- the em dash inside v12's indented fence is class-2 suppressed (fixture stays CLEAN)" \
  || fail "T44 AC2 (CA-038) -- v12-indented-fence.md is no longer CLEAN after adding an em dash inside its indented fence"

# G27/CA-101: prove a legal paren/curly label carrying an entity INSIDE plus a real
# statement-terminating ";" OUTSIDE the label passes -- no prior valid/ fixture exercised this
# combination for the (...) and {...} label shapes (only [...] and quoted labels were covered).
[[ -f "${MERMAID_VALID_DIR}/v13-paren-curly-labels.md" ]] \
  && pass "T44 AC2 (G27) -- a paren/curly-label-with-terminator fixture is present" \
  || fail "T44 AC2 (G27) -- v13-paren-curly-labels.md is missing"
t44_v13_content="$(cat "${MERMAID_VALID_DIR}/v13-paren-curly-labels.md" 2>/dev/null || true)"
check "T44 AC2 (G27) -- v13 carries a (...)-shaped label" "(Wait" "$t44_v13_content"
check "T44 AC2 (G27) -- v13 carries a {...}-shaped label" "{Retry" "$t44_v13_content"

echo
echo "T44 AC3 -- invalid/ coverage: one file per required case, each with an expected-line marker"
for _t44_case in i01-bracket-label i02-quoted-label i03-edge-pipe-label i04-curly-label i05-sequence-message i06-indented-mermaid-label; do
  _t44_f="${MERMAID_INVALID_DIR}/${_t44_case}.md"
  [[ -f "$_t44_f" ]] && pass "T44 AC3 -- ${_t44_case}.md exists" || fail "T44 AC3 -- ${_t44_case}.md is missing"
  grep -q 'expected-line:' "$_t44_f" 2>/dev/null && pass "T44 AC3 -- ${_t44_case}.md carries an expected-line marker" \
    || fail "T44 AC3 -- ${_t44_case}.md has no expected-line marker"
done

echo
echo "T44 AC4 -- exact violation set: zero on valid/, exactly one per file (at its expected line) on invalid/"
t44_valid_rc=0
t44_valid_out="$(bash "$LINT_BIN" --path "$MERMAID_VALID_DIR" 2>&1)" || t44_valid_rc=$?
check "T44 AC4 -- valid/ exits 0 (no violations found)" "0" "$t44_valid_rc"
check "T44 AC4 -- valid/ is CLEAN" "CLEAN" "$t44_valid_out"
check_absent "T44 AC4 -- the indented-fence fixture does not leak a mermaid-semicolon violation" \
  "v12-indented-fence.md" "$t44_valid_out"

t44_ac4_case() {
  local bad=0 f expected actual
  for f in "${MERMAID_INVALID_DIR}"/*.md; do
    # G51/CA-211: both extractions now share one set +e/set -e bracket -- previously only the
    # `actual=` extraction two lines below was guarded, so a 7th invalid fixture added later
    # without an `expected-line:` marker would crash the whole suite here under `set -e` instead
    # of failing just this one assertion.
    set +e
    expected="$(sed -n '1p' "$f" | grep -oE 'expected-line: [0-9]+' | grep -oE '[0-9]+')"
    actual="$(bash "$LINT_BIN" --path "$f" 2>&1 | grep -oE ':[0-9]+: mermaid-semicolon:' | grep -oE '[0-9]+' | head -1)"
    set -e
    if [[ -z "$expected" ]]; then
      bad=1
      echo "  MISSING expected-line marker in $(basename "$f")"
      continue
    fi
    if [[ "$actual" != "$expected" ]]; then
      bad=1
      echo "  MISMATCH in $(basename "$f"): expected line ${expected}, got ${actual:-<none>}"
    fi
  done
  [[ $bad -eq 0 ]] && pass "T44 AC4 -- every invalid/ fixture violates at exactly its recorded expected-line" \
    || fail "T44 AC4 -- at least one invalid/ fixture's violation line did not match its expected-line marker (see above)"
}
t44_ac4_case

echo
echo "T44 AC5 -- false positives are a release blocker"
t44_ac5_case() {
  local scratch
  scratch="$(mktemp -d "${TMP}/edm-t44-fp.XXXXXX")" || { fail "T44 AC5 -- mktemp failed"; return 1; }
  cp "${MERMAID_VALID_DIR}/v01-entity-codes.md" "${scratch}/copy.md"

  bash "$LINT_BIN" --path "${scratch}/copy.md" >/dev/null 2>&1 \
    && pass "T44 AC5 -- unmodified copy of a valid fixture (with a legal #59;) still passes" \
    || fail "T44 AC5 -- unmodified copy of a valid fixture unexpectedly failed"

  printf '\n```mermaid\nflowchart TD\n    Z[Raw; semicolon] --> Y[End]\n```\n' >> "${scratch}/copy.md"
  check_fails "T44 AC5 -- adding a raw ';' to the copy makes the suite fail" "mermaid-semicolon" \
    bash "$LINT_BIN" --path "${scratch}/copy.md"

  rm -rf "$scratch"
}
t44_ac5_case

echo
echo "T44 AC6 -- the corpus test runs in CI"
# Same auto-discovery mechanism as T42 AC12: test:smoke's script is the run-all.sh aggregator,
# which discovers every bin/tests/*-smoke.sh suite (EDMV3-T20 AC3) including this one.
check "T44 AC6 -- .gitlab-ci.yml's test:smoke job runs the run-all.sh aggregator" \
  "bin/tests/run-all.sh" "$(cat "$GITLAB_CI_YML" 2>/dev/null)"

echo
echo "T44 AC7 -- existing committed diagrams under tracked SRD/ trees pass"
# CA-094: reuses the shared whole-tree capture (before T66 AC12) instead of a fresh --all run.
_wave7_assert_shared_lint_fresh "T44 AC7"
[[ "$WAVE7_ALL_LINT_EXIT" -eq 0 ]] || fail "T44 AC7 -- edm-lint-artifacts --all exited ${WAVE7_ALL_LINT_EXIT} (captured once): ${WAVE7_ALL_LINT_OUT}"
check "T44 AC7 -- edm-lint-artifacts --all is CLEAN across the tracked SRD tree" "CLEAN" "$WAVE7_ALL_LINT_OUT"

echo
echo "T44 AC8 -- this suite's T44 cases use the shared _harness.sh assertions"
t44_block="$(awk '/^# EDMV3-T44:/{f=1} f{print} /^# EDMV3-T44 end/{exit}' "${SCRIPT_DIR}/wave7-smoke.sh")"
t44_check_uses="$(printf '%s\n' "$t44_block" | grep -c 'check_fails\|check "' || true)"
[[ "${t44_check_uses:-0}" -gt 0 ]] \
  && pass "T44 AC8 -- T44's own cases use check/check_fails from _harness.sh" \
  || fail "T44 AC8 -- T44's cases do not appear to use the shared harness assertions"
# EDMV3-T44 end

# =================================================================================
# CA-144 (code-audit round 2): an edm-lint-ignore marker directly above a fence opener must
# not corrupt the fence state machine in bin/_edm-lint-lib.sh's build_line_classes. Before the
# fix, the marker's ignore_next branch consumed the fence-open line via `next` before the
# fence-open transition ran, so in_fence never became 1 -- the fenced content below was
# scanned as ordinary prose (a false positive) and the fence's own CLOSING line was then
# matched by the still-armed opener branch instead, inverting fence-suppression state for
# everything after it in the file.
# =================================================================================
echo
echo "CA-144 -- edm-lint-ignore directly above a fence opener: suppresses the fenced content,"
echo "does not corrupt fence state for the prose after the fence's real close"
CA144_FIXTURE="${PLUGIN_DIR}/bin/tests/fixtures/lint-lib/ca144-ignore-marker-before-fence.md"
[[ -f "$CA144_FIXTURE" ]] && pass "CA-144 -- fixture file exists" \
  || fail "CA-144 -- fixture file missing: $CA144_FIXTURE"

ca144_ec=0
ca144_out="$(bash "$LINT_BIN" --path "$CA144_FIXTURE" 2>&1)" || ca144_ec=$?

[[ "$ca144_ec" -eq 1 ]] && pass "CA-144 -- fixture reports exactly one violation, not zero and not more" \
  || fail "CA-144 -- expected exit 1 (exactly one violation), got exit ${ca144_ec}: ${ca144_out}"
check_absent "CA-144 -- the fenced Co-Authored-By line (inside the ignored fence) is suppressed" \
  "Should Be Suppressed By The Fence" "$ca144_out"
check "CA-144 -- the Co-Authored-By line AFTER the fence's real close is still reported (not" \
  "Should Be Reported" "$ca144_out"
check "CA-144 -- the reported violation is attributed to the attribution class" \
  "attribution:" "$ca144_out"
ca144_violation_count="$(printf '%s\n' "$ca144_out" | grep -cE ': attribution: ' || true)"
[[ "${ca144_violation_count:-0}" -eq 1 ]] \
  && pass "CA-144 -- exactly one attribution violation reported (the post-fence one, not the fenced one)" \
  || fail "CA-144 -- expected exactly 1 attribution violation, found ${ca144_violation_count:-0}"
# CA-144 end

# ---- EDMV3-T33: /edm:verify-runtime closes every PARTIAL; D15 spec-defect policy -------------
echo
echo "=== EDMV3-T33: /edm:verify-runtime skill + D15 unverifiable-AC policy ==="
VERIFY_RUNTIME_SKILL="${PLUGIN_DIR}/skills/verify-runtime/SKILL.md"
VR_CONTENT="$(cat "$VERIFY_RUNTIME_SKILL")"

echo "T33 AC1 -- verify-runtime skill file exists and names partial_verdict_map"
[[ -f "$VERIFY_RUNTIME_SKILL" ]] && pass "T33 AC1 -- skills/verify-runtime/SKILL.md exists" \
  || fail "T33 AC1 -- skills/verify-runtime/SKILL.md does not exist"
check "T33 AC1 -- names partial_verdict_map" "partial_verdict_map" "$VR_CONTENT"
check "T33 AC1 -- invocable as /edm:verify-runtime <PREFIX>" "/edm:verify-runtime <PREFIX>" "$VR_CONTENT"

echo
echo "T33 AC2 -- closure recorded with closing timestamp and a verification.md section reference"
check "T33 AC2 -- record-partial-verdict close call present" "record-partial-verdict <PREFIX> <ticket> close" "$VR_CONTENT"
check "T33 AC2 -- post-deploy/verification.md is the written output" "post-deploy/verification.md" "$VR_CONTENT"
check "T33 AC2 -- one section per PARTIAL documented" "Closed" "$VR_CONTENT"

echo
echo "T33 AC3 -- FAIL directs to remediation loop and offers no acceptance option"
check "T33 AC3 -- FAIL directs to /edm:implement remediation loop" "/edm:implement" "$VR_CONTENT"
check "T33 AC3 -- states no way to accept the failure" "no way to accept the failure" "$VR_CONTENT"
check_absent "T33 AC3 -- no 'accept and continue' style escape hatch" "Accept and continue" "$VR_CONTENT"
check_absent "T33 AC3 -- no 'skip remediation' escape hatch" "skip remediation" "$VR_CONTENT"
check "T33 AC3 -- AskUserQuestion PASS/FAIL options state there is no third option" \
  "There is no third option" "$VR_CONTENT"

echo
echo "T33 AC4 -- no third verdict (BLOCKED/WAIVED/N/A-runtime) anywhere in scope"
t33_blocked_pattern='BLOCKED'
t33_waived_pattern='WAIVED'
t33_naruntime_pattern='N/A-runtime'
t33_third_verdict_hits="$(grep -rn "${t33_blocked_pattern}\|${t33_waived_pattern}\|${t33_naruntime_pattern}" \
  "${PLUGIN_DIR}/bin/edm-state" "$VERIFY_RUNTIME_SKILL" "${PLUGIN_DIR}/agents/edm-qc-auditor.md" 2>/dev/null || true)"
# G20 (round-3): three-needle OR'd scan for a never-implemented third verdict -- each needle
# routed through assert_tree_absent (G2/CA-037 + G13/CA-145, round 4): genuinely seeded scratch
# controls, and the three scanned files are asserted to exist before each needle check runs.
# G2/CA-037 residual (round 5): the OR'd producing pattern above is built from the same three
# variables passed to assert_tree_absent below, closing the divergent-typo class.
t33_blocked_control="${TMP}/edm-t33-blocked-control.txt"
printf 'BLOCKED\n' > "$t33_blocked_control"
assert_tree_absent "T33 AC4 -- no BLOCKED token in edm-state, verify-runtime, or qc-auditor" \
  "$t33_blocked_pattern" "$t33_third_verdict_hits" "$(cat "$t33_blocked_control")" \
  "${PLUGIN_DIR}/bin/edm-state" "$VERIFY_RUNTIME_SKILL" "${PLUGIN_DIR}/agents/edm-qc-auditor.md"
t33_waived_control="${TMP}/edm-t33-waived-control.txt"
printf 'WAIVED\n' > "$t33_waived_control"
assert_tree_absent "T33 AC4 -- no WAIVED token in edm-state, verify-runtime, or qc-auditor" \
  "$t33_waived_pattern" "$t33_third_verdict_hits" "$(cat "$t33_waived_control")" \
  "${PLUGIN_DIR}/bin/edm-state" "$VERIFY_RUNTIME_SKILL" "${PLUGIN_DIR}/agents/edm-qc-auditor.md"
t33_naruntime_control="${TMP}/edm-t33-naruntime-control.txt"
printf 'N/A-runtime\n' > "$t33_naruntime_control"
assert_tree_absent "T33 AC4 -- no N/A-runtime token in edm-state, verify-runtime, or qc-auditor" \
  "$t33_naruntime_pattern" "$t33_third_verdict_hits" "$(cat "$t33_naruntime_control")" \
  "${PLUGIN_DIR}/bin/edm-state" "$VERIFY_RUNTIME_SKILL" "${PLUGIN_DIR}/agents/edm-qc-auditor.md"
rm -f "$t33_blocked_control" "$t33_waived_control" "$t33_naruntime_control"

echo
echo "T33 AC5 -- D15 policy in CLAUDE.md: two sanctioned responses"
CLAUDE_MD_T33="$(cat "${PLUGIN_DIR}/CLAUDE.md")"
check "T33 AC5 -- 'unverifiable acceptance criterion' subsection language present" \
  "unverifiable acceptance criterion" "$CLAUDE_MD_T33"
check "T33 AC5 -- route (a): rework the AC" "Rework the AC" "$CLAUDE_MD_T33"
check "T33 AC5 -- route (b): move out of scope" "Move the unverifiable clause out of scope" "$CLAUDE_MD_T33"
check "T33 AC5 -- referenced by name from verify-runtime" 'CLAUDE.md Sec."Unverifiable acceptance criteria (D15)"' "$VR_CONTENT"
QC_AUDITOR_T33="$(cat "${PLUGIN_DIR}/agents/edm-qc-auditor.md")"
check "T33 AC5 -- referenced by name from edm-qc-auditor.md" 'CLAUDE.md Sec."Unverifiable acceptance criteria (D15)"' "$QC_AUDITOR_T33"

echo
echo "T33 AC6 -- route (b) is a gate action; implementer cannot descope"
check "T33 AC6 -- 'implementer cannot descope' stated in CLAUDE.md" "implementer cannot descope" "$CLAUDE_MD_T33"
check "T33 AC6 -- 'gate change control' stated in verify-runtime skill" "gate change control" "$VR_CONTENT"

echo
echo "T33 AC8 -- ownership boundary: this ticket adds no Skill invocation to the orchestrator"
IMPLEMENT_SKILL_T33="$(cat "${PLUGIN_DIR}/skills/implement/SKILL.md")"
check "T33 AC8 -- ownership sentence present in implement/SKILL.md" \
  "Phase 6 is closed by the orchestrator" "$IMPLEMENT_SKILL_T33"
t33_orch_skill_grant="$(grep -n '^allowed-tools:' "${PLUGIN_DIR}/skills/implement/SKILL.md" | grep -c 'Skill' || true)"
[[ "${t33_orch_skill_grant:-0}" -eq 0 ]] && pass "T33 AC8 -- implement/SKILL.md's allowed-tools does not grant Skill" \
  || fail "T33 AC8 -- implement/SKILL.md's allowed-tools unexpectedly grants Skill"

echo
echo "T33 AC9 -- direct-invocation path: README.md and implement/SKILL.md state the two-command sequence"
check "T33 AC9 -- README.md command table mentions verify-runtime" "verify-runtime" "$(cat "${PLUGIN_DIR}/README.md")"
check "T33 AC9 -- implement/SKILL.md Step 8 states the two-command sequence" \
  "edm-state phase-complete <PREFIX> 6" "$IMPLEMENT_SKILL_T33"

echo
echo "T33 AC10 -- frontmatter contract: full grant set, no Edit, no bare Bash"
t33_frontmatter="$(sed -n '1,10p' "$VERIFY_RUNTIME_SKILL")"
check "T33 AC10 -- argument-hint '<PREFIX>'" "argument-hint: '<PREFIX>'" "$t33_frontmatter"
check "T33 AC10 -- allowed-tools exact set" \
  "allowed-tools: Read, Write, Bash(edm-state *), Bash(mkdir *), Glob, Grep, AskUserQuestion, TodoWrite" "$t33_frontmatter"
check_absent "T33 AC10 -- no Edit grant" "Edit" "$t33_frontmatter"
check_absent "T33 AC10 -- no bare Bash grant" "Bash," "$(printf '%s' "$t33_frontmatter" | grep '^allowed-tools:')"

echo
echo "T33 AC12 -- empty partial_verdict_map: nothing to verify, writes no file"
check "T33 AC12 -- empty-map message documented" "Nothing to verify" "$VR_CONTENT"
check "T33 AC12 -- absence is authoritative -- writes no file" "absence is authoritative" "$VR_CONTENT"

echo
echo "T33 AC13 -- manifest lists the new skill"
check "T33 AC13 -- marketplace.json lists ./skills/verify-runtime" \
  '"./skills/verify-runtime"' "$(cat "${PLUGIN_DIR}/../../.claude-plugin/marketplace.json")"

echo
echo "T33 AC14 -- upstream loop closed: qc-audit.md and ticket-audit.md anti-pattern/pre-flight entries"
QC_AUDIT_DOC_T33="$(cat "${PLUGIN_DIR}/docs/audit-patterns/qc-audit.md")"
check "T33 AC14 -- qc-audit.md anti-pattern names infrastructure that does not exist" \
  "infrastructure that does not exist" "$QC_AUDIT_DOC_T33"
t33_qc_audit_h2_count="$(count_matches '^## ' "${PLUGIN_DIR}/docs/audit-patterns/qc-audit.md")"
[[ "$t33_qc_audit_h2_count" -eq 4 ]] && pass "T33 AC14 -- qc-audit.md still has exactly 4 '##' headings" \
  || fail "T33 AC14 -- qc-audit.md has ${t33_qc_audit_h2_count} '##' headings, expected 4"
TICKET_AUDIT_DOC_T33="$(cat "${PLUGIN_DIR}/docs/audit-patterns/ticket-audit.md")"
check "T33 AC14 -- ticket-audit.md pre-flight names environment the project does not have" \
  "environment the project does not have" "$TICKET_AUDIT_DOC_T33"

echo
echo "T33 -- edm-check-grants and bash -n stay clean with the new skill in the tree"
bash -n "${PLUGIN_DIR}/bin/edm-state" && pass "T33 -- bash -n bin/edm-state" || fail "T33 -- bash -n bin/edm-state failed"
# CA-094: reuses the shared whole-tree grants capture (before T66 AC12) instead of a fresh run.
_wave7_assert_shared_lint_fresh "T33"
[[ "$WAVE7_GRANTS_EXIT" -eq 0 ]] && pass "T33 -- edm-check-grants exits 0 (captured once; CA-094)" \
  || fail "T33 -- edm-check-grants failed with the new skill present (captured once; output: ${WAVE7_GRANTS_OUT})"
# EDMV3-T33 end


# ---- EDMV3-T34: Skill-tool composition depth spike, CLAUDE.md documents the pattern -----------
echo
echo "=== EDMV3-T34: skill-composition spike recorded, CLAUDE.md rule 2 rewritten ==="
SPIKE_NOTE="$(cd "$PLUGIN_DIR/../.." && pwd)/SRD/edm/EDMV3__prompt-streamline/spike-skill-composition.md"
DECISIONS_MD="$(cd "$PLUGIN_DIR/../.." && pwd)/SRD/edm/EDMV3__prompt-streamline/decisions.md"

echo "T34 AC1 -- spike note exists and answers all six questions"
[[ -f "$SPIKE_NOTE" ]] && pass "T34 AC1 -- spike-skill-composition.md exists" \
  || fail "T34 AC1 -- spike-skill-composition.md does not exist"
SPIKE_CONTENT="$(cat "$SPIKE_NOTE" 2>/dev/null || true)"
check "T34 AC1 -- Q1 (invocation succeeds) answered" "Does the invocation succeed?" "$SPIKE_CONTENT"
check "T34 AC1 -- Q2 (\$ARGUMENTS reaches callee) answered" "Does \`\$ARGUMENTS\` reach the callee?" "$SPIKE_CONTENT"
check "T34 AC1 -- Q3 (caller variables visible) answered" "visible to the callee" "$SPIKE_CONTENT"
check "T34 AC1 -- Q4 (whose allowed-tools govern) answered" "Whose \`allowed-tools\` govern?" "$SPIKE_CONTENT"
check "T34 AC1 -- Q5 (disabled target) answered" "not enabled" "$SPIKE_CONTENT"
check "T34 AC1 -- Q6 (context survives round trip) answered" "survive the round trip" "$SPIKE_CONTENT"

echo
echo "T34 AC2 -- depth: at least two chained invocations recorded"
check "T34 AC2 -- two-level chain recorded (hop 1: caller -> mid)" '`spike-caller` -> `spike-mid`' "$SPIKE_CONTENT"
check "T34 AC2 -- two-level chain recorded (hop 2: leaf reached)" "spike-leaf" "$SPIKE_CONTENT"
check "T34 AC2 -- depth framing (not just existence) stated" "two-level chain in one session" "$SPIKE_CONTENT"

echo
echo "T34 AC3 -- disabled/nonexistent target failure mode recorded precisely"
check "T34 AC3 -- observed error text captured verbatim" "tool_use_error: Unknown skill:" "$SPIKE_CONTENT"

echo
echo "T34 AC4 -- explicit GO or NO-GO recommendation, dated, in decisions.md"
DECISIONS_CONTENT="$(cat "$DECISIONS_MD" 2>/dev/null || true)"
check "T34 AC4 -- GO recommendation recorded in decisions.md as D21" "D21 | Skill-tool composition depth spike" "$DECISIONS_CONTENT"
check "T34 AC4 -- explicit GO verdict" "**GO**" "$DECISIONS_CONTENT"
check "T34 AC4 -- dated" "2026-07-28" "$DECISIONS_CONTENT"

echo
echo "T34 AC5 -- ordering: the spike note is committed, and orchestrator holds no T34-specific note"
[[ -f "$SPIKE_NOTE" ]] && pass "T34 AC5 -- spike-skill-composition.md is committed to the initiative directory" \
  || fail "T34 AC5 -- spike-skill-composition.md is missing"
check_absent "T34 AC5 -- orchestrator/SKILL.md carries no T34-specific spike note" "EDMV3-T34" "$(cat "${PLUGIN_DIR}/skills/orchestrator/SKILL.md")"

echo
echo "T34 AC6 -- rule 2 rewritten: Skill-tool composition pattern and both caller obligations"
CLAUDE_MD_T34="$(cat "${PLUGIN_DIR}/CLAUDE.md")"
check "T34 AC6 -- 'Skill-tool composition' section present" "Skill-tool composition" "$CLAUDE_MD_T34"
check "T34 AC6 -- caller obligation 1: Skill in allowed-tools" "must appear in the caller's \`allowed-tools\`" "$CLAUDE_MD_T34"
check "T34 AC6 -- caller obligation 2: graceful degradation" "must handle a target-skill-not-enabled failure gracefully" "$CLAUDE_MD_T34"

echo
echo "T34 AC7 -- the old sentence is removed, not qualified, and appears nowhere else"
# Built from two halves at runtime (never written as one literal string in this file) so this
# negative assertion's own search term does not itself count as an occurrence under a repo-wide
# grep -- the real AC7 verify command has no bin/tests/ carve-out, unlike the vocabulary checker.
t34_old_sentence="each contain their own"
t34_old_sentence="${t34_old_sentence} orchestration"
t34_old_sentence_hits="$(grep -rl "$t34_old_sentence" "${PLUGIN_DIR}/" 2>/dev/null | wc -l | tr -d ' ' || true)"
[[ "${t34_old_sentence_hits:-1}" -eq 0 ]] && pass "T34 AC7 -- the abolished rule-2 sentence appears nowhere in plugins/edm/" \
  || fail "T34 AC7 -- old sentence still present in ${t34_old_sentence_hits} file(s)"

echo
echo "T34 AC8 -- concrete failure mode, git plugin cited as precedent"
check "T34 AC8 -- concrete failure mode (tool_use_error) recorded in CLAUDE.md" "tool_use_error: Unknown skill" "$CLAUDE_MD_T34"
check "T34 AC8 -- git plugin cited as precedent" "git plugin" "$CLAUDE_MD_T34"

echo
echo "T34 AC9 -- rules 1, 3, 4 untouched (no 'commands/' reword)"
check "T34 AC9 -- rule 1 ('there is no commands/') intact" "there is no \`commands/\`" "$CLAUDE_MD_T34"
check "T34 AC9 -- rule 1's 'Do not re-introduce' instruction intact" "Do not re-introduce a \`commands/\`" "$CLAUDE_MD_T34"

echo
echo "T34 AC10 -- intent-to-file index added"
check "T34 AC10 -- intent-to-file index present" "Intent-to-file index" "$CLAUDE_MD_T34"
check "T34 AC10 -- 'which file is authoritative' framing present" "which file is authoritative" "$CLAUDE_MD_T34"
# EDMV3-T34 end


# ---- EDMV3-T35: canonical Gate PROTOCOL written once; weak free-prose gates deleted ------------
echo
echo "=== EDMV3-T35: Gate PROTOCOL (canonical) + by-name references replace restatement ==="
ORCH_SKILL_T35="$(cat "${PLUGIN_DIR}/skills/orchestrator/SKILL.md")"

echo "T35 AC1 -- one canonical section"
t35_protocol_count="$(count_matches '^## Gate PROTOCOL (canonical)$' "${PLUGIN_DIR}/skills/orchestrator/SKILL.md")"
[[ "$t35_protocol_count" -eq 1 ]] && pass "T35 AC1 -- '## Gate PROTOCOL (canonical)' appears exactly once" \
  || fail "T35 AC1 -- '## Gate PROTOCOL (canonical)' appears ${t35_protocol_count} times, expected 1"

echo
echo "T35 AC2 -- the four preserved rules, verbatim"
check "T35 AC2 -- 'Please select an option to proceed' preserved" "Please select an option to proceed" "$ORCH_SKILL_T35"
check "T35 AC2 -- approve-gate called only on exact Approve selection" \
  'is called ONLY when the user selects the **exact "Approve" option**' "$ORCH_SKILL_T35"
check "T35 AC2 -- free-text responses are not approvals" "are **NOT** approvals" "$ORCH_SKILL_T35"
check "T35 AC2 -- never infer intent from sentiment" "Never infer intent from sentiment" "$ORCH_SKILL_T35"

echo
echo "T35 AC3 -- four additions: STOP and WAIT, 12-char headers, three options, approve-gate after selection"
check "T35 AC3 -- STOP and WAIT for the AskUserQuestion response" "STOP and WAIT for the \`AskUserQuestion\` response" "$ORCH_SKILL_T35"
check "T35 AC3 -- 12 characters or fewer" "12 characters or fewer" "$ORCH_SKILL_T35"
check "T35 AC3 -- Approve, Revise, No-Go" "Approve, Revise, No-Go" "$ORCH_SKILL_T35"
check "T35 AC3 -- approve-gate invocation happens only after the selection" \
  "invocation happens only after the selection" "$ORCH_SKILL_T35"

echo
echo "T35 AC4 -- zero restatements of 'free-text is never approval' outside orchestrator/SKILL.md"
# G20 (round-3): needles built from split parts so this suite's own source text never contains
# either contiguous phrase -- otherwise the repo-wide scan below (which includes bin/tests/,
# unlike most of this file's other repo-wide scans) would self-match its own assertion text,
# exactly the hazard the T36/vocabulary-guard split-needle idiom elsewhere in this file already
# avoids.
t35_freetext_needle_a="free-text is never"; t35_freetext_needle_a="${t35_freetext_needle_a} approval"
t35_freetext_needle_b="free text is not"; t35_freetext_needle_b="${t35_freetext_needle_b} an approval"
t35_freetext_hits="$(grep -rn -e "$t35_freetext_needle_a" -e "$t35_freetext_needle_b" "${PLUGIN_DIR}/" 2>/dev/null | grep -v 'orchestrator/SKILL.md' || true)"
# G2/CA-037 + G13/CA-145: controls are genuinely seeded scratch files under $TMP (outside
# PLUGIN_DIR, so they cannot self-contaminate the repo-wide scan above) built from the same
# split-needle variables, never a fresh contiguous literal -- reusing $t35_freetext_needle_a/_b
# keeps this file's own source text free of the contiguous phrase. "${PLUGIN_DIR}/" is asserted
# to exist before either needle check runs.
t35_control_a="${TMP}/edm-t35-control-a.txt"
printf '%s\n' "$t35_freetext_needle_a" > "$t35_control_a"
t35_control_b="${TMP}/edm-t35-control-b.txt"
printf '%s\n' "$t35_freetext_needle_b" > "$t35_control_b"
assert_tree_absent "T35 AC4 -- no free-text-is-never-approval restatement outside orchestrator/SKILL.md" \
  "$t35_freetext_needle_a" "$t35_freetext_hits" "$(cat "$t35_control_a")" "${PLUGIN_DIR}/"
assert_tree_absent "T35 AC4 -- no free-text-is-not-an-approval restatement outside orchestrator/SKILL.md" \
  "$t35_freetext_needle_b" "$t35_freetext_hits" "$(cat "$t35_control_b")" "${PLUGIN_DIR}/"
rm -f "$t35_control_a" "$t35_control_b"
for t35_gate_site in "plugins/edm/skills/plan/SKILL.md" "plugins/edm/skills/audit-srd/SKILL.md" \
                     "plugins/edm/skills/audit-tickets/SKILL.md" "plugins/edm/skills/code-audit/SKILL.md"; do
  check "T35 AC4 -- ${t35_gate_site} references Gate PROTOCOL by name" \
    'Gate PROTOCOL' "$(cat "$(cd "${PLUGIN_DIR}/../.." && pwd)/${t35_gate_site}")"
done

echo
echo "T35 AC5 -- weak free-prose approval questions deleted"
t35_weak_gate_pattern="Ask: .Do you approve"
t35_weak_gate_hits="$(grep -rn "$t35_weak_gate_pattern" "${PLUGIN_DIR}/skills/" 2>/dev/null || true)"
# G20 (round-3): positive control proving the same pattern (the "." wildcard matches a literal
# quote in the real needle) would actually catch a line containing the retired weak-prose gate.
# G2/CA-037 residual (round 5): one shared pattern variable, not two independently-typed copies.
t35_weak_gate_control="$(printf '%s\n' 'synthetic control: Ask: "Do you approve of this plan?"' | grep -c "$t35_weak_gate_pattern" || true)"
if [[ "${t35_weak_gate_control:-0}" -lt 1 ]]; then
  fail "T35 AC5 -- positive control broken: a synthetic 'Ask: \"Do you approve' line was not caught by the pattern"
else
  [[ -z "$t35_weak_gate_hits" ]] && pass "T35 AC5 -- no 'Ask: \"Do you approve' free-prose gate remains in skills/ (positive control confirms the pattern works)" \
    || fail "T35 AC5 -- found a weak free-prose gate: $t35_weak_gate_hits"
fi

echo
echo "T35 AC6 -- abbreviated approval lines corrected to reference the PROTOCOL by name"
PLAN_SKILL_T35="$(cat "${PLUGIN_DIR}/skills/plan/SKILL.md")"
AUDIT_SRD_SKILL_T35="$(cat "${PLUGIN_DIR}/skills/audit-srd/SKILL.md")"
AUDIT_TICKETS_SKILL_T35="$(cat "${PLUGIN_DIR}/skills/audit-tickets/SKILL.md")"
check "T35 AC6 -- plan/SKILL.md's abbreviated Gate 1 line references the PROTOCOL" \
  'Gate PROTOCOL' "$PLAN_SKILL_T35"
check "T35 AC6 -- audit-srd/SKILL.md's abbreviated Gate 2 line references the PROTOCOL" \
  'Gate PROTOCOL' "$AUDIT_SRD_SKILL_T35"
check "T35 AC6 -- audit-tickets/SKILL.md's abbreviated Gate 3 line references the PROTOCOL" \
  'Gate PROTOCOL' "$AUDIT_TICKETS_SKILL_T35"

echo
echo "T35 AC7 -- the fourth free-prose gate (code-audit remediation gate) at the same standard"
CODE_AUDIT_SKILL_T35="$(cat "${PLUGIN_DIR}/skills/code-audit/SKILL.md")"
check "T35 AC7 -- 'remediation gate' named" "remediation gate" "$CODE_AUDIT_SKILL_T35"
check "T35 AC7 -- 'Remediation Gate (Code Audit)' section titled" "Remediation Gate (Code Audit)" "$CODE_AUDIT_SKILL_T35"
check "T35 AC7 -- upgraded to AskUserQuestion" 'Present via `AskUserQuestion`' "$CODE_AUDIT_SKILL_T35"

echo
echo "T35 AC8 -- all four skills grant AskUserQuestion (edm-check-grants clean)"
# CA-094: reuses the shared whole-tree grants capture (before T66 AC12) instead of a fresh run.
_wave7_assert_shared_lint_fresh "T35 AC8"
[[ "$WAVE7_GRANTS_EXIT" -eq 0 ]] && pass "T35 AC8 -- edm-check-grants exits 0 (captured once; CA-094)" \
  || fail "T35 AC8 -- edm-check-grants exited ${WAVE7_GRANTS_EXIT} (captured once; output: ${WAVE7_GRANTS_OUT})"
for t35_gate_skill in plan audit-srd audit-tickets code-audit; do
  check "T35 AC8 -- ${t35_gate_skill}/SKILL.md's allowed-tools grants AskUserQuestion" \
    "AskUserQuestion" "$(grep '^allowed-tools:' "${PLUGIN_DIR}/skills/${t35_gate_skill}/SKILL.md")"
done

echo
echo "T35 AC10 -- smoke assertions: section appears once, five gate sites reference it by name"
t35_gate_site_refs=0
for t35_ref_file in "${PLUGIN_DIR}/skills/orchestrator/SKILL.md" "${PLUGIN_DIR}/skills/plan/SKILL.md" \
                    "${PLUGIN_DIR}/skills/audit-srd/SKILL.md" "${PLUGIN_DIR}/skills/audit-tickets/SKILL.md" \
                    "${PLUGIN_DIR}/skills/code-audit/SKILL.md"; do
  grep -q 'Gate PROTOCOL' "$t35_ref_file" && t35_gate_site_refs=$((t35_gate_site_refs + 1))
done
[[ "$t35_gate_site_refs" -eq 5 ]] && pass "T35 AC10 -- all five gate sites reference Gate PROTOCOL by name" \
  || fail "T35 AC10 -- only ${t35_gate_site_refs}/5 gate sites reference Gate PROTOCOL by name"

echo
echo "T35 -- full suite stays green with the PROTOCOL section in place"
# CA-094: reuses the shared whole-tree lint capture (before T66 AC12) instead of a fresh run.
_wave7_assert_shared_lint_fresh "T35 (full suite)"
[[ "$WAVE7_ALL_LINT_EXIT" -eq 0 ]] && pass "T35 -- edm-lint-artifacts --all exits 0 (captured once; CA-094)" \
  || fail "T35 -- edm-lint-artifacts --all exited ${WAVE7_ALL_LINT_EXIT} (captured once; output: ${WAVE7_ALL_LINT_OUT})"
# EDMV3-T35 end


# ---- EDMV3-T36: every phase skill opens with a Step 0 gate/branch preflight --------------------
echo
echo "=== EDMV3-T36: Step 0 -- Gate and Branch Preflight, all eight phase skills ==="
T36_PHASE_SKILLS="plan srd audit-srd tickets audit-tickets implement code-audit verify-runtime"

echo "T36 AC1 -- all eight phase skills contain the Step 0 reference"
t36_step0_count=0
for t36_skill in $T36_PHASE_SKILLS; do
  if grep -q '^## Step 0 -- Gate and Branch Preflight$' "${PLUGIN_DIR}/skills/${t36_skill}/SKILL.md" 2>/dev/null; then
    t36_step0_count=$((t36_step0_count + 1))
  else
    fail "T36 AC1 -- skills/${t36_skill}/SKILL.md is missing the Step 0 heading"
  fi
done
[[ "$t36_step0_count" -eq 8 ]] && pass "T36 AC1 -- all eight phase skills contain the Step 0 heading" \
  || fail "T36 AC1 -- only ${t36_step0_count}/8 phase skills contain the Step 0 heading"

echo
echo "T36 AC2 -- the token each skill passes resolves to a real gate (functional, against a scratch initiative)"
t36_ac2_case() {
  with_scratch_repo _t36_ac2_inner
}
_t36_ac2_inner() {
  edm-init T36X >/dev/null 2>&1 || true
  local t36_tok t36_out t36_ec t36_results=""
  for t36_tok in $T36_PHASE_SKILLS; do
    t36_ec=0
    t36_out="$("$EDM_STATE" gate-check T36X "$t36_tok" 2>&1)" || t36_ec=$?
    t36_results="${t36_results}${t36_tok}=${t36_ec} "
  done
  # None of the eight tokens is unrecognized (the *) branch's distinctive message).
  if printf '%s\n' "$t36_results" | grep -q 'unknown gated command' 2>/dev/null; then
    fail "T36 AC2 -- a phase token fell through to the unknown-gated-command branch: $t36_results"
  else
    pass "T36 AC2 -- every one of the eight tokens resolves to a real gate outcome (no silent fall-through): $t36_results"
  fi
}
t36_ac2_case

echo
echo "T36 AC3 -- Step 0 text instructs a block on non-zero gate-check and surfaces the message"
PLAN_STEP0_T36="$(sed -n '/^## Step 0 -- Gate and Branch Preflight$/,/^## Operational Orchestration$/p' "${PLUGIN_DIR}/skills/plan/SKILL.md")"
check "T36 AC3 -- gate-check non-zero BLOCKs" "**BLOCK**: do not proceed with the phase, and surface the exact message" "$PLAN_STEP0_T36"

echo
echo "T36 AC4 -- Step 0 text instructs a block on non-zero branch-check; CHANGELOG records the behaviour change"
check "T36 AC4 -- branch-check non-zero BLOCKs, surfacing the git checkout instruction" \
  'surface the `git checkout <initiative_branch>` instruction it' "$PLAN_STEP0_T36"
t36_changelog_block="$(awk '/EDMV3-T36/{f=1} f{print} /^## /{if (f && NR > 1) exit}' "${PLUGIN_DIR}/CHANGELOG.md")"
check "T36 AC4 -- CHANGELOG.md records 'branch-check becoming a BLOCK'" \
  "branch-check becoming a BLOCK" "$t36_changelog_block"

echo
echo "T36 AC5 -- written once (full text in one file), referenced by name from the other seven"
t36_full_text_files=0
for t36_skill in $T36_PHASE_SKILLS; do
  t36_hits="$(count_matches 'edm-state branch-check' "${PLUGIN_DIR}/skills/${t36_skill}/SKILL.md")"
  [[ "${t36_hits:-0}" -gt 0 ]] && t36_full_text_files=$((t36_full_text_files + 1))
done
[[ "$t36_full_text_files" -eq 1 ]] && pass "T36 AC5 -- exactly one of the eight phase skills (plan) carries the literal edm-state branch-check text" \
  || fail "T36 AC5 -- ${t36_full_text_files}/8 phase skills carry the literal text, expected exactly 1"
for t36_skill in srd audit-srd tickets audit-tickets implement code-audit verify-runtime; do
  check "T36 AC5 -- skills/${t36_skill}/SKILL.md references Step 0 by name" \
    'skills/plan/SKILL.md Sec."Step 0 -- Gate and Branch Preflight"' \
    "$(cat "${PLUGIN_DIR}/skills/${t36_skill}/SKILL.md")"
done

echo
echo "T36 AC6 -- UserPromptExpansion hooks retained unchanged"
t36_hooks_hits="$(grep -c 'UserPromptExpansion' "${PLUGIN_DIR}/hooks/hooks.json" 2>/dev/null || echo 0)"
[[ "${t36_hooks_hits:-0}" -gt 0 ]] && pass "T36 AC6 -- hooks.json still declares UserPromptExpansion hooks" \
  || fail "T36 AC6 -- hooks.json no longer declares UserPromptExpansion hooks"

echo
echo "T36 AC7 -- mode suppression computed, not restated (no 'skipped_phases' token in any of the eight)"
t36_skipped_phases_hits=0
for t36_skill in $T36_PHASE_SKILLS; do
  t36_c="$(count_matches 'skipped_phases' "${PLUGIN_DIR}/skills/${t36_skill}/SKILL.md")"
  t36_skipped_phases_hits=$((t36_skipped_phases_hits + ${t36_c:-0}))
done
[[ "$t36_skipped_phases_hits" -eq 0 ]] && pass "T36 AC7 -- zero 'skipped_phases' occurrences across all eight phase skills" \
  || fail "T36 AC7 -- found ${t36_skipped_phases_hits} 'skipped_phases' occurrence(s) across the eight phase skills"

echo
echo "T36 AC8 -- vocabulary check: the phase-preflight step is never paired on one line with the D-word for restored certainty"
# Pattern built from two halves assigned on separate lines, and the grep call itself split across
# two variables, so no single physical line in this checker ever contains both search terms
# together -- the real AC8 verify command has no self-exclusion, so this checker's own source
# must not be a false-positive hit under it.
t36_needle_a="step"
t36_needle_a="${t36_needle_a} 0"
t36_needle_b="determin"
t36_needle_b="${t36_needle_b}istic"
t36_step0_deterministic_hits="$(grep -rni "$t36_needle_a" "${PLUGIN_DIR}/" 2>/dev/null | grep -i "$t36_needle_b" || true)"
# G20 (round-3): positive control proving the same two-stage co-occurrence pipeline would
# actually catch a line containing both needles together, so the emptiness above is a real
# absence rather than a broken pipeline silently matching nothing.
t36_step0_deterministic_control="$(printf '%s\n' "synthetic control: ${t36_needle_a} gate uses ${t36_needle_b} enforcement" | grep -i "$t36_needle_a" | grep -i "$t36_needle_b" || true)"
if [[ -z "$t36_step0_deterministic_control" ]]; then
  fail "T36 AC8 -- positive control broken: a synthetic co-occurrence line was not caught by the pairing scan"
else
  [[ -z "$t36_step0_deterministic_hits" ]] && pass "T36 AC8 -- no such pairing found anywhere in plugins/edm/ (positive control confirms the scan works)" \
    || fail "T36 AC8 -- found a disallowed pairing: $t36_step0_deterministic_hits"
fi
check "T36 AC8 -- defence-in-depth framing used instead" "defence in depth on the Skill-tool path" "$(cat "${PLUGIN_DIR}/skills/plan/SKILL.md")"

echo
echo "T36 -- full suite and lint stay green with Step 0 in place across all eight phase skills"
# CA-094: reuses the shared whole-tree lint/grants capture (before T66 AC12) instead of fresh runs.
_wave7_assert_shared_lint_fresh "T36 (full suite)"
[[ "$WAVE7_GRANTS_EXIT" -eq 0 ]] && pass "T36 -- edm-check-grants exits 0 (captured once; CA-094)" \
  || fail "T36 -- edm-check-grants exited ${WAVE7_GRANTS_EXIT} (captured once; output: ${WAVE7_GRANTS_OUT})"
[[ "$WAVE7_ALL_LINT_EXIT" -eq 0 ]] && pass "T36 -- edm-lint-artifacts --all exits 0 (captured once; CA-094)" \
  || fail "T36 -- edm-lint-artifacts --all exited ${WAVE7_ALL_LINT_EXIT} (captured once; output: ${WAVE7_ALL_LINT_OUT})"
# EDMV3-T36 end

# ---- shared helper: numbered-list ascending check (T37 AC9 / T38 AC9) ---------------------------
# Column-0 numbered items ("1.", "2.", ...) must be strictly ascending with no repeats/gaps within
# each section. Resets at a "## "/"### " markdown heading or a whole-line "**Bold Header**"
# pseudo-heading (the convention this file set uses inside "## Step 1 -- Intake"). Lettered
# sub-steps ("7a.") never match the leading-integer pattern, so they do not break the sequence --
# consistent with T36 AC5's precedent that a named sub-step is not itself a restatement.
_wave7_check_ascending() {
  awk '
    BEGIN { prev = 0; err = "" }
    /^##/ { prev = 0 }
    /^\*\*[^*]+\*\*[ \t]*$/ { prev = 0 }
    {
      if (match($0, /^[0-9]+\./)) {
        numstr = substr($0, RSTART, RLENGTH - 1)
        num = numstr + 0
        if (prev == 0) {
          if (num != 1) { err = err sprintf("first item is %d not 1 (line %d); ", num, NR) }
        } else {
          if (num != prev + 1) { err = err sprintf("expected %d got %d (line %d); ", prev + 1, num, NR) }
        }
        prev = num
      }
    }
    END { if (err != "") { print err; exit 1 } else { exit 0 } }
  ' "$1"
}

# =================================================================================
# EDMV3-T37: each phase skill owns its phase entirely
# =================================================================================
echo
echo "=== EDMV3-T37: each phase skill owns its phase entirely (procedures relocated out of the dispatcher) ==="
T37_PHASE_SKILLS="plan srd audit-srd tickets audit-tickets implement code-audit verify-runtime"
ORCH_SKILL_T37="$(cat "${PLUGIN_DIR}/skills/orchestrator/SKILL.md")"

echo "T37 AC1 -- each phase's agent spawn template text appears in exactly one file"
declare -a t37_anchor_files=(plan srd srd audit-srd tickets audit-tickets implement code-audit code-audit)
declare -a t37_anchors=("Agent: edm-explorer" "Agent: edm-srd-writer" "Agent: edm-architect" \
  "Agent: edm-srd-auditor" "Agent: edm-ticket-writer" "Agent: edm-ticket-auditor" \
  "Agent: edm-implementer" "Agent: edm-audit-{lens-name}" "Agent: edm-audit-synthesizer")
t37_anchor_i=0
while [[ $t37_anchor_i -lt ${#t37_anchors[@]} ]]; do
  t37_anchor="${t37_anchors[$t37_anchor_i]}"
  t37_owner="${t37_anchor_files[$t37_anchor_i]}"
  t37_hit_count="$(grep -rl -- "$t37_anchor" "${PLUGIN_DIR}/skills/"*/SKILL.md 2>/dev/null | wc -l | tr -d ' ' || true)"
  t37_hit_owner_only="$(grep -l -- "$t37_anchor" "${PLUGIN_DIR}/skills/${t37_owner}/SKILL.md" 2>/dev/null || true)"
  if [[ "$t37_hit_count" -eq 1 && -n "$t37_hit_owner_only" ]]; then
    pass "T37 AC1 -- '${t37_anchor}' appears in exactly one file (skills/${t37_owner}/SKILL.md)"
  else
    fail "T37 AC1 -- '${t37_anchor}' expected exactly one file (skills/${t37_owner}/SKILL.md), found ${t37_hit_count}"
  fi
  t37_anchor_i=$((t37_anchor_i + 1))
done
check_absent "T37 AC1 -- orchestrator carries no agent spawn template marker" "Agent: edm-" "$ORCH_SKILL_T37"

echo
echo "T37 AC2 -- orchestrator contains no agent spawn template, no artifact template, no per-phase step list"
t37_ac2_hits="$(grep -c 'Task tool\|spawn the .edm-' "${PLUGIN_DIR}/skills/orchestrator/SKILL.md" 2>/dev/null || true)"
[[ "${t37_ac2_hits:-0}" -eq 0 ]] && pass "T37 AC2 -- orchestrator contains no spawn template ('Task tool'/'spawn the \`edm-' both absent)" \
  || fail "T37 AC2 -- found ${t37_ac2_hits} spawn-template marker(s) in orchestrator/SKILL.md"

echo
echo "T37 AC4 -- each of the eight phase skills ends with a Gate PROTOCOL reference in its last 20 lines"
t37_ac4_missing=""
for t37_skill in $T37_PHASE_SKILLS; do
  tail -20 "${PLUGIN_DIR}/skills/${t37_skill}/SKILL.md" | grep -q 'Gate PROTOCOL' \
    || t37_ac4_missing="${t37_ac4_missing} ${t37_skill}"
done
[[ -z "$t37_ac4_missing" ]] && pass "T37 AC4 -- all eight phase skills reference Gate PROTOCOL within their last 20 lines" \
  || fail "T37 AC4 -- missing in:${t37_ac4_missing}"

echo
echo "T37 AC6 -- phase-start/phase-complete calls: one owning file per phase (fast-track's mode-branch duplicate inside skills/tickets, and orchestrator+verify-runtime's documented phase-complete-6 split, are the sanctioned exceptions -- re-baselined to 3 files by EDMV3-T50, which wires the orchestrator's owning call)"
t37_ac6_bad=""
for t37_n in 1 2 3 4 5 6; do
  t37_start_files="$(grep -rl "phase-start <PREFIX> ${t37_n}\\b" "${PLUGIN_DIR}/skills/"*/SKILL.md 2>/dev/null | wc -l | tr -d ' ' || true)"
  [[ "$t37_start_files" -eq 1 ]] || t37_ac6_bad="${t37_ac6_bad} phase-start:${t37_n}=${t37_start_files}file(s)"
  t37_complete_files="$(grep -rl "phase-complete <PREFIX> ${t37_n}\\b" "${PLUGIN_DIR}/skills/"*/SKILL.md 2>/dev/null | wc -l | tr -d ' ' || true)"
  if [[ "$t37_n" -eq 6 ]]; then
    [[ "$t37_complete_files" -eq 3 ]] || t37_ac6_bad="${t37_ac6_bad} phase-complete:6=${t37_complete_files}file(s),expected3(orchestrator+implement+verify-runtime)"
  else
    [[ "$t37_complete_files" -eq 1 ]] || t37_ac6_bad="${t37_ac6_bad} phase-complete:${t37_n}=${t37_complete_files}file(s)"
  fi
done
[[ -z "$t37_ac6_bad" ]] && pass "T37 AC6 -- one owning file per phase-start/phase-complete call (phase-complete 6's three-file split is the documented orchestrator-owns/implement+verify-runtime-restate-for-direct-invocation exception, EDMV3-T50)" \
  || fail "T37 AC6 -- unexpected file counts:${t37_ac6_bad}"

echo
echo "T37 AC9 -- numbered lists in every phase skill are strictly ascending, no repeats, no gaps"
t37_ac9_bad=""
for t37_skill in $T37_PHASE_SKILLS; do
  t37_ac9_err="$(_wave7_check_ascending "${PLUGIN_DIR}/skills/${t37_skill}/SKILL.md" || true)"
  [[ -z "$t37_ac9_err" ]] || t37_ac9_bad="${t37_ac9_bad} ${t37_skill}(${t37_ac9_err})"
done
[[ -z "$t37_ac9_bad" ]] && pass "T37 AC9 -- all eight phase skills have strictly ascending numbered lists" \
  || fail "T37 AC9 -- numbering defect(s):${t37_ac9_bad}"

echo
echo "T37 -- full suite and grants stay green with the phase-procedure move in place"
# CA-094: reuses the shared whole-tree lint/grants capture (before T66 AC12) instead of fresh runs.
_wave7_assert_shared_lint_fresh "T37 (full suite)"
[[ "$WAVE7_GRANTS_EXIT" -eq 0 ]] && pass "T37 -- edm-check-grants exits 0 (captured once; CA-094)" \
  || fail "T37 -- edm-check-grants exited ${WAVE7_GRANTS_EXIT} (captured once; output: ${WAVE7_GRANTS_OUT})"
[[ "$WAVE7_ALL_LINT_EXIT" -eq 0 ]] && pass "T37 -- edm-lint-artifacts --all exits 0 (captured once; CA-094)" \
  || fail "T37 -- edm-lint-artifacts --all exited ${WAVE7_ALL_LINT_EXIT} (captured once; output: ${WAVE7_ALL_LINT_OUT})"
# EDMV3-T37 end

# =================================================================================
# EDMV3-T38: the orchestrator becomes a dispatcher of at most 300 lines
# =================================================================================
echo
echo "=== EDMV3-T38: orchestrator collapsed to a <=300-line dispatcher ==="

echo "T38 AC1 -- orchestrator/SKILL.md is at most 300 lines"
t38_orch_lines="$(wc -l < "${PLUGIN_DIR}/skills/orchestrator/SKILL.md" | tr -d ' ')"
[[ "$t38_orch_lines" -le 300 ]] && pass "T38 AC1 -- orchestrator/SKILL.md is ${t38_orch_lines} lines (<= 300)" \
  || fail "T38 AC1 -- orchestrator/SKILL.md is ${t38_orch_lines} lines, expected <= 300"

echo
echo "T38 AC2 -- retained set: seven '## ' sections (Overview, Communication [added EDMV3-T45], Step 1 -- Intake, Gate PROTOCOL, Step 2 -- Dispatch each phase, Resume and Compaction, Anti-Patterns)"
t38_section_count="$(grep -c '^## ' "${PLUGIN_DIR}/skills/orchestrator/SKILL.md" || true)"
[[ "$t38_section_count" -eq 7 ]] && pass "T38 AC2 -- exactly seven top-level sections (six T38 sections plus T45's Communication)" \
  || fail "T38 AC2 -- found ${t38_section_count} top-level sections, expected 7"
check "T38 AC2 -- Overview retained" "## Overview" "$ORCH_SKILL_T37"
check "T38 AC2 -- Step 1 -- Intake retained" "## Step 1 -- Intake" "$ORCH_SKILL_T37"
check "T38 AC2 -- Gate PROTOCOL retained" "## Gate PROTOCOL (canonical)" "$ORCH_SKILL_T37"
check "T38 AC2 -- Step 2 -- Dispatch each phase retained" "## Step 2 -- Dispatch each phase" "$ORCH_SKILL_T37"
check "T38 AC2 -- Resume and Compaction retained" "## Resume and Compaction" "$ORCH_SKILL_T37"
check "T38 AC2 -- Anti-Patterns retained" "## Anti-Patterns" "$ORCH_SKILL_T37"

echo
echo "T38 AC3 -- no phase procedure body (mirrors T37 AC2's check_absent)"
check_absent "T38 AC3 -- orchestrator contains no spawn template" "Agent: edm-" "$ORCH_SKILL_T37"

echo
echo "T38 AC4 -- Skill grant appears exactly once across all skills (orchestrator only), edm-check-grants clean"
t38_skill_grant_count="$(grep -rn '^allowed-tools:' "${PLUGIN_DIR}/skills/"*/SKILL.md | grep -c 'Skill\b' || true)"
[[ "$t38_skill_grant_count" -eq 1 ]] && pass "T38 AC4 -- exactly one skill's allowed-tools grants Skill" \
  || fail "T38 AC4 -- ${t38_skill_grant_count} skills grant Skill, expected 1"
check "T38 AC4 -- orchestrator/SKILL.md's allowed-tools grants Skill" "Skill" \
  "$(grep '^allowed-tools:' "${PLUGIN_DIR}/skills/orchestrator/SKILL.md")"
# CA-094: reuses the shared whole-tree grants capture (before T66 AC12) instead of a fresh run.
_wave7_assert_shared_lint_fresh "T38 AC4/AC13"
[[ "$WAVE7_GRANTS_EXIT" -eq 0 ]] && pass "T38 AC4/AC13 -- edm-check-grants exits 0 (captured once; CA-094)" \
  || fail "T38 AC4/AC13 -- edm-check-grants exited ${WAVE7_GRANTS_EXIT} (captured once; output: ${WAVE7_GRANTS_OUT})"

echo
echo "T38 AC5 -- graceful degradation instruction present (Skill-tool composition CLAUDE.md reference)"
check "T38 AC5 -- names the unavailable-skill failure text" "tool_use_error: Unknown skill" "$ORCH_SKILL_T37"
check "T38 AC5 -- never falls back to inlining" "does not fall back to inlining" "$ORCH_SKILL_T37"

echo
echo "T38 AC6 -- mode sub-flow bodies relocated; only the routing mention of mini-srd remains in the dispatcher"
t38_minisrd_count="$(grep -c 'mini-srd' "${PLUGIN_DIR}/skills/orchestrator/SKILL.md" || true)"
[[ "${t38_minisrd_count:-0}" -le 1 ]] && pass "T38 AC6 -- 'mini-srd' (lowercase, literal mode value) appears at most once in the dispatcher" \
  || fail "T38 AC6 -- 'mini-srd' appears ${t38_minisrd_count} times in the dispatcher, expected at most 1"
check_absent "T38 AC6 -- 'mini-SRD Sub-Flow' section body no longer in the dispatcher" "mini-SRD Sub-Flow" "$ORCH_SKILL_T37"
check_absent "T38 AC6 -- 'Prototype Sub-Flow' section body no longer in the dispatcher" "Prototype Sub-Flow" "$ORCH_SKILL_T37"
check_absent "T38 AC6 -- 'Fast-Track / Fix-Pack Sub-Flow' section body no longer in the dispatcher" "Fast-Track / Fix-Pack Sub-Flow" "$ORCH_SKILL_T37"
check "T38 AC6 -- CLAUDE.md documents the EDM mode matrix" "## EDM mode matrix" "$(cat "${PLUGIN_DIR}/CLAUDE.md")"
check "T38 AC6 -- CLAUDE.md documents Phase Timing Guidelines" "## Phase Timing Guidelines" "$(cat "${PLUGIN_DIR}/CLAUDE.md")"

echo
echo "T38 AC7 -- resume preserved: wave5-smoke.sh (current-step / SessionStart / HANDOFF) stays green"
t38_wave5_exit=0
bash "${PLUGIN_DIR}/bin/tests/wave5-smoke.sh" >/dev/null 2>&1 || t38_wave5_exit=$?
[[ "$t38_wave5_exit" -eq 0 ]] && pass "T38 AC7 -- wave5-smoke.sh exits 0" || fail "T38 AC7 -- wave5-smoke.sh exited ${t38_wave5_exit}"

echo
echo "T38 AC8 -- current_step vocabulary defined, legacy values tolerated, mapping recorded in CHANGELOG.md"
check "T38 AC8 -- post-refactor current_step is a bare phase number" "a bare phase number" "$ORCH_SKILL_T37"
check "T38 AC8 -- legacy 2.x values named" "2.srd" "$ORCH_SKILL_T37"
check "T38 AC8 -- unrecognized current_step resumes at the start of its phase with a warning" \
  "resumes at the **start**" "$ORCH_SKILL_T37"
check "T38 AC8 -- CHANGELOG.md records the current_step mapping" "current_step" "$(cat "${PLUGIN_DIR}/CHANGELOG.md")"

echo
echo "T38 AC9 -- numbered lists in the surviving orchestrator content are strictly ascending"
t38_ac9_err="$(_wave7_check_ascending "${PLUGIN_DIR}/skills/orchestrator/SKILL.md" || true)"
[[ -z "$t38_ac9_err" ]] && pass "T38 AC9 -- orchestrator/SKILL.md numbered lists are strictly ascending" \
  || fail "T38 AC9 -- numbering defect: ${t38_ac9_err}"

echo
echo "T38 AC12 -- no phases.json / phase-graph interpreter introduced"
t38_phasesjson_count="$(grep -rl 'phases\.json' "${PLUGIN_DIR}/" 2>/dev/null | grep -v '/bin/tests/' | wc -l | tr -d ' ' || true)"
[[ "$t38_phasesjson_count" -eq 0 ]] && pass "T38 AC12 -- zero literal 'phases.json' file references anywhere in plugins/edm/ (excluding this negative-test carve-out in bin/tests/)" \
  || fail "T38 AC12 -- found ${t38_phasesjson_count} 'phases.json' reference(s)"

echo
echo "T38 AC13 -- the Phase 6 dispatcher entry invokes /edm:verify-runtime via the Skill tool"
check "T38 AC13 -- verify-runtime invoked from the Phase 6 entry" "verify-runtime" "$ORCH_SKILL_T37"

echo
echo "T38 -- full suite stays green with the dispatcher collapse in place"
# CA-094: reuses the shared whole-tree lint capture (before T66 AC12) instead of a fresh run.
_wave7_assert_shared_lint_fresh "T38 (full suite)"
[[ "$WAVE7_ALL_LINT_EXIT" -eq 0 ]] && pass "T38 -- edm-lint-artifacts --all exits 0 (captured once; CA-094)" \
  || fail "T38 -- edm-lint-artifacts --all exited ${WAVE7_ALL_LINT_EXIT} (captured once; output: ${WAVE7_ALL_LINT_OUT})"
# EDMV3-T38 end
# =================================================================================
# EDMV3-T54: update-patterns respects the Living-Library Contract, entries pending-review
# =================================================================================
# Ownership split (recorded here, not worked around silently): cmd_update_patterns
# (plugins/edm/bin/edm-state: cmd_update_patterns / _cmd_update_patterns_body /
# _splice_pattern_file / pattern_insert_line_for) was owned by a different agent in an earlier
# wave, so only the docs/contract half was assertable from this file at that time: AC13
# (README.md's Append Schema documents the pending-review marker, its provenance fields, and the
# curation lifecycle) plus the "Insertion target" mapping/never-EOF contract prose that
# AC1/AC2/AC3 are written against.
#
# CA-002 remediation (code-audit round 2): AC1-AC5, AC8, AC9 and AC10 now have real runtime
# coverage that exercises the insertion path itself -- the only pre-existing case (T42 AC9 below)
# seeds a pure duplicate, so new_findings stays 0 and the insertion path never ran. That coverage,
# plus a byte-content assertion so a concatenation-merge regression like CA-133 cannot ship
# undetected again, lives in the "CA-002 remediation" section further below, after
# `_t56_four_heading_contract_check` is defined (EDMV3-T56) -- the byte-content assertion reuses
# that helper rather than re-deriving the four-heading contract a second time.
echo
echo "=== EDMV3-T54: update-patterns Living-Library Contract + pending-review (docs/contract half) ==="
README_T54="${PLUGIN_DIR}/docs/audit-patterns/README.md"
README_T54_CONTENT="$(cat "$README_T54")"

echo "T54 AC13 -- Append Schema documents the pending-review marker and curation lifecycle"
check "T54 AC13 -- 'status: pending-review' marker documented" "status: pending-review" "$README_T54_CONTENT"
check "T54 AC13 -- provenance field 'source' documented" "source: {source-prefix}" "$README_T54_CONTENT"
check "T54 AC13 -- provenance field 'audit-type' documented" "audit-type: {srd|ticket|qc|code|test-coverage}" "$README_T54_CONTENT"
check "T54 AC13 -- provenance field 'date' documented" "date: {date}" "$README_T54_CONTENT"
check "T54 AC13 -- curation lifecycle documented (one-way, de-dup prevents re-add)" \
  "curation is one-way" "$README_T54_CONTENT"

echo
echo "T54 -- contract prose this batch owns (AC1/AC2/AC3's documented insertion contract)"
check "T54 -- default insertion target documented" \
  "\`## Anti-Patterns\` is the default target" "$README_T54_CONTENT"
check "T54 -- missing-heading skip (never EOF fallback) documented" \
  "it never falls back to appending at end-of-file" "$README_T54_CONTENT"

# EDMV3-T54 end

# =================================================================================
# EDMV3-T55: the audit gate presents pending pattern entries for human curation
# =================================================================================
# Ownership split (recorded here, not worked around silently): the presentation logic itself
# lives in skills/audit-srd/SKILL.md, skills/audit-tickets/SKILL.md and
# skills/code-audit/SKILL.md, all owned by a different agent in this wave and out of this
# batch's file remit to edit. AC1 (presented at three gates), AC2 (keep/edit/discard in one
# AskUserQuestion round) and AC4 (nothing shown when nothing is pending) require prose in those
# three files and are BLOCKED-ON-OWNER (skills/*.md) as of this commit. AC9 (MR before/after
# review) is a review artifact, not a runnable assertion, and is out of scope for this suite
# regardless of ownership (same framing as T15 AC9 above). AC3, AC5, AC6, AC7 and AC8 are
# asserted below: AC7 and AC6 are already true of the live tree (no owner dependency); AC3, AC5
# and AC8 assert the docs/contract half this batch owns -- the actual gate-time behavior these
# three prose describe is still the skills owner's to implement and is noted as such.
echo
echo "=== EDMV3-T55: gate-time curation of pending pattern entries (docs/contract half) ==="
CURATION_SECTION_T55="$(awk '/^## Curation at Gates$/{f=1;next} /^## /{f=0} f' "$README_T54")"

echo "T55 AC3 -- contract documents the three action semantics (keep/edit/discard)"
check "T55 AC3 -- Keep semantics documented" \
  "remove the \`status: pending-review\` marker; the entry is curated as-is" "$CURATION_SECTION_T55"
check "T55 AC3 -- Edit semantics documented" \
  "prompt for the one-paragraph description, then remove the marker" "$CURATION_SECTION_T55"
check "T55 AC3 -- Discard semantics documented" \
  "remove the entry from the pattern document entirely" "$CURATION_SECTION_T55"

echo
echo "T55 AC5 -- contract documents curation never blocking the gate"
check "T55 AC5 -- README states declining curation never blocks gate approval" \
  "never blocks gate approval" "$CURATION_SECTION_T55"

echo
echo "T55 AC6 -- regression guard: Gate PROTOCOL (canonical) is unchanged by this ticket"
ORCH_SKILL_T55="$(cat "${PLUGIN_DIR}/skills/orchestrator/SKILL.md")"
t55_protocol_count="$(count_matches '^## Gate PROTOCOL (canonical)$' "${PLUGIN_DIR}/skills/orchestrator/SKILL.md")"
[[ "${t55_protocol_count:-0}" -eq 1 ]] && pass "T55 AC6 -- '## Gate PROTOCOL (canonical)' still appears exactly once" \
  || fail "T55 AC6 -- '## Gate PROTOCOL (canonical)' appears ${t55_protocol_count:-0} times, expected 1"
check "T55 AC6 -- approve-gate still called only on exact Approve selection" \
  'is called ONLY when the user selects the **exact "Approve" option**' "$ORCH_SKILL_T55"
check "T55 AC6 -- free-text responses are still not approvals" "are **NOT** approvals" "$ORCH_SKILL_T55"

echo
echo "T55 AC7 -- AskUserQuestion already granted on the three curation-presenting skills"
# G26 (round-3): reuses the shared whole-tree grants capture (before T66 AC12) instead of a
# fresh run (CA-094).
_wave7_assert_shared_lint_fresh "T55 AC7"
[[ "$WAVE7_GRANTS_EXIT" -eq 0 ]] && pass "T55 AC7 -- edm-check-grants exits 0 (captured once; CA-094)" \
  || fail "T55 AC7 -- edm-check-grants exited ${WAVE7_GRANTS_EXIT} (captured once; output: ${WAVE7_GRANTS_OUT})"
for t55_gate_skill in audit-srd audit-tickets code-audit; do
  check "T55 AC7 -- ${t55_gate_skill}/SKILL.md's allowed-tools grants AskUserQuestion" \
    "AskUserQuestion" "$(grep '^allowed-tools:' "${PLUGIN_DIR}/skills/${t55_gate_skill}/SKILL.md")"
done

echo
echo "T55 AC8 -- contract documents grep-derived pending count, no state mirror (docs half)"
check "T55 AC8 -- README documents the keep/edit/discard curation contract by section name" \
  "## Curation at Gates" "$README_T54_CONTENT"
check "T55 AC8 -- README states the pending count is derived by grep, not mirrored in state" \
  "grep -c 'status: pending-review' docs/audit-patterns/*.md\` computed at read time" "$README_T54_CONTENT"
check_absent "T55 AC8 -- no 'patterns_pending' state-array token anywhere in docs/audit-patterns/" \
  "patterns_pending" "$README_T54_CONTENT"

echo
echo "T55 -- BLOCKED-ON-OWNER (skills/audit-srd, skills/audit-tickets, skills/code-audit SKILL.md):"
echo "  AC1 (presented at three gates, showing title/source prefix/target doc), AC2 (keep/edit/"
echo "  discard offered in the same AskUserQuestion round as the findings review), AC4 (nothing"
echo "  shown when nothing is pending) all require prose changes to the three skill files, out of"
echo "  this batch's file remit. Not asserted here; report these as blocked-on-owner rather than a"
echo "  false PASS or FAIL. AC9 (MR before/after review artifact) is out of scope for this suite"
echo "  regardless of ownership."
# EDMV3-T55 end

# =================================================================================
# EDMV3-T56: the four-`##` Living-Library contract becomes a CI regression guard
# =================================================================================
# Fully owned by this batch (docs/audit-patterns/*.md, wave7-smoke.sh, .gitlab-ci.yml -- no
# bin/edm-state or skills/*.md edit required). This is the authoritative four-heading contract
# check (four-heading contract check, EDMV3-T56): five documents, four `##` headings each, in
# contract order, heading 4 by regex, README.md and SOURCES.md exempt by name, no orphan `###`
# under the 4th section. .gitlab-ci.yml's lint:pattern-library-contract job runs an
# independent, minimal re-implementation of the same contract in the lint stage (mirrors, not
# re-derives -- same convention as edm-lint-artifacts, edm-check-grants and edm-check-vocabulary
# each sourcing the shared bin/_edm-lint-lib.sh as peer consumers rather than re-deriving its
# helpers, "CA-010" above); this suite's version below is the one with full negative-case
# coverage.

# _t56_four_heading_contract_check <docs-dir> -- validates the Living-Library four-`##`-heading
# contract (README.md Sec."Living-Library Contract") against every *.md file directly in
# <docs-dir>, except the two explicitly named exemptions:
#   - README.md is exempt: it is the contract document itself, not a library document.
#   - SOURCES.md is exempt: it is the provenance document (two `##` headings), neither
#     four-heading-compliant nor exempted from the four-heading contract before EDMV3-T56.
# For every other file: asserts headings 1-3 match exactly ("## Top Recurring Findings",
# "## Anti-Patterns", "## Pre-Flight Checklist"), heading 4 matches the regex
# `^## What .*Looks Like$`, there are exactly four `##` headings total (catches a 5th/orphan
# section or an unexempted third file with the wrong shape), and no `###` heading appears under
# the 4th section (catches an EOF-appended orphan, EDMV3-T54 AC3's own regression guard).
# Prints one "CONTRACT-FAIL <file>: <reason>" line per violation and returns 1 iff any
# violation was found; 0 otherwise. Read-only; never mutates the scanned tree.
_t56_four_heading_contract_check() {
  local docs_dir="$1"
  local viol=0
  local f base headings h1 h2 h3 h4 count orphan_count

  for f in "${docs_dir}"/*.md; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"

    case "$base" in
      README.md) continue ;;   # README.md is exempt: the contract document itself
      SOURCES.md) continue ;;  # SOURCES.md is exempt: the provenance document (two headings)
    esac

    headings="$(grep '^## ' "$f" || true)"
    count="$(printf '%s\n' "$headings" | grep -c '^## ' || true)"
    if [[ "${count:-0}" -ne 4 ]]; then
      echo "CONTRACT-FAIL ${base}: expected exactly 4 '##' headings, found ${count:-0}"
      viol=1
      continue
    fi

    h1="$(printf '%s\n' "$headings" | sed -n '1p')"
    h2="$(printf '%s\n' "$headings" | sed -n '2p')"
    h3="$(printf '%s\n' "$headings" | sed -n '3p')"
    h4="$(printf '%s\n' "$headings" | sed -n '4p')"

    [[ "$h1" == "## Top Recurring Findings" ]] \
      || { echo "CONTRACT-FAIL ${base}: heading 1 is '${h1}', expected '## Top Recurring Findings'"; viol=1; }
    [[ "$h2" == "## Anti-Patterns" ]] \
      || { echo "CONTRACT-FAIL ${base}: heading 2 is '${h2}', expected '## Anti-Patterns'"; viol=1; }
    [[ "$h3" == "## Pre-Flight Checklist" ]] \
      || { echo "CONTRACT-FAIL ${base}: heading 3 is '${h3}', expected '## Pre-Flight Checklist'"; viol=1; }
    if ! printf '%s' "$h4" | grep -qE '^## What .*Looks Like$'; then
      echo "CONTRACT-FAIL ${base}: heading 4 is '${h4}', expected to match regex '^## What .*Looks Like\$'"
      viol=1
    fi

    orphan_count="$(awk '/^## What /{f=1} f' "$f" | grep -c '^### ' || true)"
    if [[ "${orphan_count:-0}" -ne 0 ]]; then
      echo "CONTRACT-FAIL ${base}: ${orphan_count} '###' heading(s) found under the 4th section (orphan append)"
      viol=1
    fi
  done

  return $viol
}

echo
echo "=== EDMV3-T56: four-'##' Living-Library contract as a CI regression guard ==="
DOCS_DIR_T56="${PLUGIN_DIR}/docs/audit-patterns"

echo "T56 AC1/AC7 -- five pattern docs carry four headings in contract order (also re-verifies"
echo "  this initiative's own T42 Mermaid entries and T33 D15 entries did not break it)"
set +e
t56_live_ec=0
t56_live_out="$(_t56_four_heading_contract_check "$DOCS_DIR_T56" 2>&1)" || t56_live_ec=$?
set -e
[[ $t56_live_ec -eq 0 ]] && pass "T56 AC1/AC7 -- all five library docs pass the four-heading contract (zero CONTRACT-FAIL lines)" \
  || fail "T56 AC1/AC7 -- contract violation(s) against the live tree:\n$t56_live_out"
check_absent "T56 AC1 -- no CONTRACT-FAIL line against the live tree" "CONTRACT-FAIL" "$t56_live_out"

echo
echo "T56 AC2 -- the fourth-heading regex is documented in README.md and matches all five docs"
check "T56 AC2 -- README documents the regex '^## What .*Looks Like\$'" \
  '^## What .*Looks Like$' "$README_T54_CONTENT"
t56_ac2_all_match=1
for t56_doc in srd-audit ticket-audit code-audit test-coverage-audit qc-audit; do
  t56_h4_count="$(grep -c '^## What .*Looks Like$' "${DOCS_DIR_T56}/${t56_doc}.md" 2>/dev/null || true)"
  if [[ "${t56_h4_count:-0}" -eq 1 ]]; then
    pass "T56 AC2 -- ${t56_doc}.md's 4th heading matches the regex exactly once"
  else
    fail "T56 AC2 -- ${t56_doc}.md matched the 4th-heading regex ${t56_h4_count:-0} time(s), expected 1"
    t56_ac2_all_match=0
  fi
done
[[ "$t56_ac2_all_match" -eq 1 ]] && pass "T56 AC2 -- all five documents' fourth heading matches the sanctioned regex"

echo
echo "T56 AC3 -- negative: a fifth '##' heading fails, naming the document and the heading"
t56_ac3_case() {
  local scratch
  scratch="$(mktemp -d "${TMP}/edm-t56-ac3.XXXXXX")" || { fail "T56 AC3 -- mktemp failed"; return 1; }
  cp "${DOCS_DIR_T56}/code-audit.md" "${scratch}/code-audit.md"
  printf '\n## Unexpected Fifth Section\n\nSurprise content.\n' >> "${scratch}/code-audit.md"

  local out ec
  set +e
  ec=0
  out="$(_t56_four_heading_contract_check "$scratch" 2>&1)" || ec=$?
  set -e

  [[ $ec -ne 0 ]] && pass "T56 AC3 -- a fifth heading fails the contract check" \
    || fail "T56 AC3 -- a fifth heading did not fail the check"
  check "T56 AC3 -- failure names the document" "code-audit.md" "$out"
  check "T56 AC3 -- failure names the unexpected heading count" "expected exactly 4" "$out"

  rm -rf "$scratch"
}
t56_ac3_case

echo
echo "T56 AC4 -- both non-library documents (README.md, SOURCES.md) are explicitly exempt by name"
check "T56 AC4 -- README.md is exempt, with its reason, in the check function" \
  "README.md) continue ;;   # README.md is exempt" "$(cat "${SCRIPT_DIR}/wave7-smoke.sh")"
check "T56 AC4 -- SOURCES.md is exempt, with its reason, in the check function" \
  "SOURCES.md) continue ;;  # SOURCES.md is exempt" "$(cat "${SCRIPT_DIR}/wave7-smoke.sh")"
[[ $t56_live_ec -eq 0 ]] && pass "T56 AC4 -- the suite passes despite README.md/SOURCES.md having different heading sets" \
  || fail "T56 AC4 -- the live-tree check unexpectedly failed with the two exemptions in place"

t56_ac4_third_file_case() {
  local scratch
  scratch="$(mktemp -d "${TMP}/edm-t56-ac4.XXXXXX")" || { fail "T56 AC4 -- mktemp failed"; return 1; }
  local f
  for f in "${DOCS_DIR_T56}"/*.md; do
    cp "$f" "${scratch}/$(basename "$f")"
  done
  printf '## Scratch Heading One\n\nContent.\n\n## Scratch Heading Two\n\nContent.\n' > "${scratch}/scratch.md"

  local out ec
  set +e
  ec=0
  out="$(_t56_four_heading_contract_check "$scratch" 2>&1)" || ec=$?
  set -e

  [[ $ec -ne 0 ]] && pass "T56 AC4 -- an unexempted third file (scratch.md) fails the suite" \
    || fail "T56 AC4 -- adding scratch.md with two headings did not fail the check"
  check "T56 AC4 -- failure names scratch.md" "scratch.md" "$out"

  rm -rf "$scratch"
}
t56_ac4_third_file_case

echo
echo "T56 AC5 -- negative: a stray orphan '### ' heading after the last section's boundary fails"
t56_ac5_case() {
  local scratch
  scratch="$(mktemp -d "${TMP}/edm-t56-ac5.XXXXXX")" || { fail "T56 AC5 -- mktemp failed"; return 1; }
  cp "${DOCS_DIR_T56}/code-audit.md" "${scratch}/code-audit.md"
  printf '\n### Orphan\n\nThis should never land here.\n' >> "${scratch}/code-audit.md"

  local out ec
  set +e
  ec=0
  out="$(_t56_four_heading_contract_check "$scratch" 2>&1)" || ec=$?
  set -e

  [[ $ec -ne 0 ]] && pass "T56 AC5 -- a stray '### Orphan' after the last section fails the check" \
    || fail "T56 AC5 -- appending '### Orphan' did not fail the check"
  check "T56 AC5 -- failure names the orphan-append condition" "orphan append" "$out"

  rm -rf "$scratch"
}
t56_ac5_case

echo
echo "T56 AC6 -- runs in the CI lint stage; coordination point for future update-patterns cases"
check "T56 AC6 -- .gitlab-ci.yml runs the pattern-library contract check in the lint stage" \
  "lint:pattern-library-contract" "$(cat "$GITLAB_CI_YML")"
check "T56 AC6 -- wave7-smoke.sh runs the contract check as part of the test stage" \
  "_t56_four_heading_contract_check" "$(cat "${SCRIPT_DIR}/wave7-smoke.sh")"
echo "  NOTE: EDMV3-T54's own update-patterns test cases, in the CA-002 remediation section"
echo "  immediately below, call _t56_four_heading_contract_check again after each"
echo "  update-patterns invocation, per this AC6 coordination point."

echo
echo "T56 AC8 -- the ten-update-patterns-runs case: repeated insertion never regresses the"
echo "  four-heading contract, checked after every single run rather than only at the end"
t56_ac8_case() {
  local scratch
  scratch="$(mktemp -d "${TMP}/edm-t56-ac8.XXXXXX")" || { fail "T56 AC8 -- mktemp failed"; return 1; }
  mkdir -p "$scratch/plugins/edm"
  cp -R "${PLUGIN_DIR}/." "$scratch/plugins/edm/"
  local scratch_docs="$scratch/plugins/edm/docs/audit-patterns"
  local scratch_code="$scratch_docs/code-audit.md"

  mkdir -p "$scratch/work/SRD/ZCA8"
  echo '{}' > "$scratch/work/SRD/ZCA8/.edm-state.json"
  mkdir -p "$scratch/work/SRD/ZCA8/code-audit/pass-1_2026-07-31"

  local i out ec all_ok=1
  for i in 1 2 3 4 5 6 7 8 9 10; do
    {
      echo "# Mock Code Audit REMEDIATION"
      echo
      echo "### T56 AC8 run ${i} novel finding"
      echo "Run ${i} of ten, proving repeated insertion never regresses the contract."
    } > "$scratch/work/SRD/ZCA8/code-audit/pass-1_2026-07-31/REMEDIATION.md"

    out="$(EDM_SRD_ROOT="$scratch/work/SRD" bash "$scratch/plugins/edm/bin/edm-state" update-patterns ZCA8 code 2>&1)"
    [[ "$out" == *"1 new finding(s) appended"* ]] || { fail "T56 AC8 -- run ${i} did not append its novel finding (got: $out)"; all_ok=0; }

    set +e
    _t56_four_heading_contract_check "$scratch_docs" >/dev/null 2>&1
    ec=$?
    set -e
    [[ $ec -eq 0 ]] || { fail "T56 AC8 -- four-heading contract violated after run ${i}"; all_ok=0; }
  done

  [[ "$all_ok" -eq 1 ]] \
    && pass "T56 AC8 -- ten consecutive update-patterns runs each appended exactly one entry and never broke the four-heading contract" \
    || fail "T56 AC8 -- at least one of the ten runs failed (see FAIL lines above)"

  local final_heading_count
  final_heading_count="$(grep -c '^### T56 AC8 run ' "$scratch_code" || true)"
  [[ "${final_heading_count:-0}" -eq 10 ]] \
    && pass "T56 AC8 -- all ten distinct entries are present in the final document" \
    || fail "T56 AC8 -- expected 10 distinct run entries, found ${final_heading_count:-0}"

  rm -rf "$scratch"
}
t56_ac8_case
# EDMV3-T56 end

# =================================================================================
# CA-002 remediation (code-audit round 2): cmd_update_patterns insertion-path coverage
# =================================================================================
# CA-002 (P0): the only pre-existing insertion-path test (T42 AC9 above) seeds a pure
# duplicate, so new_findings stays 0 and cmd_update_patterns / _cmd_update_patterns_body /
# _splice_pattern_file / pattern_insert_line_for never actually run their insertion branch. The
# two cases below exercise that branch for real, against a scratch copy of the whole plugin
# invoked by explicit path (the t30_ac2_case pattern) rather than with_scratch_repo + a bare
# `edm-state` call -- with_scratch_repo prepends the REAL plugins/edm/bin to PATH, and
# cmd_update_patterns resolves docs/audit-patterns/ relative to SCRIPT_DIR (G39, round-3 Wave
# 7g-1: previously $0's directory, which broke under `source`; direct execution -- as every
# call in this file uses -- leaves BASH_SOURCE[0] and $0 identical, so this note's practical
# conclusion is unchanged), so a bare call
# under with_scratch_repo would write into this repository's own committed pattern-library docs.
echo
echo "=== CA-002 remediation: cmd_update_patterns insertion path (T54 AC1/AC2/AC3/AC4/AC5/AC8/AC9/AC10) ==="

ca002_insertion_case() {
  local scratch
  scratch="$(mktemp -d "${TMP}/edm-ca002-ins.XXXXXX")" || { fail "CA-002 -- mktemp failed"; return 1; }
  mkdir -p "$scratch/plugins/edm"
  cp -R "${PLUGIN_DIR}/." "$scratch/plugins/edm/"
  local scratch_docs="$scratch/plugins/edm/docs/audit-patterns"
  local scratch_srd="$scratch_docs/srd-audit.md"
  local scratch_srd_root="$scratch/work/SRD"

  mkdir -p "${scratch_srd_root}/ZCA2"
  {
    echo "# Mock SRD Audit"
    echo
    echo "### CA002 novel finding one"
    echo "First novel finding for the insertion-path regression test."
    echo
    echo "### CA002 novel finding two"
    echo "Second novel finding for the insertion-path regression test."
    echo
    echo "### literal semicolon inside a mermaid label"
    echo "Duplicate-titled finding (normalized case-insensitive match) to prove de-duplication"
    echo "still skips it on the insertion path, not just on the pure-duplicate path T42 AC9 covers."
  } > "${scratch_srd_root}/ZCA2/audit-srd.md"
  echo '{}' > "${scratch_srd_root}/ZCA2/.edm-state.json"

  local before_heading_count after_heading_count out1 out2
  before_heading_count="$(grep -c '^### ' "$scratch_srd")"

  out1="$(EDM_SRD_ROOT="$scratch_srd_root" bash "$scratch/plugins/edm/bin/edm-state" update-patterns ZCA2 srd 2>&1)"
  [[ "$out1" == *"2 new finding(s) appended"* ]] \
    && pass "CA-002 AC1 -- two novel findings are appended through the real insertion path" \
    || fail "CA-002 AC1 -- expected '2 new finding(s) appended', got: $out1"

  after_heading_count="$(grep -c '^### ' "$scratch_srd")"
  [[ "$((after_heading_count - before_heading_count))" -eq 2 ]] \
    && pass "CA-002 AC1 -- exactly two '### ' headings were added (${before_heading_count} -> ${after_heading_count})" \
    || fail "CA-002 AC1 -- expected +2 '### ' headings, got ${before_heading_count} -> ${after_heading_count}"

  check "CA-002 AC1 -- first novel title landed as a '### ' heading" \
    "### CA002 novel finding one" "$(cat "$scratch_srd")"
  check "CA-002 AC1 -- second novel title landed as a '### ' heading" \
    "### CA002 novel finding two" "$(cat "$scratch_srd")"

  local anti_patterns_section
  anti_patterns_section="$(awk '/^## Anti-Patterns$/{f=1;next} /^## /{f=0} f' "$scratch_srd")"
  check "CA-002 AC1 -- first novel entry lands inside '## Anti-Patterns', not some other section" \
    "### CA002 novel finding one" "$anti_patterns_section"
  check "CA-002 AC1 -- second novel entry lands inside '## Anti-Patterns', not some other section" \
    "### CA002 novel finding two" "$anti_patterns_section"

  local dup_original_count
  dup_original_count="$(grep -c '^### Literal semicolon inside a Mermaid label$' "$scratch_srd" || true)"
  [[ "${dup_original_count:-0}" -eq 1 ]] \
    && pass "CA-002 AC5 -- the pre-existing entry the mock report duplicates still appears exactly once" \
    || fail "CA-002 AC5 -- pre-existing duplicate-titled entry appears ${dup_original_count:-0} time(s), expected 1"
  check_absent "CA-002 AC5 -- the duplicate was skipped, not re-appended under its report-side casing" \
    "### literal semicolon inside a mermaid label" "$(cat "$scratch_srd")"

  local pending_count
  pending_count="$(grep -c 'status: pending-review' "$scratch_srd" || true)"
  [[ "${pending_count:-0}" -eq 2 ]] \
    && pass "CA-002 AC9 -- both auto-appended entries carry the pending-review marker" \
    || fail "CA-002 AC9 -- found ${pending_count:-0} pending-review marker(s), expected 2"

  check "CA-002 AC10 -- appended stub text is delimited, not disguised as curated prose" \
    "delimited stub text pending human curation; not yet curated prose" "$(cat "$scratch_srd")"

  # Byte-content assertion (CA-002's central point): a presence-only check is exactly what let
  # CA-133's concatenation-merge regression ship undetected. Reuse the authoritative four-heading
  # contract check (_t56_four_heading_contract_check, defined above under EDMV3-T56) against this
  # scratch docs dir -- it fails loudly if the appended block ran the trailing '## Pre-Flight
  # Checklist' boundary heading onto the same physical line as an entry's last line (heading
  # count drops below 4) or left an orphan '### ' heading stranded past the fourth section.
  local t_ca002_contract_out t_ca002_contract_ec
  set +e
  t_ca002_contract_ec=0
  t_ca002_contract_out="$(_t56_four_heading_contract_check "$scratch_docs" 2>&1)" || t_ca002_contract_ec=$?
  set -e
  [[ $t_ca002_contract_ec -eq 0 ]] \
    && pass "CA-002 AC3 -- the four-heading contract still holds after insertion (no heading/content concatenation-merge, no orphan section)" \
    || fail "CA-002 AC3 -- four-heading contract violated after insertion: $t_ca002_contract_out"
  check_absent "CA-002 -- appended prose never runs directly into the next '##' boundary heading (no dropped newline)" \
    "curated prose.## " "$(cat "$scratch_srd")"

  check "CA-002 AC8 -- patterns_updates records this audit type in state on the insertion path" \
    '"srd"' "$(cat "${scratch_srd_root}/ZCA2/.edm-state.json")"
  local ca002_new_findings_recorded
  ca002_new_findings_recorded="$(jq -r '.patterns_updates.srd.new_findings' "${scratch_srd_root}/ZCA2/.edm-state.json" 2>/dev/null)"
  [[ "$ca002_new_findings_recorded" == "2" ]] \
    && pass "CA-002 AC8 -- state records new_findings=2 for this run" \
    || fail "CA-002 AC8 -- state's patterns_updates.srd.new_findings is '${ca002_new_findings_recorded}', expected '2'"

  # AC4: idempotent under repetition -- an immediate second run against the SAME audit report
  # (all three titles are now already present as '### ' headings: two from this run, one
  # pre-existing) appends nothing further.
  out2="$(EDM_SRD_ROOT="$scratch_srd_root" bash "$scratch/plugins/edm/bin/edm-state" update-patterns ZCA2 srd 2>&1)"
  [[ "$out2" == *"no novel findings to append"* ]] \
    && pass "CA-002 AC4 -- a second identical run appends nothing further (idempotent)" \
    || fail "CA-002 AC4 -- second run did not report 'no novel findings to append' (got: $out2)"

  local after_second_heading_count
  after_second_heading_count="$(grep -c '^### ' "$scratch_srd")"
  [[ "$after_second_heading_count" -eq "$after_heading_count" ]] \
    && pass "CA-002 AC4 -- '### ' heading count is unchanged by the second run (${after_second_heading_count})" \
    || fail "CA-002 AC4 -- '### ' heading count changed on the second run (${after_heading_count} -> ${after_second_heading_count})"

  set +e
  t_ca002_contract_ec=0
  t_ca002_contract_out="$(_t56_four_heading_contract_check "$scratch_docs" 2>&1)" || t_ca002_contract_ec=$?
  set -e
  [[ $t_ca002_contract_ec -eq 0 ]] \
    && pass "CA-002 AC3/T56 AC6 -- four-heading contract still holds after the repeat run" \
    || fail "CA-002 AC3/T56 AC6 -- four-heading contract violated after the repeat run: $t_ca002_contract_out"

  rm -rf "$scratch"
}
ca002_insertion_case

echo
echo "CA-002 AC2 -- a missing target heading is a skip (nothing appended, no end-of-file fallback), never an error"
ca002_missing_heading_case() {
  local scratch
  scratch="$(mktemp -d "${TMP}/edm-ca002-missing-heading.XXXXXX")" || { fail "CA-002 AC2 -- mktemp failed"; return 1; }
  mkdir -p "$scratch/plugins/edm"
  cp -R "${PLUGIN_DIR}/." "$scratch/plugins/edm/"
  local scratch_srd="$scratch/plugins/edm/docs/audit-patterns/srd-audit.md"
  local scratch_srd_root="$scratch/work/SRD"

  # Remove the '## Anti-Patterns' target heading entirely -- the default insertion target can no
  # longer be found.
  sed -i.bak '/^## Anti-Patterns$/d' "$scratch_srd"
  rm -f "${scratch_srd}.bak"

  mkdir -p "${scratch_srd_root}/ZCA4"
  {
    echo "# Mock SRD Audit"
    echo
    echo "### CA002 AC2 novel finding"
    echo "Would be appended if a target heading existed."
  } > "${scratch_srd_root}/ZCA4/audit-srd.md"
  echo '{}' > "${scratch_srd_root}/ZCA4/.edm-state.json"

  local before_hash after_hash out status
  before_hash="$(_harness_hash_file "$scratch_srd")"

  status=0
  out="$(EDM_SRD_ROOT="$scratch_srd_root" bash "$scratch/plugins/edm/bin/edm-state" update-patterns ZCA4 srd 2>&1)" || status=$?
  after_hash="$(_harness_hash_file "$scratch_srd")"

  [[ "$status" -eq 0 ]] \
    && pass "CA-002 AC2 -- a missing target heading exits 0 (a skip, never an error)" \
    || fail "CA-002 AC2 -- expected exit 0 on a missing target heading, got $status"

  check "CA-002 AC2 -- skip message names the file and states no end-of-file fallback" \
    "skipping (nothing appended, no end-of-file fallback)" "$out"

  [[ "$before_hash" == "$after_hash" ]] \
    && pass "CA-002 AC2 -- the document is byte-identical before and after the skip" \
    || fail "CA-002 AC2 -- document hash changed on a skip (before=$before_hash after=$after_hash)"

  rm -rf "$scratch"
}
ca002_missing_heading_case
# CA-002 remediation end

# =================================================================================
# CA-007 remediation (code-audit round 2): porcelain rename/copy containment parsing
# =================================================================================
# CA-007 (P1): run-eval.sh's containment check read `${line:3}` as the path unconditionally,
# but `git status --porcelain` emits a rename/copy as `R  <old> -> <new>` (or `C  ...`), so
# `${line:3}` yielded the OLD path concatenated with " -> " and the NEW path -- a rename whose
# destination escapes SRD/ still matched the `SRD/*` glob and was scored as contained. The fix
# reproduces run-eval.sh's exact fixed parsing loop against real `git status --porcelain` output
# from a scratch git repo (not by invoking run-eval.sh itself, which requires a live
# ANTHROPIC_API_KEY for its `claude -p` phases -- out of scope for a smoke suite).
echo
echo "=== CA-007 remediation: porcelain rename/copy containment parsing (EDMV3-93 AC9) ==="

ca007_containment_case() {
  local scratch
  scratch="$(mktemp -d "${TMP}/edm-ca007-containment.XXXXXX")" || { fail "CA-007 -- mktemp failed"; return 1; }
  ( cd "$scratch" && git init -q && git config user.email t@t && git config user.name t )
  mkdir -p "$scratch/SRD"
  echo "one" > "$scratch/SRD/x.md"
  ( cd "$scratch" && git add SRD/x.md && git commit -qm init )

  # Case 1: a rename whose destination stays under SRD/ -- contained, no violation.
  ( cd "$scratch" && git mv SRD/x.md SRD/y.md )
  local porcelain1 violations1
  porcelain1="$(cd "$scratch" && git status --porcelain)"
  violations1="$(_ca007_containment_violations "$porcelain1")"
  [[ -z "$violations1" ]] \
    && pass "CA-007 -- a rename staying under SRD/ is still scored as contained (no false positive)" \
    || fail "CA-007 -- a contained rename was wrongly flagged: $violations1"

  # Case 2: a rename whose destination escapes SRD/ but stays inside the scratch tree/repo
  # (the actual shape run-eval.sh's containment check guards against -- a phase writing
  # outside SRD/ within the same scratch repo, not literally outside the filesystem repo,
  # which git refuses to track at all) -- must be a violation (the CA-007 bug).
  ( cd "$scratch" && git mv SRD/y.md escape.md )
  local porcelain2 violations2
  porcelain2="$(cd "$scratch" && git status --porcelain)"
  violations2="$(_ca007_containment_violations "$porcelain2")"
  [[ -n "$violations2" ]] \
    && pass "CA-007 -- a rename whose destination escapes SRD/ is caught as a containment violation" \
    || fail "CA-007 -- an escaping rename went undetected (the pre-fix bug this finding names)"

  rm -rf "$scratch"
}

# Reproduces run-eval.sh:443-460's fixed containment loop verbatim, so a future edit to one and
# not the other is caught the next time this test runs against a real regression scenario.
_ca007_containment_violations() {
  local containment_output="$1" line xy path violations=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    xy="${line%%"${line#??}"}"
    path="${line:3}"
    case "$xy" in
      R*|C*) path="${path##* -> }" ;;
    esac
    case "$path" in
      SRD/*) ;;
      *) violations="${violations}${line}
" ;;
    esac
  done <<CONTAINMENT_EOF
${containment_output}
CONTAINMENT_EOF
  echo "$violations"
}
ca007_containment_case
# CA-007 remediation end

# =================================================================================
# EDMV3-T52 AC7: CLAUDE.md pricing table matches script constants (cannot drift)
# =================================================================================
echo
echo "T52 AC7 -- CLAUDE.md pricing table matches script constants"

CLAUDE_MD_T52="${PLUGIN_DIR}/CLAUDE.md"
EDM_STATE_BIN_T52="${PLUGIN_DIR}/bin/edm-state"

# _t52_script_rate <env-var-name> -- the single-source default value baked into compute_cost_usd
# for that override variable, extracted directly from the script rather than re-typed by hand.
_t52_script_rate() {
  grep -oE "${1}:-[0-9.]+" "$EDM_STATE_BIN_T52" | head -1 | sed -E 's/.*:-//'
}

# _t52_md_cell <model-label> <column-index-1-based-after-model> -- the numeric value (dollar
# sign and header/separator rows stripped) from CLAUDE.md's pricing table row for <model-label>.
_t52_md_cell() {
  local label="$1" col="$2"
  grep -F "| ${label} |" "$CLAUDE_MD_T52" | head -1 \
    | awk -F'|' -v c="$col" '{gsub(/^[ \t$]+|[ \t]+$/, "", $(c+2)); print $(c+2)}'
}

t52_pricing_pairs=(
  "EDM_OPUS_INPUT_RATE:Opus 4.8:1"
  "EDM_OPUS_OUTPUT_RATE:Opus 4.8:2"
  "EDM_OPUS_CACHE_READ_RATE:Opus 4.8:3"
  "EDM_OPUS_CACHE_WRITE_5M_RATE:Opus 4.8:4"
  "EDM_OPUS_CACHE_WRITE_1H_RATE:Opus 4.8:5"
  "EDM_SONNET_INPUT_RATE:Sonnet 4.7:1"
  "EDM_SONNET_OUTPUT_RATE:Sonnet 4.7:2"
  "EDM_SONNET_CACHE_READ_RATE:Sonnet 4.7:3"
  "EDM_SONNET_CACHE_WRITE_5M_RATE:Sonnet 4.7:4"
  "EDM_SONNET_CACHE_WRITE_1H_RATE:Sonnet 4.7:5"
  "EDM_HAIKU_INPUT_RATE:Haiku 4.6:1"
  "EDM_HAIKU_OUTPUT_RATE:Haiku 4.6:2"
  "EDM_HAIKU_CACHE_READ_RATE:Haiku 4.6:3"
  "EDM_HAIKU_CACHE_WRITE_5M_RATE:Haiku 4.6:4"
  "EDM_HAIKU_CACHE_WRITE_1H_RATE:Haiku 4.6:5"
)
for t52_pair in "${t52_pricing_pairs[@]}"; do
  t52_var="${t52_pair%%:*}"
  t52_rest="${t52_pair#*:}"
  t52_label="${t52_rest%:*}"
  t52_col="${t52_rest##*:}"
  t52_script_val="$(_t52_script_rate "$t52_var")"
  t52_md_val="$(_t52_md_cell "$t52_label" "$t52_col")"
  [[ "$t52_script_val" == "$t52_md_val" ]] \
    && pass "T52 AC7 -- ${t52_var} matches CLAUDE.md ${t52_label} column ${t52_col} (both ${t52_script_val})" \
    || fail "T52 AC7 -- ${t52_var} mismatch: script=${t52_script_val}, CLAUDE.md ${t52_label} column ${t52_col}=${t52_md_val}"
done

# =================================================================================
# EDMV3-T45: communication cadence and deliverable-length calibration
# =================================================================================
echo
echo "=== EDMV3-T45: communication cadence and deliverable-length calibration ==="

ORCH_SKILL_T45="$(cat "${PLUGIN_DIR}/skills/orchestrator/SKILL.md")"

# CA-102/CA-099: _wave7_extract_section and _wave7_extract_between moved to _harness.sh (still
# under their original names for continuity with prior audit findings) so every suite can reuse
# them, not just this one call site -- see _harness.sh for the definitions.

echo
echo "T45 AC1 -- orchestrator gains a top-level '## Communication' section"
check "T45 AC1 -- '## Communication' heading present" "## Communication" "$ORCH_SKILL_T45"

echo
echo "T45 AC2 -- <tone_preference> reminder placed after the Anti-Patterns heading"
t45_antipatterns_line="$({ grep -n '^## Anti-Patterns$' "${PLUGIN_DIR}/skills/orchestrator/SKILL.md" || true; } | head -1 | cut -d: -f1)"
t45_tonepref_line="$({ grep -n '<tone_preference>' "${PLUGIN_DIR}/skills/orchestrator/SKILL.md" || true; } | head -1 | cut -d: -f1)"
if [[ -n "$t45_antipatterns_line" && -n "$t45_tonepref_line" && "$t45_tonepref_line" -gt "$t45_antipatterns_line" ]]; then
  pass "T45 AC2 -- <tone_preference> (line ${t45_tonepref_line}) follows Anti-Patterns (line ${t45_antipatterns_line})"
else
  fail "T45 AC2 -- <tone_preference> line ${t45_tonepref_line:-absent} does not follow Anti-Patterns line ${t45_antipatterns_line:-absent}"
fi

echo
echo "T45 AC3 -- orchestrator at most 300 lines"
t45_orch_lines="$(wc -l < "${PLUGIN_DIR}/skills/orchestrator/SKILL.md" | tr -d ' ')"
[[ "$t45_orch_lines" -le 300 ]] && pass "T45 AC3 -- orchestrator at most 300 lines (${t45_orch_lines})" \
  || fail "T45 AC3 -- orchestrator/SKILL.md is ${t45_orch_lines} lines, expected <= 300"

echo
echo "T45 AC4 -- Communication section mentions no artifact"
t45_comm_body="$(_wave7_extract_section "${PLUGIN_DIR}/skills/orchestrator/SKILL.md" "Communication")"
t45_tonepref_body="$(awk '/<tone_preference>/{f=1;next} /<\/tone_preference>/{f=0} f' "${PLUGIN_DIR}/skills/orchestrator/SKILL.md")"
t45_ac4_bad=""
for t45_word in "srd.md" "artifact" "deliverable"; do
  printf '%s' "$t45_comm_body" | grep -qi -- "$t45_word" && t45_ac4_bad="${t45_ac4_bad} comm:${t45_word}"
  printf '%s' "$t45_tonepref_body" | grep -qi -- "$t45_word" && t45_ac4_bad="${t45_ac4_bad} tone:${t45_word}"
done
[[ -z "$t45_ac4_bad" ]] && pass "T45 AC4 -- Communication section mentions no artifact (and <tone_preference> is clean too)" \
  || fail "T45 AC4 -- forbidden word(s) found:${t45_ac4_bad}"

echo
echo "T45 AC5 -- correction-narration guidance present"
check "T45 AC5 -- 'change the user' present" "change the user" "$ORCH_SKILL_T45"

echo
echo "T45 AC6 -- no interim-progress scaffolding introduced"
t45_ac6_hits="$(grep -rn -i 'every [0-9]* tool calls\|summarize every' "${PLUGIN_DIR}/skills/" 2>/dev/null || true)"
[[ -z "$t45_ac6_hits" ]] && pass "T45 AC6 -- no 'every N tool calls' / 'summarize every' scaffolding in skills/" \
  || fail "T45 AC6 -- found scaffolding text: ${t45_ac6_hits}"

echo
echo "T45 AC7 -- length floors preserved verbatim"
check "T45 AC7 -- edm-srd-writer.md floor unchanged" "800+ lines for major initiative, 200+ for focused feature, 50+ for small change" \
  "$(cat "${PLUGIN_DIR}/agents/edm-srd-writer.md")"
check "T45 AC7 -- skills/srd/SKILL.md floor unchanged" "800+ lines major, 200+ focused, 50+ small change" \
  "$(cat "${PLUGIN_DIR}/skills/srd/SKILL.md")"

echo
echo "T45 AC8 -- anti-padding clause on both floor sites"
check "T45 AC8 -- edm-srd-writer.md carries anti-padding clause" "do not pad with filler" \
  "$(cat "${PLUGIN_DIR}/agents/edm-srd-writer.md")"
check "T45 AC8 -- skills/srd/SKILL.md carries anti-padding clause" "do not pad with filler" \
  "$(cat "${PLUGIN_DIR}/skills/srd/SKILL.md")"

echo
echo "T45 AC9 -- identical deliverable-length clause on the eight file-writing agents"
t45_ac9_unique="$(grep -rho 'match the length of the document to what the task needs' "${PLUGIN_DIR}/agents/" | sort -u | wc -l | tr -d ' ')" || true
[[ "$t45_ac9_unique" -eq 1 ]] && pass "T45 AC9 -- exactly one unique phrasing of the deliverable-length clause" \
  || fail "T45 AC9 -- ${t45_ac9_unique} unique phrasings found, expected 1"
# NOTE: -rl (no -c) is used deliberately, not the AC's literal '-rlc' -- BSD grep (macOS,
# EDMV3-106 divergence) prints both a "file:count" line AND a bare filename line when -l and -c
# are combined, doubling the count; GNU grep gives -l precedence and would return 8 either way.
# -rl alone is portable and correct on both.
t45_ac9_files="$(grep -rl 'match the length of the document' "${PLUGIN_DIR}/agents/" | wc -l | tr -d ' ')" || true
[[ "$t45_ac9_files" -eq 8 ]] && pass "T45 AC9 -- exactly eight agent files carry the clause" \
  || fail "T45 AC9 -- ${t45_ac9_files} agent files carry the clause, expected 8"

echo
echo "T45 AC10 -- length clause absent from the Communication section"
if printf '%s' "$t45_comm_body" | grep -q 'match the length of the document'; then
  fail "T45 AC10 -- Communication section contains the deliverable-length clause"
else
  pass "T45 AC10 -- Communication section never mentions the deliverable-length clause"
fi
if printf '%s' "$t45_tonepref_body" | grep -q 'match the length of the document'; then
  fail "T45 AC10 -- <tone_preference> block contains the deliverable-length clause"
else
  pass "T45 AC10 -- <tone_preference> block never mentions the deliverable-length clause"
fi

# CA-094: the shared whole-tree lint/grants capture now lives far above (before T66 AC12, its
# earliest potential consumer) alongside `_wave7_assert_shared_lint_fresh`. T45, T46, T47, T49
# and T48 below still each close with their own separately-named "full suite stays green" case
# (AC-traceability preserved), but all reuse that single capture instead of re-running it.
_wave7_assert_shared_lint_fresh "T45"

echo
echo "T45 -- full suite stays green with the cadence/length additions in place"
[[ "$WAVE7_GRANTS_EXIT" -eq 0 ]] && pass "T45 -- edm-check-grants exits 0 (captured once; CA-094)" \
  || fail "T45 -- edm-check-grants exited ${WAVE7_GRANTS_EXIT} (captured once; output: ${WAVE7_GRANTS_OUT})"
[[ "$WAVE7_ALL_LINT_EXIT" -eq 0 ]] && pass "T45 -- edm-lint-artifacts --all exits 0" \
  || fail "T45 -- edm-lint-artifacts --all exited ${WAVE7_ALL_LINT_EXIT} (captured once; output: ${WAVE7_ALL_LINT_OUT})"
# EDMV3-T45 end

# =================================================================================
# EDMV3-T46: agent scope, output contracts, decision ladder, and N/A carve-outs
# =================================================================================
echo
echo "=== EDMV3-T46: agent scope, output contracts, decision ladder, and N/A carve-outs ==="

T46_LENSES="edm-audit-consistency edm-audit-dead-code edm-audit-docs edm-audit-dry edm-audit-edge-cases edm-audit-logic edm-audit-runtime edm-audit-security edm-audit-spec edm-audit-test-quality edm-audit-wiring"
T46_SCOPE13="edm-explorer edm-audit-synthesizer $T46_LENSES"
T46_OUTPUT10="edm-implementer edm-test-unit edm-test-component edm-test-composable edm-test-integration edm-test-contract edm-test-e2e edm-test-a11y edm-test-scaffold edm-test-planner"

echo
echo "T46 AC1 -- thirteen occurrences of the scope line"
t46_scope_count=0
t46_scope_missing=""
for t46_a in $T46_SCOPE13; do
  if grep -q '^## Scope$' "${PLUGIN_DIR}/agents/${t46_a}.md"; then
    t46_scope_count=$((t46_scope_count + 1))
  else
    t46_scope_missing="${t46_scope_missing} ${t46_a}"
  fi
done
[[ "$t46_scope_count" -eq 13 && -z "$t46_scope_missing" ]] && pass "T46 AC1 -- thirteen occurrences of the scope line (all thirteen agents)" \
  || fail "T46 AC1 -- found ${t46_scope_count}/13, missing:${t46_scope_missing}"
t46_scope_unique="$(grep -rho 'deliver what was asked at the scope intended' "${PLUGIN_DIR}/agents/" | sort -u | wc -l | tr -d ' ')" || true
[[ "$t46_scope_unique" -eq 1 ]] && pass "T46 AC1 -- exactly one unique phrasing of the scope line" \
  || fail "T46 AC1 -- ${t46_scope_unique} unique phrasings found, expected 1"

echo
echo "T46 AC2 -- False Alarm Filter criteria count unchanged (three per lens, all eleven lenses)"
t46_faf_bad=""
for t46_l in $T46_LENSES; do
  t46_faf_cnt="$(awk '/^## False Alarm Filter/{f=1;next} /^## /{f=0} f' "${PLUGIN_DIR}/agents/${t46_l}.md" | grep -c '^[0-9]\+\.' || true)"
  [[ "${t46_faf_cnt:-0}" -eq 3 ]] || t46_faf_bad="${t46_faf_bad} ${t46_l}=${t46_faf_cnt:-0}"
done
[[ -z "$t46_faf_bad" ]] && pass "T46 AC2 -- all eleven lenses still carry exactly three False Alarm Filter criteria" \
  || fail "T46 AC2 -- unexpected criteria count(s):${t46_faf_bad}"

echo
echo "T46 AC3 -- ten agents contain an '## Output' section"
t46_out_count=0
t46_out_missing=""
for t46_a in $T46_OUTPUT10; do
  if grep -q '^## Output$' "${PLUGIN_DIR}/agents/${t46_a}.md"; then
    t46_out_count=$((t46_out_count + 1))
  else
    t46_out_missing="${t46_out_missing} ${t46_a}"
  fi
done
[[ "$t46_out_count" -eq 10 && -z "$t46_out_missing" ]] && pass "T46 AC3 -- ten agents contain an '## Output' section" \
  || fail "T46 AC3 -- found ${t46_out_count}/10, missing:${t46_out_missing}"

echo
echo "T46 AC4 -- write-path class documented (edm-test-unit) and edm-check-grants clean"
check "T46 AC4 -- 'detected test root' present in edm-test-unit.md" "detected test root" \
  "$(cat "${PLUGIN_DIR}/agents/edm-test-unit.md")"
# G26 (round-3): reuses the shared whole-tree grants capture (before T66 AC12) instead of a
# fresh run (CA-094).
_wave7_assert_shared_lint_fresh "T46 AC4"
[[ "$WAVE7_GRANTS_EXIT" -eq 0 ]] && pass "T46 AC4 -- edm-check-grants exits 0 (captured once; CA-094)" \
  || fail "T46 AC4 -- edm-check-grants exited ${WAVE7_GRANTS_EXIT} (captured once; output: ${WAVE7_GRANTS_OUT})"

echo
echo "T46 AC6 -- generalization stated literally in edm-implementer.md"
t46_ac6_cnt="$(grep -c 'every item, not just the first' "${PLUGIN_DIR}/agents/edm-implementer.md" || true)"
[[ "${t46_ac6_cnt:-0}" -gt 0 ]] && pass "T46 AC6 -- 'every item, not just the first' present (${t46_ac6_cnt}x)" \
  || fail "T46 AC6 -- phrase absent from edm-implementer.md"

echo
echo "T46 AC7/AC8 -- Core Rules is a numbered, stop-at-first-rung ladder bound to ticket understanding"
check "T46 AC7 -- 'stop at the first rung that holds' present" "stop at the first rung that holds" \
  "$(cat "${PLUGIN_DIR}/agents/edm-implementer.md")"
check "T46 AC8 -- 'after the ticket is understood' present" "after the ticket is understood" \
  "$(cat "${PLUGIN_DIR}/agents/edm-implementer.md")"
check "T46 AC8 -- 'never a rung' present" "never a rung" \
  "$(cat "${PLUGIN_DIR}/agents/edm-implementer.md")"

echo
echo "T46 AC10 -- carve-out section present in all 30 agent files, exact heading and file count"
t46_ac10_missing=""
t46_ac10_count=0
for t46_f in "${PLUGIN_DIR}"/agents/*.md; do
  if grep -q '^## When this does NOT apply$' "$t46_f"; then
    t46_ac10_count=$((t46_ac10_count + 1))
  else
    t46_ac10_missing="${t46_ac10_missing} $(basename "$t46_f")"
  fi
done
t46_ac10_total="$(ls "${PLUGIN_DIR}"/agents/*.md | wc -l | tr -d ' ')"
[[ "$t46_ac10_count" -eq 30 && "$t46_ac10_total" -eq 30 && -z "$t46_ac10_missing" ]] && pass "T46 AC10 -- all 30 agent files carry the carve-out heading" \
  || fail "T46 AC10 -- ${t46_ac10_count}/${t46_ac10_total} carry it, missing:${t46_ac10_missing}"

echo
echo "T46 AC12 -- N/A behaviour cross-referenced, not restated, in agents/"
t46_ac12_pattern='recomputed each run'
t46_ac12_agents_files="$(grep -rl "$t46_ac12_pattern" "${PLUGIN_DIR}/agents/" 2>/dev/null || true)"
# G20 (round-3): positive control -- the identical grep -l invocation against CLAUDE.md (the
# documented single source for this phrase, asserted right below) proves the pattern still
# matches a file that legitimately contains it, so the empty agents/ result is a real absence.
# G2/CA-037 residual (round 5): one shared pattern variable, not two independently-typed copies.
t46_ac12_control_files="$(grep -l "$t46_ac12_pattern" "${PLUGIN_DIR}/CLAUDE.md" 2>/dev/null || true)"
if [[ -z "$t46_ac12_control_files" ]]; then
  fail "T46 AC12 -- positive control broken: CLAUDE.md no longer contains 'recomputed each run'"
else
  [[ -z "$t46_ac12_agents_files" ]] && pass "T46 AC12 -- zero agent files restate 'recomputed each run' (positive control confirms the pattern works)" \
    || fail "T46 AC12 -- agent file(s) restate the phrase: $t46_ac12_agents_files"
fi
check "T46 AC12 -- CLAUDE.md carries the single source" "recomputed each run" "$(cat "${PLUGIN_DIR}/CLAUDE.md")"

echo
echo "T46 -- full suite stays green with the agent-contract additions in place"
# G26 (round-3): reuses the shared whole-tree grants capture (before T66 AC12) instead of a
# fresh run (CA-094).
_wave7_assert_shared_lint_fresh "T46 (full suite)"
[[ "$WAVE7_GRANTS_EXIT" -eq 0 ]] && pass "T46 -- edm-check-grants exits 0 (captured once; CA-094)" \
  || fail "T46 -- edm-check-grants exited ${WAVE7_GRANTS_EXIT} (captured once; output: ${WAVE7_GRANTS_OUT})"
[[ "$WAVE7_ALL_LINT_EXIT" -eq 0 ]] && pass "T46 -- edm-lint-artifacts --all exits 0" \
  || fail "T46 -- edm-lint-artifacts --all exited ${WAVE7_ALL_LINT_EXIT} (captured once; output: ${WAVE7_ALL_LINT_OUT})"
# EDMV3-T46 end

# =================================================================================
# EDMV3-T47: explorer fan-out gets a deterministic cap
# =================================================================================
echo
echo "=== EDMV3-T47: explorer fan-out gets a deterministic cap ==="

echo
echo "T47 AC1 -- the cap: 'maximum 4' present in skills/plan/SKILL.md"
check "T47 AC1 -- 'maximum 4' present" "maximum 4" "$(cat "${PLUGIN_DIR}/skills/plan/SKILL.md")"

echo
echo "T47 AC2 -- rationale recorded alongside the cap"
T47_PLAN_PATTERN="$(sed -n '/AI Execution Pattern/,/^## /p' "${PLUGIN_DIR}/skills/plan/SKILL.md")"
check "T47 AC2 -- AskUserQuestion four-option rationale" "AskUserQuestion" "$T47_PLAN_PATTERN"
check "T47 AC2 -- cites existing fan-outs (ticket auditors)" "ticket auditors" "$T47_PLAN_PATTERN"
check "T47 AC2 -- cites existing fan-outs (SRD auditors)" "SRD auditors" "$T47_PLAN_PATTERN"
check "T47 AC2 -- fifth-area-means-split rationale" "signal the" "$T47_PLAN_PATTERN"

echo
echo "T47 AC3 -- the one-is-enough case stated explicitly"
check "T47 AC3 -- 'use one' present" "use one" "$T47_PLAN_PATTERN"

echo
echo "T47 AC4 -- criterion given concretely"
check "T47 AC4 -- 'distinct top-level source trees' present" "distinct top-level source trees" "$T47_PLAN_PATTERN"

echo
echo "T47 AC5 -- one location after the move: orchestrator carries no copy"
# G20/G30 (round-3): count_matches_strict distinguishes "genuinely zero" from "file missing/
# unreadable" (CA-145), and the positive control below (skills/plan/SKILL.md, which legitimately
# spawns edm-explorer, EDMV3-T47's own move target) proves the identical needle is not itself
# broken -- an uncontrolled zero here would pass identically whether the mention was truly absent
# or the needle had been typo'd.
t47_orch_explorer_pattern='edm-explorer'
t47_orch_explorer_ec=0
t47_orch_explorer_hits="$(count_matches_strict "$t47_orch_explorer_pattern" "${PLUGIN_DIR}/skills/orchestrator/SKILL.md")" || t47_orch_explorer_ec=$?
t47_orch_explorer_control_ec=0
t47_orch_explorer_control="$(count_matches_strict "$t47_orch_explorer_pattern" "${PLUGIN_DIR}/skills/plan/SKILL.md")" || t47_orch_explorer_control_ec=$?
if [[ $t47_orch_explorer_control_ec -ne 0 || "${t47_orch_explorer_control:-0}" -lt 1 ]]; then
  fail "T47 AC5 -- positive control broken: skills/plan/SKILL.md no longer mentions edm-explorer (ec=${t47_orch_explorer_control_ec}, count=${t47_orch_explorer_control:-0})"
elif [[ $t47_orch_explorer_ec -ne 0 ]]; then
  fail "T47 AC5 -- count_matches_strict errored reading orchestrator/SKILL.md (ec=${t47_orch_explorer_ec})"
else
  [[ "${t47_orch_explorer_hits:-0}" -eq 0 ]] && pass "T47 AC5 -- orchestrator/SKILL.md carries zero 'edm-explorer' mentions (positive control confirms the needle still matches a legitimate mention elsewhere)" \
    || fail "T47 AC5 -- orchestrator/SKILL.md carries ${t47_orch_explorer_hits} 'edm-explorer' mention(s), expected 0"
fi

echo
echo "T47 AC6 -- other deterministic caps unchanged (asserted positively on the surviving text)"
check "T47 AC6 -- ticket-auditor cap surviving unchanged" "spawn exactly 2 \`edm-ticket-auditor\`" \
  "$(cat "${PLUGIN_DIR}/skills/audit-tickets/SKILL.md")"
check "T47 AC6 -- SRD-auditor cap surviving unchanged" "Spawn 2-3 \`edm-srd-auditor\`" \
  "$(cat "${PLUGIN_DIR}/skills/audit-srd/SKILL.md")"
check "T47 AC6 -- implementer cap surviving unchanged" "6-10 parallel" \
  "$(cat "${PLUGIN_DIR}/skills/implement/SKILL.md")"
check "T47 AC6 -- lens cap surviving unchanged" "run all 11" \
  "$(cat "${PLUGIN_DIR}/skills/code-audit/SKILL.md")"

echo
echo "T47 AC7 -- the cap text appears in exactly one file"
t47_cap_files="$(grep -rl 'maximum 4' "${PLUGIN_DIR}/skills/" | wc -l | tr -d ' ')" || true
[[ "${t47_cap_files:-0}" -eq 1 ]] && pass "T47 AC7 -- 'maximum 4' appears in exactly one skills/ file" \
  || fail "T47 AC7 -- 'maximum 4' appears in ${t47_cap_files:-0} file(s), expected 1"

echo
echo "T47 -- full suite stays green with the explorer cap in place"
# G26 (round-3): reuses the shared whole-tree grants capture (before T66 AC12) instead of a
# fresh run (CA-094).
_wave7_assert_shared_lint_fresh "T47 (full suite)"
[[ "$WAVE7_GRANTS_EXIT" -eq 0 ]] && pass "T47 -- edm-check-grants exits 0 (captured once; CA-094)" \
  || fail "T47 -- edm-check-grants exited ${WAVE7_GRANTS_EXIT} (captured once; output: ${WAVE7_GRANTS_OUT})"
[[ "$WAVE7_ALL_LINT_EXIT" -eq 0 ]] && pass "T47 -- edm-lint-artifacts --all exits 0" \
  || fail "T47 -- edm-lint-artifacts --all exited ${WAVE7_ALL_LINT_EXIT} (captured once; output: ${WAVE7_ALL_LINT_OUT})"
# EDMV3-T47 end

# =================================================================================
# EDMV3-T49: do-NOT-adopt guards and the before/after prose convention
# =================================================================================
echo
echo "=== EDMV3-T49: do-NOT-adopt guards and the before/after prose convention ==="

echo
echo "T49 AC1 -- conventions recorded as house style"
check "T49 AC1 -- 'house style' present" "house style" "$(cat "${PLUGIN_DIR}/CLAUDE.md")"

echo
echo "T49 AC2 -- four sources named with licence and location"
check "T49 AC2 -- opus-5 named" "opus-5" "$(cat "${PLUGIN_DIR}/CLAUDE.md")"
check "T49 AC2 -- sonnet-5 named" "sonnet-5" "$(cat "${PLUGIN_DIR}/CLAUDE.md")"
check "T49 AC2 -- caveman named" "caveman" "$(cat "${PLUGIN_DIR}/CLAUDE.md")"
check "T49 AC2 -- ponytail named" "ponytail" "$(cat "${PLUGIN_DIR}/CLAUDE.md")"
# AC2 requires a URL and a licence for each of the four sources, plus a clean-room note for the
# two adopted from sibling repositories. This case asserted the literal string "licence is
# unverified", which was true only while the two licences were unresolved -- so it asserted the
# defect rather than the requirement, and went red the moment the licences were verified as MIT.
# Assert what AC2 actually asks for: the licence value, and that the clean-room posture survives.
check "T49 AC2 -- caveman/ponytail licences recorded" "MIT" "$(cat "${PLUGIN_DIR}/CLAUDE.md")"
check "T49 AC2 -- clean-room note present" "Clean-room note" "$(cat "${PLUGIN_DIR}/CLAUDE.md")"
t49_url_count="$(grep -c 'https://' "${PLUGIN_DIR}/CLAUDE.md" || true)"
[[ "${t49_url_count:-0}" -ge 4 ]] && pass "T49 AC2 -- at least four source URLs present" \
  || fail "T49 AC2 -- found ${t49_url_count:-0} https:// URLs in CLAUDE.md, expected >= 4"

echo
echo "T49 AC3 -- six do-NOT-adopt guards named and cited"
t49_guard_count="$(grep -c '(D[1-6])' "${PLUGIN_DIR}/CLAUDE.md" || true)"
[[ "${t49_guard_count:-0}" -eq 6 ]] && pass "T49 AC3 -- six (D1)-(D6) guard identifiers present" \
  || fail "T49 AC3 -- found ${t49_guard_count:-0} guard identifiers, expected 6"

echo
echo "T49 AC4 -- each guard carries a 'the cost of ignoring this is' clause"
t49_cost_count="$(grep -c 'cost of ignoring this is' "${PLUGIN_DIR}/CLAUDE.md" || true)"
[[ "${t49_cost_count:-0}" -eq 6 ]] && pass "T49 AC4 -- six guards each carry a cost clause" \
  || fail "T49 AC4 -- found ${t49_cost_count:-0} cost clauses, expected 6"

echo
echo "T49 AC5 -- do-NOT-adopt subsection with six identifiers"
check "T49 AC5 -- '#### Do-NOT-adopt guards' heading present" "#### Do-NOT-adopt guards" "$(cat "${PLUGIN_DIR}/CLAUDE.md")"
[[ "${t49_guard_count:-0}" -eq 6 ]] && pass "T49 AC5 -- do-NOT-adopt subsection carries all six guard identifiers" \
  || fail "T49 AC5 -- subsection carries ${t49_guard_count:-0} guard identifiers, expected 6"

echo
echo "T49 AC6 -- self-verification phrase family absent outside skills/verify-runtime/"
t49_dc_pattern='double-check'
t49_vyo_pattern='verify your own'
t49_cyw_pattern='check your work'
t49_rvy_pattern='re-verify your'
t49_selfverify_hits="$(grep -rni "${t49_dc_pattern}\|${t49_vyo_pattern}\|${t49_cyw_pattern}\|${t49_rvy_pattern}" "${PLUGIN_DIR}/skills" "${PLUGIN_DIR}/agents" 2>/dev/null | grep -v 'skills/verify-runtime/' || true)"
# G20 (round-3): four-needle OR'd repo-wide scan -- each phrasing routed through
# assert_tree_absent (G2/CA-037 + G13/CA-145, round 4): genuinely seeded scratch controls, and
# the two scanned directories are asserted to exist before each needle check runs.
# G2/CA-037 residual (round 5): the OR'd producing pattern above is built from the same four
# variables passed to assert_tree_absent below, closing the divergent-typo class.
t49_dc_control="${TMP}/edm-t49-doublecheck-control.txt"
printf 'double-check your own work\n' > "$t49_dc_control"
assert_tree_absent "T49 AC6 -- no 'double-check' self-verification hit outside skills/verify-runtime/" \
  "$t49_dc_pattern" "$t49_selfverify_hits" "$(cat "$t49_dc_control")" "${PLUGIN_DIR}/skills" "${PLUGIN_DIR}/agents"
t49_vyo_control="${TMP}/edm-t49-verifyown-control.txt"
printf 'verify your own output\n' > "$t49_vyo_control"
assert_tree_absent "T49 AC6 -- no 'verify your own' self-verification hit outside skills/verify-runtime/" \
  "$t49_vyo_pattern" "$t49_selfverify_hits" "$(cat "$t49_vyo_control")" "${PLUGIN_DIR}/skills" "${PLUGIN_DIR}/agents"
t49_cyw_control="${TMP}/edm-t49-checkwork-control.txt"
printf 'check your work before submitting\n' > "$t49_cyw_control"
assert_tree_absent "T49 AC6 -- no 'check your work' self-verification hit outside skills/verify-runtime/" \
  "$t49_cyw_pattern" "$t49_selfverify_hits" "$(cat "$t49_cyw_control")" "${PLUGIN_DIR}/skills" "${PLUGIN_DIR}/agents"
t49_rvy_control="${TMP}/edm-t49-reverify-control.txt"
printf 're-verify your findings\n' > "$t49_rvy_control"
assert_tree_absent "T49 AC6 -- no 're-verify your' self-verification hit outside skills/verify-runtime/" \
  "$t49_rvy_pattern" "$t49_selfverify_hits" "$(cat "$t49_rvy_control")" "${PLUGIN_DIR}/skills" "${PLUGIN_DIR}/agents"
rm -f "$t49_dc_control" "$t49_vyo_control" "$t49_cyw_control" "$t49_rvy_control"

echo
echo "T49 AC7 -- before/after convention present on every prompt-text epic file (positive check)"
t49_ac7_missing=""
for t49_epic in 01 02 04 05 06 07 08 09 10; do
  t49_epic_file="$(ls "${PLUGIN_DIR}/../../SRD/edm/EDMV3__prompt-streamline/tickets/epics/${t49_epic}-"*.md 2>/dev/null | head -1)"
  if [[ -z "$t49_epic_file" ]] || ! grep -q 'before and after' "$t49_epic_file" 2>/dev/null; then
    t49_ac7_missing="${t49_ac7_missing} epics/${t49_epic}"
  fi
done
[[ -z "$t49_ac7_missing" ]] && pass "T49 AC7 -- all nine prompt-text epic files (01,02,04-10) carry the before/after AC" \
  || fail "T49 AC7 -- missing the before/after AC in:${t49_ac7_missing}"
# AC7's own literal verify is `grep -rl 'before and after' epics/ | wc -l` == 9. That used to
# return ten: epics/11-cross-cutting-delivery.md matched incidentally on cost/output-comparison
# wording, none of it the prose-change AC. This suite recorded that as a known gap instead of
# asserting it, which left the AC's stated command permanently wrong. The three incidental
# phrases were reworded to "pre- and post-change" (same meaning), so the count is now assertable
# and this is a mechanism rather than a note.
t49_ac7_count="$(grep -rl 'before and after' "${PLUGIN_DIR}/../../SRD/edm/EDMV3__prompt-streamline/tickets/epics/" 2>/dev/null | wc -l | tr -d ' ')"
[[ "${t49_ac7_count:-0}" -eq 9 ]] && pass "T49 AC7 -- the AC's literal grep lists exactly nine epic files" \
  || fail "T49 AC7 -- the AC's literal grep lists ${t49_ac7_count:-0} epic files, expected exactly 9"
check_absent "T49 AC7 -- epics/11 no longer collides with the convention grep" "before and after" \
  "$(cat "${PLUGIN_DIR}/../../SRD/edm/EDMV3__prompt-streamline/tickets/epics/11-cross-cutting-delivery.md" 2>/dev/null || true)"

echo
echo "T49 AC8 -- convention recorded once in CLAUDE.md under contribution guidance"
check "T49 AC8 -- 'before and after for each changed block' present" "before and after for each changed block" "$(cat "${PLUGIN_DIR}/CLAUDE.md")"

echo
echo "T49 -- full suite stays green with the guard/convention subsection in place"
# G26 (round-3): reuses the shared whole-tree grants capture (before T66 AC12) instead of a
# fresh run (CA-094).
_wave7_assert_shared_lint_fresh "T49 (full suite)"
[[ "$WAVE7_GRANTS_EXIT" -eq 0 ]] && pass "T49 -- edm-check-grants exits 0 (captured once; CA-094)" \
  || fail "T49 -- edm-check-grants exited ${WAVE7_GRANTS_EXIT} (captured once; output: ${WAVE7_GRANTS_OUT})"
[[ "$WAVE7_ALL_LINT_EXIT" -eq 0 ]] && pass "T49 -- edm-lint-artifacts --all exits 0" \
  || fail "T49 -- edm-lint-artifacts --all exited ${WAVE7_ALL_LINT_EXIT} (captured once; output: ${WAVE7_ALL_LINT_OUT})"
# EDMV3-T49 end
# EDMV3-T67: performance and cost budgets are measured and recorded
# =================================================================================
echo
echo "T67 AC14 -- committed, reproducible timing script exists and is executable"
TIMING_SH="${PLUGIN_DIR}/bin/tests/timing.sh"
[[ -x "$TIMING_SH" ]] \
  && pass "T67 AC14 -- bin/tests/timing.sh is executable" \
  || fail "T67 AC14 -- bin/tests/timing.sh is missing or not executable"
# CA-147: the label claims seven measurement modes; asserting on a single token
# ("generate-fixture") would still pass on a timing.sh reduced to `echo generate-fixture; exit 0`
# -- and this is the script that produces the committed latency budgets in CHANGELOG.md's T67
# table and both budgets in plugins/edm/CLAUDE.md, so a silently-broken timing.sh is a silently
# untrustworthy budget. Assert each of the seven measurement mode names by itself
# (--generate-fixture sets up the fixture and is not itself a measurement mode).
t67_timing_usage="$(bash "$TIMING_SH" 2>&1 || true)"
for t67_mode in --subcommands --phase-complete --ledger --session-start --lint --mermaid-ratio --all-lint; do
  check "T67 AC14 -- timing.sh usage lists measurement mode ${t67_mode}" \
    "$t67_mode" "$t67_timing_usage"
done

echo
echo "T67 AC14 (CA-147) -- a single cheap mode actually measures against a real fixture"
# --session-start is the cheapest real mode: it inits one tiny scratch initiative and times ten
# real edm-state session-start invocations -- no 30-file/10,000-line fixture generation like
# --lint/--mermaid-ratio/--all-lint. Asserting a parseable millisecond figure comes back (not
# just that the mode name is recognized) proves the mode actually measures something real.
t67_ss_rc=0
t67_ss_out="$(bash "$TIMING_SH" --session-start 2>&1)" || t67_ss_rc=$?
check "T67 AC14 -- --session-start exits 0" "0" "$t67_ss_rc"
check "T67 AC14 -- --session-start reports the TIMING session-start line" \
  "TIMING session-start" "$t67_ss_out"
t67_ss_delta="$(printf '%s\n' "$t67_ss_out" | grep -o 'delta_ms=-\?[0-9]\+' | sed -E 's/.*=//' || true)"
[[ -n "$t67_ss_delta" && "$t67_ss_delta" =~ ^-?[0-9]+$ ]] \
  && pass "T67 AC14 -- --session-start returns a parseable integer delta_ms (${t67_ss_delta})" \
  || fail "T67 AC14 -- --session-start did not return a parseable delta_ms (output: $t67_ss_out)"

echo
echo "T67 AC14 (G31/CA-147) -- --generate-fixture + --subcommands is a real, exit-0 measurement run"
# The block above proves --session-start reports SOME integer, but delta_ms is a signed
# difference that is routinely negative or zero (noise-level, per CHANGELOG.md's own recorded
# "-2ms" figure) -- it never proves a genuinely positive measurement came back. A stub timing.sh
# that only prints its own usage/help text would still pass every assertion above it (the seven
# mode-name-in-usage checks) and could even be made to print a fake "delta_ms=0" line. This block
# closes that gap: it drives --generate-fixture for a real (if minimal) 1-initiative fixture, then
# runs --subcommands against it for real and asserts a parseable POSITIVE p95_ms figure comes
# back -- which also incidentally exercises (and would catch a regression in) the perl-less
# whole-second-resolution timing fallback on a host without perl.
t67_gen_rc=0
t67_gen_out="$(bash "$TIMING_SH" --generate-fixture --initiatives 1 2>&1)" || t67_gen_rc=$?
check "T67 AC14 (G31) -- --generate-fixture exits 0" "0" "$t67_gen_rc"
t67_fixture_dir="$(printf '%s\n' "$t67_gen_out" | grep -oE 'FIXTURE_DIR=.*' | cut -d= -f2-)"
[[ -n "$t67_fixture_dir" && -d "$t67_fixture_dir" ]] \
  && pass "T67 AC14 (G31) -- --generate-fixture produces a usable 1-initiative fixture directory" \
  || fail "T67 AC14 (G31) -- --generate-fixture did not produce a usable fixture directory (output: $t67_gen_out)"

t67_sub_exit=0
t67_sub_out="$(bash "$TIMING_SH" --subcommands --dir "$t67_fixture_dir" 2>&1)" || t67_sub_exit=$?
[[ "$t67_sub_exit" -eq 0 ]] \
  && pass "T67 AC14 (G31) -- --subcommands exits 0 against the generated fixture" \
  || fail "T67 AC14 (G31) -- --subcommands exited ${t67_sub_exit} (output: $t67_sub_out)"
if [[ "$t67_sub_out" =~ p95_ms=([1-9][0-9]*) ]]; then
  pass "T67 AC14 (G31) -- --subcommands reports a parseable positive p95_ms figure (${BASH_REMATCH[1]})"
else
  fail "T67 AC14 (G31) -- --subcommands produced no parseable positive p95_ms figure (output: $t67_sub_out)"
fi
[[ -n "$t67_fixture_dir" ]] && rm -rf "$t67_fixture_dir"

echo
echo "T67 AC2 -- get_session_tokens_since bounds its read (EDM_TOKEN_READ_LINE_CAP)"
check "T67 AC2 -- token read is capped with tail -n, not an unbounded jq -s over the whole file" \
  "EDM_TOKEN_READ_LINE_CAP" "$(cat "$EDM_STATE")"

echo
echo "T67 AC8 -- commit-hook scoping (PreToolUse git commit) preserved"
# This assertion used to be `git diff --stat -- hooks/hooks.json` is empty. That measures
# "the file has no UNCOMMITTED change right now", not "the scoping is preserved": it goes green
# the moment anything is committed, whatever the content, and goes red for an unrelated edit like
# normalizing an em dash in a prompt string. Assert the scoping properties AC8 actually names,
# read out of the hook command itself, so the check means the same thing before and after a commit.
t67ac8_cmd="$(jq -r '.hooks.PreToolUse[] | select(.matcher == "git commit") | .hooks[0].command' \
  "${PLUGIN_DIR}/hooks/hooks.json" 2>/dev/null || true)"
if [[ -z "$t67ac8_cmd" ]]; then
  fail "T67 AC8 -- no PreToolUse hook with matcher 'git commit' found in hooks/hooks.json"
else
  # Scoped to staged SRD/ paths only, resolves prefixes from both layouts, degrades to exit 0
  # when the helpers are absent, and propagates a non-zero exit so a violation blocks the commit.
  check "T67 AC8 -- scoped to staged paths under SRD/" "diff --cached --name-only" "$t67ac8_cmd"
  # CA-023: srd_root is now derived dynamically (EDM_SRD_ROOT / CLAUDE_PLUGIN_OPTION_SRD_ROOT,
  # default ./SRD) rather than the literal hardcoded `grep '^SRD/'` pattern this assertion used
  # to require -- a relocated srd_root now scopes the commit-path hook too, not just direct
  # edm-lint-artifacts invocations (plugins/edm/CLAUDE.md's own "Hooks behavior" note on this
  # exact gap is now stale and should be read as historical, not current).
  check "T67 AC8 -- srd_root is derived, not hardcoded to SRD/" \
    'srd_root="${EDM_SRD_ROOT:-${CLAUDE_PLUGIN_OPTION_SRD_ROOT:-./SRD}}"' "$t67ac8_cmd"
  # CA-011: a staged path whose prefix has no resolvable initiative (a deleted initiative
  # directory, a pre-plugin legacy path, a stale prefix) is skipped rather than blocking an
  # otherwise-clean commit on an edm-lint-artifacts exit-2 "no initiative for prefix" error.
  check "T67 AC8 -- unresolvable prefixes are skipped, not treated as violations" \
    'edm-state resolve-dir "$p" >/dev/null 2>&1 || continue' "$t67ac8_cmd"
  # CA-011: a PreToolUse hook must exit 2 to actually block Claude Code's tool call -- the
  # honest violation path (edm-lint-artifacts exit 1) sets fail=2; a setup/usage error
  # (edm-lint-artifacts exit 2) is reported but does NOT set fail, so it warns without blocking.
  check "T67 AC8 -- a real violation (exit 1) sets fail=2, the code that actually blocks" \
    'code" -eq 1' "$t67ac8_cmd"
  check "T67 AC8 -- a setup/usage error (exit 2) is reported but does not block the commit" \
    'code" -eq 2' "$t67ac8_cmd"
  check "T67 AC8 -- exits 0 when edm-lint-artifacts is unavailable" \
    "command -v edm-lint-artifacts >/dev/null 2>&1 || exit 0" "$t67ac8_cmd"
  check "T67 AC8 -- exits 0 when nothing under SRD/ is staged" 'test -z "$staged" && exit 0' "$t67ac8_cmd"
  check "T67 AC8 -- propagates failure so the commit is blocked" 'exit $fail' "$t67ac8_cmd"
  check "T67 AC8 -- invokes the linter per resolved prefix, not with --all" 'edm-lint-artifacts "$p"' "$t67ac8_cmd"
  check_absent "T67 AC8 -- commit path does not scan the whole tree" "edm-lint-artifacts --all" "$t67ac8_cmd"
fi

echo
echo "T67 AC11 -- no blocking job's script contains a network call"
# G74/CA-234: derive the blocking-job set programmatically from .gitlab-ci.yml itself, rather than
# a hand-maintained list -- the prior hardcoded 9-job list silently drifted behind the pipeline
# and omitted two real, current blocking jobs (lint:file-type-ban, lint:pattern-library-contract),
# covering only 9 of the 11 actual blocking jobs. A job is "blocking" here iff it is a top-level
# job key (excludes the `stages:` list and the `.foo: &anchor` YAML anchors, which never end a
# line in a bare `:`) whose block contains no `allow_failure: true`. The "job body must not be
# empty" guard a few lines below stays in place as a safeguard ON this derivation: a mis-parsed or
# renamed job still fails loudly by name instead of silently vanishing from the set.
t67ac11_all_job_names="$(grep -oE '^[A-Za-z][A-Za-z0-9_:-]*:$' "$GITLAB_CI_YML" | sed 's/:$//' | grep -v '^stages$')"
t67ac11_blocking_jobs=""
# G40/CA-271 (round 4): all three job-body extractions below (this one, the T67 AC11 loop just
# past it, and the CA-085(b) positive control below that) share the same tightened terminator --
# excluding '#' from the FIRST character class, not just the rest of the line -- so a column-0
# comment ending in a colon can never be misread as the next job's header and silently truncate
# the body being scanned (the T66 AC11 block above carries the identical fix for the same shape).
for t67_candidate in $t67ac11_all_job_names; do
  t67_candidate_body="$(awk -v job="^${t67_candidate}:$" '
    $0 ~ job {f=1; next}
    f && /^[^[:space:]#][^#]*:$/ {exit}
    f {print}
  ' "$GITLAB_CI_YML")"
  # Comment lines trailing a job's real script (e.g. validate:manifest's own trailing comment
  # block documents validate:plugin-cli's `allow_failure: true` right below it) get swept into
  # this crude body extraction because they don't end in a bare ":" the way a real next-job
  # header does -- strip comment-only lines before checking for a real `allow_failure: true` key,
  # or a job whose only mention of the phrase is in prose describing its NEIGHBOR gets
  # misclassified as non-blocking.
  if ! printf '%s' "$t67_candidate_body" | grep -v '^[[:space:]]*#' | grep -q 'allow_failure: *true'; then
    t67ac11_blocking_jobs="${t67ac11_blocking_jobs} ${t67_candidate}"
  fi
done
t67ac11_blocking_jobs="${t67ac11_blocking_jobs# }"
t67ac11_blocking_job_count="$(printf '%s\n' "$t67ac11_blocking_jobs" | wc -w | tr -d ' ')"
[[ -n "$t67ac11_blocking_jobs" && "$t67ac11_blocking_job_count" -ge 11 ]] \
  && pass "T67 AC11 -- derived a blocking-job set of >= 11 jobs from .gitlab-ci.yml (got ${t67ac11_blocking_job_count}: ${t67ac11_blocking_jobs})" \
  || fail "T67 AC11 -- derived blocking-job set has only ${t67ac11_blocking_job_count} job(s), expected >= 11 (got: ${t67ac11_blocking_jobs})"
t67ac11_net_hits=""
t67ac11_missing_jobs=""
for t67_job in $t67ac11_blocking_jobs; do
  t67_job_body="$(awk -v job="^${t67_job}:$" '
    $0 ~ job {f=1; next}
    f && /^[^[:space:]#][^#]*:$/ {exit}
    f {print}
  ' "$GITLAB_CI_YML")"
  # CA-085(a): an absent job (deleted from the pipeline, renamed, or a typo in the list above)
  # yields an EMPTY body that matches no network pattern and was silently scored clean -- the
  # far more consequential fact (the job doesn't exist) went unreported. Fail explicitly, naming
  # the job, instead of letting an empty body pass the grep below by default.
  if [[ -z "$t67_job_body" ]]; then
    t67ac11_missing_jobs="${t67ac11_missing_jobs} ${t67_job}"
    continue
  fi
  # CA-085(b): broadened beyond curl/wget/anthropic.com to also catch an unpinned global tool
  # install (npm install -g, with no version pin) landing in a blocking job -- previously
  # invisible, with no positive control proving the pattern actually fires. Deliberately does
  # NOT add a bare "apk add"/"apt-get" ban: every blocking job's before_script bootstraps its
  # (digest-pinned, per CLAUDE.md's "All job images are pinned by digest" note) Alpine image with
  # `apk add --no-cache bash` or similar -- that is this pipeline's accepted, reviewed baseline,
  # not the invisible-network-call class this AC targets. A literal "apk add|apt-get" ban was
  # tried and immediately flagged every blocking job identically, which is a false-positive
  # regression, not real signal -- it would make this assertion permanently red or force someone
  # to blanket-suppress it, either of which defeats the AC. "npm install" alone has zero matches
  # in the current blocking set (both existing `npm install -g @anthropic-ai/claude-code` calls
  # are in the two non-blocking, allow_failure:true jobs), so it adds real forward coverage
  # without a false positive today.
  echo "$t67_job_body" | grep -qE 'curl |wget |anthropic\.com|npm install' \
    && t67ac11_net_hits="${t67ac11_net_hits} ${t67_job}"
done
[[ -z "$t67ac11_missing_jobs" ]] \
  && pass "T67 AC11 -- all named blocking jobs exist in .gitlab-ci.yml" \
  || fail "T67 AC11 -- job(s) named in the blocking set are not present in .gitlab-ci.yml:${t67ac11_missing_jobs}"
[[ -z "$t67ac11_net_hits" ]] \
  && pass "T67 AC11 -- no blocking job's script calls curl/wget/anthropic.com/npm install" \
  || fail "T67 AC11 -- network/unpinned-install call found in blocking job(s):${t67ac11_net_hits}"

# CA-085(b) positive control: inject a curl call into a scratch copy of the same job body and
# prove the widened pattern actually fires -- without this, the assertion above could pass
# vacuously (silently matching nothing) forever.
t67ac11_scratch_body="$(awk -v job='^lint:artifacts:$' '
  $0 ~ job {f=1; next}
  f && /^[^[:space:]#][^#]*:$/ {exit}
  f {print}
' "$GITLAB_CI_YML")
    - curl -sSL https://example.invalid/install.sh | sh"
echo "$t67ac11_scratch_body" | grep -qE 'curl |wget |anthropic\.com|npm install' \
  && pass "T67 AC11 (CA-085 positive control) -- an injected curl call is actually caught by the pattern" \
  || fail "T67 AC11 (CA-085 positive control) -- injecting a curl call did not trip the network-call pattern"

# Second positive control: the "npm install" half of the widened pattern specifically -- proving
# the new part of the broadened coverage actually fires, not just the pre-existing curl branch.
t67ac11_scratch_body_npm="${t67ac11_scratch_body}
    - npm install -g some-unpinned-tool"
echo "$t67ac11_scratch_body_npm" | grep -qE 'curl |wget |anthropic\.com|npm install' \
  && pass "T67 AC11 (CA-085 positive control) -- an injected unpinned npm install is actually caught by the widened pattern" \
  || fail "T67 AC11 (CA-085 positive control) -- injecting an npm install did not trip the widened pattern"

echo "T67 AC1/AC3/AC4/AC5/AC6/AC7 -- measured this session against real generated fixtures via"
echo "  bin/tests/timing.sh; the numbers are recorded in CHANGELOG.md's EDMV3-T67 table, not"
echo "  re-run here (they take minutes and generate scratch fixtures unsuited to a fast smoke"
echo "  suite). AC9/AC13 are recorded verified-locally-pending-pipeline (decisions.md D27) --"
echo "  both require a live GitLab runner / a real costed eval run this session did not trigger."
# EDMV3-T67 end

# =================================================================================
# EDMV3-T48: tiering matrix (D16) -- built and unit-verified, not run; 15 contested
# agents stay opus/max until a real matrix result retiers them mechanically.
# =================================================================================
echo
echo "=== EDMV3-T48: tiering matrix (D16) -- contested set unchanged, promotion rule unit-verified ==="

if [[ "$(pwd)" == "$WAVE7_ALL_LINT_CWD" && "${EDM_SRD_ROOT:-}" == "$WAVE7_ALL_LINT_SRD_ROOT" ]]; then
  pass "shared-lint invariant -- cwd and EDM_SRD_ROOT match the captured values before T48"
else
  fail "shared-lint invariant -- cwd or EDM_SRD_ROOT drifted before T48"
fi
if [[ "$(git -C "$PLUGIN_DIR/../.." status --porcelain 2>/dev/null || true)" == "$WAVE7_ALL_LINT_GIT_STATUS" ]]; then
  pass "shared-lint invariant -- tracked-tree fingerprint unchanged before T48"
else
  fail "shared-lint invariant -- tracked-tree fingerprint changed before T48"
fi

echo
echo "T48 AC1 -- nothing pre-tiered: the 15 contested agents are still opus/max"
T48_CONTESTED_AGENTS="edm-audit-consistency edm-audit-dead-code edm-audit-docs edm-audit-dry edm-audit-edge-cases edm-audit-logic edm-audit-runtime edm-audit-security edm-audit-spec edm-audit-test-quality edm-audit-wiring edm-audit-synthesizer edm-srd-auditor edm-ticket-auditor edm-qc-auditor"
t48_contested_count=0
t48_bad=""
for t48_agent in $T48_CONTESTED_AGENTS; do
  t48_contested_count=$((t48_contested_count + 1))
  t48_file="${PLUGIN_DIR}/agents/${t48_agent}.md"
  if [[ ! -f "$t48_file" ]]; then
    t48_bad="${t48_bad} ${t48_agent}(missing-file)"
    continue
  fi
  t48_model="$({ grep -m1 '^model:' "$t48_file" || true; } | awk '{print $2}')"
  t48_effort="$({ grep -m1 '^effort:' "$t48_file" || true; } | awk '{print $2}')"
  if [[ "$t48_model" != "opus" || "$t48_effort" != "max" ]]; then
    t48_bad="${t48_bad} ${t48_agent}(${t48_model}/${t48_effort})"
  fi
done
[[ "$t48_contested_count" -eq 15 ]] && pass "T48 AC1 -- exactly 15 contested agents enumerated" \
  || fail "T48 AC1 -- enumerated ${t48_contested_count} contested agents, expected 15"
[[ -z "$t48_bad" ]] && pass "T48 AC1 -- all 15 contested agents are opus/max (no hand-tiering slipped in)" \
  || fail "T48 AC1 -- non-opus/max contested agent(s) found, D16 violation:${t48_bad}"

echo
echo "T48 AC5 -- the three wave-A EDMV3-T02 downgrades are unaffected by this ticket"
t48_explorer="$({ grep -m1 '^model:' "${PLUGIN_DIR}/agents/edm-explorer.md" || true; } | awk '{print $2}')/$(grep -m1 '^effort:' "${PLUGIN_DIR}/agents/edm-explorer.md" | awk '{print $2}')"
t48_tca="$({ grep -m1 '^model:' "${PLUGIN_DIR}/agents/edm-test-coverage-auditor.md" || true; } | awk '{print $2}')/$(grep -m1 '^effort:' "${PLUGIN_DIR}/agents/edm-test-coverage-auditor.md" | awk '{print $2}')"
t48_architect="$({ grep -m1 '^model:' "${PLUGIN_DIR}/agents/edm-architect.md" || true; } | awk '{print $2}')/$(grep -m1 '^effort:' "${PLUGIN_DIR}/agents/edm-architect.md" | awk '{print $2}')"
[[ "$t48_explorer" == "sonnet/high" ]] && pass "T48 AC5 -- edm-explorer stays sonnet/high" || fail "T48 AC5 -- edm-explorer is ${t48_explorer}, expected sonnet/high"
[[ "$t48_tca" == "sonnet/high" ]] && pass "T48 AC5 -- edm-test-coverage-auditor stays sonnet/high" || fail "T48 AC5 -- edm-test-coverage-auditor is ${t48_tca}, expected sonnet/high"
[[ "$t48_architect" == "opus/high" ]] && pass "T48 AC5 -- edm-architect stays opus/high" || fail "T48 AC5 -- edm-architect is ${t48_architect}, expected opus/high"

echo
echo "T48 AC6 -- lens fan-out unchanged: eleven lenses, none merged or removed"
t48_lens_count="$(ls "${PLUGIN_DIR}"/agents/edm-audit-*.md | grep -vc synthesizer)"
[[ "$t48_lens_count" -eq 11 ]] && pass "T48 AC6 -- eleven code-audit lens agent files present" \
  || fail "T48 AC6 -- found ${t48_lens_count} lens agent files, expected 11"

echo
echo "T48 -- the tiering-matrix promotion rule is unit-verified against synthetic fixtures"
t48_matrix_out=""
t48_matrix_exit=0
t48_matrix_out="$(bash "${PLUGIN_DIR}/evals/tiering-matrix.sh" --self-test 2>&1)" || t48_matrix_exit=$?
[[ "$t48_matrix_exit" -eq 0 ]] && pass "T48 -- tiering-matrix.sh --self-test exits 0" \
  || fail "T48 -- tiering-matrix.sh --self-test exited ${t48_matrix_exit}: ${t48_matrix_out}"
check "T48 -- self-test proves a qualifying cheaper config wins" \
  "self-test PASS: qualifying cheaper config wins" "$t48_matrix_out"
check "T48 -- self-test proves a P0-missing config is rejected and the next tier wins" \
  "self-test PASS: P0-missing config rejected, next tier wins" "$t48_matrix_out"
check "T48 -- self-test proves an agent with no qualifying config is left unchanged" \
  "self-test PASS: no qualifying config leaves the agent unchanged" "$t48_matrix_out"
# G28/CA-138: extract the actual denominator from the summary line and assert it's >= 6, rather
# than matching the literal string "6/6" -- a hardcoded literal match here would still pass even
# if a self-test block (including the CA-104 80%-boundary pair) were silently deleted from
# tiering-matrix.sh, since --self-test's own prior "6/6" text was equally hardcoded and never
# reflected how many assertions actually ran (this is the exact bug G28 fixed on the other side).
t48_matrix_denom="$(printf '%s' "$t48_matrix_out" | grep -oE 'self-test: PASS \([0-9]+/[0-9]+' | grep -oE '[0-9]+/[0-9]+' | cut -d/ -f2)"
[[ -n "$t48_matrix_denom" && "$t48_matrix_denom" -ge 6 ]] \
  && pass "T48 -- self-test summary reports a real denominator >= 6 (got ${t48_matrix_denom})" \
  || fail "T48 -- self-test summary denominator missing or below 6 (got '${t48_matrix_denom:-<none>}')"

echo
echo "T48 -- CLAUDE.md provenance header present and honestly states not-yet-derived"
check "T48 -- 'Derived from tiering matrix' header present" "Derived from tiering matrix" "$(cat "${PLUGIN_DIR}/CLAUDE.md")"
check "T48 -- honestly flags the table as not yet matrix-derived" "NOT yet matrix-derived" "$(cat "${PLUGIN_DIR}/CLAUDE.md")"

echo
echo "T48 -- full suite stays green with the tiering-matrix instrument in place"
# G26 (round-3): reuses the shared whole-tree grants capture (before T66 AC12) instead of a
# fresh run (CA-094).
_wave7_assert_shared_lint_fresh "T48 (full suite)"
[[ "$WAVE7_GRANTS_EXIT" -eq 0 ]] && pass "T48 -- edm-check-grants exits 0 (captured once; CA-094)" \
  || fail "T48 -- edm-check-grants exited ${WAVE7_GRANTS_EXIT} (captured once; output: ${WAVE7_GRANTS_OUT})"
[[ "$WAVE7_ALL_LINT_EXIT" -eq 0 ]] && pass "T48 -- edm-lint-artifacts --all exits 0" \
  || fail "T48 -- edm-lint-artifacts --all exited ${WAVE7_ALL_LINT_EXIT} (captured once; output: ${WAVE7_ALL_LINT_OUT})"
# EDMV3-T48 end

# ---- Shipped surfaces are ASCII-only (EDMV3 wave-C drift sweep) -------------------------------
# CLAUDE.md Sec."Artifact content conventions" requires ASCII-only text, and edm-lint-artifacts
# class 2 enforces it -- but only over initiative directories under the SRD root. Nothing scanned
# the plugin's own tree, and four em dashes duly survived in skills/ and agents/ prompt templates
# until this sweep found them by hand. Those templates are the literal shapes agents copy into
# artifacts, so a non-ASCII character there propagates into output the artifact lint then blocks.
#
# Scope: every surface that ships and is read at runtime, plus the prompt text in hooks.json.
# Deliberately excluded: CHANGELOG.md (project history, not rewritten retroactively -- the same
# carve-out bin/vocabulary-allowlist.txt makes) and bin/tests/ (this suite's own labels, which
# nothing reads as a prompt).
echo
echo "wave-C drift sweep -- shipped surfaces contain no non-ASCII bytes"
t_ascii_offenders=""
for t_ascii_target in \
  "${PLUGIN_DIR}/skills" "${PLUGIN_DIR}/agents" "${PLUGIN_DIR}/docs" "${PLUGIN_DIR}/evals" \
  "${PLUGIN_DIR}/hooks" "${PLUGIN_DIR}/monitors" "${PLUGIN_DIR}/.claude-plugin" \
  "${PLUGIN_DIR}/CLAUDE.md" "${PLUGIN_DIR}/README.md"
do
  [[ -e "$t_ascii_target" ]] || continue
  t_ascii_hit="$(LC_ALL=C grep -rlv '^[[:print:][:space:]]*$' "$t_ascii_target" 2>/dev/null || true)"
  [[ -n "$t_ascii_hit" ]] && t_ascii_offenders="${t_ascii_offenders} ${t_ascii_hit}"
done
# bin/ excluding bin/tests/ -- the helper scripts themselves, whose comments and output strings
# are held to the same rule (two live session-start output strings carried em dashes).
for t_ascii_bin in "${PLUGIN_DIR}"/bin/*; do
  [[ -f "$t_ascii_bin" ]] || continue
  if LC_ALL=C grep -qv '^[[:print:][:space:]]*$' "$t_ascii_bin" 2>/dev/null; then
    t_ascii_offenders="${t_ascii_offenders} ${t_ascii_bin}"
  fi
done
[[ -z "$t_ascii_offenders" ]] && pass "shipped surfaces are ASCII-only (skills, agents, docs, evals, hooks, monitors, manifest, CLAUDE.md, README.md, bin/)" \
  || fail "non-ASCII bytes found on shipped surfaces:${t_ascii_offenders}"

# Positive control: the detector must actually be able to find a non-ASCII byte. Without this, a
# broken grep invocation would make the assertion above permanently and silently green. This is
# not hypothetical: the first version of this check used `grep -P`, which BSD grep does not
# support -- it exited 2, the `|| true` swallowed it, and the check reported clean. The portable
# `[[:print:][:space:]]` form under LC_ALL=C is what bin/edm-lint-artifacts already falls back to.
t_ascii_probe="$(mktemp "${TMP}/edm-ascii-probe.XXXXXX")"
printf 'em dash \xe2\x80\x94 here\n' > "$t_ascii_probe"
if LC_ALL=C grep -qv '^[[:print:][:space:]]*$' "$t_ascii_probe" 2>/dev/null; then
  pass "non-ASCII detector positive control fires on a known em dash"
else
  fail "non-ASCII detector positive control did NOT fire -- the assertion above is meaningless"
fi
rm -f "$t_ascii_probe"

# =================================================================================
# Code-audit round-2 remediation, Wave 4a: CA-141/CA-142/CA-143/CA-159/CA-025
# (with_state_lock / write_atomic concurrency and trap-nesting fixes)
# =================================================================================
#
# Every case below forces the mkdir-based fallback lock branch regardless of whether this host
# has flock(1) -- the eight findings this wave fixes are concentrated in that branch -- by
# shadowing the `command` builtin so `command -v flock` reports absent. Each case sources
# bin/edm-state inside its own `$( )` subshell (matching _wave7_settable_keys's established
# convention above) so the sourced functions/globals never leak into this suite's own shell.
echo
echo "CA-141/CA-142/CA-143/CA-159/CA-025 -- with_state_lock / write_atomic concurrency fixes"

# ---- G53 (round-3 CA-213 re-fix): the prescribed guard comment above the flock() call lands,
# so a later round does not mistake the never-unlinked lock file for a leak (ledger CA-169).
t_g53_flock_context="$(awk '/flock -w 10 200/{print NR; exit}' "$EDM_STATE")"
t_g53_flock_line="${t_g53_flock_context:-0}"
t_g53_before_flock="$(sed -n "$(( t_g53_flock_line > 10 ? t_g53_flock_line - 10 : 1 )),${t_g53_flock_line}p" "$EDM_STATE")"
check "G53 -- the CA-169 guard comment is present immediately above the flock() call" \
  "CA-169" "$t_g53_before_flock"
check "G53 -- the guard comment states the lock file is never unlinked (inode-keyed exclusion)" \
  "never" "$t_g53_before_flock"
check_absent "G53 -- no rm -f of the flock lockfile was (re)introduced near the flock() call" \
  'rm -f "${lockfile}"' "$t_g53_before_flock"

# ---- CA-159: no path is ever interpolated into a trap body string (apostrophe-safe) -----------
t_ca159_out="$(
  set +e
  # This subshell inherits a COPY of the parent script's own EXIT/INT/TERM trap (the
  # top-level "rm -rf $TMP" cleanup at the top of this file) at fork time. No backtick pair
  # in this comment -- bash 3.2 mis-parses a backtick pair inside a comment that is itself
  # inside a $( ) command substitution (confirmed empirically), the same class of bug
  # _edm-lint-lib.sh's own header already documents for a heredoc-in-process-substitution
  # case. with_state_lock/write_atomic below correctly save-and-restore whatever trap was
  # active when they install their own -- but restoring that inherited trap means it fires
  # again when THIS subshell exits, deleting the real, shared TMP out from under every later
  # test in the suite. Clear the inherited dispositions here, before either function ever
  # runs, so there is nothing dangerous left to restore.
  trap - EXIT INT TERM HUP
  tmp159="$(mktemp -d "${TMPDIR:-/tmp}/edm-ca159.XXXXXX")" || exit 1
  apos_dir="${tmp159}/o'brien"
  mkdir -p "$apos_dir" || exit 1
  command() { if [[ "${1:-}" == "-v" && "${2:-}" == "flock" ]]; then return 1; fi; builtin command "$@"; }
  source "$EDM_STATE" >/dev/null 2>&1
  lockbase="${apos_dir}/state"
  lock_ec=0
  body_out="$(with_state_lock "$lockbase" echo ca159-body-ran 2>&1)" || lock_ec=$?
  lockdir_state=absent
  [[ -d "${lockbase}.lockd" ]] && lockdir_state=present
  dest="${apos_dir}/out.txt"
  wa_ec=0
  write_atomic "$dest" echo ca159-write-ran >/dev/null 2>&1 || wa_ec=$?
  tmp_left="$(find "$apos_dir" -maxdepth 1 -name '*.tmp.*' 2>/dev/null | wc -l | tr -d ' ')"
  dest_content="$(cat "$dest" 2>/dev/null || echo absent)"
  rm -rf "$tmp159"
  printf 'lock_ec=%s lockdir=%s body_out=%s wa_ec=%s tmp_left=%s dest=%s\n' \
    "$lock_ec" "$lockdir_state" "$body_out" "$wa_ec" "$tmp_left" "$dest_content"
)" || true
check "CA-159 -- with_state_lock completes cleanly against an apostrophe-containing lockbase path" \
  "lock_ec=0" "$t_ca159_out"
check "CA-159 -- the locked body actually ran (no trap-body syntax error swallowed it)" \
  "body_out=ca159-body-ran" "$t_ca159_out"
check "CA-159 -- the lockdir is cleaned up (no leaked lock under the apostrophe path)" \
  "lockdir=absent" "$t_ca159_out"
check "CA-159 -- write_atomic completes cleanly against an apostrophe-containing destination path" \
  "wa_ec=0" "$t_ca159_out"
check "CA-159 -- write_atomic's destination file was actually written" \
  "dest=ca159-write-ran" "$t_ca159_out"
check "CA-159 -- no leaked *.tmp.* file remains after write_atomic completes" \
  "tmp_left=0" "$t_ca159_out"

# ---- CA-141a: a stale lockdir held by a genuinely dead PID is reclaimed (atomic mv-based) ------
t_ca141a_out="$(
  set +e
  # Clear inherited EXIT/INT/TERM/HUP dispositions before with_state_lock runs -- see the CA-159
  # case above for why (restoring an inherited trap on this subshell own exit deletes TMP).
  trap - EXIT INT TERM HUP
  tmp141a="$(mktemp -d "${TMPDIR:-/tmp}/edm-ca141a.XXXXXX")" || exit 1
  command() { if [[ "${1:-}" == "-v" && "${2:-}" == "flock" ]]; then return 1; fi; builtin command "$@"; }
  source "$EDM_STATE" >/dev/null 2>&1
  lockbase="${tmp141a}/state"
  lockdir="${lockbase}.lockd"
  mkdir -p "$lockdir"
  # A genuinely dead PID: spawn a child that exits on its own and reap it, so its PID cannot
  # still be alive. Deliberately NOT sleep-then-kill: `wait` on a job that was terminated by a
  # signal hangs indefinitely under `set -e` on bash 3.2 (reproduced in isolation, unrelated to
  # with_state_lock itself) -- sourcing edm-state re-enables errexit in this subshell (its own
  # top-level `set -euo pipefail` overrides the `set +e` above), so this case must avoid that
  # bash 3.2 wait-after-signal interaction rather than rely on staying errexit-free.
  ( exit 0 ) &
  deadpid=$!
  wait "$deadpid" 2>/dev/null
  echo "$deadpid" > "${lockdir}/pid"
  ec=0
  body_out="$(with_state_lock "$lockbase" echo ca141a-reclaimed)" || ec=$?
  lockdir_state=absent
  [[ -d "$lockdir" ]] && lockdir_state=present
  rm -rf "$tmp141a"
  printf 'ec=%s body_out=%s lockdir=%s\n' "$ec" "$body_out" "$lockdir_state"
)" || true
check "CA-141 -- a stale lockdir held by a genuinely dead PID is reclaimed and the lock acquired" \
  "ec=0" "$t_ca141a_out"
check "CA-141 -- the locked body runs after a dead-PID reclaim" \
  "body_out=ca141a-reclaimed" "$t_ca141a_out"
check "CA-141 -- the lockdir is cleaned up after a successful reclaim-then-acquire" \
  "lockdir=absent" "$t_ca141a_out"

# ---- CA-141b: a lockdir with an invalid (non-numeric) PID marker is also reclaimed -------------
t_ca141b_out="$(
  set +e
  # Clear inherited EXIT/INT/TERM/HUP dispositions before with_state_lock runs -- see the CA-159
  # case above for why (restoring an inherited trap on this subshell own exit deletes TMP).
  trap - EXIT INT TERM HUP
  tmp141b="$(mktemp -d "${TMPDIR:-/tmp}/edm-ca141b.XXXXXX")" || exit 1
  command() { if [[ "${1:-}" == "-v" && "${2:-}" == "flock" ]]; then return 1; fi; builtin command "$@"; }
  source "$EDM_STATE" >/dev/null 2>&1
  lockbase="${tmp141b}/state"
  lockdir="${lockbase}.lockd"
  mkdir -p "$lockdir"
  echo "not-a-pid" > "${lockdir}/pid"
  ec=0
  body_out="$(with_state_lock "$lockbase" echo ca141b-reclaimed)" || ec=$?
  rm -rf "$tmp141b"
  printf 'ec=%s body_out=%s\n' "$ec" "$body_out"
)" || true
check "CA-141 -- a lockdir with an invalid (non-numeric) PID marker is reclaimed" \
  "ec=0" "$t_ca141b_out"
check "CA-141 -- the locked body runs after an invalid-PID reclaim" \
  "body_out=ca141b-reclaimed" "$t_ca141b_out"

# ---- G29 (round-3 CA-141 re-fix): a lockdir whose pidfile literally contains "0" is reclaimed
# too, not classified live forever. `^[0-9]+$` alone accepts the literal string "0" as a
# syntactically valid PID, but `kill -0 0` targets the WHOLE PROCESS GROUP (not PID 0, which does
# not exist) and always succeeds -- so pre-fix, this case would burn all 50 retries and die,
# never reaching the reclaim path at all.
t_ca141d_out="$(
  set +e
  # Clear inherited EXIT/INT/TERM/HUP dispositions before with_state_lock runs -- see the CA-159
  # case above for why (restoring an inherited trap on this subshell own exit deletes TMP).
  trap - EXIT INT TERM HUP
  tmp141d="$(mktemp -d "${TMPDIR:-/tmp}/edm-ca141d.XXXXXX")" || exit 1
  command() { if [[ "${1:-}" == "-v" && "${2:-}" == "flock" ]]; then return 1; fi; builtin command "$@"; }
  source "$EDM_STATE" >/dev/null 2>&1
  lockbase="${tmp141d}/state"
  lockdir="${lockbase}.lockd"
  mkdir -p "$lockdir"
  echo "0" > "${lockdir}/pid"
  ec=0
  body_out="$(with_state_lock "$lockbase" echo ca141d-reclaimed)" || ec=$?
  rm -rf "$tmp141d"
  printf 'ec=%s body_out=%s\n' "$ec" "$body_out"
)" || true
check "G29 -- a lockdir whose pidfile literally contains '0' is reclaimed, not treated as forever-live" \
  "ec=0" "$t_ca141d_out"
check "G29 -- the locked body runs after a literal-'0'-PID reclaim" \
  "body_out=ca141d-reclaimed" "$t_ca141d_out"

# ---- G29 (structural): the invalid-PID reclaim path is atomic (routed through the shared
# mv-aside helper, same as the dead-PID path) and sleeps before its continue, matching the
# dead-PID path's own retry pacing rather than tight-looping.
t_g29_lock_body="$(awk '/^with_state_lock\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"
t_g29_invalid_pid_block="$(printf '%s\n' "$t_g29_lock_body" | awk '/invalid PID/{f=1} f{print} f && /continue/{exit}')"
check "G29 -- the invalid-PID reclaim branch routes through the shared atomic mv-aside helper" \
  "_edm_reclaim_stale_lockdir" "$t_g29_invalid_pid_block"
check "G29 -- the invalid-PID reclaim branch retries via the shared _lock_retry_or_die helper before its continue (no tight loop)" \
  "_lock_retry_or_die" "$t_g29_invalid_pid_block"
check "G29 -- the invalid-PID check also rejects the literal string '0'" \
  'holder_pid" == "0"' "$t_g29_invalid_pid_block"

# ---- CA-141c: a live cross-UID holder (kill -0 EPERM) is never reclaimed (narrower: kill -0 is
# mocked to fail with an "Operation not permitted"-shaped message, since actually becoming a
# second UID is not available in this harness) ---------------------------------------------------
t_ca141c_out="$(
  set +e
  # Clear inherited EXIT/INT/TERM/HUP dispositions before with_state_lock runs -- see the CA-159
  # case above for why (restoring an inherited trap on this subshell own exit deletes TMP).
  trap - EXIT INT TERM HUP
  tmp141c="$(mktemp -d "${TMPDIR:-/tmp}/edm-ca141c.XXXXXX")" || exit 1
  command() { if [[ "${1:-}" == "-v" && "${2:-}" == "flock" ]]; then return 1; fi; builtin command "$@"; }
  kill() {
    if [[ "${1:-}" == "-0" && "${2:-}" == "99999" ]]; then
      echo "kill: (99999) - Operation not permitted" >&2
      return 1
    fi
    builtin kill "$@"
  }
  source "$EDM_STATE" >/dev/null 2>&1
  lockbase="${tmp141c}/state"
  lockdir="${lockbase}.lockd"
  mkdir -p "$lockdir"
  echo "99999" > "${lockdir}/pid"
  ec=0
  out="$(with_state_lock "$lockbase" echo ca141c-should-not-run 2>&1)" || ec=$?
  rm -rf "$tmp141c"
  printf 'ec=%s out=%s\n' "$ec" "$out"
)" || true
check "CA-141 -- a live cross-UID holder (EPERM on kill -0) is never reclaimed" \
  "owned by another user" "$t_ca141c_out"
check_absent "CA-141 -- the locked body never runs against a live cross-UID holder's lock" \
  "ca141c-should-not-run" "$t_ca141c_out"

# ---- CA-141 (sub-issue 4, narrower static guard): both reclaim branches increment `tries`
# before their `continue` -- forcing 50 real reclaim-vs-recreate iterations deterministically
# would need a timing-sensitive background contender racing this process's own retry loop, which
# is exactly the kind of flaky test this suite's own conventions avoid, so the bound itself is
# checked structurally instead. The dead-PID and invalid-PID cases above already prove each
# reclaim path is reachable and functions; this proves neither path can loop unaccounted-for. ---
t_ca141_lock_body="$(awk '/^with_state_lock\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"
t_ca141_invalid_pid_block="$(printf '%s\n' "$t_ca141_lock_body" | awk '/invalid PID/{f=1} f{print} f && /continue/{exit}')"
check "CA-141 -- the invalid-PID reclaim branch retries via the shared _lock_retry_or_die helper before its continue" \
  "_lock_retry_or_die" "$t_ca141_invalid_pid_block"
t_ca141_stale_pid_block="$(printf '%s\n' "$t_ca141_lock_body" | awk '/reclaimed stale state lock/{f=1} f{print} f && /^[[:space:]]*continue$/{exit}')"
check "CA-141 -- the stale-PID reclaim branch retries via the shared _lock_retry_or_die helper before its continue" \
  "_lock_retry_or_die" "$t_ca141_stale_pid_block"

# ---- CA-142 (round-3 G2 re-fix): a write_atomic call nested inside a locked mkdir-branch body
# installs its own full trap layer unconditionally now (the previous shared-cleanup-list design
# was dead code -- see bin/edm-state's comment above _EDM_TRAP_DEPTH for the full analysis), and
# the real-world nested path (cmd_init -> with_state_lock -> _cmd_init_body -> write_atomic)
# still completes cleanly with no leaked tmp file and no leaked lockdir.
t_ca142_out="$(
  set +e
  # Clear inherited EXIT/INT/TERM/HUP dispositions before with_state_lock/write_atomic run --
  # see the CA-159 case above for why (restoring an inherited trap on this subshell own
  # exit deletes TMP).
  trap - EXIT INT TERM HUP
  tmp142="$(mktemp -d "${TMPDIR:-/tmp}/edm-ca142.XXXXXX")" || exit 1
  command() { if [[ "${1:-}" == "-v" && "${2:-}" == "flock" ]]; then return 1; fi; builtin command "$@"; }
  source "$EDM_STATE" >/dev/null 2>&1
  lockbase="${tmp142}/state"
  nested_body() {
    printf 'depth-seen=%s\n' "${_EDM_TRAP_DEPTH:-unset}"
    write_atomic "${tmp142}/dest.txt" echo ca142-nested-write
  }
  ec=0
  out="$(with_state_lock "$lockbase" nested_body 2>&1)" || ec=$?
  lockdir_state=absent
  [[ -d "${lockbase}.lockd" ]] && lockdir_state=present
  dest_content="$(cat "${tmp142}/dest.txt" 2>/dev/null || echo absent)"
  tmp_left="$(find "$tmp142" -maxdepth 1 -name '*.tmp.*' 2>/dev/null | wc -l | tr -d ' ')"
  rm -rf "$tmp142"
  printf 'ec=%s out=%s lockdir=%s dest=%s tmp_left=%s\n' "$ec" "$out" "$lockdir_state" "$dest_content" "$tmp_left"
)" || true
check "CA-142 -- with_state_lock's mkdir branch sets _EDM_TRAP_DEPTH=1 before running the locked body" \
  "depth-seen=1" "$t_ca142_out"
check "CA-142 -- a write_atomic call nested inside a locked body completes successfully (no double-trap error)" \
  "ec=0" "$t_ca142_out"
check "CA-142 -- the nested write_atomic call's destination file is written" \
  "dest=ca142-nested-write" "$t_ca142_out"
check "CA-142 -- no leaked *.tmp.* file remains from the nested write_atomic call" \
  "tmp_left=0" "$t_ca142_out"
check "CA-142 -- the lockdir is cleaned up after the nested-write_atomic body completes" \
  "lockdir=absent" "$t_ca142_out"
# The real-world nested path this fix targets (cmd_init routes _cmd_init_body's write_atomic call
# through an active with_state_lock trap) is exercised implicitly by every "$EDM_STATE" init call
# elsewhere in this suite and wave6-smoke.sh -- hundreds of them, all green -- so this case adds
# the depth assertion those calls cannot make, rather than re-proving init itself works.

# =================================================================================
# G18/CA-306 (round 5): CA-257's reposition (guard armed before BOTH acquisition branches,
# depth armed on the flock branch too) is correct code; two of its own comments described the
# old, narrower shape. Doc-only fix -- the guard's actual behavior is unchanged.
# =================================================================================
t_g18_edm_state="$(cat "$EDM_STATE")"
check "G18/CA-306 -- the reentrancy-guard section header now names both acquisition branches" \
  "the SAME guard around the flock branch's subshell too" "$t_g18_edm_state"
check_absent "G18/CA-306 -- the section header no longer claims the guard is armed only around the mkdir branch" \
  "is set to 1 for the lifetime of with_state_lock's mkdir-branch subshell and" "$t_g18_edm_state"
check "G18/CA-306 -- the guard's own comment now states it is a process-global flag, not lockbase-keyed" \
  "a single, PROCESS-GLOBAL flag, not keyed on" "$t_g18_edm_state"
check_absent "G18/CA-306 -- the guard's own comment no longer claims a different lockbase is unaffected" \
  "two with_state_lock calls against DIFFERENT lockbases never share" "$t_g18_edm_state"

# ---- CA-025: the mkdir branch now runs the locked body in a subshell (matching the flock
# branch's existing subshell semantics) -- a variable a locked body sets must not leak back into
# with_state_lock's caller. -----------------------------------------------------------------------
t_ca025_out="$(
  set +e
  # Clear inherited EXIT/INT/TERM/HUP dispositions before with_state_lock runs -- see the CA-159
  # case above for why (restoring an inherited trap on this subshell own exit deletes TMP).
  trap - EXIT INT TERM HUP
  tmp025="$(mktemp -d "${TMPDIR:-/tmp}/edm-ca025.XXXXXX")" || exit 1
  command() { if [[ "${1:-}" == "-v" && "${2:-}" == "flock" ]]; then return 1; fi; builtin command "$@"; }
  source "$EDM_STATE" >/dev/null 2>&1
  lockbase="${tmp025}/state"
  ca025_leak_probe="before"
  set_leak_var() { ca025_leak_probe="leaked-from-locked-body"; echo "body-ran"; }
  ec=0
  body_out="$(with_state_lock "$lockbase" set_leak_var 2>&1)" || ec=$?
  rm -rf "$tmp025"
  printf 'ec=%s body_out=%s leak_probe=%s\n' "$ec" "$body_out" "$ca025_leak_probe"
)" || true
check "CA-025 -- the mkdir branch runs the locked body successfully" "ec=0" "$t_ca025_out"
check "CA-025 -- the locked body's own stdout still crosses the subshell back to the caller" \
  "body_out=body-ran" "$t_ca025_out"
check "CA-025 -- a variable the locked body sets does NOT leak into with_state_lock's caller (subshell semantics, matching the flock branch)" \
  "leak_probe=before" "$t_ca025_out"

# ---- CA-143: INT/TERM traps actually terminate the process instead of resuming (static backup
# assertions -- kept alongside the real behavioral test below): confirm with_state_lock and
# write_atomic both install the exact `cleanup; exit 130`/`exit 143` trap idiom.
t_ca143_lock_body="$(awk '/^with_state_lock\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"
check "CA-143 -- with_state_lock's INT trap calls exit 130" "exit 130' INT" "$t_ca143_lock_body"
check "CA-143 -- with_state_lock's TERM trap calls exit 143" "exit 143' TERM" "$t_ca143_lock_body"
t_ca143_lock_exit_line="$(printf '%s\n' "$t_ca143_lock_body" | grep "' EXIT$" || true)"
check_absent "CA-143 -- with_state_lock's EXIT-only trap arm never calls exit itself" "exit " "$t_ca143_lock_exit_line"

t_ca143_wa_body="$(awk '/^write_atomic\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"
check "CA-143 -- write_atomic's INT trap calls exit 130" "exit 130' INT" "$t_ca143_wa_body"
check "CA-143 -- write_atomic's TERM trap calls exit 143" "exit 143' TERM" "$t_ca143_wa_body"
t_ca143_wa_exit_line="$(printf '%s\n' "$t_ca143_wa_body" | grep "' EXIT$" || true)"
check_absent "CA-143 -- write_atomic's EXIT-only trap arm never calls exit itself" "exit " "$t_ca143_wa_exit_line"

# ---- G2/G3/G4 (round-3 CA-142/CA-143/CA-184 re-fix) -- THE central regression case this wave
# exists to land: a REAL background child process, forced onto the mkdir branch, is sent a REAL
# SIGINT while genuinely blocked mid-write, and must (1) leave no *.tmp.* file behind, (2) leave
# no lockdir behind, and (3) actually die from the signal (exit 128+2=130) rather than resume.
#
# A prior round's attempt at this exact case (see CHANGELOG history for CA-143) found `kill -INT`
# targeted at a specific PID unreliable while that process is synchronously blocked waiting on a
# foreground child (this bash defers trap execution in that position), and worried that
# group-wide signaling to more faithfully reproduce a terminal Ctrl-C would kill the test driver
# itself, since a non-interactive script's background jobs normally share its own process group.
# Both obstacles are solved the same way real interactive shells solve them: `set -m` (job
# control) gives a freshly backgrounded job its OWN process group (confirmed empirically --
# verified with a standalone reproduction before landing this case: the job's pgid equals its own
# pid under `set -m`, distinct from the driver's pgid, so signaling the job's negative pgid
# reaches every process in that job -- the with_state_lock process AND the nested subshell
# write_atomic runs in -- without touching this suite's own driver process at all).
ca_wave7a_sigint_case() {
  local scratch child_script lockbase dest readyfile child_pid child_ec
  scratch="$(mktemp -d "${TMP}/edm-wave7a-sigint.XXXXXX")" || { fail "G2/G3/G4 -- mktemp failed"; return 1; }
  child_script="${scratch}/child.sh"
  lockbase="${scratch}/state"
  dest="${scratch}/dest.txt"
  readyfile="${scratch}/ready"

  # A real, separate bash process (not sourced into this suite's own shell) so a real SIGINT
  # exercises the actual trap layers installed by with_state_lock and write_atomic rather than
  # this suite's own top-level cleanup trap.
  cat > "$child_script" <<'CHILD_SCRIPT_EOF'
#!/bin/bash
set -euo pipefail
EDM_STATE_PATH="$1"; LOCKBASE="$2"; DEST="$3"; READYFILE="$4"
command() { if [[ "${1:-}" == "-v" && "${2:-}" == "flock" ]]; then return 1; fi; builtin command "$@"; }
source "$EDM_STATE_PATH" >/dev/null 2>&1
_wave7a_slow_render() {
  # write_atomic has already run mktemp and installed its own trap layer by the time this
  # renderer starts (both happen before "$@" > "$tmp" runs) -- touching READYFILE here means the
  # driver can safely signal us the instant it sees this file without a race against either step.
  touch "$READYFILE"
  sleep 5
  echo should-not-complete-render
}
_wave7a_locked_body() {
  write_atomic "$DEST" _wave7a_slow_render
}
with_state_lock "$LOCKBASE" _wave7a_locked_body
CHILD_SCRIPT_EOF
  chmod +x "$child_script"

  set -m
  "$child_script" "$EDM_STATE" "$lockbase" "$dest" "$readyfile" &
  child_pid=$!

  local waited=0
  while [[ ! -f "$readyfile" ]] && [[ $waited -lt 100 ]]; do
    sleep 0.05
    waited=$((waited + 1))
  done
  if [[ ! -f "$readyfile" ]]; then
    fail "G2/G3/G4 -- child never reached its write (could not run the SIGINT assertion)"
    kill -INT -- "-${child_pid}" 2>/dev/null || true
    wait "$child_pid" 2>/dev/null || true
    set +m
    rm -rf "$scratch"
    return 1
  fi
  # Small safety margin past the readyfile signal itself.
  sleep 0.1

  # Negative PID targets the whole process group `set -m` gave this job -- both with_state_lock's
  # own process and the nested subshell write_atomic runs in receive the signal independently.
  # G1/CA-036: `|| true` guards this kill the same way the sibling at :4788 already does -- an
  # unguarded `kill` under this script's own `set -euo pipefail` would abort the whole suite
  # (CRASH) rather than let the assertions below name a failure, on a slow runner where the child
  # has already exited by the time this signal is sent.
  kill -INT -- "-${child_pid}" || true
  child_ec=0
  wait "$child_pid" 2>/dev/null || child_ec=$?
  set +m

  local tmp_left lockdir_left dest_left
  tmp_left="$(find "$scratch" -maxdepth 1 -name '*.tmp.*' 2>/dev/null | wc -l | tr -d ' ')"
  lockdir_left=absent
  [[ -d "${lockbase}.lockd" ]] && lockdir_left=present
  dest_left=absent
  [[ -e "$dest" ]] && dest_left=present

  check "G2/G3/G4 -- the SIGINT'd child actually died from the signal (exit 128+2=130)" \
    "130" "$child_ec"
  check "G2/G3/G4 -- no *.tmp.* file remains after SIGINT mid-write on the mkdir branch" \
    "0" "$tmp_left"
  check "G2/G3/G4 -- the lockdir is gone after SIGINT mid-write on the mkdir branch" \
    "absent" "$lockdir_left"
  check "G1/CA-036 -- \$dest was never created after SIGINT interrupted the render mid-write" \
    "absent" "$dest_left"

  rm -rf "$scratch"
}
# G1/CA-036: called with a trailing `|| true` -- this function has two internal `return 1` paths
# (the "child never reached its write" guard above), and this script runs under its own top-level
# `set -euo pipefail`, so a bare call here would turn that named failure into a suite-wide CRASH
# instead of a single reported FAIL.
ca_wave7a_sigint_case || true

# ---- G4 (round-3 CA-184 re-fix): a failing locked body causes with_state_lock's mkdir branch to
# take its EXPLICIT return path (reset _EDM_TRAP_DEPTH, rm -rf the lockdir, restore the caller's
# own traps, `return $ec`) rather than merely surviving via its own EXIT trap catching a premature
# bare-statement death. Proven by installing our OWN marker trap before calling rmw_state bare (no
# `||` guard, matching rmw_state's ~30 real bare callers) with a deliberately invalid jq filter: if
# the fix is in place, with_state_lock restores OUR trap before rmw_state's own non-zero return
# propagates under `set -e` -- so OUR marker, not with_state_lock's lockdir-removal trap, is what
# fires when the subshell finally dies. Pre-fix, the bare "( "$@" )" statement would have aborted
# the shell immediately, one line before the restore ever ran, and with_state_lock's OWN trap
# (never restored) would have fired instead -- observably different from what this case checks.
tmp184="$(mktemp -d "${TMPDIR:-/tmp}/edm-ca184.XXXXXX")"
markerfile184="${tmp184}/marker"
t_ca184_ec=0
t_ca184_capture="$(
  set +e
  trap - EXIT INT TERM HUP
  command() { if [[ "${1:-}" == "-v" && "${2:-}" == "flock" ]]; then return 1; fi; builtin command "$@"; }
  source "$EDM_STATE" >/dev/null 2>&1
  export EDM_SRD_ROOT="$tmp184"
  trap 'echo original-trap-fired >> "'"$markerfile184"'"' EXIT
  rmw_state CA184 '.bad_filter_syntax((('
  echo unreachable-if-rmw-state-failed >> "$markerfile184"
)" || t_ca184_ec=$?
t_ca184_marker="$(cat "$markerfile184" 2>/dev/null || echo absent)"
t_ca184_lockdir=absent
[[ -d "${tmp184}/CA184/.edm-state.lockd" ]] && t_ca184_lockdir=present
check "G4/CA-184 -- rmw_state's bare, unguarded call to a failing locked body returns non-zero" \
  "nonzero" "$([[ $t_ca184_ec -ne 0 ]] && echo nonzero || echo zero)"
check "G4/CA-184 -- with_state_lock restored the caller's own trap before the failure propagated (explicit return path, not merely the EXIT trap)" \
  "original-trap-fired" "$t_ca184_marker"
check_absent "G4/CA-184 -- execution never resumed past the bare rmw_state call (it genuinely aborted under set -e)" \
  "unreachable-if-rmw-state-failed" "$t_ca184_marker"
check "G4/CA-184 -- the lockdir is gone after the failing locked body" \
  "absent" "$t_ca184_lockdir"
rm -rf "$tmp184"

# =================================================================================
# Code-audit round-2 remediation, Wave 4b: CA-135/CA-140/CA-137/CA-136/CA-134/CA-160/CA-056/
# CA-069/CA-154 (mechanical P2 fixes to bin/edm-state; CA-133 was already landed with CA-002 --
# _cmd_update_patterns_body's pending_entries loop already appends the trailing $'\n', verified
# by inspection rather than re-fixed here).
# =================================================================================
echo
echo "CA-135/CA-140/CA-137/CA-136/CA-134/CA-160/CA-056/CA-069/CA-154 -- Wave 4b mechanical fixes"

# ---- CA-140: schema_at_least's dead '-z "$sv"' disjunct removed; the injection-prevention
# comment above the coercion is preserved verbatim; three-valued behaviour unchanged -----------
t_ca140_body="$(awk '/^schema_at_least\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"
check_absent "CA-140 -- schema_at_least's dead '-z \"\$sv\"' disjunct is removed" \
  '-z "$sv"' "$t_ca140_body"
check "CA-140 -- the injection-prevention comment block above the coercion is preserved verbatim" \
  "A present-but-non-integer value is treated as legacy/absent" "$t_ca140_body"
ca140_empty="$(bash -c "source '$EDM_STATE' >/dev/null 2>&1; schema_at_least '' 1")"
ca140_bad="$(bash -c "source '$EDM_STATE' >/dev/null 2>&1; schema_at_least abc 1")"
ca140_below="$(bash -c "source '$EDM_STATE' >/dev/null 2>&1; schema_at_least 1 2")"
ca140_at="$(bash -c "source '$EDM_STATE' >/dev/null 2>&1; schema_at_least 2 2")"
check "CA-140 -- an absent schema_version still degrades to class 0" "0" "$ca140_empty"
check "CA-140 -- a non-integer schema_version still degrades to class 0" "0" "$ca140_bad"
check "CA-140 -- a present-but-below-minimum schema_version is still class 1" "1" "$ca140_below"
check "CA-140 -- an at-or-above-minimum schema_version is still class 2" "2" "$ca140_at"

# ---- CA-135: migrate-schema refuses a non-integer schema_version instead of silently
# coercing it to 0 and stamping schema_version=1 over it; the diagnostic prints the RAW value --
ca135_scratch="$(mktemp -d "${TMP}/edm-ca135.XXXXXX")" || fail "CA-135 -- mktemp failed"
mkdir -p "${ca135_scratch}/CA135"
cat > "${ca135_scratch}/CA135/.edm-state.json" <<'EOF'
{"prefix":"CA135","schema_version":"corrupted-not-a-number","current_phase":1,"gates_approved":[]}
EOF
set +e
ca135_ec=0
ca135_out="$(EDM_SRD_ROOT="$ca135_scratch" bash "$EDM_STATE" migrate-schema CA135 <<< "yes" 2>&1)" || ca135_ec=$?
set -e
[[ $ca135_ec -ne 0 ]] \
  && pass "CA-135 -- migrate-schema refuses a non-integer schema_version rather than exiting 0" \
  || fail "CA-135 -- expected non-zero exit against a corrupted schema_version, got 0: $ca135_out"
check "CA-135 -- the refusal names the actual raw corrupted value, not a coerced 0" \
  "corrupted-not-a-number" "$ca135_out"
check "CA-135 -- the refusal states it is refusing to guess a version" \
  "refusing to guess a version" "$ca135_out"
ca135_after="$(cat "${ca135_scratch}/CA135/.edm-state.json")"
check "CA-135 -- schema_version on disk is untouched by the refused migration (never lowered/guessed)" \
  '"corrupted-not-a-number"' "$ca135_after"

# ---- CA-135 (no regression): a genuinely-absent schema_version still migrates cleanly --------
ca135b_scratch="$(mktemp -d "${TMP}/edm-ca135b.XXXXXX")" || fail "CA-135b -- mktemp failed"
mkdir -p "${ca135b_scratch}/CA135B"
cat > "${ca135b_scratch}/CA135B/.edm-state.json" <<'EOF'
{"prefix":"CA135B","current_phase":1,"gates_approved":[]}
EOF
ca135b_out="$(EDM_SRD_ROOT="$ca135b_scratch" bash "$EDM_STATE" migrate-schema CA135B <<< "yes" 2>&1)"
check "CA-135 -- an absent schema_version (the legacy signal) still migrates to 1 cleanly" \
  "migrated CA135B: schema_version = 1" "$ca135b_out"

# ---- CA-137: dead 'found' bookkeeping removed from state_anomalies; anomaly detection itself
# is unaffected (functional regression guard) --------------------------------------------------
t_ca137_body="$(awk '/^state_anomalies\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"
check_absent "CA-137 -- state_anomalies no longer declares the dead 'found' bookkeeping variable" \
  "local found=0" "$t_ca137_body"
ca137_found_assigns="$(printf '%s\n' "$t_ca137_body" | grep -c '^[[:space:]]*found=1[[:space:]]*$' || true)"
[[ "${ca137_found_assigns:-0}" -eq 0 ]] \
  && pass "CA-137 -- zero remaining 'found=1' assignment statements inside state_anomalies" \
  || fail "CA-137 -- expected zero 'found=1' statements inside state_anomalies, found ${ca137_found_assigns}"
ca137_scratch="$(mktemp -d "${TMP}/edm-ca137.XXXXXX")" || fail "CA-137 -- mktemp failed"
mkdir -p "${ca137_scratch}/CA137"
cat > "${ca137_scratch}/CA137/.edm-state.json" <<'EOF'
{"prefix":"CA137","current_phase":2,"gates_approved":[],"estimated_size":"Unknown"}
EOF
ca137_out="$(EDM_SRD_ROOT="$ca137_scratch" bash "$EDM_STATE" validate CA137 2>&1)" || true
check "CA-137 -- state_anomalies still emits SIZE_UNKNOWN after removing the dead 'found' variable" \
  "SIZE_UNKNOWN" "$ca137_out"

# ---- CA-136: get-coverage fails loudly on an unparseable state file instead of silently
# aborting under set -euo pipefail; both previously-bare renderers now carry a fallback --------
ca136_scratch="$(mktemp -d "${TMP}/edm-ca136.XXXXXX")" || fail "CA-136 -- mktemp failed"
mkdir -p "${ca136_scratch}/CA136"
printf 'not valid json at all' > "${ca136_scratch}/CA136/.edm-state.json"
set +e
ca136_ec=0
ca136_out="$(EDM_SRD_ROOT="$ca136_scratch" bash "$EDM_STATE" get-coverage CA136 2>&1)" || ca136_ec=$?
set -e
[[ $ca136_ec -ne 0 ]] \
  && pass "CA-136 -- get-coverage fails loudly (non-zero exit) against an unparseable state file" \
  || fail "CA-136 -- expected non-zero exit against an unparseable state file, got 0: $ca136_out"
check "CA-136 -- the failure names the unparseable state file rather than aborting silently" \
  "unparseable state file" "$ca136_out"
t_ca136_body="$(awk '/^cmd_get_coverage\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"
ca136_bare_renderers="$(printf '%s\n' "$t_ca136_body" | grep -c '2>/dev/null$' || true)"
[[ "${ca136_bare_renderers:-0}" -eq 0 ]] \
  && pass "CA-136 -- no renderer inside cmd_get_coverage ends bare on '2>/dev/null' with no fallback" \
  || fail "CA-136 -- ${ca136_bare_renderers} renderer(s) still end bare on 2>/dev/null with no fallback"
ca136b_scratch="$(mktemp -d "${TMP}/edm-ca136b.XXXXXX")" || fail "CA-136b -- mktemp failed"
mkdir -p "${ca136b_scratch}/CA136B"
cat > "${ca136b_scratch}/CA136B/.edm-state.json" <<'EOF'
{"prefix":"CA136B","coverage_by_layer":{"unit":{"pct":82.4,"measured_at":"2026-08-01T00:00:00Z"}}}
EOF
ca136b_out="$(EDM_SRD_ROOT="$ca136b_scratch" bash "$EDM_STATE" get-coverage CA136B 2>&1)"
check "CA-136 -- a valid state file's whole-initiative coverage still renders (no regression)" \
  "Whole-Initiative Coverage" "$ca136b_out"

# ---- CA-134: write_atomic's ec=$? capture is guarded on the SAME statement as the risky
# command, not on a bare line after it -- so a future unprotected bare call returns the
# renderer's status instead of aborting mid-cleanup. Structural + behavioural coverage --------
t_ca134_body="$(awk '/^write_atomic\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"
check "CA-134 -- the render capture is guarded on the same statement (|| ec=\$?)" \
  '"$@" > "$tmp" || ec=$?' "$t_ca134_body"
check "CA-134 -- the mv capture is guarded on the same statement (|| ec=\$?)" \
  'mv -f "$tmp" "$dest" || ec=$?' "$t_ca134_body"
ca134_scratch="$(mktemp -d "${TMP}/edm-ca134.XXXXXX")" || fail "CA-134 -- mktemp failed"
printf 'original content\n' > "${ca134_scratch}/dest.txt"
ca134_script="${ca134_scratch}/probe.sh"
cat > "$ca134_script" <<PROBE
#!/usr/bin/env bash
set -euo pipefail
source "$EDM_STATE" >/dev/null 2>&1
fail_renderer() { echo "renderer output should never be committed"; return 1; }
write_atomic "${ca134_scratch}/dest.txt" fail_renderer
PROBE
chmod +x "$ca134_script"
set +e
ca134_ec=0
ca134_out="$(bash "$ca134_script" 2>&1)" || ca134_ec=$?
set -e
[[ $ca134_ec -ne 0 ]] \
  && pass "CA-134 -- a bare write_atomic call with a failing renderer exits non-zero rather than silently succeeding" \
  || fail "CA-134 -- expected non-zero exit from a failing renderer, got 0: $ca134_out"
check "CA-134 -- the destination file is left byte-unchanged after the failed write" \
  "original content" "$(cat "${ca134_scratch}/dest.txt")"
ca134_leftover="$(ls "${ca134_scratch}"/dest.txt.tmp.* 2>/dev/null || true)"
[[ -z "$ca134_leftover" ]] \
  && pass "CA-134 -- no leftover *.tmp.* file remains after write_atomic's failure path" \
  || fail "CA-134 -- leftover tmp file(s) found: $ca134_leftover"

# ---- CA-160: HUMAN_HOURLY_RATE_USD is passed to jq as data (--arg), never spliced into the
# program string; both HUMAN_HOURLY_RATE_USD and EDM_TOKEN_READ_LINE_CAP are validated up front -
t_ca160_metrics_body="$(awk '/^cmd_metrics_report\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"
check_absent "CA-160 -- HUMAN_HOURLY_RATE_USD is no longer spliced into the jq program string" \
  "human hourly rate: \$'\"\$HUMAN_HOURLY_RATE_USD\"'" "$t_ca160_metrics_body"
check "CA-160 -- the rate reaches jq as data via --arg" \
  '--arg rate "$HUMAN_HOURLY_RATE_USD"' "$t_ca160_metrics_body"
# G55/CA-215: derive the proof path from the suite's own $TMP scratch tree (covered by the
# suite's own cleanup trap, honors TMPDIR, and is unique per run) instead of a hardcoded /tmp
# path -- a hardcoded path is never pre-cleaned (a stale leftover from an earlier killed run, or a
# maliciously planted file, would produce a permanent false FAIL with no way to fix it from the
# test code alone) and collides across two concurrent suite runs on one machine.
ca160_proof="${TMP}/edm-ca160-proof"
rm -f "$ca160_proof"
set +e
ca160_rate_ec=0
ca160_rate_out="$(EDM_HUMAN_HOURLY_RATE_USD='150"; touch '"$ca160_proof"' #' bash "$EDM_STATE" --help 2>&1)" || ca160_rate_ec=$?
set -e
[[ $ca160_rate_ec -ne 0 ]] \
  && pass "CA-160 -- a HUMAN_HOURLY_RATE_USD value with jq-breaking characters is refused at startup" \
  || fail "CA-160 -- expected refusal of a malformed HUMAN_HOURLY_RATE_USD, got 0: $ca160_rate_out"
check "CA-160 -- the refusal names the bad rate value" "invalid HUMAN_HOURLY_RATE_USD" "$ca160_rate_out"
[[ ! -e "$ca160_proof" ]] \
  && pass "CA-160 -- the malformed rate never reached a shell/jq eval sink" \
  || { fail "CA-160 -- ${ca160_proof} exists -- the malformed rate was executed"; rm -f "$ca160_proof"; }

check "CA-160 -- EDM_TOKEN_READ_LINE_CAP validation is present next to the tail invocation" \
  "invalid EDM_TOKEN_READ_LINE_CAP" "$(awk '/^get_session_tokens_since\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"
ca160b_scratch="$(mktemp -d "${TMP}/edm-ca160b.XXXXXX")"
(
  cd "$ca160b_scratch" || exit 1
  sess_dir="${HOME}/.claude/projects/$(pwd | tr '/.' '-')"
  mkdir -p "$sess_dir"
  jq -cn '{type:"assistant",timestamp:"2026-01-01T00:00:00Z",message:{model:"claude-sonnet-4-7",usage:{input_tokens:10,output_tokens:5}}}' \
    > "${sess_dir}/a.jsonl"
  set +e
  ec=0
  out="$(EDM_TOKEN_READ_LINE_CAP='+500' bash -c "source '$EDM_STATE' >/dev/null 2>&1; get_session_tokens_since 2000-01-01T00:00:00Z" 2>&1)" || ec=$?
  set -e
  echo "ca160b_ec=$ec"
  echo "ca160b_out=$out"
  rm -rf "$sess_dir"
) > "${TMP}/ca160b.out" 2>&1 || true
ca160b_ec="$(grep '^ca160b_ec=' "${TMP}/ca160b.out" | cut -d= -f2)"
ca160b_out="$(grep '^ca160b_out=' "${TMP}/ca160b.out" | cut -d= -f2-)"
[[ "${ca160b_ec:-0}" -ne 0 ]] \
  && pass "CA-160 -- a leading-'+' EDM_TOKEN_READ_LINE_CAP is refused rather than silently inverting tail's meaning" \
  || fail "CA-160 -- expected refusal of EDM_TOKEN_READ_LINE_CAP=+500, got exit ${ca160b_ec:-0}: $ca160b_out"
check "CA-160 -- the refusal names the bad line-cap value" "invalid EDM_TOKEN_READ_LINE_CAP" "$ca160b_out"

# ---- G75/CA-235: regression coverage for CA-157's arithmetic-context injection guard on
# phase-start's and phase-complete's phase-number argument. CA-157 added the guard; nothing
# proved it actually works or stays working. Mirrors the CA-160 case's shape immediately above:
# an injection payload as the untrusted argument, asserting BOTH the refusal message and that the
# proof file was never created, using the suite's own $TMP scratch var (never a hardcoded /tmp
# path, same reasoning as G55 above). The phase-num validation in both commands runs before any
# state file is read or resolved, so a real initiative prefix is not required for this to prove
# the guard fires.
ca157_ps_proof="${TMP}/edm-ca157-ps-proof"
rm -f "$ca157_ps_proof"
check_fails "G75/CA-157 -- phase-start refuses an arithmetic-context injection in phase-num" \
  "phase-num must be 1-6" \
  "$EDM_STATE" phase-start CA157PS "a[\$(touch ${ca157_ps_proof})]"
[[ ! -e "$ca157_ps_proof" ]] \
  && pass "G75/CA-157 -- phase-start's injection payload was never executed" \
  || { fail "G75/CA-157 -- ${ca157_ps_proof} exists -- phase-start's injection payload was executed"; rm -f "$ca157_ps_proof"; }

ca157_pc_proof="${TMP}/edm-ca157-pc-proof"
rm -f "$ca157_pc_proof"
check_fails "G75/CA-157 -- phase-complete refuses an arithmetic-context injection in phase-num" \
  "phase-num must be 1-6" \
  "$EDM_STATE" phase-complete CA157PC "a[\$(touch ${ca157_pc_proof})]"
[[ ! -e "$ca157_pc_proof" ]] \
  && pass "G75/CA-157 -- phase-complete's injection payload was never executed" \
  || { fail "G75/CA-157 -- ${ca157_pc_proof} exists -- phase-complete's injection payload was executed"; rm -f "$ca157_pc_proof"; }

# ---- CA-056: the pattern-library heading match and pre-flight duplicate check are
# fence-aware, and refuse (rather than guess) when a heading is ambiguous outside fences -------
check "CA-056 -- edm-state sources the shared line-classification library" \
  'source "${SCRIPT_DIR}/_edm-lint-lib.sh"' "$(cat "$EDM_STATE")"
ca056_scratch="$(mktemp -d "${TMP}/edm-ca056.XXXXXX")" || fail "CA-056 -- mktemp failed"
cat > "${ca056_scratch}/doc.md" <<'EOF'
## Top Recurring Findings

body

## Anti-Patterns

Here is an example of the Append Schema shown in a fence:

```markdown
## Anti-Patterns
### Example Fenced Heading
```

Some real content in the real Anti-Patterns section.

## Pre-Flight Checklist

body

## What Good Looks Like
EOF
ca056_line="$(bash -c "source '$EDM_STATE' >/dev/null 2>&1; pattern_insert_line_for '${ca056_scratch}/doc.md' '## Anti-Patterns'")"
ca056_line_content="$(sed -n "${ca056_line}p" "${ca056_scratch}/doc.md")"
check_absent "CA-056 -- the insertion point for a heading with a fenced example does not land inside the fence" \
  '```' "$ca056_line_content"
[[ "$ca056_line" -eq 10 ]] \
  && pass "CA-056 -- the real (non-fenced) '## Anti-Patterns' heading is matched, not the fenced example" \
  || fail "CA-056 -- expected insert_line=10 (the real heading line), got $ca056_line"

cat > "${ca056_scratch}/dup.md" <<'EOF'
## Top Recurring Findings

body

## Anti-Patterns

first section body

## Anti-Patterns

second section body (duplicate heading, outside any fence)

## Pre-Flight Checklist

body

## What Good Looks Like
EOF
set +e
ca056_dup_ec=0
ca056_dup_out="$(bash -c "source '$EDM_STATE' >/dev/null 2>&1; pattern_insert_line_for '${ca056_scratch}/dup.md' '## Anti-Patterns'" 2>&1)" || ca056_dup_ec=$?
set -e
[[ $ca056_dup_ec -ne 0 ]] \
  && pass "CA-056 -- an ambiguous heading (occurs twice outside fences) is refused rather than guessed" \
  || fail "CA-056 -- expected refusal on an ambiguous heading, got 0: $ca056_dup_out"
check "CA-056 -- the refusal names the ambiguous heading and the occurrence count" \
  "occurs 2 times outside fenced code blocks" "$ca056_dup_out"

cat > "${ca056_scratch}/preflight.md" <<'EOF'
## Top Recurring Findings

body

## Anti-Patterns

An example of the Append Schema, showing the exact heading shape a real entry uses -- this is
documentation, not a real entry, so its title must not count as an existing duplicate:

```markdown
### Fenced Example Duplicate Heading
```

## Pre-Flight Checklist

body

## What Good Looks Like
EOF
cat > "${ca056_scratch}/audit-report.md" <<'EOF'
# Mock Audit Report

### Fenced Example Duplicate Heading
Novel finding whose title collides only with a FENCED example in the pattern doc, not a real
entry -- the fence-aware pre-flight check must still append it once.
EOF
ca056_body_out="$(bash -c "
  source '$EDM_STATE' >/dev/null 2>&1
  _cmd_update_patterns_body '${ca056_scratch}/preflight.md' '${ca056_scratch}/audit-report.md' '## Anti-Patterns' code CA056 2026-08-06
" 2>&1)"
check "CA-056 -- a heading that only textually matches a FENCED example is treated as novel, not a duplicate" \
  "1" "$(printf '%s\n' "$ca056_body_out" | tail -1)"

# ---- CA-154/CA-005: the cross-reference comments name the whole convention (not just one
# sibling file), and every bin/ helper + evals/ driver now sources ONE shared print_help
# (_edm-cli-lib.sh) instead of hand-copying the sentinel-extraction awk literal -------------------
check "CA-154 -- bin/edm-state's cross-reference names the whole bin/+evals convention" \
  "every \`bin/\` helper and the three \`evals/\` drivers" "$(cat "$EDM_STATE")"
check "CA-154 -- bin/edm-lint-artifacts' cross-reference names the whole bin/+evals convention" \
  "every \`bin/\` helper and the three \`evals/\` drivers" "$(cat "${PLUGIN_DIR}/bin/edm-lint-artifacts")"
ca154_form_b_hits="$(grep -rl 'sub(/^# ?/,""' "${PLUGIN_DIR}/bin" "${PLUGIN_DIR}/evals" 2>/dev/null | grep -v '/tests/' || true)"
[[ -z "$ca154_form_b_hits" ]] \
  && pass "CA-154 -- zero remaining form-B (leading-hash-stripping) print_help sites; all agree" \
  || fail "CA-154 -- form-B print_help site(s) still present: $ca154_form_b_hits"
# CA-005: the extractor awk literal itself may now appear in exactly ONE file in the whole
# plugin -- bin/_edm-cli-lib.sh. Any second occurrence anywhere under bin/ or evals/ (outside
# bin/tests/, which legitimately re-derives it for its own doc-vs-dispatch cross-check) means a
# script re-introduced a hand-copied extractor instead of sourcing the shared one.
ca005_awk_hits="$(grep -rl '/\^# EDM-HELP-BEGIN/{f=1;next} /\^# EDM-HELP-END/{f=0} f' "${PLUGIN_DIR}/bin" "${PLUGIN_DIR}/evals" 2>/dev/null | grep -v '/tests/' || true)"
[[ "$ca005_awk_hits" == "${PLUGIN_DIR}/bin/_edm-cli-lib.sh" ]] \
  && pass "CA-005 -- the EDM-HELP sentinel-extractor awk literal exists in exactly one file (_edm-cli-lib.sh)" \
  || fail "CA-005 -- expected the extractor literal ONLY in _edm-cli-lib.sh, found: $ca005_awk_hits"
for ca154_f in edm-state edm-lint-artifacts edm-validate-prefix edm-init edm-check-vocabulary edm-check-grants edm-compare-eval edm-check-skill-sync edm-sync-canonical-sections; do
  ca154_hit="$(grep -c 'source "\${SCRIPT_DIR}/_edm-cli-lib\.sh"' "${PLUGIN_DIR}/bin/${ca154_f}" 2>/dev/null || true)"
  [[ "${ca154_hit:-0}" -ge 1 ]] \
    && pass "CA-005/CA-154 -- bin/${ca154_f} sources the shared _edm-cli-lib.sh print_help" \
    || fail "CA-005/CA-154 -- bin/${ca154_f} does not source the shared print_help"
done
# G66: all three evals/ drivers now source _edm-cli-lib.sh via the identical literal form
# `source "${SCRIPT_DIR}/../bin/_edm-cli-lib.sh"` (run-eval.sh previously used its own
# EDM_BIN_DIR-relative variant) -- this assertion requires the exact literal form rather than a
# loose substring match, so a future re-divergence fails this check instead of passing silently.
for ca154_ef in run-eval.sh score-artifacts.sh tiering-matrix.sh; do
  ca154_hit="$(grep -c 'source "\${SCRIPT_DIR}/\.\./bin/_edm-cli-lib\.sh"' "${PLUGIN_DIR}/evals/${ca154_ef}" 2>/dev/null || true)"
  [[ "${ca154_hit:-0}" -ge 1 ]] \
    && pass "CA-005/CA-154/G66 -- evals/${ca154_ef} sources _edm-cli-lib.sh via the standardized \${SCRIPT_DIR}/../bin/ form" \
    || fail "CA-005/CA-154/G66 -- evals/${ca154_ef} does not source the shared print_help via the standardized form"
done

echo
echo "=== CA-148/CA-149: .gitignore actually covers the lock/temp paths edm-state derives from lockbase, including a relocated (non-\"SRD\"-named) srd_root ==="
ca148_gitignore_case() {
  local scratch repo_root
  scratch="$(mktemp -d "${TMP}/edm-ca148.XXXXXX")" || { fail "CA-148 -- mktemp failed"; return 1; }
  repo_root="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  [[ -f "${repo_root}/.gitignore" ]] || { fail "CA-148 -- repo-root .gitignore not found at ${repo_root}"; return 1; }

  ( cd "$scratch" && git init -q && git config user.email t@t && git config user.name t )
  cp "${repo_root}/.gitignore" "${scratch}/.gitignore"
  ( cd "$scratch" && git add .gitignore && git commit -qm "seed real .gitignore" )

  # Deliberately NOT named "SRD" and nested two levels deep -- reproduces the exact relocated-tree
  # shape CA-149 fixes: a literal "SRD/" prefix in .gitignore never matches this path regardless
  # of depth, because the directory is not named "SRD" at all.
  local relroot="${scratch}/artifacts/nested-root"

  # ---- Real state mutation (CA-148): edm-state init acquires and releases a real lock around
  # a real write_atomic call, and leaves the state file itself on disk afterward.
  local init_out init_ec=0
  init_out="$(EDM_SRD_ROOT="$relroot" edm-state init CA148 2>&1)" || init_ec=$?
  [[ "$init_ec" -eq 0 ]] \
    && pass "CA-148 -- edm-state init succeeded against a relocated, non-SRD-named srd_root" \
    || { fail "CA-148 -- edm-state init failed (exit ${init_ec}): $init_out"; rm -rf "$scratch"; return 1; }

  local state_file="${relroot}/CA148/.edm-state.json"
  [[ -f "$state_file" ]] \
    && pass "CA-148 -- the real state file exists at the path edm-state actually created" \
    || { fail "CA-148 -- expected state file not found at ${state_file}"; rm -rf "$scratch"; return 1; }

  # ---- Enumerate the lock/temp paths edm-state derives from this real state file's own path,
  # using the identical formula cmd_init/with_state_lock/write_atomic use in bin/edm-state
  # (lockbase="${f%.json}"; lockfile="${lockbase}.lock"; lockdir="${lockbase}.lockd";
  # write_atomic's staging file is "${dest}.tmp.XXXXXX") -- never a hand-typed guess at the name.
  local lockbase="${state_file%.json}"
  local lockfile="${lockbase}.lock"
  local lockdir="${lockbase}.lockd"
  local statetmp="${state_file}.tmp.ABC123"
  local mdtmp="${relroot}/CA148/decisions.md.tmp.XYZ789"
  # G52/CA-212: the atomic stale-lock-aside name _edm_reclaim_stale_lockdir derives, using the
  # SAME "${lockdir}.stale.$$" formula the source uses (bin/edm-state's with_state_lock mkdir
  # branch) -- never a hand-typed guess at the shape.
  local lockdir_stale="${lockdir}.stale.$$"
  # G15/CA-256 (round 5): the G49 flock-timeout marker, using the SAME "${lockfile}.timeout.$$"
  # formula with_state_lock's flock branch uses (bin/edm-state:1079) -- never a hand-typed guess.
  # This name matches neither the ".lock" nor ".lockd" shapes above by one character (it hangs
  # off ".lock", not ".lockd"), which is exactly how it escaped every existing pattern.
  local lock_timeout_marker="${lockfile}.timeout.$$"

  touch "$lockfile"
  mkdir -p "$lockdir"
  touch "$statetmp"
  touch "$mdtmp"
  mkdir -p "$lockdir_stale"
  touch "$lock_timeout_marker"

  local ca148_path ca148_label ca148_entry
  for ca148_entry in \
    "${lockfile}|.edm-state.lock (with_state_lock's flock path)" \
    "${lockdir}|.edm-state.lockd/ (with_state_lock's mkdir-spinlock fallback)" \
    "${statetmp}|.edm-state.json.tmp.* (write_atomic staging the state file itself)" \
    "${mdtmp}|*.md.tmp.* (write_atomic staging an arbitrary artifact, e.g. decisions.md)" \
    "${lockdir_stale}|.edm-state.lockd.stale.PID (with_state_lock's atomic stale-lock-aside name, G29/CA-141 + G52/CA-212)" \
    "${lock_timeout_marker}|.edm-state.lock.timeout.PID (with_state_lock's G49 flock-timeout marker, G15/CA-256)"
  do
    ca148_path="${ca148_entry%%|*}"
    ca148_label="${ca148_entry#*|}"
    if git -C "$scratch" check-ignore -q "$ca148_path"; then
      pass "CA-148/CA-149 -- git check-ignore -q succeeds for ${ca148_label}"
    else
      fail "CA-148/CA-149 -- git check-ignore -q did NOT match ${ca148_label} at ${ca148_path}"
    fi
  done

  rm -rf "$scratch"
}
ca148_gitignore_case

# =================================================================================
# G15/CA-256 (round 5): the CA-148 case above only proves .gitignore covers the marker's name --
# it never proved either destination sweep (_cmd_archive_move_body, _cmd_migrate_path_move_body)
# actually REMOVES one. Plant a real flock-timeout marker and confirm the archive sweep removes
# it from the archived destination, exercising the quoted, looped glob fix directly rather than
# grepping for its source text.
# =================================================================================
echo
echo "=== G15/CA-256: the archive move body's marker sweep actually removes a flock-timeout marker, not just .gitignores it ==="
g15_archive_sweep_case() {
  export EDM_MODE="prototype"
  "$EDM_STATE" init G15ARCH >/dev/null
  unset EDM_MODE
  "$EDM_STATE" approve-gate G15ARCH 1 >/dev/null
  local state_g15arch="SRD/G15ARCH/.edm-state.json"
  jq '.current_phase = 2 | .phase_durations["2_phase"] = {started_at: "2026-01-01T00:00:00Z", completed_at: "2026-01-01T01:00:00Z"}' \
    "$state_g15arch" > "${state_g15arch}.tmp" && mv "${state_g15arch}.tmp" "$state_g15arch"
  local lockbase="${state_g15arch%.json}"
  local timeout_marker="${lockbase}.lock.timeout.99999"
  touch "$timeout_marker"
  local out ec=0
  out="$("$EDM_STATE" archive G15ARCH 2>&1)" || ec=$?
  [[ $ec -eq 0 ]] \
    && pass "G15/CA-256 -- archive still succeeds with a flock-timeout marker present at the source" \
    || fail "G15/CA-256 -- archive failed (exit ${ec}) with a flock-timeout marker present: $out"
  local dst_marker="SRD/.archived/G15ARCH/.edm-state.lock.timeout.99999"
  [[ ! -e "$dst_marker" ]] \
    && pass "G15/CA-256 -- the flock-timeout marker is actually removed from the archived destination (the sweep ran, not merely .gitignored)" \
    || fail "G15/CA-256 -- the flock-timeout marker leaked into the archived destination at ${dst_marker}"
  [[ -d "SRD/.archived/G15ARCH" ]] \
    && pass "G15/CA-256 -- the archived directory itself exists (the marker sweep did not abort or skip the move)" \
    || fail "G15/CA-256 -- SRD/.archived/G15ARCH not found after archive"
}
with_scratch_repo g15_archive_sweep_case

g15_migrate_sweep_case() {
  "$EDM_STATE" init G15MIG >/dev/null
  local state_g15mig="SRD/G15MIG/.edm-state.json"
  local lockbase="${state_g15mig%.json}"
  local timeout_marker="${lockbase}.lock.timeout.88888"
  touch "$timeout_marker"
  local out ec=0
  out="$("$EDM_STATE" migrate-path --product g15prod --description g15desc G15MIG 2>&1)" || ec=$?
  [[ $ec -eq 0 ]] \
    && pass "G15/CA-256 -- migrate-path still succeeds with a flock-timeout marker present at the source" \
    || fail "G15/CA-256 -- migrate-path failed (exit ${ec}) with a flock-timeout marker present: $out"
  local dst_marker="SRD/g15prod/G15MIG__g15desc/.edm-state.lock.timeout.88888"
  [[ ! -e "$dst_marker" ]] \
    && pass "G15/CA-256 -- the flock-timeout marker is actually removed from the migrated destination" \
    || fail "G15/CA-256 -- the flock-timeout marker leaked into the migrated destination at ${dst_marker}"
  [[ -f "SRD/g15prod/G15MIG__g15desc/.edm-state.json" ]] \
    && pass "G15/CA-256 -- the migrated state file itself exists (the marker sweep did not abort the move)" \
    || fail "G15/CA-256 -- SRD/g15prod/G15MIG__g15desc/.edm-state.json not found after migrate-path"
}
with_scratch_repo g15_migrate_sweep_case

# =================================================================================
# G5 (round-3 Wave 7b, RE-OPENED CA-036) / G1 (round-4, CA-036 widened): tripwire against the
# unguarded command-substitution-then-bare-$?-capture shape and its siblings.
# =================================================================================
# CA-036 was fixed once, then reintroduced by the CA-040 remediation (three sites in
# wave6-smoke.sh) plus two pre-existing siblings (one in wave6-smoke.sh, one in
# wave7-smoke.sh) -- all five closed in round 3. Under `set -euo pipefail`, a `VAR="$(cmd)"`
# assignment whose substitution fails aborts the shell right there; a bare exit-code capture
# on a separate statement -- whether on the same physical line via `;`, or the very next
# physical line -- never runs, so the `fail` branch it exists to reach is unreachable dead
# code. The guard must live on the SAME statement (`|| VAR2=$?`), or the whole pair must be
# bracketed in `set +e` / `set -e`.
#
# G1/CA-036 (round 4): the round-3 detector only recognized ONE shape -- a QUOTED command
# substitution assigned to a bare variable. Three more shapes carry the identical hazard and
# were invisible to it: (a) a PLAIN command (no assignment at all) followed by a bare $?
# capture on the next line -- exactly wave7-smoke.sh's own T43/T23/T67 live instances this
# round; (b) a `local`-prefixed assignment; (c) an UNQUOTED command substitution
# (`VAR=$(cmd)`, no quotes). The widened detector below adds all three as additional
# alternatives, tracks a `set +e`/`set -e` bracket (a command inside one cannot abort the
# shell, so a bare $? capture there is genuinely safe and must not be flagged), and carries
# one new synthetic positive-control fragment per new alternative.
#
# The positive-control file below is assembled from separate literal fragments (never the
# hazard shapes as adjacent text in THIS file) precisely so this section does not trip its own
# tripwire when the real scan two paragraphs down globs this very file.
echo
echo "G5/G1 -- tripwire: bin/tests/*.sh never captures a command's exit code with a bare \$? on a separate, unguarded statement (quoted/unquoted cmdsub, local-prefixed, or a plain command)"
g5_scratch="$(mktemp -d "${TMP}/edm-g5-tripwire.XXXXXX")" || fail "G5/G1 -- mktemp failed"
g5_detector="${g5_scratch}/detect.awk"
cat > "$g5_detector" <<'G5AWK'
FNR==1 { prev_bare = 0; prev_plain = 0; guarded = 0 }
{
  line = $0

  # A command inside a set +e / set -e bracket cannot abort the shell, so a bare $? capture
  # anywhere inside the bracket is genuinely safe -- exclude the whole region from every
  # alternative below rather than just the two boundary lines.
  if (line ~ /^[[:space:]]*set[[:space:]]+\+e([[:space:]]|$)/) { guarded = 1 }

  # ---- same-line shapes: `VAR="$(cmd)"; VAR2=$?` and the unquoted `VAR=$(cmd); VAR2=$?` -----
  if (!guarded && line ~ /^[[:space:]]*(local[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*="\$\(.*\)"[[:space:]]*;[[:space:]]*(local[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=\$\?[[:space:]]*(#.*)?$/) {
    print FILENAME ":" FNR ": same-line (quoted cmdsub)"
  }
  if (!guarded && line ~ /^[[:space:]]*(local[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=\$\(.*\)[[:space:]]*;[[:space:]]*(local[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=\$\?[[:space:]]*(#.*)?$/) {
    print FILENAME ":" FNR ": same-line (unquoted cmdsub)"
  }

  is_bare_capture = (line ~ /^[[:space:]]*(local[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=\$\?[[:space:]]*(#.*)?$/)
  is_quoted_cmdsub = (line ~ /^[[:space:]]*(local[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*="\$\(.*\)"[[:space:]]*(#.*)?$/)
  is_unquoted_cmdsub = (line ~ /^[[:space:]]*(local[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=\$\(.*\)[[:space:]]*(#.*)?$/)
  # A "plain command" candidate: a real statement that is none of the above, not blank or a
  # comment, not a control-flow keyword line, not already guarded by its own `||`/`&&`, and
  # not a continuation line -- i.e. exactly wave7's T43/T23/T67 shape, generalized.
  is_plain_cmd = (line !~ /^[[:space:]]*(#.*)?$/) && !is_bare_capture && !is_quoted_cmdsub && !is_unquoted_cmdsub \
    && (line !~ /\|\|/) && (line !~ /&&/) \
    && (line !~ /^[[:space:]]*(if|elif|else|fi|while|until|do|done|for|case|esac|then|\{|\}|set[[:space:]]+[-+]e)\b/) \
    && (line !~ /\\$/)

  if (!guarded && prev_bare && is_bare_capture) {
    print FILENAME ":" (FNR-1) "-" FNR ": next-line (cmdsub, quoted or unquoted, optionally local-prefixed)"
  }
  if (!guarded && prev_plain && is_bare_capture) {
    print FILENAME ":" (FNR-1) "-" FNR ": next-line (plain command)"
  }

  prev_bare = (is_quoted_cmdsub || is_unquoted_cmdsub)
  prev_plain = is_plain_cmd

  if (line ~ /^[[:space:]]*set[[:space:]]+-e([[:space:]]|$)/) { guarded = 0 }

  # G4/CA-036 (round 5): `guarded` was purely lexical -- only a literal `set -e` line cleared
  # it. This codebase's dominant subshell-probe idiom opens a command substitution with `set +e`
  # and a trap reset, then never has a matching `set -e` because the scope closes with the
  # subshell itself (`)"`, optionally followed by `|| true` or a capture). Without this rule,
  # guarded latches to 1 at the first such site and never clears for the rest of the file,
  # blinding the detector to every later hazard regardless of file position. A closing `)"` ends
  # the subshell's `set +e` disposition exactly as surely as a `set -e` would, so it clears the
  # flag too.
  if (line ~ /^[[:space:]]*\)"/) { guarded = 0 }
}
G5AWK

g5_pc_var1="pc_same"
g5_pc_var2="pc_next"
g5_pc_var3="pc_local"
g5_pc_var4="pc_usame"
g5_pc_var5="pc_unext"
g5_pc_var6="pc_plaincmd"
g5_pc_var7="pc_boundary"
g5_pc_file="${g5_scratch}/positive-control.sh"
{
  printf '%s="$(false)"; %s=$?\n' "$g5_pc_var1" "${g5_pc_var1}_ec"
  printf '%s="$(false)"\n' "$g5_pc_var2"
  printf '%s=$?\n' "${g5_pc_var2}_ec"
  printf 'local %s="$(false)"\n' "$g5_pc_var3"
  printf 'local %s=$?\n' "${g5_pc_var3}_ec"
  printf '%s=$(false); %s=$?\n' "$g5_pc_var4" "${g5_pc_var4}_ec"
  printf '%s=$(false)\n' "$g5_pc_var5"
  printf '%s=$?\n' "${g5_pc_var5}_ec"
  printf 'true\n'
  printf '%s=$?\n' "${g5_pc_var6}_ec"
  # G4/CA-036 (round 5): a hazard placed AFTER an unpaired `set +e` inside a closed command
  # substitution -- the exact shape the subshell-boundary-close fix above exists to catch. The
  # pre-fix detector would latch guarded=1 at "set +e" and never see the `)"` close, so the bare
  # capture on the final line would be silently missed.
  printf '%s="$(\n' "$g5_pc_var7"
  printf '  set +e\n'
  printf '  false\n'
  printf ')"\n'
  printf '%s=$?\n' "${g5_pc_var7}_ec"
} > "$g5_pc_file"

g5_pc_hits="$(awk -f "$g5_detector" "$g5_pc_file" 2>/dev/null | wc -l | tr -d ' ')" || g5_pc_hits=0
[[ "${g5_pc_hits:-0}" -eq 7 ]] \
  && pass "G5/G1 -- the detector catches all seven shapes (same-line/next-line x quoted/unquoted, local-prefixed, plain command, post-subshell-boundary) on a synthetic positive control" \
  || fail "G5/G1 -- detector found ${g5_pc_hits:-0} hit(s) on the positive control, expected 7 (the widened pattern does not actually catch every bug shape)"

g5_real_hit_lines="$(awk -f "$g5_detector" "${PLUGIN_DIR}"/bin/tests/*.sh 2>/dev/null)" || g5_real_hit_lines=""
g5_real_hits="$(printf '%s\n' "$g5_real_hit_lines" | grep -c . || true)"
[[ "${g5_real_hits:-0}" -eq 0 ]] \
  && pass "G5/G1 -- zero unguarded command/\$? sites across bin/tests/*.sh (quoted, unquoted, local-prefixed, or plain command)" \
  || fail "G5/G1 -- found ${g5_real_hits} unguarded site(s) across bin/tests/*.sh (CA-036 class re-opened):\n${g5_real_hit_lines}"

rm -rf "$g5_scratch"

# =================================================================================
# G6 (round-3 Wave 7b): tripwire against a hard `bc` dependency re-entering the suite.
# =================================================================================
# CA-035's T42 AC4 fix piped a grep -c count through `paste -sd+ -` into `bc` -- the only such
# invocation anywhere in this plugin, and no `apk add --no-cache` line in .gitlab-ci.yml
# installs it, so it crashed both blocking smoke jobs on every pinned image. Replaced above
# with pure awk arithmetic (awk is already a hard dependency of every suite here). This is the
# regression tripwire so the dependency cannot silently come back. The search token is
# assembled from two single-character fragments (never spelled out as adjacent literal
# characters in this file) so this section cannot trip its own assertion.
echo
echo "G6 -- tripwire: zero shell-outs to the bc utility anywhere under plugins/edm/"
g6_scratch="$(mktemp -d "${TMP}/edm-g6-bc.XXXXXX")" || fail "G6 -- mktemp failed"
g6_bin="b"
g6_bin="${g6_bin}c"
g6_pattern="(\\| *${g6_bin}\\b|${g6_bin}\\)[\"'])"

g6_pc_file="${g6_scratch}/positive-control.sh"
printf '%s\n' "grep -c pattern file | paste -sd+ - | ${g6_bin}" > "$g6_pc_file"
g6_pc_hits="$(grep -rnE "$g6_pattern" "$g6_pc_file" 2>/dev/null | grep -c . || true)"
[[ "${g6_pc_hits:-0}" -eq 1 ]] \
  && pass "G6 -- the detector catches a synthetic bc pipeline planted in a scratch copy" \
  || fail "G6 -- detector found ${g6_pc_hits:-0} hit(s) on the positive control, expected 1"

g6_real_hit_lines="$(grep -rnE "$g6_pattern" "${PLUGIN_DIR}/" 2>/dev/null)" || g6_real_hit_lines=""
g6_real_hits="$(printf '%s\n' "$g6_real_hit_lines" | grep -c . || true)"
[[ "${g6_real_hits:-0}" -eq 0 ]] \
  && pass "G6 -- zero bc invocations anywhere under plugins/edm/" \
  || fail "G6 -- found ${g6_real_hits} bc invocation(s) under plugins/edm/ (no CI image installs it):\n${g6_real_hit_lines}"

rm -rf "$g6_scratch"

# =================================================================================
# G8 (round-3 Wave 7c): a trailing-slash or absolute srd_root must not silently disable
# commit-time enforcement. Extracts the real PreToolUse git-commit hook command (same jq
# extraction pattern T67 AC8 uses above) and runs it against a scratch git repo with stub
# edm-state/edm-lint-artifacts binaries, so this exercises the actual shipped hook script, not a
# hand-written stand-in for it.
# =================================================================================
g8_srd_root_case() {
  local scratch cmdfile cmd out ec repo_root_g3
  scratch="$(mktemp -d "${TMP}/edm-g8.XXXXXX")" || { fail "G8 -- mktemp failed"; return 1; }
  mkdir -p "${scratch}/SRD/FOOG8" "${scratch}/bin"
  ( cd "$scratch" && git init -q && git config user.email t@t && git config user.name t )
  repo_root_g3="$(cd "$scratch" && git rev-parse --show-toplevel)"

  cat > "${scratch}/bin/edm-state" <<'EOS'
#!/bin/bash
case "$1" in
  resolve-dir) echo "SRD/FOOG8"; exit 0 ;;
esac
EOS
  cat > "${scratch}/bin/edm-lint-artifacts" <<'EOS'
#!/bin/bash
echo "SRD/FOOG8/planning.md:1: unicode: synthetic violation"
exit 1
EOS
  chmod +x "${scratch}/bin/edm-state" "${scratch}/bin/edm-lint-artifacts"
  echo "hello" > "${scratch}/SRD/FOOG8/planning.md"
  ( cd "$scratch" && git add SRD/FOOG8/planning.md bin/edm-state bin/edm-lint-artifacts )

  cmdfile="${scratch}/hook-command.sh"
  jq -r '.hooks.PreToolUse[] | select(.matcher == "git commit") | .hooks[0].command' \
    "${PLUGIN_DIR}/hooks/hooks.json" > "$cmdfile" 2>/dev/null
  cmd="$(cat "$cmdfile" 2>/dev/null || true)"
  if [[ -z "$cmd" ]]; then
    fail "G8 -- could not extract the PreToolUse git-commit hook command from hooks.json"
    rm -rf "$scratch"
    return 1
  fi

  # Case 1: a trailing slash (EDM_SRD_ROOT=SRD/) must not silently disable enforcement -- the
  # original bug (an unnormalized trailing slash makes the awk prefix match against "SRD//",
  # which never matches a real staged path, so `prefixes` was silently empty).
  ec=0
  out="$(cd "$scratch" && PATH="${scratch}/bin:${PATH}" EDM_SRD_ROOT="SRD/" bash "$cmdfile" 2>&1)" || ec=$?
  [[ "$ec" -eq 2 && "$out" == *"FOOG8"* ]] \
    && pass "G8 -- EDM_SRD_ROOT=SRD/ (trailing slash) still detects the violation and blocks (hook exit 2)" \
    || fail "G8 -- EDM_SRD_ROOT=SRD/ produced exit=${ec}, output: ${out} (expected exit 2 naming FOOG8 -- a trailing slash must not silently disable enforcement)"

  # Case 2: a leading ./ combined with a trailing slash (EDM_SRD_ROOT=./SRD/).
  ec=0
  out="$(cd "$scratch" && PATH="${scratch}/bin:${PATH}" EDM_SRD_ROOT="./SRD/" bash "$cmdfile" 2>&1)" || ec=$?
  [[ "$ec" -eq 2 && "$out" == *"FOOG8"* ]] \
    && pass "G8 -- EDM_SRD_ROOT=./SRD/ still detects the violation and blocks (hook exit 2)" \
    || fail "G8 -- EDM_SRD_ROOT=./SRD/ produced exit=${ec}, output: ${out} (expected exit 2 naming FOOG8)"

  # Case 3 (round-4 CA-186 G3 fix): an absolute srd_root that cannot be relativized under the
  # repository root now prints a diagnostic AND exits 1 -- transcript-visible, but not blocking
  # (a misconfiguration, not a security violation). It previously exited 0, which sent the
  # diagnostic to the debug log only, never the transcript -- silent loss of enforcement.
  ec=0
  out="$(cd "$scratch" && PATH="${scratch}/bin:${PATH}" EDM_SRD_ROOT="/nonexistent/absolute/SRD" bash "$cmdfile" 2>&1)" || ec=$?
  [[ "$ec" -eq 1 && "$out" == *"srd_root is absolute"* ]] \
    && pass "CA-186 G3 -- an absolute EDM_SRD_ROOT outside the repo prints a transcript-visible diagnostic and exits 1 (not 0, not blocking)" \
    || fail "CA-186 G3 -- absolute EDM_SRD_ROOT produced exit=${ec}, output: ${out} (expected exit 1 with an absolute-path diagnostic)"

  # Case 3b: the bare filesystem root "/" is also absolute and must be classified as such rather
  # than being reduced to an empty string by an out-of-order trailing-slash collapse (the second
  # CA-186 residual bug: the absolute check must run BEFORE the trailing-slash strip).
  ec=0
  out="$(cd "$scratch" && PATH="${scratch}/bin:${PATH}" EDM_SRD_ROOT="/" bash "$cmdfile" 2>&1)" || ec=$?
  [[ "$ec" -eq 1 && "$out" == *"srd_root is absolute"* ]] \
    && pass "CA-186 G3 -- EDM_SRD_ROOT=/ is classified as absolute (diagnostic + exit 1), not silently collapsed to empty" \
    || fail "CA-186 G3 -- EDM_SRD_ROOT=/ produced exit=${ec}, output: ${out} (expected exit 1 with an absolute-path diagnostic)"

  # Case 4 (CA-186 G3): a bare relative root with no leading/trailing decoration -- baseline for
  # the remaining shapes below.
  ec=0
  out="$(cd "$scratch" && PATH="${scratch}/bin:${PATH}" EDM_SRD_ROOT="SRD" bash "$cmdfile" 2>&1)" || ec=$?
  [[ "$ec" -eq 2 && "$out" == *"FOOG8"* ]] \
    && pass "CA-186 G3 -- EDM_SRD_ROOT=SRD (bare) still detects the violation and blocks (hook exit 2)" \
    || fail "CA-186 G3 -- EDM_SRD_ROOT=SRD produced exit=${ec}, output: ${out} (expected exit 2 naming FOOG8)"

  # Case 5 (CA-186 G3): a doubled leading "./" (././SRD) must be fully stripped by the LOOPED
  # leading-./ strip, not just one iteration of it.
  ec=0
  out="$(cd "$scratch" && PATH="${scratch}/bin:${PATH}" EDM_SRD_ROOT="././SRD" bash "$cmdfile" 2>&1)" || ec=$?
  [[ "$ec" -eq 2 && "$out" == *"FOOG8"* ]] \
    && pass "CA-186 G3 -- EDM_SRD_ROOT=././SRD (doubled leading ./) still detects the violation and blocks (hook exit 2)" \
    || fail "CA-186 G3 -- EDM_SRD_ROOT=././SRD produced exit=${ec}, output: ${out} (expected exit 2 naming FOOG8 -- the ./ strip must be looped)"

  # Case 6 (CA-186 G3): a trailing "/." (current-directory component) must be collapsed the same
  # way a trailing "/" is -- this was the other silent-bypass shape the trailing-slash-only
  # collapse missed entirely.
  ec=0
  out="$(cd "$scratch" && PATH="${scratch}/bin:${PATH}" EDM_SRD_ROOT="SRD/." bash "$cmdfile" 2>&1)" || ec=$?
  [[ "$ec" -eq 2 && "$out" == *"FOOG8"* ]] \
    && pass "CA-186 G3 -- EDM_SRD_ROOT=SRD/. (trailing /.) still detects the violation and blocks (hook exit 2)" \
    || fail "CA-186 G3 -- EDM_SRD_ROOT=SRD/. produced exit=${ec}, output: ${out} (expected exit 2 naming FOOG8 -- a trailing /. must not silently disable enforcement)"

  # Case 7 (CA-186 G3): an empty EDM_SRD_ROOT value falls through bash's ${VAR:-default}
  # substitution exactly like an unset one, so it must default to ./SRD and still block.
  ec=0
  out="$(cd "$scratch" && PATH="${scratch}/bin:${PATH}" EDM_SRD_ROOT="" bash "$cmdfile" 2>&1)" || ec=$?
  [[ "$ec" -eq 2 && "$out" == *"FOOG8"* ]] \
    && pass "CA-186 G3 -- EDM_SRD_ROOT='' (empty string) defaults to ./SRD and still blocks (hook exit 2)" \
    || fail "CA-186 G3 -- EDM_SRD_ROOT='' produced exit=${ec}, output: ${out} (expected exit 2 naming FOOG8)"

  # Case 8 (CA-186 G3 bullet 4): a relative root that does not exist on disk must be named loudly
  # (diagnostic + exit 1) rather than silently producing zero matched prefixes.
  ec=0
  out="$(cd "$scratch" && PATH="${scratch}/bin:${PATH}" EDM_SRD_ROOT="SRD_DOES_NOT_EXIST" bash "$cmdfile" 2>&1)" || ec=$?
  [[ "$ec" -eq 1 && "$out" == *"does not exist"* ]] \
    && pass "CA-186 G3 -- a nonexistent relative EDM_SRD_ROOT is named loudly (diagnostic + exit 1), not silently skipped" \
    || fail "CA-186 G3 -- EDM_SRD_ROOT=SRD_DOES_NOT_EXIST produced exit=${ec}, output: ${out} (expected exit 1 naming the missing root)"

  # Case 9 (CA-186 G3 round-5): a bare "." must be treated as "srd_root is the repository root
  # itself" -- every staged path is under it -- not silently produce zero matched prefixes because
  # the awk matcher looked for a literal "./" prefix git never emits from --name-only.
  ec=0
  out="$(cd "$scratch" && PATH="${scratch}/bin:${PATH}" EDM_SRD_ROOT="." bash "$cmdfile" 2>&1)" || ec=$?
  [[ "$ec" -eq 2 && "$out" == *"FOOG8"* ]] \
    && pass "CA-186 G3 (round 5) -- EDM_SRD_ROOT=. still detects the violation and blocks (hook exit 2)" \
    || fail "CA-186 G3 (round 5) -- EDM_SRD_ROOT=. produced exit=${ec}, output: ${out} (expected exit 2 naming FOOG8 -- '.' must not silently disable enforcement)"

  # Case 10 (CA-186 G3 round-5): "./" reduces to empty via the leading-./ strip loop and must land
  # on the same "repository root" handling as a bare ".", not the empty-string default-substitution
  # path (Case 7 above) -- those are two different origins for an empty srd_root and only one of
  # them (an unset/empty env var) is supposed to re-default to ./SRD.
  ec=0
  out="$(cd "$scratch" && PATH="${scratch}/bin:${PATH}" EDM_SRD_ROOT="./" bash "$cmdfile" 2>&1)" || ec=$?
  [[ "$ec" -eq 2 && "$out" == *"FOOG8"* ]] \
    && pass "CA-186 G3 (round 5) -- EDM_SRD_ROOT=./ still detects the violation and blocks (hook exit 2)" \
    || fail "CA-186 G3 (round 5) -- EDM_SRD_ROOT=./ produced exit=${ec}, output: ${out} (expected exit 2 naming FOOG8)"

  # Case 11 (CA-186 G3 round-5): ".." resolves outside the repository root and is nonsensical as an
  # srd_root -- refuse loudly (exit 1) rather than silently matching zero prefixes.
  ec=0
  out="$(cd "$scratch" && PATH="${scratch}/bin:${PATH}" EDM_SRD_ROOT=".." bash "$cmdfile" 2>&1)" || ec=$?
  [[ "$ec" -eq 1 && "$out" == *"'..' path component"* ]] \
    && pass "CA-186 G3 (round 5) -- EDM_SRD_ROOT=.. is refused loudly (diagnostic + exit 1), not silently skipped" \
    || fail "CA-186 G3 (round 5) -- EDM_SRD_ROOT=.. produced exit=${ec}, output: ${out} (expected exit 1 naming the '..' component)"

  # Case 12 (CA-186 G3 round-5): an absolute srd_root equal to the repository root exercises the
  # relativization arm's OWN "." output -- that arm had zero prior coverage; only non-relativizable
  # absolutes (Case 3/3b) were ever exercised.
  ec=0
  out="$(cd "$scratch" && PATH="${scratch}/bin:${PATH}" EDM_SRD_ROOT="$repo_root_g3" bash "$cmdfile" 2>&1)" || ec=$?
  [[ "$ec" -eq 2 && "$out" == *"FOOG8"* ]] \
    && pass "CA-186 G3 (round 5) -- an absolute EDM_SRD_ROOT equal to the repo root relativizes to '.' and still blocks (hook exit 2)" \
    || fail "CA-186 G3 (round 5) -- absolute-equal-to-repo-root EDM_SRD_ROOT produced exit=${ec}, output: ${out} (expected exit 2 naming FOOG8 -- the relativization arm's '.' output must not silently disable enforcement)"

  # Regression: the unset (default ./SRD) case still detects and blocks exactly as before.
  ec=0
  out="$(cd "$scratch" && PATH="${scratch}/bin:${PATH}" bash "$cmdfile" 2>&1)" || ec=$?
  [[ "$ec" -eq 2 && "$out" == *"FOOG8"* ]] \
    && pass "G8 -- default (unset EDM_SRD_ROOT) still detects the violation and blocks (regression check)" \
    || fail "G8 -- default EDM_SRD_ROOT produced exit=${ec}, output: ${out} (expected exit 2 naming FOOG8)"

  # No shape may exit 0 silently (CA-186 G3's core invariant): every one of the twelve documented
  # shapes above resolves to either exit 2 (blocking, relative) or exit 1 (loud, non-blocking
  # config problem) -- never a bare exit 0.
  local -a g3_all_shapes=("SRD" "./SRD" "././SRD" "SRD/" "SRD/." "/" "/nonexistent/absolute/SRD" "" "." "./" ".." "$repo_root_g3")
  local g3_shape g3_ec g3_never_zero=1
  for g3_shape in "${g3_all_shapes[@]}"; do
    g3_ec=0
    (cd "$scratch" && PATH="${scratch}/bin:${PATH}" EDM_SRD_ROOT="$g3_shape" bash "$cmdfile" >/dev/null 2>&1) || g3_ec=$?
    if [[ "$g3_ec" -eq 0 ]]; then
      g3_never_zero=0
      fail "CA-186 G3 -- EDM_SRD_ROOT='${g3_shape}' exited 0 silently (must be 1 or 2)"
    fi
  done
  [[ "$g3_never_zero" -eq 1 ]] \
    && pass "CA-186 G3 -- none of the twelve documented srd_root shapes exits 0 silently"

  rm -rf "$scratch"
}
echo
echo "=== G8 (round-3 Wave 7c) / CA-186 G3 (round-4 Wave 8b, round-5): a trailing-slash, doubled ./, trailing /., bare '.', './', '..', or absolute srd_root must never silently disable commit-time enforcement ==="
g8_srd_root_case

# =================================================================================
# CA-253 G8 (round-4 Wave 8b): the five UserPromptExpansion gate hooks must refuse with exit 2
# (the code Claude Code actually treats as blocking), not exit 1 (non-blocking, expansion
# proceeds anyway despite the refusal message being shown). Both refusal sites in each hook body
# -- the invalid-prefix branch and the gate-check-failed branch -- must carry exit 2, and neither
# may retain a bare "exit 1" on the refusal path. This is a static assertion against the shipped
# hooks.json text (not an executed hook), which is sufficient here because the two refusal sites
# are literal, grep-able exit-code tokens rather than a scan/derivation the way CA-186's srd_root
# normalization is.
# =================================================================================
echo
echo "=== CA-253 G8: the five UserPromptExpansion gate hooks refuse with exit 2, never exit 1 ==="
ca253_gate_hooks_exit2_case() {
  local matcher token hook_cmd
  for matcher in edm:srd edm:audit-srd edm:tickets edm:audit-tickets edm:implement; do
    token="${matcher#edm:}"
    hook_cmd="$(jq -r --arg m "$matcher" \
      '.hooks.UserPromptExpansion[] | select(.matcher == $m) | .hooks[] | select(.type == "command") | .command' \
      "${PLUGIN_DIR}/hooks/hooks.json" 2>/dev/null)"
    if [[ -z "$hook_cmd" ]]; then
      fail "CA-253 G8 -- could not extract the ${matcher} UserPromptExpansion command hook from hooks.json"
      continue
    fi
    check "CA-253 G8 -- ${matcher} hook's invalid-prefix branch refuses with exit 2" \
      "exit 2 ;; esac" "$hook_cmd"
    check "CA-253 G8 -- ${matcher} hook's gate-check call for token '${token}' refuses with exit 2" \
      "gate-check \"\$prefix\" ${token} || exit 2" "$hook_cmd"
    check_absent "CA-253 G8 -- ${matcher} hook body carries no bare 'exit 1' on the refusal path" \
      "exit 1" "$hook_cmd"
    check_absent "CA-253 G8 -- ${matcher} hook's gate-check call no longer merges stderr into stdout via 2>&1" \
      "gate-check \"\$prefix\" ${token} 2>&1" "$hook_cmd"
  done
}
ca253_gate_hooks_exit2_case

# =================================================================================
# CA-298/G1 (round-5): CA-253's exit-2 conversion made the command hooks block on ANY gate-check
# failure, not only a genuine gate refusal -- including a missing state file, which the sibling
# prompt hook's own text says must allow expansion (first invocation). Extracts each of the five
# real UserPromptExpansion command hooks and executes them against stub edm-state binaries, so
# this exercises the actual shipped hook script, not a hand-written stand-in for it.
# =================================================================================
echo
echo "=== CA-298/G1: the five gate hooks allow expansion on a missing state file, still block on a genuine refusal ==="
ca298_gate_hooks_case() {
  local matcher token scratch cmdfile cmd out ec
  for matcher in edm:srd edm:audit-srd edm:tickets edm:audit-tickets edm:implement; do
    token="${matcher#edm:}"
    scratch="$(mktemp -d "${TMP}/edm-ca298.XXXXXX")" || { fail "CA-298/G1 -- mktemp failed"; continue; }
    mkdir -p "${scratch}/bin"

    cmdfile="${scratch}/hook-command.sh"
    jq -r --arg m "$matcher" \
      '.hooks.UserPromptExpansion[] | select(.matcher == $m) | .hooks[] | select(.type == "command") | .command' \
      "${PLUGIN_DIR}/hooks/hooks.json" > "$cmdfile" 2>/dev/null
    cmd="$(cat "$cmdfile" 2>/dev/null || true)"
    if [[ -z "$cmd" ]]; then
      fail "CA-298/G1 -- could not extract the ${matcher} UserPromptExpansion command hook from hooks.json"
      rm -rf "$scratch"
      continue
    fi

    # Case A: no initiative for this prefix (resolve-dir fails) -- must ALLOW expansion (exit 0),
    # matching the sibling prompt hook's documented first-invocation allowance.
    cat > "${scratch}/bin/edm-state" <<'EOS'
#!/bin/bash
case "$1" in
  resolve-dir) echo "no initiative for prefix $2" >&2; exit 1 ;;
  gate-check) echo "CA298: gate-check should not have been called" >&2; exit 1 ;;
esac
EOS
    chmod +x "${scratch}/bin/edm-state"
    ec=0
    out="$(cd "$scratch" && PATH="${scratch}/bin:${PATH}" ARGUMENTS="CA298PFX" bash "$cmdfile" 2>&1)" || ec=$?
    [[ "$ec" -eq 0 ]] \
      && pass "CA-298/G1 -- ${matcher} hook allows expansion when the initiative has no state file (first invocation)" \
      || fail "CA-298/G1 -- ${matcher} hook produced exit=${ec}, output: ${out} (expected exit 0 -- a missing state file must not block)"

    # Case B: the initiative resolves but the gate genuinely is not approved -- must BLOCK
    # (exit 2), so Case A's fix has not disabled real enforcement.
    cat > "${scratch}/bin/edm-state" <<'EOS'
#!/bin/bash
case "$1" in
  resolve-dir) echo "/tmp/CA298PFX"; exit 0 ;;
  gate-check) echo "edm-state gate-check: Gate 1 has not been approved for CA298PFX." >&2; exit 1 ;;
esac
EOS
    chmod +x "${scratch}/bin/edm-state"
    ec=0
    out="$(cd "$scratch" && PATH="${scratch}/bin:${PATH}" ARGUMENTS="CA298PFX" bash "$cmdfile" 2>&1)" || ec=$?
    [[ "$ec" -eq 2 ]] \
      && pass "CA-298/G1 -- ${matcher} hook still blocks a genuine gate refusal (hook exit 2)" \
      || fail "CA-298/G1 -- ${matcher} hook produced exit=${ec}, output: ${out} (expected exit 2 -- a real gate refusal must still block)"

    rm -rf "$scratch"
  done
}
ca298_gate_hooks_case

# =================================================================================
# G9/G19 (round-3 Wave 7c): the two --help sentences this round's own remediation inverted are
# corrected, and the "unreadable" violation class is documented. A positive control proves the
# assertions actually catch the old (wrong) text if it were reintroduced, not just that the
# current text happens to be absent.
# =================================================================================
echo
echo "=== G9/G19: edm-lint-artifacts --help states the current exit-code/hook contract and lists 'unreadable' ==="
g9_help_out="$(bash "${PLUGIN_DIR}/bin/edm-lint-artifacts" --help 2>&1)"

check_absent "G9 -- --help no longer claims the hook blocks on any non-zero exit with one generic line" \
  "blocks on any non-zero" "$g9_help_out"
check_absent "G9 -- --help no longer claims the hook's staged-path matcher is the literal ^SRD/" \
  "literal \`^SRD/\`" "$g9_help_out"
check "G9 -- --help states exit 1 makes the hook exit 2 (the blocking code)" \
  "makes the hook exit 2" "$g9_help_out"
check "G9 -- --help states exit 2 makes the hook exit 0 (does not block)" \
  "makes the hook exit 0" "$g9_help_out"
check "G19 -- --help's class list documents the 'unreadable' class" \
  "unreadable" "$g9_help_out"

# Positive control: the two old (wrong) phrasings are still individually recognizable strings, so
# check_absent above is not vacuously passing against something the tests can't actually detect.
g9_old_phrase_1="blocks on any non-zero exit and prints one generic remediation line"
g9_old_phrase_2='staged-path matcher is still the literal `^SRD/`'
case "$g9_old_phrase_1" in
  *"blocks on any non-zero"*) pass "G9 (positive control) -- the retired phrase 1 text does contain the substring check_absent looks for" ;;
  *) fail "G9 (positive control) -- the retired phrase 1 fixture does not contain the substring being checked; the assertion above would pass vacuously" ;;
esac
case "$g9_old_phrase_2" in
  *"literal \`^SRD/\`"*) pass "G9 (positive control) -- the retired phrase 2 text does contain the substring check_absent looks for" ;;
  *) fail "G9 (positive control) -- the retired phrase 2 fixture does not contain the substring being checked; the assertion above would pass vacuously" ;;
esac

echo
echo "=== G9/G19: plugins/edm/CLAUDE.md's bin/ table row for edm-lint-artifacts matches the current contract ==="
g9_claude_md="$(cat "${PLUGIN_DIR}/CLAUDE.md" 2>/dev/null)"
check_absent "G9 -- CLAUDE.md's bin/ table no longer hardcodes 'four violation classes' for edm-lint-artifacts" \
  "four violation classes" "$g9_claude_md"
check "G9 -- CLAUDE.md's bin/ table points readers at --help instead of a hardcoded count" \
  "edm-lint-artifacts --help" "$g9_claude_md"

# =================================================================================
# G64 (round-3 Wave 7c): CLAUDE.md's Hooks behavior table must not present edm-lint-artifacts's
# own exit codes as if they were the hook's own -- the mapping is inverted (linter exit 1 -> hook
# exit 2; linter exit 2 -> hook exit 0).
# =================================================================================
echo
echo "=== G64: CLAUDE.md's Hooks behavior table disambiguates the linter's exit codes from the hook's own ==="
check "G64 -- CLAUDE.md states linter exit 1 makes the hook exit 2 (the blocking code)" \
  "makes the hook exit **2**" "$g9_claude_md"
check "G64 -- CLAUDE.md states linter exit 2 makes the hook exit 0 (does not block)" \
  "makes the hook exit 0" "$g9_claude_md"


# =================================================================================
# G13 (round-3 Wave 7e): the lens JSONL schema is restated as a literal token list
# alongside the by-name pointer in the launch template, and a step-8a precondition
# blocks the synthesizer spawn until every lens's .jsonl half exists.
# =================================================================================
echo
echo "=== G13: code-audit SKILL.md restates the literal lens JSONL schema and gates the synthesizer spawn ==="
g13_code_audit_skill="$(cat "${PLUGIN_DIR}/skills/code-audit/SKILL.md" 2>/dev/null)"

# G6/CA-193 (round 5, fifth recurrence): the four schema-token checks below previously asserted
# against the WHOLE FILE, so moving the schema line back above the fence -- the exact CA-193
# regression -- left all four green (the tokens still appear "somewhere in the file," just not
# inside the fenced launch template that actually ships to a lens). Extract the fence's own body
# and assert against THAT, so a schema line that migrates outside the fence is caught.
g13_launch_template_body="$(awk '
  /^## Lens Agent Launch Template/ { f = 1 }
  f && $0 == "```" { c++; if (c == 2) exit; next }
  f && c == 1 { print }
' "${PLUGIN_DIR}/skills/code-audit/SKILL.md")"
[[ -n "$g13_launch_template_body" ]] \
  && pass "G6/CA-193 -- the Lens Agent Launch Template fence extraction is non-empty (extraction itself works)" \
  || fail "G6/CA-193 -- the Lens Agent Launch Template fence extraction returned nothing -- the heading or fence markers moved, and every schema-token check below would be checked against nothing"
check "G13/G6 -- launch template FENCE BODY restates the literal JSONL schema id field" '"id":null' "$g13_launch_template_body"
check "G13/G6 -- launch template FENCE BODY restates the literal JSONL schema lens field" '"lens":"L{N}"' "$g13_launch_template_body"
check "G13/G6 -- launch template FENCE BODY restates the literal JSONL schema file field" '"file":"path"' "$g13_launch_template_body"
check "G13/G6 -- launch template FENCE BODY restates the literal JSONL schema status field" '"status":"open"' "$g13_launch_template_body"
check "G13 -- launch template still carries the by-name pointer to the agent's own JSONL Line Format section" \
  "JSONL Line Format" "$g13_code_audit_skill"
check "G13 -- a precondition blocks proceeding to the synthesizer spawn (step 8a) until step 9 may run" \
  "do not proceed to step 9 until it holds" "$g13_code_audit_skill"
check "G13/G4 -- the precondition Globs the pass directory for a lens-L{N}.jsonl file per lens" \
  '`${OUTPUT_DIR}/lens-L*.jsonl` and count the matches' "$g13_code_audit_skill"
check "G4 -- a count mismatch refuses to proceed and names the missing lenses by ID" \
  "name, by lens ID, every member" "$g13_code_audit_skill"
check "G13 -- the precondition states the orchestrator-persists-both-halves fallback" \
  "Never persist only the \`.md\` half and proceed" "$g13_code_audit_skill"

# G6/CA-193 (round 5): the count check alone cannot tell eleven correctly-schema'd files from
# eleven files carrying an invented schema. Step 8a now also validates CONTENT.
check "G6/CA-193 -- step 8a's precondition includes a content check beyond the count check" \
  "Content check (CA-193, fifth recurrence)" "$g13_code_audit_skill"
check "G6/CA-193 -- the content check names the required lens-schema keys" \
  'schema`, `lens`, `sev` and `status` present,' "$g13_code_audit_skill"
check "G6/CA-193 -- the content check requires id to be literally null" \
  '`id` literally `null`' "$g13_code_audit_skill"
check "G6/CA-193 -- the content check refuses the ledger-shaped lenses key" \
  '`lenses` (plural),' "$g13_code_audit_skill"
check "G6/CA-193 -- the content check refuses the ledger-shaped component/raised_round keys" \
  '`component`, `raised_round`' "$g13_code_audit_skill"
check "G6/CA-193 -- a content-check failure re-delivers the lens's launch template rather than hand-patching its output" \
  "re-deliver that lens's launch template" "$g13_code_audit_skill"

# G6/CA-193 (round 5): the Synthesizer Phase section's own spawn instruction previously carried
# zero reference to step 8a or LENS_SET, so a reader could satisfy it with markdown-only reports
# -- precisely the pass-3 CA-193 regression. The section now cross-references step 8a explicitly.
check "G6/CA-193 -- the Synthesizer Phase section is explicitly gated on step 8a, not merely 'after reports are written'" \
  "Gated on step 8a (CA-193)" "$g13_code_audit_skill"
check "G6/CA-193 -- the cross-reference names the regression it prevents (markdown-only reports treated as sufficient)" \
  "treats markdown-only reports" "$g13_code_audit_skill"

# =================================================================================
# G14 (round-3 Wave 7e): the CA-098 legacy-flat-path break is closed at all 7 skill
# files and 11 agent files the finding named -- each now resolves INIT_DIR via
# edm-state resolve-dir rather than hand-building a flat ${srd_root}/{PREFIX} path.
#
# G5 (CA-195, round-4 Wave 8d): the sweep that produced the check_absent calls below
# keyed on one spelling only (the srd_root-prefixed literal). Twelve further sites
# used the bare `SRD/{PREFIX}/` spelling instead and survived undetected outside this
# needle. The needle is widened here to catch both spellings in the same files this
# block already enumerates, so a future regression under either spelling is caught.
# =================================================================================
echo
echo "=== G14: the 7 named skills and 11 named agents resolve INIT_DIR instead of a hardcoded flat path ==="
g14_skills="test-plan test-coverage test push-jira tickets audit-srd audit-tickets"
for g14_s in $g14_skills; do
  g14_content="$(cat "${PLUGIN_DIR}/skills/${g14_s}/SKILL.md" 2>/dev/null)"
  check "G14 -- skills/${g14_s}/SKILL.md calls edm-state resolve-dir" "resolve-dir" "$g14_content"
done

g14_agents="edm-test-coverage-auditor edm-test-planner edm-test-unit edm-test-component edm-test-composable edm-test-contract edm-test-integration edm-test-e2e edm-test-a11y edm-test-scaffold"
for g14_a in $g14_agents; do
  g14_acontent="$(cat "${PLUGIN_DIR}/agents/${g14_a}.md" 2>/dev/null)"
  check "G14 -- agents/${g14_a}.md takes INIT_DIR from its launcher" "INIT_DIR" "$g14_acontent"
done

g14_qc_auditor="$(cat "${PLUGIN_DIR}/agents/edm-qc-auditor.md" 2>/dev/null)"
check "G14 -- edm-qc-auditor.md now calls edm-state resolve-dir instead of edm-state get | jq" \
  "edm-state resolve-dir <PREFIX>" "$g14_qc_auditor"
check "G14 -- edm-qc-auditor.md's Output Path section names resolve-dir as the operative command" \
  "Resolve the initiative directory from state: \`edm-state resolve-dir <PREFIX>\`" "$g14_qc_auditor"

# =================================================================================
# G23/CA-195 (round 5, final pass): the check_absent calls above were keyed on a hardcoded
# 19-file enumeration (7 skills, 10 agents, edm-qc-auditor) -- the same sweep-keyed-on-one-axis
# shape CA-195 itself was raised for, one axis over. A regression in any of the ~16 unenumerated
# skill/agent files was invisible to the suite. Replaced with one tree-wide scan over every
# skills/*/SKILL.md and agents/*.md file for both needles -- but scoped to text INSIDE fenced
# code blocks only, not the whole file. Empirically, every current occurrence of either needle
# (7 sites across implement, orchestrator, plan x3, srd x2) is prose describing an artifact's
# canonical illustrative location ("- **Output**: `.../{PREFIX}/planning.md`", "if
# `SRD/{PREFIX}/` already exists" narrating edm-validate-prefix's own already-correct check) --
# never inside a code fence, because none of them is an executable step. The actual CA-195 bug
# class this exists to catch is a hardcoded path used AS CODE (a shell existence test, a
# constructed path an agent is told to run against), which only ever appears inside a fence in
# this plugin's prompt-authoring convention. Scoping to fences catches that class with zero
# hand-maintained exceptions, rather than a three-entry list of prose shapes that the next
# rewording could just as easily fall outside of.
# =================================================================================
echo
echo "=== G23/CA-195: no skills/*/SKILL.md or agents/*.md fenced code block hardcodes the flat SRD/{PREFIX} path ==="
g23_scan_files="$(find "${PLUGIN_DIR}/skills" "${PLUGIN_DIR}/agents" -name '*.md' 2>/dev/null | sort)"
g23_scan_count="$(printf '%s\n' "$g23_scan_files" | grep -c . || true)"
[[ "${g23_scan_count:-0}" -ge 20 ]] \
  && pass "G23/CA-195 -- the tree-wide scan enumerates at least 20 files (sanity floor -- a find-command regression would silently scan nothing)" \
  || fail "G23/CA-195 -- the tree-wide scan found only ${g23_scan_count:-0} skill/agent files, expected at least 20 -- find itself may be broken"
g23_fence_scan() {
  awk '
    /^```/ { infence = !infence; next }
    infence && ($0 ~ /srd_root\}\/\{PREFIX\}/ || $0 ~ /SRD\/\{PREFIX\}/) { print FILENAME ":" FNR ": " $0 }
  ' "$1" 2>/dev/null
}
g23_violations=""
while IFS= read -r g23_f; do
  [[ -n "$g23_f" ]] || continue
  g23_hits="$(g23_fence_scan "$g23_f")"
  [[ -n "$g23_hits" ]] && g23_violations="${g23_violations}${g23_hits}"$'\n'
done <<< "$g23_scan_files"
[[ -z "$g23_violations" ]] \
  && pass "G23/CA-195 -- zero fenced-code-block hits for the hardcoded flat path across every skills/*/SKILL.md and agents/*.md file" \
  || fail "G23/CA-195 -- hardcoded flat SRD/{PREFIX} path found inside a fenced code block:\n${g23_violations}"

# Positive control: plant one hit OUTSIDE a fence (must NOT be flagged, matching the seven
# existing prose occurrences) and one INSIDE a fence (must be flagged) in the same probe file,
# proving the scanner draws the line at the fence boundary rather than, say, reading zero bytes
# and reporting a false-clean result either way.
g23_probe_dir="$(mktemp -d "${TMP}/edm-g23-probe.XXXXXX")"
cat > "${g23_probe_dir}/probe.md" << 'EOF'
- **Output**: `${user_config.srd_root}/{PREFIX}/planning.md` -- prose, outside any fence.

```bash
if [[ -d "SRD/{PREFIX}/tickets" ]]; then
  echo "found"
fi
```
EOF
g23_probe_hits="$(g23_fence_scan "${g23_probe_dir}/probe.md")"
g23_probe_hit_lines="$(printf '%s\n' "$g23_probe_hits" | grep -c . || true)"
[[ "${g23_probe_hit_lines:-0}" -eq 1 ]] \
  && pass "G23/CA-195 -- positive control: the scanner flags exactly the one violation inside the fence, not the prose line outside it" \
  || fail "G23/CA-195 -- positive control failed: expected exactly 1 fenced hit, got ${g23_probe_hit_lines:-0} -- the assertion above may be vacuous or over-broad"
check "G23/CA-195 -- the flagged hit is the fenced one, not the prose one" \
  "SRD/{PREFIX}/tickets" "$g23_probe_hits"
rm -rf "$g23_probe_dir"

# Positive control: the four agent-launch-template sites named in the finding actually pass
# INIT_DIR to the agent they spawn (tickets -> edm-ticket-writer, audit-srd -> edm-srd-auditor,
# audit-tickets -> edm-ticket-auditor x2), proving the skill-side fix reaches the spawn site.
check "G14 -- tickets/SKILL.md's edm-ticket-writer launch template passes INIT_DIR" \
  "Initiative directory (INIT_DIR): \${INIT_DIR}" "$(cat "${PLUGIN_DIR}/skills/tickets/SKILL.md")"
check "G14 -- audit-srd/SKILL.md's edm-srd-auditor launch template passes INIT_DIR" \
  "Initiative directory (INIT_DIR): \${INIT_DIR}" "$(cat "${PLUGIN_DIR}/skills/audit-srd/SKILL.md")"
g14_audit_tickets_content="$(cat "${PLUGIN_DIR}/skills/audit-tickets/SKILL.md")"
[[ "$(printf '%s' "$g14_audit_tickets_content" | grep -c 'Initiative directory (INIT_DIR): ${INIT_DIR}')" -ge 2 ]] \
  && pass "G14 -- audit-tickets/SKILL.md's two edm-ticket-auditor launch templates both pass INIT_DIR" \
  || fail "G14 -- audit-tickets/SKILL.md does not pass INIT_DIR at both Lane 1 and Lane 2 launch templates"

# =================================================================================
# G15 (round-3 Wave 7e): current_step gains a producer -- every phase skill's Step 0
# preflight now records it via the canonical block plan/SKILL.md defines once.
# =================================================================================
echo
echo "=== G15: every phase skill's Step 0 preflight records current_step in the bare phase-number vocabulary ==="
g15_plan="$(cat "${PLUGIN_DIR}/skills/plan/SKILL.md" 2>/dev/null)"
check "G15 -- plan/SKILL.md's canonical Step 0 block writes current_step" \
  "edm-state current-step <PREFIX> <phase-num>" "$g15_plan"
check "G15 -- plan/SKILL.md substitutes phase-num=1 for itself" \
  "\`1\` for this skill" "$g15_plan"

g15_phase_num_map="srd:2 audit-srd:3 tickets:4 audit-tickets:5 implement:6 code-audit:6 verify-runtime:6"
for g15_pair in $g15_phase_num_map; do
  g15_skill="${g15_pair%%:*}"
  g15_num="${g15_pair##*:}"
  g15_content="$(cat "${PLUGIN_DIR}/skills/${g15_skill}/SKILL.md" 2>/dev/null)"
  check "G15 -- skills/${g15_skill}/SKILL.md substitutes <phase-num> = ${g15_num} into the canonical Step 0 block" \
    "<phase-num>\` = \`${g15_num}\`" "$g15_content"
done

# =================================================================================
# G34 (round-3 Wave 7e): findings-ledger.jsonl (not the .md render) is named
# authoritative everywhere the prior text called the .md authoritative.
# =================================================================================
echo
echo "=== G34: findings-ledger.jsonl, not the .md render, is named authoritative in every prompt-surface site ==="
check "G34 -- code-audit/SKILL.md's closure template names the .jsonl ledger authoritative" \
  "code-audit/findings-ledger.jsonl\` is the authoritative record" "$g13_code_audit_skill"
g34_claude_md="$(cat "${PLUGIN_DIR}/CLAUDE.md" 2>/dev/null)"
check "G34 -- CLAUDE.md's decisions.md-vs-ledger note attributes authoritative status to the .jsonl, rendered by edm-state render-ledger" \
  "rendered by \`edm-state render-ledger\` from the authoritative \`code-audit/findings-ledger.jsonl\`" "$g34_claude_md"
check "G34 -- CLAUDE.md's artifact-layout diagram lists findings-ledger.jsonl above findings-ledger.md" \
  "findings-ledger.jsonl <- authoritative cross-round findings ledger" "$g34_claude_md"
g34_readme="$(cat "${PLUGIN_DIR}/README.md" 2>/dev/null)"
check "G34 -- README.md's artifact-layout diagram lists findings-ledger.jsonl above findings-ledger.md" \
  "findings-ledger.jsonl        <- authoritative cross-round findings ledger" "$g34_readme"

# =================================================================================
# G35 (round-3 Wave 7e): test-coverage-audit.md gains a write side -- a fifth
# `test-coverage` audit type in cmd_update_patterns, called from its two consuming
# skills after the coverage auditor returns.
# =================================================================================
echo
echo "=== G35: cmd_update_patterns gains a test-coverage arm, wired from test-coverage/SKILL.md and test/SKILL.md ==="
g35_edm_state="$(cat "${PLUGIN_DIR}/bin/edm-state" 2>/dev/null)"
check "G35 -- cmd_update_patterns accepts the test-coverage audit type" \
  "srd|ticket|qc|code|test-coverage" "$g35_edm_state"
check "G35 -- cmd_update_patterns maps test-coverage to test-coverage-audit.md" \
  "test-coverage) pattern_file=\"\${patterns_dir}/test-coverage-audit.md\"" "$g35_edm_state"
check "G35 -- cmd_update_patterns maps test-coverage's audit report to test-coverage.md" \
  'test-coverage) audit_report_path="${_dir}/test-coverage.md"' "$g35_edm_state"
check "G35 -- test-coverage/SKILL.md calls update-patterns test-coverage after the auditor returns" \
  "edm-state update-patterns <PREFIX> test-coverage" "$(cat "${PLUGIN_DIR}/skills/test-coverage/SKILL.md")"
check "G35 -- test/SKILL.md calls update-patterns test-coverage after the auditor returns" \
  "edm-state update-patterns <PREFIX> test-coverage" "$(cat "${PLUGIN_DIR}/skills/test/SKILL.md")"
g35_readme="$(cat "${PLUGIN_DIR}/docs/audit-patterns/README.md" 2>/dev/null)"
check "G35 -- audit-patterns README.md's Append Schema enum includes test-coverage" \
  "srd|ticket|qc|code|test-coverage" "$g35_readme"
check "G35 -- audit-patterns README.md's Consumers list includes edm-test-coverage-auditor" \
  "edm-test-coverage-auditor\` loads \`test-coverage-audit.md\`" "$g35_readme"

# =================================================================================
# G69 (round-3 Wave 7e): the edm:audit-srd UserPromptExpansion hook now passes its
# own gate token instead of the edm:srd hook's token.
# =================================================================================
echo
echo "=== G69: the edm:audit-srd hook's gate-check call passes 'audit-srd', not 'srd' ==="
g69_hooks_json="$(cat "${PLUGIN_DIR}/hooks/hooks.json" 2>/dev/null)"
check "G69 -- hooks.json's edm:audit-srd matcher calls gate-check with the audit-srd token" \
  'gate-check \"$prefix\" audit-srd' "$g69_hooks_json"

# =================================================================================
# G85 (round-3 Wave 7e): the SubagentStop hook that spawns edm-qc-auditor resolves
# the initiative directory with resolve-dir, not `edm-state get | jq`.
# =================================================================================
echo
echo "=== G85: the SubagentStop edm-implementer hook resolves the initiative dir via edm-state resolve-dir ==="
check "G85 -- SubagentStop prompt step 4 uses edm-state resolve-dir" \
  "Resolve the initiative directory from state using \`edm-state resolve-dir <PREFIX>\`" "$g69_hooks_json"

# =================================================================================
# G86 (round-3 Wave 7e): estimated_size gains a real producer (plan/SKILL.md's Gate
# 1), and the SETTABLE_KEYS provenance comment stops misattributing last_decision.
# =================================================================================
echo
echo "=== G86: estimated_size is produced at plan/SKILL.md's Gate 1; SETTABLE_KEYS comment corrected ==="
check "G86 -- plan/SKILL.md's Gate 1 records estimated_size" \
  "edm-state set <PREFIX> estimated_size <Small|Medium|Large>" "$g15_plan"
check "G86 -- SETTABLE_KEYS comment attributes last_decision to skills/srd/SKILL.md" \
  "\`last_decision\`'s one real producer is" "$g35_edm_state"
check_absent "G86 -- SETTABLE_KEYS comment no longer misattributes last_decision to orchestrator/SKILL.md" \
  "last_cmd/last_decision" "$g35_edm_state"

# =================================================================================
# G11/CA-246 (round 5): last_cmd is deleted entirely rather than left settable with
# no producer a third consecutive round (L2+L3+L11). Assert it is gone from every
# surface -- SETTABLE_KEYS, the init payload, and both renderers -- not merely that
# a comment somewhere admits the gap.
# =================================================================================
echo
echo "=== G11/CA-246: last_cmd is deleted -- no SETTABLE_KEYS entry, no init payload key, no renderer ==="
t_g11_edm_state="$(cat "$EDM_STATE" 2>/dev/null)"
g11_settable_line="$(printf '%s\n' "$t_g11_edm_state" | grep '^SETTABLE_KEYS=')"
check_absent "G11/CA-246 -- last_cmd is not a member of SETTABLE_KEYS" \
  "last_cmd" "$g11_settable_line"
check "G11/CA-246 -- SETTABLE_KEYS still carries last_cmd's sibling, last_decision" \
  "last_decision" "$g11_settable_line"
check_absent "G11/CA-246 -- the init payload no longer seeds a last_cmd key" \
  'last_cmd: ""' "$t_g11_edm_state"
check_absent "G11/CA-246 -- session-start no longer renders a Last command line" \
  "Last command:" "$t_g11_edm_state"
check_absent "G11/CA-246 -- write-handoff no longer renders a Last command line" \
  "Last command**" "$t_g11_edm_state"

g11_case() {
  "$EDM_STATE" init G11DEL >/dev/null
  local ec=0 out
  out="$("$EDM_STATE" set G11DEL last_cmd "should be refused" 2>&1)" || ec=$?
  [[ $ec -ne 0 ]] \
    && pass "G11/CA-246 -- edm-state set refuses an unsettable last_cmd key" \
    || fail "G11/CA-246 -- edm-state set accepted last_cmd, expected refusal (output: ${out})"
  local state_g11="SRD/G11DEL/.edm-state.json"
  [[ "$(jq -e 'has("last_cmd")' "$state_g11" 2>/dev/null)" == "false" ]] \
    && pass "G11/CA-246 -- a freshly initialized state file has no last_cmd key at all" \
    || fail "G11/CA-246 -- the freshly initialized state file still carries a last_cmd key"
}
with_scratch_repo g11_case

# =================================================================================
# G68 (round-3 Wave 7e): edm-test-planner (the sole authority for N/A assignment)
# now enumerates integration alongside the other four N/A-eligible layers, and
# CLAUDE.md's list agrees, so edm-test-integration's self-N/A carve-out is
# sanctioned rather than a self-declared exemption no enumerating source lists.
# =================================================================================
echo
echo "=== G68: edm-test-planner and CLAUDE.md both list integration as N/A-eligible; the writer's carve-out is sanctioned, not self-declared ==="
g68_planner="$(cat "${PLUGIN_DIR}/agents/edm-test-planner.md" 2>/dev/null)"
check "G68 -- edm-test-planner.md's N/A enumeration now includes integration" \
  "\`integration\` is N/A only when the epic's Target Components cross no module or service" "$g68_planner"
g68_claude_md="$(cat "${PLUGIN_DIR}/CLAUDE.md" 2>/dev/null)"
check "G68 -- CLAUDE.md's Layers-that-are-N/A list now includes integration" \
  "\`integration\` is N/A only when Target Components cross no module or service boundary" "$g68_claude_md"
g68_integration="$(cat "${PLUGIN_DIR}/agents/edm-test-integration.md" 2>/dev/null)"
check "G68 -- edm-test-integration.md's carve-out states it is sanctioned by the planner, not self-declared" \
  "sanctioned by" "$g68_integration"

# =================================================================================
# Round-3 Wave 7g-1: nine independent bin/edm-state findings (G22, G38, G39, G43, G44,
# G46, G47, G48, G49). Each sub-section below is self-contained per finding.
# =================================================================================

echo
echo "=== G22: with_state_lock's mkdir loop dies immediately on a real error, not a 50-try timeout; record_degraded_check warns-and-skips on a non-writable state dir ==="

# ---- G22a: a real (non-"File exists") mkdir failure dies immediately, naming the real error --
t_g22a_out="$(
  set +e
  trap - EXIT INT TERM HUP
  tmp_g22a="$(mktemp -d "${TMPDIR:-/tmp}/edm-g22a.XXXXXX")" || exit 1
  command() { if [[ "${1:-}" == "-v" && "${2:-}" == "flock" ]]; then return 1; fi; builtin command "$@"; }
  source "$EDM_STATE" >/dev/null 2>&1
  if [[ "$(id -u)" -eq 0 ]]; then
    echo "skip=root"
  else
    mkdir -p "${tmp_g22a}/nowrite"
    chmod 555 "${tmp_g22a}/nowrite"
    lockbase="${tmp_g22a}/nowrite/state"
    ec=0
    out="$(with_state_lock "$lockbase" echo should-not-run 2>&1)" || ec=$?
    chmod 755 "${tmp_g22a}/nowrite"
    printf 'ec=%s out=%s\n' "$ec" "$out"
  fi
  rm -rf "$tmp_g22a"
)" || true
if [[ "$t_g22a_out" == "skip=root" ]]; then
  echo "  SKIP: G22a permission sub-case -- running as root, which bypasses the write-bit denial this case depends on"
else
  check "G22a -- with_state_lock dies immediately on a real mkdir error instead of retrying" \
    "cannot create lock directory" "$t_g22a_out"
  check_absent "G22a -- a real mkdir error never falls through to the 50-try timeout message" \
    "50 tries" "$t_g22a_out"
fi

# ---- G22b: record_degraded_check warns and returns 0 (does not die) when the state directory
# is not writable, honoring gate-check's documented read-only contract on a legacy initiative's
# very first invocation.
t_g22b_out="$(
  set +e
  trap - EXIT INT TERM HUP
  tmp_g22b="$(mktemp -d "${TMPDIR:-/tmp}/edm-g22b.XXXXXX")" || exit 1
  cd "$tmp_g22b" || exit 1
  export EDM_SRD_ROOT="${tmp_g22b}/SRD"
  "$EDM_STATE" init G22RDC >/dev/null 2>&1
  source "$EDM_STATE" >/dev/null 2>&1
  if [[ "$(id -u)" -eq 0 ]]; then
    echo "skip=root"
  else
    chmod 555 "${EDM_SRD_ROOT}/G22RDC"
    ec=0
    out="$(record_degraded_check G22RDC g22-check g22-reason 2>&1)" || ec=$?
    chmod 755 "${EDM_SRD_ROOT}/G22RDC"
    printf 'ec=%s out=%s\n' "$ec" "$out"
  fi
)" || true
if [[ "$t_g22b_out" == "skip=root" ]]; then
  echo "  SKIP: G22b permission sub-case -- running as root, which bypasses the write-bit denial this case depends on"
else
  check "G22b -- record_degraded_check returns 0 (does not die) when the state directory is not writable" \
    "ec=0" "$t_g22b_out"
  check "G22b -- the warning names gate-check's read-only contract" \
    "gate-check remains read-only" "$t_g22b_out"
fi

echo
echo "=== G38: HANDOFF.md is written with a terminating newline ==="
g38_case() {
  "$EDM_STATE" init G38HAND >/dev/null
  "$EDM_STATE" write-handoff G38HAND >/dev/null
  local handoff_path="SRD/G38HAND/HANDOFF.md"
  if [[ ! -s "$handoff_path" ]]; then
    fail "G38 -- HANDOFF.md missing or empty after write-handoff"
    return
  fi
  [[ -z "$(tail -c 1 "$handoff_path")" ]] \
    && pass "G38 -- HANDOFF.md ends with a terminating newline" \
    || fail "G38 -- HANDOFF.md does not end with a terminating newline"
}
with_scratch_repo g38_case
check "G38 -- _print_line is a distinct sibling of _print_literal, which is left unmodified" \
  "_print_line() {" "$(cat "$EDM_STATE")"
check "G38 -- write-handoff's write_atomic call now uses _print_line" \
  'write_atomic "$handoff_path" _print_line "$handoff_content"' "$(cat "$EDM_STATE")"

echo
echo "=== G39: cmd_update_patterns resolves docs/audit-patterns/ via the BASH_SOURCE-derived SCRIPT_DIR global, not a local \$0 re-derivation ==="
check_absent "G39 -- cmd_update_patterns no longer re-derives its own script directory from \$0" \
  'local _s="$0"' "$(awk '/^cmd_update_patterns\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"
check "G39 -- cmd_update_patterns uses the shared SCRIPT_DIR global instead" \
  'local patterns_dir="${SCRIPT_DIR}/../docs/audit-patterns"' \
  "$(awk '/^cmd_update_patterns\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"

g39_source_case() {
  local scratch
  scratch="$(mktemp -d "${TMP}/edm-g39.XXXXXX")" || { fail "G39 -- mktemp failed"; return 1; }
  mkdir -p "$scratch/plugins/edm"
  cp -R "${PLUGIN_DIR}/." "$scratch/plugins/edm/"
  local scratch_srd_root="$scratch/work/SRD"
  mkdir -p "${scratch_srd_root}/ZG39"
  {
    echo "# Mock SRD Audit"
    echo
    echo "### G39 sourced-invocation novel finding"
    echo "Proves cmd_update_patterns resolves patterns_dir via SCRIPT_DIR even when this file is"
    echo "sourced from a wrapper whose own positional \$0 is not edm-state's own path."
  } > "${scratch_srd_root}/ZG39/audit-srd.md"
  echo '{}' > "${scratch_srd_root}/ZG39/.edm-state.json"

  # A wrapper script whose own $0 is NOT edm-state's path -- the exact failure mode G39 fixes
  # ($0-derivation used to resolve to the SOURCING script's own path instead).
  local wrapper="$scratch/wrapper.sh"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'set -euo pipefail\n'
    printf 'source "%s/plugins/edm/bin/edm-state" >/dev/null 2>&1\n' "$scratch"
    printf 'cmd_update_patterns "$1" "$2"\n'
  } > "$wrapper"
  chmod +x "$wrapper"

  local out
  out="$(EDM_SRD_ROOT="$scratch_srd_root" bash "$wrapper" ZG39 srd 2>&1)" || true
  check "G39 -- cmd_update_patterns still finds the plugin's own docs/audit-patterns/ when sourced from a wrapper with a different \$0" \
    "1 new finding(s) appended" "$out"
  rm -rf "$scratch"
}
g39_source_case

echo
echo "=== G43: git-lock-check gates on lock age, scopes liveness detection to this repo, and removes via atomic mv-aside ==="
check "G43 -- an age threshold gates removal before any liveness probe runs" \
  '-mmin +0' "$(awk '/^cmd_git_lock_check\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"
check_absent "G43 -- the bare, unscoped 'pgrep -x git' liveness check is gone" \
  "pgrep -x git" "$(awk '/^cmd_git_lock_check\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"
check "G43 -- liveness detection is scoped: lsof against the lock file is tried first" \
  'lsof -- "$lock_file"' "$(awk '/^cmd_git_lock_check\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"
check "G43 -- the pgrep fallback is scoped to this repo's git-dir path, not a bare process name" \
  'pgrep -f -- "$git_dir"' "$(awk '/^cmd_git_lock_check\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"
check "G43 -- removal uses the atomic mv-aside-then-remove idiom instead of a bare rm -f" \
  'mv "$lock_file" "$stale_aside"' "$(awk '/^cmd_git_lock_check\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"

g43_case() {
  git init -q . >/dev/null 2>&1
  git config user.email "g43@example.com"; git config user.name "G43 Test"; git config commit.gpgsign false
  echo seed > seed.txt && git add seed.txt && git commit -q -m seed >/dev/null 2>&1
  local git_dir=".git"
  # A fresh (young) lock file must never be removed regardless of liveness.
  : > "${git_dir}/index.lock"
  local out1
  out1="$("$EDM_STATE" git-lock-check 2>&1)" || true
  check "G43 -- a lock file younger than the age threshold is left in place" \
    "less than a minute old" "$out1"
  [[ -f "${git_dir}/index.lock" ]] \
    && pass "G43 -- the young lock file still exists after the refusal" \
    || fail "G43 -- the young lock file was removed despite being under the age threshold"
  rm -f "${git_dir}/index.lock"
}
g43_scratch="$(mktemp -d "${TMP}/edm-g43.XXXXXX")"
( cd "$g43_scratch" && g43_case )
rm -rf "$g43_scratch"

# =================================================================================
# G10/CA-251 (round 5): the prior test above only exercises the REFUSAL branch (a young lock
# left in place) -- the removal branch itself was, per the finding, invisible to the suite,
# which only grepped the function body's literal source text and never executed it. These
# three cases actually EXECUTE cmd_git_lock_check end to end: a genuinely stale lock is really
# removed, an undetermined pgrep exit refuses rather than silently proceeding, and a lock that
# becomes fresh again during the liveness probe is not renamed-and-deleted out from under a
# process that just re-acquired it.
# =================================================================================
echo
echo "=== G10/CA-251 (round 5): git-lock-check actually removes a genuinely stale lock, refuses on an undetermined pgrep exit, and re-checks age immediately before the mv ==="

g10_removed_case() {
  local lock_file=".git/index.lock"
  : > "$lock_file"
  # Backdate past the ~60s age gate. `touch -t` (POSIX [[CC]YY]MMDDhhmm[.SS]) is identical on
  # GNU and BSD touch, unlike `-d`/`-r` variants that diverge across platforms.
  local backdate
  backdate="$(date -v-5M +%Y%m%d%H%M 2>/dev/null || date -d '5 minutes ago' +%Y%m%d%H%M 2>/dev/null || true)"
  if [[ -n "$backdate" ]]; then
    touch -t "$backdate" "$lock_file"
  else
    echo "  SKIP: G10/CA-251 -- could not backdate the lock file with either BSD or GNU date; skipping the removal case"
    return
  fi
  local out ec=0
  out="$("$EDM_STATE" git-lock-check 2>&1)" || ec=$?
  [[ $ec -eq 0 ]] \
    && pass "G10/CA-251 -- git-lock-check exits 0 against a genuinely stale, unheld lock" \
    || fail "G10/CA-251 -- git-lock-check exited ${ec} against a genuinely stale lock (output: ${out})"
  # cmd_git_lock_check resolves its own git_dir via --absolute-git-dir internally, so the
  # removal message names the ABSOLUTE path, not this test's relative "$git_dir" convenience
  # variable used elsewhere in this case.
  local real_git_dir
  real_git_dir="$(git rev-parse --absolute-git-dir)"
  check "G10/CA-251 -- the removal message names the removed path" "removed ${real_git_dir}/index.lock" "$out"
  [[ ! -e "$lock_file" ]] \
    && pass "G10/CA-251 -- the stale lock file is ACTUALLY GONE after git-lock-check (executing the removal branch, not merely grepping for it)" \
    || fail "G10/CA-251 -- the stale lock file still exists after git-lock-check claimed to remove it"
  if find "$(dirname "$lock_file")" -maxdepth 1 -name "$(basename "$lock_file").stale.*" 2>/dev/null | grep -q .; then
    fail "G10/CA-251 -- a '.stale.\$\$' mv-aside artifact was left behind uncleaned"
  else
    pass "G10/CA-251 -- no leaked '.stale.\$\$' mv-aside artifact remains"
  fi
}
with_scratch_repo g10_removed_case

g10_pgrep_undetermined_case() {
  local lock_file=".git/index.lock"
  : > "$lock_file"
  local backdate
  backdate="$(date -v-5M +%Y%m%d%H%M 2>/dev/null || date -d '5 minutes ago' +%Y%m%d%H%M 2>/dev/null || true)"
  [[ -n "$backdate" ]] || { echo "  SKIP: G10/CA-251 -- could not backdate the lock file; skipping the pgrep-undetermined case"; return; }
  touch -t "$backdate" "$lock_file"
  # Shadow lsof to find nothing (the normal not-held case) and pgrep to exit 2 -- simulating an
  # invalid extended regex in git_dir (an unbalanced bracket, a trailing backslash), which is
  # NOT pgrep's documented "no processes matched" exit of 1. Exported so the child `edm-state`
  # process (a separate bash invocation, not sourced) inherits both shadows.
  lsof() { return 1; }
  pgrep() { return 2; }
  export -f lsof pgrep
  local out ec=0
  out="$("$EDM_STATE" git-lock-check 2>&1)" || ec=$?
  unset -f lsof pgrep 2>/dev/null || true
  [[ $ec -eq 1 ]] \
    && pass "G10/CA-251 -- git-lock-check refuses (exit 1) when pgrep exits undetermined (not 1)" \
    || fail "G10/CA-251 -- git-lock-check exited ${ec} on an undetermined pgrep exit, expected 1 (output: ${out})"
  check "G10/CA-251 -- the refusal names pgrep's non-1 exit code, not a silent proceed" \
    "pgrep exited 2" "$out"
  [[ -e "$lock_file" ]] \
    && pass "G10/CA-251 -- the lock file survives an undetermined pgrep exit (not removed with no liveness check having run)" \
    || fail "G10/CA-251 -- the lock file was removed despite pgrep's liveness check being undetermined"
}
with_scratch_repo g10_pgrep_undetermined_case

g10_toctou_case() {
  local lock_file=".git/index.lock"
  : > "$lock_file"
  local backdate
  backdate="$(date -v-5M +%Y%m%d%H%M 2>/dev/null || date -d '5 minutes ago' +%Y%m%d%H%M 2>/dev/null || true)"
  [[ -n "$backdate" ]] || { echo "  SKIP: G10/CA-251 -- could not backdate the lock file; skipping the TOCTOU re-check case"; return; }
  touch -t "$backdate" "$lock_file"
  # Shadow lsof to simulate a concurrent re-acquire happening DURING the liveness probe: touch
  # the lock file to "now" (as a real re-acquiring git process would) and THEN report no holder
  # evidence (lsof genuinely finds nothing for a lock a process just barely created). Without
  # the re-asserted age gate immediately before the mv, this would rename the now-live lock
  # aside and delete it.
  lsof() { local f="$1"; [[ "$f" == "--" ]] && f="$2"; touch "$f"; return 1; }
  export -f lsof
  local out ec=0
  out="$("$EDM_STATE" git-lock-check 2>&1)" || ec=$?
  unset -f lsof 2>/dev/null || true
  [[ $ec -eq 1 ]] \
    && pass "G10/CA-251 -- git-lock-check refuses (exit 1) when the lock reads fresh again immediately before the mv" \
    || fail "G10/CA-251 -- git-lock-check exited ${ec} instead of refusing on a lock re-acquired during the probe (output: ${out})"
  check "G10/CA-251 -- the refusal names the re-check, not the entry-level age gate" \
    "re-checked immediately before removal" "$out"
  [[ -e "$lock_file" ]] \
    && pass "G10/CA-251 -- the re-acquired lock file survives (not renamed aside and deleted out from under the new holder)" \
    || fail "G10/CA-251 -- the re-acquired lock file was removed -- the TOCTOU window is still open"
}
with_scratch_repo g10_toctou_case

echo
echo "=== G44: metrics-report's jq 'add' calls all guard against an empty array (null) with '// 0' ==="
t_g44_metrics_body="$(awk '/^cmd_metrics_report\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"
t_g44_unguarded="$(printf '%s\n' "$t_g44_metrics_body" | grep -E '\| add\)' | grep -v '// 0' || true)"
[[ -z "$t_g44_unguarded" ]] \
  && pass "G44 -- every '| add)' in cmd_metrics_report's jq programs is guarded with '// 0'" \
  || fail "G44 -- unguarded 'add' found in cmd_metrics_report:\n$t_g44_unguarded"
check "G44 -- the --all/--with-human-baseline totals guard add with // 0" \
  "add // 0) as \$tc" "$t_g44_metrics_body"

g44_case() {
  "$EDM_STATE" init G44FRESH >/dev/null
  local out
  out="$("$EDM_STATE" metrics-report G44FRESH --with-human-baseline 2>&1)"
  check_absent "G44 -- a freshly initialized initiative's metrics-report never renders 'null'" \
    "null" "$out"
  out="$("$EDM_STATE" metrics-report G44FRESH 2>&1)"
  check_absent "G44 -- the non-baseline report also never renders 'null'" "null" "$out"
}
with_scratch_repo g44_case

echo
echo "=== G46: archive and migrate-path hold the state lock across their directory rename ==="
check "G46 -- cmd_archive wraps its rename in with_state_lock" \
  'with_state_lock "${state_file%.json}" _cmd_archive_move_body' "$(cat "$EDM_STATE")"
check "G46 -- _cmd_archive_move_body renames via git_aware_mv BEFORE removing the lockdir/lockfile at the destination (G17/CA-206 rename-then-clean order)" \
  "git_aware_mv" "$(awk '/^_cmd_archive_move_body\(\)/{f=1} f{print} f && (/rm -rf.*_dst_lockbase/ || /^}/){exit}' "$EDM_STATE")"
check "G46 -- cmd_migrate_path wraps its initial rename in with_state_lock" \
  'with_state_lock "$migrate_lockbase" _cmd_migrate_path_move_body' "$(cat "$EDM_STATE")"
check "G46 -- _cmd_migrate_path_move_body also renames via git_aware_mv BEFORE removing the lockdir/lockfile at the destination (G17/CA-206 rename-then-clean order)" \
  "git_aware_mv" "$(awk '/^_cmd_migrate_path_move_body\(\)/{f=1} f{print} f && (/rm -rf.*_dst_lockbase/ || /^}/){exit}' "$EDM_STATE")"
t_g46_migrate_body="$(awk '/^cmd_migrate_path\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"
check_absent "G46 -- migrate-path no longer pre-emptively deletes the carried-over .bak before the write that might need it" \
  'rm -f "${new_state_file}.bak"' "$t_g46_migrate_body"

# =================================================================================
# G16/CA-304 (round 5): two residuals of the G46 lock-discipline sweep, both in
# _cmd_migrate_path_move_body's tail -- the destination sweep unlinked the flock lockfile
# itself under a false "same exception as archive" claim, and the post-failure rollback
# rename ran with no lock held at all, the one directory move in this file with none.
# =================================================================================
t_g16_move_body="$(awk '/^_cmd_migrate_path_move_body\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"
check "G16/CA-304 -- the migrate move body's destination sweep removes only .lockd" \
  $'rm -rf "${_dst_lockbase}.lockd"\n' "$t_g16_move_body"
check_absent "G16/CA-304 -- the migrate move body no longer removes .lockd and .lock together in one rm -rf (the flock lockfile itself is no longer unlinked)" \
  '"${_dst_lockbase}.lockd" "${_dst_lockbase}.lock"' "$t_g16_move_body"
check_absent "G16/CA-304 -- the false 'same exception as archive' claim is gone from this file" \
  "Same narrow, deliberate exception to CA-169 as _cmd_archive_move_body above" "$(cat "$EDM_STATE")"
check "G16/CA-304 -- the rollback rename is now wrapped in a fresh with_state_lock acquisition, mirroring the forward move" \
  'with_state_lock "${dst}/.edm-state" _cmd_migrate_path_rollback_body' "$t_g46_migrate_body"
check_absent "G16/CA-304 -- cmd_migrate_path's post-failure branch no longer calls git_aware_mv bare (unlocked)" \
  $'    git_aware_mv "$dst" "$src"\n    die' "$t_g46_migrate_body"
t_g16_rollback_body="$(awk '/^_cmd_migrate_path_rollback_body\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"
check "G16/CA-304 -- the rollback body renames dst back to src via git_aware_mv" \
  'git_aware_mv "$_dst" "$_src"' "$t_g16_rollback_body"
check "G16/CA-304 -- the rollback body removes the product directory only if it is left empty (rmdir, not rm -rf)" \
  'rmdir "$_product_dir"' "$t_g16_rollback_body"

# Executing coverage for the rollback path itself. A jq-filter failure (corrupt destination
# JSON) triggers rollback without touching any directory permission, so it exercises the
# rollback exclusively -- unlike a permission-based injection, which was tried first and
# rejected: chmod'ing the source initiative directory to block the later write also blocks
# with_state_lock's own lock acquisition (mkdir needs write on the same directory), so it can
# never isolate "forward move succeeded, then only the write failed" from "the lock never
# acquired at all."
g16_rollback_case() {
  "$EDM_STATE" init G16C >/dev/null
  echo "{ this is not valid json" > "SRD/G16C/.edm-state.json"
  local out ec=0
  out="$("$EDM_STATE" migrate-path --product g16prodc --description g16descc G16C 2>&1)" || ec=$?
  [[ $ec -ne 0 ]] \
    && pass "G16/CA-304 -- migrate-path refuses (non-zero exit) when the moved state file is corrupt JSON" \
    || fail "G16/CA-304 -- migrate-path exited 0 despite a jq-filter failure, output: $out"
  [[ -d "SRD/G16C" ]] \
    && pass "G16/CA-304 -- the rollback actually moved the directory back to the source path" \
    || fail "G16/CA-304 -- SRD/G16C not found after rollback -- the directory was not moved back"
  [[ ! -e "SRD/g16prodc/G16C__g16descc" ]] \
    && pass "G16/CA-304 -- nothing is left behind at the destination after rollback" \
    || fail "G16/CA-304 -- SRD/g16prodc/G16C__g16descc still exists after rollback"
  [[ ! -d "SRD/g16prodc" ]] \
    && pass "G16/CA-304 -- the product directory this call created is removed on rollback (left empty by the failed move)" \
    || fail "G16/CA-304 -- SRD/g16prodc still exists after rollback despite holding nothing"
}
with_scratch_repo g16_rollback_case

g16_rollback_nonempty_product_case() {
  "$EDM_STATE" init G16SIB >/dev/null
  "$EDM_STATE" migrate-path --product g16prodd --description sibdesc G16SIB >/dev/null
  "$EDM_STATE" init G16D >/dev/null
  echo "{ also not valid json" > "SRD/G16D/.edm-state.json"
  "$EDM_STATE" migrate-path --product g16prodd --description g16descd G16D >/dev/null 2>&1 || true
  [[ -d "SRD/g16prodd/G16SIB__sibdesc" ]] \
    && pass "G16/CA-304 -- an unrelated sibling initiative already in the product directory survives the rollback" \
    || fail "G16/CA-304 -- the sibling initiative SRD/g16prodd/G16SIB__sibdesc was destroyed by the rollback's product-dir cleanup"
  [[ -d "SRD/g16prodd" ]] \
    && pass "G16/CA-304 -- the product directory itself survives rollback when it is NOT left empty" \
    || fail "G16/CA-304 -- SRD/g16prodd was removed despite still holding the sibling initiative"
}
with_scratch_repo g16_rollback_nonempty_product_case

g46_archive_case() {
  export EDM_MODE="prototype"
  "$EDM_STATE" init G46ARCH >/dev/null
  unset EDM_MODE
  "$EDM_STATE" approve-gate G46ARCH 1 >/dev/null
  local state_g46arch="SRD/G46ARCH/.edm-state.json"
  jq '.current_phase = 2 | .phase_durations["2_phase"] = {started_at: "2026-01-01T00:00:00Z", completed_at: "2026-01-01T01:00:00Z"}' \
    "$state_g46arch" > "${state_g46arch}.tmp" && mv "${state_g46arch}.tmp" "$state_g46arch"
  local out ec=0
  out="$("$EDM_STATE" archive G46ARCH 2>&1)" || ec=$?
  [[ $ec -eq 0 ]] \
    && pass "G46 -- archive still succeeds end-to-end for an eligible (prototype-mode) initiative under the new lock wrapping" \
    || fail "G46 -- archive failed (exit ${ec}) after the lock-wrapping change: $out"
  [[ -d "SRD/.archived/G46ARCH" ]] \
    && pass "G46 -- the archived directory exists at the expected destination" \
    || fail "G46 -- SRD/.archived/G46ARCH not found after archive"
  [[ ! -e "SRD/.archived/G46ARCH/.edm-state.lockd" && ! -e "SRD/.archived/G46ARCH/.edm-state.lock" ]] \
    && pass "G46 -- no lockdir/lockfile artifact traveled to the archive destination" \
    || fail "G46 -- a lockdir/lockfile artifact was found at the archive destination"
}
with_scratch_repo g46_archive_case

g46_migrate_case() {
  "$EDM_STATE" init G46MIG >/dev/null
  local out ec=0
  out="$("$EDM_STATE" migrate-path --product g46prod --description g46desc G46MIG 2>&1)" || ec=$?
  [[ $ec -eq 0 ]] \
    && pass "G46 -- migrate-path still succeeds end-to-end under the new lock wrapping" \
    || fail "G46 -- migrate-path failed (exit ${ec}) after the lock-wrapping change: $out"
  [[ -f "SRD/g46prod/G46MIG__g46desc/.edm-state.json" ]] \
    && pass "G46 -- the migrated state file exists at the expected destination" \
    || fail "G46 -- SRD/g46prod/G46MIG__g46desc/.edm-state.json not found after migrate-path"
}
with_scratch_repo g46_migrate_case

echo
echo "=== G47: get_session_tokens_since's whole-directory fallback caps EACH session file independently; EDM_TOKEN_READ_LINE_CAP=0 is refused ==="
check_absent "G47 -- the whole-directory fallback no longer concatenates all session files before capping" \
  'cat "$sessions_dir"/*.jsonl 2>/dev/null | tail -n' "$(awk '/^get_session_tokens_since\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"
check "G47 -- the fallback now loops over session files individually, capping each one" \
  'for _tf in "$sessions_dir"/*.jsonl' "$(awk '/^get_session_tokens_since\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"
check "G47 -- the cap validator now requires a positive integer (rejects 0)" \
  '^[1-9][0-9]*$' "$(awk '/^get_session_tokens_since\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"
check "G47 -- the refusal message names the ZERO_TOKENS consequence a CAP=0 would otherwise cause" \
  "trips the blocking ZERO_TOKENS anomaly" "$(awk '/^get_session_tokens_since\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"

g47_zero_case() {
  local scratch
  scratch="$(mktemp -d "${TMP}/edm-g47zero.XXXXXX")" || { fail "G47 -- mktemp failed"; return 1; }
  (
    cd "$scratch" || exit 1
    sess_dir="$(session_dir_for_test_cwd)"
    mkdir -p "$sess_dir"
    stage_session_jsonl "$sess_dir" a.jsonl claude-sonnet-4-7 10 5
    ec=0
    out="$(EDM_TOKEN_READ_LINE_CAP=0 bash -c "source '$EDM_STATE' >/dev/null 2>&1; get_session_tokens_since 2000-01-01T00:00:00Z" 2>&1)" || ec=$?
    printf 'ec=%s out=%s\n' "$ec" "$out"
    rm -rf "$sess_dir"
  )
}
t_g47_zero_out="$(g47_zero_case)"
t_g47_zero_ec="$(printf '%s' "$t_g47_zero_out" | grep -oE '^ec=[0-9-]+' | cut -d= -f2)"
[[ "${t_g47_zero_ec:-0}" -ne 0 ]] \
  && pass "G47 -- EDM_TOKEN_READ_LINE_CAP=0 is refused rather than silently reading zero lines" \
  || fail "G47 -- expected refusal of EDM_TOKEN_READ_LINE_CAP=0, got: $t_g47_zero_out"
check "G47 -- the refusal names the bad line-cap value" "invalid EDM_TOKEN_READ_LINE_CAP" "$t_g47_zero_out"

# ---- G47b: the whole-directory fallback sums EVERY session file, not just the tail of the
# concatenation. Forces the fallback branch deterministically by shadowing `ls` so the
# driving-session picker (`ls -t ... | head -1`) finds NOTHING (succeeds, but enumerates zero
# files) while the initial directory-has-jsonl-files existence check (a bare `ls`, no `-t`)
# still succeeds -- the exact AC2 "driving session could not be identified" condition, without
# depending on a real race. The shadow returns 0 (not 1) for the `-t` case deliberately: a
# genuine `ls -t` failure feeds a failing exit status into `... | head -1` which, under this
# file's own `set -euo pipefail`, aborts the whole function before it ever reaches the fallback
# branch this case exists to exercise (a separate, pre-existing pipefail hazard on that exact
# line, out of scope for G47) -- so the empty-success shape is the only way to actually reach
# and exercise the AC2 fallback path this case is testing.
g47_fallback_case() {
  local scratch
  scratch="$(mktemp -d "${TMP}/edm-g47fb.XXXXXX")" || { fail "G47b -- mktemp failed"; return 1; }
  (
    cd "$scratch" || exit 1
    sess_dir="$(session_dir_for_test_cwd)"
    mkdir -p "$sess_dir"
    stage_session_jsonl "$sess_dir" a-first.jsonl claude-sonnet-4-7 11 0 "2026-01-01T00:00:00Z"
    stage_session_jsonl "$sess_dir" b-second.jsonl claude-sonnet-4-7 22 0 "2026-01-01T00:00:01Z"
    ls() { if [[ "${1:-}" == "-t" ]]; then return 0; fi; command ls "$@"; }
    export -f ls
    out="$(bash -c "source '$EDM_STATE' >/dev/null 2>&1; get_session_tokens_since 2000-01-01T00:00:00Z")"
    echo "out=$out"
    rm -rf "$sess_dir"
  )
}
t_g47_fallback_out="$(g47_fallback_case)"
t_g47_fallback_json="${t_g47_fallback_out#out=}"
check "G47b -- the forced whole-directory fallback tags attribution_mode accordingly" \
  '"attribution_mode": "whole-directory"' "$t_g47_fallback_json"
t_g47_fallback_input="$(printf '%s' "$t_g47_fallback_json" | jq -r '.input' 2>/dev/null || echo "?")"
check "G47b -- the fallback sums BOTH session files' input tokens (11+22=33), not just one file's tail" \
  "33" "$t_g47_fallback_input"

echo
echo "=== G48: watch-impl distinguishes a genuine git-log failure from history rewritten out from under last_sha, and advances last_sha on every successful poll ==="
t_g48_body="$(awk '/^cmd_watch_impl\(\)/{f=1} f{print} f && /^}/{exit}' "$EDM_STATE")"
check "G48 -- git log's own exit status is captured separately from grep's" \
  'git_log_out="$(git log' "$t_g48_body"
check "G48 -- a git-log failure is checked against whether last_sha is still a valid ref" \
  'git cat-file -e "${last_sha}^{commit}"' "$t_g48_body"
check "G48 -- a rewritten history re-anchors last_sha at HEAD with a named diagnostic" \
  "history was rewritten" "$t_g48_body"
check "G48 -- last_sha advances to HEAD on every successful poll, not only on a match" \
  'last_sha="$(git rev-parse HEAD' "$t_g48_body"

g48_rewrite_case() {
  local scratch
  scratch="$(mktemp -d "${TMP}/edm-g48.XXXXXX")" || { fail "G48 -- mktemp failed"; return 1; }
  ( cd "$scratch" && \
    git init -q . >/dev/null 2>&1 && \
    git config user.email "g48@example.com" && git config user.name "G48 Test" && git config commit.gpgsign false && \
    echo one > a.txt && git add a.txt && git commit -q -m "first" >/dev/null 2>&1 ) || true
  local pruned_sha
  pruned_sha="$(cd "$scratch" && git rev-parse HEAD 2>/dev/null || true)"
  if [[ -z "$pruned_sha" ]]; then
    fail "G48 -- rewrite sub-case setup failed (no initial commit in scratch repo)"
    rm -rf "$scratch"
    return
  fi
  ( cd "$scratch" && echo two > a.txt && git add a.txt && git commit -q --amend -m "amended" >/dev/null 2>&1 ) || true
  # Force the pruned commit unreachable for real (reflog would otherwise keep it alive).
  ( cd "$scratch" && git reflog expire --expire=now --all >/dev/null 2>&1; git gc --prune=now >/dev/null 2>&1 ) || true
  # Bare `cmd && var=0` (or a bare subshell alone) as a top-level statement takes on that
  # command's own exit status under `set -e` -- when the EXPECTED outcome here is that the
  # commit is unreachable (cat-file fails), a bare form would abort this whole suite right at
  # the moment the test is working as intended. Wrap in `if` so only `still_reachable`'s value
  # carries the result.
  local still_reachable=1
  if ( cd "$scratch" && git cat-file -e "${pruned_sha}^{commit}" 2>/dev/null ); then
    still_reachable=0
  fi
  if [[ $still_reachable -eq 0 ]]; then
    echo "  SKIP: G48 rewrite sub-case -- this git/filesystem did not actually prune the old commit (gc left it reachable)"
  else
    local ec=0 out
    out="$(cd "$scratch" && bash -c "
      source '$EDM_STATE' >/dev/null 2>&1
      last_sha='$pruned_sha'
      git_log_out=\"\$(git log --pretty=format:'%h %s' \"\${last_sha}..HEAD\" 2>/dev/null)\" || git_log_ec=\$?
      if [[ \"\${git_log_ec:-0}\" -ne 0 ]]; then
        if git cat-file -e \"\${last_sha}^{commit}\" 2>/dev/null; then
          echo 'still-valid'
        else
          echo 'history was rewritten (pruned-sha-test); monitor re-anchored at current HEAD'
        fi
      else
        echo 'log-succeeded'
      fi
    ")" || ec=$?
    check "G48 -- a pruned, unreachable last_sha is correctly detected via git cat-file -e" \
      "history was rewritten" "$out"
  fi
  rm -rf "$scratch"
}
g48_rewrite_case

echo
echo "=== G49: with_state_lock's flock timeout is detected via a side-channel marker file, not a magic exit code any locked body could collide with ==="
check "G49 -- the timeout branch writes a dedicated marker file instead of relying solely on exit 99" \
  '_lock_timeout_marker' "$(cat "$EDM_STATE")"
check "G49 -- the timeout is detected by checking for the marker file's existence, not the locked body's own exit code" \
  'if [[ -e "$_lock_timeout_marker" ]]; then' "$(cat "$EDM_STATE")"

# No locked body anywhere in this file may itself use exit/return 99 -- that would defeat the
# marker-file redesign's whole purpose by making the marker and a real body-originated 99 both
# plausible outcomes to reason about. Scoped to bin/edm-state's own function bodies, excluding
# the one sanctioned timeout-branch use inside with_state_lock itself (identified by the
# adjacent marker-file write) and this comment block's own prose.
t_g49_ec99_hits="$(grep -nE '(^|[^0-9])(exit|return) 99([^0-9]|$)' "$EDM_STATE" | grep -vE '^[0-9]+:[[:space:]]*#' | grep -v '_lock_timeout_marker' || true)"
[[ -z "$t_g49_ec99_hits" ]] \
  && pass "G49 -- no locked body in bin/edm-state returns/exits 99 outside the one sanctioned with_state_lock timeout use" \
  || fail "G49 -- a bare exit/return 99 was found outside the sanctioned use:\n$t_g49_ec99_hits"

g49_timeout_case() {
  local tmp_g49
  tmp_g49="$(mktemp -d "${TMPDIR:-/tmp}/edm-g49.XXXXXX")" || { fail "G49 -- mktemp failed"; return 1; }
  (
    set +e
    trap - EXIT INT TERM HUP
    source "$EDM_STATE" >/dev/null 2>&1
    lockbase="${tmp_g49}/state"
    lockfile="${lockbase}.lock"
    # Hold the flock in a background subshell for longer than with_state_lock's own 10s
    # timeout, so the call below is guaranteed to time out. Deliberately never `kill` or `wait`
    # this background job -- bash 3.2's `wait` on a job terminated by a signal can hang forever
    # under `set -e` (a real, previously-reproduced interaction; see the CA-141 case above) --
    # so it is simply left to run out its own sleep and exit on its own after this case returns.
    ( flock 200; sleep 12 ) 200>"$lockfile" &
    sleep 0.3
    ec=0
    body_that_exits_99() { exit 99; }
    out="$(with_state_lock "$lockbase" body_that_exits_99 2>&1)" || ec=$?
    printf 'ec=%s out=%s\n' "$ec" "$out"
  )
  rm -rf "$tmp_g49"
}
if command -v flock >/dev/null 2>&1; then
  t_g49_out="$(g49_timeout_case)"
  check "G49 -- a locked body that itself exits 99 while genuinely timed out is still reported as a lock timeout (both true here)" \
    "state lock timeout" "$t_g49_out"
else
  echo "  SKIP: G49 live-timeout sub-case -- flock(1) not available on this host"
fi

# =================================================================================
# G17/CA-305 (round 5): the flock-timeout marker's TWO defects -- a symlink-attackable
# truncating redirect, and silent failure with no diagnostic if the marker write fails. Both
# reachable only under genuine flock contention (unavailable on this host, per G49 above), so
# these cases test the marker MECHANISM directly rather than driving it through a real timeout.
# =================================================================================
echo
echo "=== G17/CA-305: the flock-timeout marker is derived under TMPDIR and created with mkdir, not a truncating redirect inside the artifact directory ==="
g17_edm_state_content="$(cat "$EDM_STATE")"
check "G17/CA-305 -- the marker is derived under TMPDIR, not inside the lockfile's own (tracked) directory" \
  '_lock_timeout_marker="${TMPDIR:-/tmp}/edm-state.lock-timeout.$$"' "$g17_edm_state_content"
check "G17/CA-305 -- the timeout branch creates the marker with mkdir (atomic, refuses any existing name)" \
  'mkdir "$_lock_timeout_marker" 2>/dev/null; exit 99' "$g17_edm_state_content"
check_absent "G17/CA-305 -- the timeout branch no longer creates the marker with a truncating, symlink-following redirect" \
  ': > "$_lock_timeout_marker"' "$g17_edm_state_content"
check "G17/CA-305 -- a secondary diagnostic arm still names the timeout when the marker mkdir itself fails" \
  'elif [[ $_lock_ec -eq 99 ]]; then' "$g17_edm_state_content"
check "G17/CA-305 -- the secondary diagnostic's message still contains the same 'state lock timeout' text the primary one uses" \
  'the timeout marker could not be created' "$g17_edm_state_content"

echo "  mechanism case: mkdir refuses a pre-planted symlink at the marker's name; a truncating redirect would not have"
g17_symlink_attack_case() {
  local target marker mkdir_ec=0
  target="$(mktemp "${TMP}/edm-g17-secret.XXXXXX")"
  marker="${TMP}/edm-g17-marker.$$"
  printf 'secret content\n' > "$target"
  ln -s "$target" "$marker"
  mkdir "$marker" 2>/dev/null || mkdir_ec=$?
  [[ $mkdir_ec -ne 0 ]] \
    && pass "G17/CA-305 -- mkdir refuses to create the marker over a pre-planted symlink (the attack window this fix closes)" \
    || fail "G17/CA-305 -- mkdir succeeded over a pre-planted symlink -- the attack window is still open"
  [[ "$(cat "$target" 2>/dev/null)" == "secret content" ]] \
    && pass "G17/CA-305 -- the symlink target's content is untouched (mkdir neither follows nor truncates a symlink, unlike ': >')" \
    || fail "G17/CA-305 -- the symlink target's content was altered by the marker-creation attempt"
  rm -f "$target" "$marker"
}
g17_symlink_attack_case

# =================================================================================
# G20/CA-049 (round 5, final pass): one mechanical sweep -- wave3-smoke.sh and wave4a-smoke.sh
# still re-derived the whole SCRIPT_DIR path chain inline at their `source .../_harness.sh` line
# instead of reusing the SCRIPT_DIR variable already set two lines above, and the
# `${BASH_SOURCE[0]:-$0}` fallback (present at wave4b/wave7) was absent from the other five
# suites' SCRIPT_DIR line. All seven now share one shape, matching _harness.sh's own docstring.
# =================================================================================
echo
echo "=== G20/CA-049: all seven smoke suites derive SCRIPT_DIR with the \${BASH_SOURCE[0]:-\$0} fallback and source _harness.sh via that variable, never an inline re-derivation ==="
# Self-avoiding split needle (same idiom T35 AC4/T36 AC8 use elsewhere in this file): this loop
# scans wave7-smoke.sh's own content among the seven suites, so any single contiguous literal
# spelling the banned inline-rederivation line would match THIS test's own source text. Neither
# half below spells the banned line; only the runtime-concatenated value does.
g20_bad_prefix='source "$(cd "$(dirname "${BASH_SOURCE[0]}")"'
g20_bad_suffix=' && pwd)/_harness.sh"'
g20_bad_needle="${g20_bad_prefix}${g20_bad_suffix}"
for g20_suite in wave3-smoke.sh wave4a-smoke.sh wave4b-smoke.sh wave5-smoke.sh wave6-smoke.sh wave7-smoke.sh harness-smoke.sh; do
  g20_content="$(cat "${SCRIPT_DIR}/${g20_suite}" 2>/dev/null)"
  check "G20/CA-049 -- ${g20_suite} derives SCRIPT_DIR with the \${BASH_SOURCE[0]:-\$0} fallback" \
    'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"' "$g20_content"
  check_absent "G20/CA-049 -- ${g20_suite} never re-derives the path chain inline at its source line" \
    "$g20_bad_needle" "$g20_content"
done

# =================================================================================
# G21/CA-074 (round 5, escalated since round 1): die() forked into three shapes across twelve
# bin/ and evals/ scripts. Standardized on the two-argument form edm-validate-prefix already
# carried the rationale for -- avoids a bare `$*` silently swallowing an intended exit-code
# override into the message text. Each script keeps its own pre-existing default exit code
# (edm-init and edm-state default to 1, their own long-standing contract; every other script
# defaults to 2) -- only the SHAPE is unified, not every script's numeric default.
# =================================================================================
echo
echo "=== G21/CA-074: every bin/* and evals/*.sh die() matches the canonical two-argument shape ==="
g21_die_map="edm-check-grants:2 edm-check-skill-sync:2 edm-check-vocabulary:2 edm-compare-eval:2 edm-init:1 edm-lint-artifacts:2 edm-state:1 edm-sync-canonical-sections:2 edm-validate-prefix:1"
for g21_pair in $g21_die_map; do
  g21_script="${PLUGIN_DIR}/bin/${g21_pair%%:*}"
  g21_default="${g21_pair##*:}"
  g21_body="$(awk '/^die\(\)/{f=1} f{print} f && /^}/{exit}' "$g21_script" 2>/dev/null)"
  check "G21/CA-074 -- bin/$(basename "$g21_script")'s die() takes the canonical two-argument form" \
    'local msg="$1" code="${2:-'"${g21_default}"'}"' "$g21_body"
  check "G21/CA-074 -- bin/$(basename "$g21_script")'s die() exits via the code variable, not a hardcoded literal" \
    'exit "$code"' "$g21_body"
done
g21_evals_map="run-eval.sh:2 score-artifacts.sh:2 tiering-matrix.sh:2"
for g21_pair in $g21_evals_map; do
  g21_script="${PLUGIN_DIR}/evals/${g21_pair%%:*}"
  g21_default="${g21_pair##*:}"
  g21_body="$(awk '/^die\(\)/{f=1} f{print} f && /^}/{exit}' "$g21_script" 2>/dev/null)"
  check "G21/CA-074 -- evals/$(basename "$g21_script")'s die() takes the canonical two-argument form" \
    'local msg="$1" code="${2:-'"${g21_default}"'}"' "$g21_body"
  check "G21/CA-074 -- evals/$(basename "$g21_script")'s die() exits via the code variable, not a hardcoded literal" \
    'exit "$code"' "$g21_body"
done

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
