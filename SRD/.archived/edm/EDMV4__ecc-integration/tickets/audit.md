# Ticket Pack Audit Report: EDMV4 -- ECC Integration

**Date**: 2026-09-02
**Pack audited**: 52 tickets, 8 epics, `Generated From: srd.md v1.2.0`
**Auditors**: 2 parallel `edm-ticket-auditor` lanes -- Lane 1 structural (dimensions 1-4, 8),
Lane 2 content-quality (dimensions 5-8). Both terminated with their completion sentinel
(`assigned=52 audited=52`), so neither report is truncated.

## Summary

- Coverage gaps: 5 | Sizing issues: 2 | Dependency issues: 9
- Critical path issues: 4 | AC quality issues: 14 | Diagram issues: 1
- Consistency issues: 11 | Version alignment issues: 1 (the version string itself PASSES)
- **P0: 2 | P1: 11 | P2: 24 | NOTED: 18**
- **Verdict**: **NEEDS FIXES** -- all P0 and P1 remediated before Gate 3.

**Independent corroboration.** Both lanes separately found four of the same defects from disjoint
dimension sets: the orphaned `timing.sh --gateguard` budget, the triple-owned `run-all.sh`
registration, the missing `EDMV4-T54` diagram node, and the stale post-fast-forward Technical
Notes. Two auditors reaching the same conclusion from different scopes raises confidence these are
real rather than one agent's misreading.

**Verifier sentinel note.** This is the first EDM audit to run under the VERIF completion-sentinel
contract with `maxTurns: 50`. This initiative's own SRD audit truncated at the old 25-turn ceiling
and had to be resumed; both lanes here ran to completion and said so machine-readably.

---

## P0 -- Critical

### P0-1 [structural] [Dependencies] `EDMV4-T53` declares no dependencies but is the Definition-of-Done pass

`srd.md` declares `EDMV4-58`'s dependencies as **"every implementation requirement in Sec.6"**. The
pack declares `Depends On | none` and lists `EDMV4-T53` among the nineteen tickets "unblocked at
wave 1". Its own ACs are unsatisfiable there: AC3 requires three smoke cases each for
`edm-gateguard`, `edm-hookify`, `edm-stop-gate` and `edm-repo-readiness` -- built by `T11`, `T43`,
`T46`, `T38`; AC4 requires a case per new `hooks.json` registration (`T11`, `T45`, `T46`); AC5
requires a case per documented exit code across all four. The epic intro says outright that these
passes run "over the surfaces the implementation waves produced".

Shipping this as wave-1-unblocked produces a wave that cannot run.

**Remediation**: `Depends On` set to the terminal ticket of each implementation stream. Removed
from the wave-1 list; count corrected.

### P0-2 [structural] [Dependencies] `EDMV4-T44` and `EDMV4-T46` form a latent circular dependency

Undeclared in either direction. `T44` AC4 requires `edm-stop-gate` to translate `edm-hookify`
exit 2 into its own exit 2, and AC5's smoke test drives "a `Stop` through `edm-stop-gate`" -- both
need `T46`'s script. `T46` AC6 requires `edm-stop-gate` to "then evaluate `stop`-event hookify
rules" and AC10 makes "a hookify `block` match" one of only two ways it returns 2 -- both need
`T43`'s evaluator and `T44`'s block semantics. Read literally, neither can complete first.

Each ticket's Out of Scope tries to disclaim the other, but `T44`'s AC4/AC5 are written as
executable assertions against running scripts, not as specification text, so the ACs and the
Out-of-Scope sections contradict each other.

**Remediation**: broken at `T46`, because `EDMV4-T45` already owns the wiring (its AC2:
"`stop`-event rules are evaluated by `edm-stop-gate`"). The hookify clauses are stripped from
`T46` AC6 and AC10, leaving `T46` validate-only. Side effect: `T46` drops to 12 ACs, closing the
AC-band finding at no extra cost.

---

## P1 -- Significant

### P1-1 [structural + content-quality] [Coverage] The `timing.sh --gateguard` 50 ms p95 budget is owned by no ticket

