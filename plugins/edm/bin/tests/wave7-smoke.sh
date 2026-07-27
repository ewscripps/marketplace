#!/usr/bin/env bash
# wave7-smoke.sh -- EDMV3-T09 (EDMV3-15) contract-suite coverage: the check-script /
# caller-contract tests that are NOT lifecycle smoke cases (those live in wave6-smoke.sh).
# This suite asserts that `cmd_set`'s SETTABLE_KEYS allowlist and its real callers across
# skills/agents/hooks/bin can never drift apart silently, and that the no-override-flag
# scope boundary (EDMV3-90) holds for bin/edm-state.
# Run from repo root: bash plugins/edm/bin/tests/wave7-smoke.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EDM_STATE="${SCRIPT_DIR}/../edm-state"
PLUGIN_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Shared assertions / counters (CA-014).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_harness.sh"

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
live_out="$(caller_contract_scan "$PLUGIN_DIR" 2>&1)"
live_ec=$?
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
  scratch="$(mktemp -d /tmp/edm-wave7-neg.XXXXXX)" || { fail "AC12 -- mktemp failed"; return 1; }

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
  out="$(caller_contract_scan "$scratch" 2>&1)"
  ec=$?
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
force_count="$(grep -c -- '--force' "$EDM_STATE" 2>/dev/null || true)"
force_count="${force_count:-0}"
[[ "$force_count" -eq 0 ]] && pass "no literal --force in bin/edm-state" \
  || fail "found $force_count occurrence(s) of literal --force in bin/edm-state"

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
t03_sources_out="$(bash "$EDM_CHECK_GRANTS" --list-sources 2>&1)"
t03_sources_ec=$?
t03_sources_count="$(printf '%s\n' "$t03_sources_out" | grep -c '.')"
[[ $t03_sources_ec -eq 0 ]] && pass "--list-sources exits 0" || fail "--list-sources exited $t03_sources_ec"
[[ "$t03_sources_count" -eq 4 ]] && pass "--list-sources prints exactly four lines" \
  || fail "--list-sources printed $t03_sources_count line(s), expected 4:\n$t03_sources_out"
check "source label: agent-bodies" "agent-bodies" "$t03_sources_out"
check "source label: skill-launch-templates" "skill-launch-templates" "$t03_sources_out"
check "source label: hook-prompt-text" "hook-prompt-text" "$t03_sources_out"
check "source label: skill-allowed-tools-vs-body" "skill-allowed-tools-vs-body" "$t03_sources_out"

echo
echo "T03 AC7 -- exit contract: usage error is exit 2"
set +e
bash "$EDM_CHECK_GRANTS" --bogus-flag >/tmp/edm-cg-bogus.$$.out 2>&1
t03_bogus_ec=$?
set -e
[[ $t03_bogus_ec -eq 2 ]] && pass "unknown flag exits 2" || fail "unknown flag exited $t03_bogus_ec, expected 2"
rm -f "/tmp/edm-cg-bogus.$$.out"

echo
echo "T03 AC2/AC4 -- every agent grant is satisfied against the live (post-EDMV3-T02) tree"
set +e
t03_live_out="$(bash "$EDM_CHECK_GRANTS" 2>&1)"
t03_live_ec=$?
set -e
[[ $t03_live_ec -eq 0 ]] && pass "edm-check-grants exits 0 against the live tree" \
  || fail "edm-check-grants exited $t03_live_ec against the live tree:\n$t03_live_out"
t03_live_agent_count="$(printf '%s\n' "$t03_live_out" | grep -c '^agent:' || true)"
[[ "$t03_live_agent_count" -eq 0 ]] && pass "zero unsatisfied agents against the live tree" \
  || fail "found $t03_live_agent_count unsatisfied agent(s) against the live tree"

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
  scratch="$(mktemp -d /tmp/edm-cg-ac6.XXXXXX)" || { fail "AC6 -- mktemp failed"; return 1; }

  mkdir -p "$scratch/bin"
  cp -R "$PLUGIN_DIR/agents" "$scratch/agents"
  cp -R "$PLUGIN_DIR/skills" "$scratch/skills"
  cp -R "$PLUGIN_DIR/hooks" "$scratch/hooks"
  cp "$EDM_CHECK_GRANTS" "$scratch/bin/edm-check-grants"
  chmod +x "$scratch/bin/edm-check-grants"

  # Strip AskUserQuestion from the scratch copy of plan/SKILL.md's allowed-tools line only.
  local target="$scratch/skills/plan/SKILL.md"
  sed -i.bak 's/, AskUserQuestion$//' "$target"
  rm -f "${target}.bak"

  local out ec
  set +e
  out="$(bash "$scratch/bin/edm-check-grants" 2>&1)"
  ec=$?
  set -e

  [[ $ec -eq 1 ]] && pass "AC6 -- missing AskUserQuestion on a gate skill fails the run" \
    || fail "AC6 -- expected exit 1, got $ec"
  check "AC6 -- failure names skills/plan/SKILL.md" "skills/plan/SKILL.md" "$out"
  check "AC6 -- failure class is missing-askuserquestion-grant" "missing-askuserquestion-grant" "$out"

  rm -rf "$scratch"
}
t03_ac6_case

