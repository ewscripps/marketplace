# SRD Audit Report: EDMDS -- EDMV4's Structural Design Docket

**SRD Version Audited**: 1.1.0
**Audit Date**: 2026-09-09
**Prior round**: `audit-srd-v1.0.0.md` (v1.0.0, verdict FAIL -- 8 P0, 32 P1, 26 P2)

Four lanes, run in parallel. Lane boundaries were drawn much narrower than the prior round's two,
where a single lane covering eighteen requirements and seventy-five acceptance criteria exhausted
its budget and returned nothing usable.

| Lane | Scope |
|---|---|
| A | Sections 1-4 and 6, plus `architecture.md` |
| B | Section 5, Epics 1-2 -- `EDMDS-01` through `EDMDS-10` |
| C | Section 5, Epics 3-4 -- `EDMDS-11` through `EDMDS-21` |
| D | The Ticket List -- `EDMDS-T01` through `EDMDS-T31`, all 8 ticket dimensions |

Lane D exists because `mode=mini-srd` skips Phase 5 entirely, so this is the only ticket audit the
initiative will receive, and the merged Gate 2+3 enters Phase 6 directly off this file.

A fifth source of findings is recorded in `pending-v1.2.0.md`: the `edm-architect` agent re-derived
every citation in its brief while writing `architecture.md` and found four wrong. Those are audit
findings in substance and are remediated in the same pass.

## Summary

| Lane | P0 | P1 | P2 | NOTED | Verdict |
|---|---|---|---|---|---|
| A -- Sections 1-4, 6, `architecture.md` | 3 | 18 | 14 | 9 | FAIL |
| B -- Requirements 01-10 | 5 | 22 | 13 | -- | FAIL |
| C -- Requirements 11-21 | 6 | 18 | 16 | 12 | FAIL |
| D -- Ticket List | 0 | 14 | 18 | 9 | NEEDS FIXES |
| Architect verification pass | 0 | 1 | 2 | 1 | -- (one entry withdrawn) |
| **Combined, before de-duplication** | **14** | **73** | **63** | **31** | **FAIL** |

**Verdict: FAIL.** Every lane failed independently, as in the prior round.

**What the count does not say.** v1.1.0 is a genuine repair, not a reword, and each lane says so on
its own evidence: lane A found all three of its P0s fixed and 14 of 18 P1s; lane B found 11 of 16
in-scope findings fixed; lane C found 14 of 18; lane D found the prior round's structural P0 closed
and coverage AC-complete in both directions. Roughly fifty code citations added in this revision
were verified line-for-line across the four lanes, with two exceptions.

**Why it fails anyway.** The failure is not breadth, it is a defect CLASS recurring wherever the
rewrite did not sweep. Three instances of *"a `Must` silently falsifies shipped assertions with no
AC owning them"* -- the exact finding the prior round raised as its P0-5, which v1.1.0 fixed for
EDMDS-07 and then reproduced in EDMDS-06 (50 fixture lines), EDMDS-15 (roughly forty assertions
across two suites) and EDMDS-19 (two live-derived subcommand-count checks). Four instances of
*"an assertion that cannot fail"* -- Goal 3's own class -- in EDMDS-10 AC5, EDMDS-11 AC8, the four
duplicated line-count AC, and EDMDS-19 AC6, which would have gone green on a sentinel-free fixture
while the population it targets stayed broken. And three new unfalsifiable disjunctions appeared
where the prior round's eight were closed.

