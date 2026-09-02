# Epic 04: Audit Lenses

Scope item 4.4 -- grow the code-audit lens set from eleven to fourteen by adding L12 (Silent
Failures), L13 (Type Design, auto-N/A on an untyped stack) and L14 (Behavioral Test Coverage). This
is the widest blast radius in the initiative: thirteen tickets, all Must Have, spanning the state
layer, the completeness backstop, three new lens agents, the house lens contract, and a tree-wide
count sweep. `EDMV4-T21` grows `ALL_LENS_IDS` and adds `CONDITIONAL_LENS_IDS` and blocks everything
else here. `EDMV4-T22` materializes `lenses` and moves `round_type` to the union rule (the epic's
load-bearing P0). `EDMV4-T23` and `EDMV4-T24` build on that state shape -- the CA-471 backstop's
third check and the deterministic `detect-conditional-lenses` helper. `EDMV4-T25`, `EDMV4-T26` and
`EDMV4-T27` write the three lens agents; `EDMV4-T28` specifies and machine-enforces the house
contract they conform to. `EDMV4-T29` sweeps `skills/code-audit/SKILL.md`; `EDMV4-T30` rewrites the
smoke-suite assertions (and serializes every other edit to `wave7-smoke.sh` behind itself);
`EDMV4-T31` re-inventories the count sites and honours the do-not-touch list; `EDMV4-T32` grows the
code-audit fixtures; `EDMV4-T33` sweeps the documentation and user-facing surfaces.

**Verified-citation note for the whole epic.** Every `file:line` below was re-checked against the
current branch tree. `bin/edm-state` line numbers cited in `srd.md` Sec.6.5 are uniformly stale by
four lines (the SRD was written against an earlier tree). Each ticket's Technical Notes records the
SRD's number and the verified number. `wave6-smoke.sh`, `wave7-smoke.sh`, `skills/code-audit/SKILL.md`
and the fixture README citations held exactly PRE-fast-forward and no longer do -- see the
advisory banner above. `CLAUDE.md` and `README.md` citations are mixed
and are itemized in `EDMV4-T31` and `EDMV4-T33`.


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

## EDMV4-T21: Grow ALL_LENS_IDS to fourteen and add the CONDITIONAL_LENS_IDS sibling

| Field | Value |
|---|---|
| Epic | Audit Lenses |
| Phase | 3 |
| Priority | Must Have |
| Size | XS |
| SRD Refs | EDMV4-23 |
| Depends On | none |
| Target Components | plugins/edm/bin/edm-state:1603-1611, plugins/edm/bin/edm-state:803-808 |

### Description

`ALL_LENS_IDS` is the single source for the code-audit lens ID set. It is declared at
`bin/edm-state:1609` and followed immediately by a self-check at `:1611` that hardcodes the count
`11` twice -- once in the `-eq 11` test and once in the `die` message. Both change to 14, and the
list gains `L12 L13 L14`. The comment above it at `:1604` calls the set "the eleven canonical
code-audit lens IDs" and must stop saying eleven.

A new sibling constant `CONDITIONAL_LENS_IDS="L13"` records which lenses may legitimately be
auto-N/A. Its purpose is defensive: without it, any caller could name any lens N/A and the union
rule in `EDMV4-T22` would happily record a `full` round that skipped a lens for convenience. With
exactly one member, `--na-lenses L8` is a hard `die` rather than a policy discussion. "Conditional"
means a lens that may be auto-N/A on a stack where it is genuinely inapplicable, never a lens
excluded to save audit cost (guard D2, `CLAUDE.md Sec."Prompt conventions (house style)"`).

Both constants use the space-separated-string plus word-membership idiom the file already uses for
`MODE_ENUM_LIST` (`:803`), `LIFECYCLE_MODE_ENUM_LIST` (`:804`) and `AUDIT_TYPE_ENUM_LIST` (`:808`),
because bash 3.2 has no portable array-as-constant usable across functions.

### Acceptance Criteria

- [ ] AC1: `ALL_LENS_IDS` reads `"L1 L2 L3 L4 L5 L6 L7 L8 L9 L10 L11 L12 L13 L14"` -- fourteen IDs,
      `L1` through `L14`, in ascending numeric order.
- [ ] AC2: The self-check immediately below it tests `-eq 14` and its `die` message reads
      `internal: ALL_LENS_IDS must enumerate exactly 14 lenses`. Neither the test nor the message
      retains the literal `11`.
- [ ] AC3: The comment block above `ALL_LENS_IDS` no longer contains the string
      "the eleven canonical code-audit lens IDs" (verified by
      `grep -c 'eleven canonical' plugins/edm/bin/edm-state` returning 0).
- [ ] AC4: `CONDITIONAL_LENS_IDS="L13"` is declared immediately beside `ALL_LENS_IDS`, with its own
      `wc -w`-based length self-check asserting exactly 1 member and a `die` on mismatch.
- [ ] AC5: A comment above `CONDITIONAL_LENS_IDS` states, in those terms, that "conditional" means
      a lens that may be auto-N/A on an inapplicable stack and never a lens excluded for cost, and
      names guard D2 as the reason.
- [ ] AC6: A load-time assertion confirms every member of `CONDITIONAL_LENS_IDS` is also a member of
      `ALL_LENS_IDS`, using the `case " $ALL_LENS_IDS " in *" $item "*)` idiom, and `die`s naming the
      offending ID otherwise.
- [ ] AC7: No caller re-encodes either list as a second literal. `grep -n 'L1 L2 L3' plugins/edm/bin/`
      returns exactly one line (the `ALL_LENS_IDS` declaration itself).
- [ ] AC8: The `# shellcheck disable=SC2086` directive that guards the deliberate word-splitting on
      `ALL_LENS_IDS` is preserved and a matching directive is added for `CONDITIONAL_LENS_IDS`.
      `shellcheck plugins/edm/bin/edm-state` reports no new warning.
- [ ] AC9: `bash plugins/edm/bin/edm-state --help` exits 0 without tripping either self-check,
      proving both assertions hold at source time on a real invocation.

### Technical Notes

- **Stale SRD citations, corrected.** `srd.md` cites `bin/edm-state:1613` for `ALL_LENS_IDS`, `:1615`
  for the self-check and `:1608` for the comment. Verified on the current branch: `ALL_LENS_IDS` is
  at **`:1609`**, the `-eq 11` self-check at **`:1611`**, the "eleven canonical" comment at
  **`:1604`**, and the `# shellcheck disable=SC2086` directive at **`:1610`**. The SRD's numbers are
  uniformly four lines high. The SRD also cites `:803-812` for the enum idiom; the three constants
  are at `:803`, `:804` and `:808`, which is inside that range.
- Do not use a bash array. Constraint C1 pins the floor at bash 3.2: no associative arrays, no
  `${var^^}`, no `mapfile`. The `echo $LIST | wc -w | tr -d ' '` shape already in the file is the
  portable length idiom; reuse it verbatim for the new constant.
- Landing this ticket alone turns the smoke suite red -- `wave7-smoke.sh` has nine `-eq 11`
  assertions and `wave6-smoke.sh:3445-3449` inverts silently. That is expected and is `EDMV4-T30`'s
  to repair. Do not "fix" the suite here.
- `bin/edm-state` contains unrelated elevens that must not be touched: `:1166` and `:1169` describe
  a coverage-table column width of 11, and `:4615` recounts the pass-7 incident. Neither is a lens
  count. See `EDMV4-T31`.

### Out of Scope

Any consumer of the two constants -- the `round_type` derivation, the CA-471 backstop, the smoke
assertions, the SKILL.md prose, the three new agent files. This ticket changes the constants and
their self-checks only.

---

## EDMV4-T22: Materialize lenses and derive round_type from the lenses-union-lenses_na rule

| Field | Value |
|---|---|
| Epic | Audit Lenses |
| Phase | 3 |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV4-24 |
| Depends On | EDMV4-T21 |
| Target Components | plugins/edm/bin/edm-state:4500-4510, plugins/edm/bin/edm-state:4527-4576, plugins/edm/bin/edm-state:1613-1623, plugins/edm/CLAUDE.md, plugins/edm/bin/tests/wave6-smoke.sh |

### Description

Per AD5, `round_type` stays a two-value enum (`full` | `partial`) with its exact current meaning.
Widening it to three values would touch `audit-converged`, `cmd_archive`, HANDOFF, `metrics-report`,
the documented C-4 unknown case and roughly 28 smoke assertions, to express information that fits
cleanly in an orthogonal field. The new information lives in
`audit_rounds.<type>.rounds[].lenses_na`, an array recorded at `audit-round-start` alongside the
existing `lenses`, and the derivation moves from set-equality to a union rule: `full` iff
`(lenses UNION lenses_na) == ALL_LENS_IDS` **and** `lenses_na` is a subset of `CONDITIONAL_LENS_IDS`.

**The union rule requires a state-shape change, and this is the load-bearing part of the ticket.**
The live derivation has two branches, not one. When `--lenses` is omitted it records
`lenses_json="[]"` and hardcodes `round_type="full"`; only the `--lenses`-given branch runs the
set-equality comparison. Stating the union rule unconditionally over that shape is incoherent: with
`lenses` recorded as `[]`, the empty union never equals `ALL_LENS_IDS`, so every
`audit-round-start <PREFIX> srd` and `... tickets` call -- neither of which has a lens concept and
neither of which ever passes `--lenses` -- would record `partial`, and `audit-converged` would refuse
forever because a partial round is never convergent. Therefore the omitted-`--lenses` branch
**materializes `lenses = ALL_LENS_IDS`** explicitly. That single change makes the union derivation
correct in both branches, and it is what keeps `EDMV4-T23`'s state-authoritative backstop meaningful:
an empty `lenses` array would make that backstop require zero JSONL files, which is precisely the
pass-7 incident the backstop was built for.

The anti-abuse property is **timing**, not policy. `lenses_na` is committed to state under lock at
round-start, which `skills/code-audit/SKILL.md` Step 4 calls before Step 7 launches any agent, so a
lens cannot retroactively excuse its own non-delivery.

**Surface disambiguation.** "`--lenses` omitted" in this ticket means the `edm-state audit-round-start --lenses` flag. It does **not** mean the operator's `/edm:code-audit` argument, which is a different surface owned by `EDMV4-T24` AC9. `skills/code-audit/SKILL.md:40-42` mandates that Step 4 always passes `--lenses` to `edm-state`, so this omitted branch is reached by direct CLI callers and by `srd`/`tickets` rounds, never by a normal code-audit run. (Moved out of the AC list by ticket-pack audit P2: nothing about the delivered code passes or fails it, so a QC auditor had nothing to grade -- it is a glossary note, not a criterion.)

### Acceptance Criteria

- [ ] AC1: **State shape.** `cmd_audit_round_start` records `lenses` as the full `ALL_LENS_IDS` list,
      in `ALL_LENS_IDS` order, when `--lenses` is omitted, replacing today's `lenses_json="[]"`. A
      smoke test asserts `jq '.audit_rounds.code.rounds[-1].lenses | length' .edm-state.json` equals
      14 directly against the state file, not inferred from the resulting `round_type`.
- [ ] AC2: The same materialization applies to `srd` and `tickets` rounds. Smoke tests replay
      `wave6-smoke.sh:3427-3432` (code, omitted `--lenses`) and `:3452-3457` (srd) and assert both
      still record `round_type == "full"`. A `partial` for either is a failure, not a new expected
      value.

