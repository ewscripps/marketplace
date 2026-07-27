# Epic E6 -- WS6: The Mermaid literal-semicolon rule

**Wave**: B (v2.1.0 -> v3.0.0)
**SRD requirements**: EDMV3-53 .. EDMV3-58, EDMV3-116 (7)
**Tickets**: EDMV3-T40 .. EDMV3-T44 (5)

The user's requirement 2. Mermaid reserves `;` as a statement separator, so a literal `;` in label
text breaks the diagram. The fix is the entity code `#59;` with no leading ampersand, verified against
upstream Mermaid documentation ("Entity codes to escape characters"). Rendering in the organization's
tooling is confirmed (D8), so no renderer validation spike is performed (EDMV3-88).

The rule does not exist anywhere today: tree-wide greps for `#59`, `&#` and `semicolon` return zero
matches, and the plugin never ships a literal example diagram -- it only instructs agents to author
them.

This epic is independent of the dispatcher and can ship at any point in wave B.

All commands are run from the repository root unless stated otherwise.

---

## EDMV3-T40: Canonical Mermaid conventions section in `CLAUDE.md`

| Field | Value |
|---|---|
| Epic | E6 -- Mermaid rule |
| Wave | B |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV3-53 |
| Depends On | -- |
| Ships-with | -- |
| Target Components | `plugins/edm/CLAUDE.md` (new section, inserted between `## Severity vocabulary (canonical)` and `## Model and effort assignments`) |

### Description

The canonical-section-referenced-by-name pattern is proven by the Severity vocabulary, whose
consumers already cite it at `skills/code-audit/SKILL.md:146`, `skills/audit-srd/SKILL.md:65`,
`agents/edm-srd-auditor.md:63` and `agents/edm-ticket-auditor.md:73`. This section must land before
the eleven references, or they dangle.

### Acceptance Criteria

- [ ] AC1 (positive, placement): `plugins/edm/CLAUDE.md` gains a section
      `## Mermaid diagram conventions (canonical)`, placed immediately after
      `## Severity vocabulary (canonical)` and before `## Model and effort assignments`, so the
      canonical sections stay adjacent.
      Verify: `grep -n '^## ' plugins/edm/CLAUDE.md | grep -A2 'Severity vocabulary'` shows the new
      heading between the two.
- [ ] AC2 (register matches the precedent): it opens with a sentence in the same register as the
      Severity section -- all EDM agents that author or audit Mermaid follow these conventions, and
      no agent may define a divergent local rule.
      Verify: `grep -n 'no agent may define a divergent local rule' plugins/edm/CLAUDE.md`.
- [ ] AC3 (problem stated): it states that `;` is a lexer-level statement separator in Mermaid and
      is reserved even where it appears inside a label.
      Verify: `grep -n 'statement separator' plugins/edm/CLAUDE.md`.
- [ ] AC4 (rule stated, both entity forms): it states that a literal semicolon in Mermaid label,
      node, edge or message text is written `#59;` -- entity code syntax, `#` followed by **either a
      base-10 code point or an entity name**, then `;`, with **no leading ampersand**. The
      definition covers both forms because the examples use both, and defining it as base-10-only
      would make `#quot;` a violation of the rule it illustrates.
      Verify: `grep -n '#59;' plugins/edm/CLAUDE.md` and
      `grep -n 'entity name' plugins/edm/CLAUDE.md`.
- [ ] AC5 (worked examples): it includes one incorrect and one correct example in adjacent-line
      form, both inside a fenced block.
      Verify: `sed -n '/Mermaid diagram conventions/,/^## /p' plugins/edm/CLAUDE.md | grep -c '```'`
      returns at least 2.
- [ ] AC6 (quoting caveat): it notes that quoting alone is not a reliable substitute across diagram
      types, and that `sequenceDiagram` message text after `:` is unquoted and therefore especially
      exposed.
      Verify: `grep -n 'sequenceDiagram' plugins/edm/CLAUDE.md`.
