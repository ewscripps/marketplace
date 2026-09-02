# Epic 01: Preconditions and Change Control

This epic holds the six tickets that must land before, or alongside, any EDMV4 implementation work
and that carry no implementation of their own: `EDMV4-T06` (Spike A, multi-hook-per-event
combination semantics), `EDMV4-T07` (Spike B, the deny shape for a native `Edit`/`Write`/`MultiEdit`),
`EDMV4-T08` (reconcile the D4 residual `plugin.json` version divergence, a merge-time obligation that
blocks nothing), `EDMV4-T09` (honour the inherited `T01`-`T05` ticket-ID claims and fix the stale
`CLAUDE.md` reference that created them), and `EDMV4-T10` (record and propagate the three Gate 2
ratifications D14, D15 and D16), and `EDMV4-T54` (map `audit-tickets` to the gate it consumes --
the `EDMV4-60` scope addition raised at Gate 3, already implemented because it blocked Phase 5
from running at all). Two of the six are live experiments against the Claude Code host
whose answers decide whether two other epics ship at all; the remaining three are change-control
bookkeeping whose absence would leave approved decisions unrecorded, unpropagated, or silently
reversed at merge.


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

## EDMV4-T06: Run Spike A and record multi-hook-per-event combination semantics

| Field | Value |
|---|---|
| Epic | Preconditions and Change Control |
| Phase | 1 |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV4-01 |
| Depends On | none |
| Blocks | EDMV4-T11, EDMV4-T45, EDMV4-T46 |
| Target Components | plugins/edm/hooks/hooks.json:14-78, plugins/edm/hooks/hooks.json:16-25, plugins/edm/hooks/hooks.json:80-90, SRD/edm/EDMV4__ecc-integration/decisions.md |

### Description

Claude Code's behaviour when two blocking hooks match the same tool call on the same event is
unverified from this repository's source. `hooks/hooks.json`'s five `UserPromptExpansion` matcher
blocks (verified at `:14-78`) prove that adding blocks is mechanically supported, but they are
matcher-disjoint -- one per slash command -- so they never exercise the competing case. EDM has
never had two independently authored blocking hooks compete on one call.

Two separate EDMV4 workstreams want `PreToolUse`: 4.1's edit gate and 5.3's hookify dispatcher.
`architecture.md` AD4's one genuine collision -- a hookify `bash`-rule block overlapping the existing
`git commit` block at `hooks.json:80-90` -- depends entirely on the answer. A second, narrower shape
is at stake too: AD4's chosen `Stop` design grows a second entry in the existing block's `hooks`
array, and the nearest in-repo precedent (`hooks.json:16-25`) is a `command` entry plus a `prompt`
entry, a heterogeneous pair. A homogeneous `command`-plus-`command` pair has zero instances anywhere
in this repository, so that design rests on an untested shape rather than on the cited precedent.

This ticket runs the experiment against the live host and records the result as a numbered decision,
following the D21 / D22 / D24 precedent of spiking a Claude Code behaviour this plugin depends on
rather than assuming it. It ships no change to the plugin's own hook wiring.

### Acceptance Criteria

- [ ] AC1: A throwaway plugin, or a scratch `.claude/settings.json` hook block in a disposable
      repository, registers two `PreToolUse` matcher blocks that both match one tool call. Block 1
      exits 0 (allow), block 2 exits 2 (deny). The recorded result names which decision the host
      took: the tool call proceeded, or it was refused.
- [ ] AC2: The reverse ordering is run and recorded separately -- block 1 denies, block 2 allows. If
      the two orderings produce different outcomes, the decision states that registration order is
      load-bearing and says so in those words.
- [ ] AC3: Each of the two commands writes a distinct marker file under a `mktemp -d` scratch
      directory. The decision records, from the markers actually present after the run, whether both
      blocks' commands executed or only the first-registered one.
- [ ] AC4: The same two-block experiment (AC1 through AC3) is run for the `Stop` event and its
      results recorded separately from the `PreToolUse` results, not collapsed into one verdict.
- [ ] AC5: Separately and specifically, two `"type": "command"` entries are registered in one `Stop`
      block's `hooks` array, each writing a distinct marker file. The decision records three things:
      whether both ran, whether only the first ran, and whether the second entry's exit code was
      honoured when the first exited 0.
- [ ] AC6: The decision states the AC5 premise honestly -- `hooks.json:16-25` is a `command` entry
      plus a `prompt` entry, and a `grep`-verified count of homogeneous `command`-plus-`command`
      pairs anywhere in this repository is zero -- so the result stands on the experiment, not on the
      cited precedent.
- [ ] AC7: If only one `command` entry per `hooks` array executes, the decision states that
      `EDMV4-44`'s second-entry design does not work and that a second `Stop` matcher block (the
      alternative `architecture.md` rejected) is re-presented at a gate before 5.4 ships.
- [ ] AC8: The decision explicitly answers whether 5.3 may register a `bash`-event block alongside
      the existing `git commit` block at `hooks.json:80-90`, or whether AD4's fallback -- folding
      `edm-lint-staged-artifacts` into `edm-hookify`'s `Bash` dispatcher -- must be taken instead.
- [ ] AC9: If the answer is "first-registered wins" or "blocks must be consolidated", the decision
      states that `EDMV4-43`'s `bash` event is not shipped in this initiative and that hookify ships
      with `file` and `stop` events only.
