# EDMV4 -- ECC Integration: Software Requirements Document

## 1. Document Information

| Field | Value |
|---|---|
| Initiative | EDMV4 -- ECC Integration |
| Prefix | `EDMV4` |
| Product | `edm` |
| Version | 1.2.0 |
| Status | Draft |
| Owner | darryl.porter |
| Mode | `standard` (`lifecycle_mode: standard`, `compliance_enabled: false`) |
| Estimated Size | Large (50-85 tickets) |
| Branch | `edm/edmv4-ecc-integration` |
| Last Updated | 2026-09-02 |

### Revision History

| Version | Date | Author | Summary |
|---|---|---|---|
| 1.0.0 | 2026-08-30 | `edm-srd-writer` | Initial SRD from the Gate-1-approved `planning.md` and `decisions.md` D1-D13. Fifty-eight requirements across eleven scope items plus two blocking spikes. |
| 1.1.0 | 2026-08-31 | `edm-srd-writer` | Remediation against `audit-srd.md` (5 P0, 44 P1). **AD5 round-type design**: `audit-round-start` now materializes `lenses = ALL_LENS_IDS` when `--lenses` is omitted, so the union derivation is correct in both branches and the CA-471 backstop stays meaningful (`EDMV4-24`, `EDMV4-25`). **`EDMV4-T04`**: `EDMV4-51` raised to Must Have and the `EDMV4-49` dependency inverted so orphan enumeration completes before anything is anchored; `EDMV4-50` restated against the verified 8-site / 6-section orphan table. **D4**: `EDMV4-03` and Sec.4.6 C9 rewritten against D4 as amended -- the revert hazard is gone, the residual is a `plugin.json` version reconciliation and is non-blocking. **Dependency cycles**: `EDMV4-14`/`15`/`16` folded into `EDMV4-14` (15 and 16 retained as merged pointers); `EDMV4-07` <-> `EDMV4-09` inverted. **Gate 2 accuracy**: `EDMV4-05`'s saving corrected to 150-250 lines of bash plus the un-ported tokenizer, and the false "`git commit` bounds the residual exposure" claim replaced with the enumerated unguarded classes. **New `EDMV4-59`** ratifies AD1 itself, which is the decision the licence posture actually depends on. Sec.4.6, Sec.4.4, Sec.4.5 and Sec.3.4 cross-references re-derived. Lens-count sweep extended with every missed name-list, non-`-eq 11` count and prose site -- notably `wave7-smoke.sh:5386`, which counts a hardcoded list and so stays green while silently dropping the three new lenses from the D16 opus/max assertion. Sec.10 R5 figures corrected to 90 tokens across 16 files and 10 exact-integer sites. Linux recorded as untested rather than claimed. **Requirement count: 59 IDs (`EDMV4-01` .. `EDMV4-59`), 57 substantive (41 Must / 15 Should / 1 Could) plus 2 merged.** |
| 1.2.0 | 2026-09-02 | orchestrator | **Scope addition discovered at this initiative's own Phase 5 preflight, raised for Gate 3 ratification.** New `EDMV4-60`: `cmd_gate_check` mapped `audit-tickets` to Gate 3 -- the gate that phase **presents** -- making Phase 5 unreachable for every standard-lifecycle initiative through both enforcement layers (Step 0 preflight and the `edm:audit-tickets` `UserPromptExpansion` hook). `bin/tests/wave6-smoke.sh`'s EDMV3-T13 AC3 loop asserted only that *a* gate was named, never the right one, so the suite stayed green; the loop is now pinned per token and a direct producer/consumer assertion added. Also records the branch reconciliation: the tree described by Sec.4.6 C9 and `decisions.md` D4 as "3 commits behind `origin/main`" was in fact 25 behind and missing `plugins/edm/docs/ecc-integration-analysis.md` entirely -- the document `EDMV4-54` exists to correct. Branch fast-forwarded to `origin/main` (plugin 3.2.2); `file:line` citations throughout Sec.6 shifted again and are advisory, with each ticket carrying its own verified anchors. **Requirement count: 60 IDs (`EDMV4-01` .. `EDMV4-60`), 58 substantive (42 Must / 15 Should / 1 Could) plus 2 merged.** |

### Source documents

| Document | Role in this SRD |
|---|---|
| `SRD/edm/EDMV4__ecc-integration/planning.md` | Gate-1-approved scope. Its "What Phase 1 Changed About the Scope" section supersedes the source analysis wherever they disagree. |
| `SRD/edm/EDMV4__ecc-integration/decisions.md` | D1-D4 (intake), D5-D12 (Gate 1) and D13 (the GateGuard licence verification). D5-D13 are binding constraints on this SRD, not suggestions. **D4 was amended on 2026-08-31, mid-Phase-2**; this SRD is written against the amended text, not the intake text. |
| `SRD/edm/EDMV4__ecc-integration/explorers/01-bin-shell-tooling.md` | Verified `file:line` evidence for `bin/`, `bin/tests/`, `evals/`. |
| `SRD/edm/EDMV4__ecc-integration/explorers/02-hooks-runtime.md` | Verified `file:line` evidence for `hooks/hooks.json` and the runtime enforcement surface. |
| `SRD/edm/EDMV4__ecc-integration/explorers/03-skills-agents-prompt-surface.md` | Verified `file:line` evidence for `skills/`, `agents/`, `docs/canonical-sections.md`. |
| `SRD/edm/EDMV4__ecc-integration/explorers/04-ecc-source-assessment.md` | Verified `file:line` evidence for the ECC checkout at `/Users/darryl.porter/projects/ECC`. |
| `SRD/edm/EDMV4__ecc-integration/architecture.md` | Target-architecture diagrams and architecture decisions. Section 5 below references it rather than duplicating it. |
| `plugins/edm/docs/ecc-integration-analysis.md` | The source analysis. Structural claims verified; Value ratings are the author's ranking of a structural argument, never measured outcomes (its own Part 8.3.1 says so). |
| `plugins/edm/CLAUDE.md` | The plugin's own conventions -- severity vocabulary, the six do-NOT-adopt guards D1-D6, model/effort assignments, the state-field table, the mode matrix, the `bin/` helper table. |

**Target Components in this document are drawn from the four explorer reports, not from the source
analysis**, whose line citations are stale in at least one confirmed case (correction 8 in Sec.4.4
below). Every `file:line` here was re-verified against the working tree on 2026-08-30 unless the
requirement itself marks it otherwise.

---

## 2. Executive Summary

EDMV4 adopts eleven items from `plugins/edm/docs/ecc-integration-analysis.md` into the EDM plugin:
Part 4 in full (4.1 GateGuard, 4.2 the `update-patterns` read-only defect, 4.3 an orchestrator size
classifier, 4.4 three new audit lenses L12/L13/L14), Part 5 items 5.2 through 5.5 (repo-readiness
scorecard, hookify rules-as-data layer, Stop-hook completion gate, codemaps interim), and the three
orphaned ticket IDs `EDMV4-T01`, `EDMV4-T04` and `EDMV4-T05` inherited from the named-but-never-created
`EDMV4__lint-and-pipeline-budgets` initiative (decisions.md D1).

Phase 1 verified every structural claim in the source analysis against source. **The analysis is
substantially accurate but wrong in eleven specific places**, and two of its three inherited tickets
are largely already done. The scope in this SRD is the corrected one.

Three things dominate the shape of the work:

1. **Two Claude Code host behaviours this initiative depends on are unverified**, and no amount of
   further planning resolves them. Whether an exit-code-only `PreToolUse` hook can deny a native
   `Edit`/`Write`/`MultiEdit` (Spike B), and how Claude Code combines two blocking hooks that match
   one tool call (Spike A), each need a mechanical experiment against the live host. They follow the
   existing D21/D22/D24 precedent of spiking a host behaviour rather than assuming it. Spike A blocks
   4.1 and 5.3; Spike B blocks 4.1. These are the **only two** blocking preconditions. The third one
   Phase 1 carried -- the `zunoworks/gateguard` upstream licence -- is resolved (MIT, decisions.md
   D13), and Phase 2 architecture decision AD1 removed it from the critical path entirely by choosing
   a bash rewrite over a vendoring.
2. **4.4 has the widest blast radius of anything here.** Explorer 03's Sec.1.1 table names 37 touch
   points for a change the source analysis describes as "updating the hardcoded lens count". The
   largest is `bin/tests/wave7-smoke.sh`, which carries lens-count assertions across seven regression
   classes -- two of which (T47 AC6 at `:4902`, T48 AC6 at `:5417-5420`) were written specifically to
   assert the lens count never changes, and must be deliberately revised rather than incremented.
   `bin/tests/wave6-smoke.sh:3445-3449` will silently invert: its explicit `--lenses
   L1,...,L11` full-round assertion becomes an 11-of-14 *partial* round the moment `ALL_LENS_IDS`
   grows, so the test's own claim reverses without the test being touched.
3. **Most of the rest is mechanically small and unblocked.** 4.2, 4.3 and `EDMV4-T04` are unambiguous
   wins that can start immediately -- D4's revert hazard was closed during Phase 2 by applying
   commit `bdec805` directly to this branch, so nothing waits on a rebase. `EDMV4-T05` closes as verification plus a
   recorded scope boundary -- both bugs it names are already fixed and verified in source, and the
   only remaining step is a live API capture that is a human credential decision, not code.

The initiative is Large, sitting at the low end (roughly 50-57 tickets). Out of scope by explicit
Gate 1 decision: 5.1 (the bounded implementer/QC remediation loop), which becomes its own named
follow-on initiative.

---

## 3. Purpose and Scope

### 3.1 Purpose

Close eleven verified structural gaps in the EDM plugin, using ECC as a source of already-solved
patterns where one exists and building from scratch where the analysis's premise turned out not to
hold. Every item in scope has a gap verified against EDM's own source, not merely asserted from the
analysis.

### 3.2 In Scope

| Item | Short name | Requirements |
|---|---|---|
| Preconditions and change control | Spikes A and B, D4 branch reconciliation, inherited ticket-ID constraint, three architecture/scope ratifications | `EDMV4-01` .. `EDMV4-06`, `EDMV4-59` |
| 4.1 | GateGuard fact-forcing edit gate | `EDMV4-07` .. `EDMV4-12` |
| 4.2 | `update-patterns` read-only-install defect | `EDMV4-13` .. `EDMV4-18` |
| 4.3 | Orchestrator size classifier | `EDMV4-19` .. `EDMV4-22` |
| 4.4 | Audit lenses L12 / L13 / L14 | `EDMV4-23` .. `EDMV4-35` |
| 5.2 | Repo-readiness scorecard | `EDMV4-36` .. `EDMV4-39` |
| 5.3 | Hookify rules-as-data layer | `EDMV4-40` .. `EDMV4-43` |
| 5.4 | Stop-hook completion gate | `EDMV4-44` .. `EDMV4-45` |
| 5.5 | Codemaps (interim only) | `EDMV4-46` |
| `EDMV4-T01` | Mermaid lint budget re-framing | `EDMV4-47` .. `EDMV4-48` |
| `EDMV4-T04` | By-name reference anchoring | `EDMV4-49` .. `EDMV4-51` |
| `EDMV4-T05` | Eval-baseline verification plus boundary record | `EDMV4-52` .. `EDMV4-53` |
| D12 | Source-document self-correction | `EDMV4-54` |
| Cross-cutting | Platform, dependencies, ASCII, enforcement surface | `EDMV4-55` .. `EDMV4-58` |

### 3.3 Out of Scope -- explicitly

Each of these is out of scope by a recorded decision, not by omission. A ticket writer must not
re-introduce any of them.

| Excluded | Why | Where recorded |
|---|---|---|
| **5.1 -- bounded implementer/QC remediation loop** | Large by itself; its cost-ceiling precondition is design work distinct from every other item, and gating the other eleven behind that design phase is the wrong trade. Carried as a **named follow-on initiative**, not an unnamed candidate, per the D13/D14 precedent. ECC's `gan-harness.sh` offers no cost model to copy -- it has no dollar ceiling at all, only an iteration cap (default 15) plus plateau detection (`gan-harness.sh:175-259`). | Gate 1 / D5; `planning.md` Sec."Scope Statement" |
| **5.6 -- modular install** | Conditional on the Part 7 kernel/methodology split; the analysis itself states it is not actionable on its own. | D2 |
| **All of Part 6** | The analysis's own reject list. | D2 |
| **Part 7 -- kernel/methodology split** | The analysis itself places it behind everything in Parts 4 and 5 regardless. | D2 |
| **The D3 `disable-model-invocation` defect** | Real defect, but **already fixed** -- commit `bdec805` is now the tip of this branch, applied directly rather than by rebase, with a regression guard in `bin/edm-check-skill-sync`. Verified in the working tree: zero skill files carry the flag. Nothing remains to do here (`EDMV4-03` verifies only). | D3; D4 as amended |
| **Project scoping / promotion / prune machinery (4.2)** | ECC's `continuous-learning-v2` promotion rule (an instinct seen in 2+ distinct projects becomes promotable) solves a problem EDM does not have; EDM's audit patterns are curated content reviewed by a human, not confidence-scored observations. Do not build speculatively. | `ecc-integration-analysis.md:414-420` |
| **The destructive-`Bash` arm of GateGuard (4.1)** | AD1. 4.1 is an edit gate. The arm's 741 lines of helper closure are the only reason ECC's implementation is 2,042 lines rather than ~300. **This is a reduction against Gate-1-approved scope and requires Gate 2 ratification** -- see `EDMV4-05`. | `architecture.md` AD1; Rejected Alternatives |
| **The "phase started with no `completed_at`" anomaly (5.4)** | It does not exist in `state_anomalies` today, and a phase legitimately stays started for hours during a Phase 6 wave, so a naive presence check would block on ordinary long-running work. **Reduction against Gate-1-approved scope; requires Gate 2 ratification** -- see `EDMV4-06`. | `explorers/02` Sec.3.1; `architecture.md` Build Sequence step 19 |
| **A destructive-command detector of any kind** | Follows from the row above. If one is ever wanted, 5.3's rule files are the right vehicle, not a vendored tokenizer nobody in this plugin can maintain in bash. | `architecture.md` AD1 |
| **`GAN_EVAL_CRITERIA` as a real knob** | Documented in ECC's `SKILL.md:231` but never read by `scripts/gan-harness.sh`. Dead code. | Correction 4 (Sec.4.4) |
| **Playwright-driven live-app evaluation** | EDM has `/edm:verify-runtime` for runtime evidence and it is deliberately human-gated. | `ecc-integration-analysis.md:604-605` |
| **ECC's `~1KB` minified inline plugin-root resolver** | EDM's `bin/`-on-`PATH` approach avoids the entire problem class. ECC's own authors document the copy-paste divergence as an accepted trade-off. | `explorers/04` Sec."Additional Part 8 claims" |
| **A codemap generator** | 5.5 is the `SRD/.codemap.md` interim only. No generator is built. | Gate 1 / D11 |
| **A CI pipeline** | None exists in this repository (`b56558d` removed the GitLab CI pipeline). `bin/tests/run-all.sh` plus the git-commit hook are the entire enforcement surface. Any `EDMV4-T05` work item assuming a CI job needs re-wiring is dropped. | `explorers/01` Sec.1.5; `CLAUDE.md Sec."Testing changes"` |

### 3.4 Definition of Done

EDMV4 is complete when all of the following hold:

1. Every `Must Have` requirement in Sec.6 has all of its acceptance criteria satisfied and evidenced.
2. `bash plugins/edm/bin/tests/run-all.sh` passes with zero failures **on macOS**, run under
   `/bin/bash` (3.2.57), which is the bash-3.2 floor check `EDMV4-55` relies on. **Linux is
   recorded as untested** for this initiative: no CI pipeline exists and no container image is
   named anywhere in this repository, so a Linux claim would be unverifiable. Linux remains a
   supported platform by construction (`EDMV4-55`'s bash-3.2 floor, `EDMV4-56`'s BSD/GNU coreutil
   discipline); it is not a verified one. See `EDMV4-58`.
3. `bash plugins/edm/bin/edm-check-grants`, `bash plugins/edm/bin/edm-check-vocabulary`,
   `bash plugins/edm/bin/edm-check-skill-sync` and
   `bash plugins/edm/bin/edm-sync-canonical-sections --check` all exit 0.
4. `claude plugin validate plugins/edm/` exits 0.
5. `plugins/edm/bin/edm-lint-artifacts --path plugins/edm/` reports zero violations across
   `skills/`, `agents/` and `docs/` (the trees the automatic invocations do not reach --
   `EDMV4-57`).
6. The D4 residual is reconciled: `plugins/edm/.claude-plugin/plugin.json` no longer diverges from
   `origin/main`, the local unstaged `*opus-5*` arm in `compute_cost_usd` survives, and
   `bin/edm-check-skill-sync`'s `disable-model-invocation` guard is present and passing
   (`EDMV4-03`). Per D4 as amended this is a merge-time reconciliation, **not** a precondition on
   any other requirement.
7. Spikes A and B are executed and their outcomes recorded as numbered decisions in
   `decisions.md` (`EDMV4-01`, `EDMV4-02`), and all three architecture/scope ratifications are
   accepted or rejected at Gate 2 (`EDMV4-05`, `EDMV4-06`, `EDMV4-59`) -- **done**: all three were
   ratified 2026-09-02, `decisions.md` D14/D15/D16.
8. `plugins/edm/CHANGELOG.md` carries a new entry documenting the 11-to-14 lens change and every
   other user-visible change in this initiative. No historical CHANGELOG entry is edited.
9. `plugins/edm/docs/ecc-integration-analysis.md` carries the eleven corrections in its own Part 8.2
   self-correction style (`EDMV4-54`).
10. A code-audit round has converged (P0 = 0, P1 = 0) or its P2 debt has been explicitly accepted at
    the convergence gate per `CLAUDE.md Sec."Severity vocabulary"`.

---

## 4. Current State Assessment

### 4.1 What exists today, per verified source

| Surface | Current state | Evidence |
|---|---|---|
| `PreToolUse` hooks | **Exactly one matcher block**, scoped to `git commit`, delegating to `edm-lint-staged-artifacts` | `hooks/hooks.json:80-90` |
| `Stop` hooks | **Exactly one matcher block**, delegating to `edm-state checkpoint-if-active` | `hooks/hooks.json:91-100` |
| Total hook surface | **6 distinct event keys, 10 matcher blocks.** `CLAUDE.md`'s five-row table collapses `Stop` and `PreCompact` into one row | `hooks/hooks.json:2,13,80,91,101,111`; `explorers/02` Sec.1.1 |
| JSON deny shape | **Zero occurrences** of `permissionDecision` or `hookSpecificOutput` anywhere in this repository outside the analysis document itself. Every EDM hook that blocks does so via a bash exit code, and the only blocking precedent is a `Bash`-wrapped `git commit` | `explorers/02` Sec.1.3 |
| "Which initiative is active" at per-tool-call cadence | **Does not exist.** Nearest primitives are `cmd_active_initiatives` (`bin/edm-state:3900-3916`), `cmd_session_start` (`:4347` onward) and `cmd_checkpoint` (`:2735` onward, which additionally takes a write lock and computes SHA-256 per tracked artifact). All run at SessionStart/Stop/PreCompact cadence, never per tool call | `explorers/02` Sec.1.4 |
| `${CLAUDE_PLUGIN_DATA}` | **Zero occurrences in any executable script.** Two prose references only: `CLAUDE.md` (the reservation rule) and the analysis document | `explorers/01` Sec.1.1; `explorers/02` Sec.1.4 |
| `cmd_update_patterns` write target | `local patterns_dir="${SCRIPT_DIR}/../docs/audit-patterns"` -- inside the plugin's own installed tree | `bin/edm-state:5595` |
| `cmd_update_patterns` read-only branch | `[[ ! -w "$pattern_dir" ]]` warns to stderr and `return 0`s -- a permanent no-op on any read-only plugin-cache install | `bin/edm-state:5627-5630` |
| `update-patterns` call sites | **Six**, not four | `skills/implement/SKILL.md:46`, `skills/code-audit/SKILL.md:135`, `skills/audit-tickets/SKILL.md:52`, `skills/audit-srd/SKILL.md:50`, `skills/test/SKILL.md:132`, `skills/test-coverage/SKILL.md:65` |
| Pattern-file readers | Four agents, each `Read`ing one file directly and each resolving "the plugin root" itself with no shared mechanism | `agents/edm-srd-writer.md:25`, `agents/edm-ticket-writer.md:32`, `agents/edm-implementer.md:24-25`, `agents/edm-test-coverage-auditor.md:40-42` |
| Orchestrator mode selection | Step 1c presents `AskUserQuestion` for mode and compliance, then records via `edm-state set-mode`. No size classification exists anywhere | `skills/orchestrator/SKILL.md:103-114` |
| Mode enums | `MODE_ENUM_LIST="standard mini-srd iac data-ml prototype"` and `LIFECYCLE_MODE_ENUM_LIST="standard fast-track fix-pack"` -- **8 values total**, validated as a hard refusal in `cmd_set_mode` | `bin/edm-state:807-808`, validated at `:5063-5114` |
| Lens ID set | `ALL_LENS_IDS="L1 L2 L3 L4 L5 L6 L7 L8 L9 L10 L11"` with a `-eq 11` self-check whose error text also hardcodes `11` | `bin/edm-state:1613,1615` |
| `round_type` derivation | Compares the caller's `--lenses` set against `ALL_LENS_IDS`; `full` when equal or when `--lenses` is omitted, `partial` otherwise. **Has no concept of an auto-N/A'd lens** | `bin/edm-state:4555,4567-4571`; comment at `:4508-4510` |
| CA-471 completeness backstop | `audit-round-complete` downgrades a code round to `partial` when any lens named in `lenses-run.txt` lacks a non-empty, parseable `lens-L{N}.jsonl`. The downgrade is irreversible for that round | `CLAUDE.md Sec.".edm-state.json mode-family fields"`, `round_type` row |
| `validate` anomalies | 14 anomaly kinds. `OPEN_PARTIALS` (`bin/edm-state:1827-1847`), `TIME_ORDER` (`:1714-1729`), `ZERO_TOKENS` (`:1741-1752`) and `CONVERGED_NO_APPROVAL` (`:1815-1826`) are blocking; the rest are informational. `cmd_validate` exits 3 iff at least one line's first field is literally `blocking` | `bin/edm-state:4036-4059`, `:1709-1927` |
| Timing harness | `bin/tests/timing.sh` already has `--generate-fixture` (default N=50, `:217,239-253`), `--lint` (`:366-384`), `--mermaid-ratio` (`:386-428`) and `--all-lint` (`:430-451`), all wired to the post-`ea31ce8` one-awk-per-file class-4 scan | `explorers/01` Sec.1.4 |
| Eval driver | CA-532 fixed (`evals/run-eval.sh:420-421,460-461` -- real bash arrays, expanded `"${ARRAY[@]}"`); CA-490 fixed (`bin/edm-compare-eval:62-81` -- completeness check before baseline-existence check) | `explorers/01` Sec.1.5 |
| `evals/baseline/scores.json` | **Does not exist.** `edm-compare-eval` exits 3 ("NOT ARMED") -- a named, non-crashing outcome, not a silent pass | `bin/edm-compare-eval:77-81`; `evals/baseline/` contains only `README.md` |
| `docs/canonical-sections.md` | Generates **exactly two** sections: "Severity vocabulary" and "Mermaid diagram conventions" | `explorers/03` Sec.4.1 |
| Unanchored by-name references | **14 files** (5 agents + 9 skills) carry a bare `` CLAUDE.md Sec."..." `` reference with no `docs/canonical-sections.md` anchor. `CLAUDE.md`'s own list names only 8 | `explorers/03` Sec.4.1 |

### 4.2 Items that shrank after Phase 1 verification

| Item | Source analysis assumed | Verified reality |
|---|---|---|
| `EDMV4-T01` | A 50-initiative fixture generator must be written | It already exists and is already wired into `--all-lint`. The remaining work is a **budget framing** fix: `CHANGELOG.md:393` records AC6 as "PASS on the number, but the budget is still malformed", and `CHANGELOG.md:433-450` explains why -- a bare ratio with no stated input size and no absolute floor is dominated by fixed process overhead |
| `EDMV4-T05` | Fix CA-532 and CA-490, then capture the baseline | Both bugs are already fixed and verified in current source. CA-537's CI fix is moot -- no `.gitlab-ci.yml` exists. Only `evals/baseline/scores.json` is genuinely missing, and capturing it is a live-API-spend and credential decision, not code |
| 5.4 | Surface four `validate` anomalies at `Stop` instead of only at `archive` | `OPEN_PARTIALS` **already blocks at `validate`** (`bin/edm-state:1827-1847`). `OPEN_AUDIT_ROUND` and `SPEC_SWEEP_PENDING` are confirmed informational by design. The fourth, "phase started with no `completed_at`", **does not exist as an anomaly at all** -- `TIME_ORDER` only fires when both timestamps are present and inverted |
| D3 | A candidate scope addition | Already fixed. Commit `bdec805` is the tip of this branch, applied directly rather than by rebase (D4 as amended). Nothing to do beyond regression verification |

### 4.3 Items that grew after Phase 1 verification

| Item | Source analysis scope | Verified scope |
|---|---|---|
| 4.4 | `skills/code-audit/SKILL.md`, `bin/edm-state`, `CLAUDE.md`, the synthesizer | **37 distinct touch points** (`explorers/03` Sec.1.1), including `bin/tests/wave7-smoke.sh` and `bin/tests/wave6-smoke.sh`, which the analysis does not mention at all |
| `EDMV4-T04` | 8 files named in `CLAUDE.md` | **14 files** (5 agents + 9 skills). `CLAUDE.md`'s list misses `agents/edm-qc-auditor.md`, `skills/verify-runtime/`, `skills/push-jira/`, `skills/orchestrator/`, `skills/metrics/`, `skills/code-audit/SKILL.md`. And `agents/edm-qc-auditor.md:39` cites a section with **no `canonical-sections.md` mirror at all** -- a different fix shape from the other 13 |
| 5.3 | Adapt ECC's rule evaluator | **ECC has no evaluator.** Exhaustive search of `scripts/`, `hooks/hooks.json` and all six operator names found the condition-matching engine exists only as documentation. EDM builds the evaluator from nothing; only the file *format concept* transfers |
| 4.2 | Four skills call `update-patterns` | **Six** call sites. The in-code comment at `bin/edm-state:5672` repeats the wrong number |

### 4.4 The eleven corrections to the source analysis

These are authoritative over `plugins/edm/docs/ecc-integration-analysis.md` wherever they conflict.
`EDMV4-54` writes them back into that document.

| # | Correction | Evidence |
|---|---|---|
| 1 | ECC's hook count is **23 registrations across 7 event types**, not 25 across 8. The analysis's own per-row table is individually correct; only its summary total and event-type count are wrong | `explorers/04` Sec."Additional Part 8 claims" |
| 2 | The seven security triggers are **not** in `rules/common/security.md` (that file holds an unrelated 8-item pre-commit checklist). They live at `orch-pipeline/SKILL.md:100-104`, which itself miscites `security.md`. Cite `orch-pipeline/SKILL.md` | `explorers/04` Sec.3 |
| 3 | Hookify has **no evaluator** in ECC | `explorers/04` Sec.7 |
| 4 | `GAN_EVAL_CRITERIA` is documented but **dead code** -- `scripts/gan-harness.sh` never reads it | `explorers/04` Sec.5 |
| 5 | `delivery-gate`'s `SKILL.md` undocuments a **third disk tier** -- the code has a 30GB warning between the documented 50GB and 15GB tiers | `explorers/04` Sec.8 |
| 6 | `silent-failure-hunter`'s body is **44 lines, not "~30"** (47% higher). The other two are 35 and 39 | `explorers/04` Sec.4 |
| 7 | `harness-audit.js` consumer mode is **16 checks / 39 points**, not 11 / 29, once the unconditionally-appended GitHub checks are counted | `explorers/04` Sec.6 |
| 8 | The `update-patterns` line cites are **stale** -- `bin/edm-state:5595` and `:5627-5629`, not `:5577` and `:5624` | `explorers/01` Sec.1.1 |
| 9 | The GateGuard env-var table **omits `GATEGUARD_DISABLED=1`**, a second independent kill switch alongside `ECC_GATEGUARD=off`. It recognizes only the literal `'1'`, not the word-forms `ECC_GATEGUARD` accepts | `gateguard-fact-force.js:732-734` |
| 10 | `MultiEdit` needs **one retry per still-unchecked file**, not one retry total | `gateguard-fact-force.js:1234-1256` |
| 11 | Codemaps placeholder lines are `generate.ts:225-231`, not `:200-240`. Substance confirmed | `explorers/04` Sec.9 |

### 4.5 The three inherited ticket IDs -- a hard constraint on Phase 4

`EDMV4-T01`, `EDMV4-T04` and `EDMV4-T05` are **pre-claimed with fixed meanings** from EDMV3's
`decisions.md` (D29, D34, D62) and are cited by ID in `plugins/edm/CLAUDE.md:352` and in EDMV3's own
archived ticket coverage map. `EDMV4-T02` and `EDMV4-T03` were **closed inside EDMV3** and must never
be reused.

Phase 4's ticket pack therefore **cannot assign `EDMV4-T01` through `EDMV4-T05` freely**. See
`EDMV4-04` for the enforceable form of this constraint.

### 4.6 Constraints

**Cross-reference discipline.** Every Consequence cell below names the requirement whose **title**
governs the constraint, re-derived mechanically from Sec.6 rather than carried forward. A ticket
writer uses this table as a traceability map, so an off-by-one here wires a constraint to the wrong
ticket -- which is exactly what happened in v1.0.0 and is corrected here.

| # | Constraint | Consequence |
|---|---|---|
| C1 | **bash 3.2+ floor; macOS and Linux only.** No associative arrays, no `${var^^}`, no `mapfile`. Live comments in `edm-lint-artifacts` and `timing.sh` record bash-3.2 gotchas including the process-substitution fd-leak class fixed under CA-472 | `EDMV4-55` ("Every new and modified `bin/` script holds the bash 3.2 floor") owns this, and extends the **already-shipped tree-wide ban** at `wave7-smoke.sh:1082-1100` rather than writing weaker per-file criteria |
| C2 | **Required binaries are `bash`, `jq` and `git` only.** Neither GateGuard adoption path offers bash -- upstream `zunoworks/gateguard` is Python and ECC's copy is a JavaScript port -- so both would add a runtime dependency. A YAML rule format would need a new binary or a from-scratch bash/awk YAML-subset parser | `EDMV4-56` ("The required-binary set stays `bash`, `jq`, `git`") owns this. It is load-bearing for two decisions: D7 (JSON rule files for 5.3) and AD1 (bash rewrite for 4.1). Node is **not** admissible unless Gate 2 reverses AD1 via `EDMV4-59`, in which case the dependency addition is re-presented at the gate |
| C3 | **Licence -- resolved, no longer a blocker.** ECC root is MIT (`ECC/LICENSE:1-3`, Affaan Mustafa 2026, verified by direct inspection). GateGuard is vendored into ECC from `zunoworks/gateguard` per its own header at `gateguard-fact-force.js:19-20`, with `skills/gateguard/SKILL.md:5` setting `metadata: origin: community`; that upstream is **also MIT** ("MIT License / Copyright (c) 2026 Hirokazu Seto / ZUNO WORKS K.K.", verified by direct inspection of `https://raw.githubusercontent.com/zunoworks/gateguard/main/LICENSE`, recorded as decisions.md **D13**). Both licences permit reuse with attribution | `EDMV4-12` ("Record ECC and GateGuard provenance in the house-style attribution section") records provenance. No requirement blocks on the licence. The dormant NOTICE clause is triggered by **an AD1 reversal to vendoring, by any route** (`EDMV4-59`), not by any one gate outcome |
| C4 | **`CLAUDE.md` guard D2** -- do not reduce the lens or auditor fan-out. 4.4 is additive so does not violate it on its face, but L13's conditionality must be framed as genuine *inapplicability*, never as cost-driven exclusion | `EDMV4-23` ("`ALL_LENS_IDS` grows to 14 and gains a `CONDITIONAL_LENS_IDS` sibling") holds the constant; `EDMV4-28` ("Lens L13 -- Type Design, auto-N/A on an untyped stack") holds the framing and its grep assertion |
| C5 | **`CLAUDE.md` guard D6** -- do not duplicate the mode matrix into agent prompts. The 4.3 classifier may cite the matrix by section reference and compute a recommendation; it may never restate what each mode does | `EDMV4-22` ("The classifier does not restate the mode matrix (guard D6)") |
| C6 | **Severity vocabulary is closed** -- P0 / P1 / P2 / NOTED, no local scale. ECC's critical / important / nice-to-have scale is the concrete import risk this initiative carries | `EDMV4-29` ("Lens L14 -- Behavioral Test Coverage") AC3 forbids the ECC scale by name; `EDMV4-30` ("The three new lens agents conform to the house lens contract exactly") requires all three new lenses to cite `CLAUDE.md Sec."Severity vocabulary"` in `## Output Format`. (v1.0.0 cited `EDMV4-33`, which owns the lens-count sweep and has nothing to do with severity -- there was no plausible match, so this row is re-derived rather than patched) |
| C7 | **ASCII-only artifacts**, but `edm-lint-artifacts` class 2 does **not** automatically scan `skills/`, `agents/` or `docs/`. The `PreToolUse` git-commit hook runs prefix mode, which never reaches the plugin's own source tree. It also collects only `*.md` (`collect_md_files:251-260`), so no `bin/` script is ever scanned by any invocation | `EDMV4-57` ("ASCII-only across every artifact, verified by a manual `--path` sweep") mandates the manual `--path` sweep for `.md` and a separate explicit byte scan for shell sources |
| C8 | **No CI pipeline exists.** `bin/tests/run-all.sh` plus the git-commit hook are the entire enforcement surface | `EDMV4-58` ("Every new surface has smoke coverage in `run-all.sh`") |
| C9 | **Branch hygiene (D4, as amended 2026-08-31).** The revert hazard is **gone**: commit `bdec805` is the tip of this branch, applied directly rather than by rebase, and the working tree carries zero `disable-model-invocation: true` under `skills/` plus the `edm-check-skill-sync` guard. What remains is that the branch is **3** commits behind `origin/main` (the merge commit `bdb5698` plus the two version bumps `33d63e0` and `4ad0f35`), so `plugins/edm/.claude-plugin/plugin.json:4` reads `3.2.0` here against `origin/main`'s `3.2.1`. That is a one-line merge-time reconciliation, **not a functional defect and not a blocker**. `file:line` citations in Phase 1 and in this SRD were taken against this branch's tree and are re-verified per requirement, not against a hypothetical post-rebase tree | `EDMV4-03` ("Reconcile the D4 residual") owns the version reconciliation and the preservation of the unstaged `*opus-5*` arm. It blocks nothing |
| C10 | **`edm-check-vocabulary` scans `hooks/hooks.json` and `monitors/monitors.json`.** Any new hook JSON content stays within the vocabulary rules it enforces. Note that `edm-lint-artifacts` does **not** reach either file -- `collect_md_files` finds only `*.md` -- so `edm-check-vocabulary` is the whole of the automatic coverage here | `EDMV4-09` ("One deny mechanism, two selectable back-ends") AC9, `EDMV4-41` ("Build the evaluator from nothing"), `EDMV4-42` ("`action: block` requires explicit opt-in"), `EDMV4-57` AC (the explicit non-`.md` byte scan) |

---

## 5. Target Architecture

The target-state diagrams and the architecture decisions behind them live in
`SRD/edm/EDMV4__ecc-integration/architecture.md`, authored by `edm-architect` in parallel with this
document. **`architecture.md` is the canonical home for this initiative's diagrams** per
`CLAUDE.md Sec."Project artifact layout"` (EDMV2-38); this SRD does not duplicate them.

The diagrams a reader should expect there, and what each one settles:

| Diagram | Settles |
|---|---|
| System context | Where each of the eleven items attaches to the existing plugin -- `hooks/hooks.json`, `bin/edm-state`, the `skills/` and `agents/` prompt surface, `bin/tests/`, and the `docs/audit-patterns/` data path |
| `PreToolUse` sequence (GateGuard) | The DENY / FORCE / ALLOW three-stage flow, the Phase-6-active marker read on the allow path, and the fail-open branch when session state cannot be persisted |
| `update-patterns` data flow (4.2) | The seed-copy-then-write path and the seed-plus-harvested read path, showing why both sides must land in one commit |
| Code-audit round composition (4.4) | Where stack detection sits in Step 1, how an auto-N/A lens reaches `lenses-run.txt`, and how `round_type` and the CA-471 completeness backstop each read that manifest |
| Hookify dispatch (5.3) | The one-classify-pass / N-projections evaluator shape and the two-tier exit-code contract |

### 5.1 Architecture decisions this SRD's requirements are written against

`architecture.md` resolved the question Gate 1 / D6 routed to Phase 2, plus five others. The
requirements in Sec.6 are written against these outcomes, not against the open questions Phase 1
carried.

| ID | Decision | Consequence for Sec.6 |
|---|---|---|
| **AD1** | **GateGuard is a bash rewrite of roughly 250-350 lines, scoped to `Edit`/`Write`/`MultiEdit`. Not a Node vendoring.** Upstream `zunoworks/gateguard` is Python (`pyproject.toml`, `src/gateguard/`, `pip install gateguard-ai`); ECC's copy is a JavaScript port. There is no bash implementation to adopt from either, so both adoption paths would add a runtime dependency the plugin has never had. Separately, ECC's 741 lines of helper closure (`shell-substitution.js` 482 + `gateguard-heredoc.js` 259) exist solely to serve `isDestructiveBash():674-721`; descoping the destructive-`Bash` arm deletes the entire recursive-BFS shell tokenizer that `explorers/04` Sec.1 called the harder half | `EDMV4-07` mandates the bash rewrite and the required-binary set stays `bash`/`jq`/`git` (`EDMV4-56`). The descope is a real scope reduction against the Gate-1-approved 4.1 and is raised for ratification as `EDMV4-05` |
| **AD2** | One `emit_decision deny\|allow <reason>` function with two back-ends selected by `EDM_GATEGUARD_DENY_MODE`, defaulting to `json`. Spike B flips a default constant and a smoke assertion rather than forcing a rewrite | `EDMV4-09` |
| **AD3** | One shared `bin/_edm-datadir-lib.sh` -- the first `${CLAUDE_PLUGIN_DATA}` consumer in `bin/` -- resolving a writable data root and a project key for both 4.1's marker and 4.2's harvested delta. Two subdirectories: `${data}/patterns/` (durable) and `${data}/run/` (ephemeral) | `EDMV4-08`, `EDMV4-13` |
| **AD4** | **Event ownership: one EDM-authored body per tool family.** `Stop` grows a **second entry in the existing block's `hooks` array** rather than a second matcher block; `PreToolUse` gets one new matcher block for `Edit`/`Write`/`MultiEdit`, matcher-disjoint from the existing `git commit` block; hookify's `file` and `stop` rules are evaluated in-process by `edm-gateguard` and `edm-stop-gate` respectively, so each surface has exactly one owner. The one genuine collision -- a hookify `bash`-rule block overlapping `git commit` -- is gated on Spike A. **Qualifier the SRD must carry, per `architecture.md:130`**: the in-repo two-entries-in-one-array precedent (`hooks.json:16-24`) is a `command` **plus a `prompt`**, not two `command` entries. Two `command` entries in one `hooks` array have **zero in-repo instances** | `EDMV4-01` (whose experiment must specifically test two `command` entries), `EDMV4-43`, `EDMV4-44` |
| **AD5** | `round_type` **stays a two-value enum**. The third state lives in a new sibling field `audit_rounds.<type>.rounds[].lenses_na`, with `full` iff `(lenses UNION lenses_na) == ALL_LENS_IDS` and `lenses_na` a subset of a new `CONDITIONAL_LENS_IDS="L13"`. For the union rule to be correct in **both** branches, `audit-round-start` must **materialize** `lenses = ALL_LENS_IDS` when `--lenses` is omitted, instead of recording `[]` (`bin/edm-state:4557`) -- see `EDMV4-24`. `lenses_na` is written at `audit-round-start`, before any lens agent launches, so a lens cannot retroactively excuse its own non-delivery. **Safety property, stated precisely**: holding `ALL_LENS_IDS` constant, the union derivation with an empty `lenses_na` returns the same answer as today's set-equality for every input. It is *not* true that every input returns the same answer across the `ALL_LENS_IDS` change itself -- `--lenses L1,...,L11` returns `full` today and `partial` after, deliberately (see `EDMV4-32`). `architecture.md:170-171` states this too loosely and is corrected by this row | `EDMV4-24`, `EDMV4-25`, `EDMV4-32` |
| **AD6** | The pattern read side is **route (c)**: `edm-state get-patterns <type> --paths` prints the seed path then the delta path, the launching skill interpolates both into the agent launch template, and the four agents do two ordinary `Read`s. Route (b) -- agents calling the subcommand themselves -- is **blocked**, because `agents/edm-srd-writer.md:8` and `agents/edm-ticket-writer.md:7` have **no `Bash` grant**, and granting `Bash` to two writer agents to read a documentation file is a disproportionate widening of a deliberately narrow tool surface | `EDMV4-14` (which absorbs the read side per the fold recorded in Sec.6.3) |

