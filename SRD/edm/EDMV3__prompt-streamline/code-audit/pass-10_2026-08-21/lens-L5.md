# Lens L5: Runtime Hygiene -- Round 10 (full)

Scope: `plugins/edm/bin/*` (excl. `bin/tests/`), `plugins/edm/bin/tests/*.sh`, `plugins/edm/hooks/hooks.json`, `plugins/edm/evals/**`, `.gitignore` (repo root), plugin docs/skills/agents.
Method: enumerate every file the code creates at runtime; check (1) `.gitignore` coverage at both the repo root and the per-initiative level, (2) whether it can surface as untracked in `git status` on a host, (3) whether it accumulates without cleanup or rotation. Every prior ledger entry naming L5 was re-verified against the current tree.

## Prior-round L5 ledger re-verification

| ID | Ledger status | Round-10 verdict | Evidence |
|----|---------------|------------------|----------|
| CA-495 | open (P2) | **STILL OPEN -- both halves, verbatim, zero lines changed** | (a) `plugins/edm/bin/tests/wave7-smoke.sh:7700` -- `tmp_g22b="$(mktemp -d "${TMPDIR:-/tmp}/edm-g22b.XXXXXX")"`; a whole-file grep for `tmp_g22b` returns exactly three hits (`:7700`, `:7701`, `:7702`), none a removal; `:7699` clears all four trap dispositions; the tree is not under `$TMP`, so the top-level trap at `:25` does not own it. Its identical sibling `tmp_g22a` DOES carry the tail removal at `:7683`. (b) The eleven conditional-leak siblings are still rooted at `${TMPDIR:-/tmp}` rather than `$TMP`: `:5542`, `:5580`, `:5616`, `:5643`, `:5668`, `:5708`, `:5757`, `:5812`, `:5961`, `:7669`, `:8252` (line numbers shifted +426 from the round-9 citations; site-for-site identical). |
| CA-481 | open (P2, L5 secondary) | **STILL OPEN -- all three parts** | (a) `plugins/edm/evals/tiering-matrix.sh:154` is still `trap 'rm -f "${tmp:-}"' RETURN EXIT INT TERM` -- no HUP, no signal-shaped exit. (b) `plugins/edm/evals/score-artifacts.sh:758-760` still arms the cleanup trap only after BOTH mktemps; the sibling that closed this exact gap is `bin/edm-lint-artifacts:133-137` (first-stage trap armed on the line after the first mktemp). (c) No durability pin: a grep of `plugins/edm/bin/tests/` for `CA-446|CA-447` returns zero hits; no cross-file trap/HUP sweep assertion exists in any suite. |
| CA-480 | open (P2, L3-lensed) | **STILL OPEN as L3 filed it; NOT an L5 finding** | `plugins/edm/bin/edm-state:1348` region unchanged (reclaim apparatus still inside the pidfile-is-a-regular-file guard, `:1349-1408`). L5's own axis is clean: the orphaned `.lockd` and its `.stale.$$` aside are both matched by root `.gitignore:36` (`**/*.lockd*`) and by the per-initiative `.gitignore` written at `bin/edm-state:2149-2150` and `bin/edm-init:180`, so a bricked lockdir never reaches `git status`. Do not re-file under L5. |
| CA-014 | fixed | CONFIRMED FIXED on the L5 axis it named (BSD template + trap widened); the residual HUP/exit-shape divergence at the same site is CA-481(a), tracked there. |
| CA-015 | fixed | CONFIRMED. `bin/edm-state:664` is the single `mktemp "${dest}.tmp.XXXXXX"` staging writer; no `.tmp.$$` writer remains anywhere in `bin/`. |
| CA-029, CA-148, CA-149, CA-212, CA-256, CA-382 | fixed | CONFIRMED. Root `.gitignore:30,35,36` (`**/.edm-state.lock*`, `**/*.lock`, `**/*.lockd*`) are unanchored and shape-anchored, so they survive `srd_root` relocation and cover every derived lockbase (`.lockd`, `.lockd.stale.<pid>`, `findings-ledger.lock`). |
| CA-030, CA-045, CA-216 | fixed | CONFIRMED. `bin/tests/wave6-smoke.sh:34` traps `cleanup_wave6` on EXIT INT TERM HUP; the T41 tracked-file backup/restore is inside it. |
| CA-065, CA-150 | fixed | CONFIRMED. `bin/edm-sync-canonical-sections:81` stages as `"${DST}.tmp.XXXXXX"`, matched by root `.gitignore:37` (`**/*.md.tmp.*`) and `:40` (`plugins/edm/docs/*.tmp.*`). |
| CA-066, CA-188, CA-214, CA-291, CA-292 | fixed | CONFIRMED. `evals/run-eval.sh:182-231` prunes with a RUN_ID ownership filter (`:209`), one filtered listing for both count and window (`:209-218`), an explicit-root opt-in (`:183-186`), and a keep-floor clamp (`:197-200`); `:276-279` is the four-arm EXIT/INT/TERM/HUP set with signal-shaped exits and a `CLEANUP_DONE` latch. |
| CA-067, CA-447-at-that-site | fixed | CONFIRMED. `bin/edm-lint-artifacts:133-137` arms a first-stage trap on all four signals immediately after the first mktemp. |
| CA-151 | fixed | CONFIRMED and now enforced in code: `evals/score-artifacts.sh:618-629` refuses to write `scores.json` into the tracked fixture directory without an explicit `--out`. |
| CA-169 | NOTED, must stay unapplied | CONFIRMED intact. `bin/edm-state:1234-1246` carries the do-not-unlink rationale, and the comment now correctly names BOTH entry points that write the per-initiative `.gitignore` (`cmd_init` and `edm-init`). |
| CA-170, CA-450 | fixed | CONFIRMED. `bin/tests/timing.sh:38-52` now installs a process-wide `_timing_cleanup` trap including HUP with a signal-shaped exit; the pre-CA-049 tail-only shape is gone. |
| CA-171 | NOTED | CONFIRMED unchanged and still bounded: `bin/tests/harness-smoke.sh:45,63,115,139,191` are tiny files under `${TMPDIR:-/tmp}`; `:263-264` and `:393` show the CA-146 scratch tree is four-signal-trapped. |
| CA-181 | NOTED (false alarm) | CONFIRMED. `bin/_edm-lint-lib.sh` is tracked. Not re-investigated. |
| CA-213, CA-341, CA-314 | fixed | CONFIRMED. Both entry points write the per-initiative ignore file: `bin/edm-state:2144-2151` and `bin/edm-init:175-182`. |
| CA-215, CA-264, CA-351 | fixed | CONFIRMED. `bin/tests/wave7-smoke.sh:24-25` roots the suite tree under `${TMPDIR:-/tmp}` with a four-signal trap; fake-HOME trees (`:6151-6152`, `:8104`, `:8141`) are nested under `$TMP`. |
| CA-217, CA-449 | fixed | CONFIRMED. `evals/score-artifacts.sh:758-763` uses house-form TMPDIR-honoring templates plus a four-arm trap; the tail-only `rm` is gone. Residual first-mktemp window is CA-481(b). |
| CA-332, CA-372, CA-374, CA-376 | fixed | CONFIRMED, no regression at the named surfaces. |
| CA-399 | fixed | CONFIRMED. `bin/edm-state:5916-5933` wraps the audit-converged stderr file in `_save_traps` + four-arm trap + `_restore_traps`. |
| CA-400 | fixed | CONFIRMED. `bin/tests/_harness.sh:390-392` still guards `session_dir_for_test_cwd` against a `$HOME` outside `${TMPDIR:-/tmp}`. |
| CA-130 | NOTED (delivery-layer) | Not an L5 axis. The JSONL schema was delivered verbatim in this round's launch prompt, so no fallback was needed. |