Both lanes searched all eight epic files independently. The budget appears in **zero acceptance
criteria**. Its only four occurrences are one Technical Note flagging the gap and handing it to
this audit, and three Out-of-Scope lines disowning it (`T11`, `T15`, `T20`). No ticket's Target
Components names `bin/tests/timing.sh` for a `--gateguard` mode.

`srd.md` Sec.9.1 assigns the target to `EDMV4-07` and `EDMV4-08`; Sec.9.3 states `timing.sh`
"gains a `--gateguard` mode"; risk R4 names `EDMV4-07` as owner. The requirement is genuinely
orphaned -- a real coverage gap, not a bookkeeping slip.

**Remediation**: two ACs added to `EDMV4-T11`, whose own Technical Notes already conceded
ownership. Removed from its Out of Scope. `T15` and `T20` Out-of-Scope lines left as-is; they are
correct once `T11` owns it.

### P1-2 [structural] [Coverage] The pack's own "verified" anchors are stale, and would drive an implementer to corrupt correct SRD citations

The most consequential finding in the audit. The README's reconciliation note and SRD v1.2.0's
revision entry both delegate `file:line` authority to the ticket pack -- "each ticket carrying its
own verified anchors". Those anchors were verified against the **pre-fast-forward** tree. The
fast-forward's commit `6e29dcb` (the `*opus-5*` pricing arm, inserted at `bin/edm-state:504-507`)
restored the +4 offset the Phase 4 writers had corrected away.

Re-verified directly during this audit:

| Symbol | Current tree | SRD says | Pack's "correction" |
|---|---|---|---|
| `ALL_LENS_IDS` | **1613** | 1613 (correct) | 1609 (wrong) |
| `MODE_ENUM_LIST` | **807** | 807 (correct) | 803 (wrong) |
| `state_anomalies()` | **1709** | 1709 (correct) | 1705 (wrong) |
| `*opus-5*` arm | **exists, `:507`** | exists | "does not exist anywhere in the file" (wrong) |

`EDMV4-T08` AC8 mandates that "a citation off by more than +/-10 lines is corrected in `srd.md`".
Under the pack's tables an implementer would edit the SRD's **correct** `:1613` down to a wrong
`:1609`. The pack would actively damage the SRD.

Symbols above line 4000 have drifted further than either document: `cmd_validate` **4048**,
`cmd_session_start` **4359**, `cmd_audit_round_start` **4543**, `cmd_set_mode` **5075**,
`cmd_update_patterns` **5593**.

**Remediation**: rather than re-deriving dozens of numbers that will drift again, every epic's
"stale citations, corrected" table is replaced with a locate-by-symbol-name instruction, and
`EDMV4-T08` AC8 is amended to require re-derivation from the tree, never from the pack's table.

### P1-3 [structural + content-quality] [Coverage/Dependencies] The `run-all.sh` registration is claimed by three tickets, making two ACs vacuous

`EDMV4-T20` AC8 (Phase 2), `EDMV4-T53` AC2 (Phase 5) and `EDMV4-T05` AC3 (conditional) all require
adding `wave8-smoke.sh` to `_PREFERRED_ORDER` and raising `_MIN_SUITE_COUNT` "from `7` to `8`".
None references the others; there is no edge between any pair. `T20` lands first, the value is
already `8`, and `T53`'s implementer finds nothing to change and ticks the box.

`T53`'s Technical Notes make this P1 rather than P2: they present AC2 as the ticket's anti-vacuity
guard, and guard the wrong failure mode -- checking that the *line exists*, not that *a peer ticket
has not already made the edit*.

Compounding it, the citation the guard rests on is wrong. `_MIN_SUITE_COUNT` is at
**`run-all.sh:96`**, not `:87` -- commit `5f90001` inserted a `_branch_before` capture block at
`:87-94`. Line 87 is now a comment. The anti-vacuity argument is itself vacuous.

