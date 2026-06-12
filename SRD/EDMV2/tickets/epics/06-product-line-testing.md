# Epic 6 — Product-Line Linkage (WS-G) + Multi-Stack Testing (WS-H)

Generated From: srd.md v1.0.7

This epic covers two adjacent workstreams that both build on the foundation laid by Epic 2 (WS-M directory structure + global prefix uniqueness, WS-N compaction, WS-J state integrity):

- **WS-G (Product-Line / Multi-Initiative Linkage, EDMV2-57 through EDMV2-61, SRD §4.7)** — lets an initiative declare its parent product-line initiative and related siblings using bare, globally unique PREFIX strings, surfaces those links in the SRD and HANDOFF, supports multiple custom-prefixed ticket packs in one directory, and references a shared product baseline.
- **WS-H (Multi-Stack / Multi-Epic Test Support, EDMV2-62 through EDMV2-65, SRD §4.8)** — makes the test-plan and coverage layers per-epic / per-stack so a multi-stack initiative (e.g., a Python epic and a Nuxt epic) gets correct, independent plans and coverage instead of a single whole-initiative assumption.

Tickets: **EDMV2-T101 through EDMV2-T112** (12 tickets covering 9 requirements).

Dependency note: WS-G depends on Epic 2 WS-M global prefix uniqueness (EDMV2-85 / EDMV2-87, ticket range T37–T45) because bare-prefix resolution is only unambiguous when prefixes are globally unique. WS-H depends on the WS-G linkage fields (for related-stack resolution) and on the Epic 2 state-derived path construction (EDMV2-88) so per-epic artifact paths resolve under the new layout.

---

## EDMV2-T101: Add parent_prefix and related_prefixes state fields with bare-prefix resolution

| Field | Value |
|---|---|
| Workstream | WS-G |
| SRD Requirements | EDMV2-57 |
| Priority | Must |
| Size | S |
| Target Components | `bin/edm-state` — extend `cmd_init` default state object to include `parent_prefix` (`""`) and `related_prefixes` ([]); consume the `initiative_dir_for()` function from T37 (do not create a new resolver) for the `resolve-dir <PREFIX>` helper that resolves a bare prefix to its initiative directory under the WS-M layout; document fields in `CLAUDE.md` state-schema section |
| Dependencies | EDMV2-T37 (WS-M new directory layout, provides `initiative_dir_for()`), EDMV2-T39 (WS-M global prefix uniqueness validation), EDMV2-T42 (WS-M state-derived path construction) |

### Description
The state schema must gain a `parent_prefix` string field and a `related_prefixes` array so an initiative can declare its parent product-line initiative and its sibling initiatives. Because PREFIX is globally unique across all products (guaranteed by EDMV2-87 / WS-M), these fields store bare prefix strings such as `"AUTH01"` — no `{PRODUCT}/{PREFIX}` qualification is needed to resolve them unambiguously.

Directory resolution is provided by consuming the `initiative_dir_for()` function already established in T37 (do not create a new resolver). This function is the shared primitive the `set-parent` / `add-related` subcommands (T102) and the SRD/HANDOFF rendering (T103) depend on. All schema additions must be additive and defaulted so existing flat-layout and pre-existing state files (C-4 backward compatibility) keep working: `parent_prefix` defaults to `""`, `related_prefixes` defaults to `[]`.

### Acceptance Criteria
1. `edm-state init <PREFIX>` writes a state object containing `parent_prefix: ""` and `related_prefixes: []`.
2. A pre-existing state file lacking both fields is treated as `parent_prefix = ""` and `related_prefixes = []` by every read path (no error, no migration required).
3. A fixture `.edm-state.json` lacking `parent_prefix` and `related_prefixes` is read without error; `parent_prefix` resolves to `""` and `related_prefixes` to `[]` via jq `//` guards.
4. A resolver (`edm-state resolve-dir <PREFIX>` or equivalent internal function) returns the absolute or `SRD_ROOT`-relative directory for a bare prefix that exists under any `SRD/{PRODUCT}/` subdirectory.
5. The resolver returns a non-zero exit and a clear "no initiative for prefix X" message when the bare prefix matches no initiative directory.
6. Given global prefix uniqueness (EDMV2-87), the resolver never returns more than one directory for a bare prefix; if two are somehow found it reports an ambiguity error rather than picking arbitrarily.
7. Both fields are documented in `CLAUDE.md` (state-schema / artifact section) as additive, defaulted, and storing bare prefixes.
8. Setting `parent_prefix` to a value and reading state back yields a JSON string (not an object), and `related_prefixes` remains a JSON array.
9. `claude plugin validate` passes after the change.

