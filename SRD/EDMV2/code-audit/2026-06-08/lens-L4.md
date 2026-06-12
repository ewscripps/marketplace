# Lens L4: Test Quality

Audit of the three bash smoke tests in `plugins/edm-ai-development/bin/tests/` (`wave3-smoke.sh`,
`wave4a-smoke.sh`, `wave4b-smoke.sh`) against `plugins/edm-ai-development/bin/edm-state` (1978 lines).
Scope: false-positive-prone assertions, masking of real failures, silent no-ops, teardown leakage, and
**v2.0.0 code paths with no smoke coverage at all**. Production-logic, concurrency, and style issues are out
of scope for this lens.

All file paths below are repo-relative to `plugins/edm-ai-development/bin/tests/`.

## Findings

| ID | Sev | File:Line | Issue |
|----|-----|-----------|-------|
| L4-01 | P2 | wave4a-smoke.sh:207-208 | `check_absent` for PASS-ticket exclusion is **tautological** — the HANDOFF PARTIAL section is jq-filtered to `verdict=="PARTIAL"`, so a PASS ticket can never render there regardless of the code. |
| L4-02 | P2 | wave4b-smoke.sh:121 | Negative grep over a sliced region: `grep -A40 'mini-SRD Sub-Flow'` fed as a function arg. If the heading is absent the region is empty and `check_absent` passes — would still pass if the whole sub-flow were deleted. |
| L4-03 | P2 | wave3-smoke.sh:96,104 | `session-start 2>/dev/null` discards stderr on the command under test; the phase-0-hidden assertion (:105) passes on empty output, so a crashed `session-start` reads as "correctly hidden". |
| L4-04 | P3 | wave4a-smoke.sh:65,84,107-113,149-160,178-180 | `… 2>&1 \|\| true` on the command under test masks its exit code; only a stderr substring is asserted. A `die`-before-print or jq crash still yields a string and can pass. Positive sibling assertions mitigate most cases. |
| L4-05 | P2 | wave4a-smoke.sh:155,160 | `check_absent SIZE_UNKNOWN` after `validate … 2>&1 \|\| true`: empty/errored output passes. Combined with L4-04, a totally broken `validate` could read as "suppressed". The :150 positive check is the only guard. |
| L4-06 | P2 | (coverage gap) | `record-test-coverage` (incl. per-epic 4th arg), `record-tests-added`, `get-coverage` — **zero** smoke coverage. Core WS test-tracking paths and the `coverage_by_epic` schema are entirely untested. |
| L4-07 | P2 | (coverage gap) | `set-parent` and `add-related` (incl. parent-exists validation and idempotent append) — **zero** smoke coverage. New v2.0.0 product-line linkage paths untested. |
| L4-08 | P2 | (coverage gap) | `migrate-path` (flat → product-scoped move, git-aware, state rewrite) — **zero** smoke coverage. Among the highest-risk new paths (filesystem move + state mutation). |
| L4-09 | P2 | (coverage gap) | Auto-backup `.bak` mechanism (`_write_state_body`, T132) — **never** asserted. No test confirms a `.bak` is created on overwrite. |
| L4-10 | P3 | (coverage gap) | Advisory locking (`with_state_lock`, flock + mkdir fallback) — **never** exercised. (Concurrency assertion proper is L3; here it is flagged only as a coverage gap for the success path.) |
| L4-11 | P3 | (coverage gap) | `checkpoint-if-active` drift-detection branch + `phase-complete` token/cost/hash recording — **zero** smoke coverage. |

---

### L4-01 — Tautological PASS-exclusion assertion

**Problem.** The assertion claims to verify that PASS-verdict tickets are omitted from the "Outstanding PARTIAL
Verdicts" HANDOFF section, but it can never fail because PASS tickets are structurally impossible in that section.

**Evidence.** `wave4a-smoke.sh:207-208`:
```bash
check_absent "HANDOFF omits PASS ticket from PARTIAL section" "TSMK-T01" \
  "$(grep -A5 'Outstanding PARTIAL' "$HANDOFF" || echo '')"
```
The section is generated in `edm-state` `write_handoff_internal` (lines 1825-1831) by:
```jq
(.partial_verdict_map // {}) | to_entries |
map(select(.value.verdict == "PARTIAL")) | …
```
Verified empirically: with `TSMK-T01=PASS` and `TSMK-T02=PARTIAL`, `TSMK-T01` appears **0** times in the entire
HANDOFF.md, not just the PARTIAL section.

