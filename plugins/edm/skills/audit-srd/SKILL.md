---
name: audit-srd
description: EDM Phase 3 (SRD Audit) -- audit the SRD across 7 categories, remediate all P0/P1 findings, present HITL Gate 2. Invoked explicitly via /edm:audit-srd.
disable-model-invocation: true
model: opus
effort: max
argument-hint: <PREFIX>
allowed-tools: Read, Write, Edit, Bash(edm-state *), Glob, Grep, Task, TodoWrite, AskUserQuestion
---

# EDM Phase 3: SRD Audit

**Arguments**: $ARGUMENTS

- **Input**: SRD at `${user_config.srd_root}/{PREFIX}/${user_config.srd_filename}`
- **Output**: Audit report at `${user_config.srd_root}/{PREFIX}/audit-srd.md` + remediated SRD

Every error caught here saves 10x the effort of catching it during implementation.

## Step 0 -- Gate and Branch Preflight

Before Step 1, run the preflight per `skills/plan/SKILL.md Sec."Step 0 -- Gate and Branch Preflight"`,
using `<gated-command>` = `audit-srd`.

## Operational Orchestration

1. Parse `{PREFIX}` from `$ARGUMENTS`.
2. `edm-state phase-start <PREFIX> 3`
3. **Version-drift check**: Read the SRD's Document Info section (or first Revision History entry) to
   extract the embedded version (e.g., `1.0.0`). Read `srd_version` from state:
   ```bash
   edm-state get <PREFIX> | jq -r '.srd_version // "0.0.0"'
   ```
   If the embedded SRD version differs from the state value, sync state to match the file version
   before proceeding (`edm-state srd-version <PREFIX> <embedded-version>`). A divergence here means
   the SRD was edited out-of-band; note it in the audit report intro.
4. Spawn 2-3 `edm-srd-auditor` agents in parallel -- one per section group (e.g., sections 1-4, 5-7, 8-11). Each agent audits its sections across all 7 categories.
5. Compile findings from all agents into `${user_config.srd_root}/{PREFIX}/audit-srd.md` using the report format below.
6. **Remediate**: fix every P0 and P1 finding directly in the SRD. Update the Revision History (bump SRD version, e.g., 1.0.0 -> 1.1.0).
7. Update `srd_version` in `.edm-state.json`: `edm-state srd-version <PREFIX> 1.1.0`
8. `edm-state phase-complete <PREFIX> 3`
8a. **Auto-update patterns** -- append novel SRD-audit findings to the pattern library:
    ```bash
    edm-state update-patterns <PREFIX> srd
    ```
9. Present **HITL Gate 2** (see below, per `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"`) and STOP for sign-off.
10. On approval: `edm-state approve-gate <PREFIX> 2`.

## 7 Audit Categories

### 1. Feature Gaps
Missing requirements, unaddressed edge cases, user flows that dead-end.

### 2. Factual Mistakes
Wrong API names, incorrect library references, impossible claims, version mismatches.

### 3. Diagram Errors
Mermaid syntax errors, logical flow errors, missing edges, orphan nodes. Follows
`CLAUDE.md Sec."Mermaid diagram conventions"` -- a raw `;` inside label/edge/message text is a
violation.

### 4. Competing Requirements
Conflicts with current codebase, existing features, other specs, internal contradictions.

### 5. Reuse Opportunities
Existing code/libraries that should be leveraged instead of rebuilt.

### 6. Specification Quality
Untestable requirements, missing IDs, missing priorities, internal contradictions.

### 7. Additional Concerns
Licensing, accessibility (WCAG), i18n, backward compatibility, deployment impact.

## Severity Levels

Use the canonical four-level scale from `CLAUDE.md Sec."Severity vocabulary"` -- no divergent local scale.

| Severity | Definition | Action |
|---|---|---|
| P0 | Blocks implementation, security/legal issue, architecturally wrong | Must fix before Phase 4 |
| P1 | Significant gap, factual error, missing requirement | Remediated before the phase or round may be called complete |
| P2 | Polish, edge case, improvement | Remediated before convergence |
| NOTED | Intentional, pre-existing, or accepted trade-off | Document in Decisions / Non-Findings; do not re-investigate |

## Finding Format

```
[CATEGORY] [SEVERITY] Section X.Y | Specific finding | Recommendation
```

## Audit Report Format