### Verification
QC confirms PASS by: (a) running `edm-state init TESTPL` in a sandbox and asserting `jq '.parent_prefix, .related_prefixes' .edm-state.json` returns `""` and `[]`; (b) creating two initiatives under different products, then resolving each bare prefix to its directory via `initiative_dir_for()` and asserting the path matches the WS-M layout; (c) loading a hand-crafted legacy state file with neither field and confirming reads succeed with the documented defaults (`parent_prefix` resolves to `""` and `related_prefixes` to `[]` via `jq` `//` guards).

---

## EDMV2-T102: Add set-parent and add-related edm-state subcommands

| Field | Value |
|---|---|
| Workstream | WS-G |
| SRD Requirements | EDMV2-58 |
| Priority | Must |
| Size | S |
| Target Components | `bin/edm-state` — new `cmd_set_parent` and `cmd_add_related` functions; new `set-parent` and `add-related` cases in the dispatch `case` block (`bin/edm-state:777-801`); usage header (`bin/edm-state:3-20`); `CLAUDE.md` subcommand table |
| Dependencies | EDMV2-T101 |

### Description
`bin/edm-state` must provide `set-parent <PREFIX> <PARENT>` and `add-related <PREFIX> <RELATED>` to manage the linkage fields added in T101. `set-parent` overwrites `parent_prefix` with the given bare prefix. `add-related` appends to `related_prefixes` only if the prefix is not already present, so repeated calls are idempotent.

Both subcommands must validate that the supplied parent/related prefix actually resolves to an existing initiative (using the T101 resolver) and refuse to record a dangling link, with an actionable error. Both must refresh HANDOFF.md after a successful write (consistent with how `srd-version`, `approve-gate`, and `phase-complete` call `write_handoff_internal`), so the Related Initiatives section (T103) stays current.

### Acceptance Criteria
1. `edm-state set-parent CHILD PARENT` sets `parent_prefix` to `"PARENT"` in CHILD's state file.
2. Calling `set-parent` a second time with a different parent overwrites the prior value (not appends).
3. `edm-state add-related CHILD SIBLING` appends `"SIBLING"` to `related_prefixes`.
4. Calling `add-related CHILD SIBLING` twice leaves `related_prefixes` with exactly one `"SIBLING"` entry (idempotent).
5. `set-parent` / `add-related` against a prefix with the wrong argument count exits non-zero with a usage message.
6. Pointing either subcommand at a non-existent parent/related prefix is refused with a "no initiative for prefix X" error and the state file is left unchanged.
7. After a successful `set-parent` or `add-related`, HANDOFF.md is regenerated (its `Last updated` timestamp advances).
8. Both subcommands appear in the `bin/edm-state` usage header and the `CLAUDE.md` subcommand table.
9. `claude plugin validate` passes.

### Verification
QC confirms PASS by running each subcommand in a sandbox against a two-initiative fixture: assert the field values via `jq`, assert idempotency by running `add-related` twice and counting array length, assert the dangling-link refusal leaves the file byte-identical, and assert HANDOFF.md's timestamp changed after a successful call.

---

## EDMV2-T103: Surface parent/related linkage in SRD and HANDOFF

| Field | Value |
|---|---|
| Workstream | WS-G |
| SRD Requirements | EDMV2-59 |
| Priority | Must |
| Size | S |
| Target Components | `bin/edm-state` — `write_handoff_internal` (`bin/edm-state:631-766`) adds a `## Related Initiatives` section rendered from `parent_prefix` + `related_prefixes`; `skills/srd/SKILL.md` — instruct `edm-srd-writer` / SRD skill to emit a "Related Initiatives" section in `srd.md` header when linkage exists; `agents/edm-srd-writer.md` — note the section |
| Dependencies | EDMV2-T101, EDMV2-T102 |

