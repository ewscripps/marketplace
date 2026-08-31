## Findings (L11: Integration Wiring)

| # | Type | Component/Endpoint | Break In Chain | File:Line |
|---|---|---|---|---|
| 1 | State key written, never read | `test_frameworks_detected` (CA-421, STILL OPEN) | Produced every run by `edm-test-planner`; `get-coverage`/`metrics-report` (the two consumers the provenance comment names) read `coverage_by_layer`/`coverage_by_epic` only | plugins/edm/bin/edm-state:1861 |
| 2 | Durability check covers only one direction (CA-422, STILL OPEN) | `caller_contract_scan` | Scans producers (`edm-state set <PREFIX> <key>`) only; its inverse pass reports keys with no PRODUCER, never keys with no CONSUMER, and never fails | plugins/edm/bin/tests/wave7-smoke.sh:99 |
| 3 | State keys written, never read (NEW) | `code_audit_p2_debt_accepted_at` / `_accepted_by` | Written by `--accept-p2-debt`; no reader in archive, HANDOFF, validate, metrics-report, or any skill. Byte-identical duplicates of two keys written 7 lines above that DO have readers | plugins/edm/bin/edm-state:2222 |
| 4 | Ground-truth fixture with no consumer (NEW) | `evals/fixtures/tiny-svc/expected.json` | The fixture README names `score-artifacts.sh` as its consumer "rather than only a self-consistency check"; the scorer never opens the file and all five of its dimensions are self-consistency checks | plugins/edm/evals/score-artifacts.sh:42 |
| 5 | Artifact produced, no consumer, undeclared (NEW) | `${OUTPUT_DIR}/tooling-notes.md` | Written by code-audit step 8b; nothing reads it and it is absent from both artifact inventories, unlike its sibling `lenses-run.txt` | plugins/edm/skills/code-audit/SKILL.md:108 |

### Details

#### Finding 1: CA-421 -- `test_frameworks_detected` is still write-only (RE-FLAGGED, still open)

- **What exists**: `test_frameworks_detected` is member 8 of `SETTABLE_KEYS`
  (`bin/edm-state:1861`), is seeded in the `cmd_init` payload (`:1950`), is documented in
  `CLAUDE.md:580,598` and `CHANGELOG.md:850`, and is asserted by
  `bin/tests/wave6-smoke.sh:1047`.
- **What it's wired to**: producers only. `agents/edm-test-planner.md:250` and `:255` call
  `edm-state set {PREFIX} test_frameworks_detected ...` (Step 6, flat and per-epic forms), and
  the agent's own frontmatter description (`:9`) restates it.
- **What it should call**: the provenance comment at `bin/edm-state:1847-1849` still asserts a
  consumer that does not exist -- it groups the key with `coverage_by_epic` and says
  "`get-coverage`/`metrics-report` consume". Re-verified against current code this round:
  - `cmd_get_coverage`'s jq programs (`bin/edm-state:2620`, `:2633`, `:2647`) read
    `.coverage_by_layer` and `.coverage_by_epic` and nothing else.
  - `cmd_metrics_report`'s coverage section (`bin/edm-state:3450-3470`) reads
    `.coverage_by_layer` and `.coverage_by_epic` and nothing else.
  - A tree-wide grep for `test_frameworks_detected` returns exactly eight occurrences in
    `plugins/edm/`: two docs lines, one CHANGELOG line, three producer lines in
    `edm-test-planner.md`, three in `bin/edm-state` (comment, `SETTABLE_KEYS`, init payload),
    and one negative-path assertion in `wave6-smoke.sh`. Zero are reads.
  The real channel is the `test-plan.md` artifact, and `CLAUDE.md`'s own N/A policy ("N/A
  designations are recomputed each run -- never inherited from a previous plan") removes the one
  purpose a persisted copy would have served.
