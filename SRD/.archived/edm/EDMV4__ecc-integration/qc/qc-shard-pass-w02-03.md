# QC Audit Report: Classifier and Scorecard [Shard 3/4, wave 2]

**Date**: 2026-09-02
**Tickets audited**: EDMV4-T35 through EDMV4-T37
**Epic**: `tickets/epics/05-classifier-and-scorecard.md`
**Implementation mode**: `standard` (TDD compliance pass does not run)

## Summary

| Ticket | Title | Verdict |
|---|---|---|
| EDMV4-T35 | Pin the classifier to the eight existing mode enum values | PARTIAL |
| EDMV4-T36 | Implement the security-trigger tie-breaker and pre-select the compliance dialog | PARTIAL |
| EDMV4-T37 | Enforce guard D6 so the classifier never restates the mode matrix | PARTIAL |

No FAIL findings. Every PARTIAL is a single AC clause; all other ACs verified statically against
the tree.

## Gate checks demanded by the shard brief

| Check | Result | Evidence |
|---|---|---|
| `bin/edm-check-skill-sync` | **exit 0** | `CLEAN (dispatcher holds no phase procedure; every phase skill owns its own; no skill blocks Skill-tool dispatch)` |
| `bin/edm-check-grants` | **exit 0** | Warnings only, all pre-existing `grant-without-instruction` on unrelated agents. By-name anchoring holds: the skill cites the suffixed form `CLAUDE.md Sec."EDM mode matrix (EDMV3-T38)"` at `skills/orchestrator/SKILL.md:118,123,140`, matching the generated heading -- the bare-`Sec."EDM mode matrix"` regression is not reintroduced |
| `bin/edm-check-vocabulary` | exit 0 (bonus) | `CLEAN` |
| `bin/tests/wave8-smoke.sh` | **382 passed, 0 failed** | Run twice during this audit (344/0, then 382/0 -- sibling shards are appending to this file concurrently; it grew 128KB -> 145KB mid-audit). Both runs exit 0. My range: **46 PASS, 0 FAIL** (T35 18, T36 17, T37 11) |
| `run-all.sh` | not run (per brief) | See the three AC8 PARTIALs |

Out-of-range observation, recorded so it is not lost: a *concurrent* wave8 run (not mine) transiently reported `FAIL: EDMV4-T17 AC2 -- exit codes diverged with library removed`. Neither of my own two runs reproduced it, and `EDMV4-T17` is outside this shard's range. The assertion deletes `_edm-datadir-lib.sh` and compares `edm-state` exit codes, so it is inherently hostile to concurrent suite runs against the same tree. Flagging for T17's owner as a possible test-isolation defect, not as a finding against T35/T36/T37.

### Self-matching scan class -- checked, NOT present

The brief flagged this shape as having bitten five times. It does not occur here:

- `T37_D6_PHRASES` (`wave8-smoke.sh:1438`) is only ever grepped against a block extracted from
  `$ORCH_SKILL` (`:1446-1448`), never against the suite file that defines it.
- `check_absent` (`_harness.sh:37-44`) searches only its third argument (`actual`), never its
  label, so the `rules/common/security.md` check at `:1384-1385` cannot self-match on its own
  label text.
- The positive control genuinely discriminates (reproduced independently, see T37 AC5).
- The empty-extract case fails rather than passing vacuously (`return 2` at `:1447`, taken by the
  `else` branch at `:1456`) -- reproduced with a fixture containing no Step 1b.5.

### One-commit disclosure -- verified separable

All three tickets landed in `ffd4c51`. Each ticket's work is present and attributable:

- **T35**: `wave8-smoke.sh:1237-1360` only. Correctly no source change -- the ticket's purpose is a
  non-modification backstop.
- **T36**: `skills/orchestrator/SKILL.md:121` (tie-breaker paragraph), the `or naming the trigger
  that fired` clause at `:123`, `(mode, lifecycle_mode, and compliance)` at `:125`, and `:136`
  (compliance bullet); plus `wave8-smoke.sh:1362-1428`.
