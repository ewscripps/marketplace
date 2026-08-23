# Lens L3: Edge Cases & Concurrency -- pass-8 (round 8, full)

## Prior-Round Verification

### CA-354 [P2] cmd_render_ledger -- CONFIRMED FIXED
`bin/edm-state:4197-4199` now wraps read+render+write_atomic in a single
`with_state_lock "${init_dir}/code-audit/findings-ledger" _cmd_render_ledger_body`, and the body
(`:4133-4178`) performs the jq read, the render, and `write_atomic` with no unlocked step between
them. `record_artifact_hash` at `:4212` is outside the lock, after release, as designed -- the
`:4203-4211` comment correctly states why (it takes the *state* file's lock via `rmw_state`, and
`_EDM_TRAP_DEPTH` is process-global, so a nested call would trip the reentrancy guard). The
restructure is correct. `_cmd_render_ledger_body`'s `die` calls run inside with_state_lock's body
subshell, but the caller re-dies at `:4199` (`|| die "render-ledger: failed to render/write"`), so
the failure still terminates the real process. No new defect.

### CA-355 [P2] update-patterns pre-flight -- CONFIRMED FIXED
`bin/edm-state:5080` now resolves the pre-flight through `pattern_insert_line_for` -- the same
fence-aware resolver the body uses -- instead of the old `grep -qxF`. The three outcomes are now
distinguishable: heading absent -> clean skip (`:5085-5086`, exit 0); heading present only inside a
fence -> loud refusal (`:5083`); heading resolvable -> proceed. The body re-checks under the lock
at `:5001-5003` and dies rather than recording a false zero. The refusal propagates correctly
through the command substitution at `:5096` (`|| die`), so nothing is written to
`patterns_updates`. No new defect.

### CA-396 [P2] flock-timeout marker PID -- CONFIRMED FIXED (rationale in the comment is wrong; see NOTED)
`bin/edm-state:1226` is now
`_lock_timeout_marker="${TMPDIR:-/tmp}/edm-state.lock-timeout.${BASHPID:-$$}"`. Two concurrently
live `with_state_lock` invocations necessarily occupy two distinct processes, and each computes the
marker from its own `BASHPID`, so the collision is closed for every real shape: separate
`edm-state` processes, `&`-backgrounded invocations from one parent, and `$( )`-nested invocations
(`:4368`, `:4627`, `:5096`).

**Independent judgment on the TMPDIR location (asked for explicitly):** TMPDIR placement is
correct and strictly safer than the lockbase-adjacent alternative the original finding suggested.
`mkdir` is atomic and refuses *any* pre-existing name including a planted symlink (unlike a `: >`
redirect, which follows and truncates one); the G13/CA-347 gate at `:1241` means a pre-planted
foreign marker cannot manufacture a false timeout, because the `-e` probe is only reached when the
subshell already exited 99; and on a sticky `/tmp` another user cannot delete our marker. Moving it
back beside the lockbase would reintroduce both the symlink-plant exposure and the
read-only-artifact-directory failure mode G17/CA-305 closed. Keep it where it is.

### CA-397 [P2] two durations for one timeout -- CONFIRMED FIXED, but the fix introduced two new defects
`bin/edm-state:1099-1100` establishes `EDM_STATE_LOCK_WAIT_S` (default 10) and derives
`EDM_STATE_LOCK_MAX_TRIES=$(( EDM_STATE_LOCK_WAIT_S * 10 ))`. The flock branch consumes it at
`:1229` (`flock -w "$EDM_STATE_LOCK_WAIT_S"`) and the mkdir branch through
`_lock_retry_or_die`'s `EDM_STATE_LOCK_MAX_TRIES` bound (`:1119`). One constant, both branches --
the divergence is gone. Two consequences of the fix are new findings below: **L3-2** (the new env
knob is unvalidated, unlike every sibling knob in the file) and **L3-8** (the `-w 10` -> `-w
"$EDM_STATE_LOCK_WAIT_S"` rename silently defanged the CA-169 regression guard in wave7-smoke.sh).

