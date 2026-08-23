I lack both Write and Bash this round (the CA-130 class, ninth consecutive round), so both halves follow inline. Git-range verification was done by reading HEAD state plus the in-file CA-NNN remediation comments and the ledger, not by running `git log/diff`.

## Findings (L8: Security & Portability)

### P1-1 -- `.gitlab-ci.yml:301` -- CA-437's fix introduced the file's only non-POSIX construct into a blocking job

`lint:hooks-shell` now iterates the NUL-delimited extraction with:

```sh
while IFS= read -r -d '' cmd; do
```

`read -d` is a bashism with no POSIX equivalent. This file states the opposing constraint three times, once inside this very job's own header comment:

- `.gitlab-ci.yml:274-276` (lint:hooks-shell) -- "`bash -n <(cmd)` process substitution needs bash itself as the invoking shell, which is not guaranteed for the runner's script stage (see the POSIX-sh-safe notes elsewhere in this file)"
- `.gitlab-ci.yml:517-519` -- "POSIX /bin/sh -safe on purpose ... the runner's shell-selection probe for this image runs before `apk add bash` in before_script has installed anything, so the script stage itself may still execute under plain sh"
- `.gitlab-ci.yml:566-568` -- same, for `validate:manifest`

A sweep for `[[`, `local`, `<<<`, `mapfile`, `declare`, array syntax and `read -d` across every `script:` body in the file returns exactly one hit: line 301. So the job that was added to guard the plugin's most privileged shell is itself the only script in the pipeline that violates the pipeline's own interpreter contract, and it is `needs: []` with no `allow_failure` -- blocking.

**Exploitation / failure scenario.** On a runner that resolves `sh` (the documented condition -- `alpine:3.20` ships no bash, and `before_script` runs inside the already-selected shell), `read` rejects `-d`, the loop body never executes, `COUNT` stays 0, and control reaches the CA-437 cross-check at `:320`, which fails the job with `checked 0 command(s) but hooks.json declares 9 (extraction/splitting regression, CA-437)`. That is fail-closed but actively misdiagnosing: the message points a maintainer at hooks.json and at jq extraction, when the cause is the interpreter. This lands on first pipeline enablement, alongside CA-111's placeholder digests, on the one job with no prior green run.

**Fix** (drops the NUL staging file entirely and keeps the count cross-check):

```sh
EXPECTED_COUNT="$(jq '[.hooks|to_entries[]|.value[]|.hooks[]|select(.type=="command")]|length' plugins/edm/hooks/hooks.json)"
IDX=0
while [ "$IDX" -lt "$EXPECTED_COUNT" ]; do
  jq -r --argjson n "$IDX" '[.hooks|to_entries[]|.value[]|.hooks[]|select(.type=="command")][$n].command' \
    plugins/edm/hooks/hooks.json > "${TMP}/hook-${IDX}.sh"
  ...
  IDX=$((IDX + 1)); COUNT=$((COUNT + 1))
done
```

Indexing by jq is immune to every delimiter question (no newline split, no NUL read), is pure POSIX, and makes `COUNT == EXPECTED_COUNT` structural rather than a post-hoc check. Downgrade to P2 only if the team confirms its runner fleet always resolves bash for the script stage -- in which case the three POSIX-sh-safe comments should be deleted as false, not left contradicting the code.

---

### P2-1 -- `plugins/edm/bin/edm-lint-staged-artifacts:1` -- the one script the git-commit hook depends on is the only one in the plugin with a hardcoded interpreter path

#!/bin/bash

Every other production and eval script uses `#!/usr/bin/env bash` -- 12 of 12: `edm-state`, `edm-lint-artifacts`, `edm-check-grants`, `edm-check-vocabulary`, `edm-check-skill-sync`, `edm-compare-eval`, `edm-init`, `edm-sync-canonical-sections`, `edm-validate-prefix`, `_edm-cli-lib.sh`, `_edm-lint-lib.sh`, plus all three `evals/*.sh`. The sole `#!/bin/bash` outlier is the brand-new file that `hooks.json:86` now routes all commit-time enforcement through.

Two concrete consequences:

1. **Fail-open on a host with no `/bin/bash`** (NixOS, distroless/minimal containers, some hardened images). `command -v edm-lint-staged-artifacts` succeeds (the file is on PATH and executable), the hook invokes it, exec fails with status 126 and a `bad interpreter` line. The hook's contract blocks only on exit 2, so 126 is non-blocking -- the commit proceeds and artifact enforcement is off. This is the CA-186 fail-open class re-entering through the interpreter rather than through `srd_root`.
2. **Split bash versions inside one check on macOS** -- the project's stated primary development platform (`bin/edm-state:653`). With Homebrew bash installed, the wrapper runs under `/bin/bash` 3.2 while the `edm-lint-artifacts` it calls at `:131` runs under `env bash` 5.x. One commit-time check straddles two language versions with nothing recording that.

