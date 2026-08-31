# EDMV3 Planning

**Sources merged into this plan**: `explorers/01-edm-plugin-current-state.md`,
`explorers/02-external-pattern-sources.md`, `EDM-REVIEW.md` (outside-expert review, 2026-07-25,
findings F1-F11 / recommendations R1-R8), and 14 recorded decisions (`decisions.md` D1-D14).
This document is the single cohesive plan; the sources are evidence.

## Initiative

Update the `plugins/edm/` Claude Code plugin using two Anthropic prompting guides (Sonnet 5, Opus 5)
and two external repos (`caveman`, `ponytail`, mined for instruction-design patterns) as sources,
plus the findings of a full outside-expert review (`EDM-REVIEW.md`). Three explicitly required fixes:

1. `code_audit_converged` must only become `true` after explicit human approval -- today it is set
   automatically the instant a code-audit round shows zero open P0/P1 findings, with no sign-off step.
2. Mermaid diagrams break because agents put a literal `;` inside node/edge label text (Mermaid
   reserves `;` as a statement separator). Fix: use the character reference `#59;` (no leading `&`)
   for a literal semicolon in diagram labels, applied everywhere the plugin authors or audits Mermaid.
   Rendering of `#59;` in org tooling is confirmed working (D8) -- no validation spike needed.
3. **No deferral, ever, anywhere in the methodology** (D6, broadened to universal by D13): every
   actionable finding at every severity (P0/P1/P2) is remediated before convergence; every PARTIAL
   verdict is closed by mandatory runtime verification before archive; no `--accept-partials` or
   equivalent escape hatches anywhere; no deferral vocabulary in any prompt or template. **NOTED**
   items are unaffected (non-actionable via the False Alarm Filter, not deferred findings).

The review reframed requirements 1 and 3: both are instances of one defect class -- **behavior
specified in prose, not enforced in mechanism** -- documented three times now (Gate 3.5 in the
2026-06-10 external audit; convergence auto-set; a live methodology bypass observed during this very
initiative). The cohesive plan therefore treats the enforcement kernel (WS2) as the center of
gravity, not a side fix. Audience decision (D7: team adoption planned) makes this urgent, not
optional.

## Current State

*(Condensed; full detail in the explorer reports and EDM-REVIEW.md Step 2.)*

The `plugins/edm/` plugin (v2.0.0) is ~40 markdown skill/agent files plus 4 POSIX bash scripts in
`bin/`, no build step, no CI. State lives in `SRD/{PRODUCT}/{PREFIX}__{DESC}/.edm-state.json`,
mutated only through `bin/edm-state` (36 subcommands, jq-based RMW under an advisory lock).

**Verified defects (all reproduced or confirmed at file:line):**

- **F1 -- lifecycle bypassable in 3 commands** (reproduced in scratch repo): `edm-init` ->
  `edm-state set X code_audit_converged true` -> `edm-state archive X` succeeds on a phase-0
  initiative with zero gates. `cmd_archive` (`bin/edm-state:860-903`) checks one boolean;
  `cmd_set` (`:479-484`) allowlists it; `cmd_set`'s generic branch (`:491-494`) accepts arbitrary
  keys. Prompts instruct the model to set the flag itself (`skills/code-audit/SKILL.md:57`,
  `skills/orchestrator/SKILL.md:557-558`) against the orchestrator's own anti-pattern (`:645`).
- **F2 -- first run broken twice** (reproduced): `bin/edm-init:139` snapshots `initiative_branch`
  before branch creation at `:148-168`, so every fresh initiative fails Step 1d's hard BLOCK with
  actively wrong remediation advice. `README.md:11,14` installs `./plugins/edm-ai-development`,
  which no longer exists.
