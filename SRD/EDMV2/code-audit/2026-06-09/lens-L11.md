# Lens L11: Integration Wiring — Round 2 (2026-06-09)

## Summary

The rewrite's wiring is in very good shape. Every `edm-state` subcommand referenced by the 13 skills, `hooks/hooks.json`, and `monitors/monitors.json` resolves to a defined `cmd_*` function in the current binary; every agent referenced by a skill exists on disk; every `marketplace.json` skill/agent path exists; and **G23 is fully fixed** (zero `edm-ai-development-staging` references remain).

**One finding survives: G5 part (b) is only PARTIALLY fixed.** G5 part (a) — the wrong/diverged manifest — is CONFIRMED FIXED in key-set terms (both `plugin.json` files now carry all 19 keys). But part (b) — the dead mode config — was **not resolved**: `mode`, `compliance_enabled`, and `implementation_mode` remain in *both* manifests as install-time defaults that **no code path ever reads**. The remediation's own instruction was "do not leave a key in the manifest that nothing reads" (wire OR remove); neither was done. This now additionally **falsifies the SRD's explicit precedence contract** at `srd.md:1302-1303` (F-B-05 / EDMV2-102), which mandates a three-tier `per-initiative state > userConfig default > built-in default` chain — the middle tier is missing. Severity P2 (dead config / spec contract violation, no runtime failure).

## Findings

### [P2] Three userConfig keys remain dead config — `mode`, `compliance_enabled`, `implementation_mode` are never consumed (G5 part b, not resolved)

**Chain:** `plugin.json` userConfig.{mode, compliance_enabled, implementation_mode} → (install-time prompt sets `CLAUDE_PLUGIN_OPTION_{…}`) → **NO READER**.

**Evidence:**
- Both manifests define all three: `.claude-plugin/plugin.json:116/122/134`, root `plugin.json:73/79/133`.
- The only `CLAUDE_PLUGIN_OPTION_*` reads in the plugin are `SRD_ROOT`, `SRD_FILENAME`, `TICKET_PACK_DIRNAME`, `HUMAN_HOURLY_RATE_USD`, `COMMIT_STATE_FILE` (`edm-state:42-45`, `edm-init:6,116`, `edm-validate-prefix:10`, `edm-lint-artifacts:19-20`). No `…_MODE`/`…_COMPLIANCE_ENABLED`/`…_IMPLEMENTATION_MODE` read exists.
- `cmd_init` **hardcodes** the seeds: `mode:"standard"`, `compliance_enabled:false`, `implementation_mode:"standard"` (`edm-state:512-515`).
- `edm-init` reads only a `--mode` CLI flag (default hardcoded `standard`) and never threads mode to `edm-state init`.
- These three fields are only ever written from CLI args (`cmd_set_mode:1391/1403/1410`) and read for display/HANDOFF — never seeded from a config default.
- The orchestrator obtains them **interactively** (`SKILL.md:148-163`, `:487-492`); the userConfig default is never pre-selected.
- `grep -rn 'user_config\.(mode|implementation_mode|compliance_enabled)' skills agents bin` → nothing.
- **SRD contract falsified:** `srd.md:1302-1303` (F-B-05): "these are install-time defaults … precedence: per-initiative state > userConfig default > built-in default." The code implements only two tiers (per-initiative hardcoded-at-init > built-in); the userConfig-default tier is absent.

**Why P2:** No runtime failure — every initiative gets the built-in `standard`/`false` regardless of the install setting. The meaningful case: a regulated shop sets `compliance_enabled: true` at install and expects new initiatives to default compliance-on; today that setting is silently inert.

**Suggested fix (pick one, per round-1 guidance):**
- **Wire (preferred for `compliance_enabled`):** have `edm-init` read `CLAUDE_PLUGIN_OPTION_{MODE,COMPLIANCE_ENABLED,IMPLEMENTATION_MODE}`, export them so `edm-state init` seeds the new state (mirroring the `EDM_PRODUCT`/`EDM_DESCRIPTION` pattern), and have the orchestrator pre-select that value as the default `AskUserQuestion` option — realizing the `srd.md:1302-1303` three-tier precedence.
- **Remove:** delete the three keys from both manifests + their CLAUDE.md/CHANGELOG references and note that per-initiative interactive selection is the sole mechanism. (`qc_shard_threshold` must stay — it is genuinely consumed.)

