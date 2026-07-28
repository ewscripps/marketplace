---
name: implement
description: EDM Phase 6 (Implementation + QC + Remediation) -- parallel implementation waves, automatic QC audit (via SubagentStop hook), and remediation loop until all tickets PASS. Invoked explicitly via /edm:implement.
disable-model-invocation: true
model: opus
effort: max
argument-hint: <PREFIX>
allowed-tools: Read, Write, Edit, Bash(edm-state *), Bash(grep *), Glob, Grep, Task, TodoWrite, TodoRead
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
7. **Remediate** any FAIL QC findings, at every severity: spawn `edm-implementer` agents to fix; re-trigger QC.
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
Prompt: "Implement tickets [{PREFIX}-T01, ...] from the epic file at [path].
         Read the Target Components in each ticket before modifying them.
         Follow CLAUDE.md conventions and existing patterns.
         Write complete implementations -- no stubs, no TODOs, no `pass`, no `raise NotImplementedError`.
         Reference ticket IDs ({PREFIX}-T{NN}) in commit messages."
```

## Step 3: Merge and Launch Next Wave

Resolve merge conflicts -> run existing tests -> launch next wave.

## Step 4: QC Audit (automatic via hook + sharding)

`SubagentStop` hook fires after each `edm-implementer` finishes. The hook spawns an
`edm-qc-auditor` which writes its report to the canonical qc/ home under the initiative directory.

**QC output paths** (resolved via `edm-state get <PREFIX>`):
- Single auditor: `<initiative-dir>/qc/qc-summary.md`
- Shards: `<initiative-dir>/qc/qc-shard-{NN}.md` (zero-padded, e.g., `qc-shard-01.md`)

**Sharding logic** -- after all implementer waves complete, if the total ticket count for a wave
exceeds `user_config.qc_shard_threshold` (default 20), spawn multiple `edm-qc-auditor` agents
in parallel, each assigned a slice of `ceil(N / threshold)` tickets:

```
# pseudo-code for the orchestrating skill
ticket_count = len(wave_tickets)
threshold    = user_config.qc_shard_threshold   # default 20
if ticket_count <= threshold:
    spawn 1 edm-qc-auditor -> writes qc/qc-summary.md
else:
    shard_size = ceil(ticket_count / ceil(ticket_count / threshold))
    for i, range in enumerate(chunks(wave_tickets, shard_size)):
        spawn edm-qc-auditor(shard=i+1, tickets=range) -> writes qc/qc-shard-{i+1:02d}.md
    merge all qc-shard-*.md files into qc/qc-summary.md
```

**Verdict semantics**:
- **PASS** -- AC is statically verifiable AND the code provably satisfies it (evidence at file:line)
- **PARTIAL** -- AC **cannot be verified statically** and requires a live runtime environment (running service, real DB, deployed container); record a `runtime-check:` note
- **FAIL** -- AC is statically verifiable AND the code provably does NOT satisfy it

Finding format:
```
[SEVERITY] {PREFIX}-T{NN} | path/to/file.py:line | AC#{N}: {criterion} | {what's wrong}
[PARTIAL]  {PREFIX}-T{NN} | AC#{N}: {criterion}  | runtime-check: {what runtime check resolves this}
```

## Step 5: Remediate

1. Compile all FAIL findings from `qc/qc-summary.md`, at every severity.
2. For each ticket with a PARTIAL verdict, persist it:
   ```bash
   edm-state record-partial-verdict <PREFIX> <ticket> PARTIAL '<runtime-check note>'
   ```
3. Group FAIL findings by file independence -> parallelize.
4. Spawn `edm-implementer` agents to fix: *"Fix these QC findings: [list]. Read the file at the given line before modifying. Write complete implementations."*
5. Commit referencing ticket IDs and finding numbers.
6. **Re-audit affected tickets** to prevent fix regressions.

Every PARTIAL is closed by the mandatory `/edm:verify-runtime` step before archive: it either
upgrades to PASS (verified at runtime) or, if runtime verification fails, becomes a FAIL and is
remediated like any other finding. The `record-partial-verdict` call persists a PARTIAL in state
only so HANDOFF.md can surface it as outstanding work until `/edm:verify-runtime` closes it.

## Step 6: Execution Report

After all PASS verdicts are recorded, write `exec-report.md` (or `epicN-execution-report.md` for per-epic)
to the initiative directory (resolved via `edm-state resolve-dir <PREFIX>`):

```markdown
# Execution Report: {PREFIX}

mode: {run-mode}   # e.g., live-db, dry-run, staging -- NOT the adaptation profile

## Summary
{what was built}

## Out of Scope (recorded boundaries)
{items not implemented -- e.g., optional AC#, follow-on tickets. A recorded boundary is a
decision made on its own merits, not a postponed finding -- it can only hold decisions, never
findings; a FAIL finding placed here instead of remediated is a QC failure.}

