---
name: edm-orchestrator
description: "Enterprise Development Methodology orchestrator - guides a software initiative through all 6 phases: Planning, SRD Creation, SRD Audit, Ticket Pack, Ticket Audit, Implementation+QC. Use when starting a new feature, refactor, or service that touches 10+ files."
version: 1.0.0
category: methodology
tags:
  - enterprise
  - methodology
  - sdlc
  - orchestration
  - srd
  - planning
author: Scripps MCP
---

# Enterprise Development Methodology (EDM) - Full Orchestrator

## Overview

The Enterprise Development Methodology is a six-phase process for shipping complex software with high confidence. It is designed for AI-assisted parallel execution but works for human teams too. The core insight: **the cost of planning is always lower than the cost of rework**.

## When to Use

| Scenario                           | Use EDM? | Notes                            |
|------------------------------------|----------|----------------------------------|
| New feature with 10+ files changed | Yes      | Full six phases                  |
| Large refactor or migration        | Yes      | SRD captures before/after state  |
| New service or module              | Yes      | Architecture needs documentation |
| Bug fix (1-3 files)                | No       | Just fix it                      |
| Config change or dependency update | No       | Just do it                       |
| Exploratory prototype              | Partial  | Phase 1-2 only                   |

## The Six Phases + HITL Gates

```
Phase 1      HITL     Phase 2      Phase 3      HITL     Phase 4          Phase 5      HITL     Phase 6
Planning --> GATE --> SRD     -->  Audit   --> GATE --> Ticket Pack --> Audit    --> GATE --> Implementation
             #1      Creation     (SRD)        #2      Creation        (Tickets)    #3       + QC Audit
                                                                                             + Remediation
```

Each phase produces a reviewable artifact. No phase is skipped.

### Human-in-the-Loop (HITL) Gates

Three mandatory review gates require explicit human sign-off before the next phase begins:

| Gate | After Phase | Reviewer Approves | What Happens If Rejected |
|------|------------|-------------------|--------------------------|
| **HITL Gate 1** | Phase 1 (Planning) | Scope, constraints, go/no-go decision | Revise scope, re-explore, or kill the initiative |
| **HITL Gate 2** | Phase 3 (SRD Audit) | Remediated SRD is correct and complete | Reopen audit findings, revise SRD sections |
| **HITL Gate 3** | Phase 5 (Ticket Audit) | Ticket pack is implementation-ready | Revise tickets, decompose further, fix gaps |

**Gate Protocol:**
1. Present the phase artifact to the user with a summary of key decisions
2. Explicitly ask: *"Do you approve proceeding to Phase N, or do you have changes?"*
3. **STOP and WAIT** for the user's response — do not proceed autonomously
4. If the user requests changes, make them and re-present for approval
5. Only proceed to the next phase after receiving explicit sign-off

## Quick Start

When a user invokes this skill, walk them through the full methodology:

### Step 1: Assess Scope
Ask the user what they are building. Determine:
- Is this large enough for the full EDM? (10+ files, new module, major refactor)
- What is the initiative name/prefix? (e.g., AUTH, PERF, MIGR)
- What is the target directory for artifacts? (default: `docs/`)

### Step 2: Execute Phases Sequentially

For each phase, invoke the corresponding EDM skill:

1. **Planning** - Use `/edm-planning` or spawn an Explore agent
   - Output: Scope statement, component inventory, constraint list, dependency map, go/no-go
   - Location: Working notes (can be inline or in `docs/{initiative}-planning.md`)

2. **HITL Gate 1** - Present planning output to the user
   - Summarize: scope, key constraints, estimated size, go/no-go recommendation
   - Ask: *"Do you approve this scope and want to proceed to SRD creation?"*
   - **STOP and WAIT for explicit sign-off before continuing**

3. **SRD Creation** - Use `/edm-srd-create`
   - Output: `docs/{initiative}-srd.md` (100-2000 lines)
   - Every requirement has a unique ID, is testable, and is prioritized

4. **SRD Audit** - Use `/edm-srd-audit`
   - Output: Audit findings with severity (P0/P1/P2)
   - Fix all P0/P1. Update SRD revision history.

