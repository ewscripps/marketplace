# Lens L3 -- Edge Cases & Concurrency (round 5, EDMV3 "prompt-streamline")

Scope: full plugins/edm/ tree, CLAUDE.md, .gitlab-ci.yml, .gitignore, SRD/edm/EDMV3__prompt-streamline/**.

Round verdict: no P0 or P1. Eight P2 findings, five new, three residuals of Wave 8's own fixes.

## Findings (L3: Edge Cases & Concurrency)

### F1 -- P2 (NEW) -- unquoted word-splittable glob on the archive/migrate lock sweep

`plugins/edm/bin/edm-state:2722` and `:3119`: `rm -rf "${_dst_lockbase}.lockd" "${_dst_lockbase}.lock" ${_dst_lockbase}.lock.timeout.*`
-- the third argument is unquoted and neither `SRD_ROOT` nor `product_name` is charset-validated.
A product name or root containing a space splits this into two arguments, silently defeating the
marker cleanup and potentially handing `rm -rf` a truncated path. The only two unquoted expansions
in the file with no `# shellcheck disable=SC2086` directive (six siblings all carry one).

**Fix**: quote the variable, loop the glob: `for _m in "${_dst_lockbase}".lock.timeout.*; do [[ -e "$_m" ]] && rm -f "$_m"; done`.

### F2 -- P2 (NEW) -- flock-timeout marker has no fallback when unwritable

`edm-state:1076-1085`: if the marker write fails (lockfile exists but its directory is read-only),
the parent's `[[ -e ]]` check is false and a bare, message-free exit 99 reaches ~30 bare mutator
callers -- the exact misreport CA-209/G49 was filed to eliminate, reintroduced in this sub-case.

**Fix**: add a secondary diagnostic arm on exit 99 with no marker present; or derive the marker
under TMPDIR so writability doesn't depend on the artifact directory.

### F3 -- P2 (CA-261 residual, PARTIALLY FIXED) -- `--calibrate` row-count guard filters on an always-true predicate

Same defect independently confirmed by L1 (see lens-L1.md L1-002): `cmd_init` seeds
`estimated_size: "Unknown"` which is non-null, so the guard equals the old file count. The
render's actual predicate additionally requires `phase_durations` rows, which init seeds empty --
so the header-with-no-rows symptom survives whenever no phase has completed. Comment states the
inverse of the shipped predicate.

**Fix**: count the rows the render actually emits, treating "Unknown"/empty as non-qualifying.

### F4 -- P2 (CA-186 residual, PARTIALLY FIXED) -- two srd_root values still fail open silently

Same defect independently confirmed by L1 (lens-L1.md L1-004): `srd_root="."` and `"./"` both
disable enforcement with no diagnostic on any channel.

**Fix**: treat `.`/empty (post-normalization) as "no root prefix, scan the whole path" rather than
silent exit 0.

### F5 -- P2 (NEW) -- the tree's only concurrency test crashes the suite instead of failing

`wave6-smoke.sh:2517-2522`, under `set -euo pipefail`: two backgrounded `edm-state set` calls are
reaped with bare `wait`, no exit-code capture. If either loses the lock-timeout race it exists to
exercise, the suite CRASHes at :2521 and loses ~1600 lines of later assertions instead of reporting
a named T64 AC8 failure. Same errexit class as CA-036 but at a shape (bare command, no `$?` line)
the G5 tripwire cannot see.

**Fix**: `t64ac8_ec1=0; wait "$t64ac8_pid1" || t64ac8_ec1=$?` (both pids), assert both are 0 as
named assertions.

### F6 -- P2 (NEW) -- git-lock-check's mv-aside removal can still delete a live lock

`edm-state:3524-3536`: the comment claims the mv-aside idiom's only two outcomes are both safe, but
omits a third -- if a concurrent remover clears the stale lock and git re-acquires it inside the
probe window (tens to hundreds of ms), this process's mv renames git's brand-new live lock aside
and deletes it, permitting a second concurrent index write.

**Fix**: re-assert the age gate immediately before the mv (one more `find -mmin +0`), refuse if it
now reads younger; soften the comment to name the residual rather than assert it away.

### F7 -- P2 (NEW) -- repositioned reentrancy guard's comment denies the behavior it now has

`edm-state:1038-1042`: the reposition (guard moved above the mkdir loop, armed on both branches) is
correct and closes CA-257. But the guard keys on a process-global depth flag, not the lockbase, so
the comment's claim that "different-lockbase nested calls are unaffected" is false in both
directions -- they now die too, on both branches. No locked body nests today (verified
exhaustively), so this is a documentation defect on a live guard, not a live break -- but the next
contributor adding a locked body touching a different lockbase would be misled.

**Fix**: state the guard detects ANY nesting, same or different lockbase; or key it on the lockbase
if cross-lockbase nesting should remain legal.

### F8 -- P2 (NEW, low reachability) -- migrate-path's rollback rename holds no lock

`edm-state:3179`: G46 swept both forward renames into locked bodies; the rollback rename after a
failed `rmw_state` still runs bare. Reachability is low (a lock timeout never reaches this line;
only a jq-filter or write_atomic failure does, at which point no other process holds the lock by
construction) but a concurrent writer acquiring the destination lock in the post-failure window has
its critical section renamed out from under it.

**Fix**: wrap the rollback in a fresh `with_state_lock` acquisition mirroring the forward path.
Also: the created product directory isn't cleaned up on this rollback path (cosmetic, fold in).

## Noted / Not Actionable

**Verified FIXED this round:**
1. CA-207 -- FIXED, newline emitted per file, blank-line no-op confirmed in the jq program.
2. CA-206 ordering -- correct, no ordering race introduced; residuals are F1 (quoting) and F8 (rollback).
3. CA-256 gitignore half -- FIXED, walked every pattern by hand against all four marker shapes.
4. CA-257 -- both live halves FIXED (comment defect is F7).
5. CA-252 -- trap redesign correct, traced all four paths, no double/missed cleanup.
6. CA-036 L3 half -- FIXED, hardening is correct not masking; every internal failure path is
   fail-guarded so a no-op kill surfaces as failing assertions, never a false pass.

**Not actionable (false-alarm filter applied):**
7. run-eval.sh's exit-4 precedence over 130/143/129 is a deliberate documented AC10-uniformity
   exception (`:223-230`) -- recorded so the ledger closes CA-252 knowing this deviation exists.
8. A second Ctrl-C during cleanup's kill-window sleep abandons the rest of cleanup -- inherent to
   the CLEANUP_DONE guard, leaked resources are TMPDIR + gitignored evals/runs/, per CA-291.
9. `COMPLETE=true` precedes run.json's write -- safe only because CA-064 reads an absent run.json
   as complete:false; recorded so nobody reverts that coupling.
10. git-lock-check's liveness probe is correct on every axis it claims (absolute path, fixed-string
    match, self/parent exclusion, safe-direction refusal); only F6's window residual is filed.
11. `_unpack_token_fields`, `_lock_retry_or_die`, `_measure_p95` -- all verified race-free.
12. Unchecked pidfile write at `:1150` requires a failed small write under which everything else
    fails more loudly; not actionable.
13. CA-246 -- `estimated_size` now has a real producer; `last_cmd` remains L11's half.
14. CA-293/CA-294 re-verified still accurate.
15. **CA-130 reproduced a sixth consecutive round.**

## Meta

`Write` was absent from this lens's delivered runtime tool set despite the frontmatter grant
(ledger CA-130, sixth consecutive round). Both `lens-L3.md` and `lens-L3.jsonl` were transcribed
by the orchestrator.
