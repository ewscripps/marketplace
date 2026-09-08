# SRD Audit Report: EDMDS -- EDMV4's Structural Design Docket

**SRD Version Audited**: 1.0.0
**Audit Date**: 2026-09-08
**Lanes**: section 5 (Requirements, 18 requirements / 75 AC) complete. Sections 1-4 and 6 lane
still running at time of writing; its findings append below when it lands.

## Summary

- Section 5: **P0: 5 | P1: 14 | P2: 11 | NOTED: 6**
- **Verdict: FAIL**

Five P0s are hard blockers. Three requirements are unimplementable as written against verified
live code, one falsifies two shipped smoke assertions the SRD's own Definition of Done requires to
keep passing, and one is an assertion that passes against the unfixed code -- the exact defect
class this initiative's Goal 3 forbids.

## P0 -- Critical

### P0-1 [FACTUAL MISTAKE] EDMDS-02 AC1, AC2 -- the rule file path never crosses the process boundary

`bin/edm-hookify:369` builds the match record as
`"M\t" + scrub(name) + "\t" + scrub(action) + "\t" + scrub(message)`. The `E` setup-error records
at `:357`, `:361`, `:392` all carry `scrub($path)`; the `M` record does not. So
`hookify_emit_match` (`:414-425`) prints `<rule_id> <action> <message>` and nothing more, and
`edm-gateguard:647` captures exactly that. AC1 requires the rule file path in
`permissionDecisionReason`; AC2 requires the message "attributed to its file". Neither is
implementable. `name` is a required schema key, so even the `// "unnamed"` fallback is unreachable.

**Fix**: add an AC changing `edm-hookify`'s matched-rule output contract to carry the path, and
name `bin/edm-hookify` and `EDMV4-T44`'s exit/output contract as in-scope surfaces. CLAUDE.md
documents the three-field shape in two places, so that is a spec sweep too.

### P0-2 [FACTUAL MISTAKE] EDMDS-02 (whole requirement) -- stderr IS the model-facing channel

