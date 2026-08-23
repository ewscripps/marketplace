# Findings (L7: Cross-File Consistency) -- Round 11 (full)

**Verification method caveat (CA-130, 11th consecutive round):** this lens received neither `Write` nor `Bash`. Every verdict below is a direct read of the working tree at HEAD (post-`0b2f304`), not a read of a diff. Line numbers are from the current working tree. Report and JSONL are returned as chat text per D22/CA-130.

---

## Part A -- Prior open L7 ledger findings: explicit FIXED / STILL OPEN verdicts

Part A is prose-only and emits no JSONL line except for the one finding still open (CA-496), so a FIXED verdict cannot be misread as a re-filing.

**CA-481 (P2, L3+L7+L8+L5; unswept sites of the CA-446/CA-447 trap convention) -- VERIFIED FIXED, all three parts** (high confidence)

- (a) `plugins/edm/evals/tiering-matrix.sh:158-161` is now the canonical four-arm split, with `RETURN` deliberately kept on the EXIT-equivalent cleanup-only arm exactly as the fix prescribed, and the rationale recorded at `:154-157`. The `"${tmp:-}"` guard against a second process-EXIT firing after `local tmp` has left scope is preserved and documented at `:150-153`.
- (b) `plugins/edm/evals/score-artifacts.sh:766-769` arms a first-stage four-arm trap covering `$_CMP_TA` alone, immediately after the first `mktemp` at `:758`, before the second `mktemp` at `:770`; `:771-774` then widens to both files. This is now structurally identical to the direct sibling `bin/edm-lint-artifacts:153-156` / `:168-171`, which is the file the finding measured it against. The rationale at `:759-765` names the sibling.
- (c) The durability pin landed at `plugins/edm/bin/tests/wave7-smoke.sh:9624-9699`. It scans `bin/*`, `bin/tests/*.sh` and `evals/*.sh` (same `*.awk`/`*.txt` exclusion CI uses, `:9668-9672`), asserts no single trap statement combines `EXIT` with a real signal (`:9674-9677`) and that every EXIT-trapping file also traps `HUP` (`:9679-9682`), and carries **two** real positive controls that construct scratch files reproducing each violation shape and require them to be detected (`:9686-9698`).

**CA-482 (P2, L3+L7; cleanup-then-resume trap shape at six residual sites) -- VERIFIED FIXED, all six sites** (high confidence)

Every site is now the four-arm split, each with a rationale comment: `bin/edm-lint-artifacts:153-156` (comment at `:144-152`), `bin/tests/_harness.sh:88-91` (comment `:85`) and `:122-125` (comment `:120`), `bin/tests/harness-smoke.sh:265-268` (comment `:264`), `bin/tests/wave6-smoke.sh:37-40` (comment `:34`), `bin/tests/wave7-smoke.sh:27-30` (comment `:25`). The `edm-lint-artifacts` self-contradiction-within-twelve-lines that made this P2 rather than NOTED is gone: `:153-156` and `:168-171` now agree, and both agree with the comment at `:164-167`. Thirteen of thirteen cleanup traps in `bin/` + `bin/tests/` + `evals/` follow both halves of the convention `bin/edm-check-grants:124-130` declares.

**CA-496 (P2, L7+L11; CLI-family durability loop) -- STILL OPEN, unchanged, and the count claim is still wrong** (high confidence)

`plugins/edm/bin/tests/wave7-smoke.sh:6733` (was `:6328` in round 10; the line moved, the content did not):
```bash
for ca154_f in edm-state edm-lint-artifacts edm-validate-prefix edm-init edm-check-vocabulary edm-check-grants edm-compare-eval edm-check-skill-sync edm-sync-canonical-sections; do
```
`edm-lint-staged-artifacts` -- the tenth PATH-exposed helper, created by CA-436's own remediation, and the delegate for the plugin's most privileged hook -- is still absent from the list. The comment at `:6757-6759` still reads "so all 12 print_help call sites in the plugin are covered, not just the 9 bin/ helpers"; the true counts are 13 and 10.

The new file remains compliant today (`bin/edm-lint-staged-artifacts:47` sources the shared library, `:50` uses the `${BASH_SOURCE[0]:-$0}` caller convention), so there is no live defect. The finding is that the one property this loop exists to provide -- durability -- is exactly what the newest and most privileged member lacks, and the asymmetry that hides it is unchanged: `lint:bash-syntax` derives its file set from the tree, so the *negative* CA-005 ban at `:6729-6732` covers the new file automatically while the *positive* assertions at `:6733-6747` do not.

