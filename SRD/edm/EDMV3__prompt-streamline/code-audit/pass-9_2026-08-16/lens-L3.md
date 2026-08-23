I have completed my analysis. I lack both `Write` and `Bash` in this runtime, so I'm returning both halves inline per my instructions.

---

## Findings (L3: Edge Cases & Concurrency)

### Priority 1 -- Round-8 remediation verification

Verified by source reading at HEAD (see coverage caveat N6 -- `git log`/`diff` over `833a06d..HEAD` was not runnable in this runtime).

| Ledger ID | Verdict | Evidence |
|---|---|---|
| CA-432 | **Fixed, clean** | `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-state:1151-1153` -- `^[1-9][0-9]*$` guard, `exit 2`, sits beside the default per CA-160's rule; the `*10` derivation is now safe. Covered at `bin/tests/wave6-smoke.sh:840-858` (non-numeric, fractional, valid). |
| CA-433 | **Fixed, clean** | `bin/tests/wave7-smoke.sh:5068-5081` -- the anchor no longer encodes the timeout value, and a stale anchor now `fail`s loudly instead of silently degrading to a one-line extraction. |
| CA-427 | **Fixed, clean** | Both sites now route through `AUDIT_ROUND_COERCE_JQ_DEF`: `edm-state:2293` and `edm-state:3120`. |
| CA-428 | **Fixed, clean** | `edm-state:3119-3120` -- both operands via `to_int`. (Residual candidate at `:3123-3125` investigated and dismissed -- see N2.) |
| CA-442 | **Fixed, correct** | `edm-state:3642` -- `rm -rf "${_src}/.edm-state.lockd"`. Confirmed it does **not** reintroduce CA-141: `with_state_lock`'s own cleanup (`:1425`, `:1455`) targets `_STATE_LOCKDIR` at the **destination** path, which no longer exists after the rollback rename, so no contender's live lockdir can be deleted. Comment-rationale residual recorded as N1. |
| CA-443 | **Fixed, clean** | `evals/run-eval.sh:188-195` -- clamps `keep` to 1 with a named warning; the just-finished run is no longer prunable. |
| CA-444 | **Fixed, partial** | `evals/run-eval.sh:408-417` -- type validated, `exit 2`. The knob is still unbounded **above**; see finding 7. |
| CA-445 | **Fixed, clean** | `edm-state:2609-2615` -- `path` emitted last so `read`'s final variable absorbs the remainder; the other three fields provably cannot contain a space. Residual (newline in path) recorded as N4. |
| CA-446 | **Fixed, incompletely swept** | Fixed at `bin/edm-sync-canonical-sections:90-93`, `bin/edm-lint-artifacts:149-152`, `bin/edm-check-grants:131-134`. Two sites of the same class remain -- see finding 5. |
| CA-447 | **Partially fixed (stays open)** | First-stage trap landed at `bin/edm-lint-artifacts:137`; HUP added across `bin/`. `bin/tests/_harness.sh:85`, `:114` and `bin/tests/harness-smoke.sh:264` still carry the one-body/four-signal shape. CA-447 is open -- confirming, not re-filing (N3). |
| CA-449 | **Fixed, clean** | `evals/score-artifacts.sh:756-763` -- TMPDIR-honoring templates, checked creation with first-file unwind, split four-arm trap. |
| CA-450 | **Fixed, clean** | `bin/tests/timing.sh:49-52` -- four-arm split trap. |
| CA-471 | **Landed, two boundary defects** | `edm-state:4438-4472`. Gate exists and downgrades to `partial`. Two residuals -- findings 1 and 2. |
| CA-440 | **Fixed, one residual** | `hooks/hooks.json:117` + `skills/implement/SKILL.md:81-85` -- the hook no longer writes `qc-summary.md`. Filename-namespace residual -- finding 3. |

---

### 1. [P2] CA-471's manifest loop silently drops the LAST lens when `lenses-run.txt` has no trailing newline

**File:** `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-state:4460-4466`

```bash
      while IFS= read -r _lens; do
        [[ "$_lens" =~ ^L[0-9]+$ ]] || continue
        ...
      done < "$_manifest"
```

`read` returns non-zero on a final line with no terminating newline, so the loop body **never executes for that line**. Every other `done < "$file"` reader in `bin/` (`edm-check-grants:562`, `edm-check-vocabulary:158`, `:233`) consumes a repo-committed or self-generated file with a guaranteed trailing newline. `lenses-run.txt` is the one manifest in this codebase authored by an LLM agent via the `Write` tool (`skills/code-audit/SKILL.md:78`) -- exactly the surface where a missing trailing newline is plausible.

