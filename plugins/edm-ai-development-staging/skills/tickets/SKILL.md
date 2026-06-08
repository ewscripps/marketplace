---
name: tickets
description: EDM Phase 4 (Ticket Pack Creation) — transform the audited SRD into a developer ticket pack with epic files and 6-12 testable acceptance criteria per ticket. Invoked explicitly via /edm:tickets.
disable-model-invocation: true
model: opus
effort: high
argument-hint: <PREFIX>
allowed-tools: Read, Write, Edit, Bash(edm-state *), Glob, Grep, Task, TodoWrite
---

# EDM Phase 4: Ticket Pack Creation

**Arguments**: $ARGUMENTS

- **Input**: Audited SRD at `${user_config.srd_root}/{PREFIX}/${user_config.srd_filename}`
- **Output**: Ticket pack at `${user_config.srd_root}/{PREFIX}/${user_config.ticket_pack_dirname}/`

## Operational Orchestration

1. Parse `{PREFIX}` from `$ARGUMENTS`.
2. `edm-state get <PREFIX>` — verify Gate 2 approved (UserPromptExpansion hook also enforces).
3. `edm-state phase-start <PREFIX> 4`
4. Read the SRD; identify the SRD version. The ticket pack README must include `Generated From: {srd_filename} v{srd_version}` for version linkage.
5. Spawn `edm-ticket-writer` (per epic in parallel for large initiatives).
6. Output structure:
   - `README.md` — index, legend, critical path, SRD coverage map, version header
   - `epics/01-{epic}.md` through `NN-{epic}.md`
7. `edm-state phase-complete <PREFIX> 4`
8. Proceed automatically to Phase 5 audit (`/edm:audit-tickets <PREFIX>`).

## README.md Must Contain

1. **Header**: `Generated From: {srd_filename} v{srd_version}` (for the version-alignment audit)
2. **Legend** — XS < 1d (1pt), S 1-3d (2-3pt), M 3-5d (5pt), L 1-2wk (8-13pt), XL = DECOMPOSE
3. **Cross-Cutting Requirements** — what every ticket must include (tests, docs, logging, CI)
4. **Ticket Index** — one table per phase: ID, Title, Epic, Size, Priority, Depends On, SRD Refs
5. **Critical Path** — Mermaid diagram, every node colored
6. **Epics Summary** — table mapping epic numbers to ticket counts and file links
7. **SRD Coverage Map** — every `{PREFIX}-NN` requirement → implementing ticket(s); no orphans

## Epic File — Each Ticket Format

```markdown
## {PREFIX}-T{NN}: {Imperative Verb Phrase Title}

| Field | Value |
|---|---|
| Epic | {epic name} |
| Phase | {phase number} |
| Priority | Must Have / Should Have / Could Have |
| Size | XS / S / M / L |
| SRD Refs | {PREFIX}-01, {PREFIX}-02 |
| Depends On | {PREFIX}-T{MM} (if any) |
| Target Components | path/to/file.py |

### Description
[2-3 paragraphs: what and why]

### Acceptance Criteria
- [ ] AC1: [Specific, testable criterion]
- [ ] AC2: ...
[6-12 checkboxes]

### Technical Notes
[Libraries, patterns, edge cases, gotchas]

### Out of Scope
[What this ticket does NOT cover]
```

## Good Acceptance Criteria

| Bad | Good |
|---|---|
| "Auth should work" | "POST /auth/login with valid creds returns 200 with JWT containing `sub`, `org_id`, `exp` claims" |
| "Performance should be acceptable" | "GET /api/users responds < 200ms p95 under 500 concurrent connections (k6 load test)" |
| "Handle errors gracefully" | "When DB is unreachable, returns 503 with `{error: 'service_unavailable', retry_after: 30}` and logs structured error with correlation ID" |

## Quality Standards

- Every SRD requirement → at least one ticket
- Every ticket → at least one SRD requirement
- No XL tickets (decompose them)
- Critical path diagrammed with all nodes colored
- 6–12 specific, testable AC per ticket
- Target: 40–60 tickets for major initiative, 10–20 for focused feature

## AI Execution Pattern

```
Agent: edm-ticket-writer
Prompt: "Create a developer ticket pack for the SRD at ${user_config.srd_root}/{PREFIX}/${user_config.srd_filename}.
         Output: ${user_config.srd_root}/{PREFIX}/${user_config.ticket_pack_dirname}/README.md + epics/.
         Header must include 'Generated From: {srd_filename} v{srd_version}'.
         Use ticket IDs {PREFIX}-T01 through {PREFIX}-TNN.
         Every SRD requirement must map to at least one ticket.
         6-12 specific, testable AC per ticket. No XL tickets — decompose."
```

For large initiatives, launch one `edm-ticket-writer` per epic in parallel, then merge into the README.

After writing, automatically proceed to `/edm:audit-tickets <PREFIX>`.