- **F3 -- tool-grant contradictions**: `edm-qc-auditor` (no Write/Bash, yet ordered to write `qc/`
  reports and run `edm-state`) and `edm-explorer` (no Write, yet ordered to write
  `explorers/*.md`; confirmed live -- both EDMV3 explorers returned text apologies). Class was
  found and fixed once for `edm-test-coverage-auditor` (EDMV2-T01) but encoded as a permanent
  manual ritual (`skills/implement/SKILL.md:162-172`) instead of a class-level test.
- **F4 -- two gate protocols**: orchestrator mandates AskUserQuestion + "free-text is never
  approval" (`skills/orchestrator/SKILL.md:396-400`); standalone phase skills accept plain
  affirmations (`skills/plan/SKILL.md:130-132`, `skills/audit-srd/SKILL.md:122-124`,
  `skills/audit-tickets/SKILL.md:127-129`). Gate integrity depends on entry path.
- **F5 -- free-text findings pipeline**: no machine-checkable representation of a finding anywhere;
  convergence is asserted, not computed; EDMV2's ledger contradicted state until an external audit
  reconciled them. Double False-Alarm filtering with no confidence field suppresses recall
  (explicitly warned against in both Anthropic model guides).
- **F6 -- economics not true**: EDMV2 Phase 6 = $0/0s despite 2 full code-audit rounds. Root cause
  confirmed (D9): `phase-start 6` fired, `phase-complete 6` never called; archive did not care.
  Token attribution also sums every project-session JSONL (`bin/edm-state:206-225`), and the
  pricing table is a model-generation stale (`:227-257`).
- **F7 -- PARTIAL verdicts never close**: excluded from remediation
  (`skills/implement/SKILL.md:105`), unchecked by archive; `skills/implement/SKILL.md:95`
  remediates P0/P1 FAILs only, contradicting requirement 3.
- **F8 -- everything opus/max**: mechanical lenses (L2, L5, L7, L10) run at the same tier as
  judgment lenses; no tiered audit policy.
- **F9 -- update-patterns appends unreviewed stubs** (`bin/edm-state:1576-1692`) after the fourth
  section, violating the Living-Library Contract, into files loaded by every future writer prompt.
- **F10 -- nothing is measured**: no fixture eval, no CI; smoke suites (76/76 pass) verify text
  presence, not outcomes.
- **F11 -- distribution hygiene**: 676KB pptx + docx + `.DS_Store` ship in the plugin dir; stale
  README paths.

**What is genuinely good and must survive untouched** (EDM-REVIEW.md Step 2 close): state-derived
path resolution, locking/atomicity discipline, artifact-hash drift detection, QC verdict semantics,
the gate approval rules text, stable CA-NNN ledger IDs + demote-don't-delete False Alarm handling,
the lint infrastructure, HANDOFF auto-refresh, the self-audit culture.

**Existing patterns to mirror**: Gate 3.5 dedicated-boolean gate (`bin/edm-state:590-609`,
`skills/orchestrator/SKILL.md:267-285`); `CLAUDE.md` canonical-section-referenced-by-name
(Severity vocabulary, `CLAUDE.md:176-191`); Living-Library four-`##` contract
(`docs/audit-patterns/README.md:5-20`); fence-aware lint ignore sets (`bin/edm-lint-artifacts`).

## Gap Analysis

