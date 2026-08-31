I have enough to complete the audit. I lack `Write`, so both halves follow inline.

# Lens L1: Logic, Correctness & Completeness -- Round 9 (pass-9, 2026-08-16)

Scope swept: `plugins/edm/bin/*` (esp. `edm-state`, `edm-lint-artifacts`, `edm-lint-staged-artifacts`, `edm-check-grants`, `edm-init`, `edm-validate-prefix`, `edm-sync-canonical-sections`), `plugins/edm/bin/tests/*.sh`, `plugins/edm/evals/*.sh`, `plugins/edm/hooks/hooks.json`, repository-root `.gitlab-ci.yml`, plus `skills/implement/SKILL.md` and `skills/code-audit/SKILL.md` where the round-8 fixes landed there.

Tooling caveat (CA-130, 9th consecutive round): this lens ran with **no `Bash` and no `Write`**. Nothing was executed; every claim below is derived from reading source. Both halves are returned in the agent message rather than written to `pass-9_2026-08-16/`.

## Priority 1 -- verification of the round-8 remediation (Stages A/B/C)

**Verified genuinely fixed; recommend close.**

| ID | Evidence |
|---|---|
| CA-426 | `bin/edm-state:2229-2239` -- `conv_out="$(cmd_audit_converged "$prefix")"`, no `2>&1`. The `G14/CA-426` comment states the contract. `:2248` adds `p2_debt_breakdown_read`; `:2267-2276` splits into two die messages so the P0/P1 form is only used when the breakdown was actually read. Traced all four exit-1 arms of `cmd_audit_converged` (`:4577`, `:4581`, `:4624`, `:4628` stderr-only; `:4668` stdout) -- the prefix test at `:2249` is now structurally correct, not accidentally correct. Pinned by `wave6-smoke.sh:800-815`. |
| CA-427 | `:2293` and `:3120` both use `${AUDIT_ROUND_COERCE_JQ_DEF} (.audit_rounds.code // 0 \| coerce_round_entry).count`. Zero remaining `.audit_rounds.code.count` reads in the file. `wave6-smoke.sh:823-837` seeds the bare-integer `{"code": 2}` shape and asserts `code_audit_p2_debt_round == 2`. |
| CA-428 | `:3119`/`:3120` both wrapped in `to_int` before the `[[ -eq ]]` at `:3121`. |
| CA-429 | `:5476-5484` -- `_accepted_by`/`_accepted_at` gained their reader in HANDOFF's debt row. `wave6-smoke.sh:818-820`. |
| CA-425 | `wave6-smoke.sh:765-797` -- partial-round, invalid-JSONL, wrong-gate and unknown-third-argument negative cases all landed, each via `check_refuses_and_leaves_state`. |
| CA-432 | Validated at load; `wave6-smoke.sh:840-858` covers `abc`, `0.5` and the valid `5`. |
| CA-433 | `wave7-smoke.sh:5068-5077` -- anchor no longer encodes `-w 10` and now `fail`s loudly on a stale anchor. |
| CA-438 | `wave7-smoke.sh:5087-5100` -- `BASH_XTRACEFD` + "Do not lower this" pinned, plus a low-fd `check_absent`. |
| CA-439 | `bin/edm-state:2326` now reads "see `_write_handoff_body`'s gates_count -- named by anchor, not line number, CA-439". Both `:5036` citations gone. |
| CA-441 | `skills/test`, `test-plan`, `test-coverage` frontmatter all carry `Task`; `bin/edm-check-grants:506-517` adds the `missing-task-grant` rule. |
| CA-446 / CA-447 | Four-signal traps with signal-shaped exits now in `edm-check-grants:131-134`, `edm-sync-canonical-sections:90-93`, `edm-lint-artifacts:149-152`. |
| CA-460 / CA-461 | `wave7-smoke.sh:8158-8194` and `:8197-8210` -- computed count assertions and the README/`edm-compare-eval` field-name equality. |
| CA-462 | `evals/score-artifacts.sh:535-574` `compute_dim6`, gated on `run.json`'s `fixture` field, which `run-eval.sh:152` and `:675` both write. `scorer_version` bumped. |
| CA-471 | New completeness backstop at `bin/edm-state:4438-4472`, covered by `wave6-smoke.sh:860-910` including the C-4 no-pass-directory arm. Also swept into `CLAUDE.md`'s state-field table and `skills/code-audit/SKILL.md:143-149`. |
| CA-413 / CA-414 / CA-436 | Hook body extracted to `bin/edm-lint-staged-artifacts`; `pwd -P` physical-path comparison at `:57-66`, `-c core.quotePath=false` + `printf '%s\n'` at `:101-106`, `# shellcheck disable=SC2086` now placeable at `:127`. `hooks.json:86` is a thin delegator. Exit-code mapping at `:133-140` matches the documented contract exactly (linter exit 1 -> script exit 2 blocking; linter exit 2 -> reported, non-blocking). |

