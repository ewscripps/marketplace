# Code Audit Pass 3 -- Lens L1: Logic, Correctness & Completeness

**Round**: 3 (2026-08-08)
**Scope**: `plugins/edm/**` (bin/, bin/tests/, agents/, skills/, evals/, hooks/, docs/, monitors/) plus repository-root `CLAUDE.md`, `.gitlab-ci.yml`, `.gitignore`.

## Part A -- Verdicts on L1-tagged open ledger entries

Filtered `findings-ledger.md` to every row whose `Lens(es)` includes L1 **and** whose `Status` is `open`: CA-002, CA-007, CA-011, CA-005, CA-017, CA-071, CA-133, CA-134, CA-135, CA-136. CA-182 is carried here as well: its Lens column reads `operator`, but it is a pure control-flow defect (a gate bypass) and it is the round's only remaining P0.

Each verdict was reached by reading the current code, not by trusting the remediation record.

| ID | Ledger sev | Verdict now | Evidence |
|----|-----------|-------------|----------|
| CA-002 | P0 | **FIXED** | `plugins/edm/bin/tests/wave7-smoke.sh:3323-3439` + `:3443-3485` |
| CA-182 | P0 | **STILL OPEN** | `plugins/edm/bin/edm-state:1679-1688` |
| CA-007 | P1 | **FIXED** | `plugins/edm/evals/run-eval.sh:465-479` |
| CA-011 | P1 | **FIXED, one residue** | `plugins/edm/hooks/hooks.json:86` -- see L1-03 |
| CA-005 | P2 | **FIXED** | `plugins/edm/bin/_edm-cli-lib.sh:28-30`; 12 sourcing sites |
| CA-017 | P2 | **PARTIALLY FIXED** | `edm-lint-artifacts:24-37` fixed; `:43-44`, `:53-55` still wrong -- see L1-04 |
| CA-071 | P2 | **FIXED** | `.gitlab-ci.yml:246-252` |
| CA-133 | P2 | **FIXED** | `plugins/edm/bin/edm-state:4024` + `:3985-3990` |
| CA-134 | P2 | **FIXED at cited site; live at sibling site** | `edm-state:587`, `:602` fixed; `edm-state:1045-1046` unfixed -- see L1-02 |
| CA-135 | P2 | **FIXED** | `plugins/edm/bin/edm-state:2184-2189`, `:2243` |
| CA-136 | P2 | **FIXED** | `plugins/edm/bin/edm-state:2072` |

**CA-002 -- FIXED.** `wave7-smoke.sh:3323-3439` (`ca002_insertion_case`) now drives the real insertion branch: copies the whole plugin to a scratch tree, seeds `audit-srd.md` with two novel `### ` headings plus one normalized-duplicate, and invokes `bash "$scratch/plugins/edm/bin/edm-state" update-patterns ZCA2 srd` by explicit path with a scratch `EDM_SRD_ROOT` (`:3351`). Asserts `2 new finding(s) appended` (`:3352`), `+2` heading delta (`:3357`), section containment (`:3367-3371`), de-duplication of the third title (`:3374-3379`), `patterns_updates.srd.new_findings == 2` (`:3410-3413`), idempotence (`:3418-3427`), and the four-heading contract before and after (`:3398`, `:3430`). `:3443-3485` covers the missing-target-heading skip with a byte-hash equality check. The committed-plugin-source half is addressed by the scratch-copy design, documented at `:3315-3319`.

**CA-007 -- FIXED.** `run-eval.sh:469-471` adds `case "$xy" in R*|C*) path="${path##* -> }" ;; esac`, so `R  old -> new` yields `new`. Regression coverage at `wave7-smoke.sh:3501+`.

**CA-011 -- FIXED, one residue.** At `hooks.json:86`: no longer branches on any non-zero (`code -eq 1` blocks, `code -eq 2` reports only); `edm-state resolve-dir "$p" >/dev/null 2>&1 || continue` skips unresolvable prefixes so a staged initiative deletion no longer blocks; `srd_root` is derived from `EDM_SRD_ROOT`/`CLAUDE_PLUGIN_OPTION_SRD_ROOT` with awk indices computed from `length(root)+1`. The exit-1-vs-2 question settles in the code's favour: a PreToolUse hook blocks on exit 2, which is what the hook returns for a real violation. Residue filed as L1-03.

