# EDMV4 -- ECC Integration: Planning & Discovery

Source document: `plugins/edm/docs/ecc-integration-analysis.md` (revision dated 2026-08-30).
Explorer reports: `explorers/01-bin-shell-tooling.md`, `02-hooks-runtime.md`,
`03-skills-agents-prompt-surface.md`, `04-ecc-source-assessment.md`.

## Scope Statement

Adopt into the EDM plugin the recommendations from the ECC integration analysis: Part 4 in full
(GateGuard edit-gate, the `update-patterns` read-only defect fix, an orchestrator size classifier,
and three new audit lenses L12/L13/L14) plus Part 5 items 5.2 through 5.5 (repo-readiness
scorecard, hookify rules-as-data layer, Stop-hook completion gate, and codemaps). This initiative
also absorbs the named-but-never-created `EDMV4__lint-and-pipeline-budgets`, inheriting its three
orphaned ticket IDs (T01, T04, T05) per `decisions.md` D1.

**5.1 (the bounded implementer/QC remediation loop) is out of scope by Gate 1 decision** and is
recorded as a named follow-on initiative. It is Large by itself and its cost-ceiling precondition
is design work distinct from every other item; the eleven remaining items should not be gated
behind it.

Phase 1 verified every structural claim in the source document against source. **The document is
substantially accurate but wrong in eleven specific places**, and two of its three inherited
tickets are largely already done. The scope below is the corrected one, not the document's.

## What Phase 1 Changed About the Scope

### Items that shrank

| Item | Source document assumed | Verified reality |
|---|---|---|
| EDMV4-T01 | A 50-initiative fixture generator must be written | `bin/tests/timing.sh` already has `--generate-fixture` (default N=50, `:217,239-253`), `--lint`, `--all-lint` and `--mermaid-ratio` (`:366-451`), all wired to the post-`ea31ce8` one-awk-per-file class-4 scan. Remaining work is a budget *framing* fix: `CHANGELOG.md:382` calls the 1.40x ceiling "still malformed" (no stated size floor) even though the number passes |
| EDMV4-T05 | Fix CA-532 and CA-490, then capture the baseline | Both bugs are **already fixed and verified** in current source (`evals/run-eval.sh:420-421,460-461`; `bin/edm-compare-eval:62-81`). CA-537's CI fix is moot -- no `.gitlab-ci.yml` exists in this repo. Only `evals/baseline/scores.json` is genuinely missing, and capturing it is a live-API-spend and credential decision, not code |
| 5.4 | Surface four `validate` anomalies at Stop instead of only at archive | `OPEN_PARTIALS` **already blocks** at `validate` (`bin/edm-state:1827-1847`). Two others are confirmed informational. The fourth, "phase started with no `completed_at`", **does not exist as an anomaly at all** -- `TIME_ORDER` only fires when both timestamps are present and inverted (`:1721-1728`) |
| D3 (`disable-model-invocation`) | Candidate scope addition | Already fixed upstream in 3.2.1 (commit `bdec805`) with a regression guard added to `bin/edm-check-skill-sync`. Out of scope; arrives via the D4 rebase |

### Items that grew