### Description
The SRD and HANDOFF must surface parent/related linkage so cross-references are not re-derived from scratch each time. HANDOFF.md gains a `## Related Initiatives` section listing the parent (if set) and each related sibling, with each resolved to its initiative directory path (via the T101 resolver) so a reader can navigate to it. The SRD skill must emit an equivalent "Related Initiatives" section in `srd.md` when linkage exists.

When no linkage is set (the common case and the backward-compatible default), the HANDOFF section either renders a clear "(none)" placeholder or is omitted entirely — but it must never break the existing HANDOFF layout or the preserved `## Notes` section. The rendering must be ASCII-only (consistent with WS-K / EDMV2-21, no Unicode markers).

### Acceptance Criteria
1. An initiative with `parent_prefix` set renders a `## Related Initiatives` section in HANDOFF.md naming the parent prefix and its resolved directory path.
2. An initiative with one or more `related_prefixes` renders each sibling prefix and its resolved directory in the same section.
3. An initiative with neither set renders either an explicit "(none)" line or omits the section, and the rest of HANDOFF.md (status, gates, artifact checklist, decisions, notes) is unchanged.
4. The SRD skill produces a "Related Initiatives" section in `srd.md` when linkage exists.
5. The Related Initiatives rendering contains only ASCII characters (`grep -P '[^\x00-\x7F]'` over the section returns nothing).
6. The pre-existing user-editable `## Notes` section in HANDOFF.md is still preserved across the re-write.
7. A related prefix that no longer resolves is shown with an explicit "(unresolved)" marker rather than a broken path.
8. `claude plugin validate` passes.

### Verification
QC confirms PASS by: setting parent + two related links on a fixture, running `edm-state write-handoff`, and asserting the rendered section names all three with valid paths; running the SRD skill in a sandbox and confirming the `srd.md` section appears; running the ASCII check; and confirming a no-linkage initiative produces an unbroken HANDOFF.

---

## EDMV2-T104: Support multiple custom-prefix ticket packs in one initiative directory

| Field | Value |
|---|---|
| Workstream | WS-G |
| SRD Requirements | EDMV2-60 |
| Priority | Should |
| Size | M |
| Target Components | `bin/edm-state` — path resolution for ticket packs must accept a per-pack prefix override and a per-pack dirname (extend the hardcoded `${TICKET_PACK_DIRNAME}/README.md` references at `bin/edm-state:336`, `:707-708`, and HANDOFF artifact checklist `:754-755`); `skills/tickets/SKILL.md` and `skills/audit-tickets/SKILL.md` — accept an optional pack-name/prefix argument and recognize sibling packs; `CLAUDE.md` artifact-layout section — document the multi-pack convention |
| Dependencies | EDMV2-T101, EDMV2-T42 (WS-M state-derived path construction) |

### Description
The plugin must support multiple ticket-pack subdirectories within one initiative directory, each using a distinct ticket prefix per pack — the pattern observed in the corpus as `tickets-gui/` + `tickets-platform-expansion/`. Today the ticket-pack path is a single hardcoded `${TICKET_PACK_DIRNAME}` with one prefix; this must generalize so two packs coexist and both are recognized by the tickets, audit-tickets, and HANDOFF artifact-checklist logic.

Each pack carries its own prefix override that flows into the ticket IDs (`{PACK_PREFIX}-T{NN}`) and the pack's `README.md` version-linkage header. The default single-pack behavior (one `tickets/` dir using the initiative PREFIX) must remain unchanged when no override is supplied, to preserve backward compatibility. State should record the set of known ticket-pack directories so HANDOFF and audit flows can enumerate them rather than assuming one.

### Acceptance Criteria
1. Two ticket-pack directories (e.g., `tickets-gui/` and `tickets-platform/`) can coexist in one initiative directory and both are enumerated by `edm-state` / the tickets flow.
2. Each pack uses its own distinct ticket prefix; ticket IDs in pack A do not collide with pack B.
3. Each pack's `README.md` carries the `Generated From: srd.md v{srd_version}` version-linkage header (WS-K / version alignment preserved per pack).
4. With no pack override supplied, the plugin produces exactly one `tickets/` directory using the initiative PREFIX (unchanged v1.x behavior).
5. The HANDOFF artifact checklist lists each ticket pack's `README.md` rather than assuming a single `tickets/README.md`.
6. `audit-tickets` can be pointed at a specific pack and audits only that pack's epics.
7. Drift-hash recording (`record_artifact_hash` for `tickets`) tracks each pack independently, so editing pack A does not mask drift in pack B.
8. The multi-pack convention and the per-pack prefix override are documented in `CLAUDE.md`.
9. `claude plugin validate` passes.