- **T37**: the single sentence appended to `:123` (`Per guard D6, this step names values only ...`);
  plus `wave8-smoke.sh:1430-1513`.

Process deviation only; no defect. The `git show ffd4c51` diff reads cleanly per ticket.

## Detailed Findings

### EDMV4-T35: Pin the classifier to the eight existing mode enum values -- PARTIAL

- [x] **AC1** (static) -- `bin/edm-state:865-866` hold `MODE_ENUM_LIST` (5) + `LIFECYCLE_MODE_ENUM_LIST`
      (3) = 8. The classifier's emitted set is `{standard, mini-srd, fix-pack}` (derived from the
      three pairs at `skills/orchestrator/SKILL.md:112-114`); all three are members. Asserted at
      `wave8-smoke.sh:1259-1276`.
- [x] **AC2** (static) -- `git diff <base>..HEAD -- plugins/edm/bin/edm-state | grep 'ENUM_LIST='`
      returns nothing across the whole initiative (base `5e26963`). Both literals pinned at
      `wave8-smoke.sh:1250-1255`.
- [x] **AC3** (static) -- Two-axis table at `skills/orchestrator/SKILL.md:110-114`, one row per tier,
      both members named. Row-count-is-3 assertion at `wave8-smoke.sh:1280-1285`; the three literal
      pairs are pinned verbatim in the same suite run at `:145-150`, so "and no others" is covered.
- [x] **AC4** (static) -- Arm counts compared against the initiative base, not just a hardcoded
      baseline: `terminal_phase_for_mode` 8->8, `code_audit_required_for_mode` 3->3,
      `convergence_exempt` 2->2. Asserted at `wave8-smoke.sh:1289-1313`.
- [x] **AC5** (static/executed) -- All four calls with correct `kind` exit 0
      (`wave8-smoke.sh:1326-1344`), confirmed green in my run.
- [x] **AC6** (static/executed) -- Reproduced independently in a scratch repo:
      `set-mode T35Q mode trivial` exits **1** with
      `edm-state: set-mode: invalid mode 'trivial' (expected: standard|mini-srd|iac|data-ml|prototype)`.
      The AC's own wording is "exits non-zero" plus the message substring, and both hold. Asserted at
      `wave8-smoke.sh:1346-1347` via `check_fails`, which enforces non-zero exit **and** message
      containment (`_harness.sh:168-180`).
      **Implementer disclosure confirmed**: `die()` at `bin/edm-state:133` is
      `local msg="$1" code="${2:-1}"`, and both refusal sites (`:5286`, `:5308`) are
      single-argument, so both exit **1**. The ticket's Technical Note ("Both refusals go through
      `die`, which exits 2", epic `:215`) is the wrong text; the implementer wrote the AC against
      verified behaviour and was correct to do so.
- [x] **AC7** (static/executed) -- Reproduced: `set-mode T35Q lifecycle_mode mini-srd` exits 1 with
      `edm-state: set-mode: invalid lifecycle_mode 'mini-srd' ...`. Both wrong-kind cases asserted at
      `wave8-smoke.sh:1349-1352`.
- [~] **AC8** -- Split verdict.
  - Clause (a) "assertions live in a suite `run-all.sh` discovers" -- **PASS** (static).
    `run-all.sh:45` discovers via `find "$_SUITE_DIR" -maxdepth 1 -name '*-smoke.sh' -type f`, and
    `:32` states `_PREFERRED_ORDER` "never gates which suites run". `wave8-smoke.sh` matches the
    glob and is invoked as `bash "$suite"` (`:114`), so its missing executable bit is immaterial.
  - Clause (b) "`bash plugins/edm/bin/tests/run-all.sh` passes" -- **PARTIAL**. Requires executing
    the aggregate suite, which this shard was instructed not to run, and which is currently red for
    reasons owned by `EDMV4-T30` in wave 3 (`wave6-smoke.sh` T27 AC1, all of `wave7-smoke.sh`).
    These tickets' own suite is green (344/0).