## Findings (L5: Runtime Hygiene)

### L5-001 (P2, high) -- `plugins/edm/bin/tests/wave7-smoke.sh:7700`: CA-495(a) unchanged -- the G22b scratch tree is created and never removed on ANY path

File type: scratch directory tree containing a full synthetic `SRD/G22RDC` initiative (state file, per-initiative `.gitignore`, HANDOFF staging).
Where created: `tmp_g22b="$(mktemp -d "${TMPDIR:-/tmp}/edm-g22b.XXXXXX")" || exit 1` at `:7700`, followed by `cd "$tmp_g22b"` at `:7701` and `export EDM_SRD_ROOT="${tmp_g22b}/SRD"` at `:7702`, then a real `"$EDM_STATE" init G22RDC` at `:7703`.
In `.gitignore`: N/A -- it never reaches a worktree, which is exactly why no ignore pattern can mitigate it.
Accumulation risk: **unconditional, success path, every run.** `bin/tests/run-all.sh` auto-discovers smoke suites, so every developer following the repo's run-before-you-push instruction mints one tree per run, and CI runs the aggregator twice per pipeline (`test:smoke`, `test:smoke-bash32`). Nothing prunes. On macOS the system temp directory is a per-user path that survives reboots; a long-lived Linux runner sweeps on a timer at best.
False-alarm filter: fails all three clauses -- not gitignore-coverable (never in a worktree), not deleted after use (never deleted), not tmpfs-backed.
Evidence that this is a dropped line rather than a project pattern: the character-for-character identical G22a sibling at `:7669` ends with `rm -rf "$tmp_g22a"` at `:7683`, and roughly 45 other `mktemp -d` calls in this same file nest under `$TMP`.
Fix: change the template root at `:7700` from `${TMPDIR:-/tmp}` to `$TMP` and keep `:7699`'s `trap - EXIT INT TERM HUP` exactly as it is -- the parent's `:25` trap then reclaims it on every path. (A bare tail `rm -rf` would close the success path only; rooting under `$TMP` closes all of them.)