echo
echo "T03 AC8 -- mirrors (not re-derives) edm-lint-artifacts's report_violation/build_ignore_set/is_ignored_line"
t03_mirror_hits="$(grep -c 'report_violation\|build_ignore_set\|is_ignored_line' "$EDM_CHECK_GRANTS" || true)"
[[ "${t03_mirror_hits:-0}" -gt 0 ]] && pass "AC8 -- mirrored helper names present in edm-check-grants" \
  || fail "AC8 -- report_violation/build_ignore_set/is_ignored_line not found in edm-check-grants"

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
[[ "$t03_disk_count" -eq 30 ]] && pass "disk agent count is 30 (baseline)" \
  || fail "disk agent count is $t03_disk_count, expected 30"

echo
echo "T03 AC10 -- bash 3.2 compatible (no associative arrays/mapfile) and referenced by run-all.sh"
bash -n "$EDM_CHECK_GRANTS" && pass "edm-check-grants passes bash -n" \
  || fail "edm-check-grants failed bash -n"
check_absent "no associative array declarations (declare -A)" "declare -A" \
  "$(cat "$EDM_CHECK_GRANTS")"
t03_mapfile_usage="$(grep -cE '(^|[^a-zA-Z_])(mapfile|readarray)[[:space:]]' "$EDM_CHECK_GRANTS" || true)"
[[ "${t03_mapfile_usage:-0}" -eq 0 ]] && pass "no mapfile/readarray command usage" \
  || fail "found mapfile/readarray usage in edm-check-grants"
check "run-all.sh references edm-check-grants (AC10 smoke-aggregator half)" "edm-check-grants" \
  "$(cat "${SCRIPT_DIR}/run-all.sh")"

# =================================================================================
# EDMV3-T15: prompts present the convergence gate instead of setting the flag
# =================================================================================
# Batch scope note (recorded here rather than silently worked around): this batch's file
# remit is bin/tests/* only -- plugins/edm/skills/code-audit/SKILL.md and
# plugins/edm/skills/orchestrator/SKILL.md are out of scope for this agent/batch to edit.
# As of this suite landing, only AC1, AC4 and AC7 are satisfied by the live skill text (AC7 is
# already covered by the "T03 AC5" block above -- code-audit/SKILL.md grants AskUserQuestion).
# AC2/AC3/AC5/AC6/AC8/AC9 require prose additions that do not exist anywhere in the tree yet:
#   - AC2/AC3: Step 10 must present the convergence gate via AskUserQuestion (header
#     "Convergence", options Approve/Revise/No-Go) AFTER computing the round result and BEFORE
#     calling `edm-state approve-gate <PREFIX> code-audit` -- today Step 10 calls approve-gate
#     directly with no gate presented first.
#   - AC5/AC8: orchestrator/SKILL.md Step 8 point 5 and the Step 9 checklist do not yet
#     reference the gate protocol by name.
#   - AC6: the free-prose remediation gate at code-audit/SKILL.md:193-200 is not yet upgraded
#     to AskUserQuestion or retitled "remediation gate".
# This is a genuinely missing dependency outside this batch's writable files, reported here
# rather than papered over with an assertion this suite cannot honestly make pass. Only the
# two cases below (already-true facts, regression-locked so they cannot silently regress) are
# added; AC2/AC3/AC5/AC6/AC8/AC9 are NOT asserted until the SKILL.md prose lands.
echo
echo "T15 AC1 -- code-audit/SKILL.md no longer instructs the model to set the flag directly"
CODE_AUDIT_SKILL="${PLUGIN_DIR}/skills/code-audit/SKILL.md"
t15_skills_grep="$(grep -rn 'code_audit_converged true' "${PLUGIN_DIR}/skills/" 2>/dev/null || true)"
check_absent "no prompt anywhere instructs 'edm-state set <PREFIX> code_audit_converged true'" \
  "code_audit_converged true" "$t15_skills_grep"

echo
echo "T15 AC4 -- gate summary states computed P0/P1/P2/NOTED counts"
check "code-audit/SKILL.md HITL gate names all four severity counts (P0/P1/P2/NOTED)" \
  "P0" "$(grep -o 'P0.*P1.*P2.*NOTED[^.]*' "$CODE_AUDIT_SKILL" || true)"
# EDMV3-T15 end (AC2/AC3/AC5/AC6/AC8/AC9 intentionally not asserted here -- see the block
# comment above)

# ---- Summary -----------------------------------------------------------------
echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
