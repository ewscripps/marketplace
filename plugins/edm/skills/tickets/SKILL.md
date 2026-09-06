---
name: tickets
description: EDM Phase 4 (Ticket Pack Creation) -- transform the audited SRD into a developer ticket pack with epic files and 6-12 testable acceptance criteria per ticket. Invoked explicitly via /edm:tickets.
user-invocable: true
model: opus
effort: high
argument-hint: <PREFIX>
allowed-tools: Read, Write, Edit, Bash(edm-state *), Bash(edm-init *), Glob, Grep, Task, TodoWrite, AskUserQuestion
---

# EDM Phase 4: Ticket Pack Creation

**Arguments**: $ARGUMENTS

- **Input**: Audited SRD at `${INIT_DIR}/${user_config.srd_filename}`
- **Output**: Ticket pack at `${INIT_DIR}/${user_config.ticket_pack_dirname}/`

**Plugin asset note**: every `docs/...` reference in this skill is relative to the EDM plugin root (`plugins/edm/` in this repository, or the installed plugin root in cache). Resolve that root before reading or grepping those files; never assume the current working directory is the plugin root.

## Step 0 -- Gate and Branch Preflight

Before Step 1, run the preflight per `skills/plan/SKILL.md Sec."Step 0 -- Gate and Branch Preflight"`,
using `<gated-command>` = `tickets` and `<phase-num>` = `4`.

## Operational Orchestration

1. Parse `{PREFIX}` from `$ARGUMENTS`.
2. `edm-state get <PREFIX>` -- verify Gate 2 approved (UserPromptExpansion hook also enforces).
   Resolve the initiative directory from state (handles both flat and product-scoped layouts):
   ```bash
   INIT_DIR="$(edm-state resolve-dir <PREFIX>)"
   ```
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
2. **Legend** -- Read plugin-root-relative `docs/templates/ticket-size-legend.md` and inline it verbatim (single source of truth; never re-author inline)
3. **Cross-Cutting Requirements** -- Read plugin-root-relative `docs/templates/cross-cutting-ac.md` and inline it verbatim (single source of truth)
4. **Ticket Index** -- one table per phase: ID, Title, Epic, Size, Priority, Depends On, SRD Refs
5. **Critical Path** -- Mermaid diagram, every node colored, following `CLAUDE.md Sec."Mermaid diagram conventions"` for label text (a raw semicolon in a label is a violation). Read `docs/canonical-sections.md` (resolved relative to the EDM plugin's own root -- `plugins/edm/` in this repository, or the installed plugin's cache root, never the caller's cwd) for the actual section text; a bare `CLAUDE.md Sec."..."` reference does not resolve because CLAUDE.md at the plugin root is not loaded as runtime context.
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

Before spawning `edm-ticket-writer`, resolve the ticket pattern-library paths (AD6/route (c) --
the agent carries no `Bash` grant):
```bash
TICKET_PATTERN_PATHS="$(edm-state get-patterns ticket --paths)"
TICKET_PATTERN_SEED="$(printf '%s\n' "$TICKET_PATTERN_PATHS" | sed -n '1p')"
TICKET_PATTERN_DELTA="$(printf '%s\n' "$TICKET_PATTERN_PATHS" | sed -n '2p')"
# CA-124 (co-site): an unresolved SEED is a setup error, not an empty string to interpolate into
# the prompt. Without this check a failed `get-patterns` -- a missing plugin data directory, or a
# resolution that fell through -- yields an empty path, the spawn prompt reads `Read  first`, and
# the agent works UNGROUNDED with no signal anywhere that the pattern library was skipped. The
# DELTA path is legitimately empty until a delta has been harvested; only the SEED is always
# expected.
if [[ -z "$TICKET_PATTERN_SEED" ]]; then
  echo "edm:tickets: pattern-library seed unresolved -- 'edm-state get-patterns ticket --paths' returned no seed path. Refusing to spawn ungrounded; fix pattern-library resolution first." >&2
  exit 2
fi
```

```
Agent: edm-ticket-writer
Prompt: "Create a developer ticket pack for the SRD at ${INIT_DIR}/${user_config.srd_filename}.
         Initiative directory (INIT_DIR): ${INIT_DIR} -- use this value; do not reconstruct it.
         Output: ${INIT_DIR}/${user_config.ticket_pack_dirname}/README.md + epics/.
         Header must include 'Generated From: {srd_filename} v{srd_version}'.
         Use ticket IDs {PREFIX}-T01 through {PREFIX}-TNN.
         Every SRD requirement must map to at least one ticket.
         6-12 specific, testable AC per ticket. No XL tickets -- decompose.
         Pattern library: Read ${TICKET_PATTERN_SEED} first, then Read ${TICKET_PATTERN_DELTA}
         if it is non-empty and exists -- treat the two as one document, seed first. Do not
         resolve these paths yourself."
```

For large initiatives, launch one `edm-ticket-writer` per epic in parallel, then merge into the README.

After writing, automatically proceed to `/edm:audit-tickets <PREFIX>`.

## Fast-Track / Fix-Pack Mode (`lifecycle_mode=fast-track` or `fix-pack`)

When `lifecycle_mode` is `fast-track` or `fix-pack`, tickets are generated directly from an analysis
document without the full SRD/ticket-audit sequence -- this mode bypasses the normal Step 0 preflight's
assumption that Gate 2 is already approved, because Phases 1-3 never ran:

1. Read the analysis document the user provides.
2. If the initiative does not yet exist, scaffold it (`edm-init <PREFIX>`, or the product-scoped form)
   and record the lifecycle mode: `edm-state set-mode <PREFIX> lifecycle_mode fast-track` (or `fix-pack`).
3. Record skipped phases -- phase 1 is included because fast-track genuinely never runs a formal
   planning step; the analysis document replaces it:
   ```bash
   edm-state skip-phase <PREFIX> 1 "fast-track: planning skipped -- tickets from analysis doc"
   edm-state skip-phase <PREFIX> 2 "fast-track: SRD skipped -- tickets from analysis doc"
   edm-state skip-phase <PREFIX> 3 "fast-track: SRD audit skipped"
   edm-state skip-phase <PREFIX> 5 "fast-track: ticket audit skipped"
   ```
4. `edm-state phase-start <PREFIX> 4`
5. Spawn `edm-ticket-writer` directly from the analysis document (the same AI Execution Pattern above,
   with the analysis document as the source instead of an audited SRD).
6. `edm-state phase-complete <PREFIX> 4`
7. Present the single human review gate directly -- Phase 5 (ticket audit) is skipped, so this gate
   takes the place of Gate 3:
   ```
   AskUserQuestion header: "Gate 3"
   Question body: names this as the ticket-pack review that stands in for the skipped Phase 5
   Options: Approve / Revise / No-Go
   ```
   Follows `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"`. On **Approve** (explicit selection only):
   `edm-state approve-gate <PREFIX> 3`, then proceed to Phase 6 (`/edm:implement <PREFIX>`).

The state file is valid and recognized as fast-track -- `validate` does not flag it as incomplete.

In every other mode, this phase presents no gate of its own -- Gate 3 is presented by
`/edm:audit-tickets` per `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"`.
