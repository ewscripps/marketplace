# Epic 5 — Adaptation Modes (WS-E) + Lifecycle Modes (WS-F)

Generated From: srd.md v1.0.7

This epic delivers the first-class adaptation profiles and lifecycle variants the methodology document
defines but the plugin (v1.3.0) currently implements as none: the `mode` / `lifecycle_mode` / `compliance_enabled`
/ `implementation_mode` concepts, the four adaptation profiles (mini-SRD, IaC, data/ML, prototype), the
compliance review gate (Gate 3.5), the TDD implementation mode, mode-selection UX, mode-aware scaffolding,
and the lifecycle modes (phase-skip, fast-track/fix-pack, supersede/fork) with their `edm-state` and HANDOFF
surfacing.

Workstreams: **WS-E** (EDMV2-44..51, EDMV2-106, SRD §4.5) and **WS-F** (EDMV2-52..56, SRD §4.6).
Tickets: **EDMV2-T83 .. EDMV2-T100**.

## Foundational dependencies (out of this epic)

All WS-E/F behavior consumes the WS-J state machinery built in Epic 2 (EDMV2-T24..T54). Specifically:

- **EDMV2-T25** (EDMV2-68 typed-set in `cmd_set`) — required so `compliance_enabled` and enum
  fields serialize as proper JSON types, not coerced strings.
- **EDMV2-T24** (EDMV2-70 advisory lock in `write_state`) — every `set-mode`/`set-parent` write must go
  through the locked writer.
- **EDMV2-T48** (EDMV2-94/95 `## Resume Point` + handoff render refactor) — WS-F HANDOFF rendering
  (EDMV2-T99) extends this.
- **EDMV2-T37** (EDMV2-88 state-derived path construction via `state_file_for()`) — mode-aware
  scaffold and all artifact-path branches resolve through it.

Where this epic references those tickets it uses the placeholder IDs above; the README index resolves them
to the Epic 2 ticket numbers. Within this epic, `set-mode` (EDMV2-T83) is the keystone: every other WS-E/F
ticket that persists a mode depends on it.

---

## EDMV2-T83: Add the set-mode subcommand and the four mode state fields to edm-state

- **Workstream**: WS-E / WS-F (shared)
- **SRD Requirements**: EDMV2-44, EDMV2-55
- **Priority**: Must
- **Size**: M
- **Target Components**:
  - `bin/edm-state` — new `cmd_set_mode()` function; new `set-mode)` arm in the dispatch `case` block (`:777-800`)
  - `bin/edm-state:218-230` (`cmd_init`) — add `mode`, `lifecycle_mode`, `compliance_enabled`, `implementation_mode` to the init payload with safe defaults
  - `bin/edm-state` `--help` block (`:2-21`) and dispatch help slice (`sed -n '2,21p'` at `:796`) — document `set-mode`
- **Dependencies**: EDMV2-T25 (EDMV2-68 typed-set), EDMV2-T24 (EDMV2-70 locking)

### Description

`set-mode <PREFIX> <kind> <value>` is the single write path for both the adaptation profile (`mode`) and
the lifecycle variant (`lifecycle_mode`), which are orthogonal: an initiative can be both `iac` and
`fast-track`. The subcommand also accepts `implementation_mode` (for EDMV2-106 TDD mode) and
`compliance_enabled` as recognized kinds so all four mode-family fields share one entry point.

The four fields are additive and defaulted (`mode: "standard"`, `lifecycle_mode: "standard"`,
`compliance_enabled: false`, `implementation_mode: "standard"`), preserving C-4 backward compatibility: an
existing v1.x state file with none of them still validates and behaves as v1.x. `compliance_enabled` must
serialize as a JSON boolean, which requires the typed-set path from EDMV2-68.

### Acceptance Criteria

- [ ] AC1: `edm-state set-mode EDMV2 mode iac` persists `"mode": "iac"` (verified via `jq -r .mode`) and prints a confirmation line.
- [ ] AC2: `edm-state set-mode EDMV2 lifecycle_mode fast-track` persists `"lifecycle_mode": "fast-track"` independently; reading `mode` afterward still returns the prior value (orthogonality round-trip).
- [ ] AC3: `edm-state set-mode EDMV2 compliance_enabled true` persists a JSON boolean `true` (`jq -e '.compliance_enabled == true'` exits 0), not the string `"true"`.
- [ ] AC4: `edm-state set-mode EDMV2 implementation_mode tdd` persists `"implementation_mode": "tdd"`.
- [ ] AC5: An invalid `kind` (e.g., `set-mode EDMV2 banana x`) exits non-zero with a `die` message listing the four valid kinds and does not write state.
- [ ] AC6: An invalid `value` for a known enum kind (e.g., `set-mode EDMV2 mode zzz`) exits non-zero, naming the allowed enum values (`standard|mini-srd|iac|data-ml|prototype` for `mode`).
- [ ] AC7: Wrong arg count (`set-mode EDMV2 mode` with no value) exits non-zero with a usage string.
- [ ] AC8: `edm-state init EDMV2` on a fresh prefix writes all four fields with their documented defaults.
- [ ] AC9: All four fields round-trip through the EDMV2-70 advisory lock (write goes through `write_state`).
- [ ] AC10: `set-mode` updates `.last_updated` and appears in `edm-state --help` output.
- [ ] AC11: A fixture `.edm-state.json` lacking these fields is read without error; `mode` resolves to `standard`, `lifecycle_mode` to `standard`, `compliance_enabled` to `false`, `implementation_mode` to `standard` via jq `//` guards.

### Technical Notes

- Mirror the structure of `cmd_srd_version()` (`:476-486`) but branch on `kind`. Use `--argjson` for
  `compliance_enabled` (boolean) and `--arg` for the three string enums.
- Validate enums in bash before the `jq` write: `mode` ∈ {standard,mini-srd,iac,data-ml,prototype};
  `lifecycle_mode` ∈ {standard,partial,fast-track,fix-pack}; `implementation_mode` ∈ {standard,tdd};
  `compliance_enabled` ∈ {true,false}.
- Do NOT call `write_handoff_internal` here unless the handoff render (EDMV2-T99) is already merged — keep
  this ticket's surface limited to state to avoid coupling. (If render is merged, refreshing handoff is fine.)

### Verification

QC confirms PASS by running each AC command against a sandbox `.edm-state.json` and asserting the `jq`
type/value checks; the typed-boolean assertion (`jq -e`) and the orthogonality round-trip (AC2) are the
load-bearing checks. Re-running `set-mode` is idempotent (same value yields same state apart from
`last_updated`).

### Out of Scope

- Orchestrator branching on these fields (EDMV2-T84, T88, T91..T95).
- Mode-selection UX / AskUserQuestion (EDMV2-T90).
- `set-parent`/`add-related` (WS-G, separate epic).

---

## EDMV2-T84: Add the mode-selection step and mode-branch dispatch to the orchestrator

- **Workstream**: WS-E / WS-F
- **SRD Requirements**: EDMV2-44 (orchestrator half), EDMV2-50
- **Priority**: Must (EDMV2-44) / Should (EDMV2-50)
- **Size**: M
- **Target Components**:
  - `skills/orchestrator/SKILL.md` — new "Step 1c — Mode and profile selection" inserted after Step 1b (`:79-94`), before Step 2 (`:96`)
  - `skills/orchestrator/SKILL.md` — new "Resume: read mode" note in the resume branch (Step 1b point 3, `:85-92`) so a resumed initiative re-reads `mode`/`lifecycle_mode`/`compliance_enabled`/`implementation_mode` from state and follows the matching sub-flow
  - `skills/orchestrator/SKILL.md` — frontmatter `allowed-tools` (`:8`) already includes `AskUserQuestion` and `Bash`; no change
