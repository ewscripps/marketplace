# Lens L3 -- Edge Cases & Concurrency (Round 4)

## Part A -- Cross-round ledger re-verification (every open entry whose Lens(es) includes L3)

| Ledger ID | Sev | Verdict | Evidence |
|---|---|---|---|
| CA-142 | P1 | **FIXED** | The `_EDM_CLEANUP_PATHS` array, `_edm_cleanup_paths_run` and `_edm_cleanup_pop` are gone tree-wide. `_EDM_TRAP_DEPTH` survives only as a reentrancy flag: declared `bin/edm-state:588`, asserted `:1123-1124`, set `:1141`, reset `:1144`. It no longer gates trap installation. |
| CA-143 | P1 | **FIXED** | `write_atomic` installs its own full four-signal layer unconditionally, including inside the fork: `edm-state:616` `_save_traps`, `:622-625` EXIT cleanup-only / INT->130 / TERM->143 / HUP->129. |
| CA-184 | P1 | **FIXED** | `edm-state:1143` is now `( "$@" ) || ec=$?`. Discriminating regression case at `wave7-smoke.sh:4830-4854`. |
| CA-185 | P1 | **FIXED** | `attribution_mode` is a two-value enum again; torn-line count moved to `unparseable_lines`, threaded through both consumers, new `TORN_TOKEN_LINES` anomaly. |
| CA-186 | P1 | **PARTIALLY FIXED** -- see N7 | Two of three halves closed at `hooks/hooks.json:86`; residual normalization gap remains. |
| CA-188 | P1 | **FIXED** | `evals/run-eval.sh:167-206`: both count and window derive from one run-ID-filtered listing; explicit-root opt-in added. |
| CA-061 | P2 | **FIXED** | `edm-state:1046-1054` captures mkdir's stderr, dies fast; `record_degraded_check:1496-1504` warn-and-skips on unwritable state dir. |
| CA-064 | P2 | **FIXED** | `evals/score-artifacts.sh:556-564`: absent run.json sets complete=false with a named reason. |
| CA-141 | P2 | **FIXED** | Invalid-PID branch routes through shared atomic reclaim; PID "0" rejected; sleeps before continue. |
| CA-203 | P2 | **FIXED** | `edm-state:3356-3404`: age gate before liveness probe, lsof + pgrep scoped, rename-aside removal. |
| CA-204 | P2 | **FIXED** | All four renderers carry the null-coalescing default. |
| CA-205 | P2 | **FIXED** | `run_with_timeout` defined ahead of credential probe; probe bounded at 60s. |
| CA-206 | P2 | **PARTIALLY FIXED** -- see N2 | Lock held across both renames now, but unlinked before rename rather than after. |
| CA-207 | P2 | **PARTIALLY FIXED** -- see N8 | Per-file cap loop landed; trailing-newline splice half untouched. |
| CA-208 | P2 | **FIXED** | `edm-state:2674-2702`: git log exit status captured separately, re-anchor on rewritten history. |
| CA-209 | P2 | **FIXED** (one new residual, N5) | Side-channel marker replaces exit-99 sentinel. |

**Net for the Wave 7a redesign:** the reasoning holds under three independent stress tests (bash trap-reset premise, `_save_traps` global-sharing, no locked body re-enters the lock).

## Part B -- New findings

### N1 (P1) -- `evals/run-eval.sh:209-231`: INT/TERM arms of `cleanup()` return instead of exiting

A Ctrl-C before `STARTED=true` (`:401`) neither stops the driver nor can be repeated (the
`CLEANUP_DONE` latch at `:213` makes it uninterruptible), and permanently disables
`write_partial_artifacts` and the documented exit-4 contract. This is the CA-143 class, fixed in
`bin/edm-state`, unfixed in this sibling driver.

**Fix**: split the handler -- `cleanup` as EXIT-only (never calls exit), a wrapper for INT/TERM
that calls `cleanup` then `exit 130`/`exit 143`, matching `edm-state:622-625`/`:1115-1118`.

### N2 (P2) -- `edm-state:2657-2661` and `:3033-3041`: archive/migrate lock unlinked before rename, not after

