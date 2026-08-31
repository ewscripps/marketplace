# Epic 1 — WS-A: Correctness and Consistency Defects

Generated From: srd.md v1.0.7

This epic covers the 18 WS-A correctness/consistency defects (G1-G18), tracked as SRD requirements EDMV2-01 through EDMV2-23. Each ticket fixes a concrete, cited defect in the existing plugin so that every advertised v1.x feature behaves as documented.

All work in this epic is performed in the staging copy `plugins/edm-ai-development-staging/` per constraint C-5 / EDMV2-109. File paths below are written relative to the plugin root and apply to the staging copy during Phase 6. The live plugin `plugins/edm-ai-development/` is never edited until the single cutover step at completion.

Size legend: XS (< 1h, 1pt) / S (1-3h, 2-3pt) / M (3-8h, 5pt) / L (8-16h, 8-13pt). No XL — decompose.

Cross-cutting requirements for every ticket in this epic:
- All changes are made in the staging copy only; `git diff plugins/edm-ai-development/` must remain empty during Phase 6.
- Any generated/edited artifact text must be ASCII-only and free of AI-attribution trailers (C-1).
- After the change, `claude plugin validate` must still pass (EDMV2-101).
- Bash edits to `bin/` scripts must remain POSIX-compatible bash (C-3) and must not break existing-initiative behavior (C-4).

---

## EDMV2-T01: Grant the Write tool to edm-test-coverage-auditor

- **Workstream**: WS-A
- **SRD Requirements**: EDMV2-01
- **Priority**: Must
- **Size**: XS
- **Target Components**:
  - `agents/edm-test-coverage-auditor.md:8` — `tools:` line currently `Read, Bash, Glob, Grep, TodoWrite`; add `Write` so it reads `Read, Write, Bash, Glob, Grep, TodoWrite`.
  - `agents/edm-test-coverage-auditor.md:9` — `disallowedTools:` line currently `Write, Edit, NotebookEdit`; remove `Write`, leaving `Edit, NotebookEdit`.
- **Dependencies**: none
- **Acceptance Criteria**:
  - **AC-1:** The `tools:` frontmatter line at `agents/edm-test-coverage-auditor.md:8` includes the literal token `Write`.
  - **AC-2:** The `disallowedTools:` frontmatter line at `agents/edm-test-coverage-auditor.md:9` does NOT contain `Write` (it retains `Edit` and `NotebookEdit`).
  - **AC-3:** `Write` appears in `tools` and is absent from `disallowedTools` — the two lists do not both reference `Write`.
  - **AC-4:** No other frontmatter field (`name`, `description`, `model`, `effort`, `maxTurns`, `color`) is altered by this change.
  - **AC-5:** The agent body still documents its output target as `SRD/{PREFIX}/test-coverage.md` (no contradiction introduced).
  - **AC-6:** In a sandbox run (`claude --plugin-dir`), spawning `edm-test-coverage-auditor` and asking it to write `SRD/{PREFIX}/test-coverage.md` completes without a permission-denied error.
  - **AC-7:** `claude plugin validate` passes on the staging plugin after the edit.
- **Verification**: Inspect `agents/edm-test-coverage-auditor.md:8-9`; run a sandbox spawn of the agent and confirm `SRD/{PREFIX}/test-coverage.md` is written without a permission error. QC PASS when AC-1 through AC-7 hold.

---

## EDMV2-T02: Add a documented coverage-auditor write-permission regression check