- [ ] AC7 (negative, the legal exceptions are enumerated): it states the exceptions that remain legal
      and are **not** violations -- a statement-terminating `;` at end of line, `;` on a `%%` comment
      line, and `;` terminating a `classDef`, `style` or `linkStyle` directive.
      Verify: `grep -n 'classDef' plugins/edm/CLAUDE.md` returns the exception list.
- [ ] AC8 (generalization): it notes that other entity codes follow the same form (`#quot;`, `#35;`)
      so the rule generalizes.
      Verify: `grep -n '#quot;' plugins/edm/CLAUDE.md`.
- [ ] AC9 (ASCII only): the section content is ASCII-only.
      Verify: `LC_ALL=C sed -n '/Mermaid diagram conventions/,/^## Model and effort/p' plugins/edm/CLAUDE.md | grep -n '[^\x00-\x7F]'`
      returns nothing.
- [ ] AC10 (heading string is asserted, not assumed): a smoke assertion checks the exact heading
      string, and `architecture.md` uses the same name, so the two documents cannot drift on it.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "canonical Mermaid heading string")
      and `grep -n 'Mermaid diagram conventions' SRD/edm/EDMV3__prompt-streamline/architecture.md`.

### Technical Notes

- Blocks EDMV3-T41, T42 and T43. Land it first in the epic.
- The incorrect example must contain a **raw** semicolon inside a label, which means the fenced block
  will trip the lint class this epic later adds. Wrap the incorrect example's fence in the block-form
  ignore markers (`<!-- edm-lint-ignore-start -->` before the fence opener,
  `<!-- edm-lint-ignore-end -->` after the closer) -- the single-line marker cannot serve here
  because its usual position is inside the fence (EDMV3-T43 AC6).
- `plugins/edm/CLAUDE.md` is currently flagged by `claude plugin validate` as not being runtime
  context. That warning is pre-existing and accepted; whether agents can actually resolve by-name
  references to it is a different question, answered by EDMV3-T41.

### Out of Scope

- The eleven touch-point references -- EDMV3-T42.
- The lint class -- EDMV3-T43.
- Any renderer validation. Explicitly forbidden by D8 / EDMV3-88.

---

## EDMV3-T41: `CLAUDE.md` by-name references are verified to resolve from an installed cache

| Field | Value |
|---|---|
| Epic | E6 -- Mermaid rule |
| Wave | B |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV3-116 |
| Depends On | EDMV3-T40 |
| Ships-with | -- |
| Target Components | `plugins/edm/CLAUDE.md`, `plugins/edm/agents/*.md` (reference form), `SRD/edm/EDMV3__prompt-streamline/decisions.md`, `plugins/edm/bin/tests/wave7-smoke.sh` (sync assertion, only if duplication is chosen) |

### Description

F11's second half, which the SRD previously retired as a validator warning. `EDM-REVIEW.md:159` puts
it plainly: several `CLAUDE.md` sections -- the severity vocabulary, and the Mermaid rules once added
-- are *referenced by name from agent prompts at runtime*, so the single most-cited canonical document
in the system is one the runtime never guarantees is present, and whether agents reliably read it is
unverified.

The Definition of Done's "one pre-existing warning about root `CLAUDE.md` not being runtime context is
acceptable" answers the validator, not the question. EDMV3-T42 then adds nine more by-name references
on top of the existing ones, and EDMV3-T43 exists precisely because prompt text is probabilistic --
but "probabilistic" presumes the text is read at all. If it is not, the canonical-section pattern is
decorative and every requirement resting on it is unsupported.

### Acceptance Criteria

- [ ] AC1 (the check runs from an installed cache, not the dev tree): from an installed plugin cache,
      an agent is given the string `` `CLAUDE.md Sec."Severity vocabulary"` `` in the same form the
      prompts use, and the run records whether it retrieved the section's content, retrieved the
      wrong file, or could not resolve it at all. The same check is run for
      `` `CLAUDE.md Sec."Mermaid diagram conventions"` ``.
      Verify: the ticket records both transcripts and the retrieved content (or the failure), taken
      against an installed cache path, not `plugins/edm/`.