- **No fix landed since round 7.** No commit between `dfa71d3` and `bdab2ac` touches the key.
- **Fix**: take the delete route the same file's own two precedents already establish
  (`last_cmd`, `bin/edm-state:1850-1854`; `jira_synced_at`/`jira_project_key`, `:1855-1860`):
  remove `test_frameworks_detected` from `SETTABLE_KEYS:1861` and from the `cmd_init` payload
  `:1950`; delete the two `edm-state set` calls at `edm-test-planner.md:250,255` and the clause
  at `:9`; re-key `wave6-smoke.sh:1047`'s unknown-key assertion onto a surviving member; correct
  the `:1847-1849` provenance comment so `coverage_by_epic` stands alone with its real producer
  (`edm-test-coverage-auditor.md:243`) and consumer; and record the deletion in `CHANGELOG.md`
  and `CLAUDE.md:576-600`. Keeping it settable requires the opposite: give it a real reader in
  `cmd_get_coverage` or `cmd_metrics_report` in the same commit.

#### Finding 2: CA-422 -- the SETTABLE_KEYS consumer half is still unenforced (RE-FLAGGED, still open)

- **What exists**: `caller_contract_scan` (`bin/tests/wave7-smoke.sh:57-110`) is the only
  structural check over `SETTABLE_KEYS`, and the durability rule it is supposed to enforce is
  written at `bin/edm-state:1823-1831`: "every member below must state BOTH a producer ... and a
  consumer (who reads it back from state)".
- **What it's wired to**: the producer direction only.
  - `:96` -- the scan's sole extraction is `grep -n 'edm-state set ' "$f"`, so the only fact it
    can observe about any key is whether something WRITES it.
  - `:89-95` -- the failing arm (`MISS`) fires when a written key is not in the allowlist.
  - `:99-107` -- the inverse arm emits `WARN_UNUSED <key>` for an allowlisted key with **no
    producer**, and its own comment concedes it is "reported, never failed". `:142-143` then
    asserts positively that `WARN_UNUSED` lines do NOT fail the scan.
  - Consequence: a key with a producer and no consumer -- precisely CA-421's and CA-384's shape
    -- produces neither a `MISS` nor a `WARN_UNUSED`. It is structurally invisible.
