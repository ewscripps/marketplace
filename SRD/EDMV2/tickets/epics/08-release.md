# Epic 8 — Release Requirements

Generated From: srd.md v1.0.7

Cross-cutting release, self-hosting safety, and v2.0.0 ship requirements drawn from SRD §4.14 (EDMV2-100 through EDMV2-110). This epic gates the declaration of EDMV2 as complete: it bumps the plugin and marketplace versions, validates the modified plugin, defines the new userConfig surface, protects the self-hosted state file and live plugin during Phase 6, and updates the two user-facing docs.

These tickets sit at the end of the dependency graph. EDMV2-T133 (staging copy) runs at the START of Phase 6; the remaining tickets run at the END of the initiative. EDMV2-T127 (version bump) is the LAST ticket in the entire EDMV2 initiative — nothing depends on it except EDMV2-T128 (validate), which is the final verification.

Requirements EDMV2-106 (TDD mode), EDMV2-107 (branch isolation / per-gate commits), and EDMV2-108 (stale git lock remediation) are NOT in this epic — they are owned by Epic 5 (WS-E) and Epic 2 (WS-J) respectively and must not be duplicated here.

---

## EDMV2-T127: Bump plugin version to 2.0.0 and write the CHANGELOG 2.0.0 entry

| Field | Value |
|---|---|
| Workstream | Release / WS-A |
| Phase | 6 |
| Priority | Must Have |
| SRD Requirements | EDMV2-100 |
| Size | S |
| Target Components | `plugins/edm-ai-development/plugin.json` (set `version` 1.3.0 -> 2.0.0); `plugins/edm-ai-development/CHANGELOG.md` (add `## [2.0.0]` entry); `plugins/edm-ai-development/.claude-plugin/plugin.json` IF it still exists after EDMV2-T (G16 de-dup) — only the single authoritative manifest is updated |
| Dependencies | ALL prior EDMV2 tickets (every WS-A through WS-N ticket and every other release ticket EDMV2-T128 excepted). This is the LAST ticket in the entire initiative — it is performed only after every other feature ticket is implemented, QC'd, and the code-audit has converged. |

### Description
The plugin advertises a target version of 2.0.0 (SRD Document Info: current 1.3.0 -> target 2.0.0). The single authoritative `plugin.json` manifest must report `2.0.0`, and `CHANGELOG.md` must carry a complete 2.0.0 entry that documents the EDMV2 change set following the existing Keep-a-Changelog + SemVer format already used for the 1.3.0 entry.

The version bump is the final substantive change in the initiative. It is deliberately sequenced last so that the manifest never claims 2.0.0 while feature work is still in flight, and so that `claude plugin validate` (EDMV2-T128) runs against a manifest whose version matches the shipped feature set. The marketplace.json bump is a separate ticket (EDMV2-T131) because it lives in a different repository file with a different schema and owner.

The CHANGELOG entry is the single human-readable source of truth that EDMV2-T134 (docs) and the `README.md` update must remain consistent with, so it must enumerate the workstreams, new modes, new `edm-state` subcommands, new userConfig keys, and the new directory layout at a summary level.

### Acceptance Criteria
- [ ] AC1: `jq -r .version plugins/edm-ai-development/plugin.json` prints exactly `2.0.0`.
- [ ] AC2: The G16 de-duplication (single authoritative manifest) is respected — only one `plugin.json` is updated; if `.claude-plugin/plugin.json` was removed by the WS-A G16 ticket, this ticket does not re-create it.
- [ ] AC3: `CHANGELOG.md` contains a top section header matching `^## \[2\.0\.0\] —` (em-dash form, consistent with the existing `## [1.3.0] —` entry) with a release date.
- [ ] AC4: The 2.0.0 entry has an `### Added` (or equivalent Keep-a-Changelog) subsection that names all thirteen in-scope workstreams (WS-A through WS-N, WS-I excluded).
- [ ] AC5: The 2.0.0 entry lists the new adaptation modes (mini-SRD, IaC, data/ML, prototype) and the compliance gate, the TDD implementation mode, branch isolation, the living audit-pattern library, compaction resilience, and the new `SRD/{PRODUCT}/{PREFIX}__{DESCRIPTION}/` directory layout.
- [ ] AC6: The 2.0.0 entry lists the new `edm-state` subcommands introduced in EDMV2 (audit-round-start, record-partial-verdict, set-mode, set-parent, add-related, migrate-path, current-step, update-patterns, validate) and the new userConfig keys (per EDMV2-T129).
- [ ] AC7: The 2.0.0 entry includes a backward-compatibility note stating that existing `.edm-state.json` files keep working via additive, defaulted fields (C-4).
- [ ] AC8: No banned content: `grep -iE 'generated with|co-authored-by|claude-flow' CHANGELOG.md` over the new entry returns nothing (WS-K / C-1).
- [ ] AC9: ASCII-only: `grep -nP '[^\x00-\x7F]' CHANGELOG.md plugin.json` returns no matches except the intentional em-dash in section headers, which is replaced with an ASCII `-` if the artifact lint (EDMV2-76) flags it.
- [ ] AC10: The CHANGELOG release date matches the date recorded in the EDMV2 `.edm-state.json` `completed_at` (or the cutover date), not a placeholder.

