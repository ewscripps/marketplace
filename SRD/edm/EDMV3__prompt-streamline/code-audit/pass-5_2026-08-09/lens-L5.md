# Lens L5 -- Runtime Hygiene (pass 5, round 5, full round)

Scope: plugins/edm/ (bin/, bin/tests/, evals/, hooks/, docs/) plus the repository-root
.gitignore and plugins/edm/evals/runs/.gitignore.

## Verdicts on open L5 ledger entries

Exactly two ledger entries carry L5 and status open.

| ID | Sev | Ledger status | Round-5 verdict |
|----|-----|---------------|-----------------|
| CA-256 | P2 | open (L3+L5) | **PARTIALLY FIXED -- keep open** |
| CA-264 | P2 | open (L5) | **NOT FIXED -- unchanged** |

### CA-256 -- two of three prescribed halves landed; the test half did not

**Part 1 (.gitignore widening) -- LANDED**, verified character by character: .gitignore:15 is
now `plugins/edm/docs/audit-patterns/*.lock*` and :30 is `**/.edm-state.lock*`; both correctly
match the `.lock.timeout.<pid>` marker shape.

**Part 3 (destination-path cleanups) -- LANDED.** `_cmd_archive_move_body:2722` and
`_cmd_migrate_path_move_body:3119` each now sweep `${_dst_lockbase}.lock.timeout.*` at the
destination, post-rename, correctly per G17/CA-206.

**Part 2 (CA-148 test enumeration) -- NOT LANDED.** `wave7-smoke.sh:5333-5355` still derives and
asserts exactly five names; `${lockfile}.timeout.$$` is absent. Reverting the .gitignore widening
to the round-3 pair still passes all five assertions while re-exposing the marker -- the coverage
is unguarded.

Secondary gap: nothing tests that the two destination sweeps actually remove anything, and neither
sweep line carries the `# shellcheck disable=SC2086` directive its six siblings carry -- quoting
the expansion to silence a shellcheck failure would make both sweeps silently inert with no test
noticing.

**Fix**: add the marker to the enumeration using the source's own formula; add a case planting a
`.lock.timeout.<pid>` file and asserting the archive sweep removes it.

### CA-264 -- unchanged at every point the finding named

Site moved from :5020-5034 to `wave7-smoke.sh:5117-5131`; nothing else changed. Line 5120 is still
the only `HOME` reference in the 6000+ line suite, never overridden, so the CA-160 probe still
writes a fabricated session JSONL into the real invoking user's `${HOME}/.claude/projects/`,
outside the suite's `$TMP` trap, cleaned up only on the success path.

## Findings (L5: Runtime Hygiene)

### L5-1 (P2) -- the plugin's runtime files are gitignored only in the plugin's OWN development repository

