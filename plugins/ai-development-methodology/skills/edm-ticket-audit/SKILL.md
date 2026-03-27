---
name: edm-ticket-audit
description: "EDM Phase 5: Audit a ticket pack for SRD coverage gaps, sizing issues, dependency errors, acceptance criteria quality, and diagram correctness. Use after ticket pack creation to validate before implementation begins."
version: 1.0.0
category: methodology
tags:
  - enterprise
  - tickets
  - audit
  - review
  - quality
author: Scripps MCP
---

# EDM Phase 5: Ticket Pack Audit

## Overview

Phase 5 validates the ticket pack against the SRD and checks for structural issues before implementation begins. This is typically a lighter audit than Phase 3 (SRD Audit).

- **Input**: Ticket pack from Phase 4
- **Output**: Audit findings with remediation recommendations

## What to Check

Audit the ticket pack against ALL 7 dimensions:

### 1. Coverage
- Is every SRD requirement mapped to at least one ticket?
- Are there orphan requirements (in SRD but not in any ticket)?
- Are there orphan tickets (not tied to any SRD requirement)?
- Does the SRD Coverage Map in README.md match reality?

### 2. Sizing
- Are sizes realistic given the acceptance criteria?
- Any XL tickets that need decomposition?
- Any tickets that seem undersized for their AC count?
- Are size estimates consistent (similar-scope tickets have similar sizes)?

### 3. Dependencies
- Are all cross-ticket dependencies declared?
- Are there circular dependencies?
- Are there implicit dependencies not captured (shared files, DB migrations)?
- Does the dependency chain match the phase ordering?

### 4. Critical Path
- Is the critical path diagram correct?
- Are there hidden dependencies that would change the critical path?
- Does the critical path match the dependency declarations?
- Every node has a color assigned?

### 5. Acceptance Criteria Quality
- Are all AC specific and testable?
- Could a QC auditor pass/fail each one unambiguously?
- Does each ticket have 6-12 AC?
- Are there duplicate AC across tickets?

### 6. Diagram Correctness
- Mermaid/PlantUML syntax is valid
- All nodes are colored and labeled
- No orphan nodes
- Flow matches the described dependencies

### 7. Consistency
- Do ticket IDs in README tables match IDs in epic files?
- Do SRD Refs in tickets match actual requirement IDs in the SRD?
- Do phase assignments in tables match phase assignments in epic files?
- Do epic file names match the epics summary table?

## Audit Report Format

```markdown
# Ticket Pack Audit Report: {Initiative Name}

**Ticket Pack Version**: {version}
**SRD Version**: {version}
**Audit Date**: {date}

## Summary
- Coverage gaps: N
- Sizing issues: N
- Dependency issues: N
- Critical path issues: N
- AC quality issues: N
- Diagram issues: N
- Consistency issues: N
- **Verdict**: PASS / NEEDS FIXES

## Findings

### Coverage
[findings...]

### Sizing
[findings...]

### Dependencies
[findings...]

### Critical Path
[findings...]

### Acceptance Criteria
[findings...]

### Diagrams
[findings...]

### Consistency
[findings...]

## Recommendations
[Prioritized list of fixes needed before implementation]
```

## AI Execution Pattern

```
Agent: architect-reviewer
Prompt: "Audit the ticket pack at [path]. Cross-reference against SRD at [path].
         Check all 7 dimensions: coverage, sizing, dependencies, critical path,
         AC quality, diagrams, consistency. Report every gap found."
```

## Remediation

After the audit:
1. Fix all coverage gaps (add missing tickets or requirements)
2. Decompose any XL tickets
3. Fix dependency declarations and critical path diagram
4. Improve vague acceptance criteria
5. Fix any consistency mismatches between README and epic files

## HITL Gate 3: Ticket Pack Sign-Off

After resolving all audit findings, you MUST present the ticket pack to the user for review before proceeding to implementation.

**Gate Protocol:**
1. Present a concise summary:
   - Total ticket count and breakdown by epic
   - Size distribution (XS/S/M/L counts)
   - Critical path summary (longest dependency chain)
   - Estimated total effort
   - SRD coverage: N/N requirements covered (should be 100%)
   - Any audit findings that were deferred
2. Explicitly ask: *"Do you approve this ticket pack and want to proceed to implementation, or do you have changes?"*
3. **STOP and WAIT** — do not proceed to Phase 6 autonomously
4. If the user requests changes, revise the ticket pack and re-present
5. Only proceed after receiving explicit sign-off

**What the user might change at this gate:**
- Reprioritize tickets or epics
- Request ticket decomposition (too large)
- Merge tickets (too granular)
- Adjust acceptance criteria
- Reorder the critical path
- Defer entire epics to a later phase
- Request a phased rollout instead of big-bang implementation

## Next Phase

Once the user signs off at HITL Gate 3, proceed to Phase 6: Implementation + QC (`/edm-implement`).
