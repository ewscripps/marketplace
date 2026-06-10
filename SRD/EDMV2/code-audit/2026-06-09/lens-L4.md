# Lens L4: Test Quality — Round 2 (2026-06-09)

## Summary

The round-1 L4 finding (G19) is **mostly fixed and the new `wave5-smoke.sh` is genuinely well-built** — the `.bak` test in particular asserts real, falsifiable pre-/post-write state rather than a tautology, and `migrate-path` / per-epic `record-test-coverage` / `set-parent` / `add-related` all now have meaningful positive assertions. No `2>/dev/null` or `|| true` sits on a *positive* assertion anywhere; the failure-masking that exists is confined to negative/rejection checks where a specific substring match keeps them mostly honest.

The real problem this pass is **coverage of the round-1 CODE fixes**, and it splits into two tiers:

1. One **P1**: the regression net for **G7** (the P1 path-traversal fix) does not exist — no test exercises a `..`-bearing `PREFIX` through `init`/`set`. The wave5 traversal tests only cover `migrate-path`'s `--product`/`--description` (the G12 surface), not the G7 `state_file_for` guard.
2. One **P1 of a different kind**: **`migrate-path` STILL bypasses the lock and `.bak`** (`edm-state:1114-1120`) — the G12 code fix was *not actually applied* to the post-move write, and the new wave5 migrate-path test cannot catch it because it never asserts a `.bak`.
3. Several **P2s**: `metrics-report` is invoked by **zero** suites, leaving G8 (`n/a`), G20 (`Phase 1`), and the G1 `--all`/`--calibrate` both-layout enumeration entirely unguarded against regression; and the G19-prescribed exit-0 gate on the SIZE_UNKNOWN suppression check was not added.

