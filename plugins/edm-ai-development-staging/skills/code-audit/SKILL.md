---
name: code-audit
description: EDM Code Audit (post-Phase 6) — 11 parallel orthogonal audit agents (logic, dead code, edge cases, tests, hygiene, docs, consistency, security, spec, DRY, wiring) plus a synthesizer that produces a severity-ranked remediation plan. Invoked explicitly via /edm:code-audit.
disable-model-invocation: true
model: opus
effort: max
argument-hint: <PREFIX> [files-or-branch-scope]
allowed-tools: Read, Write, Edit, Bash(edm-state *), Bash(mkdir *), Glob, Grep, Task, TodoWrite
---

# EDM Code Audit: Exhaustive QA in One Pass

**Arguments**: $ARGUMENTS

- **Input**: An implementation (files, commits, branch) plus the initiative's ticket pack and SRD
- **Output**: Severity-ranked remediation plan at
  `${user_config.srd_root}/{PREFIX}/code-audit/{YYYY-MM-DD}/REMEDIATION.md`

A single auditor misses things because it gravitates toward familiar patterns. Eleven auditors with **orthogonal
mandates** — plus a synthesizer — catch what a single pass misses.

## Operational Orchestration

1. Parse `{PREFIX}` and optional scope from `$ARGUMENTS`.
2. Determine scope: files / commits / branch. Read critical files yourself first to write sharp agent prompts.
3. Resolve paths:
    - SRD: `${user_config.srd_root}/{PREFIX}/${user_config.srd_filename}`
    - Ticket pack: `${user_config.srd_root}/{PREFIX}/${user_config.ticket_pack_dirname}/`
    - Output dir: `${user_config.srd_root}/{PREFIX}/code-audit/$(date +%Y-%m-%d)/`
4. `mkdir -p "${OUTPUT_DIR}"`
5. `edm-state set <PREFIX> last_code_audit_at $(date -u +%Y-%m-%dT%H:%M:%SZ)`
6. **Launch 11 lens agents in parallel** (single message, multiple Task calls). Each writes its raw report to
   `${OUTPUT_DIR}/lens-L{N}.md`.
7. After all 11 complete, **spawn `edm-audit-synthesizer`**. It reads the 11 raw reports, applies the False Alarm
   Filter, deduplicates findings flagged by multiple lenses, and writes `${OUTPUT_DIR}/REMEDIATION.md`.
8. Read `REMEDIATION.md`. Present the HITL gate (summary below) and STOP for approval.
9. On approval, remediate per the rollout order in the plan.
10. After remediation, re-run only the lens agents whose lenses were touched. Loop until clean.

## The 11 Audit Lenses

| Agent                    | Lens                                                                         |
|--------------------------|------------------------------------------------------------------------------|
| `edm-audit-logic`        | L1: Logic, correctness, stubs, TODOs, NotImplementedError                    |
| `edm-audit-dead-code`    | L2: Dead code, unreachable paths, env-eliminated branches                    |
| `edm-audit-edge-cases`   | L3: Edge cases, concurrency, race conditions, null/empty inputs              |
| `edm-audit-test-quality` | L4: Test quality, suppressed failures, mock abuse                            |
| `edm-audit-runtime`      | L5: Runtime hygiene (lock files, temp files, .gitignore coverage)            |
| `edm-audit-docs`         | L6: Comment & error-message accuracy                                         |
| `edm-audit-consistency`  | L7: Cross-file consistency (timeouts, retry, error handling)                 |
| `edm-audit-security`     | L8: Security & portability (bash, paths, env vars, systemd)                  |
| `edm-audit-spec`         | L9: Spec/ticket compliance (REQUIRES ticket pack/SRD paths)                  |
| `edm-audit-dry`          | L10: DRY violations, duplicate utilities, divergent parallel implementations |
| `edm-audit-wiring`       | L11: Integration wiring (frontend↔API↔backend, dummy data, unused endpoints) |

## Lens Agent Launch Template

