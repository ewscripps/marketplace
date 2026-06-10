---
name: orchestrator
description: Run the full Enterprise Development Methodology (EDM) -- all 6 phases with 3 HITL gates. Invoked explicitly via /edm:orchestrator <initiative>. The initiative can be plain text, a file path, or a Jira ticket key. Use when starting a new feature, refactor, or service that touches 10+ files.
disable-model-invocation: true
model: opus
effort: max
argument-hint: '<initiative description | /path/to/file | PROJ-123>'
allowed-tools: Read, Write, Edit, Bash(edm-state *), Bash(edm-init *), Bash(edm-validate-prefix *), Glob, Grep, Task, TodoWrite, AskUserQuestion
---

# EDM Orchestrator

You are orchestrating a complete Enterprise Development Methodology (EDM) initiative. The user invoked
`/edm:orchestrator` with:

**Raw input**: $ARGUMENTS

The input may be plain text, a file path, or a Jira ticket key -- Step 1a resolves it into a concrete initiative
description before any planning begins.

## Overview

EDM is a six-phase process for shipping complex software with high confidence. The core insight: **the cost of planning
is always lower than the cost of rework**.

## When to Use

| Scenario                       | Use EDM?                 |
|--------------------------------|--------------------------|
| New feature touching 10+ files | Yes -- full six phases    |
| Large refactor or migration    | Yes                      |
| New service or module          | Yes                      |
| Bug fix (1-3 files)            | No -- just fix it         |
| Config/dependency update       | No -- just do it          |
| Exploratory prototype          | Partial -- Phase 1-2 only |

## The Six Phases + HITL Gates

```
Phase 1      HITL     Phase 2      Phase 3      HITL     Phase 4       Phase 5      HITL     Phase 6
Planning --> GATE --> SRD     -->  Audit   --> GATE --> Tickets --> Audit    --> GATE --> Implementation
             #1      Creation     (SRD)        #2      Creation    (Tickets)    #3       + QC + Remediation
```

| Gate   | After                | Approves                            |
|--------|----------------------|-------------------------------------|
| Gate 1 | Phase 1 Planning     | Scope, constraints, go/no-go        |
| Gate 2 | Phase 3 SRD Audit    | Remediated SRD is correct           |
| Gate 3 | Phase 5 Ticket Audit | Ticket pack is implementation-ready |

## Operational Orchestration

Execute the following steps. Use `bin/edm-state` (on PATH while plugin enabled) to record progress.

### Step 1 -- Initial assessment

**Step 1a -- Resolve the initiative description from `$ARGUMENTS`**

Determine the input type and extract the initiative description before proceeding:

- **Empty**: If `$ARGUMENTS` is empty or blank, ask: *"What are we building? Describe the initiative, provide a file
  path, or give a Jira ticket key (e.g., PROJ-123)."* Use the answer as the initiative description.

- **Jira ticket key** (`$ARGUMENTS` matches `[A-Z][A-Z0-9]+-\d+`, e.g., `ELI-42`):
  1. Call `getAccessibleAtlassianResources` to get the cloudId.
  2. Call `getJiraIssue` with the ticket key.
  3. Compose the initiative description from the issue summary, description, and any acceptance criteria in the body.
  4. Show the user the resolved description and confirm: *"Using Jira ticket {KEY}: '{summary}'. Proceed?"*

- **File path** (`$ARGUMENTS` starts with `/`, `./`, `~/`, or ends with a known extension like `.md`, `.txt`, `.rst`):
  1. Read the file with the `Read` tool.
  2. Use the full file contents as the initiative description.
  3. Tell the user: *"Using contents of {path} as the initiative description."*

- **Plain text** (everything else): use `$ARGUMENTS` directly as the initiative description.

Call the resolved value **`INITIATIVE`** -- all subsequent steps use `INITIATIVE`, not `$ARGUMENTS`.

**Step 1b -- EDM qualification and prefix**

1. Assess whether `INITIATIVE` qualifies for full EDM (10+ files, new module, major refactor). If not, say so and
   suggest doing it directly without EDM.
