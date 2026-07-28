---
name: tickets
description: EDM Phase 4 (Ticket Pack Creation) -- transform the audited SRD into a developer ticket pack with epic files and 6-12 testable acceptance criteria per ticket. Invoked explicitly via /edm:tickets.
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

## Step 0 -- Gate and Branch Preflight

Before Step 1, run the preflight per `skills/plan/SKILL.md Sec."Step 0 -- Gate and Branch Preflight"`,
using `<gated-command>` = `tickets`.

## Operational Orchestration

1. Parse `{PREFIX}` from `$ARGUMENTS`.
2. `edm-state get <PREFIX>` -- verify Gate 2 approved (UserPromptExpansion hook also enforces).
3. Read `mode` and `compliance_enabled` from state:
   ```bash
   edm-state get <PREFIX> | jq -r '{mode: (.mode // "standard"), compliance_enabled: (.compliance_enabled // false)}'
   ```
4. `edm-state phase-start <PREFIX> 4`
5. Read the SRD; identify the SRD version. The ticket pack README must include `Generated From: {srd_filename} v{srd_version}` for version linkage.
6. Spawn `edm-ticket-writer` (per epic in parallel for large initiatives).
   - **IaC mode** (`mode=iac`): use resource paths in Target Components instead of source-file paths.
   - **Compliance** (`compliance_enabled=true`): add regulatory-traceability columns to all AC tables.
7. Output structure:
   - `README.md` -- index, legend, critical path, SRD coverage map, version header
   - `epics/01-{epic}.md` through `NN-{epic}.md`
8. `edm-state phase-complete <PREFIX> 4`
9. Proceed automatically to Phase 5 audit (`/edm:audit-tickets <PREFIX>`).

## README.md Must Contain

1. **Header**: `Generated From: {srd_filename} v{srd_version}` (for the version-alignment audit)
2. **Legend** -- Read `docs/templates/ticket-size-legend.md` and inline it verbatim (single source of truth; never re-author inline)
3. **Cross-Cutting Requirements** -- Read `docs/templates/cross-cutting-ac.md` and inline it verbatim (single source of truth)
4. **Ticket Index** -- one table per phase: ID, Title, Epic, Size, Priority, Depends On, SRD Refs
5. **Critical Path** -- Mermaid diagram, every node colored, following `CLAUDE.md Sec."Mermaid diagram conventions"` for label text (a raw semicolon in a label is a violation)
6. **Epics Summary** -- table mapping epic numbers to ticket counts and file links
7. **SRD Coverage Map** -- every `{PREFIX}-NN` requirement -> implementing ticket(s); no orphans

## Epic File -- Each Ticket Format

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
| Target Components | path/to/file.py  (or aws_resource.name for IaC mode) |

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

**When `compliance_enabled=true`**, append a regulatory-traceability table to each ticket's AC list:

```markdown
### Regulatory Traceability
| Regulation | Control | Evidence |
|---|---|---|
| HIPAA Sec.164.312 | Access control | AC3 verifies role-based token validation |
```

Empty traceability rows are a P0 finding in the ticket audit when `compliance_enabled=true`.

## Good Acceptance Criteria

| Bad | Good |
|---|---|
| "Auth should work" | "POST /auth/login with valid creds returns 200 with JWT containing `sub`, `org_id`, `exp` claims" |
| "Performance should be acceptable" | "GET /api/users responds < 200ms p95 under 500 concurrent connections (k6 load test)" |
| "Handle errors gracefully" | "When DB is unreachable, returns 503 with `{error: 'service_unavailable', retry_after: 30}` and logs structured error with correlation ID" |

## Quality Standards

- Every SRD requirement -> at least one ticket
- Every ticket -> at least one SRD requirement
- No XL tickets (decompose them)
- Critical path diagrammed with all nodes colored
- 6-12 specific, testable AC per ticket
- Target: 40-60 tickets for major initiative, 10-20 for focused feature

## AI Execution Pattern

```
Agent: edm-ticket-writer
Prompt: "Create a developer ticket pack for the SRD at ${user_config.srd_root}/{PREFIX}/${user_config.srd_filename}.
         Output: ${user_config.srd_root}/{PREFIX}/${user_config.ticket_pack_dirname}/README.md + epics/.
         Header must include 'Generated From: {srd_filename} v{srd_version}'.
         Use ticket IDs {PREFIX}-T01 through {PREFIX}-TNN.
         Every SRD requirement must map to at least one ticket.
         6-12 specific, testable AC per ticket. No XL tickets -- decompose."
```

For large initiatives, launch one `edm-ticket-writer` per epic in parallel, then merge into the README.

After writing, automatically proceed to `/edm:audit-tickets <PREFIX>`.