- [ ] AC2 (recorded either way): the result, the Claude Code version, the install method and the date
      are recorded in `decisions.md`. A negative result is as useful as a positive one and is not a
      reason to skip recording.
      Verify: `grep -n 'CLAUDE.md by-name reference resolution' SRD/edm/EDMV3__prompt-streamline/decisions.md`
      returns the four recorded fields.
- [ ] AC3 (positive branch): if the references resolve, the pattern is confirmed, the result is noted
      in `plugins/edm/CLAUDE.md` so a future contributor does not re-litigate it, and nothing else
      changes.
      Verify: `grep -n 'verified to resolve' plugins/edm/CLAUDE.md` with the recorded date.
- [ ] AC4 (negative branch): if they do not resolve, the canonical sections are relocated or
      deterministically duplicated into a path agents *can* resolve -- the leading candidate being a
      `docs/` file inside the plugin that agent prompts reference by relative path, matching how
      `docs/audit-patterns/*.md` is already loaded at write time. Duplication, if chosen, is
      one-directional and generated, never hand-maintained in two places.
      Verify: on the negative branch, `ls plugins/edm/docs/` shows the generated file and
      `grep -n 'generated from CLAUDE.md' <that file>` shows the header.
- [ ] AC5 (negative branch, byte-identity guard): if duplication is chosen, a smoke assertion guards
      the copy -- the duplicated section is byte-identical to its source, asserted in CI. An
      unguarded duplicate would recreate the exact defect the canonical-section pattern exists to
      prevent.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "duplicated canonical section is
      byte-identical"), and hand-editing the copy makes it fail.
- [ ] AC6 (exactly one branch is implemented, and which is stated): the ticket states which branch
      was taken. A ticket closing without naming the branch is not done.
      Verify: the ticket's QC evidence names the branch and links the `decisions.md` entry.
- [ ] AC7 (ordering, the whole point): this ticket completes **before EDMV3-T42 lands**, so nine new
      references are not added to a mechanism that has not been shown to work.
      Verify: `git log --format='%h %cI' -- SRD/edm/EDMV3__prompt-streamline/decisions.md plugins/edm/agents/edm-architect.md`
      shows the decision recorded before the reference edits.

### Technical Notes

- "Installed plugin cache" means the path Claude Code copies the plugin to on
  `claude plugin install`, not `--plugin-dir ./plugins/edm`. The two resolve differently and the
  install path is the one users have.
- Run the check twice in separate sessions. A single successful resolution could be the model
  guessing from context rather than retrieving.
- On the negative branch, generation must be one-directional and scripted -- add it to the CI lint
  stage so a hand edit to the copy is a pipeline failure, not a silent divergence.

### Out of Scope

- The nine reference edits themselves -- EDMV3-T42.
- Fixing the pre-existing `claude plugin validate` warning about root `CLAUDE.md`. That is a
  different problem and is explicitly accepted in the SRD's Definition of Done.

---

## EDMV3-T42: Eleven touch points carry the rule, and rule presence is asserted

| Field | Value |
|---|---|
| Epic | E6 -- Mermaid rule |
| Wave | B |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV3-54, EDMV3-55, EDMV3-58 |
| Depends On | EDMV3-T40, EDMV3-T41 |
| Ships-with | -- |
| Target Components | `plugins/edm/agents/edm-architect.md` (26-30, 44, 67, 85-86), `plugins/edm/agents/edm-srd-writer.md` (34, 58, 79), `plugins/edm/agents/edm-ticket-writer.md` (5, 39, 99), `plugins/edm/agents/edm-srd-auditor.md` (33-36), `plugins/edm/agents/edm-ticket-auditor.md` (40-44, 52-56, 126), `plugins/edm/skills/srd/SKILL.md` (57, 82, 153), `plugins/edm/skills/tickets/SKILL.md:43`, `plugins/edm/skills/audit-srd/SKILL.md` (48-49), `plugins/edm/skills/audit-tickets/SKILL.md` (61-64, 72-75), `plugins/edm/docs/audit-patterns/srd-audit.md` (Anti-Patterns at `:58`, Pre-Flight Checklist at `:86`), `plugins/edm/docs/audit-patterns/ticket-audit.md` (Anti-Patterns at `:57`, Pre-Flight Checklist at `:81`), `plugins/edm/bin/tests/wave7-smoke.sh` |

