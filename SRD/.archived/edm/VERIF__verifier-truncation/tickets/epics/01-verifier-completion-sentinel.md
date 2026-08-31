# Epic 01 -- Verifier completion sentinel and budget parity

Source: `analysis.md` (fix-pack, no SRD). Target release: EDM 3.2.2.

All paths in `Target Components` are relative to the repository root
(`/Users/darryl.porter/projects/marketplace`).

---

## VERIF-T01: Specify the verifier completion-sentinel contract

| Field | Value |
|---|---|
| Epic | verifier-completion-sentinel |
| Phase | 1 |
| Priority | Must Have |
| Size | XS |
| Analysis Refs | Fix 1 -- completion sentinel; Affected files: `CLAUDE.md` |
| Depends On | -- |
| Target Components | plugins/edm/CLAUDE.md |

### Description

Four verifier agents and four consumers have to agree on one byte-level string, or the check is
worthless: an agent that emits a slightly different marker than the consumer greps for produces
exactly the silent-pass this initiative exists to remove, only now with a check in place giving
false assurance. This ticket writes the contract down once, in the plugin's conventions file, so
every subsequent ticket cites one authority instead of re-deriving the grammar.

The contract is deliberately minimal: a single-line HTML comment, an artifact-specific marker
token, and two key-value fields. It carries no timestamp, no agent name, no host metadata --
anything a truncated agent could plausibly emit early is excluded by construction.

This is a documentation ticket. It changes no behaviour on its own, and nothing in the plugin
reads this section at runtime. Its value is that VERIF-T02 through VERIF-T07 are then editing four
prompts and four consumers against a fixed target rather than against each other.

### Acceptance Criteria

- [ ] AC1: `plugins/edm/CLAUDE.md` gains a section headed exactly `## Verifier completion sentinel (canonical)`.
- [ ] AC2: The section defines the grammar as a single-line HTML comment: `<!-- {MARKER}-COMPLETE range={ASSIGNMENT} audited={N} -->`, ASCII only, one space either side of the comment delimiters, no line continuation.
- [ ] AC3: The section enumerates all four markers and the artifact each terminates -- `QC-SHARD-COMPLETE` (`qc/qc-shard-impl-*.md` and `qc/qc-shard-pass-*.md`), `SRD-AUDIT-COMPLETE` (`edm-srd-auditor` returned text), `TICKET-AUDIT-COMPLETE` (`edm-ticket-auditor` returned text), `TEST-COVERAGE-COMPLETE` (`test-coverage.md` and any `test-coverage-{epic}.md`).
- [ ] AC4: The section states that `range=` names the assignment the dispatcher handed the agent and contains no whitespace, and that `audited=` is a base-10 count of the units that agent actually covered.
- [ ] AC5: The section states that the consumer checks `tail -1` and nothing else, and gives the reason: a truncated agent cannot emit a trailing line it never reached, so a sentinel found anywhere other than the last line proves nothing and must be rejected.
- [ ] AC6: The section names both refusal conditions the consumer enforces -- (a) the last line does not carry the marker, (b) `audited=` is below the count implied by `range=` -- and states that both refuse loudly, naming the offending artifact path.
- [ ] AC7: The section states the check introduces no binary beyond the existing `bash`, `jq`, `git` contract, and is bash 3.2 compatible.
- [ ] AC8: `grep -c 'QC-SHARD-COMPLETE' plugins/edm/CLAUDE.md` returns at least 1, and the same for the other three marker tokens.
- [ ] AC9: `bash plugins/edm/bin/edm-check-vocabulary` exits 0.
- [ ] AC10: `bash plugins/edm/bin/tests/run-all.sh` exits 0.

### Technical Notes

Place the new section adjacent to `## Mermaid diagram conventions (canonical)` and
`## Severity vocabulary (canonical)` -- it is the same kind of cross-agent contract. Do **not** add
it to `edm-sync-canonical-sections`' generated set (`docs/canonical-sections.md`) in this ticket:
that generator has a byte-identical `--check` mode and adding a third section to it is a separate
change with its own regression surface. The four agent prompts get the literal string inlined
(VERIF-T02, T05, T06, T07) rather than a by-name reference, precisely because
`plugins/edm/CLAUDE.md Sec."..."` is known not to resolve from an installed plugin cache
(D22, recorded in `plugins/edm/CLAUDE.md`).

ASCII-only: write `->` not an arrow, `--` not an em dash.

### Out of Scope

Any executable check (VERIF-T03), any agent prompt edit (VERIF-T02/T05/T06/T07), any `maxTurns`
change (VERIF-T09), and adding the section to `docs/canonical-sections.md`.

---

## VERIF-T02: Emit the QC completion sentinel as the shard's final line

| Field | Value |
|---|---|
| Epic | verifier-completion-sentinel |
| Phase | 1 |
| Priority | Must Have |
| Size | S |
| Analysis Refs | Part 1 -- a truncated verifier is silent; Affected files: `agents/edm-qc-auditor.md` (sentinel half) |
| Depends On | VERIF-T01 |
| Target Components | plugins/edm/agents/edm-qc-auditor.md |

### Description

`edm-qc-auditor` is the dangerous instance. It is auto-spawned by the `SubagentStop` hook matching
`edm-implementer` (`plugins/edm/hooks/hooks.json:111-121`), writes a verdict shard, and no human
watches it run. Its shard is merged into `qc/qc-summary.md` as-is. A shard truncated at turn 25
today is indistinguishable from a finished one, which is how a ticket gets recorded PASS because
the auditor ran out of turns before reaching its acceptance criteria.

This ticket changes the agent's output contract so a finished shard is distinguishable from a
truncated one. The instruction has to be unambiguous that the sentinel is the file's **final
line** -- an agent that is merely told to "include the sentinel" may write it into the header, and
a sentinel in the header is emitted before the work happens and therefore proves nothing.

The agent's `maxTurns` is deliberately left at 25 here. VERIF-T09 raises it, after the whole of
Fix 1 has landed.

