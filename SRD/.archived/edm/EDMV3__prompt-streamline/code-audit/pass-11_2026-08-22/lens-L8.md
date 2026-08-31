# Lens L8 -- Security & Portability (Round 11, full sweep)

Scope swept: `plugins/edm/bin/*` (shebang/`set`-flag/fd/eval/privilege sweeps across all entries;
`edm-lint-staged-artifacts` and `edm-state:1040-1130`, `:1795-1815` read in full),
`plugins/edm/bin/tests/*.sh` (targeted: CA-501/CA-481(c)/CA-499/CA-497 durability blocks,
shebang + `chmod` + `-x` + fd sweeps), `plugins/edm/hooks/hooks.json` (full, all nine hooks),
`plugins/edm/monitors/monitors.json`, `plugins/edm/evals/run-eval.sh` (auth/timeout/grant/budget
paths read in full), `evals/score-artifacts.sh` + `evals/tiering-matrix.sh` (targeted),
`.gitlab-ci.yml` (full for `lint:hooks-shell`, `test:state-validate`, `eval:nightly`, image
pinning), `plugins/edm/CLAUDE.md` (targeted).

Coverage caveat (report as unaudited, not clean): no Bash in the delivered tool set, so **no file
mode was observed** and **nothing was executed**. `plugins/edm/skills/**/SKILL.md`,
`plugins/edm/agents/*.md` and `plugins/edm/docs/**` were covered by targeted grep only
(injection / fd / hardcoded-path / secret patterns), not read end to end.

---

## Prior-round L8 ledger verdicts (explicit, with file:line evidence)

**All seven round-10 open findings are VERIFIED FIXED, six of them with durability assertions.**
This is the first round since round 2 with a clean prior-finding sweep.

### L8-10-01 / CA-532 -- `evals/run-eval.sh:410` -- **VERIFIED FIXED**
The collapsed single-argv grant string is gone. `:421-422` are now real bash arrays with each
space-bearing specifier individually quoted (`CLAUDE_ALLOWED_TOOLS=(Read Write ... "Bash(edm-state
*)" "Bash(edm-init *)" "Bash(edm-validate-prefix *)" "Bash(jq *)")`), and `:487-488` expand them as
`"${CLAUDE_ALLOWED_TOOLS[@]}"` / `"${CLAUDE_DISALLOWED_TOOLS[@]}"` -- twelve and four separate argv
elements, matching the CLI's documented space-separated-separate-arguments form. The rationale
comment at `:410-420` records the CLI reference, the four affected specifiers, the failure
direction, and the bash-3.2 array-support check. The documented containment posture in
`evals/README.md` now describes a boundary that can actually be in force. Close.

### L8-10-02 / CA-499 -- `bin/edm-lint-staged-artifacts:1` -- **VERIFIED FIXED**
`:1` is now `#!/usr/bin/env bash`. A fresh full-plugin shebang sweep shows **zero** `#!/bin/bash`
among all 14 production/eval scripts (the only remaining hits are ~15 heredoc-authored scratch
stubs inside `bin/tests/wave7-smoke.sh` -- test context). Pinned both directions at
`wave7-smoke.sh:5448-5451`: a positive `check` for `#!/usr/bin/env bash` **and** a `check_absent`
for `#!/bin/bash`, so the choice can no longer drift back silently. The fail-open-at-exec-126 path
under the `hooks.json:86` contract, and the bash-3.2-vs-5.x straddle on macOS, are both closed.

