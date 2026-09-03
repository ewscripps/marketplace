# QC Audit Report: Audit Lenses (EDMV4) [Shard 2/4, wave 2]

**Date**: 2026-09-02
**Tickets audited**: `EDMV4-T25`, `EDMV4-T27`, `EDMV4-T29`, `EDMV4-T33` (4 assigned, 4 graded)
**Epic file**: `tickets/epics/04-audit-lenses.md`
**Mode**: `implementation_mode=standard` -- the TDD compliance pass does not run.

## Summary

| Ticket | Title | Verdict |
|---|---|---|
| `EDMV4-T25` | Write lens L12 -- Silent Failures | **PASS** |
| `EDMV4-T27` | Write lens L14 -- Behavioral Test Coverage, with an explicit mandate boundary | **PASS** |
| `EDMV4-T29` | Sweep `skills/code-audit/SKILL.md`'s twelve lens-count sites | **FAIL** |
| `EDMV4-T33` | Sweep the documentation and user-facing surfaces for the lens count | **PASS** |

43 acceptance criteria graded. 42 PASS, 1 FAIL, 0 PARTIAL. Two P2 advisories are attached to
otherwise-passing ACs and are listed under Remediation.

**Every AC in this shard was statically verifiable.** No AC required a live service, database or
browser, so no PARTIAL verdicts were recorded and nothing from this shard goes to
`/edm:verify-runtime`.

---

## House lens contract conformance (T25 AC1 / T27 AC1)

`EDMV4-T28` is not implemented, so this is the only check on the contract. I compared both new
files mechanically against three existing lenses -- `edm-audit-logic.md` (L1, the exemplar
`EDMV4-T28` names), `edm-audit-security.md` (L8, the wrapped-anchoring variant) and
`edm-audit-dry.md` (L10) -- rather than accepting a claim of conformance.

Method: normalise the lens ID to a placeholder, strip blank lines, and diff every line of L1
against each new file. **Every L1 line absent from L12/L14 is lens-specific content**
(frontmatter `name`/`description`, opening frame, hunt targets, false-alarm criteria, example
table rows). Zero structural boilerplate lines diverge.

| `EDMV4-T28` clause | L12 evidence | L14 evidence | Result |
|---|---|---|---|
| AC1 frontmatter, block-scalar `description` naming lens number | `edm-audit-silent-failures.md:1-14` | `edm-audit-behavioral-tests.md:1-14` | PASS |
| AC2 no `Edit`/`NotebookEdit`; CA-529 byte-identical `tools:` | `:8`, `:13` | `:8`, `:13` | PASS -- `grep -h '^tools:' agents/edm-audit-*.md \| sort -u` yields exactly **1** line across all 14 files; same for `model:` and `disallowedTools:` |
| AC3 `model: opus` / `effort: max` | `:9-10` | `:9-10` | PASS -- agrees with `CLAUDE.md:493` (14 lenses / 18 agents) |
| AC4 opening frame + mandate-narrowing sentence | `:16-18` | `:16-18` | PASS -- byte-identical to `edm-audit-logic.md:16-18` modulo lens name |
| AC5 verbatim house scope paragraph | `:22` | `:22` | PASS -- byte-identical to `edm-audit-logic.md:22` |
| AC6 identical FAF framing + **exactly three** numbered criteria | `:54`, 3 criteria `:56-58` | `:37`, 3 criteria `:39-41` | PASS -- framing sentence matches `wave7-smoke.sh:1903` verbatim; criteria count computed with T46 AC2's own awk/grep (`:4779-4780`) returns 3 for both |
| AC7 `## Output` two write paths, ASCII reminder, `mkdir -p` rationale, JSONL-authoritative | `:60-70` | `:43-53` | PASS -- byte-identical to `edm-audit-logic.md:55-65` |
| AC8 `## Output Format` anchoring instruction verbatim | `:74` | `:57` | PASS -- L14's line is an exact **prefix match** of `edm-audit-logic.md:69` plus an appended AC3 sentence; the keyed substring `resolved relative to the EDM plugin's own root` is present in both |
| AC9 `## JSONL Line Format`, D22/CA-130 clause, five field rules, residual risk | `:90-115` | `:73-98` | PASS -- byte-identical modulo lens ID |
| AC10 `## When this does NOT apply`, standard sentence | `:117-119` | `:100-102` | PASS |
| AC11 `color: cyan` | `:12` | `:12` | PASS -- agrees with `CLAUDE.md:226` (`all 14 edm-audit-* lenses`) |
| AC12 `edm-check-grants` exits 0 | ran: exit **0** | ran: exit **0** | PASS |

