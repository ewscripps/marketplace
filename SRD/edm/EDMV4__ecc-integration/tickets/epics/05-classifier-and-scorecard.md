# Epic 05: Classifier and Scorecard

This epic covers the two routing-and-measurement scope items: item 4.3, the orchestrator size
classifier (`EDMV4-T34` adds the Step 1b.5 pre-step and the missing `lifecycle_mode` write path,
`EDMV4-T35` pins the eight-enum backstop, `EDMV4-T36` adds the security-trigger tie-breaker and the
compliance pre-selection, `EDMV4-T37` enforces guard D6 so the classifier never restates the mode
matrix), and item 5.2, the repo-readiness scorecard (`EDMV4-T38` creates
`bin/edm-repo-readiness` following house conventions, `EDMV4-T39` implements the six-category
0-10 rubric with conditional applicability and a version string, `EDMV4-T40` wires each category to
the signals EDM already computes rather than re-detecting them, and `EDMV4-T41` joins the two halves
by feeding the score into the classifier and into `planning.md`). The two halves are independent
until `EDMV4-T41`: `EDMV4-T34` and `EDMV4-T38` are both unblocked from day one.


> **Line numbers in this epic are ADVISORY (ticket-pack audit P1-2).** Every `file:line` citation
> here -- including the "stale SRD citations, corrected" tables in the Technical Notes below -- was
> verified against the **pre-fast-forward** tree. The fast-forward's `6e29dcb` re-inserted four
> lines at `bin/edm-state:504-507`, so this epic's corrections are now wrong where the SRD is
> right: `ALL_LENS_IDS` is at **1613**, `MODE_ENUM_LIST` at **807**, `state_anomalies()` at
> **1709**. Symbols above line 4000 have drifted further than either document.
>
> **Locate every site by symbol name or by the literal string the AC quotes, at edit time.** Do not
> "correct" `srd.md` toward any number in this pack -- see `EDMV4-T08` AC8.

---

## EDMV4-T34: Add a size-classifier pre-step and a lifecycle_mode write path to the orchestrator dialog

| Field | Value |
|---|---|
| Epic | Classifier and Scorecard |
| Phase | 3 |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV4-19 |
| Depends On | none |
| Target Components | `plugins/edm/skills/orchestrator/SKILL.md:103-114`, `:107-108`, `:111-112`, `:90-95`, `plugins/edm/bin/edm-state` (`cmd_set_mode`), `plugins/edm/CLAUDE.md Sec."EDM mode matrix"` |

### Description
EDM already has the destinations: five `mode` values and three `lifecycle_mode` values which between
them can collapse the six phases down to a single ticket-pack review gate. What EDM lacks is the
routing. Today a user must already know that `lifecycle_mode=fix-pack` exists and set it by hand, so
someone arriving with a 20-line bug fix and no prior EDM knowledge gets the full six-phase flow by
default. This ticket adds a classifier as a new Step 1b.5, immediately after prefix and product
resolution and before the existing Step 1c mode dialog. It scores three signals (files touched, new
dependency or contract, design ambiguity), takes the highest tier any one signal reaches, and
pre-selects the resulting recommendation as the "(Recommended)" annotation on the existing
`AskUserQuestion`.

The orchestrator has no `lifecycle_mode` write path today, and a `fix-pack` recommendation needs
one. Step 1c.1 offers `mode` values only (Standard / mini-SRD / IaC / Data-ML / Prototype,
`skills/orchestrator/SKILL.md:107-108`), and Step 1c.3 records exactly two things,
`set-mode <PREFIX> mode <value>` and `set-mode <PREFIX> compliance_enabled true` (`:111-112`).
`lifecycle_mode` is never written by the orchestrator at any step. So this ticket adds a
`lifecycle_mode` question to the dialog and a `set-mode <PREFIX> lifecycle_mode <value>` call to the
recording step. Restricting the classifier to the values Step 1c.1 already offers is the rejected
alternative: it would delete the `fix-pack` tier, which is the classifier's whole reason for
existing.

The premise (that the six-phase default costs EDM anything in practice) is unmeasured. The analysis
says so itself and the argument is structural only. That does not change the work, but it belongs in
the ticket so nobody later cites a measurement that was never taken.

### Acceptance Criteria
- [ ] AC1: `skills/orchestrator/SKILL.md` gains a **Step 1b.5** section positioned after Step 1b and
      before Step 1c (currently `:103-114`), and it carries the same "Skipped on resume" line Step
      1c carries at `:105`.
- [ ] AC2: Step 1b.5 states that it scores exactly three signals -- files touched, new dependency or
      contract, and design ambiguity -- and that the **highest** tier any single signal reaches
      wins. The text explicitly says it is not an average.
- [ ] AC3: Step 1b.5 enumerates exactly three output pairs and no others:
      trivial -> `(mode=standard, lifecycle_mode=fix-pack)`;
      small -> `(mode=mini-srd, lifecycle_mode=standard)`;
      full -> `(mode=standard, lifecycle_mode=standard)`. Both members of the pair are always
      stated, because the two enum families are orthogonal and every initiative carries a value from
      each.
- [ ] AC4: Step 1b.5 states in one line that `fast-track` is never emitted, because `fast-track` and
      `fix-pack` share one row in the mode matrix and are documented as behaviourally identical, so
      distinguishing them would require splitting that row (out of scope).
- [ ] AC5: The computed recommendation is stated in **one line inside the `AskUserQuestion` body**,
      with its reasoning, and that line names **both** members of the pair it picked.
- [ ] AC6: Step 1c gains a **`lifecycle_mode` question** presenting Standard / fast-track /
      fix-pack, using the same `AskUserQuestion` form as the existing mode question at `:107-108`
      and the same `<=12`-character header constraint. It carries a "(Recommended)" annotation set
      by Step 1b.5.
- [ ] AC7: Step 1c's recording step (`:111-112`) gains
      `edm-state set-mode <PREFIX> lifecycle_mode <value>` alongside the existing
      `set-mode <PREFIX> mode <value>`, and the skill states it is called **only when the selected
      value is not the `standard` default**, matching how `compliance_enabled` is recorded only when
      On.