| Item | Source document scope | Verified scope |
|---|---|---|
| 4.4 (lenses) | `skills/code-audit/SKILL.md`, `bin/edm-state`, `CLAUDE.md`, synthesizer | **37 distinct touch points** (`explorers/03` Sec.1.1). The largest is `bin/tests/wave7-smoke.sh`, carrying **~28 hardcoded `-eq 11` assertions** across seven regression classes -- including T47 AC6 and T48 AC6, tests written specifically to assert the lens count never changes (`wave7-smoke.sh:4902,5417`). The source document does not mention the test suite at all. `bin/tests/wave6-smoke.sh:3440-3448` will actively invert: its `--lenses L1,...,L11` full-round assertion becomes an 11-of-14 *partial* round the moment `ALL_LENS_IDS` grows |
| EDMV4-T04 (anchoring) | 8 files named in `CLAUDE.md` | **14 files** (5 agents + 9 skills, `explorers/03` Sec.4.1). `CLAUDE.md`'s own list misses `edm-qc-auditor.md`, `verify-runtime/`, `push-jira/`, `orchestrator/`, `metrics/`, `code-audit/SKILL.md`. And `edm-qc-auditor.md:39` cites `Sec."Unverifiable acceptance criteria (D15)"`, which has **no `canonical-sections.md` mirror at all** -- a different fix shape than the other 13 |
| 5.3 (hookify) | Adapt ECC's rule evaluator | **ECC has no evaluator.** Exhaustive search of `scripts/`, `hooks/hooks.json` and all six operator names found the condition-matching engine exists only as documentation (`explorers/04` Sec.7). The `/hookify*` commands write, list and toggle rule files; nothing evaluates them at tool-call time. EDM would build the evaluator from nothing, with only the file *format* reusable |
| 4.2 (update-patterns) | Four skills call it | **Six** call sites (`implement:46`, `code-audit:135`, `audit-tickets:52`, `audit-srd:50`, `test:132`, `test-coverage:65`). The in-code comment at `bin/edm-state:5672` repeats the wrong number and should be corrected in the same change |

### Corrections to the source document

Verified against source; each should be treated as authoritative over the document.

1. **ECC's hook count is 23 across 7 events, not 25 across 8** (`explorers/04`). The document's
   own per-row table is individually correct; only its summary total and event-type count are wrong.
2. **The seven security triggers are not in `rules/common/security.md`.** That file contains an
   unrelated 8-item pre-commit checklist. The triggers live at `orch-pipeline/SKILL.md:100-104`,
   which itself miscites `security.md`. The document repeated a citation without checking it.
   Cite `orch-pipeline/SKILL.md`.
3. **Hookify has no evaluator in ECC** (above).
4. **`GAN_EVAL_CRITERIA` is documented but dead code** -- `scripts/gan-harness.sh` never reads it.
   Do not port it as a real knob.
5. **`delivery-gate`'s SKILL.md undocuments a third disk tier** -- the code has a 30GB warning
   between the documented 50GB and 15GB tiers.
6. **`silent-failure-hunter`'s body is 44 lines, not "~30"** (47% higher). The other two are 35
   and 39.
7. **`harness-audit.js` consumer mode is 16 checks / 39 points**, not 11 / 29, once the
   unconditionally-appended GitHub checks are counted.
8. **The `update-patterns` line cites are stale** -- `:5595` and `:5627-5629`, not `:5577`/`:5624`.
9. **The analysis's GateGuard env-var table omits `GATEGUARD_DISABLED=1`**, a second independent
   kill switch alongside `ECC_GATEGUARD=off` (`gateguard-fact-force.js:732-734`).
10. **`MultiEdit` needs one retry per still-unchecked file**, not one retry total
    (`gateguard-fact-force.js:1234-1256`) -- a mechanical subtlety the document's prose omits.
11. **Codemaps placeholder lines are `generate.ts:225-231`**, not `:200-240`. Substance confirmed.

Claims that **could not** be verified, beyond the document's own Part 8.3 list: GateGuard's
upstream (`zunoworks/gateguard`) licence, and Claude Code's multi-hook-per-event combination
semantics. Both are blocking preconditions -- see Open Questions.

## Component Inventory

