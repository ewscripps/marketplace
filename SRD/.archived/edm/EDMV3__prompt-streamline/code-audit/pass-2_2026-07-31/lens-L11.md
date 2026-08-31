# Code Audit Lens L11: Integration Wiring

- **Date**: 2026-07-31 | **Round**: pass-2 (full, 11 lenses) | **Branch**: `edm/edmv3-prompt-streamline`
- **Scope**: `plugins/edm/**` (bin, bin/tests, skills, agents, hooks, evals, docs, CLAUDE.md,
  CHANGELOG.md, README.md), repository-root `.gitlab-ci.yml` and `.gitignore`
- **Method note**: this lens agent again had no `Write` tool at runtime despite
  `agents/edm-audit-wiring.md:8` granting one. This report was returned as agent text for the
  orchestrator to transcribe. See NOTED-3.

## Part 1 -- Verification of prior-round L11 findings

Verified against the current working tree, not against the ledger's `status` field.

| ID | Prior sev | Verdict | Evidence (current tree) |
|---|---|---|---|
| CA-004 | P0 | **fixed** (round 1) | `skills/code-audit/SKILL.md:51` = `N=$(edm-state audit-round-start <PREFIX> code --lenses "${LENS_SET_CSV}")`; `:38-40` and `:52-58` state the flag is mandatory and why. `cmd_audit_round_start` still derives `round_type` from set size; `cmd_audit_converged` still refuses `partial`. Chain reachable from its only real caller. |
| CA-007 | P1 | **fixed** (L11 half) | `.gitlab-ci.yml:347-352` (`ec=0; out="$(edm-state validate ...)" || ec=$?` then a named `-eq 3` branch), `:494-499`, and `:552-558` (`rc=0; bash ... edm-compare-eval ... || rc=$?` with live `0)`, `3) NOT ARMED`, `*)` arms). `evals/run-eval.sh:443-445` now captures `containment_status` separately. The three dead handlers L11 filed are reachable. |
| CA-013 | P1 | **still open** (L11 half) | `docs/canonical-sections.md` still has **zero** consumers under `plugins/edm/agents/` or `plugins/edm/skills/`. Every reference is `CLAUDE.md:300,724`, `CHANGELOG.md:379,384`, `bin/edm-sync-canonical-sections`, `bin/vocabulary-allowlist.txt:45`, `bin/tests/wave6-smoke.sh:3089`, and the file's own generated header. The generator, the generated file and the drift guard all exist; the consumer half is still unshipped. |
| CA-020 | P1 | **fixed** (with residual, see NOTED-1) | `skills/code-audit/SKILL.md:63` ("Writes its raw report to `${OUTPUT_DIR}/lens-L{N}.md` **and** `${OUTPUT_DIR}/lens-L{N}.jsonl`") and the launch template at `:200` both name the JSONL; `:201` supplies a schema line. Live proof: this round's own prompt named both artifacts. |
| CA-021 | P1 | **fixed** (with residual, see NOTED-2) | All three curation blocks now read "search the **plugin-root-relative** path `docs/audit-patterns/*.md`": `code-audit/SKILL.md:326`, `audit-srd/SKILL.md:163`, `audit-tickets/SKILL.md:181`; each skill carries a "Plugin asset note" header (`code-audit:20`, `audit-srd:18`, `audit-tickets:18`, `plan:18`, `tickets:18`). Writer still at `bin/edm-state:3735-3743` (`${script_dir}/../docs/audit-patterns`); producer and consumer now name the same root. Live test passed -- this agent resolved `plugins/edm/docs/audit-patterns/` without guessing. |
| CA-022 | P1 | **partially fixed -- STILL OPEN** | Fixed on the skill side: `tickets/SKILL.md:47-48`, `audit-tickets/SKILL.md:40,131`. **Not fixed on the agent side**, which the remediation named explicitly: `agents/edm-ticket-writer.md:27,28,29,36,37` still say bare `docs/templates/ticket-size-legend.md` / `cross-cutting-ac.md` / `docs/audit-patterns/ticket-audit.md` with no anchor, no "plugin-root-relative" qualifier, and no plugin-asset note in the file. Same shape at `agents/edm-implementer.md:22-23` and `agents/edm-srd-writer.md:23`. The agent, not the skill, is what runs at write time. |
| CA-048 | P2 | **fixed** | All three blocks now read "Derive the list at presentation time with the `Grep` tool, never from state" (`code-audit:325`, `audit-srd:162`, `audit-tickets:180`); all three grant `Grep` (`:8` in each). `implement/SKILL.md:8` no longer carries the unused `Bash(grep *)`. |
| CA-097 | P2 | **fixed** | `skills/orchestrator/SKILL.md:8` declares `mcp__{jira_mcp_namespace}__atlassianUserInfo`, `...__getAccessibleAtlassianResources`, `...__getJiraIssue`; `:66-69` probes `atlassianUserInfo` first and stops on failure, exactly as `push-jira/SKILL.md:31-34` does. |
| CA-098 | P2 | **fixed** | Launch template `skills/code-audit/SKILL.md:199` now reads `Related docs: ${INIT_DIR}/${user_config.srd_filename}, ${INIT_DIR}/${user_config.ticket_pack_dirname}/`, interpolating the step-3 `edm-state resolve-dir` result (`:44`). No legacy-flat `srd_root/{PREFIX}` remains in the template. Live test passed -- this round's prompt carried the resolved product-scoped path. |
| CA-106 | NOTED | unchanged | `evals/baseline/scores.json` still intentionally absent (D23); `edm-compare-eval` exit 3 is now actually observed by its consumer (CA-007). |
| CA-112 | NOTED | unchanged | Floating `bash:3.2` tag and absent macOS runner remain authorized named exceptions. |
| CA-130 | NOTED | **re-confirmed live** | See NOTED-3. |
| CA-131 | NOTED | unchanged | See NOTED-4. |

