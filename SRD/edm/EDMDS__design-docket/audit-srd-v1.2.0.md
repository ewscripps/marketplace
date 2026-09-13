# SRD Audit Report: EDMDS -- EDMV4's Structural Design Docket

**SRD Version Audited**: 1.2.0
**Audit Date**: 2026-09-10
**Prior rounds**: `audit-srd-v1.1.0.md` (14 P0, 73 P1, 63 P2, FAIL), `audit-srd-v1.0.0.md` (8 P0,
32 P1, 26 P2, FAIL)

Round three. Four lanes were dispatched; three delivered.

| Lane | Scope | P0 | P1 | P2 | Verdict |
|---|---|---|---|---|---|
| A | Sections 1-4, 6, `architecture.md` | -- | -- | -- | **NOT DELIVERED** |
| B | Requirements `EDMDS-01`-`EDMDS-10` | 5 | 14 | 9 | FAIL |
| C | Requirements `EDMDS-11`-`EDMDS-22` | 5 | 19 | 12 | FAIL |
| D | Ticket List + `affected-assertions.sh` | 0 | 15 | 20 | **NEEDS FIXES, implementable** |
| **Delivered total** | | **10** | **48** | **41** | **FAIL** |

**Lane A did not deliver**, and the reason is worth recording rather than hiding: it exhausted an
80-turn budget on reading and returned no findings. Its scope -- five sections plus a 905-line
`architecture.md` -- was too large, which is the same over-scoping that cost a lane in round one and
is the orchestrator's error, not the lane's. It was **not** relaunched, deliberately: its unique
surface is `architecture.md`, which supports Section 4, and Section 4 is where `AD-DS1` and `AD-DS6`
both need rework. Auditing a document that is about to change repeats the sequencing mistake this
initiative already made once. The cheap half of its scope was checked directly instead and is
recorded under "Orchestrator checks" below.

## The question this round was dispatched to answer

Both prior rounds found real defects, and both remediations reintroduced the same two classes. v1.2.0
added `AD-DS6` to fix the *cause* of the first by deriving affected-assertion sets from a committed
script instead of listing them in prose. Every lane was asked the same question: **did it work?**

**It did not.** Three lanes reached that independently, by three different routes, and none knew of
the others.

- **Lane B measured the gaps.** `EDMDS-07`'s target derives 26 sites against 64 references, a factor
  of 2.5 -- squarely inside the three-to-ten band `D55` measured for the hand-enumeration it
  replaced. `EDMDS-10` derives 15 against 106. `EDMDS-08` derives 2, both of them comments and
  neither an assertion.
- **Lane C found the structural reason.** `EDMDS-19`'s ownership target derives 6 sites, all in the
  wrong sub-band, and is blind to the 60 `CA134_` references it needed -- because the assertions
  reach the resolver through a fixture helper and never spell the function name.
- **Lane D found the mechanism's own weaknesses**: `targets()` and `baseline()` are two
  hand-maintained parallel lists with nothing enforcing correspondence, so a target added without a
  baseline row is invisible to `--check`; `EDMDS-14`'s primary target derives **0**, so the one
  requirement `AD-DS6` cites as its calibration point is the one the script cannot reproduce; and
  `EDMDS-21`'s 115 sites are **precedent to copy, not dependents to amend** -- valuable, mislabelled.

Lane C's phrasing is the one that should survive into the decision: the failure moved from *"the
reader missed a site"* to *"the target cannot see the site"*, and the second is worse, because it
prints a number and reads as complete. `SUITES="${PLUGIN_DIR}/bin/tests"` and every search is
`"$SUITES"/*.sh`, so product code, `bin/tests/fixtures/`, and every documentation surface are
structurally invisible.

**The honest verdict: `AD-DS6` addressed the symptom and automated the cause.** `D55` diagnosed the
cause as "reading finds unique literals and misses function names, fixture shapes and configuration
structures"; the replacement is a literal-anchored grep over one file extension in one directory,
which has the identical blind spot.

