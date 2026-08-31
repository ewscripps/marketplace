# Lens L6: Documentation & Message Accuracy

Audit of the EDM Claude Code plugin v2.0.0 ("EDMV2"), cross-referencing documentation
(`CLAUDE.md`, `README.md`, `CHANGELOG.md`, `plugin.json`, skill/agent frontmatter, and
operator-facing `echo`/`die` messages in `bin/`) against the actual implemented code.

Scope per mandate: stale claims, mismatched signatures/parameter docs, error messages that
misstate what happened, documented-but-nonexistent features, existing-features-missing-from-docs,
wrong file paths, and missing "why" for non-obvious choices. Code-logic / wiring defects are out
of scope (L11) — but where a *doc* references something that does not match reality, the doc side
is reported here.

All paths are relative to `plugins/edm-ai-development/` unless absolute.

## Findings

| ID | Sev | Doc location vs Code | Issue |
|----|-----|----------------------|-------|
| L6-01 | P2 | `CLAUDE.md:403` vs `bin/edm-state:1935-1971` | `edm-state` subcommand list in the bin-scripts table omits ~18 real subcommands |
| L6-02 | P1 | `README.md:91-108` vs `CLAUDE.md:45-86` + `bin/edm-init` | README artifact-layout tree shows the *flat* legacy layout, not the v2.0 canonical product-scoped layout that `edm-init` actually creates |
| L6-03 | P2 | `README.md:103-106` vs `bin/edm-state:1560` + `CLAUDE.md:72-77` | README code-audit tree shows `code-audit/{YYYY-MM-DD}/`; real layout is `code-audit/pass-{N}_{YYYY-MM-DD}/` |
| L6-04 | P2 | `README.md:124` vs `bin/edm-state:684-689` | README claims "TaskCompleted records per-task durations" — it is an explicit reserved no-op that records nothing |
| L6-05 | P2 | `CLAUDE.md:430-440` vs `plugin.json:23-139` | `userConfig` reference lists only the 5 v1.0 keys; omits the 13 keys added in v1.1–v2.0 |
| L6-06 | P2 | `CLAUDE.md:387-394` (hooks table) + `397-405` (bin table) vs `hooks/hooks.json` + `bin/edm-lint-artifacts` | `PreToolUse: git commit` hook and the `edm-lint-artifacts` script exist but are undocumented in both tables |
| L6-07 | P2 | `README.md:139` vs filesystem | "See also" links `../EDM_PLUGIN_REMEDIATION_PLAN.md`; file does not exist at that path or the repo root |
| L6-08 | P2 | `CLAUDE.md:403` vs `bin/edm-state:1376-1401` | Subcommand list says `set-mode <PREFIX> <kind> <value>` sets only `mode`; actual kinds include `lifecycle_mode`, `compliance_enabled`, `implementation_mode` (documented elsewhere, not in this table) |
| L6-09 | P3 | `agents/edm-test-contract.md:4` vs body `:33-35` + `README.md:61` | Agent `description` says "OpenAPI/Swagger"; the agent body and README/CHANGELOG correctly include GraphQL too |
| L6-10 | P3 | `CLAUDE.md:225` + `bin/edm-state:193` vs `currentDate 2026-06-08` | "Verified May 2026" pricing-provenance note is one month stale (cosmetic; the constants themselves are correct) |
| L6-11 | P3 | `README.md:107` vs `CLAUDE.md:85` | README `.edm-state.json` tree comment omits the `mode` fields that CLAUDE.md lists ("gate approvals, phase timestamps, mode fields") |
| L6-12 | P3 | `CLAUDE.md:403` (`archive` entry) vs `bin/edm-state:799-842` | `archive` is listed with no mention that it now refuses when `code_audit_converged=false`; the convergence gate / `prototype` bypass is undocumented |

---

### L6-01 — `edm-state` subcommand list is badly incomplete (P2)

