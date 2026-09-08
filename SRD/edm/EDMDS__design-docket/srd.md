# SRD: EDMDS -- EDMV4's Structural Design Docket

## 1. Document Info

| Field | Value |
|---|---|
| Version | 1.0.0 |
| Mode | `mini-srd` -- phases 2 through 5 fuse into this one audited file; a merged Gate 2+3 replaces Gate 2 and Gate 3 |
| Forked from | `EDMV4` |
| Branch | `edm/edmds-design-docket` |
| Inputs | `planning.md`, `explorers/01` through `explorers/04`, `inherited-findings.jsonl` |

### Revision History

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0.0 | 2026-09-08 | orchestrator | Initial fused SRD. Proposes a decision for each of the eighteen findings; Gate 2+3 ratifies or overturns. |

## 2. Executive Summary

EDMV4 accepted 39 P2 findings as documented debt. `EDMTC` closed 21 of them -- one homogeneous
defect class, run as a fix-pack. These are the other 18, and they are different in kind: each needs
a design decision before a fix is well-defined.

**This document makes those eighteen calls.** The explorers deliberately withheld recommendations
so the facts would stand on their own; Phase 2's job is to propose, and Gate 2+3's job is to ratify
or overturn. Every requirement below states what was chosen, what was rejected, and why -- so a
reviewer can disagree with the reasoning rather than only with the outcome.

Phase 1 already changed three of the eighteen. CA-114's premise is disproved by measurement, CA-109
turns out to be a security-relevant correctness gap rather than a consolidation, and CA-072 is
smaller than recorded. Those are folded in below.

## 3. Goals and Scope

### 3.1 Goals

1. Close all eighteen findings, or record an explicit, reasoned decision not to.
2. Leave no finding whose resolution rests on an undocumented assumption about a dependency.
3. Add no assertion that cannot fail. This initiative's two predecessors fixed fifteen of those
   between them, and `EDMTC` still caught an agent introducing a sixteenth.

### 3.2 In scope

The eighteen findings in `inherited-findings.jsonl`, plus two items Phase 1 established belong here:

- `bin/tests/wave6-smoke.sh`'s unguarded writes into the real host data directory -- 85 stale
  markers measured on this host, traced to its T06 band isolating `HOME` and `CLAUDE_PROJECT_DIR`
  but never `CLAUDE_PLUGIN_DATA`. Same mechanism as Decision B.
- `README.md`'s claim that `file`-event hookify rules work unconditionally. They do not (CA-122),
  and the documentation is currently wrong regardless of which way that decision goes.

### 3.3 Out of scope

- Re-opening EDMV4's archived ledger. The eighteen stay open there; that ledger records what EDMV4
  shipped, and rewriting it would misdescribe history. EDMDS is the record of closure.
- The four reserved-but-uncreated follow-on prefixes (`EDMRT`, `LINUXV`, `EVALB`, `CAMGAP`).
  CA-116 and CA-091 reference two of them; referencing is not adopting.
- Any change to `bin/tests/wave8-smoke.sh`'s assertion COUNT downward. `run-all.sh` must stay at
  or above 4048 passed / 0 failed.

### 3.4 Definition of Done

1. Every `Must Have` requirement below has all acceptance criteria satisfied and evidenced.
2. `/bin/bash plugins/edm/bin/tests/run-all.sh` passes with zero failures on macOS under bash
   3.2.57, at **4048 or above**.
3. `edm-check-grants`, `edm-check-vocabulary`, `edm-check-skill-sync` and
   `edm-sync-canonical-sections --check` all exit 0.
4. `claude plugin validate plugins/edm/` exits 0.
5. `edm-lint-artifacts --path plugins/edm/` reports zero violations across `skills/`, `agents/`
   and `docs/`.
6. `bin/edm-gateguard` is within `EDMV4-T11` AC1's closed line range. If a requirement pushes it
   past 660, the bound is amended by a recorded decision -- never nudged (D42, D47 precedent).
7. Every decision this document proposes is either ratified at Gate 2+3 or replaced by one that is,
   and the outcome is recorded in `decisions.md`.

## 4. Architecture Decisions

Four cut across multiple requirements and are stated once here.

### AD1 -- Trust boundary: project-authored text is data, never instruction

