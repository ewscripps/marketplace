I could not write files -- no `Write` tool was delivered to this lens (CA-130's stale-cache class, already NOTED). Both halves follow.

## Findings (L7: Cross-File Consistency)

**Verification method caveat:** no `Bash` either, so the `833a06d..HEAD` diff was never executed. Every Priority-1 verification below is a read of the tree **at HEAD**, not a read of the diff.

---

**P2-1 -- `plugins/edm/bin/tests/wave7-smoke.sh:5900` enumerates nine bin/ helpers; the tenth, added by round 8's own remediation, is missing** (high confidence)

The CA-005/CA-154/CA-365 durability loop hardcodes its subject list:

```bash
for ca154_f in edm-state edm-lint-artifacts edm-validate-prefix edm-init edm-check-vocabulary edm-check-grants edm-compare-eval edm-check-skill-sync edm-sync-canonical-sections; do
```

`edm-lint-staged-artifacts` -- created by CA-436's extraction and now the delegate for the plugin's most privileged hook -- is absent. The comment at `:5924-5926` still reads "so all 12 print_help call sites in the plugin are covered"; there are 13. The file conforms today (`/Users/darryl.porter/projects/marketplace/plugins/edm/bin/edm-lint-staged-artifacts:29` sources the shared lib, `:32` uses the `${BASH_SOURCE[0]:-$0}` caller convention), so no live defect -- but the one property this loop exists to provide, durability, is exactly what the newest member lacks. This is the third instance of one shape: CA-231 (library header undercounted consumers by one), CA-270 (boundary loop undercounted by one), now the CLI-family loop. Note the asymmetry that makes it invisible: `lint:bash-syntax`'s CA-005 ban at `.gitlab-ci.yml:126` *derives* its file set from the tree, so the negative rule covers the new file while the positive assertion does not.

**Fix:** add `edm-lint-staged-artifacts` at `:5900` and correct `:5925`'s count to 13. Better, derive the list from `bin/edm-*` minus `_edm-*.sh` the way `lint:bash-syntax:106` derives its sweep, so the eleventh helper cannot repeat this.

---

**P2-2 -- `plugins/edm/evals/tiering-matrix.sh:154` is the last cleanup trap in `bin/` + `evals/` that follows neither half of the now-declared convention** (high confidence)

```bash
trap 'rm -f "${tmp:-}"' RETURN EXIT INT TERM
```

No `HUP`, and no signal-shaped exits. `plugins/edm/bin/edm-check-grants:124-130` now states the convention as plugin-wide in prose -- "the plugin's convention is the FOUR-signal set EXIT INT TERM HUP ... and the three real signals exit with signal-shaped codes after cleanup rather than resuming" -- and nine sibling sites were converted to the four-line form (`edm-check-grants:131-134`, `edm-lint-artifacts:149-152`, `edm-state:692-695` / `:1425-1428` / `:5651-5654`, `edm-sync-canonical-sections:90-93`, `evals/run-eval.sh:271-274`, `evals/score-artifacts.sh:758-761`, `bin/tests/timing.sh:49-52`). `tiering-matrix.sh` was missed by both CA-446 and CA-447. The site's own comment at `:148-153` explains the `RETURN` + `${tmp:-}` reasoning and predates the convention, so nothing there signals the divergence as deliberate.

Compounding it: CA-447's prescribed durability pin ("a smoke assertion sweeping `bin/`, `bin/tests/` and `evals/` for cleanup trap lines and asserting each names HUP") **was never added** -- `wave7-smoke.sh` contains no `CA-446`/`CA-447` assertion at all. The convention is stated in one comment in one file and enforced nowhere.

**Fix:** convert `:154` to the four-line form, keeping `RETURN` on the EXIT-equivalent arm. Land the sweep assertion in the same commit. Cross-link the open CA-446 and CA-447.

---

**P2-3 -- `plugins/edm/bin/edm-lint-staged-artifacts:25` is the only `set -uo pipefail` site in the plugin with no rationale comment, and the omission is load-bearing** (high confidence)

Nine of the ten PATH-exposed `bin/` scripts use `set -euo pipefail` (`edm-state:54`, `edm-lint-artifacts:62`, `edm-check-grants:61`, `edm-check-vocabulary:56`, `edm-init:16`, `edm-validate-prefix:15`, `edm-compare-eval:34`, `edm-check-skill-sync:25`, `edm-sync-canonical-sections:39`). This one uses `set -uo pipefail` with nothing above it explaining why.

Round 8 dispositioned the `set -uo pipefail` divergence NOTED (L7-N01) explicitly on the grounds of "documented rationale at each site" -- `evals/tiering-matrix.sh:61-64`, `evals/run-eval.sh`, `evals/score-artifacts.sh` and `bin/tests/run-all.sh:10-16` each carry a CA-074 note immediately above the line. That predicate does not hold here, and the consequence is not cosmetic. At least five statements in this file are bare `test ... && assignment` lists that return non-zero on their *ordinary* path:

```bash
srd_root_explicit=0
[ -n "${EDM_SRD_ROOT:-}" ] && srd_root_explicit=1        # :41
[ -n "${CLAUDE_PLUGIN_OPTION_SRD_ROOT:-}" ] && srd_root_explicit=1
```

plus `:107`, `:110`, `:124`. Adding `-e` to match the nine siblings makes the script exit 1 at `:41` whenever neither environment variable is set -- the default case. Under the hook's own contract exit 1 is *non-blocking*, so commit-time artifact lint would stop enforcing **silently, for everyone**. That is the same fail-open outcome CA-410 and CA-413 were each filed for, reachable by a one-token "normalization" that looks like a consistency improvement.

**Fix:** add the CA-074-shaped rationale comment above `:25`, naming the `&&`-list dependency and the fail-open direction, so the divergence is intentional on the page.

---

**P2-4 -- the exit-arm half of the trap convention is applied at 7 of 13 sites, including twice within one file** (medium confidence)

`plugins/edm/bin/edm-lint-artifacts:137` arms `trap 'rm -f "$ATTR_PATTERN_FILE"' EXIT INT TERM HUP` -- single body, no exits -- twelve lines above the same file's `:149-152` four-line form, and directly above its own `:145-148` comment declaring that "the three real signals now exit with signal-shaped codes after cleanup (CA-446's cleanup-then-resume class)". A signal in that window cleans up and resumes into the second `mktemp`.

