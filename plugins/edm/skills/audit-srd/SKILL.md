---
name: audit-srd
description: EDM Phase 3 (SRD Audit) -- audit the SRD across 7 categories, remediate all P0/P1 findings, present HITL Gate 2. Invoked explicitly via /edm:audit-srd.
user-invocable: true
model: opus
effort: max
argument-hint: <PREFIX>
allowed-tools: Read, Write, Edit, Bash(edm-state *), Glob, Grep, Task, TodoWrite, AskUserQuestion
---

# EDM Phase 3: SRD Audit

**Arguments**: $ARGUMENTS

- **Input**: SRD at `${INIT_DIR}/${user_config.srd_filename}`
- **Output**: Audit report at `${INIT_DIR}/audit-srd.md` + remediated SRD

**Plugin asset note**: every `docs/...` reference in this skill is relative to the EDM plugin root (`plugins/edm/` in this repository, or the installed plugin root in cache). Resolve that root before reading or grepping those files; never assume the current working directory is the plugin root.

Every error caught here saves 10x the effort of catching it during implementation.

## Step 0 -- Gate and Branch Preflight

Before Step 1, run the preflight per `skills/plan/SKILL.md Sec."Step 0 -- Gate and Branch Preflight"`,
using `<gated-command>` = `audit-srd` and `<phase-num>` = `3`.

## Operational Orchestration

1. Parse `{PREFIX}` from `$ARGUMENTS`.
2. `edm-state phase-start <PREFIX> 3`. Resolve the initiative directory from state (handles both
   flat and product-scoped layouts):
   ```bash
   INIT_DIR="$(edm-state resolve-dir <PREFIX>)"
   ```
3. **Version-drift check**: Read the SRD's Document Info section (or first Revision History entry) to
   extract the embedded version (e.g., `1.0.0`). Read `srd_version` from state:
   ```bash
   edm-state get <PREFIX> | jq -r '.srd_version // "0.0.0"'
   ```
   If the embedded SRD version differs from the state value, sync state to match the file version
   before proceeding (`edm-state srd-version <PREFIX> <embedded-version>`). A divergence here means
   the SRD was edited out-of-band; note it in the audit report intro.
3a. **Pre-verify mechanical claims** (before spawning auditors). The dispatching skill itself
    checks the cheap, mechanical claims an `edm-srd-auditor` would otherwise spend turns
    re-deriving, using only `grep`/`ls`/`jq` -- no new binary, no new state field, no new gate:
    - **File and path existence**: every file path the SRD's Target Components, references, or
      diagrams name -- confirm each exists (`ls` or `[ -e ... ]`).
    - **`file:line` anchors**: every `path:line` citation the SRD makes against the codebase --
      confirm the file exists and, where practical, that the line number is within the file's
      current line count.
    - **Requirement counts by priority**: count `Must`/`Should`/`Could` requirement IDs in the SRD
      with `grep -c` and compare against any total the SRD's own prose or Document Info table
      asserts.
    - **Version strings**: any version number the SRD asserts (its own Document Info version,
      referenced library/API versions where cheaply checkable) against `.edm-state.json` or the
      codebase's own manifest.
    A mechanical claim that fails this pre-verification is **not** silently corrected before the
    auditors run -- record it as a finding in `audit-srd.md` (the same as any other audit
    finding), exactly the kind of drift the audit exists to surface. Hand the auditors the
    corrected fact alongside the discrepancy note, per Step 4 below. Pre-verify only mechanical,
    checkable-by-grep claims -- never a judgment call (is this requirement well-specified? does
    this diagram match the prose?); those are what the auditors exist for, and pre-verifying a
    conclusion rather than a fact would defeat the purpose of dispatching them at all.
