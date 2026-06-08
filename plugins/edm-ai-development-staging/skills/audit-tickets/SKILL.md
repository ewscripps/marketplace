---
name: audit-tickets
description: EDM Phase 5 (Ticket Pack Audit) — audit the ticket pack for coverage, sizing, dependencies, AC quality, diagrams, version alignment, and consistency; present HITL Gate 3. Invoked explicitly via /edm:audit-tickets.
disable-model-invocation: true
model: opus
effort: max
argument-hint: <PREFIX>
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task, TodoWrite
---

# EDM Phase 5: Ticket Pack Audit

**Arguments**: $ARGUMENTS

- **Input**: Ticket pack at `${user_config.srd_root}/{PREFIX}/${user_config.ticket_pack_dirname}/`
- **Output**: Audit report at the same directory's `audit.md` + remediated ticket pack

## Operational Orchestration

1. Parse `{PREFIX}` from `$ARGUMENTS`.
2. `edm-state phase-start <PREFIX> 5`
3. Spawn 2 `edm-ticket-auditor` agents in parallel:
   - One for **structural** issues: coverage, sizing, dependencies, version alignment
   - One for **content quality**: AC quality, diagrams, consistency
4. Compile findings into `${user_config.srd_root}/{PREFIX}/${user_config.ticket_pack_dirname}/audit.md`
5. **Remediate** all coverage gaps, decompose XL tickets, fix dependency declarations, improve vague AC, fix consistency mismatches.
6. `edm-state phase-complete <PREFIX> 5`
7. Present **HITL Gate 3** (see below) and STOP for sign-off.
8. On approval: `edm-state approve-gate <PREFIX> 3`.

## 8 Audit Dimensions

### 1. Coverage
- Every SRD requirement maps to ≥1 ticket?
- Every ticket maps to ≥1 SRD requirement?
- SRD Coverage Map matches reality?
- Orphan requirements or orphan tickets?

### 2. Sizing
- Sizes realistic given AC count?
- Any XL tickets needing decomposition?
- Consistent sizing for similar-scope tickets?

### 3. Dependencies
- All cross-ticket dependencies declared?
- Circular dependencies?
- Implicit dependencies (shared files, DB migrations) captured?
- Dependency chain matches phase ordering?

### 4. Critical Path
- Mermaid diagram syntactically valid?
- Diagram matches declared Depends On values?
- Every node colored?

### 5. Acceptance Criteria Quality
- Every AC specific and testable?
- Each ticket has 6-12 AC?
- Vague AC ("should work", "is performant")?
- Duplicate AC across tickets?

### 6. Diagram Correctness
- All Mermaid blocks valid?
- All nodes colored and labeled?
- No orphan nodes?

### 7. Consistency
- Ticket IDs in README tables match IDs in epic files?
- SRD Refs in tickets match actual requirement IDs?
- Phase assignments consistent between README and epic files?
- Epic file names match epics summary table?

### 8. Version Alignment (NEW)
- Does the ticket pack `README.md` header `Generated From: srd.md vX.Y.Z` match the **current** SRD version (`srd_version` in `.edm-state.json`)?
- If mismatched → P0 finding ("ticket pack is stale relative to current SRD; re-run Phase 4 or accept divergence with explicit rationale").

## Audit Report Format

```markdown
# Ticket Pack Audit Report: {Initiative Name}

**Date**: {date}

## Summary
- Coverage gaps: N | Sizing issues: N | Dependency issues: N
- Critical path issues: N | AC quality issues: N | Diagram issues: N
- Consistency issues: N | Version alignment issues: N
- **Verdict**: PASS / NEEDS FIXES

## Findings (organized by dimension)

## Recommendations (prioritized fixes)
```

## AI Execution Pattern

```
Agent: edm-ticket-auditor (launch 2 in parallel)
Prompt: "Audit the ticket pack at ${user_config.srd_root}/{PREFIX}/${user_config.ticket_pack_dirname}/.
         Cross-reference against SRD at ${user_config.srd_root}/{PREFIX}/${user_config.srd_filename}.
         Check dimensions [1-4 / 5-8]. Report every gap found.
         Verify ticket IDs use {PREFIX}-T{NN} format. Verify Generated From header matches current SRD version."
```

## HITL Gate 3

After resolving all findings:
1. Summarize: total ticket count by epic, size distribution (XS/S/M/L counts), critical path summary, estimated total effort, SRD coverage (N/N = 100%), version alignment confirmed.
2. Ask: *"Do you approve this ticket pack and want to proceed to implementation, or do you have changes?"*
3. **STOP and WAIT** — do not proceed to Phase 6 autonomously.
4. On approval: `edm-state approve-gate <PREFIX> 3`. Next: `/edm:implement <PREFIX>`.
