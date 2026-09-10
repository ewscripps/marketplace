# Pending remediation for srd.md v1.2.0

**STATUS: DISCHARGED 2026-09-10.** All five entries are resolved in `srd.md` v1.2.0 and this file
is retained as the record of what was held and why, because `audit-srd.md` and two commit messages
cite it. Do not add new items here -- the holding rationale below applied to one specific window
(three audit lanes reading v1.1.0), and that window is closed.

| Entry | Disposition in v1.2.0 |
|---|---|
| A1 -- EDMDS-14's extraction target | **Applied, corrected twice.** The target is `bin/_edm-cli-lib.sh`, which all four hook consumers already source. Recorded in `EDMDS-14`'s Decision block and `EDMDS-T22 AC6` |
| A2 -- the 660-line breach | **Withdrawn, then re-derived.** The breach is real but lands at `EDMDS-02`, not `EDMDS-14`, which now buys headroom. `R3` carries the settled arithmetic and `EDMDS-T05` owns the two-file amendment |
| A3 -- AD-DS2's exec argument | **Applied and extended.** `AD-DS2` now states the budget as external binaries, which is what makes the three-way split in `EDMDS-11` possible rather than the two-way one v1.1.0 had |
| A4 -- EDMDS-08's inertness citation | **Applied.** `R9` cites `bin/edm-state:5330` and `:5354`; `EDMDS-08 AC6` owns the refusal |
| A5 -- the `:5144` mis-citation | **No change needed, as recorded.** `srd.md` never cited it. v1.2.0 cites `:5144` correctly, as the manifest-existence trigger, in `EDMDS-07` |

---

Held deliberately, not forgotten. Three audit lanes are reading v1.1.0 as this is written; editing
`srd.md` under them would make their findings unreproducible and drift the version they audited from
the version on disk -- the defect the ticket auditor's Dimension 8 exists to catch. These land in
the same pass as the audit's own findings.

Source: the `edm-architect` agent's verification pass while writing `architecture.md` (2026-09-09).
It re-derived every citation the brief gave it and found four that were wrong. Treated here as audit
findings, because that is what they are.

## A1 (P1) -- EDMDS-14's extraction target is wrong, but not for the reason first recorded

`EDMDS-14 AC1` and `EDMDS-T21`'s Target Components name `bin/_edm-datadir-lib.sh` "or a new shared
lib" as the sanitizer's new home. That is the wrong home, and the disjunction should go.

**Corrected by direct verification.** The `edm-architect` agent reported that only
`bin/edm-gateguard:89-91` and `bin/edm-state:74` source `_edm-datadir-lib.sh`, and concluded that a
NEW library was therefore needed. The first half is true. The conclusion is false: it generalised
from one library without checking the one every consumer already shares.

`bin/_edm-cli-lib.sh` is sourced by **all four hook consumers and `edm-state`** --
`edm-gateguard:52`, `edm-hookify:104`, `edm-bash-gate:69`, `edm-stop-gate:65`, `edm-state:65` --
and by fourteen other `bin/` scripts besides. It is the existing, already-universal home. No new
library, and **no consumer needs a new `source` line**.

Lane B of the v1.1.0 audit reached the same place independently, as a Reuse Opportunity finding
against `EDMDS-02 AC6`, and drew the further consequence recorded as A2 below.

**Fix**: name `bin/_edm-cli-lib.sh` outright in `EDMDS-14 AC1` and in `EDMDS-T21`'s Target
Components, and drop the "or a new shared lib" disjunction. Lane D independently flagged that
disjunction as a Target Components defect (P1-CN1), along with the separate error that T21 names
`bin/edm-bash-gate` (which holds no existing copy) and omits `bin/edm-hookify:226` (which holds one
that must change).

## A2 (WITHDRAWN) -- the 660-line bound does not break from EDMDS-14; extraction helps it

**This entry was wrong and is retained rather than deleted, because the error is instructive.**

It claimed the sanitizer extraction adds a `source` line to `bin/edm-gateguard`, making the file net
`+1` at 659 of a CLOSED 660 bound, and that the breach was therefore arithmetic rather than a risk.
It rested on A1's discarded premise that a new library was needed.

`edm-gateguard` already sources `_edm-cli-lib.sh` at `:52`. Extraction removes the definition at
`:213` and adds nothing, so `EDMDS-14` is net **negative** on the line count. R3 stands as written:
the breach remains a risk driven by `EDMDS-02`'s and `EDMDS-16`'s additions, not a certainty, and
`EDMDS-14` is the one requirement of the three that buys headroom rather than spending it.

Two real findings survive from this entry and are owned elsewhere:

- **Lane D P1-A1**: the four line-count acceptance criteria (`EDMDS-T05 AC6`, `T06 AC5`, `T21 AC5`,
  `T24 AC6`) are verbatim duplicates that cannot fail, because "recorded" asserts nothing. They must
  assert `<= 660`. That finding is independent of this withdrawal and is the more valuable half.
- **Lane B**: `EDMDS-02 AC6` must consume the labelling shape FROM the shared owner rather than
  re-typing it, or it creates sanitizer copies four and five and `EDMDS-14 AC2`'s
  "only one definition exists" scan fails. `EDMDS-02` is a `Must` and `EDMDS-14` a `Should` with no
  stated ordering, so the ordering must be recorded -- or the extraction folded into `EDMDS-02`.

**Lesson worth carrying**: a verification pass that corrects four citations can still ship a fifth
error of its own, and its conclusions deserve the same scepticism as the text it corrected. This one
was caught only because a second lane reached the opposite conclusion and the conflict was resolved
by reading the code rather than by preferring an agent.

## A3 (P2) -- AD-DS2's exec argument is right but imprecisely stated

The CA-500 cross-check is **one external binary plus two forks**, not three execs: `bin/edm-state:1175`
runs `git rev-parse`, while `:1179-1180`'s `cd` and `pwd -P` are bash builtins inside `$( )`.
`EDMV4-T07 AC8`'s budget is counted in external binaries, so the forks alone would not breach it.

This strengthens AD-DS2 rather than weakening it -- the `git` call alone is the whole breach -- but
the decision should say so precisely, since the argument is what carries EDMDS-11's resolution of
two mutually exclusive AC.

## A4 (P2) -- EDMDS-08's inertness argument lacked its citation

`EDMDS-08 AC7` and R9 both turn on `audit-converged` reading only the latest round's type. The
citation is `bin/edm-state:5330` (`$e.rounds[-1].round_type`) and `:5354` (the refusal on
`partial`). Add both; an argument this load-bearing should not rest on an uncited claim in a
document whose Goal 2 forbids exactly that.

## A5 (NOTED) -- one line reference in the prior audit was wrong, and no SRD text depends on it

`bin/edm-state:5144` is the manifest-existence trigger (`if [[ -n "$_pass_dir" && -f "$_manifest" ]]`,
with no `else` -- which is why EDMDS-07 targets it), not the "three-way backstop gate". The backstop
is checks (1), (2) and (3) inside it at `:5153-5196`, and `:5183` scopes check (3) to
`round_type == "full"`. `srd.md` never cites `:5144`, so nothing needs changing; recorded so the
mistake is not reintroduced from the prior round's notes.