Note: the migrate-path lock/backup bypass (Finding 2) is primarily a **code** defect (L3's lane), but I am reporting it from L4 because G19 designated wave5 as its regression net and that net is non-functional — the test passes against broken code.

## Findings

### [P1] G7 path-traversal fix has no regression test — the P1 security fix is unguarded — wave5-smoke.sh (absent), guard at edm-state:145

**Evidence:** The round-1 P1 (G7) was a path-traversal arbitrary-write: a `..`-bearing `PREFIX` reaching `state_file_for` via `init`/`set`/etc. wrote `.edm-state.json` outside `SRD_ROOT`. The fix is `state_file_for:145`:
```bash
[[ "$prefix" =~ ^[A-Za-z0-9_-]+$ ]] || die "state_file_for: invalid PREFIX '${prefix}' ..."
```
The only path-traversal assertions in the entire suite are wave5-smoke.sh:66-73, and they exercise **`migrate-path --product`/`--description`** (the G12 surface, guarded separately at `edm-state:1090-1091`), not the G7 `PREFIX` vector. `grep` for `init '../`, `escaped`, or any `state_file_for` exercise across `bin/tests/` returns nothing. The G19 remediation (REMEDIATION.md:933) explicitly stated the new tests "serve as the regression net for G1/G2/G3/G4/G7/G12" — G7 is named but not covered.

**Why it matters:** This was a legacy-P1 (→ P0 on the canonical scale) security fix. Nothing prevents a future refactor of `state_file_for` (e.g. moving the guard, broadening the regex, or short-circuiting it on the flat-path fast-path at line 149) from silently re-opening the arbitrary-write primitive. A P1 security fix with zero test coverage is the highest-value gap this pass.

**Suggested fix:** Add to wave5 (these would have failed against pre-G7 code):
```bash
check "prefix path-traversal rejected (init)" "invalid PREFIX" \
  "$("$EDM_STATE" init '../escaped/INJ' 2>&1 || true)"
[[ ! -e "$TMP/escaped/INJ/.edm-state.json" ]] && pass "no file written outside SRD_ROOT" \
  || fail "G7 traversal wrote outside SRD_ROOT"
check "prefix slash rejected (set)" "invalid PREFIX" \
  "$("$EDM_STATE" set 'A/B' k v 2>&1 || true)"
```

### [P1] migrate-path still writes state without the lock or `.bak`; wave5 test cannot catch it — edm-state:1114-1120, wave5-smoke.sh:42-59

**Evidence:** The G12 remediation (REMEDIATION.md:677) prescribed routing the post-move state update "through the **G2 `rmw_state`** primitive (lock + backup + atomic write) instead of `printf > "$new_state_file"`." The live code at `cmd_migrate_path` still does the pre-fix hand-rolled write:
```bash
current="$(cat "$new_state_file")"
new="$(echo "$current" | jq --arg p "$product" ... )"
printf '%s\n' "$new" > "${new_state_file}.tmp.$$" && mv -f "${new_state_file}.tmp.$$" "$new_state_file"
```
This is the **only mutator besides `init` that does not call `rmw_state`/`write_state`** — it acquires no `with_state_lock` and creates no `.bak`. The wave5 migrate-path test (wave5-smoke.sh:48-59) asserts `product_name`/`initiative_description`/`last_updated` are updated, but **never asserts a `.bak` exists** after the migrate, so it passes green against this defect.

**Why it matters:** Two things are wrong: (a) the G12 code fix was effectively not applied — the lock-bypass and missing-`.bak` that G3/G12 flagged still live in `migrate-path`; (b) the test designated as G12's regression net (G19/L4-08) is blind to it. From L4's mandate this is "an assertion that passes even when the feature is broken."

**Suggested fix (test side, L4's lane):** Add to the wave5 migrate-path block:
```bash
[[ -f "${state_file}.bak" ]] && pass "migrate-path created .bak" \
  || fail "migrate-path did not create .bak (lock/backup bypass — G12 regressed)"
```
This will fail against the current code and pass only once `cmd_migrate_path` is converted to `rmw_state` (the actual code fix, owned by L3).

### [P2] metrics-report is invoked by no suite — G8 (`n/a`), G20 (`Phase 1`), and G1 `--all`/`--calibrate` enumeration are entirely untested — bin/tests/* (absent)

**Evidence:** `grep -n 'metrics-report' bin/tests/*` returns **no matches**. Three round-1 fixes live only in `cmd_metrics_report`: G8 (`n/a` guards at `:913/:975/:986`), G20 (`Phase 1` label at `:974`), and G1 both-layout enumeration for the two aggregates (`:915/:926`).

**Why it matters:** G20 is a string-formatting fix the next jq edit can trivially re-break; G8 is a correctness/honesty fix; the G1 `--all`/`--calibrate` arms are the *only* `list_state_files` consumers no test touches. P2 because none corrupts state.

**Suggested fix:** Add a small `wave6` (or extend wave5) that runs `phase-complete` on a sized initiative, then asserts `metrics-report <P>` output contains `Phase 1` (not `1Phase`) and `n/a` (not `0x`) when `estimated_size:"Unknown"`; and that `metrics-report --all` lists a product-scoped initiative.

### [P2] SIZE_UNKNOWN suppression check uses `2>&1 || true` with no exit-0 gate — wave4a-smoke.sh:153-160

**Evidence:** G19/L4-03 prescribed asserting `validate` exits 0 before `check_absent SIZE_UNKNOWN`. The shipped code retains `|| true` with no `[[ exit == 0 ]]` gate. `check_absent` passes whenever `SIZE_UNKNOWN` is not a substring — including if `validate` crashed to empty. (Today it does not false-pass — TSMK at phase 2 produces genuinely-empty clean output — so this is a falsifiability weakness, not a current false pass.)

**Suggested fix:** Capture status explicitly and assert clean exit before the absence check.

### [P2] session-start phase-0-hidden check is satisfiable by a total crash — wave3-smoke.sh:103-109

**Evidence:** The second `session-start` invocation: if it crashed entirely, `session_out2` is empty, `grep -q "TSMK2"` finds nothing, and the test **passes spuriously**. `2>/dev/null` hides any diagnostic.

**Suggested fix:** Pin a positive control to the same invocation — assert `session_out2` contains `TSMK` AND not `TSMK2`.

## Round-1 fix verification (L4)

**G19 — PARTIAL (substantially fixed; two prescribed hardenings not done).**
- migrate-path coverage (L4-08): CONFIRMED ADDED (wave5:42-85) — but does NOT assert `.bak` (blind to the un-applied G12 lock/backup fix).
- per-epic record-test-coverage (L4-06): CONFIRMED FIXED (wave5:90-109, real post-conditions).
- set-parent / add-related (L4-07): CONFIRMED FIXED (wave5:114-143, incl. idempotency).
- .bak mechanism (L4-09): CONFIRMED FIXED — and well-constructed (wave5:148-164, falsifiable pre/post state). The model the others should follow.
- Tautological PASS-ticket absence (L4-01): CONFIRMED FIXED (wave4a:207-208, region-sliced).
- mini-SRD empty-region negative grep (L4-02): CONFIRMED FIXED (wave4b:121-122, awk region extraction).
- Invalid-input non-zero-exit + fast-track exit-0 gate (L4-03/04/05): NOT DONE (substring-only under `2>&1 || true`; SIZE_UNKNOWN exit-0 gate not added).

## Coverage gaps for round-1 CODE fixes (changed behavior left untested)

- G1 both-layout enumeration: PARTIAL — metrics `--all`/`--calibrate` arm untested; product-scoped initiative never enumerated by a test.
- G2/G9 atomic write + `.bak` via `rmw_state`: YES for `set`; NOT for `migrate-path`.
- G3 checkpoint-if-active through `rmw_state`: NO — no suite invokes it.
- G4 get-coverage exit-0-on-success: PARTIAL (implicit under `set -e`); empty-coverage case NO.
- G7 path-traversal `PREFIX` rejection: NO (P1 Finding 1).
- G8 metrics `n/a`: NO. G10 invalid-input `die`: PARTIAL (valid path only). G12 migrate lock/backup: NO. G13 flock-timeout `die`: NO. G20 `Phase 1`: NO. G18 `phase_name_for`: PARTIAL.

## Noted / Not Actionable

- Rejection tests using `"$(... 2>&1 || true)"` with specific substring match (wave4a/wave5): acceptable for negative assertions; the matched substrings are specific `die`-message fragments. Mildly false-positive-prone but low risk; not promoted (except the absence checks reported above).
- `cmd_init` does not create a `.bak`: intentional (fresh file via `jq -n > "$f"`); wave5 correctly does not expect one.
- Smoke-only design (no bash unit framework): intentional per charter/SRD.
- `_harness.sh` extraction not present; preamble duplicated: L10's lane (behaviorally consistent across suites now), not an L4 correctness defect.
- G23 stale staging comments: out of L4 scope; wave3:5/wave4a:5 reference `edm-ai-development` correctly anyway.