- **Dependencies**: EDMV2-T83 (set-mode)

### Description

The orchestrator gains a mode-selection step at initiative start (after prefix resolution, before Phase 1)
that presents the adaptation profile and the compliance toggle via `AskUserQuestion`, records the choices
through `set-mode`, and documents how each `mode` value re-shapes the phase graph. Because the orchestration
layer is a prompt read by an LLM rather than a code interpreter (SRD §5.0), "branching on mode" means the
orchestrator reads the fields from state and follows the matching documented sub-flow — the same mechanism
it already uses for `gates_approved`.

This ticket establishes the selection step and the dispatch table (which mode routes to which sub-flow); the
actual per-mode sub-flow bodies land in EDMV2-T88 (mini-SRD), T91 (compliance gate), T92 (IaC), T93
(data/ML), T94 (prototype), and T95 (TDD). On resume, the orchestrator must re-read all four mode-family
fields and not restart Phase 1 in the wrong profile.

### Acceptance Criteria

- [ ] AC1: A new "Step 1c — Mode and profile selection" exists in `skills/orchestrator/SKILL.md` positioned after Step 1b and before "Step 2 — Execute Phase 1".
- [ ] AC2: Step 1c uses `AskUserQuestion` with a `<=12`-char header (e.g., `"EDM mode"`) and options for each adaptation profile: Standard, mini-SRD, IaC, Data/ML, Prototype.
- [ ] AC3: Step 1c separately captures the compliance toggle (a distinct `AskUserQuestion` option set or a follow-up question: compliance on/off), reflecting that `compliance_enabled` is a flag, not a mode.
- [ ] AC4: After selection, the step records choices via `edm-state set-mode <PREFIX> mode <value>` and, when compliance is on, `edm-state set-mode <PREFIX> compliance_enabled true`.
- [ ] AC5: The step is skipped on resume of an initiative that already has a non-default `mode` recorded; instead the orchestrator reads the existing value and states which sub-flow it will follow.
- [ ] AC6: A dispatch table or prose maps each `mode` to its sub-flow ticket behavior (standard = current six-phase flow; mini-srd = EDMV2-T88; iac = EDMV2-T92; data-ml = EDMV2-T93; prototype = EDMV2-T94) and names the compliance-gate insertion point (EDMV2-T91).
- [ ] AC7: Selecting Standard mode with compliance off yields the same phase/gate sequence (Phases 1-6, Gates 1-3) as v1.x; the only addition is Step 1c recording `mode=standard`, which is transparent to the phase graph.
- [ ] AC8: The resume branch (Step 1b) instructs reading `mode`, `lifecycle_mode`, `compliance_enabled`, and `implementation_mode` from `.edm-state.json` before dispatching.
- [ ] AC9: The selection step never auto-approves a gate and never edits state outside `set-mode`.

### Technical Notes

- Keep the `AskUserQuestion` header under 12 chars (Claude Code constraint mirrored in existing gate prompts).
- Always provide a default/escape option (Standard) so the user can proceed without committing to a profile.
- Reference the SRD §5.5 mode/phase-graph paragraph as the source of truth for branch semantics.

### Verification

QC confirms PASS by inspection: the new Step 1c is present and ordered correctly; `grep` confirms the four
`set-mode`/`AskUserQuestion` references; the standard-path equivalence (AC7) is verified by diffing the
documented standard sub-flow against the pre-EDMV2 Steps 2-8. Since this is a markdown-prompt change, QC
verdict is PASS on structural inspection plus a sandbox dry-read of Step 1c.

### Out of Scope

- The sub-flow bodies for each mode (separate tickets).
- `edm-init` scaffold changes (EDMV2-T96).
- Lifecycle-mode selection (this step covers adaptation profile + compliance; lifecycle modes are set via
  `set-mode` directly or surfaced in HANDOFF per WS-F tickets).

---

## EDMV2-T85: Add the WS-E/F userConfig keys and mode-family schema documentation

- **Workstream**: WS-E / WS-F
- **SRD Requirements**: EDMV2-44 (schema), EDMV2-102 (the `mode`/`compliance_enabled` keys)
- **Priority**: Must
- **Target Components**:
  - `plugin.json` (authoritative manifest per EDMV2-22) — add `userConfig` keys `mode` (default `standard`) and `compliance_enabled` (default `false`)
  - `CLAUDE.md` — extend the `.edm-state.json` schema docs and `userConfig` reference with the mode-family fields
- **Size**: S
- **Dependencies**: EDMV2-T83 (set-mode), EDMV2-T22 (EDMV2-22 manifest de-dup)

### Description

EDMV2-102 requires `plugin.json` to define `mode` and `compliance_enabled` as userConfig keys with safe
defaults that reproduce v1.x behavior when omitted. This ticket adds those two keys (the WS-E/F slice of
EDMV2-102; `jira_mcp_namespace` and `qc_shard_threshold` belong to their own workstreams) and documents the
four mode-family state fields in `CLAUDE.md` so the schema is discoverable.

`product_name` is intentionally NOT a userConfig key (per-initiative only). `lifecycle_mode` and
`implementation_mode` are per-initiative state fields, not userConfig keys; only `mode` and
`compliance_enabled` are exposed as install-time defaults.

### Acceptance Criteria

- [ ] AC1: `plugin.json` defines a `mode` userConfig key with default `"standard"` and a description listing the five enum values.
- [ ] AC2: `plugin.json` defines a `compliance_enabled` userConfig key with default `false` (JSON boolean).
- [ ] AC3: Omitting both keys at install reproduces v1.x behavior (defaults applied).
- [ ] AC4: `CLAUDE.md` documents `mode`, `lifecycle_mode`, `compliance_enabled`, and `implementation_mode` in the state-schema section with type, default, and introducing requirement.
- [ ] AC5: `CLAUDE.md` `userConfig` reference lists the two new keys with their defaults.
- [ ] AC6: `claude plugin validate` passes on the modified manifest.
- [ ] AC7: There is exactly one authoritative manifest (the EDMV2-22 de-dup is respected — no key added to a stale duplicate).

### Technical Notes

- Coordinate with EDMV2-T22 so the keys are added to the single source-of-truth manifest, not the
  duplicate slated for removal.
- Keys must use the existing `CLAUDE_PLUGIN_OPTION_*` env-var convention so `bin/` scripts can read them.

### Verification

QC confirms PASS via `claude plugin validate` exit 0 and `jq` assertions on the two new keys' defaults in
the manifest; AC3 verified by a sandbox init with no overrides yielding standard-mode state.

### Out of Scope

- `qc_shard_threshold` and `jira_mcp_namespace` userConfig keys (other workstreams).
- The schema implementation in `cmd_init` (EDMV2-T83 owns the init payload).

---

## EDMV2-T86: mini-SRD mode — fused-artifact state and scaffold contract

- **Workstream**: WS-E
- **SRD Requirements**: EDMV2-45 (state/scaffold half)
- **Priority**: Must
- **Size**: M
- **Target Components**:
  - `bin/edm-init` — mode-aware scaffold branch (coordinated with EDMV2-T96): when `mode=mini-srd`, do not create a `tickets/` slot; create the fused-file slot
  - `bin/edm-state` — `cmd_archive` gating already tolerates non-standard flows; confirm mini-SRD's skipped phases do not falsely block archive (coordinated with EDMV2-T97)
  - `skills/srd/SKILL.md` — document the fused mini-SRD file structure (Phases 2-5 sections in one file)
