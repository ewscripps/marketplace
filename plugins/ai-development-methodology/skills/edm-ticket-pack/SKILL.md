---
name: edm-ticket-pack
description: "EDM Phase 4: Create a developer ticket pack from an audited SRD - epic files with acceptance criteria, dependency maps, critical path diagrams, and full SRD coverage. Use after SRD audit to produce implementation-ready work items."
version: 1.0.0
category: methodology
tags:
  - enterprise
  - tickets
  - epics
  - acceptance-criteria
  - planning
author: Scripps MCP
---

# EDM Phase 4: Developer Ticket Pack Creation

## Overview

Phase 4 transforms the audited SRD into a structured ticket pack: an index README plus epic files containing
implementation-ready tickets with testable acceptance criteria.

- **Input**: Audited SRD from Phase 3
- **Output**: Ticket index + epic files

## Output Structure

```
docs/tickets/{initiative}/
  README.md              # Index: legend, phases, ticket tables, critical path
  epics/
    01-{epic-name}.md    # Full tickets with AC, tech notes, out of scope
    02-{epic-name}.md
    ...
```

## README.md Contents

The index file MUST contain:

### 1. Legend

Size/duration/story-point mapping and priority definitions:

| Size | Duration  | Story Points | Guideline                                       |
|------|-----------|--------------|-------------------------------------------------|
| XS   | < 1 day   | 1            | Config change, small fix, one-file edit         |
| S    | 1-3 days  | 2-3          | Single function/component, clear path           |
| M    | 3-5 days  | 5            | Multi-file change, some design decisions        |
| L    | 1-2 weeks | 8-13         | New module/service, multiple integration points |
| XL   | 2+ weeks  | 13+          | **Must be decomposed** before starting          |

### 2. Cross-Cutting Requirements

What every ticket must include (e.g., tests, documentation, CI checks).

### 3. Ticket Index

One table per phase. Columns: ID, Title, Epic, Size, Priority, Depends On, SRD Refs.

### 4. Critical Path

Mermaid diagram showing the dependency chain. Every node MUST have a color assigned.

### 5. Epics Summary

Table mapping epic numbers to ticket counts and file links.

### 6. SRD Coverage Map

Every requirement ID mapped to its implementing ticket(s). No orphan requirements.

## Epic File Contents

Each epic file contains 3-7 tickets. Each ticket includes:

```markdown
## TICK-{NN}: {Imperative Verb Phrase Title}

| Field             | Value                          |
|-------------------|--------------------------------|
| Epic              | {epic name}                    |
| Phase             | {phase number}                 |
| Priority          | Must Have / Should Have / Could Have |
| Size              | XS / S / M / L                 |
| SRD Refs          | {PREFIX}-01, {PREFIX}-02       |
| Depends On        | TICK-{NN} (if any)             |
| Target Components | path/to/file.py, path/to/dir/ |

### Description

[2-3 paragraphs: what is being built and why]

### Acceptance Criteria

- [ ] AC1: [Specific, testable criterion]
- [ ] AC2: [Specific, testable criterion]
- [ ] AC3: ...
- [ ] AC4: ...
- [ ] AC5: ...
- [ ] AC6: ...
  [6-12 checkboxes per ticket]

### Technical Notes

[Implementation hints: libraries, file paths, patterns, edge cases]

### Out of Scope

[What this ticket does NOT cover]
```

## Writing Good Acceptance Criteria

**Bad vs. Good examples:**

| Bad                                | Good                                                                                                                                                 |
|------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| "Authentication should work"       | "POST /auth/login with valid credentials returns 200 with JWT containing `sub`, `org_id`, and `exp` claims"                                          |
| "Performance should be acceptable" | "GET /api/users responds in < 200ms p95 under 500 concurrent connections (k6 load test)"                                                             |
| "Handle errors gracefully"         | "When DB is unreachable, service returns 503 with `{ error: 'service_unavailable', retry_after: 30 }` and logs structured error with correlation ID" |

## Quality Standards

- [ ] Every SRD requirement maps to at least one ticket
- [ ] Every ticket maps to at least one SRD requirement
- [ ] No ticket is larger than L (XL must be decomposed)
- [ ] Critical path is identified and diagrammed
- [ ] Phase boundaries are clear - no ticket spans multiple phases
- [ ] Each ticket has 6-12 specific, testable acceptance criteria
- [ ] Target: 40-60 tickets for major initiative, 10-20 for focused feature

## AI Execution Pattern

```
Agent: product-manager
Prompt: "Create a developer ticket pack for the SRD at [path].
         Read [existing ticket pack] as format reference if available.
         Create README.md index + one epic file per epic.
         Target [N] tickets across [M] epics and [P] phases.
         Every SRD requirement must map to at least one ticket.
         Every ticket must have 6-12 specific, testable acceptance criteria.
         No ticket larger than L."
```

## Next Phase

Once the ticket pack is complete, proceed to Phase 5: Ticket Pack Audit (`/edm-ticket-audit`).
