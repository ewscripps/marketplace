# Code Audit Pass 3 -- Lens L9: Spec & Ticket Compliance

**Initiative**: EDMV3 -- prompt-streamline
**Round**: 3 (2026-08-08)
**Scope**: `plugins/edm/**` cross-referenced against `srd.md`, `tickets/README.md`, `tickets/epics/01..11`, `decisions.md`, `architecture.md`
**Inputs read**: `srd.md` (targeted sections: EDMV3-52 `:2734-2764`, EDMV3-54 `:2809-2866`, EDMV3-97 `:4059-4083`, EDMV3-07/113 `:744-772`, EDMV3-13 `:998-1007`), `tickets/README.md` in full (814 lines), all eleven epic files, `decisions.md` in full (D1-D35 + Finding-to-Commit ledger), `code-audit/findings-ledger.md` in full (195 lines)
**Tool limitation**: no `Bash` and no `Write`. All verification is `Read`/`Grep`-based. Two claims are explicitly hedged below where a shell would have been needed.

---

## Verdict summary

| Ledger entry | Lens(es) | Ledger status | Round-3 verdict |
|---|---|---|---|
| CA-013 | L9+L11 | open | **L9 half now consistent** -- recommend fixed; one new residual (F1) |
| CA-034 | L9 | open | **Now consistent** -- recommend fixed; cosmetic residue only |
| CA-089 | L9 | open | **Partially closed** -- ticket-pack and SRD halves verified against code; `architecture.md` residue remains |
| CA-127 | L6+L9 | open | **Now consistent** -- recommend fixed |
| CA-163 | L9 | open | **Half closed** -- D19 half verified closed; D23/T23 half still absent |

Fresh findings this round: 3 P1, 7 P2. No scope creep.

---

## Part 1 -- Cross-round ledger: every open L9 entry

### CA-013 (P1, L9+L11) -- NOW CONSISTENT on the L9 half

**Spec side.** `srd.md:2846-2852` (EDMV3-54) now reads: "Every reference uses one of two accepted forms: the identical quoting style already in use, `` `CLAUDE.md Sec."Mermaid diagram conventions"` ``, **or** the plugin-relative fallback, `` `docs/canonical-sections.md` `` ... the two forms are equivalent because the latter is a generated, byte-identical extract of the former (EDMV3-T41 AC4/AC5)." `srd.md:2853-2856` replaced the disproven "verified to resolve from an installed plugin cache" criterion with "disproven by two independent methods and not re-asserted here." `plugins/edm/CLAUDE.md` Sec."By-name reference resolution" now states "**Current position (decisions.md D34): the negative branch is now the shipped default, not a future one**" and names `EDMV4-T04` for the residual scope -- the "gated on T42 landing" prose is gone.

**Code side.** `docs/canonical-sections.md` now has 13 prompt-surface consumers under `agents/`: all eleven `plugins/edm/agents/edm-audit-*.md`, plus `agents/edm-audit-synthesizer.md` and `agents/edm-srd-auditor.md`. The "zero prompt-surface consumers" half of CA-013 is closed.

**Verdict: CONSISTENT.** Recommend flipping CA-013's L9 half to fixed. One new residual is raised separately as **F1**.

---

### CA-034 (P2, L9) -- NOW CONSISTENT

All three cited lines now state both sanctioned auth paths:
- `plugins/edm/evals/baseline/README.md:9-12`: "through one of its two sanctioned auth paths (D20; `epics/03-ci-and-fixture-eval.md` AC8; `run-eval.sh:24-27,:37-39,:181-183`) -- an exported `ANTHROPIC_API_KEY`, or a `claude` CLI that is already authenticated via subscription/OAuth login"
- `:26-28`: "with working Claude auth in place -- either export a real `ANTHROPIC_API_KEY` or use a machine where the `claude` CLI is already logged in (subscription/OAuth)"
- `:32-35`: the capture block now carries "Auth path 1" / "Auth path 2 (alternative to the export above)"

Spec side: `epics/03:400-406` (T22 AC8) matches -- "Either an exported `ANTHROPIC_API_KEY` or an already authenticated `claude` CLI session satisfies the contract."

