# EDM Plugin Review -- Outside Expert Assessment

**Date**: 2026-07-25
**Scope**: `plugins/edm/` (v2.0.0), `SRD/edm/EDMV3__prompt-streamline/`, `SRD/.archived/EDMV2/`
**Method**: read every skill, agent, hook, and bin script; read the archived EDMV2 initiative end to end including the 2026-06-10 external audit; ran the plugin's own smoke suites (wave3: 18/18, wave4a: 58/58 pass); ran `claude plugin validate` (passes, one warning); exercised the real orchestrator path on a live initiative (EDMV3) and reproduced two defects in a scratch git repo. Everything cited below is `file:line` against the current tree. Claims I could not verify directly are marked **[inferred]**.

---

## Step 1 -- What EDM is for

### The job

EDM is a waterfall-with-gates software delivery methodology, encoded as Claude Code prompts, for one purpose: making LLM-driven development of *non-trivial* work (10+ files, new modules, migrations) trustworthy enough to ship. It replaces "ask Claude to build the feature" with a six-phase pipeline -- plan, specify, audit the spec, ticket, audit the tickets, implement-with-QC -- where a human signs off at three gates and every intermediate artifact (planning doc, SRD, ticket pack, audit reports, findings ledgers) is committed to git as a first-class deliverable. Its core belief is stated outright in `skills/orchestrator/SKILL.md:23-24`: *"the cost of planning is always lower than the cost of rework."* Its second, unstated belief is more interesting: a single LLM pass is untrustworthy, but many LLM passes with orthogonal mandates, checking each other, converge on trustworthy. That belief is why there are 30 agent definitions, 11 audit lenses, dual ticket auditors, an auto-spawned QC auditor, and a cross-round findings ledger.

The audience is a developer (in practice, so far, the author -- see Open Questions) at an enterprise (Scripps) who needs the output to survive review: SRDs in PRs, audit findings in commit history, Jira sync, and an ROI story (`/edm:metrics` computes "Claude cost vs. human baseline" multiples). The `EDM_Plugin_Presentation.pptx` sitting in the plugin root says the ROI story is not incidental -- this artifact is also meant to *justify itself to management*.

### The intended user journey

1. `/edm:orchestrator <description>` -> prefix, product, mode selection -> `edm-init` scaffolds `SRD/{product}/{PREFIX}__{slug}/` and a feature branch.
2. Phase 1: explorer agents map the codebase -> `planning.md` -> resolve open questions interactively -> **Gate 1** (human approves scope).
3. Phases 2-3: SRD writer + architect in parallel -> 2-3 SRD auditors -> remediate P0/P1 -> **Gate 2**.
4. Phases 4-5: ticket writer -> dual ticket auditors -> remediate -> **Gate 3**.
5. Phase 6: implementer waves in isolated worktrees, each auto-QC'd by a hook; remediation loops until all tickets PASS; then an 11-lens code audit loops to "convergence" (zero open P0/P1); archive.
6. Throughout: `bin/edm-state` records phases, gates, costs, coverage in a committed JSON file; `HANDOFF.md` lets a teammate resume mid-flight.

### What it believes

- Planning always beats rework (asserted, never measured against an alternative).
- LLM audit fan-out with orthogonal mandates catches what single passes miss (plausible, also never measured -- see F10).
- Process compliance can be achieved primarily through *instruction text*, with a thin bash layer for state bookkeeping (this is the load-bearing assumption, and it is false -- see F1).
- Git-committed artifacts are the collaboration and audit medium (good belief, genuinely well executed).
- The user will follow the happy path (the unhappy paths -- wrong branch, half-finished phases, concurrent sessions -- get warnings at best).

### Where the intent is divided

1. **Autonomous pipeline vs. human-checkpointed methodology.** The gates say "human decides." But `code_audit_converged` -- the flag that unlocks archiving -- is set by the model itself the moment a round shows zero P0/P1 (`skills/code-audit/SKILL.md:57`), and the orchestrator's own anti-pattern list says *"Never auto-approve a HITL gate"* (`skills/orchestrator/SKILL.md:645`). The plugin cannot decide whether the machine or the human owns "done." (EDMV3's first requirement is to fix exactly this -- the tension has already bitten its own author.)
2. **Delivery tool vs. justification artifact.** Elaborate cost tracking (`bin/edm-state:188-281`) computes per-phase Claude cost against a hardcoded $150/hr human baseline to produce "Nx cheaper" figures -- yet the tracking silently missed the entire Phase 6 of its own flagship initiative (see F6), and nothing in the pipeline ever *acts* on a cost number. The machinery exists to produce a slide, not to steer decisions.
3. **One flow vs. two.** Every phase exists twice: inside the 645-line orchestrator and as a standalone skill. `CLAUDE.md:22-23` declares this duplication intentional ("Skills don't load other skills"). Nothing keeps the copies in sync, and they have already diverged in a behaviorally significant way (F5).
4. **`monitors/`, `lifecycle_mode=partial`, `TaskCompleted` hook** -- half-built stubs whose purpose is only recoverable from ticket archaeology. `cmd_record_task_duration` is an admitted no-op (`bin/edm-state:753-758`).