`bin/tests/` is split the same way: `_harness.sh:85`, `_harness.sh:114`, `harness-smoke.sh:264`, `wave6-smoke.sh:34` and `wave7-smoke.sh:25` all use the single-body form, while `timing.sh:49-52` in the same directory uses the four-line form. For `wave7-smoke.sh:25` the resume is concretely wrong: a Ctrl-C deletes `$TMP` and the suite continues running assertions against a scratch tree that no longer exists.

**Fix:** convert the six residual sites in the same pass as P2-2, or state at each why the resume is acceptable there. Sequence with CA-446 and CA-447.

---

**P2-5 -- `bin/edm-check-grants` source 4 gained a `Task` rule but not the `Skill` rule the same contract names** (medium confidence)

`scan_skill_tool_usage` (`:480-518`) now carries two positive rules: `AskUserQuestion` at `:502` and `Task` at `:515`. `plugins/edm/CLAUDE.md Sec."Skills are the source of truth for orchestration"` names **two** caller obligations, the first being "`Skill` must appear in the caller's `allowed-tools`" -- and grants are explicitly not inherited from a caller, which is the identical failure mode CA-441 was filed on. No live gap today: only `skills/orchestrator/SKILL.md` instructs a Skill-tool invocation (`:27`, `:144`, `:149`, `:169`) and it grants `Skill`; `implement/SKILL.md:194` and `plan/SKILL.md:31` mention the tool descriptively. But that is precisely the argument the CA-441 remediation comment at `:474-478` rejected for `Task`: "otherwise the next skill added has the same hole."

**Fix:** add a third positive rule -- a skill body instructing a `Skill`-tool invocation whose `allowed-tools` lacks `Skill` is a `missing-skill-grant` violation.

---

**P2-6 -- repo-root `CLAUDE.md:61` still says `v3.1.0`; three other version statements say `3.2.0`** (medium confidence)

`/Users/darryl.porter/projects/marketplace/CLAUDE.md:61` reads `**edm** (v3.1.0)`. `.claude-plugin/marketplace.json:35`, `plugins/edm/.claude-plugin/plugin.json:4` and `plugins/edm/CHANGELOG.md:7` all read `3.2.0`. CA-431's remediation swept three of the four sites. The skill inventory on that same line is correct (14 skills, matching `plugins/edm/CLAUDE.md`'s "All 14 skills are accounted for"), so only the version drifted.

*Scope note:* repo-root `CLAUDE.md` is not in this round's stated L7 file list (it was in round 8's). Recorded because it is a pure cross-file version drift and a one-line fix.

---

## Noted / Not Actionable

