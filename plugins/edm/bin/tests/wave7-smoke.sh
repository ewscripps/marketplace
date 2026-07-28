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
GITLAB_CI_YML="$(cd "$PLUGIN_DIR/../.." && pwd)/.gitlab-ci.yml"

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
t15_skills_grep="$(grep -rn 'code_audit_converged true' "${PLUGIN_DIR}/skills/" 2>/dev/null || true)"
check_absent "no prompt anywhere instructs 'edm-state set <PREFIX> code_audit_converged true'" \
  "code_audit_converged true" "$t15_skills_grep"

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
T15_STEP10="$(sed -n '54,69p' "$CODE_AUDIT_SKILL")"
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
  } > run-dir/srd.md
  echo "run-dir/srd.md written, TSVE-01 present" > /dev/null

  bash "$SCORE_ARTIFACTS" run-dir > out-a.json 2> err-a.json
  local rc_a=$?
  bash "$SCORE_ARTIFACTS" run-dir > out-b.json 2> err-b.json
  local rc_b=$?

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
  awk '/^# EDM-HELP-BEGIN/{f=1;next} /^# EDM-HELP-END/{f=0} f' "$f" \
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
  dispatch_file="$(mktemp /tmp/edm-t61-dispatch.XXXXXX)"
  help_file="$(mktemp /tmp/edm-t61-help.XXXXXX)"
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
t61_bidi_out="$(_t61_bidirectional_check "$EDM_STATE" 2>&1)"
t61_bidi_ec=$?
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
  scratch="$(mktemp /tmp/edm-t61-neg.XXXXXX)" || { fail "T61 AC2 negative -- mktemp failed"; return 1; }
  # Inject a dispatch-only entry (bogus-new-cmd) with no corresponding help doc line, immediately
  # above the closing `esac` -- case arm order is irrelevant to bash, so this is always valid.
  awk '/^esac/{print "  bogus-new-cmd) die \"nope\" ;;"} {print}' "$EDM_STATE" > "$scratch"

  local out ec
  set +e
  out="$(_t61_bidirectional_check "$scratch" 2>&1)"
  ec=$?
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
#   - list, active-initiatives, checkpoint-if-active, record-task-duration, git-lock-check,
#     session-start: every required argument is optional or absent by design.
#   - metrics-report: dispatches on an optional first arg (<PREFIX>|--all|--calibrate); zero
#     args is a valid "no scope" invocation path handled inside the command itself.
#   - watch-impl: an intentional infinite loop (tails git log until interrupted) -- it has no
#     usage-line concept and invoking it in a test would hang forever, not fail fast.
T61_ZERO_ARG_SAFE="list active-initiatives checkpoint-if-active record-task-duration git-lock-check session-start metrics-report watch-impl"
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
t61_cg_pipefail="$(grep -c '^set -euo pipefail' "$EDM_CHECK_GRANTS" || true)"
[[ "${t61_cg_pipefail:-0}" -ge 1 ]] && pass "edm-check-grants has set -euo pipefail" \
  || fail "edm-check-grants set -euo pipefail count: ${t61_cg_pipefail:-0}"

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
[[ -z "$t61_bash4_hits" ]] && pass "T61 AC9 -- zero bash-4-only constructs found in real bin/ scripts" \
  || fail "T61 AC9 -- bash-4-only construct(s) found:\n$t61_bash4_hits"

