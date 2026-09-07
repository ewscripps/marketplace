# QC Audit Report: EDMV4 Phase 6 Wave 1 [Shard 1/3]

**Date**: 2026-09-02
**Tickets audited**: EDMV4-T01, EDMV4-T04, EDMV4-T05, EDMV4-T06 (4 of 4 assigned)
**Tree audited**: `edm/edmv4-ecc-integration` @ `c936e4f` (working tree carries uncommitted
sibling-agent edits to `plugins/edm/bin/tests/wave6-smoke.sh` and
`plugins/edm/docs/canonical-sections.md`; both are called out where they bear on a verdict)
**Implementation mode**: `standard` -- the TDD compliance pass does not run.

## Summary

| Ticket | Title | Verdict |
|---|---|---|
| EDMV4-T01 | Re-derive the Mermaid lint budget as an absolute ceiling plus a sized ratio | FAIL |
| EDMV4-T04 | Anchor all 14 by-name reference files, after enumerating and resolving every orphan | FAIL |
| EDMV4-T05 | Verify the CA-532 and CA-490 fixes and record the eval-baseline scope boundary | FAIL |
| EDMV4-T06 | Run Spike A and record multi-hook-per-event combination semantics | PARTIAL |

Three FAILs, all narrow and individually remediable; one PARTIAL ticket (a live-host spike whose
experiment cannot be re-executed from the tree). No P0-class functional breakage was found in
T01 or T05. T04 carries the one wholly unmet acceptance criterion in this shard.

---

## EDMV4-T01: Mermaid lint budget -- FAIL (11 PASS / 1 FAIL)

- [x] AC1 -- `plugins/edm/CLAUDE.md:951` restates the budget as a conditional (absolute
      `<= 1,000 ms` added overhead below the floor, `<= 1.40x` ratio at or above it) and quotes
      the floor in **both** units: "30 `.md` files / 9,990 lines". No bare ratio survives.
