# Lens L1: Logic, Correctness & Completeness -- Round 5

Scope: full plugins/edm/ tree, repository-root CLAUDE.md/.gitlab-ci.yml/.gitignore, and
SRD/edm/EDMV3__prompt-streamline/**. Emphasis per brief on Wave 8 diffs in bin/edm-state
(git-lock-check, with_state_lock retry/reentrancy, the three extracted helpers) and timing.sh.

## Findings (L1: Logic, Correctness & Completeness)

| ID | Severity | File:Line | What's Wrong | Fix |
|----|----------|-----------|--------------|-----|
| L1-001 | P1 | plugins/edm/hooks/hooks.json:19 (and :32,:45,:58,:71) | CA-253's `|| exit 2` conversion now BLOCKS on any gate-check failure, not only "gate not approved" -- `cmd_gate_check` dies on a missing state file or missing jq, both now indistinguishable from a genuine refusal. Reachable under the supported `commit_state_file=false` config: a fresh clone has no state file, so every gated phase skill hard-blocks with an opaque diagnostic. Contradicts the sibling prompt hook's own text ("or if the state file does not exist -- first invocation, allow expansion") and CLAUDE.md's Hooks-behavior scoping. Invisible to the suite (static grep, never executes a hook body). | Add a resolvability probe before gate-check, mirroring the PreToolUse hook's own idiom: `edm-state resolve-dir "$prefix" >/dev/null 2>&1 || exit 0;` before the gate-check call. Or give cmd_gate_check a distinct non-blocking exit code for setup errors. Convert the static grep to an executing case. |
| L1-002 | P2 | plugins/edm/bin/edm-state:2837 | CA-261 NOT closed: the G30 guard counts state FILES whose estimated_size is non-null; `cmd_init` seeds the literal "Unknown" (non-null), so every file qualifies -- the guard is functionally the old file-count check. The renderer counts something different (`.phase_durations` rows, empty on init), so `--calibrate` still prints only its header on a repo with no completed phases. The comment claims the guard counts "qualifying rows" -- false. | Derive the guard from the same expression the renderer uses, with an explicit `!= "Unknown"` exclusion, so guard and renderer can't disagree. |
| L1-003 | P2 | plugins/edm/bin/edm-state:3406 (gate at :3455) | `find -mmin` is not identical across GNU/BSD: GNU truncates the fraction, BSD/macOS rounds UP to the next minute. So the G27/G43 threshold alignment holds on Linux and shifts a full bucket on macOS (this project's primary dev platform) -- a lock ~1 second old passes the "at least 60s" gate, and `_git_lock_age_bucket` reports "at least 1 minute" for a 2-second-old lock. The docstring claims -mmin is "identical" across GNU and BSD -- true of the flag, false of the rounding. Capped at P2 because the lsof/pgrep oracle still runs after the gate as defence-in-depth. | Compute age numerically via a reference-file comparison (`touch -r`/`! -newer`) or `stat -f %m`/`stat -c %Y` in a labelled platform branch, so age and gate share one computation. |
| L1-004 | P2 | plugins/edm/hooks/hooks.json:86 | CA-186 PARTIALLY fixed: two of four named values (`././SRD`, `SRD/.`) close with executing test coverage; `srd_root="."` and `"./"` still fail open silently. `"."` survives normalization, isn't absolute, and the awk matcher compares against a literal `"./"` prefix git never emits from `--name-only`, so `prefixes` is empty and enforcement silently exits 0. `"./"` reduces to empty and hits the same silent exit. Neither value is in wave7-smoke.sh's eight-shape invariant list. A security control failing open doesn't get the no-documented-workflow defence per the ledger's own prior resolution. | Treat `.` and empty (post-normalization) as "no root prefix, scan the whole path" rather than falling through to silent exit 0; add both shapes to the test's shape list. |
| L1-005 | P2 | plugins/edm/bin/edm-state:3119 | Migrate-path's lock unlink inherits archive's CA-169 exception rationale ("permanently archived, no future caller targets this path") which is false here -- the destination IS the live home and `rmw_state` at :3176 locks it immediately after. Bounded impact (locked body's work is complete before the unlink), but the exception is justified by a rationale that doesn't apply, the same pattern that nearly re-broke CA-169's class once already. Flock branch only. | Remove only `.lockd` and the timeout glob at the migrate-path site, leaving `.lock` on disk per CA-169's default; or move the `.lock` removal to after `with_state_lock` returns so fd 200 is closed first. Replace the false "same exception" clause. |

## Noted / Not Actionable

1. `timing.sh:105` -- `_measure_p95` discards the measured command's exit status; documented
   intentional at :92-96, the assertion half is L4's open CA-262.
2. `timing.sh:43` -- perl-less fallback emits its resolution warning on every call (noise, not a
   defect); CA-197's UNMEASURABLE refusal is what actually protects the emitted numbers.
3. `timing.sh:30` -- not discovered by run-all.sh so its bash-3.2-sensitive constructs are never
   exercised by test:smoke-bash32; all are 3.2-legal today, recorded for future contributors.
4. `edm-state:2722` -- unquoted glob is deliberate pathname expansion; shellcheck-directive
   question belongs to L7/L8.
5. **CA-130 reproduced a sixth consecutive round.** `Write` granted in frontmatter but absent
   from delivered tool set. Delivered agent definition matched on-disk this round.

## Round-4 L1 closure spot-checks

All ledger entries with L1 in Lens(es) re-verified against current tree, not trusted from the
stale Status column (findings-ledger.md hasn't been re-rendered since Wave 8 merged, so all 53
remediated entries still read "open" in the .md render):

- **CA-251** -- FIXED. `--absolute-git-dir` at :3432, fixed-string `grep -F` match at :3509-3510,
  self/parent PID exclusion at :3511, lsof primary oracle, refusal when neither tool available.
- **CA-252** -- FIXED. EXIT-only cleanup body, dedicated INT/TERM/HUP wrappers exiting
  130/143/129, exit-4 decision stays inside EXIT body, CLEANUP_DONE latch retained correctly.
- **CA-258** -- FIXED as specified; new platform gap filed separately as L1-003.
- **CA-196** -- FIXED. `_P95_SAMPLE_COUNT=20` single-sourced, real nearest-rank p95 now (index 19
  of 20), G49's extraction landed first as prescribed.
- **CA-186** -- PARTIALLY FIXED, filed as L1-004.
- CA-182, CA-184, CA-185, CA-187, CA-017, CA-019, CA-197, CA-198, CA-199, CA-133, CA-134,
  CA-135/136/140, CA-047/051/052/071/005/044/006/007/008/011 -- all re-verified present and
  correct in the tree.

New-helper scrutiny with no defect found: `_lock_retry_or_die`'s dynamic-scoping mutation of the
caller's `tries` local is correct at all three call sites; `_unpack_token_fields` writes fixed
globals read immediately by both callers with no interleaving; `_save_traps`/`_restore_traps`
globals cannot collide across the fork boundary; `_EDM_TRAP_DEPTH` is armed and checked
consistently and no locked body nests today (verified by call-graph sweep).

## Meta

`Write` was absent from this lens's delivered runtime tool set despite the frontmatter grant
(ledger CA-130, sixth consecutive round). Both `lens-L1.md` and `lens-L1.jsonl` were transcribed
by the orchestrator.
