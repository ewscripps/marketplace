# Lens L7: Cross-File Consistency -- Round 5 (full round)

Scope: full plugins/edm/ tree plus repository-root .gitlab-ci.yml.

## Verification of open L7 ledger entries

| Ledger ID | Round-5 verdict | Evidence |
|---|---|---|
| CA-227 | FIXED (core), residual re-scoped as L7-007 | `.gitlab-ci.yml:119`, `:237`, `:261`/`:282` all now print job-named FAILED before exit 1; sibling set was incomplete |
| CA-228 | FIXED | `agents/edm-test-unit.md:104-105` now lists six N/A layers including integration |
| CA-268 | FIXED (trap half); citation half NOT fixed -- L7-003 | `edm-check-grants:127` now EXIT INT TERM; `edm-state:627`'s exemplar citation is stale again |
| CA-269 | FIXED | `.gitlab-ci.yml:143` now carries `| grep -v '/tests/'`, matching siblings |
| CA-270 | FIXED | `wave7-smoke.sh:317` loops over all four consumers including edm-state |
| CA-049 | STILL OPEN -- L7-001 | `_harness.sh:6-10` vs `wave3-smoke.sh:12`, `wave4a-smoke.sh:12` |
| CA-074 | STILL OPEN -- L7-002 | `edm-validate-prefix:26` vs `edm-init:22`, `score-artifacts.sh:135`, `tiering-matrix.sh:72` |

## Findings (L7: Cross-File Consistency)

### L7-001 (P2) -- CA-049 still open: two `_harness.sh` sourcing shapes and a fallback split survive

`_harness.sh:6-10`'s docstring now prescribes `source "${SCRIPT_DIR}/_harness.sh"`; wave3:12 and
wave4a:12 still re-derive the whole path chain inline. The `${BASH_SOURCE[0]:-$0}` fallback is
present at wave4b:6/wave7:10 and absent at five other suites -- the docstring's claim that it
models "the form wave7-smoke.sh actually uses" is only half true.

**Fix**: sweep wave3:12 and wave4a:12 to the documented form; pick one fallback convention and
apply it everywhere.

### L7-002 (P2) -- CA-074 still open: `die()` is three shapes across twelve scripts

Two-arg form (5 scripts), one-line echo-and-exit form (6 scripts), and a two-line no-code-arg
form (score-artifacts.sh). Two default exit codes (1 vs 2) and two prefix-derivation conventions
in the evals drivers. No smoke assertion pins any shape.

**Fix**: standardize on the two-arg form with default 2 (majority), add one smoke assertion
matching the canonical shape across bin/* and evals/*.sh.

### L7-003 (P2) -- CA-268 residual: three of four exemplar citations in the CA-159 comment are stale

`edm-state:627`'s comment block cites `edm-check-grants:124` (CA-268's fix moved the trap to
`:127` when inserting its explanatory comment, re-staling the citation CA-268 was filed to
correct), `_harness.sh:104` (means `:110`), `_harness.sh:76` (means `:81-82`). Only
`edm-lint-artifacts:141` still resolves.

**Fix**: re-point all three; prefer the by-name form CA-095 adopted elsewhere.

### L7-004 (P2) -- NEW: G8/CA-253's exit-2 conversion activated a latent hook disagreement

All five UserPromptExpansion command hooks now `gate-check ... || exit 2` -- on a prefix with no
state file, `read_state` dies, so the hook BLOCKS. Every prompt half's step 5 says the opposite:
"If approved (or if the state file does not exist -- first invocation), allow expansion." At the
old exit 1 (non-blocking) this divergence was inert; at exit 2 it's live and the two enforcement
layers for the same condition disagree.

**Fix**: pick one direction for both halves. If blocking is correct, delete the first-invocation
allowance from the five prompt bodies. If allowing is correct, guard the command half the way the
PreToolUse hook already does for "no resolvable state" (`resolve-dir ... || exit 0`). Add a test
asserting the two halves agree on a never-init'd prefix.

### L7-005 (P2) -- NEW: `timing.sh --all-lint` wasn't converted to `_measure_p95`

Nine of ten measurement sites route through the new helper; `--all-lint` at :328-331 kept the
inline variant and reports `duration_ms=` instead of `p95_ms=`. The extraction's header at :72-74
falsely claims universal coverage.

**Fix**: route `--all-lint` through `_measure_p95 1 ms -- ...` like `--phase-complete` does; narrow
the header claim.

### L7-006 (P2) -- NEW: one `assert_absent_with_control` call site survived the G2/CA-037 sweep

`wave7-smoke.sh:185` still uses the older helper (with a real, non-tautological control), but keeps
the swallowed-exit-code haystack and no scan-target-existence assertion that the newer
`assert_tree_absent` provides.

**Fix**: convert to `assert_tree_absent`; note the older helper now has zero production callers.

### L7-007 (P2) -- CA-227 residual at a new sibling set

Three jobs (`lint:artifacts`, `lint:grants`, `lint:vocabulary`) invoke a binary directly with no
shell wrapper, so a failure prints no job-named string at all. `validate:plugin-cli` says "FAIL"
where `validate:manifest` says "FAILED". Third consecutive round an L7 sweep stopped at the named
sites without checking the rest of the file.

**Fix**: wrap the three single-command jobs; standardize the FAIL/FAILED token; add the job name
at `eval:nightly:652`.

### L7-008 (P2) -- NEW: two stale-lock reclaimers in one file disagree on fail-safe direction

`cmd_git_lock_check` refuses to remove a lock when no liveness oracle is available (age-gated,
correct per its own stated rationale). `with_state_lock`'s invalid-pidfile reclaim path does the
opposite -- reclaims immediately with no age gate -- for the identical no-oracle situation, though
the file's comments present the two as one agreeing family.

**Fix**: add an age gate to the invalid-PID reclaim path, or document why this lock-owner case is
exempt and cross-reference it from the other site.

## Noted / Not Actionable

1. `_unpack_token_fields`, `_lock_retry_or_die`: both fully clean, no residual inline variant at
   any call site.
2. The G6/CA-251 absolute-path-plus-fixed-string pattern is correctly a one-off -- no other site
   needs command-line liveness matching.
3. The five UserPromptExpansion command hooks are byte-identical apart from the gate token; all
   pass their own token correctly (CA-229 stays closed).
4. The commit-lint hook is the only srd_root normalizer; the four bin/ consumers only construct
   filesystem paths where POSIX resolution absorbs the difference. Documented, criterion 1/3.
5. flock 10s vs mkdir ~5s acquire bounds -- already dispositioned NOTED by L3 in round 4.
6. Four `set -uo pipefail` sites each carry an in-place rationale -- documented, criterion 1.
7. HUP coverage split matches CA-268's prescribed direction and the tracked-file distinction.
8. CA-226 stays closed: identical source literal across all evals drivers and bin/ helpers.
9. Round-scoped G-numbers (G5, G43, G48) collide across rounds in operator-visible labels; comments
   mostly use the disambiguating G<N>/CA-<NNN> form. Cosmetic, no runtime consequence.
10. **CA-130 reproduced a sixth consecutive round** on this lens -- no Write delivered though the
    on-disk definition grants it.

## Meta

`Write` was absent from this lens's delivered runtime tool set despite the frontmatter grant
(ledger CA-130, sixth consecutive round). Both `lens-L7.md` and `lens-L7.jsonl` were transcribed
by the orchestrator.
