# SRD: EDMDS -- EDMV4's Structural Design Docket

**Generated From**: srd.md v1.1.0

## 1. Document Info

| Field | Value |
|---|---|
| Version | 1.1.0 |
| Mode | `mini-srd` -- phases 2 through 5 fuse into this one audited file; a merged Gate 2+3 replaces Gate 2 and Gate 3 |
| Forked from | `EDMV4` |
| Branch | `edm/edmds-design-docket` |
| Inputs | `planning.md`, `analysis.md` (carried constraints CC1-CC8), `explorers/01` through `explorers/04`, `upgrade-path.md`, `inherited-findings.jsonl` |
| Architecture | `architecture.md` -- resolver chain and round-record state transitions are diagrammed there, not restated here |
| Related | `EDMTC` (closed the other 21 of EDMV4's 39), `EDMV4` (archived) |

### Revision History

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0.0 | 2026-09-08 | orchestrator | Initial fused SRD. Proposed a decision for each of the eighteen findings. |
| 1.1.0 | 2026-09-09 | orchestrator | Phase 3 remediation. Verdict on 1.0.0 was FAIL (8 P0, 32 P1, 26 P2 across both lanes). Two P0s were structural: the trust-boundary decision rested on a false premise, and the fused file was missing its entire Phase-4 half. Both lanes independently found the first. Changes: AD1 reversed and renumbered AD-DS1 (the labelling mechanism it denied exists is shipped and pinned); EDMDS-02 rewritten per deny mechanism; the closure model conformed to the canonical vocabulary; EDMDS-11's two mutually exclusive AC resolved in favour of the fast-path budget; EDMDS-13 split three ways; EDMDS-19 added for installs already polluted by CA-134; a Ticket List added with `EDMDS-T{NN}` ids, Sizes and Target Components. Eighteen requirements became twenty-one. |

## 2. Executive Summary

EDMV4 accepted 39 P2 findings as documented debt. `EDMTC` closed 21 of them -- one homogeneous
defect class, run as a fix-pack. These are the other 18, and they are different in kind: each needs
a design decision before a fix is well-defined. The arithmetic is verified against EDMV4's D51
element by element: 39 - 21 = 18, and the eighteen match D51's group-5 list exactly.

**This document makes those calls.** Explorers 01 through 03 deliberately withheld recommendations
so the facts would stand on their own. Explorer 04 did not: it is a runtime measurement written by
this document's own author, and it both measures and recommends. That is stated here rather than
glossed, because it is the one place in the input chain where the writer and the verifier are the
same person -- see R7.

Six of the twenty-one requirements carry an explicit **Rejected** block. The other fifteen record a
single decision with its rationale and no live alternative; v1.0.0 claimed all of them stated a
rejected option, which was false, and the claim is withdrawn rather than manufactured.

Phase 1 changed three of the eighteen. CA-114's premise is disproved by measurement, CA-109 turns
out to be a security-relevant correctness gap rather than a consolidation, and CA-072 is smaller
than recorded. Phase 3 changed a fourth: CA-134's shipped fix does nothing for a directory EDM
already polluted, which is now EDMDS-19.

## 3. Goals and Scope

### 3.1 Goals

1. Reach a canonical status for all eighteen inherited findings. Under
   `docs/canonical-sections.md:14-23` that means remediated, or reclassified `NOTED` with a stated
   reason. There is no third outcome: deferral does not exist in this methodology, and this
   document does not invent one. v1.0.0's "or record an explicit, reasoned decision not to close"
   was a fifth status and is withdrawn.
2. Leave no finding whose resolution rests on an undocumented assumption about a dependency.
3. Add no assertion that cannot fail. EDMV4 fixed fifteen instances of that class (D51 records the
   figure for EDMV4 alone), and this initiative's own `analysis.md` records EDMTC catching an agent
   introducing one more. The "sixteenth" count traces to `analysis.md` only -- no record of it was
   found in EDMTC's own artifacts -- so it is cited as this document's claim, not EDMTC's.

### 3.2 In scope

The eighteen findings in `inherited-findings.jsonl`, plus three items Phases 1 and 3 established
belong here:

- `bin/tests/wave6-smoke.sh`'s unguarded writes into the real host data directory -- 85 stale
  markers measured on this host, traced to its T06 band isolating `HOME` and `CLAUDE_PROJECT_DIR`
  but never `CLAUDE_PLUGIN_DATA`. Same mechanism as Decision B. Now EDMDS-21.
- `README.md`'s claim that `file`-event hookify rules work unconditionally. They do not (CA-122),
  and the documentation is currently wrong regardless of which way that decision goes. It carries a
  second live falsehood at `:342` ("Kill switches for all three consumers"), swept by EDMDS-04.
- Installs already polluted by CA-134 before its fix shipped. Now EDMDS-19; the full reasoning is
  `upgrade-path.md`.

### 3.3 Out of scope

- Re-opening EDMV4's archived ledger. The eighteen stay open there; that ledger records what EDMV4
  shipped, and rewriting it would misdescribe history -- the same precedent EDMTC set. EDMDS is the
  record of closure, and EDMDS-17 AC4 gives that claim mechanical backing rather than leaving it an
  assertion.
- Adopting any of the four reserved-but-uncreated follow-on prefixes (`EDMRT`, `LINUXV`, `EVALB`,
  `CAMGAP`) as an initiative. Deciding whether each stays reserved IS in scope -- that is EDMDS-18,
  and `CAMGAP`'s disposition is owned there alone. EDMDS-07 and EDMDS-18 no longer both claim it.
- Any change to `bin/tests/wave8-smoke.sh`'s assertion COUNT downward. Amending an assertion's
  expectation is in scope; deleting one is not.

### 3.4 Definition of Done

1. Every requirement below at **any** priority has all acceptance criteria satisfied and evidenced,
   or its finding is reclassified `NOTED` with the reason recorded in `decisions.md`. v1.0.0 bound
   only `Must`, which put six of eighteen findings behind an escape the vocabulary does not permit.
2. `/bin/bash plugins/edm/bin/tests/run-all.sh` passes with zero failures on macOS under bash
   3.2.57, at **4048 or above** (CC6). That baseline is EDMTC's exit figure and is anchored to no
   commit; two `bin/`-touching commits have landed since. It is re-measured and re-anchored to a
   commit sha as the first act of Phase 6, and the measured figure recorded in `decisions.md`.
3. `edm-check-grants`, `edm-check-vocabulary`, `edm-check-skill-sync` and
   `edm-sync-canonical-sections --check` all exit 0.
4. `claude plugin validate plugins/edm/` exits 0.
5. `edm-lint-artifacts --path plugins/edm/` reports zero violations across `skills/`, `agents/` and
   `docs/`. Its exit code is not part of this item: it reports on a wider surface than this claim
   covers and can exit non-zero on a clean tree for reasons outside it.
6. `bin/edm-gateguard` is within `EDMV4-T11` AC1's closed 200-660 line range. It stands at 659
   (CC7) -- one line of headroom, and three requirements touch it. If a requirement pushes it past
   660, the bound is amended by a recorded decision, never nudged (D42, D47, D49 precedent). Note
   that amending T11 AC1 edits a file under `.archived/`, which `edm-lint-artifacts` excludes from
   every scan, so that edit is verified by reading rather than by the linter.
7. **Carried constraints CC1-CC8 from `analysis.md` hold.** Named individually because v1.0.0
   carried only two of eight: CC1 every new assertion has a negative control proving it can fail;
   CC2 no self-matching scans (binds hardest on EDMDS-14 AC2); CC3 no `var="$(cmd | ...)"` under
   `set -e` and never `$?` after a pipe; CC4 bash 3.2 floor, required binaries stay `bash`, `jq`,
   `git`; CC5 ASCII only, `wave8-smoke.sh` stays executable and new bands go BEFORE its own
   `Results:`/`exit` lines; CC6 as item 2; CC7 as item 6; CC8 a scratch directory uses one of
   EDMTC-T03's two sanctioned forms.

v1.0.0 carried an eighth item requiring every proposed decision to be ratified at Gate 2+3. It was
circular -- discharged by the very gate that ratifies this document -- and textually identical to
EDMDS-17 AC1. It is removed; EDMDS-17 owns it.

## 4. Architecture Decisions

Five decisions cut across multiple requirements and are stated once here. They are numbered
**AD-DS{N}**, not `AD{N}`: EDMV4's `architecture.md` carries AD1 through AD6, all six still cited
bare in CLAUDE.md sections that five of these requirements must edit, and a bare `AD2` appearing in
both documents would be ambiguous in exactly the files being changed.

Flow and state consequences of AD-DS2 and AD-DS3 are diagrammed in `architecture.md`. v1.0.0
expressed both in prose only.

### AD-DS1 -- Trust boundary: label the text where it cannot be moved, move it where it can

A hookify rule file is source-controlled project content, authored by whoever can commit to the
repository, which is not necessarily the operator running the session. Its `message` field is
**data to be displayed, never instruction to be followed**.

v1.0.0 asserted that this is "a posture, not a mechanism, because no mechanism in this plugin can
enforce it". **That was false and it is reversed here.** The mechanism exists, is shipped, and is
machine-pinned: `bin/edm-stop-gate:113-124`'s `stop_gate_emit_blocking <label> <text>` separates
EDM's own literal label from the untrusted half, sanitizes only the untrusted half, and is held in
place by `EDMV4-T52 AC6` at `bin/tests/wave8-smoke.sh:7922-7929`. Both audit lanes found this
independently, by different routes. `docs/ecc-integration-analysis.md:95-97` records a second,
weaker precedent.

The second corrected premise is the channel. **stderr is not a non-model-facing channel.** For a
`PreToolUse` hook, exit 2 plus stderr is precisely the case where stderr is returned to the model
as the refusal reason. So "put the author's message on stderr" relocates the text within the
model-facing channel rather than out of it, at three of four consumers.

What follows is one decision with two branches, because the surfaces genuinely differ:

| Surface | Channels available | Decision |
|---|---|---|
| `edm-gateguard`, `EDM_GATEGUARD_DENY_MODE=json` (default) | two -- stdout JSON to the model, stderr to the operator | **Separate.** `permissionDecisionReason` carries EDM-authored text plus rule id and rule file path; the author's `message` goes to stderr. |
| `edm-gateguard`, `EDM_GATEGUARD_DENY_MODE=exit-code` (`:236-240`) | one -- stderr IS the refusal | **Label.** Route through the `stop_gate_emit_blocking` shape. |
| `edm-bash-gate` (`:136`) | one | **Label**, same shape. |
| `edm-stop-gate` (`:216`, `:244`) | one | **Already labelled.** This is the precedent; no change beyond confirming it. |

Where two channels exist, reduce the channel. Where one exists, label the text using the mechanism
already in the tree. v1.0.0's blanket "prefer reducing the channel over fortifying the frame" is
withdrawn: at three of four surfaces there is no second channel to reduce into, and applying that
preference there would have entrenched the exposure while reporting it closed.

### AD-DS2 -- One resolver where the budget allows, and the residual named where it does not

Three project-root resolvers exist and they disagree. The canonical implementation is
`bin/edm-state`'s `_resolve_permcheck_project_root` (`:1172-1199`), because it is the only one
carrying the CA-500 physical-path cross-check.

**Two corrections to v1.0.0's statement of the asymmetry.** The canonical resolver is not
uniformly strict: at `:1191-1193` it accepts `CLAUDE_PROJECT_DIR` unchecked in the sub-case where
there is no git toplevel at all. And the third resolver's fallback is `pwd`, not `.`. So the choice
of canonical is correct but the claim that "the two lax resolvers accept `CLAUDE_PROJECT_DIR`
unchecked" understates where the divergence survives.

**The cross-check cannot be applied everywhere, and v1.0.0 required exactly that.** It IS a
`git rev-parse --show-toplevel` -- unconditional, at `edm-state:1175`, plus two `cd ... && pwd -P`
subshells. Meanwhile `edm_project_key()` (`bin/_edm-datadir-lib.sh:172-185`) spawns `git` only when
`CLAUDE_PROJECT_DIR` is unset or not a directory, `EDMV4-T17 AC7` pins that by shadowing `git`
with a failing stub and requiring success anyway, and `edm-gateguard:98` calls `edm_marker_path()`
before the marker test at `:102-104` on a fast path budgeted at zero external binaries
(`EDMV4-T07 AC8`, advertised to users at `README.md:300-301`). EDMDS-04's own rationale spends that
same budget to reject a feature change.

So: **the fast-path budget wins.** The cross-check is applied in `edm-state` (where it already is)
and in `bin/edm-hookify` (which parses payloads with `jq` on every evaluation and can afford one
more exec). `edm_project_key()` keeps its documented no-git contract unchanged.

The residual is stated rather than hidden: an unchecked `CLAUDE_PROJECT_DIR` still redirects the
marker key, so a wrong or hostile value relocates `<key>.phase6` and `edm-gateguard` then finds no
marker and allows every edit. Two things bound it. `CLAUDE_PROJECT_DIR` is set by the host, not by
project content, so it is outside AD-DS1's trust boundary. And the failure is fail-open toward a
state the operator can reach anyway by not enabling the plugin. That half of CA-109 is therefore
reclassified `NOTED` under EDMDS-11 AC6, not left open.

`CLAUDE.md:1345` still records CA-500 as open while the code carries the fix. EDMDS-11 AC7 sweeps
it; without that sweep this decision would ship contradicted by the documentation it depends on.

### AD-DS3 -- A completeness gate asserts delivery, not existence

`CA-090` and `CA-091` together decide whether "the round converged" is a claim about delivery or
about files existing. A gate whose only check is "the file parses" is a gate in name only, and
absence of a manifest is the strongest non-delivery signal available rather than a reason to skip
checking.

**Qualifier, per D40** -- which named this the precondition for closing the gap at all: the
downgrade applies to `audit_type == "code"` rounds only. `bin/edm-state:5116`'s guard predates this
SRD and already scopes it correctly.

**Residual, and its remedy.** Option B checks two of a lens line's eleven schema fields. v1.0.0
left it there, which means a `lens-L{N}.jsonl` copied verbatim from a PREVIOUS round satisfies the
new gate. Adding `round` to the checked fields closes that, and it adds no drift surface because
`round` is already in state -- which is precisely why Option C's drift-surface objection does not
reach it. EDMDS-06 AC2 carries this.

### AD-DS4 -- Backward compatibility is a constraint, and it binds every requirement that moves data

`CA-134`'s C-4 clause is `[[ -d "${p}/run" || -d "${p}/patterns" ]]` -- **`run/` OR `patterns/`**.
v1.0.0 named only `patterns/`, and the omitted half is the larger one: 85 `run/` markers against 5
`patterns/` files on this host. A sweep that empties `run/` on a pre-D46 install whose only
footprint is `run/` markers destroys that install's ownership proof and silently relocates its data
root -- the failure class this decision exists to prevent, created by the requirement it
constrains. So the sweep must not remove `run/` itself, only its contents (EDMDS-20 AC4).

A sentinel-only ownership test was tried in EDMV4 and provably abandoned every existing install --
58 failing assertions (D46). No install was in fact abandoned; the change was caught pre-ship. The
figure is a measurement of the test suite's reaction, not of field damage, and is cited that way.

**AD-DS4 binds EDMDS-11, EDMDS-13, EDMDS-19 and EDMDS-20**, not Decision B alone. v1.0.0 bound only
the last. AD-DS2's change has an equal consequence: adopting `edm-state`'s semantics inside
`edm_project_key()` would rename `<key>.phase6`, `<key>.checked` and `<key>.denials` for any
project where the resolvers disagree, so it could trigger on upgrade the exact marker-absent
failure EDMDS-10 exists to fix. That is a second, independent reason the fast-path budget wins in
AD-DS2.

Every requirement under this decision proves compatibility by a test that **fails without the
compatibility path** -- an assertion that passes either way is Goal 3's defect class.

### AD-DS5 -- A closed finding has a status from the closed set, and the status is mechanically checkable

`docs/canonical-sections.md:14-23` admits four statuses: P0, P1, P2, NOTED. Every inherited finding
leaves this initiative as remediated or as `NOTED` with a reason. Three consequences, stated because
v1.0.0 violated all three:

- No requirement's acceptance criterion may be satisfied by writing a sentence. v1.0.0 had eight
  such disjunctions ("X, or the difference is recorded with a reason"); each is now a single
  obligation, with the alternative -- where one is genuinely open -- resolved here in the SRD text
  and the requirement stating only what to do. Choosing between them at implementation time is the
  descope authority `canonical-sections.md:118-123` reserves to a human at a gate.
- `Should` and `Could` do not weaken closure. The priority orders the work; it does not license
  leaving a P2 unresolved. Section 5's legend says so.
- "EDMDS is the record of closure" needs backing: EDMDS-17 AC4 records a `resolved_commit` per
  finding, so the claim is checkable rather than asserted.

## 5. Requirements

Priority orders the work, and nothing else. **Must** = on the critical path. **Should** = expected
this initiative. **Could** = opportunistic. Per AD-DS5 no priority licenses leaving a finding
unresolved: every requirement below closes its finding by remediation or by a recorded `NOTED`
reclassification, and Definition of Done item 1 binds all three tiers equally.

Every AC that adds an assertion carries a negative control (CC1). Where a control is not spelled
out in its own AC it is named in the ticket's AC list.

### Epic 1 -- Untrusted input and unratified surface

#### EDMDS-01 (Must) -- Depend on Oniguruma's retry limit deliberately, pin it, and split CA-114

**Finding**: CA-114, **split**. The finding carries two claims and they have different dispositions:

- The header's statement that the 64 KiB cap bounds evaluation cost is **false, and remediated** by
  AC1.
- "`regex_match` has no time bound" is **still literally true** after this requirement lands, and
  is reclassified **`NOTED`** by AC6, with explorer 04's measurement as the reason: jq 1.8.1 is flat
  at 139/144/147 ms across 100/1000/10000-character inputs and reports
  `Regex failure: retry-limit-in-match over`, so the unbounded hang does not occur on the pinned
  engine.

v1.0.0 closed CA-114 as a remediated P2 while leaving the second claim unfixed, which is the
deferral the methodology forbids. Doing nothing about the time bound is defensible on the
measurement; closing the finding without reclassifying it is not.

**Decision**: option 1 of explorer 04 -- depend on the engine's bound, document it, assert it.

**Rejected**: adding an EDM-side bound. A pattern-complexity heuristic rejects legitimate patterns,
which is a worse failure than the one it prevents; a `sleep`-plus-`kill` watchdog adds asynchronous
process management to three hook consumers, one of which has a zero-exec fast path. Both are
solutions to a hang that does not occur. Also rejected: dropping `regex_match`, which removes a
documented feature to fix a non-problem.

- [ ] AC1: `bin/edm-hookify`'s header no longer claims the 64 KiB cap bounds evaluation cost. It
      states that the bound is Oniguruma's `retry-limit-in-match`, that it is a property of `jq`
      and not of EDM, and that `CLAUDE.md`'s required-binary contract names `jq` with no version
      floor.
- [ ] AC2: an assertion drives a known-catastrophic pattern (`(a+)+$` against a non-matching
      suffix) through `bin/edm-hookify eval bash` and requires **exit 1** -- the `E` record at
      `:392` sets `HAD_ERROR=1` and the ladder at `:476-480` is `block(2) > error(1) > clean(0)` --
      with the offending rule FILE named on stderr and no block. The `exit 0` in explorer 04 came
      from `edm-bash-gate`, which translates 1 into 0; v1.0.0 attributed it to the evaluator.
- [ ] AC3: a companion assertion drives the same fixture through `bin/edm-bash-gate` and requires
      exit 0 with no block, so the translation is pinned at the consumer that performs it.
- [ ] AC4: the fixture's input length is a named constant at the assertion site, with an inline
      comment pointing at R5. On a future engine with the retry limit REMOVED this assertion hangs
      rather than fails, and a maintainer facing a wedged suite needs the pointer at the line, not
      in a document.
- [ ] AC5: the same band requires a benign sibling rule in the same directory to still fire, so
      CA-030's per-file isolation is pinned alongside.
- [ ] AC6: a negative control proves AC2 discriminates -- a rule whose pattern is benign produces
      no setup error, so "no error" is not the assertion's only reachable state.
- [ ] AC7: `CLAUDE.md`'s hookify section records the dependency and the residual, and
      `decisions.md` records CA-114's split: the documentation half remediated, the
      unbounded-`regex_match` half `NOTED` with the measurement as its reason. No wall-clock or
      complexity guard is added, and that omission is recorded as decided rather than overlooked.

#### EDMDS-02 (Must) -- Give the model an EDM-authored refusal where a second channel exists, and a labelled one where it does not

**Finding**: CA-113. **Decision**: per AD-DS1, two branches by surface. v1.0.0 chose "message to
stderr" for all four consumers on the premise that stderr is not model-facing. Both audit lanes
falsified that premise independently, and under it AC5 would have entrenched the exposure at two
sites while reporting the requirement closed.

**Also corrected**: v1.0.0's AC1 and AC2 required the rule file path in the refusal and the message
"attributed to its file". Neither was implementable. `bin/edm-hookify:369` builds the match record
as `"M\t" + scrub(name) + "\t" + scrub(action) + "\t" + scrub(message)` -- no path field, while the
`E` setup-error records at `:357`, `:361` and `:392` all carry `scrub($path)`. So
`hookify_emit_match` (`:414-425`) prints `<rule_id> <action> <message>` and `edm-gateguard:647`
captures exactly that. The path never crosses the process boundary. AC1 below changes that contract
first; the rest depends on it.

**Rejected**: option 4, accept the risk. `CA-196` records the same class at
`bin/edm-lint-staged-artifacts:151` -- **already accepted as `NOTED` in EDMV4's ledger**. v1.0.0
cited that site as grounds for refusing to accept here while leaving it unaddressed, which is
incoherent in both directions. The honest form: accepting here would make a two-site pattern, and
the second site's acceptance was itself never revisited. EDMDS-02 AC8 revisits it.

**Cost accepted explicitly**: in `json` mode the author's `message` becomes invisible in the one
channel most likely to change model behaviour on retry. That is a real loss of the field's value
and it is the price of the boundary. In the three single-channel modes the message stays where it
is, labelled -- no loss, and no pretence of a boundary that is not there.

- [ ] AC1: `bin/edm-hookify`'s matched-rule output contract carries the rule file path. The `M`
      record gains a `scrub($path)` field, `hookify_emit_match` emits it, and `EDMV4-T44`'s
      exit/output contract is amended to match. CLAUDE.md documents the three-field shape in two
      places; both are swept.
- [ ] AC2: in `EDM_GATEGUARD_DENY_MODE=json`, `permissionDecisionReason` on a hookify-driven denial
      contains only EDM-authored text plus the rule id and rule file path -- no byte of the author's
      `message`.
- [ ] AC3: in `json` mode the author's `message` appears on stderr, attributed to its file.
- [ ] AC4: an assertion proves a rule whose `message` mimics EDM's own fact-list prose cannot place
      that text into `permissionDecisionReason` in `json` mode.
- [ ] AC5: AC4's negative control -- the same message IS present on stderr, so the test
      distinguishes "suppressed everywhere" from "moved to the right channel".
- [ ] AC6: in `EDM_GATEGUARD_DENY_MODE=exit-code` and in `bin/edm-bash-gate`, the author's message
      is emitted through the `stop_gate_emit_blocking <label> <text>` shape: an EDM-authored label
      line naming the rule id and file, then the sanitized untrusted text. `bin/edm-stop-gate` is
      confirmed to already do this and is not changed.
- [ ] AC7: an assertion proves the label line is present and unsanitized and the message half is
      sanitized, at both changed sites -- with a control proving the assertion fails when the two
      halves are concatenated into one unlabelled string.
- [ ] AC8: `CA-196`'s site is re-assessed against AD-DS1 and its `NOTED` status either reaffirmed
      with a current reason or superseded by a fix. Recorded either way in `decisions.md`.
- [ ] AC9: `CLAUDE.md`'s hookify section and `README.md`'s rule-format section state, per deny
      mode, which channel carries the author's message. Both currently describe one behaviour for
      all modes.
- [ ] AC10: D49's ordering is honoured -- the reused MIT text in `NOTICE` is amended before any
      claim about it changes, never after.

#### EDMDS-03 (Must) -- Ratify GateGuard's MultiEdit arm on stated evidence

**Finding**: CA-116. **Decision**: ratify on current evidence and close D26's condition.

**Rationale**: D26 conditioned shipping on a re-test that could not be performed -- `MultiEdit` was
absent from the toolset twice, including with `--allowedTools MultiEdit` forced. A condition whose
precondition is unavailable is not a gate, it is a permanent block on working code. `EDMTC-T04` has
since driven the arm end to end against both payload shapes with de-duplication asserted, which is
more evidence than the original re-test would have produced.

**Rejected**: withdrawal, which would delete a tested feature to satisfy an unsatisfiable condition.

- [ ] AC1: `decisions.md` records D26's condition as closed, naming `EDMTC-T04`'s coverage as the
      substitute evidence and stating plainly that the original re-test was never performed.
- [ ] AC2: the residual is recorded: the arm is proven by fixture, not by a live `MultiEdit` tool
      call, and no such call has been observed on this host. v1.0.0's AC2 asserted the negative
      existential ("no such call has ever been observed") as a verifiable claim; it is not
      verifiable, and is recorded as a statement about this host's observation history instead.
- [ ] AC3: `EDMRT` is retained as reserved for live runtime verification, and `decisions.md` says
      so. v1.0.0 said this requirement "does not claim to close it", which decided nothing;
      EDMDS-18 owns the other three prefixes, and this AC owns `EDMRT`'s retention.

#### EDMDS-04 (Must) -- Ratify `file`-event rule scoping and fix both README falsehoods

**Finding**: CA-122. **Decision**: the Phase-6 scoping is INTENDED; the documentation is wrong.

**Rationale**: `edm-gateguard`'s marker-absent fast path is budgeted at one exec and zero `jq`
(`EDMV4-T07 AC8`). Evaluating hookify rules outside Phase 6 would parse a payload on every Edit and
Write in every session, contradicting a shipped, advertised performance contract. Per AD-DS2 this
same budget is what decides EDMDS-11, so the two requirements now spend it consistently -- v1.0.0
declared it inviolable here and spent it there.

**Rejected**: making `file`-event rules unconditional -- trades a measured fast path for reach
nobody has asked for.

- [ ] AC1: `README.md`'s rule-format section states that `file`-event rules are evaluated only
      while an initiative is in Phase 6, and says why.
- [ ] AC2: the worked example in `README.md` uses a `bash`-event rule, which is unconditional. (The
      v1.0.0 alternative -- keep the `file` example and add a caveat -- is dropped per AD-DS5.)
- [ ] AC3: `README.md:342`'s "Kill switches for all three consumers" is corrected. It is the second
      live falsehood in the same file, and CLAUDE.md contradicts itself on the same point: its
      `EDM_HOOKIFY_*` section opens saying all three consumers honour the switches and closes
      saying `edm-stop-gate` does not, while `edm-stop-gate:95-98` shows it does. The closing
      paragraph is stale and is removed.
- [ ] AC4: `CLAUDE.md`'s existing statement of the scoping is cited by file and line rather than
      restated, and verified to still say what AC1 claims.
- [ ] AC5: an assertion pins the scoping -- a `file`-event block rule does NOT deny outside Phase 6,
      and DOES deny with a marker present.
- [ ] AC6: AC5's control proves the marker is what changes the outcome, not the rule file.

#### EDMDS-05 (Should) -- Name `edm-bash-gate` as a deliverable and make `bin/` membership derived

**Finding**: CA-063. **Decision**: record it retrospectively, as D48 did for an unticketed commit.

- [ ] AC1: `decisions.md` records `bin/edm-bash-gate` as a deliverable of `EDMV4-T45`, noting that
      T45's Target Components omitted it and that three cross-cutting ACs (T50 AC1, T52 AC4,
      T53 AC3) each name four `bin/` scripts and never this one.