Heading set and order, extracted outside fenced blocks, is identical across all four files
compared: `## Scope`, `## What You Hunt For`, `## False Alarm Filter`, `## Output`,
`## Output Format`, `## JSONL Line Format`, `## When this does NOT apply`.

`bin/edm-check-grants` exits **0** with by-name citation anchoring enforced -- no bare
`Sec."..."` regression from either new file. `bin/edm-check-vocabulary` and
`bin/edm-lint-artifacts --path agents/` both exit 0.

---

## Detailed Findings

### `EDMV4-T25`: Write lens L12 -- Silent Failures -- **PASS**

All 9 acceptance criteria verified statically.

- [x] **AC1** House lens contract in full -- verified in the table above against three existing
      lenses. `agents/edm-audit-silent-failures.md`, 119 lines.
- [x] **AC2** Five hunt categories -- `:28` Errors Converted to Silence (empty catch, errors to
      `null`/empty collections, discarded error object); `:33` Inadequate Logging (missing
      context, wrong severity, log-and-forget); `:38` Dangerous Fallbacks; `:43` Error
      Propagation Problems (lost stack traces, generic rethrow, missing async handling); `:48`
      Missing Handling Entirely (network/file/database, transactional work without rollback). All
      five map to the AC's (a)-(e).
- [x] **AC3** Dangerous-fallback mandate stated most explicitly -- the heading itself carries the
      rationale at `:38` (`the gap L1 does not cover -- the most explicit mandate in this lens`),
      and it is the longest of the five categories. Concrete code shapes at `:39`
      (`.catch(() => [])`, `except Exception: return {}`, `result ?? []`) and a dedicated
      "Concrete shape to flag" bullet at `:41`.
- [x] **AC4** Unconditional -- `bin/edm-state:1684` reads `CONDITIONAL_LENS_IDS="L13"`, so L12 is
      absent from it; `ALL_LENS_IDS` at `:1672` holds L1-L14. No N/A exit anywhere in the file;
      `:119` carries the standard house sentence.
- [x] **AC5** L1/L12 boundary -- `:24`, one sentence inside `## Scope`, immediately after the
      house scope paragraph.
- [x] **AC6** No text copied from `ECC/agents/silent-failure-hunter.md` -- measured, not assumed:
      **zero shared 5-grams** between the two files. The only overlap is at the taxonomy-label
      level (`Inadequate Logging`, `Dangerous Fallbacks`), which AC2 itself mandates as the
      category names; no shared sentence exists. The clean-room posture is recorded in
      `plugins/edm/CLAUDE.md`'s house-style attribution section.
- [x] **AC7** Lens ID consistency -- `${OUTPUT_DIR}/lens-L12.md` `:63`, `${OUTPUT_DIR}/lens-L12.jsonl`
      `:64`/`:92`, `"lens":"L12"` `:97`. A token scan of the whole file yields 15 `L12` and 2 `L1`,
      both `L1` occurrences being the deliberate AC5 boundary sentence. No stray lens ID.
- [x] **AC8** Length scales with hunt categories, ASCII-only -- 119 lines for five categories,
      matching no existing lens's count (L1 is 114, L8 is 204). Zero non-ASCII bytes.
- [x] **AC9** `bash plugins/edm/bin/edm-check-grants` -- ran, exit **0**.

### `EDMV4-T27`: Write lens L14 -- Behavioral Test Coverage -- **PASS**

All 10 acceptance criteria verified statically. One P2 advisory on AC9 (below).

- [x] **AC1** House lens contract in full -- verified in the table above.
      `agents/edm-audit-behavioral-tests.md`, 102 lines.
- [x] **AC2** Six process steps -- `:28` map changed code to its tests; `:29` find new untested
      paths; `:30` verify edge and error paths; `:31` prefer meaningful assertions over no-throw
      checks; `:32` flag flaky-shaped patterns; `:33` rate every gap.
