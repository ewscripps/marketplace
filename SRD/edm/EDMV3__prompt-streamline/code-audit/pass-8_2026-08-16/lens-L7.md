# Lens L7: Cross-File Consistency -- round 8 (pass-8, full)

## Prior-round re-verification

### CA-317 -- FIXED
`.gitlab-ci.yml` + `plugins/edm/bin/tests/wave7-smoke.sh`. Both halves landed.
The hand-enumerated list is gone: `wave7-smoke.sh:7899-7915` now extracts every top-level job
key (`grep -E '^[a-z][a-z0-9:_-]*:$'`), extracts each job body by awk range, and for every body
containing `exit 1` asserts a `<job>: FAILED` occurrence, guarded by a `>= 10` floor at :7913 so
a broken key-extraction fails loudly instead of vacuously passing. The bare-`FAIL` ban at :7918
retains its positive control at :7924. I independently enumerated all fourteen top-level jobs in
`.gitlab-ci.yml` and confirmed each prints its own job-named FAILED line:
lint:bash-syntax (:119,:127,:135,:149), lint:artifacts (:171), lint:grants (:190),
lint:vocabulary (:207), lint:shellcheck (:257), lint:hooks-shell (:311),
lint:file-type-ban (:336,:356), lint:pattern-library-contract (:413), test:smoke (:435),
test:smoke-bash32 (:474,:476), test:state-validate (:533), validate:manifest (:562,:642),
validate:plugin-cli (:676,:683), eval:nightly (:720,:725,:740). No holes.

### CA-363 -- FIXED
`plugins/edm/hooks/hooks.json:8` is now
`command -v edm-state >/dev/null 2>&1 && edm-state session-start || true` -- byte-identical in
shape to the Stop hook (:96) and the PreCompact hook (:106). The `2>&1` that remains belongs to
the `command -v` probe, not to `edm-state session-start`, so the inner command's stderr reaches
the user exactly as its two siblings' does. The divergence is gone; no CLAUDE.md exemption note
is needed.

### CA-409 -- STILL OPEN [P2]
`plugins/edm/hooks/hooks.json` -- command hooks :19/:32/:45/:58/:71 vs prompt hooks
:23/:36/:49/:62/:75. The two layers still decide "legitimate first invocation" by two
independently-derived procedures for the same five gates:
- Command layer: validates the prefix character class, then calls
  `edm-state gate-check "$prefix" <cmd>` and blocks **only** on exit 3. An unresolvable prefix
  reaches `cmd_gate_check` -> `read_state` (`bin/edm-state:553-559`), which `die`s at a non-3
  code, so the hook falls through to `exit 0`. Non-blocking by *side effect* of gate-check's own
  error contract.
- Prompt layer: step 3 explicitly runs `edm-state resolve-dir <PREFIX>` first and treats any
  failure as first-invocation, only then running `gate-check` at step 4.
Both reach "allow" today, so there is no live behaviour split -- which is exactly why this can
drift silently. If `cmd_gate_check` ever returned `GATE_CHECK_REFUSED` for an unresolvable prefix
(a plausible hardening), the command layer would start blocking first invocations while the
prompt layer still allowed them. There is a second latent asymmetry: `cmd_resolve_dir`
(`bin/edm-state:4776-4789`) calls `require_jq`, so on a jq-less host the prompt layer classifies a
setup error as "first invocation" and skips gate-check entirely, whereas the command layer runs
gate-check and classifies it via the CA-298 non-3 rule. Same outcome, different reasoning.
**Fix:** delete step 3 from all five prompt hooks and have the prompt mirror the command hook's
single rule verbatim -- "run `edm-state gate-check <PREFIX> <cmd>`; exit 3 blocks, every other
status allows" -- so one procedure exists in one shape at both layers. Alternatively, if the
resolve-dir pre-probe is wanted, add it to the command hooks too. Do not leave two procedures.

### CA-410 -- STILL OPEN [P2] (direction now confirmed)
`plugins/edm/hooks/hooks.json:86` vs `plugins/edm/bin/edm-validate-prefix:42` /
`plugins/edm/bin/edm-init:53` vs `plugins/edm/bin/edm-state:222`.
The prior round asked for `edm-validate-prefix`'s canonical regex to be confirmed before picking a
normalization direction. Confirmed:

