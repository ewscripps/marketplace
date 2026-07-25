# Lens L8: Security & Portability

**Scope**: `plugins/edm-ai-development/bin/{edm-state,edm-init,edm-validate-prefix,edm-lint-artifacts}` + `bin/tests/*.sh`
**Host fact**: Audited on the stated dev/primary host — macOS 26.5 (darwin), `/bin/bash` = **3.2.57**, `/bin/date` = BSD, `flock` = **absent**.
**Platform requirement (from SRD)**: `tickets/epics/02-foundation-plumbing.md:36` — *"The lock must be portable across macOS and Linux (C-3). `flock` is unavailable by default on macOS"*. So macOS is a **supported, first-class platform**, not a Linux-only deployment. Portability breaks on macOS are therefore **P1**, not NOTED.

## Findings

| ID | Sev | File:Line | Issue |
|------|------|-----------|-------|
| L8-01 | **P1** | `edm-lint-artifacts:60` | `mapfile -t` is a bash 4.0+ builtin; absent in macOS stock `/bin/bash` 3.2 — script aborts under `set -e`, so `/edm:` lint is fully broken on the primary host. |
| L8-02 | **P1** | `edm-state:110-152, 264-272` (also `:799-806`, `:1054-1059`) | Path-traversal arbitrary-directory write: `PREFIX` is interpolated into the state-file path with **no format validation** in `edm-state`. A `PREFIX` of `../victim/X` writes/overwrites `<dir>/.edm-state.json` outside `SRD_ROOT`. Verified live. |
| L8-03 | P2 | `edm-state:1059, 1063-1070` | `migrate-path` builds `dst` from raw `--product`/`--description` with no sanitization; `..`/`/` in either escapes the product subtree where the parent path exists. `git mv`/`mv` themselves are injection-safe (quoted), so this is path-confinement only, not command exec. |
| L8-04 | P2 | `edm-state:283-316` | `flock` fast-path uses **FD 200**; works but FD 200 is high/undocumented and the subshell relies on `set -e` propagation. Recommend `exec {fd}>` dynamic FD allocation (bash 4) or a documented low FD, plus an explicit non-zero handling comment. Hardening only — current behavior is correct. |
| L8-05 | P2 | `edm-state:1523-1638` | `update-patterns` appends (`>>`) to plugin-relative `docs/audit-patterns/*.md`. When the plugin is installed read-only (typical for `~/.claude/plugins` / system installs), the append fails. Plugin tree is assumed writable. |
| L8-06 | P3 | `edm-state:1218` | `pgrep -x` + `xargs` in `git-lock-check` — works on macOS/Linux as used, but `xargs` with empty input is a no-op only because of the preceding `tr`; minor robustness nit. |

## L8-01 — `mapfile` breaks `edm-lint-artifacts` on macOS bash 3.2 (P1)

**Problem**: `edm-lint-artifacts` collects markdown files with `mapfile -t MD_FILES`. `mapfile`/`readarray` are bash 4.0+ builtins. macOS ships `/bin/bash` 3.2.57 (Apple has never shipped bash 4 due to GPLv3), and `#!/usr/bin/env bash` resolves to that 3.2 on a stock host. With `set -euo pipefail` active, the failed builtin aborts the script before `MD_FILES` is populated, so `edm-state lint <PREFIX>` (which delegates here, `edm-state:1509-1514`) is non-functional on the primary platform.

**Evidence**:
```bash
# edm-lint-artifacts:60
mapfile -t MD_FILES < <(
  find "$INIT_DIR" -not -path '*/.git/*' -not -path '*/.archived/*' -name '*.md' 2>/dev/null | sort
)
```
Live run under stock macOS bash:
```
$ /bin/bash --version           -> GNU bash, version 3.2.57(1)-release (arm64-apple-darwin25)
$ /bin/bash edm-lint-artifacts LINTTEST
edm-lint-artifacts: line 60: mapfile: command not found   # script aborts
```