### Technical Notes
This ticket runs **post-cutover** against the live `plugins/edm-ai-development/` directory — T133 has already completed and the staging copy no longer exists. Confirm whether the WS-A G16 ticket made `plugin.json` (root) or `.claude-plugin/plugin.json` authoritative before editing — edit only the authoritative one. Use the existing 1.3.0 entry as the structural template. Keep the em-dash usage consistent with the existing file unless the artifact lint requires ASCII.

### Out of Scope
- The `marketplace.json` version bump (EDMV2-T131).
- The `README.md` content update beyond version consistency (owned by the WS-A G16 / docs tickets; this ticket only requires CHANGELOG <-> README consistency to be verifiable).
- Updating `.pptx` / `.docx` docs (EDMV2-T134).

### Verification
QC confirms PASS by: running `jq -r .version` on the authoritative manifest and asserting `2.0.0`; grepping `CHANGELOG.md` for the `## [2.0.0]` header and each required content item (AC4-AC7); running the banned-content and ASCII greps (AC8-AC9). FAIL if the manifest still reads 1.3.0, if any workstream or new subcommand/userConfig key is missing from the entry, or if banned content is present.

---

## EDMV2-T128: Confirm `claude plugin validate` passes on the modified plugin

| Field | Value |
|---|---|
| Workstream | Release |
| Phase | 6 |
| Priority | Must Have |
| SRD Requirements | EDMV2-101 |
| Size | S |
| Target Components | The whole `plugins/edm-ai-development/` tree (all `plugin.json`, `skills/*/SKILL.md` frontmatter, `agents/*.md` frontmatter, `hooks/hooks.json`); a recorded validation note in the EDMV2 testing-layer verification artifact |
| Dependencies | EDMV2-T127 (version bump). Transitively depends on all feature tickets, since validation runs against the fully-assembled plugin. This is the final verification step after the cutover (EDMV2-T133). |

### Description
Per C-2, the marketplace repo has no build/test/CI system; the primary available verification mechanism for the plugin is `claude plugin validate`, which checks the manifest schema and every skill/agent frontmatter. EDMV2 touches manifest userConfig, many skill `allowed-tools` entries (WS-A G14), agent `tools`/`disallowedTools` (WS-A G1, G13), and `hooks/hooks.json` (WS-C/J/N), so a clean validate run is a gating condition for declaring v2.0.0 ready.

This ticket runs the validator against the post-cutover live plugin and records the result. It is sequenced after EDMV2-T127 so the manifest version is final, and after EDMV2-T133 so the staging copy has replaced the live directory (validate must pass on what actually ships).

Because the validator is the only schema-level guard available, any failure it surfaces (malformed frontmatter, invalid userConfig type, unknown manifest field) blocks completion and must be remediated in the responsible feature ticket's component before this ticket can pass.

### Acceptance Criteria
- [ ] AC1: `claude plugin validate plugins/edm-ai-development` exits with status 0.
- [ ] AC2: The validator reports zero schema errors against `plugin.json` (including the new userConfig keys from EDMV2-T129).
- [ ] AC3: The validator reports zero frontmatter errors across all 30 `agents/*.md` (including the `Write`-grant change to `edm-test-coverage-auditor` from WS-A G1 and any new compliance/IaC/data-ML QC agents from WS-E).
- [ ] AC4: The validator reports zero frontmatter errors across all `skills/*/SKILL.md` (including the scoped `Bash(...)` allowed-tools changes from WS-A G14).
- [ ] AC5: `hooks/hooks.json` parses as valid JSON (`jq . hooks/hooks.json` exits 0) and the validator accepts its hook event names.
- [ ] AC6: The validation command, its full stdout/stderr, and exit status are recorded verbatim in the EDMV2 testing-layer verification notes (the canonical verification artifact), with the date and the plugin version validated.
- [ ] AC7: No staging directory is validated as a separate plugin — validation targets only the single live `plugins/edm-ai-development` (consistent with EDMV2-T133 keeping staging out of `marketplace.json`).
- [ ] AC8: If validation fails, the failing component and the owning ticket are identified in the recorded note (so remediation is routed, not silently patched here).

### Technical Notes
This ticket runs **post-cutover** against the live `plugins/edm-ai-development/` directory — T133 has already completed and the staging copy no longer exists. If the WS-A G16 de-dup left a single manifest, point the validator at the directory containing it. The validator is the canonical "test" under C-2 alongside sandbox runs and bash unit checks — treat a non-zero exit as a hard blocker.

### Out of Scope
- Fixing the underlying schema/frontmatter defects (those are remediated in the owning feature tickets; this ticket only verifies and records).
- Sandbox functional runs of individual skills (covered by per-feature verification ACs).

