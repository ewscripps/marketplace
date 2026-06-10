---
name: plan
description: EDM Phase 1 (Planning & Discovery) -- explore the codebase, define scope, map dependencies, produce a go/no-go decision. Invoked explicitly via /edm:plan.
disable-model-invocation: true
model: opus
effort: max
argument-hint: <PREFIX> <initiative description>
allowed-tools: Read, Write, Bash(edm-state *), Bash(edm-init *), Bash(edm-validate-prefix *), Glob, Grep, Task, TodoWrite
---

# EDM Phase 1: Planning & Discovery

**Arguments**: $ARGUMENTS

- **Input**: Business requirement, feature request, or strategic initiative
- **Output**: `${user_config.srd_root}/{PREFIX}/planning.md` -- scope definition, current-state assessment, go/no-go decision

## Operational Orchestration

1. Parse `$ARGUMENTS` for `{PREFIX}` and the initiative description. If missing, ask the user.
2. `edm-validate-prefix <PREFIX>` -- if SRD/{PREFIX}/ already exists, ask whether to resume or pick another.
3. If new: prompt the user for a one-word **product** name (e.g., `auth`, `payments`) and a short **description slug** (e.g., `user-auth-rewrite`). Then:
   ```bash
   edm-init --product <product> --description <slug> <PREFIX>
   export EDM_PRODUCT=<product>; export EDM_DESCRIPTION=<slug>
   ```
   (The exports are required so subsequent `edm-state` calls resolve the product-scoped directory.)
4. `edm-state phase-start <PREFIX> 1`
5. Spawn `edm-explorer` agent(s) -- see "AI Execution Pattern" below.
6. Synthesize agent output into the planning document at `${user_config.srd_root}/{PREFIX}/planning.md` using the template below.
7. `edm-state phase-complete <PREFIX> 1`
8. `edm-state write-handoff <PREFIX>` -- create/refresh HANDOFF.md from the just-written planning.md. This is idempotent; re-running regenerates HANDOFF.md without error.
9. Present **HITL Gate 1** (see below) and STOP for sign-off.
10. On approval: `edm-state approve-gate <PREFIX> 1`.

## Activities -- the agent must cover ALL

### 1. Understand the Existing System
- Explore the codebase
- Read CLAUDE.md, README.md, architecture docs
- Map how components connect
- Identify tech stack, frameworks, patterns

### 2. Identify the Gap
- What exists today vs. what is needed?
- What works well that should be preserved?

### 3. Define Scope Boundaries
- **In scope**: what this delivers
- **Out of scope**: explicit exclusions
- **Deferred**: follow-up initiatives

### 4. Identify Constraints
Licensing, code ownership, regulatory requirements, platform limitations, team expertise.

### 5. Map Dependencies
What this touches, what blocks what, external service dependencies.

### 6. Estimate Complexity
Files affected, new modules, integration points, approximate ticket count (S/M/L).

## Planning Document Template

> **Planning authoring guidance** (from `docs/audit-patterns/srd-audit.md`):
> - **`## Go/No-Go`** -- an explicit GO/NO-GO/CONDITIONAL here prevents "undefined scope boundary" (top SRD P1 finding).
> - **`## Riskiest Assumptions`** -- pre-empts "requirement assumed but never validated" (top SRD P0/P1 finding).
> - **`## Open Questions`** -- tag with `[DECISION: A|B|C]` to surface bounded choices at Gate 1; resolves "ambiguous requirement" findings.
> - **`## Decisions Made`** -- filled at Gate 1; feeds HANDOFF.md and `decisions.md`. Empty section = highest SRD-rewrite rate in the corpus.

```markdown
# {Initiative Name} -- Planning & Discovery

## Scope Statement
[1-2 paragraphs]

## Component Inventory
| Component | Path | Status | Notes |
|---|---|---|---|

## Constraints
- [ ] Constraint 1

## Dependency Map
[What blocks what]

## Complexity Estimate
- Files affected: ~N
- New modules: N
- Estimated size: Small (10-20 tickets) / Medium (30-50) / Large (50-85)

## Go/No-Go
**Decision**: GO / NO-GO / CONDITIONAL
**Rationale**: [why]
**Conditions** (if conditional): [what must be true before proceeding]

## Riskiest Assumptions
[What we're assuming that hasn't been validated]

## Open Questions
{Each question on its own line, tagged as one of:}
- [DECISION: Option A | Option B | Option C] Question text
- [OPEN] Question text

## Decisions Made
{populated interactively at Gate 1 -- leave empty initially}
```

## AI Execution Pattern

Spawn the `edm-explorer` agent. For initiatives spanning multiple codebase areas, launch parallel agents:

```
Agent: edm-explorer
Prompt: "Explore the codebase to understand [area]. Map all components,
         identify gaps vs [requirement]. Report current state, gap analysis,
         component inventory, constraints, dependency map, and complexity estimate
         per the EDM Phase 1 template."
```

## HITL Gate 1

After writing the planning document:
1. Summarize concisely: scope (1-2 sentences), components affected, key constraints, estimated initiative size, go/no-go recommendation.
2. Ask: *"Do you approve this scope and want to proceed to SRD creation, or do you have changes?"*
3. **STOP and WAIT** -- do not proceed to Phase 2 autonomously.
4. On approval: `edm-state approve-gate <PREFIX> 1`. The next phase is `/edm:srd <PREFIX>` or via `/edm:orchestrator`.