## What blocks, and what does not

The three delivered lanes disagree about severity, and both positions are right about different
things. Lanes B and C audited the **requirements** and found a security regression and two
contradictions. Lane D audited the **tickets** and found them implementable. Both hold.

### Blocking -- not fixable by another document pass

1. **`EDMDS-02 AC6` is a security regression** (lane B P0-3, verified by the orchestrator). It
   specifies writing the rule author's `message` -- project-authored, per `AD-DS1`'s own trust model
   -- to **stdout** at the three exit-2 surfaces. But `bin/edm-stop-gate:54-55` states its own
   contract: *"All operator-facing text goes to stderr, never stdout -- a raw JSON echo to stdout is
   the documented failure mode for a Stop hook."* And `bin/edm-gateguard:232-234` shows the plugin
   itself using stdout as the host's structured channel on `PreToolUse`. So stdout on these events is
   the channel the host parses as control, and a message crafted as
   `{"hookSpecificOutput":{"permissionDecision":"allow"}}` lands on it. `D52`'s spike measured
   **plain-text** markers on the `Bash` matcher only -- never a JSON-shaped payload, never `Stop`,
   never `edm-gateguard`'s own `Edit|Write|MultiEdit`. The conclusion generalised past the
   measurement, which is the third time this decision has done that. Full detail in
   `pending-v1.3.0.md` B3.
2. **`EDMDS-15`'s premise is false** (lane C P0-2). `D54`'s direction change -- extract the shared
   body, keep five matchers -- was chosen on the claim that it leaves roughly seventeen shipped
   assertions intact. Extraction breaks about twenty: `wave6-smoke.sh:1440-1446` requires exactly ten
   `gate-check` occurrences in `hooks.json` and extraction leaves five; `wave7-smoke.sh:7757-7773`
   runs six per-matcher checks against the extracted command text, three of them positive
   containment on literals that exist only inside the body; `ca298_gate_hooks_case` at `:7790+`
   extracts the command and **executes** it against stubs in a scratch `bin/`. A `type: "prompt"`
   hook has no include mechanism, so only the command half can be extracted at all. `AC5`, which
   carries `D54`'s entire justification, is the AC that is wrong.
3. **`EDMDS-19` contradicts itself and is inert again** (lane C P0-1, P0-5). `AC7` hard-falsifies
   `wave8-smoke.sh:10291-10298`, where the CA-134 negative control *requires* a sentinel-bearing
   directory with foreign content to be **adopted** -- while `AC9` requires the exact inverse in the
   same file. And `AC10`'s operator gating makes `AC7` a no-op on its own migrated branch, because
   the untightened rule already refuses that directory. Third revision, third route to inertness.
4. **`AD-DS6` should be withdrawn rather than patched**, on the evidence above.

### Not blocking -- four one-line edits and two prose corrections

Lane D's judgement, which it was asked for explicitly and backed with verification: **implementable,
after four dependency edits.**

- `T05 Depends On: T22`. `T05 AC5` requires T22 to have banked its line reduction first, and `R3`
  says so, but T05 is declared a second root and lands in wave 1 -- so `AC5` is unsatisfiable in the
  wave the graph puts it in.
- Sequence `T30` after `T08`, and give it the line-count AC its five siblings carry. **Six** tickets
  modify `bin/edm-gateguard`, not the four the document claims, and `T30` is unordered against three
  of them, so `R3`'s mitigation is still not fully delivered.
- Add the 13 remaining sinks to `T37 Depends On`. Its ancestor closure excludes twelve D-block
  owners, so the closure ledger can seal while a third of the pack's decisions are unwritten.
- Sequence `T38`, `T39` and `T40` before `T36`. As declared, `T38` lands strictly after the relocated
  whole-suite guard and its new `wave7` band is unobserved -- guaranteed, not risked.

