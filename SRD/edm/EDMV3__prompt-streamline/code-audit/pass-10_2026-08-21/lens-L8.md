# Lens L8 -- Security & Portability (Round 10, full sweep)

Scope swept this round: `plugins/edm/bin/*` (all 15 entries), `plugins/edm/bin/tests/*.sh` (targeted), `plugins/edm/hooks/hooks.json` (full), `plugins/edm/monitors/monitors.json` (full), `plugins/edm/evals/run-eval.sh` (full), `plugins/edm/evals/score-artifacts.sh` (partial/targeted), `plugins/edm/evals/tiering-matrix.sh` (targeted), `plugins/edm/evals/README.md`, `.gitlab-ci.yml` (full, 820 lines), `plugins/edm/CLAUDE.md` + `README.md` (targeted greps).

Coverage caveat (report as unaudited, not clean): no Bash in the delivered tool set, so **no file mode was observed** and **nothing was executed**. `plugins/edm/skills/**/SKILL.md`, `plugins/edm/agents/*.md`, `plugins/edm/docs/**`, `CHANGELOG.md` and `bin/tests/wave3/4a/4b/5-smoke.sh` were covered by targeted grep only (injection/fd/hardcoded-path/secret patterns), not read end to end.

---

## Prior-round L8 ledger verdicts (explicit, with file:line evidence)

### CA-474 -- P1, `.gitlab-ci.yml:301` -- **VERIFIED FIXED**
The `while IFS= read -r -d ...` loop is gone. `lint:hooks-shell` now derives the bound from jq and indexes:
- `.gitlab-ci.yml:312` -- `EXPECTED_COUNT="$(jq '[.hooks | to_entries[] | .value[] | .hooks[] | select(.type=="command")] | length' ...)"`
- `:316-321` -- non-numeric `EXPECTED_COUNT` is rejected up front with an explicit `case` (closing the silent-pass hole the finding named as a consequence of the fix)
- `:323` -- `while [ "$IDX" -lt "$EXPECTED_COUNT" ]; do` (POSIX `[`, no bashism)
- `:328` -- `jq -r --argjson n "$JQ_IDX" '[...][$n].command' ... > "$cmdfile"` -- one file per command, no shared stream to re-split, so CA-437's embedded-newline case is handled by construction
- `:343-346` -- the cross-check survives and its message is retargeted at a jq/index mismatch
- `:278` and `:294-311` -- the job header now asserts POSIX-sh safety explicitly and records the measured `dash` vs BusyBox `read -d` difference; `:544-549` and `:596-598` carry the matching notes on the two sibling jobs.
I re-swept every `script:` body in the file for bash-only constructs (`[[`, `local`, here-strings, `mapfile`, `declare`, array syntax, `read -d`): **zero hits**. The file no longer asserts one thing and does another. Close.

### CA-499 -- P2, `plugins/edm/bin/edm-lint-staged-artifacts:1` -- **STILL OPEN**
`plugins/edm/bin/edm-lint-staged-artifacts:1` is still `#!/bin/bash`. A full shebang sweep of the plugin shows it is the sole outlier among 14 production/eval scripts -- `edm-state:1`, `edm-lint-artifacts:1`, `edm-check-grants:1`, `edm-check-vocabulary:1`, `edm-check-skill-sync:1`, `edm-compare-eval:1`, `edm-init:1`, `edm-sync-canonical-sections:1`, `edm-validate-prefix:1`, `_edm-cli-lib.sh:1`, `_edm-lint-lib.sh:1`, `evals/run-eval.sh:1`, `evals/score-artifacts.sh:1`, `evals/tiering-matrix.sh:1` are all `#!/usr/bin/env bash`. No rationale comment was added at `:1` (the header block runs `:2-24` and never mentions the interpreter), and no divergence-sweep assertion for the shebang form exists in `bin/tests/`. Both consequences the finding named are unchanged: (1) on a host with no `/bin/bash`, `command -v` succeeds, exec fails with 126, and 126 is non-blocking under the hook contract at `hooks.json:86`, so commit-time artifact enforcement is silently off; (2) on macOS with Homebrew bash, this wrapper runs under system bash 3.2 while the `edm-lint-artifacts` it invokes at `:131` runs under env-resolved bash 5.x -- one commit-time check straddling two language versions.

