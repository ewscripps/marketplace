# Lens L9: Spec & Ticket Compliance — Round 2 (2026-06-09)

## Summary

I cross-referenced the SRD requirements and ticket ACs against the remediated code, focusing on the tickets whose Target Components were touched by the Round-1 remediation (the `bin/edm-state` rewrite, the manifests, `bin/edm-init`, `bin/edm-lint-artifacts`, the orchestrator skill, the smoke tests).

The remediation is overwhelmingly sound: G1 (both-layout enumeration), G2/G3 (locked RMW for all mutators incl. `checkpoint`), G7 (prefix guard in `state_file_for`), G6 (`mapfile` removed), and the bulk of G5 (manifest version + userConfig keys) all hold and keep their backing ACs satisfied.

However, I found **two genuine compliance gaps introduced or left by the remediation pass, plus two pre-existing gaps**:

- **P1 — G5 part (a) only PARTIALLY fixed (regression risk realized):** the 5 userConfig keys were added to `.claude-plugin/plugin.json` but the duplicate root `plugin.json` was **not** removed/symlinked. Both files still exist and **have already diverged** in key descriptions and key order — the exact T22 AC1/AC2 condition G5 was supposed to close.
- **P1 — `migrate-path` (T42/T132) write path NOT converted to `rmw_state`:** G12's fix was half-applied (inputs sanitized, but the post-move write bypasses the lock and the T132 `.bak`). Violates T132 AC1/AC5 and T42 AC7; the new wave5 test does not catch it.
- **P2 — T35 AC3/AC4 orchestrator wiring absent** (pre-existing; G1 only fixed the subcommand glob, not the orchestrator's use of it).

No P0. The two P1s are narrow and pre-deployment (no shipped state to corrupt).

## Findings

### [P1] EDMV2-T22 / G5(a) — Duplicate `plugin.json` still present and already diverged — `plugin.json` vs `.claude-plugin/plugin.json`

**Requirement/AC:** T22 AC1/AC2: "exactly one authoritative manifest; no second copy can drift." Round-1 G5(a): "Exactly one `plugin.json` on disk (or root is a symlink) … remove the root `plugin.json`."

**Code reality:** Both files exist as independent regular files (root is not a symlink). Both carry `version: 2.0.0` and all five T129 keys (so `claude plugin validate` and the install prompt are satisfied — the operative half of G5). But the two copies **have already drifted**:
- `srd_root.description`: root says product-scoped `{srd_root}/{PRODUCT}/{PREFIX}__{DESCRIPTION}/`; `.claude-plugin/plugin.json:27` still says the **stale flat** `{srd_root}/{PREFIX}/`.
- `mode.description`, `jira_mcp_namespace.description` differ; `jira_project_key.description` ASCII `--` vs em-dash; userConfig key **ordering** differs.

**Gap:** The drift T22/G5 set out to eliminate is now real and live. `claude plugin validate` loads `.claude-plugin/plugin.json`, so the **stale flat-layout `srd_root` description** is shown at install time, contradicting the canonical product-scoped layout v2.0 documents everywhere else.

**Suggested fix:** Delete the root `plugin.json` (or make it a symlink), then re-sync the canonical file's `srd_root` description to the product-scoped form. Re-run `claude plugin validate`. (The schema does not forbid a second file, which is why validate passes — the violation is the project's own T22 AC.)

### [P1] EDMV2-T132 / EDMV2-T42 AC7 / G12 — `migrate-path` post-move write bypasses the lock and `.bak` — `bin/edm-state:1114-1120`

**Requirement/AC:** T132 AC1 "before any state-file write, copy `.edm-state.json` to `.edm-state.json.bak`"; AC5 "the backup runs for **every** mutating subcommand" — `migrate-path` is explicitly listed. T42 AC7 "state-field writes go through the typed/locked write path." G12: "Route the post-move state update through `rmw_state`."

**Code reality:** `cmd_migrate_path` applies the G12 input-sanitization half (`:1090-1091`) but the post-move write was **not** converted — it remains `cat | jq | printf > tmp && mv`, the **only** mutating path in the 1972-line script that does not call `rmw_state` (every other mutator was converted). So it takes no `with_state_lock` and writes **no `.bak`**.

**Gap:** T132 AC5 VIOLATED for `migrate-path`; T42 AC7 VIOLATED. It does get atomic temp+mv (G9 satisfied), and the destination dir was just created (so the lock omission has no realistic concurrent contender) — hence P1, not P0. The backup omission is the substantive miss. wave5 exercises `migrate-path` but asserts `.bak` only for `set`, so untested (secondary T132 AC9 / G19 gap).

**Suggested fix:** Replace `:1114-1120` with `rmw_state "$prefix" '.product_name=$p|.initiative_description=$d|.last_updated=$t' --arg p "$product" --arg d "$description" --arg t "$(now_utc)"`. Add a `migrate-path produces a .bak` assertion to wave5.