| Area | Today | Desired |
|---|---|---|
| Lifecycle enforcement | Prose-only; archive checks 1 boolean; `cmd_set` writes any key; 3-command full bypass | `edm-state` as enforcement kernel: permission-gated approvals, artifact-verified phase-complete, lifecycle-verified archive, allowlisted `cmd_set` |
| `code_audit_converged` | Auto-set by agent, zero sign-off | Settable only via `edm-state approve-gate <PREFIX> code-audit` (D2); removed from `cmd_set`; existing converged initiatives grandfathered (D4) |
| Gate protocol | Two protocols; free-text approval accepted on standalone-skill path | One protocol, written once, referenced everywhere; backed by permission `ask` rule so drift cannot record approvals |
| Findings pipeline | Free-text end to end; convergence asserted; blind corroboration filter | Findings as JSONL with `confidence` field; ledger rendered from data; convergence = jq query; blocking set P0+P1+P2 in code (one place) |
| Deferral policy | P1 deferrable with rationale, P2 "defer otherwise"; worked example defers P2s; implement remediates P0/P1 only; PARTIALs deferred to runtime that never comes | Universal no-deferral (D13): blocking set P0+P1+P2 everywhere; every PARTIAL closed via mandatory runtime verification before archive; no override flags; no deferral vocabulary anywhere |
| Mermaid `;` in labels | No rule anywhere; diagrams intermittently break | Canonical rule in `CLAUDE.md`, referenced by name from 11 touch points; 4th `edm-lint-artifacts` violation class (Mermaid-only line set) |
| `edm-init` branch recording | Records pre-switch branch; hard-blocks Step 1d on every fresh initiative | Post-checkout correction (D3) + regression test |
| Agent tool grants | 2 known contradictions + ritual instead of class test | Grants match instructions; class-level smoke check; ritual deleted |
| Orchestrator structure | 645 lines, all 6 phases inline, duplicated in phase skills, drifted | Full dispatcher (at most 300 lines, derived in `srd.md` EDMV3-46) invoking phase skills via Skill tool (D10); phase procedures live once |
| Economics | Phase 6 invisible; attribution over-counts; pricing stale; ROI theater | phase-complete 6 wired; attribution scoped/labeled honestly; pricing current; lens tiering; human-baseline ROI dropped from default output |
| Prompt design vs. model guides | No cadence/length calibration; double-filtering; no output contracts | Selective adoption per explorer 02 (C1-C3), guarded by its Part D do-NOT-adopt list; applied post-dispatcher so edits land once |
| Measurement | None; no CI | Fixture initiative + headless eval scoring; GitLab CI running lint, smoke suites, plugin validate, class checks |
| Pattern library | EOF stub appends, contract violation, no curation | `update-patterns` respects contract; appended entries surface for human review at the audit gate |
| Hygiene | pptx/docx/.DS_Store shipped; stale README; dead enum/hook/no-op | Delete list executed (D12 includes `lifecycle_mode=partial`) |

## The Plan -- Workstreams

Sequenced per EDM-REVIEW.md Step 3, adjusted for decisions D7-D12. Each workstream becomes an epic
in the ticket pack.

### WS1. Mechanical fixes (R2 + F2 + F3) -- first, hours not days

1. `bin/edm-init`: post-checkout correction `edm-state set "$PREFIX" initiative_branch "$BRANCH"`
   after the branch block succeeds (D3). Regression test: scaffold in scratch repo, assert
   `initiative_branch` matches `HEAD`.
2. `agents/edm-qc-auditor.md`: grant `Write`, `Bash(edm-state *)`, `Bash(mkdir *)`, `Bash(jq *)`;
   keep `disallowedTools: Edit, NotebookEdit`.
3. `agents/edm-explorer.md`: grant `Write` (D5).
4. `README.md:11,14`: `./plugins/edm-ai-development` -> `./plugins/edm`. Also state the
   macOS/Linux-only platform constraint (D11).
5. Class fix: smoke check grepping every `agents/*.md` for write-instructions vs. `Write` grant;
   delete the manual ritual at `skills/implement/SKILL.md:162-172`.

### WS2. Enforcement kernel (R1 + requirement 1) -- the product change

1. **Permission-gated human approval**: ship documented setup adding
   `"permissions": { "ask": ["Bash(edm-state approve-gate*)", "Bash(edm-state archive*)"] }`
   so every gate approval and archive physically stops at a human click, regardless of entry path,
   compaction, or prompt drift.
2. **Convergence gate** (D2): `cmd_approve_gate` accepts `code-audit`, sets
   `code_audit_converged=true` (mirrors the `3.5` dedicated-boolean precedent); the field is
   removed from `cmd_set`'s allowlist. Prompts change from "set the flag" to "present the gate via
   AskUserQuestion, then run approve-gate". Grandfather existing converged initiatives (D4).
