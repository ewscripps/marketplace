# QC Audit Report: Epic 01 -- Verifier completion sentinel and budget parity [Shard 1/1]

**Date**: 2026-08-31
**Tickets audited**: VERIF-T01 through VERIF-T11
**Branch**: `edm/verif-verifier-truncation`
**Mode**: `implementation_mode=standard` -- the TDD compliance pass does not run.

## Summary

| Ticket | Title | Verdict |
|---|---|---|
| VERIF-T01 | Specify the verifier completion-sentinel contract | FAIL |
| VERIF-T02 | Emit the QC completion sentinel as the shard's final line | PASS |
| VERIF-T03 | Refuse incomplete QC shards at the qc-summary merge step | FAIL |
| VERIF-T04 | Negative smoke tests for both QC refusal paths | PASS |
| VERIF-T05 | Sentinel + check for edm-srd-auditor | PASS |
| VERIF-T06 | Sentinel + check for edm-ticket-auditor | PASS |
| VERIF-T07 | Sentinel-terminate test-coverage.md and check it | PASS |
| VERIF-T08 | Assert the sentinel instruction in all four verifier prompts | PASS |
| VERIF-T09 | Raise the four verifiers from maxTurns 25 to 50 | PASS |
| VERIF-T10 | Pre-verify mechanical claims before spawning auditors | PASS |
| VERIF-T11 | Ship 3.2.2 in both manifests and the changelog | FAIL |

**Rollup**: 8 PASS, 3 FAIL, 0 PARTIAL. Every AC in this epic proved statically verifiable --
by design, per `decisions.md` D4, which deliberately kept "the agent reliably emits X" out of the
AC set. No AC required a live runtime environment, so this shard records no PARTIAL verdicts and
nothing here is deferred to `/edm:verify-runtime`.

**One P1 defect (VERIF-T03 AC6) is a live silent-pass in the shipped check.** The other two FAILs
are P2 documentation/process gaps. Details below.

### Grammar deviation applied throughout -- read this before the per-ticket sections

The epic specifies the sentinel grammar in five places as

```
<!-- {MARKER}-COMPLETE range={ASSIGNMENT} audited={N} -->
```

The implementation everywhere uses a three-field superset that inserts `assigned={M}`:

```
<!-- {MARKER}-COMPLETE range={ASSIGNMENT} assigned={M} audited={N} -->
```

This is applied consistently across `CLAUDE.md:315`, all four agent prompts, the checker script,
all four consumers and the smoke suite -- it is a coherent redesign, not a slip. It is graded
**once, at its source (VERIF-T01 AC2/AC6)**, where the grammar is specified. The downstream
"ends with the literal line ..." ACs (T02 AC1, T05 AC1, T06 AC1, T07 AC1) are graded PASS against
the implemented canonical grammar, because the marker, `range=` and `audited=` are all present in
order on the block's true final line. Readers should not conclude the AC's literal string was
matched -- it was not. The deviation is recorded in no `decisions.md` entry (D1-D6 do not mention
`assigned=`), which is why it surfaces here rather than as an accepted variance.

The deviation is not cosmetic: it is the direct cause of the P1 under VERIF-T03 AC6 below,
because `CLAUDE.md:336-337` goes on to state that "no consumer parses it [`range=`] to derive a
count" -- the exact opposite of what T03 AC6 requires the script to do.

---

## Detailed Findings

### VERIF-T01: Specify the verifier completion-sentinel contract -- FAIL

- [x] AC1: Section headed exactly `## Verifier completion sentinel (canonical)` -- `plugins/edm/CLAUDE.md:299`.
- [ ] AC2: Grammar defined as `<!-- {MARKER}-COMPLETE range={ASSIGNMENT} audited={N} -->` -- **FAIL**: `CLAUDE.md:315` documents `<!-- {MARKER}-COMPLETE range={ASSIGNMENT} assigned={M} audited={N} -->`. The ASCII-only, single-line, one-space-either-side and no-line-continuation properties are all stated (`:311-312`) and hold; the field list does not.
- [x] AC3: All four markers and their artifacts enumerated -- `CLAUDE.md:325-330`, table rows for `QC-SHARD-COMPLETE` (both shard globs), `SRD-AUDIT-COMPLETE`, `TICKET-AUDIT-COMPLETE`, `TEST-COVERAGE-COMPLETE` (`test-coverage.md` and any `test-coverage-{epic}.md`).
- [x] AC4: `range=` is the dispatcher's assignment, no whitespace; `audited=` is a base-10 count of units actually covered -- `CLAUDE.md:334-337` and `:342-344`.
- [x] AC5: Consumer checks `tail -1` and nothing else, with the reason -- verified at `CLAUDE.md:346-355`, including the "a consumer that instead grepped the whole artifact ... destroys the property" rationale. PASS.
- [ ] AC6: Both refusal conditions named, (b) being `audited=` below the count implied by `range=` -- **FAIL**: `CLAUDE.md:362-369` names two conditions, and both do refuse loudly naming the artifact path, but condition (b) is defined as `audited=` below **`assigned=`**, and `:336-337` explicitly states that `range=` is "a human-readable label only -- no consumer parses it to derive a count". The section documents the negation of the AC's condition (b).
- [x] AC7: No binary beyond `bash`/`jq`/`git`; bash 3.2 compatible -- `CLAUDE.md:371-376`.
- [x] AC8: `grep -c` returns >= 1 for each of the four markers -- all four return exactly 1.
- [x] AC9: `bash plugins/edm/bin/edm-check-vocabulary` -- exit 0 (run).
- [x] AC10: `bash plugins/edm/bin/tests/run-all.sh` -- exit 0 (established fact; I independently ran `wave7-smoke.sh`: 1429 passed, 0 failed, exit 0).