**Triggering scenario:** a round whose `lens-L11.jsonl` never landed, with `L11` as the manifest's last line and no trailing newline. The gate reports no misses, `ca471_downgrade` stays empty, and the round records `round_type: full` -- so `edm-state audit-converged` can converge on it. That is precisely the pass-7 failure (eleven prose reports, zero JSONL) CA-471 was filed to prevent, reproduced at the boundary.

**Secondary trigger:** a CRLF manifest makes `[[ "$_lens" =~ ^L[0-9]+$ ]]` fail for *every* line, disabling the gate wholesale with no diagnostic.

**Fix:** `while IFS= read -r _lens || [[ -n "$_lens" ]]; do`, and strip CR before the regex: `_lens="${_lens%$'\r'}"`.

---

### 2. [P2] CA-471's pass-directory resolution silently takes the last of several `pass-N_*` matches

**File:** `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-state:4453-4457`

```bash
    for _cand in "${_init_dir}/code-audit/pass-${round_num}_"*; do
      [[ -d "$_cand" ]] || continue
      _pass_dir="$_cand"
    done
```

The glob is date-suffixed (`pass-9_2026-08-16`), so a round re-run across a date boundary, a hand-copied scratch directory, or a partially-created retry leaves **two** `pass-N_*` directories. The loop keeps the last in lexicographic (= chronological) order with no diagnostic. Both directions fail silently:

- newest is a scratch/partial copy without lens JSONL -> the gate fires spuriously and downgrades a legitimately complete round to `partial`, making it permanently non-convergent;
- newest is a stale copy that happens to hold JSONL -> the gate passes **vacuously** for the round that actually ran.

The C-4 carve-out at `:4445-4447` deliberately tolerates a *missing* directory; it says nothing about an *ambiguous* one. `round_num` itself is safe here (the glob prefix is fully quoted, so state-file metacharacters are not glob-active).

**Fix:** collect matches into a counted list; when `>1`, emit a warning naming all of them and select by mtime (or refuse), rather than resolving silently.

---

### 3. [P1] CA-440's fix puts two independent writers into ONE `qc-shard-NN.md` namespace -- the overwrite it closed can still happen

**Files:**
- `/Users/darryl.porter/projects/marketplace/plugins/edm/hooks/hooks.json:117`
- `/Users/darryl.porter/projects/marketplace/plugins/edm/skills/implement/SKILL.md:81-85`, `:97`, `:101`, `:103`

CA-440 correctly stopped the hook-spawned auditors from all writing `qc/qc-summary.md`. But the two shard producers key `{NN}` on **different quantities** and write into the same directory and the same merge glob:

| Writer | Key for `{NN}` | Site |
|---|---|---|
| Hook-spawned per-implementer auditor | **lowest ticket number** in the implementer's range | `hooks.json:117`; `SKILL.md:81-83` |
| Skill's own post-wave QC pass, `ticket_count <= threshold` | **lowest ticket number** | `SKILL.md:97` |
| Skill's own post-wave QC pass, sharded branch | **shard index** `{i+1:02d}` | `SKILL.md:101` |

Merge glob (`SKILL.md:103`): `merge all qc-shard-*.md files (hook-spawned and threshold shards alike)`.

**Triggering scenario (common, deterministic):** a wave of implementers covering T01-T09 leaves hook shards `qc-shard-01.md`, `qc-shard-04.md`, `qc-shard-07.md`. The skill's own post-wave QC pass then runs the `ticket_count <= threshold` branch and writes `qc-shard-01.md`, destroying the hook shard for T01-T03. Its FAIL verdicts never reach `qc-summary.md` and nothing reports the loss -- CA-440's exact harm.

**Second scenario (sharded branch):** shard index `1` -> `qc-shard-01.md` collides with the hook shard for T01; index `7` with T07; and so on for every index that coincides with a range-leading ticket number.

**Fix:** give the two producers disjoint namespaces (`qc-shard-hook-{ticket}.md` vs `qc-shard-pass-{i}.md`) and widen the merge glob to cover both, or have the skill's own pass cover only tickets no hook shard already covers. Rated P1 to match CA-440's own severity for the identical harm; blast radius is smaller (one shard, not all of them), so a downgrade to P2 at synthesis is defensible.

---

### 4. [P2] A state lockdir with NO pidfile is never reclaimed -- the mkdir branch bricks that initiative's lock permanently

**File:** `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-state:1348-1404`

