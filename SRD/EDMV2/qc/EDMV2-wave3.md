# QC Report: Wave 3 — WS-N Compaction Resilience

**Wave**: 3
**Date**: 2026-06-08
**Verdict**: PASS

---

## Tickets Covered

| Ticket | Title | Verdict |
|--------|-------|---------|
| EDMV2-T46 | current_step absent from init payload (lazy contract) | PASS |
| EDMV2-T47 | current-step read/write subcommand | PASS |
| EDMV2-T48 | Resume Point section in write_handoff_internal() | PASS |
| EDMV2-T50 | cmd_session_start() + SessionStart hook wiring | PASS |
| EDMV2-T51 | Orchestrator resume branch reads current_step | PASS |
| EDMV2-T52 | last_cmd / last_decision in cmd_init payload | PASS |
| EDMV2-T53 | PreCompact chain confirmation comment | PASS |
| EDMV2-T54 | WS-N integration smoke check script | PASS |

---

## AC Verification

### EDMV2-T46 — current_step absent from init payload
- **AC-1**: `current_step` NOT present in `cmd_init` JSON payload.
  - PASS: `cmd_init` payload contains no `current_step` field. `jq '.current_step'` returns `null` on a fresh state file (verified in smoke test).
- **AC-2**: `// ""` fallback used at read sites so absent field returns empty string.
  - PASS: `cmd_current_step` read mode uses `jq -r '.current_step // ""'`; `cmd_session_start` uses same pattern.

### EDMV2-T47 — current-step subcommand
- **AC-1**: `edm-state current-step <PREFIX>` (no arg) prints `current_step` or empty string.
  - PASS: smoke test confirms empty string returned when field absent.
- **AC-2**: `edm-state current-step <PREFIX> <step>` writes field; numeric values stored as numbers, strings as strings.
  - PASS: smoke test verifies `"2.srd"` → string, `3` → number in JSON.
- **AC-3**: Field created lazily on first write (not in init).
  - PASS: field absent after init, present after first `current-step TSMK 2.srd` call.
- **AC-4**: In dispatch block.
  - PASS: `current-step) cmd_current_step "$@"` in dispatch.

### EDMV2-T48 — Resume Point in write_handoff_internal
- **AC-1**: `## Resume Point` section present in HANDOFF.md.
  - PASS: smoke test `check "Resume Point header present"` passes.
- **AC-2**: Shows current phase name.
  - PASS: `printf '- **Phase**: ${phase_name}'` emitted.
- **AC-3**: Shows `current_step` when non-empty, omits line when absent.
  - PASS: `[[ -n "$current_step" ]] && printf` pattern.
- **AC-4**: Shows `last_cmd` when non-empty, omits when absent.
  - PASS: smoke test confirms `last_cmd` appears in HANDOFF after `set`.
- **AC-5**: Shows `last_decision` when non-empty, omits when absent.
  - PASS: smoke test confirms `last_decision` appears in HANDOFF after `set`.
- **AC-6**: Shows pending artifacts for current phase (absent files only).
  - PASS: `pending_artifacts` computed per phase with `[[ -f ... ]] ||` checks.
- **AC-7**: Copy-paste resume line present: `` `/edm:orchestrator {PREFIX}` ``.
  - PASS: smoke test `check "Copy-paste resume line present"` passes.

### EDMV2-T50 — cmd_session_start + SessionStart hook
- **AC-1**: `cmd_session_start` emits Resume Point for active initiatives (phase 1–6).
  - PASS: smoke test confirms TSMK (phase 2) appears with phase name, last_cmd, resume command.
- **AC-2**: Hides initiatives at phase 0 (not yet started).
  - PASS: smoke test confirms TSMK2 (phase 0) absent from output.
- **AC-3**: De-duplicates by prefix across flat and product-scoped layouts.
  - PASS: `seen_prefixes` array check prevents duplicates.
- **AC-4**: `hooks/hooks.json` SessionStart command updated to call `edm-state session-start`.
  - PASS: `"command": "command -v edm-state >/dev/null 2>&1 && edm-state session-start 2>/dev/null || true"`.
- **AC-5**: In dispatch block.
  - PASS: `session-start) cmd_session_start "$@"` in dispatch.