**Confirmed still open -- cited, not re-filed.**

- **CA-401** -- the unguarded count-capture class survives at `wave6-smoke.sh:290, :1057, :1074, :3441, :3448, :3460` (bare `grep -c`/`grep -cE` assignments under `set -euo pipefail`, no `|| true`, not routed through `count_matches`). Line numbers shifted from round 8's citation; the sites are the same.
- **CA-453** -- still zero coverage. A tree-wide grep for `Gates approved` across `bin/tests/` returns exactly one hit and it is a comment (`wave6-smoke.sh:649`); `required_gate_count` appears in no test file. None of the four prescribed assertions landed.

---

## Findings (L1: Logic, Correctness & Completeness)

### L1-001 [P1] The CA-440 fix moved the hook's QC output into the *same* `qc-shard-NN.md` namespace the threshold-shard mechanism already owns, with two incompatible numbering schemes -- reintroducing silent FAIL-verdict loss one level down

**File**: `plugins/edm/skills/implement/SKILL.md:97` and `:101` (colliding with `:81-83`), `plugins/edm/hooks/hooks.json:117` (step 5)

CA-440 correctly stopped 6-10 concurrent hook-spawned auditors from all writing `qc/qc-summary.md`. The new hook path writes:

> `qc/qc-shard-{NN}.md`, where {NN} is the **lowest ticket number** in this implementer's assigned range, zero-padded (e.g. tickets T07-T09 -> qc-shard-07.md)  -- `hooks.json:117`, restated at `SKILL.md:81-83`

But the pre-existing threshold-shard mechanism, which `SKILL.md:87` explicitly says runs "**separately from** the per-implementer hook shards", writes into the identical namespace with a *different* key:

if ticket_count <= threshold:
    spawn 1 edm-qc-auditor -> writes qc/qc-shard-{lowest-ticket:02d}.md      # :97
else:
    for i, range in enumerate(chunks(wave_tickets, shard_size)):
        spawn edm-qc-auditor(shard=i+1, tickets=range) -> writes qc/qc-shard-{i+1:02d}.md   # :101

`{i+1:02d}` is a **shard ordinal** (01, 02, 03, ...). `{NN}` is a **ticket number** (01, 04, 07, ...). Both are two-digit, zero-padded, in one directory, written with full-file `Write` semantics, by agents running concurrently. `SKILL.md:103` confirms both sets coexist at merge time: "merge all qc-shard-\*.md files (hook-spawned and threshold shards alike)".

Two concrete collisions, both routine rather than exotic:

1. **Large initiative (> `qc_shard_threshold`, default 20).** Threshold shard 1 writes `qc-shard-01.md`. The implementer whose range begins at T01 -- the first implementer of the first wave, essentially always present -- also writes `qc-shard-01.md`. Same for shard 2 vs T02, shard 3 vs T03. Last writer wins; the loser's FAIL verdicts never reach `SKILL.md:119`'s "Compile all FAIL findings from `qc/qc-summary.md`".
2. **Small initiative (<= threshold).** `:97` uses `{lowest-ticket:02d}` -- **byte-identical** to the hook's own key. The skill's single orchestrated auditor deterministically overwrites the hook shard for the implementer that owned that same lowest ticket. Every time.

This is the same harm CA-440 was rated P1 for (PASS and FAIL verdicts live only in these markdown files -- only PARTIALs reach state via the correctly-locked `record-partial-verdict`), relocated rather than removed, and it was introduced by CA-440's own remediation. `CLAUDE.md`'s hooks table repeats only the hook half of the convention, so nothing documents the overlap either.

**Concrete fix** -- disjoint namespaces, one edit to each writer:

- `hooks.json:117` step 5: write `qc/qc-shard-impl-{NN}.md` (NN = lowest ticket number), and say so in the same sentence that currently says `qc-shard-{NN}.md`.
- `SKILL.md:97` and `:101`: write `qc/qc-shard-pass-{i+1:02d}.md` for the threshold path (and `qc-shard-pass-01.md` for the single-auditor branch, so the two branches of one mechanism agree with each other too).
- `SKILL.md:103`: `merge all qc-shard-impl-*.md and qc-shard-pass-*.md into qc/qc-summary.md`.
- `SKILL.md:81-85` and `CLAUDE.md`'s `SubagentStop` row: state both prefixes and state that they must not overlap.
- Durability: add a `wave7-smoke.sh` assertion that the shard token in `hooks.json`'s `SubagentStop` prompt and the shard token in `skills/implement/SKILL.md`'s pseudo-code are **not** equal (a plain string-inequality check, with a positive control that sets them equal and turns red).

---

### L1-002 [P2] `.gitlab-ci.yml:301` uses `read -r -d ''`, a bashism, in a blocking job whose own comment 25 lines above states the runner's script shell is not guaranteed to be bash

**File**: `/Users/darryl.porter/projects/marketplace/.gitlab-ci.yml:301` (fix landed for CA-437)

```yaml
      while IFS= read -r -d '' cmd; do          # :301
```

`read -d` is a bash extension. POSIX `read` accepts only `-r`; dash has no `-d`, and BusyBox `ash` -- the shell in the Alpine images every `<<: *alpine_edm` consumer uses -- supports `-r -n -p -s -t -u` but **not** `-d`. `before_script` (`:283`) `apk add`s bash, but installing bash does not change which interpreter the runner uses to execute the `script:` block.

The job's *own* comment is the evidence that this was known and then contradicted:

# command is written to its own temp file first: `bash -n <(cmd)` process substitution needs
# bash itself as the invoking shell, which is not guaranteed for the runner's script stage (see
# the POSIX-sh-safe notes elsewhere in this file).                                   # :274-276

The author deliberately avoided `<(...)` for exactly this reason, then used `read -d` twenty-five lines later. It is the only `read -d` in the file; every other job body is POSIX-sh-safe (`for f in ...`, `[ ... ]`, `$(( ))`, no `[[ ]]`), so the consistency filter does not clear it -- this is a lone deviation from the file's established style, not the style.

Failure mode on an `sh` runner: `read: unrecognized option -d` makes the `while` condition false immediately (errexit does not apply to a loop condition), the body never runs, `COUNT` stays `0`, and the CA-437 cross-check at `:320` fires:

lint:hooks-shell: FAILED -- checked 0 command(s) but hooks.json declares 9 (extraction/splitting regression, CA-437)

So it fails **closed and loudly** -- good -- but with a diagnostic naming the wrong cause, on a blocking job that gates the plugin's most privileged shell surface, and the next maintainer will hunt a jq extraction bug that does not exist. `lint:hooks-shell` has never run against a live runner fleet (CA-436's own investigation step was never executed), so nothing has yet exercised this path.

**Concrete fix** -- replace the NUL loop with a POSIX-safe indexed extraction that preserves CA-437's unforgeable record boundary:

```sh
EXPECTED_COUNT="$(jq '[.hooks | to_entries[] | .value[] | .hooks[] | select(.type=="command")] | length' plugins/edm/hooks/hooks.json)"
IDX=0
while [ "$IDX" -lt "$EXPECTED_COUNT" ]; do
  cmdfile="${TMP}/hook-$((IDX + 1)).sh"
  jq -r --argjson i "$IDX" \
    '[.hooks | to_entries[] | .value[] | .hooks[] | select(.type=="command") | .command][$i]' \
    plugins/edm/hooks/hooks.json > "$cmdfile"
  IDX=$((IDX + 1))
  COUNT=$((COUNT + 1))
  ...
done
```

This never splits on any delimiter at all, so the multi-line `.command` case CA-437 was about cannot recur, and `COUNT` is derived from the same jq length the cross-check compares against. Keep the `:320` cross-check; retarget its message at a jq/index mismatch. Alternatively, if the fleet's shell is confirmed to be bash, add `shell: bash` (or an explicit `bash -c` wrapper) to the `.alpine_edm` anchor and delete the `:274-276` caveat -- but do not leave the file asserting one thing and doing another.

