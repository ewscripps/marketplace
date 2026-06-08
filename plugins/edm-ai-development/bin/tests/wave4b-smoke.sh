#!/usr/bin/env bash
# Wave 4b smoke tests — skill/agent/config text changes
# Tickets: T61, T64, T65, T66, T67, T74, T82, T84, T85, T86, T88, T89, T90, T91, T92, T93, T94
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

check() {
  local label="$1" pattern="$2" content="$3"
  if echo "$content" | grep -qF "$pattern"; then
    echo "  PASS: $label"
    PASS=$((PASS+1))
  else
    echo "  FAIL: $label (expected: $pattern)"
    FAIL=$((FAIL+1))
  fi
}

check_absent() {
  local label="$1" pattern="$2" content="$3"
  if ! echo "$content" | grep -qF "$pattern"; then
    echo "  PASS: $label"
    PASS=$((PASS+1))
  else
    echo "  FAIL: $label (must not contain: $pattern)"
    FAIL=$((FAIL+1))
  fi
}

echo "=== Wave 4b Smoke Tests ==="
echo ""

# ---- T61: Version-drift detection -------------------------------------------
echo "--- T61: Version-drift detection ---"
AUDIT_SRD="$(cat "$PLUGIN_DIR/skills/audit-srd/SKILL.md")"
check "audit-srd version-drift step" "Version-drift check" "$AUDIT_SRD"
check "audit-srd reads srd_version from state" "jq -r '.srd_version" "$AUDIT_SRD"
check "audit-srd syncs version before spawning auditors" "Spawn 2-3" "$AUDIT_SRD"

AUDIT_TICKETS="$(cat "$PLUGIN_DIR/skills/audit-tickets/SKILL.md")"
check "audit-tickets version-drift step" "Version-drift check" "$AUDIT_TICKETS"
check "audit-tickets P0 finding on drift" "P0" "$AUDIT_TICKETS"
check "audit-tickets reads srd_version" "jq -r '.srd_version" "$AUDIT_TICKETS"
check "audit-tickets VERSION-DRIFT finding format" "VERSION-DRIFT" "$AUDIT_TICKETS"
echo ""

# ---- T64/T65/T66/T67: implement skill QC sharding ---------------------------
echo "--- T64/T65/T66/T67: implement skill QC sharding and PARTIAL semantics ---"
IMPLEMENT="$(cat "$PLUGIN_DIR/skills/implement/SKILL.md")"
check "QC output canonical path" "<initiative-dir>/qc/" "$IMPLEMENT"
check "qc-summary.md path" "qc/qc-summary.md" "$IMPLEMENT"
check "qc-shard path" "qc-shard-{NN}.md" "$IMPLEMENT"
check "qc_shard_threshold reference" "qc_shard_threshold" "$IMPLEMENT"
check "PARTIAL verdict semantics" "cannot be verified statically" "$IMPLEMENT"
check "deferred-to-runtime" "deferred-to-runtime" "$IMPLEMENT"
check "record-partial-verdict call" "record-partial-verdict" "$IMPLEMENT"
check "PARTIAL does not require remediation" "do not require remediation" "$IMPLEMENT"
check "QC report format has Shard header" "Shard {N}/{M} | Single" "$IMPLEMENT"
check "QC report deferred-to-runtime note" "deferred-to-runtime: call the endpoint" "$IMPLEMENT"
echo ""

# ---- T74: edm-architect output to architecture.md ---------------------------
echo "--- T74: edm-architect canonical architecture.md output ---"
ARCH="$(cat "$PLUGIN_DIR/agents/edm-architect.md")"
check "architect writes to architecture.md" "architecture.md" "$ARCH"
check "architect description updated" "state-derived initiative directory" "$ARCH"
check "architect output format section" "Output Format" "$ARCH"
check "architect rejected alternatives" "Rejected Alternatives" "$ARCH"
check_absent "arch-section5 reference absent" "arch-section5" "$ARCH"
check_absent "architect does not say paste into SRD" "ready to paste in directly" "$ARCH"
echo ""

