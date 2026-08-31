# Lens L9: Spec & Ticket Compliance -- EDMV3 Code Audit Round 2 (full)

**Date**: 2026-07-31
**Round**: pass-2, full
**Tree**: `/Users/darryl.porter/projects/marketplace`, branch `edm/edmv3-prompt-streamline`
**Inputs used**: `SRD/edm/EDMV3__prompt-streamline/srd.md` (v1.3.0), `tickets/README.md` (read in full, 814 lines),
`tickets/epics/01..11`, `decisions.md` (D1-D32 plus the Finding-to-Commit Ledger),
`code-audit/findings-ledger.jsonl` (filtered to `lenses` containing `L9`),
`code-audit/pass-1_2026-07-28/REMEDIATION.md`, `code-audit/pass-1_2026-07-28/lens-L9.md`.

**Method note.** Every verdict below was re-derived from the current files. The prior ledger's
`status` field was ignored, as instructed. No shell was available to this lens, so all evidence is
read/grep evidence; commands that require execution (`run-all.sh`, `claude plugin validate`,
`edm-check-grants`) are again listed under "Not verified" rather than asserted.

---

## Round-1 L9 findings: verification against the current tree

| ID | Round-1 severity | Round-2 verdict | Evidence |
|---|---|---|---|
| CA-013 | P1 (L9+L11) | **STILL OPEN** -- nothing landed | see below |
| CA-033 | P1 | **FIXED** | all six verify clauses rewritten |
| CA-034 | P1 | **PARTIALLY FIXED** -- ticket and script halves fixed, `baseline/README.md` half not | see below |
| CA-089 | P2 | **PARTIALLY FIXED** -- SRD half amended, ticket half still contradicts the tree | see below |
| CA-090 | P2 | **FIXED** | `epics/02:185-193` |
| CA-091 | P2 | **FIXED** | `epics/03:569-574` |
| CA-092 | P2 | **FIXED** | `tickets/README.md:3`, `:10`, `:576` |

---

## Missing Implementations (P1)

| Requirement | Ticket | What's Missing | Evidence (search results) |
|---|---|---|---|
| EDMV3-116 (Must) negative branch: canonical sections relocated "into a path agents *can* resolve ... that agent prompts reference by relative path" (`srd.md:3009-3012`) | T41 AC4 (`epics/06:152-158`) | The generated file still has **zero prompt-surface consumers**. Unchanged since round 1 -- the remediation did not land. | `grep -c 'canonical-sections\.md' plugins/edm/**` returns hits in exactly six files: `plugins/edm/CLAUDE.md` (2), `CHANGELOG.md` (2), `docs/canonical-sections.md` (1), `bin/vocabulary-allowlist.txt` (2), `bin/edm-sync-canonical-sections` (7), `bin/tests/wave6-smoke.sh` (8). **Zero under `plugins/edm/agents/` or `plugins/edm/skills/`.** |
| EDMV3-54 (Must) vs EDMV3-116 (Must) -- still mutually unsatisfiable | T42 AC4 / T41 AC4 | No change request was raised. `srd.md:2846-2849` still mandates the reference form `` `CLAUDE.md Sec."Mermaid diagram conventions"` `` *exactly*, and `:2850-2852` still requires those same references "verified to actually resolve from an installed plugin cache before this requirement is considered done" -- the thing D22 disproved by two independent methods. | `srd.md:2846-2852` (verbatim unchanged from round 1); `decisions.md:28` (D22) unchanged |
| EDMV3-116's remaining work has no named owner | -- | D22 still closes with "should be picked up as **its own immediate follow-up ticket**" -- the exact "candidate, not a follow-on" construction D29 forecloses. D29 still names exactly one surviving ticket (EDMV4-T01, the AC6 budget re-derivation), which is a different item. Nothing in `decisions.md` postdates D32 (2026-07-28). | `decisions.md:28` (D22 final clause), `decisions.md:38` (D29), last row of the table is D32 at `:41` |

**Aggravating evidence found this round.** `plugins/edm/CLAUDE.md:300-302` still describes the relocation
as future work -- "a plugin-relative path new prompt-surface references should point at instead of the
bare `CLAUDE.md Sec."..."` form **once EDMV3-T42 lands**". T42 landed at `fa108ee` and merged at
`424f3dc` (recorded in D22 itself), two waves ago. The plugin's own conventions file therefore states a
precondition that is already in the past while the edit it gates has never been made.