- [ ] AC10: The result is recorded in `SRD/edm/EDMV4__ecc-integration/decisions.md` as a numbered
      decision naming the `claude --version` output string verbatim and the date, matching D22's
      recording format.
- [ ] AC11: `plugins/edm/hooks/hooks.json` is unmodified by this ticket -- `git status` shows no
      change to it and the experiment ran entirely from the scratch harness.

### Technical Notes

- Citations verified against this tree: the five matcher-disjoint `UserPromptExpansion` blocks span
  `hooks.json:14-78` inside an array at `:13-79`; the first block's `hooks` array is `:16-25` (the
  SRD cites `:16-24`, off by the closing bracket only); the `PreToolUse` `git commit` block is
  `:81-89` inside the `PreToolUse` array at `:80-90`. All within tolerance and safe to restate.
- Run the experiment from a scratch `.claude/settings.json` in a disposable repository rather than
  from the EDM plugin itself. Editing `plugins/edm/hooks/hooks.json` to run a spike risks the change
  surviving into a commit, and plugin hook changes need a `/reload-plugins` cycle that adds a
  confound to the ordering question.
- Marker files must be created with distinct names by each command (for example `block-a` and
  `block-b` under one `mktemp -d`), because "which decision the host took" and "which commands ran"
  are different questions and a single shared marker cannot separate them.
- The exit-code contract this spike assumes for `PreToolUse` is exit 2 = block with stderr surfaced,
  exit 0 = allow. That is the contract `edm-lint-staged-artifacts` already relies on for a
  `Bash`-wrapped `git commit`; whether it holds for other tools is Spike B's question, not this one.
- The D21 / D22 / D24 precedent decisions live at
  `SRD/.archived/edm/EDMV3__prompt-streamline/decisions.md` (audit P1-9: the unarchived path this
  note originally gave no longer exists) on
  this tree. `SRD/.archived/` **now exists** (audit P1-9 -- the fast-forward brought the EDMV3 archival
  rename set, so `SRD/edm/EDMV3__prompt-streamline/` is gone and
  `SRD/.archived/edm/EDMV3__prompt-streamline/` is the live path). Any citation of an archived
  EDMV3 path must be
  resolved at close time rather than copied forward.

### Out of Scope

- Wiring any hook into `plugins/edm/hooks/hooks.json`. `EDMV4-43` (hookify event wiring) and
  `EDMV4-44` (the `Stop` entry) own that, and both consume this spike's answer.
- The deny mechanism for a native `Edit`/`Write`/`MultiEdit` -- that is Spike B (`EDMV4-T07`).
- Building `edm-hookify`, its rule-file evaluator, or its exit-code contract.
- Any decision about whether the destructive-`Bash` arm returns; that was settled at Gate 2 (D15).

---

## EDMV4-T07: Run Spike B and set the GateGuard deny-mode default from evidence

| Field | Value |
|---|---|
| Epic | Preconditions and Change Control |
| Phase | 1 |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV4-02 |
| Depends On | none |
| Blocks | EDMV4-T11, EDMV4-T13 |
| Target Components | plugins/edm/bin/edm-lint-staged-artifacts:7-10, plugins/edm/bin/edm-lint-staged-artifacts:150-158, plugins/edm/hooks/hooks.json:80-90, SRD/edm/EDMV4__ecc-integration/decisions.md |

### Description

`permissionDecision` and `hookSpecificOutput` appear zero times anywhere in this repository outside
the analysis document. Every EDM hook that blocks does so via a bash exit code, and the sole blocking
precedent -- `edm-lint-staged-artifacts` exit 2 -- is a `Bash`-wrapped `git commit`, not a native
`Edit`. Whether an exit-code-only `PreToolUse` hook can deny a native `Edit`/`Write`/`MultiEdit` is
unverified in both directions, as is whether the AD2 JSON payload is honoured.

This is the worst failure shape in the initiative. If the JSON shape is silently ignored, GateGuard
denies nothing while appearing to work, because the allow path is silent by design -- there is no
observable difference between "allowed correctly" and "the deny was dropped on the floor". AD2 makes
the outcome a one-constant change (`EDM_GATEGUARD_DENY_MODE`, defaulting to `json`) rather than a
rewrite, but the constant still has to be set from evidence.

The ticket runs both mechanisms against all three tools, records the results per tool, and sets the
default. It also records the `MultiEdit` partial-application behaviour, which decides whether a deny
on one file in a batch leaves the other files written.

### Acceptance Criteria

- [ ] AC1: A scratch `PreToolUse` hook matching `Edit` prints the AD2 JSON payload
      (`{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"<text>"}}`)
      on stdout and exits 0. The record states whether the `Edit` was refused, and separately whether
      the `permissionDecisionReason` text was surfaced to the agent as the tool result.
- [ ] AC2: The AC1 experiment is repeated for `Write` and for `MultiEdit`, and the results are
      recorded as three rows -- one per tool -- never collapsed into a single verdict.
- [ ] AC3: A second scratch hook prints the same text on stderr and exits 2. The record states
      whether that refused the `Edit`, and whether the stderr text reached the agent.
- [ ] AC4: A positive control is run with the hook removed, showing the same `Edit` succeeding, so a
      "refused" result cannot be an unrelated tool failure misread as a deny.
- [ ] AC5: The `MultiEdit` case uses a batch of at least three edits spanning at least two files, and
      the record states from the post-run file contents whether the whole call was refused or
      partially applied.