- **Dependencies**: EDMV2-T83 (set-mode), EDMV2-T37 (EDMV2-88)

### Description

mini-SRD mode fuses Phases 2-5 into a single audited file and skips the separate ticket pack (methodology doc
lines 446-468). This ticket defines the artifact contract: the fused file's section layout, the directory
shape (no separate `tickets/` directory), and the state representation (`skipped_phases` reflecting the
fused/omitted phases). The orchestrator sub-flow that drives mini-SRD lands in EDMV2-T88; this ticket is the
data/scaffold foundation it builds on.

### Acceptance Criteria

- [ ] AC1: `skills/srd/SKILL.md` documents a fused mini-SRD file containing, in order, the SRD content sections plus an embedded ticket-list section (the Phase-4 equivalent) within one file.
- [ ] AC2: The fused-file path is derived from state (not hardcoded), resolving under the initiative directory.
- [ ] AC3: For a `mode=mini-srd` initiative, `edm-init`/scaffold does not create a `tickets/` subdirectory.
- [ ] AC4: The fused file still has a defined audit target so EDMV2-45's "still requires an audit" holds (the audit reads the fused file).
- [ ] AC5: State records which phases are fused/skipped via `skipped_phases` so completion is not falsely blocked on a separate ticket-pack gate.
- [ ] AC6: A `mode=standard` initiative is unaffected — it still scaffolds `tickets/` and uses the multi-file flow.
- [ ] AC7: The documented fused-file structure preserves the SRD `Generated From:` version-linkage requirement (the fused file or its audit references the SRD version).

### Technical Notes

- Coordinate the no-`tickets/` scaffold branch with EDMV2-T96 (mode-aware scaffold) to avoid a double-implementation.
- The fused file does not replace the SRD audit phase — it changes what the audit reads, not whether it runs.

### Verification

QC confirms PASS by scaffolding a sandbox `mode=mini-srd` initiative and asserting the absence of `tickets/`,
the presence of the fused-file slot, and the documented section layout in `skills/srd/SKILL.md`.

### Out of Scope

- The orchestrator mini-SRD driving sub-flow (EDMV2-T88).
- General mode-aware scaffold for the other profiles (EDMV2-T96).

---

## EDMV2-T87: Reserve slot — folded into EDMV2-T86/T88

> **Note for the README index:** mini-SRD was decomposed into T86 (state/scaffold contract) and T88
> (orchestrator sub-flow). To keep the EDMV2-T83..T100 range contiguous with one ticket per logical unit,
> this slot is intentionally not used as a standalone ticket. If the index requires a contiguous numbering,
> renumber T88..T100 down by one; otherwise treat T87 as reserved. No SRD requirement is orphaned by this
> reservation — EDMV2-45 is fully covered by T86 + T88.

(Reserved — no ticket. See coverage note in the README SRD coverage map.)

---

## EDMV2-T88: mini-SRD mode — orchestrator fused-flow driving and audit

- **Workstream**: WS-E
- **SRD Requirements**: EDMV2-45 (orchestrator half)
- **Priority**: Must
- **Size**: M
- **Target Components**:
  - `skills/orchestrator/SKILL.md` — new "mini-SRD sub-flow" subsection branched from Step 1c (EDMV2-T84); replaces the linear Step 3 -> Step 6 sequence (`:181-248`) with a single fused-file produce-then-audit sequence when `mode=mini-srd`
  - `skills/orchestrator/SKILL.md:79-94` — resume branch reads `mode` and jumps into the fused sub-flow
- **Dependencies**: EDMV2-T84 (mode dispatch), EDMV2-T86 (fused-file contract)

### Description

When `mode=mini-srd`, the orchestrator must run a compressed flow: Phase 1 (planning) -> produce the single
fused SRD+tickets file -> audit the fused file -> Gate (the merged Gate 2/3 equivalent) -> Phase 6
implementation. The separate ticket-pack creation (Phase 4) and separate ticket audit (Phase 5) are skipped;
the SRD audit still runs against the fused file (EDMV2-45 "still requires an audit").

### Acceptance Criteria

- [ ] AC1: `skills/orchestrator/SKILL.md` contains a mini-SRD sub-flow that, after Phase 1, produces one fused file and does not spawn `edm-ticket-writer` for a separate pack.
- [ ] AC2: The sub-flow runs an audit step over the fused file before its approval gate.
- [ ] AC3: The sub-flow presents exactly one pre-implementation HITL gate (the merged Gate 2/3) rather than two.
- [ ] AC4: `skipped_phases` is set to reflect the omitted separate-ticket-pack phases (coordinated with EDMV2-T97).
- [ ] AC5: After fused-file approval, the orchestrator proceeds to Phase 6 implementation reading tickets from the fused file's ticket section.
- [ ] AC6: On resume of a `mode=mini-srd` initiative, the orchestrator enters the fused sub-flow rather than the standard Steps 3-6.
- [ ] AC7: The sub-flow does not call `approve-gate` except on an explicit Approve selection (consistent with EDMV2-67).
- [ ] AC8: Standard mode's Steps 3-6 are unchanged.

### Technical Notes

- The merged gate should still record a gate approval in `gates_approved` so completion/archive logic and
  HANDOFF have a recorded gate; document which gate number it records (recommend reusing Gate 2's slot since
  the SRD-equivalent is what is approved).
- Reuse the existing SRD-audit agents over the fused file; do not invent a new auditor agent.

### Verification

QC confirms PASS by inspection of the orchestrator sub-flow and a sandbox dry-read: only one gate is
presented, no separate ticket-pack spawn occurs, and the audit step is present.

### Out of Scope

- The fused-file section contract and scaffold (EDMV2-T86).
- Per-epic test plans for the fused initiative (WS-H).

---

## EDMV2-T89: IaC adaptation profile — resource-path vocabulary and terraform-plan QC

- **Workstream**: WS-E
- **SRD Requirements**: EDMV2-47
- **Priority**: Must
- **Size**: M
- **Target Components**:
  - `skills/srd/SKILL.md` and `skills/tickets/SKILL.md` — when `mode=iac`, document "resource paths" (e.g., `aws_s3_bucket.logs`) in place of source "file paths" in SRD requirements and ticket Target Components
  - new QC agent `agents/edm-qc-auditor-iac.md` (red color, opus/max per SRD §5.2.4) OR a documented IaC branch within `agents/edm-qc-auditor.md` — directs QC to verify `terraform plan` / drift instead of source-file ACs
  - `skills/implement/SKILL.md` — IaC QC branch reference
- **Dependencies**: EDMV2-T84 (mode dispatch)

### Description

The IaC profile changes two things when `mode=iac`: (1) the artifact vocabulary shifts from "file paths" to
"resource paths" in SRD requirements and ticket Target Components, and (2) QC verification shifts from
inspecting source-file ACs to checking `terraform plan` output and drift, since IaC correctness is expressed
as desired-vs-actual resource state rather than code structure.

### Acceptance Criteria