- [x] **AC3** ECC severity scale banned by name, with a live positive control. Two independent
      checks:
      1. My own scan, `grep -icE '\b(critical|important|nice-to-have)\b'` over
         `agents/edm-audit-behavioral-tests.md`, returns **0**.
      2. The shipped assertion at `wave8-smoke.sh:1000-1006` runs the same scan, and
         `:1010-1019` builds a throwaway fixture reading
         `Rate every gap as critical, important, or nice-to-have.` and asserts the scan fires on
         it. I confirmed this control **passes for the right reason** by running the suite:
         `PASS: EDMV4-T27 AC3 -- positive control: the scan fires on a known-bad ECC-scale fixture`.
      The control is a separate temp file, so it cannot self-match the prose in the file under
      test -- this is not the five-times-recurring self-matching-scan class. The canonical scale
      is cited affirmatively at `:57`, and `bin/edm-check-vocabulary` exits 0.
- [x] **AC4** One sentence bounding L14 against both neighbours -- `:24`, inside `## Scope`,
      naming all three roles in a single sentence.
- [x] **AC5** L4 reciprocal -- `agents/edm-audit-test-quality.md:21`, inside its `## Scope`. The
      correct file: `agents/edm-audit-tests.md` does **not** exist (confirmed by directory
      listing; `agents/edm-audit-*.md` holds 14 files = 13 lenses + the synthesizer, with
      `edm-audit-type-design.md` still owed by `EDMV4-T26`). No twelfth-lens file was created by
      accident, and `wave8-smoke.sh:956-958` asserts that absence.
- [x] **AC6** `edm-test-coverage-auditor` reciprocal -- `agents/edm-test-coverage-auditor.md:29`.
      Its frontmatter is untouched: still `model: sonnet`, `effort: high`, `maxTurns: 50`,
      `color: cyan` (`:11-15`) -- it was not accidentally promoted into the lens family.
- [x] **AC7** Smoke assertion keyed on a stable substring -- `wave8-smoke.sh:1028-1038` keys on
      `whether the tests would catch a real bug in the changed behavior`, not a whole paragraph,
      and requires 3/3 files. I verified independently: that exact substring appears in
      `edm-audit-behavioral-tests.md:24`, `edm-audit-test-quality.md:21` and
      `edm-test-coverage-auditor.md:29`, and nowhere else in `plugins/edm/` outside the assertion
      itself.
- [x] **AC8** Unconditional -- `bin/edm-state:1684` names only L13; `:102` carries the standard
      house sentence.
- [x] **AC9** Lens ID consistency -- `${OUTPUT_DIR}/lens-L14.md` `:46`, `.jsonl` `:47`/`:75`,
      `"lens":"L14"` `:80`. Token scan: 15 `L14`, 2 `L4`, both the deliberate AC4 boundary
      sentence. On the copy clause: measured against `ECC/agents/pr-test-analyzer.md`, **zero
      shared 8-grams** and exactly **one** shared run -- the seven-word step name
      `prefer meaningful assertions over no-throw checks` (ECC `:37`, EDM `:31`). See the P2
      advisory below; graded PASS because this ticket's own AC2 prescribes that phrase verbatim.
- [x] **AC10** `edm-check-grants` exit **0**; all three touched files zero non-ASCII bytes
      (`edm-lint-artifacts --path agents/` exits 0).

All 58 shipped `EDMV4-T25`/`EDMV4-T27` assertions in `wave8-smoke.sh` pass.

**Finding**: [P2] `EDMV4-T27` | `plugins/edm/agents/edm-audit-behavioral-tests.md:31` | AC#9:
"no text is copied from `ECC/agents/pr-test-analyzer.md`" | AC9's copy clause and AC2's step-4
wording are in tension: AC2 prescribes the step name `prefer meaningful assertions over no-throw
checks`, which is `pr-test-analyzer.md:37` verbatim (modulo leading capital). The overlap is a
single 7-word functional idiom -- zero shared 8-grams, and nothing of the ECC prompt body
carries over (39-line ECC body vs. 102-line EDM lens). Not graded FAIL because the implementer
could not satisfy AC2's literal wording and AC9's absolute clause simultaneously; this is a
specification tension, not an implementation defect.

### `EDMV4-T29`: Sweep `skills/code-audit/SKILL.md`'s twelve lens-count sites -- **FAIL**

11 of 12 acceptance criteria verified. AC12 is half-met.

- [x] **AC1** `skills/code-audit/SKILL.md:3` -- "14 parallel orthogonal audit agents" and 14
      dimensions listed; silent failures, type design and behavioral tests appended to the
      existing eleven.