### CA-398 [P2] `_lock_retry_or_die` dynamic scoping -- CONFIRMED FIXED; the specific hazard flagged in the mandate is NOT present
This was the safety-critical one; I read `with_state_lock` (`:1131-1401`) in full.

`_lock_retry_or_die` (`:1116-1124`) now takes the counter as `$1`, echoes the incremented value, and
**explicitly does not call `die`** -- it `return 1`s at the terminal case (`:1119-1121`). The three
call sites (`:1323-1324`, `:1338-1339`, `:1343-1344`) each read
`tries="$(_lock_retry_or_die "$tries")" || die "state lock timeout after ..."`. The `die` is in the
caller's context, and that caller is the `until ... done` loop at `:1285-1345`, which runs directly
in `with_state_lock`'s own shell -- **not** inside a subshell. So `die`'s `exit` terminates the real
process. The failure mode the finding warned about (a `die` fired from inside the command
substitution killing only the fork, leaving the loop to spin forever with `tries` resetting to
empty-then-0 on every call) is not reachable in the current design.

I also checked the three call sites where `with_state_lock` is itself invoked inside `$( )`
(`:4368`, `:4627`, `:5096`): in those, `die` exits the command-substitution subshell, and all three
guard the result (`|| return 1`, `|| return 1`, `|| die`), so the timeout still surfaces. Verified
separately that `die`'s default exit code is 1 (`:74-78`), so a `die` from inside a locked body can
never be misread as the flock branch's 99 timeout sentinel.

---

## Findings (L3: Edge Cases & Concurrency)

### L3-1 [P1] Concurrent auto-spawned QC auditors overwrite one another's `qc/qc-summary.md`
**File:** `plugins/edm/hooks/hooks.json:117` (with `plugins/edm/skills/implement/SKILL.md:35,37,81,114`)

**Scenario.** `skills/implement/SKILL.md:35` spawns **6-10 `edm-implementer` agents in parallel per
wave**. `:37` states that the `SubagentStop` hook fires *after each implementer completes* and
auto-spawns an `edm-qc-auditor`. The hook's prompt (`hooks.json:117`, step 5) instructs every one of
those auditors, unconditionally, to *"Write the QC report to `<initiative-dir>/qc/qc-summary.md`"* --
one fixed path, full-file `Write` semantics, no shard suffix, no append, no lock, no merge step.
When two or more implementers in a wave finish close together (the normal case for a wave of
independent tickets), N auditors write the same path and the last writer wins. Step 5 of the skill
(`:114`) then *"Compile all FAIL findings from `qc/qc-summary.md`"* -- so the FAIL verdicts belonging
to every overwritten auditor are silently absent from remediation. The verdicts are never
persisted anywhere else: only PARTIALs reach state (`record-partial-verdict`, which *is* correctly
locked); PASS and FAIL live only in that markdown file.

**Why this is not covered by the existing sharding rule.** The shard mechanism at
`SKILL.md:84-99` is a *different* path: it is orchestrated by the skill, keyed on total ticket
count vs `qc_shard_threshold`, runs "after all implementer waves complete", and writes
`qc-shard-{NN}.md` followed by an explicit merge. The hook-driven per-implementer auto-spawn has
none of that. The authors clearly knew about the multi-writer collision -- they solved it for the
skill path and left the hook path exposed.

**False-alarm filter.** Not documented as single-writer anywhere (`plugins/edm/CLAUDE.md`'s hooks
table says only "write verdict to `qc/qc-summary.md`"). Not a boundary this code does not own --
the hook prompt is this plugin's own artifact. Not test-only.