- [ ] AC8: Both new writes go through `cmd_set_mode` in `bin/edm-state`. A grep of
      `skills/orchestrator/SKILL.md` finds no `jq` write, no `edm-state set`, and no other path that
      sets `mode` or `lifecycle_mode` -- exactly one write mechanism per field.
- [ ] AC9: The recommendation only sets which existing option carries "(Recommended)". Step 1b.5's
      text states it never auto-applies a mode and never calls `set-mode` itself; the user confirms
      or overrides via the Step 1c dialog.
- [ ] AC10: An override is always available, and whatever the user selects (recommended or not) is
      recorded through the same `edm-state set-mode <PREFIX> mode|lifecycle_mode <value>` path. The
      skill states the classifier is a default, not an enforcement.
- [ ] AC11: The new lifecycle question is **skipped on resume** together with the rest of Step 1c.
      The resume branch at `:90-95` is left unmodified: it already reads all four mode-family fields
      including `lifecycle_mode` and already states which lifecycle applies, so only the write side
      was missing.
- [ ] AC12: Step 1b.5's prose is **under 30 lines**, consistent with the dispatcher's role as a
      dispatcher. `bash plugins/edm/bin/tests/run-all.sh` passes, `edm-check-skill-sync` included
      (it asserts the dispatcher holds no phase procedure body).

### Technical Notes
- **Citations verified against the current branch tree.** `skills/orchestrator/SKILL.md`'s cited
  ranges hold exactly: Step 1c is `:103-114`, the mode-only `AskUserQuestion` is `:107-108`, the
  recording step is `:111-112`, and the resume branch is `:90-95`. The `bin/edm-state` citations in
  the SRD are **stale by 4 lines** against this tree: `cmd_set_mode` starts at `:5059` (SRD says
  5063-5114) and ends at `:5112`. Cite the function by name, not by line, and re-check before
  quoting a line number.
- `cmd_set_mode` already accepts `lifecycle_mode` as a `kind` -- see the `lifecycle_mode)` arm and
  its `LIFECYCLE_MODE_ENUM_LIST` word-membership test. No `bin/edm-state` change is needed for the
  write to work; this ticket is prose-only in `SKILL.md`.
- Note the asymmetry between the two `cmd_set_mode` arms: the `mode)` arm also seeds
  `skipped_phases` via `default_skipped_phases_json_for_mode`, while the `lifecycle_mode)` arm
  writes the field and nothing else. Do not describe them as symmetric in the skill text.
- `AskUserQuestion` headers are 12 characters or fewer per `Sec."Gate PROTOCOL"`. "Lifecycle" fits;
  "Lifecycle mode" does not.
- The translation source cited by the SRD (`ECC/skills/orch-pipeline/SKILL.md:39-54`, the four-tier
  table and the highest-tier-wins rule) is **not present in this repository**. Treat the SRD's
  restatement of the rule as the authority; do not attempt to re-verify against a path that does not
  exist here.

### Out of Scope
- The enum backstop and its smoke tests (`EDMV4-T35`).
- The security-trigger tie-breaker and the compliance pre-selection (`EDMV4-T36`).
- The D6 no-restatement guard and its scoped grep assertion (`EDMV4-T37`).
- Consuming the repo-readiness score as a fourth input (`EDMV4-T41`).
- Splitting the `fast-track` / `fix-pack` row of the mode matrix.
- Any change to `bin/edm-state`, `CLAUDE.md Sec."EDM mode matrix"`, or the resume branch itself.

---

## EDMV4-T35: Pin the classifier to the eight existing mode enum values

| Field | Value |
|---|---|
| Epic | Classifier and Scorecard |
| Phase | 3 |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV4-20 |
| Depends On | EDMV4-T34 |
| Target Components | `plugins/edm/bin/edm-state:803-804` (`MODE_ENUM_LIST`, `LIFECYCLE_MODE_ENUM_LIST`), `cmd_set_mode` validation, `terminal_phase_for_mode`, `code_audit_required_for_mode`, `convergence_exempt`, `plugins/edm/skills/orchestrator/SKILL.md`, `plugins/edm/bin/tests/wave8-smoke.sh` (new) |

### Description
`MODE_ENUM_LIST="standard mini-srd iac data-ml prototype"` and
`LIFECYCLE_MODE_ENUM_LIST="standard fast-track fix-pack"` are validated in `cmd_set_mode` as a hard
refusal: any value outside them dies with `set-mode: invalid mode '<value>'`. The two families are
orthogonal -- an initiative can be `mode=iac` and `lifecycle_mode=fast-track` simultaneously -- and
the source analysis's four-tier scheme does not map onto either family alone; its own suggested
mapping mixes the two families inside one tier list.

This ticket records the backstop explicitly and proves it with tests, so no future ticket attempts
to invent a bespoke "trivial" state distinct from `fix-pack`. Doing so would require new arms in
`terminal_phase_for_mode`, `code_audit_required_for_mode` and `convergence_exempt` as well, a far
larger change than a classifier warrants. The failure mode this guards is not silent --
`cmd_set_mode` dies loudly -- but a ticket written against a nonexistent enum value still wastes an
implementation wave before anyone runs the command.

The important subtlety is that a bare value does not determine its `kind`. The two families overlap
on `standard` and are disjoint everywhere else, so the tests name the `kind` per value rather than
asserting "each of the three emitted values", which is not mechanically executable.

### Acceptance Criteria
- [ ] AC1: Every value the classifier can emit is a member of `MODE_ENUM_LIST` or
      `LIFECYCLE_MODE_ENUM_LIST`. There are exactly **8** such values across the two lists.
- [ ] AC2: The diff for this initiative leaves `MODE_ENUM_LIST` and `LIFECYCLE_MODE_ENUM_LIST`
      **unmodified**. A smoke assertion pins both strings literally, so a future edit to either list
      fails a test rather than silently widening the classifier's reachable set.
- [ ] AC3: The classifier's two-axis mapping is stated in `skills/orchestrator/SKILL.md` as one row
      per tier, naming both the `mode` and the `lifecycle_mode` it recommends -- the same three
      literal pairs enumerated in `EDMV4-T34` AC3, and no others.
- [ ] AC4: `terminal_phase_for_mode`, `code_audit_required_for_mode` and `convergence_exempt` gain
      **no new arms**. A smoke assertion counts the arms in each and fails on a change.
