# Epic E9 -- WS9: Pattern-library curation

**Wave**: C (v3.0.0 -> v3.1.0)
**SRD requirements**: EDMV3-76 .. EDMV3-79 (4)
**Tickets**: EDMV3-T54 .. EDMV3-T56 (3)

F9. The living pattern library seeded from 600 real findings is one of the best ideas in the plugin.
The append mechanism is a prompt-rot vector that violates the library's own contract and feeds
unreviewed placeholder text into the highest-leverage prompt inputs in the system: the appended body
is literally "Review and refine: add a one-paragraph description explaining the finding and how to
prevent it" at severity P2, appended at end-of-file, past the fourth `##` section, into files loaded
by every future writer prompt.

The library is consumed at write time by `edm-srd-writer`, `edm-ticket-writer` and `edm-implementer`
(`docs/audit-patterns/README.md:34-44`), which is why its structure is a runtime contract rather than
a style preference.

All commands are run from the repository root unless stated otherwise.

---

## EDMV3-T54: `update-patterns` respects the Living-Library Contract and marks entries pending-review

| Field | Value |
|---|---|
| Epic | E9 -- Pattern-library curation |
| Wave | C |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV3-76, EDMV3-77 |
| Depends On | -- |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/edm-state:1576-1692` (`cmd_update_patterns`), the append block at `:1668-1675`, the normalized de-duplication at `:1632-1666`, the read-only-plugin graceful skip at `:1622-1625`, the `### ` heading read at `:1678`, the state recording block at `:1680-1685`; `plugins/edm/docs/audit-patterns/README.md:5-20` (the four-`##` contract) and `:22-32` (the Append Schema) |

### Description

`cmd_update_patterns` always appends at end-of-file, which lands after the fourth `##` section and
therefore outside the Living-Library Contract. And the stub it appends is indistinguishable from
curated content, which is the actual problem -- the stub itself is fine as a review instruction, but
nothing marks it as one and nothing ever prompts a human to complete it.

Both halves ship together because a contract-respecting insertion that is still unmarked would be
tidier prompt rot, and a marked stub in the wrong section would still violate the contract.

### Acceptance Criteria

- [ ] AC1 (positive, insert under a heading): new entries are inserted as `###` entries under an
      existing `##` heading, chosen by a documented mapping from the finding type.
      **`## Anti-Patterns` is the default target**, which is the self-consistent choice because
      EDMV3-T42 places this initiative's own pattern entries there.
      Verify: `edm-state update-patterns TESTX code` against the committed synthetic report in
      `plugins/edm/bin/tests/fixtures/code-audit/` (EDMV3-T24 AC0), then
      `awk '/^## Anti-Patterns/{f=1; next} f && /^## /{f=0} f' plugins/edm/docs/audit-patterns/code-audit.md | grep -c '^### '`
      increases by the entry count. The **guard-flag** form is required: the range form
      `awk '/^## Anti-Patterns/,/^## /'` tests the end pattern against the start record, so the
      range closes on the heading line itself, emits exactly one line, and the `grep -c` returns 0
      unconditionally -- passing whatever the insertion logic did. The guard-flag idiom is already
      in use at `plugins/edm/bin/tests/wave4b-smoke.sh:101` and is the pattern to copy.
- [ ] AC2 (negative, missing heading skips -- it does not fall back to EOF): if the target heading is
      absent, the command **skips with a message** rather than appending at EOF. Falling back to EOF
      when the heading is missing would preserve the whole defect in the one case that matters.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "missing target heading skips with a
      message and appends nothing"), asserting the file is byte-identical afterwards.
- [ ] AC3 (negative, no fifth section, no orphan content): no insertion ever occurs after the last
      `##` section's content boundary in a way that creates a fifth section or orphan content.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "no content after the last section
      boundary").
