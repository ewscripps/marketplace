---
name: orchestrator
description: Run the full Enterprise Development Methodology (EDM) -- all 6 phases with 3 HITL gates. Invoked explicitly via /edm:orchestrator <initiative>. The initiative can be plain text, a file path, or a Jira ticket key. Use when starting a new feature, refactor, or service that touches 10+ files.
disable-model-invocation: true
model: opus
effort: max
argument-hint: '<initiative description | /path/to/file | PROJ-123>'
allowed-tools: Read, Write, Edit, Bash(edm-state *), Bash(edm-init *), Bash(edm-validate-prefix *), Glob, Grep, Task, TodoWrite, AskUserQuestion, Skill
---

# EDM Orchestrator

You are dispatching a complete Enterprise Development Methodology (EDM) initiative. The user invoked
`/edm:orchestrator` with:

**Raw input**: $ARGUMENTS

The input may be plain text, a file path, or a Jira ticket key -- Step 1a resolves it into a concrete
initiative description before any planning begins.

## Overview

EDM is a six-phase process for shipping complex software with high confidence: Planning -> SRD -> SRD
Audit -> Tickets -> Ticket Audit -> Implementation, gated by three HITL approvals. The core insight:
**the cost of planning is always lower than the cost of rework**. Each phase's complete procedure
lives in that phase's own skill (`skills/{phase}/SKILL.md`) -- **this dispatcher invokes each phase
via the `Skill` tool and presents its gate; it contains no phase procedure itself**
(`CLAUDE.md Sec."Skill-tool composition"`).

| Scenario                       | Use EDM?                 |
|--------------------------------|--------------------------|
| New feature touching 10+ files | Yes -- full six phases    |
| Large refactor or migration    | Yes                      |
| New service or module          | Yes                      |
| Bug fix (1-3 files)            | No -- just fix it         |
| Config/dependency update       | No -- just do it          |
| Exploratory prototype          | Partial -- Phase 1-2 only (`mode=prototype`) |

| Gate   | After                | Approves                            |
|--------|----------------------|--------------------------------------|
| Gate 1 | Phase 1 Planning     | Scope, constraints, go/no-go        |
| Gate 2 | Phase 3 SRD Audit    | Remediated SRD is correct           |
| Gate 3 | Phase 5 Ticket Audit | Ticket pack is implementation-ready |

## Communication

This governs conversational cadence only -- what is said aloud while dispatching phases. It never
touches how a phase skill writes its own output; length and content of anything written to disk
are that skill's concern, not this one's.

- Before the first tool call, say one sentence stating what is about to happen.
- While work is underway, give a brief update only on an important finding or a change of
  direction -- not a running commentary on every step.
- On finishing, lead with the outcome, then supporting detail if asked.
- Correct an earlier statement only when the error would change the user's code, conclusions or
  decisions; state the correction plainly and briefly, then continue.

## Step 1 -- Intake

Use `bin/edm-state` (on PATH while plugin enabled) to record progress throughout.

**Step 1a -- Resolve the initiative description from `$ARGUMENTS`**

- **Empty**: ask *"What are we building? Describe the initiative, provide a file path, or give a
  Jira ticket key (e.g., PROJ-123)."* Use the answer as the initiative description.
- **Jira ticket key** (`$ARGUMENTS` matches `[A-Z][A-Z0-9]+-\d+`): call
  `getAccessibleAtlassianResources`, then `getJiraIssue`; compose the description from the issue
  summary/description/AC; confirm with the user: *"Using Jira ticket {KEY}: '{summary}'. Proceed?"*
- **File path** (`$ARGUMENTS` starts with `/`, `./`, `~/`, or ends `.md`/`.txt`/`.rst`): `Read` it;
  use the full contents as the description; tell the user *"Using contents of {path}..."*
- **Plain text** (everything else): use `$ARGUMENTS` directly.

Call the resolved value **`INITIATIVE`** -- all subsequent steps use `INITIATIVE`, never `$ARGUMENTS`.

**Step 1b -- EDM qualification, prefix, and resume**

1. Assess whether `INITIATIVE` qualifies for full EDM (10+ files, new module, major refactor). If
   not, say so and suggest doing it directly without EDM.