**CA-005 -- FIXED.** `_edm-cli-lib.sh` holds the only copy of the extractor. Sourced by `edm-state:63`, `edm-lint-artifacts:61`, `edm-check-grants:65`, `edm-check-vocabulary:57`, `edm-init:20`, `edm-compare-eval:37`, `edm-validate-prefix:19`, `edm-check-skill-sync:31`, `edm-sync-canonical-sections:42`, `evals/run-eval.sh:63`, `evals/score-artifacts.sh:111`, `evals/tiering-matrix.sh:69`. `edm-sync-canonical-sections` now has real sentinels (`:2`/`:35`) instead of keying on `set -euo pipefail`. Both prescribed CI bans landed at `.gitlab-ci.yml:112-125`.

**CA-133 -- FIXED.** `edm-state:4024` appends `$'\n'` after the command substitution. Traced end to end: each entry begins and ends with exactly one `\n`, so `_splice_pattern_file`'s `printf '%s'` (`:3988`) emits a blank line before every `###` and a terminating newline before `tail -n "+${insert_line}"` resumes. `wave7-smoke.sh:3404-3405` asserts the `curated prose.## ` concatenation signature is absent.

**CA-135 -- FIXED.** `edm-state:2184-2189` refuses when the coerced value differs from the raw value. Verified against three shapes: JSON number `2` and string `"2"` round-trip equal and proceed; `2.0` coerces to `0`, mismatches, and dies. `:2243` prints the raw value.

**CA-136 -- FIXED.** `edm-state:2072` adds `jq -e . "$state" >/dev/null 2>&1 || die "get-coverage: unparseable state file at $state"`; all four renderers carry `|| true`. Covered at `wave7-smoke.sh:4590-4603`.

---

## Findings (L1: Logic, Correctness & Completeness)

### L1-00 [P0] Code-audit gate is still unconditionally approvable at `schema_version: 1`

**File**: `plugins/edm/bin/edm-state:1679-1688` (write at `:1696-1703`)

Carry-forward of **CA-182**, verified still open.

```bash
ag_schema_class2="$(schema_at_least "$ag_schema_version" 2)"
if [[ "$ag_schema_class2" == "2" ]]; then
  conv_out="$(cmd_audit_converged "$prefix" 2>&1)" || conv_ec=$?
  [[ $conv_ec -eq 0 ]] || die "code-audit gate refused for ${prefix}: ${conv_out}"
else
  record_degraded_check "$prefix" "approve-gate:code-audit-convergence-precheck" "schema_version ${ag_schema_version:-absent} < 2"
fi
```

The `else` arm records a degraded check and falls straight through to the unconditional `.code_audit_converged = true` at `:1696-1703`. `_cmd_init_render` still writes the literal `1`, nothing auto-migrates, and nothing prompts `migrate-schema` -- so every initiative created by the current plugin version has a bypassable code-audit gate. CA-183's sibling fix **did** land, at `:1666-1670`, and its comment at `:1658-1665` explicitly names CA-182 as the same bypass shape; the pair was remediated in the write-up but only one arm shipped.

**Fix** -- make the precheck unconditional and degrade only the ledger-shape requirement:

```bash
  # The convergence precheck is NEVER skipped -- only its exit-3 (no JSONL ledger) arm degrades
  # for a pre-wave-B initiative, matching EDMV3-T28 AC7 without reopening CA-182's bypass.
  local conv_out conv_ec=0
  conv_out="$(cmd_audit_converged "$prefix" 2>&1)" || conv_ec=$?
  if [[ $conv_ec -eq 3 && "$ag_schema_class2" != "2" ]]; then
    record_degraded_check "$prefix" "approve-gate:code-audit-ledger-shape" \
      "schema_version ${ag_schema_version:-absent} < 2 and no findings-ledger.jsonl"
    echo "edm-state approve-gate: [warn] no JSONL findings ledger and schema_version ${ag_schema_version:-absent} < 2 -- convergence not computable" >&2
  else
    [[ $conv_ec -eq 0 ]] || die "code-audit gate refused for ${prefix}: ${conv_out}"
  fi
```