A hookify rule file is source-controlled project content. It is authored by whoever can commit to
the repository, which is not necessarily the operator running the session. Every requirement that
handles rule-supplied text (CA-113, CA-114, CA-029's successors) treats it as **data to be
displayed, never as instruction to be followed**, and labels it as such at every boundary it
crosses.

This is a posture, not a mechanism, because no mechanism in this plugin can enforce it against a
model's willingness to be talked out of a frame. Requirements below therefore prefer *reducing the
channel* over *fortifying the frame* wherever the cost is comparable.

### AD2 -- One resolver, and the strictest one wins

Three project-root resolvers exist and they disagree. The canonical implementation is
`bin/edm-state`'s `_resolve_permcheck_project_root`, because it is the only one carrying the CA-500
physical-path cross-check. The other two adopt it rather than the reverse. Choosing the strictest
is not arbitrary: the two lax resolvers accept `CLAUDE_PROJECT_DIR` unchecked, which is the defect.

### AD3 -- A completeness gate asserts delivery, not existence

`CA-090` and `CA-091` together decide whether "the round converged" is a claim about delivery or
about files existing. This SRD takes the position that a gate whose only check is "the file parses"
is a gate in name only, and that absence of a manifest is the strongest non-delivery signal
available rather than a reason to skip checking.

### AD4 -- Backward compatibility is a constraint, not a preference

`CA-134`'s C-4 clause treats a data directory carrying `patterns/` as EDM-owned. A sentinel-only
test was tried and provably abandoned every existing install -- 58 failing assertions. Any scoping
or lifecycle change in Decision B must keep an existing install working, and must prove it does by
a test that fails without the compatibility path.

## 5. Requirements

Priority: **Must** = blocks Definition of Done. **Should** = expected, may be descoped with a
recorded reason. **Could** = opportunistic.

### Epic 1 -- Untrusted input and unratified surface

#### EDMDS-01 (Must) -- Depend on Oniguruma's retry limit deliberately, and pin it

**Finding**: CA-114. **Decision**: option 1 of explorer 04 -- depend on the engine's bound, document
it, and assert it.

**Rejected**: adding an EDM-side bound. A pattern-complexity heuristic rejects legitimate patterns,
which is a worse failure than the one it prevents; a `sleep`-plus-`kill` watchdog adds asynchronous
process management to every one of three hook consumers, in a file whose fast path is budgeted at
one exec. Both are solutions to a hang that does not occur. Also rejected: dropping `regex_match`,
which removes a documented feature to fix a non-problem.

- [ ] AC1: `bin/edm-hookify`'s header no longer claims the 64 KiB cap bounds evaluation cost. It
      states that the bound is Oniguruma's `retry-limit-in-match`, that it is a property of `jq`
      and not of EDM, and that `CLAUDE.md`'s required-binary contract names `jq` with no version
      floor.
- [ ] AC2: an assertion drives a known-catastrophic pattern (`(a+)+$` against a non-matching
      suffix) through `edm-hookify eval bash` and requires: exit 0, the offending rule FILE named
      on stderr, and no block.
- [ ] AC3: the same assertion requires a benign sibling rule in the same directory to still fire,
      so CA-030's per-file isolation is pinned alongside.
- [ ] AC4: a negative control proves AC2 discriminates -- a rule whose pattern is benign produces
      no setup error, so "no error" is not the assertion's only reachable state.
- [ ] AC5: `CLAUDE.md`'s hookify section records the dependency and the residual: a future `jq`
      that raises or removes the retry limit reopens the exposure, and AC2 is what fails when it
      does.
- [ ] AC6: no wall-clock or complexity guard is added. This AC exists so a later contributor sees
      the omission was decided, not overlooked.

#### EDMDS-02 (Must) -- Remove rule text from the model-facing refusal channel

**Finding**: CA-113. **Decision**: option 3 -- do not interpolate a rule author's `message` into
`permissionDecisionReason`. Emit a fixed, EDM-authored sentence there naming the rule id and file;
put the author's message on stderr.

**Rejected**: option 1, an untrusted-content frame. Per AD1 a frame is only as strong as the
model's willingness to respect it, this plugin has no existing mechanism for labelling untrusted
content to a model, and explorer 01's own assessment is that a frame the model can be talked out of
is worse than none because it manufactures false confidence. Option 4, accept the risk, is rejected
because CA-196 records the same class already present at a second site, so accepting here entrenches
a multi-site pattern.

**Cost accepted explicitly**: the author's message becomes invisible in the one channel most likely
to change model behaviour on retry. That is a real loss of the `message` field's value, and it is
the price of the trust boundary.

- [ ] AC1: `permissionDecisionReason` on a hookify-driven denial contains only EDM-authored text,
      plus the rule id and rule file path.
- [ ] AC2: the rule author's `message` appears on stderr, attributed to its file.
- [ ] AC3: an assertion proves a rule whose `message` mimics EDM's own fact-list prose cannot place
      that text into `permissionDecisionReason`.
- [ ] AC4: AC3's negative control -- the same message IS present on stderr, so the test distinguishes
      "suppressed everywhere" from "moved to the right channel".
- [ ] AC5: `edm-stop-gate` and `edm-bash-gate` are checked for the same channel and brought into
      line, or their difference is recorded with a reason. Explorer 01 found `edm-stop-gate` is the
      only consumer that already labels the text's origin.
- [ ] AC6: `CLAUDE.md`'s hookify section and `README.md`'s rule-format section both state that
      `message` reaches stderr, not the model-facing refusal.

#### EDMDS-03 (Must) -- Withdraw GateGuard's MultiEdit arm, or ratify it on stated evidence

**Finding**: CA-116. **Decision**: ratify on current evidence and close D26's condition, rather than
withdraw.

**Rationale**: D26 conditioned shipping on a re-test that could not be performed -- `MultiEdit` was
absent from the toolset twice, including with `--allowedTools MultiEdit` forced. A condition that
cannot be satisfied is not a gate, it is a permanent block on working code. `EDMTC-T04` has since
driven the arm end to end against both payload shapes with de-duplication asserted, which is more
evidence than the original re-test would have produced.

**Rejected**: withdrawal. It would delete a tested feature to satisfy a condition whose own
precondition is unavailable.

- [ ] AC1: `decisions.md` records D26's condition as closed, naming `EDMTC-T04`'s coverage as the
      substitute evidence and stating plainly that the original re-test was never performed.
- [ ] AC2: the residual is stated: the arm is proven by fixture, not by a live `MultiEdit` tool
      call, and no such call has ever been observed on this host.
- [ ] AC3: `EDMRT` remains reserved for live runtime verification; this requirement does not claim
      to close it.

#### EDMDS-04 (Must) -- Decide and document `file`-event rule reach, and fix the README

**Finding**: CA-122. **Decision**: the Phase-6 scoping is INTENDED, and the documentation is wrong.

**Rationale**: `edm-gateguard`'s marker-absent fast path is budgeted at one exec and zero `jq`
(`EDMV4-T07` AC8). Evaluating hookify rules outside Phase 6 would mean parsing a payload on every
Edit and Write in every session, which contradicts a shipped performance contract. The scoping is
the right behaviour; the claim that rules apply unconditionally is the defect.

**Rejected**: making `file`-event rules unconditional. It trades a documented, measured fast path
for a feature reach nobody has asked for.

- [ ] AC1: `README.md`'s rule-format section states that `file`-event rules are evaluated only
      while an initiative is in Phase 6, and says why.
- [ ] AC2: the worked example in `README.md` either uses a `bash`-event rule, which is
      unconditional, or carries the Phase-6 caveat inline.
- [ ] AC3: `CLAUDE.md` already documents the scoping; verify and cite it rather than restating.
- [ ] AC4: an assertion pins the scoping -- a `file`-event block rule does NOT deny outside Phase 6,
      and DOES deny with a marker present.
- [ ] AC5: AC4's control proves the marker is what changes the outcome, not the rule file.

#### EDMDS-05 (Should) -- Name `edm-bash-gate` as a deliverable

**Finding**: CA-063. **Decision**: record it retrospectively, as D48 did for an unticketed commit.

- [ ] AC1: `decisions.md` records `bin/edm-bash-gate` as a deliverable of `EDMV4-T45`, noting that
      T45's Target Components omitted it and that three cross-cutting ACs (T50 AC1, T52 AC4,
      T53 AC3) each name four `bin/` scripts and never this one.