5. **HITL Gate 2** - Present remediated SRD and audit summary to the user
   - Summarize: requirement count, architecture decisions, key risks, audit findings resolved
   - Ask: *"Do you approve this SRD and want to proceed to ticket creation?"*
   - **STOP and WAIT for explicit sign-off before continuing**

6. **Ticket Pack Creation** - Use `/edm-ticket-pack`
   - Output: `docs/tickets/{initiative}/README.md` + `epics/01-*.md` through `epics/NN-*.md`
   - Every SRD requirement maps to at least one ticket

7. **Ticket Pack Audit** - Use `/edm-ticket-audit`
   - Output: Audit findings on coverage, sizing, dependencies, AC quality
   - Fix gaps.

8. **HITL Gate 3** - Present audited ticket pack to the user
   - Summarize: ticket count, epic breakdown, critical path, estimated effort
   - Ask: *"Do you approve this ticket pack and want to proceed to implementation?"*
   - **STOP and WAIT for explicit sign-off before continuing**

9. **Implementation + QC** - Use `/edm-implement`
   - Parallel agent execution by file independence
   - QC audit against acceptance criteria
   - Remediation loop until all tickets PASS

### Step 3: Verify Completion

Before marking the initiative complete:
- [ ] All tickets have a PASS verdict
- [ ] All P0 QC findings are resolved
- [ ] Code compiles and existing tests pass
- [ ] Documentation is updated
- [ ] All files are committed on the feature branch

## Phase Timing Guidelines

| Initiative Size        | Planning | SRD  | SRD Audit | Tickets | Ticket Audit | Implementation | Total         |
|------------------------|----------|------|-----------|---------|--------------|----------------|---------------|
| Small (10-20 tickets)  | 30 min   | 2 hr | 1 hr      | 1 hr    | 30 min       | 4-8 hr         | **1-2 days**  |
| Medium (30-50 tickets) | 1 hr     | 4 hr | 2 hr      | 3 hr    | 1 hr         | 12-24 hr       | **3-5 days**  |
| Large (50-85 tickets)  | 2 hr     | 8 hr | 4 hr      | 6 hr    | 2 hr         | 24-48 hr       | **5-10 days** |

## Anti-Patterns to Avoid

- **Skip the SRD** - Tickets lack context, scope creeps, contradictions emerge
- **Skip the audit** - Errors propagate to every ticket and every line of code
- **Skip the HITL gate** - Human misalignment compounds across phases; rework is 10x more expensive after implementation starts
- **Auto-approve HITL gates** - The gate exists to catch misunderstandings; rubber-stamping defeats the purpose
- **One monolithic implementation pass** - Context exhaustion, no parallelism
- **Fix QC findings without re-auditing** - New fixes introduce new bugs
- **Vague acceptance criteria** - Untestable, disputes about completeness
- **Tickets without SRD refs** - No traceability, orphan work
- **XL tickets (2+ weeks)** - Must be decomposed before starting

## Artifacts Checklist

At the end of the full cycle, the repository should contain:

```
docs/
  {initiative}-srd.md
  tickets/
    {initiative}/
      README.md
      epics/
        01-{epic}.md
        02-{epic}.md
        ...
```

Plus the implementation itself in the appropriate project directories.

## Adapting to Your Context

### Smaller projects (< 10 tickets)
Compress Phases 2-5 into a single "mini-SRD" combining requirements, ticket list, and acceptance criteria. Still audit.

### Regulated industries (healthcare, finance, defense)
Add a compliance review gate between Phase 5 and Phase 6. Add traceability columns linking to regulatory frameworks (HIPAA, PCI-DSS, FedRAMP).

### Infrastructure-as-code
Replace file paths with resource paths (Terraform modules, K8s manifests). QC audit checks `terraform plan` output.

### Data/ML projects
Add "Data Requirements" section: data sources, schema, volume, freshness, privacy classification, model evaluation criteria.

## Related Skills

- `/edm-planning` - Phase 1: Planning & Discovery
- `/edm-srd-create` - Phase 2: SRD Creation
- `/edm-srd-audit` - Phase 3: SRD Audit
- `/edm-ticket-pack` - Phase 4: Ticket Pack Creation
- `/edm-ticket-audit` - Phase 5: Ticket Pack Audit
- `/edm-implement` - Phase 6: Implementation + QC + Remediation