3. **`phase-complete` verifies artifacts**: per-phase `[[ -s ... ]]` checks (planning.md, SRD,
   audit report, ticket pack README, ticket audit, qc-summary). Mode-aware: phases recorded via
   `skip-phase` are exempt; there is NO generic `--force` override (D13). Ten lines of bash;
   converts "the model said so" into "the deliverable exists".
4. **`archive` verifies the lifecycle**: gates 1-3 in `gates_approved`, `current_phase == 6`,
   phase 6 completed, zero unclosed PARTIALs (no override flag -- D13), convergence -- with
   warn-and-proceed legacy degradation for pre-existing initiatives only (C-4).
5. **`cmd_set` allowlist**: enumerate legal keys, reject unknown keys naming the valid set;
   gate-ish fields (`code_audit_converged`, `compliance_gate_approved`, `gates_approved`) refuse
   `set` entirely and name the `approve-gate` command.
6. Smoke tests for every rule above, including the 3-command bypass as a must-fail case.

### WS3. CI + fixture eval (R7) -- before the big prompt refactor

1. `.gitlab-ci.yml`: `bash -n` over `bin/`, the four smoke suites, `claude plugin validate`, the
   WS1 class check, `edm-lint-artifacts` over tracked artifact trees.
2. Fixture eval in `plugins/edm/evals/`: small synthetic repo + frozen initiative description; a
   headless run (`claude -p`) executes plan -> srd -> audit; artifacts scored mechanically
   (requirement-ID coverage, vague-AC regexes from the pattern library, Mermaid parse success,
   coverage-map bidirectionality). Gives WS5 a before/after regression number.

### WS4. Structured findings + no-deferral (R3 + requirement 3)

1. Each of the 11 lenses emits, alongside its prose report, one JSON line per finding:
   `{"id":null,"lens":"L1","sev":"P1","confidence":"high","file":"...","line":42,"title":"...","status":"open"}`.
   Lenses report everything with a confidence level; the recall-suppressing single-lens discard is
   replaced by confidence-ranked synthesis.
2. Synthesizer keeps the LLM merge/dedup judgment but emits `findings-ledger.jsonl` (stable CA-NNN
   IDs) as the authoritative record; markdown ledger is rendered from it.
3. New `edm-state audit-converged <PREFIX>`: jq query over the JSONL. Blocking set is
   **open P0+P1+P2** (D6) -- the no-deferral policy is one predicate in code, not five prompt
   restatements.
4. Prompt-side alignment: `CLAUDE.md` Severity vocabulary drops "explicitly defer otherwise" from
   P2; the five restatement sites match; the "P2 deferred to next maintenance window" worked
   example is removed; `skills/implement/SKILL.md:95,105` remediate all FAIL severities.
5. PARTIAL closure (R6, hardened by D13): new `/edm:verify-runtime <PREFIX>` is a **mandatory**
   Phase 6 closure step -- drives every runtime check from `partial_verdict_map`, records
   PASS/FAIL per AC, writes `post-deploy/verification.md`. Archive hard-blocks while any PARTIAL
   is unclosed (lands in WS2.4); there is no override flag. A PARTIAL that fails runtime
   verification becomes a FAIL and is remediated like any other.

### WS5. Orchestrator as dispatcher (R4, full -- D10)

1. Phase procedures move to their phase skills as the single source of truth; the orchestrator
   shrinks to **at most 300 lines**: intake (1a-1d), mode dispatch (table and routing only -- the
   three mode sub-flows and the Gate 3.5 block move out), the gate PROTOCOL (written once), resume
   logic, communication cadence, and per-phase "invoke `/edm:plan`, then present Gate 1". The cap
   is derived from the retained-content list in `srd.md` EDMV3-46 rather than estimated; the
   earlier ~200 figure was not achievable against that list, and 300 is the single number used in
   `planning.md`, `srd.md` and `architecture.md`.