- [ ] AC3: `cmd_audit_round_start` accepts a new optional `--na-lenses <csv>` flag, parsed with the
      same normalization the existing `--lenses` parsing uses (comma split, whitespace trim, empty
      lines dropped), in either flag order.
- [ ] AC4: `round_type` is `full` when `(lenses UNION lenses_na) == ALL_LENS_IDS` and `lenses_na` is
      a subset of `CONDITIONAL_LENS_IDS`; `partial` otherwise. The rule is evaluated uniformly in
      both branches -- no branch hardcodes `full` without evaluating it.
- [ ] AC5: `--na-lenses` naming any lens outside `CONDITIONAL_LENS_IDS` is a hard `die` at
      round-start, naming the offending ID. A smoke case asserts `--na-lenses L8` exits non-zero and
      writes no round record.
- [ ] AC6: **Pass-7 regression test.** A smoke test replays the founding CA-471 shape: a code round
      started with `--lenses` omitted, N prose `lens-L{N}.md` files written, and zero
      `lens-L{N}.jsonl` files. It asserts the CA-471 downgrade still fires and the round closes as
      `partial`. This test fails against a design that leaves `lenses` empty.
- [ ] AC7: `--na-lenses` omitted produces `lenses_na: []`. A smoke test replays the existing
      `wave6-smoke.sh` T27 AC1 cases and asserts each derived `round_type` is unchanged from today's
      recorded expectation, holding `ALL_LENS_IDS` at its post-`EDMV4-T21` value. The assertion is on
      the derived `round_type`, never on byte-identity of the round record -- the record now carries
      a materialized `lenses` array and a new `lenses_na` key and is deliberately not byte-identical.
- [ ] AC8: `lenses_na` is written into the round record alongside `lenses`, in the same
      `_rmw_state_body` write, under the existing `with_state_lock` acquisition.
- [ ] AC9: **`audit-round-start` is the sole writer of `lenses_na`.** No code path writes, appends
      to or mutates it afterwards. `audit-round-complete` accepts an N/A declaration from no source:
      not a flag, not `lenses-run.txt`, not a lens agent's output. A smoke assertion greps
      `bin/edm-state` and fails if any assignment to or jq-write of `lenses_na` appears outside
      `cmd_audit_round_start` / `_cmd_audit_round_start_body`, and a behavioural test confirms an
      attempt to declare a lens N/A at completion time is refused.
- [ ] AC10: **C-4 read rules, both directions.** (a) **C-4 read rule.** On read, a round record whose `lenses` is empty and whose recorded `round_type` is `full` is substituted with `ALL_LENS_IDS`, never read as "no lenses required". A smoke test proves it against a fixture round record carrying `lenses: []` and `round_type: "full"`, asserting the `EDMV4-T23` backstop requires the full JSONL set rather than passing vacuously. (b) A round record carrying no `lenses_na` key reads as `[]` via a jq `//` default. No existing state file is rewritten in place. `schema_version` is **not** bumped -- this is an additive extension of the wave-B round shape exactly like the EDMV3-T51 cost fields, and the reasoning is recorded in `CLAUDE.md Sec.".edm-state.json schema_version contract"`.

- [ ] AC11: An untyped stack with `--na-lenses` omitted records `partial` (the union misses L13) and
      `audit-converged` refuses. The failure is loud and conservative, never a silent `full`.
- [ ] AC12: `CLAUDE.md Sec.".edm-state.json mode-family fields"` gains a `lenses_na` row stating
      type, default, purpose and C-4 absent behaviour in the same form as the surrounding rows, and
      the two C-4 rules from AC11 and AC12 are documented together there.

### Technical Notes

- **Stale SRD citations, corrected.** `srd.md` cites `:4508-4510` (derivation comment),
  `:4531-4580` (`_cmd_audit_round_start`), `:4555,4567-4571` (the set-equality derivation), `:4557`
  (`lenses_json="[]"`) and `:1617-1630` (`AUDIT_ROUND_COERCE_JQ_DEF`). Verified on the current branch:
  the derivation comment is at **`:4500-4510`**, `_cmd_audit_round_start_body` at **`:4512-4525`**,
  `cmd_audit_round_start` at **`:4527-4576`**, the two-branch derivation at **`:4548-4569`**,
  `lenses_json="[]"` at **`:4553`**, the set-equality comparison at **`:4564-4568`**, and
  `AUDIT_ROUND_COERCE_JQ_DEF` at **`:1613-1623`**. Four lines high throughout.
- **Safety property, stated precisely.** Holding `ALL_LENS_IDS` constant, the union derivation with
  an empty `lenses_na` returns the same answer as today's set-equality for every input. It is **not**
  true that every input returns the same answer across the `ALL_LENS_IDS` change itself:
  `--lenses L1,...,L11` returns `full` today and `partial` after, deliberately. That reversal is
  `EDMV4-T30`'s to handle. `architecture.md:170-171` states the property too broadly and is
  corrected by `srd.md` Sec.5.1 AD5.
- The existing comparison shape (`jq -r 'sort | join(",")'` on both sides) already normalizes order,
  so the union rule can be expressed as: sort-unique the concatenation of `lenses` and `lenses_na`,
  compare against the sorted `ALL_LENS_IDS` string. Keep the comparison in jq, not in bash, so
  ordering and de-duplication stay in one place.
- The subset check on `lenses_na` is a separate bash loop over the `case " $CONDITIONAL_LENS_IDS "`
  idiom and runs before the union comparison, so the `die` in AC6 fires before any state write.
- SRD-declared dependency is `EDMV4-23` only, matching this ticket's `Depends On`.

### Out of Scope

The CA-471 backstop's use of the new fields (`EDMV4-T23`), the `detect-conditional-lenses` helper
that computes what to pass to `--na-lenses` (`EDMV4-T24`), and the rewrite of the `wave6`/`wave7`
lens-count assertions (`EDMV4-T30`). This ticket adds only the smoke cases its own ACs name.

---

## EDMV4-T23: Teach the CA-471 completeness backstop to distinguish N/A from missing JSONL

| Field | Value |
|---|---|
| Epic | Audit Lenses |
| Phase | 3 |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV4-25 |
| Depends On | EDMV4-T22 |
| Target Components | plugins/edm/bin/edm-state:4613-4671, plugins/edm/bin/edm-state:4652, plugins/edm/bin/edm-state:4658-4665, plugins/edm/skills/code-audit/SKILL.md:56-61, plugins/edm/agents/edm-test-integration.md:21-25, plugins/edm/CLAUDE.md, plugins/edm/bin/tests/wave6-smoke.sh, plugins/edm/bin/tests/wave8-smoke.sh |

### Description

`audit-round-complete` currently downgrades a code round to `partial` when any lens named in the
round's `lenses-run.txt` lacks a non-empty, parseable `lens-L{N}.jsonl`. That downgrade is
irreversible for the round it fires on: a second completion is refused, so persisting the missing
JSONL afterwards does not restore `full`. With L13 auto-N/A, the backstop needs a third check, and
it must get its answer from state written **before** the lenses ran, not from the manifest written
after.