**Verdict: CONSISTENT.** Recommend fixed. Residue (not actionable, see Noted): `baseline/README.md:147-149`'s cost note still frames ownership as "whoever owns the `ANTHROPIC_API_KEY` used for wave-A exit", which excludes the CLI path -- but it is a cost-ownership sentence, not the auth contract, and none of CA-034's three cited lines survives.

---

### CA-089 (P2, L9) -- PARTIALLY CLOSED

**The T39 AC7 amendment is correct and matches the shipped code exactly. Verified on both sides.**

Spec side (`epics/05-orchestrator-dispatcher.md:605-617`):
> AC7 (tripwire shipped regardless of GO/NO-GO, amended per CA-089) ... It asserts the inverse of the original wording: the dispatcher (`skills/orchestrator/SKILL.md`) contains **no** phase procedure body (no phase skill's `## Operational Orchestration` marker appears in it), and every phase skill still owns its own `## Operational Orchestration` section. `run-all.sh` runs it unconditionally, as part of the smoke suite, on every invocation -- not only on a comparison failure.
> Verify: `bash plugins/edm/bin/edm-check-skill-sync; echo "exit=$?"` prints `exit=0` on the current (deduplicated) tree; pasting a phase skill's `## Operational Orchestration` section body back into `skills/orchestrator/SKILL.md`, or deleting that section from any phase skill, makes it exit 1 and name the specific violation.

Code side (`plugins/edm/bin/edm-check-skill-sync`):
- `:47` -- `PROCEDURE_MARKER='## Operational Orchestration'` -- the exact marker the AC now names.
- `:51-54` -- flags the marker's **presence** in `$ORCH`, incrementing `violations`. Matches "contains no phase procedure body".
- `:58-65` -- iterates `plan srd audit-srd tickets audit-tickets implement code-audit verify-runtime` and flags the marker's **absence** from each. Matches "every phase skill still owns its own".
- `:67-73` -- exit 0 with a `CLEAN` line, else a per-violation stderr message plus `exit 1`. Matches "exit 1 and name the specific violation". `:22` documents `0 clean, 1 duplication found, 2 usage or environment error` -- so the AC's "exits the script does not have" complaint from round 2 is resolved.
- Precondition holds on the live tree: `^## Operational Orchestration` appears in 13 `skills/*/SKILL.md` files, and `skills/orchestrator/SKILL.md` is **not** one of them. All eight skills the loop checks carry it: `plan:47`, `srd:23`, `audit-srd:27`, `tickets:25`, `audit-tickets:25`, `implement:23`, `code-audit:33`, `verify-runtime:42`. So the verify command's `exit=0` claim is true today.
- `plugins/edm/bin/tests/run-all.sh:177-178` invokes it via `_standalone_check` with no conditional -- matching "runs it unconditionally".

Also closed: `epics/05:101-104` (T34 Out of Scope) now carries the CA-089 amendment rather than forbidding the script; `epics/05:638-642` (T39 Technical Notes) records the rework explicitly; `srd.md:2755-2759` sanctions the shipped tripwire.

**Residue that keeps CA-089 open (2 sites, both in the SRD's companion document of record):**
- `architecture.md:647` -- "the fallback is the reviewed alternative -- a `bin/edm-check-skill-sync` script asserting the duplicated blocks stay identical" -- the inverse of `edm-check-skill-sync:47-65`.
- `architecture.md:873` -- "`bin/edm-check-skill-sync` (assert the duplicated blocks stay identical) instead of the dispatcher | ... Retained only as the documented fallback if the WS3 eval shows the refactor regresses" -- both halves now false: the assertion is inverted, and retention is unconditional (`run-all.sh:177-178`), not conditional on an eval regression that never ran (D23).
- `architecture.md` is named as a companion document of record at `tickets/README.md:11`, so it is in L9's scope.

**Third residue (P2, script-side):** `plugins/edm/bin/edm-check-skill-sync:3` still titles itself "the EDMV3-T39 AC7 **fallback** tripwire" and `:10-13` gives as reason (1) "**AC7 requires the fallback to exist and be runnable**" -- a requirement the amended AC7 no longer states. The header now cites a version of its own AC that has been superseded.

**Verdict: PARTIALLY CLOSED.** Keep CA-089 open scoped to `architecture.md:647`, `architecture.md:873`, and `edm-check-skill-sync:3,10-13`. The epics/05 and srd.md halves are verified done.

---

### CA-127 (P2, L6+L9) -- NOW CONSISTENT

- Repository-root `CLAUDE.md:54`: "**edm** (v3.1.0) -- ... `/edm:code-audit`, `/edm:test`, `/edm:test-plan`, `/edm:test-coverage`, `/edm:verify-runtime`, `/edm:push-jira`, and `/edm:metrics`"
- `.claude-plugin/marketplace.json:35`: `"version": "3.1.0"`; `:45`: `"./skills/verify-runtime"`

Both sides agree on version and on the skill's registration. **Verdict: CONSISTENT.** Recommend fixed.

---

### CA-163 (P2, L9) -- HALF CLOSED

#### The D19 half is CLOSED. Verified on both sides, AC by AC.

`decisions.md:23` (D19, "**Extended 2026-08-08 per CA-163**") now names six ACs. I checked every claimed "after" against the shipped ticket text:

| AC | decisions.md claimed "after" | Shipped text | Match |
|---|---|---|---|
| T61 AC13 | assert via `run-all.sh` auto-discovery | `epics/11:152-153` -- "AC13 (CI): the help-completeness test runs in CI. Verify: `grep -n 'run-all.sh' .gitlab-ci.yml`." | yes |
| T01 AC9 | assert via `run-all.sh` auto-discovery | `epics/01:85-88` -- "Verify: `grep -n 'run-all.sh' .gitlab-ci.yml plugins/edm/bin/tests/run-all.sh` returns a hit in each file" | yes |
| T16 AC10 | "Verify: `grep -n 'run-all.sh' .gitlab-ci.yml plugins/edm/bin/tests/run-all.sh`" | `epics/02:1253-1254` -- byte-identical | yes |
| T42 AC12 | "Verify: `grep -n 'run-all.sh' .gitlab-ci.yml`" | `epics/06:278-279` -- byte-identical | yes |
| T44 AC6 | "Verify: `grep -n 'run-all.sh' .gitlab-ci.yml`" | `epics/06:480-481` -- byte-identical | yes |
| T56 AC6 | "`grep -n 'four-heading\|contract check' ... wave7-smoke.sh` ... and `grep -n 'run-all.sh' .gitlab-ci.yml`" | `epics/09:290-294` -- byte-identical | yes |

And the "after" forms actually pass on the current tree: `.gitlab-ci.yml` contains `run-all.sh` at `:313`, `:327`, `:329-330`, `:366`; and a search for `wave(3|4a|4b|5|6|7)-smoke` in `.gitlab-ci.yml` returns **zero** occurrences, so T21 AC5's invariant (which D19 ruled the winner) genuinely holds.

**Before/after completeness -- partial.** The task asked me to confirm every AC D19 now claims went through gate change control is "named with before/after text". All six are **named**. Four carry an explicit `before -- ...; after -- ...` pair. But the "before" is a **paraphrase rather than the replaced text** in four of six cases:
- T42 AC12: before given as "a literal suite-file pointer naming the Mermaid rule-presence test's specific suite"
- T44 AC6: before given as "a literal suite-file pointer naming the fixture-corpus test's specific suite"
- T56 AC6: before given as "a literal suite-file pointer for the four-heading contract test"
- T16 AC10: before quoted as `` grep -n '<wave-N>-smoke' .gitlab-ci.yml `` -- a template with a `<wave-N>` placeholder standing in for the actual literal token
- T61 AC13 / T01 AC9: before/after described in prose only, though the literal tokens (`wave7-smoke`, `wave6-smoke`) are named

Consequence: a reader cannot reconstruct what was changed for four of six, so the record documents *that* a rework happened but not *what* was replaced. Recorded here rather than raised as a separate finding, because D19 does discharge `tickets/README.md:64-65`'s "reworked ... through gate change control, never recorded as accepted" obligation for all six, and `plugins/edm/CLAUDE.md`'s before/after convention is scoped by its own text to "prompt text in this plugin -- any `SKILL.md`, any `agents/*.md`, this file", not to ticket ACs.

#### The D23 / T23 half is NOT CLOSED.

CA-163's second clause: "**D23 still never names T23 though AC13 was rewritten**."

- **Spec side, code-search evidence**: a search for `T23` / `EDMV3-T23` over `SRD/edm/EDMV3__prompt-streamline/decisions.md` returns **zero matches**. `decisions.md:29` (D23) enumerates what shipped for T39 AC2/AC3/AC4/AC7 and what is open (AC1 and the baseline), and gives a closing command -- but never names T23, its AC13, or the temporal clause that was removed. No new decision entry (D33/D34/D35 are CA-182, CA-013 and CA-183 respectively) names it either.
- **The rework demonstrably happened**: `epics/03-ci-and-fixture-eval.md:569-574` now reads "AC13 (**verifiable today**): the committed baseline artifact records the wave-A fixture/scorer it was captured from and the variance table that EDMV3-T39 consumes, **so later tickets can verify provenance from the artifact itself instead of from a no-longer-live chronology claim**." The "captured before the first wave-B commit" precondition that CA-091 named is gone. That is a D15-class AC rework, and `tickets/README.md:64-65` plus `plugins/edm/CLAUDE.md` Sec."Unverifiable acceptance criteria (D15)" both require it "recorded in `decisions.md` and the ticket's audit trail."

**Verdict: HALF CLOSED.** Keep CA-163 open, narrowed to: no `decisions.md` entry records the T23 AC13 rework. See also **F9**, which is the substantive consequence.

---

## Part 2 -- Fresh findings

### Missing / partial implementations (P1)

| # | Ticket / AC | What the spec requires | What the code does | Evidence |
|---|---|---|---|---|
| **F2** | T37 AC6 | "`edm-state phase-start` and `phase-complete` calls exist **exactly once per phase** across the whole plugin. Verify: `grep -rc 'phase-start' plugins/edm/skills/*/SKILL.md` **sums to 8** (one per phase skill) and ... (case \"one phase-start per phase\")" | Sums to **7**, not 8, and the distribution is per-*phase* not per-*skill*. `code-audit` and `verify-runtime` carry no `phase-start` at all; `tickets` carries two. The shipped smoke test implements a different contract (one owning *file* per phase, with `phase-complete 6` expected in **three** files) and records the exceptions only in its own echo string. The AC's cited case name is not the shipped label. | Spec: `SRD/.../tickets/epics/05-orchestrator-dispatcher.md:358-361`. Code: `plugins/edm/skills/srd/SKILL.md:28`, `implement/SKILL.md:26`, `plan/SKILL.md:63`, `audit-srd/SKILL.md:30`, `audit-tickets/SKILL.md:28`, `tickets/SKILL.md:33` **and** `tickets/SKILL.md:145` = 7. Test: `plugins/edm/bin/tests/wave7-smoke.sh:2830-2843` (echo names "fast-track's mode-branch duplicate inside skills/tickets, and orchestrator+verify-runtime's documented phase-complete-6 split ... re-baselined to 3 files by EDMV3-T50"). Contrast `epics/08-economics-honesty.md:72-87` (T50 AC4), which *does* carry a "Note -- why the obvious command does not work" block for the same three-file split. No `decisions.md` entry records a T37 AC6 rework. |
| **F3** | T39 AC5 | "the driver's stop-before-gate instruction is re-verified against the wave-B PROTOCOL wording from EDMV3-T35, and any change to driver behaviour is recorded ... Verify: the ticket records the re-verification result, and `grep -n 'stop before gate presentation' plugins/edm/evals/run-eval.sh` matches the final PROTOCOL's terminology." | The literal phrase appears **nowhere** in `run-eval.sh` -- a case-insensitive search for `stop.{0,20}gate`, `gate presentation`, `STOP_BEFORE` and `stop-before` over the file returns zero hits. The substance exists under a third wording. And no record of the re-verification exists: `CHANGELOG.md` contains **no** `EDMV3-T39` entry, and `decisions.md:29` (D23) enumerates AC2/AC3/AC4/AC7 but never AC5. So both halves of AC5's verify fail. | Spec: `epics/05:593-599`; `srd.md:2746-2750`. Code: `plugins/edm/evals/run-eval.sh:350-352` ("Do NOT perform the HITL Gate 1 presentation (no ... approve-gate yourself -- the eval driver pre-seeds that approval once this invocation ends") and `:415-417` ("Do NOT perform step 9 (the HITL Gate 2 ...) ... call edm-state approve-gate yourself"). Final PROTOCOL: `plugins/edm/skills/orchestrator/SKILL.md:130` ("**STOP and WAIT for the `AskUserQuestion` response.**"). Three different wordings, none of them the AC's. |
| **F4** | T39 AC9 | "the nightly `scores.json` files remain named or tagged such that a simple script can plot total score over time ... Verify: `ls plugins/edm/evals/runs/` shows timestamp-and-SHA names and **the plotting script described in `evals/README.md` runs against them**." | Half implemented. The naming convention exists and is documented (`evals/README.md:33` -- `plugins/edm/evals/runs/<timestamp>_<git-sha>/`). The plotting script **does not exist and is described nowhere**: a case-insensitive search for `plot` across all of `plugins/edm/` returns zero matches, so `evals/README.md` describes no such script. `plugins/edm/evals/runs/` also holds no committed run directories, so the first half of the verify is unrunnable in a clean checkout. No ticket names a plotting script. | Spec: `epics/05:622-625`; the same clause originates at `epics/03:559-564` (T23 AC11, "named or tagged so a simple script can plot total score over time" -- which stops short of requiring the script). Code: zero `plot` occurrences under `plugins/edm/`. |

### Partial implementations and drifted verify commands (P2)

| # | Ticket / AC | What the spec says | Current tree | Evidence |
|---|---|---|---|---|
| **F1** | srd.md EDMV3-54 AC (D34's amendment) | `:2853-2856` -- "Consumers cite the plugin-relative form (decisions.md D22, D34) ... `docs/canonical-sections.md` is the resolvable fallback and is what new prompt-surface references point at." | Of the **nine prompt-surface touch points EDMV3-54's own canonical table enumerates** (`srd.md:2819-2831`: `agents/edm-architect.md`, `edm-srd-writer.md`, `edm-ticket-writer.md`, `edm-srd-auditor.md`, `edm-ticket-auditor.md`, `skills/srd`, `skills/tickets`, `skills/audit-srd`, `skills/audit-tickets`), exactly **one** -- `agents/edm-srd-auditor.md` -- carries the `docs/canonical-sections.md` anchor. Zero `skills/*/SKILL.md` carry it. D34 added the anchor to the eleven `edm-audit-*` lenses and the synthesizer, which are **not** among EDMV3-54's touch points at all. `plugins/edm/CLAUDE.md`'s "that ordering gap is now closed" is therefore true of the lens set and not of the touch-point set D22 identified as already shipped against a confirmed-broken mechanism. Compounding: `:2846-2852` declares both forms equivalent and accepted, while `:2853-2856` reads as a requirement to use the plugin-relative one -- two adjacent criteria in tension. | Spec: `srd.md:2819-2831`, `:2846-2856`; `decisions.md:28` (D22's "Handoff, urgent, not yet done" names "those nine prompt-surface files"); `decisions.md:43` (D34). Code: `docs/canonical-sections.md` consumers are `agents/edm-audit-{wiring,test-quality,spec,security,runtime,logic,edge-cases,dry,docs,dead-code,consistency}.md`, `agents/edm-srd-auditor.md`, `agents/edm-audit-synthesizer.md`, plus `bin/edm-sync-canonical-sections`, `bin/tests/wave6-smoke.sh`, `CLAUDE.md`, `CHANGELOG.md`, `bin/vocabulary-allowlist.txt`. |
| **F5** | T38 AC12 | "Verify: `grep -rl 'phases.json' plugins/edm/ \| wc -l` **prints 0**." | Prints **1**. `phases.json` occurs in one file -- `plugins/edm/bin/tests/wave7-smoke.sh:2941-2944`, the negative test itself, whose own pass label says "(excluding this negative-test carve-out in `bin/tests/`)". The test carves `bin/tests/` out; the AC text never did. The pack has an established convention for exactly this, unapplied here: `epics/02:553-556` (T09 AC13) explicitly writes the `bin/tests/` carve-out into the AC. | Spec: `epics/05:494-499`. Code: `plugins/edm/bin/tests/wave7-smoke.sh:2941-2944`. |
| **F6** | T35 AC4 | "Verify: `grep -rn 'free-text is never approval\|free text is not an approval' plugins/edm/ \| grep -v 'orchestrator/SKILL.md'` **returns zero results**." | Returns **two** results -- both inside the smoke file that implements the assertion. `wave7-smoke.sh:2584` carries the phrase inside an `echo`, and `:2585` carries both alternation branches inside the grep pattern itself; neither line is under `orchestrator/SKILL.md`, so `grep -v` keeps both. The shipped assertion runs the identical grep over `${PLUGIN_DIR}/` (`= plugins/edm`, per `wave7-smoke.sh:12`) with no `bin/tests/` carve-out, so on a plain reading `:2586`'s `[[ -z "$t35_freetext_hits" ]]` is false and the case fails. **Hedged**: I could not execute the suite (no `Bash`), so I report the AC's stated command as demonstrably non-zero and flag the possible red assertion for L4 cross-check rather than asserting a failing suite. | Spec: `epics/05:152-156`. Code: `plugins/edm/bin/tests/wave7-smoke.sh:2584-2587`, `:12`. |
| **F7** | T38 AC6 | "Verify: `grep -c 'mini-srd' plugins/edm/skills/orchestrator/SKILL.md` returns **only the routing row**." | Returns **0**. The orchestrator writes the display form `mini-SRD` (`:107` in the Step 1c option list, `:158` in the Phase 3 entry); the enum-cased `mini-srd` survives only in `plugins/edm/CLAUDE.md`'s mode matrix, which is where AC6 sent it. The AC's *substance* is satisfied -- the sub-flows and matrix did move out -- but its stated command returns 0 where the AC expects 1, so a reader running it concludes the routing row is missing. | Spec: `epics/05:460-466`. Code: `plugins/edm/skills/orchestrator/SKILL.md:107`, `:158`; zero case-sensitive `mini-srd` in that file. |
| **F8** | T38 AC8 | "the post-restructure `current_step` vocabulary is defined, a mapping from the 2.x values ... is published ... **The mapping is recorded in `CHANGELOG.md`.** Verify: ... and `grep -n 'current_step' plugins/edm/CHANGELOG.md`." | The grep returns hits, but what it finds is a **superseded placeholder that says the opposite**: `CHANGELOG.md:282-288` -- "**`current_step` vocabulary migration (EDMV3-T38): tracked, not yet landed as of this entry.** ... EDMV3-T38 had not landed on `edm/edmv3-prompt-streamline` as of this changelog entry; its published mapping supersedes this paragraph once it does." T38 has landed (the orchestrator is 204 lines, dispatches via the `Skill` tool, and publishes the vocabulary and legacy tolerance at `:177-183`). The two documents now contradict each other in both directions: `orchestrator/SKILL.md:180-181` asserts the legacy-value tolerance is "(recorded in `CHANGELOG.md`)", which is false as written. | Spec: `epics/05:471-477`. Code: `plugins/edm/CHANGELOG.md:282-288`; `plugins/edm/skills/orchestrator/SKILL.md:177-183`. |
| **F9** | T23 AC13 | `epics/03:569-574`, labelled "AC13 (**verifiable today**)". Verify has two halves: a grep over `baseline/README.md`, and `jq -e '(.dimensions_scored == 4) and (.complete == true)' plugins/edm/evals/baseline/scores.json`. | The grep half passes (`baseline/README.md`: `wave-A` at `:55`/`:58`/`:81`, `variance` at `:66`/`:89`/`:93`, `dimensions_scored` at `:58-63`). The `jq` half **cannot run**: `plugins/edm/evals/baseline/` contains only `README.md` -- `scores.json` does not exist. The rework therefore substituted one unverifiable precondition (a no-longer-live chronology) for another (an absent artifact), while renaming the AC "verifiable today". The absent baseline itself is documented (ledger CA-106, `decisions.md` D23), so the finding is the label plus the missing change-control record -- the substantive consequence of CA-163's open D23 half. | Spec: `epics/03:569-574`; ledger CA-106 (Decisions/Non-Findings item 2). Code: directory listing of `plugins/edm/evals/baseline/` = `README.md` only. |
| **F10** | EDMV3-97 / T66 | `srd.md:4059-4064` -- "`CLAUDE.md` reference tables match reality ... A stale reference table is worse than none, because it is cited by name from agent prompts at runtime." T66 Target Components (`epics/11:618`) names "`plugins/edm/CLAUDE.md` (**`bin/` table**, state-field table, Hooks behavior table, ...)". | The `bin/` helper-scripts table in `plugins/edm/CLAUDE.md` lists **five of the nine** shipped scripts: `edm-state`, `edm-init`, `edm-validate-prefix`, `edm-lint-artifacts`, `edm-sync-canonical-sections`. Omitted: `edm-check-grants` (T03), `edm-check-vocabulary` (T30), `edm-compare-eval` (T39), `edm-check-skill-sync` (T39). No AC covers the script list -- T66 AC3 (`epics/11:641-653`) constrains only the *subcommand* count and enumeration (40, which does match the stated figure), and AC4 the linter/hook/mode rows. `CLAUDE.md`'s own intent-to-file index calls this table "the index of `bin/`", so a table missing four of nine entries is the exact "stale reference table cited by name from agent prompts" the requirement was written against, with no AC to catch it. | Spec: `srd.md:4059-4083`; `epics/11:607-618`, `:641-653`, `:654-665`. Code: `plugins/edm/bin/` contains `edm-state`, `edm-init`, `edm-validate-prefix`, `edm-lint-artifacts`, `edm-sync-canonical-sections`, `edm-check-grants`, `edm-check-skill-sync`, `edm-check-vocabulary`, `edm-compare-eval` (plus `_edm-cli-lib.sh`, `_edm-lint-lib.sh`, `edm-mermaid-rules.awk`, two vocabulary text files). |
| **F11** | Cross-cutting AC (`tickets/README.md:94`), EDMV3-98 via T65 | "Changelog entry written if initiative has a CHANGELOG" -- applies when the ticket changes user-visible behavior or public API. EDMV3-98 requires the changelog correct at every wave boundary. | `CHANGELOG.md` carries entries naming `EDMV3-T30`, `-T31`, `-T32`, `-T33`, `-T34`, `-T35`, `-T36`, `-T38` -- but **no `EDMV3-T37` and no `EDMV3-T39`**. T39 shipped two new user-facing `bin/` scripts and a CI comparison job; a search for `edm-compare-eval` over `CHANGELOG.md` returns nothing. T37's content is arguably absorbed by T38's "Skill-tool composition/dispatcher restructure" entries at `:256` and `:263` (the two ship in one MR per the `Ships-with` pair), which is why this is P2 rather than P1; T39's is not covered anywhere. | Spec: `tickets/README.md:94`, `:750-752`; `epics/11:495-590` (T65). Code: `plugins/edm/CHANGELOG.md` -- `EDMV3-T3[0-9]` occurrences at `:16`, `:260`, `:264`, `:274`, `:282-285`, `:311`, `:320`, `:430`, `:440`, `:447`, `:456`, `:461`, `:465`, `:470`, `:515`, `:518`. |

---

## Part 3 -- Scope creep (P2)

**None found this round.** Both candidates from earlier rounds are now properly sanctioned and are explicitly not reported:

- `bin/edm-check-skill-sync` -- round 1's scope-creep item. Now sanctioned by `srd.md:2755-2759`, by the amended `epics/05:605-617` (T39 AC7) and by `epics/05:101-104`. It is specified work, not creep. (The residual defects in its *description* are folded into CA-089 above.)
- `bin/_edm-lint-lib.sh` -- already ruled not-creep as ledger item CA-175 (T30 AC9 at `epics/04:781-784` sanctions the extraction; round-1 REMEDIATION CA-050 prescribed it). Not re-investigated.
- `bin/_edm-cli-lib.sh` (sourced at `edm-check-skill-sync:31`) has no ticket of its own, but it is the shared `print_help` extractor that round-1 finding CA-005 prescribed be created in place of eleven hand-copies. Necessary implementation detail of an existing remediation, not creep. Recorded in Noted.

---

## Noted / Not Actionable

1. **Stale `path:line` anchors in `Target Components` across all eleven epics** (e.g. `epics/05:412`'s "645 lines today" against the shipped 204; `epics/05:119`'s `:395-402`; `epics/05:217`'s `bin/edm-state:1194-1237`) -- `tickets/README.md:57` states the convention explicitly: "Verified `path:line` anchors as of 2026-07-25. The **symbol name is the authoritative anchor**; line numbers drift as the initiative executes." Documented as intentional.
2. **CA-106, CA-108, CA-109, CA-110, CA-125, CA-132, CA-174, CA-175** -- all eight are L9-tagged items already in the ledger's "Decisions / Non-Findings" block, which instructs future audits not to re-investigate. Not re-opened. F9 is *adjacent* to CA-106 but is a different claim (an AC label and a missing change-control record, not the missing baseline).
3. **`baseline/README.md:147-149`'s `ANTHROPIC_API_KEY`-only cost-ownership phrasing** -- residue of CA-034, but it is a cost-ownership sentence rather than the auth contract, and all three lines CA-034 cited are fixed.
4. **T36 AC7's `grep -c 'skipped_phases' plugins/edm/skills/*/SKILL.md` "returns 0 for all eight"** -- 0 occurrences confirmed, so the substance holds; `grep -c` prints 0 and exits 1, which is the same shell gotcha `epics/05:75-77` (T34 AC7) documents in place. Consistent project pattern.
5. **T39 AC2's `grep -n 'baseline_total' .gitlab-ci.yml`** -- hits at `.gitlab-ci.yml:608` (a comment naming the field and its source) and `:617` (the success echo). The threshold expression itself lives in `bin/edm-compare-eval`, invoked by the job at `:615`. AC2's substance -- "compared ... **by the CI job**, not by the scorer" -- holds, and the AC does not require the arithmetic to be inline. Not a finding.
6. **T38 AC2's "mode dispatch (table and routing)" vs AC6's "the mode matrix itself [moves] to `CLAUDE.md`"** -- reads as an internal tension, but AC6 resolves it explicitly (routing stays, matrix moves) and the shipped orchestrator does exactly that (`:103-114` routing; `:113-114` by-name reference to `CLAUDE.md Sec."EDM mode matrix"`). Documented as intentional.
7. **`bin/_edm-cli-lib.sh` has no ticket** -- it is the shared help extractor round-1 finding CA-005 prescribed; necessary implementation detail of a tracked remediation.
8. **T34 AC7 verified passing**: `grep -rl 'each contain their own orchestration' plugins/edm/ | wc -l` returns 0 -- zero occurrences of the phrase anywhere under `plugins/edm/`. **T35 AC1 verified passing**: `## Gate PROTOCOL (canonical)` appears exactly once, at `orchestrator/SKILL.md:123`. **T38 AC1 verified passing**: the orchestrator is 204 lines (cap 300). **T38 AC13 verified passing**: `verify-runtime` appears in the Phase 6 entry at `orchestrator/SKILL.md:169`. **T36 AC1/AC5 verified passing**: all eight phase skills carry a `Step 0`/`branch-check` reference, with `plan/SKILL.md` holding the full text (5 occurrences) and the other seven a by-name reference (2 each). **T35 AC7 verified passing**: "remediation gate" at `code-audit/SKILL.md:135`, `:137`, `:309`. Recorded so a later round does not re-derive them.

---

## Recommended ledger actions

| Finding | Action |
|---|---|
| CA-013 | Flip L9 half to fixed; raise **F1** as its successor |
| CA-034 | Flip to fixed |
| CA-089 | Keep open, re-scope to `architecture.md:647`, `architecture.md:873`, `bin/edm-check-skill-sync:3,10-13` |
| CA-127 | Flip to fixed (tree now consistent; ledger status stale) |
| CA-163 | Keep open, re-scope to the D23/T23 half only |
| F2, F3, F4 | New P1 entries |
| F1, F5, F6, F7, F8, F9, F10, F11 | New P2 entries |
| F6 | Additionally flag to L4 -- possible currently-failing `wave7-smoke.sh` assertion at `:2586` (unconfirmed without a shell) |

---

**Files most load-bearing for this report** (all absolute):
- `/Users/darryl.porter/projects/marketplace/SRD/edm/EDMV3__prompt-streamline/tickets/epics/05-orchestrator-dispatcher.md`
- `/Users/darryl.porter/projects/marketplace/SRD/edm/EDMV3__prompt-streamline/decisions.md`
- `/Users/darryl.porter/projects/marketplace/SRD/edm/EDMV3__prompt-streamline/architecture.md`
- `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-check-skill-sync`
- `/Users/darryl.porter/projects/marketplace/plugins/edm/skills/orchestrator/SKILL.md`
- `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/wave7-smoke.sh`
- `/Users/darryl.porter/projects/marketplace/plugins/edm/CHANGELOG.md`
- `/Users/darryl.porter/projects/marketplace/plugins/edm/CLAUDE.md`
- `/Users/darryl.porter/projects/marketplace/plugins/edm/evals/run-eval.sh`
- `/Users/darryl.porter/projects/marketplace/plugins/edm/evals/baseline/README.md`