---

### L1-003 [P2] The CA-471 completeness backstop silently skips the last lens in `lenses-run.txt` when that file has no trailing newline -- and on a full round the last lens is L11

**File**: `plugins/edm/bin/edm-state:4460-4466`

```bash
while IFS= read -r _lens; do
  [[ "$_lens" =~ ^L[0-9]+$ ]] || continue
  _lens_file="${_pass_dir}/lens-${_lens}.jsonl"
  if [[ ! -s "$_lens_file" ]] || ! jq empty "$_lens_file" >/dev/null 2>&1; then
    _missing="${_missing:+$_missing }${_lens}"
  fi
done < "$_manifest"
```

`read` returns non-zero when it hits EOF with an unterminated final line, so the loop body does not execute for that line -- the classic bash idiom gap. `_lens` holds `L11` but the check never runs on it.

Why this input class is different from every other `while read` in the tree: `lenses-run.txt` is authored by an **LLM agent** with the `Write` tool (`skills/code-audit/SKILL.md:78`: "Write `${OUTPUT_DIR}/lenses-run.txt` -- one lens ID per line"). Every other `done < "$file"` site in the plugin reads a file the plugin itself generated with `printf '%s\n'` (`edm-check-grants:562` reads `AGENT_TSV`), a committed config with a guaranteed trailing newline (`edm-check-vocabulary:158`, `:233`), or a `.jsonl` (`score-artifacts.sh:500`). A missing trailing newline is not plausible for any of those; it is entirely plausible for a model-written text file.

The consequence is precisely the hole CA-471 exists to close, positioned at the worst spot: on a full round the last manifest line is `L11`, and a round that truncated its delivery is exactly the round most likely to be missing its *last* lens. `wave6-smoke.sh:870` and `:881` both seed the manifest with `printf 'Round type: full\nL1\nL2\n'` -- trailing newline present -- so the suite cannot detect this.

**Not covered by CA-471's own prescription** and not a re-flag of it: CA-471 is filed and closed on the gate's existence; this is a defect inside the shipped gate.

**Concrete fix** -- one line, plus a case:

```bash
while IFS= read -r _lens || [[ -n "$_lens" ]]; do
```

and in `wave6-smoke.sh`'s CA-471 block, seed one manifest without the final newline and assert the gate still fires:

```bash
"$EDM_STATE" init CA471NONL >/dev/null
mkdir -p "$TMP/SRD/CA471NONL/code-audit/pass-1_2026-08-16"
printf 'Round type: full\nL1\nL2' > "$TMP/SRD/CA471NONL/code-audit/pass-1_2026-08-16/lenses-run.txt"  # no trailing \n
printf '{"lens":"L1"}\n' > "$TMP/SRD/CA471NONL/code-audit/pass-1_2026-08-16/lens-L1.jsonl"
"$EDM_STATE" audit-round-start CA471NONL code >/dev/null
ca471nonl_out="$("$EDM_STATE" audit-round-complete CA471NONL code 2>&1)"
check "CA-471 -- an unterminated final manifest line is still checked" "for: L2" "$ca471nonl_out"
```

---

### L1-004 [P2] `edm-init:212` cites "edm-state init (line 139, above)"; the call is at `:165` -- a fresh instance of the CA-406/CA-439 stale-citation class at a third file neither finding names

**File**: `plugins/edm/bin/edm-init:212`

```bash
  # Post-checkout correction (F2a, D3): edm-state init (line 139, above) snapshotted
  # initiative_branch from HEAD *before* this block ran, so it recorded the branch the
  # user was on beforehand -- not the branch actually occupied now.
```

`edm-state init "$PREFIX"` is at `:165`. Line 139 is inside the `decisions.md` heredoc (`| # | Decision | Chosen | Rationale | Date |`), so a reader following the pointer lands on a markdown table template. The comment is load-bearing -- it is the entire justification for the unconditional `edm-state record-branch "$PREFIX"` call at `:219`, and a maintainer who cannot locate the snapshot it describes has no way to check whether the correction is still needed.

