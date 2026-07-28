# Code Audit Lens L2 -- Dead Code & Unreachable Paths

- **Lens**: L2 (Dead Code & Unreachable Paths)
- **Date**: 2026-07-28
- **Round**: pass-1 (full, all 11 lenses)
- **Branch**: `edm/edmv3-prompt-streamline`
- **Initiative**: EDMV3 (`SRD/edm/EDMV3__prompt-streamline`)

## Findings summary

| ID | Severity | Site | Defect |
|---|---|---|---|
| L2-01 | P1 | `bin/edm-lint-artifacts:363-367` | Class-2 PCRE branch reads 3 fields from a 2-field `grep -n`; the ignore-set `continue` is dead and the reported line number is file text |
| L2-02 | P1 | `.gitlab-ci.yml:275-284` | `test:smoke-bash32` runs `apt-get` on an Alpine-based `bash:3.2` image, so `before_script` always fails and `script:` is unreachable |
| L2-03 | P1 | `bin/edm-state:314-373` | `compute_cost_usd`'s three current-generation arms match no model in use; every real run hits `*)` and is priced at Sonnet rates |
| L2-04 | P2 | `CLAUDE.md:448-464` | Documents bare family wildcards that no longer exist, and a silent-mispricing mode that can no longer occur |
| L2-05 | P2 | `evals/run-eval.sh:55`, `bin/edm-check-grants:67`, `evals/score-artifacts.sh:100` | Hardcoded `sed -n 'A,Bp'` help ranges stop short of their own headers, making exit-code contracts unreachable output |
| L2-06 | P2 | `.gitlab-ci.yml:327-336`, `:474-480`, `:531-537` | GitLab's default `set -eo pipefail` aborts at the command substitution, so the following `$?` captures and their branches are unreachable |
| L2-07 | P2 | `evals/run-eval.sh:215-220` | Comment documents a `--bare` flag the invocation does not pass, contradicted by the NOTE at `:288-290` |
| L2-08 | P2 | `bin/edm-state:3180` | `${already_closing_verdict:-PARTIAL}` can only ever yield the default on this path, and the default may be wrong |
| L2-09 | P2 | `bin/edm-state:1946-1949` | `prototype)` case arm emits output byte-identical to the `*)` arm below it |
| L2-10 | P2 | `bin/edm-state:2253-2272` | "Tiered vs Untiered Lens Cost" section gated on `.tiering_results`, which no producer writes |
| L2-11 | P2 | `bin/edm-lint-artifacts:435-436, 471` | Three `die` messages lost their `$PREFIX`/`$INIT_DIR`/`$PATH_ARG` interpolation |

**Totals**: 3 P1, 8 P2, 0 P0, plus 15 NOTED.

Open P2 blocks convergence here -- `BLOCKING_FILTER` (`bin/edm-state:809`) includes P2 -- so none of the eight P2 findings is a parking space.

---

## L2-01 (P1) -- class-2 PCRE branch: ignore-set suppression is dead, reported line number is not a line number

`bin/edm-lint-artifacts:363-367`. `grep -n` is given exactly one file, so it emits `lineno:content` with no filename prefix. The three-field read binds `_f=<lineno>` and `lineno=<first colon-delimited chunk of content>`.

- `is_ignored_line "$lineno" "$ignore_set"` compares file text against a set of line numbers and can never match, so `&& continue` is dead. The `edm-lint-ignore` / code-fence escape valve does not work at all for class 2 on any host with GNU grep.
- `sed -n "${lineno}p"` gets a non-numeric expression, errors into `/dev/null`, so `snippet` is always empty.
- Output violates the documented `path:line: <class>: <snippet>` contract (`:30`).

A copy/paste survivor: the other three readers are two-field and correct -- class 1 `:349`, non-PCRE class 2 `:375`, class 3 `:392`. Only the PCRE arm has the extra `_f`.

