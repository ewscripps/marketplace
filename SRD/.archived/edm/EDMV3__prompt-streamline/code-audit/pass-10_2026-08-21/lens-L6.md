# Code Audit -- Lens L6: Documentation Accuracy

**Round:** 10 (full, 11-lens) | **Date:** 2026-08-21 | **Tree:** `edm/edmv3-prompt-streamline` at/after commit `c3467cb`
**Scope:** `plugins/edm/bin/*`, `plugins/edm/bin/tests/*.sh`, `plugins/edm/hooks/hooks.json`, `plugins/edm/monitors/monitors.json`, `plugins/edm/skills/**/SKILL.md`, `plugins/edm/agents/*.md`, `plugins/edm/docs/**/*.md`, `plugins/edm/evals/**`, `plugins/edm/CLAUDE.md`, `plugins/edm/README.md`, `plugins/edm/CHANGELOG.md`, `.gitlab-ci.yml`, root `CLAUDE.md`

**Tooling limitation, disclosed:** this lens agent was delivered without Write, Edit, or Bash tools. The report and JSONL could not be written to `pass-10_2026-08-21/`; they are delivered inline instead. The synthesizer must persist them. All verification below was done with Read/Grep only (no command execution), so counts stated as "N occurrences" are grep-derived, not shell-computed.

---

## Part 1 -- Verdicts on prior open L6 ledger entries

Eight ledger entries name L6 and were `status: open` entering this round: CA-475, CA-483, CA-484, CA-485, CA-486, CA-487, CA-488, CA-489. Each was re-derived against the current tree rather than trusted from the commit message.

| ID | Prior claim | Verdict | Evidence |
|---|---|---|---|
| CA-475 | baseline runbook + T23 ACs still say four/five dimensions | **FIXED** | `plugins/edm/evals/baseline/README.md:50` now says `dimensions_scored: 5`; `:57` heads "Why five scored dimensions, not six"; `:72` "five-dimension baseline"; `:94` adds the Dimension 6 (known-gap-recall) variance row; `:113` adds `known-gap-recall` to the `per_dimension_range` example; `:127` "Six mechanical dimensions -- five of them scored". Ticket side: `epics/03-ci-and-fixture-eval.md:518` "exactly six", `:535-539` defines dimension 6 incl. `srd_match`/`expected.json`, `:578-589` AC8 rewritten as a five-dimension wave-A baseline, `:590-595` AC9 says six per-dimension ranges, `:596` AC10 "six dimensions". Blocking test coupling released: `wave7-smoke.sh:832,836` now assert the literal `five-dimension`. |
| CA-483 | root `CLAUDE.md` edm row stuck at v3.1.0 | **FIXED (doc half); durability half NOT landed** | Root `CLAUDE.md:61` now reads `**edm** (v3.2.0)`, matching `.claude-plugin/marketplace.json:35`. The 14-command inventory on the same line is still correct. However CA-483's prescribed durability pin -- a test asserting root `CLAUDE.md`'s version token equals `marketplace.json`'s -- did **not** land: the only version assertions in `bin/tests/` are `wave7-smoke.sh:1255-1261` (plugin.json vs marketplace.json) and `:8957` (CA-431, same pair). Root `CLAUDE.md` is pinned by nothing. Re-filed below as **L6-01** (the finding CA-483 itself argued for, since this row has now gone stale twice -- CA-127, then CA-483). |
| CA-484 | `score-artifacts.sh:4` says "exactly five dimensions" | **FIXED** | `score-artifacts.sh:4-6` now reads "exactly six dimensions (five as originally specified plus known-gap-recall, added by CA-462 with the 1.0.0 -> 1.1.0 scorer_version bump; --describe below is the authority on the set)". Consistent with `:24`, `:40-43`, and DIM_NAMES. |
| CA-485 | `.gitlab-ci.yml:353` + `plugins/edm/CLAUDE.md:1020` still say "directory-size ceiling" | **FIXED (both sites)** | `.gitlab-ci.yml:376-382` now says "100KB **tracked-bytes** budget (git-tracked files only; untracked eval output under `plugins/edm/evals/runs/` is excluded)" and names CA-463 explicitly as the retired wording; the code below at `:383-402` matches (git ls-files, `wc -c`, ceiling-divide, `runs/` note at `:401`). `plugins/edm/CLAUDE.md:1056` likewise now says "tracked-bytes budget ... untracked eval output under `evals/runs/` is excluded". |
| CA-486 | `plugins/edm/CLAUDE.md:1021` lint:shellcheck row omits the `*.awk` exclusion | **STILL OPEN** | See **L6-02** below. Now at `plugins/edm/CLAUDE.md:1057`. |
| CA-487 | schema_version durability paragraph names the wrong test file and the wrong grep | **FIXED** | The paragraph now names `bin/tests/wave7-smoke.sh` and its verbatim banner, and quotes the pattern the assertion actually runs (`grep -c 'schema_at_least "'`). Re-derived against the tree: `bin/edm-state` has exactly 6 `schema_at_least "` call sites (`:2280, :2447, :2505, :3053, :3897, :4644`) and exactly 5 `# requires schema_version >= ` comments (`:2436, :2498, :3050, :3847, :3888`), sitting at 4 of the 6 call sites; the two without are `cmd_approve_gate`'s precheck (`:2280`) and `cmd_audit_converged` (`:4644`). Every number in the paragraph checks out, and the shipped assertions are at `wave7-smoke.sh:4873-4882`. |
| CA-488 | `plugins/edm/README.md` lists `decisions.md` as optional/on-demand | **STILL OPEN** | See **L6-03** below. Now at `plugins/edm/README.md:210`. |
| CA-489 | `docs/audit-patterns/README.md` pending-count command doesn't produce a count | **STILL OPEN** | See **L6-04** below. Now at `docs/audit-patterns/README.md:88` (the file was restructured by CA-476's fix, which inserted the new "Source-side finding shape" section). |