### L8-10-03 / CA-500(a)+(b) -- `bin/edm-state:1062` -- **VERIFIED FIXED**
The bare `-d` trust test is gone, replaced by a shared resolver at `:1075-1101` implementing
exactly the prescribed fix: both candidates resolved **physically** (`cd ... && pwd -P`, `:1082-1083`),
a `case` accepting `CLAUDE_PROJECT_DIR` only when it equals or is contained within the toplevel
(`:1084-1087`), and on disagreement a named-both-paths stderr warning plus a hard preference for
the toplevel (`:1089-1090`). Extracting it as one resolver also closes the divergence risk the
comment names: the scan and the diagnostic now read the same value by construction. (b) is closed
too -- `:1809` calls the same resolver and the `PERM_RULES_MISSING` diagnostic names the **resolved**
root, not just the algorithm. A dedicated smoke case exists (`wave6-smoke.sh:1559` tears down
`ca500_repo` / `ca500_attacker`). The self-recording bypass is gone.

### L8-10-04 / CA-501 -- `bin/edm-lint-staged-artifacts` file mode + `hooks.json:86` -- **VERIFIED FIXED**
All three prescribed pieces landed at `wave7-smoke.sh`:
- `:5470-5482` -- the executable bit is asserted for **every** non-underscore-prefixed
  `plugins/edm/bin/` entry in a loop, with the underscore convention (sourced library, never
  PATH-invoked) stated as the exclusion rule. Git tracks the mode, so this is a real regression guard.
- `:5495-5541` -- the negative control the finding asked for: a scratch bin, a mode-0644 copy
  (`chmod 0644` at `:5514`) placed first on PATH, the real hook command extracted from
  `hooks.json`, and an assertion that it **fails open (not exit 2)** against the unexecutable
  delegate. The comment at `:5486-5491` records the live correction that `command -v` does resolve
  a non-executable file, so the mechanism is documented as measured rather than assumed.
- `:7271-7308` -- the missing behavioural case: the real hook exits 0 on an otherwise-clean staged
  commit, complementing the pre-existing staged-violation-exits-2 cases.

### L8-10-05 / CA-481(a)+(c) -- `evals/tiering-matrix.sh:154` -- **VERIFIED FIXED**
(a) `:158-161` is now the canonical four-arm split: `trap 'rm -f "${tmp:-}"' RETURN EXIT`, then
`INT`/`TERM`/`HUP` each cleaning up and exiting 130/143/129. The `"${tmp:-}"` guard for the
post-return EXIT firing survives, and `:154-157` explains the conversion. The last HUP-omitting
trap in the plugin is gone.
(c) The cross-file durability pin CA-447 asked for twice finally exists, at
`wave7-smoke.sh:9625-9698`: a sweep asserting (i) no cleanup trap combines EXIT with a real signal
in one statement (the CA-446 cleanup-then-resume shape) and (ii) every file installing an EXIT
cleanup trap also installs a HUP trap -- each with its own **positive control** on a scratch file
(`:9684-9698`). This is the assertion whose absence let (a) survive two sweeps that named it.

### L8-10-06 / CA-497 -- `bin/edm-lint-staged-artifacts:25` -- **VERIFIED FIXED**
`:43` is still `set -uo pipefail`, correctly, and now carries the CA-074-shaped rationale block at
`:33-42`: it names the five ordinary-path non-zero statements, the three load-bearing command
substitutions, the exact fail-open consequence under the hook's exit-code contract, and ends with
"Do not 'fix' this to match the other scripts." Pinned at `wave7-smoke.sh:5457-5459`, which asserts
both that the `CA-497` marker survives at the site and that `-e` is still absent.

### L8-10-07 / CA-493 -- `.gitlab-ci.yml:554` -- **VERIFIED FIXED (one inert residual)**
Both halves landed. `:570-576` captures the enumerator's own status on the same statement
(`LIST_EC=0; edm-state list --paths > "$LIST_FILE" || LIST_EC=$?`) and fails the job naming the
exit code; `:598-604` adds the zero-count floor with a message that says the validator scanned
nothing. The blocking-job-reports-green-having-validated-nothing path is closed in both directions
(non-zero status **and** empty-but-successful enumeration). Residual, recorded as NOTED below, not
re-filed: `LIST_FILE` still has no `trap`, only tail-position `rm -f` at `:574`/`:596`, unlike the
sibling `lint:hooks-shell` (`:293`) and `validate:manifest` (`:603`).