**Finding**: [PARTIAL] EDMV4-T35 | AC#8: `bash plugins/edm/bin/tests/run-all.sh` passes | runtime-check: after `EDMV4-T30`'s lens-count assertions land in wave 3, run `bash plugins/edm/bin/tests/run-all.sh` and confirm exit 0 with `wave8-smoke.sh` reported green in the per-suite table.

**Finding**: [P2] EDMV4-T35 | SRD/edm/EDMV4__ecc-integration/tickets/epics/05-classifier-and-scorecard.md:215 | AC#6/AC#7 Technical Note: "Both refusals go through `die`, which exits 2" | Factually wrong -- `bin/edm-state:133` defaults `code` to 1 and both call sites (`:5286`, `:5308`) are single-argument, so both exit 1. Verified empirically. The ACs themselves say "exits non-zero" and are unaffected; the ticket's Technical Note is the text needing correction.

### EDMV4-T36: Security-trigger tie-breaker and compliance pre-selection -- PARTIAL

- [x] **AC1** (static) -- `skills/orchestrator/SKILL.md:121`, inside Step 1b.5's block (102-126):
      trigger hit "or on a public API or contract change, forces the recommendation to **at least**
      `standard`, overriding a lower tier from the three signals above". Asserted at
      `wave8-smoke.sh:1373-1376`.
- [x] **AC2** (static) -- Exactly seven, verbatim and in the AC's stated order, at `:121`:
      authentication or authorization / user-input handling / database queries / filesystem paths /
      external API calls / cryptography / secrets or credentials. Counted independently: 7, no
      additions, no omissions. Asserted at `wave8-smoke.sh:1378-1380`.