- [ ] AC5: A smoke test drives each recommended pair through `edm-state set-mode` with the correct
      `kind` per member and asserts each call exits 0:
      `set-mode <PREFIX> lifecycle_mode fix-pack`; `set-mode <PREFIX> mode mini-srd`;
      `set-mode <PREFIX> mode standard` **and** `set-mode <PREFIX> lifecycle_mode standard`.
- [ ] AC6: A smoke test asserts a hypothetical fourth value is refused:
      `set-mode <PREFIX> mode trivial` exits non-zero and its stderr contains
      `set-mode: invalid mode 'trivial'`.
- [ ] AC7: A smoke test asserts a **valid value driven through the wrong `kind`** is likewise
      refused -- `set-mode <PREFIX> mode fix-pack` exits non-zero with
      `set-mode: invalid mode 'fix-pack'`, and `set-mode <PREFIX> lifecycle_mode mini-srd` exits
      non-zero with `set-mode: invalid lifecycle_mode 'mini-srd'`. This is the case a classifier bug
      would actually produce.
- [ ] AC8: The new assertions live in a suite `bin/tests/run-all.sh` discovers, and
      `bash plugins/edm/bin/tests/run-all.sh` passes.

### Technical Notes

- **Dependency direction is inverted from `srd.md`, deliberately (ticket-pack audit P1-11).**
  `srd.md` declares `EDMV4-19`'s dependency as `EDMV4-20`; this pack has `EDMV4-T34` depending on
  nothing and `EDMV4-T35` depending on `EDMV4-T34`. The pack's direction is the executable one:
  AC1 ("Every value the classifier can emit is a member of ...") and AC3 (the three literal pairs
  enumerated in `EDMV4-T34`) are unverifiable before the classifier exists. This is the same
  completion-versus-specification argument `EDMV4-T28` already uses, and the reason it is recorded
  here is that it was the one inversion in the pack with no written rationale -- epic 04 documents
  every one of its own.
- **Citation drift.** The SRD cites `bin/edm-state:807-808` for the two enum lists; on the current
  branch they are at **`:803-804`**. Likewise `cmd_set_mode` is `:5059-5112` (not 5063-5114), the
  `mode` refusal is `:5067-5070` (not 5071-5074), and the `lifecycle_mode` refusal is `:5089-5092`
  (not 5093-5096). The three helper functions are at `terminal_phase_for_mode()` `:821`,
  `code_audit_required_for_mode()` `:948`, `convergence_exempt()` `:983` -- all four lines earlier
  than the SRD states. Anchor assertions on function names and literal strings, never on line
  numbers, so this class of drift cannot recur.
- `cmd_set_mode` validates by word membership against the list variable
  (`case " $MODE_ENUM_LIST " in *" $value "*)`), not a second case-literal list. Any assertion that
  greps for a duplicated enum literal elsewhere in the file is asserting the wrong thing.
- Both refusals go through `die`, which exits 2. Assert on the message text as well as the exit
  code -- a bare non-zero assertion would also pass on an unrelated `require_jq` failure.
- `bin/tests/wave8-smoke.sh` does not exist yet on this branch; it is created by this epic's work
  and shared with `EDMV4-T37`. Whichever ticket lands first creates it; the second appends a banner
  section rather than overwriting.
- Bash 3.2 floor: no associative arrays, no `${var^^}`, no `mapfile` in the new test code. Required
  binaries stay `bash`, `jq`, `git`.

### Out of Scope
- Adding, removing or renaming any enum value.
- Splitting the `fast-track` / `fix-pack` row of the mode matrix so a classifier could distinguish
  them.
- The classifier's scoring logic itself (`EDMV4-T34`).
- The D6 restatement grep (`EDMV4-T37`).

---

## EDMV4-T36: Implement the security-trigger tie-breaker and pre-select the compliance dialog

| Field | Value |
|---|---|
| Epic | Classifier and Scorecard |
| Phase | 3 |
| Priority | Should Have |
| Size | S |
| SRD Refs | EDMV4-21 |
| Depends On | EDMV4-T34 |
| Target Components | `plugins/edm/skills/orchestrator/SKILL.md:103-114` (Steps 1c.1 and 1c.2), `plugins/edm/CLAUDE.md Sec."EDM mode matrix"` (the `compliance_enabled` Gate 3.5 paragraph) |

### Description
The tie-breaker taken from ECC is that anything touching a security trigger or a public API or
contract is **at least** standard, regardless of file count. The seven triggers are authentication
or authorization, user-input handling, database queries, filesystem paths, external API calls,
cryptography, and secrets or credentials. Without the tie-breaker, a two-file change to an auth
path scores trivial on all three signals and routes to `fix-pack`, which is exactly the routing
error that would make the classifier a net negative.

The source citation matters here. The seven triggers come from `orch-pipeline/SKILL.md:100-104`,
**not** from `rules/common/security.md` -- that file contains an unrelated 8-item pre-commit
checklist, and the misattribution originated in ECC's own parenthetical citation, which the source
analysis repeated without checking.

The analysis also claimed the tie-breaker "composes cleanly with EDM's existing `compliance_enabled`
Gate 3.5", which understates the work: compliance is a **second, independent** `AskUserQuestion` at
Step 1c.2 whose default would also need pre-selecting. This ticket does that pre-selection rather
than assuming it away.

### Acceptance Criteria
- [ ] AC1: The tie-breaker is implemented in Step 1b.5: a hit on any of the seven triggers, or on a
      public API or contract change, forces the recommendation to at least `standard`, overriding a
      lower tier computed from the three signals.
- [ ] AC2: The seven triggers are enumerated in the skill exactly as listed -- authentication or
      authorization, user-input handling, database queries, filesystem paths, external API calls,
      cryptography, secrets or credentials -- with no additions and no omissions.
- [ ] AC3: The source cited for the triggers is `orch-pipeline/SKILL.md`. A grep of
      `skills/orchestrator/SKILL.md` for `rules/common/security.md` returns nothing.
- [ ] AC4: When the tie-breaker fires, the classifier **also** pre-selects **On** for the Step 1c.2
      compliance dialog, so "(Recommended)" moves from Off to On for that run.