**Remediation**: `EDMV4-T53` gets sole ownership; `T20` AC8 and `T05` AC3 restated as
post-conditions asserting the registration is present. `T53` AC2's second half restated as a
durable live-derived post-condition -- `_MIN_SUITE_COUNT`'s default equals the count of
`*-smoke.sh` files the `find` at `run-all.sh:45` discovers -- which is non-vacuous regardless of
landing order and survives the ninth suite.

### P1-4 [structural + content-quality] [Critical Path/Diagram] `EDMV4-T54` is absent from the Mermaid diagram

The five subgraphs declare 51 nodes against 52 tickets; the `classDef must` line names 36 against
37 Must Have. Both deficits are the same node. Not a style choice: ten other dependency-free
tickets are drawn as isolated nodes, so "no edges" is demonstrably not the pack's reason for
omitting one.

Same root cause as three prose defects below -- the `EDMV4-60`/`T54` scope addition reached every
table and the coverage map but none of the summary prose or the diagram.

**Remediation**: node and class added; the three prose counts corrected; `T54`'s missing `Blocks`
row added.

### P1-5 [structural] [Dependencies] `EDMV4-T50`, `T51`, `T52` carry the same defect as `T53`

`T50` declares `none` but AC1 fails naming any absent new `bin/` file -- all five are built by
`T11`, `T17`, `T43`, `T46`, `T38`. `T51` declares only `T10` but AC5 greps `edm-gateguard` and AC8
drives a `jq`-off-`PATH` test against "each of the four new scripts". `T52` declares `none` but
AC6/AC7 drive denials through "the three emit points". `T50` and `T52` are listed wave-1 unblocked.

**Remediation**: same terminal-ticket dependency set as `T53`; both removed from the wave-1 list.

### P1-6 [structural] [Dependencies] Four missing intra-epic edges

- `EDMV4-T11` omits `T17`. `T17`'s own Description states the division of labour
  ("`edm-gateguard`'s sourcing is asserted by `EDMV4-07`"), and `T11` AC8/AC9 presuppose
  `edm_marker_path()`. Ordering happens to work today; nothing records it, so a wave re-plan
  breaks it silently.
- `EDMV4-T14` omits `T13`. SRD declares `EDMV4-10`'s dependencies as `EDMV4-07, EDMV4-09`; AC8
  asserts each fact "appears in the corresponding denial output", which needs `emit_decision`.
- `EDMV4-T15` omits `T13` and `T17`. SRD declares `EDMV4-11` as `EDMV4-07, 08, 09`; its Target
  Components list `_edm-datadir-lib.sh` and AC6/AC7 exercise `${data}/run/`.

Unlike every divergence in epic 04, none of these is documented.

**Remediation**: edges added to both the tickets and the diagram.

### P1-7 [structural] [Dependencies] `bin/tests/wave8-smoke.sh` is a shared new file with no designated creator

Named in the Target Components of seventeen tickets. The README's "Serialization constraints not
expressible as edges" section lists three constraints and does not mention it. Coordination exists
only as scattered prose in four epic files, each of which believes it may be the creator
("Whichever ticket lands first creates it"; "Creating it is in scope here").

**Remediation**: fourth bullet added to the README's serialization section naming one creator and
stating the append-a-banner rule once.

### P1-8 [content-quality] [AC quality] `EDMV4-T54` AC7 is satisfiable by the hardcoded list it exists to forbid

Adjudicated against the tree. Eight of `T54`'s nine ACs are verified genuinely satisfied. AC7 is
the exception. The shipped assertion iterates `for prod_spec in audit-srd:2 audit-tickets:3` -- a
**hardcoded two-entry name list**, re-encoded in the test with no source in `bin/edm-state` to
derive it from. A ninth phase-skill token that presents a gate is simply not in the loop, the
circularity can be reintroduced, and the suite stays green.

That is verbatim the outcome AC7's own Technical Note says it prevents ("so a ninth token added
later cannot reintroduce the circularity while the suite stays green"), and it is a second
independent encoding of one predicate -- the CA-409 class the same ticket cites as its reason for
leaving `hooks/hooks.json` untouched.

