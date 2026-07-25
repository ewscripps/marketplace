# Epic 4 — WS-D: Canonical Artifact Homes

Generated From: srd.md v1.0.7

WS-D gives the recurring real artifacts that today leak into sidecars or HANDOFF prose a single canonical, state-derived home inside each initiative directory: the architecture doc (`architecture.md`), explorer findings (`explorers/`), a decision/audit ledger (`decisions.md`), a rollback runbook (`ROLLBACK.md`), per-epic execution reports (`exec-report.md`), and post-deploy verification / analysis-input slots. These slots are defined in CLAUDE.md, scaffolded (where always-present) by `bin/edm-init`, rendered/referenced by `write_handoff_internal()` in `bin/edm-state`, and written by the orchestrator flow and the `edm-architect` / `edm-explorer` agents.

This epic covers SRD requirements EDMV2-38 through EDMV2-43 (SRD §4.4, §5.2.6, §6.3) across tickets EDMV2-T73 through EDMV2-T82.

## Cross-cutting dependency note (read first)

WS-D is a **Phase B** workstream (SRD §5.7) and depends on the **Epic 2 foundation (EDMV2-T24 through EDMV2-T54 range)**, specifically:

- **EDMV2-85 (WS-M new directory layout)** — every WS-D path MUST be derived from the `state_file_for()`-resolved initiative directory `SRD/{PRODUCT}/{PREFIX}__{DESCRIPTION}/`, never from the flat `SRD/{PREFIX}/` layout. No WS-D ticket may hardcode `${SRD_ROOT}/${prefix}/...`. When `product_name`/`initiative_description` are absent (legacy/v1 initiative), the same path helper must resolve the flat layout so WS-D slots also work for existing initiatives (EDMV2-90 backward compatibility).
- **EDMV2-88 (state-derived path construction)** — WS-D introduces a single directory-resolver call site (mirroring `state_file_for()`) that all WS-D readers/writers use to compute their slot paths.
- **EDMV2-86 (edm-init `--product`/`--description`)** — `edm-init` scaffolding changes in this epic are layered on top of the WS-M init rewrite; they must compose, not conflict.

Because the WS-M directory work lands first, the WS-D tickets here assume the resolver exists and `initiative_dir_for()` (introduced by T37, Epic 2) is available in `bin/edm-state`. T73 explicitly wires WS-D call sites to that shared resolver so the other WS-D tickets reference one seam.

---

## EDMV2-T73: Add a shared state-derived initiative-directory resolver for WS-D slots

| Field | Value |
|---|---|
| Workstream | WS-D |
| SRD Requirements | EDMV2-38, EDMV2-39, EDMV2-40, EDMV2-41, EDMV2-42, EDMV2-43 (foundation), EDMV2-88 |
| Priority | Must |
| Size | S |
| Phase | 4 (Tickets) / implements in Phase B |

**Target Components**
- `plugins/edm-ai-development-staging/bin/edm-state` — call the `initiative_dir_for()` function introduced by T37 (Epic 2, EDMV2-T37) rather than creating a new `dir_for` helper; expose it within WS-D's call sites under the `dir_for` alias if needed for internal brevity. Refactor `write_handoff_internal()` path vars (`:704-708`, `:726`) and `cmd_write_handoff` echo (`:771`) to call `initiative_dir_for()`.
- `plugins/edm-ai-development-staging/CLAUDE.md` — document that all per-initiative artifact paths (including all WS-D slots) are derived through the `initiative_dir_for()` resolver from T37.

**Dependencies**
- EDMV2-T37 (Epic 2) — provides `initiative_dir_for()`, which this ticket calls rather than creating a duplicate resolver. T37 must land before T73.
- EDMV2-T (WS-M, EDMV2-85/88) — the `state_file_for()` layout switch and state-derived path construction must already be in place; `initiative_dir_for()` reuses the same `product_name`/`initiative_description` resolution logic. WS-D depends on the Epic 2 foundation (T24-T54 range).

### Description
WS-D defines six new artifact slots, each of which needs the same answer to "where is this initiative's directory?". Today `write_handoff_internal()` hardcodes `${SRD_ROOT}/${prefix}/...` in five places (`bin/edm-state:704-708`), which silently breaks under the WS-M `SRD/{PRODUCT}/{PREFIX}__{DESCRIPTION}/` layout. Rather than have each WS-D ticket re-derive the path, this ticket wires all WS-D call sites to call `initiative_dir_for()` — the resolver already introduced by T37 (Epic 2). T37 owns the function definition; this ticket is the WS-D adoption seam.

This concentrates the layout dependency in a single seam (matching the architectural decision in SRD §5.6 Risk 2 mitigation), so a future layout change touches one function. It also guarantees WS-D slots work for both the new layout and legacy flat initiatives (EDMV2-90).

