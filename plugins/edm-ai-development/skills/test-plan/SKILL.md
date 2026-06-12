---
name: test-plan
description: Preview mode for EDM testing -- detects the project stack and maps ticket ACs to test layers without writing any tests. Produces SRD/{PREFIX}/test-plan.md. Invoke before /edm:test to review scope, or run it standalone when you need the coverage map but aren't ready to write tests yet.
disable-model-invocation: true
model: opus
effort: high
argument-hint: <PREFIX> [scope]
allowed-tools: Read, Write, Edit, Bash(edm-state *), Glob, Grep, TodoWrite
---

# EDM Test Plan -- Stack Detection & Coverage Mapping

**Arguments**: $ARGUMENTS

This skill runs the planning phase of the EDM testing layer **without writing any tests**. It produces a comprehensive `test-plan.md` that maps every ticket AC to a test layer and identifies infrastructure gaps.

Use this skill when:
- You want to review test scope before committing time to writing tests.
- You want to share the coverage plan with a teammate before implementation.
- You need to identify scaffold prerequisites (missing frameworks, config files) before running `/edm:test`.

## Operational Orchestration

### Step 1 -- Verify prerequisites

1. Parse `{PREFIX}` from `$ARGUMENTS`. If missing, print usage and exit.
2. Verify `${user_config.srd_root}/{PREFIX}/` exists. If not, print:
   > *"No initiative directory at {srd_root}/{PREFIX}/. Run /edm:plan {PREFIX} first."*
3. Verify the ticket pack exists at `${user_config.srd_root}/{PREFIX}/${user_config.ticket_pack_dirname}/epics/`. If not, print:
   > *"Ticket pack not found. Run /edm:tickets {PREFIX} and /edm:audit-tickets {PREFIX} first."*
4. Parse optional `[scope]` argument (default: "all").

### Step 2 -- Spawn edm-test-planner

Spawn the `edm-test-planner` agent with:

```
PREFIX: {PREFIX}
scope: {scope arg}
srd_root: ${user_config.srd_root}
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

Wait for it to complete.

### Step 3 -- Summarize and present

After the planner completes, present to the user:
- Stack detected per epic (or single stack if uniform), layers active/N/A.
- Whether per-epic plans were written (multi-stack) or a single plan (single-stack).
- Infrastructure gaps (if any) with install commands.
- Total tickets and AC in scope.
- Locations of the generated plan file(s):
  - Single-stack: `${user_config.srd_root}/{PREFIX}/test-plan.md`
  - Multi-stack: `${user_config.srd_root}/{PREFIX}/test-plan.md` (index) plus
    `${user_config.srd_root}/{PREFIX}/test-plan-{epic}.md` for each epic.
- Suggested next steps:
  - **No gaps**: "Run `/edm:test {PREFIX}` to write tests based on this plan."
  - **Gaps found**: "Run `/edm:test {PREFIX}` -- it will scaffold the missing frameworks first, then write tests. Or run `/edm:test {PREFIX}` with `--skip-scaffold` to write tests for layers that are already set up."

### Artifacts produced

- **Single-stack**: `${user_config.srd_root}/{PREFIX}/test-plan.md`
- **Multi-stack**: `${user_config.srd_root}/{PREFIX}/test-plan.md` (index) plus
  `${user_config.srd_root}/{PREFIX}/test-plan-{epic-slug}.md` per epic

All files are source-controlled alongside other initiative artifacts.

### See also

- `/edm:test <PREFIX>` -- full test orchestration (plan + scaffold + write + audit)
- `/edm:test-coverage <PREFIX>` -- re-run coverage audit against existing tests (no writing)