- [x] AC2 -- `plugins/edm/CLAUDE.md:959` ("Why the Mermaid row is a conditional, not a single
      number") states the floor numerically and names fixed bash/awk fork-exec overhead as the
      reason the ratio does not bind below it.
- [x] AC3 -- the Mermaid row at `CLAUDE.md:951` uses the same five-column shape as the two
      existing rows (`Budget | Invocation | Ceiling | Fixture ... | Where it binds`).
- [x] AC4 -- option **(b)** taken and recorded: `plugins/edm/CHANGELOG.md:11-25` and
      `timing.sh:411-415` both state the budget is against `--mermaid-ratio`'s own
      30-file / 9,990-line single-initiative fixture and explain why the 50-initiative framing was
      dropped (the mode ignores `--dir`). `srd.md:3684` Sec.9.1's fixture cell already reads
      "`--mermaid-ratio`'s own fixture: 30 files / 9,990 lines, a single scratch initiative,
      20-sample nearest-rank p95", so it matches the chosen option with no correction needed.
- [x] AC5 -- `grep -n 'budget: <= 1.40x' plugins/edm/bin/tests/timing.sh` returns nothing
      (exit 1). The conditional emitter is at `timing.sh:440-444`.
- [x] AC6 -- the UNMEASURABLE refusal is preserved unchanged: `git log -L 419,431` shows its last
      modification was `9cba6c4`, well before this initiative, and the block sits intact at
      `timing.sh:427-431`. Exercised live: with a zero-resolution `perl` shim on `PATH`,
      `timing.sh --mermaid-ratio --files 1 --lines-per-file 1` printed
      `ratio=UNMEASURABLE ...` and exited **3**.
- [x] AC7 -- re-measurement recorded with its fixture size at `CHANGELOG.md:22-25` (median 1.21x
      across three 20-sample runs: 1.10x / 1.21x / 1.25x, against 30 files / 9,990 lines).
      Independently reproduced during this audit:
      `ratio=1.28x delta_ms=715 fixture=30files/9990lines (at/above the 30-file/9,990-line floor:
      ratio budget <= 1.40x binds)` -- consistent with the recorded range and inside the ceiling.
- [x] AC8 -- `timing.sh:112` `readonly _P95_SAMPLE_COUNT=20`, consumed by both `--mermaid-ratio`
      measurements at `:416` and `:422`; `--self-test` pins the constant and the nearest-rank
      index (`self-test PASS: _p95 of 20 samples ... returns the 19th order statistic`).
- [ ] AC9 -- **FAIL**. The currency question is answered (`CLAUDE.md:975`: the 1.12x figure
      "should be treated as superseded rather than still current"; `CHANGELOG.md:23` attributes
      the delta to host/run variance and states `bin/edm-lint-artifacts` is untouched), but the
      AC requires that statement to be made **with respect to the D4 `plugin.json` reconciliation
      (`EDMV4-03`)** as well as this initiative's own changes. `grep -n 'EDMV4-03'` and
      `grep -n 'plugin.json reconciliation'` return nothing in either `CLAUDE.md` or
      `CHANGELOG.md`, so that half is left implicit -- the exact thing the AC forbids.
- [x] AC10 -- the figure is recorded under a **new** `[Unreleased]` entry
      (`CHANGELOG.md:11-25`); the historical EDMV3-T67 AC6 row is untouched at `CHANGELOG.md:507`
      and still reads "PASS on the number, but the budget is still malformed".
- [x] AC11 -- the sentence "The re-derivation is the one piece of EDMV3-T67's budget work that
      remains open" no longer appears (`grep -n 'remains open'` returns nothing). The rewritten
      note at `CHANGELOG.md:557-570` closes Explorer 01's third assumption explicitly and in
      bold: "**Nothing addressed the 'budget is still malformed' objection between this entry and
      `EDMV4-T01`: it stayed open, named but unfixed ...**".
- [x] AC12 -- `bash plugins/edm/bin/tests/timing.sh --self-test` exits **0** (5/5 assertions,
      including the G35/CA-311 nearest-rank pin); `git diff --stat 5e26963..HEAD --
      plugins/edm/bin/edm-lint-artifacts` is empty, and `28f4dfe` touches only `CHANGELOG.md`,
      `CLAUDE.md` and `timing.sh`.

**Finding**: [P2] EDMV4-T01 | plugins/edm/CLAUDE.md:963-975 | AC#9: The re-measurement states
whether the 1.12x figure is still current after the D4 `plugin.json` reconciliation (`EDMV4-03`)
and after this initiative's own changes | Only the second half is stated. Neither `EDMV4-03` nor
the D4 reconciliation is named anywhere in `CLAUDE.md` or `CHANGELOG.md`. Fix: one sentence in the
`CLAUDE.md:963-975` paragraph confirming the reconciliation is a version-metadata change that
cannot move lint timing, so it does not affect the superseded verdict.

---

## EDMV4-T04: Anchor all 14 by-name reference files -- FAIL (10 PASS / 2 FAIL)

- [x] AC1 -- the mandatory order is visible in `git log --oneline`:
      `94dd043` (EDMV4-50, generator) -> `c52f157` (EDMV4-51, enumeration) -> `6565ad8`
      (EDMV4-49, anchoring). The `--stat` of each confirms no anchoring edit precedes the
      enumeration: `94dd043` touches only the generator, `wave6-smoke.sh` and the regenerated
      doc; `c52f157` adds `decisions.md` D27/D28 plus four more generator calls; only `6565ad8`
      edits the 14 prompt files.
- [x] AC2 -- `bin/edm-sync-canonical-sections:114`
      `extract_section "Unverifiable acceptance criteria (D15)" "$SRC"`, byte-identical and
      one-directional like its two predecessors at `:110` and `:112`. The `CLAUDE.md` D15 heading
      string is unchanged.
- [ ] AC3 -- **FAIL** on the "`--check` exits 0" clause. Run directly against the tree during
      this audit, `bash plugins/edm/bin/edm-sync-canonical-sections --check` exited **1** with a
      `Project artifact layout` diff: `CLAUDE.md` gained nine `SRD/.codemap.md` lines in
      `0c8ac40` (EDMV4-T48) and `docs/canonical-sections.md` was never regenerated. The committed
      blob at HEAD is still stale -- `git diff --stat plugins/edm/CLAUDE.md` is empty (so the
      working-tree source equals HEAD) while `docs/canonical-sections.md` carries an uncommitted
      +9-line regeneration produced by a sibling agent mid-audit. The **other** two clauses pass:
      the file is script-generated, and both `--check` directions are proven by a real smoke case,
      not asserted (`wave6-smoke.sh` T41 AC5 backs the file up, hand-edits it, asserts exit 1,
      restores, asserts exit 0 again -- verified passing in a full `wave6-smoke.sh` run).
- [x] AC4 -- `wave6-smoke.sh` gains the third presence check
      (`## Unverifiable acceptance criteria (D15)`) and the third byte-identity diff using the
      same `awk` idiom, plus one presence-and-diff pair for each of the four sections added by an
      AC7 route-1 resolution. All nine assertions observed passing in a live `wave6-smoke.sh` run.
- [x] AC5 -- `decisions.md:37` (D27) enumerates every distinct section name with every site,
      explicitly re-derived by content across all three citation shapes (backticked, unbackticked,
      bare `Sec."..."` continuation), not one row per file.
- [x] AC6 -- the `(canonical)`-suffix versus exact-match case is classified deliberately as
      "Bucket A -- already resolves via the generator, exact-match-modulo-suffix ... deliberately
      classified as NOT orphans", with every affected site listed. Neither silently exempted nor
      mass-flagged.
- [x] AC7 -- every orphan is resolved by a named route, recorded per case in D27: Route 1 for
      D15 / `Project artifact layout` / `Optional: Jira synchronization`; Route 2a for
      `EDM mode matrix` and `Phase Timing Guidelines` (citations gain the real `(EDMV3-T38)`
      suffix, then the exact string is added to the generator at `:120` and `:122`); Route 3 for
      `Skill-tool composition`, resolved by inlining -- `grep -rn 'Skill-tool composition'
      skills/ agents/` now returns nothing. D28 adds a fourth, honestly-argued classification
      ("deliberately unmirrored") for `Verifier completion sentinel (canonical)`.
- [x] AC8 -- D27's own reconciliation column records the discrepancy against `EDMV4-50`'s
      8-site / 6-section table rather than absorbing it: the live tree carries a fifth D15
      citation at `agents/edm-ticket-auditor.md:55` that the pre-audit table missed, so the real
      anchorable count is 32, not the advisory 31.
- [x] AC9 -- verified by an independent sweep of all 14 files at HEAD: **33** `CLAUDE.md`-scoped
      `Sec."..."` sites; 29 are anchored **and** name a section that exists in
      `docs/canonical-sections.md`; the 3 Route-3 sites are gone by design; the two
      `Verifier completion sentinel (canonical)` sites (`skills/audit-srd/SKILL.md:68`,
      `skills/audit-tickets/SKILL.md:75`) are the D28-recorded deliberate exemption. Every one of
      the 14 files carries at least one anchor sentence.
- [x] AC10 -- the applied sentence is verbatim the exemplar at `agents/edm-audit-logic.md:69`,
      including the qualifier "resolved relative to the EDM plugin's own root -- `plugins/edm/` in
      this repository, or the installed plugin's cache root, never the caller's cwd". The original
      citation is retained at every anchored site (spot-checked at
      `skills/orchestrator/SKILL.md:145` and `:234-241`).
- [ ] AC11 -- **FAIL, completely unmet.** `bin/edm-check-grants` has no orphan-citation check of
      either failure mode: `git diff --stat 1ea4994..HEAD -- plugins/edm/bin/edm-check-grants` is
      empty, and the only `canonical-sections`/`Sec."` matches in the file are unrelated comment
      prose at `:125` and `:480`. No positive controls exist. The implementer's self-report
      ("reverted rather than ship broken code") is accurate. Two consequences compound this:
      (i) `decisions.md:38` (D28) asserts that the check "hard-codes an exemption for the exact
      section name `Verifier completion sentinel (canonical)`", describing behaviour of a check
      that does not exist; (ii) the regression class the check exists to stop has **already
      occurred in this same wave** -- `skills/orchestrator/SKILL.md:118` and `:123` carry bare,
      unanchored `CLAUDE.md Sec."EDM mode matrix"` citations (without the Route-2a `(EDMV3-T38)`
      suffix, so they name a string with no mirror), introduced by `aee1eed` (EDMV4-T34) after
      `6565ad8` landed.
- [x] AC12 -- as of this ticket's own commit the sweep clause holds (the only post-`6565ad8`
      violations are the two T34 sites recorded above, which postdate it). `CLAUDE.md:441-475`
      replaces the eight-file list with the verified fourteen, records "**`EDMV4-T04` has
      landed**", and states "seven sections total, derived from `edm-sync-canonical-sections`' own
      generation block at edit time, not assumed" -- which matches the generator's actual seven
      calls at `:110-122`. `grep -rn 'lint-and-pipeline-budgets' plugins/edm/` returns nothing, so
      the stale directory name is gone.