- [ ] AC6: The result is recorded in `SRD/edm/EDMV4__ecc-integration/decisions.md` as a numbered
      decision naming the `claude --version` output string and the date, and stating the value
      `EDM_GATEGUARD_DENY_MODE` must default to -- exactly one of `json` or `exit-code`.
- [ ] AC7: The decision names the precedent it is being compared against and states its limit:
      `edm-lint-staged-artifacts` documents its exit-code contract at `:7-10` and exits 2 on a real
      violation via the loop at `:150-158`, but it fires on a `Bash`-wrapped `git commit`, so it does
      not itself evidence the native-tool case.
- [ ] AC8: If neither mechanism denies a native `Edit`, the decision says so plainly and states that
      `EDMV4-07` is re-presented at a gate as a no-go for 4.1, rather than being implemented against
      a mechanism that does not work.
- [ ] AC9: `plugins/edm/hooks/hooks.json` is unmodified by this ticket -- the experiment ran from a
      scratch harness and `git status` shows no change to it.

### Technical Notes

- Citations verified against this tree: `edm-lint-staged-artifacts:7-10` is the `EDM-HELP-BEGIN`
  block stating exit 0 = clean, exit 2 = real violation (blocks the commit), exit 1 = setup error;
  the per-prefix loop is `:146-158` with `fail=2` set at `:153` and `exit "$fail"` at `:159`. The
  SRD's `:150-158` and `:140-159` both land inside that loop and are safe to restate.
- The JSON payload must be a single line on stdout with nothing else written there. A stray `echo`
  or a `set -x` trace on the same stream is the most likely way to get a false "JSON ignored"
  result.
- Record the raw host response for each run (tool result text, any surfaced reason) rather than only
  a PASS/FAIL judgement. The follow-on ticket that implements `emit_decision` needs the exact
  surfaced-text shape, not just the verdict.
- GateGuard's two kill switches (`EDM_GATEGUARD=off`, `EDM_GATEGUARD_DISABLED=1`) are AD1 concerns
  belonging to the implementation ticket; do not conflate a kill switch with a deny mechanism while
  recording results.

### Out of Scope

- Writing `edm-gateguard`, its fact-forcing state machine, its glob exemption matcher, or its session
  state.
- Implementing `emit_decision` and its two back-ends -- this ticket only sets which back-end is the
  default.
- The multi-hook-per-event question (Spike A, `EDMV4-T06`).
- Any destructive-`Bash` behaviour, descoped at Gate 2 per D15.

---

## EDMV4-T08: Reconcile the D4 residual plugin.json version divergence at merge time