`_has_pcre_grep` (`:103-106`) is 1 on GNU grep, which the blocking `lint:artifacts` CI job runs, and 0 on macOS BSD grep. **The correct branch runs on the developer's Mac and the broken branch runs in CI** -- the worst split, because the bug is invisible locally.

**Fix**: `while IFS=: read -r lineno _rest; do`. Do not delete the fallback (N1).

## L2-02 (P1) -- the bash-3.2 job's `script:` is unreachable

`.gitlab-ci.yml:275-284` runs `apt-get` against `image: "bash:3.2"`. The official Docker Hub `bash` image is Alpine-based (its own docs list `3.2.57-alpine3.22` and use `apk add --no-cache jq`). Alpine has no `apt-get`; `before_script` fails on its first command and `run-all.sh` under bash 3.2 never runs.

The tag is fine; only the package manager is wrong. The job exists, is not `allow_failure`, and will red-flag every pipeline, while the thing it was built to prove (T61 AC10) is never proven. Combined with the deliberately-omitted macOS runner (`:286-295`), **no job currently exercises the plugin under its declared target shell.**

**Fix**: `- apk add --no-cache jq git`. Add an assertion that `bash --version` reports 3.2, so a future image bump cannot pass this job while proving nothing.

## L2-03 (P1) -- the current-generation pricing arms match no model in use

Arm order after the wave-C narrowing: `*opus-4-7*`/`*sonnet-4-6*`/`*haiku-4-5*` (frozen), `*opus-4-8*`, `*haiku-4-6*`, `unknown`, `*sonnet-4-7*`, `*)`.

No arm is shadowed, and the `unknown` sentinel arm remains reachable (`get_session_tokens_since` emits it at `:247`, `:273`, `:292`, `:295`) -- neither is a finding.

The finding is the other direction. `.message.model` is the driving session's concrete model ID. This plugin's agents run on the current generation, not Opus 4.8 / Sonnet 4.7, so:

1. `*opus-4-8*`, `*haiku-4-6*`, `*sonnet-4-7*` are unreachable for every model in current use.
2. Every real `phase-complete` and `audit-round-complete` prints the `*)` unrecognized-model warning.
3. Every Opus-driven phase's `estimated_cost_usd` is computed at Sonnet-4.7 rates -- input 4 vs 6, output 20 vs 30, cache-write-1h 8 vs 12 -- understating recorded spend by roughly a third, in the field `metrics-report` publishes.

Tests do not catch it: `wave6-smoke.sh:3488` uses a deliberately alien string and `:3505` uses `claude-opus-4-8-20260701`; nothing asserts the generation actually in production.

**Fix**: add arms for the live generation with verified rates, refresh the `CLAUDE.md` pricing tables, and add a case pinning the live generation.

## L2-04 (P2) -- CLAUDE.md documents a branch that no longer exists

`CLAUDE.md:448-464` describes the bare family wildcards and states that a newer in-family generation is priced silently with no warning. Both describe the pre-narrowing code. `claude-opus-5-20260501` now matches nothing, falls to `*)`, and does warn. A reader following this section concludes cost figures are silently mis-generationed with no signal, when the signal exists and is firing on every run (L2-03) -- the opposite diagnostic.

**Fix**: rewrite to describe the eight actual arms and the real gap.

## L2-05 (P2) -- three more scripts truncate their own help

The sentinel convention was applied to `edm-state`, `edm-lint-artifacts`, `edm-check-vocabulary`, `edm-compare-eval` and `tiering-matrix.sh`, and missed on three with the identical defect:

| Site | Range | Header ends | Unreachable |
|---|---|---|---|
| `evals/run-eval.sh:55` | `2,33p` | 40 | Cuts mid-sentence; exit codes 2 and 4 never printed |
| `bin/edm-check-grants:67` | `2,45p` | 57 | Output format (`:46-49`) and exit contract (`:51-52`) |
| `evals/score-artifacts.sh:100` | `2,45p` | 85 | The `total` normalization rule and the jq expression the header calls non-negotiable |

