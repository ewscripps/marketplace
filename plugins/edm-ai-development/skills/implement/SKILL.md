---
name: implement
description: EDM Phase 6 (Implementation + QC + Remediation) — parallel implementation waves, automatic QC audit (via SubagentStop hook), and remediation loop until all tickets PASS. Invoked explicitly via /edm:implement.
disable-model-invocation: true
model: opus
effort: max
argument-hint: <PREFIX>
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task, TodoWrite, TodoRead
---

# EDM Phase 6: Implementation + QC Audit + Remediation

**Arguments**: $ARGUMENTS

- **Input**: Audited ticket pack at `${user_config.srd_root}/{PREFIX}/${user_config.ticket_pack_dirname}/`
- **Output**: Committed code on a feature branch with all tickets PASS-verified

## Operational Orchestration

1. Parse `{PREFIX}` from `$ARGUMENTS`.
2. `edm-state phase-start <PREFIX> 6`
3. Read the ticket pack. Group tickets by file/component independence into parallel waves.
4. **For each wave**: spawn `edm-implementer` agents (6-10 parallel). Each gets `isolation: worktree` automatically.
5. After each implementer completes, the `SubagentStop` hook automatically spawns `edm-qc-auditor` to verify the ticket's acceptance criteria against the implemented code. (The hook is configured in `hooks/hooks.json`.)
6. Aggregate QC findings as they arrive.
7. **Remediate** any P0/P1 QC findings: spawn `edm-implementer` agents to fix; re-trigger QC.
8. Loop until all tickets have PASS verdict.
9. `edm-state phase-complete <PREFIX> 6`
10. Print the post-implementation checklist and remind the user about `/edm:code-audit <PREFIX>` for the optional 11-lens audit before merge.

## Step 1: Identify Parallelizable Work

Group tickets by file/component independence:

```
Wave 1: [{PREFIX}-T01, {PREFIX}-T02, {PREFIX}-T05]   (independent files)
Wave 2: [{PREFIX}-T03, {PREFIX}-T04]                  (depend on Wave 1)
Wave 3: [{PREFIX}-T06, {PREFIX}-T07]                  (depend on Wave 2)
```

## Step 2: Launch Agent Swarm

```
Agent: edm-implementer (6-10 parallel per wave, each in isolated worktree)
Prompt: "Implement tickets [{PREFIX}-T01, …] from the epic file at [path].
         Read the Target Components in each ticket before modifying them.
         Follow CLAUDE.md conventions and existing patterns.
         Write complete implementations — no stubs, no TODOs, no `pass`, no `raise NotImplementedError`.
         Reference ticket IDs ({PREFIX}-T{NN}) in commit messages."
```

## Step 3: Merge and Launch Next Wave

Resolve merge conflicts → run existing tests → launch next wave.

## Step 4: QC Audit (automatic via hook)

`SubagentStop` hook fires after each `edm-implementer` finishes:

```
Agent: edm-qc-auditor
Prompt: "Verify acceptance criteria for the tickets just implemented.
         Read the epic file. Read the implemented code at the Target Components.
         For every AC, determine PASS/PARTIAL/FAIL with file:line evidence."
```

Finding format:
```
[SEVERITY] {PREFIX}-T{NN} | path/to/file.py:line | AC#{N}: {criterion} | {what's wrong}
```

Verdicts: **PASS** (all AC satisfied) / **PARTIAL** (some gaps listed) / **FAIL** (critical AC unmet)

## Step 5: Remediate

1. Compile all P0/P1 findings.
2. Group by file independence → parallelize.
3. Spawn `edm-implementer` agents to fix: *"Fix these QC findings: [list]. Read the file at the given line before modifying. Write complete implementations."*
4. Commit referencing ticket IDs and finding numbers.
5. **Re-audit affected tickets** to prevent fix regressions.

## Step 6: Comprehensive Testing

After all tickets have an initial PASS verdict and the code compiles:

Recommend running `/edm:test {PREFIX}` to build out layered, comprehensive coverage:
> *"All {N} tickets pass QC. Before declaring Phase 6 complete, run `/edm:test {PREFIX}` to add
>  thorough unit, integration, E2E, and accessibility tests across all layers. Implementer agents
>  write basic smoke tests per ticket — `/edm:test` builds the full coverage suite."*

The user may choose to skip this step for small initiatives or where the implementer tests are
already comprehensive. If skipped, note it in the state:
```bash
edm-state set {PREFIX} test_layer_skipped true
```

## Step 7: Declare Done

Only when:
- [ ] All tickets have PASS verdict
- [ ] All P0 QC findings resolved
- [ ] Code compiles, existing tests pass
- [ ] No TODO or FIXME markers remain
- [ ] Documentation updated
- [ ] All files committed on the feature branch

After declaration, recommend the user run `/edm:code-audit <PREFIX>` for the 11-lens exhaustive audit before merging.

## QC Audit Report Format

```markdown
# QC Audit Report: {Initiative Name}

**Branch**: {branch} | **Date**: {date}

## Summary
| Epic | Tickets | PASS | PARTIAL | FAIL |

## Detailed Findings
### Epic 1
#### {PREFIX}-T01: {title} — PASS
All N acceptance criteria verified.

#### {PREFIX}-T02: {title} — PARTIAL
- [x] AC1-AC2: Verified
- [ ] AC3: [what's wrong]
**Finding**: [P1] {PREFIX}-T02 | src/api.py:45 | AC#3: Wrong status code

## Remediation Required
[Prioritized P0 and P1 findings]
```

## AI Execution Tips

- **Isolation**: `edm-implementer` has `isolation: worktree` — each parallel agent gets its own worktree automatically.
- **Read first**: Every agent reads existing code before modifying.
- **Complete code**: No stubs.
- **Test**: Run tests after each wave.
- **Commit often**: Small commits referencing ticket IDs.
- **Re-audit**: Always re-audit after remediation.
- **Background monitor**: While Phase 6 runs, the `edm-impl-progress` monitor reports each ticket commit as a notification.