Add a `wave6-smoke.sh` case at `schema_version: 1` with a blocking finding in `findings-ledger.jsonl`, asserting `approve-gate <PFX> code-audit` exits non-zero and leaves `code_audit_converged` unset.

---

### L1-01 [P1] `get_session_tokens_since` emits a third `attribution_mode` value that no consumer, document or test accepts

**File**: `plugins/edm/bin/edm-state:341` and `:371`

```jq
attribution_mode: (if $acc.bad > 0 then "unparseable" else $mode end)
```

The CA-060 remediation replaced `jq -s` with `jq -Rn`/`reduce inputs` and added a `bad` counter for lines failing `fromjson?` -- then reported that counter *through* a field that is a two-value enum everywhere else:

- `plugins/edm/CLAUDE.md:427` -- "`attribution_mode` -- `"scoped"` or `"whole-directory"`"
- `plugins/edm/CLAUDE.md:436` -- "records `"scoped"` when this succeeded, or `"whole-directory"` on the pre-T52 fallback"
- `CLAUDE.md` state-field table, audit-round row -- "`string enum scoped | whole-directory`"
- `plugins/edm/bin/tests/wave6-smoke.sh:3427-3434` -- a `case` that `fail`s on anything else

Three consequences. (1) One torn line in a live-appended session JSONL -- the exact condition CA-060 was filed about, and routine when `phase-complete` runs while Claude Code is still appending -- fails the blocking `test:smoke` job with `attribution_mode was 'unparseable', expected scoped or whole-directory`. (2) The value is written into committed state at `:1918` and `:3391` and rendered by `metrics-report`; `edm-state validate` has no anomaly for an out-of-enum value. (3) It **destroys the information the field exists to carry** -- a reader can no longer tell whether an `unparseable` figure came from the scoped driving-session read or the whole-directory fallback, which is the only question `attribution_mode` was added to answer.

**Fix** -- keep the enum two-valued; report the parse failure in its own field. At `:341` and `:371`:

```jq
          attribution_mode: $mode,
          unparseable_lines: $acc.bad
```

Then read `unparseable_lines` alongside `attribution_mode` in `cmd_phase_complete` (`:1884-1894`) and `_cmd_audit_round_complete_body` (`:3366-3376`), pass it as `--arg ul`, and add `| . + {unparseable_lines: ($ul|tonumber)}` to both jq programs. Add a `TORN_TOKEN_LINES` informational anomaly in `state_anomalies` when `> 0`, and add the field to `CLAUDE.md`'s state-field table with a C-4 "absent reads as 0" note. `wave6-smoke.sh:3427` then needs no change.

---

### L1-02 [P1] `with_state_lock`'s mkdir branch reintroduces the exact `$?`-on-the-next-line defect CA-134 was filed to remove -- on the branch macOS always takes

**File**: `plugins/edm/bin/edm-state:1045-1046`

```bash
    _EDM_TRAP_DEPTH=1
    ( "$@" )
    local ec=$?
    _EDM_TRAP_DEPTH=0
    rm -rf "$lockdir"
    _restore_trap EXIT "$old_exit"
    ...
    return $ec
```

`( "$@" )` sits in a non-tested position under `set -e`. Four lines above, the flock branch does it correctly -- `( flock -w 10 200 || exit 99; "$@" ) 200>"${lockfile}" || _lock_ec=$?` (`:944`), with the rationale spelled out at `:940-942`. And `write_atomic:581-586`, rewritten by CA-134's remediation *this round*, states the rule generally: *"guard the capture on the SAME statement, not on the line after it -- a bare `"$@" > "$tmp"` followed by a separate `ec=$?` is only safe under set -e because every current call site happens to sit in an errexit-suspended position."* The remediation applied it to `write_atomic`'s two sites and skipped the sibling function in the same file.