| Component | Path | Status | Notes |
|---|---|---|---|
| GateGuard hook | new; vendor `gateguard-fact-force.js` (1,301) + `shell-substitution.js` (482) + `gateguard-heredoc.js` (259) | New (4.1) | Dependency closure is exactly these 3 files. Bash rewrite est. 400-600 lines excluding the two helpers, which are the harder half |
| JSON deny-shape mechanism | none | New (4.1) | `permissionDecision`/`hookSpecificOutput` appear **zero times** in this repo. EDM has only ever blocked via exit codes, and only on a `Bash`-wrapped `git commit` |
| Phase-6-active marker | none | New (4.1) | No cheap per-tool-call "which initiative is active" path exists. Nearest primitives run at SessionStart/Stop cadence; `cmd_checkpoint:2735` does write-locking plus SHA-256 per initiative |
| `cmd_update_patterns` write target | `bin/edm-state:5581-5595` | Modified (4.2) | Add `${CLAUDE_PLUGIN_DATA}` -> `${XDG_DATA_HOME:-$HOME/.local/share}/edm` chain. First `bin/` consumer of that variable -- zero existing precedent |
| Read-only skip branch | `bin/edm-state:5625-5630` | Modified (4.2) | Becomes seed-copy-then-write instead of permanent no-op |
| Pattern-file readers | `edm-srd-writer.md:25`, `edm-ticket-writer.md:32`, `edm-implementer.md:24-25`, `edm-test-coverage-auditor.md:40-42` | Modified (4.2) | Write-side and read-side must land together or harvested content is silently lost |
| Size classifier | `skills/orchestrator/SKILL.md:103-114` | Modified (4.3) | New Step 1b.5/1c.0. Hard backstop: `MODE_ENUM_LIST`/`LIFECYCLE_MODE_ENUM_LIST` at `bin/edm-state:807-808`, validated at `:5063-5114` -- the classifier can only ever recommend one of the 8 existing enum values |
| `ALL_LENS_IDS` | `bin/edm-state:1613,1615` | Modified (4.4) | 11 -> 14; the `-eq 11` self-check and its error text both change |
| Code-audit lens table and prose | `skills/code-audit/SKILL.md` (12 sites) | Modified (4.4) | Table, headings, `--lenses` validation range, smoke-audit language |
| L12 Silent Failures | new `agents/edm-audit-*.md` | New (4.4) | Unconditional. Taxonomy from `silent-failure-hunter.md:23-49`, five categories |
| L13 Type Design | new `agents/edm-audit-*.md` | New (4.4) | **Stack-conditional; blocked on a design question** -- see Open Questions |
| L14 Behavioral Test Coverage | new `agents/edm-audit-*.md` | New (4.4) | Mandate boundary vs L4 and `edm-test-coverage-auditor` needs one clarifying sentence |
| Smoke-suite lens assertions | `bin/tests/wave7-smoke.sh` (~28 sites), `wave6-smoke.sh:3440-3448` | Modified (4.4) | Largest blast radius. T47 AC6 / T48 AC6 exist to assert the count is permanent and must be deliberately revised |
| Bounded remediation loop | `skills/implement/SKILL.md:40` | Modified (5.1) | Replaces unbounded FAIL-remediation prose. Plateau mechanism is directly portable from `gan-harness.sh:175-259` |
| Remediation attempt counter | none | New (5.1) | `closure_history:4978` is PARTIAL-closure-shaped, not a fit for FAIL-attempt tracking |
| Per-attempt cost attribution | none | New (5.1) | `phase_durations[6]` is not decomposed by cycle. ECC's own driver has **no dollar ceiling at all** -- only an iteration cap |
| Repo-readiness scorecard | new `bin/` script | New (5.2) | Follow `_edm-cli-lib.sh` help sentinels and `SCORER_VERSION` versioning precedent. Reuse signals `validate`/`session-start`/`get-coverage` already compute rather than re-detecting |
| Hookify rule loader + dispatcher | new `bin/` script + hook registration | New (5.3) | Evaluator built from scratch. **No YAML parsing exists anywhere in `bin/`** |
| Stop-hook validate wiring | `hooks/hooks.json:91-100` | Modified (5.4) | `OPEN_PARTIALS` path is wiring-only; the fourth anomaly needs new design |
| By-name reference anchors | 14 files | Modified (T04) | Pattern to copy is verbatim at `edm-audit-logic.md:69` and `edm-srd-auditor.md:38-42` |
| `evals/baseline/scores.json` | `plugins/edm/evals/baseline/` | **Missing** (T05) | Needs 3 live `run-eval.sh` captures, middle-scoring run committed. Human credential decision |
| Codemaps | none | New/deferred (5.5) | Analysis recommends fresh or none; offers an `SRD/.codemap.md` interim written by the first explorer |

## Constraints

- [ ] **Platform**: macOS and Linux only, **bash 3.2+** floor. No associative arrays. Existing code
      carries live comments about bash-3.2 gotchas including a process-substitution fd leak class
      fixed under CA-472. Any new `bin/` script must hold this floor.