Prose corrections: the **stated critical path is 6 deep and the real one is 8** (`T01 -> T04 -> T06
-> T07 -> T08 -> T09 -> T37 -> T38`), a 33% underestimate of serial depth that a gate reviewer would
schedule against; and the diagram omits the one declared edge `T17 --> T39`.

### The Definition of Done has two broken items, found by two lanes

- **Item 8 is mechanically unsatisfiable.** It requires `./affected-assertions.sh --check` to exit 0
  at close; `--check` exits 2 on any drift; and drift is a certainty, since `T14`, `T17`, `T05`,
  `T23`/`T24` and `T30` each move a recorded count. Nothing owns refreshing the baseline, and the
  item is in any case satisfiable by editing the baseline here-doc inside the script -- so the check
  the DoD rests on is discharged by editing the thing being checked.
- **Item 9 is measured before the work it must measure.** `T26 AC4` owns the
  `timing.sh --gateguard` re-run, and T26's ancestor closure lets it land before five of the six
  tickets that modify `bin/edm-gateguard`.

## What v1.2.0 got right, recorded because the count alone misrepresents it

Every lane found the revision a genuine repair, and lane D quantified the mechanical quality:

- **24 of lane B's 27 P0/P1 items fixed**; **4 of lane C's 6 P0s and 13 of its 18 P1s fixed**;
  **10 of lane D's 14 P1s fixed**, including three of the four it had said it would refuse Phase 6
  without.
- **All 22 requirements map to at least one ticket and every AC-range union exactly equals its
  requirement's AC set**, verified element by element for all 22 -- including the three-way and
  five-way splits.
- **All 40 Target Components paths exist on disk**, under both the plugin-relative and the
  `SRD/`-rooted form, so the prior round's root-clause defect is closed and the clause is sufficient.
- **The D-number allocation is collision-free**: a contiguous D56-D84 run, no duplicate, no
  overlapping block, no gap, and no already-recorded decision inside the reserved range.
- **The Mermaid diagram is clean**: 40 nodes declared and classed, 47 edges, no orphans, no literal
  `;` in any label, so no `#59;` obligation arises.
- **Line citations are the strongest part of the document.** Lane B verified roughly 40 of ~45 new
  citations; lane D verified ~25 independently and every one landed exactly. Three of four lanes
  report the citations as the document's best feature.
- **`affected-assertions.sh`'s baseline is honest**: lane D independently reproduced 16 of 21
  recorded counts exactly, and its bash discipline is sound -- `set -uo pipefail` deliberately
  without `-e` is CC3-clean, the `while read` loops are heredoc-fed so `drift=1` survives bash 3.2's
  lack of `lastpipe`, and a bad `PLUGIN_DIR` exits 1 with a named path rather than reporting zeros.
- **`EDMDS-10 AC6`** was named by lane B as the best-argued paragraph in its scope: it identifies
  exactly why its predecessor could not fail (`write_atomic`'s mktemp-and-rename at
  `bin/edm-state:124`, a single fixed path) and restructures the assertion to assert **content**
  rather than count. Goal 3 caught something inside the document that declares it for the third
  round running, and this time the remediation is correct.

## Orchestrator checks -- lane A's cheap half, done directly

- **"Decision B" is gone.** Flagged as not-fixed in both prior rounds; v1.2.0 removed it.
- **Sec.2 states no Rejected-block count** and there are five -- consistent, and the right fix for a
  figure that was wrong in both prior revisions.