The AC text was too loose to force the right implementation: "A dedicated assertion states the
producer/consumer invariant directly" is satisfied by what shipped.

**Remediation**: AC7 tightened to require the assertion derive its token set live from
`cmd_gate_check`'s own `Valid tokens:` enumeration, and the implementation rewritten to match.

### P1-9 [structural + content-quality] [Consistency] Six tickets assert a pre-fast-forward tree state the README explicitly supersedes

| Ticket claim | Actual |
|---|---|
| `T06`/`T08`/`T09`: "`SRD/.archived/` does not exist" | exists |
| `T08`/`T09`: "EDMV3 still lives at `SRD/edm/EDMV3__prompt-streamline/`" | does not exist; EDMV3 is archived |
| `T17`/`T19`/`T49`: "`ecc-integration-analysis.md` does not exist anywhere in this repository" | exists |
| `T08`: "There is **no** `*opus-5*` text anywhere in the file" | `bin/edm-state:507` |
| `T08`: `plugin.json` reads `3.2.0` | reads `3.2.2` |

Concrete damage: `EDMV4-T09`'s Target Components names a nonexistent path; `T08` AC6's "staged
EDMV3-archival rename set" is already committed; `T49` AC1's blocking pre-flight is already
satisfied. The pack is also inconsistent with itself -- `T05`'s Target Components uses the correct
`SRD/.archived/...` form.

Worth recording: `T08` AC2/AC3/AC4 survive unchanged because they assert *behaviour* (computed
cost, absence of the `*)` warning, arm ordering) rather than the arm's textual presence. That is
the right AC design and it worked. Only the surrounding narrative is stale.

**Remediation**: the five stale claims rewritten against the reconciled tree; `T09`'s Target
Components path corrected.

### P1-10 [content-quality] [Consistency] Test-file citations asserted as verified have drifted

`wave6-smoke.sh` citations above `:1179` drifted +36 to +41, because the `EDMV4-T54` fix inserted
its assertions there. The round-type block cited as `:3427-3457` is at `:3463-3492`; the
canonical-sections block cited as `:4052-4119` is at ~`:4093-4141`.

`wave7-smoke.sh`: `LENS_AGENTS` at **`:1596`** (`T30` AC4 says `:1589`), `lens_files` at
**`:1912`** (says `:1905`), `T46_LENSES` at **`:4754`** (says `:4734`), `T48_CONTESTED_AGENTS` at
**`:5406`** (AC4/AC5 say `:5386`).

This falsifies Epic 04's header claim that the test-file citations "all hold exactly" and `T30`'s
Technical Note that "the test-file line numbers did not drift".

Sharpest instance: `T04` AC4 instructs the implementer to read a comment "which records that
EDMV3-T41's own ticket made this identical wrong citation". The AC warning about a stale citation
is now itself a stale citation.

**Remediation**: folded into the P1-2 anchor pass; the two false "did not drift" assurances struck.

### P1-11 [structural] [Dependencies] `EDMV4-T34`/`T35` invert the SRD's declared direction with no rationale

`srd.md` declares `EDMV4-19`'s dependency as `EDMV4-20`; the pack has `T34` (= `EDMV4-19`) with
`none` and `T35` (= `EDMV4-20`) depending on `T34`. This is the one inversion in the pack with no
recorded rationale -- epic 04 documents every one of its own.

**Remediation**: direction kept (it is the executable one -- `T35`'s ACs are unverifiable before
the classifier exists), rationale recorded in `T35`'s Technical Notes.

---

## P2 -- Minor

Twenty-four findings. Fixed now where cheap; the rest are tracked to Phase 6 and carried into the
code-audit ledger rather than blocking Gate 3.

**Fixed at Gate 3:**

- `README.md` "all 51 tickets" -> 52; "`EDMV4-01` .. `EDMV4-59`" -> `EDMV4-60`; epic 01's "this
  epic holds the five tickets" -> six. All three are `EDMV4-60`/`T54` scope-addition residue.