### CA-518 (adjacent, L8-relevant) -- `.gitlab-ci.yml:312` -- **VERIFIED FIXED**
`:322-333` adds the `WELLFORMED` cross-check: the same select-chain narrowed to entries whose
`.command` is a non-empty string, compared against `EXPECTED_COUNT`, failing the job by name. A
declared-but-unwired hook (null/empty/non-string `.command`) can no longer pass `bash -n` and
`shellcheck` on jq's empty rendering while doing nothing at runtime.

### Previously-NOTED L8 items re-swept and still correct
- **CA-123** (fd choice): fresh sweep of `bin/`, `bin/tests/`, `evals/` and `.gitlab-ci.yml` for
  fd 9, fd 10-19, `BASH_XTRACEFD` and `exec N<>` returns **zero** hits. fd 200 remains the only
  non-standard descriptor, still documented as deliberately clear of 0-2 and of 9, and is now
  additionally pinned by a `wave7-smoke.sh:5891`-anchored assertion naming both the
  `BASH_XTRACEFD` convention and the 10+ reserved band. Holds.
- **CA-381** (`$ARGUMENTS` textual-substitution question, ledger `NOTED`): re-read all five
  `UserPromptExpansion` command hooks. The `''|*[!A-Za-z0-9_-]*` charset filter is present at
  `hooks.json:19`, `:32`, `:45`, `:58`, `:71`; the block-only-on-status-3 contract holds
  (`ec=$?; if [ "$ec" -eq 3 ]; then exit 2; fi; exit 0`); the paired prompt bodies agree in
  writing. The `-n`-as-`echo`-option edge case fails in the safe direction (empty prefix -> the
  `''` arm -> exit 2). Dispositioned; not re-filed.
- **CA-117**, **CA-087**, **CA-124**, **CA-111**: re-confirmed. CA-111 specifically: `bash:3.2` at
  `.gitlab-ci.yml:513` is still an unpinned floating tag, still carrying the documented,
  explicitly-authorized exception note at `:504-512`; the two `@sha256:` digests at `:64`/`:68`
  are unchanged placeholders. Documented and authorized, not re-filed.
- **CA-233**, **CA-319**: both hold fixed (`*.awk|*.txt) continue ;;` at `:111`/`:249`; the pinned
  `@anthropic-ai/claude-code@2.1.226` at `:799` in the credential-bearing job).