`run-eval.sh` is worst: `--help` ends mid-sentence and hides the two exit codes CI keys off.

**Fix**: sentinel treatment on all three, plus a CI grep banning `sed -n '[0-9]*,[0-9]*p' "$0"` to close the class.

## L2-06 (P2) -- three CI exit-code diagnostics are unreachable

GitLab Runner executes each job script with `set -eo pipefail`. An assignment from a command substitution carries that command's status, so a non-zero result aborts at the assignment, before the `$?` capture and every branch reading it.

1. `:327-336` -- `edm-state validate` exits 3 on a blocking anomaly, so `ec=$?`, the `BLOCKING anomaly in <prefix>` line, the remaining loop iterations and the summary are all unreachable. The job's design (sweep all, print every anomaly, fail once naming the code) collapses to "die at the first one with no explanation". `set -u` at `:310` does not disable `-e`.
2. `:474-480` -- the `claude plugin validate` structural-error message is unreachable.
3. `:531-537` -- exit 3 aborts, so the `NOT ARMED` arm is unreachable. The comment at `:527` promises exactly that it is reported. Since no baseline is committed, exit 3 is the guaranteed path, so this is the arm that would fire on the first real nightly run.

(2) and (3) are on `allow_failure` jobs, hence P2; (1) is on a blocking job.

**Fix**: `out="$(cmd 2>&1)" || ec=$?` with `ec=0` initialized -- the idiom `edm-state:705` and `:1308` already use.

## L2-07 (P2) -- a comment documents a flag the invocation does not pass

`evals/run-eval.sh:215-220` describes `--bare` as what makes AC8 true at the CLI level. `:288-290` says the opposite and explains why it was removed. `--bare` appears nowhere in the `claude -p` invocation (`:279-287`). Two comments in one function disagreeing about a flag's presence is the drift this initiative exists to remove.

**Fix**: delete `:215-220`, fold anything surviving into the `:288-290` NOTE.

## L2-08 (P2) -- a parameter default that always fires, and may be wrong

`bin/edm-state:3180` is reached only when `already_closed != "true"`, so `already_closing_verdict` is necessarily empty and `:-PARTIAL` always fires. The open path legally writes `PASS`, `PARTIAL` or `FAIL`, so closing a `FAIL` entry prints "(was PARTIAL)" -- a fabricated prior state in a field the archive gate and the `OPEN_PARTIALS` anomaly both reason about. It reads `.closing_verdict` where the open shape's verdict is `.verdict`.

**Fix**: read the real prior verdict; or drop the dead expansion so no reader thinks a variable is consulted.

## L2-09 (P2) -- a case arm identical to its fallback

`bin/edm-state:1946-1949`: when `$mode` is `prototype`, `${mode}` expands to `prototype`, so the fallback produces the identical string. Pure duplication -- the shape that rots.

**Fix**: delete the `case`, keep the single `${mode}` line.

## L2-10 (P2) -- ~20 lines of rendering that has never rendered

`bin/edm-state:2253-2272` is gated on `.tiering_results` having length > 0. The comment at `:2255-2256` states plainly that no producer exists. `cmd_init` does not seed it; no `rmw_state` filter writes it; `evals/tiering-matrix.sh` prints a table to stdout and never touches state. Grep confirms `tiering_results` appears only at `:2259` and `:2261`.

**Fix**: land the producer, or delete the block and keep the anticipated-shape note in CLAUDE.md. Do not leave a rendering path that has never rendered and has no test that could notice if it broke.

## L2-11 (P2) -- three `die` messages lost their identifying half

`bin/edm-lint-artifacts:434-436, 471` -- `$PREFIX`, `$INIT_DIR`, `$PATH_ARG` expansions are gone, leaving a double space, `init )` with an empty argument, and two messages that name a path then print nothing. The messages fire but their identifying content is dead, from a script whose `--help` promises exit 2 is distinguishable so the hook can tell a misinvocation from a dirty tree.

