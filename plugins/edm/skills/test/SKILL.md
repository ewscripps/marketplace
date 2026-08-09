---
name: test
description: Full-pipeline EDM test orchestration for an initiative -- plan, scaffold, write tests (unit, component, composable, integration, contract, E2E, a11y), run the suite, and audit coverage. Produces test-plan.md and test-coverage.md in the initiative directory. Run after Phase 6 implementation before declaring the initiative complete.
disable-model-invocation: true
model: opus
effort: max
argument-hint: <PREFIX> [--fill-gaps | --skip-scaffold]
allowed-tools: Read, Write, Edit, Bash(edm-state *), Glob, Grep, TodoWrite
---

# EDM Test -- Comprehensive Testing Pipeline

**Arguments**: $ARGUMENTS

This skill runs the complete EDM testing pipeline: detect stack -> scaffold missing infra -> plan coverage -> write tests across all applicable layers -> run the suite -> audit coverage -> record results.

Run this skill after Phase 6 implementation completes and before declaring the initiative done. It is the answer to "are we tested well enough to ship?"

Flags:
- `--fill-gaps` -- skip the planning and writing passes, jump straight to coverage audit, then spawn only the writers needed to fill ALL gaps (P0, P1, and P2) found in the existing `test-coverage.md`.
- `--skip-scaffold` -- skip the scaffold step; useful when you've already set up the test infra manually.

## Prerequisites

- Phase 6 implementation has produced working code (at minimum, the source files exist).
- Ticket pack exists at `${INIT_DIR}/${user_config.ticket_pack_dirname}/`.
- State shows `current_phase >= 6` (implementation started).

If Phase 6 hasn't started:
> *"Phase 6 hasn't started for {PREFIX}. Run /edm:implement first."*

## Operational Orchestration

### Step 1 -- Verify prerequisites

1. Parse `{PREFIX}` and optional flags from `$ARGUMENTS`.
2. Resolve the initiative directory from state (handles both flat and product-scoped layouts):
   ```bash
   INIT_DIR="$(edm-state resolve-dir <PREFIX>)"
   ```
3. Verify the ticket pack and phase state (phase >= 6) at `${INIT_DIR}`.
4. If `--fill-gaps`: skip to Step 5.

### Step 2 -- Spawn edm-test-planner

Spawn `edm-test-planner` with the full initiative context:

```
PREFIX: {PREFIX}
INIT_DIR: ${INIT_DIR}
srd_filename: ${user_config.srd_filename}
ticket_pack_dirname: ${user_config.ticket_pack_dirname}
coverage_target_unit_pct: ${user_config.coverage_target_unit_pct}
coverage_target_component_pct: ${user_config.coverage_target_component_pct}
coverage_target_integration_pct: ${user_config.coverage_target_integration_pct}
coverage_target_e2e_critical_paths_pct: ${user_config.coverage_target_e2e_critical_paths_pct}
test_framework_unit_override: ${user_config.test_framework_unit_override}
test_framework_component_override: ${user_config.test_framework_component_override}
test_framework_e2e_override: ${user_config.test_framework_e2e_override}
```

Wait for the planner to complete and `test-plan.md` to be written.

Present the plan summary to the user: active layers, infrastructure gaps, total AC in scope.
**Ask the user to confirm before proceeding** if there are infrastructure gaps or if the plan
identifies the initiative as Large (50+ tickets).

### Step 3 -- Scaffold missing infrastructure (unless --skip-scaffold)

If `test-plan.md` contains any "SCAFFOLD NEEDED" entries:

Spawn `edm-test-scaffold` with:
```
PREFIX: {PREFIX}
INIT_DIR: ${INIT_DIR}
```

Wait for scaffold to complete and user to confirm installs. The scaffold agent will ask the user
for each install -- do not bypass this.

### Step 4 -- Spawn specialist test writers in parallel

Read `test-plan.md` to determine which layers are active (non-N/A). For each active layer,
prepare the agent scope (files + AC from the "Writer Agent Task Assignments" section).

Spawn all active layers in a single parallel agent invocation:

```
[parallel if 2+ layers are active]
edm-test-unit       -> scope from test-plan.md "edm-test-unit" section
edm-test-component  -> scope from test-plan.md "edm-test-component" section
edm-test-composable -> scope from test-plan.md "edm-test-composable" section
edm-test-integration-> scope from test-plan.md "edm-test-integration" section
edm-test-contract   -> scope from test-plan.md "edm-test-contract" section
edm-test-e2e        -> scope from test-plan.md "edm-test-e2e" section
edm-test-a11y       -> scope from test-plan.md "edm-test-a11y" section
```

Only spawn agents for layers marked active. Skip N/A layers.

**Wait for ALL writers to complete before proceeding. Do NOT spawn `edm-test-coverage-auditor` in parallel with the writers -- it audits the tests that exist on disk at the moment it runs. If a writer is still producing tests when the auditor scans, those tests will not be seen and the auditor will report false gaps for work that is already being done.**

### Step 5 -- Run the full test suite

Run the full test command for each active layer:

```bash
{unit_test_command}         # e.g., pytest tests/unit/ or vitest run
{integration_test_command}  # e.g., pytest tests/integration/ or jest --testPathPattern=integration
{e2e_test_command}          # e.g., playwright test
```

If any layer fails:
- Print the failure output.
- Attempt to diagnose (is it a setup issue or a real test failure?).
- If the failure is in newly-written tests, spawn the relevant writer agent to fix it.
- If the failure is in pre-existing tests, note it as a P0 finding for the user to address.

Do not proceed to coverage audit if the unit or integration test suite fails (P0).

### Step 6 -- Spawn edm-test-coverage-auditor (sequential -- after Step 4 and Step 5 fully complete)

**Do not begin this step until Step 4 (all writers) and Step 5 (test suite run) have both finished.** The auditor measures what exists on disk right now -- running it while writers are still producing tests produces false gap reports.

Spawn `edm-test-coverage-auditor` with:
```
PREFIX: {PREFIX}
INIT_DIR: ${INIT_DIR}
```

Wait for it to complete and `test-coverage.md` to be written. Then run
`edm-state update-patterns <PREFIX> test-coverage` to append any novel findings from this run's
`test-coverage.md` into the pattern library.

### Step 7 -- Record results in state

```bash
edm-state record-tests-added {PREFIX} 6 unit {count_from_unit_writer_report}
edm-state record-tests-added {PREFIX} 6 component {count}
edm-state record-tests-added {PREFIX} 6 integration {count}
edm-state record-tests-added {PREFIX} 6 e2e {count}
# ... for each active layer

edm-state record-test-coverage {PREFIX} unit {pct_from_auditor}
edm-state record-test-coverage {PREFIX} integration {pct}
# ... for each measured layer
```

### Step 8 -- Report and declare

Present the final summary:

```
## EDM Test Results -- {PREFIX}

Layer        Target   Actual   Status    Tests Added
-----------  -------  -------  --------  -----------
unit         80%      84.2%    MEET      31
component    70%      72.1%    MEET      15
integration  60%      68.3%    MEET      12
e2e          100%     100%     MEET       4
a11y         N/A      --        N/A        --

Findings: 0 P0  |  0 P1  |  2 P2

P2 findings (remediate before convergence):
  - AUTH-T07 AC3 partially covered -- edge case for concurrent login not tested

Coverage report: ${INIT_DIR}/test-coverage.md
Test plan:       ${INIT_DIR}/test-plan.md
```

**If any findings remain (P0/P1/P2)**: "Testing is not fully complete. Re-run `/edm:test {PREFIX} --fill-gaps` to write tests for all remaining gaps."

**If no findings remain**: "Testing complete. Phase 6 may be declared done. The QC auditor (`edm-qc-auditor`) will verify the full initiative, including test coverage, as its final gate."

## --fill-gaps mode

When `--fill-gaps` is passed:
1. Verify `test-coverage.md` exists. If not, run the full pipeline from Step 2.
2. Read ALL findings (P0, P1, and P2) from `test-coverage.md`.
3. For each finding, determine the relevant test layer (unit, component, integration, e2e, a11y, contract).
4. Spawn only the writer agents needed to fill those specific gaps -- one agent per affected layer, scoped to only the files and AC identified in the findings.
5. Re-run coverage audit.
6. Report updated results.