### Acceptance Criteria

- [ ] AC1: The `## Output Format` block in `plugins/edm/agents/edm-qc-auditor.md` ends with the literal line `<!-- QC-SHARD-COMPLETE range={T-first}-{T-last} audited={N} -->`.
- [ ] AC2: The prompt states, in imperative form, that this line is the **final line of the file**, that nothing may be written after it, and that being present somewhere in the file is not sufficient.
- [ ] AC3: The prompt explicitly forbids writing the sentinel before the audit is finished (no writing it into the header, no writing it as a placeholder to be filled in later).
- [ ] AC4: The prompt states what happens when the sentinel is absent -- `/edm:implement` refuses the shard and the auditor is re-run -- and states that this refusal is the intended behaviour, not an error to be worked around.
- [ ] AC5: `range=` is specified as the assigned **ticket** range (`T{first}-T{last}`) for both shard kinds, explicitly independent of the `qc-shard-pass-w{WW}-{NN}.md` filename's wave/ordinal components.
- [ ] AC6: `audited=` is specified as the number of tickets carrying a verdict row in the shard's own `## Summary` table.
- [ ] AC7: `grep -c 'QC-SHARD-COMPLETE' plugins/edm/agents/edm-qc-auditor.md` returns at least 1, and `grep -ci 'final line' plugins/edm/agents/edm-qc-auditor.md` returns at least 1.
- [ ] AC8: `git diff plugins/edm/agents/edm-qc-auditor.md` shows no change to any YAML frontmatter key -- `maxTurns` still reads `25`, `tools`, `model`, `effort`, `color` and `disallowedTools` unchanged.
- [ ] AC9: `bash plugins/edm/bin/edm-check-grants` exits 0.
- [ ] AC10: The file is ASCII-only (no em dash, no arrow glyph, no smart quote, no emoji).
- [ ] AC11: `bash plugins/edm/bin/tests/run-all.sh` exits 0.

### Technical Notes

This file is prompt text, not code, so "the agent reliably emits the sentinel" is not statically
verifiable and is **not** what the ACs above assert. What is verifiable, and what is asserted, is
that the instruction exists and is unambiguous about the final-line requirement. The enforcement
that makes a missed sentinel harmless lives on the consumer side (VERIF-T03) -- that asymmetry is
the design: the prompt asks, the consumer refuses.

Both shard filename namespaces (`qc-shard-impl-*` and `qc-shard-pass-*`) get the same sentinel.
Do not tie the sentinel's `range=` to the filename -- CA-473 and CA-515 already made the two
filename namespaces carry different keys, and coupling `range=` to the filename would reintroduce
that confusion inside the sentinel.

Follow the plugin's before/after-with-rationale contribution convention: this is a prompt-text
change and the diff is the only reviewable artifact.

### Out of Scope

The merge-side check (VERIF-T03), the other three verifiers (VERIF-T05/T06/T07), the `maxTurns`
raise (VERIF-T09), and any change to the verdict semantics or the shard filename conventions.

---

## VERIF-T03: Refuse incomplete QC shards at the qc-summary merge step

| Field | Value |
|---|---|
| Epic | verifier-completion-sentinel |
| Phase | 1 |
| Priority | Must Have |
| Size | M |
| Analysis Refs | Fix 1 -- completion sentinel; Acceptance 1 and 2; Affected files: `skills/implement/SKILL.md` |
| Depends On | VERIF-T01, VERIF-T02 |
| Target Components | plugins/edm/bin/edm-check-verifier-sentinel (new), plugins/edm/skills/implement/SKILL.md, plugins/edm/CLAUDE.md |

### Description

This is the ticket that closes the defect. `/edm:implement` merges every
`qc/qc-shard-impl-*.md` and `qc/qc-shard-pass-*.md` into `qc/qc-summary.md` after a wave drains
(`plugins/edm/skills/implement/SKILL.md:39`, and the merge pseudo-code at `:96-127`), with no
completeness check anywhere in that path. After this ticket, a shard that cannot prove it finished
does not enter the merge, and the merge says so by name.

The check is implemented as a real executable, `bin/edm-check-verifier-sentinel`, rather than as a
bash snippet embedded in the skill's prose. Prose cannot be negative-tested, and the analysis
requires a negative test that fails if the check is removed (Acceptance 4). This follows the
existing CA-436 precedent, where the inline `PreToolUse` hook one-liner was extracted into
`bin/edm-lint-staged-artifacts` for exactly this reason.

Two refusal conditions, not one. The missing sentinel catches truncation. The `audited=` count
below the count implied by `range=` catches the clean-but-incomplete case -- an auditor that
terminates normally having covered six of eight assigned tickets -- which completion alone misses
entirely and which is easy to drop from a fix that only thinks about truncation.

### Acceptance Criteria