### Verification
QC confirms PASS by creating a fixture initiative with two packs of distinct prefixes, asserting both READMEs carry the version header, running `audit-tickets` against each pack and confirming it audits only that pack, and confirming a single-pack initiative with no override produces the unchanged default layout.

---

## EDMV2-T105: Support shared product baseline reference document

| Field | Value |
|---|---|
| Workstream | WS-G |
| SRD Requirements | EDMV2-61 |
| Priority | Could |
| Size | S |
| Target Components | `bin/edm-init` — detect and note an existing `SRD/{PRODUCT}/BASELINE.md` at scaffold time and print its path; `skills/srd/SKILL.md` — instruct the SRD writer to reference `SRD/{PRODUCT}/BASELINE.md` when present; `CLAUDE.md` — document the canonical baseline path at the product-directory level |
| Dependencies | EDMV2-T37 (WS-M new directory layout), EDMV2-T38 (WS-M `--product` scaffold) |

### Description
A product-level shared-baseline document should be supported so baseline facts (the canonical product description, shared constraints, shared architecture context) are stated once and referenced by member initiatives rather than copied into each SRD. The canonical path is `SRD/{PRODUCT}/BASELINE.md`, using the product directory that WS-M (EDMV2-85 / EDMV2-86) already creates — no additional directory structure is introduced.

`edm-init` must detect an existing `BASELINE.md` in the product directory at scaffold time and print its path in the next-step output, so the operator knows it exists and can reference it. The SRD skill must, when a baseline exists for the product, instruct the writer to reference it rather than restate baseline facts. This is a Could-priority enhancement; absence of a baseline must be a clean no-op.

### Acceptance Criteria
1. The canonical baseline path `SRD/{PRODUCT}/BASELINE.md` is documented in `CLAUDE.md` as a product-level (not per-initiative) artifact.
2. When `SRD/{PRODUCT}/BASELINE.md` exists, `edm-init --product {PRODUCT} ...` prints a line noting the baseline path in its next-step output.
3. When no baseline exists, `edm-init` proceeds normally with no error and no baseline reference (clean no-op).
4. The SRD skill, when a baseline exists for the initiative's product, instructs the writer to reference `SRD/{PRODUCT}/BASELINE.md` instead of restating baseline facts.
5. A member initiative's `srd.md` can reference the baseline by its documented relative path and the reference resolves to a real file.
6. No new directory beyond the WS-M product subdirectory is required to hold the baseline.
7. `claude plugin validate` passes.

### Verification
QC confirms PASS by placing a `BASELINE.md` under a product directory, running `edm-init` for a second initiative in that product, and asserting the next-step output names the baseline path; then asserting that the same run with no baseline present produces no baseline line and no error.

---

## EDMV2-T108: Per-epic stack auto-detection in edm-test-planner

| Field | Value |
|---|---|
| Workstream | WS-H |
| SRD Requirements | EDMV2-64 |
| Priority | Must |
| Size | M |
| Target Components | `agents/edm-test-planner.md` — Step 1 stack detection (lines 37-70) must run per epic over each epic's Target Components rather than once for the whole initiative; record per-epic `test_frameworks_detected` (Step 6, lines 178-185) |
| Dependencies | EDMV2-T101 |

### Description
`edm-test-planner` must auto-detect the stack per epic rather than assuming a single stack for the whole initiative. Today Step 1 detects one stack from project-level signals (`package.json`, `pyproject.toml`, `go.mod`, etc.). It must instead, for each epic, look at the epic's own Target Components and the directories they live in, detecting the framework set for that subtree.