- [x] **AC2** `:24` -- "Fourteen auditors with **orthogonal mandates**".
- [x] **AC3** `:37-38` -- "Validate lens tokens against L1-L14; reject unknown tokens (including
      `L15` and above) with a clear message naming the accepted range." The `L1-L11` string
      `EDMV4-T31`'s widened closure grep matches explicitly is gone.
- [x] **AC4** `:39` -- "run all 14"; `:40-42` `ROUND_TYPE` rewritten to `EDMV4-T22`'s union rule
      ("the union of the lenses run and any lenses legitimately marked N/A ... covers all 14 lens
      IDs"), not set-equality.
- [x] **AC5** `:65` -- "Passing all fourteen explicitly"; `:59-64` replaces the "eleven members
      means `full`" derivation with the union rule and states explicitly that omitting the flag
      "materializes `lenses` as the full 14-lens set **rather than recording an empty array**",
      so the empty-array claim AC5 names is gone.
- [x] **AC6** `:86` ("e.g. 14 on a full round") and `:100-101` ("cannot distinguish fourteen
      correctly-schema'd files from fourteen files carrying an invented schema") -- both Step 8a
      count sentences read 14.
- [x] **AC7** `:255` `## The 14 Audit Lenses`; `:536` `## What Single-Pass Audits Miss (Why 14 Lenses)`.
- [x] **AC8** `:256-271` -- table gains exactly three rows: `edm-audit-silent-failures` (L12,
      `:269`), `edm-audit-type-design` (L13, `:270`), `edm-audit-behavioral-tests` (L14, `:271`),
      one line each, no mandate restated. The L13 row is annotated
      `(**conditional**: auto-N/A on an untyped stack, see Step 1)`.
- [x] **AC9** `:282` "**Full round** (14 lenses)"; `:298` "run the full fourteen regardless of
      ticket count"; `:306` "one full fourteen-lens round". The `L1,L9,L11` smoke *selection* at
      `:282`/`:305` is correctly left alone -- not mechanically bumped.
- [x] **AC10** `:381` -- "If this is a partial round (fewer than 14 lenses)".
- [x] **AC11** `agents/edm-audit-synthesizer.md:24` -- "The round type (full: 14 lenses, or
      partial: subset)".
- [ ] **AC12** "A grep for each changed heading string across `plugins/edm/` returns zero stale
      references, **and the result is recorded**." -- **half FAIL**.
      - Clause 1 **holds**, verified independently rather than taken on report. Greps across the
        whole of `plugins/edm/` for `The 11 Audit Lenses`, `Why 11 Lenses`, `Audit Lenses` and
        `Single-Pass Audits Miss` return exactly two hits total, both being the renamed headings'
        own definition sites (`skills/code-audit/SKILL.md:255` and `:536`). Neither heading is
        referenced by name from anywhere else in the plugin, so nothing went stale.
      - Clause 2 **does not hold**. The grep result is recorded nowhere: `decisions.md` has no
        `EDMV4-T29` entry (D33 is `EDMV4-T33`'s and does not cover this); commit `6e64c86`'s
        message records only the edits ("both headings that name the lens count from 11 to 14")
        and neither states that a closure grep was run nor its result; `bin/tests/*.sh` contains
        no `EDMV4-T29` assertion at all; `HANDOFF.md` and `.edm-state.json` carry nothing.

**Finding**: [P1] `EDMV4-T29` | `SRD/edm/EDMV4__ecc-integration/decisions.md` | AC#12: "A grep for
each changed heading string across `plugins/edm/` returns zero stale references, and the result
is recorded" | The grep's *result* is recorded nowhere -- not in `decisions.md`, not in commit
`6e64c86`'s message, not in any smoke assertion. The substantive property is true (independently
re-verified: zero stale references), so this is a bookkeeping clause left unmet, not a broken
sweep. Recording it is what lets a later reader distinguish "checked, clean" from "never checked"
-- the same rationale `EDMV4-T31` AC11 and `EDMV4-T33` AC9 encode for their own sweeps.

**Cross-ticket, not a T29 defect**: the L13 table row at `:270` names
`agents/edm-audit-type-design.md`, which does not yet exist -- exactly the ordering condition
T29's own Technical Notes anticipate, owned by `EDMV4-T26`. AC8 requires the row by that name, so
the row is correct as written.

### `EDMV4-T33`: Sweep the documentation and user-facing surfaces -- **PASS**

All 12 acceptance criteria verified statically. One P2 advisory (below).

- [x] **AC1** `plugins/edm/.claude-plugin/plugin.json:5` reads "14-lens code audit"; the root
      `.claude-plugin/marketplace.json` `edm` entry was checked, carried the same string, and was
      updated to match.
- [x] **AC2** `README.md:123` "14-lens exhaustive audit" and "a full fourteen-lens round";
      `:269` "does not have to be the full fourteen lenses"; `:272` "the synthesizer instead of
      fourteen" and "Reserve the full fourteen-lens round".
- [x] **AC3** `plugins/edm/CLAUDE.md:226` -- ``| `cyan` | all 14 `edm-audit-*` lenses + `edm-audit-synthesizer` |``.
- [x] **AC4** `CLAUDE.md:265` "a full fourteen-lens round was ever recorded (CA-426)";
      `CLAUDE.md:1377` "the 14-lens code-audit methodology" in the testing-changes section.
- [x] **AC5** `CLAUDE.md:121-122` and `README.md:204-205` -- both artifact-layout trees now list
      `lens-L1.jsonl ... lens-L14.jsonl` / `lens-L1.md ... lens-L14.md`. Landed in one pass with
      `EDMV4-T31` AC5, not twice.
- [x] **AC6** `CLAUDE.md:460` -- the D34 passage reads "all fourteen `agents/edm-audit-*.md` lens
      definitions". Reconciled in a single pass; no conflicting double-edit. (The adjacent "all
      fourteen files `EDMV4-T04` anchored" is a different fourteen -- anchored files, not lenses
      -- and is correct.)