**Fix.** Give the hook prompt a per-subagent unique output path and an explicit merge owner --
e.g. instruct the auto-spawned auditor to write `qc/qc-shard-<ticket-or-agent-id>.md` and have
`/edm:implement` Step 4 merge every `qc/qc-shard-*.md` into `qc-summary.md` once the wave drains
(the merge step already exists at `SKILL.md:98`). Alternatively, serialize by having the auditor
append under an `edm-state`-mediated lock. Do not leave a single fixed path written by 6-10
concurrent agents.

**Relationship to CA-411.** CA-411 (open, L7) covers the *same hook site* but frames it as a
config-consistency gap ("the auto-spawn path ignores the sharding rule the skill path honors").
This finding is a distinct defect class -- concurrent full-file overwrite causing silent verdict
loss -- and is what makes CA-411's fix load-bearing rather than cosmetic. Synthesizer: cross-link
or merge, but do not close as a duplicate at P2.

---

### L3-2 [P2] NEW, introduced by the CA-397 fix: `EDM_STATE_LOCK_WAIT_S` is unvalidated and reaches both bash arithmetic and `flock -w`
**File:** `plugins/edm/bin/edm-state:1099-1100`

```bash
EDM_STATE_LOCK_WAIT_S="${EDM_STATE_LOCK_WAIT_S:-10}"
EDM_STATE_LOCK_MAX_TRIES=$(( EDM_STATE_LOCK_WAIT_S * 10 ))
```

These run at **top level**, under `set -euo pipefail` (`:54`), so they execute on every invocation
of every subcommand -- including read-only ones -- and on every `source` of the file (which the
smoke suites do).

**Scenarios.**
- `EDM_STATE_LOCK_WAIT_S=0.5` (the obvious value for a test wanting a sub-second wait; `flock -w`
  accepts fractional seconds, so it looks legal): bash arithmetic rejects `0.5` with
  `syntax error: invalid arithmetic operator (error token is ".5")`, the assignment returns
  non-zero, `set -e` aborts. `edm-state get`, `validate`, `--help` -- everything -- dies at load
  with a raw bash error and no diagnostic.
- `EDM_STATE_LOCK_WAIT_S=abc`: `flock -w abc` fails immediately, so the `||` arm at `:1229` creates
  the timeout marker and exits 99, and the parent dies with *"state lock timeout after abcs"* --
  a fabricated lock-timeout on the **first** attempt with zero contention. Every locked mutation in
  the process fails as a bogus timeout.

**Why this is actionable rather than "user error".** The file establishes the opposite convention
twice, and documents why: `HUMAN_HOURLY_RATE_USD` is regex-validated at `:84-85`, and
`EDM_TOKEN_READ_LINE_CAP` at `:393-394`, both under the CA-160 rule *"validate right next to where
the default is established -- a non-numeric value reaches [the sink] and aborts with a raw,
user-hostile error."* The comment at `:1097` explicitly advertises this knob for testing
("Override via env for testing"), yet no test sets it (grep of `bin/tests/` returns nothing), so
the first person to use it as documented hits this.

**Fix.** Add the sibling guard immediately after `:1099`:
`[[ "$EDM_STATE_LOCK_WAIT_S" =~ ^[1-9][0-9]*$ ]] || die "invalid EDM_STATE_LOCK_WAIT_S: '...' (expected a positive whole number of seconds)"`.
Positive-integer-only is the right constraint given the `* 10` derivation; if fractional waits are
wanted later, derive `MAX_TRIES` with awk instead of `$(( ))`.

---

### L3-3 [P2] NEW: `.audit_rounds.code.count` read without `coerce_round_entry` -- jq hard-errors on the documented legacy bare-integer shape
**File:** `plugins/edm/bin/edm-state:2212` (and the twin at `:3016`)

```bash
p2_debt_round="$(echo "$state_json" | jq -r '.audit_rounds.code.count // 0')"
```