- **What it should call**: a consumer-side pass. Re-verified this round that none exists: greps
  for `consumer`/`reader` across `bin/tests/` return only unrelated prose (shared-lint-library
  consumers, `cmd_audit_converged`'s four consumers, `_edm-lint-lib.sh` peers), and
  `_wave7_settable_keys` has exactly two call sites, both inside `caller_contract_scan`
  (`:60`, `:102`).
- **Direct evidence the gap is still live**: Finding 3 below is a brand-new write-only key pair
  introduced by commit `dc8a24f` -- i.e. it landed AFTER the `:1823-1831` durability rule was
  written, and the full suite stayed green. A prose rule with no check is not a check.
- **Fix**: add a second pass to `caller_contract_scan` (or a sibling function) that, for each
  member of `SETTABLE_KEYS`, greps `bin/`, `skills/`, `agents/`, `hooks/hooks.json` and
  `monitors/monitors.json` for at least one READ occurrence -- a `jq` path reference
  (`.<key>`), a `read_bool "$state" "<key>"`, or a documented-and-listed exemption -- excluding
  the `SETTABLE_KEYS` line itself, the provenance comment block, the `cmd_init` payload, and
  `bin/tests/`. A key with zero reads must **fail** (exit non-zero), not warn: the existing
  `WARN_UNUSED` precedent is exactly why CA-384 and CA-421 survived. Pair it with a negative
  case (inject a synthetic consumer-less key into a scratch tree and assert the scan fails,
  naming the key), mirroring `neg_case_bogus_key` at `:149-177`.

#### Finding 3: `code_audit_p2_debt_accepted_at` and `_accepted_by` are written and read by nothing (NEW)

- **What exists**: `cmd_approve_gate`'s `--accept-p2-debt` branch writes five debt keys in one
  `rmw_state` call (`bin/edm-state:2213-2226`):
  ```
  | .code_audit_p2_debt_accepted = true
  | .code_audit_p2_debt_count = ($p|tonumber)
  | .code_audit_p2_debt_round = ($r|tonumber)
  | .code_audit_p2_debt_accepted_at = $t
  | .code_audit_p2_debt_accepted_by = $a
  ```
- **What it's wired to**: three of the five have real consumers; two have none.
  - `_accepted` -- read at `bin/edm-state:3013` (`cmd_archive`'s staleness gate) and `:5329`
    (HANDOFF).
  - `_count` -- read at `:3022` and `:5331`.
  - `_round` -- read at `:3015` and `:5332`.
  - `_accepted_at` -- **zero readers** tree-wide.
  - `_accepted_by` -- **zero readers** tree-wide.
- **What it should call**: nothing needs them. `$t` and `$a` in that same jq invocation are
  already persisted seven lines earlier as `code_audit_gate_approved_at` (`:2215`) and
  `code_audit_gate_approver` (`:2216`) from the identical `--arg t`/`--arg a` bindings
  (`:2225`), and THOSE two are read in three places: `cmd_validate`'s `CONVERGED_NO_APPROVAL`
  check (`:1649`), `cmd_metrics_report`'s `dedicated_gate_row` (`:3444`), and HANDOFF
  (`:5323-5324`). So the two new keys are not merely unread -- they are byte-identical
  duplicates of two keys that are read.
- **Not a false alarm**: filter 1 fails (nothing documents them as write-only; `CLAUDE.md:241`
  and `skills/code-audit/SKILL.md:190` list all five as "debt metadata" recorded together, and
  `CLAUDE.md`'s next sentence names only count and round as what HANDOFF surfaces, so the
  documentation itself does not claim a consumer for these two). Filter 2 fails (no comment
  explains the duplication). Filter 3 fails (the gate-metadata pattern at `:2104-2111` and
  `:2229-2236` is exactly "sibling scalars that ARE read").
- **Fix**: drop `.code_audit_p2_debt_accepted_at = $t` and
  `.code_audit_p2_debt_accepted_by = $a` from the jq program at `:2222-2223` -- the timestamp
  and approver survive in `code_audit_gate_approved_at`/`_approver`, which the same branch
  already writes and which three consumers already read. Update `CLAUDE.md:241`,
  `docs/canonical-sections.md:38` and `skills/code-audit/SKILL.md:190` to list the three keys
  that remain. If the pair is instead kept, give it a real reader in the same commit -- the
  natural one is HANDOFF's debt row at `:5329-5332`, which currently renders count and round but
  not who accepted the debt or when.

#### Finding 4: the tiny-svc eval fixture's ground truth is consumed by nothing, so the eval measures only self-consistency (NEW)

- **What exists**: `plugins/edm/evals/fixtures/tiny-svc/expected.json` enumerates six known,
  countable gaps (GAP-01..GAP-06) in the frozen eval subject, carries a version contract, and is
  cross-referenced by five source-file comments (`src/api/server.js:6,10`,
  `src/api/routes.js:5`, `src/worker/processor.js:5,7,12`, `src/worker/queue.js:6`) plus
  `evals/README.md:277`.
- **What it's wired to**: nothing executable. Neither `evals/score-artifacts.sh` nor
  `evals/run-eval.sh` nor `bin/edm-compare-eval` nor any smoke suite contains the string
  `expected.json`, `GAP-0`, or any case-insensitive `expected`/`ground truth` reference to it.
  The scorer's five dimensions (`score-artifacts.sh:42` onward; restated at
  `evals/README.md:200-213`) are requirement-id-coverage, ac-testability,
  mermaid-parse-success, coverage-map-bidirectionality and lens-jsonl-prose-agreement -- every
  one of them computed over the run's OWN output files.
- **What it should call**: the fixture README states the intended wiring in so many words
  (`evals/fixtures/tiny-svc/README.md:22-25`): the gaps "are enumerated in `expected.json`
  alongside this README **so the eval scorer (`score-artifacts.sh`, EDMV3-T23) has ground truth
  to check a produced SRD against, rather than only a self-consistency check.**" The named
  consumer is in scope, exists, and does not consume it -- so the harness delivers exactly the
  self-consistency-only scoring the README says it was built to avoid.
- **Why this is P1, not P2**: the break is load-bearing for the only automated regression
  detector this initiative has for prompt quality. `eval:nightly` (`.gitlab-ci.yml:695-742`)
  feeds `scores.json` to `bin/edm-compare-eval` against a committed baseline. Because no
  dimension consults the ground truth, an eval run whose SRD surfaces **zero** of the six known
  gaps can score identically to one that surfaces all six -- both are internally consistent, both
  have sequential requirement IDs, both parse their Mermaid. The tripwire is structurally blind
  to the regression class it exists to catch, and `CLAUDE.md:345` already records that the
  baseline itself is uncaptured, so nothing else compensates.
- **Not a false alarm**: filter 1 fails -- the documentation asserts the opposite of the current
  behaviour rather than sanctioning it. Filter 2 fails -- no comment in `score-artifacts.sh`
  explains the omission. Filter 3 fails -- there is no other scorer; `edm-compare-eval` only
  compares two `scores.json` files and never reads the fixture.
- **Fix**: add a sixth scorer dimension, `known-gap-recall`, to `score-artifacts.sh`: read
  `fixtures/tiny-svc/expected.json`, and for each `GAP-NN` entry grep the run's `srd.md` for its
  declared marker (an `id`/`match` regex field added to each entry for this purpose), scoring
  `100 * matched/total`. It must follow the file's existing skip contract -- emit `score: null`
  and a `dimensions_skipped` reason when the run directory is not the tiny-svc fixture -- so the
  scorer stays usable against arbitrary run directories, and it must bump `scorer_version` so
  `edm-compare-eval`'s version handshake (`bin/edm-compare-eval:81`) refuses to compare across
  the change rather than silently mixing five- and six-dimension totals. If a sixth dimension is
  out of scope, the honest alternative is to correct
  `evals/fixtures/tiny-svc/README.md:22-25` and `evals/README.md:277` to state that
  `expected.json` is human-reference-only and is checked by no code -- but that leaves the
  tripwire blind, so wiring it is the better route.

#### Finding 5: `tooling-notes.md` is written by the code-audit round and consumed by nothing (NEW)

- **What exists**: `skills/code-audit/SKILL.md:108-120` (step 8b, added as CA-388's remediation)
  instructs the orchestrator to write `${OUTPUT_DIR}/tooling-notes.md` recording per-lens stall
  counts and truncation caveats, "so degraded delivery is measurable round over round rather
  than lost the moment the round's own transcript scrolls away."
- **What it's wired to**: only the producing instruction. A tree-wide grep for `tooling-notes`
  returns exactly one hit -- `skills/code-audit/SKILL.md:111`. It is not read by
  `agents/edm-audit-synthesizer.md` (which reads the lens reports and `lenses-run.txt` at `:24`
  and `:180`), not by `edm-state metrics-report`, not by any smoke suite, and not by any other
  skill.
- **What it should call**: contrast its sibling. `lenses-run.txt`, written one step earlier into
  the same directory for the same round-scoped purpose, has two structural consumers
  (`edm-audit-synthesizer.md:24,180`; `wave7-smoke.sh:1507-1510`'s T24 AC0) **and** appears in
  both artifact inventories -- `CLAUDE.md`'s layout block ("`lenses-run.txt` <- lens set for this
  round") and `README.md:197`. `tooling-notes.md` has neither consumer nor inventory entry: it is
  absent from `CLAUDE.md`'s `pass-{N}_{YYYY-MM-DD}/` block and from `README.md:194-198`. A
  reader following either documented tree has no way to learn the file can exist, which defeats
  the round-over-round comparison that is its entire stated purpose.
- **Partial false-alarm credit**: filter 1 partly applies -- CA-388's ledger entry does record
  the file as an intentional, on-demand, human-read artifact, and "written only when there is
  something to record" is a deliberate design choice, not an oversight. That is why this is P2
  and medium confidence rather than higher. What survives the filter is the un-discoverability:
  an intentionally human-consumed artifact still needs a documented location for the human.
- **Fix**: add one line to both artifact inventories --
  `CLAUDE.md`'s `pass-{N}_{YYYY-MM-DD}/` block (beside the `lenses-run.txt` line) and
  `README.md:197` -- reading `tooling-notes.md  <- per-lens stall counts / truncation caveats
  (on-demand; absent when the round was clean)`. Optionally give it a real structural consumer by
  having `edm-audit-synthesizer` read it when present and carry a one-line "delivery degradation
  this round" note into `REMEDIATION.md`, which is what makes the degradation actually visible at
  the convergence gate rather than only in a file nobody is pointed at.

## Noted / Not Actionable

| # | Component | Rationale |
|---|---|---|
| N1 | `edm-state git-lock-check` (`bin/edm-state:3871`) | Zero automatic callers across `skills/`, `agents/`, `hooks/`, `monitors/`, `bin/`; resolved in round 6 by documenting it as OPERATOR-INVOKED by name in `architecture.md`. Filter 1 -- an intentionally human-invoked entry point is not a broken chain. |
| N2 | `migrate-path`, `migrate-schema`, `set-supersedes`, `set-forked-from`, `set-parent`, `add-related` | Six subcommands with no skill/agent/hook caller, all documented as operator-run CLI in `CLAUDE.md:146-151,606-609,621-622,820-821,839-844` and all with real readers (`state_file_for` path derivation; HANDOFF's provenance and Related rows at `bin/edm-state:5534,5600-5609`). Filter 1. |
| N3 | `edm-state init`, `record-branch` | Both called by `bin/edm-init` (`:161`, `:215`); `init` is additionally a documented direct-invocation entry point (`README.md:220-223`). Wired. |
| N4 | `WARN_UNUSED product_name` / `WARN_UNUSED compliance_enabled` (`wave7-smoke.sh:140-141`) | Advisory by design and asserted as such. Both keys have real producers outside the scan's `edm-state set` grep shape (`edm-init`/`cmd_migrate_path` for `product_name`; the orchestrator's mode-selection step via `set-mode` for `compliance_enabled`), and both have real readers. Not the CA-422 class -- that class is the opposite direction. |
| N5 | All 30 files in `agents/` | Every one is spawned: 11 lenses + synthesizer from `skills/code-audit/SKILL.md:235-245,334`; `edm-qc-auditor` from `skills/implement/SKILL.md:37` and `hooks/hooks.json`'s `SubagentStop`; the rest from their owning phase/test skills. No orphan agent. |
| N6 | All 20 `userConfig` keys in `.claude-plugin/plugin.json` | Each is consumed -- 16 via `${user_config.*}` prompt substitution in skills/agents, and four via the env-prefixed form in `bin/edm-init` (`CLAUDE_PLUGIN_OPTION_MODE:37`, `_COMPLIANCE_ENABLED:38`, `_IMPLEMENTATION_MODE:39`, `_COMMIT_STATE_FILE:182`). No orphan config key. |
| N7 | `monitors/monitors.json` -> `edm-state watch-impl` | `cmd_watch_impl` (`bin/edm-state:3100`) takes zero arguments, matching the monitor's argument-less command; arming is host-managed per `CLAUDE.md:700-716`. Filter 1 (external event source). Wired. |
| N8 | All five `hooks/hooks.json` event families | `SessionStart`->`session-start`, `Stop`/`PreCompact`->`checkpoint-if-active`, five `UserPromptExpansion` matchers->`gate-check`, `PreToolUse git commit`->`edm-lint-artifacts`, `SubagentStop edm-implementer`->`edm-qc-auditor`+`record-partial-verdict`. Every target subcommand exists in the dispatch table (`:5639-5685`). No dead handler. |
| N9 | `tests_added` / `tests_by_layer` / `partial_verdict_map` / `degraded_checks` / `archive_exemptions` / `artifact_hashes` / `initiative_description` / `implementation_mode` / all four `code_audit_gate_*` / all three `compliance_gate_*` | Checked individually; every one has at least one real reader in `cmd_metrics_report`, `cmd_validate`, `cmd_archive`, `write_handoff_internal`, or a skill. Not the CA-421 class. |
| N10 | `bin/tests/timing.sh`, `evals/tiering-matrix.sh` | Neither is auto-discovered by `run-all.sh` (deliberately, per CA-328), but both are reached by real assertions: `wave7-smoke.sh:4435-4449` runs `timing.sh --self-test`, `:4798-4803` runs `tiering-matrix.sh --self-test`, and both are covered by `lint:bash-syntax` and `lint:shellcheck`. Filter 1. |
| N11 | `docs/templates/ticket-size-legend.md`, `docs/templates/cross-cutting-ac.md`, `docs/canonical-sections.md`, `evals/vague-ac-patterns.txt`, `evals/initiative.txt`, `evals/baseline/` | All have live readers (`edm-ticket-writer.md:33-34,41-42`; `skills/tickets/SKILL.md:51-52`; `skills/audit-tickets/SKILL.md:44,136`; the 13 D34-anchored agent files; `score-artifacts.sh:127,274`; `run-eval.sh:70,341-344`; `edm-compare-eval:59`). Wired. |
| N12 | `evals/fixtures/tiny-svc/README.md:41` claims `lint:file-type-ban` "runs `du -sk plugins/edm/evals/`" | The job actually sums `git ls-files -- plugins/edm/evals | wc -c` (`.gitlab-ci.yml:342-350`), tracked bytes only, explicitly excluding `evals/runs/`. A doc naming a mechanism that does not exist -- but that is comment/doc accuracy (L6), not integration wiring. Recorded here only as a cross-lens pointer; not filed as an L11 finding. |

## Summary for the coordinator

**Both prior findings re-verified as STILL OPEN**, with fresh evidence, not merely restated:

- **CA-421** -- no fix landed. `test_frameworks_detected` remains in `SETTABLE_KEYS` at `plugins/edm/bin/edm-state:1861` and in the `cmd_init` payload at `:1950`; producers at `plugins/edm/agents/edm-test-planner.md:250,255`. I re-checked both claimed consumers directly: `cmd_get_coverage`'s jq (`:2620`, `:2633`, `:2647`) and `cmd_metrics_report`'s coverage section (`:3450-3470`) read only `coverage_by_layer`/`coverage_by_epic`. Eight tree-wide occurrences, zero reads.
- **CA-422** -- no fix landed. `caller_contract_scan` at `plugins/edm/bin/tests/wave7-smoke.sh:57-110` still extracts only via `grep -n 'edm-state set ' "$f"` (`:96`); the inverse arm at `:99-107` emits `WARN_UNUSED` for keys with no *producer* and `:142-143` positively asserts it never fails.

**Three new findings**, the strongest being P1 finding 4: the tiny-svc eval fixture's `expected.json` ground truth is read by no code, so `score-artifacts.sh` scores only self-consistency -- the exact thing `plugins/edm/evals/fixtures/tiny-svc/README.md:22-25` says the file exists to prevent -- leaving the `eval:nightly` -> `edm-compare-eval` baseline tripwire blind to its own regression class.

Finding 3 is worth flagging to the synthesizer as **direct causal evidence for CA-422's priority**: `code_audit_p2_debt_accepted_at`/`_accepted_by` (`bin/edm-state:2222-2223`) are a brand-new consumer-less key pair introduced by commit `dc8a24f`, i.e. *after* the producer-and-consumer durability rule was written at `bin/edm-state:1823-1831`, and the full suite stayed green. CA-422 is not a hygiene item; it is the only thing that would have caught CA-384, CA-421, and now this.