- No `eval` of external data anywhere in `bin/` or `evals/`. The only `eval` sites are
  `bin/tests/_harness.sh:155-158` (operating on `trap -p`'s own output, CA-376) and
  `bin/tests/timing.sh:211` (a bash-3.2 array-name indirection over a literal). No `sudo`, no
  `umask`, no `chmod` outside `bin/tests/`, no `curl`/`wget` in any blocking job body.

---

## Findings (L8: Security & Portability)

### L8-11-01 -- P2 (medium) -- `plugins/edm/evals/run-eval.sh:460`
**Class**: required-input validation missing on a spend-control knob (fail-open on a cost boundary
in the one credential-bearing job); the CA-160 "validate beside the default" rule applied to the
sibling knob and explicitly declined here.

```
PHASE_MAX_BUDGET_USD="${EDM_EVAL_MAX_BUDGET_USD:-15}"
```

`:460` is the only `EDM_EVAL_*` numeric knob in this driver with **no validation at all**, and the
value flows unchecked to `claude -p --max-budget-usd "$PHASE_MAX_BUDGET_USD"` at `:492`. The
contrast is inside the same file, twenty-five lines up: `EDM_EVAL_PHASE_TIMEOUT_SECONDS` at
`:423-433` is validated with an explicit `case` that exits 2 on anything that is not a positive
whole number, precisely because "the driver runs without `set -e`, so an unvalidated value silently
disabled the phase timeout instead of aborting" (CA-444). `CI_JOB_TIMEOUT` at `:434-459` gets the
same treatment. `EDM_EVAL_KEEP_RUNS` is validated and clamped (CA-443). The budget knob -- the one
that bounds *money* rather than time -- is the sole exception, and the omission is **documented as
a known state rather than fixed**: `plugins/edm/CLAUDE.md:1033` reads "per-run spend ceiling,
default `15`. **Not** validated -- unlike the timeout knob above, a non-numeric value here is still
taken as-is."

**Exploitation / failure scenario**: not an escalation -- an operator or CI variable typo, a
shell-mangled value, or a locale-decimal-comma (`15,00`) reaches the CLI unchecked in
`eval:nightly`, the one job holding `ANTHROPIC_API_KEY` (`.gitlab-ci.yml:783`), running
`--permission-mode acceptEdits` with no human in the loop across three phases. The direction of
failure is undetermined and that is the finding: either the CLI rejects the flag (loud, acceptable)
or it ignores an unparseable value and the per-phase ceiling is simply not applied, leaving three
unbounded-spend phases whose only remaining bound is the 2700 s wall clock. Nothing in this tree
establishes which, and nothing asserts the shape. Note `${...:-15}` does cover the empty case, so
the exposure is non-numeric/negative/multi-dot values only.

**Concrete fix**: apply the CA-444 pattern verbatim at `:460` -- a `case
"$PHASE_MAX_BUDGET_USD" in ''|*[!0-9.]*|*.*.*|.) echo "run-eval.sh: EDM_EVAL_MAX_BUDGET_USD must be
a positive decimal number (got '<value>')" >&2; exit 2 ;; esac`, sited beside the default the way
the timeout's is, and add one smoke case asserting exit 2 on a non-numeric value. Separately (L6's
axis, cross-referenced not filed here): `run-eval.sh:36` and `:406` call this a **per-phase**
ceiling while `CLAUDE.md:1033` calls it a **per-run** ceiling -- for a spend control those are a
3x difference in what an operator thinks they capped.

### L8-11-02 -- P2 (medium) -- `plugins/edm/evals/run-eval.sh:311`, `:316-318`, `:260-263`
**Class**: incomplete process containment on the timeout and interrupt paths -- the driver signals
a single PID, never the process group, so credential-bearing grandchildren outlive the boundary the
driver asserts.

```
"$@" >"$outfile" 2>"$errfile" &
CURRENT_CHILD_PID=$!
...
kill -TERM "$pid" 2>/dev/null ; sleep 2 ; kill -KILL "$pid" 2>/dev/null
```

`run_with_timeout` (`:309-330`) and `cleanup` (`:256-264`) both signal exactly `$CURRENT_CHILD_PID`
-- the `claude` process itself. Neither ever signals the group. The direct-child leak *was*
analysed and closed: the comment at `:465-470` explains that `invoke_claude` deliberately avoids a
`(...)` subshell so `CURRENT_CHILD_PID` stays visible to the top-level trap. The **grandchild** case
is addressed nowhere. `claude -p` runs here with `Bash(edm-state *)`, `Bash(edm-init *)`,
`Bash(edm-validate-prefix *)` and `Bash(jq *)` granted (`:421`), so at any instant it may have a
Bash-tool child of its own; those children inherit the driver's entire environment, including
`ANTHROPIC_API_KEY`.

**Exploitation / failure scenario**: on the 124-timeout path or any INT/TERM/HUP, `claude` dies and
every subprocess it had open is reparented and keeps running -- with the eval's grants and the API
key still in its environment, past the containment boundary `evals/README.md` claims. `cleanup`
then `rm -rf`s `$SCRATCH_DIR` (`:265-267`) out from under whatever is still writing into it, so the
scratch tree can be deleted mid-write by a process the driver no longer knows about. On a CI runner
the container teardown masks this; the documented developer path is `bash
plugins/edm/evals/run-eval.sh` on a workstation, where the orphan persists for the rest of the
login session. This is the only place in the plugin where a process holding a live credential can
survive its supervisor.

