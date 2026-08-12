# Lens L3 -- Edge Cases & Concurrency (Round 7)

**Tooling note (CA-130's class, 7+ consecutive rounds):** Write absent from this
lens's delivered runtime tool set. This report was transcribed by the
orchestrator from the lens agent's final message, after a stalled first attempt.

**Coverage caveat (read before weighting a clean result):** this run was
truncated by the tool budget. Surface actually reviewed: `bin/edm-state` lock/
atomic machinery (lines ~1074-1370, plus the archive/migrate lock-sweep sites
at 2900-2950 and 3341-3375), `bin/edm-sync-canonical-sections` in full, and a
repo-wide grep index of every `flock`/`mktemp`/`mv -f`/`with_state_lock`/
`write_atomic` call site. **Not** reviewed: `write_atomic`'s body (line 637+)
and its `_EDM_TRAP_DEPTH` interaction, `state_file_for` (line 219, the round-6
duplicate-match fix), `edm-lint-artifacts` cleanup traps, and the
`cmd_watch_impl` poll loop. No P0/P1 in the reviewed surface -- but that is a
statement about ~30% of the concurrency surface, not the whole of it.

## Findings (L3: Edge Cases & Concurrency)

### P2 -- flock-timeout marker is created at one path and swept at a different one; both sweeps are dead code

`plugins/edm/bin/edm-state:1202` creates the G49 marker at:
```bash
_lock_timeout_marker="${TMPDIR:-/tmp}/edm-state.lock-timeout.$$"
```
The two cleanup sweeps glob a different directory *and* a different separator
-- `:2948` (archive) and `:3372` (migrate-path) both do `for m in
"${_dst_lockbase}".lock.timeout.*`. `.lock-timeout.` (hyphen, in TMPDIR) never
matches `.lock.timeout.*` (dot, beside the lockbase). Both loops are
unreachable, and the comments asserting coverage are wrong -- `:2933` claims
"G25 (CA-256): also sweep the G49 flock-timeout marker glob
(`${lockbase}.lock.timeout.<pid>`)", naming a path nothing ever creates.

Trigger: none at runtime (impact is bounded -- `:1203` pre-clears the marker
before every flock attempt, and TMPDIR is transient). The defect is that the
next contributor reads the sweep and believes marker cleanup is handled at
both sites.

Fix, and it should be this direction rather than the other: move the marker
creation to `${lockbase}.lock.timeout.$$` so the two existing sweeps become
live. That also fixes the next finding for free. If you instead point the
sweeps at TMPDIR, they can only ever sweep the *current* process's marker,
which is pointless -- so delete them and correct both comments.

Caveat: the grep was truncated at 120 matches; confirm with `grep -n
'lock.timeout\|lock-timeout' plugins/edm/bin/edm-state` that `:1202` is the
only creation site.

### P2 -- `$$` does not uniquely identify a subshell, so a sibling's pre-clear can steal another's timeout marker

`bash` expands `$$` inside a subshell to the *parent's* PID. If any caller ever
backgrounds two `with_state_lock` bodies from one shell, both compute the
identical `_lock_timeout_marker` path. Sequence: child B times out and
`mkdir`s the marker (`:1205`); child A then reaches its own `rm -rf
"$_lock_timeout_marker"` pre-clear at `:1203` and deletes B's marker; B's
`_lock_ec == 99` branch at `:1218` finds nothing and falls to the else-arm at
`:1224`, dying with *"the timeout marker could not be created ... (check
TMPDIR writability)"* -- a message that sends the operator to investigate
TMPDIR permissions for what was actually a plain lock timeout.

Never a false success (both arms `die`), so this is a diagnosability bug, not
a correctness one -- which is why it is P2 and not P1. Secondary fragility in
the same line: the marker path is keyed by PID but **not** by lockbase, so one
process locking two different initiatives in sequence reuses one marker path.
Harmless today only because `:1203` re-clears each time.

