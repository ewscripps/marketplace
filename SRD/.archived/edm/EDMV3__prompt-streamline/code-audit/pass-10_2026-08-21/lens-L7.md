# Findings (L7: Cross-File Consistency) -- Round 10 (full)

**Verification method caveat:** no `Bash` and no `Write` were delivered to this lens. Every verdict below is a direct read of the tree at HEAD (post-c3467cb), not a read of a diff. Line numbers are from the current working tree.

---

## Part A -- Prior open L7 ledger findings: explicit FIXED / STILL OPEN verdicts

**CA-473 (P1, L1+L3; qc-shard namespaces) -- VERIFIED FIXED** (high confidence)

All five prescribed sites landed, plus the durability pin with a positive control:
- `plugins/edm/hooks/hooks.json:117` now writes `qc/qc-shard-impl-{NN}.md` and explicitly forbids both the bare `qc-shard-{NN}.md` and any `qc-shard-pass-*` name from the hook path.
- `plugins/edm/skills/implement/SKILL.md:84-85` (threshold shards = `qc-shard-pass-{NN}.md`, keyed on shard ordinal), `:106` and `:110` (both pseudo-code branches now agree on `qc-shard-pass-`), `:86-91` (states the disjointness requirement), `:39` and `:114` (merge globs both prefixes).
- `plugins/edm/CLAUDE.md:106-107` documents both rows and the disjointness.
- `plugins/edm/bin/tests/wave7-smoke.sh:8700-8752` extracts both tokens from the files that declare them, asserts inequality, asserts the skill's two branches agree on one token, and carries a real positive control at `:8735-8739`.
- `plugins/edm/bin/edm-state:2551-2561` keeps the phase-6 glob deliberately prefix-agnostic and its comment names both namespaces, so the consumer accepts both producers.

No L7 residual. Do not re-file.

---

**CA-481 (P2, L3+L7+L8+L5; unswept sites of the CA-446/CA-447 trap convention) -- STILL OPEN, all three parts** (high confidence)

(a) `plugins/edm/evals/tiering-matrix.sh:154`:
```bash
trap 'rm -f "${tmp:-}"' RETURN EXIT INT TERM
```
Unchanged. No `HUP`, and no signal-shaped exits. It is now the **only** cleanup trap in `bin/` + `bin/tests/` + `evals/` that follows neither half of the convention `bin/edm-check-grants:124-130` declares plugin-wide. Nine sibling sites use the canonical four-line split form: `edm-check-grants:131-134`, `edm-lint-artifacts:149-152`, `edm-state:692-695` / `:1431-1434` / `:5926-5929`, `edm-sync-canonical-sections:90-93`, `evals/run-eval.sh:276-279`, `evals/score-artifacts.sh:760-763`, `bin/tests/timing.sh:49-52`.

