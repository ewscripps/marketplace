# Lens L5: Runtime Hygiene

Scope: every file the EDM bash tooling (`bin/edm-state`, `bin/edm-init`, `bin/edm-lint-artifacts`) creates at runtime inside the **user's project tree**, plus the hook/monitor configs. Question for each: cleaned up? gitignored if it must NOT be committed? will it show as untracked noise in `git status`?

Dev-host note: `flock` is **absent** on the macOS dev host, so `with_state_lock` takes the `.lockd` mkdir spin-lock fallback locally. On Linux/CI (`flock` present) the `.lock` fast path runs instead. The two paths have **different** hygiene profiles — see L5-02.

## Runtime-created file inventory

| File | Created by (file:line) | Cleaned? | Gitignored? | Verdict |
|------|------------------------|----------|-------------|---------|
| `SRD/{PREFIX}/.edm-state.json` | `cmd_init` `edm-state:483`; rewritten by `_write_state_body` `edm-state:261` (19 `write_state` callers) | N/A (persistent, committed on purpose) | Only when `commit_state_file=false` (`edm-init:117-119`) | NOTED — intentional, committed by design |
| `SRD/{PREFIX}/.edm-state.json.bak` | `_write_state_body` `edm-state:260` (`cp -p "$1" "${1}.bak"`) — on **every** state mutation | No — overwritten each write, **never deleted** | **No** — uncovered by root `.gitignore`; `edm-init`'s per-initiative `.gitignore` excludes only `.edm-state.json`, not `.bak` | **L5-01 (P2)** untracked-file noise next to the committed state file |
| `SRD/{PREFIX}/.edm-state.json.lock` | `with_state_lock` flock path `edm-state:294` (`200>"${lockfile}"`) — **Linux/CI only** | **No** — flock releases via FD close but the file is never removed | **No** — same uncovered path as `.bak` | **L5-02 (P2)** untracked lock-file noise on flock hosts |
| `SRD/{PREFIX}/.edm-state.lockd/` (+ `pid`) | `with_state_lock` mkdir fallback `edm-state:298,307` — **macOS/no-flock only** | **Yes** — `rm -rf "$lockdir"` + `trap … EXIT INT TERM HUP` (`edm-state:309,312`) | No (but transient, so see verdict) | NOTED — cleaned on success and on signal; only leaks on `kill -9`/power-loss |
| `SRD/{PREFIX}/HANDOFF.md` | `write_handoff_internal` `edm-state:1923` | N/A (persistent, committed on purpose) | No (intended) | NOTED — versioned deliverable per plugin CLAUDE.md |
| `SRD/{PREFIX}/decisions.md`, `explorers/`, `code-audit/` | `edm-init:84,85,101,105` | N/A (persistent, committed) | No (intended) | NOTED — scaffolded deliverables |
| `SRD/{PREFIX}/.gitignore` | `edm-init:118` — only when `commit_state_file=false` | N/A (persistent) | No (it IS the ignore file) | NOTED — but incomplete coverage feeds L5-01/L5-02 |
| `SRD/.archived/{PREFIX}/` | `cmd_archive` `edm-state:834-840` (`git mv`/`mv`) | N/A (move, not temp) | No (intended — archive is committed history) | NOTED — moves the whole dir incl. any stray `.bak`/`.lock`; see L5-03 |
| `SRD/{PRODUCT}/{PREFIX}__{DESC}/` (+ moved `.edm-state.json`) | `cmd_migrate_path` `edm-state:1063,1067,1081` | N/A — `git mv`/`mv` of existing dir; no temp file created | N/A | NOTED — atomic-ish move; **no temp file**, so no temp-cleanup concern |
| `.git/index.lock` (removal only) | `cmd_git_lock_check` `edm-state:1221` removes a stale one; never creates | Removed when stale | Lives under `.git/` (never tracked) | NOTED — remediation helper, not a runtime artifact of EDM |
| Hook/monitor side effects | `hooks/hooks.json`, `monitors/monitors.json` | They only invoke `edm-state`/`edm-lint-artifacts` | — | NOTED — create no files of their own |
| `edm-lint-artifacts` | whole file | Read-only (`find`/`grep`/`sed -n`) — writes nothing | — | NOTED — no runtime files |

## Findings

| ID | Sev | File:Line | Issue |
|----|-----|-----------|-------|
| L5-01 | P2 | `edm-state:260`, `edm-init:117-119` | `.edm-state.json.bak` is created beside the committed state file on every write and is **not gitignored** — permanent untracked noise (or, if staged, churns every commit) |
| L5-02 | P2 | `edm-state:294` | flock fast-path creates `.edm-state.json.lock` and never removes it; not gitignored — untracked noise on Linux/CI |
| L5-03 | P3 | `edm-state:837` | `cmd_archive` `git mv`'s the initiative dir; a stale `.bak`/`.lock` inside it makes `git mv` fail and silently fall back to plain `mv`, dragging the sidecars into `.archived/` |