`with_state_lock` has bare callers today: `rmw_state:654` is `rmw_state`'s last command, and `rmw_state` is called bare from ~30 mutators (`cmd_srd_version:2125`, `cmd_approve_gate:1625`/`:1651`/`:1696`/`:1711`, `record_artifact_hash:186`, ...). On those paths a non-zero locked body aborts the shell **at line 1045**: `_EDM_TRAP_DEPTH` is never reset to `0`, the saved EXIT/INT/TERM/HUP traps are never restored, and `return $ec` never runs. Worse than `write_atomic`'s version was -- what gets skipped is lock-release bookkeeping, not a `rm -f`. And since macOS has no `flock(1)`, the mkdir branch is the one every developer machine takes; the correct branch is the Linux/CI one.

**Fix**:

```bash
    _EDM_TRAP_DEPTH=1
    local ec=0
    # CA-134: guard the capture on the SAME statement -- see write_atomic's note at :581.
    ( "$@" ) || ec=$?
    _EDM_TRAP_DEPTH=0
```

Add a `wave7-smoke.sh` case that forces the mkdir branch (a `PATH` that hides `flock`), calls `rmw_state` bare with a deliberately failing jq filter, and asserts both a non-zero exit **and** that `${lockbase}.lockd` is gone -- which the current code achieves only via the EXIT trap, not its own release path.

---

### L1-03 [P2] The commit hook's `srd_root` is normalized for a leading `./` but not a trailing `/`, silently disabling all commit-time artifact enforcement

**File**: `plugins/edm/hooks/hooks.json:86`

```sh
srd_root="${EDM_SRD_ROOT:-${CLAUDE_PLUGIN_OPTION_SRD_ROOT:-./SRD}}"; srd_root="${srd_root#./}";
... awk -v root="$srd_root" '{ rl=length(root)+1; if (substr($0,1,rl)==(root "/")) { ... } }'
```

Introduced by the CA-023 remediation. `EDM_SRD_ROOT="SRD/"` -- a natural way to write a directory value, and one every *other* consumer accepts because `edm-state` joins with `"${SRD_ROOT}/${prefix}/..."` and the filesystem collapses `SRD//` -- makes the awk test compare the staged path's first five characters against `SRD//`. That never matches, `prefixes` is empty, `test -z "$prefixes" && exit 0` fires, and all commit-time enforcement is gone with no diagnostic. An absolute `EDM_SRD_ROOT` fails identically, because `git diff --cached --name-only` prints repo-relative paths.

**Fix** -- insert immediately after the existing `srd_root="${srd_root#./}"`:

```sh
while [ "${srd_root%/}" != "$srd_root" ]; do srd_root="${srd_root%/}"; done;
case "$srd_root" in
  /*) echo "[EDM] srd_root is absolute (${srd_root}); commit-time artifact lint cannot match repository-relative staged paths -- set EDM_SRD_ROOT to a repo-relative path" >&2; exit 0 ;;
esac;
test -n "$srd_root" || exit 0;
```

Add a `wave7-smoke.sh` case that extracts the hook command from `hooks.json` and runs it against a scratch repo with `EDM_SRD_ROOT=SRD/`, asserting the violation is still detected.

---

### L1-04 [P2] Two statements in `edm-lint-artifacts`' help block were inverted by this round's own remediation

**File**: `plugins/edm/bin/edm-lint-artifacts:43-44` and `:53-55`

```
# ... The current
# PreToolUse git-commit hook blocks on any non-zero exit and prints one generic remediation line
# for both classes of failure.
...
# ... The git-commit hook's staged-path matcher is still the literal `^SRD/`,
# so relocating srd_root drops that automatic hook enforcement unless the hook is updated too.
```

This is CA-017's own class -- a help block whose exit-code contract disagrees with the code -- *reopened* by the remediation rather than closed by it. Both sentences were true before this round and are false now:

- CA-011's fix made the hook branch on `code -eq 1` vs `code -eq 2` and print *different* lines for the two classes (`hooks.json:86`).
- CA-023's fix made the hook derive `srd_root` from the env vars; the matcher is no longer literal `^SRD/`. `plugins/edm/CLAUDE.md` was updated to say so ("both honor `${user_config.srd_root}` ... with no separate hook-matcher update required"), so the two documents now contradict each other -- and this one is the `--help` a contributor reads first. Note the internal contradiction: `:42` says "Direct callers, CI, and tests can distinguish exit 1 from exit 2"; the very next sentence denies it.