### Description

Explorer 01 section 2.3 inventories the complete Mermaid touch-point set. **The canonical list is
EDMV3-54's eleven-row table, and it is the only place the cardinality is stated.** The set is eleven,
not twelve: nine prompt-surface files (three authoring agents, two auditing agents, four skills)
receive by-name references, and the two pattern-library documents receive `###` content entries.
Every other statement of the count points at that table rather than restating a number.

The pattern-library half is delivered here rather than separately because the two writer-facing
pattern docs are loaded at write time by `edm-srd-writer` and `edm-ticket-writer`, so an entry there
reaches the writers without editing agent prompts -- it is the same delivery mechanism from the
writers' point of view, and the four-`##` Living-Library Contract binds both edits identically.

### Acceptance Criteria

- [ ] AC1 (positive, three authoring agents): `agents/edm-architect.md` references the section at the
      existing ASCII carve-out (`:85-86`, pointing at the canonical section rather than growing an
      inline explanation) plus the diagram deliverable at `:26-30`; `agents/edm-srd-writer.md` at
      process step 4 (`:79`); `agents/edm-ticket-writer.md` at process step 8 (`:99`).
      Verify: `grep -c 'Mermaid diagram conventions' plugins/edm/agents/edm-architect.md plugins/edm/agents/edm-srd-writer.md plugins/edm/agents/edm-ticket-writer.md`
      is non-zero for each.
- [ ] AC2 (positive, two auditing agents, with an explicit check): `agents/edm-srd-auditor.md`
      category 3 Diagram Errors (`:33-36`) and `agents/edm-ticket-auditor.md` dimension 6 Diagram
      Correctness (`:52-56`) plus process step 4 (`:126`) reference the section **and add the
      literal-`;` check explicitly**.
      Verify: `grep -n 'raw ;\|literal semicolon' plugins/edm/agents/edm-srd-auditor.md plugins/edm/agents/edm-ticket-auditor.md`.
- [ ] AC3 (positive, four skills): `skills/srd/SKILL.md` (the architect spawn prompt at `:153` is the
      highest-leverage site, plus the template at `:82`), `skills/tickets/SKILL.md:43`,
      `skills/audit-srd/SKILL.md:48-49` and `skills/audit-tickets/SKILL.md:72-75` all reference it.
      Verify: `for s in srd tickets audit-srd audit-tickets; do grep -q 'Mermaid diagram conventions' "plugins/edm/skills/$s/SKILL.md" || echo "MISSING: $s"; done`
      prints nothing.
- [ ] AC4 (identical quoting style): every reference uses the identical quoting style already in use:
      `` `CLAUDE.md Sec."Mermaid diagram conventions"` ``.
      Verify: `grep -rho 'CLAUDE.md Sec\."Mermaid diagram conventions"' plugins/edm/ | sort -u | wc -l`
      returns 1.
- [ ] AC5 (negative, no restatement): no touch point restates the rule content. A grep for `#59`
      outside `CLAUDE.md`, the pattern-library entries, the linter and its tests returns only
      reference lines.
      Verify: `grep -rn '#59' plugins/edm/ | grep -v 'CLAUDE.md' | grep -v 'docs/audit-patterns' | grep -v 'edm-lint-artifacts' | grep -v 'bin/tests'`
      returns zero results.
- [ ] AC6 (concrete audit check text): the auditing agents' new check text names what to look for
      concretely -- a raw `;` inside `[...]`, `(...)`, `{...}`, `|...|`, `"..."`, or after the `:` in
      a `sequenceDiagram` message.
      Verify: `grep -n 'sequenceDiagram message' plugins/edm/agents/edm-ticket-auditor.md`.
- [ ] AC7 (pattern-library entries under an existing `##`): `docs/audit-patterns/srd-audit.md` gains
      a `###` entry under `## Anti-Patterns` describing the literal-semicolon failure with the
      `#59;` fix, following the existing anti-pattern shape (description then `**Fix:**`).
      `docs/audit-patterns/ticket-audit.md` gains the equivalent entry framed for the critical-path
      diagram. Both gain one bullet in their `## Pre-Flight Checklist` sections.
      Verify: `grep -n '^### ' plugins/edm/docs/audit-patterns/srd-audit.md | grep -i mermaid` and
      the same for `ticket-audit.md`.