# ---- T82/T85: CLAUDE.md artifact layout and mode schema ----------------------
echo "--- T82/T85: CLAUDE.md WS-D layout and mode schema ---"
CLAUDE_MD="$(cat "$PLUGIN_DIR/CLAUDE.md")"
check "architecture.md in layout" "architecture.md" "$CLAUDE_MD"
check "explorers/ in layout" "explorers/" "$CLAUDE_MD"
check "decisions.md in layout" "decisions.md" "$CLAUDE_MD"
check "ROLLBACK.md in layout" "ROLLBACK.md" "$CLAUDE_MD"
check "exec-report.md in layout" "exec-report.md" "$CLAUDE_MD"
check "post-deploy/ in layout" "post-deploy/" "$CLAUDE_MD"
check "qc/ in layout" "qc/" "$CLAUDE_MD"
check "findings-ledger.md in layout" "findings-ledger.md" "$CLAUDE_MD"
check "pass-{N}_ in layout" "pass-{N}_{YYYY-MM-DD}/" "$CLAUDE_MD"
check "mode field in schema table" "Adaptation profile:" "$CLAUDE_MD"
check "lifecycle_mode in schema table" "Lifecycle variant:" "$CLAUDE_MD"
check "compliance_enabled in schema table" "Gate 3.5" "$CLAUDE_MD"
check "implementation_mode in schema table" "tdd" "$CLAUDE_MD"
check "skipped_phases in schema table" "skipped_phases" "$CLAUDE_MD"
check "supersedes in schema table" "supersedes" "$CLAUDE_MD"
check "decisions vs findings-ledger distinction" "code-audit/findings-ledger.md" "$CLAUDE_MD"
check "set-mode in bin table" "set-mode" "$CLAUDE_MD"
check "audit-round-start in bin table" "audit-round-start" "$CLAUDE_MD"
echo ""

# ---- T84: orchestrator mode selection Step 1c --------------------------------
echo "--- T84: orchestrator mode selection ---"
ORCH="$(cat "$PLUGIN_DIR/skills/orchestrator/SKILL.md")"
check "Step 1c exists" "Step 1c" "$ORCH"
check "mode selection AskUserQuestion" "AskUserQuestion" "$ORCH"
check "EDM mode header" "EDM mode" "$ORCH"
check "mini-SRD option" "mini-SRD" "$ORCH"
check "IaC option" "IaC" "$ORCH"
check "Data/ML option" "Data/ML" "$ORCH"
check "Prototype option" "Prototype" "$ORCH"
check "compliance toggle" "compliance toggle" "$ORCH"
check "set-mode records choice" "set-mode" "$ORCH"
check "resume reads mode fields" "mode-family fields" "$ORCH"
check "resume skips Step 1c" "Skip Step 1c" "$ORCH"
echo ""

# ---- T88: mini-SRD sub-flow --------------------------------------------------
echo "--- T88: mini-SRD sub-flow ---"
check "mini-SRD sub-flow section" "mini-SRD Sub-Flow" "$ORCH"
check "mini-SRD fused file" "fused file" "$ORCH"
check "mini-SRD merged gate" "Gate 2+3" "$ORCH"
check "mini-SRD skip-phase 4" "skip-phase <PREFIX> 4" "$ORCH"
check "mini-SRD skip-phase 5" "skip-phase <PREFIX> 5" "$ORCH"
check_absent "mini-SRD does not spawn ticket-writer" "edm-ticket-writer" \
  "$(echo "$ORCH" | awk '/### mini-SRD Sub-Flow/{f=1} f && /^---$/{exit} f{print}')"
echo ""

# ---- T91: Gate 3.5 compliance review -----------------------------------------
echo "--- T91: Gate 3.5 compliance review ---"
check "Gate 3.5 section" "Gate 3.5" "$ORCH"
check "Gate 3.5 compliance_enabled condition" "compliance_enabled=true" "$ORCH"
check "Gate 3.5 header" '"Gate 3.5"' "$ORCH"
check "Gate 3.5 approve-gate" "approve-gate <PREFIX> 3.5" "$ORCH"
echo ""