- **Workstream**: WS-A
- **SRD Requirements**: EDMV2-02
- **Priority**: Must
- **Size**: S
- **Target Components**:
  - New: `SRD/EDMV2__enhance-edm-plugin/test-coverage.md` verification-notes section (or the initiative's testing-layer verification notes) — document the end-to-end sandbox check that the coverage auditor produces `test-coverage.md`.
  - Reference fixture: a minimal sandbox initiative directory plus the spawn command used to exercise `edm-test-coverage-auditor`.
- **Dependencies**: EDMV2-T01
- **Acceptance Criteria**:
  - **AC-1:** A written, repeatable check exists that spawns `edm-test-coverage-auditor` end-to-end and asserts `SRD/{PREFIX}/test-coverage.md` is produced.
  - **AC-2:** The check is recorded in the testing layer's verification notes with the exact command(s) to run and the expected artifact path.
  - **AC-3:** Running the check against the EDMV2-T01-fixed agent passes (the artifact is produced, no permission error).
  - **AC-4:** A negative control is documented: re-adding `Write` to `disallowedTools` (or removing it from `tools`) causes the check to fail with a permission error, proving the check actually guards the regression.
  - **AC-5:** The check requires no new external dependency beyond what C-2 allows (`claude plugin validate`, sandbox run, bash).
  - **AC-6:** The verification note states the date and plugin version under which the check last passed.
- **Verification**: Run the documented check; confirm PASS with the fix in place and FAIL with `Write` removed again. QC PASS when both the positive and negative controls behave as documented.

---

## EDMV2-T03: Reconcile /edm:metrics skill claims with metrics-report implementation

- **Workstream**: WS-A
- **SRD Requirements**: EDMV2-03
- **Priority**: Must
- **Size**: S
- **Target Components**:
  - `skills/metrics/SKILL.md:33` — remove the "Comparison column against the Phase Timing Guidelines" claim (single-initiative mode), which `cmd_metrics_report` does not compute.
  - `skills/metrics/SKILL.md:34` — remove the "Highlights any phase that ran > 1.5x the expected duration" claim (not computed).
  - `skills/metrics/SKILL.md:31` — keep the per-gate review-time bullet only if EDMV2-T04 lands; otherwise remove it.
  - `skills/metrics/SKILL.md:43` — remove the "Mean / median / p95 per phase" p95 claim (aggregate mode computes none of these in `cmd_metrics_report` lines 522-543).
  - `skills/metrics/SKILL.md:44` — remove "Top 3 bottleneck phases" (not computed).
  - `skills/metrics/SKILL.md:45` — remove "Initiatives where total gate-review time exceeded total execution time" (not computed).
  - `skills/metrics/SKILL.md:64` — reconcile the `gate_review_seconds` interpretation note with the EDMV2-T04 decision.
- **Dependencies**: EDMV2-T04 (decision must be applied before this check; T04 may land or be deferred — see AC-2)
- **Acceptance Criteria**:
  - **AC-1:** Every metric named anywhere in `skills/metrics/SKILL.md` maps to a code path actually present in `cmd_metrics_report` (`bin/edm-state:518-595+`).
  - **AC-2:** If EDMV2-T04 lands, `gate_review_seconds` references remain in the skill text and are computed; if EDMV2-T04 is deferred, all `gate_review_seconds` references (including line 31 and the line 64 interpretation note) are removed.
  - **AC-3:** The p95 claim (line 43) is removed; no remaining text advertises p95.
  - **AC-4:** The bottleneck-highlighting claims (lines 34, 44) are removed; no remaining text advertises bottleneck detection.
  - **AC-5:** The guideline-comparison claim (line 33) and the gate-review-time-vs-execution-time claim (line 45) are removed; no remaining text advertises guideline comparison.
  - **AC-6:** The Mode 1 / Mode 2 / Mode 3 output descriptions describe only columns and lines the implementation actually prints.
  - **AC-7:** `grep -n "p95\|bottleneck\|Comparison column\|exceeded total execution"` over `skills/metrics/SKILL.md` returns nothing.
  - **AC-8:** No metric is silently added to `bin/edm-state` in this ticket — implementation of metrics is scoped to EDMV2-T04 only.
- **Verification**: Cross-walk every metric noun in `skills/metrics/SKILL.md` against `cmd_metrics_report`; confirm a 1:1 mapping with no advertised-but-uncomputed metric. QC PASS when AC-1 through AC-8 hold and the EDMV2-T04 decision is consistently applied.

---

## EDMV2-T04: Implement gate_review_seconds in metrics-report

- **Workstream**: WS-A
- **SRD Requirements**: EDMV2-04
- **Priority**: Should
- **Size**: M
- **Target Components**:
  - `bin/edm-state:518-595` (`cmd_metrics_report`, single-initiative `*)` branch) — compute per-gate `gate_review_seconds` as the interval between the gated phase's `phase-complete` timestamp and that gate's `approved_at` in `gates_approved`.
  - `bin/edm-state` `cmd_phase_complete` / `phase_durations` schema — ensure a phase-complete timestamp is readable for the gated phase (Gate 1 ↔ phase 1, Gate 2 ↔ phase 3, Gate 3 ↔ phase 5).
  - Single-initiative report output block (`bin/edm-state:580-595`) — render a per-gate review-seconds line.
- **Dependencies**: none
- **Acceptance Criteria**:
  - **AC-1:** `edm-state metrics-report <PREFIX>` prints a per-gate `gate_review_seconds` value for each approved gate present in `gates_approved`.
  - **AC-2:** `gate_review_seconds` for gate G equals `approved_at(G) - phase_complete(gated_phase(G))` in whole seconds, where gate 1↔phase 1, gate 2↔phase 3, gate 3↔phase 5.
  - **AC-3:** Given a fixture state file with known timestamps (phase-3 complete at T, gate 2 approved at T+3600), the report shows `gate_review_seconds = 3600` for gate 2.
  - **AC-4:** A gate that has no `approved_at` (not yet approved) is rendered as `n/a` or omitted, not as a negative or garbage value.
  - **AC-5:** Missing or malformed timestamps do not crash the command — it degrades to `n/a` for the affected gate and still prints the rest of the report.
  - **AC-6:** The change is additive: existing state files without the new computation still produce a valid report (backward-compatible, C-4).
  - **AC-7:** The code remains POSIX-compatible bash and uses `jq` for JSON parsing (C-3); no new dependency is introduced.
  - **AC-8:** A bash unit check exercises AC-3 and AC-4 against fixture state files.
- **Verification**: Run `edm-state metrics-report <PREFIX>` against a fixture with known gate/phase timestamps; assert the printed `gate_review_seconds` matches the hand-computed interval. QC PASS when the unit check covering AC-3/AC-4 passes.

---

## EDMV2-T05: Unify the Phase-1 planning template across plan and orchestrator skills

- **Workstream**: WS-A
- **SRD Requirements**: EDMV2-05
- **Priority**: Must
- **Size**: M
- **Target Components**:
  - `skills/plan/SKILL.md:56-86` — the planning template currently has `## Go/No-Go Decision` and `## Riskiest Assumptions` but lacks `## Open Questions` and `## Decisions Made`.
  - `skills/orchestrator/SKILL.md:103-138` — the planning template has `## Open Questions` (line 131) and `## Decisions Made` (line 136) but lacks `## Go/No-Go` and `## Riskiest Assumptions`.
  - Both templates must converge on one canonical set of section headings including all four: `## Go/No-Go`, `## Riskiest Assumptions`, `## Open Questions`, `## Decisions Made`.
  - `bin/edm-state:719-720` — the `## Decisions Made` heading the unified template uses must match exactly what the `awk` parser in `write_handoff_internal` keys on (`/^## Decisions Made/`).
- **Dependencies**: none
- **Acceptance Criteria**:
  - **AC-1:** Both `skills/plan/SKILL.md` and `skills/orchestrator/SKILL.md` contain a planning template with identical section headings.
  - **AC-2:** Both templates include all four headings exactly: `## Go/No-Go`, `## Riskiest Assumptions`, `## Open Questions`, `## Decisions Made`.
  - **AC-3:** The `## Decisions Made` heading string in both templates is byte-identical to the pattern the parser at `bin/edm-state:720` matches (`^## Decisions Made`).
  - **AC-4:** The `## Open Questions` heading string in both templates matches the heading the orchestrator's interactive resolution step (`skills/orchestrator/SKILL.md:147,158`) reads and edits.
  - **AC-5:** A diff of the two templates restricted to `^## ` heading lines is empty.
  - **AC-6:** A `planning.md` produced from either template, with at least one recorded decision, yields a non-empty Decisions Made block when `edm-state write-handoff` runs (no empty-fallback placeholder).
  - **AC-7:** The existing semantic intent of each skill is preserved (plan still describes Go/No-Go rationale; orchestrator still describes the `[DECISION:]`/`[OPEN]` tagging convention).
  - **AC-8:** No requirement-ID or unrelated section in either skill is removed by the unification.
- **Verification**: `diff <(grep '^## ' plan-template) <(grep '^## ' orchestrator-template)` is empty; produce a `planning.md` from each and confirm `write-handoff` extracts the Decisions Made block. QC PASS when AC-1 through AC-8 hold.

---

## EDMV2-T06: Harden write_handoff_internal Decisions-Made parsing for the unified template

- **Workstream**: WS-A
- **SRD Requirements**: EDMV2-06
- **Priority**: Must
- **Size**: S
- **Target Components**:
  - `bin/edm-state:717-723` — the `awk '/^## Decisions Made/{p=1;next} p && /^## /{p=0} p{print}'` extraction plus the `[[ -n "$decisions" ]] || decisions="_(none...)_"` fallback in `write_handoff_internal`.
  - Confirm robustness against both the `plan` skill output and the orchestrator output (whitespace, trailing content, list markers).
- **Dependencies**: EDMV2-T05
- **Acceptance Criteria**:
  - **AC-1:** A `planning.md` produced by the `plan` skill with a populated `## Decisions Made` section yields those decisions verbatim in `HANDOFF.md` under `## Key Decisions Made`.
  - **AC-2:** A `planning.md` produced by the orchestrator with a populated `## Decisions Made` section yields those decisions verbatim in `HANDOFF.md`.
  - **AC-3:** The empty-fallback placeholder (`_(none recorded yet ...)_`) appears ONLY when the `## Decisions Made` section is genuinely empty, not when decisions are present.
  - **AC-4:** The parser correctly stops at the next `## ` heading and does not bleed content from a following section into the decisions block.
  - **AC-5:** Decision lines that begin with `- ` (list markers) are preserved, not stripped.
  - **AC-6:** A `planning.md` with `## Decisions Made` as the final section (no trailing `## `) is still parsed to end-of-file correctly.
  - **AC-7:** Bash unit checks cover AC-1 through AC-6 using both-skill fixture `planning.md` files; the change remains POSIX bash.
- **Verification**: Run `edm-state write-handoff <PREFIX>` against fixtures from both skills and inspect `HANDOFF.md`; confirm decisions appear and the placeholder is absent when decisions exist. QC PASS when the unit checks pass.

---

## EDMV2-T07: Remove or fulfill the CHANGELOG example-block claim

- **Workstream**: WS-A
- **SRD Requirements**: EDMV2-07
- **Priority**: Must
- **Size**: S
- **Target Components**:
  - `CHANGELOG.md:154` — the claim "All agents have proper `<example>` blocks in their `description` fields per the canonical spec." This is currently false: `grep -L '<example>' agents/*.md` returns all 30 agents (zero contain `<example>`).
  - Default resolution: correct the CHANGELOG to remove the false claim (lower effort than authoring 30 example blocks). If the team elects to fulfill instead, every `agents/*.md` gains an `<example>` block.
- **Dependencies**: none
- **Acceptance Criteria**:
  - **AC-1:** The post-change state is internally consistent: either every `agents/*.md` contains an `<example>` block, OR no committed text claims they do.
  - **AC-2:** If the claim is removed: `grep -ri 'example.*block' CHANGELOG.md` returns no surviving sentence asserting all agents contain `<example>` blocks.
  - **AC-3:** If the claim is removed: the surrounding CHANGELOG bullet remains grammatical and the 1.0.0 entry still reads coherently.
  - **AC-4:** If the claim is fulfilled instead: `grep -L '<example>' agents/*.md` returns no files (every agent has the block).
  - **AC-5:** The chosen resolution path is recorded in the EDMV2 decision ledger / commit message so the auditor knows which branch was taken.
  - **AC-6:** No other CHANGELOG entry's factual content is altered.
- **Verification**: Run `grep -L '<example>' agents/*.md`; if it returns files, then `grep -i '<example>' CHANGELOG.md` must return nothing. QC PASS when the claim and reality agree.

---

## EDMV2-T08: Make /edm:plan write HANDOFF.md after planning.md

- **Workstream**: WS-A
- **SRD Requirements**: EDMV2-08
- **Priority**: Must
- **Size**: XS
- **Target Components**:
  - `skills/plan/SKILL.md:25-29` — the Operational Orchestration steps; after step 6 (write `planning.md`) and the `phase-complete` call, add an explicit `edm-state write-handoff <PREFIX>` step so HANDOFF.md exists when `/edm:plan` is run directly (the orchestrator already does this at `skills/orchestrator/SKILL.md:94`, but `plan` does not).
- **Dependencies**: EDMV2-T05 (unified template ensures the handoff Decisions block parses)
- **Acceptance Criteria**:
  - **AC-1:** `skills/plan/SKILL.md` includes an explicit instruction to call `edm-state write-handoff <PREFIX>` after `planning.md` is written.
  - **AC-2:** The `write-handoff` step is placed after `planning.md` is written so the handoff reflects the produced planning content.
  - **AC-3:** Running `/edm:plan <PREFIX> <desc>` on a fresh prefix produces BOTH `planning.md` and `HANDOFF.md` in `SRD/{PREFIX}/`.
  - **AC-4:** The produced `HANDOFF.md` reflects the just-written planning content (e.g., the Decisions Made block when decisions exist).
  - **AC-5:** The step is idempotent — re-running `/edm:plan` (resume path) regenerates HANDOFF.md without error.
  - **AC-6:** No change to the orchestrator's existing handoff behavior; the orchestrator path remains the single source of orchestration (skills do not load skills).
- **Verification**: Sandbox-run `/edm:plan` on a fresh prefix; assert both `planning.md` and `HANDOFF.md` exist. QC PASS when AC-1 through AC-6 hold.

---

## EDMV2-T09: Route SRD versioning through the srd-version subcommand

- **Workstream**: WS-A
- **SRD Requirements**: EDMV2-09
- **Priority**: Must
- **Size**: S
- **Target Components**:
  - `skills/srd/SKILL.md:24` — currently "Set `srd_version` in `.edm-state.json` to `1.0.0`"; change to call `edm-state srd-version <PREFIX> 1.0.0` (which refreshes HANDOFF via `write_handoff_internal`, `bin/edm-state:476-486`).
  - `skills/audit-srd/SKILL.md:27` — currently `edm-state set <PREFIX> srd_version 1.1.0` (which skips the handoff refresh); change to `edm-state srd-version <PREFIX> 1.1.0`.
- **Dependencies**: none
- **Acceptance Criteria**:
  - **AC-1:** `skills/srd/SKILL.md` sets the SRD version via `edm-state srd-version <PREFIX> <version>`, not via `edm-state set <PREFIX> srd_version <value>`.
  - **AC-2:** `skills/audit-srd/SKILL.md:27` sets the SRD version via `edm-state srd-version <PREFIX> <version>`, not via `edm-state set`.
  - **AC-3:** No remaining occurrence of `edm-state set <PREFIX> srd_version` exists in any skill (`grep -rn 'set .*srd_version' skills/` returns nothing).
  - **AC-4:** Invoking the `srd` or `audit-srd` versioning step updates `srd_version` in `.edm-state.json`.
  - **AC-5:** The same invocation refreshes `HANDOFF.md` (its `Last updated` timestamp advances), confirming the handoff-refresh side effect of `srd-version` runs.
  - **AC-6:** The `cmd_srd_version` subcommand behavior at `bin/edm-state:476-486` is unchanged by this ticket (skill-side change only).
- **Verification**: Run the versioning step from each skill against a fixture; assert `srd_version` updates AND `HANDOFF.md` timestamp advances. QC PASS when AC-1 through AC-6 hold.

---

## EDMV2-T10: Reconcile record-task-duration documentation with its no-op behavior

- **Workstream**: WS-A
- **SRD Requirements**: EDMV2-10
- **Priority**: Must
- **Size**: M
- **Target Components**:
  - `bin/edm-state:403-411` (`cmd_record_task_duration`) — currently a documented no-op placeholder.
  - `CLAUDE.md` hooks table ("`TaskCompleted` — Record per-task durations for `/edm:metrics`") and `bin/edm-state` subcommand list — must agree with actual behavior.
  - `CHANGELOG.md:163,166` — references that imply `record-task-duration` is live.
  - Default resolution: document it explicitly as a reserved no-op and remove any "live" claim, OR implement per-task duration accumulation by parsing the `TaskCompleted` hook stdin JSON.
- **Dependencies**: none
- **Acceptance Criteria**:
  - **AC-1:** Docs and behavior agree: either `record-task-duration` is documented as a reserved no-op everywhere it is mentioned, OR it actually accumulates per-task durations.
  - **AC-2:** If deferred (no-op path): no doc (CLAUDE.md hooks table, CHANGELOG, subcommand help) states or implies the command records durations as a live feature; the no-op is labeled as reserved/future.
  - **AC-3:** If deferred: the `TaskCompleted` hook wiring and the function comment both clearly say the accumulation is not yet implemented.
  - **AC-4:** If implemented: a simulated `TaskCompleted` stdin JSON payload, piped to the command, records a duration into `.edm-state.json` (e.g., a `task_durations` entry) without error.
  - **AC-5:** If implemented: the function safely no-ops (returns 0) when it cannot determine the active initiative, preserving current best-effort behavior.
  - **AC-6:** The chosen path (implement vs. document-as-reserved) is recorded in the commit message / decision ledger.
  - **AC-7:** The change remains POSIX bash and does not break the `TaskCompleted` hook for existing initiatives (C-4).
- **Verification**: Read `cmd_record_task_duration` and every doc reference; confirm they describe the same behavior. If implemented, pipe a fixture `TaskCompleted` payload and assert a duration is recorded. QC PASS when docs and behavior agree.

---

## EDMV2-T11: Parameterize the push-jira MCP namespace via jira_mcp_namespace userConfig

- **Workstream**: WS-A
- **SRD Requirements**: EDMV2-11
- **Priority**: Must
- **Size**: M
- **Target Components**:
  - `skills/push-jira/SKILL.md:8` — `allowed-tools` hardcodes 11 `mcp__MCP_DOCKER__*` tool names; these must be derived from `${user_config.jira_mcp_namespace}` (default `plugin_jira_atlassian-mcp-server`).
  - `skills/push-jira/SKILL.md:19,29,32-35,49,55-56,109,113` — body references to `mcp__MCP_DOCKER__*` tool names must be reconstructed as `mcp__{jira_mcp_namespace}__{tool}`.
  - `CLAUDE.md` push-jira section ("checks `mcp__MCP_DOCKER__atlassianUserInfo` first") — update to the parameterized form.
  - userConfig key `jira_mcp_namespace` is defined in EDMV2-T-scope of WS-A here via the manifest (coordinated with release ticket EDMV2-102 which lists the key).
- **Dependencies**: EDMV2-T22 (single authoritative manifest must exist before adding the key)
- **Acceptance Criteria**:
  - **AC-1:** `skills/push-jira/SKILL.md` constructs every Jira MCP tool reference as `mcp__{jira_mcp_namespace}__{tool}` where `{jira_mcp_namespace}` resolves from `${user_config.jira_mcp_namespace}`.
  - **AC-2:** The default value of `jira_mcp_namespace` is `plugin_jira_atlassian-mcp-server`.
  - **AC-3:** With the default config, the skill references `mcp__plugin_jira_atlassian-mcp-server__atlassianUserInfo` (and the other 10 tools under the same namespace).
  - **AC-4:** No literal `mcp__MCP_DOCKER__` string remains in `skills/push-jira/SKILL.md` (`grep -c 'MCP_DOCKER' skills/push-jira/SKILL.md` returns 0).
  - **AC-5:** Overriding `jira_mcp_namespace` to a different value changes the referenced namespace in the skill's tool construction (documented, demonstrable by config substitution).
  - **AC-6:** `CLAUDE.md` push-jira documentation references the parameterized namespace, not `mcp__MCP_DOCKER__`.
  - **AC-7:** The `allowed-tools` frontmatter remains valid and `claude plugin validate` passes.
  - **AC-8:** The skill's idempotency, label-tracking, and dependency-linking behavior are otherwise unchanged.
- **Verification**: `grep MCP_DOCKER skills/push-jira/SKILL.md` returns nothing; confirm the default-config tool name is `mcp__plugin_jira_atlassian-mcp-server__atlassianUserInfo`; substitute the config and observe the namespace change. QC PASS when AC-1 through AC-8 hold.

---

## EDMV2-T12: push-jira graceful skip when the Jira MCP namespace is unavailable

- **Workstream**: WS-A
- **SRD Requirements**: EDMV2-12
- **Priority**: Must
- **Size**: S
- **Target Components**:
  - `skills/push-jira/SKILL.md:27-31` (Step 1) — the prerequisite check now calls `mcp__{jira_mcp_namespace}__atlassianUserInfo`; ensure that when the configured namespace is unavailable, the skill prints a friendly skip message and exits cleanly (exit success, no error).
  - `skills/push-jira/SKILL.md:151-156` (Behavior on errors) — confirm the "MCP unavailable: skip with friendly message" path references the parameterized namespace.
- **Dependencies**: EDMV2-T11
- **Acceptance Criteria**:
  - **AC-1:** When `mcp__{jira_mcp_namespace}__atlassianUserInfo` is unavailable, the skill prints a clear "skipping — Jira not available" message naming the configured namespace.
  - **AC-2:** On the unavailable path, the skill exits successfully (treated as opt-in skip, not a failure) and performs no writes to Jira.
  - **AC-3:** On the unavailable path, the skill does not modify the ticket pack or `.edm-state.json` (no `jira_synced_at` written).
  - **AC-4:** The skip message tells the user how to enable Jira sync (configure the MCP server) and references the parameterized namespace, not `MCP_DOCKER`.
  - **AC-5:** The strictly-opt-in behavior is preserved: absence of the MCP never blocks or errors any other EDM phase.
  - **AC-6:** When the MCP IS available, the skill proceeds normally (the skip logic does not false-trigger).
- **Verification**: In a sandbox with no Jira MCP connected, invoke `/edm:push-jira <PREFIX>`; confirm a friendly skip message and clean exit with no mutations. QC PASS when AC-1 through AC-6 hold.

---

## EDMV2-T13: Unify the severity vocabulary across all audit agents

- **Workstream**: WS-A
- **SRD Requirements**: EDMV2-13
- **Priority**: Must
- **Size**: L
- **Target Components**:
  - One canonical severity scale must be defined and referenced by all auditors. Current divergence: `agents/edm-audit-synthesizer.md:45-52` uses `P1/P2/P3 + NOTED`; `agents/edm-srd-auditor.md`, `agents/edm-ticket-auditor.md`, `agents/edm-qc-auditor.md`, and `agents/edm-test-coverage-auditor.md` use `P0/P1/P2`.
  - All 11 `agents/edm-audit-*.md` lens agents and `agents/edm-audit-synthesizer.md` must reference the unified scale.
  - `agents/edm-srd-auditor.md`, `agents/edm-ticket-auditor.md`, `agents/edm-qc-auditor.md`, `agents/edm-test-coverage-auditor.md` must reference the same scale.
  - A single documented severity-scale definition (a shared section, e.g., in CLAUDE.md or a shared template referenced by the agents) is the source of truth.
- **Dependencies**: none
- **Acceptance Criteria**:
  - **AC-1:** A single severity vocabulary is documented in exactly one canonical location with clear definitions and actions per level.
  - **AC-2:** The chosen scale reconciles the two existing scales into one (e.g., a mapping that subsumes `P0/P1/P2` and `P1/P2/P3+NOTED`), with the mapping documented so legacy reports remain interpretable.
  - **AC-3:** Every `agents/edm-audit-*.md` lens agent references the canonical scale (no agent defines its own divergent levels).
  - **AC-4:** `agents/edm-audit-synthesizer.md` references the canonical scale; its `## Severity Reference` table matches the canonical definitions.
  - **AC-5:** `agents/edm-srd-auditor.md`, `agents/edm-ticket-auditor.md`, `agents/edm-qc-auditor.md`, and `agents/edm-test-coverage-auditor.md` each reference the canonical scale.
  - **AC-6:** No two distinct severity scales remain anywhere in `agents/` (a grep audit shows only the canonical levels in use).
  - **AC-7:** The `NOTED` (intentional/pre-existing) concept is preserved in the unified scale or explicitly mapped, so the synthesizer's false-alarm-filter semantics are not lost.
  - **AC-8:** Backward compatibility: existing corpus audit reports using the old levels are not invalidated (the mapping in AC-2 covers them); C-4 holds.
- **Verification**: Grep all auditor agents for severity tokens; confirm only the canonical scale appears and every named auditor references the one documented definition. QC PASS when AC-1 through AC-8 hold.

---

## EDMV2-T14: Make the 11-lens code audit a mandatory orchestrated phase

- **Workstream**: WS-A
- **SRD Requirements**: EDMV2-14
- **Priority**: Must
- **Size**: M
- **Target Components**:
  - `skills/orchestrator/SKILL.md:279` — replace the bullet "Optional: invoke `/edm:code-audit` for the 11-lens exhaustive code audit before merging." with a driven, mandatory code-audit phase.
  - `skills/orchestrator/SKILL.md:271-281` (Step 8 — Verify completion) — add a completion-blocking condition requiring a converged code-audit round; the orchestrator must drive the audit (spawn lenses + synthesizer) rather than suggest it.
- **Dependencies**: EDMV2-T15 (state gating must exist for the completion block to enforce)
- **Acceptance Criteria**:
  - **AC-1:** The word "Optional" no longer precedes the code-audit step in `skills/orchestrator/SKILL.md` (`grep -n 'Optional.*code-audit' skills/orchestrator/SKILL.md` returns nothing).
  - **AC-2:** The orchestrator describes code audit as a mandatory phase that it drives (spawns the 11 lens agents and the synthesizer), not a user-discretion suggestion.
  - **AC-3:** The orchestrator's Step 8 completion checklist requires a converged code-audit round before the initiative may be declared complete / archived.
  - **AC-4:** The completion logic references the state flag (`code_audit_converged`) defined by EDMV2-T15 as the gating condition.
  - **AC-5:** The orchestrator instructs that `edm-state archive` must not be run until the code-audit convergence condition is met (for v2 initiatives).
  - **AC-6:** The `prototype` mode exemption is acknowledged (prototype initiatives do not require code-audit convergence — consistent with EDMV2-T15).
  - **AC-7:** The phase ordering remains coherent: code audit runs after Phase 6 QC and before archive; no earlier phase is disturbed.
  - **AC-8:** `claude plugin validate` passes after the edit.
- **Verification**: Inspect `skills/orchestrator/SKILL.md` around lines 271-281; confirm "Optional" is gone, the audit is driven, and completion is blocked on `code_audit_converged`. QC PASS when AC-1 through AC-8 hold.

---

## EDMV2-T15: Code-audit phase gating in .edm-state.json

- **Workstream**: WS-A
- **SRD Requirements**: EDMV2-15
- **Priority**: Must
- **Size**: M
- **Target Components**:
  - `bin/edm-state` — record code-audit completion via a `code_audit_converged` boolean in state; add the gating rule to `cmd_archive` (`bin/edm-state:488-498`).
  - `cmd_archive` (`bin/edm-state:488-498`) — currently a bare `mv` with no gating; add the convergence/product-aware refusal logic.
  - Optionally a small subcommand or `set`-path to mark `code_audit_converged` true (coordinated with WS-B's audit-round work; this ticket only needs the field + archive gate).
- **Dependencies**: none
- **Acceptance Criteria**:
  - **AC-1:** `.edm-state.json` can record code-audit completion via a `code_audit_converged` field.
  - **AC-2:** When `code_audit_converged` is explicitly `false` AND `product_name` is set (v2 initiative), `edm-state archive <PREFIX>` refuses with a clear, actionable message and a non-zero exit.
  - **AC-3:** When `code_audit_converged` is absent (legacy/v1 initiative), `edm-state archive` proceeds but prints a warning.
  - **AC-4:** When `mode` is `prototype`, `edm-state archive` proceeds with a warning regardless of `code_audit_converged`.
  - **AC-5:** When `code_audit_converged` is `true`, `edm-state archive` proceeds silently (no warning, no refusal).
  - **AC-6:** The gating logic reads `code_audit_converged`, `product_name`, and `mode` via `jq` and treats a missing field as absent (not as `false`), preserving C-4 backward compatibility.
  - **AC-7:** Bash unit checks cover all four cases in AC-2 through AC-5 against fixture state files.
  - **AC-8:** The change is additive — the archive behavior for all existing flat/legacy initiatives is unchanged except for the new warning in the absent-field case.
- **Verification**: Run `edm-state archive` against four fixtures (v2 + converged=false → refused; legacy absent → warn+proceed; prototype → warn+proceed; converged=true → silent proceed); assert each behaves per AC. QC PASS when the unit checks pass.

---

## EDMV2-T16: Parse and honor the --dry-run flag in push-jira

- **Workstream**: WS-A
- **SRD Requirements**: EDMV2-16
- **Priority**: Should
- **Size**: S
- **Target Components**:
  - `skills/push-jira/SKILL.md:170-174` ("Optional: human review before push") — `--dry-run` is described but never formally parsed in Step 1 argument parsing (`skills/push-jira/SKILL.md:28`).
  - `skills/push-jira/SKILL.md:28` — add `--dry-run` to the parsed argument set.
  - Steps 3-8 — gate all mutating MCP calls (`createJiraIssue`, `editJiraIssue`, `createIssueLink`) and ticket-pack/state writes behind a "not dry-run" condition.
- **Dependencies**: EDMV2-T11
- **Acceptance Criteria**:
  - **AC-1:** `skills/push-jira/SKILL.md` Step 1 argument parsing explicitly recognizes the `--dry-run` flag.
  - **AC-2:** When `--dry-run` is set, the skill walks all read/lookup steps and reports the full plan (which issues would be created vs. updated, which links would be added).
  - **AC-3:** When `--dry-run` is set, no `createJiraIssue`, `editJiraIssue`, or `createIssueLink` call is made (no external mutation).
  - **AC-4:** When `--dry-run` is set, no ticket-pack file is rewritten with a Jira link and `.edm-state.json` is not updated (`jira_synced_at` unchanged).
  - **AC-5:** The dry-run output clearly labels itself as a plan/preview, not an executed sync.
  - **AC-6:** Without `--dry-run`, behavior is unchanged (normal sync proceeds).
  - **AC-7:** `--dry-run` composes correctly with the EDMV2-T12 graceful-skip path (a dry run with no MCP still skips cleanly).
- **Verification**: Invoke `/edm:push-jira <PREFIX> --dry-run`; confirm a plan is produced and no Jira issue/link is created and no state/ticket-pack mutation occurs. QC PASS when AC-1 through AC-7 hold.

---

## EDMV2-T17: Resolve the --fill-gaps contradiction between the test skill and CLAUDE.md

- **Workstream**: WS-A
- **SRD Requirements**: EDMV2-17
- **Priority**: Must
- **Size**: XS
- **Target Components**:
  - `skills/test/SKILL.md:20` — authoritative: `--fill-gaps` fills ALL gaps (P0, P1, and P2). This is correct and stays.
  - `CLAUDE.md` ("Testing layer" → "When to invoke /edm:test") — currently states `--fill-gaps` is "fix only P1 gaps in an existing coverage report"; correct this to match the skill (ALL gaps), and ensure there is no option to fill only P1 gaps.
- **Dependencies**: none
- **Acceptance Criteria**:
  - **AC-1:** `CLAUDE.md`'s `--fill-gaps` description states it fills ALL gaps (P0, P1, and P2), matching `skills/test/SKILL.md:20`.
  - **AC-2:** `CLAUDE.md` no longer contains the phrase "fix only P1 gaps" (or any P1-only restriction) for `--fill-gaps`.
  - **AC-3:** There is no documented option anywhere that restricts `--fill-gaps` to P1-only.
  - **AC-4:** The `test` skill text at `skills/test/SKILL.md:20` is left unchanged (it is the correct source of truth).
  - **AC-5:** Any other reference to `--fill-gaps` (e.g., `skills/test/SKILL.md:165,169-171`) remains consistent with the ALL-gaps semantics.
  - **AC-6:** `grep -rn 'fill-gaps' CLAUDE.md skills/test/SKILL.md` shows identical semantics in every hit.
- **Verification**: Diff the `--fill-gaps` descriptions in CLAUDE.md and the test skill; confirm both say ALL gaps and neither offers a P1-only mode. QC PASS when AC-1 through AC-6 hold.

---

## EDMV2-T18: Reconcile the prefix validation regex with the documented 3-6 uppercase format

- **Workstream**: WS-A
- **SRD Requirements**: EDMV2-18
- **Priority**: Must
- **Size**: S
- **Target Components**:
  - `bin/edm-validate-prefix:17` — current regex `^[A-Z][A-Z0-9_-]{1,7}$` allows 2-8 chars and `_`/`-`.
  - `bin/edm-init:12` — same regex `^[A-Z][A-Z0-9_-]{1,7}$` and the message "prefix must be 2-8 chars".
  - `CLAUDE.md` "Initiative prefix" naming section — documents "3-6 uppercase characters".
  - `plugin.json` / `.claude-plugin/plugin.json` `prefix_format_hint` default — "UPPERCASE 3-6 chars (AUTH, MIGR, TIPS)".
  - Implementation and docs must agree on one character set and length.
- **Dependencies**: EDMV2-T22 (single authoritative manifest before editing the hint default)
- **Acceptance Criteria**:
  - **AC-1:** The regex in `bin/edm-validate-prefix` and the documented format string describe the same character set and length range.
  - **AC-2:** The regex in `bin/edm-init:12` matches the regex in `bin/edm-validate-prefix:17` exactly (no divergence between the two scripts).
  - **AC-3:** The error/usage messages in both scripts state the same length and character rules as the regex.
  - **AC-4:** `CLAUDE.md`'s "Initiative prefix" section and the `prefix_format_hint` default in the authoritative manifest agree with the regex.
  - **AC-5:** A prefix that satisfies the documented format is accepted; a prefix that violates it is rejected with the documented message and the documented exit code (1 for invalid format).
  - **AC-6:** Backward compatibility: any existing in-flight initiative prefix that was valid under the old regex still resolves and operates (C-4) — if narrowing the regex, confirm no existing corpus prefix is broken, or document the exemption.
  - **AC-7:** The chosen reconciliation direction (tighten regex to docs, or loosen docs to regex) is recorded in the commit message / decision ledger.
- **Verification**: Compare the regex, both script messages, the CLAUDE.md format string, and the `prefix_format_hint` default; confirm one consistent rule. Run `edm-validate-prefix` on a conforming and a non-conforming prefix. QC PASS when AC-1 through AC-7 hold.

---

## EDMV2-T19: Fix the stale next-step message in edm-init

- **Workstream**: WS-A
- **SRD Requirements**: EDMV2-19
- **Priority**: Should
- **Size**: XS
- **Target Components**:
  - `bin/edm-init:29-36` — the closing `cat <<EOF ... Next: run /edm:plan $PREFIX <description> ...` heredoc message must reference the current orchestrator entry point and the WS-M directory layout.
  - `bin/edm-init:14,31` — the scaffold path `DIR="${SRD_ROOT}/${PREFIX}"` and the printed tree reflect the old flat layout; align the printed next-step/path text with the layout in effect (coordinated with WS-M).
- **Dependencies**: none
- **Acceptance Criteria**:
  - **AC-1:** The next-step message printed by `bin/edm-init` references a valid, currently-existing command (e.g., `/edm:orchestrator` or `/edm:plan`) that matches the orchestrator's documented entry flow.
  - **AC-2:** The printed initiative path in the message matches the directory `edm-init` actually creates.
  - **AC-3:** The message does not reference any removed/renamed command or a path the script does not create.
  - **AC-4:** The message is ASCII-only (consistent with EDMV2-T21) and contains no AI-attribution text.
  - **AC-5:** Running `edm-init <PREFIX>` prints the corrected message and exits 0.
  - **AC-6:** The change is text-only and does not alter the scaffold's directory creation behavior in this ticket.
- **Verification**: Run `edm-init <PREFIX>` in a sandbox; confirm the printed command and path are valid and current. QC PASS when AC-1 through AC-6 hold.

---

## EDMV2-T20: Scope the Bash entry in skill allowed-tools

- **Workstream**: WS-A
- **SRD Requirements**: EDMV2-20
- **Priority**: Should
- **Size**: M
- **Target Components**: Every skill frontmatter `allowed-tools` line carrying a bare unscoped `Bash`:
  - `skills/orchestrator/SKILL.md:8`, `skills/plan/SKILL.md:8`, `skills/srd/SKILL.md:8`, `skills/audit-srd/SKILL.md:8`, `skills/tickets/SKILL.md:8`, `skills/audit-tickets/SKILL.md:8`, `skills/implement/SKILL.md:8`, `skills/code-audit/SKILL.md:8`, `skills/metrics/SKILL.md:8`, `skills/push-jira/SKILL.md:8`, `skills/test/SKILL.md:8`, `skills/test-plan/SKILL.md:8`, `skills/test-coverage/SKILL.md:8`.
  - Replace bare `Bash` with scoped families the skill actually invokes (e.g., `Bash(edm-state *)`, `Bash(edm-init *)`, `Bash(edm-validate-prefix *)`, `Bash(git *)`).
- **Dependencies**: none
- **Acceptance Criteria**:
  - **AC-1:** No skill frontmatter contains a bare unscoped `Bash` where a scoped form is sufficient (`grep -rn 'Bash[,$]' skills/*/SKILL.md` finds no bare `Bash` token in `allowed-tools`).
  - **AC-2:** Each skill's scoped `Bash(...)` entries cover exactly the command families that skill actually invokes in its body (e.g., `metrics` only needs `Bash(edm-state *)`; `plan` needs `edm-state`, `edm-init`, `edm-validate-prefix`).
  - **AC-3:** No skill loses access to a command it actually calls — every bare-name call in each skill body maps to a scoped entry.
  - **AC-4:** Skills that legitimately need git (e.g., those that commit or read git state) include `Bash(git *)`; skills that do not, do not.
  - **AC-5:** The `push-jira` skill retains its `mcp__...` tool entries unchanged (only the `Bash` token is scoped).
  - **AC-6:** `claude plugin validate` passes for every modified skill.
  - **AC-7:** A sandbox smoke run of at least one representative skill (e.g., `/edm:metrics`) confirms the scoped `Bash` still permits its `edm-state` calls.
- **Verification**: Grep all skill frontmatter for bare `Bash`; for each skill, cross-check that scoped families cover its actual command calls. Sandbox-run a representative skill. QC PASS when AC-1 through AC-7 hold.

---

## EDMV2-T21: Remove Unicode glyphs from generated artifacts (edm-state)

- **Workstream**: WS-A
- **SRD Requirements**: EDMV2-21
- **Priority**: Must
- **Size**: S
- **Target Components**:
  - `bin/edm-state:368` — the drift header uses a Unicode `(!)` warning glyph; replace with ASCII `(!)`.
  - `bin/edm-state:380` and `bin/edm-state:390` — the two Unicode `->` arrows in the drift body; replace with ASCII `->`.
  - `bin/edm-state:711-715` — the present/not-yet markers (`✓ present` / `✗ not yet`) in `write_handoff_internal`; replace with ASCII equivalents (e.g., `[present]` / `[absent]`).
  - `bin/edm-state:497` — the `archived ... ->` arrow in `cmd_archive` output (Unicode); replace with ASCII `->`.
- **Dependencies**: none
- **Acceptance Criteria**:
  - **AC-1:** The drift header at `bin/edm-state:368` emits an ASCII-only warning marker (no Unicode).
  - **AC-2:** The drift-body arrows at `bin/edm-state:380` and `:390` are ASCII `->` (no Unicode arrow glyph).
  - **AC-3:** The artifact-checklist markers at `bin/edm-state:711-715` are ASCII (e.g., `[present]` / `[absent]`), and the generated `HANDOFF.md` Artifact Checklist table renders them as ASCII.
  - **AC-4:** Any other Unicode arrow in `edm-state` user-facing output (e.g., the `cmd_archive` message at `:497`) is converted to ASCII.
  - **AC-5:** `grep -nP '[^\x00-\x7F]' bin/edm-state` returns no matches in code paths that produce committed/printed artifacts (HANDOFF.md, drift output, archive message).
  - **AC-6:** Running `write-handoff` then `grep -P '[^\x00-\x7F]'` over the produced `HANDOFF.md` returns nothing.
  - **AC-7:** Triggering a drift condition then `grep -P '[^\x00-\x7F]'` over the drift output returns nothing.
  - **AC-8:** The semantic meaning of each marker is preserved (a teammate can still tell "present" from "absent" and read the drift remediation arrow).
- **Verification**: `grep -P '[^\x00-\x7F]'` over generated `HANDOFF.md` and over captured drift/archive output returns nothing; visually confirm markers remain meaningful. QC PASS when AC-1 through AC-8 hold.

---

## EDMV2-T22: De-duplicate plugin.json and fix README install paths

- **Workstream**: WS-A
- **SRD Requirements**: EDMV2-22
- **Priority**: Must
- **Size**: M
- **Target Components**:
  - `plugin.json` and `.claude-plugin/plugin.json` — currently byte-identical duplicate manifests (both `"version": "1.3.0"`). Resolve to a single authoritative manifest per the Claude Code plugin spec (`.claude-plugin/plugin.json` is canonical); remove or symlink the duplicate so there is one source of truth.
  - `README.md:11` — install path `claude plugin install /Users/darryl.porter/projects/scripps-mcp/edm-plugin` is wrong (actual layout is `plugins/edm-ai-development/`).
  - `README.md:14` — dev-mode path `claude --plugin-dir /Users/darryl.porter/projects/scripps-mcp/edm-plugin` is likewise wrong.
- **Dependencies**: none
- **Acceptance Criteria**:
  - **AC-1:** Exactly one authoritative plugin manifest is the source of truth; the duplicate is removed (or made a thin pointer), and the spec-canonical location is used.
  - **AC-2:** A change to the version field in the authoritative manifest is the only place that must be edited to bump the plugin version (no second copy can drift).
  - **AC-3:** `README.md` install command references a path that exists in the actual repository layout (`plugins/edm-ai-development/` or the marketplace install form), not the stale `projects/scripps-mcp/edm-plugin` path.
  - **AC-4:** `README.md` dev-mode `--plugin-dir` command references a path that exists.
  - **AC-5:** No README install/usage example references a non-existent directory.
  - **AC-6:** `claude plugin validate` passes against the single authoritative manifest.
  - **AC-7:** The decision on which manifest is canonical is recorded in the commit message / decision ledger.
  - **AC-8:** `marketplace.json` (repo root) continues to reference the plugin correctly after de-duplication (no broken `source` path), per repo convention.
- **Verification**: Confirm only one authoritative manifest exists; run the README install/dev commands' path references against the actual tree; `claude plugin validate` passes. QC PASS when AC-1 through AC-8 hold.

---

## EDMV2-T23: Resolve scaffold asymmetry between edm-init and later-phase expectations

- **Workstream**: WS-A
- **SRD Requirements**: EDMV2-23
- **Priority**: Could
- **Size**: M
- **Target Components**:
  - `bin/edm-init:19` — currently scaffolds only `mkdir -p "$DIR/code-audit"` plus the state file; later phases expect `tickets/`, `tickets/epics/`, and other slots documented in the CLAUDE.md "Project artifact layout".
  - `bin/edm-init` printed tree (`:30-34`) — must match what is actually created.
  - CLAUDE.md "Project artifact layout" — the canonical layout the scaffold should align to (coordinated with WS-M / WS-D canonical homes).
- **Dependencies**: EDMV2-T19 (next-step/path message), EDMV2-T15 (code-audit state field, to avoid contradicting the gating model)
- **Acceptance Criteria**:
  - **AC-1:** A freshly scaffolded initiative directory matches the documented artifact layout with no missing or extra expected slots.
  - **AC-2:** Every directory slot that a later phase assumes exists (e.g., `code-audit/`, and any others the layout documents as scaffolded-at-init) is created by `edm-init`, OR the layout doc is corrected to state which slots are created lazily by later phases.
  - **AC-3:** The tree printed by `edm-init` exactly matches the directories/files it actually creates.
  - **AC-4:** No phase later fails because a directory it assumed at init time is absent (verified by walking each phase's path assumptions against the scaffold).
  - **AC-5:** The scaffold remains backward-compatible: existing initiatives are not retro-scaffolded, and `edm-init` still refuses to overwrite an existing initiative directory (`bin/edm-init:15-17`).
  - **AC-6:** The resolution is consistent with the WS-M directory layout (no flat-vs-product-dir contradiction introduced by this ticket).
  - **AC-7:** `claude plugin validate` and a sandbox `edm-init` run both succeed, and the produced tree matches AC-3.
- **Verification**: Run `edm-init <PREFIX>` in a sandbox; compare the produced directory tree against the documented layout and against each later phase's path assumptions; confirm no missing/extra slots and the printed tree is accurate. QC PASS when AC-1 through AC-7 hold.