The planner reports the detected stack for each epic and records `test_frameworks_detected` keyed by epic (additive). When all epics resolve to the same stack, the result collapses gracefully to the existing single-stack output. The per-epic detection is the input that T106 (per-epic plans) and T107 (per-epic coverage) consume, so this ticket is sequenced before the planning/coverage emission it feeds — but it is delivered as the detection logic change within the planner agent.

### Acceptance Criteria
1. For a multi-stack initiative, the planner reports the correct framework set for each epic based on that epic's Target Components and their directories.
2. A Python epic is detected as pytest-based even when the repository root also contains a `package.json` for a separate JS epic.
3. A Nuxt/Vue epic is detected with component/composable/e2e/a11y layers active even when another epic is backend-only.
4. The framework override userConfig keys (`test_framework_*_override`) still apply, taking precedence over per-epic auto-detection where set.
5. `test_frameworks_detected` is recorded in state keyed by epic (additive structure) and round-trips via `jq`.
6. When all epics share one stack, output collapses to the existing single-stack detection result (backward compatible).
7. An epic whose Target Components match no known stack signal is reported with an explicit "stack undetected" note rather than silently defaulting.
8. `claude plugin validate` passes.

### Verification
QC confirms PASS by running the planner against a fixture with a Python epic and a Vue epic in distinct directories and asserting each epic's reported stack and state entry is correct; asserting an override pins a layer; and confirming a single-stack fixture collapses to the unchanged result.

---

## EDMV2-T106: Per-epic / per-stack test plans in the test-plan layer

| Field | Value |
|---|---|
| Workstream | WS-H |
| SRD Requirements | EDMV2-62 |
| Priority | Must |
| Size | M |
| Target Components | `agents/edm-test-planner.md` — emit `test-plan-{epic}.md` per epic alongside the main `test-plan.md` (Step 5 write section, agent lines 104-176); `skills/test-plan/SKILL.md` — orchestrate per-epic planning, optionally spawning one planner sub-agent per epic; `CLAUDE.md` testing-layer section — document the per-epic plan filename convention |
| Dependencies | EDMV2-T101, EDMV2-T42 (WS-M state-derived path construction), EDMV2-T108 (per-epic stack auto-detection) |

### Description
The test-plan layer must support per-epic (per-stack) test plans rather than a single `test-plan.md`, so a Python epic and a Nuxt epic each get a correct plan instead of one stack's plan wrongly marking the other's layers "N/A out-of-tree." For each epic in the ticket pack, the planner produces a `test-plan-{epic}.md` file alongside a top-level `test-plan.md` that indexes the per-epic plans.

Each per-epic plan carries that epic's own stack-detection table, coverage targets, per-ticket scope, AC coverage map, and writer task assignments — scoped to the files owned by that epic. The top-level `test-plan.md` becomes an index/summary that lists each epic, its detected stack, and a link to its per-epic plan. Single-stack initiatives must still work: when all epics share one stack, a single `test-plan.md` (with an empty or trivial per-epic split) remains valid so existing behavior is preserved.

### Acceptance Criteria
1. For a two-stack initiative (e.g., one Python epic, one Nuxt epic), the planner writes `test-plan-{epic-a}.md` and `test-plan-{epic-b}.md` plus a top-level `test-plan.md` index.
2. Each per-epic plan's Stack Detection table reflects only that epic's stack; the Python epic's plan does not mark Nuxt-only layers (component, a11y) N/A on account of the Python files, and vice versa.
3. Neither epic's plan wrongly marks the other epic's in-scope layers as "N/A out-of-tree."
4. The top-level `test-plan.md` lists each epic with its detected stack and links to the corresponding per-epic plan.
5. Per-epic plan paths are derived from state (WS-M layout) under the correct initiative directory.
6. A single-stack initiative still produces a valid `test-plan.md` and does not error on the per-epic split (backward compatible).
7. Each per-epic plan retains all sections the v1.x `test-plan.md` had (stack table, coverage targets, per-ticket scope, AC coverage map, infrastructure gaps, writer assignments) scoped to the epic.
8. `claude plugin validate` passes.

### Verification
QC confirms PASS by running the planner against a fixture two-stack ticket pack and asserting two per-epic plan files plus an index exist, that each per-epic stack table is correct for its epic, and that neither marks the other's layers N/A; then running it against a single-stack fixture and confirming the unchanged single-plan behavior.