- [ ] AC1: `skills/srd/SKILL.md` documents that under `mode=iac`, requirement targets are stated as resource paths, with at least one worked example.
- [ ] AC2: `skills/tickets/SKILL.md` documents that under `mode=iac`, ticket Target Components list resource paths rather than source-file paths.
- [ ] AC3: The IaC QC behavior is defined: each AC is verified against `terraform plan` (no unexpected changes) and/or a drift check, not against static source-file inspection.
- [ ] AC4: The IaC QC behavior follows the red (QC) color and opus/max model policy if delivered as a new agent (SRD §5.2.4); if delivered as a branch in the existing auditor, the existing color/model is retained.
- [ ] AC5: `claude plugin validate` passes if a new agent file is added (frontmatter conformant).
- [ ] AC6: Under `mode=standard`, none of the IaC vocabulary or QC changes apply (the file-path vocabulary and source-AC QC are unchanged).
- [ ] AC7: The IaC QC verdict still supports PASS/PARTIAL/FAIL (PARTIAL for ACs needing a live `terraform plan` not runnable statically), consistent with EDMV2-34.

### Technical Notes

- Prefer a documented branch within `agents/edm-qc-auditor.md` over a wholly new agent unless the QC logic
  diverges enough to warrant separation — fewer agents is the least-privilege default, but SRD §5.2.4
  explicitly allows new QC agents for these profiles.
- `terraform plan` requires a runtime + cloud creds; many IaC ACs will legitimately be PARTIAL/deferred — do
  not mark them FAIL.

### Verification

QC confirms PASS by inspection of the three skill/agent vocabulary branches and the documented terraform-plan
QC contract; if a new agent is added, `claude plugin validate` must exit 0.

### Out of Scope

- Actually running `terraform` (no new external dependency is added — C-2; the profile documents the QC
  contract, it does not bundle terraform).
- Data/ML profile (EDMV2-T90... see T90 below — data/ML is a separate ticket).

---

## EDMV2-T90: Data/ML adaptation profile — Data Requirements SRD section and model-metric QC

- **Workstream**: WS-E
- **SRD Requirements**: EDMV2-48
- **Priority**: Must
- **Size**: M
- **Target Components**:
  - `skills/srd/SKILL.md` — when `mode=data-ml`, require a `## Data Requirements` section in the SRD (data sources, schemas, volumes, quality/labeling constraints)
  - new QC agent `agents/edm-qc-auditor-dataml.md` (red, opus/max) OR a documented data/ML branch within `agents/edm-qc-auditor.md` — directs QC to validate model metrics (e.g., accuracy/precision/recall thresholds) rather than only source-file ACs
  - `skills/implement/SKILL.md` — data/ML QC branch reference
- **Dependencies**: EDMV2-T84 (mode dispatch)

### Description

The Data/ML profile requires a dedicated Data Requirements section in the SRD (so data provenance, schema,
volume, and quality constraints are first-class) and directs QC to validate model metrics against the
thresholds the tickets specify, in addition to standard source-file ACs.

### Acceptance Criteria

- [ ] AC1: `skills/srd/SKILL.md` documents that under `mode=data-ml` the SRD MUST contain a `## Data Requirements` section, listing the subsections it must cover (sources, schema, volume, quality/labeling).
- [ ] AC2: An SRD produced under `mode=data-ml` without a `## Data Requirements` section is flagged by the SRD audit as a gap.
- [ ] AC3: The data/ML QC behavior is defined: model-metric ACs (e.g., "model achieves >= 0.85 F1 on holdout") are verified against reported metric values.
- [ ] AC4: Model-metric ACs that require a runtime training/eval environment are recorded as PARTIAL/deferred-to-runtime (consistent with EDMV2-34), not invented or FAILed.
- [ ] AC5: The data/ML QC follows red/opus/max policy if a new agent; retains existing policy if a branch.
- [ ] AC6: `claude plugin validate` passes if a new agent file is added.
- [ ] AC7: Under `mode=standard`, the Data Requirements section is not required and model-metric QC does not apply.

### Technical Notes

- The Data Requirements section heading must be exactly `## Data Requirements` so the SRD audit can detect
  its presence/absence deterministically.
- Model-metric verification typically needs a runtime; expect many of these ACs to be PARTIAL.

### Verification

QC confirms PASS by inspection (the SRD section requirement and the model-metric QC contract) plus
`claude plugin validate` if a new agent is added; AC2 verified by a sandbox audit run flagging a missing
section.

### Out of Scope

- Bundling any ML framework or training harness (no new external dependency — C-2).
- IaC profile (EDMV2-T89).

---

## EDMV2-T91: Compliance review gate (Gate 3.5) with regulatory-traceability columns

- **Workstream**: WS-E
- **SRD Requirements**: EDMV2-46
- **Priority**: Must
- **Size**: M
- **Target Components**:
  - `skills/orchestrator/SKILL.md` — new "Gate 3.5 — Compliance review" inserted between Step 6 (Phase 5 / Gate 3, `:224-248`) and Step 7 (Phase 6, `:250-257`), conditional on `compliance_enabled=true`
  - `skills/tickets/SKILL.md` and `skills/audit-tickets/SKILL.md` — when `compliance_enabled=true`, add regulatory-traceability columns (e.g., `Regulation | Control | Evidence`) to the ticket/AC tables
  - `bin/edm-state` — Gate 3.5 records as a distinct gate marker (recommend `gate: 3.5` or `gate: "3.5"` in `gates_approved`); document in `cmd_approve_gate` usage
- **Dependencies**: EDMV2-T83 (set-mode for compliance_enabled), EDMV2-T84 (mode dispatch)

### Description

When `compliance_enabled` is true, the orchestrator inserts a compliance review gate (Gate 3.5) between
Phase 5 and Phase 6, and the ticket/AC artifacts gain regulatory-traceability columns so each ticket maps to
the regulation/control it satisfies and the evidence that demonstrates it. This is orthogonal to the
adaptation `mode` — any mode can be compliance-enabled.

### Acceptance Criteria

- [ ] AC1: `skills/orchestrator/SKILL.md` contains a "Gate 3.5 — Compliance review" step positioned after Gate 3 (Step 6) and before Phase 6 (Step 7).
- [ ] AC2: Gate 3.5 only appears in the flow when `compliance_enabled=true`; when false, the flow goes Gate 3 -> Phase 6 unchanged.
- [ ] AC3: Gate 3.5 uses `AskUserQuestion` with Approve/Revise/No-Go options and follows the EDMV2-67 rule (only explicit Approve records the gate).
- [ ] AC4: When `compliance_enabled=true`, the ticket pack tables (in `skills/tickets/SKILL.md`) include regulatory-traceability columns with documented headers.
- [ ] AC5: When `compliance_enabled=true`, `audit-tickets` checks that the traceability columns are populated (empty traceability is a finding).
- [ ] AC6: Gate 3.5 approval is recorded in `gates_approved` with a distinct, documented marker that does not collide with gates 1/2/3.
- [ ] AC7: Phase 6 does not start until Gate 3.5 is approved when `compliance_enabled=true`.
- [ ] AC8: Under `compliance_enabled=false`, the traceability columns are not added and `audit-tickets` does not require them.

### Technical Notes

- A `3.5` gate value is fine as a JSON number; if string-keying is cleaner for `jq` filters, document the
  choice and apply it consistently in `cmd_approve_gate` and `write_handoff_internal`.
- The traceability columns are additive to the existing ticket table; do not remove existing columns.

### Verification

QC confirms PASS by inspection of the conditional Gate 3.5 step, the traceability-column branch, and the
`gates_approved` marker; a sandbox `compliance_enabled=true` dry-read shows Gate 3.5 present and a
`compliance_enabled=false` dry-read shows it absent.

### Out of Scope

