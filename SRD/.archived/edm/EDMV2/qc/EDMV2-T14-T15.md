# QC Notes: EDMV2-T14 and EDMV2-T15

Verified: 2026-06-08
Plugin version: staging (plugins/edm-ai-development-staging/)
Worktree: .claude/worktrees/agent-a435cafd6eeebf8c9

---

## EDMV2-T15: Code-audit phase gating in .edm-state.json

### Changes made

`plugins/edm-ai-development-staging/bin/edm-state`

**1. `cmd_init` -- added `code_audit_converged: false` to initial JSON (line ~229)**

Before:
```json
{
  "coverage_by_layer": {},
  "last_updated": $t
}
```

After:
```json
{
  "coverage_by_layer": {},
  "code_audit_converged": false,
  "last_updated": $t
}
```

**2. `cmd_archive` -- added gating logic before the mv (lines 489-520)**

New gating block reads three fields from `${SRD_ROOT}/${prefix}/.edm-state.json` via `jq`:
- `mode` -- used to detect prototype exemption
- `code_audit_converged` -- uses `has()` to distinguish absent (legacy) from false (v2 unconverged)
- `product_name` -- non-empty value distinguishes v2 initiatives from flat/legacy ones

Logic branches:
1. `mode == "prototype"` -- warn to stderr and proceed
2. `code_audit_converged` field absent -- warn to stderr and proceed (legacy v1 behavior preserved)
3. `code_audit_converged == false` AND `product_name` non-empty -- `die` with actionable message (non-zero exit)
4. `code_audit_converged == true` -- no message, proceed silently
5. No state file present -- skip gating entirely (flat/legacy initiative)

### AC verification

- AC-1: PASS -- `cmd_init` emits `"code_audit_converged": false` (JSON boolean) into new state files.
  `jq 'if has("code_audit_converged") then .code_audit_converged | tostring else "absent" end'`
  returns `"false"` for newly initialized files.

- AC-2: PASS -- When `code_audit_converged=false` and `product_name` is non-empty, `cmd_archive` calls
  `die "archive refused: code_audit_converged=false; run /edm:code-audit ${prefix} and ensure REMEDIATION.md convergence before archiving"`.
  `die` calls `exit 1` via `echo ... >&2; exit 1`. Non-zero exit guaranteed.

- AC-3: PASS -- When state file exists but `code_audit_converged` field is absent (jq `has()` returns
  false), the script emits `"[warn] legacy initiative -- code_audit_converged not set; proceeding"` to
  stderr and continues to the `mv`.

- AC-4: PASS -- When `mode` field is `"prototype"`, the script emits
  `"[warn] prototype mode -- skipping code-audit convergence check"` to stderr and continues,
  regardless of `code_audit_converged` value.

- AC-5: PASS -- When `code_audit_converged` is `true` (boolean) or `"true"` (string from `cmd_set`),
  `jq '... | tostring'` returns `"true"`, none of the three branches match, and the function proceeds
  without any output.

- AC-6: PASS -- All three fields are read via `jq -r` in the new block. `mode` uses `// "null"` fallback.
  `code_audit_converged` uses `has()` to distinguish absent from false. `product_name` uses `// ""` fallback.
  The `jq` `has()` approach treats a missing field as absent (not as false), satisfying the spec.

- AC-7: PASS -- `cmd_init` JSON template at line ~219 now includes `"code_audit_converged": false` between
  `coverage_by_layer` and `last_updated`. Verified by reading the file and confirming the field.

- AC-8: PASS -- The gating block is wrapped in `if [[ -f "$state_file" ]]; then ... fi`, so when no state
  file exists (flat/legacy initiative with no `.edm-state.json`) the entire check is skipped and archive
  proceeds exactly as before. For legacy initiatives that do have a state file but no `code_audit_converged`
  field, a warning is printed and the archive proceeds -- consistent with pre-T15 behavior.

---

## EDMV2-T14: Make the 11-lens code audit a mandatory orchestrated phase

### Change made

`plugins/edm-ai-development-staging/skills/orchestrator/SKILL.md`, lines 271-280:

**Before (Step 8 -- Verify completion):**
```
### Step 8 -- Verify completion

- [ ] All tickets have a PASS verdict
- [ ] All P0 QC findings resolved
- [ ] Code compiles, existing tests pass
- [ ] `/edm:test {PREFIX}` run and all coverage targets met (or consciously skipped)
- [ ] Documentation updated
- [ ] Committed on feature branch
- Optional: invoke `/edm:code-audit` for the 11-lens exhaustive code audit before merging.
- Run `edm-state archive <PREFIX>` after the initiative ships.
```

**After (Step 8 -- Code Audit + Step 9 -- Verify completion):**

Step 8 is now a mandatory driven phase that instructs the orchestrator to:
1. Spawn all 11 `edm-audit-*` lens agents in parallel
2. Spawn `edm-audit-synthesizer` after lenses complete
3. Remediate all P0 and P1 findings
4. Run a second pass if remediation introduces new P0/P1 findings
5. Record convergence via `edm-state set {PREFIX} code_audit_converged true`

Step 8 also documents the prototype exemption explicitly.

Step 9 is the renamed completion checklist, with `code_audit_converged` check added as a required item,
and a note that `edm-state archive` is blocked by `code_audit_converged=false` for non-prototype v2 initiatives.

### AC verification

- AC-1: PASS -- `grep -n "Optional" skills/orchestrator/SKILL.md` returns no output. The word "Optional"
  no longer appears anywhere in the orchestrator skill.

- AC-2: PASS -- Step 8 is titled "Code Audit (mandatory for standard and tdd modes)" and instructs
  spawning all 11 lens agents in parallel followed by `edm-audit-synthesizer`. This is a driven phase,
  not an optional suggestion.

- AC-3: PASS -- Step 8 item 5 requires recording convergence (`edm-state set {PREFIX} code_audit_converged true`)
  as the final action of the audit phase. The phase only completes when REMEDIATION.md shows no new P0/P1 findings.

- AC-4: PASS -- Step 9 includes the checklist item:
  `[ ] Code audit converged: edm-state get {PREFIX} code_audit_converged shows true (or mode is prototype)`
  This directly references the state flag introduced by T15.

- AC-5: PASS -- Step 9 archive instruction reads:
  "Run `edm-state archive <PREFIX>` after the initiative ships (blocked by code_audit_converged=false for non-prototype v2 initiatives)."
  Orchestrator instructs that archive must not run until convergence.

- AC-6: PASS -- Step 8 includes:
  "**Exemption**: `prototype` mode initiatives may skip code-audit convergence -- `edm-state archive` proceeds with a warning."

- AC-7: PASS -- Phase ordering in the orchestrator:
  - Step 7: Phase 6 Implementation + QC
  - Step 7b: Comprehensive Testing (recommended)
  - Step 8: Code Audit (mandatory) -- new, after QC
  - Step 9: Verify completion + archive
  Code audit follows Phase 6 QC and precedes archive.

- AC-8: PASS -- `claude plugin validate plugins/edm-ai-development-staging/` output:
  "1 warning: root: CLAUDE.md at the plugin root is not loaded as project context..."
  "Validation passed with warnings" -- this warning is pre-existing and unrelated to T14/T15 changes.
  No new errors introduced.
