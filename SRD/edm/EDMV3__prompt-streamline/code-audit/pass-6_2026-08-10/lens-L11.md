# Lens L11: Integration Wiring -- Pass 6 (2026-08-10)

**Tooling note (CA-130's class, sixth consecutive round):** Write/Bash absent from
this lens's delivered runtime tool set (Read, Glob, Grep, WebFetch, WebSearch,
TaskStop only). This report was transcribed by the orchestrator from the lens
agent's final message.

Round type: recorded here as `full`. `code-audit/pass-6_2026-08-10/lenses-run.txt` was not readable back by the lens agent at the time it ran; correct the JSONL `round_type` if this round is partial (it is not -- confirmed full by the orchestrator).

## Delivery-layer self-report (diagnostic, not a repository finding)

The on-disk contract is intact and the delivered prompt again lost pieces of it:

- **Both write paths are on disk.** `agents/edm-audit-wiring.md:78-86` names `lens-L11.md` AND `lens-L11.jsonl`; `skills/code-audit/SKILL.md:248-250` carries the literal schema line inside the fenced launch template. **The delivered prompt named only the `.md` path and carried no JSONL schema line at all.** Step 8a's count check (`skills/code-audit/SKILL.md:79-93`) is what will have to catch this.
- **The delivered agent definition is a stale pre-CA-165 revision**, missing `## Scope` (:20-22), `## Output` (:76-86), `## JSONL Line Format` (:114-139), `## When this does NOT apply` (:141-143), the False-Alarm confidence paragraph (:70), and the `docs/canonical-sections.md` read instruction (:90). Its Output Format showed `| # | Type | ... |` with a bare-integer row `| 1 |`; the on-disk template at :95-97 shows `| ID |` with `| L11-001 |`, and `evals/score-artifacts.sh` counts prose rows as `^\| *L11-[0-9]+ *\|`. **This report therefore uses the on-disk `L11-NNN` row format so dimension 5 can count it** -- transcribe the row IDs verbatim.
- Delivered tool set had no `Write` and no `Bash`, so the recovery available to the lens was reading the on-disk definitions itself -- possible only because this round's audit target *is* the repository holding the plugin.

## Findings (L11: Integration Wiring)