### Verification
QC confirms PASS by re-running `claude plugin validate plugins/edm-ai-development`, asserting exit 0, and confirming the recorded verification note exists with the command, output, exit status, date, and validated version. FAIL on any non-zero exit or a missing/placeholder verification note.

---

## EDMV2-T129: Define new userConfig keys with safe, behavior-preserving defaults

| Field | Value |
|---|---|
| Workstream | Release |
| Phase | 6 |
| Priority | Must Have |
| SRD Requirements | EDMV2-102 |
| Size | S |
| Target Components | `plugins/edm-ai-development/plugin.json` `userConfig` block (add `mode`, `jira_mcp_namespace`, `compliance_enabled`, `qc_shard_threshold`, `implementation_mode`); `bin/edm-state` and skills that read these values via `${user_config.*}` / `CLAUDE_PLUGIN_OPTION_*` env vars |
| Dependencies | WS-E tickets (mode / compliance_enabled / implementation_mode consumers), WS-C QC sharding ticket EDMV2-T (qc_shard_threshold consumer), WS-A G8 push-jira ticket (jira_mcp_namespace consumer). This ticket defines the keys; the consuming behavior is implemented in those workstreams. Runs near end of initiative once consumers exist. |

### Description
EDMV2 introduces new configurable behavior that must be expressible without hand-editing state: the adaptation profile (`mode`), the Jira MCP server namespace (`jira_mcp_namespace`, WS-A G8 / EDMV2-11), the compliance-gate flag (`compliance_enabled`, WS-E / EDMV2-46), the QC shard threshold (`qc_shard_threshold`, WS-C / EDMV2-32), and the Phase-6 implementation strategy (`implementation_mode`, WS-E / EDMV2-106). Each key must declare a default that reproduces exact v1.x behavior so that an install that accepts every default behaves identically to 1.3.0 (C-4 backward compatibility).

`product_name` is intentionally NOT a userConfig key — it is per-initiative only (recorded in `.edm-state.json` by `edm-init --product`, EDMV2-86 / F-B-05), so this ticket must not add it to `userConfig`.

The keys must follow the existing `userConfig` schema shape (`type`, `title`, `description`, `default`, optional `required`) already used by the 13 existing keys, and their defaults must be documented in `description` so the install-time prompt is self-explanatory.

### Acceptance Criteria
- [ ] AC1: `plugin.json` `userConfig` defines `mode` with `type: "string"` and `default: "standard"`; its description lists the valid profiles (standard / mini-srd / iac / data-ml / prototype).
- [ ] AC2: `userConfig` defines `jira_mcp_namespace` with `type: "string"` and `default: "plugin_jira_atlassian-mcp-server"` (matching EDMV2-11), enabling tool names of the form `mcp__{jira_mcp_namespace}__{tool}`.
- [ ] AC3: `userConfig` defines `compliance_enabled` with `type: "boolean"` and `default: false` (Gate 3.5 off by default per EDMV2-46).
- [ ] AC4: `userConfig` defines `qc_shard_threshold` with `type: "number"` and `default: 20` (matching the EDMV2-32 shard threshold).
- [ ] AC5: `userConfig` defines `implementation_mode` with `type: "string"` and `default: "standard"`; its description names the `tdd` alternative (EDMV2-106).
- [ ] AC6: Each new key has a non-empty `title` and `description`; `jq '.userConfig | keys' plugin.json` shows all five new keys present.
- [ ] AC7: `product_name` does NOT appear in `userConfig` (`jq '.userConfig.product_name' plugin.json` returns `null`).
- [ ] AC8: Omitting all five new keys at install reproduces v1.x behavior: with defaults applied, `mode=standard`, `compliance_enabled=false`, `implementation_mode=standard`, `qc_shard_threshold=20`, and push-jira targets the default namespace — verifiable by a sandbox run that sets none of the keys and observes standard-mode flow.
- [ ] AC9: The defaults documented here are consistent with the values referenced by the consuming tickets (WS-E mode branches, WS-C sharding, WS-A G8 namespace) — no drift between the schema default and the consumer's assumed default.
- [ ] AC10: `claude plugin validate` accepts the modified `userConfig` (cross-checked by EDMV2-T128).

### Technical Notes
Mirror the existing key shape in `plugin.json` (see `srd_root`, `coverage_target_unit_pct`). Numbers use JSON number type (no quotes); booleans use JSON boolean (relevant to WS-J typed-state, EDMV2-68). `bin/edm-state` and skills read these through the `CLAUDE_PLUGIN_OPTION_*` env mechanism already used for `srd_root`/`srd_filename`; this ticket only DEFINES the keys and their defaults — consumption logic belongs to the owning workstream tickets.

### Out of Scope
- Implementing the behavior each key controls (owned by WS-E, WS-C, WS-A G8).
- Adding `product_name` or any per-initiative field to userConfig.
- The seven testing-layer userConfig keys already shipped in 1.3.0 (unchanged).