### L5-002 (P2, high) -- `plugins/edm/bin/tests/wave7-smoke.sh:5542`: CA-495(b) unchanged -- eleven subshell scratch trees are rooted outside the suite's trap-covered root, with a tail-position `rm` as their only cleanup

File type: eleven scratch directory trees (lock/state fixtures, a fake `$HOME`, one deliberately mode-555 directory).
Where created: `:5542`, `:5580`, `:5616`, `:5643`, `:5668`, `:5708`, `:5757`, `:5812`, `:5961`, `:7669`, `:8252` -- all `mktemp -d "${TMPDIR:-/tmp}/..."`, each inside a `$( )` subshell that correctly clears all four inherited trap dispositions (`:5541`, `:5579`, `:5615`, `:5642`, `:5667`, `:5707`, `:5756`, `:5811`, `:5966`, `:7668`, `:8255`) for the documented reason at `:5531-5540` -- restoring the inherited copy of the parent's cleanup would delete the shared `$TMP` out from under every later test. The consequence is that after the clear, these resources have **no handler at all** and a tail-position `rm -rf` is their sole cleanup.
In `.gitignore`: N/A (outside any worktree).
Accumulation risk: conditional but with two concrete, non-hypothetical abort paths. (1) Sourcing `edm-state` re-enables errexit inside these subshells -- the suite states this itself in the comment block at `:5586-5589` -- and later statements in several of these blocks are unguarded, so a regression in `edm-state` (precisely what this harness exists to detect) aborts the subshell before its own tail `rm`. (2) A Ctrl-C leaks these eleven while the parent trap reclaims the ~45 nested siblings; `:7669` additionally leaves a mode-555 directory behind if interrupted between `:7676` and `:7680`.
False-alarm filter: the consistent-project-pattern defence fails cleanly -- `bin/tests/wave6-smoke.sh:456-458` states the nest-under-`$TMP` rule outright and ~45 sites in this same file follow it.
Fix: change the template root to `$TMP` at all eleven sites, keep every `trap -` line untouched, and keep the existing tail removals as a fast path. Then add a `bin/tests` tripwire asserting that every `mktemp -d` in `bin/tests/*.sh` either interpolates the suite scratch root or is paired with a trap -- the existing T61 AC11 divergence sweep at `:1139` scans `bin/` and `evals/` and explicitly filters out `/tests/`, so this class is structurally invisible to the repo's own guard.

