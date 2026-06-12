# Lens L8: Security & Portability — Round 2 (2026-06-09)

## Summary

The Round-1 rewrite is largely solid: I confirmed **zero bash-4 constructs anywhere** in the plugin (bin + tests + hooks), no `eval`, no unguarded BSD/GNU flag hazards, both manifests carrying the four contested userConfig keys, all six state-file enumerators using both layout globs through a 3.2-safe `list_state_files`, and a centralized `^[A-Za-z0-9_-]+$` prefix guard in `state_file_for`. G5/G6/G15/G24 are cleanly fixed.

However, **the G7/G12 path-traversal hardening is incomplete (PARTIAL)**: the sanitization was applied to `state_file_for` (prefix) and `cmd_migrate_path` (product/description) but **two reachable user-input → path sinks were left unguarded**: (1) `edm-state migrate-path`'s positional `PREFIX`, and (2) `edm-init`'s `--product` / `--description` (and the interactive description prompt). Both yield a path-traversal directory-create/move primitive that escapes `SRD_ROOT`. These are the same vulnerability class Round-1 graded P1, and the remediation plan explicitly intended to cover them but did not. I am raising them as **P1** and **P1**.

## Findings

### [P1] `migrate-path` PREFIX is not path-validated — traversal directory-move primitive — `bin/edm-state:1095,1098,1108`

**Evidence:** `cmd_migrate_path` validates `--product`/`--description` (the G12 fix, `:1090-1091`) but never validates the positional `prefix`. It then builds the move endpoints literally:
```bash
src="${SRD_ROOT}/${prefix}"                                # :1095  prefix unsanitized
[[ -d "$src" ]] || die ...                                 # :1096
dst="${SRD_ROOT}/${product}/${prefix}__${description}"     # :1098  prefix unsanitized
...
git mv "$src" "$dst" 2>/dev/null || mv "$src" "$dst"       # :1106 / :1108
```
With `prefix='../../tmp/victim'`, `src` resolves to `${SRD_ROOT}/../../tmp/victim` and `dst` to `${SRD_ROOT}/${product}/../../tmp/victim__<desc>`. If `src` exists (the only constraint, `:1096`), `mv` relocates an arbitrary directory outside `SRD_ROOT`. `git mv`/`mv` are quoted, so no command execution — this is path-confinement escape, identical in class to G7. `migrate-path` never routes `prefix` through `state_file_for` (the central guard).

**Why it matters:** Round-1 fixed G7 by guarding `state_file_for`, but `cmd_migrate_path` constructs the path by hand and bypasses it. The wave5 smoke test exercises traversal rejection for `--product`/`--description` but never for `prefix`, so the gap is untested. PREFIX reaches `edm-state` from LLM/artifact-derived text.

**Suggested fix:** Validate `prefix` at the top of `cmd_migrate_path` before constructing `src`/`dst` (canonical guard, e.g. `^[A-Z][A-Z0-9]{2,5}$` or shared `validate_prefix`). Add a wave5 case asserting `migrate-path … '../../evil'` is rejected with no directory moved outside `SRD_ROOT`.

### [P1] `edm-init` `--product` / `--description` (and interactive slug) are not path-validated — traversal mkdir primitive — `bin/edm-init:18-19,49-50,58-60`

**Evidence:** `edm-init` validates `PREFIX` (`:27`) but takes `--product`/`--description` raw and interpolates them straight into paths:
```bash
--product)    ... PRODUCT="$2"; shift 2 ;;        # :18  no format guard
--description) ... DESCRIPTION="$2"; shift 2 ;;   # :19  no format guard
...
DIR="${SRD_ROOT}/${PRODUCT}/${PREFIX}__${DESCRIPTION}"   # :49
mkdir -p "${SRD_ROOT}/${PRODUCT}"                        # :50  -> mkdir outside SRD_ROOT if PRODUCT has ../
```
The interactive branch is the same (`read -r DESCRIPTION` `:58`, then `DIR=…` `:60`). `--product '../../evil'` runs `mkdir -p "${SRD_ROOT}/../../evil"` and scaffolds the initiative tree there. Worse, `edm-init` `export`s these raw values (`:52-53,62-63`) and calls `edm-state init "$PREFIX"` (`:112`); `state_file_for` computes the path from `EDM_PRODUCT`/`EDM_DESCRIPTION` (`:172`) **without validating product/description** (only `prefix` at `:145`), so the traversal propagates into the state-file path.