This ticket is only sound because `EDMV4-T22` materializes `lenses`. Today the backstop iterates the
manifest, which lists real lens IDs regardless of how the round was started. Moving the source of
truth to state without the materialization would make a full round started without `--lenses`
iterate an empty array and require zero JSONL files -- exactly the founding incident recorded in the
CA-471 comment ("pass-7 of this plugin's own EDMV3 initiative shipped eleven prose reports and ZERO
JSONL files, and the round still closed and counted as full") and exactly what
`skills/code-audit/SKILL.md:56-61` independently documents. The dependency is load-bearing, not
sequencing convenience.

The manifest keeps one role and loses another. It is no longer the source of truth for which lenses
were required, but it remains the trigger deciding whether the gate runs at all, retained
deliberately for C-4. The consequence is a known residual gap that this ticket records rather than
closes.

### Acceptance Criteria

- [ ] AC1: The backstop reads `lenses` and `lenses_na` from the round record in state, not from
      `lenses-run.txt`. The manifest is a rendering, not a source of truth.
- [ ] AC2: It applies `EDMV4-T22` AC11's C-4 read rule -- a historical round record carrying
      `lenses: []` with `round_type: "full"` is read as `ALL_LENS_IDS`. A smoke test replays that
      fixture and asserts the backstop requires the full JSONL set rather than passing vacuously.
- [ ] AC3: For each lens in `lenses`, a non-empty parseable `lens-L{N}.jsonl` is required, exactly as
      today (`[[ -s "$f" ]]` plus `jq empty`).
- [ ] AC4: For each lens in `lenses_na`, **no** `lens-L{N}.jsonl` may exist. A JSONL present for a
      lens declared N/A downgrades the round to `partial` with a message naming the disagreement
      between the skill's Step 1 detection and the agent's own behaviour, in the contract-violation
      shape `agents/edm-test-integration.md:21-25` already uses for the test layer.
- [ ] AC5: **Incomplete-coverage check, scoped to full rounds only.** If `lenses UNION lenses_na` no
      longer covers `ALL_LENS_IDS` at completion time -- for example because `ALL_LENS_IDS` grew
      between round start and round completion -- the round downgrades to `partial`. The check runs
      **only** on rounds whose recorded `round_type` is `full` at completion time.
- [ ] AC6: A smoke test runs `--lenses L1,L9,L11` through to completion and asserts **no** coverage
      warning is emitted. Unscoped, AC5 would fire on every legitimate operator-requested partial
      round, since that union is not `ALL_LENS_IDS` by construction.
- [ ] AC7: The three downgrade reasons are distinguishable in the operator output -- missing JSONL
      for a run lens, unexpected JSONL for an N/A lens, and incomplete coverage. A single generic
      message is not acceptable; each carries its own distinct prefix string that a smoke test greps
      for individually.
- [ ] AC8: The downgrade stays irreversible and the double-completion refusal is preserved. A smoke
      case asserts a second `audit-round-complete` on the same round still exits non-zero and mutates
      nothing.
- [ ] AC9: A round with no pass directory, or with a pass directory but no `lenses-run.txt`, is left
      unchanged, exactly as today (C-4). The manifest existence test remains the gate trigger.
- [ ] AC10: The residual gap is recorded in `SRD/edm/EDMV4__ecc-integration/decisions.md` as an
      accepted limitation with a named follow-on: a round that produces no manifest -- arguably the
      strongest non-delivery signal there is -- escapes the backstop entirely, exactly as it does
      today. This ticket does not close it, because closing it means deciding what a missing pass
      directory means for a round that legitimately skipped one, which is new design.
- [ ] AC11: Smoke tests cover all three downgrade reasons, the clean 13-of-14 N/A case that must
      remain `full`, the `--lenses L1,L9,L11` case that must emit no coverage warning, and
      `EDMV4-T22` AC7's pass-7 replay which must still downgrade.
- [ ] AC12: `CLAUDE.md`'s `audit_rounds.<type>.rounds[].round_type` state-field row is rewritten to
      describe the three-way check in place of the current two-way description, and records both C-4
      read rules from `EDMV4-T22` plus the manifest-trigger residual gap.

### Technical Notes

- **Stale SRD citations, corrected.** `srd.md` cites `:4617-4619` (founding-incident comment),
  `:4656` (manifest existence test) and `:4662-4669` (manifest iteration). Verified on the current
  branch: the CA-471 comment block is at **`:4613-4622`** with the pass-7 sentence at **`:4615`**,
  the `if [[ -n "$_pass_dir" && -f "$_manifest" ]]` trigger at **`:4652`**, and the manifest
  `while IFS= read` loop at **`:4658-4665`**. Four lines high throughout.
- Two existing behaviours in that loop must survive the rewrite (CA-478): the
  `|| [[ -n "$_lens" ]]` clause that recovers a final line with no trailing newline, and the
  `_lens="${_lens%$'\r'}"` CRLF strip. Reading lens IDs from state instead of the manifest removes
  the need for both **only** on the state path; the manifest is still read as the gate trigger, so
  do not delete the defensive parsing wholesale.
- The `^L[0-9]+$` filter at `:4660` is what makes `EDMV4-T24` AC8's `Lenses N/A:` header line safe to
  add to `lenses-run.txt` -- it does not match, so no existing consumer mis-reads it as a lens ID.
  Do not relax that regex.
- `wave8-smoke.sh` does not exist yet; the SRD lists it as new. Creating it is in scope here if the
  new cases do not fit `wave6-smoke.sh`'s existing T27 block. Register any new suite file with
  `bin/tests/run-all.sh` or it will not run.
- SRD-declared dependency is `EDMV4-24` only, matching this ticket's `Depends On`.

### Out of Scope

Closing the no-manifest residual gap (recorded, not fixed). Changing what `lenses-run.txt` contains
(`EDMV4-T24` AC8). The fixtures the new cases run against (`EDMV4-T32`).

---

## EDMV4-T24: Make code-audit Step 1 the sole authority for L13 applicability

| Field | Value |
|---|---|
| Epic | Audit Lenses |
| Phase | 3 |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV4-26 |
| Depends On | EDMV4-T22 |
| Target Components | plugins/edm/bin/edm-state, plugins/edm/skills/code-audit/SKILL.md:35-42, plugins/edm/skills/code-audit/SKILL.md:52-61, plugins/edm/skills/code-audit/SKILL.md:95-96, plugins/edm/agents/edm-test-integration.md:21-25, plugins/edm/CLAUDE.md |

### Description

Per D8, L13's conditionality follows the test layer's N/A-agreement precedent, not the mode matrix.
The mode matrix is a user-selected enum a human picks at Step 1c; it is not derived from the target
codebase, which makes it a poor fit for a lens whose applicability should be *detected*. The test
layer's shape is the right one: a single authority determines applicability once, every consumer
agrees rather than self-declaring, N/A is recomputed each run rather than inherited, and absence is
authoritative -- no placeholder file, no placeholder row.

Today code-audit's lens selection has exactly one input, the human-supplied `--lenses` flag, so an
automatically computed N/A is a new kind of round-composition logic that must be given one clear
owner. `skills/code-audit/SKILL.md` Step 1 is that owner, but the determination itself is computed by
a deterministic `edm-state` helper rather than by prose an LLM interprets. This is mandatory rather
than preferred: the determination gates `round_type=full`, which gates `audit-converged`, which gates
`archive`. A non-deterministic input to a convergence gate is not acceptable.

**Guard D2 binds here.** L13's conditionality is justified only as genuine inapplicability -- type
design is meaningless in untyped code. It is never a licence to skip a lens for cost. The helper's
criteria are pure filesystem predicates so the answer is reproducible and auditable.

### Acceptance Criteria

- [ ] AC1: `edm-state detect-conditional-lenses [<PREFIX>]` exists, prints a CSV of conditional lens
      IDs that are N/A for the current repository (empty output means none), and exits **0** whether
      or not it finds markers. An empty result is a valid answer, not an error.
- [ ] AC2: The marker criteria are enumerated in the subcommand's own help block and are pure
      filesystem predicates over tracked files with no content heuristics. L13 **applies** when the
      repository contains at least one of: `tsconfig.json`; any `*.kt` or `*.kts`; any `*.swift`;
      `Cargo.toml`; `go.mod`; any `*.java`; any `*.scala`; any `*.hs`; or `pyproject.toml` **together
      with** a typed-checker configuration (a `[tool.mypy]` or `[tool.pyright]` table, or a sibling
      `mypy.ini` / `pyrightconfig.json`). A bare `pyproject.toml` is not sufficient -- an untyped
      Python project has one too. Absence of every marker means L13 is N/A.
- [ ] AC3: The marker list lives in exactly one place in `bin/edm-state` and is restated in neither
      `skills/code-audit/SKILL.md` nor `agents/edm-audit-type-design.md` nor any ticket. A smoke
      assertion greps those two prompt files for the marker filenames and fails on a second copy.
- [ ] AC4: Detection is deterministic: two runs against the same tree produce byte-identical output.
      A smoke test runs the helper twice against a fixture and diffs, and separately asserts each
      marker independently flips the answer -- one fixture per marker, plus a no-marker fixture.
- [ ] AC5: The helper is bash 3.2 clean (no associative arrays, no `${var^^}`, no `mapfile`) and adds
      no required binary beyond `bash`, `jq` and `git`. `shellcheck plugins/edm/bin/edm-state`
      reports no new warning.
- [ ] AC6: `skills/code-audit/SKILL.md` Step 1 gains a stack-detection step that **calls** the helper
      and records the result, and states in its own text that Step 1 is the **sole** authority for
      the L13 applicability determination. It does not re-derive the answer.
- [ ] AC7: N/A is recomputed on every round and is never read from a previous round's record. On
      N/A, **nothing is written**: no `lens-L13.md`, no `lens-L13.jsonl`, no placeholder. Absence is
      authoritative.
- [ ] AC8: Step 4 passes both `--lenses` and `--na-lenses` to `audit-round-start`, and Step 8 writes
      `lenses-run.txt` containing the run lens IDs one per line plus a `Lenses N/A:` header line.
      A test asserts that header line does not match the `^L[0-9]+$` parsing filter in
      `bin/edm-state:4660`, so no existing consumer mis-reads it as a lens ID.
- [ ] AC9: **Operator override, on the `/edm:code-audit` surface.** When the operator passes an
      explicit lens list to `/edm:code-audit`, they get exactly that list and the auto-N/A path does
      not run -- an explicit human request is never silently rewritten. The auto-N/A path applies only
      when the operator supplied no lens list. This AC is about the `/edm:code-audit` argument, not
      the `edm-state audit-round-start --lenses` flag, which `skills/code-audit/SKILL.md:40-42`
      requires Step 4 to pass on **every** run regardless. `EDMV4-T22` AC3 owns the flag; this AC
      owns the operator argument.
- [ ] AC10: The skill states that the **agent** must agree with this determination rather than form
      its own. The reciprocal clause inside `agents/edm-audit-type-design.md` is owned by
      `EDMV4-T26`, not by this ticket -- this ticket establishes the authority; the agent agrees with
      it once it exists.
- [ ] AC11: `CLAUDE.md Sec."bin/ helper scripts"` documents the new subcommand and the marker list,
      and the `edm-state` subcommand count is updated to match. That count is also incremented by
      `EDMV4-14`'s `get-patterns`; the two increments are reconciled into one final number rather
      than each claiming to be the only change.
- [ ] AC12: `CLAUDE.md Sec."Layers that are N/A and per-epic test plans"` is cross-referenced from the
      new documentation as the precedent this determination follows.

### Technical Notes

- **Verified citations.** All `skills/code-audit/SKILL.md` line references hold exactly on the
  current branch: `:35-42` (Step 1 lens parsing and validation, with the always-pass-`--lenses`
  mandate at `:40-42`), `:52-61` (Step 4 round-start and its round-type prose at `:56-61`), `:95-96`
  (Step 8a content check). `agents/edm-test-integration.md:21-25` holds exactly and is the
  N/A-agreement precedent to copy structurally, not verbatim.
- The `bin/edm-state:4660` filter cited in AC8 is verified: the SRD's `:4656` for the manifest gate
  and the `^L[0-9]+$` test are at `:4652` and `:4660` respectively on the current branch.
- Use `git ls-files` for the tracked-file predicates so an untracked scratch `tsconfig.json` cannot
  flip a convergence-gating answer. `git` is already a required binary (C2), so this adds nothing.
- Anchor the `pyproject.toml` typed-checker probe to a `grep -q '^\[tool\.\(mypy\|pyright\)\]'` over
  the file plus sibling-file existence tests. Do not parse TOML; that would add a binary.
- **Dependency direction, settled.** SRD v1.0.0 declared `EDMV4-26 -> EDMV4-28` while `EDMV4-28`
  declared `28 -> 26`, a dependency cycle. The direction is settled by which artifact is
  authoritative: this ticket *establishes* the applicability authority and `EDMV4-T26`'s agent
  *agrees* with it, so the agent depends on the authority and this ticket does not depend on the
  agent. SRD-declared dependency is `EDMV4-24` only, matching `Depends On`.

### Out of Scope

The `edm-audit-type-design.md` agent file itself and its reciprocal agreement clause
(`EDMV4-T26`). The `--na-lenses` flag's parsing and the union derivation (`EDMV4-T22`). Sweeping
`SKILL.md`'s lens-count strings (`EDMV4-T29`).

---

## EDMV4-T25: Write lens L12 -- Silent Failures

| Field | Value |
|---|---|
| Epic | Audit Lenses |
| Phase | 3 |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV4-27 |
| Depends On | EDMV4-T21 |
| Target Components | plugins/edm/agents/edm-audit-silent-failures.md, plugins/edm/agents/edm-audit-logic.md |

### Description

L1 (Logic, Correctness and Completeness) explicitly lists "Empty `except`/`catch` blocks (silently
swallow errors)" as a hunt target at `agents/edm-audit-logic.md:38`, but nothing in L1 through L11
hunts the fallback that *succeeds while hiding a failure* -- the more dangerous and much
harder-to-spot half of the category, and one a passing test suite actively conceals. A
`.catch(() => [])` that turns a network failure into an empty list produces a green build, a rendered
empty state, and a bug report three weeks later. L12 exists for that.

L12 is unconditional: it is not a member of `CONDITIONAL_LENS_IDS` and has no N/A exit.

Its taxonomy comes from `ECC/agents/silent-failure-hunter.md:23-49`, whose five categories were
verified verbatim during Phase 1. Its prompt does not. The ECC agent's body is 44 lines with a
four-item bullet-list output format, against EDM's 115-to-204-line lens agents with structured JSONL
contracts. Take the taxonomy, not the prompt.

### Acceptance Criteria

- [ ] AC1: `plugins/edm/agents/edm-audit-silent-failures.md` exists and satisfies `EDMV4-T28`'s house
      lens contract in full -- frontmatter, opening frame, `## Scope`, `## False Alarm Filter`,
      `## Output`, `## Output Format`, `## JSONL Line Format`, `## When this does NOT apply`.
- [ ] AC2: Its `## What You Hunt For` section covers five categories: (a) empty catch blocks and
      errors converted to `null` or empty collections without context; (b) inadequate logging --
      missing context, wrong severity, log-and-forget; (c) **dangerous fallbacks** -- default values
      that hide real failure, `.catch(() => [])`, graceful-looking paths that make downstream bugs
      harder to diagnose; (d) error propagation problems -- lost stack traces, generic rethrows,
      missing async handling; (e) missing handling entirely around network, file or database paths,
      or transactional work without rollback.
