# SRD Audit Report: EDMDS -- EDMV4's Structural Design Docket

**SRD Version Audited**: 1.0.0
**Audit Date**: 2026-09-08
**Lanes**: both complete. Section 5 (Requirements, 18 requirements / 75 AC), and sections 1-4
plus 6 (Document Info, Executive Summary, Goals and Scope, Architecture Decisions, Risks).

## Summary

- Section 5: **P0: 5 | P1: 14 | P2: 11 | NOTED: 6**
- Sections 1-4, 6: **P0: 3 | P1: 18 | P2: 15**
- Combined: **P0: 8 | P1: 32 | P2: 26**
- **Verdict: FAIL**

Both lanes reached FAIL independently. The two lanes agree on the single most consequential
finding -- AD1/EDMDS-02's trust-boundary premise is false -- having reached it by different routes,
which is the strongest signal in the report.

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

---

# Lane 2 -- Sections 1-4 and 6

**P0: 3 | P1: 18 | P2: 15. Verdict: FAIL.**

## P0 -- Critical

### L2-P0-1 [FACTUAL MISTAKE] AD1 with R1 -- the trust boundary is not closed by the decision that exists to close it

Independent confirmation of lane 1's P0-2, reached from the architecture decision rather than the
requirement. `edm-gateguard:236-240`'s `exit-code` arm is `printf '%s\n' "$reason" >&2; exit 2`, and
for a `PreToolUse` hook that IS the model-facing refusal -- which is exactly why `edm-bash-gate` and
`edm-stop-gate` use it. Consequences the SRD does not state:

- Under `EDM_GATEGUARD_DENY_MODE=exit-code`, a documented supported value, EDMDS-02 AC1 is vacuous
  (`permissionDecisionReason` is never emitted) and AC2 puts the author's text into the refusal the
  model reads. AC3's assertion passes while the channel is wide open.
- AC5 asks that the other two consumers be "brought into line". Both refuse only via exit 2 plus
  stderr, so "in line with message-on-stderr" means ENTRENCHING the channel at both sites -- the
  opposite of AD1's posture and of the multi-site argument EDMDS-02 uses to reject option 4.

### L2-P0-2 [FEATURE GAP] Sec.1 Mode row and Sec.3.4 -- the fused file is missing its entire Phase-4 half

`skills/srd/SKILL.md:126-142` prescribes the mini-srd layout verbatim: a `## --- Ticket List ---`
section with `{PREFIX}-T{NN}` entries carrying Size, ACs and Target Components, plus a
`Generated From: srd.md vX.Y.Z` line. `srd.md` contains zero occurrences of `EDMDS-T`,
`Ticket List`, `Size:`, `Target Components` or `Generated From:`.

`EDMDS-01`..`EDMDS-18` are REQUIREMENT ids per CLAUDE.md's own distinction; they are not ticket ids.
Since the merged Gate 2+3 discharges Gate 3 and enters Phase 6 directly off this file
(`skills/audit-srd/SKILL.md:190-206`), the downstream breakage is mechanical:

- `/edm:implement` takes an audited ticket pack as Input and groups TICKETS into waves. It has
  nothing to enumerate and no dependency graph.
- Commit subjects carry no `{PREFIX}-T{NN}`, so `edm-impl-progress` sees nothing -- the exact cost
  D48 verified against commit `b697142`.
- `record-partial-verdict <PREFIX> <ticket>` and `archive`'s `OPEN_PARTIALS` block key on a ticket
  id that does not exist. QC shard names and `edm-check-verifier-sentinel`'s `T{a}-T{b}` parse both
  assume ticket numbering.
- The `Generated From:` line is a P0 in the ticket-auditor's own Dimension 8, and under mini-srd
  Phase 5 is skipped, so nothing catches its absence -- silent rather than harmless.

Noted sharply by the auditor: EDMDS-05 exists to fix CA-063, a deliverable omitted from a ticket's
Target Components. This document has no Target Components anywhere, so it reproduces the defect it
is chartered to close.

### L2-P0-3 [COMPETING REQUIREMENTS] Sec.3.1 Goal 1, Sec.3.3, Sec.5 legend -- the closure model uses statuses the vocabulary does not admit

Against `docs/canonical-sections.md:14-23`: "Every P0, P1 and P2 finding is remediated before
convergence; `NOTED` is the only status that closes a finding without a fix", and "deferral does not
exist in this methodology".

- Goal 1's "or record an explicit, reasoned decision not to [close]" is a fifth status. EDMDS-17
  AC3's "descoped" is a sixth. Neither exists.
- Section 5's legend reads "**Should** = expected, may be descoped with a recorded reason", and
  Sec.3.4 item 1 binds only `Must`. That puts CA-063, CA-089, CA-112, CA-072, CA-121 and CA-106 --
  six of eighteen, a third of the docket -- behind an escape the vocabulary does not permit for a P2.