(b) `plugins/edm/evals/score-artifacts.sh:758-763` -- the untrapped one-mktemp window is unchanged. `_CMP_TA` is created at `:758`; the trap is not armed until `:760`. The failure path is covered (`:759`'s `|| { rm -f "$_CMP_TA"; ... }`) but a signal in that window still leaks. The direct sibling `bin/edm-lint-artifacts:134-137` closed exactly this gap with a first-stage trap and documents it at `:134`, so this is now an unjustified divergence between two files doing the identical two-mktemp staging.

(c) The prescribed durability pin **still does not exist**. A repository-wide grep for `CA-446|CA-447|CA-481|CA-482` matches only `CHANGELOG.md:76`, `edm-sync-canonical-sections:84`, `edm-lint-artifacts:134`/`:145`/`:147` and `edm-check-grants:124`/`:129` -- zero hits anywhere under `bin/tests/`. The convention is stated in prose in one file and enforced nowhere, which is precisely why (a), (b) and CA-482's six sites all survived a sweep that named them in scope.

**Fix (unchanged):** convert `:154` to the four-arm form keeping `RETURN` on the EXIT-equivalent arm; arm a first-stage trap immediately after `score-artifacts.sh:758`; land the cross-file sweep assertion (scan `bin/`, `bin/tests/`, `evals/` for cleanup trap lines; assert each names `HUP` and each real signal exits after cleanup) with a positive control.

---

**CA-482 (P2, L3+L7; cleanup-then-resume trap shape at six residual sites) -- STILL OPEN, all six sites** (high confidence)

Verified unchanged at every site:
- `plugins/edm/bin/edm-lint-artifacts:137` -- `trap 'rm -f "$ATTR_PATTERN_FILE"' EXIT INT TERM HUP`, single body, no exits, twelve lines above the same file's canonical four-line form at `:149-152` and directly above its own `:145-148` comment declaring that the three real signals exit with signal-shaped codes after cleanup. The file contradicts itself within twelve lines, and this binary runs on every `git commit` through the PreToolUse hook.
- `plugins/edm/bin/tests/_harness.sh:85`
- `plugins/edm/bin/tests/_harness.sh:114`
- `plugins/edm/bin/tests/harness-smoke.sh:264`
- `plugins/edm/bin/tests/wave6-smoke.sh:34`
- `plugins/edm/bin/tests/wave7-smoke.sh:25`

All five test sites use the single-body form while `bin/tests/timing.sh:49-52` in the same directory uses the four-line form, so the exit-arm half of the convention is applied at 7 of 13 sites. `wave7-smoke.sh:25`'s resume is concretely wrong: a Ctrl-C deletes `$TMP` and the suite continues running assertions against a tree that no longer exists. The contract `bin/edm-state:687-691` states file-wide ("a trap that only cleans up and returns lets the interrupted caller resume") is violated at all six.

---

**CA-496 (P2, L7+L11; CLI-family durability loop) -- STILL OPEN, unchanged, with the count claim still wrong** (high confidence)

`plugins/edm/bin/tests/wave7-smoke.sh:6328` (was `:5900` in round 9; the line moved, the content did not):
```bash
for ca154_f in edm-state edm-lint-artifacts edm-validate-prefix edm-init edm-check-vocabulary edm-check-grants edm-compare-eval edm-check-skill-sync edm-sync-canonical-sections; do
```
`edm-lint-staged-artifacts` -- the tenth PATH-exposed helper, created by CA-436's own remediation, and the delegate for the plugin's most privileged hook -- is still absent. The comment at `:6352-6354` still reads "so all 12 print_help call sites in the plugin are covered, not just the 9 bin/ helpers"; the true counts are 13 and 10.

The new file is compliant today (`bin/edm-lint-staged-artifacts:29` sources the shared library; `:32` uses the `${BASH_SOURCE[0]:-$0}` caller convention), so there is no live defect -- the finding is that the one property this loop exists to provide, durability, is exactly what the newest and most privileged member lacks. The asymmetry that hides it is unchanged: `lint:bash-syntax` derives its file set from the tree, so the negative CA-005 ban covers the new file while the positive assertion does not.

**Fix:** add `edm-lint-staged-artifacts` at `:6328` and correct `:6353`'s counts to 13/10; better, derive the list from the `bin/edm-*` glob minus the underscore-prefixed libraries.

---

**CA-497 (P2, L7+L8; `set -uo pipefail` rationale) -- STILL OPEN, unchanged** (high confidence)

`plugins/edm/bin/edm-lint-staged-artifacts:25` is still a bare `set -uo pipefail` with no rationale comment. The `EDM-HELP-BEGIN`/`EDM-HELP-END` header at `:2-24` documents the exit-code contract and the CA-436 extraction history but says nothing about the shell-option divergence.

The predicate that made round 8's L7-N01 disposition correct still does not hold here. Nine of the ten PATH-exposed `bin/` scripts use the full `set -euo pipefail` (`edm-state:54`, `edm-lint-artifacts:62`, `edm-check-grants:61`, `edm-check-vocabulary:56`, `edm-init:16`, `edm-validate-prefix:15`, `edm-compare-eval:37`, `edm-check-skill-sync:25`, `edm-sync-canonical-sections:39`), and the four *documented* `set -uo pipefail` sites each carry a CA-074-shaped note (`evals/tiering-matrix.sh:65`, `evals/run-eval.sh:66`, `evals/score-artifacts.sh:131`, `bin/tests/run-all.sh:17`). This one carries none.

The omission is load-bearing, verified in the current tree: `:41` and `:42` are bare `[ -n ... ] && assignment` lists that return non-zero on their *ordinary* path (the default case where neither `EDM_SRD_ROOT` nor `CLAUDE_PLUGIN_OPTION_SRD_ROOT` is set), plus the same shape at `:107`, `:110`, `:124`, and load-bearing non-zero command substitutions at `:44`, `:58-59`, `:106`, `:131-132`. Adding `-e` "to match the nine siblings" makes the script exit 1 at `:41` in the default case, and under its own header contract at `:10` exit 1 is **non-blocking** -- so commit-time artifact lint would stop enforcing silently for everyone. That is the same fail-open outcome CA-410 and CA-413 were each filed for, reachable by a one-token change that reads as a consistency improvement.

**Fix:** add the CA-074-shaped rationale comment above `:25` naming the test-and-assignment dependency, the load-bearing command substitutions and the fail-open direction.

---

**CA-502 (P2, L10-owned; the bash-source-file glob triple) -- STILL OPEN on the L7 axis; L10 owns the file** (high confidence)

Re-verified from the consistency axis. The "what is a bash source file" enumeration is still written three times: `lint:bash-syntax` (`.gitlab-ci.yml:104-124`), `lint:shellcheck` (`:240-263`, the same block verbatim modulo tool/job name), and the in-suite twin at `plugins/edm/bin/tests/wave7-smoke.sh:1081-1087`, which omits `evals/*.sh`. The CA-233 three-way consistency assertion at `wave7-smoke.sh:1099-1115` pins only the *exclusion* arm, not the glob list. So a syntax error introduced into `evals/run-eval.sh`, `evals/score-artifacts.sh` or `evals/tiering-matrix.sh` is caught by CI but not by a local `bin/tests/run-all.sh`, which `plugins/edm/CLAUDE.md Sec."Testing changes"` presents as the same command CI runs. No change since round 9. **L7 does not re-file it** -- it is L10's finding and remains correctly attributed there; recorded here as a confirmed STILL OPEN so the synthesizer has cross-lens corroboration.

---

**CA-483 (P2, L6+L7+L9+L11; root CLAUDE.md version row) -- VERIFIED FIXED, including the durability pin** (high confidence)

`CLAUDE.md:61` now reads `**edm** (v3.2.0)`, matching `plugins/edm/.claude-plugin/plugin.json:4`. The prescribed tripwire landed at `plugins/edm/bin/tests/wave7-smoke.sh:8944-8962`: it reads all three tokens and asserts marketplace.json == plugin.json and root CLAUDE.md == plugin.json, with the pipeline deliberately avoiding `head` under `pipefail` (`:8947-8949`). The skill inventory on the same line is still accurate at 14 commands. One residual, filed below as L7-004: `plugins/edm/CHANGELOG.md` -- the fourth site CA-483 itself enumerated -- is not covered by the pin.

---

**CA-498 (P2, L7; missing `Skill` positive rule in edm-check-grants source 4) -- STILL OPEN, unchanged** (high confidence)

`plugins/edm/bin/edm-check-grants`'s `scan_skill_tool_usage` still carries exactly two positive rules: `AskUserQuestion` at `:492-503` and the CA-441 `Task` rule at `:506-516`. There is no `Skill` rule and no `missing-skill-grant` token anywhere in the file. `plugins/edm/CLAUDE.md Sec."Skills are the source of truth for orchestration"` names two caller obligations, the first being that `Skill` must appear in the caller's `allowed-tools`, and grants are explicitly not inherited from a caller -- the identical non-inheritance failure mode CA-441 was filed on. Still no live gap (only `skills/orchestrator/SKILL.md` instructs a Skill-tool invocation and it grants `Skill`), but "no live gap today" is exactly the argument the CA-441 remediation comment at `:471-477` rejected for `Task`.

---

## Part B -- New findings this round

**L7-001 -- `agents/edm-audit-synthesizer.md:5`'s `tools` list diverges from all eleven lens agents, and round 9's own sweep note asserts the opposite** (medium confidence, P2)

The twelve `agents/edm-audit-*.md` files are a single sibling family launched by one skill in one wave. Eleven of them carry a byte-identical grant line:

`plugins/edm/agents/edm-audit-consistency.md:5`, `edm-audit-docs.md:5`, `edm-audit-dead-code.md:5`, `edm-audit-edge-cases.md:5`, `edm-audit-runtime.md:5`, `edm-audit-security.md:5`, `edm-audit-test-quality.md:5`, `edm-audit-dry.md:8`, `edm-audit-logic.md:8`, `edm-audit-spec.md:8`, `edm-audit-wiring.md:8`:
```
tools: Glob, Grep, LS, Read, NotebookRead, WebFetch, TodoWrite, WebSearch, KillShell, BashOutput, Write
```

`plugins/edm/agents/edm-audit-synthesizer.md:5`:
```
tools: Read, Write, Glob, Grep, LS, NotebookRead, WebFetch, TodoWrite, WebSearch
```
Two grants dropped (`KillShell`, `BashOutput`) and the whole list reordered. `model: opus` / `effort: max` / `maxTurns: 30` / `color: cyan` / `disallowedTools: Edit, NotebookEdit` are identical across all twelve, so the divergence is confined to this one field and nothing in either file states it as deliberate.

Why consistency matters here: this is the field that decides what an audit agent can do, and the family is maintained as a block (every round's remediation edits several of these files at once). The synthesizer's list is also the *correct* one on the merits -- `KillShell` and `BashOutput` only operate on shells started by `Bash`, which none of the twelve is granted, so the eleven lens agents carry two inert grants the synthesizer does not. Either direction is defensible; having both, undocumented, in one family is not. The aggravating factor is that round 9's L7 report closed this exact family with sweep note N10 -- "all 12 `agents/edm-audit-*.md` frontmatter blocks (identical `tools`/`model: opus`/...)" -- which is false for `tools`, so a reader of the ledger now believes this family is pinned when it is not.

**Fix:** pick one list (preferably the synthesizer's, dropping the two inert grants from the eleven) and apply it to all twelve; add a wave7 assertion that the twelve `agents/edm-audit-*.md` `tools:` lines are byte-identical, with a positive control that perturbs one and turns red.

---

**L7-002 -- root `CLAUDE.md:47-51` documents `user-invocable: true` as the SKILL.md frontmatter convention; all 14 edm skills use `disable-model-invocation: true` and none carries `user-invocable`** (medium confidence, P2)

Root `CLAUDE.md`'s "SKILL.md Frontmatter" block presents the repository-wide convention as:
```yaml
name: skill-name
description: One-line description
user-invocable: true
argument-hint: '[optional args]'
allowed-tools: ...
```
Every one of the 14 `plugins/edm/skills/*/SKILL.md` files instead sets `disable-model-invocation: true` at line 4 and no `user-invocable` key at all (verified across all 14: `srd:4`, `orchestrator:4`, `test-coverage:4`, `verify-runtime:4`, `implement:4`, `test-plan:4`, `push-jira:4`, `code-audit:4`, `audit-tickets:4`, `plan:4`, `test:4`, `metrics:4`, `tickets:4`, `audit-srd:4`). The two keys are not synonyms and not opposites -- `disable-model-invocation` gates *model* invocation, `user-invocable` gates *user* invocation -- so the documented template and the shipped reality describe different frontmatter contracts.

Why it matters: this is the block a contributor copies when adding a skill to any plugin in this repository, and the edm plugin is the one with CI that will lint the result. A new edm skill written from the documented template gets a key the edm family does not use and misses the key all 14 siblings do use. This is the same shape as CA-483 (root CLAUDE.md documenting the edm plugin and drifting), and root CLAUDE.md is now precedented as in-scope for this initiative.

**Fix:** update root `CLAUDE.md`'s frontmatter block to show `disable-model-invocation: true` (with `model:` and `effort:`, which the edm family also sets and the template omits), or state explicitly that `user-invocable` is the non-edm-plugin convention and `disable-model-invocation` is edm's, naming which plugins use which.

---

**L7-003 -- `argument-hint` quoting diverges inside the 14-skill family with no pattern** (low confidence, NOTED-adjacent P2 -- filed at P2 only because it is a one-token fix in the same file family)

Within `plugins/edm/skills/*/SKILL.md` line 7, eight skills use an unquoted scalar and two quote an equivalent value:
- unquoted: `srd:7`, `test-coverage:7`, `implement:7`, `audit-tickets:7`, `plan:7`, `tickets:7`, `audit-srd:7` (`<PREFIX>` / `<PREFIX> <initiative description>`), `test-plan:7`, `test:7`, `push-jira:7`, `code-audit:7`, `metrics:7`
- quoted: `orchestrator:7` (`'<initiative description | /path/to/file | PROJ-123>'`) and `verify-runtime:7` (`'<PREFIX>'`)

`orchestrator`'s quoting is *required* -- the value contains `|`, which is a YAML block-scalar indicator. `verify-runtime`'s is not: `'<PREFIX>'` is byte-equivalent to the bare `<PREFIX>` seven siblings use. So the family has one justified quote and one unjustified one, and a reader cannot tell which rule is in force.

**Fix:** unquote `verify-runtime:7` to match the seven `<PREFIX>` siblings; leave `orchestrator:7` quoted and add a trailing comment noting the `|` forces it, so the exception reads as an exception.

---

**L7-004 -- the CA-483 version tripwire pins three of the four version sites it was filed against; `plugins/edm/CHANGELOG.md` is the unpinned fourth** (medium confidence, P2)

CA-483 enumerated four version sources of truth: `.claude-plugin/marketplace.json`, `plugins/edm/.claude-plugin/plugin.json`, `plugins/edm/CHANGELOG.md` and root `CLAUDE.md`. The tripwire that landed at `plugins/edm/bin/tests/wave7-smoke.sh:8944-8962` reads and compares exactly three: `plugin.json:8945`, `marketplace.json:8946`, root `CLAUDE.md:8949`. `CHANGELOG.md` is not read.

This is the same undercount-by-one shape the ledger has now filed three times against different loops (CA-231 library header, CA-270 boundary loop, CA-496 CLI-family loop). The stated purpose of the tripwire, in its own comment at `:8939-8942`, is that "the edm plugin version is asserted in three independent files and nothing pinned them together, so the repo-root CLAUDE.md silently drifted to a fourth stale site" -- the comment counts four sites, the code checks three, and the one it omits is the one that made the round-9 finding a *repeat* of CA-127 rather than a first occurrence.

**Fix:** extract the top `##`-level version token from `plugins/edm/CHANGELOG.md` and add a fourth comparison against `plugin.json`; correct the comment's arithmetic at `:8939-8942`.

---

## Noted / Not Actionable

- **N1 -- `bin/edm-lint-staged-artifacts`' inverted exit-code contract** (exit 2 = violation, exit 1 = setup error) versus the `bin/` family's (1 = violation, 2 = setup/usage). Documented in its own header at `:6-11` and in `plugins/edm/CLAUDE.md`'s hooks-behaviour table, and dictated by the host's PreToolUse contract where only exit 2 blocks. Filter 1. Unchanged from round 9's N1.
- **N2 -- `bin/edm-lint-staged-artifacts` mixes `[EDM]`-prefixed and script-name-prefixed diagnostics** (`:34` script-name for the CLI-facing unknown-argument path; `[EDM]` elsewhere for the hook-facing path). Two internally-uniform layers, consistent with round 8's L7-N06. Filter 3.
- **N3 -- POSIX `[ ]` tests throughout `bin/edm-lint-staged-artifacts` where the nine sibling `bin/` scripts use `[[ ]]`.** Residue of the `sh` hook string it was extracted from; harmless under its `#!/bin/bash` shebang at `:1`. Filter 2/3.
- **N4 -- bare `help` token accepted by `edm-init`, `edm-lint-staged-artifacts:32` and `score-artifacts.sh` but not by `edm-check-skill-sync`, `edm-compare-eval` or `tiering-matrix.sh`.** Standing as **CA-289** with an explicit do-not-re-file disposition ("Two lenses saw it, neither claimed it"). Nothing changed this round.
- **N5 -- `set -uo pipefail` at `evals/tiering-matrix.sh:65`, `evals/run-eval.sh:66`, `evals/score-artifacts.sh:131` and `bin/tests/run-all.sh:17`** remains correctly dispositioned under round 8's L7-N01: each of those four sites carries its CA-074 rationale. Only the undocumented `bin/` instance is filed (CA-497, re-confirmed above). Filter 1.
- **N6 -- `.gitlab-ci.yml:291`'s `trap 'rm -rf "$TMP"' EXIT` is EXIT-only** where the plugin convention is the four-signal split. Container-ephemeral; already dispositioned as L5-N6 in round 8 and out of the `bin/`+`evals/` scope CA-481's convention statement covers. Filter 3.
- **N7 -- `bin/tests/wave6-smoke.sh:1960-1965` builds a bare `qc-shard-01.md` fixture**, a filename shape no producer writes since CA-473. The consumer it exercises (`edm-state:2557`) globs `qc/qc-shard-*.md` *deliberately* prefix-agnostically, with the reason stated at `:2551-2554`, so the fixture is still a valid test of that glob and not a contradiction. Stale-looking rather than inconsistent; if anyone wants it tightened it is L4/L9's call, not L7's. Filter 1.
- **N8 -- the five `UserPromptExpansion` hooks in `hooks/hooks.json` are now byte-identical in shape and each passes its own gate token** (`:19` srd, `:32` audit-srd, `:45` tickets, `:58` audit-tickets, `:71` implement). CA-229's residual is closed; the only inter-hook prose difference is `:75`'s extra Gate-3.5 clause, which is genuinely implement-specific. Verified consistent, no finding.
- **N9 -- `skills/metrics/SKILL.md:8` is the only skill with no `Write` and no `TodoWrite` grant.** It is a read-and-report skill that writes no artifact; the narrower grant is the correct direction, not a drift. Filter 3.
- **N10 -- swept and fully consistent, no finding:** all 14 `skills/*/SKILL.md` `model`/`effort` pairs against `plugins/edm/CLAUDE.md`'s "Model and effort assignments" table (10 opus / 4 sonnet: sonnet at `test-coverage`, `verify-runtime`, `push-jira`, `metrics`; `effort: max` at `orchestrator`, `implement`, `code-audit`, `audit-tickets`, `plan`, `test`, `audit-srd`); all 14 carry `disable-model-invocation: true` at line 4 with no exception; the ten-script `die()` family; the nine-of-nine `source "${SCRIPT_DIR}/_edm-cli-lib.sh"` literal in `bin/` and the three-of-three `source "${SCRIPT_DIR}/../bin/_edm-cli-lib.sh"` literal in `evals/` (CA-226 closed, with the tightened literal assertions at `wave7-smoke.sh:6347-6351`); `agents/edm-audit-*.md` `model`/`effort`/`maxTurns`/`color`/`disallowedTools` across all twelve (only `tools` diverges -- L7-001).
- **N11 -- CA-130 reproduced for an 11th consecutive round.** This lens received neither `Write` nor `Bash`, and the delivered prompt is the stale variant: it lacks the `## Scope`, `## Output`, `## JSONL Line Format` and `## When this does NOT apply` sections that `plugins/edm/agents/edm-audit-consistency.md:17-120` actually contains. The JSONL schema was therefore taken from the launch prompt's restated fallback, exactly as D22/CA-130 prescribes. Report and JSONL returned as chat text. Do not re-file; this is CA-130.
- **N12 -- CA-502 confirmed STILL OPEN but deliberately not re-filed by L7.** Correctly owned by L10; the confirmation is recorded above in Part A as cross-lens corroboration only.