- [ ] AC3: The dangerous-fallback category is the one whose mandate is stated most explicitly, since
      it is the gap L1 does not cover. It carries at least one concrete code-shape example.
- [ ] AC4: The lens is unconditional. The file contains no N/A exit and `L12` does not appear in
      `CONDITIONAL_LENS_IDS`. Its `## When this does NOT apply` uses the standard sentence: this
      agent always applies once the code-audit skill selects lens L12 for the round.
- [ ] AC5: Its `## Scope` section carries one sentence bounding L12 against L1 -- L1 owns the empty
      catch block as a correctness defect, L12 owns the handler that succeeds while concealing the
      failure -- so a single finding is not filed twice by two lenses.
- [ ] AC6: No text is copied from `silent-failure-hunter.md`. The five categories are re-expressed in
      EDM's own register and at EDM's own length. A reviewer diffing the two files finds no shared
      sentence.
- [ ] AC7: All JSONL and Output-Format references use the lens ID `L12` consistently:
      `${OUTPUT_DIR}/lens-L12.md`, `${OUTPUT_DIR}/lens-L12.jsonl`, and `"lens":"L12"` in the schema
      line.
- [ ] AC8: The file's length scales with its hunt categories rather than targeting any existing
      lens's line count. It is ASCII-only.
- [ ] AC9: `bash plugins/edm/bin/edm-check-grants` passes over the new file.

### Technical Notes

- **Verified.** `agents/edm-audit-logic.md` is 115 lines on the current branch; the empty-catch hunt
  target is at `:38` and the section-by-section contract exemplar is intact. The L1 boundary sentence
  in AC5 belongs in the new file's `## Scope`; `EDMV4-T27` AC5/AC6 handle reciprocal sentences for
  L14's neighbours, but L1 does **not** need a reciprocal edit for L12 -- AC5 is one-directional by
  design, because L1's existing target is a strict subset of L12's category (a).
- Do not grant `Edit` or `NotebookEdit`. The tool grant line is fixed by `EDMV4-T28` AC1 and is
  byte-identical across all twelve `agents/edm-audit-*.md` files today -- `wave7-smoke.sh:1599-1603`
  (CA-529) asserts exactly that, and a new file that deviates fails it.
- The five-category taxonomy is the deliverable; the ECC source is read for structure only. Record
  the clean-room posture in `decisions.md` if a reviewer asks, per
  `CLAUDE.md Sec."Prompt conventions (house style)"`.
- SRD-declared dependencies are `EDMV4-23` and `EDMV4-30`. `Depends On` carries `EDMV4-T21` per the
  epic DAG; `EDMV4-T28`'s contract text is readable from this ticket's start, and only its machine
  enforcement lands later. See `EDMV4-T28` Technical Notes.

### Out of Scope

The house contract's own specification and smoke enforcement (`EDMV4-T28`). Adding the L12 row to
`skills/code-audit/SKILL.md`'s lens table (`EDMV4-T29`). Growing `LENS_AGENTS` and `lens_files` in
`wave7-smoke.sh` (`EDMV4-T30`).

---

## EDMV4-T26: Write lens L13 -- Type Design, with auto-N/A on an untyped stack

| Field | Value |
|---|---|
| Epic | Audit Lenses |
| Phase | 3 |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV4-28 |
| Depends On | EDMV4-T21, EDMV4-T24 |
| Target Components | plugins/edm/agents/edm-audit-type-design.md, plugins/edm/bin/edm-state:1609-1612, plugins/edm/agents/edm-test-integration.md:21-25, plugins/edm/CLAUDE.md |

### Description

No EDM lens touches type design at all. The gap is total, and for a methodology whose implementers
write TypeScript, Kotlin, Swift and Rust that is a real hole. L13 evaluates whether types make
illegal states harder or impossible to represent, across the four dimensions verified at
`ECC/agents/type-design-analyzer.md:23-42`.

L13 is the **only** conditional lens. **Guard D2 binds here and must travel with the work.** Adding
lenses does not violate D2 on its face, but the source analysis's own risk note ("more lenses means
more audit cost per round ... Measure with `/edm:metrics` before making all three unconditional")
must not be read as licence to make L13 conditional for cost reasons. D2's stated cost of being
ignored is coverage loss disguised as an efficiency gain -- a lens silently stops existing and nobody
notices until the gap it used to catch ships. L13's conditionality is justified **only** as genuine
inapplicability: type design is meaningless in untyped code.

The agent does not decide its own applicability. `skills/code-audit/SKILL.md` Step 1 (`EDMV4-T24`) is
the sole authority; this agent's N/A exit agrees with that determination and never substitutes for
it, in the same form `agents/edm-test-integration.md:21-25` uses for the test layer.

### Acceptance Criteria

- [ ] AC1: `plugins/edm/agents/edm-audit-type-design.md` exists and satisfies `EDMV4-T28`'s house
      lens contract in full.
- [ ] AC2: Its `## What You Hunt For` section covers four dimensions: encapsulation (are internals
      hidden, can invariants be violated from outside); invariant expression (do types encode business
      rules); invariant usefulness (do they prevent real bugs, are they domain-aligned); and
      enforcement (does the type system enforce them, are there easy escape hatches).
- [ ] AC3: The agent's `## When this does NOT apply` section states the N/A condition as
      **inapplicability**, in exactly those terms, and explicitly states that cost is never a reason
      to skip it. A smoke assertion greps the file for the inapplicability framing and for the
      cost-is-never-a-reason sentence, and fails if either is absent.
- [ ] AC4: The same section states that the agent's N/A exit **agrees with**
      `skills/code-audit/SKILL.md` Step 1's determination and never substitutes for it, and that a
      mismatch between this agent's exit and Step 1's determination is a contract violation -- the
      `agents/edm-test-integration.md:21-25` form.
- [ ] AC5: On N/A the agent writes nothing at all and exits cleanly: no `lens-L13.md`, no
      `lens-L13.jsonl`, no placeholder. Absence is authoritative.
- [ ] AC6: `L13` is the sole member of `CONDITIONAL_LENS_IDS` in `bin/edm-state`. A smoke assertion
      confirms the constant has exactly one member and that it is `L13`.
- [ ] AC7: This ticket's text records the D2 framing constraint verbatim (conditionality is
      inapplicability, never cost), so the constraint travels with the work rather than living only
      in the SRD.
- [ ] AC8: Neither the agent nor the skill nor any AC in this epic cites GateGuard's or any other
      self-reported effect-size number as a target. Effect claims are directional only.
- [ ] AC9: All JSONL and Output-Format references use the lens ID `L13` consistently, and the
      `## Output Format` section cites `CLAUDE.md Sec."Severity vocabulary"` with the
      `Read docs/canonical-sections.md` anchoring instruction (`EDMV4-T28` AC8).
- [ ] AC10: The agent does not restate the stack-marker list from `EDMV4-T24` AC2. A smoke assertion
      greps this file for the marker filenames (`tsconfig.json`, `Cargo.toml`, `go.mod`,
      `pyproject.toml`, `mypy.ini`, `pyrightconfig.json`) and fails on any hit.
- [ ] AC11: `bash plugins/edm/bin/edm-check-grants` passes over the new file, and the file is
      ASCII-only.

### Technical Notes

- **Stale SRD citation, corrected.** `srd.md` cites `bin/edm-state:1613` for the
  `CONDITIONAL_LENS_IDS` site. Verified: `ALL_LENS_IDS` is at **`:1609`** on the current branch, so
  the new constant lands at roughly **`:1612-1614`** once `EDMV4-T21` adds it. Locate by string
  (`ALL_LENS_IDS=`), not by line number.
- **Verified.** `agents/edm-test-integration.md:21-25` holds exactly and carries the sentence to copy
  structurally: "this is not a self-declared exemption independent of it; a mismatch between this
  agent's exit and the planner's assignment for the same epic is a contract violation."
- Guard D2 lives at `CLAUDE.md:429` on the current branch (the SRD's
  `Sec."Prompt conventions (house style)"` reference resolves; the line number is advisory). That
  passage is on `EDMV4-T31`'s **do-not-touch** list -- cite it, do not edit it.
- The `## When this does NOT apply` section is the one place this lens deviates from the standard
  house sentence L12 and L14 use. Everything else in the contract is identical.
- SRD-declared dependencies are `EDMV4-23`, `EDMV4-26` and `EDMV4-30`; `Depends On` carries the first
  two as `EDMV4-T21` and `EDMV4-T24`. See `EDMV4-T28` Technical Notes for the contract-direction
  reconciliation.

### Out of Scope

The `detect-conditional-lenses` helper and Step 1's call to it (`EDMV4-T24`). The `--na-lenses` flag
and the union derivation (`EDMV4-T22`). The backstop's N/A check (`EDMV4-T23`). Annotating the L13
row as conditional in `SKILL.md`'s lens table (`EDMV4-T29`).

---

## EDMV4-T27: Write lens L14 -- Behavioral Test Coverage, with an explicit mandate boundary

| Field | Value |
|---|---|
| Epic | Audit Lenses |
| Phase | 3 |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV4-29 |
| Depends On | EDMV4-T21 |
| Target Components | plugins/edm/agents/edm-audit-behavioral-tests.md, plugins/edm/agents/edm-audit-test-quality.md, plugins/edm/agents/edm-test-coverage-auditor.md, plugins/edm/bin/tests/wave7-smoke.sh:1589, plugins/edm/CLAUDE.md |

### Description

EDM has two adjacent things that both miss this question. L4 (Test Quality) hunts defects *in the
tests themselves* -- `2>/dev/null || true` masking failures, mocks hiding the code under test.
`edm-test-coverage-auditor` reports *percentages* against configured thresholds. Neither asks "would
these tests catch a real bug in this change?" L14 does.

Because it sits between two existing mandates, the boundary must be stated in the prompt rather than
left to the synthesizer's false-alarm filter to sort out after the fact. Two lenses filing the same
finding is exactly the duplicate-finding noise the orthogonal-mandate design exists to prevent, and
the synthesizer's de-duplication is a recall-preserving mechanism, not a licence to overlap mandates.

The boundary is stated from all three sides: L14's own `## Scope`, L4's file, and
`edm-test-coverage-auditor`'s file, so no agent has to infer it.

### Acceptance Criteria

- [ ] AC1: `plugins/edm/agents/edm-audit-behavioral-tests.md` exists and satisfies `EDMV4-T28`'s
      house lens contract in full.
- [ ] AC2: Its process section covers six steps: map changed code to its tests; find new untested
      paths; verify edge and error paths; prefer meaningful assertions over no-throw checks; flag
      flaky patterns; and rate gaps.
- [ ] AC3: Gap ratings use the canonical `P0` / `P1` / `P2` / `NOTED` vocabulary and nothing else.
      ECC's **critical / important / nice-to-have** scale is **not** imported -- the file must not
      contain those three tokens as a severity scale. `CLAUDE.md Sec."Severity vocabulary"` is closed
      and no agent may define a divergent local scale (constraint C6). A smoke assertion greps the new
      file for `critical`, `important` and `nice-to-have` used as severity labels and fails on a hit.
