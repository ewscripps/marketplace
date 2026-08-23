# Code Audit Pass 6 -- Lens L8: Security & Portability

**Tooling note (CA-130's class):** Write/Edit/Bash absent from this lens's delivered
runtime tool set (Read, Grep, Glob, WebFetch, WebSearch, TaskStop only). This report
was transcribed by the orchestrator from the lens agent's final message.

**Round:** 6 (`pass-6_2026-08-10`)
**Scope:** `plugins/edm/**` (bin/, hooks/, evals/, skills/, agents/, docs/) plus the edm-scoped jobs of the repository-root `.gitlab-ci.yml`
**Lens mandate:** bash file-descriptor conflicts, hardcoded absolute paths, env-var propagation gaps, privilege assumptions, missing systemd hardening, SQL/command/path injection
**Round-5 L8 entries checked for reopening:** CA-298 (closed, verified), CA-305 (partially closed -- see L8-6-03), CA-319 (closed, verified with one residual -- see L8-6-05), CA-320 (**incompletely closed** -- see L8-6-01)

## Findings (L8: Security & Portability)

### L8-6-01 -- P1 -- `plugins/edm/hooks/hooks.json:86`

**Vulnerability class:** security-control bypass via env-var / working-directory resolution-base mismatch (CA-320's remediation is incomplete, and the fix removed the only observable signal)

Round 5's CA-320 fix correctly repointed **two** of the hook's four resolution bases at the repository root:

- the existence guard -- `check_dir="${repo_root:-.}/${srd_root}"`, with `repo_root=$(git rev-parse --show-toplevel)`
- the staged-path matcher -- the `root="$root_for_awk" awk ...` prefix strip over `git diff --cached --name-only`

It did **not** repoint the two **consumers** at the end of the same hook body. Both still resolve `srd_root` against the hook's own cwd, independently of everything the hook just computed:

- `bin/edm-state:65` -- `SRD_ROOT="${EDM_SRD_ROOT:-${CLAUDE_PLUGIN_OPTION_SRD_ROOT:-./SRD}}"`, consumed by `state_file_for` (`bin/edm-state:223`) as a cwd-relative path
- `bin/edm-lint-artifacts:64` -- byte-identical derivation

**Exploitation scenario (no attacker, no user error).** A commit made with the hook's cwd anywhere other than the repository root -- the exact premise CA-320 itself established, and which the remediation accepts by resolving `repo_root` from git at all:

1. `check_dir="$repo_root/SRD"` exists -> guard passes.
2. Staged path `SRD/edm/EDMV3__prompt-streamline/srd.md` is repo-root-relative -> awk extracts `EDMV3` -> `grep -E '^[A-Z][A-Z0-9_-]*$'` passes -> `prefixes="EDMV3"`.
3. `edm-state resolve-dir EDMV3` runs with `SRD_ROOT="./SRD"` relative to the **subdirectory**; `state_file_for` returns `./SRD/EDMV3/.edm-state.json`, `cmd_resolve_dir` (`bin/edm-state:4416`) finds no file and dies.
4. `|| continue` skips the prefix. Every prefix skips the same way. `fail` stays 0. Hook `exit 0`.

Net: **all commit-time artifact enforcement silently drops, and the pre-CA-320 misleading-typo diagnostic that at least signalled *something* is gone.** The `edm-lint-artifacts` invocation on the next line is unreachable in this configuration, so an attribution trailer, a non-ASCII byte or a raw Mermaid semicolon commits clean. The same mismatch also makes the guard itself wrong (not merely the consumers) when the Claude Code project directory is a *subdirectory* of the git root -- a monorepo sub-project -- because `$repo_root/SRD` is then not where the SRD tree lives at all.

Severity is P1 rather than P0 because the blocking `lint:artifacts` CI job (`edm-lint-artifacts --all`) still catches the same violation classes at merge-request time, so the failure mode is a lost fast local gate, not an unguarded merge path.

**Concrete fix.** Make all four bases agree on one absolute value, once, and add executing coverage:

1. After `check_dir` is computed and the `-d` test passes, pass it down explicitly to both children rather than letting them re-derive: `EDM_SRD_ROOT="$check_dir" edm-state resolve-dir "$p"` and `out=$(EDM_SRD_ROOT="$check_dir" edm-lint-artifacts "$p" 2>&1)`. Both honor `EDM_SRD_ROOT` (`edm-state:65`, `edm-lint-artifacts:64`) and both accept an absolute value without further change. (Equivalently, `cd "$repo_root" || exit 0` immediately after `repo_root` is captured -- one line, and it fixes the matcher's base as a side effect. Prefer the explicit-env form so the fix is visible at the two call sites it protects.)
2. Add a smoke case that **executes** the hook body -- not a static grep of it -- from a subdirectory of a scratch repo with a real violation staged, asserting exit 2. The only current coverage of this hook body is static (`wave7-smoke.sh:3370` and the `wave7-smoke.sh:6176` stub-based case), which is structurally incapable of observing a resolution-base mismatch; that is the same blind spot CA-298's fix note already called out for the sibling hook family.

### L8-6-02 -- P2 -- `plugins/edm/hooks/hooks.json:86`

**Vulnerability class:** enforcement silently disabled by an operator-side git config value (portability of the assumed path base)

The staged-path matcher assumes `git diff --cached --name-only` emits **repository-root-relative** paths. That is git's default, but it is configurable: `diff.relative = true` (repo-level `.git/config`, `~/.gitconfig`, or `-c`) makes `git diff` behave as if `--relative` were passed, which both (a) prints paths relative to the current directory and (b) **excludes staged paths outside the current directory entirely**.

**Exploitation scenario.** A developer with `diff.relative = true` set globally -- a common ergonomic preference -- commits from a subdirectory. Every staged `SRD/...` path is either re-based or dropped, the awk prefix strip matches nothing, `prefixes` is empty, and `test -z "$prefixes" && exit 0` fires. Enforcement drops with no diagnostic. This compounds L8-6-01 and is closed by the same edit.

**Concrete fix.** Pin the base explicitly: `staged=$(git -c diff.relative=false diff --cached --name-only 2>/dev/null)`. (`--no-relative` is equivalent but needs git >= 2.28; the `-c` form has no version floor.) If the `cd "$repo_root"` variant of L8-6-01 is taken, keep the `-c diff.relative=false` anyway -- `cd` alone does not defeat `diff.relative`.

### L8-6-03 -- P2 -- `plugins/edm/bin/edm-state:1120-1129`

**Vulnerability class:** predictable shared-directory artifact converts a successful privileged write into a false failure (residual of CA-305's remediation)

CA-305's fix is correct on both of the halves it named: the flock timeout marker moved out of the tracked initiative directory to `${TMPDIR:-/tmp}/edm-state.lock-timeout.$$` (`:1117`), and the truncating `: >` redirect became `mkdir` (`:1120`), which is atomic and refuses any pre-existing name including a planted symlink. Both verified closed.

What the rewrite introduced: the marker's **existence probe at `:1122` now runs unconditionally**, on every return path from the locked subshell, where the pre-G49 design consulted `_lock_ec -eq 99` first. The pre-clean at `:1118` is best-effort (`rm -rf ... 2>/dev/null || true`).

**Exploitation scenario.** On a host with a shared `/tmp` (unset `TMPDIR`, sticky bit set, multiple local users or a shared CI shell runner), another local user pre-creates `/tmp/edm-state.lock-timeout.<pid>` as a directory they own. The victim's `rm -rf` cannot remove it and fails silently; `mkdir` is never reached because there was no timeout; `[[ -e ... ]]` is true; `die "state lock timeout after 10s on ..."` fires **after the locked body has already run and mutated `.edm-state.json`**. The caller -- roughly thirty bare mutator call sites via `rmw_state` -- is told the write timed out when it succeeded. The PID space is small enough (32768 default on Linux) to pre-plant exhaustively, making this a cheap local denial-of-service against every `edm-state` mutation plus a state/report divergence. Capped at P2: flock-branch-only (Linux/CI, never macOS), and requires either a co-tenant local user or an unremovable stale entry.

**Concrete fix.** Gate the probe on the only branch that can create the marker, preserving G17/CA-305's two-arm diagnostic:

```
if [[ $_lock_ec -eq 99 ]]; then
  if [[ -e "$_lock_timeout_marker" ]]; then
    rm -rf "$_lock_timeout_marker" 2>/dev/null || true
    die "state lock timeout after 10s on ${lockfile} (another edm-state process may be holding it)"
  fi
  die "state lock timeout after 10s on ${lockfile} ... -- the timeout marker could not be created at ${_lock_timeout_marker} (check TMPDIR writability)"
fi
```

Optionally also unpredictable-ize the name (`mktemp -d "${TMPDIR:-/tmp}/edm-state.lock-timeout.XXXXXX"` captured before the subshell, path passed in) so the pre-plant is not possible at all. Extend `wave7-smoke.sh`'s G49 case (currently `wave7-smoke.sh:7209`, a static needle on the marker path literal) with an executing case that plants an unremovable marker and asserts a successful write still reports success.

### L8-6-04 -- P2 -- `plugins/edm/evals/run-eval.sh:266`

**Vulnerability class:** `TMPDIR` not honored -- the sole surviving bare `mktemp -d` in `bin/` + `evals/`

`SCRATCH_DIR="$(mktemp -d)" || die "mktemp -d failed"` is the only `mktemp` in the plugin with no template. Every one of the ~40 siblings uses `mktemp -d "${TMPDIR:-/tmp}/<name>.XXXXXX"`, and `bin/tests/_harness.sh:59` names a bare `mktemp -d` explicitly as the anti-pattern `harness_scratch_dir` was extracted to replace (CA-049/G21): *"honoring TMPDIR (unlike a bare `mktemp -d` with no template)"*. So this is the one outlier against a convention the project states in writing -- the False Alarm Filter's consistency test fails here rather than excusing it.

**Portability consequence.** On macOS -- this project's declared primary development platform -- a template-less `mktemp -d` behaves as `-t tmp`, which resolves against `_CS_DARWIN_USER_TEMP_DIR` **first** and only falls back to `TMPDIR` when that configuration variable is unavailable (verified against the macOS mktemp(1) synopsis). An operator or sandbox that redirects `TMPDIR` -- a size-bounded scratch volume, a seccomp/sandbox-permitted path, a CI build volume -- is therefore bypassed, and the eval driver's fixture copy, throwaway git repo and every `claude -p` write land in `/var/folders/...` instead.

**Second-order consequence, and why it interacts with L8-6-01.** The macOS path returned is under `/var`, which is a symlink to `/private/var`, so `$SCRATCH_DIR` and `git rev-parse --show-toplevel` run inside it disagree. `run-eval.sh:443` then exports that unresolved value as an absolute `EDM_SRD_ROOT`, which is exactly the shape the new hook guard's relativization (`case "$srd_root" in "$repo_root"/*)`) cannot match -- a string-prefix comparison against a symlink-resolved root. Not reachable in the eval today (the run's `--allowedTools` grants no `Bash(git *)`, so the `git commit` matcher never fires), but it is the live counterexample to the guard's relativization contract and is worth fixing on both sides.

**Concrete fix.** `SCRATCH_DIR="$(mktemp -d "${TMPDIR:-/tmp}/edm-eval-scratch.XXXXXX")" || die "mktemp -d failed"`. Separately, add a template-less-`mktemp` pattern to the T61 AC11 divergence sweep at `bin/tests/wave7-smoke.sh:1022` -- its current regex catches a template *suffix* (`XXXXXX[A-Za-z0-9]`, BSD-rejecting) but has no pattern for a *missing* template, which is why this site survived CA-014's widening of that very sweep to cover `evals/`.

### L8-6-05 -- P2 -- `.gitlab-ci.yml:603`, `.gitlab-ci.yml:657`, `plugins/edm/bin/tests/wave7-smoke.sh:4511-4517`

**Vulnerability class:** supply-chain pin whose enforcement control accepts a floating specifier

CA-319's remediation is landed and correct as shipped: both `npm install -g @anthropic-ai/claude-code@2.1.226` lines carry an explicit version (that version is real -- it is the registry's current `dist-tags.latest`), both carry the refresh-procedure cross-reference, and the deliberate decision to leave install scripts enabled is documented with the reason (`postinstall: node install.cjs` fetches the platform binary, so `--ignore-scripts` would break rather than tighten the install). The AC11 exemption gap it named is also closed -- `wave7-smoke.sh:4505-4513` adds the weaker per-job pin assertion for both `allow_failure` jobs.

The residual is in the assertion itself. `check` is a plain substring test (`_harness.sh:27-34`), and the needle is `"npm install -g @anthropic-ai/claude-code@"`. `@latest`, `@next`, `@^2.1.0` and `@~2.1` all contain that substring and all satisfy the check. The negative control at `:4516` only proves that a **bare** install (no `@` at all) fails. So the one control guarding the least-controlled, `ANTHROPIC_API_KEY`-bearing job in the pipeline can be satisfied by exactly the unpinned behavior it exists to prevent -- and "replace the stale pin with `@latest`" is the single most likely future edit to this line.

**Concrete fix.** Tighten the needle to require a numeric first character after the `@` (e.g. assert against a `@[0-9]` regex form, or a captured `@<major>.<minor>.<patch>` match, rather than a bare substring), and add a second negative control asserting that `npm install -g @anthropic-ai/claude-code@latest` does **not** satisfy it. Consider also folding the two pinned versions into a single `variables:` entry so the pin is one line to refresh, matching what `.alpine_edm` already does for the image digest.

## Noted / Not Actionable

| Item | Rationale |
|---|---|
| `flock` on fd 200 (`bin/edm-state:1071-1074`, `:1120`) | Re-swept this round for `>&9`, `<&9`, `exec 1[0-9]`, `BASH_XTRACEFD` and any `exec N<` across `bin/`, `bin/tests/`, `evals/` and `hooks/`: zero hits outside fd 200. 200 is deliberately above the bash-internal and `BASH_XTRACEFD` range and is required because bash 3.2 has no `{var}` auto-assignment (banned by T61 AC9's own CI grep). Confirms CA-123; do not re-file. |
| No systemd units, no SQL, no HTTP client anywhere in the plugin | The systemd-hardening, SQL-injection and SSRF sub-lenses are structurally N/A. Grep confirms zero `.service`/`.timer` files, zero SQL, and zero `curl`/`wget` in `bin/` or `evals/` -- the only occurrences are inside comments and inside the CI network-ban assertion's own positive-control fixture. |
| `eval "$saved"` (`bin/edm-state:557`, `_restore_trap`) | The operand is `trap -p`'s own output for a trap this same process installed moments earlier; bash quotes it itself and no external data reaches it. Same class: `bin/tests/_harness.sh:143-145` and `bin/tests/timing.sh:193` (`_mp95_var` is a file-local literal identifier). |
| `run-eval.sh:393` `--allowedTools` prefix matchers (`Bash(jq *)` et al.) with `--permission-mode acceptEdits` | The file's own comment at `:362-373` documents precisely that a prefix matcher is satisfied by shell metacharacters after the matched prefix and that this is an accepted tradeoff for an unattended run, not a hard boundary. CA-086's remediation was to stop the comment misdescribing it, which it now does. |
| `git add -A` at `run-eval.sh:271` | Throwaway `mktemp` scratch repo, never the user's tree; CA-124. |
| Placeholder image digests and the floating `bash:3.2` tag (`.gitlab-ci.yml:10-20`, `:402`) | Self-declared placeholders with a documented refresh procedure and an explicit authorization; CA-111. |
| `for p in $prefixes` (hooks.json:86) and `set -- $list` (`edm-check-grants:186`) unquoted | Both charset-constrained before use -- `grep -E '^[A-Z][A-Z0-9_-]*$'` and the comma-split-with-disable-comment respectively -- and neither charset contains a glob metacharacter; CA-117. |
| `$ARGUMENTS` in the five `UserPromptExpansion` command hooks (`hooks.json:19,32,45,58,71`) | Quoted at every expansion, then charset-filtered by the `case ''|*[!A-Za-z0-9_-]*)` arm before the value reaches `edm-state`. The `awk '{print $1}'` extraction preceding the filter cannot escape the quoting. CA-087 closed. |
| `EDM_SRD_ROOT` exported absolute at `run-eval.sh:443` | Required for the child `claude -p` and for the driver's own `edm-state` calls to resolve inside the scratch tree regardless of cwd, and documented as such at `:440-442`. The macOS symlink consequence is filed separately as L8-6-04, not as an objection to the export. |
| `HUMAN_HOURLY_RATE_USD` / `EDM_TOKEN_READ_LINE_CAP` startup validation (`bin/edm-state:84-85`) | CA-160 closed and verified: the regex rejects `+`, exponent notation and arithmetic metacharacters at the point the default is established, before any jq-program splice or `tail -n`. |
| `to_int` coercion at arithmetic sinks | Spot-verified still in place at `schema_at_least` (`:1319`) and `phase_start_prerequisite_gate` (`:837`), with the bash-3.2 array-subscript command-substitution rationale intact at `:92-108`. CA-001/CA-003/CA-157 remain closed. |
| Path-traversal guards in `state_file_for` (`bin/edm-state:222`, `:248`, `:250`) and `edm-init:72-77` | Prefix, `EDM_PRODUCT` and `EDM_DESCRIPTION` all still constrained to `^[A-Za-z0-9_-]+$`; CA-082 closed. `edm-lint-artifacts --path` takes an operator-supplied path by design and is read-only. |
| CA-305's symlink half | Genuinely closed -- `mkdir` refuses any pre-existing name of any kind, and `rm -rf` on a symlink removes the link, never the target. Only the unconditional probe ordering is filed (L8-6-03). |
| File modes written by `edm-init` (`.gitignore`, `decisions.md`) | Default umask, no secrets in any file the plugin creates; no mode-setting call anywhere in `bin/` outside test fixtures restoring their own scratch permissions. |
| `${TMPDIR:-/tmp}` as the scratch base | Standard, and the correct portable form; the finding at L8-6-04 is the one site that does *not* use it. |

**Round-6 L8 summary:** 1 x P1, 4 x P2, 0 x P0. The P1 and one P2 are the same twenty lines of the same hook and should be remediated in one pass; L8-6-04's sweep-widening half and L8-6-05's needle-tightening half are both durability edits to existing assertions rather than new coverage.
</content>