The intent is legible overall -- I could reconstruct it confidently, which speaks well of the documentation. The division sits in one place: **who enforces the process, prose or mechanism.**

---

## Step 2 -- The gap

Ranked by consequence. Severity / Effort-to-fix / Confidence at the end of each.

### F1. The state machine does not enforce its own invariants -- the entire lifecycle can be bypassed in three commands

The methodology's value proposition is *enforced rigor*. Here is the enforcement, exercised empirically in a scratch repo:

```
$ edm-init --product demo --description branch-test TESTX     # phase 0, zero gates
$ edm-state set TESTX code_audit_converged true                # accepted
$ edm-state archive TESTX                                      # "archived TESTX -> ./SRD/.archived/demo/TESTX__branch-test"
```

A phase-0 initiative with **no phases run and no gates approved** archives cleanly. `cmd_archive` (`bin/edm-state:860-903`) checks exactly one thing -- `code_audit_converged` -- and that flag is a plain settable boolean, allowlisted in `cmd_set` (`bin/edm-state:479-484`). It never looks at `gates_approved` or `current_phase`. Meanwhile the prompts *instruct* the model to set the flag itself (`skills/code-audit/SKILL.md:57`, `skills/orchestrator/SKILL.md:557-558`).

The actual mechanical enforcement surface is three items: the `UserPromptExpansion` gate-check on five skills (`hooks/hooks.json:13-78`), the archive convergence check above, and the pre-commit artifact lint (`hooks/hooks.json:80-89`). Everything else -- "STOP and WAIT", "free-text is never approval", "never skip a phase", phase ordering, artifact completeness -- is instruction text that a model under context pressure, after compaction, or invoked via a side path will eventually not follow.

This is not hypothetical, and it is not new. It is the **third documented instance of the same defect class**:

- 2026-06-10 external audit: Gate 3.5 "documented and tested by text-presence checks, but the state script could not record gate 3.5, and gate-check did not enforce it" (`SRD/.archived/EDMV2/edm-plugin-audit-findings-2026-06-10.md:50-74`). Fixed -- for that gate.
- EDMV3 requirement #1 (2026-07): convergence auto-set with no sign-off. Same class, next instance.
- This review, live: I watched a session (the one producing EDMV3) blow straight past the methodology on first invocation -- full implementation executed with zero phases, zero gates, no state file -- because nothing mechanical stood in the way and 645 lines of orchestrator prose didn't hold. The state machine recorded nothing because nothing forces it to be consulted.

*Strongest case for the current design*: Claude Code hooks genuinely can't intercept everything; prose-first shipped v2.0 and mostly works when the author drives it attentively. *Why it doesn't hold*: the failure recurrence is empirical, the plugin's own audit history documents it, and cheap mechanisms exist and are already half-used (the expansion hooks prove the pattern works -- they just cover 5 of ~15 critical transitions).

**Severity: breaks things (silently -- worst kind). Effort: M. Confidence: high (reproduced).**

### F2. First-run experience is broken twice: a new user cannot reach first success unaided

**(a) `edm-init` records the wrong branch, then the orchestrator hard-blocks on it.** `bin/edm-init:139` calls `edm-state init` -- which snapshots `initiative_branch` from `git rev-parse --abbrev-ref HEAD` (`bin/edm-state:510`) -- **before** creating and switching to the initiative branch at `bin/edm-init:164`. Reproduced:

```
Branch: created and switched to branch edm/testx-branch-test
--- state initiative_branch: main
edm-state branch-check: current branch 'edm/testx-branch-test' does not match initiative_branch 'main'.
Run: git checkout main        <- this advice is actively wrong
```

Orchestrator Step 1d treats a branch-check failure as a hard BLOCK (`skills/orchestrator/SKILL.md:296-298`). So **every fresh initiative** stalls at Step 1d, and the printed remedy moves the user *off* their initiative branch. The live EDMV3 run hit this and required manual state surgery (`edm-state set EDMV3 initiative_branch ...`).

**(b) The README installs a plugin that doesn't exist.** `README.md:11` and `:14` say `claude plugin install ./plugins/edm-ai-development` -- the directory was renamed to `plugins/edm` (commit `fe5d0f0`). Step one of the documented journey 404s.

**Severity: breaks things on every new initiative. Effort: S. Confidence: high (reproduced).**

### F3. Agents are instructed to do things their tool grants forbid -- a defect class that was found, fixed once, and left alive in two other agents