- **N1 -- `edm-lint-staged-artifacts`' inverted exit-code contract** (exit 2 = violation, exit 1 = setup error) versus the `bin/` family's (1 = violation, 2 = setup/usage, per `edm-lint-artifacts`' `die()` default and `_summarize_and_exit:447-455`). Documented in its own header `:6-11` and in `plugins/edm/CLAUDE.md`'s Hooks-behavior table, and dictated by the host's PreToolUse contract that only exit 2 blocks. Filter 1.
- **N2 -- the same file mixes `[EDM]`-prefixed and script-name-prefixed diagnostics** (`:70`, `:87`, `:95`, `:135`, `:139` vs `:34`). These are the hook-facing and CLI-facing layers respectively, consistent with round 8's L7-N06 disposition that the two prefixes are two internally-uniform layers. Filter 3.
- **N3 -- POSIX `[ ]` tests throughout `edm-lint-staged-artifacts` where nine sibling `bin/` scripts use `[[ ]]`.** Residue of the `sh` hook string it was extracted from; harmless under its `#!/bin/bash` shebang. Filter 2/3.
- **N4 -- `bin/edm-state:3143-3148` encodes the two archived layouts a third time** (alongside `list_state_files:137-138` and `archived_state_file_for:161`). It is a destination *constructor*, not a probe; `archived_state_file_for`'s docstring scopes its claim to "every probe of the enumeration", which the constructor is not. Filter 1.
- **N5 -- `.gitlab-ci.yml:291`'s `trap 'rm -rf "$TMP"' EXIT` is EXIT-only.** Container-ephemeral; already dispositioned as L5-N6 in round 8. Filter 1/3.
- **N6 -- bare `help` token accepted by `edm-init:43`, `edm-lint-staged-artifacts:32` and `score-artifacts.sh:771` but not by `edm-check-skill-sync:40`, `edm-compare-eval:48` or `tiering-matrix.sh:82`.** Standing NOTED as **CA-289** with an explicit do-not-re-file. The newly added script lands on the majority side, so nothing changed.
- **N7 -- `set -uo pipefail` in `evals/*.sh` and `run-all.sh`** remains correctly dispositioned under round 8's L7-N01; each of those four sites carries its rationale. Only the new, undocumented `bin/` instance is filed (P2-3).
- **N8 -- CA-130 reproduced for a 10th consecutive round.** This lens received neither `Write` nor `Bash`, so this report is returned as chat text and the `833a06d..HEAD` range was never read as a diff. Do not re-file; this is CA-130.
- **N9 -- verified fixed, re-checked directly against the tree, no finding:** CA-409 (both hook layers now state one rule; `hooks.json:23` explicitly forbids a resolve-dir pre-probe), CA-410 (`edm-lint-staged-artifacts:114-123` widened to the path-safety class, awk uppercase heuristic gone), CA-411/CA-412/CA-440 (`hooks.json:117` now has a step 0 PREFIX derivation and writes `qc-shard-{NN}.md`, with the merge step at `implement/SKILL.md:39`, `:84-85`, `:102-103`), CA-441 (`Task` present in all three testing skills; `edm-check-grants:506-517` adds the rule), CA-460 (`.gitlab-ci.yml:56-58` and `:80-84` now say eight/eleven; `plugins/edm/CLAUDE.md` has the `lint:hooks-shell` row), CA-417/CA-418/CA-419/CA-420, CA-344 items 2/3/4/5, CA-431 (3.2.0 in plugin.json, marketplace.json, CHANGELOG), CA-462 (six scorer dimensions incl. `known-gap-recall`), CA-436/CA-437 (NUL-delimited extraction plus `EXPECTED_COUNT` cross-check at `.gitlab-ci.yml:298-299`, `:320-323`).
- **N10 -- swept and fully consistent, no finding:** all 12 `agents/edm-audit-*.md` frontmatter blocks (identical `tools`/`model: opus`/`effort: max`/`maxTurns: 30`/`color: cyan`/`disallowedTools`); all 14 `skills/*/SKILL.md` `model`/`effort` values against `plugins/edm/CLAUDE.md`'s "Model and effort assignments" table (10 opus / 4 sonnet, effort split exact); the ten-script `die()` family (uniform two-argument form and script-name prefix, with the documented per-script default-code matrix); all eight lint jobs now print a job-named terminal verdict on **both** paths.
- **N11 -- the three `COVERAGE_*_HEADER` constants** (`bin/edm-state:1116-1118`) verified against their row defs and both rendering mechanisms: dash runs match label lengths exactly (5/8/11 and 4/5/8), column widths match the row clamps (14-wide layer, 15-wide epic), and the one sanctioned divergence -- get-coverage's extra trailing `Measured At` column at `:2717` vs metrics-report's three-column form at `:3568` -- matches the row-def split it documents. No hand-built header survives.
- **N12 -- `_edm-cli-lib.sh:5-6`'s "twelve times" and `:19`'s "eight of the twelve"** are historical statements about the pre-CA-005 state, not current consumer counts. Correct as written; not stale.