- [ ] AC8 (negative, four-`##` contract intact): neither pattern doc gains a new `##` heading.
      Verify: `grep -c '^## ' plugins/edm/docs/audit-patterns/srd-audit.md plugins/edm/docs/audit-patterns/ticket-audit.md`
      returns 4 for each, and `grep '^## ' <each>` shows the contract order.
- [ ] AC9 (de-duplication safe): entry titles are chosen so `cmd_update_patterns`' normalized
      de-duplication (lowercased, whitespace-collapsed, trailing-parens-stripped) will not later
      auto-append a duplicate, and the entries are ASCII-only.
      Verify: `edm-state update-patterns EDMV3 code` run twice against the committed synthetic
      report in `plugins/edm/bin/tests/fixtures/code-audit/` (EDMV3-T24 AC0) does not append a
      second Mermaid entry, and
      `LC_ALL=C grep -n '[^\x00-\x7F]' plugins/edm/docs/audit-patterns/srd-audit.md` returns
      nothing.
- [ ] AC10 (rule-presence smoke assertions): a smoke test asserts the canonical heading exists in
      `CLAUDE.md`, that the by-name reference or `###` entry appears in each of the eleven touch
      points in EDMV3-54's numbered table -- rows 1-9 carry a reference, rows 10-11 carry the entries
      -- and that the `#59;` token appears in the canonical section's correct example. The test
      reads the cardinality from that table rather than hardcoding a number in a second place, and
      names the specific missing file when it fails.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "eleven Mermaid touch points"), and
      deleting one reference makes it fail naming that file.
- [ ] AC11 (post-WS5 file set): after the EDMV3-T37 move, the skill-side references exist only in the
      phase-skill copies and the orchestrator carries none.
      Verify: `grep -c 'Mermaid diagram conventions' plugins/edm/skills/orchestrator/SKILL.md`
      returns 0.
- [ ] AC12 (CI): the rule-presence test runs in CI.
      Verify: `grep -n 'wave7-smoke' .gitlab-ci.yml`.
- [ ] AC13 (prose-change convention, EDMV3-69): the merge request shows before and after for each of
      the eleven changed blocks plus one sentence on why the new wording is better. The nine by-name
      references share one canonical form, so they are shown once as a canonical before/after plus
      the nine-file list; the two pattern-library `###` entries are shown individually because their
      content differs.
      Verify: the MR description contains the canonical reference before/after with its nine-file
      list, and two individual before/after blocks for the pattern-library entries.

### Technical Notes

- The bound on what AC10 buys is worth stating in the ticket: it verifies the text exists, not that
  an agent reads it. That is EDMV3-T41's question and is why this ticket depends on it.
- The two pattern-library entries must be `###` under an existing `##`. Adding a fifth `##` fails
  EDMV3-T56's contract check in wave C and fails AC8 today.
- EDMV3-T37's move relocates some of these skill files' content. If T37 lands first, apply the
  references to the post-move file set; if this ticket lands first, T37 carries the references along
  and AC11 is checked at wave close.

### Out of Scope

- The lint class -- EDMV3-T43.
- The fixture corpus -- EDMV3-T44.
- The four-`##` contract *test* -- EDMV3-T56 (wave C). AC8 here is a manual grep, not the automated
  guard.

---

## EDMV3-T43: `edm-lint-artifacts` gains the Mermaid class on a one-pass line classifier