Distinct from the open findings in the class by location, and distinct from CA-439 in status: CA-439's two `edm-state` sites were fixed this round (`:2326` now anchors by name), which is what makes the survival of an identical defect one file over worth flagging rather than folding in. The same commit range that applied CA-406's "anchor by name, drop the number" prescription to `edm-state` and `hooks.json` did not sweep `bin/`'s other scripts for the same shape.

Overlaps L6 (comment accuracy); expect the synthesizer to merge if L6 filed it independently.

**Concrete fix** -- apply CA-406's own remediation verbatim:

```bash
  # Post-checkout correction (F2a, D3): the `edm-state init` call above (named by anchor, not
  # line number -- CA-406) snapshotted initiative_branch from HEAD *before* this block ran, ...
```

Do not renumber; a fresh number regresses on the next insertion. While in the file, sweep the other `bin/` helpers for the same shape -- this one was found by reading, not by any mechanism.

---

## Noted / Not Actionable

- **CA-401 still open** (`wave6-smoke.sh:290, :1057, :1074, :3441, :3448, :3460`) -- six unguarded `grep -c`/`grep -cE` captures under `set -euo pipefail`. Confirmed present at shifted line numbers; not re-filed.
- **CA-453 still open** -- `Gates approved` has one hit in `bin/tests/` and it is a comment (`wave6-smoke.sh:649`); `required_gate_count` appears in no test file. All four prescribed assertions still absent. Not re-filed.
- **`--accept-p2-debt` is silently ignored when `cmd_audit_converged` exits 3 on a `schema_version < 2` initiative** (`edm-state:2263-2266`). The warn-and-proceed arm approves the gate without recording debt fields. Harmless: exit 3 means there is no ledger, so there is no debt to record, and the plain approval is the documented pre-wave-B degradation (CA-182). Filter 1.
- **`edm-check-grants:511` derives `task_ln` from a whole-file grep while `needs_task` is derived from `$body`**, so the reported line could fall in frontmatter. Byte-for-byte the same shape as the pre-existing `AskUserQuestion` rule at `:492-494`. Filter 3.
- **`edm-check-grants:509`'s spawn regex requires `spawn` and `edm-` on the same line**, so a multi-line spawn instruction escapes the new `missing-task-grant` rule. No live instance: the only two skills without `Task` (`metrics`, `verify-runtime`) contain no spawn instruction in any form. Recorded as a known limit of the rule, not a defect.
- **`wave7-smoke.sh:4696-4708` reuses one variable (`t67ac8_cmd`) for two different subjects** -- the hook `.command` for `:4704`/`:4706`, then the delegate script's contents from `:4708` on. Verified correct as written (the reassignment sits between the two groups), but the reuse is a trap for the next editor. Readability, not correctness.
- **`edm-lint-artifacts:137`'s first-stage trap cleans up and resumes on INT/TERM/HUP** rather than exiting with a signal-shaped code. It is deliberately transitional -- replaced at `:149-152` by the full four-trap layer as soon as the second `mktemp` returns -- and the comment at `:134-136` states the purpose (closing the leak window CA-447 named). The window is one `mktemp` wide. Filter 2.
- **`edm-lint-staged-artifacts:58`'s `[ -n "$x" ] && a="$(...)" || a="$x"`** three-clause chain is correct for all four input combinations (empty `repo_root`, unreadable dir, both). Verified by case analysis; no `set -e` in this script (`:25` is `set -uo pipefail`). Not a bug.
- **No unresolved `TODO` / `FIXME` / `HACK` / `NotImplementedError` / stub return anywhere in scope.** Case-insensitive sweep of `bin/`, `bin/tests/`, `evals/`: every hit is either prose about placeholder *pricing* (`edm-state:539-541`, `:1482`), a documentation-placeholder ignore list (`wave7-smoke.sh:41, :83, :163-166`), a Mermaid fixture's deliberate comment content (`bin/tests/fixtures/mermaid/valid/v03-comment-semicolon.md:9`), or the `vague-ac-patterns.txt:29` detection token. Zero live markers, zero `:` -where-logic-belongs, zero always-same-literal returns.
- **CA-130 (no `Bash`, no `Write` in the delivered lens tool set)** -- reproduced for the 9th/10th consecutive round. Remains NOTED per its recorded do-not-re-file disposition. The report is delivered in the agent message per the fallback clause.

---

