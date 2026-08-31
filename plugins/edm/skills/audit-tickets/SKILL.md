---
name: audit-tickets
description: EDM Phase 5 (Ticket Pack Audit) -- audit the ticket pack for coverage, sizing, dependencies, AC quality, diagrams, version alignment, and consistency; present HITL Gate 3. Invoked explicitly via /edm:audit-tickets.
user-invocable: true
model: opus
effort: max
argument-hint: <PREFIX>
allowed-tools: Read, Write, Edit, Bash(edm-state *), Glob, Grep, Task, TodoWrite, AskUserQuestion
---

# EDM Phase 5: Ticket Pack Audit

**Arguments**: $ARGUMENTS

- **Input**: Ticket pack at `${INIT_DIR}/${user_config.ticket_pack_dirname}/`
- **Output**: Audit report at the same directory's `audit.md` + remediated ticket pack

**Plugin asset note**: every `docs/...` reference in this skill is relative to the EDM plugin root (`plugins/edm/` in this repository, or the installed plugin root in cache). Resolve that root before reading or grepping those files; never assume the current working directory is the plugin root.

## Step 0 -- Gate and Branch Preflight

Before Step 1, run the preflight per `skills/plan/SKILL.md Sec."Step 0 -- Gate and Branch Preflight"`,
using `<gated-command>` = `audit-tickets` and `<phase-num>` = `5`.

## Operational Orchestration

1. Parse `{PREFIX}` from `$ARGUMENTS`.
2. `edm-state phase-start <PREFIX> 5`. Resolve the initiative directory from state (handles both
   flat and product-scoped layouts):
   ```bash
   INIT_DIR="$(edm-state resolve-dir <PREFIX>)"
   ```
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
4. **Two-lane mandatory spawn** -- count the total tickets in the pack (sum of ticket entries
   across the epic files, or the count in `README.md`'s ticket table -- the count Dimension 1
   coverage checking already needs, not a new counting mechanism) and spawn exactly 2
   `edm-ticket-auditor` agents in parallel (never serial, never merged into one agent), telling
   each its lane and the pack's total ticket count as `assigned={M}` (both lanes audit the whole
   pack, so both get the same `M`):
   - **Lane 1 (structural)** -- dimensions 1-4: coverage, sizing (using the plugin-root-relative shared legend at `docs/templates/ticket-size-legend.md`), dependencies, version alignment
   - **Lane 2 (content-quality)** -- dimensions 5-8: AC quality, diagram correctness, consistency, version alignment overlap
5. **Check each lane's completion sentinel before compiling.** Each `edm-ticket-auditor` returns
   text rather than writing a file, so check the **last non-empty line of that returned text** for
   the literal marker `TICKET-AUDIT-COMPLETE` in the canonical grammar defined in `CLAUDE.md
   Sec."Verifier completion sentinel (canonical)"` (`<!-- TICKET-AUDIT-COMPLETE range={lane}
   assigned={M} audited={N} -->`, `range=` exactly `structural` or `content-quality`). Refuse
   exactly as `bin/edm-check-verifier-sentinel` does for the file form, but against the returned
   text since there is no file to `tail`:
   - **Missing or misplaced sentinel** (not the true last non-empty line, or absent entirely) --
     that lane's returned block is truncated. Do not compile it.
   - **Short count** -- the sentinel is present and well-formed but `audited=` is below
     `assigned=` -- the lane finished cleanly but graded fewer tickets than the pack contains. Do
     not compile it.
   A lane failing either check is **not** compiled, is never de-duplicated against the other
   lane's findings, and must never be presented as half of a completed two-lane audit. Name the
   failing lane and re-dispatch it. **Gate 3 must not be presented while either lane is
   outstanding.**
6. Compile the surviving (sentinel-verified) findings from both lanes into `${INIT_DIR}/${user_config.ticket_pack_dirname}/audit.md`. Tag each finding with its lane (`[structural]` or `[content-quality]`). De-duplicate findings that both lanes surface (deduplicated findings appear once).

7. **Remediate** all coverage gaps, decompose XL tickets, fix dependency declarations, improve vague AC, fix consistency mismatches.
8. `edm-state phase-complete <PREFIX> 5`
8a. **Auto-update patterns** -- append novel ticket-audit findings:
    ```bash
    edm-state update-patterns <PREFIX> ticket
    ```
9. Present **HITL Gate 3** (see below, per `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"`) and STOP for sign-off.
10. On approval: `edm-state approve-gate <PREFIX> 3`. Then append Gate 3 approval decisions into `decisions.md` in the initiative directory:
   ```
   | Gate 3 | <ticket-pack decision> | <chosen> | <rationale> | {date} |
   ```
   If `compliance_enabled=true`, present **Gate 3.5**
   (below) before proceeding to Phase 6; otherwise proceed directly to `/edm:implement <PREFIX>`.

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
Prompt: "Audit the ticket pack at ${INIT_DIR}/${user_config.ticket_pack_dirname}/.
         Initiative directory (INIT_DIR): ${INIT_DIR} -- use this value; do not reconstruct it.
         Cross-reference against SRD at ${INIT_DIR}/${user_config.srd_filename}.
         You are the STRUCTURAL lane (dimensions 1-4): coverage, sizing, dependencies, version alignment.
         For sizing checks, read the plugin-root-relative shared size legend at docs/templates/ticket-size-legend.md.
         The pack contains {M} tickets total (assigned={M}). Tag all findings: [structural].
         Report every gap found. End your returned text with the completion sentinel per your own
         agent definition's 'Completion sentinel' section, using range=structural and
         assigned={M}."