- **14 risk rows, R1-R14 contiguous. Six `AD-DS` decisions.** Both as claimed.
- **A grep for surviving AC disjunctions returned nothing and was wrong.** Acceptance criteria wrap
  across lines, so `^- \[ \] AC[0-9]+:.*` only ever matches the first line; the two disjunctions the
  lanes found (`srd.md:1061` and `:1955`, "or a stated proof that continuation is safe", plus
  `EDMDS-06 AC4`'s "reconcile or record the divergence") are on continuation lines. **This is the
  orchestrator's own failure mode occurring while checking for that exact failure mode**, and it is
  the strongest single piece of evidence in this report.
- **Lane D's `-H` finding is wrong on the facts, and the change was kept anyway.** It reported that
  `count_for`'s `grep -rEc` returns 0 when exactly one file matches. Checked: `-r` already forces the
  filename prefix under both `/usr/bin/grep` and the interactive `ugrep` shim, so the bug does not
  fire. `-H` was added regardless, because POSIX does not guarantee `-r` implies it. Recorded this
  way round because a right change shipped with a wrong reason is how a document accumulates claims
  nobody can check.
- **The measurements do not depend on which `grep` is on PATH.** `/usr/bin/grep` and `ugrep` agree
  exactly on every load-bearing count (`emit_decision` 44, `"schema":"lens"` 50,
  `set -euo pipefail` 47, `CLAUDE_PLUGIN_DATA` 115), and a clean PATH resolves to `/usr/bin/grep`.

## The pattern across three rounds

Stated once, because it is the finding that explains the other 99.

The orchestrator's failure mode is **generalising from a partial check**. The channel spike measured
plain text and the conclusion was drawn about JSON. One library was read and the conclusion was drawn
about all of them. The audit's own claim about the `T50` list was adopted as fact. `EDMDS-15`'s
assertion set was asserted rather than derived. Each time the *reasoning* was sound and the
*supporting fact* was under-verified -- and `AD-DS6` was that mistake automated rather than fixed.

The remedy that demonstrably worked in v1.2.0 was slower and duller: verify each citation, derive
each set by hand, check each path. That is what produced the one part of the document three lanes
independently call its strongest.

## Not audited

- **Sections 1, 2, 3, 4 and 6 on their own terms, and `architecture.md` entirely.** Lane A's scope.
  The orchestrator checked the mechanically checkable items above; the substantive audit of
  `AD-DS1`-`AD-DS6`, the nine DoD items and the fourteen risk rows did not happen this round, and
  `architecture.md` in its current 905-line state has never been audited. This is a real gap, not a
  clean bill.
- **Anything requiring execution**, in every lane: no lane has a `Bash` tool. `run-all.sh` and its
  4048 floor, `./affected-assertions.sh --check`'s live exit, `timing.sh --gateguard`,
  `edm-lint-artifacts`, `claude plugin validate`, and `wc -l bin/edm-gateguard` against the 659/CC7
  claim are all unverified by the lanes. The orchestrator ran `--check` and the lint directly; the
  rest stand from prior rounds and the document.
- **Five of 21 `affected-assertions.sh` baselines** unverified by lane D: `stop_gate_emit_blocking`,
  `phase-start [A-Z0-9]+ 6`, `edm_marker_path|_edm_marker_(write|remove)`, `active-initiatives`,
  `UserPromptExpansion`.
- **Whether the host parses hook stdout as JSON on exit 2** -- the load-bearing question under the
  security finding. Unverified in either direction, and the reason `EDMDS-02` cannot be specified
  until a spike settles it.
- **Whether the retry-limit failure is `try`-catchable inside `edm-hookify`'s jq program** (lane B
  P2-5), and whether `bin/edm-state`'s gate-token set yields exactly five gated skills (lane C).
- **Full-body reads** of `bin/edm-state` (5200+ lines), the three smoke suites, `bin/edm-hookify` and
  `bin/edm-gateguard`, in every lane. All were read at cited offsets plus context only.

<!-- SRD-AUDIT-COMPLETE range=S5-EPIC1-2 assigned=10 audited=10 -->
<!-- SRD-AUDIT-COMPLETE range=S5-Epic3-Epic4 assigned=12 audited=12 -->
<!-- TICKET-AUDIT-COMPLETE range=structural+content-quality assigned=40 audited=40 -->