2. Phase skills invoke via the Skill tool (confirmed working; this marketplace's git plugin is the
   precedent). `plugins/edm/CLAUDE.md:22-23`'s stale "skills don't load skills" constraint is
   rewritten to document the composition pattern and its failure mode (target skill not enabled).
3. The weak gate protocol in `skills/plan`, `skills/audit-srd`, `skills/audit-tickets` is deleted;
   all phase skills end with "present the gate per the orchestrator gate protocol". Safe because
   WS2.1 means a drifted skill cannot silently record an approval anyway.
4. Duplicate step numbering and accumulated hand-edit drift cleaned up in the same pass.
5. Regression-checked against the WS3 fixture eval before/after.

### WS6. Mermaid rule (requirement 2)

1. New canonical section in `plugins/edm/CLAUDE.md` beside Severity vocabulary: literal `;` never
   appears in Mermaid label/node/edge text; use `#59;` (no leading `&`). Include one before/after
   example. No renderer validation needed (D8).
2. One-line named reference from the 11 touch points: 3 authoring agents, 2 auditing agents,
   4 mirrored skills (post-WS5 this shrinks to the phase-skill copies only), 2 pattern-library
   docs (as `###` entries under `Anti-Patterns`, respecting the four-`##` contract).
3. 4th `edm-lint-artifacts` violation class: inverse Mermaid-only line-set helper (existing
   `build_ignore_set` skips fenced code; this class scans only inside ` ```mermaid ` fences) that
   flags raw `;` inside label text. Deterministic backstop, ships independent of prompt edits.

### WS7. Prompt streamline (original Large-scope mandate, D1)

Applied after WS5 so every edit lands once in the deduplicated skills:

1. Communication cadence + deliverable-length calibration per the Opus 5 guide (explorer 02 C1):
   scoped so conversational-conciseness guidance can never shorten deliverable artifacts (SRD
   length floors stay -- explorer 02 F4).
2. Confidence field usage guidance per the Sonnet 5 code-review-recall guidance (C2) -- the
   prompt-side complement of WS4.1.
3. Structural adoptions from caveman/ponytail (C3): persistence framing where agents drift,
   decision ladders for orchestrator branch points, output contracts for artifact-producing
   agents, "when NOT to" carve-outs. Explorer 02 Part D do-NOT-adopt list is the guardrail.
4. Lens tiering (R5.3): mechanical lenses (L2, L5, L7, L10) to `sonnet`/`high`; judgment lenses
   (L1, L3, L8, L9, L11) stay `opus`; documented smoke-audit path
   (`/edm:code-audit PREFIX --lenses L1,L9,L11`) for small initiatives.

### WS8. Economics honesty (R5, root cause D9)

1. Wire `phase-complete 6` into the end of `skills/implement` / `skills/code-audit` flow; add
   `audit-round-complete` markers capturing per-round tokens. (WS2.4's archive check makes the
   omission impossible to repeat silently.)
2. Scope token attribution to the driving session's JSONL, or relabel the number "project activity
   during phase".
3. Refresh the pricing table to current model generation.
4. Drop the human-baseline ROI table from default `/edm:metrics` output (keep raw cost/duration);
   move ROI framing to the deck.

### WS9. Pattern-library curation (F9)

1. `cmd_update_patterns` inserts under the correct existing `##` heading (never EOF-appends past
   the fourth section) and marks entries `status: pending-review`.
2. The audit gate presents pending pattern entries for human keep/edit/discard alongside the
   findings review -- closing the harvest half of the feedback loop with a curation half.

### WS10. Delete list (R8 + F11 + D12)

- `EDM_Plugin_Presentation.pptx`, `EDM_Plugin_User_Guide.docx` -> repo `docs/` outside the plugin
  source dir; `.DS_Store` deleted + gitignored.
- `skills/implement/SKILL.md:162-172` ritual (replaced by WS1.5 test).
- `TaskCompleted` hook + `cmd_record_task_duration` no-op.
- `lifecycle_mode=partial` enum value (D12).
- `monitors/watch-impl` sleep-loop: document lifecycle or delete (confirm host-side management
  first -- flagged [inferred] in review).