```
Agent: edm-audit-{lens-name}
Prompt: "You are auditing [scope] on lens [L#]: [Lens Name].

Scope:
- Files: [explicit file paths]
- Context: [deployment env, tool versions, constraints]
- Related docs: ${user_config.srd_root}/{PREFIX}/${user_config.srd_filename}, ${user_config.srd_root}/{PREFIX}/${user_config.ticket_pack_dirname}/
- Output: write your raw report to ${OUTPUT_DIR}/lens-L{N}.md

Your mandate is ONLY [lens name]. Apply the False Alarm Filter before reporting.
Write findings + 'Noted / Not Actionable' section to your assigned file."
```

## False Alarm Filter

Before reporting any finding, the lens agent applies:

1. Is this behavior documented as intentional in the plan/SRD/ticket?
2. Is there a comment explaining why this looks wrong but is correct?
3. Is this pattern used consistently everywhere in the file or project?

If yes to any → record as "Noted / Not Actionable" with one-line rationale, do not report as a finding.

## Synthesizer Phase

After all 11 lens reports are written:

```
Agent: edm-audit-synthesizer
Prompt: "Read the 11 lens reports in ${OUTPUT_DIR}/lens-L1.md through lens-L11.md.
         Apply the second-pass False Alarm Filter. Deduplicate findings flagged by
         multiple lenses (count multi-lens findings as higher confidence).
         Write the consolidated remediation plan to ${OUTPUT_DIR}/REMEDIATION.md
         using the standard plan format."
```

Synthesizer responsibilities:

- Apply second-pass filter (intentional behavior, pre-existing issue, documented trade-off, multi-lens corroboration)
- Deduplicate (same issue flagged by L1 and L4 → one finding, higher confidence)
- Severity-rank (P1 / P2 / P3 / NOTED)
- Suggest rollout order (which fixes first, which can batch)
- Write to `${OUTPUT_DIR}/REMEDIATION.md`

## Severity Reference

| Severity | Definition                                                                  | Action                       |
|----------|-----------------------------------------------------------------------------|------------------------------|
| P1       | Will cause production failure, security gap, or incorrect behavior          | Fix before shipping          |
| P2       | Operational friction, misleading messages, incomplete docs, unresolved TODO | Fix before shipping          |
| P3       | Nice-to-have improvements                                                   | Fix if low effort            |
| NOTED    | Looks like a problem but is intentional                                     | Document once, never revisit |

## Remediation Plan Format

```markdown
# Code Audit Remediation Plan: {Initiative or Feature Name}

## Context

[What was audited, commit/branch, date, deployment target]

## Findings Summary

| # | Sev | Lens(es) | Component | Issue |

## G1 (P1, L1+L4): [Title]

### Problem

### Fix (concrete code or config)

### Verification

### Files

## Decisions / Non-Findings

[Every false alarm with rationale — prevents re-investigation]

## Rollout Order

[Which findings first, which to batch, commit strategy]

## Verification Plan

[Syntax checks, tests to run, manual smoke test steps]
```

## HITL Gate (Code Audit)

After the synthesizer writes `REMEDIATION.md`:

1. Summarize: P1/P2/P3 counts, top 3 most impactful findings (one sentence each), false alarm count (demonstrates the
   filter worked), estimated remediation effort.
2. Ask: *"Do you approve this audit plan and want me to remediate, or do you have changes?"*
3. **STOP and WAIT** for explicit approval.

## What Single-Pass Audits Miss (Why 11 Lenses)

- **Stubs**: A function returning `{"status": "ok"}` regardless of input looks syntactically correct to every other
  lens.
- **Spec gaps (L9)**: Without the ticket pack, an auditor reading code never knows a `--dry-run` flag was required but
  not built.
- **DRY (L10)**: Two date formatters in two files both work perfectly — only L10's "count duplicate capabilities"
  mandate finds them.
- **Frontend wired to dummy data (L11)**: A React component rendering from `const MOCK_DATA = [...]` passes every other
  check.
- **Dead error messages**: An error in `if ! flock -w 1800` is unreachable if systemd kills the process at 600s — only
  L2's cross-reference of timeouts vs. constraints finds it.
- **Runtime file hygiene**: Lock files created at runtime but missing from `.gitignore` only surface under L5.