| Field | Value |
|---|---|
| Epic | Preconditions and Change Control |
| Phase | 1 |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV4-03 |
| Depends On | none |
| Blocks | nothing (merge-time obligation only) |
| Target Components | plugins/edm/.claude-plugin/plugin.json:4, .claude-plugin/marketplace.json (the `edm` entry), plugins/edm/bin/edm-state (the `compute_cost_usd` `case`), plugins/edm/bin/edm-check-skill-sync, plugins/edm/skills/*/SKILL.md (14 files, verification only), plugins/edm/bin/tests/run-all.sh, plugins/edm/CLAUDE.md Sec."Cost tracking", SRD/edm/EDMV4__ecc-integration/decisions.md |

### Description

**This ticket blocks nothing.** SRD v1.0.0 declared `EDMV4-03` a precondition on every implementation
requirement, on the premise that the branch still carried the D3 defect. `decisions.md` D4 as amended
records that the defect is already fixed on this branch -- commit `bdec805` is applied directly
rather than by rebase, zero `skills/*/SKILL.md` files carry `disable-model-invocation: true`, and
`bin/edm-check-skill-sync` carries the plugin-wide guard. What remains is narrow and, in D4's own
words, non-blocking: the branch is missing the merge commit `bdb5698` and the two version-bump
commits `33d63e0` and `4ad0f35`, so `plugins/edm/.claude-plugin/plugin.json:4` reads `3.2.0` while
`origin/main` reads `3.2.1`. That is a one-line divergence to reconcile at merge, carried in the
Definition of Done rather than in any ticket's `Depends On`.

The one real hazard in the reconciliation is collateral. `compute_cost_usd`'s model `case` in
`bin/edm-state` must end the merge with an `*opus-5*` arm, and a careless merge or checkout would
lose it -- silently repricing every Opus 5 run at the `*)` placeholder rate with a warning nobody
reads. Verified on the tree this ticket was written against: that arm is **absent** today (see
Technical Notes), so the reconciliation is an addition to make and verify, not merely a local edit to
preserve.

The remaining work is regression verification rather than fixing: three assertions that fail loudly
if the merge regresses the state D3 and D4 already left the tree in, an accounting of the two
outstanding working-tree change sets, and a clean `run-all.sh` that establishes the baseline every
later EDMV4 requirement measures against.

### Acceptance Criteria

- [ ] AC1: `plugins/edm/.claude-plugin/plugin.json:4` records a version at or above `3.2.1` in the
      merge that lands EDMV4, and `.claude-plugin/marketplace.json`'s `edm` entry records the
      identical string. `EDMV4-35`'s manifest-description bump is reconciled into that one final
      value rather than applied as a second, independent bump.
- [ ] AC2: A test prices a synthetic `claude-opus-5-20260501` identifier through `compute_cost_usd`
      and asserts the Opus row (input 6, output 30, cache read 0.60, cache write 5m 7.50, cache write
      1h 12.00). The assertion compares the computed cost, not the presence of the arm's text in the
      file.
- [ ] AC3: The same test captures stderr and asserts that the `*)` arm's
      `WARNING: unrecognized model_used` message does **not** fire for an `opus-5` identifier.
- [ ] AC4: The `*opus-5*` match precedes the final `*)` fallback and the `case` introduces no bare
      family wildcard (no bare `*opus*`, `*sonnet*` or `*haiku*` arm anywhere in it) -- the two
      invariants `plugins/edm/CLAUDE.md Sec."Cost tracking"` states for that `case` after D32.
- [ ] AC5: Regression verification, not a fix: `grep -rc 'disable-model-invocation'
      plugins/edm/skills/` returns 0 across all 14 `SKILL.md` files, all 14 carry
      `user-invocable: true`, and `bash plugins/edm/bin/edm-check-skill-sync` exits 0 with its body
      still containing the guard that bans the flag anywhere under `skills/`.
- [ ] AC6: The staged EDMV3-archival rename set (roughly 313 paths) and the unstaged
      `bin/tests/wave6-smoke.sh` edits are each accounted for at merge time -- committed or
      deliberately dropped -- with the choice recorded in `decisions.md`. Neither is silently carried
      into an unrelated commit.
- [ ] AC7: `bash plugins/edm/bin/tests/run-all.sh` passes on the reconciled tree, and the run is
      recorded as the baseline every later EDMV4 requirement measures against.
- [ ] AC8: Every `file:line` citation this ticket carries is re-verified **against the tree**, at
      the time the ticket closes, by locating the cited symbol by name -- never by trusting any
      table in this ticket pack. A citation off by more than +/-10 lines is corrected in `srd.md`,
      but **only after re-derivation from the tree confirms the SRD is the wrong one**. This
      obligation is independent of D4 and applies whether or not any branch reconciliation happens.

      **Why this AC is worded defensively** (ticket-pack audit P1-2): the pack's own "verified
      anchors" were derived pre-fast-forward and are now wrong where the SRD is right. The
      fast-forward's `6e29dcb` re-inserted four lines at `bin/edm-state:504-507`, restoring the
      offset the Phase 4 writers had corrected away -- `ALL_LENS_IDS` is at 1613 (SRD correct, pack
      says 1609), `MODE_ENUM_LIST` at 807 (SRD correct, pack says 803), `state_anomalies()` at 1709
      (SRD correct, pack says 1705). An earlier wording of this AC would have driven an implementer
      to "correct" the SRD's correct numbers to the pack's wrong ones, damaging the SRD.
- [ ] AC9: The non-blocking status is visible in the pack, not only asserted here: no EDMV4 ticket
      lists `EDMV4-T08` in its `Depends On` field, and the README critical path draws no outbound
      edge from it.

### Technical Notes

- **Verified finding that changes AC2's shape.** On the tree this ticket was written against
  (`bin/edm-state:488-547`), `compute_cost_usd`'s `case` has eight arms and the current-generation
  Opus arm reads `*opus-4-8*|*opus-4.8*)` at `:503`. There is **no** `*opus-5*` text anywhere in the
  file -- the only `opus-5` occurrence is the explanatory comment at `:499`. A `claude-opus-5-*`
  identifier therefore falls through to `*)` at `:534` today and is priced at Sonnet placeholder
  rates with a warning. Meanwhile `plugins/edm/CLAUDE.md Sec."Cost tracking"` already documents the
  arm as `*opus-4-8*|*opus-4.8*|*opus-5*`. Doc and code disagree on this tree, and the SRD's framing
  of the arm as an "unstaged local edit" does not hold here.
- The working tree these citations were verified against is on branch `edm/verif-verifier-truncation`
  with a clean `git status`. Neither the roughly 313-path staged archival rename set nor the unstaged
  `wave6-smoke.sh` edits D4 describes are present here. **`SRD/.archived/` now exists** and the
  EDMV3 archival rename set is already committed, so the half of AC6 that tracked it as staged
  work is moot (audit P1-9). Formerly: EDMV3
  now lives at `SRD/.archived/edm/EDMV3__prompt-streamline/` (audit P1-9). Re-derive AC6's two
  change sets against the
  actual `edm/edmv4-ecc-integration` branch before closing rather than trusting D4's snapshot.
- `plugins/edm/.claude-plugin/plugin.json:4` verified as `"version": "3.2.0"`.
- `edm-check-skill-sync`'s guard is at `:71-78`, with the rejecting `grep -q '^disable-model-invocation:
  *true'` at `:77`. The 14 `SKILL.md` files carrying `user-invocable: true` were enumerated and
  counted; the `disable-model-invocation` count across `plugins/edm/skills/` is 0.
- AC2 must assert on the computed figure because a `grep` for the arm passes on a `case` where the
  arm sits *after* `*)` and is therefore dead. AC4 covers ordering separately for the same reason.

### Out of Scope

- Rebasing the initiative branch. D4 as amended withdrew that instruction; the revert hazard it
  described is gone.
- Re-applying the D3 fix. It is already present and this ticket only asserts it has not regressed.
- Writing `EDMV4-35`'s 14-lens manifest description text -- only the version value is reconciled
  here.