**Findings**:
- [P2] VERIF-T01 | plugins/edm/CLAUDE.md:315 | AC#2: Documented grammar carries a third field, `assigned={M}`, that the AC's literal grammar does not. Applied consistently plugin-wide, recorded in no `decisions.md` entry. Remedy: either amend T01 AC2/AC6 (and T02/T05/T06/T07 AC1) to the three-field grammar and add a D7 decision row, or drop `assigned=`.
- [P2] VERIF-T01 | plugins/edm/CLAUDE.md:336-337, :366-367 | AC#6: Refusal condition (b) is specified against `assigned=` and the section affirmatively forbids deriving a count from `range=`, contradicting the AC. This is the documentation half of the VERIF-T03 AC6 P1 below -- fix them together or the script will drift back.
- [P2] VERIF-T01 | plugins/edm/CLAUDE.md:298-299 | (no AC): the new `##` heading has no blank line before it -- it butts directly against the last prose line of the Mermaid section. Not covered by any AC and not caught by `edm-check-vocabulary`; cosmetic, but every other `##` in the file is blank-line separated.

### VERIF-T02: Emit the QC completion sentinel as the shard's final line -- PASS

- [x] AC1: `## Output Format` block ends with the sentinel -- `agents/edm-qc-auditor.md:126`, with the closing fence at `:127`. It is the last content line of the block. (Grammar deviation per the note above.)
- [x] AC2: Imperative, final-line-of-the-file, nothing after it, presence-elsewhere insufficient -- `:142-146` ("Being present somewhere earlier in the file ... is treated by the consumer exactly as if the sentinel were absent").
- [x] AC3: Forbids writing it before the audit finishes, no header placeholder, no early write -- `:147-150`.
- [x] AC4: States `/edm:implement` refuses the shard and re-runs the auditor, and that the refusal is intended, not to be worked around -- `:160-163`.
- [x] AC5: `range=` is the assigned ticket range for both shard kinds, explicitly independent of the `qc-shard-pass-w{WW}-{NN}.md` filename components -- `:151-154`.
- [x] AC6: `audited=` is the number of tickets carrying a verdict row in the shard's own `## Summary` table -- `:157-159`.
- [x] AC7: `grep -c 'QC-SHARD-COMPLETE'` = 3; `grep -ci 'final line'` = 2.
- [x] AC8: `git show d31bbf8 -- agents/edm-qc-auditor.md` touches no frontmatter key (36 insertions, 0 deletions, none in frontmatter); `maxTurns` read `25` at that commit.
- [x] AC9: `bash plugins/edm/bin/edm-check-grants` -- exit 0 (run).
- [x] AC10: ASCII-only -- 0 non-ASCII lines.
- [x] AC11: `run-all.sh` exit 0.

### VERIF-T03: Refuse incomplete QC shards at the qc-summary merge step -- FAIL

- [x] AC1: `bin/edm-check-verifier-sentinel` exists, mode `755`, `#!/usr/bin/env bash` at `:1`, `set -euo pipefail` at `:46`. No `declare -A`, no `${var^^}`, no `mapfile`; the only match for those patterns is the comment at `:44` asserting their absence.
- [x] AC2: Usage is `<MARKER> <file> [expected-count]` (`:66-72`). The script's own work uses `tail` (`:89`) and `sed` (`:102-104`) plus shell builtins -- no `jq`, no `python`, no `awk`. See the P2 note below on `dirname`/`print_help`.
- [x] AC3: Exit contract 0/2/1 as documented at `:27-30` and observed. No arguments -> exit 1 with `usage: edm-check-verifier-sentinel <MARKER> <file> [expected-count]` on stderr.
- [x] AC4: Missing-sentinel refusal -- exit 2, stderr `<path>: truncated -- no QC-SHARD-COMPLETE sentinel on the last line` (`:96-99`). Verified against a live fixture.
- [x] AC5: Last-line-only -- a well-formed sentinel followed by one further line is refused identically. Verified live (exit 2, "truncated"). The script reads `tail -1` at `:89` and never greps the body; there is no whole-file scan anywhere in it.
- [ ] AC6: Short-count refusal derived from `range=`'s inclusive span, or the explicit `[expected-count]` argument when supplied -- **FAIL**. Both derivations exist (`:127-135` range span with `10#` handling, `:123-125` explicit argument) and the refusal message names file, audited and expected (`:151-152`). But `:121-122` gives the artifact's own `assigned=` field absolute precedence over both, which produces two silent passes:
  - `range=T01-T08 assigned=1 audited=1`, no argument -> **exit 0**. `audited=1` is below the 8 the range implies; AC6 requires exit 2.
  - Same line with an explicit `[expected-count]` of `8` supplied -> **exit 0**. AC6 says the explicit argument governs "when supplied"; it is ignored whenever `assigned=` is present.
  Both were reproduced against live fixtures. The failure direction is accept-when-it-should-refuse, i.e. exactly the silent pass this initiative exists to close, reachable through the consumer path that is wired today (`skills/implement/SKILL.md` invokes the script with no `[expected-count]`).
