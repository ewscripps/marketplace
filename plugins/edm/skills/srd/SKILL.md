---
name: srd
description: EDM Phase 2 (SRD Creation) -- transform planning scope into a comprehensive Software Requirements Document with unique requirement IDs, testable acceptance criteria, architecture diagrams, and prioritized features. Invoked explicitly via /edm:srd.
user-invocable: true
model: opus
effort: high
argument-hint: <PREFIX>
allowed-tools: Read, Write, Edit, Bash(edm-state *), Glob, Grep, Task, TodoWrite
---

# EDM Phase 2: SRD Creation

**Arguments**: $ARGUMENTS

- **Input**: Planning document at `${user_config.srd_root}/{PREFIX}/planning.md`
- **Output**: SRD at `${user_config.srd_root}/{PREFIX}/${user_config.srd_filename}` (default `srd.md`)

## Step 0 -- Gate and Branch Preflight

Before Step 1, run the preflight per `skills/plan/SKILL.md Sec."Step 0 -- Gate and Branch Preflight"`,
using `<gated-command>` = `srd` and `<phase-num>` = `2`.

## Operational Orchestration

1. Parse `$ARGUMENTS` for `{PREFIX}`. If missing, ask the user or read from in-progress initiatives via `edm-state list`.
2. `edm-state get <PREFIX>` -- verify Gate 1 has been approved. (The UserPromptExpansion hook also enforces this.)
3. Read `mode` from state: `edm-state get <PREFIX> | jq -r '.mode // "standard"'`
4. `edm-state phase-start <PREFIX> 2`
5. **Standard / IaC / Data-ML modes**: Spawn `edm-srd-writer` for main content + `edm-architect` in
   parallel. `edm-srd-writer` writes to `${user_config.srd_filename}` (default `srd.md`).
   `edm-architect` writes to `architecture.md` (not into the SRD body). Record the decision:
   ```bash
   edm-state set <PREFIX> last_decision "architecture.md written by edm-architect"
   ```
   **mini-SRD mode**: Spawn `edm-srd-writer` with the fused-file structure (see section below).
6. After both complete, verify the SRD file. `edm-state srd-version <PREFIX> 1.0.0`
7. `edm-state phase-complete <PREFIX> 2`
8. **Mode branch**:
   - `mode=prototype`: stop here with a clean message instead of proceeding to Phase 3:
     > "Prototype complete. SRD is at `{path}`. Phases 3-6 are skipped. To graduate this
     > prototype to a full initiative, run `edm-state set-mode <PREFIX> mode standard` then
     > resume with `/edm:orchestrator <PREFIX>`."
     Record skipped phases:
     ```bash
     edm-state skip-phase <PREFIX> 3 "prototype: SRD audit skipped"
     edm-state skip-phase <PREFIX> 4 "prototype: ticket creation skipped"
     edm-state skip-phase <PREFIX> 5 "prototype: ticket audit skipped"
     edm-state skip-phase <PREFIX> 6 "prototype: implementation skipped"
     ```
     Do not spawn ticket writers, implementers, or QC agents. `edm-state archive` proceeds with a
     warning when `mode=prototype` (no convergence gate required).
   - All other modes: proceed automatically to Phase 3 audit (`/edm:audit-srd <PREFIX>`) -- no HITL
     gate between Phase 2 and Phase 3.

## SRD Sections

| Section | When to Include |
|---|---|
| Executive Summary | Always |
| Document Information | Always |
| Purpose & Scope | Always |
| Current State Assessment | Always |
| Target Architecture | When architecture changes |
| Feature Requirements | Always |
| Security | When security-relevant |
| Observability | When operational behavior changes |
| Performance Targets | When performance matters |
| Migration Path | For large initiatives |
| Risks & Mitigations | Always |
| Glossary | When domain-specific language is used |

## Requirement ID Conventions

All requirements get sequential IDs: `{PREFIX}-01`, `{PREFIX}-02`, ...