This round is the fourth consecutive round it has survived, and it is now the only member of the round-10 assignment still open, in a round where the two other undercount-by-one loop findings (CA-502, CA-531) were both closed. **Fix:** add `edm-lint-staged-artifacts` to `:6733` and correct `:6758`'s counts to 13/10; better, derive the list from the `bin/edm-*` glob minus the underscore-prefixed libraries, which makes the loop self-extending and retires the class.

**CA-497 (P2, L7+L8; `set -uo pipefail` rationale) -- VERIFIED FIXED** (high confidence)

`plugins/edm/bin/edm-lint-staged-artifacts:33-42` now carries the CA-074-shaped rationale directly above `set -uo pipefail` at `:43`. It names all three load-bearing dependencies the finding identified (the bare test-and-assignment statements returning non-zero on their ordinary path, the `repo_root`/`phys_*` command substitutions with load-bearing non-zero status), states the fail-open direction explicitly, cites CA-410/CA-413 as the precedent class, and closes with "Do not 'fix' this to match the other scripts" -- which is the exact one-token change the finding warned a consistency-minded contributor would make. All five `set -uo pipefail` sites in the plugin now carry a rationale (`bin/tests/run-all.sh:10` is the pattern this follows).

**CA-498 (P2, L7; missing `Skill` positive rule in edm-check-grants source 4) -- VERIFIED FIXED** (high confidence)

`plugins/edm/bin/edm-check-grants` now has a third positive rule. The contract is documented at `:479-483` and implemented at `:525-535`: `:528` detects the instruction shape via `grep -qE 'nvoke[^.]*Skill[^.]*tool'`, `:534-535` report through the shared `mark_and_maybe_report` path the `AskUserQuestion` (`:508-509`) and `Task` rules already use. `:482-483` explicitly records that the matcher is deliberately narrower than a bare "Skill tool" mention so `implement/SKILL.md` and `plan/SKILL.md`'s discussion-level references do not false-positive -- the precision the finding asked for, not a blanket token scan.

**CA-502 (P2, L10-owned; the bash-source-file glob triple) -- VERIFIED FIXED; L7 corroborates from the consistency axis** (high confidence)

The in-suite twin at `plugins/edm/bin/tests/wave7-smoke.sh:1130` now globs `"$PLUGIN_DIR"/evals/*.sh` alongside `bin/*` and `bin/tests/*.sh`, so a syntax error in `evals/run-eval.sh`, `evals/score-artifacts.sh` or `evals/tiering-matrix.sh` is caught by a local `bin/tests/run-all.sh` and not only by CI -- closing the divergence from the command `plugins/edm/CLAUDE.md Sec."Testing changes"` presents as the same one CI runs. The three-way pin landed at `:1166-1190`: `:1177` asserts `.gitlab-ci.yml` contains exactly two identical glob-triple loops (`:106` and `:242`), `:1180-1181` asserts the twin itself iterates `evals/*.sh`, and `:1183-1190` is a positive control proving a synthetic two-element glob line does not satisfy the three-element pattern. The rationale at `:1166-1172` names L10 round 9 as the origin.

**CA-529 (P2, L7; `agents/edm-audit-synthesizer.md` tools divergence) -- VERIFIED FIXED, including the durability pin** (high confidence)

All twelve `plugins/edm/agents/edm-audit-*.md` files now carry the byte-identical line
```
tools: Glob, Grep, LS, Read, NotebookRead, WebFetch, TodoWrite, WebSearch, Write
```
(`consistency:5`, `docs:5`, `dead-code:5`, `edge-cases:5`, `runtime:5`, `security:5`, `synthesizer:5`, `test-quality:5`, `dry:8`, `logic:8`, `spec:8`, `wiring:8`). The fix took the direction the finding recommended: the two inert grants (`KillShell`, `BashOutput`, which only operate on shells started by `Bash` that none of the twelve is granted) were dropped from the eleven rather than added to the synthesizer. The pin landed at `bin/tests/wave7-smoke.sh:1741-1768`: `:1750-1754` asserts the twelve lines deduplicate to exactly one distinct value, `:1755-1756` additionally asserts the shared line grants neither inert tool, and `:1758-1768` is a positive control that perturbs a scratch copy of `edm-audit-logic.md`'s line and requires the divergence to be detected. The comment at `:1741-1747` records that round 9's sweep note N10 falsely claimed this family was already byte-identical -- so the ledger's stale durability claim is corrected in the file that now enforces it.

**CA-530 (P2, L7; root `CLAUDE.md` frontmatter template vs. the edm family) -- VERIFIED FIXED** (high confidence)

