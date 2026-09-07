# QC Audit Report: EDMV4 (ECC Integration) -- Wave 3, Shard 2/2

**Date**: 2026-09-03
**Tickets audited**: EDMV4-T30, EDMV4-T31, EDMV4-T41, EDMV4-T44, EDMV4-T47
**Audit target**: merged branch tip `edm/edmv4-ecc-integration` @ `0d099e9` (main working tree)

## Summary

| Ticket | Title | Verdict |
|---|---|---|
| EDMV4-T30 | Rewrite the smoke-suite lens-count assertions | FAIL |
| EDMV4-T31 | Re-inventory the lens-count sites and honour the do-not-touch list | FAIL |
| EDMV4-T41 | Feed the readiness score into the classifier and into planning.md | PASS |
| EDMV4-T44 | Make `action: block` explicit opt-in behind a two-tier exit contract | FAIL |
| EDMV4-T47 | Block only on the unambiguous subset, read from the existing class field | PASS |

Independent suite evidence gathered for this shard (`bash plugins/edm/bin/tests/wave7-smoke.sh`,
run on the merged tip): every lens-count assertion T30 retargeted fails by **exactly one lens**
(`13/14`, `14/15`, `32/33`) and by nothing else. That is conclusive evidence the retargeting itself
is arithmetically correct and that the redness is entirely `EDMV4-T26`'s unlanded L13 agent file --
no T30-retargeted assertion fails for a T30-caused reason.

## Detailed Findings

### EDMV4-T30: Rewrite the smoke-suite lens-count assertions -- FAIL

Twelve ACs. Ten verified; two FAIL. The bulk of this ticket is correct and careful work -- the
highest-risk item the shard brief named (`T48_CONTESTED_AGENTS`) was genuinely converted, and the
five `set -e` guards are genuine guard additions with no assertion deleted or neutered. The two
failures are a **newly introduced vacuity pair**: two assertions that were real tripwires before
this ticket and are now `X == X` self-comparisons that no input can fail.

- [x] **AC1** -- T47 AC6's anti-regression test is deliberately revised, not incremented.
      `wave7-smoke.sh:4958-4962` now checks the literal `run all 14`, its banner reads "fourteen is
      the invariant now protected", and a three-line comment records it as a deliberate revision.
      Target string verified present at `skills/code-audit/SKILL.md:51` -- the assertion is live,
      not vacuous.
- [x] **AC2** -- T48 AC6 likewise: `wave7-smoke.sh:5483-5489`, banner "fourteen lenses, none merged
      or removed", `die`/fail message says 14, revision recorded in a comment.
- [x] **AC3** -- All exact-integer lens sites retargeted. Verified by re-running the sweep on the
      merged tip: `grep -n -- "-eq 11\|== 11\|-eq 12\|-eq 13\|-eq 15"` across
      `wave6/wave7/wave8-smoke.sh` returns **zero code hits** (4 hits, all inside comments that
      describe the sweep itself). A tenth site not in the ticket's nine (`VERIF-T09 AC3`,
      `wave7-smoke.sh:9582`) was found by T31's re-inventory and swept here -- but see the AC3
      finding below for how it was swept.
- [x] **AC4** -- All four hardcoded lens-NAME lists extended, including the site called out as most
      dangerous. `LENS_AGENTS` 11->14 (`:1610`); `lens_files` 11->14 (`:1938`); `T46_LENSES` 11->14
      (`:4785`); `T48_CONTESTED_AGENTS` 15->18 (`:5448`), and the three new lenses
      (`edm-audit-behavioral-tests`, `edm-audit-silent-failures`, `edm-audit-type-design`) are
      genuinely present in the D16 opus/max list -- the silent-drop failure mode the ticket named is
      closed.
- [ ] **AC5** -- **FAIL.** Non-`-eq 11` offset counts: `:1688` (`-eq 12` -> 15) and `:4749`
      (`-eq 13` -> 16) are correct and remain non-vacuous. `:5402` (`-eq 15` -> `-eq 18`) is
      **not** what shipped: `wave7-smoke.sh:5468` compares `t48_contested_count` against
      `T48_CONTESTED_TOTAL`, and both are the member count of the same `T48_CONTESTED_AGENTS`
      string. See the AC5 finding.
- [x] **AC6** -- `wave7-smoke.sh:1789` reads `for t24_n in 1 2 3 4 5 6 7 8 9 10 11 12 13 14`.
- [x] **AC7** -- The CA-529 "twelve" banners now read fifteen at `:1618`, `:1622`, `:1626`, `:1630`
      (comment, comment, `echo` banner, `pass` message). No "twelve" survives in that block.
- [x] **AC8** -- Both False Alarm Filter machine assertions named and retargeted: T25 AC8 at
      `:1938-1950` and T46 AC2 at `:4795-4801`. Neither was missed.
- [x] **AC9** -- Message text swept with the assertions. Spot-checked every retargeted `pass`/`fail`
      pair; none prints "eleven" while asserting 14. Two stale *narrative* strings survive outside
      the assertion set (`:480` comment, `:1491` `echo`) -- reported under T31 AC9, which owns the
      closure sweep.