### Out of scope (separate initiative -- scope boundary, not deferral; D14)

**Phases-as-data** (`phases.json` interpreted by a slim orchestrator; modes become phase-graph
variants): a distinct future initiative, decided on its own merits after WS1-WS5 prove out through
one real initiative. WS2.3's artifact checks and WS5's dispatcher are its first column and
interpreter respectively -- nothing in this plan blocks it. Nothing about it is deferred *within*
EDMV3: no EDMV3 requirement depends on it, and no EDMV3 work is left incomplete pending it.

## Constraints

- bash 3.2 compatibility for every `bin/` script (macOS default; no associative arrays, no `mapfile`).
- macOS/Linux only -- stated constraint, documented in README (D11).
- `gates_approved` holds integers only -- non-numeric gates use dedicated boolean fields (the
  `3.5` precedent; `code-audit` follows it).
- C-4 backward compatibility: new/changed state fields default so v1.x/v2.0 state files keep
  working; legacy escape hatches degrade to warn-and-proceed, never hard-fail.
- `docs/audit-patterns/*.md` four-`##`-heading Living-Library Contract -- new content is
  `###`-level only; WS9 makes the tooling respect it too.
- All artifact text ASCII-only and linted at commit; `#59;` is ASCII-safe.
- No AI-attribution trailers; gitmoji shortcodes only.
- Skill-to-skill invocation via the Skill tool is supported and becomes load-bearing (WS5);
  callers must include `Skill` in `allowed-tools` and handle target-plugin-not-enabled gracefully.
- Preserve untouched: state-derived path resolution, locking/atomicity, artifact-hash drift
  detection, QC verdict semantics, gate approval rules text, CA-NNN ledger IDs, lint
  infrastructure, HANDOFF auto-refresh (EDM-REVIEW.md "genuinely good" list).

## Dependency Map

- WS1 first -- nothing else is credibly testable while `edm-init` breaks every fresh initiative.
- WS2.2 (approve-gate accepts `code-audit`) must land before `code_audit_converged` leaves
  `cmd_set`'s allowlist, or the flow is stranded.
- WS3 (CI + fixture eval) must precede WS5 (dispatcher refactor) -- the eval is WS5's regression
  harness; CI locks WS1/WS2 in place.
- WS4.3 (computed convergence) is the mechanical enforcement of D6; the WS4.4 prompt edits are its
  documentation, and both should land in the same MR to avoid a contradictory window.
- WS6's `CLAUDE.md` canonical section lands before the 11 named references; the lint class (WS6.3)
  is independent and can ship any time.
- WS7 strictly after WS5 (edit once, not twice).
- WS8-WS10 independent; batch opportunistically after WS2.
- No external service dependencies (Jira MCP untouched).

## Complexity Estimate

*(Corrected 2026-07-25 against `architecture.md`'s scope-delta table and the round-1 SRD audit.
Every correction is an increase in stated scope discovered while grounding the design in the code,
not a change of direction.)*

- **Files affected**: ~55-60 (Large scope D1 + review workstreams; overlaps because WS5 collapses
  the duplication WS7 would otherwise edit twice).
- **New modules**: 1 CI file, 1 evals fixture tree, **3 new `edm-state` subcommands**
  (`audit-converged`, `render-ledger`, `audit-round-complete`) plus `migrate-schema` added by the
  audit -- four in total; **3 new `bin/` check scripts** (`edm-check-grants`,
  `edm-check-vocabulary`, and the fourth Mermaid violation class inside `edm-lint-artifacts`);
  1 `/edm:verify-runtime` skill; 2-4 smoke-test files plus `_harness.sh` helpers. No new runtime
  services.