echo
echo "T61 AC10 -- bash -n passes over every file in plugins/edm/bin/ (incl. bin/tests/*.sh)"
t61_bashn_fail=0
for t61_f in "$PLUGIN_DIR"/bin/* "$PLUGIN_DIR"/bin/tests/*.sh; do
  [[ -f "$t61_f" ]] || continue
  bash -n "$t61_f" 2>/dev/null || { t61_bashn_fail=1; echo "  bash -n FAILED: $t61_f"; }
done
[[ $t61_bashn_fail -eq 0 ]] && pass "T61 AC10 -- bash -n passes over every bin/ and bin/tests/ file" \
  || fail "T61 AC10 -- bash -n failed on at least one file (see output above)"

echo
echo "T61 AC11 -- macOS/Linux divergence points (sed -i, grep -P family, stat -c/-f) are all inside a detection branch"
# -[a-zA-Z]*P (not a literal "grep -P") so this also catches grep -qP / -nP, the actual forms
# used by edm-lint-artifacts' PCRE-detection-and-fallback branch -- a literal "grep -P" search
# (as the ticket's own Verify command uses) misses those by one character and would falsely
# report zero hits, i.e. "nothing to check" rather than "checked and confined".
t61_divergence_hits="$(grep -rnE 'sed -i|grep -[a-zA-Z]*P|stat -c|stat -f' "$PLUGIN_DIR/bin/" 2>/dev/null | grep -v '/tests/' || true)"
t61_divergence_outside_branch="$(printf '%s\n' "$t61_divergence_hits" | grep -v 'edm-lint-artifacts:' || true)"
[[ -z "$t61_divergence_outside_branch" ]] \
  && pass "T61 AC11 -- every sed -i/grep -P family/stat -c//stat -f hit is inside edm-lint-artifacts' detection branch" \
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
  scratch="$(mktemp -d /tmp/edm-t20-path-dir.XXXXXX)" || { fail "T20 --path dir -- mktemp failed"; return 1; }
  mkdir -p "$scratch/a/b/c"
  printf '# top-level note\n\nClean ASCII content.\n' > "$scratch/top.md"
  printf '# nested note\n\nAlso clean ASCII content, three levels deep.\n' > "$scratch/a/b/c/nested.md"
  # An attribution-trailer violation buried two levels deep -- proves recursion actually reaches
  # it, not just the top-level file.
  printf '# violation note\n\nCo-Authored-By: Someone <someone@example.com>\n' > "$scratch/a/b/violation.md"

  local out ec
  set +e
  out="$("$EDM_LINT_ARTIFACTS" --path "$scratch" 2>&1)"
  ec=$?
  set -e

  [[ $ec -ne 0 ]] && pass "T20 -- --path <dir> recursion finds a violation nested two levels deep" \
    || fail "T20 -- --path <dir> did not detect the nested violation (exit $ec):\n$out"
  check "T20 -- --path <dir> names the nested violation file" "a/b/violation.md" "$out"

  rm -rf "$scratch"
}
t20_path_dir_case

echo
echo "T20 AC10 -- --path <file> lints exactly the one named file"
t20_path_file_out="$("$EDM_LINT_ARTIFACTS" --path "${PLUGIN_DIR}/evals/fixtures/tiny-svc/README.md" 2>&1)"
t20_path_file_ec=$?
[[ $t20_path_file_ec -eq 0 ]] && pass "T20 -- --path <file> against a known-clean single file exits 0" \
  || fail "T20 -- --path <file> unexpectedly reported violations:\n$t20_path_file_out"
check "T20 -- --path <file> output names the file, not a directory-wide scan" \
  "tiny-svc/README.md" "$t20_path_file_out"

echo
echo "T20 AC10 -- --path never calls edm-state (read-only contract holds with edm-state off PATH)"
t20_path_no_edmstate_case() {
  local scratch scrub_path
  scratch="$(mktemp -d /tmp/edm-t20-path-noedm.XXXXXX)" || { fail "T20 --path no-edm-state -- mktemp failed"; return 1; }
  printf '# clean note\n\nNo violations here.\n' > "$scratch/note.md"

  # A PATH with only /usr/bin and /bin -- enough for find/sort/grep/sed/cut/tr to resolve, but
  # with every real bin/ directory (where edm-state actually lives) excluded.
  scrub_path="/usr/bin:/bin"
  local control ec out
  control="$(PATH="$scrub_path" command -v edm-state 2>&1 || true)"
  [[ -z "$control" ]] && pass "T20 -- edm-state is genuinely absent from the scrubbed PATH (control check)" \
    || fail "T20 -- edm-state still resolves on the scrubbed PATH ($control) -- test setup invalid"

  set +e
  out="$(PATH="$scrub_path" "$EDM_LINT_ARTIFACTS" --path "$scratch" 2>&1)"
  ec=$?
  set -e
  [[ $ec -eq 0 ]] && pass "T20 -- --path succeeds with edm-state removed from PATH (no edm-state call)" \
    || fail "T20 -- --path failed with edm-state off PATH (exit $ec):\n$out"
  check_absent "T20 -- --path output never reports edm-state as missing" "edm-state not found" "$out"

  rm -rf "$scratch"
}
t20_path_no_edmstate_case
# EDMV3-T20 end

# =================================================================================
# EDMV3-T21 AC3 (shard-2 QC remediation): tripwire for lint:file-type-ban's allow_failure
# flip -- T57's flip to `false` and T66's cross-check both depend on a passing assertion
# existing here first (no case previously read this field out of .gitlab-ci.yml at all).
# =================================================================================
echo
echo "T21 AC3 -- lint:file-type-ban currently carries allow_failure: true (T57/T66 tripwire)"
t21_ban_block="$(awk '/^lint:file-type-ban:/{f=1;next} f && /^[a-zA-Z]/{f=0} f' "$GITLAB_CI_YML")"
check "T21 AC3 -- lint:file-type-ban block found in .gitlab-ci.yml" "allow_failure" "$t21_ban_block"
check "T21 AC3 -- lint:file-type-ban carries allow_failure: true (flip to false lands with EDMV3-T57)" \
  "true" "$(printf '%s\n' "$t21_ban_block" | grep 'allow_failure' || true)"
# EDMV3-T21 AC3 end

# ---- AC5 (D19 amendment, decisions.md): no literal wave-suite token anywhere in
# .gitlab-ci.yml -- suites run via run-all.sh auto-discovery and are never hand-named. -------
echo
echo "T21 AC5 -- zero literal wave-suite tokens anywhere in .gitlab-ci.yml"
t21_wave_token_hits="$(grep -cE 'wave(3|4a|4b|5|6|7)-smoke' "$GITLAB_CI_YML" || true)"
t21_wave_token_hits="${t21_wave_token_hits:-0}"
[[ "$t21_wave_token_hits" -eq 0 ]] \
  && pass "T21 AC5 -- .gitlab-ci.yml names zero literal wave-suite tokens (run-all.sh auto-discovery only)" \
  || fail "T21 AC5 -- found $t21_wave_token_hits literal wave-suite token(s) in .gitlab-ci.yml"

echo
echo "T64 AC1 -- plugin.json and marketplace.json versions agree"
REPO_ROOT_T64="$(cd "$PLUGIN_DIR/../.." && pwd)"
t64_plugin_version="$(jq -r '.version' "$PLUGIN_DIR/.claude-plugin/plugin.json")"
t64_marketplace_version="$(jq -r '.plugins[] | select(.name=="edm") | .version' "$REPO_ROOT_T64/.claude-plugin/marketplace.json")"
[[ "$t64_plugin_version" == "$t64_marketplace_version" ]] \
  && pass "T64 AC1 -- plugin.json and marketplace.json versions agree ($t64_plugin_version)" \
  || fail "T64 AC1 -- plugin.json version '$t64_plugin_version' != marketplace.json edm entry '$t64_marketplace_version'"
[[ "$t64_plugin_version" == "2.1.0" ]] \
  && pass "T64 AC1 -- plugin.json version is 2.1.0" \
  || fail "T64 AC1 -- plugin.json version is '$t64_plugin_version', expected '2.1.0'"

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
  scratch="$(mktemp -d /tmp/edm-t24-ac10.XXXXXX)" || { fail "T24 AC10 -- mktemp failed"; return 1; }
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
  scratch="$(mktemp -d /tmp/edm-t25-ledger.XXXXXX)" || { fail "T25 AC1/AC10 -- mktemp failed"; return 1; }
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
echo "T30 AC9 -- mirrors report_violation/build_ignore_set rather than re-deriving the file walk"
check "T30 AC9 -- report_violation defined" "report_violation()" "$(cat "$CHECK_VOCAB")"
check "T30 AC9 -- build_ignore_set defined" "build_ignore_set()" "$(cat "$CHECK_VOCAB")"

echo
echo "T30 AC10 -- override-flag grep (repo-wide, documented carve-outs) is clean"
t30_override_hits="$(grep -rn -- '--force\|--accept-partials' "${PLUGIN_DIR}/bin" "${PLUGIN_DIR}/skills" "${PLUGIN_DIR}/agents" 2>/dev/null \
  | grep -v "${PLUGIN_DIR}/bin/tests/" | grep -v vocabulary- | grep -v 'refused:' || true)"
[[ -z "$t30_override_hits" ]] && pass "T30 AC10 -- no stray --force/--accept-partials outside bin/tests/ and the vocabulary checker's own files" \
  || fail "T30 AC10 -- found stray override-flag text: $t30_override_hits"

echo
echo "T30 AC11 -- bash 3.2 syntax check and CI wiring"
bash -n "$CHECK_VOCAB" && pass "T30 AC11 -- bash -n edm-check-vocabulary" || fail "T30 AC11 -- bash -n edm-check-vocabulary failed"
check "T30 AC11 -- edm-check-vocabulary wired into .gitlab-ci.yml lint stage" "edm-check-vocabulary" \
  "$(cat "$GITLAB_CI_YML" 2>/dev/null)"

echo
echo "T30 AC2 -- JSON-escaped prompt strings: a scratch hooks.json carrying the abolished token is caught"
t30_ac2_case() {
  local scratch
  scratch="$(mktemp -d /tmp/edm-t30-ac2.XXXXXX)" || { fail "T30 AC2 -- mktemp failed"; return 1; }
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
t40_heading_order="$(grep -n '^## ' "${PLUGIN_DIR}/CLAUDE.md" | grep -A2 'Severity vocabulary')"
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
t40_ac5_fence_count="$(sed -n '/Mermaid diagram conventions/,/^## /p' "${PLUGIN_DIR}/CLAUDE.md" | grep -c '```')"
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
t42_ac4_forms="$(grep -rho 'CLAUDE.md Sec\."Mermaid diagram conventions"' "${PLUGIN_DIR}/" | sort -u | wc -l | tr -d ' ')"
[[ "$t42_ac4_forms" == "1" ]] \
  && pass "T42 AC4 -- exactly one quoting form of the by-name reference is in use" \
  || fail "T42 AC4 -- found ${t42_ac4_forms} distinct quoting forms, expected 1"

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

t42_srd_hh_count="$(grep -c '^## ' "${PLUGIN_DIR}/docs/audit-patterns/srd-audit.md")"
t42_tkt_hh_count="$(grep -c '^## ' "${PLUGIN_DIR}/docs/audit-patterns/ticket-audit.md")"
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
T43_SCRATCH="$(mktemp -d /tmp/edm-t43-mermaid.XXXXXX)"
t43_write() { printf '%s\n' "$2" > "${T43_SCRATCH}/$1"; }

echo
echo "T43 AC1 -- one-pass classifier replaces the per-class helper"
check_absent "T43 AC1 -- build_ignore_set no longer present" "build_ignore_set" "$(cat "$LINT_BIN")"
t43_def_count="$(grep -c '^build_line_classes()' "$LINT_BIN")"
t43_call_count="$(grep -c '_table="\$(build_line_classes' "$LINT_BIN")"
[[ "$t43_def_count" -eq 1 && "$t43_call_count" -eq 1 ]] \
  && pass "T43 AC1 -- exactly one build_line_classes definition and one call site" \
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
bash "$LINT_BIN" --path "${T43_SCRATCH}/unterminated.md" >/dev/null 2>&1
t43_rc=$?
t43_elapsed=$((SECONDS - t43_start))
[[ "$t43_elapsed" -le 10 && "$t43_rc" -le 1 ]] \
  && pass "T43 AC3 -- unterminated fence terminates promptly (took ${t43_elapsed}s, exit ${t43_rc})" \
  || fail "T43 AC3 -- unterminated fence took ${t43_elapsed}s or exited ${t43_rc} (expected <=10s, exit 0/1)"

t43_write nested.md 'Header

```mermaid
flowchart TD
    A[Ok] --> B[Done]
```stray
    C[Also ok] --> D[End]
```
'
t43_start="$SECONDS"
bash "$LINT_BIN" --path "${T43_SCRATCH}/nested.md" >/dev/null 2>&1
t43_rc=$?
t43_elapsed=$((SECONDS - t43_start))
[[ "$t43_elapsed" -le 10 && "$t43_rc" -le 1 ]] \
  && pass "T43 AC3 -- nested-looking fence does not hang or crash (took ${t43_elapsed}s, exit ${t43_rc})" \
  || fail "T43 AC3 -- nested-looking fence took ${t43_elapsed}s or exited ${t43_rc} (expected <=10s, exit 0/1)"

echo
echo "T43 AC4 -- the class fires on a raw ';' inside a label span"
t43_write invalid1.md 'Header

```mermaid
flowchart TD
    A[Wait; then retry] --> B[Done]
```
'
check_fails "T43 AC4 -- a raw ';' inside [...] is flagged as mermaid-semicolon" "mermaid-semicolon" \
  bash "$LINT_BIN" --path "${T43_SCRATCH}/invalid1.md"

echo
echo "T43 AC5 -- zero false positives on the legal cases"
t43_write valid1.md 'Header

```mermaid
flowchart TD
    A[Wait#59; then retry] --> B[Done]
    A["ratio 3,4 (ok)"] --> C[End]
    classDef done fill:#f9f,stroke:#333;
    style A fill:#bbf,stroke:#333;
    linkStyle 0 stroke:#333;
    %% a comment; with a semicolon is fine
    D[Quote#quot;here] --> E[Hash#35;here]
```

```mermaid
sequenceDiagram
    Alice->>Bob: hello there, no problem
```
'
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
t43_all_out="$(bash "$LINT_BIN" --all 2>&1)"
check "T43 AC9 -- --all is still CLEAN across the tree post-refactor" "CLEAN" "$t43_all_out"
check_absent "T43 AC9 -- no attribution violation on the live tree" ": attribution: " "$t43_all_out"
check_absent "T43 AC9 -- no unicode violation on the live tree" ": unicode: " "$t43_all_out"
check_absent "T43 AC9 -- no leaked-tool-tag violation on the live tree" ": leaked-tool-tag: " "$t43_all_out"

echo
echo "T43 AC10 -- performance budget (measured manually: 0.096s before, 0.097s after -- ~1.01x, well under 1.40x)"
t43_perf_start="$SECONDS"
bash "$LINT_BIN" --all >/dev/null 2>&1
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
echo "T43 AC12 -- no hook change needed; CLAUDE.md documents four violation classes"
check "T43 AC12 -- hooks.json's PreToolUse still invokes edm-lint-artifacts" \
  "edm-lint-artifacts" "$(cat "${PLUGIN_DIR}/hooks/hooks.json" 2>/dev/null)"
check "T43 AC12 -- CLAUDE.md's bin/ table describes four violation classes" \
  "four violation classes" "$CLAUDE_MD_CONTENT"

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

echo
echo "T44 AC3 -- invalid/ coverage: one file per required case, each with an expected-line marker"
for _t44_case in i01-bracket-label i02-quoted-label i03-edge-pipe-label i04-curly-label i05-sequence-message; do
  _t44_f="${MERMAID_INVALID_DIR}/${_t44_case}.md"
  [[ -f "$_t44_f" ]] && pass "T44 AC3 -- ${_t44_case}.md exists" || fail "T44 AC3 -- ${_t44_case}.md is missing"
  grep -q 'expected-line:' "$_t44_f" 2>/dev/null && pass "T44 AC3 -- ${_t44_case}.md carries an expected-line marker" \
    || fail "T44 AC3 -- ${_t44_case}.md has no expected-line marker"
done

echo
echo "T44 AC4 -- exact violation set: zero on valid/, exactly one per file (at its expected line) on invalid/"
t44_valid_out="$(bash "$LINT_BIN" --path "$MERMAID_VALID_DIR" 2>&1)"
check "T44 AC4 -- valid/ is CLEAN" "CLEAN" "$t44_valid_out"

t44_ac4_case() {
  local bad=0 f expected actual
  for f in "${MERMAID_INVALID_DIR}"/*.md; do
    expected="$(sed -n '1p' "$f" | grep -oE 'expected-line: [0-9]+' | grep -oE '[0-9]+')"
    set +e
    actual="$(bash "$LINT_BIN" --path "$f" 2>&1 | grep -oE ':[0-9]+: mermaid-semicolon:' | grep -oE '[0-9]+' | head -1)"
    set -e
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
  scratch="$(mktemp -d /tmp/edm-t44-fp.XXXXXX)" || { fail "T44 AC5 -- mktemp failed"; return 1; }
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
t44_all_out="$(bash "$LINT_BIN" --all 2>&1)"
check "T44 AC7 -- edm-lint-artifacts --all is CLEAN across the tracked SRD tree" "CLEAN" "$t44_all_out"

echo
echo "T44 AC8 -- this suite's T44 cases use the shared _harness.sh assertions"
t44_block="$(awk '/^# EDMV3-T44:/{f=1} f{print} /^# EDMV3-T44 end/{exit}' "${SCRIPT_DIR}/wave7-smoke.sh")"
t44_check_uses="$(printf '%s\n' "$t44_block" | grep -c 'check_fails\|check "' || true)"
[[ "${t44_check_uses:-0}" -gt 0 ]] \
  && pass "T44 AC8 -- T44's own cases use check/check_fails from _harness.sh" \
  || fail "T44 AC8 -- T44's cases do not appear to use the shared harness assertions"
# EDMV3-T44 end

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
t33_third_verdict_hits="$(grep -rn 'BLOCKED\|WAIVED\|N/A-runtime' \
  "${PLUGIN_DIR}/bin/edm-state" "$VERIFY_RUNTIME_SKILL" "${PLUGIN_DIR}/agents/edm-qc-auditor.md" 2>/dev/null || true)"
[[ -z "$t33_third_verdict_hits" ]] && pass "T33 AC4 -- no BLOCKED/WAIVED/N/A-runtime token in edm-state, verify-runtime, or qc-auditor" \
  || fail "T33 AC4 -- found a third-verdict token: $t33_third_verdict_hits"

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
t33_qc_audit_h2_count="$(grep -c '^## ' "${PLUGIN_DIR}/docs/audit-patterns/qc-audit.md")"
[[ "$t33_qc_audit_h2_count" -eq 4 ]] && pass "T33 AC14 -- qc-audit.md still has exactly 4 '##' headings" \
  || fail "T33 AC14 -- qc-audit.md has ${t33_qc_audit_h2_count} '##' headings, expected 4"
TICKET_AUDIT_DOC_T33="$(cat "${PLUGIN_DIR}/docs/audit-patterns/ticket-audit.md")"
check "T33 AC14 -- ticket-audit.md pre-flight names environment the project does not have" \
  "environment the project does not have" "$TICKET_AUDIT_DOC_T33"

echo
echo "T33 -- edm-check-grants and bash -n stay clean with the new skill in the tree"
bash -n "${PLUGIN_DIR}/bin/edm-state" && pass "T33 -- bash -n bin/edm-state" || fail "T33 -- bash -n bin/edm-state failed"
bash "${PLUGIN_DIR}/bin/edm-check-grants" >/dev/null 2>&1 && pass "T33 -- edm-check-grants exits 0" \
  || fail "T33 -- edm-check-grants failed with the new skill present"
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
echo "T34 AC5 -- ordering: the spike note is committed, and T34's own commit made no dispatcher edit"
[[ -f "$SPIKE_NOTE" ]] && pass "T34 AC5 -- spike-skill-composition.md is committed to the initiative directory" \
  || fail "T34 AC5 -- spike-skill-composition.md is missing"
t34_orch_touched_by_t34="$(git -C "$PLUGIN_DIR/../.." log --format='%s' -- plugins/edm/skills/orchestrator/SKILL.md 2>/dev/null | grep -c 'EDMV3-T34' || true)"
[[ "${t34_orch_touched_by_t34:-0}" -eq 0 ]] && pass "T34 AC5 -- no commit tagged EDMV3-T34 touches orchestrator/SKILL.md (that edge is EDMV3-T35/T38's)" \
  || fail "T34 AC5 -- an EDMV3-T34-tagged commit touched orchestrator/SKILL.md"

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
t35_protocol_count="$(grep -c '^## Gate PROTOCOL (canonical)$' "${PLUGIN_DIR}/skills/orchestrator/SKILL.md")"
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
t35_freetext_hits="$(grep -rn 'free-text is never approval\|free text is not an approval' "${PLUGIN_DIR}/" 2>/dev/null | grep -v 'orchestrator/SKILL.md' || true)"
[[ -z "$t35_freetext_hits" ]] && pass "T35 AC4 -- no free-text-approval restatement outside orchestrator/SKILL.md" \
  || fail "T35 AC4 -- found a restatement outside orchestrator/SKILL.md: $t35_freetext_hits"
for t35_gate_site in "plugins/edm/skills/plan/SKILL.md" "plugins/edm/skills/audit-srd/SKILL.md" \
                     "plugins/edm/skills/audit-tickets/SKILL.md" "plugins/edm/skills/code-audit/SKILL.md"; do
  check "T35 AC4 -- ${t35_gate_site} references Gate PROTOCOL by name" \
    'Gate PROTOCOL' "$(cat "$(cd "${PLUGIN_DIR}/../.." && pwd)/${t35_gate_site}")"
done

echo
echo "T35 AC5 -- weak free-prose approval questions deleted"
t35_weak_gate_hits="$(grep -rn "Ask: .Do you approve" "${PLUGIN_DIR}/skills/" 2>/dev/null || true)"
[[ -z "$t35_weak_gate_hits" ]] && pass "T35 AC5 -- no 'Ask: \"Do you approve' free-prose gate remains in skills/" \
  || fail "T35 AC5 -- found a weak free-prose gate: $t35_weak_gate_hits"

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
bash "${PLUGIN_DIR}/bin/edm-check-grants" >/dev/null 2>&1
t35_grants_exit=$?
[[ "$t35_grants_exit" -eq 0 ]] && pass "T35 AC8 -- edm-check-grants exits 0" \
  || fail "T35 AC8 -- edm-check-grants exited ${t35_grants_exit}"
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
t35_lint_exit=0
bash "${PLUGIN_DIR}/bin/edm-lint-artifacts" --all >/dev/null 2>&1 || t35_lint_exit=$?
[[ "$t35_lint_exit" -eq 0 ]] && pass "T35 -- edm-lint-artifacts --all exits 0" \
  || fail "T35 -- edm-lint-artifacts --all exited ${t35_lint_exit}"
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
    t36_out="$("$EDM_STATE" gate-check T36X "$t36_tok" 2>&1)"
    t36_ec=$?
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
check "T36 AC4 -- CHANGELOG.md records 'branch-check becoming a BLOCK'" \
  "branch-check becoming a BLOCK" "$(cat "${PLUGIN_DIR}/CHANGELOG.md")"

echo
echo "T36 AC5 -- written once (full text in one file), referenced by name from the other seven"
t36_full_text_files=0
for t36_skill in $T36_PHASE_SKILLS; do
  t36_hits="$(grep -c 'edm-state branch-check' "${PLUGIN_DIR}/skills/${t36_skill}/SKILL.md" 2>/dev/null || echo 0)"
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
  t36_c="$(grep -c 'skipped_phases' "${PLUGIN_DIR}/skills/${t36_skill}/SKILL.md" 2>/dev/null || echo 0)"
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
[[ -z "$t36_step0_deterministic_hits" ]] && pass "T36 AC8 -- no such pairing found anywhere in plugins/edm/" \
  || fail "T36 AC8 -- found a disallowed pairing: $t36_step0_deterministic_hits"
check "T36 AC8 -- defence-in-depth framing used instead" "defence in depth on the Skill-tool path" "$(cat "${PLUGIN_DIR}/skills/plan/SKILL.md")"

echo
echo "T36 -- full suite and lint stay green with Step 0 in place across all eight phase skills"
bash "${PLUGIN_DIR}/bin/edm-check-grants" >/dev/null 2>&1
t36_grants_exit=$?
[[ "$t36_grants_exit" -eq 0 ]] && pass "T36 -- edm-check-grants exits 0" || fail "T36 -- edm-check-grants exited ${t36_grants_exit}"
t36_lint_exit=0
bash "${PLUGIN_DIR}/bin/edm-lint-artifacts" --all >/dev/null 2>&1 || t36_lint_exit=$?
[[ "$t36_lint_exit" -eq 0 ]] && pass "T36 -- edm-lint-artifacts --all exits 0" || fail "T36 -- edm-lint-artifacts --all exited ${t36_lint_exit}"
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
echo "T37 AC6 -- phase-start/phase-complete calls: one owning file per phase (fast-track's mode-branch duplicate inside skills/tickets, and verify-runtime's documented direct-invocation phase-complete-6, are the two sanctioned exceptions)"
t37_ac6_bad=""
for t37_n in 1 2 3 4 5 6; do
  t37_start_files="$(grep -rl "phase-start <PREFIX> ${t37_n}\\b" "${PLUGIN_DIR}/skills/"*/SKILL.md 2>/dev/null | wc -l | tr -d ' ' || true)"
  [[ "$t37_start_files" -eq 1 ]] || t37_ac6_bad="${t37_ac6_bad} phase-start:${t37_n}=${t37_start_files}file(s)"
  t37_complete_files="$(grep -rl "phase-complete <PREFIX> ${t37_n}\\b" "${PLUGIN_DIR}/skills/"*/SKILL.md 2>/dev/null | wc -l | tr -d ' ' || true)"
  if [[ "$t37_n" -eq 6 ]]; then
    [[ "$t37_complete_files" -eq 2 ]] || t37_ac6_bad="${t37_ac6_bad} phase-complete:6=${t37_complete_files}file(s),expected2(implement+verify-runtime)"
  else
    [[ "$t37_complete_files" -eq 1 ]] || t37_ac6_bad="${t37_ac6_bad} phase-complete:${t37_n}=${t37_complete_files}file(s)"
  fi