- [ ] AC1: New executable `plugins/edm/bin/edm-check-verifier-sentinel` exists, is `chmod +x`, starts `#!/usr/bin/env bash`, sets `set -euo pipefail`, and runs under bash 3.2 (no associative arrays, no `${var^^}`, no `mapfile`).
- [ ] AC2: Usage is `edm-check-verifier-sentinel <MARKER> <file> [expected-count]`; it invokes no binary outside `bash`, `grep`, `sed`, and `tail` (verifiable by reading the script -- no `jq`, `python`, `awk`-only constructs, or anything off the `bash`/`jq`/`git` contract).
- [ ] AC3: Exit contract matches `edm-lint-staged-artifacts`: `0` = complete, `2` = refusal, `1` = usage or setup error. `edm-check-verifier-sentinel` with no arguments exits 1 and prints usage.
- [ ] AC4: Missing-sentinel refusal -- when `tail -1 <file>` does not match `^<!-- {MARKER}-COMPLETE `, the script exits 2 and prints to stderr a message containing the file path and the word `truncated`.
- [ ] AC5: Last-line-only property -- a file carrying a well-formed sentinel on any line other than the last is refused exactly as in AC4. The script reads only the last line; it never scans the file body for the marker.
- [ ] AC6: Short-count refusal -- when the last line carries the marker but `audited=N` is less than the count implied by `range=` (inclusive span of `T{a}-T{b}`, or the explicit `[expected-count]` argument when supplied), the script exits 2 and prints a message naming the file, the audited count, and the expected count.
- [ ] AC7: A malformed sentinel (marker present but `range=` or `audited=` missing, or `audited=` non-numeric) is refused with exit 2, not accepted and not treated as a usage error.
- [ ] AC8: `plugins/edm/skills/implement/SKILL.md`'s merge step runs the script over every `qc/qc-shard-impl-*.md` and every `qc/qc-shard-pass-*.md` **before** any content is written to `qc/qc-summary.md`.
- [ ] AC9: When any shard refuses, `qc/qc-summary.md` is neither created nor overwritten -- the merge is all-or-nothing, and no partially-merged summary is left on disk.
- [ ] AC10: The skill text states the operator remedy verbatim: re-run `edm-qc-auditor` for the named shard range, then re-run the merge.
- [ ] AC11: `plugins/edm/CLAUDE.md`'s `bin/` helper-script table gains a row for `edm-check-verifier-sentinel` describing its purpose and its 0/1/2 exit contract.
- [ ] AC12: `bash plugins/edm/bin/tests/run-all.sh` exits 0.

### Technical Notes

Count parsing without new binaries, bash 3.2 safe:

```bash
last="$(tail -1 "$file")"
case "$last" in
  "<!-- ${marker}-COMPLETE "*) : ;;
  *) printf '%s: truncated -- no %s sentinel on the last line\n' "$file" "$marker" >&2; exit 2 ;;
esac
audited="$(printf '%s\n' "$last" | sed -n 's/.*audited=\([0-9][0-9]*\).*/\1/p')"
```

An empty `audited` after the `sed` is the malformed case (AC7), not a zero.

The expected count derives from `range=`: for a `T{a}-T{b}` range it is `b - a + 1`, computed with
`$(( ))` after stripping the leading `T` and any leading zeros (`10#` prefix -- `08` is not a valid
octal literal and would fail arithmetic expansion otherwise, on both macOS bash 3.2 and Linux bash
5). For a non-ticket `range=` (the `structural` lane, a section group), the caller supplies
`[expected-count]` explicitly; when it supplies neither a parseable range nor an argument, the
script checks presence only and says so on stderr rather than silently skipping the count arm.

The merge step in `skills/implement/SKILL.md` is prose plus pseudo-code, so the AC8/AC9 edits are
prompt-text edits that name the script by bare name -- `bin/` is on PATH while the plugin is
enabled, matching how every other skill calls `edm-state`.

Do not add this script to `bin/tests/run-all.sh`'s standalone-check set. It is a per-initiative
runtime check with required arguments, not a repo-wide checker like `edm-check-grants`; its
regression coverage is VERIF-T04's cases inside `wave7-smoke.sh`.

### Out of Scope

The tests for this script (VERIF-T04). The other three consumers (VERIF-T05/T06/T07). Any change
to the shard filename namespaces, the verdict rollup, or `record-partial-verdict`. Detecting
truncation by any means other than the trailing sentinel.

---

## VERIF-T04: Negative smoke tests for both QC refusal paths

| Field | Value |
|---|---|
| Epic | verifier-completion-sentinel |
| Phase | 1 |
| Priority | Must Have |
| Size | M |
| Analysis Refs | Fix 1 -- "Negative test required"; Acceptance 4 and 5; Affected files: `bin/tests/wave7-smoke.sh` |
| Depends On | VERIF-T03 |
| Target Components | plugins/edm/bin/tests/wave7-smoke.sh |

### Description

The analysis states the standard plainly: a fix whose failure path is untested is the same class of
defect as the one being fixed. This ticket makes both refusal paths regression-proof, and makes the
assertions themselves provably load-bearing.

A positive control that still passes when the check is deleted is worthless, and EDMV3's own open
P2 debt is largely assertions that do not prove what they claim. So the suite does not merely
assert "stripped fixture is refused" -- it also mutates a copy of `edm-check-verifier-sentinel`
with the sentinel check removed and asserts that the mutated copy **accepts** the stripped fixture.
If the mutated copy still refuses, the refusal is coming from somewhere other than the check and
the suite fails with a named message.

There is no CI pipeline for this plugin. `bin/tests/run-all.sh` and the git-commit hook are the
entire enforcement surface, so an assertion that does not land in a smoke suite is not enforced at
all.

### Acceptance Criteria

- [ ] AC1: Fixture A -- a well-formed shard ending `<!-- QC-SHARD-COMPLETE range=T01-T08 audited=8 -->` -- makes `edm-check-verifier-sentinel QC-SHARD <fixture>` exit 0.
- [ ] AC2: Fixture B -- byte-identical to A with the final sentinel line deleted -- makes the script exit 2, and stderr contains fixture B's path and the word `truncated`.
- [ ] AC3: Fixture C -- the sentinel present but followed by one further line of report text -- makes the script exit 2, proving the check is `tail -1` and not a whole-file scan.
- [ ] AC4: Fixture D -- `range=T01-T08 audited=6` on the last line -- makes the script exit 2, and stderr contains both `6` and `8`.
- [ ] AC5: Fixture E -- `range=T01-T08 audited=8` -- exits 0, so the count arm is shown to distinguish short from complete rather than refusing everything.
- [ ] AC6: Fixture F -- last line `<!-- QC-SHARD-COMPLETE -->` with no `range=` or `audited=` -- exits 2 (malformed, not accepted).
- [ ] AC7: Mutation guard for the truncation arm -- the suite copies the script to `$TMP`, removes the last-line marker check from the copy, and asserts the copy exits 0 on fixture B. If the mutated copy still exits 2, the suite fails with a message naming the mutation guard.
- [ ] AC8: Mutation guard for the count arm -- same technique against fixture D: with the count comparison removed, the copy must exit 0.
- [ ] AC9: Every fixture is created under the suite's existing `$TMP` and removed by its existing four-arm trap. `git status --porcelain` is clean after a run.
- [ ] AC10: All new assertions go through the shared `_harness.sh` counters, so a failure fails the suite's exit code rather than only printing.
- [ ] AC11: `bash plugins/edm/bin/tests/wave7-smoke.sh` exits 0 and its printed assertion count increases by the number of cases added.
- [ ] AC12: `bash plugins/edm/bin/tests/run-all.sh` exits 0. The suite performs no network access and no writes outside `$TMP`.