- A dedicated compliance auditor agent (the existing ticket auditor checks the columns; a separate agent is
  not required by EDMV2-46).
- The set of regulations themselves (project-specific; the plugin provides the columns, not the content).

---

## EDMV2-T92: Prototype path — Phases 1-2 only with clean stop

- **Workstream**: WS-E
- **SRD Requirements**: EDMV2-49
- **Priority**: Must
- **Size**: S
- **Target Components**:
  - `skills/orchestrator/SKILL.md` — prototype sub-flow branched from Step 1c (EDMV2-T84): run Step 2 (Phase 1) and Step 3 (Phase 2 SRD) only, then stop cleanly; do not advance to Phase 3+
  - `bin/edm-state` — ensure `skipped_phases` records [3,4,5,6] (or [4,5,6] if SRD audit is retained) for prototype; `cmd_archive` gating already proceeds with a warning when `mode=prototype` (EDMV2-15, `:826` per SRD §5.2.2)
- **Dependencies**: EDMV2-T84 (mode dispatch), EDMV2-T97 (skipped_phases)

### Description

Prototype mode runs only Phases 1-2 and stops cleanly, with state reflecting the truncated lifecycle. It does
not advance to tickets or implementation. The archive-gating rule already special-cases `mode=prototype` to
proceed with a warning (EDMV2-15), so a prototype can be archived without a converged code audit.

### Acceptance Criteria

- [ ] AC1: `skills/orchestrator/SKILL.md` contains a prototype sub-flow that runs planning and SRD, then stops with a clear "prototype complete — Phases 3-6 skipped" message.
- [ ] AC2: The prototype sub-flow does not spawn ticket-writer, ticket-auditor, implementer, or QC agents.
- [ ] AC3: `skipped_phases` reflects the truncated lifecycle for a prototype initiative.
- [ ] AC4: `edm-state archive` on a `mode=prototype` initiative proceeds (with a warning), not refused, even with `code_audit_converged` false/absent.
- [ ] AC5: On resume of a `mode=prototype` initiative already past Phase 2, the orchestrator reports completion rather than restarting or advancing.
- [ ] AC6: Standard mode is unaffected — it continues through all six phases.

### Technical Notes

- Decide and document whether prototype includes the Phase 3 SRD audit; SRD §4.5 says "Phases 1-2 only," so
  default to skipping Phase 3+ and record `skipped_phases` accordingly. Keep consistent with EDMV2-T97.
- The clean-stop message should tell the user how to graduate the prototype to a full initiative if desired
  (e.g., set `mode=standard` and resume).

### Verification

QC confirms PASS via a sandbox dry-read of the prototype sub-flow (stops after Phase 2, no downstream spawns)
and a `jq` assertion that `skipped_phases` is populated; AC4 verified by an archive run on a prototype-mode
state file proceeding with a warning.

### Out of Scope

- `skipped_phases` machinery itself (EDMV2-T97 owns the state field and the gate-skip handling).
- Archive gating implementation (Epic 2 / EDMV2-15).

---

## EDMV2-T93: TDD implementation mode — Red-Green-Refactor per-ticket implementer flow

- **Workstream**: WS-E
- **SRD Requirements**: EDMV2-106 (implementer half)
- **Priority**: Should
- **Size**: L
- **Target Components**:
  - `skills/orchestrator/SKILL.md` — Step 7 (Phase 6, `:250-257`): if `implementation_mode` is unset, `AskUserQuestion` at Phase 6 start to choose standard vs tdd; record via `set-mode`
  - `agents/edm-implementer.md` — TDD branch in the agent prompt: per-ticket Red-Green-Refactor (write failing test, verify red, write minimum code, verify green, refactor); no test modification after implementation begins; escalate rather than retrofit
  - `bin/edm-state` — confirm `set-mode` accepts `implementation_mode` (already in EDMV2-T83)
- **Dependencies**: EDMV2-T83 (set-mode implementation_mode), EDMV2-T84 (mode dispatch / Phase 6 entry)

### Description

TDD implementation mode (`implementation_mode: "tdd"`) makes each `edm-implementer` agent follow a strict
per-ticket Red-Green-Refactor cycle: (1) write the failing test(s) for the ticket's ACs, (2) run the suite
and confirm red, (3) write the minimum implementation to pass, (4) run the suite and confirm green, (5)
refactor while green, then the next ticket. Tests are written ticket-by-ticket as implementation proceeds —
not all upfront. Once a test is written for a ticket, the implementer must not modify that test to achieve a
pass; only implementation code may change. If the implementation cannot satisfy the tests without modifying
them, the agent escalates rather than retrofitting. Standard mode preserves v1.x behavior (basic smoke tests
per ticket; the comprehensive suite is built separately via `/edm:test`).

### Acceptance Criteria

- [ ] AC1: `skills/orchestrator/SKILL.md` Step 7 prompts via `AskUserQuestion` (standard vs tdd) at Phase 6 start when `implementation_mode` is not already set in state.
- [ ] AC2: If `implementation_mode` is already set (via `set-mode` before Phase 6), the orchestrator skips the prompt and uses the recorded value.
- [ ] AC3: The chosen mode is recorded via `edm-state set-mode <PREFIX> implementation_mode <value>`.
- [ ] AC4: `agents/edm-implementer.md` contains a TDD branch documenting the five-step Red-Green-Refactor cycle, applied per ticket.
- [ ] AC5: The TDD branch instructs writing the failing test BEFORE the implementation file for each ticket and confirming it fails (red) before writing code.
- [ ] AC6: The TDD branch prohibits modifying a ticket's test after implementation begins and instructs escalation (not test retrofitting) when the implementation cannot pass the test as written.
- [ ] AC7: The TDD branch states tests are written ticket-by-ticket as implementation proceeds, not all upfront.
- [ ] AC8: The standard branch in `agents/edm-implementer.md` is unchanged (basic smoke tests per ticket; full suite via `/edm:test`).
- [ ] AC9: `claude plugin validate` passes on the modified agent.

### Technical Notes

- The implementer must state its red/green ordering explicitly in its output so the QC TDD-compliance pass
  (EDMV2-T94) can verify it.
- "Minimum implementation" means just enough to pass the failing test — discourage gold-plating in the same
  step as the red->green transition.

### Verification

QC confirms PASS by inspection of the orchestrator Phase-6 prompt and the `edm-implementer` TDD branch (all
six TDD constraints present), plus `claude plugin validate` exit 0. A sandbox dry-read confirms the prompt
fires only when `implementation_mode` is unset.

### Out of Scope

- The QC TDD-compliance pass (EDMV2-T94).
- The actual test frameworks (project-detected; no new dependency).

---

## EDMV2-T94: TDD implementation mode — QC auditor per-ticket TDD compliance pass

- **Workstream**: WS-E
- **SRD Requirements**: EDMV2-106 (QC half)
- **Priority**: Should
- **Size**: M
- **Target Components**:
  - `agents/edm-qc-auditor.md` — new TDD-compliance pass: when `implementation_mode=tdd`, for each ticket verify the test file predates the implementation change (by agent-stated ordering) and flag test content that appears retrofitted to match behavior rather than define it
  - `skills/implement/SKILL.md` — reference the TDD compliance pass in the QC step when `implementation_mode=tdd`
- **Dependencies**: EDMV2-T93 (implementer TDD branch emits stated ordering)

### Description