This is ledger finding **CA-013**, re-opened unchanged at P1. It is the single largest open L9 item and
it is exactly where round 1 left it.

---

## Partial Implementations (P1 / P2)

| Ticket | AC | What the Spec Requires | What Code / Prose Does | File:Line |
|---|---|---|---|---|
| T22 (CA-034) | AC8 | **Reworked correctly.** The AC now reads "the driver requires working Claude auth for a real run. Either an exported `ANTHROPIC_API_KEY` or an already authenticated `claude` CLI session satisfies the contract; `--provision-only` needs neither." | The ticket half and the script half both match the shipped code now. `run-eval.sh:24-27` documents `ANTHROPIC_API_KEY` as an *optional* explicit path; `:37-39` documents exit 2 as "no working Claude auth"; `:181-183` dies only when both paths fail, with a message naming both remedies. **But the third named site was not corrected**: `evals/baseline/README.md` still asserts the abolished single-path contract -- "`run-eval.sh` only ever produces a real run directory by calling `claude -p` against `ANTHROPIC_API_KEY`", "with a real `ANTHROPIC_API_KEY` exported", and a closing command whose first line is `export ANTHROPIC_API_KEY=sk-...`. That file is the closing command for T23 AC8/AC9/AC13, so the stale precondition is load-bearing. | AC (fixed): `epics/03:400-406`. Script (fixed): `plugins/edm/evals/run-eval.sh:24-27`, `:37-39`, `:181-183`. **Residual**: `plugins/edm/evals/baseline/README.md:9-10`, `:24`, `:28` |
| T39 (CA-089) | AC7 + Technical Notes + Out of Scope | The SRD half was amended as prescribed and is now honest: `srd.md:2755-2759` says the tripwire "may ship even when the full eval gate is not yet armed, provided the ticket and decisions ledger record that narrower outcome honestly: it verifies the fallback path, catches any future re-introduction of duplicated orchestration prose", and `srd.md:2763` marks it "(fallback tripwire, shipped and also used on the rollback path)". `epics/05:554` Target Components carries the same amendment. | **The ticket body was not amended, so the pack still contradicts both the amended SRD and the tree in three places.** (1) `epics/05:602-605` still specifies "a script asserting the duplicated orchestration blocks **are identical**" -- the shipped script asserts the inverse: `PROCEDURE_MARKER='## Operational Orchestration'` must be **absent** from the dispatcher and **present** in each of the eight phase skills. (2) Its verify command, "prints `exit=0` on a synced tree and non-zero when one block is edited", does not describe the shipped exits. (3) `epics/05:628` still reads "written **only** on the fallback path. Do not build it speculatively." while the script is in the tree and wired at `bin/tests/run-all.sh:137-144`; `epics/05:101` still lists it as "EDMV3-T39, and only on NO-GO". | Ticket (unamended): `epics/05:101`, `:602-607`, `:628`. Code: `plugins/edm/bin/edm-check-skill-sync:42-60`, `:62-68`. Wired: `plugins/edm/bin/tests/run-all.sh:137-144`. SRD (amended): `srd.md:2755-2759`, `:2763` |

**New this round -- change-control records for two round-1 AC reworks were never written.**