- [ ] **Required binaries are `bash`, `jq`, `git` only.** A YAML-parsing hookify format would add a
      new required binary this plugin has never needed. Node would be a new runtime dependency for
      GateGuard if vendored.
- [ ] **Licence -- RESOLVED (D13)**: ECC root is **MIT** (`ECC/LICENSE:1-3`, Affaan Mustafa 2026).
      GateGuard's upstream `zunoworks/gateguard` is **also MIT** ("Copyright (c) 2026 Hirokazu Seto
      / ZUNO WORKS K.K."), verified by direct inspection of its `LICENSE`. Both meet the
      direct-inspection standard `CLAUDE.md` applies to `caveman`/`ponytail`. **Remaining
      obligation**: vendoring GateGuard is verbatim reuse of ~2,042 lines, so MIT attribution
      genuinely binds -- retain the copyright headers and carry a NOTICE naming ZUNO WORKS K.K.
      A bash rewrite derived from that source is a derivative work under the same obligation.
- [ ] **D2 guard**: 4.4 is additive so does not violate it on its face, but L13's conditionality
      must be justified as genuine *inapplicability*, never as cost-driven exclusion.
- [ ] **D6 guard**: the 4.3 classifier may cite the mode matrix by section reference and compute a
      recommendation; it may never restate what each mode does.
- [ ] **Severity vocabulary is closed** -- new lenses use P0/P1/P2/NOTED with no local scale.
- [ ] **ASCII-only**, though note `edm-lint-artifacts` class 2 does **not** scan `skills/`,
      `agents/` or `docs/` automatically. New lens prompts need `--path` checking by hand.
- [ ] **No CI pipeline exists.** `bin/tests/run-all.sh` plus the git-commit hook are the entire
      enforcement surface.
- [ ] **Branch hygiene (D4)**: this branch is 2 commits behind `origin/main` and still carries the
      D3 defect. Every file:line citation in Phase 1 is against a pre-rebase tree.

## Dependency Map

**Hard preconditions, before implementation:**

```
SPIKE A (multi-hook-per-event semantics) --blocks--> 4.1 and 5.3
SPIKE B (deny shape for native Edit/Write/MultiEdit) --blocks--> 4.1
DESIGN C (L13 round_type=full) --blocks--> 4.4's L13 only
DESIGN D (cost ceiling) --blocks--> 5.1 entirely
DECISION E (rule format: YAML vs JSON) --blocks--> 5.3
DECISION F (GateGuard licence + Node dependency) --blocks--> 4.1
D4 REBASE --blocks--> everything landing on this branch
```

- **Spike A** is the highest-leverage unknown: EDM's `hooks.json` has never had two independently
  authored blocking hooks compete on one tool call. `UserPromptExpansion`'s five blocks prove
  *adding* works but are matcher-disjoint, so they never exercise the case. 4.1 and 5.3 both want
  `PreToolUse`; if both are adopted, this blocks both.
- **Spike B**: if an exit-code-only hook cannot deny a native `Edit`, GateGuard is a hard
  requirement to adopt the JSON deny shape, not an option.
- **Design C**: if L13 auto-excludes on an untyped stack, a 13-of-14 round must still read as
  `full`. The current derivation at `bin/edm-state:4567-4571` compares the run set against
  `ALL_LENS_IDS` and has no concept for "auto-N/A'd lens" vs "operator-requested subset". CA-471's
  completeness backstop would need a third state.
- **4.2's two sides must land in one commit** -- a seed-only read against a harvested-only write
  silently loses everything harvested.
- **5.2's value depends on 4.3** (the classifier is the scorecard's consumer), though its
  construction is not blocked.
- **4.4's test rewrite blocks** anything else landing cleanly on `wave7-smoke.sh`.
- **T01, T04, T05 are independent** of each other and of everything above. T05 is blocked only on
  a human credential decision.

## Complexity Estimate

Revised after the Gate 1 decision to move 5.1 out of scope.