Root `CLAUDE.md:47-56` now carries an explicit six-line passage taking the second of the two fixes offered: it states that `user-invocable` and `disable-model-invocation` are neither synonyms nor opposites and what each gates, names which plugins use which (`git`/`jira`/`ada-tablo`/`bruno`/`myday` follow the template; `edm`'s 14 skills set `disable-model-invocation` only; `web-cms`'s 14 set both), notes that `edm` and `web-cms` add the `model:`/`effort:` keys the template omits, points at `plugins/edm/CLAUDE.md`'s assignment table, and closes by instructing a contributor to follow that plugin's existing sibling skills rather than the bare template. This is a better outcome than the prescription: it documents the real repository-wide state instead of forcing one convention onto five plugins that legitimately differ.

**CA-531 (P2, L7+L6; CA-483's version pin covering three of four sites) -- VERIFIED FIXED, including the comment arithmetic** (high confidence)

`plugins/edm/bin/tests/wave7-smoke.sh:9605` now extracts the top `##`-level version token from `plugins/edm/CHANGELOG.md`, and `:9620-9622` compares it against `plugin.json`. All four sites are now read and pinned (`plugin.json:9599`, `marketplace.json:9600`, root `CLAUDE.md:9603`, `CHANGELOG.md:9605`). The comment's arithmetic was corrected too: `:9591-9596` now reads "asserted in FOUR independent files", names all four, and explicitly records that "CA-483's tripwire read only three of the four -- CHANGELOG.md was never compared -- which is why this went stale a second time". The prose count and the code count agree, which was the specific defect. The `head`-free extraction discipline (`:9601-9602`, `sed -n '1p'` instead of `head` under `pipefail`) was carried into the new fourth reader rather than reintroduced as a divergence.

**CA-535 (NOTED, L7; `argument-hint` quoting) -- both prescribed edits landed, but the remediation introduced a new inconsistency** (high confidence)

`skills/verify-runtime/SKILL.md:7` is now the bare `<PREFIX>`, matching its seven siblings, and `skills/orchestrator/SKILL.md:7` gained the prescribed trailing comment. The comment's stated rule, however, is contradicted by two siblings in the same family and is not correct as written -- filed below as **L7-11-001**. This is a self-correction: the false YAML claim originated in round 10's own L7-003 write-up and this lens propagated it into the ledger, from where the remediation copied it verbatim into shipped prompt text.

---

## Part B -- New findings this round

**L7-11-001 -- `skills/orchestrator/SKILL.md:7`'s new quoting-rationale comment states a YAML rule that two siblings in the same 14-skill family visibly contradict, and the rule as stated is not correct** (P2, high confidence -- RESIDUAL OF CA-535's remediation)

`plugins/edm/skills/orchestrator/SKILL.md:7`:
```
argument-hint: '<initiative description | /path/to/file | PROJ-123>'  # quoted: the | here is a literal pipe, not the YAML block-scalar indicator -- unquoted it would be parsed as one
```

Three of the fourteen `plugins/edm/skills/*/SKILL.md` `argument-hint` values contain a literal `|`. Exactly one of them is quoted:

- `orchestrator:7` -- `'<initiative description | /path/to/file | PROJ-123>'` (quoted, with the comment above)
- `test:7` -- `<PREFIX> [--fill-gaps | --skip-scaffold]` (unquoted)
- `metrics:7` -- `<PREFIX|--all|--calibrate> [--with-human-baseline]` (unquoted)

So the rule is asserted in one file and violated in two, and the comment that was added to make the exception "read as an exception" instead makes two conforming siblings read as bugs.

The rule is also wrong on the merits, which is why this is a finding rather than a style nit. `|` is a YAML block-scalar indicator only in the **first character position of the value**. All three of these values begin with `<`, which is not a YAML indicator character, so all three are ordinary plain scalars in which a mid-value `|` is just a pipe character. `orchestrator:7`'s quoting is therefore optional, not required. The live proof is in the same directory: `test:7` and `metrics:7` have shipped unquoted through eleven audit rounds and through `validate:manifest`'s frontmatter-parse check, and neither has ever been flagged. For contrast, the genuinely-forced case exists elsewhere in this repository -- `plugins/git/skills/commit/SKILL.md:5` must be quoted, and the reason is the `: ` in `optional type override: feat|fix|...` (a colon-space is illegal in a plain scalar), not the pipes.