## Part 2 -- Findings (L11: Integration Wiring)

| # | Sev | Type | Component/Endpoint | Break In Chain | File:Line |
|---|---|---|---|---|---|
| L11-001 | P1 | Consumer sources a producer that is not in the repository | `bin/_edm-lint-lib.sh` | Two blocking CI jobs plus `run-all.sh` `source` it, but the file is untracked | `plugins/edm/bin/edm-check-grants:101`, `plugins/edm/bin/edm-check-vocabulary:57` |
| L11-002 | P1 | Producer told to emit a schema its contract, its fixtures and its tests reject | Lens JSONL artifact | Skill launch template hands the lens the **ledger** schema; all eleven agent definitions and all eleven committed fixtures declare a different **lens-stage** schema | `plugins/edm/skills/code-audit/SKILL.md:201` vs `plugins/edm/agents/edm-audit-wiring.md:118-120` |
| L11-003 | P2 | Consumer keys on a shape no producer is instructed to emit | `score-artifacts.sh` dimension 5 | Counts prose rows matching `^\| *L{N}-[0-9]+ *\|`; every lens agent's Output Format template shows `\| 1 \|` | `plugins/edm/evals/score-artifacts.sh:448` vs `plugins/edm/agents/edm-audit-wiring.md:95-97` |
| L11-004 | P2 | Consumer reads the derived artifact while the same file declares the other one authoritative | code-audit skill prior-round ledger read | Steps 6 and 7 feed every lens from `findings-ledger.md`, which `:48` and `:18` call "canonical" / "the persistent ledger", while `:70`, `:233` and `:247` declare the JSONL authoritative and the `.md` a render of it | `plugins/edm/skills/code-audit/SKILL.md:18`, `:48`, `:60` vs `:70`, `:233`, `:247` |
| L11-005 | P2 | User-facing recovery instruction points at a destination that does not exist | `push-jira` MCP-unavailable message | Tells the operator to see `CLAUDE.md -> 'Atlassian MCP setup'`; no such section exists anywhere in `plugins/edm/CLAUDE.md` | `plugins/edm/skills/push-jira/SKILL.md:32` |
| L11-006 | P2 | Library document with zero prompt-surface consumers | `docs/audit-patterns/test-coverage-audit.md` | Its four sibling documents each have a named loader; this one has none, and `update-patterns` has no audit type that targets it | `plugins/edm/docs/audit-patterns/test-coverage-audit.md` <- nothing; siblings at `agents/edm-implementer.md:22-23`, `agents/edm-ticket-writer.md:27`, `agents/edm-srd-writer.md:23`; writer map at `bin/edm-state:3740-3743` |
| CA-013 | P1 | Generated artifact with zero consumers (carried, re-confirmed) | `docs/canonical-sections.md` | Generator, generated file and CI drift guard all exist; no skill or agent references it | `plugins/edm/docs/canonical-sections.md:1` <- `plugins/edm/bin/edm-sync-canonical-sections:67` |
| CA-022 | P1 | Plugin asset referenced with no anchor (carried, agent half unfixed) | `edm-ticket-writer`, `edm-implementer`, `edm-srd-writer` | Cwd-relative `docs/...` reads with no plugin-root anchor and no defined failure behaviour | `plugins/edm/agents/edm-ticket-writer.md:27-29,36-37`; `agents/edm-implementer.md:22-23`; `agents/edm-srd-writer.md:23` |