- `edm-qc-auditor` has `disallowedTools: Write, Edit, NotebookEdit` and **no `Bash`** (`agents/edm-qc-auditor.md:5,10`). Its own prompt tells it to "Write your report to `<initiative-dir>/qc/`" (`:23`), "Run `mkdir -p <initiative-dir>/qc` before writing" (`:76`), and resolve paths via `edm-state get <PREFIX> | jq` (`:68`). The `SubagentStop` hook additionally instructs it to call `edm-state record-partial-verdict` (`hooks/hooks.json:117`, step 6). Every one of those operations is impossible under its grant. The QC layer -- the thing the SubagentStop hook exists to guarantee -- cannot deliver its artifact. **[inferred: what actually happens at runtime is the spawning context absorbs the failure or writes on its behalf; what would confirm it is one Phase 6 run with transcript inspection. The grant/instruction contradiction itself is verified.]**
- `edm-explorer`: same contradiction -- told to "Write your findings to `explorers/{NN}-{slug}.md`" (`agents/edm-explorer.md:61`) with `disallowedTools: Write, Edit` (`:10`). Verified live: both EDMV3 explorer agents returned reports as text with "I have no Write tool" apologies, and the orchestrating session had to persist them manually.
- The class was already discovered for `edm-test-coverage-auditor` and fixed in EDMV2 (`SRD/.archived/EDMV2/qc/EDMV2-T01-T02.md`). The response to that fix is the most telling artifact in the repo: instead of auditing the *class* (grep all agents for write-instructions vs. grants), a permanent manual step was added to the Phase 6 done-checklist telling the model to re-grep that one agent's frontmatter on every future initiative, forever (`skills/implement/SKILL.md:162-172`). Instance-fixing, encoded as ritual.

**Severity: bites under normal use. Effort: S. Confidence: high.**

### F4. Two entry paths, two different gate protocols -- the duplication has already drifted where it matters most

The orchestrator mandates the strong gate protocol: `AskUserQuestion` with exact options, "free-text responses ('yes', 'ok', 'looks good') are NOT approvals," re-present on free text (`skills/orchestrator/SKILL.md:396-400`). The standalone phase skills -- which the hooks and README present as equally valid entry points -- use the weak protocol: *"Ask: 'Do you approve this scope...?'"* then "On approval: `edm-state approve-gate`" (`skills/plan/SKILL.md:130-132`, `skills/audit-srd/SKILL.md:122-124`, `skills/audit-tickets/SKILL.md:127-129`). Invoke `/edm:audit-srd` directly and a typed "looks good" becomes a recorded Gate 2 approval; invoke `/edm:orchestrator` and it doesn't. The methodology's single most safety-critical behavior depends on which command the user happened to type.

Smaller drift is visible too -- the orchestrator's own step lists have duplicate numbering from hand-editing (two "5." items in Step 3 at `skills/orchestrator/SKILL.md:417-423`, again in Step 4 at `:432-433`, again in Step 6 at `:478-479`). Harmless individually; collectively they are what unguarded hand-maintained duplication always becomes.

**Severity: bites under normal use (gate integrity). Effort: M (structural) / S (patch the skills). Confidence: high.**

### F5. The findings pipeline is free-text end to end, so "convergence" is a model's opinion about markdown

Lenses write free-form markdown reports; the synthesizer "merges findings with the ledger" by "component + summary similarity (not literal text)" (`agents/edm-audit-synthesizer.md:140`); convergence is determined by a model reading the resulting table; the blocking set is whatever the synthesizer decided to write down. There is no machine-checkable representation of a finding anywhere in the pipeline. Consequences:

- Convergence cannot be computed; it can only be asserted. EDMV2's own history shows what that costs: the ledger said four P1s open / not converged while HANDOFF and state said all fixed -- a contradiction that stood until an external audit forced reconciliation (`edm-plugin-audit-findings-2026-06-10.md:76-91`).
- Cross-round identity ("matching uses component + summary similarity") is exactly the kind of judgment LLMs do inconsistently, and every mismatch either resurrects a fixed finding or silently drops an open one.
- The double False-Alarm filter (per-lens `agents/edm-audit-logic.md:43-50`, plus synthesizer criterion 4 discarding single-lens uncorroborated findings, `agents/edm-audit-synthesizer.md:39`) is the recall-suppression pattern both current Anthropic model guides explicitly warn against in review harnesses -- with no confidence field to rank on, the synthesizer discards blind. **[inferred: actual recall loss unmeasured; confirmable by re-running an archived audit with the filter framing changed.]**

**Severity: bites under normal use (process-integrity core). Effort: M. Confidence: high for the structural claim.**

### F6. The economics are instrumented but not true, and nothing consumes them

Real data from the flagship initiative (`SRD/.archived/EDMV2/.edm-state.json`):