- `EDMV4-T22` at 14 ACs: AC3 is a glossary note, not a criterion -- nothing about the delivered
  code passes or fails it. Moved to Description; AC11+AC12 merged. Lands at 12.
- `EDMV4-T30` at 13 ACs: AC5's two mechanical obligations are already covered by AC4 and AC6; its
  unique content is rationale. Folded into AC4 as a callout. Lands at 12.
- `EDMV4-T46` at 13 ACs: closes as a side effect of the P0-2 cycle fix.
- `EDMV4-T19` AC1/AC6 contradiction: AC1 explicitly permits enumerating "the six call sites"
  while AC6 fails on the literal word `six`. Both cannot be satisfied in that branch. AC6 narrowed.
- `EDMV4-T18` AC7 names a literal "39 to 40" for a subcommand count that `EDMV4-T24` also
  increments; true final value is 41. Restated as "incremented to match the subcommands actually
  dispatched", matching `T24` AC11's reconciliation instruction.

**Carried to Phase 6** (each recorded with its owning ticket):

- `EDMV4-T53` undersized at M given AC3+AC5 alone (12 smoke cases minimum); re-size or push
  per-script case authorship into the tickets that build each script.
- `EDMV4-T50`/`T51`/`T52` sized as one-shot passes but described as re-run per wave.
- Six documented-but-unenforced dependency edges: `T29 + T25/T26/T27`, `T32 + T22/T23`,
  `T33 + T31`, `T40 + T39`, `T41 + T40`, `T45 + T11/T44/T46`.
- Three `T31`/`T33` duplicate AC pairs and the `T46` AC6 / `T47` AC1 overlap: ambiguous ownership.
- `EDMV4-T53` AC3 hardcodes a four-name script list where its three epic-08 siblings deliberately
  derive theirs live -- same epic, opposite discipline.
- `EDMV4-T29`'s twelve ACs are all line-anchored, and AC1's own edit shifts its later citations.
- `EDMV4-T50` AC9's pack-wide "no escape hatch" assertion false-positives on `T38` AC8.
- `EDMV4-T08` AC5's `grep -rc` is ambiguous between output and exit status; also names a fixed
  count of 14 `SKILL.md` files.
- `EDMV4-T16` AC5 names a fixed target count for a prose enumeration.
- `EDMV4-T04` AC7's orphan taxonomy has no route for a canonical-suffixed section deliberately not
  mirrored -- and the tree now contains one, the VERIF `Verifier completion sentinel (canonical)`
  section added after this SRD was written. Currently latent.
- Compound ACs in epic 07 bundling 3-5 falsifiable obligations behind one checkbox (`T04` AC12
  carries five).
- `Blocks` field present on 5 of 52 tickets -- a partial reverse index a reader may mistake for a
  complete one.
- `T12` and `T17` cite the same `architecture.md` anchor one line apart, both as verified.
- H2 heading backticks stripped in epics 01/04/05 but kept elsewhere, defeating a byte-identical
  index-to-epic title cross-check.
- Epic 05 and 07 formatting diverges from the other six.
- `artifact_hashes.srd` was recorded at Phase 3 close and predates both v1.1.0 and v1.2.0.
- `EDMV4-T54` AC2/AC3 (the positive direction -- Gate 2 approved, Gate 3 not) have no committed
  regression case; the wave6 loop exercises only the all-gates-unapproved direction.
- The "Longest chains" table needs recomputing once the new edges land -- the real critical path
  becomes the hookify/Stop-gate stream terminating in `T53`, not the lens chain.

---

## NOTED -- Intentional / Pre-existing

- **Version alignment PASSES.** README body line 1, `srd.md` Document Information, and
  `.edm-state.json` all read 1.2.0. No P0.
- **Both stated distributions are correct**, recomputed independently by Lane 1 from the epic
  files: 6 XS / 31 S / 13 M / 2 L / **0 XL**, and 37 Must / 14 Should / 1 Could. All 52 rows match
  their README index entries, and every ticket priority correctly derives as the maximum of its
  requirements' SRD priorities.