### 5.2 Architecture and scope decisions requiring Gate 2 ratification

Three decisions go to Gate 2 for explicit human ratification rather than being absorbed as
implementation detail. Two are **reductions against Gate-1-approved scope**, so the change-control
principle in `CLAUDE.md Sec."Unverifiable acceptance criteria (D15)"` applies by analogy -- an
implementer cannot descope approved scope. The third is the architecture decision the other two and
the entire licence posture rest on, and nothing in v1.0.0 ratified it.

**All three were ratified at Gate 2 on 2026-09-02** (`decisions.md` D14, D15, D16). This section is
retained as the record of what was presented and why -- not as an open question a later reader
re-runs the gate to answer.

| ID | What is presented | Why it cannot be absorbed |
|---|---|---|
| `EDMV4-05` | Descoping GateGuard's destructive-`Bash` arm | Reduction against Gate-1-approved 4.1 |
| `EDMV4-06` | Descoping 5.4's "phase started with no `completed_at`" anomaly | Reduction against Gate-1-approved 5.4 |
| `EDMV4-59` | **AD1 itself: bash rewrite, not a vendoring** | Gate 1 / D6 explicitly deferred vendor-versus-rewrite to Phase 2 with "Resolve in SRD". Phase 2 answered it, but an answer recorded by the architect is not a ratification. AD1 is also the sole trigger for the dormant MIT NOTICE obligation (D13), so leaving it unratified means a Gate 2 that approves `EDMV4-05` while separately directing vendoring would leave that obligation dormant and unnoticed |

**These three are independent.** Rejecting `EDMV4-05` yields a *larger bash rewrite*, not a
vendoring -- it does not reverse AD1. Only `EDMV4-59` can reverse AD1. Wiring the licence
obligation to `EDMV4-05`, as v1.0.0 did, was a live exposure and is corrected in Sec.7.3,
`EDMV4-12` and `EDMV4-56`.

**Outcome, recorded 2026-09-02:** all three were ratified at Gate 2 -- `EDMV4-59` as AD1 (bash
rewrite, not a vendoring; `decisions.md` D14), `EDMV4-05` as the destructive-`Bash` descope
(`decisions.md` D15), and `EDMV4-06` as the "phase started with no `completed_at`" descope
(`decisions.md` D16). Each requirement's own "On accept" branch below is therefore the branch that
applies; the "On reject" branches are retained as the record of what was decided against, not as an
open path.

Note on the cited authority: `CLAUDE.md Sec."Unverifiable acceptance criteria (D15)"` is scoped to
unverifiable acceptance criteria on **tickets**, not to reductions against Gate-1-approved **SRD**
scope. The extension is a reasoned analogy and the substantive obligation is right, but no canonical
section covers this case today. Recorded here as a **convention gap** to open separately, not as an
EDMV4 defect.

---

## 6. Feature Requirements

**Reading this section.** Every requirement carries exactly one priority (Must Have / Should Have /
Could Have), at least one testable acceptance criterion, and `file:line` Target Components drawn from
the explorer reports. Values that appear more than once in this document -- the 14-lens count, the 6
`update-patterns` call sites, the 14 anchoring files, the 8 mode enum values, the 3,000 ms
commit-path budget -- are defined once here or in Sec.4 and cited by reference elsewhere. Where a
number in the source analysis or in an explorer report is superseded, the requirement says so
explicitly rather than leaving two figures in circulation.

**`EDMV4-03` is not a scheduling dependency.** v1.0.0 declared it a precondition on every
implementation requirement, on the premise that the branch still carried the D3 defect. `decisions.md`
D4 as amended records that the defect is already fixed on this branch and that the residual --
reconciling `plugin.json` `3.2.0` against `origin/main`'s `3.2.1` while preserving the unstaged
`*opus-5*` arm -- is **non-blocking**. `EDMV4-03` is therefore a merge-time obligation carried in
the Definition of Done, and no requirement below lists it as a dependency. This also resolves the
contradiction v1.0.0 carried between "`EDMV4-03` blocks everything" and `EDMV4-55`/`EDMV4-57`, both
of which correctly declared no dependencies.

**Merged IDs.** `EDMV4-15` and `EDMV4-16` are **merged into `EDMV4-14`** and carry no independent
acceptance criteria -- see their entries in Sec.6.3 for the pointer and the reason. Their IDs are
retained rather than reused so every existing cross-reference still resolves.

### 6.1 Blocking preconditions and change control

#### EDMV4-01: Spike A -- multi-hook-per-event combination semantics

- **Priority**: Must Have
- **Description**: Claude Code's behaviour when **two blocking hooks match the same tool call on the
  same event** is unverified from this repository's source. `hooks/hooks.json`'s five
  `UserPromptExpansion` matcher blocks prove that *adding* blocks is mechanically supported, but they
  are matcher-disjoint (one per slash command) so they never exercise the case. EDM has never had two
  independently authored blocking hooks compete on one call. Both 4.1 and 5.3 want `PreToolUse`, and
  `architecture.md` AD4's one genuine collision -- a hookify `bash`-rule block overlapping the
  existing `git commit` block -- depends entirely on the answer. Run the experiment against the live
  host and record the result as a numbered decision, following the D21 / D22 / D24 precedent of
  spiking a Claude Code behaviour this plugin depends on rather than assuming it.
- **Acceptance Criteria**:
  - [ ] A throwaway plugin (or a scratch `.claude/settings.json` hook block) registers **two**
        `PreToolUse` matcher blocks that both match one tool call. Block 1 exits 0 (allow); block 2
        denies. The experiment records which decision the host takes.
  - [ ] The reverse ordering is also run -- block 1 denies, block 2 allows -- and its result recorded
        separately. If the two orderings differ, registration order is load-bearing and that fact is
        stated.
  - [ ] The experiment additionally records whether **both** blocks' commands execute at all, or only
        the first-registered one, distinguishable by each command writing a distinct marker file.
  - [ ] The same two-block experiment is run for the `Stop` event.
  - [ ] **Separately and specifically: two `"type": "command"` entries in one block's `hooks`
        array.** State the premise honestly -- `hooks/hooks.json:16-24` is a `command` entry plus a
        `prompt` entry, a **heterogeneous** pair. A homogeneous `command`+`command` pair has
        **zero** instances anywhere in this repository, so AD4's chosen `Stop` design (`EDMV4-44`)
        rests on an untested shape, not on the cited precedent. The experiment registers two
        `command` entries in one `Stop` block, each writing a distinct marker file, and records
        whether **both** ran, whether only the first ran, and whether the second entry's exit code
        was honoured when the first exited 0.
  - [ ] If only one `command` entry per `hooks` array executes, the decision states that
        `EDMV4-44`'s second-entry design does not work and that a second `Stop` **matcher block**
        (the alternative `architecture.md` rejected) is re-presented at a gate before 5.4 ships.
  - [ ] Result recorded in `decisions.md` as a numbered decision naming the Claude Code version
        string (`claude --version`) and the date, matching D22's recording format.
  - [ ] The decision explicitly answers: may 5.3 register a `bash`-event block alongside the existing
        `git commit` block (`hooks/hooks.json:80-90`), or must AD4's fallback -- folding
        `edm-lint-staged-artifacts` into `edm-hookify`'s Bash dispatcher -- be taken instead.
  - [ ] If the answer is "first-registered wins" or "blocks must be consolidated", the decision states
        that `EDMV4-43`'s `bash` event is **not** shipped in this initiative and hookify ships with
        `file` and `stop` events only.
- **Dependencies**: none. Runnable immediately, in parallel with Phase 1 work.
- **Blocks**: `EDMV4-07` (4.1), `EDMV4-43` (5.3 event wiring).
- **Target Components**: `plugins/edm/hooks/hooks.json:14-78` (the five matcher-disjoint
  `UserPromptExpansion` blocks that motivate the question), `hooks.json:16-24` (the
  `command`-plus-`prompt` pair -- the nearest in-repo shape, and **not** the homogeneous pair AD4
  needs), `hooks.json:80-90` (the existing `git commit` block that the collision would
  overlap), `SRD/edm/EDMV4__ecc-integration/decisions.md` (the output).

#### EDMV4-02: Spike B -- deny shape for a native `Edit` / `Write` / `MultiEdit`

- **Priority**: Must Have
- **Description**: `permissionDecision` and `hookSpecificOutput` appear **zero times** anywhere in
  this repository outside the analysis document (`explorers/02` Sec.1.3). Every EDM hook that blocks
  does so via a bash exit code, and the sole blocking precedent -- `edm-lint-staged-artifacts` exit 2
  -- is a `Bash`-wrapped `git commit`, not a native `Edit`. Whether an exit-code-only `PreToolUse`
  hook can deny a native `Edit`/`Write`/`MultiEdit` is unverified in **both** directions. This is the
  worst failure shape in the initiative: if the JSON shape is silently ignored, GateGuard denies
  nothing while appearing to work, because the allow path is silent. AD2 makes the outcome a
  one-constant change rather than a rewrite, but the constant still has to be set from evidence.
- **Acceptance Criteria**:
  - [ ] A scratch `PreToolUse` hook matching `Edit` prints the AD2 JSON payload
        (`{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"<text>"}}`)
        on stdout and exits 0. The experiment records whether the `Edit` was refused, and whether the
        `permissionDecisionReason` text was surfaced to the agent as the tool result.
  - [ ] The same experiment is repeated for `Write` and for `MultiEdit` and results are recorded per
        tool, not collapsed into one verdict.
  - [ ] A second scratch hook prints the same text on **stderr** and exits **2**. The experiment
        records whether that refused the `Edit`, and whether the stderr text reached the agent.
  - [ ] The experiment records what a `MultiEdit` deny does to the remaining files in the batch:
        whether the whole call is refused or partially applied.
  - [ ] Result recorded in `decisions.md` as a numbered decision naming the Claude Code version and
        date, and stating the value `EDM_GATEGUARD_DENY_MODE` must default to (`json` or
        `exit-code`).
  - [ ] If **neither** mechanism denies a native `Edit`, the decision says so plainly and `EDMV4-07`
        is re-presented at Gate 2 as a no-go for 4.1 rather than being implemented against a
        mechanism that does not work.
- **Dependencies**: none.
- **Blocks**: `EDMV4-07`, `EDMV4-09`.
- **Target Components**: `plugins/edm/bin/edm-lint-staged-artifacts:7-10,150-158` (the only existing
  blocking precedent and its exit-code contract), `plugins/edm/hooks/hooks.json:80-90`,
  `SRD/edm/EDMV4__ecc-integration/decisions.md`.

#### EDMV4-03: Reconcile the D4 residual -- the `plugin.json` version divergence, not a rebase

- **Priority**: Must Have
- **Description**: **The revert hazard D4 originally described is gone.** Commit `bdec805`
  ("fix(edm): :bug: Remove disable-model-invocation so skills can be Skill-tool dispatched") is now
  the tip of `edm/edmv4-ecc-integration`, applied directly rather than by rebase. Verified in the
  working tree: **zero** `skills/*/SKILL.md` files carry `disable-model-invocation: true`,
  `bin/edm-check-skill-sync` carries the plugin-wide guard, and root `CLAUDE.md` and
  `plugins/edm/README.md` carry the post-fix wording. `decisions.md` D4 records this as an amendment
  dated 2026-08-31 and corrects the branch-age figure to **3** commits behind `origin/main`, not 2.

  What remains is narrow and, in D4's own words, **non-blocking**: the branch is missing the merge
  commit `bdb5698` and the two version-bump commits `33d63e0` and `4ad0f35`, so
  `plugins/edm/.claude-plugin/plugin.json:4` reads `3.2.0` here while `origin/main` reads `3.2.1`.
  That is a one-line divergence to reconcile at merge, not a functional defect. The one real hazard
  in the reconciliation is collateral: an unstaged local edit to `bin/edm-state` adds an `*opus-5*`
  arm to `compute_cost_usd`'s model `case` (work not present upstream), and a careless
  merge/checkout would discard it, silently repricing every Opus 5 run at the `*)` placeholder rate.

  Because the residual is non-blocking, **this requirement blocks nothing.** v1.0.0 declared it a
  precondition on every implementation requirement, which gated the whole initiative on a one-line
  version bump and contradicted two requirements that correctly declare "Dependencies: none".
- **Acceptance Criteria**:
  - [ ] `plugins/edm/.claude-plugin/plugin.json:4` records a version at or above `3.2.1` in the
        merge that lands EDMV4, and `.claude-plugin/marketplace.json`'s `edm` entry records the same
        value. (`EDMV4-35` bumps both again for the 14-lens manifest description; the two bumps are
        reconciled into one final value, not applied twice.)
  - [ ] The local unstaged `*opus-5*` arm in `compute_cost_usd`'s model `case` in `bin/edm-state`
        **survives** the reconciliation: an `opus-5` model identifier resolves to the Opus rate row
        and does **not** fall through to the `*)` placeholder-pricing arm. A test asserts this by
        pricing a synthetic `claude-opus-5-*` identifier and comparing against the Opus row, not by
        grepping for the arm's presence.
  - [ ] The `*opus-5*` arm precedes the final `*)` fallback and introduces no bare family wildcard,
        the two invariants `CLAUDE.md Sec."Cost tracking"` states for that `case` after D32.
  - [ ] **Regression verification, not a fix** -- these three assert the state D3/D4 already left the
        tree in and fail loudly if the reconciliation regresses it:
        `grep -rc 'disable-model-invocation' plugins/edm/skills/` returns 0 across all 14 files;
        all 14 carry `user-invocable: true`; `bash plugins/edm/bin/edm-check-skill-sync` exits 0 and
        its body contains the guard banning the flag anywhere under `skills/`.
  - [ ] The staged EDMV3-archival rename set (~313 paths) and the unstaged
        `bin/tests/wave6-smoke.sh` edits are accounted for at merge time -- each is either committed
        or deliberately dropped, with the choice recorded. Neither is silently carried into an
        unrelated commit.
  - [ ] `bash plugins/edm/bin/tests/run-all.sh` passes on the reconciled tree, establishing the
        baseline every later requirement measures against.
  - [ ] Every `file:line` citation in this SRD is re-verified against the tree at the time the
        ticket consuming it is closed. A citation off by more than +/-10 lines is a defect to
        correct, not a rounding tolerance. This obligation is **independent of D4** -- this
        plugin's own line numbers went stale twice during this initiative (`audit-srd.md` Process
        Finding 3) -- so it applies whether or not any branch reconciliation happens.
- **Dependencies**: none.
- **Blocks**: nothing. Per D4 as amended the residual is explicitly non-blocking. It must land in
  the merge that ships EDMV4, which is a merge-time obligation rather than a scheduling dependency.
- **Target Components**: `plugins/edm/.claude-plugin/plugin.json:4`,
  `.claude-plugin/marketplace.json` (the `edm` entry), `plugins/edm/bin/edm-state` (the
  `compute_cost_usd` `case`), `plugins/edm/bin/edm-check-skill-sync`,
  `plugins/edm/skills/*/SKILL.md` (14 files, verification only),
  `plugins/edm/bin/tests/run-all.sh`, `plugins/edm/CLAUDE.md Sec."Cost tracking"` (the `case`
  invariants), `SRD/edm/EDMV4__ecc-integration/decisions.md` (D4 as amended).

#### EDMV4-04: Inherited ticket IDs `T01`-`T05` are pre-claimed and constrain Phase 4

- **Priority**: Must Have
- **Description**: `EDMV4-T01`, `EDMV4-T04` and `EDMV4-T05` already have defined scope, assigned by
  EDMV3's `decisions.md` (D29, D34, D62) and cited by ID in `plugins/edm/CLAUDE.md:352` and in
  EDMV3's archived ticket coverage map. `EDMV4-T02` and `EDMV4-T03` were **closed inside EDMV3** and
  must never be reused -- reusing them would make two different pieces of work share one ID across
  the archived and live ledgers. Phase 4's ticket pack therefore cannot allocate `EDMV4-T01` through
  `EDMV4-T05` freely, which is the opposite of the usual "number tickets from T01" convention and is
  easy to violate by default.
- **Acceptance Criteria**:
  - [ ] The ticket pack `README.md` carries an explicit "Inherited ticket IDs" note stating that
        `T01`, `T04` and `T05` are pre-claimed and that `T02` and `T03` are retired.
  - [ ] `EDMV4-T01` in the pack covers the Mermaid lint budget re-framing and nothing else
        (`EDMV4-47`, `EDMV4-48`).
  - [ ] `EDMV4-T04` in the pack covers by-name reference anchoring and nothing else (`EDMV4-49`
        through `EDMV4-51`).
  - [ ] `EDMV4-T05` in the pack covers eval-baseline verification plus the boundary record and
        nothing else (`EDMV4-52`, `EDMV4-53`).
  - [ ] No ticket in the pack is numbered `EDMV4-T02` or `EDMV4-T03`. A gap in the numbering between
        `T01` and `T04` is correct and intentional, and the `README.md` note says so, so a later
        reader does not "fix" it.
  - [ ] New tickets are numbered from `EDMV4-T06` upward.
  - [ ] `plugins/edm/CLAUDE.md:352`'s reference to the never-created
        `EDMV4__lint-and-pipeline-budgets` initiative is updated to name this initiative's real
        directory, `SRD/edm/EDMV4__ecc-integration/` -- the stale reference D1 created on this
        initiative's creation and put in scope to fix.
- **Dependencies**: none.
- **Target Components**: `SRD/edm/EDMV4__ecc-integration/tickets/README.md` (Phase 4 output),
  `plugins/edm/CLAUDE.md:352`, `SRD/.archived/edm/EDMV3__prompt-streamline/decisions.md` (D29, D34,
  D62 -- the origin of the three claims).

#### EDMV4-05: Ratify the descoping of GateGuard's destructive-`Bash` arm

- **Priority**: Must Have
- **Description**: The Gate-1-approved 4.1 is the source analysis's 4.1, which explicitly includes a
  destructive-`Bash` gate demanding blast radius, a one-line rollback procedure and the quoted
  instruction (`ecc-integration-analysis.md:293`). `architecture.md` AD1 removes that arm: it is what
  drags in ECC's 741 lines of helper closure (`shell-substitution.js` 482 lines +
  `gateguard-heredoc.js` 259 lines), whose sole consumer is `isDestructiveBash():674-721`, and
  dropping it takes the bash rewrite from 400-600 lines to roughly 250-350. **But it is a reduction
  against approved scope, and an implementer cannot descope approved scope.** Only a human, at a
  gate, can accept it, per the change-control principle in `CLAUDE.md Sec."Unverifiable acceptance
  criteria (D15)"`.

  **This requirement governs a human decision, so its two numbers must be right and v1.0.0's were
  not.**

  *The saving.* The 741 lines are ECC's **JavaScript**; they are never written in bash under either
  option, so they cannot appear in a bash line-count saving. The honest figure is two things stated
  separately: **150-250 lines of bash** (400-600 minus 250-350), **plus** not having to port the
  recursive-BFS shell tokenizer at all -- which `explorers/04` Sec.1 assessed as "the harder half
  to port" and which is the qualitative half of the argument. Quoting "741 lines plus 250-350" as
  one saving overstates it by roughly an order of magnitude and would put a false number in front
  of the human making the call.

  *The residual exposure.* v1.0.0 claimed EDM "already blocks the one destructive `Bash` operation
  its methodology cares about, `git commit`, via `edm-lint-staged-artifacts`". **That is false.**
  `bin/edm-lint-staged-artifacts:140-159` blocks on **artifact lint violations** only -- a
  non-ASCII byte, an attribution trailer, a raw semicolon in a Mermaid label. It guards nothing
  destructive, and it does not fire at all unless something under the derived `srd_root` is staged.
  The residual exposure is therefore **unbounded by anything in this plugin**, and the Gate 2
  presentation must say so.

  **Ratified 2026-09-02 (see `decisions.md` D15): descope approved.** 4.1 ships as an edit gate
  over `Edit`/`Write`/`MultiEdit` only. The "On accept" branch below is the branch that applied;
  the "On reject" branch is retained as the record of what was decided against.
- **Acceptance Criteria**:
  - [ ] The reduction is presented at Gate 2 via the canonical
        `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"`, stating what is lost, what remains, and
        the cost saved.
  - [ ] The stated saving is **150-250 lines of bash, plus not porting ECC's recursive-BFS shell
        tokenizer** (`shell-substitution.js` 482 + `gateguard-heredoc.js` 259 = 741 lines of
        **JavaScript**, never written in bash under either option). The presentation must not
        present 741 as part of a bash line-count saving.
  - [ ] The presentation **enumerates the concrete command classes that remain entirely unguarded**
        under the descope, by name and not by category: `rm -rf`, `git reset --hard`,
        `git clean -fd`, a force-push (`git push --force` / `--force-with-lease`), and destructive
        SQL such as `DROP TABLE`. None of these is gated today and none becomes gated under 4.1 as
        descoped.
  - [ ] The presentation states plainly that **no existing EDM hook bounds this exposure.** It
        names `bin/edm-lint-staged-artifacts:140-159` as blocking on artifact lint violations only,
        and corrects the v1.0.0 claim that it constitutes a destructive-`Bash` guard. A human must
        not accept this reduction believing a partial guard already exists.
  - [ ] The presentation names the intended future vehicle -- 5.3's `bash`-event rule files
        (`EDMV4-43`) -- and states plainly that those ship **only if Spike A clears** (`EDMV4-01`),
        so the follow-on route is itself conditional rather than assured.
  - [ ] The human's decision -- accept or reject -- is recorded in `decisions.md` as a numbered
        decision with rationale, not inferred from silence.
  - [ ] On **accept**: `EDMV4-07`'s scope is `Edit`/`Write`/`MultiEdit` only, and the ticket pack
        carries no destructive-`Bash` ticket. The boundary is recorded using the EDMV3 D14
        scope-boundary framing, naming a follow-on vehicle (5.3's rule files) rather than being
        silently dropped.
  - [ ] On **reject**: `EDMV4-07` is re-scoped to include the destructive-`Bash` arm, the estimate
        returns to 400-600 lines of bash **including** a hand-written shell tokenizer, and the
        vendor-versus-rewrite trade is re-opened as a **separate** question routed to `EDMV4-59`.
        Rejecting this requirement does **not** by itself reverse AD1 -- it yields a larger bash
        rewrite, not a vendoring. Only `EDMV4-59` can reverse AD1, and only an AD1 reversal revives
        the MIT NOTICE obligation in `EDMV4-12`.
  - [ ] Whichever way it goes, `architecture.md` AD1 is amended to record the ratification outcome so
        the two documents do not disagree.
- **Dependencies**: none. Must be resolved at Gate 2, before `EDMV4-07` is ticketed.
- **Target Components**: `SRD/edm/EDMV4__ecc-integration/decisions.md`,
  `SRD/edm/EDMV4__ecc-integration/architecture.md` (AD1),
  `plugins/edm/bin/edm-lint-staged-artifacts:140-159` (the hook whose scope the presentation must
  state correctly), `plugins/edm/skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"`,
  `plugins/edm/CLAUDE.md Sec."Unverifiable acceptance criteria (D15)"`.

#### EDMV4-06: Ratify the descoping of 5.4's "phase started with no `completed_at`" anomaly

- **Priority**: Must Have
- **Description**: The source analysis names four `validate` anomalies for 5.4 to surface at `Stop`
  (`ecc-integration-analysis.md:758-763`). Phase 1 verified that three exist and one does not: "a
  phase marked started with no `completed_at`" has **no anomaly definition at all**. `TIME_ORDER`
  (`bin/edm-state:1714-1729`) is the only anomaly touching both timestamps and it fires only when
  both are present and inverted; a phase with `started_at` set and `completed_at` simply absent -- the
  normal in-progress state -- produces no anomaly line. Building it is new design, not wiring: a
  phase legitimately stays started for hours during a Phase 6 wave, so a naive presence check would
  block on ordinary long-running work and would need a time threshold or an explicit
  "wave in progress" carve-out. `architecture.md` descopes it. As with `EDMV4-05`, that is a
  reduction against approved scope and needs human ratification.

  **Ratified 2026-09-02 (see `decisions.md` D16): descope approved.** The "On accept" branch below
  is the branch that applied; the "On reject" branch is retained as the record of what was decided
  against.
- **Acceptance Criteria**:
  - [ ] The reduction is presented at Gate 2 via the canonical Gate PROTOCOL, stating that 3 of the
        analysis's 4 named anomalies are delivered and naming the fourth precisely.
  - [ ] The presentation states why a naive presence check is not acceptable: it would fire on every
        `Stop` throughout a multi-hour Phase 6 wave, which is the same
        block-on-a-normal-state failure mode that keeps `OPEN_AUDIT_ROUND` informational
        (`bin/edm-state:1786-1789`).
  - [ ] The presentation states what already covers part of the gap: `cmd_archive` already refuses
        when the **terminal** phase has no `completed_at` (`bin/edm-state:3185`), so the exposure is
        non-terminal phases only.
  - [ ] The human's decision is recorded in `decisions.md` as a numbered decision.
  - [ ] On **accept**: the boundary is recorded using the EDMV3 D14 scope-boundary framing, naming
        what a future design would need (a threshold or a wave-in-progress carve-out), and
        `EDMV4-45` ships the three verified anomalies only.
  - [ ] On **reject**: a new requirement is added for the anomaly's design, including its threshold
        semantics and its `blocking`-versus-`info` classification, and `EDMV4-45` gains a dependency
        on it.
- **Dependencies**: none. Must be resolved at Gate 2, before `EDMV4-44` and `EDMV4-45` are ticketed.
- **Target Components**: `plugins/edm/bin/edm-state:1709-1927` (`state_anomalies`),
  `bin/edm-state:1714-1729` (`TIME_ORDER`), `bin/edm-state:1786-1789` (the
  `OPEN_AUDIT_ROUND` informational rationale), `bin/edm-state:3185` (the terminal-phase check that
  already exists), `SRD/edm/EDMV4__ecc-integration/decisions.md`.

#### EDMV4-59: Ratify AD1 -- GateGuard is a bash rewrite, not a vendoring

- **Priority**: Must Have
- **Description**: Gate 1 / D6 asked "vendor ECC's 3 Node files or rewrite in bash?" and explicitly
  deferred it with **"Resolve in SRD"**. Phase 2 answered it as architecture decision AD1 (bash
  rewrite, ~250-350 lines), and the human independently recommended the same thing the same day --
  but **an answer recorded by the architect is not a ratification.** Nothing in v1.0.0 of this SRD
  presented AD1 itself for a gate decision, which left two problems.

  First, a Gate-1 deferral that names the gate it returns to has to actually return to it, or the
  deferral silently becomes an implementer's choice.

  Second, and more consequentially, **AD1 is the sole trigger for the MIT attribution and
  licence-notice obligation.** `decisions.md` D13 states the trigger correctly: the strict
  obligation returns "if Phase 2 or Gate 2 reverses AD1 back to vendoring". Under AD1 as chosen,
  nothing is copied from either upstream -- what carries over is the concept, which is pattern-level
  adoption matching the `caveman`/`ponytail` clean-room posture, so `EDMV4-12` is house convention
  rather than licence compulsion. Under a vendoring, roughly 2,042 lines across three files are
  retained verbatim and the obligation binds in full. Wiring that trigger to `EDMV4-05` (as v1.0.0
  did in Sec.7.3 and `EDMV4-12` AC7) was wrong in a way that creates real exposure: `EDMV4-05`
  ratifies the destructive-`Bash` **descope**, and rejecting it yields a *larger bash rewrite*, not
  a vendoring. A Gate 2 that approves `EDMV4-05` while separately directing vendoring would leave
  the NOTICE obligation dormant with nothing to wake it.

  **Ratified 2026-09-02 (see `decisions.md` D14): bash rewrite confirmed, not a vendoring.** The
  "On accept" branch below is the branch that applied; the "On reject" branch is retained as the
  record of what was decided against.
- **Acceptance Criteria**:
  - [ ] AD1 is presented at Gate 2 via the canonical
        `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"` as its own decision, distinct from
        `EDMV4-05` and `EDMV4-06`, and is not folded into either.
  - [ ] The presentation states the three adoption paths and what each costs: **vendor ECC's
        JavaScript** (adds `node` to a required-binary set that has always been `bash`/`jq`/`git`,
        imports roughly 2,042 lines nobody in this plugin maintains, and triggers the full MIT
        obligation); **adopt upstream `zunoworks/gateguard`** (adds `python3` plus a
        `pip install gateguard-ai` step -- verified by direct inspection: `pyproject.toml`,
        `src/gateguard/`); **rewrite in bash** (250-350 lines under `EDMV4-05` accepted, 400-600
        with the destructive arm restored, no new dependency, no verbatim reuse).
  - [ ] The presentation states that there is **no bash implementation to adopt from either
        upstream** -- upstream is Python and ECC's copy is a JavaScript port -- so "just vendor the
        existing one" is not among the options.
  - [ ] The presentation states the licence consequence explicitly and in both directions: on
        **accept**, `EDMV4-12` stays Should Have and the NOTICE clause stays dormant; on **reject**
        (vendoring), `EDMV4-12` is re-raised to **Must Have**, the three vendored files retain their
        copyright headers unmodified, and `plugins/edm/NOTICE` (new) names ZUNO WORKS K.K. and
        Affaan Mustafa with their MIT texts.
  - [ ] The human's decision is recorded in `decisions.md` as a numbered decision with rationale,
        not inferred from silence and not inferred from the outcome of `EDMV4-05`.
  - [ ] On **accept**: `EDMV4-07` proceeds as a bash rewrite and `EDMV4-56`'s required-binary set is
        unchanged.
  - [ ] On **reject**: `EDMV4-07` is re-scoped to a vendoring, `EDMV4-56` is re-presented at the
        gate as an explicit dependency addition (`node` or `python3`) rather than being silently
        violated, and `EDMV4-55`'s bash-3.2 floor no longer applies to the vendored files (which
        are not bash) -- that carve-out is recorded rather than assumed.
  - [ ] `decisions.md` D13's attribution paragraph is updated to record the ratification outcome, so
        the licence record and the architecture record cannot disagree.
  - [ ] `architecture.md` AD1 is amended to record the ratification outcome.
- **Dependencies**: none. Must be resolved at Gate 2, before `EDMV4-07` is ticketed.
- **Blocks**: `EDMV4-07`, `EDMV4-12` (its priority), `EDMV4-56` (its premise).
- **Target Components**: `SRD/edm/EDMV4__ecc-integration/architecture.md` (AD1),
  `SRD/edm/EDMV4__ecc-integration/decisions.md` (D6, D13),
  `plugins/edm/skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"`,
  `plugins/edm/CLAUDE.md Sec."Prompt conventions (house style)"` (where the provenance entry lands),
  `plugins/edm/CLAUDE.md Sec."Testing changes"` (the required-binary statement).

#### EDMV4-60: `cmd_gate_check` maps `audit-tickets` to the gate it produces, deadlocking Phase 5

- **Priority**: Must Have
- **Description**: `cmd_gate_check` in `bin/edm-state` maps each phase-skill token to the HITL gate
  that skill must **consume** before it may run. Every row holds that meaning except one:
  `audit-tickets` was grouped with `implement` on the `required_gate=3` arm. But `audit-tickets`
  is Phase 5, the phase that **presents** Gate 3 (`skills/audit-tickets/SKILL.md Sec."HITL Gate
  3"`). Requiring Gate 3 to run the only thing that can approve Gate 3 is circular, and Phase 5
  is unreachable for every initiative whose mode does not skip it.

  **Both enforcement layers deadlock, not one.** The `edm:audit-tickets` `UserPromptExpansion`
  hook in `hooks/hooks.json` runs the same `gate-check` and blocks expansion on its exit-3
  refusal status, so invoking the slash command directly fails identically to the Step 0
  preflight path. Neither escape in `cmd_gate_check` applies: the legacy warn-and-proceed branch
  needs an absent `schema_version`, and `gate_required_and_approved` returns `not-required` only
  when the feeding phase is skipped or past the mode's terminal phase. A standard-lifecycle
  initiative satisfies neither.

  **Why the suite stayed green.** `bin/tests/wave6-smoke.sh` (EDMV3-T13 AC3) looped all eight
  tokens asserting only `"$tok_out" == *"Gate "*` -- that *a* gate number is named, never that it
  is the *correct* one. `audit-tickets` printing "Gate 3" satisfied it exactly. This is the
  harvested SRD-audit pattern "an anti-regression assertion counts a hardcoded name list rather
  than the live set, so it stays green while newly added members silently escape the property it
  exists to enforce", recurring on a different surface.

  **Why it went unnoticed until now.** The Step 0 preflight and kernel gate enforcement are
  recent (EDMV3-T13); EDMV3's own Phase 5 predates them, and VERIF ran `lifecycle_mode=fix-pack`,
  which skips Phase 5. EDMV4 is the first standard-lifecycle initiative to reach the check.

  Discovered during this initiative's own Phase 5 preflight and scoped in at Gate 3 as an
  addition to the Gate-2-approved requirement set, per the change-control principle in
  `CLAUDE.md Sec."Unverifiable acceptance criteria (D15)"`.
- **Acceptance Criteria**:
  - [ ] `cmd_gate_check`'s `case` maps `audit-tickets` to `required_gate=2`, grouped with
        `tickets`, and `implement` retains `required_gate=3` on its own arm.
  - [ ] `edm-state gate-check <PREFIX> audit-tickets` exits 0 on an initiative whose Gate 2 is
        approved and Gate 3 is not.
  - [ ] `edm-state gate-check <PREFIX> implement` still exits 3 on that same initiative, proving
        the fix narrowed only the intended token and did not weaken Phase 6's gate.
  - [ ] The `Gated commands and their required gates` docstring above `cmd_gate_check` states the
        corrected mapping and records that a token names the gate a phase **consumes**, never the
        one it **produces**.
  - [ ] `bin/tests/wave6-smoke.sh`'s EDMV3-T13 AC3 loop pins every token to its exact expected
        gate number and fails on a wrong-but-present gate, not merely on an absent one.
  - [ ] A dedicated assertion states the producer/consumer invariant directly: neither
        `audit-srd` (presents Gate 2) nor `audit-tickets` (presents Gate 3) may require the gate
        it presents.
  - [ ] `bash bin/tests/run-all.sh` passes with zero failures after the change.
  - [ ] `CHANGELOG.md` records the fix as a user-visible bug fix, since it unblocks a phase that
        could not previously run.
- **Dependencies**: none. It blocks `EDMV4`'s own Phase 5 and every future standard-lifecycle
  initiative's Phase 5, so it is fixed before the ticket-pack audit runs rather than scheduled
  into an implementation wave.
- **Target Components**: `plugins/edm/bin/edm-state` (`cmd_gate_check` and its docstring),
  `plugins/edm/bin/tests/wave6-smoke.sh` (EDMV3-T13 AC3 block),
  `plugins/edm/CHANGELOG.md`.

---

### 6.2 Item 4.1 -- GateGuard fact-forcing edit gate

#### EDMV4-07: GateGuard is a bash `PreToolUse` gate scoped to `Edit` / `Write` / `MultiEdit`

- **Priority**: Must Have
- **Description**: Implement `bin/edm-gateguard` as a standalone bash script registered on a new
  `PreToolUse` matcher block covering `Edit`, `Write` and `MultiEdit`, active **only** while the
  project is in Phase 6. It is a rewrite, not a vendoring, per AD1: upstream `zunoworks/gateguard` is
  Python and ECC's copy is a JavaScript port, so neither offers a bash implementation to adopt, and
  both would add a runtime dependency this plugin has never had. The gate must never invoke
  `edm-state` on its common path -- `edm-state` is a roughly 6,300-line script paying a fresh parse
  plus at least one `jq` subprocess per invocation, and this hook fires tens to hundreds of times per
  Phase 6 wave, versus once per `git commit` for the only existing `PreToolUse` block.