```markdown
# SRD Audit Report: {Initiative Name}

**SRD Version Audited**: {version}
**Audit Date**: {date}

## Summary
- P0 findings: N | P1 findings: N | P2 findings: N
- **Verdict**: PASS / FAIL

## P0 -- Critical (Must Fix Now)
[findings]

## P1 -- Significant (Must Fix Now)
[findings]

## P2 -- Minor (Remediate Before Convergence)
[findings]

## NOTED -- Intentional / Pre-existing
[Items that look like findings but are intentional, pre-existing, or accepted trade-offs -- documented once, not re-investigated]

## Remediation
[List of P0/P1 fixes applied to the SRD]
```

## AI Execution Pattern

```
Agent: edm-srd-auditor (launch 2-3 in parallel)
Prompt: "Audit the SRD at ${user_config.srd_root}/{PREFIX}/${user_config.srd_filename} for sections [N-M].
         Also read the codebase files referenced. Check all 7 categories.
         For each finding: [CATEGORY] [SEVERITY] Section X.Y | Finding | Recommendation.
         Be exhaustive. Cross-reference every factual claim against the actual codebase."
```

## HITL Gate 2

After remediating all P0/P1:
1. Summarize: requirement count by priority (Must/Should/Could), key architecture decisions, risks, audit findings resolved (P0: N, P1: N, P2: N).
2. **Mode branch (mini-SRD)**: when `mode=mini-srd`, this gate additionally stands in for the ticket-pack
   review -- present it as the merged gate with header `"Gate 2+3"` instead of `"Gate 2"`, and on Approve
   additionally record:
   ```bash
   edm-state skip-phase <PREFIX> 4 "mini-SRD: ticket pack fused into SRD file"
   edm-state skip-phase <PREFIX> 5 "mini-SRD: ticket audit fused into SRD audit"
   ```
   then proceed directly to Phase 6 (`/edm:implement <PREFIX>`) instead of Phase 4. On resume of a
   `mode=mini-srd` initiative past this merged gate, enter Phase 6 directly.
2a. **Pending pattern entries**: derive them and fold their curation into this same gate round --
   see Sec."Pending Pattern Entries (gate-time curation)" below. When none are pending, the gate
   presentation is exactly as it would otherwise be.
3. Present the gate per `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"` -- header `"Gate 2"` (or
   `"Gate 2+3"` under the mini-SRD branch above), options **Approve** / **Revise** / **No-Go**. **STOP
   and WAIT** for the response.
4. On **Approve** (explicit selection only): `edm-state approve-gate <PREFIX> 2`. Next: `/edm:tickets
   <PREFIX>` (or `/edm:implement <PREFIX>` directly under the mini-SRD branch above). Then append Gate 2
   architecture decisions into `decisions.md` in the initiative directory:
   ```
   | Gate 2 | <architecture decision> | <chosen> | <rationale> | {date} |
   ```
   On **Revise**: rework the flagged SRD sections and re-present the gate.
   On **No-Go**: summarize the blockers and stop.

## Pending Pattern Entries (gate-time curation)

`edm-state update-patterns` (step 8a above) appends novel findings to the pattern library as stubs,
each carrying a `status: pending-review` line plus `source:`, `audit-type:` and `date:` provenance
(`docs/audit-patterns/README.md Sec."Append Schema"`). A stub nobody is ever asked about is a stub
forever, so Gate 2 -- one the human already stops at -- is where the ask happens.

**Derive the list at presentation time, by grep, never from state:**

```bash
grep -n 'status: pending-review' docs/audit-patterns/*.md
```

Nothing about pending entries is mirrored in `.edm-state.json`. The pattern documents are the only
record, so an entry curated by hand between gates simply stops appearing here.

**No matches: show nothing.** No heading, no "0 pending entries" line, no mention of curation
anywhere in the gate summary. Absence is authoritative.

**Matches: add one line per entry** to the gate summary, reading the entry's `###` heading and its
`source:` line out of the file each match came from:

```
Pending pattern entries
- {entry title} (source: {source-prefix}) -- landed in docs/audit-patterns/{target-document}.md
```

Then carry the curation questions **in the same `AskUserQuestion` call as the Gate 2 question** --
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

Curation carries no approval weight. The Gate 2 question itself follows
`` `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"` `` unchanged, and leaving every entry pending
has no effect on **Approve** / **Revise** / **No-Go**.