2. Ask the user for the **initiative prefix** (e.g., `AUTH`, `MIGR`, `FEAT`). Hint format:
   `${user_config.prefix_format_hint}`. In the same prompt or immediately after, determine the
   **product name** (short lowercase identifier for the product area, e.g. `web`, `auth`, `billing`,
   `edm`) and **description slug** (lowercase-hyphenated summary, e.g. `web-navigation-feature`).
   - Derive the description slug from `INITIATIVE` — no need to prompt the user.
   - For the product name: infer from `INITIATIVE` context when clear (e.g., "web navigation
     feature" → `web`). If the product area is ambiguous, ask the user in the same `AskUserQuestion`
     call alongside the prefix question (header `"Product"`, options based on context, or free-text
     via Other).
   - Both values must match `^[a-z][a-z0-9-]*$` — lowercase letters, digits, hyphens only.
3. Run `edm-validate-prefix <PREFIX>` -- if `SRD/{PREFIX}/` already exists:
   - Refresh the handoff from current state before displaying: `edm-state write-handoff <PREFIX>`
     (this pulls `current_phase`, gate approvals, and mode fields from `.edm-state.json` so the
     user sees the true current state, not a snapshot from a prior session).
   - Read the refreshed `SRD/{PREFIX}/HANDOFF.md` and display it verbatim so the user sees exactly
     where the initiative stands (phase, last gate, next action, artifact checklist, decisions made).
   - Then use `AskUserQuestion` with header `"Resume?"` and options:
     - **Resume** -- continue from where the handoff shows
     - **Start over** -- pick a different prefix
   - On Resume:
     1. Skip `edm-init`.
     2. Run `edm-state get <PREFIX>` and read **both** `current_phase` AND `current_step`.
        - `current_phase` tells you which phase the initiative was in.
        - `current_step` (if non-empty) tells you the specific named step within that phase
          where work stopped (e.g., `"2c"` = step 2c of Phase 2). Jump directly to that
          step rather than re-running the phase from the beginning.
        - If `current_step` is empty or absent, resume from the start of `current_phase`.
     3. **Read all four mode-family fields** from state and set your working variables before
        dispatching to any sub-flow:
        ```bash
        edm-state get <PREFIX> | jq -r '{
          mode: (.mode // "standard"),
          lifecycle_mode: (.lifecycle_mode // "standard"),
          compliance_enabled: (.compliance_enabled // false),
          implementation_mode: (.implementation_mode // "standard")
        }'
        ```
        State which mode/lifecycle the initiative is in (e.g., "Resuming in iac mode,
        fast-track lifecycle") before continuing so the user sees which sub-flow applies.
        Skip Step 1c (mode selection) -- the mode is already recorded.
     4. Run `edm-state current-step <PREFIX> <step>` at the start of each major step so
        that future resume operations can jump precisely. The canonical step IDs are:
        `1a`, `1b`, `1c`, `2`, `3`, `4`, `5`, `6` (matching the Step numbering in this skill).
        Within multi-part steps use dotted sub-steps: `2.srd`, `2.arch`, `4.epic-N`, etc.
     5. Record `last_cmd` and `last_decision` at decision points:
        `edm-state set <PREFIX> last_cmd "<command>"` and
        `edm-state set <PREFIX> last_decision "<decision text>"`.
   - On Start over: ask for a new prefix and loop back to step 2.
4. If new: scaffold the initiative directory using the **product-scoped layout** (v2.0 canonical):
   ```bash
   edm-init --product <product> --description <slug> <PREFIX>
   ```
   This creates `${user_config.srd_root}/<product>/<PREFIX>__<slug>/`. Export `EDM_PRODUCT` and
   `EDM_DESCRIPTION` before any subsequent `edm-state` calls so they resolve the correct path:
   ```bash
   export EDM_PRODUCT=<product>; export EDM_DESCRIPTION=<slug>
   ```
   Then immediately run `edm-state write-handoff <PREFIX>` to create the initial HANDOFF.md.

   Flat fallback (legacy or per-user preference only): `edm-init <PREFIX>` — creates
   `${user_config.srd_root}/<PREFIX>/`. Use this only when the user explicitly requests it.

### Step 1c -- Mode and profile selection

After prefix resolution and before Phase 1, ask the user to select an adaptation profile and
lifecycle mode. This step is **skipped on resume** when a non-default `mode` is already recorded
in state (see Step 1b resume instructions).

1. Present a mode selection via `AskUserQuestion` (header `"EDM mode"`, <=12 chars):
   - **Standard** -- full six-phase flow, file-path vocabulary, standard QC (Recommended)
   - **mini-SRD** -- fused Phases 2-5 into one audited file; no separate ticket pack
   - **IaC** -- resource-path vocabulary; QC verifies `terraform plan` / drift
   - **Data/ML** -- requires Data Requirements SRD section; QC validates model metrics
   - **Prototype** -- Phases 1-2 only; clean stop after SRD

2. Present a compliance toggle via a second `AskUserQuestion` (header `"Compliance"`):
   - **Off** -- standard gates only (Recommended)
   - **On** -- adds Gate 3.5 compliance review with regulatory-traceability columns

3. Record choices:
   ```bash
   edm-state set-mode <PREFIX> mode <value>
   edm-state set-mode <PREFIX> compliance_enabled true   # only if On was selected
   ```

4. Mode dispatch -- follow the matching sub-flow:

| `mode` | Sub-flow |
|---|---|
| `standard` | Continue Steps 2-9 as written (current six-phase flow) |
| `mini-srd` | See **mini-SRD Sub-Flow** section below |
| `iac` | Steps 2-9 with IaC vocabulary (resource paths in SRD/tickets; terraform-plan QC) |
| `data-ml` | Steps 2-9 with Data Requirements SRD section; model-metric QC |
| `prototype` | See **Prototype Sub-Flow** section below |

When `compliance_enabled=true`: insert **Gate 3.5** between Step 6 (Gate 3) and Step 7 (Phase 6).
See **Gate 3.5 -- Compliance Review** section below.

---

### mini-SRD Sub-Flow (mode=mini-srd)

When `mode=mini-srd`, run this compressed lifecycle instead of Steps 3-6:

1. **Phase 1** (Step 2) -- execute normally.
2. **Produce fused file** -- spawn `edm-srd-writer` to produce a single fused file (see
   `skills/srd/SKILL.md` for mini-SRD section layout). No separate ticket pack is created.
   ```bash
   edm-state phase-start <PREFIX> 2
   # spawn edm-srd-writer with mini-SRD instructions
   edm-state phase-complete <PREFIX> 2
   ```
3. **Audit fused file** -- spawn `edm-srd-auditor` agents against the fused file:
   ```bash
   edm-state phase-start <PREFIX> 3
   # spawn 2-3 edm-srd-auditor agents
   edm-state phase-complete <PREFIX> 3
   ```
4. **Merged Gate 2/3** -- present a single pre-implementation gate:
   ```
   AskUserQuestion header: "Gate 2+3"
   Options: Approve / Revise / No-Go
   ```
   On Approve: `edm-state approve-gate <PREFIX> 2` (records the merged gate).
   Apply the gate approval rules from Gate 1 -- free-text is never approval.
5. Record skipped phases:
   ```bash
   edm-state skip-phase <PREFIX> 4 "mini-SRD: ticket pack fused into SRD file"
   edm-state skip-phase <PREFIX> 5 "mini-SRD: ticket audit fused into SRD audit"
   ```
6. **Phase 6** -- proceed to Step 7 (Implementation) reading tickets from the fused file's ticket
   section, not a separate ticket pack directory.

On resume of a `mode=mini-srd` initiative past the merged gate, enter Phase 6 directly.

---

### Prototype Sub-Flow (mode=prototype)

When `mode=prototype`, stop after Phase 2 (SRD):

1. Run Step 2 (Phase 1) normally.
2. Run Step 3 (Phase 2 SRD) normally.
3. Stop with a clean message:
   > "Prototype complete. SRD is at `{path}`. Phases 3-6 are skipped. To graduate this
   > prototype to a full initiative, run `edm-state set-mode <PREFIX> mode standard` then
   > resume with `/edm:orchestrator <PREFIX>`."
4. Record skipped phases:
   ```bash
   edm-state skip-phase <PREFIX> 3 "prototype: SRD audit skipped"
   edm-state skip-phase <PREFIX> 4 "prototype: ticket creation skipped"
   edm-state skip-phase <PREFIX> 5 "prototype: ticket audit skipped"
   edm-state skip-phase <PREFIX> 6 "prototype: implementation skipped"
   ```
5. Do NOT spawn ticket writers, implementers, or QC agents.

`edm-state archive` proceeds with a warning when `mode=prototype` (no convergence gate required).

---

### Fast-Track / Fix-Pack Sub-Flow (lifecycle_mode=fast-track or fix-pack)

When `lifecycle_mode` is `fast-track` or `fix-pack`, generate tickets directly from an analysis
document without the full SRD/ticket-audit sequence:

1. Read the analysis document provided by the user.
2. Produce a minimal `.edm-state.json` with `lifecycle_mode` set.
3. Spawn `edm-ticket-writer` directly from the analysis document.
4. Record skipped phases:
   ```bash
   edm-state skip-phase <PREFIX> 2 "fast-track: SRD skipped -- tickets from analysis doc"
   edm-state skip-phase <PREFIX> 3 "fast-track: SRD audit skipped"
   edm-state skip-phase <PREFIX> 5 "fast-track: ticket audit skipped"
   ```
5. Proceed to Phase 6 after ticket production and a single human review gate.

The state file is valid and recognized as fast-track -- `validate` does not flag it as incomplete.

---

### Gate 3.5 -- Compliance Review (when compliance_enabled=true)

Insert this gate between Gate 3 (end of Step 6) and Phase 6 (Step 7), only when
`compliance_enabled=true`:

1. Present a compliance review gate via `AskUserQuestion` (header `"Gate 3.5"`):
   - **Approve** -- regulatory traceability is verified, proceed to Phase 6
   - **Revise** -- specific tickets need compliance coverage rework (user will describe)
   - **No-Go** -- compliance gap is too large; re-plan

2. Record the gate:
   ```bash
   edm-state approve-gate <PREFIX> 3.5   # only on explicit Approve
   ```

3. Apply the gate approval rules from Gate 1 -- free-text is never approval.

The ticket pack tables include regulatory-traceability columns
(`Regulation | Control | Evidence`) when `compliance_enabled=true` (see `skills/tickets/SKILL.md`).

---

### Step 2 -- Execute Phase 1 (Planning)

1. `edm-state phase-start <PREFIX> 1`
2. Spawn `edm-explorer` agent(s) with `INITIATIVE` as the initiative context -- parallel if scope spans multiple codebase areas. Each explorer writes its findings to `explorers/{NN}-{slug}.md` in the initiative directory (e.g., `explorers/01-current-state.md`, `explorers/02-dependencies.md`).
3. **Synthesis sub-step**: read all `explorers/*.md` and fold the consolidated findings into `planning.md` sections (`## Current State`, `## Gap Analysis`, `## Component Inventory`). For a single-explorer initiative this is a no-op merge. `planning.md` must include these sections
   in order:

   > **Planning authoring guidance** (from `docs/audit-patterns/srd-audit.md`):
   > - **`## Go/No-Go`** -- an explicit GO/NO-GO/CONDITIONAL here prevents "undefined scope boundary" (top SRD P1 finding).
   > - **`## Riskiest Assumptions`** -- pre-empts "requirement assumed but never validated" (top SRD P0/P1 finding).
   > - **`## Open Questions`** -- tag with `[DECISION: A|B|C]` to surface bounded choices at Gate 1; resolves "ambiguous requirement" findings.
   > - **`## Decisions Made`** -- filled at Gate 1; feeds HANDOFF.md and `decisions.md`. Empty section = highest SRD-rewrite rate in the corpus.

   ```
   # {PREFIX} Planning

   ## Initiative
   {one-paragraph description}

   ## Current State
   {what exists today}

   ## Gap Analysis
   {delta between current and desired state}

   ## Component Inventory
   | Component | Path | Status | Notes |
   |-----------|------|--------|-------|

   ## Constraints
   {licensing, team boundaries, platform limits, regulatory}

   ## Dependency Map
   {what blocks what}

   ## Complexity Estimate
   - Files affected: ~N
   - New modules: N
   - Integration points: N
   - Estimated size: Small (10-20 tickets) / Medium (30-50) / Large (50-85)

   ## Go/No-Go
   **Decision**: GO / NO-GO / CONDITIONAL
   **Rationale**: [why]
   **Conditions** (if conditional): [what must be true before proceeding]

   ## Riskiest Assumptions
   [What we're assuming that hasn't been validated]

   ## Open Questions
   {Each question on its own line, tagged as one of:}
   - [DECISION: Option A | Option B | Option C] Question text
   - [OPEN] Question text

   ## Decisions Made
   {populated interactively at Gate 1 -- leave empty initially}
   ```

   Tag questions `[DECISION: ...]` when there are 2-4 bounded options the team must choose between.
   Tag `[OPEN]` for questions that need free-form clarification (expected traffic, team ownership, etc.).

4. `edm-state phase-complete <PREFIX> 1`

5. **Resolve Open Questions interactively** before presenting the gate:

   a. Read the `## Open Questions` section of `planning.md`.

   b. Collect all `[DECISION: ...]` questions. Batch them into `AskUserQuestion` calls (up to 4 per call).
      - Use a <=12-char header that names the decision (e.g., `"Auth method"`, `"DB approach"`).
      - Parse the options from the tag brackets -- those become the selectable choices.
      - Always append an `"Defer to SRD"` option so the user can skip without blocking.

   c. If any `[OPEN]` questions remain, output them as a numbered list and wait for the user's typed
      response before continuing.

   d. Write all answers into the `## Decisions Made` section of `planning.md` (one `- Question: Answer`
      line each). Strike or remove resolved items from `## Open Questions`.

6. **HITL Gate 1** -- present a structured summary then ask for sign-off via `AskUserQuestion`:

   Summary to show first:
   - **Scope**: components affected, file count
   - **Constraints**: key constraints surfaced
   - **Complexity**: Small/Medium/Large with estimated ticket count
   - **Decisions resolved**: N of N open questions answered
   - **Deferred to SRD**: any questions answered "Defer to SRD"
   - **Recommendation**: Go / No-Go with one-line rationale

   Then call `AskUserQuestion` with header `"Gate 1"` and options:
   - **Approve** -- scope is correct, proceed to SRD creation
   - **Revise** -- re-run planning with additional context (user will type what's missing)
   - **No-Go** -- initiative is not ready to proceed

7. **STOP and WAIT for the `AskUserQuestion` response.**
8. **CRITICAL -- gate approval rules (apply to ALL gates)**:
   - `edm-state approve-gate` is called ONLY when the user selects the **exact "Approve" option** from the `AskUserQuestion` dialog.
   - Free-text responses ("yes", "ok", "looks good", "proceed", "sounds good", "go ahead") are **NOT** approvals.
   - If the user types free text instead of selecting an option: re-present the `AskUserQuestion` with a brief note: "Please select an option to proceed."
   - Never infer intent from sentiment -- only the explicit AskUserQuestion selection counts.

   On **Approve** (explicit selection only): `edm-state approve-gate <PREFIX> 1` and proceed to Phase 2.
   Then append Gate 1 scope decisions into `decisions.md` in the initiative directory:
   ```
   | Gate 1 | <decision text> | <chosen> | <rationale> | {date} |
   ```
   On **Revise**: ask what context is missing, then loop back to step 2 with that additional context appended to
   `INITIATIVE`.
   On **No-Go**: summarize the blockers and stop. Do not archive -- leave state for the user to revisit.

### Step 3 -- Execute Phase 2 (SRD)

1. `edm-state phase-start <PREFIX> 2`
2. Resolve the initiative directory: `INIT_DIR=$(edm-state resolve-dir <PREFIX>)`
3. Spawn `edm-srd-writer` for content sections; spawn `edm-architect` in parallel for the Target Architecture.
4. **`edm-srd-writer`** writes directly to `${INIT_DIR}/${user_config.srd_filename}` (default `srd.md`).
5. **`edm-architect`** writes to `${INIT_DIR}/architecture.md` (canonical home for diagrams
   and decisions). The SRD's `## 5. Target Architecture` section references `architecture.md` rather
   than duplicating content. Record the decision:
   ```bash
   edm-state set <PREFIX> last_decision "architecture.md written by edm-architect"
   ```
5. `edm-state phase-complete <PREFIX> 2`
6. Proceed automatically to Phase 3 (no gate between Phase 2 and Phase 3).

### Step 4 -- Execute Phase 3 (SRD Audit)

1. `edm-state phase-start <PREFIX> 3`
2. Resolve the initiative directory: `INIT_DIR=$(edm-state resolve-dir <PREFIX>)`
3. Spawn 2-3 `edm-srd-auditor` agents in parallel (one per section group).
4. Compile findings; remediate all P0/P1 directly in the SRD; update revision history.
5. Write audit report to `${INIT_DIR}/audit-srd.md`.
5. `edm-state phase-complete <PREFIX> 3`
5a. **Auto-update patterns** -- append novel SRD-audit findings to the pattern library:
    ```bash
    edm-state update-patterns <PREFIX> srd
    ```
6. **HITL Gate 2** -- present summary then call `AskUserQuestion` with header `"Gate 2"`:

   Summary to show first:
   - **Requirements**: count by priority (P0/P1/P2)
   - **Architecture decisions**: key choices made
   - **Risks**: top 3 from audit
   - **Audit findings resolved**: P0: N, P1: N, P2: N deferred

   Options:
   - **Approve** -- SRD is correct, proceed to ticket creation
   - **Revise** -- specific SRD sections need rework (user will describe)
   - **No-Go** -- initiative scope or approach needs rethinking

7. **STOP and WAIT for the `AskUserQuestion` response.**
8. On **Approve** (explicit selection only): `edm-state approve-gate <PREFIX> 2` and proceed to Phase 4.
   Then append Gate 2 architecture decisions into `decisions.md` in the initiative directory:
   ```
   | Gate 2 | <architecture decision> | <chosen> | <rationale> | {date} |
   ```
   On **Revise**: ask which sections need rework, remediate, then re-run Phase 3 audit and re-present Gate 2.
   On **No-Go**: summarize blockers and stop.
   (Apply the gate approval rules from Gate 1 -- free-text is never approval.)

### Step 5 -- Execute Phase 4 (Ticket Pack)

1. `edm-state phase-start <PREFIX> 4`
2. Resolve the initiative directory: `INIT_DIR=$(edm-state resolve-dir <PREFIX>)`
3. Spawn `edm-ticket-writer` (per epic in parallel for large initiatives).
4. Output to `${INIT_DIR}/${user_config.ticket_pack_dirname}/` (default `tickets/`):
    - `README.md` (index, legend, critical path, SRD coverage map, `Generated From: srd.md vX.Y.Z` header)
    - `epics/01-*.md` through `NN-*.md`
5. `edm-state phase-complete <PREFIX> 4`
6. Proceed automatically to Phase 5.

### Step 6 -- Execute Phase 5 (Ticket Audit)

1. `edm-state phase-start <PREFIX> 5`
2. Resolve the initiative directory: `INIT_DIR=$(edm-state resolve-dir <PREFIX>)`
3. Spawn 2 `edm-ticket-auditor` agents in parallel (one structural, one content quality).
4. Compile findings; remediate all gaps in the ticket pack.
5. Write audit report to `${INIT_DIR}/${user_config.ticket_pack_dirname}/audit.md`.
5. `edm-state phase-complete <PREFIX> 5`
5a. **Auto-update patterns** -- append novel ticket-audit findings:
    ```bash
    edm-state update-patterns <PREFIX> ticket
    ```
6. **HITL Gate 3** -- present summary then call `AskUserQuestion` with header `"Gate 3"`:

   Summary to show first:
   - **Tickets**: count by epic
   - **Size distribution**: XS/S/M/L breakdown
   - **Critical path**: sequence of blocking tickets
   - **Estimated effort**: from size distribution
   - **SRD coverage**: N/N requirements covered

   Options:
   - **Approve** -- ticket pack is implementation-ready, proceed
   - **Revise** -- specific tickets or epics need rework (user will describe)
   - **No-Go** -- scope has shifted enough to warrant re-planning

7. **STOP and WAIT for the `AskUserQuestion` response.**
8. On **Approve** (explicit selection only): `edm-state approve-gate <PREFIX> 3` and proceed to Phase 6.
   On **Revise**: ask which tickets need rework, remediate, then re-run Phase 5 audit and re-present Gate 3.
   On **No-Go**: summarize blockers and stop.
   (Apply the gate approval rules from Gate 1 -- free-text is never approval.)

### Step 7 -- Execute Phase 6 (Implementation + QC)

1. `edm-state phase-start <PREFIX> 6`
2. **TDD mode selection** -- if `implementation_mode` is not already set in state, ask the user:
   ```
   AskUserQuestion header: "Impl mode"
   Options: Standard -- basic smoke tests per ticket (Recommended) | TDD -- Red-Green-Refactor per ticket
   ```
   Record the choice: `edm-state set-mode <PREFIX> implementation_mode <value>`
   On resume, read `implementation_mode` from state and skip this prompt.
3. Group tickets by file/component independence into parallel waves.
4. Spawn `edm-implementer` agents per wave (each gets a worktree via `isolation: worktree`).
   - In TDD mode, pass `implementation_mode=tdd` instruction to each implementer (Red-Green-Refactor per ticket).
5. After each wave, the `SubagentStop` hook automatically spawns `edm-qc-auditor` to verify acceptance criteria.
   - In TDD mode, the QC auditor also runs the TDD compliance pass.
6. Compile QC findings; remediate; re-audit affected tickets until all PASS.
   Append any finding-to-commit mappings to `decisions.md`:
   ```
   | Finding {ID} | <source> | <resolution> | {ticket-ref} | resolved |
   ```
7. Write the execution report to `exec-report.md` in the initiative directory (or `epicN-execution-report.md`
   for per-epic variants). Minimum content: summary of what was built, deferred work, known issues,
   outstanding PARTIAL ACs (referencing `qc/qc-summary.md`), and a `mode` field (e.g., `live-db`, `dry-run`).
   Note: this `mode` field is the **run** mode, distinct from the `mode` adaptation profile in state.
8. `edm-state phase-complete <PREFIX> 6`
8a. **Auto-update patterns** -- append novel QC findings from this wave:
    ```bash
    edm-state update-patterns <PREFIX> qc
    ```
9. After code-audit convergence (Step 8), append novel code-audit findings:
   ```bash
   edm-state update-patterns <PREFIX> code
   ```

### Step 7b -- Comprehensive Testing (recommended before declaring done)

After all tickets have an initial PASS verdict, suggest:

> *"All {N} tickets pass QC. Recommended: run `/edm:test {PREFIX}` to build thorough,
> layered test coverage (unit, component, integration, E2E, a11y) before declaring Phase 6
> complete. Implementer agents write basic smoke tests per ticket -- `/edm:test` builds the
> full suite that gives you confidence to ship."*

This step is recommended but not mandatory. For very small initiatives (< 5 tickets, all tested
thoroughly by the implementers), the user may choose to proceed without it.

### Step 8 -- Code Audit (mandatory for standard and tdd modes)

Drive the 11-lens code audit:
1. Spawn all 11 `edm-audit-*` lens agents in parallel (see `/edm:code-audit` for the full agent list).
2. Spawn `edm-audit-synthesizer` after lenses complete.
3. Remediate all P0 and P1 findings before proceeding.
4. Run a second audit pass if any P0/P1 findings were introduced by remediation changes.
5. When REMEDIATION.md shows no new P0/P1 findings, record convergence:
   `edm-state set {PREFIX} code_audit_converged true`

**Exemption**: `prototype` mode initiatives may skip code-audit convergence -- `edm-state archive` proceeds with a warning.

**On-demand artifacts at completion** -- write these when applicable, not always:
- `ROLLBACK.md` -- if this initiative changes production behavior or involves an irreversible migration.
  Minimum content: trigger conditions, ordered revert steps, verification-after-rollback, and owner/contact.
- `post-deploy/verification.md` -- post-deploy smoke-test / verification report (after the deploy, not before).
- `post-deploy/analysis/` -- analysis-input documents (rate-limit-analysis.md, source-triage.md,
  cost-analysis.md) if relevant. All paths are state-derived; a fresh initiative has none of these.

### Step 9 -- Verify completion

- [ ] All tickets have a PASS verdict
- [ ] All P0 QC findings resolved
- [ ] Code compiles, existing tests pass
- [ ] `/edm:test {PREFIX}` run and all coverage targets met (or consciously skipped)
- [ ] Documentation updated
- [ ] Committed on feature branch
- [ ] Execution report written to `exec-report.md` in the initiative directory (Step 7)
- [ ] `ROLLBACK.md` written if initiative changes production behavior (on-demand; omit for internal tooling)
- [ ] Post-deploy verification at `post-deploy/verification.md` if already deployed (on-demand)
- [ ] Code audit converged: `edm-state get {PREFIX} code_audit_converged` shows `true` (or mode is `prototype`)
- Run `edm-state archive <PREFIX>` after the initiative ships (blocked by code_audit_converged=false for non-prototype v2 initiatives).

## Phase Timing Guidelines

| Initiative Size        | Planning | SRD | Audit | Tickets | Audit | Impl   | Total     |
|------------------------|----------|-----|-------|---------|-------|--------|-----------|
| Small (10-20 tickets)  | 30m      | 2h  | 1h    | 1h      | 30m   | 4-8h   | 1-2 days  |
| Medium (30-50 tickets) | 1h       | 4h  | 2h    | 3h      | 1h    | 12-24h | 3-5 days  |
| Large (50-85 tickets)  | 2h       | 8h  | 4h    | 6h      | 2h    | 24-48h | 5-10 days |

Run `/edm:metrics --calibrate` periodically to update these from your team's actual data.

## Artifact Layout (committed to git)

All paths are state-derived (product-scoped or flat layout, never hardcoded).

```
${user_config.srd_root}/{PRODUCT}/{PREFIX}__{DESCRIPTION}/   (or flat {PREFIX}/ for legacy)
|
+-- planning.md                <- Phase 1 (always-present)
+-- srd.md                     <- Phase 2 (always-present; default srd_filename)
+-- architecture.md            <- Phase 2: edm-architect diagrams and decisions (Must/always-present)
+-- explorers/                 <- Phase 1: parallel explorer findings, one file per focus area (Must/always-present)
|   +-- 01-{slug}.md, 02-{slug}.md, ...
+-- decisions.md               <- Running key-decisions and finding-to-commit ledger (Must/always-present)
+-- audit-srd.md               <- Phase 3
+-- {ticket_pack_dirname}/     <- default: tickets/
|   +-- README.md              <- index, SRD coverage map, Generated From header
|   +-- audit.md               <- Phase 5 audit
|   +-- epics/01-*.md, 02-*.md, ...
+-- test-plan.md               <- /edm:test (stack + AC coverage map)
+-- test-coverage.md           <- /edm:test (coverage by layer + AC<->test cross-ref)
+-- qc/                        <- Phase 6 QC reports (always-present after first wave)
|   +-- qc-summary.md          <- merged QC report (single auditor or merged shards)
|   +-- qc-shard-{NN}.md       <- shard reports before merge
+-- code-audit/                <- /edm:code-audit output
|   +-- findings-ledger.md     <- persistent cross-round findings ledger (stable CA-NNN IDs)
|   +-- pass-{N}_{YYYY-MM-DD}/ <- one directory per audit round
|       +-- lens-L1.md ... lens-L11.md
|       +-- lenses-run.txt
|       +-- REMEDIATION.md
+-- ROLLBACK.md                <- rollback runbook (Should/on-demand -- only when initiative changes prod)
+-- exec-report.md             <- post-Phase-6 execution report, includes mode field (Should/on-demand)
+-- post-deploy/               <- post-deploy verification and analysis-input docs (Could/on-demand)
|   +-- verification.md        <- smoke-test / deploy verification report
|   +-- analysis/              <- rate-limit-analysis.md, source-triage.md, cost-analysis.md
+-- HANDOFF.md                 <- auto-generated cross-user resume doc (refreshed at every phase/gate/stop)
+-- .edm-state.json            <- gate approvals, phase timestamps, mode fields, coverage_by_layer
```

**Slot annotations**:
- `always-present` -- scaffolded by `edm-init` or written early in the phase flow
- `on-demand` -- created by its owning phase/agent only when the initiative needs it
- `Must/Should/Could` -- priority per SRD EDMV2-38..43

## Anti-Patterns

- **Skip the SRD** -- scope creeps, contradictions emerge, tickets lack context.
- **Skip an audit** -- errors propagate to every ticket and every line of code.
- **Auto-approve HITL gates** -- defeats the purpose; human misalignment is 10x cheaper to fix now than after
  implementation.
- **One monolithic implementation pass** -- context exhaustion, no parallelism.
- **XL tickets** -- must be decomposed before starting.

Never auto-approve a HITL gate. Never skip a phase. Always record state via `edm-state`.