- [ ] AC2: whichever cross-cutting assertion enumerates `bin/` membership derives the set live
      rather than from a literal list, so a seventh script cannot escape the same way.
- [ ] AC3: AC2's control -- a scratch `bin/` with an extra script is detected.

### Epic 2 -- Completeness-gate and round semantics

#### EDMDS-06 (Must) -- A lens artifact must carry lens-shaped content, not merely parse

**Finding**: CA-090. **Decision**: option B -- require, per line, a JSON object carrying the lens id
and a severity from the closed set, and at least one such line.

**Rejected**: option A, status quo, which lets `{}` converge a round. Option C, full schema
validation, is rejected as disproportionate: it must track a schema that `agents/edm-audit-logic.md`
carries verbatim in every lens prompt, so it acquires a drift surface of its own, and it runs across
14 files on every round close.

- [ ] AC1: the CA-471 completeness check requires each line of `lens-L{N}.jsonl` to be a JSON
      object with a `lens` field matching the file's own N and a `sev` in the closed P0/P1/P2/NOTED set.
- [ ] AC2: a file of `{}` fails. A file of valid lens lines passes.
- [ ] AC3: the single-malformed-line question is decided explicitly and recorded: one bad line
      among good ones fails the file. Partial credit for an artifact whose integrity is in question
      is what AD3 rejects.