**Two findings are blocked on facts no amount of reading settles**, and both have in-tree precedent
for how to settle them (D25 Spike A, D26 Spike B, CA-007's host re-verification): whether a
`PreToolUse` hook's stderr reaches the operator on exit 0 and its stdout on exit 2 (lane A P0-3,
which decides `AD-DS1`'s branch at three of four surfaces), and whether the `UserPromptExpansion`
hook input exposes the invoked command name (lane C, which decides whether EDMDS-15 AC1 is
feasible at all). A third is settled by one `jq` invocation: whether Oniguruma's retry limit is
configurable per-invocation, which `explorers/04:94` records as "not investigated" and which would
defuse R5 entirely.

## Cross-lane corroboration

**The strongest signal in this round.** Lane D and the architect's verification pass reached the
same defect independently, by different routes, and neither knew of the other:

- The architect, tracing which scripts source which libraries: only `bin/edm-gateguard:89-91` and
  `bin/edm-state:74` source `bin/_edm-datadir-lib.sh`. `EDMDS-14`'s named extraction target
  therefore cannot reach two of the three sanitizer copies, and extracting to a new library makes
  GateGuard net **+1** line against a CLOSED 660 bound it already sits one line under. Recorded as
  `pending-v1.2.0.md` A1 and A2.
- Lane D, auditing Target Components against the filesystem: `EDMDS-T21` names the wrong three
  `bin/` scripts -- it includes `bin/edm-bash-gate`, which holds **no** existing sanitizer copy (it
  is the new site AC4 adds), and omits `bin/edm-hookify:226`, which holds one that must change.
  Recorded as P1-CN1. Lane D separately found the four line-count acceptance criteria cannot fail,
  because "recorded" asserts nothing at 659 of 660. Recorded as P1-A1.

Lane D also names P1-CN1 as CA-063's own defect class -- a deliverable omitted from a ticket's
Target Components -- reproduced inside the ticket implementing the requirement chartered to close
CA-063. The prior round caught that same shape once already, in the SRD's total absence of Target
Components. Finding it twice, in two rounds, in the document whose charter is to close it, is worth
recording as a pattern rather than as two incidents.

---

# Lane D -- Ticket List (EDMDS-T01 through EDMDS-T31)

**P0: 0 | P1: 14 | P2: 18 | NOTED: 9. Verdict: NEEDS FIXES.**

**The prior round's structural P0 is closed.** The Phase-4 half exists, carries `EDMDS-T{NN}` ids,
Sizes, Target Components and a `Generated From:` header, and three of the four downstream mechanisms
`L2-P0-2` named are now fully satisfied. No new P0. What remains concentrates in two places:
undeclared shared-file ordering, and acceptance criteria that cannot fail.

Dimension counts: coverage 0 - sizing 4 - dependencies 8 - critical path 2 - AC quality 15 -
diagrams 0 (vacuous) - consistency 5 - version alignment 0.

## P1 -- Significant (14)

1. **P1-CN1 [structural] `EDMDS-T21`** -- Target Components names the wrong three `bin/` scripts.
   The three sanitizer copies are `bin/edm-hookify:226`, `bin/edm-stop-gate:123`,
   `bin/edm-gateguard:213`. The field includes `bin/edm-bash-gate` (zero copies -- the NEW site AC4
   adds) and omits `bin/edm-hookify` (one copy that must change). The omission also hides a
   shared-file dependency: `bin/edm-hookify` is additionally a Target Component of T02, T04, T18 and
   T24, so T21's collision analysis is wrong as well as its deliverable list. That T24 gets the
   identical file set right and T06 correctly excludes `bin/edm-stop-gate` shows the pack
   understands the convention -- this is a slip, not a house style. **CA-063's defect class,
   reproduced in the ticket closing it.**
2. **P1-A1 [content-quality] `EDMDS-T05` AC6, `T06` AC5, `T21` AC5, `T24` AC6** -- four verbatim
   duplicate AC that cannot fail. "`bin/edm-gateguard` line count recorded after this ticket (R3)."
   Duplicated AC across four tickets is a Dimension 5 defect on its own; worse, "recorded" asserts
   nothing -- an AC recording `701` passes exactly as happily as one recording `659`. Goal 3's own
   defect class inside the pack implementing the document that declares Goal 3. Fix: assert
   `<= 660`, never the literal 659 (the CA-067/D15 total-versus-delta trap).
3. **P1-D1 [structural]** -- R3's stated mitigation is not delivered by the dependency graph. Four
   tickets modify `bin/edm-gateguard` (T05, T06, T21, T24); the graph sequences T04<T05<T06 and
   T21<T06 but leaves **T24 sequenced against none of them**. T24 and T21 can land in one wave, both
   editing the file, and neither "after this ticket" measurement is then well-defined. Fix: T24
   depends on T06.
4. **P1-D2 [structural]** -- nine unsequenced writers to one `decisions.md`: T01, T02, T07, T08,
   T10, T14, T15, T20, T25. Nothing allocates D-number ranges. Two parallel implementers both
   writing "D52" corrupts the ledger EDMDS-17's "record of closure" rests on.
5. **P1-D3 [structural]** -- T27 and T28 both edit `bin/_edm-datadir-lib.sh` unordered, and
   interact semantically: T28 AC5's control ("a fixture where `run/` is removed loses ownership")
   reads the very function T27 AC1 tightens, so whether the control passes depends on whether T27
   landed. AD-DS4 binds both requirements; the pack encodes EDMDS-19's internal order but not the
   EDMDS-19/EDMDS-20 order.
6. **P1-D4 [structural]** -- T29 relocates `wave7-smoke.sh`'s deliberately-last band into a helper
   while T19 and T23 append new bands to the same file, all three at depth 1. If T29 lands first,
   the later bands sit after the relocated call and are unobserved by it -- silently defeating the
   whole-suite guarantee T29 exists to strengthen.
7. **P1-D9 [structural] `EDMDS-T30`** -- "Depends On: every other ticket" is legitimate in intent
   and an evasion in effect. `/edm:implement` scans that field for `{PREFIX}-T{NN}` tokens and finds
   **zero**, so T30 parses as dependency-free and lands in wave 1 -- the exact inverse of the
   declaration, and precisely the mechanism `L2-P0-2` flagged. It is also over-constrained: AC1-AC3
   need no other ticket. Fix: split into a wave-1 decision-recording half and a terminal
   `resolved_commit` half.
8. **P1-A2 [content-quality] `EDMDS-T12`** -- no negative control, and its central claim is
   unproven. AC2 says the change is atomic "so a partial update fails the suite"; AC3 says a passing
   suite proves byte-identity. A passing suite after a COMPLETE update proves nothing about whether a
   PARTIAL update would be caught. Breaches CC1. Fix: mutate one of the copies in a scratch tree and
   require the assertion to fail.
9. **P1-A3 [content-quality] `EDMDS-T14`** -- no negative control, and its AC understate a
   structural cascade (see P2-S2).
10. **P1-A7 [content-quality] `EDMDS-T07` AC1** -- surviving AD-DS5 disjunction: CA-196's status
    "reaffirmed with a current reason **or** superseded by a fix". The left branch is discharged by
    writing one sentence, and the implementer chooses at implementation time -- authority
    `canonical-sections.md:118-123` reserves to a human at a gate. **Root cause is `EDMDS-02 AC8`**,
    which carries the identical unresolved disjunction.
11. **P1-A8 [content-quality] `EDMDS-T13` AC5** -- same shape: D40's harder half "distinguished from
    non-delivery, **or** shown not to exist". `EDMDS-07 AC7` at least adds "if it exists, the
    signal is named"; the ticket drops even that.
12. **P1-A9 [content-quality] `EDMDS-T01` AC2** -- no falsifiable outcome and no recording target.
    Conditional, so vacuous whenever the figure is at or above 4048; "investigated and explained"
    states no bar; names no artifact. T01 roots the entire dependency graph and R11 makes it the
    anchor for every later comparison, so this AC is load-bearing and currently ungradeable.
13. **P1-CN2 [structural] `EDMDS-T23`** -- Target Components omits `decisions.md` (AC4 requires a
    record with nowhere to land) and `CLAUDE.md`. Separately verified: `CLAUDE.md`'s
    Sec."Hooks behavior" describes the hook as a single matcher
    `edm:(srd|audit-srd|tickets|audit-tickets|implement)`, which is **already false** --
    `hooks/hooks.json` carries five separate `UserPromptExpansion` entries. T23 AC1 is the change
    that makes that sentence true, and `CLAUDE.md` is not in its Target Components.
14. **P1-CN3 [structural]** -- the stated Target Components root is contradicted by eleven tickets.
    Line 883 says paths are relative to `plugins/edm/` unless stated otherwise; T01, T02, T07, T08,
    T10, T14, T15, T18, T20, T25 and T30 name `SRD/edm/...` paths and none states otherwise. Under
    the stated root those files do not exist. Rated P1 rather than P0 because the intent is
    unambiguous to a human, but the mechanical consequence is real -- an artifact written to the
    wrong path falls outside `edm-lint-artifacts`' prefix scan and outside `resolve-dir`. One clause
    fixes it.

## P2 -- Minor (18)

**Sizing (4)**: T24 undersized at S -- AC5 alone is four error-injection harnesses against four
scripts, more work than T21 at M; the legend's own rule is size up when in doubt. T14 a candidate
for L: its work is not "amend six expectations" but restoring five fixtures to full-round shape and
re-establishing eight downstream assertions. T15 a candidate for L or a split -- nine AC, and AC4
(narrowing the double-completion refusal) is the architecturally riskiest change in the pack and
separable from the promotion path. T08 (S, 3 AC) and T31 (XS, 1 AC) are the same kind of pure-record
work at different sizes; one is wrong.

**Dependencies (4)**: `bin/edm-state` is a Target Component of eleven tickets, with T16, T17, T20,
T23, T25, T28 unsequenced against each other and against the T11<T13<T15 chain. Append-point
contention under CC5 -- `wave8-smoke.sh` is a Target Component of fourteen tickets and
`wave6-smoke.sh` of eight, and CC5 puts every new band at the same anchor, so unsequenced parallel
appends are a deterministic merge conflict; inherent to the single-file suite design, but it should
be an explicit wave-planning input. Documentation-section contention: `CLAUDE.md`'s hookify section
is edited by T02, T04, T05 and T09 with only T04<T05 ordered. T31 under-declares -- EDMDS-07 lands
via T13 **and T14**, so releasing CAMGAP after T13 alone records a closure that is not yet true.

**AC quality (7)**: T18 AC8 cannot fail as written (asserting current names on an unchanged resolver
is green by construction) and T18 AC5 carries no control. T24 AC5 carries no control. T03's control
covers one arm of two -- nothing discriminates that `edm-bash-gate` exits 0 *because it translates 1
into 0* rather than unconditionally, which matters precisely because the SRD corrects v1.0.0 for
misattributing that exit 0. T14 AC2's "shown unaffected" needs pinning to a passing run. T23 AC4 is
a determination-plus-record with no target file. T31's single AC is pure sentence-writing with no
verification; it should at minimum assert no released prefix remains referenced in `CLAUDE.md` or
`docs/`. T27 AC5 restates its own `Depends On` line as an AC -- ordering is not gradeable from code.
T22 AC3's "a negative control per site" is ambiguous for three of four sites, because `:7891`,
`:8996` and `:9027` **are already controls**; the real obligation is that each still discriminates
after amendment.

**AC count band (1)**: 23 of 31 tickets fall below the 6-12 house band, none above. The cause is
structural -- requirements were split across tickets by AC range, so each carries a slice. Padding
23 tickets to reach a number is not recommended; either state the deviation in the legend as
deliberate, or merge the thinnest pure-record tickets (T08, T31 and T07's `decisions.md`-only half
are one coherent ticket, which would also retire P1-D2's contention and the T08/T31 inconsistency).

**Consistency (2)**: T12's Target Components pins "(14 files)" against a glob
`agents/edm-audit-*.md` that matches **15** -- the fourteen lenses plus the synthesizer. CLAUDE.md's
own house lens contract derives the set live "excluding the synthesizer" for exactly this reason,
and D15 forbids writing today's number into an AC; AC2's "atomic across all 14" repeats it. T29
AC2's cited range `wave7-smoke.sh:10186-10228` is not the whole band -- the `if` opens at `:10192`
and the `fi` closes at **`:10230`**, so extracting the cited range yields an unbalanced `if`. The
right band is identified; for an extract-into-a-helper AC the boundary is the deliverable.

**Coverage (2, reported here rather than as gaps)**: no requirement-to-ticket coverage map exists, so
the hand verification below is the only check there is. T23 lists `bin/edm-state` with no AC
requiring a change there.

## Verified clean -- recorded so the audit's silence is not mistaken for omission

- **Coverage is AC-complete in both directions.** All 21 requirements map to at least one ticket, no
  orphan tickets, and for every requirement the union of the AC ranges its tickets claim exactly
  equals that requirement's AC set -- verified element by element for all 21.
- **Ticket ids clean**: `EDMDS-T01` through `EDMDS-T31`, sequential, no gaps, no duplicates,
  correct `{PREFIX}-T{NN}` zero-padded format.
- **No cycles.** The graph is a forest rooted at T01 with a single sink at T30. The non-obvious
  declared orderings are correct: T04<T05<T06 (output contract before consumers), T11<T13<T15 (all
  three edit `cmd_audit_round_complete`), T25<T26<T27 (AD-DS4's load-bearing detect-migrate-tighten
  order), T21<T22.
- **No XL, no ticket requiring decomposition on size grounds.** Distribution 2 XS / 7 S / 22 M / 0 L.
- **Every Target Components path exists on the filesystem** -- checked, not assumed. No
  nonexistent-file P0.
- **Every line-number citation in the ticket half is accurate**, with no drift: `edm-hookify:369`
  and `:414-425`; `edm-gateguard:647`; `edm-state:5163`/`:5177`/`:5193` (all three) and
  `:1191-1193`; `CLAUDE.md:1345`; `README.md:342`; `wave6-smoke.sh:1132-1140` and all six of
  `:681`/`:697`/`:738`/`:750`/`:778`/`:790`; all four of `wave8-smoke.sh:7877`/`:7891`/`:8996`/`:9027`;
  `wave8-smoke.sh:10302-10308`. `bin/edm-gateguard` measured at exactly **659** lines, so CC7 and
  DoD item 6 are accurate.
- **T14 AC2's substantive claim verified line by line**: `:681`=PDEBT1, `:697`=PDEBT2, `:738` and
  `:750`=PDEBT3 (two completions), `:778`=PDEBT4, `:790`=PDEBT5.
- **EDMDS-15's premise verified**: the five `UserPromptExpansion` `command` strings are identical
  apart from the gate token, and the five `prompt` strings likewise except `edm:implement`, which
  adds the Gate 3.5 clause. The SRD's characterisation is accurate.
- **Version alignment clean, four-way**: ticket header line 876, document body line 3, Section 1
  line 9, and `.edm-state.json` all read `1.1.0`.
- **The fused-layout spec is met and in two respects exceeded.** `skills/srd/SKILL.md:126-142`
  prescribes the `## --- Ticket List ---` heading, `### {PREFIX}-T{NN}` entries, `Size`, `AC` and a
  `Generated From:` line; all present, plus `Depends On` and `Target Components`, which that spec
  does not require. The Phase-4 critical-path mandate attaches to `tickets/README.md`, and the same
  spec says no separate ticket pack is created -- so its absence is not a spec violation.

## Critical path -- no diagram, and the judgement behind that

There are **zero** Mermaid blocks anywhere in the file, either half. Checked rather than assumed:
`mermaid`, `flowchart` and `graph TD|LR` across all 1360 lines return nothing but a revision-history
row. Dimension 6 is therefore vacuously clean -- no syntax to validate, no uncoloured or orphan
nodes, and no possible violation of the semicolon convention, because there are no labels at all.

**Not a spec violation** (see above), but **recommended at this scale** as P2-CP1. Thirty declared
edges across 31 interdependent tickets with a nine-wide depth-1 tier is past what a reader holds in
their head, and the Gate 2+3 reviewer is being asked to enter Phase 6 directly off this file. Three
of the P1 dependency findings -- D1, D3, D4 -- are exactly the class a diagram surfaces on sight. If
added it must show all 31 nodes and 30 edges; T30's fan-in rendered explicitly rather than as prose;
the four-ticket `bin/edm-gateguard` contention set {T05, T06, T21, T24} and the wave7 set {T19, T23,
T29} as ordering edges rather than merely coincident Target Components; and colour by wave so the
depth-1 tier's width is visible. Any `;` in a node label written `#59;`.

The current critical path is T01 -> T04 -> T05 -> T06, four deep, with T21 joining at T06 -- stated
nowhere, and it changes the moment P1-D1's edge is added (P2-CP2).

## L2-P0-2 mechanism confirmation

The prior round's P0 named four downstream mechanisms that break when ticket ids are absent. Three
are now fully satisfied; one carries a P1 residual.

| Mechanism | Status |
|---|---|
| `/edm:implement` wave grouping needs a derivable dependency graph | **Mostly satisfied** -- derivable for 30 of 31, concrete existing ids, no cycles. Residual: T30 (P1-D9) parses to zero ticket tokens and would land in wave 1 |
| Commit subjects carry `{PREFIX}-T{NN}` for `edm-impl-progress` | **Satisfied** -- ids match the pattern `cmd_watch_impl` polls `git log` for |
| `record-partial-verdict <PREFIX> <ticket>` and `archive`'s open-PARTIAL block | **Satisfied** -- stable per-ticket ids now exist to key on |
| QC shard filenames and `edm-check-verifier-sentinel`'s `T{a}-T{b}` parse | **Satisfied, verified against the script** -- `:135` matches `T[0-9]*-T[0-9]*` and `:139` uses `10#` arithmetic, so zero-padded `range=T01-T04` parses to span 4 without octal misreading |

The `Generated From:` line, which `L2-P0-2` noted nothing would catch under mini-srd because Phase 5
is skipped, is present and correct. This audit is that catch.

## NOTED (9)

T01 is not tied to a numbered requirement but is traceable both ways -- R11's mitigation names it
explicitly, so it is not an orphan ticket. Ticket order does not follow requirement number, which
mirrors the document's own epic structure and is consistent. `Generated From:` appears twice (lines 3
and 876), harmless and arguably correct for a file that must satisfy both conventions. The absence
of any L or XL ticket is a legitimate outcome of requirement-slice decomposition, not a suppressed
one. T02 AC4, T20 AC6 and T25 AC5 are pure record obligations, **not** AD-DS5 violations -- AD-DS5
prohibits the disjunction, and these state a single obligation to record a decision already made in
the SRD text; T20 AC6 is the exemplary case. T14 AC2's disjunction **is** legitimate where P1-A7 and
P1-A8's are not, because both branches are mechanically checkable by running the band, and PDEBT4
genuinely is unaffected (its round is already `partial` via `--lenses L1`) -- only the wording needs
tightening. T06 correctly excludes `bin/edm-stop-gate` from Target Components although AC2 mentions
it, since AC2 only confirms unchanged behaviour -- the correct deliverable-versus-reference
distinction, which is what makes P1-CN1 a slip rather than a convention.
`edm-check-verifier-sentinel` expects a bare `T01-T04` in `range=`, not the prefixed form -- a
Phase-6 dispatcher concern, not a defect here. CC7's "659 lines, one line of headroom" is accurate.

## Lane D -- not audited

Stated so absence of a finding is not mistaken for cleanliness.

- Section 5 as a requirements document, and Sections 1-4 and 6 -- read as reference spec only, per
  scope. Where a ticket inherits a defect from its requirement (`EDMDS-02 AC8` behind P1-A7,
  `EDMDS-07 AC7` behind P1-A8, `EDMDS-06 AC6`'s "all 14" behind the T12 finding) the ticket instance
  is reported and the root named, but those requirements were not audited on their own terms.
- Whether `run-all.sh` actually passes at 4048 -- requires executing the suite; the lane has no
  `Bash` tool. `EDMDS-T01` exists to establish it, and its AC2 is P1-A9.
- The two host-local measurements (144 delta findings, 85 stale `run/` markers) -- unverifiable
  without shell access. The SRD correctly confines both to rationale with no AC depending on them.
- `bin/edm-state`'s internal region boundaries -- cited line numbers and the `cmd_audit_round_complete`
  clustering confirmed, but not every one of the eleven `edm-state` tickets mapped to a byte range,
  so P2-D5's collision set may be larger than the two overlaps named.
- Full-body reads of `bin/edm-state` (over 5200 lines) and the three smoke suites -- read only at
  cited offsets plus context, so undeclared same-file interactions beyond those named may exist.
- `upgrade-path.md`, `analysis.md`, `architecture.md`, `planning.md`, `explorers/01`-`04` -- named as
  inputs, not read. CC1-CC8 taken as quoted in Sec.3.4 rather than verified against `analysis.md`.
- Cross-initiative id collision -- not checked; `edm-validate-prefix` owns prefix uniqueness.
- Roughly 95 of 141 AC received an individual falsifiability judgement. The unswept remainder is
  T11 AC1-AC4, T15 AC1-AC4, T16 AC1/AC4, T17 AC1, T20 AC1-AC2, T26 AC1-AC3 -- all restating their
  requirement's AC closely, none expected to yield a finding beyond those reported.

<!-- TICKET-AUDIT-COMPLETE range=structural assigned=31 audited=31 -->

---

# Lane B -- Section 5, Epics 1-2 (EDMDS-01 through EDMDS-10)

**P0: 5 | P1: 22 | P2: 13. Verdict: FAIL.** 10 requirements / 63 AC.

v1.1.0 is a genuine repair rather than a reword: **11 of the 16 in-scope v1.0.0 findings are fully
fixed**, and every one of the roughly 25 code citations added in this revision checks out
line-for-line. It fails on a narrower and sharper problem -- the same defect class v1.0.0's P0-5
named (a `Must` silently falsifying shipped assertions with no AC owning them) recurs twice more,
once in a suite the SRD never mentions -- and on Goal 3 being violated again, in a new place.

Diagram errors vacuously clean: no diagrams in Epics 1-2.

## P0 -- Critical (5)

1. **[FEATURE GAP] EDMDS-06 AC2 -- 50 lens fixture lines carry no `round`, and nothing owns them.**
   `bin/tests/wave6-smoke.sh` holds **50** hand-built lines of the shape
   `{"schema":"lens","lens":"L1","sev":"P2","status":"open","id":null}` (`:877`, `:879`,
   `:897-:935`, and the T22/T23 sets at `:3859-:4199`). **Not one carries a `round` field**
   -- verified: 50 matches, 0 with `round`. AC2 requires every line's `round` to equal the round
   being completed, so all 50 become rejections and every CA-471/CA-477/CA-478/CA-479/T22/T23
   assertion built on them fails, against DoD item 2's zero-failures requirement. Exactly the class
   v1.0.0's P0-5 named for EDMDS-07, fixed there and left open here.
   **Fix**: an AC modelled on EDMDS-07 AC4/AC5 naming the fixture set as an in-scope surface and
   stating the amended shape. Note the fixtures' `"schema":"lens"` string also diverges from the
   canonical `"schema":1` at `skills/code-audit/SKILL.md:348`.
2. **[FACTUAL MISTAKE] EDMDS-06 AC6 -- the assertion it relies on does not exist.** AC6's whole
   atomicity guarantee is "CLAUDE.md's house contract pins those copies byte-identical under a
   smoke assertion, so a partial update fails the suite." `wave8-smoke.sh`'s EDMV4-T28 band derives
   the lens set live and checks **section headings**; the only schema-line content checks are three
   per-lens spot greps for L12, L13 and L14 (`:1469`, `:1628`, `:1719`). The eleven pre-EDMV4
   lenses have no schema-content assertion at all, so a partial 14-file update passes silently.
   `agents/edm-audit-logic.md:91` makes the same unbacked claim, which is likely where the error
   came from. **Fix**: AC6 must ADD the assertion, not cite it -- derive the set live excluding the
   synthesizer, compare the `## JSONL Line Format` block byte-for-byte modulo the lens id, with a
   mutating control.
3. **[COMPETING REQUIREMENTS] EDMDS-06 AC1/AC3 vs EDMDS-08 -- the coupling breaks for a lens that
   legitimately finds nothing.** `agents/edm-audit-logic.md:59,87` instruct one JSONL line "for
   every finding", so a zero-finding lens produces zero lines. AC1's "at least one such line" plus
   AC3's "an empty file fails" force a clean lens to either fabricate a finding or downgrade a
   $105.28 round -- and EDMDS-08 AC1 restores `full` only if every failed check now passes, which
   for this class is impossible without fabricating. **The repair path cannot repair the downgrade
   EDMDS-06 creates.** EDMDS-07 AC7 asks exactly this question for the manifest case; EDMDS-06 has
   no analogue. **Fix**: define the no-findings artifact (a sentinel line, which
   `agents/edm-audit-logic.md:88` already half-establishes) and instruct it in AC6's prompt change.
4. **[FEATURE GAP] EDMDS-07 AC5 -- the seven named sites are not the complete set.** All seven
   verify exactly as stated, but `bin/tests/wave7-smoke.sh:9566-9573`'s `ca416_fixture()` helper
   does the same thing in a different suite, and its own comment states the intent the change
   destroys: "record one full code-audit round **so the round-type gate in cmd_audit_converged is
   satisfied**". Under EDMDS-07 that round records `partial`, and `bin/edm-state:5353`'s
   `elif [[ "$latest_round_type" == "partial" ]]` makes every `ca416_converged` call exit 1 --
   collapsing a band with **73 `ca416_*` references**. Two further unnamed sites:
   `wave6-smoke.sh:5343` (T51ROUND) and `:5864` (T53DEFAULT). **Fix**: re-derive the affected set
   mechanically across ALL suites and name every site. `wave7`'s CA-416 band needs its own
   amendment AC, since fixing it means teaching a shared helper to build a manifest.
5. **[SPECIFICATION QUALITY] EDMDS-10 AC5 -- the control cannot fail.** Goal 3's defect class
   inside the document that declares it, and the same finding lane 1 raised against v1.0.0's
   EDMDS-09 AC2. AC5 asserts two concurrent reconciliations "produce one marker". The marker is a
   **single fixed path** written through `write_atomic`'s mktemp-plus-rename (`bin/edm-state:124`),
   so at most one file can exist there with or without the lock. Worse, the fixture drives the
   wrong interleaving: AC4's own prose names the race as reconciliation versus a `phase-start 6` on
   a DIFFERENT initiative, and that is the one that can produce **zero** markers (session-start
   reads a stale marker at `:4773`, a concurrent `phase-start 6` writes a fresh one, then
   session-start's `rm -f` at `:4780` deletes it). **Fix**: drive that interleaving and assert the
   surviving marker's CONTENT -- that its PREFIX names an initiative really at Phase 6 -- not the
   file count.

## P1 -- Significant (22)

**EDMDS-01**: the Finding block says the `NOTED` half is recorded "by AC6"; AC6 is the negative
control and **AC7** is the record -- a wrong cross-reference in the one requirement whose whole
purpose is a vocabulary-conformant split. AC2 (exit 1, no block) collides with AC5 (a benign
sibling "still fires") because the ladder is `block(2) > error(1)` at `:478-479`, so a `block`
sibling makes AC2's exit unreachable; state the sibling's action is `warn` and that AC2 and AC5
share one invocation.

**EDMDS-02** (eight findings, the most-rewritten requirement): AC1 does not say WHERE the path
field goes, and `bin/edm-hookify:39-40` states the contract as message-last "so it may itself
contain spaces" -- a path appended after the message destroys every consumer's ability to split the
line, so the order is load-bearing and unstated. AC1 names one consumer of the changed line; there
are **three** (`edm-gateguard:647`, `edm-bash-gate:131,136`, `edm-stop-gate:238,244`), so AC6's
"`edm-stop-gate` is not changed" is true of the file and false of the behaviour. **The
`stop_gate_emit_blocking` shape does not transfer to `edm-gateguard`'s exit-code arm as the AD-DS1
table assumes**: `emit_decision` takes ONE `$reason` and sanitizes all of it at `:213`, before the
mode split at `:216`, deliberately -- the comment at `:209-212` explains it protects the `json`
arm's `jq -cn` control channel. Producing an unsanitized label plus sanitized text requires either
restructuring `emit_decision` into a two-argument form or adding a second emission site, which
breaks `EDMV4-T13`'s single-emit-point contract pinned at `wave8-smoke.sh:7877,7891`. Neither
surface is named. AC7's "the label is unsanitized" is unobservable (the label is EDM's own ASCII
literal, and CC5 plus T52's byte scan guarantee the sanitizer would not alter it -- an assertion
that an all-ASCII string survives an ASCII filter cannot fail); and "the message half is sanitized"
is **already true upstream** -- `hookify_emit_match` runs `hookify_scrub` (`:226`) over id, action
and message before printing, with the header at `:409-413` stating "so neither downstream consumer
ever has to sanitize a second time" -- while AC7's control tests the label, leaving the
sanitization clause with no control at all (CC1 breach). Behaviour for MORE THAN ONE matched rule is
unspecified: hookify emits one line per match and AC6 requires a label "naming the rule id and
file", singular. AC10 inverts what it enforces: `NOTICE` contains no reused text, it is the CLAIM
about reuse (`:27-33`), so as written AC10 requires amending the claim first; and the premise looks
vacuous because hookify denials route through `emit_decision` (`edm-gateguard:651`) and never touch
`gg_build_facts()`. R10 states this correctly; AC10 does not. AC8 puts CA-196's disposition inside
EDMDS-02's AC, making it a **fifth** in-scope item against 3.2's three and Sec.2's "a fourth".

**AD-DS5 is over-broad, and the SRD violates it in four of its own AC.** AD-DS5 says without
qualification "no requirement's AC may be satisfied by writing a sentence". EDMDS-03's **entire** AC
set is three `decisions.md` records, and EDMDS-05 AC1 is a fourth. The requirements are legitimate
-- a ratification has no code deliverable -- so the RULE is what needs narrowing: no AC may offer
writing a sentence as an ALTERNATIVE to work that is otherwise specified. Then add the mechanical
half the plugin already uses: assert `decisions.md` contains the named identifiers (`D26`,
`EDMTC-T04`, `EDMV4-T45`).

**EDMDS-04**: AC3 calls `README.md:342` a live falsehood and requires it corrected. **It is true.**
`:342` reads "Kill switches for all three consumers:" followed by `export EDM_HOOKIFY=off`, and
`edm-stop-gate:95-100` honours both `EDM_HOOKIFY` and `EDM_HOOKIFY_DISABLED` -- as AC3's own next
sentence concedes. Executing AC3 as written replaces a correct sentence with an incorrect one.
Withdraw the README half (and 3.2's matching bullet); keep the CLAUDE.md stale-paragraph removal.
AC4 mandates citing CLAUDE.md "by file and line", which is the exact form **CA-059 retired** --
CLAUDE.md's own Mermaid-budget passage records a prior line citation having "already drifted" and
is now cited by name. Five requirements in this initiative edit CLAUDE.md, so the cited line moves
WITHIN the initiative. Cite by section-heading string per D22.

**EDMDS-05**: AC1 names **three** cross-cutting ACs each carrying a literal four-script list, then
AC2 says "**whichever** cross-cutting assertion" -- singular, so converting one and leaving two
satisfies AC2 while `edm-bash-gate` still escapes twice. Make it plural and name all three. The
membership predicate for "derives the set live" is also unstated, and `bin/` holds **22 entries**
of which three are data files and three are sourced-only libraries; a naive `find bin -type f`
sweeps all six into an assertion meant for deliverable scripts.

**EDMDS-07**: AC3's control is false -- with both `_pass_dir` and `_manifest` present
(`bin/edm-state:5144`) the three existing checks run, and check (1) at `:5153-5165` downgrades for
every lens with no landed JSONL, so restoring only the manifest yields `partial` for a DIFFERENT
reason. Require the control to restore the manifest AND a valid `lens-L{N}.jsonl` per recorded
lens, and assert the absence of AC1's message specifically. AC7's disjunction is answerable
mechanically: `--na-lenses` members must be in `CONDITIONAL_LENS_IDS`, which holds only `L13`
(`bin/edm-state:5020-5022` hard-dies otherwise), so an all-lenses-N/A round **cannot exist** --
resolve it in the SRD text and reduce AC7 to pinning the `die`.

**EDMDS-08**: AC1 says "a subcommand" while AC4 requires narrowing `audit-round-complete`'s
refusal "so it does not also block this path" -- incompatible readings. That refusal is INSIDE
`cmd_audit_round_complete` (`:5073`), so a NEW verb never reaches it and AC4 is vacuous, while a
re-entry reaches it but collides with AC3. Name the subcommand and pick the shape. The subcommand
also has no name, no `--help` obligation, and no AC sweeping CLAUDE.md's `bin/` table -- whose
`edm-state` row reads "**42 subcommands**" and enumerates them. That literal count is the
CA-021/CA-022 stale-count class the plugin has been burned by twice. AC8's new state field likewise
has no row in CLAUDE.md's state-field table and no stated **C-4 rule when absent**, which that
table requires of every row.

**EDMDS-09** AC4: "rejected, **or** its double-count is corrected" is an unresolved disjunction
with two materially different observable outcomes, and it also decides whether AC1's "materialised"
scoping is right. Resolve to **reject**: every existing `--na-lenses` fixture passes a disjoint
13-plus-L13 pair, and `wave6-smoke.sh:3846` already establishes the die-at-round-start precedent.

**EDMDS-10** AC4 (two findings): **the project-scoped lock does not exist and the AC does not say
it must be built.** Every lock in `bin/edm-state` goes through `with_state_lock "$lockbase"` with
`lockbase="${f%.json}"` (`:848-851`) -- per-initiative, as AC4 correctly diagnoses -- and there is
no project-keyed primitive in that file. The nearest precedent is in a different script:
`edm-gateguard`'s `mkdir`-based `<checked-file>.lockd` (CA-083), which IS project-keyed. There is
also an unaddressed hazard: `with_state_lock`'s trap-depth guard dies on ANY nested acquisition
regardless of lockbase (`:1419-1430`), so building on it requires proving every marker-mutation
site sits outside an existing acquisition. Separately, AC4 covers **two of four** mutation sites --
it omits `_edm_marker_remove_if_matches` at `:3056` (a `phase-start` to a non-6 phase) and `:3655`
(`cmd_archive`), either of which can delete a live Phase-6 marker concurrently with a
reconciliation, the same fail-open outcome CA-075 names.

**[REUSE] EDMDS-02 AC6 vs EDMDS-14**: routing two new surfaces through the labelling shape by
RE-TYPING it creates sanitizer copies four and five, so EDMDS-14 AC2's "only one definition exists"
scan fails. EDMDS-02 is a `Must` and EDMDS-14 a `Should` with no stated ordering. Consume the shape
from a shared owner instead -- which also REDUCES `edm-gateguard`'s line count against CC7's one
line of headroom.

## P2 -- Minor (13)

EDMDS-01 AC4's hang concession is honest but never considers a test-side watchdog, whose rejection
was argued entirely against product code; `bin/tests/_harness.sh` has no timeout helper, so a wedge
is unrecoverable. AC5 and AC6 both describe a benign rule without saying whether they are one
fixture or two. EDMDS-02 AC1 undercounts the documentation surfaces -- `bin/edm-hookify:39-40`
documents the shape a third time -- and omits the `.archived/` caveat DoD item 6 raises for
`EDMV4-T11`. EDMDS-06 AC1's "a `lens` field matching the file's own N" is ambiguous between
`lens == 1` and `lens == "L1"`; the schema value is the string. AC5's empty-file control is already
satisfied by pre-change code (`bin/edm-state:5158`'s `-s` test) so it cannot fail against either
version. The Rejected block's cost objection to option C ("runs across 14 files on every round
close") does not distinguish the options, since option B does the same; keep the drift-surface half
only. AC7's "stays within `jq`" does not constrain the shape, and the candidates differ by an order
of magnitude in exec count. EDMDS-07 AC5's "amended **or shown unaffected**" is a residual
disjunction whose second branch is satisfiable in prose. EDMDS-08 AC7's "not the latest" needs an
ordering key named (the `round` number, not `completed_at`). EDMDS-09 names no AC for
`wave6-smoke.sh:3865-3868`, which asserts `lenses | length == 14` -- in fact unaffected, but
EDMDS-07 AC5 sets the precedent that such sites are named even when unaffected. EDMDS-03 AC2's
reword is a real improvement but still verifiable only by its author. EDMDS-05 AC2's "so a seventh
script cannot escape" matches no count in the tree (22 entries; the three ACs name four, making
`edm-bash-gate` the fifth) -- CA-021's own remedy is count-free phrasing. EDMDS-10 AC1's "in one
pass" has three readings and the structural fix satisfies only the weakest.

## Lane B -- v1.0.0 verification

**11 of 16 fully fixed.** Fixed: P0-1 (path contract now changed first), P0-2 (AD-DS1 reversed, the
four-surface table correct against the code), P1-1 (exit 1, all four citations correct), P1-2
(CA-114 split legitimate under the vocabulary, no deferral), P1-3 (EDMDS-09 AC2 now genuinely
discriminating -- `bin/edm-state:4997-4999` materialises 14, subtracting `["L13"]` gives 13 while
the union stays `ALL_LENS_IDS`, so the array length is 14 unfixed / 13 fixed where `round_type` was
invariant), P1-7 (fabrication conceded, and adequate BECAUSE the requirement's stated purpose was
narrowed to "accidental non-delivery" in the same revision -- title and rationale now match the
concession, which is what v1.0.0 lacked), P1-8's message half (all three lines verified), the
EDMDS-03 negative-existential P2, the `CAMGAP` double-ownership P2, all three in-scope disjunction
P1s, R5/R6's split (**R6 and EDMDS-01 AC4 checked specifically for mutual consistency and found
consistent**), and AD-DS3's `audit_type` qualifier plus its copied-artifact residual.

Partially fixed: P0-5 (seven sites owned, three more unowned -- see P0-4), P1-4 (disjointness
reached but as an unresolved disjunction), P1-5 (AC6 exists but both its premises are wrong -- the
three fields are already stated verbatim in all 14 at `agents/edm-audit-logic.md:92`, and the
assertion it relies on does not exist), P1-6 (EDMDS-08 promoted to `Must`, but the coupling breaks
for a zero-findings lens), P1-9 (granularity corrected, lock nonexistent), P1-8's narrowing half
(possibly vacuous), D40's harder half (asked, but answerable mechanically).

**Three NEW disjunctions appeared** where the eight old ones were closed: EDMDS-07 AC5, EDMDS-07
AC7, EDMDS-09 AC4.

**On the CA-114 split specifically**: legitimate, not deferral wearing a label. The documentation
half is remediated against a header claim that really is false (`bin/edm-hookify:29-37`), and the
time-bound half is reclassified with a stated reason and no residual action -- exactly what
`docs/canonical-sections.md:19-23` permits. **No invented statuses anywhere in scope**: every
Finding block, Decision line and AC was checked for "descoped", "deferred", "accepted", "carried
forward" and equivalents, and none were found.

---

# Lane C -- Section 5, Epics 3-4 (EDMDS-11 through EDMDS-21, EDMDS-17, EDMDS-18)

**P0: 6 | P1: 18 | P2: 16 | NOTED: 12. Verdict: FAIL.** 11 requirements / 53 AC.

**14 of 18** in-scope v1.0.0 P1 items verified fixed. But the three requirements NEW in v1.1.0
introduced four of the six P0s, and two pre-existing ones reproduce the same
falsifies-shipped-assertions-with-no-owner class that failed v1.0.0.

Diagram errors vacuously clean: no diagrams in Epics 3-4.

## P0 -- Critical (6)

1. **[FACTUAL MISTAKE + FEATURE GAP] EDMDS-21 AC1 -- the remedy is scoped to a band containing none
   of the writes it must stop.** `wave6-smoke.sh` writes a Phase-6 marker at **nine** sites
   (`phase-start ... 6` at `:1404`, `:1823`, `:1999`, `:5264`, `:5289`, `:5462`, `:5513`, `:5597`,
   `:5883`), each reaching `_edm_marker_write` -> `edm_marker_path()` -> `edm_data_dir()`. The T06
   band spans `:1575-:1783` (`t06_restore_env` called at `:1783`). **Zero of the nine fall inside
   it** -- one precedes, eight follow. Verified directly. So isolating `CLAUDE_PLUGIN_DATA` in that
   band changes nothing, and the SRD's causal claim ("traced to its T06 band") is wrong about the
   mechanism: the band's `HOME` isolation only ever affected branch 3 of `edm_data_dir()`, and no
   band affects branches 1-2. AC1 and AC2 are then jointly unsatisfiable -- the extracted
   whole-suite guard fails on wave6, against DoD item 2. **Fix**: file-wide isolation at the top of
   `wave6-smoke.sh` (scratch `CLAUDE_PLUGIN_DATA`, `XDG_DATA_HOME` **and** `HOME` -- the shape
   wave8 uses at 93 occurrences and wave7 at 19), or isolate at each of the nine sites. `wave6` has
   **zero** `XDG_DATA_HOME` occurrences too, so isolating `CLAUDE_PLUGIN_DATA` alone still leaks on
   any host exporting `XDG_DATA_HOME`, which CC4's bash-3.2/Linux floor admits.
2. **[FEATURE GAP] EDMDS-19 AC3 -- a new subcommand falsifies two live-derived count checks.**
   `bin/tests/wave7-smoke.sh:1440-1451` (T66 AC3) derives the dispatch-arm count live
   (`grep -cE '^  [a-z][a-z0-9_-]*\)[[:space:]]+cmd_'` over `bin/edm-state`) and hard-fails when it
   differs from the first "N subcommands" figure in `CLAUDE.md`; `wave6-smoke.sh:4456` carries an
   independent copy. T66 AC3 also asserts **membership** in the `## bin/ helper scripts` table, so
   a count bump alone is insufficient. `CLAUDE.md` says 42 and `README.md:363` says 42. T26's
   Target Components omit `CLAUDE.md` entirely. **Fix**: an AC sweeping the table (count and row)
   and `README.md:363` in the same commit. **The same trap applies to EDMDS-08 AC1's promotion
   subcommand** -- flagged across lanes.
3. **[FEATURE GAP + COMPETING REQUIREMENTS] EDMDS-15 AC1 -- collapsing the five hook blocks
   falsifies roughly forty shipped assertions with no owner.** `hooks/hooks.json` carries five
   matcher-keyed entries (`:15`, `:28`, `:41`, `:54`, `:67`). Broken by a collapse:
   `wave6-smoke.sh:1440-1446` asserts hooks.json has **exactly 10** `gate-check` mentions (5
   command + 5 prompt); `wave7-smoke.sh:7746-7776` (CA-253 G8) loops the five literal matchers and
   extracts each by `select(.matcher == $m)`, six checks per matcher; `wave7-smoke.sh:7790+`
   (CA-298/G1) extracts and **executes** each of the five; `:7914`, `:7938`, `:7994` extract
   per-matcher command and prompt hooks again. All return empty under one collapsed entry. No AC in
   EDMDS-15 and none in T23 owns the amendment, and `wave6-smoke.sh` is absent from T23's Target
   Components. Exactly the class that produced v1.0.0's P0-5. **Fix**: the EDMDS-07 AC4/AC5
   treatment -- name each band by line, state the amended expectation, record the old one.
4. **[FEATURE GAP] EDMDS-19 AC5, AC6 -- the tightening is inert for its own target population.**
   `_edm_datadir_owned()` (`bin/_edm-datadir-lib.sh:110-137`) tests in order: not-a-directory
   (`:113`), **`.edm-owned` present (`:115`)**, `run/` or `patterns/` present (`:127`), empty
   (`:131-135`). AC5 tightens only the third arm. But a polluted directory acquires the sentinel on
   its first post-3.3.0 write: `edm_data_dir_claim()` is called by `_edm_marker_write`
   (`bin/edm-state:98`, i.e. every `phase-start 6`) and by `cmd_update_patterns`
   (`bin/edm-state:6359`, the very command that produced the leak). Verified directly. So for any
   affected user who has used EDM since upgrading -- the normal case -- **the tightened clause is
   never reached and nothing changes**. Worse, AC6's new assertion passes on a sentinel-free
   fixture while the real population stays broken: an assertion green while the defect persists.
   `upgrade-path.md:29-36` prints the arm order and still asserts the verdict flips. **Fix**: AC5
   must cover the sentinel arm -- accept `.edm-owned` only when the directory otherwise contains
   nothing that is not EDM's -- or have AC1's detection drive the report rather than the resolver,
   with AC6's fixture matrix including the sentinel-bearing polluted case as a named arm.
5. **[FEATURE GAP] EDMDS-20 AC1 -- an age-based `run/` sweep deletes a live Phase-6 marker,
   re-creating the defect EDMDS-10 exists to fix.** A marker is written once, at `phase-start 6`,
   and never refreshed; Phase 6 for a Large initiative is budgeted at 24-48h by CLAUDE.md's own
   timing guidelines. Any age threshold below a real Phase 6's duration unlinks a live marker, after
   which `edm-gateguard:102-104` allows every Edit and Write -- "a security control turning itself
   off", EDMDS-10's own words. **CA-105's title states the discriminator the finding actually asks
   for**: "no sweep for keys whose **project directory no longer exists**" -- not age. EDMDS-20
   substitutes a different policy with no rationale, and `edm-gateguard:106-110` (EDMV4-T15 AC11)
   already implements the existence test against the marker's own recorded absolute
   `initiative_dir`. **Fix**: key the `.phase6` sweep on the recorded `initiative_dir` no longer
   existing, never on age alone. Note the project key is **not invertible**
   (`edm_project_key()` maps both `/` and `.` to `-`, `:182-183`), so the existence test is
   available only for `.phase6`, whose content carries the path -- state the per-entry-type policy.
6. **[COMPETING REQUIREMENTS] EDMDS-19 ordering -- "detect, then migrate, then tighten" is enforced
   only as commit order inside one release, which is not the ordering the rationale needs.** The
   rationale calls the ordering load-bearing because tightening first makes a user's library vanish
   from view. The only enforcement is T27 AC5 (land after T25 and T26) -- all three land in one
   initiative, hence **one version bump**. An affected user upgrading receives detection, migration
   and tightening simultaneously: the first post-upgrade run relocates their data root and the
   report arrives after the fact. `upgrade-path.md:100-102`'s claim that a non-migrated user "gets
   the report, not silent relocation" is self-contradictory -- under the tightened rule
   "EDM footprint plus foreign content" IS the refuse case, which is the relocation. **Fix**: gate
   the tightening behind an explicit operator action or a later release than detect-plus-migrate and
   say so in an AC; or drop the ordering claim and require the resolver to keep using the polluted
   root while reporting, until the operator migrates -- ownership by consent rather than by silent
   relocation.

## P1 -- Significant (18)

**EDMDS-11** (six findings): AC6's "`_edm-datadir-lib.sh` is unchanged" is **falsified by three
sibling requirements in the same epic** -- EDMDS-19 AC5 modifies `_edm_datadir_owned()` in that
file, EDMDS-20 names it, and EDMDS-14 names it as a candidate sanitizer home. As written AC6 is
unsatisfiable; as a diff check it hard-fails. Narrow it to "`edm_project_key()`'s resolution chain
and its documented no-git contract are unchanged". AC8 **cannot fail** -- given AC6 the key is
unchanged by construction -- and has no control; make it a characterization test with a mutant
control. A **second** CLAUDE.md passage becomes false and nothing sweeps it: `:991-998` states the
project root "is resolved exactly the way `check_permission_rules()` already resolves it" and lists
three steps with no cross-check, already stale and made flatly wrong for `edm-hookify` by AC1;
AC7 sweeps only `:1345`. **The `NOTED`'s stated reason is materially overstated**: the cross-check
is not indivisible -- one `git rev-parse` (`:1175`, an external binary) plus two
`cd ... && pwd -P` subshells (`:1179-1180`, builtins only) -- and `_edm-datadir-lib.sh:52-57` states
this library's budget explicitly as "invokes no external binary ... not forks no subshell", while
`edm_project_key()` already forks (`dir="$(pwd)"`, `:178`). So the **physical-path half is
affordable**, passes `EDMV4-T17 AC7`'s failing-`git` stub, and closes a failure the two stated
reasons do not address: a NON-HOSTILE writer/reader key divergence (logical vs physical path)
yields two keys for one project and silently disables the Phase-6 gate -- which AD-DS4 itself names
as the exact failure EDMDS-10 exists to fix. Either apply `pwd -P` normalization inside
`edm_project_key()` (one subshell, zero external binaries) and narrow the `NOTED` to the
git-containment half, or record why a partial cross-check is rejected. Finally, **the new exec
lands on the highest-frequency surface in the plugin and is not analyzed**: `bin/edm-bash-gate`
invokes `edm-hookify eval bash` on every Bash tool call in every session, and
`resolve_project_root()` (`:141-151`) runs before rule discovery -- so a repository with zero rule
files, which CLAUDE.md advertises as costing nothing, would newly pay `git rev-parse` plus two
subshells per Bash call.

**EDMDS-12**: AC1 and AC2 are **jointly unsatisfiable**. `cmd_active_initiatives`
(`bin/edm-state:4243-4259`) prints `printf "  %-12s  phase=%d  last_updated=%s\n"` plus sentinel
lines -- the same shape, `phase=` token included, that `edm-repo-readiness:178` scrapes off `list`
today. Retargeting the awk satisfies AC1 and violates AC2. AC2 also binds `edm-stop-gate`, which
must parse the same output. Add an AC requiring a machine-readable emission
(`active-initiatives --porcelain`, bare prefixes, no sentinel) and add `bin/edm-state` and
`bin/edm-stop-gate` to Target Components.

**EDMDS-13** AC6: the stated reason for adding no gitignore coverage **contradicts CA-100's own
condition**. CA-100's title is "...with no gitignore coverage; **an absolute CLAUDE_PLUGIN_DATA
inside any git tree** makes both files untracked" -- the finding's premise is exactly the case AC6
denies. Independently, `cmd_update_patterns` has three write branches
(`bin/edm-state:6375-6411`), and branch (b) at `:6402-6404` appends into the **git-tracked**
`plugins/edm/docs/audit-patterns/{type}-audit.md` whenever no data directory resolves. Restate the
decision honestly: EDM never CHOOSES a path inside a repository, a host that points
`CLAUDE_PLUGIN_DATA` into a git tree is outside EDM's control, and a `.gitignore` in a repository
EDM does not own is not EDM's to edit -- and record branch (b) explicitly.

**EDMDS-14** (two findings): **a fifth class of dependent site.** `cahk_mutant`
(`wave8-smoke.sh:8569-8578`) copies only `_edm-cli-lib.sh` beside its mutant -- and `cahk_mutant`
builds the very mutants at `:8996` and `:9027` that AC4 owns. If the sanitizer moves into any NEW
`_edm-*.sh`, those mutants source a file absent from the scratch directory. `p2g1_mutant_bin`
(`:10603-10609`) documents this precise hazard and its fix: it copies EVERY sibling `_edm-*.sh`,
because "a two-library copy yields a mutant that dies at its own `source` line, and a control built
on it then reports 'the mutant produced no output', which reads like a discriminating negative
result while actually proving nothing". So "the four live sites" is complete for the LITERAL, not
for the extraction. Add an AC requiring every mutant/fixture helper that stages a consumer
(`cahk_mutant`, `w8_mutant_bin`, and the explicit `cp` sites at `:9585`, `:9838`, `:11730`,
`:12940`) to copy libraries by the `_edm-*.sh` glob. Separately, **extraction creates a new
fail-open path with no stated posture**: the in-tree guarded-sourcing precedent degrades silently
(`edm-gateguard:88-96` -- unreadable library means no gate at all), and for a SANITIZER that means
untrusted rule text reaching a model-facing channel unsanitized. Require the owner to be sourced
unguarded (fail-closed) with an assertion that a missing library aborts rather than emitting raw
text.

**EDMDS-15** AC1: no mechanism is named by which one collapsed entry recovers which of the five
commands fired. The only difference between the bodies is the gate token, and the shipped hooks read
only `$ARGUMENTS`, which carries arguments and not the command name. Whether the
`UserPromptExpansion` input exposes the invoked command is **unverified** (no execution available).
T23's Target Components hint at a different design -- extract the shared body, keep five thin
matcher entries -- which AC1's "the blocks are collapsed" forbids. Decide and state which; if a
true collapse, require runtime verification of the input field first, per the Spike A / D25
precedent for exactly this kind of hook-shape claim.

**EDMDS-16** AC1: dropping `set -e` from a 659-line script written under it is not a no-op, and no
AC audits the sites that relied on it. CA-077's history is direct evidence that unguarded
non-zero-capable commands existed on the gated path and were made explicit BECAUSE `-e` was in
force; with `-e` removed, any remaining one continues past a failure instead of aborting. AC3/AC4
test only the injected-error-before-print case. Add an AC enumerating the gated path's
non-zero-capable commands, plus a check that no assertion in `wave8-smoke.sh`'s CA-077 band
(`:11087+`) becomes vacuous once abort semantics change.

**EDMDS-19** (three further findings): **both named surfaces require an initiative to exist, and
the affected population may have none.** `cmd_validate` takes a mandatory PREFIX (`:4392`) and
reports per-initiative, so a host-global condition is reported N times for N initiatives and zero
times for none; `cmd_session_start` returns early when `SRD_ROOT` is absent (`:4703`). CA-134's
population includes projects with no `SRD/` at all, and AC7's recorded limit covers only "users who
never upgrade". Add a prefix-free surface (a `check-data-dir` subcommand, or a line in
`edm-repo-readiness`) -- but **not** wired into `edm_data_dir()`, which is on the zero-exec fast
path. Separately, **"the correctly-resolved destination" names no mechanism**: `edm_data_dir()`
returns exactly one path, and until AC5 lands that path IS the polluted root, so report and
migration would name source == destination; post-tightening the inverse holds. Either way a
"resolve as if `CLAUDE_PLUGIN_DATA` were not owned" entry point is required and no AC requires it.
And **the EDM-name set is never enumerated normatively**: AC3 treats `patterns/`, `run/` and any
`edm/` subtree as EDM's, while `upgrade-path.md:52` lists `.edm-owned`, `run`, `patterns` --
omitting `edm`. Depth is unstated too: under a recursive reading `patterns/code-audit.md` is not an
EDM name and AC6's fixture would be REFUSED; only a top-level reading makes AC6 true.

**EDMDS-20** (three findings): AC1's "a stated age ... on a stated trigger" **states neither** --
the same defect v1.1.0 fixed one requirement earlier, where EDMDS-13 AC4 was rewritten because "a
documented cap" with no value is satisfiable by documenting one million. AC1 also says "marker
entries" where CA-105 names a **triple** (`.phase6` + `.checked` + `.denials`), and
`.checked`/`.denials` are live session state, so sweeping them re-arms first-touch denials and
resets the per-session budget. AC5's control is **unimplementable as written**: on a fixture whose
only content is `run/`, removing `run/` leaves an EMPTY directory, which the emptiness arm at
`:131-135` **accepts** -- ownership is not lost, so the control cannot demonstrate what it claims;
and once EDMDS-19 AC5 lands, foreign content makes the directory refused whether or not `run/` is
present, so `run/` stops being the discriminator at all. **AD-DS4's motivating claim is false
against the code**: `:127` tests directory **existence**, not entry count, so emptying `run/` while
keeping the directory PRESERVES ownership. AC4 is the right fix reached for a reason that does not
hold -- and the stated reason is what a Gate 2+3 reviewer weighs. Restate as "removing the `run/`
**directory** loses ownership; emptying it does not". Finally, EDMDS-20 **introduces a second
retention owner over one directory, unacknowledged**: `edm-gateguard` already sweeps its own
`<key>.checked` past 30 minutes, and CA-085 hardened that unlink to re-read the mtime immediately
before removing so a concurrent refresh is read rather than deleted. A second sweeper on a different
policy is the duplicate-owner class EDMDS-14 and EDMDS-15 exist to remove, reproduced inside the
initiative that removes it. State which owner sweeps which entry names, and reuse CA-085's
re-read-before-unlink pattern.

**EDMDS-21** AC2: **the extraction has no home, and the shipped mechanism is not one helper.**
Verified at `wave7-smoke.sh:10185-10230`: the guarantee is a PAIR -- a start-of-suite snapshot into
`WAVE7_HOST_DATA_BEFORE` plus an end-of-suite comparison -- over three suite globals
(`WAVE7_HOST_DATA_DIR`, `WAVE7_HOST_DATA_BEFORE`, `WAVE7_HOST_DATA_CONTROL_NAME`) and the helper
`_wave7_datadir_snapshot`. Both suites source `bin/tests/_harness.sh`, the only plausible home, and
T29's Target Components list only the two suite files. **CA-063's own defect, inside the initiative
chartered to close it.** Name `_harness.sh` and specify both entry points plus the shared snapshot
function.

**EDMDS-17** (two findings): **`resolved_commit` has no mechanism anywhere, and the SRD does not say
so.** Grep across the repository: it appears only in EDMDS's own documents and in
`SRD/.archived/edm/EDMV4__ecc-integration/code-audit/findings-ledger.jsonl`, agent-written by
`edm-audit-synthesizer`. **No `bin/` script reads or writes it**, and
`inherited-findings.jsonl` has no such field -- its per-line schema is `schema, id, sev, status,
confidence, lenses, file, line, component, title, raised_round, resolved_round`. AC5 covers terminal
**status** only, so a remediated finding with an absent or fabricated `resolved_commit` still
passes; the "mechanical backing" AD-DS5 promises is not delivered. Extend AC5 to require a
non-empty `resolved_commit` that resolves in git (`git cat-file -e`), name the hosting file, and
cite the `spec_swept` precedent for additive-field-with-default treatment so `schema:1` need not
bump. Separately, **the closure obligation binds only the eighteen inherited findings.**
`inherited-findings.jsonl` contains exactly CA-063, 072, 074, 075, 089, 090, 091, 100, 103, 105,
106, 109, 112, 113, 114, 116, 121, 122 -- **CA-134 is not among them**, and EDMDS-21's item has no
CA id at all. AC4/AC5 quantify over "every inherited finding", so EDMDS-19's residual, EDMDS-21's
item and 3.2's README item are invisible to the very check that exists to stop closure being claimed
with something open. Quantify over "every finding in scope per 3.2" and give the three added items
ids.

## P2 -- Minor (16)

EDMDS-11: two parity-claim sites, one named -- `bin/edm-hookify:25-27` (the `--help` region, which
is what CA-109's title actually names) and `:139-140` (a comment); AC3 still does not name the
observable outcome, and `_resolve_permcheck_project_root` does not "reject" a disagreeing value --
it prefers the toplevel and warns naming both paths (`bin/edm-state:1186-1187`), which
`wave6-smoke.sh:1670-1702` already asserts along with `enforcement=prose-only`, so extend that band
rather than authoring a new one; eight AC in one `M` ticket against the three-ticket treatment its
sibling gets. EDMDS-12 AC3: "both paths agree" on a phase-0/phase-7-only fixture is agreement on the
empty set, which an always-empty broken accessor also satisfies -- add an in-range initiative.
EDMDS-13: AC4's `date:` ordering has no stated value format (`docs/audit-patterns/README.md:40` is
the placeholder `date: {date}`, so lexical ordering is not guaranteed safe); AC1 does not scope the
re-keying to the data-directory branch, and re-keying branch (b) would create per-project
subdirectories inside the plugin's own git-tracked `docs/audit-patterns/`. EDMDS-14: AC1's "all
three call sites" is falsified by its own AC5, which makes four -- the unfixed remnant of v1.0.0's
literal-counts P2; the CC2 self-match exclusion has in-tree precedents not cited
(`wave6-smoke.sh:1463-1464` builds the needle from parts, `_edm-datadir-lib.sh:63-64` deliberately
does not spell a token); **the natural owner is `bin/_edm-cli-lib.sh`, which all four consumers
already source unguarded** (`edm-gateguard:52`, `edm-stop-gate:65`, `edm-bash-gate:69`,
`edm-hookify:104`), whereas T21 proposes `_edm-datadir-lib.sh` -- sourced GUARDED, not sourced at
all by three of the four, and asserted unchanged by EDMDS-11 AC6; and AC4 perturbs the same two
assertions as EDMDS-02 AC6/AC7 with no ordering relation (T22 depends on T21 but not T06).
EDMDS-15 AC2's "derived from the skill list live" names no source yielding exactly the five gated
skills (`skills/` holds 14). EDMDS-16 AC2 writes "four consumers" into a document where "three
hookify consumers" is load-bearing and simultaneously being corrected by EDMDS-04 AC3. EDMDS-19
AC1's three-part payload strains the one-line contract two consumers parse
(`edm-repo-readiness:226-234` reads `class` and `type` as fields 1 and 2; `edm-stop-gate` collapses
informational anomalies to a count, which a multi-line anomaly inflates). EDMDS-21 AC2/AC3 leave
placement and control scope unstated -- AC2 does not require wave6's `end` call to be the last
thing the file does, and AC3 conflates the guarantee's scope with the control's, since the shipped
control writes, detects and removes within one assertion (`:10207-10225`). EDMDS-17 AC2's D51 mark
edits `SRD/.archived/edm/EDMV4__ecc-integration/decisions.md:65`, which 3.3 puts partly out of scope
and DoD item 6 flags as lint-excluded, and the AC names no file. EDMDS-18 AC1 never says where a
reservation lives, and a release leaves a stale in-tree comment nothing sweeps --
**`bin/tests/wave7-smoke.sh:3739`** states "contrast EVALB, CAMGAP, LINUXV and EDMRT, which this
initiative did reserve because real work remained behind each", which becomes false on release, and
that file is absent from T31's Target Components. It is a comment, not an assertion, so nothing
fails -- which is exactly why it will be missed.

## Lane C -- v1.0.0 verification

**14 of 18 in-scope items fixed.** Notably: P0-3 and P0-4 both fixed -- AC1 scopes the cross-check
to `edm-hookify` and AC6 preserves `edm_project_key()`, and `edm-gateguard:98`/`:102-104` exits
before any hookify call so the exec no longer lands on the marker-absent path (new residual filed:
it lands on `edm-bash-gate`'s every-Bash-call path instead). P1-10 fixed with the phase-0/phase-7
fixture matching CA-112's own divergence. P1-12 fixed by requiring **extraction** rather than
re-authoring. P1-13, P1-14, P1-15 (all four sites owned), P1-16 (character set, verified exactly
three occurrences plugin-wide), P1-17, P1-18 all fixed. The `CAMGAP` double-ownership and the CC2
self-match P2s fixed. EDMDS-13's three-way split verified **coverage-intact**: all 18 ids in
`inherited-findings.jsonl` map one-to-one across the SRD, no orphan and no double owner.

Partially fixed or fixed defectively: P1-11 (AC2 states the obligation but the accessor is itself
human-readable), the AC3 vagueness P2 (re-filed), the backward-compatibility P2 (AC8 added but
cannot fail), the literal-counts P2 (EDMDS-15 fixed, EDMDS-14 AC1 not), and the `run/` P2 (AC4 added
but on a false premise, with an unimplementable control).

## Lane C -- NOTED (12)

EDMDS-19 AC6's factual claim verified -- `wave8-smoke.sh:10302-10308` builds
`${dir}/patterns/code-audit.md` and nothing else, so it does still adopt under a top-level
"EDM names only" reading. EDMDS-14's corrected count verified (three copies, not five) and its four
dependent sites verified at the exact stated lines, with four confirmed **complete for the literal**
-- `LC_ALL=C tr -c` has 7 occurrences plugin-wide (3 in `bin/`, 4 in `wave8`), the character set has
3, all in `bin/`, and the other `tr -c` hits (`wave8:4141`, `:6265`, `:6283`) are unrelated label
sanitizers. EDMDS-14 AC5's premise verified: `edm-bash-gate` has no sanitizer of any kind.
EDMDS-16's four `set -` postures verified exactly as stated, and no shipped assertion pins
`set -euo pipefail` in `edm-gateguard`. EDMDS-21's occurrence counts verified exactly:
`CLAUDE_PLUGIN_DATA` = 0 in wave6, 93 in wave8, 19 in wave7, 3 in timing. EDMDS-15's premise
verified against CA-121's own component list. EDMDS-12's premise verified. EDMDS-11 AC7's target
verified. **The `NOTED` reclassification of CA-109's marker-key half is legitimate in form** -- a
permanent, stated trade-off with a bounded residual, not deferral relabelled; the P1 concerns the
completeness of its stated reason, not the status choice. CA-106's "four hook consumers" wording is
the finding's own. No i18n/l10n or WCAG obligation arises in this scope.

## Lane C -- not audited

EDMDS-13 AC2/AC3/AC5 swept for falsifiability but the compatibility read path and append-loop
implementation were not read, so whether "read in place" is as cheap as claimed is unverified.
EDMDS-15 AC3/AC4 individually -- the Gate 3.5 determination was not researched. EDMDS-16 AC5
individually. EDMDS-17 AC1/AC3 taken at face value. EDMDS-18's substantive question is a judgment
for the gate. **Execution-dependent, all unverified**: `run-all.sh`'s current count against the 4048
baseline; whether the extra `git` exec measurably moves the `edm-bash-gate` path; whether the
`UserPromptExpansion` input exposes the invoked command name (load-bearing for the EDMDS-15 AC1
finding); which of `edm_data_dir()`'s three branches produced this host's 85 markers; and
`bin/edm-gateguard`'s line count against the 660 bound.

---

# Lane A -- Sections 1-4, 6, and architecture.md

**P0: 3 | P1: 18 | P2: 14 | NOTED: 9. Verdict: FAIL.**

**All three of the prior round's P0s in this lane are genuinely fixed**, and the reversal of `AD1`
into `AD-DS1` is correct on its load-bearing premise: exit 2 plus stderr IS the model-facing refusal
channel for a `PreToolUse` hook, and `bin/edm-stop-gate:120-124` really is a label-and-sanitize
mechanism, shipped and pinned. Most of the prior round's 18 P1s and 15 P2s are closed. FAIL is
driven by three new items.

## P0 -- Critical (3)

1. **[FACTUAL MISTAKE / REUSE] `architecture.md` -- the sanitizer decision rests on a false claim,
   and the document on disk is stale against a correction this initiative has already recorded.**
   `architecture.md:52-53` states that `edm-hookify`, `edm-bash-gate` and `edm-stop-gate` "source
   nothing today" and concludes "no option avoids adding a sourcing statement to two or three
   scripts". All four hook consumers already source `_edm-cli-lib.sh` (`edm-gateguard:52`,
   `edm-hookify:104`, `edm-bash-gate:69`, `edm-stop-gate:65`, `edm-state:65`), joined by twelve
   more `bin/` scripts. The cascade is why this is P0 rather than P1: the whole new-component row
   `bin/_edm-sanitize-lib.sh` and the "exactly one new file" claim are unnecessary; R-A1's
   "EDMDS-14 is net plus four to six" is wrong, since extraction removes `edm-gateguard:213` and
   adds nothing, making EDMDS-14 net **negative**; therefore "the sum crosses 660 at EDMDS-14" is
   wrong and **EDMDS-02 is the first crossing**, which defeats the stated purpose of the fixed
   ordering (take the bound decision before EDMDS-02 is written) -- under corrected arithmetic the
   decision must be taken DURING EDMDS-02; R-A1 option 2's sole objection ("the file stops being a
   sanitizer library and becomes a refusal-emission library") evaporates because `_edm-cli-lib.sh`
   is already a general CLI library; and the Rejected Alternatives table never lists
   `_edm-cli-lib.sh` at all. `pending-v1.2.0.md` A1/A2 already record this correction, dated the
   same day -- so `architecture.md` is stale against the initiative's own established facts, in the
   document Sec.1 and Sec.4 delegate to. **Fix**: retarget to `_edm-cli-lib.sh`; delete the
   new-component row; re-derive R-A1's arithmetic (659, EDMDS-16 net 0, EDMDS-14 net negative,
   EDMDS-02 +10..30 -- still a certain breach, attributable to EDMDS-02 alone); restate the
   ordering rationale; list `_edm-cli-lib.sh` as the chosen option. Keep the `declare -F`
   fail-closed design, but note `_edm-cli-lib.sh` is sourced **unguarded** at all five sites,
   unlike `_edm-datadir-lib.sh`.
