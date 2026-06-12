# Epic 2 — Foundation Plumbing (WS-J State Integrity + WS-M Directory Layout + WS-N Compaction Resilience)

Generated From: srd.md v1.0.7

This epic delivers Phase A of the EDMV2 build sequence (SRD section 5.7): the shared state machinery that every other workstream consumes. It must land before Epics 3+ (WS-B/C/D/E/F/G/H/K/L). Three workstreams are sequenced here in dependency order:

1. WS-J (State Integrity and Determinism, EDMV2-66..73 + 107 + 108) — typed state, locking, validation, deterministic gate, git-aware archive, branch isolation. Sequenced first because typed-set (EDMV2-68) and file-locking (EDMV2-70) are the substrate the WS-M/WS-N writes ride on.
2. WS-M (Initiative Directory Structure, EDMV2-85..91) — the `SRD/{PRODUCT}/{PREFIX}__{DESCRIPTION}/` layout, concentrated in `state_file_for()` and a parallel directory resolver.
3. WS-N (Compaction Resilience, EDMV2-92..99) — `current_step`, `## Resume Point`, `SessionStart` injection, `PreCompact` capture.

Per C-5 (SRD section 5.6 / 10.4) all implementation lands in the staging copy `plugins/edm-ai-development-staging/`. All line references in Target Components are to the live source as read at SRD v1.0.7; resolve them against the staging copy at implementation time. All bash must be POSIX (`#!/usr/bin/env bash`, C-3). All schema changes additive and defaulted (C-4). No new external dependency (`jq` + optional `git` only).

Size legend: XS < 1d (1pt) | S 1-3d (2-3pt) | M 3-5d (5pt) | L 1-2wk (8-13pt) | no XL (decompose).

Cross-cutting ACs (every ticket below also satisfies): change lives only in `plugins/edm-ai-development-staging/`; `git diff plugins/edm-ai-development/` stays empty (EDMV2-109); a bash unit check exercises the new/changed path (C-2); no Unicode emitted into any artifact the change touches (C-1, EDMV2-21/75); no AI-attribution string introduced (C-1, EDMV2-74); `claude plugin validate` still passes (EDMV2-101).

---

## WS-J — State Integrity and Determinism (EDMV2-T24 through EDMV2-T36)

## EDMV2-T24: Add advisory file locking to all state writes

| Field | Value |
|---|---|
| Workstream | WS-J |
| Phase | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV2-70 |
| Depends On | (none — first foundation ticket) |
| Target Components | `bin/edm-state:179-186` (`write_state()`) — wrap the write in an advisory lock; add a `with_state_lock()` helper near `:170`; lockfile path derived from `state_file_for()` (e.g. `<dir>/.edm-state.lock`) |

### Description
`write_state()` currently does an unguarded `printf > "$f"` (`bin/edm-state:185`). Two concurrent `edm-state` invocations (e.g. a Stop-hook checkpoint racing a `phase-complete`) can interleave and corrupt `.edm-state.json`. EDMV2-70 requires advisory locking so writes serialize.

The lock must be portable across macOS and Linux (C-3). `flock` is unavailable by default on macOS, so the implementation provides a `flock`-based fast path when present and a `mkdir`-based lock-directory fallback otherwise. The lock is scoped per-initiative (one lockfile per state file) so unrelated initiatives never block each other.

This is sequenced first because every WS-J/M/N write below passes through `write_state()`; locking the single write seam protects all of them.

### Acceptance Criteria
- [ ] AC1: A `with_state_lock <lockpath> <command>` helper exists in `bin/edm-state` and is invoked by `write_state()` before the `printf` at `:185`.
- [ ] AC2: When `flock` is on PATH, the helper acquires an exclusive lock on `<state-dir>/.edm-state.lock` for the duration of the write and releases it after.
- [ ] AC3: When `flock` is absent, the helper falls back to a `mkdir`-based lock directory and spin-waits with a bounded retry (max 50 tries, 100ms apart) before giving up.
- [ ] AC4: On lock-acquisition timeout the helper calls `die` with a message naming the lockfile and the likely holding PID, and exits non-zero rather than writing.
- [ ] AC5: The lock is always released on normal exit and on error (trap-based cleanup for the `mkdir` path).
- [ ] AC6: Two `edm-state set` calls launched in parallel against the same prefix both complete and the resulting `.edm-state.json` is valid JSON containing both writes' effects (last-writer-wins, no truncation).
- [ ] AC7: The lockfile/lockdir is created under the initiative directory, never under the plugin directory (C-3, no plugin-relative paths).
- [ ] AC8: Existing single-threaded callers (`set`, `init`, `phase-complete`, `approve-gate`, `checkpoint-if-active`) behave identically to v1.x when no contention exists.

### Technical Notes
Use `flock -w <secs> 200` on FD 200 for the fast path. For the fallback, `mkdir "$lockdir"` is atomic on POSIX filesystems; store the PID in `$lockdir/pid` so AC4 can name the holder and a future ticket (EDMV2-T36) can detect a dead holder. Keep `set -euo pipefail` intact — guard the spin loop so a transient failure does not abort the script. Do not introduce a global lock; per-initiative scoping avoids the WS-N hooks deadlocking each other.

### Out of Scope
Git index locking (that is EDMV2-T36 / EDMV2-108). Cross-machine coordination (explicitly rejected, SRD section 5.0). Retrofitting locking onto reads (`read_state` stays lock-free).

### Verification
QC auditor runs the bash unit check that forks two `edm-state set` writes in parallel and asserts the file remains valid JSON with both effects (AC6); confirms the `with_state_lock` helper is present and called from `write_state()` (AC1); confirms no lockfile is created under the plugin dir (AC7). PASS when all hold; PARTIAL acceptable only for the race test if the harness cannot fork (deferred-to-runtime note required).

---

## EDMV2-T25: Add typed-set path for known boolean/number/timestamp fields

| Field | Value |
|---|---|
| Workstream | WS-J |
| Phase | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV2-68 |
| Depends On | EDMV2-T24 |
| Target Components | `bin/edm-state:197-205` (`cmd_set`) — add a known-typed-field table and an `--argjson` branch; new `set-typed` dispatch entry near `:779`; help block `:5` |

### Description
`cmd_set` coerces every value to a string via `--arg` (`bin/edm-state:203`), so `edm-state set EDMV2 compliance_enabled false` writes the JSON string `"false"`, not the boolean `false`. EDMV2-68 requires correct JSON types for known-typed fields (booleans, numbers, ISO timestamps).

The fix adds a typed-set path: a lookup of the known field name to its JSON type, and an `--argjson` write when the field is typed (with a value-shape validation so a malformed boolean is rejected, not silently stringified). Unknown/free-text fields keep the existing `--arg` string behavior for backward compatibility.

### Acceptance Criteria
- [ ] AC1: A field-to-type table maps at minimum `compliance_enabled`->boolean, `code_audit_converged`->boolean, `current_phase`->number, `qc_shard_threshold`->number to their JSON types.
- [ ] AC2: `edm-state set EDMV2 compliance_enabled true` results in `jq '.compliance_enabled' .edm-state.json` printing `true` (JSON boolean), not `"true"`.
- [ ] AC3: `edm-state set EDMV2 code_audit_converged false` yields a JSON boolean `false`.
- [ ] AC4: Setting a number field yields a JSON number (e.g. `qc_shard_threshold` -> `20`, not `"20"`).
- [ ] AC5: Setting a typed field with a non-conforming value (e.g. `compliance_enabled maybe`) fails with a `die` message and non-zero exit; the state file is unchanged.
- [ ] AC6: Setting an unknown field (e.g. `set EDMV2 foo bar`) keeps the v1.x string behavior (`"bar"`).
- [ ] AC7: The typed-set write goes through `write_state()` and therefore acquires the lock from EDMV2-T24.
- [ ] AC8: A legacy state file that already stores `code_audit_converged` as the string `"false"` is still read correctly by the gating logic (read-side coercion documented for EDMV2-T33).
- [ ] AC9: `.last_updated` is refreshed on every successful set, as today.

### Technical Notes
Implement with a `case "$key" in` mapping inside `cmd_set` rather than a separate subcommand, so existing skill callers need no change (per SRD section 5.4 type-handling note). Use `jq --argjson v "$value"` only after a shape check: for booleans accept exactly `true|false`; for numbers test against `^-?[0-9]+(\.[0-9]+)?$`. Do not rewrite unrelated fields on read (no auto-migration of the whole file — that is EDMV2-T33's bounded read-side coercion).

### Out of Scope
The `validate` subcommand (EDMV2-T32). Auto-migrating every legacy stringified field on disk. New typed fields' semantics (those are owned by their introducing workstream's tickets).

### Verification
Bash unit check sets each typed field and asserts `jq` returns the native JSON type (AC2-AC4); sets a malformed boolean and asserts non-zero exit + unchanged file (AC5); sets an unknown field and asserts string behavior (AC6). PASS when type assertions hold for all four table entries.

---

## EDMV2-T26: Gate false-positive fix — free-text is never approval

| Field | Value |
|---|---|
| Workstream | WS-J |
| Phase | A |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV2-67 |
| Depends On | (none) |
| Target Components | `skills/orchestrator/SKILL.md` Gate handlers — Steps 6/7/8 at `:160-179`, mirrored at `:196-212` and `:231-248` (HITL gate prompt + `approve-gate` call sites) |

### Description
The orchestrator's HITL gate handler currently treats the `AskUserQuestion` answer as approval too loosely: free text typed into the "Other" field is misrouted as an approval and triggers `edm-state approve-gate`. EDMV2-67 requires that `approve-gate` is called ONLY when the user explicitly selects the "Approve" option. Any free-text in the "Other" field must be a no-op that re-prompts the same gate (per the sequence diagram in SRD section 5.3.B).

This is a prompt-logic change in the three gate handlers, not a code change to `edm-state`. It complements the deterministic script gate (EDMV2-T27) from the other direction: T27 prevents entering a gated phase prematurely; this ticket prevents falsely satisfying a gate.

### Acceptance Criteria
- [ ] AC1: Each of the three gate handlers (`:160-179`, `:196-212`, `:231-248`) presents an `AskUserQuestion` with an explicit "Approve" option label (plus Revise / No-Go).
- [ ] AC2: The handler calls `edm-state approve-gate <PREFIX> <N>` only on an exact match of the "Approve" option selection.
- [ ] AC3: Free text entered in the "Other" field is treated as a no-op and triggers a re-prompt that restates the gate summary and the same option set.
- [ ] AC4: A "No-Go" selection does not call `approve-gate` and routes to the documented no-go path.
- [ ] AC5: A "Revise" selection does not call `approve-gate` and routes back to the relevant phase.
- [ ] AC6: The handler instructions explicitly state, in prose the orchestrator reads, that free-text is never approval (mirrors SRD section 9.1).
- [ ] AC7: All three gate handlers are updated identically (no divergence between Gate 1/2/3 logic).

### Technical Notes
Because the orchestration layer is an LLM-read prompt (SRD section 5.0), the "fix" is precise prompt wording plus an explicit conditional: "IF and ONLY IF the selected option is exactly 'Approve', call `edm-state approve-gate`; otherwise re-prompt." Keep the option labels stable so a future deterministic check can match on them. Pair the re-prompt with the gate summary so the user is not left without context.

### Out of Scope
The deterministic script-backed gate hook (EDMV2-T27). Changing `approve-gate`'s own behavior in `edm-state`.

