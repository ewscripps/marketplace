---
name: audit-srd
description: EDM Phase 3 (SRD Audit) -- audit the SRD across 7 categories, remediate all P0/P1 findings, present HITL Gate 2. Invoked explicitly via /edm:audit-srd.
disable-model-invocation: true
model: opus
effort: max
argument-hint: <PREFIX>
allowed-tools: Read, Write, Edit, Bash(edm-state *), Glob, Grep, Task, TodoWrite, AskUserQuestion
---

# EDM Phase 3: SRD Audit

**Arguments**: $ARGUMENTS

- **Input**: SRD at `${user_config.srd_root}/{PREFIX}/${user_config.srd_filename}`
- **Output**: Audit report at `${user_config.srd_root}/{PREFIX}/audit-srd.md` + remediated SRD

Every error caught here saves 10x the effort of catching it during implementation.

## Step 0 -- Gate and Branch Preflight

Before Step 1, run the preflight per `skills/plan/SKILL.md Sec."Step 0 -- Gate and Branch Preflight"`,
using `<gated-command>` = `audit-srd`.

## Operational Orchestration

1. Parse `{PREFIX}` from `$ARGUMENTS`.
2. `edm-state phase-start <PREFIX> 3`
3. **Version-drift check**: Read the SRD's Document Info section (or first Revision History entry) to
   extract the embedded version (e.g., `1.0.0`). Read `srd_version` from state:
   ```bash
   edm-state get <PREFIX> | jq -r '.srd_version // "0.0.0"'
   ```
   If the embedded SRD version differs from the state value, sync state to match the file version
   before proceeding (`edm-state srd-version <PREFIX> <embedded-version>`). A divergence here means
   the SRD was edited out-of-band; note it in the audit report intro.
4. Spawn 2-3 `edm-srd-auditor` agents in parallel -- one per section group (e.g., sections 1-4, 5-7, 8-11). Each agent audits its sections across all 7 categories.
5. Compile findings from all agents into `${user_config.srd_root}/{PREFIX}/audit-srd.md` using the report format below.
6. **Remediate**: fix every P0 and P1 finding directly in the SRD. Update the Revision History (bump SRD version, e.g., 1.0.0 -> 1.1.0).
7. Update `srd_version` in `.edm-state.json`: `edm-state srd-version <PREFIX> 1.1.0`
8. `edm-state phase-complete <PREFIX> 3`
9. Present **HITL Gate 2** (see below, per `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"`) and STOP for sign-off.
10. On approval: `edm-state approve-gate <PREFIX> 2`.

## 7 Audit Categories

### 1. Feature Gaps
Missing requirements, unaddressed edge cases, user flows that dead-end.

### 2. Factual Mistakes
Wrong API names, incorrect library references, impossible claims, version mismatches.

### 3. Diagram Errors
Mermaid syntax errors, logical flow errors, missing edges, orphan nodes.

### 4. Competing Requirements
Conflicts with current codebase, existing features, other specs, internal contradictions.

### 5. Reuse Opportunities
Existing code/libraries that should be leveraged instead of rebuilt.

### 6. Specification Quality
Untestable requirements, missing IDs, missing priorities, internal contradictions.

### 7. Additional Concerns
Licensing, accessibility (WCAG), i18n, backward compatibility, deployment impact.

## Severity Levels

Use the canonical four-level scale from `CLAUDE.md Sec."Severity vocabulary"` — no divergent local scale.

| Severity | Definition | Action |
|---|---|---|
| P0 | Blocks implementation, security/legal issue, architecturally wrong | Must fix before Phase 4 |
| P1 | Significant gap, factual error, missing requirement | Must fix before shipping |
| P2 | Polish, edge case, improvement | Remediated before convergence |
| NOTED | Intentional, pre-existing, or accepted trade-off | Document in Decisions / Non-Findings; do not re-investigate |

## Finding Format

```
[CATEGORY] [SEVERITY] Section X.Y | Specific finding | Recommendation
```

## Audit Report Format

```markdown
# SRD Audit Report: {Initiative Name}

**SRD Version Audited**: {version}
**Audit Date**: {date}

## Summary
- P0 findings: N | P1 findings: N | P2 findings: N
- **Verdict**: PASS / FAIL

## P0 -- Critical (Must Fix Now)
[findings]

## P1 -- Significant (Must Fix Now)
[findings]

## P2 -- Minor (Remediate Before Convergence)
[findings]

## NOTED -- Intentional / Pre-existing
[Items that look like findings but are intentional, pre-existing, or accepted trade-offs — documented once, not re-investigated]

## Remediation
[List of P0/P1 fixes applied to the SRD]
```

## AI Execution Pattern

```
Agent: edm-srd-auditor (launch 2-3 in parallel)
Prompt: "Audit the SRD at ${user_config.srd_root}/{PREFIX}/${user_config.srd_filename} for sections [N-M].
         Also read the codebase files referenced. Check all 7 categories.
         For each finding: [CATEGORY] [SEVERITY] Section X.Y | Finding | Recommendation.
         Be exhaustive. Cross-reference every factual claim against the actual codebase."
```

## HITL Gate 2

After remediating all P0/P1:
1. Summarize: requirement count by priority (Must/Should/Could), key architecture decisions, risks, audit findings resolved (P0: N, P1: N, P2: N).
2. Present the gate per `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"` -- header `"Gate 2"`, options **Approve** / **Revise** / **No-Go**. **STOP and WAIT** for the response.
3. On **Approve** (explicit selection only): `edm-state approve-gate <PREFIX> 2`. Next: `/edm:tickets <PREFIX>`.
   On **Revise**: rework the flagged SRD sections and re-present the gate.
   On **No-Go**: summarize the blockers and stop.