- [x] AC7: Malformed sentinel (marker present, no `range=`/`audited=`) -> exit 2, not a usage error -- `:106-112`, and wave7 fixture F confirms.
- [x] AC8: The merge step runs the check over every `qc-shard-impl-*.md` and `qc-shard-pass-*.md` before any content is written -- `skills/implement/SKILL.md:39` (prose) and `:127-135` (pseudo-code loop preceding the merge line at `:136`).
- [x] AC9: All-or-nothing -- `SKILL.md:39` ("`qc/qc-summary.md` is neither created nor overwritten, so no partially-merged summary is ever left on disk") and `:131-135` (`abort the merge for this pass entirely`).
- [x] AC10: Operator remedy verbatim -- "re-run `edm-qc-auditor` for the named shard's ticket range, then re-run the merge" at `SKILL.md:39`, repeated in the pseudo-code comment at `:134`.
- [x] AC11: `CLAUDE.md:922` carries the `bin/` table row with purpose and the 0/1/2 exit contract.
- [x] AC12: `run-all.sh` exit 0.

**Findings**:
- [P1] VERIF-T03 | plugins/edm/bin/edm-check-verifier-sentinel:121-125 | AC#6: The self-reported `assigned=` field outranks both the `range=`-implied span and the explicit `[expected-count]` argument, so a sentinel reading `range=T01-T08 assigned=1 audited=1` is accepted (exit 0) with and without an explicit count of 8. The count arm can be defeated by the same agent it is meant to police, and the dispatcher has no override. Fix: invert the precedence to explicit-argument > `assigned=` > `range=` span, and additionally refuse when `assigned=` is below a parseable `range=` span (an internally inconsistent sentinel is malformed, not authoritative). Add both cases to `wave7-smoke.sh`'s VERIF-T04 block -- neither is covered today.
- [P2] VERIF-T03 | plugins/edm/bin/edm-check-verifier-sentinel:48 | AC#2: `dirname` is invoked in the `SCRIPT_DIR` preamble, and `print_help` (`bin/_edm-cli-lib.sh:30`) invokes `awk` on the `-h`/`--help` path. Neither is in AC2's enumerated `bash`/`grep`/`sed`/`tail` set, though both are the plugin-wide preamble every `bin/` script already uses and neither is `jq` or `python`. Accepted as-is unless AC2 is meant literally; noted so the next reader does not re-derive it.

### VERIF-T04: Negative smoke tests for both QC refusal paths -- PASS

All twelve criteria verified. The whole block lives under a banner comment naming the ticket at
`bin/tests/wave7-smoke.sh:9237-9243`, in the style the ticket's Technical Notes required.