- [x] **AC7** `CLAUDE.md:493` -- "Contested audit set -- 14 code-audit lenses, ... (18 agents)".
      This is the row `EDMV4-T28` AC3 cites as authority, and it now agrees with that citation.
- [x] **AC8** `skills/implement/SKILL.md:66` and `:269` both read "14-lens".
- [x] **AC9** `evals/README.md:305-306` -- "the eighteen contested agents (the fourteen code-audit
      lenses, ...)". `docs/audit-patterns/README.md:137` took the explicit second branch: retained
      unchanged as a dated historical seed row (`| code-audit.md | 11-lens code audit | EDMV2 seed
      (2026-06-08) |`), with the choice recorded in `decisions.md` D33. The AC offers this as an
      either/or, so retention is compliant, and the reasoning is sound -- the row's own third
      column dates it.
- [x] **AC10** `docs/audit-patterns/code-audit.md` inspected, result recorded in D33. **I
      re-verified the recorded claim rather than accepting it**: a count-word grep over all 267
      lines returns only three hits, all of the dated per-finding form D33 describes
      (`### CA-513 (P1, lenses L10 + L1): ... (EDMV3, 2026-08-21, P2)` at `:101`, and the same
      shape at `:175` and `:184`). Each names individual lens IDs; none asserts a total. The
      file's only other numeral-bearing header is `Frequency: [x/16] = appeared in x of 16
      audited initiatives` (`:10`), a corpus size, not a lens count. D33's characterisation is
      accurate.
- [x] **AC11** `CHANGELOG.md` gains one new `### Added` entry under `[Unreleased]` naming all
      three lenses by number and name, the `lenses_na` field, the `--na-lenses` flag, and the
      `round_type` union-rule derivation. Commit `74ccaf2`'s diff of that file is
      **additions only** -- no historical entry edited, honouring `EDMV4-T31` AC8(d).
- [x] **AC12** `plugin.json:4` and the root `marketplace.json` `edm` entry both read `3.3.0`
      (from `3.2.2`) -- the two match. `claude plugin validate plugins/edm/` **ran, exit 0**
      ("Validation passed with warnings"; the sole warning is the pre-existing, by-design
      plugin-root `CLAUDE.md` notice, unrelated to this change).

**D33 accuracy check (all five claims verified against the tree)**

