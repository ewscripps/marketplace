---
name: implement
description: EDM Phase 6 (Implementation + QC + Remediation) -- parallel implementation waves, automatic QC audit (via SubagentStop hook), and remediation loop until all tickets PASS. Invoked explicitly via /edm:implement.
user-invocable: true
model: opus
effort: max
argument-hint: <PREFIX>
allowed-tools: Read, Write, Edit, Bash(edm-state *), Glob, Grep, Task, TodoWrite, TodoRead, AskUserQuestion
---

# EDM Phase 6: Implementation + QC Audit + Remediation

**Arguments**: $ARGUMENTS

- **Input**: Audited ticket pack at `${user_config.srd_root}/{PREFIX}/${user_config.ticket_pack_dirname}/`
- **Output**: Committed code on a feature branch with all tickets PASS-verified

## Step 0 -- Gate and Branch Preflight

Before Step 1, run the preflight per `skills/plan/SKILL.md Sec."Step 0 -- Gate and Branch Preflight"`,
using `<gated-command>` = `implement` and `<phase-num>` = `6`.

## Operational Orchestration

1. Parse `{PREFIX}` from `$ARGUMENTS`.
2. `edm-state phase-start <PREFIX> 6`
3. **TDD mode selection** -- if `implementation_mode` is not already set in state, ask the user:
   ```
   AskUserQuestion header: "Impl mode"
   Options: Standard -- basic smoke tests per ticket (Recommended) | TDD -- Red-Green-Refactor per ticket
   ```
   Record the choice: `edm-state set-mode <PREFIX> implementation_mode <value>`
   On resume, read `implementation_mode` from state and skip this prompt.
4. Read the ticket pack. Group tickets by file/component independence into parallel waves.
5. **For each wave**: spawn `edm-implementer` agents (6-10 parallel). Each gets `isolation: worktree` automatically.
   - In TDD mode, pass `implementation_mode=tdd` instruction to each implementer (Red-Green-Refactor per ticket).
6. After each implementer completes, the `SubagentStop` hook automatically spawns `edm-qc-auditor` to verify the ticket's acceptance criteria against the implemented code. (The hook is configured in `hooks/hooks.json`.) Each hook-spawned auditor writes its own per-implementer shard, `qc/qc-shard-impl-{NN}.md` -- never the shared `qc/qc-summary.md` (CA-440: 6-10 auditors finishing concurrently on one file would silently overwrite one another's FAIL verdicts), and never a `qc-shard-pass-*.md` name, which belongs to this skill's own threshold-shard namespace (CA-473).
   - In TDD mode, the QC auditor also runs the TDD compliance pass.
7. Aggregate QC findings as they arrive. **After the wave drains, merge every `qc/qc-shard-impl-*.md` and every `qc/qc-shard-pass-*.md` into `qc/qc-summary.md`** (one verdict table; keep each shard's file:line evidence). The shard files stay on disk as the per-implementer audit trail.
8. **Remediate** any FAIL QC findings, at every severity: spawn `edm-implementer` agents to fix; re-trigger QC.
9. Loop until all tickets have PASS verdict. Phase 6 closure (`edm-state phase-complete <PREFIX> 6`)
   is **not** a step in this list -- it belongs to the orchestrator's Phase 6 entry (or, for the
   standalone/direct-invocation path, to Step 8 "Declare Done" below), and is called there only.
10. **Auto-update patterns** -- append novel QC findings from this wave:
    ```bash
    edm-state update-patterns <PREFIX> qc
    ```
11. Print the post-implementation checklist and remind the user about `/edm:code-audit <PREFIX>` for the 11-lens audit before merge -- mandatory for every `mode` except `prototype`, and not required when `lifecycle_mode` is `fast-track` or `fix-pack` (see Step 8 below).

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
- Hook-spawned (per-implementer) auditor: `<initiative-dir>/qc/qc-shard-impl-{NN}.md`, where `{NN}` is
  the lowest ticket number in that implementer's assigned range, zero-padded (e.g. tickets
  T07-T09 -> `qc-shard-impl-07.md`). The hook path NEVER writes `qc-summary.md` directly (CA-440).
- Threshold-shard (this skill's post-wave QC) auditor:
  `<initiative-dir>/qc/qc-shard-pass-w{WW}-{NN}.md`, where `{WW}` is the **wave number** (1-based,
  zero-padded) and `{NN}` is the **shard ordinal within that wave** (1-based, zero-padded), not a
  ticket number. The wave component is required (CA-515): an ordinal-only name collides across
  waves whenever two waves both stay at or under `qc_shard_threshold` and each writes a single
  shard 1.
- **The two prefixes are disjoint namespaces and MUST NOT overlap** (CA-473). Both mechanisms run
  concurrently and write whole files into the same `qc/` directory, so a shared key space collides
  deterministically -- an unprefixed `qc-shard-{NN}.md` would let threshold shard 1 clobber the
  implementer shard whose range starts at T01 (and shard 2 vs T02, and so on), and the loser's FAIL
  verdicts would never reach the merge step. Only PARTIAL verdicts survive elsewhere (via the
  locked `record-partial-verdict`); PASS and FAIL live ONLY in these markdown files.
- Merged report: `<initiative-dir>/qc/qc-summary.md` -- produced ONLY by this skill's merge step
  (Step 4 item 7 above / the pseudo-code below), from all `qc-shard-impl-*.md` **and** all
  `qc-shard-pass-*.md` files.

**Threshold sharding** -- separately from the per-implementer hook shards, when this skill itself
orchestrates a QC pass **after each wave's implementers complete** (Step 4 item 7 -- this runs once
per wave, not once per initiative) and that wave's ticket count exceeds
`user_config.qc_shard_threshold` (default 20), it spawns multiple `edm-qc-auditor` agents in
parallel, each assigned a slice of `ceil(N / threshold)` tickets from that wave:

```
# pseudo-code for the orchestrating skill -- runs once per wave (wave_num is that wave's 1-based index)
wave_ticket_count = len(wave_tickets)
threshold         = user_config.qc_shard_threshold   # default 20
if wave_ticket_count <= threshold:
    spawn 1 edm-qc-auditor -> writes qc/qc-shard-pass-w{wave_num:02d}-01.md
else:
    shard_size = ceil(wave_ticket_count / ceil(wave_ticket_count / threshold))
    for i, range in enumerate(chunks(wave_tickets, shard_size)):
        spawn edm-qc-auditor(shard=i+1, tickets=range) -> writes qc/qc-shard-pass-w{wave_num:02d}-{i+1:02d}.md
# CA-515: the wave number is now part of the filename, not just the shard ordinal -- with an
# ordinal-only name, wave 2's single-shard pass (ticket_count <= threshold) reuses the exact
# filename wave 1's did (qc-shard-pass-01.md) and silently overwrites wave 1's PASS/FAIL verdicts,
# which (like CA-473's hook-vs-threshold collision) are never persisted anywhere else. Both
# branches still key on {shard ordinal} within a wave, never on a ticket number, so they still
# cannot collide with the hook's qc-shard-impl-{lowest-ticket:02d}.md namespace (CA-473); the
# `qc-shard-pass-*.md` glob below already matches the wave-prefixed name unchanged, so the merge
# step needs no widening.
# either way, exactly one merge step owns qc-summary.md, re-run after every wave drains so it
# always reflects every shard written by any wave so far:
merge all qc-shard-impl-*.md AND all qc-shard-pass-*.md files into qc/qc-summary.md
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
  downgraded to FAIL and remediated). The mandatory closing sequence is two commands, in order:
  ```bash
  /edm:verify-runtime <PREFIX>
  edm-state phase-complete <PREFIX> 6
  ```
  `phase-complete 6` refuses while an open PARTIAL remains, so this ordering is enforced, not
  merely requested. **Phase 6 is closed by the orchestrator**, not by this skill, when running
  through `/edm:orchestrator` -- the dispatcher's Phase 6 entry invokes `/edm:verify-runtime` via
  the Skill tool and then calls `phase-complete 6` (EDMV3-T38/T50). This skill states the same
  two-command sequence above only for the standalone/direct-invocation path, where the user (not
  the orchestrator) runs both commands itself.
- [ ] Code compiles, existing tests pass
- [ ] No TODO or FIXME markers remain
- [ ] Execution report written to `exec-report.md` (Step 6)
- [ ] Documentation updated
- [ ] All files committed on the feature branch
- [ ] `/edm:test {PREFIX}` run and all coverage targets met, or consciously skipped
  (`test_layer_skipped` recorded in state per Step 7 above)
- [ ] Code audit converged: the Convergence gate (`/edm:code-audit`'s own Step 10) recorded explicit
  Approve -- `edm-state get {PREFIX} | jq -r '.code_audit_converged'` prints `true` (or the
  initiative is convergence-exempt: `mode` is `prototype`, or `lifecycle_mode` is `fast-track` or
  `fix-pack`)

**On-demand artifacts at completion** -- write these when applicable, not always:
- `ROLLBACK.md` -- if this initiative changes production behavior or involves an irreversible
  migration. Minimum content: trigger conditions, ordered revert steps,
  verification-after-rollback, and owner/contact.
- `post-deploy/verification.md` -- post-deploy smoke-test / verification report (after the deploy,
  not before). Also the canonical `/edm:verify-runtime` closure output (Step 8 above).
- `post-deploy/analysis/` -- analysis-input documents (rate-limit-analysis.md, source-triage.md,
  cost-analysis.md) if relevant. All paths are state-derived; a fresh initiative has none of these.

After declaration, recommend the user run `/edm:code-audit <PREFIX>` for the 11-lens exhaustive audit
before merging. The audit is keyed off `mode`, never off `implementation_mode` (which selects
Red-Green-Refactor for this phase and governs nothing else): it is mandatory for `standard`,
`mini-srd`, `iac` and `data-ml`, and `prototype` runs no audit round at all. Independently of
`mode`, a `lifecycle_mode` of `fast-track` or `fix-pack` also runs no audit round. For all three
exemptions `edm-state archive` proceeds with a warning and records
`archive_exemptions: ["CONVERGENCE_NOT_REQUIRED"]`. Once converged, run
`edm-state archive <PREFIX>` to close the initiative -- blocked by `code_audit_converged=false`
only on a v2+ initiative that none of those three exemptions covers.

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

This phase presents no HITL gate of its own -- it is the terminal phase, closed by the "Declare
Done" checklist above and `edm-state archive`, not by an `AskUserQuestion` gate. The Convergence and
Remediation gates that run within it are presented by `/edm:code-audit` per
`skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"`.