- Correcting `file:line` citations in requirements owned by other tickets; AC8 binds this ticket's
  own citations, and each other ticket carries the same obligation for its own.

---

## EDMV4-T09: Enforce the inherited T01-T05 ticket-ID constraints and fix the stale CLAUDE.md reference

| Field | Value |
|---|---|
| Epic | Preconditions and Change Control |
| Phase | 1 |
| Priority | Must Have |
| Size | XS |
| SRD Refs | EDMV4-04 |
| Depends On | none |
| Blocks | nothing |
| Target Components | `SRD/edm/EDMV4__ecc-integration/tickets/README.md`, `plugins/edm/CLAUDE.md` (the stale `EDMV4__lint-and-pipeline-budgets` reference), `SRD/.archived/edm/EDMV3__prompt-streamline/decisions.md` (D29, D34, D62 -- the origin of the three claims) |

### Description

`EDMV4-T01`, `EDMV4-T04` and `EDMV4-T05` already have defined scope, assigned by EDMV3's
`decisions.md` (D29, D34, D62) and cited by ID in `plugins/edm/CLAUDE.md:351-352` and in EDMV3's
ticket coverage map. `EDMV4-T02` and `EDMV4-T03` were closed inside EDMV3 and must never be reused --
reusing them would make two different pieces of work share one ID across two ledgers.

This initiative's ticket pack therefore cannot allocate `EDMV4-T01` through `EDMV4-T05` freely, which
is the opposite of the usual "number tickets from T01" convention and is easy to violate by default.
The constraint has to be stated in the pack itself, not only in the SRD, because the reader most
likely to break it is a future contributor adding a ticket months from now who never opens `srd.md`.

The same ticket closes the stale reference that created the situation. `plugins/edm/CLAUDE.md:352`
names `EDMV4__lint-and-pipeline-budgets`, an initiative that was cited in three places but never
existed on disk -- the condition EDMV3's own code audit raised as CA-430. D1 absorbed that name into
this initiative, which makes the reference stale on creation and puts it in scope to fix here.

### Acceptance Criteria

- [ ] AC1: The ticket pack `README.md` carries an explicit "Inherited ticket IDs" note stating that
      `T01`, `T04` and `T05` are pre-claimed with defined scope, and that `T02` and `T03` are retired
      and must never be reused.
- [ ] AC2: `EDMV4-T01` in the pack covers the Mermaid lint budget re-framing and nothing else -- its
      `SRD Refs` field lists exactly `EDMV4-47` and `EDMV4-48`.
- [ ] AC3: `EDMV4-T04` in the pack covers by-name reference anchoring and nothing else -- its
      `SRD Refs` field lists exactly `EDMV4-49` through `EDMV4-51`.
- [ ] AC4: `EDMV4-T05` in the pack covers eval-baseline verification plus the boundary record and
      nothing else -- its `SRD Refs` field lists exactly `EDMV4-52` and `EDMV4-53`.
- [ ] AC5: A grep for `EDMV4-T02` and `EDMV4-T03` across `tickets/README.md` and `tickets/epics/`
      returns zero ticket headings, and the `README.md` note states that the numbering gap between
      `T01` and `T04` is correct and intentional so a later reader does not "fix" it.
- [ ] AC6: Every ticket the pack creates for this initiative is numbered `EDMV4-T06` or higher, and
      the pack's ID set from `T06` upward is contiguous with no gaps and no duplicates.
- [ ] AC7: `plugins/edm/CLAUDE.md:352`'s `EDMV4__lint-and-pipeline-budgets` reference is replaced
      with this initiative's real directory, `SRD/edm/EDMV4__ecc-integration/`, and the surrounding
      parenthetical at `:351-353` still reads grammatically and still names `EDMV4-T04` as the
      follow-on ticket.
- [ ] AC8: A repository-wide grep for `EDMV4__lint-and-pipeline-budgets` returns only historical
      decision-ledger entries (EDMV4 D1, EDMV3 D29/D34/D62) and no live pointer presented as a
      current path.

### Technical Notes