### Verification
QC confirms PASS by running `jq '.userConfig | keys'` and asserting all five new keys exist with the correct types and defaults (AC1-AC6), asserting `product_name` is absent (AC7), and confirming a no-keys-set sandbox run yields standard v1.x behavior (AC8). FAIL on a missing key, wrong type, wrong default, presence of `product_name`, or default drift versus a consumer.

---

## EDMV2-T130: Record and verify self-hosting-safe ticket sequencing

| Field | Value |
|---|---|
| Workstream | Release |
| Phase | 4-6 (verification) |
| Priority | Must Have |
| SRD Requirements | EDMV2-103 |
| Size | XS |
| Target Components | The EDMV2 ticket pack itself: `SRD/EDMV2/tickets/README.md` (critical-path / dependency graph and a sequencing note); `.edm-state.json` sequencing record if one is kept |
| Dependencies | The existence of the WS-M, WS-N, WS-J epic tickets (so their ordering can be asserted). This is a verification/documentation ticket, not a build ticket. |

### Description
The architecture decision (SRD §5.0, §10.4) requires that WS-M (directory layout), WS-N (compaction resilience), and WS-J (state integrity / determinism) are sequenced before workstreams that add new path references or new state consumers, so the foundation the self-hosted running initiative depends on is hardened before new consumers arrive. The primary self-hosting protection is the staging copy (EDMV2-109 / EDMV2-T133); this sequencing requirement is the secondary, logical-dependency safeguard.

This ticket is explicitly a verification-and-documentation ticket (per the scope note): the epic sequencing of EDMV2 (Epic 2 covering WS-J, with WS-M/WS-N foundation work ordered first, then Epics 3-8) already satisfies the requirement. The ticket confirms the dependency graph encodes this order and records that confirmation in the ticket pack README so a reviewer can see at a glance that the foundation precedes its consumers.

No production code changes are made here; the deliverable is the documented, verified ordering.

### Acceptance Criteria
- [ ] AC1: The ticket pack `README.md` critical-path / dependency section shows WS-M, WS-N, and WS-J foundation tickets with no inbound dependency on any later path-consuming or state-consuming workstream ticket.
- [ ] AC2: Every ticket that constructs an artifact path (WS-D, WS-G, and any path-deriving skill/agent ticket) depends on the WS-M state-derived-path ticket (EDMV2-88) directly or transitively.
- [ ] AC3: Every ticket that adds a new `.edm-state.json` consumer (WS-E modes, WS-C verdicts, WS-N resume) depends on the relevant WS-J state-integrity ticket(s) directly or transitively.
- [ ] AC4: The README contains a short "Self-hosting sequencing" note that states WS-M/WS-N/WS-J are foundation-first and cites EDMV2-103 and the staging copy (EDMV2-109) as the primary mitigation.
- [ ] AC5: No dependency cycle exists in the graph (a topological order exists) — verifiable by inspection of the Depends-On fields across all epics.
- [ ] AC6: The note explicitly states this is a secondary safeguard and that the staging copy (EDMV2-T133) is the primary C-5 protection, so reviewers do not over-rely on sequencing alone.

### Technical Notes
This ticket has no source-code target; it asserts properties of the ticket pack the auditor (`edm-ticket-auditor`) also checks for cycles and orphans. Keep the README note concise and link to EDMV2-T133. If the dependency graph is rendered as a Mermaid diagram in the README, confirm the foundation nodes have no inbound edges from consumer nodes.

### Out of Scope
- Re-ordering or rewriting other epics' tickets (if the graph is wrong, the fix is raised against the offending ticket, not done here).
- The staging copy mechanism itself (EDMV2-T133).

### Verification
QC confirms PASS by inspecting the ticket pack README dependency graph and the Depends-On fields, asserting the foundation-first ordering (AC1-AC3), absence of cycles (AC5), and presence of the sequencing note with the EDMV2-103 / EDMV2-109 citations (AC4, AC6). FAIL if any consumer ticket is ordered before its WS-M/WS-N/WS-J prerequisite, if a cycle exists, or if the note is missing.

---

## EDMV2-T131: Bump the marketplace.json edm-ai-development entry to 2.0.0

| Field | Value |
|---|---|
| Workstream | Release |
| Phase | 6 |
| Priority | Must Have |
| SRD Requirements | EDMV2-104 |
| Size | XS |
| Target Components | `/Users/darryl.porter/projects/marketplace/.claude-plugin/marketplace.json` (the `edm-ai-development` plugin entry `version` field: 1.3.0 -> 2.0.0; the entry `skills` / `agents` arrays if EDMV2 added or removed any) |
| Dependencies | EDMV2-T127 (plugin.json version bump) — the marketplace entry version must match the plugin manifest version. Transitively depends on the cutover (EDMV2-T133) so any new skills/agents added by EDMV2 exist before the arrays are updated. |