- [ ] AC4 (idempotent structure under repetition): the four-`##` structure of every pattern doc is
      unchanged after any number of `update-patterns` runs. A smoke test runs the command ten times
      against a fixture report and asserts `grep '^## '` still returns exactly the four contract
      headings in order.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "ten update-patterns runs preserve
      four headings").
- [ ] AC5 (preserve, de-duplication): the existing normalized de-duplication (lowercase,
      whitespace-collapsed, trailing-parens-stripped) at `:1632-1666` is preserved unchanged, so
      manually added entries remain de-dup-safe.
      Verify: `git diff plugins/edm/bin/edm-state | sed -n '/1632/,/1666/p' | grep -c '^-'` is 0 for
      the de-dup logic, and running the command twice with the same report appends once.
- [ ] AC6 (preserve, skip list and read-only skip): the existing structural-heading skip list
      (`summary`, `findings`, `recommendations`, `overview`, `appendix`, `legend`) and the
      read-only-plugin graceful skip at `:1622-1625` are preserved unchanged.
      Verify: `grep -n 'recommendations\|appendix' plugins/edm/bin/edm-state` shows the unchanged
      list, and running against a read-only plugin directory still skips gracefully.
- [ ] AC7 (atomic insertion): insertion is atomic -- a temp file plus rename, matching the discipline
      used elsewhere in the script -- so an interrupted run cannot leave a half-written pattern doc.
      Verify: `grep -n 'mv .*audit-patterns' plugins/edm/bin/edm-state` shows a rename from a temp
      path, and interrupting a run mid-insert leaves the original file intact.
- [ ] AC8 (preserve, state recording): the state recording block at `:1680-1685` is preserved, and
      it writes the two fields it actually writes -- `patterns_last_updated` (an ISO timestamp,
      `:1682`) and `patterns_updates` (an object keyed by audit type carrying `updated_at` and
      `new_findings`, `:1683`). There is no field named `patterns_updated`; the earlier verification
      read a key that has never existed and would have failed against correct code.
      Verify: `edm-state get TESTX | jq -e '.patterns_last_updated != null and (.patterns_updates.code.new_findings | type) == "number"'`
      after a run.
- [ ] AC9 (positive, pending-review marker): every auto-appended entry carries
      `status: pending-review` in a machine-greppable form on its own line, and records its
      provenance -- source prefix, audit type and date -- matching the Append Schema documented at
      `docs/audit-patterns/README.md:22-32`.
      Verify: `grep -A3 'status: pending-review' plugins/edm/docs/audit-patterns/code-audit.md`
      shows the three provenance fields.