In TDD mode, the `edm-qc-auditor` adds a per-ticket TDD-compliance pass: for each ticket it verifies that the
test file predates the implementation change (by the agent-stated ordering the implementer emits per
EDMV2-T93) and flags any test content that appears retrofitted to match behavior rather than to define it.
The pass reports a per-ticket TDD compliance result. In standard mode the pass does not run.

### Acceptance Criteria

- [ ] AC1: `agents/edm-qc-auditor.md` contains a TDD-compliance pass that runs only when `implementation_mode=tdd`.
- [ ] AC2: For each ticket, the pass checks that the test was written before the implementation (using the implementer's stated red/green ordering as the evidence source).
- [ ] AC3: The pass flags test content that appears retrofitted (e.g., assertions that merely mirror the implementation's actual output rather than the AC's specified behavior).
- [ ] AC4: The pass produces a per-ticket TDD-compliance result (compliant / flagged) included in the QC report.
- [ ] AC5: In `implementation_mode=standard`, the TDD-compliance pass does not run and QC behavior is unchanged from v1.x.
- [ ] AC6: The pass uses the unified severity vocabulary (EDMV2-13) for any findings it raises.
- [ ] AC7: `claude plugin validate` passes on the modified agent.

### Technical Notes

- The QC auditor cannot see file timestamps reliably across worktrees; it relies on the implementer's stated
  ordering (EDMV2-T93 AC requires the implementer to state it) plus heuristic inspection of test content.
- A retrofitted-test heuristic: a test that asserts the exact serialized output of the implementation rather
  than the AC's described contract is a candidate flag.

### Verification

QC confirms PASS by inspection of the TDD-compliance pass in `agents/edm-qc-auditor.md` (conditional on
`implementation_mode=tdd`, per-ticket result, retrofit flagging) plus `claude plugin validate` exit 0.

### Out of Scope

- The implementer TDD flow (EDMV2-T93).
- QC sharding (WS-C, separate epic) — this pass composes with sharded QC but does not implement sharding.

---

## EDMV2-T95: Mode-aware scaffold in edm-init for all adaptation profiles

- **Workstream**: WS-E
- **SRD Requirements**: EDMV2-51
- **Priority**: Should
- **Size**: M
- **Target Components**:
  - `bin/edm-init` — accept the selected `mode` (via flag `--mode <value>` or by reading state after `edm-state init`) and scaffold the mode-appropriate directory shape; the flat `mkdir -p "$DIR/code-audit"` at `:19` becomes mode-aware
  - `bin/edm-init:29-36` — the next-step message reflects the mode (coordinated with EDMV2-19/G13)
- **Dependencies**: EDMV2-T83 (set-mode), EDMV2-T86 (mini-SRD scaffold contract), EDMV2-T37 (EDMV2-88)

### Description

`edm-init` scaffolds the directory according to the selected mode: mini-SRD omits `tickets/`; prototype may
omit ticket/QC slots; standard/IaC/data-ML use the full shape (with the data/ML SRD expecting a Data
Requirements section, but that is content, not a directory). This consolidates the per-mode scaffold branches
that EDMV2-T86 sketched for mini-SRD into one mode-aware scaffold.

### Acceptance Criteria

- [ ] AC1: `edm-init` accepts the mode (via `--mode <value>` flag or post-init state read) and branches its `mkdir` accordingly.
- [ ] AC2: `mode=mini-srd` scaffolding produces no `tickets/` directory.
- [ ] AC3: `mode=standard` (and `iac`, `data-ml`) scaffolding produces the full documented shape including `tickets/` and `code-audit/`.
- [ ] AC4: `mode=prototype` scaffolding produces the documented prototype shape (no ticket/QC slots if those phases are skipped).
- [ ] AC5: An invalid `--mode` value exits non-zero with a message naming the valid values.
- [ ] AC6: The next-step message printed by `edm-init` references the selected mode and a valid current command/path (satisfies EDMV2-19/G13 for the mode-aware case).
- [ ] AC7: Omitting `--mode` defaults to `standard` and reproduces the v1.x scaffold shape (plus any WS-M layout changes from Epic 2).
- [ ] AC8: The scaffold derives paths from state/config, not hardcoded flat `SRD/{PREFIX}` (consistent with EDMV2-88).

### Technical Notes

- Coordinate with EDMV2-T86 so the mini-SRD branch is implemented once here, not duplicated.
- `edm-init` runs `edm-state init` at `:20`; the mode must be set on state (via `set-mode`) before or right
  after init so the scaffold can read it, OR passed as the `--mode` flag directly.

### Verification

QC confirms PASS by scaffolding sandbox initiatives in each mode and asserting the directory shape per AC2-A4
and the default-standard equivalence (AC7); invalid `--mode` exits non-zero (AC5).

### Out of Scope

- The mini-SRD fused-file contract (EDMV2-T86 defines it; this ticket only omits `tickets/`).
- WS-M product-scoped layout (Epic 2) — this ticket layers mode-awareness on top of whatever layout WS-M
  produces.

---

## EDMV2-T96: First-class phase-skip — skipped_phases state and gate-skip handling

- **Workstream**: WS-F
- **SRD Requirements**: EDMV2-52
- **Priority**: Must
- **Size**: M
- **Target Components**:
  - `bin/edm-state` — `cmd_init` adds `skipped_phases: []`; new helper or `set`-based path to append a skipped phase with rationale; gate-derivation logic in `write_handoff_internal` (`:665-692`) must not flag a skipped phase's gate as "pending"
  - `bin/edm-state` — `cmd_approve_gate` / completion logic: a skipped phase's gate is neither required nor falsely blocking
  - `skills/orchestrator/SKILL.md` — record skipped phases (with rationale) when a sub-flow truncates the lifecycle
- **Dependencies**: EDMV2-T83 (set-mode established the mode-family pattern), EDMV2-T48 (EDMV2-94 handoff refactor)

### Description

Phase-skip becomes first-class: state records which phases were intentionally skipped (rather than recording
"N/A (partial EDM)" only as prose), each with an explicit rationale, and gates for skipped phases are handled
without false blocking. This is the foundation prototype mode (EDMV2-T92) and mini-SRD (EDMV2-T88) build on
when they truncate the lifecycle, and it directly serves partial-EDM initiatives.

### Acceptance Criteria

- [ ] AC1: `cmd_init` writes `skipped_phases: []` (additive, defaulted) so v1.x files default safely.
- [ ] AC2: There is a documented path to record a skipped phase WITH a rationale (the rationale is persisted, not just the phase number).
- [ ] AC3: Skipping Phases 4-5 records `[4,5]` (or equivalent objects with rationale) in state.
- [ ] AC4: `write_handoff_internal`'s next-action derivation does not present a skipped phase's gate as "pending."
- [ ] AC5: Completion/archive logic does not block on a gate that belongs to a skipped phase.
- [ ] AC6: A standard initiative with no skipped phases behaves exactly as v1.x (empty `skipped_phases`).
- [ ] AC7: The recorded rationale is retrievable (via `get` / surfaced in HANDOFF per EDMV2-T99).
- [ ] AC8: The write goes through the EDMV2-70 advisory lock.
- [ ] AC9: A fixture `.edm-state.json` lacking `skipped_phases` is read without error; resolves to `[]` via `jq // []`.

### Technical Notes

- Recommend storing `skipped_phases` as an array of objects `{phase: N, rationale: "..."}` so the rationale
  travels with the phase; if a flat number array is chosen, store rationale in a parallel map and document it.
- The gate-skip handling touches `write_handoff_internal`'s `case "$phase"` next-action block (`:668-692`)
  and any completion check — audit all gate-pending derivations.

### Verification

QC confirms PASS via a sandbox state file with `skipped_phases=[4,5]`: HANDOFF shows no false "Gate pending"
for those phases (AC4), archive is not blocked by them (AC5), and the rationale is retrievable (AC7).

### Out of Scope

- The HANDOFF rendering of skipped phases (EDMV2-T99 renders; this ticket ensures correct gate logic).
- Prototype/mini-SRD sub-flows (they consume this; EDMV2-T88/T92).

---

## EDMV2-T97: Fast-track / fix-pack lifecycle mode — tickets-from-analysis with valid minimal state

- **Workstream**: WS-F
- **SRD Requirements**: EDMV2-53
- **Priority**: Must
- **Size**: M
- **Target Components**:
  - `skills/orchestrator/SKILL.md` — fast-track sub-flow: when `lifecycle_mode` ∈ {fast-track, fix-pack}, generate tickets directly from an analysis document with a valid minimal `.edm-state.json`, skipping the full SRD/ticket-audit phases
  - `bin/edm-init` / `bin/edm-state` — ensure a fix-pack initiative produces a valid (minimal) state file recognized as fast-track, not flagged as incomplete/broken
  - `bin/edm-state` `validate` (EDMV2-73, Epic 2) — recognize fast-track/fix-pack as a valid shape, not an anomaly
- **Dependencies**: EDMV2-T83 (set-mode lifecycle_mode), EDMV2-T96 (skipped_phases)

### Description

A fast-track/fix-pack mode supports generating tickets directly from an analysis document with a valid
minimal `.edm-state.json`, so this common bug-fix-pack workflow is not indistinguishable from a broken EDM
run. The state file is valid and recognized as fast-track; the `validate` subcommand and HANDOFF treat it as
intentional, not incomplete.

### Acceptance Criteria

- [ ] AC1: `skills/orchestrator/SKILL.md` documents a fast-track sub-flow that takes an analysis document and produces tickets without the full Phase 2-3 SRD + Phase 5 ticket-audit sequence.
- [ ] AC2: A fix-pack initiative has a valid minimal `.edm-state.json` with `lifecycle_mode` set to `fast-track` or `fix-pack`.
- [ ] AC3: The `validate` subcommand (EDMV2-73) does NOT flag a well-formed fast-track/fix-pack state file as anomalous or incomplete.
- [ ] AC4: The skipped phases for fast-track are recorded via `skipped_phases` (consistent with EDMV2-T96).
- [ ] AC5: HANDOFF surfaces the fast-track/fix-pack mode (coordinated with EDMV2-T99) so a teammate sees it is intentional.
- [ ] AC6: A standard-lifecycle initiative is unaffected.
- [ ] AC7: The fast-track sub-flow still records gate/phase markers sufficient for completion/archive logic to function.

### Technical Notes

- Coordinate the "not flagged as incomplete" requirement with the Epic 2 `validate` subcommand owner so
  fast-track is in `validate`'s allow-list of intentional shapes.
- The minimal state file should still carry `prefix`, `current_phase`, and `lifecycle_mode` so `list` and
  HANDOFF render correctly.

### Verification

QC confirms PASS by creating a sandbox fix-pack initiative and asserting: `validate` exits 0 / reports no
incompleteness (AC3), `lifecycle_mode` is set (AC2), `skipped_phases` is populated (AC4), and the orchestrator
sub-flow is documented (AC1).

### Out of Scope

- The `validate` subcommand implementation (Epic 2 / EDMV2-73) — this ticket only ensures fast-track is
  recognized, coordinating with that ticket.
- HANDOFF rendering (EDMV2-T99).

---

## EDMV2-T98: Supersede / fork provenance — supersedes and forked_from fields with subcommands

- **Workstream**: WS-F
- **SRD Requirements**: EDMV2-54
- **Priority**: Must
- **Size**: S
- **Target Components**:
  - `bin/edm-state` — `cmd_init` adds `supersedes: ""` and `forked_from: ""`; new `set-supersedes <PREFIX> <other>` and `set-forked-from <PREFIX> <other>` arms (or fold into `set-mode`-style typed setters), with dispatch `case` entries (`:777-800`) and `--help` docs
- **Size**: S
- **Dependencies**: EDMV2-T83 (set-mode pattern), EDMV2-T48 (EDMV2-94)

### Description

Supersede and fork relationships become recordable so a re-scope of an existing initiative carries a
provenance link rather than appearing as an orphan. A forked initiative records its origin prefix; HANDOFF
surfaces the link (rendering lands in EDMV2-T99). Because PREFIX is globally unique (EDMV2-87), these fields
store bare prefix strings that resolve unambiguously.

### Acceptance Criteria

- [ ] AC1: `cmd_init` writes `supersedes: ""` and `forked_from: ""` (additive, defaulted) so v1.x files default safely.
- [ ] AC2: A subcommand sets `supersedes` to a bare prefix and persists it (verified via `jq -r .supersedes`).
- [ ] AC3: A subcommand sets `forked_from` to a bare prefix and persists it.
- [ ] AC4: The fields are independent — setting one does not clear the other.
- [ ] AC5: Setting an empty/blank value or wrong arg count exits non-zero with a usage message.
- [ ] AC6: The write goes through the EDMV2-70 advisory lock and updates `.last_updated`.
- [ ] AC7: The new subcommands appear in `edm-state --help`.
- [ ] AC8: A standard initiative with neither field set behaves exactly as v1.x.
- [ ] AC9: A fixture `.edm-state.json` lacking `supersedes`/`forked_from` is read without error; both resolve to `""` via `jq // ""`.

### Technical Notes

- Either two dedicated subcommands or an extension of `set-mode`'s kind set (e.g., `set-mode <PREFIX> supersedes <prefix>`) is acceptable; if folding into `set-mode`, document that these kinds take free-string prefix values, not enums. Prefer keeping `set-mode` enum-only and adding dedicated provenance setters for clarity.
- Do not validate that the referenced prefix exists (a superseded initiative may be archived); store the
  bare string and let resolution be best-effort.

### Verification

QC confirms PASS via sandbox `set`/`get` round-trips on both fields independently (AC2-A4), the
empty-value/arg-count guards (AC5), and `--help` presence (AC7).

### Out of Scope

- HANDOFF rendering of the provenance chain (EDMV2-T99).
- Resolving/validating the referenced initiative's directory (best-effort only).

---

## EDMV2-T99: Lifecycle-mode, skipped-phases, and provenance rendering in HANDOFF

- **Workstream**: WS-F
- **SRD Requirements**: EDMV2-56
- **Priority**: Should
- **Size**: M
- **Target Components**:
  - `bin/edm-state` — `write_handoff_internal()` (`:631-766`): render the active `lifecycle_mode`, the `mode` adaptation profile, `skipped_phases` (with rationale), and the provenance chain (`supersedes`/`forked_from`); ASCII-only per EDMV2-21/G15
  - `bin/edm-state:737-765` — the HANDOFF document body: add a "## Lifecycle & Mode" section and surface skipped phases and provenance
- **Dependencies**: EDMV2-T48 (EDMV2-94/95 Resume Point + render refactor), EDMV2-T96 (skipped_phases), EDMV2-T98 (provenance fields), EDMV2-T83 (mode fields), EDMV2-T67, EDMV2-T81, EDMV2-T103

### Description

HANDOFF.md renders the active lifecycle mode, the adaptation profile, any skipped phases (with their
rationale), and the supersede/fork provenance chain, so a resuming teammate immediately understands the
deviation from the standard flow and where the initiative came from. All rendering is ASCII-only
(EDMV2-21/G15) and derived from state, not hand-written.

### Acceptance Criteria

- [ ] AC1: `write_handoff_internal` renders a section showing `mode` and `lifecycle_mode` (e.g., "Mode: iac | Lifecycle: fast-track").
- [ ] AC2: When `skipped_phases` is non-empty, HANDOFF lists each skipped phase with its rationale.
- [ ] AC3: When `supersedes` is set, HANDOFF shows "Supersedes: {PREFIX}"; when `forked_from` is set, shows "Forked from: {PREFIX}".
- [ ] AC4: When all mode/lifecycle/provenance fields are at defaults (standard initiative), HANDOFF does not add empty noise — the standard-flow HANDOFF is unchanged or shows "Mode: standard | Lifecycle: standard" only.
- [ ] AC5: All rendered content is ASCII-only (`grep -P '[^\x00-\x7F]'` over generated HANDOFF returns nothing) — consistent with EDMV2-21/G15.
- [ ] AC6: The rendered values are derived from state fields, not hand-written (changing `lifecycle_mode` in state and re-running `write-handoff` changes the rendered value).
- [ ] AC7: The existing Resume Point section (EDMV2-94) and the user-editable `## Notes` section are preserved.
- [ ] AC8: The HANDOFF for a partial-EDM initiative shows the mode and skipped phases (EDMV2-56 verification).
- [ ] AC9: T99 is the owner of the final `write_handoff_internal()` section sequence; it must ensure all four new sections (PARTIAL verdicts from T67, WS-D checklist from T81, Lifecycle & Mode from T99, Related Initiatives from T103) appear in documented order and the `## Notes` parse (`:729-731`) and `## Key Decisions Made` parse (`:719-720`) still work correctly.

### Technical Notes

- Build on the EDMV2-94 handoff render refactor — add the new section to the existing `{ ... } > "$handoff_path"`
  heredoc block (`:737-765`), reading the fields with `jq` `//` defaults so v1.x files render cleanly.
- The Notes-preservation `awk` at `:729-731` must continue to work — add the new section before `## Notes`.
- T99 is the integration ticket for `write_handoff_internal()` — it must land after T67, T81, and T103 to sequence all new sections correctly.

### Verification

QC confirms PASS by running `write-handoff` against sandbox state files: (1) a fully-decorated state
(iac/fast-track, skipped [4,5] with rationale, forked_from set) renders all four facets; (2) a default state
renders only the minimal mode line; (3) the ASCII check passes; (4) the Notes section survives a re-write.

### Out of Scope

- The Resume Point section content (EDMV2-94, Epic 2).
- Product-line linkage rendering (parent/related — WS-G, separate epic, though it shares this render block).

---

## EDMV2-T100: WS-E/F integration verification and mode-matrix sandbox checks

- **Workstream**: WS-E / WS-F
- **SRD Requirements**: EDMV2-44, EDMV2-55 (integration verification across the mode matrix); cross-cutting closure for the epic
- **Priority**: Must
- **Size**: S
- **Target Components**:
  - `bin/edm-state` — no new behavior; this ticket adds documented bash unit checks (the C-2 verification mechanism) exercising the mode matrix
  - documented sandbox-check notes (recorded in the testing layer's verification notes, mirroring the EDMV2-02 pattern)
- **Dependencies**: EDMV2-T83, T84, T86, T88, T89, T90, T91, T92, T93, T94, T95, T96, T97, T98, T99

### Description

A single integration ticket that verifies the orthogonality and composition of the mode family end-to-end:
`mode` and `lifecycle_mode` are independent; `compliance_enabled` composes with any `mode`;
`implementation_mode` is independent of both; and a combined initiative (e.g., `iac` + `fast-track` +
`compliance_enabled` + `tdd`) round-trips through state, scaffold, orchestrator dispatch, and HANDOFF without
contradiction. This closes the epic by proving the pieces compose, since the individual tickets each verify
only their own slice.

### Acceptance Criteria

- [ ] AC1: A documented bash check sets `mode=iac` and `lifecycle_mode=fast-track` on one initiative and asserts both persist independently (orthogonality, EDMV2-44).
- [ ] AC2: A check sets `compliance_enabled=true` on a `mode=mini-srd` initiative and asserts both coexist (compliance is a flag, not a mode).
- [ ] AC3: A check sets `implementation_mode=tdd` independently of `mode`/`lifecycle_mode` and asserts no cross-clobbering.
- [ ] AC4: A check confirms `edm-state get` on a fully-decorated initiative returns all mode-family fields with correct types (boolean for `compliance_enabled`, strings for the enums).
- [ ] AC5: A check confirms `write-handoff` on the fully-decorated initiative renders mode, lifecycle, skipped phases, and provenance with no Unicode (composes EDMV2-T99).
- [ ] AC6: A check confirms a `mode=standard` + all-defaults initiative reproduces v1.x state and HANDOFF (regression guard for C-4).
- [ ] AC7: The checks are recorded in the testing layer's verification notes so they are re-runnable (EDMV2-02 pattern).
- [ ] AC8: `claude plugin validate` passes with all WS-E/F changes merged (EDMV2-101 closure for this epic's surface).

### Technical Notes

- These are bash unit checks against `bin/edm-state` plus markdown-inspection assertions on the orchestrator
  and agent prompts — the only verification mechanisms available under C-2 (no CI/build).
- Run after all other epic tickets merge; this is the epic's integration gate.

### Verification

QC confirms PASS by running the documented bash checks (all assertions green), the ASCII check on the
fully-decorated HANDOFF, the C-4 regression check (AC6), and `claude plugin validate` exit 0 (AC8).

### Out of Scope

- New mode behavior (all behavior is delivered by T83-T99; this ticket only verifies composition).
- WS-G/H/J/etc. integration (other epics).

---

## Epic 5 coverage summary

| SRD Req | Title | Ticket(s) |
|---|---|---|
| EDMV2-44 | Mode concept in state + orchestrator | T83 (state) + T84 (orchestrator) + T100 (orthogonality verify) |
| EDMV2-45 | mini-SRD mode | T86 (state/scaffold contract) + T88 (orchestrator fused flow) |
| EDMV2-46 | Compliance review gate (Gate 3.5) | T91 |
| EDMV2-47 | IaC profile | T89 |
| EDMV2-48 | Data/ML profile | T90 |
| EDMV2-49 | Prototype path | T92 |
| EDMV2-50 | Mode selection UX | T84 |
| EDMV2-51 | Mode-aware scaffold | T95 (consolidates T86's mini-SRD scaffold) |
| EDMV2-106 | TDD implementation mode | T93 (implementer) + T94 (QC pass) |
| EDMV2-52 | First-class phase-skip | T96 |
| EDMV2-53 | Fast-track / fix-pack | T97 |
| EDMV2-54 | Supersede / fork provenance | T98 |
| EDMV2-55 | set-mode subcommand | T83 + T100 (verify) |
| EDMV2-56 | Lifecycle-mode HANDOFF rendering | T99 |
| EDMV2-102 (WS-E/F slice) | mode + compliance_enabled userConfig keys | T85 |

> **Numbering note:** T87 is reserved (mini-SRD decomposed into T86+T88). The 17 active tickets are
> T83-T86, T88-T100. No SRD requirement in this epic's scope is orphaned. The README index should reflect
> T87 as reserved (or renumber T88-T100 down by one if a contiguous range is required).