| Field | Value |
|---|---|
| Epic | E6 -- Mermaid rule |
| Wave | B |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV3-56, EDMV3-102 |
| Depends On | EDMV3-T40 |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/edm-lint-artifacts` -- header comment block at `:7-11`, `usage()` at `:30`, `report_violation` at `:59`, `build_ignore_set` at `:69-109` including the discarded fence info string at `:83`, `is_ignored_line` at `:112`, the three per-class `build_ignore_set` calls at `:147`, `:166`/`:176` and `:192`, and the new class after `:198`; `plugins/edm/hooks/hooks.json:80-90` (unchanged); `plugins/edm/CLAUDE.md` (`bin/` table) |

### Description

This is the only mechanism in the whole change set that gives a hard guarantee; the other eleven touch
points are prompt text, which is probabilistic.

The structural caveat is that `build_ignore_set` deliberately emits every in-fence line as ignored, so
all three existing classes skip exactly the region this class must inspect. An inverse helper is
required -- and since `edm-lint-artifacts` currently calls `build_ignore_set` once per class per file
(three times per file today), refactoring it into one shared pass is both the cleanest factoring and
the cheapest way to meet EDMV3-102's 40% budget, which a fourth independent full pass would not meet
by construction.

### Acceptance Criteria

- [ ] AC1 (one pass serves four classes): `build_ignore_set` is refactored once into
      `build_line_classes <file>`, emitting `lineno<TAB>ignored|mermaid`, computed **once per file**
      and shared by all four classes.
      Verify: `grep -c 'build_line_classes' plugins/edm/bin/edm-lint-artifacts` shows one definition
      and one call per file, and `grep -c 'build_ignore_set' plugins/edm/bin/edm-lint-artifacts`
      returns 0.
- [ ] AC2 (mermaid line set is correct): the mermaid line set contains only line numbers inside
      ` ```mermaid ` fences, using the language token the existing loop discarded at `:83`.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "mermaid line set excludes
      non-mermaid fences").
- [ ] AC3 (negative, malformed fences): the helper handles nested and unterminated fences without
      hanging or mis-attributing lines, and treats a fence opened with any info string other than
      `mermaid` as out of scope.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (cases "unterminated fence terminates" and
      "nested fence does not mis-attribute"), with a timeout so a hang fails rather than blocks.
- [ ] AC4 (positive, the class fires): a fourth class flags a `;` occurring inside a label span --
      `[...]`, `(...)`, `{...}`, `|...|`, or `"..."` -- or after the `:` in a `sequenceDiagram`
      message line.
      Verify: `bash plugins/edm/bin/edm-lint-artifacts --path plugins/edm/bin/tests/fixtures/mermaid/invalid/`
      reports one violation per invalid fixture at the expected line. The `--path` mode is
      delivered by EDMV3-T20 AC10 and is what makes this verification expressible: the script
      accepts a `PREFIX` only today (`:37` dies on an empty argument, `:44` resolves the prefix
      through `edm-state resolve-dir`), so a bare directory argument exits 1 with "no initiative for
      prefix" and never lints anything.
- [ ] AC5 (negative, zero false positives on the legal cases): negative guards produce zero false
      positives on `#<digits>;` and `#<name>;` entity codes including `#59;`, `#quot;` and `#35;`; a
      trailing statement-terminating `;` at end of line; `;` on a `%%` comment line; and `;`
      terminating a `classDef`, `style` or `linkStyle` directive.
      Verify: `bash plugins/edm/bin/edm-lint-artifacts --path plugins/edm/bin/tests/fixtures/mermaid/valid/; echo "exit=$?"`
      prints `exit=0` (`--path` per EDMV3-T20 AC10).