**This is the first finding this lens has raised about the deployment host rather than this
repository.** Every prior round (4 rounds running, including this lens's own prior work) walked
`/.gitignore` as if it were the plugin's, when it is actually the plugin's *development
repository's* .gitignore -- the two are the same file only here, because EDM is dogfooded against
its own SRD/ tree.

Two runtime paths under any initiative directory are permanent by design:
- `<init-dir>/.edm-state.json.bak` (`edm-state:691`) -- written on every state mutation, never
  deleted (deliberate, per `edm-state:3169-3174`'s migrate-path rollback rationale).
- `<init-dir>/.edm-state.lock` (`edm-state:1079`) -- deliberately never unlinked per CA-169
  (correct, inode-keyed exclusion rationale, must not be reverted).

Both are covered here by `.gitignore:9` and `:30`. **Nothing in the plugin creates or documents
equivalent coverage in a consumer project.** `edm-init:158-161` writes a per-initiative
`.gitignore` containing only `.edm-state.json`, and only when `commit_state_file != true`. On the
default config, no `.gitignore` is written at all. `plugins/edm/README.md` has zero mentions of
gitignore setup.

**The false claim**: `edm-state:1057-1058`, justifying the permanent lock file, reads "`.gitignore`
already hides `**/.edm-state.lock*` from git status, so this is not a leak." True here, false on
the deployment host -- the load-bearing justification for a permanent artifact states a property
the environment doesn't supply. Same shape as CA-187/CA-254.

**Why it survived 4 rounds**: the CA-148 test copies THIS repository's own .gitignore into its
scratch repo before asserting coverage, so it's structurally incapable of detecting that a
consumer has no equivalent.

**Accumulation**: bounded per initiative, unbounded across initiatives, permanent, and sited
exactly where a reviewer's eyes land (per CLAUDE.md's own "teammate reviews the SRD in a PR"
value). No functional failure or data loss -- caps this at P2.

**Fix**:
1. Add a copy-pasteable `.gitignore` block to `plugins/edm/README.md` for consumer projects:
   `.edm-state.json.bak`, `.edm-state.json.tmp.*`, `**/.edm-state.lock*`, `**/*.md.tmp.*`.
2. Make `edm-init:158-161` write that full set into `<init-dir>/.gitignore` unconditionally
   (with `.edm-state.json` added only under `commit_state_file != true`), so it ships committed
   and travels correctly under an `srd_root` relocation.
3. Correct `edm-state:1057-1058`'s claim to reference the per-initiative file once it exists.

### L5-2 (P2) -- residual of CA-256 (see ledger verdict above)

### L5-3 (P2) -- CA-264, unchanged (see ledger verdict above)

## Wave-8 helper check -- clean negative

The four extracted helpers named in this round's brief create no runtime files at all:
`_unpack_token_fields` (pure jq reads into globals), `_lock_retry_or_die` (increments/dies/sleeps,
no I/O), `_measure_p95` (times commands, discards their output, writes only caller variables), and
`assert_tree_absent` (pipes both haystacks via stdin, no temp file). No new scratch paths
introduced by Wave 8.

## Fresh runtime-file inventory

23 runtime path classes traced from every mktemp/mkdir/touch/cat >/: >/write_atomic site. Three
are the findings above (rows 2, 4, 7, 20 map to L5-1/L5-2/L5-3); the rest are clean or noted. No
PID files outside a lockdir, no SQLite/.db, no __pycache__/cache/dist/build, no downloaded
artifacts, no generated secrets, no unrotated logs outside the retention-managed evals/runs/.

## Noted / Not Actionable

1. `bin/tests/timing.sh:137` -- six mktemp -d trees with no trap anywhere in the file; standing
   NOTED as CA-170/CA-171, TMPDIR-only and manual-invocation-only.
2. `evals/baseline/README.md:137` -- the documented --out baseline target is inside the work tree
   and untracked by .gitignore, but the artifacts are meant to be committed and none has ever
   been captured (D23).
3. Six traps still omit HUP (edm-lint-artifacts:141, tiering-matrix.sh:147, _harness.sh:82/110,
   harness-smoke.sh:292, wave7-smoke.sh:25) -- all TMPDIR-only, criterion 3.
4. `.gitlab-ci.yml:432` -- LIST_FILE mktemp has no trap; runner-local, out of scope.
5. `evals/run-eval.sh:186` -- CA-188 surviving sliver, keep window from ls -1t; unreachable
   without an adversarial filename.
6. `.edm-state.json.bak` never deleted -- deliberate, one file per initiative, migrate-path
   rollback rationale. Consumer-side gitignore gap filed separately as L5-1.
7. CA-169 remains correctly unapplied -- do not fix.
8. `.git/index.lock.stale.<pid>` inside .git/, never in git status, removed immediately.
9. Neither CA-256 marker-sweep line carries the shellcheck disable=SC2086 directive its six
   siblings carry -- load-bearing for L5-2's fix, cross-lens L7/L8.
10. `evals/runs/.gitignore:6-7`'s self-ignoring form verified correct.
11. `score-artifacts.sh:554`'s scores.json fallback -- not filed, --out exists and no documented
    workflow points elsewhere.

## Meta

`Write` was absent from this lens's delivered runtime tool set despite the frontmatter grant
(ledger CA-130, four rounds running). Both `lens-L5.md` and `lens-L5.jsonl` were transcribed by
the orchestrator.