**Note — `qc_shard_threshold` is NOT dead** (correctly resolved): consumed by `skills/implement/SKILL.md:66,72` (`user_config.qc_shard_threshold`, default 20). No action.

## Round-1 fix verification (L11)

- **G5 part (a) — wrong/diverged manifest: CONFIRMED FIXED (key-set).** Both manifests carry the identical full 19-key userConfig set incl. all four T129 keys + `jira_mcp_namespace`. The canonical `.claude-plugin/plugin.json` is no longer key-incomplete. (Two copies still coexist; L9 found content drift in descriptions/ordering — flagged there as the T22-dedup issue. Not an L11 wiring break.)
- **G5 part (b) — dead mode config: PARTIAL (NOT resolved).** See finding above. `qc_shard_threshold` correctly consumed.
- **G23 — stale `edm-ai-development-staging/` paths: CONFIRMED FIXED.** Whole-plugin grep returns 0 matches. `wave3:5`/`wave4a:5` run-hints now reference `edm-ai-development`.

## Wiring trace results

**userConfig keys → consumer (19 keys):** all wired EXCEPT `mode`, `compliance_enabled`, `implementation_mode` (NO consumer — finding). `qc_shard_threshold` → `skills/implement:66,72` (yes). `srd_root`/`srd_filename`/`ticket_pack_dirname`/`commit_state_file`/`human_hourly_rate_usd`/`jira_*`/`coverage_target_*`(×4)/`test_framework_*`(×3)/`prefix_format_hint` → all consumed.

**Subcommands referenced by skills/hooks/monitor → defined in dispatcher (`:1929-1964`):** ALL resolve. Skills: list/get/set/phase-start/phase-complete/srd-version/skip-phase/resolve-dir/audit-round-start/approve-gate/current-step/write-handoff/set-mode/archive/update-patterns/record-tests-added/record-test-coverage/get-coverage/record-partial-verdict/metrics-report. Hooks: session-start/gate-check/active-initiatives/checkpoint-if-active/record-partial-verdict/record-task-duration. Monitor: watch-impl. `edm-state lint` → delegates to `edm-lint-artifacts` (present). No referenced-but-missing subcommand; no unreachable dispatched `cmd_*`. Defined-but-CLI-only (not a wiring break): branch-check, git-lock-check, validate, set-supersedes, set-forked-from, set-parent, add-related.

**`edm-init` flags → binary:** `--product`/`--description`/`--mode`/bare `<PREFIX>` all parsed. (See Noted re: `--mode` never driven by a skill.)

**Hook/monitor command paths:** only `edm-state` and `edm-lint-artifacts` invoked; both exist; guarded with `command -v`.

**marketplace.json → disk:** all 13 skill dirs and all 29 `agents/*.md` for `edm-ai-development` exist (`.claude-plugin/marketplace.json:36-82`).

**Skill → agent references:** all referenced agents exist on disk; no orphaned reference.

**Staging refs found:** 0.

## Noted / Not Actionable

- Two coexisting `plugin.json` files — byte-equivalent in userConfig key set today; content drift is L9's T22-dedup finding. Not an L11 break.
- `bin/edm-init --mode` flag defined/validated but no skill passes `--mode` (orchestrator/plan scaffold without it, then `set-mode` post-init). Works manually; `standard` scaffolds identically. Latent, not a break. NOTED.
- `record-task-duration` (TaskCompleted hook) is a documented reserved no-op; hook→subcommand chain resolves. NOTED.
- Diagnostic/user subcommands reached only via manual CLI (branch-check, git-lock-check, validate, set-supersedes, set-forked-from, set-parent, add-related) — documented in CLAUDE.md bin table; not required to have a skill caller. NOTED.
- Staging strings under `SRD/EDMV2/**` are historical initiative artifacts, out of scope for this plugin audit. NOTED.
