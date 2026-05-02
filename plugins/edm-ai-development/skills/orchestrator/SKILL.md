---
name: orchestrator
description: Run the full Enterprise Development Methodology (EDM) — all 6 phases with 3 HITL gates. Invoked explicitly via /edm:orchestrator <initiative>. The initiative can be plain text, a file path, or a Jira ticket key. Use when starting a new feature, refactor, or service that touches 10+ files.
disable-model-invocation: true
model: opus
effort: max
argument-hint: '<initiative description | /path/to/file | PROJ-123>'
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task, TodoWrite
---

# EDM Orchestrator

You are orchestrating a complete Enterprise Development Methodology (EDM) initiative. The user invoked
`/edm:orchestrator` with:

**Raw input**: $ARGUMENTS

The input may be plain text, a file path, or a Jira ticket key — Step 1a resolves it into a concrete initiative
description before any planning begins.

## Overview

EDM is a six-phase process for shipping complex software with high confidence. The core insight: **the cost of planning
is always lower than the cost of rework**.

## When to Use

| Scenario                       | Use EDM?                 |
|--------------------------------|--------------------------|
| New feature touching 10+ files | Yes — full six phases    |
| Large refactor or migration    | Yes                      |
| New service or module          | Yes                      |
| Bug fix (1-3 files)            | No — just fix it         |
| Config/dependency update       | No — just do it          |
| Exploratory prototype          | Partial — Phase 1-2 only |

## The Six Phases + HITL Gates

```
Phase 1      HITL     Phase 2      Phase 3      HITL     Phase 4       Phase 5      HITL     Phase 6
Planning --> GATE --> SRD     -->  Audit   --> GATE --> Tickets --> Audit    --> GATE --> Implementation
             #1      Creation     (SRD)        #2      Creation    (Tickets)    #3       + QC + Remediation
```

| Gate   | After                | Approves                            |
|--------|----------------------|-------------------------------------|
| Gate 1 | Phase 1 Planning     | Scope, constraints, go/no-go        |
| Gate 2 | Phase 3 SRD Audit    | Remediated SRD is correct           |
| Gate 3 | Phase 5 Ticket Audit | Ticket pack is implementation-ready |

## Operational Orchestration

Execute the following steps. Use `bin/edm-state` (on PATH while plugin enabled) to record progress.

### Step 1 — Initial assessment

**Step 1a — Resolve the initiative description from `$ARGUMENTS`**

Determine the input type and extract the initiative description before proceeding:

- **Empty**: If `$ARGUMENTS` is empty or blank, ask: *"What are we building? Describe the initiative, provide a file
  path, or give a Jira ticket key (e.g., PROJ-123)."* Use the answer as the initiative description.

- **Jira ticket key** (`$ARGUMENTS` matches `[A-Z][A-Z0-9]+-\d+`, e.g., `ELI-42`):
  1. Call `getAccessibleAtlassianResources` to get the cloudId.
  2. Call `getJiraIssue` with the ticket key.
  3. Compose the initiative description from the issue summary, description, and any acceptance criteria in the body.
  4. Show the user the resolved description and confirm: *"Using Jira ticket {KEY}: '{summary}'. Proceed?"*

- **File path** (`$ARGUMENTS` starts with `/`, `./`, `~/`, or ends with a known extension like `.md`, `.txt`, `.rst`):
  1. Read the file with the `Read` tool.
  2. Use the full file contents as the initiative description.
  3. Tell the user: *"Using contents of {path} as the initiative description."*

- **Plain text** (everything else): use `$ARGUMENTS` directly as the initiative description.

Call the resolved value **`INITIATIVE`** — all subsequent steps use `INITIATIVE`, not `$ARGUMENTS`.

**Step 1b — EDM qualification and prefix**

1. Assess whether `INITIATIVE` qualifies for full EDM (10+ files, new module, major refactor). If not, say so and
   suggest doing it directly without EDM.
2. Ask the user for the **initiative prefix** (e.g., `AUTH`, `MIGR`, `FEAT`). Hint format:
   `${user_config.prefix_format_hint}`.
3. Run `edm-validate-prefix <PREFIX>` — if a SRD/{PREFIX}/ already exists, ask whether to resume or pick a different
   prefix.
4. If new: `edm-init <PREFIX>` to scaffold the initiative directory at `${user_config.srd_root}/{PREFIX}/`.

### Step 2 — Execute Phase 1 (Planning)

1. `edm-state phase-start <PREFIX> 1`
2. Spawn `edm-explorer` agent(s) with `INITIATIVE` as the initiative context — parallel if scope spans multiple codebase areas.
3. Synthesize agent output into `${user_config.srd_root}/{PREFIX}/planning.md` using the planning template.
4. `edm-state phase-complete <PREFIX> 1`
5. **HITL Gate 1**: present scope, components affected, constraints, estimated size, go/no-go recommendation. Ask: *"Do
   you approve this scope and want to proceed to SRD creation?"*
6. **STOP and WAIT for explicit sign-off.**
7. On approval: `edm-state approve-gate <PREFIX> 1`

### Step 3 — Execute Phase 2 (SRD)

1. `edm-state phase-start <PREFIX> 2`
2. Spawn `edm-srd-writer` for content sections; spawn `edm-architect` in parallel for Section 5 (Target Architecture).
3. Both agents write directly to `${user_config.srd_root}/{PREFIX}/${user_config.srd_filename}` (default `srd.md`).
4. `edm-state phase-complete <PREFIX> 2`
5. Proceed automatically to Phase 3 (no gate between Phase 2 and Phase 3).

### Step 4 — Execute Phase 3 (SRD Audit)