**Findings**:

[P0] EDMV4-T04 | plugins/edm/bin/edm-check-grants (unmodified) | AC#11: `bin/edm-check-grants`
gains one check with two failure modes, both proven to discriminate by positive controls | The
check does not exist in any form. `git diff --stat 1ea4994..HEAD` on the file is empty. Graded P0
because the AC is completely unmet, it is the ticket's only enforcement mechanism, and its absence
has already let two unanchored citations land in the same wave.

[P1] EDMV4-T04 | plugins/edm/skills/orchestrator/SKILL.md:118,123 | AC#11 (consequence): the
class AC11's check exists to catch | Both lines cite `CLAUDE.md Sec."EDM mode matrix"` bare --
no anchor sentence within the surrounding block, and the un-suffixed name has no mirror in
`docs/canonical-sections.md` (the generated heading is `EDM mode matrix (EDMV3-T38)`). Introduced
by `aee1eed` (EDMV4-T34), so this is not a T04 authoring defect; it is direct evidence of the cost
of shipping T04 without AC11. Fix: apply the Route-2a suffix and the standard anchor sentence at
both sites.

[P1] EDMV4-T04 | plugins/edm/docs/canonical-sections.md (HEAD blob) | AC#3: `--check` exits 0
after the regeneration | At HEAD the committed generated file is stale by nine lines against the
committed `CLAUDE.md` `## Project artifact layout` section (drift introduced by `0c8ac40`,
EDMV4-T48). Reproduced: `--check` exit 1 with the diff. A regeneration already exists uncommitted
in the working tree; the fix is to run `bash plugins/edm/bin/edm-sync-canonical-sections` and
commit the result before the merge gate.