**Fix:** change to `#!/usr/bin/env bash` for family consistency; or, if pinning bash 3.2 was the intent, say so in a comment at `:1` and add the shebang form to the T61 AC11 divergence sweep at `wave7-smoke.sh:1137` so the choice is pinned rather than incidental.

---

### P2-2 -- `plugins/edm/bin/edm-state:1062` -- `CLAUDE_PROJECT_DIR` is trusted unvalidated (INTRODUCED BY THE CA-448 FIX)

```bash
proj_root="${CLAUDE_PROJECT_DIR:-}"
[[ -n "$proj_root" && -d "$proj_root" ]] || proj_root="$(git rev-parse --show-toplevel 2>/dev/null)" || proj_root=""
[[ -n "$proj_root" ]] || proj_root="."
```

The resolution order is correct and closes CA-448's stated defect. The new exposure is that `CLAUDE_PROJECT_DIR` is accepted on the sole test that it is a directory -- nothing checks it against the git toplevel, the initiative directory, or `SRD_ROOT`.

**Exploitation scenario.** `check_permission_rules` produces the `enforcement` tag stamped onto every gate approval (`:2173`, `:2306`, `:2317`, `:2338`) -- the plugin's only auditable record that a human-approval control was armed. An invocation of the form

CLAUDE_PROJECT_DIR=/tmp/x edm-state approve-gate <PREFIX> <gate>

does two things at once: the env-prefixed form is one of the documented shapes that does **not** match the `Bash(edm-state approve-gate*)` literal-prefix ask matcher (README.md "Matcher limitation", echoed at `edm-state:1029-1032`), so no permission prompt fires; and it simultaneously points the scan at `/tmp/x/.claude/settings.json`, which need only contain the two literal patterns to stamp the approval `permission-ask`. The result is a bypass that records itself as enforced. This is precisely the direction the function's own AC6 docstring at `:1047-1051` forbids: *"a false 'present' (permission-ask) is not [harmless], since it would overstate the tier that actually enforced the approval."* Pre-CA-448 the equivalent needed a `cd ... &&` compound (also a documented bypass shape); the fix reduced it to a one-token env prefix and moved it onto a host-supplied variable.

**Fix:** accept `CLAUDE_PROJECT_DIR` only when it agrees with the repository -- resolve both with `cd ... && pwd -P` and require equality with, or containment of, `git rev-parse --show-toplevel`; on disagreement prefer the toplevel and say so. Then land the half of CA-448's own prescription that did not ship: name the resolved root. `PERM_RULES_MISSING` at `:1697` still emits bare relative paths (`.claude/settings.local.json, .claude/settings.json, or ~/.claude/settings.json`), so a `prose-only` tag remains unattributable to any particular tree.

---

### P2-3 -- `plugins/edm/bin/edm-lint-staged-artifacts` (whole file) -- the CA-436 extraction made commit-time enforcement depend on a file mode nothing pins

Before the extraction, the enforcement body lived inline in `hooks.json:86`; it could not fail to be present. It is now a PATH-resolved script guarded by `command -v edm-lint-staged-artifacts >/dev/null 2>&1 || exit 0`, which returns non-zero -- and silently disables all commit-time artifact lint with no output on any channel -- whenever the file is not executable.

Nothing anywhere asserts that. A sweep of `bin/tests/` for `-x`, `executable`, `100755` and `core.fileMode` returns exactly one hit, `wave7-smoke.sh:4570`, and it covers only `bin/tests/timing.sh`. `.gitlab-ci.yml` has no executable-bit check at all. The suite's own CA-436 coverage (`wave7-smoke.sh:2543-2546`, `:4704-4710`) asserts only that the file *exists* and that its text contains the right strings -- both of which hold on a mode-0644 file.

This is realistic, not theoretical: a file created by an agent's Write tool, a patch applied with `git apply` on a `core.fileMode=false` checkout, or an archive export can all land the file without `+x`, and the failure is indistinguishable from "no violations found."

**Fix:** one loop in `wave7-smoke.sh` asserting `[[ -x ]]` for every non-`_`-prefixed entry in `plugins/edm/bin/`, plus a positive control -- copy the script to a scratch dir at mode 0644, put that dir first on PATH, and assert `command -v` fails -- so the silent-degradation path itself is exercised rather than assumed.