**Fix** -- replace `:43-44` with:

```
# ... The PreToolUse git-commit hook treats exit 1 as a
# real violation and blocks the commit; exit 2 (setup/usage) is reported to stderr and does not
# block. The two classes get distinct remediation lines (hooks/hooks.json).
```

and `:53-55` with:

```
# Direct invocations and the PreToolUse git-commit hook both honor EDM_SRD_ROOT and
# CLAUDE_PLUGIN_OPTION_SRD_ROOT (AC9, CA-023), so a relocated tree is linted and enforced at commit
# time with no separate hook-matcher update. The hook's staged-path prefix is derived from that same
# value; give it a repo-relative path with no trailing slash.
```

Same edit is needed on `plugins/edm/CLAUDE.md`'s `bin/` table row for `edm-lint-artifacts`, which still says "four violation classes" and enumerates four while the tool emits six (`attribution`, `unicode`, `leaked-tool-tag`, `mermaid-semicolon`, `unterminated-fence`, `scan-error`, plus `unreadable`) -- CA-017's undercount, in a second file.

---

### L1-05 [P2] `_p95` floors where nearest-rank requires ceiling, so no timing mode reports a p95 and every published budget figure is systematically optimistic

**File**: `plugins/edm/bin/tests/timing.sh:52-63`

```awk
      idx = int(0.95 * NR)
      if (idx < 1) idx = 1
      if (idx > NR) idx = NR
      print a[idx]
```

Docstring at `:52`: "*integer p95 (nearest-rank)*". Nearest-rank p95 is `ceil(0.95*N)`; awk's `int()` truncates. For every sample size the harness uses, the returned value is not the p95:

| Mode | Samples | `int(0.95N)` | `ceil(0.95N)` | Actually reported |
|---|---|---|---|---|
| `--subcommands` (`:112`, `:123`) | 10 | 9 | 10 | 9th of 10 -- the p90 |
| `--phase-complete` (`:142`, `:153`) | 5 | 4 | 5 | 4th of 5 -- the p80 |
| `--ledger` (`:185`, `:194`) | 5 | 4 | 5 | p80 |
| `--session-start` (`:229-230`) | 5 | 4 | 5 | p80 |
| `--lint` (`:258`) | 5 | 4 | 5 | p80 |
| `--mermaid-ratio` (`:289`, `:300`) | 3 | 2 | 3 | 2nd of 3 -- the **median** |

The slowest sample is always discarded, so every figure is biased low against the budget it is compared to. The harness header at `:7` says "*Every mode is a REAL measurement ... no numbers are invented*", and its outputs are the committed evidence for the 3,000 ms commit-path and 60,000 ms CI budgets in `plugins/edm/CLAUDE.md`, the 2,000/500/1,000 ms figures in EDMV3-T67's ACs, and the 1.19x mermaid-ratio sample in `plugins/edm/CHANGELOG.md`.

**Fix**:

```awk
      # nearest-rank: ceil(0.95 * NR), without a ceil() builtin (not portable across
      # bwk awk / mawk / busybox awk).
      idx = int(0.95 * NR); if (idx < 0.95 * NR) idx = idx + 1
      if (idx < 1) idx = 1
      if (idx > NR) idx = NR
      print a[idx]
```

Separately raise the sample counts -- three and five samples cannot support a 95th percentile at all. Either take 20 samples so `ceil(0.95*20) = 20` is a real tail measurement, or rename the emitted key to `max_ms` and update the four consuming documents. Re-run every mode and re-record the figures in `CHANGELOG.md` and `CLAUDE.md`; the published numbers were produced by the floored statistic.

---

### L1-06 [P2] `--mermaid-ratio` reports a raw millisecond count as a ratio when the baseline measures 0 ms -- the normal case on the perl-less images the timer fallback exists for

**File**: `plugins/edm/bin/tests/timing.sh:302-303`