[P2] EDMV4-T04 | plugins/edm/CLAUDE.md:933 | AC#12 (adjacent site): the true final count |
The `bin/` helper table still describes the script as regenerating the file "from this file's
"Severity vocabulary" and "Mermaid diagram conventions" sections" -- a two-section claim that is
now wrong by five. AC12 named only "the note below the Mermaid section", which was updated
correctly, so this is not a FAIL of the AC; it is the same stale count in a second place.
`bin/edm-sync-canonical-sections:14-15` carries the identical stale "the two by-name-referenced
canonical sections" phrasing.

### Scope adjudication: seven generated sections versus `EDMV4-50`'s "third"

**Verdict: necessary completion, not scope creep.** The reasoning is structural, not charitable:

1. `EDMV4-51` was raised from Should Have to Must Have by the SRD audit (P0-3) precisely so that
   the enumeration would gate the other two requirements. Its output (D27) found five orphaned
   section names beyond D15, at eight sites across five files.
2. `EDMV4-T04` AC7 mandates that **every** orphan be resolved by one of three named routes, and
   Route 1 *is* "add to the generator". AC12 independently forbids the alternative -- anchoring a
   citation to a section that does not exist is the failure mode the ticket calls "worse than the
   bare form, because it looks fixed".
3. Therefore `EDMV4-49` could not have completed with three generated sections: four of the 14
   files would have been anchored to names with no mirror. The word "third" in `EDMV4-50` is an
   ordinal identifying D15, not a cap on the generated set, and the ticket's own AC12 tells the
   implementer to derive the final count "from the generator's actual section list at edit time,
   not assumed".