- [ ] AC4: Its `## Scope` section carries **one** sentence bounding L14 against L4 and against
      `edm-test-coverage-auditor`: L4 owns defects inside tests, `edm-test-coverage-auditor` owns
      coverage percentages against thresholds, L14 owns whether the tests would catch a real bug in
      the changed behaviour.
- [ ] AC5: `agents/edm-audit-test-quality.md` (L4) gains the reciprocal sentence, so the boundary is
      stated from both sides. **The L4 file is `edm-audit-test-quality.md`; `agents/edm-audit-tests.md`
      does not exist and never has.** A ticket written against the wrong path would either fail or,
      worse, create a twelfth lens file by accident.
- [ ] AC6: `agents/edm-test-coverage-auditor.md` gains the same reciprocal sentence.
- [ ] AC7: A smoke assertion verifies the boundary sentence is present in all three files, keyed on a
      stable substring rather than the whole paragraph.
- [ ] AC8: The lens is unconditional. `L14` does not appear in `CONDITIONAL_LENS_IDS`, and its
      `## When this does NOT apply` uses the standard house sentence.
- [ ] AC9: All JSONL and Output-Format references use the lens ID `L14` consistently, and no text is
      copied from `ECC/agents/pr-test-analyzer.md`.
- [ ] AC10: `bash plugins/edm/bin/edm-check-grants` passes over the new file, and all three edited or
      created files are ASCII-only.

### Technical Notes

- **Verified.** The canonical lens filename list is `wave7-smoke.sh:1589` (`LENS_AGENTS`), which holds
  exactly on the current branch and enumerates `edm-audit-logic edm-audit-dead-code
  edm-audit-edge-cases edm-audit-test-quality edm-audit-runtime edm-audit-docs edm-audit-consistency
  edm-audit-security edm-audit-spec edm-audit-dry edm-audit-wiring`. A directory listing confirms
  eleven `edm-audit-*.md` lens files plus `edm-audit-synthesizer.md`, and confirms
  `edm-audit-tests.md` does **not** exist. AC5's warning is real, not hypothetical.
- `edm-test-coverage-auditor.md` is a **test-layer** agent, not a lens: it runs on `sonnet`/`high`
  and is `cyan`. Adding the reciprocal sentence does not make it a lens and must not change its
  frontmatter.
- Constraint C6 (AC3) is the concrete import risk in this ticket. The ECC source
  (`pr-test-analyzer.md:23-47`, a 39-line body) uses the critical/important/nice-to-have scale
  throughout. Read it for the six process steps; translate every severity token.
- `bin/edm-check-vocabulary` is the deterministic backstop for abolished vocabulary. Run it after
  writing the file; if `critical`/`important` need a carve-out for non-severity prose usage, use
  `bin/vocabulary-allowlist.txt` rather than weakening AC3.
- SRD-declared dependencies are `EDMV4-23` and `EDMV4-30`; `Depends On` carries `EDMV4-T21` per the
  epic DAG. See `EDMV4-T28` Technical Notes.

### Out of Scope

L4's and `edm-test-coverage-auditor`'s own mandates beyond the single reciprocal sentence each. The
`edm-audit-synthesizer` de-duplication behaviour. Growing `wave7-smoke.sh`'s name lists
(`EDMV4-T30`).

---

## EDMV4-T28: Specify and enforce the house lens contract for the three new lens agents

| Field | Value |
|---|---|
| Epic | Audit Lenses |
| Phase | 3 |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV4-30 |
| Depends On | EDMV4-T25, EDMV4-T26, EDMV4-T27 |
| Target Components | plugins/edm/agents/edm-audit-logic.md, plugins/edm/agents/edm-audit-security.md:154-157, plugins/edm/agents/edm-audit-silent-failures.md, plugins/edm/agents/edm-audit-type-design.md, plugins/edm/agents/edm-audit-behavioral-tests.md, plugins/edm/bin/tests/wave7-smoke.sh:1902-1912, plugins/edm/docs/canonical-sections.md, plugins/edm/CLAUDE.md |

### Description

Every existing lens agent shares a nine-part structural contract, verified in full against
`edm-audit-logic.md` (L1, 115 lines) and `edm-audit-security.md` (L8, 204 lines). Several parts of it
are **machine-asserted by existing smoke tests** -- notably T25 AC8 at `wave7-smoke.sh:1902-1912`,
which asserts the False Alarm Filter's exact framing sentence appears in every lens file, and T46 AC2
at `:4756-4763`, which asserts exactly three numbered criteria per lens. A new lens agent that does
not match is not merely inconsistent; it fails or silently escapes existing assertions.

This ticket is a constraint *on* `EDMV4-T25`, `EDMV4-T26` and `EDMV4-T27`, not a peer of them. It
specifies the contract those three files must satisfy; each of them cites it by ID and requires
conformance in full. Per-file conformance is verified at each agent ticket's completion. What
completes *here* is the contract's written specification plus the smoke-assertion extension that
enforces it, and that extension is complete only when the last of the three agent files has landed --
which is why this ticket is scheduled after them.

### Acceptance Criteria

- [ ] AC1: Frontmatter on all three new files matches the existing lens set exactly:
      `name: edm-audit-{lens-name}`, a YAML block-scalar `description:` naming the lens number and
      what it hunts, `tools: Glob, Grep, LS, Read, NotebookRead, WebFetch, TodoWrite, WebSearch,
      Write`, `model: opus`, `effort: max`, `maxTurns: 30`, `color: cyan`,
      `disallowedTools: Edit, NotebookEdit`.
- [ ] AC2: The tool grant is structurally read-only apart from `Write`. **No new lens is granted
      `Edit` or `NotebookEdit`.** `wave7-smoke.sh`'s CA-529 byte-identical `tools:` assertion passes
      with the three new files in its set.
- [ ] AC3: `model: opus` / `effort: max` matches the contested-audit-set row of
      `CLAUDE.md Sec."Model and effort assignments"` (`:368` on the current branch). No hand-picked
      downgrade is taken -- only a measured, mechanical promotion may retier that set. That row is
      updated to 14 lenses / 18 agents by `EDMV4-T31`, and this AC must not disagree with it.
- [ ] AC4: Each file's opening frame reads
      `You are executing **EDM Code Audit Lens L{N}: {Name}**.` followed immediately by the
      mandate-narrowing sentence in the house form ("Your mandate is ONLY this lens. Do not audit
      other dimensions -- other agents handle those.").
- [ ] AC5: `## Scope` carries the verbatim house scope-statement paragraph, byte-identical to the one
      at `agents/edm-audit-logic.md:22`. `wave7-smoke.sh`'s T46 AC1 scope-line count assertion passes
      with the new files included.
- [ ] AC6: `## False Alarm Filter` carries the identical framing sentence and **exactly three**
      numbered criteria specific to the lens, so both machine assertions pass: T25 AC8
      (`wave7-smoke.sh:1902-1912`) and T46 AC2 (`:4756-4763`). Both are named here so neither is
      missed by a sweep that finds only one.
- [ ] AC7: `## Output` states the two permitted write paths inside the current pass directory
      (`${OUTPUT_DIR}/lens-L{N}.md` and `${OUTPUT_DIR}/lens-L{N}.jsonl`), the ASCII-only reminder, the
      `mkdir -p` rationale for why `Write` is granted without `Bash(mkdir *)`, and the "JSONL file is
      authoritative on conflict" sentence.
- [ ] AC8: `## Output Format` cites `CLAUDE.md Sec."Severity vocabulary"` **and** carries the
      `Read docs/canonical-sections.md` anchoring instruction verbatim, with the "resolved relative to
      the EDM plugin's own root ... never the caller's cwd" qualifier. All three files are anchored
      from birth, not left for a later sweep. This is also the C6 enforcement point: every new lens
      cites the one closed severity scale rather than defining a local one.
- [ ] AC9: `## JSONL Line Format` restates the fixed schema literally with the correct lens ID, the
      D22/CA-130 stale-cache fallback clause, the five bulleted field rules (`id`,
      `round`/`round_type`, `sev`, `confidence`, `status`), and the residual-risk paragraph.
- [ ] AC10: `## When this does NOT apply` is present in all three. L12 and L14 use the standard
      "always applies once the code-audit skill selects lens L{N}" sentence; L13's differs per
      `EDMV4-T26` AC3/AC4.
- [ ] AC11: `color: cyan` matches `CLAUDE.md Sec."Agent color scheme"`, whose lens row is updated from
      11 to 14 by `EDMV4-T33`.
- [ ] AC12: `bash plugins/edm/bin/edm-check-grants` passes over all three new files, and the smoke
      extension asserting the contract lists all three by name.

### Technical Notes

- **Verified.** `agents/edm-audit-logic.md` is 115 lines; the anchoring sentence the SRD cites at
  `:69` holds exactly. `agents/edm-audit-security.md:154-157` holds exactly and carries the same
  anchoring paragraph wrapped across four lines -- copy the L1 form (single line) or the L8 form
  (wrapped) consistently, but the grepped substring must match either way, so key any assertion on a
  short unique substring such as `resolved relative to the EDM plugin's own root`.
- `wave7-smoke.sh:1902-1912` (T25 AC8) and `:4756-4763` (T46 AC2) both hold exactly. Note that T25
  AC8 iterates the hardcoded `lens_files` list at `:1905`, not a glob, so `EDMV4-T30` must grow that
  list before this ticket's conformance is actually enforced on the new files. That is the ordering
  reason this ticket's smoke extension is scheduled late.
- **Dependency direction, reconciled.** `srd.md` sets the one-way direction `EDMV4-27, 28, 29 ->
  EDMV4-30` (the agents depend on the contract) precisely to remove the three cycles v1.0.0
  introduced. This ticket's `Depends On` points the other way because the epic DAG schedules it by
  *completion*: the contract **text** is fully specified in this ticket's AC1-AC11 and is readable by
  `EDMV4-T25`/`T26`/`T27` from day one, while what completes here is the smoke enforcement whose file
  set is only whole once all three agents exist. There is no cycle in either reading -- the
  specification precedes the agents, the enforcement follows them.
- Do not re-author the contract from memory. Diff a new file against `edm-audit-logic.md`
  section-by-section; every heading, in order, must match.

### Out of Scope

The lens-specific content of the three files (`EDMV4-T25`, `EDMV4-T26`, `EDMV4-T27`). Growing
`lens_files`, `LENS_AGENTS`, `T46_LENSES` and `T48_CONTESTED_AGENTS` (`EDMV4-T30`). Retiering the
contested audit set.

---

## EDMV4-T29: Sweep skills/code-audit/SKILL.md's twelve lens-count sites

| Field | Value |
|---|---|
| Epic | Audit Lenses |
| Phase | 3 |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV4-31 |
| Depends On | EDMV4-T21 |
| Target Components | plugins/edm/skills/code-audit/SKILL.md:3,24,37,38-40,57,60,95-96,250,252-264,273-274,290,298,373,524, plugins/edm/agents/edm-audit-synthesizer.md:24, plugins/edm/CLAUDE.md |

### Description

`skills/code-audit/SKILL.md` carries the lens count in twelve places, spanning frontmatter, prose,
the `--lenses` validation range, the lens table itself, and the synthesizer launch prompt. Some are
cosmetic and some are load-bearing; the validation range at `:37` and the table at `:252-264` are the
ones that change behaviour. Two headings carry the count in the heading string itself --
`## The 11 Audit Lenses` at `:250` and `## What Single-Pass Audits Miss (Why 11 Lenses)` at `:524` --
so renaming them is a cross-file concern, not a local edit.

The lens table gains three rows. Per `CLAUDE.md`'s intent-to-file index the table **summarizes**; the
agent file remains authoritative for the mandate, so each new row is one line, not a mandate restated.

### Acceptance Criteria

- [ ] AC1: The frontmatter `description` at `:3` names 14 parallel orthogonal audit agents and lists
      all 14 dimensions, adding silent failures, type design and behavioral tests to the existing
      eleven.
- [ ] AC2: `:24`'s "Eleven auditors with **orthogonal mandates**" reads fourteen.
- [ ] AC3: `:37`'s lens-token validation accepts `L1` through `L14` and rejects `L15` and above with
      a clear message naming the accepted range.
- [ ] AC4: `:38-40`'s "If `--lenses` is omitted, run all 11" reads 14, and the `ROUND_TYPE`
      description at `:39` is updated for `EDMV4-T22`'s union rule rather than left describing
      set-equality.
- [ ] AC5: `:57`'s "eleven members means `full`" and `:60`'s "Passing all eleven explicitly" read 14,
      and `:56-61` no longer claims omitting the flag records `full` with an **empty** `lenses`
      array -- `EDMV4-T22` materializes it.
- [ ] AC6: `:95-96`'s Step 8a content-check prose reads 14 in both sentences.
- [ ] AC7: `:250`'s `## The 11 Audit Lenses` heading and `:524`'s
      `## What Single-Pass Audits Miss (Why 11 Lenses)` heading both read 14.
- [ ] AC8: `:252-264`'s lens table gains three rows -- `edm-audit-silent-failures` (L12),
      `edm-audit-type-design` (L13), `edm-audit-behavioral-tests` (L14) -- each with a one-line
      mandate summary. The L13 row is annotated as conditional with a pointer to Step 1's detection.
- [ ] AC9: `:273-274`'s Smoke-Audit-versus-Full-Round table, `:290`'s "run the full eleven regardless
      of ticket count" and `:298`'s "one full eleven-lens round" read 14.
- [ ] AC10: `:373`'s synthesizer launch prompt reads "fewer than 14".
- [ ] AC11: `agents/edm-audit-synthesizer.md:24`'s "The round type (full: 11 lenses, or partial:
      subset)" reads 14.
