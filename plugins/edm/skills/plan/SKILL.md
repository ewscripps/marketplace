---
name: plan
description: EDM Phase 1 (Planning & Discovery) -- explore the codebase, define scope, map dependencies, produce a go/no-go decision. Invoked explicitly via /edm:plan.
disable-model-invocation: true
model: opus
effort: max
argument-hint: <PREFIX> <initiative description>
allowed-tools: Read, Write, Edit, Bash(edm-state *), Bash(edm-init *), Bash(edm-validate-prefix *), Glob, Grep, Task, TodoWrite, AskUserQuestion
---

# EDM Phase 1: Planning & Discovery

**Arguments**: $ARGUMENTS

- **Input**: Business requirement, feature request, or strategic initiative
- **Output**: `${user_config.srd_root}/{PREFIX}/planning.md` -- scope definition, current-state assessment, go/no-go decision

**Plugin asset note**: every `docs/...` reference in this skill is relative to the EDM plugin root (`plugins/edm/` in this repository, or the installed plugin root in cache). Resolve the plugin root before reading those files; never assume the current working directory is the plugin root.

## Step 0 -- Gate and Branch Preflight

Before Step 1 (or any other step, on a fresh invocation or a resume), every phase skill in this
methodology runs two read-only checks. This text is written once, here -- every other phase
skill (`srd`, `audit-srd`, `tickets`, `audit-tickets`, `implement`, `code-audit`,
`verify-runtime`) references it by name --
`` `skills/plan/SKILL.md Sec."Step 0 -- Gate and Branch Preflight"` `` -- rather than restating it,
substituting its own `<gated-command>` token.

**This is defence in depth on the Skill-tool path, not the deterministic layer.** Prompt text
(Tier 3, SRD Section 5.1) "cannot be bypassed by: nothing" -- the requirement that actually
restores deterministic enforcement when a phase is reached through the Skill tool rather than
direct user invocation is EDMV3-115 (landed in wave A as EDMV3-T13), inside `cmd_gate_check`
itself. Step 0 is a second, defence-in-depth line alongside the `UserPromptExpansion` hooks
(`hooks/hooks.json`), which are retained unchanged and fire only on direct invocation.

1. **Gate check**: run `edm-state gate-check <PREFIX> <gated-command>`, where `<gated-command>`
   is this skill's own token -- `plan` for this skill. Whether this phase's gate applies at all
   under the initiative's current mode is computed entirely inside `cmd_gate_check` itself; that
   mode-suppression logic is not restated here or in any other phase skill.
   If it exits non-zero, **BLOCK**: do not proceed with the phase, and surface the exact message
   the command printed.
2. **Branch check**: run `edm-state branch-check <PREFIX>`. If it exits non-zero, **BLOCK**: do
   not proceed with the phase, and surface the `git checkout <initiative_branch>` instruction it
   printed. This is a behaviour change on the standalone-skill path (CHANGELOG.md) -- previously
   `branch-check` hard-blocked only at the orchestrator's Step 1d.

## Operational Orchestration

1. Parse `$ARGUMENTS` for `{PREFIX}` and the initiative description. If missing, ask the user.
2. `edm-validate-prefix <PREFIX>` -- if SRD/{PREFIX}/ already exists:
   - Refresh and display the handoff:
     ```bash
     edm-state write-handoff <PREFIX>
     INIT_DIR=$(edm-state resolve-dir <PREFIX>)
     ```
   - Read `${INIT_DIR}/HANDOFF.md` and display it verbatim, then ask whether to resume or pick another prefix.
3. If new: prompt the user for a one-word **product** name (e.g., `auth`, `payments`) and a short **description slug** (e.g., `user-auth-rewrite`). Then:
   ```bash
   edm-init --product <product> --description <slug> <PREFIX>
   export EDM_PRODUCT=<product>; export EDM_DESCRIPTION=<slug>
   ```
   (The exports are required so subsequent `edm-state` calls resolve the product-scoped directory.)
4. `edm-state phase-start <PREFIX> 1`
5. Spawn `edm-explorer` agent(s) -- see "AI Execution Pattern" below.
6. Synthesize agent output into the planning document at `${user_config.srd_root}/{PREFIX}/planning.md` using the template below.
7. `edm-state phase-complete <PREFIX> 1`
8. `edm-state write-handoff <PREFIX>` -- create/refresh HANDOFF.md from the just-written planning.md. This is idempotent; re-running regenerates HANDOFF.md without error.
9. **Resolve Open Questions interactively** before presenting the gate:
   a. Read the `## Open Questions` section of `planning.md`.
   b. Collect all `[DECISION: ...]` questions. Batch them into `AskUserQuestion` calls (up to 4 per call).
      - Use a <=12-char header that names the decision (e.g., `"Auth method"`, `"DB approach"`).
      - Parse the options from the tag brackets -- those become the selectable choices.
      - Always append a `"Resolve in SRD"` option so the user can skip without blocking.
   c. If any `[OPEN]` questions remain, output them as a numbered list and wait for the user's typed
      response before continuing.
   d. Write all answers into the `## Decisions Made` section of `planning.md` (one `- Question: Answer`
      line each). Strike or remove resolved items from `## Open Questions`.