**Why it's a false-positive risk.** The PASS ticket is filtered out at the jq source. The grep would find nothing
even if the exclusion intent were removed, mis-implemented, or the whole "verdict" concept changed — the test
passes by construction. It gives false confidence that a behavior is guarded when nothing exercises it.

**Fix.** Assert the positive instead: that the PARTIAL section *contains* `TSMK-T02` (already done at :205) **and**
that the section's entry count equals the number of PARTIAL verdicts (e.g. `grep -c '^- \*\*TSMK-' …` equals 1
when only T02 is PARTIAL). Drop the tautological `check_absent` or replace it with a count-based assertion that
would break if a PASS/FAIL ticket leaked in.

---

### L4-02 — Negative grep over an empty sliced region

**Problem.** The check verifies the mini-SRD sub-flow does not spawn `edm-ticket-writer`, but it greps a region
that is empty whenever the section heading is missing — so deleting the entire sub-flow makes the test pass.

**Evidence.** `wave4b-smoke.sh:121`:
```bash
check_absent "mini-SRD does not spawn ticket-writer" "edm-ticket-writer" "$(echo "$ORCH" | grep -A40 'mini-SRD Sub-Flow')"
```
`check_absent` (lines 21-30) passes when the content does **not** contain the pattern. If
`grep -A40 'mini-SRD Sub-Flow'` matches nothing (heading renamed/removed), the third argument is the empty string
and the absence check trivially passes.

**Why it's a false-positive risk.** This is the classic "feature-deleted-still-green" trap: the assertion's
precondition (the section exists) is the very thing the positive checks at :116-120 are supposed to establish, but
there is no guard ensuring the slice is non-empty before asserting absence within it. A regression that drops the
mini-SRD sub-flow heading would make :121 pass.

**Fix.** Gate the negative check on a non-empty region, e.g. capture
`region="$(echo "$ORCH" | grep -A40 'mini-SRD Sub-Flow')"`, assert `[[ -n "$region" ]]` first, then run
`check_absent` against `$region`. (Note: the top-level `ORCH="$(cat …SKILL.md)"` assignment at :100 is safe —
plain assignment with a failing `cat` aborts under `set -e`, verified — so this risk is confined to the empty-slice
case, not a missing file.)

---

### L4-03 — `session-start` stderr suppressed; phase-0-hidden check passes on empty output

**Problem.** Both `session-start` invocations discard stderr. The "hides phase-0 initiative" assertion is a
negative check, so any failure that produces empty stdout (including a crash) reads as success.

**Evidence.** `wave3-smoke.sh:96` and `:104`:
```bash
session_out="$("$EDM_STATE" session-start 2>/dev/null)"
…
session_out2="$("$EDM_STATE" session-start 2>/dev/null)"
if echo "$session_out2" | grep -q "TSMK2"; then
  fail "session-start showed phase-0 initiative TSMK2 (should be hidden)"
else
  pass "session-start hides phase-0 initiative"
fi
```
If `session-start` errored (e.g. a jq failure on one state file), stderr is hidden and stdout is empty →
`grep -q "TSMK2"` is false → the test **passes**.

**Why it's a false-positive risk.** The positive checks at :97-100 (TSMK present) would catch a *totally* broken
`session-start`, which is partial mitigation. But the specific phase-0-suppression behavior is asserted only via a
negative grep on output whose error channel is muted — a regression where phase-0 filtering breaks *and* emits to
stderr, or where the second initiative simply fails to render, would still pass.

**Fix.** Drop `2>/dev/null` (let stderr surface so a crash is visible), or capture exit code:
`session_out2="$("$EDM_STATE" session-start)"` and assert the command succeeded *and* that TSMK (phase 2) is still
present in `session_out2` while TSMK2 (phase 0) is absent — anchoring the negative on a known-good positive.

---

### L4-04 — `… 2>&1 || true` masks exit code on the command under test

**Problem.** Several invalid-input rejection tests capture both streams and swallow the exit code, asserting only a
stderr substring. A failure mode that prints the expected substring for the wrong reason (or a `die` on an
unrelated precondition) would pass.