```
1_phase: 4371s  $20.04   218k out-tokens  claude-opus-4-8
2_phase:  824s   $0.95    26k             claude-sonnet-4-6
3_phase: 1089s   $2.66    59k
4_phase:  910s   $2.82   122k
5_phase:  921s   $3.98   112k
6_phase:    0s   $0.00     0              ?        <- the implementation phase
```

Phase 6 -- implementation, QC, remediation, plus **two full 11-lens code-audit rounds** (`audit_rounds: {"code": 2}`, i.e., 22 opus/max lens invocations plus synthesizers) -- recorded zero seconds and zero dollars. The single most expensive stretch of the methodology is invisible to its own metrics, which means `/edm:metrics`' "Nx cheaper than human" output and the README's timing table are built on data that omits the dominant cost. Two more integrity problems: token attribution sums *every* session JSONL in the project directory since the phase-start timestamp (`bin/edm-state:206-225`), so any concurrent session inflates a phase's cost **[inferred: not tested with two live sessions, but the code path is unambiguous]**; and the pricing table is hardcoded for Opus 4.7 / Sonnet 4.6 (`bin/edm-state:227-257`, `CLAUDE.md` pricing section) -- one model generation stale.

**Severity: friction and debt (but it corrupts the plugin's headline claim). Effort: S-M. Confidence: high.**

### F7. PARTIAL verdicts are a one-way door -- ACs can be deferred to runtime that never comes

QC semantics are genuinely well designed (see "What's good"), but the lifecycle is: PARTIAL is recorded (`edm-state record-partial-verdict`), listed in `exec-report.md`, explicitly excluded from remediation ("PARTIAL findings do not require remediation -- they are deferred to runtime verification," `skills/implement/SKILL.md:105`), excluded from the done-checklist, not checked by `archive`, and `post-deploy/verification.md` is optional/on-demand (`skills/orchestrator/SKILL.md:565`). Nothing ever closes them. An initiative can converge, archive, and ship with acceptance criteria that were never verified by anyone or anything -- and the paper trail will look complete. Note also `skills/implement/SKILL.md:95` remediates "P0/P1 FAIL findings" only; P2 FAILs are silently out of scope, which contradicts the new EDMV3 no-deferral requirement before it's even implemented.

**Severity: bites under normal use (silent). Effort: S-M. Confidence: high.**

### F8. Everything runs at maximum spend by default, and the one flag that could tier it is buried

Every judgment agent is `opus`/`max` -- including purely mechanical mandates like L5 (grep runtime files vs. `.gitignore`) and L2 (grep for dead code), and including three simultaneous SRD auditors reading the same document. The deterministic spawn caps are good discipline, but there is no cheap pass: a full code-audit round is 12 opus/max agents minimum, twice if any finding is found (a second full round is mandated for convergence). `--lenses` exists (`skills/code-audit/SKILL.md:27-30`) but nothing in the flow recommends a tiered strategy, and the "when to use EDM" table has nothing between "mini-SRD" and the full pipeline for the audit stage. Given F6, nobody can currently see this cost -- which is presumably why it hasn't hurt yet. **[inferred: actual per-round cost; EDMV2's untracked Phase 6 prevents measuring it, which is itself the finding.]**

**Severity: friction and debt. Effort: S (policy) . Confidence: high on structure, medium on magnitude.**

### F9. The self-improving pattern library appends unreviewed stubs that get injected into every future writer prompt

`cmd_update_patterns` (`bin/edm-state:1576-1692`) extracts `###` headings from audit reports and appends, at end-of-file, entries whose body is literally *"Review and refine: add a one-paragraph description..."* (`:1671-1674`), default severity P2. These files are loaded at write time by `edm-srd-writer`, `edm-ticket-writer`, and `edm-implementer` as quality guidance (`agents/edm-srd-writer.md:23-28`). So uncurated placeholder text accumulates in the highest-leverage prompt inputs in the system, appended *after* the fourth section in violation of the library's own four-heading contract (`docs/audit-patterns/README.md:5-20`). The idea (a living pattern library seeded from 600 real findings) is one of the best in the plugin; the append mechanism is a prompt-rot vector. Nothing prompts a human review of appended entries.

**Severity: friction and debt, compounding. Effort: S. Confidence: high.**

### F10. The plugin never measures whether any of it works

There is no evaluation anywhere: no fixture initiative, no golden artifacts, no A/B of prompt changes, no measurement that the 11-lens audit finds more than a 3-lens audit, that the pattern library reduces findings, or that the SRD length floors ("800+ lines major," `agents/edm-srd-writer.md:37`) produce substance rather than padding. The README's timing table is asserted; `/edm:metrics --calibrate` exists but has one initiative of (incomplete, F6) data. The bin/tests smoke suites are genuinely good *for the bash layer* (76/76 passed when I ran them) -- but they test that text exists in prompts (`wave4b`), not that prompts produce outcomes. Contrast with the two repos the author is currently mining for ideas: caveman ships a three-arm eval harness and reports *measured* token savings; ponytail ships benchmark arms. The methodology plugin -- whose entire pitch is rigor -- is the least-measured artifact in its own ecosystem. And there is no CI: the smoke suites run only when someone remembers (`CLAUDE.md` "Testing changes" is a manual checklist).