**Affected platforms**: macOS with stock `/bin/bash` (the stated dev/primary host) and any host whose first `bash` on PATH is < 4.0. Linux with bash 4+ is unaffected.

**Fix**: Replace `mapfile` with a 3.2-safe read loop, e.g.:
```bash
MD_FILES=()
while IFS= read -r f; do MD_FILES+=("$f"); done < <(
  find "$INIT_DIR" -not -path '*/.git/*' -not -path '*/.archived/*' -name '*.md' 2>/dev/null | sort
)
```
(`edm-state` itself contains no bash-4 constructs and runs fine on 3.2 — confirmed — so the fix is isolated to this one file.)

**Severity rationale**: P1 — a documented supported platform (macOS, per SRD C-3) is the dev host, and the feature fails outright there, not degrades. Not P0 only because lint is an advisory/CI-adjacent helper, not a gate-blocking write path.

## L8-02 — Path-traversal arbitrary write via unvalidated `PREFIX` in `edm-state` (P1)

**Problem**: `edm-init` and `edm-validate-prefix` enforce `^[A-Z][A-Z0-9]{2,5}$`, but `edm-state` accepts **any** string as `PREFIX` and interpolates it directly into the on-disk path via `state_file_for()` → `write_state()`. `write_state` does `mkdir -p "$(dirname "$f")"` then writes, so `..` segments in `PREFIX` walk out of `SRD_ROOT`. Subcommands `init`, `set`, `srd-version`, `approve-gate`, `record-*`, `current-step`, `set-mode`, etc. all reach this path; `archive` (`:799-806`) and `migrate-path` (`:1054-1059`) likewise build `src`/`dst` from a raw prefix.

**Evidence** (live, `EDM_SRD_ROOT=/tmp/edmtest/SRD`):
```bash
$ edm-state init '../victimdir/INJECTED'
initialized /tmp/edmtest/SRD/../victimdir/INJECTED/.edm-state.json
$ ls /tmp/edmtest/victimdir/INJECTED/.edm-state.json   # OUTSIDE SRD_ROOT
-rw-r--r-- ... /tmp/edmtest/victimdir/INJECTED/.edm-state.json
$ edm-state set '../victimdir/INJECTED' attacker_controlled yes
$ jq -r .attacker_controlled /tmp/edmtest/victimdir/INJECTED/.edm-state.json
yes
```
Relevant code:
```bash
# edm-state:112
local flat_path="${SRD_ROOT}/${prefix}/.edm-state.json"   # prefix unsanitized
# edm-state:270-271
mkdir -p "$(dirname "$f")"
with_state_lock "$lockbase" _write_state_body "$f" "$content"
```

**Attack vector**: `PREFIX` reaches `edm-state` from skills/hooks and is frequently derived from LLM-generated or artifact-sourced text (the `UserPromptExpansion` hooks do `prefix=$(echo "$ARGUMENTS" | awk '{print $1}')` and pass it straight to `edm-state gate-check "$prefix"`). A malicious or malformed prefix yields a **create/overwrite primitive** on any directory-relative `<dir>/.edm-state.json` the process can reach (the filename component is fixed, so it cannot target arbitrary filenames, but it can clobber any existing `.edm-state.json` and litter sibling trees / git-tracked dirs). No command execution — `_write_state_body` uses `cp`/`printf` with quoted args.

**Fix**: Validate `PREFIX` at the top of `edm-state` dispatch (or in `state_file_for`) with the same `^[A-Z][A-Z0-9]{2,5}$` regex used by `edm-validate-prefix`, rejecting anything containing `/` or `..`. Centralize so every subcommand inherits it.

**Severity rationale**: P1 — an exploitable path-traversal write that escapes the intended root, reachable from hook/skill input. Not P0 because the fixed `.edm-state.json` filename and lack of code-exec bound the blast radius, and the typical caller supplies a validated prefix.