| Ticket / rule | What the pack's own rule requires | What is recorded | File:Line |
|---|---|---|---|
| D19 | `tickets/README.md:64-65`: "An acceptance criterion that cannot be verified is a specification defect (D15, EDMV3-117), reworked or rescoped **through gate change control** -- never recorded as accepted." Six ACs were reworked this remediation cycle. | D19 still names **two** -- "T61 AC13 and T01 AC9 are AMENDED" -- and still says the amendment reached "`.gitlab-ci.yml`'s `test:smoke` job comment and `wave7-smoke.sh`'s T21 AC5 case". The four ACs it never named (T16 AC10, T42 AC12, T44 AC6, T56's CI row) were rewritten with no record anywhere. | `decisions.md:23` |
| D23 | Same rule. T23 AC13 was rewritten from an impossible temporal clause into an artifact-provenance assertion. | D23 is still framed entirely around T39 and never names T23, AC8, AC9 or AC13. | `decisions.md:29` |

Nothing in `decisions.md` postdates D32 (2026-07-28), so no later entry absorbs either. This is a new P2.

**New this round -- the repository's own plugin registry entry is two waves stale and no ticket owns it.**

| Fact | Evidence |
|---|---|
| The distribution manifest is correct and complete | `.claude-plugin/marketplace.json:35` = `"version": "3.1.0"`; `:45` registers `./skills/verify-runtime`; all 30 agents listed. `plugins/edm/.claude-plugin/plugin.json:4` = `3.1.0`. T66's version work landed. |
| The repository conventions doc is not | `/Users/darryl.porter/projects/marketplace/CLAUDE.md:54` still reads "**edm** (v2.1.0)" and enumerates 13 skills with **no `/edm:verify-runtime`** -- a user-invocable skill this initiative shipped in wave B (T33, EDMV3-41). |
| No ticket names the file | T66 Target Components (`epics/11:618`) names `plugins/edm/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json:35`, `plugins/edm/CHANGELOG.md` and `plugins/edm/CLAUDE.md` only. T04's (`epics/01:411`) names `plugins/edm/README.md` and `plugins/edm/CLAUDE.md`. T64 and T65 are the wave-A/B analogues of T66. The repository-root `CLAUDE.md` appears in no ticket's Target Components. |
| The pack's own cross-cutting AC covers it | `tickets/README.md:92`: "Project conventions doc (CLAUDE.md, CONTRIBUTING.md, or equivalent) updated if conventions change" -- and `:90` scopes that row to tickets that "change user-visible behavior or public API". A new slash command is both. |

Reported as a P2 coverage gap rather than a P1, because the mechanically-consumed manifests are all correct;
only the human-facing registry description is wrong.

---

## Scope Creep (P2)

| File / Feature | Not Specified In | Recommendation |
|---|---|---|
| *(none newly found this round)* | -- | -- |

`bin/edm-check-skill-sync` was round 1's scope-creep item. It is no longer reported here as scope creep,
because `srd.md:2755-2759` now sanctions it; what survives is the unamended ticket text, reported above
as a partial implementation (CA-089). `bin/_edm-lint-lib.sh` was examined and is **not** scope creep --
see Noted.

---

## Fresh full-surface pass: requirements verified satisfied this round

These were re-checked directly against the tree in round 2 (round 1 read epics 07-11's AC bodies only
partially, so this is new coverage rather than a repeat).

| Requirement / AC | Verified by |
|---|---|
| EDMV3-46 / T38 AC (dispatcher <= 300 lines) | `plugins/edm/skills/orchestrator/SKILL.md` is **204 lines** |
| EDMV3-59 / T45 AC1, AC2 | `## Communication` at `skills/orchestrator/SKILL.md:45`; `<tone_preference>` at `:201`, after the anti-patterns block |
| EDMV3-61 / T46 AC1 (thirteen agents) | `grep -c 'deliver what was asked at the scope intended' plugins/edm/agents/` returns **13 files, 1 hit each** -- the eleven lenses plus `edm-explorer` and `edm-audit-synthesizer` |
| EDMV3-64 / T46 AC10 (all 30 agents) | `^## When this does NOT apply` present in **30 of 30** `agents/*.md` |
| EDMV3-64 / T46 AC12 (cross-referenced, not restated) | `recomputed each run` appears once, in `plugins/edm/CLAUDE.md:589`, and in zero agent files |
| EDMV3-65 / T47 AC1, AC3, AC4, AC5 | `skills/plan/SKILL.md:162` ("maximum 4"), `:163` ("use one"), `:167` ("distinct top-level source trees"); `grep -c 'edm-explorer' skills/orchestrator/SKILL.md` returns **0** |
| EDMV3-70 / T50 | `skills/orchestrator/SKILL.md:170` calls `edm-state phase-complete <PREFIX> 6` (EDMV3-T50), and `skills/implement/SKILL.md:186`, `:189` state the same ordering |
| EDMV3-41 / T33, EDMV3-113 wave-B half | `skills/verify-runtime/SKILL.md:8` frontmatter carries `AskUserQuestion` |
| EDMV3-42 / T32 | `record-partial-verdict` is referenced from `skills/verify-runtime/SKILL.md:71`, `:77`, `:151` and `skills/implement/SKILL.md:117` |
| EDMV3-34 / T26, EDMV3-36 / T28, EDMV3-71 / T51 | `render-ledger`, `audit-converged` and `audit-round-complete` are all invoked from `skills/code-audit/SKILL.md:76-88` |
| EDMV3-77 / T54, EDMV3-78 / T55 | `pending-review` written by `bin/edm-state` (1 site), presented by all three audit skills (`code-audit` 4, `audit-srd` 4, `audit-tickets` 4), documented at `docs/audit-patterns/README.md`, asserted 8 times in `wave7-smoke.sh` |
| EDMV3-79 / EDMV3-109 / T56 | `.gitlab-ci.yml:251` -- `lint:pattern-library-contract` job emits the four-heading contract result; 7 four-heading assertions in `wave7-smoke.sh` |
| EDMV3-43 / T30 | `.gitlab-ci.yml:118-124` runs `bash plugins/edm/bin/edm-check-vocabulary` in the lint stage |
| EDMV3-80 / T57 | No `.pptx`, `.docx`, `.DS_Store` or other binary remains anywhere under `plugins/edm/` (full glob, 139 files) |
| EDMV3-92/97/98/111 version half of T66 | `plugin.json:4` and `marketplace.json:35` both `3.1.0` |
| CA-033's target side | `.gitlab-ci.yml:255` carries the AC5 comment; `:269` and `:304` are the two `bash plugins/edm/bin/tests/run-all.sh` invocations; zero wave-suite literals |

---

## Noted / Not Actionable

- **CA-106** (wave-A eval baseline `scores.json` absent) -- re-verified as a recorded boundary. `evals/baseline/`
  still contains `README.md` only. D23 (`decisions.md:29`) records the seven attempts, the six driver defects
  fixed, the org spend limit, and an executable closing command; `edm-compare-eval`'s distinct exit 3 keeps an
  absent baseline from reading as a pass. **Consequence worth stating plainly**: T23 AC8, AC9 and the newly
  reworked AC13 all fail today for this one reason. That is the boundary, not three separate findings.
- **T48 AC4's provenance header is a literal placeholder, deliberately.** `plugins/edm/CLAUDE.md:306` reads
  "Derived from tiering matrix `<date>`" -- the angle-bracket token, not a date. AC4's verify command asks for
  "the header with a date". **NOTED, not a finding**: `:307-313` immediately states "**Status: NOT yet
  matrix-derived.**", explains that the matrix is built and unit-verified but unrun because D23's baseline does
  not exist, and points at D28 for the exact command that "replaces this note with a real run date". This is the
  documented-as-intentional branch of the False Alarm Filter, and it is the same boundary round 1 accepted for
  T48 AC11.
- **CA-108** (T67 AC6 Mermaid-ratio budget is a bare ratio with no input size and no absolute ceiling) --
  re-verified: D26 calls the budget shape malformed and D29 (`decisions.md:38`) carries the re-derivation as
  named ticket **EDMV4-T01**, with a scope line and a closing verify command. Recorded boundary.
- **CA-109** (T67 AC9 and AC13 recorded `verified-locally-pending-pipeline`) -- re-verified at `decisions.md:35`;
  each names its missing dependency (a live runner; a real costed eval run). Recorded boundary.
- **CA-110** (`git ls-files` accepted where T57 AC5 said `find`) -- re-verified at `decisions.md:39`; the AC text
  and Technical Notes are amended to match and both forms are recorded as measured returning 0. Accepted deviation.
- **CA-125** (`SETTABLE_KEYS` widened past T09 AC11's three named keys) -- unchanged and still in scope by
  construction: AC5 requires the allowlist to enumerate every legal key and AC11/AC12 make live callers the
  source of truth.
- **CA-132 / D8 / EDMV3-88** (no Mermaid renderer spike) -- re-verified as a boundary with no ticket by
  construction. The deterministic lint class ships regardless (T43) and T44's corpus validates the rule.
- **`plugins/edm/bin/_edm-lint-lib.sh` is not scope creep.** T30 AC9 (`epics/04:781-784`) explicitly sanctions
  the shape: "the checker **sources or mirrors** `bin/edm-lint-artifacts`' `report_violation` and ignore-marker
  helpers rather than re-deriving the file walk". The extraction is the "sources" branch, it was prescribed by
  round-1 REMEDIATION CA-050, and `wave7-smoke.sh:1381` asserts it against T30 AC9 by name. Three shipped
  scripts source it (`edm-check-grants:101`, `edm-lint-artifacts:52`, `edm-check-vocabulary:57`).
  **Cross-lens pointer, not an L9 finding**: the session-start `git status` shows the file as untracked (`??`),
  which -- if it stays that way -- means three shipped scripts have a missing dependency in any clone or
  installed cache. That is a wiring/distribution question for L11/L10, and I did not verify the current index
  state myself.
- **`architecture.md:873`** still describes `edm-check-skill-sync` as "(assert the duplicated blocks stay
  identical)". That row is the *alternatives-considered* table -- it records the rejected design, so the
  wording is correctly historical and is deliberately excluded from CA-089. `architecture.md:647` carries the
  same phrasing in rationale prose; also historical, and folded into CA-089's fix rather than raised separately.
- **`tickets/README.md:9`** describes the subject as "(EDM plugin v2.0.0)". That is the generation-time subject
  statement, and `:14` names the three wave targets (v2.1.0 / v3.0.0 / v3.1.0). Correctly historical.
- **CA-092's two historical anchors** were correctly left alone: `tickets/README.md:759`, `:772` and `:775` still
  say v1.2.0 because they describe change requests CR1-CR6 that landed in that revision.

---

## Not verified (commands named, not run)

This lens had no shell. Everything below rests on the record rather than on execution:

1. `bash plugins/edm/bin/tests/run-all.sh` -- every AC of the form "Verify: `bash .../wave{6,7}-smoke.sh` (case
   "...")". Named cases were confirmed to exist by grep (T06 AC10's `code_audit_gate_*` trio at
   `wave6-smoke.sh:477-540`; T56's four-heading cases, 7 hits in `wave7-smoke.sh`; T30 AC9 at `:1381`), but no
   suite was executed.