### Acceptance Criteria
- [ ] AC1: `edm-state` calls `initiative_dir_for()` (from T37) at all WS-D path resolution sites; no duplicate resolver function is introduced by this ticket.
- [ ] AC2: For a state file with `product_name=edm` and `initiative_description=enhance-edm-plugin`, `initiative_dir_for EDMV2` resolves to `${SRD_ROOT}/edm/EDMV2__enhance-edm-plugin`.
- [ ] AC3: For a state file with empty/absent `product_name` and `initiative_description`, `initiative_dir_for LEGACY` resolves to `${SRD_ROOT}/LEGACY` (flat layout, EDMV2-90 backward compatibility).
- [ ] AC4: `write_handoff_internal()` no longer contains any literal `${SRD_ROOT}/${prefix}/` path construction; all five artifact path vars (`:704-708`) are derived via `initiative_dir_for()`.
- [ ] AC5: `cmd_write_handoff` echoes the `initiative_dir_for()`-resolved `HANDOFF.md` path, not a hardcoded flat path.
- [ ] AC6: `initiative_dir_for()` reads through `state_file_for()` semantics so a relocated initiative (via `migrate-path`, EDMV2-89) resolves to its new directory without code changes.
- [ ] AC7: Running `write-handoff` on a pre-existing flat-layout initiative produces HANDOFF.md at the unchanged flat path (no regression).
- [ ] AC8: CLAUDE.md documents that WS-D slot paths are derived from state via `initiative_dir_for()` and never hardcoded.

### Technical Notes
- `initiative_dir_for()` is defined by T37 (Epic 2); this ticket must not redefine it. Verify the function signature and behavior against T37 before calling.
- `initiative_dir_for()` should not require the directory to exist (it is used both to read existing slots and to compute write targets) — confirm T37's implementation satisfies this or raise with T37.
- Mirror the existing jq `//` default pattern (`:642`, `:657`) so absent fields default cleanly.

### Out of Scope
- The WS-M `state_file_for()` layout switch itself (Epic 2 / EDMV2-85).
- Defining the individual WS-D slot contents (T74-T81).

### Verification
QC confirms PASS by: (1) sourcing the script and calling `initiative_dir_for()` against two crafted state files (new-layout and flat-layout) and diffing the echoed path against the expected string; (2) `grep -n 'SRD_ROOT}/\${prefix}/' bin/edm-state` returns nothing inside `write_handoff_internal`; (3) running `write-handoff` against a flat fixture leaves HANDOFF.md at the legacy path; (4) `grep -n 'dir_for\b' bin/edm-state` shows no standalone `dir_for` function definition (only calls that resolve through `initiative_dir_for()`).

---

## EDMV2-T74: Define the canonical architecture-doc home (`architecture.md`)

| Field | Value |
|---|---|
| Workstream | WS-D |
| SRD Requirements | EDMV2-38 |
| Priority | Must |
| Size | S |
| Phase | 4 (Tickets) / implements in Phase B |

**Target Components**
- `plugins/edm-ai-development-staging/agents/edm-architect.md` — change the agent's write target from `arch-section5.md` sidecars / inline SRD sections to the canonical `architecture.md` in the resolved initiative directory; document that diagrams and architecture decisions live there.
- `plugins/edm-ai-development-staging/skills/orchestrator/SKILL.md` — Step 3 (Phase 2, `:184`): `edm-architect` writes Target Architecture to `{dir_for}/architecture.md`; the SRD's Section 5 references it rather than duplicating it.
- `plugins/edm-ai-development-staging/CLAUDE.md` — add `architecture.md` to the project artifact layout block (after `audit-srd.md`).

**Dependencies**
- EDMV2-T73 (WS-D resolver). Transitively depends on EDMV2-85 (WS-M layout) via T73.

### Description
The `edm-architect` agent currently has no single canonical output location — its Section 5 work lands either inline in `srd.md` or in inconsistent `arch-section5.md` sidecars (SRD §5.2.4, EDMV2-38). This ticket establishes `architecture.md` as the canonical home for the architect's diagrams and decisions inside the resolved initiative directory.

The SRD's Section 5 (Target Architecture) continues to exist but references `architecture.md` for the detailed diagrams and decision records, so the architecture content has one authoritative source and stops being duplicated or scattered.

### Acceptance Criteria
- [ ] AC1: `agents/edm-architect.md` instructs the agent to write its output to `architecture.md` in the state-derived initiative directory (via the T73 resolver), not to `arch-section5.md` or an inline-only section.
- [ ] AC2: The orchestrator Step 3 explicitly names `architecture.md` as the `edm-architect` write target.
- [ ] AC3: `architecture.md` content scope is documented: architecture decision records, component diagrams (Mermaid), sequence diagrams, and rejected-alternatives table.
- [ ] AC4: The path is derived from state (resolves correctly under both `SRD/{PRODUCT}/{PREFIX}__{DESCRIPTION}/` and legacy flat layouts); no hardcoded `arch-section5.md` reference remains in the architect agent or orchestrator.
- [ ] AC5: CLAUDE.md's artifact-layout block lists `architecture.md` with a one-line description ("canonical home for edm-architect diagrams and decisions").
- [ ] AC6: `grep -rn 'arch-section5' agents/ skills/` returns nothing after the change.
- [ ] AC7: The architect's content is ASCII-only per C-1/EDMV2-21 (no Unicode arrows/glyphs in the emitted diagrams' prose).

### Technical Notes
- Mermaid fenced blocks are permitted; the ASCII constraint applies to emitted prose markers, not to standard Mermaid syntax.
- The architect runs in parallel with `edm-srd-writer` (orchestrator `:184`); ensure no write race on the same file — `architecture.md` is the architect's file, `srd.md` is the srd-writer's file.

### Out of Scope
- Changing the `edm-architect` color/model/effort (Non-Goal — retained).
- The explorer-findings home (T75).