### CA-500 -- P2, `plugins/edm/bin/edm-state:1062`, `:1697` -- **STILL OPEN (a); PARTIALLY FIXED (b)**
(a) Unchanged and re-derived. `edm-state:1062-1064`:
```
proj_root="${CLAUDE_PROJECT_DIR:-}"
[[ -n "$proj_root" && -d "$proj_root" ]] || proj_root="$(git rev-parse --show-toplevel 2>/dev/null)" || proj_root=""
```
`CLAUDE_PROJECT_DIR` is still accepted on the sole test that it names a directory, with no cross-check against the git toplevel, the initiative directory or `SRD_ROOT`. The value flows to `:1066`'s settings scan and thence to the `permission-ask` / `prose-only` enforcement tag stamped onto every gate approval. The function's own AC6 docstring at `:1047-1051` still states that a false `permission-ask` "is not harmless, since it would overstate the tier that actually enforced the approval" -- which is exactly what a one-token `CLAUDE_PROJECT_DIR=<dir with the two literal patterns> edm-state approve-gate ...` produces, while the env-prefixed form is itself one of the documented shapes the literal-prefix ask matcher misses (recorded at `:1029-1032`). Bypass that records itself as enforced.
(b) Improved but not as prescribed. `edm-state:1729` now reads `... not found in <project-root>/.claude/settings.local.json, <project-root>/.claude/settings.json, or ~/.claude/settings.json (CA-448: <project-root> is $CLAUDE_PROJECT_DIR when it names a directory, else the git toplevel, else the current directory ...)`. The bare-relative-path defect is gone, but the **resolved** root value is still not printed, so the tag remains unattributable to a specific directory after the fact. No smoke case asserting the enforcement tag against a scratch settings tree was found.

### CA-501 -- P2, `plugins/edm/bin/edm-lint-staged-artifacts` (file mode) + `hooks.json:86` -- **STILL OPEN**
The precondition is still pinned by nothing. Verified:
- A repository-wide grep for an executable-bit test (`[ -x`, `[[ -x`) across `plugins/edm/` returns **exactly one** hit: `plugins/edm/bin/tests/wave7-smoke.sh:4996`, and it is for `$TIMING_SH`.
- The T67 AC8 block at `wave7-smoke.sh:5122-5166` reads the delegate with `cat` (`:5134`) and does substring `check`s (`:5140-5165`) -- every one of which holds on a mode-0644 file. `wave7-smoke.sh:2546-2548` is the same shape.
- `.gitlab-ci.yml:114` (`bash -n "$f"`) and `:252` (`shellcheck ... "$f"`) pass the file as an argument, needing no execute bit.
- No test or CI job anywhere executes `edm-lint-staged-artifacts`; grep for the name returns only `hooks.json:86`, the script itself, three CLAUDE.md rows, and static substring assertions.
Consequence unchanged: `command -v` at `hooks.json:86` succeeds only for an executable file on PATH, so a mode-0644 file makes the guard fire, the hook exits 0, and a PreToolUse exit 0 is read as "proceed" -- indistinguishable from "commit is clean". Per the finding's own note, the claim is that nothing pins the bit, not that it is currently wrong; I could not observe the mode this round (no Bash).

### CA-481 -- P2 (L3/L7/L8/L5), `evals/tiering-matrix.sh:154`, `evals/score-artifacts.sh:756` -- **(a) STILL OPEN, (b) SUBSTANTIALLY FIXED, (c) STILL OPEN**
(a) `plugins/edm/evals/tiering-matrix.sh:154` is byte-unchanged: `trap 'rm -f "${tmp:-}"' RETURN EXIT INT TERM` -- HUP still absent, and the three real signals still fall through to cleanup-then-resume with no signal-shaped exit. It remains the last trap in the plugin omitting HUP, against the plugin-wide four-signal convention now stated at `edm-check-grants:124-130`.
(b) CA-449's fix landed at `score-artifacts.sh:758-763`: the second `mktemp` failure arm now removes `_CMP_TA` (`:759`), and the four-arm trap covers EXIT/INT/TERM/HUP with 130/143/129 exits (`:760-763`). The residual is now only a signal arriving in the window between `:758` and `:760` -- the shape the finding named, but with the die-path leak closed. I read this half as closed enough to drop from the open set; recorded as a NOTED residual below rather than re-filed.
(c) Unchanged: a recursive grep for `CA-446` or `CA-447` across `plugins/edm/bin/tests/` returns **zero** matches. There is still no cross-file sweep asserting that every cleanup trap in `bin/`, `bin/tests/` and `evals/` names HUP and exits after cleanup, which is precisely why (a) survived a sweep that named it in scope.