- Citation verified: `plugins/edm/CLAUDE.md:352` carries the literal string
  `EDMV4__lint-and-pipeline-budgets`, inside a sentence beginning at `:351` that reads "scope opened
  as a named follow-on ticket, `EDMV4-T04` (the next unused ticket number in ...". The replacement
  must preserve that parenthetical's grammar, so a bare path substitution needs a reworded clause,
  not a token swap.
- **Correction to the SRD's Target Components line.** It cites
  `SRD/.archived/edm/EDMV3__prompt-streamline/decisions.md`. On this tree `SRD/.archived/` does not
  exist at all and the file is at `SRD/edm/EDMV3__prompt-streamline/decisions.md`, where the three
  `EDMV4-T0[145]` references were verified present. `EDMV4-T08` AC6 may move that tree during merge,
  so resolve the path at close time rather than restating either form as fixed.
- AC6's contiguity check is cheap and worth automating as a one-line `grep -ho 'EDMV4-T[0-9][0-9]'`
  over `tickets/` piped through `sort -u`; it catches an accidental duplicate ID far more reliably
  than reading the index table.

### Out of Scope

- Performing `EDMV4-T01`, `EDMV4-T04` or `EDMV4-T05`'s own implementation work. This ticket only
  constrains what those IDs may cover.
- Renumbering, merging or splitting any ticket already written in this pack.
- Any other stale reference in `plugins/edm/CLAUDE.md` not created by D1.
- Migrating EDMV3 into `SRD/.archived/` -- that change set is accounted for by `EDMV4-T08` AC6.

---

## EDMV4-T10: Record and propagate the three Gate 2 ratifications (D14, D15, D16)

| Field | Value |
|---|---|
| Epic | Preconditions and Change Control |
| Phase | 1 |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV4-05, EDMV4-06, EDMV4-59 |
| Depends On | none |
| Blocks | EDMV4-T11, EDMV4-T16, EDMV4-T46, EDMV4-T47, EDMV4-T51 |
| Target Components | SRD/edm/EDMV4__ecc-integration/decisions.md (D13, D14, D15, D16), SRD/edm/EDMV4__ecc-integration/architecture.md (AD1, :32-64), plugins/edm/bin/edm-lint-staged-artifacts:140-159, plugins/edm/bin/edm-state:1705-1927 (`state_anomalies`), plugins/edm/skills/orchestrator/SKILL.md Sec."Gate PROTOCOL", plugins/edm/CLAUDE.md Sec."Unverifiable acceptance criteria (D15)" |

### Description

**All three ratifications were approved at Gate 2 on 2026-09-02** and are recorded in
`decisions.md` as D14 (`EDMV4-59` -- AD1 is a bash rewrite of roughly 250-350 lines scoped to
`Edit`/`Write`/`MultiEdit`, not a vendoring), D15 (`EDMV4-05` -- GateGuard's destructive-`Bash` arm is
descoped) and D16 (`EDMV4-06` -- 5.4's "phase started with no `completed_at`" anomaly is descoped).
This ticket does not seek approval. Its work is recording and propagating outcomes that have already
been decided.

The three were presented independently and must stay independent in the record. Rejecting `EDMV4-05`
would have yielded a *larger bash rewrite*, never a vendoring; only `EDMV4-59` could have reversed
AD1. That distinction is not academic bookkeeping: AD1 is the sole trigger for D13's dormant MIT
NOTICE obligation, and SRD v1.0.0 wired that trigger to `EDMV4-05` instead. Under the old wiring a
Gate 2 that approved `EDMV4-05` while separately directing vendoring would have left the obligation
dormant with nothing to wake it. The corrected wiring -- "an AD1 reversal to vendoring, by any route"
-- has to land in the two requirements it gates, `EDMV4-12`'s dormant NOTICE clause and `EDMV4-56`'s
dependency-addition clause, or the exposure survives the ratification that was supposed to close it.

Propagation is the substance of the ticket. Three documents must agree (`decisions.md`,
`architecture.md` AD1, and `srd.md`), one live factual error inside AD1 must be corrected, both
descope boundaries must be recorded in the scope-boundary framing with named follow-on vehicles, and
the downstream tickets must carry the ratified scope rather than the pre-gate options.

### Acceptance Criteria

- [ ] AC1: `decisions.md` carries three separate numbered Gate 2 entries -- D14 (`EDMV4-59`), D15
      (`EDMV4-05`) and D16 (`EDMV4-06`) -- each dated 2026-09-02 with its own verdict and rationale.
      No entry's verdict is stated as inferred from another's or from silence.
- [ ] AC2: `architecture.md` AD1 is amended to record both outcomes it depends on: D14 (ratified as a
      bash rewrite, roughly 250-350 lines, not a vendoring) and D15 (destructive-`Bash` arm
      descoped), so `architecture.md` and `decisions.md` cannot disagree.
- [ ] AC3: The same amendment corrects the false claim in AD1's "Accepted trade-off" paragraph
      (`architecture.md:45-49`) that EDM "already blocks the one destructive Bash operation its
      methodology cares about (`git commit`, via `edm-lint-staged-artifacts`)". The corrected text
      states that `bin/edm-lint-staged-artifacts:140-159` blocks only on artifact lint violations,
      fires only when something under the derived `srd_root` is staged, and therefore bounds nothing
      destructive.
- [ ] AC4: The D15 boundary is recorded in the scope-boundary framing (a decision on its own merits,
      not a postponed finding), naming 5.3's `bash`-event rule files (`EDMV4-43`) as the follow-on
      vehicle and stating plainly that they ship only if Spike A (`EDMV4-T06`) clears -- so the
      follow-on route is recorded as conditional, not assured.
- [ ] AC5: That boundary record enumerates the command classes left entirely unguarded by name and
      not by category: `rm -rf`, `git reset --hard`, `git clean -fd`, a force-push (`git push
      --force` / `--force-with-lease`), and destructive SQL such as `DROP TABLE`.
- [ ] AC6: Propagation into the pack for D15: no ticket in the EDMV4 pack carries destructive-`Bash`
      scope, the `EDMV4-07` ticket's scope reads `Edit`/`Write`/`MultiEdit` only, and a grep across
      `tickets/` for `isDestructiveBash`, `shell-substitution` and `gateguard-heredoc` returns no
      in-scope work.
- [ ] AC7: `decisions.md` D13's attribution paragraph records D14's outcome, so the licence record
      and the architecture record cannot disagree: under AD1 as ratified nothing is copied from
      either upstream, the adoption is pattern-level, and `EDMV4-12` stays Should Have with its
      NOTICE clause dormant.
- [ ] AC8: The dormant NOTICE clause's trigger is stated once, in the `EDMV4-12` ticket, as "an AD1
      reversal to vendoring, by any route", and a grep of the pack finds no text making an
      `EDMV4-05` rejection revive that obligation.
- [ ] AC9: The `EDMV4-56` ticket carries the same wiring for its dependency-addition clause: a
      re-presentation of the required-binary set at a gate is triggered by an AD1 reversal by any
      route, and the ratified set stays `bash`/`jq`/`git` with no re-presentation required now.
- [ ] AC10: Propagation into the pack for D16: the `EDMV4-45` ticket ships exactly the three verified
      `validate` anomalies and no fourth, and the boundary record names what a future "phase started
      with no `completed_at`" design would need (a time threshold or an explicit wave-in-progress
      carve-out).
- [ ] AC11: That D16 boundary record cites the two facts that made a naive presence check
      unacceptable: `OPEN_AUDIT_ROUND` is kept informational for the same block-on-a-normal-state
      reason (`bin/edm-state:1782-1789`), and `cmd_archive` already refuses when the terminal phase
      has no `completed_at` (`bin/edm-state:3178-3181`), so the exposure is non-terminal phases only.
- [ ] AC12: Every `srd.md` passage that still presents these three as pending -- Sec.5.2's "go to
      Gate 2 for explicit human ratification" framing and the accept/reject branch criteria in
      `EDMV4-05`, `EDMV4-06` and `EDMV4-59` -- reads consistently with the ratified outcome at close,
      either by amendment or by an explicit "ratified 2026-09-02, see D14/D15/D16" annotation, so no
      reader re-runs a gate that has already happened.

### Technical Notes

- **Naming collision to avoid propagating.** `EDMV4-05` and `EDMV4-06` both instruct the boundary to
  be recorded "using the D14 scope-boundary framing". That means **EDMV3's D14** ("Phases-as-data --
  scope boundary, not a deferral", `SRD/edm/EDMV3__prompt-streamline/decisions.md:18`), not this
  initiative's D14, which is the Gate 2 AD1 ratification dated 2026-09-02. Write the citation as
  "EDMV3 D14" wherever it appears in the pack; an unqualified "D14" now resolves to the wrong
  decision inside this initiative.
- Citations verified against this tree, with two worth restating more precisely than the SRD does:
  `state_anomalies()` begins at `bin/edm-state:1705` (the SRD cites `:1709-1927`), with the
  `TIME_ORDER` jq block at `:1714-1725`; the terminal-phase `completed_at` refusal is the `die` at
  `bin/edm-state:3181` inside the check at `:3178-3181` (the SRD cites `:3185`, which on this tree is
  a comment inside the following convergence-exemption block). Both are within the SRD's own +/-10
  tolerance, but cite the tighter ranges.
- `OPEN_AUDIT_ROUND`'s informational rationale is the comment at `bin/edm-state:1782-1786` with the
  loop at `:1788-1793`; `edm-lint-staged-artifacts`'s blocking loop is `:146-159` with the
  violation branch at `:150-153`. `skills/orchestrator/SKILL.md`'s Gate PROTOCOL heading is at
  `:123`.
- AC3 is the highest-value item in the ticket and the easiest to skip. `architecture.md:45-49` states
  the same claim `srd.md` `EDMV4-05` explicitly labels false. Leaving it means the architecture
  document is the one place a future reader finds a written assurance that a destructive-`Bash` guard
  already exists.
- Do not fold D15 and D16 into one "descopes ratified" entry. They were presented independently, they
  gate different requirements (`EDMV4-07` versus `EDMV4-44`/`EDMV4-45`), and a merged record loses
  the independence that made the D14 wiring correction necessary in the first place.

### Out of Scope

- Seeking or re-running any gate approval. All three were approved on 2026-09-02;
  `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"` is read as the governing procedure and is not
  modified by this ticket.
- Implementing `edm-gateguard` (`EDMV4-07`), the `Stop` hook entry (`EDMV4-44`), or the three
  `validate` anomalies (`EDMV4-45`).
- Writing the `CLAUDE.md` house-style attribution entries for ECC and GateGuard -- that is
  `EDMV4-12`'s own ticket; this ticket only fixes what triggers its dormant clause.
- Opening the convention gap `srd.md` Sec.5.2 records (that no canonical section covers reductions
  against Gate-1-approved SRD scope). That is explicitly a separate initiative, not an EDMV4 defect.

---

## EDMV4-T54: Map `audit-tickets` to the gate it consumes, not the one it produces

| Field | Value |
|---|---|
| Epic | Preconditions and Change Control |
| Phase | 1 |
| Priority | Must Have |
| Size | XS |
| SRD Refs | EDMV4-60 |
| Depends On | none |
| Blocks | nothing |
| Target Components | `plugins/edm/bin/edm-state` (`cmd_gate_check` and its docstring), `plugins/edm/bin/tests/wave6-smoke.sh` (EDMV3-T13 AC3 block), `plugins/edm/CHANGELOG.md` |

### Description

`cmd_gate_check` maps each phase-skill token to the HITL gate that skill must **consume** before
it may run. Every row carried that meaning except one: `audit-tickets` was grouped with
`implement` on the `required_gate=3` arm. But `audit-tickets` is Phase 5, the phase that
**presents** Gate 3. Requiring Gate 3 in order to run the only thing that can approve Gate 3 is
circular, and Phase 5 was unreachable for every initiative whose mode does not skip it.

Both enforcement layers deadlocked, not one. The `edm:audit-tickets` `UserPromptExpansion` hook
in `hooks/hooks.json` runs the same `gate-check` and blocks expansion on its exit-3 refusal
status, so invoking the slash command directly failed exactly as the Step 0 preflight did.
Neither escape hatch applied: the legacy warn-and-proceed branch needs an absent
`schema_version`, and `gate_required_and_approved` returns `not-required` only when the feeding
phase is skipped or past the mode's terminal phase.

The suite stayed green because the EDMV3-T13 AC3 loop asserted only that *a* gate number was
named, never the correct one -- `audit-tickets` printing "Gate 3" satisfied it perfectly. The
defect went unnoticed because Step 0 preflight and kernel gate enforcement are recent
(EDMV3-T13): EDMV3's own Phase 5 predates them, and VERIF ran `lifecycle_mode=fix-pack`, which
skips Phase 5 entirely. EDMV4 is the first standard-lifecycle initiative to reach the check, and
found it in its own Phase 5 preflight.

### Acceptance Criteria

- [ ] AC1: `cmd_gate_check`'s `case` maps `audit-tickets` to `required_gate=2` on the same arm as
      `tickets`; `implement` retains `required_gate=3` on an arm of its own.
- [ ] AC2: `edm-state gate-check <PREFIX> audit-tickets` exits 0 for an initiative with Gate 2
      approved and Gate 3 unapproved.
- [ ] AC3: `edm-state gate-check <PREFIX> implement` still exits 3 for that same initiative,
      proving the change narrowed only the intended token and did not weaken Phase 6's gate.
- [ ] AC4: `edm-state gate-check <PREFIX> audit-tickets` still exits 3 when Gate 2 is *not*
      approved -- the fix moves the gate, it does not remove enforcement.
- [ ] AC5: The `Gated commands and their required gates` docstring above `cmd_gate_check` states
      the corrected mapping and records the invariant that a token names the gate a phase
      **consumes**, never the one it **produces**.
- [ ] AC6: `bin/tests/wave6-smoke.sh`'s EDMV3-T13 AC3 loop pins every one of the eight tokens to
      its exact expected gate number, and fails on a wrong-but-present gate rather than only on
      an absent one.
- [ ] AC7: A dedicated assertion states the producer/consumer invariant as a **property over a
      live-derived token set**, with **both sides derived** and neither hardcoded:
      (a) the token set comes from `cmd_gate_check`'s own `Valid tokens:` line, already the single
      enumeration its hard-error branch prints (EDMV3-T13 AC4);
      (b) the gate each token **produces** comes from that skill's own `## HITL Gate N` heading in
      `skills/<token>/SKILL.md`, which is where a phase declares the gate it presents;
      (c) the assertion fails on any token whose consumed gate is greater than or equal to the gate
      it produces; and
      (d) it fails loudly if the derivation itself yields fewer than two gate-presenting skills, so
      a broken derivation can never pass vacuously.
      **A hardcoded pair list does not satisfy this AC.** The first implementation of it used one,
      which was caught by the ticket-pack audit (P1-8): a hardcoded list is a second independent
      encoding of one predicate -- the CA-409 class this ticket's own Technical Notes cite as the
      reason `hooks/hooks.json` is left untouched -- and it leaves a ninth token free to
      reintroduce the circularity while the suite stays green, which is verbatim the outcome this
      AC exists to prevent.
- [ ] AC8: `bash plugins/edm/bin/tests/run-all.sh` passes with zero failures on macOS under
      `/bin/bash` (3.2.57).
- [ ] AC9: `plugins/edm/CHANGELOG.md` records the fix as a user-visible bug fix, since it unblocks
      a phase that previously could not run at all. No historical entry is edited.

### Technical Notes

- The `hooks/hooks.json` `edm:audit-tickets` entry needs **no change**. It calls
  `gate-check "$prefix" audit-tickets` and blocks only on exit 3, so it inherits the corrected
  mapping automatically. Editing it would create a second place where the gate number is decided
  -- exactly the CA-409 "two independent procedures for one predicate drift apart silently"
  failure the hook's own prompt text warns against.
- `skills/audit-tickets/SKILL.md` Step 0 also needs no change: it delegates to the same binary.
- Keep the two arms separate rather than collapsing to `tickets|audit-tickets|implement`. The
  gates genuinely differ, and a single arm would be a fresh instance of the same bug class.
- AC7 is the criterion that outlives this fix. AC6 pins today's eight values; AC7 asserts the
  rule that generated them, so a ninth token added later cannot reintroduce the circularity while
  the suite stays green.
- Bash 3.2 floor applies (constraint C1): the assertion loop uses `${spec%%:*}` / `${spec##*:}`
  parameter expansion rather than an associative array.

### Out of Scope

- Auditing the other seven token-to-gate mappings for correctness beyond the assertion AC6 and
  AC7 add. They were verified correct by inspection during diagnosis; no change is proposed.
- Changing `gate_required_and_approved`, the mode-suppression derivation, or the schema-version
  degradation behaviour. The defect is in the token table alone.
- Editing `hooks/hooks.json` or any phase skill's Step 0 text -- see Technical Notes for why both
  are deliberately untouched.
- The broader question of whether other EDM smoke assertions accept a wrong-but-present value the
  way this one did. That pattern is already recorded in the SRD-audit pattern library; a
  tree-wide sweep is not in this ticket.
