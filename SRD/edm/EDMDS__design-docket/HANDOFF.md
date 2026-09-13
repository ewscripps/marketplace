# EDMDS - Session Handoff

> **Last updated**: 2026-09-13T04:19:38Z by darryl.porter  
> **To resume**: `/edm:orchestrator EDMDS`

## Current Status

- **Phase**: Phase 3 - SRD Audit
- **Gates approved**: 1 of 2
- **Last gate**: Gate 1 - approved 2026-09-08T16:54:57Z by darryl.porter
- **Product**: edm
- **Description**: design-docket
- **Next action**: HITL Gate 2 pending - run `/edm:orchestrator EDMDS` to present SRD for team approval

## Resume Point

- **Phase**: Phase 3 - SRD Audit

**Pending artifacts for Phase 3 - SRD Audit**:

_(all phase artifacts present)_

> Copy-paste to resume: `/edm:orchestrator EDMDS`

## Lifecycle & Mode

- **Mode**: mini-srd
- **Lifecycle mode**: standard
- **Compliance**: false
- **Implementation mode**: standard
- **Forked from**: EDMV4

**Skipped phases:**
- Phase 2: mini-srd: Phase 2 SRD creation fused into a single planning+SRD file (mode phase graph)
- Phase 4: mini-srd: ticket pack fused into SRD file (mode phase graph)
- Phase 5: mini-srd: ticket audit fused into SRD audit (mode phase graph)

## Gates

- Gate 1 - approved 2026-09-08T16:54:57Z by darryl.porter [enforcement: permission-ask]

## Artifact Checklist

| Artifact | Status |
|----------|--------|
| `./SRD/edm/EDMDS__design-docket/planning.md` | [present] |
| `./SRD/edm/EDMDS__design-docket/srd.md` | [present] |
| `./SRD/edm/EDMDS__design-docket/audit-srd.md` | [present] |
| `./SRD/edm/EDMDS__design-docket/tickets/README.md` | [absent] |
| `./SRD/edm/EDMDS__design-docket/tickets/audit.md` | [absent] |
| `./SRD/edm/EDMDS__design-docket/architecture.md` | [present] |
| `./SRD/edm/EDMDS__design-docket/decisions.md` | [present] |
| `./SRD/edm/EDMDS__design-docket/ROLLBACK.md` | [absent] (on-demand) |
| `./SRD/edm/EDMDS__design-docket/exec-report.md` | [absent] (on-demand) |

## Key Decisions Made

_(none recorded yet - decisions are captured at Gate 1)_

-> See full decision ledger: `./SRD/edm/EDMDS__design-docket/decisions.md`

## Related Initiatives

- Related: EDMTC (./SRD/edm/EDMTC__p2-test-coverage)

## How to Resume

1. Pull the latest branch - all EDM artifacts are committed
2. Open Claude Code in the project root
3. Run: `/edm:orchestrator EDMDS`
4. The orchestrator detects the existing initiative and resumes from **Phase 3 - SRD Audit**

## Notes

_(Add anything a teammate should know before resuming - context, blockers, preferences)_


**State: Phase 3 complete, SRD v1.0.0 FAILED audit. Do not enter Gate 2+3.**

Combined audit result across both lanes: **8 P0, 32 P1, 26 P2**. Full report in `audit-srd.md`,
which is the only document that needs reading to resume -- `planning.md` and `explorers/01-04` are
inputs it already accounts for.

### Start here, in this order