| ID | Type | Component/Endpoint | Break In Chain | File:Line |
|----|------|----------------------|-------------------|-----------|
| L11-001 | Settable key with no producer and no reader | `qc_shard_threshold` (CA-246's class, one key over) | In `SETTABLE_KEYS` and numeric-typed, but nothing in skills/agents/hooks sets it and NOTHING anywhere reads it; `implement` reads `user_config.qc_shard_threshold` instead, so an operator's per-initiative override is silently discarded | plugins/edm/bin/edm-state:1677 |
| L11-002 | Subcommands reachable by nobody | `set-supersedes` / `set-forked-from` | Zero callers in skills/agents/hooks/monitors/evals AND no user-facing doc naming either command, while two HANDOFF renderer lines consume the fields they set | plugins/edm/bin/edm-state:4389 |
| L11-003 | Advisory layer disagrees with the deterministic layer it mirrors | five `UserPromptExpansion` prompt hooks | Command hooks block (exit 2) on an invalid/empty prefix before `resolve-dir`; the prompt hooks have no such step and classify that same input as "legitimate first invocation -- allow expansion" | plugins/edm/hooks/hooks.json:23 |
| L11-004 | Five new call sites instructed to run a "read-only" command that writes | `gate-check` read-only label | `cmd_gate_check` calls `record_degraded_check`, which `rmw_state`-writes `.degraded_checks` + `last_updated` on the first legacy-initiative invocation when the state dir is writable | plugins/edm/bin/edm-state:3395 |
| L11-005 | Comment references a dropped subcommand | `lint` in the EDM-HELP rationale comments | Both copies name `lint` as an example subcommand alongside the still-live `update-patterns`; `lint` no longer exists anywhere, so the example is unresolvable | plugins/edm/bin/edm-state:6 |

### Details

#### Finding L11-001: `qc_shard_threshold` is settable, typed, tested -- and read by nothing

- **What exists**: `qc_shard_threshold` is a member of `SETTABLE_KEYS` (`bin/edm-state:1677`) with its own numeric-coercion arm (`:1735`), and it is exercised by the concurrency case at `bin/tests/wave6-smoke.sh:2575`, so it looks fully alive.
- **What it's wired to**: nothing. Zero producers in `skills/`, `agents/`, `hooks/`, `monitors/` (only a hand-run `edm-state set` and the smoke fixtures write it), and **zero readers anywhere in the plugin** -- no `jq` read in `bin/edm-state`, no skill or agent reading it from state.
- **What it should call**: `skills/implement/SKILL.md:85,91` is the only consumer of the concept, and it reads `user_config.qc_shard_threshold`, never state. So `edm-state set <PREFIX> qc_shard_threshold 40` succeeds, persists, and changes nothing -- the userConfig default still governs sharding.
- **Not a false alarm**: the provenance comment immediately above `SETTABLE_KEYS` (`:1665-1671`) names a producer for every other key in the list and says nothing about this one; and the CA-246 precedent is recorded three lines further down (`:1672-1676`: "Deleted entirely rather than kept settable 'for a future producer'"). This is that same class, undetected because the field's userConfig twin makes the feature work.
- **Fix**: either make `implement`'s step 8 read state first and fall back to `user_config` (giving the key a real reader), or delete it from `SETTABLE_KEYS` and its `:1735` typing arm and re-key `wave6-smoke.sh:2575`'s concurrency test onto `current_phase`. Whichever is chosen, extend the `:1665-1671` provenance comment so every `SETTABLE_KEYS` member states a producer *and* a consumer -- the omission is what let this sit.

#### Finding L11-002: two provenance subcommands nobody is ever told to run

- **What exists**: `cmd_set_supersedes` (`bin/edm-state:4389`) and `cmd_set_forked_from` (`:4398`), dispatched at `:5179-5180`, documented in the help sentinel at `:47-48`, with real consumers -- the HANDOFF renderer prints `- **Supersedes**:` / `- **Forked from**:` at `:5055-5056`.
- **What it's wired to**: nothing automatic and no reader-facing instruction. Zero occurrences of either command (or of the words `supersedes` / `forked_from`) anywhere in `skills/`, `agents/`, `hooks/`, `monitors/`, `evals/` or `README.md`.
- **What it should call**: the sibling pair is the control. `set-parent` / `add-related` are named for the user in `README.md:264` ("Product-line linkage ... link related initiatives with `edm-state set-parent ...` and `edm-state add-related ...`") and their state rows in `CLAUDE.md` carry an explicit "(set via `edm-state set-parent <PREFIX> <PARENT>`)" clause. The `supersedes` / `forked_from` rows at `CLAUDE.md:802-803` carry no such clause, so the only place either command surfaces is `edm-state --help`.
- **Fix**: one-line change either way -- add both commands to `README.md:264`'s linkage bullet and add the "(set via ...)" clause to `CLAUDE.md:802-803`, or delete the pair, the two fields, and the two renderer lines the way `last_cmd` was deleted (CA-246).

#### Finding L11-003: the invalid-prefix arm did not travel with the delegation rewrite

- **What exists**: each of the five matcher blocks now pairs a command hook with a prompt hook. The command hook (`hooks.json:19,32,45,58,71`) validates the prefix charset first -- `case "$prefix" in ''|*[!A-Za-z0-9_-]*) echo "[EDM] invalid prefix" >&2; exit 2 ;; esac` -- **before** `resolve-dir`, per CA-253/CA-298's two-branch exit contract.
- **What it's wired to**: the prompt hook's procedure (`hooks.json:23,36,49,62,75`) has three steps: extract the prefix, `resolve-dir` (fail -> allow), `gate-check` (non-zero -> block). An empty or malformed prefix makes `resolve-dir` fail, which step 2 explicitly labels "a legitimate first invocation -- allow expansion." So the two layers classify the same input differently, inside a prompt whose own opening sentence sets the parity expectation ("it must resolve the SAME gate the binary would").
- **What it should call**: the same charset guard, stated as step 1a, with the same "invalid prefix" wording the command hook prints.
- **Severity rationale (P2, not P1)**: the disagreement is in the fail-safe direction -- the deterministic hook still blocks, so no gate opens. The cost is a contradictory advisory message and a parity claim the text does not keep.
- **Fix**: add one clause to each of the five prompt strings distinguishing "no state file yet" (allow) from "malformed prefix argument" (block), and extend the `G31/CA-279` tripwire at `bin/tests/wave7-smoke.sh:6193-6203` with a per-matcher assertion that the prompt names the invalid-prefix case, so the next rewrite cannot drop it again.

#### Finding L11-004: five new instruction sites now carry the "read-only" label onto a command that writes

- **What exists**: `gate-check` is documented read-only in three places -- the help line (`bin/edm-state:32`), the function docstring (`:3338` "Read-only -- never mutates state"), and now, five times over, in the rewritten prompt hooks ("run `edm-state gate-check <PREFIX> srd` (read-only; ...)").
- **What it's wired to**: `cmd_gate_check:3393-3396` calls `record_degraded_check` on the legacy-initiative branch, which at `:1625-1631` does `rmw_state ... .degraded_checks = ... | .last_updated = $ts`. The two pre-checks in front of it narrow the window -- CA-061's idempotence short-circuit (`:1612-1615`) and G22's writability skip (`:1618-1624`) -- but the **first** invocation for a legacy initiative on a writable checkout still takes the write lock, writes a `.bak`, and bumps `last_updated`. The comment block at `:1588-1608` argues the read-only contract is preserved for the *non-writable* case only; it never claims the writable first call is read-only, so False-Alarm filter 2 does not cover this.
- **Consequence**: typing `/edm:srd LEGACY` produces a state-file diff before the prompt is even processed, from a command three separate surfaces call read-only. The prompt hooks add no *new* write (the command hook already fires) but they multiply the inaccurate claim by five and put it in front of a model that is being told to run the command itself.
- **Fix**: either qualify the label at its source (`:32` and `:3338`: "read-only, except a one-time degraded-check breadcrumb on a legacy initiative") and drop the bare "(read-only)" from the five prompt strings, or move the breadcrumb out of `gate-check` into `cmd_phase_start` / `cmd_approve_gate`, which already mutate on the same legacy branch (`:2024`).

#### Finding L11-005: the dropped `lint` subcommand is still named as a live example

- **What exists**: two copies of the EDM-HELP rationale comment, `bin/edm-state:6` and `:120`, both reading "which is exactly how `update-patterns` and `lint` fell out of `--help` before this ticket".
- **What it's wired to**: nothing. `cmd_lint` and its `lint)` dispatch arm were removed this round; `update-patterns` is still live. The sentence now mixes one resolvable name with one that resolves to nothing, and gives a reader grepping for `lint` no signal about which state is intended.
- **Fix**: three words -- "the since-removed `lint`" -- in both copies. (Class is doc-accuracy rather than a live chain break; reported here because it is the residual of the exact drop this round performed.)

## Verified Fixed This Round

| Item | Evidence |
|----|----------|
| CA-247 (`cmd_lint` half) | Zero occurrences of `cmd_lint` or a `lint)` dispatch arm anywhere in `plugins/edm/`. Dispatch carries 39 arms (`bin/edm-state:5146-5184`), matched by 39 `cmd_*` definitions and by the 39 names in `CLAUDE.md:760`'s bin table; the help sentinel block (`:10-53`) has no `lint` line. The `PreToolUse` hook (`hooks.json:86`) calls `edm-lint-artifacts` directly, as it always did. |
| CA-247 (citation half) | `architecture.md:631` now cites `cmd_git_lock_check` **by name with no line range** (CA-095's un-stale-able form) and states explicitly that it is OPERATOR-INVOKED with "nothing in `skills/`, `agents/`, or `hooks/hooks.json` calls it". |
| CA-279 / G31 (this round's prompt-hook rewrite) | All five prompt hooks delegate to `edm-state gate-check <PREFIX> <token>`; each token matches its sibling command hook 1:1 (`srd`, `audit-srd`, `tickets`, `audit-tickets`, `implement`) and all five resolve in `cmd_gate_check`'s case (`:3368-3371`); the `implement` prompt's extra Gate-3.5 clause matches `:3418-3429` exactly; no gate NUMBER remains in any of the five, asserted per-matcher by `wave7-smoke.sh:6193-6203` (delegation `check` + `check_absent` on a hardcoded number). |
| CA-246 (`last_cmd`) | Deleted outright: absent from `SETTABLE_KEYS`, absent from the init payload, both renderer lines gone, and `set` refuses the key -- asserted at `wave7-smoke.sh:6537-6561` including a real `jq -e 'has("last_cmd")' == false` on a fresh state file. |
| Round-5 L11-001 (schema content check) | `skills/code-audit/SKILL.md:95-107` now validates content, not only count: `schema`/`lens`/`sev`/`status` present, `id` literally `null`, explicit refusal on ledger-shaped keys (`lenses`, `component`, `raised_round`), with re-delivery of the verbatim template as the remedy. |
| Round-5 L11-002 (second spawn site) | `skills/code-audit/SKILL.md:275-279` opens "## Synthesizer Phase" with "**Gated on step 8a (CA-193)**" and names the reader-who-skips-here failure mode. |
| Round-5 L11-003 (tripwire scope) | The 19-file enumeration is replaced by a tree-wide scan over `skills/*/SKILL.md` + `agents/*.md` (`wave7-smoke.sh:6379-6421`) with a >=20-file sanity floor and an inside-fence/outside-fence positive control. |

## Chain checks run clean this round

- **Agent spawn coverage**: all 30 files in `agents/` have a live spawn site (11 lenses + synthesizer from `skills/code-audit/SKILL.md:182-192,108,281`; the 10 test agents from `skills/test/`, `test-plan/`, `test-coverage/`; `edm-qc-auditor` from `skills/implement/SKILL.md:37` and `hooks.json:117`). No orphaned agent, and no skill names an agent that does not exist.
- **Step 0 delegation**: all seven non-`plan` phase skills cross-reference `` `skills/plan/SKILL.md Sec."Step 0 -- Gate and Branch Preflight"` `` by name and substitute a `<gated-command>` token that `cmd_gate_check` accepts; the three tokens with no hook (`plan`, `code-audit`, `verify-runtime`) all have skill-side callers.
- **userConfig**: every one of the 20 keys has a consumer -- including the three that looked like install-time-only defaults (`mode`, `compliance_enabled`, `implementation_mode` are read as `CLAUDE_PLUGIN_OPTION_*` at `bin/edm-init:37-39`) and `commit_state_file` (`edm-init:178`), `prefix_format_hint` (`orchestrator/SKILL.md:81`).
- **Env knobs**: every pricing override `CLAUDE.md:471` names is actually read (`bin/edm-state:472-513`), as are `EDM_TOKEN_READ_LINE_CAP` (`:372`) and both documented families (`EDM_RUN_ALL_*`, `EDM_EVAL_*`).
- **Artifact consumers**: `lenses-run.txt` is read by `agents/edm-audit-synthesizer.md:24,180`; `BLOCKING_FILTER`, referenced by name from `skills/code-audit/SKILL.md:319`, exists at `bin/edm-state:1364` and is evaluated at `:4125`.
- **Monitor**: `monitors/monitors.json`'s single entry names a command that dispatches (`watch-impl` -> `cmd_watch_impl:2804`) and carries the `on-skill-invoke:implement` arm trigger `CLAUDE.md` documents.

## Noted / Not Actionable

| ID | File:Line | Rationale |
|----|-----------|-----------|
| L11-006 | SRD/.../architecture.md:631 | `git-lock-check` has zero automatic callers, now documented as OPERATOR-INVOKED by name -- filter 1. |
| L11-007 | plugins/edm/bin/edm-check-grants:429-432 | Source 3 skips any hook prompt with no `spawn ... edm-<agent>` target, so the five new prompt hooks are outside the grant checker; correct by design (the executor is the session, not an agent) and the header scopes source 3 to prompts "that spawn and instruct an agent" -- filters 1 and 3. |
| L11-008 | plugins/edm/skills/implement/SKILL.md:198 | `test_layer_skipped` is code-write-only; the Step 8 checklist is its human-facing consumer and its producer is named in the provenance comment -- filter 1. |
| L11-009 | plugins/edm/README.md:264 | `set-parent`/`add-related`/`migrate-schema`/`migrate-path`/`validate`/`render-ledger` have no automated caller but are documented operator commands -- filter 1. Contrast L11-002, which lacks that documentation. |
| L11-010 | plugins/edm/agents/edm-audit-wiring.md:8 | `KillShell`/`BashOutput` granted with no `Bash` grant on every lens agent -- CA-179's accepted dead-grant surface. |
| L11-011 | plugins/edm/bin/tests/wave6-smoke.sh:2575 | The concurrency test's use of `qc_shard_threshold` as a convenient numeric key is why L11-001 looks alive; folded into that fix, not a separate finding. |
| L11-012 | plugins/edm/CLAUDE.md | The "three `schema_at_least()` call sites lack the canonical comment" admission is documented outstanding work in the same paragraph -- L6/L7's class, filter 1. |
| L11-013 | plugins/edm/hooks/hooks.json:23 | Prompt hooks instruct two shell commands with no grant surface of their own; consistent across all six prompt hooks in the file -- filter 3. |
| L11-014 | plugins/edm/skills/code-audit/SKILL.md:248 | CA-130 reproduced a sixth consecutive round on this lens (no `Write`/`Bash`, stale pre-CA-165 definition, `.jsonl` path elided from the delivered prompt). Host-side, not a repository defect. |
| L11-015 | plugins/edm/skills/code-audit/SKILL.md:62 | CA-131 data point: the delivered prompt again carried a resolved `OUTPUT_DIR` path rather than the literal `${OUTPUT_DIR}`; still not statically decidable. |

---

### `lens-L11.jsonl` (transcribe verbatim, one object per line)

```
{"schema":1,"id":null,"lens":"L11","round":6,"round_type":"full","sev":"P2","confidence":"high","file":"plugins/edm/bin/edm-state","line":1677,"title":"qc_shard_threshold is in SETTABLE_KEYS and numeric-typed but has zero producers in skills/agents/hooks and zero readers anywhere; implement reads user_config.qc_shard_threshold, so a per-initiative override is silently discarded (CA-246's class)","status":"open"}
{"schema":1,"id":null,"lens":"L11","round":6,"round_type":"full","sev":"P2","confidence":"high","file":"plugins/edm/bin/edm-state","line":4389,"title":"set-supersedes/set-forked-from have zero callers anywhere and no user-facing documentation naming either command, while two HANDOFF renderer lines consume the fields they set; the sibling pair set-parent/add-related is documented at README.md:264","status":"open"}
{"schema":1,"id":null,"lens":"L11","round":6,"round_type":"full","sev":"P2","confidence":"high","file":"plugins/edm/hooks/hooks.json","line":23,"title":"the five rewritten UserPromptExpansion prompt hooks omit the invalid-prefix arm their sibling command hooks enforce, classifying a malformed prefix as a legitimate first invocation and allowing expansion where the deterministic layer exits 2","status":"open"}
{"schema":1,"id":null,"lens":"L11","round":6,"round_type":"full","sev":"P2","confidence":"medium","file":"plugins/edm/bin/edm-state","line":3395,"title":"gate-check is labelled read-only in its help line, its docstring and all five new prompt hooks, but record_degraded_check rmw_state-writes .degraded_checks and last_updated on the first legacy-initiative invocation when the state dir is writable","status":"open"}
{"schema":1,"id":null,"lens":"L11","round":6,"round_type":"full","sev":"P2","confidence":"high","file":"plugins/edm/bin/edm-state","line":6,"title":"both EDM-HELP rationale comments (:6 and :120) still name the dropped lint subcommand as an example alongside the still-live update-patterns, leaving a reader with an unresolvable name after this round removed cmd_lint","status":"open"}
{"schema":1,"id":null,"lens":"L11","round":6,"round_type":"full","sev":"NOTED","confidence":"high","file":"SRD/edm/EDMV3__prompt-streamline/architecture.md","line":631,"title":"git-lock-check has zero automatic callers but is now documented as OPERATOR-INVOKED with a by-name citation","status":"noted"}
{"schema":1,"id":null,"lens":"L11","round":6,"round_type":"full","sev":"NOTED","confidence":"high","file":"plugins/edm/bin/edm-check-grants","line":429,"title":"source 3 skips hook prompts with no spawn-an-agent target, so the five prompt hooks are outside the grant checker; correct by design since the executor is the session, not an agent","status":"noted"}
{"schema":1,"id":null,"lens":"L11","round":6,"round_type":"full","sev":"NOTED","confidence":"high","file":"plugins/edm/skills/implement/SKILL.md","line":198,"title":"test_layer_skipped is code-write-only; the Step 8 checklist is its human-facing consumer and its producer is named in the SETTABLE_KEYS provenance comment","status":"noted"}
{"schema":1,"id":null,"lens":"L11","round":6,"round_type":"full","sev":"NOTED","confidence":"high","file":"plugins/edm/README.md","line":264,"title":"set-parent/add-related/migrate-schema/migrate-path/validate/render-ledger have no automated caller but are documented operator commands","status":"noted"}
{"schema":1,"id":null,"lens":"L11","round":6,"round_type":"full","sev":"NOTED","confidence":"high","file":"plugins/edm/agents/edm-audit-wiring.md","line":8,"title":"KillShell/BashOutput granted with no Bash grant on every lens agent -- CA-179's accepted dead-grant surface","status":"noted"}
{"schema":1,"id":null,"lens":"L11","round":6,"round_type":"full","sev":"NOTED","confidence":"high","file":"plugins/edm/bin/tests/wave6-smoke.sh","line":2575,"title":"the concurrency test's use of qc_shard_threshold as a numeric key is why the dead settable key looks alive; folded into L11-001's fix","status":"noted"}
{"schema":1,"id":null,"lens":"L11","round":6,"round_type":"full","sev":"NOTED","confidence":"high","file":"plugins/edm/CLAUDE.md","line":1,"title":"three schema_at_least call sites lacking the canonical requires-comment are documented outstanding work in the same paragraph -- L6/L7 class","status":"noted"}
{"schema":1,"id":null,"lens":"L11","round":6,"round_type":"full","sev":"NOTED","confidence":"medium","file":"plugins/edm/hooks/hooks.json","line":23,"title":"prompt hooks instruct shell commands with no grant surface of their own; consistent across all six prompt hooks in the file","status":"noted"}
{"schema":1,"id":null,"lens":"L11","round":6,"round_type":"full","sev":"NOTED","confidence":"high","file":"plugins/edm/skills/code-audit/SKILL.md","line":248,"title":"CA-130 sixth consecutive round on this lens: no Write/Bash delivered, stale pre-CA-165 agent definition, and the lens-L11.jsonl path plus the JSONL schema line elided from the delivered prompt","status":"noted"}
{"schema":1,"id":null,"lens":"L11","round":6,"round_type":"full","sev":"NOTED","confidence":"medium","file":"plugins/edm/skills/code-audit/SKILL.md","line":62,"title":"CA-131 data point: the delivered prompt again carried a resolved OUTPUT_DIR path rather than the literal ${OUTPUT_DIR}","status":"noted"}
```

Both round-6 changes named for verification are correctly wired end-to-end: `cmd_lint` is gone with no live referent anywhere (39 dispatch arms == 39 `cmd_*` functions == 39 documented names, `PreToolUse` still calls `edm-lint-artifacts` directly), and all five prompt hooks delegate by name with tokens that match their sibling command hooks and resolve in `cmd_gate_check`. The two residuals are L11-005 (the historical comments still naming `lint`) and L11-003/L11-004 (two places where the prompt hooks' prose does not match what the binary they now delegate to actually does).
</content>