Fix: `_lock_timeout_marker="${lockbase}.lock.timeout.${BASHPID:-$$}"` -- keys
on both the lock identity and the true subshell PID, and lands the marker
where the existing `:2948`/`:3372` sweeps already look.

### P2 -- the two lock branches bound the same wait at 10s and ~5s depending only on whether `flock(1)` exists

`:1205` uses `flock -w 10`. The mkdir fallback's own die text at `:1109` reads
`"state lock timeout after ~5s (50 tries x 0.1s)"`. Identical logical
operation, 2x different worst case, selected by host platform (Linux has
`flock(1)`, macOS typically does not -- and macOS is named in `CLAUDE.md` as
this project's primary development platform).

Round 6's G33/CA-364 fix aligned the *units in the message* between the two
branches; it did not align the durations. No live defect, because nothing
currently wraps `edm-state` in an outer time budget. It becomes one the moment
something does -- a CI `timeout 8 edm-state ...`, or the `cmd_watch_impl` 5s
poll interval growing a lock-taking step -- at which point the wrapper fires on
macOS and not on Linux, or vice versa, for the same contention.

Fix: one constant, both branches derived: `EDM_STATE_LOCK_WAIT_S=10`; `flock -w
"$EDM_STATE_LOCK_WAIT_S"`; max tries `= EDM_STATE_LOCK_WAIT_S * 10`.

### P2 -- `_lock_retry_or_die` reads its retry counter out of the caller's scope instead of taking it as a parameter

`plugins/edm/bin/edm-state:1102` declares `local _lockdir="$1" _reason="$2"`
and then consults `tries` -- a variable it never receives -- relying on bash
dynamic scoping from `with_state_lock`'s loop. Correct today (all three call
sites, `:1299`/`:1313`/`:1317`, are inside that loop). A fourth call site
added anywhere else silently mis-accounts: `tries` resolves to a global or,
under `set -u`, aborts inside the arithmetic. Fix: `_lock_retry_or_die
<lockdir> <reason> <tries>`, three-line change, removes an invisible coupling
from a function whose whole job is bounding a retry loop.

### P2 -- `edm-sync-canonical-sections` stages its temp file inside the tracked repo tree, where an untrappable signal leaks it

`plugins/edm/bin/edm-sync-canonical-sections:81` does `tmp="$(mktemp
"${DST}.tmp.XXXXXX")"`, i.e. `plugins/edm/docs/canonical-sections.md.tmp.
XXXXXX`. The trap at `:84` covers `EXIT INT TERM HUP` (CA-150 -- genuinely
thorough), but `SIGKILL` and OOM are untrappable, so those leak a stray file
into a tracked directory. Neither guard catches it downstream: `CLAUDE.md`'s
"never `git add -A`" convention only mitigates accidental staging, and
`lint:file-type-ban` scans *tracked* files, so an untracked leak is invisible
to it too.

Fix: add `docs/canonical-sections.md.tmp.*` to the plugin's `.gitignore`. Do
**not** relocate the temp to `$TMPDIR` -- the adjacency is what makes the `mv
-f` at `:112` a same-filesystem atomic rename, and a cross-device `mv` would
trade a cosmetic leak for a torn destination file.

## Noted / Not Actionable

- **Round-6 reclaim-direction asymmetry fix: verified sound.**
  `_edm_reclaim_stale_lockdir` (`:1083`) is now the single atomic-rename
  reclaim behind both the invalid-pidfile path (`:1292`) and the dead-PID path
  (`:1308`), and `_git_lock_age_seconds` (`:1290`) is shared with
  `cmd_git_lock_check`. The three-way branch at `:1291`/`:1294`/`:1297`
  distinguishes reclaim / unknown-age-refuse / too-young-refuse, and every
  non-reclaiming arm falls through to `_lock_retry_or_die` -- so a merely-too-
  young lockdir reclaims on a later try instead of dying. EPERM vs ESRCH is
  separated at `:1304`-`:1308` by `kill -0` error text, so a live cross-UID
  holder is not reclaimed.
