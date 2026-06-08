---
name: test-coverage
description: Re-run the coverage audit against the current test suite without writing any new tests. Useful after manually adding tests or after /edm:test --fill-gaps to verify gaps were addressed. Reads the existing test-plan.md and produces an updated SRD/{PREFIX}/test-coverage.md.
disable-model-invocation: true
model: sonnet
effort: high
argument-hint: <PREFIX>
allowed-tools: Read, Write, Bash, Glob, Grep, TodoWrite
---

# EDM Test Coverage — Re-Audit Existing Tests

**Arguments**: $ARGUMENTS

This skill runs the coverage audit **without spawning any test-writer agents**. It assumes tests already exist and simply measures what's there against the configured targets.

Use this skill when:
- You've manually added tests after a previous `/edm:test` run and want to verify the gaps closed.
- You want a fresh coverage snapshot after refactoring tests.
- The CI pipeline flagged coverage regression and you want to investigate locally.
- You already ran `/edm:test` and want to re-run just the audit step cheaply.

## Operational Orchestration

### Step 1 — Verify prerequisites

1. Parse `{PREFIX}` from `$ARGUMENTS`.
2. Verify `${user_config.srd_root}/{PREFIX}/test-plan.md` exists. If not, print:
   > *"test-plan.md not found. Run /edm:test-plan {PREFIX} first to generate the coverage map."*
3. Verify the ticket pack exists.

### Step 2 — Spawn edm-test-coverage-auditor

Spawn the `edm-test-coverage-auditor` agent with:

```
PREFIX: {PREFIX}
srd_root: ${user_config.srd_root}
ticket_pack_dirname: ${user_config.ticket_pack_dirname}
coverage_target_unit_pct: ${user_config.coverage_target_unit_pct}
coverage_target_component_pct: ${user_config.coverage_target_component_pct}
coverage_target_integration_pct: ${user_config.coverage_target_integration_pct}
coverage_target_e2e_critical_paths_pct: ${user_config.coverage_target_e2e_critical_paths_pct}
```

Wait for it to complete.

### Step 3 — Present results

After the auditor completes, present to the user:
- Updated coverage by layer (target vs. actual).
- Finding counts (P0, P1, P2).
- Whether Phase 6 can be declared complete.
- Location of the report: `${user_config.srd_root}/{PREFIX}/test-coverage.md`.
- If P0 or P1 findings remain: suggest running `/edm:test {PREFIX} --fill-gaps`.

### Artifact produced

`${user_config.srd_root}/{PREFIX}/test-coverage.md` — overwrites the previous version with fresh measurements.

### See also

- `/edm:test <PREFIX>` — full pipeline including test writing
- `/edm:test-plan <PREFIX>` — re-generate the plan (stack detection + AC mapping)
- `edm-state get-coverage <PREFIX>` — quick coverage summary from state file