- [ ] AC12: No heading string renamed here is referenced by name from elsewhere without that
      reference also being updated. A grep for each changed heading string across `plugins/edm/`
      returns zero stale references, and the result is recorded.

### Technical Notes

- **All citations verified and holding exactly** on the current branch: `:3`, `:24`, `:37`, `:38-40`,
  `:57`, `:60`, `:95-96`, `:250`, `:273-274`, `:290`, `:298`, `:373`, `:524`, and
  `agents/edm-audit-synthesizer.md:24`. This is the one requirement in the epic whose `file:line` set
  needed no correction.
- `:37`'s validation range string is `L1-L11`, which the widened closure grep in `EDMV4-T31` matches
  explicitly. Changing it to `L1-L14` is required for that grep to close.
- `:38`'s exact string `run all 11` is what `wave7-smoke.sh:4902-4903` (T47 AC6) asserts under the
  banner "lens cap surviving unchanged". Changing it here **fails that test** until `EDMV4-T30`
  rewrites the assertion. Coordinate: either land `EDMV4-T30` first, or expect a red suite between
  the two.
- `:274` and `:290-298` also mention `L1,L9,L11` as the smoke set. That is a lens *selection*, not a
  count, and stays `L1,L9,L11`. Do not mechanically bump it.
- SRD-declared dependencies are `EDMV4-23`, `EDMV4-27`, `EDMV4-28` and `EDMV4-29`; `Depends On`
  carries `EDMV4-T21` per the epic DAG. AC8's three table rows name the three agent files, so land
  this after `EDMV4-T25`/`T26`/`T27` in practice or the table points at files that do not exist yet.

### Out of Scope

Step 1's stack-detection step and Step 4's `--na-lenses` argument (`EDMV4-T24`). The smoke assertions
that guard these strings (`EDMV4-T30`). `CLAUDE.md` and `README.md` count sites (`EDMV4-T31`,
`EDMV4-T33`).

---

## EDMV4-T30: Rewrite the smoke-suite lens-count assertions

| Field | Value |
|---|---|
| Epic | Audit Lenses |
| Phase | 3 |
| Priority | Must Have |
| Size | L |
| SRD Refs | EDMV4-32 |
| Depends On | EDMV4-T22 |
| Target Components | plugins/edm/bin/tests/wave7-smoke.sh, plugins/edm/bin/tests/wave6-smoke.sh:3434-3449, plugins/edm/bin/tests/run-all.sh |

### Description

This is the largest single piece of 4.4 and the one the source analysis does not mention at all -- it
names no test file. Two facts make it a first-class ticket rather than a mechanical sweep.

**`wave7-smoke.sh` contains two tests written specifically to assert the lens count never changes.**
T47 AC6 at `:4902-4903` checks that `skills/code-audit/SKILL.md` still contains the literal string
`run all 11`, under the banner "lens cap surviving unchanged". T48 AC6 at `:5417-5420` counts
`agents/edm-audit-*.md` files excluding the synthesizer and asserts `-eq 11`, under the banner "lens
fan-out unchanged: eleven lenses, none merged or removed". These are not incidental constants. They
must be deliberately revised -- rewritten to assert 14 and to state in their banner text that 14 is
the new invariant -- and that revision is called out as its own acceptance criterion, because
"revise a test whose entire purpose was asserting today's number is permanent" is a different kind of
change from "update a constant".

**`wave6-smoke.sh:3445-3449` will silently invert.** Its T27 AC1 case calls
`audit-round-start T27ROUND code --lenses L1,L2,L3,L4,L5,L6,L7,L8,L9,L10,L11` and asserts
`round_type == "full"`. The moment `ALL_LENS_IDS` grows, that input is an 11-of-14 **partial** round,
so the test's own claim reverses without the test being touched. That is risk R7 (High) and it needs
its own AC plus two new cases for the N/A composition.

**This ticket blocks any other work touching `bin/tests/wave7-smoke.sh`.** It is the single largest
and most interconnected file the initiative edits, and concurrent edits to it will conflict.

### Acceptance Criteria

- [ ] AC1: **Deliberate anti-regression revision, 1 of 2.** T47 AC6 (`wave7-smoke.sh:4902-4903`) is
      rewritten to assert the new `run all 14` string, and its banner text states that 14 is the
      invariant being protected. This is recorded as a deliberate revision of an anti-regression
      test, not an incremented constant.
- [ ] AC2: **Deliberate anti-regression revision, 2 of 2.** T48 AC6 (`:5417-5420`) is rewritten to
      assert `-eq 14`, its banner reads "fourteen lenses, none merged or removed", and its `die`
      message says 14. Same recording requirement as AC1.