- [x] **AC3** (static) -- `` (source: ECC's `orch-pipeline/SKILL.md`) `` at `:121`;
      `grep -c "rules/common/security.md" skills/orchestrator/SKILL.md` returns **0**. Asserted at
      `wave8-smoke.sh:1382-1385`.
- [x] **AC4** (static) -- `:121` "it also pre-selects **On** for Step 1c's compliance toggle, moving
      "(Recommended)" from Off to On for this run"; mirrored in the dialog itself at `:136`. Asserted
      at `wave8-smoke.sh:1387-1390`.
- [x] **AC5** (static) -- `:123` "which signal scored what tier, **or naming the trigger that
      fired**". Asserted at `wave8-smoke.sh:1392-1393`.
- [x] **AC6** (static) -- Diffed against the initiative base: the base read
      `**Off** (Recommended) /\n   **On**.` at `:109-110`; HEAD `:136` preserves that literal option
      text and appends "when it does not fire, this default is unchanged". The item renumber 2->3 is
      forced by `EDMV4-T34` AC6's inserted Lifecycle question, not a change to the default. Asserted
      at `wave8-smoke.sh:1403-1408`.
- [x] **AC7** (static) -- `:136` "The user may still choose Off, and either way the choice is
      recorded only through step 4's existing `set-mode <PREFIX> compliance_enabled true` write
      (only if On) -- no new write path." `compliance_enabled false` absent from the whole skill.
      Asserted at `wave8-smoke.sh:1411-1416`.
- [~] **AC8** -- Split verdict.
  - Clause "the test is registered in a suite `run-all.sh` discovers" -- **PASS** (static, same
    evidence as T35 AC8(a)).
  - Clause "a smoke test asserts a trigger hit produces at least `standard`: given a scenario where
    all three signals score trivial and one trigger is present, the recommended pair is
    `(standard, standard)` and not `(standard, fix-pack)`" -- **PARTIAL**.

#### Adjudication of T36 AC8 (the disclosed unverifiable AC)

**Verdict: PARTIAL. Not a D15 specification defect; no gate change control required.**

The implementer was right not to claim PASS, and right to disclose inline
(`wave8-smoke.sh:1418-1426`) rather than silently emit a green line. My independent reading:

1. **The AC is runtime-only, not statically verifiable.** Its verb is "asserts ... the recommended
   pair **is**" -- an observable output. Step 1b.5 is prose interpreted by an LLM at dispatch time;
   there is no classifier binary a bash suite can drive with three trivial signals and a trigger
   flag. So the behaviour cannot be observed by reading the tree.
2. **It is not a D15 case.** `CLAUDE.md Sec."Unverifiable acceptance criteria (D15)"` binds only
   when the runtime environment "genuinely does not exist in the project". It does exist here:
   `evals/run-eval.sh` drives `claude -p` against EDM phases under a per-phase timeout and budget,
   and `/edm:verify-runtime` is the sanctioned closer for exactly this class. A scripted
   trivial-signals-plus-auth-trigger scenario is a real, meaningful, in-project check. Neither
   sanctioned D15 response (rework the AC, or move the clause out of scope) is warranted -- the AC
   is closeable as written.
3. **The documentation proxy is valuable but is not the AC.** `T36_AC8_EXPECTED`
   (`wave8-smoke.sh:1395-1397`) pins the exact scenario in the skill text -- "even when all three
   signals score trivial, a trigger hit overrides the trivial tier's `(standard, fix-pack)`
   recommendation with `(standard, standard)`". That is the necessary precondition for the runtime
   behaviour and is a genuinely stronger assertion than a bare "at least standard" grep. But it
   verifies the *specification*, not the *behaviour* AC8 names.
4. **The one real defect is the green line.** `wave8-smoke.sh:1426` emits an unconditional `pass`
   for AC8 with no assertion behind it. It can never fail, and to anyone scanning `344 passed,
   0 failed` it reads as though the scenario were tested.

**Finding**: [PARTIAL] EDMV4-T36 | AC#8: a trigger hit given three trivial signals recommends `(standard, standard)`, not `(standard, fix-pack)` | runtime-check: dispatch `/edm:orchestrator` (or an `evals/run-eval.sh` fixture) with an initiative description scoring trivial on all three signals -- a two-file change -- that touches an authentication path, and assert the Step 1c dialog carries "(Recommended)" on `mode=Standard` **and** `lifecycle_mode=Standard` (not `fix-pack`), with the one-line reasoning naming "authentication or authorization" and the Compliance toggle pre-selected On.

**Finding**: [PARTIAL] EDMV4-T36 | AC#8: (registration clause verified statically; behaviour clause above)

**Finding**: [P2] EDMV4-T36 | plugins/edm/bin/tests/wave8-smoke.sh:1426 | AC#8: unconditional `pass` with no assertion behind it | Renders a runtime-unverified AC as green in suite output and inflates the pass count with a non-assertion. Same shape at `:1358` (T35 AC8) and `:1511` (T37 AC8). Prefer a `skip`/`note` emitter distinct from `pass`, so the suite's pass count only counts things that can fail.

**Finding**: [P2] EDMV4-T36 | plugins/edm/skills/orchestrator/SKILL.md:121 | House style (guard D3, prompt-conventions) | The tie-breaker paragraph is one unwrapped 814-character line in a file whose surrounding prose wraps at ~90-105 columns; `:123` (423 chars) and `:125` (435) are the same shape. Consequence worth naming: Step 1b.5 measures **24 raw lines but 41 lines wrapped at 100 columns**, so `EDMV4-T34` AC12's "under 30 lines" currently holds by wrapping style rather than by prose volume. `EDMV4-T34` is outside this shard's range; recorded here because T36's paragraph is the dominant contributor.

### EDMV4-T37: Enforce guard D6 so the classifier never restates the mode matrix -- PARTIAL

- [x] **AC1** (static) -- Read all of Step 1b.5 (`skills/orchestrator/SKILL.md:103-126`): nothing
      states what any `mode` or `lifecycle_mode` value *does*. The block names values (the table at
      `:110-114`), states classifier properties, and cites
      `CLAUDE.md Sec."EDM mode matrix (EDMV3-T38)"` at `:118` and `:123` -- the same by-name pattern
      Step 1c uses at `:140`. Asserted at `wave8-smoke.sh:1454-1460`.
      (Advisory-drift note, not a defect: the ticket cites the exemplar as "Step 1c.4 at `:113-114`";
      post-`EDMV4-T34` renumbering makes it Step 1c item **5** at `:140-145`. The epic's own banner
      at `:15-23` declares line numbers advisory and directs anchoring by symbol/literal.)
- [x] **AC2** (static) -- `:123` "naming both members of the pair and which signal scored what tier,
      or naming the trigger that fired -- never the destination's behaviour". Asserted at
      `wave8-smoke.sh:1463-1466`.
- [x] **AC3** (static) -- `t37_d6_scoped_check` (`wave8-smoke.sh:1444-1450`) extracts via
      `_t34_extract_between` delimited by `^\*\*Step 1b\.5` and `^\*\*Step 1c` -- the actual bold-line
      heading form Step 1c uses, per the Technical Note -- asserts the extract is non-empty
      (`return 2`, which the caller's `else` branch turns into a FAIL, verified with a
      no-Step-1b.5 fixture), then greps for exactly the three required phrases (`:1438`). "At
      minimum" satisfied.
- [x] **AC4** (static) -- **Substance verified; the implementer's scoping is correct and hides
      nothing.** The three phrases really do exist elsewhere in the tree, so a tree-wide grep would
      fail on correct code: `plugins/edm/CLAUDE.md:1315` (`fuse into one audited file`) and `:1323`
      (`Tickets generated directly from`, `Phases 1, 2, 3, 5 recorded`), plus the generated mirror at
      `plugins/edm/docs/canonical-sections.md:241,249`. The block-scoped check passes on the
      unmodified tree. `wave8-smoke.sh:1469-1476` asserts both halves together, so the test is
      non-vacuous: it fails if the fixture phrases ever leave `CLAUDE.md`.
      I checked the two files the AC names for a concealed restatement and found none -- they carry
      paraphrases, not the literals: `skills/tickets/SKILL.md:146` reads "tickets are generated
      directly from an analysis document" (lowercase `t`, so outside the phrase), and
      `skills/srd/SKILL.md:128` reads "folds Phases 2-5 into one audited document" (not "fuse into
      one audited file"). That is the mode matrix's "owning phase skill" design working as intended.
- [x] **AC5** (static/executed) -- **Reproduced independently, not taken from the suite's own
      output.** The injection at `wave8-smoke.sh:1481-1487` lands at line 105, inside Step 1b.5
      (102-126): the `!inserted` guard makes it take the **first** of the two byte-identical
      "Skipped on resume ..." lines rather than Step 1c's at `:129`. The poisoned copy's block-scoped
      grep matches (control fires); the unmodified tree's does not (control discriminates). Both
      directions asserted at `:1489-1498`.
- [x] **AC6** (static) -- Diffed against the initiative base `5e26963`: the
      `## EDM mode matrix (EDMV3-T38)` section is byte-identical
      (md5 `4ba9dfb297c2167f7d3385d7f7ef59fd` on both sides), and the D6 guard text is byte-identical
      (base `CLAUDE.md:549-552`, HEAD `:595-598`; only the line offset moved).
- [x] **AC7** (static) -- `:123` "Per guard D6, this step names values only and never restates any
      mode's or lifecycle_mode's behaviour." One line, in Step 1b.5's own text, naming D6. Asserted
      at `wave8-smoke.sh:1507-1508`.
- [~] **AC8** -- Split verdict, identical in shape to T35 AC8: clause (a) registration **PASS**,
      clause (b) `run-all.sh` passes **PARTIAL**.

**Finding**: [PARTIAL] EDMV4-T37 | AC#8: `bash plugins/edm/bin/tests/run-all.sh` passes | runtime-check: after `EDMV4-T30`'s lens-count assertions land in wave 3, run `bash plugins/edm/bin/tests/run-all.sh` and confirm exit 0 with `wave8-smoke.sh` reported green.

**Finding**: [P2] EDMV4-T37 | SRD/edm/EDMV4__ecc-integration/tickets/epics/05-classifier-and-scorecard.md:355-356 | AC#4: "those phrases exist in `skills/tickets/SKILL.md` and `skills/srd/SKILL.md`" | The AC's factual premise names the wrong files. Verified: the literal phrases live in `plugins/edm/CLAUDE.md:1315,1323` and `plugins/edm/docs/canonical-sections.md:241,249`; the two named skills carry paraphrases only. The AC's behavioural substance (block-scoped, passes on the unmodified tree despite tree-wide hits) is fully satisfied, and the implementer's substitution at `wave8-smoke.sh:1472-1476` is correct. Correct the AC's premise to name `CLAUDE.md` / `docs/canonical-sections.md`.

**Finding**: [P2] EDMV4-T37 | plugins/edm/bin/tests/wave8-smoke.sh:1501-1504 | AC#6: "byte-unmodified" | The assertions are presence-checks for a heading string and one D6 sentence, not byte-comparisons. They would not catch an edit to the matrix table body that left both intact. The AC itself is a claim about the tree and is satisfied (verified by md5 against the initiative base), so this is assertion strength, not an AC failure. Consider pinning the section's checksum, as `edm-sync-canonical-sections --check` already does for the generated mirror.

**Finding**: [NOTED] EDMV4-T37 | plugins/edm/skills/orchestrator/SKILL.md:116-119 | AC#1 | "the two are documented as behaviourally identical" is the closest thing in Step 1b.5 to a matrix restatement, and it is a latent drift surface if the `fast-track`/`fix-pack` row is ever split. It is not a D6 violation: it states an equivalence and cites the matrix, never saying what either value does -- a reader of Step 1b.5 alone still must consult the matrix. `EDMV4-T34` AC4 mandates this sentence verbatim, so it is intentional, not an oversight. Recorded so a future editor who splits that row knows this line goes stale.

## Remediation Required

No FAIL findings -- nothing blocks. Ordered P2 remediation:

1. **[P2] `wave8-smoke.sh:1426`, `:1358`, `:1511`** -- replace the three unconditional `pass` calls
   with a distinct non-counting emitter (e.g. `note`), so the suite's pass count only counts
   assertions that can fail. `:1426` is the material one: it renders a runtime-unverified AC green.
2. **[P2] epic `05-classifier-and-scorecard.md:355-356` (T37 AC4)** -- correct the premise to name
   `plugins/edm/CLAUDE.md` and `plugins/edm/docs/canonical-sections.md`. The current text sends the
   next reader to two files that do not contain the phrases.
3. **[P2] epic `05-classifier-and-scorecard.md:215` (T35 Technical Note)** -- change "which exits 2"
   to "which exits 1 by default (`bin/edm-state:133`); both `set-mode` refusal sites are
   single-argument".
4. **[P2] `skills/orchestrator/SKILL.md:121,123,125`** -- rewrap to the file's ~100-column house
   width. This will take Step 1b.5 to ~41 lines, which surfaces a real tension with `EDMV4-T34`
   AC12's "under 30 lines"; route that to `EDMV4-T34`'s owner rather than resolving it by leaving
   the lines unwrapped.
5. **[P2] `wave8-smoke.sh:1501-1504` (T37 AC6)** -- strengthen to a checksum comparison of the mode
   matrix section body.

PARTIAL findings are not remediated here. The three of them close via the mandatory
`/edm:verify-runtime` step before archive:

| Ticket | AC | Closes when |
|---|---|---|
| EDMV4-T35 | AC8(b) | `run-all.sh` green after `EDMV4-T30` lands (wave 3) |
| EDMV4-T36 | AC8(behaviour) | Scenario dispatch confirms `(standard, standard)` + named trigger + Compliance On |
| EDMV4-T37 | AC8(b) | `run-all.sh` green after `EDMV4-T30` lands (wave 3) |

<!-- QC-SHARD-COMPLETE range=EDMV4-T35..EDMV4-T37 assigned=3 audited=3 -->