Additionally re-spot-checked, all still **FIXED / accurate**: CA-012 and CA-152 (pricing prose), CA-031/CA-219 (eval defaults), CA-044 (lint die-message interpolations), CA-070 (`cmd_init` wave literal / skill count), CA-127 (root registry row -- superseded by CA-483/L6-01), CA-460 (CI job table structure), CA-461 (`variance.total_range` field name pinned at `baseline/README.md:118-122`), CA-463 (tiny-svc README), CA-464 (auth-path citation by name not line range).

---

## Findings (L6: Documentation Accuracy)

### L6-01 (P2, high) -- `CLAUDE.md:61` version row is correct today and pinned by nothing; this is its second stale-and-fix cycle
**File:** `CLAUDE.md:61` (repo root); durability gap in `plugins/edm/bin/tests/wave7-smoke.sh`

**What the doc says / did say:** the root registry row is now `**edm** (v3.2.0)` -- correct against `.claude-plugin/marketplace.json:35`, `plugins/edm/.claude-plugin/plugin.json`, and `plugins/edm/CHANGELOG.md`.

**What the code actually does:** nothing enforces the equality. The only version-agreement assertions in the suite are `plugins/edm/bin/tests/wave7-smoke.sh:1255-1261` ("T64 AC1 -- plugin.json and marketplace.json versions agree") and `:8957` ("CA-431 -- marketplace.json edm version matches plugin.json"). Both compare the two JSON manifests to each other. Root `CLAUDE.md`'s prose token is in neither. Grep for `Current Plugins` across `plugins/edm/bin/tests/` returns zero hits.

**Why this is a finding and not a closed item:** the same single row went stale at v2.1.0 (CA-127, round 3, fixed), then again at v3.1.0 (CA-483, round 9, fixed in `c3467cb`). Two fixes, zero mechanism. The row is a specified deliverable (T21 AC2, `epics/03-ci-and-fixture-eval.md:237-243`, verifies it by grep), and it is the first file a contributor to this repository reads. CA-483's own prescription had two halves; only the doc half landed, so round 11 will re-file this from scratch on the next version bump.