2. **[FEATURE GAP] Sec.3.4 item 6, R3, `architecture.md` R-A1 -- the 200-660 bound is a LIVE
   assertion and nobody owns amending it.** `bin/tests/wave8-smoke.sh:4055-4060` is
   `t11_lines="$(wc -l < "$GATEGUARD" | tr -d ' ')"` then
   `if [[ "$t11_lines" -ge 200 && "$t11_lines" -le 660 ]]`. Verified directly. All three documents
   describe amending the bound as an edit to `EDMV4-T11` AC1 under `.archived/` -- correct, and
   `edm-lint-artifacts`' `collect_md_files` does exclude `.archived/` -- and **none names the live
   assertion**. Precedent proves both edits are required: D42 and D47 each raised the assertion AND
   amended the epic file, and D47 records the failure mode of doing only one ("the epic file's AC1
   text still read 200-400, two revisions stale"). Because the breach is certain and DoD item 2
   requires zero failures, an unowned assertion edit is a **certain DoD failure**. The four
   "line count recorded after this ticket" AC record a number and change nothing. **Fix**: state in
   DoD item 6 and R3 that amending the bound edits TWO places -- `wave8-smoke.sh:4056` (live, and
   the reason `run-all.sh` would otherwise fail) and `EDMV4-T11` AC1 under `.archived/` (verified by
   reading) -- and name the assertion file in the owning requirement's Target Components. Sec.3.3
   already puts amending an assertion's expectation in scope, so only ownership is missing.
3. **[FACTUAL MISTAKE] `AD-DS1`'s channel table -- the model-facing premise is confirmed, but the
   complementary premise the branch decision actually turns on is unestablished.** Row 1 asserts
   json mode has "two -- stdout JSON to the model, **stderr to the operator**", but json mode
   `exit 0`s at `edm-gateguard:234`, and nothing in the SRD, `architecture.md`, `CLAUDE.md` or
   `decisions.md` establishes that a `PreToolUse` hook's stderr is surfaced anywhere on exit 0. If
   it is not, EDMDS-02 AC3 routes the author's `message` nowhere, AC5's control ("the same message
   IS present on stderr") passes at the process level while being false at the operator level --
   Goal 3's defect class -- and the "Cost accepted explicitly" paragraph understates the cost from
   "invisible to the model" to "invisible to everyone". Rows 2-4 assert "one" channel, but
   **stdout exists at all three surfaces and the table never considers it**; a hook exiting 2 could
   put the author's `message` on stdout and keep stderr EDM-authored -- precisely the "Separate"
   branch `AD-DS1` rules out at three of four surfaces. `AD-DS1`'s own principle is "where two
   channels exist, reduce the channel", so if stdout is usable the decision at three surfaces is
   wrong. Stated as **unestablished, not false** -- but v1.0.0 FAILED for asserting exactly one
   channel premise without checking it, and this plugin's precedent (D25 Spike A, D26 Spike B,
   CA-007's re-verification) is to settle host-behaviour questions by disposable-repo spike rather
   than by reading. **Fix**: run a D25/D26-style spike before Gate 2+3 and record two facts in
   `decisions.md` -- whether a `PreToolUse` hook's stderr is surfaced to the operator on **exit 0**,
   and whether its stdout is surfaced to the operator and confirmed NOT to the model on **exit 2**.
   Rename the column `Model-facing channels`, add a `Non-model-facing channel` column with the
   answers, and re-open the branch decision for rows 2-4 if exit-2 stdout is operator-visible.

## P1 -- Significant (18)

**Sec.2 (three findings)**: "CA-114's premise is disproved by measurement" contradicts its own
source -- `explorers/04:64` reads "**CA-114's premise is true and its conclusion does not hold on
this build**", and EDMDS-01 splits it exactly that way. What measurement disproved is the DoS
CONCLUSION. **"Six of the twenty-one requirements carry an explicit Rejected block" -- there are
five** (`srd.md:283`, `:328`, `:376`, `:398`, `:436`); verified. Five plus sixteen, not six plus
fifteen, and R8 repeats both figures -- the same class of checkable count v1.0.0 was failed for, in
the paragraph that withdraws v1.0.0's version of it. And "it both measures and recommends"
overstates explorer 04, which enumerates three options with costs and recommends none; EDMDS-01
makes the choice. "It both measures and frames the decision" keeps the concern and makes the claim
accurate.

**Sec.3.2 bullet 2 -- the named falsehood is not the falsehood, and the real one is missed.**
Grepping `bin/` for `EDM_HOOKIFY` returns `edm-bash-gate:89,92` and `edm-stop-gate:95,98` -- and
**nothing in `bin/edm-gateguard`**. So `edm-stop-gate` DOES honour the pair, making
`CLAUDE.md:1832-1833` false as the SRD says; but `edm-gateguard` does NOT, making CLAUDE.md's
**opening** claim ("Honoured by ALL THREE hookify consumers") equally false -- and the SRD treats
that opening claim as the true one. Following AC3 as written removes the stale closing paragraph
(right) and leaves CLAUDE.md and README asserting an unqualified false claim about a **safety
control**, in the requirement whose purpose is fixing false claims in those files. Exposure is
bounded: `EDM_GATEGUARD`/`EDM_GATEGUARD_DISABLED` (`edm-gateguard:31-32,84`) disable the whole gate
including hookify evaluation, so an operator has a bigger hammer but not the documented one. The
prior round's P2 stated this incorrectly and v1.1.0 propagated it without re-verifying.

**R3 vs `architecture.md` R-A1 vs `pending-v1.2.0.md` A2 -- one event, three incompatible
likelihoods inside one initiative.** R3 says "High -- one line of headroom"; `architecture.md:469`
says "the bound WILL be breached, and no ordering avoids it"; `pending-v1.2.0.md:45-46` says "the
breach remains a risk ... not a certainty". R3's Mitigation is conditional ("if 660 is exceeded"),
which `architecture.md` denies. On corrected arithmetic the breach is certain and attributable to
EDMDS-02 alone. Settle on one figure: R3 Likelihood becomes **Certain** (the vocabulary already
carries it at R1, R7, R11), Mitigation drops the conditional and becomes P0-2's two-file amendment
plus the sequencing.

**R7 and R8 -- R7's only mitigation is the thing R8 calls a risk, and neither row acknowledges the
other.** R7 (High/Certain) says "Mitigation is external: Gate 2+3's reviewer is the only independent
verifier"; R8 says twenty-one decisions in one gate round invites rubber-stamping. So the sole
mitigation for the highest-severity row is the control the next row says will not hold at this
volume. R7's citation of guard **D1** is fair, and its second half (the multi-lane Phase 3 audit) is
a real delivered control -- but R7 is the only row naming no owning AC or DoD item, and its two
mitigation halves are not distinguished. Split them into "delivered" and "assumed",
cross-reference R8, and give R7 one checkable obligation -- e.g. that Gate 2+3 ratify `AD-DS1`
through `AD-DS5` individually with a per-decision recorded verdict rather than as a block, which
mitigates R8 in the same stroke.

**Sec.3.4 item 1 reintroduces at DoD level the exact disjunction `AD-DS5` removes at AC level**:
"all acceptance criteria satisfied and evidenced, **or** its finding is reclassified `NOTED` with
the reason recorded". `AD-DS5` says of that shape that choosing at implementation time is the
descope authority `canonical-sections.md:118-123` reserves to a human at a gate -- verified: those
lines read "the implementer cannot descope an AC by declaring it unverifiable -- only a human, at a
gate". Item 1 carries no gate qualifier, so as written an implementer discharges any requirement by
writing a `NOTED` sentence. Both intended reclassifications are already decided in the SRD, so the
open-ended escape buys nothing.

**Sec.3.4 item 2 -- the threshold is ambiguous the moment the item's own remediation runs.** It
requires "4048 or above" AND that the baseline be re-measured and re-anchored as the first act of
Phase 6. If the re-measured figure is 4102, two developers disagree about whether the threshold is
4048 or 4102. Deferring the measurement is sound; the defect is the threshold. Recommend: the
re-anchored figure becomes the DoD threshold and 4048 becomes the regression floor, with a measured
figure below 4048 a hard refusal pending a gate decision, not an explanation.

**Sec.6 missing row / Goal 2 -- the CA-114 `NOTED` rests on an assumption explorer 04 explicitly
declines to establish, and no risk row carries it.** `explorers/04:91-93`: "Whether a pattern exists
that defeats Oniguruma's retry limit on this build. Three classic catastrophic shapes were tried at
input lengths to 10,000; **absence of a counterexample is not proof of its impossibility**." R5
covers a future `jq` raising the limit and R6 removing it; neither covers a pattern defeating it on
the CURRENT engine, which is the primary unestablished claim and the one the reclassification
depends on. Goal 2 is directly engaged.

**`architecture.md` Rejected Alternatives / R5 -- the cheap third option its own source flags as
uninvestigated is never considered.** The row rejects a complexity heuristic and a
`sleep`-plus-`kill` watchdog. `explorers/04:94` records: "Whether the retry limit is **configurable
per-invocation** from `jq`. Not investigated." If it is, EDM can pin the bound explicitly at
near-zero cost, removing the dependency-default residual and defusing R5 entirely, with no heuristic
and no watchdog. One `jq` invocation settles it.

**`AD-DS2` / EDMDS-11 AC2, AC7 -- two of three documentation sites AC1 falsifies are unowned.**
`bin/edm-hookify` carries **two** parity claims: `:139` and `:26-27`, the latter spelling out the
unchecked three-step chain and therefore the more wrong one after AC1. AC2 names only `:139-140`.
Third site: `CLAUDE.md`'s "Rule directory and discovery" section enumerates the identical chain, and
AC7 sweeps only `:1345`. Same Goal 2 breach shape AC7 exists to prevent. That section is **not** in
`edm-sync-canonical-sections`' generated seven, so no regeneration follows.

**`AD-DS2` / EDMDS-11's two-way split vs `architecture.md:164-168` -- a third residual has no
terminal status.** The split admits only remediated-or-`NOTED`, but after AC1 hookify still accepts
an unchecked `CLAUDE_PROJECT_DIR` outside a git worktree, so **rule discovery can still be
redirected in a non-git project**. Verified: `edm-state:1191-1193` sits inside the
`[[ -n "$proj_root" && -d "$proj_root" ]]` branch with the `[[ -n "$git_toplevel" ]]` guard around
the cross-check. Goal 1 and `AD-DS5` forbid leaving it statusless. State it in `AD-DS2`: hookify's
half is remediated **for the in-git case**, with the no-toplevel sub-case `NOTED` on the same two
bounds already given for the marker key. EDMDS-11 AC5 already pins the behaviour; only the status is
missing.

**`AD-DS1` row 1 -- the json-mode stderr emission is not required to be sanitized**, while every
other untrusted-text emission in this family is. `EDMV4-T52 AC6` exists precisely because `$reason`
reaches stderr from `edm-gateguard`, and `:202-213`'s comment records why. Row 1 says only "the
author's `message` goes to stderr"; AC7's label-and-sanitize obligation is scoped to AC6's two
sites. An unsanitized json-mode stderr write re-opens the control-byte exposure T52 AC6 closed.

**`AD-DS1` / EDMDS-02 vs `wave8-smoke.sh:7871-7895` -- EDMDS-02 adds a second untrusted-text
emission site inside `edm-gateguard` that falls outside the assertion pinning that file's
single-emit-point property.** The band runs
`t52_ordering_ok "$GATEGUARD" "emit_decision" "LC_ALL=C tr -c" '"$reason"'` -- it keys on the
literal `"$reason"` only. Once AC2 strips the author's `message` out of `$reason` and AC3 emits it
through a new variable, the new emission is invisible to the scan, and the positive control at
`:7888-7889` does not reach it either. The same unowned-shipped-assertion class the SRD carefully
owns for EDMDS-07 and EDMDS-14.

**`AD-DS1`/EDMDS-14 -- sanitizer extraction breaks the mutant HARNESS, not just the two sed
expressions, and the harness change is unowned.** `cahk_mutant`
(`wave8-smoke.sh:8569-8578`) copies `_edm-cli-lib.sh` then applies the seds **only** to
`edm-hookify`; the two dependent expressions neutralise `hookify_scrub` at `edm-hookify:225-226`.
Once that line becomes a call into a shared owner, the seds cannot reach it. Under the corrected
target the harness already copies the file, so the fix is "apply the sed to the copied library too"
-- cheap, but a harness signature change, not the "retargeted at the new single site" AC4 describes.
Under `architecture.md`'s `_edm-sanitize-lib.sh` the harness would not copy the library at all, and
its own `declare -F` fail-closed rule would make the CA-056 mutant controls at `:8999`, `:9011` and
`:9030` **fail** rather than no-op.

**Sec.3.4 missing item -- the DoD never re-measures the budget `AD-DS2` turns on.**
`edm-gateguard:657-658` records a second constraint on the marker-absent path: "allow path (marker
absent) targets 50 ms p95 over 20 samples, measured by `bin/tests/timing.sh --gateguard`". Three
requirements modify `edm-gateguard` and EDMDS-19 AC5 modifies the resolver reached from it -- and
AC5's tightening converts `_edm_datadir_owned()`'s conditional glob loop (`:131-135`, today reached
only when the `:127` clause fails) into an enumeration that runs on **every** resolution for any
install lacking the `.edm-owned` sentinel, on every Edit and Write, until it claims. No external
binary is added so `EDMV4-T07 AC8` is not breached literally, and the sentinel short-circuit bounds
the population -- but nothing re-measures the p95.

**Sec.1 -- the gate reviewer is not told v1.1.0 ships with known held findings.**
`pending-v1.2.0.md` holds A1 (P1), A2 (withdrawn, two surviving findings), A3, A4, A5 against
v1.1.0. Its version-freeze rationale is sound and holding is not deferral in the prohibited sense --
but the Revision History presents 1.1.0 as "Phase 3 remediation" with no mention of it, and Inputs
does not list the file. A1's correction is not yet reflected in `architecture.md`, which is P0-1.

**[DIAGRAM ERROR] `architecture.md` Diagram 2 -- the state machine admits a transition its own
requirement forbids.** `SP --> CP` (`:217`) merges "operator-requested partial" into the same `CP`
state as "downgraded from full", and the repair edge `CP --> CF` (`:222`) is drawn from that merged
state with no distinguishing guard. As drawn, an operator-requested lens-subset round can be
promoted to `full`, contradicting EDMDS-08 AC3 ("cannot promote a round that was never downgraded")
and the `round_type` union rule, since such a round's `lenses UNION lenses_na` is not
`ALL_LENS_IDS` by construction. The requirement text prevents it; the diagram does not, and the
diagram is what Sec.4 delegates the state detail to. Split `CP` into `CP_DOWNGRADED` and
`CP_OPERATOR`, with no repair edge from the latter.

**Sec.3.4 items 6-7, R3, `architecture.md` R-A1 -- "D42, D47, D49 precedent" is wrong on D49, in
four places.** Verified in the archived ledger: D42 widened the bound 400 -> 500; D47 widened it
500 -> 660; **D49 is CA-061 -- the verbatim-text contradiction and the `NOTICE`/clean-room
retraction -- and amended no bound.** It only records that condensing a comment "was necessary to
stay inside AC1's 660-line bound", i.e. it worked WITHIN the bound. `analysis.md:102-104` (CC7)
agrees: the bound "has been widened **twice** already (D42, D47)". Cite D42 and D47 only, and add
D47's own unused warning, which is the strongest available support: "660 against 652 lines is EIGHT
lines of headroom, so the next change of any size to this file trips it ... the next contributor
should expect to amend AC1 again and should record it, not nudge it."

## P2 -- Minor (14)

`architecture.md`'s Integration Points row claims each data-directory candidate is gated by both
`_edm_datadir_creatable` and `_edm_datadir_owned`; only the `${CLAUDE_PLUGIN_DATA}` candidate is
ownership-gated (`:146-147`), the other two by creatability alone -- which matters because it
implies EDMDS-19 AC5's tightening affects all three. Diagram 3's steps 12-13 are unreachable as
ordered, since the json arm `exit 0`s at `:234`, so the stderr write must precede the json emission.
`AD-DS1`'s "machine-pinned" overstates the band's scope: `wave8-smoke.sh:7922-7944` pins that
`stop_gate_emit_blocking` is defined once and that its two variables are never referenced outside a
call into it, but **not** that the label is unsanitized and the text sanitized -- so a future edit
collapsing the halves into one sanitized string would pass, and EDMDS-02 AC6 leaves the precedent
site's split with no assertion while AC7 adds one for the changed sites. EDMDS-14's four-site
paragraph misclassifies `:7891`: `t52_ordering_ok` returns 1 when the marker is absent, so `:7877`
hard-fails (good) but `:7891` is itself the positive control wrapped in `if ! t52_ordering_ok`, so
marker absence makes it **pass for the wrong reason** -- three of four fail silently-green, not two.
`AD-DS5` bullet 3's "mechanically checkable" rests on `resolved_commit`, which returns zero matches
across `plugins/edm/`, is in no schema and has no reader. Sec.3.1's "canonical status" and
EDMDS-17's "terminal status" are not terms the cited table defines -- it defines four SEVERITY
levels, and closure is expressed by `findings-ledger.jsonl`'s `status: "fixed"` plus `spec_swept`;
naming only, but it would let EDMDS-17 AC4/AC5 name a real field. DoD item 2 thins CC6, dropping
"across 8 suites" and "quiet tree" -- both matter, since seven suites could exceed 4048 while
violating CC6, and D50 records the last DoD run being reconciled per-suite precisely because a
`set -e` abort ends a suite green. EDMDS-01 AC4's inline comment points at R5 where R6 and
`EDMDS-T03 AC3` both say R6 -- two against one, and it matters because R6 is the hang row.
Diagram 2's `:205` states half the round-type rule (the `lenses_na` subset conjunct is missing) and
its `:214-215` superimpose two machines with no legend distinguishing superseded edges.
`architecture.md:388` cites `:117-119` where the comment spans `:116-119`.
**"Decision B" is still a dangling reference**, used at `srd.md:68` and `:227` and defined nowhere in
the file -- NOT FIXED from the prior round. `.edm-state.json`'s `artifact_hashes.srd` was recorded
at `2026-09-08T16:58:14Z`, i.e. against v1.0.0 before the rewrite; re-record before Gate 2+3.

## Lane A -- v1.0.0 verification

**All three P0s FIXED.** `L2-P0-1`: `AD-DS1` reverses the premise explicitly and cites
`edm-stop-gate:113-124`, verified. `L2-P0-2`: the Ticket List exists at `srd.md:874` with 31 tickets
carrying Size, Depends On, Target Components and AC. `L2-P0-3`: Goal 1 withdraws the fifth status by
name, Sec.5's legend is rewritten, DoD item 1 binds all priorities, and EDMDS-17 AC3 replaces
"descoped" with "split". A grep for `descope|defer|waive|BLOCKED|N/A-runtime` returns only
meta-references; `architecture.md` returns zero. **No fifth status survives anywhere in this lane's
scope.**

**Of the 18 P1 claims: 14 fixed, 4 partially.** Fixed: AD1's false claim, the CA-196 omission, the
single-author chain (R7 added, and `explorers/04:3` verified to read "Author: orchestrator, not an
`edm-explorer` agent"), the six missing carried constraints plus `analysis.md` in Inputs, the four
wave8 sanitizer sites, AD2's overstated asymmetry, AD2's CLAUDE.md contradiction, AD3's
`audit_type` qualifier and residual, AD4's `patterns/`-only naming, AD4 binding only Decision B,
R5's hang branch, the AD numbering collision, `architecture.md`'s absence, and the prose-only flow
decisions. Partially: R6's count (corrected, but the replacement is itself wrong), the eight AC
disjunctions (all spot-checked now single obligations, but DoD item 1 reintroduces the shape and
EDMDS-02 AC8 retains one), "record of closure" (pointed at EDMDS-17 AC4 but `resolved_commit` has no
reader), and R3's Mitigation (Impact coherently raised, but still a change-control procedure).

**Of the 16 P2 clauses: 12 fixed, 1 partial, 3 not fixed.** Not fixed: the dangling "Decision B"
reference, the `README.md:342` characterisation (and the original finding was itself wrong -- see
P1), and Sec.1's Branch row per the lane, though see the reconciliation below.

## Lane A -- NOTED (9)

`AD-DS1`'s model-facing premise **confirmed**: `edm-gateguard:236-240` is
`printf '%s\n' "$reason" >&2` / `exit 2`; `edm-bash-gate:135-138` and `edm-stop-gate:248` are the
same shape. `edm-stop-gate:113-124` **is** genuinely a labelling mechanism whose shape transfers,
with two live call sites both using `[EDM] <what happened>:`. `bin/edm-gateguard` independently
counted at **659** lines. **All three Mermaid diagrams are clean** under the canonical conventions
-- zero raw semicolons in any label, the one entity code `#59;` at `:113` in the correct
no-leading-ampersand form, every `;` inside a fence on a `classDef`/`style`/`class` line. The lane
traced `bin/edm-mermaid-rules.awk`'s `mermaid_is_violation()` (`:91` exempts `%%`, `:99` exempts
`classDef|style|linkStyle`, `:105` strips one trailing `;`) and `mermaid_strip_entities()`, and all
three diagrams pass; every node in Diagrams 1-2 carries a class, and Diagram 3's six participants
each sit in a coloured `box`, which is `sequenceDiagram`'s only styling mechanism. No orphan nodes.
`architecture.md`'s "Correction to the brief" is right: `edm-state:1179-1180` really is `cd`/`pwd -P`
builtins inside `$( )`, so the cross-check is one external-binary exec plus two forks, and
`EDMV4-T07 AC8`'s budget is counted in external binaries. `architecture.md`'s citations verified
accurate at a high rate across roughly 50 sites, with only the two flagged exceptions, and its
self-marked UNVERIFIED blocks are the right honesty. Sec.2's 39/21/18 arithmetic re-verified against
D51 element by element, and D51 does say "Group 5 stays as ledger entries with no named owner,
deliberately", so EDMDS-17 AC2's supersession claim is accurate. Sec.3.3's refusal to rewrite the
archived ledger is coherent and does not conflict with DoD item 6 or EDMDS-17 AC2. No i18n/l10n or
WCAG obligation arises.

## Lane A -- not audited

Section 5's twenty-one requirements and the Ticket List (other lanes). Anything requiring execution:
`run-all.sh`'s total against 4048 and whether it is 8 suites; `timing.sh --gateguard`'s current p95;
whether any diagram RENDERS (verified statically against the rule and the awk implementation, which
is not a render); whether `edm-lint-artifacts --path plugins/edm/` is currently clean; **whether a
`PreToolUse` hook's stderr is surfaced on exit 0 or its stdout on exit 2** (P0-3); explorer 04's jq
timings; and whether `jq`'s Oniguruma retry limit is settable per invocation. Host-local
measurements not reproducible: the 85 `run/` markers and 5 `patterns/` files, the 144-entry delta,
the $105.28 / 3h15m round price, and wave6's zero `CLAUDE_PLUGIN_DATA` occurrences.
`architecture.md`'s two self-marked UNVERIFIED blocks were not re-derived. `architecture.md` sections
swept at moderate depth only: the Component Design table's Requirements column (~15 of ~60 AC
references checked), the Data Flow section's `edm-hookify` citations, and Build Sequence items 1-13
and 16-21. `wave6-smoke.sh` and `wave7-smoke.sh` were not opened at all; `wave8-smoke.sh` was read
only at `:4040-4064`, `:7810-7900`, `:7922-7944`, `:8569-8587`, `:8986-9035`.