- [ ] AC5: When the tie-breaker fires, the one-line reasoning **names the trigger that fired** (for
      example "authentication or authorization"), not merely that a trigger fired.
- [ ] AC6: When the tie-breaker does not fire, the compliance dialog's default is unchanged and
      still reads "Off (Recommended)" exactly as it does today at `:109-110`.
- [ ] AC7: The compliance pre-selection is a recommendation only. The skill states the user can
      still choose Off, and the choice is recorded through the existing
      `edm-state set-mode <PREFIX> compliance_enabled true` path (written only when On), with no new
      write path introduced.
- [ ] AC8: A smoke test asserts a trigger hit produces at least `standard`: given a scenario where
      all three signals score trivial and one trigger is present, the recommended pair is
      `(mode=standard, lifecycle_mode=standard)` and not the trivial tier's
      `(mode=standard, lifecycle_mode=fix-pack)`. The test is registered in a suite
      `bin/tests/run-all.sh` discovers.

### Technical Notes
- **Citations.** `skills/orchestrator/SKILL.md:103-114` (Step 1c) and the compliance toggle at
  `:109-110` both hold on the current branch. The ECC translation source
  (`ECC/skills/orch-pipeline/SKILL.md:100-104`) is **not present in this repository**, so the seven
  triggers cannot be re-verified against it from here; the SRD's enumeration is the working
  authority, and AC2 pins it.
- The tie-breaker is a floor, not a ceiling. It raises a trivial or small recommendation to
  `standard`; it must never lower a `standard` recommendation, and it never touches `mode` values
  other than `standard` (a classifier that computed `mini-srd` and hits a trigger goes to
  `(standard, standard)`, not to `(mini-srd, standard)`).
- `compliance_enabled` inserts Gate 3.5 between Gate 3 and Phase 6 and adds regulatory-traceability
  columns to ticket ACs. Do **not** restate that behaviour in Step 1b.5 -- cite
  `CLAUDE.md Sec."EDM mode matrix"` by section reference (see `EDMV4-T37`).
- `cmd_set_mode`'s `compliance_enabled` arm accepts only the literal strings `true` or `false` and
  dies otherwise. The existing skill text writes `true` only; keep it that way rather than adding a
  `false` write for the Off case.

### Out of Scope
- Any change to Gate 3.5's own behaviour, its prompt, or `skills/audit-tickets/SKILL.md`.
- Recording `compliance_enabled false` explicitly when the user selects Off.
- Detecting the triggers automatically by scanning the repository; the classifier reasons about the
  described change, it does not run a scanner.
- The three base signals themselves (`EDMV4-T34`).

---

## EDMV4-T37: Enforce guard D6 so the classifier never restates the mode matrix

| Field | Value |
|---|---|
| Epic | Classifier and Scorecard |
| Phase | 3 |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV4-22 |
| Depends On | EDMV4-T34 |
| Target Components | `plugins/edm/skills/orchestrator/SKILL.md:103-114`, `plugins/edm/CLAUDE.md Sec."EDM mode matrix"`, `plugins/edm/CLAUDE.md Sec."Prompt conventions (house style)"` (guard D6), `plugins/edm/bin/tests/wave8-smoke.sh` (new) |

### Description
`CLAUDE.md`'s do-NOT-adopt guard **D6** states: do not duplicate the mode matrix into agent prompts,
since it is state-backed and read at runtime. The stated cost of ignoring it is the same drift the
whole guard set exists to remove -- two copies of the same behaviour-governing text disagree,
silently, the next time one of them is edited.

Step 1c.4 already models the correct pattern: "Mode-family fields and each mode's full behavior are
`CLAUDE.md Sec.\"EDM mode matrix\"` -- consult it before dispatching; do not restate the sub-flows
here." A classifier that inlines even a brief description of what `fix-pack` or `mini-srd` do, in
order to justify its recommendation, violates D6. The justification the classifier owes the user is
about the **classification** (which signals scored what tier), not about the destination's
behaviour.

The assertion's scope is the critical design detail. It greps **Step 1b.5's block only**, delimited
by its own heading and the next heading. A tree-wide grep fails on correct code the day it is
written, because those phrases legitimately appear in `skills/tickets/SKILL.md` and
`skills/srd/SKILL.md` -- that is the mode matrix's own "owning phase skill" design working as
intended.

### Acceptance Criteria
- [ ] AC1: Step 1b.5's text contains **no** description of what any `mode` or `lifecycle_mode` value
      does. It names the value and cites `CLAUDE.md Sec."EDM mode matrix"` by section reference,
      following the pattern Step 1c.4 already uses at `:113-114`.
- [ ] AC2: The one-line reasoning explains the classification -- which of the three signals scored
      what tier, or which security trigger fired -- and never the destination's behaviour.
- [ ] AC3: A smoke assertion extracts **Step 1b.5's block only**, delimited by its own heading and
      the next heading in `skills/orchestrator/SKILL.md`, and greps that extract for restatement
      phrases including at minimum "Phases 1, 2, 3, 5 recorded", "fuse into one audited file" and
      "Tickets generated directly from". It fails if any appears within that block.
- [ ] AC4: The assertion's scope is the block, not the tree. A run of the assertion against the
      unmodified tree passes even though those phrases exist in `skills/tickets/SKILL.md` and
      `skills/srd/SKILL.md`.
- [ ] AC5: The assertion is proven to discriminate by a **positive control**: the test copies
      `SKILL.md` to a scratch path, inserts one restatement phrase **inside** Step 1b.5, and asserts
      the check fails on that copy while passing on the unmodified tree. A test that only ever
      asserts the passing direction is not sufficient.
- [ ] AC6: The mode-matrix text in `CLAUDE.md Sec."EDM mode matrix"` is byte-unmodified by this
      initiative, and the D6 text in `CLAUDE.md Sec."Prompt conventions (house style)"` is likewise
      unmodified.
- [ ] AC7: The no-restatement requirement is stated in the 4.3 work's own skill text (a single line
      in Step 1b.5 citing guard D6), so the constraint travels with the work rather than living only
      in the SRD.
- [ ] AC8: The assertion lives in a suite `bin/tests/run-all.sh` discovers, and
      `bash plugins/edm/bin/tests/run-all.sh` passes.

