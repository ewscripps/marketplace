# Lens L8: Security & Portability -- Round 5 (full)

Scope: plugins/edm/{bin,bin/tests,evals,hooks,docs} plus repository-root .gitlab-ci.yml.

## Verification of open L8 ledger entries

| Ledger ID | Verdict | Evidence |
|---|---|---|
| CA-186 | PARTIALLY FIXED, residual narrowed | Both named residuals closed; new residual class survives -- L8-001 |
| CA-253 | FIXED as to exit code; NEW defect introduced | All five hooks converted identically, correct in isolation -- L8-002 |
| CA-251 | SUBSTANTIALLY FIXED, two residuals | absolute-git-dir, age gate, lsof-first, fixed-string ps+grep -F, refuse-when-no-oracle, mv-aside all correct -- L8-003 |
| CA-233 | TWO of three halves FIXED | `.gitlab-ci.yml:105-109` excludes both extensions; prose constraint gone -- L8-004 |
| CA-268 | Trap half FIXED, citation half RE-STALED by its own fix | L8-005 |
| CA-271 | FIXED, no residual | All extractors carry the tightened terminator |

### G3 (CA-186) character-by-character re-derivation

Most adversarial values (backslash, whitespace, embedded newline, glob metacharacters, `//`,
`/./`) are safe -- they hit an existing named diagnostic. **Not safe**: `.`, `./`, `..` all reach
a silent `exit 0` with no diagnostic on any channel. An absolute srd_root equal to the repository
root is manufactured into `.` by the fix's own relativization arm and takes the same silent path
-- and that relativization arm has zero test coverage (only non-relativizable absolutes are
exercised).

### G8 (CA-253) completeness check

All five command hooks converted identically and correctly in isolation; no other hook in the
file carries the mistake. What the conversion did NOT do is classify gate-check's failure modes
-- see L8-002.

### G6 (CA-251) fixed-string matching re-derived

`grep -F` is correctly literal for every metacharacter. Self/parent PID exclusion is correct for
its stated goal (two negligible edge directions noted, not filed). The live residual is upstream,
in candidate selection -- L8-003.

## Findings (L8: Security & Portability)

### L8-001 (P2) -- CA-186 residual: four srd_root values still fail open silently

`.`, `..`, `./`, and an absolute value equal to the repo root (converted to `.` by the fix's own
relativization) all reach `exit 0` with zero diagnostic -- a provable violation of the round-4
test's own "none of the eight shapes exits 0 silently" invariant. Independently confirmed by
L1/L2/L3.

**Fix**: refuse loudly whenever the resolved root is `.`, `..`, empty, or contains a `..`
component. Extend the test's shape list to twelve values including one exercising relativization.

### L8-002 (P1) -- CA-253's exit-2 conversion over-blocks; independently confirmed by L1/L2/L3/L7/L10

`gate-check ... || exit 2` treats every non-zero gate-check status as a refusal, but only two of
its non-zero paths actually are one: a missing state file (`read_state` dies at `edm-state:536`),
a missing jq (`require_jq` dies), and a transient lock-timeout on a legacy initiative all now
hard-block. The sibling prompt hook's own text says the opposite for the missing-state-file case
("allow expansion"). Every other hook in the file degrades to exit 0 when a dependency is
missing -- this is the outlier.