2. `claude plugin validate plugins/edm/` -- T02 AC9, T03 AC11, T60 AC1. Asserted four times at `decisions.md:52`.
3. `bash plugins/edm/bin/edm-check-grants` -- T02 AC10, T03 AC2/AC4, T35 AC8, T38 AC4/AC13, T46 AC4.
4. `bash plugins/edm/bin/tests/timing.sh --lint` / `--mermaid-ratio` -- the T67 budget figures (D26).
5. `bash plugins/edm/evals/score-artifacts.sh ...` and `tiering-matrix.sh --self-test`.
6. The current git index state of `plugins/edm/bin/_edm-lint-lib.sh`.

---

## Summary

**Actionable this round: 1 P1 (CA-013), 4 P2 (CA-034 residual, CA-089 residual, and two new).
Zero P0.**

**Closed since round 1: CA-033, CA-090, CA-091, CA-092** -- all four re-verified fixed with fresh evidence,
none of them merely re-described.

The remediation cycle landed the mechanical ticket-text corrections cleanly. What it did not land is the one
finding that required editing prompt-surface files (CA-013), the two documentation tails of findings whose
primary site was fixed (CA-034's `baseline/README.md`, CA-089's `epics/05`), and the change-control records
that the pack's own D13/D15 rules require for an AC rework. Under D6/D13 every open P2 blocks convergence, so
all five need a fix or a False Alarm Filter argument before this round can converge.