- **Agent and skill grant edits**: **13 agent tool-grant corrections** (`edm-qc-auditor`,
  `edm-explorer`, and all 11 `edm-audit-*` lenses -- the write instruction for the lenses lives in
  `skills/code-audit/SKILL.md:44,99`, not in the agent files), plus a `disallowedTools` line on
  `edm-audit-synthesizer`, plus `AskUserQuestion` grants to 5 gate-presenting skills.
- **Phase-skill edits**: **Step 0 preflight added to all 8 phase skills** (`plan`, `srd`,
  `audit-srd`, `tickets`, `audit-tickets`, `implement`, `code-audit`, `verify-runtime`) on top of
  the WS5 procedure relocation, because the `UserPromptExpansion` gate-check hooks do not cover the
  Skill-tool path. Step 0 is defense in depth; the deterministic control is the kernel-side refusal
  in `phase-start` and the completed, mode-aware `cmd_gate_check`.
- **Smoke-suite re-baselines**: 3 assertions in `wave4b-smoke.sh` (`:36`, `:38`, `:40`) for the
  vocabulary sweep, the Step-7 set at `wave4b-smoke.sh:123-125` for the dispatcher move, and
  `wave5-smoke.sh:175` for the metrics change -- each shipping in the same MR as its text change.
- **Integration points**: 10 (edm-state dispatch/help, `cmd_archive`, `cmd_set`, `cmd_approve_gate`,
  HANDOFF writer, commit-lint hook, `update-patterns`, pattern-library contract, `edm-init`
  handshake, Skill-tool composition).
- **Estimated size**: **Medium-Large, 40-60 tickets across 10 epics (one per workstream).**
  Recommend delivery in three MR waves matching the dependency map: wave A = WS1+WS2+WS3,
  wave B = WS4+WS5+WS6, wave C = WS7-WS10. Version: 2.0.0 -> 2.1.0 at wave A, 3.0.0 at wave B
  (dispatcher restructure is a major behavioral change).

## Go/No-Go

**Decision**: GO
**Rationale**: The three explicit requirements are small and pattern-following; the review
converted the remaining risk from unknown to enumerated, with every load-bearing claim reproduced
or confirmed at file:line. Team adoption (D7) makes the enforcement kernel the difference between
a demo and a product. Sequencing puts a regression harness (WS3) in front of the only genuinely
risky refactor (WS5).
**Conditions**: none outstanding -- all six open questions resolved (D7-D12).

## Riskiest Assumptions

- **WS5 regression risk**: the dispatcher refactor rewrites the most-loaded prompt in the system.
  Mitigation: WS3 fixture eval before/after, plus wave-B isolation. If the eval shows regression,
  fall back to sync-check-only (the reviewed alternative) without blocking waves A/C.
- **Skill-tool composition depth**: the git-plugin precedent is one skill calling one skill; WS5
  chains orchestrator -> phase skill across 6 phases with state handoffs. A 10-minute spike early
  in wave B validates depth/context behavior before committing the refactor. [assumption: composition
  behaves identically when the caller is itself a skill mid-flow]
- **Permission-rule coverage** (WS2.1): `"ask"` rules are settings, not plugin-enforced -- a user
  who removes them reopens the prose-only gap. Mitigation: `edm-state doctor`-style check warning
  when the rules are absent; documented as required setup.
- **Grandfathering surface** (D4): archived initiatives with old-flow convergence must not fail new
  archive/validate checks -- C-4 warn-and-proceed applies; smoke test covers a v2.0 state file.
- **Anthropic guidance transfer** (explorer 02 F1/F2): the guides target direct API prompting;
  Claude Code layers its own system prompt. WS7 edits are scoped so cadence guidance cannot bleed
  into deliverable length (SRD floors stay).
- **JSONL dual-output drift** (WS4): lenses now write prose + JSONL; if they diverge, the JSONL
  wins by definition -- stated in the synthesizer prompt and checked by a smoke test that the
  rendered ledger matches the JSONL.

## Open Questions

None remaining -- all resolved. See `decisions.md` D1-D14.