- [x] **AC10** -- File-on-disk counts converted to a computed constant defined once:
      `WAVE7_LENS_COUNT` at `:1616`, derived from `LENS_AGENTS`, consumed at 11 sites. Both
      disk-counting lens assertions (T24 AC0 fixtures `:1654`/`:1657`, T48 AC6 `:5488`) use it, and
      those comparisons are real (disk count vs. list count).
- [x] **AC11** -- `wave6-smoke.sh:3595-3620`. An explicit all-14 `--lenses` invocation asserts
      `round_type == "full"`; the two new N/A-composition cases are present (13 IDs + `--na-lenses
      L13` -> `full`; the same 13 IDs without the declaration -> `partial`); the 3-of-N partial case
      survives with its message corrected to "3-of-14". The original 11-listing was retained with
      its expectation corrected `full` -> `partial` rather than deleted -- extra coverage, and
      correct at 14 lenses.
- [ ] **AC12** -- **FAIL.** `run-all.sh` does not pass with zero failures on the merged tip. Cause
      is external to this ticket (see finding). The second clause -- "lands before any other
      ticket's changes touch `wave7-smoke.sh`" -- holds: the only subsequent commit to that file is
      `9a4a7f0` (`EDMV4-T18`), which landed after `b526181`.

**Findings**

```
[P1] EDMV4-T30 | plugins/edm/bin/tests/wave7-smoke.sh:5468 | AC#5: `:5402` (`-eq 15`) becomes `-eq 18` -- shipped as `-eq "$T48_CONTESTED_TOTAL"`, a tautology
```
`t48_contested_count` is incremented once per member of `$T48_CONTESTED_AGENTS` (`:5455-5456`);
`T48_CONTESTED_TOTAL` is `printf '%s\n' $T48_CONTESTED_AGENTS | grep -c '.'` (`:5452`). Both
expressions word-split the same string, so the comparison is `X == X` and **no input can make it
fail**. The pre-existing `-eq 15` was vacuous with respect to the *tree* (which is why AC4 flagged
this site) but was a real tripwire against the *list*: dropping a name made it 14 != 15 and failed.
That tripwire is now gone, and nothing else in the suite cross-checks this list -- `grep -n
"T48_CONTESTED"` returns six lines, all inside this one block, and the only other consumer
(`-z "$t48_bad"`, `:5470`) iterates the same list, so a silently dropped lens is invisible again.
This is the exact failure mode AC4 exists to prevent, reintroduced one layer up.
**Fix**: restore the literal at `:5468` -- `[[ "$t48_contested_count" -eq 18 ]]`. AC10's
computed-constant rule is explicitly scoped to "where an assertion counts files on disk"; this one
counts list members.

```
[P1] EDMV4-T30 | plugins/edm/bin/tests/wave7-smoke.sh:9582 | AC#3: VERIF-T09 AC3's `-eq 11` retargeted into a tautology
```
`verif_t09_lens_name_count` (`:9581`) and `WAVE7_LENS_COUNT` (`:1616`) are byte-identical
expressions over the same variable. The assertion cannot fail. Its own surviving comment
(`:9578-9580`) still claims "a future edit that adds a fifteenth real lens must update that shared
variable consciously rather than this ticket's count silently drifting out of sync with it" -- that
rationale is now false, since there is no second number to drift. Mitigating: a shrinkage of
`LENS_AGENTS` would still be caught at `:5488` (disk count vs. list count), so the safety loss is
smaller here than at `:5468`. **Fix**: `[[ "$verif_t09_lens_name_count" -eq 14 ]]`, or delete the
assertion and its comment as superseded by `:5488` -- but not leave it as a self-comparison that
reads like a check.

```
[P2] EDMV4-T30 | AC#12: `run-all.sh` passes with zero failures -- wave7-smoke.sh is red
```
Verified by direct run on the merged tip. **Every** lens-count failure is off by exactly one:
`T24 AC1/AC2/AC4/AC5/AC6` report `13/14`, `CA-467` reports `14/15`, `T03 AC9`/`T66 AC6` report
`32` vs `33`. All are `EDMV4-T26`'s unlanded L13 agent file, which is outside this ticket's scope
and which the implementer recorded honestly in the commit message. Recorded as FAIL because the AC
as written is a green-suite gate and the suite is not green; **the remediation is landing
`EDMV4-T26`, not editing anything T30 wrote.** This AC cannot close until T26 lands and the ~35
`EDMV4-T18`-stale assertions (group (b), currently owned by no ticket) get an owner.

```
[P2] EDMV4-T30 | plugins/edm/bin/tests/wave7-smoke.sh | A `set -e` abort deeper in the file still truncates the suite
```
My run produced 15 FAIL lines and **no `Results:` line** -- the suite aborted before completion.
T30's own commit message reports finding this ("a further pre-existing abort deeper in the file,
near the Wave-4b mechanical-fixes block") and correctly scoping it out. Recorded here so it has a
written home: this is the tenth instance of the class, and a truncated suite is the failure mode
that hid ~500 assertions earlier in this initiative. Not a T30 defect; needs an owning ticket.