**Severity: friction and debt (strategic). Effort: M. Confidence: high.**

### F11. Distribution hygiene

676KB `EDM_Plugin_Presentation.pptx`, 32KB `EDM_Plugin_User_Guide.docx`, and `.DS_Store` ship inside the plugin directory to every installer. The root `CLAUDE.md` triggers the validator warning that it isn't loaded as runtime context (`claude plugin validate`: confirmed) -- fine as contributor docs, but several of its sections (severity vocabulary, Mermaid rules once added) are *referenced by name from agent prompts at runtime*, so the single most-cited canonical document in the system is one the runtime never guarantees is present. **[inferred: whether installed-plugin agents can actually resolve `CLAUDE.md Sec."Severity vocabulary"` references depends on install layout; confirmable by checking an installed cache copy -- note the cache at `~/.claude/plugins/cache/stg-marketplace/edm/2.0.0/` does include CLAUDE.md, so file presence holds today; whether agents reliably *read* it is unverified.]**

**Severity: polish. Effort: S. Confidence: high on facts.**

### What's genuinely good -- do not refactor these away

- **State-derived path resolution.** `state_file_for` / `resolve-dir` (`bin/edm-state:131-186`) is a single source of layout truth handling flat + product-scoped trees with sane precedence. Every skill correctly routes through it. This is the backbone that makes everything else fixable.
- **The locking and atomicity discipline.** Advisory flock with a portable mkdir fallback, RMW-under-lock as the only write path, atomic temp-file renames, `.bak` snapshots (`bin/edm-state:291-396`). Better bash than most production bash.
- **Artifact-hash drift detection.** Recording SRD/ticket hashes at phase-complete and warning at checkpoint time when a gate-approved artifact changed out-of-band (`bin/edm-state:691-751`) is a genuinely clever, cheap integrity mechanism. It's the *right instinct* -- mechanical verification -- applied to one slice; F1's fix is mostly "do this everywhere."
- **QC verdict semantics.** The PASS/PARTIAL/FAIL definitions with "never invent a PASS for something you cannot verify statically" (`agents/edm-qc-auditor.md:26-48`) is excellent prompt engineering -- it names the exact failure mode (hallucinated verification) and gives the model a legal out. The PARTIAL *lifecycle* is broken (F7); the semantics should survive untouched.
- **The gate approval rules text** (`skills/orchestrator/SKILL.md:396-400`). "Free-text is never approval; never infer intent from sentiment" is sharp, model-aware design. It needs to exist in one place instead of one-of-two places (F4), and be backed by mechanism (R1), but the text itself is right.
- **Cross-round findings ledger with stable CA-NNN IDs** and the demote-don't-delete False Alarm Filter ("Noted / Not Actionable" with rationale). Right ideas; they need a data representation (R3).
- **The lint infrastructure.** Fence-aware ignore sets, explicit ignore markers, staged-prefix derivation in the pre-commit hook (`bin/edm-lint-artifacts`, `hooks/hooks.json:86`) -- deterministic checks where determinism is possible. More of the plugin should work this way.
- **HANDOFF.md auto-refresh + SessionStart resume points.** Real cross-session/cross-user continuity most agent workflows lack.
- **A culture of writing down audits of itself** -- the 2026-06-10 external audit document is exactly the kind of artifact most teams never produce. The problem is what happens after (instance-fixes, F3), not the practice.

---

## Step 3 -- What it should become

The through-line for every recommendation: **EDM's differentiator is enforced rigor. Today the rigor is requested, not enforced. Move every invariant that can be checked deterministically out of prose and into `edm-state` + hooks, and spend the freed prompt budget on the judgment work only models can do.**

### R1. Make `edm-state` the enforcement kernel (the one change that changes the product)

Four concrete mechanisms, all in existing files:

**(a) Human gates enforced by the permission system, not prose.** Claude Code already has the mechanism: a permission rule that forces an interactive ask on exactly the gate-mutation command. Ship this in the plugin's recommended settings (and document it as required):

```json
// .claude/settings.json (project) -- shipped as documented setup, or via plugin install guidance
{
  "permissions": {
    "ask": ["Bash(edm-state approve-gate*)", "Bash(edm-state archive*)"]
  }
}
```

Now *every* gate approval and archive physically stops at a human click -- regardless of which skill, which session, which compaction state, or how persuasive the transcript was. The "free-text is never approval" prose becomes defense-in-depth instead of the only line. This composes with (not replaces) EDMV3's planned `approve-gate code-audit` gate.