**Concrete fix**: make the backgrounded invocation lead its own process group and signal the group,
with the current single-PID kill retained as the fallback. Bash-3.2-safe shape: `set -m` around the
`&` at `:311` (restore with `set +m` immediately after capturing `$!`), then
`kill -TERM -"$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null` at `:316`, the same for `-KILL` at
`:318`, and the same pair in `cleanup` at `:261`/`:263`. Add one smoke case: push a
`bash -c 'sleep 300 & wait'` stub through `run_with_timeout` with a 1 s bound, capture the
grandchild's PID from the stub, and assert `kill -0` on it fails after the timeout returns 124.

### L8-11-03 -- P2 (low) -- `.gitlab-ci.yml:864-868`
**Class**: unredacted artifact publication from a credential-bearing job (re-raise of a round-8 L8
item that was filed with `id:null` and never carried into the round-9/10 open sets, so it has no
ledger disposition either way).

```
  artifacts:
    when: always
    expire_in: 30 days
    paths:
      - plugins/edm/evals/runs/
```

`eval:nightly` is, by its own comment at `:794-797`, "the one job in the pipeline holding
`ANTHROPIC_API_KEY`". It publishes the *entire* `runs/` tree, `when: always` (so failed and partial
runs upload too), for 30 days, with no `exclude:` and no redaction step. What lands there includes
`raw/<phase>.stderr.log` and `raw/<phase>.json` for every phase (`run-eval.sh:480`) -- raw stderr
and the full JSON result of each `claude -p` invocation. GitLab's variable masking applies to **job
logs only**; artifacts are never masked. So any diagnostic that echoes the environment (a CLI stack
trace including argv/env, a Node crash dump, a future `set -x` added for debugging) is published to
everyone who can read the pipeline's artifacts, for a month, with no masking layer between.

**Exploitation / failure scenario**: not a demonstrated leak, and I want that boundary explicit --
I traced every write into the run directory (`:157`, `:162`, `:480`, `:725`) and found **no site
that writes the key to a file today**, and the fixture content is synthetic. This is an
exposure-surface finding: the redaction control that would contain a future stderr regression does
not exist, in the one job where it matters, and `when: always` guarantees the failure paths (the
ones most likely to dump diagnostics) are the ones that upload.

**Concrete fix**: narrow `paths:` to what the pipeline actually consumes downstream -- `run.json`
and `scores.json` -- and either drop `raw/` or add
`exclude: ["plugins/edm/evals/runs/*/raw/*.stderr.log"]`. If the raw stderr is genuinely wanted for
triage, add a redaction pass before the upload step (`sed`-scrub `sk-ant-[A-Za-z0-9_-]*` and the
literal `$ANTHROPIC_API_KEY` value across `runs/*/raw/`) and say so in the job comment. Flagged low
confidence deliberately: the exposure is structural, not observed.

---

## Noted / Not Actionable

- `.gitlab-ci.yml:565` -- CA-493 residual: `LIST_FILE` is created by `mktemp` with no `trap`, only
  tail-position `rm -f` at `:574`/`:596`, so an interrupt leaks it -- unlike the sibling
  `lint:hooks-shell` (`trap 'rm -rf "$TMP"' EXIT` at `:293`) and `validate:manifest` (`:603`). The
  primary fail-open is fixed; the leak is inert in an ephemeral CI container with a job-scoped
  TMPDIR. Two-line fix if the sibling consistency is wanted; not worth a finding.
- `plugins/edm/bin/edm-state:1094-1096` -- the one `_resolve_permcheck_project_root` sub-case that
  still accepts `CLAUDE_PROJECT_DIR` unconditionally is the no-git-toplevel case, and the code says
  why in place: outside a worktree there is no repository boundary for it to have violated. The
  containment arm at `:1085` also accepts any *subdirectory* of the toplevel, so a repo vendoring a
  `.claude/settings*.json` under a subdirectory could in principle stamp `permission-ask` -- I
  globbed for `.claude/settings*` under `plugins/edm/evals/fixtures/` and found none, so the shape
  is not reachable in this tree. Both are correct residuals of a fix, not gaps in it.