`plugins/edm/CLAUDE.md`'s state-field table states the C-4 contract verbatim:
*"`audit_rounds.<type>` may still be a bare integer in a file written before the `{count, rounds:
[...]}` widening; **every reader coerces via `coerce_round_entry`** and no existing file is
rewritten."* These two readers -- both added by the freshly landed T-EDMV4 accept-p2-debt work
(dc8a24f) -- do not. Every other reader in the file does (`:4232`, `:4240`, `:4308`, `:4457`).

**Scenario.** A legacy initiative whose `audit_rounds.code` is still the bare integer `3`.
`jq '.audit_rounds.code.count'` raises `Cannot index number with "count"` -- `// 0` does not catch
it, because `//` handles null/false, not an evaluation error. Reachability is confirmed:
`cmd_audit_converged` (`:4457`) *does* coerce, so a legacy file coerces to `rounds: []`, takes the
warn-and-proceed arm at `:4476`, computes the blocking set, and returns exit 1 with the
`"not converged: "` prefix -- exactly the two conditions the `--accept-p2-debt` branch at `:2178`
requires. Line 2212 then runs as a bare statement inside an `if` body under `set -e`, so
`edm-state approve-gate <PREFIX> code-audit --accept-p2-debt` aborts with a raw jq error and jq's
exit code. Fails closed (nothing is written), but the documented convergence path is unusable on a
documented-supported input, with an error that names neither the command nor the cause.

**Fix.** Splice `${AUDIT_ROUND_COERCE_JQ_DEF}` into both filters, exactly as `:4457` does:
`jq -r "${AUDIT_ROUND_COERCE_JQ_DEF} (.audit_rounds.code // 0 | coerce_round_entry).count"`.
Consider a shared `_audit_round_count <state-json> <type>` helper so the fourth reader cannot
diverge again.

---

### L3-4 [P2] NEW: jq-derived debt round reaches a bash arithmetic context without `to_int`
**File:** `plugins/edm/bin/edm-state:3015-3017`

```bash
debt_round_at_accept="$(echo "$state_json" | jq -r '.code_audit_p2_debt_round // -1')"
debt_round_now="$(echo "$state_json" | jq -r '.audit_rounds.code.count // 0')"
if [[ "$debt_round_at_accept" -eq "$debt_round_now" ]] ...
```

`to_int` (`:109-114`) exists precisely for this, and its docstring is unambiguous: *"Every value
from any external source -- state file, environment, or command line -- that reaches an arithmetic
context MUST pass through here first (CA-157: this is not only a `.edm-state.json` concern)"*,
with the confirmed bash-3.2.57 reproduction showing `[[ "$x" -ge 1 ]]` executing a command
substitution embedded in an array subscript. `.edm-state.json` is a committed, shared artifact that
arrives from git, a merge conflict, or a hand edit without passing through `cmd_set`. Neither of
these two values is coerced.

**Scenario.** `code_audit_p2_debt_round` set to a non-integer string in a state file (hand edit,
merge artifact, or a state file authored elsewhere). At minimum, `edm-state archive` aborts on the
arithmetic; at worst, the value is evaluated. Same class as the sites CA-157 already closed.

**Fix.** `debt_round_at_accept="$(to_int "$(echo "$state_json" | jq -r '.code_audit_p2_debt_round // -1')" -1)"`
and the equivalent for `debt_round_now` (after the L3-3 coercion fix). Also worth a targeted grep
for any other post-CA-157 jq-to-arithmetic sites added by T-EDMV4.

---

### L3-5 [P2] NEW: `migrate-path` rollback leaks a live lockdir into the restored source directory
**File:** `plugins/edm/bin/edm-state:3531-3539` (`_cmd_migrate_path_rollback_body`), invoked from `:3601`

```bash
with_state_lock "${dst}/.edm-state" _cmd_migrate_path_rollback_body "$dst" "$src" "${SRD_ROOT}/${product}"
```