- [x] AC1: Fixture A (well-formed, `range=T01-T08 assigned=8 audited=8`) exits 0 -- `wave7-smoke.sh:9250-9256`; observed PASS in the run.
- [x] AC2: Fixture B (A minus its final line, built with `sed '$d'` so it is byte-identical otherwise) exits 2; stderr asserted to contain both the fixture path and `truncated` -- `:9266-9275`, three separate assertions.
- [x] AC3: Fixture C (sentinel present, one further line after it) exits 2 -- `:9279-9285`. This is the assertion that proves `tail -1` rather than a whole-file scan.
- [x] AC4: Fixture D (`assigned=8 audited=6`) exits 2, stderr asserted to contain both `6` and `8` -- `:9288-9297`.
- [x] AC5: Fixture E (`audited=8`) exits 0 -- `:9301-9307`, so the count arm distinguishes short from complete.
- [x] AC6: Fixture F (`<!-- QC-SHARD-COMPLETE -->`, no fields) exits 2, explicitly asserted as "not a usage error" -- `:9310-9316`.
- [x] AC7: **Mutation guard for the truncation arm -- genuinely flips.** `:9334-9349` locates the anchored `VERIF-T03 marker-check` comment in the real script, finds the matching `^esac$`, `sed`-deletes that line range into a copy under `$TMP`, and asserts the mutated copy **exits 0** on fixture B. If the mutant still exits 2 it fails with a named message ("the refusal is coming from somewhere other than the check under test"). This is the correct construction: it proves the deleted check *causes* the refusal, not merely that the unmutated script refuses. The guard is also non-vacuous by design -- fixture B's line 2 is deliberately crafted to carry bare `range=`/`assigned=`/`audited=` tokens without the comment wrapper (rationale at `:9258-9265`), so the mutant can actually reach the accept path; without that, a downstream arm could coincidentally refuse and the guard would prove nothing. Both anchor-not-found branches call `fail`, so a reshaped script fails loudly rather than skipping.
- [x] AC8: Mutation guard for the count arm -- same technique against fixture D, deleting from the `VERIF-T03 count-check` anchor to the matching `^fi$` and asserting exit 0 -- `:9354-9369`. I traced the deleted span (script `:144-154`, leaving `exit 0` reachable) and confirm it flips.
- [x] AC9: Every fixture is created under `$TMP` (`:23`, `mktemp -d` with an explicit template) and removed by the existing four-arm trap (`:26-29`, EXIT/INT/TERM/HUP). `git status --porcelain` after my run shows no test residue -- only pre-existing unrelated modifications and this untracked initiative directory.
- [x] AC10: All new assertions route through `_harness.sh`'s `pass`/`fail`/`check` counters (`_harness.sh:23-27`), so a failure moves the suite's exit code.
- [x] AC11: `bash plugins/edm/bin/tests/wave7-smoke.sh` -- exit 0, "Results: 1429 passed, 0 failed". 12 VERIF-T04 assertions print in the run. The commit's only deletion in this file is one continuation line inside an unrelated T52 block, so the printed count rose by exactly the cases added.
- [x] AC12: `run-all.sh` exit 0; the block performs no network access and writes only under `$TMP`.

### VERIF-T05: Sentinel + check for edm-srd-auditor -- PASS

- [x] AC1: Output contract ends with the `SRD-AUDIT-COMPLETE` line -- `agents/edm-srd-auditor.md:105`, closing fence at `:106`. (Grammar deviation per the top note.)
- [x] AC2: Final line of the **returned text**, nothing after it, presence elsewhere insufficient -- `:119-124`, including "You write no file -- your entire response to the dispatching skill IS the artifact this contract checks".
- [x] AC3: Forbids emitting it before the audit completes -- `:125-128`.
- [x] AC4: `range=` is the assigned section group, no whitespace, example `S1-S4`; `audited=` is sections actually covered -- `:129-135`.
- [x] AC5: `skills/audit-srd/SKILL.md` step 5 checks the **last non-empty line** of each returned block before compiling into `${INIT_DIR}/audit-srd.md` -- step 5 as landed, quoting the literal marker and the canonical grammar. It is a last-non-empty-line check, not a block-wide grep.
- [x] AC6: A failing block is not compiled; the skill names the agent's assigned section group and re-dispatches (resume) that agent, in the skill text.
- [x] AC7: Short-count refusal (`audited=` below the assigned section count) routes through the same refusal path, stated as a distinct second bullet.
- [x] AC8: States that a truncated auditor's partial findings are never that section group's audit result, and that **Gate 2 must not be presented while any block is outstanding**.
- [x] AC9: `grep -c 'SRD-AUDIT-COMPLETE'` = 3 in the agent, 2 in the skill.
- [x] AC10: `git show 99bec9a` touches no frontmatter key; `maxTurns` read `25` at that commit.
- [x] AC11: `edm-check-grants` exit 0 and `edm-check-skill-sync` exit 0 (both run).
- [x] AC12: `run-all.sh` exit 0.

Note: the skill's step renumbering (old 5-10 became 6-11, `8a` became `9a`) was applied
consistently, including the back-reference in the "Pending Pattern Entries" section.

### VERIF-T06: Sentinel + check for edm-ticket-auditor -- PASS

- [x] AC1: Output contract ends with the `TICKET-AUDIT-COMPLETE` line -- `agents/edm-ticket-auditor.md:133`, fence at `:134`.
- [x] AC2: Final line of the returned text, nothing after, presence elsewhere insufficient -- `:147-152`.
- [x] AC3: Forbids emitting it early -- `:153-156`.
- [x] AC4: `range=` is exactly `structural` or `content-quality`, tied to the lane tags the skill applies at its compile step, "No whitespace, no other spelling" -- `:157-159`.
- [x] AC5: `audited=` is the number of pack tickets that lane actually graded -- `:162-164`.
- [x] AC6: `skills/audit-tickets/SKILL.md` step 5 checks the last non-empty line of each lane's block before compiling into the pack's `audit.md`.
- [x] AC7: A failing lane is not compiled, is never de-duplicated against the other lane, and is re-dispatched by name -- step 5 states all three explicitly.
- [x] AC8: Short-count refusal (`audited=` below the pack count) routes through the same path.
- [x] AC9: "**Gate 3 must not be presented while either lane is outstanding.**"
- [x] AC10: `grep -c 'TICKET-AUDIT-COMPLETE'` = 3 in the agent, 2 in the skill.
- [x] AC11: `git show 22a6bcb` touches no frontmatter key; `maxTurns` read `25` at that commit.
- [x] AC12: `run-all.sh` exit 0.