```bash
ratio="$(awk -v a="$p95_base" -v b="$p95_mermaid" 'BEGIN{printf "%.2f", b/(a>0?a:1)}')"
echo "TIMING mermaid_ratio baseline_p95_ms=${p95_base} with_mermaid_p95_ms=${p95_mermaid} ratio=${ratio}x (budget: <= 1.40x)"
```

The `(a>0?a:1)` guard avoids a divide-by-zero abort but substitutes a wrong answer for a missing one: when `a == 0` the printed `ratio` is `b` -- a duration in milliseconds -- labelled `ratio=...x` and compared against `<= 1.40x`. `a == 0` is not exotic: `_now`'s documented perl-less fallback (`:34-41`) has whole-second resolution, so on any Alpine-like image without perl a lint pass over the 30-file/333-line fixture measures 0 ms for every sample and `_p95` returns 0. The mode then prints e.g. `ratio=40.00x (budget: <= 1.40x)` -- a ~28x apparent budget breach that is purely a timer artifact, in the one mode whose entire output is a single ratio, on exactly the image class CA-158's fallback was added to support.

**Fix**:

```bash
if [[ "$p95_base" -le 0 || "$p95_mermaid" -le 0 ]]; then
  echo "TIMING mermaid_ratio baseline_p95_ms=${p95_base} with_mermaid_p95_ms=${p95_mermaid} ratio=UNMEASURABLE (timer resolution too coarse for this fixture -- install perl for sub-second resolution, or raise --files/--lines-per-file until both baselines exceed 0 ms)" >&2
  exit 3
fi
ratio="$(awk -v a="$p95_base" -v b="$p95_mermaid" 'BEGIN{printf "%.2f", b/a}')"
```

---

### L1-07 [P2] `HANDOFF.md` is written with no terminating newline

**File**: `plugins/edm/bin/edm-state:4537-4539`, with `_print_literal` at `:631-633`

```bash
    printf '%s\n' "${notes}"
  })"
  write_atomic "$handoff_path" _print_literal "$handoff_content" || die "write-handoff: failed to write ${handoff_path}"
```

`handoff_content="$( { ... } )"` strips every trailing newline the render block emitted, and `_print_literal` writes with `printf '%s'` -- no newline. The committed, generated `HANDOFF.md` therefore ends mid-line on every write. Same dropped-trailing-newline mechanism as CA-133 (`printf '%s'` after a command substitution), in the sibling writer the CA-027 remediation introduced when it moved HANDOFF.md onto `write_atomic`. `edm-state` is the only writer, it regenerates on every phase/gate/checkpoint, and the file is git-tracked -- so every diff carries `\ No newline at end of file` and any appending tool concatenates onto the user's last Notes line.

**Fix** -- add a newline-terminating renderer beside `_print_literal` (do **not** change `_print_literal`; the pattern-library splice at `:3988` depends on its exact no-newline behaviour):

```bash
_print_line() {
  printf '%s\n' "$1"
}
```

then `write_atomic "$handoff_path" _print_line "$handoff_content" || die ...`. Add a `wave7-smoke.sh` assertion that `tail -c 1 HANDOFF.md` is a newline, and run `edm-state write-handoff` once over every tracked initiative to normalize the committed copies.

---

### L1-08 [P2] `cmd_update_patterns` re-derives the plugin root from `$0` though the `BASH_SOURCE`-derived `SCRIPT_DIR` is already a global in the same file

**File**: `plugins/edm/bin/edm-state:4053-4061`

```bash
  local _s="$0"
  if [[ "$_s" != */* ]]; then
    _s="$(command -v "$_s" 2>/dev/null || true)"
  fi
  local script_dir
  script_dir="$(cd "$(dirname "${_s:-$0}")" 2>/dev/null && pwd || echo ".")"
  local patterns_dir="${script_dir}/../docs/audit-patterns"
```