**Concrete fix:** add a `wave7-smoke.sh` case in the same computed-count shape as `:1255-1261` -- read the edm entry's `version` from `.claude-plugin/marketplace.json` with `jq -r`, extract the parenthesised token from root `CLAUDE.md`'s `- **edm** (vX.Y.Z)` bullet, and assert equality, failing with both values named. Extend T66 AC1 (`epics/11`) to name the third site so the obligation lives on the ticket as well as in the test.

---

### L6-02 (P2, high) -- `plugins/edm/CLAUDE.md:1057` says `lint:shellcheck` excludes only `*.txt`; the shipped job excludes `*.awk` too (CA-486, unfixed)
**File:** `plugins/edm/CLAUDE.md:1057`

**What the doc says:**
> `` | `lint` | `lint:shellcheck` (EDMV3-T61) | Yes | `shellcheck` over `bin/*`, `bin/tests/*.sh`, and `evals/*.sh` (excluding `*.txt`), scoped to the unquoted-expansion class of findings (SC2086/SC2046/SC2048/SC2068) ... ``

**What the code actually does:** `.gitlab-ci.yml:244-250`:
```
        case "$f" in
          # G24/CA-233 (round 5): *.awk added alongside *.txt -- edm-mermaid-rules.awk is plain
          # awk source (loaded via `awk -f`, never executed as bash), same reason lint:bash-syntax
          # above excludes it. *.txt is a data file (vocabulary-allowlist.txt,
          # vocabulary-prohibited.txt), never shellcheck-able bash source either.
          *.awk|*.txt) continue ;;
        esac
```
Both extensions are skipped, and the code comment explains why.

**Why it is a miss rather than a convention:** the sibling `lint:bash-syntax` row one entry up, at `plugins/edm/CLAUDE.md:1052`, states both exclusions correctly -- "(excluding `*.awk` and `*.txt`)". Only the shellcheck row is wrong.

**Operator harm:** a contributor reading the CI table concludes `bin/edm-mermaid-rules.awk` is shellchecked as bash. Two ways that misleads: chasing nonexistent SC-class findings in an awk file, or adding a second `.awk` helper in the expectation of coverage that does not exist.