### Verification
QC confirms PASS by: (1) inspecting `agents/edm-architect.md` for the `architecture.md` write instruction and absence of `arch-section5`; (2) confirming orchestrator Step 3 names the file; (3) `grep -rn 'arch-section5' plugins/edm-ai-development-staging/` is empty; (4) CLAUDE.md layout block includes the entry.

---

## EDMV2-T75: Define the canonical explorer-findings home (`explorers/`) and synthesis step

| Field | Value |
|---|---|
| Workstream | WS-D |
| SRD Requirements | EDMV2-39 |
| Priority | Must |
| Size | M |
| Phase | 4 (Tickets) / implements in Phase B |

**Target Components**
- `plugins/edm-ai-development-staging/agents/edm-explorer.md` — each parallel explorer writes its findings to `explorers/explorer-{NN}-{slug}.md` (or `explorers/{focus-area}.md`) inside the resolved initiative directory, instead of ad-hoc top-level `explorer-*.md` sidecars.
- `plugins/edm-ai-development-staging/skills/orchestrator/SKILL.md` — Step 2 (Phase 1, `:99-100`): spawn explorers writing into `explorers/`, then add a documented synthesis step that reads all `explorers/*.md` and folds them into `planning.md`.
- `plugins/edm-ai-development-staging/bin/edm-init` — scaffold the `explorers/` subdirectory at init (alongside `code-audit/`).
- `plugins/edm-ai-development-staging/CLAUDE.md` — document `explorers/` in the artifact layout.

**Dependencies**
- EDMV2-T73 (WS-D resolver). Transitively depends on EDMV2-85/86 (WS-M layout + edm-init `--product`/`--description`) — the `edm-init` scaffold change here must compose with the WS-M init rewrite.

### Description
Phase 1 commonly spawns multiple parallel `edm-explorer` agents (SRD §1: four explorers for EDMV2 itself). Their outputs currently land as ad-hoc `explorer-*.md` sidecars with no defined home or synthesis contract, so findings are inconsistently named and the path from raw exploration to `planning.md` is undocumented (EDMV2-39).

This ticket defines `explorers/` as the canonical home for parallel explorer reports and adds an explicit, documented synthesis step in the orchestrator: explorers write into `explorers/`, then the orchestrator reads all explorer reports and synthesizes them into `planning.md`. This makes both the raw findings and the synthesis traceable and source-controlled.

### Acceptance Criteria
- [ ] AC1: `agents/edm-explorer.md` instructs each explorer to write to `explorers/` with a stable per-explorer filename derived from its focus area (e.g., `explorers/01-plugin-surface.md`).
- [ ] AC2: Orchestrator Step 2 spawns explorers writing into the `explorers/` slot resolved via the T73 helper, not flat sidecars.
- [ ] AC3: Orchestrator Step 2 contains an explicit synthesis sub-step: read all `explorers/*.md`, then write the consolidated result into the documented `planning.md` sections (`## Current State`, `## Gap Analysis`, `## Component Inventory`).
- [ ] AC4: `bin/edm-init` scaffolds an `explorers/` directory in the new initiative (and this composes with the WS-M product-scoped path so the directory is created under `SRD/{PRODUCT}/{PREFIX}__{DESCRIPTION}/`).
- [ ] AC5: A single-explorer initiative still works: one explorer writes one file into `explorers/` and synthesis is a no-op merge.
- [ ] AC6: The `explorers/` path is state-derived; resolving under the legacy flat layout produces `SRD/{PREFIX}/explorers/`.
- [ ] AC7: CLAUDE.md artifact-layout block lists `explorers/` with a description and notes the synthesis-into-`planning.md` step.
- [ ] AC8: `grep -rn 'explorer-\*\.md\|top-level explorer sidecar' agents/ skills/` shows the old ad-hoc pattern is removed in favor of `explorers/`.

### Technical Notes
- Keep filenames slugged ASCII (C-1); two-digit numeric prefixes keep ordering stable.
- The synthesis step is orchestrator prose (the orchestration layer is a prompt, SRD §5.0), not a new bin script.
- `edm-init` scaffolding must remain idempotent and must not fail if `explorers/` already exists.