### L5-003 (P2, high) -- `plugins/edm/evals/tiering-matrix.sh:154`: CA-481(a) unchanged -- the last trap in the plugin omitting HUP, and the last one that resumes instead of exiting

File type: transient self-test fixture file (`edm-tiering-matrix-selftest.XXXXXX` under `${TMPDIR:-/tmp}`, created at `:147`).
Where created/armed: `:147` creation; `:154` `trap 'rm -f "${tmp:-}"' RETURN EXIT INT TERM`.
In `.gitignore`: N/A (TMPDIR).
Accumulation risk: low per event, but it is now the **single declared exception to a declared plugin-wide rule**: `bin/edm-check-grants:124-134` states the four-signal set EXIT INT TERM HUP with signal-shaped exits as the plugin's convention and nine sibling sites were converted. A terminal disconnect during `--self-test` leaks the file; an INT resumes the script rather than exiting 130, so the exit code is wrong too.
Note on the local comment: `:148-153` explains only the RETURN-vs-EXIT reasoning and predates the convention, so it signals nothing about the HUP omission being deliberate.
Fix: convert to the canonical four-arm form (`EXIT` cleanup-only; `INT` then `exit 130`; `TERM` then `exit 143`; `HUP` then `exit 129`), keeping RETURN on the EXIT-equivalent arm.

### L5-004 (P2, medium) -- `plugins/edm/evals/score-artifacts.sh:758`: CA-481(b) unchanged -- one-mktemp untrapped window in `--compare`

File type: two transient JSON staging files.
Where created: `:758` (`_CMP_TA`) and `:759` (`_CMP_TB`); the cleanup traps arm only at `:760-763`.
In `.gitignore`: N/A (TMPDIR).
Accumulation risk: low. The `die` path is covered (`:759` carries an inline `rm -f "$_CMP_TA"`), so only a signal delivered in the one-statement window between `:758` and `:760` leaks. Named here because the sibling fix that closed this identical window already shipped one directory over: `bin/edm-lint-artifacts:133-137` arms a first-stage trap on the line immediately after its first mktemp, with a comment naming exactly this failure mode.
Fix: arm `trap 'rm -f "$_CMP_TA"' EXIT INT TERM HUP` immediately after `:758`, replaced by the two-file trap at `:760`.

### L5-005 (P2, high) -- no cross-file trap-convention sweep exists anywhere in `bin/tests/`: CA-481(c) never landed

File type: N/A -- this is the missing durability pin for the whole class above.
Evidence: a grep of `plugins/edm/bin/tests/` for `CA-446|CA-447` returns zero hits. Every `HUP` hit in that directory is an ordinary `trap`/`trap -` line in a suite's own preamble, not an assertion about another file's traps. The plugin-wide four-signal convention is therefore stated in exactly one comment in one file (`bin/edm-check-grants:124-134`) and enforced nowhere -- which is precisely why L5-003 and L5-004 survived a sweep that named `evals/*.sh` in scope, and why L5-001/L5-002 can persist across two rounds.
Accumulation risk: meta -- it is the mechanism by which every finding in this section regresses or survives.
Fix: one assertion scanning `bin/`, `bin/tests/` and `evals/` for cleanup-trap lines, asserting each names HUP and each real-signal arm exits after cleanup, with a planted positive control. Note the existing T61 AC11 sweep at `bin/tests/wave7-smoke.sh:1139` cannot be extended as-is: it filters `/tests/` out, so it would not see L5-001/L5-002 even with a widened alternation.

## Noted / Not Actionable

