# Lens L2 -- Dead Code & Unreachable Paths (Round 7)

**Tooling note (CA-130's class, 7+ consecutive rounds):** Write/Edit/Bash absent
from this lens's delivered runtime tool set. This report was transcribed by the
orchestrator from the lens agent's final message, after a stalled first attempt.

## Findings (L2: Dead Code & Unreachable Paths)

### L2-01 (P2) -- `denom -eq 0` skip branch in dimension 4 is structurally unreachable
`plugins/edm/evals/score-artifacts.sh:419-422`

```bash
local denom=$((srd_count + target_count))
if [[ "$denom" -eq 0 ]]; then
  D4_SCORE=""; D4_REASON="no comparable IDs found"; return
fi
```

`srd_count` is already proven non-zero by the early return 33 lines above
(`:386-388`, `no ${prefix}-NN requirement IDs found in srd.md`). Every path that
reaches line 419 therefore has `srd_count >= 1`, and `target_count` is a
`grep -c` result that is never negative, so `denom >= 1` unconditionally. The
`"no comparable IDs found"` skip reason can never appear in any `scores.json`'s
`dimensions_skipped[]`.

**Verdict: delete, not fix.** The branch is not masking a guard that is
actually needed: the real edge case (`target_count == 0` -- `audit-srd.md`
exists but references zero `{PREFIX}-NN` IDs) is *deliberately* not a skip. It
scores `forward_hits + backward_hits == 0` over `denom == srd_count`, i.e. a
hard 0, which is the same "a real zero is not an absence of data" reasoning
G53/CA-286 already codified for dimension 5 (`:436-449`). Removing the dead
branch makes that intent legible instead of contradicted. No comment anywhere
claims this is a deliberate safety net.

### L2-02 (P2) -- `_harness_hash_file`'s `unhashable` arm is environmentally unreachable, and silently converts every dependent assertion into a vacuous PASS if it ever is reached
`plugins/edm/bin/tests/_harness.sh:279-289`, consumed at `:294-310` and `:320-353`

```bash
  if command -v shasum >/dev/null 2>&1; then ...
  elif command -v sha256sum >/dev/null 2>&1; then ...
  else
    echo "unhashable"
  fi
```

Two halves, and the second is why this is worth acting on:

1. **Unreachable in every supported environment.** `plugins/edm/CLAUDE.md
   Sec."Testing changes"` scopes the harness to macOS and Linux only. macOS
   ships `shasum` (perl); Linux and the busybox-based CI images ship
   `sha256sum`. Both CI jobs (`test:smoke` on the pinned alpine image,
   `test:smoke-bash32` on `bash:3.2`) satisfy at least one branch. There is no
   configured environment in which the `else` arm executes.
2. **If it ever does execute, it is a false-pass generator, not a fallback.**
   `check_state_unchanged` (`:294`) and `check_refuses_and_leaves_state`
   (`:320`) both guard exactly one sentinel:

```bash
before="$(_harness_hash_file "$state_file")"
if [[ "$before" == "absent" ]]; then
  fail "..."; return
fi
```

`"unhashable"` is not guarded. Both `before` and `after` come back as the
identical literal `unhashable`, so `[[ "$before" == "$after" ]]` is true and the
assertion reports `PASS: state unchanged` regardless of what the command under
test did to the state file. Per the CA-042 note at `:312-319`,
`check_refuses_and_leaves_state` replaced 49 `check_state_unchanged` call sites
-- so a single missing hash utility would silently green-light that entire
class of "the command refused AND left state untouched" proofs.

This is a textbook repeat of the CA-145 class already fixed once in this same
file (`count_matches` collapsing grep exit 1 and exit 2 into the identical
passing value `0`, `:176-207`). The lesson was applied to grep and not to the
hasher.

**Verdict: fix, do not delete the fallback.** Either extend both guards to
reject any non-hash sentinel (`[[ "$before" == "absent" || "$before" ==
"unhashable" ]]` -> `fail`), or -- cleaner and it fixes both call sites at once
-- have `_harness_hash_file` `return 1` on the `unhashable` arm and have the
two callers treat a non-zero return as a `fail`. Deleting the arm outright is
the wrong move: it would make the function print nothing and the comparison
would still trivially pass.

### L2-03 (P2) -- `assert_absent_with_control` is retained with zero production callers, kept alive only by its own self-tests
`plugins/edm/bin/tests/_harness.sh:209-228`

The docstring states the condition itself (G2/CA-037, round 5):

> "It now has zero production callers; the only remaining callers are this
> file's own self-tests in harness-smoke.sh, which exercise it deliberately."

Confirmed by scan: the only two files referencing the symbol are `_harness.sh`
and `bin/tests/harness-smoke.sh`; no `wave*-smoke.sh` suite references it. The
16 real call sites were migrated to `assert_tree_absent` across rounds 4-5.

This is not a false alarm under the filter: it is not an intentional safety net
(nothing can trip it -- it has no callers to protect), it is not documented as
reserved for future use, and its presence is actively load-bearing in the wrong
direction. The docstring has to carry a "**Do NOT** add a new tautological-
control call site" warning precisely *because* the function is still exported
into every suite's namespace. Deleting it converts a warning a contributor must
read into an impossibility.

**Verdict: delete** the function plus the `harness-smoke.sh` cases that exist
solely to exercise it, and fold the one-sentence "the control haystack must not
be a hand-typed literal containing the needle" rule into `assert_tree_absent`'s
docstring (`:230-255`), where the same guidance already partly lives. If the
team prefers retention over deletion, the minimum acceptable alternative is
renaming it with a `_deprecated_` prefix so a new call site is visibly wrong at
the call site rather than only in a docstring nobody re-reads.

## Noted / Not Actionable

- `score-artifacts.sh:186-188` -- `if (v < 0) v = 0` in `score_from_ratio`
  never fires (every call site passes non-negative integer counts). **Keep:**
  CA-139's already-applied fix reasons *from* this clamp to justify deleting
  the negative-rounding branch three lines below; removing the clamp silently
  invalidates that justification.
- `score-artifacts.sh:224` -- the `-z "$max_num"` half of `[[ -z "$max_num" ||
  "$max_num" -le 0 ]]` is unreachable (`unique_ids` is proven non-empty at
  `:207`, and `sed` always emits a line). It is a correctly-ordered
  short-circuit guard against `[[ "" -le 0 ]]` raising a bash arithmetic error;
  the `-le 0` half is genuinely reachable (a `#### AUTH-00` heading). Costs one
  test.
- `score-artifacts.sh:577-580` -- the `complete` non-enum coercion *looks*
  dead (the jq program can only emit `"true"` or `"false"` on exit 0, and the
  `|| complete="false"` at `:576` absorbs failure), but it is reachable: a
  concatenated multi-document `run.json` makes `jq -r` exit 0 while printing
  two lines, yielding `$'true\ntrue'`. Real trigger, real guard.
- `score-artifacts.sh:280, 480` -- `[[ -z "$vague_count" ]] && vague_count=0`
  / `[[ -z "$md_count" ]] && md_count=0`. Defensive against a `grep` exit-2
  race after an `-f` test; one line each, and the CA-145 precedent in this tree
  is to guard exactly this.
- `score-artifacts.sh:663-708` -- `--compare` mode has no production caller;
  the CI comparison is owned by `bin/edm-compare-eval` per `plugins/edm/
  CLAUDE.md`. Explicitly documented as existing so AC4's refuse-on-mismatch
  behavior is directly testable, with EDMV3-T39 named as the owner of the CI
  wiring (`:24-34`, `:659-662`). Intentional. (Flagging only that two
  independent comparison implementations can drift -- that is an
  L10-duplication concern, not L2.)
- `_harness.sh:115` -- `cd "$dir" || { rm -rf "$dir"; trap - EXIT INT TERM;
  return 1; }` after a successful `mktemp -d`. Near-unreachable but the
  cleanup-and-untrap sequence is correct and cheap.
- `_harness.sh:143-145` -- the three `[[ -n "$prev_trap_*" ]] && eval ...`
  restores are no-ops in the common case (suites install no EXIT trap before
  calling `with_scratch_repo`). Correct as written and not last-statement, so
  no `set -e` interaction.
- `_harness.sh:37-44` -- `check_absent` has no positive control at all, which
  is the same shape CA-037 retired `assert_absent_with_control` over. Not a
  finding: it is a general substring primitive over an already-captured
  string and is correct for that job. Any residual risk lives at call sites,
  not here.
- `bin/tests/run-all.sh` -- the branch that skips the three real-repo-anchored
  standalone checks when `EDM_RUN_ALL_SUITE_DIR` is set is reachable only from
  `harness-smoke.sh`. Documented as a test-harness knob in `plugins/edm/
  CLAUDE.md Sec."Testing changes"` (`EDM_RUN_ALL_*` family, G30/CA-275).
  Test-environment-only by design -- explicit False Alarm Filter case 3.
- `count_matches`' documented CAVEAT (`_harness.sh:176-190`) -- the strict
  variant already ships and the caveat names the obligation. The residual
  risk is bare expect-zero `count_matches` call sites in `wave6-smoke.sh` /
  `wave7-smoke.sh`, which were not enumerated this round (see coverage note).
  Not asserted as a finding; recorded as the highest-value follow-up pointer.

## Coverage note (round cut short)

Fully read and audited this round: `plugins/edm/evals/score-artifacts.sh` and
`plugins/edm/bin/tests/_harness.sh`, plus a directory-level survey of
`plugins/edm/bin/` and `plugins/edm/evals/`.

**Not reached, still under-covered for L2 after six rounds:**
`plugins/edm/evals/run-eval.sh`, `plugins/edm/evals/tiering-matrix.sh`,
`plugins/edm/bin/tests/run-all.sh`, the six `plugins/edm/bin/tests/wave*-
smoke.sh` suites, `plugins/edm/bin/tests/timing.sh`, and
`plugins/edm/bin/edm-compare-eval`. The `run-eval.sh` retention path
(`EDM_EVAL_KEEP_RUNS`, default 10) and `edm-compare-eval`'s exit-3 "no baseline
committed" arm are the two highest-value unexamined targets -- the latter
because `plugins/edm/CLAUDE.md` states the wave-A baseline it compares against
**does not exist yet** (decisions.md D23), which makes every non-exit-3 path in
that script currently unreachable in practice and is exactly the
environmental-unreachability pattern this lens exists to catch. Recommend
scoping round 8's L2 pass to those two files first.
</content>