| Site | Regex | Role |
|---|---|---|
| `bin/edm-validate-prefix:42` | `^[A-Z][A-Z0-9]{2,5}$` | canonical **creation-time format** (matches CLAUDE.md "3-6 uppercase characters" and `prefix_format_hint`). No `_`, no `-`, bounded length |
| `bin/edm-init:53` | `^[A-Z][A-Z0-9]{2,5}$` | same, agrees byte-for-byte |
| `bin/edm-state:222` (`state_file_for`) | `^[A-Za-z0-9_-]+$` | **path-safety** guard -- deliberately permissive, blocks `/` and `..` |
| `bin/edm-state:261,:263,:3556,:3557,:3561`, `bin/edm-init:74` | `^[A-Za-z0-9_-]+$` | same path-safety class |
| hooks.json `:19,:32,:45,:58,:71` | `''|*[!A-Za-z0-9_-]*` reject == `^[A-Za-z0-9_-]+$` | agrees with the path-safety class |
| **hooks.json `:86` (commit hook)** | **`grep -E '^[A-Z][A-Z0-9_-]*$'`** | **a third class matching neither** |

So there are two legitimate, coherent families -- creation-format and path-safety -- and the
commit hook belongs to neither. It is a superset of the creation regex (allows `_`, `-`, and any
length) and a strict subset of the path-safety regex (rejects lowercase). It fails OPEN: an
initiative whose prefix contains a lowercase character is legal to `state_file_for` and resolvable
by `edm-state resolve-dir`, but its staged paths are filtered out by this grep before
`resolve-dir` is ever consulted, so commit-time artifact lint silently does not run for it. The
awk immediately upstream carries the same uppercase-only assumption in its flat-layout branch
(`parts[1] ~ /^[A-Z]/`).
**Recommended direction: widen, do not tighten.** The commit hook is *discovering* candidate
prefixes from directory names and already gates every candidate through
`EDM_SRD_ROOT="$check_dir" edm-state resolve-dir "$p" >/dev/null 2>&1 || continue`. `resolve-dir`
is therefore the authority on what is a real initiative, and the grep's only job is path-safety.
Tightening it to `^[A-Z][A-Z0-9]{2,5}$` would *enlarge* the fail-open set (more legal initiatives
skipped). Change `:86`'s filter to `grep -E '^[A-Za-z0-9_-]+$'` -- matching `state_file_for` and
the five sibling gate hooks -- and drop the awk's `parts[1] ~ /^[A-Z]/` heuristic in the same
edit so both branches agree. Behaviour for every canonically-created prefix is unchanged; the
silent skip disappears.