### Technical Notes

The mutation guards (AC7, AC8) are the point of this ticket. Implement them by `sed`-deleting the
specific check lines from a copy under `$TMP` and running the copy -- never by editing the real
script in place, and never by setting an environment variable that disables the check (a disable
knob would itself become a bypass in production).

Group the new cases under a banner comment naming the ticket, in the style of wave7's existing
`G25/CA-342:` banner, so a future reader can find the whole block.

bash 3.2: use `printf`, not `echo -e`. Use `$(...)`, not backticks. `mktemp -d` with an explicit
template, as the suite already does.

### Out of Scope

Prompt-text assertions across the four agent files (VERIF-T08). `maxTurns` assertions (VERIF-T09).
Any change to `edm-check-verifier-sentinel` itself -- if a test reveals a defect, fix it under
VERIF-T03 rather than widening this ticket.

---

## VERIF-T05: Terminate edm-srd-auditor findings with a sentinel and check it in /edm:audit-srd

| Field | Value |
|---|---|
| Epic | verifier-completion-sentinel |
| Phase | 2 |
| Priority | Must Have |
| Size | S |
| Analysis Refs | Fix 1 (returned-text form); Affected files: `agents/edm-srd-auditor.md`, `skills/audit-srd/SKILL.md` (sentinel half) |
| Depends On | VERIF-T01, VERIF-T03 |
| Target Components | plugins/edm/agents/edm-srd-auditor.md, plugins/edm/skills/audit-srd/SKILL.md |

### Description

`edm-srd-auditor` returns text to an orchestrating skill rather than writing a file, so its
truncation is in principle visible. In practice it is not checked: `skills/audit-srd/SKILL.md:44`
compiles findings from all agents into `audit-srd.md` with no completeness test, so the same
consumed-as-complete hazard applies. This is not hypothetical -- during EDMV4 Phase 3 all three
`edm-srd-auditor` agents hit the 25-turn ceiling before emitting a single finding.

The returned-text form of the sentinel terminates the findings block, and the compile step checks
the last non-empty line of each returned block before compiling it.

### Acceptance Criteria

- [ ] AC1: `plugins/edm/agents/edm-srd-auditor.md`'s output contract ends with the literal line `<!-- SRD-AUDIT-COMPLETE range={section-group} audited={N} -->`.
- [ ] AC2: The prompt states the sentinel is the **final line of the returned text**, that nothing follows it, and that presence elsewhere in the response does not satisfy the contract.
- [ ] AC3: The prompt forbids emitting the sentinel before the audit is complete.
- [ ] AC4: `range=` is specified as the assigned section group with no whitespace (for example `S1-S4`); `audited=` is the number of SRD sections the agent actually covered.
- [ ] AC5: `skills/audit-srd/SKILL.md` step 5 (compile) checks the last non-empty line of each returned block for `SRD-AUDIT-COMPLETE` before that block is compiled into `${INIT_DIR}/audit-srd.md`.
- [ ] AC6: A returned block failing that check is **not** compiled; the skill names the agent's assigned section group and re-dispatches (resume) that agent, and the skill text says so explicitly.
- [ ] AC7: Short-count refusal -- when `audited=` is below the number of sections that agent was assigned, the block is refused by the same path as AC6.
- [ ] AC8: The skill text states that a truncated auditor's partial findings must never be treated as that section group's audit result, and that Gate 2 must not be presented while any block is outstanding.
- [ ] AC9: `grep -c 'SRD-AUDIT-COMPLETE' plugins/edm/agents/edm-srd-auditor.md` and `grep -c 'SRD-AUDIT-COMPLETE' plugins/edm/skills/audit-srd/SKILL.md` each return at least 1.
- [ ] AC10: `git diff plugins/edm/agents/edm-srd-auditor.md` shows no frontmatter change -- `maxTurns` still reads `25`.
- [ ] AC11: `bash plugins/edm/bin/edm-check-grants` and `bash plugins/edm/bin/edm-check-skill-sync` both exit 0.
- [ ] AC12: `bash plugins/edm/bin/tests/run-all.sh` exits 0.

### Technical Notes

The returned-text form cannot use `bin/edm-check-verifier-sentinel` directly -- there is no file to
`tail`. The skill's check is therefore prose instructing the orchestrating skill to inspect the last
non-empty line of the returned block. Mirror VERIF-T03's refusal wording and its two conditions so
the two forms read as one contract, not two.

`skills/audit-srd/SKILL.md` is also touched by VERIF-T10 (the pre-verification step). Land this
ticket first -- both edits are in the same file's `## Operational Orchestration` list and merging
them in the other order forces a rebase for no benefit.

Keep the section-group notation consistent with what the skill already dispatches at step 4
("sections 1-4, 5-7, 8-11").

### Out of Scope

The ticket auditor and the coverage auditor (VERIF-T06, VERIF-T07). The pre-verification step
(VERIF-T10). The `maxTurns` raise (VERIF-T09). Changing how many `edm-srd-auditor` agents are
spawned -- proportional fan-out is explicitly deferred.

---

## VERIF-T06: Terminate edm-ticket-auditor findings with a sentinel and check it in /edm:audit-tickets

