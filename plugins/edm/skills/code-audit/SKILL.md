---
name: code-audit
description: EDM Code Audit (post-Phase 6) -- 11 parallel orthogonal audit agents (logic, dead code, edge cases, tests, hygiene, docs, consistency, security, spec, DRY, wiring) plus a synthesizer that produces a severity-ranked remediation plan. Invoked explicitly via /edm:code-audit. Supports --lenses subset for targeted re-audits.
disable-model-invocation: true
model: opus
effort: max
argument-hint: <PREFIX> [files-or-branch-scope] [--lenses L1,L3]
allowed-tools: Read, Write, Edit, Bash(edm-state *), Bash(mkdir *), Bash(date *), Glob, Grep, Task, TodoWrite, AskUserQuestion
---

# EDM Code Audit: Exhaustive Multi-Round QA

**Arguments**: $ARGUMENTS

- **Input**: An implementation (files, commits, branch) plus the initiative's ticket pack and SRD
- **Output**:
  - Per-round report: `<initiative-dir>/code-audit/pass-{N}_{YYYY-MM-DD}/REMEDIATION.md`
  - Persistent findings ledger: `<initiative-dir>/code-audit/findings-ledger.md` (spans all rounds)

A single auditor misses things because it gravitates toward familiar patterns. Eleven auditors with **orthogonal
mandates** -- plus a synthesizer -- catch what a single pass misses. Multiple rounds use a persistent ledger to
track findings across passes and determine convergence.

## Operational Orchestration

1. Parse `{PREFIX}`, optional scope, and optional `--lenses` subset from `$ARGUMENTS`.
   - `--lenses L1,L3` runs only those lens agents (comma-separated, with or without spaces).
   - Validate lens tokens against L1-L11; reject unknown tokens with a clear message.
   - If `--lenses` is omitted, run all 11 (full round).
   - Set `LENS_SET` = the list to run; set `ROUND_TYPE` = `full` (11 lenses) or `partial` (subset).
2. Determine scope: files / commits / branch. Read critical files yourself first to write sharp agent prompts.
3. Resolve the initiative directory from state (handles both flat and product-scoped layouts):
   ```bash
   INIT_DIR="$(edm-state resolve-dir <PREFIX>)"
   ```
   - SRD: `${INIT_DIR}/${user_config.srd_filename}`
   - Ticket pack: `${INIT_DIR}/${user_config.ticket_pack_dirname}/`
   - Ledger: `${INIT_DIR}/code-audit/findings-ledger.md`  (canonical cross-round path)
4. Obtain the pass number: `N=$(edm-state audit-round-start <PREFIX> code)`
5. Set `OUTPUT_DIR="${INIT_DIR}/code-audit/pass-${N}_$(date +%Y-%m-%d)/"` and `mkdir -p "${OUTPUT_DIR}"`
6. Read the prior `findings-ledger.md` if it exists (prior round context for the synthesizer).
7. **Launch lens agents in parallel** for every lens in `LENS_SET` (single message, multiple Task calls).
   Each lens:
   - Writes its raw report to `${OUTPUT_DIR}/lens-L{N}.md`
   - Receives the relevant prior-round open findings from the ledger (filtered to its lens) so it can confirm fixes or re-flag
8. Write `${OUTPUT_DIR}/lenses-run.txt` -- one lens ID per line (e.g., `L1`, `L2`, ... for a full round, or `L1`, `L3` for a partial). Add a `Round type: full` or `Round type: partial` header line.
9. **Spawn `edm-audit-synthesizer`**. It:
   - Reads the lens reports in `${OUTPUT_DIR}/`
   - Reads the prior `findings-ledger.jsonl` (or the legacy `findings-ledger.md` if only that exists)
   - Merges findings: assigns stable CA-NNN IDs to new findings, marks prior-round findings as `fixed` if absent, re-opens any that reappear, and ranks by confidence rather than discarding single-lens findings
   - Writes the updated `findings-ledger.jsonl` to `${INIT_DIR}/code-audit/findings-ledger.jsonl` -- the authoritative record (it does not write `findings-ledger.md`; that file is rendered separately, deterministically, by `edm-state render-ledger`)
   - Writes `${OUTPUT_DIR}/REMEDIATION.md` for this round
   - Marks the round as `partial` (non-convergent) in REMEDIATION.md if `ROUND_TYPE=partial`