**Verified not weakened** (the shard brief's specific concerns):
- The five `set -e` guards are genuine. `ca533_pattern_file_arms`/`ca533_report_path_arms`
  (`:1156-1157`) wrap `grep -c` in `{ ...; || true; }`, preserving the `0` output so the
  count comparison still fails on a real zero-arm regression. `_ca467_extract` (`:1706-1712`) and
  the two T24 `awk` loop bodies (`:1740`, `:1777`) convert a missing-file abort into a
  correctly-labelled FAIL -- verified by the run above, where CA-467 and T24 AC1/2/4/5/6 each
  report a precise `n/N` shortfall instead of killing the run. No assertion was deleted: the diff
  removes 40 assertion lines and adds 46.
- The do-not-touch elevens survived untouched: `CLAUDE.md:307` and `docs/canonical-sections.md:88`
  (Mermaid touch points), `CLAUDE.md:578` (D1) and `:581` (D2), `bin/edm-state:4899` (historical
  incident), `:1229`/`:1232` (constant-11-column coverage table), `:842`/`:2730`/`:2761`
  (`EDMV3-T11` identifiers), `:4300` (`T61 AC11`), `bin/edm-check-grants:11`. Neither T30 nor T31
  touches `CHANGELOG.md` (`git show --stat` on both commits confirms).

---

### EDMV4-T31: Re-inventory the lens-count sites and honour the do-not-touch list -- FAIL

Eleven ACs. Nine verified; two FAIL. This ticket's entire value is the written record, and D39 in
`decisions.md` is a genuinely strong record -- it does exactly what `EDMV4-T29` AC12 failed to do
in wave 2, and it explicitly distinguishes "verified, not edited" from "never checked" for the
AC5-AC7 sites, per the D36 precedent. The two failures are both in the record's completeness, not
in the sweep's substance.

- [x] **AC1** -- Second pass run and reconciled. D39 records the discrepancy by name:
      `wave7-smoke.sh`'s `VERIF-T09 AC3` `-eq 11` site was missing from T30's nine-site list, landed
      after the pack was written, and was fixed inside T30's own commit per the serialization rule.
- [x] **AC2** -- Tree-wide count reconciled and the SRD's superseded figure recorded. D39 states the
      real exact-integer set is **eleven** (T30's nine + the VERIF-T09 tenth + `bin/edm-state`'s own
      self-check), not the ten the pack projected -- the discrepancy is recorded, not absorbed.
- [x] **AC3** -- Both structurally-invisible shapes covered, plus a **fourth** shape neither ticket's
      greps can find: three "30 agent files on disk" baselines (`T03 AC9`, `T66 AC6`, `T46 AC10`)
      that carry no eleven/twelve/thirteen/fifteen token because they count all agent files. Found
      by re-deriving what each assertion counts rather than trusting its label; grown 30->33.
      Independently confirmed at `wave7-smoke.sh:507`, `:1482`, `:4872`.
- [x] **AC4** -- Four `bin/edm-state` prose sites edited with a per-site decision recorded in D39.
      Three verified live: `:3792` (metrics-report legend, "all 14 lenses"), `:5096`
      ("fourteen-lens opus round"), `:5161` (unknown-round-type refusal, "(fourteen-lens)"). The
      fourth (the CA-478 comment) was correctly edited in `f75ebd8` and the whole comment block was
      subsequently deleted by the concurrent `EDMV4-T23` -- verified by diffing `f75ebd8..HEAD`.
      Not a T31 defect.
- [x] **AC5** -- Artifact-layout trees verified: `CLAUDE.md:121-122` and `README.md:204-205` both
      read `lens-L1.jsonl ... lens-L14.jsonl`. D39 records these as verified-not-edited, with the
      reason (concurrent `EDMV4-T29` work landed first). That distinction is exactly what AC11 and
      the D36 pattern require.
- [x] **AC6** -- `CLAUDE.md:493` reads "Contested audit set -- 14 code-audit lenses, ... (18
      agents)", agreeing with its machine counterparts at `wave7-smoke.sh:5448`/`:5468`.
- [x] **AC7** -- `CLAUDE.md:460-461` reads "all fourteen `agents/edm-audit-*.md` lens definitions,
      and all fourteen files `EDMV4-T04` anchored"; the enumerated list that follows does carry 14
      entries. Reconciled in one pass, not applied twice.
- [ ] **AC8** -- **FAIL** (minor). The list is correctly keyed by string with line numbers advisory,
      and adds four categories beyond the epic's six. But entry (f) records only D2's string; the AC
      names D1's string as part of the same required minimum entry. See finding.
- [ ] **AC9** -- **FAIL.** The closure grep does not return only members of the do-not-touch list.
      Four survivors at T31's own commit are unaccounted for. See finding.
- [x] **AC10** -- `docs/canonical-sections.md` was not hand-edited (`git show --stat f75ebd8` shows
      only `decisions.md` and `bin/edm-state`), and `edm-sync-canonical-sections --check` exits 0 --
      re-run by me on the merged tip: "docs/canonical-sections.md is in sync with CLAUDE.md".
- [x] **AC11** -- Recorded in `decisions.md` as Wave 2 / D39: sites found, sites added to T30,
      per-site AC4 decisions, and the full do-not-touch list. A later reader can tell the inventory
      was closed deliberately.

**Findings**