### Details

#### L11-001: the new shared lint library is sourced by two blocking CI jobs and is not in the repository

- **What exists**: `plugins/edm/bin/_edm-lint-lib.sh` (101 lines: `build_line_classes`,
  `is_ignored_line`, `report_violation`) -- the CA-050 extraction that CA-009 and CA-010 were
  routed through.
- **What it is wired to**: `plugins/edm/bin/edm-check-grants:101`
  (`source "${SCRIPT_DIR}/_edm-lint-lib.sh"`) and `plugins/edm/bin/edm-check-vocabulary:57`
  (`source "${SELF_DIR}/_edm-lint-lib.sh"`). Both scripts run `set -euo pipefail`, so a failed
  `source` aborts immediately.
- **The break**: the harness-supplied `git status` for this working tree lists
  `?? plugins/edm/bin/_edm-lint-lib.sh` -- untracked -- while listing the two scripts that source
  it as ` M` (tracked, modified). `.gitignore` does not cover it (checked; the only
  `plugins/edm/` entries are the three `docs/audit-patterns/*` lock/tmp patterns at `:13-15`).
  If the two modified scripts are committed without the new file being added, three CI paths die:
  `lint:grants` (`.gitlab-ci.yml:111`, blocking), `lint:vocabulary` (`:124`, blocking), and
  `test:smoke` via `bin/tests/run-all.sh:121`, which invokes `edm-check-grants` directly and
  attributes the failure to the aggregator.
- **Fix**: `git add plugins/edm/bin/_edm-lint-lib.sh` in the same commit as the two `source`
  lines. Add a smoke assertion that every `source "${...}/_edm-lint-lib.sh"` site resolves to an
  existing file, and consider a CI guard that the library is tracked
  (`git ls-files --error-unmatch plugins/edm/bin/_edm-lint-lib.sh`).
- **Verification**: `git ls-files --error-unmatch plugins/edm/bin/_edm-lint-lib.sh` exits 0.
  Confidence is **medium** solely because this lens cannot run `git`; the shape of the break is
  certain, only the commit state is second-hand.
- **Note for the synthesizer**: two further untracked paths appear in the same snapshot
  (`plugins/edm/bin/tests/fixture...`, truncated). `bin/tests/wave7-smoke.sh:1944-1945` hard-asserts
  `v12-indented-fence.md` exists and `:1985` copies `v01-entity-codes.md`; both are present on disk
  but should be confirmed tracked by the same command.

  **Orchestrator note (added post-report)**: verified via `git ls-files --error-unmatch
  plugins/edm/bin/_edm-lint-lib.sh` -- exits 0, the file IS tracked (committed in 6ddcf0c). This
  lens had no Bash tool and reasoned from a stale pre-commit `git status` snapshot rather than
  live state. Demoted to Not Actionable for this round; not re-investigated unless it goes
  untracked again.

#### L11-002: the lens is instructed to emit the ledger's schema, not the lens schema

- **What exists**: two different JSONL schemas for the same artifact.
  - Lens-stage schema, declared identically in all eleven agent definitions
    (`agents/edm-audit-wiring.md:118`, `edm-audit-security.md:98`, `edm-audit-dry.md:105`,
    `edm-audit-spec.md:110`, `edm-audit-docs.md:92`, and the rest):
    `{"schema":1,"id":null,"lens":"L11","round":N,"round_type":"...","sev":...,"confidence":...,"file":"path","line":42,"title":"...","status":"open"}`
  - Ledger schema, used by the synthesizer's output and by `edm-state render-ledger`
    (`bin/edm-state:2986` reads `.lenses | join("+")` and `.component`; fixtures at
    `bin/tests/wave6-smoke.sh:2493-2495`, `:2674-2679`):
    `{"schema":1,"id":"CA-NNN",...,"lenses":[...],"component":"path","raised_round":N,"resolved_round":null}`