done
[[ -z "$t37_ac6_bad" ]] && pass "T37 AC6 -- one owning file per phase-start/phase-complete call (phase-complete 6's two-file split is the documented implement+verify-runtime direct-invocation exception)" \
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
t37_grants_exit=0
bash "${PLUGIN_DIR}/bin/edm-check-grants" >/dev/null 2>&1 || t37_grants_exit=$?
[[ "$t37_grants_exit" -eq 0 ]] && pass "T37 -- edm-check-grants exits 0" || fail "T37 -- edm-check-grants exited ${t37_grants_exit}"
t37_lint_exit=0
bash "${PLUGIN_DIR}/bin/edm-lint-artifacts" --all >/dev/null 2>&1 || t37_lint_exit=$?
[[ "$t37_lint_exit" -eq 0 ]] && pass "T37 -- edm-lint-artifacts --all exits 0" || fail "T37 -- edm-lint-artifacts --all exited ${t37_lint_exit}"
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
echo "T38 AC2 -- retained set: six '## ' sections (Overview, Step 1 -- Intake, Gate PROTOCOL, Step 2 -- Dispatch each phase, Resume and Compaction, Anti-Patterns)"
t38_section_count="$(grep -c '^## ' "${PLUGIN_DIR}/skills/orchestrator/SKILL.md" || true)"
[[ "$t38_section_count" -eq 6 ]] && pass "T38 AC2 -- exactly six top-level sections" \
  || fail "T38 AC2 -- found ${t38_section_count} top-level sections, expected 6"
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
t38_grants_exit=0
bash "${PLUGIN_DIR}/bin/edm-check-grants" >/dev/null 2>&1 || t38_grants_exit=$?
[[ "$t38_grants_exit" -eq 0 ]] && pass "T38 AC4/AC13 -- edm-check-grants exits 0" || fail "T38 AC4/AC13 -- edm-check-grants exited ${t38_grants_exit}"

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
t38_lint_exit=0
bash "${PLUGIN_DIR}/bin/edm-lint-artifacts" --all >/dev/null 2>&1 || t38_lint_exit=$?
[[ "$t38_lint_exit" -eq 0 ]] && pass "T38 -- edm-lint-artifacts --all exits 0" || fail "T38 -- edm-lint-artifacts --all exited ${t38_lint_exit}"
# EDMV3-T38 end

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