- **CA-480 (`bin/edm-state:1348`) is not an L5 finding.** The orphaned `.lockd` and its `.stale.$$` aside are both matched by root `.gitignore:36` (`**/*.lockd*`) and by the per-initiative ignore file written at `bin/edm-state:2149-2150` and `bin/edm-init:180`, so a bricked lockdir never appears in `git status`. Its impact is availability (L3), not hygiene. Re-verified STILL OPEN on L3's own axis; recorded here only so the round does not double-count it.
- **`with_state_lock`'s flock lockfile is never unlinked, by design (CA-169).** `bin/edm-state:1234-1246`. Unlinking a released flock file breaks inode-keyed mutual exclusion. Both entry points write `.edm-state.lock*` into the per-initiative `.gitignore` unconditionally, so it is not a leak in a consumer project. Do not "fix" in a later round.
- **The flock timeout marker is clean.** `bin/edm-state:1290-1312`: created under `${TMPDIR:-/tmp}` (not the tracked initiative directory), pre-cleared at `:1291`, created by `mkdir` only on the timeout branch, and removed at `:1307`. Success paths never create it. Its shared-`/tmp` predictable-name exposure is an L8 axis already tracked (CA-305/CA-347).
- **`write_atomic`'s staging files are fully ignore-covered.** `bin/edm-state:664` stages as `"${dest}.tmp.XXXXXX"`; every live destination resolves to a covered glob -- `.edm-state.json` -> `.edm-state.json.tmp.*`, `findings-ledger.md`/`HANDOFF.md` -> `**/*.md.tmp.*` (root `:37`) and `*.md.tmp.*` (per-initiative), `docs/audit-patterns/*.md` -> `plugins/edm/docs/audit-patterns/*.tmp.*` (root `:16`). No `.jsonl` destination passes through `write_atomic` today (`findings-ledger.jsonl` is written by the synthesizer's Write tool), so the absence of a `*.jsonl.tmp.*` pattern is not currently reachable -- worth one line of comment, not a finding.
- **`.edm-state.json.bak` is permanent by design** and covered at root `.gitignore:9` and per-initiative line 1. Documented at `bin/edm-init:167-174` as a migrate-path rollback artifact.
- **`plugins/edm/evals/runs/` is fully self-ignoring.** `plugins/edm/evals/runs/.gitignore` is `*` plus `!.gitignore`, so run output can never surface as untracked; retention is enforced by `prune_old_runs` from all four exit paths.
- **`--out DIR` pointing at an unignored in-repo directory would produce untracked output.** Deliberate and documented (`evals/run-eval.sh:17-21`), and pruning of a caller-chosen root now requires an explicit `EDM_EVAL_PRUNE_EXPLICIT_OUT=true` opt-in (`:183-186`) precisely because that root may hold content the driver does not own. Operator choice, not a defect.
- **`score-artifacts.sh` writing `scores.json` into a tracked fixture directory is now refused in code** (`:618-629`), the CA-151 remediation. Verified present.
- **`edm-state update-patterns` mutates tracked files inside the installed plugin directory** (`bin/edm-state:5402`). That is the intended Living-Library design -- pattern-library growth is meant to be reviewed and committed -- and its staging file is ignore-covered. Not a hygiene defect.
- **`bin/tests/harness-smoke.sh:45,63` (CA-171)** remain untrapped tiny files under `${TMPDIR:-/tmp}` with inline `rm -f`. Unchanged, still bounded, still on a path whose assertion helpers never exit early. Holding at NOTED rather than re-filing.
- **The hundreds of `*.tmp` + `mv` pairs across `bin/tests/wave6-smoke.sh`** (e.g. `:95`, `:606`, `:2295`) all write inside the suite's `$TMP` tree, which `:34`'s four-signal trap owns. Correct by construction.
- **`plugins/edm/hooks/hooks.json`** creates no runtime files of its own -- every hook body delegates to a `bin/` helper whose temp handling is audited above. No `.pid`, no lock, no log, no cache anywhere in the file. Nothing to report.
- **`.claude/worktrees/**` agent trees** are covered by root `.gitignore:1` (`.claude/`). Not plugin-generated and not a hygiene exposure.