Key file paths referenced, for transcription and follow-up:

- `/Users/darryl.porter/projects/marketplace/SRD/edm/EDMV3__prompt-streamline/srd.md` (`:2755-2759`, `:2763`, `:2846-2852`, `:903-904`)
- `/Users/darryl.porter/projects/marketplace/SRD/edm/EDMV3__prompt-streamline/decisions.md` (`:23` D19, `:28` D22, `:29` D23, `:38` D29)
- `/Users/darryl.porter/projects/marketplace/SRD/edm/EDMV3__prompt-streamline/tickets/README.md` (`:3`, `:10`, `:64-65`, `:92`, `:576`)
- `/Users/darryl.porter/projects/marketplace/SRD/edm/EDMV3__prompt-streamline/tickets/epics/02-enforcement-kernel.md:185-193`
- `/Users/darryl.porter/projects/marketplace/SRD/edm/EDMV3__prompt-streamline/tickets/epics/03-ci-and-fixture-eval.md` (`:400-406`, `:569-574`)
- `/Users/darryl.porter/projects/marketplace/SRD/edm/EDMV3__prompt-streamline/tickets/epics/05-orchestrator-dispatcher.md` (`:101`, `:554`, `:602-607`, `:628`)
- `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-check-skill-sync:42-68`
- `/Users/darryl.porter/projects/marketplace/plugins/edm/evals/baseline/README.md` (`:9-10`, `:24`, `:28`)
- `/Users/darryl.porter/projects/marketplace/plugins/edm/CLAUDE.md` (`:300-302`, `:306-313`)
- `/Users/darryl.porter/projects/marketplace/CLAUDE.md:54`