**Claim** (`CLAUDE.md:403`): the `bin/` helper-scripts table documents `edm-state`'s subcommands as:
`get`, `set`, `list`, `approve-gate`, `checkpoint-if-active`, `archive`, `phase-start`,
`phase-complete`, `record-task-duration`, `write-handoff`, `watch-impl`, `metrics-report`,
`audit-round-start`, `record-partial-verdict`, `set-mode`, `skip-phase`, `set-supersedes`,
`set-forked-from`.

**Reality** (`bin/edm-state:1935-1971` dispatch `case`): the script implements all of the above
**plus** these undocumented subcommands: `init`, `active-initiatives`, `migrate-path`,
`record-test-coverage`, `record-tests-added`, `get-coverage`, `srd-version`, `validate`,
`gate-check`, `branch-check`, `git-lock-check`, `current-step`, `session-start`, `resolve-dir`,
`set-parent`, `add-related`, `update-patterns`, `lint`. That is 18 real subcommands absent from
the list a contributor would treat as authoritative. (Several — `record-test-coverage`,
`record-tests-added`, `get-coverage`, `set-parent`, `add-related` — are documented in the separate
testing/state tables at `CLAUDE.md:327-333`, but `session-start`, `gate-check`, `validate`,
`branch-check`, `git-lock-check`, `current-step`, `resolve-dir`, `update-patterns`, `lint`,
`migrate-path`, `srd-version`, `active-initiatives`, and `init` appear in **no** subcommand
inventory.)

**Fix**: Replace the inline list at `CLAUDE.md:403` with a complete inventory (or a pointer to the
`edm-state` usage header at `bin/edm-state:4-39`, which *is* complete and authoritative), and add
the genuinely-undocumented commands (`gate-check`, `validate`, `branch-check`, `git-lock-check`,
`current-step`, `session-start`, `resolve-dir`, `update-patterns`, `lint`, `migrate-path`,
`srd-version`, `active-initiatives`) to a table somewhere in `CLAUDE.md`.

### L6-02 — README artifact-layout tree shows the obsolete flat layout (P1)

**Claim** (`README.md:91-108`): the "Project artifact layout" tree shows
```
SRD/
└── {PREFIX}/
    ├── planning.md
    ├── srd.md
    ...
```
i.e. the flat `SRD/{PREFIX}/` layout, with no product directory and no `__{DESCRIPTION}` slug.

**Reality** (`CLAUDE.md:45-86` "canonical layout (v2.0+)"; `bin/edm-init:47-53`): the canonical v2.0
layout is `SRD/{PRODUCT}/{PREFIX}__{DESCRIPTION}/`, and `edm-init` creates exactly that when
`--product`/`--description` are supplied. The README tree predates the WS-D "canonical homes" work
(EDMV2-38..43) and is missing the entire product-scoped structure plus the always-present
`explorers/`, `decisions.md`, `architecture.md`, `qc/`, `HANDOFF.md` slots that `edm-init` and the
phase flow scaffold.

This is **P1** rather than P2 because the README is the user-facing onboarding doc: a user who
follows it will expect their initiative under `SRD/{PREFIX}/` and may be confused when the plugin
(or a teammate using `--product`) writes to `SRD/{product}/{PREFIX}__{slug}/`, and because the tree
materially understates the artifact set teams will review in PRs.

**Fix**: Replace the README tree with the canonical product-scoped layout (a condensed version of
`CLAUDE.md:49-86`), noting that the flat layout still works for legacy initiatives.

### L6-03 — README code-audit subdirectory name is wrong (P2)

**Claim** (`README.md:103-106`):
```
├── code-audit/
│   └── {YYYY-MM-DD}/
│       ├── lens-L1.md … lens-L11.md
│       └── REMEDIATION.md
```

**Reality** (`CLAUDE.md:72-77`: `pass-{N}_{YYYY-MM-DD}/`; confirmed by `bin/edm-state:1560`, which
globs `"${_dir}/code-audit"/pass-*/REMEDIATION.md` to locate the latest remediation report). The
per-round directory is named `pass-{N}_{YYYY-MM-DD}`, not `{YYYY-MM-DD}`. The README also omits the
persistent `findings-ledger.md` and `lenses-run.txt` files that `CLAUDE.md:73,76` document.