- **Acceptance Criteria**:
  - [ ] `plugins/edm/bin/edm-gateguard` exists, is executable, and is between 200 and 400 lines
        (AD1's estimate is 250-350; the band allows for house boilerplate).
  - [ ] It sources `_edm-cli-lib.sh` and uses the sentinel-delimited `# EDM-HELP-BEGIN` /
        `# EDM-HELP-END` help block extracted by the shared `print_help`, never a hardcoded
        `sed -n 'A,Bp'` range -- the convention `edm-lint-artifacts:1-70` and
        `edm-compare-eval:2-33` both follow.
  - [ ] `hooks/hooks.json` gains exactly **one** new `PreToolUse` matcher block matching
        `Edit`, `Write` and `MultiEdit`, whose command is guarded by
        `command -v edm-gateguard >/dev/null 2>&1 || exit 0` before exec, mirroring the existing
        `git commit` block's guard at `hooks.json:86`.
  - [ ] The existing `git commit` matcher block (`hooks.json:80-90`) is **byte-identical** after the
        change. `git diff` on that hunk shows no modification.
  - [ ] The script contains **zero** invocations of `edm-state` (asserted by
        `grep -c 'edm-state' plugins/edm/bin/edm-gateguard` returning 0).
  - [ ] The script contains **no** destructive-`Bash` detection: no regex over shell commands, no
        heredoc stripping, no subshell explosion. `grep -ci 'destructive\|heredoc\|subshell'` returns
        0. (Contingent on `EDMV4-05` being accepted.)
  - [ ] The plugin's required-binary set is unchanged: `edm-gateguard` invokes only `bash` builtins,
        `jq`, and `stat`/`test`. No `node`, no `python`. Asserted by `EDMV4-56`.
  - [ ] **`jq` is a dependency only *after* the marker test passes** (AD3's qualifier). The script
        contains **no** top-of-script `require_jq`-style precondition check: a `command -v jq`
        guard, if present at all, sits below the marker test, so the allow path outside Phase 6
        never depends on `jq` being installed. A smoke assertion greps the script and fails if any
        `jq` reference appears before the marker `test -f`.
  - [ ] `bin/tests/wave8-smoke.sh` asserts the allow path spawns **zero** `jq` processes when the
        Phase-6 marker is absent, verified by running the script with `jq` moved off `PATH` and
        asserting exit 0.
- **Dependencies**: `EDMV4-01`, `EDMV4-02`, `EDMV4-08`, `EDMV4-59`. `EDMV4-05` must be resolved at
  Gate 2 before this is ticketed (it sets the scope), and `EDMV4-59` before that (it sets the
  implementation approach). **`EDMV4-09` is not a dependency**: it is the deny back-end living
  *inside* this script and therefore cannot precede the script's existence. v1.0.0 declared a mutual
  dependency between the two, which is a cycle and unschedulable. Every AC above is structural and
  independently completable without a working deny path.
- **Target Components**: `plugins/edm/bin/edm-gateguard` (new),
  `plugins/edm/hooks/hooks.json:80-90` (the block it sits beside),
  `plugins/edm/bin/_edm-cli-lib.sh`, `plugins/edm/bin/edm-lint-artifacts:1-70` (the help-sentinel
  precedent), `plugins/edm/bin/tests/wave8-smoke.sh` (new).

#### EDMV4-08: Phase-6-active marker primitive with SessionStart reconciliation

- **Priority**: Must Have
- **Description**: No cheap per-tool-call "which initiative is active" path exists today. The nearest
  primitives -- `cmd_active_initiatives` (`bin/edm-state:3900-3916`), `cmd_session_start`
  (`:4347` onward) and `cmd_checkpoint` (`:2735` onward, which additionally takes a write lock and
  computes SHA-256 over every tracked artifact) -- all run at SessionStart / Stop / PreCompact
  cadence, a handful of times per conversation. Running any of them per edit is the failure mode this
  requirement exists to avoid: at the 50-initiative fixture size `CLAUDE.md`'s own latency table
  already uses, the sweep is 50 `jq` invocations **per edit**. Build a marker file at a fixed,
  project-keyed path outside the repository, written when Phase 6 starts and removed when it ends,
  with SessionStart reconciliation as the self-healing path.
- **Acceptance Criteria**:
  - [ ] `plugins/edm/bin/_edm-datadir-lib.sh` exposes `edm_marker_path()`, printing
        `${data}/run/<project-key>.phase6`, computed with pure bash parameter expansion and **zero**
        subprocesses.
  - [ ] `cmd_phase_start` writes the marker when the phase being started is 6. A marker write failure
        warns on stderr and the phase transition still succeeds -- it must never fail a phase
        transition.
  - [ ] `cmd_phase_complete` removes the marker when the phase being completed is 6, **and only when
        the marker's recorded PREFIX matches the completing initiative** (so a second initiative
        completing Phase 6 does not clear a marker the first still needs).
  - [ ] `cmd_archive` and `cmd_skip_phase` remove the marker defensively.
  - [ ] `cmd_session_start` reconciles: if a marker exists but its named initiative is not at
        `current_phase == 6`, the marker is removed and one line of operator output says so. If no
        marker exists but some initiative *is* at phase 6, the marker is recreated.
  - [ ] The marker holds one line: `PREFIX<TAB>initiative_dir<TAB>started_at`.
  - [ ] The marker path is **outside** the repository. A smoke assertion verifies no marker file is
        ever created under `${EDM_SRD_ROOT}` or anywhere `git status --porcelain` would report it.
  - [ ] `edm_data_dir()` resolves `${CLAUDE_PLUGIN_DATA}` when absolute and creatable, then
        `${XDG_DATA_HOME}/edm` when `XDG_DATA_HOME` is absolute, then `${HOME}/.local/share/edm`,
        then prints an **empty string** when all three fail. A relative value at any step falls
        through with a stderr warning rather than erroring -- the three-step absolute-only pattern
        from `homunculus-dir.sh:1-31`.
  - [ ] When `edm_data_dir()` returns empty, `edm_marker_path()` returns empty and `edm-gateguard`
        treats that as "marker absent" and allows. Degradation is to today's behaviour (no gate at
        all), never to a deny.
  - [ ] `edm_project_key()` resolves `CLAUDE_PROJECT_DIR` when it names a directory, then
        `git rev-parse --show-toplevel`, then `pwd` -- the CA-448 precedent from
        `check_permission_rules` -- so a hook invoked from a subdirectory keys the same marker the
        `edm-state` writer created. Encoding replaces `/` and `.` with `-` in pure bash.
  - [ ] `bin/tests/wave8-smoke.sh` asserts marker create-on-`phase-start-6`,
        remove-on-`phase-complete-6`, remove-on-`archive`, PREFIX-mismatch non-removal, and
        SessionStart reconciliation in both directions.
- **Dependencies**: `EDMV4-13` (shares `_edm-datadir-lib.sh`).
- **Target Components**: `plugins/edm/bin/_edm-datadir-lib.sh` (new),
  `plugins/edm/bin/edm-state` `cmd_phase_start`, `cmd_phase_complete`, `cmd_archive:3096+`,
  `cmd_skip_phase`, `cmd_session_start:4347+`; `bin/edm-state:3900-3916` and `:2735+` (the two
  rejected alternatives, for the record); `bin/edm-state:307-312` (`session_dir_for_cwd`, the
  existing project-key encoding idiom); `plugins/edm/bin/tests/wave8-smoke.sh` (new).

#### EDMV4-09: One deny mechanism, two selectable back-ends, defaulted from Spike B

- **Priority**: Must Have
- **Description**: Per AD2, every refusal routes through a single `emit_decision deny|allow <reason>`
  function with two back-ends selected by `EDM_GATEGUARD_DENY_MODE`. This exists so Spike B's outcome
  flips a default constant and a smoke assertion rather than forcing a rewrite, and so the JSON --
  a response protocol this plugin's tooling has never reasoned about -- is emitted from exactly one
  place. The exit-code split must match the existing `edm-lint-staged-artifacts` convention exactly,
  because a divergent third convention on the same event is precisely the drift EDM's helper table
  exists to prevent.
- **Acceptance Criteria**:
  - [ ] All deny and allow decisions in `edm-gateguard` are emitted by one function. No `printf`,
        `echo` or `exit` producing a decision exists outside it, asserted by a smoke test grepping
        the script.
  - [ ] `EDM_GATEGUARD_DENY_MODE=json` (the default) prints exactly
        `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"<facts>"}}`
        on **stdout** and exits **0**.
  - [ ] `EDM_GATEGUARD_DENY_MODE=exit-code` prints the fact list on **stderr** and exits **2** -- the
        same code `edm-lint-staged-artifacts:7-10` already means "block".
  - [ ] Any other value of `EDM_GATEGUARD_DENY_MODE` is a setup error: warn on stderr naming both
        legal values, exit **1**, do not block.
  - [ ] Exit **1** is reserved for setup errors and **never blocks**, matching the CA-298 convention
        that a setup condition never blocks while a real refusal does.
  - [ ] The default value is set from `EDMV4-02`'s recorded decision, and the smoke suite asserts the
        default matches the decision (a constant and a test, so a silent revert fails).
  - [ ] `bin/tests/wave8-smoke.sh` pipes the emitted JSON through `jq -e
        '.hookSpecificOutput.permissionDecision == "deny"'` and fails on a malformed emission, so an
        unparseable payload is a test failure rather than a silently unenforced gate.
  - [ ] The `permissionDecisionReason` string is valid JSON: embedded newlines, quotes and
        backslashes in the fact list are escaped. A smoke test denies on a path containing a double
        quote and asserts the output still parses.
  - [ ] The emitted JSON is ASCII-only, and `bin/edm-check-vocabulary` passes over the new script.
- **Dependencies**: `EDMV4-02`, `EDMV4-07`. The direction is one-way: `emit_decision` lives inside
  `edm-gateguard`, so `EDMV4-07` must land first. `EDMV4-07` does **not** depend on this
  requirement.