---

## Post-remediation verification (round 8 -> HEAD)

| Prior finding | Verdict | Evidence |
|---|---|---|
| **CA-413** (lexical relativization defeated by symlinked repo) | **VERIFIED FIXED** | `edm-lint-staged-artifacts:51-66`: both sides normalized with `cd ... && pwd -P` before the `case` compare, with a documented fallback to the original string when `cd` fails. The `A && B \|\| C` at `:58` is correct in all four branches (a failing command substitution propagates non-zero, so the `\|\|` arm restores `$repo_root`). |
| **CA-414** (interpreter-dependent staged-path parsing) | **PARTIALLY FIXED** -- see below | |
| **CA-436** (blocking hooks-shell job unsatisfiable by a JSON-string hook) | **VERIFIED FIXED** | Body extracted; `hooks.json:86` is now two fully-quoted statements with no SC2086 shape. The intentional word-split at `edm-lint-staged-artifacts:129` carries a real directive at `:127-128` -- and the intervening comment line does not break it (ShellCheck's `allspacing` consumes plain comments between an annotation and its command). |
| **CA-437** (newline-split extraction) | **FIXED, new defect introduced** | NUL extraction + count cross-check landed at `.gitlab-ci.yml:298-299`, `:320-323`. See P1-1. |
| **CA-438** (fd-200 rationale unpinned) | **VERIFIED FIXED** | `wave7-smoke.sh:5087-5100` pins `BASH_XTRACEFD`, `Do not lower this`, and adds a `check_absent`-style tripwire for any sub-100 fd redirect onto `$lockfile`. Independent full-scope fd sweep this round: `edm-state:1287`'s `200>` remains the only numeric fd anywhere in `bin/`, `evals/` or `hooks/` -- no fd 9, no 10--19. |
| **CA-443 / CA-444** (eval knob validation) | **VERIFIED FIXED** | `run-eval.sh:192-195` clamps `EDM_EVAL_KEEP_RUNS=0` to 1 with a named warning; `:412-417` refuses a non-numeric or zero `EDM_EVAL_PHASE_TIMEOUT_SECONDS` with exit 2, validated beside its default per the CA-160 rule, and documented at `:34-35`. |
| **CA-447** (trap signal-set divergence) | **PARTIALLY FIXED** | The six enumerated sites all now carry `EXIT INT TERM HUP` with signal-shaped exits, and the first-stage trap between the two mktemps landed at `edm-lint-artifacts:137`. The prescribed **cross-file sweep assertion did not land** (no `CA-447` hit anywhere in `bin/tests/`), and two sites it would have caught survive: `evals/tiering-matrix.sh:154` is the last `RETURN EXIT INT TERM` trap in the plugin (no HUP), and `evals/score-artifacts.sh:756-757` has an untrapped one-mktemp window -- the exact gap `edm-lint-artifacts:133` just closed. |
| **CA-448** (cwd-relative settings scan) | **PARTIALLY FIXED** | Project-root anchoring landed (`edm-state:1056-1064`). The prescription's second half -- name the resolved root in the diagnostic -- did not; `:1697` still emits bare relative paths. New trust residual filed as P2-2. |
| **CA-449** (bare `mktemp` / staging-file traps) | **VERIFIED FIXED** | `score-artifacts.sh:756-761` uses `${TMPDIR:-/tmp}/...XXXXXX` templates with checked creation and a four-signal split trap; the T61 divergence tripwire at `wave7-smoke.sh:1137` is widened to `mktemp( -d)?\)` so the bare *file* form is now caught too. |

**CA-414 detail (why it is not closed).** The `printf '%s\n'`-for-`echo` half is genuinely closed at `:114` and `:134`/`:138`, and closes the ash-expands-backslashes hazard. The `core.quotePath=false` half rests on a false premise. The code comment at `:101-105` claims the flag makes "a path carrying non-ASCII **or backslash** bytes arrive raw instead of C-quoted." Git's documentation says the opposite: `core.quotePath=false` suppresses quoting only for bytes above 0x80, and *"double quote, backslash and control characters are always quoted without `-z` regardless of the setting of this variable."* So a staged path containing `"`, `\`, or any control byte still arrives as a C-quoted, backslash-escaped string beginning with `"`. The awk root test at `:118` (`substr($0,1,rl) == root "/"`) then fails on the leading quote and `next`s the record; in the `srd_root="."` branch the `grep -E '^[A-Za-z0-9_-]+$'` filter at `:123` drops it instead. Either way, if such a file is the only staged file for an initiative, `prefixes` is empty, `:124` exits 0, and the initiative is not linted with no diagnostic on any channel. **Fix:** `git -c core.quotePath=false diff --cached --name-only -z` (the `-z` is what actually disables the quoting) read NUL-delimited, and correct the comment so the next reader does not inherit the wrong model.

---

## Noted / Not Actionable

- **CA-130 (tool set)** -- Write and Bash again absent from this lens's delivered runtime set; carries a do-not-re-file disposition. Recorded only because it is the reason this round has no executed verification and no written files.
- **CA-111** -- `alpine:3.20` / `node:20-alpine` digests and the floating `bash:3.2` tag are still self-declared placeholders, authorized in the file header. Unchanged; do not re-file.
- **CA-123 / CA-376 (fd sweep)** -- re-swept full scope. `flock` on fd 200 remains the only numeric descriptor in `bin/`, `evals/` and `hooks/`, and the rationale is now both correct and pinned. Clean.
- **CA-381** -- the five `UserPromptExpansion` `$ARGUMENTS` hooks are unchanged and carry an explicit round-8 NOTED disposition recording that both candidate fixes were empirically tested and both broke gate enforcement. Not re-attempted.
- **CA-086 / CA-124 / round-8 `argv` note** -- `run-eval.sh:372-394` still describes the `acceptEdits` + prefix-matcher posture accurately as a bounded, non-airtight tradeoff, with `bypassPermissions` deliberately unused; `git add -A` at `:283` is a throwaway scratch repo. Unchanged.
- **`eval:nightly` artifact retention** (`.gitlab-ci.yml:776-780`, filed round 8 at P2/low, never promoted to a CA) -- re-examined and downgraded to noted. The uploaded tree contains only frozen `tiny-svc` fixture artifacts, model outputs and `raw/*.stderr.log`; `ANTHROPIC_API_KEY` is never echoed (`:344` names the variable, not its value), never written to `run.json`, and GitLab masks the protected variable in job output. Compensating control present.
- **`set -uo pipefail` (no `-e`) at `edm-lint-staged-artifacts:25`** -- `-e` is provably unusable here, not an oversight: `:44` and `:106` capture git output whose non-zero status is load-bearing, and `:131-132` depends on `out=$(...)` surviving so `code=$?` can be read. This matches `run-eval.sh`'s documented CA-074 exception. The only gap is that, unlike `run-eval.sh:60-65`, no comment records the reason -- cosmetic, one line.
- **`srd_root` path normalization** (`:47`, `:77-90`) -- re-derived character by character against `.`, `./`, `././SRD`, `SRD/`, `SRD/.`, `..`, `../x`, `SRD/..`, `a/../b`, `""` and `..foo`. Every traversal shape hits a named `exit 1`; every benign shape normalizes. Correct.
- **Locale-dependent bracket ranges** in `grep -E '^[A-Za-z0-9_-]+$'` (`:123`) -- under a UTF-8 collation a range can admit exotic letters, but no whitespace or glob metacharacter is a letter or digit in any locale, so the compensating argument in the SC2086 directive at `:127-128` holds and the word-split at `:129` stays safe.
- **Hardcoded paths** -- a full sweep of every executable file under `plugins/edm/` for `/Users/`, `/home/`, `/opt/`, `/usr/local/`, `/var/local/` and the developer's username returns zero hits. The only developer-machine paths in the plugin are in `CLAUDE.md`'s licence-provenance record, already noted in round 8.
- **Bare `mktemp -d` in `.gitlab-ci.yml:290`, `:572`** -- the macOS `_CS_DARWIN_USER_TEMP_DIR` hazard that motivates the `bin/`/`evals/` tripwire does not apply to Linux-only CI runners; the T61 sweep correctly does not cover this file.
- **Categories not applicable:** no systemd units, no init-managed daemon, no container image built by this repo (confinement surface audited instead as P1-1 / P2-3 and the hook exit-code contract); no database or SQL string building; no HTTP client taking a caller-supplied URL (the only network calls are `claude -p` and a version-pinned `npm install -g`, with `--ignore-scripts` correctly rejected and the reason recorded at `.gitlab-ci.yml:672-675`); no secret written to disk by any script.

Sources for the `core.quotePath` behavior: [git-config documentation](https://git-scm.com/docs/git-config), [git-config(1) man page](https://linux.die.net/man/1/git-config)