**Evidence.** Representative lines in `wave4a-smoke.sh`:
```bash
:64-65   check "invalid audit type rejected" "unknown audit type"  "$("$EDM_STATE" audit-round-start TSMK invalid 2>&1 || true)"
:83-84   check "invalid verdict rejected"    "unknown verdict"     "$("$EDM_STATE" record-partial-verdict TSMK "TSMK-T04" UNKNOWN 2>&1 || true)"
:106-113 check "invalid mode rejected" …     "$("$EDM_STATE" set-mode TSMK mode badvalue 2>&1 || true)"   (and 3 siblings)
:177-180 check "empty supersedes rejected" "non-empty" "$("$EDM_STATE" set-supersedes TSMK "" 2>&1 || true)"
```
Verified: `set-mode TSMK mode badvalue` exits 1 and prints `edm-state: set-mode: invalid mode 'badvalue' …`. The
`|| true` discards the exit 1; only the substring is checked.

**Why it's a false-positive risk.** Low for these specific cases — the substrings (`unknown verdict`, `invalid
mode`, `non-empty`) are unique to the intended reject path, and a regression that *accepted* the bad value would
print a "set …" success message and fail the substring check correctly. The residual risk is that the substring is
matched for an unrelated reason (e.g. a future refactor where a precondition `die` emits similar text). This is a
consistent harness pattern, hence P3 rather than P2.

**Fix.** Assert non-zero exit alongside the substring, e.g.:
```bash
out="$("$EDM_STATE" set-mode TSMK mode badvalue 2>&1)"; ec=$?
[[ $ec -ne 0 ]] && check "invalid mode rejected" "invalid mode" "$out" || fail "set-mode accepted badvalue"
```

---

### L4-05 — SIZE_UNKNOWN suppression: absence check passes on empty/errored `validate`

**Problem.** The fast-track/fix-pack suppression checks run `validate … 2>&1 || true` and assert SIZE_UNKNOWN is
*absent*. Empty output (a crash, or `validate` exiting 3 then `|| true`) satisfies the absence check.

**Evidence.** `wave4a-smoke.sh:153-160`:
```bash
"$EDM_STATE" set-mode TSMK lifecycle_mode fast-track >/dev/null
anomalies_ft="$("$EDM_STATE" validate TSMK 2>&1 || true)"
check_absent "SIZE_UNKNOWN suppressed in fast-track mode" "SIZE_UNKNOWN" "$anomalies_ft"
```
Verified: `validate` exits **3** when anomalies exist (confirmed in isolation). The `|| true` is *required* here
because `set -euo pipefail` would otherwise abort on exit 3 — so it is not gratuitous — but it also means a
`validate` that crashed to empty output would pass the absence check.

**Why it's a false-positive risk.** The positive check at :150 (`SIZE_UNKNOWN` present in standard mode) guards
against a fully broken `validate`. But the suppression logic itself (the `lifecycle_mode != "fast-track" &&
… != "fix-pack"` guard in `state_anomalies`, lines 382-383) is asserted only by absence. A regression where
`validate` errors out under fast-track (rather than correctly suppressing) reads as success.

**Fix.** After confirming suppression, assert `validate` *succeeded cleanly* in fast-track: capture exit code and
require it to be 0 (no anomalies) — `out=$("$EDM_STATE" validate TSMK 2>&1); ec=$?; [[ $ec -eq 0 ]]` — then
`check_absent`. This distinguishes "suppressed, clean exit" from "crashed, no output".

---

## Coverage gaps

New v2.0.0 `edm-state` subcommands with **no smoke test in any of the three files**. Tested set (union of wave3 +
wave4a, derived from the dispatch table at `edm-state:1935-1977`): `init`, `get`, `set`, `current-step`,
`session-start`, `phase-start`, `write-handoff`, `audit-round-start`, `record-partial-verdict`, `set-mode`,
`skip-phase`, `set-supersedes`, `set-forked-from`, `validate`. (wave4b is text-only — it greps SKILL/agent/CLAUDE
markdown and never invokes `edm-state`.)

| Subcommand / mechanism | edm-state ref | Severity | Notes |
|---|---|---|---|
| `record-test-coverage <PREFIX> <layer> <pct> [<epic>]` | cmd_record_test_coverage, 691-713 | **P2** | Both the whole-initiative path AND the per-epic 4th-arg path (`coverage_by_epic`) are untested. Mandate explicitly names per-epic coverage. |
| `record-tests-added` | cmd_record_tests_added, 715-730 | P2 | `tests_by_layer` accumulation + `tests_added` rollup never asserted. |
| `get-coverage` | cmd_get_coverage, 732-785 | P2 | Whole-initiative + per-epic rendering + "no coverage" fallback untested. |
| `set-parent <PREFIX> <PARENT>` | cmd_set_parent, 1467-1480 | **P2** | Parent-exists validation (`die` when missing) and `parent_prefix` write untested. Mandate-named. |
| `add-related <PREFIX> <RELATED>` | cmd_add_related, 1483-1503 | **P2** | Idempotent append + related-exists validation untested. Mandate-named. |
| `migrate-path --product --description <PREFIX>` | cmd_migrate_path, 1038-1085 | **P2** | Flat→product move (git mv / mv fallback), target-exists guard, state rewrite — all untested. High-risk (FS move + state mutation). Mandate-named. |
| Auto-backup `.bak` | _write_state_body, 259-262 (T132) | **P2** | `[[ -f "$1" ]] && cp -p "$1" "${1}.bak"` — no test asserts a `.bak` appears after an overwrite. Mandate-named. |
| Advisory lock success path | with_state_lock, 283-316 | P3 | flock path + mkdir fallback never exercised (concurrency assertions are L3; success-path smoke is still absent). Mandate-named. |
| `checkpoint-if-active` drift detection | cmd_checkpoint, 621-682 | P3 | Hash-drift warning branch (the SRD/tickets "modified since recorded" path) untested. |
| `phase-complete` token/cost/hash recording | cmd_phase_complete, 557-619 | P3 | Duration, token sums, cost, and artifact-hash recording untested (token reads depend on session JSONL, so partly environment-bound). |
| `resolve-dir`, `srd-version`, `update-patterns`, `lint`, `gate-check`, `branch-check`, `git-lock-check`, `archive`, `list`, `active-initiatives`, `metrics-report`, `get-coverage` | various | P3 | Broad untested surface; several pre-date v2.0.0. Listed for completeness — prioritize the P2 rows above. |

**Most important gaps to close before deployment** (mandate-named, state-mutating, no coverage at all): `migrate-path`
(L4-08), the per-epic `record-test-coverage` path (L4-06), `set-parent`/`add-related` (L4-07), and the auto-backup
`.bak` mechanism (L4-09).

## Noted / Not Actionable

- **`trap 'rm -rf "$TMP"' EXIT`** (wave3:28, wave4a:37). Legitimate cleanup of a `mktemp -d` scratch dir; `rm -rf`
  here is the canonical harness teardown. Each file creates its own `TMP` and points `EDM_SRD_ROOT` at it, so
  there is no cross-file state leakage. Not a finding.
- **Intra-file state accumulation on `TSMK`** (wave4a: `init TSMK` once at :46, mutated through :223). This is a
  deliberate sequential fixture — each section builds on the prior state (mode set → skip-phase → validate →
  HANDOFF order assertions). It is intentional and consistent; not a teardown-leak defect.
- **`mktemp -d` without an explicit failure guard** (wave3:27, wave4a:36). Under `set -euo pipefail`, a failed
  `mktemp` aborts before any `cd`/write, and these scripts never `cd "$TMP"` (they export `EDM_SRD_ROOT`), so the
  "cd into a dir that failed to create" silent-no-op pattern does not apply here. Not a finding.
- **`|| true` on `validate` (wave4a:149,154,159) and `… 2>&1 || true` generally.** The `|| true` on `validate` is
  *required* because `validate` legitimately exits 3 on anomalies and `set -e` would otherwise abort — it does not
  swallow a "thing under test passes regardless" outcome by itself. The residual concern (absence-on-empty-output)
  is captured as L4-04/L4-05; the bare `|| true` mechanism itself is a justified harness pattern.
- **`|| echo ''` fallback** (wave4a:208). Standard idiom so command substitution yields an empty string when grep
  matches nothing (an expected outcome). Not masking a failure of the unit under test. The *assertion* it feeds is
  the L4-01 tautology; the fallback itself is fine.
- **Top-level `VAR="$(cat …SKILL.md)"` assignments** (wave4b:37,42,51,66,77,100,147,159,171,184). Verified that a
  plain (non-`local`) assignment with a failing command substitution aborts under `set -e` — so a missing/renamed
  source file fails loudly rather than producing a silent false positive. Correct by construction; not a finding.
  (The empty-*slice* case at :121 is different and is filed as L4-02.)
- **`PLUGIN_DIR="$(cd "$(dirname "$0")/../.." && pwd)"`** (wave4b:6). A failed `cd` under `set -e` aborts the
  command substitution and the script; the resolved path is then used only to `cat` files that themselves abort on
  absence. No silent no-op. Not a finding.