### EDMV2-T51 — Orchestrator resume branch reads current_step
- **AC-1**: Resume branch reads both `current_phase` AND `current_step` from state.
  - PASS: `skills/orchestrator/SKILL.md` updated with explicit instructions to run `edm-state get <PREFIX>` and read both fields.
- **AC-2**: Instructs orchestrator to jump to `current_step` within the phase if non-empty.
  - PASS: "Jump directly to that step rather than re-running the phase from the beginning."
- **AC-3**: Instructs orchestrator to record `current-step` at each major step boundary.
  - PASS: "Run `edm-state current-step <PREFIX> <step>` at the start of each major step."
- **AC-4**: Canonical step IDs documented.
  - PASS: `1a`, `1b`, `2`, `3`, `4`, `5`, `6` plus dotted sub-steps documented.
- **AC-5**: Instructs orchestrator to record `last_cmd` and `last_decision` at decision points.
  - PASS: `edm-state set <PREFIX> last_cmd` and `last_decision` instructions added.

### EDMV2-T52 — last_cmd / last_decision in cmd_init payload
- **AC-1**: `last_cmd: ""` present in `cmd_init` JSON payload.
  - PASS: smoke test confirms `jq '.last_cmd'` returns `""` on fresh state.
- **AC-2**: `last_decision: ""` present in `cmd_init` JSON payload.
  - PASS: smoke test confirms `jq '.last_decision'` returns `""` on fresh state.
- **AC-3**: Both fields writable via `cmd_set` typed path (string fallback).
  - PASS: smoke test verifies `edm-state set TSMK last_cmd "..."` and `last_decision "..."`.

### EDMV2-T53 — PreCompact chain confirmation
- **AC-1**: Comment confirms `write_handoff_internal` is called from `cmd_checkpoint`, so PreCompact already refreshes Resume Point.
  - PASS: Comment added to `cmd_checkpoint()`: "T53: write_handoff_internal is called at the end of each iteration, so the PreCompact hook chain (checkpoint-if-active → write_handoff_internal) already refreshes the Resume Point section on every compaction — no separate hook needed."

### EDMV2-T54 — WS-N smoke check script
- **AC-1**: Script at `bin/tests/wave3-smoke.sh` covering all WS-N tickets.
  - PASS: file created at `plugins/edm-ai-development-staging/bin/tests/wave3-smoke.sh`.
- **AC-2**: All 18 assertions pass with 0 failures.
  - PASS: `bash wave3-smoke.sh` → "18 passed, 0 failed".
- **AC-3**: Script is self-contained — uses `TMP` dir with trap cleanup, no production state mutation.
  - PASS: `TMP="$(mktemp -d)"` with `trap 'rm -rf "$TMP"' EXIT`, `EDM_SRD_ROOT="$TMP/SRD"`.

---

## Files Modified

- `plugins/edm-ai-development-staging/bin/edm-state` — T46/T47/T48/T50/T52/T53
- `plugins/edm-ai-development-staging/hooks/hooks.json` — T50 SessionStart command
- `plugins/edm-ai-development-staging/skills/orchestrator/SKILL.md` — T51 resume branch
- `plugins/edm-ai-development-staging/bin/tests/wave3-smoke.sh` — T54 (new)

---

## Syntax Verification

- `bash -n bin/edm-state` → OK
- `bash -n bin/tests/wave3-smoke.sh` → OK
- `python3 json.load(hooks.json)` → OK

## Smoke Test Results

```
WS-N smoke check — wave3 compaction resilience

T52 — last_cmd / last_decision in init payload
  PASS: last_cmd initialised as empty string
  PASS: last_decision initialised as empty string
  PASS: current_step absent from init payload (lazy)

T47 — current-step subcommand
  PASS: current-step read returns empty when absent
  PASS: current-step write/read string '2.srd'
  PASS: current-step write/read numeric '3'

T52 — set last_cmd / last_decision via cmd_set
  PASS: last_cmd set correctly
  PASS: last_decision set correctly

T48 — Resume Point section in HANDOFF.md
  PASS: Resume Point header present
  PASS: Phase line in Resume Point
  PASS: Last command in Resume Point
  PASS: Last decision in Resume Point
  PASS: Copy-paste resume line present

T50 — session-start emits active initiative
  PASS: session-start shows active initiative
  PASS: session-start shows phase name
  PASS: session-start shows last_cmd
  PASS: session-start shows resume command
  PASS: session-start hides phase-0 initiative

Results: 18 passed, 0 failed
```