### CA-497 -- P2 (L7 + L8), `plugins/edm/bin/edm-lint-staged-artifacts:25` -- **STILL OPEN**
`:25` is still a bare `set -uo pipefail` with no rationale comment. The load-bearing statements the finding named are all still present and still non-zero on their ordinary path: `:41-42` (`[ -n ... ] && srd_root_explicit=1`), `:107` (`test -z "$staged" && exit 0`), `:110` (`[ "$root_for_awk" = "." ] && root_for_awk=""`), `:124` (`test -z "$prefixes" && exit 0`); load-bearing command substitutions at `:44`, `:106`, `:131-132`. Adding `-e` "for family consistency" still makes the script exit 1 at `:41` in the default (no override) case, and exit 1 is non-blocking under the hook contract -- silent fail-open for everyone. The CA-074-shaped comment is still not there.

### Previously-NOTED L8 items re-swept and still correct
- **CA-123** (fd choice): re-swept the whole scope for fd 9 and fd 10-19 use, plus `BASH_XTRACEFD` and `exec N<>`. Zero hits. `edm-state:1223` documents fd 200 as deliberately clear of 0-2 and of 9, and `:1293` is the only `200>` redirect. Holds.
- **CA-117** (`set -- $list` in `edm-check-grants:185`), **CA-087** (`$ARGUMENTS` charset filter), **CA-124** (`git add -A` at `run-eval.sh:288`, throwaway scratch repo), **CA-111** (placeholder digests / floating `bash:3.2` tag at `.gitlab-ci.yml:501`): all re-confirmed as previously dispositioned. Not re-filed.
- **CA-233** (vocabulary data files as bash source): `.gitlab-ci.yml:111` and `:249` carry the byte-identical `*.awk|*.txt) continue ;;` arm. Holds fixed.
- **CA-319** (npm pinning in the key-bearing job): `.gitlab-ci.yml:707` and `:770` both pin `@anthropic-ai/claude-code@2.1.226` with the refresh-procedure cross-reference and the documented decision to leave install scripts enabled. Holds fixed.

---

## Findings (L8: Security & Portability)

### L8-10-01 -- P2 (medium) -- `plugins/edm/evals/run-eval.sh:410`, `:450`
**Class**: privilege/capability boundary not actually in effect (malformed permission grant).
The whole allow-list is built as one space-separated string and passed as a **single** argv element:
```
CLAUDE_ALLOWED_TOOLS="Read Write Edit Glob Grep LS TodoWrite Task Bash(edm-state *) Bash(edm-init *) Bash(edm-validate-prefix *) Bash(jq *)"
...
--allowedTools "$CLAUDE_ALLOWED_TOOLS" \
```
The CLI's own reference documents `--allowedTools` as taking **space-separated separate arguments**, each individually quoted when the specifier contains a space -- its example is literally `"Bash(git log *)" "Bash(git diff *)" "Read"`. Four of this list's twelve entries contain an internal space (`Bash(edm-state *)`, `Bash(edm-init *)`, `Bash(edm-validate-prefix *)`, `Bash(jq *)`), so they cannot survive any space-split of the single collapsed argument: the consumer either splits and produces the malformed tokens `Bash(edm-state`, `*)`, ... or treats the whole 12-entry string as one tool name that matches nothing.
**Exploitation / failure scenario**: not an escalation -- `acceptEdits` covers file edits, not Bash, so the practical outcome is that every phase prompt's mandated `edm-state phase-complete` / `edm-init` call hits a permission prompt no headless run can answer, the phase burns its 2700s timeout, and the driver exits 4. The security-relevant half is that the documented containment posture (`evals/README.md:87-97`: "a tight `--allowedTools`/`--disallowedTools` pair ... exactly the containment property this harness needs") describes a boundary that is very likely not the boundary in force, and there is no assertion anywhere that would notice. Note `--disallowedTools` at `:411`/`:451` is unaffected: none of `WebFetch WebSearch KillShell BashOutput` contains a space, so a split recovers it correctly -- the defect is asymmetric and only the *allow* side is at risk.
**Concrete fix**: pass the grants as real separate arguments rather than one collapsed string -- keep the authoritative definition but expand it as an array (`CLAUDE_ALLOWED_TOOLS=(Read Write ... "Bash(edm-state *)" ...)`, then `--allowedTools "${CLAUDE_ALLOWED_TOOLS[@]}"`; bash 3.2 supports both), or switch to the comma-separated form if that is confirmed accepted. Then add one assertion (or a `--provision-only`-adjacent dry-run echo of the constructed argv) so the grant shape is pinned, and re-check `evals/README.md:87-97`'s containment claim against whatever shape lands. Flagged medium confidence and requiring one live check: the file's comments record several live observations against claude 2.1.220, and if a real multi-phase run ever completed then the CLI must be tolerating the collapsed form -- but no committed evidence in this tree establishes that, and `decisions.md` D23/CA-106 record that no wave-A baseline run exists.

