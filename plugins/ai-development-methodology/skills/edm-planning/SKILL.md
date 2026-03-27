---
name: edm-planning
description: "EDM Phase 1: Planning & Discovery - explore the codebase, identify gaps, define scope, map dependencies, and produce a go/no-go decision for a software initiative. Use when starting any new feature, refactor, or migration."
version: 1.0.0
category: methodology
tags:
  - enterprise
  - planning
  - discovery
  - scope
  - dependencies
author: Scripps MCP
---

# EDM Phase 1: Planning & Discovery

## Overview

Phase 1 takes a business requirement or feature request and produces a scope definition, current-state assessment, and go/no-go decision. This is the cheapest phase to get right and the most expensive to skip.

- **Input**: Business requirement, feature request, or strategic initiative
- **Output**: Scope definition, current-state assessment, go/no-go decision

## Activities

When this skill is invoked, perform ALL of the following:

### 1. Understand the Existing System
- Explore the codebase structure using the Explore agent (very thorough)
- Read architecture docs, READMEs, and CLAUDE.md files
- Map how components connect and communicate
- Identify the tech stack, frameworks, and patterns in use

### 2. Identify the Gap
- What exists today vs. what is needed?
- Where is the delta between current state and desired state?
- What works well that should be preserved?

### 3. Define Scope Boundaries
- **In scope**: What this initiative will deliver
- **Out of scope**: What is explicitly excluded
- **Deferred**: What could be done later in a follow-up initiative

### 4. Identify Constraints
- Licensing restrictions
- Existing code ownership
- Regulatory requirements (HIPAA, PCI-DSS, etc.)
- Platform limitations
- Team expertise and availability

### 5. Map Dependencies
- What existing systems does this touch?
- What must be built first? What blocks what?
- External service dependencies
- Shared infrastructure dependencies

### 6. Estimate Complexity
- Number of files/modules affected
- New vs. modified components
- Integration points
- Approximate ticket count (S/M/L initiative?)

## Output Format

Produce a planning document with these sections:

```markdown
# {Initiative Name} - Planning & Discovery

## Scope Statement
[1-2 paragraphs: what we're building and why]

## Component Inventory
| Component | Path/Location | Status | Notes |
|-----------|--------------|--------|-------|
| ...       | ...          | Exists/New/Modified | ... |

## Constraints
- [ ] Constraint 1: description
- [ ] Constraint 2: description

## Dependency Map
[List or diagram showing what blocks what]

## Complexity Estimate
- Files affected: ~N
- New modules: N
- Integration points: N
- Estimated size: Small (10-20 tickets) / Medium (30-50) / Large (50-85)

## Go/No-Go Decision
**Decision**: GO / NO-GO / CONDITIONAL
**Rationale**: [Why]
**Conditions** (if conditional): [What must be true before proceeding]
```

## AI Execution Pattern

```
Agent: Explore (very thorough)
Prompt: "Explore the codebase to understand [area]. Map all components,
         identify gaps vs [requirement]. Report what exists, what's missing,
         what constraints apply, and what's blocked."
```

Launch multiple Explore agents in parallel if the initiative spans multiple areas of the codebase.

## Tips

- Read existing docs before exploring code - they provide context faster
- Check git history for recent changes in the affected area
- Look for existing patterns that the new work should follow
- Identify the riskiest assumptions early
- If complexity estimate exceeds expectations, recommend decomposing into multiple initiatives

## HITL Gate 1: Planning Sign-Off

After completing the planning output, you MUST present it to the user for review before proceeding.

**Gate Protocol:**
1. Present a concise summary of the planning output:
   - Scope statement (1-2 sentences)
   - Number of components affected
   - Key constraints identified
   - Estimated initiative size (Small / Medium / Large)
   - Go/no-go recommendation with rationale
2. Explicitly ask: *"Do you approve this scope and want to proceed to SRD creation, or do you have changes?"*
3. **STOP and WAIT** — do not proceed to Phase 2 autonomously
4. If the user requests changes, revise the planning output and re-present
5. Only proceed after receiving explicit sign-off

**What the user might change at this gate:**
- Narrow or widen scope
- Add/remove constraints
- Change the go/no-go decision
- Request deeper exploration of a specific area
- Split into multiple smaller initiatives

## Next Phase

Once the user signs off at HITL Gate 1, proceed to Phase 2: SRD Creation (`/edm-srd-create`).
