# QC Report: Wave 1d — bin/edm-state enhancements + orchestrator gate fixes

**Wave**: 1d
**Date**: 2026-06-08
**Verdict**: PASS

---

## Tickets Covered

| Ticket | Title | Verdict |
|--------|-------|---------|
| EDMV2-T24 | Advisory file locking in write_state() | PASS |
| EDMV2-T25 | Typed-set path in cmd_set() | PASS |
| EDMV2-T26 | Orchestrator gate false-positive fix | PASS |
| EDMV2-T27 | gate-check subcommand + UserPromptExpansion command hook | PASS |
| EDMV2-T28 | write_handoff_internal() in phase-start | PASS |
| EDMV2-T29 | state_anomalies() detection | PASS |
| EDMV2-T30 | git-aware archive + read_bool() convergence check | PASS |
| EDMV2-T32 | validate subcommand | PASS |
| EDMV2-T33 | read_bool() / read_num() type coercion helpers | PASS |
| EDMV2-T34 | initiative_branch in init + edm-init branch creation | PASS |
| EDMV2-T35 | active-initiatives + branch-check subcommands | PASS |
| EDMV2-T36 | git-lock-check subcommand | PASS |

---

## AC Verification

### EDMV2-T24 — Advisory file locking
- **AC-1**: `with_state_lock()` added after `now_utc()` helper.
  - PASS: `bin/edm-state` lines 198–236, `with_state_lock()` function implemented.
- **AC-2**: flock fast path (FD 200) with 10s timeout.
  - PASS: `flock -w 10 200` used when `command -v flock` succeeds.
- **AC-3**: mkdir fallback (50 × 0.1s = 5s timeout) for macOS.
  - PASS: `until mkdir "$lockdir"` loop with `tries -ge 50` guard.
- **AC-4**: `write_state()` wraps write with `with_state_lock`.
  - PASS: `write_state()` calls `with_state_lock "$lockbase" printf '%s\n' "$content" > "$f"`.
- **AC-5**: Lockbase derived from state file path (strips `.json`).
  - PASS: `lockbase="${f%.json}"` in `write_state()`.

### EDMV2-T25 — Typed-set path
- **AC-1**: Boolean fields (`compliance_enabled`, `code_audit_converged`) use `--argjson` with true/false validation.
  - PASS: `case "$key" in compliance_enabled|code_audit_converged)` branch with `--argjson v "$value"`.
- **AC-2**: Number fields (`current_phase`, `qc_shard_threshold`) use `--argjson` with pattern validation.
  - PASS: `^-?[0-9]+(\.[0-9]+)?$` guard before `--argjson`.
- **AC-3**: Unknown fields retain string behavior for backward compat.
  - PASS: `*) ... jq --arg k --arg v` fallback.

### EDMV2-T26 — Orchestrator gate false-positive fix
- **AC-1**: Each gate section has explicit note: only `AskUserQuestion` "Approve" selection triggers `approve-gate`.
  - PASS: Gate 1 has "CRITICAL — gate approval rules" block. Gates 2 and 3 have "(Apply the gate approval rules...)" cross-reference.
- **AC-2**: Free-text instruction: re-present `AskUserQuestion` rather than inferring approval.
  - PASS: "If the user types free text... re-present the AskUserQuestion with a brief note."

### EDMV2-T27 — gate-check subcommand + hooks
- **AC-1**: `cmd_gate_check <PREFIX> <gated-cmd>` exits 0 when gate is approved.
  - PASS: function checks `length` of matching gates_approved entries; returns 0 if > 0.
- **AC-2**: Exits 1 with human-readable message when gate not approved.
  - PASS: `echo "edm-state gate-check: Gate ${required_gate} has not been approved..." >&2; return 1`.
- **AC-3**: Unknown commands pass through (exit 0).
  - PASS: `*) return 0 ;;` in case block.
- **AC-4**: `UserPromptExpansion` split into 5 per-command matchers, each with `command` hook + `prompt` hook.
  - PASS: `hooks/hooks.json` has matchers for `edm:srd`, `edm:audit-srd`, `edm:tickets`, `edm:audit-tickets`, `edm:implement`.
- **AC-5**: Command hook exits 1 to block expansion when gate check fails.
  - PASS: `|| exit 1` in each command hook.

### EDMV2-T28 — write_handoff_internal in phase-start
- **AC-1**: `write_handoff_internal "$prefix"` called at end of `cmd_phase_start()`.
  - PASS: Added after `write_state "$prefix" "$new"` in `cmd_phase_start()`.

### EDMV2-T29 — state_anomalies()
- **AC-1**: `state_anomalies()` emits `TIME_ORDER` lines when `completed_at < started_at`.
  - PASS: jq filter in `state_anomalies()` compares epochs and emits `TIME_ORDER` lines.
- **AC-2**: Emits `SIZE_UNKNOWN` when `estimated_size == "Unknown"` at phase >= 2.
  - PASS: bash check `[[ "$size" == "Unknown" && "$phase" -ge 2 ]]`.
