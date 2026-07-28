---
name: audit-tickets
description: EDM Phase 5 (Ticket Pack Audit) -- audit the ticket pack for coverage, sizing, dependencies, AC quality, diagrams, version alignment, and consistency; present HITL Gate 3. Invoked explicitly via /edm:audit-tickets.
disable-model-invocation: true
model: opus
effort: max
argument-hint: <PREFIX>
allowed-tools: Read, Write, Edit, Bash(edm-state *), Glob, Grep, Task, TodoWrite, AskUserQuestion
---

# EDM Phase 5: Ticket Pack Audit

**Arguments**: $ARGUMENTS

- **Input**: Ticket pack at `${user_config.srd_root}/{PREFIX}/${user_config.ticket_pack_dirname}/`
- **Output**: Audit report at the same directory's `audit.md` + remediated ticket pack

## Step 0 -- Gate and Branch Preflight

Before Step 1, run the preflight per `skills/plan/SKILL.md Sec."Step 0 -- Gate and Branch Preflight"`,
using `<gated-command>` = `audit-tickets`.

## Operational Orchestration

1. Parse `{PREFIX}` from `$ARGUMENTS`.
2. `edm-state phase-start <PREFIX> 5`
3. **Version-drift check**: Read `srd_version` from state:
   ```bash
   edm-state get <PREFIX> | jq -r '.srd_version // "0.0.0"'
   ```
   Read the `Generated From:` header in the ticket pack `README.md`. If the header version does not
   match `srd_version`, surface it as a P0 finding immediately -- the ticket pack is stale. Example:
   ```
   [VERSION-DRIFT] P0 | README.md | Generated From: srd.md v1.0.0 but current srd_version is 1.2.0
   | Ticket pack was generated from an outdated SRD. Re-run /edm:tickets or accept with rationale.
   ```
4. **Two-lane mandatory spawn** -- spawn exactly 2 `edm-ticket-auditor` agents in parallel (never serial, never merged into one agent):
   - **Lane 1 (structural)** -- dimensions 1-4: coverage, sizing (using shared legend from `docs/templates/ticket-size-legend.md`), dependencies, version alignment
   - **Lane 2 (content-quality)** -- dimensions 5-8: AC quality, diagram correctness, consistency, version alignment overlap
5. Compile findings into `${user_config.srd_root}/{PREFIX}/${user_config.ticket_pack_dirname}/audit.md`. Tag each finding with its lane (`[structural]` or `[content-quality]`). De-duplicate findings that both lanes surface (deduplicated findings appear once).

6. **Remediate** all coverage gaps, decompose XL tickets, fix dependency declarations, improve vague AC, fix consistency mismatches.
7. `edm-state phase-complete <PREFIX> 5`
8. Present **HITL Gate 3** (see below, per `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"`) and STOP for sign-off.
9. On approval: `edm-state approve-gate <PREFIX> 3`.

## 8 Audit Dimensions

### 1. Coverage
- Every SRD requirement maps to >=1 ticket?
- Every ticket maps to >=1 SRD requirement?
- SRD Coverage Map matches reality?
- Orphan requirements or orphan tickets?

### 2. Sizing
- Sizes realistic given AC count?
- Any XL tickets needing decomposition?
- Consistent sizing for similar-scope tickets?

### 3. Dependencies
- All cross-ticket dependencies declared?
- Circular dependencies?
- Implicit dependencies (shared files, DB migrations) captured?
- Dependency chain matches phase ordering?

### 4. Critical Path
- Mermaid diagram syntactically valid?
- Diagram matches declared Depends On values?
- Every node colored?
- Follows `CLAUDE.md Sec."Mermaid diagram conventions"` for label text?

### 5. Acceptance Criteria Quality
- Every AC specific and testable?
- Each ticket has 6-12 AC?
- Vague AC ("should work", "is performant")?
- Duplicate AC across tickets?

### 6. Diagram Correctness
- All Mermaid blocks valid?
- All nodes colored and labeled?
- No orphan nodes?
- Per `CLAUDE.md Sec."Mermaid diagram conventions"`: a raw `;` inside `[...]`, `(...)`, `{...}`,
  `|...|`, `"..."`, or after the `:` in a sequenceDiagram message is a violation -- flag it.

### 7. Consistency
- Ticket IDs in README tables match IDs in epic files?
- SRD Refs in tickets match actual requirement IDs?
- Phase assignments consistent between README and epic files?
- Epic file names match epics summary table?

### 8. Version Alignment (NEW)
- Does the ticket pack `README.md` header `Generated From: srd.md vX.Y.Z` match the **current** SRD version (`srd_version` in `.edm-state.json`)?
- If mismatched -> P0 finding ("ticket pack is stale relative to current SRD; re-run Phase 4 or accept divergence with explicit rationale").

## Audit Report Format

```markdown
# Ticket Pack Audit Report: {Initiative Name}

**Date**: {date}

## Summary
- Coverage gaps: N | Sizing issues: N | Dependency issues: N
- Critical path issues: N | AC quality issues: N | Diagram issues: N
- Consistency issues: N | Version alignment issues: N
- **Verdict**: PASS / NEEDS FIXES

## Findings (organized by dimension)

## Recommendations (prioritized fixes)
```

## AI Execution Pattern

```
Agent: edm-ticket-auditor (Lane 1 -- structural)
Prompt: "Audit the ticket pack at ${user_config.srd_root}/{PREFIX}/${user_config.ticket_pack_dirname}/.
         Cross-reference against SRD at ${user_config.srd_root}/{PREFIX}/${user_config.srd_filename}.
         You are the STRUCTURAL lane (dimensions 1-4): coverage, sizing, dependencies, version alignment.
         For sizing checks, read the shared size legend at docs/templates/ticket-size-legend.md.
         Tag all findings: [structural]. Report every gap found."

Agent: edm-ticket-auditor (Lane 2 -- content-quality)
Prompt: "Audit the ticket pack at ${user_config.srd_root}/{PREFIX}/${user_config.ticket_pack_dirname}/.
         Cross-reference against SRD at ${user_config.srd_root}/{PREFIX}/${user_config.srd_filename}.
         You are the CONTENT-QUALITY lane (dimensions 5-8): AC quality, diagram correctness,
         consistency, version alignment.
         Tag all findings: [content-quality]. Report every gap found."
```

## HITL Gate 3

After resolving all findings:
1. Summarize: total ticket count by epic, size distribution (XS/S/M/L counts), critical path summary, estimated total effort, SRD coverage (N/N = 100%), version alignment confirmed.
2. Present the gate per `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"` -- header `"Gate 3"`, options **Approve** / **Revise** / **No-Go**. **STOP and WAIT** for the response.
3. On **Approve** (explicit selection only): `edm-state approve-gate <PREFIX> 3`. Next: `/edm:implement <PREFIX>`.
   On **Revise**: rework the flagged tickets and re-present the gate.
   On **No-Go**: summarize the blockers and stop.