- Files affected: **~45-55**
- New modules: 3 lens agents, 2 new `bin/` scripts (scorecard, hookify loader), 1 GateGuard hook
  (3 vendored files or a bash rewrite -- approach deferred to Phase 2), 1 Phase-6 marker primitive
- Integration points: 6 (`PreToolUse`, `Stop`, `bin/edm-state` round-type logic, orchestrator
  Step 1c, `edm-sync-canonical-sections`, the four pattern-file read sites)
- **Estimated size: Large (50-85 tickets)**, sitting at the low end -- roughly 50-57

Per-item: T05 Small (verification plus a boundary record), T01 Small, 4.3 Small, 4.2 Small,
5.5 Small (interim only), T04 Small-Medium, 5.4 Small-Medium, 5.2 Medium, 5.3 Medium,
4.1 Medium (plus two blocking spikes), **4.4 Medium and the widest blast radius** (37 touch
points, ~28 test assertions).

## Go/No-Go

**Decision**: **CONDITIONAL GO**

**Rationale**: Every item has a verified structural gap and the source document held up well under
checking -- eleven corrections, none of which invalidate a recommendation. Three items (4.2, 4.3,
T04) are unambiguous wins that could start immediately after the rebase. But the initiative as
scoped is Large, and four separate items are blocked behind unknowns that no amount of planning
resolves -- they need mechanical spikes against the live host.

**Conditions**:

1. The D4 rebase onto `origin/main` lands before any implementation.
2. Spikes A and B are executed and recorded as decisions before 4.1 or 5.3 are ticketed. These
   follow the existing D21/D22/D24 precedent of spiking a Claude Code behaviour this plugin depends
   on rather than assuming it.
3. Design C (L13 `round_type`) is resolved in Phase 2, not deferred to implementation.
4. ~~GateGuard's upstream licence is confirmed before any vendoring.~~ **MET (D13)** --
   `zunoworks/gateguard` is MIT, verified by direct inspection. Attribution obligations apply to
   both vendoring and a derived bash rewrite.
5. 5.1 is carried as a named follow-on initiative, not silently dropped. Its cost ceiling must be
   designed and reviewed before any of its code is written -- the source document's own explicit
   precondition, and ECC's driver provides no model since `gan-harness.sh` has **no dollar ceiling
   at all**, only an iteration cap plus plateau detection.

**Shape decided at Gate 1**: 5.1 moves to its own initiative. The remaining eleven items form a
coherent, mostly-mechanical body of work with three unambiguous quick wins (4.2, 4.3, T04) that can
start immediately after the D4 rebase.

## Riskiest Assumptions

1. **That an exit-code-only `PreToolUse` hook can deny a native `Edit`/`Write`/`MultiEdit`.** EDM's
   only blocking precedent is a `Bash`-wrapped `git commit`. Unverified either way from source.
2. **That Claude Code executes multiple matching hooks on one event independently** rather than
   first-registered-wins or requiring consolidation. No in-repo evidence exercises the case.
3. **That `${CLAUDE_PLUGIN_DATA}` is genuinely writable and persistent across plugin upgrades on
   both supported platforms.** Nothing in this codebase has ever exercised it; the reservation is
   prose in `CLAUDE.md:71` only.
4. **That `round_type=full` can be cleanly redefined once L13 is conditional.** A design question
   the source document does not resolve either.
5. **That the ~28 `wave7-smoke.sh` assertions found by grep are the complete set.** Pattern
   matching was used, not a full read of a 7,000+ line file. A bare `-eq 11` with no nearby
   "eleven" token could have been missed -- re-grep for `-eq 11` and `== 11` before closing the
   inventory.
6. **That per-attempt cost attribution can reuse `get_session_tokens_since`/`compute_cost_usd`
   unmodified.** No existing call site invokes them more than once per phase.
7. **That GateGuard's +2.25/10 result generalizes.** n=2, self-reported, unblinded, no published
   rubric -- the document says so itself. The *mechanism* is structurally sound and matches EDM's
   own audit premise; the *effect size* is directional only.
8. **That the 3.2.1 cache differs from 3.2.0 only in skill frontmatter.** Only frontmatter was
   diffed, not full file bodies.