- **What it is wired to**: `skills/code-audit/SKILL.md:201` -- the launch template, the operative
  instruction at spawn time -- hands the lens the **ledger** schema, prefixed "one finding per line
  matching findings-ledger.jsonl".
- **The break**: the eleven committed ground-truth fixtures
  (`bin/tests/fixtures/code-audit/lens-L*.jsonl`) are all in the **lens** shape, and their README
  at `:21-22` states the contract as "per the schema in each lens agent's `## JSONL Line Format`
  section (`{"schema":1,"id":null,"lens":"L{N}",...}`)". So the artifact the fixture set exists to
  pin, the artifact the agent contract specifies, and the artifact the skill actually asks for are
  three-way inconsistent in field names (`lens` vs `lenses`, `file`+`line` vs `component`) and
  directly contradictory on ownership: `agents/edm-audit-wiring.md:120` says "`id` is always `null`
  at the lens stage -- the synthesizer assigns the stable `CA-NNN` ledger ID", while
  `SKILL.md:201` puts `"id":"CA-NNN"` in the lens's own template. This round is again the live
  instance: this agent's prompt carried the ledger schema and an explicit instruction to reuse
  `CA-NNN` IDs, which is the opposite of its own definition file's contract.
- **What it should call**: the lens-stage schema, verbatim from the agent definitions and the
  fixtures.
- **Fix**: replace `SKILL.md:201` with the lens-stage schema, or -- better, given this is one fact
  in thirteen places -- delete the inline schema from the launch template and have it say "emit the
  schema in your own `## JSONL Line Format` section". Add a smoke assertion that the skill's
  template schema string and `agents/edm-audit-*.md`'s schema string are the same field set.
- **Regression note**: this defect did not exist in round 1 -- the skill named no JSONL at all.
  It was introduced by the CA-020 remediation, which added the artifact name and the wrong schema
  together.

#### L11-003: dimension 5 counts a prose row shape the lens agents are never told to write

- **What exists**: `evals/score-artifacts.sh:448` scores lens JSONL/prose agreement by
  `grep -cE "^\| *L${lens_n}-[0-9]+ *\|" "$md_file"`.
- **What it is wired to**: the hand-authored fixture, which uses exactly that shape
  (`bin/tests/fixtures/code-audit/lens-L11.md:5`, `| L11-001 | ... |`; README `:28-32` calls the
  `L{N}-NNN` local ID "what lets dimension 5 compute a real per-lens count comparison").
- **The break**: no lens agent's Output Format template produces it. `edm-audit-wiring.md:95-97`
  shows `| # | Type | ... |` / `| 1 | Frontend -> dummy data | ... |`; `edm-audit-dry.md:82-84` is
  the same plain-integer shape. `skills/code-audit/SKILL.md:204` says only "Write findings +
  'Noted / Not Actionable' section to your markdown file". So `md_count` is 0 for every real round,
  `jsonl_count` is positive, and `score_from_ratio 0 N` gives every lens 0 -- dimension 5 scores
  100 against the fixture that was written to satisfy it and 0 against real output.
- **Why P2 and not P1**: on the automatic path the dimension is skipped, because `run-eval.sh`
  runs `plan -> srd -> audit` and never a code-audit round, so `:429-431` returns
  `"run does not include a code-audit round"` and the score is null. The exposure is the invocation
  `fixtures/code-audit/README.md:49` documents as supported -- pointing the scorer at a real pass
  directory -- where the metric would silently read 0.
- **Fix**: put the `L{N}-NNN` local ID in the Output Format table of all eleven lens definitions
  (`| ID | ... |`, `| L11-001 | ... |`), matching the fixture; or relax the dimension-5 regex to
  count any leading data row. Prefer the former -- the local ID is what makes prose and JSONL
  line-matchable at all.

#### L11-004: the skill routes prior-round context through the derived ledger while calling the JSONL authoritative

- **What exists**: two ledger artifacts with a stated direction --
  `findings-ledger.jsonl` (synthesizer output, authoritative) and `findings-ledger.md`
  (`edm-state render-ledger` output, derived).
- **What it is wired to**: `skills/code-audit/SKILL.md:60` -- "Read the prior
  `findings-ledger.md` if it exists (prior round context for the synthesizer)" -- and `:64`, where
  each lens "Receives the relevant prior-round open findings from the ledger (filtered to its
  lens)". The only ledger the skill has told anyone to read at that point is the markdown.
  `:48` reinforces it: "Ledger: `${INIT_DIR}/code-audit/findings-ledger.md` (canonical cross-round
  path)", as does `:18`, "Persistent findings ledger: ... `findings-ledger.md`".