- [ ] AC4: negative controls for each arm -- empty file, `{}`, wrong lens id, illegal `sev`, one bad
      line among four good ones.
- [ ] AC5: the check adds no new required binary and stays within `jq`.

#### EDMDS-07 (Must) -- A round with no manifest is non-delivery, not an exemption

**Finding**: CA-091. **Decision**: absence of a pass directory or manifest downgrades the round.

**Rationale**: per AD3, and because EDMV4's own D40 named this gap and reserved `CAMGAP` for it
without ever using it. The current `if` has no `else`, so the strongest non-delivery signal
available produces no consequence at all.

- [ ] AC1: when a code round's pass directory or manifest is absent at completion, the round is
      recorded `partial` with a message distinguishing this cause from the other three.
- [ ] AC2: a round WITH both present is unaffected -- the existing three checks run as today.
- [ ] AC3: negative control -- the same completion with the manifest restored produces `full`.
- [ ] AC4: `CLAUDE.md`'s round-type table records that the residual gap D40 named is now closed,
      and `CAMGAP` is released or explicitly retained with a reason.

#### EDMDS-08 (Should) -- Make an irreversible downgrade recoverable without a new round

**Finding**: CA-089. **Decision**: add a narrow repair path rather than keep irreversibility
absolute.

**Rationale**: the measured price of irreversibility is $105.28 and 3h15m per round, from EDMV4's
own state file, and a repair round does not help because `audit-converged` keys on the latest
round's type. Irreversibility was chosen to stop a round self-certifying after the fact; a repair
path that re-runs the SAME completeness checks against the SAME round cannot self-certify, because
it must pass the checks that failed.

**Rejected**: keeping it absolute. The cost is real money and hours, and the protection it buys is
already provided by re-running the checks.

- [ ] AC1: a subcommand re-evaluates a downgraded round's completeness and restores `full` only if
      every check that caused the downgrade now passes.
- [ ] AC2: it refuses if any check still fails, naming which.
- [ ] AC3: it cannot promote a round that was never downgraded, and cannot alter any other round.
- [ ] AC4: negative control -- a round with a still-missing lens JSONL is refused, and the same
      round with the file restored is promoted.
- [ ] AC5: every promotion is recorded in state with a timestamp and the checks that passed, so a
      promotion is auditable rather than silent.

#### EDMDS-09 (Must) -- Subtract `lenses_na` before materialising `lenses`

**Finding**: CA-074. **Decision**: fix the subtraction.

**Rationale**: explorer 02 established the defect is currently MASKED -- the skill layer always
subtracts before calling, so production shapes look correct and no test exercises the bug. A masked
defect is worse than a visible one: the next caller that does not pre-subtract gets a
`round_type` computed from a double-counted set, with no signal.

- [ ] AC1: `audit-round-start` subtracts `lenses_na` from the materialised `lenses` set.
- [ ] AC2: an assertion calls it WITHOUT pre-subtracting -- the path the skill layer masks -- and
      requires a correct `round_type`.
- [ ] AC3: AC2's control -- the same call against the unfixed logic produces the contradiction
      explorer 02 traced between completeness checks (1) and (2).
- [ ] AC4: EDMV4's recorded round-1 shape (`lenses` 13, `lenses_na` `["L13"]`) still reads as
      `full`, so the fix is backward compatible with existing state.

#### EDMDS-10 (Must) -- Marker reconciliation must not leave an active initiative unmarked