## L8-03 — `migrate-path` product/description not path-sanitized (P2)

**Problem**: `dst="${SRD_ROOT}/${product}/${prefix}__${description}"` (`:1059`) interpolates raw `--product`/`--description`. `..` or `/` in either escapes the product subtree (constrained by `git mv`/`mv` requiring an existing parent). `git mv "$src" "$dst"` and the `mv` fallback are correctly quoted — a `--product 'p; touch X'` becomes a literal directory name, **no command execution** (verified).

**Evidence**:
```bash
$ edm-state migrate-path --product 'p; touch /tmp/edmtest/PWNED1' --description d AAA
migrated AAA: .../SRD/AAA -> .../SRD/p; touch /tmp/edmtest/PWNED1/AAA__d   # literal dir, no exec
```

**Affected platforms**: all. **Attack vector**: path confinement bypass, same class as L8-02 but for the product layout.

**Fix**: Validate `product`/`description` against `^[a-z0-9][a-z0-9-]*$` (matches the documented lowercase-hyphenated slug convention) and reject `/`/`..`. Folds into the L8-02 sanitization work.

**Severity rationale**: P2 — confinement weakness, not arbitrary write outside root in the common case (mkdir only creates the product dir), and no code exec.

## L8-04 — `flock` FD 200 hardening (P2)

**Problem**: The lock fast-path hard-codes file descriptor 200 (`flock -w 10 200` redirected by `) 200>"${lockfile}"`). It is the only user of FD 200 in the script (no conflict today), and the subshell's failure handling depends on `set -e` propagating the inner exit. This works, but a fixed high FD is fragile if a future caller or sourced environment claims 200, and the contract is undocumented.

**Evidence**:
```bash
# edm-state:289-295
if command -v flock >/dev/null 2>&1; then
  ( flock -w 10 200 || { echo "...timeout..." >&2; exit 1; }
    "$@"
  ) 200>"${lockfile}"
```

**Affected platforms**: Linux (where `flock` is present). macOS takes the `mkdir` fallback (`:296-315`), which was verified to work correctly and clean up its lockdir.

**Fix**: Prefer dynamic FD allocation `exec {lock_fd}>"$lockfile"; flock -w 10 "$lock_fd"` (bash 4+; on the 3.2 fallback path flock is absent anyway), or keep 200 with a comment asserting exclusive ownership. Hardening only.

**Severity rationale**: P2 — no current break or exploit; defensive robustness.

## L8-05 — `update-patterns` writes to a possibly read-only plugin tree (P2)

**Problem**: `cmd_update_patterns` resolves `patterns_dir="${script_dir}/../docs/audit-patterns"` from `$0` and appends novel findings with `>> "$pattern_file"` (`:1611-1617`). When the plugin is installed in a read-only location (system path or a managed `~/.claude/plugins`), the append fails. The design assumes the plugin tree is writable.

**Evidence**:
```bash
# edm-state:1540-1541, 1611-1617
script_dir="$(cd "$(dirname "${_s:-$0}")" 2>/dev/null && pwd || echo ".")"
local patterns_dir="${script_dir}/../docs/audit-patterns"
...
{ printf '### %s (%s, %s, P2)\n\n' ... } >> "$pattern_file"
```

**Affected platforms**: all (manifests wherever the install is read-only). **Vector**: not an attack — operational failure / silent data loss for the pattern library.

**Fix**: Detect non-writable `pattern_file`/`patterns_dir` and emit a clear warning + skip (the function already has a "skipping" path for a missing file at `:1564-1567`); or relocate the pattern library to a writable project/`CLAUDE_PLUGIN_DATA` location. Note: this is borderline against the "no docs/dead-code" scope filter but is a portability/assumption issue (writable-install assumption), so retained at P2.

**Severity rationale**: P2 — feature-local failure, recoverable, no security impact.

## L8-06 — `pgrep -x`/`xargs` robustness in `git-lock-check` (P3)