### CA-411 -- STILL OPEN [P2]
`plugins/edm/hooks/hooks.json:117` vs `plugins/edm/skills/implement/SKILL.md:80-99` vs
`plugins/edm/agents/edm-qc-auditor.md:79-83` vs `plugins/edm/CLAUDE.md:106` and `:686`.
Nothing changed. The SubagentStop prompt still says, unconditionally, *"Write the QC report to
`<initiative-dir>/qc/qc-summary.md`"* with no mention of sharding. Three other sources describe
the sharded shape: `implement/SKILL.md:82` and `:97` (`qc/qc-shard-{NN}.md` when ticket count
exceeds `user_config.qc_shard_threshold`, default 20), `edm-qc-auditor.md:81` ("Shard N of M:
`qc/qc-shard-{NN}.md`"), and the artifact-layout diagram at `CLAUDE.md:106`. `bin/edm-state:2388-2395`
already accepts either file for phase-6 completion, so the state layer knows about both. The hook
prompt and `CLAUDE.md:686`'s hooks table are the two sources that know only about
`qc-summary.md`. Because the hook fires after *each* `edm-implementer` (6-10 parallel per wave
per `implement/SKILL.md:63`), every auto-spawned auditor is told to write the same
`qc/qc-summary.md`, and when the skill path also shards, the hook-spawned auditor's unsharded
write races the shard merge at `implement/SKILL.md:98`.
**Fix:** give the SubagentStop prompt the same shard-awareness clause the agent body carries --
"if you were given an assigned ticket range, write `qc/qc-shard-{NN}.md`; otherwise write
`qc/qc-summary.md`" -- and update `CLAUDE.md:686`'s hooks-table cell to name both outputs so the
documentation stops agreeing with the gap.

### CA-412 -- STILL OPEN [P2]
`plugins/edm/hooks/hooks.json:117`. Step 4 of the SubagentStop prompt still says *"Resolve the
initiative directory from state using `edm-state resolve-dir <PREFIX>`"* with no instruction for
where `<PREFIX>` comes from. All five UserPromptExpansion sibling prompts (:23, :36, :49, :62,
:75) open with an explicit derivation -- "1. Extract the initiative PREFIX from the first
argument." The SubagentStop prompt has no `$ARGUMENTS` to extract from at all, which is precisely
why it needs a stated source (the epic file it is told to read at step 1, or the ticket IDs
`{PREFIX}-T{NN}` in the implementer's commit messages), rather than a bare placeholder the agent
must guess at.
**Fix:** add a step 0 to the SubagentStop prompt naming the derivation source explicitly, in the
same imperative shape the five siblings use. CA-411 and CA-412 are one edit to one string and
should be remediated together.

## Findings (L7: Cross-File Consistency) -- new this round

| ID | File A | File B | What Differs | Why It Matters | Fix |
|----|--------|--------|---------------|-----------------|-----|
| L7-001 [P1] | `plugins/edm/skills/test/SKILL.md:8`, `plugins/edm/skills/test-plan/SKILL.md:8`, `plugins/edm/skills/test-coverage/SKILL.md:8` | `plugins/edm/skills/plan/SKILL.md:8`, `srd:8`, `audit-srd:8`, `tickets:8`, `audit-tickets:8`, `implement:8`, `code-audit:8`, `orchestrator:8` | All three testing-layer skills spawn agents in their bodies but omit `Task` from `allowed-tools`; all eight Phase-1..6 agent-spawning skills grant it | `skills/test/SKILL.md` spawns 10 agents (`edm-test-planner` :46, `edm-test-scaffold` :72, seven writers :90-96, `edm-test-coverage-auditor` :125); `test-plan` spawns `edm-test-planner` (:39); `test-coverage` spawns `edm-test-coverage-auditor` (:38). Per `plugins/edm/CLAUDE.md` Sec."Skills are the source of truth for orchestration", grants are not inherited from a caller -- the callee's own `allowed-tools` governs. Without `Task` these three skills cannot spawn anything, so `/edm:test`, `/edm:test-plan` and `/edm:test-coverage` are non-functional as written. `bin/edm-check-grants` cannot catch it: its source 4 (`scan_skill_tool_usage`, :454-480) is scoped to `AskUserQuestion` only, and its source 2 cross-references agent grants, never the skill's own | Add `Task` to `allowed-tools` in all three SKILL.md frontmatter lines. Separately, extend `edm-check-grants` source 4 with a second positive rule: a skill body containing a spawn instruction (`Spawn `/`Agent:`/`spawn ... edm-`) whose `allowed-tools` lacks `Task` is a `missing-task-grant` violation -- otherwise the next skill added has the same hole |
| L7-002 [P2] | `plugins/edm/bin/edm-check-grants:127`, `plugins/edm/bin/edm-lint-artifacts:141`, `plugins/edm/bin/tests/wave7-smoke.sh:25`, `plugins/edm/bin/tests/harness-smoke.sh:264`, `plugins/edm/bin/tests/_harness.sh:85`, `:113` | `plugins/edm/bin/edm-sync-canonical-sections:84`, `plugins/edm/bin/tests/wave6-smoke.sh:34`, `plugins/edm/evals/run-eval.sh:259-262`, `bin/edm-state`'s `write_atomic`/`_save_traps` layer | Two scratch-cleanup trap signal sets coexist for the identical concern: `EXIT INT TERM` (6 sites) vs `EXIT INT TERM HUP` (4 sites) | The plugin's own precedent says HUP is required, not optional: CA-150 was filed and fixed specifically because `edm-sync-canonical-sections`'s trap "omits HUP", and CA-252/G7 documents the four-signal `EXIT`/`INT`/`TERM`/`HUP` wrapper idiom in `run-eval.sh:216-237` as the one `write_atomic` already uses. `edm-check-grants:125-126`'s own remediation comment then states the weaker claim that "every sibling covers at least EXIT INT TERM" -- a floor that contradicts the CA-150 precedent and reads as if the family already agrees. On SIGHUP (terminal close, CI runner teardown, `ssh` disconnect) the six 3-signal sites leak their `mktemp -d` scratch directories. `wave7-smoke.sh` is internally inconsistent with itself: its top-level trap at :25 is 3-signal while eleven of its own inner helpers restore 4-signal traps (`trap - EXIT INT TERM HUP` at :4927, :4965, :5001, :5028, :5053, :5093, :5142, :5197, :5352, :7037, :7068) | Add `HUP` to all six 3-signal traps so one signal set exists across the plugin, and rewrite `edm-check-grants:125-126` to state the actual convention (`EXIT INT TERM HUP`, citing CA-150) rather than a floor. Pin it with a smoke assertion in the shape of the existing sentinel-extractor ban: sweep `bin/`, `bin/tests/` and `evals/` for `^\s*trap ` lines installing a cleanup and assert each names HUP |
| L7-003 [P2] | `.gitlab-ci.yml:56-60`, `:78-83` | `plugins/edm/CLAUDE.md:1018-1019` (CI job table), `:1032`, `:1036` | `lint:hooks-shell` (`.gitlab-ci.yml:275-314`, added by CA-380) was landed without updating any of the three sources that enumerate or count the lint jobs | The pipeline now has **8** lint jobs and **11** `<<: *alpine_edm` consumers. `.gitlab-ci.yml:56-60`'s anchor comment still says "seven of them today ... ten consumers total" and even names the command that would prove it wrong (`grep -c '<<: \*alpine_edm'`); `:78-83` still says "seven more the same way ... seven lint jobs total today ... executes all seven concurrently"; `CLAUDE.md`'s CI table has no `lint:hooks-shell` row at all, and `:1032`/`:1036` repeat "all seven concurrently" and "all ten consumers". This is the plugin's single most privileged shell surface (the git-commit hook) whose lint job is invisible in the contributor-facing documentation, and the anchor comment exists specifically so a digest refresh is a single-line change -- a stale consumer count defeats its own stated purpose | Add a `lint:hooks-shell` row to `CLAUDE.md`'s CI job table; correct the three count sentences to 8 lint jobs / 11 consumers. Then make it self-maintaining: `wave7-smoke.sh` already derives blocking jobs programmatically for T67 AC11 (:4580-4615) -- reuse that derivation to assert that every `stage: lint` job key in `.gitlab-ci.yml` appears as a row in `CLAUDE.md`'s CI table, so the next job added cannot land undocumented |

## Noted / Not Actionable

| ID | File:Line | Rationale |
|----|-----------|-----------|
| L7-N01 | `plugins/edm/evals/score-artifacts.sh:121`, `run-eval.sh:63`, `tiering-matrix.sh:65`, `bin/tests/run-all.sh:17` use `set -uo pipefail` where all 9 `bin/` helpers use `set -euo pipefail` | Documented divergence with stated rationale at `score-artifacts.sh:118-120` ("AC5 requires this scorer to exit 0 whenever a score was produced"), at `run-eval.sh`'s CA-074 note, and at `run-all.sh` (an aggregator must not abort on the first failing suite). False Alarm Filter #1 and #3. |
| L7-N02 | `plugins/edm/skills/verify-runtime/SKILL.md:7` (`'<PREFIX>'`) vs `skills/srd/SKILL.md:7` (`<PREFIX>`) | `argument-hint` quoting differs across skills but `<` is not a YAML indicator character, so plain and single-quoted scalars parse identically. Cosmetic only. |
| L7-N03 | `plugins/edm/agents/edm-test-coverage-auditor.md:11` places `disallowedTools` immediately after `tools:`, where all eight other `disallowedTools`-carrying agents place it last | YAML mapping key order is not semantic; `validate:manifest`'s frontmatter check is order-independent. Cosmetic. |
| L7-N04 | `maxTurns` spread across agents: 25 / 30 / 50 / 60 | Every value is documented in `plugins/edm/CLAUDE.md` Sec."Testing layer agent inventory" and Sec."Model and effort assignments"; the 11 lens agents are uniformly 30/opus/max/cyan. Deliberate and recorded. False Alarm Filter #1. |
| L7-N05 | `## Scope` house-style clause present in 13 of 30 agents (11 lenses + synthesizer + explorer) | The adopting set is coherent and matches `CLAUDE.md` Sec."Prompt conventions (house style)" plus the EDMV3-T47 explorer fan-out work. Not drift. |
| L7-N06 | `hooks/hooks.json` diagnostics use an `[EDM] ...` prefix (`:19`, `:86`) where `bin/*` helpers use `<script-name>: ...` (`edm-validate-prefix:27`, `edm-check-grants:74`) | Two layers with two audiences (host-surfaced hook output vs CLI stderr); each is internally uniform across all its own members. |

## Summary for the coordinator

**Prior-round verdicts:** CA-317 FIXED, CA-363 FIXED, CA-409 / CA-410 / CA-411 / CA-412 all STILL OPEN with fresh evidence and line citations.

**CA-410 direction question, now answered:** `plugins/edm/bin/edm-validate-prefix:42` and `plugins/edm/bin/edm-init:53` agree on `^[A-Z][A-Z0-9]{2,5}$` as the creation format. `state_file_for` (`plugins/edm/bin/edm-state:222`) and the five gate hooks agree on `^[A-Za-z0-9_-]+$` as the path-safety class. The commit hook's `grep -E '^[A-Z][A-Z0-9_-]*$'` matches neither. **Widen it to `^[A-Za-z0-9_-]+$`** (and drop the awk's `parts[1] ~ /^[A-Z]/` heuristic in the same edit) -- the hook already gates every candidate through `edm-state resolve-dir`, so `resolve-dir` is the correct authority and tightening would enlarge the fail-open set.

**Highest-value new finding (P1):** `plugins/edm/skills/test/SKILL.md:8`, `plugins/edm/skills/test-plan/SKILL.md:8`, and `plugins/edm/skills/test-coverage/SKILL.md:8` all spawn agents but lack `Task` in `allowed-tools`; all eight Phase-1..6 agent-spawning skills grant it. `edm-check-grants` structurally cannot catch this -- `scan_skill_tool_usage` at `plugins/edm/bin/edm-check-grants:454-480` checks only `AskUserQuestion`.