### Technical Notes
- **Citations verified.** Step 1c.4's exemplar text is at `skills/orchestrator/SKILL.md:113-114` on
  the current branch, and guard D6 is in `CLAUDE.md` under "Do-NOT-adopt guards" within
  Sec."Prompt conventions (house style)". Both hold.
- Block extraction under the bash 3.2 floor: use `awk '/^\*\*Step 1b\.5/{f=1;next} /^\*\*Step /{f=0}
  f'` or an equivalent sed range. Do **not** use `mapfile` or an associative array of phrases -- a
  space-separated string plus a `for` loop, or a heredoc read line by line, is the portable form.
  `bin/_edm-cli-lib.sh`'s `print_help` is the in-repo precedent for exactly this sentinel-delimited
  awk extraction.
- The delimiter must not be the literal string "next heading" interpreted loosely: pick the actual
  heading form Step 1b.5 uses (matching Step 1c's `**Step 1c -- ...**` bold-line form) and assert
  the extract is non-empty before grepping it. An empty extract must fail the test, not pass it
  vacuously -- that is the single most likely way this assertion silently stops checking anything.
- The phrase list is drawn from the mode-matrix rows in `CLAUDE.md`. Keep it as a small explicit
  list; a regex broad enough to catch every possible restatement will also catch legitimate text.
- `bin/tests/wave8-smoke.sh` is new. If `EDMV4-T35` has already created it, append a banner section
  rather than overwriting the file.

### Out of Scope
- Auditing any other skill or agent for D6 compliance; the scope is Step 1b.5's block.
- Editing `CLAUDE.md Sec."EDM mode matrix"` or the mode matrix itself.
- A tree-wide restatement grep, which the SRD explicitly rejects as failing on correct code.
- The classifier's scoring logic, tie-breaker, or enum backstop (`EDMV4-T34`, `EDMV4-T35`,
  `EDMV4-T36`).

---

## EDMV4-T38: Create bin/edm-repo-readiness following bin/ house conventions

| Field | Value |
|---|---|
| Epic | Classifier and Scorecard |
| Phase | 3 |
| Priority | Should Have |
| Size | S |
| SRD Refs | EDMV4-36 |
| Depends On | none |
| Target Components | `plugins/edm/bin/edm-repo-readiness` (new), `plugins/edm/bin/_edm-cli-lib.sh`, `plugins/edm/bin/edm-lint-artifacts:74`, `plugins/edm/bin/edm-compare-eval:39,44-48`, `plugins/edm/bin/tests/timing.sh:26`, `plugins/edm/CLAUDE.md Sec."bin/ helper scripts"` |

### Description
EDM measures *itself* via `/edm:metrics` -- time and cost per phase -- but never scores the
*repository it is about to work in*, which is exactly the information that should feed the 4.3
classifier. This ticket creates the script and its conventions surface; the rubric content lands in
`EDMV4-T39` and the signal wiring in `EDMV4-T40`.

ECC's `harness-audit.js` is not reusable. In repo mode its checks are almost entirely `fileExists`
against ECC's own bundled paths, which is an ECC installation-completeness check rather than a
readiness rubric. Take the shape, reject the content: EDM writes its own check table as a new `bin/`
script following the conventions every existing script in `bin/` already shares.

Those conventions are not optional decoration. `_edm-cli-lib.sh`'s `print_help`, the one-line
`SCRIPT_DIR` idiom, the two-argument `die()`, and the text-to-stdout / JSON-to-file split are what
make eleven scripts in `bin/` behave the same way from a skill's point of view. A twelfth script
that invents its own shape is a maintenance tax paid forever.

### Acceptance Criteria
- [ ] AC1: `plugins/edm/bin/edm-repo-readiness` exists, has the executable bit set
      (`test -x` passes), and is listed as a new row in
      `plugins/edm/CLAUDE.md Sec."bin/ helper scripts"`.
- [ ] AC2: The script sources `_edm-cli-lib.sh` and implements `--help` by calling the shared
      `print_help "${BASH_SOURCE[0]:-$0}"` against its own
      `# EDM-HELP-BEGIN` / `# EDM-HELP-END` sentinel block. It contains no hardcoded `sed -n 'A,Bp'`
      line range.
- [ ] AC3: `edm-repo-readiness --help` exits 0 and prints the sentinel block's contents, including
      the usage line `edm-repo-readiness [<PREFIX>] [--json <path>]`.
- [ ] AC4: `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"` is computed once near the
      top, byte-matching the idiom at `edm-lint-artifacts:74`, `edm-compare-eval:39` and
      `edm-state:61`.
- [ ] AC5: The script carries a local two-argument `die()` helper (`msg`, `code="${2:-2}"`), matching
      the form present verbatim at `edm-compare-eval:44-48` and in `evals/run-eval.sh`.
- [ ] AC6: Exit codes follow the contract: **0** when the repository was scored, regardless of how
      low the score is; **2** for a usage or setup error (unknown flag, `--json` with no path,
      missing `jq`). A smoke test asserts a deliberately low-scoring fixture still exits 0.
- [ ] AC7: Human-readable text goes to **stdout**; machine-readable JSON goes to a **file** via
      `--json <path>`, produced with `jq -n`. There is **no** `--json`-to-stdout flag, matching every
      other script in `bin/`; a grep confirms stdout carries no JSON document.
- [ ] AC8: `set -euo pipefail` is set, or a deliberate deviation is documented in-file with its
      reason, following `evals/run-eval.sh`'s CA-074 precedent.
- [ ] AC9: The script is bash 3.2 compatible -- no associative arrays, no `${var^^}`, no `mapfile`,
      no `declare -A` -- and adds no required binary beyond `bash`, `jq` and `git`. A grep for those
      four constructs over the new file returns nothing.

### Technical Notes
- **All bin/ citations verified on the current branch**: `edm-lint-artifacts:74` and
  `edm-compare-eval:39` carry the `SCRIPT_DIR` idiom exactly as quoted, `edm-compare-eval:44` opens
  the `die()` helper, and `bin/tests/timing.sh:26` carries a near-identical `SCRIPT_DIR` line that
  differs only in using `${BASH_SOURCE[0]}` without the `:-$0` fallback. Copy the
  `edm-lint-artifacts:74` / `edm-compare-eval:39` form (with the fallback), not `timing.sh`'s.