Agent: edm-ticket-auditor (Lane 2 -- content-quality)
Prompt: "Audit the ticket pack at ${INIT_DIR}/${user_config.ticket_pack_dirname}/.
         Initiative directory (INIT_DIR): ${INIT_DIR} -- use this value; do not reconstruct it.
         Cross-reference against SRD at ${INIT_DIR}/${user_config.srd_filename}.
         You are the CONTENT-QUALITY lane (dimensions 5-8): AC quality, diagram correctness,
         consistency, version alignment.
         The pack contains {M} tickets total (assigned={M}). Tag all findings: [content-quality].
         Report every gap found. End your returned text with the completion sentinel per your own
         agent definition's 'Completion sentinel' section, using range=content-quality and
         assigned={M}."
```

## HITL Gate 3

After resolving all findings:
1. Summarize: total ticket count by epic, size distribution (XS/S/M/L counts), critical path summary, estimated total effort, SRD coverage (N/N = 100%), version alignment confirmed.
1a. **Pending pattern entries**: derive them and fold their curation into this same gate round --
   see Sec."Pending Pattern Entries (gate-time curation)" below. When none are pending, the gate
   presentation is exactly as it would otherwise be.
2. Present the gate per `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"` -- header `"Gate 3"`, options **Approve** / **Revise** / **No-Go**. **STOP and WAIT** for the response.
3. On **Approve** (explicit selection only): `edm-state approve-gate <PREFIX> 3`, then append:
   ```
   | Gate 3 | <ticket-pack decision> | <chosen> | <rationale> | {date} |
   ```
   to `decisions.md` in the initiative directory. If `compliance_enabled=true`, present Gate 3.5
   (below) next; otherwise the next command is `/edm:implement <PREFIX>`.
   On **Revise**: rework the flagged tickets and re-present the gate.
   On **No-Go**: summarize the blockers and stop.

## Gate 3.5 -- Compliance Review (when compliance_enabled=true)

Insert this gate between Gate 3 (above) and Phase 6, only when `compliance_enabled=true`:

1. Present a compliance review gate via `AskUserQuestion` (header `"Gate 3.5"`):
   - **Approve** -- regulatory traceability is verified, proceed to Phase 6
   - **Revise** -- specific tickets need compliance coverage rework (user will describe)
   - **No-Go** -- compliance gap is too large; re-plan
2. Record the gate: `edm-state approve-gate <PREFIX> 3.5` (only on explicit Approve).
3. Follows `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"`.

The ticket pack tables include regulatory-traceability columns (`Regulation | Control | Evidence`) when
`compliance_enabled=true` (see `skills/tickets/SKILL.md`).

## Pending Pattern Entries (gate-time curation)

`edm-state update-patterns` (step 8a above) appends novel findings to the pattern library as stubs,
each carrying a `status: pending-review` line plus `source:`, `audit-type:` and `date:` provenance
(`docs/audit-patterns/README.md Sec."Append Schema"`). A stub nobody is ever asked about is a stub
forever, so Gate 3 -- one the human already stops at -- is where the ask happens.

**Derive the list at presentation time with the `Grep` tool, never from state:** search the
plugin-root-relative path `docs/audit-patterns/*.md` for `status: pending-review`.

Nothing about pending entries is mirrored in `.edm-state.json`. The pattern documents are the only
record, so an entry curated by hand between gates simply stops appearing here.

**No matches: show nothing.** No heading, no "0 pending entries" line, no mention of curation
anywhere in the gate summary. Absence is authoritative.

**Matches: add one line per entry** to the gate summary, reading the entry's `###` heading and its
`source:` line out of the file each match came from:

```
Pending pattern entries
- {entry title} (source: {source-prefix}) -- landed in plugin-root-relative docs/audit-patterns/{target-document}.md
```

Then carry the curation questions **in the same `AskUserQuestion` call as the Gate 3 question** --
never a second round. Four questions is that tool's ceiling, so at most three entries are curated
per gate; when more are pending, take the three oldest by `date:` and leave the rest for the next
gate. Each per-entry question uses a short header (`"Pattern 1"`, `"Pattern 2"`, `"Pattern 3"` --
within the PROTOCOL's header limit), names the entry and its target document in its body, and
offers exactly these four options:

- **Keep** -- delete the entry's `status: pending-review` line, and only that line. Heading,
  provenance lines and body stay exactly as written.
- **Edit** -- take the human's revised one-paragraph description, replace the entry's body with it,
  then delete the `status: pending-review` line.
- **Discard** -- delete the entry outright: its `###` heading, its provenance lines and its body.
- **Leave pending** -- change nothing. The entry keeps its marker and is offered again at the next
  gate.

Apply the chosen edits with `Edit` after the response comes back and before running
`edm-state approve-gate`. Curation is one-way: once the marker is gone the entry is an ordinary
library entry, and a later `update-patterns` never re-marks it (de-duplication on the entry title
blocks the re-append).

Curation carries no approval weight. The Gate 3 question itself follows
`` `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"` `` unchanged, and leaving every entry pending
has no effect on **Approve** / **Revise** / **No-Go**.