<!-- SRD-AUDIT-COMPLETE range=S1-S4,S6,architecture.md assigned=6 audited=6 -->

---

# Cross-lane reconciliation -- contested findings settled by direct verification

Three findings were contested between lanes or between a lane and the architect. Each was settled by
reading the code rather than by preferring a lane, and the resolution is recorded here because in
two of three cases the winning lane was not the one that spoke last.

**1. The sanitizer's home.** The architect reported that `edm-hookify`, `edm-bash-gate` and
`edm-stop-gate` source nothing, and concluded a new `bin/_edm-sanitize-lib.sh` was required. Lanes
B, C and A each independently reported `bin/_edm-cli-lib.sh` as the existing universal home.
**Verified**: `edm-gateguard:52`, `edm-hookify:104`, `edm-bash-gate:69`, `edm-stop-gate:65`,
`edm-state:65` all `source "${SCRIPT_DIR}/_edm-cli-lib.sh"`, and fourteen other `bin/` scripts do
too. The architect's claim was true only of `_edm-datadir-lib.sh` (sourced by `edm-gateguard` and
`edm-state` alone) and it generalised from the one library that is not shared. **The three lanes
win.** Consequence: extraction needs no new file and no new `source` line, and is net NEGATIVE on
GateGuard's line count. `pending-v1.2.0.md` A2 is withdrawn on this basis, and `architecture.md`
must be corrected before the gate (lane A P0-1).