The entire reclaim apparatus -- both the age-gated invalid-PID path (`:1350-1383`) and the dead-PID path (`:1385-1398`) -- lives inside `if [[ -f "$pidfile" ]]` (`:1348`). A lockdir that exists **without** a pidfile therefore skips the whole block on every iteration, falls through to `_lock_retry_or_die`, exhausts the ~100-try/10 s budget, and `die`s. Nothing on this invocation or any later one can ever reclaim it.

Three ways to reach that state:

- **(a)** A crash, `kill -9`, or power loss in the window between `mkdir "$lockdir"` succeeding (`:1343`) and `echo $$ > "$pidfile"` (`:1404`). Note the trap layer is not installed until `:1425`, so even a *clean* INT in that window leaves the lockdir with no pidfile **and** no cleanup.
- **(b)** The pidfile write failing at all: `echo $$ > "$pidfile" 2>/dev/null || true` (`:1404`) swallows EROFS / ENOSPC / quota silently. The lock is then held with no pidfile for this process's lifetime, and the first ungraceful exit orphans it permanently.
- **(c)** Any external process creating the directory name.

**Impact:** the mkdir branch is the macOS path, and `plugins/edm/CLAUDE.md` names macOS the primary development platform. Once bricked, every `edm-state` mutation for that initiative dies -- including the `Stop` and `PreCompact` `checkpoint-if-active` hooks that fire on every session -- until a human runs `rm -rf` by hand.

**Corroborating tell:** the invalid-PID branch already prints `'${holder_pid:-missing}'` at `:1375`, `:1377` and `:1379`. That `missing` label is unreachable as written -- the `-f` guard means `holder_pid` can only be empty when the pidfile *exists* and is empty. The author clearly intended the missing-pidfile case to be covered; the guard placement prevents it.

**Fix:** hoist the `_git_lock_age_seconds >= 1` reclaim out of the `-f "$pidfile"` branch so an absent pidfile takes the same age-gated reclaim path an empty/invalid one does; and make the `:1404` write failure fatal (remove the lockdir, then `die`) rather than `|| true`.

*If a prior round covered this under CA-141's or CA-318's reclaim discussion, treat this as a confirmation rather than a new ID -- I could not find it in the ledger's open or NOTED set.*

---

### 5. [P2] The CA-446/CA-447 trap sweep left two sites of its own class -- one of them created by the sweep

**Files:**
- `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-lint-artifacts:137`
- `/Users/darryl.porter/projects/marketplace/plugins/edm/evals/tiering-matrix.sh:154`

**(a) Introduced by the CA-447 fix.** `edm-lint-artifacts:137`:

```bash
trap 'rm -f "$ATTR_PATTERN_FILE"' EXIT INT TERM HUP
```

One body on all four signals with no `exit` -- the exact shape CA-446 closed **twelve lines below it** at `:149-152`. A signal delivered in the covered window (the second `mktemp` at `:144`) cleans up and then **resumes**, so the process ignores the operator's Ctrl-C. This binary runs on every `git commit` via the `PreToolUse` hook, so the interrupt an operator sends is the one that gets swallowed. Contradicts the file-wide contract `bin/edm-state:687-691` states ("INT/TERM/HUP must actually terminate the process after cleanup -- a trap that only cleans up and returns lets the interrupted caller resume").

**(b) Never swept.** `evals/tiering-matrix.sh:154`:

```bash
trap 'rm -f "${tmp:-}"' RETURN EXIT INT TERM
```

Same one-body shape, and **HUP is missing entirely** -- adding HUP everywhere else was precisely the other half of CA-447. `evals/*.sh` is inside CA-446/447's declared scope; this file was simply not visited.

**Fix:** split both into the canonical four-arm form (`EXIT` cleanup-only; `INT` + `exit 130`; `TERM` + `exit 143`; `HUP` + `exit 129`). Both are one-line-each changes.

---

### 6. [P2] Nothing couples the eval's inner per-phase timeout budget to the CI job's outer timeout, and the inner budget already consumes 90% of it

**Files:** `/Users/darryl.porter/projects/marketplace/.gitlab-ci.yml:713` and `/Users/darryl.porter/projects/marketplace/plugins/edm/evals/run-eval.sh:407`

`eval:nightly` sets `timeout: 150m` (9000 s). `run-eval.sh` runs exactly three phases -- `invoke_claude plan|srd|audit-srd` at `:500`, `:533`, `:571` -- each bounded by `PHASE_TIMEOUT_SECONDS` (default 2700 s), plus a 60 s auth probe (`:343`), plus `npm install -g @anthropic-ai/claude-code` (`.gitlab-ci.yml:731`), fixture provisioning, scoring and the baseline comparison.