### L8-10-02 -- P2 (high) -- `plugins/edm/bin/edm-lint-staged-artifacts:1` (re-confirmation of CA-499)
See the CA-499 verdict above. Hardcoded interpreter path on the one script all commit-time enforcement now routes through; sole outlier in a 14-file family; fail-open at exec status 126 under a hook contract that blocks only on exit 2. Fix: switch to `#!/usr/bin/env bash`, or, if bash 3.2 pinning was the intent, say so in a comment at `:1` and add the shebang form to the T61 AC11 divergence sweep so the choice is pinned rather than incidental.

### L8-10-03 -- P2 (medium) -- `plugins/edm/bin/edm-state:1062` (re-confirmation of CA-500(a))
See the CA-500 verdict above. `CLAUDE_PROJECT_DIR` trusted on a bare `-d` test, feeding the only auditable record that a human-approval control was armed. Fix: resolve both `CLAUDE_PROJECT_DIR` and the git toplevel physically and require equality with, or containment of, the toplevel; on disagreement prefer the toplevel and say so on stderr; then name the resolved root in the `:1729` diagnostic and add the prescribed smoke case.

### L8-10-04 -- P2 (high) -- `plugins/edm/bin/edm-lint-staged-artifacts` file mode + `plugins/edm/hooks/hooks.json:86` (re-confirmation of CA-501)
See the CA-501 verdict above. Fix: assert the executable bit in the T67 AC8 block (git tracks the mode, so this is a real regression guard) and loop it over every non-underscore-prefixed entry in `plugins/edm/bin/`; add the negative control (copy to a scratch dir at 0644, put it first on PATH, assert `command -v` fails); give the delegate at least one behavioural case (scratch repo, staged violating artifact, assert exit 2; clean, assert exit 0).

### L8-10-05 -- P2 (high) -- `plugins/edm/evals/tiering-matrix.sh:154` (re-confirmation of CA-481(a)+(c))
See the CA-481 verdict above. Fix: convert `:154` to the canonical four-arm form (EXIT cleanup-only, keeping RETURN on that arm; `INT` then `exit 130`; `TERM` then `exit 143`; `HUP` then `exit 129`), and land the cross-file sweep assertion CA-447 prescribed -- scan `bin/`, `bin/tests/` and `evals/` for cleanup trap lines, assert each names HUP and each real signal exits after cleanup, with a positive control -- since (c)'s absence is the reason (a) survived two sweeps that named it in scope.

### L8-10-06 -- P2 (high) -- `plugins/edm/bin/edm-lint-staged-artifacts:25` (re-confirmation of CA-497)
See the CA-497 verdict above. Fix: add the CA-074-shaped rationale comment above `:25` naming the five test-and-assignment statements, the three load-bearing command substitutions, and the fail-open direction, so the divergence is intentional on the page rather than incidental.

### L8-10-07 -- P2 (medium) -- `.gitlab-ci.yml:554`
**Class**: fail-open in a blocking gate via unchecked enumeration.
```
LIST_FILE="$(mktemp "${TMPDIR:-/tmp}/edm-state-validate.XXXXXX")"
edm-state list --paths > "$LIST_FILE"
while IFS= read -r dir; do ... done < "$LIST_FILE"
```
The job runs under `set -u` only (`:543`, deliberately -- no `-e`, POSIX-sh-safe by design). `edm-state list --paths` at `:554` has **no exit-status check** and there is **no floor on `COUNT`**. Any failure of the enumerator -- a `die` from a malformed state file, a lock timeout, a PATH mishap after `:550`, an unexpected `resolve` error -- leaves `LIST_FILE` empty, the loop iterates zero times, `FAIL` stays 0, and `:575` prints `state-validate: 0 initiative(s) checked` followed by `:580`'s `test:state-validate: OK`. A **blocking, `needs`-gated job that validated nothing reports green**, and the only signal is one line of log text nobody reads on a passing job. This is the same fail-open-with-a-diagnostic-nobody-sees shape CA-186 was escalated for. Secondary, minor: `LIST_FILE` has no trap (only the tail-position `rm -f` at `:574`), so an interrupt leaks it into the shared TMPDIR -- unlike the sibling `lint:hooks-shell` (`:293`) and `validate:manifest` (`:603`), which both arm `trap 'rm -rf "$TMP"' EXIT`.
**Concrete fix**: capture the enumerator's status (`edm-state list --paths > "$LIST_FILE" || { echo "test:state-validate: FAILED -- edm-state list --paths exited $?"; exit 1; }`), and add a minimum-count floor (`[ "$COUNT" -ge 1 ] || { echo "...FAILED -- zero initiatives enumerated; the validator scanned nothing"; exit 1; }`) so an empty enumeration is loud rather than green. Arm `trap 'rm -f "$LIST_FILE"' EXIT` beside the `mktemp` to match both sibling jobs.