1. `edm-state phase-start <PREFIX> 3`
2. Spawn 2-3 `edm-srd-auditor` agents in parallel (one per section group).
3. Compile findings; remediate all P0/P1 directly in the SRD; update revision history.
4. Write audit report to `${user_config.srd_root}/{PREFIX}/audit-srd.md`.
5. `edm-state phase-complete <PREFIX> 3`
6. **HITL Gate 2**: present requirement count by priority, key architecture decisions, risks, audit findings resolved (
   P0: N, P1: N, P2: N deferred). Ask: *"Do you approve this SRD and want to proceed to ticket creation?"*
7. **STOP and WAIT for explicit sign-off.**
8. On approval: `edm-state approve-gate <PREFIX> 2`

### Step 5 — Execute Phase 4 (Ticket Pack)

1. `edm-state phase-start <PREFIX> 4`
2. Spawn `edm-ticket-writer` (per epic in parallel for large initiatives).
3. Output to `${user_config.srd_root}/{PREFIX}/${user_config.ticket_pack_dirname}/` (default `tickets/`):
    - `README.md` (index, legend, critical path, SRD coverage map, `Generated From: srd.md vX.Y.Z` header)
    - `epics/01-*.md` through `NN-*.md`
4. `edm-state phase-complete <PREFIX> 4`
5. Proceed automatically to Phase 5.

### Step 6 — Execute Phase 5 (Ticket Audit)

1. `edm-state phase-start <PREFIX> 5`
2. Spawn 2 `edm-ticket-auditor` agents in parallel (one structural, one content quality).
3. Compile findings; remediate all gaps in the ticket pack.
4. Write audit report to `${user_config.srd_root}/{PREFIX}/${user_config.ticket_pack_dirname}/audit.md`.
5. `edm-state phase-complete <PREFIX> 5`
6. **HITL Gate 3**: present ticket count by epic, size distribution, critical path, estimated effort, SRD coverage (N/N
   requirements). Ask: *"Do you approve this ticket pack and want to proceed to implementation?"*
7. **STOP and WAIT for explicit sign-off.**
8. On approval: `edm-state approve-gate <PREFIX> 3`

### Step 7 — Execute Phase 6 (Implementation + QC)

1. `edm-state phase-start <PREFIX> 6`
2. Group tickets by file/component independence into parallel waves.
3. Spawn `edm-implementer` agents per wave (each gets a worktree via `isolation: worktree`).
4. After each wave, the `SubagentStop` hook automatically spawns `edm-qc-auditor` to verify acceptance criteria.
5. Compile QC findings; remediate; re-audit affected tickets until all PASS.
6. `edm-state phase-complete <PREFIX> 6`

### Step 7b — Comprehensive Testing (recommended before declaring done)

After all tickets have an initial PASS verdict, suggest:

> *"All {N} tickets pass QC. Recommended: run `/edm:test {PREFIX}` to build thorough,
> layered test coverage (unit, component, integration, E2E, a11y) before declaring Phase 6
> complete. Implementer agents write basic smoke tests per ticket — `/edm:test` builds the
> full suite that gives you confidence to ship."*

This step is recommended but not mandatory. For very small initiatives (< 5 tickets, all tested
thoroughly by the implementers), the user may choose to proceed without it.

### Step 8 — Verify completion

- [ ] All tickets have a PASS verdict
- [ ] All P0 QC findings resolved
- [ ] Code compiles, existing tests pass
- [ ] `/edm:test {PREFIX}` run and all coverage targets met (or consciously skipped)
- [ ] Documentation updated
- [ ] Committed on feature branch
- Optional: invoke `/edm:code-audit` for the 11-lens exhaustive code audit before merging.
- Run `edm-state archive <PREFIX>` after the initiative ships.

## Phase Timing Guidelines

| Initiative Size        | Planning | SRD | Audit | Tickets | Audit | Impl   | Total     |
|------------------------|----------|-----|-------|---------|-------|--------|-----------|
| Small (10-20 tickets)  | 30m      | 2h  | 1h    | 1h      | 30m   | 4-8h   | 1-2 days  |
| Medium (30-50 tickets) | 1h       | 4h  | 2h    | 3h      | 1h    | 12-24h | 3-5 days  |
| Large (50-85 tickets)  | 2h       | 8h  | 4h    | 6h      | 2h    | 24-48h | 5-10 days |

Run `/edm:metrics --calibrate` periodically to update these from your team's actual data.

## Artifact Layout (committed to git)

```
${user_config.srd_root}/{PREFIX}/
├── planning.md                ← Phase 1
├── ${user_config.srd_filename} ← Phase 2 (default: srd.md)
├── audit-srd.md               ← Phase 3
├── ${user_config.ticket_pack_dirname}/
│   ├── README.md              ← index
│   ├── audit.md               ← Phase 5 audit
│   └── epics/01-*.md, 02-*.md, …
├── test-plan.md               ← /edm:test (stack + AC coverage map)
├── test-coverage.md           ← /edm:test (coverage by layer + AC↔test cross-ref)
├── code-audit/
│   └── {YYYY-MM-DD}/
│       ├── lens-L1.md … lens-L11.md
│       └── REMEDIATION.md
└── .edm-state.json            ← gate approvals, phase timestamps, coverage_by_layer
```

## Anti-Patterns

- **Skip the SRD** — scope creeps, contradictions emerge, tickets lack context.
- **Skip an audit** — errors propagate to every ticket and every line of code.
- **Auto-approve HITL gates** — defeats the purpose; human misalignment is 10x cheaper to fix now than after
  implementation.
- **One monolithic implementation pass** — context exhaustion, no parallelism.
- **XL tickets** — must be decomposed before starting.

Never auto-approve a HITL gate. Never skip a phase. Always record state via `edm-state`.