Two process launches (`git rev-parse`, `git mv`) separate the `rm -rf` from the actual rename, so
a contender can acquire a fresh lock at the same path during the window, and the parent's
unconditional `rm -rf "$lockdir"` at `:1145` can then delete the contender's live lockdir --
CA-141's TOCTOU reintroduced one function away from where its own remediation removed it.

**Fix**: invert the order -- rename first, then remove the lock names at the destination.

### N3 (P2) -- `wave7-smoke.sh:4745-4818`: new SIGINT regression case proves its claim but crashes the suite on timing failures

The tmp-file assertion is genuinely discriminating. But the case is called bare under `set -e`
with two `return 1` paths, so a slow CI runner converts a recorded FAIL into a suite-wide CRASH
losing every assertion after it. `kill -INT` at `:4799` is unguarded where its sibling at `:4788`
carries `|| true`.

**Fix**: call as `... || true`; add `|| true` to `:4799`; add a fourth assertion that `$dest` is
absent after the interrupt.

### N4 (P2) -- `edm-state:1123-1124`: nested-lock reentrancy guard only set/checked on the mkdir branch

A locked body nesting on a distinct lockbase passes on every flock host (all CI runners) and
hard-dies on macOS. CI structurally cannot catch the class the guard exists for.

**Fix**: set and check `_EDM_TRAP_DEPTH` on both branches.

### N5 (P2) -- `edm-state:1010`: G49's new timeout-marker path is matched by no `.gitignore` pattern

Absent from the CA-148 derived-name enumeration at `wave7-smoke.sh:5253-5258` -- the CA-212 class
recurring in the same wave that closed CA-212.

**Fix**: widen `.gitignore:23`/`:11` to `.lock*`; add the marker to the enumeration.

### N6 (P2) -- `edm-state:2765`: `metrics-report --calibrate` guards on state-file count, not qualifying rows

`estimated_size` has no producer (CA-246), so the jq selection is empty and exits 0 -- the
"insufficient data" fallback never fires. Prints a header and nothing on every real repository.

**Fix**: compute the filtered row count first; emit the fallback when it is zero.

### N7 (P2) -- `hooks/hooks.json:86`: CA-186's `./`-strip is single-pass

`EDM_SRD_ROOT="."`, `"./"`, or `"././SRD"` still disable all commit-time enforcement, some
silently. The fix landed a loud diagnostic for only one of four bad shapes.

**Fix**: loop the `./` strip the same way the trailing-slash strip is looped.

### N8 (P2) -- `edm-state:378-382`: whole-directory token fallback still splices lines lacking a trailing newline

A live-appended session JSONL missing its last newline gets spliced onto the next file's first
line -- both messages lost from the fallback's sum.

**Fix**: `tail -n "$_token_read_cap" "$_tf"; echo` inside the loop.

## Noted / Not Actionable

1. mkdir branch gives up after ~5s, flock branch after 10s -- neither bound is close to binding.
2. `_save_traps` depends on the standard POSIX save-traps idiom; empirically pinned by the CA-184 case.
3. `write_atomic`'s `_restore_traps` may re-install the parent's lockdir traps inside the locked
   subshell; both orderings end the critical section at the same point.
4. Pidfile liveness oracle's unsafe direction across PID namespaces is unstated but unreachable
   (mkdir branch only taken when `flock(1)` is absent, and every target environment has it).
5. A single-PID SIGTERM is deferred until the locked subshell finishes -- sub-second, and the
   SIGKILL escalation case is covered by stale-lockdir reclaim.
6. `cmd_render_ledger` calls `write_atomic` unlocked -- pure render, last-writer-wins is correct.
7. `cmd_archive` reads `state_json` unlocked before the locked move; TOCTOU closed by the
   audit-converged re-query.
8. **CA-130 reproduces for a fifth consecutive round.** `Write` absent from delivered tool set
   (Read, Grep, Glob, WebFetch, WebSearch, TaskStop). Delivered agent definition matched the
   on-disk file this time (JSONL Line Format section present) -- only the missing-tool half
   recurred.

## Meta

`Write` was absent from this lens's delivered runtime tool set despite the frontmatter grant
(ledger CA-130). Both `lens-L3.md` and `lens-L3.jsonl` were transcribed by the orchestrator.