- `print_help` is a one-line awk extractor
  (`awk '/^# EDM-HELP-BEGIN/{f=1;next} /^# EDM-HELP-END/{f=0} f'`) at
  `bin/_edm-cli-lib.sh:29-31`, and callers pass their own path explicitly. Source the library
  relative to `SCRIPT_DIR`, not relative to the caller's cwd.
- `bin/` scripts operate against the project's working directory and use no plugin-relative paths
  for project data. The `--json <path>` target is resolved against the caller's cwd.
- `jq -n` with `--arg` / `--argjson` is the house form for constructing JSON. Do not build JSON by
  string concatenation; a repository path containing a quote would produce invalid output.
- The `<PREFIX>` argument is optional. With no prefix the script scores the repository as a whole;
  the per-initiative behaviour and the no-initiatives case are specified by `EDMV4-T40`.

### Out of Scope
- The six categories, their point budgets, the 0-10 normalization and `READINESS_RUBRIC_VERSION`
  (`EDMV4-T39`).
- Wiring the checks to `edm-state validate` / `session-start` / `get-coverage` / `metrics-report`
  (`EDMV4-T40`).
- Any integration into `skills/plan/SKILL.md` or the classifier (`EDMV4-T41`).
- Porting any part of ECC's `harness-audit.js` check content.

---

## EDMV4-T39: Implement the six-category rubric with 0-10 normalization and a version constant

| Field | Value |
|---|---|
| Epic | Classifier and Scorecard |
| Phase | 3 |
| Priority | Should Have |
| Size | M |
| SRD Refs | EDMV4-37 |
| Depends On | EDMV4-T38 |
| Target Components | `plugins/edm/bin/edm-repo-readiness` (new), `plugins/edm/evals/score-artifacts.sh:139` (`SCORER_VERSION` precedent), `plugins/edm/bin/edm-compare-eval:85-91` (refuse-on-version-mismatch precedent) |

### Description
Four properties of ECC's rubric shape transfer, and they are the whole of what transfers: a fixed
category list each normalized 0-10 so scores are comparable across runs; a versioned rubric string
so a score can be traced to the rubric that produced it; conditional applicability where the
denominator adjusts rather than penalizing absence; and per-check determinism so the same commit
always scores the same.

The initial category set is fixed by the SRD: **Methodology setup** (10 pts, not conditional),
**State health** (10, not conditional), **Test stack** (10, conditional on any test framework being
detected at all), **Coverage posture** (10, conditional on Test stack being applicable),
**Convergence history** (10, conditional on at least one archived initiative existing), and
**Artifact hygiene** (10, not conditional). Six categories, 60 raw points, each normalized to 0-10,
with the overall score reported as the mean of **applicable** categories only. Three are
conditional, so a greenfield repository with no tests and no history scores out of three categories
rather than being penalized for the absence of things it cannot have.

This is the initial rubric, not a permanent one. It is expected to change, which is exactly what
`READINESS_RUBRIC_VERSION` exists for. Note correction 7 from the analysis: ECC's headline
"11 checks / 29 points" for consumer mode undercounts, because five GitHub checks worth 10 more
points are appended unconditionally, making the real surface 16 checks / 39 points. EDM places
shared checks deliberately rather than inheriting that ambiguity.

### Acceptance Criteria
- [ ] AC1: The six categories are implemented with their stated 10-point budgets and their stated
      conditional markers: Methodology setup and State health and Artifact hygiene unconditional;
      Test stack conditional on a detected test framework; Coverage posture conditional on Test
      stack being applicable; Convergence history conditional on at least one archived initiative.
- [ ] AC2: A category's checks, its raw total and its conditional predicate are declared **together
      in one place** in the script, not scattered across the file. A reader can see the whole
      definition of one category without scrolling to three sections.
- [ ] AC3: Each of the six categories is normalized to 0-10, and the overall score is the arithmetic
      mean of **applicable** categories only. A smoke test asserts a category earning 5 of 10 raw
      points reports `5.0`, and that a three-applicable-category run divides by 3, not 6.
- [ ] AC4: The three conditional categories are marked as such in the JSON output with an explicit
      applicability field, so a consumer can distinguish "scored 0" from "not applicable" without
      re-deriving the predicate.
- [ ] AC5: Categories with zero applicable checks are **excluded from the denominator**, not scored
      as zero. A smoke test asserts a repository lacking a conditional category's marker scores the
      same overall value as one where that category is not defined at all.
- [ ] AC6: `READINESS_RUBRIC_VERSION` is a bare top-level string constant (for example
      `READINESS_RUBRIC_VERSION="1.0.0"`), following `evals/score-artifacts.sh:139`'s
      `SCORER_VERSION="1.1.0"` precedent exactly. No new versioning scheme is invented.
- [ ] AC7: The rubric version is written into **every** JSON output, and the script documents that a
      future comparator must **refuse** rather than silently pass on a version mismatch, matching
      `edm-compare-eval:85-91`'s scorer_version refusal.
- [ ] AC8: Every check carries `id`, `category`, `points`, a `description`, a `pass` result, and a
      `fix:` string. The `fix:` string is **mandatory on every check, not only failing ones** -- it
      is what makes the report actionable without a second pass. A smoke test asserts no check
      object in the JSON has a null or empty `fix`.
- [ ] AC9: Checks are deterministic: a smoke test runs the script twice against the same commit and
      diffs the two JSON outputs, allowing only a timestamp field to differ (or the JSON carries no
      timestamp at all).
- [ ] AC10: **No check scores the repository on whether EDM itself is installed.** A review of the
      check table confirms this; it is the self-serving pattern correction 7 exposes in ECC's own
      consumer mode, and it measures nothing about readiness.
- [ ] AC11: Checks shared across scopes are placed deliberately, and the script documents in a
      comment which category owns each shared check, so the report's totals are unambiguous.
- [ ] AC12: `bash plugins/edm/bin/tests/run-all.sh` passes with the new assertions registered in a
      suite it discovers.