### Description
The marketplace registry `.claude-plugin/marketplace.json` carries a per-plugin `version` that must track the plugin's own `plugin.json` version. The `edm-ai-development` entry currently reads `1.3.0` and must be set to `2.0.0` to match EDMV2-T127. If EDMV2 added new skills (none planned beyond existing 13) or new agents (WS-E compliance/IaC/data-ML QC agents), the entry's `skills` / `agents` arrays must be updated to include them so the marketplace lists the shipped surface accurately.

Per C-1, the `requires: { mcp: [...] }` field must NOT be added to the marketplace entry. The entry must not register `plugins/edm-ai-development-staging` as a separate plugin (consistent with EDMV2-T133).

This ticket is XS and mechanical, but it is a Must because an out-of-sync marketplace version causes installs to advertise the wrong version.

### Acceptance Criteria
- [ ] AC1: In `.claude-plugin/marketplace.json`, the `edm-ai-development` plugin object's `version` field equals `2.0.0` (`jq -r '.plugins[] | select(.name=="edm-ai-development") | .version' .claude-plugin/marketplace.json` prints `2.0.0`).
- [ ] AC2: The `edm-ai-development` entry `version` matches the authoritative `plugin.json` `version` (both `2.0.0`).
- [ ] AC3: The entry's `agents` array includes any new agent files added by EDMV2 (e.g., new WS-E compliance/IaC/data-ML QC agents) and no longer references any agent file removed by EDMV2; every listed path exists under `plugins/edm-ai-development/`.
- [ ] AC4: The entry's `skills` array matches the actual `skills/` directories shipped in v2.0.0; every listed path exists.
- [ ] AC5: No `requires` / `mcp` field is added anywhere in the entry (C-1) — `jq '.plugins[] | select(.name=="edm-ai-development") | .requires' marketplace.json` returns `null`.
- [ ] AC6: No staging plugin entry exists (`jq '.plugins[] | select(.name=="edm-ai-development-staging")' marketplace.json` returns nothing).
- [ ] AC7: The other plugin entries (git, jira, ada-tablo, bruno, web-cms) are unchanged by this ticket (diff touches only the edm-ai-development entry).
- [ ] AC8: `jq . .claude-plugin/marketplace.json` exits 0 (file remains valid JSON after the edit).

### Technical Notes
Edit only the `edm-ai-development` object; do not reformat the rest of the file. If WS-E added QC agents, get the exact filenames from the agents directory before listing them. The marketplace `metadata.version` (currently 1.1.0) is the registry version, NOT the plugin version — do not change it as part of this ticket.

### Out of Scope
- Bumping the registry-level `metadata.version`.
- Editing other plugins' entries.
- Adding the staging directory to the registry.

### Verification
QC confirms PASS by running the AC1/AC2 `jq` checks (version 2.0.0 and parity with plugin.json), confirming each listed skill/agent path exists (AC3-AC4), asserting no `requires` field and no staging entry (AC5-AC6), and confirming the file is valid JSON with only the edm entry changed (AC7-AC8). FAIL on any version mismatch, dangling path, presence of `requires`, or unintended edits to other entries.

---

## EDMV2-T132: Auto-backup `.edm-state.json` before any state mutation

| Field | Value |
|---|---|
| Workstream | Release / WS-J-adjacent |
| Phase | 6 |
| Priority | Must Have |
| SRD Requirements | EDMV2-105 |
| Size | M |
| Target Components | `plugins/edm-ai-development/bin/edm-state` (add a backup step invoked by every write path: `set`, `set-mode`, `approve-gate`, `phase-start`, `phase-complete`, `srd-version`, `archive`, `init`, `record-*`, `current-step`, `audit-round-start`, `record-partial-verdict`, `set-parent`, `add-related`, `migrate-path`, `update-patterns`, `checkpoint-if-active`) |
| Dependencies | EDMV2-T24 (advisory file locking, WS-J) so the backup-then-write sequence runs inside the advisory lock and cannot race. Should be coordinated with the WS-J typed-state ticket (EDMV2-68). |

### Description
Because EDMV2 is self-hosted (C-5) and modifies `edm-state` while that same `edm-state` tracks the EDMV2 initiative, a faulty write during development could corrupt the live `.edm-state.json` of an in-flight initiative. To protect against this, every mutation must first copy the current `.edm-state.json` to `.edm-state.json.bak` so the prior good state is always recoverable.

The backup must be written atomically and before the new state is committed to disk, and it must live alongside the state file in the initiative directory. Combined with the staging copy (EDMV2-T133, which protects the plugin code) and file locking (EDMV2-70, which prevents concurrent corruption), the backup is the recovery layer: if a write produces malformed JSON, the operator restores from `.edm-state.json.bak`.

The backup must be a no-op-safe operation: on `init` (no prior file) it simply skips; on every subsequent write it overwrites the single `.bak` with the last-known-good copy taken immediately before the new write.