| Field | Value |
|---|---|
| Epic | verifier-completion-sentinel |
| Phase | 2 |
| Priority | Must Have |
| Size | S |
| Analysis Refs | Fix 1 (returned-text form); Affected files: `agents/edm-ticket-auditor.md`, `skills/audit-tickets/SKILL.md` |
| Depends On | VERIF-T01, VERIF-T03 |
| Target Components | plugins/edm/agents/edm-ticket-auditor.md, plugins/edm/skills/audit-tickets/SKILL.md |

### Description

`/edm:audit-tickets` spawns exactly two `edm-ticket-auditor` agents in parallel, one structural and
one content-quality (`plugins/edm/skills/audit-tickets/SKILL.md:43`), then compiles both lanes into
`tickets/audit.md` at step 5 with no completeness check. A truncated lane produces a ticket-pack
audit that silently covers one lane and part of another, and Gate 3 is presented on it.

The two lanes need distinguishable `range=` values, because both lanes audit the whole pack: the
lane name is the assignment, and `audited=` is the ticket count that lane actually reached.

### Acceptance Criteria

- [ ] AC1: `plugins/edm/agents/edm-ticket-auditor.md`'s output contract ends with the literal line `<!-- TICKET-AUDIT-COMPLETE range={lane} audited={N} -->`.
- [ ] AC2: The prompt states the sentinel is the **final line of the returned text**, that nothing follows it, and that presence elsewhere does not satisfy the contract.
- [ ] AC3: The prompt forbids emitting the sentinel before the audit is complete.
- [ ] AC4: `range=` is specified as the lane identifier, exactly `structural` or `content-quality`, matching the lane tags the skill already applies to findings at step 5.
- [ ] AC5: `audited=` is specified as the number of tickets in the pack that lane actually graded.
- [ ] AC6: `skills/audit-tickets/SKILL.md` step 5 checks the last non-empty line of each lane's returned block before compiling into `${INIT_DIR}/${user_config.ticket_pack_dirname}/audit.md`.
- [ ] AC7: A lane failing that check is not compiled; the skill names the lane and re-dispatches it, and refuses to de-duplicate or present partial results as a completed two-lane audit.
- [ ] AC8: Short-count refusal -- when a lane's `audited=` is below the pack's ticket count, that lane is refused by the same path as AC7.
- [ ] AC9: The skill text states that Gate 3 must not be presented while either lane is outstanding.
- [ ] AC10: `grep -c 'TICKET-AUDIT-COMPLETE' plugins/edm/agents/edm-ticket-auditor.md` and the same over `plugins/edm/skills/audit-tickets/SKILL.md` each return at least 1.
- [ ] AC11: `git diff plugins/edm/agents/edm-ticket-auditor.md` shows no frontmatter change -- `maxTurns` still reads `25`.
- [ ] AC12: `bash plugins/edm/bin/tests/run-all.sh` exits 0.

### Technical Notes

The pack's ticket count for AC8 is what the skill already dispatches with -- do not add a new
counting mechanism; reuse the count the launch template already computes when assigning lanes.

The two-lane mandatory spawn is unchanged: still exactly two agents, never serial, never merged.
This ticket adds a completeness check to what those two return, nothing more.

Keep the refusal wording identical in shape to VERIF-T05's, so a reader of either skill recognizes
the same contract.

### Out of Scope

The pre-verification step (VERIF-T10) even though it touches the same file. Any change to lane
definitions, the two-lane spawn count, or the de-duplication rule. The `maxTurns` raise.

---

## VERIF-T07: Sentinel-terminate test-coverage.md and check it in /edm:test-coverage

| Field | Value |
|---|---|
| Epic | verifier-completion-sentinel |
| Phase | 2 |
| Priority | Must Have |
| Size | S |
| Analysis Refs | Fix 1 (file form); Affected files: `agents/edm-test-coverage-auditor.md`, `skills/test-coverage/SKILL.md` |
| Depends On | VERIF-T01, VERIF-T03 |
| Target Components | plugins/edm/agents/edm-test-coverage-auditor.md, plugins/edm/skills/test-coverage/SKILL.md |

### Description

`edm-test-coverage-auditor` writes a file, so it uses the same file form as the QC shard and can
reuse `bin/edm-check-verifier-sentinel` unchanged. A truncated coverage audit reports fewer gaps
than exist, and a coverage report that under-reports gaps is read as good news -- the same
silent-failure shape as the QC false PASS, one phase later.

Multi-stack initiatives produce `test-coverage-{epic}.md` per epic plus a top-level summary. Each
of those files is written by its own agent invocation, so each needs its own sentinel and each must
be checked -- checking only the top-level summary would leave the per-epic files unguarded.

### Acceptance Criteria

- [ ] AC1: `plugins/edm/agents/edm-test-coverage-auditor.md`'s output contract ends with the literal line `<!-- TEST-COVERAGE-COMPLETE range={assignment} audited={N} -->` as the final line of every file it writes.
- [ ] AC2: The prompt states the sentinel is the **final line of the file**, that nothing follows it, and that presence elsewhere does not satisfy the contract.
- [ ] AC3: The prompt forbids emitting the sentinel before the coverage audit is complete.
- [ ] AC4: For a single-stack run, `range=` is the initiative's ticket range and `audited=` is the number of acceptance criteria cross-referenced; for a multi-stack run each `test-coverage-{epic}.md` carries `range={epic-slug}` and its own `audited=`.
- [ ] AC5: `skills/test-coverage/SKILL.md` runs `edm-check-verifier-sentinel TEST-COVERAGE <file>` against `${INIT_DIR}/test-coverage.md` after the agent returns and before any downstream consumption.
- [ ] AC6: In the multi-stack case, the skill runs the same check against **every** `test-coverage-{epic}.md` as well as the top-level summary.
- [ ] AC7: On refusal the skill reports the failing path, does not record coverage into state (`edm-state record-test-coverage` is not called for a refused file), and re-dispatches the auditor for that file.
- [ ] AC8: The skill text states that a refused coverage report must not be used to satisfy the Phase 6 "coverage targets met" checklist item.
- [ ] AC9: `grep -c 'TEST-COVERAGE-COMPLETE' plugins/edm/agents/edm-test-coverage-auditor.md` and `grep -c 'edm-check-verifier-sentinel' plugins/edm/skills/test-coverage/SKILL.md` each return at least 1.
- [ ] AC10: `git diff plugins/edm/agents/edm-test-coverage-auditor.md` shows no frontmatter change -- `maxTurns` still reads `25`, and `disallowedTools: Edit, NotebookEdit` is preserved.
- [ ] AC11: `bash plugins/edm/bin/tests/run-all.sh` exits 0.