### Verification
QC auditor inspects the three handler blocks and confirms each gates the `approve-gate` call behind an exact "Approve" selection and re-prompts on free-text (AC2/AC3). Because behavior is prompt-driven, this is a structural/static PASS; an interactive sandbox run submitting Other-field text and confirming no gate is recorded is the runtime confirmation (record PARTIAL/deferred-to-runtime if no interactive sandbox).

---

## EDMV2-T27: Deterministic script-backed gate enforcement hook

| Field | Value |
|---|---|
| Workstream | WS-J |
| Phase | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV2-66 |
| Depends On | EDMV2-T24 |
| Target Components | `hooks/hooks.json:13-23` (`UserPromptExpansion`) — add a `command` hook alongside the existing `prompt` hook; new `gate-check <PREFIX> <phase>` subcommand in `bin/edm-state` (dispatch near `:783`) |

### Description
Today the gate is enforced only by a `prompt` hook (`hooks.json:18-19`) — an LLM instruction that can be ignored or mis-evaluated. EDMV2-66 requires a deterministic, model-independent block: a `command` hook that runs an `edm-state`-backed check and exits non-zero to hard-block a premature gated phase.

The new `gate-check` subcommand reads `gates_approved` and maps the matched command (`edm:srd`->gate 1, `edm:tickets`->gate 2, `edm:implement`->gate 3) to its prerequisite; it exits 0 when satisfied (or when no state file exists — first invocation) and non-zero with an actionable message otherwise. The existing prompt hook stays as an advisory complement (SRD section 5.6 Risk 3).

### Acceptance Criteria
- [ ] AC1: `bin/edm-state gate-check <PREFIX> <gated-command>` exists and reads `gates_approved` from state via `read_state`.
- [ ] AC2: For `edm:srd`/`edm:audit-srd` it requires gate 1; for `edm:tickets`/`edm:audit-tickets` gate 2; for `edm:implement` gate 3.
- [ ] AC3: When the prerequisite gate is missing it exits non-zero and prints a message naming the prefix, the missing gate number, and the remediation (`run the prior phase or /edm:orchestrator`).
- [ ] AC4: When the prerequisite gate is present it exits 0 silently.
- [ ] AC5: When no state file exists (first invocation) it exits 0 (does not block bootstrap), matching the prompt hook's step 5.
- [ ] AC6: `hooks/hooks.json` `UserPromptExpansion` gains a `command` hook (guarded by `command -v edm-state`) matching the same `edm:(srd|tickets|implement)` matcher, run in addition to the existing prompt hook.
- [ ] AC7: The command hook's non-zero exit hard-blocks expansion (documented as the one hook allowed to fail the action, per SRD section 5.5).
- [ ] AC8: The check is read-only (no `write_state`, no lock needed) and never mutates state.
- [ ] AC9: A unit check invoking `gate-check` against a state file with gate 2 unapproved + `edm:tickets` exits non-zero; with gate 2 approved exits 0.

### Technical Notes
The command hook must remain non-fatal when `edm-state` is absent (`command -v edm-state >/dev/null 2>&1 && edm-state gate-check ... ` but WITHOUT the trailing `|| true` that other hooks use, since the non-zero exit is the intended block — see SRD section 5.5). The determinism guarantee covers only the three matched skill prefixes (SRD Risk 3); document that scope in the subcommand help. Map the gated command from the hook's `$ARGUMENTS` first token.