Why consistency matters here: this is shipped prompt-surface text in a plugin whose entire thesis is that a documented convention is a contract. A contributor who reads `orchestrator:7` will either add unnecessary quotes to the next skill or "fix" `test:7` and `metrics:7` as latent parse bugs, and the file gives them no way to discover that the stated reason is not the real one. It also matters because the incorrect claim is now load-bearing in two places -- the file and ledger entry CA-535 -- and CA-535 is closed, so nothing will revisit it.

**Fix:** either (a) drop the quotes at `orchestrator:7` so all three `|`-containing siblings agree and the family has one uniform rule, keeping a comment that names the real constraint (`quote only when the value starts with a YAML indicator character or contains `: ``), or (b) keep the quotes and correct the comment to state the actual rule plus why this one value is quoted as a readability choice, and quote `test:7` and `metrics:7` to match. (a) is smaller and is what the family already does at 12 of 14 sites. Amend CA-535's ledger entry either way, since its stated rationale is the source of the error. Optionally pin it: assert that the set of `argument-hint` values containing `|` is uniform in quoting -- a two-line check with the positive control being one perturbed value.

**L7-11-002 -- `bin/edm-state:5341` is now the plugin's last RETURN-scoped cleanup trap with no signal arms, diverging from the sibling CA-481(a) just hardened, and CA-481(c)'s new sweep is structurally blind to it** (P2, medium confidence)

Two functions in this plugin `mktemp` a scratch file into a function-local variable and clean it up with a `RETURN` trap. CA-481(a) hardened one of them this round and left the other untouched:

- `plugins/edm/evals/tiering-matrix.sh:158-161` -- `trap ... RETURN EXIT` + three signal arms, with the rationale at `:148-157` naming the exact failure mode: "RETURN-only leaked `$tmp` on a die (exit 2, no RETURN) or a SIGINT mid-self-test."
- `plugins/edm/bin/edm-state:5341` -- `trap 'rm -f "$_pxt_ignfile"' RETURN`, single arm, no EXIT and no signal coverage.

`pattern_extract_titles` (`:5326-5394`) creates `$_pxt_ignfile` at `:5340`, then runs an awk pass over the audit report at `:5349`, `:5360` or `:5382`. `RETURN` fires on the ordinary path, so there is no leak in normal operation; a signal delivered during the awk pass -- the longest-lived statement between creation and removal, which is the same window CA-449 and CA-481(b) were each filed on -- leaves `${TMPDIR}/edm-pxt-ignored.XXXXXX` behind. This is verbatim the second half of the failure mode `tiering-matrix.sh:148` names.

Both call sites (`:5541`, `< <(pattern_extract_titles ...)`, and `:5654`, a command substitution) run the function in a **subshell**, so an EXIT arm is meaningful and correctly scoped there -- the fix the sibling took is directly applicable rather than a shape mismatch.

The consistency concern is the pin, not the leak. CA-481(c)'s new sweep at `wave7-smoke.sh:9636-9682` cannot see this site, in both of its arms: the `combined` arm only flags a statement combining `EXIT` with a real signal, and a bare `RETURN` trap combines nothing; the `no-hup` arm is **file-granular** (`:9656-9661`, keyed on `FILENAME`), and `bin/edm-state` installs HUP traps at `:695`, `:1510` and `:6081`, so the file is green regardless of what `:5341` does. The sweep was landed specifically because "the convention is stated in prose in one file and enforced nowhere" -- and the one site in the plugin that still does not follow it is the one site the sweep's chosen granularity exempts. That is the same shape as CA-496, CA-231, CA-270 and CA-531: a loop that covers all but one member, where the uncovered member is the one that matters.

Honest blast radius, stated for the false-alarm filter: `update-patterns` is a low-frequency operator command and the leak is a single small file in `TMPDIR`, so this is a P2 on consistency-and-durability grounds, not on impact.

**Fix:** mirror the sibling at `:5341` -- `trap 'rm -f "${_pxt_ignfile:-}"' RETURN EXIT` plus the three signal arms, using the `${_pxt_ignfile:-}` guard for the same reason `tiering-matrix.sh:150-153` documents (the trap is process-wide, so a second firing at EXIT can occur after `local _pxt_ignfile` has left scope, and a bare `"$_pxt_ignfile"` would then trip `set -u`). Then extend CA-481(c)'s sweep with a third arm: for each `trap` line naming `RETURN`, assert the same statement also names `EXIT` -- one added predicate in `_ca481_sweep`, with a scratch positive control in the shape `:9686-9698` already uses.

---

## Noted / Not Actionable