### Technical Notes

AC7 is the one that matters operationally: writing coverage percentages into state from a truncated
report is worse than writing nothing, because `metrics-report` and the Phase 6 checklist then read
a number that was never measured.

`edm-check-verifier-sentinel` is invoked by bare name -- `bin/` is on PATH while the plugin is
enabled. Pass `TEST-COVERAGE` as the marker argument; the script's marker parameter already makes
this reuse work with no script change.

For the multi-stack case the file set is derived from the epic slugs the plan already enumerates.
An epic whose layer set is entirely N/A produces no coverage file at all (absence is
authoritative), so the check must iterate the files that exist rather than asserting one file per
epic.

### Out of Scope

Any change to coverage targets, layer N/A determination, `record-test-coverage`, or the per-epic
filename conventions. The `maxTurns` raise. `/edm:test`'s writer agents.

---

## VERIF-T08: Assert the sentinel instruction in all four verifier prompts

| Field | Value |
|---|---|
| Epic | verifier-completion-sentinel |
| Phase | 2 |
| Priority | Must Have |
| Size | S |
| Analysis Refs | Affected files: `bin/tests/wave7-smoke.sh` (row 1 -- "sentinel present in all four agent prompts") |
| Depends On | VERIF-T02, VERIF-T05, VERIF-T06, VERIF-T07 |
| Target Components | plugins/edm/bin/tests/wave7-smoke.sh |

### Description

The four prompt edits are prose, and prose rots. Once VERIF-T02, T05, T06 and T07 have landed, an
unrelated later edit to any of those four agent files can drop the sentinel instruction with no
signal at all -- the consumers would then refuse every artifact, which is loud, or (worse, for the
returned-text pair) the skill's prose check silently never matches.

This ticket makes the prompt contract machine-checked, in the same suite that already carries the
plugin's other computed-not-asserted-in-prose guards.

### Acceptance Criteria

- [ ] AC1: `wave7-smoke.sh` asserts each of the four agent files contains its own marker token: `edm-qc-auditor.md` -> `QC-SHARD-COMPLETE`, `edm-srd-auditor.md` -> `SRD-AUDIT-COMPLETE`, `edm-ticket-auditor.md` -> `TICKET-AUDIT-COMPLETE`, `edm-test-coverage-auditor.md` -> `TEST-COVERAGE-COMPLETE`.
- [ ] AC2: The suite asserts each of the four files also carries the final-line wording -- a case-insensitive match on `final line` -- so an edit that keeps the marker but drops the positional requirement still fails.
- [ ] AC3: The four markers are asserted distinct from one another, so a copy-paste that gives two agents the same marker fails.
- [ ] AC4: The suite asserts no **other** file under `plugins/edm/agents/` contains a `-COMPLETE ` marker, catching a sentinel pasted into a producer agent where it would be meaningless.
- [ ] AC5: The agent-to-marker mapping is declared once in the suite (a single parallel-array or here-doc table), not restated per assertion.
- [ ] AC6: The assertion body is a function taking a file path and a marker, so it can be run against an arbitrary path.
- [ ] AC7: Negative control -- the suite copies one agent file to `$TMP`, deletes the sentinel line and the final-line wording, calls the AC6 function on the copy, and fails with a named message if the function returns 0.
- [ ] AC8: Each failure message names the offending agent file and which of the two properties (marker, final-line wording) is missing.
- [ ] AC9: `bash plugins/edm/bin/tests/wave7-smoke.sh` exits 0 with the new assertions counted in its summary.
- [ ] AC10: `bash plugins/edm/bin/tests/run-all.sh` exits 0, and `git status --porcelain` is clean afterwards.

### Technical Notes

AC4 is a whole-directory grep with a four-file allowlist. Write the allowlist as filenames, not as
an inverted pattern, so adding a fifth verifier later fails the test loudly and forces a conscious
decision rather than silently passing.

bash 3.2 has no associative arrays -- use two indexed arrays or a `while read` over a here-doc for
AC5's mapping table.

Reuse `_harness.sh`'s counters, as VERIF-T04 does. Place the block under its own banner comment
naming this ticket.

### Out of Scope

Any edit to the four agent files themselves -- if an assertion fails, fix it in the owning ticket
(VERIF-T02/T05/T06/T07). `maxTurns` assertions (VERIF-T09). Consumer-side checks (VERIF-T03/T05/T06/T07).

---

## VERIF-T09: Raise the four verifiers from maxTurns 25 to 50

| Field | Value |
|---|---|
| Epic | verifier-completion-sentinel |
| Phase | 3 |
| Priority | Must Have |
| Size | S |
| Analysis Refs | Part 2 -- verifiers budgeted below producers; Fix 2 -- budget parity; Acceptance 3; Affected files: four `agents/*.md` (maxTurns half), `CLAUDE.md` (inventory column), `bin/tests/wave7-smoke.sh` |
| Depends On | VERIF-T08 |
| Target Components | plugins/edm/agents/edm-srd-auditor.md, plugins/edm/agents/edm-ticket-auditor.md, plugins/edm/agents/edm-qc-auditor.md, plugins/edm/agents/edm-test-coverage-auditor.md, plugins/edm/CLAUDE.md, plugins/edm/bin/tests/wave7-smoke.sh |

