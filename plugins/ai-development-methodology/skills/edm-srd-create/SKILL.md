---
name: edm-srd-create
description: "EDM Phase 2: Create a Software Requirements Document (SRD) with unique requirement IDs, testable criteria, architecture diagrams, and prioritized features. Use after planning is complete to formalize requirements before implementation."
version: 1.0.0
category: methodology
tags:
  - enterprise
  - srd
  - requirements
  - documentation
  - architecture
author: Scripps MCP
---

# EDM Phase 2: SRD Creation

## Overview

Phase 2 transforms the scope definition from Phase 1 into a comprehensive Software Requirements Document (SRD). The SRD is the single source of truth for what will be built.

- **Input**: Scope definition from Phase 1 (planning)
- **Output**: Software Requirements Document (100-2000 lines)
- **Location**: `docs/{initiative}-srd.md`

## SRD Sections

Choose the sections that apply to your initiative:

| Section                  | When to Include                       |
|--------------------------|---------------------------------------|
| Executive Summary        | Always                                |
| Document Information     | Always                                |
| Purpose & Scope          | Always                                |
| Current State Assessment | Always                                |
| Target Architecture      | When architecture changes             |
| Feature Requirements     | Always                                |
| Security                 | When security-relevant                |
| Observability            | When operational behavior changes     |
| Compliance               | When compliance-relevant              |
| Performance Targets      | When performance matters              |
| Migration Path           | For large initiatives                 |
| Risks & Mitigations      | Always                                |
| Glossary                 | When domain-specific language is used |

## Requirement ID Conventions

Choose a short, unique prefix per initiative:

| Example   | Initiative               |
|-----------|--------------------------|
| `AUTH-01` | Authentication overhaul  |
| `PERF-01` | Performance optimization |
| `MIGR-01` | Database migration       |
| `APP-01`  | Main features            |
| `API-01`  | API v2 redesign          |

All requirements get sequential IDs: `{PREFIX}-01`, `{PREFIX}-02`, etc.

## Quality Standards (Mandatory)

Every SRD produced by this skill MUST meet these standards:

1. **Unique IDs** - Every requirement has a unique ID (e.g., `AUTH-01`)
2. **Testable** - Every requirement has clear pass/fail criteria
3. **Illustrated** - Architecture is shown with diagrams (Mermaid, ASCII, etc.)
4. **Prioritized** - Must Have / Should Have / Could Have for every requirement
5. **No vague language** - "fast" becomes "< 200ms p95 at 1000 QPS"; "secure" becomes specific auth flows
6. **Cross-referenced** - References to existing systems, files, APIs, external docs
7. **Appropriate length** - 800+ lines for major initiative, 200+ for focused feature, 50+ for small change

## SRD Template

```markdown
# {Initiative Name} - Software Requirements Document

## 1. Document Information

| Field           | Value                    |
|-----------------|--------------------------|
| Version         | 1.0.0                    |
| Status          | Draft / Under Review / Approved |
| Owner           | {name}                   |
| Last Updated    | {date}                   |

### Revision History
| Version | Date | Author | Summary |
|---------|------|--------|---------|

## 2. Executive Summary
[What, why, and the key capability delta. 2-3 paragraphs.]

## 3. Purpose & Scope

### In Scope
- ...

### Out of Scope
- ...

### Definition of Done
- ...

## 4. Current State Assessment
[What exists, what's strong, what's missing. Reference actual files/modules.]

## 5. Target Architecture
[Diagrams showing the target state. Use Mermaid for rendering in Git.]

## 6. Feature Requirements

### 6.1 {Domain Group}

#### {PREFIX}-01: {Requirement Title}
- **Priority**: Must Have / Should Have / Could Have
- **Description**: [What must be true when this is implemented]
- **Acceptance Criteria**:
  - [ ] Criterion 1 (specific, measurable)
  - [ ] Criterion 2
- **Dependencies**: {PREFIX}-NN (if any)
- **Target Components**: [file paths or module names]

[Repeat for each requirement]

## 7. Security Requirements
[If applicable: threat model, auth flows, encryption, authorization]

## 8. Observability Requirements
[If applicable: metrics, logging, tracing, dashboards]

## 9. Performance Targets
[If applicable: specific NFRs with measurement methodology]

## 10. Risks & Mitigations
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|

## 11. Glossary
| Term | Definition |
|------|-----------|
```

## AI Execution Pattern

```
Agent: technical-writer or product-manager
Prompt: "Write a comprehensive SRD for [initiative]. Read [existing docs]
         for context and format. Cover sections: [list applicable sections].
         Target [N] lines. Use requirement IDs [PREFIX]-01 through [PREFIX]-NNN.
         Every requirement must be testable."
```

For large SRDs, spawn multiple agents in parallel - one per section group - then merge results.

## Common Mistakes to Avoid

- Writing requirements that can't be tested ("should be user-friendly")
- Forgetting to cross-reference existing code and systems
- Making the SRD too long with filler vs. too short missing key requirements
- Using vague language that different people interpret differently
- Skipping architecture diagrams ("I'll figure it out during implementation")
- Not prioritizing requirements (everything becomes "must have")

## Next Phase

Once the SRD is complete, proceed to Phase 3: SRD Audit (`/edm-srd-audit`).
