# Pending remediation for srd.md v1.2.0

Held deliberately, not forgotten. Three audit lanes are reading v1.1.0 as this is written; editing
`srd.md` under them would make their findings unreproducible and drift the version they audited from
the version on disk -- the defect the ticket auditor's Dimension 8 exists to catch. These land in
the same pass as the audit's own findings.

Source: the `edm-architect` agent's verification pass while writing `architecture.md` (2026-09-09).
It re-derived every citation the brief gave it and found four that were wrong. Treated here as audit
findings, because that is what they are.

## A1 (P1) -- EDMDS-14's extraction target does not exist as assumed

`EDMDS-14 AC1` and `EDMDS-T21`'s Target Components name `bin/_edm-datadir-lib.sh` "or a new shared
lib" as the sanitizer's new home. **Only two of the six `bin/` scripts source that library** --
`bin/edm-gateguard:89-91` and `bin/edm-state:74`. `bin/edm-hookify`, `bin/edm-bash-gate` and
`bin/edm-stop-gate` source nothing at all. Two of those three hold sanitizer copies
(`edm-hookify:226`, `edm-stop-gate:123`), so the named home cannot reach them.

**Fix**: name a new `bin/_edm-sanitize-lib.sh` outright and drop the disjunction, which the ticket
auditor was independently asked to judge as a Target Components defect. Add an AC for the three
scripts that currently source nothing: each gains a source line, which is a real change to each
file's preamble and not a detail of the extraction.

## A2 (P0) -- the 660-line bound breaks arithmetically, and earlier than R3 assumes

The sanitizer is used inline in a pipeline, so extraction does not remove a line from GateGuard --
it replaces one line with a call and **adds** a source line. Net **+1** on a file at 659 against
`EDMV4-T11 AC1`'s CLOSED 200-660 range (CC7).

So the breach is not R3's "High likelihood" contingency to be handled if it arises. It is certain,
it happens at `EDMDS-T21`, and it happens **before** `EDMDS-02` -- which R3 lists first -- has
written a line. v1.1.0 sequences the three touching requirements to measure after each, which is
the right instinct applied to a case that no sequencing can avoid.

**Fix**: rewrite R3 to state the breach as certain with its trigger named, and move the bound
amendment out of the risk column into `EDMDS-T21`'s own AC, so the amending decision is recorded
work rather than a contingency nobody owns. `EDMDS-T05`, `T06` and `T24`'s "record the line count
after this ticket" AC stay -- they remain the right check once the bound has been amended.

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