- CA-114 concretely: EDMDS-01 leaves the finding an open P2 with no fix, which is the deferral the
  methodology forbids. "Do nothing" IS defensible on explorer 04's measurement; closing CA-114
  without reclassifying it is not.

## P1 -- Significant (18)

**AD1's central factual claim is false.** AD1 asserts "this plugin has no existing mechanism for
labelling untrusted content" and uses it to justify REMOVING a feature. Two in-tree precedents
contradict it, one machine-enforced: `edm-stop-gate:113-124`'s `stop_gate_emit_blocking <label>
<text>`, whose header states "`<label>` is this script's own literal text and is never sanitized;
`<text>` is the untrusted half" -- pinned under `EDMV4-T52 AC6` at `wave8-smoke.sh:7922-7929`. And
`docs/ecc-integration-analysis.md:95-97` records ECC's assessed "Prompt Defense Baseline". AD1
conflates two claims: that no mechanism can bind a model's willingness to respect a frame (true,
unfixable) and that the plugin has no labelling mechanism (false). The decision turns on the false one.

**AD1 omits the second site EDMDS-02 cites to reject accepting the risk**, and that site --
`edm-lint-staged-artifacts:151`, CA-196 -- is recorded in EDMV4's ledger as `NOTED`, already
accepted. So the SRD invokes a site to refuse acceptance and leaves it unaddressed, while using an
already-accepted finding as grounds for refusing to accept.

**R6's mitigation rests on a false claim.** Sec.2 says "every requirement states what was chosen,
what was rejected, and why". Six of eighteen requirements carry a Rejected block; twelve do not, and
none of the four ADs does. R6's count is also low: the gate is asked to ratify 4 ADs + 18
requirements + at least six sub-decisions embedded in ACs.

**Eight ACs are unfalsifiable disjunctions** -- EDMDS-01 AC6, -03 AC3, -10 AC4, -11 AC2, -13 AC7,
-14 AC4, -15 AC4, -16 AC1 -- each satisfiable by writing a sentence. This hands the implementer the
descope authority `canonical-sections.md:118-123` reserves to a human at a gate. It is Goal 3's
defect one level up, in the ACs meant to enforce Goal 3.

**The single-author chain is absent from the risk table.** `planning.md`'s synthesis, explorer 04's
measurement (which states its own author is the orchestrator), the go/no-go, the Gate 1 record and
all eighteen proposed decisions share one author, with no writer/verifier separation anywhere in the
chain. This is precisely what CLAUDE.md's guard **D1** names as the plugin's core quality mechanism.
R6 addresses only the human reviewer's exposure, not the chain producing what the human ratifies.
Sec.2's "the explorers deliberately withheld recommendations" is true of explorers 01-03 and false
of explorer 04, which is both measurement and recommendation by the SRD's author.

**Six of eight carried constraints are missing from the DoD** -- CC2 (self-matching scans, which
binds hardest exactly where EDMDS-14 AC2 lands), CC3, CC5's operational half, CC8 -- and Sec.1's
Inputs omits `analysis.md`, where they are defined, so a reader of the SRD has no path to them.

**Four live wave8 sites depend on the sanitizer literal existing in place** --
`wave8-smoke.sh:7877`, `:7891` (EDMV4-T52 AC6 ordering checks against `edm-gateguard` specifically)
and `:8996`, `:9027` (sed mutants driving negative controls). EDMDS-14's extraction breaks the first
two and turns the second two into no-ops -- negative controls passing for the wrong reason.
Explorer 03 found two of four; lane 1 found four; this lane identifies which.

**AD2 overstates its asymmetry.** The canonical resolver also accepts `CLAUDE_PROJECT_DIR`
unchecked in one sub-case (`edm-state:1191-1193`, no git toplevel at all), and the third resolver
returns an encoded key with a different fallback (`pwd`, not `.`). EDMDS-11 AC3/AC4 drive only the
in-git pair, so the one sub-case where all three still diverge goes untested.

**AD2's own premise is contradicted by CLAUDE.md**, which still records CA-500 as open at `:1345`
while the code carries the fix. No requirement sweeps it, so EDMDS-11 would ship leaving CLAUDE.md
asserting the opposite of AD2 -- a direct Goal 2 violation.

**AD3 lacks the `audit_type` qualifier** that D40 named as the precondition for closing this gap at
all, and never states its residual: option B checks two of eleven schema fields, and nothing checks
`round`/`round_type` agreement, so a lens JSONL copied verbatim from a PREVIOUS round passes the new
gate. Option C's drift-surface rejection does not apply to those two fields, which are already in state.

**AD4 names only `patterns/` as the ownership footprint.** The clause is `run/` OR `patterns/`
(`_edm-datadir-lib.sh:127`) -- and the omitted half is exactly what EDMDS-13 AC5's sweep operates
on. A pre-D46 install whose only footprint is `run/` markers loses ownership the moment the sweep
removes the last entry, silently relocating that user's data root: the failure class AD4 exists to
prevent, created by the requirement AD4 constrains.

**AD4 binds only Decision B**, while AD2's change has an equal or worse compatibility consequence.
Adopting `edm-state`'s semantics inside `edm_project_key()` renames `<key>.phase6`, `<key>.checked`
and `<key>.denials` for any project where the resolvers disagree -- so EDMDS-11 can trigger, on
upgrade, the exact marker-absent failure EDMDS-10 exists to fix, and nothing addresses it.

**R5's mitigation is wrong in the branch that matters.** If a future Oniguruma REMOVES the retry
limit, EDMDS-01 AC2 does not fail -- it hangs, synchronously, inside `run-all.sh`, with no
`timeout` available and no wall-clock guard by AC6's design. Detection is converted into a suite
wedge. And AC2 does not specify its fixture's input length, so a modest raise leaves it green while
the exposure returns at larger inputs.

**Also**: EDMDS's AD1-AD4 numbering collides with EDMV4's `architecture.md` AD1-AD6, all six still
cited bare in CLAUDE.md inside sections five EDMDS requirements must edit; no `architecture.md`
exists for this initiative although the canonical layout marks it Must/always-present and
`skills/srd/SKILL.md:211` says "Always run `edm-architect` separately"; the two flow/state decisions
(AD2's three-into-one chain, AD3's round-record transitions with three existing downgrade paths plus
a proposed fourth and a proposed reverse edge) are expressed only in prose; Sec.3.3's "EDMDS is the
record of closure" has no mechanical backing -- no ledger, no `resolved_commit`, no `spec_swept`, no
DoD closure item; and the reserved-prefix scope conflict appears in three requirements.

## P2 -- Minor (15)

The 58-figure is real (D46) but uncited and merges a measurement with a generalisation -- no install
was ever abandoned, the change was caught pre-ship. Goal 3's "two predecessors fixed fifteen"
misattributes a figure D51 records for EDMV4 alone, and the "sixteenth" claim traces only to this
initiative's own `analysis.md` -- no record of it was found in EDMTC's artifacts. "Decision B" is a
dangling reference defined only in `planning.md`. The 4048 baseline is verified against EDMTC's
exec-report but anchored to no commit, and two `bin/`-touching commits have landed since with no
re-measurement. DoD item 5's command reports wider than its claim and exits 1 on a clean tree while
item 3 says "exit 0". Item 7 is circular -- discharged by the gate that ratifies the document, and
textually identical to EDMDS-17 AC1. Amending `EDMV4-T11` AC1 edits a file under `.archived/`,
which the artifact lint excludes from every scan. `README.md:342` carries a second live falsehood
("Kill switches for all three consumers") and CLAUDE.md contradicts itself on the same point.
R1's Likelihood "Certain" describes a design consequence, not a risk. R3's Impact "Low" is
inconsistent with its own DoD-gating status and "High" likelihood, and its Mitigation column holds
a change-control procedure rather than a mitigation. Risk rows reference bare AC numbers ambiguous
across eighteen requirements. Two further risks with concrete triggers are absent, including that
EDMDS-08's promotion is INERT when the downgraded round is not the latest -- `audit-converged` keys
on the latest round's type, the very fact EDMDS-08's rationale uses to rule out a repair round.
Sec.1's Branch row disagrees with the working tree, and no `related_prefixes` link to EDMTC exists
although Sec.2's framing and the 4048 baseline both depend on it. And EDMDS-02 rewrites text whose
provenance is an attributed MIT reuse pinned by tests -- D49's order (text first, claim second) is
named in neither the DoD nor the risks.

## NOTED (lane 2)

Sec.1's mode-row quote is verbatim from the canonical matrix, so not a defect in the SRD. Diagram
errors are clean by absence -- filed instead as a P1 for the absence itself. Sec.2's finding
arithmetic is correct and verified against D51 element by element: 39 - 21 = 18, and the eighteen
match D51's group-5 list exactly. Requirement-to-finding coverage is complete and non-overlapping,
no orphan and no double-owner. Sec.3.3's refusal to rewrite the archived ledger matches EDMTC's
precedent. AD2's designation of `_resolve_permcheck_project_root` as canonical is correct against
the code -- the findings concern its overstatement and unswept documentation, not the choice. No
i18n or WCAG obligation arises. DoD items 3 and 4 are satisfiable as written, per D50.

<!-- SRD-AUDIT-COMPLETE range=S1-S6 assigned=23 audited=23 -->