## Open Questions

All Gate 1 open questions are resolved -- see Decisions Made below. Four questions remain for
Phase 2 to answer as architecture work, carried forward rather than left open here:

- **GateGuard implementation approach** (vendor Node vs bash rewrite) is a Phase 2 architecture
  decision by explicit Gate 1 choice, now gated behind Spikes A and B only.
- **Spike A** (multi-hook-per-event combination semantics) and **Spike B** (deny shape for native
  `Edit`/`Write`/`MultiEdit`) must be executed and recorded before 4.1 or 5.3 are ticketed.
- ~~`zunoworks/gateguard` upstream licence~~ **RESOLVED (D13)** -- MIT, verified by direct
  inspection. Attribution obligations carry into whichever implementation approach Phase 2 picks.
- **The `round_type` third state** for auto-N/A lenses needs a concrete design in Phase 2,
  including how CA-471's completeness backstop distinguishes "lens legitimately N/A" from
  "missing JSONL".

## Decisions Made

- **Where 5.1 lives**: **Its own initiative.** The bounded implementer/QC remediation loop is
  Large by itself and its cost-ceiling precondition is design work distinct from every other item.
  Splitting it means the remaining eleven items are not gated behind that design phase. EDMV4
  records it as a named follow-on rather than an unnamed candidate, per the D13/D14 precedent.
- **GateGuard implementation (4.1)**: **Resolve in SRD.** Deferred to Phase 2 architecture,
  contingent on Spikes A and B and the `zunoworks/gateguard` licence check. Phase 2 chooses
  between vendoring the three Node files (~2,042 lines, adds a Node runtime dependency) and a bash
  rewrite (400-600 lines excluding the two harder helper files).
- **Hookify rule format (5.3)**: **JSON rule files.** jq-native, adds no required binary, and
  matches how every other structured file in `bin/` is consumed. ECC compatibility buys nothing
  here because ECC has no evaluator to inherit -- only the format was ever reusable, and EDM is
  free to choose a better-fitting one.
- **L13 stack-conditionality (4.4)**: **Auto-N/A plus a new `round_type` state.** Follow the test
  layer's N/A-agreement precedent (`edm-test-integration.md:21-25`): code-audit Step 1 detects the
  stack, L13 exits N/A on untyped code, and `round_type` learns to distinguish an auto-N/A lens
  from an operator-requested subset so a 13-of-14 round can still read as `full`. This keeps L13's
  conditionality framed as genuine inapplicability, satisfying the D2 guard.
- **EDMV4-T05 baseline**: **Recorded as an explicit scope boundary with a named follow-on.** Both
  named bugs (CA-532, CA-490) are already fixed and verified, so T05's code work is complete. The
  live capture of `evals/baseline/scores.json` stays a decision for whoever owns the
  `ANTHROPIC_API_KEY`, per `evals/baseline/README.md`'s own recorded position that it must not be
  spent by an agent verifying its own ticket. T05 closes as verification plus a boundary record.
- **EDMV4-T04 scope**: **All 14 verified files, plus a third canonical section.** Anchor the full
  verified set rather than the 8 `CLAUDE.md` names, and add "Unverifiable acceptance criteria
  (D15)" as a third generated section so `edm-qc-auditor.md:39`'s orphaned citation resolves.
  Requires re-running `edm-sync-canonical-sections` and re-verifying its `--check` drift assertion
  in the same ticket.
- **Codemaps (5.5)**: **The `SRD/.codemap.md` interim.** The first explorer of an initiative writes
  a reusable current-architecture codemap that later initiatives read and refresh. No generator is
  built. This is the cheapest way to test a premise the source document itself flags as unmeasured,
  and it avoids the failure mode ECC hit (a generator whose Data Flow and External Dependencies
  sections are literal placeholders).
- **The eleven corrections**: **Written back into `ecc-integration-analysis.md`.** Amend the source
  document in place, in the Part 8.2 style it already uses to self-correct twice, so the next
  reader gets the corrected version instead of re-deriving the same eleven findings. `planning.md`
  keeps the correction table as the audit record of what changed.