## Quality Standards (Mandatory)

1. **Unique IDs** -- every requirement has `{PREFIX}-NN`
2. **Testable** -- every requirement has clear pass/fail acceptance criteria
3. **Illustrated** -- architecture shown with Mermaid diagrams (system context + sequence), following `CLAUDE.md Sec."Mermaid diagram conventions"` for label text. Read `docs/canonical-sections.md` (resolved relative to the EDM plugin's own root -- `plugins/edm/` in this repository, or the installed plugin's cache root, never the caller's cwd) for the actual section text; a bare `CLAUDE.md Sec."..."` reference does not resolve because CLAUDE.md at the plugin root is not loaded as runtime context.
4. **Prioritized** -- Must Have / Should Have / Could Have
5. **No vague language** -- "fast" -> "< 200ms p95 at 1000 QPS"
6. **Cross-referenced** -- actual file paths, API names, library versions
7. **Appropriate length** -- 800+ lines major, 200+ focused, 50+ small change

These are substance signals, not padding targets: match the length of the document to what the
task needs, cover the substance, and do not pad with filler sections, redundant summaries, or
boilerplate. A draft below the floor is probably missing substance, not merely short.

## SRD Template

```markdown
# {Initiative Name} -- Software Requirements Document

## 1. Document Information
| Field | Value |
|---|---|
| Version | 1.0.0 |
| Status | Draft |
| Owner | {name} |
| Last Updated | {date} |

### Revision History
| Version | Date | Author | Summary |

## 2. Executive Summary
## 3. Purpose & Scope (In/Out/Definition of Done)
## 4. Current State Assessment
## 5. Target Architecture (Mermaid diagrams)
## 6. Feature Requirements
### {PREFIX}-01: {Title}
- **Priority**: Must Have / Should Have / Could Have
- **Description**: [what must be true]
- **Acceptance Criteria**: [- [ ] testable items]
- **Dependencies**: {PREFIX}-NN (if any)
- **Target Components**: path/to/file
## 7. Security Requirements
## 8. Observability Requirements
## 9. Performance Targets
## 10. Risks & Mitigations
## 11. Glossary
```

## Mode-Specific SRD Requirements

### mini-SRD mode (mode=mini-srd)

The fused file folds Phases 2-5 into one audited document. Section layout (in order):

```markdown
## 1. Document Information / Executive Summary / Purpose & Scope / Current State / Architecture Ref
## 2. Feature Requirements  (SRD body)
## 3. Risks & Mitigations   (SRD body)
## --- Ticket List ---       (Phase 4 equivalent -- numbered tickets with ACs)
### {PREFIX}-T01: {title}
- **Size**: S/M/L
- **AC**: [ ] ...
```

- The fused file still has a version (`Generated From: srd.md vX.Y.Z`) and a defined audit target.
- `edm-state skip-phase` records that Phases 4-5 are fused/omitted.
- The SRD audit in Phase 3 reads the fused file; no separate ticket pack is created.

### IaC mode (mode=iac)

- Requirement targets are stated as **resource paths** (e.g., `aws_s3_bucket.logs`,
  `azurerm_virtual_network.main`) rather than source-file paths.
- Example: "Target Components: `aws_lambda_function.processor` (new), `aws_iam_role.processor_role` (modified)"
- The SRD's `## 5. Target Architecture` should reference the Terraform module layout and drift expectations.

### Data/ML mode (mode=data-ml)

The SRD **MUST** include a `## Data Requirements` section (exactly that heading so auditors can
detect presence/absence) covering:

- **Data sources**: where data comes from (databases, streams, APIs, files)
- **Schema**: field names, types, nullable constraints for each source
- **Volume**: expected row counts, data rates, storage estimates
- **Quality & labeling**: null-rate thresholds, labeling approach, holdout/train split

If this section is absent from an SRD produced under `mode=data-ml`, the SRD audit flags it as a P0 gap.

## AI Execution Pattern

Before spawning `edm-srd-writer`, resolve the SRD pattern-library paths (AD6/route (c) --
`edm-srd-writer` carries no `Bash` grant, so this skill resolves and interpolates both paths
rather than the agent calling `get-patterns` itself):
```bash
SRD_PATTERN_PATHS="$(edm-state get-patterns srd --paths)"
SRD_PATTERN_SEED="$(printf '%s\n' "$SRD_PATTERN_PATHS" | sed -n '1p')"
SRD_PATTERN_DELTA="$(printf '%s\n' "$SRD_PATTERN_PATHS" | sed -n '2p')"
```

```
Agent: edm-srd-writer
Prompt: "Write the SRD for {PREFIX}. First resolve the initiative directory:
         INIT_DIR=$(edm-state resolve-dir <PREFIX>)
         Write to ${INIT_DIR}/${user_config.srd_filename}.
         Read the planning doc and existing referenced files. Cover all applicable sections.
         Use requirement IDs {PREFIX}-01 through {PREFIX}-NNN. Every requirement must be testable.
         Pattern library: Read ${SRD_PATTERN_SEED} first, then Read ${SRD_PATTERN_DELTA} if it
         is non-empty and exists -- treat the two as one document, seed first. Do not resolve
         these paths yourself.
         [mode=data-ml: include ## Data Requirements section]
         [mode=iac: use resource paths in Target Components]
         [mode=mini-srd: produce fused file with embedded ticket list section]"

Agent: edm-architect
Prompt: "Write the Target Architecture document for {PREFIX}. First resolve the initiative directory:
         INIT_DIR=$(edm-state resolve-dir <PREFIX>)
         Write to ${INIT_DIR}/architecture.md.
         Include Mermaid diagrams (system context + sequence) and component design grounded in
         the existing codebase. The SRD Section 5 references this file -- do not duplicate content.
         Follow CLAUDE.md Sec."Mermaid diagram conventions" for label text -- a raw semicolon
         in a label is a violation. Read docs/canonical-sections.md (resolved relative to the
         EDM plugin's own root -- plugins/edm/ in this repository, or the installed plugin's
         cache root, never the caller's cwd) for the actual section text; a bare CLAUDE.md
         Sec."..." reference does not resolve because CLAUDE.md at the plugin root is not
         loaded as runtime context."
```

For large SRDs, run multiple `edm-srd-writer` agents in parallel (one per section group). Always run `edm-architect` separately -- it writes `architecture.md`, not the SRD body.

## Related Initiatives Section (when linkage exists)

When `parent_prefix` or `related_prefixes` are non-empty in state, the SRD must include a
`## Related Initiatives` section (after `## 1. Document Information`):

1. Read linkage from state:
   ```bash
   edm-state get <PREFIX> | jq -r '{parent_prefix: (.parent_prefix // ""), related_prefixes: (.related_prefixes // [])}'
   ```
2. Resolve each prefix to its initiative directory via `edm-state resolve-dir <RELATED_PREFIX>`.
3. Emit the section:
   ```markdown
   ## Related Initiatives

   | Role | Prefix | Directory |
   |------|--------|-----------|
   | Parent | {PARENT_PREFIX} | {parent_dir} |
   | Sibling | {SIBLING_PREFIX} | {sibling_dir} |
   ```
4. If a prefix no longer resolves, show `(unresolved)` in the Directory column.
5. If neither `parent_prefix` nor `related_prefixes` are set, omit this section entirely.

The rendering must be ASCII-only; do not use Unicode markers.

## Common Mistakes

- Untestable requirements ("should be user-friendly")
- Missing diagrams ("I'll figure it out during implementation")
- Everything as Must Have
- Vague language

After writing, the next step is automatic: `/edm:audit-srd <PREFIX>`.

This phase presents no gate of its own (except the `mode=prototype` stop above, which is not an
approval gate) -- Gate 2 is presented by `/edm:audit-srd` per
`skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"`.