`:62` already computes `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"` -- correct under every invocation shape including `source`. This second `$0`-derived copy is not: `edm-state` is deliberately sourceable (guarded dispatch at `:4554`; `wave7-smoke.sh:4721` and `:4787` source it to unit-test `pattern_insert_line_for` and `_cmd_update_patterns_body`). Under `source`, `$0` is the sourcing shell (`bash`), `command -v bash` resolves to `/bin/bash`, and `patterns_dir` becomes `/bin/../docs/audit-patterns` -- outside the plugin. Latent today because the tests pass an explicit pattern-file argument to `_cmd_update_patterns_body`; the next helper that calls `cmd_update_patterns` on a sourced `edm-state` gets a silent `pattern file not found ... (skipping)` (`:4085`) and a passing exit 0. Also the derivation-divergence class CA-049 raised.

**Fix** -- delete `:4053-4060` and use the existing global:

```bash
  # SCRIPT_DIR (:62) is BASH_SOURCE-derived, so it is correct when this file is sourced as well as
  # when it is executed -- do not re-derive from $0 (CA-049).
  local patterns_dir="${SCRIPT_DIR}/../docs/audit-patterns"
```

---

### L1-09 [P2] `edm-mermaid-rules.awk`'s header claims all three consumers share its rules, but `edm-lint-artifacts` never loads the file and still carries its own copies

**File**: `plugins/edm/bin/edm-mermaid-rules.awk:19-26`; surviving copies at `plugins/edm/bin/edm-lint-artifacts:176-219`

Header states: *"...plus `bin/edm-lint-artifacts`'s own `mermaid_scan_awk` helper each carried an independent, byte-equivalent copy of `strip_entities`/`is_violation` ... All three consumers now call the same fence-recognition functions below."*

`edm-lint-artifacts:168` invokes `awk -v scan_file=... '<inline program>'` with **no** `-f edm-mermaid-rules.awk`, and defines its own `strip_entities` (`:176-187`) and `is_violation` (`:188-219`). Only two of three consumers -- `_edm-lint-lib.sh:74` and `evals/score-artifacts.sh` -- load the shared file. The copies are logically identical to `mermaid_strip_entities`/`mermaid_is_violation` today (compared rule by rule: the `%%` carve-out, the `classDef|style|linkStyle` carve-out, the single trailing-`;` strip, the five label-span regexes, and the arrow/`:` sequence-message rule), so there is no live divergence -- but the header's claim is what a future editor will rely on when fixing one copy, and `edm-lint-artifacts` is the *blocking* consumer (`lint:artifacts` plus the git-commit hook).

**Fix** -- preferred, make the claim true (the call is already one process per file):

```bash
  awk -f "$MERMAID_RULES_AWK" -v scan_file="$MERMAID_SCAN_FILE" '
    BEGIN { ... }
    {
      sub(/\r$/, "")
      if (!(FNR in mer)) next
      if (FNR in ign) next
      if (index($0, "<!-- edm-lint-ignore -->") > 0) { print "U\t" FNR "\t"; next }
      if (mermaid_is_violation($0)) print "V\t" FNR "\t" substr($0, 1, 120)
    }
  ' "$file"
```

Delete `edm-lint-artifacts:169-219` and add `MERMAID_RULES_AWK="${SCRIPT_DIR}/edm-mermaid-rules.awk"` beside the `source` lines at `:61-62`. If the copies are instead kept for the per-file-fork budget, correct the awk header at `:19-26` to say *two* consumers and why the third is exempt, and add the missing `wave7-smoke.sh` assertion that both implementations return the same verdict for every fixture under `bin/tests/fixtures/mermaid/`.

---

## Noted / Not Actionable