- **N1 -- `bin/edm-lint-staged-artifacts`' inverted exit-code contract** (`:8-10`: exit 2 = violation, exit 1 = setup error) versus the `bin/` family's (1 = violation, 2 = setup/usage). Documented in its own header and in `plugins/edm/CLAUDE.md`'s hooks-behaviour table, and dictated by the host's PreToolUse contract where only exit 2 blocks. Filter 1. Unchanged; carried from rounds 9-10.
- **N2 -- `bin/edm-lint-staged-artifacts` mixes `[EDM]`-prefixed and script-name-prefixed diagnostics** (script-name for the CLI-facing arg-handling path at `:49-50`, `[EDM]` for the hook-facing path). Two internally-uniform layers, consistent with round 8's L7-N06. Filter 3.
- **N3 -- POSIX `[ ]` tests throughout `bin/edm-lint-staged-artifacts` where the sibling `bin/` scripts use `[[ ]]`.** Residue of the `sh` hook string it was extracted from; harmless under its `#!/usr/bin/env bash` shebang at `:1`. Filter 2/3.
- **N4 -- bare `help` token accepted at `bin/edm-lint-staged-artifacts:50` (`-h|--help|help`) and by `edm-init` and `score-artifacts.sh`, but not by `edm-check-skill-sync`, `edm-compare-eval` or `tiering-matrix.sh`.** Standing as **CA-289** with an explicit do-not-re-file disposition ("Two lenses saw it, neither claimed it"). Nothing changed this round.
- **N5 -- the `set -uo pipefail` class is now closed.** All five sites carry a CA-074-shaped rationale: `bin/tests/run-all.sh:10` above `:17`, the three `evals/` drivers, and the last holdout `bin/edm-lint-staged-artifacts:33-42` (CA-497, fixed this round). Round 8's L7-N01 predicate now holds everywhere. No finding.
- **N6 -- `.gitlab-ci.yml:293` and `:632` both carry an EXIT-only `trap 'rm -rf "$TMP"' EXIT`** where the plugin convention is the four-signal split. Container-ephemeral, already dispositioned as round 8's L5-N6, and deliberately outside the `bin/` + `bin/tests/` + `evals/` scope CA-481's convention statement and CA-481(c)'s sweep both take (these are job-script fragments inside YAML, not shell source files). Recorded only so a future round knows the count went from one to two by design rather than treating the second as new. Filter 3.
- **N7 -- the twelve-agent frontmatter family is now fully pinned and fully consistent, no finding.** `tools` (CA-529, fixed this round, asserted at `wave7-smoke.sh:1750-1768` with a positive control) joins `model: opus` / `effort: max` / `maxTurns: 30` / `color: cyan` / `disallowedTools: Edit, NotebookEdit` as verified byte-identical across all twelve `agents/edm-audit-*.md`. Round 9's false N10 durability claim is now true and machine-checked.
- **N8 -- CA-130 reproduced for an 11th consecutive round.** This lens received neither `Write` nor `Bash`, and the delivered prompt is the stale variant: it lacks the `## Scope`, `## Output`, `## JSONL Line Format` and `## When this does NOT apply` sections that `plugins/edm/agents/edm-audit-consistency.md:5`'s own file actually contains. The JSONL schema below was therefore taken from the launch prompt's restated fallback, exactly as D22/CA-130 prescribes. Do not re-file; this is CA-130.
- **N9 -- CA-502 confirmed FIXED but the verdict is L10's to record.** Verified at `wave7-smoke.sh:1173-1190` from the consistency axis and reported in Part A as cross-lens corroboration only; L7 files nothing on it.
- **N10 -- swept and consistent, no finding:** all 14 `skills/*/SKILL.md` `argument-hint` lines (only the `|`-quoting rule diverges -- L7-11-001; the `verify-runtime` outlier CA-535 named is closed); all 13 cleanup traps in `bin/` + `bin/tests/` + `evals/` against the `bin/edm-check-grants:124-130` convention (only the `RETURN`-scoped `edm-state:5341` diverges -- L7-11-002); the two-stage two-mktemp trap shape at `bin/edm-lint-artifacts:153-171` vs `evals/score-artifacts.sh:766-774` (now structurally identical); the four version sites against `plugin.json` (CA-531, pinned); the nine-of-nine `source "${SCRIPT_DIR}/_edm-cli-lib.sh"` literal in `bin/` and three-of-three `source "${SCRIPT_DIR}/../bin/_edm-cli-lib.sh"` literal in `evals/` (assertion set at `wave7-smoke.sh:6733-6764` -- consistent among the members it covers; its *membership* is CA-496); the three positive grant rules in `bin/edm-check-grants` (`AskUserQuestion:498-509`, `Task`, `Skill:525-535`) all routed through the same `mark_and_maybe_report` reporter.