4. The implementer stayed inside the boundary in the direction that matters: `CLAUDE.md`'s section
   **bodies** were not edited (Out of Scope), only the D34 passage and citations; the one section
   that would have required a heading rename (Route 2b) was resolved by the cheaper default 2a.

The real cost of the decision is worth recording rather than disputing: the byte-identity coupling
surface grew from two `CLAUDE.md` sections to seven, and `Project artifact layout` is a section
other tickets edit routinely. That coupling broke within days (the AC3 finding above). The
follow-up worth naming is wiring `edm-sync-canonical-sections --check` into a commit-path or
`run-all.sh` gate, which is adjacent to -- and partly subsumed by -- the unbuilt AC11 check.

---

## EDMV4-T05: Verify CA-532/CA-490 and record the eval boundary -- FAIL (10 PASS / 1 PARTIAL / 1 FAIL)

**API budget: none spent, confirmed.** `plugins/edm/evals/baseline/` contains only `README.md` --
no `scores.json`. `git status --short` shows no eval run artifacts anywhere in the tree, and
`git diff --stat 1ea4994..HEAD` on `evals/run-eval.sh` and `bin/edm-compare-eval` is empty. The
commit `0532ff4` touches exactly two files: `decisions.md` and the new `bin/tests/wave8-smoke.sh`.
D9 is recorded as the scope boundary. No live eval was executed.

- [x] AC1 -- `bin/tests/wave8-smoke.sh:26-56` asserts both arrays are declared with `=(` and
      expanded as `--allowedTools "${CLAUDE_ALLOWED_TOOLS[@]}"` /
      `--disallowedTools "${CLAUDE_DISALLOWED_TOOLS[@]}"`. Observed passing.
- [x] AC2 -- `wave8-smoke.sh:58-100` compares the **line number** of the `cand_complete` test
      against that of `[ ! -f "$BASELINE" ]`; no absolute line numbers appear. Observed passing.
- [x] AC3 -- `bin/tests/wave8-smoke.sh` sits at `bin/tests/` depth 1 and is matched by
      `run-all.sh`'s `find ... -name '*-smoke.sh'` glob (it is not in `_PREFERRED_ORDER` at
      `run-all.sh:39`, which the suite reports as a NOTE naming `EDMV4-T53` as the owner, per the
      AC's own instruction). Creating a new suite rather than extending one is consistent with the
      ticket pack: epics 02, 03 and 05 all name `plugins/edm/bin/tests/wave8-smoke.sh (new)` in
      their Target Components, and `EDMV4-T53` owns the `_PREFERRED_ORDER`/`_MIN_SUITE_COUNT`
      registration.
- [ ] AC4 -- **PARTIAL**. `bash plugins/edm/bin/tests/wave8-smoke.sh` exits **0** with
      `Results: 83 passed, 0 failed`, and both new cases plus both discrimination controls are
      reported as passes. The aggregate `run-all.sh` exit was not established by this audit (the
      coordinator reserves the full-suite run for the merge gate); `wave6-smoke.sh` currently
      exits 1 on the by-design `T27 AC1` assertion owned by `EDMV4-T30`, so the aggregate cannot
      be inferred.