---

## EDMV2-T107: Per-epic coverage reporting in the coverage layer

| Field | Value |
|---|---|
| Workstream | WS-H |
| SRD Requirements | EDMV2-63 |
| Priority | Must |
| Size | M |
| Target Components | `agents/edm-test-coverage-auditor.md` — produce `test-coverage-{epic}.md` per epic against each epic's own targets (agent process steps, lines 29-40+); `skills/test-coverage/SKILL.md` — orchestrate per-epic coverage; `bin/edm-state` — extend `cmd_record_test_coverage` / `coverage_by_layer` to key coverage by epic (additive, e.g., `coverage_by_epic[{epic}][{layer}]`); `CLAUDE.md` testing-layer section |
| Dependencies | EDMV2-T106 |

### Description
Coverage reporting must support per-epic coverage so each stack's coverage is reported against its own targets, consuming the per-epic plans from T106. The coverage auditor produces `test-coverage-{epic}.md` per epic, each cross-referencing that epic's AC map against the tests actually written, and reports coverage figures per layer per epic rather than a single whole-initiative figure.

State must record coverage keyed by epic (additive to the existing `coverage_by_layer`) so metrics and HANDOFF can report each epic's coverage separately without losing the legacy whole-initiative summary for single-stack initiatives. The PASS/PARTIAL/FAIL verdict vocabulary and severity scale (shared with WS-C / EDMV2-13) apply per epic. Single-stack initiatives must continue to produce the existing `test-coverage.md` behavior.

### Acceptance Criteria
1. For a two-stack initiative, the coverage auditor writes `test-coverage-{epic-a}.md` and `test-coverage-{epic-b}.md`.
2. Each per-epic coverage report shows coverage figures per layer measured against that epic's own targets, not a blended whole-initiative number.
3. Per-epic coverage figures are recorded in state under an additive epic-keyed structure and survive a re-read.
4. The existing `coverage_by_layer` (whole-initiative) path still works for single-stack initiatives (backward compatible).
5. `metrics-report` / `get-coverage` surfaces per-epic coverage when present and the whole-initiative figure when not.
6. Each per-epic report cross-references the epic's AC map to planned and actual tests with PASS/PARTIAL/FAIL verdicts using the unified severity vocabulary.
7. A gap in epic A's coverage is reported in epic A's report only and does not contaminate epic B's figures.
8. `claude plugin validate` passes.

### Verification
QC confirms PASS by running the coverage auditor on a fixture with per-epic plans, asserting one coverage report per epic with independent figures, asserting state holds epic-keyed coverage via `jq`, and confirming a single-stack initiative still yields the legacy `test-coverage.md`.

---

## EDMV2-T109: Remove stale N/A coverage artifact behavior (absence is authoritative)

| Field | Value |
|---|---|
| Workstream | WS-H |
| SRD Requirements | EDMV2-65 |
| Priority | Should |
| Size | S |
| Target Components | `agents/edm-test-coverage-auditor.md` — when a layer/epic is skipped, do not write or carry forward an "N/A" placeholder coverage artifact; treat absence as authoritative; `skills/test-coverage/SKILL.md` — on re-run after a plan correction, remove any stale per-epic coverage file whose epic no longer applies; `agents/edm-test-planner.md` — N/A determination per epic is recomputed each run, never inherited |
| Dependencies | EDMV2-T106, EDMV2-T107 |

### Description
The coverage layer must not carry forward a stale "N/A" designation for an epic or layer that a superseding plan corrected. Today an N/A mark, once written, can persist across re-runs and misrepresent a corrected scope. The fix makes absence authoritative: when a layer is skipped, no placeholder file or stale N/A row is written; when a plan correction changes an epic's applicable layers or removes an epic, the coverage re-run reflects the corrected scope rather than the original N/A.

Concretely, the coverage auditor recomputes applicability each run from the current per-epic plan (T106) and does not inherit a prior N/A row. On re-run after a plan correction, any per-epic coverage file or row that no longer corresponds to a current epic/layer is removed, not left as a stale artifact. This is the WS-H counterpart to clean state hygiene and must not delete coverage for epics/layers that are still valid.