**(b) `phase-complete` verifies the phase produced its artifact.** Today `cmd_phase_complete` records timing for whatever you claim. Add:

```bash
# in cmd_phase_complete, before the RMW:
local _dir; _dir="$(initiative_dir_for "$prefix")"
case "$phase" in
  1) [[ -s "${_dir}/planning.md" ]] || die "phase-complete 1 refused: ${_dir}/planning.md missing or empty" ;;
  2) [[ -s "${_dir}/${SRD_FILENAME}" ]] || die "phase-complete 2 refused: SRD missing" ;;
  3) [[ -s "${_dir}/audit-srd.md" ]] || die "phase-complete 3 refused: audit report missing" ;;
  4) [[ -s "${_dir}/${TICKET_PACK_DIRNAME}/README.md" ]] || die "phase-complete 4 refused: ticket pack missing" ;;
  5) [[ -s "${_dir}/${TICKET_PACK_DIRNAME}/audit.md" ]] || die "phase-complete 5 refused: ticket audit missing" ;;
  6) [[ -s "${_dir}/qc/qc-summary.md" ]] || die "phase-complete 6 refused: qc/qc-summary.md missing" ;;
esac
```

Ten lines. It converts "the model said the phase happened" into "the phase's deliverable exists." (Pair with a `--force` escape hatch for legitimate exceptions, logged into state.)

**(c) `archive` checks the actual lifecycle.** Gates 1-3 present in `gates_approved`, `current_phase == 6`, zero open PARTIALs or an explicit waiver -- in addition to convergence. The current check (`bin/edm-state:868-891`) validates one boolean; my three-command bypass should be impossible.

**(d) `cmd_set` gets an allowlist.** Today any key writes (`bin/edm-state:491-494` generic branch) -- I planted `totally_made_up_key` into state with no complaint. Enumerate legal keys; reject the rest with the list of valid ones. Gate-ish fields (`code_audit_converged`, `compliance_gate_approved`, `gates_approved`) refuse `set` entirely and name the `approve-gate` command (EDMV3 already plans this for one field; do all three).

**Why this serves the purpose**: it converts the plugin's central promise from a request into a property. **Cost**: ~1 day of bash + smoke tests; one extra human click per gate (that click *is the product*); `--force` paths needed for legacy initiatives. **Why not the alternative** (more/better prose, more `wave4b`-style text-presence tests): three documented recurrences prove prose doesn't hold, and text-presence tests verify the promise exists, not that it's kept.

### R2. Fix the four mechanical defects immediately (they're cheap and they're the front door)

1. `bin/edm-init` -- after the branch block succeeds (`:168`), correct the snapshot: `edm-state set "$PREFIX" initiative_branch "$BRANCH"` (post-checkout correction is safer than reordering because the warn-and-continue failure paths at `:161-166` leave the user on the old branch, which the correction then records truthfully). Add the regression test: run `edm-init` from a branch where the target branch doesn't exist; assert `initiative_branch` matches `HEAD`.
2. `agents/edm-qc-auditor.md` -- grant what its job requires: `tools: ... Read, Write, Bash(edm-state *), Bash(mkdir *), Bash(jq *)...`, `disallowedTools: Edit, NotebookEdit`. Same pattern already applied to `edm-test-coverage-auditor` in EDMV2.
3. `agents/edm-explorer.md` -- add `Write` (EDMV3 Gate-1 decision already made).
4. `README.md:11,14` -- `./plugins/edm-ai-development` -> `./plugins/edm`.

Then fix the *class*, once: a smoke check that greps every `agents/*.md` for write-instructions ("Write your report/findings to") and asserts `Write` is granted -- and **delete** the per-initiative manual regression ritual at `skills/implement/SKILL.md:162-172`, which becomes a test instead of a ceremony. That's the correct general form of what EDMV2-T01 should have been.

### R3. Give findings a data representation; compute convergence instead of asserting it

Every lens writes, *alongside* its prose report, one JSON line per finding:

```jsonl
{"id":null,"lens":"L1","sev":"P1","confidence":"high","file":"src/auth/handler.py","line":42,"title":"stub returns hardcoded data","status":"open"}
```

The synthesizer's merge/dedup/ledger work stays LLM (it's genuine judgment), but it emits `findings-ledger.jsonl` with stable CA-NNN IDs as the authoritative record, and the markdown ledger is rendered *from* it. Then:

- **Convergence is a query, not an opinion**: `edm-state audit-converged <PREFIX>` = `jq -e '[.[] | select(.status=="open" and (.sev=="P0" or .sev=="P1"))] | length == 0'`. The EDMV2 ledger-vs-state contradiction (F5) becomes structurally impossible, and the new EDMV3 no-deferral policy is one character change (`P2` joins the blocking set) *enforced in code* rather than restated in five prompt files.
- The `confidence` field fixes the blind corroboration filter (F5): lenses report everything and say how sure they are; the synthesizer ranks instead of discarding.
- `update-patterns`, metrics, and HANDOFF all get real data to consume.