**Problem**: `git_pids="$(pgrep -x git 2>/dev/null | tr '\n' ' ' | xargs || true)"` (`:1218`). `pgrep -x` and `xargs` (whitespace-trim idiom) behave the same on macOS and Linux here (verified), so this is not a portability break — only a minor robustness nit (the `xargs` trim is redundant given the `tr`, and an empty pipeline relies on `|| true`).

**Affected platforms**: none broken. **Fix**: optional — drop the `xargs` and trim in-shell. **Severity rationale**: P3, cosmetic.

## Noted / Not Actionable

- **`flock` missing on macOS → NOTED (correctly handled).** The anticipated top finding is a non-issue: `with_state_lock` (`:283-316`) detects `flock` via `command -v` and falls back to an atomic `mkdir` spin-lock (50 × 0.1s) exactly as mandated by SRD `02-foundation-plumbing.md:36-51` (AC2/AC3) and QC `EDMV2-wave1d.md:33-35`. Verified live on macOS (flock absent): writes succeed and the `.lockd` is cleaned up. Consistent guarded pattern + documented intent → NOTED.
- **`date` flags → NOTED.** Scripts use only `date -u +"%Y-%m-%dT%H:%M:%SZ"` (`:275`) and `date -u +"%Y-%m-%d"` (`:1586`). No `date -d` and no `date +%s%N` anywhere — both are POSIX-portable across GNU/BSD. (Nanosecond/relative-date math is done inside `jq` via `fromdateiso8601`, not `date`.)
- **`mktemp -d` → NOTED.** Only in `bin/tests/*.sh`, and template-less `mktemp -d` works on both GNU and BSD.
- **`sed -i`, `readlink -f`, `stat`, hardcoded absolute paths → NOTED (none present).** No `sed -i` in any bin script; `sed` usages (`:1577-1602`) are stdin-filter form (portable). No `readlink -f`/`stat`/absolute paths in production scripts.
- **`grep -P` → NOTED (guarded).** `edm-lint-artifacts:43-47` probes PCRE support (`grep -qP ''`) and provides an `LC_ALL=C grep` fallback (`:108-116`). macOS BSD grep lacks `-P`, so it takes the fallback — handled.
- **`python3` → NOTED (not used).** Token reading is pure `jq` over session JSONL (`:172-191`); no `python3` in any bin script. The mandate's "python3 assumed present" concern does not apply.
- **jq `--argjson` injection → NOTED (safe).** `--argjson` parses its argument as a standalone JSON value, never interpolated into the filter. Crafted payloads to `current_phase`/`approve-gate`/`record-test-coverage` produce "invalid JSON text" and abort — verified. Free-text fields use `--arg`, which stores values literally (a `'"; rm -rf / #'` value is stored verbatim — verified). No jq/SQL/command injection surface.
- **`git mv`/`mv` command injection → NOTED (safe).** All variables in command position are double-quoted; a semicolon in `--product` becomes a literal directory name, not a command (verified). The residual issue is path *confinement* (L8-03), not execution.
- **FD 200 conflict → NOTED.** FD 200 is used only inside `with_state_lock`; no other FD redirection in the script.
- **Lost-update on concurrent writers → out of scope (logic, not security/portability).** 10 parallel `edm-state set` calls collapsed to 1 surviving key because each `cmd_*` does `read_state` *outside* the lock (lock guards only `_write_state_body`). This is a read-modify-write race, not a portability or injection defect, so per the L8 mandate it is flagged here for L-other and not counted as an L8 finding.
- **Env var propagation (`EDM_*_RATE`, `CLAUDE_PLUGIN_OPTION_*`, `EDM_PRODUCT/DESCRIPTION`) → NOTED.** All reads use safe `${VAR:-default}` precedence (`:42-45, 204-222`); `edm-init` correctly `export`s `EDM_PRODUCT`/`EDM_DESCRIPTION` for the child `edm-state init` (`:52-53, 62-63`). No propagation gap found.