10. **Convergence gate** (full rounds only -- partial rounds are never convergent). The order is always
    **compute -> present -> approve -> record** -- the flag is never set as a side effect of computing it:
    1. **Compute**: read `findings-ledger.md` and count open `P0`, `P1`, `P2`, and `NOTED` findings introduced
       or surviving in this round (call these `P0_COUNT`, `P1_COUNT`, `P2_COUNT`, `NOTED_COUNT`). A round with
       zero open P0/P1 findings is clean; any open P0/P1 is the blocking set. (Once `edm-state audit-converged`
       exists (EDMV3-T28) it becomes the authority for this computation; until then this step reads the ledger
       directly.)
    2. **Present** the gate via `AskUserQuestion` -- before any state mutation, regardless of clean or blocked:
        - Header: `"Convergence"`
        - Question body states the computed result and pass number, e.g.: *"Pass {N}: {P0_COUNT} P0,
          {P1_COUNT} P1, {P2_COUNT} P2, {NOTED_COUNT} NOTED findings open. Converge this round?"* -- if any
          P0/P1 remain open, name the blocking set findings in the body.
        - Options: **Approve** (record convergence now), **Revise** (address the blocking set and re-run
          affected lenses before asking again), **No-Go** (stop; do not record convergence)
        - Per the gate approval rules that apply to every gate in this methodology: a free-text reply
          ("yes", "looks good", "proceed") is **never** treated as approval -- only the explicit **Approve**
          option records convergence.
    3. **Approve** (and only on explicit Approve): run `edm-state approve-gate <PREFIX> code-audit`.
    4. **Record**: immediately after Approve, add a closure note to the top of `${OUTPUT_DIR}/REMEDIATION.md`
       (the current round's file):
       ```markdown
       ## Post-Remediation Closure ({YYYY-MM-DD})
       All findings in this round resolved. Convergence reached {YYYY-MM-DD}.
       The cross-round ledger at `code-audit/findings-ledger.md` is the authoritative record.
       The original audit snapshot is preserved below.
       ---
       ```
       ASCII-only, like every other committed artifact this methodology produces (no em dashes,
       no arrows, no smart quotes) -- `edm-lint-artifacts` class 2 enforces this at commit time.
       This prevents a reviewer reading the round directory in isolation from seeing
       "Convergence NOT reached" after all work is done.
    - On **Revise**: no state mutation; loop back to the remediation gate (step 11) and step 12.
    - On **No-Go**: no state mutation; stop and summarize the blockers for the human.
11. Read `REMEDIATION.md`. Present the remediation gate (see "Remediation Gate (Code Audit)" below) and STOP
    for approval.
12. On approval, remediate per the rollout order in the plan.
13. After remediation, re-run affected lenses (use `--lenses` for targeted re-audit, or full round for convergence). Loop until the Convergence gate records Approve.

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
| `edm-audit-wiring`       | L11: Integration wiring (frontend<->API<->backend, dummy data, unused endpoints) |

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

If yes to any -> record as "Noted / Not Actionable" with one-line rationale, do not report as a finding.

## Synthesizer Phase

After all lens reports are written, spawn `edm-audit-synthesizer` with:

```
Agent: edm-audit-synthesizer
Prompt: "Read the lens reports (prose and JSONL) in ${OUTPUT_DIR}/. Read the prior findings
         ledger at ${INIT_DIR}/code-audit/findings-ledger.jsonl (or the legacy
         findings-ledger.md if only that exists).
         Apply the second-pass False Alarm Filter, ranking by confidence and corroboration
         rather than discarding single-lens findings (multi-lens = higher confidence; a
         single-lens low-confidence finding is demoted to NOTED, never dropped).
         Deduplicate findings flagged by multiple lenses.
         Merge findings with the ledger: assign stable IDs (CA-001, CA-002, ...) to new
         findings; mark prior open findings as 'fixed' (resolved_round = N) if they no
         longer appear; re-open any that reappear under their original ID.
         Write the updated ledger to ${INIT_DIR}/code-audit/findings-ledger.jsonl -- the
         authoritative record. Do not write findings-ledger.md yourself.
         Write the consolidated remediation plan to ${OUTPUT_DIR}/REMEDIATION.md.
         If this is a partial round (fewer than 11 lenses), note 'Round type: partial'
         in REMEDIATION.md -- this round cannot satisfy the convergence gate."
```

Synthesizer responsibilities:

- Apply second-pass filter (intentional behavior, pre-existing issue, documented trade-off), ranking by confidence and corroboration rather than discarding single-lens findings
- Deduplicate (same issue flagged by L1 and L4 -> one finding, higher confidence)
- Severity-rank using canonical P0/P1/P2/NOTED scale (NOT legacy P1/P2/P3)
- Assign stable CA-NNN IDs and merge with prior-round ledger
- Suggest rollout order (which fixes first, which can batch)
- Write the authoritative ledger to `${INIT_DIR}/code-audit/findings-ledger.jsonl` (never `findings-ledger.md` directly -- `edm-state render-ledger` renders that file)
- Write round report to `${OUTPUT_DIR}/REMEDIATION.md`

## Severity Reference

Use the **canonical** severity scale from `CLAUDE.md Sec."Severity vocabulary"`:

| Severity | Definition                                                                  | Action                       |
|----------|-----------------------------------------------------------------------------|------------------------------|
| **P0**   | Critical -- blocks implementation, security/legal issue, production failure  | Fix before phase is complete |
| **P1**   | Significant -- material gap, factual error, behavior that must be corrected  | Fix before shipping          |
| **P2**   | Minor -- polish, edge-case, improvement, nice-to-have                        | Fix if low effort            |
| NOTED    | Looks like a problem but is intentional -- documented trade-off              | Document once, never revisit |

**Convergence blocking set**: open P0 and P1 findings from the ledger. P2 and NOTED findings do not block convergence.

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

[Every false alarm with rationale -- prevents re-investigation]

## Rollout Order

[Which findings first, which to batch, commit strategy]

## Verification Plan

[Syntax checks, tests to run, manual smoke test steps]
```

## Remediation Gate (Code Audit)

This is the remediation gate: distinct from the Convergence gate in Step 10, it approves the *remediation
plan itself* (whether to start fixing findings) rather than round closure, and it records no state --
no `edm-state` command runs from this gate.

After the synthesizer writes `REMEDIATION.md`:

1. Summarize: P0/P1/P2 counts (+ NOTED count), top 3 most impactful findings (one sentence each), false alarm count (demonstrates the
   filter worked), estimated remediation effort.
2. Present via `AskUserQuestion`:
   - Header: `"Remediation"`
   - Question: *"Do you approve this remediation plan?"* -- summarize the counts and top findings in the body.
   - Options: **Approve** (proceed to remediate per the rollout order), **Revise** (change scope or priority
     before starting), **No-Go** (stop; do not remediate)
   - A free-text reply is never treated as approval -- only the explicit **Approve** option proceeds.
3. **STOP and WAIT** for explicit approval.

## What Single-Pass Audits Miss (Why 11 Lenses)

- **Stubs**: A function returning `{"status": "ok"}` regardless of input looks syntactically correct to every other
  lens.
- **Spec gaps (L9)**: Without the ticket pack, an auditor reading code never knows a `--dry-run` flag was required but
  not built.
- **DRY (L10)**: Two date formatters in two files both work perfectly -- only L10's "count duplicate capabilities"
  mandate finds them.
- **Frontend wired to dummy data (L11)**: A React component rendering from `const MOCK_DATA = [...]` passes every other
  check.
- **Dead error messages**: An error in `if ! flock -w 1800` is unreachable if systemd kills the process at 600s -- only
  L2's cross-reference of timeouts vs. constraints finds it.
- **Runtime file hygiene**: Lock files created at runtime but missing from `.gitignore` only surface under L5.