**Cost**: touch 11 lens prompts + synthesizer + one new edm-state subcommand (~2 days); prose reports unchanged for humans. **Why not the alternative** (keep markdown, parse with grep): finding tables in free markdown drift in shape; you'd be writing a fragile parser for output you control -- just control it at the source.

### R4. One source of truth per phase; the orchestrator becomes a dispatcher

Current: every phase's full procedure exists in the orchestrator *and* its phase skill, hand-synced, already divergent at the gates (F4). Target shape:

```
Before                                    After
skills/orchestrator/SKILL.md  645 ln  ->  ~200 ln: intake (1a-1d), mode dispatch,
  (contains all 6 phases inline)          gate PROTOCOL (once), resume logic,
skills/plan/SKILL.md          132 ln       and per-phase: "invoke /edm:plan, then Gate 1"
  (contains phase 1 again, drifted)   ->  phase skills own their phase entirely,
skills/srd/SKILL.md ...                      each ending "present gate per orchestrator protocol"
```

The gate protocol (AskUserQuestion, exact options, free-text rule, `approve-gate` command) is written **once** in the orchestrator and *referenced* by phase skills -- which is safe now because R1(a) means a drifted phase skill can no longer silently record an approval anyway. If `CLAUDE.md:22-23`'s "skills don't load skills" constraint is genuinely hard (worth re-testing against current Claude Code -- skills invoking skills via the Skill tool is now supported and this marketplace's own git plugin does it), the fallback is a `bin/edm-check-skill-sync` script asserting the duplicated blocks are identical, run in the smoke suite. Deduplication beats sync-checking; sync-checking beats today.

**Cost**: the biggest prompt-refactor in the plan (~2-3 days), regression risk on a mature prompt set -- mitigate with R7's fixture eval before/after. **Payoff**: every future prompt improvement lands once; the F4 class dies; ~400 lines fall out of the most-loaded context in the system.

### R5. Make the economics honest, then let them steer