- [ ] AC2: whichever cross-cutting assertion enumerates `bin/` membership derives the set live from
      the directory rather than from a literal list, so a seventh script cannot escape the same way.
      The derivation must not match the test file itself (CC2).
- [ ] AC3: AC2's control -- a scratch `bin/` with an extra script is detected. The scratch directory
      uses one of EDMTC-T03's two sanctioned forms (CC8).

### Epic 2 -- Completeness-gate and round semantics

#### EDMDS-06 (Must) -- A lens artifact must carry lens-shaped content from this round

**Finding**: CA-090. **Decision**: option B -- require, per line, a JSON object carrying the lens id,
a severity from the closed set, and this round's number; and at least one such line.

**Rejected**: option A, status quo, which lets `{}` converge a round. Option C, full schema
validation, is rejected as disproportionate: it must track a schema that every lens prompt carries
verbatim, so it acquires a drift surface of its own, and it runs across 14 files on every round
close. Per AD-DS3 the `round` field is exempt from that objection -- it is already in state.

**Coupling, stated**: AC4 makes one malformed line fail a file, and a failed file downgrades a round
that costs $105.28 and 3h15m (verified against EDMV4's archived state file `:198`, `:189`). That
price is only acceptable because **EDMDS-08 is a `Must`** in this version, not the `Should` it was
in v1.0.0. The strict gate and its repair path ship together or neither ships.

- [ ] AC1: the CA-471 completeness check requires each line of `lens-L{N}.jsonl` to be a JSON object
      with a `lens` field matching the file's own N and a `sev` in the closed P0/P1/P2/NOTED set.
- [ ] AC2: each line's `round` must equal the round being completed, so a `lens-L{N}.jsonl` copied
      verbatim from a previous round is rejected (AD-DS3's residual).
- [ ] AC3: a file of `{}` fails. An empty file fails. A file of valid lens lines passes.
- [ ] AC4: one bad line among good ones fails the file. Partial credit for an artifact whose
      integrity is in question is what AD-DS3 rejects. Recorded as decided, with EDMDS-08 named as
      the recovery path.
- [ ] AC5: negative controls for each arm -- empty file, `{}`, wrong lens id, illegal `sev`,
      previous round's `round`, one bad line among four good ones.
- [ ] AC6: all 14 lens agent prompts are updated to state the three required fields and the
      at-least-one-line obligation, in one atomic change. CLAUDE.md's house contract pins those
      copies byte-identical under a smoke assertion, so a partial update fails the suite. v1.0.0 had
      no AC for this at all, and AC1's obligation was invisible to the agents expected to meet it.
- [ ] AC7: the check adds no new required binary and stays within `jq` (CC4).

#### EDMDS-07 (Must) -- A `code` round with no manifest is non-delivery, and the C-4 band says so

**Finding**: CA-091. **Decision**: absence of a pass directory or manifest downgrades the round.

**Rationale**: per AD-DS3, and because EDMV4's D40 named this gap and reserved `CAMGAP` for it
without ever using it. The current `if` has no `else`, so the strongest non-delivery signal
available produces no consequence at all.

**The shipped assertions this changes, which v1.0.0 left unowned.**
`bin/tests/wave6-smoke.sh:1132-1140` -- the `CA471NODIR` band -- asserts that a manifest-less round
stays silent and keeps `round_type=full`, labelled C-4 backward compatibility. This requirement
makes both fail. Six further `code` rounds complete with no pass directory in the same suite
(`:681`, `:697`, `:738`, `:750`, `:778`, `:790`) and become `partial`, so their downstream
`--accept-p2-debt` and `audit-converged` expectations change too. Amending an expectation is not
reducing the count (3.3), but it must be owned, and AC4 and AC5 own it.

- [ ] AC1: when a `code` round's pass directory or manifest is absent at completion, the round is
      recorded `partial` with a message distinguishing this cause from the other three.
- [ ] AC2: a round WITH both present is unaffected -- the existing three checks run as today.
- [ ] AC3: negative control -- the same completion with the manifest restored produces `full`.
- [ ] AC4: `wave6-smoke.sh`'s `CA471NODIR` band is amended: a manifest-less `code` round now warns
      and records `partial`. The band's C-4 intent is preserved by asserting the NEW documented
      behaviour, and the amendment is recorded in `decisions.md` with the old expectation quoted.
- [ ] AC5: the six further `code`-round sites are amended or shown unaffected, one by one, each named
      by line. `run-all.sh` finishes at or above the re-anchored baseline with zero failures.
- [ ] AC6: `CLAUDE.md`'s round-type table records that D40's residual gap is closed. `CAMGAP`'s
      disposition is EDMDS-18's, not this requirement's -- v1.0.0 had both claiming it.
- [ ] AC7: D40's harder half is answered: a `code` round that legitimately produced no manifest --
      an all-lenses-N/A round -- is distinguished from non-delivery, or shown not to exist. If it
      exists, the distinguishing signal is named.

#### EDMDS-08 (Must) -- Make an irreversible downgrade recoverable without a new round

**Finding**: CA-089. **Decision**: add a narrow repair path rather than keep irreversibility
absolute. **Promoted from `Should` to `Must`** -- EDMDS-06 AC4's strictness depends on it.

**Rationale**: the measured price of irreversibility is $105.28 and 3h15m per round, from EDMV4's
own archived state file, and a repair round does not help because `audit-converged` keys on the
latest round's type. Irreversibility was chosen to stop a round self-certifying after the fact; a
repair path re-running the SAME checks against the SAME round cannot self-certify, because it must
pass the checks that failed.

**Residual, stated because R4's v1.0.0 mitigation was true and beside the point**: these checks read
file content, and the caller controls file content. Under EDMDS-06 the bar is one JSON object with a
matching `lens`, a legal `sev` and the right `round` -- forgeable in one `printf`, as
`wave6-smoke.sh:877` already demonstrates for the weaker check. Fabrication passes the checks rather
than bypassing them, and no file-content check can prevent that. What this path protects against is
accidental non-delivery, which is the failure that actually cost $105. AC6 records the limit.

**Inertness, stated because it is a real gap**: promotion restores `full` on the round it repairs,
but `audit-converged` reads the LATEST round's type. If a newer round has since completed, promoting
the older one changes nothing -- the same fact this requirement's own rationale uses to rule out a
repair round. AC7 makes that refusal explicit rather than silent.

- [ ] AC1: a subcommand re-evaluates a downgraded round's completeness and restores `full` only if
      every check that caused the downgrade now passes.
- [ ] AC2: it refuses if any check still fails, naming which.
- [ ] AC3: it cannot promote a round that was never downgraded, and cannot alter any other round.
- [ ] AC4: `audit-round-complete`'s double-completion refusal ("a round may be completed only once")
      is narrowed so it does not also block this path, and the narrowing is proven not to re-open
      double completion.
- [ ] AC5: the three downgrade messages at `bin/edm-state:5163`, `:5177`, `:5193` are swept -- each
      currently states the downgrade is irreversible, which becomes false.
- [ ] AC6: negative control -- a round with a still-missing lens JSONL is refused, and the same
      round with the file restored is promoted. `decisions.md` records that the path detects
      accidental non-delivery and cannot detect fabrication.
- [ ] AC7: promoting a round that is not the latest is refused with a message saying why, since
      `audit-converged` would ignore the promotion.
- [ ] AC8: every promotion is recorded in state with a timestamp and the checks that passed, so a
      promotion is auditable rather than silent.

#### EDMDS-09 (Must) -- Subtract `lenses_na` before materialising `lenses`, and check disjointness

**Finding**: CA-074. **Decision**: fix the subtraction, and check the disjointness the finding also
names.

**Rationale**: explorer 02 established the defect is currently MASKED -- the skill layer always
subtracts before calling, so production shapes look correct and no test exercises the bug. A masked
defect is worse than a visible one: the next caller that does not pre-subtract gets a `round_type`
computed from a double-counted set, with no signal.

- [ ] AC1: `audit-round-start` subtracts `lenses_na` from the materialised `lenses` set.
- [ ] AC2: an assertion calls it WITHOUT pre-subtracting and asserts the resulting **`lenses` array
      itself**, not `round_type`. v1.0.0 asserted `round_type`, which is invariant under the fix --
      unfixed gives `lenses`=14 with `lenses_na`=["L13"] for a union of 14 and reads `full`; fixed
      gives 13 for the same union and also reads `full`. Identical. That was a sixteenth instance of
      the class Goal 3 exists to prevent, inside the document that declares Goal 3.
- [ ] AC3: AC2's control -- the same call against the unfixed logic produces a `lenses` array of a
      different length, so the assertion is proven able to fail.
- [ ] AC4: a hand-passed non-disjoint `lenses`/`lenses_na` pair is rejected, or its double-count is
      corrected. This is CA-074's "never checks disjointness" clause, which v1.0.0's AC1 did not
      reach -- it touched only the materialised branch.
- [ ] AC5: AC4's control -- a disjoint pair is accepted unchanged.
- [ ] AC6: EDMV4's recorded round-1 shape (`lenses` 13, `lenses_na` `["L13"]`, `full`) still reads
      as `full`, so the fix is backward compatible with existing state. Verified against the
      archived state file `:168-186` -- frozen data, so legitimate as an absolute in an AC.

#### EDMDS-10 (Must) -- Marker reconciliation must not leave an active initiative unmarked

**Finding**: CA-075. **Decision**: make removal and recreation a single reconciliation rather than
mutually exclusive branches.

**Rationale**: a marker-absent state makes `edm-gateguard` allow every Edit and Write with no
further checks. This defect silently disables the Phase-6 fact-forcing gate for a genuinely active
initiative -- a security control turning itself off.

- [ ] AC1: `SessionStart` reconciliation removes a stale marker AND writes a correct one when an
      initiative is genuinely at Phase 6, in one pass.
- [ ] AC2: an assertion drives the stale-plus-active case and requires a marker to exist afterwards.
- [ ] AC3: AC2's control -- against the unfixed branches, the same fixture ends with no marker and
      `edm-gateguard` allows a first-touch edit.
- [ ] AC4: the sequence is serialized by a **project-scoped** lock. `with_state_lock` is
      per-initiative and cannot serialize against a `phase-start 6` on a DIFFERENT initiative, which
      is the race CA-075 names; v1.0.0's AC4 named the wrong granularity and offered "or record the
      absence of a lock" as an alternative, which AD-DS5 disallows.
- [ ] AC5: AC4's control -- two concurrent reconciliations against the same project produce one
      marker, and the test fails when the lock is removed.

### Epic 3 -- Resolvers, data-directory lifecycle, duplication

#### EDMDS-11 (Must) -- Converge the resolvers where the budget allows, and reclassify the rest

**Finding**: CA-109, **split**, per AD-DS2.

- `bin/edm-hookify` adopting the CA-500 cross-check: **remediated** by AC1.
- `edm_project_key()` accepting an unchecked `CLAUDE_PROJECT_DIR` for the marker key:
  **`NOTED`** by AC6, because the cross-check IS a `git rev-parse` and `EDMV4-T17 AC7` pins that
  function to succeed with `git` shadowed by a failing stub, on a path `EDMV4-T07 AC8` budgets at
  zero external binaries.

v1.0.0's AC1 and AC5 were mutually exclusive -- AC1 required the cross-check in all three resolvers,
AC5 required `_edm-datadir-lib.sh` to keep spawning `git` only when `CLAUDE_PROJECT_DIR` is unset,
and the cross-check is a `git` call on exactly the path AC5 protects. It also spent the same fast-path
budget EDMDS-04's rationale uses to reject a change. Both audit lanes flagged it; the budget wins.

**Note**: reclassified upward from a consolidation to a correctness gap by Phase 1. Unchecked
`CLAUDE_PROJECT_DIR` acceptance redirects rule discovery and the marker key.

- [ ] AC1: `bin/edm-hookify`'s resolver applies the CA-500 physical-path cross-check, matching
      `edm-state`'s `_resolve_permcheck_project_root` semantics.
- [ ] AC2: `edm-hookify`'s comment claiming parity with `edm-state` is made true by AC1. (It is
      currently false; v1.0.0 offered "either true or removed", which AD-DS5 disallows.)
- [ ] AC3: an assertion drives a `CLAUDE_PROJECT_DIR` pointing outside the git toplevel and requires
      `edm-state` and `edm-hookify` to agree on rejecting it -- stated as the same observable
      outcome for each, since the two have different return types.
- [ ] AC4: AC3's control -- a legitimate `CLAUDE_PROJECT_DIR` is accepted by both.
- [ ] AC5: the no-git-toplevel sub-case is covered: `edm-state:1191-1193` accepts
      `CLAUDE_PROJECT_DIR` unchecked when there is no toplevel at all, so an assertion pins what
      both resolvers do there. v1.0.0's AC3/AC4 drove only the in-git pair, leaving the one sub-case
      where all three still diverge untested.
- [ ] AC6: `_edm-datadir-lib.sh` is unchanged, `EDMV4-T17 AC7`'s failing-`git` stub still passes,
      and `decisions.md` records the marker-key half of CA-109 as `NOTED` with AD-DS2's two reasons:
      the fast-path budget, and that `CLAUDE_PROJECT_DIR` is host-set and therefore outside AD-DS1's
      trust boundary.
- [ ] AC7: `CLAUDE.md:1345`'s record of CA-500 as open is corrected -- the code carries the fix.
      Without this sweep AD-DS2 ships contradicted by its own documentation, a direct Goal 2 breach.
- [ ] AC8: no `<key>.phase6`, `<key>.checked` or `<key>.denials` marker changes name as a result of
      this requirement. Proven by an assertion, since AD-DS4 notes a key rename would trigger on
      upgrade the exact marker-absent failure EDMDS-10 exists to fix.

#### EDMDS-12 (Should) -- One active-initiatives accessor, and no scraping either way

**Finding**: CA-112. **Decision**: `edm-repo-readiness` calls `edm-state active-initiatives` rather
than scraping `edm-state list` through awk.

**Rationale**: the two genuinely disagree -- `cmd_list` prints phase unconditionally,
`cmd_active_initiatives` gates on phases 1 to 6 -- so this is a reporting-correctness fix, not only
deduplication.

- [ ] AC1: `edm-repo-readiness` uses the accessor.
- [ ] AC2: neither consumer parses a human-readable listing. This is the half of CA-112's
      prescription v1.0.0 dropped: AC1 alone is satisfiable by retargeting the same awk at a
      different human-readable stream.
- [ ] AC3: an assertion proves both paths agree on a fixture containing a **phase-0** initiative and
      a **phase-7** initiative. v1.0.0's fixture used an archived and an active initiative, which
      cannot discriminate -- both derivations already exclude `.archived/`. Phases outside 1..6 are
      where the two actually diverge.
- [ ] AC4: AC3's control -- the fixture is shown to distinguish them, so agreement is not vacuous.

#### EDMDS-13 (Must) -- Scope and cap the harvested pattern delta

**Findings**: CA-100, CA-103. **Decision**: key the delta by project as well as audit type, and cap
its growth at a stated number with a stated behaviour at the cap.

**Split from v1.0.0**, which carried 7 AC, four findings and a test fix under one priority. The
`run/` sweep is now EDMDS-20 and the test isolation EDMDS-21.

**Measured on this host**: 144 findings in one host-global delta. Host-local and unverifiable by an
auditor without shell access; it appears in this rationale only, and no AC depends on it.

**Constraint**: AD-DS4.

- [ ] AC1: the harvested delta is keyed by project as well as audit type.
- [ ] AC2: an existing host-global delta is read in place after the change -- not migrated, not
      orphaned. Reading in place is chosen over migration because a delta is append-only harvest
      data with no schema change, so a read-path fallback is strictly cheaper than a move.
- [ ] AC3: AC2's control -- a fixture carrying a pre-change delta is proven readable, and the test
      fails when the compatibility read path is removed.
- [ ] AC4: the cap is **500 entries per (project, audit-type) delta**, and the behaviour at the cap
      is **prune oldest by the entry's `date:` provenance line**, ties broken by position in file.
      v1.0.0 said "a documented cap" with no value, no unit and no choice, which is satisfiable by
      documenting a cap of one million; and "oldest" needs an ordering key, which the append schema
      supplies (`docs/audit-patterns/README.md`, Append Schema).
- [ ] AC5: an assertion drives the delta one entry past the cap and requires the oldest entry gone
      and the newest present, with a control at exactly the cap where nothing is pruned.
- [ ] AC6: gitignore coverage is **not** added: the data directory resolves outside the repository,
      so nothing in it can appear in `git status`. Recorded in `decisions.md` as decided.
      (v1.0.0's AC7 pre-announced this answer inside an AC whose stated purpose was that the answer
      be stated rather than assumed; it is answered here in the SRD and the AC now only records it.)

#### EDMDS-14 (Should) -- One owner for the ASCII sanitizer, and four dependent sites swept

**Finding**: CA-072. **Decision**: extract the literal to one shared owner.

**Note**: three copies, not the five recorded, byte-identical with no drift. The work is smaller
than the finding implies and the count is corrected in `decisions.md`.

**The four live sites that depend on the literal being in place**, which v1.0.0 left unowned.
`wave8-smoke.sh:7877` and `:7891` are `EDMV4-T52 AC6` ordering checks that match the literal
`LC_ALL=C tr -c` inside `edm-gateguard` specifically -- extraction breaks them. `:8996` and `:9027`
are sed mutants driving negative controls -- extraction turns them into no-ops, so those controls
would pass for the wrong reason, which is worse than failing. Explorer 03 found two of four; the
audit identified which four.

- [ ] AC1: one definition; all three call sites use it.
- [ ] AC2: an assertion proves only one definition exists, derived by scanning for the **character
      set** `'\011\012\015\040-\176'` rather than for a marker string. v1.0.0 asserted a marker, and
      the existing assertions already key on one -- so a character-set drift passes today. The scan
      must exclude the test file itself (CC2).
- [ ] AC3: AC2's control -- a re-introduced copy is detected, and the scan is shown not to match its
      own source.
- [ ] AC4: `wave8-smoke.sh:7877` and `:7891` are amended to match the extracted owner, and `:8996`
      and `:9027`'s mutants are retargeted at the new single site. Each of the four is named by line
      in the ticket, and each is proven still able to fail after amendment.
- [ ] AC5: `bin/edm-bash-gate`, which explorer 03 found has no sanitizer of its own, is given one.
      It emits untrusted rule text under EDMDS-02 AC6, so it needs the sanitized half; v1.0.0
      offered "assessed and either given one or recorded as not needing one", and EDMDS-02 settles
      the assessment.

#### EDMDS-15 (Should) -- One `UserPromptExpansion` gate block

**Finding**: CA-121. **Decision**: collapse the five near-identical blocks, preserving the
`edm:implement` copy's extra clause as a parameter rather than losing it.

**Note**: four are byte-identical apart from the gate token; the `implement` copy carries one extra
clause about Gate 3.5. That drift is the reason to consolidate carefully rather than pick one copy.

- [ ] AC1: the blocks are collapsed with no loss of behaviour, including `implement`'s clause.
- [ ] AC2: an assertion proves each of the five skills still gets its correct gate enforcement,
      derived from the skill list live rather than from a literal count of five.
- [ ] AC3: AC2's control -- a skill whose gate is unapproved is still blocked.
- [ ] AC4: Gate 3.5 enforcement is established as implement-specific or not, and the finding
      recorded accordingly. Explorer 03 could not determine it; the determination is part of this
      requirement's work, not an alternative to doing it.

#### EDMDS-16 (Should) -- Converge the four hook consumers on `set -uo pipefail`

**Finding**: CA-106. **Decision**: all four consumers run `set -uo pipefail` without `-e`.
`bin/edm-gateguard` drops `-e`; the other three already match.

**Rationale**: `edm-gateguard` expresses a DENIAL by printing JSON to stdout and exiting 0. Under
`set -e` an unexpected non-zero anywhere before that print aborts the script, and the host reads the
absence of output as no decision -- **fail-open**, on the one consumer whose job is to deny. Without
`-e`, execution continues to the print. So the posture the other three already use is also the
correct one for the gate that matters most, and the split was accidental rather than reasoned.

v1.0.0's AC1 said "one posture, or each difference carries an inline reason", which contradicted its
own Decision line and is the status quo. AD-DS5 disallows the disjunction; the Decision stands alone.

- [ ] AC1: all four consumers run `set -uo pipefail` and none runs `set -e`.
- [ ] AC2: the choice and its consequence are recorded in `CLAUDE.md`.
- [ ] AC3: an assertion injects an internal error into `edm-gateguard` before its decision print and
      requires a DECISION to still be emitted -- not merely that it "never blocks". v1.0.0's AC3
      asserted only the latter, which passes on the fail-open path CA-077 names, because a
      `set -e` abort produces no block and no decision.
- [ ] AC4: AC3's control -- with `set -e` restored, the same injection produces no decision, so the
      assertion is proven able to fail.
- [ ] AC5: the same error-injection check runs against the other three consumers, each of which
      refuses via exit 2 plus stderr, so their documented posture is pinned too.

#### EDMDS-19 (Must) -- An upgrade path for installs already polluted by CA-134

**Finding**: CA-134 (post-fix residual, raised in Phase 3). **Decision**: detect, then migrate on
request, then tighten the ownership test -- in that order. Full reasoning in `upgrade-path.md`.

**Rationale**: CA-134's shipped fix stops new pollution and does nothing about directories EDM
already wrote into. Worse, the C-4 clause that makes the fix safe for legitimate installs is exactly
what keeps a polluted directory claimed: the test accepts any directory carrying `run/` or
`patterns/`, and a polluted foreign directory carries both. An upgraded user keeps writing to the
wrong place indefinitely and 3.3.0 reports nothing.

The discriminator is that a legitimate EDM root contains **only** EDM's own names, while a polluted
one contains those alongside foreign content.

**Ordering is load-bearing**, per AD-DS4: tightening first makes an affected user's EDM resolve to a
fresh empty root and their harvested library vanish from view -- the same failure D46 records,
reached from the other side. Migrating first with no detection means nobody knows to run it.

**Constraint**: AD-DS4. Compatibility checked, not assumed: `wave8-smoke.sh:10302-10308`'s C-4
fixture builds `patterns/code-audit.md` with no foreign content beside it, so it still adopts under
the tightened rule.

- [ ] AC1: `edm-state validate` reports a polluted data directory as an informational anomaly,
      naming the polluted path, EDM's contents within it, and the correctly-resolved destination.
      It does not refuse, block or delete.
- [ ] AC2: `edm-state session-start` surfaces the same condition, so it is seen without being asked
      for.
- [ ] AC3: `edm-state migrate-data-dir` moves `patterns/`, `run/` and any `edm/` subtree from the
      polluted root to the resolved one, and removes the `.edm-owned` sentinel EDM wrote there. It
      touches nothing that is not EDM's, and it is opt-in -- never run automatically on upgrade.
- [ ] AC4: on a destination collision the migration refuses and names both paths. Merging two
      harvested libraries silently is worse than doing nothing.
- [ ] AC5: `_edm_datadir_owned()`'s C-4 footprint clause accepts the footprint only when the
      directory contains EDM names and nothing else.
- [ ] AC6: the C-4 fixture at `wave8-smoke.sh:10302-10308` still passes unchanged, and a new
      assertion proves a directory carrying `patterns/` **alongside** foreign content is refused --
      with a control proving the same directory without the foreign content is accepted.
- [ ] AC7: `CHANGELOG.md` states plainly that 3.2.x and earlier wrote into other plugins' data
      directories, and how a user checks. Users who never upgrade are reachable by no other channel,
      and that limit is recorded in `decisions.md`.

#### EDMDS-20 (Must) -- Sweep `run/` on a stated policy without destroying ownership

**Finding**: CA-105, split out of v1.0.0's EDMDS-13.

**Constraint**: AD-DS4, in its sharpest form. The ownership clause is `run/` **OR** `patterns/`, so a
pre-D46 install whose only footprint is `run/` markers loses ownership the moment the sweep removes
the last entry.

- [ ] AC1: `run/` marker entries older than a stated age are removed on a stated trigger, both
      recorded in `CLAUDE.md`.
- [ ] AC2: an assertion proves a stale marker is swept and a current one is not.
- [ ] AC3: the fixture asserts a **delta** -- markers the sweep created are gone -- not a total
      count. v1.0.0's AC5 wrote this host's 85 into an AC, which D15 forbids ("write the delta, not
      the total") and which running the DoD suite makes stale by construction.
- [ ] AC4: `run/` itself is never removed, only its contents, and an assertion proves the directory
      survives a sweep that empties it. Without this the sweep destroys the ownership proof AD-DS4
      protects.
- [ ] AC5: AC4's control -- a fixture where `run/` is removed is shown to lose ownership, so AC4 is
      proven to be testing something.

#### EDMDS-21 (Must) -- Stop the test suite writing to the real host data directory

**Finding**: `wave6-smoke.sh`'s unguarded writes, established in Phase 1. Split out of v1.0.0's
EDMDS-13.

`wave6-smoke.sh`'s T06 band isolates `HOME` and `CLAUDE_PROJECT_DIR` but never
`CLAUDE_PLUGIN_DATA`; the file has zero occurrences of that variable, against 93 in `wave8`, 19 in
`wave7` and 3 in the timing suite. This is the mechanism that produced the pollution EDMDS-19
remediates, so leaving it unfixed re-creates the damage on every suite run.

- [ ] AC1: `wave6-smoke.sh`'s T06 band isolates `CLAUDE_PLUGIN_DATA` alongside `HOME` and
      `CLAUDE_PROJECT_DIR`.
- [ ] AC2: the whole-suite guarantee **extracts** EDMTC's shipped assertion at
      `wave7-smoke.sh:10186-10228` into a helper both suites call. It cannot be extended in place:
      its own header states it is "deliberately the LAST thing this file does, so it observes every
      case above it", so it is scoped to the suite that hosts it by design. Copying it into `wave6`
      would create a second owner -- the defect class EDMDS-14 and EDMDS-15 exist to fix, reproduced
      inside the document that fixes it. v1.0.0's AC6 re-specified it from scratch, which is worse
      still. The helper keeps the either-arm three-assertion shape so the suite total does not move
      with the host's data-directory situation.
- [ ] AC3: AC2's control writes to the real host data directory deliberately and is detected. Named
      concretely: the suite run being checked is `run-all.sh`, not "a suite run".

### Epic 4 -- Record-keeping and closure

#### EDMDS-17 (Must) -- Record every decision, and give "record of closure" mechanical backing

- [ ] AC1: each ratified, revised or rejected decision from Gate 2+3 is recorded in `decisions.md`
      with a D-number, including any this SRD proposed that the gate overturns.
- [ ] AC2: EDMV4's D51, which said these eighteen would stay unowned, is marked superseded with a
      pointer to EDMDS.
- [ ] AC3: the four reclassifications are recorded against their finding ids, so the archived
      ledger's text is not the only account: CA-114 **split** (documentation half remediated,
      unbounded-`regex_match` half `NOTED`), CA-109 **upgraded then split** (hookify half
      remediated, marker-key half `NOTED`), CA-072 **corrected** (three copies, not five), and
      CA-134 **extended** with the post-fix residual EDMDS-19 owns. v1.0.0 described CA-114 as
      "descoped", a status the canonical vocabulary does not admit.
- [ ] AC4: every inherited finding carries a terminal status and, where remediated, a
      `resolved_commit`. This is what makes 3.3's "EDMDS is the record of closure" checkable; v1.0.0
      asserted it with no ledger, no `resolved_commit` and no DoD item.
- [ ] AC5: an assertion or check proves no inherited finding is left without a terminal status, so
      closure cannot be claimed while one is silently open.

#### EDMDS-18 (Could) -- Retire or re-scope the unused reserved prefixes

`CAMGAP` was reserved by D40 for the gap EDMDS-07 closes. `EDMRT`'s retention is decided by
EDMDS-03 AC3; this requirement owns the other three.

- [ ] AC1: `CAMGAP`, `LINUXV` and `EVALB` are each released or retained with a stated reason,
      recorded in `decisions.md`. `CAMGAP` is expected to be released once EDMDS-07 lands, and this
      requirement is the single owner of that call.

## 6. Risks

Risk rows name requirements and AC in full (`EDMDS-13 AC4`, not `AC4`) -- v1.0.0 used bare AC
numbers, ambiguous across eighteen requirements.

| ID | Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|---|
| R1 | In `json` mode the rule author's `message` no longer reaches the model, losing the field's main value | Medium | Certain by design | Accepted explicitly in EDMDS-02. Recorded here so a later reader finds a decision rather than rediscovering it as a bug. Not a probabilistic risk; listed because its cost is real |
| R2 | EDMDS-13, EDMDS-19 or EDMDS-20 re-breaks an existing install, as a stricter ownership test already did once (D46) | High | Medium | AD-DS4. `EDMDS-13 AC3`, `EDMDS-19 AC6` and `EDMDS-20 AC5` each require a test that fails without the compatibility path |
| R3 | `bin/edm-gateguard` exceeds `EDMV4-T11 AC1`'s 660-line bound | Medium -- it gates the Definition of Done | High -- one line of headroom, and EDMDS-02, EDMDS-14 and EDMDS-16 all touch the file | Sequence the three so the file is measured after each; if 660 is exceeded, amend the bound by recorded decision (D42, D47, D49). Note the amendment edits a file under `.archived/`, which `edm-lint-artifacts` never scans |
| R4 | EDMDS-08's repair path is used to launder a fabricated lens artifact | Medium | Low | None available, and that is the finding. The checks read file content and the caller controls file content, so fabrication passes rather than bypasses. `EDMDS-08 AC6` records that the path detects accidental non-delivery only. v1.0.0's mitigation ("it must pass the checks") was true and did not address this |
| R5 | A future `jq` raises Oniguruma's retry limit, reopening CA-114 at larger inputs | Medium | Low | `EDMDS-01 AC2` fails, and `AC4` fixes the input length as a named constant so a raised limit does not silently leave the assertion green |
| R6 | A future `jq` REMOVES the retry limit | High | Very low | **The assertion hangs rather than fails.** `run-all.sh` wedges synchronously, with no `timeout` binary available under CC4 and no wall-clock guard by EDMDS-01's own decision. `EDMDS-01 AC4` requires an inline comment at the assertion site naming this row, so a maintainer facing a wedged suite finds the cause at the line. Split from R5 in v1.1.0: v1.0.0 merged the two and claimed AC2 fails in both branches, which is false in this one |
| R7 | The proposal chain has one author and no writer/verifier separation | High | Certain | `planning.md`'s synthesis, explorer 04's measurement, the go/no-go, the Gate 1 record and all twenty-one decisions share one author. CLAUDE.md's guard **D1** names writer/verifier separation as this plugin's core quality mechanism, and it is absent from this chain. Mitigation is external: Gate 2+3's reviewer is the only independent verifier, and the two-lane Phase 3 audit -- which produced this revision -- is the only independent check performed. v1.0.0 omitted this row and claimed "the explorers deliberately withheld recommendations", true of 01-03 and false of 04 |
| R8 | Twenty-one decisions ratified in one gate round invites rubber-stamping | Medium | Medium | The gate is asked to ratify 5 architecture decisions, 21 requirements and several sub-decisions embedded in AC. Six requirements carry an explicit **Rejected** block; the other fifteen state one decision and its rationale. v1.0.0 claimed all eighteen stated a rejected option, which was false and would have given a reviewer false assurance of having alternatives to weigh |
| R9 | EDMDS-08's promotion is inert when the downgraded round is not the latest | Medium | Medium | `audit-converged` keys on the latest round's type -- the same fact EDMDS-08's rationale uses to rule out a repair round. `EDMDS-08 AC7` makes the refusal explicit and says why, rather than promoting a round to no effect |
| R10 | EDMDS-02 rewrites text whose provenance is an attributed MIT reuse pinned by tests | Medium | Medium | `NOTICE` states which strings are reused. D49's order applies: amend the text first, then any claim about it. `EDMDS-02 AC10` carries it; v1.0.0 named it in neither the DoD nor the risks |
| R11 | The 4048 baseline is anchored to no commit and two `bin/`-touching commits have landed since | Medium | Certain | Definition of Done item 2 re-measures and re-anchors to a sha as the first act of Phase 6 (`EDMDS-T01`), so every later comparison has a fixed reference |

## --- Ticket List ---

**Generated From**: srd.md v1.1.0

Sizes: **XS** under an hour, **S** a half day, **M** a day, **L** two to three days. No XL -- an XL
ticket is decomposed before work starts. Every ticket adding an assertion adds its negative control
in the same ticket (CC1); new bands in `wave8-smoke.sh` go BEFORE its own `Results:`/`exit` lines
(CC5).

`Target Components` are repository-relative paths under `plugins/edm/` unless stated otherwise.

### EDMDS-T01: Re-anchor the run-all baseline to a commit

- **Requirement**: Definition of Done item 2, R11
- **Size**: XS
- **Depends On**: none
- **Target Components**: `SRD/edm/EDMDS__design-docket/decisions.md`
- **AC**:
  - [ ] AC1: `/bin/bash plugins/edm/bin/tests/run-all.sh` is run on the current HEAD and the passed
        and failed counts recorded in `decisions.md` alongside the sha.
  - [ ] AC2: if the figure is below 4048, the shortfall is investigated and explained before any
        other ticket starts -- a baseline nobody can reproduce is not a baseline.

### EDMDS-T02: Correct the hookify cost-bounding header and pin the retry-limit dependency

- **Requirement**: EDMDS-01 AC1, AC7
- **Size**: S
- **Depends On**: EDMDS-T01
- **Target Components**: `bin/edm-hookify`, `CLAUDE.md`, `SRD/edm/EDMDS__design-docket/decisions.md`
- **AC**:
  - [ ] AC1: the header no longer claims the 64 KiB cap bounds evaluation cost; it names
        Oniguruma's `retry-limit-in-match` as a `jq` property, and notes `jq` carries no version floor.
  - [ ] AC2: `CLAUDE.md`'s hookify section records the dependency and the residual.
  - [ ] AC3: `decisions.md` records CA-114's split -- documentation half remediated, unbounded
        `regex_match` half `NOTED` with explorer 04's measurement as the reason.
  - [ ] AC4: the decision to add no wall-clock or complexity guard is recorded as decided.

### EDMDS-T03: Assert the catastrophic-pattern path through evaluator and consumer

- **Requirement**: EDMDS-01 AC2-AC6
- **Size**: M
- **Depends On**: EDMDS-T02
- **Target Components**: `bin/tests/wave8-smoke.sh`
- **AC**:
  - [ ] AC1: a band drives `(a+)+$` against a non-matching suffix through `bin/edm-hookify eval bash`
        and requires exit 1, the rule FILE named on stderr, and no block.
  - [ ] AC2: a companion assertion drives the same fixture through `bin/edm-bash-gate` and requires
        exit 0 with no block.
  - [ ] AC3: the fixture's input length is a named constant with an inline comment naming R6.
  - [ ] AC4: a benign sibling rule in the same directory still fires (CA-030 isolation).
  - [ ] AC5: negative control -- a benign pattern produces no setup error.

### EDMDS-T04: Carry the rule file path across the hookify output contract

- **Requirement**: EDMDS-02 AC1
- **Size**: M
- **Depends On**: EDMDS-T01
- **Target Components**: `bin/edm-hookify`, `bin/edm-gateguard`, `CLAUDE.md`,
  `bin/tests/wave8-smoke.sh`
- **AC**:
  - [ ] AC1: the `M` record at `bin/edm-hookify:369` gains a `scrub($path)` field.
  - [ ] AC2: `hookify_emit_match` (`:414-425`) emits it and `edm-gateguard:647` captures it.
  - [ ] AC3: `EDMV4-T44`'s exit/output contract is amended to the new field count.
  - [ ] AC4: both places `CLAUDE.md` documents the three-field shape are swept.
  - [ ] AC5: an assertion proves the path is present in the match record, with a control proving it
        was absent before.

### EDMDS-T05: Separate the channels in GateGuard's json deny mode

- **Requirement**: EDMDS-02 AC2-AC5, AC9
- **Size**: M
- **Depends On**: EDMDS-T04
- **Target Components**: `bin/edm-gateguard`, `README.md`, `CLAUDE.md`, `bin/tests/wave8-smoke.sh`
- **AC**:
  - [ ] AC1: `permissionDecisionReason` carries only EDM-authored text plus rule id and rule file path.
  - [ ] AC2: the author's `message` goes to stderr, attributed to its file.
  - [ ] AC3: an assertion proves a `message` mimicking EDM's own fact-list prose cannot reach
        `permissionDecisionReason`.
  - [ ] AC4: control -- the same message IS on stderr, distinguishing "suppressed" from "moved".
  - [ ] AC5: `CLAUDE.md` and `README.md` state the per-deny-mode channel behaviour.
  - [ ] AC6: `bin/edm-gateguard` line count recorded after this ticket (R3).

### EDMDS-T06: Label the untrusted half at the three single-channel surfaces

- **Requirement**: EDMDS-02 AC6, AC7
- **Size**: M
- **Depends On**: EDMDS-T05, EDMDS-T21
- **Target Components**: `bin/edm-gateguard`, `bin/edm-bash-gate`, `bin/tests/wave8-smoke.sh`
- **AC**:
  - [ ] AC1: `EDM_GATEGUARD_DENY_MODE=exit-code` and `bin/edm-bash-gate` emit an EDM-authored label
        line naming rule id and file, then the sanitized untrusted text -- the
        `stop_gate_emit_blocking` shape.
  - [ ] AC2: `bin/edm-stop-gate` is confirmed to already do this and is not changed.
  - [ ] AC3: an assertion proves the label is unsanitized and the message half is sanitized, at both
        changed sites.
  - [ ] AC4: control -- the assertion fails when the two halves are concatenated unlabelled.
  - [ ] AC5: `bin/edm-gateguard` line count recorded after this ticket (R3).

### EDMDS-T07: Re-assess CA-196 and honour D49's ordering on the reused text

- **Requirement**: EDMDS-02 AC8, AC10
- **Size**: S
- **Depends On**: EDMDS-T05
- **Target Components**: `bin/edm-lint-staged-artifacts`, `NOTICE`,
  `SRD/edm/EDMDS__design-docket/decisions.md`
- **AC**:
  - [ ] AC1: CA-196's site at `:151` is re-assessed against AD-DS1; its `NOTED` status is reaffirmed
        with a current reason or superseded by a fix.
  - [ ] AC2: any reused MIT string named in `NOTICE` is amended before a claim about it changes.
  - [ ] AC3: both outcomes recorded in `decisions.md`.

### EDMDS-T08: Close D26's condition on the MultiEdit arm

- **Requirement**: EDMDS-03
- **Size**: S
- **Depends On**: EDMDS-T01
- **Target Components**: `SRD/edm/EDMDS__design-docket/decisions.md`
- **AC**:
  - [ ] AC1: D26's condition recorded closed, naming `EDMTC-T04` as substitute evidence and stating
        the original re-test was never performed.
  - [ ] AC2: the residual recorded as a statement about this host's observation history, not as a
        verified negative existential.
  - [ ] AC3: `EDMRT` recorded as retained for live runtime verification.

### EDMDS-T09: Fix both README falsehoods and pin the file-event scoping

- **Requirement**: EDMDS-04
- **Size**: M
- **Depends On**: EDMDS-T01
- **Target Components**: `README.md`, `CLAUDE.md`, `bin/tests/wave8-smoke.sh`
- **AC**:
  - [ ] AC1: the rule-format section states `file`-event rules evaluate only in Phase 6, and why.
  - [ ] AC2: the worked example uses a `bash`-event rule.
  - [ ] AC3: `README.md:342`'s "Kill switches for all three consumers" corrected, and CLAUDE.md's
        stale closing paragraph in the `EDM_HOOKIFY_*` section removed.
  - [ ] AC4: `CLAUDE.md`'s existing scoping statement cited by file and line, and verified.
  - [ ] AC5: an assertion proves a `file`-event block rule does not deny outside Phase 6 and does
        deny with a marker present.
  - [ ] AC6: control -- the marker is what changes the outcome, not the rule file.

### EDMDS-T10: Record edm-bash-gate as a deliverable and derive bin/ membership live

- **Requirement**: EDMDS-05
- **Size**: S
- **Depends On**: EDMDS-T01
- **Target Components**: `SRD/edm/EDMDS__design-docket/decisions.md`, `bin/tests/wave8-smoke.sh`
- **AC**:
  - [ ] AC1: `decisions.md` records `bin/edm-bash-gate` as a deliverable of `EDMV4-T45`, naming
        T50 AC1, T52 AC4 and T53 AC3 as the three cross-cutting ACs that omitted it.
  - [ ] AC2: the cross-cutting `bin/` enumeration derives the set live from the directory, and the
        derivation does not match the test file itself (CC2).
  - [ ] AC3: control -- a scratch `bin/` with an extra script is detected, using one of EDMTC-T03's
        two sanctioned scratch forms (CC8).

### EDMDS-T11: Require lens-shaped, current-round content in the completeness check

- **Requirement**: EDMDS-06 AC1-AC5, AC7
- **Size**: M
- **Depends On**: EDMDS-T01
- **Target Components**: `bin/edm-state`, `bin/tests/wave6-smoke.sh`
- **AC**:
  - [ ] AC1: each line of `lens-L{N}.jsonl` must be a JSON object with `lens` matching the file's N
        and `sev` in the closed P0/P1/P2/NOTED set.
  - [ ] AC2: each line's `round` must equal the round being completed.
  - [ ] AC3: `{}` fails; an empty file fails; valid lens lines pass.
  - [ ] AC4: one bad line among good ones fails the file.
  - [ ] AC5: negative controls for every arm -- empty, `{}`, wrong lens id, illegal `sev`, previous
        round, one bad line among four good.
  - [ ] AC6: no new required binary; stays within `jq` (CC4).

### EDMDS-T12: Update all 14 lens prompts to state the required fields

- **Requirement**: EDMDS-06 AC6
- **Size**: M
- **Depends On**: EDMDS-T11
- **Target Components**: `agents/edm-audit-*.md` (14 files), `CLAUDE.md`
- **AC**:
  - [ ] AC1: every lens prompt states the three required fields and the at-least-one-line obligation.
  - [ ] AC2: the change is atomic across all 14 -- CLAUDE.md's house contract pins the copies
        byte-identical under a smoke assertion, so a partial update fails the suite.
  - [ ] AC3: the suite passes, proving the copies are still byte-identical.

### EDMDS-T13: Downgrade a manifest-less code round

- **Requirement**: EDMDS-07 AC1-AC3, AC6, AC7
- **Size**: M
- **Depends On**: EDMDS-T11
- **Target Components**: `bin/edm-state`, `CLAUDE.md`, `bin/tests/wave6-smoke.sh`
- **AC**:
  - [ ] AC1: an absent pass directory or manifest records the round `partial`, with a message
        distinguishing this cause from the other three.
  - [ ] AC2: a round with both present is unaffected.
  - [ ] AC3: control -- the manifest restored produces `full`.
  - [ ] AC4: `CLAUDE.md`'s round-type table records D40's residual as closed.
  - [ ] AC5: D40's harder half answered -- a legitimately manifest-less `code` round is distinguished
        from non-delivery, or shown not to exist.

### EDMDS-T14: Amend the seven wave6 code-round sites the downgrade changes

- **Requirement**: EDMDS-07 AC4, AC5
- **Size**: M
- **Depends On**: EDMDS-T13
- **Target Components**: `bin/tests/wave6-smoke.sh`,
  `SRD/edm/EDMDS__design-docket/decisions.md`
- **AC**:
  - [ ] AC1: the `CA471NODIR` band at `:1132-1140` asserts the new documented behaviour -- warn and
        record `partial` -- preserving its C-4 intent.
  - [ ] AC2: the six further `code`-round sites at `:681`, `:697`, `:738`, `:750`, `:778`, `:790`
        are each amended or shown unaffected, named one by one. All six are P2-debt bands
        (`PDEBT1` through `PDEBT5`, with `PDEBT3` completing two rounds), which is why AC3's
        `--accept-p2-debt` re-check is not optional.
  - [ ] AC3: downstream `--accept-p2-debt` and `audit-converged` expectations at those sites are
        re-checked.
  - [ ] AC4: `decisions.md` records the amendment with the old expectation quoted.
  - [ ] AC5: `run-all.sh` finishes at or above `EDMDS-T01`'s re-anchored figure with zero failures,
        and no assertion is deleted.

### EDMDS-T15: Add the round-repair path

- **Requirement**: EDMDS-08
- **Size**: M
- **Depends On**: EDMDS-T13
- **Target Components**: `bin/edm-state`, `bin/tests/wave6-smoke.sh`,
  `SRD/edm/EDMDS__design-docket/decisions.md`
- **AC**:
  - [ ] AC1: a subcommand re-evaluates a downgraded round and restores `full` only if every check
        that caused the downgrade now passes.
  - [ ] AC2: it refuses if any check still fails, naming which.
  - [ ] AC3: it cannot promote a never-downgraded round and cannot alter any other round.
  - [ ] AC4: `audit-round-complete`'s double-completion refusal is narrowed without re-opening
        double completion, proven by assertion.
  - [ ] AC5: the three downgrade messages at `bin/edm-state:5163`, `:5177`, `:5193` are swept.
  - [ ] AC6: control -- a still-missing lens JSONL is refused; restored, it is promoted.
  - [ ] AC7: promoting a non-latest round is refused with a message saying why.
  - [ ] AC8: every promotion recorded in state with timestamp and passing checks.
  - [ ] AC9: `decisions.md` records that the path detects accidental non-delivery and cannot detect
        fabrication (R4).

### EDMDS-T16: Subtract lenses_na and reject non-disjoint pairs

- **Requirement**: EDMDS-09
- **Size**: M
- **Depends On**: EDMDS-T01
- **Target Components**: `bin/edm-state`, `bin/tests/wave6-smoke.sh`
- **AC**:
  - [ ] AC1: `audit-round-start` subtracts `lenses_na` from the materialised `lenses` set.
  - [ ] AC2: an assertion calls it without pre-subtracting and asserts the `lenses` ARRAY, not
        `round_type`.
  - [ ] AC3: control -- against unfixed logic the array length differs, so AC2 can fail.
  - [ ] AC4: a hand-passed non-disjoint pair is rejected or its double-count corrected.
  - [ ] AC5: control -- a disjoint pair is accepted unchanged.
  - [ ] AC6: EDMV4's round-1 shape (13 / `["L13"]`) still reads `full`.

### EDMDS-T17: Reconcile the Phase-6 marker in one locked pass

- **Requirement**: EDMDS-10
- **Size**: M
- **Depends On**: EDMDS-T01
- **Target Components**: `bin/edm-state`, `hooks/hooks.json`, `bin/tests/wave6-smoke.sh`
- **AC**:
  - [ ] AC1: `SessionStart` reconciliation removes a stale marker and writes a correct one in one pass.
  - [ ] AC2: an assertion drives the stale-plus-active case and requires a marker afterwards.
  - [ ] AC3: control -- against the unfixed branches the fixture ends with no marker and
        `edm-gateguard` allows a first-touch edit.
  - [ ] AC4: the sequence is serialized by a project-scoped lock, not `with_state_lock`'s
        per-initiative one.
  - [ ] AC5: control -- two concurrent reconciliations on one project produce one marker, and the
        test fails with the lock removed.

### EDMDS-T18: Apply the CA-500 cross-check in hookify and sweep the stale record

- **Requirement**: EDMDS-11
- **Size**: M
- **Depends On**: EDMDS-T04
- **Target Components**: `bin/edm-hookify`, `CLAUDE.md`, `bin/tests/wave8-smoke.sh`,
  `SRD/edm/EDMDS__design-docket/decisions.md`
- **AC**:
  - [ ] AC1: `bin/edm-hookify`'s resolver applies the physical-path cross-check.
  - [ ] AC2: its parity comment becomes true.
  - [ ] AC3: an assertion drives a `CLAUDE_PROJECT_DIR` outside the git toplevel and requires
        `edm-state` and `edm-hookify` to reject it, stated as the same observable outcome for each.
  - [ ] AC4: control -- a legitimate value is accepted by both.
  - [ ] AC5: the no-git-toplevel sub-case (`edm-state:1191-1193`) is pinned for both.
  - [ ] AC6: `bin/_edm-datadir-lib.sh` unchanged; `EDMV4-T17 AC7`'s failing-`git` stub still passes;
        `decisions.md` records the marker-key half of CA-109 as `NOTED` with AD-DS2's two reasons.
  - [ ] AC7: `CLAUDE.md:1345`'s "CA-500, open" corrected.
  - [ ] AC8: an assertion proves no `<key>.phase6`, `<key>.checked` or `<key>.denials` marker name
        changes.

### EDMDS-T19: Route repo-readiness through the accessor

- **Requirement**: EDMDS-12
- **Size**: S
- **Depends On**: EDMDS-T01
- **Target Components**: `bin/edm-repo-readiness`, `bin/tests/wave7-smoke.sh`
- **AC**:
  - [ ] AC1: `edm-repo-readiness` calls `edm-state active-initiatives`.
  - [ ] AC2: neither consumer parses a human-readable listing.
  - [ ] AC3: an assertion proves both paths agree on a fixture with a phase-0 and a phase-7
        initiative.
  - [ ] AC4: control -- the fixture is shown to distinguish them, so agreement is not vacuous.

### EDMDS-T20: Key the harvested delta by project and cap it

- **Requirement**: EDMDS-13
- **Size**: M
- **Depends On**: EDMDS-T01
- **Target Components**: `bin/edm-state`, `docs/audit-patterns/README.md`,
  `bin/tests/wave6-smoke.sh`
- **AC**:
  - [ ] AC1: the delta is keyed by project as well as audit type.
  - [ ] AC2: an existing host-global delta is read in place after the change.
  - [ ] AC3: control -- a pre-change fixture is readable, and the test fails with the compatibility
        read path removed.
  - [ ] AC4: the cap is 500 entries per (project, audit-type), pruning oldest by the entry's `date:`
        line, ties by file position; documented in `docs/audit-patterns/README.md`.
  - [ ] AC5: an assertion drives one entry past the cap -- oldest gone, newest present -- with a
        control at exactly the cap where nothing is pruned.
  - [ ] AC6: `decisions.md` records that no gitignore entry is added, and why.

### EDMDS-T21: Extract the ASCII sanitizer to one owner

- **Requirement**: EDMDS-14 AC1-AC3, AC5
- **Size**: M
- **Depends On**: EDMDS-T01
- **Target Components**: `bin/_edm-datadir-lib.sh` or a new shared lib, `bin/edm-gateguard`,
  `bin/edm-stop-gate`, `bin/edm-bash-gate`, `bin/tests/wave8-smoke.sh`
- **AC**:
  - [ ] AC1: one definition of `'\011\012\015\040-\176'`; all three existing call sites use it.
  - [ ] AC2: an assertion proves one definition exists, scanning for the CHARACTER SET rather than a
        marker string, excluding the test file itself (CC2).
  - [ ] AC3: control -- a re-introduced copy is detected, and the scan does not match its own source.
  - [ ] AC4: `bin/edm-bash-gate` is given a sanitizer, since EDMDS-02 AC6 makes it emit untrusted
        text.
  - [ ] AC5: `bin/edm-gateguard` line count recorded after this ticket (R3).

### EDMDS-T22: Sweep the four wave8 sites that depend on the sanitizer literal

- **Requirement**: EDMDS-14 AC4
- **Size**: S
- **Depends On**: EDMDS-T21
- **Target Components**: `bin/tests/wave8-smoke.sh`
- **AC**:
  - [ ] AC1: `:7877` and `:7891` (`EDMV4-T52 AC6` ordering) are amended to match the extracted owner.
  - [ ] AC2: `:8996` and `:9027`'s sed mutants are retargeted at the new single site, so they are not
        silently no-ops.
  - [ ] AC3: each of the four is proven still able to fail after amendment -- a negative control per
        site, not per ticket.

### EDMDS-T23: Collapse the five UserPromptExpansion gate blocks

- **Requirement**: EDMDS-15
- **Size**: M
- **Depends On**: EDMDS-T01
- **Target Components**: `hooks/hooks.json`, `bin/edm-state`, `bin/tests/wave7-smoke.sh`
- **AC**:
  - [ ] AC1: the blocks are collapsed with no loss of behaviour, including `implement`'s Gate 3.5
        clause, carried as a parameter.
  - [ ] AC2: an assertion proves each of the five skills still gets its correct gate enforcement,
        derived from the skill list live rather than a literal five.
  - [ ] AC3: control -- a skill whose gate is unapproved is still blocked.
  - [ ] AC4: whether Gate 3.5 enforcement is implement-specific is established and recorded.

### EDMDS-T24: Converge the four hook consumers on set -uo pipefail

- **Requirement**: EDMDS-16
- **Size**: S
- **Depends On**: EDMDS-T01
- **Target Components**: `bin/edm-gateguard`, `bin/edm-bash-gate`, `bin/edm-stop-gate`,
  `bin/edm-hookify`, `CLAUDE.md`, `bin/tests/wave8-smoke.sh`
- **AC**:
  - [ ] AC1: all four run `set -uo pipefail`; none runs `set -e`.
  - [ ] AC2: the choice and its consequence recorded in `CLAUDE.md`.
  - [ ] AC3: an assertion injects an internal error into `edm-gateguard` before its decision print
        and requires a DECISION to still be emitted -- not merely that it never blocks.
  - [ ] AC4: control -- with `set -e` restored, the same injection produces no decision.
  - [ ] AC5: the same injection check runs against the other three, pinning their exit-2 posture.
  - [ ] AC6: `bin/edm-gateguard` line count recorded after this ticket (R3).

### EDMDS-T25: Detect and report a polluted data directory

- **Requirement**: EDMDS-19 AC1, AC2, AC7
- **Size**: M
- **Depends On**: EDMDS-T01
- **Target Components**: `bin/edm-state`, `CHANGELOG.md`, `bin/tests/wave8-smoke.sh`,
  `SRD/edm/EDMDS__design-docket/decisions.md`
- **AC**:
  - [ ] AC1: `edm-state validate` reports the condition as an informational anomaly naming the
        polluted path, EDM's contents within it, and the resolved destination. It never refuses,
        blocks or deletes.
  - [ ] AC2: `edm-state session-start` surfaces the same condition.
  - [ ] AC3: an assertion drives a fixture directory carrying EDM artifacts alongside foreign
        content and requires the anomaly, with a control on a clean EDM root that reports nothing.
  - [ ] AC4: `CHANGELOG.md` states that 3.2.x and earlier wrote into other plugins' data directories,
        and how to check.
  - [ ] AC5: `decisions.md` records that users who never upgrade are reachable by no other channel.

### EDMDS-T26: Add the opt-in data-directory migration

- **Requirement**: EDMDS-19 AC3, AC4
- **Size**: M
- **Depends On**: EDMDS-T25
- **Target Components**: `bin/edm-state`, `bin/tests/wave8-smoke.sh`
- **AC**:
  - [ ] AC1: `edm-state migrate-data-dir` moves `patterns/`, `run/` and any `edm/` subtree to the
        resolved root and removes the `.edm-owned` sentinel EDM wrote in the polluted one.
  - [ ] AC2: it touches nothing that is not EDM's -- proven by a fixture whose foreign files are
        checked present afterwards.
  - [ ] AC3: it is never invoked automatically; no hook or upgrade path calls it.
  - [ ] AC4: on a destination collision it refuses and names both paths.
  - [ ] AC5: control -- a non-colliding migration succeeds, so AC4 is not vacuous.

### EDMDS-T27: Tighten the C-4 ownership footprint

- **Requirement**: EDMDS-19 AC5, AC6
- **Size**: S
- **Depends On**: EDMDS-T25, EDMDS-T26
- **Target Components**: `bin/_edm-datadir-lib.sh`, `bin/tests/wave8-smoke.sh`
- **AC**:
  - [ ] AC1: `_edm_datadir_owned()`'s footprint clause accepts the footprint only when the directory
        contains EDM names and nothing else.
  - [ ] AC2: the C-4 fixture at `wave8-smoke.sh:10302-10308` passes unchanged.
  - [ ] AC3: a new assertion proves a directory carrying `patterns/` alongside foreign content is
        refused.
  - [ ] AC4: control -- the same directory without the foreign content is accepted.
  - [ ] AC5: this ticket lands only after `EDMDS-T25` and `EDMDS-T26`. Landing it first strands an
        affected user's harvested library (AD-DS4, R2).

### EDMDS-T28: Sweep run/ without destroying the ownership proof

- **Requirement**: EDMDS-20
- **Size**: M
- **Depends On**: EDMDS-T01
- **Target Components**: `bin/_edm-datadir-lib.sh`, `bin/edm-state`, `CLAUDE.md`,
  `bin/tests/wave8-smoke.sh`
- **AC**:
  - [ ] AC1: `run/` entries older than a stated age are removed on a stated trigger, both recorded in
        `CLAUDE.md`.
  - [ ] AC2: an assertion proves a stale marker is swept and a current one is not.
  - [ ] AC3: the fixture asserts a DELTA -- markers the fixture created are gone -- never a total
        count (D15).
  - [ ] AC4: `run/` itself survives a sweep that empties it, proven by assertion.
  - [ ] AC5: control -- a fixture where `run/` is removed is shown to lose ownership.

### EDMDS-T29: Isolate CLAUDE_PLUGIN_DATA in wave6

- **Requirement**: EDMDS-21
- **Size**: S
- **Depends On**: EDMDS-T01
- **Target Components**: `bin/tests/wave6-smoke.sh`, `bin/tests/wave7-smoke.sh`
- **AC**:
  - [ ] AC1: `wave6-smoke.sh`'s T06 band isolates `CLAUDE_PLUGIN_DATA` alongside `HOME` and
        `CLAUDE_PROJECT_DIR`.
  - [ ] AC2: EDMTC's shipped assertion at `wave7-smoke.sh:10186-10228` is extracted into a
        helper both suites call, preserving its either-arm three-assertion shape. It is suite-scoped
        by design ("deliberately the LAST thing this file does"), so it cannot be extended in place
        and must not be copied.
  - [ ] AC3: control -- a deliberate write to the real host data directory during `run-all.sh` is
        detected.

### EDMDS-T30: Record every decision and give closure mechanical backing

- **Requirement**: EDMDS-17
- **Size**: M
- **Depends On**: every other ticket
- **Target Components**: `SRD/edm/EDMDS__design-docket/decisions.md`,
  `SRD/edm/EDMDS__design-docket/inherited-findings.jsonl`, `bin/edm-state`
- **AC**:
  - [ ] AC1: every ratified, revised or rejected Gate 2+3 decision recorded with a D-number,
        including any this SRD proposed that the gate overturned.
  - [ ] AC2: EDMV4's D51 marked superseded with a pointer to EDMDS.
  - [ ] AC3: the four reclassifications recorded against their finding ids -- CA-114 split, CA-109
        upgraded then split, CA-072 corrected, CA-134 extended.
  - [ ] AC4: every inherited finding carries a terminal status and, where remediated, a
        `resolved_commit`.
  - [ ] AC5: a check proves no inherited finding lacks a terminal status.

### EDMDS-T31: Decide the three remaining reserved prefixes

- **Requirement**: EDMDS-18
- **Size**: XS
- **Depends On**: EDMDS-T13
- **Target Components**: `SRD/edm/EDMDS__design-docket/decisions.md`, `CLAUDE.md`
- **AC**:
  - [ ] AC1: `CAMGAP`, `LINUXV` and `EVALB` each released or retained with a stated reason. `EDMRT`
        is EDMDS-T08's.