1. **Reverse AD1 and rewrite EDMDS-02.** Both lanes independently found AD1's central claim false:
   the plugin DOES have a machine-enforced untrusted-content labelling precedent
   (`edm-stop-gate:113-124`'s `stop_gate_emit_blocking`, pinned at `wave8-smoke.sh:7922-7929`).
   EDMDS-02's rejection of option 1 rests on that false claim. Separately, "put it on stderr" does
   not leave the model-facing channel -- exit 2 plus stderr IS that channel for three of four
   consumers. Cost option 1 against the real precedent before deciding.
2. **Add the Phase-4 half.** `srd.md` has no `## --- Ticket List ---`, no `EDMDS-T{NN}` ids, no
   Size, no Target Components, no `Generated From:` line -- see `skills/srd/SKILL.md:126-142` for
   the prescribed layout. Do this AFTER the decisions settle; ticket ids written against
   requirements that are about to change would only need rewriting.
3. **Fix the closure model.** Goal 1's "or record a reasoned decision not to close" and EDMDS-17
   AC3's "descoped" are statuses the canonical vocabulary does not admit. CA-114 needs splitting:
   remediate the false-header half, reclassify the unbounded-`regex_match` half `NOTED`.
4. **Resolve EDMDS-11's self-contradiction.** AC1 and AC5 are mutually exclusive (the CA-500
   cross-check IS a `git rev-parse`), and AC1 spends the `EDMV4-T07` AC8 fast-path budget that
   EDMDS-04's own rationale invokes to reject a change.
5. **Add a nineteenth requirement for already-polluted installs.** See `upgrade-path.md`,
   written 2026-09-08 after cleaning this host by hand. CA-134's shipped fix does nothing for a
   directory it already polluted -- the C-4 footprint clause that makes the fix safe for legitimate
   installs is what keeps a polluted one claimed. The document carries the discriminator (EDM names
   AND nothing else), the compatibility check against `wave8-smoke.sh:10302-10308`, and the
   detect/migrate/tighten ordering. This is not a variation on EDMDS-13: that one decides where data
   should live, this one what to do about where it already is.
6. Then the remaining P1s, then re-audit, then Gate 2+3.

### Two audit P2s already fixed

`related_prefixes` now links EDMTC, and this file is refreshed. Everything else in the audit is
outstanding.

### Constraints that still bind

- `run-all.sh` at or above **4048 passed / 0 failed** (GNU bash 3.2.57, quiet tree). Note the audit
  flags this figure as anchored to no commit, with two `bin/`-touching commits landed since.
- `bin/edm-gateguard` is at **659** lines against `EDMV4-T11` AC1's closed 200-660 bound. One line.
  Amend by recorded decision if exceeded -- never nudge (D42, D47, D49 precedent).
- CC1-CC8 in `analysis.md`. The audit found six of eight missing from the DoD; carry them in.

### What is NOT blocked

Nothing here depends on information we lack. Every P0 and P1 is actionable from `audit-srd.md`
alone.


**State: Phase 3 run three times. srd.md is at v1.2.0 and FAILED again -- 10 P0, 48 P1, 41 P2
across three delivered lanes. Do not enter Gate 2+3.**

Full report in `audit-srd.md`; prior rounds preserved as `audit-srd-v1.1.0.md` and
`audit-srd-v1.0.0.md`. Held findings in `pending-v1.3.0.md`.

### Read this before doing anything else

`pending-v1.3.0.md` **B3 is a security regression** in `EDMDS-02 AC6`. It specifies writing
project-authored rule text to stdout at the three exit-2 surfaces, and stdout on those events is the
channel the host parses as control (`bin/edm-gateguard:232-234` uses it that way;
`bin/edm-stop-gate:54-55` documents a raw stdout JSON echo as the failure mode). `D52`'s spike
measured plain-text markers on the `Bash` matcher only. **Do not implement `EDMDS-02` until the spike
is extended** to `Stop`, `Edit|Write|MultiEdit`, and a JSON-shaped payload.

### The recommendation on the table, not yet decided by a human

**Split the initiative.** Three of four lanes agree v1.2.0 is mechanically sound -- all 22 AC-range
unions verified, all 40 Target Components paths exist, the D-block allocation collision-free, the
diagram clean, and roughly 65 line citations verified across two lanes with the citations named the
document's strongest feature. Lane D's explicit judgement is that the ticket list is implementable
after four one-line dependency edits.