### Technical Notes
- **Citations verified.** `evals/score-artifacts.sh:139` is `SCORER_VERSION="1.1.0"` exactly, and
  `edm-compare-eval:85-91` is the `scorer_version` mismatch refusal (exit 2) exactly as cited. Both
  hold on the current branch.
- Bash 3.2 has no associative arrays, so the category table cannot be a `declare -A`. Use parallel
  space-separated strings, a heredoc parsed line by line with `IFS='|' read`, or a `jq`-held table
  built once with `jq -n`. The last is often cleanest here since `jq` is already required.
- Integer-only arithmetic in bash means normalization needs care: compute the 0-10 value with `jq`
  (`($raw / $max) * 10`) rather than with `$(( ))`, and format to one decimal place so `5` and `5.0`
  do not both appear in output.
- Determinism means no `date`-derived value inside a score, no `find` ordering dependence (pipe
  through `LC_ALL=C sort`), and no dependence on the caller's cwd within the repository.
- The conditional denominator is the one place a bug is easy and invisible: a category that is
  applicable but scores 0 must stay in the denominator. Assert both directions (AC5 covers the
  not-applicable direction; add the applicable-but-zero direction to the same test).
- ECC's `harness-audit.js` is not present in this repository, so its cited line numbers
  (`:977`, `:22`, `:827-943`) cannot be verified from here. They are shape references only; nothing
  in this ticket depends on them being accurate.

### Out of Scope
- The script scaffold, `--help`, `die()`, exit-code contract and output split (`EDMV4-T38`).
- Which specific `edm-state` subcommand feeds each category (`EDMV4-T40`) -- this ticket defines the
  categories and the scoring math, the next one wires the sources.
- Building a comparator for two scorecard JSON files; AC7 only requires the version be present and
  the refusal contract documented.
- Changing `SCORER_VERSION` or anything in `evals/`.

---

## EDMV4-T40: Wire the scorecard to the readiness signals EDM already computes

| Field | Value |
|---|---|
| Epic | Classifier and Scorecard |
| Phase | 3 |
| Priority | Should Have |
| Size | M |
| SRD Refs | EDMV4-38 |
| Depends On | EDMV4-T38 |
| Target Components | `plugins/edm/bin/edm-repo-readiness` (new), `plugins/edm/bin/edm-state` (`state_anomalies`, `cmd_validate`, `cmd_session_start`, `check_permission_rules`, `cmd_get_coverage`, `cmd_metrics_report`), `plugins/edm/CLAUDE.md Sec."Required setup: permission ask rules (EDMV3-T06)"` |

### Description
EDM already computes a battery of readiness-adjacent signals; they are simply not aggregated into
named categories. The highest-leverage move is therefore not "write 20-30 new `fileExists` checks"
-- which is ECC's actual implementation, and which the source analysis itself says not to port --
but "aggregate the signals `edm-state validate` / `session-start` / `get-coverage` already compute
into named, 0-10-normalized categories under a versioned rubric".

That distinction is the whole point of this ticket: it is new **categorization** logic, not new
**detection** logic. One source of truth per signal, rather than two implementations that can
disagree. A second permission-rule scanner in `edm-repo-readiness` would drift from
`check_permission_rules()` the first time the settings-file search order changed, and the scorecard
would then confidently report a state the rest of EDM disagrees with.

The script is strictly read-only with respect to state. It scores a repository; it never mutates
one.

### Acceptance Criteria
- [ ] AC1: Permission-rule presence is read from the existing `check_permission_rules()` result as
      surfaced by `edm-state session-start` / the `PERM_RULES_MISSING` anomaly. A grep of
      `edm-repo-readiness` for `settings.local.json` and `settings.json` returns nothing -- the
      script never scans `.claude/settings*.json` a second time.
- [ ] AC2: State-health signals are read from `edm-state validate`'s anomaly output, covering at
      minimum `OPEN_AUDIT_ROUND`, `TORN_TOKEN_LINES`, `SPEC_SWEEP_PENDING`, `OPEN_PARTIALS` and
      `CONVERGED_NO_APPROVAL`. Nothing is re-derived from `.edm-state.json` directly.
- [ ] AC3: The State health category's split between blocking-class and informational anomalies is
      **declared in the script** with a per-hit cost for each class, so a reader can see why a given
      repository lost the points it lost.
- [ ] AC4: Test-stack signals are read from `test_frameworks_detected` and
      `edm-state get-coverage`. The script does not scan for framework config files
      (`jest.config.*`, `pytest.ini`, `vitest.config.*`, etc.); a grep confirms no such pattern
      appears.
- [ ] AC5: Coverage posture compares `edm-state get-coverage` output against the configured
      `coverage_target_*_pct` thresholds rather than against hardcoded percentages.
- [ ] AC6: Cost and duration history, where scored, is read from `edm-state metrics-report`.
- [ ] AC7: Any signal the script genuinely must detect itself carries a one-line in-file comment
      explaining why no existing source covers it. A check with no such comment and no `edm-state`
      call is a defect.
- [ ] AC8: The script **never writes to `.edm-state.json`**. A smoke test records the state file's
      hash before and after a run and asserts it is unchanged, for every initiative in the fixture
      repository.
- [ ] AC9: Running the script against a repository with **no initiatives at all** succeeds: it
      scores what it can, prints a report, and exits **0** rather than erroring. A smoke test covers
      this against a fixture with an empty `SRD/`.
- [ ] AC10: `bash plugins/edm/bin/tests/run-all.sh` passes with the new assertions registered in a
      suite it discovers.

### Technical Notes
- **Citation drift.** The SRD's `bin/edm-state` line numbers run about four lines ahead of the
  current branch. Verified positions today: `state_anomalies()` `:1705` (SRD says 1709-1927),
  `cmd_validate()` `:4032` (SRD says 4036-4059), `cmd_session_start()` `:4343` (SRD says 4347+),
  `check_permission_rules()` `:1103`, `cmd_get_coverage()` `:2855`, `cmd_metrics_report()` `:3422`.
  Call the subcommands; do not read `bin/edm-state` by line offset.
- These are consumed as **subcommand output**, not as sourced shell functions. `edm-repo-readiness`
  must not `source bin/edm-state` -- that file has a large top-level body and sourcing it would
  execute a command dispatch. Invoke `edm-state validate`, `edm-state get-coverage`, etc. as
  processes and parse their output.