2. Ask for the **initiative prefix** (hint: `${user_config.prefix_format_hint}`), the **product
   name** (lowercase, inferred from context when clear, else asked alongside the prefix), and the
   **description slug** (derived from `INITIATIVE`, no prompt needed). All three match
   `^[a-z][a-z0-9-]*$` (prefix uppercased separately).
3. `edm-validate-prefix <PREFIX>` -- if `SRD/{PREFIX}/` already exists:
   - Refresh and display the handoff: `edm-state write-handoff <PREFIX>`, then
     `INIT_DIR=$(edm-state resolve-dir <PREFIX>)`, then `Read` and show `${INIT_DIR}/HANDOFF.md`
     verbatim (phase, last gate, next action, artifact checklist, decisions made).
   - `AskUserQuestion` header `"Resume?"`: **Resume** / **Start over**.
   - On **Resume**: skip `edm-init`. Run `edm-state get <PREFIX>` and read **all four
     mode-family fields** (`mode`, `lifecycle_mode`, `compliance_enabled`, `implementation_mode`)
     plus `current_phase`/`current_step` (see "Resume and Compaction" below for what `current_step`
     means post-refactor). State which mode/lifecycle applies (e.g., "Resuming in iac mode,
     fast-track lifecycle") and Skip Step 1c -- the mode is already recorded. Invoke the phase
     skill for `current_phase` directly (Step 2 below).
   - On **Start over**: ask for a new prefix and loop back to step 2.
4. If new: `edm-init --product <product> --description <slug> <PREFIX>` (product-scoped layout;
   creates `${user_config.srd_root}/<product>/<PREFIX>__<slug>/`), then
   `export EDM_PRODUCT=<product>; export EDM_DESCRIPTION=<slug>`, then
   `edm-state write-handoff <PREFIX>`. Flat fallback (legacy/explicit user request only):
   `edm-init <PREFIX>`.

**Step 1c -- Mode and profile selection**

Skipped on resume (Step 1b already read a recorded non-default mode).

1. `AskUserQuestion` header `"EDM mode"` (<=12 chars): **Standard** (Recommended) / **mini-SRD** /
   **IaC** / **Data/ML** / **Prototype**.
2. Present a compliance toggle via `AskUserQuestion` header `"Compliance"`: **Off** (Recommended) /
   **On**.
3. Record: `edm-state set-mode <PREFIX> mode <value>`;
   `edm-state set-mode <PREFIX> compliance_enabled true` (only if On).
4. Mode-family fields and each mode's full behavior are `CLAUDE.md Sec."EDM mode matrix"` --
   consult it before dispatching; do not restate the sub-flows here.

**Step 1d -- Concurrency & branch safety check**

1. `edm-state active-initiatives` -- if more than one is listed, warn the user, naming each active
   prefix and branch (warning, not a block).
2. `edm-state branch-check <PREFIX>` -- if non-zero, **BLOCK** and surface its `git checkout`
   instruction; do not proceed until the branch matches.

## Gate PROTOCOL (canonical)

This is the single definition of gate-approval behavior for every HITL gate in this methodology --
Gate 1, Gate 2, Gate 3, Gate 3.5, the code-audit Convergence gate, and the code-audit Remediation
gate. Every gate site in this plugin references it by name --
`` `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"` `` -- rather than restating it.

**STOP and WAIT for the `AskUserQuestion` response.** Headers are 12 characters or fewer (e.g.,
`"Gate 1"`, `"Gate 2"`, `"Convergence"`). The three standard options are Approve, Revise, No-Go
(a gate may add a fourth option only when its own section documents why, e.g., Gate 3.5's
compliance-specific wording). The `approve-gate` invocation happens only after the selection is
made, never before it.

**CRITICAL -- gate approval rules (apply to ALL gates)**:
- `edm-state approve-gate` is called ONLY when the user selects the **exact "Approve" option** from the `AskUserQuestion` dialog.
- Free-text responses ("yes", "ok", "looks good", "proceed", "sounds good", "go ahead") are **NOT** approvals.
- If the user types free text instead of selecting an option: re-present the `AskUserQuestion` with a brief note: "Please select an option to proceed."
- Never infer intent from sentiment -- only the explicit AskUserQuestion selection counts.

## Step 2 -- Dispatch each phase

Invoke each phase skill via the `Skill` tool, passing `<PREFIX>` (and any accumulated context); each
phase skill runs its own Step 0 preflight, executes its procedure in full (`skills/{phase}/SKILL.md`
is the single source of truth -- EDMV3-T37), and presents its own gate per the PROTOCOL above. This
dispatcher never restates a phase's steps, agent-spawn templates, or artifact templates.

**Graceful degradation**: if a `Skill`-tool invocation fails with `tool_use_error: Unknown skill:
<name>`, report to the user exactly which skill is unavailable and what plugin/skill to enable.
This dispatcher does not fall back to inlining that phase's procedure, and does not silently
continue (`CLAUDE.md Sec."Skill-tool composition"`).

1. **Phase 1 (Planning)**: invoke `/edm:plan <PREFIX>` `<INITIATIVE>`. Presents Gate 1.
2. **Phase 2 (SRD)**: invoke `/edm:srd <PREFIX>`. Runs its own Phase 3 handoff automatically (no
   gate between Phase 2 and 3) -- under `mode=prototype`, `skills/srd/SKILL.md` stops here instead.
3. **Phase 3 (SRD Audit)**: invoke `/edm:audit-srd <PREFIX>` (auto-invoked by step 2 above unless
   already run). Presents Gate 2 (or the mini-SRD merged `"Gate 2+3"`).
4. **Phase 4 (Tickets)**: invoke `/edm:tickets <PREFIX>`. Runs its own Phase 5 handoff
   automatically -- under fast-track/fix-pack, `skills/tickets/SKILL.md` presents
   `"Gate 3 -- Ticket Review"` directly instead.
5. **Phase 5 (Ticket Audit)**: invoke `/edm:audit-tickets <PREFIX>` (auto-invoked by step 4 above
   unless already run, or skipped entirely by fast-track/fix-pack). Presents Gate 3, then Gate 3.5
   when `compliance_enabled=true`.
6. **Phase 6 (Implementation + QC + Code Audit + Closure)**: invoke `/edm:implement <PREFIX>`.
   When all tickets PASS, invoke `/edm:code-audit <PREFIX>` (mandatory for `standard`/`tdd`
   `implementation_mode`; `prototype` may skip convergence) --
   `/edm:code-audit` Step 10 presents the Convergence gate itself; this dispatcher does not
   restate it. When code-audit converges, invoke `/edm:verify-runtime <PREFIX>` via the `Skill`
   tool to close every PARTIAL verdict, then call `edm-state phase-complete <PREFIX> 6` (EDMV3-T50
   -- this dispatcher's Phase 6 entry is the single owner of that call; `skills/implement/SKILL.md`
   Step 8 states the same two-command sequence only for the standalone/direct-invocation path,
   where the user runs both commands without going through this dispatcher).

## Resume and Compaction

`current_step` (post-refactor vocabulary): a bare phase number, `"1"`..`"6"` -- the dispatcher jumps
straight to that phase skill's own Step 0, which re-derives any finer-grained position itself. A
legacy 2.x value (`1a`, `1b`, `1c`, `2.srd`, `2.arch`, `4.epic-N`, etc.) resumes at the **start** of
its phase with a warning naming the legacy value seen, rather than erroring (recorded in
`CHANGELOG.md`). `SessionStart` prints in-progress initiatives via `edm-state list`; `PreCompact`/
`Stop` opportunistically checkpoint state; HANDOFF.md is refreshed at every phase/gate/stop by the
phase skill or `edm-state write-handoff` directly.

## Anti-Patterns

- **Skip the SRD** -- scope creeps, contradictions emerge, tickets lack context.
- **Skip an audit** -- errors propagate to every ticket and every line of code.
- **Auto-approve HITL gates** -- defeats the purpose; human misalignment is 10x cheaper to fix now
  than after implementation.
- **One monolithic implementation pass** -- context exhaustion, no parallelism.
- **XL tickets** -- must be decomposed before starting.
- **Inline a phase's procedure here "just this once"** -- the dispatcher only invokes and gates; see
  `CLAUDE.md Sec."Skill-tool composition"`.

Never auto-approve a HITL gate. Never skip a phase. Always record state via `edm-state`. Artifact
layout, phase timing guidance, and the full mode matrix are `CLAUDE.md Sec."Project artifact
layout"`, Sec."Phase Timing Guidelines"`, and Sec."EDM mode matrix"` respectively -- referenced by
name here, not duplicated.

<tone_preference>
Be direct and concise: lead with the outcome, skip preamble, and never pad a reply for length.
</tone_preference>