**Finding**: CA-075. **Decision**: make removal and recreation a single reconciliation rather than
mutually exclusive branches.

**Rationale**: a marker-absent state makes `edm-gateguard` allow every Edit and Write with no
further checks. So this defect silently disables the Phase-6 fact-forcing gate for a genuinely
active initiative -- the failure mode is a security control turning itself off.

- [ ] AC1: `SessionStart` reconciliation removes a stale marker AND writes a correct one when an
      initiative is genuinely at Phase 6, in one pass.
- [ ] AC2: an assertion drives the stale-plus-active case and requires a marker to exist afterwards.
- [ ] AC3: AC2's control -- against the unfixed branches, the same fixture ends with no marker and
      `edm-gateguard` allows a first-touch edit.
- [ ] AC4: the sequence holds under the lock the state writer already uses, or the absence of a lock
      is recorded with a reason.

### Epic 3 -- Resolvers, data-directory lifecycle, duplication

#### EDMDS-11 (Must) -- One project-root resolver, the strict one

**Finding**: CA-109. **Decision**: per AD2, `bin/edm-hookify` and `bin/_edm-datadir-lib.sh` adopt
`edm-state`'s resolver semantics including the CA-500 cross-check.

**Note**: reclassified upward from a consolidation to a correctness gap by Phase 1. Unchecked
`CLAUDE_PROJECT_DIR` acceptance redirects rule discovery and the marker key.

- [ ] AC1: all three resolvers apply the CA-500 physical-path cross-check.
- [ ] AC2: `edm-hookify`'s comment claiming parity with `edm-state` is either true or removed. It is
      currently false.
- [ ] AC3: an assertion drives a `CLAUDE_PROJECT_DIR` pointing outside the git toplevel and requires
      all three to agree on rejecting it.
- [ ] AC4: AC3's control -- a legitimate `CLAUDE_PROJECT_DIR` is accepted by all three.
- [ ] AC5: `_edm-datadir-lib.sh` still spawns `git` only on the documented condition
      (`EDMV4-T17` AC7), so the fix does not add a subprocess to the fast path.

#### EDMDS-12 (Should) -- One active-initiatives accessor

**Finding**: CA-112. **Decision**: `edm-repo-readiness` calls `edm-state active-initiatives` rather
than scraping `edm-state list` through awk.

**Rationale**: the two genuinely disagree -- `cmd_list` has no phase filter, `cmd_active_initiatives`
filters phases 1 to 6 -- so this is a reporting-correctness fix, not only deduplication.

- [ ] AC1: `edm-repo-readiness` uses the accessor.
- [ ] AC2: an assertion proves both paths now agree on a fixture containing an archived and an
      active initiative.
- [ ] AC3: AC2's control -- the fixture is shown to distinguish them, so agreement is not vacuous.

#### EDMDS-13 (Must) -- Bound and scope the data directory

**Findings**: CA-100, CA-103, CA-105, plus `wave6-smoke.sh`'s unguarded writes. **Decision**: scope
the harvested delta per project, cap its growth, sweep the `run/` triple, and isolate the test.

**Measured on this host**: 144 findings in one host-global delta; 85 stale `.phase6` markers.

**Constraint**: AD4. A scoping change must keep an existing install working.

- [ ] AC1: the harvested delta is keyed by project as well as audit type.
- [ ] AC2: an existing host-global delta is still readable after the change -- migrated or read in
      place, decided and recorded, not silently orphaned.
- [ ] AC3: AC2's control -- a fixture carrying a pre-change delta is proven readable, and the test
      fails without the compatibility path.
- [ ] AC4: the delta has a documented cap, and the behaviour at the cap is decided: prune oldest,
      or refuse to append, not unbounded growth.
- [ ] AC5: `run/` entries are swept on a stated policy, with the 85 measured leftovers as the test
      fixture's basis.
- [ ] AC6: `bin/tests/wave6-smoke.sh`'s T06 band isolates `CLAUDE_PLUGIN_DATA` alongside `HOME` and
      `CLAUDE_PROJECT_DIR`, and an assertion proves a suite run writes nothing to the real host data
      directory -- with a positive control that writes there deliberately and is detected.
- [ ] AC7: gitignore coverage for the data directory is decided and recorded. It is outside the
      repository, so the likely answer is "none needed"; the AC exists so that is stated rather
      than assumed.

#### EDMDS-14 (Should) -- One owner for the ASCII sanitizer