The decision rests on stderr not being model-facing. That is false for every exit-2 refusal.
`emit_decision`'s `exit-code` arm (`edm-gateguard:236-240`) does `printf '%s\n' "$reason" >&2;
exit 2`, and for a `PreToolUse` hook exit 2 is precisely the case where stderr is returned to the
model as the refusal reason. `edm-bash-gate:136` and `edm-stop-gate:216,244` are exit-2-plus-stderr
by construction with no second channel at all.

So "put the author's message on stderr" does not move the text out of the model-facing channel in
three of four code paths -- it relocates it within the same channel. R1's stated mitigation ("the
message still reaches stderr") is in fact the failure mode. AC5's escape hatch lets the requirement
close with the channel intact at two of three consumers.

**Fix**: restate the decision per deny mechanism, or add an AC recording that the boundary is only
enforceable in the `json` back-end and what the residual is for the other three surfaces.

### P0-3 [COMPETING REQUIREMENTS] EDMDS-11 AC1 vs AC5 -- the cross-check IS a git call

AC1 requires `edm_project_key()` to apply the CA-500 cross-check. AC5 requires it to keep spawning
`git` only when `CLAUDE_PROJECT_DIR` is unset. The cross-check *is* a `git rev-parse` on exactly
the path AC5 protects.

- `_resolve_permcheck_project_root` (`bin/edm-state:1172-1199`) spawns `git rev-parse
  --show-toplevel` unconditionally at `:1175`, then two `cd ... && pwd -P` subshells.
- `edm_project_key()` (`bin/_edm-datadir-lib.sh:172-185`) spawns `git` only inside
  `if [[ -z "$dir" || ! -d "$dir" ]]`, and the header at `:45-46` states that as the contract.
- `EDMV4-T17` AC7 is not merely documentation: its smoke test shadows `git` with a failing stub and
  requires all three functions to still succeed. AC1's cross-check fails that stub by construction.

**Fix**: decide which wins. If AC1, add an AC amending `EDMV4-T17` AC7 and re-measuring the allow
path. If AC5, narrow AC1 to two resolvers and record the marker-key redirection as an open
residual.

### P0-4 [COMPETING REQUIREMENTS] EDMDS-11 AC1 -- spends a budget the SRD declares inviolable

`edm-gateguard:98` calls `edm_marker_path()` before the marker test at `:102-104`, and that chain
invokes zero external binaries today. Adding the cross-check puts a `git` exec on the marker-absent
fast path -- the same `EDMV4-T07` AC8 budget EDMDS-04's own rationale uses to REJECT a change.
`README.md:300-301` advertises the property to users.

**Fix**: as P0-3, and reconcile with EDMDS-04 so the SRD does not spend one budget it declares
sacred elsewhere.

### P0-5 [FEATURE GAP] EDMDS-07 AC1 -- falsifies two shipped C-4 assertions with no owner

`bin/tests/wave6-smoke.sh:1132-1140` (the `CA471NODIR` band) asserts that a manifest-less round
stays silent and keeps `round_type=full`, explicitly labelled C-4 backward compatibility. EDMDS-07
AC1 makes both fail, and no AC owns amending them. Section 3.4 item 2 requires `run-all.sh` at 4048
with zero failures and 3.3 forbids reducing the assertion count, so a Must Have cannot coexist with
the DoD.

Six further `code` rounds complete with no pass directory in the same suite (`:681, :697, :738,
:750, :778, :790`) and become `partial` under EDMDS-07; their downstream `--accept-p2-debt` and
`audit-converged` assertions need re-checking.

**Fix**: add an AC naming that band as a surface to amend, and state the amended expectation.
Note the scoping itself is correct -- `bin/edm-state:5116`'s `audit_type == "code"` guard predates
this SRD.

## P1 -- Significant

1. **EDMDS-01 AC2 requires an unreachable exit code.** `edm-hookify eval bash` returns **1** on a
   rule-evaluation error (`E` record at `:392`, `HAD_ERROR=1` at `:436-445`, ladder
   `block(2) > error(1) > clean(0)` at `:476-480`). The `exit=0` in explorer 04 came from
   `edm-bash-gate`, which translates 1 into 0. **I mis-transcribed which binary produced the 0 when
   writing the AC from my own measurement.** Reword to require 1 from the evaluator plus a separate
   clause driving `edm-bash-gate` for exit 0 and no block.
2. **EDMDS-01 cannot close CA-114 as a remediated P2.** The finding carries two claims: the header's
   false cost-bounding statement (genuinely fixed by AC1) and "no time bound" (still literally true
   after EDMDS-01 lands). AC6 records that nothing was added; R5 confirms a future `jq` reopens it.
   Under the canonical vocabulary, `NOTED` is the only status that closes without a fix, deferral
   does not exist, and the P2-debt exception is a human choice at the convergence gate that an SRD
   may not pre-authorise. **Split CA-114**: remediate the documentation half, reclassify the
   unbounded-`regex_match` half NOTED.
3. **EDMDS-09 AC2 is invariant under the fix -- it passes against unfixed code.** Unfixed:
   `lenses`=14, `lenses_na`=["L13"], union 14 -> `full`. Fixed: `lenses`=13, same union -> `full`.
   Identical. This is a sixteenth instance of the class Goal 3 exists to prevent. Assert the
   `lenses` array itself, or drive `audit-round-complete`.
4. **EDMDS-09 misses half of CA-074** -- the finding's "never checks disjointness" clause. AC1
   touches only the materialised branch; a hand-passed non-disjoint pair still double-counts.
5. **EDMDS-06 has no AC updating the 14 lens prompts** that tell agents what to write. CLAUDE.md's
   house contract pins those copies byte-identical under a smoke assertion, so the change must land
   across 14 files atomically. AC1's "at least one line" is also a new producer obligation nothing
   communicates to the producer.
6. **EDMDS-06 AC3's all-lines rule makes a $105/3h15m round non-convergent for one bad line**, with
   only a `Should` (EDMDS-08) as pressure valve. Unparseable lines already fail today via
   `jq empty`; what AC3 newly decides is that a parsing-but-not-lens-shaped line fails the file.
7. **EDMDS-08 does not prevent self-certification by fabrication.** The checks are on file content
   and the caller controls file content -- under EDMDS-06 the bar is one JSON object with a matching
   `lens` and legal `sev`, forgeable in one `printf`, as `wave6-smoke.sh:877` demonstrates. R4's
   mitigation is true and irrelevant: fabrication passes the checks rather than bypassing them.
8. **EDMDS-08 does not narrow the double-completion refusal** that enforces irreversibility, and
   does not sweep three downgrade messages at `bin/edm-state:5163,:5177,:5193` that become false.
9. **EDMDS-10 AC4 names the wrong lock granularity.** `with_state_lock` is per-initiative; the
   Phase-6 marker is per-project. An initiative-scoped lock cannot serialize against a
   `phase-start 6` on a different initiative, which is the race CA-075 names.
10. **EDMDS-12 AC2/AC3's fixture cannot discriminate.** Both derivations already exclude
    `.archived/`; the real divergence is `cmd_list`'s unconditional phase print versus
    `cmd_active_initiatives`' `1..6` gate. Use phase 0 and phase 7 initiatives.
11. **EDMDS-12 drops half of CA-112's prescription** -- "neither consumer should parse the
    human-readable listing". AC1 is satisfiable by retargeting the same awk at a different
    human-readable stream.
12. **EDMDS-13 AC6 re-specifies an assertion EDMTC already shipped** at
    `wave7-smoke.sh:10186-10228`. Re-authoring creates a second copy with no shared owner -- the
    exact defect class EDMDS-14 and EDMDS-15 exist to fix.
13. **EDMDS-13 AC4's "documented cap" decides nothing** -- no value, no unit, no choice between
    prune-oldest and refuse-to-append, and "oldest" presumes an ordering key the delta may not have.
    Satisfied by documenting a cap of one million.
14. **EDMDS-13 AC5 writes today's host-local number into an AC.** Directly forbidden by D15's
    "write the delta, not the total". Running the DoD suite increases the figure until AC6 lands,
    so the AC is stale by construction -- CA-067's class.
15. **EDMDS-14 breaks two shipped `EDMV4-T52` ordering assertions** at `wave8-smoke.sh:7877,:7891`,
    which match the literal `LC_ALL=C tr -c` inside `edm-gateguard`. No AC owns the sweep.
16. **EDMDS-14 AC2 misses the finding's central point** -- the existing assertions key on a marker
    string, so a character-set drift passes. Assert the character set, not the marker.
17. **EDMDS-16 AC1 contradicts its own Decision line** -- the Decision says converge, AC1 permits
    keeping differences with a comment, which is the status quo.
18. **EDMDS-16 AC3 is green on CA-077's actual failure mode.** `edm-gateguard` expresses a DENIAL
    by printing JSON to stdout and exiting 0, so a `set -e` abort before that print reads to the
    host as no decision -- fail-open. An assertion checking only "never blocks" passes on that.

## P2 -- Minor (11)

Scope conflict between 3.3's out-of-scope prefix list and EDMDS-07 AC4 / EDMDS-18 AC1; duplicate
ownership of `CAMGAP`; D40's harder half (a `code` round that legitimately produced no manifest)
unanswered; EDMDS-03 AC2's unverifiable negative existential; EDMDS-11 AC3's vague "agree on
rejecting it" across three different return types; EDMDS-11's missing backward-compatibility AC for
a changed project key orphaning existing markers; EDMDS-14 AC1 and EDMDS-15 AC2 pinning literal
counts while sibling AC require deriving live; EDMDS-14 AC2's scan self-matching the test suite
(CC2); EDMDS-13 AC5 not stating the sweep may not remove `run/` itself, which AD4's ownership test
keys on; EDMDS-13 AC6's unnamed "a suite run"; and EDMDS-13 being too large -- 7 AC, 4 findings and
a test fix under one priority, recommended split three ways.

## NOTED (6)

EDMDS-06 vs existing lens fixtures checked and clean; EDMDS-07's `code`-only scoping already
correct via a pre-existing guard; EDMDS-03's substitute evidence verified sound; EDMDS-01 AC4's
control shape correct; EDMDS-05 AC2/AC3 named the strongest AC pair in the section and the shape
the rest should follow; and a pre-existing CLAUDE.md self-contradiction in the `EDM_HOOKIFY_*`
section -- it opens saying all three consumers honour the switches and closes saying `edm-stop-gate`
does not, while the code (`edm-stop-gate:95-98`) shows it does. The closing paragraph is stale.

## Measured claims -- verification status

| Claim | Status |
|---|---|
| `$105.28` / `3h15m` per round | **Verified** -- archived state file `:198`, `:189` (3h14m34s) |
| EDMV4 round-1 shape (13 / `["L13"]` / `full`) | **Verified** -- same file `:168-186`; frozen archived data, so legitimate as an absolute in an AC |
| Three sanitizer copies, not five | **Verified.** Also corrects explorer 03: `wave8-smoke.sh` carries FOUR occurrences, not two |
| One line of headroom (659 / 660) | **Verified** -- file ends at 659; bound at `epics/02-gateguard.md:65`; D47's own eight-line caveat consumed to one by D49 |
| `wave6-smoke.sh` never isolates `CLAUDE_PLUGIN_DATA` | **Verified** -- 0 occurrences, versus 93 / 19 / 3 in wave8 / wave7 / timing |
| All 18 findings have a requirement | **Verified** one-to-one; every coverage defect is within-requirement |
| 144 findings in the host-global delta | **Unverified** -- host-local, auditor has no Bash. Not load-bearing (Description only) |
| 85 stale `.phase6` markers | **Unverified** -- same reason. IS load-bearing (EDMDS-13 AC5), which is P1-14 |
| `run-all.sh` at 4048 / 0 | **Unverified** -- requires executing the suite |

## Not audited (stated so absence is not mistaken for cleanliness)

EDMDS-04's five AC individually (its two source facts were verified); EDMDS-15 AC1/AC3/AC4;
EDMDS-17 entirely; EDMDS-18 AC1's substantive question. Roughly 45 of 75 AC received the individual
falsifiability sweep -- not swept: EDMDS-04 AC1-5, EDMDS-15 AC1/3/4, EDMDS-17 AC1-3, EDMDS-13 AC7,
EDMDS-05 AC1, EDMDS-03 AC1/AC3, EDMDS-10 AC1/AC2. Of these the auditor expects EDMDS-13 AC7 to
yield a finding on a second pass, because it pre-announces its own answer ("the likely answer is
none needed") in an AC whose stated purpose is that the answer be stated rather than assumed.

Diagram errors are vacuously clean for section 5 -- it contains no diagrams.

<!-- SRD-AUDIT-COMPLETE range=S5 assigned=18 audited=18 -->