# ---- T92: prototype sub-flow -------------------------------------------------
echo "--- T92: prototype sub-flow ---"
check "Prototype sub-flow section" "Prototype Sub-Flow" "$ORCH"
check "prototype stop after Phase 2" "Phases 3-6 are skipped" "$ORCH"
check "prototype skip-phase 3" "skip-phase <PREFIX> 3" "$ORCH"
check "prototype skip-phase 6" "skip-phase <PREFIX> 6" "$ORCH"
check "prototype graduation message" "mode standard" "$ORCH"
echo ""

# ---- T93: TDD mode in orchestrator and implementer ---------------------------
echo "--- T93: TDD mode ---"
check "TDD mode prompt at Phase 6" "Impl mode" "$ORCH"
check "TDD option" "TDD" "$ORCH"
check "set-mode implementation_mode" "set-mode <PREFIX> implementation_mode" "$ORCH"

IMPL="$(cat "$PLUGIN_DIR/agents/edm-implementer.md")"
check "TDD branch in implementer" "TDD Mode" "$IMPL"
check "Red-Green-Refactor" "Red-Green-Refactor" "$IMPL"
check "Red state stated in output" "suite is RED" "$IMPL"
check "Green state stated in output" "suite is GREEN" "$IMPL"
check "test before implementation" "Write the failing test" "$IMPL"
check "no test modification after impl" "Never modify a ticket's test file after implementation" "$IMPL"
check "escalate on retrofit" "escalate" "$IMPL"
echo ""

# ---- T94: TDD compliance pass in QC auditor ----------------------------------
echo "--- T94: TDD compliance pass ---"
QC="$(cat "$PLUGIN_DIR/agents/edm-qc-auditor.md")"
check "TDD compliance pass section" "TDD Compliance Pass" "$QC"
check "runs only when tdd" "implementation_mode=tdd" "$QC"
check "ordering check" "Ordering check" "$QC"
check "retrofit check" "Retrofit check" "$QC"
check "TDD-COMPLIANT verdict" "TDD-COMPLIANT" "$QC"
check "TDD-FLAGGED verdict" "TDD-FLAGGED" "$QC"
check "standard mode unchanged" "implementation_mode=standard" "$QC"
echo ""

# ---- T86/T89/T90: SRD skill mode-specific sections --------------------------
echo "--- T86/T89/T90: SRD skill mode-specific sections ---"
SRD_SKILL="$(cat "$PLUGIN_DIR/skills/srd/SKILL.md")"
check "mini-SRD mode section" "mini-SRD mode" "$SRD_SKILL"
check "fused file layout" "Ticket List" "$SRD_SKILL"
check "IaC mode section" "IaC mode" "$SRD_SKILL"
check "resource paths example" "resource paths" "$SRD_SKILL"
check "data-ml mode section" "Data/ML mode" "$SRD_SKILL"
check "Data Requirements section heading" "## Data Requirements" "$SRD_SKILL"
check "data sources subsection" "Data sources" "$SRD_SKILL"
check "architect writes architecture.md in AI pattern" "architecture.md" "$SRD_SKILL"
echo ""

# ---- T89/T91: tickets skill IaC + compliance columns ------------------------
echo "--- T89/T91: tickets skill IaC and compliance ---"
TICKETS="$(cat "$PLUGIN_DIR/skills/tickets/SKILL.md")"
check "reads mode from state" "mode" "$TICKETS"
check "IaC resource paths" "resource paths" "$TICKETS"
check "compliance traceability table" "Regulatory Traceability" "$TICKETS"
check "Regulation | Control | Evidence columns" "Regulation | Control | Evidence" "$TICKETS"
check "empty traceability is P0" "P0" "$TICKETS"
echo ""

echo "=== Summary ==="
echo "PASS: $PASS  FAIL: $FAIL"
if [ "$FAIL" -eq 0 ]; then
  echo "All $PASS checks passed."
  exit 0
else
  echo "$FAIL check(s) failed."
  exit 1
fi