Worst case from the inner timeouts alone: `3 x 2700 + 60 = 8160 s = 136 m` against a 9000 s ceiling. Two consequences:

- **The outer timeout defeats the CA-452 handshake in exactly the case it matters.** When GitLab's job timeout wins, the job is killed and the trailing `script:` steps -- `score-artifacts.sh` (`:748-753`), `edm-compare-eval` (`:758-768`), and CA-452's "partial always fails the job" step (`:771-775`) -- never run at all. The partial-run contract CA-452 was filed to make live is bypassed.
- **CA-444 validated the knob's type but left it unbounded above.** `EDM_EVAL_PHASE_TIMEOUT_SECONDS=3600` passes validation cleanly and makes `3 x 3600 = 180 m > 150 m`, i.e. the phase timeout becomes dead wiring -- the classic "inner timeout exceeds outer timeout" shape. Neither the knob's documentation (`run-eval.sh:34-35`) nor the CI job mentions the other.

**Fix:** state the relationship at both sites and derive one from the other -- e.g. refuse at `run-eval.sh` startup when `3 * PHASE_TIMEOUT_SECONDS + 120` exceeds `${CI_JOB_TIMEOUT:-}` where that variable is present, and add a comment at `.gitlab-ci.yml:713` naming the three-phase arithmetic the 150 m figure is derived from.

---

## Noted / Not Actionable

- **N1 -- `edm-state:3642` (CA-442 fix rationale).** The fix itself is correct and does not reintroduce CA-141. But its justifying comment (`:3640-3641`) cites "the flock file (fd 200) is still held until this body returns" -- that reasoning holds only on the **flock** branch. On the mkdir branch (macOS) the lockdir *is* the mutual-exclusion primitive, so removing it here releases the lock before the body returns. I traced the residual window as benign: only `rmdir "$_product_dir"` follows, and `cmd_migrate_path` `die`s immediately after, so no state mutation happens unprotected. The identical comment/branch mismatch exists at the forward body (`:3613`, G17). This is comment correctness, not a live defect, and falls under CA-439's already-open class -- not re-filed.
- **N2 -- `edm-state:3123-3125`.** `debt_recheck_p0` / `debt_recheck_p1` reach `[[ -eq ]]` without `to_int`, three lines after CA-428's sweep. Investigated and dismissed: `_audit_ledger_breakdown` (`:1565-1578`) derives both via `| length`, so they are non-negative integers by construction; a malformed ledger makes `jq` fail, the `&&` at `:3122` short-circuits, and the debt override is skipped fail-safe. Not a live instance of CA-157's class.
- **N3 -- `bin/tests/_harness.sh:85`, `:114`; `bin/tests/harness-smoke.sh:264`.** Still carry the single-body `EXIT INT TERM HUP` trap with no `exit`. These are named sites of the still-open CA-447 -- confirming presence, not re-filing. (Also a test-only path, per False Alarm Filter #3.)
- **N4 -- `edm-state:2613-2615` (CA-445 residual).** The fix handles spaces correctly. A recorded artifact path containing a **newline** still mis-splits across two loop iterations, and `IFS=' '` strips a trailing space from the final field. Both are pathological path shapes; accepted as out of scope for the fix's stated contract.
- **N5 -- `edm-state:1343` to `:1425` (unprotected acquisition window).** A lockdir created at `:1343` has no trap covering it until `:1425`. Recorded here rather than filed separately because it is the *mechanism* behind finding 4, not an independent defect -- fixing finding 4's reclaim path makes this window self-healing.
- **N6 -- COVERAGE CAVEAT (CA-130's class, `plugins/edm/agents/edm-audit-edge-cases.md`).** This lens was delivered with **neither `Write` nor `Bash`** in its runtime tool set. Consequences for this round specifically: (i) I could not run `git log`/`git diff` over the `833a06d..HEAD` range the task designated as Priority 1, so every remediation verdict in the table above is derived from reading the source at HEAD rather than from the diffs, and I cannot attest to what a fix commit touched *outside* the sites I read; (ii) I could not execute the smoke suite or reproduce any finding dynamically -- finding 4's window and finding 1's `read` behaviour are asserted from bash semantics, not observed; (iii) the report and JSONL are returned inline in this message rather than written to `pass-9_2026-08-16/`. CA-130 is NOTED with a do-not-re-file disposition; recorded here as a round-9 recurrence and a confidence qualifier on the Priority-1 verdicts.

---