- **AC-3**: Emits `ZERO_TOKENS` when `model_used` is set but tokens are both 0.
  - PASS: jq filter checks `model_used != null && input == 0 && output == 0`.
- **AC-4**: Never mutates state (read-only).
  - PASS: function only reads via `read_state`; no `write_state` calls.

### EDMV2-T30 — git-aware archive + read_bool convergence
- **AC-1**: `read_bool` used instead of raw jq `.code_audit_converged | tostring` for convergence check.
  - PASS: `converged="$(read_bool "$state_json" "code_audit_converged" "false")"` after field presence check.
- **AC-2**: `git mv` used when inside a git worktree; falls back to `mv`.
  - PASS: `git -C "$src" rev-parse --is-inside-work-tree` guard before `git mv "$src" "$dst" 2>/dev/null || mv "$src" "$dst"`.
- **AC-3**: State loaded once into `state_json` variable (not re-read per field).
  - PASS: `state_json="$(cat "$state_file" 2>/dev/null || echo '{}')"` read once at start.

### EDMV2-T32 — validate subcommand
- **AC-1**: `cmd_validate <PREFIX>` calls `state_anomalies` and exits 3 when anomalies found.
  - PASS: `anomalies="$(state_anomalies "$prefix")"` then `[[ -n "$anomalies" ]] && ... return 3`.
- **AC-2**: Exits 0 and prints clean message when no anomalies.
  - PASS: `echo "# State OK: no anomalies found..."` then `return 0`.
- **AC-3**: Dispatch case includes `validate)`.
  - PASS: `validate) cmd_validate "$@" ;;` in dispatch.

### EDMV2-T33 — read_bool / read_num
- **AC-1**: `read_bool` normalizes JSON boolean and string "true"/"false" → bash "true"/"false".
  - PASS: jq expr handles `type == "boolean"` and `type == "string"` branches with default.
- **AC-2**: `read_num` normalizes JSON number and numeric string → bare number.
  - PASS: jq expr handles `type == "number"` (returns as-is) and `type == "string"` (tonumber) branches.

### EDMV2-T34 — initiative_branch in init + edm-init branch creation
- **AC-1**: `cmd_init()` records current git branch as `initiative_branch` in state JSON.
  - PASS: `branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"` then `initiative_branch: $b` in jq.
- **AC-2**: `bin/edm-init` creates and checks out `edm/{PREFIX}` branch when inside a git worktree.
  - PASS: `if git rev-parse --is-inside-work-tree` block with `git checkout -b "edm/${PREFIX}"`.
- **AC-3**: Switches to existing branch without error if branch already exists.
  - PASS: `git rev-parse --verify "$BRANCH"` check before `git checkout -b`.
- **AC-4**: Outputs branch action to user.
  - PASS: `BRANCH_MSG` variable printed in heredoc output.

### EDMV2-T35 — active-initiatives + branch-check
- **AC-1**: `cmd_active_initiatives` lists only initiatives with `current_phase` 1–6.
  - PASS: `[[ "$phase" -ge 1 && "$phase" -le 6 ]]` filter.
- **AC-2**: `cmd_branch_check <PREFIX>` exits 0 when branch matches or field absent.
  - PASS: `[[ -z "$initiative_branch" ]] && return 0` for legacy state; `current_branch == initiative_branch` check.
- **AC-3**: Exits 1 with advisory on mismatch.
  - PASS: `echo "...does not match..." >&2; return 1`.
- **AC-4**: Both subcommands in dispatch.
  - PASS: `active-initiatives) cmd_active_initiatives "$@"` and `branch-check) cmd_branch_check "$@"`.

### EDMV2-T36 — git-lock-check
- **AC-1**: Checks for `.git/index.lock` and exits 0 if absent.
  - PASS: `[[ ! -f "$lock_file" ]] && echo "no .git/index.lock present"; return 0`.
- **AC-2**: Removes stale lock when no git processes are running.
  - PASS: `pgrep -x git` check; if empty, `rm -f "$lock_file"`.
- **AC-3**: Warns and exits 1 if git processes are running.
  - PASS: `echo "WARNING: .git/index.lock exists and git processes are running..." >&2; return 1`.
- **AC-4**: In dispatch.
  - PASS: `git-lock-check) cmd_git_lock_check "$@"`.

---

## Files Modified

- `plugins/edm-ai-development-staging/bin/edm-state` — T24/T25/T27/T28/T29/T30/T32/T33/T34/T35/T36
- `plugins/edm-ai-development-staging/bin/edm-init` — T34 branch creation
- `plugins/edm-ai-development-staging/hooks/hooks.json` — T27 per-command matchers with command hooks
- `plugins/edm-ai-development-staging/skills/orchestrator/SKILL.md` — T26 gate false-positive rules

---

## Syntax Verification

- `bash -n bin/edm-state` → OK
- `bash -n bin/edm-init` → OK
- `python3 json.load(hooks.json)` → OK
