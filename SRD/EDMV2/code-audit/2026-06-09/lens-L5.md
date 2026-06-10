# Lens L5: Runtime Hygiene — Round 2 (2026-06-09)

## Summary

G11 (the round-1 L5 headline) is **CONFIRMED FIXED at the root `.gitignore` level**: `.edm-state.json.bak`, `.edm-state.json.lock`, and `.edm-state.json.lockd/` are all present and correctly matched against the exact names the code creates. After a normal `edm-state set`, no `.bak`/`.lock`/`.lockd` sidecar appears as untracked. The `.bak` stays single (overwritten, not rotated). Locks self-clean (mkdir path) or are inode-only (flock path).

However, the **G9 atomic-write fix introduced a new runtime file that L5 must now own: the temp file `${state}.tmp.$$`** (e.g. `.edm-state.json.tmp.41234`). This name is **not** matched by any `.gitignore` entry and is **not** cleaned by any trap. In the normal path it is `mv`'d away within milliseconds, but on a failed write (jq error under `set -e`) or a SIGKILL/SIGINT in the redirect→`mv` window, it leaks beside the committed state file as permanent untracked noise — the precise failure class G9 was added to harden against. One new P2 finding.

## Findings

### [P2] Atomic-write temp file `.edm-state.json.tmp.$$` is neither gitignored nor trap-cleaned — `bin/edm-state:295`, `:314`, `:1120`

**Evidence:**
The G9 atomic-write fix replaced truncate-in-place with temp-file-plus-rename in three places:
- `_write_state_body` (`bin/edm-state:295`): `printf '%s\n' "$2" > "${1}.tmp.$$" && mv -f "${1}.tmp.$$" "$1"`
- `_rmw_state_body` (`bin/edm-state:314`): `jq "$@" "$filter" "$f" > "${f}.tmp.$$" && mv -f "${f}.tmp.$$" "$f"`
- `cmd_migrate_path` (`bin/edm-state:1120`): `printf '%s\n' "$new" > "${new_state_file}.tmp.$$" && mv -f ...`

The temp file is created **in the same directory as the committed `.edm-state.json`** (correct — that is what makes the `mv` atomic), with the literal name `.edm-state.json.tmp.<pid>`.

The root `.gitignore` (`.gitignore:9-11`) ignores exactly three sidecars:
```
.edm-state.json.bak
.edm-state.json.lock
.edm-state.json.lockd/
```
There is **no** `*.tmp`, no `.edm-state.json.tmp*` entry. `git check-ignore .edm-state.json.tmp.41234` exits 1 (not ignored).

There is **no trap covering the temp file.** The only trap (`:366`, cleared `:370`) does `rm -rf '${lockdir}'` on the mkdir-lock path; it never references `.tmp.$$`. On the flock fast path there is no trap. So on abort paths the temp file survives: jq emits invalid output / errors → `&&` short-circuits, `mv` never runs, `set -e` aborts with the temp file on disk; or the process is killed in the redirect→`mv` window.

Because it sits inside the committed `SRD/{…}/` tree and matches no ignore glob, it shows as `?? SRD/{…}/.edm-state.json.tmp.41234` indefinitely. The PID suffix means repeated failures accumulate **distinct** leaked temp files (unlike `.bak`, bounded to one).

**Why it matters:** This is the exact hygiene + git-status-noise problem G11 was raised for, reintroduced by the G9 fix on a sibling filename the round-1 `.gitignore` patch didn't anticipate. P2, not P1: the happy path never leaks, the gate logic keys off `.edm-state.json` content, and a leaked temp file is deletable. It rises above NOTED because it dirties `git status` exactly like the G11 sidecars, failed writes are precisely when the operator is debugging, and it can accumulate unbounded.

**Suggested fix (any one):**
- Simplest — gitignore the pattern: add `.edm-state.json.tmp.*` to the root `.gitignore`.
- More complete — clean on failure: in `_write_state_body`/`_rmw_state_body`, `rm -f "${f}.tmp.$$"` on the failure branch (and extend the mkdir-path trap).
- Both together is cheap and closes both vectors.

## Round-1 fix verification (L5)

| Finding | Status | Evidence |
|---|---|---|
| **G11** (P2) `.bak`/`.lock`/`.lockd` not gitignored | **CONFIRMED FIXED** | Root `.gitignore:9-11` lists all three; names match code exactly (`.bak` `:294/:313`, `.lock` `:340/:348`, `.lockd/` `:341/:355`). `.bak` overwritten (bounded). Lock dir self-cleans via trap; flock lockfile inode-only. The remediation-doc planned name `.edm-state.lockd/` was corrected to the code-accurate `.edm-state.json.lockd/`. |
| **G24** (P3) stale-sidecar cleanup nits | **CONFIRMED FIXED (transitively)** | Because `.bak`/`.lock`/`.lockd` are now gitignored, `cmd_archive` (`:867-868`) and `cmd_migrate_path` (`:1105-1106`) cannot drag a tracked sidecar into `.archived/`. The one item this did NOT cover: the `.tmp.$$` temp file (a different sibling name introduced by G9) — see new finding above. |

## Runtime-file inventory

| File / pattern | Where | Persists? | In `.gitignore`? | Cleaned up? | Verdict |
|---|---|---|---|---|---|
| `.edm-state.json.bak` | `:294`,`:313` | Yes (single, overwritten) | Yes `:9` | Overwritten; never rotated | OK |
| `.edm-state.json.lock` (flock) | `:348` | Yes (empty inode) | Yes `:10` | Inode-only, harmless | OK |
| `.edm-state.json.lockd/` + pid | `:355`,`:364` | No | Yes `:11` | `rm -rf` on success + trap | OK |
| `.edm-state.json.tmp.$$` | `:295`,`:314`,`:1120` | Normally no; **leaks on failure/SIGKILL** | **No** | **No trap, no failure `rm`** | **P2 — see finding** |
| `HANDOFF.md` | `:1916` | Yes | n/a (deliverable) | Overwritten each call | OK |
| `decisions.md` | `edm-init:85` | Yes | n/a (deliverable) | n/a | OK |
| Pattern-library append | `:1623` | Yes (plugin doc) | n/a | guarded by `-w` check `:1570` | OK |
| `.git/index.lock` | `:1259-1260` | n/a | n/a | only removed, never created | OK |

No log files, caches, DB, downloads, PID files outside the self-cleaning lockdir. No unbounded-growth directory other than the `.tmp.$$` accumulation noted.

## Noted / Not Actionable

- **`edm-init` per-initiative `.gitignore` does not list the sidecars (`edm-init:116-119`).** Divergence from the plan but not actionable: the root `.gitignore` already ignores all three at every depth, so coverage is complete. NOTED.
- **`migrate-path` can copy a stale `.bak` into the destination (`:1105-1106`).** Now gitignored → neither in `git status` nor tracked into `.archived/`. Cosmetic, overwritten on next mutation. NOTED.
- **Flock lockfile never `rm`'d (`:348`).** Intentional/correct for `flock(1)` (locks the inode); empty, bounded, gitignored. NOTED.
- **`.bak` single, not rotated (`:294`).** By SRD design (EDMV2-105). NOTED.
- **Test smoke scripts use `mktemp -d`.** Ephemeral OS temp, test-only, never on a deploy path. NOTED.