### Acceptance Criteria
1. When a layer is skipped for an epic, no placeholder coverage file or "N/A" row is written for that layer.
2. After a plan correction that makes a previously-N/A layer applicable, the next coverage run reports real coverage for that layer (not the stale N/A).
3. After a plan correction that removes an epic, the corresponding `test-coverage-{epic}.md` is removed on the next coverage run rather than left stale.
4. Coverage for epics/layers that remain valid is not deleted by the cleanup.
5. The coverage auditor recomputes applicability each run from the current per-epic plan rather than inheriting prior N/A designations.
6. State entries for removed epics/layers are cleared (or marked superseded) so metrics do not report stale N/A coverage.
7. A re-run with no plan changes is idempotent — no files are spuriously added or removed.
8. `claude plugin validate` passes.

### Verification
QC confirms PASS by: running coverage, then correcting the plan to make an N/A layer applicable and re-running, asserting real coverage replaces the N/A; removing an epic from the plan and re-running, asserting its coverage file is gone while sibling coverage remains; and running twice with no change to confirm idempotency.

---

## EDMV2-T110: Document WS-G/WS-H conventions in CLAUDE.md and plugin docs

| Field | Value |
|---|---|
| Workstream | WS-G + WS-H |
| SRD Requirements | EDMV2-57, EDMV2-60, EDMV2-61, EDMV2-62, EDMV2-63 |
| Priority | Should |
| Size | S |
| Target Components | `CLAUDE.md` — state-schema section (parent/related fields), artifact-layout section (multi-pack, BASELINE.md, per-epic plan/coverage filenames), testing-layer section (per-epic plans and coverage); `README.md` — user-facing note on product-line linkage and multi-stack testing |
| Dependencies | EDMV2-T101, EDMV2-T104, EDMV2-T105, EDMV2-T106, EDMV2-T107 |

### Description
The conventions introduced by WS-G and WS-H must be documented so contributors and users understand the new state fields, directory shapes, and filename conventions. `CLAUDE.md` is the authoritative contributor reference and must be updated to describe: the `parent_prefix` / `related_prefixes` fields; the multi-pack ticket directory convention with per-pack prefixes; the `SRD/{PRODUCT}/BASELINE.md` path; and the per-epic `test-plan-{epic}.md` / `test-coverage-{epic}.md` filename conventions.

`README.md` gets a concise user-facing note pointing to product-line linkage and multi-stack testing as v2.0.0 capabilities. All documentation must be ASCII-only (WS-K) and consistent with the actual implemented behavior delivered in T101–T109, so the docs do not advertise behavior that does not exist (the WS-A G3 anti-pattern).

### Acceptance Criteria
1. `CLAUDE.md` state-schema section documents `parent_prefix` and `related_prefixes` as additive, defaulted, bare-prefix fields.
2. `CLAUDE.md` artifact-layout section documents the multi-pack convention with per-pack prefixes.
3. `CLAUDE.md` documents `SRD/{PRODUCT}/BASELINE.md` as the product-level baseline path.
4. `CLAUDE.md` testing-layer section documents `test-plan-{epic}.md` and `test-coverage-{epic}.md` conventions.
5. `README.md` includes a user-facing note on product-line linkage and multi-stack testing.
6. Every documented behavior maps to an implemented capability in T101–T109 (no advertised-but-absent feature).
7. All added documentation is ASCII-only (`grep -P '[^\x00-\x7F]'` over the changes returns nothing).
8. `claude plugin validate` passes.

### Verification
QC confirms PASS by diffing `CLAUDE.md` / `README.md` for each required topic, cross-checking each documented capability against the corresponding T101–T109 acceptance criteria, and running the ASCII check over the additions.

---

## EDMV2-T111: WS-G linkage integration sandbox check

| Field | Value |
|---|---|
| Workstream | WS-G |
| SRD Requirements | EDMV2-57, EDMV2-58, EDMV2-59 |
| Priority | Must |
| Size | S |
| Target Components | `bin/` test fixtures / sandbox notes (recorded in the EDMV2 testing-layer verification notes, consistent with the EDMV2-02 sandbox-check pattern); exercises `bin/edm-state set-parent`, `add-related`, `resolve-dir`, and `write-handoff` end to end |
| Dependencies | EDMV2-T101, EDMV2-T102, EDMV2-T103 |