- [ ] AC6 (the escape valve is the block form, and the single-line form is explicitly unsupported):
      the supported escape valve for class 4 is `<!-- edm-lint-ignore-start -->` on the line before
      the ` ```mermaid ` opener and `<!-- edm-lint-ignore-end -->` after the closer. The single-line
      `<!-- edm-lint-ignore -->` marker cannot be used in its usual position, because that position
      is *inside* the fence, where an HTML comment is diagram source and Mermaid's comment syntax is
      `%%` -- the marker would corrupt the diagram it was meant to exempt. A single-line marker on
      the fence-open line suppresses the entire fence; anywhere else inside a fence it is
      unsupported and the linter says so.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (cases "block-form markers suppress a
      fence", "single-line marker on the fence-open line suppresses the fence", and "single-line
      marker inside a fence produces the unsupported message").
- [ ] AC7 (output format and exit code unchanged): output uses the existing
      `path:line: <class>: <snippet>` format via `report_violation`, and the class contributes to the
      same exit code.
      Verify: `bash plugins/edm/bin/edm-lint-artifacts <file-with-violation> | grep -E '^[^:]+:[0-9]+: '`.
- [ ] AC8 (header block, and the `usage()` range is not touched here): the header comment block at
      `:7-11` lists the new class. The `usage()` `sed` range is **not** widened here -- EDMV3-96
      replaces the hardcoded range with sentinel delimiters and owns that line. Widening it here
      while EDMV3-96 deletes it would be two incompatible instructions for the same code.
      Verify: `sed -n '7,11p' plugins/edm/bin/edm-lint-artifacts` names four classes, and
      `git diff plugins/edm/bin/edm-lint-artifacts | grep -c "sed -n '2,19p'"` returns 0.
- [ ] AC9 (three existing classes behave identically): the three existing classes produce identical
      output before and after the refactor on the same corpus.
      Verify: capture `bash plugins/edm/bin/edm-lint-artifacts --all` output before the change, and
      `diff` it against the output after, filtered to the three pre-existing class names -- the diff
      is empty.
- [ ] AC10 (performance budget): adding the Mermaid class increases total lint time by no more than
      40% relative to the three-class baseline, measured before and after and recorded in the ticket.
      Files containing no ` ```mermaid ` fence short-circuit the new class without a per-line scan.
      Verify: `time bash plugins/edm/bin/edm-lint-artifacts --all` before and after, both recorded;
      the ratio is at most 1.40.
- [ ] AC11 (bash 3.2): the helper and class use no associative arrays, no `mapfile`, no `{fd}`
      redirection, and pass `bash -n`.
      Verify: `bash -n plugins/edm/bin/edm-lint-artifacts` and
      `grep -nE 'declare -A|mapfile|readarray|\{fd\}' plugins/edm/bin/edm-lint-artifacts` returns
      nothing.
- [ ] AC12 (no hook change, docs updated): no hook change is needed --
      `hooks/hooks.json:80-90` already invokes the linter -- and the `CLAUDE.md` `bin/` table
      description of `edm-lint-artifacts` is updated to describe four violation classes.
      Verify: `git diff --stat plugins/edm/hooks/hooks.json` is empty and
      `grep -n 'four violation classes' plugins/edm/CLAUDE.md`.

### Technical Notes

- The commit-path budget matters: this linter runs on `git commit` and blocks the commit on non-zero
  exit. The short-circuit in AC10 is the difference between a 3s hook and an 8s one on a large
  initiative directory.
- Span detection in POSIX grep is approximate. Bias toward false negatives in ambiguous cases and let
  EDMV3-T44's corpus decide -- a false positive blocks a commit and is a release blocker (RK-10),
  while a false negative is a missed diagram bug the auditing agents also look for.
- `grep -P` is not available on all macOS userlands. Follow the existing PCRE-detection-and-fallback
  pattern at `bin/edm-lint-artifacts:49-53` (EDMV3-106).
- The hazard AC8 references is already live: the header block runs to line 22 while `usage()` prints
  only `2,19p`, so lines 20-22 are truncated today, before this initiative adds anything.

### Out of Scope

- The `usage()` sentinel refactor -- EDMV3-T61.
- The fixture corpus -- EDMV3-T44.
- Correcting any existing committed diagram this class flags -- EDMV3-T44 AC7 handles that.

---

## EDMV3-T44: A fixture corpus proves the lint class has zero false positives