**Why it matters:** `edm-init` is the **primary** initiative-creation entry point, and product/description come from interactive prompts / LLM slugs (orchestrator Step 1b). `migrate-path` was hardened against exactly these inputs (G12); `edm-init` — the more common path — was not. The documented convention is lowercase-hyphenated slugs; nothing sanctions skipping validation.

**Suggested fix:** Apply the same guard `cmd_migrate_path` uses to `PRODUCT`/`DESCRIPTION` in `edm-init` (after flag parsing and after the interactive `read`). For defense-in-depth, also validate `EDM_PRODUCT`/`EDM_DESCRIPTION` inside `state_file_for` where consumed (`:169-174`).

## Round-1 fix verification (L8)

- **G5 (diverged manifest)** — **CONFIRMED FIXED** (functionally). Both manifests define `mode`/`compliance_enabled`/`qc_shard_threshold`/`implementation_mode` and agree on the 19-key set. (Both files still exist rather than one being a symlink — accepted; but see L9/L11 re: drift + dead config.)
- **G6 (`mapfile` bash-4)** — **CONFIRMED FIXED.** `edm-lint-artifacts:60-70` now uses `while IFS= read -r … < <(find … | sort)`. Portability sweep across all bin/ + tests/ + hooks/ found zero bash-4 constructs. `list_state_files` dedups with a linear seen-array, not `declare -A`.
- **G7 (PREFIX path traversal)** — **PARTIAL.** Centrally guarded in `state_file_for:145` (covers init/set/srd-version/approve-gate/record-*/current-step/set-mode/resolve-dir). **But `cmd_migrate_path`'s `prefix` bypasses it** (new P1).
- **G12 (`migrate-path` product/description)** — **CONFIRMED FIXED** for product/description (`:1090-1091`). The sibling `edm-init` product/description were **not** guarded (new P1).
- **G15 (`update-patterns` read-only install)** — **CONFIRMED FIXED.** `[[ ! -w "$pattern_file" ]]` warn + `return 0` at `:1570-1573`.
- **G24 (flock FD-200 / pgrep nits)** — **CONFIRMED FIXED.** FD 200 explicit, `git-lock-check` uses `pgrep -x git | paste -sd ' ' -` (POSIX). (Note: L2/L3 flag a `set -e` reachability residual in the same flock block, P2.)

## Portability sweep result

- **bash-4 constructs:** NONE. Grep for `mapfile|readarray|declare -A|local -A|${x^^}|${x,,}|&>>|;;&` across the entire plugin returned no matches. The G1 dedup helper uses a linear seen-array.
- **BSD vs GNU flag risks:** NONE actionable. `grep -P` is guarded by a runtime feature probe with an `LC_ALL=C` byte-range fallback. `date` uses only POSIX forms. `paste -sd`, `ls -t | head`, `sort/tr/cut/sed` (stdin-filter), `cp -p`, `mv -f`, `mkdir -p` — all portable. No `sed -i`, `stat`, `readlink -f`, `date -d`. `mktemp -d` only in tests.
- **`eval` / command injection:** NONE. No `eval`. jq uses `--arg`/`--argjson` (never string-interpolated into the filter); enum fields case-validated. `git mv`/`mv` operands quoted. Residual risk in migrate-path/edm-init is path *confinement* (the two P1s), not code execution.
- **FD conflicts:** NONE. Only FD 200, exclusively inside `with_state_lock`.

## Noted / Not Actionable

- flock absent on macOS → mkdir fallback with PID file + trap. Correct (SRD C-3 / EDMV2-T24). NOTED.
- `EDM_PRODUCT`/`EDM_DESCRIPTION` export across separate Bash tool calls — not a propagation break: `edm-init` exports and calls `edm-state init` in the same process, and on-disk discovery resolves it afterward. NOTED (but see P1 re: validating those env vars where consumed).
- `jq --arg`/`--argjson` injection — none (parsed/verbatim, never concatenated into the filter). NOTED.
- Unquoted `for rp in $related_prefixes_val` (`:1897`) — intentional word-splitting; each element validated as an existing prefix at write time. NOTED.
- `.edm-state.json` committed; sidecars — committed state by design; sidecar gitignoring is L5. NOTED.
- Non-ASCII bytes appear only in comments/prompt prose, never in emitted artifacts. NOTED.
