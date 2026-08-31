# Lens L3: Edge Cases & Concurrency -- Round 11 (full)

**Runtime caveat (CA-130's class, recurrence #9):** this lens was delivered `Read`/`Grep`/`Glob` only --
**neither `Write` nor `Bash`**. Consequences: (i) this report and the JSONL are returned inline for the
orchestrator to persist; (ii) no `git log`/`git diff` over `0b2f304`, so every FIXED verdict below is
derived from reading source at HEAD, not from the fix commit's diff; (iii) `bin/tests/run-all.sh` was not
run, so no finding is reproduced dynamically -- every trigger is asserted from bash/git semantics.
CA-130 keeps its do-not-re-file disposition; recorded here as a recurrence and a confidence qualifier.

**Round 11 in one line for this lens: 7 of 8 open L3 ledger entries are FIXED, 1 (CA-521) was closed by
its documentation route rather than its code route, and 3 new P2s are filed -- all three residuals of
round 10's own remediations.**

---

## Part 1 -- verdicts on every open L3 ledger entry

| Ledger ID | Sev | Verdict | Evidence at HEAD |
|---|---|---|---|
| **CA-479** | P2 | **FIXED, clean** | `bin/edm-state:4638-4651`: candidates collected into `_pass_cands`, `-gt 1` emits `CA-479` naming **all** matches (`:4643`), selection by mtime (`:4645`). Durability landed: `bin/tests/wave6-smoke.sh:885-915` seeds two `pass-1_*` dirs, asserts the warning names both, and asserts `round_type` stays `full` because mtime picked the fully-backed copy. |
| **CA-480** | P2 | **FIXED, clean** | The `-f "$pidfile"` guard is gone: `:1422` reads the pidfile unconditionally (`cat ... || true`) so a **missing** pidfile now takes the same age-gated reclaim path an empty/invalid one takes (`:1423-1453`). The `|| true` on the pidfile write is gone: `:1483-1486` removes the lockdir and `die`s. Reclaim is atomic via `_edm_reclaim_stale_lockdir` (`:1193-1200`). Tests at `wave7-smoke.sh:6035-6062`. Round 10's N1 (untrapped `mkdir`-to-trap window, `:1407` to `:1507`) is resolved **as a consequence**: a crash in that window now leaves a pidfile-less lockdir, which self-heals after 1s. |
| **CA-515** | P1 | **FIXED, clean** | `skills/implement/SKILL.md:107` and `:111` key the pass shard on wave **and** ordinal (`qc-shard-pass-w{wave_num:02d}-{i+1:02d}.md`); cardinality is now stated once and consistently (`:97` "runs once per wave, not once per initiative", `:103` pseudo-code header, `:39`/`:120-122` merge re-run after every wave). `:112-119` records why. Durability at `wave7-smoke.sh:9390-9403`, including a positive control that strips the wave component. |
| **CA-521** | P2 | **NOT fixed in code -- closed by the documented-gap route; recommend re-disposition to NOTED** | The index-vs-worktree divergence is unchanged (`bin/edm-lint-staged-artifacts:124` `diff --cached` selects prefixes, `:149` delegates to `edm-lint-artifacts`, which finds the worktree). What landed is the round-10 fix's stated minimum: the gap is spelled out in the script's own EDM-HELP (`:25-31`), in `plugins/edm/CLAUDE.md`'s hooks-behavior row, and it is now **test-pinned with a positive control** at `wave7-smoke.sh:7314-7368` -- the staged-and-left case asserts exit 2, the staged-then-fixed-unstaged case asserts exit 0 today, with an inline instruction to flip the assertion when the full fix lands. That satisfies False Alarm Filter clause 1 (documented as acceptable, with the CI `lint:artifacts --all` job named as the enforcement of record). No new L3 finding; see NOTED N1. |
| **CA-481** | P2 | **(a) FIXED, (b) FIXED, (c) LANDED BUT INCOMPLETE -- see finding 2** | (a) `evals/tiering-matrix.sh:158-161` is the four-arm split with HUP present and RETURN sharing the EXIT arm. (b) `evals/score-artifacts.sh:766-769` arms a first-stage four-arm trap on `$_CMP_TA` immediately after the first `mktemp` at `:758`, replaced by the two-file layer at `:771-774`. (c) The cross-file sweep exists at `wave7-smoke.sh:9624-9699` with two positive controls -- but it pins two of the convention's three clauses and is structurally blind to one trap shape that is live in the tree. Filed as finding 2. |
| **CA-482** | P2 | **FIXED, all six sites** | `bin/edm-lint-artifacts:153-156`; `bin/tests/_harness.sh:85`, `:120`; `bin/tests/harness-smoke.sh:264`; `bin/tests/wave6-smoke.sh:37-40`; `bin/tests/wave7-smoke.sh:25`. Every site is now EXIT cleanup-only plus INT/TERM/HUP exiting 130/143/129. |
| **CA-511** | P2 | **FIXED in the enforcement half -- one residual, see finding 1** | `evals/run-eval.sh:443-459` reads `CI_JOB_TIMEOUT`, computes the worst case at `:452`, and `exit 2`s with both numbers named at `:454`. Boundary is correct (`-ge`, refuses on equality). Tests at `wave7-smoke.sh:8961-8995` including the 2700/9000 proceed case and CA-444's own 3600/9000 refuse case. Residual: the phase multiplier is a hardcoded `3`. |
| **CA-522** | P2 | **FIXED, clean** | `bin/edm-state:3392-3393` resolves HEAD once into `head_now`; `:3395` uses it as the range end; `:3419` advances the cursor to the same value; `:3406` re-anchors to it on the history-rewrite path. Tests at `wave7-smoke.sh:8706-8715` count `rev-parse HEAD` occurrences in `cmd_watch_impl` and assert exactly 1. |

---

## Part 2 -- Findings

### 1. [P2] CA-511's guard hardcodes the phase count, so adding a fourth eval phase silently re-inverts the timeout nesting with a green suite

**Files:** `plugins/edm/evals/run-eval.sh:452` (with `:542`, `:575`, `:613`); `plugins/edm/bin/tests/wave7-smoke.sh:8975-8976`

```bash
inner_worst_case_secs=$((PHASE_TIMEOUT_SECONDS * 3 + 60))
```

The `3` is a literal. The driver's actual phase count is the number of `invoke_claude` calls -- three
today, at `:542` (`plan`), `:575` (`srd`), `:613` (`audit-srd`) -- and nothing couples the two. The
durability pin makes this worse rather than better: `wave7-smoke.sh:8975-8976` asserts the **literal
source string** `inner_worst_case_secs=$((PHASE_TIMEOUT_SECONDS * 3 + 60))` is present, and `:8982-8986`
re-implements the same formula with its own hardcoded `* 3`.

**Triggering scenario.** A contributor adds a fourth phase (`invoke_claude tickets ...`) -- exactly the
change `.gitlab-ci.yml:778-780` warns about in prose ("Adding a fourth phase ... inverts the nesting --
raise this timeout in the same change"). The guard's worst case still reads 8160s against
`CI_JOB_TIMEOUT=9000`, so it proceeds; the real worst case is 10860s. GitLab kills the job at 150m
(`.gitlab-ci.yml:781`) and the trailing `script:` steps never run -- scoring, `edm-compare-eval`, and
CA-452's partial-run-always-fails-the-job handshake are all bypassed **precisely when the run was
partial**, which is the one case that handshake exists for. Both wave7 assertions stay green, because
neither reads the phase count.

This is the identical shape CA-511 was filed for, reachable through one plausible edit, and the fix's own
test is the thing that certifies the stale constant.

**Fix.** Derive the multiplier instead of writing it: count the phases from a single enumerable source
(e.g. a `EVAL_PHASES="plan srd audit-srd"` constant that both the invocation sites and the arithmetic
read), and change the wave7 case from a literal-string grep to a computed assertion -- `grep -c
'^\s*if invoke_claude\|^\s*invoke_claude ' evals/run-eval.sh` must equal the multiplier the guard uses.
Positive control: add a stub fourth `invoke_claude` line in a scratch copy and confirm the assertion
turns red.

---

### 2. [P2] CA-481(c)'s new cross-file sweep pins two of the convention's three clauses and is blind to unquoted trap handlers -- a shape live in the tree today

**File:** `plugins/edm/bin/tests/wave7-smoke.sh:9636-9682` (with `bin/tests/wave6-smoke.sh:37`)

The sweep that finally landed asserts (1) no single `trap` statement combines EXIT with a real signal,
and (2) every file installing an EXIT cleanup trap also installs a HUP trap. The convention it
is pinning has a **third** clause, stated file-wide at `bin/edm-state:687-691` and plugin-wide at
`bin/edm-check-grants`' sibling comment block: *INT/TERM/HUP must actually terminate the process after
cleanup*. Three concrete blind spots:

**(a) The cleanup-then-resume bug itself still passes.** Split across two statements --

```bash
trap 'rm -rf "$scratch"' EXIT
trap 'rm -rf "$scratch"' INT TERM HUP     # no exit
```

-- clause 1 does not fire (no single statement combines EXIT with a real signal) and clause 2 does not
fire (the file traps HUP). This is exactly the CA-446 shape: Ctrl-C deletes the scratch tree and the
suite **resumes** running assertions against a tree that no longer exists. The awk program never
inspects the trap *body* for `exit`.

**(b) An unquoted handler is invisible to both clauses.** `:9643-9648` derives the signal list as the
text after the **last quote character** on the line. For `trap cleanup_wave6 EXIT` there is no quote, so
`nq == 1`, `ndq == 1`, `sig` stays empty, and `has_exit` is false -- the line is neither flagged as
combined nor recorded in `file_has_exit`, so the file is exempt from the HUP check too. **This shape is
live at `bin/tests/wave6-smoke.sh:37`**, the one site whose history (CA-216, then CA-482) is the reason
the sweep exists. wave6 is correct today only because `:38-40` happen to be quoted; delete those three
lines and the sweep stays green on a suite that restores a **tracked** file from backup.

**(c) Clause 2 is per-file, not per-resource.** A file with two cleanup resources where only one is
HUP-covered passes, because `file_has_hup[FILENAME]` is set by any HUP trap anywhere in the file.

The positive controls at `:9686-9698` are honest but only exercise the two shapes the checks already
detect, so they cannot reveal any of the above.

**Severity rationale.** P2, not P1: no live violation exists at HEAD -- all eight sites CA-481/CA-482
named are now canonical. This is a durability gap, and CA-481(c) is on record as the reason the class
survived four rounds. Filed under L3 rather than L4 because signal-handling on partial cleanup is this
lens's own class and CA-481(c) is an L3 entry.

**Fix.** Extend `_ca481_sweep` with a third mode: for every trap statement naming INT, TERM or HUP,
require the body to contain `exit` (allowing an indirected handler only when the named function itself
contains `exit`), and make the handler parser tolerate an unquoted first word by taking the signal list
as the trailing whitespace-separated tokens that match a known signal name instead of "everything after
the last quote". Add a positive control per shape: a two-statement `EXIT` + `INT TERM HUP`-without-exit
file, and a `trap cleanup EXIT`-only file with no HUP.

---

### 3. [P2] `edm-init` has no unwind for a partial scaffold, and its own existence guard then blocks the retry with a diagnostic that cannot work

**File:** `plugins/edm/bin/edm-init:125-127`, `:130-159`, `:165` (with `:16`)

`edm-init` runs `set -euo pipefail` (`:16`) and installs **no trap** anywhere. Its scaffold is a
multi-step, non-atomic sequence: `mkdir -p "$DIR"` (`:130`), `mkdir -p "$DIR/explorers"` (`:133`), a
heredoc into `decisions.md` (`:134-144`), a mode-dependent `mkdir -p "$DIR/code-audit"` (`:146-159`),
then `edm-state init "$PREFIX"` (`:165`), then the `.gitignore` write (`:175-189`), then branch creation
(`:191+`).

**Triggering scenario.** `edm-state init` at `:165` fails -- `jq` absent (`require_jq` `die`s), a state
lock timeout (`with_state_lock` `die`s after `EDM_STATE_LOCK_WAIT_S`), an out-of-band mutator return, a
read-only or full filesystem, or a Ctrl-C. Under `set -e` with no trap, `edm-init` aborts having already
created `$DIR`, `$DIR/explorers`, `$DIR/decisions.md` and (in three of five modes) `$DIR/code-audit`,
and having written **no state file** and no `.gitignore`. Re-running the identical command now hits
`if [[ -d "$DIR" ]]` at `:125` and dies with `initiative directory already exists at $DIR (run
'edm-state get $PREFIX' to inspect)` -- and that hint cannot work, because the state file the guard
implies exists was never written, so `edm-state get` fails too. The operator's only route out is a
manual `rm -rf` of a directory the tool created and refuses to acknowledge as its own leftover.

The signal case is the sharper one: a Ctrl-C anywhere between `:130` and `:189` produces the same wedge
with no diagnostic at all.

**Severity rationale.** P2: recoverable by hand, no data loss (the scaffold is template content), and it
requires a failure or signal mid-scaffold. Filed rather than noted because the recovery path is
actively misleading and one trap closes it. Not the same defect as the `:125`-to-`:130` TOCTOU, which
round 10 adjudicated Not Actionable (see NOTED N2) -- this is the partial-failure axis, not the race.

**Fix.** Record the directory in a variable, install the canonical four-arm trap layer immediately after
`mkdir -p "$DIR"` at `:130` (EXIT cleanup-only, removing `$DIR` **only if this invocation created it and
has not yet reached the success point**; INT/TERM/HUP cleanup-then-`exit 130/143/129`), and clear the
disposition once `edm-state init` has returned successfully. Alternatively, if leaving the partial tree
is preferred, make `:126`'s diagnostic distinguish the two cases -- test for the state file and, when it
is absent, say the directory is an incomplete scaffold from a failed run and name the `rm -rf` that
clears it.

---

## Noted / Not Actionable

- **N1 -- CA-521 re-disposition (`bin/edm-lint-staged-artifacts:25-31`).** The code gap is unchanged, but
  the round-10 plan's own minimum bar landed at three surfaces (script EDM-HELP, `plugins/edm/CLAUDE.md`
  hooks row, and a test-pinned case with a positive control at `wave7-smoke.sh:7314-7368`), and the
  blocking `lint:artifacts --all` CI job is named as the enforcement of record. Filter clause 1 now
  applies. Recommend the synthesizer close CA-521 as accepted-and-documented rather than carrying it as
  an open P2 -- an accepted gap left in the open set is indistinguishable from an unaddressed one.
- **N2 -- `bin/edm-init:125` to `:130` (check-then-create TOCTOU).** Genuine, and adjudicated Not
  Actionable in round 10's Decisions/Non-Findings item 9 ("the guard still narrows a real TOCTOU window
  containing the unbounded `read` at `:106`"). Honoring that disposition; not re-filed. Finding 3 above
  is the partial-failure axis, deliberately scoped so it does not reopen this.
- **N3 -- `bin/edm-state:1195` (`_edm_reclaim_stale_lockdir` derives its stale-aside name from `$$`).**
  CA-396 established for this same file that `$$` does not distinguish `( )` subshells of one parent
  shell, and fixed the sibling flock-timeout marker to `BASHPID` for exactly that reason; this helper
  still uses `$$`. Safe today only because `_EDM_TRAP_DEPTH` is process-global (`:1277`), so two live
  `with_state_lock` calls cannot coexist in one process. Recorded so that if cross-lockbase nesting is
  ever made legal (the comment at `:1274-1276` contemplates it), this line is changed in the same commit.
- **N4 -- `bin/edm-state:1407` to `:1507` (untrapped lock-acquisition window).** Round 10's N1. Now
  self-healing rather than open: a crash or Ctrl-C in that window leaves a pidfile-less lockdir, which
  CA-480's hoisted, age-gated reclaim path collects after 1 second. Not filed.
- **N5 -- `bin/edm-state:4642`, `:4649` (bash 3.2 empty-array expansion in the CA-479 block).** Only
  `${#_pass_cands[@]}` is evaluated when the array can be empty; both `"${_pass_cands[*]}"` (`:4643`)
  and `"${_pass_cands[@]}"` (`:4644`) sit inside the `-gt 1` branch and `${_pass_cands[0]}` (`:4650`)
  inside the `-eq 1` branch, so the pre-4.4 `set -u` empty-array trap is not reachable. CI's
  `test:smoke-bash32` covers the zero-candidate path via every scratch initiative that completes a code
  round with no pass directory. Verified by reading; not executed this round.
- **N6 -- `bin/edm-state:4645` (mtime tie-break).** Two `pass-N_*` directories with the same mtime (a
  scripted re-run inside one second) make `-nt` false for both comparisons, so the first in glob order
  wins. Not silent -- the `CA-479` warning at `:4643` still names every candidate -- so an operator sees
  the ambiguity. Acceptable as written.
- **N7 -- CA-294 / CA-375 (lock give-up budget asymmetry) is resolved, not standing.** `:1202-1217`
  single-sources both backends from `EDM_STATE_LOCK_WAIT_S` (CA-397), with `EDM_STATE_LOCK_MAX_TRIES`
  derived and the knob validated beside its default at `:1215`. Round 10's N9 described this as still
  standing under a do-not-re-file disposition; that description is stale and should not be carried again.
- **N8 -- `bin/edm-state:4663` (`jq empty` over JSONL).** Re-verified: jq's default concatenated-value
  input mode accepts a valid multi-line JSONL file and fails a truncated final line, which is the
  intended direction for the CA-471 gate. Correct, not filed.
- **N9 -- `bin/tests/wave6-smoke.sh:885-915` covers one direction of CA-479.** The case seeds the stale
  copy as older and the fully-backed copy as newer. The inverse (newer is the partial scratch copy ->
  spurious, irreversible downgrade per CA-506) has no case. Low value: mtime selection is
  direction-symmetric, so the same code path is exercised. Recorded, not filed.
- **N10 -- `evals/run-eval.sh:443-447` (silent skip when `CI_JOB_TIMEOUT` is absent or non-numeric).**
  Correct by design outside CI (no outer timeout to invert), but on a runner predating GitLab's
  `CI_JOB_TIMEOUT` the coupling silently does not engage and nothing says so. A one-line notice on the
  skip arm would make the guard's inactivity observable. Not filed.
- **N11 -- lock artifacts under the plugin tree are covered.** `cmd_update_patterns` takes
  `with_state_lock "${pattern_file%.md}"` (`bin/edm-state:5667`), creating `.lock`/`.lockd` inside
  `plugins/edm/docs/audit-patterns/`. Checked: the repository `.gitignore` covers this at `:15`
  (`plugins/edm/docs/audit-patterns/*.lock*`) and again shape-anchored at `:35-36`. Verified clean.
- **N12 -- COVERAGE CAVEAT, CA-130's class (recurrence #9), `agents/edm-audit-edge-cases.md`.** Delivered
  without `Write` and without `Bash`. Both halves returned inline; every FIXED verdict is read-derived,
  not diff-derived; no suite figure was independently verified by this lens; finding 1's and finding 3's
  triggers are asserted from bash semantics, not observed. CA-331/CA-377's standing request -- a
  Bash-capable pass runs `bin/tests/run-all.sh` immediately before the convergence gate -- is
  outstanding for a seventh round.
- **N13 -- SCOPE CAVEAT.** Surfaces read this round: `bin/edm-state:600-790`, `:1180-1541`, `:3290-3421`,
  `:4513-4718`, `:4946-5060`, `:5486-5684`; `bin/edm-lint-staged-artifacts` (whole file);
  `bin/edm-lint-artifacts:120-169`; `bin/edm-init:85-194`; `evals/run-eval.sh:395-460`;
  `evals/tiering-matrix.sh:140-180`; `evals/score-artifacts.sh:745-780`; `skills/implement/SKILL.md:28-152`;
  `bin/tests/wave6-smoke.sh:25-42`, `:878-922`; `bin/tests/wave7-smoke.sh:8958-8996`, `:9620-9703`;
  `.gitlab-ci.yml` eval:nightly timeout block; `plugins/edm/CLAUDE.md`; root `.gitignore`.
  **Report as unaudited, not clean:** `bin/edm-state:1550-3290` and `:3421-4513` (including
  `cmd_phase_start`, `cmd_phase_complete`, `cmd_approve_gate`, `cmd_init`, `cmd_migrate_schema`,
  `cmd_migrate_path`, `cmd_git_lock_check`, `cmd_metrics_report`, `_write_handoff_body`),
  `:5060-5486`, `:5692-6203`; `bin/edm-validate-prefix`, `edm-check-grants`, `edm-check-vocabulary`,
  `edm-check-skill-sync`, `edm-compare-eval`, `edm-sync-canonical-sections`, both shared libs,
  `edm-mermaid-rules.awk`; the body of `evals/run-eval.sh` outside `:395-460`; all of `bin/tests/**`
  beyond the ranges listed above; the remaining `skills/**` and `agents/**` prompt bodies; `docs/**`.
  Previously-fixed L3 findings CA-027/CA-028/CA-055/CA-056/CA-059/CA-062 received partial regression
  re-verification only (CA-056's fence-aware duplicate check at `:5509-5525` and CA-059's
  decide-inside-the-lock shape at `:4946-5000` were re-read and are intact; the others were not).