---

## Noted / Not Actionable

- `plugins/edm/evals/fixtures/tiny-svc/config/settings.json:5` -- `"billingApiKey": "FIXTURE-HARDCODED-SECRET-DO-NOT-USE"`. A deliberately planted, self-labelling fake credential inside the frozen eval fixture -- it is one of the ground-truth gaps the scorer's dimension 6 measures. Test/fixture context, false-alarm filter #1.
- `plugins/edm/evals/README.md:26`, `:36`, `plugins/edm/evals/baseline/README.md:36` -- `export ANTHROPIC_API_KEY=sk-...` in operator documentation. Placeholder, not a real value.
- `plugins/edm/CLAUDE.md:391`, `:399` -- `/Users/darryl.porter/projects/caveman` and `.../ponytail` absolute developer paths. These appear only in prose recording *how a licence check was performed once* (provenance of a past manual inspection), not in any code path, and nothing resolves them at runtime. Documentation of a historical act, not a portability defect. (A tidiness argument exists for genericizing them; that is L6's axis, not L8's.)
- `plugins/edm/evals/score-artifacts.sh:758-760` -- the one-`mktemp` window from CA-481(b). CA-449's fix closed the die-path leak (`:759` removes `_CMP_TA`) and armed the full four-signal trap (`:760-763`); the surviving exposure is a signal delivered inside two adjacent assignments. Not worth a separate entry; folded into the CA-481 verdict.
- `plugins/edm/evals/score-artifacts.sh:404`, `:410`, `:432` -- `prefix` is interpolated raw into two `grep -E` patterns, but it is extracted at `:404` through `grep -oE '^#### [A-Za-z][A-Za-z0-9]*-[0-9]+'` and stripped to an alphanumeric token, so no metacharacter can reach the pattern. CA-088's sibling case at `:487-495` carries an explicit digit-only `case` guard. Both safe.
- `plugins/edm/evals/score-artifacts.sh:627-631` -- the CA-151 tracked-fixture write guard is present and matches any `*/fixtures/*` component. Holds.
- `plugins/edm/monitors/monitors.json:4` -- `"command": "edm-state watch-impl"` is a bare PATH-resolved invocation with no arguments and no interpolation. No injection surface.
- `plugins/edm/hooks/hooks.json` -- all nine `command` hooks re-read this round. The five `UserPromptExpansion` bodies (`:19`, `:32`, `:45`, `:58`, `:71`) are byte-identical apart from the gate name, apply the `''|*[!A-Za-z0-9_-]*` charset filter to the awk-extracted prefix before it reaches `edm-state`, and now block only on gate-check's dedicated status 3 (`ec=$?; if [ "$ec" -eq 3 ]; then exit 2; fi; exit 0`) -- CA-298's whole class stays closed, and the prompt bodies at `:23`/`:36`/`:49`/`:62`/`:75` agree with the code in writing. No `eval`, no unquoted expansion, no fd use.
- `plugins/edm/bin/*` -- no `eval` of external data anywhere in the scope. The single `eval` in the tree (`_restore_trap`, operating on `trap -p`'s own output) is already dispositioned under CA-376. No `sudo`, no `chmod`, no `umask`, no `curl`/`wget` in any blocking job body.
- Nine of the ten PATH-exposed `bin/` scripts carry the full `set -euo pipefail` with a documented rationale where they diverge; the tenth is CA-497 above. `run-eval.sh:60-66`, `score-artifacts.sh:125-131`, `tiering-matrix.sh` and `bin/tests/run-all.sh` each carry the CA-074 note.
- CA-130 reproduces for a **tenth** consecutive round: `Write` was again absent from this lens's delivered runtime tool set despite the frontmatter grant, so neither `lens-L8.md` nor `lens-L8.jsonl` could be written by the lens and both halves are transcribed by the launching agent. Host-side, already filed; do not re-file. Note also that the delivered agent definition for this run did not surface a `## JSONL Line Format` section, so the prompt-supplied fallback schema (D22/CA-130) is the one used below.