### Description
Because the plugin has no CI (C-2), the linkage feature needs a documented, repeatable sandbox check that exercises `set-parent`, `add-related`, resolution, and HANDOFF/SRD rendering end to end against a multi-initiative fixture. This mirrors the EDMV2-02 pattern of recording a verification check in the testing-layer notes so a regression is detectable by re-running.

The check builds a fixture of three initiatives under two products with globally unique prefixes, links them (one parent, one related), and asserts the full chain: state fields persist with correct JSON types, bare prefixes resolve to correct directories, dangling links are refused, and both HANDOFF and SRD render the Related Initiatives section. The check must be self-contained (creates and tears down its own fixture) and must not touch the live EDMV2 state (C-5 self-hosting safety).

### Acceptance Criteria
1. A documented sandbox check exists that builds a three-initiative, two-product fixture with globally unique prefixes.
2. The check asserts `set-parent` and `add-related` persist correct values with correct JSON types.
3. The check asserts bare-prefix resolution returns the correct directory for each linked prefix.
4. The check asserts a dangling link is refused and leaves state unchanged.
5. The check asserts HANDOFF.md and `srd.md` both render the Related Initiatives section with resolved paths.
6. The check creates and removes its own fixture and does not modify the live EDMV2 `.edm-state.json`.
7. Re-running the check after reverting any one of T101/T102/T103 causes it to fail (proving it guards the behavior).
8. The check is recorded in the testing-layer verification notes.

### Verification
QC confirms PASS by running the check in a sandbox and observing all assertions pass, then reverting one linkage behavior and observing the check fail; and by confirming `git diff` on the live EDMV2 state is empty after the check runs.

---

## EDMV2-T112: WS-H multi-stack test-layer integration sandbox check

| Field | Value |
|---|---|
| Workstream | WS-H |
| SRD Requirements | EDMV2-62, EDMV2-63, EDMV2-64, EDMV2-65 |
| Priority | Must |
| Size | S |
| Target Components | `bin/` test fixtures / sandbox notes (recorded in the EDMV2 testing-layer verification notes); exercises `edm-test-planner` and `edm-test-coverage-auditor` against a two-stack fixture and the stale-N/A correction path |
| Dependencies | EDMV2-T106, EDMV2-T107, EDMV2-T108, EDMV2-T109 |

### Description
The multi-stack test support (per-epic plans, per-epic coverage, per-epic stack detection, stale-N/A removal) needs a documented, repeatable sandbox check given the absence of CI (C-2). The check builds a two-stack fixture initiative — one backend (e.g., Python) epic and one frontend (e.g., Vue/Nuxt) epic in distinct directories — runs the planner and coverage auditor, and asserts the per-epic behavior plus the stale-N/A correction path.

This mirrors the EDMV2-02 sandbox-check pattern and is recorded in the testing-layer verification notes. The check must be self-contained and must not touch the live EDMV2 initiative (C-5). It is the integration counterpart to the per-ticket acceptance criteria in T106–T109 and is the artifact QC uses to confirm the whole WS-H slice works together rather than each piece in isolation.

### Acceptance Criteria
1. A documented sandbox check exists that builds a two-stack fixture (one backend epic, one frontend epic, distinct directories) with a ticket pack.
2. The check asserts the planner produces a per-epic `test-plan-{epic}.md` for each epic plus a top-level index.
3. The check asserts each epic's stack is auto-detected correctly and that neither epic's plan marks the other's in-scope layers N/A.
4. The check asserts the coverage auditor produces a per-epic `test-coverage-{epic}.md` with independent figures.
5. The check asserts the stale-N/A correction path: a plan correction making an N/A layer applicable is reflected on the next coverage run, and a removed epic's coverage file is removed.
6. The check creates and removes its own fixture and does not modify the live EDMV2 `.edm-state.json`.
7. Re-running the check after reverting any one of T106–T109 causes it to fail.
8. The check is recorded in the testing-layer verification notes and a re-run with no changes is idempotent.

### Verification
QC confirms PASS by running the check against the two-stack fixture and observing all assertions pass, reverting one WS-H behavior and observing failure, and confirming the live EDMV2 state is untouched (`git diff` empty) after the run.
