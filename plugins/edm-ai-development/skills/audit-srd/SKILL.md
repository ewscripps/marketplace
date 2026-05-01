---
name: audit-srd
description: EDM Phase 3 (SRD Audit) — audit the SRD across 7 categories, remediate all P0/P1 findings, present HITL Gate 2. Invoked explicitly via /edm:audit-srd.
disable-model-invocation: true
model: opus
effort: max
argument-hint: <PREFIX>
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task, TodoWrite
---

# EDM Phase 3: SRD Audit

**Arguments**: $ARGUMENTS

- **Input**: SRD at `${user_config.srd_root}/{PREFIX}/${user_config.srd_filename}`
- **Output**: Audit report at `${user_config.srd_root}/{PREFIX}/audit-srd.md` + remediated SRD

Every error caught here saves 10x the effort of catching it during implementation.

## Operational Orchestration

1. Parse `{PREFIX}` from `$ARGUMENTS`.
2. `edm-state phase-start <PREFIX> 3`
3. Spawn 2-3 `edm-srd-auditor` agents in parallel — one per section group (e.g., sections 1-4, 5-7, 8-11). Each agent audits its sections across all 7 categories.
4. Compile findings from all agents into `${user_config.srd_root}/{PREFIX}/audit-srd.md` using the report format below.
5. **Remediate**: fix every P0 and P1 finding directly in the SRD. Update the Revision History (bump SRD version, e.g., 1.0.0 → 1.1.0).
6. Update `srd_version` in `.edm-state.json`: `edm-state set <PREFIX> srd_version 1.1.0`
7. `edm-state phase-complete <PREFIX> 3`
8. Present **HITL Gate 2** (see below) and STOP for sign-off.
9. On approval: `edm-state approve-gate <PREFIX> 2`.

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

| Severity | Definition | Action |
|---|---|---|
| P0 | Blocks implementation, security/legal issue, architecturally wrong | Must fix before Phase 4 |
| P1 | Significant gap, factual error, missing requirement | Must fix before Phase 4 |
| P2 | Polish, edge case, improvement | Can defer |

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

## P0 — Critical (Must Fix Now)
[findings]

## P1 — Significant (Must Fix Now)
[findings]

## P2 — Minor (Can Defer)
[findings]

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
1. Summarize: requirement count by priority (Must/Should/Could), key architecture decisions, risks, audit findings resolved (P0: N, P1: N, P2: N deferred).
2. Ask: *"Do you approve this SRD and want to proceed to ticket creation, or do you have changes?"*
3. **STOP and WAIT** — do not proceed to Phase 4 autonomously.
4. On approval: `edm-state approve-gate <PREFIX> 2`. Next: `/edm:tickets <PREFIX>`.
