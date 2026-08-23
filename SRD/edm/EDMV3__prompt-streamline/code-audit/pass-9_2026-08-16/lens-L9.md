I lack `Write` and `Bash` this round (the CA-130 class, NOTED -- not re-filed). Both halves follow.

---

# Code Audit Lens L9 -- Spec & Ticket Compliance (Round 9, post-remediation verification)

**Initiative:** EDMV3 -- prompt-streamline
**Scope audited:** `SRD/edm/EDMV3__prompt-streamline/srd.md`, `tickets/README.md` + `tickets/epics/01..11`, `plugins/edm/**`, `.gitlab-ci.yml`
**Round type:** full | **Priority 1:** verify the Stage A/B/C remediation stayed within spec

## Coverage caveat (read before the findings)

Delivered tool set this round was `Read, Grep, Glob, WebFetch, WebSearch, TaskStop` -- **no `Bash`, no `Write`**. Every `Verify:` clause below was evaluated **statically** (read the target, reason the command's result) rather than executed, and this report was returned as chat text for transcription. This is CA-130 / CA-377's standing condition, recorded NOTED with a do-not-re-file disposition; it is restated only so the confidence qualifier on this round's convergence read is explicit. The 2182/0 suite figure is orchestrator-supplied and was not independently verified by this lens.

---

## Priority-1 verification result: the three Stage C AC amendments

| Amendment | Claim | Verified against tree | Verdict |
|---|---|---|---|
| **T66 AC3** (CA-468) | cites a verbatim shipped case label | `epics/11:676-677` now cites `"T66 AC3 -- subcommand count and membership match the dispatch table exactly"`; shipped at `wave7-smoke.sh:1297` (`echo`). Sibling citation at `epics/11:681-682` matches `wave7-smoke.sh:1346`. | **ACCURATE** |
| **T30 AC4** (CA-469) | seven shipped allowlist classes; both verify derivations measure what they claim | `epics/04:776-791` enumerates all seven; `vocabulary-allowlist.txt` carries data lines at `:13,:15,:18,:21,:24,:28,:34,:41,:52` = **9** (matches `grep -cvE '^[[:space:]]*(#\|$)'` -> 9) and `^# Class [0-9]+` labels 1,1,2,2,3,4,5,7,6 -> `sort -u` = **7**. | **ACCURATE** |
| **T29 AC12** (CA-470) | checker-as-mechanism replaces the hand-rolled three-filter pipeline | `epics/04:686-694` now states "every `defer`-family hit under `plugins/edm/` is covered by a labelled class in `bin/vocabulary-allowlist.txt`" and verifies via `bash plugins/edm/bin/edm-check-vocabulary`. The one genuinely uncovered hit (WHATS_NEW.md) is gone -- `plugins/edm/*.md` now globs to CLAUDE.md, README.md, CHANGELOG.md only (D59). | **ACCURATE** |

**CA-471** (completeness gate): wired in both halves -- `bin/edm-state:4438-4468` (`cmd_audit_round_complete` downgrades to `round_type=partial` on a lens-JSONL miss) and `skills/code-audit/SKILL.md:104,:143-148` (refuse-to-proceed + `tooling-notes.md`). Mechanism verified present; see **L9-004** for the AC-ownership gap it left.

**D59** (WHATS_NEW.md deleted) and **D60** (nine-finding debt set) verified recorded at `decisions.md:68-69`.

**The CA-416 same-commit sweep obligation did NOT hold for this round's own commits.** Four of the six findings below are stale-citation instances authored inside the same remediation batch that shipped `spec_swept`.

---

## Findings (L9: Spec & Ticket Compliance)

### Missing Implementations (P1)

| Requirement | Ticket | What's Missing | Evidence (search results) |
|---|---|---|---|
| -- | -- | **None this round.** Every SRD requirement with an implementing ticket resolved to shipped code. The four requirements with standing non-implementation dispositions (EDMV3-27/28/29 baseline via CA-106/D23/D36; EDMV3-101/103 via CA-109/D27) are NOTED, not re-filed. | -- |

### Partial Implementations (P1)

| Ticket | AC | What the Spec Requires | What Code Does | File:Line |
|---|---|---|---|---|
| **EDMV3-T23** | AC1, AC2, AC8, AC9, AC10 | AC1: the scorer scores **"exactly five"** dimensions -- *"not 'at least five', which would leave two runs of different scorer versions incomparable"* -- verified by `jq -e '.dimensions \| length == 5'`. AC2 defines dimensions 1-5. AC8 requires a committed **"four-dimension baseline"** with `dimensions_scored: 4` and `dimensions_skipped \| length == 1`, plus `grep -n 'four-dimension' evals/baseline/README.md`. AC9/AC10 say "the five per-dimension ranges" / "the five dimensions". | The shipped scorer emits **six**: `DIM_NAMES=(requirement-id-coverage ac-testability mermaid-parse-success coverage-map-bidirectionality lens-jsonl-prose-agreement known-gap-recall)` (`score-artifacts.sh:145`), `scorer_version` bumped 1.0.0 -> 1.1.0 (`:134`). AC1's verify command now returns **false**. Dimension 6 gates only on `run.json.fixture == "tiny-svc"` (`:546-553`), so it **scores on a wave-A plan->srd->audit run** -- a fresh baseline capture yields `dimensions_scored: 5`, making AC8 unsatisfiable by construction. `evals/baseline/README.md:50,:62-65` still documents `dimensions_scored: 4` and "**four-dimension baseline**", so the D23/D36 closing command for CA-106 now produces an artifact its own runbook and AC declare wrong. **No AC anywhere** covers `known-gap-recall`, `expected.json`'s new `srd_match` patterns, `fixture_version 1.1.0`, or `run.json`'s new `fixture` field (T22 AC2's `jq -e '.gaps \| length > 0'` still passes and says nothing about them). The script's own header is internally contradictory: `:4` says "exactly five dimensions", `:38` says "The six dimensions". `score-artifacts.sh:38-39` **acknowledges the AC conflict in a code comment** ("T23 AC1 originally fixed this at exactly five; CA-462 added the sixth") and no ticket, AC or `decisions.md` entry records it. | `SRD/edm/EDMV3__prompt-streamline/tickets/epics/03-ci-and-fixture-eval.md:495-500`, `:501-517`, `:546-555`, `:558-562` vs `plugins/edm/evals/score-artifacts.sh:4`, `:38-56`, `:134`, `:145`, `:535-574`; `plugins/edm/evals/baseline/README.md:50`, `:62-65` |