- `edm-state validate` exit codes are not all failures. An informational anomaly (for example
  `TORN_TOKEN_LINES`) does not flip its exit code, while blocking-class anomalies do. Under
  `set -euo pipefail` a non-zero `edm-state validate` will abort the script unless invoked as
  `out="$(edm-state validate "$p")" || rc=$?`. This is the single most likely implementation bug in
  this ticket.
- `test_frameworks_detected` may be flat (single-stack) or keyed by epic slug (multi-stack). Handle
  both shapes; `jq` `type == "object"` discrimination on a nested value is the portable test.
- `coverage_by_layer` / `coverage_by_epic` are absent on older state files. Read every field with
  `jq`'s `//` default operator per the C-4 backward-compatibility rule; absence is never an error.
- Bash 3.2 floor and the `bash`/`jq`/`git` binary set both apply; no `mapfile` when reading
  subcommand output, use a `while IFS= read -r` loop.

### Out of Scope
- Defining the categories, point budgets or normalization (`EDMV4-T39`).
- Any change to `bin/edm-state` itself -- this ticket consumes its subcommands, it does not modify
  them.
- Adding new anomaly types to `state_anomalies`.
- Writing any new detector for a signal an existing `edm-state` subcommand already produces.

---

## EDMV4-T41: Feed the readiness score into the classifier and into planning.md

| Field | Value |
|---|---|
| Epic | Classifier and Scorecard |
| Phase | 3 |
| Priority | Could Have |
| Size | S |
| SRD Refs | EDMV4-39 |
| Depends On | EDMV4-T34, EDMV4-T38, EDMV4-T39 |
| Target Components | `plugins/edm/skills/plan/SKILL.md`, `plugins/edm/skills/orchestrator/SKILL.md` (Step 1b.5), `plugins/edm/bin/edm-repo-readiness` (new), `plugins/edm/CLAUDE.md` |

### Description
The scorecard's value is conditional on the 4.3 classifier landing. A repository with no tests, no
CI and no `CLAUDE.md` should route differently from a mature one, and the classifier is the consumer
that would use that signal. The scorecard's findings are also exactly the kind of thing that belongs
in `planning.md`, where a reviewer sees them alongside the explorer synthesis.

Construction of the scorecard is not blocked on 4.3 -- `EDMV4-T38` through `EDMV4-T40` stand alone
-- but this integration is blocked on both halves, which is why it is the lowest-priority
requirement in the initiative and the join point of this epic.

The dependency is **advisory in both directions**. Phase 1 proceeds unchanged if the scorecard is
missing or fails, and the classifier still produces a recommendation from its three signals when no
score exists. Neither side may become a hard prerequisite of the other.

### Acceptance Criteria
- [ ] AC1: `skills/plan/SKILL.md` **optionally** runs `edm-repo-readiness` during Phase 1 and records
      its summary in `planning.md`. The skill text states the step is optional, not mandatory.
- [ ] AC2: The recorded summary names the **rubric version alongside the score**, so a score in an
      old `planning.md` is traceable to the rubric that produced it. A summary carrying a bare score
      with no version is a defect.
- [ ] AC3: Step 1b.5 states that the classifier **may** consult the score as an additional input to
      the **design-ambiguity signal** specifically -- not as a fourth signal and not as an input to
      the other two.
- [ ] AC4: The score never overrides the security-trigger tie-breaker from `EDMV4-T36`. Step 1b.5
      states the precedence explicitly: the tie-breaker's `standard` floor wins over any score-driven
      adjustment.
- [ ] AC5: If `edm-repo-readiness` is **not on PATH**, Phase 1 proceeds unchanged: no error is
      raised, no placeholder section is written to `planning.md`, and the phase completes normally.
- [ ] AC6: If `edm-repo-readiness` **exits non-zero**, Phase 1 proceeds unchanged, with the same
      no-error, no-placeholder behaviour as AC5. The skill text names both cases.
- [ ] AC7: When no score is available, Step 1b.5 still produces a recommendation from its three
      signals. The classifier never blocks on, or waits for, the scorecard.
- [ ] AC8: The integration is documented in `plugins/edm/CLAUDE.md`, so a reader who finds a
      readiness summary in a `planning.md` can tell where the score came from and which command
      produced it.

### Technical Notes
- `skills/plan/SKILL.md` owns Phase 1's procedure; the orchestrator only dispatches to it
  (`edm-check-skill-sync` asserts the dispatcher holds no phase procedure body). Put the Phase 1
  invocation in `skills/plan/SKILL.md`, never in the orchestrator.
- The "unavailable" case is a real one, not a hypothetical: `bin/` is on PATH only while the plugin
  is enabled, and a `planning.md` may be authored in a session where a different plugin set is
  loaded. Guard with `command -v edm-repo-readiness >/dev/null 2>&1 || skip`.
- Absence must be authoritative. Writing a "readiness: not measured" placeholder section is the
  wrong shape here and contradicts AC5/AC6 -- when the scorecard did not run, `planning.md` simply
  has no readiness section, matching how EDM handles N/A test layers.
- The classifier consumes the **summary score and rubric version**, not the full JSON. Step 1b.5 is
  under 30 lines (`EDMV4-T34` AC12) and cannot absorb a check-by-check reading.
- Guard D6 still applies to whatever text this ticket adds to Step 1b.5: name values, cite
  `CLAUDE.md Sec."EDM mode matrix"` by section reference, describe no mode's behaviour
  (`EDMV4-T37`). The block-scoped grep from `EDMV4-T37` AC3 must still pass after this ticket lands.
- `plugins/edm/CLAUDE.md` is a contributor-facing file; per the plugin's own contribution
  convention, the merge request shows before and after for each changed prose block with one
  sentence on why the new wording is better.

### Out of Scope
- Making the readiness score a required Phase 1 input or a gate condition.
- Adding a fourth signal to the classifier; the score feeds the existing design-ambiguity signal
  only.
- Any change to the scorecard's own categories, scoring or output format (`EDMV4-T39`,
  `EDMV4-T40`).
- Recording the readiness score into `.edm-state.json`; the scorecard is read-only with respect to
  state (`EDMV4-T40` AC8) and this ticket does not change that.