**Concrete fix:** change `plugins/edm/CLAUDE.md:1057` to "(excluding `*.awk` and `*.txt`)", matching `:1052` and the shipped case arm. One-token edit; no test change needed (no assertion pins this row's wording).

---

### L6-03 (P2, medium) -- `plugins/edm/README.md:210` classifies `decisions.md` as an optional on-demand file; it is always-present and load-bearing (CA-488, unfixed)
**File:** `plugins/edm/README.md:210`

**What the doc says:**
> See `CLAUDE.md` for the full v2.0 artifact inventory including optional on-demand files (`decisions.md`, `ROLLBACK.md`, `exec-report.md`, `post-deploy/`).

**What the code/spec actually does:** `plugins/edm/CLAUDE.md`'s artifact-layout block annotates `decisions.md` as Must / always-present, alongside `planning.md`, `srd.md`, `architecture.md` and `explorers/` -- not alongside the on-demand set. It is also load-bearing at runtime: `plugins/edm/skills/code-audit/SKILL.md` requires every convergence approval be appended to `decisions.md`, and CLAUDE.md's D15 rule requires every scope change and every AC amendment be recorded there. This initiative's own `decisions.md` (60+ entries, D1-D61) is the working proof.

**False-alarm filter applied and failed:** three of the four items in the same parenthetical (`ROLLBACK.md`, `exec-report.md`, `post-deploy/`) are correctly classified, so this is a single miss inside an otherwise-correct list, not a deliberate simplification. `README.md` is the user-facing document a new adopter reads *before* `CLAUDE.md`, so the wrong classification is read first.

**Concrete fix:** split the parenthetical -- name the always-present files this ASCII tree omits (`architecture.md`, `explorers/`, `decisions.md`) separately from the optional on-demand files (`ROLLBACK.md`, `exec-report.md`, `post-deploy/`). Keep the pointer to `CLAUDE.md` as the inventory authority.

---

### L6-04 (P2, medium) -- `docs/audit-patterns/README.md:88` documents a "pending count" command that cannot produce a count (CA-489, unfixed)
**File:** `plugins/edm/docs/audit-patterns/README.md:88` (test coupling at `plugins/edm/bin/tests/wave7-smoke.sh:3476`)

**What the doc says:**
> The pending count is always `grep -c 'status: pending-review' docs/audit-patterns/*.md` computed at read time -- there is no mirrored count in `.edm-state.json`.

**What the command actually does:** `grep -c` against a multi-file glob prints one `filename:count` line **per file**, not a total. The glob resolves to five library documents (`srd-audit.md`, `ticket-audit.md`, `code-audit.md`, `test-coverage-audit.md`, `qc-audit.md`) plus `README.md` and `SOURCES.md`. An operator or agent running the documented command to answer "how many entries are pending" gets seven prefixed lines and no total. Worse degenerate case: if only one file matched, they get a bare number that silently *under*-reports the real total.

**Why it matters operationally:** this sentence is the documented mechanism behind the Curation-at-Gates flow at `README.md:90-101`, presented at three HITL gates. The count is what the human is shown. The suite's own correct usage at `wave7-smoke.sh:3811` runs the same command against a **single** file, which is exactly why nothing catches the glob case.

**In-family, not a stylistic quibble:** this is the bare-`grep -c` class this plugin has been actively remediating -- CA-392 replaced four bare `grep -c` captures with `count_matches` / `count_matches_strict`, and `wave7-smoke.sh:4894-4898` carries an explicit comment about why a bare `grep -c ... || echo 0` is wrong.

**Concrete fix:** state a command that actually totals -- e.g. `grep -o 'status: pending-review' docs/audit-patterns/*.md | wc -l`, or `grep -h -c` summed -- and update the verbatim-string assertion at `wave7-smoke.sh:3476`, which pins this exact sentence, in the same commit. The doc fix cannot land alone without turning the suite red.

---

## Noted / Not Actionable

- **CA-475, CA-483 (doc half), CA-484, CA-485, CA-487** -- verified FIXED in the current tree with the file:line evidence tabulated in Part 1. Not re-filed. CA-483's *durability* half is re-filed as L6-01; the version token itself is correct.
- **Root `CLAUDE.md:61` uses Unicode em-dash and arrows** -- the plugin's ASCII-only rule (`edm-lint-artifacts`) binds artifacts the plugin *produces* under `SRD/`, not the repository's own root instruction file, which is outside `lint:artifacts`' scan set. Deliberate scope boundary, not drift.
- **`.gitlab-ci.yml:265` "hooks.json's nine command-type hooks"** -- re-derived and correct: SessionStart (1) + five `UserPromptExpansion` command hooks (srd, audit-srd, tickets, audit-tickets, implement) + PreToolUse (1) + Stop (1) + PreCompact (1) = 9. The SubagentStop hook is `type: prompt` and correctly excluded.
- **`.gitlab-ci.yml:58` "eleven consumers" of the `.alpine_edm` anchor** -- re-derived and correct: `<<: *alpine_edm` at `:90, :159, :180, :199, :232, :282, :361, :413, :466, :537, :589`. The named list (eight lint jobs + `test:smoke`, `test:state-validate`, `validate:manifest`) matches exactly; `test:smoke-bash32`, `validate:plugin-cli` and `eval:nightly` correctly do not consume it.
- **`plugins/edm/CLAUDE.md` "Job graph" -- eight lint jobs run concurrently, three `test` jobs carry `needs: ["lint:bash-syntax"]`** -- both re-derived and correct: eight lint jobs all with `needs: []` (`:88, :157, :178, :197, :230, :280, :359, :411`), and `needs: ["lint:bash-syntax"]` at `:471, :503, :541`.
- **`plugins/edm/CLAUDE.md` bin/ table "39 subcommands" for `edm-state`** -- re-derived and correct: the dispatcher at `bin/edm-state:6067-6105` has exactly 39 arms, and the 39 names enumerated in the doc match the 39 in the case statement one-for-one.
- **`plugins/edm/CLAUDE.md` `UserPromptExpansion` exit-code contract row** -- re-derived against `hooks/hooks.json:19, :32, :45, :58, :71` and accurate: missing binary -> `exit 0`; malformed prefix -> `exit 2`; `gate-check` exit 3 (and only 3) -> `exit 2`; every other non-zero -> `exit 0`. The paired prompt hooks at `:23, :36, :49, :62, :75` describe the same rule and do not contradict it.
- **`plugins/edm/CLAUDE.md` PreToolUse row vs `bin/edm-lint-staged-artifacts`** -- accurate: the script's own header (`:6-11`) and the CLAUDE.md row agree that exit 2 = violation/blocking, exit 1 = setup error/non-blocking, exit 0 = clean; the delegate-off-PATH degradation is at `hooks.json:86` and the two extra PATH guards at `edm-lint-staged-artifacts:37-38` are a superset, not a contradiction.
- **`hooks.json:117` SubagentStop shard-namespace prose** -- the prompt now names `qc-shard-impl-{NN}.md`, forbids bare `qc-shard-{NN}.md` and `qc-shard-pass-*.md` by name, cites CA-473/CA-440/CA-411, and states the merge glob. The doc text matches the CA-473 remediation; whether the *code/skill* half agrees is L1/L3/L11 territory, not L6.
- **`docs/audit-patterns/README.md:60-64` source-shape table** -- newly added by the CA-476 fix. Its factual claims about which report carries which finding shape were spot-checked against the cited agent sections and are internally consistent (including the two honest `**None.**` rows and the `extraction_status` table at `:79-83`). Whether `pattern_extract_titles` actually implements it is L1/L11, not L6.
- **`evals/baseline/README.md:3-19` "scores.json does not exist yet"** -- still true (`evals/baseline/` holds only `README.md`), and the file says so plainly. The related complaint that `bin/edm-compare-eval`'s complete:false refusal is unreachable on that path is **L2's** finding (CA-490), already open in the ledger; L6 does not re-file it, and per CA-490's cross-lens resolution the earlier L6 Filter-1 clearance of the `plugins/edm/CLAUDE.md` "visibly refused by edm-compare-eval" wording stands overturned in L2's favour, not re-litigated here.
- **`docs/audit-patterns/README.md:171` "P2 (remediate before convergence) ... deprioritized"** -- checked against the abolished-vocabulary policy; `deprioritized` is not in the prohibited set the blocking `lint:vocabulary` job enforces, and the P0/P1/P2 wording matches the canonical severity scale. Not a finding.
- **`plugins/edm/README.md:214-229` runtime-files/`.gitignore` section** -- claims about `with_state_lock` having more than one lockbase (state + `code-audit/findings-ledger`, CA-382) and about both `edm-init` and `edm-state init` writing the block are consistent with the shape-anchored patterns described; no drift found.
- **Auto-generated / mechanically-synced surfaces excluded per Filter 3** -- `plugins/edm/docs/canonical-sections.md` (generated by `bin/edm-sync-canonical-sections`, has its own sync mechanism and CI check) and `plugins/edm/bin/tests/fixtures/**` (fixture data whose "inaccuracy" is the point).
- **Coverage gap, disclosed rather than silently passed:** the tool set delivered to this agent had no Bash, so per-agent-frontmatter-vs-CLAUDE.md-table reconciliation (models, `effort`, `maxTurns`, `disallowedTools` across all 30 agents) was begun but not completed, and `plugins/edm/CHANGELOG.md`, `monitors/monitors.json`, `evals/README.md` and the 14 `SKILL.md` files received only targeted rather than exhaustive cross-reference checks. No finding was suppressed; these areas are simply not fully swept this round and should be re-swept in round 11 or by a re-run of this lens with Bash available.