**Finding**: CA-072. **Decision**: extract the literal to one shared owner.

**Note**: three copies, not the five recorded, byte-identical with no drift. The work is smaller
than the finding implies and the finding's count is corrected in `decisions.md`.

- [ ] AC1: one definition; all three call sites use it.
- [ ] AC2: a computed assertion proves only one definition exists, derived by scanning rather than
      a pinned count.
- [ ] AC3: AC2's control -- a re-introduced copy is detected.
- [ ] AC4: `bin/edm-bash-gate`, which explorer 03 found has no sanitizer of its own, is assessed
      and either given one or recorded as not needing one.

#### EDMDS-15 (Should) -- One `UserPromptExpansion` gate block

**Finding**: CA-121. **Decision**: collapse the five near-identical blocks, preserving the
`edm:implement` copy's extra clause as a parameter rather than losing it.

**Note**: four are byte-identical apart from the gate token; the `implement` copy carries one extra
clause about Gate 3.5. That drift is the reason to consolidate carefully rather than pick one copy.

- [ ] AC1: the blocks are collapsed with no loss of behaviour, including `implement`'s clause.
- [ ] AC2: an assertion proves each of the five skills still gets its correct gate enforcement.
- [ ] AC3: AC2's control -- a skill whose gate is unapproved is still blocked.
- [ ] AC4: whether Gate 3.5 enforcement is genuinely implement-specific is established and recorded.
      Explorer 03 could not determine this.

#### EDMDS-16 (Should) -- Decide the `set -e` posture for hook consumers

**Finding**: CA-106. **Decision**: converge the four consumers on one posture, and document which.

**Rationale**: only `edm-gateguard` runs `set -euo pipefail`; the other three run `set -uo pipefail`
with no comment explaining the split. For a hook, `set -e` means an unexpected non-zero aborts the
hook -- which for a gate that must not block on its own failure is arguably wrong, and for one that
must fail closed is arguably right. The point is that the difference is currently accidental.

- [ ] AC1: all four consumers share one posture, or each difference carries an inline reason.
- [ ] AC2: the choice and its consequence are recorded in `CLAUDE.md`.
- [ ] AC3: an assertion proves each consumer's behaviour on an internal error matches the documented
      posture -- specifically that a setup condition never blocks.

#### EDMDS-17 (Must) -- Record every decision this document proposes

- [ ] AC1: each ratified, revised or rejected decision from Gate 2+3 is recorded in `decisions.md`
      with a D-number, including any this SRD proposed that the gate overturns.
- [ ] AC2: EDMV4's D51, which said these eighteen would stay unowned, is marked superseded with a
      pointer to EDMDS.
- [ ] AC3: the three Phase-1 reclassifications (CA-114 descoped, CA-109 upgraded, CA-072 corrected)
      are recorded against their finding ids, so the archived ledger's text is not the only account.

#### EDMDS-18 (Could) -- Retire or re-scope the unused reserved prefixes

`CAMGAP` was reserved by D40 for the gap EDMDS-07 now closes. If EDMDS-07 lands, `CAMGAP` should be
released rather than left reserved indefinitely.

- [ ] AC1: each of `CAMGAP`, `EDMRT`, `LINUXV` and `EVALB` is either still justified or released,
      with the outcome recorded.

## 6. Risks

| ID | Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|---|
| R1 | EDMDS-02 removes the `message` field's main value | Medium | Certain | Accepted explicitly; the message still reaches stderr. Revisit only if a real trust-labelling mechanism appears |
| R2 | EDMDS-13's scoping re-breaks existing installs, as a stricter test already did once | High | Medium | AD4; AC3 requires a test that fails without the compatibility path |
| R3 | `bin/edm-gateguard` exceeds T11 AC1's 660-line bound | Low | High -- one line of headroom, and two epics touch it | Amend by recorded decision, never nudge (D42, D47) |
| R4 | EDMDS-08's repair path becomes a self-certification route | High | Low | It must pass the checks that caused the downgrade; it cannot bypass them |
| R5 | A future `jq` raises Oniguruma's retry limit, reopening CA-114 | Medium | Low | EDMDS-01 AC2 fails when it happens; AC5 records the dependency |
| R6 | Eighteen decisions ratified in one gate round invites rubber-stamping | Medium | Medium | Each requirement states what was rejected and why, so a reviewer can disagree with reasoning rather than only outcomes |