### [P2] EDMV2-T35 / EDMV2-107 — Orchestrator does not run `active-initiatives` / `branch-check` on phase start — `skills/orchestrator/SKILL.md` (Step 1)

**Requirement/AC:** T35 AC3 "on any phase start the orchestrator runs `active-initiatives`; when >1 active it warns naming each prefix + branch." AC4 "on a branch mismatch `branch-check` … blocks the phase."

**Code reality:** The `active-initiatives` and `branch-check` subcommands exist and are correct (G1 fixed `active-initiatives` to scan both layouts). `active-initiatives` is consumed by the PreToolUse git-commit lint hook. But no skill (incl. the orchestrator) invokes either — Step 1 reads `current_phase`/`current_step`/mode but never calls the simultaneous-initiative detection or branch-mismatch block.

**Gap:** T35 AC3/AC4 unmet. **Pre-existing, not a remediation regression** — Round-1 G1 scoped only the subcommand glob; the subcommand-level ACs (AC1/AC2/AC5/AC7/AC8) are MET. P2 (protective subcommands exist; git-commit hook is a partial backstop).

**Suggested fix:** Add to orchestrator Step 1: run `active-initiatives` (warn if >1) and `branch-check <PREFIX>` (BLOCK on non-zero). Prompt-logic change only.

## Round-1 fix verification (L9)

**G5 (P1, L9+L11) → PARTIAL.** Part (a): the deployment-critical half (keys present in the loaded manifest) is **fixed**; the de-duplication half **regressed into live drift** (P1 above; T22 AC1/AC2 remain VIOLATED). Part (b): `mode`/`implementation_mode`/`compliance_enabled` remain per-initiative-set via `set-mode` + interactive seeding; keys exist as documented install-time defaults. `qc_shard_threshold` consumed by `skills/implement`. Acceptable resolution of part (b). (L11 flags the three keys as dead config — see L11.)

## AC compliance of remediation-touched tickets

| Ticket | AC(s) at risk | Verdict | Evidence |
|---|---|---|---|
| EDMV2-T37 (path resolver) | both-layout AC1-9 | MET | `state_file_for:142-186` |
| EDMV2-T44 (HANDOFF paths) | no hardcoded SRD/{prefix} | MET | `write_handoff_internal` derives from `initiative_dir_for` |
| EDMV2-T35 — subcommand | AC1/2/5/7/8 | MET | `cmd_active_initiatives:1129-1145`, `cmd_branch_check:1213-1235` |
| EDMV2-T35 — orchestrator | AC3/AC4 | **NOT MET (pre-existing)** | orchestrator never calls them (P2) |
| EDMV2-T42 (migrate-path) | AC1-6/8 MET; **AC7 VIOLATED** | PARTIAL | post-move write not locked (`:1116-1120`) |
| EDMV2-T132 (auto-backup) | AC1; **AC5 VIOLATED for migrate-path** | PARTIAL | `migrate-path` bypasses `.bak` |
| EDMV2-T24 (locking) | AC1-8 | MET | `with_state_lock:338-373`; G13 die applied |
| EDMV2-T25 (typed-set) | AC1-9 | MET | `cmd_set:455-472` |
| EDMV2-T33 (read coercion) | AC1/4 MET; AC2 read_num removed | MET | `read_bool:379-389`; `read_num` deleted per G14 |
| EDMV2-T30 (git archive) | AC1-10 | MET | `cmd_archive:826-873` |
| EDMV2-T22 (de-dup manifest) | **AC1/AC2 VIOLATED** | PARTIAL | dual diverged `plugin.json` (P1) |
| EDMV2-T129 (userConfig keys) | AC1-7/10 | MET | 5 keys + types/defaults present |
| EDMV2-T127 (version bump) | AC1 | MET | `plugin.json:4` = 2.0.0 |
| EDMV2-T39/T41 (global uniqueness) | AC1-9 | MET | `edm-validate-prefix` global scan |
| EDMV2-T46/47/48/50/51 (current_step/Resume/session) | — | MET | verified per-field |

## Noted / Not Actionable (incl. deferred-by-design)

- G14 `read_num` removed (T33 AC2 named the helper; deletion is the accepted G14 option; numeric coercion satisfied by per-command `tonumber` checks). NOTED.
- userConfig key names conform to schema `^[A-Za-z_]\w*$` (hyphens only in default values); validate passes. The P1 is project-AC drift, not schema invalidity. NOTED.
- T104/T105/T110/T134 — Should/Could/deferred items, untouched by remediation; not regressions. NOTED.
- `migrate-path` lock omission (vs backup omission) — low-risk (just-created dest, atomic write); folded into the P1.
- `record-task-duration` reserved no-op (T10) — documented. NOTED.
- No scope-creep subcommands: every dispatched `cmd_*` maps to a ticket-backed subcommand; remediation added only internal helpers (G18/G1/G2/G7 plumbing). NOTED.
