# Lens L1: Logic, Correctness & Completeness -- Round 6

**Tooling note (CA-130's class, seventh consecutive round):** this lens's delivered tool set was
Read, Grep, Glob, WebFetch, WebSearch, TaskStop -- no Write, Edit, or Bash. This report was
transcribed by the orchestrator from the lens agent's final message rather than written directly
by the agent. Suite greenness was NOT independently confirmed by this lens (no Bash); all findings
below are derived from static reading of the current tree.

Scope read: `plugins/edm/bin/edm-state` (all 5193 lines), `bin/edm-lint-artifacts`,
`bin/_edm-lint-lib.sh`, `bin/_edm-cli-lib.sh`, `bin/edm-mermaid-rules.awk`, `bin/edm-init`,
`bin/edm-validate-prefix`, `bin/edm-check-grants`, `bin/edm-check-vocabulary`,
`bin/edm-check-skill-sync`, `bin/edm-compare-eval`, `bin/edm-sync-canonical-sections`,
`hooks/hooks.json`, `evals/run-eval.sh`, `evals/score-artifacts.sh`, `evals/tiering-matrix.sh`,
`docs/canonical-sections.md`, `plugins/edm/CLAUDE.md`, and the edm-scoped `.gitlab-ci.yml` jobs.

## Findings (L1: Logic, Correctness & Completeness)

### L1-001 -- P1 -- `plugins/edm/bin/edm-state:5037`

HANDOFF.md's first status bullet contains **two independently wrong values on one line**:

```bash
printf '%s\n' "- **Gates approved**: ${gates_count} of 3"
```

**Wrong denominator.** `3` is hardcoded. `required_gates_for_mode()` (same file, `:811`) is the
single source for "which gates this lifecycle actually requires", and `_write_handoff_body`
already reads `mode`, `lifecycle_mode` and `skipped_phases` a few lines above (`:4770-4797`) -- it
just never uses them for the count. For `mode=prototype`, `terminal_phase_for_mode` returns 2 and
the default skip set covers phases 3-6, so exactly **one** gate is required; the artifact renders
`1 of 3`, telling a teammate two gates are outstanding on an initiative that has none. `mini-srd`
(merged Gate 2+3, phases 4/5 skipped) and `fast-track`/`fix-pack` (phases 1/2/3/5 skipped) are
wrong the same way. This is the exact class CLAUDE.md's own mode matrix closes with "never
restated as prose in a phase skill or in the dispatcher" -- restated here as a literal instead.

**Inflatable numerator.** `gates_count` is `(.gates_approved // []) | length` (`:4760`), and
`cmd_approve_gate` appends with no dedup (`:1990`, `.gates_approved += [{gate: ($g|tonumber),
...}]`). Re-approval is not a misuse -- `cmd_checkpoint`'s drift path explicitly instructs it at
`:2280` ("re-approve Gate 2 before creating tickets") and `:2289` ("re-approve Gate 3 before
implementation"). So `- **Gates approved**: 4 of 3` is reachable through a documented workflow.

Graded P1 on the "factual error" clause: HANDOFF.md is the committed cross-user resume artifact
and this is its headline status row. (Counter-argument for P2: no enforcement path reads this
value -- `cmd_gate_check`, `cmd_archive` and `metrics-report` all use
`map(select(.gate == $g))`/`first`, so only the human-facing render is affected. The lens would not
object to P2, but the value is nonsense either way.)

**Concrete fix** -- derive both halves, guarding against a hand-edited invalid `mode`
(`required_gates_for_mode` -> `terminal_phase_for_mode` calls `die`, and this code runs inside
`with_state_lock`):

```bash
  local gates_count required_gate_count skipped_for_count
  gates_count="$(echo "$state" | jq -r '[(.gates_approved // [])[].gate] | unique | length')"
  skipped_for_count="$(echo "$state" | jq -r '[(.skipped_phases // [])[].phase] | join(" ")')"
  required_gate_count="$( (required_gates_for_mode "$mode" "$lifecycle_mode" "$skipped_for_count" \
    | grep -c . ) 2>/dev/null || echo 3 )"
  [[ "$required_gate_count" =~ ^[1-9][0-9]*$ ]] || required_gate_count=3
```
then `"- **Gates approved**: ${gates_count} of ${required_gate_count}"`. Add one assertion pinning
`1` as the denominator for a `prototype` initiative and one pinning that a double `approve-gate 1`
still renders `1 of N`.

---

### L1-002 -- P2 -- `plugins/edm/evals/score-artifacts.sh:498`

`compute_dim5` has an **unguarded division by zero** introduced by CA-088's own remediation.

The only zero-denominator guard is the "no `lens-L*.jsonl` files at all" early return at `:435`.
CA-088 then added, inside the per-file loop:

```bash
    case "$lens_n" in
      ''|*[!0-9]*) continue ;;
    esac
```
at `:464-466` -- which skips the file **without incrementing `total`** (`total=$((total + 1))` is
at `:494`, after the guard). If every discovered file is skipped, `${#jsonl_files[@]}` is non-zero,
`total` stays `0`, and `:498` runs

```bash
D5_SCORE="$(round_int "$(awk -v s="$sum" -v n="$total" 'BEGIN{printf "%.4f", s / n}')")"
```

awk aborts with `awk: division by zero`, emits nothing to stdout, and leaks its diagnostic to the
scorer's stderr; `round_int ""` then coerces the empty string to **`D5_SCORE=0`**. So a data-shape
error is silently laundered into a real dimension-5 score of zero, which then enters
`dimensions_scored` and the `total` mean. The reachable shapes are exactly the ones CA-088 was
written for -- a run directory containing a literally-named `lens-L*.jsonl`, or a `lens-L.jsonl`.
Round 1's L3 report recorded "`compute_dim5` guards before calling" as the rationale for not
filing this; that rationale is no longer true.

**Concrete fix** -- insert immediately after the loop closes at `:496`, before `:498`:

```bash
  if [[ "$total" -eq 0 ]]; then
    D5_SCORE=""
    D5_REASON="no lens-L<N>.jsonl with a numeric lens number (every discovered file was skipped)"
    return
  fi
```

---

### L1-003 -- P2 -- `plugins/edm/bin/edm-init:163-166`

CA-314's remediation comment carries **two line-number citations that were already wrong on the
day they were written**:

- `edm-state:691` is cited for "the state backup". The backup is `_rmw_state_body`'s
  `[[ -f "$f" ]] && cp -p "$f" "${f}.bak"` at **`edm-state:705`**.
- `edm-state:1034-1035` is cited for "the lock file family". Those lines are `with_state_lock`'s
  usage doc comment; the `lockfile`/`lockdir` assignments are at **`edm-state:1040-1041`**.

This is CA-315/CA-268's class at a site the round-5 sweep did not enumerate, and it is the same
failure mode CA-268 recorded ("went stale twice, the second time inside the very commit that fixed
the first"). Filing here because the lens found it; L6 owns this class and may prefer to absorb it
into CA-315's durability half rather than track it separately.

**Concrete fix** -- re-point by name, per the CA-095 convention:

> the state backup (`_rmw_state_body`'s `cp -p ... .bak`), the lock file family
> (`with_state_lock`'s `lockfile`/`lockdir`, deliberately never unlinked per CA-169) and
> `write_atomic`'s transient temp files

and fold this site into whatever ban/assertion CA-315's fix adds for new file-and-line citations in
comments.

---

## Noted / Not Actionable

1. **Zero unresolved incompleteness markers in production code.** Full-tree sweep for
   `TODO|FIXME|HACK|XXX`, `NotImplementedError`, bare `pass`, and empty `catch`/`except` found
   exactly two hits, both legitimate: `bin/tests/fixtures/mermaid/valid/v03-comment-semicolon.md:9`
   (a Mermaid `%% TODO` comment that *is* the fixture under test) and
   `evals/vague-ac-patterns.txt:29` (the token `TODO` as a vague-AC detection pattern). No stub
   returning hardcoded data anywhere in `bin/`, `hooks/` or `evals/`.
2. `edm-lint-artifacts:365-402` -- the class-4 mermaid loop omits the
   `[[ "${UNREADABLE_FLAGS[$i]}" -eq 1 ]] && continue` guard its four sibling loops carry.
   Behaviourally equivalent: `MERMAID_SETS[$i]` is set to `""` for an unreadable file at `:276`,
   and `[[ -z "$mermaid_set" ]] && continue` at `:368` catches it.
3. `edm-validate-prefix:80` -- `"${SRD_ROOT}/.archived/"/*/` produces a doubled slash
   (`./SRD/.archived//*/`). POSIX-harmless in path resolution; behaviour is correct, including the
   unmatched-glob path.
4. `edm-state:2942-2943` -- `--calibrate`'s median is `.[length / 2 | floor]`, the upper median on
   even counts. Used identically for both `median_duration_s` and `median_cost_usd`; consistent,
   and the output is labelled "Median values".
5. `edm-state:485-494` -- the `unknown` sentinel arm sits between the two current-generation arms.
   Explicitly sanctioned by `CLAUDE.md`'s D32 note ("it is arm 6 of 8 ... where it lands relative
   to `unknown` is immaterial"); the two real invariants (every version arm precedes `*)`, no bare
   family wildcard) both hold.
6. `edm-state:4080`/`:4087` -- `audit-converged`'s invalid-status filter accepts `deferred` while
   its diagnostic enumerates `open|fixed|noted`. Deliberate: `deferred` is read-compat only per
   EDMV3-T25 AC4, and the message names the going-forward enum.
7. `_edm-lint-lib.sh:153-156` -- an `edm-lint-ignore-end` inside a fence closes the block and is
   emitted in no class. Already CA-122 (NOTED, unreachable).
8. `_edm-lint-lib.sh:162` -- the `-start` marker line itself is not emitted as `marker` (the flag
   is set after the print). Consistent with the ordering; no caller consumes that case.
9. `edm-check-grants:437-443` -- `ln` is read and never used in the two hook-prompt loops;
   deliberate and documented at `:419` (each prompt value is one physical line, so `$lnum` is the
   citation).
10. `edm-state:1186` and `:3540` -- `date -r <file|dir> +%s` is supported with file semantics by
    GNU coreutils, BSD/macOS, and BusyBox (the Alpine CI image) `date`. Portable; correctly avoids
    the `stat -c`/`stat -f` divergence the T61 AC11 assertion bans.
11. `pattern_target_heading_for` (`edm-state:4495`) always returns the same heading regardless of
    argument -- CA-114, already NOTED as the contractually-coupled extension point.
12. `edm-compare-eval:47-50` accepts `-h`/`--help` but not bare `help` -- CA-289, already NOTED
    (two lenses saw it, neither claimed it; do not re-file).

## Round-5 L1 closure spot-checks (re-verified against the tree, not trusted from the ledger's stale `status` column)

- **CA-298 -- FIXED.** All five `UserPromptExpansion` command hooks (`hooks.json:19,32,45,58,71`)
  now carry `edm-state resolve-dir "$prefix" >/dev/null 2>&1 || exit 0;` ahead of the gate-check,
  so only a real refusal reaches `|| exit 2`. `CLAUDE.md`'s "Hooks behavior" row now states the
  exit-code contract explicitly, and the five prompt bodies' first-invocation clause is now true
  rather than contradicted.
- **CA-303 -- FIXED.** `find -mmin` is gone. `_git_lock_age_seconds` (`:3538`) computes one integer
  via `date -r`; `_git_lock_age_bucket_label` (`:3548`) and both gates (`:3597`, `:3692`) read that
  same integer. The lens re-derived the bucket labels for `age_min` 0/1/2/60/61 -- correct and
  monotone. A second age re-check immediately before the `mv`-aside was added as a bonus (the
  CA-251 residual).
- **CA-304 -- FIXED, both halves.** `_cmd_migrate_path_move_body:3215` removes only `.lockd` plus
  the timeout glob and leaves `.lock` on disk, with the false "same exception as archive" clause
  replaced by a correct explanation. `_cmd_migrate_path_rollback_body` now exists (`:3235`) and the
  rollback rename runs inside `with_state_lock` on the destination lockbase (`:3305`), with the
  product-directory `rmdir` cleanup.
- **CA-320 -- FIXED.** `srd_root_explicit`, a `repo_root`-anchored `check_dir`, and silence when an
  unset default simply does not exist.
- **CA-186 residual -- FIXED.** `.`, `./`, `././SRD`, `SRD/.` and `SRD/` all normalize to a usable
  root; `srd_root="."` now sets `root_for_awk=""` so the whole staged path is scanned instead of
  the enforcement silently exiting 0.
- **CA-305 -- FIXED.** Timeout marker under `${TMPDIR:-/tmp}`, created with `mkdir` (atomic,
  refuses a pre-planted symlink), plus the secondary `_lock_ec -eq 99` arm that still names the
  timeout.
- **CA-306 -- FIXED.** `:601-612` and `:1057-1066` now both state the guard is armed on *both*
  branches and is process-global rather than lockbase-keyed.
- **CA-318 -- FIXED.** The invalid-pidfile reclaim now age-gates at `>= 1s` (`:1185-1193`),
  agreeing in direction with `cmd_git_lock_check`.
- **CA-261 -- FIXED.** `--calibrate`'s guard (`:2920`) derives from the renderer's own `select()`
  with an explicit `!= "Unknown"` exclusion and counts `phase_durations` rows summed across
  qualifying files, not the file count.
- **CA-308 -- FIXED.** `skills/plan/SKILL.md:46-63` now defines Step 0's producer as the block
  every other phase skill cross-references, enumerates all seven substitutions, and names the
  covering assertion.
- Re-derived from scratch and **confirmed accurate** (three claims a stale doc would have broken):
  `CLAUDE.md:760`'s "39 subcommands" matches the 39 dispatch arms exactly;
  `CLAUDE.md:843-854`'s "eight `schema_at_least()` call sites, five carrying the canonical comment,
  three not" is exactly right (sites at `:1957, :2019, :2082, :2148, :2598, :2695, :3393, :4061`;
  the three uncommented are approve-gate's precheck, archive's wave-B block, and
  `cmd_audit_converged`); and `docs/canonical-sections.md` is byte-in-sync with `CLAUDE.md`'s two
  canonical sections, including the doubled blank line at `:30-31` that `extract_section` + `echo`
  necessarily produce.
- New-code scrutiny with **no defect found**: `run-eval.sh`'s containment `xy`/`path` split and
  `R*|C*` rename handling (CA-007) are correct; `get_session_tokens_since`'s scoped branch
  correctly falls through to the whole-directory fallback on a `tail` failure because `pipefail` is
  on; `_lint_report_class_hits`'s process-substitution form genuinely preserves the caller's
  `violations` counter across all four class sites (CA-327's extraction is sound);
  `tiering-matrix.sh`'s `_MATRIX_JQ_FILTER` implements D16's rule as documented including the
  exact-80% boundary.

## Meta

`Write` absent from the delivered tool set despite the frontmatter grant (ledger CA-130, seventh
consecutive round) -- this report needed orchestrator transcription. `Bash` was also absent, so
suite greenness is **NOT CONFIRMED** by this lens; CA-331's standing recommendation (a
Bash-capable pass runs the aggregator before the convergence gate) applies again.
</content>