The pack count reuses the count step 4 already needs for Dimension 1 coverage checking, as the
Technical Notes required; the two-lane mandatory spawn is unchanged (still exactly two, parallel).

### VERIF-T07: Sentinel-terminate test-coverage.md and check it -- PASS

- [x] AC1: The `TEST-COVERAGE-COMPLETE` line terminates both report templates the agent writes -- `agents/edm-test-coverage-auditor.md:175` (multi-stack summary) and `:223` (the coverage report template used for single-stack and each per-epic file).
- [x] AC2: Final line of the file, nothing after it, presence elsewhere insufficient -- `:237-242`, naming `edm-check-verifier-sentinel` as the consumer.
- [x] AC3: Forbids writing it before the coverage audit for that file is finished -- `:243-246`.
- [x] AC4: Single-stack `range=` is the ticket range with `audited=` the ACs cross-referenced (`:247-251`); per-epic files carry `range={epic-slug}` with their own counts (`:252-254`); the multi-stack top-level summary is specified separately (`:255-258`).
- [x] AC5: `skills/test-coverage/SKILL.md:52-60` -- new Step 2a runs `edm-check-verifier-sentinel TEST-COVERAGE "${INIT_DIR}/test-coverage.md"` after the agent returns and before any downstream consumption.
- [x] AC6: The multi-stack loop globs `"${INIT_DIR}"/test-coverage-*.md` with an `[ -e "$f" ] || continue` guard and runs the same check on each, plus the top-level summary. It iterates files that exist rather than asserting one per epic, exactly as the Technical Notes required for the all-N/A case.
- [x] AC7: On refusal the skill reports the failing path, and re-dispatches the auditor. The skill itself never calls `edm-state record-test-coverage` (`grep` finds one mention, at `:76`, and it is prose). See the P2 below on the residual.
- [x] AC8: "A refused coverage report must never be used to satisfy that checklist item" -- `:77-80`, tying it to the Phase 6 "coverage targets met" item by name.
- [x] AC9: `grep -c 'TEST-COVERAGE-COMPLETE'` = 4 in the agent; `grep -c 'edm-check-verifier-sentinel'` = 3 in the skill.
- [x] AC10: `git show e53c53f` touches no frontmatter key; `maxTurns` read `25` at that commit and `disallowedTools: Edit, NotebookEdit` is preserved (`CLAUDE.md:680` still documents it).
- [x] AC11: `run-all.sh` exit 0.

**Finding**:
- [P2] VERIF-T07 | plugins/edm/skills/test-coverage/SKILL.md:74-77 | AC#7 (residual, not an AC violation): the agent calls `record-test-coverage` during Step 2, before Step 2a's check runs, so a truncated agent can leave a coverage number in state that the check then refuses. The guard against that is prompt-level (`agents/edm-test-coverage-auditor.md:268-271`, "Only call `edm-state record-test-coverage` for a layer or epic whose report file has already been written **including its completion sentinel**") and the skill's response is advisory ("treat as unverified ... do not present it"). Nothing clears or overwrites the stale entry, so `metrics-report` and any other state reader still see it. This is the one place in the initiative where the "the prompt asks, the consumer refuses" asymmetry (D4) is not achieved -- here the consumer can only annotate. Remedy: have Step 2a call a state-invalidating operation for the refused file's layers/epic, or defer `record-test-coverage` to the skill after the sentinel check passes.

### VERIF-T08: Assert the sentinel instruction in all four verifier prompts -- PASS

Block under its own banner at `bin/tests/wave7-smoke.sh:9371-9378`.

- [x] AC1: Each of the four agent files asserted to contain its own marker -- `:9417-9432`, driven off the mapping table; all four PASS in the run.
- [x] AC2: Each also asserted to carry case-insensitive `final line` wording -- `:9403`, so an edit that keeps the marker but drops the positional requirement fails.
- [x] AC3: The four markers asserted pairwise distinct -- `:9436-9440`, computed from the same map (`cut | sort -u`) rather than a second hand-typed literal that could diverge.
- [x] AC4: No other file under `agents/` carries a `-COMPLETE ` marker -- `:9446-9459`. The allowlist is written as four filenames (`:9446`), not an inverted pattern, so a fifth verifier fails loudly as the Technical Notes required. It routes through `assert_tree_absent`, which carries its own positive control (`:9457`) proving the scan can find a real hit.
- [x] AC5: Mapping declared once as a here-doc table -- `:9386-9392`, bash 3.2 safe (no associative array), consumed by a `while IFS='|' read`.
- [x] AC6: The assertion body is a function taking `(file, marker)` -- `verif_t08_check_sentinel` at `:9399-9414`, run against both the four real files and the AC7 copy.
- [x] AC7: Negative control -- `:9464-9472` copies `edm-qc-auditor.md` to `$TMP` with both the marker lines and the `final line` wording stripped and asserts the AC6 function returns non-zero, failing with a named message otherwise. Observed PASS, reporting `missing: marker(QC-SHARD-COMPLETE), final-line wording`.
- [x] AC8: Failure messages name the file and which property is missing -- `:9430` interpolates `${verif_t08_missing}`, which the function builds as `marker(...)` and/or `final-line wording` (`:9404-9408`).
- [x] AC9: `wave7-smoke.sh` exit 0 with the new assertions in the summary -- 7 VERIF-T08 assertions print; suite total 1429 passed, 0 failed.
- [x] AC10: `run-all.sh` exit 0; `git status --porcelain` shows no residue from the run.

