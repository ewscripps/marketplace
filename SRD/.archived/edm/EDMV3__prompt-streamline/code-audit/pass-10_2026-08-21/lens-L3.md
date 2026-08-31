# Lens L3: Edge Cases & Concurrency -- Round 10 (full)

**Runtime caveat (CA-130's class, recurrence #8):** this lens was delivered **neither `Write` nor `Bash`**. Consequences for this round: (i) the report and JSONL are returned inline in the agent message rather than written to `SRD/edm/EDMV3__prompt-streamline/code-audit/pass-10_2026-08-21/`; (ii) I could not run `git log`/`git diff` over `c3467cb`, so every remediation verdict below is derived from **reading the source at HEAD**, not from the diffs -- I cannot attest to what the fix commit touched outside the sites I read; (iii) I could not execute `bin/tests/run-all.sh` or reproduce any finding dynamically -- every trigger below is asserted from bash/git semantics, not observed. CA-130 is NOTED with a do-not-re-file disposition; recorded here as a round-10 recurrence and as a confidence qualifier on the Priority-1 verdicts.

**Scope coverage caveat:** the coordinator halted investigation mid-sweep. Surfaces I read closely: `bin/edm-state` (locking/`write_atomic`/`rmw_state`/`with_state_lock`/`cmd_watch_impl`/`cmd_audit_round_*`/`_cmd_archive_move_body`), `bin/edm-lint-artifacts` (whole file), `bin/edm-lint-staged-artifacts` (whole file), `hooks/hooks.json` (whole file), `monitors/monitors.json` (whole file), `skills/implement/SKILL.md` (whole file), `evals/score-artifacts.sh:735-789`, `evals/tiering-matrix.sh:135-175`, `evals/run-eval.sh` trap/timeout surfaces, `.gitlab-ci.yml:735-805`. Surfaces **NOT** re-audited this round and to be reported as unaudited rather than clean: `bin/edm-state:1500-3250` and `:3350-4420` and `:4600-6100`, `bin/edm-init`, `bin/edm-validate-prefix`, `bin/edm-check-grants`, `bin/edm-check-vocabulary`, `bin/edm-check-skill-sync`, `bin/edm-compare-eval`, `bin/edm-sync-canonical-sections`, `bin/_edm-cli-lib.sh`, `bin/_edm-lint-lib.sh`, `bin/edm-mermaid-rules.awk`, all of `bin/tests/**` beyond trap-shape greps, the remaining `skills/**` and `agents/**` prompt bodies, `docs/**`.

---

## Part 1 -- Priority 1: verdicts on every open L3 ledger entry

Seven ledger entries name L3 and are `open`. Verified individually against the current tree.

| Ledger ID | Sev | Verdict | Evidence at HEAD |
|---|---|---|---|
| **CA-473** | P1 | **FIXED, clean** | Namespaces are now disjoint. `hooks/hooks.json:117` mandates `qc/qc-shard-impl-{NN}.md` and explicitly bans both `qc-summary.md` and any `qc-shard-pass-*` name. `skills/implement/SKILL.md:106` and `:110` write `qc/qc-shard-pass-01.md` / `qc-shard-pass-{i+1:02d}.md`; `:111-112` states the ordinal-vs-ticket keying rule inline. Merge glob widened to both prefixes at `:39`, `:93-94` and `:114`. Non-overlap contract stated at `:86-91`. One **new residual on a different axis** -- see finding 3. |
| **CA-478** | P2 | **FIXED, clean** | `bin/edm-state:4548-4549`: `while IFS= read -r _lens || [[ -n "$_lens" ]]; do` followed by `_lens="${_lens%$'\r'}"`. Both the unterminated-final-line and the CRLF trigger are closed, and the rationale comment at `:4544-4547` names the input class correctly. |
| **CA-479** | P2 | **STILL OPEN** | `bin/edm-state:4537-4540` is byte-unchanged in substance: `for _cand in "${_init_dir}/code-audit/pass-${round_num}_"*; do [[ -d "$_cand" ]] || continue; _pass_dir="$_cand"; done`. No count, no diagnostic, last lexicographic match silently wins. See finding 1. |
| **CA-480** | P2 | **STILL OPEN** | `bin/edm-state:1354` -- the whole reclaim apparatus (`:1356-1390` invalid-PID, `:1391-1405` dead-PID) is still inside `if [[ -f "$pidfile" ]]`. `:1410` is still `echo $$ > "$pidfile" 2>/dev/null || true`. The trap layer still does not install until `:1431-1434`, i.e. after the `mkdir` at `:1349`. The unreachable `'${holder_pid:-missing}'` label still sits at `:1381`, `:1383`, `:1385`. See finding 2. |
| **CA-481** | P2 | **STILL OPEN (a, b, c all)** | (a) `evals/tiering-matrix.sh:154` is still `trap 'rm -f "${tmp:-}"' RETURN EXIT INT TERM` -- one body, no `exit`, **HUP still absent**; the pre-convention rationale comment at `:148-153` is unchanged. (b) `evals/score-artifacts.sh:758-763`: the second `mktemp` now has a first-file unwind (`:759`), but the four-arm trap is still only armed at `:760`, so the window between the first `mktemp` at `:758` and `:760` is still untrapped -- the exact gap `edm-lint-artifacts:133-137` closed. (c) The prescribed durability pin never landed: a repo-wide grep of `bin/tests/**` returns **zero** occurrences of `CA-446`, `CA-447`, `CA-481` or `CA-482`. See finding 5. |
| **CA-482** | P2 | **STILL OPEN, all six sites** | `bin/edm-lint-artifacts:137` is still `trap 'rm -f "$ATTR_PATTERN_FILE"' EXIT INT TERM HUP` -- one body, four signals, no `exit`, twelve lines above the split form at `:149-152` and directly contradicting the file-wide contract stated at `bin/edm-state:687-691`. The five folded-in sites are all unchanged: `bin/tests/_harness.sh:85`, `_harness.sh:114`, `harness-smoke.sh:264`, `wave6-smoke.sh:34`, `wave7-smoke.sh:25`. `bin/tests/timing.sh:49-52` remains the only four-arm site in that directory. See finding 5. |
| **CA-511** | P2 | **PARTIALLY FIXED -- stays open** | The **documentation half landed**: `.gitlab-ci.yml:743-751` now spells out the `3 x 2700 + 60 = 136m` arithmetic against the `timeout: 150m` at `:752` and instructs raising it in the same change. The **enforcement half did not**: `evals/run-eval.sh:412-422` still validates only the knob's *type* (`''|*[!0-9]*|0` -> exit 2) and has no upper bound and no reference to `CI_JOB_TIMEOUT`, so `EDM_EVAL_PHASE_TIMEOUT_SECONDS=3600` still passes cleanly and still inverts the nesting (180m inner vs 150m outer) with no diagnostic on any channel. See finding 6. |

---

## Part 2 -- Findings

### 1. [P2] CA-479 confirmed STILL OPEN -- pass-directory resolution silently takes the last of several `pass-N_*` matches

**File:** `plugins/edm/bin/edm-state:4537-4540`

```bash
    for _cand in "${_init_dir}/code-audit/pass-${round_num}_"*; do
      [[ -d "$_cand" ]] || continue
      _pass_dir="$_cand"
    done
    _manifest="${_pass_dir}/lenses-run.txt"
```

The glob is date-suffixed (`pass-9_2026-08-16`), so a round re-run across a date boundary, a hand-copied scratch directory, or a partially-created retry leaves **two** `pass-N_*` directories. The loop keeps the last in lexicographic (= chronological) order with no diagnostic. **This initiative's own tree is a live example of the ambiguity's precondition**: `pass-3_2026-08-08` and `pass-4_2026-08-08` share a date, and this round's own artifacts are being written to `pass-10_2026-08-21` while `pass-9_2026-08-16` exists -- one mistyped round number in `audit-round-start` produces exactly the two-directory state.

Both directions fail silently:
- newest is a scratch/partial copy without lens JSONL -> the CA-471 gate fires **spuriously**, downgrades a legitimately complete round to `partial`, and (per CA-506) that downgrade is irreversible, making the round permanently non-convergent;
- newest is a stale copy that happens to hold JSONL -> the gate passes **vacuously** for the round that actually ran, which is precisely the pass-7 failure CA-471 exists to prevent.

The C-4 carve-out at `:4529-4531` deliberately tolerates a *missing* pass directory; it says nothing about an *ambiguous* one. `round_num` itself is safe here (the glob prefix is fully quoted, so state-file metacharacters are not glob-active).

**Fix:** collect matches into a counted list; when the count exceeds one, emit a warning naming **all** of them and select by mtime, or refuse outright. Add a wave6 case seeding two `pass-N_*` directories and asserting the warning names both.

---

### 2. [P2] CA-480 confirmed STILL OPEN -- a state lockdir with NO pidfile is never reclaimed; on the mkdir branch that bricks the initiative's lock permanently

**File:** `plugins/edm/bin/edm-state:1354`

The entire reclaim apparatus -- both the age-gated invalid-PID path (`:1356-1390`) and the dead-PID path (`:1391-1405`) -- still lives inside `if [[ -f "$pidfile" ]]` at `:1354`. A lockdir that exists **without** a pidfile skips the whole block on every iteration, falls through to `_lock_retry_or_die` at `:1407`, exhausts the ~50-try budget, and `die`s at `:1408`. Nothing on this invocation or any later one can ever reclaim it.

Three ways to reach that state, all unchanged:
- **(a)** A crash, `kill -9`, or power loss in the window between `mkdir "$lockdir"` succeeding at `:1349` and the pidfile write at `:1410`. Note the trap layer is not installed until `:1431-1434`, so even a *clean* Ctrl-C in that window leaves the lockdir with no pidfile **and** no cleanup.
- **(b)** The pidfile write failing at all: `:1410` is still `echo $$ > "$pidfile" 2>/dev/null || true`, swallowing EROFS / ENOSPC / quota. The lock is then held with no pidfile for this process's lifetime, and the first ungraceful exit orphans it permanently.
- **(c)** Any external process creating the directory name.

**Impact:** the mkdir branch is the macOS path and `plugins/edm/CLAUDE.md` names macOS the primary development platform. Once bricked, every `edm-state` mutation for that initiative dies -- including the `Stop` and `PreCompact` `checkpoint-if-active` hooks (`hooks/hooks.json:96`, `:106`) that fire on every session -- until a human runs `rm -rf` by hand.

**Corroborating tell that the author intended coverage:** the invalid-PID branch still prints `'${holder_pid:-missing}'` at `:1381`, `:1383` and `:1385`. That `missing` arm is unreachable as written -- the `-f` guard means `holder_pid` can only be empty when the pidfile *exists* and is empty.

**Fix:** hoist the `_git_lock_age_seconds >= 1` reclaim out of the `-f "$pidfile"` guard so an absent pidfile takes the same age-gated path an empty/invalid one does; and make the `:1410` write failure fatal (remove the lockdir, then `die`) rather than `|| true`.

---

### 3. [P2] NEW -- CA-473's fix left the `qc-shard-pass-{NN}` key non-unique ACROSS WAVES, and the skill contradicts itself on whether the pass runs once or per wave

**File:** `plugins/edm/skills/implement/SKILL.md:39`, `:96-99`, `:103`, `:106`, `:110`

CA-473 correctly made the two *mechanisms* disjoint (`qc-shard-impl-` vs `qc-shard-pass-`). It did not make the `pass-` key unique over **time**, and the file gives two incompatible readings of the pass's cardinality:

| Site | Text | Implied cardinality |
|---|---|---|
| `:96-97` | "when this skill itself orchestrates a QC pass **after all implementer waves complete**" | once per initiative |
| `:103` | `ticket_count = len(wave_tickets)` | once **per wave** |
| `:39` | "**After the wave drains**, merge every `qc/qc-shard-impl-*.md` and every `qc/qc-shard-pass-*.md` into `qc/qc-summary.md`" | once per wave |

Two of the three readings are per-wave, including the operative pseudo-code variable an agent will follow. Under the per-wave reading the collision is deterministic:

**Triggering scenario:** Step 1's own worked example (`:55-57`) is a three-wave initiative. Wave 1's post-wave QC pass writes `qc/qc-shard-pass-01.md`; the merge at `:39` builds `qc-summary.md`. Wave 2's post-wave QC pass writes `qc/qc-shard-pass-01.md` again, **overwriting** wave 1's, and the merge step -- which regenerates one verdict table from the shard glob -- produces a `qc-summary.md` from which wave 1's pass-shard verdicts have vanished. Nothing reports the loss. As CA-473 itself established, only PARTIAL survives elsewhere (via the locked `record-partial-verdict`); **PASS and FAIL live ONLY in these markdown files**, so a wave-1 FAIL never reaches Step 5's compile step at `:130`.

The hook shards are immune -- `qc-shard-impl-{lowest ticket}` is unique across waves by construction, because each implementer owns a distinct ticket range. Only the ordinal-keyed `pass-` namespace collides.

**Fix:** pick one cardinality and state it once. If the pass is genuinely per-initiative, change `:103` to the full ticket set and delete "after the wave drains" from `:39`. If it is per-wave, key the name on wave as well as ordinal (`qc-shard-pass-w{W}-{i:02d}.md`) and widen `:114`'s glob. Add a wave7 assertion that the pass-shard key expression in `skills/implement/SKILL.md` contains a wave component whenever the merge step is described as per-wave, with a positive control.

---

### 4. [P2] NEW -- `edm-lint-staged-artifacts` decides *which* initiatives to lint from the **index** but lints the **working tree**, so a violation staged and then fixed unstaged commits clean

**Files:**
- `plugins/edm/bin/edm-lint-staged-artifacts:106` (`git ... diff --cached --name-only`)
- `plugins/edm/bin/edm-lint-artifacts:235-241` (`collect_md_files` -> `find "$dir" -type f ... -name '*.md'`)

The hook derives prefixes from the **index** (`:106`, `:114-123`) and then hands each surviving prefix to `edm-lint-artifacts` (`:131`), whose only file source is a `find` over the resolved initiative directory -- i.e. **worktree content**. `git commit` commits the index. Check and use are therefore over two different snapshots of the same paths, in both directions:

- **False pass (the enforcement bypass).** `git add srd.md` with an em dash in it, then fix the em dash in the editor without re-staging. The hook lints the clean worktree file, `violations` stays 0, `_summarize_and_exit` exits 0 (`edm-lint-artifacts:449-451`), the hook's `fail` stays 0, and `git commit` lands the em-dash blob. This is the routine `git add` -> keep-editing workflow, not an adversarial one.
- **False block.** The mirror case -- an *unstaged* violation anywhere in the same initiative's `*.md` tree blocks an otherwise clean commit, because the scan granularity is the whole initiative directory, not the staged paths.

Nothing in `edm-lint-staged-artifacts`'s own `EDM-HELP` block (`:2-24`), in `edm-lint-artifacts`'s (`:2-61`), or in `plugins/edm/CLAUDE.md`'s hooks table states the index-vs-worktree axis, so an operator reading either surface reasonably believes the commit *content* is gated.

**Severity rationale:** capped at P2 because the blocking `lint:artifacts` CI job (`edm-lint-artifacts --all` at merge-request time) lints the committed checkout and does catch the escaped violation -- so this is a lost fast local gate rather than an unguarded merge path, the same calibration CA-320 used.

**Fix:** lint the staged blobs. Materialize each staged `*.md` under the derived root via `git show ":$path"` into a scratch tree and run `edm-lint-artifacts --path <scratch>` (the `--path` mode is already documented as strictly read-only with no state resolution, `edm-lint-artifacts:16-18`, `:477-496`), or at minimum state the worktree semantics in both `EDM-HELP` blocks and in `CLAUDE.md`'s hooks-table row. Add a smoke case that stages a violating file, fixes it unstaged, and asserts the hook exits 2 (positive control: assert the current code exits 0).

---

### 5. [P2] CA-481 and CA-482 confirmed STILL OPEN -- seven residual single-body traps, one missing HUP, one untrapped mktemp window, and zero test coverage pinning the convention

**Files (all verified unchanged at HEAD):**

| Site | Current form | Defect |
|---|---|---|
| `plugins/edm/bin/edm-lint-artifacts:137` | `trap 'rm -f "$ATTR_PATTERN_FILE"' EXIT INT TERM HUP` | one body, no `exit`; cleanup-then-**resume** on the binary that runs on every `git commit` |
| `plugins/edm/evals/tiering-matrix.sh:154` | `trap 'rm -f "${tmp:-}"' RETURN EXIT INT TERM` | one body, no `exit`, **HUP absent** -- the last trap in the plugin omitting HUP |
| `plugins/edm/evals/score-artifacts.sh:758` -> `:760` | first `mktemp` at `:758`, trap armed at `:760` | untrapped one-statement window; the exact gap `edm-lint-artifacts:133-137` closed |
| `plugins/edm/bin/tests/_harness.sh:85` | `trap 'rm -rf "$_HARNESS_SCRATCH_DIR"' EXIT INT TERM HUP` | one body, no `exit` |
| `plugins/edm/bin/tests/_harness.sh:114` | `trap 'rm -rf "$dir"' EXIT INT TERM HUP` | one body, no `exit` |
| `plugins/edm/bin/tests/harness-smoke.sh:264` | `trap 'rm -rf "$CA146_SCRATCH"' EXIT INT TERM HUP` | one body, no `exit` |
| `plugins/edm/bin/tests/wave6-smoke.sh:34` | `trap cleanup_wave6 EXIT INT TERM HUP` | one body, no `exit`; `cleanup_wave6` restores a **tracked** file |
| `plugins/edm/bin/tests/wave7-smoke.sh:25` | `trap 'rm -rf "$TMP"' EXIT INT TERM HUP` | one body, no `exit`; a Ctrl-C deletes the scratch root and the suite **resumes** running assertions against a tree that no longer exists |

`plugins/edm/bin/tests/timing.sh:49-52` is the only four-arm site in `bin/tests/`, so the exit-arm half of the declared convention is applied at 7 of 14 sites. All of this contradicts the contract stated file-wide at `plugins/edm/bin/edm-state:687-691` ("INT/TERM/HUP must actually terminate the process after cleanup -- a trap that only cleans up and returns lets the interrupted caller resume") and re-declared plugin-wide at `plugins/edm/bin/edm-check-grants:131-134`'s sibling comment block.

**CA-481(c) is the reason (a), (b) and the six test sites all survived a sweep that named them in scope:** a grep of `plugins/edm/bin/tests/**` for `CA-446`, `CA-447`, `CA-481` and `CA-482` returns **zero** hits. The convention is stated in comments in two files and enforced nowhere.

**Fix (one commit):** convert all eight sites to the canonical four-arm split (`EXIT` cleanup-only; `INT` then `exit 130`; `TERM` then `exit 143`; `HUP` then `exit 129`, keeping `RETURN` on the EXIT-equivalent arm at `tiering-matrix.sh:154`); arm a first-stage trap immediately after `score-artifacts.sh:758`; and land the cross-file sweep assertion CA-447 asked for -- scan `bin/`, `bin/tests/` and `evals/` for cleanup trap lines and assert each names HUP and each real signal exits after cleanup, with a positive control that adds a single-body trap and turns the assertion red.

---

### 6. [P2] CA-511 confirmed PARTIALLY FIXED -- the CI-side comment landed, the driver-side refusal did not, so the knob still inverts the timeout nesting silently

**Files:** `.gitlab-ci.yml:743-752` and `plugins/edm/evals/run-eval.sh:412-422`

The documentation half is genuinely closed and well done: `.gitlab-ci.yml:743-751` now names the `3 phases x 2700s = 135m, plus the 60s auth probe = 136m worst case` arithmetic against `timeout: 150m` at `:752`, and instructs that adding a fourth phase or raising the knob inverts the nesting and must raise this timeout in the same change.

The enforcement half is absent. `run-eval.sh:417-422` validates only the type:

```bash
case "$PHASE_TIMEOUT_SECONDS" in
  ''|*[!0-9]*|0)
    echo "run-eval: invalid EDM_EVAL_PHASE_TIMEOUT_SECONDS='${PHASE_TIMEOUT_SECONDS}' ..." >&2
    exit 2 ;;
esac
```

There is no upper bound and no reference to `CI_JOB_TIMEOUT` anywhere in the file. `EDM_EVAL_PHASE_TIMEOUT_SECONDS=3600` passes cleanly and yields `3 x 3600 = 180m` inner against a 150m outer ceiling -- the classic inner-exceeds-outer shape, with the phase timeout becoming dead wiring. When the GitLab job timeout wins, the trailing `script:` steps are never reached at all: `score-artifacts.sh` (`.gitlab-ci.yml:787-792`), `edm-compare-eval` (`:797-805`), and CA-452's own partial-run-always-fails-the-job handshake (`:777-785`) are all bypassed **precisely when the run was partial**, which is the one case that handshake exists for.

The comment mitigates a human *editing* either number, but not an operator *overriding* the knob at invocation, and nothing in `bin/tests/**` pins the 150m figure to the 2700s default, so the two can also drift apart by an edit that never reads the comment.

**Fix:** refuse at `run-eval.sh` startup when `3 * PHASE_TIMEOUT_SECONDS + <fixed overhead>` exceeds `${CI_JOB_TIMEOUT:-}` where that variable is present (GitLab exports it in seconds), naming both numbers in the diagnostic; and add a wave7 assertion tying the `timeout:` value in `.gitlab-ci.yml`'s `eval:nightly` to the `EDM_EVAL_PHASE_TIMEOUT_SECONDS` default in `run-eval.sh` arithmetically.

---

### 7. [P2] NEW -- CA-208's own fix left a lost-commit race: `watch-impl` re-resolves HEAD when advancing its cursor instead of reusing the HEAD it just scanned

**File:** `plugins/edm/bin/edm-state:3306` and `:3327`

```bash
    git_log_out="$(git log --pretty=format:'%h %s' "${last_sha}..HEAD" 2>/dev/null)" || git_log_ec=$?
    ...
    new_commits="$(printf '%s' "$git_log_out" | grep -E '[A-Z]+-T[0-9]+' || true)"
    [[ -n "$new_commits" ]] && echo "$new_commits"
    last_sha="$(git rev-parse HEAD 2>/dev/null || echo "$last_sha")"
```

`HEAD` is resolved twice per poll -- once as the range end at `:3306`, once as the new cursor value at `:3327` -- with a `grep` and an `echo` in between. Any commit landing in that window advances `last_sha` **past a commit that was never printed**, and it can never be printed on a later poll because the range now starts after it. This is the read-then-advance-cursor-to-a-re-read-value shape; it was introduced by CA-208's own remediation, whose G48 comment at `:3324-3326` correctly explains *why* to advance on every successful poll but advances to the wrong value.

`monitors/monitors.json:4-6` runs this for the whole `/edm:implement` phase, during which 6-10 implementers commit in parallel, and `plugins/edm/CLAUDE.md` documents the monitor as having no EDM-side kill switch -- so a dropped ticket notification is silent and unrecoverable for the rest of the session.

**Mitigating factor (why P2, not P1):** `skills/implement/SKILL.md:278` gives each `edm-implementer` `isolation: worktree`, so implementer commits land on the worktree's own branch and do **not** advance the monitored worktree's HEAD until the sequential merge at Step 3 (`:71-73`). The window is therefore narrow *and* the concurrent-writer population is small. The fix is one variable, which is why it is worth filing rather than noting.

**Fix:** resolve HEAD once per poll into a local, use it as both the range end and the new cursor:

```bash
local head_now
head_now="$(git rev-parse HEAD 2>/dev/null || echo "$last_sha")"
git_log_out="$(git log --pretty=format:'%h %s' "${last_sha}..${head_now}" 2>/dev/null)" || git_log_ec=$?
...
last_sha="$head_now"
```

---

## Noted / Not Actionable

- **N1 -- `plugins/edm/bin/edm-state:1349` to `:1431` (untrapped lock-acquisition window).** A lockdir created by the `mkdir` at `:1349` has no trap covering it until `:1431`. Recorded here rather than filed separately because it is the *mechanism* behind finding 2, not an independent defect -- fixing finding 2's reclaim path makes this window self-healing. This preserves round 9's identical disposition and avoids double-counting one defect.
- **N2 -- `plugins/edm/bin/edm-lint-staged-artifacts:58`.** `[ -n "$repo_root" ] && phys_repo_root="$(cd "$repo_root" 2>/dev/null && pwd -P)" || phys_repo_root="$repo_root"` is the `A && B || C` shape, but traced correct in all three cases: a simple assignment takes the command substitution's exit status, so a failed `cd` correctly falls through to the `||` arm, and an empty `repo_root` also lands on the `||` arm and is then caught by the `-n` guard at `:61`. Not a defect.
- **N3 -- `plugins/edm/bin/edm-lint-staged-artifacts:132`.** `code=$?` sits on the line after `out=$(...)`, i.e. CA-036's bare-capture shape -- but this file runs under `set -uo pipefail` with **no `-e`** (`:25`), so the errexit hazard does not apply. Not a live instance.
- **N4 -- `plugins/edm/bin/edm-lint-staged-artifacts:92`.** `check_dir="${repo_root:-.}/${srd_root}"` hands an **absolute** `EDM_SRD_ROOT` to both children at `:130-131`. This is CA-320's deliberate fix (one absolute value computed once, passed down explicitly rather than re-derived); both children accept an absolute value because only the *staged-path matcher* needs a relative one. Correct as written, recorded so a future round does not read it as an absolute-root regression.
- **N5 -- `plugins/edm/skills/implement/SKILL.md:106` vs `:110`.** Both the `ticket_count <= threshold` branch and the sharded branch can produce `qc-shard-pass-01.md`, but they are mutually exclusive arms of one `if`, so within a single pass they cannot collide. The cross-*wave* collision is the live axis and is filed as finding 3.
- **N6 -- `plugins/edm/bin/edm-state:3324-3326` (G48 unbounded-range half of CA-208).** Advancing the cursor on every successful poll rather than only on a match is correct and remains correct; only the *value* advanced to is wrong (finding 7). Recorded so the fix for finding 7 is not mistaken for a revert of G48.
- **N7 -- `plugins/edm/bin/edm-state:4552`.** The CA-471 gate's per-lens check is `[[ ! -s "$_lens_file" ]] || ! jq empty "$_lens_file"`. `jq empty` on a multi-line JSONL file succeeds only because jq's default input mode parses a stream of concatenated values, so a genuine JSONL file passes and a truncated final line fails -- the intended direction. Verified correct rather than filed.
- **N8 -- `plugins/edm/evals/run-eval.sh:276-279`.** The four-arm split trap (EXIT cleanup-only; INT/TERM/HUP exiting 130/143/129) is intact, matching CA-252's round-5 closure. Re-verified, no drift.
- **N9 -- CA-294 / CA-375 (lock give-up budget asymmetry, `edm-state:1407` vs the flock branch's `-w`).** Re-derived independently again this round and re-confirmed as standing under CA-294's explicit do-not-re-file disposition. Not re-filed.
- **N10 -- CA-291 / CA-332 (traps omitting HUP over TMPDIR-only resources).** The remaining sites named in those bundles were re-checked; only `evals/tiering-matrix.sh:154` is inside CA-481's scope (which explicitly overruled CA-291 for that site on the changed-premise argument). No new members of that class filed.
- **N11 -- COVERAGE CAVEAT, CA-130's class (recurrence #8), `plugins/edm/agents/edm-audit-edge-cases.md`.** This lens was delivered with neither `Write` nor `Bash`. The Priority-1 verdicts in Part 1 rest on reading source at HEAD rather than on the `c3467cb` diffs; the suite figure quoted in the task (2313 assertions, 0 failing) is orchestrator-supplied and was **not** independently verified by this lens; finding 2's window, finding 4's index-vs-worktree divergence and finding 7's race are asserted from bash/git semantics, not observed. CA-331's standing recommendation -- a Bash-capable pass runs `bin/tests/run-all.sh` immediately before the convergence gate -- applies again. CA-130 is NOTED with a do-not-re-file disposition; recorded here as a round-10 recurrence and a confidence qualifier.
- **N12 -- SCOPE CAVEAT.** Investigation was halted by the coordinator mid-sweep. The surfaces listed in the header caveat as NOT re-audited must be reported as **unaudited**, not clean -- in particular `bin/edm-state:1500-3250`, `:3350-4420` and `:4600-6100` (which include `cmd_phase_start`/`cmd_phase_complete`/`cmd_approve_gate`/`cmd_init`/`cmd_update_patterns`/`_splice_pattern_file`/`cmd_render_ledger`/`_write_handoff_body`/`cmd_record_partial_verdict`/`cmd_git_lock_check`), the whole of `evals/run-eval.sh`'s body, and all of `bin/tests/**` beyond trap-shape greps. Several of those are the exact sites of previously-fixed L3 findings (CA-027, CA-028, CA-055, CA-056, CA-059, CA-062) and received **no** regression re-verification this round.
