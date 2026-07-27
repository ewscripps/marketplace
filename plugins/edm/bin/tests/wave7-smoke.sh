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
check "free-text-is-never-approval restated at the convergence gate" \
  "never** treated as approval" "$CA_CONTENT"

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
echo "T15 AC5 -- orchestrator Step 8 point 5 invokes the gate protocol by name, not a restatement"
T15_STEP8="$(awk '/^### Step 8 --/{f=1} /^### Step 9 --/{f=0} f' "$ORCH_SKILL")"
check "Step 8 names the Convergence gate by reference to /edm:code-audit Step 10" \
  "/edm:code-audit\` Step 10 presents the Convergence" "$T15_STEP8"
check_absent "Step 8 does not restate the gate's own STOP-and-WAIT protocol locally" \
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
echo "T15 AC8 -- Step 9 checklist names the Convergence gate; Post-Remediation Closure note preserved"
T15_STEP9="$(awk '/^### Step 9 --/{f=1} /^## Phase Timing/{f=0} f' "$ORCH_SKILL")"
check "Step 9 checklist names the Convergence gate" "Convergence gate" "$T15_STEP9"
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

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