- **Round-6 marker-probe gating fix: verified sound.** The `[[ -e
  "$_lock_timeout_marker" ]]` probe at `:1218` is now nested inside the
  `_lock_ec == 99` branch, closing the round-6 bug where an unconditional
  probe reported an already-completed successful write as a timeout.
- **Mid-acquisition window is correct by construction, not by luck.** `mkdir
  "$lockdir"` (`:1261`) precedes the pidfile write (`~:1326`), so the interval
  when the pidfile is missing lands on the "invalid PID" path -- the one that
  *is* age-gated. The dead-PID path can only fire against a fully-written
  pidfile, so it correctly needs no age gate.
- **Pidfile short-read cannot produce a truncated-but-valid PID.** `echo $$ >
  pidfile` is a single `write()` of <16 bytes; a concurrent reader sees 0
  bytes (-> invalid-PID path, age-gated) or the whole value. The dangerous
  case (reading `12` from `12345`, then `kill -0` succeeding against an
  unrelated live process) is unreachable on any filesystem this plugin
  supports.
- **The `_lockdir_age_s >= 1` boundary at `:1291` is documented and
  self-correcting.** A 0.99s-old lockdir reads as `0` and is refused; the
  comment at `:1282`-`:1286` states the 10x-margin rationale, and the retry
  fallthrough means the off-by-one costs one 0.1s retry, not a failure.
- **`cmd_archive` unlinks the `.lock` flock file (`:2936`) while
  `cmd_migrate_path` deliberately does not (`:3365`) -- the asymmetry is
  justified.** It reads like a CA-169 violation but isn't: archive's
  destination is `.archived/`, terminal, where no contender ever looks for a
  lock; migrate's destination is the live go-forward path, where unlinking a
  flock target is exactly the inode-reuse hazard G16/CA-304 reasons about at
  `:3346`-`:3353`. Destination liveness is the discriminator and both sites
  get it right.
- **`edm-sync-canonical-sections` has no lock around its read-compute-
  rename.** Concurrent runs both `mktemp` unique temps and both `mv -f`
  (atomic rename), so no torn output; and both derive byte-identical content
  from the same `SRC`, so the "lost update" is a no-op. Single-writer dev/CI
  tool.
- **`--check` mode's diff (`:102`) has a nominal TOCTOU against a concurrent
  `CLAUDE.md` edit.** It runs as a CI job against a fixed checkout.
- **A locked body that legitimately exits 99 would be misreported as a lock
  timeout via `:1224`.** No callee in `bin/edm-state` returns 99, and the
  comment at `:1176` records 99 as reserved; `with_state_lock` only ever
  invokes in-file functions, so the reservation covers the real call set.
- **The `for m in "${_dst_lockbase}".lock.timeout.*` sweeps guard the
  nullglob no-match case correctly** via `[[ -e "$m" ]] || continue`
  (`:2949`, `:3373`) -- the pattern is right even though the glob itself
  matches nothing (see P2 finding 1).
- **`_STATE_LOCKDIR` is a single global consumed by the trap at `:1328`, so
  nested locks would clobber it.** The reentrancy guard at `:1130`-`:1151`
  makes nesting unreachable, and round 6 is what armed that guard on the
  flock branch.

**Two items not cleared this round, handed to the parent rather than silently
dropped:** `bin/edm-lint-artifacts:133` and `:140` create `ATTR_PATTERN_FILE`
and `MERMAID_SCAN_FILE` via `mktemp` in TMPDIR; a cleanup trap was not
verified to exist. If absent, the leak rate is per-`git commit` (the
`PreToolUse` hook path), not per-session, which is what makes it worth
checking. And `state_file_for` (`bin/edm-state:219`) -- round 6's duplicate-
match refusal -- was not re-verified this round.
</content>