**Fix**: Update the README tree to `code-audit/pass-{N}_{YYYY-MM-DD}/` and add `findings-ledger.md`.

### L6-04 — README claims TaskCompleted records durations; it is a no-op (P2)

**Claim** (`README.md:124`): "...SubagentStop auto-fires `edm-qc-auditor` after every implementer;
**TaskCompleted records per-task durations**."

**Reality** (`bin/edm-state:684-689`, `cmd_record_task_duration`): the function is an explicit
reserved no-op — "TaskCompleted hook wires here but accumulation is not yet implemented... no
durations are recorded." `CLAUDE.md:393` and `CHANGELOG.md:206` both correctly describe it as
"reserved / not yet implemented." Only the README states it as a working feature, which overstates
plugin capability.

**Fix**: Change `README.md:124` to "TaskCompleted is reserved (per-task duration accumulation not
yet implemented)" to match `CLAUDE.md`/`CHANGELOG`.

### L6-05 — CLAUDE.md userConfig reference omits 13 of 18 keys (P2)

**Claim** (`CLAUDE.md:430-440`): the "`userConfig` reference" section lists exactly five keys —
`srd_root`, `srd_filename`, `ticket_pack_dirname`, `prefix_format_hint`, `commit_state_file` — and
says "See `plugin.json` for the live schema."

**Reality** (`plugin.json:23-139`): the live schema defines 18 keys. Missing from the CLAUDE.md
list: `human_hourly_rate_usd`, `jira_project_key`, `jira_mcp_namespace`, `mode`,
`compliance_enabled`, `qc_shard_threshold`, `implementation_mode`, `coverage_target_unit_pct`,
`coverage_target_component_pct`, `coverage_target_integration_pct`,
`coverage_target_e2e_critical_paths_pct`, `test_framework_unit_override`,
`test_framework_component_override`, `test_framework_e2e_override`. The CHANGELOG (`:21-29`, `:93-95`)
documents these additions, so the CLAUDE.md reference is simply stale at v2.0.

(Note: the coverage-target keys *are* tabulated separately at `CLAUDE.md:273-283`, but the section
that purports to be the canonical `userConfig` reference does not include or cross-link them, and
the mode-family keys appear in no userConfig table at all.)

**Fix**: Either complete the key list at `CLAUDE.md:430-440` or replace it with an explicit "the
`plugin.json` `userConfig` block is the single source of truth; current keys: …" enumeration.

### L6-06 — `PreToolUse` commit-lint hook and `edm-lint-artifacts` are undocumented (P2)

**Claim**: `CLAUDE.md:387-394` (hooks table) lists five events — `SessionStart`,
`UserPromptExpansion`, `Stop`/`PreCompact`, `SubagentStop`, `TaskCompleted`. The `bin/` table
(`CLAUDE.md:401-405`) lists three scripts — `edm-state`, `edm-init`, `edm-validate-prefix`.

**Reality**: `hooks/hooks.json` defines a **sixth** hook, `PreToolUse` matching `git commit`, which
runs `edm-lint-artifacts` against the active initiative and **blocks the commit** on violations
(`"[EDM] Fix artifact violations before committing"`). The script `bin/edm-lint-artifacts` exists
(attribution / unicode / leaked-tool-tag scanning) and is also reachable via `edm-state lint`. Both
the hook and the script are absent from the contributor docs, so a contributor reading CLAUDE.md
would not know a commit-blocking lint gate is active — a non-obvious behavior that the "do not
disable them in normal operation" guidance should cover.

**Fix**: Add a `PreToolUse | git commit` row to the hooks table (`CLAUDE.md:387-394`) and an
`edm-lint-artifacts` row to the bin-scripts table (`CLAUDE.md:401-405`).