### Acceptance Criteria
- [ ] AC1: Before any state-file write, `edm-state` copies the existing `.edm-state.json` to `.edm-state.json.bak` in the same initiative directory.
- [ ] AC2: The backup is taken from the on-disk pre-write content (the last-known-good state), not from the in-memory post-mutation content.
- [ ] AC3: On `edm-state init` where no prior `.edm-state.json` exists, the backup step is skipped without error (no empty/`.bak` of a missing file).
- [ ] AC4: After a successful `set`, `.edm-state.json.bak` contains the exact bytes the state file had before the `set` (verifiable: capture state, run a `set`, diff `.bak` against the captured pre-image — they match).
- [ ] AC5: The backup runs for every mutating subcommand listed in Target Components; a read-only subcommand (`get`, `list`, `metrics-report`, `get-coverage`, `validate`) does NOT create or modify a `.bak`.
- [ ] AC6: The backup occurs inside the advisory file lock (EDMV2-70) so a concurrent writer cannot interleave between backup and write.
- [ ] AC7: If the live write fails (e.g., `jq` produces invalid output and the script aborts), the original `.edm-state.json` is left intact and `.edm-state.json.bak` holds the recoverable copy — the operator can restore by `cp .edm-state.json.bak .edm-state.json`.
- [ ] AC8: The backup mechanism is POSIX bash (C-3), uses no new external dependency beyond `jq`/`cp`, and is documented in the `edm-state` usage header and CLAUDE.md.
- [ ] AC9: A documented bash unit check (C-2) demonstrates: pre-write content equals post-write `.bak` content for a representative mutation, and `init` on a fresh prefix creates no `.bak`.
- [ ] AC10: Backward compatible (C-4): existing initiatives gain a `.bak` on their next mutation with no schema change to `.edm-state.json` itself; the `.bak` file is excluded from or included in git per the same `commit_state_file` policy decision documented in the ticket.

### Technical Notes
Implement as a single `backup_state()` helper called at the top of the write path (after lock acquisition, before the `jq | mv` swap). Use the existing atomic write pattern (`jq ... > tmp && mv tmp file`); take the backup with `cp -p "$STATE" "$STATE.bak"` guarded by `[[ -f "$STATE" ]]`. Decide and document whether `.edm-state.json.bak` is git-ignored (recommended: ignored, since it is a transient recovery artifact, not a deliverable — note this in CLAUDE.md and add to the initiative `.gitignore` guidance). Coordinate ordering with EDMV2-70 so backup is strictly inside the lock.

### Out of Scope
- Multi-generation / rotating backups (single `.bak` is sufficient per EDMV2-105).
- Automatic restore-on-corruption (operator-initiated restore is acceptable; only the backup is required).
- Backing up other artifacts (only `.edm-state.json`).

### Verification
QC confirms PASS by reading the `backup_state` helper and its call sites (asserting every mutating subcommand calls it and no read-only subcommand does), and by running the documented bash unit check: capture a state file, run a `set`, and assert `.edm-state.json.bak` byte-matches the captured pre-image while the live file holds the mutation (AC2, AC4); run `init` on a fresh prefix and assert no `.bak` is created (AC3). FAIL if any mutation path skips the backup, if the backup is taken post-write, or if a read-only command writes a `.bak`.

---

## EDMV2-T133: Create the plugin staging copy and perform the single-step cutover

| Field | Value |
|---|---|
| Workstream | Release |
| Phase | 6 |
| Priority | Must Have |
| SRD Requirements | EDMV2-109 |
| Size | M |
| Target Components | New directory `plugins/edm-ai-development-staging/` (full copy of `plugins/edm-ai-development/` at Phase 6 start; all Phase 6 edits land here); the live `plugins/edm-ai-development/` (replaced by staging at cutover); `.claude-plugin/marketplace.json` (must NOT gain a staging entry) |
| Dependencies | Gate 3 approval (start of Phase 6). This ticket BRACKETS all of Phase 6: its first half (staging creation) runs at Phase 6 start before any other EDMV2-T implementation ticket; its second half (cutover) runs at the very end, after every feature ticket and QC pass, and immediately before EDMV2-T127 (version bump) / EDMV2-T128 (validate). |

### Description
EDMV2 modifies the very plugin (`edm-state`, hooks, skills) that the running EDMV2 initiative depends on (C-5). Editing the live plugin mid-flight could corrupt the initiative's own state machine or hooks. The primary mitigation (SRD §5.6 Risk 1, §10.4) is a staging copy: at Phase 6 start the entire live plugin is copied to `plugins/edm-ai-development-staging/`, ALL Phase 6 implementation work modifies only the staging copy, and the live plugin is never touched during Phase 6. At completion, the staging directory replaces the live directory in a single cutover step.

The staging directory must NOT be registered in `marketplace.json` as a separate plugin entry — it is a working copy, not a shipped plugin. The cutover is a single, reviewable operation (e.g., `git mv` / directory swap) that produces a live `plugins/edm-ai-development/` byte-identical to the validated staging copy.

