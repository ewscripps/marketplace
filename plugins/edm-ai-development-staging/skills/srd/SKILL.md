---
name: srd
description: EDM Phase 2 (SRD Creation) — transform planning scope into a comprehensive Software Requirements Document with unique requirement IDs, testable acceptance criteria, architecture diagrams, and prioritized features. Invoked explicitly via /edm:srd.
disable-model-invocation: true
model: opus
effort: high
argument-hint: <PREFIX>
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task, TodoWrite
---

# EDM Phase 2: SRD Creation

**Arguments**: $ARGUMENTS

- **Input**: Planning document at `${user_config.srd_root}/{PREFIX}/planning.md`
- **Output**: SRD at `${user_config.srd_root}/{PREFIX}/${user_config.srd_filename}` (default `srd.md`)

## Operational Orchestration

1. Parse `$ARGUMENTS` for `{PREFIX}`. If missing, ask the user or read from in-progress initiatives via `edm-state list`.
2. `edm-state get <PREFIX>` — verify Gate 1 has been approved. (The UserPromptExpansion hook also enforces this.)
3. `edm-state phase-start <PREFIX> 2`
4. Spawn `edm-srd-writer` for the main content + `edm-architect` in parallel for Section 5 (Target Architecture). Both agents write directly to the SRD file.
5. After both complete, verify the SRD file. Set `srd_version` in `.edm-state.json` to `1.0.0`.
6. `edm-state phase-complete <PREFIX> 2`
7. Proceed automatically to Phase 3 audit (`/edm:audit-srd <PREFIX>`) — no HITL gate between Phase 2 and Phase 3.

## SRD Sections

| Section | When to Include |
|---|---|
| Executive Summary | Always |
| Document Information | Always |
| Purpose & Scope | Always |
| Current State Assessment | Always |
| Target Architecture | When architecture changes |
| Feature Requirements | Always |
| Security | When security-relevant |
| Observability | When operational behavior changes |
| Performance Targets | When performance matters |
| Migration Path | For large initiatives |
| Risks & Mitigations | Always |
| Glossary | When domain-specific language is used |

## Requirement ID Conventions

All requirements get sequential IDs: `{PREFIX}-01`, `{PREFIX}-02`, …

## Quality Standards (Mandatory)

1. **Unique IDs** — every requirement has `{PREFIX}-NN`
2. **Testable** — every requirement has clear pass/fail acceptance criteria
3. **Illustrated** — architecture shown with Mermaid diagrams (system context + sequence)
4. **Prioritized** — Must Have / Should Have / Could Have
5. **No vague language** — "fast" → "< 200ms p95 at 1000 QPS"
6. **Cross-referenced** — actual file paths, API names, library versions
7. **Appropriate length** — 800+ lines major, 200+ focused, 50+ small change

## SRD Template

```markdown
# {Initiative Name} — Software Requirements Document

## 1. Document Information
| Field | Value |
|---|---|
| Version | 1.0.0 |
| Status | Draft |
| Owner | {name} |
| Last Updated | {date} |

### Revision History
| Version | Date | Author | Summary |

## 2. Executive Summary
## 3. Purpose & Scope (In/Out/Definition of Done)
## 4. Current State Assessment
## 5. Target Architecture (Mermaid diagrams)
## 6. Feature Requirements
### {PREFIX}-01: {Title}
- **Priority**: Must Have / Should Have / Could Have
- **Description**: [what must be true]
- **Acceptance Criteria**: [- [ ] testable items]
- **Dependencies**: {PREFIX}-NN (if any)
- **Target Components**: path/to/file
## 7. Security Requirements
## 8. Observability Requirements
## 9. Performance Targets
## 10. Risks & Mitigations
## 11. Glossary
```

## AI Execution Pattern

```
Agent: edm-srd-writer
Prompt: "Write the SRD for {PREFIX} at ${user_config.srd_root}/{PREFIX}/${user_config.srd_filename}.
         Read the planning doc and existing referenced files. Cover all applicable sections.
         Use requirement IDs {PREFIX}-01 through {PREFIX}-NNN. Every requirement must be testable."

Agent: edm-architect
Prompt: "Write Section 5 (Target Architecture) of the SRD at the same path. Include Mermaid
         diagrams (system context + sequence) and component design grounded in the existing codebase."
```

For large SRDs, run multiple `edm-srd-writer` agents in parallel (one per section group). Always run `edm-architect` separately for Section 5.

## Common Mistakes

- Untestable requirements ("should be user-friendly")
- Missing diagrams ("I'll figure it out during implementation")
- Everything as Must Have
- Vague language

After writing, the next step is automatic: `/edm:audit-srd <PREFIX>`.