```
[P2] EDMV4-T31 | SRD/edm/EDMV4__ecc-integration/decisions.md:52 | AC#9: closure grep returns only do-not-touch members -- four survivors are unlisted
```
I re-ran D39's own grep against the tree **as it stood at `f75ebd8`** (so this is not merge drift):
`grep -rniE 'eleven|twelve|thirteen|fifteen|11[- ]lens|lens-L11|L1-L11|all 11|-eq (11|12|13|15)'
plugins/edm/`, excluding `bin/tests/fixtures/` and `CHANGELOG.md` exactly as D39 does. Four hits are
in no category (a)-(j):
- `bin/edm-lint-artifacts:146` -- "matching the two-file trap twelve lines below" (unrelated twelve;
  belongs on the list, same family as (i))
- `bin/tests/wave7-smoke.sh:20` -- "hand-copying the sentinel-extraction awk literal a thirteenth
  time" (unrelated thirteen; same family as (i))
- `bin/tests/wave7-smoke.sh:480` -- "CLAUDE.md documents the 11 `edm-audit-*` lenses collectively
  (\"all 11 `edm-audit-*` lenses\")" -- **a genuinely stale count**. The live code below it is
  dynamic (`grep -oE 'all [0-9]+ \`edm-audit-\*\`'`), so no assertion is wrong; the comment is.
- `bin/tests/wave7-smoke.sh:1491` -- `echo "  yet run -- all 11 lens agents remain opus/max on
  disk)..."` -- **a live operator-facing output string that is now false** (14 lens agents).
Separately, a large benign class is also unlisted: the current-correct 14/15 text T30 and T21/T22
wrote (`wave6-smoke.sh:3510`, `:3519`, `:3556-3557`, `:3564-3566`, `:3789-3796`, and T30's own
explanatory comments in `wave7-smoke.sh`). Those are not defects, but AC9's rule is "any survivor
outside the list is a defect", so D39's "zero survivors outside it" is overstated as written.
**Fix**: fix the two stale strings at `wave7-smoke.sh:480` and `:1491`; add `edm-lint-artifacts:146`
and `wave7-smoke.sh:20` to D39's category (i); add a category for "current-correct fourteen/fifteen
text written by this sweep" so the closure claim is literally true on re-run.

```
[P2] EDMV4-T31 | SRD/edm/EDMV4__ecc-integration/decisions.md:52 | AC#8: do-not-touch entry (f) records D2 only, not D1
```
AC8's required minimum entry (f) is "`CLAUDE.md`'s do-NOT-adopt guard **D1 and D2** text (\"the 11
code-audit lenses\", \"the 11-lens or 2-auditor fan-out\")". D39's (f) reads "`CLAUDE.md:581`'s
guard D2 text (\"the 11-lens or 2-auditor fan-out\")" and stops there. D1's string at
`CLAUDE.md:578` is absent from the record. No harm reached the tree -- D1 is verified untouched, and
its string is not matched by the AC9 closure grep in any case -- but the recorded list is short
against an explicitly enumerated minimum, and this ticket is the written record.
**Fix**: extend D39 entry (f) with `CLAUDE.md:578`'s "the 11 code-audit lenses" string.

**Merge-drift note (not a T31 defect)**: at the merged tip, four further closure-grep survivors
exist that did not exist at `f75ebd8` -- `wave6-smoke.sh:918`, `:946`, `:998`, `:4118`, all
`lens-L11.jsonl` scratch-fixture paths added by the concurrent `EDMV4-T23`. They are benign (an
arbitrary lens ID in a scratch path) but should be folded into D39's list whenever it is next
touched, or the closure claim will read false to the next auditor.

---

### EDMV4-T47: Block only on the unambiguous subset, read from the existing class field -- PASS

Eleven ACs, all verified. **The "no production change was needed" claim is independently
confirmed**, and I judge the ACs genuinely satisfied by tests alone. Reasoning below.

**The claim, verified independently.** `git log --all --format="%h %ai %s" --
plugins/edm/bin/edm-stop-gate` returns **exactly one commit**: `c6a4e82` (2026-09-02 16:27,
"wip(edm): EDMV4-T43/T46 incomplete -- hookify evaluator and stop-gate"). T47's own commit
`97b204a` (22:03) has a one-file stat: `bin/tests/wave8-smoke.sh`, +219/-0. So the file has not
been touched since `EDMV4-T46` delivered it, and T47 added no production code. I then read the
delivered mechanism rather than trusting the claim: `bin/edm-stop-gate:115-123` computes
`_class="${_aline%% *}"` and dispatches on a literal `blocking)` / `info)` case, and
`grep -nE 'OPEN_PARTIALS|OPEN_AUDIT_ROUND|SPEC_SWEEP_PENDING|PERM_RULES_MISSING|SIZE_UNKNOWN'`
over the whole file returns **zero hits** -- not merely zero hits in conditionals, zero hits
anywhere. The policy-free property T47 specifies is real in the delivered code.

**Judgment: are the ACs satisfied by tests alone?** Yes, and this is the right outcome rather than
a gap. T47's ACs are behavioural properties of `edm-stop-gate`, not construction instructions --
AC1 and AC3-AC11 all read "the gate does X", and its Out of Scope explicitly assigns "the gate
script's construction" to `EDMV4-T46`. A ticket whose specified mechanism already exists has two
honest options: re-implement it (churn, and a second encoding of one predicate -- the CA-409 class
this initiative has flagged repeatedly), or prove it. T47 proved it, and proved it against the real
binary in isolated scratch repositories rather than by reading the source. Three of its assertions
are of a kind T46's own ACs never demanded and that materially raise confidence: a positive control
on the AC4 grep, an *existence* assertion on each info-class fixture before the exit-0 assertion,
and a one-fixture two-state comparison. I would reach a different conclusion if the tests were
source-shape greps standing in for behaviour -- they are not; nine of the eleven ACs are exercised
by running the binary.

- [x] **AC1** -- `bin/edm-stop-gate:115-119` tests the first whitespace-delimited field against the
      literal `blocking`; `:139-140` makes `ANY_BLOCKING` the sole route to exit 2. Verified
      exhaustively: every other path is `soft_exit`/`exit 0` (`:63-67`, `:69`, `:75`, `:92`,
      `:104`), so "blocks **only** when" holds strictly, not just typically. Behaviourally proven
      by the AC5/AC6/AC7/AC10 fixtures.
- [x] **AC2** -- Prefix comes from `edm-state active-initiatives` (`:73`), parsed at `:80-89`; no
      cwd derivation. Asserted negatively (`check_absent ... "basename"`, `wave8-smoke.sh`) with an
      honest comment explaining why a bare `pwd` grep would self-match the script's own
      `SCRIPT_DIR` boilerplate -- the self-matching-scan trap this initiative has hit five times,
      correctly avoided here rather than shipped. The "no resolvable initiative -> clean exit 0"
      clause is proven by `t47_ac11_case`.
- [x] **AC3** -- `:132-134` prints one `[EDM] <N> informational anomalies (run: edm-state validate
      <PREFIX>)` line and never the individual info lines. This ticket adds no per-anomaly printing.
- [x] **AC4** -- Machine-checked with a real positive control. `_t47_ac4_nonconditional_hits`
      greps the five anomaly names and filters comment-only lines; the real run must return empty,
      and a scratch copy with an injected `if [[ "$_class_name" == "OPEN_PARTIALS" ]]` conditional
      must be flagged. That control is what makes the zero-hit result evidence rather than an
      unfalsifiable green.
- [x] **AC5** -- `t47_ac5_case`: `record-partial-verdict` creates an unclosed `partial_verdict_map`
      entry; asserts exit **2**.
- [x] **AC6** -- `t47_ac6_case`: opens a `code` round and never completes it; **first** asserts
      `validate` really emitted `info  OPEN_AUDIT_ROUND`, then asserts exit **0**. The existence
      assertion is what stops this being an exit-0 from an empty fixture.
- [x] **AC7** -- `t47_ac7_case`: writes a `findings-ledger.jsonl` line with
      `"status":"fixed","spec_swept":"no"`; same both-directions shape -- asserts
      `info  SPEC_SWEEP_PENDING` is present, then exit **0**.
- [x] **AC8** -- The descoped anomaly is proven absent *functionally*, not just by absence of
      implementation: `t47_ac8_case` patches a phase with `started_at` and no `completed_at`, then
      `check_absent`s any anomaly naming it and asserts exit 0.
- [x] **AC9** -- `t47_ac9_case` asserts both tokens (`OPEN_PARTIALS` and `T47NAME`) in the captured
      stream, and fails the case if the fixture did not actually reach the blocking path -- so the
      two `check`s cannot pass against output produced by a non-blocking run.
- [x] **AC10** -- `t47_ac10_case` runs one fixture initiative twice: informational-only -> exit 0,
      then mutated in place with `record-partial-verdict` -> exit 2, plus a `check` on the message.
      One state file, two states, exactly as the AC specifies (and distinct from T46 AC2, which
      compares two different initiatives).
- [x] **AC11** -- `t47_ac11_case` asserts `rc=0 && -z "$out"` with stdout and stderr combined, so
      "no output on either stream" is genuinely checked. Run inside `t46_isolate_and_run`, which
      builds a fresh scratch repo with isolated `HOME` and `CLAUDE_PROJECT_DIR` -- the fixture
      isolation is real, so `PERM_RULES_MISSING` cannot leak in from the developer machine.

**No findings.** Suite evidence: `wave8-smoke.sh` is 507 passed / 0 failed on the merged tip, and
every T47 assertion lives in that suite.

Two things I checked for and did not find: the ticket does not sneak a `${var^^}` normalisation
into the class comparison (C1 -- the token is compared literally at `:116-118`), and it does not
add any anomaly name to `edm-stop-gate` under cover of a comment (the grep returns zero hits, so
even the comment-tolerant AC4 rule is satisfied more strictly than it requires).

---

### EDMV4-T44: Make `action: block` explicit opt-in behind a two-tier exit contract -- FAIL

Eight ACs. Six verified; two FAIL. The evaluator work is correct and well-tested. The two failures
are AC4 and AC5, whose behavioural clauses require *consumer* behaviour that no consumer
implements -- a specification defect the ticket pack created and did not finish repairing, not an
implementer shortfall.

- [x] **AC1** -- `bin/edm-hookify:281-287`: only the literal `"block"` takes the blocking branch;
      anything else (absent key, unknown value) falls through to warn -- fail-safe toward
      non-blocking. Asserted at the fixture level: the test `jq 'del(.action)'`s a real fixture,
      runs it against a matching payload, and asserts exit 0 **and** that the emitted line names
      action `warn` by name. That second half is what makes it a default-to-warn test rather than a
      "nothing happened" test.
- [x] **AC2** -- Exactly three codes. `:293-295` is the whole exit surface: `HAD_BLOCK -> 2`,
      `HAD_ERROR -> 1`, else 0, with precedence block > error > clean. Seven scenarios assert exact
      codes individually, plus an aggregate `{0,1,2}` membership check. Precedence is separately
      proven with a block rule co-resident with a malformed rule file -> exit 2 with the malformed
      file still named on stderr; that is the "one contributor's typo must never mask another rule's
      legitimate block" property, machine-checked.
- [x] **AC3** -- `:285`: warn -> stderr, exit unchanged. Asserted with stdout and stderr
      captured to **separate files**, a `check` on stderr for the exact `rule_id action message`
      line, and a `check_absent` on stdout. The negative half is what makes it a stream assertion.
- [ ] **AC4** -- **FAIL.** See finding.
- [ ] **AC5** -- **FAIL.** See finding.
- [x] **AC6** -- One matching warn rule plus one matching block rule: exit 2, block line on stdout,
      warn line still on stderr, and a `check_absent` proving the warn line did not also leak onto
      stdout. All three assertions present; a block does not suppress a concurrent warning.
- [x] **AC7** -- `CLAUDE.md:1044-1073`, a `### edm-hookify's two-tier exit contract (EDMV4-T44)`
      subsection. Placement verified: it sits inside `## Hooks behavior` (`:1028`-`:1081`), and it
      uses the same three-column table form the surrounding rows use. Cross-references
      `edm-lint-staged-artifacts` by name ("the same violation-versus-setup-error split
      `edm-lint-staged-artifacts` already applies to `git commit`"). "There is no fourth code" is
      stated and asserted.
- [x] **AC8** -- `CLAUDE.md:1126-1136`, verified to sit inside `## Artifact content conventions`
      (`:1102`-`:1145`). Both independent reasons are named with their citations
      (`edm-lint-artifacts:251-260`'s `-name '*.md'` filter; `edm-check-vocabulary:98-107`'s
      `${PLUGIN_ROOT}`-anchored `SCOPE_ROOTS`), and it points at `EDMV4-57` as the owner. Stated as
      fact, not assumed closed -- which is what this AC asked for. C10 honoured: the prose says "not
      closed here", never "deferred".

**Findings**

```
[P2] EDMV4-T44 | plugins/edm/bin/edm-gateguard, plugins/edm/bin/edm-stop-gate | AC#4: neither consumer translates edm-hookify exit 2 -- no consumer calls edm-hookify at all
```
`grep -n hookify` over both files returns zero hits. AC4's behavioural clause ("`edm-gateguard`
translates `edm-hookify` exit 2 into a refusal through its own `emit_decision deny`, and
`edm-stop-gate` translates it into its own exit 2") is unimplemented. What shipped is the contract
documented in `CLAUDE.md` plus two `check`s asserting that documentation exists -- **and** a
`check_absent` at the T44 block asserting `edm-stop-gate` still does *not* invoke `edm-hookify`,
i.e. the suite deliberately pins the opposite of AC4's behavioural clause.
**Root cause is a specification defect, not implementer choice.** The ticket-pack audit's P0-2
resolution broke the T44/T46 circular dependency by making T46 validate-only and moving the wiring
to `EDMV4-T45` (`EDMV4-T46` AC5 states this explicitly, and `bin/edm-stop-gate:9-13` records it in
its own header). T44's own Out of Scope agrees: "This ticket specifies how those two consumers
translate an exit code". But AC4/AC5 were never rewritten to match, so they still read as
behavioural assertions about code T45 owns.
**Fix -- do not wire the consumers under T44**; that would violate the serialization the P0-2 fix
established. Either (a) re-scope AC4/AC5 to their documented-contract form through gate change
control, or (b) hold T44 open and add the two consumer-level assertions once `EDMV4-T45` lands.
Severity P2 because the safety-relevant property is real today: with no consumer calling the
evaluator, no exit code from it can escalate to a block anywhere.

```
[P2] EDMV4-T44 | plugins/edm/bin/tests/wave8-smoke.sh | AC#5: the required consumer-level assertions are evaluator-level instead
```
AC5 demands a smoke test that puts a malformed rule file in the rule directory and asserts "an
`Edit` payload through `edm-gateguard` is still allowed **and** a `Stop` through `edm-stop-gate`
still exits 0, with the malformed file named on stderr in both cases". What shipped asserts
`edm-hookify eval file` -> exit **1** and `edm-hookify eval stop` -> exit **1**, with
`malformed-invalid-json` named on stderr for both -- at the evaluator, not through either consumer.
The load-bearing half ("exit 1, never 2") is genuinely proven, and the two-event split is a
reasonable stand-in given the classify pass validates every rule file identically regardless of
event. But the AC's actual subject -- consumer non-escalation -- is untested, and untestable until
T45 lands. Same root cause and same fix as the AC4 finding; these two should be remediated together
as one change-control item.

**Verified not a hidden regression** (the shard brief's specific concern). T44 widened two
pre-existing `EDMV4-T43` assertions to `2>&1` because its own change moved `warn` output to stderr.
I checked both, and the claim that stream-specific coverage replaces the dropped distinction holds:

1. `t43_run()` (`wave8-smoke.sh:1924-1938`) gained `2>&1`. It backs T43 AC4, which asserts the
   matched-rule line's exact `rule_id action message` **format**. Widening loses only "which
   stream"; the format assertion is a literal-string `check`, so an unrelated stderr line cannot
   satisfy it. The dropped distinction is separately and directly covered by T44's own AC3 block --
   `check` on stderr **plus** `check_absent` on stdout, against separately captured files, and
   again by the AC6 block's `check_absent` proving a warn line does not leak onto stdout in the
   mixed warn+block case. Stream routing is one code path (`:281-287`), so covering it once with
   both polarities is sufficient.
2. `T43_HUGE_OUT`/`T43_NORMAL_OUT` (`:2080-2084`) gained `2>&1` for the 64 KiB truncation test.
   Here the widening **strengthens** the pair rather than weakening it. The rule's action is `warn`,
   so post-split its output is on stderr; without `2>&1` the positive control ("the marker DOES fire
   within the ceiling") would have found nothing and failed, and the negative `check_absent` ("a
   match only past the ceiling does not fire") would have passed vacuously against empty output.
   After the widening both halves are real again.

No assertion was deleted or relaxed in either case -- the diff adds 188 lines to `wave8-smoke.sh`
and removes 6, all six being the two capture lines and their replacements.

---

### EDMV4-T41: Feed the readiness score into the classifier and into planning.md -- PASS

Eight ACs, all verified. The integration is advisory in both directions exactly as specified, and
the shard brief's specific hazard -- reading booleans out of score records with jq's `//` -- does
not occur, because this ticket reads no JSON at all.

- [x] **AC1** -- `skills/plan/SKILL.md:83-92`, a new Step 6 titled "**Optional repository readiness
      scorecard** (EDMV4-T41)". The step is guarded by `command -v edm-repo-readiness >/dev/null
      2>&1` and the word "Optional" is in its own heading, so the optionality is stated rather than
      implied. The surrounding steps were correctly renumbered 6->12. Placement respects the
      ticket's Technical Note: the invocation lives in `skills/plan/SKILL.md`, never in the
      orchestrator, so `edm-check-skill-sync`'s "the dispatcher holds no phase procedure body"
      assertion still holds.
- [x] **AC2** -- The step reads "the `Rubric version:` and `Overall score:` lines from its stdout
      and record[s] both together", and states outright that "a bare score with no rubric version is
      a defect". The template addendum at `:191-200` shows both lines in the section format. Producer
      contract verified rather than assumed: `bin/edm-repo-readiness:475` emits
      `Rubric version: ${READINESS_RUBRIC_VERSION}` and `:493` emits `Overall score: %s / 10`, so
      the two strings the skill instructs a reader to extract genuinely exist.
- [x] **AC3** -- `skills/orchestrator/SKILL.md:123`: "may consult it **only** as an additional input
      to the **design-ambiguity** signal above -- never as a fourth signal, and never as an input to
      the files-touched or new-dependency-or-contract signals." All three constraints of the AC
      (design-ambiguity specifically; not a fourth signal; not an input to the other two) are
      present in one sentence.
- [x] **AC4** -- Same line: "The security-trigger tie-breaker's `standard` floor above always wins
      over any score-driven adjustment; the score never lowers or overrides it." Precedence stated
      explicitly and in the direction the AC requires.
- [x] **AC5** -- `skills/plan/SKILL.md:84-89`: not on PATH -> "skip this step entirely and proceed
      unchanged -- no error is raised, and no placeholder section is written to planning.md", with
      the Technical Note's own guidance honoured verbatim ("do not write a 'readiness: not measured'
      note"; absence is authoritative, matching how EDM handles N/A test layers).
- [x] **AC6** -- Both failure modes are named in one clause: "if the command **is not on PATH, or it
      exits non-zero**", sharing the same no-error/no-placeholder consequence. The template addendum
      at `:199-200` repeats the rule for the section itself.
- [x] **AC7** -- `skills/orchestrator/SKILL.md:123`: "When no score is available, this step still
      produces a recommendation from the three signals alone and never blocks on, or waits for, the
      scorecard." The plan skill states the same from its side ("the size classifier ... never waits
      for it").
- [x] **AC8** -- `plugins/edm/CLAUDE.md:1199-1216`, a dedicated
      `### Repository readiness feeds planning.md and the classifier (EDMV4-T41)` subsection naming
      the producing command (`bin/edm-repo-readiness`), where it runs (`skills/plan/SKILL.md`
      Step 6), and both consumers. The `bin/` helper table row at `:1195` was updated in the same
      change to point at it, so a reader arriving from either direction lands on the explanation.

**No findings.**

**Boolean-via-`//` hazard: verified absent.** T41 consumes the **summary text**, not the JSON --
the skill instructs reading two literal stdout lines, and T41's diff touches only `CLAUDE.md`, the
two SKILL.md files and `wave8-smoke.sh`. It introduces no `jq` invocation anywhere, so it cannot
reintroduce the `false`-treated-as-absent defect. Separately confirmed that `EDMV4-T39`'s fix is
intact upstream of it: `bin/edm-repo-readiness:443-451` carries an explicit comment naming the trap
and uses `(if ($applicability | has($catname)) then $applicability[$catname] else true end)` rather
than `$applicability[$catname] // true`. The only `//` operators in that file (`:452-453`) apply to
`add`, which returns `null` on an empty array -- a numeric default, not a boolean.

**Test quality note (positive).** T41's own smoke block does two things worth recording as good
practice rather than findings: it asserts the Step 1b.5 extraction is non-empty *before* running any
assertion against it ("extraction not silently vacuous"), and its guard-D6 regression check ships
with a positive control that injects a restatement phrase into a scratch copy and confirms the check
flips. Both are the pattern this initiative learned the hard way from D31/D35, applied without being
asked. The `EDMV4-T34` AC12 under-30-lines ceiling on Step 1b.5 is also re-verified post-addition.

## Remediation Required

Prioritized. Two P1s and five P2s; no P0s. `EDMV4-T41` and `EDMV4-T47` need nothing.

**P1-1 -- `EDMV4-T30`, `plugins/edm/bin/tests/wave7-smoke.sh:5468`.** Replace
`[[ "$t48_contested_count" -eq "$T48_CONTESTED_TOTAL" ]]` with `[[ "$t48_contested_count" -eq 18 ]]`
and delete `T48_CONTESTED_TOTAL` (`:5452`) or keep it only for message interpolation. Both operands
are currently the member count of one string, so no input can fail the assertion, and nothing else
in the suite cross-checks `T48_CONTESTED_AGENTS` against the tree. This is the highest-value fix in
the shard: it restores the only tripwire that would catch a lens being silently dropped from the D16
opus/max set -- the exact defect `EDMV4-T30` AC4 named as "the only site in this sweep where the
test passing is itself the defect".

**P1-2 -- `EDMV4-T30`, `plugins/edm/bin/tests/wave7-smoke.sh:9582`.** Replace
`-eq "$WAVE7_LENS_COUNT"` with `-eq 14`, or delete the assertion together with its now-false comment
at `:9578-9580` and note that `:5488` supersedes it. As shipped it compares
`printf '%s\n' $LENS_AGENTS | grep -c '.'` against a variable holding the identical expression.

**P2-1 -- `EDMV4-T31`, `decisions.md` D39 (AC9).** Fix the two genuinely stale strings the closure
sweep left behind -- `wave7-smoke.sh:480` ("the 11 `edm-audit-*` lenses", a comment; the code below
it is dynamic) and `wave7-smoke.sh:1491` (a live operator-facing `echo` reading "all 11 lens agents
remain opus/max on disk"). Then add `bin/edm-lint-artifacts:146` and `wave7-smoke.sh:20` to D39
category (i), and add a category covering the current-correct fourteen/fifteen text this sweep
itself wrote, so "zero survivors outside the list" is literally true when the next auditor re-runs
the grep. While there, fold in the four `lens-L11.jsonl` scratch-fixture paths `EDMV4-T23` added to
`wave6-smoke.sh` after this ticket closed.

**P2-2 -- `EDMV4-T31`, `decisions.md` D39 entry (f) (AC8).** Add `CLAUDE.md:578`'s D1 string ("the
11 code-audit lenses") alongside the D2 string already recorded. AC8 names both as one required
minimum entry. The tree is correct -- D1 is untouched -- so this is a record repair only.

**P2-3 -- `EDMV4-T44`, AC4 and AC5 (one item, not two).** Reconcile the ACs with the ticket pack's
own P0-2 resolution, which moved consumer wiring to `EDMV4-T45`. Either re-scope AC4/AC5 to the
documented-contract form through gate change control, or hold `EDMV4-T44` open until `EDMV4-T45`
lands and then add the two consumer-level assertions AC5 specifies. **Do not wire `edm-gateguard` or
`edm-stop-gate` under `EDMV4-T44`** -- that reintroduces the circular dependency the P0-2 fix broke,
and `edm-gateguard` is `EDMV4-T13`'s file this wave.

**P2-4 -- `EDMV4-T30` AC12, external.** `wave7-smoke.sh` cannot go green until `EDMV4-T26` lands the
L13 agent file (every lens failure is off by exactly one) and until the ~35 assertions left stale by
`EDMV4-T18`'s harvested-pattern relocation get an owning ticket. Nothing in `EDMV4-T30`'s own diff
needs to change for this. Recorded as a FAIL only because the AC is written as a green-suite gate.

**P2-5 -- unowned, surfaced by this shard.** `wave7-smoke.sh` still aborts under `set -e` before
printing its `Results:` line (my run: 15 FAIL lines, no summary). `EDMV4-T30`'s commit message
reports finding this near the Wave-4b mechanical-fixes block and correctly scoping it out. This is
the tenth instance of the class in this initiative and the one that previously hid ~500 assertions;
it needs an owning ticket rather than another honest scope-out.

<!-- QC-SHARD-COMPLETE range=T30-T47 assigned=5 audited=5 -->