**Scenario (mkdir-fallback branch -- macOS, the project's primary dev platform).**
`with_state_lock` creates `${dst}/.edm-state.lockd` **before** dispatching the body. The body then
`git_aware_mv`s `$dst` back to `$src`, carrying `.edm-state.lockd` (and its pidfile) along to
`${src}/.edm-state.lockd`. On return, `with_state_lock`'s unconditional cleanup at `:1397`
(`rm -rf "$lockdir"`) and its EXIT trap at `:1367` both target `${dst}/.edm-state.lockd`, which no
longer exists -- so the removal silently succeeds against nothing and the lockdir is left behind in
the restored initiative directory, containing a now-dead PID.

The next `with_state_lock` on that initiative spins in the `until mkdir` loop, finds the pidfile,
`kill -0` fails, waits out the 1-second age gate, and reclaims it -- printing
`"reclaimed stale state lock ... (PID N no longer running)"`. Self-healing, but it costs retry
iterations and emits an alarming diagnostic for what was a clean rollback.

**Why this is a real asymmetry, not a nitpick.** Both *forward* movers handle exactly this:
`_cmd_archive_move_body:3082` sweeps `"${_dst_lockbase}.lockd"` and `.lock` at the destination, and
`_cmd_migrate_path_move_body:3511` sweeps `"${_dst_lockbase}.lockd"`, each with a comment
explaining that the lock names travel with `git_aware_mv`. The rollback body -- added by
G16/CA-304 specifically to bring the rollback into line with the forward move -- omits the sweep.

**Fix.** Add the mirror sweep at the end of `_cmd_migrate_path_rollback_body`:
`rm -rf "${_src}/.edm-state.lockd"` (leave `.lock` alone -- `$src` becomes the live home again, so
CA-169's never-unlink-the-flock-file default applies here exactly as G16/CA-304 argued for the
forward path at `:3492-3501`).

---

### L3-6 [P2] NEW: `EDM_EVAL_KEEP_RUNS=0` deletes the run that just finished, and CI then reports green with no eval at all
**File:** `plugins/edm/evals/run-eval.sh:180-206` (with `.gitlab-ci.yml:722-742`)

```bash
local keep="${EDM_EVAL_KEEP_RUNS:-10}"
case "$keep" in ''|*[!0-9]*) keep=10 ;; esac
...
[ "$run_total" -gt "$keep" ] || return 0
stale_dirs="$(printf '%s\n' "$run_dirs" | tail -n "+$((keep + 1))")"
```

**Scenario.** `EDM_EVAL_KEEP_RUNS=0` passes the validator (`0` contains no non-digit), so
`keep=0`, `tail -n +1` selects **every** run-shaped directory including the one this invocation
just wrote, and `prune_old_runs` -- called from the EXIT trap at `:256`, after `$RUN_DIR` is fully
populated -- `rm -rf`s it. The function's own header comment at `:162-163` asserts the opposite
("The run directory currently being investigated is always the newest by mtime, so it is never
eligible for pruning"), which is true for `keep >= 1` and false at exactly `keep = 0`.

**Downstream silent pass.** `.gitlab-ci.yml:723` and `:733` both do
`RUN_DIR="$(ls -td plugins/edm/evals/runs/*/ | head -1)"` guarded by `if [ -n "$RUN_DIR" ]`. With
the directory gone, both guards are false, scoring and the baseline comparison are skipped with no
message, and `eval:nightly` reports success having evaluated nothing.

**Fix.** Reject 0 in the same `case`: `''|0|*[!0-9]*) keep=10 ;;`, or clamp with
`[ "$keep" -lt 1 ] && keep=1`. Also add `[ "$stale" = "$RUN_ID" ] && continue` inside the prune
loop so the current run is structurally un-prunable rather than un-prunable by arithmetic accident.

---

### L3-7 [P2] NEW: `EDM_EVAL_PHASE_TIMEOUT_SECONDS` is unvalidated, and a non-numeric value disables the phase timeout entirely
**File:** `plugins/edm/evals/run-eval.sh:292-313` (`run_with_timeout`), knob at `:395`

```bash
while kill -0 "$pid" 2>/dev/null; do
  if [ "$waited" -ge "$seconds" ]; then ... return 124; fi
  sleep 1; waited=$((waited + 1))
done
```

This driver deliberately runs **without `set -e`** (`:57-63`: *"-e is intentionally omitted"*), so a
`[` that fails with `integer expression expected` returns 2 and is simply treated as false by the
`if`. With a non-numeric `EDM_EVAL_PHASE_TIMEOUT_SECONDS`, the timeout branch is **never** taken:
the loop polls forever and the `claude -p` child runs unbounded. This is the "network call with no
timeout set" shape -- reintroduced through an unvalidated knob into the one function G45 built
specifically to guarantee every model call is bounded (`:326-331`). The only backstop left is
GitLab's `timeout: 150m`, and on a local run there is no backstop at all.

**Fix.** Validate at `:395` alongside the default, matching `edm-state`'s CA-160 convention:
`[[ "$PHASE_TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]] || die "invalid EDM_EVAL_PHASE_TIMEOUT_SECONDS ..."`.
Do the same for `EDM_EVAL_MAX_BUDGET_USD` at `:396` while in the file.

---

### L3-8 [P2] NEW, introduced by the CA-397 fix: the CA-169 inode-safety regression guard now passes vacuously
**File:** `plugins/edm/bin/tests/wave7-smoke.sh:4904-4912`

```bash
t_g53_flock_line="$(awk '/^    \( flock -w 10 200/{print NR; exit}' "$EDM_STATE")"
t_g53_ca169_line="$(awk '/# CA-169: never `rm -f/{print NR; exit}' "$EDM_STATE")"
t_g53_before_flock="$(sed -n "${t_g53_ca169_line:-1},${t_g53_flock_line:-1}p" "$EDM_STATE")"
```

The CA-397 fix rewrote `bin/edm-state:1229` from `( flock -w 10 200 ...` to
`( flock -w "$EDM_STATE_LOCK_WAIT_S" 200 ...`. The awk anchor no longer matches, so
`t_g53_flock_line` is empty, `${...:-1}` substitutes `1`, and `sed -n "1175,1p"` (addr2 below
addr1) emits only the single line matched by addr1 -- the CA-169 comment line itself.

All three assertions still **pass**, vacuously: the extracted single line contains `CA-169`, it
contains `never`, and it does not contain the literal `rm -f "${lockfile}"` (the comment writes it
without braces, as `rm -f "$lockfile"`). So the guard that exists to stop a future round from
"cleaning up" the deliberately-never-unlinked flock file -- the file whose unlinking breaks
inode-keyed mutual exclusion outright -- is now inspecting one line instead of a ~55-line range and
can no longer fail. Note that G38/CA-314 already fixed this same assertion once for the same
reason (a fragile anchor), and the fix chosen then re-broke on the next edit to the anchored line.

**Fix.** Anchor on something that does not encode the timeout value:
`awk '/^    \( flock -w /{print NR; exit}'`. Additionally make the extraction fail loudly rather
than silently degrade -- replace `${t_g53_flock_line:-1}` with an explicit
`[[ -n "$t_g53_flock_line" ]] || fail "G53 -- could not locate the flock() call; anchor is stale"`,
so the third occurrence of this class reports instead of passing.

---

### L3-9 [P2] NEW: a space in a recorded artifact path silently disables drift detection for that artifact
**File:** `plugins/edm/bin/edm-state:2527-2532`

```bash
hashes="$(... '"\(.key) \(.value.hash) \(.value.path) \(.value.recorded_at)"' ...)"
while IFS=' ' read -r artifact_name stored_hash file_path recorded_at; do
  current_hash="$(artifact_hash "$file_path")"
  if [[ "$current_hash" != "$stored_hash" && "$current_hash" != "absent" && ... ]]; then
```

Fields are packed into one space-delimited line and split by `read`. A recorded `path` containing a
space (reachable: `srd_root` comes from `EDM_SRD_ROOT`/`user_config.srd_root`, and this file's own
G15/CA-256 comment at `:3084-3086` states plainly that *"srd_root and product_name are not
charset-validated against spaces"*) truncates `file_path` at the first space. `artifact_hash`
(`:170-182`) returns the literal `"absent"` for a non-existent path, and the `!= "absent"` guard
then skips the comparison entirely.

**Consequence.** No warning, no error -- `checkpoint-if-active` simply stops detecting SRD and
ticket-pack drift for that initiative. Drift detection is the mechanism that tells a user to
re-run `/edm:audit-srd` and re-approve Gate 2 after an out-of-band edit, so this is a safety check
failing silently open, not a cosmetic parse bug.

**Fix.** Emit the four fields as `-c` JSON per line and read each with jq inside the loop, or put
`path` last and read it with `read -r artifact_name stored_hash recorded_at file_path` so the
whitespace-bearing field absorbs the remainder. Whichever is chosen, make an unresolvable
`file_path` warn rather than fall through the `absent` arm.

---

### L3-10 [P2] NEW: INT/TERM/HUP trap cleans up and *resumes*, producing a false "out of sync" verdict
**File:** `plugins/edm/bin/edm-sync-canonical-sections:84`

```bash
tmp="$(mktemp "${DST}.tmp.XXXXXX")"
trap 'rm -f "$tmp"' EXIT INT TERM HUP
```

One trap body for all four signals, with no `exit` on the three real signals. `bin/edm-state`'s
CA-143 comment (`:667-671`) states the required contract for exactly this shape: *"INT/TERM/HUP
must actually terminate the process after cleanup -- a trap that only cleans up and returns lets
the interrupted caller resume."* This file is under `set -euo pipefail` (`:39`) but that does not
help: the trap returns cleanly, so execution resumes at the interrupted statement.

**Scenarios.**
- `--check` mode (the mode CI runs): Ctrl-C during the `{ ... } > "$tmp"` block at `:86-99` deletes
  `$tmp`, execution resumes into `diff -u "$DST" "$tmp"` at `:102`, diff fails on the missing
  operand, the `! diff` test is true, and the script reports
  *"docs/canonical-sections.md is out of sync with CLAUDE.md"* and exits 1 -- a fabricated drift
  verdict for what was a user interrupt.
- Write mode: `mv -f "$tmp" "$DST"` at `:112` fails on the deleted temp file, exiting non-zero with
  a raw `mv` error instead of a signal-shaped 130/143/129.

**Fix.** Split the traps the way `write_atomic` and `with_state_lock` already do:
```bash
trap 'rm -f "$tmp"' EXIT
trap 'rm -f "$tmp"; exit 130' INT
trap 'rm -f "$tmp"; exit 143' TERM
trap 'rm -f "$tmp"; exit 129' HUP
```
Same shape applies to `bin/edm-lint-artifacts:141` and `bin/edm-check-grants:127`, though both are
read-only so the consequence there is a wrong exit code rather than a wrong verdict -- see NOTED.

---

## Noted / Not Actionable

- **CA-354, CA-355, CA-396, CA-397, CA-398 -- all five verified fixed against current code**
  (evidence and line citations in the Verification section above). CA-397 and the CA-397-adjacent
  test anchor produced two genuinely new defects, reported as L3-2 and L3-8; the fixes themselves
  are correct.
- **The CA-396 comment's stated mechanism is wrong, though the fix works.** `:1216-1220` claims
  *"BASHPID is this subshell's own, real PID"*, but `_lock_timeout_marker` is assigned at `:1226`,
  in the parent shell, **before** the `( )` fork at `:1229` -- so `BASHPID` there is the *calling*
  shell's PID, not the locked body's. Uniqueness still holds (two concurrent invocations are two
  processes), so this is a docs-accuracy issue rather than a live defect. Worth correcting only
  because a future contributor trusting the comment might move the assignment inside the subshell,
  where the parent's `-e` probe at `:1242` would then never see the marker.
- **The TMPDIR timeout marker leaks one empty directory on SIGKILL.** If the process is `kill -9`'d
  between the `mkdir` at `:1229` and the parent's `rm -rf` at `:1243`, the marker survives in
  TMPDIR; no sweep covers TMPDIR (the archive/migrate sweeps target the pre-G17 in-initiative
  shape). Bounded to one empty directory per killed timeout, reclaimed by the `rm -rf` at `:1227`
  on the next run that draws the same PID, and harmless because the `_lock_ec -eq 99` gate means a
  stale marker cannot manufacture a false timeout. Below the reporting bar.
- **The mkdir branch's effective timeout still slightly exceeds `EDM_STATE_LOCK_WAIT_S`.** Each
  iteration costs 0.1s of sleep plus real work (mkdir, cat, `kill -0`, `date`, and now a fork for
  the `$( )` around `_lock_retry_or_die`), so 100 iterations land somewhere above 10s while the
  flock branch's `-w 10` is exact. Nominal parity is what CA-397 asked for and got; sub-second
  wall-clock parity between two structurally different backends is not achievable and not worth
  chasing.
- **`eval:nightly`'s outer timeout is larger than the inner budget, but the margin is thin and
  undocumented.** `.gitlab-ci.yml:699` sets `timeout: 150m`; worst-case inner is 3 phases x 2700s
  (135m) + the 60s auth probe + `npm install -g` in `before_script` + scoring + baseline compare
  ~= 140m. Correct direction (outer > inner), so not a finding -- but the ~10m of slack is nowhere
  stated, and adding a fourth phase or raising `EDM_EVAL_PHASE_TIMEOUT_SECONDS` silently inverts
  the relationship. Worth one comment beside `timeout: 150m` recording the arithmetic.
- **`approve-gate --accept-p2-debt` has an unlocked read-to-write window, closed downstream.**
  `state_json` (`:2122`), `cmd_audit_converged` (`:2168`) and `_audit_ledger_breakdown` (`:2181`)
  all read unlocked; only the `rmw_state` at `:2213` is locked. A concurrent synthesizer could
  append a P0 between the check and the write. Not actionable: `cmd_archive` independently
  re-verifies P0/P1 at `:3021` and refuses if a newer round completed since acceptance, which is
  the documented staleness guard for exactly this window (`plugins/edm/CLAUDE.md`, "Sanctioned
  exception -- P2 debt acceptance"). A stale `code_audit_p2_debt_round` also fails *closed* at
  `:3017`. Gate approval is a deliberate human action, not something raced against an audit round.
- **`edm-lint-artifacts:141` and `edm-check-grants:127` share L3-10's trap shape but not its
  consequence.** Both are read-only scanners; resuming after an interrupt yields a wrong exit code
  and a possibly-truncated scan, never a corrupted artifact or a false verdict on committed state.
  Fix them in the same pass as L3-10 for consistency; not independently actionable.
- **`bin/tests/_harness.sh:113` interpolates a `local $dir` into a trap body that can outlive the
  function.** Test-only code path (False Alarm Filter #3), and `:142` clears the trap on the normal
  return path.
- **`wave7-smoke.sh:5806`'s comment still names the pre-CA-396 marker shape**
  (`"${TMPDIR:-/tmp}/edm-state.lock-timeout.$$"`). Comment-only staleness inside a test that
  deliberately exercises the *legacy* marker name; no assertion depends on it.
- **`cmd_git_lock_check` handles negative ages safely.** `_git_lock_age_seconds` (`:3845-3850`) can
  return a negative value under clock skew or a future mtime; every consumer gates with `>=`
  (`:3904`, `:4003`, `:1315`), so skew fails toward "refuse to reclaim". Correct direction,
  no change needed.
- **`run_with_timeout`'s `kill -0` poll is not vulnerable to the zombie-spin failure.** Bash reaps
  background children asynchronously and retains the status for `wait`, so `kill -0` starts failing
  once the child exits. The idiom is sound.