- [x] AC5 -- both positive controls are in-suite and observed discriminating: collapsing
      `CLAUDE_ALLOWED_TOOLS` to a space-joined string fails the AC1 check, and swapping the two
      anchor lines fails the AC2 check.
- [x] AC6 -- `decisions.md:48-49` record CA-532 (`raised_round: 10, resolved_round: 11`) and
      CA-490 (`raised_round: 9, resolved_round: 11`), each naming
      `SRD/.archived/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl` as origin.
- [x] AC7 -- `decisions.md:50` drops CA-537 with the reason recorded: no `.gitlab-ci.yml` exists
      (constraint C8), `b56558d` removed the pipeline, and `.claude/worktrees/*/` copies are agent
      scratch trees.
- [x] AC8 -- no re-fix: `git diff --stat 1ea4994..HEAD -- plugins/edm/evals/run-eval.sh
      plugins/edm/bin/edm-compare-eval` is empty.
- [ ] AC9 -- **FAIL**. D9 (`decisions.md:14`) is a numbered decision and does record the capture as
      out of scope and as a human credential decision, but the follow-on is **not named**: the text
      reads "it is carried as its own follow-on ticket, **to be filed** and run once a human owning
      `ANTHROPIC_API_KEY` for wave-A exit is ready". No ticket ID, initiative prefix or artifact
      name is given. This is the precise defect the ticket's own Description says the record exists
      to prevent ("an unnamed gap is how `EDMV4-T01`, `T04` and `T05` became orphans in the first
      place").
- [x] AC10 -- D9 states the capture procedure exactly: three `run-eval.sh` invocations against
      fresh scratch trees, each scored individually by `score-artifacts.sh`, with the run whose
      `total` is the middle of the three committed as the baseline.
- [x] AC11 -- D9 lists `scorer_version` (`"1.1.0"`, `score-artifacts.sh:139`),
      `dimensions_scored` (**5**, with the reason dimension 5 has no input), `dimensions`,
      `total`, `complete`, and `variance.total_range` scoped explicitly to the committed baseline
      only, citing `jq -r '.variance.total_range // 0'` at `:109`.
- [x] AC12 -- D9 states the interim behaviour plainly (exit **3**, "the eval tripwire is NOT
      armed", `bin/edm-compare-eval:77-81`), cross-references `evals/baseline/README.md`
      (`:39-55`, `:104-116`, `:165-171`), and closes with "No agent spends API budget under EDMV4
      to capture the baseline". `README.md:165-171` was read and agrees in its own words.

**Findings**:

[P1] EDMV4-T05 | SRD/edm/EDMV4__ecc-integration/decisions.md:14 | AC#9: the follow-on that owns
the baseline capture is recorded **by name** | D9 says the capture "is carried as its own
follow-on ticket, to be filed" without naming it. Fix: assign and record a concrete identifier
(a ticket ID in this pack, or a named successor initiative prefix) in the D9 row, matching the
D5/D14 "named follow-on" precedent the row itself invokes.

[PARTIAL] EDMV4-T05 | AC#4: `bash plugins/edm/bin/tests/run-all.sh` exits 0 with both new cases
reported as passes | runtime-check: run `bash plugins/edm/bin/tests/run-all.sh` at the merge gate
and confirm exit 0 and the two `EDMV4-T05 AC1/AC2` lines reported as passes. `wave8-smoke.sh`
alone already exits 0 (83/0); the open question is only the aggregate, which currently also
depends on `EDMV4-T30`'s `wave6-smoke.sh T27 AC1` rewrite and on committing the
`docs/canonical-sections.md` regeneration.

[P2] EDMV4-T05 | plugins/edm/bin/tests/wave8-smoke.sh:102-110 | AC#3: raise a defect against
`EDMV4-T53` if the registration is absent | The defect is raised only as a stdout `NOTE:` line
during a suite run; it is not recorded in `decisions.md` or any findings ledger, so it disappears
the moment nobody reads the transcript. The assertion and the naming of `EDMV4-T53` are both
correct, so this is a durability nit, not a missing check.

---

## EDMV4-T06: Spike A, multi-hook-per-event semantics -- PARTIAL (6 PASS / 5 PARTIAL)

The deliverable is `decisions.md:35` (D25), and it is a genuinely detailed record: version string,
method, marker layout, both orderings, both events, the homogeneous-pair case, and explicit
statements that AC7's and AC9's trigger conditions did not occur. Five ACs, however, require that
a live-host experiment was *executed*; commit `ccddd30` adds three lines to `decisions.md` and
nothing else, so no harness, scratch settings file, marker output or transcript survives in the
tree. Those five are classified PARTIAL: their recorded content is verified, their execution is
not re-verifiable statically. They are not failures -- nothing contradicts the record.

- [ ] AC1 -- **PARTIAL**. D25 records the setup (two `PreToolUse` matcher-`Bash` blocks, block-a
      exit 0, block-b exit 2) and names the host's decision unambiguously: both orderings refused
      the call, with the tool result quoted.
- [ ] AC2 -- **PARTIAL**. The reverse ordering is recorded separately and the conclusion is stated
      in the required terms -- "Order is not load-bearing for either event" -- so the
      "registration order is load-bearing" branch correctly did not fire.
- [ ] AC3 -- **PARTIAL**. D25 records distinct markers under one `mktemp -d` per run
      (`block-a-ran`, `block-b-ran`) and answers the which-commands-ran question from the markers
      present: both executed.
- [ ] AC4 -- **PARTIAL**. The `Stop`-event experiment is recorded in its own sentence block with
      its own outcome, not collapsed into the `PreToolUse` verdict.
- [ ] AC5 -- **PARTIAL**. The homogeneous `command`+`command` `Stop` array is recorded with all
      three required answers: both entries ran; not only the first; and entry 2's exit 2 was
      honoured even though entry 1 exited 0.
- [x] AC6 -- verified independently, not merely accepted: `hooks.json` `UserPromptExpansion[0]`
      (`:16-25`) is a `command` entry plus a `prompt` entry, and a parse of every block in
      `plugins/edm/hooks/hooks.json` yields **zero** homogeneous `command`+`command` arrays
      (`SessionStart`, `PreToolUse`, `Stop`, `PreCompact` each have one `command` entry;
      `SubagentStop` has one `prompt`). D25 states this premise honestly.
- [x] AC7 -- the "only one entry executes" branch did not occur and D25 says so, so no gate
      re-presentation of a second `Stop` matcher block is triggered. `EDMV4-44`'s design stands.
- [x] AC8 -- answered explicitly: 5.3 **may** register a `bash`-event `PreToolUse` block alongside
      the `git commit` block at `hooks.json:80-90`, and AD4's fold-into-dispatcher fallback is
      not required by this evidence.
- [x] AC9 -- the trigger condition ("first-registered wins" / "blocks must be consolidated") did
      not occur, and D25 records that, so `EDMV4-43`'s `bash` event is not withdrawn.
- [x] AC10 -- D25 is a numbered decision quoting `claude --version` verbatim as
      `2.1.246 (Claude Code)`, dated `2026-09-02`, and adds the D22-style caveat that this is one
      host version's behaviour to be re-run if `EDMV4-T11/T45/T46` ship against a different one.
- [x] AC11 -- `plugins/edm/hooks/hooks.json` is unmodified: `git diff --stat 1ea4994..HEAD` on the
      path is empty and `git status --short` on it returns nothing.

**Findings**:

[PARTIAL] EDMV4-T06 | AC#1: two `PreToolUse` blocks matching one call, block 1 allow / block 2
deny, recorded result names the host's decision | runtime-check: in a disposable `mktemp -d` repo
against `claude --version` 2.1.246, register two `PreToolUse` matcher-`Bash` blocks (exit 0 then
exit 2), issue one `Bash` call, and confirm the call is refused as D25 records.

[PARTIAL] EDMV4-T06 | AC#2: the reverse ordering is run and recorded separately | runtime-check:
repeat the AC1 harness with deny registered first and confirm the outcome is identical, i.e. that
registration order is not load-bearing.

[PARTIAL] EDMV4-T06 | AC#3: each command writes a distinct marker under one `mktemp -d`; the
record names which commands ran from the markers present | runtime-check: after each ordering,
list the scratch directory and confirm both `block-a-ran` and `block-b-ran` exist.

[PARTIAL] EDMV4-T06 | AC#4: the same two-block experiment is run for the `Stop` event | runtime-
check: register two `Stop` blocks (one always exit 0, one marker-gated deny) in a scratch repo and
confirm both fire on both orderings.

[PARTIAL] EDMV4-T06 | AC#5: two `"type": "command"` entries in one `Stop` block's `hooks` array |
runtime-check: register a single `Stop` block whose `hooks` array holds two `command` entries with
distinct markers, entry 1 exit 0 and entry 2 exit 2, and confirm both markers appear and entry 2's
exit code is honoured.

[NOTED] EDMV4-T06 | commit ccddd30 (decisions.md only) | The spike left no reproducible harness in
the repository, so each of the five runtime checks above has to be re-authored from D25's prose.
No AC required committing the harness -- AC11 in fact requires the experiment to run entirely from
a scratch tree -- but a small committed `bin/tests/spikes/` script would have made these five
closable in one command instead of one reconstruction.

---

## Remediation Required

Ordered by severity. PARTIAL findings are not remediated here -- `/edm:verify-runtime` closes them
to PASS or FAIL before archive.

1. **[P0] EDMV4-T04 AC11** -- build the `bin/edm-check-grants` orphan-citation check with both
   failure modes (bare `Sec."..."` under `skills/`|`agents/` with no adjacent anchor; anchored
   citation whose named section is absent from `docs/canonical-sections.md`), plus the two
   positive controls the AC specifies and the `Verifier completion sentinel (canonical)` exemption
   that `decisions.md` D28 already claims exists. The implementer's stated blocker -- a tree-wide
   regex matching the descriptive `Sec."..."` text *inside* the anchor sentences -- is solvable by
   excluding the literal placeholder `Sec."..."` (three dots) from the citation pattern, which is
   exactly how this audit's own sweep enumerated 33 real sites with zero false positives. Until
   the check ships, D28's claim about it should be reworded to the future tense.
2. **[P1] EDMV4-T04 AC11 consequence** -- fix `plugins/edm/skills/orchestrator/SKILL.md:118,123`:
   add the `(EDMV3-T38)` suffix to both `EDM mode matrix` citations and append the standard anchor
   sentence.
3. **[P1] EDMV4-T04 AC3** -- run `bash plugins/edm/bin/edm-sync-canonical-sections` and commit the
   regenerated `docs/canonical-sections.md` (the regeneration is already sitting uncommitted in
   the working tree). Verify `--check` exits 0 from a clean checkout before the merge gate.
4. **[P1] EDMV4-T05 AC9** -- name the eval-baseline follow-on in `decisions.md:14` D9 with a
   concrete ticket ID or successor initiative prefix.
5. **[P2] EDMV4-T01 AC9** -- add one sentence to `plugins/edm/CLAUDE.md:963-975` stating whether
   the 1.12x figure is still current after the D4 `plugin.json` reconciliation (`EDMV4-03`),
   confirmed or refuted.
6. **[P2] EDMV4-T04 AC12 adjacent** -- update `plugins/edm/CLAUDE.md:933` and
   `bin/edm-sync-canonical-sections:14-15`, both of which still describe a two-section generated
   set.
7. **[P2] EDMV4-T05 AC3** -- record the `EDMV4-T53` registration gap in `decisions.md` so it
   survives outside a suite transcript.

<!-- QC-SHARD-COMPLETE range=EDMV4-T01..EDMV4-T06 assigned=4 audited=4 -->