| D33 claim | Verified |
|---|---|
| `docs/audit-patterns/README.md:137` retained as dated seed row | Yes -- row present, unchanged, third column dates it to the EDMV2 seed |
| `docs/audit-patterns/code-audit.md` carries no current-count assertion | Yes -- re-derived independently, see AC10 above |
| `plugins/edm/CLAUDE.md`'s `round_type` state-field row left to `EDMV4-T22`/`T23` | Yes -- correctly handed off, and the site now carries no stale count (T22 rewrote it to the union rule in this same wave) |
| Root `CLAUDE.md`'s edm bullet ("an 11-lens code audit") is genuinely stale, outside `plugins/edm/`, and outside every T29/T33/T16 Target Components list | Yes on all three -- the string is at root `CLAUDE.md:69`; it is outside the plugin tree; T33's Target Components names root `.claude-plugin/marketplace.json` but not root `CLAUDE.md` |
| One extra in-scope site fixed beyond the citation list: the `maxTurns: 30` floor passage | Yes -- `CLAUDE.md:395` now reads "the fourteen code-audit lens agents' own ceiling" |

D33 is accurate on every claim it makes. It is **incomplete in one respect**, recorded below.

**Finding**: [P2] `EDMV4-T33` | `/Users/darryl.porter/projects/marketplace/CLAUDE.md:69` | AC#12
collateral | D33 names one stale fact on root `CLAUDE.md:69` ("an 11-lens code audit") but that
single line carries **two**: the same bullet opens `- **edm** (v3.2.2)`, which AC12's own bump to
`3.3.0` has just made stale. Unlike the lens count, this staleness was *created by this ticket*
rather than inherited, so the "left unswept pending a ticket that names it" rationale does not
cover it -- no reader of D33 would know to look for it. This fails no AC (root `CLAUDE.md` is
outside every Target Components list and AC12's three conjuncts all hold), so `EDMV4-T33`'s
verdict stands at PASS.

---

## Remediation Required

1. **[P1] `EDMV4-T29` AC12 -- record the closure-grep result.** Add an `EDMV4-T29` row to
   `SRD/edm/EDMV4__ecc-integration/decisions.md` stating the two heading strings swept
   (`## The 11 Audit Lenses`, `## What Single-Pass Audits Miss (Why 11 Lenses)`), the scope
   (`plugins/edm/`), and the result (zero by-name references outside each heading's own
   definition site, so no cross-file reference needed updating). The grep itself is already
   correct -- only the record is missing. One row closes this and moves `EDMV4-T29` to PASS.

2. **[P2] `EDMV4-T33` -- extend D33 to the version string.** Amend the D33 row to name
   `(v3.2.2)` on root `CLAUDE.md:69` alongside the lens count, since the `3.3.0` bump created it,
   and fold both into whatever follow-on ticket claims root `CLAUDE.md`. Root `CLAUDE.md:69` is
   the only stale-version site in the repo outside `SRD/` and `CHANGELOG.md`.

3. **[P2] `EDMV4-T27` AC2/AC9 tension -- resolve or record.** Either reword step 4 at
   `agents/edm-audit-behavioral-tests.md:31` away from ECC's exact phrasing (and re-key
   `wave8-smoke.sh:989-990`'s substring to match), or record in `decisions.md` that the seven-word
   overlap is deliberate, prescribed by AC2, and de-minimis against the MIT provenance posture in
   D13. Recording is the cheaper option and preserves the shipped assertion.

**No PARTIAL verdicts.** Nothing from this shard is carried to `/edm:verify-runtime`.

## Out-of-scope observations (not defects of these four tickets)

- `wave8-smoke.sh` shows one failing assertion in my run (`EDMV4-T17 AC2`, a wave-1 ticket);
  the coordinator reports it as `EDMV4-T39 AC3` post-merge. Either way it is outside this shard.
  **All 58 `EDMV4-T25`/`EDMV4-T27` assertions pass.**
- `wave7-smoke.sh`'s `LENS_AGENTS` (`:1589`), `lens_files` (`:1905`), `T46_LENSES` (`:4755`) and
  `T48_CONTESTED_AGENTS` (`:5405`) still enumerate 11 lenses / 15 contested agents, so
  `plugins/edm/CLAUDE.md:493`'s 14/18 row has no matching machine counterpart yet. Red by design,
  owned by `EDMV4-T30`; `EDMV4-T33`'s Out of Scope excludes every smoke assertion.
- `agents/edm-audit-type-design.md` (L13) does not exist yet -- `EDMV4-T26`. Two of the three new
  lens files are present, not three.

<!-- QC-SHARD-COMPLETE range=EDMV4-T25..EDMV4-T33 assigned=4 audited=4 -->