- **Target Components**: `plugins/edm/bin/edm-gateguard` (new),
  `plugins/edm/bin/edm-lint-staged-artifacts:7-10,150-158` (the exit-code convention being matched),
  `plugins/edm/CLAUDE.md Sec."Hooks behavior"` (CA-298's exit-code contract),
  `plugins/edm/bin/tests/wave8-smoke.sh` (new).

#### EDMV4-10: Fact-forcing content, ticket-AC substitution, and per-file `MultiEdit` semantics

- **Priority**: Must Have
- **Description**: The gate's value is that the denial reason is a numbered list of facts the agent
  must produce, not a confirmation prompt -- asking a model "did you violate any policies" gets "no",
  but asking "list every file that imports this module" forces a `Grep` and a `Read`, and the context
  that investigation produces changes the output. EDM substitutes one fact for a better one it
  already has: instead of "quote the user's current instruction verbatim", demand the acceptance
  criteria of the ticket being implemented, by `{PREFIX}-T{NN}` ID, so the gate reinforces ticket
  traceability. `MultiEdit` is handled per-file: a batch with three unchecked files needs three
  retries, not one (`gateguard-fact-force.js:1234-1256`; correction 10).
- **Acceptance Criteria**:
  - [ ] An `Edit` denial emits four numbered facts: (1) list all files that import or require this
        file, searching the tree; (2) list the public functions or classes affected by this change;
        (3) if this file reads or writes data files, show field names, structure and date format
        using redacted or synthetic values, never raw production data; (4) quote the acceptance
        criteria of the ticket being implemented, by `{PREFIX}-T{NN}` ID.
  - [ ] A `Write` (new file) denial swaps facts 1 and 2 for: name the file(s) and line(s) that will
        call this new file, and confirm no existing file already serves the same purpose. Facts 3
        and 4 are unchanged.
  - [ ] Fact 4 is the ticket-AC form in both variants. The string "quote the user's current
        instruction" does not appear in the script.
  - [ ] `MultiEdit` iterates the batch and denies on the **first still-unchecked** `file_path`,
        returning immediately. A smoke test with a three-file batch, all unchecked, asserts three
        successive denials and an allow on the fourth call.
  - [ ] A `MultiEdit` batch where all files are already checked allows on the first call.
  - [ ] The denial text is plain ASCII with no em dashes, arrows, smart quotes or emoji
        (`EDMV4-57`).
  - [ ] No text is copied verbatim from `gateguard-fact-force.js` or `skills/gateguard/SKILL.md`. The
        fact list is re-expressed in EDM's own register, consistent with the clean-room posture
        recorded in `CLAUDE.md Sec."Prompt conventions (house style)"` for `caveman` and `ponytail`.
  - [ ] `bin/tests/wave8-smoke.sh` asserts each of the four `Edit` facts and each of the two swapped
        `Write` facts appears in the corresponding denial output.
- **Dependencies**: `EDMV4-07`, `EDMV4-09`.
- **Target Components**: `plugins/edm/bin/edm-gateguard` (new),
  `plugins/edm/bin/tests/wave8-smoke.sh` (new),
  `plugins/edm/CLAUDE.md Sec."Prompt conventions (house style)"`; behaviour source
  `gateguard-fact-force.js:1062-1076` (Edit facts), `:1078-1092` (Write facts), `:1234-1256`
  (MultiEdit per-file loop) -- read for mechanism, not copied.

#### EDMV4-11: Operational safety controls -- kill switches, exemptions, fail-open, denial budget

- **Priority**: Must Have
- **Description**: The graduated controls are what make a per-edit gate safe to ship: each narrows one
  behaviour while leaving the load-bearing checks running, and every state-write failure path allows
  rather than looping. A gate that cannot record what it has already asked would otherwise deny the
  same edit forever. Two independent kill switches travel, not one -- the source analysis's table
  omits `GATEGUARD_DISABLED=1` (correction 9, `gateguard-fact-force.js:732-734`). ECC's exempt-glob
  matcher has a documented gotcha this implementation fixes rather than inherits: an unanchored
  substring regex means `**/tests/**` matches `/repo/tests/x.js` but not the bare relative
  `tests/x.js`, so ECC's own skill doc tells users to list both forms.
- **Acceptance Criteria**:
  - [ ] `EDM_GATEGUARD` set to any of `0`, `false`, `off`, `disabled` or `disable` exits 0 before
        anything else runs. A smoke test asserts each of the five spellings.
  - [ ] `EDM_GATEGUARD_DISABLED=1` independently exits 0 before anything else runs. It recognizes the
        literal `1` only, matching the upstream contract.
  - [ ] With either kill switch engaged, the script performs **zero** filesystem reads beyond its own
        environment: no marker `stat`, no session-state read.
  - [ ] `EDM_GATEGUARD_EXEMPT_GLOBS` is a comma-separated glob list. Each entry is tested with bash
        `case` pattern matching against **both** the absolute path and the repository-relative path,
        so a single `**/tests/**` entry covers `/repo/tests/x.js` and bare `tests/x.js`. A smoke test
        asserts both forms match from one entry -- the explicit fix for the ECC gotcha.
  - [ ] The shipped default `EDM_GATEGUARD_EXEMPT_GLOBS` covers the `SRD/` artifact tree ("who imports
        this markdown file" carries no signal), common test trees, and generated output.
  - [ ] Session state lives at `${data}/run/<project-key>.checked`, is capped at **500** entries
        (oldest pruned first), and is treated as empty and truncated when its mtime is older than
        **30 minutes**.
  - [ ] Every state-write failure path **allows** with a stderr warning naming
        `EDM_GATEGUARD_STATE_DIR`. A smoke test makes the data directory read-only and asserts exit 0
        with the warning, not a deny.
  - [ ] `EDM_GATEGUARD_MAX_DENIALS` (default **3**) bounds full denials per session; past the budget
        the gate degrades to a stderr advisory and allows, so a pathological loop cannot wedge a
        wave.
  - [ ] `jq` missing exits **1** (setup error, non-blocking) per the CA-298 convention, never 2 --
        **but only on the gated path.** Per AD3, `jq` becomes a dependency only after the marker
        test passes, so with the marker absent a missing `jq` is not a setup error at all: the
        script exits **0** having never referenced `jq`. The two cases are asserted separately by
        smoke tests, and the distinction is stated in the script's help block, because "`jq` missing
        exits 1" read unqualified contradicts `EDMV4-07`'s zero-`jq` allow-path guarantee.
  - [ ] An unparseable stdin payload exits **1** with a stderr diagnostic, never blocks.
  - [ ] A marker present whose named initiative directory no longer exists (branch switch,
        `git clean`) allows; SessionStart reconciliation removes the marker on the next session.
  - [ ] Every environment variable introduced here is documented in
        `plugins/edm/CLAUDE.md`, in the same form as the existing `EDM_RUN_ALL_*` / `EDM_EVAL_*`
        knob families, including its default and its unset-equals-prior-behaviour property.
- **Dependencies**: `EDMV4-07`, `EDMV4-08`, `EDMV4-09`.
- **Target Components**: `plugins/edm/bin/edm-gateguard` (new),
  `plugins/edm/bin/_edm-datadir-lib.sh` (new),
  `plugins/edm/CLAUDE.md Sec."Testing changes"` (the knob-family documentation pattern),
  `plugins/edm/bin/tests/wave8-smoke.sh` (new); behaviour source `gateguard-fact-force.js:732-734`
  (both kill switches), `:117-134` (the glob gotcha), `:806-819` (the 500-entry prune), line 36
  (the 30-minute timeout), `:1176-1181` (fail-open), `:904-912` (the denial budget).

#### EDMV4-12: Record ECC and GateGuard provenance in the house-style attribution section

- **Priority**: Should Have
- **Description**: `CLAUDE.md Sec."Prompt conventions (house style)"` is this plugin's established
  form for recording borrowed material: source, URL, licence, and the **means of verification**, with
  a clean-room note stating what was actually adopted. Both licences are permissive and verified --
  ECC is MIT (`ECC/LICENSE:1-3`, Affaan Mustafa 2026, verified by direct inspection of the local
  clone) and `zunoworks/gateguard` is MIT (Hirokazu Seto / ZUNO WORKS K.K. 2026, verified by direct
  inspection of its `LICENSE`, decisions.md D13). Under AD1 what carries over is the *concept* --
  deny first touch, demand facts, allow on retry -- which is pattern-level adoption matching the
  posture already recorded for `caveman` and `ponytail`, not verbatim reuse. This is therefore house
  convention rather than a strict licence compulsion, which is why it is Should Have.

  **The trigger that revives the strict obligation is an AD1 reversal to vendoring, by any route.**
  That is what `decisions.md` D13 states, and it is the only correct formulation: the obligation
  binds on *verbatim reuse*, and only vendoring produces verbatim reuse. `EDMV4-59` is the
  requirement that presents AD1 for ratification and is therefore the requirement this clause is
  wired to. It is explicitly **not** wired to `EDMV4-05` -- rejecting `EDMV4-05` yields a *larger
  bash rewrite*, not a vendoring, so an `EDMV4-05` rejection revives nothing. v1.0.0 wired it to
  `EDMV4-05`, which meant a Gate 2 that approved `EDMV4-05` while separately directing vendoring
  would have left the obligation dormant with nothing to wake it.
- **Acceptance Criteria**:
  - [ ] `plugins/edm/CLAUDE.md Sec."Prompt conventions (house style)"` gains an entry for **ECC**
        (`everything-claude-code`, `github.com/affaan-m/everything-claude-code`, MIT, verified
        2026-08-30 by direct inspection of `ECC/LICENSE:1-3` in the local clone at
        `/Users/darryl.porter/projects/ECC`, revision `19e2f2b4`).
  - [ ] The same section gains an entry for **GateGuard** (`github.com/zunoworks/gateguard`, MIT,
        "Copyright (c) 2026 Hirokazu Seto / ZUNO WORKS K.K.", verified 2026-08-30 by direct
        inspection of its `LICENSE`), noting that ECC vendored a JavaScript port
        (`gateguard-fact-force.js:19-20`, `skills/gateguard/SKILL.md:5` marking
        `metadata: origin: community`) and that upstream is Python.
  - [ ] Both entries carry a clean-room note in the existing form, stating that the adoption is
        mechanism-level (deny first touch, demand facts, allow on retry) and that **no text was
        copied** from either source.
  - [ ] The entries state the means of verification explicitly, as the `caveman` and `ponytail`
        entries do -- a URL alone is not sufficient.
  - [ ] The section's existing four-source enumeration is updated to match the new count so the
        prose and the list do not disagree.
  - [ ] A smoke assertion in `bin/tests/wave8-smoke.sh` verifies both `zunoworks` and `MIT` appear in
        that section, so a later edit cannot silently drop the attribution.
  - [ ] **Dormant clause -- trigger stated once, here.** If **AD1 is reversed to vendoring, by any
        route** (`EDMV4-59` rejected at Gate 2, or any later decision that directs vendoring), this
        requirement is re-raised to **Must Have** and three things bind: the vendored files retain
        their original copyright headers unmodified; `plugins/edm/NOTICE` (new) names ZUNO WORKS
        K.K. and Affaan Mustafa with their MIT texts; and `EDMV4-56`'s required-binary set is
        re-presented at the gate as an explicit dependency addition. The clause is dormant unless
        and until AD1 is reversed, and no other requirement's outcome revives it.
- **Dependencies**: `EDMV4-59` (its outcome sets this requirement's priority).
- **Target Components**: `plugins/edm/CLAUDE.md Sec."Prompt conventions (house style)"`,
  `plugins/edm/bin/tests/wave8-smoke.sh` (new); evidence `ECC/LICENSE:1-3`,
  `gateguard-fact-force.js:19-20`, `ECC/skills/gateguard/SKILL.md:5`,
  `SRD/edm/EDMV4__ecc-integration/decisions.md` (D13).

---

### 6.3 Item 4.2 -- the `update-patterns` read-only-install defect

#### EDMV4-13: Shared data-directory resolver, the first `${CLAUDE_PLUGIN_DATA}` consumer in `bin/`

- **Priority**: Must Have
- **Description**: `${CLAUDE_PLUGIN_DATA}` appears **zero times in any executable script** in this
  plugin -- two prose references only, `CLAUDE.md` (the reservation rule) and the analysis document.
  There is no existing resolution pattern in `bin/` to copy. Both 4.1's marker and 4.2's harvested
  pattern delta need a writable, plugin-owned, outside-the-repository directory, so per AD3 one
  library owns the whole question rather than each consumer inventing its own chain.

  **Consumer set, resolved.** `architecture.md` is internally inconsistent here: its AD3 prose
  (`:97`) names `edm-state`, `edm-gateguard` **and** `edm-hookify` as sourcing consumers, while its
  own component table (`:213`) omits `_edm-datadir-lib.sh` from `edm-hookify`'s dependency list.
  The table is right and the prose is wrong. **`edm-hookify` does not need the data directory**: its
  rule files live at `.claude/edm-hookify/*.json`, project-relative and source-controlled per D7 and
  `CLAUDE.md` rule 3, and it writes nothing (`EDMV4-41` requires it be read-only). Sourcing a
  resolver it never calls would add startup cost to a path `edm-gateguard` invokes per edit.
  **Decision: two sourcing consumers, `edm-state` and `edm-gateguard`.** `architecture.md:97` is
  amended to match.

  **Scope of this requirement.** It delivers the library and its own coverage, and nothing else.
  Assertions about a *consumer* sourcing it belong to the requirement that builds that consumer,
  because neither consumer exists when this lands: `edm-gateguard`'s sourcing is asserted by
  `EDMV4-07`, and `edm-state`'s by `EDMV4-08` (the marker producers). v1.0.0's AC1 asserted that
  `edm-gateguard` and `edm-hookify` source the library, which cannot be verified at this
  requirement's own completion.
- **Acceptance Criteria**:
  - [ ] `plugins/edm/bin/_edm-datadir-lib.sh` exists, is syntactically valid under bash 3.2
        (`bash -n` passes under `/bin/bash`), and is sourceable standalone: sourcing it in a fresh
        shell defines `edm_data_dir`, `edm_project_key` and `edm_marker_path` and exits 0, with no
        side effects and no output.
  - [ ] `bin/edm-state` sources it, and the sourcing is guarded so a missing library degrades
        `edm-state` to today's behaviour rather than failing every subcommand.
  - [ ] The library defines **only** those three functions plus any strictly-internal helpers, and
        declares no variables in the global namespace that could collide with `edm-state`'s own.
        A smoke test sources it inside a scratch shell alongside `edm-state`'s constant block and
        asserts no redefinition.
  - [ ] `edm_data_dir()` resolution order and fall-through behaviour are exactly as specified in
        `EDMV4-08`, including the empty-string terminal case.
  - [ ] Two subdirectories are created on demand and never conflated: `${data}/patterns/` (durable
        harvested deltas) and `${data}/run/` (ephemeral markers and session state).
  - [ ] The library is bash 3.2 compatible: no associative arrays, no `${var^^}`, no `mapfile`, no
        process substitution in a loop condition (the CA-472 fd-leak class).
  - [ ] The library spawns **zero** subprocesses on the `edm_data_dir()` and `edm_marker_path()`
        paths. `edm_project_key()` may spawn `git rev-parse` only when `CLAUDE_PROJECT_DIR` is unset
        or does not name a directory.
  - [ ] A smoke test exercises all four `edm_data_dir()` branches by manipulating
        `CLAUDE_PLUGIN_DATA`, `XDG_DATA_HOME` and `HOME`, including the relative-value fall-through
        and the all-fail empty-string case.
  - [ ] A smoke test asserts that with `CLAUDE_PLUGIN_DATA` unset the resolver never writes anything
        inside the repository working tree (`git status --porcelain` stays empty).
  - [ ] `plugins/edm/CLAUDE.md`'s `bin/` helper table gains a row for `_edm-datadir-lib.sh`, and
        `architecture.md` AD3's prose is amended to name two sourcing consumers, not three.
- **Dependencies**: none. (v1.0.0 declared `EDMV4-03`; per D4 as amended the branch residual blocks
  nothing.)
- **Target Components**: `plugins/edm/bin/_edm-datadir-lib.sh` (new),
  `plugins/edm/bin/edm-state`, `plugins/edm/CLAUDE.md:71` (the reservation prose that is currently
  the only reference), `plugins/edm/CLAUDE.md Sec."bin/ helper scripts"`,
  `plugins/edm/bin/tests/wave8-smoke.sh` (new); structural source
  `ECC/skills/continuous-learning-v2/scripts/lib/homunculus-dir.sh:1-31` (31 lines, MIT).

#### EDMV4-14: The 4.2 fix -- writable harvested delta, `get-patterns` read side, one commit

- **Priority**: Must Have
- **Scope note**: this requirement **absorbs `EDMV4-15` (read side) and `EDMV4-16` (single-commit
  coupling)**. v1.0.0 split them three ways and produced two dependency cycles
  (`14 -> 16 -> 14` and `15 -> 16 -> 15`), which either deadlocks Phase 4's dependency-ordered wave
  scheduler or is silently broken by whatever topologically sorts it -- and the constraint most
  likely to be dropped in that break is `EDMV4-16`'s single-commit guarantee, the only thing
  preventing silent loss of all harvested content. It was also unenforceable by construction: "no
  intermediate commit leaves the write side landed and the read side not" cannot be asserted across
  two tickets in two waves. One requirement, one ticket, one commit. `EDMV4-15` and `EDMV4-16`
  remain as merged pointers so existing cross-references still resolve.
- **Description**: `cmd_update_patterns` computes its write target as
  `local patterns_dir="${SCRIPT_DIR}/../docs/audit-patterns"` (`bin/edm-state:5595`) -- inside the
  plugin's own installed tree. On any plugin-cache install that directory is not writable, so
  `[[ ! -w "$pattern_dir" ]]` at `:5627` is true, the function warns to stderr and `return 0`s. The
  skip is deliberate and graceful (never `die`s, never aborts the phase), and the comment shows the
  author anticipated read-only installs; what was never followed through is where the data should go
  instead. The consequence is that **EDM's pattern library only ever grows for people running the
  plugin from a checkout of this repository**; for every installed user the learning loop is a no-op
  that logs to stderr and returns success. The shipped `docs/audit-patterns/*.md` become a read-only
  seed and the harvested delta becomes a separate file, created as a **stub** carrying only the
  Living-Library contract headings plus a provenance line -- never a copy of the seed -- so seed and
  delta are disjoint by construction and concatenation cannot double-count an entry.

  **The read side is the other half of the same change.** Four agents read the pattern library
  today, each doing one `Read` of one file and each resolving "the plugin root" itself with **no
  concrete mechanism named anywhere** -- no env var, no `bin/` helper, nothing like
  `CLAUDE_PLUGIN_ROOT`. `edm-implementer.md:19` states it most explicitly ("Resolve the plugin root
  before reading these files... If a referenced file cannot be resolved there, stop and report the
  blocker"), the same unresolvable-reference class D22 documents for `CLAUDE.md Sec."..."`
  references. Per AD6 the fix is **route (c)**: `edm-state get-patterns <type> --paths` prints the
  two resolved absolute paths, seed first and delta second, the launching skill interpolates both
  into the agent launch template, and the agents do two ordinary `Read`s. **Route (b) -- agents
  calling the subcommand themselves -- is blocked**, because `agents/edm-srd-writer.md:8` and
  `agents/edm-ticket-writer.md:7` have **no `Bash` grant**, and granting `Bash` to two writer agents
  to read a documentation file is a disproportionate widening of a deliberately narrow tool surface.
  Route (a) -- four agents each merging by their own rule -- is the duplicated-logic class the
  Append Schema and the D6 guard both exist to prevent.

  **Why the two sides cannot be separated.** A seed-only read against a delta-only write **silently
  loses all harvested content**, and the loss is invisible because `update-patterns` reports success
  on every append. Both halves individually pass their own tests; the failure surfaces only as a
  pattern library that stops growing, which nobody notices. That is the single most dangerous
  sequencing hazard in the initiative, and it is why this is one requirement rather than three.
- **Acceptance Criteria**:

  *Write side (absorbed from the original `EDMV4-14`).*
  - [ ] `cmd_update_patterns` resolves its write target via `edm_data_dir()` to
        `${data}/patterns/{srd,ticket,qc,code,test-coverage}-audit.md`.
  - [ ] On first write for a given audit type, the delta file is created as a stub containing only
        the Living-Library contract headings that `docs/audit-patterns/README.md` defines, plus a
        one-line provenance record. It contains **no** copy of the seed's content, asserted by a
        smoke test comparing the stub against the seed and requiring zero shared finding entries.
  - [ ] De-duplication runs against **both** the seed's headings and the delta's headings, so a
        finding already present in the shipped seed is never re-appended to the delta.
  - [ ] Degradation is strictly additive and preserves both existing behaviours in order: try the
        data directory; if unresolvable, try the shipped tree when writable (today's behaviour); if
        neither, warn to stderr and `return 0` (today's behaviour). A smoke test asserts each of the
        three branches, and asserts the phase is never aborted in any of them.
  - [ ] The fence-aware insertion-target resolution at `bin/edm-state:5649-5658` is preserved
        unchanged, including its two distinct outcomes: heading genuinely absent is a clean skip,
        heading present only inside a fence is a loud refusal (the G16 / CA-355 fix).
  - [ ] `${data}/patterns/harvest-provenance.json` records a write count and a first-write timestamp,
        so the R3 exposure -- a plugin upgrade silently clearing the delta while `update-patterns`
        keeps reporting successful appends -- has an observable signature.
  - [ ] `edm-state validate` gains an **informational** anomaly when the shipped seed's mtime is
        newer than the delta's recorded first-write timestamp. It is informational, never blocking:
        it never flips `validate`'s exit code.
  - [ ] `patterns_updates` continues to be recorded in `.edm-state.json` on every successful splice,
        with the same shape as today.
  - [ ] `plugins/edm/CLAUDE.md`'s state-field table gains a row for the new anomaly, stating its
        C-4 absent behaviour.

  *Read side (absorbed from `EDMV4-15`).*
  - [ ] `edm-state get-patterns <type> --paths` prints exactly two lines: the seed's absolute path,
        then the delta's absolute path. Both are absolute; neither is plugin-root-relative.
  - [ ] When the delta does not exist or the data directory is unresolvable, the second line is
        **empty** rather than absent, so a consumer can distinguish "no delta" from a truncated
        read. The contract is documented in the subcommand's help block.
  - [ ] `<type>` is validated against the existing `PATTERN_AUDIT_TYPE_ENUM_LIST` using the same
        word-membership idiom, not a re-encoded literal list.
  - [ ] The four launching skills call `get-patterns --paths` and interpolate both paths into their
        agent launch templates.
  - [ ] The four reading agents are updated to `Read` two explicit absolute paths, in order, seed
        first. Each carries one sentence on merge order referencing
        `docs/audit-patterns/README.md`, and none carries its own de-duplication rule.
  - [ ] **No agent gains a new tool grant.** `agents/edm-srd-writer.md` and
        `agents/edm-ticket-writer.md` still have no `Bash` grant after the change, asserted by
        `bin/edm-check-grants`.
  - [ ] An agent handed an empty second path reads only the seed and proceeds normally, with no
        error and no warning. A smoke test asserts this.
  - [ ] `bin/edm-check-grants` gains an assertion that every skill launch template spawning one of
        the four pattern-reading agents carries both interpolated paths, closing the R8 risk that a
        skill edit silently leaves an agent reading nothing.
  - [ ] `plugins/edm/CLAUDE.md`'s `bin/` helper table lists `get-patterns` among `edm-state`'s
        subcommands, and the stated subcommand count is updated from 39 to 40.

  *Coupling (absorbed from `EDMV4-16`).*
  - [ ] **One commit** contains all of: the `cmd_update_patterns` write-target change, the seed-stub
        creation, the `get-patterns` subcommand, the four agent read-site edits, and the four
        launching-skill interpolation edits.
  - [ ] **Phase 4 emits exactly one ticket covering this requirement.** The ticket-pack coverage map
        shows `EDMV4-14`, `EDMV4-15` and `EDMV4-16` all mapped to that single ticket ID, and the
        ticket-pack audit fails if the requirement is split across two tickets or two waves. This is
        the mechanically checkable form of the single-commit constraint -- the reason 14/15/16 are
        one requirement rather than three.
  - [ ] An end-to-end smoke test in one process: run `update-patterns` against a fixture audit
        report with the shipped tree made read-only, then run `get-patterns --paths`, then read both
        paths, and assert the harvested finding is present in the concatenation. This test fails if
        either half is missing.
  - [ ] A negative test asserts the failure mode explicitly: with the write side applied and the
        read side reverted, the harvested finding is **absent** from what an agent would read. This
        test exists to document why the coupling is mandatory, and is retained.
  - [ ] The ticket states the single-commit constraint in its own text so a later editor cannot
        split it.
- **Dependencies**: `EDMV4-13`. (v1.0.0 additionally listed `EDMV4-16`, which was a cycle:
  `EDMV4-16` was a constraint *on* this work, not a peer of it. It is now absorbed here.)
- **Target Components**: `plugins/edm/bin/edm-state:5581-5604` (`cmd_update_patterns`, `patterns_dir`
  at `:5595`), `:5625-5630` (the read-only skip branch), `:5649-5658` (the fence-aware pre-flight),
  `:5527` (`_cmd_update_patterns_body`), `plugins/edm/bin/edm-state` (new `get-patterns` arm;
  dispatch `case` at `:6239+`, currently 39 arms), `bin/edm-state:813-814`
  (`PATTERN_AUDIT_TYPE_ENUM_LIST`), `plugins/edm/docs/audit-patterns/README.md`
  (the Living-Library contract and Append Schema),
  `plugins/edm/docs/audit-patterns/{srd,ticket,qc,code,test-coverage}-audit.md` (the five seeds),
  `plugins/edm/agents/edm-srd-writer.md:25` and `:8` (no `Bash` grant),
  `plugins/edm/agents/edm-ticket-writer.md:32` and `:7` (no `Bash` grant),
  `plugins/edm/agents/edm-implementer.md:19,24-25`,
  `plugins/edm/agents/edm-test-coverage-auditor.md:40-42`,
  `plugins/edm/skills/{srd,tickets,implement,test-coverage}/SKILL.md` (launch templates),
  `plugins/edm/bin/edm-check-grants`,
  `plugins/edm/CLAUDE.md Sec."bin/ helper scripts"`,
  `plugins/edm/CLAUDE.md Sec.".edm-state.json mode-family fields"`,
  `plugins/edm/bin/tests/wave8-smoke.sh` (new, the end-to-end and negative tests).

#### EDMV4-15: MERGED into `EDMV4-14`

- **Status**: **Merged.** This ID carries no independent priority and no independent acceptance
  criteria. The read side -- `edm-state get-patterns <type> --paths`, the four launching-skill
  interpolations, the four agent read-site edits, the no-new-grant assertion and the
  `edm-check-grants` launch-template check -- is now the *Read side* AC block of **`EDMV4-14`**.
- **Why merged**: v1.0.0 made `EDMV4-15` depend on `EDMV4-16` while `EDMV4-16` depended on
  `EDMV4-15`, a cycle that Phase 4's dependency-ordered wave scheduler cannot resolve. More
  substantively, the read side and the write side must land in a single commit or all harvested
  content is silently lost, and that constraint is unenforceable across two tickets in two waves.
  One requirement produces one ticket produces one commit.
- **ID retained, not reused.** `EDMV4-15` is never reassigned to different work. Existing
  cross-references (Sec.5.1 AD6, Sec.10 R8, Sec.12) are redirected to `EDMV4-14`.
- **Dependencies**: none -- merged. See `EDMV4-14`.
- **Target Components**: none -- merged. See `EDMV4-14`.

#### EDMV4-16: MERGED into `EDMV4-14`

- **Status**: **Merged.** This ID carries no independent priority and no independent acceptance
  criteria. The single-commit coupling -- the one-commit requirement, the one-ticket ticket-pack
  assertion, the end-to-end test and the retained negative test -- is now the *Coupling* AC block of
  **`EDMV4-14`**.
- **Why merged**: `EDMV4-16` was a constraint *on* the 4.2 work, not a peer of it, and v1.0.0 wired
  it as a peer in both directions (`14 -> 16 -> 14` and `15 -> 16 -> 15`). A dependency-ordered
  scheduler either deadlocks on that or silently breaks it, and the constraint most likely to be
  dropped in the break is precisely this one -- the only thing preventing silent loss of all
  harvested pattern content. Its own AC ("no intermediate commit leaves the write side landed and
  the read side not") was also unenforceable across two tickets in two waves by construction.
  Folding it into `EDMV4-14` makes it enforceable, and `EDMV4-14`'s Coupling block adds a
  mechanically checkable form: the ticket-pack coverage map must show all three IDs mapped to one
  ticket.
- **ID retained, not reused.** Existing cross-references (Sec.10 R9, Sec.12.2) are redirected to
  `EDMV4-14`.
- **Dependencies**: none -- merged. See `EDMV4-14`.
- **Target Components**: none -- merged. See `EDMV4-14`.

#### EDMV4-17: Correct the stale caller-count comment at `bin/edm-state:5672`

- **Priority**: Should Have
- **Description**: The comment at `bin/edm-state:5672` reads "update-patterns is called mid-phase by
  four skills". The verified count is **six**. This is a small standalone doc-accuracy fix, distinct
  from the read-only-path defect itself, and it belongs in the same change so the file's own comment
  does not keep asserting a number the tree contradicts.
- **Acceptance Criteria**:
  - [ ] The comment names six call sites, or is reworded to avoid carrying a maintained count at all
        (the more durable option, since a count in a comment drifts).
  - [ ] The six verified call sites are `skills/implement/SKILL.md:46`,
        `skills/code-audit/SKILL.md:135`, `skills/audit-tickets/SKILL.md:52`,
        `skills/audit-srd/SKILL.md:50`, `skills/test/SKILL.md:132`,
        `skills/test-coverage/SKILL.md:65`.
  - [ ] The comment's substantive point is preserved unchanged: neither "nothing harvested" outcome
        is a `die`, because aborting a phase over a report-format gap would be worse than the gap
        (CA-476).
  - [ ] `plugins/edm/docs/ecc-integration-analysis.md`'s own "called mid-phase by four skills" claim
        is corrected as part of `EDMV4-54`.
- **Dependencies**: `EDMV4-14`.
- **Target Components**: `plugins/edm/bin/edm-state:5668-5673`,
  `plugins/edm/skills/implement/SKILL.md:46`, `plugins/edm/skills/code-audit/SKILL.md:135`,
  `plugins/edm/skills/audit-tickets/SKILL.md:52`, `plugins/edm/skills/audit-srd/SKILL.md:50`,
  `plugins/edm/skills/test/SKILL.md:132`, `plugins/edm/skills/test-coverage/SKILL.md:65`.

#### EDMV4-18: Regression coverage for the 4.2 change

- **Priority**: Must Have
- **Description**: There is no CI pipeline; `bin/tests/run-all.sh` plus the git-commit hook are the
  entire enforcement surface. Every branch of the new write path and read path needs an assertion, or
  a future edit reverts one silently.
- **Acceptance Criteria**:
  - [ ] A smoke test asserts the writable-data-directory path: the delta is created, the stub carries
        the Living-Library headings, and the finding is spliced under the correct insertion target.
  - [ ] A smoke test asserts the shipped-tree-writable fallback produces today's exact behaviour.
  - [ ] A smoke test asserts the all-unwritable path warns on stderr, exits 0, and appends nothing.
  - [ ] A smoke test asserts de-duplication against the seed: a finding whose title already exists in
        the shipped seed is not appended to the delta.
  - [ ] A smoke test asserts de-duplication against the delta: running `update-patterns` twice on the
        same report appends the finding once.
  - [ ] A smoke test asserts `get-patterns --paths` prints two lines with an empty second line when
        no delta exists.
  - [ ] A smoke test asserts the fence-aware refusal still fires when the target heading exists only
        inside a fenced code block.
  - [ ] All new tests are registered in a suite `bin/tests/run-all.sh` discovers, and
        `bash plugins/edm/bin/tests/run-all.sh` passes.
- **Dependencies**: `EDMV4-14` (which now carries the write side, the read side and the coupling;
  `EDMV4-15` and `EDMV4-16` are merged into it).
- **Target Components**: `plugins/edm/bin/tests/wave8-smoke.sh` (new),
  `plugins/edm/bin/tests/run-all.sh`, `plugins/edm/bin/tests/fixtures/` (new pattern fixtures).

---

### 6.4 Item 4.3 -- orchestrator size classifier

#### EDMV4-19: Add a size-classifier pre-step to the orchestrator's mode dialog

- **Priority**: Must Have
- **Description**: EDM already has the *destinations* -- five `mode` values and three `lifecycle_mode`
  values which between them can collapse the six phases down to a single ticket-pack review gate.
  What EDM lacks is the *routing*: the user must already know `lifecycle_mode=fix-pack` exists and set
  it by hand, so someone arriving with a 20-line bug fix and no prior EDM knowledge gets the full
  six-phase flow by default. Add a classifier as a new Step 1b.5, immediately after prefix and
  product resolution and before the existing Step 1c mode dialog, which scores three signals, takes
  the highest tier any one signal reaches, and **pre-selects** the resulting recommendation as the
  "(Recommended)" annotation on the existing `AskUserQuestion`. Note that the premise -- that the
  default costs EDM anything in practice -- is **unmeasured**; the analysis says so itself, and the
  argument is structural only.

  **The orchestrator has no `lifecycle_mode` write path, and a `fix-pack` recommendation needs
  one.** v1.0.0 claimed the classifier "adds no new dialog and no new UI mechanism". That is false
  as written. Step 1c.1 offers **`mode` values only** -- Standard / mini-SRD / IaC / Data-ML /
  Prototype (`skills/orchestrator/SKILL.md:107-108`) -- and Step 1c.3 records exactly two things,
  `set-mode <PREFIX> mode <value>` and `set-mode <PREFIX> compliance_enabled true`
  (`:111-112`). **`lifecycle_mode` is never written by the orchestrator at any step.** But
  `fix-pack` is a `lifecycle_mode` value, so a `fix-pack` recommendation has no option to annotate
  and no path to record. This requirement resolves that rather than asserting it away: a
  `lifecycle_mode` option is added to the dialog and a `set-mode <PREFIX> lifecycle_mode <value>`
  call is added to the recording step. The alternative -- restricting the classifier to the values
  Step 1c.1 already offers -- would delete the `fix-pack` tier, which is the classifier's whole
  reason for existing (the user who does not know `fix-pack` exists is the user this feature is
  for).
- **Acceptance Criteria**:
  - [ ] **The dialog gains a `lifecycle_mode` question.** Step 1c presents lifecycle selection --
        Standard / fast-track / fix-pack -- alongside the existing mode question, following the
        same `AskUserQuestion` form and the same `<=12`-character header constraint. It carries a
        "(Recommended)" annotation set by Step 1b.5, exactly as the mode question does.
  - [ ] **Step 1c's recording step gains a `lifecycle_mode` write.**
        `edm-state set-mode <PREFIX> lifecycle_mode <value>` is called alongside the existing
        `set-mode <PREFIX> mode <value>`, and is called only when the selected value is not the
        `standard` default, matching how `compliance_enabled` is recorded only when On.
  - [ ] Both new writes go through `cmd_set_mode` and are validated by its existing hard refusal.
        No second write path for either field is introduced (`EDMV4-20`).
  - [ ] The new question is **skipped on resume**, matching Step 1c's existing behaviour. The resume
        branch at `skills/orchestrator/SKILL.md:90-95` already reads all four mode-family fields
        including `lifecycle_mode` and already states which lifecycle applies, so the read side
        needs no change -- only the write side is missing today.
  - [ ] `skills/orchestrator/SKILL.md` gains a Step 1b.5 that runs before Step 1c and is skipped on
        resume, matching Step 1c's own resume behaviour.
  - [ ] The classifier scores exactly three signals: files touched, new dependency or contract, and
        design ambiguity. The **highest** tier any single signal reaches wins; it is not an average.
  - [ ] The computed recommendation is stated in **one line** with its reasoning, in the
        `AskUserQuestion` body, so the user sees why.
  - [ ] The recommendation sets which existing option carries the "(Recommended)" annotation. It
        never auto-applies a mode: the user still confirms or overrides via the existing dialog.
  - [ ] An override is always available and is recorded. The classifier is a default, not an
        enforcement.
  - [ ] Whatever the user selects is recorded through the existing `edm-state set-mode <PREFIX>
        mode|lifecycle_mode <value>` path. The classifier introduces no second write path for mode.
  - [ ] **The classifier's output shape is a `(mode, lifecycle_mode)` pair, and the three tiers are
        enumerated literally.** Exactly three pairs are emitted, and no others:
    - trivial tier -> `(mode=standard, lifecycle_mode=fix-pack)`
    - small tier -> `(mode=mini-srd, lifecycle_mode=standard)`
    - full tier -> `(mode=standard, lifecycle_mode=standard)`

        Both members of the pair are always stated, because the two enum families are orthogonal and
        every initiative carries a value from each. This is the single output shape for this
        initiative: v1.0.0 described "three single values" here and a "(mode, lifecycle_mode) pair
        per tier" in `EDMV4-20` AC3, which cannot both be built. The pair form is chosen because a
        bare value is ambiguous about which `set-mode` kind it drives -- see `EDMV4-20` AC5.
  - [ ] The classifier does not attempt to distinguish "trivial" from "small" beyond those three
        tiers. `fast-track` and `fix-pack` share one row in the mode matrix and are documented as
        behaviourally identical, so a classifier cannot distinguish them without first splitting
        that row, which is out of scope. `fast-track` is therefore never emitted, and the skill says
        so in one line rather than leaving a reader to wonder why a valid enum value is unreachable.
  - [ ] The one-line output names both members of the pair it picked.
  - [ ] Step 1b.5's prose is under 30 lines, consistent with the analysis's own effort estimate and
        with the dispatcher's role as a dispatcher.
- **Dependencies**: `EDMV4-20`.
- **Target Components**: `plugins/edm/skills/orchestrator/SKILL.md:103-114` (Step 1c, the insertion
  point is immediately before it), `:107-108` (the mode-only `AskUserQuestion` that gains a
  lifecycle sibling), **`:111-112`** (the recording step, which today writes `mode` and
  `compliance_enabled` and **no `lifecycle_mode` at all** -- the gap this requirement closes),
  **`:90-95`** (the resume branch, which already reads `lifecycle_mode` and must continue to skip
  Step 1c), `plugins/edm/bin/edm-state:5063-5114` (`cmd_set_mode`, the single
  write path), `plugins/edm/CLAUDE.md Sec."EDM mode matrix"` (cited by reference, never restated);
  translation source `ECC/skills/orch-pipeline/SKILL.md:39-54` (the four-tier table and
  highest-tier-wins rule).

#### EDMV4-20: The classifier can only ever recommend one of the eight existing enum values

- **Priority**: Must Have
- **Description**: `MODE_ENUM_LIST="standard mini-srd iac data-ml prototype"` and
  `LIFECYCLE_MODE_ENUM_LIST="standard fast-track fix-pack"` (`bin/edm-state:807-808`) are validated
  in `cmd_set_mode` (`:5063-5114`) as a hard refusal: any value outside them dies with
  `set-mode: invalid mode '<value>'`. The two families are **orthogonal** -- an initiative can be
  `mode=iac` and `lifecycle_mode=fast-track` simultaneously -- and the analysis's four-tier scheme
  does not bijection onto either family alone; its own suggested mapping mixes the two families
  inside one tier list. This requirement records the backstop explicitly so no ticket attempts to
  invent a bespoke "trivial" state distinct from `fix-pack`: doing so would require new arms in
  `terminal_phase_for_mode` (`:839-847`), `code_audit_required_for_mode` (`:952-958`) and
  `convergence_exempt` (`:987-998`) as well, a far larger change.
- **Acceptance Criteria**:
  - [ ] Every value the classifier can emit is a member of `MODE_ENUM_LIST` or
        `LIFECYCLE_MODE_ENUM_LIST`. There are exactly **8** such values.
  - [ ] `MODE_ENUM_LIST` and `LIFECYCLE_MODE_ENUM_LIST` are **not modified** by this initiative. A
        smoke assertion pins both strings.
  - [ ] The classifier's two-axis mapping is stated explicitly in the skill, one row per tier,
        naming both the `mode` and the `lifecycle_mode` it recommends -- the three literal pairs
        enumerated in `EDMV4-19`, and no others. This is the same output shape `EDMV4-19` states;
        the two requirements agree by construction rather than describing different designs.
  - [ ] `terminal_phase_for_mode`, `code_audit_required_for_mode` and `convergence_exempt` gain no
        new arms.
  - [ ] **A smoke test drives each recommended pair through `edm-state set-mode` with the correct
        `kind` per member, and asserts each call is accepted.** The `kind` is named explicitly per
        value because the two enum families overlap on `standard` and are disjoint everywhere else,
        so a value alone does not determine its kind:
    - `set-mode <PREFIX> lifecycle_mode fix-pack`
    - `set-mode <PREFIX> mode mini-srd`
    - `set-mode <PREFIX> mode standard` **and** `set-mode <PREFIX> lifecycle_mode standard`

        Driven through the wrong kind, two of the three **`die`**: `fix-pack` is not in
        `MODE_ENUM_LIST` (`:5071-5074`) and `mini-srd` is not in `LIFECYCLE_MODE_ENUM_LIST`
        (`:5093-5096`). v1.0.0's AC said "each of the three emitted values" without naming a kind,
        which is not mechanically executable.
  - [ ] A smoke test asserts that a hypothetical fourth value is refused by `cmd_set_mode`, pinning
        the backstop itself, **and** that a valid value driven through the wrong `kind` is likewise
        refused -- `set-mode <PREFIX> mode fix-pack` must `die`. That second case is the one a
        classifier bug would actually produce.
- **Dependencies**: none. (See the `EDMV4-03` note in Sec.6's reading guide.)
- **Target Components**: `plugins/edm/bin/edm-state:807-808` (`MODE_ENUM_LIST`,
  `LIFECYCLE_MODE_ENUM_LIST`), `:5063-5114` (`cmd_set_mode` validation, `mode` at `:5071-5074`,
  `lifecycle_mode` at `:5093-5096`), `:839-847` (`terminal_phase_for_mode`), `:952-958`
  (`code_audit_required_for_mode`), `:987-998` (`convergence_exempt`),
  `plugins/edm/skills/orchestrator/SKILL.md`.

#### EDMV4-21: Security-trigger tie-breaker and the compliance dialog

- **Priority**: Should Have
- **Description**: ECC's tie-breaker is that anything touching a security trigger or a public
  API/contract is **at least** standard, regardless of file count. The seven triggers are
  authentication or authorization, user-input handling, database queries, filesystem paths, external
  API calls, cryptography, and secrets or credentials. **Cite `orch-pipeline/SKILL.md:100-104` as
  their source, not `rules/common/security.md`** -- correction 2: that file contains an unrelated
  8-item pre-commit checklist, and the misattribution originated in ECC's own parenthetical citation,
  which the analysis repeated without checking. Separately, the analysis claims the tie-breaker
  "composes cleanly with EDM's existing `compliance_enabled` Gate 3.5" but does not account for the
  fact that compliance is a **second, independent** `AskUserQuestion` at Step 1c.2 whose default
  would also need pre-selecting.
- **Acceptance Criteria**:
  - [ ] The tie-breaker is implemented: a hit on any of the seven triggers, or on a public API or
        contract change, forces the recommendation to at least `standard`, overriding a lower tier
        from the three signals.
  - [ ] The seven triggers are enumerated in the skill exactly as verified, and the source cited is
        `orch-pipeline/SKILL.md`, never `rules/common/security.md`.
  - [ ] When the tie-breaker fires, the classifier **also** pre-selects **On** for the Step 1c.2
        compliance dialog, and its one-line reasoning names the trigger that fired.
  - [ ] When the tie-breaker does not fire, the compliance dialog's default is unchanged
        ("Off (Recommended)").
  - [ ] The compliance pre-selection is a recommendation only. The user can still choose Off, and the
        choice is recorded through the existing path.
  - [ ] A smoke test asserts a trigger hit produces at least `standard` even when all three signals
        score trivial.
- **Dependencies**: `EDMV4-19`.
- **Target Components**: `plugins/edm/skills/orchestrator/SKILL.md:103-114` (Steps 1c.1 and 1c.2),
  `plugins/edm/CLAUDE.md Sec."EDM mode matrix"` (the `compliance_enabled` Gate 3.5 paragraph);
  translation source `ECC/skills/orch-pipeline/SKILL.md:100-104` (the seven triggers, correctly
  attributed).

#### EDMV4-22: The classifier does not restate the mode matrix (guard D6)

- **Priority**: Must Have
- **Description**: `CLAUDE.md`'s do-NOT-adopt guard **D6** states: do not duplicate the mode matrix
  into agent prompts, since it is state-backed and read at runtime. The stated cost of ignoring it is
  the same drift the whole guard set exists to remove -- two copies of the same behaviour-governing
  text disagree, silently, the next time one of them is edited. Step 1c.4 already models the correct
  pattern ("consult it before dispatching; do not restate the sub-flows here"). A classifier that
  inlines even a brief description of what `fix-pack` or `mini-srd` do, in order to justify its
  recommendation, violates D6.
- **Acceptance Criteria**:
  - [ ] Step 1b.5's text contains **no** description of what any `mode` or `lifecycle_mode` value
        does. It names the value and cites `CLAUDE.md Sec."EDM mode matrix"` by section reference.
  - [ ] The one-line reasoning explains the **classification** (which signals scored what tier), not
        the destination's behaviour.
  - [ ] **A smoke assertion greps Step 1b.5's block only**, delimited by its own heading and the
        next heading in `skills/orchestrator/SKILL.md`, for phrases that would indicate a
        restatement -- for example "Phases 1, 2, 3, 5 recorded", "fuse into one audited file",
        "Tickets generated directly from" -- and fails if any appears **within that block**. The
        scope is the block, not the tree: those phrases legitimately appear in
        `skills/tickets/SKILL.md` and `skills/srd/SKILL.md`, which is the mode matrix's own
        "owning phase skill" design working as intended. A tree-wide grep, as v1.0.0 specified,
        fails on correct code the day it is written.
  - [ ] The assertion is proven to discriminate by a positive control: a scratch copy of
        `SKILL.md` with one such phrase inserted **inside** Step 1b.5 must fail it, and the
        unmodified tree must pass.
  - [ ] The mode-matrix text in `CLAUDE.md Sec."EDM mode matrix"` is unmodified by this initiative.
  - [ ] The requirement is stated in the 4.3 ticket's own text, so the constraint travels with the
        work rather than living only here.
- **Dependencies**: `EDMV4-19`.
- **Target Components**: `plugins/edm/skills/orchestrator/SKILL.md:103-114`,
  `plugins/edm/CLAUDE.md Sec."EDM mode matrix"`,
  `plugins/edm/CLAUDE.md Sec."Prompt conventions (house style)"` (guard D6),
  `plugins/edm/bin/tests/wave8-smoke.sh` (new).

---

### 6.5 Item 4.4 -- audit lenses L12, L13 and L14

This is the widest blast radius in the initiative. The source analysis names four files; the verified
inventory is **37 touch points** (`explorers/03` Sec.1.1). The requirements below are ordered so the
state and test layers land before any prose does, because a prose change landing first makes the
smoke suite fail for the wrong reason.

**One number defined once, used throughout this subsection**: the lens count goes from **11 to 14**.
`ALL_LENS_IDS` becomes `"L1 L2 L3 L4 L5 L6 L7 L8 L9 L10 L11 L12 L13 L14"`.

#### EDMV4-23: `ALL_LENS_IDS` grows to 14 and gains a `CONDITIONAL_LENS_IDS` sibling

- **Priority**: Must Have
- **Description**: `ALL_LENS_IDS` (`bin/edm-state:1613`) is the single source for the lens ID set,
  followed immediately by a self-check at `:1615` that hardcodes the count `11` **twice** -- once in
  the `-eq 11` test and once in the `die` message. Both change. A new sibling constant
  `CONDITIONAL_LENS_IDS="L13"` records which lenses may legitimately be auto-N/A, so a caller cannot
  declare an unconditional lens N/A. Both use the space-separated-string plus word-membership idiom
  the file already uses for `MODE_ENUM_LIST` and `AUDIT_TYPE_ENUM_LIST`, because bash 3.2 has no
  portable array-as-constant usable across functions.
- **Acceptance Criteria**:
  - [ ] `ALL_LENS_IDS` enumerates 14 IDs, `L1` through `L14`, in order.
  - [ ] The self-check at `:1615` tests `-eq 14` and its `die` message says 14. Neither retains the
        literal `11`.
  - [ ] The comment at `:1608` no longer says "the eleven canonical code-audit lens IDs".
  - [ ] `CONDITIONAL_LENS_IDS="L13"` is declared beside `ALL_LENS_IDS`, with its own length
        self-check and a comment stating what "conditional" means (a lens that may be auto-N/A on an
        inapplicable stack, never a lens excluded for cost).
  - [ ] Every member of `CONDITIONAL_LENS_IDS` is also a member of `ALL_LENS_IDS`, asserted at load
        time.
  - [ ] Both constants are consumed via the `case " $LIST " in *" $item "*)` word-membership idiom.
        No caller re-encodes either list as a second literal.
  - [ ] The `shellcheck disable=SC2086` directive at `:1614` (deliberate word-splitting) is preserved
        and duplicated for the new constant.
  - [ ] `bash plugins/edm/bin/edm-state --help` runs without tripping the self-check, verifying the
        assertion holds at source time on a real invocation.
- **Dependencies**: none. (See the `EDMV4-03` note in Sec.6's reading guide.)
- **Target Components**: `plugins/edm/bin/edm-state:1607-1615`,
  `bin/edm-state:803-812` (the `MODE_ENUM_LIST` / `AUDIT_TYPE_ENUM_LIST` idiom being followed).

#### EDMV4-24: `lenses_na` sibling field and the union-based `round_type` derivation

- **Priority**: Must Have
- **Description**: Per AD5, `round_type` **stays a two-value enum** (`full` | `partial`) with its
  exact current meaning. Widening it to three values would touch `audit-converged`, `cmd_archive`,
  HANDOFF, `metrics-report`, the state-field table's documented C-4 unknown case, and roughly 28
  smoke assertions -- to express information that fits cleanly in an orthogonal field. The new
  information lives in `audit_rounds.<type>.rounds[].lenses_na`, an array recorded at
  `audit-round-start` alongside the existing `lenses`. The derivation changes from set-equality to a
  union rule.

  **The union rule requires a state-shape change, and this is the load-bearing part of the
  requirement.** The live derivation has **two** branches, not one (`bin/edm-state:4552-4573`).
  When `--lenses` is omitted it records `lenses_json="[]"` at `:4557` and hardcodes
  `round_type="full"`; only the `--lenses`-given branch runs the set-equality comparison at
  `:4567-4571`. Stating the union rule unconditionally over that shape is incoherent: with `lenses`
  recorded as `[]`, `{} UNION {}` never equals `ALL_LENS_IDS`, so every
  `audit-round-start <PREFIX> srd` and `... tickets` call -- neither of which has a lens concept and
  neither of which ever passes `--lenses` (`bin/edm-state:4554-4556` says so explicitly) -- would
  record `partial`, and `audit-converged` would refuse forever because a partial round is never
  convergent. `wave6-smoke.sh:3427-3432` and `:3452-3457` both assert `full` for exactly those
  inputs.

  **Therefore: the omitted-`--lenses` branch materializes `lenses = ALL_LENS_IDS` explicitly**
  instead of recording `[]`. That single change makes the union derivation correct in both branches
  and is what keeps `EDMV4-25`'s state-authoritative backstop meaningful -- an empty `lenses` array
  would make that backstop require **zero** JSONL files, which is precisely the pass-7 incident the
  backstop was built for (`bin/edm-state:4617-4619`).

  **Safety property, stated precisely.** Holding `ALL_LENS_IDS` constant, the union derivation with
  an empty `lenses_na` returns the same answer as today's set-equality for every input. It is
  **not** true that every input returns the same answer across this initiative as a whole:
  `--lenses L1,...,L11` returns `full` today and `partial` after `ALL_LENS_IDS` grows to 14, and
  that reversal is deliberate and is `EDMV4-32`'s to handle. `architecture.md:170-171` states the
  property too broadly and is corrected.

  The anti-abuse property is **timing**, not policy: `lenses_na` is committed to state under lock at
  round-start, which `skills/code-audit/SKILL.md` step 4 calls before step 7 launches any agent, so
  a lens cannot retroactively excuse its own non-delivery.
- **Acceptance Criteria**:
  - [ ] **State shape.** `cmd_audit_round_start` records `lenses = ALL_LENS_IDS` (all IDs, in
        `ALL_LENS_IDS` order) when `--lenses` is omitted, replacing today's `lenses_json="[]"` at
        `bin/edm-state:4557`. The round record after an omitted-`--lenses` code round contains a
        14-element `lenses` array, asserted directly against `.edm-state.json` by a smoke test, not
        inferred from the resulting `round_type`.
  - [ ] The same materialization applies to `srd` and `tickets` rounds, which never pass `--lenses`.
        Smoke tests replay `wave6-smoke.sh:3427-3432` and `:3452-3457` and assert both still record
        `round_type == "full"` after the change. A `partial` result for either is a failure, not a
        new expected value.
  - [ ] **Surface disambiguation, stated in the requirement text.** "`--lenses` omitted" throughout
        this requirement means **the `edm-state audit-round-start --lenses` flag**. It does **not**
        mean the operator's `/edm:code-audit` argument -- that is a different surface owned by
        `EDMV4-26` AC8, and the two are not interchangeable. `skills/code-audit/SKILL.md:40-42`
        mandates that Step 4 **always** passes `--lenses` to `edm-state`, so the `edm-state`-level
        omitted branch is reached by direct CLI callers and by `srd`/`tickets` rounds, never by a
        normal code-audit run. Both requirements name their surface in these words so neither can be
        read as constraining the other.
  - [ ] `cmd_audit_round_start` accepts a new optional `--na-lenses <csv>` flag.
  - [ ] `round_type` is `full` when `(lenses UNION lenses_na) == ALL_LENS_IDS` **and** `lenses_na` is
        a subset of `CONDITIONAL_LENS_IDS`; `partial` otherwise. The rule is applied **uniformly to
        both branches** -- there is no longer a branch that hardcodes `full` without evaluating it.
  - [ ] **Pass-7 regression test.** A smoke test replays the founding CA-471 incident's exact shape:
        a code round started with `--lenses` **omitted**, N prose `lens-L{N}.md` files written, and
        **zero** `lens-L{N}.jsonl` files. It asserts the CA-471 downgrade still fires and the round
        closes as `partial`. This test is the reason the materialization is mandatory rather than
        cosmetic, and it fails against v1.0.0's design.
  - [ ] `--na-lenses` naming any lens outside `CONDITIONAL_LENS_IDS` is a hard `die` at round-start.
        A lens is not conditional because a caller says so.
  - [ ] `--na-lenses` omitted produces an empty `lenses_na`. A smoke test replays the existing
        `wave6-smoke.sh` T27 AC1 cases and asserts the `round_type` each produces is unchanged from
        today's recorded expectation, **holding `ALL_LENS_IDS` at its post-`EDMV4-23` value**. The
        assertion is on the derived `round_type` value, not on byte-identity of the round record --
        the record now carries a materialized `lenses` array and a new `lenses_na` key, so it is
        deliberately not byte-identical, and `EDMV4-32` AC7 simultaneously rewrites one of those
        very cases (`wave6-smoke.sh:3445-3449`).
  - [ ] `lenses_na` is written into the round record alongside `lenses`, in the same `rmw_state`
        write, under the existing lock.
  - [ ] **`lenses_na` ordering -- `audit-round-start` is the sole writer.** No code path writes,
        appends to or mutates `lenses_na` after `audit-round-start` returns. `audit-round-complete`
        never accepts an N/A declaration from any source: not from a flag, not from
        `lenses-run.txt`, not from a lens agent's output. A smoke assertion greps `bin/edm-state`
        and fails if any assignment to or jq-write of `lenses_na` appears outside
        `_cmd_audit_round_start`, and a behavioural test confirms that an attempt to declare a lens
        N/A at completion time is refused. **This is the entire anti-abuse property** -- v1.0.0
        stated it only in prose, with no AC and no test, which left the mechanism that makes AD5
        safe completely unenforced. Atomicity (the same `rmw_state` write, under lock) is a
        different property and does not imply ordering.
  - [ ] **C-4 backward compatibility -- one behaviour, stated.** A round record written **before**
        this change carries `lenses: []` for an omitted-`--lenses` round, and that is
        indistinguishable at read time from "no lenses were run". **Every reader must treat a
        historical `lenses: []` on a round whose recorded `round_type` is `full` as meaning
        "all lenses", not "none".** The concrete rule: on read, if `lenses` is empty and
        `round_type` is `full`, substitute `ALL_LENS_IDS`. Without this the `EDMV4-25` backstop
        silently weakens on every historical round -- it would require zero JSONL files and pass
        everything. A smoke test proves it against a fixture round record carrying `lenses: []` and
        `round_type: "full"`, asserting the backstop requires the full JSONL set.
  - [ ] A round record carrying no `lenses_na` key at all reads as `[]` via a jq `//` default. No
        existing state file is rewritten in place. The two C-4 rules above are documented together
        in `CLAUDE.md`'s state-field table so a later reader does not re-derive them.
  - [ ] `schema_version` is **not** bumped. This is an additive extension of the wave-B round shape,
        exactly like the EDMV3-T51 cost fields, and every reader uses `//` defaults, so no check
        requires a higher version. The reasoning is recorded in `CLAUDE.md`'s `schema_version`
        contract table.
  - [ ] An untyped stack with `--na-lenses` **omitted** records `partial` (the union misses L13) and
        `audit-converged` refuses. The failure is loud and conservative, never a silent `full`.
  - [ ] `plugins/edm/CLAUDE.md`'s state-field table gains a `lenses_na` row stating its type,
        default, purpose and C-4 absent behaviour, in the same form as the surrounding rows.
- **Dependencies**: `EDMV4-23`.
- **Target Components**: `plugins/edm/bin/edm-state:4508-4510` (the derivation comment),
  `:4531-4580` (`_cmd_audit_round_start`), `:4555,4567-4571` (the set-equality derivation being
  replaced), `:1617-1630` (`AUDIT_ROUND_COERCE_JQ_DEF`, the C-4 coercion the new field must respect),
  `plugins/edm/CLAUDE.md Sec.".edm-state.json mode-family fields"` (`round_type` row),
  `plugins/edm/CLAUDE.md Sec.".edm-state.json schema_version contract"`.

#### EDMV4-25: CA-471's completeness backstop learns to distinguish N/A from missing JSONL

- **Priority**: Must Have
- **Description**: `audit-round-complete` currently downgrades a code round to `partial` when any lens
  named in the round's `lenses-run.txt` lacks a non-empty, parseable `lens-L{N}.jsonl`, and that
  downgrade is **irreversible** for the round it fires on -- a second completion is refused, so
  persisting the missing JSONL afterwards does not restore `full`. With L13 auto-N/A, the backstop
  needs a third check, and it must get its answer from **state written before the lenses ran**, not
  from the manifest written after. This is the one genuine design gap in 4.4 that the source analysis
  does not resolve.

  **This requirement is only sound because `EDMV4-24` materializes `lenses`.** Today the backstop
  iterates the **manifest** (`bin/edm-state:4662-4669`), which lists real lens IDs regardless of how
  the round was started. Moving the source of truth to state without the materialization would make
  a full round started without `--lenses` iterate an empty array and require **zero** JSONL files --
  exactly the founding incident recorded at `bin/edm-state:4617-4619` ("pass-7 of this plugin's own
  EDMV3 initiative shipped eleven prose reports and ZERO JSONL files, and the round still closed and
  counted as full"), and exactly what `skills/code-audit/SKILL.md:56-61` independently documents.
  The dependency on `EDMV4-24` is therefore load-bearing, not sequencing convenience.
- **Acceptance Criteria**:
  - [ ] The backstop reads `lenses` and `lenses_na` from the **round record in state**, not from
        `lenses-run.txt`. The manifest is a rendering, not a source of truth.
  - [ ] It applies `EDMV4-24`'s C-4 read rule: a historical round record carrying `lenses: []` with
        `round_type: "full"` is read as `ALL_LENS_IDS`, never as "no lenses required". A smoke test
        replays that fixture and asserts the backstop requires the full JSONL set rather than
        passing vacuously.
  - [ ] For each lens in `lenses`, a non-empty parseable `lens-L{N}.jsonl` is required, exactly as
        today.
  - [ ] For each lens in `lenses_na`, **no** `lens-L{N}.jsonl` may exist. A JSONL present for a lens
        declared N/A downgrades the round to `partial` with a message naming the disagreement between
        the skill's Step 1 detection and the agent's own behaviour -- the same contract-violation
        shape `agents/edm-test-integration.md:22-25` already names for the test layer.
  - [ ] **Incomplete-coverage check, scoped.** If `lenses UNION lenses_na` no longer covers
        `ALL_LENS_IDS` at completion time -- for example because `ALL_LENS_IDS` grew between round
        start and round completion -- the round downgrades to `partial`. **This check applies only
        to rounds whose recorded `round_type` is `full` at completion time.** Unscoped it fires on
        every legitimate operator-requested partial round: for the documented smoke set
        `--lenses L1,L9,L11` the union is not `ALL_LENS_IDS` by construction, so every smoke round
        would print an "incomplete coverage" downgrade warning about a round that is already
        correctly `partial` and was never claiming otherwise. A smoke test runs `--lenses L1,L9,L11`
        to completion and asserts **no** coverage warning is emitted.
  - [ ] The three downgrade reasons are distinguishable in the operator output: missing JSONL for a
        run lens, unexpected JSONL for an N/A lens, and incomplete coverage. A single generic message
        is not acceptable.
  - [ ] The downgrade stays irreversible, and the double-completion refusal is preserved.
  - [ ] **The manifest's remaining role is stated explicitly, and its residual gap is recorded.**
        The manifest is not a source of truth for *which lenses were required* -- state is. But it
        **remains the trigger deciding whether the gate runs at all** (`bin/edm-state:4656`), and
        that is retained deliberately for C-4: rounds recorded before this change may have no
        parseable state answer, and a round whose pass directory was never created legitimately has
        nothing to check. The consequence is a **known residual gap**: a round that produces no
        manifest -- arguably the strongest non-delivery signal there is -- escapes the backstop
        entirely, exactly as it does today. This is recorded here as an accepted limitation with a
        named follow-on, **not** closed by this requirement, because closing it means deciding what
        a missing pass directory means for a round that legitimately skipped one, which is new
        design. `decisions.md` records the gap so a later reader does not mistake it for an
        oversight.
  - [ ] A round with no pass directory or no manifest is left unchanged, exactly as today (C-4), per
        the row above.
  - [ ] Smoke tests cover all three downgrade reasons, the clean 13-of-14 N/A case that must remain
        `full`, the operator-requested `--lenses L1,L9,L11` case that must emit no coverage warning,
        and `EDMV4-24`'s pass-7 replay (omitted `--lenses`, N prose files, zero JSONL) which must
        still downgrade.
  - [ ] `plugins/edm/CLAUDE.md`'s `round_type` state-field row is updated to describe the three-way
        check, replacing the current two-way description, and to record both C-4 read rules from
        `EDMV4-24` plus the manifest-trigger residual gap.
- **Dependencies**: `EDMV4-24`. The dependency is load-bearing: without the `lenses`
  materialization this requirement's AC1 makes the backstop vacuous for the very incident it exists
  to catch.
- **Target Components**: `plugins/edm/bin/edm-state` `cmd_audit_round_complete` (the CA-471 backstop),
  `bin/edm-state:4617-4619` (the founding-incident comment), `:4656` (the manifest existence test
  that remains the gate trigger), `:4662-4669` (today's manifest iteration being replaced),
  `plugins/edm/skills/code-audit/SKILL.md:56-61` (the independent record of the empty-`lenses`
  hazard), `plugins/edm/agents/edm-test-integration.md:21-25` (the N/A-agreement precedent),
  `plugins/edm/CLAUDE.md Sec.".edm-state.json mode-family fields"` (`round_type` row),
  `plugins/edm/bin/tests/wave6-smoke.sh`, `plugins/edm/bin/tests/wave8-smoke.sh` (new).

#### EDMV4-26: Code-audit Step 1 is the sole authority for L13 applicability

- **Priority**: Must Have
- **Description**: Per D8, L13's conditionality follows the test layer's N/A-agreement precedent, not
  the mode matrix. The mode matrix is a **user-selected enum** that a human picks at Step 1c; it is
  not derived from the target codebase, which makes it a poor fit for a lens whose applicability
  should be *detected*. The test layer's shape is the right one: a single authority determines
  applicability once, every consumer agrees rather than self-declaring, N/A is recomputed each run
  rather than inherited, and absence is authoritative (no placeholder file, no placeholder row).
  Today code-audit's lens selection has exactly one input -- the human-supplied `--lenses` flag -- so
  an automatically computed N/A is a new kind of round-composition logic that must be given one clear
  owner.
- **Acceptance Criteria**:
  - [ ] `skills/code-audit/SKILL.md` Step 1 gains a stack-detection step that determines whether L13
        applies, and states in its own text that it is the **sole** authority for that
        determination.
  - [ ] **The determination is computed by a deterministic `edm-state` helper, not by prose an LLM
        interprets.** `edm-state detect-conditional-lenses [<PREFIX>]` prints the CSV the skill
        passes straight to `--na-lenses` (empty output means none). Step 1 **calls** it and records
        the result; it does not re-derive the answer. This is mandatory rather than preferred
        because the determination gates `round_type=full`, which gates `audit-converged`, which
        gates `archive` -- a non-deterministic input to a convergence gate is not acceptable, and
        `skills/code-audit/SKILL.md` Step 1 is prose an agent executes with no reproducibility
        guarantee.
  - [ ] The helper's criteria are enumerated in its own help block and are pure filesystem
        predicates over tracked files, with **no** content heuristics. L13 applies when the
        repository contains at least one of: `tsconfig.json`; any `*.kt` or `*.kts`; any `*.swift`;
        `Cargo.toml`; `go.mod`; any `*.java`; any `*.scala`; any `*.hs`; or `pyproject.toml`
        **together with** a typed-checker configuration (a `[tool.mypy]` or `[tool.pyright]` table,
        or a sibling `mypy.ini` / `pyrightconfig.json`) -- bare `pyproject.toml` is not sufficient,
        since an untyped Python project has one too. Absence of every marker means L13 is N/A.
  - [ ] The marker list lives in **one** place in `bin/edm-state` and is not restated in
        `skills/code-audit/SKILL.md`, in `agents/edm-audit-type-design.md`, or in any ticket. The
        skill cites the helper by name; the agent cites the skill. A smoke assertion greps the two
        prompt files for the marker filenames and fails on a second copy, per the same
        define-once discipline `CONDITIONAL_LENS_IDS` follows.
  - [ ] Detection is deterministic: two runs against the same tree produce byte-identical output. A
        smoke test runs the helper twice against a fixture and diffs, and separately asserts each
        marker independently flips the answer (one fixture per marker, plus a no-marker fixture).
  - [ ] The helper is bash 3.2 clean (`EDMV4-55`), adds no required binary (`EDMV4-56`), and exits
        **0** whether or not it finds markers. An empty result is a valid answer, not an error.
  - [ ] `plugins/edm/CLAUDE.md Sec."bin/ helper scripts"` documents the new subcommand and the
        marker list, and the `edm-state` subcommand count is updated to match (it is also
        incremented by `EDMV4-14`'s `get-patterns`; the two increments are reconciled into one final
        number rather than each claiming to be the only change).
  - [ ] N/A is recomputed on every round. It is never read from a previous round's record.
  - [ ] The skill states that the **agent** must agree with this determination rather than form its
        own. The reciprocal clause inside `agents/edm-audit-type-design.md` is owned by
        `EDMV4-28` AC4, which depends on this requirement -- not the reverse. This requirement
        establishes the authority; the agent agrees with it once it exists.
  - [ ] On N/A, **nothing is written**: no `lens-L13.md`, no `lens-L13.jsonl`, no placeholder. Absence
        is authoritative.
  - [ ] Step 4 passes both `--lenses` and `--na-lenses` to `audit-round-start`.
  - [ ] Step 8 writes `lenses-run.txt` containing the run lens IDs one per line plus a
        `Lenses N/A:` header line, and that header line does not match the existing `^L[0-9]+$`
        parsing filter, so no existing consumer mis-reads it as a lens ID.
  - [ ] **Operator override, on the `/edm:code-audit` surface.** When the **operator** passes an
        explicit lens list to `/edm:code-audit`, they get exactly that list and the auto-N/A path
        does not run -- an explicit human request is never silently rewritten. The auto-N/A path
        applies only when the **operator** supplied no lens list. Note the surface: this AC is about
        the `/edm:code-audit` argument, **not** the `edm-state audit-round-start --lenses` flag,
        which `skills/code-audit/SKILL.md:40-42` requires Step 4 to pass on **every** run
        regardless. `EDMV4-24` owns the `edm-state` flag; this AC owns the operator argument. Under
        the flag reading this path would be dead code, which is why both requirements name their
        surface explicitly.
- **Dependencies**: `EDMV4-24`. **Not `EDMV4-28`.** v1.0.0 declared `26 -> 28` while `EDMV4-28`
  declares `28 -> 26`, a fourth dependency cycle of the same unschedulable class as P0-5's three
  (the SRD audit did not catch this one). The direction is settled by which artifact is
  authoritative: this requirement **establishes** the applicability authority, and the agent
  **agrees** with it, so the agent depends on the authority. `EDMV4-28` retains its dependency on
  this requirement; this one drops its dependency on the agent.
- **Blocks**: `EDMV4-28`.
- **Target Components**: `plugins/edm/bin/edm-state` (new `detect-conditional-lenses` arm),
  `plugins/edm/skills/code-audit/SKILL.md:37-40` (Step 1 lens validation and
  selection), `:40-42` (the always-pass-`--lenses` mandate that makes the two surfaces distinct),
  `:57,60` (Step 4 round-type prose), `:95-96` (Step 8a content check),
  `plugins/edm/agents/edm-test-integration.md:21-25,100-116` (the precedent),
  `plugins/edm/CLAUDE.md Sec."Layers that are N/A and per-epic test plans"`,
  `plugins/edm/CLAUDE.md Sec."bin/ helper scripts"`,
  `plugins/edm/agents/edm-audit-type-design.md` (new).

#### EDMV4-27: Lens L12 -- Silent Failures

- **Priority**: Must Have
- **Description**: L1 (Logic, Correctness and Completeness) explicitly lists "empty catch blocks" as a
  hunt target, but **nothing in L1 through L11 hunts the fallback that succeeds while hiding a
  failure** -- the more dangerous and much harder-to-spot half of the category, and one a passing test
  suite actively conceals. L12 is unconditional. Its taxonomy comes from
  `silent-failure-hunter.md:23-49`, whose five categories were verified verbatim; its prompt does
  not. The ECC agent's body is **44 lines** (correction 6 -- the analysis's "roughly 30" undercounts
  it by 47%), with a four-item bullet-list output format, against EDM's 115-204-line lens agents with
  structured JSONL contracts. Take the taxonomy, not the prompt.
- **Acceptance Criteria**:
  - [ ] `plugins/edm/agents/edm-audit-silent-failures.md` exists and satisfies `EDMV4-30`'s house
        contract in full.
  - [ ] Its `## What You Hunt For` section covers five categories: empty catch blocks and errors
        converted to `null` or empty collections without context; inadequate logging (missing
        context, wrong severity, log-and-forget); **dangerous fallbacks** (default values that hide
        real failure, `.catch(() => [])`, graceful-looking paths that make downstream bugs harder to
        diagnose); error propagation problems (lost stack traces, generic rethrows, missing async
        handling); and missing handling entirely around network, file or database paths, or
        transactional work without rollback.
  - [ ] The dangerous-fallback category is the one whose mandate is stated most explicitly, since it
        is the gap L1 does not cover.
  - [ ] The lens is **unconditional**: it is not a member of `CONDITIONAL_LENS_IDS` and has no N/A
        exit.
  - [ ] Its `## Scope` section carries one sentence bounding it against L1, so a finding about an
        empty catch block does not get filed twice by two lenses.
  - [ ] No text is copied from `silent-failure-hunter.md`. The five categories are re-expressed in
        EDM's own register and at EDM's own length.
  - [ ] Its length scales with its hunt categories rather than targeting any existing lens's line
        count.
- **Dependencies**: `EDMV4-23`, `EDMV4-30`.
- **Target Components**: `plugins/edm/agents/edm-audit-silent-failures.md` (new),
  `plugins/edm/agents/edm-audit-logic.md` (L1, the adjacent mandate);
  taxonomy source `ECC/agents/silent-failure-hunter.md:23-49` (44-line body, read not copied).

#### EDMV4-28: Lens L13 -- Type Design, auto-N/A on an untyped stack

- **Priority**: Must Have
- **Description**: No EDM lens touches type design at all -- the gap is total, and for a methodology
  whose implementers write TypeScript, Kotlin, Swift and Rust that is a real hole. L13 evaluates
  whether types make illegal states harder or impossible to represent, across the four dimensions
  verified at `type-design-analyzer.md:23-42`. It is the **only** conditional lens.
  **Guard D2 binds here**: adding lenses does not violate D2 on its face, but the analysis's own risk
  note ("more lenses means more audit cost per round... Measure with `/edm:metrics` before making all
  three unconditional") must not be read as licence to make L13 conditional for cost reasons. D2's
  stated cost of being ignored is coverage loss disguised as an efficiency gain -- a lens silently
  stops existing and nobody notices until the gap it used to catch ships. L13's conditionality is
  justified **only** as genuine inapplicability: type design is meaningless in untyped code.
- **Acceptance Criteria**:
  - [ ] `plugins/edm/agents/edm-audit-type-design.md` exists and satisfies `EDMV4-30`'s house
        contract in full.
  - [ ] Its `## What You Hunt For` section covers four dimensions: encapsulation (are internals
        hidden, can invariants be violated from outside), invariant expression (do types encode
        business rules), invariant usefulness (do they prevent real bugs, are they domain-aligned),
        and enforcement (does the type system enforce them, are there easy escape hatches).
  - [ ] The agent's `## When this does NOT apply` section states the N/A condition as
        **inapplicability**, in exactly those terms, and explicitly states that cost is never a
        reason to skip it. A smoke assertion greps for the inapplicability framing.
  - [ ] The agent's N/A exit **agrees with** `skills/code-audit/SKILL.md` Step 1's determination and
        never substitutes for it, in the `edm-test-integration.md:22-25` form.
  - [ ] On N/A the agent writes nothing at all and exits cleanly.
  - [ ] `L13` is the sole member of `CONDITIONAL_LENS_IDS`.
  - [ ] The 4.4 ticket text records the D2 framing constraint, so it travels with the work.
  - [ ] Neither the agent nor the skill nor any ticket AC cites GateGuard's or any other
        self-reported effect-size number as a target. Effect claims are directional only
        (`ecc-integration-analysis.md` Part 8.3.1).
- **Dependencies**: `EDMV4-23`, `EDMV4-26`, `EDMV4-30`.
- **Target Components**: `plugins/edm/agents/edm-audit-type-design.md` (new),
  `plugins/edm/bin/edm-state:1613` (`CONDITIONAL_LENS_IDS` beside `ALL_LENS_IDS`),
  `plugins/edm/agents/edm-test-integration.md:21-25` (the agreement clause form),
  `plugins/edm/CLAUDE.md Sec."Prompt conventions (house style)"` (guard D2);
  taxonomy source `ECC/agents/type-design-analyzer.md:23-42` (35-line body, read not copied).

#### EDMV4-29: Lens L14 -- Behavioral Test Coverage, with an explicit mandate boundary

- **Priority**: Must Have
- **Description**: EDM has two adjacent things that both miss this question. L4 (Test Quality) hunts
  defects *in the tests themselves* -- `2>/dev/null || true` masking failures, mocks hiding the code
  under test. `edm-test-coverage-auditor` reports *percentages* against configured thresholds.
  Neither asks "would these tests catch a real bug in this change?" L14 does. Because it sits between
  two existing mandates, the boundary must be stated in the prompt, not left to the synthesizer's
  false-alarm filter to sort out after the fact -- two lenses filing the same finding is exactly the
  duplicate-finding noise the orthogonal-mandate design exists to prevent.
- **Acceptance Criteria**:
  - [ ] `plugins/edm/agents/edm-audit-behavioral-tests.md` exists and satisfies `EDMV4-30`'s house
        contract in full.
  - [ ] Its process covers: map changed code to its tests, find new untested paths, verify edge and
        error paths, prefer meaningful assertions over no-throw checks, flag flaky patterns, and rate
        gaps.
  - [ ] Gap ratings use the canonical P0/P1/P2/NOTED vocabulary. ECC's critical/important/
        nice-to-have scale is **not** imported -- `CLAUDE.md Sec."Severity vocabulary"` is closed and
        no agent may define a divergent local scale.
  - [ ] Its `## Scope` section carries **one** sentence bounding L14 against L4 and against
        `edm-test-coverage-auditor`: L4 owns defects inside tests, `edm-test-coverage-auditor` owns
        coverage percentages against thresholds, L14 owns whether the tests would catch a real bug in
        the changed behaviour.
  - [ ] `agents/edm-audit-test-quality.md` (L4) gains the reciprocal sentence, so the boundary is
        stated from both sides and neither agent has to infer it. **The L4 file is
        `edm-audit-test-quality.md`; `agents/edm-audit-tests.md` does not exist** and never has --
        the canonical list is `wave7-smoke.sh:1589`'s `LENS_AGENTS`. A ticket written against the
        wrong path would either fail or, worse, create a twelfth lens file by accident.
  - [ ] `agents/edm-test-coverage-auditor.md` gains the same reciprocal sentence.
  - [ ] The lens is unconditional.
  - [ ] A smoke assertion verifies the boundary sentence is present in all three files.
- **Dependencies**: `EDMV4-23`, `EDMV4-30`.
- **Target Components**: `plugins/edm/agents/edm-audit-behavioral-tests.md` (new),
  `plugins/edm/agents/edm-audit-test-quality.md` (L4 -- the real filename; the L4 lens is **not**
  `edm-audit-tests.md`, which does not exist),
  `plugins/edm/bin/tests/wave7-smoke.sh:1589` (`LENS_AGENTS`, the canonical eleven filenames),
  `plugins/edm/agents/edm-test-coverage-auditor.md`,
  `plugins/edm/CLAUDE.md Sec."Severity vocabulary"`;
  process source `ECC/agents/pr-test-analyzer.md:23-47` (39-line body, read not copied).

#### EDMV4-30: The three new lens agents conform to the house lens contract exactly

- **Priority**: Must Have
- **Description**: Every existing lens agent shares a nine-part structural contract, verified in full
  against `edm-audit-logic.md` (L1, 115 lines) and `edm-audit-security.md` (L8, 204 lines). Several
  parts of it are **machine-asserted by existing smoke tests** -- notably T25 AC8
  (`wave7-smoke.sh:1902-1912`), which asserts the False Alarm Filter's exact framing sentence appears
  in every lens file with exactly three criteria each. A new lens agent that does not match is not
  merely inconsistent; it fails or silently escapes existing assertions.

  **This requirement is a constraint *on* `EDMV4-27`, `EDMV4-28` and `EDMV4-29`, not a peer of
  them.** It specifies the contract those three files must satisfy; each of them cites it by ID and
  requires conformance "in full". v1.0.0 additionally declared `EDMV4-30` dependent on all three,
  producing three further dependency cycles (`27 <-> 30`, `28 <-> 30`, `29 <-> 30`) of exactly the
  unschedulable class P0-5 identified for `EDMV4-14`/`15`/`16` -- the SRD audit did not catch these
  three. The contract must be written down before an agent can be written against it, so the
  direction is `27, 28, 29 -> 30`, one way.

  Its per-file conformance criteria are therefore **verified at each agent requirement's
  completion**, not at this one's. What completes *here* is the contract's specification plus the
  smoke-assertion extension that enforces it; the extension's file set grows as each agent lands,
  and is complete when the last of the three does.
- **Acceptance Criteria**:
  - [ ] Frontmatter matches the existing lens set exactly: `name: edm-audit-{lens-name}`, a YAML
        block-scalar `description:` naming the lens number and what it hunts,
        `tools: Glob, Grep, LS, Read, NotebookRead, WebFetch, TodoWrite, WebSearch, Write`,
        `model: opus`, `effort: max`, `maxTurns: 30`, `color: cyan`,
        `disallowedTools: Edit, NotebookEdit`.
  - [ ] The tool grant is structurally read-only apart from `Write`. **No new lens is granted `Edit`
        or `NotebookEdit`.**
  - [ ] `model: opus` / `effort: max` matches the contested-audit-set row of
        `CLAUDE.md Sec."Model and effort assignments"`. No hand-picked downgrade is taken -- only a
        measured, mechanical promotion may retier that set.
  - [ ] Opening frame: `You are executing **EDM Code Audit Lens L{N}: {Name}**.` followed immediately
        by the mandate-narrowing sentence in the house form.
  - [ ] `## Scope` carries the verbatim house scope-statement paragraph.
  - [ ] `## False Alarm Filter` carries the identical framing sentence and **exactly three** numbered
        criteria specific to the lens, so `wave7-smoke.sh`'s T25 AC8 assertion passes with the new
        files included in its set.
  - [ ] `## Output` states the two permitted write paths inside the current pass directory
        (`${OUTPUT_DIR}/lens-L{N}.md` and `${OUTPUT_DIR}/lens-L{N}.jsonl`), the ASCII-only reminder,
        the `mkdir -p` rationale for why `Write` is granted without `Bash(mkdir *)`, and the
        "JSONL file is authoritative on conflict" sentence.
  - [ ] `## Output Format` cites `CLAUDE.md Sec."Severity vocabulary"` **and** carries the
        `Read docs/canonical-sections.md` anchoring instruction verbatim, with the
        "resolved relative to the EDM plugin's own root ... never the caller's cwd" qualifier. The
        three new files are anchored from birth, not left for `EDMV4-49` to sweep.
  - [ ] `## JSONL Line Format` restates the fixed schema literally with the correct lens ID, the
        D22/CA-130 stale-cache fallback clause, the five bulleted field rules
        (`id`, `round`/`round_type`, `sev`, `confidence`, `status`), and the residual-risk paragraph.
  - [ ] `## When this does NOT apply` is present in all three. L12 and L14 use the standard
        "always applies once the code-audit skill selects lens L{N}" sentence; L13's differs per
        `EDMV4-28`.
  - [ ] `color: cyan` matches `CLAUDE.md Sec."Agent color scheme"`, whose lens row is updated from 11
        to 14 by `EDMV4-35`.
  - [ ] `bash plugins/edm/bin/edm-check-grants` passes over the three new files.
- **Dependencies**: `EDMV4-23`. **Not `EDMV4-27`/`28`/`29`** -- see the constraint note above; those
  three depend on this one, and declaring the reverse as well made three cycles.
- **Blocks**: `EDMV4-27`, `EDMV4-28`, `EDMV4-29`.
- **Target Components**: `plugins/edm/agents/edm-audit-logic.md` (L1, the contract exemplar, anchor
  sentence at `:69`), `plugins/edm/agents/edm-audit-security.md` (L8, `:154-157`),
  `plugins/edm/agents/edm-audit-silent-failures.md`, `edm-audit-type-design.md`,
  `edm-audit-behavioral-tests.md` (all new),
  `plugins/edm/bin/tests/wave7-smoke.sh:1902-1912` (T25 AC8),
  `plugins/edm/docs/canonical-sections.md`,
  `plugins/edm/CLAUDE.md Sec."Model and effort assignments"`.

#### EDMV4-31: Sweep `skills/code-audit/SKILL.md`'s twelve lens-count sites

- **Priority**: Must Have
- **Description**: `skills/code-audit/SKILL.md` carries the lens count in twelve places, spanning
  frontmatter, prose, the `--lenses` validation range, the lens table itself, and the synthesizer
  launch prompt. Some are cosmetic and some are load-bearing; the validation range and the table are
  the ones that change behaviour. The heading `## The 11 Audit Lenses` and the section
  `## What Single-Pass Audits Miss (Why 11 Lenses)` both carry the count in the heading string
  itself.
- **Acceptance Criteria**:
  - [ ] The frontmatter `description` at `:3` names 14 parallel orthogonal audit agents and lists all
        14 dimensions.
  - [ ] `:24`'s "Eleven auditors with orthogonal mandates" reads 14.
  - [ ] `:37`'s lens-token validation accepts `L1` through `L14` and rejects `L15` and above with a
        clear message.
  - [ ] `:38-40`'s "if `--lenses` is omitted, run all 11" reads 14, and the `ROUND_TYPE` description
        is updated for the union rule in `EDMV4-24` rather than left describing set-equality.
  - [ ] `:57` and `:60`'s "eleven members means full" / "all eleven explicitly" read 14.
  - [ ] `:95-96`'s Step 8a content-check prose reads 14.
  - [ ] `:250`'s `## The 11 Audit Lenses` heading reads 14.
  - [ ] `:252-264`'s lens table gains three rows -- `edm-audit-silent-failures` (L12),
        `edm-audit-type-design` (L13), `edm-audit-behavioral-tests` (L14) -- each with a one-line
        mandate summary. Per `CLAUDE.md`'s intent-to-file index, the table **summarizes**; the agent
        file remains authoritative for the mandate.
  - [ ] The L13 row is annotated as conditional, with a pointer to Step 1's detection.
  - [ ] `:273-274,290,298`'s Smoke-Audit-versus-Full-Round table and prose read 14.
  - [ ] `:373`'s synthesizer launch prompt reads "fewer than 14".
  - [ ] `:524`'s `## What Single-Pass Audits Miss (Why 11 Lenses)` heading reads 14.
  - [ ] `agents/edm-audit-synthesizer.md:24`'s "full: 11 lenses" reads 14.
  - [ ] No heading string renamed here is referenced by name from elsewhere without that reference
        also being updated. A grep for each changed heading string across the plugin confirms zero
        stale references.
- **Dependencies**: `EDMV4-23`, `EDMV4-27`, `EDMV4-28`, `EDMV4-29`.
- **Target Components**: `plugins/edm/skills/code-audit/SKILL.md:3,24,37,38-40,57,60,95-96,250,252-264,273-274,290,298,373,524`,
  `plugins/edm/agents/edm-audit-synthesizer.md:24`,
  `plugins/edm/CLAUDE.md Sec."Intent-to-file index"`.

#### EDMV4-32: Rewrite the smoke-suite lens-count assertions

- **Priority**: Must Have
- **Description**: This is the largest single piece of 4.4 and the one the source analysis does not
  mention at all -- it names no test file. Two facts make it a first-class requirement rather than a
  mechanical sweep:

  **`bin/tests/wave7-smoke.sh` contains two tests written specifically to assert the lens count never
  changes.** T47 AC6 at `:4902-4903` checks that `skills/code-audit/SKILL.md` still contains the
  literal string `run all 11`, under the banner "lens cap surviving unchanged". T48 AC6 at
  `:5417-5420` counts `agents/edm-audit-*.md` files excluding the synthesizer and asserts `-eq 11`,
  under the banner "lens fan-out unchanged: eleven lenses, none merged or removed". These are not
  incidental constants. They must be **deliberately revised** -- rewritten to assert 14 and to state
  in their banner text that 14 is the new invariant -- with the revision called out as its own
  acceptance criterion, because "revise a test whose entire purpose was asserting today's number is
  permanent" is a different kind of change from "update a constant".

  **`bin/tests/wave6-smoke.sh:3445-3449` will silently invert.** Its T27 AC1 case calls
  `audit-round-start T27ROUND code --lenses L1,L2,L3,L4,L5,L6,L7,L8,L9,L10,L11` and asserts
  `round_type == "full"`. The moment `ALL_LENS_IDS` grows, that input is an 11-of-14 **partial**
  round, so the test's own claim reverses without the test being touched. It must be rewritten to
  list all 14, and a new case added for the 13-plus-N/A composition.
- **Acceptance Criteria**:
  - [ ] T47 AC6 (`wave7-smoke.sh:4902-4903`) is rewritten to assert the new "run all 14" string, and
        its banner text states that 14 is the invariant being protected.
  - [ ] T48 AC6 (`wave7-smoke.sh:5417-5420`) is rewritten to assert `-eq 14` and its banner text
        reads "fourteen lenses, none merged or removed". Its `die` message says 14.
  - [ ] Both rewrites are called out explicitly in the ticket's own acceptance criteria as
        deliberate revisions of anti-regression tests, not as incremented constants.
  - [ ] Every `-eq 11` / `== 11` lens assertion in `wave7-smoke.sh` is retargeted. The verified exact
        set is **nine** sites: `:1627`, `:1630`, `:1656`, `:1666`, `:1722`, `:1732`, `:1745`,
        `:1911`, `:5419`. Tree-wide the exact-integer set is **ten**, the tenth being
        `bin/edm-state:1615` (`ALL_LENS_IDS`'s own `-eq 11` self-check), owned by `EDMV4-23`.

  - [ ] **Hardcoded lens-NAME lists.** `-eq 11` is not the only shape, and a name list is the more
        dangerous one because it stays green while silently dropping the new lenses. All four are
        extended to 14 (or, where they enumerate a wider set, to that set plus three):
    - `wave7-smoke.sh:1589` (`LENS_AGENTS`, 11 names) -- also the canonical list of real lens
      filenames, which is why `EDMV4-29` cites it.
    - `:1905` (`lens_files`) -- the list T25 AC8 actually iterates when asserting the False Alarm
      Filter's three-criteria shape, so `EDMV4-30`'s conformance AC is only enforced on the new
      lenses once this list grows.
    - `:4734` (`T46_LENSES`).
    - **`:5386` (`T48_CONTESTED_AGENTS`, 15 names) -- call this one out explicitly.**
      `t48_contested_count` is computed by **counting the hardcoded list itself**
      (`:5387-5390`), so `:5402`'s `-eq 15` stays green no matter what the tree contains. Left
      unswept, the three new lenses are **silently dropped out of the D16 opus/max assertion** and
      nothing fails -- exactly the "silently escapes existing assertions" failure `EDMV4-30` warns
      about, and the only site in this sweep where the test passing is itself the defect. The list
      goes to 18 names and `:5402` to `-eq 18`.
  - [ ] **Non-`-eq 11` exact-integer counts**, all of which derive from the lens count and none of
        which the `-eq 11` grep finds: `:1688` (`-eq 12`, the eleven lenses plus
        `skills/code-audit/SKILL.md`) becomes `-eq 15`; `:4735` and `:4749` (`-eq 13`) become
        `-eq 16`; `:5402` (`-eq 15`) becomes `-eq 18`. Each is re-read at edit time to confirm what
        its number is counting before it is changed -- these are offsets from 11, not the count
        itself, so a mechanical `+3` is right only if the offset is verified.
  - [ ] `:1751`'s literal loop bound (`for t24_n in 1 ... 11`) enumerates lens numbers and is
        extended through 14.
  - [ ] The "twelve" banner strings at `:1591`, `:1599` and `:1603` (the CA-529 block, "all twelve
        `agents/edm-audit-*.md`" = eleven lenses plus the synthesizer) read fifteen.
  - [ ] `wave7-smoke.sh:4756-4763` (T46 AC2) is a **second** machine assertion on the three-criteria
        False Alarm Filter, distinct from T25 AC8 at `:1902-1912`. Both are retargeted, and the
        ticket names both, so neither is missed by a sweep that finds only the one this SRD's
        `EDMV4-30` cites.
  - [ ] Every assertion's accompanying `pass`/`fail` message text is updated too, so a passing test
        does not print "eleven lens prompts instruct a JSONL sibling" while asserting 14.
  - [ ] Where an assertion counts files on disk, it is converted to a computed count compared against
        a single named constant defined once in the suite, rather than nine independent literals.
  - [ ] `wave6-smoke.sh:3445-3449`'s explicit all-lenses invocation lists all 14 IDs and still
        asserts `round_type == "full"`.
  - [ ] `wave6-smoke.sh` gains a **new** case asserting that `--lenses` naming 13 IDs plus
        `--na-lenses L13` records `round_type == "full"`.
  - [ ] `wave6-smoke.sh` gains a **new** case asserting that `--lenses` naming 13 IDs with
        `--na-lenses` omitted records `round_type == "partial"`.
  - [ ] `wave6-smoke.sh:3435-3443`'s existing partial-round case (`--lenses L1,L9,L11`) still records
        `partial`, and its message text is updated from "3-of-11" to "3-of-14".
  - [ ] `bash plugins/edm/bin/tests/run-all.sh` passes with zero failures after the rewrite.
  - [ ] This requirement's work lands **before** any other requirement's changes touch
        `wave7-smoke.sh`, since it is the single largest and most interconnected file the initiative
        edits.
- **Dependencies**: `EDMV4-23`, `EDMV4-24`, `EDMV4-33`.
- **Blocks**: any other work touching `bin/tests/wave7-smoke.sh`.
- **Target Components**: `plugins/edm/bin/tests/wave7-smoke.sh` --
  exact-integer comparisons at `:1627,1630,1656,1666,1722,1732,1745,1911,5419`;
  non-`-eq 11` counts at `:1688` (12), `:4735,:4749` (13), `:5402` (15);
  hardcoded name lists at `:1589` (`LENS_AGENTS`), `:1905` (`lens_files`), `:4734` (`T46_LENSES`),
  `:5386` (`T48_CONTESTED_AGENTS`);
  the literal loop bound at `:1751`; the "twelve" banners at `:1591,:1599,:1603`;
  the two False Alarm Filter assertions at `:1902-1912` (T25 AC8) and `:4756-4763` (T46 AC2);
  the two deliberately-revised anti-regression tests at `:4902-4903` (T47 AC6) and `:5417-5420`
  (T48 AC6); and every `11`/`eleven` message string among the wider token set (`EDMV4-33`).
  Also `plugins/edm/bin/tests/wave6-smoke.sh:3434-3449`,
  `plugins/edm/bin/tests/run-all.sh`.

#### EDMV4-33: Re-inventory the lens-count sites, and do not touch the unrelated elevens

- **Priority**: Must Have
- **Description**: Two opposite hazards sit either side of `EDMV4-32`. First, the inventory may be
  incomplete: `explorers/03` found its sites by pattern matching rather than by reading a
  7,000-line file, and its own riskiest-assumption list flags that a bare `[[ "$count" -eq 11 ]]`
  with no nearby "eleven" token could have been missed. Second, and more dangerous, **several
  occurrences of "eleven" in this codebase are not the lens count**, and a careless find-replace
  corrupts them. `CLAUDE.md:292` and `docs/canonical-sections.md:88` say "referenced by name from the
  eleven touch points inventoried in `architecture.md`" -- that is the **Mermaid-convention**
  touch-point count, a different eleven entirely.
- **Acceptance Criteria**:
  - [ ] Before the 4.4 inventory is declared closed, a second pass greps `bin/tests/` specifically
        for `-eq 11` and `== 11`, and the result is reconciled against the nine sites named in
        `EDMV4-32`. Any additional site found is added and the discrepancy recorded.
  - [ ] The same second pass runs across the whole plugin, not only `bin/tests/`. Tree-wide the
        exact-integer set is **ten**: the nine in `wave7-smoke.sh` plus `bin/edm-state:1615`.
  - [ ] **The second pass also covers the two shapes `-eq 11` structurally cannot find**, both of
        which `EDMV4-32` enumerates and both of which stay green while being wrong:
        (a) **hardcoded lens-name lists** -- grep for `edm-audit-` appearing three or more times on
        one line across `bin/tests/`, which is what surfaces `LENS_AGENTS`, `lens_files`,
        `T46_LENSES` and `T48_CONTESTED_AGENTS`; and (b) **counts that are offsets from 11 rather
        than 11 itself** -- `-eq 12`, `-eq 13`, `-eq 15`. Any site either grep finds that is not
        already in `EDMV4-32`'s list is added there and the discrepancy recorded.
  - [ ] **Four `bin/edm-state` prose sites** carry the lens count and are owned here rather than
        left to an unowned sweep: `:3632` (`metrics-report` output), `:4660`, `:4762`, and `:4827`
        (`cmd_audit_converged`'s refusal text). Each is re-read at edit time -- some describe an
        invariant that remains true at 14 and must not be mechanically incremented -- and the
        decision per site is recorded.
  - [ ] **The artifact-layout trees** carry `lens-L11` as the last element of an illustrative
        listing and are swept: `plugins/edm/CLAUDE.md:118-119` and
        `plugins/edm/README.md:204-205`.
  - [ ] **`CLAUDE.md:368`'s contested-audit-set row** ("11 code-audit lenses ... (15 agents)") is
        cited as authority by `EDMV4-30` AC3 and must be updated to 14 lenses / 18 agents in the
        same change as its machine counterparts, `wave7-smoke.sh:5386` and `:5402`. A prompt
        citing a table that says 11 while the assertion says 18 is worse than either alone.
  - [ ] **`CLAUDE.md:339` and `:342`** carry live lens-count strings ("eleven", "thirteen") inside
        the D34 passage that `EDMV4-49` AC5 separately rewrites. They are on **this** requirement's
        list, not on the do-not-touch list, and the two edits are reconciled in one pass rather than
        applied twice or applied in conflict.
  - [ ] A **do-not-touch list** is recorded in the 4.4 ticket and honoured. It contains at minimum:
    - `plugins/edm/CLAUDE.md:292` and `plugins/edm/docs/canonical-sections.md:88` -- the Mermaid
      touch-point count, an unrelated eleven.
    - `plugins/edm/bin/edm-state:4619` -- a comment recounting a past incident ("shipped eleven prose
      reports and ZERO JSONL files"). Historical; do not rewrite history.
    - `plugins/edm/bin/edm-check-grants:11` -- a comment describing that check's own rationale, not a
      lens-count assertion. Verify at edit time rather than assuming.
    - `plugins/edm/CHANGELOG.md` (14 sites) -- a historical record. **No past entry is edited.** A
      new entry documenting the 11-to-14 change is the correct addition (`EDMV4-35`).
    - `plugins/edm/bin/edm-state:2390` -- describes an invariant that remains true at 14; re-read for
      correctness but do not mechanically increment.
    - **`plugins/edm/CLAUDE.md`'s do-NOT-adopt guard D1 and D2 text.** The widened closure grep
      below matches it, and no requirement in this SRD owns it, so without this entry AC4 would
      report a defect nobody is responsible for. D1/D2 are guard prose about fan-out policy, not a
      lens-count assertion. **Keyed by string, not line number** -- see the note below.
  - [ ] **The do-not-touch list is keyed to strings, not line numbers.** Every entry records the
        matched text (or a stable unique substring of it) alongside the path; the line number is
        advisory only. This plugin's own line numbers moved twice during this initiative, and
        CA-464 already retired one line-range citation for going stale twice. A do-not-touch list
        keyed to a line number silently starts protecting a different line.
  - [ ] After the sweep, the closure grep returns only members of the do-not-touch list. The
        pattern is
        `grep -rniE 'eleven|twelve|thirteen|fifteen|11[- ]lens|lens-L11|L1-L11|all 11|-eq (11|12|13|15)' plugins/edm/`.
        v1.0.0's `eleven|11 lens|11-lens` was structurally incapable of finding most live forms:
        it misses `run all 11` (`skills/code-audit/SKILL.md:38`, the exact string T47 AC6 asserts),
        `L1-L11` (`:37`), `lens-L11.jsonl`, `11 parallel orthogonal audit agents` (`:3`), and every
        `-eq 11|12|13|15`. Any survivor outside the do-not-touch list is a defect.
  - [ ] `docs/canonical-sections.md` is regenerated by `edm-sync-canonical-sections` rather than
        hand-edited, and `--check` passes (it is a generated mirror -- editing it directly is the
        drift the `--check` assertion exists to catch).
  - [ ] The reconciliation result is recorded in `decisions.md` so a later reader knows the inventory
        was closed deliberately.
- **Dependencies**: `EDMV4-23`.
- **Target Components**: `plugins/edm/bin/tests/wave7-smoke.sh`,
  `plugins/edm/bin/edm-state:3632,4660,4762,4827` (the four prose sites),
  `plugins/edm/CLAUDE.md:118-119` (artifact-layout tree), `:339,:342` (the D34 passage's live
  counts), `:368` (the contested-audit-set row), `plugins/edm/README.md:204-205`
  (artifact-layout tree);
  do-not-touch, keyed by string: `plugins/edm/CLAUDE.md:292` and
  `plugins/edm/docs/canonical-sections.md:88` (the Mermaid touch-point count),
  `plugins/edm/CLAUDE.md`'s D1/D2 guard prose, `plugins/edm/bin/edm-state:2390,4619`,
  `plugins/edm/bin/edm-check-grants:11`, `plugins/edm/CHANGELOG.md`;
  plus `plugins/edm/bin/edm-sync-canonical-sections`,
  `SRD/edm/EDMV4__ecc-integration/decisions.md`.

#### EDMV4-34: Grow the code-audit test fixtures from 11 to 14 lens pairs

- **Priority**: Must Have
- **Description**: `bin/tests/fixtures/code-audit/` provides a full-round fixture whose `README.md:33`
  documents `lenses-run.txt` as "the eleven lens IDs, one per line, with the `Round type: full`
  header". Several `wave7-smoke.sh` assertions count fixture files directly, so the fixture and the
  assertions must move together. A second fixture is needed for the auto-N/A composition, which has
  no analogue today.
- **Acceptance Criteria**:
  - [ ] The full-round fixture carries 14 `lens-L{N}.jsonl` files and 14 `lens-L{N}.md` files,
        `L1` through `L14`.
  - [ ] `bin/tests/fixtures/code-audit/README.md:33` documents 14 lens IDs, not eleven.
  - [ ] A **new** fixture provides the 13-plus-N/A composition: 13 lens pairs (no `L13`),
        a `lenses-run.txt` carrying the 13 IDs plus the `Lenses N/A:` header line, and a round record
        with `lenses_na: ["L13"]`.
  - [ ] A **negative** fixture provides the contract-violation case: `lenses_na: ["L13"]` but a
        `lens-L13.jsonl` present on disk, so `EDMV4-25`'s third downgrade reason is exercised.
  - [ ] The new JSONL fixture lines conform to the fixed schema
        (`{"schema":1,"id":null,"lens":"L{N}",...}`) exactly as the existing eleven do.
  - [ ] All fixture content is ASCII-only.
  - [ ] `wave7-smoke.sh`'s T24 AC0 assertions (`:1627`, `:1630`) count 14 files each and pass.
- **Dependencies**: `EDMV4-23`, `EDMV4-24`, `EDMV4-25`.
- **Target Components**: `plugins/edm/bin/tests/fixtures/code-audit/README.md:33`,
  `plugins/edm/bin/tests/fixtures/code-audit/` (fixture tree),
  `plugins/edm/bin/tests/wave7-smoke.sh:1627,1630`.

#### EDMV4-35: Documentation and user-facing surface sweep for the lens count

- **Priority**: Must Have
- **Description**: The lens count appears on surfaces a user sees before they ever run the plugin --
  the marketplace manifest description, the README's feature table, and `CLAUDE.md`'s agent-colour
  table. Leaving any of them at 11 makes the plugin describe itself inaccurately in its own
  storefront.
- **Acceptance Criteria**:
  - [ ] `plugins/edm/.claude-plugin/plugin.json:5`'s manifest `description` reads "14-lens code
        audit".
  - [ ] `.claude-plugin/marketplace.json`'s `edm` entry is checked for the same string and updated if
        present.
  - [ ] `plugins/edm/README.md:123,265,268` read 14 throughout ("14-lens exhaustive audit", "does not
        have to be the full fourteen lenses", "Reserve the full fourteen-lens round").
  - [ ] `plugins/edm/CLAUDE.md:211`'s agent-colour table row reads "all 14 `edm-audit-*` lenses +
        `edm-audit-synthesizer`".
  - [ ] `plugins/edm/CLAUDE.md:250`, `:333` and `:1000` read 14. `:333` is the D34 passage that is
        also `EDMV4-49`'s home paragraph -- the two edits must be reconciled, not applied twice.
        The same passage carries two further live counts at `:339` ("eleven") and `:342`
        ("thirteen"), owned by `EDMV4-33`; all four edits land in one pass.
  - [ ] `plugins/edm/CLAUDE.md:118-119` and `plugins/edm/README.md:204-205` -- the artifact-layout
        trees, whose illustrative listings end at `lens-L11` -- read `lens-L14`.
  - [ ] `plugins/edm/CLAUDE.md:368`'s contested-audit-set row reads 14 code-audit lenses and 18
        agents, matching its machine counterparts `wave7-smoke.sh:5386` and `:5402` (`EDMV4-32`).
        `EDMV4-30` AC3 cites this row as authority, so the two must not disagree.
  - [ ] **Line numbers in this AC are advisory.** Every site is located at edit time by its matched
        string, not by its line number -- `CLAUDE.md`'s numbers moved twice during this initiative
        and several cites here are known stale by 4-7 lines. A number that no longer matches is a
        cue to re-locate, not a site to skip.
  - [ ] `plugins/edm/skills/implement/SKILL.md:48,241` read 14.
  - [ ] `plugins/edm/evals/README.md:306` reads 14.
  - [ ] `plugins/edm/docs/audit-patterns/README.md:137`'s table row is either updated to 14 or
        explicitly retained as a dated historical seed row, with the choice recorded rather than left
        ambiguous.
  - [ ] `plugins/edm/docs/audit-patterns/code-audit.md` is inspected for lens-count-adjacent prose
        and updated where the count is asserted as current.
  - [ ] `plugins/edm/CHANGELOG.md` gains **one new entry** documenting the 11-to-14 change, the three
        new lenses by name and number, the `lenses_na` field, and the `round_type` derivation change.
        No historical entry is edited.
  - [ ] The `plugin.json` version is bumped and `.claude-plugin/marketplace.json`'s `edm` version is
        bumped to match, since the manifest description changed.
  - [ ] `claude plugin validate plugins/edm/` exits 0 after the manifest change.
- **Dependencies**: `EDMV4-31`, `EDMV4-33`.
- **Target Components**: `plugins/edm/.claude-plugin/plugin.json:4,5`,
  `.claude-plugin/marketplace.json`, `plugins/edm/README.md:123,265,268`,
  `plugins/edm/CLAUDE.md:118-119,211,250,333,368,1000`,
  `plugins/edm/README.md:204-205`, `plugins/edm/skills/implement/SKILL.md:48,241`,
  `plugins/edm/evals/README.md:306`, `plugins/edm/docs/audit-patterns/README.md:137`,
  `plugins/edm/docs/audit-patterns/code-audit.md`, `plugins/edm/CHANGELOG.md`.

---

### 6.6 Item 5.2 -- repo-readiness scorecard

#### EDMV4-36: A new `bin/edm-repo-readiness` script following house conventions

- **Priority**: Should Have
- **Description**: EDM measures *itself* via `/edm:metrics` -- time and cost per phase -- but never
  scores the *repository it is about to work in*, which is exactly the information that should feed
  the 4.3 classifier. ECC's `harness-audit.js` is not reusable: in repo mode its checks are almost
  entirely `fileExists` against ECC's own bundled paths (`getRepoChecks():388-657`), which is an ECC
  installation-completeness check rather than a readiness rubric. **Take the shape, reject the
  content.** Write EDM's own check table as a new `bin/` script following the conventions every
  existing script in `bin/` shares.
- **Acceptance Criteria**:
  - [ ] `plugins/edm/bin/edm-repo-readiness` exists, is executable, and is listed in
        `plugins/edm/CLAUDE.md Sec."bin/ helper scripts"`.
  - [ ] It sources `_edm-cli-lib.sh` and uses the sentinel-delimited `# EDM-HELP-BEGIN` /
        `# EDM-HELP-END` block extracted by the shared `print_help`, never a hardcoded `sed -n`
        range.
  - [ ] `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"` is computed once near the
        top, matching `edm-lint-artifacts:74`, `timing.sh:26`, `edm-compare-eval:39` and
        `edm-state:61`.
  - [ ] It carries a local two-argument `die()` helper (`msg`, `code="${2:-2}"`), present verbatim in
        `edm-compare-eval:44-48` and `run-eval.sh`.
  - [ ] Exit codes: **0** when the repository was scored, regardless of how low the score is; **2**
        for a usage or setup error. A low score is not a script failure, which is the split
        `edm-lint-artifacts` and `edm-compare-eval` both express in their own vocabularies.
  - [ ] Output follows the existing house split: human-readable text to stdout, machine-readable JSON
        to a **file** via `--json <path>`, produced with `jq -n`. It does **not** introduce a
        `--json`-to-stdout flag; no `bin/` script has one today, and ECC's text-or-JSON-to-stdout
        shape would be a new pattern here rather than an existing one.
  - [ ] `set -euo pipefail` is set, or a deliberate deviation is documented in-file with its reason,
        following `run-eval.sh`'s CA-074 precedent.
  - [ ] The script is bash 3.2 compatible (`EDMV4-55`) and adds no required binary beyond
        `bash`/`jq`/`git` (`EDMV4-56`).
- **Dependencies**: none. (See the `EDMV4-03` note in Sec.6's reading guide.)
- **Target Components**: `plugins/edm/bin/edm-repo-readiness` (new),
  `plugins/edm/bin/_edm-cli-lib.sh`, `plugins/edm/bin/edm-lint-artifacts:1-70,74`,
  `plugins/edm/bin/edm-compare-eval:2-33,39,44-48`, `plugins/edm/bin/tests/timing.sh:26`,
  `plugins/edm/CLAUDE.md Sec."bin/ helper scripts"`;
  shape source `ECC/scripts/harness-audit.js:396-404` (the eight-field check object).

#### EDMV4-37: Fixed categories, 0-10 normalization, conditional applicability, versioned rubric

- **Priority**: Should Have
- **Description**: Four properties of ECC's rubric shape are worth taking and are the whole of what
  transfers: a fixed category list each normalized 0-10 so scores are comparable across runs; a
  versioned rubric string so a score can be traced to the rubric that produced it; conditional
  applicability where the denominator adjusts rather than penalizing absence
  (`buildReport():977` filters categories on `max > 0`); and per-check determinism so the same commit
  always scores the same. Note correction 7: ECC's headline "11 checks / 29 points" for consumer mode
  undercounts -- `getConsumerChecks():827-941` unconditionally appends five GitHub checks worth 10
  more points at line 942, so the real surface is **16 checks / 39 points**. EDM should place shared
  checks deliberately rather than inheriting that ambiguity.
  **The initial category set is specified here.** v1.0.0 specified the scorecard's *shape*
  completely and its *content* not at all -- no requirement named a single category, check, point
  value or conditional marker -- which left a ticket writer unable to derive the check table and
  made the ECC-shape properties (0-10 normalization, conditional denominators, versioned rubric)
  meaningless, since there was nothing to normalize. The table below is the **initial** set; it is
  a starting rubric under `READINESS_RUBRIC_VERSION` and is expected to change, which is what the
  version string exists for.

  | Category | Raw points | Conditional? | Signal source (`EDMV4-38`) |
  |---|---|---|---|
  | **Methodology setup** | 10 | No | `check_permission_rules()` via the `PERM_RULES_MISSING` anomaly; presence of a project `CLAUDE.md`; `edm-state list` returning at least one initiative |
  | **State health** | 10 | No | `edm-state validate` anomaly output. Blocking-class anomalies cost more per hit than informational ones, and the split is declared in the script |
  | **Test stack** | 10 | **Yes** -- zero applicable checks when no test framework is detected at all | `test_frameworks_detected`, `edm-state get-coverage` |
  | **Coverage posture** | 10 | **Yes** -- conditional on Test stack being applicable | `edm-state get-coverage` against configured thresholds |
  | **Convergence history** | 10 | **Yes** -- conditional on at least one archived initiative existing | `edm-state metrics-report`, archived round records |
  | **Artifact hygiene** | 10 | No | `edm-lint-artifacts --all` exit status and violation count |

  Six categories, 60 raw points, each normalized to 0-10 and the overall score reported as the mean
  of **applicable** categories only. Three are conditional, so a greenfield repository with no tests
  and no history scores out of three categories rather than being penalized for the absence of
  things it cannot have -- which is the `applicableCategories` behaviour
  (`harness-audit.js:977` filters on `max > 0`) that is worth taking from ECC.
- **Acceptance Criteria**:
  - [ ] The six categories above are implemented with their stated point budgets and their stated
        conditional markers. A category's checks, its raw total and its conditional predicate are
        declared together in one place in the script.
  - [ ] The three conditional categories are marked as such in the JSON output, so a consumer can
        tell "scored 0" from "not applicable" without re-deriving the predicate.
  - [ ] The category list is fixed and declared once in the script. Each category is normalized to
        0-10.
  - [ ] `READINESS_RUBRIC_VERSION` is a bare top-level string constant, following
        `score-artifacts.sh:139`'s `SCORER_VERSION` precedent exactly rather than inventing a new
        versioning scheme.
  - [ ] The rubric version is written into every JSON output, and any future comparator refuses --
        rather than silently passes -- on a version mismatch, matching `edm-compare-eval:85-91`.
  - [ ] Categories with zero applicable checks are excluded from the denominator, not scored as
        zero. A smoke test asserts a repository lacking a conditional category's marker scores the
        same as one where that category is not defined.
  - [ ] Every check carries `id`, `category`, `points`, a `description`, a `pass` result, and a
        `fix:` string. The `fix:` string is the detail that makes the report actionable without a
        second pass, and is mandatory on every check, not only failing ones.
  - [ ] Checks are deterministic: two runs against the same commit produce identical scores. A smoke
        test runs the script twice and diffs the JSON.
  - [ ] No check scores the repository on whether EDM itself is installed. That is the self-serving
        pattern correction 7 exposes in ECC's own consumer mode (a 4-point "is ECC installed" check),
        and it measures nothing about readiness.
  - [ ] Checks shared across scopes are placed deliberately, and the script documents which category
        owns them, so the report's totals are unambiguous.
- **Dependencies**: `EDMV4-36`.
- **Target Components**: `plugins/edm/bin/edm-repo-readiness` (new),
  `plugins/edm/evals/score-artifacts.sh:139` (`SCORER_VERSION` precedent),
  `plugins/edm/bin/edm-compare-eval:85-91` (refuse-on-version-mismatch precedent);
  shape source `ECC/scripts/harness-audit.js:977` (`applicableCategories`), `:22`
  (`RUBRIC_VERSION`), `:827-943` (the consumer-mode check set and its appended GitHub checks).

#### EDMV4-38: Reuse the readiness signals EDM already computes

- **Priority**: Should Have
- **Description**: EDM already computes a battery of readiness-adjacent signals; they are simply not
  aggregated into named categories. The highest-leverage move is therefore not "write 20-30 new
  `fileExists` checks" -- ECC's actual implementation, which the analysis itself says not to port --
  but "aggregate signals `edm-state validate` / `session-start` / `get-coverage` already compute into
  named, 0-10-normalized categories under a versioned rubric". That is new categorization logic, not
  new detection logic, and it means one source of truth per signal rather than two implementations
  that can disagree.
- **Acceptance Criteria**:
  - [ ] Permission-rule presence is read from the existing `check_permission_rules()` result surfaced
        by `edm-state session-start` / the `PERM_RULES_MISSING` anomaly, not re-detected by scanning
        `.claude/settings*.json` a second time.
  - [ ] State-health signals are read from `edm-state validate`'s anomaly output
        (`OPEN_AUDIT_ROUND`, `TORN_TOKEN_LINES`, `SPEC_SWEEP_PENDING`, `OPEN_PARTIALS`,
        `CONVERGED_NO_APPROVAL`, and the rest), not re-derived from `.edm-state.json`.
  - [ ] Test-stack signals are read from `test_frameworks_detected` and `edm-state get-coverage`, not
        re-detected by scanning for framework config files.
  - [ ] Cost and duration history, where scored, is read from `edm-state metrics-report`.
  - [ ] Any signal the script genuinely must detect itself is documented in-file with one line
        explaining why no existing source covers it.
  - [ ] The script never writes to `.edm-state.json`. It is read-only with respect to state.
  - [ ] Running the script against a repository with no initiatives at all succeeds, scores what it
        can, and exits 0 rather than erroring.
- **Dependencies**: `EDMV4-36`, `EDMV4-37`.
- **Target Components**: `plugins/edm/bin/edm-repo-readiness` (new),
  `plugins/edm/bin/edm-state:1709-1927` (`state_anomalies`), `:4036-4059` (`cmd_validate`),
  `:4347+` (`cmd_session_start`), `check_permission_rules()`, `cmd_get_coverage`,
  `cmd_metrics_report`, `plugins/edm/CLAUDE.md Sec."Required setup: permission ask rules (EDMV3-T06)"`.

#### EDMV4-39: Feed the scorecard into the classifier and into `planning.md`

- **Priority**: Could Have
- **Description**: The scorecard's value is conditional on 4.3 landing -- a repository with no tests,
  no CI and no `CLAUDE.md` should route differently from a mature one, and the classifier is the
  consumer that would use that signal. Its findings are also exactly the kind of thing that belongs
  in `planning.md`. Construction is not blocked on 4.3, but this integration is, which is why it is
  the lowest-priority requirement in the initiative.
- **Acceptance Criteria**:
  - [ ] `skills/plan/SKILL.md` optionally runs `edm-repo-readiness` during Phase 1 and records its
        summary in `planning.md`.
  - [ ] The recorded summary names the rubric version alongside the score, so a score in an old
        `planning.md` is traceable to the rubric that produced it.
  - [ ] The 4.3 classifier may consult the score as an additional input to the design-ambiguity
        signal. It remains one input among three; it never overrides the security-trigger
        tie-breaker.
  - [ ] If the scorecard is unavailable or exits non-zero, Phase 1 proceeds unchanged. The dependency
        is advisory in both directions.
  - [ ] The integration is documented in `plugins/edm/CLAUDE.md` so a reader of `planning.md` knows
        where the score came from.
- **Dependencies**: `EDMV4-19`, `EDMV4-36`, `EDMV4-37`, `EDMV4-38`.
- **Target Components**: `plugins/edm/skills/plan/SKILL.md`,
  `plugins/edm/skills/orchestrator/SKILL.md` (Step 1b.5), `plugins/edm/bin/edm-repo-readiness` (new),
  `plugins/edm/CLAUDE.md`.

---

### 6.7 Item 5.3 -- hookify rules-as-data layer

#### EDMV4-40: JSON rule files, not ECC's YAML frontmatter (D7)

- **Priority**: Should Have
- **Description**: EDM's enforcement is entirely hardcoded bash -- `edm-lint-artifacts`,
  `edm-check-grants`, `edm-check-vocabulary`, the gate hooks. A team with its own conventions has no
  way to add enforcement without editing the plugin and carrying a fork. The rules-as-data layer
  closes that. **The rule format is JSON, per Gate 1 / D7**: jq-native, adds no required binary, and
  matches how every other structured file in `bin/` is consumed. ECC compatibility buys nothing --
  correction 3 established by exhaustive search that ECC has **no evaluator at all**, so there is
  nothing to stay compatible with; only the format *concept* was ever reusable, and EDM is free to
  choose a better-fitting one. There is zero YAML parsing anywhere in `bin/` today, so ECC's
  YAML-frontmatter format would need a from-scratch bash/awk YAML-subset parser or a new required
  binary.
- **Acceptance Criteria**:
  - [ ] Rule files are JSON, read with `jq`. No YAML parser is written and no YAML-capable binary is
        added.
  - [ ] Each rule carries: `name`, `enabled` (boolean), `event` (one of `file`, `stop`, `bash`),
        `action` (`warn` or `block`, defaulting to `warn`), `conditions` (an array), and `message`.
  - [ ] Each condition carries `field`, `operator` and `pattern`. **All** conditions must match for
        the rule to fire (AND semantics), stated explicitly in the format documentation.
  - [ ] Six operators are supported: `regex_match`, `contains`, `equals`, `not_contains`,
        `starts_with`, `ends_with`. Any other operator is a setup error naming the rule file and the
        offending operator.
  - [ ] Available `field` values are constrained per event and validated: `file_path`, `new_text`,
        `old_text`, `content` for `file`; `command` for `bash`. A field that does not belong to the
        rule's event is a setup error.
  - [ ] Rule files live under the project's tree at `.claude/edm-hookify/*.json` and are
        **source-controlled**, matching `CLAUDE.md`'s "source control IS the feature" principle
        rather than ECC's `.local.md`-plus-gitignore convention.
  - [ ] The format is documented once, with the naming convention (verb-first: `warn-*`, `block-*`,
        `require-*`) and the three failure modes ECC documents honestly -- patterns too broad
        (`log` matches "login" and "dialog"), too specific, and escaping traps.
  - [ ] A malformed rule file is a **setup error**: named on stderr, skipped, and the evaluator exits
        1. A malformed rule never blocks and never silently disables the whole rule set.
- **Dependencies**: none. (See the `EDMV4-03` note in Sec.6's reading guide.)
- **Target Components**: `plugins/edm/bin/edm-hookify` (new),
  `.claude/edm-hookify/` (new rule directory), `plugins/edm/CLAUDE.md` (format documentation),
  `plugins/edm/CLAUDE.md Sec."Artifact content conventions"` (rule 3, source control);
  format source `ECC/skills/hookify-rules/SKILL.md:12-64` (events, actions, fields, six operators,
  AND semantics -- concept only, no evaluator exists to inherit).

#### EDMV4-41: Build the evaluator from nothing, with one classify pass and N projections

- **Priority**: Should Have
- **Description**: EDM is not porting an existing evaluator and wiring it into a dispatcher -- it is
  **writing the evaluator from nothing**. `explorers/04` Sec.7 searched all of `scripts/`,
  `hooks/hooks.json` and all six operator names, and found the condition-matching engine exists only
  in `hookify-rules/SKILL.md` prose and its two translated locale copies; the three `/hookify*`
  commands only write, list and toggle rule files, and none consumes a rule at tool-call time. The
  cost model matters: a rules engine with N enabled rules faces the identical multiplying-cost
  problem `edm-lint-artifacts` already solved once, and the fix pattern -- one classify pass, N
  projections against a shared table -- transfers directly.
- **Acceptance Criteria**:
  - [ ] `plugins/edm/bin/edm-hookify` exists with two subcommands: `list` (enumerate enabled rules)
        and `eval <file|bash|stop>` reading a payload on stdin.
  - [ ] `eval` reads and evaluates **all** enabled rules for the event in a single `jq` pass. Per-call
        cost does not multiply with rule count. A smoke test with 1 rule and with 50 rules asserts
        the process count is identical.
  - [ ] `eval` prints one line per matched rule: `rule_id action message`.
  - [ ] The evaluator honours `enabled: false` and skips those rules entirely.
  - [ ] Regex evaluation is bounded so a pathological pattern cannot hang a hook that fires on every
        edit. **The mechanism is a documented input-size cap**, not a timeout: the payload text a
        rule is matched against is truncated to a stated byte ceiling before evaluation, and the
        ceiling and its rationale are stated in-file. `timeout(1)` is **not** used -- it is absent
        from stock macOS (it is a GNU coreutils binary, not a BSD one) and is outside the
        `bash`/`jq`/`git` required-binary set `EDMV4-56` pins, so depending on it would either add a
        required binary or silently do nothing on the plugin's primary development platform.
  - [ ] If a future change does introduce a timeout, it is guarded by `command -v timeout` with a
        documented no-timeout fallback, and the fallback path is the one asserted by the smoke
        suite -- since that is the path macOS takes.
  - [ ] A smoke test feeds an oversized payload and asserts the cap is applied and the evaluator
        still returns within the same order of magnitude as a normal call.
  - [ ] The evaluator never writes to any file. It is read-only.
  - [ ] A rule set with zero enabled rules exits 0 immediately, doing no `jq` work.
  - [ ] It follows the same conventions as `EDMV4-36` requires of `edm-repo-readiness`:
        `_edm-cli-lib.sh`, help sentinels, `SCRIPT_DIR`, `die()`.
  - [ ] `plugins/edm/CLAUDE.md Sec."bin/ helper scripts"` gains a row for `edm-hookify`.
- **Dependencies**: `EDMV4-40`.
- **Target Components**: `plugins/edm/bin/edm-hookify` (new),
  `plugins/edm/bin/edm-lint-artifacts:303-448` (`scan_md_files`, the one-classify-pass pattern),
  `:251-260` (`collect_md_files`), `:286-297` (`_lint_report_class_hits`, built to eliminate a
  four-times-copy-pasted per-class loop that caused a real CA-008 divergence),
  `plugins/edm/bin/_edm-cli-lib.sh`, `plugins/edm/CLAUDE.md Sec."bin/ helper scripts"`.

#### EDMV4-42: `action: block` requires explicit opt-in, with a two-tier exit contract

- **Priority**: Should Have
- **Description**: The analysis's own risk rating for 5.3 is "low, **if** `action: block` requires
  explicit opt-in per rule". That conditional is the whole safety argument, so it is a requirement
  rather than a note. The exit-code contract must match the existing violation-versus-setup-error
  split that `edm-lint-staged-artifacts` already expresses, because a rule that fires and says
  "block" is a categorically different event from a rule file that is malformed or unreadable, and
  conflating them means one team's typo silently blocks another team's commits.
- **Acceptance Criteria**:
  - [ ] `action` defaults to `warn` when the key is absent. A rule blocks only when it explicitly
        carries `"action": "block"`.
  - [ ] `edm-hookify eval` exit codes: **0** no rule matched or only `warn` rules matched; **1** setup
        error (malformed rule file, unknown operator, unreadable directory) -- **never blocking**;
        **2** at least one `block` rule matched.
  - [ ] A `warn` match writes its message to stderr and does not affect the exit code.
  - [ ] The consuming hook translates exit 2 into a refusal through its own established mechanism --
        `edm-gateguard`'s `emit_decision` for `file` events, `edm-stop-gate`'s exit 2 for `stop`
        events -- never by inventing a third mechanism.
  - [ ] Exit 1 from `edm-hookify` never escalates to a block in any consumer. A smoke test asserts a
        malformed rule file leaves an `Edit` and a `Stop` both unblocked.
  - [ ] The exit-code contract is documented in `plugins/edm/CLAUDE.md Sec."Hooks behavior"` in the
        same table form the existing rows use.
  - [ ] Rule files are ASCII-only and are covered by whichever lint invocation reaches
        `.claude/edm-hookify/`; if none does, the gap is stated rather than assumed closed
        (`EDMV4-57`).
- **Dependencies**: `EDMV4-40`, `EDMV4-41`.
- **Target Components**: `plugins/edm/bin/edm-hookify` (new),
  `plugins/edm/bin/edm-lint-staged-artifacts:7-10,150-158` (the two-tier precedent),
  `plugins/edm/bin/edm-gateguard` (new, the `file`-event consumer),
  `plugins/edm/bin/edm-stop-gate` (new, the `stop`-event consumer),
  `plugins/edm/CLAUDE.md Sec."Hooks behavior"`.

#### EDMV4-43: Event wiring, with the `bash` event gated on Spike A

- **Priority**: Should Have
- **Description**: Per AD4, hookify does not register its own `PreToolUse` block for file events;
  `edm-gateguard` evaluates `file`-event rules in-process after its own decision, and
  `edm-stop-gate` evaluates `stop`-event rules. Both surfaces then have exactly **one** EDM-authored
  owner, so the unverified multi-hook combination question is never asked. The one place it cannot be
  avoided is `bash` rules, which need a `Bash` matcher that overlaps the existing `git commit` block.
  If Spike A shows the host does not execute both, the dangerous outcome is not that the new block
  never fires -- it is that it **suppresses the commit lint**, silently disabling the plugin's only
  proven-working blocking hook.
- **Acceptance Criteria**:
  - [ ] `file`-event rules are evaluated by `edm-gateguard` on its allow path, inside Phase 6 only,
        using the same payload it already parsed. No second `PreToolUse` block is registered for
        file events.
  - [ ] `stop`-event rules are evaluated by `edm-stop-gate`. No second `Stop` matcher block is
        registered.
  - [ ] `bash`-event rules ship **only if** `EDMV4-01` records that the host executes every matching
        block on one tool call.
  - [ ] If Spike A shows otherwise, `bash` events are not shipped in this initiative and the
        limitation is documented in the rule-format documentation, so a user writing a `bash` rule is
        told plainly it will not fire rather than discovering it silently.
  - [ ] Under no circumstance is the existing `git commit` matcher block modified in this
        initiative. AD4's fallback -- folding `edm-lint-staged-artifacts` into a Bash dispatcher --
        is more invasive than the feature warrants and is recorded as a scope boundary rather than
        attempted.
  - [ ] A smoke test asserts that with hookify present and a `file` rule enabled, an `Edit` outside
        Phase 6 is still allowed with zero rule evaluation, so the rules layer cannot re-introduce
        per-edit cost on the common path.
  - [ ] `plugins/edm/CLAUDE.md Sec."Hooks behavior"` documents which events hookify serves and which
        it does not.
- **Dependencies**: `EDMV4-01`, `EDMV4-07`, `EDMV4-41`, `EDMV4-42`, `EDMV4-44`.
- **Target Components**: `plugins/edm/hooks/hooks.json:80-90` (unmodified),
  `plugins/edm/hooks/hooks.json:91-100`, `plugins/edm/bin/edm-gateguard` (new),
  `plugins/edm/bin/edm-stop-gate` (new), `plugins/edm/bin/edm-hookify` (new),
  `plugins/edm/CLAUDE.md Sec."Hooks behavior"`.

---

### 6.8 Item 5.4 -- Stop-hook completion gate

#### EDMV4-44: A single EDM-authored `Stop`-gate script, added as a second entry in the existing block

- **Priority**: Should Have
- **Description**: Today every anomaly in 5.4's scope is enforced no later than `edm-state archive`,
  the very end of an initiative. Surfacing them at `Stop` makes the debt visible the moment it is
  created rather than weeks later. EDM already has the query (`edm-state validate`) and already has a
  `Stop` hook (`checkpoint-if-active`) to extend, so this is **wiring, not new policy**. Per AD4 the
  new work is a **second entry in the existing `Stop` block's `hooks` array**, not a second matcher
  block.

  **The in-repo precedent for that shape is weaker than v1.0.0 claimed, and this requirement states
  it honestly.** `hooks.json:16-24` carries two entries in one `hooks` array, but they are a
  `"type": "command"` entry **and a `"type": "prompt"` entry** -- a heterogeneous pair. That the
  host runs a command alongside a prompt says nothing about whether it runs **two commands**, which
  is what AD4 proposes. A homogeneous `command`+`command` pair has **zero instances anywhere in
  this repository**. `architecture.md:130` states the qualifier; v1.0.0 dropped it and presented the
  shape as proven. It is not proven, which is why `EDMV4-01` must test it specifically and why this
  requirement does not ship on the assumption.

  **Prefix resolution is a real gap, not a detail.** `edm-state validate` requires a `<PREFIX>`
  argument and `die`s without one (`bin/edm-state:4037`: `[[ $# -eq 1 ]] || die "usage: edm-state
  validate <PREFIX>"`). A `Stop` hook receives no arguments and no prefix. Neither v1.0.0
  requirement stated how the gate obtains one, or what it does when more than one initiative is
  active.
- **Acceptance Criteria**:
  - [ ] **Prefix resolution.** `edm-stop-gate` resolves which initiative(s) to validate by calling
        `edm-state active-initiatives`, which lists initiatives with `current_phase` in 1-6 and
        requires no argument (`bin/edm-state:3900-3916`). It does not re-implement the sweep and
        does not guess a prefix from the working directory.
  - [ ] **Multi-initiative rule, stated.** When `active-initiatives` returns more than one, the gate
        runs `validate` for **each** and blocks if **any** returns a blocking-class anomaly, naming
        the specific initiative in the message. When it returns none, the gate exits **0** silently
        -- no output at all, since a repository with no active initiative has nothing to say at
        every `Stop`.
  - [ ] **Only blocking-class anomalies reach stderr, plus one informational count line.** The gate
        prints the full text of blocking-class anomalies and **suppresses per-anomaly informational
        output**, replacing it with a single line of the form
        `[EDM] <N> informational anomalies (run: edm-state validate <PREFIX>)`. Printing
        informational anomalies individually would fire on essentially every `Stop`:
        `PERM_RULES_MISSING` is present until permission rules are configured, one
        `ACTIVE_EXEMPTION` line appears **per skipped phase**, and `SIZE_UNKNOWN` and
        `SCHEMA_VERSION_MISSING` are routine. That is a significant noise regression on a hook that
        fires at the end of every turn, and noise on a gate is how a gate gets disabled.
  - [ ] A smoke test asserts the informational-only case produces exactly one line of output and
        exit 0, and that the count in that line is correct.
  - [ ] `plugins/edm/bin/edm-stop-gate` exists and owns the whole EDM `Stop` surface: it runs
        `edm-state validate`, honours only `blocking`-class anomalies, then evaluates `stop`-event
        hookify rules.
  - [ ] `hooks/hooks.json:91-100` gains `edm-stop-gate` as a **second entry** in the existing block's
        `hooks` array, after `checkpoint-if-active`. **No second `Stop` matcher block is added.**
  - [ ] The existing `checkpoint-if-active` entry is byte-identical after the change.
  - [ ] All operator text goes to **stderr**, never stdout. Stop hooks write feedback to stderr, and
        a raw JSON echo to stdout is the documented failure mode
        (`ECC/skills/delivery-gate/hooks/quality-gate.py:131-133` records the same constraint from
        the other side).
  - [ ] Exit codes: **0** continue, **2** block. There is no third code.
  - [ ] Any internal error -- `edm-state` off `PATH`, `jq` missing, no resolvable initiative,
        `validate` itself failing -- exits **0**. Only a genuine `blocking`-class anomaly or a
        hookify `block` match returns 2.
  - [ ] `command -v edm-stop-gate >/dev/null 2>&1 || exit 0` guards the hook body, mirroring the
        existing entries.
  - [ ] `EDMV4-01`'s **two-`command`-entries** experiment confirms both entries execute, and that
        the second entry's exit code is honoured, **before this ships**. The
        `command`-plus-`prompt` pair at `hooks.json:16-24` does not establish this and must not be
        cited as if it did. If the experiment shows only the first `command` entry runs, or that the
        second's exit 2 is ignored, this design does not work and a second `Stop` **matcher block**
        -- the alternative `architecture.md` rejected -- is re-presented at a gate rather than
        shipped on an assumption.
  - [ ] `plugins/edm/CLAUDE.md Sec."Hooks behavior"`'s table gains a row for the new entry, and the
        existing `Stop` and `PreCompact` row is updated to reflect that `Stop` now carries two
        entries while `PreCompact` still carries one -- the collapse of those two events into one
        table row no longer holds.
- **Dependencies**: `EDMV4-01`, `EDMV4-06`.
- **Target Components**: `plugins/edm/bin/edm-stop-gate` (new),
  `plugins/edm/hooks/hooks.json:91-100`, `hooks.json:16-24` (the `command`-plus-`prompt` pair --
  the **nearest** in-repo shape, **not** the homogeneous pair this design needs),
  `plugins/edm/bin/edm-state:4036-4059` (`cmd_validate`), **`:4037`** (the `<PREFIX>`-required
  `die` that makes prefix resolution mandatory), `:3900-3916` (`cmd_active_initiatives`, the
  resolver), `:1709-1927` (`state_anomalies`, for the informational classes that must not be
  printed per-anomaly), `plugins/edm/CLAUDE.md Sec."Hooks behavior"`.

#### EDMV4-45: Warn by default, block only on the unambiguous subset

- **Priority**: Should Have
- **Description**: ECC's discipline alongside the pattern is: warn by default, block only on the
  subset that is unambiguous. EDM already applies exactly this reasoning to `spec_swept`, where only
  the explicit string `no` blocks and an absent field never does. The classification is not a
  judgment call here -- `cmd_validate` already classifies every anomaly, and the Stop gate must honour
  that existing classification rather than inventing a second one. Three of the analysis's four named
  candidates are verified to exist, and their current classifications are correct for Stop-time use:
  `OPEN_PARTIALS` already **blocks** at `validate`, so surfacing it at `Stop` is a timing improvement
  with no new classification risk; `OPEN_AUDIT_ROUND` and `SPEC_SWEEP_PENDING` are informational by
  design, and blocking on either would fire on every `Stop` for the remainder of a round in which
  anything is mid-flight.
- **Acceptance Criteria**:
  - [ ] `edm-stop-gate` blocks **only** when `edm-state validate` emits at least one line whose first
        field is literally `blocking`, exactly the condition `cmd_validate:4048-4054` already uses
        for its own exit 3.
  - [ ] The `<PREFIX>` each `validate` call needs comes from `edm-state active-initiatives`
        (`EDMV4-44`), never from a guess, a cwd derivation or a hardcoded value. `cmd_validate`
        `die`s without exactly one argument (`bin/edm-state:4037`), so an unresolved prefix must
        produce a clean exit 0 from the gate rather than a `die` surfaced at every `Stop`.
  - [ ] Informational anomalies are **not** printed individually, per `EDMV4-44` -- only their
        count. This requirement's warn-versus-block classification governs which anomalies *block*;
        it does not license printing every informational line at every `Stop`.
  - [ ] It does not re-classify any anomaly. It contains no per-anomaly logic and no allow-list or
        deny-list of anomaly names -- it reads the class field.
  - [ ] `OPEN_PARTIALS` blocks at `Stop`, because it already blocks at `validate`
        (`bin/edm-state:1827-1847`) and at `archive` (`:3260`).
  - [ ] `OPEN_AUDIT_ROUND` warns and does not block, matching its informational classification and
        the explicit rationale at `bin/edm-state:1786-1789` that a round in progress is the normal
        state for most of an audit's duration.
  - [ ] `SPEC_SWEEP_PENDING` warns and does not block, matching its informational classification and
        the rationale at `:1911-1913` that its blocking enforcement already lives at
        `audit-converged` and `approve-gate`.
  - [ ] The "phase started with no `completed_at`" anomaly is **not** implemented, per `EDMV4-06`.
        The gate ships the three verified anomalies. If Gate 2 rejects the descope, this requirement
        gains a dependency on the new anomaly's design.
  - [ ] When it blocks, the stderr message names the specific anomaly and the initiative, so the
        operator can act without running `validate` themselves.
  - [ ] A smoke test asserts a blocking anomaly returns 2 and an informational-only anomaly set
        returns 0.
  - [ ] A smoke test asserts that a repository with no active initiative returns 0 and produces no
        output.
- **Dependencies**: `EDMV4-06`, `EDMV4-44`.
- **Target Components**: `plugins/edm/bin/edm-stop-gate` (new),
  `plugins/edm/bin/edm-state:4036-4059` (`cmd_validate`, the `blocking`-class test at `:4048-4054`),
  `:1827-1847` (`OPEN_PARTIALS`), `:1784-1801` and `:1786-1789` (`OPEN_AUDIT_ROUND` and its
  informational rationale), `:1907-1926` and `:1911-1913` (`SPEC_SWEEP_PENDING`), `:3260`
  (`archive`'s own `OPEN_PARTIALS` check);
  discipline source `ECC/skills/delivery-gate/hooks/quality-gate.py:149-214`.

---

### 6.9 Item 5.5 -- codemaps, interim only

#### EDMV4-46: The `SRD/.codemap.md` interim, written by the first explorer

- **Priority**: Should Have
- **Description**: The idea is sound -- a deterministic, token-lean map of a repository's **current**
  architecture, so agents read a compact artifact instead of re-deriving structure by grepping the
  tree. ECC's generator is not worth porting: correction 11 confirms its two most valuable sections,
  Data Flow and External Dependencies, are literal unconditional template strings at
  `generate.ts:225-231`, not computed from anything, so the script is a file inventory with an
  architecture-shaped outline around it. Its file-to-area classifier is also first-match and
  order-dependent, and silently drops files matching no area. Per Gate 1 / D11, **no generator is
  built**: the first explorer of an initiative writes a reusable current-architecture codemap that
  later initiatives read and refresh. This is the cheapest way to test a premise the analysis itself
  flags as unmeasured.
- **Acceptance Criteria**:
  - [ ] `agents/edm-explorer.md` instructs the first explorer of an initiative to write or refresh
        `SRD/.codemap.md`.
  - [ ] The instruction states plainly that a codemap is the **current** architecture and
        `architecture.md` is the **target** architecture, so the two artifacts do not duplicate or
        contradict each other. This distinction is the whole reason the file lives at `SRD/` root
        rather than inside an initiative directory.
  - [ ] `SRD/.codemap.md` lives at the `${user_config.srd_root}` root, not inside any one
        initiative's directory, since it is shared across initiatives.
  - [ ] On a later initiative, the first explorer **reads** the existing codemap and refreshes it
        rather than rewriting it from scratch, and records what it changed.
  - [ ] The codemap has no template sections that are placeholders. A section with nothing real to
        say is **omitted**, not filled with an instruction to the reader -- the exact failure ECC's
        generator ships.
  - [ ] **No generator script is written.** No `bin/` script produces or validates the codemap.
  - [ ] The codemap is ASCII-only, **and the gap in its automatic coverage is stated as fact rather
        than assumed closed.** `edm-lint-artifacts` does **not** reach `SRD/.codemap.md` through any
        automatic invocation: prefix mode resolves a single initiative directory, and `--all`
        iterates the initiative directories `edm-state list --paths` returns. Only the manual
        `--path` mode reaches the `SRD/` root, and nothing invokes it automatically -- the
        git-commit hook runs prefix mode. The codemap is therefore covered by `EDMV4-57`'s **manual**
        `--path` sweep, which is named as a required Definition-of-Done step, and by nothing else.
        v1.0.0 asserted the opposite.
  - [ ] `agents/edm-explorer.md`'s instruction states the ASCII-only requirement inline, since the
        writing agent cannot rely on a lint pass catching a violation before the file is committed.
  - [ ] `plugins/edm/CLAUDE.md Sec."Project artifact layout"` documents `SRD/.codemap.md` as a
        `Should`/`on-demand` slot with its current-versus-target distinction stated.
- **Dependencies**: none. (See the `EDMV4-03` note in Sec.6's reading guide.)
- **Target Components**: `plugins/edm/agents/edm-explorer.md`,
  `plugins/edm/CLAUDE.md Sec."Project artifact layout"`,
  `SRD/.codemap.md` (new, project-resident);
  rejected source `ECC/scripts/codemaps/generate.ts:36-59` (five area patterns), `:107-137`
  (first-match classification), `:225-231` (the placeholder sections).

---

### 6.10 `EDMV4-T01` -- Mermaid lint budget re-framing

#### EDMV4-47: Re-derive the Mermaid-class budget as an absolute ceiling plus a sized ratio

- **Priority**: Should Have
- **Description**: The inherited ticket assumed a 50-initiative fixture generator had to be written.
  It already exists (`timing.sh --generate-fixture`, default `N_INITIATIVES=50` at `:217`, wired into
  `--all-lint`), as do `--lint`, `--all-lint` and `--mermaid-ratio`, all against the post-`ea31ce8`
  one-awk-per-file class-4 scan. The remaining work is a **budget framing fix**, and the CHANGELOG
  states the objection precisely: "A bare ratio with no stated input size and no absolute floor is
  dominated by fixed process overhead: it reads differently on every machine, and it moves when
  unrelated code gets faster. That is exactly what happened here, twice, in both directions." The
  AC5 rewrite (`d591b92`) made the baseline roughly 40x faster without touching the Mermaid class and
  the ratio got **worse**, 2.26x to 3.40x, because class 4 became the dominant cost rather than a
  marginal one; optimizing class 4 (`ea31ce8`) then brought it to 1.12x. The same budget read miss,
  worse-miss, then pass across three commits, only one of which touched the code it measures.
- **Acceptance Criteria**:
  - [ ] The Mermaid-class budget is restated as a **conditional**: an absolute millisecond ceiling
        plus a ratio that binds only above a stated input-size floor, with the floor expressed in
        both files and lines.
  - [ ] The restated budget is quoted **together with its input size**, per the rule
        `CLAUDE.md Sec."edm-lint-artifacts latency budgets"` already states for the other two
        budgets. A bare ratio does not survive this change.
  - [ ] The absolute floor below which the ratio does not bind is stated numerically, with one
        sentence on why (fixed process overhead dominates below it).
  - [ ] `bin/tests/timing.sh --mermaid-ratio`'s printed budget line at `:426` is updated to emit the
        new conditional form, not the bare `budget: <= 1.40x`.
  - [ ] The existing `ratio=UNMEASURABLE` refusal at `:419-423` (the G37/CA-197 fix that refuses
        rather than reporting a fabricated ratio when either p95 measures 0 ms) is preserved
        unchanged.
  - [ ] `CLAUDE.md`'s latency-budget table gains or amends a row for the Mermaid budget in the same
        three-column form the commit-path and full-repo-sweep rows use (budget, invocation, fixture
        the ceiling is stated against).
  - [ ] The CHANGELOG note at `:433-450` is updated to record that the re-derivation has landed,
        replacing "The re-derivation is the one piece of EDMV3-T67's budget work that remains open".
        The AC6 row at `:393` is left as the historical record of the miss and is **not** rewritten.
  - [ ] `bin/tests/timing.sh --self-test` still passes, including the G35/CA-311 assertion pinning
        the nearest-rank p95 index.
- **Dependencies**: none. (See the `EDMV4-03` note in Sec.6's reading guide.)
- **Target Components**: `plugins/edm/bin/tests/timing.sh:386-428` (`--mermaid-ratio`), `:426` (the
  printed budget), `:419-423` (the UNMEASURABLE refusal), `:217,239-253` (`--generate-fixture`),
  `plugins/edm/CLAUDE.md Sec."edm-lint-artifacts latency budgets (EDMV3-T67 AC5/AC7)"`,
  `plugins/edm/CHANGELOG.md:393,433-450`.

#### EDMV4-48: Re-measure against the fixture the AC actually names, and record the figure

- **Priority**: Should Have
- **Description**: The CHANGELOG records a second, separate defect in the original measurement: the
  recorded 2.26x "was taken on a 5-file fixture", so the original figure never answered the AC either
  way, and the budget needs "re-measuring on the 50-initiative fixture the AC actually names". A
  green number against an unstated fixture size recreates the same defect in the opposite direction,
  which is why the AC6 row reads "PASS on the number" rather than PASS.

  **`--mermaid-ratio` cannot be pointed at the 50-initiative fixture as it stands, and this
  requirement says so rather than assuming it can.** The mode builds its **own** scratch tree
  containing exactly one initiative, `TIMMR` (`timing.sh:397-400`), and **ignores `DIR` entirely**;
  its size knobs are `--files` (default `N_FILES=30`) and `--lines-per-file` (default
  `N_LINES_PER_FILE=333`), giving 30 files / 9,990 lines. `N_INITIATIVES=50` is consumed only by
  `--generate-fixture` (`:246`), a different mode. The CHANGELOG's phrase "the 50-initiative fixture
  the AC actually names" describes what `--all-lint` measures, not what `--mermaid-ratio` measures.
  The first AC below resolves the mismatch explicitly rather than leaving a ticket writer to
  discover that `--dir` is silently ignored.
- **Acceptance Criteria**:
  - [ ] **The fixture question is settled first, and the choice is recorded.** Exactly one of:
        **(a)** `--mermaid-ratio` gains a `--dir` arm that reuses `--all-lint`'s existing resolver
        (`export EDM_SRD_ROOT="${DIR}/SRD"`, `timing.sh:438-439`) and appends its mermaid fences
        into that tree instead of building `TIMMR`, with the same `[[ -n "$DIR" ]]` usage guard and
        the same measure-what-is-there discipline `--all-lint` uses to avoid misreporting fixture
        size (CA-073); or **(b)** the 50-initiative framing is **dropped** and the budget is stated
        against `--mermaid-ratio`'s real fixture -- **30 files / 9,990 lines, single initiative,
        20-sample nearest-rank p95**. Option (b) is the default, since it requires no harness change
        and the Mermaid class is a per-line scan whose cost tracks file and line count rather than
        initiative count. Whichever is chosen, Sec.9.1's fixture column is corrected to match.
  - [ ] `--mermaid-ratio` is re-run against a fixture whose size is stated, and the new figure is
        recorded together with that size.
  - [ ] The re-measurement uses the 20-sample nearest-rank p95 harness (`_P95_SAMPLE_COUNT`), not a
        smaller sample count. `N=20` is the smallest count where `ceil(0.95*20)=19 < 20`, making
        `p95_ms` a real 95th-percentile figure rather than a relabeled maximum.
  - [ ] The re-measurement confirms or refutes that the 1.12x figure is still current after the D4
        `plugin.json` reconciliation and after this initiative's own changes.
  - [ ] The measured figure is recorded in `CHANGELOG.md` in the new entry (`EDMV4-35`), never as an
        edit to the historical EDMV3-T67 table.
  - [ ] Explorer 01's third riskiest assumption is closed explicitly: the reconciliation states
        whether the "budget is still malformed" objection was already addressed elsewhere between
        the CHANGELOG entry and this initiative, and records the answer.
  - [ ] No optimization work is done under this requirement. It measures and records; if the
        re-derived budget is missed, that is a recorded miss for its own follow-on, matching
        EDMV3-T67's own Out of Scope discipline.
- **Dependencies**: `EDMV4-47`.
- **Target Components**: `plugins/edm/bin/tests/timing.sh:386-428` (`--mermaid-ratio`), `:397-400`
  (the single-initiative `TIMMR` scratch tree it builds and the `DIR` it ignores), `:219-220`
  (`N_FILES=30`, `N_LINES_PER_FILE=333` -- the real fixture size), `:217` (`N_INITIATIVES=50`,
  consumed only by `--generate-fixture`), `:438-439` (`--all-lint`'s `--dir` resolver, the one
  option (a) would reuse), `plugins/edm/bin/tests/timing.sh` (`_P95_SAMPLE_COUNT`, `--self-test`),
  `plugins/edm/CHANGELOG.md`, `plugins/edm/bin/edm-lint-artifacts:214-248` (`mermaid_scan_awk`, the
  code being measured), `:225-246` (`_MSA_PROG_CACHE`, the CA-472 fd-leak fix).

---

### 6.11 `EDMV4-T04` -- by-name reference anchoring

#### EDMV4-49: Anchor all 14 verified files, not the eight `CLAUDE.md` names

- **Priority**: Must Have
- **Description**: A bare `` CLAUDE.md Sec."..." `` reference in a prompt **does not resolve** from an
  installed plugin cache -- D22 verified this against Claude Code 2.1.220: plugin-root `CLAUDE.md` is
  never loaded as runtime context, and an installed cache directory is not path-adjacent to the
  project it is installed into, so the reference either fails to resolve or silently resolves to the
  target project's own unrelated `CLAUDE.md`. D34 anchored thirteen files (the eleven lenses, the
  synthesizer, and `edm-srd-auditor`). `CLAUDE.md` names eight remaining touch points. The **verified
  unanchored set is 14** (5 agents + 9 skills): `CLAUDE.md`'s own list misses `edm-qc-auditor.md`,
  `verify-runtime/`, `push-jira/`, `orchestrator/`, `metrics/` and `code-audit/SKILL.md`, all
  carrying the identical defect. A ticket scoped to the named eight under-delivers against what
  "close the ordering gap" actually requires.
- **Acceptance Criteria**:
  - [ ] All **14** files are anchored: `agents/edm-architect.md`, `agents/edm-srd-writer.md`,
        `agents/edm-ticket-writer.md`, `agents/edm-ticket-auditor.md`, `agents/edm-qc-auditor.md`,
        `skills/srd/SKILL.md`, `skills/tickets/SKILL.md`, `skills/audit-srd/SKILL.md`,
        `skills/audit-tickets/SKILL.md`, `skills/verify-runtime/SKILL.md`,
        `skills/push-jira/SKILL.md`, `skills/orchestrator/SKILL.md`, `skills/metrics/SKILL.md`,
        `skills/code-audit/SKILL.md`.
  - [ ] The pattern applied is exactly the one already in use, verified identical at
        `edm-audit-logic.md:69`, `edm-audit-security.md:154-157`, `edm-audit-synthesizer.md:87` and
        `edm-srd-auditor.md:38-42`: **keep** the original `` CLAUDE.md Sec."..." `` citation, and
        **append** the `Read docs/canonical-sections.md` sentence immediately after it, carrying the
        "resolved relative to the EDM plugin's own root -- `plugins/edm/` in this repository, or the
        installed plugin's cache root, never the caller's cwd" qualifier verbatim.
  - [ ] Every citation **site** is anchored, not one per file. `agents/edm-architect.md` carries the
        Mermaid reference at both `:31` and `:89`; `skills/orchestrator/SKILL.md` carries multiple
        references to four different sections. Each gets the sentence.
  - [ ] The original citation is never deleted -- it still resolves for a human reading the file
        in-repo, which is a different and still-valid audience.
  - [ ] `plugins/edm/CLAUDE.md`'s own D34 passage is updated: the eight-file list is replaced with the
        verified fourteen, and the "residual scope opened as a named follow-on ticket, `EDMV4-T04`"
        sentence is updated to record that the ticket has landed. The stale
        `EDMV4__lint-and-pipeline-budgets` directory name in the same passage is fixed
        (`EDMV4-04`).
  - [ ] `bin/edm-check-grants` gains an assertion that no file under `skills/` or `agents/` carries a
        bare `` CLAUDE.md Sec."..." `` reference without an adjacent canonical-sections anchor, so
        the class cannot regress.
  - [ ] **No file is anchored until every section it cites is known to resolve.** Before any
        anchoring edit lands, `EDMV4-51`'s enumeration is complete and every orphan it found is
        resolved. Anchoring a citation whose named section has no mirror sends a reader to a
        document that does not contain the section -- worse than the bare form, because it looks
        fixed. This is not a stylistic preference: **five of the 14 files carry orphaned citations
        at 8 sites naming 6 distinct sections**, tabulated in `EDMV4-50`.
  - [ ] After the change, a grep for `` CLAUDE.md Sec\." `` across `skills/` and `agents/` returns
        only anchored sites, **and** every anchored site's named section exists in
        `docs/canonical-sections.md`. The first clause alone is satisfiable by anchoring four skills
        to sections that do not exist, which is exactly what v1.0.0's ordering would have produced.
- **Dependencies**: `EDMV4-50`, `EDMV4-51`. **The `EDMV4-51` direction is inverted from v1.0.0**,
  which made `EDMV4-51` (Should Have) depend on this Must Have and therefore scheduled it after.
  Executed that way, the Must-Have pair anchors four skills to six sections of which only one
  exists, and the sweep that would have caught it runs afterwards -- if at all, being lower
  priority. Orphan enumeration completes **first**.
- **Target Components**: the 14 files above; `plugins/edm/agents/edm-audit-logic.md:69`,
  `plugins/edm/agents/edm-srd-auditor.md:38-42` (the two verbatim pattern exemplars),
  `plugins/edm/docs/canonical-sections.md`,
  `plugins/edm/CLAUDE.md Sec."By-name reference resolution from an installed plugin cache (EDMV3-T41)"`
  (the D34 passage, around `:333` and `:352` in the working tree),
  `plugins/edm/bin/edm-check-grants`.

#### EDMV4-50: Add "Unverifiable acceptance criteria (D15)" as a third generated canonical section

- **Priority**: Must Have
- **Description**: `docs/canonical-sections.md` generates **only two** sections -- "Severity
  vocabulary" and "Mermaid diagram conventions". Anchoring a file to any other section name points a
  reader at a document that does not contain the section they were sent to find.

  **The orphan set is not one file.** v1.0.0 framed this as "one of the 14 files needs a materially
  different fix shape from the other 13", which is factually false. **Five of the 14 files carry
  orphaned citations, at 8 sites naming 6 distinct sections**, only one of which v1.0.0 addressed:

  | Site | Section cited | Status and resolution route |
  |---|---|---|
  | `agents/edm-qc-auditor.md:39` | `Unverifiable acceptance criteria (D15)` | Orphan. **Add to the generator** (D10's route, below) |
  | `skills/verify-runtime/SKILL.md:31,39,147` | `Unverifiable acceptance criteria (D15)` | Orphan, **three sites**, named nowhere in v1.0.0. Same fix as the row above -- adding D15 to the generator resolves all four D15 sites at once |
  | `skills/orchestrator/SKILL.md:113,200` | `EDM mode matrix` | Orphan by **name mismatch**: the real heading is `## EDM mode matrix (EDMV3-T38)`. See the heading-mismatch route below |
  | `skills/metrics/SKILL.md:74`, `skills/orchestrator/SKILL.md:200` | `Phase Timing Guidelines` | Orphan by **name mismatch**: the real heading carries `(EDMV3-T38)`. Same route |
  | `skills/orchestrator/SKILL.md:199` | `Project artifact layout` | Orphan, but an **exact heading match exists** -- add to the generator |
  | `skills/push-jira/SKILL.md:36` | `Optional: Jira synchronization` | Orphan, exact match available -- add to the generator |
  | `skills/orchestrator/SKILL.md:28,152,196` | `Skill-tool composition` | Orphan, **and not a `##` heading at all** -- it is bold inline text at `CLAUDE.md:24`. See the not-a-heading route below |

  **Three resolution routes, chosen per case and recorded.**

  1. **Add to the generator.** Available when the cited name matches a `##` heading exactly.
     Covers D15, `Project artifact layout` and `Optional: Jira synchronization`.
  2. **Heading mismatch** (`EDM mode matrix`, `Phase Timing Guidelines`). `extract_section`
     (`bin/edm-sync-canonical-sections:72-79`) matches `"## ${heading}"` **exactly**, so neither
     name can be added to the generator as cited. Two sub-options, and the choice is recorded per
     case: **(a)** update the citing sites to the real heading including its `(EDMV3-T38)` suffix,
     then add that exact string to the generator -- preferred, because it changes prompts rather
     than a by-name-referenced heading; or **(b)** rename the `CLAUDE.md` heading to drop the
     suffix, which per the Mermaid convention requires updating **every** reference to it in the
     same commit and is therefore the wider blast radius. Option (a) is the default and (b) needs a
     stated reason.
  3. **Not a heading** (`Skill-tool composition`, bold inline text at `CLAUDE.md:24`). The generator
     cannot extract it at all. Two options: **(a)** promote it to a real `##` heading in `CLAUDE.md`
     and add it to the generator, or **(b)** inline the rule at the three citation sites and drop
     the `Sec."..."` form, which `EDMV4-51` AC3 already names as a legitimate route for short
     rules. Whichever is chosen is recorded; what is **not** acceptable is anchoring
     `skills/orchestrator/SKILL.md` to a section name that can never resolve.

  Per D10 the D15 route requires re-running the generator and re-verifying its drift assertion in
  the same change -- `docs/canonical-sections.md` is a generated, byte-identical mirror, and
  hand-editing it is precisely the drift `--check` exists to catch.
- **Acceptance Criteria**:
  - [ ] `bin/edm-sync-canonical-sections` generates a third section from
        `CLAUDE.md Sec."Unverifiable acceptance criteria (D15)"`, byte-identical and one-directional,
        exactly as it already does for the other two.
  - [ ] `docs/canonical-sections.md` is **regenerated by the script**, never hand-edited.
  - [ ] `bash plugins/edm/bin/edm-sync-canonical-sections --check` exits 0 after the regeneration,
        and exits 1 if either file is subsequently edited out of step. A smoke test proves both
        directions.
  - [ ] **All four D15 citation sites** are anchored and their target now exists:
        `agents/edm-qc-auditor.md:39` and `skills/verify-runtime/SKILL.md:31`, `:39`, `:147`. The
        three `verify-runtime` sites carry the identical defect and are resolved by the identical
        generator addition; v1.0.0 named none of them.
  - [ ] `agents/edm-qc-auditor.md:70`'s `` Sec."Severity vocabulary" `` citation is anchored in the
        same pass.
  - [ ] Each of the other five orphaned section names in the table above is resolved by one of the
        three named routes, the choice is recorded per case in `decisions.md`, and no citing site is
        left anchored to a name that cannot resolve.
  - [ ] `CLAUDE.md`'s own note below the Mermaid section -- which currently says both the Severity
        and Mermaid sections are generated -- is updated to name the true final count of generated
        sections, which is three **plus** whatever the route-1 resolutions above add. The note's
        number is derived from the generator's actual section list at edit time, not assumed.
  - [ ] **The two existing wave6 assertions are extended, and a third pair is added.** There is no
        assertion **counting** generated sections anywhere in the suite, so v1.0.0's AC7 ("any smoke
        assertion counting generated sections is updated from two to three") was vacuously
        satisfiable -- the D15 section would have shipped with zero coverage. What exists at
        `bin/tests/wave6-smoke.sh:4052-4119` is two named per-section **presence** checks
        (`:4074-4075` Severity, `:4076-4077` Mermaid) and two per-section **byte-identity** diffs
        (`:4110-4114` Severity, `:4115-4119` Mermaid). This requirement adds:
    - a third presence check asserting `## Unverifiable acceptance criteria (D15) (canonical)`
      appears in the generated file, mirroring the form at `:4076-4077`;
    - a third byte-identity diff extracting the D15 span from both `CLAUDE.md` and the generated
      copy with the same `awk` idiom and asserting they are identical, mirroring `:4115-4119`;
    - one further presence-plus-diff pair per section added by a route-1 resolution above.
  - [ ] The D15 section heading string in `CLAUDE.md` is unchanged, since it is referenced by name;
        only the generated mirror is added.
- **Dependencies**: none. (See the `EDMV4-03` note in Sec.6's reading guide.)
- **Blocks**: `EDMV4-49`.
- **Target Components**: `plugins/edm/bin/edm-sync-canonical-sections`, `:72-79`
  (`extract_section`'s exact `"## ${heading}"` match, which is why the two heading-mismatch cases
  cannot simply be added), `plugins/edm/docs/canonical-sections.md`,
  `plugins/edm/CLAUDE.md Sec."Unverifiable acceptance criteria (D15)"`,
  `plugins/edm/CLAUDE.md Sec."By-name reference resolution from an installed plugin cache (EDMV3-T41)"`,
  `plugins/edm/CLAUDE.md:24` (`Skill-tool composition`, bold inline text and **not** a heading),
  `plugins/edm/agents/edm-qc-auditor.md:39,70`,
  `plugins/edm/skills/verify-runtime/SKILL.md:31,39,147` (the three unnamed D15 sites),
  `plugins/edm/skills/orchestrator/SKILL.md:28,113,152,196,199,200`,
  `plugins/edm/skills/metrics/SKILL.md:74`, `plugins/edm/skills/push-jira/SKILL.md:36`,
  **`plugins/edm/bin/tests/wave6-smoke.sh:4052-4119`** -- the canonical-section assertions live in
  **wave6**, not wave7. `wave6-smoke.sh:4055-4058` carries a comment recording that **EDMV3-T41's
  own ticket made this identical wrong citation** ("the ticket's own Target Components name
  plugins/edm/bin/tests/wave7-smoke.sh for the AC5 byte-identity case ... the equivalent case is
  implemented here instead"). v1.0.0 reproduced the error a second time; a ticket writer following
  it would have edited the wrong suite file and found nothing to change.

#### EDMV4-51: Enumerate every orphaned citation, before anything is anchored

- **Priority**: Must Have
- **Priority note**: raised from Should Have in v1.0.0 (audit P0-3). It is the requirement that
  determines whether `EDMV4-49` and `EDMV4-50` -- both Must Have -- can be executed correctly at
  all. `explorers/03`'s assumption that `edm-qc-auditor.md`'s D15 reference was the only orphan is
  **verified false**: five files, 8 sites, 6 distinct section names (`EDMV4-50`'s table). A
  Should-Have sweep scheduled after two Must-Have anchoring requirements is a sweep that runs after
  the damage.
- **Description**: An orphaned citation is a `` CLAUDE.md Sec."..." `` reference whose target
  section has no `canonical-sections.md` mirror. Anchoring one produces a reference that resolves to
  a document lacking the section -- **worse than the bare form because it looks fixed**, and the
  reader who follows it has no reason to suspect the anchor rather than their own search. The
  enumeration must therefore be complete and resolved before `EDMV4-49` appends a single anchor
  sentence.

  `EDMV4-50`'s table records the orphans found so far and their resolution routes. This requirement
  owns proving that table **complete** -- the explorer found its instances by grep during the T04
  sweep and did not cross-check all 14 files' citations against the mirror -- and owns the
  regression guard that stops the class returning.
- **Acceptance Criteria**:
  - [ ] Every distinct section name cited via `` CLAUDE.md Sec."..." `` anywhere under `skills/` and
        `agents/` is enumerated, with **every site** of each, not one row per file.
  - [ ] Each is cross-checked against `docs/canonical-sections.md`'s generated section list **by
        exact string**, since `extract_section` (`bin/edm-sync-canonical-sections:72-79`) matches
        `"## ${heading}"` exactly. A near-match is an orphan -- this is what makes
        `EDM mode matrix` and `Phase Timing Guidelines` orphans despite their sections existing.
  - [ ] The enumeration reconciles against `EDMV4-50`'s table. Any orphan found here and not in that
        table is added to it, and the discrepancy is recorded rather than silently absorbed.
  - [ ] Every orphan is resolved by one of the **three** routes `EDMV4-50` names -- add to the
        generator, resolve a heading mismatch, or inline the rule at the citation site when it is
        short -- chosen deliberately per case and recorded. No orphan is left
        anchored-but-unresolvable. (v1.0.0 named only two routes, which cannot resolve
        `Skill-tool composition`, since it is bold inline text at `CLAUDE.md:24` and not a heading
        at all.)
  - [ ] The enumeration is recorded in `decisions.md` so the sweep is auditable and does not have to
        be re-derived.
  - [ ] `bin/edm-check-grants` gains an assertion that fails on an anchored citation whose named
        section does not exist in `docs/canonical-sections.md`, so the orphan class cannot regress
        silently. `EDMV4-49` extends the same assertion to cover bare-citation regressions; the two
        halves are one check with two failure modes.
  - [ ] The assertion is proven to discriminate by a positive control: a scratch copy anchored to a
        deliberately nonexistent section name must fail it.
- **Dependencies**: `EDMV4-50` (the generator must be able to take a third section before any
  route-1 resolution can land). **Not `EDMV4-49`** -- that dependency is inverted from v1.0.0, since
  `EDMV4-49` now depends on this.
- **Blocks**: `EDMV4-49`.
- **Target Components**: `plugins/edm/skills/*/SKILL.md`, `plugins/edm/agents/*.md`,
  `plugins/edm/docs/canonical-sections.md`, `plugins/edm/bin/edm-check-grants`,
  `SRD/edm/EDMV4__ecc-integration/decisions.md`.

---

### 6.12 `EDMV4-T05` -- eval-baseline verification and boundary record

#### EDMV4-52: Re-verify CA-532 and CA-490 as regression checks, and drop the moot CI item

- **Priority**: Must Have
- **Description**: The inherited ticket's scope was "fix the CA-532 `--allowedTools` argv-splitting
  bug, run the live wave-A eval capture, commit `evals/baseline/scores.json`, re-verify CA-490's
  `edm-compare-eval` reorder". **Both named bugs are already fixed and verified in current source.**
  CA-532's fix is present (`run-eval.sh:420-421` defines the two tool lists as real bash arrays and
  `:460-461` expands them as `"${ARRAY[@]}"`, so the CLI's documented space-separated-separate-
  arguments contract is honoured for all four space-containing specifiers). CA-490's fix is present
  (`edm-compare-eval:62-75` runs the `complete != true` check **before** the baseline-existence check
  at `:77-81`). A third item, CA-537's `.gitlab-ci.yml` exit-code arm ordering, is **moot**: no
  `.gitlab-ci.yml` exists in this repository, and commit `b56558d` removed the pipeline. T05's code
  work is therefore complete and closes as verification, not as a fix.
- **Acceptance Criteria**:
  - [ ] A regression check asserts `CLAUDE_ALLOWED_TOOLS` and `CLAUDE_DISALLOWED_TOOLS` are declared
        as bash arrays in `evals/run-eval.sh` and expanded as `"${ARRAY[@]}"`, not as a space-joined
        string passed as one argv element.
  - [ ] A regression check asserts `bin/edm-compare-eval` performs its `complete != true` refusal
        before its baseline-existence check, pinning the CA-490 ordering.
  - [ ] Both checks live in a suite `bin/tests/run-all.sh` discovers, so a future edit that reverts
        either fix fails a test rather than shipping.
  - [ ] The verification result is recorded, naming the archived ledger entries (`CA-532`
        `raised_round:10` `resolved_round:11`; `CA-490` `raised_round:9` `resolved_round:11`) as the
        origin of each claim.
  - [ ] The CA-537 CI item is **dropped**, with the reason recorded: no pipeline exists, the eval
        driver and comparator are purely local invocations, and stray `.gitlab-ci.yml` copies under
        `.claude/worktrees/*/` are agent scratch worktrees, not this repository's own files.
  - [ ] No re-fix is attempted for either bug. A ticket that "fixes" already-correct code is a defect
        in the ticket.
- **Dependencies**: none. (See the `EDMV4-03` note in Sec.6's reading guide.)
- **Target Components**: `plugins/edm/evals/run-eval.sh:420-421,460-461`,
  `plugins/edm/bin/edm-compare-eval:62-75,77-81`,
  `SRD/.archived/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl` (entries `CA-532`,
  `CA-490`, `CA-537`), `plugins/edm/bin/tests/run-all.sh`.

#### EDMV4-53: Record the baseline capture as an explicit scope boundary with a named follow-on

- **Priority**: Must Have
- **Description**: `plugins/edm/evals/baseline/scores.json` does not exist -- `evals/baseline/`
  contains only `README.md`. Capturing it requires three live `run-eval.sh` invocations against
  fresh scratch trees, each scored individually, with the **middle-scoring** run's `scores.json`
  committed. That is real API spend on human-owned credentials, and `evals/baseline/README.md`
  records, in its own words, that this is a decision for whoever owns the `ANTHROPIC_API_KEY`, made
  deliberately and "not spent silently by an agent verifying its own ticket". Per Gate 1 / D9 this
  initiative does **not** spend it. The boundary is recorded explicitly with a named follow-on rather
  than left as an unnamed candidate, following the D13/D14 precedent -- an unnamed gap is how
  `EDMV4-T01`/`T04`/`T05` became orphans in the first place.
- **Acceptance Criteria**:
  - [ ] `decisions.md` carries the boundary as a numbered decision: the capture is out of scope for
        EDMV4, it is a human credential decision, and the named follow-on that owns it is recorded by
        name.
  - [ ] The record states precisely what a capture requires: three `run-eval.sh` invocations against
        fresh scratch trees, individually scored by `score-artifacts.sh`, with the middle run by
        `total` committed as the baseline.
  - [ ] The record states what the committed baseline file must contain: `scorer_version` (currently
        `"1.1.0"`), `dimensions_scored` (5 for a wave-A `plan -> srd -> audit-srd` capture, since
        dimension 5 -- lens-JSONL-versus-prose agreement -- has no input without a code-audit round),
        `dimensions`, `total`, `complete`, and -- **only** on the committed baseline, not on every
        candidate run -- `variance.total_range`, which is the sole field `edm-compare-eval` reads off
        the baseline for its threshold.
  - [ ] The record states the current interim behaviour plainly: `edm-compare-eval` exits **3** with
        "the eval tripwire is NOT ARMED" -- a distinct, named, non-crashing outcome, neither a crash
        nor a silent pass.
  - [ ] `evals/baseline/README.md` is cross-referenced from the decision so the two records agree.
  - [ ] No agent spends API budget under this initiative to capture the baseline. This is stated in
        the ticket text, not only here.
  - [ ] `EDMV4-T05` closes as verification (`EDMV4-52`) plus this boundary record. It is not left
        open pending a capture that is deliberately not scheduled.
- **Dependencies**: `EDMV4-52`.
- **Target Components**: `plugins/edm/evals/baseline/README.md:39-55,104-116`,
  `plugins/edm/evals/baseline/` (the missing `scores.json`),
  `plugins/edm/bin/edm-compare-eval:77-81,109`, `plugins/edm/evals/score-artifacts.sh:139`,
  `SRD/edm/EDMV4__ecc-integration/decisions.md`.

---

### 6.13 D12 -- source-document self-correction

#### EDMV4-54: Write the eleven verified corrections back into `ecc-integration-analysis.md`

- **Priority**: Must Have
- **Description**: Per Gate 1 / D12, the eleven corrections are amended into the source document in
  place, in the Part 8.2 style it already uses to self-correct twice. Leaving the analysis
  uncorrected means the next reader re-derives the same eleven findings, and the corrections are
  substantive rather than cosmetic -- one of them (correction 2) is a citation the analysis repeated
  from ECC without checking, pointing at a file that does not contain what it is cited for.
  `planning.md` keeps the correction table as the audit record of what changed.
- **Acceptance Criteria**:
  - [ ] All eleven corrections enumerated in Sec.4.4 of this SRD are written into
        `plugins/edm/docs/ecc-integration-analysis.md`.
  - [ ] Each correction is applied in the document's own Part 8.2 self-correction style, not as a
        silent overwrite -- a reader must be able to see that the claim changed and why.
  - [ ] Correction 2 is applied at every site where the analysis cites `rules/common/security.md` for
        the seven security triggers, and each is redirected to `orch-pipeline/SKILL.md:100-104`. The
        note records that the misattribution originated in ECC's own parenthetical citation.
  - [ ] Correction 1 corrects the summary total to **23 registrations across 7 event types** while
        leaving the per-row table unchanged, since every individual row is correct -- the note says
        so explicitly, so a reader does not distrust the whole table.
  - [ ] Correction 8 updates the `update-patterns` line citations from `:5577`/`:5624` to
        `bin/edm-state:5595` and `:5627-5629`, and corrects "called mid-phase by four skills" to the
        verified six.
  - [ ] Corrections 4, 5, 6, 7, 9, 10 and 11 are applied with their verified figures and line
        citations exactly as Sec.4.4 records them.
  - [ ] Correction 3 records that ECC has no hookify evaluator, and the Part 5.3 effort estimate is
        annotated to reflect that EDM builds it from nothing rather than adapting existing logic.
  - [ ] The document's Part 8.3 "claims NOT verified" list is updated: the `zunoworks/gateguard`
        licence is now verified (MIT, decisions.md D13) and moves out of the unverified list.
  - [ ] `planning.md`'s correction table is left intact as the audit record. The two documents are
        cross-referenced rather than one replacing the other.
  - [ ] The amended document remains ASCII-only and passes `edm-lint-artifacts --path
        plugins/edm/docs/`.
- **Dependencies**: none. (See the `EDMV4-03` note in Sec.6's reading guide.)
- **Target Components**: `plugins/edm/docs/ecc-integration-analysis.md` (Part 1.2, Part 1.6, Part
  4.2 at `:360,368`, Part 4.3 at `:449`, Part 5.1, Part 5.2 at `:646-650`, Part 5.3, Part 5.5, Part
  8.2, Part 8.3), `SRD/edm/EDMV4__ecc-integration/planning.md` Sec."Corrections to the source
  document", `SRD/edm/EDMV4__ecc-integration/decisions.md` (D12, D13).

---

### 6.14 Cross-cutting requirements

#### EDMV4-55: Every new and modified `bin/` script holds the bash 3.2 floor

- **Priority**: Must Have
- **Description**: The plugin supports macOS and Linux only, at a **bash 3.2+** floor. macOS ships
  bash 3.2, so this is not theoretical. Existing code carries live comments about bash-3.2 gotchas,
  including a process-substitution fd-leak class fixed under CA-472. This initiative adds four new
  scripts and a shared library, which is the largest single addition to `bin/` in the plugin's
  history and the largest opportunity to regress the floor.

  **The ban is already implemented tree-wide, and this requirement extends it rather than writing
  weaker parallel criteria.** `wave7-smoke.sh:1082-1100` (T61 AC9) greps **every real `bin/` script**
  with `T61_BASH4_RE` at `:1083`
  (`declare -A|mapfile|readarray|\$\{[a-zA-Z_]+\^\^\}|\$\{[a-zA-Z_]+,,\}|\{fd\}`), excluding
  comment-only lines, and carries a positive control at `:1095-1097` proving the alternation fires.
  `:512-535` (T03 AC10) bans `declare -A` tree-wide with its own control and separately checks
  `mapfile`/`readarray`; `:649` repeats the `declare -A` check; `:2539-2542` (T43 AC11) pins
  `edm-lint-artifacts` specifically; `harness-smoke.sh:245-248` pins `_harness.sh`. Note that
  `{fd}` redirection is **already banned** by `T61_BASH4_RE` -- v1.0.0's per-file ACs did not
  mention it and were, taken literally, weaker than what already ships.

  **The one real gap this requirement must close**: T61 AC9 deliberately excludes `bin/tests/`
  ("test-fixture/assertion surface"), so the new `bin/tests/wave8-smoke.sh` is **not** covered by
  the existing ban.
- **Acceptance Criteria**:
  - [ ] **The five new files are covered by the existing tree-wide assertions, not by new ones.**
        `wave7-smoke.sh:1082-1100`'s T61 AC9 sweep already iterates real `bin/` scripts, so
        `_edm-datadir-lib.sh`, `edm-gateguard`, `edm-hookify`, `edm-stop-gate` and
        `edm-repo-readiness` fall under it automatically. A smoke assertion confirms the sweep's
        file set actually **includes** all five -- an addition that silently falls outside the
        glob would be protected by nothing.
  - [ ] **`T61_BASH4_RE` is extended, or a documented equivalent added, to cover `bin/tests/`** for
        the new suite. T61 AC9 excludes `bin/tests/` by design, so `wave8-smoke.sh` is otherwise
        unprotected. Either widen the existing sweep to include the new suite, or add a parallel
        assertion in `wave8-smoke.sh` that applies `T61_BASH4_RE` to itself -- the choice is
        recorded, and either way the constant is **referenced**, never re-encoded as a second
        literal that can drift from `:1083`.
  - [ ] No new or modified `bin/` script uses associative arrays (`declare -A`), `${var^^}`,
        `${var,,}`, `mapfile`, `readarray`, or `{fd}` redirection -- the exact set `T61_BASH4_RE`
        already encodes, cited rather than restated.
  - [ ] Constants that would naturally be arrays use the space-separated-string plus word-membership
        idiom (`case " $LIST " in *" $item "*)`) the file already uses for `MODE_ENUM_LIST`,
        `AUDIT_TYPE_ENUM_LIST` and `ALL_LENS_IDS`.
  - [ ] No process substitution appears in a loop condition, the CA-472 fd-leak class.
  - [ ] **Every new script is parsed and executed under `/bin/bash` explicitly**, not under
        `bash` from `PATH`. On macOS -- this plugin's stated primary development platform --
        `/bin/bash` **is** 3.2.57, so `/bin/bash -n <script>` and a `/bin/bash <script> --help`
        invocation are a real 3.2 check requiring no container, no `brew install bash@3.2` and no
        compatibility harness. `PATH`'s `bash` on a developer machine is routinely 5.x from
        Homebrew, so testing under it proves nothing about the floor. A smoke assertion records
        `/bin/bash --version` in its output so a run on a host where `/bin/bash` is not 3.2 is
        visible rather than silently vacuous.
  - [ ] **There is no "or the deviation is documented" escape hatch.** v1.0.0's AC5 carried one,
        which made it unfalsifiable -- any failure could be reclassified as a documented deviation.
        A bash-4 construct in a new `bin/` script is a defect, full stop. Genuine platform
        deviations are handled the way `timing.sh:54-80` handles the `perl` timer: a runtime
        `command -v` probe with a working fallback on the same code path, not a note in a file.
  - [ ] `/bin/bash -n` parses every new script cleanly.
  - [ ] Shellcheck directives are placed inline at the site they apply to, with the reason stated,
        following `bin/edm-state:1614`'s form. A file-level blanket disable is not acceptable.
- **Dependencies**: none.
- **Target Components**: `plugins/edm/bin/_edm-datadir-lib.sh`, `plugins/edm/bin/edm-gateguard`,
  `plugins/edm/bin/edm-hookify`, `plugins/edm/bin/edm-stop-gate`,
  `plugins/edm/bin/edm-repo-readiness` (all new), `plugins/edm/bin/tests/wave8-smoke.sh` (new, and
  the one file the existing ban does **not** reach), `plugins/edm/bin/edm-state`;
  **the existing tree-wide ban this requirement extends** --
  `plugins/edm/bin/tests/wave7-smoke.sh:1082-1100` (T61 AC9, the real-`bin/`-scripts sweep),
  `:1083` (`T61_BASH4_RE`, the canonical construct list, already including `{fd}`),
  `:1095-1097` (its positive control), `:512-535` (T03 AC10's `declare -A` and
  `mapfile`/`readarray` bans with their own controls), `:649` (the repeated `declare -A` check),
  `:2539-2542` (T43 AC11, `edm-lint-artifacts`-specific),
  `plugins/edm/bin/tests/harness-smoke.sh:245-248` (`_harness.sh`'s own check);
  plus `plugins/edm/CLAUDE.md Sec."Testing changes"`, `plugins/edm/bin/edm-state:1614` (the inline
  shellcheck form), `plugins/edm/bin/tests/timing.sh:54-80` (the `command -v perl` probe with an
  awk fallback -- the house form for a genuine platform deviation, cited by AC6),
  `plugins/edm/bin/edm-lint-artifacts` (existing bash-3.2 gotcha comments).

#### EDMV4-56: The required-binary set stays `bash`, `jq`, `git`

- **Priority**: Must Have
- **Description**: The plugin's stated required binaries are `bash`, `jq` and `git`. Two decisions in
  this initiative turned on that constraint: D7 chose JSON rule files over ECC's YAML frontmatter
  because a YAML parser would add a new required binary this plugin has never needed, and AD1 chose a
  bash rewrite over vendoring because both GateGuard adoption paths -- Python upstream, JavaScript
  ECC port -- would add a runtime dependency. The constraint is therefore load-bearing for two
  separate design decisions, and recording it as a testable requirement is what keeps a later
  implementer from quietly reintroducing one.
- **Acceptance Criteria**:
  - [ ] No new or modified script in `bin/` invokes `node`, `python`, `python3`, `yq` or any
        interpreter outside `bash`, `jq` and `git`.
  - [ ] **The `perl` exemption is declarative, not hypothetical.** `bin/tests/timing.sh` invokes
        `perl` at `:59-60` (`_now`) and `:75-76` (`_ms_between`) as an **optional
        high-resolution timing path**, each guarded by `command -v perl >/dev/null 2>&1` with a
        POSIX-`awk` fallback that works on a perl-less image (the CA-158 and G31/CA-262 fixes
        recorded in the comments at `:54-57` and `:63-68`). That is a verified fact about the tree,
        not a possibility -- and `EDMV4-47` AC4 modifies this very file, so the exemption is
        directly in this initiative's path. The smoke assertion therefore names `timing.sh`'s two
        `perl` call sites as **the** exempt set by construction, and fails on:
    - any `perl` invocation in `bin/` outside those two sites; **and**
    - a `perl` invocation at either site that is **not** guarded by a `command -v perl` probe with a
      working non-perl fallback on the same code path.

        The second half is the load-bearing one: the exemption is for an optional accelerator, not
        for a dependency, and an unguarded `perl` at `:59` would make `perl` required without
        anyone noticing.
  - [ ] A smoke assertion greps every `bin/` script for the banned interpreter names and fails on a
        hit, with a positive control proving the pattern fires.
  - [ ] **"POSIX coreutils" is not used as the boundary**, because it is imprecise in ways that
        matter here: `stat` is not POSIX at all and its flags differ between BSD and GNU (`stat -f`
        versus `stat -c`), and `flock` is util-linux-only. Any coreutil a new script depends on
        beyond the POSIX-guaranteed set is named individually in-file with its BSD/GNU divergence
        stated, or is avoided. `edm-gateguard`'s mtime read (`EDMV4-11`'s 30-minute expiry) is the
        concrete instance and must not assume GNU `stat`.
  - [ ] No file under `plugins/edm/` is added with a `.js`, `.ts`, `.mjs`, `.cjs` or `.py`
        extension.
  - [ ] `plugins/edm/CLAUDE.md Sec."Testing changes"`'s required-binary statement is unchanged after
        this initiative.
  - [ ] Every new script degrades correctly when `jq` is missing: a setup error (exit 1 for hook
        scripts, exit 2 for CLI scripts, per each one's documented convention), never a block and
        never a crash.
  - [ ] **If AD1 is reversed to vendoring** (`EDMV4-59` rejected, or any later decision directing
        vendoring), this requirement is re-presented at the gate as an explicit dependency addition
        -- `node` for ECC's JavaScript port, `python3` plus `pip install gateguard-ai` for the
        upstream -- rather than being silently violated. The trigger is an **AD1 reversal**, not an
        `EDMV4-05` rejection: rejecting `EDMV4-05` yields a larger *bash* rewrite, which adds no
        binary and leaves this requirement untouched.
- **Dependencies**: `EDMV4-59` (whose outcome determines whether the required-binary set can hold
  at all). `EDMV4-05` does not affect it.
- **Target Components**: `plugins/edm/bin/` (all scripts),
  `plugins/edm/bin/tests/timing.sh:54-80` (the guarded optional `perl` path and its awk fallback --
  the sole exempt sites), `:59-60`, `:75-76` (the two invocations),
  `plugins/edm/CLAUDE.md Sec."Testing changes"` (the required-binary statement),
  `SRD/edm/EDMV4__ecc-integration/decisions.md` (D7),
  `SRD/edm/EDMV4__ecc-integration/architecture.md` (AD1).

#### EDMV4-57: ASCII-only across every artifact, verified by a manual `--path` sweep

- **Priority**: Must Have
- **Description**: Every artifact this plugin produces or ships is ASCII-only: no em dashes, no
  arrows (use `->`), no smart quotes, no emoji. But `edm-lint-artifacts` class 2 (`unicode`) has a
  narrower reach than the rule: prefix mode resolves one initiative directory and `--all` walks the
  initiative directories `edm-state list --paths` returns, so **the plugin's own source tree is
  scanned by no invocation the git-commit hook makes**. `plugins/edm/skills/`, `agents/`, `docs/`,
  `evals/`, `CLAUDE.md` and `README.md` are all unreached, and em dashes have in fact landed in
  `skills/` and `agents/` and survived there undetected, found only by hand. This initiative adds
  three lens agents, four `bin/` scripts and edits across all of those trees, so the gap is directly
  in its path.
  **The reach gap has two halves, and v1.0.0 addressed only one.** The first is *which trees* the
  automatic invocations walk -- prefix mode resolves one initiative directory, `--all` iterates the
  initiative directories `edm-state list --paths` returns, so the plugin's own source tree is
  reached by nothing the git-commit hook runs. A manual `--path` sweep closes that.

  The second half is *which files the linter collects at all*, and a `--path` sweep does **not**
  close it: `collect_md_files` (`bin/edm-lint-artifacts:251-260`) runs
  `find "$dir" -type f ... -name '*.md'`. **No `.sh` file and no extensionless `bin/` script is
  ever collected, in any mode, including `--path`.** So `edm-lint-artifacts --path plugins/edm/`
  scans zero of the four new `bin/` scripts and zero of the shared library -- and this initiative's
  new `bin/` surface is the largest in the plugin's history. The ACs below split accordingly: the
  `--path` sweep owns `.md`, and an explicit byte scan owns everything else.
- **Acceptance Criteria**:
  - [ ] **`.md` coverage.** `plugins/edm/bin/edm-lint-artifacts --path plugins/edm/` reports zero
        violations before the initiative is called complete. This is a **manual** invocation and is
        named as a required Definition-of-Done step, not assumed. It covers `skills/`, `agents/`,
        `docs/`, `CLAUDE.md` and `README.md` -- all `.md`, all unreached by any automatic
        invocation.
  - [ ] **Non-`.md` coverage: an explicit byte scan, added to `bin/tests/wave8-smoke.sh`.** A new
        assertion runs `LC_ALL=C grep -n '[^\x00-\x7F]'` over `plugins/edm/bin/` (every file,
        including extensionless scripts and `bin/tests/`), `plugins/edm/hooks/hooks.json` and
        `plugins/edm/monitors/monitors.json`, and fails on any hit, printing file and line. This is
        the only mechanism that reaches those files -- `collect_md_files`'s `-name '*.md'` filter
        excludes all of them from `edm-lint-artifacts` in every mode.
  - [ ] The byte scan carries a positive control: a scratch file containing one non-ASCII byte must
        fail it, so a silently-non-firing grep is caught the way `T61_BASH4_RE`'s control catches a
        broken alternation.
  - [ ] The three new lens agent prompts, every `SKILL.md` edit and every `CLAUDE.md` edit pass the
        `--path` sweep. The four new `bin/` scripts and the new shared library pass the byte scan.
        Each file is covered by exactly one of the two mechanisms and the requirement says which.
  - [ ] Every artifact this initiative writes under `SRD/edm/EDMV4__ecc-integration/` passes
        `edm-lint-artifacts EDMV4`.
  - [ ] **Runtime-emitted text is a sanitization requirement, not a static-scan requirement.** No
        static mechanism can assert that GateGuard denial text, hookify rule messages or Stop-gate
        operator messages are ASCII at run time, because each interpolates values -- file paths,
        rule messages, anomaly text -- that originate outside the plugin and are unknowable at lint
        time. A user's repository can legitimately contain a path with a non-ASCII character.
        Therefore: **`emit_decision` (`EDMV4-09`) and the equivalent single emit point in
        `edm-hookify` and `edm-stop-gate` each strip or replace non-ASCII bytes in interpolated
        values before emitting**, and a smoke test drives a denial on a path containing a
        non-ASCII byte and asserts the output is pure ASCII and still parses as JSON. The
        **literal** text in those scripts is covered by the byte scan above; the **interpolated**
        text is covered by this sanitization.
  - [ ] `bash plugins/edm/bin/edm-check-vocabulary` exits 0 across `skills/`, `agents/`, `docs/`,
        `hooks/hooks.json`, `monitors/monitors.json`, `CLAUDE.md`, `README.md` and `bin/`.
  - [ ] Any Mermaid diagram added or edited in any artifact uses the `#59;` entity code for a literal
        semicolon inside label, node, edge or message text, per
        `CLAUDE.md Sec."Mermaid diagram conventions"`. A raw `;` inside a label is a violation.
  - [ ] The reach gap is recorded in the ticket text so the manual sweep is not skipped on the
        assumption that the commit hook covers it.
  - [ ] Where new rule files or generated artifacts land in a tree no invocation reaches (for example
        `.claude/edm-hookify/`), the gap is stated explicitly rather than assumed closed
        (`EDMV4-42`).
- **Dependencies**: none.
- **Target Components**: `plugins/edm/bin/edm-lint-artifacts` (class 2),
  **`:251-260` (`collect_md_files`'s `-name '*.md'` filter -- the reason a `--path` sweep cannot
  reach any shell script)**, `plugins/edm/bin/tests/wave8-smoke.sh` (new, the byte scan),
  `plugins/edm/hooks/hooks.json`, `plugins/edm/monitors/monitors.json`,
  `plugins/edm/bin/edm-gateguard` (`emit_decision`'s sanitization),
  `plugins/edm/bin/edm-check-vocabulary`,
  `plugins/edm/CLAUDE.md Sec."Artifact content conventions"`,
  `plugins/edm/CLAUDE.md Sec."Mermaid diagram conventions (canonical)"`,
  `plugins/edm/agents/` (3 new files), `plugins/edm/bin/` (4 new scripts plus the library),
  `SRD/edm/EDMV4__ecc-integration/`.

#### EDMV4-58: Every new surface has smoke coverage in `run-all.sh`

- **Priority**: Must Have
- **Description**: There is no CI pipeline for this plugin. `bin/tests/run-all.sh` plus the
  git-commit hook are the entire enforcement surface -- the local smoke suite is the actual
  enforcement, not a convenience check ahead of a pipeline. An untested new script is therefore
  permanently untested, not merely untested until the pipeline runs.
- **Acceptance Criteria**:
  - [ ] A new suite `bin/tests/wave8-smoke.sh` exists, is executable, follows the existing suites'
        `pass`/`fail`/summary contract, and is discovered by `bin/tests/run-all.sh`.
  - [ ] **`wave8-smoke.sh` is registered in `_PREFERRED_ORDER`** (`bin/tests/run-all.sh:39`).
        Discovery alone is not sufficient: the tripwire at `:73-76` iterates `_PREFERRED_ORDER` and
        fails naming any expected suite that was **not** discovered. A suite absent from that list
        is discovered but unprotected -- if it later stops being found, the run goes green with one
        fewer suite and nothing says so. Registration is what makes its absence loud.
  - [ ] Every new `bin/` script has at least: a `--help` invocation test, a usage-error test
        asserting the documented exit code, and one happy-path test.
  - [ ] Every new hook registration has a test asserting its `command -v` guard exits 0 when the
        delegate is off `PATH`.
  - [ ] Every exit code documented in this SRD for a new script has a test that produces it.
  - [ ] The suite runs without network access and without spending any API budget.
  - [ ] The suite creates no files inside the repository working tree. Scratch trees use
        `mktemp -d` and are cleaned up. **The invariant is scoped to files the *new* suite creates,
        not to a bare `git status --porcelain` being empty**, because `wave6-smoke.sh:4088-4098`
        deliberately mutates a tracked file (`docs/canonical-sections.md`) to prove
        `edm-sync-canonical-sections --check` catches a hand-edit, and restores it afterwards. A
        blanket clean-tree assertion would conflict with that existing, correct test. The check is:
        `git status --porcelain` reports nothing attributable to `wave8-smoke.sh`, verified by
        snapshotting before and after the suite runs in isolation.
  - [ ] **Platform claim, stated honestly.** `bash plugins/edm/bin/tests/run-all.sh` passes with
        zero failures **on macOS**, which is the platform every contributor to this plugin runs and
        the platform whose `/bin/bash` 3.2.57 makes `EDMV4-55`'s floor check real.

        **Linux is recorded as untested for this initiative.** There is no CI pipeline (`b56558d`
        removed the GitLab one), no container image is named anywhere in this repository, and
        nothing in this initiative introduces one. An AC requiring a Linux run with no named
        environment is aspirational, not testable, and would be signed off on the basis of nobody
        having run it. The plugin continues to *support* Linux -- `EDMV4-55`'s bash-3.2 floor and
        `EDMV4-56`'s BSD/GNU coreutil discipline are precisely what make that support plausible
        without a Linux run -- but "supported" and "verified" are recorded as different claims.
        Sec.3.4's Definition of Done item 2 is amended to match, and the gap is recorded in
        `decisions.md` with a named follow-on so it is a known boundary rather than an assumption.
  - [ ] If a Linux environment is later named, it is named **concretely** (an image tag and the bash
        version it ships) and the run becomes a manual Definition-of-Done step with a recorded
        result, following the same discipline `EDMV4-48` applies to a measured latency figure.
  - [ ] The `EDM_RUN_ALL_*` knob family continues to work: `harness-smoke.sh` can still point the
        aggregator at a scratch suite directory, and the new suite does not break that path.
  - [ ] `plugins/edm/CLAUDE.md Sec."Testing changes"` is updated if the suite count or the run
        procedure changes.
- **Dependencies**: every implementation requirement in Sec.6.
- **Target Components**: `plugins/edm/bin/tests/wave8-smoke.sh` (new),
  `plugins/edm/bin/tests/run-all.sh`, **`:39` (`_PREFERRED_ORDER`)**, **`:73-76`** (the tripwire
  that makes registration load-bearing), `plugins/edm/bin/tests/wave6-smoke.sh:4088-4098` (the
  deliberate tracked-file mutation the clean-tree invariant must not conflict with),
  `plugins/edm/bin/tests/harness-smoke.sh`,
  `plugins/edm/bin/tests/wave6-smoke.sh`, `plugins/edm/bin/tests/wave7-smoke.sh`,
  `plugins/edm/CLAUDE.md Sec."Testing changes"`.

---

## 7. Security, Licensing and Data-Handling Requirements

This initiative handles no user credentials, opens no network connections, and stores no secrets.
Four security-adjacent surfaces still need explicit treatment, because each one is new to this
plugin.

### 7.1 New attack and failure surfaces

| Surface | Exposure | Requirement that bounds it |
|---|---|---|
| **A `PreToolUse` hook that can refuse an edit** | A gate that denies incorrectly, or denies forever, halts a Phase 6 wave. The dangerous shape is a gate that cannot record what it has already asked, which would deny the same edit indefinitely | `EDMV4-11`: every state-write failure path **allows** with a stderr warning. `EDM_GATEGUARD_MAX_DENIALS` (default 3) bounds full denials per session. Two independent kill switches |
| **JSON emitted to stdout as a control channel** | This plugin's own tooling has never reasoned about stdout as a control channel. A malformed emission silently unenforces the gate rather than failing loudly | `EDMV4-09`: emitted from exactly one function, asserted by parsing it with `jq` in the smoke suite; escaping verified against a path containing a double quote |
| **User-authored rule files that can block operations** | `.claude/edm-hookify/*.json` is project-local content that can refuse a tool call. A malformed or overly broad rule from one contributor blocks everyone | `EDMV4-40`: malformed rule is a setup error, named on stderr and skipped, never blocking. `EDMV4-42`: `action` defaults to `warn`; blocking requires explicit per-rule opt-in |
| **Regex evaluated against tool payloads** | A pathological user-supplied pattern could hang a hook that fires on every edit | `EDMV4-41`: regex evaluation is bounded by a timeout or a documented input-size cap, with the choice stated in-file |
| **Data written outside the repository** | `${CLAUDE_PLUGIN_DATA}` and its XDG fallbacks are new territory for this plugin -- nothing in `bin/` has ever written there | `EDMV4-08`, `EDMV4-13`: only two subdirectories, both plugin-owned; every write is best-effort; unresolvable degrades to today's behaviour; a smoke test asserts nothing is ever written inside the repository working tree |

### 7.2 Data handling

- **No secrets are read, written, logged or persisted by anything in this initiative.** The only
  credential anywhere near this scope is `ANTHROPIC_API_KEY`, used solely by `evals/run-eval.sh`,
  which is unchanged and out of the runtime path. `EDMV4-53` records that no agent spends it.
- **GateGuard fact 3 explicitly demands redacted or synthetic values** when an agent describes a data
  file's field names, structure and date format. Raw production data must not be quoted into a
  denial response, which would place it in the conversation transcript. `EDMV4-10` carries this as an
  acceptance criterion, not as guidance.
- **The Phase-6 marker holds no sensitive content**: a PREFIX, an initiative directory path, and a
  timestamp. The session-state file holds file paths only.
- **Nothing this initiative adds is committed to the repository by default** except source-controlled
  hookify rule files, which are project content the team chooses to commit, consistent with
  `CLAUDE.md` rule 3.

### 7.3 Licensing and attribution

Both upstream licences are permissive and verified by direct inspection:

| Source | Licence | Verification |
|---|---|---|
| `everything-claude-code` (ECC), `github.com/affaan-m/everything-claude-code`, revision `19e2f2b4` | **MIT**, Copyright (c) 2026 Affaan Mustafa | `ECC/LICENSE:1-3`, inspected in the local clone at `/Users/darryl.porter/projects/ECC` |
| `zunoworks/gateguard` | **MIT**, Copyright (c) 2026 Hirokazu Seto / ZUNO WORKS K.K. | `https://raw.githubusercontent.com/zunoworks/gateguard/main/LICENSE`, inspected directly. Recorded as decisions.md **D13** |

`EDMV4-12` records both in `CLAUDE.md Sec."Prompt conventions (house style)"` in the established
form -- source, URL, licence, means of verification, clean-room note. Under AD1 the adoption is
mechanism-level rather than verbatim, matching the posture already recorded for `caveman` and
`ponytail`, which is why `EDMV4-12` is Should Have.

**The dormant obligation's trigger is an AD1 reversal to vendoring, by any route** -- `EDMV4-59`
rejected at Gate 2, or any later decision that directs vendoring. On that trigger the strict MIT
attribution and licence-notice obligation applies in full: roughly 2,042 lines across three files
retained verbatim, their copyright headers preserved, and a `NOTICE` naming ZUNO WORKS K.K. and
Affaan Mustafa. `EDMV4-12` is re-raised to Must Have and `EDMV4-56`'s required-binary set is
re-presented at the gate.

v1.0.0 wired this trigger to `EDMV4-05`, which was wrong in a way that created live exposure.
`EDMV4-05` ratifies the destructive-`Bash` **descope**; rejecting it yields a *larger bash rewrite*,
which copies nothing and revives nothing. Under that wiring, a Gate 2 that approved `EDMV4-05`
while separately directing vendoring would have left the obligation dormant with nothing to wake
it. `decisions.md` D13 states the trigger correctly ("if Phase 2 or Gate 2 reverses AD1 back to
vendoring"), and **`EDMV4-59` is the requirement that presents AD1 for that decision** -- nothing in
v1.0.0 ratified AD1 at all, so the decision the licence posture depends on had no gate. The
conditional is stated in `EDMV4-12`'s own acceptance criteria, once, so it travels with the work
rather than living only here.

---

## 8. Observability Requirements

EDM's observability is operator-facing text plus recorded state, not metrics infrastructure. Three
things must be observable that are not today.

### 8.1 A refusal must always be attributable

- Every GateGuard denial names the file being gated and, when the marker supplies it, the initiative
  PREFIX. A refusal an operator cannot attribute is indistinguishable from a bug.
- Every Stop-gate block names the specific anomaly and the initiative (`EDMV4-45`), so an operator
  does not have to run `validate` themselves to act.
- Every hookify block names the rule that fired by `rule_id` (`EDMV4-41`).
- Every setup error names the condition and the environment variable that would fix it -- the form
  `gateguard-fact-force.js:1176-1181` uses and `EDMV4-11` requires for
  `EDM_GATEGUARD_STATE_DIR`.

### 8.2 Silent degradation must be observable

Every degradation path in this initiative is deliberately fail-open, which means each one is a place
where the feature silently stops working. Each must leave a trace:

| Degradation | Observable signal |
|---|---|
| `edm_data_dir()` unresolvable | GateGuard treats the marker as absent and allows. `EDMV4-13`'s smoke tests pin the branch; the operator sees no gate, which is today's behaviour |
| Marker write failed at `phase-start 6` | stderr warning; the phase transition still succeeds (`EDMV4-08`) |
| Session state unwritable | stderr warning naming `EDM_GATEGUARD_STATE_DIR`, and an allow (`EDMV4-11`) |
| Denial budget exhausted | stderr advisory stating the budget was hit, then allow (`EDMV4-11`) |
| Harvested pattern delta silently cleared by a plugin upgrade | `${data}/patterns/harvest-provenance.json` records a write count and first-write timestamp, and `edm-state validate` gains an **informational** anomaly when the shipped seed's mtime is newer than the delta's first-write timestamp (`EDMV4-14`). This is the R3 exposure's only observable signature |
| A malformed hookify rule file | Named on stderr, skipped, exit 1 (`EDMV4-40`) |
| An audit round downgraded by the CA-471 backstop | Three distinguishable messages, one per downgrade reason (`EDMV4-25`) -- a single generic message is explicitly not acceptable |

### 8.3 Recorded state

- `lenses_na` is recorded in the round entry and rendered wherever `round_type` already is
  (`EDMV4-24`), so a `full` round that ran 13 lenses is visible as such rather than looking like an
  unexplained discrepancy.
- The `edm-repo-readiness` JSON output carries `READINESS_RUBRIC_VERSION`, so a score is traceable to
  the rubric that produced it (`EDMV4-37`).
- `patterns_updates` continues to be recorded on every successful splice (`EDMV4-14`), unchanged in
  shape.
- No new field is added to `.edm-state.json` without a row in
  `CLAUDE.md Sec.".edm-state.json mode-family fields"` stating its type, default, purpose and C-4
  absent behaviour (`EDMV4-14`, `EDMV4-24`).

### 8.4 Effect measurement

The honest instrument for GateGuard's value is `/edm:metrics`: Phase 6 QC FAIL rate before and after.
GateGuard's reported +2.25/10 result is n=2, self-reported, unblinded, with no published rubric --
the analysis says so itself, and its own Part 8.3.1 states that every Value rating in the document is
the author's ranking of a structural argument rather than a measured outcome. **No ticket acceptance
criterion in this initiative may cite that number, or any other self-reported effect size, as a
target.** The mechanism is why it is being adopted; the effect size is directional only.

---

## 9. Performance Targets

### 9.1 The one genuinely new performance problem

Every existing EDM hook fires at most a handful of times per conversation. `PreToolUse` fires exactly
once per `git commit`, where a 3,000 ms p95 budget is acceptable because a human is already waiting.
**GateGuard fires on every `Edit`, `Write` and `MultiEdit` -- tens to hundreds of times per Phase 6
wave.** That is a different order of magnitude, and it is the reason for the marker design.

| Target | Value | Fixture the target is stated against | Requirement |
|---|---|---|---|
| GateGuard allow path (marker absent) | **50 ms p95** | A repository with no active Phase 6 initiative, measured over 20 samples by `bin/tests/timing.sh --gateguard` | `EDMV4-07`, `EDMV4-08` |
| GateGuard allow path, `jq` subprocesses | **exactly 0** when the marker is absent | Verified by running with `jq` off `PATH` and asserting exit 0 | `EDMV4-07` |
| GateGuard gated path (marker present, first touch) | 1 exec, 2-3 `stat`, 1 `jq`, 1 small append | Same fixture with a marker present | `EDMV4-11` |
| Hookify `eval` process count | **Constant with respect to rule count** | 1 enabled rule versus 50 enabled rules, asserting identical process counts | `EDMV4-41` |
| Hookify `eval` with zero enabled rules | Exits 0 immediately, doing no `jq` work | Empty rule directory | `EDMV4-41` |
| `edm-lint-artifacts` commit path | **3,000 ms p95** (unchanged) | One initiative directory of 30 `.md` files / 9,990 lines | Not modified by this initiative |
| `edm-lint-artifacts --all` full-repo sweep | **60,000 ms** (unchanged) | A 50-initiative repository | Not modified by this initiative |
| Mermaid class | Re-derived as an absolute ceiling plus a ratio binding above a stated size floor | **`--mermaid-ratio`'s own fixture: 30 files / 9,990 lines, a single scratch initiative, 20-sample nearest-rank p95.** The mode builds this tree itself (`timing.sh:397-400`) and ignores `--dir`; `N_INITIATIVES=50` belongs to `--generate-fixture`, a different mode. If `EDMV4-48` takes option (a) and adds a `--dir` arm, this cell is restated against whatever fixture that arm is pointed at | `EDMV4-47`, `EDMV4-48` |

**Always quote a budget together with its input size.** A bare millisecond ceiling, or a bare ratio,
with no stated fixture is dominated by fixed process overhead: it reads differently on every machine,
and it moves when unrelated code gets faster. That is not a style preference here -- it is the exact
defect `EDMV4-47` exists to fix, and it has already bitten this plugin twice in opposite directions.
The commit-path and full-repo-sweep budgets are 20x apart and measured against fixtures roughly 50x
apart in size; **the two numbers must never be compared against each other**.

### 9.2 Explicitly rejected designs, on latency grounds

| Rejected | Cost |
|---|---|
| Re-run `cmd_active_initiatives`'s sweep per edit | 1 `edm-state` startup (a roughly 6,300-line script parsed fresh, since each hook invocation is a new process with no warm interpreter) plus 1 `jq` per active initiative. At the 50-initiative fixture size `CLAUDE.md`'s own latency table already uses, that is 50 `jq` invocations **per edit** |
| Anything shaped like `cmd_checkpoint` | It takes a write lock and computes SHA-256 over every tracked artifact per active initiative (`bin/edm-state:2781-2799`). It runs at `Stop`/`PreCompact` cadence for a reason. Running that shape per edit is the failure mode the marker design exists to avoid |
| `edm-state get <PREFIX> current_phase` | Not available: a `PreToolUse` hook receives no `PREFIX` argument |
| A consolidated multi-hook dispatcher process, ECC's own fix for its 23 registrations | EDM's problem is **one registration at high frequency**, not many registrations at low frequency. The ECC fix does not address it, and consolidation would put the plugin's one proven blocking hook behind new untested code |

### 9.3 Measurement gap

No per-edit timing fixture exists today the way `bin/tests/timing.sh` measures `edm-lint-artifacts`.
`timing.sh` gains a `--gateguard` mode to close it. Until that mode exists and runs, the 50 ms figure
is a design target, not a measured result, and must be described that way.

---

## 10. Risks and Mitigations

| # | Risk | Likelihood | Impact | Mitigation | Owning requirement |
|---|---|---|---|---|---|
| R1 | **Claude Code does not execute both matching hooks on one event.** The dangerous outcome is not that a new block never fires -- it is that it **suppresses the commit lint**, silently disabling the plugin's only proven-working blocking hook | Unknown | High | The design avoids the case everywhere it can: `Stop` gets a second entry in one block, and the new `PreToolUse` block is matcher-disjoint from `git commit`. The one unavoidable place is hookify's `bash` rules, which do not ship unless Spike A clears. The fallback (folding the lint into a Bash dispatcher) is deliberately the contingency, not the plan, because it touches the one hook that works | `EDMV4-01`, `EDMV4-43` |
| R2 | **Neither deny mechanism works for a native `Edit`.** GateGuard would deny nothing while appearing to work -- the worst failure shape, because the allow path is silent and nothing surfaces | Unknown | High | AD2's two back-ends make the outcome a one-constant change. `wave8-smoke.sh` catches a malformed emission but **cannot** catch a host that parses the JSON and ignores it -- only Spike B, against the live host, can. 4.1 is not ticketed before Spike B, and if neither mechanism works, 4.1 is re-presented at Gate 2 as a no-go rather than built against a mechanism that does not work | `EDMV4-02`, `EDMV4-09` |
| R3 | **`${CLAUDE_PLUGIN_DATA}` is not persistent across plugin upgrades.** The marker's loss is harmless -- it is ephemeral and SessionStart reconciles it. **The harvested pattern delta being silently erased on every upgrade is the real exposure**, and it is invisible: `update-patterns` would keep reporting successful appends into a directory that periodically empties | Medium | Medium | `harvest-provenance.json` plus an informational `validate` anomaly give the erasure an observable signature. If it proves true, move `${data}/patterns/` to the XDG path unconditionally and reserve `${CLAUDE_PLUGIN_DATA}` for `run/` only -- which is exactly the durable-versus-ephemeral split AD3's two subdirectories were designed to make cheap | `EDMV4-13`, `EDMV4-14` |
| R4 | **A per-edit `stat` is not cheap enough at EDM's real Phase 6 edit frequency.** Plausible and standard practice, but unmeasured for this plugin | Low | Medium | `timing.sh --gateguard` and the 50 ms p95 allow-path budget. If the budget cannot be met, the only remaining lever is inlining logic into the hook's JSON string -- the thing CA-436 exists to prevent -- so the budget is worth defending rather than relaxing | `EDMV4-07`, Sec.9 |
| R5 | **The lens-count assertion inventory is incomplete.** Found by grep, not by reading a 7,000-line file. A bare `-eq 11` with no nearby "eleven" token could have been missed. This SRD narrows the figure -- the exact-integer set is **10** tree-wide (9 in `wave7-smoke.sh` plus `bin/edm-state:1615`), and the wider token set is **90 occurrences across 16 files** when the corrected `EDMV4-33` AC4 pattern is run, not the 54 v1.0.0 reported. Part of that delta is this initiative's own doing -- `docs/ecc-integration-analysis.md` contributes 6 and did not exist at Phase 1. A narrower figure derived by the same method is still not a guarantee | Medium | Medium | Three greps, not one: `-eq 11`/`== 11` for exact integers; `edm-audit-` three-or-more-times-per-line for hardcoded **name lists** (which stay green while wrong -- `wave7-smoke.sh:5386` is the dangerous instance); and `-eq 12|13|15` for counts that are offsets from 11. Plus the widened post-sweep closure grep, whose survivors must all be on a do-not-touch list **keyed by string, not line number** | `EDMV4-32`, `EDMV4-33` |
| R6 | **A careless find-replace corrupts an unrelated "eleven".** `CLAUDE.md:292` and `canonical-sections.md:88` refer to the **Mermaid-convention** touch-point count, a different eleven. `bin/edm-state:4619` recounts a historical incident. `CHANGELOG.md` has 14 historical mentions | Medium | Medium | An explicit do-not-touch list recorded in the 4.4 ticket, plus the rule that `canonical-sections.md` is regenerated rather than hand-edited and `--check` must pass | `EDMV4-33` |
| R7 | **`wave6-smoke.sh:3445-3449` inverts silently.** Its explicit 11-lens full-round assertion becomes an 11-of-14 partial the moment `ALL_LENS_IDS` grows -- the test's claim reverses without the test being touched | High if not addressed | High | Called out as its own acceptance criterion with two new cases added for the N/A composition, rather than left to be discovered when the suite goes red for a reason nobody expects | `EDMV4-32` |
| R8 | **A skill edit silently leaves a pattern-reading agent with no paths**, and the agent reads nothing while reporting success | Medium | Medium | `bin/edm-check-grants` gains an assertion that every launch template spawning one of the four agents carries both interpolated paths. `edm-check-grants` already checks skill launch templates as one of its four sources, so this is an extension rather than a new mechanism | `EDMV4-14` (Read side) |
| R9 | **4.2's write side and read side land in separate commits**, silently losing all harvested content while `update-patterns` reports success | Medium | High | The write side, the read side and the coupling are **one requirement** (`EDMV4-14`, absorbing `EDMV4-15` and `EDMV4-16`), so they cannot be scheduled apart. Enforced three ways: a ticket-pack assertion that all three IDs map to one ticket, an end-to-end test, and a **retained** negative test documenting the failure mode. v1.0.0 split them across three requirements with a mutual dependency, which a dependency-ordered scheduler would have broken by dropping exactly this constraint | `EDMV4-14` (Coupling) |
| R10 | **L13's conditionality is read as licence to skip lenses for cost.** The analysis's own risk note for 4.4 invites this reading, and guard D2's stated cost of being ignored is coverage loss disguised as an efficiency gain | Medium | High | L13's conditionality is framed as inapplicability everywhere it appears, in exactly those terms, with a smoke assertion grepping for the framing. `CONDITIONAL_LENS_IDS` has exactly one member and a caller naming any other lens N/A is a hard `die` | `EDMV4-28`, `EDMV4-23` |
| R11 | **The size classifier tries to invent a tier outside the eight enum values.** `cmd_set_mode` hard-refuses, so the failure is loud rather than silent -- but a ticket could still be written against a nonexistent value and waste a wave | Low | Low | The backstop is recorded as its own requirement with a smoke test pinning both enum strings and asserting a hypothetical fourth value is refused. The classifier emits three recommendations and does not attempt to distinguish `fast-track` from `fix-pack`, which are documented as behaviourally identical | `EDMV4-20` |
| R12 | **The D4 reconciliation discards the unstaged `*opus-5*` arm** in `compute_cost_usd`'s model `case`. The revert hazard D4 originally described is **closed** -- `bdec805` is the branch tip and the working tree carries zero `disable-model-invocation` -- so the residual risk is collateral loss during the merge, not regression of the D3 fix. Losing that arm silently reprices every Opus 5 run at the `*)` placeholder rate, and nothing fails | Low | Medium | `EDMV4-03` asserts the arm behaviourally (price a synthetic `claude-opus-5-*` identifier and compare against the Opus row) rather than by grepping for its presence, and separately re-asserts the D3 state as a regression check. A clean full-suite run on the reconciled tree establishes the baseline | `EDMV4-03` |
| R13 | **`EDMV4-T02` or `EDMV4-T03` is reused by Phase 4**, colliding with work closed inside EDMV3 | Medium | Medium | Stated as an explicit numbered constraint, with the numbering gap documented in the ticket pack `README.md` so a later reader does not "fix" it | `EDMV4-04` |
| R14 | **A scope reduction is absorbed as implementation detail** rather than ratified, so approved scope shrinks without a human decision | Medium | Medium | Both reductions are first-class Must Have requirements with gate-presentation acceptance criteria and explicit accept/reject branches, not notes in a constraints list | `EDMV4-05`, `EDMV4-06` |
| R15 | **`origin/main`'s three unmerged commits differ from this branch in ways beyond the version bump.** The branch is 3 commits behind (merge `bdb5698` plus version bumps `33d63e0`, `4ad0f35`); only the version line has been diffed, not full file bodies | Low | Medium | The clean full-suite run on the reconciled tree (`EDMV4-03`) would surface a functional difference. If it does, the difference is investigated before EDMV4 work continues rather than absorbed. Because the reconciliation is merge-time and blocks nothing, this risk is carried to the merge rather than to the start of implementation | `EDMV4-03` |
| R17 | **AD1 ships unratified and the dormant MIT NOTICE obligation is never triggered.** Gate 1 / D6 deferred vendor-versus-rewrite to Phase 2 with "Resolve in SRD"; Phase 2 answered it as AD1, but an architect's answer is not a ratification. v1.0.0 wired the licence trigger to `EDMV4-05` instead, so a Gate 2 approving `EDMV4-05` while separately directing vendoring would have left the obligation dormant with nothing to wake it | Medium | Medium | `EDMV4-59` presents AD1 itself at Gate 2 as a decision distinct from `EDMV4-05` and `EDMV4-06`, enumerating all three adoption paths and stating the licence consequence in both directions. `EDMV4-12`'s dormant clause and `EDMV4-56`'s dependency-addition clause are both re-wired to an **AD1 reversal by any route**, matching `decisions.md` D13's own wording | `EDMV4-59`, `EDMV4-12` |
| R16 | **`edm-lint-artifacts` class 2 does not reach the plugin's own tree**, so ASCII violations in three new lens prompts and four new scripts ship undetected -- as em dashes already have in `skills/` and `agents/` | Medium | Low | A manual `edm-lint-artifacts --path plugins/edm/` sweep is a named required step in the Definition of Done, not an assumption | `EDMV4-57` |

---

## 11. Glossary

| Term | Definition |
|---|---|
| **AD1 .. AD6** | Architecture decisions recorded in `architecture.md`. AD1 GateGuard is a bash rewrite; AD2 two deny back-ends; AD3 shared data-directory resolver; AD4 event ownership; AD5 `lenses_na` sibling field; AD6 pattern read route (c). |
| **`ALL_LENS_IDS`** | The single source for the code-audit lens ID set, `bin/edm-state:1613`. Grows from 11 to **14** in this initiative. |
| **CA-NNN** | A stable code-audit finding ID from `code-audit/findings-ledger.jsonl`. Referenced here for historical fixes (CA-298, CA-436, CA-440, CA-448, CA-471, CA-472, CA-476, CA-490, CA-515, CA-532, CA-537). |
| **C-4 backward compatibility** | The plugin's rule that a state file predating a field is never an error. Every reader supplies a `//` default and the field's absent behaviour is documented in `CLAUDE.md`'s state-field table. |
| **Clean-room posture** | Adopting a mechanism structurally -- a shape of section, a kind of clause, a state-machine design -- without copying text. The posture `CLAUDE.md Sec."Prompt conventions (house style)"` records for `caveman` and `ponytail`, and which `EDMV4-12` extends to ECC and GateGuard. |
| **`CONDITIONAL_LENS_IDS`** | New constant beside `ALL_LENS_IDS` naming lenses that may legitimately be auto-N/A. Exactly one member: `L13`. |
| **D1 .. D13** | Numbered decisions in this initiative's `decisions.md`. D1-D4 intake; D5-D12 Gate 1; D13 the GateGuard licence verification. |
| **do-NOT-adopt guards D1-D6** | A separate, unrelated numbering in `CLAUDE.md Sec."Prompt conventions (house style)"`. **D2** (do not reduce lens or auditor fan-out) and **D6** (do not duplicate the mode matrix into prompts) both bind this initiative. Not to be confused with `decisions.md`'s D1-D13. |
| **ECC** | `everything-claude-code`, `github.com/affaan-m/everything-claude-code`, MIT. The source of the patterns this initiative adopts. Local clone at `/Users/darryl.porter/projects/ECC`, revision `19e2f2b4`. |
| **Fact-forcing** | GateGuard's mechanism: the denial reason is a numbered list of facts the agent must produce, not a confirmation prompt. Asking a model to self-evaluate returns "no"; asking it to list every importer forces a `Grep` and a `Read`, and that investigation changes the output. |
| **`lenses_na`** | New `audit_rounds.<type>.rounds[]` field recording lenses auto-excluded as inapplicable. Written at `audit-round-start`, before any agent launches. |
| **Marker (Phase-6-active)** | A one-line file at `${data}/run/<project-key>.phase6` that answers "is this project in Phase 6" for the cost of one `stat`. |
| **P0 / P1 / P2 / NOTED** | The closed severity vocabulary. `CLAUDE.md Sec."Severity vocabulary"` is authoritative; no agent may define a divergent local scale. |
| **`round_type`** | Two-value enum, `full` or `partial`, on an audit round. Stays two-valued in this initiative; the third state lives in `lenses_na` (AD5). |
| **Route (a) / (b) / (c)** | The three pattern-library read designs. (a) four agents merge in-context; (b) agents call a concatenating subcommand; (c) the skill resolves paths and the agents `Read` two files. AD6 chooses (c); (b) is blocked by the absent `Bash` grant on two writer agents. |
| **Seed and delta** | The pattern library's two halves. The seed is the shipped, read-only `docs/audit-patterns/*.md`. The delta is the writable harvested file under `${data}/patterns/`, created as a stub so the two are disjoint by construction. |
| **Spike A / Spike B** | The two blocking mechanical experiments against the live Claude Code host. A: multi-hook-per-event combination semantics. B: deny shape for a native `Edit`/`Write`/`MultiEdit`. |
| **`{PREFIX}-NN` / `{PREFIX}-T{NN}`** | Requirement IDs versus ticket IDs. `EDMV4-01` is a requirement in this SRD; `EDMV4-T01` is a ticket in the Phase 4 pack. The `T` prevents collision, and this initiative's `T01`/`T04`/`T05` are pre-claimed (`EDMV4-04`). |

---

## 12. Requirement Summary

| Priority | Count | IDs |
|---|---|---|
| **Must Have** | **42** | `EDMV4-01` .. `EDMV4-11`, `EDMV4-13`, `EDMV4-14`, `EDMV4-18` .. `EDMV4-20`, `EDMV4-22` .. `EDMV4-35`, `EDMV4-49` .. `EDMV4-51`, `EDMV4-52` .. `EDMV4-60` |
| **Should Have** | **15** | `EDMV4-12`, `EDMV4-17`, `EDMV4-21`, `EDMV4-36` .. `EDMV4-38`, `EDMV4-40` .. `EDMV4-48` |
| **Could Have** | **1** | `EDMV4-39` |
| **Merged** | **2** | `EDMV4-15`, `EDMV4-16` -- absorbed into `EDMV4-14`. No independent priority, no independent acceptance criteria. IDs retained so existing cross-references resolve |
| **Substantive total** | **58** | 42 Must + 15 Should + 1 Could |
| **ID range** | **60** | `EDMV4-01` .. `EDMV4-60`, no gaps, no duplicates |

**Changes from v1.0.0's counts.** `EDMV4-59` (ratify AD1) is new. `EDMV4-51` is raised from Should
Have to Must Have (P0-3: it gates whether `EDMV4-49` and `EDMV4-50` can be executed correctly).
`EDMV4-15` and `EDMV4-16` are merged into `EDMV4-14` (P0-5: they formed two dependency cycles and
their single-commit constraint was unenforceable while split). Net: Must Have unchanged at 41
(+`EDMV4-59`, +`EDMV4-51`, -`EDMV4-15`, -`EDMV4-16`), Should Have 16 -> 15 (-`EDMV4-51`).

### 12.1 Requirements by scope item

| Scope item | Requirements | Must | Should | Could |
|---|---|---|---|---|
| Preconditions and change control | `EDMV4-01` .. `EDMV4-06`, `EDMV4-59`, `EDMV4-60` | 8 | 0 | 0 |
| 4.1 GateGuard | `EDMV4-07` .. `EDMV4-12` | 5 | 1 | 0 |
| 4.2 `update-patterns` | `EDMV4-13`, `EDMV4-14`, `EDMV4-17`, `EDMV4-18` (plus merged `EDMV4-15`, `EDMV4-16`) | 3 | 1 | 0 |
| 4.3 Size classifier | `EDMV4-19` .. `EDMV4-22` | 3 | 1 | 0 |
| 4.4 Lenses L12/L13/L14 | `EDMV4-23` .. `EDMV4-35` | 13 | 0 | 0 |
| 5.2 Repo-readiness scorecard | `EDMV4-36` .. `EDMV4-39` | 0 | 3 | 1 |
| 5.3 Hookify | `EDMV4-40` .. `EDMV4-43` | 0 | 4 | 0 |
| 5.4 Stop-hook gate | `EDMV4-44` .. `EDMV4-45` | 0 | 2 | 0 |
| 5.5 Codemaps interim | `EDMV4-46` | 0 | 1 | 0 |
| `EDMV4-T01` | `EDMV4-47` .. `EDMV4-48` | 0 | 2 | 0 |
| `EDMV4-T04` | `EDMV4-49` .. `EDMV4-51` | 3 | 0 | 0 |
| `EDMV4-T05` | `EDMV4-52` .. `EDMV4-53` | 2 | 0 | 0 |
| D12 source correction | `EDMV4-54` | 1 | 0 | 0 |
| Cross-cutting | `EDMV4-55` .. `EDMV4-58` | 4 | 0 | 0 |

### 12.2 Critical path

```
EDMV4-01 (Spike A)              ->  EDMV4-07, EDMV4-43, EDMV4-44
EDMV4-02 (Spike B)              ->  EDMV4-07, EDMV4-09
EDMV4-59 (ratify AD1)           ->  EDMV4-07, EDMV4-12, EDMV4-56
EDMV4-05 (ratify 4.1 descope)   ->  EDMV4-07
EDMV4-06 (ratify 5.4 descope)   ->  EDMV4-44, EDMV4-45
EDMV4-07 (gateguard script)     ->  EDMV4-09, EDMV4-10, EDMV4-11   (one-way, never mutual)
EDMV4-13 (datadir lib)          ->  EDMV4-08 (4.1 marker), EDMV4-14 (4.2)
EDMV4-14 (all of 4.2, one commit)  ->  EDMV4-17, EDMV4-18
EDMV4-23 (ALL_LENS_IDS)         ->  all of 4.4
EDMV4-24 (materialized lenses)  ->  EDMV4-25, EDMV4-26, EDMV4-32
EDMV4-32 (smoke rewrite) blocks any other work touching wave7-smoke.sh
EDMV4-50 (third canonical section) ->  EDMV4-51  ->  EDMV4-49
EDMV4-03 (D4 residual) blocks nothing -- merge-time obligation only
```

**`EDMV4-03` blocks nothing.** Per `decisions.md` D4 as amended the revert hazard is already
closed on this branch and the residual is a one-line `plugin.json` reconciliation the decision
itself calls non-blocking. v1.0.0 said it blocked "everything", which contradicted `EDMV4-55` and
`EDMV4-57`, both of which correctly declared no dependencies. It is now carried in the Definition
of Done (item 6) and appears in no Dependencies line.

**Three scope items are unblocked immediately and are the initiative's quick wins**: 4.2
(`EDMV4-13`, `EDMV4-14`, `EDMV4-17`, `EDMV4-18`), 4.3 (`EDMV4-19` .. `EDMV4-22`) and
`EDMV4-T01` (`EDMV4-47`, `EDMV4-48`). Note the counting: these are three *scope items* spanning
ten requirements, not three requirements -- v1.0.0 said "three requirements are unblocked" and then
named three groups.

`EDMV4-T04` (`EDMV4-49` .. `EDMV4-51`) is also unblocked but is **not** a quick win: it is a
three-requirement chain (`50 -> 51 -> 49`) whose middle link must enumerate and resolve 8 orphaned
citation sites across 6 section names before any anchoring happens.

`EDMV4-T05` (`EDMV4-52`, `EDMV4-53`) is unblocked and closes as verification plus a recorded
boundary. **`EDMV4-T01` does need new harness code** -- `EDMV4-47` AC4 rewrites `timing.sh`'s
printed budget line and `EDMV4-48` must either add a `--dir` arm to `--mermaid-ratio` or restate
the budget against that mode's real single-initiative fixture. v1.0.0's claim that T01 and T05
"need no new harness code" was true only of T05.