**Why P1, same class as CA-424:** an acceptance criterion whose `Verify:` command returns *false* against the shipped tree is a false statement of the contract, not a documentation nit. CA-424 was rated P1 on exactly this basis. **False Alarm Filter applied:** not deferred/out-of-scope (T23 is a Must, wave A, closed); not an implementation detail (a scorer dimension set is the eval's entire comparability contract, which is why AC1 was written as "exactly", not "at least"); no pending change request -- `decisions.md` has no entry for CA-462 and `srd.md` EDMV3-27 is unamended.

**Fix:** amend T23 AC1 to "exactly six" with the new verify literal; add dimension 6's definition to AC2; rewrite AC8 as a **five**-dimension wave-A baseline (`dimensions_scored: 5`, `dimensions_skipped | length == 1`) and sweep `evals/baseline/README.md:50,:62-65` in the same commit; correct `score-artifacts.sh:4`; add an AC (on T22 or T23) owning `srd_match`, `fixture_version` and `run.json.fixture`.

### Scope Creep (P2)

| File / Feature | Not Specified In | Recommendation |
|---|---|---|
| **`round_type` downgrade inside `cmd_audit_round_complete`** (`bin/edm-state:4438-4468`) plus the new **"refuse to proceed"** gate at `skills/code-audit/SKILL.md:104-113`. A round in which all eleven lenses ran is now recorded `round_type=partial` -- **permanently non-convergent** -- when any `lens-L{N}.jsonl` is missing, empty or unparseable. | **No AC anywhere**, and both candidate owners explicitly disclaim it. T27 Out of Scope (`epics/04:445`): *"`audit-round-complete` and per-round cost -- EDMV3-T51 (wave C)."* T51 Out of Scope (`epics/08:203`): *"`round_type` recording -- EDMV3-T27 (wave B)."* T51's AC1-AC10 (`epics/08:145-186`) cover only timestamp, duration, tokens, cost, the `OPEN_AUDIT_ROUND` anomaly, metrics, C-4, double-completion and atomicity. T27 AC1 (`epics/04:375-380`) derives `round_type` at **`audit-round-start`** only, from lens-set equality. The pack's own rule at `tickets/README.md:66-68` requires any ticket adding "a gate, a refusal, an allowlist, or a permission boundary" to carry **at least one positive and one negative AC**; this convergence-blocking refusal has neither. | The mechanism is a genuine improvement over CA-471's own prescription -- do not remove it. Give it an owner: add an AC to **T51** (positive: complete round with all JSONL present stays `full`; negative: a missing/empty/unparseable `lens-L{N}.jsonl` records `partial` and `audit-converged` then refuses; C-4: no pass directory or no `lenses-run.txt` leaves the round unchanged) and delete the contradicting Out-of-Scope line in **both** T27 and T51 in the same commit. |
| **`EDMV3-T68` was added to the index and the EDMV3-90 boundary row, but the pack's own bookkeeping was not swept** -- see the next table, row 1. The result is a 68th ticket that nine pack-level statistics deny exists. | `tickets/README.md` | See next table. |

### Stale / Falsified Specification Text (P2)

These are the CA-416 class. All four were authored or invalidated **inside the round-8/9 remediation commits**, i.e. the same batch that shipped the `spec_swept` obligation intended to prevent them.

| # | Location | Defect | Evidence |
|---|---|---|---|
| **1** | `tickets/README.md` (nine sites) | **The T68 addition swept two rows and left the pack's arithmetic asserting 67 tickets, `T01..T67`, and a Won't-Have convention T68 now violates.** | `:12` `\| Tickets \| 67 (EDMV3-T01 .. EDMV3-T67) \|`; `:232` E4 = **10** tickets, wave **B** (T68 is E4, wave C); `:240` Total **67**; `:257-266` sizing S=**31**, total **67**, "Arithmetic: 4 + 31 + 26 + 6 = 67" (T68 is S -> 32/68); `:365-384` Mermaid subgraph `WC` lists T45..T67 with **no T68 node and no `T28 --> T68` edge** while `:221` declares `Depends On \| T28`; `:519-521` class lines cover T45..T67 only; `:527-531` "All **67** nodes appear in exactly one `class` line ... 24 + 20 + 17 + 2 + 3 + 1 = 67"; `:545` "**123 edges over 67 nodes**"; `:586-588` "Every ticket `EDMV3-T01` .. `EDMV3-T67` appears in at least one row"; `:737-741` "the union ... **115 IDs** ... all **67** tickets carry at least one `SRD Refs` entry and all **67** appear in at least one coverage-map row". **Convention conflict:** `:590-596` states a Won't Have "is not delivered by anything", records EDMV3-90 as *stripped* from `SRD Refs`, and says listing one "made the pack's own statistics table contradict its ticket field tables in five places" -- yet `:221` and `epics/04:1200` now put `EDMV3-90 (amended)` back into a ticket's `SRD Refs`, while `:723-729` still reports Won't Have covered-by-a-ticket = **0**. That is the exact contradiction the convention was written to remove, reintroduced. |
| **2** | `srd.md:3829-3856` vs `tickets/README.md:689`, `epics/04:1200,:1207` | **The pack asserts an SRD amendment that does not exist in `srd.md`.** The ticket pack now says EDMV3-90 is "amended by D57/D58 for exactly one sanctioned flag" and T68's `SRD Refs` reads `EDMV3-90 (amended, D57/D58)`. `srd.md` EDMV3-90 is **byte-unchanged**: AC1 (`:3836-3837`) still reads *"No `--force`, `--accept-partials`, `--skip-checks`, `--yes`, or equivalent bypass flag exists on `phase-complete`, `archive`, `approve-gate`, or `audit-converged`"* and AC4 (`:3846-3848`) still bans a recorded-exemption category. `srd.md` is still v1.3.0 with no CR entry -- contrast the pack's own documented amendment route, CR1-CR6 at `tickets/README.md:785-795`, each of which landed as a versioned `srd.md` change. **This is explicitly NOT a re-file of CA-423** (NOTED under human override D58): I make no claim that the flag is unauthorized. The defect is a missing paperwork half -- D58 enumerated four consequences (ticket, tree-wide relabel, T28 AC12 amendment, README boundary row) and `srd.md` was not among them, leaving one governing artifact asserting a fact about another that the other contradicts. |
| **3** | `epics/04:560` (T28 AC12, the CA-424 amendment) | **The amendment written to close CA-424 cites smoke cases by a label the same commit batch relabelled out of existence.** AC12's `Verify:` reads *"...plus the **T-EDMV4** and CA-425 accept-p2-debt cases"*. `CHANGELOG.md:21` and `epics/04:1243` both record that every in-code site was relabelled `EDMV3-T68` (CA-430). A grep for `T-EDMV4` across `plugins/edm/bin/tests/` returns **zero**; the shipped labels are `EDMV3-T68 -- ...` (`wave6-smoke.sh:667,:682,:707,:713,:725`) and `CA-425 -- ...` (`:765,:779,:791`). Direct violation of `tickets/README.md:73-81` ("Verbatim shipped case labels, never a paraphrase (G40/CA-368)") -- the rule CA-468 was filed under, broken again three ACs away. |
| **4** | repo-root `CLAUDE.md:61` | **The plugin registry entry still reads `edm (v3.1.0)` after the 3.2.0 bump.** `plugins/edm/.claude-plugin/plugin.json:4` = `3.2.0`; `.claude-plugin/marketplace.json:35` = `3.2.0`. T21 AC2 (`epics/03:237-243`) makes the root `CLAUDE.md` Current Plugins entry an EDMV3 deliverable and verifies it by grep; T66 AC1's CA-431 amendment (`epics/11:648-654`) covers `plugin.json` + `marketplace.json` only and does not name this file. **CA-127 filed and fixed this exact row at round 3 and it has re-staled on the next version bump** -- there is still no assertion pinning it, which is why it recurs. Fix: sweep the row and extend `wave7-smoke.sh`'s "versions agree" case to read the root `CLAUDE.md` literal alongside the two manifests. |

---

## Noted / Not Actionable

**Verified remediated this round (confirming closure, not re-filing):**

- **CA-468** -- T66 AC3's paraphrase replaced with the verbatim `wave7-smoke.sh:1297` label. Closed.
- **CA-469** -- T30 AC4's five-class list replaced with the seven shipped classes; both verify derivations now measure what they claim (9 data lines / 7 class labels, both re-derived by hand against `vocabulary-allowlist.txt`). Closed.
- **CA-470** -- T29 AC12's hand-rolled three-filter pipeline replaced by an invocation of the shipped checker; the one genuinely uncovered hit (WHATS_NEW.md) removed by D59. Closed.
- **CA-465** -- `plugins/edm/WHATS_NEW.md` no longer exists (`plugins/edm/*.md` = CLAUDE.md, README.md, CHANGELOG.md). D59 records the deletion and the re-entry conditions. Closed. *Residual, not re-filed:* `edm-check-vocabulary`'s `SCOPE_ROOTS` (`:98-107`) still names CLAUDE.md and README.md as explicit files rather than the plugin root, so the structural blind spot CA-465(b) named survives -- the next top-level markdown file is invisible to the backstop by construction.
- **CA-471** -- completeness backstop present in both `bin/edm-state:4438-4468` and `skills/code-audit/SKILL.md:104-113,:143-148`. Mechanism closed; AC ownership filed above as scope creep.
- **CA-431** -- CHANGELOG 3.2.0 entry exists (`CHANGELOG.md:7-30`), version bumped in both manifests, and all five `code_audit_p2_debt_*` fields now carry a row in `CLAUDE.md`'s state-field table with absent-value semantics, satisfying T66 AC5. Closed except the root-CLAUDE.md half, filed above.
- **CA-430** -- EDMV3-T68 exists (`epics/04:1198-1246`) with six ACs, positive and negative branches, a `Depends On` and a coverage-map row; `T-EDMV4` is gone from all in-code sites. Closed except the pack-statistics half, filed above.
- **CA-424** -- T28 AC12 amended at `epics/04:551-561`. Closed except the stale `T-EDMV4` label in its own verify clause, filed above.
- **CA-416** -- **partially remediated, do not re-file.** `spec_swept` now exists in both prescribed places: the ledger field rules (`agents/edm-audit-synthesizer.md:177-182`) and the remediation format's "**Spec/AC text to sweep in the same commit**" row (`:122-126`). The **enforcement half is still prose-only** -- "the remediating commit is not done while it is unmet" has no mechanism, no smoke case and no `audit-converged` check -- and no ledger entry carries the field yet. The four stale-spec findings above are the direct measurement of that residual.

**False alarms cleared by the filter:**

1. **T68 AC citations** -- every cited case label resolves. AC2's `"accept-p2-debt still refuses with an open P1"` is a verbatim `check` label at `wave6-smoke.sh:677` (not a paraphrase of the `echo` at `:667`); AC5's `"HANDOFF debt row carries the accepted-by field"` is verbatim at `:820`; AC3's four labels are verbatim at `:774,:786,:792,:795`; AC1/AC4's are exact substrings of the shipped `echo` lines and remain greppable.
2. **`missing-task-grant` rule in `edm-check-grants` (CA-441)** -- not scope creep. T03 AC6 (`epics/01:334-336`) already states the generic contract: "the extended checker fails when a skill's body uses a tool its `allowed-tools` does not list." `Task` is such a tool; the rule is an instance of an existing AC, not a new one.
3. **`bin/edm-lint-staged-artifacts` (CA-436)** -- not scope creep. Carries `EDM-HELP-BEGIN/END` sentinels and the shared `print_help` (`:2-32`), has a `bin/` table row in `CLAUDE.md`, and is counted by T66 AC3's mechanical derivation (`find plugins/edm/bin -maxdepth 1 -type f -name 'edm-*' ! -name '*.awk'`). Extracting an unlintable JSON one-liner into a testable script is a necessary implementation detail under filter 2.
4. **T32 AC6's `git diff --stat plugins/edm/hooks/hooks.json` verify**, now false after CA-409/CA-410/CA-436/CA-440 -- covered by CA-376's D48 carve-out: the nine `git diff | grep -c` forms are per-merge-request historical claims, not tree-state assertions.
5. **T02's Target Components naming `qc/qc-summary.md` at `edm-qc-auditor.md:71`**, now `qc/qc-shard-{NN}.md` after CA-440 -- `tickets/README.md:57` declares Target Components drift-tolerant by design ("the symbol name is the authoritative anchor; line numbers drift"). T31's `qc-summary.md` AC (`epics/04:881`) and T50's (`epics/08:94-96`) both survive because `/edm:implement` owns the merge step.
6. **T21 AC4's lint-stage list** omitting `lint:shellcheck`, `lint:hooks-shell`, `lint:vocabulary`, `lint:file-type-ban`, `lint:pattern-library-contract` -- AC4 is non-exhaustive ("runs X, Y and Z"), and each added job has its own owning AC (T30 AC11, T56, T57 AC10) or is a ledger-tracked remediation. Not falsified.
7. **`EDM_EVAL_PHASE_TIMEOUT_SECONDS` absent from `CLAUDE.md:988-999`'s enumerated `EDM_EVAL_*` family** (which lists only `EDM_EVAL_KEEP_RUNS`) -- documented at its owning component (`evals/README.md`) and validated at startup by the CA-444 fix. Marginal; filter 2 applies. Recorded so a future round does not re-derive it. Same for `EDM_STATE_LOCK_WAIT_S`, which is documented at its definition site and pinned by `wave6-smoke.sh:840-856`.
8. **CA-423** -- not re-filed. Human override D58 records `--accept-p2-debt` as a sanctioned feature with ticket EDMV3-T68. Finding **#2** in the stale-spec table concerns only the unamended `srd.md` text, not the authorization.
9. **CA-106 / CA-108 / CA-109 / CA-110 / CA-125 / CA-132 / CA-174 / CA-175 / CA-376 / CA-377** -- all re-checked against the current tree, all dispositions still hold, none re-filed. CA-106's closing path is now degraded by the sixth dimension; that is captured inside the T23 finding rather than re-filed against CA-106.

---

