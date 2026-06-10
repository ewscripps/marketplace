# EDM Plugin Audit Findings - 2026-06-10

Scope reviewed:
- `plugins/edm-ai-development/`
- `SRD/EDMV2/`

Review type: read-only plugin/codebase audit plus targeted runtime probes.

## Executive Summary

The EDM plugin v2 surface is generally well structured. The marketplace entry points resolve, the helper scripts parse, the bundled smoke suites pass, and `claude plugin validate plugins/edm-ai-development` passes with one warning about root `CLAUDE.md` not being loaded as plugin runtime context.

The biggest issues are not broad architecture failures. They are mismatches between documented v2 behavior, runtime enforcement, and the EDMV2 artifact record. The most important defect is the compliance Gate 3.5 path: it is documented and tested by text-presence checks, but the state script cannot record gate `3.5`, and `gate-check implement` does not enforce it when `compliance_enabled=true`.

## Verification Performed

- `bash -n` over EDM helper scripts and smoke tests: clean.
- Bundled smoke suites: 199 checks passed, 0 failed.
  - `wave3-smoke.sh`: 18 passed.
  - `wave4a-smoke.sh`: 51 passed.
  - `wave4b-smoke.sh`: 97 passed.
  - `wave5-smoke.sh`: 33 passed.
- `claude plugin validate plugins/edm-ai-development`: passed with one warning that root `CLAUDE.md` is not loaded as project context.
- Direct Gate 3.5 probe: failed to record `3.5`; implementation gate check still passed with `compliance_enabled=true` after only Gate 3.
- `edm-lint-artifacts EDMV2`: found attribution/unicode violations in EDMV2 artifacts.

## Findings

### P1 - Gate 3.5 Is Documented But Not Runtime-Enforced

Evidence:
- `plugins/edm-ai-development/skills/orchestrator/SKILL.md` documents a compliance Gate 3.5 and instructs `edm-state approve-gate <PREFIX> 3.5`.
- `plugins/edm-ai-development/bin/edm-state` only accepts integer gate numbers in `cmd_approve_gate`.
- `plugins/edm-ai-development/bin/edm-state` maps `implement` gate checking to Gate 3 only.
- `plugins/edm-ai-development/bin/tests/wave4b-smoke.sh` verifies only that Gate 3.5 text exists, not that it can be recorded or enforced.

Runtime probe result:

```text
edm-state: approve-gate: gate-num must be numeric; got: 3.5
implement gate-check passed with compliance_enabled=true and no gate 3.5
```

Impact:
- Regulated/compliance initiatives can proceed to implementation without the documented compliance approval.
- The advertised `compliance_enabled` behavior is partly ceremonial.

Recommendation:
- Represent compliance approval explicitly. Options:
  - Allow gate IDs to be decimal/string values and update all gate rendering/counting logic.
  - Preferably add a dedicated `compliance_gate_approved` or `gate_3_5_approved` state field to avoid overloading numeric gates.
- Update `gate-check implement` to require the compliance marker when `compliance_enabled=true`.
- Add a behavioral smoke test that creates a compliance-enabled initiative, approves Gate 3 but not Gate 3.5, and verifies `/edm:implement` is blocked.

### P1 - EDMV2 Code-Audit Artifacts Contradict Current Implementation

Evidence:
- `SRD/EDMV2/code-audit/findings-ledger.md` still lists CA-001 through CA-004 as open P1 findings and says convergence was not reached.
- `SRD/EDMV2/code-audit/2026-06-09/REMEDIATION.md` also says four P1 findings remain open.
- `SRD/EDMV2/HANDOFF.md` and `.edm-state.json` say Round 2 remediation completed all 26 findings and verification passed.
- Current code and smoke tests confirm several of the old open findings are no longer true, including migrate-path backup/path traversal regression coverage.

Impact:
- A reviewer cannot tell whether v2 is converged.
- The artifact record undermines the methodology's central claim that source-controlled audit artifacts are authoritative.

Recommendation:
- Run a final full code-audit round or explicitly update the findings ledger with resolved status and verification evidence.
- Record convergence only after the ledger and state agree.
- Treat this as release-blocking for v2.0.0, because it is a process-integrity defect rather than a cosmetic documentation issue.

### P1 - EDMV2 State Is Stale Relative To The Ticket Pack And V2 Schema

Evidence:
- `SRD/EDMV2/.edm-state.json` has `srd_version: "0.0.0"`.
- `SRD/EDMV2/tickets/README.md` says it was generated from `srd.md v1.0.7`.
- The state file lacks newer v2 fields such as `mode`, `compliance_enabled`, `code_audit_converged`, `coverage_by_epic`, `parent_prefix`, and `related_prefixes`.
- `audit_rounds` is stored as a stringified object instead of a JSON object.