1. **`cmd_migrate_schema`'s comment contains an embedded self-correction** -- `edm-state:2179-2181` reads "...always satisfies `1 -le 0`... no, wait: coercion makes `current_version=0`...". The reasoning it lands on is correct and matches the code; prose form is L6's scope.
2. **`pattern_target_heading_for` ignores its argument and always returns the same heading** -- `edm-state:3903-3908`. Already demoted as CA-114: documented intentional extension point.
3. **`grep -qxF "$target_heading"` at `edm-state:4103` is fence-unaware** -- residual half of CA-056, but it is only a cheap existence pre-flight; `pattern_insert_line_for` (`:3935-3970`) *is* fence-aware and returns `0` for a fence-only match, which `:4032-4036` treats as a skip with no EOF fallback. Redundant, not wrong.
4. **`srand()` at `timing.sh:39` is now a dead call** -- CA-158's fix removed `rand()` from the expression but left the seeding. Harmless; L2 (dead code).
5. **`run-eval.sh:554` counts with `find -type d` while `:560` prunes from `ls -1t`'s all-entries listing** -- a non-hidden regular file can shift the `tail -n +K` offset by one. The `[ -d ] || continue` guard at `:564` prevents deleting non-directories, `evals/runs/`'s only tracked entry is the dotfile `.gitignore`, and worst case is one extra pruned run directory in a gitignored disk-only tree.
6. **`run-eval.sh:312`'s `rc=$?` sits three comment lines below its command** -- comments do not alter `$?`, `set -e` is deliberately omitted (documented `:47-52`), and `invoke_claude` is only called from an `if`.
7. **`edm-state:4599` calls `print_help "$0"` where ten siblings pass `"${BASH_SOURCE[0]:-$0}"`** -- reachable only from the dispatch guarded by `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` at `:4554`, so the two are equal by construction. Style (L10).
8. **`_p95` clamps `idx` to `[1, NR]` and returns `0` for an empty list** -- both are correct guards; the defect is the `int()` truncation (L1-05).
9. **No stubs, `TODO`, `FIXME`, `HACK`, `XXX`, `NotImplementedError` or placeholder-return functions in production code** -- a case-insensitive sweep of the whole tree returns only (a) `TodoWrite`/`TodoRead` grants, (b) prompt text *instructing against* stubs (`agents/edm-implementer.md:46-47`, `skills/implement/SKILL.md:67`/`:193`, `agents/edm-audit-logic.md:33-35`), (c) `evals/vague-ac-patterns.txt:29`, a detector pattern file, and (d) the deliberate `complete: false` stub `scores.json` at `run-eval.sh:126-130`, documented at `:107-111` and `evals/README.md:135`. `check_permission_rules` (`edm-state:893-916`) performs real introspection and no longer returns the EDMV3-T08 literal `prose-only`.
10. **~60 `xxx_ec=$?` lines in `wave6-smoke.sh`** -- all inside explicit `set +e`/`set -e` windows or after a `|| true`-guarded call; spot-checked `:72`, `:311`, `:1056`, `:2632`, `:3316`. Not the CA-134 class.
11. **`with_state_lock`'s `kill -0` error-text classification** (`edm-state:978-991`) -- matching `"not permitted"` is locale-dependent, but the failure direction is safe and the rationale is stated at `:956-963`. L3/L8 scope, deliberate.
12. **`run-eval.sh:151`'s `git add -A`** -- already demoted as CA-124: throwaway scratch repo only.

---

## Summary for the parent agent

- **Blocking set this round (L1)**: 1 x P0 (L1-00 / CA-182, unchanged), 2 x P1 (L1-01, L1-02), 7 x P2 (L1-03 ... L1-09).
- **Ledger reconciliation**: of the 10 L1-tagged open entries, **8 are fully fixed** (CA-002, CA-007, CA-011, CA-005, CA-071, CA-133, CA-135, CA-136), **2 are partial** (CA-017 -> L1-04; CA-134 -> L1-02). CA-182 remains open and is still the round's only P0.
- **Remediation-introduced defects**: L1-01 (CA-060's fix), L1-02 (CA-134's fix, applied to only one of two sibling functions), L1-03 (CA-023's fix), L1-04 (CA-011 + CA-023's fixes inverting a help block that CA-017 had just corrected), L1-07 (CA-027's fix). Five of nine findings originate in this round's own waves -- the risk the round-3 brief flagged is real and concentrated in the "fixed one site, missed the mirror" pattern.
- Files carrying findings: `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-state`, `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/tests/timing.sh`, `/Users/darryl.porter/projects/marketplace/plugins/edm/hooks/hooks.json`, `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-lint-artifacts`, `/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-mermaid-rules.awk`, `/Users/darryl.porter/projects/marketplace/plugins/edm/CLAUDE.md`.