But four items cannot be fixed by another document pass:

1. `EDMDS-02` -- blocked on the spike above.
2. `EDMDS-15` -- `D54`'s premise is false. Extraction breaks about twenty shipped assertions
   (`wave6-smoke.sh:1440-1446` requires exactly ten `gate-check` occurrences and extraction leaves
   five; `wave7-smoke.sh:7757-7773` checks the command body's literals; `:7790+` executes it in a
   scratch `bin/`). A `type: "prompt"` hook has no include mechanism, so only the command half can
   be extracted at all. **The decision needs re-making by a human, with the real assertion set.**
3. `EDMDS-19` -- `AC7` hard-falsifies `wave8-smoke.sh:10291-10298` while `AC9` requires its inverse
   in the same file, and `AC10`'s operator gating makes `AC7` a no-op on its own migrated branch.
4. `AD-DS6` -- withdraw it. Three lanes independently measured the derivation as narrower than the
   prose it replaced.

The proposal is to take the remaining requirements forward and pull these four, so the sound
two-thirds is not held hostage to items that need runtime evidence rather than more drafting.

### If the split is approved, do this

1. The four dependency edits, which are one line each: `T05 Depends On: T22`; `T30` after `T08` plus
   the line-count AC its five siblings carry; the 13 missing sinks added to `T37`; `T38`/`T39`/`T40`
   before `T36`.
2. The two prose corrections: the critical path is **8** deep, not 6
   (`T01 -> T04 -> T06 -> T07 -> T08 -> T09 -> T37 -> T38`), and the diagram omits the declared edge
   `T17 --> T39`.
3. Fix DoD items 8 and 9. Item 8 is mechanically unsatisfiable -- drift is certain, `--check` exits 2,
   nothing owns refreshing the baseline, and the check is dischargeable by editing the baseline
   inside the script. Item 9 measures `timing.sh --gateguard` before five of the six tickets that
   modify the file it measures.
4. Apply `pending-v1.3.0.md` B1, B2, B4, B5. **B5 matters most**: `EDMDS-05` specifies work that is
   already shipped -- `wave8-smoke.sh:6605` lists six scripts including `edm-bash-gate` and cites
   CA-063 by ID, and `t50_bin_membership_set` at `:6611-6619` already derives the set live. The
   premise came from the v1.1.0 audit and was adopted without re-deriving it.
5. Audit `architecture.md`, which has never been audited in its current 905-line state -- but only
   **after** `AD-DS1` and `AD-DS6` settle, since Section 4 is what it documents.

### What NOT to repeat

The orchestrator's failure mode across all three rounds is **generalising from a partial check**: the
spike measured plain text and the conclusion covered JSON; one library was read and the conclusion
covered all of them; an audit claim was adopted as fact; an assertion set was asserted rather than
derived. `AD-DS6` was that mistake automated instead of fixed.

The remedy that demonstrably worked is slower and duller -- verify each citation, derive each set,
check each path. And a check that returns nothing is not a clean result until you have proven the
check can fire: a grep run this round to find surviving AC disjunctions returned nothing and was
wrong, because acceptance criteria wrap and the pattern only matched their first line.

### Constraints that still bind

- `run-all.sh` at or above **4048 passed / 0 failed across 8 suites on a quiet tree**, still anchored
  to no commit. `EDMDS-T01` exists to fix that and has not run.
- `bin/edm-gateguard` at **659** lines against a CLOSED 200-660 bound. Amending it edits **two**
  places -- the live assertion at `bin/tests/wave8-smoke.sh:4056` and `EDMV4-T11` AC1 under
  `.archived/`. D42 and D47 are the precedent; **D49 is not** and amended no bound.
- CC1-CC8 in `analysis.md`. Measurements are grep-independent: `/usr/bin/grep` and `ugrep` agree on
  every load-bearing count.