**Fix**: classify gate-check's outcome like the settled PreToolUse 1-vs-2 contract does for the
linter -- block only on a real "not approved" message, or give `cmd_gate_check` a dedicated
refusal status. Add an executing test (the static grep can't see this).

### L8-003 (P2) -- CA-251 residual: pgrep candidate selection still compiles an unvalidated ERE

Classification (the `grep -F` step) is fixed, but candidate SELECTION still passes `git_dir` to
`pgrep -f` as a regex. An invalid ERE (unbalanced `[`, trailing `\`) makes pgrep error out
silently (`2>/dev/null || true`), `_candidate_pids` stays empty -- indistinguishable from "no
processes matched" -- and the lock is removed with no liveness check having run. Reachable
wherever lsof is absent (common in Alpine/CI). The prescribed executing test also never landed.

**Fix**: distinguish pgrep's exit codes (1 = no candidates, >1 = undetermined, route to refuse);
better, drop the ERE dependency entirely via `ps -e -o pid=,args= | grep -F`. Add the backdated-
lock executing test.

### L8-004 (P2) -- CA-233 residual: shellcheck still analyzes the awk file; the constraint moved, didn't disappear

`lint:shellcheck`'s exclusion covers only `*.txt`, not `*.awk` (its sibling `lint:bash-syntax`
covers both). Separately, the in-suite twin at `wave7-smoke.sh:948-950` still excludes only
`*.awk`, so both vocabulary `.txt` files remain load-bearing bash source for the blocking
`test:smoke` job -- the warning was correctly deleted from the data file, but the underlying
fragility (surviving only by luck of content) is now undocumented too.

**Fix**: add `*.awk` to the shellcheck exclusion; add `*.txt` to the in-suite twin; add one
assertion that all three loops share the same extension set.

### L8-005 (P2) -- CA-268 residual: the fix re-staled its own citation

`edm-state:627` was corrected to cite `edm-check-grants:124` -- but the same remediation's own
3-line explanatory comment insertion pushed the trap to `:127`. Same mechanism affects the two
`_harness.sh` sibling citations in the same block. Independently confirmed by L1/L7.

**Fix**: re-point all three; adopt the by-name citation form used elsewhere so it survives future
insertions.

### L8-006 (P2) -- NEW: unpinned npm install in the one secret-bearing job

`eval:nightly` installs `@anthropic-ai/claude-code` unpinned with install scripts enabled, in the
one job carrying `ANTHROPIC_API_KEY`. CA-161's pinning sweep pinned all eleven `apk add` lines and
skipped both `npm install` lines. Compounding: the T67 AC11 no-network scan structurally exempts
`allow_failure: true` jobs, which is exactly the two jobs that reach the network.

**Fix**: pin both npm installs to an explicit version with the same refresh-procedure note the
apk pins carry; extend AC11 to a weaker pass asserting version-pinning on allow_failure jobs.

### L8-007 (P2) -- NEW: existence guard resolved against the wrong base

The CA-186 fix's new directory-existence check evaluates against the hook's cwd, while the
staged-path matcher uses repository-root-relative paths from git. They disagree whenever cwd is a
subdirectory -- enforcement silently drops with a misleading "typo" diagnostic. Second
consequence: every commit in any of the marketplace's other six plugins (which have no `SRD/`)
now emits an EDM error line where the pre-fix hook was silent.

**Fix**: resolve the existence test against `git rev-parse --show-toplevel`; refuse loudly only
when srd_root was set explicitly (an unset default not existing just means the project doesn't
use EDM).

### L8-008 (P2) -- NEW: predictable temp path truncated with symlink-following redirect

The G49 flock-timeout marker (`${lockfile}.timeout.$$`) is a predictable path in the tracked,
potentially group-writable initiative directory, created with `: > "$marker"` (follows symlinks,
truncates). A ~10-second window exists between pre-clean and write during which another local
user could plant a symlink there.

**Fix**: create with `mkdir` (atomic, fails on existing name of any kind) instead of a truncating
redirect.

## Noted / Not Actionable

1. CA-123 re-verified by fresh sweep: no fd 9/10-19 use anywhere; flock's fd 200 remains correct.
2. Both `eval` sites in edm-state and timing.sh are safe idioms (bash-quoted trap output; literal
   caller-supplied variable name).
3. PID recycling onto `$PPID` and grandparent-ancestry evasion are real but negligible directions,
   subsumed by the L8-003 fix.
4. run-eval.sh's auth probe uses default permissions but its prompt is a fixed literal with no
   injection vector; CA-086's accepted position.
5. Two developer-local absolute paths in CLAUDE.md are a licence-verification provenance record,
   not a portability defect.
6. `for p in $prefixes` unquoted but safe -- every value already passed a strict uppercase grep.
7. lsof's `--` marker may be unsupported on old builds; failure mode routes to the safe pgrep
   fallback.
8. The two mv-aside paths share `$$` predictability with L8-008 but use rename not truncating
   open -- not filed separately.
9. CA-117, CA-124, CA-111 re-verified unchanged and correctly dispositioned.
10. **CA-130 reproduces a sixth consecutive round** -- tool-set half only.

## Meta

`Write` was absent from this lens's delivered runtime tool set (ledger CA-130, sixth consecutive
round). Both `lens-L8.md` and `lens-L8.jsonl` were transcribed by the orchestrator.
