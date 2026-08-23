# Lens L4: Test Quality -- Round 5 (EDMV3 prompt-streamline)

## Method note

This lens agent has no Bash tool (by design for lens agents, confirmed mid-task). "Break it"
verification was done by hand-tracing the awk/bash under test against corrupted input, not by
execution. Where a claim rests on a regex matching real content, Grep was used as a live regex
oracle (marked "verified"); others are marked "traced".

## Open L4 ledger entries verified against current code

| ID | Verdict |
|---|---|
| CA-036 | **Shape axis closed, file axis broken.** New residual: F-2 |
| CA-037 | **Third pass still needed.** Path-existence half closed; matcher half live at 16 sites: F-1 |
| CA-145 | **Closeable.** Prescribed scope done |
| CA-146 | **Closed and discriminating** |
| CA-262 | **NOT fixed**, aggravated by G16: F-3 |
| CA-263 | **NOT fixed**: F-5 |

## Findings (L4: Test Quality)

### F-1 (P1) -- CA-037 third pass: the real scan's own pattern is still outside the control

`_harness.sh:243-262`'s `assert_tree_absent` genuinely closed the path-existence half (break test
3a: a broken scan target fails by name). But the control needle is a SECOND literal independent of
the real scan's pattern -- typo the real scan's pattern only (break test 3b), leaving the seeded
scratch file's needle correct, and the assertion still passes. `_harness.sh:228-232`'s docstring
claims this cannot happen. The sweep also keyed on the helper name: at least 5 hand-rolled sites
in the identical tautological shape were never converted (wave7:1184,1193,1202,1338;
wave6:2480 -- the last one 8 lines below a converted sibling).

**Fix**: use ONE literal for both the real scan and the control needle; route the control through
a real scan over a seeded scratch tree via the identical pipeline (templates already exist at
wave7:4345-4364, :910, :1172, :3951, :4010); correct the docstring; sweep the 5 remaining sites.

### F-2 (P1) -- CA-036 residual: the widened tripwire is blind to ~850 lines (13%) of wave7-smoke.sh

The detector's `guarded` flag is lexical (`set +e` sets it, `set -e` clears it), but this file's
dominant subshell-probe idiom (`VAR="$( set +e; trap - ...; ... )"`) never has a matching `set -e`
because the scope closes with the subshell. 11 unpaired `set +e` lines create two blind regions:
`:4543-4988` (446 lines) and `:5953-6356` (404 lines) -- exactly the lock/trap block CA-036's L3
half was filed against. Traced: reintroducing the exact CA-036 shape inside either region passes
silently; outside them it's caught correctly. No live hazard today (all 12 real bare-capture sites
verified correctly bracketed), but the tripwire can't see a reintroduction exactly where one is
most likely.

**Fix**: close the bracket at the subshell boundary rather than lexically (clear `guarded` on the
line closing the command substitution, not on a lexical `set -e`). Add a 7th positive-control
fragment placing a hazard after an unpaired `set +e`, update the expected count from 6 to 7.

### F-3 (P2) -- CA-262 not fixed, and G16 made it worse

`wave7-smoke.sh:4214` unchanged: `[1-9][0-9]*` still required. No perl on any pinned CI image.
Traced aggravation: G16 raised sample count 10->20, moving the selected p95 rank from index 10
(the max, needs 1 boundary crossing) to index 19 (second-largest, needs 2) -- roughly halving the
pass probability in a blocking job. Neither fix's write-up notes the interaction.

**Fix**: per CA-262's original prescription; add a comment noting the rank/resolution coupling.

### F-4 (P2) -- G16/CA-262's timing.sh fixes have zero covering assertions

No suite references `_p95`, `_P95_SAMPLE_COUNT`, `_measure_p95`, or `_now` outside one comment.
Traced: reverting the sample count to 10 or the ceiling formula keeps the suite green. The portable
awk fallback (G31's fix) is dead code on macOS (has perl) and unexercised in CI (gawk has
`systime()` so the pre-fix code never crashes there either) -- no environment the suite runs in
exercises the crash G31 fixed.

**Fix**: shadow `command -v perl` (idiom already used at wave7:4558 etc.) to force the fallback
path and assert `_now` still works; add two `_p95` argument-vector assertions.

### F-5 (P2) -- CA-263 not fixed

`wave7-smoke.sh:4902-4903`: `check "..." "0" "$tmp_left"` still uses `check()`'s substring match --
expected "0" also matches 10/20/30/100. Same class at `:6240-6241` ("33" matches 133/233/330).

**Fix**: `[[ "$tmp_left" -eq 0 ]]` idiom at both sites.

### F-6 (P2) -- three "only gate N" assertions prove presence, not exclusivity

`wave6-smoke.sh:210` and `:213` have no companion `check_absent` at all -- a regression returning
"1 2 3" passes both, on the prototype/mini-srd gate-suppression contract (the entire purpose of
those modes).

**Fix**: assert the full joined string as the correct sibling at :203 does.

### F-7 (P2) -- G40/CA-271's terminator fix is load-bearing but untested

Verified: `.gitlab-ci.yml:5,16,198` are real column-0 comments ending in a colon, in the region a
body extraction walks -- the fix changes real behavior on real input. No assertion fires it; the
existing `>=11` count and empty-body guards both pass on a body truncated early but non-empty.

**Fix**: one assertion extracting a job body spanning line 198, asserting a post-198 token is
present.

## Noted / Not Actionable

1. CA-036's L3 half fully closed and discriminating (seed-zero-then-or-capture form, `|| true`
   guards, 4th assertion landed).
2. Break test traced: the G5/G1 positive control is genuinely discriminating on the shape axis
   (exactly 6 hits from 6 shapes, exact `-eq` comparison).
3. CA-146/G14 closed and discriminating (traced two directions).
4. CA-145 prescribed scope closed -- recommend closing.
5. `assert_tree_absent`'s ERROR sentinel cannot cause a `set -u` abort -- correct as written.
6. The five Wave-8f-2 retry-assertion rewrites fail in the safe direction (renamed function/marker
   empties the extraction).
7. G39/CA-270 landed correctly, both arms verified real.
8. G50/CA-281 is comment-only, nothing to verify.
9. Spot checks of the highest-drift-risk repo-wide scans (agent count, orchestrator line count,
   several zero-occurrence checks) all Grep-verified clean.
10. evals/ self-tests wired and exit-checked correctly.

## Suite-run status -- NOT CONFIRMED

`run-all.sh` could not be executed (no Bash tool). Grep re-ran the repo-wide scans behind the
riskiest assertions and all returned expected values -- no positive evidence of a red assertion,
but this is not proof. Recommend a Bash-capable pass runs the aggregator before the convergence
gate.

## Meta

`Write` and `Bash` absent from this lens's delivered runtime tool set. Both `lens-L4.md` and
`lens-L4.jsonl` were transcribed by the orchestrator.