10. Present **HITL Gate 1** (see below, per `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"`) and STOP for sign-off.
11. On **Approve** (explicit selection only): `edm-state approve-gate <PREFIX> 1`. Then append Gate 1
    scope decisions into `decisions.md` in the initiative directory:
    ```
    | Gate 1 | <decision text> | <chosen> | <rationale> | {date} |
    ```
    On **Revise**: ask what context is missing, then rework the planning document with that additional
    context and re-present the gate.
    On **No-Go**: summarize the blockers and stop. Do not archive -- leave state for the user to revisit.

## Activities -- the agent must cover ALL

### 1. Understand the Existing System
- Explore the codebase
- Read CLAUDE.md, README.md, architecture docs
- Map how components connect
- Identify tech stack, frameworks, patterns

### 2. Identify the Gap
- What exists today vs. what is needed?
- What works well that should be preserved?

### 3. Define Scope Boundaries
- **In scope**: what this delivers
- **Out of scope**: explicit exclusions
- **Follow-on initiatives**: recorded scope boundaries

### 4. Identify Constraints
Licensing, code ownership, regulatory requirements, platform limitations, team expertise.

### 5. Map Dependencies
What this touches, what blocks what, external service dependencies.

### 6. Estimate Complexity
Files affected, new modules, integration points, approximate ticket count (S/M/L).

## Planning Document Template

> **Planning authoring guidance** (from plugin-root-relative `docs/audit-patterns/srd-audit.md`):
> - **`## Go/No-Go`** -- an explicit GO/NO-GO/CONDITIONAL here prevents "undefined scope boundary" (top SRD P1 finding).
> - **`## Riskiest Assumptions`** -- pre-empts "requirement assumed but never validated" (top SRD P0/P1 finding).
> - **`## Open Questions`** -- tag with `[DECISION: A|B|C]` to surface bounded choices at Gate 1; resolves "ambiguous requirement" findings.
> - **`## Decisions Made`** -- filled at Gate 1; feeds HANDOFF.md and `decisions.md`. Empty section = highest SRD-rewrite rate in the corpus.

```markdown
# {Initiative Name} -- Planning & Discovery

## Scope Statement
[1-2 paragraphs]

## Component Inventory
| Component | Path | Status | Notes |
|---|---|---|---|

## Constraints
- [ ] Constraint 1

## Dependency Map
[What blocks what]

## Complexity Estimate
- Files affected: ~N
- New modules: N
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

## AI Execution Pattern

Spawn one `edm-explorer` agent per genuinely distinct codebase area, **maximum 4**. If one
explorer can cover the whole scope, use one. The cap is 4 for consistency with the
`AskUserQuestion` four-option convention and with the plugin's other fan-outs (exactly 2 ticket auditors,
2-3 SRD auditors) -- and because a fifth genuinely distinct area is a signal the initiative should
be split rather than explored wider. A "genuinely distinct area" is judged concretely:
distinct top-level source trees (e.g., `frontend/` vs. `backend/` vs. `infra/`), or distinct
subsystems explicitly named in the initiative description -- not a subjective read of "how big"
the change feels.

```
Agent: edm-explorer
Prompt: "Explore the codebase to understand [area]. Map all components,
         identify gaps vs [requirement]. Report current state, gap analysis,
         component inventory, constraints, dependency map, and complexity estimate
         per the EDM Phase 1 template."
```

## HITL Gate 1

After writing the planning document:
1. Summarize concisely: scope (1-2 sentences), components affected, key constraints, estimated initiative size, go/no-go recommendation.
2. Present the gate per `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"` -- header `"Gate 1"`, options **Approve** / **Revise** / **No-Go**. **STOP and WAIT** for the response.
3. On **Approve** (explicit selection only): `edm-state approve-gate <PREFIX> 1`. The next phase is `/edm:srd <PREFIX>` or via `/edm:orchestrator`.
   On **Revise**: rework the planning document per the feedback and re-present the gate.
   On **No-Go**: summarize the blockers and stop.