This ticket has two checkpoints in the timeline: setup (first action of Phase 6) and cutover (last action before version bump/validate). Both are captured here as one ticket because they are the two ends of the same self-hosting-safety mechanism.

### Acceptance Criteria
- [ ] AC1: At Phase 6 start, `plugins/edm-ai-development-staging/` exists as a full, faithful copy of `plugins/edm-ai-development/` (same files; a recursive diff at copy time is empty).
- [ ] AC2: During Phase 6 (before cutover), `git diff plugins/edm-ai-development/` is empty — the live plugin receives zero changes while implementation proceeds.
- [ ] AC3: During Phase 6, every EDMV2 implementation change appears only under `plugins/edm-ai-development-staging/` (verifiable: `git status` shows modifications confined to the staging path).
- [ ] AC4: `marketplace.json` contains no `edm-ai-development-staging` plugin entry at any point (`jq '.plugins[] | select(.name | test("staging"))' marketplace.json` returns nothing).
- [ ] AC5: At cutover, the live `plugins/edm-ai-development/` is replaced by the staging contents such that a recursive diff between the post-cutover live directory and the pre-cutover staging directory is empty.
- [ ] AC6: After cutover, the `plugins/edm-ai-development-staging/` directory is removed (or emptied) so no duplicate plugin tree remains in the repo.
- [ ] AC7: The cutover is a single, atomic, version-controlled step (one commit / staged rename), not a piecemeal file-by-file copy, so the change is reviewable as one unit.
- [ ] AC8: The cutover happens AFTER all feature tickets and QC complete and BEFORE EDMV2-T127 (version bump) and EDMV2-T128 (validate) run against the live tree — the sequencing is documented and reflected in the ticket dependency graph.
- [ ] AC9: The staging-copy and cutover procedure is documented (for EDMV2-T134's user guide section and the CHANGELOG note) including the exact commands used.
- [ ] AC10: No banned git practices in the cutover step: git commands run as separate calls (not chained with `&&`), files staged by explicit path (no `git add -A` / `git add .`) per C-1.

### Technical Notes
Create the staging copy with a recursive copy (`cp -R plugins/edm-ai-development plugins/edm-ai-development-staging`) as the first Phase 6 action; do this before any other EDMV2 implementation ticket runs. All subsequent edits target the staging path. For the cutover, prefer a `git mv`-based swap (remove live, `git mv` staging into place) so the rename is tracked, staging files by explicit path. Verify with a recursive diff before committing the cutover. Because the live `edm-state`/hooks remain the running ones until cutover, the initiative's own state machine is undisturbed throughout Phase 6.

After cutover, T127 (version bump), T128 (plugin validate), T131 (marketplace.json), and T134 (documentation) run against the live `plugins/edm-ai-development/` directory — the staging path no longer exists at that point.

### Out of Scope
- Any feature implementation (those are the individual workstream tickets, all of which write into the staging path — this ticket only creates the staging copy and performs the swap).
- Registering staging in marketplace.json (explicitly forbidden).
- Bumping versions or running validate (EDMV2-T127 / EDMV2-T128, which depend on the cutover).

### Verification
QC confirms PASS by: at setup, asserting the staging copy is a faithful diff-clean copy (AC1) and that `git diff plugins/edm-ai-development/` stays empty through Phase 6 (AC2-AC3); at cutover, asserting the post-cutover live tree diffs clean against the pre-cutover staging tree (AC5), staging is removed (AC6), the swap is a single tracked commit (AC7), no staging entry exists in marketplace.json (AC4), and git-practice rules held (AC10). FAIL if the live plugin was modified during Phase 6, if a staging entry leaked into marketplace.json, or if the cutover is not a single reviewable step.

---

## EDMV2-T134: Update EDM_Plugin_Presentation.pptx and EDM_Plugin_User_Guide.docx to v2.0.0

| Field | Value |
|---|---|
| Workstream | Release |
| Phase | 6 |
| Priority | Must Have |
| SRD Requirements | EDMV2-110 |
| Size | L |
| Target Components | `plugins/edm-ai-development/EDM_Plugin_Presentation.pptx`; `plugins/edm-ai-development/EDM_Plugin_User_Guide.docx`; consistency cross-check against `plugins/edm-ai-development/CHANGELOG.md` (2.0.0 entry) and `plugins/edm-ai-development/README.md` |
| Dependencies | EDMV2-T127 (CHANGELOG 2.0.0 entry exists and is final, so docs can be made consistent with it) and the WS-A G16 README-update ticket (so README content is final). Effectively depends on all feature workstreams since the docs describe their behavior. Runs near the end of the initiative, before completion is declared. |

### Description
Both user-facing documents ship inside the plugin and must reflect v2.0.0 before the initiative is declared complete. The presentation is the at-a-glance overview; the user guide is the reference manual. Each must be re-versioned and have content added or revised to cover the full EDMV2 change set, and both must be consistent with the shipped `CHANGELOG.md` 2.0.0 entry and the updated `README.md`.

This is an L-sized ticket because it spans two binary office documents and a broad content surface (thirteen workstreams, five modes, the compliance gate, TDD mode, branch isolation, the new directory layout, the living pattern library, compaction resilience, the expanded CLI, new state subcommands, updated userConfig, the per-gate commit schedule, stale-lock remediation, and the staging cutover procedure). The two documents have different required content (the user guide additionally documents the new `edm-state` subcommands, userConfig keys/defaults, commit schedule, lock remediation, and cutover procedure that the presentation does not need to enumerate).

The completion of EDMV2 is blocked until both files are updated and version-consistent.

### Acceptance Criteria — Presentation (`EDM_Plugin_Presentation.pptx`)
- [ ] AC1: The title/cover slide version number reads `2.0.0` (no longer 1.3.0).
- [ ] AC2: The presentation includes at minimum one new or updated slide for EACH of the thirteen in-scope workstreams (WS-A, WS-B, WS-C, WS-D, WS-E, WS-F, WS-G, WS-H, WS-J, WS-K, WS-L, WS-M, WS-N) — WS-I excluded.
- [ ] AC3: A slide (or slides) covers the new adaptation modes: mini-SRD, IaC, data/ML, prototype, and the compliance review gate (Gate 3.5).
- [ ] AC4: A slide covers TDD implementation mode (EDMV2-106), the initiative branch isolation model (EDMV2-107), the new `SRD/{PRODUCT}/{PREFIX}__{DESCRIPTION}/` directory layout (WS-M), the living audit pattern library (WS-L), and compaction resilience (WS-N).
- [ ] AC5: A slide reflects the updated CLI subcommand set (the new `edm-state` subcommands and any new `/edm:*` flows).

### Acceptance Criteria — User Guide (`EDM_Plugin_User_Guide.docx`)
- [ ] AC6: The header/title version number reads `2.0.0`.
- [ ] AC7: The guide has a section for EACH new adaptation mode (mini-SRD, IaC, data/ML, prototype), the compliance gate, and TDD implementation mode, describing how to select and use each.
- [ ] AC8: The guide documents EACH new `edm-state` subcommand introduced in v2.0.0 (audit-round-start, record-partial-verdict, set-mode, set-parent, add-related, migrate-path, current-step, update-patterns, validate, and the state-backup behavior) with usage and an example.
- [ ] AC9: The guide documents the updated `userConfig` keys and their defaults (the five new keys from EDMV2-T129 plus the existing set).
- [ ] AC10: The guide documents the per-gate commit schedule (EDMV2-107), stale git lock remediation (EDMV2-108), and the staging-copy cutover procedure (EDMV2-109 / EDMV2-T133).
- [ ] AC11: The guide documents the new `SRD/{PRODUCT}/{PREFIX}__{DESCRIPTION}/` directory layout, the living pattern library, compaction resilience and the `## Resume Point`, and backward-compatibility guarantees for existing flat-layout initiatives.

### Acceptance Criteria — Consistency
- [ ] AC12: Both documents are consistent with the `CHANGELOG.md` 2.0.0 entry and the updated `README.md` — every mode, subcommand, and userConfig key named in one is reconcilable with the others (no contradictory defaults, command names, or version numbers); a reviewer cross-checks the three sources and records no discrepancy.

### Technical Notes
These are binary Office files (`.pptx` is a zipped OOXML package, `.docx` likewise). Edit them with an Office-compatible editor or a scripting library (e.g., python-pptx / python-docx) — do NOT hand-edit the raw XML unless necessary. Because they are binary, the ASCII/banned-content lint (WS-K) does not apply to them the way it does to markdown; instead verify content by opening the files. Source the authoritative subcommand list and userConfig defaults from the final `bin/edm-state` and `plugin.json` (post-cutover) so the docs do not drift. Use the CHANGELOG 2.0.0 entry as the content checklist.

### Out of Scope
- Re-versioning `README.md` / `CHANGELOG.md` (owned by EDMV2-T127 and the G16 README ticket; this ticket only ensures the two office docs are consistent with them).
- Redesigning the presentation template or restyling the guide beyond the required content/version updates.
- Producing translated or alternate-format copies of the docs.

### Verification
QC confirms PASS by opening both files and asserting: the cover/header versions read 2.0.0 (AC1, AC6); the presentation has a slide for each of the thirteen workstreams and the mode/feature slides (AC2-AC5); the user guide has a section per new mode, per new `edm-state` subcommand, the userConfig keys/defaults, the commit schedule, lock remediation, and cutover procedure, plus the directory-layout/pattern-library/compaction sections (AC7-AC11); and a tri-source consistency cross-check against CHANGELOG 2.0.0 and README finds no discrepancy (AC12). This AC set requires manual document review and is recorded as a PARTIAL-then-PASS verdict if any item must be runtime/visually confirmed. FAIL if either version is unbumped, if any workstream lacks a slide, if any new subcommand or mode is undocumented in the guide, or if the docs contradict the CHANGELOG/README.