## Known Issues
{post-implementation issues visible but not blocking}

## Outstanding PARTIAL ACs
Cross-reference: see qc/qc-summary.md PARTIAL entries.

| Ticket | AC | Runtime-check note |
|--------|-----|--------------------------|
```

Note: the `mode` field here is the **run** mode (e.g., `live-db`), distinct from the state `mode`
adaptation profile (standard/iac/data-ml/etc.).

## Step 7: Comprehensive Testing

After all tickets have an initial PASS verdict, the execution report is written, and the code compiles:

Recommend running `/edm:test {PREFIX}` to build out layered, comprehensive coverage:
> *"All {N} tickets pass QC. Before declaring Phase 6 complete, run `/edm:test {PREFIX}` to add
>  thorough unit, integration, E2E, and accessibility tests across all layers. Implementer agents
>  write basic smoke tests per ticket -- `/edm:test` builds the full coverage suite."*

The user may choose to skip this step for small initiatives or where the implementer tests are
already comprehensive. If skipped, note it in the state:
```bash
edm-state set {PREFIX} test_layer_skipped true
```

## Step 8: Declare Done

Only when:
- [ ] All tickets have PASS verdict
- [ ] All FAIL findings resolved, at every severity
- [ ] Every outstanding PARTIAL closed via `/edm:verify-runtime` (upgraded to PASS, or
  downgraded to FAIL and remediated)
- [ ] Code compiles, existing tests pass
- [ ] No TODO or FIXME markers remain
- [ ] Execution report written to `exec-report.md` (Step 6)
- [ ] Documentation updated
- [ ] All files committed on the feature branch
- [ ] Coverage-auditor write-permission check (EDMV2-02 regression guard): verify that
  `agents/edm-test-coverage-auditor.md` has `Write` in `tools:` and does NOT have `Write`
  in `disallowedTools:`. Run these two commands and inspect the output:
  ```bash
  grep '^tools:' agents/edm-test-coverage-auditor.md
  grep '^disallowedTools:' agents/edm-test-coverage-auditor.md
  ```
  Pass condition: `tools:` line contains `Write`; `disallowedTools:` line does not contain `Write`.
  Fail condition: if `Write` is absent from `tools:` or present in `disallowedTools:`, the
  test-coverage-auditor cannot write `SRD/{PREFIX}/test-coverage.md` -- the testing layer is
  broken. Fix by editing `agents/edm-test-coverage-auditor.md` before declaring done.

After declaration, recommend the user run `/edm:code-audit <PREFIX>` for the 11-lens exhaustive audit before merging.

## QC Audit Report Format

```markdown
# QC Audit Report: {Initiative Name} [Shard {N}/{M} | Single]

**Date**: {date}
**Tickets audited**: {PREFIX}-T{first} through {PREFIX}-T{last}

## Summary
| Ticket | Title | Verdict |
|---|---|---|
| {PREFIX}-T01 | {title} | PASS |
| {PREFIX}-T02 | {title} | PARTIAL |
| {PREFIX}-T03 | {title} | FAIL |

## Detailed Findings

### {PREFIX}-T01: {title} -- PASS
All N acceptance criteria verified.
- [x] AC1: {criterion} -- verified at src/handler.py:42

### {PREFIX}-T02: {title} -- PARTIAL
- [x] AC1-AC3: Verified (statically)
- [ ] AC4: {criterion} -- **runtime-check:** requires a running service to verify the 201 response
**Finding**: [PARTIAL] {PREFIX}-T02 | AC#4: runtime-check: call the endpoint with a live server and assert 201

### {PREFIX}-T03: {title} -- FAIL
- [x] AC1-AC2: Verified
- [ ] AC3: {criterion} -- **FAIL**: handler.py:78 returns 200, not 201
**Finding**: [P1] {PREFIX}-T03 | src/handler.py:78 | AC#3: Wrong status code -- returns 200, must be 201

## Remediation Required
[Prioritized FAIL findings, at every severity, with file:line and specific fix.
PARTIAL findings appear in the exec-report's runtime-check table (Step 6) and are closed by
`/edm:verify-runtime` before archive, not remediated here directly.]
```

## AI Execution Tips

- **Isolation**: `edm-implementer` has `isolation: worktree` -- each parallel agent gets its own worktree automatically.
- **Read first**: Every agent reads existing code before modifying.
- **Complete code**: No stubs.
- **Test**: Run tests after each wave.
- **Commit often**: Small commits referencing ticket IDs.
- **Re-audit**: Always re-audit after remediation.
- **Background monitor**: While Phase 6 runs, the `edm-impl-progress` monitor reports each ticket commit as a notification.