### VERIF-T09: Raise the four verifiers from maxTurns 25 to 50 -- PASS

**Scrutiny item 4 -- the raise did not leak.** I enumerated `^maxTurns:` across all 30 agent files
independently of the suite's own assertions. Exactly four files moved to 50 in `306b0bf`; the
eleven lens agents are all still 30, `edm-audit-synthesizer` is still 30, `edm-implementer` is
still 60, and `edm-srd-writer`/`edm-ticket-writer`/`edm-architect` are still 50. The other agents
at 50 (`edm-test-unit`, `edm-test-contract`, `edm-test-component`, `edm-test-composable`,
`edm-test-integration`) and 60 (`edm-test-e2e`) were already at those values and are untouched by
this commit.

- [x] AC1: All four read `maxTurns: 50`, exactly one occurrence each.
- [x] AC2: None contains `maxTurns: 25` -- asserted per file at `wave7-smoke.sh:9502-9505`.
- [x] AC3: Eleven lens agents still `maxTurns: 30`, asserted by count -- `:9508-9529`. The implementation deliberately reuses the shared `LENS_AGENTS` enumeration rather than an `edm-audit-*.md` glob (which would sweep in `edm-audit-synthesizer` and miscount 12 as 11), and separately asserts `LENS_AGENTS` still holds exactly eleven names so the two cannot drift apart silently. This is a better construction than the AC required.
- [x] AC4: Producers asserted explicitly, one entry per named producer -- `:9533-9542`, `edm-implementer.md:60 edm-srd-writer.md:50 edm-ticket-writer.md:50 edm-architect.md:50`. All four PASS.
- [x] AC5: `CLAUDE.md:674` -- the testing-layer inventory row for `edm-test-coverage-auditor` reads `50` in the `maxTurns` column.
- [x] AC6: `CLAUDE.md:378-390` "Turn budget parity" states the four run at parity with the writers they check and explicitly says not to "tidy" them back to the floor, with the reasoning.
- [x] AC7: AC1-AC4 are computed checks in `wave7-smoke.sh`, not prose.
- [x] AC8: The AC1 assertion is a path-parameterized function (`verif_t09_has_maxturns_50`, `:9489-9492`) exercised against a `$TMP` copy rewritten to `maxTurns: 25`, asserted to return non-zero -- `:9548-9555`. Observed PASS, so the assertion demonstrably fails on a revert.
- [x] AC9: `git show 306b0bf -- 'plugins/edm/agents/*.md'` yields exactly four `-maxTurns: 25` / `+maxTurns: 50` pairs and nothing else. `model`, `effort`, `color`, `tools`, `disallowedTools` byte-identical.
- [x] AC10: `claude plugin validate plugins/edm/` -- exit 0 (run; one pre-existing warning about plugin-root `CLAUDE.md` not being loaded as project context, which is not an error and predates this initiative).
- [x] AC11: `run-all.sh` exit 0.

### VERIF-T10: Pre-verify mechanical claims before spawning auditors -- PASS