- [ ] AC3: Every `-eq 11` / `== 11` lens assertion in `wave7-smoke.sh` is retargeted. The verified
      set is **nine** sites: `:1627`, `:1630`, `:1656`, `:1666`, `:1722`, `:1732`, `:1745`, `:1911`,
      `:5419`. Tree-wide the exact-integer set is **ten**, the tenth being `bin/edm-state:1611`
      (`ALL_LENS_IDS`'s own self-check), owned by `EDMV4-T21`.
- [ ] AC4: **Hardcoded lens-NAME lists.** All four are extended, because a name list stays green while silently dropping the new lenses: `:1589` (`LENS_AGENTS`, 11 names -> 14); `:1905` (`lens_files`, the list T25 AC8 actually iterates, 11 -> 14); `:4734` (`T46_LENSES`, 11 -> 14); and `:5386` (`T48_CONTESTED_AGENTS`, 15 -> 18).

      **Why this site matters most** (rationale folded in from the former AC5 by ticket-pack audit P2; its two mechanical obligations were already covered by this AC and by AC5 below): **`:5386` is called out explicitly as the dangerous instance.** `t48_contested_count` is computed by counting the hardcoded list itself at `:5389-5390`, so `:5402`'s `-eq 15` stays green no matter what the tree contains. Left unswept, the three new lenses are silently dropped out of the D16 opus/max assertion and nothing fails -- the only site in this sweep where the test passing is itself the defect. The list goes to 18 names and `:5402` to `-eq 18`.

- [ ] AC5: **Non-`-eq 11` exact-integer counts**, none of which the `-eq 11` grep finds: `:1688`
      (`-eq 12`, the eleven lenses plus `skills/code-audit/SKILL.md`) becomes `-eq 15`; `:4735` and
      `:4749` (`-eq 13`) become `-eq 16`; `:5402` (`-eq 15`) becomes `-eq 18`. Each is re-read at edit
      time to confirm what its number counts before it is changed -- these are offsets from 11, not
      the count itself, so a mechanical `+3` is right only if the offset is verified, and the
      verification is recorded per site.
- [ ] AC6: `:1751`'s literal loop bound (`for t24_n in 1 2 ... 11`) enumerates lens numbers and is
      extended through 14.
- [ ] AC7: The "twelve" banner strings at `:1591`, `:1599` and `:1603` (the CA-529 block, "all twelve
      `agents/edm-audit-*.md`" = eleven lenses plus the synthesizer) read fifteen.
- [ ] AC8: `:4756-4763` (T46 AC2) is a **second** machine assertion on the three-criteria False Alarm
      Filter, distinct from T25 AC8 at `:1902-1912`. Both are retargeted and both are named here, so
      neither is missed by a sweep that finds only one.
- [ ] AC9: Every retargeted assertion's accompanying `pass`/`fail` message text is updated too, so a
      passing test does not print "eleven lens prompts instruct a JSONL sibling" while asserting 14.
- [ ] AC10: Where an assertion counts files on disk, it is converted to a computed count compared
      against a single named constant defined once in the suite, rather than nine independent
      literals.
- [ ] AC11: `wave6-smoke.sh:3445-3449`'s explicit all-lenses invocation lists all 14 IDs and still
      asserts `round_type == "full"`; two **new** cases are added -- `--lenses` naming 13 IDs plus
      `--na-lenses L13` records `full`, and `--lenses` naming 13 IDs with `--na-lenses` omitted
      records `partial`; and `:3435-3443`'s existing partial case (`--lenses L1,L9,L11`) still records
      `partial` with its message text updated from "3-of-11" to "3-of-14".
- [ ] AC12: `bash plugins/edm/bin/tests/run-all.sh` passes with zero failures after the rewrite, and
      this ticket's work lands **before** any other ticket's changes touch `wave7-smoke.sh`.

### Technical Notes

- **Line numbers in this ticket are advisory; locate every site by the literal string the AC
  quotes.** An earlier revision claimed these citations were re-verified and held exactly, and
  that "unlike the `bin/edm-state` set, the test-file line numbers did not drift". Both claims
  are false on the reconciled tree (audit P1-10): `LENS_AGENTS` is at `:1596` not `:1589`,
  `lens_files` at `:1912` not `:1905`, `T46_LENSES` at `:4754` not `:4734`, and
  `T48_CONTESTED_AGENTS` at `:5406` not `:5386`. `wave6-smoke.sh` shifted a further +36 to +41
  above `:1179` when `EDMV4-T54` inserted its assertions. The **content** claims all still hold --
  `T48_CONTESTED_AGENTS` does carry 15 names, `LENS_AGENTS` does carry 11 -- so this ticket's
  substance is unaffected. This also makes `EDMV4-T31`'s re-inventory load-bearing rather than a
  belt-and-braces check.
- **Superseded note (kept for the audit trail):** the original claim that citations "hold
  exactly** on the current branch: `:1589`, `:1591`, `:1599`, `:1603`, `:1627`, `:1630`, `:1656`,
  `:1666`, `:1688`, `:1722`, `:1732`, `:1745`, `:1751`, `:1902-1912`, `:1905`, `:1911`, `:4734`,
  `:4735`, `:4749`, `:4756-4763`, `:4902`, `:5386`, `:5389-5390`, `:5402`, `:5417-5420`, `:5419`; and
  `wave6-smoke.sh:3427-3432`, `:3435-3443`, `:3445-3449`, `:3452-3457`. Unlike the `bin/edm-state`
  set, the test-file line numbers did not drift.
- `:4735` is `T48_SCOPE13="edm-explorer edm-audit-synthesizer $T46_LENSES"` -- a *derived* string, so
  it needs no name edit once `T46_LENSES` grows; only its `-eq 13` companion at `:4749` changes to
  `-eq 16`. Confirm this at edit time rather than assuming, per AC6.
- The `EDMV4-T31` re-inventory greps are **read-only** and should be run **before** this ticket's
  edits so any site missing from AC3-AC6 is added here rather than discovered afterwards.
  `EDMV4-T31`'s *edits* to `wave7-smoke.sh` serialize behind this ticket. That split resolves the
  apparent tension between `srd.md`'s "`EDMV4-32` depends on `EDMV4-33`" and "`EDMV4-32` blocks any
  other work touching `wave7-smoke.sh`".
- **Size justification (L, not decomposed).** Twenty-plus interdependent assertion sites in one
  7,000-line file, with a hard "no concurrent edits" constraint. Splitting it would either create the
  merge conflicts the serialization exists to prevent, or leave the suite red between sub-tickets,
  which defeats the only mechanism that catches a missed site.
- SRD-declared dependencies are `EDMV4-23`, `EDMV4-24` and `EDMV4-33`; `Depends On` carries
  `EDMV4-T22` per the epic DAG (which transitively carries `EDMV4-T21`).

### Out of Scope

The fixture files the retargeted counts run against (`EDMV4-T32`) -- AC3's `:1627`/`:1630` will stay
red until those land. Non-test count sites in `bin/edm-state`, `CLAUDE.md` and `README.md`
(`EDMV4-T31`, `EDMV4-T33`).

---

## EDMV4-T31: Re-inventory the lens-count sites and honour the do-not-touch list

| Field | Value |
|---|---|
| Epic | Audit Lenses |
| Phase | 3 |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV4-33 |
| Depends On | EDMV4-T21 |
| Target Components | plugins/edm/bin/tests/wave7-smoke.sh, plugins/edm/bin/edm-state:3628,4656,4758,4823, plugins/edm/CLAUDE.md:118-119,339,342,368, plugins/edm/README.md:204-205, plugins/edm/bin/edm-sync-canonical-sections, SRD/edm/EDMV4__ecc-integration/decisions.md |

### Description

Two opposite hazards sit either side of `EDMV4-T30`. First, the inventory may be incomplete: the
Phase-1 explorer found its sites by pattern matching rather than by reading a 7,000-line file, and its
own riskiest-assumption list flags that a bare `[[ "$count" -eq 11 ]]` with no nearby "eleven" token
could have been missed. Second, and more dangerous, **several occurrences of "eleven" in this
codebase are not the lens count**, and a careless find-replace corrupts them. `CLAUDE.md:298` and
`docs/canonical-sections.md:88` both say "referenced by name from the eleven touch points inventoried
in `architecture.md`" -- that is the **Mermaid-convention** touch-point count, a different eleven
entirely.

Three greps are required, not one: `-eq 11`/`== 11` for exact integers; `edm-audit-` appearing three
or more times on one line for hardcoded name lists; and `-eq 12|13|15` for counts that are offsets
from 11. The second and third shapes are structurally invisible to the first.

### Acceptance Criteria

- [ ] AC1: A second pass greps `bin/tests/` for `-eq 11` and `== 11` and reconciles the result against
      the nine sites named in `EDMV4-T30` AC3. Any additional site found is added there and the
      discrepancy recorded.
- [ ] AC2: The same pass runs across the whole plugin, not only `bin/tests/`. Tree-wide the
      exact-integer set is **ten**: the nine in `wave7-smoke.sh` plus `bin/edm-state:1611`. The
      SRD v1.0.0 figure of 54 was wrong and is superseded; the wider token set is 90 occurrences
      across 16 files.
- [ ] AC3: The pass also covers the two shapes `-eq 11` structurally cannot find, both of which stay
      green while being wrong: (a) hardcoded lens-name lists, found by grepping `bin/tests/` for
      `edm-audit-` appearing three or more times on one line, which surfaces `LENS_AGENTS`,
      `lens_files`, `T46_LENSES` and `T48_CONTESTED_AGENTS`; and (b) counts that are offsets from 11
      rather than 11 itself -- `-eq 12`, `-eq 13`, `-eq 15`. Any site either grep finds that is not
      already in `EDMV4-T30`'s list is added there and the discrepancy recorded.
- [ ] AC4: **Four `bin/edm-state` prose sites** are owned here rather than left to an unowned sweep:
      the `metrics-report` round-type legend, the CA-478 comment that names L11 as the last line of a
      full round, `cmd_audit_converged`'s "fresh eleven-lens opus round" text, and its unknown-
      round-type refusal text. Each is re-read at edit time -- some describe an invariant that remains
      true at 14 and must not be mechanically incremented -- and the decision per site is recorded.
- [ ] AC5: The **artifact-layout trees** whose illustrative listings end at `lens-L11` are swept:
      `plugins/edm/CLAUDE.md:118-119` and `plugins/edm/README.md:204-205`.
- [ ] AC6: **`CLAUDE.md`'s contested-audit-set row** ("11 code-audit lenses ... (15 agents)") is
      updated to 14 lenses / 18 agents in the same change as its machine counterparts,
      `wave7-smoke.sh:5386` and `:5402`. `EDMV4-T28` AC3 cites this row as authority; a prompt citing
      a table that says 11 while the assertion says 18 is worse than either alone.
- [ ] AC7: **`CLAUDE.md`'s D34 passage** carries two live lens-count strings ("all eleven" and
      "these thirteen files"). They are on **this** ticket's list, not on the do-not-touch list, and
      are reconciled in one pass with `EDMV4-T33`'s edit to the same passage rather than applied
      twice or applied in conflict.
- [ ] AC8: A **do-not-touch list keyed by string, not by line number**, is recorded in this ticket and
      honoured. Every entry records the matched text (or a stable unique substring) alongside the
      path; the line number is advisory only. It contains at minimum:
      (a) `CLAUDE.md` and `docs/canonical-sections.md` -- "referenced by name from the eleven touch
      points inventoried in `architecture.md`", the Mermaid touch-point count;
      (b) `bin/edm-state` -- "shipped eleven prose reports and ZERO JSONL files", a comment recounting
      a past incident, do not rewrite history;
      (c) `bin/edm-check-grants:11` -- a comment describing that check's own rationale, verified at
      edit time rather than assumed;
      (d) `CHANGELOG.md` (14 sites) -- a historical record, no past entry is edited; a new entry is
      the correct addition and belongs to `EDMV4-T33`;
      (e) `bin/edm-state` -- "does NOT imply \"a full eleven-lens round was run\"", an invariant that
      remains true at 14, re-read for correctness but not mechanically incremented;
      (f) `CLAUDE.md`'s do-NOT-adopt guard D1 and D2 text ("the 11 code-audit lenses", "the 11-lens or
      2-auditor fan-out") -- guard prose about fan-out policy, not a lens-count assertion, matched by
      the widened closure grep and owned by no requirement, so without this entry AC9 would report a
      defect nobody is responsible for.
- [ ] AC9: After the sweep, the closure grep
      `grep -rniE 'eleven|twelve|thirteen|fifteen|11[- ]lens|lens-L11|L1-L11|all 11|-eq (11|12|13|15)' plugins/edm/`
      returns only members of the do-not-touch list. Any survivor outside it is a defect. v1.0.0's
      narrower `eleven|11 lens|11-lens` pattern is superseded: it could not find `run all 11`, `L1-L11`,
      `lens-L11.jsonl`, `11 parallel orthogonal audit agents`, or any `-eq 11|12|13|15`.
- [ ] AC10: `docs/canonical-sections.md` is **regenerated** by `edm-sync-canonical-sections` rather
      than hand-edited, and `edm-sync-canonical-sections --check` exits 0. It is a generated mirror;
      editing it directly is the drift the `--check` assertion exists to catch.
- [ ] AC11: The reconciliation result -- sites found, sites added to `EDMV4-T30`, per-site decisions
      from AC4, and the final do-not-touch list -- is recorded in
      `SRD/edm/EDMV4__ecc-integration/decisions.md` so a later reader knows the inventory was closed
      deliberately.

### Technical Notes

- **Stale SRD citations, corrected.** `srd.md` names the four `bin/edm-state` prose sites as `:3632`,
  `:4660`, `:4762` and `:4827`. Verified on the current branch they are at **`:3628`** (the
  `metrics-report` "round_type full = all 11 lenses" legend), **`:4656-4657`** (the CA-478 comment,
  "on a full round that is L11"), **`:4758`** ("a fresh eleven-lens opus round") and **`:4823`**
  (`cmd_audit_converged`'s unknown-round-type refusal). Four lines high throughout. The do-not-touch
  entries the SRD cites as `:2390` and `:4619` are at **`:2386`** and **`:4615`** -- which is exactly
  why AC8 keys the list by string.
- **`CLAUDE.md` citations are mixed.** Verified: `:118-119` (artifact tree) holds; `:368`
  (contested-audit-set row) holds; `:339` ("all eleven") and `:342` ("these thirteen files") hold. But
  the SRD's `:292` (Mermaid touch points) is at **`:298`**, and `docs/canonical-sections.md:88` holds.
  D1 is at `:426` and D2 at `:429`. `README.md:204-205` holds.
- **Two unrelated elevens the SRD does not list, found during verification.** `bin/edm-state:1166` and
  `:1169` describe a coverage-table column width ("totals a CONSTANT 11 columns", "(11 and 10) match
  those totals"). Neither matches the AC9 closure grep, so they are not a false positive there -- but
  a contributor running a bare `grep -n 11 bin/edm-state` will hit them. Add both to the do-not-touch
  list. Same for `bin/edm-state:2605` (`EDMV3-T11 AC1`) and `:4124` (`T61 AC11`), which are ticket and
  AC identifiers, not counts.
- Line numbers in this ticket moved twice during this initiative and CA-464 already retired one
  line-range citation for going stale twice. A do-not-touch list keyed to a line number silently
  starts protecting a different line -- that is the whole reason for AC8's keying rule.
- SRD-declared dependency is `EDMV4-23` only, matching `Depends On`. The AC1/AC3 greps are read-only
  and should run before `EDMV4-T30` edits; this ticket's writes to `wave7-smoke.sh` serialize behind
  `EDMV4-T30` per its blocking clause.

### Out of Scope

Editing `wave7-smoke.sh`'s assertions themselves (`EDMV4-T30` -- this ticket supplies the reconciled
site list). The user-facing documentation surfaces and the CHANGELOG entry (`EDMV4-T33`).
`skills/code-audit/SKILL.md` (`EDMV4-T29`).

---

## EDMV4-T32: Grow the code-audit test fixtures from 11 to 14 lens pairs

| Field | Value |
|---|---|
| Epic | Audit Lenses |
| Phase | 3 |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV4-34 |
| Depends On | EDMV4-T21 |
| Target Components | plugins/edm/bin/tests/fixtures/code-audit/, plugins/edm/bin/tests/fixtures/code-audit/README.md:33, plugins/edm/bin/tests/wave7-smoke.sh:1627,1630 |

### Description

`bin/tests/fixtures/code-audit/` provides a full-round fixture whose `README.md:33` documents
`lenses-run.txt` as "the eleven lens IDs, one per line, with the `Round type: full` header". Several
`wave7-smoke.sh` assertions count fixture files directly -- `:1627` counts `lens-L*.jsonl` and `:1630`
counts `lens-L*.md`, both `-eq 11` -- so the fixture and the assertions must move together.

Two additional fixtures are needed for compositions that have no analogue today: the clean auto-N/A
round (13 lens pairs, `lenses_na: ["L13"]`, must remain `full`) and the contract-violation case
(`lenses_na: ["L13"]` with a `lens-L13.jsonl` present on disk, which must trigger `EDMV4-T23`'s third
downgrade reason).

### Acceptance Criteria

- [ ] AC1: The full-round fixture carries 14 `lens-L{N}.jsonl` files and 14 `lens-L{N}.md` files,
      `L1` through `L14`, and its `lenses-run.txt` lists all 14 IDs one per line under the existing
      `Round type: full` header.
- [ ] AC2: `bin/tests/fixtures/code-audit/README.md:33` documents 14 lens IDs, not eleven, and the
      surrounding references at `:21`, `:26` and `:28` that read `lens-L11` read `lens-L14`.
- [ ] AC3: A **new** fixture provides the 13-plus-N/A composition: 13 lens pairs with no `L13`, a
      `lenses-run.txt` carrying the 13 IDs plus the `Lenses N/A:` header line, and a round record with
      `lenses_na: ["L13"]`.
- [ ] AC4: A **negative** fixture provides the contract-violation case: `lenses_na: ["L13"]` but a
      `lens-L13.jsonl` present on disk, so `EDMV4-T23` AC4's downgrade reason is exercised against
      real files rather than a synthesized path.
- [ ] AC5: Every new JSONL fixture line conforms to the fixed schema
      (`{"schema":1,"id":null,"lens":"L{N}","round":N,"round_type":"full|partial","sev":...,
      "confidence":...,"file":...,"line":...,"title":...,"status":...}`) exactly as the existing
      eleven do. `jq empty` over each new file exits 0.
- [ ] AC6: Each new `lens-L{N}.jsonl` carries two findings (one `open`, one `NOTED`), matching the
      shape the existing `lens-L2` through `lens-L11` fixtures use, and each finding in the JSONL has
      a matching prose entry in the sibling `lens-L{N}.md`.
- [ ] AC7: All fixture content is ASCII-only. `bash plugins/edm/bin/edm-lint-artifacts --path
      plugins/edm/bin/tests/fixtures/code-audit/` reports no unicode-class violation.
- [ ] AC8: `wave7-smoke.sh`'s T24 AC0 assertions at `:1627` and `:1630` count 14 files each and pass.
- [ ] AC9: The new fixtures do not disturb the existing `lens-L1.jsonl` widest-fixture role (all four
      severities present) that other assertions depend on.

### Technical Notes

- **Verified.** `bin/tests/fixtures/code-audit/README.md:33` holds exactly, as do the `lens-L11`
  references at `:21`, `:26` and `:28`. `wave7-smoke.sh:1627` and `:1630` hold exactly.
- The fixture is deliberately hand-written and stable, per its own README: "a fixed target the
  mechanism is checked against" so a lens prompt or model version change cannot move it. Author the
  three new pairs in the same register; do not generate them from a live audit run.
- The two new fixtures need a round record, not just files on disk. Their `.edm-state.json` shape must
  match what `EDMV4-T22` writes -- a materialized `lenses` array plus `lenses_na`. Author them after
  `EDMV4-T22` lands so the shape is copied from real output rather than guessed.
- **SRD-declared dependencies are `EDMV4-23`, `EDMV4-24` and `EDMV4-25`**; `Depends On` carries
  `EDMV4-T21` per the epic DAG. The additional two are real sequencing constraints for AC3 and AC4
  specifically (they encode `EDMV4-T22`'s round-record shape and exercise `EDMV4-T23`'s third
  downgrade reason); AC1, AC2, AC5-AC7 and AC9 depend on `EDMV4-T21` alone and can proceed
  immediately.
- `:1627`/`:1630` stay red between `EDMV4-T21` and this ticket. That window is expected and is called
  out in `EDMV4-T30`'s Out of Scope.

### Out of Scope

The smoke assertions that consume the fixtures (`EDMV4-T30`). The backstop logic the negative fixture
exercises (`EDMV4-T23`). Any fixture outside `bin/tests/fixtures/code-audit/`.

---

## EDMV4-T33: Sweep the documentation and user-facing surfaces for the lens count

| Field | Value |
|---|---|
| Epic | Audit Lenses |
| Phase | 3 |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV4-35 |
| Depends On | EDMV4-T21 |
| Target Components | plugins/edm/.claude-plugin/plugin.json, .claude-plugin/marketplace.json, plugins/edm/README.md:123,204-205,269,272, plugins/edm/CLAUDE.md:118-119,217,256,339,368,1007, plugins/edm/skills/implement/SKILL.md:48,241, plugins/edm/evals/README.md:306, plugins/edm/docs/audit-patterns/README.md:137, plugins/edm/docs/audit-patterns/code-audit.md, plugins/edm/CHANGELOG.md |

### Description

The lens count appears on surfaces a user sees before they ever run the plugin -- the marketplace
manifest description, the README's feature table, and `CLAUDE.md`'s agent-colour table. Leaving any of
them at 11 makes the plugin describe itself inaccurately in its own storefront, and the manifest
description in particular is what a prospective user reads in the plugin browser.

**Line numbers in this ticket are advisory.** `CLAUDE.md`'s numbers moved twice during this initiative
and several SRD cites are known stale by 4 to 7 lines. Every site is located at edit time by its
matched string. A number that no longer matches is a cue to re-locate, not a site to skip.

### Acceptance Criteria

- [ ] AC1: `plugins/edm/.claude-plugin/plugin.json`'s manifest `description` reads "14-lens code
      audit", and `.claude-plugin/marketplace.json`'s `edm` entry is checked for the same string and
      updated if present.
- [ ] AC2: `plugins/edm/README.md` reads 14 throughout: `:123`'s "11-lens exhaustive audit" and "a
      full eleven-lens round", `:269`'s "does not have to be the full eleven lenses", and `:272`'s
      "the synthesizer instead of eleven" / "Reserve the full eleven-lens round".
- [ ] AC3: `plugins/edm/CLAUDE.md`'s agent-colour table row reads "all 14 `edm-audit-*` lenses +
      `edm-audit-synthesizer`".
- [ ] AC4: `CLAUDE.md`'s "a full eleven-lens round was ever recorded (CA-426)" passage and its
      "11-lens code-audit methodology" passage in the testing-changes section both read 14.
- [ ] AC5: `CLAUDE.md:118-119` and `plugins/edm/README.md:204-205` -- the artifact-layout trees whose
      illustrative listings end at `lens-L11` -- read `lens-L14`. This overlaps `EDMV4-T31` AC5; the
      two land in one pass, not twice.
- [ ] AC6: The D34 passage's lens-count strings are reconciled in a single pass with `EDMV4-T31` AC7
      rather than applied twice or applied in conflict. The passage is also `EDMV4-49`'s home
      paragraph; all edits to it land together.
- [ ] AC7: `CLAUDE.md`'s contested-audit-set row reads 14 code-audit lenses and 18 agents, matching
      its machine counterparts `wave7-smoke.sh:5386` and `:5402`. `EDMV4-T28` AC3 cites this row as
      authority, so the two must not disagree. This overlaps `EDMV4-T31` AC6; same single-pass rule.
- [ ] AC8: `plugins/edm/skills/implement/SKILL.md:48` and `:241` read 14.
- [ ] AC9: `plugins/edm/evals/README.md:306` reads 14, and
      `plugins/edm/docs/audit-patterns/README.md:137`'s table row is either updated to 14 or
      explicitly retained as a dated historical seed row, with the choice recorded in `decisions.md`
      rather than left ambiguous.
- [ ] AC10: `plugins/edm/docs/audit-patterns/code-audit.md` is inspected for lens-count-adjacent prose
      and updated where the count is asserted as current, with the inspection result recorded even if
      no edit was needed.
- [ ] AC11: `plugins/edm/CHANGELOG.md` gains **one new entry** documenting the 11-to-14 change, the
      three new lenses by name and number, the `lenses_na` field, and the `round_type` derivation
      change. **No historical entry is edited** -- the 14 historical mentions are on `EDMV4-T31`'s
      do-not-touch list.
- [ ] AC12: `plugin.json`'s version is bumped and `.claude-plugin/marketplace.json`'s `edm` version is
      bumped to match, since the manifest description changed, and
      `claude plugin validate plugins/edm/` exits 0 after the manifest change.

### Technical Notes

- **Citation verification.** Holding exactly: `README.md:123`, `README.md:204-205`,
  `skills/implement/SKILL.md:48` and `:241`, `evals/README.md:306`,
  `docs/audit-patterns/README.md:137`, `CLAUDE.md:118-119`, `CLAUDE.md:368`, `CLAUDE.md:339`.
  **Stale:** the SRD's `README.md:265,268` are at **`:269`** and **`:272`**; `CLAUDE.md:211`
  (agent-colour row) is at **`:217`**; `CLAUDE.md:250` (the CA-426 passage) is at **`:256`**;
  `CLAUDE.md:1000` is at **`:1007`**; `CLAUDE.md:333` (the D34 home paragraph) resolves to the
  passage whose live counts are at **`:339`** and **`:342`**. `plugin.json`'s description line was not
  verified by number -- locate it by the `"description"` key.
- The gitmoji shortcode convention applies to the CHANGELOG entry style used elsewhere in that file;
  match the surrounding entries rather than inventing a format.
- `.claude-plugin/marketplace.json` is at the **repository** root, not the plugin root. Both version
  fields must match or the marketplace entry drifts from the plugin manifest.
- SRD-declared dependencies are `EDMV4-31` and `EDMV4-33`; `Depends On` carries `EDMV4-T21` per the
  epic DAG. AC5, AC6 and AC7 explicitly overlap `EDMV4-T31` and must be executed in one pass with it
  -- coordinate rather than racing.

### Out of Scope

`skills/code-audit/SKILL.md` (`EDMV4-T29`). The `bin/edm-state` prose sites and the do-not-touch list
(`EDMV4-T31`). Any smoke assertion (`EDMV4-T30`).