### L6-07 — README links a remediation-plan file that does not exist (P2)

**Claim** (`README.md:139`): "The full remediation plan that produced this plugin:
`../EDM_PLUGIN_REMEDIATION_PLAN.md`." (Also referenced at `CLAUDE.md` "Related documentation" is a
generic pointer, but the specific path is only in README.)

**Reality**: no `EDM_PLUGIN_REMEDIATION_PLAN.md` exists at `plugins/EDM_PLUGIN_REMEDIATION_PLAN.md`
(the `../` target) nor at the repo root. The link is dead.

**Fix**: Remove the line or repoint it to the live planning artifacts under `SRD/EDMV2/`.

### L6-08 — `set-mode` documented as mode-only in the subcommand list (P2)

**Claim** (`CLAUDE.md:403`): the subcommand list shows `set-mode` with no argument signature; a
reader could infer it only sets the adaptation `mode`.

**Reality** (`bin/edm-state:1362-1401`, `cmd_set_mode`): `set-mode <PREFIX> <kind> <value>` accepts
four `kind` values — `mode`, `lifecycle_mode`, `compliance_enabled`, `implementation_mode` — each
with its own validated value set. This *is* correctly described at `CLAUDE.md:421` ("Set
independently via `edm-state set-mode <PREFIX> mode|lifecycle_mode <value>`") and in the script
usage header (`:31`), so the gap is only in the line-403 inventory, which is why this is P2 and
overlaps with L6-01.

**Fix**: Subsumed by the L6-01 fix — give `set-mode` its full `<PREFIX> <kind> <value>` signature in
whatever table replaces line 403.

### L6-09 — `edm-test-contract` description omits GraphQL (P3)

**Claim** (`agents/edm-test-contract.md:4`, the agent `description`): "Writes API contract tests
driven by the project's **OpenAPI/Swagger** specification or inferred from route handlers."

**Reality** (same file body, `:17`, `:33-35`): the agent explicitly detects and handles **GraphQL**
schemas (`schema.graphql`, `schema.gql`) in addition to OpenAPI and Swagger. `README.md:61` and
`CHANGELOG.md:75` describe it as "OpenAPI/GraphQL," matching the body. Only the one-line description
is narrower than the agent's real capability.

**Fix**: Change the description to "OpenAPI/Swagger/GraphQL" for parity with the body and README.

### L6-10 — "Verified May 2026" pricing note is stale-dated (P3)

**Claim** (`CLAUDE.md:225`, `bin/edm-state:193`): pricing constants "Verified May 2026."

**Reality**: current date is 2026-06-08; the v2.0.0 CHANGELOG is dated 2026-06-08. The constants
themselves match the code defaults exactly (`CLAUDE.md:221-223` == `bin/edm-state:204-223`), so this
is purely a provenance-freshness nit, not a numeric error.

**Fix**: Bump the "Verified" month when the v2.0.0 release is cut, or drop the month and keep just
the source link.

### L6-11 — README state-file tree comment omits mode fields (P3)

**Claim** (`README.md:107`): `.edm-state.json ← gate approvals, phase timestamps (committed by
default)`.

**Reality** (`CLAUDE.md:85`): `.edm-state.json ← gate approvals, phase timestamps, mode fields
(committed by default)`. The state file written by `cmd_init` (`bin/edm-state:452-483`) includes
`mode`, `lifecycle_mode`, `compliance_enabled`, `implementation_mode`, etc. Minor under-description.

**Fix**: Add "mode fields" to the README comment to match CLAUDE.md.

### L6-12 — `archive` convergence gate is undocumented (P3 / missing-why)

**Claim** (`CLAUDE.md:403`): `archive` is listed among `edm-state` subcommands with no behavioral
note; the prose at `CLAUDE.md:25-37` describes archiving only as "mark initiative complete."

**Reality** (`bin/edm-state:799-842`, `cmd_archive`): `archive` now **refuses** with
`"archive refused: code_audit_converged=false; run /edm:code-audit ${prefix} and ensure
REMEDIATION.md convergence before archiving"` when `code_audit_converged=false` and a
`product_name` is set, warns-and-proceeds for `prototype` mode and for legacy state lacking the
field. This is a non-obvious safety gate a contributor or operator would want documented (and the
error message references `/edm:code-audit` and `REMEDIATION.md`, both of which are real). The
"why" — prototype bypass, legacy-state leniency — is captured only in code comments.

**Fix**: Add a one-line note to the `archive` entry (or the mode-fields section) explaining the
code-audit-convergence precondition and its `prototype`/legacy bypasses.

---

## Noted / Not Actionable

- **`record-test-coverage` signature is accurate.** `CLAUDE.md:329` documents
  `record-test-coverage <PREFIX> <layer> <pct> [<epic>]`; `cmd_record_test_coverage`
  (`bin/edm-state:691-713`) and the usage header (`:14`) match exactly, including the optional
  `[<epic>]` per-epic arg and its `coverage_by_epic` target. CHANGELOG `:38` agrees. No finding.
- **State-schema fields are all real.** Every field the mandate asked about — `coverage_by_epic`,
  `parent_prefix`, `related_prefixes`, `supersedes`, `forked_from`, `lifecycle_mode`,
  `implementation_mode` — is written by `cmd_init` (`bin/edm-state:466-481`) and documented
  (`CLAUDE.md:296-320`, `407-419`). The docs and the init template agree. No finding.
- **Pricing constants match.** `CLAUDE.md:221-223` (Opus $5/$25/$0.50/$6.25/$10.00; Sonnet
  $3/$15/$0.30/$3.75/$6.00; Haiku $1/$5/$0.10/$1.25/$2.00) are identical to the code defaults in
  `compute_cost_usd` (`bin/edm-state:204-223`). No discrepancy.
- **Model/effort tables are consistent.** `README.md:43-64`, `CLAUDE.md:195-203,254-266`, and the
  actual skill/agent frontmatter agree: planning/audit/QC + lenses on `opus/max`; the two writers on
  `opus/high`; implementers + test-writers on `sonnet/high`; metrics + push-jira on `sonnet/high`.
  Agent colors match the CLAUDE.md semantic scheme. No finding.
- **No stale `edm-ai-development-staging/` references.** Grep over all `*.md`/`*.json` in the plugin
  found zero references to the old staging directory. The cutover left the docs clean.
- **Model version labels ("Opus 4.7", "Sonnet 4.6", "Haiku 4.5").** These are doc-only labels;
  `compute_cost_usd` matches on the `*opus*`/`*sonnet*`/`*haiku*` substrings, so the version numbers
  never feed logic. CLAUDE.md and CHANGELOG use the same labels — internally consistent. Pre-existing
  style; not actionable for this lens.
- **Gate-enforcement error messages are accurate.** `cmd_gate_check` (`bin/edm-state:1142-1147`) and
  the `hooks.json` UserPromptExpansion prompts name the correct required gate per command (srd→1,
  tickets→2, implement→3) and reference real commands (`/edm:orchestrator`). Verified against the
  `gate_check` mapping. No finding.
- **`disable-model-invocation: true` claim.** `README.md:39` says all phase skills set it; confirmed
  present in every `skills/*/SKILL.md` frontmatter. No finding.
- **`/edm:test` "10 specialist agents" claim** (`README.md:130`): planner + scaffold + 7 writers +
  coverage auditor = 10. Matches the agent inventory (`CLAUDE.md:254-266`). Accurate.
- **`qc_shard_threshold` not seeded by `cmd_init`.** It is a typed-set field (`bin/edm-state:422`)
  and a real `plugin.json` userConfig key, but `cmd_init` does not write it into new state. Whether
  that is a defect is a wiring/logic question (L11); the *documentation* (CHANGELOG `:27`,
  `plugin.json:85-90`) accurately describes it as a userConfig key, so there is no L6 doc finding.