| Field | Value |
|---|---|
| Epic | E6 -- Mermaid rule |
| Wave | B |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV3-57 |
| Depends On | EDMV3-T19, EDMV3-T43 |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/tests/fixtures/mermaid/valid/` (new), `plugins/edm/bin/tests/fixtures/mermaid/invalid/` (new), `plugins/edm/bin/tests/wave7-smoke.sh`, `.gitlab-ci.yml` |

### Description

Explorer 01 risk R4. Bracket and quote span detection in POSIX grep is approximate, and a false
positive **blocks a commit**, so the failure mode is high-friction. The class must be proven against a
corpus before it is trusted on the commit path.

### Acceptance Criteria

- [ ] AC1 (corpus size and split, both floors asserted separately): a fixture corpus of at least 15
      Mermaid diagrams is committed under `plugins/edm/bin/tests/fixtures/mermaid/`, split into a
      `valid/` set that must produce zero violations and an `invalid/` set where every file has a
      known expected violation line. **Each side carries its own floor**: at least **10** files in
      `valid/` and at least **5** in `invalid/`. A single combined floor of 15 is satisfiable by 15
      valid fixtures and zero invalid ones, which would prove the class never fires rather than that
      it fires correctly -- and the valid side needs the larger floor because AC2 enumerates nine
      distinct legal cases it must cover.
      Verify: `ls plugins/edm/bin/tests/fixtures/mermaid/valid/*.md | wc -l` is at least 10,
      `ls plugins/edm/bin/tests/fixtures/mermaid/invalid/*.md | wc -l` is at least 5, and their sum
      is at least 15.
- [ ] AC2 (valid coverage): the `valid/` set covers at minimum entity codes `#59;`, `#quot;` and
      `#35;`; statement-terminating semicolons; `%%` comment lines containing semicolons; `classDef`,
      `style` and `linkStyle` directives; a `sequenceDiagram` with clean messages; a `flowchart` with
      quoted labels containing commas and parentheses; and a diagram inside a non-Mermaid fence that
      must be ignored entirely.
      Verify: `grep -l '#quot;' plugins/edm/bin/tests/fixtures/mermaid/valid/*` and equivalent greps
      for each listed case return a file.
- [ ] AC3 (invalid coverage): the `invalid/` set covers at minimum a raw `;` inside `[...]`, inside
      `"..."`, inside an edge `|...|` label, inside `{...}`, and in a `sequenceDiagram` message after
      the `:`.
      Verify: `ls plugins/edm/bin/tests/fixtures/mermaid/invalid/` shows one file per case, each with
      an `expected-line:` comment at the top.
- [ ] AC4 (positive and negative, exact expected set): a smoke test runs the class over the corpus
      and asserts exactly the expected violation set -- zero false positives and zero false
      negatives.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "mermaid corpus: exact violation
      set").
- [ ] AC5 (false positives are a release blocker): the test fails if any `valid/` file produces a
      violation. False positives are a release blocker, not a warning.
      Verify: add a legal `#59;` to a `valid/` fixture and confirm the suite still passes; add a raw
      `;` to it and confirm the suite fails.
- [ ] AC6 (CI): the corpus test runs in CI.
      Verify: `grep -n 'wave7-smoke' .gitlab-ci.yml`.
- [ ] AC7 (existing committed diagrams): any Mermaid diagram already committed under tracked `SRD/`
      trees is linted as part of `--all` and either passes or is corrected in the same MR.
      Verify: `bash plugins/edm/bin/edm-lint-artifacts --all; echo "exit=$?"` prints `exit=0`, and
      the MR lists any diagram corrected.
- [ ] AC8 (shared helpers): the suite uses the `_harness.sh` helpers rather than hand-rolling
      assertions.
      Verify: `grep -c 'check_fails\|check ' plugins/edm/bin/tests/wave7-smoke.sh` is non-zero and
      `grep -c 'mktemp -d' plugins/edm/bin/tests/wave7-smoke.sh` is 0.

### Technical Notes

- Each `invalid/` fixture should carry its expected violation line as a comment on line 1 so the test
  reads ground truth from the fixture rather than from a parallel list that can drift.
- This pack's own README contains a Mermaid diagram with `#59;`-free labels and `classDef` lines
  without trailing semicolons. It is a live subject for AC7.
- The corpus is also the regression suite for any future tightening of the span detection. Say so in
  a `fixtures/mermaid/README.md` so a later contributor extends the corpus rather than loosening the
  guards.

### Out of Scope

- Renderer validation. Explicitly forbidden by D8 / EDMV3-88 -- this corpus validates the *rule*, not
  the renderer.
- The lint class itself -- EDMV3-T43.
