# EDMDS Planning -- EDMV4's Structural Design Docket

**Phase 1 output.** Synthesises `explorers/01` through `explorers/04`. Those reports are the
evidence; this document is the scope, the decision list, and the go/no-go.

**Verdict: GO**, with one finding descoped and two reclassified upward. Reasoning below.

## What Phase 1 changed

Discovery was worth running rather than going straight to implementation, and the reason is
concrete: **three of the eighteen findings are not what they say they are.**

### CA-114 does not reproduce (explorer 04 supersedes explorer 01's framing)

Explorer 01 established the analytical half correctly: the 64 KiB field cap is input-length only,
uniform across all six operators, no pattern-complexity check exists, and neither `timeout` nor
`gtimeout` is on this host. All true. Its four costed options were written on the premise that a
catastrophic pattern therefore hangs the hook.

**Measured, it does not.** On `jq-1.8.1`, `(a+)+$` and `^(a|a?)+$` run 139/144/147 ms against
inputs of 100, 1,000 and 10,000 characters -- flat across a 100x increase. Oniguruma enforces its
own retry limit; at the shape that trips it, `jq` errors (`Regex failure: retry-limit-in-match
over`) rather than hanging. End to end through `bin/edm-bash-gate`, with a benign rule alongside:
the error is **bounded**, the offending rule **file is named**, the benign rule **still fires**
(CA-030's per-file try/catch works), and the exit code is **0** -- non-blocking.

Explorer 01's option 4 ("leaves a source-controlled file able to hang a blocking hook") is
therefore false as stated, and its options 1-3 are solutions to a problem that does not exist in
this form. The decision that remains is narrower and is stated in the table below.

This measurement exists only because explorer 01 flagged that it could not take it --
`edm-explorer` has no `Bash` grant, and I briefed it to run a timing test anyway. It reported the
gap instead of guessing.

### CA-109 is a correctness gap, not a consolidation

Explorer 03: three project-root resolvers exist, and only `bin/edm-state`'s carries the CA-500
physical-path cross-check. `bin/edm-hookify` and `bin/_edm-datadir-lib.sh` accept
`CLAUDE_PROJECT_DIR` unchecked -- and `edm-hookify`'s own comment claiming parity with `edm-state`
is **false**. An attacker-controlled `CLAUDE_PROJECT_DIR` redirects rule discovery and the marker
key. This moves CA-109 from Epic 3's consolidation work into the same severity class as Epic 1.

### CA-072's count is wrong

The finding says the ASCII sanitizer literal is copied five times. Current-tree grep finds
**three**, one per file, byte-identical, no drift. Explorer 03 flagged the discrepancy rather than
reconciling it silently, and could not establish the origin of "five" -- it may have been measured
against an earlier `edm-hookify`. The work is smaller than the finding implies.

## Live measurements of this host

Not code reading -- actual state, from explorer 03:

- **144 findings** accumulated in one host-global pattern delta (`patterns/code-audit.md`), keyed
  by audit-type only, never by project, with no cap.
- **85 stale `.phase6` marker files** in `run/`, traced to `bin/tests/wave6-smoke.sh`'s T06 band,
  which isolates `HOME` and `CLAUDE_PROJECT_DIR` but never `CLAUDE_PLUGIN_DATA`.

The second confirms the unguarded `wave6` writes belong inside Decision B rather than being a
separate item, which was an open question at scoping.

## Scope

The three-epic split **holds under direct code reading** (explorer 03's grouping check): each
group shares a genuine common mechanism rather than file-list proximity. One amendment -- CA-109
is security-relevant and CA-112 is operational, so they are not interchangeable even though both
are "N resolvers should be 1".

### Epic 1 -- Untrusted input and unratified surface (5)

| Finding | Decision to take at Gate 2+3 |
|---|---|
| CA-114 | **Reframed.** Not "how do we bound an unbounded regex" -- it is bounded. Do we depend on Oniguruma's retry limit deliberately (document it, and assert the observed bounded/attributed/isolated/non-blocking behaviour so a future `jq` that raises the limit fails a test), or add an EDM-side bound anyway? `CLAUDE.md` names `jq` with no version floor, which is the residual either way. |
| CA-113 | Should a rule author's `message` reach an operator-facing refusal at all? Four costed options in explorer 01. The hard part is that a trust frame is only as strong as the model's willingness to respect it, and this plugin has no existing mechanism for labelling untrusted content to a model. |
| CA-116 | D26 conditioned `MultiEdit` shipping on a re-test that never happened; `EDMRT` was reserved for it and never created. Ratify on current evidence, or withdraw the arm. |
| CA-122 | `file`-event rules are unreachable outside Phase 6 -- the marker-absent `exit 0` precedes hookify evaluation. Is that intended scoping or a hole? **This one implicates the README I wrote**: `README.md`'s worked example presents `file`-event rules as unconditional with no caveat. Either way the README needs correcting. |
| CA-063 | `bin/edm-bash-gate` is named as a deliverable by no ticket, and its own authorising ticket T45 omits it from Target Components. Record it or explain why not. |

### Epic 2 -- Completeness-gate and round semantics (5)

| Finding | Decision to take at Gate 2+3 |
|---|---|
| CA-090 | What must a `lens-L{N}.jsonl` contain to count as delivered? Today: non-empty and parseable, so `{}` satisfies it. Three costed options, A through C, in explorer 02. |
| CA-091 | A round producing **no** manifest escapes the backstop entirely and keeps whatever `round_type` it started with. Corroborated independently by EDMV4's own D40, which named this gap and reserved a `CAMGAP` prefix that was never used. |
| CA-089 | Irreversibility is enforced by a double-completion refusal, and there is no repair subcommand. The real price, from EDMV4's own state file: **$105.28 and 3h15m** per round, and a repair round does not help because `audit-converged` keys on the latest round's type. |
| CA-074 | The missing `lenses_na` subtraction. Explorer 02 established something important: EDMV4's round-1 shape is **not** an accident of the bug -- the skill layer always subtracts before calling, which masks a defect no test exercises. |
| CA-075 | Removal and recreation are mutually exclusive branches with no lock, and a marker-absent state makes `edm-gateguard` allow every Edit and Write with no further checks. |

### Epic 3 -- Resolvers, data-directory lifecycle, duplication (8)

| Decision | Findings | Shape |
|---|---|---|
| A | CA-109, CA-112 | Which resolver is canonical. CA-109 is behavioural and security-relevant; CA-112 is reporting consistency (`cmd_list` has no phase filter, `cmd_active_initiatives` filters 1-6). |
| B | CA-100, CA-103, CA-105 | Data-directory lifecycle and scoping, plus `wave6`'s unguarded writes. **Hard constraint**: CA-134's C-4 ownership clause treats a directory carrying `patterns/` as EDM-owned. A sentinel-only test provably abandoned existing installs -- 58 failing assertions. Any scoping change must not re-break that. |
| C | CA-072, CA-121 | Duplication with no owner. Three sanitizer copies (not five), byte-identical. `hooks.json`'s five `UserPromptExpansion` blocks: four byte-identical apart from the gate token, the `edm:implement` copy carries one extra clause -- drift confirmed. |
| -- | CA-106 | Only `edm-gateguard` runs `set -euo pipefail`; the other three hook consumers run `set -uo pipefail`, undocumented. Which posture is right for a hook that must not block on its own failure? |

## Constraints

Carried from `analysis.md` CC1-CC8, with two that will bite:

- **`run-all.sh` must stay at or above 4048 passed, 0 failed across 8 suites** (EDMTC's exit
  figure, GNU bash 3.2.57, quiet tree).
- **`bin/edm-gateguard` has ONE line of headroom** against `EDMV4-T11` AC1's closed 200-660 bound,
  at 659. Epic 1 and Epic 3 both touch that file. The bound has been widened twice (D42, D47) and
  each widening was recorded as a decision; a third must be too.

## Go / no-go

**GO**, with these scope adjustments carried into the fused SRD:

1. **CA-114 is descoped from "add a bound" to "decide whether to depend on one".** Its original
   framing is disproved by measurement. Doing nothing is now a defensible option where before it
   was not.
2. **CA-109 is reclassified upward** to Epic 1's severity class -- unchecked `CLAUDE_PROJECT_DIR`
   acceptance in two of three resolvers, with a false comment claiming otherwise.
3. **CA-072 is smaller than recorded** -- three sites, not five, no drift.
4. **CA-122 requires a README correction regardless of which way the decision goes.** The
   documentation I wrote is currently wrong about a shipped feature's reach.

Nothing here is blocked on information we do not have. Two items remain unestablished and neither
gates a decision: the origin of CA-072's "five", and whether a pattern exists that defeats
Oniguruma's retry limit on this build (three classic shapes were tried to 10,000 characters;
absence of a counterexample is not proof).