Impact:
- Version-drift checks are weakened because the state version does not match the artifacts.
- Backward-compatibility paths may be under-tested against the actual EDMV2 state shape.
- Archive/convergence behavior may not get the intended v2 signal.

Recommendation:
- Add an `edm-state normalize` or `edm-state migrate-schema` command that safely upgrades legacy/additive fields in place.
- Include `SRD/EDMV2/.edm-state.json` as a regression fixture.
- Run `edm-state srd-version EDMV2 1.0.7` as part of artifact cleanup after confirming the SRD version is still correct.
- Ensure `audit_rounds` becomes a JSON object before invoking any commands that increment audit rounds.

### P1/P2 - EDMV2 Artifacts Violate The Plugin's Own Artifact-Lint Policy

Evidence:
- `edm-lint-artifacts EDMV2` reports attribution and unicode violations.
- Examples include `SRD/EDMV2/planning.md`, `SRD/EDMV2/HANDOFF.md`, `SRD/EDMV2/audit-srd.md`, `SRD/EDMV2/srd.md`, and ticket epic files.
- Some violations are negative examples or requirement text describing banned content, but the linter does not distinguish examples from generated output.

Impact:
- The plugin can block commits for EDMV2 artifacts that document the exact policy it enforces.
- If the policy is meant to apply to all committed EDM artifacts, EDMV2 currently fails its own standard.

Recommendation:
- Decide whether negative examples are allowed in committed EDM artifacts.
- If no, sanitize the artifacts to use neutral placeholders such as `[forbidden attribution phrase]` and ASCII-only punctuation.
- If yes, update `edm-lint-artifacts` to ignore explicitly marked examples or fenced test fixtures, then add tests proving real emitted content is still blocked.

### P2 - Pre-Commit Artifact Lint Hook Only Checks One Active Initiative

Evidence:
- `plugins/edm-ai-development/hooks/hooks.json` selects the first active prefix from `edm-state active-initiatives` and runs `edm-lint-artifacts` only on that prefix.

Impact:
- In repos with multiple active initiatives, violations in later active initiatives are missed.
- Unrelated commits can be blocked by the first active initiative even when the staged changes belong elsewhere.

Recommendation:
- Prefer linting touched/staged SRD paths by deriving prefixes from `git diff --cached --name-only`.
- If staged-file detection is not available in the hook context, loop over all active initiatives and report all failing prefixes.

### P2 - Duplicate Plugin Manifests Remain A Drift Risk

Evidence:
- `plugins/edm-ai-development/plugin.json` and `plugins/edm-ai-development/.claude-plugin/plugin.json` are byte-identical today.
- The SRD/QC artifacts indicate the root duplicate was supposed to be removed in the staging cutover path.
- `claude plugin validate` reads the `.claude-plugin/plugin.json` manifest.

Impact:
- The current state is not broken, but future edits can drift again.
- Maintaining two identical regular files adds unnecessary review burden.

Recommendation:
- Keep `.claude-plugin/plugin.json` as the authoritative manifest.
- Remove the root duplicate, or generate it from the canonical manifest in a documented release step.
- If both must remain, add a smoke check that fails when they differ.

### P2 - Root CLAUDE.md Is Not Runtime Plugin Context

Evidence:
- `claude plugin validate plugins/edm-ai-development` passes but warns that root `CLAUDE.md` is not loaded as project context.

Impact:
- Contributor documentation in root `CLAUDE.md` is useful, but runtime-critical instructions must also live in skills, agents, hooks, or scripts.

Recommendation:
- Keep root `CLAUDE.md` as contributor documentation.
- Audit it for any runtime-only expectations that are not duplicated in the relevant skill/agent files.

## Recommended Fix Order

1. Fix Gate 3.5 recording and enforcement, then add a behavioral smoke test.
2. Normalize `SRD/EDMV2/.edm-state.json` and align `srd_version` with the current SRD/ticket pack.
3. Reconcile the Round 2 code-audit ledger/remediation artifacts with current code, then record final convergence.
4. Decide and implement the artifact-lint policy for negative examples in committed artifacts.
5. Improve the pre-commit lint hook for multi-initiative repos.
6. Remove or guard the duplicate root plugin manifest.
7. Ensure runtime-critical root `CLAUDE.md` conventions are mirrored in skills/agents.

## Positive Notes

- The current helper scripts pass syntax checks.
- The bundled smoke tests are broad and fast enough to run regularly.
- `edm-state` has strong work in place around locking, path traversal guards, migration backup behavior, and schema additive defaults.
- The v2 plugin surface is coherent; the remaining risk is mostly convergence between docs, state, and runtime gates.