### Description

All four read-only verifiers sit at the plugin's floor of 25 turns while the producers whose output
they check get 50 to 60 -- a 2x to 2.4x deficit, despite verification being strictly more work,
since the verifier must read the artifact **and** cross-reference it against the codebase. This is
not a v3 regression: `maxTurns: 25` was set once in `fe5d0f0` and never changed. What v3 added was
scaling guidance on the production side only (`skills/srd/SKILL.md:84` targets "800+ lines major"
for an SRD) against a hard-capped verification side.

Sizing evidence from EDMV4: the auditors logged roughly 2 tool calls per turn, so 50 turns is about
90 to 110 tool calls, which comfortably covered the work once the capped agents were resumed.

**This ticket lands last of the two fixes, deliberately.** A higher budget reduces how often
truncation happens but never reveals when it did. Raising the budget first would make the remaining
truncations rarer and therefore harder to notice -- strictly worse than the status quo for
diagnosis.

### Acceptance Criteria

- [ ] AC1: `grep -c '^maxTurns: 50' plugins/edm/agents/edm-srd-auditor.md` returns 1, and the same for `edm-ticket-auditor.md`, `edm-qc-auditor.md` and `edm-test-coverage-auditor.md`.
- [ ] AC2: None of those four files contains `maxTurns: 25` afterwards.
- [ ] AC3: The eleven `plugins/edm/agents/edm-audit-*.md` lens agents still read `maxTurns: 30` -- asserted by a count, so a stray edit is caught.
- [ ] AC4: No producer's `maxTurns` changes: `edm-implementer` stays 60, and `edm-srd-writer`, `edm-ticket-writer`, `edm-architect` stay 50, asserted explicitly.
- [ ] AC5: `plugins/edm/CLAUDE.md`'s testing-layer agent inventory table shows `50` in the `maxTurns` column for `edm-test-coverage-auditor`.
- [ ] AC6: `plugins/edm/CLAUDE.md` states that the four read-only verifiers run at parity with the writers they check, so a future contributor does not "tidy" them back to the floor.
- [ ] AC7: `wave7-smoke.sh` asserts AC1 through AC4 as computed checks, not as prose.
- [ ] AC8: The AC1 assertion is path-parameterized and is exercised against a temp copy rewritten to `maxTurns: 25`, which must make it return non-zero -- so the assertion demonstrably fails on a revert.
- [ ] AC9: No other frontmatter key changes on any of the four files -- `model`, `effort`, `color`, `tools`, `disallowedTools` are byte-identical before and after.
- [ ] AC10: `claude plugin validate plugins/edm/` exits 0.
- [ ] AC11: `bash plugins/edm/bin/tests/run-all.sh` exits 0.

### Technical Notes

The ordering constraint in the Description is the whole reason this ticket sits behind VERIF-T08
rather than being done first as a one-line change. Do not reorder it for convenience -- with the
sentinel in place the raise is a genuine improvement, and without it the raise is a diagnostic
regression.

AC3 and AC4 exist because this is a four-file `sed`-able change and a careless `find`-and-replace
across `agents/` would sweep the lenses and the producers with it. Assert what must **not** change,
not only what must.

`edm-test-coverage-auditor` is the only one of the four that appears in `CLAUDE.md`'s testing-layer
inventory table; the other three are not in that table and need no row edit there.

### Out of Scope

Raising producer budgets (`edm-srd-writer` capped twice during EDMV4 remediation, but raising both
sides preserves the gap rather than closing it). Any change to the eleven lenses' `maxTurns: 30`
(no evidence of truncation there). Proportional auditor fan-out.

---

## VERIF-T10: Pre-verify mechanical claims before spawning auditors

| Field | Value |
|---|---|
| Epic | verifier-completion-sentinel |
| Phase | 3 |
| Priority | Should Have |
| Size | S |
| Analysis Refs | Fix 3 -- pre-verify mechanical claims; Affected files: `skills/audit-srd/SKILL.md` (pre-verification half), `skills/audit-tickets/SKILL.md` |
| Depends On | VERIF-T05, VERIF-T06 |
| Target Components | plugins/edm/skills/audit-srd/SKILL.md, plugins/edm/skills/audit-tickets/SKILL.md |

### Description

A zero-cost procedural change, observed to work during EDMV4 Phase 3. When the dispatching skill
resumed the capped auditors, it supplied verified ground truth for the cheap mechanical claims --
line numbers, counts, file existence -- and that freed the auditors' remaining turns for judgment
work. Both of Group B's P0 findings came out of that freed budget.

The step costs the dispatcher a handful of greps and saves each auditor the turns it would
otherwise spend re-deriving the same facts, multiplied by the number of auditors spawned. It
complements the budget raise rather than substituting for it: more turns and less waste on
mechanical work are additive.

The established-fact block must not become a new blind spot. The auditors are told to treat the
facts as given **and** to report any discrepancy they happen to observe, rather than silently
trusting a stale line number.

### Acceptance Criteria

- [ ] AC1: `skills/audit-srd/SKILL.md` gains a numbered step in `## Operational Orchestration` that runs after the version-drift check and before the auditor spawn.
- [ ] AC2: That step enumerates the mechanical claims to verify: file and path existence, `file:line` anchors cited in the SRD, requirement counts by priority, and any version string the SRD asserts.
- [ ] AC3: The step states the verification is done with `grep`/`ls`/`jq` by the dispatching skill itself, introducing no new binary, no new state field, and no new gate.
- [ ] AC4: The auditor launch template passes the verified facts in a named block titled `Established facts -- do not re-derive`.
- [ ] AC5: The launch template instructs the auditor not to spend turns re-deriving those facts, and to report any discrepancy it does observe as a finding rather than silently accepting the supplied value.
- [ ] AC6: The equivalent step and launch-template block are added to `skills/audit-tickets/SKILL.md`, with ticket-pack-specific claims: epic file existence, ticket count, `Target Components` path existence, and `Depends On` targets resolving to real ticket IDs.
- [ ] AC7: Both skills state that a failed mechanical claim discovered during pre-verification is itself a finding recorded in the audit report, not something silently fixed before the auditors run.
- [ ] AC8: `grep -c 'Established facts' plugins/edm/skills/audit-srd/SKILL.md` and the same over `plugins/edm/skills/audit-tickets/SKILL.md` each return at least 1.
- [ ] AC9: `bash plugins/edm/bin/edm-check-grants` exits 0 -- the launch-template scan sees the new block.
- [ ] AC10: `bash plugins/edm/bin/edm-check-skill-sync` exits 0 -- each phase skill still owns its own `## Operational Orchestration` section and the dispatcher holds no phase procedure body.
- [ ] AC11: `bash plugins/edm/bin/tests/run-all.sh` exits 0.

