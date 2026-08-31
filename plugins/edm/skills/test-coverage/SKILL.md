---
name: test-coverage
description: Re-run the coverage audit against the current test suite without writing any new tests. Useful after manually adding tests or after /edm:test --fill-gaps to verify gaps were addressed. Reads the existing test-plan.md and produces an updated test-coverage.md in the initiative directory.
user-invocable: true
model: sonnet
effort: high
argument-hint: <PREFIX>
allowed-tools: Read, Write, Bash(edm-state *), Glob, Grep, Task, TodoWrite
---

# EDM Test Coverage -- Re-Audit Existing Tests

**Arguments**: $ARGUMENTS

This skill runs the coverage audit **without spawning any test-writer agents**. It assumes tests already exist and simply measures what's there against the configured targets.

Use this skill when:
- You've manually added tests after a previous `/edm:test` run and want to verify the gaps closed.
- You want a fresh coverage snapshot after refactoring tests.
- A coverage regression was reported and you want to investigate it.
- You already ran `/edm:test` and want to re-run just the audit step cheaply.

## Operational Orchestration

### Step 1 -- Verify prerequisites

1. Parse `{PREFIX}` from `$ARGUMENTS`.
2. Resolve the initiative directory from state (handles both flat and product-scoped layouts):
   ```bash
   INIT_DIR="$(edm-state resolve-dir <PREFIX>)"
   ```
3. Verify `${INIT_DIR}/test-plan.md` exists. If not, print:
   > *"test-plan.md not found. Run /edm:test-plan {PREFIX} first to generate the coverage map."*
4. Verify the ticket pack exists.

### Step 2 -- Spawn edm-test-coverage-auditor

Spawn the `edm-test-coverage-auditor` agent with:

```
PREFIX: {PREFIX}
INIT_DIR: ${INIT_DIR}
ticket_pack_dirname: ${user_config.ticket_pack_dirname}
coverage_target_unit_pct: ${user_config.coverage_target_unit_pct}
coverage_target_component_pct: ${user_config.coverage_target_component_pct}
coverage_target_integration_pct: ${user_config.coverage_target_integration_pct}
coverage_target_e2e_critical_paths_pct: ${user_config.coverage_target_e2e_critical_paths_pct}
```

Wait for it to complete.

### Step 2a -- Verify each coverage report's completion sentinel

Before any downstream consumption of the auditor's output -- before presenting results, before
treating a number as satisfying the Phase 6 "coverage targets met" checklist item -- run
`edm-check-verifier-sentinel TEST-COVERAGE <file>` (VERIF-T03/T07) against **every** coverage file
the auditor may have written:

```bash
edm-check-verifier-sentinel TEST-COVERAGE "${INIT_DIR}/test-coverage.md"
```

For a multi-stack run, also run it against **every** `${INIT_DIR}/test-coverage-{epic}.md` that
currently exists (glob for the files present -- an epic with an entirely N/A layer set produces no
file at all, and absence there is authoritative, not a refusal):

```bash
for f in "${INIT_DIR}"/test-coverage-*.md; do
  [ -e "$f" ] || continue
  edm-check-verifier-sentinel TEST-COVERAGE "$f"
done
```

On refusal (exit 2 -- missing/misplaced sentinel, or a short `audited=` count) for any file:
- Report the failing path and the reason to the user.
- Treat any coverage `edm-state record-test-coverage` may already have written for that file's
  layer(s)/epic as **unverified** -- do not present it, and do not count it toward the Phase 6
  "coverage targets met" checklist item. A refused coverage report must never be used to satisfy
  that checklist item.
- Re-dispatch `edm-test-coverage-auditor` (Step 2) -- a fresh run overwrites both the report file
  and, once it completes with a valid sentinel, the corresponding state entries with newly
  measured values.

Only once every coverage file present passes this check does Step 3 proceed.

### Step 3 -- Present results, then update the pattern library

After the auditor completes and every report has passed its sentinel check, present to the user:
- Updated coverage by layer -- or by epic and layer for multi-stack initiatives (target vs. actual).
- Stale per-epic coverage files removed (if any).
- Finding counts (P0, P1, P2) overall and per epic.
- Whether Phase 6 can be declared complete.
- Locations of the updated report(s):
  - Single-stack: `${INIT_DIR}/test-coverage.md`
  - Multi-stack: `${INIT_DIR}/test-coverage.md` (summary) plus
    `${INIT_DIR}/test-coverage-{epic}.md` per epic.
- If P0 or P1 findings remain: suggest running `/edm:test {PREFIX} --fill-gaps`.

Then run `edm-state update-patterns <PREFIX> test-coverage` to append any novel findings from
this round's `test-coverage.md` into the pattern library.

### Artifacts produced

- **Single-stack**: `${INIT_DIR}/test-coverage.md`
- **Multi-stack**: `${INIT_DIR}/test-coverage.md` (summary) plus
  `${INIT_DIR}/test-coverage-{epic-slug}.md` per epic

All files overwrite the previous version with fresh measurements. Stale per-epic files whose
epics no longer appear in the current plan are removed before measuring.

### See also

- `/edm:test <PREFIX>` -- full pipeline including test writing
- `/edm:test-plan <PREFIX>` -- re-generate the plan (stack detection + AC mapping)
- `edm-state get-coverage <PREFIX>` -- quick coverage summary from state file