1. Record what's actually spent: `skills/implement` and `skills/code-audit` must call `phase-start 6` / `phase-complete 6` and per-round markers (EDMV2 shows they effectively don't -- F6). Add `audit-round-complete` capturing tokens per code-audit round.
2. Scope token attribution to the driving session (the current session's JSONL, not the whole project dir), or label the number "project activity during phase" honestly.
3. Tier the lenses. The lens mandates split cleanly: mechanical scans (L2 dead-code, L5 runtime-hygiene, L10 DRY-grep, L7 consistency-grep) run fine on `sonnet`/`high`; judgment lenses (L1, L3, L8, L9, L11) keep `opus`. Add a documented smoke-audit path: `/edm:code-audit PREFIX --lenses L1,L9,L11` for small initiatives, full 11 for release candidates. The `--lenses` machinery already exists; this is policy text plus frontmatter edits.
4. Drop the human-baseline ROI table or move it to the pptx where it belongs. A tool that mis-measures its own cost while computing "47x cheaper than humans" invites exactly the scrutiny it can't survive. **Why not "just fix the baseline"**: the baseline is unknowable per-initiative; the *Claude cost* is knowable and actionable -- spend the effort there.

### R6. Close the PARTIAL loop

Minimum viable: `edm-state archive` warns (or blocks without `--accept-partials "<rationale>"`) when `partial_verdict_map` has entries with no matching closure. Real fix: a `/edm:verify-runtime <PREFIX>` command -- reads `partial_verdict_map`, drives the deferred-to-runtime checks (each PARTIAL already carries a machine-suggested verification note, which is why the QC prompt design is good), records PASS/FAIL, writes `post-deploy/verification.md`. The QC semantics already generate the runtime test plan as a side effect; today it's thrown away.

### R7. Measure the methodology (and put the bash under CI)

- **Fixture initiative**: a small synthetic repo + a frozen initiative description checked into `plugins/edm/evals/`. An eval run executes plan->srd->audit against it headlessly (`claude -p`), then scores artifacts mechanically: requirement-ID coverage, AC testability (regex for vague-AC patterns from the pattern library), Mermaid parse success, coverage-map bidirectionality. Prompt changes get a before/after number instead of vibes. This is precisely the caveman/ponytail `evals/` pattern the author is already mining -- apply it to the flagship.
- **CI**: this is a GitLab-homed repo; a 20-line `.gitlab-ci.yml` running `bash -n` over bin/, the four smoke suites, `claude plugin validate`, and the R2 class-check turns "206 checks that pass when someone remembers" into a gate. The plugin that mandates test coverage for its users currently has no CI for itself.

### R8. Delete list

- `EDM_Plugin_Presentation.pptx`, `EDM_Plugin_User_Guide.docx` -> repo `docs/` outside the plugin source dir; `.DS_Store` -> delete + `.gitignore`.
- `skills/implement/SKILL.md:162-172` (the baked-in one-agent regression ritual) -> becomes a smoke test (R2).
- The human-baseline ROI computation from `metrics` default output (R5.4) -- keep raw cost/duration.
- `TaskCompleted` hook + `cmd_record_task_duration` no-op -- delete until real; a wired no-op is documentation debt.
- Reconsider `monitors/watch-impl`'s infinite `sleep 5` git-log poll -- if kept, document its lifecycle; today it's an unkillable-looking loop with no owner. **[inferred: actual monitor lifecycle management is host-side; confirm before deleting.]**

### The bigger swings

**Shape**: EDM's purpose is right and rare -- most "AI SDLC" tooling is either a single mega-prompt or a rigid external workflow engine; EDM's insight is that the *artifacts and state* should live in git while the *judgment* lives in agents. The shape that fully serves that insight is **phases as data**: a `phases.json` (inputs, outputs, gate, agents, artifact checks per phase) that `edm-state` enforces and a slim orchestrator interprets. Modes (mini-srd, prototype, fast-track) become phase-graph variants instead of prose sub-flows; the four-way duplication of the phase list (orchestrator, phase skills, CLAUDE.md tree, README) collapses to one. Migration: R1(b)'s artifact checks are the first column of that table; R4's dispatcher is its interpreter. Do it only after R1-R4 prove out -- it's the natural v3, not a prerequisite.

**Not worth doing**: maintaining two gate protocols, hand-maintained duplicated orchestration, ROI theater, per-instance regression rituals. All named above.

**Missing capability the intent implies**: a **feedback loop that closes**. EDM already half-built it -- `update-patterns` harvests findings into writer guidance. What's missing is the other half: *curation* (appended stubs need a human-review step -- make `update-patterns` open a review block in the audit gate instead of silently appending) and *measurement* (R7 tells you whether the loop improves anything). A methodology that provably gets better with each initiative -- with numbers -- is the great version of this idea. That, plus enforcement-as-mechanism, is the whole distance between "adequate" and "great": today EDM *documents* rigor; the great version *guarantees* what it can and *measures* what it can't.

### Sequencing

1. **R2** (mechanical fixes) -- hours of work; unblocks every future initiative's first run and the QC layer; EDMV3 already covers most of it. Nothing else is credible while the front door is broken.
2. **R1** (enforcement kernel) -- the trust foundation. Do it before touching prompts at scale, because it makes prompt drift survivable and it's what EDMV3's requirements are really asking for (both user asks are instances of R1).
3. **R7-CI + fixture eval** -- *before* the big prompt refactor, so R4 has a regression harness to land against.
4. **R3** (structured findings) -- enables the no-deferral policy mechanically, fixes convergence integrity, and feeds R5's metrics.
5. **R4** (dedup/dispatcher) -- the largest prompt change, now protected by 2 and 3.
6. **R5, R6, R8** -- economics, PARTIAL loop, deletions; independent, batch opportunistically.
7. **Phases-as-data** -- only after the above holds through one real initiative.

---

## Open Questions

1. **Who uses this besides the author?** Git history shows a single-committer plugin. If the answer is "nobody yet," R2/R7 (first-run + credibility) matter more than any feature; if teams are adopting, R1 is urgent. Answered by: install telemetry, or just asking.
2. **Does GitLab's Mermaid renderer honor `#59;` entity codes?** EDMV3's Mermaid fix is verified against mermaid.js docs, not against the org's actual renderers (GitLab MR view, VS Code). One fixture diagram in a test MR answers it.
3. **Where did EDMV2's Phase 6 costs actually go?** `phase_durations["6_phase"]` is empty while `audit_rounds.code=2`. Was Phase 6 run in sessions whose JSONL predates the tracking, or were `phase-start/complete 6` simply never called? Answered by: grepping the archived HANDOFF/qc timestamps against session logs. Determines whether R5.1 is "wire calls" or "fix attribution."
4. **Is the "skills don't load other skills" constraint (`CLAUDE.md:22-23`) still true of current Claude Code?** This marketplace's own git plugin invokes `create-jira-card` via the Skill tool. If skills can now compose, R4's dispatcher design simplifies substantially. Answered by: a 10-minute spike.
5. **Is Windows/WSL a target?** Everything is bash 3.2 + jq. Fine if macOS/Linux-only is a stated constraint; a silent adoption ceiling if not.
6. **What is `lifecycle_mode=partial`?** It's a legal enum value (`bin/edm-state:1447`) with no documented sub-flow anywhere. Dead value or unshipped feature?