- **Zero orphan requirements, zero orphan tickets.** All 60 requirement IDs appear in the coverage
  map; all 52 tickets carry a resolvable `SRD Refs`.
- **Zero D15-class unverifiable acceptance criteria.** Lane 2 checked every AC against the
  environment that actually exists. The pack actively closed all three candidates rather than
  leaving them latent: the live-API eval baseline is an explicit scope boundary with a named
  follow-on; Linux is recorded as untested rather than claimed; the CI block is reinterpreted
  against constraint C8. Nothing needs gate change control at Phase 6.
- **Mermaid conventions: compliant.** No raw `;` inside any label, node, edge or message text. The
  `classDef` lines carry no `;` at all, so not even the legal-terminator case arises. Hex colours
  are directive values, not label text. No `#59;` escape needed anywhere. All 44 edges match the
  declared `Depends On` values exactly.
- **Pack is ASCII-clean** -- zero non-ASCII bytes tree-wide.
- **The `T01` -> `T04` numbering gap** is correct, intentional, and documented in three places with
  an explicit do-not-fix instruction, enforced by `T09` AC5/AC6.
- **The 3-to-1 mapping of `EDMV4-14`/`15`/`16` to `EDMV4-T18`** is deliberate per risk R9 and
  correctly modelled, reinforced three ways by `T18` AC12.
- **`EDMV4-T01` at Should Have is correct -- do not "fix" it.** Both lanes checked every surface
  and agree. Both its requirements are Should Have in the SRD; the ticket takes the maximum among
  them. Inheritance constrains what the ID may *cover* (enforced by `T09`, which is Must Have), not
  its priority. The one risk here is someone raising it to Must on the theory that an inherited
  ticket must be Must. Ratified as-is.
- **Both `L` tickets carry genuine decomposition justifications.** `T18`'s argues decomposition is
  the specific failure the merge exists to prevent, with an escalation route that says re-scope the
  requirement rather than split the ticket. `T30`'s cites twenty-plus interdependent assertion
  sites in one 7,000-line file under a no-concurrent-edits constraint.
- **`EDMV4-T04` encodes its mandatory internal order `50 -> 51 -> 49` correctly**, as a criterion
  in its own right requiring `git log --oneline` to show it.
- **`T01`/`T04`/`T05` each cover their inherited scope and nothing else**, each with an explicit
  no-drift clause in Out of Scope.
- **The two spikes are the right shape.** `T06` and `T07` cannot be graded from code alone -- that
  is inherent to a host-behaviour spike -- but both specify the artifact tightly enough to be
  falsifiable, including a positive control and a `git status` proving `hooks.json` was untouched.
- **`EDMV4-T30` AC5 and `EDMV4-T31` AC3(a)** are the pack's own catches of the hardcoded-name-list
  anti-pattern this audit hunts. `T30` AC5 identifies the one site where "the test passing is
  itself the defect". Preserved verbatim through the restructuring.
- **Definition of Done item 10** (a converged code-audit round) is owned by no ticket, correctly --
  it is a methodology gate discharged by `/edm:code-audit`, not implementation scope. Items 2-9 all
  map to tickets.
- **The SRD's `bin/edm-state` line drift is not itself a pack defect** and is already recorded in
  the README's reconciliation note. P1-2 is the separate matter of the *pack's own* corrected
  anchors being wrong.
- **`EDMV4-T08`'s behavioural ACs survive its stale premise**, by design -- see P1-9.

---

## Process finding

**The stale-anchor pattern has now recurred three times inside one initiative**: the SRD premise
about branch state (caught at Phase 4), the epic writers' corrected anchors (caught here), and the
`wave6-smoke.sh` shift caused by this initiative's own `T54` fix (caught here). Each time the fix
was to re-derive numbers that then drifted again.

The remediation applied at this gate breaks the loop rather than continuing it: the pack now
instructs implementers to locate by symbol name at edit time, and `EDMV4-T08` AC8 is amended so it
can never be used to "correct" the SRD toward the pack's numbers. Any line number remaining in the
pack is advisory.