---

### L5-01 — `.edm-state.json.bak` is untracked noise next to a committed file (P2)

**Problem.** `_write_state_body` runs `cp -p "$1" "${1}.bak"` before every write (`edm-state:260`), and there are **19** `write_state` call sites (`set`, `approve-gate`, `phase-start`, `phase-complete`, `set-mode`, `record-*`, etc.), so the `.bak` is (re)created on essentially every EDM operation. It sits at `SRD/{PREFIX}/.edm-state.json.bak` — i.e. **inside the committed tree, immediately beside the file git IS tracking**.

It does not accumulate unboundedly (it's overwritten, not suffixed/rotated), so this is not P1 growth. But it is never deleted, and it is **not gitignored**:
- The root `.gitignore` covers only `.claude/`, `.serena/`, `.DS_Store`, `/.idea/` — nothing EDM-related.
- `edm-init` writes a per-initiative `.gitignore` (`edm-init:118`) containing exactly `.edm-state.json` — and only when `commit_state_file=false`. In the **default** `commit_state_file=true` case there is **no `.gitignore` at all**, so the `.bak` is fully exposed.

`git check-ignore` confirms it: `SRD/EDMV2/.edm-state.json.bak` → exit 1 (no match → not ignored).

Net effect: every user running EDM on the default config gets a permanent `?? SRD/{PREFIX}/.edm-state.json.bak` in `git status`, sitting right next to the file they review in PRs. Worst case a developer does `git add SRD/...` by directory and commits the backup, which then churns on every subsequent phase.

**Evidence.**
```bash
# edm-state:259-262
_write_state_body() {
  [[ -f "$1" ]] && cp -p "$1" "${1}.bak"   # created beside the committed state file, every write
  printf '%s\n' "$2" > "$1"
}
# edm-init:116-119 — the ONLY .gitignore EDM writes, and only in the non-default branch:
COMMIT_STATE="${CLAUDE_PLUGIN_OPTION_COMMIT_STATE_FILE:-true}"
if [[ "$COMMIT_STATE" != "true" ]]; then
  echo ".edm-state.json" > "$DIR/.gitignore"   # excludes the state file but NOT .bak
fi
$ git check-ignore -v SRD/EDMV2/.edm-state.json.bak; echo $?
1     # not ignored
```

**Fix (gitignore entry).** The cleanest fix is a root-level rule that covers the sidecars regardless of layout or `commit_state_file`. Add to `/Users/darryl.porter/projects/marketplace/.gitignore` (and document it so users adopting EDM add the same to their own project root):
```gitignore
# EDM runtime sidecars — never commit (the .edm-state.json itself IS committed by design)
.edm-state.json.bak
.edm-state.json.lock
.edm-state.lockd/
```
And make `edm-init` always emit these into the per-initiative `.gitignore` (unconditionally, independent of `commit_state_file`). Replace `edm-init:116-119` with:
```bash
COMMIT_STATE="${CLAUDE_PLUGIN_OPTION_COMMIT_STATE_FILE:-true}"
{
  echo ".edm-state.json.bak"
  echo ".edm-state.json.lock"
  echo ".edm-state.lockd/"
  [[ "$COMMIT_STATE" != "true" ]] && echo ".edm-state.json"
} > "$DIR/.gitignore"
```
(Alternatively, drop the `.bak` entirely and rely on git history as the backup, since the state file is committed — that removes the artifact instead of ignoring it. Either is acceptable; the gitignore approach is lower-risk because it preserves the T132 backup behavior other lenses may depend on.)

---

### L5-02 — flock lock file `.edm-state.json.lock` left behind on Linux/CI (P2)

**Problem.** When `flock` is available (Linux, most CI images), `with_state_lock` opens the lock on FD 200 via `) 200>"${lockfile}"` (`edm-state:294`). `flock` releases the advisory lock when the FD closes, but the **lock file is never unlinked** — `${lockbase}.lock` = `SRD/{PREFIX}/.edm-state.json.lock` persists after the command exits. Like the `.bak`, it lands in the committed tree and is not gitignored (`git check-ignore` → exit 1).

This is host-dependent and therefore easy to miss: on the macOS dev host (`flock` absent) the code takes the `.lockd` mkdir fallback, which **does** clean up (`rm -rf "$lockdir"` at `edm-state:312` plus a `trap … EXIT INT TERM HUP` at `:309`). So the bug is invisible during local dev and only appears for teammates / CI on Linux. The `.lockd` fallback is fine (NOTED in the table); only the flock path leaks.

Deleting the lock file is **not** safe to do unconditionally inside the subshell (unlinking it while another waiter holds an open handle is a known flock footgun — that's a concurrency concern owned by another lens). The hygiene-only remedy is to make sure it never shows up in `git status`.

**Evidence.**
```bash
# edm-state:289-294
if command -v flock >/dev/null 2>&1; then
  (
    flock -w 10 200 || { echo "... timeout ..." >&2; exit 1; }
    "$@"
  ) 200>"${lockfile}"     # lockfile created here; no matching rm anywhere in the file
fi
$ grep -c 'rm.*lockfile\|rm.*\.lock\b' bin/edm-state   # => 0 (only .git/index.lock removal exists, unrelated)
$ git check-ignore SRD/EDMV2/.edm-state.json.lock; echo $?   # => exit 1, not ignored
```

**Fix (gitignore entry).** Covered by the same root-level + `edm-init` `.gitignore` additions in L5-01 (`.edm-state.json.lock`). That neutralizes the untracked-file noise without touching the locking semantics. If a lens that owns concurrency later wants the file physically removed, the safe place is a single best-effort `rm -f "${lockfile}"` *after* the subshell returns (outside the `flock` FD scope), but that is out of L5 scope — the gitignore entry is the L5 fix.

---

### L5-03 — stale sidecar can flip `cmd_archive`/`migrate-path` from `git mv` to plain `mv` (P3, nice-to-have)

**Problem.** `cmd_archive` (`edm-state:836-840`) and `cmd_migrate_path` (`edm-state:1066-1070`) both do `git mv "$src" "$dst" 2>/dev/null || mv "$src" "$dst"`. `git mv` of a directory fails if the directory contains an **untracked** file that would collide or that git can't account for; in practice the `.bak`/`.lock` left by L5-01/L5-02 are untracked, and `git mv` of a tree containing untracked cruft can fail, silently falling back to plain `mv`. The fallback drags the `.bak`/`.lock` into `SRD/.archived/{PREFIX}/` (or the migrated product dir) as untracked files, and because the move was not git-aware the rename is no longer recorded as a rename. This is a second-order consequence of L5-01/L5-02, not an independent defect — once the sidecars are gitignored, `git mv` behaves predictably and nothing stale rides along.

**Evidence.**
```bash
# edm-state:836-840 (archive) and 1066-1070 (migrate-path) — identical pattern
if git -C "$src" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git mv "$src" "$dst" 2>/dev/null || mv "$src" "$dst"   # 2>/dev/null hides the failure; mv carries cruft along
else
  mv "$src" "$dst"
fi
```

**Fix.** No separate code change required — resolving L5-01/L5-02 (gitignoring the sidecars) makes git treat them as ignored, so `git mv` of the directory succeeds and the ignored files are simply not moved by git (they get left behind or moved by the filesystem but never tracked). If desired as defense-in-depth, prune sidecars before the move: `rm -f "${src}"/.edm-state.json.bak "${src}"/.edm-state.json.lock` and `rm -rf "${src}"/.edm-state.lockd` immediately before the `git mv` line in both `cmd_archive` and `cmd_migrate_path`. Optional; the gitignore fix is sufficient.

---

## Noted / Not Actionable

- **`.edm-state.json` is committed** — intentional per the plugin CLAUDE.md ("State is in the project, not the plugin"; `commit_state_file` default `true`). NOTED, not a finding. The audit question was its sidecars, addressed in L5-01/L5-02.
- **`HANDOFF.md`, `decisions.md`, `explorers/`, `code-audit/`, `architecture.md`** — all are version-controlled deliverables by design (plugin CLAUDE.md, "Artifacts live in the project's `SRD/` directory and are committed"). Persistent and committed on purpose. NOTED.
- **`.edm-state.lockd/` + `pid` (mkdir fallback)** — cleaned on success (`rm -rf` at `edm-state:312`) and on signal (`trap … EXIT INT TERM HUP` at `:309`). Only leaks on uncatchable `SIGKILL`/power-loss, after which the next run's 50-try timeout surfaces the stale holder PID. Consistent, documented, self-healing pattern. NOTED (the matching `.lock` flock path is the real gap → L5-02).
- **`.git/index.lock`** — `cmd_git_lock_check` only *removes* a stale one (`edm-state:1221`), never creates it, and the file lives under `.git/` which is never tracked. A remediation helper, not an EDM runtime artifact. NOTED.
- **`cmd_migrate_path` "atomic write"** — it does `printf '%s\n' "$new" > "$new_state_file"` directly onto the already-moved file (`edm-state:1081`); there is **no temp file** in the migrate path, so the "temp cleaned on success AND failure?" question has no target here. NOTED — no temp file exists to leak.
- **Hooks / monitors** — `hooks/hooks.json` and `monitors/monitors.json` only invoke `edm-state` / `edm-lint-artifacts`; they create no files of their own. Covered transitively. NOTED.
- **`edm-lint-artifacts`** — read-only scanner (`find`/`grep`/`sed -n`/`mapfile`); writes nothing to disk. NOTED.