### Out of Scope
Blocking direct agent spawns that bypass the matched skills (out of the matcher's reach, Risk 3). The free-text approval guard (EDMV2-T26).

### Verification
Bash unit check runs `gate-check` against crafted state files for each gate/command pairing and asserts exit codes (AC2/AC9); confirms the new `command` hook is present in `hooks.json` without `|| true` masking (AC6/AC7). PASS when exit codes are correct for all three command families and the hook entry exists.

---

## EDMV2-T28: current_phase / HANDOFF consistency

| Field | Value |
|---|---|
| Workstream | WS-J |
| Phase | A |
| Priority | Should Have |
| Size | S |
| SRD Refs | EDMV2-72 |
| Depends On | EDMV2-T24 |
| Target Components | `bin/edm-state:281-341` (`cmd_phase_complete`), `:266-279` (`cmd_phase_start`), `:631-766` (`write_handoff_internal`) — ensure HANDOFF is regenerated from the just-written `current_phase`, never a stale read |

### Description
EDMV2-72 requires `current_phase` in state to stay consistent with the phase rendered in HANDOFF.md with no lag. Today `phase_start` writes `current_phase` (`:274`) and `phase_complete` calls `write_handoff_internal` at the end (`:340`); the risk is any path that mutates phase without re-rendering HANDOFF, or renders HANDOFF from a stale in-memory `$current`.

This ticket audits every phase-mutating path and guarantees HANDOFF is rendered from freshly-read state after the write, so the phase shown in HANDOFF always equals the phase in state.

### Acceptance Criteria
- [ ] AC1: Every code path that changes `current_phase` calls `write_handoff_internal` after `write_state` completes.
- [ ] AC2: `write_handoff_internal` reads the phase from the on-disk state file (`:634-642`), not from a caller-passed stale variable.
- [ ] AC3: After `edm-state phase-start EDMV2 2`, both `jq .current_phase` and the `## Current Status` Phase line in HANDOFF.md read Phase 2.
- [ ] AC4: After `edm-state phase-complete EDMV2 2`, state and HANDOFF agree on the phase and gates count.
- [ ] AC5: `phase-start` triggers a HANDOFF refresh (currently it does not call `write_handoff_internal`) so the phase line never lags a started-but-not-completed phase.
- [ ] AC6: No regression to the existing `## Notes` preservation behavior (`:725-732`).
- [ ] AC7: A unit check transitions phases and diffs `jq .current_phase` against the rendered HANDOFF phase line, asserting equality after each transition.

### Technical Notes
Add a `write_handoff_internal "$prefix"` call at the end of `cmd_phase_start` (it is currently absent). Confirm `write_handoff_internal` always re-`cat`s the state file (it does, at `:639`). Keep the Notes-section preservation awk intact. Mind that adding a HANDOFF write to `phase_start` means it now takes the EDMV2-T24 lock — acceptable.

### Out of Scope
The Resume Point section (EDMV2-T48). Mode/linkage rendering (owned by WS-E/F/G tickets in later epics).

### Verification
Bash unit check asserts `jq .current_phase` equals the parsed HANDOFF Phase line after both `phase-start` and `phase-complete` (AC3/AC4/AC7). PASS on equality across a 0->1->2 transition sequence.

---

## EDMV2-T29: State-anomaly guards (detection rules)

| Field | Value |
|---|---|
| Workstream | WS-J |
| Phase | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV2-69 |
| Depends On | EDMV2-T25 |
| Target Components | `bin/edm-state` — new `state_anomalies()` helper (near `:170`) producing a findings list consumed by `validate` (EDMV2-T32); reads `phase_durations`, `estimated_size`, `tokens`, `model_used` |

### Description
EDMV2-69 requires detection of three observed anomaly classes: `completed_at` earlier than `started_at`; `estimated_size` left `"Unknown"` for a sized initiative; and zeroed tokens / `model_used` where data should exist. This ticket implements the detection logic as a reusable `state_anomalies()` helper; EDMV2-T32 wires it into the `validate` subcommand.

The helper must never mutate state (SRD section 6.2 — validate reports but does not auto-fix). It emits a structured, ASCII-only findings list (one line per anomaly with a stable code) that `validate` formats.

### Acceptance Criteria
- [ ] AC1: A `state_anomalies <PREFIX>` helper exists, reads state via `read_state`, and emits zero or more anomaly lines.
- [ ] AC2: Detects, per phase entry in `phase_durations`, any `completed_at` whose ISO time is earlier than that entry's `started_at` (anomaly code `TIME_ORDER`).
- [ ] AC3: Detects `estimated_size == "Unknown"` when `current_phase >= 2` (the initiative is past planning, so size should be set) (anomaly code `SIZE_UNKNOWN`).
- [ ] AC4: Detects a phase entry with `model_used` set to a real model but zeroed `tokens.input` and `tokens.output` (anomaly code `ZERO_TOKENS`).
- [ ] AC5: Each anomaly line is ASCII-only and includes the code, the affected field/phase, and a one-line human description.
- [ ] AC6: The helper exits 0 and prints nothing when no anomalies are found.
- [ ] AC7: The helper performs no `write_state` and acquires no lock (read-only).
- [ ] AC8: ISO time comparison uses `fromdateiso8601` in jq (consistent with `:317`), handling missing timestamps without error.

### Technical Notes
Reuse the jq `fromdateiso8601` pattern already in `cmd_phase_complete:317`. Treat absent fields as non-anomalous (a phase that never completed has no `completed_at` to compare). Keep anomaly codes stable strings so `validate` output and any future hook can grep them. Do not flag legacy initiatives for missing v2 fields — only the three EDMV2-69 classes.

### Out of Scope
The `validate` subcommand wrapper and its dispatch entry (EDMV2-T32). Auto-remediation of any anomaly.

### Verification
Bash unit check feeds crafted state files (one per anomaly class) and asserts the matching code appears; feeds a clean file and asserts empty output + exit 0 (AC6). PASS when all three codes fire on their crafted inputs and the clean case is silent.

---

## EDMV2-T30: Git-aware archive with three-case completion gating

| Field | Value |
|---|---|
| Workstream | WS-J |
| Phase | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV2-71, EDMV2-15 |
| Depends On | EDMV2-T25, EDMV2-T37 |
| Target Components | `bin/edm-state:488-498` (`cmd_archive`) — replace bare `mv` at `:496` with `git mv` when tracked; add the three-case `code_audit_converged` gating; resolve src/dst via the state-derived resolver (EDMV2-T37) |

### Description
`cmd_archive` does a bare `mv` (`bin/edm-state:496`) and applies no completion gating. EDMV2-71 requires the archive to be git-aware (use `git mv` so the relocation is staged in version control when the directory is tracked, falling back to plain `mv` when not). EDMV2-15 requires three-case completion gating on `code_audit_converged`.

The three cases (SRD sections 4.1/8.2): refuse when `code_audit_converged` is explicitly `false` AND `product_name` is set (a v2 initiative that has not converged); proceed with a warning when `code_audit_converged` is absent (legacy/v1) OR `mode` is `prototype`; proceed silently when `code_audit_converged` is `true`. The src/dst paths must come from the EDMV2-T37 resolver so archiving works for both flat and product-scoped layouts.

### Acceptance Criteria
- [ ] AC1: Source and destination directories are resolved via the state-derived directory resolver (EDMV2-T37), supporting both `SRD/{PREFIX}/` and `SRD/{PRODUCT}/{PREFIX}__{DESC}/`.
- [ ] AC2: When the initiative directory is inside a git work tree, the move uses `git mv` (or `git rm --cached` + `mv` + `git add`) so the rename is staged.
- [ ] AC3: When not git-tracked (or `git` absent), it falls back to plain `mv` (guarded by `command -v git`, matching `:504`).
- [ ] AC4: Archive is refused (non-zero exit, actionable message) when `code_audit_converged == false` (typed boolean) AND `product_name` is non-empty.
- [ ] AC5: Archive proceeds with a printed warning when `code_audit_converged` is absent from state (legacy/v1 initiative).
- [ ] AC6: Archive proceeds with a printed warning when `mode == "prototype"`, regardless of convergence.
- [ ] AC7: Archive proceeds silently (no warning) when `code_audit_converged == true`.
- [ ] AC8: The destination is `<srd-root>/.archived/<archive-name>` where the archive-name preserves the `{PREFIX}__{DESC}` form for product-scoped initiatives.
- [ ] AC9: Reading `code_audit_converged` tolerates a legacy stringified `"false"`/`"true"` (coercion shared with EDMV2-T33) so gating is correct for both forms.
- [ ] AC10: A unit check exercises all three gating cases plus the git-tracked vs untracked branches.

### Technical Notes
Detect a work tree with `git rev-parse --is-inside-work-tree 2>/dev/null`. Use `git mv` which both moves and stages; if the destination's parent is not yet created, `mkdir -p` first then `git mv`. The convergence read must use `// false` defaulting but distinguish absent (legacy) from explicit `false`: check `has("code_audit_converged")` in jq to separate AC4 from AC5. The `product_name` presence is the v2-initiative signal (SRD section 10.2).

### Out of Scope
Per-gate artifact commits (EDMV2-T34). The convergence computation itself (WS-B, later epic) — this ticket only reads the flag. Setting `code_audit_converged` (orchestrator/WS-B owns the write).

### Verification
Bash unit check: in a temp git repo, archive a product-scoped initiative with `code_audit_converged true` and assert a staged rename (`git status` shows renamed) (AC2); assert refusal for explicit-false+product_name (AC4); assert warning for absent flag (AC5) and prototype mode (AC6). PASS when all three gating cases and the git-mv branch behave as specified.

---

### Reserved: EDMV2-T31

> Note: `current_phase`/HANDOFF consistency is delivered by EDMV2-T28. No separate ticket is allocated to EDMV2-72 here; T28 is its sole ticket. This heading is intentionally omitted from the index. (Numbering continues at T32 to preserve the WS-J -> WS-M -> WS-N block ordering.)

---

## EDMV2-T32: edm-state validate subcommand

| Field | Value |
|---|---|
| Workstream | WS-J |
| Phase | A |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV2-73 |
| Depends On | EDMV2-T29 |
| Target Components | `bin/edm-state` — new `cmd_validate()` + dispatch entry near `:793`; help block `:2-21`; consumes `state_anomalies()` from EDMV2-T29 |

### Description
EDMV2-73 requires a `validate <PREFIX>` subcommand that checks the state file for the EDMV2-69 anomalies and reports findings. This ticket wraps the `state_anomalies()` helper (EDMV2-T29) in a user-facing subcommand with formatted output and a meaningful exit code, and never mutates state (SRD section 6.2).

### Acceptance Criteria
- [ ] AC1: `bin/edm-state validate <PREFIX>` exists and is wired into the dispatch `case` block.
- [ ] AC2: It calls `state_anomalies` and prints each finding as an ASCII-only line under a `# State Validation - <PREFIX>` header.
- [ ] AC3: It exits 0 when no anomalies are found and prints a clear "no anomalies" line.
- [ ] AC4: It exits non-zero (e.g. 3) when one or more anomalies are found, so the result is scriptable in a hook.
- [ ] AC5: It is read-only — no `write_state`, no lock, no HANDOFF rewrite.
- [ ] AC6: It dies cleanly with a usage message when called with the wrong argument count.
- [ ] AC7: The help/usage comment block at the top of `bin/edm-state` lists the new subcommand.
- [ ] AC8: Running `validate` on a known-bad state file reports the specific anomaly codes from EDMV2-T29 (TIME_ORDER, SIZE_UNKNOWN, ZERO_TOKENS).

### Technical Notes
Keep the exit-code contract distinct from `die`'s exit 1 so callers can distinguish "anomalies found" (3) from "usage/error" (1). This subcommand is a candidate for wiring into a future health hook but no hook wiring is in scope here. Output must be greppable (stable codes) so CI/sandbox checks can assert on it.

### Out of Scope
Auto-remediation. The anomaly detection logic itself (EDMV2-T29). Hook integration of validate.

### Verification
Bash unit check runs `validate` on the EDMV2-T29 crafted bad files and asserts both the printed codes (AC8) and the non-zero exit (AC4); runs on a clean file and asserts exit 0 + "no anomalies" (AC3). PASS when exit codes and printed codes match for both cases.

---

## EDMV2-T33: Read-side type coercion for legacy stringified known fields

| Field | Value |
|---|---|
| Workstream | WS-J |
| Phase | A |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV2-68 |
| Depends On | EDMV2-T25 |
| Target Components | `bin/edm-state` — a `read_bool()` / `read_num()` jq-helper used by `cmd_archive` (`:488`), gate logic, and any consumer of typed fields; documented in SRD section 6.2 migration note |

### Description
SRD section 6.2 and EDMV2-68 require that previously string-typed known fields are coerced correctly on read without rewriting unrelated state. A v1.x file may hold `code_audit_converged: "false"` (string) while a v2 write produces `code_audit_converged: false` (boolean). Consumers (notably the archive gate, EDMV2-T30) must treat both identically.

This ticket adds small read-side coercion helpers so every typed-field reader gets a normalized native value regardless of how the field was stored, with no on-disk mutation.

### Acceptance Criteria
- [ ] AC1: A `read_bool <state-json> <field>` helper returns a normalized boolean for both JSON-boolean and JSON-string (`"true"`/`"false"`) storage.
- [ ] AC2: A `read_num <state-json> <field>` helper returns a number for both JSON-number and numeric-string storage.
- [ ] AC3: An absent field returns the documented default (false / 0 / caller-specified) without error.
- [ ] AC4: `cmd_archive`'s convergence gate (EDMV2-T30) uses `read_bool` so a legacy stringified `"false"` is correctly treated as not-converged.
- [ ] AC5: Coercion is read-only — the on-disk value is not rewritten by the act of reading.
- [ ] AC6: An unrecognized/garbage value for a typed field falls back to the default and is surfaceable as an anomaly (cross-references EDMV2-T29 where applicable).
- [ ] AC7: A unit check feeds both stringified and native forms and asserts identical normalized reads.

### Technical Notes
Implement as jq filters: `(.field // false) | if type=="string" then (.=="true") else . end` for booleans; analogous `tonumber?` for numbers with a `// default` guard. Keep the helpers tiny and pure so they can be reused by EDMV2-T30 and the future WS-B/WS-E typed readers. Do not coerce free-text/unknown fields.

### Out of Scope
A bulk on-disk migration pass. The write-side typed-set (EDMV2-T25). Anomaly reporting (EDMV2-T29).

### Verification
Bash unit check reads `code_audit_converged` from one file storing `"false"` and one storing `false`, asserting both normalize to the same not-converged result (AC1/AC7). PASS when the two forms produce identical reads across bool and num helpers.

---

## EDMV2-T34: Initiative branch creation at init and per-gate artifact commits

| Field | Value |
|---|---|
| Workstream | WS-J |
| Phase | A |
| Priority | Must Have |
| Size | L |
| SRD Refs | EDMV2-107 |
| Depends On | EDMV2-T25, EDMV2-T39 |
| Target Components | `bin/edm-init:19-36` (create + checkout `edm/{PREFIX}`, record `initiative_branch`); `skills/orchestrator/SKILL.md` gate handlers (`:160-179`, `:196-212`, `:231-248`) + Phase 6 completion block — stage+commit artifacts per gate; `bin/edm-state` init payload (`:218-230`) gains `initiative_branch` |

### Description
EDMV2-107 requires each initiative to live on a dedicated git branch `edm/{PREFIX}` created at `edm-init` time and recorded in state as `initiative_branch`, with per-gate artifact commits: Gate 1 -> commit `planning.md`; Gate 2 -> commit `srd.md` + `audit-srd.md`; Gate 3 -> commit `tickets/`; Phase 6 complete -> commit implementation, test, and code-audit artifacts. Every commit must obey C-1 (gitmoji shortcodes, no AI-attribution trailers, explicit `git add` by name, separate parallel git calls, never `git add -A`).

This is the largest WS-J ticket because it spans `edm-init` (branch creation + state field) and three orchestrator gate handlers plus the Phase 6 completion path. It depends on the WS-M resolver (EDMV2-T39) so the staged artifact paths are correct under the new layout, and on EDMV2-T25 so `initiative_branch` is stored as a proper string field.

### Acceptance Criteria
- [ ] AC1: `edm-init` creates and checks out branch `edm/{PREFIX}` when inside a git work tree, after the directory scaffold and before printing the next-step message.
- [ ] AC2: The branch name is written to `.edm-state.json` as `initiative_branch` (string) at init time.
- [ ] AC3: When the repo is not a git work tree, `edm-init` skips branch creation gracefully (warning, non-fatal) and leaves `initiative_branch` empty.
- [ ] AC4: Gate 1 approval stages and commits exactly `planning.md` (explicit path, never `git add -A`) on the initiative branch before `approve-gate` records the gate.
- [ ] AC5: Gate 2 approval commits `srd.md` and `audit-srd.md` (explicit paths) on the initiative branch.
- [ ] AC6: Gate 3 approval commits the `tickets/` tree (explicit path) on the initiative branch.
- [ ] AC7: Phase 6 completion commits implementation artifacts, test artifacts, and code-audit outputs (explicit paths) on the initiative branch.
- [ ] AC8: Every commit message uses a gitmoji shortcode form (`:memo:`), never the Unicode glyph form; `grep -P '[^\x00-\x7F]'` over any emitted commit-message template returns nothing. Messages reference the PREFIX scope and contain no AI-attribution trailer (C-1).
- [ ] AC9: Git commands in the skill are issued as separate parallel Bash calls, never chained with `&&` (C-1).
- [ ] AC10: All artifact paths to be staged are resolved via the EDMV2-T39 directory resolver (correct under both layouts).
- [ ] AC11: A branch-creation failure (e.g. dirty tree, existing branch) produces an actionable message and does not silently proceed on the wrong branch.

### Technical Notes
Create the branch with `git switch -c edm/${PREFIX}` (or `git checkout -b`) guarded by `git rev-parse --is-inside-work-tree`. If `edm/{PREFIX}` already exists, `git switch edm/${PREFIX}` instead of failing hard, then warn. The per-gate commits are orchestrator-prompt instructions (the skill emits the exact `git add <path>` then `git commit -m :gitmoji: scope: msg` calls); follow the marketplace `/commit` conventions. Reuse EDMV2-T36's stale-lock check before each commit. <!-- edm-lint-ignore -->
The commit body must never include `Co-Authored-By` or `Generated with`.

### Out of Scope
Simultaneous-initiative detection / branch-mismatch blocking (EDMV2-T35). Stale git-lock remediation mechanics (EDMV2-T36). The actual artifact authoring (owned by each phase's agents).

### Verification
Sandbox/git unit check: `edm-init` in a temp repo creates `edm/{PREFIX}`, sets `initiative_branch` in state (AC1/AC2); simulate each gate approval and assert a new commit on the branch containing only the expected explicit paths with a gitmoji, attribution-free message (AC4-AC8); assert no `git add -A`/`.` and no `&&`-chained git calls in the skill text (AC9). PASS on branch + per-gate commit assertions; PARTIAL acceptable for the interactive gate commits if no interactive sandbox (deferred-to-runtime note).

---

## EDMV2-T35: Simultaneous-initiative detection and branch-mismatch blocking

| Field | Value |
|---|---|
| Workstream | WS-J |
| Phase | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV2-107 |
| Depends On | EDMV2-T34 |
| Target Components | `skills/orchestrator/SKILL.md` phase-start logic (Step 1 / resume branch) + new `bin/edm-state active-initiatives` and `branch-check <PREFIX>` helpers (dispatch near `:793`) |

### Description
The second clause of EDMV2-107 requires that when two initiatives in the same repo are simultaneously active (both with `current_phase` in 1-6, neither archived), the orchestrator detects this on any phase start, warns, and verifies each is on its own branch. A mismatch between `initiative_branch` in state and the current working branch must surface as a blocking error with switch instructions.

This ticket adds the detection helpers and wires them into the orchestrator's phase-start/resume logic. It depends on EDMV2-T34 (which creates `initiative_branch` and the per-gate commit flow).

### Acceptance Criteria
- [ ] AC1: `edm-state active-initiatives` lists all initiatives whose directory exists, is NOT under `.archived/`, and whose `current_phase` is in 1-6 (the active definition, SRD section 6.1).
- [ ] AC2: `edm-state branch-check <PREFIX>` compares `initiative_branch` in state against the current git branch (`git branch --show-current`) and exits non-zero on mismatch.
- [ ] AC3: On any phase start the orchestrator runs `active-initiatives`; when more than one is active it warns the user, naming each active prefix and its branch.
- [ ] AC4: On a branch mismatch `branch-check` prints an actionable message instructing the user to `git switch <initiative_branch>` and the orchestrator blocks the phase from proceeding.
- [ ] AC5: When `initiative_branch` is empty (non-git repo or legacy initiative), `branch-check` exits 0 (no mismatch possible) so legacy/flat initiatives are not blocked (C-4).
- [ ] AC6: A single active initiative on its correct branch produces no warning and proceeds normally.
- [ ] AC7: The helpers are read-only and acquire no state lock.
- [ ] AC8: A unit check with two crafted active state files asserts the multi-active warning fires; a mismatched-branch case asserts non-zero `branch-check`.

### Technical Notes
`active-initiatives` reuses the `cmd_list` glob pattern (`:237`) but filters on `current_phase` in 1..6 and excludes `.archived/`. `branch-check` uses `git branch --show-current` guarded by `git rev-parse --is-inside-work-tree`; outside a work tree it exits 0. The orchestrator change is prompt logic: "run `active-initiatives`; if >1, warn; run `branch-check <PREFIX>`; if non-zero, BLOCK with the printed instruction." Keep messages ASCII-only (C-1).

### Out of Scope
Branch creation and per-gate commits (EDMV2-T34). Auto-switching branches on the user's behalf (the orchestrator instructs; the user switches).

### Verification
Bash unit check: two active state files -> `active-initiatives` lists both and the multi-active condition is detectable (AC1/AC8); a state file whose `initiative_branch` differs from the current branch -> `branch-check` exits non-zero with switch instructions (AC2/AC4); empty `initiative_branch` -> exit 0 (AC5). PASS on all exit-code and listing assertions.

---

## EDMV2-T36: Stale git lock detection and remediation

| Field | Value |
|---|---|
| Workstream | WS-J |
| Phase | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV2-108 |
| Depends On | (none) |
| Target Components | new `bin/edm-state git-lock-check` (dispatch near `:793`) and/or a `PreToolUse` hook on Bash calls containing `git` in `hooks/hooks.json`; checks `.git/index.lock` liveness |

### Description
EDMV2-108 requires that before any git write (commit/add/merge) the system checks for a stale `.git/index.lock`. A lock with no live holding process must be removed automatically; a lock held by a live process triggers a bounded wait and then an actionable, named-process error rather than a silent failure. The SRD permits implementing this as a pre-git helper in `bin/edm-state`, a `PreToolUse` hook, or both.

This ticket is independent of the branch-commit work but is consumed by EDMV2-T34's per-gate commits, which should call the check before each commit.

### Acceptance Criteria
- [ ] AC1: `edm-state git-lock-check` detects the presence of `.git/index.lock` in the current repo.
- [ ] AC2: When the lock exists and no live git process holds it, the lock is removed automatically and the check exits 0 so the subsequent git write proceeds.
- [ ] AC3: When a live process holds the lock, the check does NOT remove it; it waits with a bounded timeout (configurable, default e.g. 10s) and then exits non-zero.
- [ ] AC4: The non-zero path prints an actionable message naming the holding process (PID/command) and how to resolve it, rather than failing silently.
- [ ] AC5: Liveness is determined without assuming GNU-only tools (use `kill -0 <pid>` / `ps`), POSIX-portable (C-3).
- [ ] AC6: When no lock exists the check exits 0 immediately.
- [ ] AC7: Outside a git work tree the check exits 0 (no-op).
- [ ] AC8: If wired as a `PreToolUse` hook, the matcher targets Bash invocations containing `git` and the hook is guarded so a missing `edm-state` never breaks the session.
- [ ] AC9: A unit check creates a stale lock (no holder) and asserts auto-removal + exit 0; creates a lock attributed to a live PID and asserts non-removal + non-zero exit + named-process message.

### Technical Notes
Determine the holder by checking for a running `git` process; `.git/index.lock` does not record its owner PID, so use a best-effort scan (`pgrep -f 'git '` or `ps`) plus a timestamp/age heuristic — document the heuristic's limits in the help. `kill -0` tests liveness portably. For the bounded wait, reuse the spin-loop pattern from EDMV2-T24. Removing a genuinely-stale lock is `rm -f .git/index.lock`. Keep messages ASCII-only.

### Out of Scope
The advisory `.edm-state.lock` (that is EDMV2-T24's separate lock). Resolving locks in worktrees other than the current one.

### Verification
Bash unit check in a temp repo: touch `.git/index.lock` with no live holder -> `git-lock-check` removes it and exits 0 (AC2/AC9); simulate a live holder -> assert non-removal, non-zero exit, and a message naming the process (AC3/AC4/AC9); no lock -> exit 0 (AC6). PASS on both the stale-removal and live-hold paths.

---

## WS-M — Initiative Directory Structure (EDMV2-T37 through EDMV2-T45)

## EDMV2-T37: state_file_for() state-derived path resolution with backward-compatible fallback

| Field | Value |
|---|---|
| Workstream | WS-M |
| Phase | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV2-88, EDMV2-90 |
| Depends On | EDMV2-T24 |
| Target Components | `bin/edm-state:71-74` (`state_file_for`) — resolve product-scoped path when `product_name`/`initiative_description` present, else legacy flat; add a parallel `initiative_dir_for()` resolver returning the directory (not just the state file) |

### Description
`state_file_for()` hardcodes the flat layout `SRD/{PREFIX}/.edm-state.json` (`bin/edm-state:73`). EDMV2-88 requires all path construction to derive the full initiative directory from state (`product_name` + `prefix` + `initiative_description`); EDMV2-90 requires existing flat initiatives to keep working unmodified. This is the central WS-M seam — concentrating the layout switch in one resolver (plus a directory variant) means most callers change one call site (SRD section 5.6 Risk 2 mitigation).

The bootstrap problem: `state_file_for` is also called before a state file exists (during `init`). The resolver must therefore first look for an existing flat state file (legacy), then an existing product-scoped directory, and otherwise compute the path from any product/description it is given (env or args) — defaulting to flat when none are known.

### Acceptance Criteria
- [ ] AC1: `state_file_for <PREFIX>` returns `SRD/{PRODUCT}/{PREFIX}__{DESC}/.edm-state.json` when a product-scoped directory for the prefix exists or product/description are resolvable.
- [ ] AC2: `state_file_for <PREFIX>` returns the legacy `SRD/{PREFIX}/.edm-state.json` when a flat state file already exists for the prefix (EDMV2-90 backward compatibility).
- [ ] AC3: A new `initiative_dir_for <PREFIX>` resolver returns the directory (without `/.edm-state.json`) for use by HANDOFF, archive, and artifact-path consumers.
- [ ] AC4: Resolution prefers an existing on-disk path over a computed one, so an in-flight initiative never has its path change underneath it.
- [ ] AC5: When neither layout exists yet (pre-init) and no product/description are supplied, the resolver returns the flat path (safe default, EDMV2-90).
- [ ] AC6: Product-scoped resolution finds the directory by globbing `SRD/{PRODUCT}/{PREFIX}__*` when description is unknown but product is, returning the single match or erroring on ambiguity.
- [ ] AC7: `EDM_SRD_ROOT` continues to pin the root for both layouts (SRD glossary).
- [ ] AC8: Every existing caller of `state_file_for` (read_state `:174`, write_state `:183`, cmd_init `:212`, get-coverage `:449`, metrics-report `:578`) resolves correctly under both layouts with no per-caller layout logic.
- [ ] AC9: A unit check resolves a crafted flat initiative and a crafted product-scoped initiative and asserts both return the correct `.edm-state.json` path.

### Technical Notes
Read `product_name`/`initiative_description` from the state file when it exists; for the pre-init case accept them via env vars (`EDM_PRODUCT`/`EDM_DESCRIPTION`) set by `edm-init` (EDMV2-T40). Glob safely with `nullglob`-equivalent guards so a non-match does not leave a literal pattern. This resolver is the single point of layout truth (SRD section 5.4) — do not scatter layout conditionals into callers. Keep it pure/read-only (no writes).

### Out of Scope
The HANDOFF path-var updates (EDMV2-T44). `edm-init`/`edm-validate-prefix` changes (EDMV2-T40/T41). `migrate-path` (EDMV2-T42).

### Verification
Bash unit check resolves both a flat and a product-scoped crafted initiative and asserts the returned state-file and directory paths (AC1/AC2/AC3/AC9); asserts the pre-init flat default (AC5). PASS when both layouts resolve correctly and the default is flat.

---

## EDMV2-T38: New canonical directory layout documented and adopted

| Field | Value |
|---|---|
| Workstream | WS-M |
| Phase | A |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV2-85 |
| Depends On | EDMV2-T37 |
| Target Components | `CLAUDE.md` (plugin) "Project artifact layout" section (the `SRD/{PREFIX}/` tree) and "Naming conventions"; `README.md` layout references |

### Description
EDMV2-85 establishes `SRD/{PRODUCT}/{PREFIX}__{DESCRIPTION}/` (double-underscore separator) as the canonical layout (e.g. `SRD/edm/EDMV2__enhance-edm-plugin/`). This ticket updates the plugin's own documentation so the canonical layout is stated authoritatively, while noting that flat initiatives remain supported (EDMV2-90).

This is documentation/adoption rather than code; the resolver code lives in EDMV2-T37. It is sequenced after T37 so the docs describe shipped behavior.

### Acceptance Criteria
- [ ] AC1: The `CLAUDE.md` "Project artifact layout" tree shows `SRD/{PRODUCT}/{PREFIX}__{DESCRIPTION}/` as canonical.
- [ ] AC2: The double-underscore separator and a concrete example (`SRD/edm/EDMV2__enhance-edm-plugin/`) are documented.
- [ ] AC3: The doc states that existing flat `SRD/{PREFIX}/` initiatives continue to work and migration is opt-in via `migrate-path` (EDMV2-89/90).
- [ ] AC4: The "Naming conventions" section references the new layout and the product directory's role in discoverability.
- [ ] AC5: Any `README.md` reference to the flat-only layout is updated to mention the product-scoped layout.
- [ ] AC6: All documentation is ASCII-only (C-1) and contains no AI-attribution content.
- [ ] AC7: The doc cross-references global prefix uniqueness (EDMV2-87) so readers understand PREFIX is unique across all products.

### Technical Notes
This change is in the staging copy's `CLAUDE.md`/`README.md`. Keep the legacy-layout description as an explicit "still supported" note rather than deleting it (C-4). Reference EDMV2-T42's `migrate-path` as the opt-in path. Mirror the target-layout tree from SRD section 5.2.6.

### Out of Scope
Code resolution (EDMV2-T37). The `migrate-path` helper (EDMV2-T42). Product-scoped uniqueness logic (EDMV2-T39).

### Verification
QC auditor confirms the canonical layout tree, the double-underscore example, the backward-compat note, and the uniqueness cross-reference are present and ASCII-only (AC1-AC7). Static doc PASS.

---

## EDMV2-T39: Global prefix uniqueness across all products

| Field | Value |
|---|---|
| Workstream | WS-M |
| Phase | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV2-87 |
| Depends On | EDMV2-T37 |
| Target Components | `bin/edm-validate-prefix:21-23` (collision check) — change from `SRD/{PREFIX}` to a GLOBAL scan across all `SRD/{PRODUCT}/{PREFIX}__*` and any flat `SRD/{PREFIX}`; archived check `:26` extended likewise |

### Description
EDMV2-87 requires prefix uniqueness GLOBALLY across all `SRD/{PRODUCT}/` subdirectories (not per-product), because PREFIX is the unique identifier in commit scopes, ticket IDs, `edm-state` commands, HANDOFF refs, and Jira scopes — two products sharing a PREFIX would make all of these ambiguous (SRD revision 1.0.5 resolved the WS-M/WS-G conflict in favor of global uniqueness).

The current collision check at `edm-validate-prefix:21` only tests the flat `SRD/{PREFIX}`. This ticket broadens it to scan every product subdirectory for `{PREFIX}__*` AND any legacy flat `SRD/{PREFIX}`, rejecting a prefix that exists anywhere.

### Acceptance Criteria
- [ ] AC1: The collision check scans all `SRD/*/` product directories for a `{PREFIX}__*` directory and rejects (exit 2) if found in any product.
- [ ] AC2: The check also rejects (exit 2) if a legacy flat `SRD/{PREFIX}` directory exists.
- [ ] AC3: A prefix unique across ALL product subdirectories and flat directories is accepted (exit 0).
- [ ] AC4: Creating `SRD/web/AUTH01__x/` is rejected when `SRD/edm/AUTH01__y/` already exists (the SRD's worked example).
- [ ] AC5: The archived-prefix NOTE (`:26-27`) is extended to scan archived product-scoped directories too, still as a non-fatal warning.
- [ ] AC6: The error message names the conflicting existing path so the user can see where the prefix is already used.
- [ ] AC7: The exit-code contract (0 valid / 1 invalid format / 2 collision) is preserved.
- [ ] AC8: The glob is guarded so an empty `SRD/` (no products yet) does not error or false-positive.
- [ ] AC9: A unit check sets up a multi-product `SRD/` and asserts cross-product collision is rejected while a globally-unique prefix is accepted.

### Technical Notes
Use a loop over `SRD/*/` plus a test for `SRD/{PREFIX}` flat, with `nullglob` guards. Match `{PREFIX}__*` exactly (the double-underscore boundary) so `AUTH01` does not falsely collide with `AUTH011__*`; anchor the prefix segment. Keep the format regex reconciliation (G12/EDMV2-18) OUT of this ticket — it is a separate Epic 1 (WS-A) item; this ticket only changes the collision scope.

### Out of Scope
The prefix-format regex fix (EDMV2-18, Epic 1). `edm-init`'s product-flag parsing (EDMV2-T40). Resolving the linkage fields that rely on global uniqueness (WS-G, later epic).

### Verification
Bash unit check builds `SRD/edm/AUTH01__y/` then asserts `edm-validate-prefix AUTH01` exits 2 naming the edm path (AC1/AC4/AC6); asserts a unique prefix exits 0 (AC3); asserts empty `SRD/` does not false-positive (AC8). PASS on cross-product rejection + unique acceptance.

---

## EDMV2-T40: edm-init accepts --product and --description and writes both to state

| Field | Value |
|---|---|
| Workstream | WS-M |
| Phase | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV2-86, EDMV2-91 |
| Depends On | EDMV2-T37, EDMV2-T39 |
| Target Components | `bin/edm-init:7-36` — parse `--product`/`--description` (or prompt), build `SRD/{PRODUCT}/{PREFIX}__{DESC}/`, `mkdir -p` the product dir, write `product_name`+`initiative_description` to state; `bin/edm-state cmd_init:218-230` init payload gains both fields |

### Description
EDMV2-86 requires `edm-init` to accept `--product <name>` and `--description <slug>` (or prompt interactively), create the product subdirectory if absent, and write `product_name` and `initiative_description` into state at init time. The current `edm-init` takes only `<PREFIX>` and builds a flat `DIR="${SRD_ROOT}/${PREFIX}"` (`bin/edm-init:14`).

This ticket adds flag parsing, the product-scoped directory build, and the state-field writes. It exports `EDM_PRODUCT`/`EDM_DESCRIPTION` so the EDMV2-T37 resolver computes the correct path during the `edm-state init` call. It also seeds the init payload (EDMV2-91 surfacing depends on the fields existing). It depends on T37 (resolver) and T39 (uniqueness now global).

### Acceptance Criteria
- [ ] AC1: `edm-init --product edm --description enhance-edm-plugin EDMV2` creates `SRD/edm/EDMV2__enhance-edm-plugin/`.
- [ ] AC2: The product subdirectory `SRD/{PRODUCT}/` is created with `mkdir -p` when absent.
- [ ] AC3: `.edm-state.json` for the new initiative contains `product_name` and `initiative_description` populated from the flags.
- [ ] AC4: Flags may appear in any order relative to the positional `<PREFIX>`; missing `--product`/`--description` triggers an interactive prompt (or a clear error in non-interactive context).
- [ ] AC5: The double-underscore directory name is built exactly as `{PREFIX}__{DESCRIPTION}`.
- [ ] AC6: When neither flag is provided and prompting is unavailable, `edm-init` falls back to the legacy flat layout (EDMV2-90) rather than failing — preserving v1.x single-arg behavior.
- [ ] AC7: `edm-state cmd_init` writes `product_name: ""` and `initiative_description: ""` as additive defaulted fields so legacy `init` calls remain valid (C-4).
- [ ] AC8: The directory-existence guard (`:15-17`) is updated to test the resolved product-scoped path, not the flat path.
- [ ] AC9: A unit check runs the full flagged invocation and asserts both the directory location and the two populated state fields.
- [ ] AC: A fixture `.edm-state.json` with none of the WS-M fields (`product_name`, `initiative_description`) present is read by all consumers without error; missing fields resolve to `""` defaults via `jq // ""` guards (verified in test).

### Technical Notes
Parse with a `while`/`case` flag loop, collecting the positional PREFIX last. Export `EDM_PRODUCT`/`EDM_DESCRIPTION` before calling `edm-state init` so EDMV2-T37 resolves the product path; then `edm-state set` the two fields (string-typed via EDMV2-T25). Keep `code-audit/` scaffold creation (`:19`) but under the new dir. Defer mode-aware scaffolding to EDMV2-T45.

### Out of Scope
Mode-aware scaffold (EDMV2-T45). The stale next-step message fix (that is EDMV2-19/Epic 1, though the message must reference a valid path here). Surfacing in metrics/handoff/list output (EDMV2-T43).

### Verification
Bash unit check runs `edm-init --product edm --description enhance-edm-plugin EDMV2` in a temp root and asserts `SRD/edm/EDMV2__enhance-edm-plugin/.edm-state.json` exists with both fields populated (AC1/AC3/AC9); runs single-arg `edm-init LEGACY` and asserts flat fallback (AC6). PASS on flagged + fallback paths.

---

## EDMV2-T41: edm-validate-prefix product-aware invocation from edm-init

| Field | Value |
|---|---|
| Workstream | WS-M |
| Phase | A |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV2-87, EDMV2-86 |
| Depends On | EDMV2-T39, EDMV2-T40 |
| Target Components | `bin/edm-init` (call `edm-validate-prefix` before scaffolding) + `bin/edm-validate-prefix` (consume the global scan from EDMV2-T39); orchestrator prefix-selection step references it |

### Description
EDMV2-86/87 require `edm-init` to validate the prefix (globally unique per EDMV2-T39) before creating the product-scoped directory. Currently `edm-init` does not call `edm-validate-prefix` at all — it only does an inline format regex (`bin/edm-init:12`) and a directory-existence test (`:15`). This ticket wires the global uniqueness check into `edm-init`'s pre-scaffold path so a colliding prefix is rejected before any directory is created.

### Acceptance Criteria
- [ ] AC1: `edm-init` calls `edm-validate-prefix <PREFIX>` before creating any directory.
- [ ] AC2: A non-zero exit from `edm-validate-prefix` (format error 1 or collision 2) aborts `edm-init` with the validator's message surfaced.
- [ ] AC3: The validator's global scan (EDMV2-T39) is what gates init, so a cross-product collision blocks creation.
- [ ] AC4: When the validator exits 0, `edm-init` proceeds to scaffold under the product-scoped directory.
- [ ] AC5: The archived-prefix NOTE (warning) does not abort init (non-fatal).
- [ ] AC6: `edm-init`'s own inline directory-existence guard remains as a secondary safety net but the validator is the primary collision gate.
- [ ] AC7: A unit check attempts `edm-init` with a globally-colliding prefix and asserts init aborts with a non-zero exit and no directory created.

### Technical Notes
Call the validator by bare name (it is on PATH alongside `edm-init`). Capture and surface its stderr. Order: validate -> mkdir product dir -> `edm-state init`. Do not duplicate the global scan logic in `edm-init`; delegate to the validator (single source of truth). The orchestrator's prefix-selection step should likewise call the validator (prompt-level reference).

### Out of Scope
The global-scan implementation (EDMV2-T39). Format-regex reconciliation (Epic 1/EDMV2-18). Directory creation mechanics (EDMV2-T40).

### Verification
Bash unit check: with `SRD/edm/AUTH01__y/` present, `edm-init --product web --description x AUTH01` aborts non-zero and creates no `SRD/web/AUTH01__*` directory (AC2/AC3/AC7); a unique prefix proceeds (AC4). PASS on collision-abort + unique-proceed.

---

## EDMV2-T42: migrate-path helper for opt-in relocation

| Field | Value |
|---|---|
| Workstream | WS-M |
| Phase | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV2-89 |
| Depends On | EDMV2-T37, EDMV2-T40 |
| Target Components | `bin/edm-state` — new `cmd_migrate_path()` + dispatch entry near `:793`; uses `git mv` when tracked (shares EDMV2-T30 logic); updates `product_name`/`initiative_description` in state |

### Description
EDMV2-89 requires `bin/edm-state migrate-path --product <name> --description <slug> <PREFIX>` as an opt-in helper that relocates an existing flat initiative into the new layout and updates state. This lets teams adopt the product-scoped layout per-initiative rather than a flag day (SRD section 5.6 Risk 2 mitigation, EDMV2-90).

The helper resolves the current (flat) directory, computes the target product-scoped path, moves the directory (git-aware when tracked), then sets `product_name`/`initiative_description` so future `state_file_for` calls resolve the new path.

### Acceptance Criteria
- [ ] AC1: `edm-state migrate-path --product edm --description enhance-edm-plugin EDMV2` moves `SRD/EDMV2/` to `SRD/edm/EDMV2__enhance-edm-plugin/`.
- [ ] AC2: After migration, `product_name` and `initiative_description` are set in the relocated `.edm-state.json`.
- [ ] AC3: When the initiative directory is git-tracked the move uses `git mv` (staged rename), else plain `mv` (shares EDMV2-T30 git-aware logic).
- [ ] AC4: The helper validates that the target product-scoped path does not already exist (no clobber) and that the prefix remains globally unique post-move (EDMV2-T39).
- [ ] AC5: It errors cleanly if the source flat directory does not exist.
- [ ] AC6: Flag parsing accepts `--product`/`--description` in any order with the positional `<PREFIX>` last.
- [ ] AC7: The state-field writes go through the typed/locked write path (EDMV2-T24/T25).
- [ ] AC8: After migration, `edm-state get <PREFIX>` and `write-handoff <PREFIX>` resolve the new path via EDMV2-T37 with no further flags.
- [ ] AC9: A unit check migrates a crafted flat initiative and asserts the new location, the staged rename (in a temp git repo), and the two populated fields.

### Technical Notes
Resolve the source via the flat branch of `state_file_for`; compute the target via the product-scoped branch. `mkdir -p SRD/{PRODUCT}` then `git mv` the whole initiative directory. Update state AFTER the move so the field write lands in the relocated file. Refuse if the move would overwrite an existing target. This is opt-in only — never invoked automatically.

### Out of Scope
Automatic/bulk migration of all initiatives. The resolver itself (EDMV2-T37). Archiving (EDMV2-T30).

### Verification
Bash unit check in a temp git repo migrates `SRD/EDMV2/` and asserts `SRD/edm/EDMV2__enhance-edm-plugin/` exists, `git status` shows a staged rename, and both fields are set (AC1/AC2/AC3/AC9); asserts a missing source errors (AC5). PASS on relocation + staged rename + field updates.

---

## EDMV2-T43: Surface product_name and initiative_description in list, metrics, and handoff

| Field | Value |
|---|---|
| Workstream | WS-M |
| Phase | A |
| Priority | Should Have |
| Size | S |
| SRD Refs | EDMV2-91 |
| Depends On | EDMV2-T40 |
| Target Components | `bin/edm-state:234-248` (`cmd_list`), `:518-623` (`cmd_metrics_report`), `:631-766` (`write_handoff_internal`) — render `product_name`/`initiative_description` where present |

### Description
EDMV2-91 requires `metrics-report`, `write-handoff`, and `list` to surface `product_name` and `initiative_description`. The current `cmd_list` glob (`:237`) only iterates `SRD/*/.edm-state.json` and prints prefix/phase/gates; it must also discover product-scoped initiatives and show the product/description. Metrics and HANDOFF likewise show the fields when present.

### Acceptance Criteria
- [ ] AC1: `edm-state list` discovers both flat `SRD/{PREFIX}/.edm-state.json` and product-scoped `SRD/{PRODUCT}/{PREFIX}__*/.edm-state.json` initiatives.
- [ ] AC2: `list` output shows `product_name` and `initiative_description` columns when the fields are non-empty.
- [ ] AC3: `metrics-report <PREFIX>` includes a line showing the product and description when present.
- [ ] AC4: `write_handoff_internal` renders the product/description in the `## Current Status` block (or header) when present.
- [ ] AC5: When the fields are empty (legacy/flat initiative), output is unchanged from v1.x (no empty columns clutter).
- [ ] AC6: All added output is ASCII-only (C-1).
- [ ] AC7: The `list` glob change does not double-count an initiative that is only in one layout.
- [ ] AC8: A unit check with one flat and one product-scoped initiative asserts `list` shows both and renders the product fields for the scoped one.

### Technical Notes
Extend the `cmd_list` glob to also iterate `SRD/*/*/.edm-state.json` (two levels) while de-duplicating. Guard rendering behind a non-empty check so legacy output is untouched (AC5). Reuse the `jq -r` extraction pattern already in `cmd_list:241-244`. Keep column widths sane; ASCII only.

### Out of Scope
The directory resolver (EDMV2-T37). The Resume Point section (EDMV2-T48). Active-initiative filtering (that is EDMV2-T35's `active-initiatives`).

### Verification
Bash unit check creates one flat and one product-scoped initiative; asserts `list` enumerates both without duplication and shows product/description for the scoped one (AC1/AC2/AC7/AC8); asserts the flat one's output is unchanged (AC5). PASS on dual-layout enumeration + conditional field rendering.

---

## EDMV2-T44: Route HANDOFF artifact paths through the directory resolver

| Field | Value |
|---|---|
| Workstream | WS-M |
| Phase | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV2-88 |
| Depends On | EDMV2-T37 |
| Target Components | `bin/edm-state:704-708` (planning/srd/audit/tickets path vars), `:726` (handoff path), `:751-755` (rendered checklist paths), `:333,336` (phase-complete artifact-hash paths), `:492-493` (archive paths) — replace literal `${SRD_ROOT}/${prefix}` with `initiative_dir_for` |

### Description
EDMV2-88 requires every path-constructing component to derive the initiative directory from state, not assume flat `SRD/{PREFIX}`. Beyond the resolver itself (EDMV2-T37), several hardcoded `${SRD_ROOT}/${prefix}` literals remain: the HANDOFF artifact-presence path vars (`:704-708`), the rendered checklist paths (`:751-755`), the handoff output path (`:726`), the phase-complete artifact-hash paths (`:333,336`), and the archive src/dst (`:492-493`, also touched by EDMV2-T30). This ticket replaces those literals with `initiative_dir_for` so artifacts are written/read in the correct directory under both layouts (SRD section 5.6 Risk 2 — a missed reference writes to the wrong directory).

### Acceptance Criteria
- [ ] AC1: All HANDOFF artifact-presence path vars (`planning_path`, `srd_path`, `audit_srd_path`, `tickets_path`, `audit_tickets_path` at `:704-708`) derive from `initiative_dir_for`.
- [ ] AC2: The rendered checklist table paths (`:751-755`) show the resolved directory (product-scoped form when applicable), not a hardcoded flat path.
- [ ] AC3: The HANDOFF output path (`handoff_path`, `:726`) derives from `initiative_dir_for`.
- [ ] AC4: The phase-complete artifact-hash paths (`srd_path :333`, `tickets_path :336`) derive from `initiative_dir_for`.
- [ ] AC5: A `grep` for literal `SRD/${prefix}` / `${SRD_ROOT}/${prefix}` across the staging `bin/edm-state` returns no remaining artifact-path construction sites (audit step per SRD Risk 2).
- [ ] AC6: A product-scoped initiative's HANDOFF.md is written inside its product-scoped directory and its checklist shows product-scoped paths.
- [ ] AC7: A flat initiative's HANDOFF behavior is unchanged (paths resolve to the flat directory).
- [ ] AC8: A unit check generates HANDOFF for both a flat and a product-scoped initiative and asserts each lands in the correct directory with correct rendered paths.

### Technical Notes
Introduce a single `dir="$(initiative_dir_for "$prefix")"` at the top of `write_handoff_internal` and `cmd_phase_complete`, then derive all sub-paths from `$dir`. The archive paths (`:492-493`) are primarily owned by EDMV2-T30; coordinate so both tickets use `initiative_dir_for` consistently. Run the grep audit (AC5) as the completion check for Risk 2.

### Out of Scope
The resolver implementation (EDMV2-T37). Skill/agent prose path references (those are separate per-skill changes tracked under their owning workstreams). The Resume Point section content (EDMV2-T48).

### Verification
Bash unit check writes HANDOFF for a flat and a product-scoped initiative; asserts each `HANDOFF.md` is created in the correct directory and the checklist paths match the layout (AC6/AC7/AC8); runs the literal-path grep and asserts no artifact-path construction sites remain (AC5). PASS when both layouts render correctly and the grep is clean.

---

## EDMV2-T45: Mode-aware scaffold and corrected next-step message in edm-init

| Field | Value |
|---|---|
| Workstream | WS-M |
| Phase | A |
| Priority | Should Have |
| Size | S |
| SRD Refs | EDMV2-51, EDMV2-19 |
| Depends On | EDMV2-T40 |
| Target Components | `bin/edm-init:19,29-36` — scaffold subdirs per selected `mode`; fix the next-step message at `:35` to reference the current orchestrator entry point and product-scoped path |

### Description
EDMV2-51 requires `edm-init` to scaffold the directory according to the selected mode (e.g. mini-SRD omits a separate `tickets/`). EDMV2-19 (G13) requires the stale next-step message at `bin/edm-init:35` ("run /edm:plan ...") to match the actual current orchestrator entry point and the new directory layout. Both are small `edm-init` changes grouped here because they touch the same scaffold/message tail of the script.

Note: the full mode state machinery (EDMV2-44/55 `set-mode`) is owned by WS-E/F in a later epic; this ticket only consumes a `--mode` value (or default `standard`) to decide which subdirectories to create.

### Acceptance Criteria
- [ ] AC1: `edm-init` accepts an optional `--mode <profile>` (default `standard`) and scaffolds accordingly.
- [ ] AC2: `standard` mode scaffolds the current shape (including `code-audit/`).
- [ ] AC3: `mini-srd` mode does NOT scaffold a separate `tickets/` directory (SRD section 4.5/9.2).
- [ ] AC4: `prototype` mode scaffolds only Phase 1-2 slots (no `tickets/`, no `code-audit/`), consistent with the truncated lifecycle.
- [ ] AC5: The next-step message references the current orchestrator entry point (`/edm:orchestrator <PREFIX>`) and the resolved product-scoped path, not the stale `/edm:plan <PREFIX> <description>` text.
- [ ] AC6: The printed scaffold tree in the message reflects what was actually created for the selected mode.
- [ ] AC7: The message and all scaffold output are ASCII-only (C-1).
- [ ] AC8: A unit check runs `edm-init` in `standard`, `mini-srd`, and `prototype` modes and asserts the created subdirectories differ as specified.

### Technical Notes
Map mode to a subdir set in a `case`. Default to `standard` when `--mode` is absent so v1.x behavior is preserved. The next-step message should state the resolved directory (from EDMV2-T37) and the orchestrator command; drop the old `/edm:plan PREFIX description` instruction. Keep the message free of Unicode box-drawing if it would emit non-ASCII (use ASCII tree characters).

### Out of Scope
The `set-mode` subcommand and full mode branching (WS-E/F, later epic). Writing `mode` to state (that is WS-E's `cmd_init`/`set-mode` work; this ticket only reads `--mode` for scaffolding).

### Verification
Bash unit check runs all three modes and asserts the subdirectory differences (no `tickets/` for mini-srd; no `tickets/`+`code-audit/` for prototype) (AC2-AC4/AC8); inspects the printed message for the orchestrator entry point and resolved path, asserting the stale `/edm:plan` text is gone (AC5). PASS on per-mode scaffold differences + corrected message.

---

## WS-N — Compaction Resilience (EDMV2-T46 through EDMV2-T54)

## EDMV2-T46: current_step state field (lazy, null-default)

| Field | Value |
|---|---|
| Workstream | WS-N |
| Phase | A |
| Priority | Must Have |
| Size | XS |
| SRD Refs | EDMV2-92 |
| Depends On | EDMV2-T24 |
| Target Components | `bin/edm-state` — read paths use `// null` fallback for `current_step`; explicitly NOT added to `cmd_init` payload (`:218-230`) per the lazy rule (SRD section 6.1, F-C-06) |

### Description
EDMV2-92 requires an optional `current_step` field updated at each step boundary, with a null default and SAFE absence. Critically (SRD section 6.1 / 5.4), `current_step` is LAZY: it is NOT pre-initialized to `null` in the `edm-state init` payload — it is created on first write (EDMV2-T47) and every reader must use a `// null` fallback. This ticket establishes the read contract and confirms the field is absent from init.

### Acceptance Criteria
- [ ] AC1: `current_step` is NOT present in the `cmd_init` JSON payload (`:218-230`) — confirmed by asserting a freshly-initialized state file has no `current_step` key.
- [ ] AC2: Every reader of `current_step` uses a `// null` (or equivalent) jq fallback so absence never errors.
- [ ] AC3: A state file with no `current_step` resolves to a safe null/empty value wherever it is read.
- [ ] AC4: A state file with `current_step` set reads back the stored value (string or number, per schema).
- [ ] AC5: No existing v1.x reader is broken by the field's absence (C-4).
- [ ] AC6: The field's lazy semantics are documented in a comment near the read site.
- [ ] AC7: A unit check asserts both the absence-in-init and the safe-fallback-on-read behaviors.

### Technical Notes
This is deliberately minimal — the write path is EDMV2-T47. The point of the ticket is to lock in the lazy contract (no init pre-init; `// null` everywhere) so later WS-N readers (Resume Point, SessionStart) are correct. Mirror the existing defaulted-read pattern (`// 0`, `// {}`) used at `:305`, `:642`, `:657`.

### Out of Scope
The `current-step` write subcommand (EDMV2-T47). Resume Point rendering (EDMV2-T48). SessionStart injection (EDMV2-T50).

### Verification
Bash unit check: `edm-state init TEST` then assert `jq 'has("current_step")'` is `false` (AC1); read `current_step` from a no-field file and assert no error + null/empty (AC3). PASS on absence + safe read.

---

## EDMV2-T47: current-step subcommand (write + read)

| Field | Value |
|---|---|
| Workstream | WS-N |
| Phase | A |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV2-93 |
| Depends On | EDMV2-T46 |
| Target Components | `bin/edm-state` — new `cmd_current_step()` + dispatch entry near `:793`; help block `:2-21`; write goes through `write_state` (lock from EDMV2-T24) |

### Description
EDMV2-93 requires a `current-step <PREFIX> <step>` subcommand (and a read path) so the orchestrator can record and read the step within a phase. This is the lazy field's write path (it creates `current_step` on first call). It also provides a read form so the orchestrator and HANDOFF can fetch the current step.

### Acceptance Criteria
- [ ] AC1: `edm-state current-step <PREFIX> <step>` sets `current_step` to the given value and refreshes `.last_updated`.
- [ ] AC2: `edm-state current-step <PREFIX>` (no value) reads and prints the current step (or empty/null when unset).
- [ ] AC3: The first `current-step` write creates the field (lazy), consistent with EDMV2-T46.
- [ ] AC4: The write goes through `write_state` and therefore acquires the EDMV2-T24 lock.
- [ ] AC5: The subcommand is wired into the dispatch `case` block and the help/usage comment block.
- [ ] AC6: Setting and reading the step round-trips (set then get returns the same value).
- [ ] AC7: A numeric step and a string step (e.g. `2.3` or `spawn-architect`) both round-trip per the schema's `string|number` type.
- [ ] AC8: Wrong argument count dies with a usage message.
- [ ] AC9: A unit check round-trips a set then a get and asserts equality.

### Technical Notes
Accept value as a string by default; if it is purely numeric, store as a number (reuse EDMV2-T25's number-shape check) so `current_step` matches the `string|number` schema. The read form (no value arg) prints `.current_step // ""`. Trigger a HANDOFF refresh on write so the Resume Point (EDMV2-T48) stays current — but only if cheap; otherwise leave HANDOFF refresh to the orchestrator's explicit `write-handoff`.

### Out of Scope
Resume Point rendering (EDMV2-T48). last_cmd/last_decision (EDMV2-T52). PreCompact wiring (EDMV2-T54).

### Verification
Bash unit check sets then gets `current_step` and asserts round-trip equality for both a numeric and a string value (AC6/AC7/AC9); asserts the field was created lazily on first write (AC3). PASS on round-trip + lazy creation.

---

## EDMV2-T48: Resume Point section in HANDOFF, populated from state

| Field | Value |
|---|---|
| Workstream | WS-N |
| Phase | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV2-94, EDMV2-95 |
| Depends On | EDMV2-T28, EDMV2-T44, EDMV2-T47 |
| Target Components | `bin/edm-state:737-765` (`write_handoff_internal` output block) — add a `## Resume Point` section rendered from `current_phase`, `current_step`, `last_cmd`, `last_decision`, pending-artifact list |

### Description
EDMV2-94 requires `write-handoff` to write a `## Resume Point` section containing: current phase + step number, the last bash command run (exact args), the last decision recorded, any pending agents, and a copy-paste-ready literal next action. EDMV2-95 requires this content to be DERIVED from state fields (`current_phase`, `current_step`, `last_cmd`, `last_decision`, pending artifact list), never hand-written.

This ticket adds the section to `write_handoff_internal`'s output block. It depends on EDMV2-T44 (HANDOFF paths via resolver) and EDMV2-T47 (`current_step` available); `last_cmd`/`last_decision` come from EDMV2-T52 but the section must render gracefully when they are empty.

### Acceptance Criteria
- [ ] AC1: `write-handoff` emits a `## Resume Point` section in HANDOFF.md.
- [ ] AC2: The section shows the current phase AND step (from `current_phase` + `current_step // ""`).
- [ ] AC3: The section shows the last bash command with exact args (from `last_cmd`, empty-safe).
- [ ] AC4: The section shows the last decision (from `last_decision`, empty-safe).
- [ ] AC5: The section lists any pending agents / pending artifacts derived from state and the artifact-presence checklist.
- [ ] AC6: The section ends with a copy-paste-ready literal next action (e.g. the exact `/edm:orchestrator <PREFIX>` or the next step instruction).
- [ ] AC7: All fields are derived from state — changing `current_step` in state and re-running `write-handoff` changes the Resume Point (EDMV2-95).
- [ ] AC8: The section is ASCII-only (C-1) and free of AI-attribution content.
- [ ] AC9: When all WS-N fields are empty/absent (legacy initiative), the section still renders without errors using safe defaults.
- [ ] AC10: A unit check sets `current_step`, re-runs `write-handoff`, and asserts the Resume Point reflects the new step.

### Technical Notes
Render the section near the top of the output block (after `## Current Status`) so it is prominent; SessionStart (EDMV2-T50) will extract it. Use the existing `printf` style in `write_handoff_internal:737-765`. Derive "pending artifacts" from the same artifact-presence checks already computed (`s_planning`/`s_srd`/... at `:710-715`). Keep every value behind a `// ""`/`// null` default so a legacy file renders cleanly (AC9). Mirror the SRD section 5.3.A example ("Phase 2, Step 3: spawn edm-architect ...").

### Out of Scope
Capturing `last_cmd`/`last_decision` (EDMV2-T52). SessionStart extraction/injection (EDMV2-T50). The orchestrator resume jump (EDMV2-T51).

### Verification
Bash unit check sets `current_step` then `write-handoff` and asserts a `## Resume Point` section exists containing the phase+step, an empty-safe last-command line, and a copy-paste next action (AC1-AC6); changes `current_step` and asserts the section updates (AC7/AC10); runs on a legacy file and asserts clean render (AC9). PASS on derived-content + update-on-change.

---

### Reserved: EDMV2-T49

> Note: Resume Point freshness on phase/step change is delivered jointly by EDMV2-T48 (renders from state) and EDMV2-T28 (HANDOFF regenerated on phase change). No separate ticket is allocated; numbering continues at T50 to preserve block ordering. This heading is omitted from the index.

---

## EDMV2-T50: SessionStart injects Resume Point for active initiatives

| Field | Value |
|---|---|
| Workstream | WS-N |
| Phase | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV2-96 |
| Depends On | EDMV2-T48 |
| Target Components | `hooks/hooks.json:3-12` (`SessionStart`) — emit the `## Resume Point` block first when an active initiative is detected; new `bin/edm-state session-start` (or `resume-point <PREFIX>`) helper that prints the block then the list |

### Description
EDMV2-96 requires the `SessionStart` hook, when an active initiative is detected (directory exists AND NOT under `.archived/` AND `current_phase` in 1-6), to inject the `## Resume Point` block verbatim at the TOP of the injected payload, before the broader initiative list. Today `SessionStart` just runs `edm-state list` (`hooks.json:8`).

This ticket adds a helper that detects the active initiative, extracts its Resume Point block from HANDOFF.md (written by EDMV2-T48), prints it first, then prints the list. The hook command is updated to call the helper.

### Acceptance Criteria
- [ ] AC1: A helper (e.g. `edm-state session-start`) detects an active initiative using the exact definition: directory exists, NOT under `.archived/`, `current_phase` in 1-6 (SRD section 6.1).
- [ ] AC2: When an active initiative is found, the helper prints its `## Resume Point` block FIRST, before the initiative list.
- [ ] AC3: When no active initiative is found, the helper prints only the `edm-state list` output (current v1.x behavior).
- [ ] AC4: The Resume Point block is emitted verbatim from the active initiative's HANDOFF.md (the section authored by EDMV2-T48).
- [ ] AC5: The `SessionStart` hook command in `hooks.json` calls the helper, guarded by `command -v edm-state ... || true` (best-effort, never breaks the session).
- [ ] AC6: When multiple active initiatives exist, the helper emits the Resume Point for the most-recently-updated one first (or all, deterministically ordered) and still lists all.
- [ ] AC7: Output is ASCII-only (C-1).
- [ ] AC8: A unit check with one active initiative asserts the Resume Point precedes the list in stdout; with no active initiative asserts list-only output.

### Technical Notes
Reuse the active-initiative filter from EDMV2-T35's `active-initiatives` if available, or replicate the `current_phase in 1..6 && not .archived` test. Extract the `## Resume Point` block from HANDOFF.md with the same awk section-extraction pattern used for Notes/Decisions (`:720`, `:729`). The hook stdout becomes injected context (SRD section 5.5), so ordering in stdout = ordering in the payload. Keep the `|| true` guard so a missing binary or absent HANDOFF never aborts session start.

### Out of Scope
Authoring the Resume Point block (EDMV2-T48). The orchestrator's resume jump (EDMV2-T51). PreCompact freshness (EDMV2-T54).

### Verification
Bash unit check runs the helper with one crafted active initiative (HANDOFF containing a Resume Point) and asserts the Resume Point text appears before the list in stdout (AC2/AC4/AC8); runs with no active initiative and asserts list-only (AC3); confirms the `hooks.json` SessionStart command calls the helper with the `|| true` guard (AC5). PASS on ordering + no-active fallback.

---

## EDMV2-T51: Orchestrator resume branch reads current_step

| Field | Value |
|---|---|
| Workstream | WS-N |
| Phase | A |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV2-97 |
| Depends On | EDMV2-T47 |
| Target Components | `skills/orchestrator/SKILL.md` resume/Step-1 branch — read `current_phase` AND `current_step` from `edm-state get`, jump to that step rather than restarting Phase 1 |

### Description
EDMV2-97 requires the orchestrator's resume branch to read `current_step` from state and jump to the correct step rather than restarting Phase 1. Per SRD section 5.3.A, resuming an initiative at Phase 2 Step 3 must continue from that step. Today the orchestrator resumes by `current_phase` only.

This is a prompt-logic change: the resume branch additionally reads `current_step` (via `edm-state current-step <PREFIX>` or `edm-state get`) and routes to the matching step within the phase.

### Acceptance Criteria
- [ ] AC1: The orchestrator's resume branch reads both `current_phase` and `current_step` from state on entry.
- [ ] AC2: When `current_step` is set, the orchestrator jumps to that step within `current_phase` rather than restarting the phase or Phase 1.
- [ ] AC3: When `current_step` is null/absent (legacy/first run), the orchestrator falls back to the current phase's start (v1.x behavior).
- [ ] AC4: The resume logic is consistent with the Resume Point block authored in HANDOFF (EDMV2-T48) and injected at SessionStart (EDMV2-T50).
- [ ] AC5: The orchestrator records/updates `current_step` (via EDMV2-T47) as it advances through steps, so a subsequent resume is accurate.
- [ ] AC6: The prompt instructions are explicit and unambiguous about the read-and-jump behavior (no reliance on inference).
- [ ] AC7: The behavior degrades safely for product-scoped and flat initiatives alike (resolved via state).

### Technical Notes
Because orchestration is an LLM-read prompt, "jump to step" means the prompt instructs: "read `current_step`; if set, resume at that documented step number; else start the phase." Pair with EDMV2-T47 writes at each step boundary so the field is meaningful. Cross-reference the Resume Point literal next action so the orchestrator and HANDOFF agree.

### Out of Scope
The `current-step` subcommand (EDMV2-T47). last_cmd/last_decision capture (EDMV2-T52). SessionStart injection (EDMV2-T50).

### Verification
QC auditor inspects the orchestrator resume branch and confirms it reads `current_step` and documents the jump-to-step behavior with a safe fallback (AC1/AC2/AC3). Static PASS; an interactive sandbox resuming an initiative with `current_step` set and confirming continuation from that step is the runtime confirmation (PARTIAL/deferred-to-runtime if no interactive sandbox).

---

## EDMV2-T52: Capture last_cmd and last_decision at step boundaries

| Field | Value |
|---|---|
| Workstream | WS-N |
| Phase | A |
| Priority | Should Have |
| Size | S |
| SRD Refs | EDMV2-98 |
| Depends On | EDMV2-T47, EDMV2-T48 |
| Target Components | `skills/orchestrator/SKILL.md` (record `last_cmd`/`last_decision` via `edm-state set` at step boundaries); `bin/edm-state cmd_init` defaults (`:218-230`) gain `last_cmd: ""`, `last_decision: ""` |

### Description
EDMV2-98 requires the orchestrator to record `last_cmd` and `last_decision` into state at step boundaries so the Resume Point is accurate after compaction. These two string fields feed the Resume Point section (EDMV2-T48). The orchestrator sets them as it executes; the fields are added (defaulted empty) to the init payload.

### Acceptance Criteria
- [ ] AC1: `cmd_init` writes `last_cmd: ""` and `last_decision: ""` as additive defaulted fields (C-4).
- [ ] AC2: The orchestrator records `last_cmd` (the exact last bash command + args it ran) at each step boundary via `edm-state set <PREFIX> last_cmd "<cmd>"`.
- [ ] AC3: The orchestrator records `last_decision` (the last decision made) at each step boundary.
- [ ] AC4: After a step, `jq .last_cmd` and `jq .last_decision` hold the expected values, and HANDOFF's Resume Point (EDMV2-T48) reflects them.
- [ ] AC5: The fields render empty-safe in the Resume Point when not yet set (legacy initiative).
- [ ] AC6: Writes go through the locked/typed write path (string-typed, EDMV2-T24/T25).
- [ ] AC7: A unit check sets both fields and asserts they appear in the rendered Resume Point.
- [ ] AC: A fixture `.edm-state.json` with none of the WS-N fields (`last_cmd`, `last_decision`) present is read by all consumers without error; missing fields resolve to `""` defaults via `jq // ""` guards (verified in test).

### Technical Notes
Keep these as plain strings (EDMV2-T25 default string path). The orchestrator instruction: "at each step boundary, `edm-state set <PREFIX> last_cmd \"...\"` and `last_decision \"...\"`, then `current-step`." Since these are Should priority, ensure the Resume Point (Must) renders correctly even if the orchestrator omits a particular update (empty-safe, AC5).

### Out of Scope
The Resume Point rendering itself (EDMV2-T48). `current_step` (EDMV2-T47). PreCompact freshness (EDMV2-T54).

### Verification
Bash unit check sets `last_cmd`/`last_decision` then runs `write-handoff` and asserts both appear in the Resume Point (AC4/AC7); asserts init writes the two empty defaults (AC1); asserts empty-safe rendering when unset (AC5). PASS on field capture + Resume Point reflection.

---

## EDMV2-T53: PreCompact captures current_step and Resume Point freshness

| Field | Value |
|---|---|
| Workstream | WS-N |
| Phase | A |
| Priority | Should Have |
| Size | S |
| SRD Refs | EDMV2-99 |
| Depends On | EDMV2-T48, EDMV2-T47 |
| Target Components | `hooks/hooks.json:34-43` (`PreCompact`) — ensure `current_step`/Resume Point are written before compaction; `bin/edm-state cmd_checkpoint:343-401` extended to refresh Resume Point |

### Description
EDMV2-99 requires the `PreCompact` hook to ensure `current_step` and the Resume Point are written before compaction occurs, so position survives the compaction. Today `PreCompact` calls `checkpoint-if-active` (`hooks.json:38-39`), which touches `last_updated` and re-renders HANDOFF — but the Resume Point section is new (EDMV2-T48), so this ticket confirms `checkpoint-if-active` refreshes it and the hook fires it before compaction.

### Acceptance Criteria
- [ ] AC1: The `PreCompact` hook continues to call `checkpoint-if-active` (or an equivalent that refreshes the Resume Point) before compaction.
- [ ] AC2: `cmd_checkpoint` (`:343-401`) re-renders HANDOFF via `write_handoff_internal` (it already calls it at `:399`), thereby refreshing the Resume Point section (EDMV2-T48).
- [ ] AC3: After a simulated `PreCompact` invocation, the active initiative's HANDOFF Resume Point reflects the latest `current_step`/`last_cmd`/`last_decision` in state.
- [ ] AC4: The hook remains best-effort guarded (`|| true`) so compaction is never blocked by an `edm-state` failure.
- [ ] AC5: No new state mutation beyond `last_updated` + HANDOFF refresh occurs (checkpoint stays non-destructive, SRD section 6.2).
- [ ] AC6: The Stop hook (`:24-32`) behavior is unchanged (it shares `checkpoint-if-active`).
- [ ] AC7: A unit check sets `current_step`, invokes `checkpoint-if-active`, and asserts the HANDOFF Resume Point reflects the step.

### Technical Notes
Most of the wiring already exists (`PreCompact` -> `checkpoint-if-active` -> `write_handoff_internal`). The real work is confirming the Resume Point (added by EDMV2-T48) is part of what `write_handoff_internal` regenerates, so it is fresh at PreCompact time. No hook structure change is strictly required beyond verifying the chain; keep the `|| true` guard.

### Out of Scope
Resume Point authoring (EDMV2-T48). `current_step` write subcommand (EDMV2-T47). SessionStart injection (EDMV2-T50).

### Verification
Bash unit check sets `current_step`, runs `edm-state checkpoint-if-active`, and asserts the active initiative's HANDOFF Resume Point shows the step (AC2/AC3/AC7); confirms the `PreCompact` hook retains the `|| true` guard (AC4). PASS on Resume-Point-refresh-at-checkpoint.

---

## EDMV2-T54: WS-N integration smoke check (compaction recovery end-to-end)

| Field | Value |
|---|---|
| Workstream | WS-N |
| Phase | A |
| Priority | Should Have |
| Size | S |
| SRD Refs | EDMV2-92, EDMV2-93, EDMV2-94, EDMV2-95, EDMV2-96, EDMV2-97 |
| Depends On | EDMV2-T47, EDMV2-T48, EDMV2-T50, EDMV2-T51 |
| Target Components | new bash unit check under the plugin's verification notes (C-2) exercising current-step -> write-handoff -> session-start -> resume; no production code change |

### Description
WS-N spans state field, subcommand, HANDOFF section, two hooks, and an orchestrator branch. SRD section 5.3.A defines the full compaction-recovery sequence. This ticket adds an end-to-end smoke check that wires the WS-N pieces together so a regression in any single piece is caught — the verification mechanism the SRD mandates in lieu of CI (C-2).

This is a verification ticket (no new production behavior); it exists so the WS-N feature is provably coherent end-to-end, mirroring the EDMV2-02 regression-check pattern for WS-A's G1.

### Acceptance Criteria
- [ ] AC1: A documented bash check initializes a crafted active initiative, sets `current_step` (EDMV2-T47), and runs `write-handoff`.
- [ ] AC2: The check asserts HANDOFF contains a `## Resume Point` with the set step (EDMV2-T48/94/95).
- [ ] AC3: The check runs the SessionStart helper (EDMV2-T50) and asserts the Resume Point is emitted before the list (EDMV2-96).
- [ ] AC4: The check asserts the orchestrator resume contract reads `current_step` (static assertion against the skill text, EDMV2-T51/97).
- [ ] AC5: The check is recorded in the plugin's verification notes so it can be re-run (per C-2 / EDMV2-101 verification posture).
- [ ] AC6: Removing any single WS-N piece (e.g. reverting the Resume Point section) causes the check to fail (regression sensitivity).
- [ ] AC7: The check is ASCII-only and introduces no new dependency beyond `jq`/bash.

### Technical Notes
Compose the check from the per-ticket unit checks rather than duplicating them — it is the integration glue. Assert ordering in the SessionStart stdout (Resume Point precedes list). For the orchestrator (prompt) piece, a `grep` for the `current_step` read in the skill text is the static assertion (AC4). Store under a `tests/`-style notes location consistent with the staging copy's verification approach.

### Out of Scope
Any production code (all owned by EDMV2-T46..T53). Interactive end-to-end compaction in a live session (deferred-to-runtime; this is a scripted smoke check).

### Verification
QC auditor runs the smoke check and confirms it passes with all WS-N pieces present (AC1-AC5) and fails when the Resume Point section is reverted (AC6). PASS when the check passes intact and fails on regression.

---

## Epic 2 dependency note

WS-J lands first (T24-T36): T24 (locking) and T25 (typed-set) are the substrate; T33 (read coercion), T29/T32 (anomaly/validate), T26/T27 (gate fixes), T28 (phase/HANDOFF consistency), T30 (git-aware archive), and the branch/lock trio T34/T35/T36 build on them. WS-M follows (T37-T45): T37 (resolver) is the single layout seam that T38-T45 consume; T44 routes HANDOFF paths through it; T39-T41 cover global uniqueness and product-aware init; T42 (migrate-path) and T45 (mode-aware scaffold + message fix) round it out. WS-N lands last in this epic (T46-T54): the lazy `current_step` field (T46/T47) feeds the Resume Point (T48), which feeds SessionStart injection (T50) and the orchestrator resume branch (T51); T52 (last_cmd/last_decision) and T53 (PreCompact freshness) make recovery accurate, and T54 is the end-to-end smoke check.

Two requirement-to-ticket mappings are intentionally folded (EDMV2-72 -> T28 alone; Resume-Point-freshness -> T48+T28), so the T31 and T49 numbers are reserved-and-omitted to preserve the WS-J -> WS-M -> WS-N block ordering. The README index should list T24-T30, T32-T48, T50-T54 (29 tickets) and note T31/T49 as intentionally unused.