- [x] AC1: `skills/audit-srd/SKILL.md` gains step `3a`, positioned after the step-3 version-drift check and before the step-4 auditor spawn. (Numbered in the file's existing `8a`/`9a` sub-step convention.)
- [x] AC2: Enumerates all four claim classes -- file/path existence, `file:line` anchors, requirement counts by priority, and version strings -- each as its own bullet with the mechanism.
- [x] AC3: States the verification is done by the dispatching skill itself with `grep`/`ls`/`jq`, "no new binary, no new state field, no new gate" -- verbatim.
- [x] AC4: The launch template passes the facts in a block titled exactly `Established facts -- do not re-derive`, in both skills.
- [x] AC5: The template instructs the auditor not to spend turns re-deriving, and to "report it as a finding rather than silently trusting the supplied value".
- [x] AC6: `skills/audit-tickets/SKILL.md` gains the equivalent step `3a` with all four pack-specific claims -- epic file existence, ticket count, `Target Components` path existence, and `Depends On` targets resolving to real ticket IDs. Both lanes receive the identical block.
- [x] AC7: Both skills state that a failed mechanical claim is itself recorded as a finding (`audit-srd.md` / `audit.md`) and is "**not** silently corrected before the auditors run". Both also fence the step to mechanical claims only, never a judgment call -- the guard the Technical Notes asked for.
- [x] AC8: `grep -c 'Established facts'` = 2 in audit-srd, 3 in audit-tickets.
- [x] AC9: `edm-check-grants` exit 0 (run) -- the launch-template scan sees the new block.
- [x] AC10: `edm-check-skill-sync` exit 0 (run).
- [x] AC11: `run-all.sh` exit 0.

Landed after T05/T06 as `Depends On` required, so the step numbering is applied against the
post-sentinel step list; the two skills' wording is parallel, as the Technical Notes asked.

### VERIF-T11: Ship 3.2.2 in both manifests and the changelog -- FAIL

- [x] AC1: `jq -r '.version' plugins/edm/.claude-plugin/plugin.json` -> `3.2.2`.
- [x] AC2: `jq -r '.plugins[] | select(.name=="edm") | .version' .claude-plugin/marketplace.json` -> `3.2.2`.
- [x] AC3: Compared programmatically, not by eye -- `wave7-smoke.sh:1282-1288` (`T64 AC1`) and `:9136-9150` (`CA-431`) both `jq` the two files and `fail` on mismatch, which moves the suite's exit code. T11 additionally de-literalized `T64 AC1`'s hardcoded version string into a comparison against `CHANGELOG.md`'s own top heading (`:1296-1303`), retiring a pin that had been hand-edited on four consecutive releases.
- [ ] AC4: Marketplace `description` re-read against the actual skill and agent set, updated if inaccurate, **and the commit body states explicitly that it was checked either way** -- **FAIL**: `git show cb69970 -- .claude-plugin/marketplace.json` changes only the `version` line; the description is untouched. The commit body (five paragraphs) covers the version drift, the changelog entry, the undated `[3.2.1]` heading and the `T64 AC1` de-literalization, and says nothing about the description. The AC's "either way" clause is precisely what makes a no-op auditable, and it is unmet.
- [x] AC5: `plugins/edm/CHANGELOG.md:7` -- `## [3.2.2] -- 2026-08-31`, dated, immediately above `## [3.2.1]`.
- [x] AC6: The entry lists all six required items -- sentinel contract (T01), the four verifier prompt changes (T02/T05/T06/T07, each named with its marker and form), the four consumer checks (T03/T05/T06/T07, each named by skill), `bin/edm-check-verifier-sentinel`, the `maxTurns` 25 -> 50 raise, and the pre-verification step.
- [x] AC7: A dedicated `### Not done (deliberately)` section names all three -- proportional auditor fan-out, producer budget raises (with the "raising both sides preserves the gap" reasoning), and the eleven lenses' `maxTurns: 30`.
- [x] AC8: The ordering constraint is stated in one sentence: "Landed only after the sentinel contract above -- a higher budget makes truncation rarer but never reveals when it still happens, so raising it first would have made the remaining truncations harder to notice rather than safer."
- [x] AC9: `claude plugin validate plugins/edm/` -- exit 0.
- [x] AC10: `run-all.sh` exit 0.
- [x] AC11: Commit `cb69970` subject uses the gitmoji shortcode `:bookmark:` (no Unicode emoji anywhere in the message) and carries no AI attribution trailer. The staging method is not recoverable from git history; the observable proxy holds -- the commit contains exactly five intentional paths and no swept-in unrelated files.

**Finding**:
- [P2] VERIF-T11 | .claude-plugin/marketplace.json:34 (commit cb69970 body) | AC#4: The `edm` marketplace description was neither updated nor recorded as checked. On inspection it remains substantively accurate (six-phase process, HITL gates, parallel waves, automatic QC, 11-lens audit -- all still true of the 14 skills and 30 agents the entry lists), so no content change is required; what is missing is the explicit statement in the commit body. Remedy: state it in the next release commit body, or amend a note to `decisions.md`. Separately noted, not an AC: that description string contains an em dash and two Unicode arrows, which the repo-root `CLAUDE.md` entry mirrors -- pre-existing and explicitly out of T11's scope.

Scope observation, not a defect: `cb69970` also touched the repo-root `CLAUDE.md` (the `v3.2.0`
reference, now `3.2.2`) and `wave7-smoke.sh`, both beyond T11's declared `Target Components`. Both
are justified in the commit body and both are version-site corrections consistent with D6, so I
record them as deliberate scope expansion rather than drift.

---

## Gap raised for judgment: a shard that is never written at all

**Verdict: real gap, correctly outside this epic's scope, P1 as a follow-up.**

Judged on the source. `skills/implement/SKILL.md:129` iterates
`for shard_file in qc-shard-impl-*.md AND qc-shard-pass-*.md`. A shard that was never created does
not match the glob, so the loop body never runs for it, every shard that does exist passes, and
`:136` merges. With zero shards on disk the loop iterates zero times and the merge still proceeds.
Nothing anywhere in the path compares the number of shards found against the number of implementers
dispatched.

This is not a defect in any VERIF ticket. No AC in the epic mentions shard *count* or expected-set
completeness, and the sentinel contract cannot close it by construction: the sentinel is an
artifact-level property, and a file that does not exist has no last line to check. `CLAUDE.md:346`
("The consumer checks `tail -1` of the artifact") is scoped to artifacts that exist. So this is a
gap in the *fix's coverage*, not a failure to implement the fix -- correctly graded as a new
finding rather than a FAIL against T03.

Severity P1, on three grounds. It is the same failure class the initiative exists to close --
silent under-coverage merged as complete -- reached by a different mechanism. It is strictly worse
than the truncation case, because a truncated shard at least leaves partial evidence on disk while
a missing one leaves none. And it is not hypothetical: it is what happened here. The `SubagentStop`
hook never fired for this initiative, zero shards were produced, and nothing detected that -- the
absence was noticed by a human, which is exactly the dependency the initiative set out to remove.

The remedy is small and belongs in `/edm:implement`'s merge step, alongside the check T03 added:
the dispatcher knows how many implementers it launched and with what ticket ranges, so it can
assert that the set of shards found covers the set of ranges dispatched, and refuse the merge by
the same all-or-nothing rule when it does not. Recording the expected shard set in state at spawn
time would make it checkable after a crash as well. That is a new ticket, not a widening of T03.

A second-order observation from the same incident, worth one line: I was executing from the
installed plugin cache at 3.2.1, where `edm-qc-auditor` still carries `maxTurns: 25`. VERIF-T09's
raise is real in the repo and correctly scoped, but it does not take effect for any agent until the
plugin is reinstalled. Nothing in the initiative claims otherwise; it is a deployment property,
not a defect.

---

## Remediation Required

Prioritized. PARTIAL findings are not listed because this shard produced none.

1. **[P1] `plugins/edm/bin/edm-check-verifier-sentinel:121-125` -- the count arm can be defeated by
   the artifact it polices.** Invert the precedence to explicit `[expected-count]` argument first,
   then `assigned=`, then the `range=` span; and refuse (exit 2) when `assigned=` is present but
   below a parseable `T{a}-T{b}` span, since an internally inconsistent sentinel is malformed
   rather than authoritative. Today `range=T01-T08 assigned=1 audited=1` exits 0 both with and
   without an explicit count of 8. Add both cases to `wave7-smoke.sh`'s VERIF-T04 block; neither is
   covered by the existing six fixtures. Fixing the script alone is insufficient -- `CLAUDE.md:336-337`
   currently instructs the opposite, so item 2 must land with it.

2. **[P2] `plugins/edm/CLAUDE.md:315, :336-337, :362-369` -- canonical grammar and refusal condition
   (b) diverge from VERIF-T01 AC2/AC6.** Decide the direction explicitly rather than leaving the
   epic and the code disagreeing: either amend T01 AC2/AC6 and T02/T05/T06/T07 AC1 to the
   three-field grammar and add a `decisions.md` D7 row recording why `assigned=` was introduced, or
   remove `assigned=` and derive the count from `range=` as specified. The first is almost certainly
   right -- an explicit dispatcher-supplied count is better design than parsing a label -- but it is
   currently an undocumented variance across six ACs.

3. **[P2] `plugins/edm/skills/test-coverage/SKILL.md:74-77` -- refused coverage can persist in
   state.** Have Step 2a invalidate the state entries for a refused file's layers/epic, or move the
   `record-test-coverage` call out of the agent and into the skill after the sentinel check passes.
   As written the consumer can only annotate what the producer already wrote, which is the one
   place the initiative's own "the prompt asks, the consumer refuses" asymmetry is not achieved.

4. **[P2] `cb69970` commit body -- VERIF-T11 AC4's description check is unrecorded.** State it in
   the next release commit body or in `decisions.md`. No content change to the description is
   needed; it is still accurate.

5. **[P2] `plugins/edm/CLAUDE.md:298-299` -- missing blank line before the new `##` heading.**
   One-character fix, no AC attached.

**New finding, not a remediation of any ticket**: the never-written-shard gap above (P1) needs its
own ticket in a follow-up fix-pack. It is out of scope for every AC in this epic.

## Process note

No `SubagentStop`-spawned QC shard exists for this initiative -- the hook that normally produces
`qc/qc-shard-impl-*.md` after each `edm-implementer` did not fire, so this manually-dispatched
shard is the only QC artifact. `qc/` did not exist before this run. Worth noting because the
`hooks.json` path is the one that is unwatched by design, and its silent non-firing is the gap
analyzed above.

<!-- QC-SHARD-COMPLETE range=T01-T11 assigned=11 audited=11 -->