4. Spawn 2-3 `edm-srd-auditor` agents in parallel -- one per section group (e.g., sections 1-4, 5-7, 8-11). Each agent audits its sections across all 7 categories. Tell each agent the exact section count it is being assigned (`assigned={M}`, the size of its own section group) so it can emit its own completion sentinel correctly. Include, in each agent's launch prompt, the `Established facts -- do not re-derive` block built from Step 3a's verified claims (scoped to that agent's own assigned section group) per the AI Execution Pattern below.
5. **Check each agent's completion sentinel before compiling.** Each `edm-srd-auditor` returns
   text rather than writing a file, so check the **last non-empty line of that returned text**
   for the literal marker `SRD-AUDIT-COMPLETE` in the canonical grammar defined in `CLAUDE.md
   Sec."Verifier completion sentinel (canonical)"` (`<!-- SRD-AUDIT-COMPLETE range={section-group}
   assigned={M} audited={N} -->`). Refuse exactly as `bin/edm-check-verifier-sentinel` does for the
   file form, but against the returned text since there is no file to `tail`:
   - **Missing or misplaced sentinel** (not the true last non-empty line, or absent entirely) --
     the agent's returned block is truncated. Do not compile it.
   - **Short count** -- the sentinel is present and well-formed but `audited=` is below
     `assigned=` -- the agent finished cleanly but covered fewer sections than it was assigned. Do
     not compile it.
   A block failing either check is **not** compiled into `audit-srd.md`. Name the agent's assigned
   section group, and re-dispatch (resume) that agent for the same section group rather than
   treating its partial findings as that section group's audit result. **Gate 2 must not be
   presented while any block is outstanding** -- a truncated auditor's partial findings are never a
   substitute for that section group's completed audit.
6. Compile the surviving (sentinel-verified) findings from all agents into `${INIT_DIR}/audit-srd.md` using the report format below.
7. **Remediate**: fix every P0 and P1 finding directly in the SRD. Update the Revision History (bump SRD version, e.g., 1.0.0 -> 1.1.0).
8. Update `srd_version` in `.edm-state.json`: `edm-state srd-version <PREFIX> 1.1.0`
9. `edm-state phase-complete <PREFIX> 3`
9a. **Auto-update patterns** -- append novel SRD-audit findings to the pattern library:
    ```bash
    edm-state update-patterns <PREFIX> srd
    ```
10. Present **HITL Gate 2** (see below, per `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"`) and STOP for sign-off.
11. On approval: `edm-state approve-gate <PREFIX> 2`. Then append Gate 2 architecture decisions into `decisions.md` in the initiative directory:
    ```
    | Gate 2 | <architecture decision> | <chosen> | <rationale> | {date} |
    ```

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

Use the canonical P0/P1/P2/NOTED vocabulary from `CLAUDE.md Sec."Severity vocabulary"` -- no divergent local scale or local restatement.

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
Prompt: "Audit the SRD at ${INIT_DIR}/${user_config.srd_filename} for sections [N-M].
         Initiative directory (INIT_DIR): ${INIT_DIR} -- use this value; do not reconstruct it.
         Your assigned section group is S{N}-S{M} (assigned={M-N+1} sections). End your returned
         text with the completion sentinel per your own agent definition's 'Completion sentinel'
         section, using range=S{N}-S{M} and assigned={M-N+1}.
         Also read the codebase files referenced. Check all 7 categories.
         For each finding: [CATEGORY] [SEVERITY] Section X.Y | Finding | Recommendation.
         Be exhaustive. Cross-reference every factual claim against the actual codebase.

         Established facts -- do not re-derive:
         [The Step 3a mechanical claims scoped to sections S{N}-S{M}: confirmed file/path
         existence, confirmed file:line anchors, requirement counts by priority, and any version
         strings verified. One line per fact, e.g.:
           - src/auth/login.py exists (confirmed)
           - Requirement count: 12 Must, 8 Should, 3 Could (confirmed against SRD prose)
           - SRD Document Info version: 1.2.0 (matches .edm-state.json srd_version)]
         Treat these as given -- do not spend turns re-confirming them. If you observe a
         discrepancy from any listed fact during your own audit, report it as a finding rather
         than silently trusting the supplied value."
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

`edm-state update-patterns` (step 9a above) appends novel findings to the pattern library as stubs,
each carrying a `status: pending-review` line plus `source:`, `audit-type:` and `date:` provenance
(`docs/audit-patterns/README.md Sec."Append Schema"`). A stub nobody is ever asked about is a stub
forever, so Gate 2 -- one the human already stops at -- is where the ask happens.

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