- `plugins/edm/bin/edm-state:1809` -- the `2>/dev/null` on the diagnostic's resolver call is not a
  suppressed warning: `check_permission_rules()` at `:1804` already ran the same resolver
  unsuppressed on the same code path, so this second call is silenced only to avoid printing the
  disagreement warning twice. Correct as written.
- `plugins/edm/CLAUDE.md:927` -- "All scripts must be POSIX-compatible bash (`#!/bin/bash` or
  `#!/usr/bin/env bash`)" still sanctions the exact form `wave7-smoke.sh:5450` now forbids by
  `check_absent` for the commit-hook delegate. A doc/enforcement divergence at the home of the very
  portability rule CA-499 closed; the actionable half is L6's axis (documentation accuracy), so
  recorded here as a cross-reference rather than re-filed as an L8 finding.
- `plugins/edm/bin/tests/wave7-smoke.sh:5502` (and ~14 sibling heredocs) -- scratch stub scripts
  authored with `#!/bin/bash` while every production script uses the env-resolved form. Test-only
  fixtures, and on a host with no `/bin/bash` the suite fails loudly rather than silently
  degrading. False-alarm filter #1.
- `plugins/edm/evals/fixtures/tiny-svc/config/settings.json:5` --
  `"billingApiKey": "FIXTURE-HARDCODED-SECRET-DO-NOT-USE"`, a deliberately planted, self-labelling
  fake credential that is one of the ground-truth gaps `score-artifacts.sh` dimension 6 measures.
  Filter #1.
- `plugins/edm/evals/README.md:26`, `:36`, `evals/baseline/README.md:36` -- `export
  ANTHROPIC_API_KEY=sk-...` in operator docs. Placeholder, not a value.
- `plugins/edm/CLAUDE.md:391`, `:399` -- `/Users/darryl.porter/projects/caveman` and `.../ponytail`.
  Prose recording how a one-off licence inspection was performed; never resolved by any code path.
  Provenance, not a portability defect. Genericizing is L6's tidiness argument.
- `.gitlab-ci.yml:513` -- CA-111: `bash:3.2` remains an unpinned floating tag with its documented,
  explicitly-authorized exception note at `:504-512` and a stated must-pin-before-first-live-use
  condition. Previously dispositioned.
- `plugins/edm/monitors/monitors.json:4` -- `"command": "edm-state watch-impl"`, a bare
  PATH-resolved invocation, no arguments, no interpolation. No injection surface.
- `plugins/edm/bin/edm-lint-staged-artifacts:147-149` -- `for p in $prefixes` is an intentional
  unquoted split, and the comment at `:146` records that every token was already clamped to
  `^[A-Za-z0-9_-]+$` upstream, so no token can carry whitespace or a glob character. The two
  `EDM_SRD_ROOT="$check_dir" edm-state ...` calls pass `$p` as argv, not through a shell. Safe; the
  `..`-component and absolute-path rejections at `:88-107` close the traversal side.
- CA-130 reproduces for an **ELEVENTH** consecutive round: `Write` is granted at
  `agents/edm-audit-security.md:5` but absent from this lens's delivered runtime tool set (delivered:
  Read, Grep, Glob, WebFetch, WebSearch, TaskStop -- also missing `LS`, `NotebookRead` and
  `TodoWrite`), so neither `lens-L8.md` nor `lens-L8.jsonl` could be written by the lens and both
  halves are transcribed by the launching agent. The delivered prompt was additionally *not* this
  file's body verbatim -- the `## Scope` block at `:17-25` was absent and no `## JSONL Line Format`
  section was surfaced -- so the prompt-supplied fallback schema (D22/CA-130) is the one used.
  Host-side, already filed; do not re-file.
