# Lens L11: Integration Wiring -- Pass 7 (2026-08-10)

**Tooling note (CA-130's class, seventh consecutive round):** `Write`/`Bash`
absent from this lens's delivered runtime tool set. Transcribed by the
orchestrator from the lens agent's final message. Round type read from
`lenses-run.txt:1`: **full**.

**Delivery-layer data point:** the pass-7 output directory held ten
`lens-L*.md` files and zero `.jsonl` files at the time this lens ran, so the
JSONL write path was elided from every lens this round, not only L11.

## Findings (L11: Integration Wiring)

| ID | Type | Component/Endpoint | Break In Chain | File:Line |
|----|------|----------------------|-------------------|-----------|
| L11-001 | Write-only settable keys; userConfig twin shadows the state twin | `jira_synced_at` / `jira_project_key` | Both are produced by `push-jira` Step 8 and read by NOTHING anywhere; the re-run fallback reads `user_config.jira_project_key` instead. Confirmed recurrence of the `qc_shard_threshold` class the round-6 durability rule was written to prevent, and that rule's own text asserts "both directions" for these two keys | plugins/edm/bin/edm-state:1795 |
| L11-002 | Write-only settable key | `test_frameworks_detected` | Produced by `edm-test-planner` Step 6, never read: `get-coverage` and `metrics-report` (the consumers the provenance comment names) read `coverage_by_epic`/`coverage_by_layer` only. The real channel is the `test-plan.md` artifact | plugins/edm/bin/edm-state:1796 |
| L11-003 | Durability rule with no enforcing check | G29/CA-356 producer-AND-consumer rule | `caller_contract_scan` only checks the producer direction (`WARN_UNUSED` = allowlisted key with no `edm-state set` caller). A key with a producer and no reader is invisible to CI, which is why L11-001/L11-002 survived the round-6 fix | plugins/edm/bin/tests/wave7-smoke.sh:99 |
| L11-004 | Advisory layer contradicts the exit-code contract it delegates to | five `UserPromptExpansion` prompt hooks, step 4 | Prompt says "if it exits non-zero, BLOCK"; the sibling command hook blocks only on `[ "$ec" -eq 3 ]`, and `cmd_gate_check` returns 1 for setup/usage errors. Conflates the two statuses round 6 split apart via `GATE_CHECK_REFUSED` | plugins/edm/hooks/hooks.json:23 |

### Details

#### Finding L11-001: the Jira state pair is written on every push and read by nobody

- **What exists**: `jira_synced_at` and `jira_project_key` are members of
  `SETTABLE_KEYS` (`bin/edm-state:1804`), with the provenance comment at
  `:1795-1796` reading `jira_synced_at/jira_project_key (skills/push-jira/
  SKILL.md, both directions)`.
- **What it's wired to**: the producer half is real -- `skills/push-jira/
  SKILL.md:165-166` runs `edm-state set <PREFIX> jira_synced_at ...` and
  `edm-state set <PREFIX> jira_project_key <JIRA_PROJECT_KEY>` in Step 8
  (normal mode only). The consumer half does not exist. A tree-wide search
  for both names across `plugins/edm/` returns exactly: those two producer
  lines, the `SETTABLE_KEYS` string and its comment, two `CHANGELOG.md`
  history entries, and one prose claim. **No `jq` read in `bin/edm-state`**
  (no HANDOFF row, no `metrics-report` row, no `validate` anomaly, and
  neither key is in `cmd_init`'s payload), and no skill or agent reads
  either key back from state.
- **What it should call**: the "both directions" claim points at `push-jira`
  itself, and `push-jira` does have a place where a state read belongs --
  Step 1 (`SKILL.md:28`) resolves the project key as "`{JIRA_PROJECT_KEY}`
  (optional -- falls back to `${user_config.jira_project_key}`)". That
  fallback reads **userConfig, never state**, so the value Step 8 persisted
  on the previous push is discarded on the next one. This is the identical
  shape to `qc_shard_threshold`, whose userConfig twin
  (`user_config.qc_shard_threshold`) likewise made the feature work while
  the state key changed nothing.
- **A false behavioral claim rides on it**: `skills/push-jira/SKILL.md:224`
  tells the reader "`bin/edm-state` -- tracks `jira_synced_at` and
  `jira_project_key` so future runs know what's already been pushed." No
  run reads either field. What actually makes a re-run idempotent is the
  JQL label search at `SKILL.md:55` (`searchJiraIssuesUsingJql` on the
  `edm-{prefix}-t{nn}` labels), which needs neither key. So the documented
  mechanism and the real mechanism are different, and the documented one is
  inert.
- **Not a false alarm**: filter 1 fails -- nothing documents these as
  write-only, and the state-field reference in `CLAUDE.md Sec.".edm-
  state.json mode-family fields"` (which the file itself calls "the whole
  state-field reference") does not list either key at all, nor does the
  `State schema additions` JSON block. Filter 2 fails -- the only comment on
  them asserts the opposite of the truth. Filter 3 fails -- the sibling
  keys are the control: `coverage_by_epic` really is read
  (`bin/edm-state:2510,2524` in `get-coverage`; `:3305,3322` in
  `metrics-report`), `current_phase`, `product_name`, `estimated_size`,
  `last_decision` and `compliance_enabled` all have real readers named and
  real readers present.
- **Severity rationale (P1, above `qc_shard_threshold`'s P2)**: three
  aggravating factors. (a) It is a *confirmed recurrence* of a class the
  previous round closed, so the round-6 remediation is itself defective,
  not merely incomplete. (b) The remediation artifact -- the durability
  comment -- states a falsehood, which actively misleads the next reader
  who checks it instead of grepping. (c) A user-facing skill file makes a
  behavioral promise ("future runs know what's already been pushed") that
  no code keeps.
- **Fix**: give the pair a real reader or delete it, and correct the
  comment either way.
  - *Reader route*: change `push-jira/SKILL.md:28`'s resolution order to
    argument -> `edm-state get <PREFIX> | jq -r '.jira_project_key'` ->
    `${user_config.jira_project_key}`, and have Step 1 print the prior
    `jira_synced_at` so the operator sees when the last push happened. That
    makes `:224`'s claim true.
  - *Delete route*: drop both from `SETTABLE_KEYS:1804`, delete the two
    `set` calls at `:165-166`, and rewrite `:224` to name the JQL label
    search as the actual idempotency mechanism -- mirroring the `last_cmd`
    (CA-246) and `qc_shard_threshold` (G29/CA-356) precedents.
  - Either way, replace "both directions" at `:1795-1796` with the named
    producer *and* the named consumer, per the rule at `:1771-1773`.

#### Finding L11-002: `test_frameworks_detected` is written per run and read by nothing

- **What exists**: `test_frameworks_detected` is in `SETTABLE_KEYS`
  (`bin/edm-state:1804`), seeded `{}` by `cmd_init` (`:1893`), documented in
  `CLAUDE.md`'s state-schema block and its keying paragraph, and produced
  by `agents/edm-test-planner.md:250` (single-stack) and `:255`
  (multi-stack), with the agent's own frontmatter advertising it at `:9`.
- **What it's wired to**: the provenance comment at `:1796-1798` groups it
  with `coverage_by_epic` -- "`coverage_by_epic`/`test_frameworks_detected`
  (`agents/edm-test-coverage-auditor.md`, `agents/edm-test-planner.md`
  produce; `get-coverage`/`metrics-report` consume)". Only the
  `coverage_by_epic` half of that is true. `cmd_get_coverage` (`:2510,2524`)
  and `cmd_metrics_report` (`:3305,3322`) read `coverage_by_epic` and
  `coverage_by_layer`; neither reads `test_frameworks_detected`. No
  test-writer agent reads it either -- the seven writers read their
  assignments from the planner's `test-plan.md`, and the only other hit in
  the tree is `wave6-smoke.sh:940`, which merely asserts the key appears in
  `cmd_set`'s unknown-key error string.
- **What it should call**: the frameworks the writers actually consume come
  from `test-plan.md` (`agents/edm-test-planner.md` Step 5 writes the
  per-agent assignment blocks, and `--fill-gaps` re-reads the artifact). The
  state write is a second, unread copy of artifact content -- and
  `CLAUDE.md` says N/A designations "are recomputed each run -- never
  inherited from a previous plan", which removes the one purpose a
  persisted copy would serve.
- **Severity rationale (P2, not P1)**: unlike L11-001 no user-facing
  document promises a behavior this field delivers, and no userConfig twin
  is silently winning a resolution race -- the cost is one unread state
  field plus a provenance comment that over-claims by grouping.
- **Fix**: either give `cmd_get_coverage` a "Detected frameworks" line (a
  natural home -- it already prints the coverage summary for the same
  initiative, and `metrics-report`'s coverage table is beside it), or
  delete the key from `SETTABLE_KEYS:1804`, the `cmd_init` payload at
  `:1893`, `edm-test-planner.md` Step 6 (`:246-259`) and its frontmatter
  line `:9`, and re-key `wave6-smoke.sh:940` onto any surviving member.
  Split the grouped comment at `:1796-1798` into one clause per key so a
  shared consumer can never again be inherited by a key that lacks one.

#### Finding L11-003: the round-6 durability rule has no check behind it

- **What exists**: `bin/edm-state:1771-1779` states the rule -- "every
  member below must state BOTH a producer ... and a consumer (who reads it
  back from state) in this comment. A member with a producer but no
  consumer -- or vice versa -- is exactly the shape that let
  `qc_shard_threshold` sit here for multiple rounds looking alive".
- **What it's wired to**: `caller_contract_scan` in
  `bin/tests/wave7-smoke.sh:57-110`. Its own header (`:52-54`) documents
  both of its outputs: `MISS <key>` for a caller key absent from the
  allowlist (fails the scan), and `WARN_UNUSED <key>` for "an allowlisted
  key with zero callers found (informational -- surfaces dead schema
  fields, never fails the scan)". The inverse loop at `:99-107` computes
  `WARN_UNUSED` purely from `found_keys`, which is built at `:88` from
  `grep -n 'edm-state set '` hits. **Both directions the scan checks are
  producer directions**: allowlist-without-producer and
  producer-without-allowlist. There is no consumer-side assertion
  anywhere -- no grep for a state read of each member, and no assertion
  over the provenance comment's own text.
- **Consequence**: a key with a producer and no reader passes every check
  in the suite. That is exactly L11-001 and L11-002, and it is why a rule
  written in round 6 to prevent the recurrence did not detect three
  instances already present in the same file when it was written.
- **Fix**: add one structural case to `wave7-smoke.sh` beside
  `caller_contract_scan`: for each token in `_wave7_settable_keys`, require
  at least one *read* occurrence outside `SETTABLE_KEYS`/the comment
  block/`bin/tests/` (a `jq` read in `bin/edm-state`, or an `edm-state
  get`-plus-key reference in `skills/`, `agents/` or `hooks/`), and
  separately require the provenance comment to name the key at least once.
  Fail, do not warn -- `WARN_UNUSED`'s advisory-only posture is the second
  reason this class keeps surviving.

#### Finding L11-004: the prompt hooks block on the setup-error status round 6 split off specifically so hooks would not

- **What exists**: five matcher blocks, each pairing a command hook with a
  prompt hook. The command hook (`hooks.json:19,32,45,58,71`) ends
  `edm-state gate-check "$prefix" <token>; ec=$?; if [ "$ec" -eq 3 ]; then
  exit 2; fi; exit 0` -- it blocks on **3 and only 3**.
- **What it's wired to**: `cmd_gate_check`'s documented status set
  (`bin/edm-state:3485-3489`, with `GATE_CHECK_REFUSED=3` at `:3518`,
  returned at `:3575` and `:3587`): "Exits 0 if the gate prerequisite ... is
  satisfied. Exits `GATE_CHECK_REFUSED` (3) ... specifically when the gate
  itself has not been approved -- a genuine refusal. Exits 1 for a
  usage/setup error (unknown `<gated-command>`, or a `die` in a helper this
  function calls, e.g. `require_jq` or `read_state`)". Each prompt hook's
  step 4 (`hooks.json:23,36,49,62,75`) instead says: "**If it exits
  non-zero, BLOCK the expansion** and show the user its stderr diagnostic
  verbatim (it already names the missing gate and the exact remediation
  command)."
- **Where they diverge**: exit 1. A missing `jq`, an unreadable or
  malformed state file, or an unknown gated-command token all produce exit
  1. The command hook allows the expansion; the prompt hook blocks it -- and
  presents a `require_jq` or JSON-parse diagnostic under a sentence
  promising the message "names the missing gate and the exact remediation
  command", which it does not. This inverts the contract stated in
  `CLAUDE.md Sec."Hooks behavior"` for this exact event: "a missing
  `edm-state` binary or an unresolvable prefix ... exits **0**,
  non-blocking; an invalid prefix argument or an actual `edm-state
  gate-check` refusal exits **2**, blocking. Only a real gate refusal
  blocks -- **a setup condition never does**."
- **Why this is a distinct finding from round-6 L11-003, not its
  residue**: round 6 fixed the *entry* of these five procedures, adding
  step 2's invalid-prefix arm (now present and verified -- see Verified
  Fixed). The same rewrite left step 4's status test as a bare "non-zero",
  so the five strings still fail parity at their *exit*, and they fail it
  against a status distinction (`GATE_CHECK_REFUSED`) that round 6 created
  in the very same wave "so hooks can distinguish real refusals from setup
  errors." The command hooks got that distinction; the prompt hooks did
  not.
- **Severity rationale (P1, above round-6 L11-003's P2)**: round 6 argued
  P2 because its divergence ran in the fail-safe direction -- the
  deterministic hook still blocked, so no gate opened. This one runs the
  other way: the advisory layer blocks work the deterministic layer
  deliberately allows, on a machine whose only problem is a missing
  dependency. It is a false block on the critical path of five commands,
  and it contradicts a contract `CLAUDE.md` states in bold.
- **Fix**: replace "exits non-zero" with the status split in all five
  prompt strings -- "if it exits **3**, BLOCK ...; if it exits 1 (a usage or
  setup error, e.g. missing `jq` or an unparseable state file), report the
  diagnostic to the user and ALLOW the expansion -- a setup condition never
  blocks (CA-298)". Then extend the per-matcher G31/CA-279 tripwire in
  `bin/tests/wave7-smoke.sh` with a `check` that each of the five prompts
  names `3` as its blocking status and a `check_absent` for the bare phrase
  "exits non-zero", so the next rewrite cannot drop it a third time.

## Verified Fixed This Round

| Item | Evidence |
|----|----|
| Round-6 L11-001 (`qc_shard_threshold`) | Deleted. Absent from `SETTABLE_KEYS` (`bin/edm-state:1804`, now 10 members) and from the numeric-typing arm (`cmd_set`'s `case` at `:1855-1872` types only `compliance_enabled` and `current_phase`). `wave6-smoke.sh:2737-2740` re-keys the concurrency case onto `current_phase` with a comment naming G29/CA-356 and the reason. The `:1771-1779` durability comment records the precedent. |
| Round-6 L11-002 (`set-supersedes`/`set-forked-from`) | Documented on both required surfaces. `README.md:267` now names both commands verbatim with their semantics and states that both render in HANDOFF.md; `CLAUDE.md`'s state-field table rows for `supersedes` and `forked_from` now carry the "(provenance link; set via `edm-state set-supersedes <PREFIX> <OTHER>`)" clause matching the `set-parent` sibling's form. |
| Round-6 L11-003 (invalid-prefix arm) | Fixed in all five prompt hooks. Each procedure now carries step 2: "If the PREFIX is empty or contains any character other than a letter, digit, hyphen or underscore, this is a malformed prefix argument, NOT a legitimate first invocation -- BLOCK the expansion with the same `[EDM] invalid prefix` diagnostic the command hook uses", with the former resolve-dir step renumbered to 3 and correctly re-scoped to "an otherwise well-formed PREFIX". Wording and diagnostic match the command hooks' `case` guard. (Step 4 remains broken -- L11-004.) |
| Round-6 L11-004 (`gate-check` "read-only" label) | Qualified at both sources and dropped from the prompt hooks. `bin/edm-state:32` now reads "deterministic gate enforcement (read-only w.r.t. gate state; may additively record a one-time `.degraded_checks` breadcrumb for a legacy initiative)"; the docstring at `:3493` matches. None of the five prompt strings carries a "(read-only)" parenthetical any more. |
| Round-6 L11-005 (dropped `lint` named as live) | Both copies corrected: `bin/edm-state:6` and `:120` now read "which is exactly how `update-patterns` and the since-removed `lint` fell out of `--help`". |

## Chain checks run clean this round

- **Dispatch vs. documentation**: 39 dispatch arms (`bin/edm-state:
  5456-5494`) match the 39 subcommand names in `CLAUDE.md`'s `bin/` table
  one-for-one, with no arm undocumented and no documented name undispatched.
- **Every subcommand a skill or agent invokes exists**: all invocations
  across `skills/*/SKILL.md` (~140 call sites) and `agents/*.md` (~35)
  resolve to a live dispatch arm. No skill or agent names a subcommand that
  was removed.
- **`record-branch` has a real caller** -- `bin/edm-init:213`, with the
  rationale comment at `:208-212` explaining the post-checkout correction.
  Not an operator-only command despite having no skill-side caller.
- **`coverage_by_epic` chain intact end to end**: produced by
  `agents/edm-test-coverage-auditor.md:226-234,243` and
  `cmd_record_test_coverage` (`bin/edm-state:2455`); consumed by
  `cmd_get_coverage` (`:2510,2524`) and `cmd_metrics_report`
  (`:3305,3322`).
- **`GATE_CHECK_REFUSED` producer/consumer match on the deterministic
  path**: the constant (`:3518`) is returned at `:3575` and `:3587`, and
  all five command hooks test for the same literal 3.
- **The other seven `SETTABLE_KEYS` members have a real reader** --
  `current_phase`, `compliance_enabled`, `estimated_size`,
  `last_decision`, `product_name`, `coverage_by_epic` verified by direct
  read-site inspection; `test_layer_skipped` per round-6's accepted
  human-facing-consumer rationale.

## Noted / Not Actionable

| ID | File:Line | Rationale |
|----|-----------|-----------|
| L11-005 | plugins/edm/bin/edm-state:5479 | `git-lock-check` still has zero automatic callers; documented OPERATOR-INVOKED by name in `architecture.md` -- filter 1, carried forward. |
| L11-006 | plugins/edm/README.md:267 | `set-parent`/`add-related`/`set-supersedes`/`set-forked-from`/`migrate-schema`/`migrate-path`/`validate`/`render-ledger` have no automated caller but are now all documented operator commands -- filter 1. |
| L11-007 | plugins/edm/skills/implement/SKILL.md:198 | `test_layer_skipped` is code-write-only; the Step 8 checklist is its human-facing consumer and the provenance comment names both directions truthfully -- filter 1, re-verified. |
| L11-008 | plugins/edm/hooks/hooks.json:23 | The five prompt hooks instruct two shell commands with no grant surface of their own; consistent across all six prompt hooks in the file -- filter 3. |
| L11-009 | plugins/edm/agents/edm-audit-wiring.md:8 | `KillShell`/`BashOutput` granted with no `Bash` grant on every lens agent -- CA-179's accepted dead-grant surface. |
| L11-010 | plugins/edm/bin/edm-check-grants:429 | Source 3 skips hook prompts with no `spawn ... edm-<agent>` target, so the five prompt hooks stay outside the grant checker; correct by design, the executor is the session -- filters 1 and 3. |
| L11-011 | plugins/edm/bin/tests/wave6-smoke.sh:940 | `test_frameworks_detected` appears in a smoke assertion only as a member of `cmd_set`'s unknown-key error string; folded into L11-002's fix, not a separate finding. |
| L11-012 | plugins/edm/skills/code-audit/SKILL.md:248 | CA-130 reproduced a **seventh** consecutive round on this lens (no `Write`/`Bash`). New data point: the pass-7 output directory holds ten `lens-L*.md` files and zero `.jsonl` files, so the JSONL write path was elided for every lens this round, not only L11. Host-side, not a repository defect. |

## Answer to the specific carry-forward question from a prior attempt this round

**The prior attempt's lead is confirmed, and it is worse than one key.** The
`qc_shard_threshold` class has recurred in **three** `SETTABLE_KEYS` members,
two of them the Jira pair:

- `jira_synced_at` and `jira_project_key` -- producers at
  `plugins/edm/skills/push-jira/SKILL.md:165-166`, zero readers anywhere,
  and the userConfig twin (`user_config.jira_project_key`) is what the
  re-run fallback at `:28` actually reads. Same shadowing shape as
  `qc_shard_threshold`.
- `test_frameworks_detected` -- producer at
  `plugins/edm/agents/edm-test-planner.md:250,255`, zero readers; the
  consumers its provenance comment names read `coverage_by_epic` only.

None of this is documented as intentional (filter 1 fails), the only comment
on them claims the opposite (filter 2 fails), and the sibling keys all have
real readers (filter 3 fails). The enabling gap is that round 6's durability
rule at `plugins/edm/bin/edm-state:1771-1779` is prose with no test behind
it -- `caller_contract_scan` at `plugins/edm/bin/tests/wave7-smoke.sh:57-110`
checks only producer directions.

A separate P1 turned up in scope item 2: all five prompt hooks in
`plugins/edm/hooks/hooks.json` (lines 23, 36, 49, 62, 75) still say step 4
must block when `gate-check` "exits non-zero", while their sibling command
hooks block only on `[ "$ec" -eq 3 ]` and `cmd_gate_check` returns 1 for
setup errors -- so round 6's `GATE_CHECK_REFUSED` split reached the command
hooks but not the prompt hooks it was created for. All five round-6 findings
are otherwise verified fixed.
</content>