**Fix**: restore the three interpolations.

---

## Noted / Not Actionable

- **N1** `bin/edm-lint-artifacts:103-106, 358, 369-381` -- both PCRE branches are live; `_has_pcre_grep` takes both values across the two targeted environments and the `LC_ALL=C` fallback is the only working path on macOS. Delete neither. The defect inside the PCRE arm is L2-01.
- **N2** `convergence_exempt()` factoring is clean at both call sites; `cmd_approve_gate:1278-1294` deliberately applies the mode half only and `:572-575` documents why. No residue.
- **N3** The delete-list epic left no residue. `TaskCompleted` absent from `hooks/hooks.json` (six families, valid JSON); `record-task-duration` has no dispatch entry, help line or function; `lifecycle_mode=partial` absent from `LIFECYCLE_MODE_ENUM_LIST` and from `cmd_set_mode`. The three surviving mentions are deliberate read-compatibility, each documented at its site.
- **N4** `edm-lint-artifacts` orphan check clean. `mermaid_line_is_violation` gone; `mermaid_scan_awk` defined `:213` called `:425`; `build_line_classes` defined `:143` called `:314`. `TICKET_PACK_DIRNAME` correctly absent here and read at ten live sites in `edm-state`.
- **N5** `edm-state` dispatch/help/function agreement is exact -- 40 each way, all four non-`cmd_` helpers have live callers.
- **N6** `cmd_gate_check` accepts exactly the eight tokens in use; no arm shadowed, `*)` reachable and tested.
- **N7** `pattern_target_heading_for:3407-3412` single-`*)` case -- documented extension point, coupled to adding a README mapping row.
- **N8** `cmd_migrate_schema:1831-1833` arithmetic is a no-op today; defensive against `schema_version: 3`, which CLAUDE.md records as deliberately unassigned.
- **N9** `score-artifacts.sh:542-587` `cmd_compare` is a second comparison implementation CI does not use, retained deliberately and exercised by `wave7-smoke.sh:464-478`.
- **N10** `edm-check-grants:550-555` always warns for `Edit` by design -- how the synthesizer's unexplained grant was found; advisory only.
- **N11** `edm-check-vocabulary:259/261` would misparse `grep -n` if `FILES` held one file -- unreachable today, noted so a future scope narrowing does not reintroduce L2-01 here.
- **N12** `vocabulary-allowlist.txt` has no dead entries; all seven paths resolve.
- **N13** `cmd_audit_converged:3009-3016` both arms `return 3` with materially different diagnostics. Correct.
- **N14** `evals/tiering-matrix.sh:251` unknown-flag guard cannot see `-h`/`--help` because they exit earlier. Deliberate two-stage parse.
- **N15** `run-eval.sh --provision-only` has no automated test; documented as manually exercised. Test-coverage observation, not unreachable code.

---

## Not examined

- `bin/tests/wave3`, `wave4a`, `wave4b`, `wave5`, `harness-smoke.sh`, `timing.sh` -- not reviewed for dead assertions or fixtures for removed paths. `wave6-smoke.sh` read only around T13 and T52; `wave7-smoke.sh` only around T61, T23, T48, T66. `run-all.sh` and `_harness.sh` read in full and clean for this lens (both use `set -uo pipefail` without `-e`, so their `$?` captures are genuinely reachable, unlike the CI ones in L2-06).
- `bin/edm-init`, `edm-validate-prefix`, `edm-sync-canonical-sections`, `edm-check-skill-sync` -- not opened. `edm-check-skill-sync` guards "the branch that was NOT taken", the profile most likely to hide an L2 finding; warrants a follow-up look.
- `skills/*/SKILL.md` and `agents/*.md` prose -- out of scope except where a `gate-check` token bore on reachability (N6).