**2. `README.md:342` and the kill-switch claim.** Three positions existed. v1.1.0's Sec.3.2 and
EDMDS-04 AC3 called the sentence a live falsehood because `edm-stop-gate` does not honour the pair.
Lane B called the sentence TRUE, since `edm-stop-gate:95-100` does honour it. Lane A called the
sentence false for a third reason. **Verified by occurrence count**: `EDM_HOOKIFY` appears 4 times
in `bin/edm-bash-gate`, 6 times in `bin/edm-stop-gate`, and **0 times in `bin/edm-gateguard`**.
**Lane A wins.** The sentence "Kill switches for all three consumers" is false, but neither for the
reason the SRD gave nor in the way lane B concluded: `edm-stop-gate` honours the pair and
`edm-gateguard` does not. So CLAUDE.md is false in BOTH directions -- its opening "all three
consumers" claim and its closing "stop-gate does not" paragraph -- and the SRD treated the opening
claim as the true one. `edm-gateguard`'s own escape is `EDM_GATEGUARD`/`EDM_GATEGUARD_DISABLED`
(`:31-32`, `:84`), which disables the whole gate rather than hookify evaluation alone. Whether
`edm-gateguard` should gain the pair is a real gap no requirement owns.

**3. Sec.1's Branch row.** Lane A recorded it as NOT FIXED, reporting the working tree on
`edm/edmv4-ecc-integration`. **Verified**: `git rev-parse --abbrev-ref HEAD` returns
`edm/edmds-design-docket`, matching both Sec.1 and `.edm-state.json`. **The lane is wrong** -- the
prior round's P2 was accurate when written, and the branch was checked out between rounds. No
finding. Recorded because a reader comparing the two reports would otherwise see a regression that
did not happen.

A fourth item is not contested but is worth pairing: lane C found that
`_edm-datadir-lib.sh:52-57` states this library's budget as "invokes no external binary ... not
forks no subshell", and that `edm_project_key()` already forks at `:178`. Lane A independently
confirmed the same asymmetry from `architecture.md`'s side. Both conclude the physical-path half of
the CA-500 cross-check is affordable inside `edm_project_key()`, which narrows EDMDS-11 AC6's
`NOTED` to the git-containment half alone. The two lanes agree and neither knew of the other.