- [ ] AC10 (stub delimited, not disguised): the stub body text is retained as the review instruction
      but is clearly delimited so a human can tell curated prose from a placeholder.
      Verify: read a generated entry -- the stub is inside an explicit delimiter, asserted by
      `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "stub body is delimited").
- [ ] AC11 (single source of truth for the pending count): `grep -c 'status: pending-review'
      docs/audit-patterns/*.md` is the single source of truth for the pending count. No mirrored
      state array, which would need syncing and could drift.
      Verify: `edm-state get TESTX | jq -e '.patterns_pending_review == null'` -- the field does not
      exist -- and `grep -rc 'status: pending-review' plugins/edm/docs/audit-patterns/` is the only
      count.
- [ ] AC12 (curation is one-way): once a human removes the `status: pending-review` line, the entry
      is curated. Nothing re-adds it, and de-duplication prevents the same title being re-appended.
      Verify: remove the marker, re-run `update-patterns` with the same fixture report, and confirm
      the marker does not return and no duplicate entry appears.
- [ ] AC13 (Append Schema documents the lifecycle): `docs/audit-patterns/README.md`'s Append Schema
      section documents the `pending-review` marker and the curation lifecycle.
      Verify: `grep -n 'pending-review' plugins/edm/docs/audit-patterns/README.md`.

### Technical Notes

- The insertion point is "end of the target `##` section's content", which means finding the next
  `^## ` line and inserting before it, with end-of-file as the boundary only when the target section
  is the last one. Get that boundary wrong and AC3 fails.
- `docs/audit-patterns/README.md` is the contract document, not a library document, and is exempt
  from the four-`##` rule. Do not insert into it.
- bash 3.2 with no `mapfile`: use `awk` for the section-boundary walk rather than reading the file
  into an array. Use the **guard-flag** idiom (`/^## Heading/{f=1; next} f && /^## /{f=0} f`), not
  the range idiom -- see AC1. The range form is the single most common way this check silently
  passes.
- Blocks EDMV3-T55 and EDMV3-T56.
- **AC-band note.** 13 acceptance criteria against the 6-12 band. Two requirements ship together
  because a contract-respecting insertion that is still unmarked would be tidier prompt rot; five of
  the ACs (AC5, AC6, AC8, AC12, plus AC4's idempotence) are preservation assertions on existing
  behaviour rather than new work. Recorded in the README sizing section.

### Out of Scope

- The gate-time curation prompt -- EDMV3-T55.
- The automated four-`##` contract test -- EDMV3-T56.
- Making `update-patterns` JSONL-aware. It reads `### ` headings from the round's audit report
  (`bin/edm-state:1678`), **not** from the ledger, and no requirement in this initiative changes
  that.

---

## EDMV3-T55: The audit gate presents pending pattern entries for human curation

| Field | Value |
|---|---|
| Epic | E9 -- Pattern-library curation |
| Wave | C |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV3-78 |
| Depends On | EDMV3-T03, EDMV3-T35, EDMV3-T54 |
| Ships-with | -- |
| Target Components | `plugins/edm/skills/audit-srd/SKILL.md`, `plugins/edm/skills/audit-tickets/SKILL.md`, `plugins/edm/skills/code-audit/SKILL.md`, `plugins/edm/docs/audit-patterns/*.md` (the curation targets) |

### Description

The missing half of the feedback loop. EDM already harvests findings into writer guidance; what is
missing is curation. Presenting pending entries at a gate the human is already stopping at costs
nothing extra in interruptions.

Promoted to Must Have in SRD v1.1.0: EDMV3-77 ships the mechanism (marked stubs) and this ships the
value (someone is actually asked to curate them). Split across a Must and a Should, a slipped Should
would leave F9 unfixed while looking fixed -- marked stubs nobody is ever prompted to review.

### Acceptance Criteria

- [ ] AC1 (positive, presented at three gates): at the audit gate presentation -- Gate 2, Gate 3 and
      the convergence gate -- the skill lists any pattern entries currently marked
      `status: pending-review`, showing the title, source prefix and target document for each.
      Verify: create a pending entry, run `/edm:audit-srd EDMV3` to its gate, and confirm the entry
      appears with all three fields. Recorded as a manual-QA case for each of the three gates.
- [ ] AC2 (three actions, one interaction round): the human is offered keep, edit or discard per
      entry, alongside the findings review, without a separate interaction round.
      Verify: the gate presentation offers the three options in the same `AskUserQuestion` flow as
      the findings review, asserted by
      `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "keep/edit/discard offered at three gates").
- [ ] AC3 (action semantics): discard removes the entry from the pattern document; keep removes the
      `pending-review` marker; edit prompts for the one-paragraph description and then removes the
      marker.
      Verify: exercise all three against a fixture entry and confirm with
      `grep -c 'status: pending-review' <doc>` and the entry's presence or absence.
- [ ] AC4 (negative, nothing shown when nothing is pending): when there are no pending entries,
      nothing is shown -- the gate presentation is unchanged.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "no pending entries leaves the gate
      presentation unchanged"), using `check_absent` on the curation heading.
- [ ] AC5 (negative, curation never blocks the gate): declining to curate leaves the entries pending
      and the gate proceeds.
      Verify: run the gate, decline curation, and confirm the gate approval still records -- the
      pending count is unchanged and `edm-state get` shows the gate approved.
- [ ] AC6 (negative, approval semantics untouched): the gate PROTOCOL itself is unchanged. This is
      additional content in the gate summary, not a change to approval semantics.
      Verify: `git diff plugins/edm/skills/orchestrator/SKILL.md | grep -c 'Gate PROTOCOL'` returns 0
      and `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "PROTOCOL section unchanged") is green.
- [ ] AC7 (grants present): the three skills that present these prompts hold `AskUserQuestion`.
      Verify: `bash plugins/edm/bin/edm-check-grants; echo "exit=$?"` prints `exit=0`, and
      `grep -l 'AskUserQuestion' plugins/edm/skills/{audit-srd,audit-tickets,code-audit}/SKILL.md`
      returns all three.
- [ ] AC8 (the count is read from the files, not from state): the pending list is derived from
      `grep 'status: pending-review' docs/audit-patterns/*.md` at presentation time, not from a state
      array.
      Verify: `grep -rl 'patterns_pending' plugins/edm/skills/ | wc -l` prints 0, and
      `grep -n "status: pending-review" plugins/edm/skills/audit-srd/SKILL.md` returns the
      grep-based derivation.
- [ ] AC9 (prose-change convention): the merge request shows before and after for each changed gate
      block plus one sentence of rationale (EDMV3-69).
      Verify: the MR description contains the before/after blocks.

### Technical Notes

- The three gates already stop for a human. Adding a fourth interaction round would make curation a
  tax rather than a habit, which is why AC2 requires it inside the same flow.
- `AskUserQuestion` supports up to four options. Keep, edit, discard and "leave pending" fit exactly,
  which is convenient and is why AC5's decline path needs no separate mechanism.
- Depends on EDMV3-T35 because the gate presentation this ticket extends is the canonical PROTOCOL's,
  and on EDMV3-T03 for the tool grants.

### Out of Scope

- The marker mechanism -- EDMV3-T54.
- Bulk curation outside a gate. Deliberately not offered: the value of gate-time curation is that it
  happens at all.

---

## EDMV3-T56: The four-`##` contract becomes a CI regression guard

| Field | Value |
|---|---|
| Epic | E9 -- Pattern-library curation |
| Wave | C |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV3-79, EDMV3-109 |
| Depends On | EDMV3-T42, EDMV3-T54 |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/tests/wave7-smoke.sh`, `.gitlab-ci.yml`, `plugins/edm/docs/audit-patterns/README.md:5-20` (the contract, and the copy-pasteable check snippet at `:14-20`), the five library documents `srd-audit.md:101`, `ticket-audit.md:95`, `qc-audit.md:74`, `code-audit.md:125`, `test-coverage-audit.md:92` |

### Description

The contract already documents a structure check at `docs/audit-patterns/README.md:14-20`, but it is a
copy-pasteable shell snippet that nobody runs. Making it a test is the difference between a documented
contract and an enforced one.

The fourth heading is the subtle part. A literal-name assertion would fail on **four of the five**
contract-compliant documents on day one: the actual titles are `## What a Passing First Draft Looks
Like` (`srd-audit.md:101`, `ticket-audit.md:95`), `## What a Passing QC Round Looks Like`
(`qc-audit.md:74`), `## What Passing Code Looks Like` (`code-audit.md:125`) and
`## What Passing Test Coverage Looks Like` (`test-coverage-audit.md:92`).

### Acceptance Criteria

- [ ] AC1 (positive, five documents, four headings, in order): a test asserts that each of the five
      pattern documents (`srd-audit`, `ticket-audit`, `code-audit`, `test-coverage-audit`,
      `qc-audit`) contains exactly four `##` headings, in the contract order: Top Recurring Findings,
      Anti-Patterns, Pre-Flight Checklist, then the fourth section.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "five pattern docs carry four
      headings in contract order").
- [ ] AC2 (the fourth heading matches a regex, and the variation is sanctioned): the first three
      headings match exactly; the fourth matches the regex `^## What .*Looks Like$`. The regex is
      documented in `docs/audit-patterns/README.md` as the contract for heading four, so the
      variation is sanctioned rather than tolerated.
      Verify: `grep -n 'What .*Looks Like' plugins/edm/docs/audit-patterns/README.md` returns the
      documented regex, and
      `for f in srd-audit ticket-audit code-audit test-coverage-audit qc-audit; do grep -c '^## What .*Looks Like$' "plugins/edm/docs/audit-patterns/$f.md"; done`
      prints 1 five times.
- [ ] AC3 (negative, failure names the document and the heading): the test fails naming the offending
      document and the unexpected or missing heading.
      Verify: add a fifth `##` to a scratch copy of `code-audit.md` and confirm the suite exits
      non-zero naming both the file and the unexpected heading.
- [ ] AC4 (negative, **both** non-library documents are explicitly exempt): the test's exemption
      list names exactly two files -- `docs/audit-patterns/README.md`, the contract document, and
      `docs/audit-patterns/SOURCES.md`, the provenance document, which carries two `##` headings and
      is therefore neither covered by the four-heading contract nor exempted from it today. Both
      exemptions are enumerated in the test by name and each carries a one-line reason, so an
      exemption is a decision rather than an accident of which files the glob happened to miss. Any
      **third** file appearing under `docs/audit-patterns/` without either four contract headings or
      an explicit exemption entry fails the test.
      Verify: `grep -n 'README.md is exempt\|SOURCES.md is exempt' plugins/edm/bin/tests/wave7-smoke.sh`
      returns both lines with their reasons, the suite passes despite both files having different
      heading sets, and adding a scratch `docs/audit-patterns/scratch.md` with two `##` headings
      makes the suite fail naming that file.
- [ ] AC5 (negative, orphan append detected): the test also asserts that no content appears after the
      last section's expected boundary in a way that would constitute an orphan append.
      Verify: append a stray `### Orphan` after the last section in a scratch copy and confirm the
      suite fails.
- [ ] AC6 (runs after every `update-patterns` invocation in the suite): the test runs in the CI lint
      stage and after every `update-patterns` invocation in the smoke suite, so a regression in
      EDMV3-T54's insertion logic is caught immediately rather than at the next audit.
      Verify: `grep -n 'four-heading\|contract check' plugins/edm/bin/tests/wave7-smoke.sh` shows the
      call following each `update-patterns` case, and `grep -n 'wave7-smoke' .gitlab-ci.yml`.
- [ ] AC7 (the manual edits this initiative made are covered): every manual edit made by this
      initiative to a pattern document adds `###`-level content under an existing `##` heading only,
      and after every wave `grep '^## '` over each of the five library documents returns exactly the
      four contract headings in contract order.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` is green after EDMV3-T42's Mermaid entries
      and EDMV3-T33's D15 entries have landed.
- [ ] AC8 (the tooling respects the contract too): the automated check passes against a tree where
      `update-patterns` has run ten times.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "ten update-patterns runs then the
      contract check") is green.

### Technical Notes

- The check is cheap and belongs in the lint stage, not the test stage, so it fails fast alongside
  the other structural checks.
- Depends on EDMV3-T42 (which adds `###` entries to two of the five docs) and EDMV3-T54 (which
  changes the insertion logic) so the guard is written against the final shape rather than the
  current one.
- The copy-pasteable snippet at `docs/audit-patterns/README.md:14-20` should stay as documentation --
  it is how a contributor checks locally -- but the README should note that CI runs the authoritative
  version.

### Out of Scope

- Changing any heading in the five documents. The regex accommodates the existing variation; it does
  not license new variation.
- Extending the contract to a fifth section.