### Out of Scope
- Auto-merging conflicting explorer conclusions (synthesis is the orchestrator's judgment call, documented but not automated).
- Changing explorer color/model (Non-Goal — retained yellow/opus).

### Verification
QC confirms PASS by: (1) `edm-init` on a fresh prefix produces an `explorers/` directory under the resolved initiative path; (2) `agents/edm-explorer.md` and orchestrator Step 2 reference `explorers/` and the synthesis step; (3) resolving the path against a flat-layout fixture yields `SRD/{PREFIX}/explorers/`.

---

## EDMV2-T76: Define the decision/audit ledger artifact (`decisions.md`)

| Field | Value |
|---|---|
| Workstream | WS-D |
| SRD Requirements | EDMV2-40 |
| Priority | Must |
| Size | M |
| Phase | 4 (Tickets) / implements in Phase B |

**Target Components**
- `plugins/edm-ai-development-staging/bin/edm-state` — `write_handoff_internal()` (`:756-757`, the `## Key Decisions Made` block): instead of embedding large finding-to-commit / key-decisions tables inline, render a short summary plus a link to `decisions.md` (resolved via T73 `dir_for`).
- `plugins/edm-ai-development-staging/skills/orchestrator/SKILL.md` — at each gate-decision point (Gate 1 decisions, Gate 2 architecture decisions, Phase 6 finding-to-commit), append running entries to `decisions.md` rather than overloading HANDOFF.md.
- `plugins/edm-ai-development-staging/bin/edm-init` — scaffold an empty `decisions.md` with its documented section headers at init.
- `plugins/edm-ai-development-staging/CLAUDE.md` — document `decisions.md` in the artifact layout.

**Dependencies**
- EDMV2-T73 (WS-D resolver). Coordinate with the WS-B findings ledger (EDMV2-31, `code-audit/findings-ledger.md`): `decisions.md` is the **initiative-wide** decision/finding-to-commit ledger; the WS-B findings ledger is the **code-audit cross-round** ledger. They are distinct files with distinct scopes; document the distinction.

### Description
Today, key-decisions lists and finding-to-commit tables overload `HANDOFF.md` (the `## Key Decisions Made` section at `bin/edm-state:756-757` pulls from `planning.md`, and Phase 6 finding-to-commit tables have no home). As initiatives grow, these tables bloat HANDOFF and make it harder to scan for resume state (EDMV2-40).

This ticket establishes `decisions.md` as the canonical running ledger of key decisions and finding-to-commit mappings. HANDOFF.md references `decisions.md` and renders only a compact summary, restoring HANDOFF's role as a fast resume document.

### Acceptance Criteria
- [ ] AC1: `decisions.md` has a defined structure with at least: a `## Key Decisions` table (decision, rationale, date, gate/phase) and a `## Finding-to-Commit` table (finding ID, resolution, commit/PR ref).
- [ ] AC2: `bin/edm-init` scaffolds `decisions.md` with the documented section headers (empty tables) in the resolved initiative directory.
- [ ] AC3: `write_handoff_internal()` `## Key Decisions Made` block renders a compact summary (or last N decisions) plus an explicit link/path reference to `decisions.md`, not the full table.
- [ ] AC4: The orchestrator records decisions into `decisions.md` at Gate 1 (scope decisions), Gate 2 (architecture decisions), and Phase 6 (finding-to-commit), in addition to the existing `planning.md` `## Decisions Made` capture.
- [ ] AC5: The `decisions.md` path is state-derived (T73); resolves under both layouts.
- [ ] AC6: The distinction between `decisions.md` (initiative-wide) and `code-audit/findings-ledger.md` (WS-B code-audit rounds) is documented in CLAUDE.md so the two are not conflated.
- [ ] AC7: CLAUDE.md artifact-layout block lists `decisions.md` with a description.
- [ ] AC8: All emitted `decisions.md` content and the HANDOFF reference are ASCII-only (C-1/EDMV2-21).

### Technical Notes
- Keep the HANDOFF reference as a relative path or `dir_for`-resolved path string; do not embed the table content.
- Preserve the existing `planning.md` `## Decisions Made` parse (`:719-720`) — `decisions.md` augments, it does not replace, the planning capture that feeds HANDOFF.
- `edm-init` scaffold must be idempotent.

### Out of Scope
- The WS-B code-audit findings ledger schema (EDMV2-26/31) — separate file, separate ticket.
- Automated commit-SHA capture (entries may be filled by the orchestrator/implementer; auto-capture is not required here).

### Verification
QC confirms PASS by: (1) `edm-init` produces `decisions.md` with the two documented tables; (2) running `write-handoff` against a state with recorded decisions shows a compact summary + a link to `decisions.md`, not an inline full table; (3) CLAUDE.md documents the `decisions.md` vs `findings-ledger.md` distinction.

---

## EDMV2-T77: Define the rollback-runbook artifact slot (`ROLLBACK.md`)

| Field | Value |
|---|---|
| Workstream | WS-D |
| SRD Requirements | EDMV2-41 |
| Priority | Should |
| Size | S |
| Phase | 4 (Tickets) / implements in Phase B |

**Target Components**
- `plugins/edm-ai-development-staging/CLAUDE.md` — document the canonical `ROLLBACK.md` slot in the artifact layout (created on demand, not always scaffolded).
- `plugins/edm-ai-development-staging/skills/orchestrator/SKILL.md` — Phase 6 / Step 8 completion checklist: note where `ROLLBACK.md` lives and when an initiative should produce one (the orchestrator points to the slot rather than inventing a location).
- `plugins/edm-ai-development-staging/bin/edm-state` — `write_handoff_internal()` artifact checklist: surface `ROLLBACK.md` presence/absence (using the T73 resolver) so a teammate sees whether a runbook exists.

**Dependencies**
- EDMV2-T73 (WS-D resolver).

### Description
Initiatives that change production behavior need a documented revert procedure, but today there is no canonical location for it, so rollback steps get scattered in HANDOFF prose or omitted (EDMV2-41). This ticket defines `ROLLBACK.md` as the canonical, state-derived slot for the rollback runbook.

`ROLLBACK.md` is created on demand (only for initiatives that need one — it is not always scaffolded), but the path convention is fixed and documented so any initiative can produce it without inventing a location. The HANDOFF artifact checklist surfaces whether the runbook is present.

### Acceptance Criteria
- [ ] AC1: CLAUDE.md documents `ROLLBACK.md` at the resolved initiative directory root as the canonical rollback-runbook slot, marked "when needed (not always scaffolded)".
- [ ] AC2: The documented `ROLLBACK.md` template/structure includes at minimum: trigger conditions, ordered revert steps, verification-after-rollback, and owner/contact.
- [ ] AC3: The path is state-derived (T73) and resolves under both the new and legacy layouts.
- [ ] AC4: The orchestrator Step 8 completion checklist references the `ROLLBACK.md` slot and the criterion for when an initiative should produce one (production-affecting change, irreversible migration, etc.).
- [ ] AC5: `write_handoff_internal()` artifact checklist includes a `ROLLBACK.md` row showing `[present]`/`[absent]` (ASCII markers per EDMV2-21).
- [ ] AC6: `ROLLBACK.md` is NOT created by `edm-init` (on-demand only); a fresh scaffold has no `ROLLBACK.md`.
- [ ] AC7: The slot definition is consistent with the SRD §5.2.6 / §6.3 layout tables (filename `ROLLBACK.md`).

### Technical Notes
- Use the same `[present]`/`[absent]` ASCII marker pattern introduced by EDMV2-21 for the new checklist row.
- Do not block completion on `ROLLBACK.md` absence — it is a Should-priority on-demand slot, not a gate.

### Out of Scope
- Authoring rollback content for any specific initiative.
- Auto-generating rollback steps from the diff (out of scope; human-authored runbook).

### Verification
QC confirms PASS by: (1) CLAUDE.md documents the slot and template; (2) a fresh `edm-init` produces no `ROLLBACK.md`; (3) creating a `ROLLBACK.md` then running `write-handoff` flips its checklist row to `[present]` with ASCII markers; (4) the slot path resolves correctly under both layouts.

---

## EDMV2-T78: Define the execution-report artifact slot (`exec-report.md`) with mode field

| Field | Value |
|---|---|
| Workstream | WS-D |
| SRD Requirements | EDMV2-42 |
| Priority | Should |
| Size | M |
| Phase | 4 (Tickets) / implements in Phase B |

**Target Components**
- `plugins/edm-ai-development-staging/skills/implement/SKILL.md` — Phase 6: after QC, write a per-epic / per-run execution report to the canonical `exec-report.md` (or `epicN-execution-report.md`) slot resolved via T73, capturing what happened, deferred work, known issues, and a `mode` field (e.g., `live-db`).
- `plugins/edm-ai-development-staging/skills/orchestrator/SKILL.md` — Step 7/8: drive creation of the execution report at Phase 6 completion and reference its canonical path.
- `plugins/edm-ai-development-staging/bin/edm-state` — `write_handoff_internal()` artifact checklist surfaces `exec-report.md` presence.
- `plugins/edm-ai-development-staging/CLAUDE.md` — document the `exec-report.md` slot and per-epic naming convention.

**Dependencies**
- EDMV2-T73 (WS-D resolver). Coordinate with WS-C canonical `qc/` home (EDMV2-33) — the exec-report references QC verdicts but lives at the initiative root, distinct from `qc/`.

### Description
After Phase 6, there is no canonical home for the post-implementation narrative — what was built, what was deferred, what known issues remain, and under what run mode (e.g., `live-db`) the work executed (EDMV2-42). This information currently leaks into HANDOFF prose or is lost.

This ticket defines `exec-report.md` (with a per-epic variant `epicN-execution-report.md` for multi-epic initiatives) as the canonical post-Phase-6 execution-report slot, including a `mode` field, derivable from state.

### Acceptance Criteria
- [ ] AC1: CLAUDE.md documents `exec-report.md` (single-epic) and `epicN-execution-report.md` (per-epic) as the canonical execution-report slots at the resolved initiative directory root.
- [ ] AC2: The documented report structure includes: summary of what happened, deferred work, known issues, outstanding PARTIAL ACs (cross-referencing WS-C), and a `mode` field (e.g., `live-db` / `dry-run`).
- [ ] AC3: The `implement` skill writes the execution report to the canonical slot resolved via T73 at Phase 6 completion.
- [ ] AC4: The orchestrator Step 7/8 references the exec-report slot and drives its creation before declaring Phase 6 complete.
- [ ] AC5: The path convention is derivable from state (T73) and resolves under both layouts; per-epic naming uses the epic number.
- [ ] AC6: `write_handoff_internal()` artifact checklist includes an `exec-report.md` row with `[present]`/`[absent]` ASCII markers.
- [ ] AC7: The slot is consistent with SRD §5.2.6 / §6.3 (filenames `exec-report.md` / `epicN-execution-report.md`, `mode` field present).
- [ ] AC8: Emitted exec-report content is ASCII-only (C-1/EDMV2-21).

### Technical Notes
- The `mode` field in the exec-report is the **run** mode (e.g., `live-db`), distinct from the state `mode` adaptation profile (WS-E) — document this to avoid confusion.
- For single-epic initiatives, `exec-report.md` is sufficient; per-epic reports apply when WS-H multi-epic/multi-stack is in play.

### Out of Scope
- Auto-populating the report from QC/state (the implementer/orchestrator authors it; auto-generation is not required).
- The WS-C `qc/` home itself (EDMV2-33) — separate ticket; exec-report only references it.

### Verification
QC confirms PASS by: (1) CLAUDE.md documents both naming conventions and the report structure including `mode`; (2) running the `implement` flow against a fixture produces `exec-report.md` at the resolved path; (3) `write-handoff` surfaces the exec-report row with ASCII markers; (4) path resolves under both layouts.

---

## EDMV2-T79: Define post-deploy verification and analysis-input slots

| Field | Value |
|---|---|
| Workstream | WS-D |
| SRD Requirements | EDMV2-43 |
| Priority | Could |
| Size | S |
| Phase | 4 (Tickets) / implements in Phase B |

**Target Components**
- `plugins/edm-ai-development-staging/CLAUDE.md` — document canonical slots for post-deploy verification reports and analysis-input documents (rate-limit analysis, source triage, cost analysis) under the resolved initiative directory.
- `plugins/edm-ai-development-staging/skills/orchestrator/SKILL.md` — Step 8: note the post-deploy verification slot where smoke-test/verification reports go after deploy.

**Dependencies**
- EDMV2-T73 (WS-D resolver).

### Description
The corpus shows recurring post-deploy artifacts — smoke-test/verification reports and analysis-input documents (rate-limit analysis, source triage, cost analysis) — that today have no defined home (EDMV2-43). Because EDMV2-43 is a Could-priority requirement, this ticket defines the **path conventions** for these slots rather than building any tooling around them.

Each slot gets a documented, state-derived path convention so an initiative that needs one can produce it consistently without inventing a location.

### Acceptance Criteria
- [ ] AC1: CLAUDE.md documents a canonical slot (path convention) for post-deploy verification reports (e.g., `post-deploy/verification.md` or `post-deploy-verification.md`).
- [ ] AC2: CLAUDE.md documents canonical slots (path conventions) for analysis-input documents covering at minimum: rate-limit analysis, source triage, and cost analysis (e.g., under an `analysis/` subdirectory).
- [ ] AC3: Each documented slot path is state-derived (resolves under both the new and legacy layouts via the T73 resolver).
- [ ] AC4: Slots are on-demand (not scaffolded by `edm-init`); a fresh initiative has none of them.
- [ ] AC5: The orchestrator Step 8 references the post-deploy verification slot as the home for any post-deploy smoke-test/verification output.
- [ ] AC6: Each slot has a one-line documented purpose so contributors know what belongs where.
- [ ] AC7: The slot definitions are consistent with the SRD §4.4 EDMV2-43 description (post-deploy verification + analysis-input docs).

### Technical Notes
- Keep this lightweight: EDMV2-43 is Could-priority and the verification clause is "each slot has a documented path convention" — no scaffolding or `edm-state` subcommand is required.
- Group analysis-input docs under one `analysis/` subdirectory to avoid root clutter.

### Out of Scope
- Building any tooling to generate or validate these reports.
- Scaffolding the slots at init (on-demand only).

### Verification
QC confirms PASS by: (1) CLAUDE.md documents each slot with a path convention and one-line purpose; (2) the path conventions resolve under both layouts; (3) a fresh `edm-init` creates none of these slots; (4) orchestrator Step 8 references the post-deploy verification slot.

---

## EDMV2-T80: Update `edm-init` scaffold to create always-present WS-D slots

| Field | Value |
|---|---|
| Workstream | WS-D |
| SRD Requirements | EDMV2-39, EDMV2-40 (scaffold portions), EDMV2-23 (scaffold symmetry) |
| Priority | Must |
| Size | S |
| Phase | 4 (Tickets) / implements in Phase B |

**Target Components**
- `plugins/edm-ai-development-staging/bin/edm-init` — extend the scaffold (currently only `mkdir -p "$DIR/code-audit"` at `:19`) to also create the always-present WS-D slots: `explorers/` (T75) and `decisions.md` (T76) with its section headers. Update the "Initiative scaffold created" tree output (`:29-36`) to list the new slots. Compose with the WS-M product-scoped `DIR` path.

**Dependencies**
- EDMV2-T75 (explorers/ definition), EDMV2-T76 (decisions.md definition), EDMV2-T73 (resolver). Depends on EDMV2-86 (WS-M edm-init `--product`/`--description`) — this scaffold change must layer on the WS-M init rewrite, using its product-scoped `DIR`.

### Description
WS-D introduces two always-present slots (`explorers/`, `decisions.md`) and several on-demand slots. This ticket centralizes the scaffold change so `edm-init` produces a directory shape that matches the documented WS-D layout (also addressing the EDMV2-23 scaffold-symmetry defect: what `edm-init` scaffolds should match what later phases expect).

The on-demand slots (`ROLLBACK.md`, `exec-report.md`, post-deploy/analysis) are deliberately NOT scaffolded — only the always-present ones are. The scaffold tree output is updated so the user sees the created structure.

### Acceptance Criteria
- [ ] AC1: `edm-init` creates `explorers/` in the new initiative directory (composing with the WS-M product-scoped `DIR`).
- [ ] AC2: `edm-init` creates `decisions.md` with its documented `## Key Decisions` and `## Finding-to-Commit` section headers (empty tables).
- [ ] AC3: `edm-init` does NOT create `ROLLBACK.md`, `exec-report.md`, `architecture.md`, or any post-deploy/analysis slot (those are written on demand by their producers).
- [ ] AC4: The "Initiative scaffold created" tree output lists `explorers/` and `decisions.md` alongside `.edm-state.json` and `code-audit/`.
- [ ] AC5: Scaffolding is idempotent and does not fail if a slot already exists (re-running on an existing dir is a no-op for slots, though `edm-init` still guards against an existing full directory at `:15-17`).
- [ ] AC6: A freshly scaffolded initiative directory matches the documented WS-D always-present layout (EDMV2-23 symmetry) — no missing or extra always-present slots.
- [ ] AC7: All scaffold output is ASCII-only (C-1) and uses ASCII tree characters, not Unicode box-drawing — the existing `:30-33` tree uses Unicode `├──`/`└──`; replace with ASCII (`+--`/`\--` or `-`) per EDMV2-21/75.

### Technical Notes
- The current tree output at `bin/edm-init:30-33` uses Unicode box-drawing glyphs (`├──`, `└──`); per EDMV2-21/75 these must become ASCII. This ticket is the natural place to fix that since it rewrites the tree block.
- Keep `set -euo pipefail` safety; `mkdir -p` is idempotent for `explorers/`. Write `decisions.md` only if absent to preserve idempotency.
- This must be sequenced after the WS-M `edm-init --product/--description` rewrite (EDMV2-86) so it edits the post-WS-M `DIR` definition.

### Out of Scope
- The next-step message correction (EDMV2-19/G13) and prefix regex reconciliation (EDMV2-18/G12) — handled in Epic 1 / WS-M tickets.
- On-demand slots (T77/T78/T79).

### Verification
QC confirms PASS by: (1) `edm-init` on a fresh prefix produces `explorers/` and `decisions.md` (with headers) and no on-demand slots; (2) `grep -P '[^\x00-\x7F]' ` over the scaffold output returns nothing (ASCII tree); (3) re-running scaffold logic over an existing slot does not error; (4) the produced directory matches the documented always-present layout.

---

## EDMV2-T81: Render WS-D slots in HANDOFF and reference ledger instead of inlining

| Field | Value |
|---|---|
| Workstream | WS-D |
| SRD Requirements | EDMV2-40, EDMV2-41, EDMV2-42 (HANDOFF rendering) |
| Priority | Must |
| Size | M |
| Phase | 4 (Tickets) / implements in Phase B |

**Target Components**
- `plugins/edm-ai-development-staging/bin/edm-state` — `write_handoff_internal()` (`:737-765`): extend the `## Artifact Checklist` table (`:748-755`) with rows for `architecture.md`, `decisions.md`, `ROLLBACK.md`, and `exec-report.md` using `dir_for` (T73) and `[present]`/`[absent]` ASCII markers; change the `## Key Decisions Made` block (`:756-757`) to a compact summary plus a `decisions.md` reference (T76).

**Dependencies**
- EDMV2-T73 (resolver), EDMV2-T74 (architecture.md), EDMV2-T76 (decisions.md), EDMV2-T77 (ROLLBACK.md), EDMV2-T78 (exec-report.md). Depends on EDMV2-21 (ASCII markers) from Epic 1 / WS-A for the `[present]`/`[absent]` marker convention.

### Description
HANDOFF.md is the single resume document a teammate reads first. WS-D's new slots are useless if HANDOFF does not surface them. This ticket wires all WS-D slots into the HANDOFF artifact checklist and converts the decisions block from an inline dump to a compact summary plus a reference to `decisions.md` (the core "stop overloading HANDOFF" goal of EDMV2-40).

This is the integration ticket that makes the WS-D slots visible at the one place teammates look, using the T73 resolver and the ASCII `[present]`/`[absent]` markers introduced by EDMV2-21.

### Acceptance Criteria
- [ ] AC1: The HANDOFF `## Artifact Checklist` table includes rows for `architecture.md`, `decisions.md`, `ROLLBACK.md`, and `exec-report.md` in addition to the existing five artifacts.
- [ ] AC2: Each new row's presence is computed against the `dir_for`-resolved path (T73), not a hardcoded flat path.
- [ ] AC3: Presence markers are ASCII `[present]` / `[absent]` (replacing the Unicode `✓`/`✗` at `:711-715`, consistent with EDMV2-21).
- [ ] AC4: The `## Key Decisions Made` block renders a compact summary (or last N entries) plus an explicit path reference to `decisions.md`, not the full finding-to-commit table (EDMV2-40).
- [ ] AC5: Running `write-handoff` on a state where only some WS-D slots exist correctly shows `[present]` for existing files and `[absent]` for missing ones.
- [ ] AC6: A `grep -P '[^\x00-\x7F]'` over a generated HANDOFF.md returns nothing (full ASCII, no remaining Unicode markers).
- [ ] AC7: HANDOFF rendering works for both new-layout and legacy-flat initiatives (rows resolve correctly via `dir_for`).
- [ ] AC8: The existing five artifact rows (`planning.md`, `srd.md`, `audit-srd.md`, tickets `README.md`, tickets `audit.md`) continue to render correctly after the change (no regression).
- [ ] AC9: No existing `HANDOFF.md` consumers (parser at `bin/edm-state:719-720`, `## Notes` awk at `:729-731`) are broken by the new section; documents produced without WS-D slots still render all prior sections correctly (backward-compatible addition).
- [ ] AC10: The WS-D checklist rows added here are compatible with the PARTIAL-verdicts section (T67), lifecycle section (T99), and related-initiatives section (T103); T99 owns the final section order.

### Technical Notes
- This ticket overlaps the EDMV2-21 fix at `:711-715`; coordinate sequencing so the ASCII-marker change lands once. If EDMV2-21 lands first, reuse its markers; if this lands first, it supersedes the Unicode markers for all rows.
- The ASCII marker substitution at `:711-715` (AC3) is co-owned with T21 (EDMV2-21). If T21 lands first, reuse its `[present]`/`[absent]` markers rather than re-applying the substitution.
- The architecture-doc, decisions, rollback, and exec-report path strings come from `dir_for` (T73); do not reconstruct `${SRD_ROOT}/${prefix}/` inline.
- Keep the HANDOFF reference to `decisions.md` as a path string, not the embedded table content.
- The `write_handoff_internal()` heredoc is edited by T67, T81, T99, and T103. T99 is the designated owner of the final combined section sequence — coordinate with T99 on placement.

### Out of Scope
- Defining the slot contents (T74/T76/T77/T78).
- WS-F/G/C HANDOFF additions (mode, linkage, PARTIAL rendering) — those are separate workstream tickets, though they touch the same function.

### Verification
QC confirms PASS by: (1) creating a fixture initiative with `architecture.md` and `decisions.md` present but `ROLLBACK.md`/`exec-report.md` absent, running `write-handoff`, and confirming the checklist shows the correct `[present]`/`[absent]` markers per row; (2) `grep -P '[^\x00-\x7F]' HANDOFF.md` is empty; (3) the decisions block shows a summary + `decisions.md` reference, not a full inline table; (4) flat-layout fixture renders correctly.

---

## EDMV2-T82: Document all WS-D canonical homes in CLAUDE.md artifact layout

| Field | Value |
|---|---|
| Workstream | WS-D |
| SRD Requirements | EDMV2-38, EDMV2-39, EDMV2-40, EDMV2-41, EDMV2-42, EDMV2-43 |
| Priority | Must |
| Size | S |
| Phase | 4 (Tickets) / implements in Phase B |

**Target Components**
- `plugins/edm-ai-development-staging/CLAUDE.md` — update the "Project artifact layout" block (the ` SRD/ ... ` tree) to show all WS-D slots in the WS-M `SRD/{PRODUCT}/{PREFIX}__{DESCRIPTION}/` layout: `architecture.md`, `explorers/`, `decisions.md`, `ROLLBACK.md` (on-demand), `exec-report.md`/`epicN-execution-report.md` (on-demand), and the post-deploy/analysis slots (on-demand). Mark each slot Must/Should/Could and always-present vs on-demand.
- `plugins/edm-ai-development-staging/skills/orchestrator/SKILL.md` — update the "Artifact Layout" block (`:294-309`) to match.

**Dependencies**
- EDMV2-T74 through EDMV2-T79 (all slot definitions). Depends on EDMV2-85 (WS-M layout) — the documented tree must show the `SRD/{PRODUCT}/{PREFIX}__{DESCRIPTION}/` layout, not the flat `SRD/{PREFIX}/` layout.

### Description
The WS-D slots are only as discoverable as their documentation. This ticket is the single consolidation point that ensures CLAUDE.md and the orchestrator's artifact-layout block both reflect the complete WS-D set inside the WS-M directory layout, so a contributor sees one authoritative picture of where every artifact lives (per the verification clauses of EDMV2-38 through EDMV2-43, each of which requires the path be documented).

It also reconciles the orchestrator's own artifact-layout block (currently the flat `SRD/{PREFIX}/` tree at `:294-309`) with the new layout, closing the documentation half of the WS-M blast-radius (SRD §5.6 Risk 2).

### Acceptance Criteria
- [ ] AC1: CLAUDE.md's artifact-layout tree shows the `SRD/{PRODUCT}/{PREFIX}__{DESCRIPTION}/` root (WS-M), not the flat `SRD/{PREFIX}/`.
- [ ] AC2: The tree lists `architecture.md`, `explorers/`, and `decisions.md` (always-present) with one-line descriptions.
- [ ] AC3: The tree lists `ROLLBACK.md`, `exec-report.md`/`epicN-execution-report.md`, and the post-deploy/analysis slots (on-demand) with one-line descriptions and an "on-demand" annotation.
- [ ] AC4: Each slot is annotated with its priority (Must/Should/Could) traceable to its SRD requirement (EDMV2-38..43).
- [ ] AC5: The orchestrator artifact-layout block (`:294-309`) is updated to match CLAUDE.md (same slots, same layout root).
- [ ] AC6: The documented tree is ASCII-only — no Unicode box-drawing glyphs (C-1/EDMV2-21/75).
- [ ] AC7: The documentation is internally consistent with the SRD §5.2.6 / §6.3 layout tables (same filenames, same homes).
- [ ] AC8: Every WS-D requirement (EDMV2-38..43) has its canonical path documented in CLAUDE.md, satisfying each requirement's "documented in CLAUDE.md / documented path convention" verification clause.

### Technical Notes
- This is the documentation closure ticket for WS-D; it should land after the slot-definition tickets so it documents the final filenames.
- Use ASCII tree characters consistently with the EDMV2-75 ASCII constraint.
- Cross-check filenames against SRD §5.2.6 (`architecture.md`, `explorers/`, `decisions.md`, `ROLLBACK.md`, `exec-report.md`) so docs and SRD agree exactly.

### Out of Scope
- Behavioral changes (those are T73-T81); this ticket is documentation-only.

### Verification
QC confirms PASS by: (1) reading CLAUDE.md and confirming all six WS-D slots appear in the WS-M layout tree with priority + always-present/on-demand annotations; (2) confirming the orchestrator artifact-layout block matches; (3) `grep -P '[^\x00-\x7F]'` over the edited CLAUDE.md sections returns nothing; (4) cross-checking each filename against SRD §5.2.6 for exact agreement.