- **The break**: `:70`, `:233-234` and `:247` all say the JSONL is "the authoritative record" and
  that the synthesizer must not write the `.md`; `:88-91` says `audit-converged` reads the JSONL
  and that the `.md` is for "the presentation counts" only. One file calls two different artifacts
  canonical, and the instruction that actually feeds all eleven lenses names the derived one.
  Because `render-ledger` runs at step 9a of the *previous* round, a round interrupted before 9a
  leaves a stale `.md` next to a current `.jsonl`, and every lens is then briefed off the stale copy.
- **Fix**: change `:60` to read `findings-ledger.jsonl` (falling back to the legacy `.md`, matching
  the synthesizer's own wording at `:68`), and change `:18` and `:48` to name the JSONL as the
  persistent/canonical ledger with the `.md` described as its rendering.

#### L11-005: the Jira failure message routes the operator to a section that does not exist

- **What exists**: `skills/push-jira/SKILL.md:32`, the single user-facing message printed when the
  Atlassian MCP namespace is unreachable -- the only failure path the skill's own Prerequisites
  section (`:19-23`) points at.
- **What it is wired to**: `(see CLAUDE.md -> 'Atlassian MCP setup')`.
- **The break**: `plugins/edm/CLAUDE.md` contains no section, heading or anchor named "Atlassian MCP
  setup"; the string appears exactly once in the whole plugin, in this message. The real
  configuration guidance is `CLAUDE.md:609` and `:866` (the `jira_mcp_namespace` userConfig row)
  and `push-jira/SKILL.md:219`.
- **Fix**: point at what exists -- `CLAUDE.md Sec."Optional: Jira synchronization"` and the
  `jira_mcp_namespace` row, or `push-jira/SKILL.md Sec."Prerequisites"` -- or add the named section.
  Whichever is chosen, use the `Sec."..."` by-name form the rest of the plugin uses so a grep
  finds it.

#### L11-006: one of the five pattern-library documents has no loader

- **What exists**: `docs/audit-patterns/test-coverage-audit.md`, a first-class member of the
  library -- listed in the contract document (`docs/audit-patterns/README.md:14`, `:20`, `:95`) and
  covered by the four-heading contract check.
- **What it is wired to**: nothing on the prompt surface. Each sibling has a named loader:
  `srd-audit.md` <- `agents/edm-srd-writer.md:23` and `skills/plan/SKILL.md:116`;
  `ticket-audit.md` <- `agents/edm-ticket-writer.md:27`; `qc-audit.md` and `code-audit.md` <-
  `agents/edm-implementer.md:22-23`. `agents/edm-test-coverage-auditor.md` -- the one agent whose
  domain it is -- never reads it (no `audit-patterns` reference anywhere in the file), and
  `skills/test-coverage/SKILL.md` does not either.
- **Second half**: it is also write-unreachable. `bin/edm-state:3740-3743` maps the four audit types
  `srd|ticket|qc|code` to the four sibling documents; there is no audit type that targets
  `test-coverage-audit.md`, so `update-patterns` can never append to it. The document is
  read-orphaned and write-orphaned at once.
- **Fix**: add `Read docs/audit-patterns/test-coverage-audit.md` to
  `agents/edm-test-coverage-auditor.md`'s inputs (with the plugin-root anchor CA-022 requires), or
  record in `docs/audit-patterns/README.md` that this document is reference-only with a named
  reason -- silence is the finding.

## Part 3 -- Verified intact (no finding)

Recorded so a later round does not re-walk it. Each was re-checked against the current tree, not
carried forward from round 1.

- **Manifest <-> disk, both directions.** `.claude-plugin/marketplace.json:36-83` declares 14 skills
  and 30 agents; disk has exactly 14 `SKILL.md` and 30 agent files, no undeclared extras, no
  declared absentees. The 11 lens agents match the 11 rows of the lens table at
  `skills/code-audit/SKILL.md:137-149`.
- **`bin/edm-state` three-way agreement, re-counted.** Dispatch (`:4207-4246`), the sentinel help
  block (`:9-53`) and the CLAUDE.md subcommand table each enumerate the same **40** subcommands.
  `print_help` (`:97-99`) extracts between the sentinels with awk, so a new doc line cannot fall out
  of `--help`.
- **Convergence chain, link by link.** `SKILL.md:51` -> `cmd_audit_round_start --lenses` -> lenses
  -> synthesizer -> `findings-ledger.jsonl` -> `render-ledger` -> `audit-round-complete` ->
  `audit-converged` (exit 0/1/3; `BLOCKING_FILTER` includes P2) -> `approve-gate code-audit`, which
  re-runs `audit-converged` -> `cmd_archive`, which re-queries rather than trusting the flag. No
  dead end. The partial-round refusal is live again.
- **Pattern-library write/read loop.** Writer `bin/edm-state:3735-3743` and the three curation
  readers now name the same plugin-relative root; `write_atomic` + `with_state_lock` wrap the splice
  (`:3712`, `:3790`); the missing-heading path SKIPs rather than falling back to EOF (`:3708`,
  `:3779`).
- **MCP wiring.** Both MCP-using skills now probe `atlassianUserInfo` under the configured namespace
  before any other call, and both declare every tool they name in `allowed-tools`
  (`orchestrator:8` = 3 tools, all 3 used; `push-jira:8` = 12 tools, all used at `:31-36`, `:51`,
  `:63-64`, `:116`, `:121`).
- **`bin/` call sites.** `edm-check-grants`: `.gitlab-ci.yml:111` + `run-all.sh:121`.
  `edm-check-vocabulary`: `.gitlab-ci.yml:124`. `edm-check-skill-sync`: `run-all.sh:138` with
  exit-code handling. `edm-sync-canonical-sections`: `wave6-smoke.sh:3089` `--check`.
  `edm-compare-eval`: `.gitlab-ci.yml:553`, now with a live three-arm status branch.
  `edm-lint-artifacts`: `hooks.json:86` + `lint:artifacts`. `edm-init` / `edm-validate-prefix`:
  `orchestrator/SKILL.md:85,97,101` and `plan/SKILL.md:50,59`.
- **Skill grants vs instructions.** Every `Bash(...)` grant in all 14 skills now has at least one
  matching instruction except `verify-runtime`'s `Bash(mkdir *)` (NOTED-5). `tickets`'
  `Bash(edm-init *)` is used at `:135`; `code-audit`'s `Bash(mkdir *)` and `Bash(date *)` at `:59`.
- **Hook wiring.** All six hook families reference commands that exist; the `gate-check` token set
  (`srd`, `tickets`, `audit-tickets`, `implement`) matches the five `UserPromptExpansion` matchers;
  the `SubagentStop` prompt's `edm-state record-partial-verdict <PREFIX> <ticket> PARTIAL '<note>'`
  arg shape matches `cmd_record_partial_verdict`, and `edm-qc-auditor` grants the tools the prompt
  needs.
- **`Sec."..."` cross-references.** 120 references sampled across skills, agents and docs; every
  named target resolves to a real heading (`## Gate PROTOCOL (canonical)` at
  `orchestrator/SKILL.md:123`; `## Severity vocabulary`, `## Mermaid diagram conventions`,
  `## EDM mode matrix`, `## Phase Timing Guidelines`, `## Unverifiable acceptance criteria (D15)`,
  `## Artifact content conventions` in CLAUDE.md; `## Living-Library Contract` and
  `## Append Schema` in `docs/audit-patterns/README.md`; `## Severity Reference`,
  `## Synthesizer Phase`, `## Pending Pattern Entries (gate-time curation)` in
  `code-audit/SKILL.md`), with the single exception in NOTED-6.

## Noted / Not Actionable

1. **CA-020 residual -- the step-8 precondition and the CA-130 fallback did not land.** The
   remediation also asked for "a step-8 precondition that eleven `.jsonl` files exist before the
   synthesizer is spawned" and an explicit "if a lens cannot write, the orchestrator persists both
   halves on its behalf". Neither is in `skills/code-audit/SKILL.md` -- step 8 (`:65`) writes only
   `lenses-run.txt` and step 9 (`:66`) spawns the synthesizer unconditionally. The wiring break
   itself is closed, so this is hardening, not a break; but given NOTED-3 reproduced for a second
   consecutive round, the fallback sentence is the cheapest thing in this report.
2. **CA-021 residual -- absence is still unconditionally authoritative.** All three curation blocks
   still read "**No matches: show nothing** ... Absence is authoritative"
   (`code-audit:331-332`, `audit-srd:168-169`, `audit-tickets:186-187`) with no requirement that the
   directory resolved first. The prescribed "absence of a *resolvable* directory is a hard error"
   was not added. Producer and consumer now agree on the path, so this is residual robustness.
3. **CA-130 re-confirmed live, second consecutive round.** `agents/edm-audit-wiring.md:8` grants
   `Write`; this agent's runtime tool set was `Read, Glob, Grep, WebFetch, WebSearch, TaskStop` --
   no `Write`, no `Bash`. The skill's step-7 write instruction and the agent's "exactly two
   permitted write paths" contract (`:78-84`) are both unfollowable, and this report was again
   returned as text for the orchestrator to transcribe. Host-side gap between a declared grant and
   a delivered capability, not a repository defect -- but see NOTED-1 for the repository-side
   mitigation that is still missing.
4. **CA-131 unchanged, with one new data point.** Whether `${user_config.KEY}` interpolates inside
   prompt text is still not decidable from static reading. This round's prompt carried a fully
   resolved initiative path rather than a `${user_config.srd_root}` literal, which is consistent
   with the orchestrating agent resolving it before spawn -- suggestive, not proof.
5. **`verify-runtime/SKILL.md:8` grants `Bash(mkdir *)` with no `mkdir` instruction.** The only
   `mkdir` on the whole skill surface is `code-audit/SKILL.md:59`. Dead permission surface, the same
   class round 1 noted for `implement`'s `Bash(grep *)` -- which the remediation removed, leaving
   this one as an inconsistency rather than a pattern. Harmless; drop it in the next grant pass.
6. **`CLAUDE.md Sec."Skill-tool composition"` names bold inline text, not a heading.** Cited from
   `orchestrator/SKILL.md:28`, `:152`, `:194`; the target is `**Skill-tool composition**` at
   `CLAUDE.md:24`, inside `### 2. Skills are the source of truth for orchestration`. It is findable
   by the by-name grep the convention prescribes, and `wave7-smoke.sh:2169` asserts on the string,
   so the reference works in practice.
7. **Lens agents grant `KillShell` and `BashOutput` without granting `Bash`.**
   `agents/edm-audit-wiring.md:8` and its ten siblings. Both tools operate only on shells started by
   `Bash`, which is deliberately withheld from a read-only lens, so the two grants can never do
   anything. Uniform across all eleven, therefore consistent-project-pattern; harmless dead grant
   surface rather than a break.
8. **`agents/edm-audit-wiring.md:84` cites `skills/code-audit/SKILL.md:40` for the `mkdir -p`,
   which is at `:59`.** One fact, eleven copies, all stale. Already filed as CA-095 (L10) with the
   right fix (cite the section name, drop the line number); not re-raised here.
9. **`hooks.json:86` still hardcodes `^SRD/` and still branches on any non-zero status.** Both are real
   wiring defects -- a relocated `srd_root` loses all enforcement, and `edm-lint-artifacts`'s
   documented exit-1/exit-2 split (`:31-34`) collapses to one outcome. Already filed as CA-023 and
   CA-011 under L8/L3/L6; not re-raised.
10. **`evals/baseline/scores.json` still absent.** Intentional and documented (D23, CA-106); the
    handler that reports it is now reachable, which was the actionable half.

## JSONL (raw lines for `lens-L11.jsonl`)

See `lens-L11.jsonl`.

## Summary for the coordinator

**Prior L11 findings**: 7 confirmed fixed (CA-004, CA-007, CA-020, CA-021, CA-048, CA-097, CA-098), 2 still open (CA-013, CA-022 -- the latter partially fixed, agent surfaces untouched), 4 NOTED carried.

**New this round**: 1 P1 (L11-002; L11-001 demoted to Not Actionable after orchestrator verification), 4 P2, 5 NOTED.

The remaining P1 deserves fast attention: the CA-020 fix introduced a schema conflict --
`/Users/darryl.porter/projects/marketplace/plugins/edm/skills/code-audit/SKILL.md:201` gives the
lens the ledger schema, contradicting
`/Users/darryl.porter/projects/marketplace/plugins/edm/agents/edm-audit-wiring.md:118-120` and all
eleven committed fixtures. My own prompt this round carried the ledger schema (the operative
instruction), so my own JSONL for this round follows my prompt rather than my own agent contract.