## Remediation

Applied to the ticket pack before Gate 3. **Every P0 and P1 is closed**, plus six P2s.

| Finding | Applied |
|---|---|
| P0-1 | `EDMV4-T53` given its twelve terminal-ticket dependencies; removed from the wave-1 list |
| P0-2 | `T44`/`T46` cycle broken -- hookify clauses stripped from `T46` AC6/AC10, wiring left to `T45`; `T44` and `T45` dependencies declared. Graph verified acyclic |
| P1-1 | `timing.sh --gateguard` and the 50 ms p95 budget owned by `EDMV4-T11` as AC10/AC11, with the 50 ms figure stated as a design target until measured; removed from `T11`'s Out of Scope and added to its Target Components |
| P1-2 | Advisory-line-number banner added to all eight epic files; `EDMV4-T08` AC8 rewritten to require re-derivation from the tree and to forbid "correcting" `srd.md` toward any number in this pack |
| P1-3 | `EDMV4-T53` AC2 is the sole owner, restated as a live-derived post-condition (`_MIN_SUITE_COUNT` equals the discovered suite count, never the literal `8`); `T20` AC8 and `T05` AC3 reduced to presence assertions |
| P1-4 | `T54` node and `must` class added to the diagram; epic 01 summary corrected to six tickets; `T54` `Blocks` row added |
| P1-5 | `T50`/`T51`/`T52` given the same terminal dependencies; `T50` and `T52` removed from the wave-1 list |
| P1-6 | Edges added: `T17 -> T11`, `T13 -> T14`, `T13 -> T15`, `T17 -> T15` |
| P1-7 | `wave8-smoke.sh` given one designated creator (`EDMV4-T53`) in the README's serialization section, with the append-a-banner rule stated once |
| P1-8 | `T54` AC7 tightened to require both sides derived live; **the implementation was rewritten to match** and now derives tokens from `cmd_gate_check`'s `Valid tokens:` line and produced-gates from each skill's `## HITL Gate N` heading. Verified to fail on a reintroduced regression |
| P1-9 | Five stale existence claims corrected across epics 01, 03 and 07; `T09`'s nonexistent Target Components path repointed to `SRD/.archived/...` |
| P1-10 | Both false "did not drift" assurances struck and replaced with the verified positions |
| P1-11 | `T34`/`T35` inversion rationale recorded in `T35`'s Technical Notes |
| P2 (6) | `T22` 14 -> 12 ACs, `T30` 13 -> 12, `T46` 13 -> 12; README prose counts (51 -> 52, `EDMV4-59` -> `EDMV4-60`, epic 01 five -> six); `T18` AC7 literal count replaced; longest-chain table recomputed |

### Verified after remediation

- 52 tickets, all within the 6-12 AC band (three were over; none is now).
- Diagram: 52 nodes, all coloured, **101 declared dependencies represented exactly** -- no drawn
  edge without a declaration, no declaration without an edge. Graph verified **acyclic**.
- The four Phase-5 verification passes' 49-edge fan-in routes through one explicit `TERM` junction
  node rather than 49 literal edges. The junction is a drawing device carrying no ticket ID; the
  convention is stated once in the README beside the diagram.
- `edm-lint-artifacts` CLEAN, `edm-check-vocabulary` CLEAN, `edm-state validate` no anomalies,
  zero non-ASCII bytes across the pack.

### Not remediated -- carried to Phase 6 by design

The eighteen P2 items listed above under "Carried to Phase 6". Per
`CLAUDE.md Sec."Severity vocabulary"` a P2 is remediated before **convergence**, not before this
gate, and each is recorded against its owning ticket. Two are worth naming at the gate because they
touch work already on disk: `EDMV4-T54` AC2/AC3 have no committed positive-direction regression
case (the wave6 loop exercises only the all-gates-unapproved direction), and `artifact_hashes.srd`
was recorded at Phase 3 close so it predates both v1.1.0 and v1.2.0.
