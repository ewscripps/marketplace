---
name: edm-implement
description: "EDM Phase 6: Parallel implementation from an audited ticket pack, followed by QC audit against acceptance criteria and remediation loop. Use when the ticket pack is audited and ready for coding."
version: 1.0.0
category: methodology
tags:
  - enterprise
  - implementation
  - qc
  - audit
  - parallel
  - remediation
author: Scripps MCP
---

# EDM Phase 6: Implementation + QC Audit + Remediation

## Overview

Phase 6 is where code gets written. It uses parallel agent execution grouped by file independence, followed by a QC
audit against every acceptance criterion, and a remediation loop until all tickets pass.

- **Input**: Audited ticket pack from Phase 5
- **Output**: Committed, reviewed code on a feature branch

## Implementation Pattern

### Step 1: Identify Parallelizable Work

Group tickets by file/component independence. Tickets that touch different files can run in parallel. Tickets with
dependencies must run sequentially.

```
Wave 1: [TICK-01, TICK-02, TICK-05]  (independent files)
Wave 2: [TICK-03, TICK-04]           (depend on Wave 1)
Wave 3: [TICK-06, TICK-07]           (depend on Wave 2)
```

### Step 2: Launch Agent Swarm

One agent per independent group, each in an isolated environment (git worktree preferred):

```
Agent: domain-appropriate developer (6-10 parallel, isolated environments)
Prompt: "Implement tickets [IDs]. Read the epic file for acceptance criteria.
         Read existing code before modifying. Follow existing patterns.
         Write complete implementations - no stubs, no TODOs.
         Reference ticket IDs in commit messages."
```

### Step 3: Merge as Agents Complete

- Resolve merge conflicts
- Commit with descriptive messages referencing ticket IDs
- Run existing tests to ensure nothing is broken

### Step 4: Launch Next Wave

After prerequisite tickets merge, launch dependent tickets. Repeat until all tickets are implemented.

## QC Audit Pattern

After ALL implementation is complete, launch a QC audit swarm:

### One Auditor Per Epic Group

```
Agent: architect-reviewer or code-reviewer (one per epic group)
Prompt: "Read the epic file at [path] for acceptance criteria.
         Read the actual implemented code at [file paths].
         Compare EVERY acceptance criterion checkbox against the code.
         Does the code satisfy it? Report findings."
```

### Finding Format

```
[SEVERITY] TICK-{NN} | file/path.py:line | AC#{N}: {criterion} | {what's wrong}
```

### Severity Levels

| Severity | Definition                                                   | Action                |
|----------|--------------------------------------------------------------|-----------------------|
| P0       | AC completely unmet, security issue, or broken functionality | Must fix immediately  |
| P1       | AC partially met, missing edge case handling                 | Must fix before merge |
| P2       | Minor quality issue, style concern                           | Fix if time permits   |

### Verdict Per Ticket

| Verdict     | Meaning                             |
|-------------|-------------------------------------|
| **PASS**    | All acceptance criteria satisfied   |
| **PARTIAL** | Some AC met, some gaps (list which) |
| **FAIL**    | Critical AC not met                 |

## QC Audit Report Format

```markdown
# QC Audit Report: {Initiative Name}

**Implementation Branch**: {branch}
**Audit Date**: {date}

## Summary

| Epic | Tickets | PASS | PARTIAL | FAIL |
|------|---------|------|---------|------|
| ...  | ...     | ...  | ...     | ...  |

## Detailed Findings

### Epic 1: {name}

#### TICK-01: {title} - PASS

All 8 acceptance criteria verified.

#### TICK-02: {title} - PARTIAL

- [x] AC1: Verified
- [x] AC2: Verified
- [ ] AC3: POST /api/widget returns 201 - **Returns 200 instead of 201**
- [x] AC4-AC8: Verified

**Finding**: [P1] TICK-02 | src/api/widgets.py:45 | AC#3: Wrong status code

[continue for all tickets...]

## Remediation Required

[Prioritized list of all P0 and P1 findings]
```

## Remediation Pattern

### Step 1: Compile Fix List

Gather all QC findings into a prioritized task list.

### Step 2: Group by File Independence

Fixes touching different files can be parallelized.

### Step 3: Launch Fix Agents

```
Agent: domain-appropriate developer (grouped by file independence)
Prompt: "Fix these QC findings: [list]. Read each file before modifying.
         Write complete implementations - no stubs."
```

### Step 4: Commit Fixes

Descriptive messages referencing ticket IDs and finding numbers.

### Step 5: Re-Audit (If Findings Existed)

Re-run QC audit on affected tickets only. This prevents fix regressions.

## Post-Implementation Checklist

Before considering the initiative complete:

- [ ] All tickets have a PASS verdict (no FAIL or PARTIAL)
- [ ] All P0 QC findings are resolved
- [ ] Code compiles and all existing tests pass
- [ ] New code has no references to out-of-scope dependencies
- [ ] Documentation is updated (README, API docs, architecture docs)
- [ ] All files are committed on the feature branch
- [ ] No TODO or FIXME markers left from implementation

## AI Execution Tips

- **Isolation**: Use git worktrees or branches for parallel agents to avoid conflicts
- **Read first**: Every agent must read existing code before modifying
- **Complete code**: No stubs, no placeholder implementations, no "TODO: implement later"
- **Test**: Run tests after each wave to catch regressions early
- **Commit often**: Small, descriptive commits referencing ticket IDs
- **Re-audit**: Always re-audit after remediation to prevent regression

## Related Skills

- `/edm-orchestrator` - Full methodology overview
- `/edm-ticket-pack` - Phase 4 (input to this phase)
- `/edm-ticket-audit` - Phase 5 (prerequisite to this phase)