### Technical Notes

AC7 matters: pre-verifying a claim and quietly correcting the SRD before the audit runs would hide
the very class of drift the audit exists to catch (audit pattern 4, "File:line references out of
sync", 6 of 16 initiatives). Verify, record, then hand the auditors the corrected fact.

Both target files are also edited by VERIF-T05 and VERIF-T06. Land those first (declared in
`Depends On`) so this ticket's step numbering is applied against the post-sentinel step list.

Keep the two skills' wording parallel. They are read as a pair, and gratuitous divergence between
them is what produces the "which one is authoritative" confusion the intent-to-file index exists to
resolve.

### Out of Scope

Any change to the number of auditors spawned in either skill (still 2-3 for SRD, exactly 2 lanes
for tickets). Proportional fan-out. Automating the pre-verification into a new `bin/` script -- the
analysis specifies a procedural step, and a new script is a larger change than the finding
warrants.

---

## VERIF-T11: Ship 3.2.2 in both manifests and the changelog

| Field | Value |
|---|---|
| Epic | verifier-completion-sentinel |
| Phase | 4 |
| Priority | Must Have |
| Size | XS |
| Analysis Refs | Acceptance 6; Affected files: `CHANGELOG.md`, `.claude-plugin/plugin.json`, `../../.claude-plugin/marketplace.json` |
| Depends On | VERIF-T04, VERIF-T09, VERIF-T10 |
| Target Components | plugins/edm/.claude-plugin/plugin.json, .claude-plugin/marketplace.json, plugins/edm/CHANGELOG.md |

### Description

The version lives in two places. `plugins/edm/.claude-plugin/plugin.json` is the plugin's own
manifest; the repository-root `.claude-plugin/marketplace.json` carries an independent copy of the
version **and** of the plugin description. EDMV4's audit found the marketplace copy is easy to
miss, and a marketplace entry that disagrees with the plugin manifest ships a version string that
was never released.

This ticket closes the release: both manifests at `3.2.2`, a changelog entry that describes what
changed and what was deliberately not done, and a passing full suite.

### Acceptance Criteria

- [ ] AC1: `jq -r '.version' plugins/edm/.claude-plugin/plugin.json` prints exactly `3.2.2`.
- [ ] AC2: `jq -r '.plugins[] | select(.name=="edm") | .version' .claude-plugin/marketplace.json` prints exactly `3.2.2`.
- [ ] AC3: The two values are compared programmatically in the verification step (a shell test that exits non-zero on mismatch), not read side by side by eye.
- [ ] AC4: The marketplace entry's `description` for `edm` is re-read against the plugin's actual skill and agent set; it is updated in the same commit if it is now inaccurate, and the commit body states explicitly that it was checked either way.
- [ ] AC5: `plugins/edm/CHANGELOG.md` gains a `## [3.2.2]` entry, dated, above the previous entry.
- [ ] AC6: The entry lists, at minimum: the sentinel contract, the four verifier prompt changes, the four consumer checks, the new `bin/edm-check-verifier-sentinel`, the `maxTurns` 25 -> 50 raise, and the auditor pre-verification step.
- [ ] AC7: The entry names what was deliberately **not** done -- proportional auditor fan-out, producer budget raises, and the code-audit lenses' `maxTurns: 30` -- so a reader does not infer they were overlooked.
- [ ] AC8: The entry states the ordering constraint (sentinel before budget raise) and why, in one sentence.
- [ ] AC9: `claude plugin validate plugins/edm/` exits 0.
- [ ] AC10: `bash plugins/edm/bin/tests/run-all.sh` exits 0.
- [ ] AC11: The commit message uses a gitmoji **shortcode** (never a Unicode emoji), carries no AI attribution trailer, and stages files by explicit name (no `git add -A`, no `git add .`).

### Technical Notes

**Verify the starting version before editing.** The analysis states the bump is `3.2.1 -> 3.2.2`,
but the working tree as read during ticket authoring has `3.2.0` in `plugin.json:4`, `3.2.0` in the
marketplace entry (`.claude-plugin/marketplace.json:35`), and `## [3.2.0]` as the newest changelog
heading. The end state asserted by AC1 and AC2 is `3.2.2` regardless. If no `3.2.1` entry exists in
the changelog, do not fabricate one -- write the `[3.2.2]` entry directly above `[3.2.0]` and note
the skipped number in the commit body rather than inventing history for a release that was never
cut.

Both JSON files are edited by hand or with `jq`; if using `jq`, write to a temp file and move it
into place rather than redirecting over the input.

The existing `plugins/edm/CHANGELOG.md` contains a non-ASCII em dash in the `[3.2.0]` heading. Do
not inherit that style: the new heading uses `--`. Do not reformat the old entry in this ticket --
an unrelated whitespace-and-punctuation sweep of the changelog buries the release diff.

### Out of Scope

Any code or prompt change. Publishing, tagging, or merging. Normalizing pre-existing non-ASCII
characters elsewhere in `CHANGELOG.md`. Bumping any other plugin's version in
`.claude-plugin/marketplace.json`.
