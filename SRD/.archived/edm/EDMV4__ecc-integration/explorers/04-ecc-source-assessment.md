# Explorer 04 -- ECC Source Assessment (verification of `ecc-integration-analysis.md`)

Scope: the `everything-claude-code` checkout at `/Users/darryl.porter/projects/ECC` (upstream
`github.com/affaan-m/everything-claude-code`, revision `19e2f2b4`), read-only, checking the nine
Part 4/5 "adopt" artifacts named in the task plus the Part 8 claims that gate how much to trust
the rest of the document. All line numbers below are `file:line` in the ECC tree unless stated
otherwise.

## Licensing (read first -- gates everything else)

`ECC/LICENSE:1-3` -- **MIT**, "Copyright (c) 2026 Affaan Mustafa". Verified by direct inspection of
the file at the ECC root (same standard EDM's CLAUDE.md "Prompt conventions" section already
applies to `caveman`/`ponytail`). MIT permits verbatim reuse with attribution; nothing in this
tree is more restrictive than the repo-root license.

**GateGuard is the one exception the task flagged, and it is real.** `gateguard-fact-force.js:19-20`
carries its own header: *"Full package with config support: pip install gateguard-ai / Repo:
https://github.com/zunoworks/gateguard"*, and `skills/gateguard/SKILL.md:5` sets
`metadata: origin: community`. ECC vendored a third party's hook rather than authoring it. **This
document did not fetch `zunoworks/gateguard`'s own license** (no network access; out of scope for
a read-only local-tree assessment) -- if EDM vendors or ports `gateguard-fact-force.js`, that
license must be checked independently before treating MIT-via-ECC as sufficient provenance. Record
this as an open item for whoever executes 4.1, not as resolved here.

## 1. `scripts/hooks/gateguard-fact-force.js` -- VERDICT: LIFT AS-IS (vendor the Node file), with a bash-rewrite alternative sized below

**Real line count: 1,301 lines** (`gateguard-fact-force.js:1-1301`) -- matches the analysis's
"~1,300" almost exactly.

**Verified, matching the analysis:**
- Three-stage DENY/FORCE/ALLOW flow, confirmed structurally: first-touch Edit/Write/MultiEdit and
  every destructive Bash are denied (`run():1207-1295`), the denial reason is the numbered fact
  list, and a retry after the first denial returns `rawInput` unmodified (allow) because the target
  key is now in `state.checked` (`isChecked():934-941`).
- Deny shape exactly as claimed: `denyResult():1158-1174` returns
  `{hookSpecificOutput: {hookEventName: 'PreToolUse', permissionDecision: 'deny',
  permissionDecisionReason: <text>}}`.
- Edit's four facts verified verbatim at `editGateMsg():1062-1076`: importers (Glob/Grep/Bash),
  affected public functions/classes, data-file field/structure/date-format (redacted/synthetic
  values), quote the user's instruction.
- Write's swap of facts 1/2 verified verbatim at `writeGateMsg():1078-1092`: name the caller
  file(s)/line(s), confirm no existing file serves the purpose -- facts 3/4 unchanged.
- Destructive-Bash's three facts verified verbatim at `destructiveBashMsg():1108-1120`: files/data
  affected, one-line rollback, quoted instruction.
- Routine Bash gated once per session, confirmed at `run():1284-1292` via the
  `ROUTINE_BASH_SESSION_KEY` sentinel -- one deny, then permanently allowed for the rest of the
  session (subject to the 30-minute timeout below).
- `MultiEdit` handled per-file, confirmed at `run():1234-1256`: the loop denies on the first
  not-yet-checked `file_path` in the batch and returns immediately (so a multi-file MultiEdit needs
  one retry per still-unchecked file, not one retry total -- a mechanical subtlety the analysis's
  prose doesn't spell out but doesn't contradict either).
- Session-state design confirmed exactly: `~/.gateguard` default (`STATE_DIR`, line 32,
  overridable via `GATEGUARD_STATE_DIR`), 30-minute inactivity timeout
  (`SESSION_TIMEOUT_MS = 30*60*1000`, line 36), 500-entry cap
  (`MAX_CHECKED_ENTRIES = 500`, line 40, enforced in `pruneCheckedEntries():806-819`).
- Quoted-string and heredoc stripping before the destructive regex, confirmed at
  `isDestructiveBash():674-721`: `stripHeredocBodies()` runs first (imported from
  `gateguard-heredoc.js`), then `stripQuotedStrings()` + `explodeSubshells()` before
  `DESTRUCTIVE_SQL_DD.test()`.
- Fail-open on unpersistable state confirmed: every `markChecked*`/`saveState` failure path returns
  `allowWithStateWarning()` (line 1176-1181), which allows the operation and names
  `GATEGUARD_STATE_DIR` in the stderr warning -- exactly as claimed.
- All six graduated-controls env vars confirmed present and doing what the table says:
  `GATEGUARD_EXEMPT_GLOBS` (`getExemptMatchers():111-135`), `GATEGUARD_BASH_ROUTINE_DISABLED`
  (`isRoutineBashGateDisabled():142-144`), `GATEGUARD_BASH_EXTRA_DESTRUCTIVE`
  (`getExtraDestructiveRegex():70-100`, malformed-regex-as-unset confirmed at lines 88-98),
  `GATEGUARD_FACT_FORCE_FULL_DENIALS` (`getFullDenialBudget():906-912`, default 3 confirmed at
  `DEFAULT_FULL_DENIALS = 3`, line 904), `GATEGUARD_STATE_DIR` (line 32), `ECC_GATEGUARD`
  (`isGateGuardDisabled():731-737`, accepts `0|false|off|disabled|disable`).

**One env var the analysis's table omits:** `GATEGUARD_DISABLED=1` (`isGateGuardDisabled():732-734`)
is a second, independent full-disable switch alongside `ECC_GATEGUARD=off` -- it only recognizes
the literal `'1'`, not the word-form spellings `ECC_GATEGUARD` accepts. `skills/gateguard/SKILL.md:111,127-132`
documents it in ECC's own skill doc, so this is not a hidden knob, just one the analysis's
graduated-controls table left out. Anyone porting the env-var contract should carry both switches,
not just `ECC_GATEGUARD`.

**Glob gotcha CONFIRMED, and traced to a specific mechanism.** `getExemptMatchers():117-134`
converts a glob to a regex by `.split('**').map(escape-and-convert-single-star).join('.*')` with
**no anchors**. For `**/tests/**`, this produces the regex source `.*/tests/.*`. Because the
`.test()` call is unanchored substring search, `/repo/tests/foo.js` matches (it contains the
literal substring `/tests/`), but a bare relative `tests/foo.js` does **not** -- there is no `/`
character preceding `tests` anywhere in that string. `skills/gateguard/SKILL.md:144-156`
independently documents this exact gotcha and recommends listing both forms
(`**/tests/**,tests/**`) in the shipped example -- so ECC's own skill doc already carries the
correct guidance; the hook code and the doc agree.

**Local `require`s -- confirmed exactly two, both must travel:**
1. `scripts/lib/shell-substitution.js` (482 lines) -- `extractCommandSubstitutions`,
   `extractSubshellGroups`, `extractBraceGroups`. Required directly by
   `gateguard-fact-force.js:28`.
2. `scripts/hooks/gateguard-heredoc.js` (259 lines) -- `stripHeredocBodies`. Required directly by
   `gateguard-fact-force.js:29`. This file **itself requires #1 again**
   (`gateguard-heredoc.js:3`), so the dependency closure is exactly these two files -- no third
   file, no transitive expansion beyond what the analysis named.

**Verdict and effort.** Vendor the two dependency files plus the main hook (3 files, ~2,042 lines
total) as-is; the code is defensive, fails open in every state-write failure path checked, and its
env-var surface is genuinely additive/narrowing rather than load-bearing-removable. A bash rewrite
is possible but not small: the destructive-command detector alone
(`isDestructiveRm`/`isDestructiveGit`/`isDestructiveFindExec`/`isDestructiveQuoteAware`, roughly
lines 340-720) implements a quote-aware, subshell-recursing shell tokenizer that would need
re-deriving in POSIX bash rather than transliterating line-by-line -- realistically 400-600 lines
of careful bash to match current behavior, excluding the shell-substitution/heredoc helpers, which
are the harder half to port (recursive BFS over three nesting constructs). **Recommend vendoring
the Node file**, not rewriting, given EDM's `bin/` scripts already assume Node is absent from the
runtime contract only for `bin/edm-state` itself -- confirm Node availability is an acceptable new
runtime dependency for Phase 6 before committing to this path (a scope question for whoever plans
4.1, not resolved here).

## 2. `skills/continuous-learning-v2/` -- VERDICT: LIFT AS-IS (the resolution pattern only)

`scripts/lib/homunculus-dir.sh:1-31` is the actual resolver (not embedded in SKILL.md prose as I'd
expect from the analysis's framing -- it's a real, tiny, freestanding shell library). Confirmed
exactly the three-step order and its precedence rules:
1. `CLV2_HOMUNCULUS_DIR`, honored only if absolute (line 10-14, else warns to stderr and falls
   through -- does not error).
2. `$XDG_DATA_HOME/ecc-homunculus`, honored only if `XDG_DATA_HOME` is absolute (line 17-21, same
   fall-through-on-relative behavior).
3. `$HOME/.local/share/ecc-homunculus` (line 24-30), and even this final fallback checks `$HOME` is
   absolute, erroring only if it is not.

This is exactly as simple as the analysis describes -- one function, no project-hash scoping logic
in this file (that lives elsewhere in the skill, per the analysis's own framing, and EDM does not
need it per the analysis's own recommendation). **Confirmed: EDM can lift this 31-line pattern
almost verbatim** (replace `ecc-homunculus`/`CLV2_HOMUNCULUS_DIR` with EDM-specific names) as the
fix for the `update-patterns` read-only-install defect the analysis describes in 4.2. Effort:
trivial once the naming decision is made.

## 3. `skills/orch-pipeline/SKILL.md` Step 0 -- VERDICT: TRANSLATE (prose only, no code), with ONE ATTRIBUTION CORRECTION the analysis did not catch

**The decision procedure, quoted verbatim for direct translation** (`orch-pipeline/SKILL.md:39-54`):

> Ceremony scales to blast radius. Score the request on three signals, take the **highest** tier
> any signal reaches, and state the result in one line so the user can override:
>
> | Tier | Files touched | New dependency / contract | Design ambiguity | Phases that run |
> |------|---------------|---------------------------|------------------|-----------------|
> | trivial | 1, a few lines | none | none -- the change is obvious | 4 -> 5 -> 6 |
> | small | 1 file / 1 function | none | clear once you read the code | (1 light) -> 4 -> 5 -> 6 |
> | standard | 2-5 files | maybe a new internal module | one real choice to make | 1 -> 2 -> 4 -> 5 -> 6 |
> | large | many / cross-cutting | new external dep, public API, or a spec doc | multiple open questions | 1 -> 2 -> (3) -> 4 -> 5 -> 6 |
>
> Phase 0 (Intake) always runs and is omitted from the mask column above. The tie-breaker: anything
> touching a security trigger (below) or a public API / contract is **at least** standard,
> regardless of file count.

Four tiers, three signals (files touched / new dependency-or-contract / design ambiguity),
highest-tier-wins, and the security/public-API tie-breaker are all confirmed present and stated
exactly as the analysis paraphrases them. Good translation candidate as-is.

**Correction: the seven security triggers are NOT in `rules/common/security.md`.** The analysis
states "ECC's security triggers, from `rules/common/security.md`, are: authentication or
authorization, user-input handling, database queries, filesystem paths, external API calls,
cryptography, secrets or credentials" and cites that file as the source. I read
`rules/common/security.md` in full (28 lines) -- it contains an entirely different, unrelated
8-item pre-commit checklist ("Mandatory Security Checks": no hardcoded secrets, input validation,
SQL injection, XSS, CSRF, auth verified, rate limiting, error-message leakage) and a "Secret
Management" / "Security Response Protocol" section. **The seven-item trigger list the analysis
quotes does not appear anywhere in that file.** It is a misattribution ECC made first:
`orch-pipeline/SKILL.md:100-104` states the list itself under its own "Security-review trigger"
heading and cites `(Per rules/common/security.md.)` in parentheses -- a citation to a file that, on
inspection, does not contain what it's cited for. The analysis repeated this citation without
checking the cited file. **The seven triggers are real and verified** (they appear verbatim at
`orch-pipeline/SKILL.md:102-104`, and are echoed in `orch-add-feature`, `orch-change-feature`, and
`orch-build-mvp` SKILL.md files, plus `commands/orch-*.md`) -- only the *source attribution* is
wrong. If EDM's own planning doc cites this list, cite `orch-pipeline/SKILL.md`, not
`rules/common/security.md`.

**Effort**: small (~30 lines of skill prose per the original analysis's estimate, unaffected by
the correction above).

## 4. Three thin reviewer agents -- VERDICT: LIFT THE TAXONOMY, REJECT THE PROMPTS (confirmed as the analysis frames it)

Real line counts (total file length, including the six-bullet Prompt Defense Baseline block that
is boilerplate in every ECC agent):

| Agent | Total lines | Frontmatter+boilerplate | Body (taxonomy+format) |
|---|---|---|---|
| `agents/silent-failure-hunter.md` | 60 | 1-16 | 17-60 (44 lines) |
| `agents/type-design-analyzer.md` | 51 | 1-16 | 17-51 (35 lines) |
| `agents/pr-test-analyzer.md` | 55 | 1-16 | 17-55 (39 lines) |

The analysis's "roughly 30 lines of body" undercounts `silent-failure-hunter` (44) and is close
for the other two (35, 39) -- still clearly "thin" relative to EDM's 130-200-line lens agents, but
worth noting the estimate skews low by up to 47% on one of the three. All three are exactly
four-item-or-fewer bullet-list output formats, confirming that half of the "take the taxonomy, not
the prompts" argument.

**Silent-failure-hunter's five categories, quoted exactly** (`silent-failure-hunter.md:23-49`):
1. Empty Catch Blocks -- `catch {}` or ignored exceptions; errors converted to `null`/empty arrays
   with no context.
2. Inadequate Logging -- logs without enough context; wrong severity; log-and-forget handling.
3. Dangerous Fallbacks -- default values that hide real failure; `.catch(() => [])`;
   graceful-looking paths that make downstream bugs harder to diagnose.
4. Error Propagation Issues -- lost stack traces; generic rethrows; missing async handling.
5. Missing Error Handling -- no timeout/error handling around network/file/db paths; no rollback
   around transactional work.

Matches the analysis's paraphrase precisely -- confirmed as L12's mandate source.

**Type-design-analyzer's four dimensions, confirmed** (`type-design-analyzer.md:23-42`):
Encapsulation, Invariant Expression, Invariant Usefulness, Enforcement -- exact match.

**Pr-test-analyzer's process, confirmed** (`pr-test-analyzer.md:23-47`): identify changed code ->
behavioral coverage -> test quality -> coverage gaps rated critical/important/nice-to-have --
exact match.

## 5. `skills/gan-style-harness/SKILL.md` + agents + `scripts/gan-harness.sh` -- VERDICT: TRANSLATE the loop shape and plateau logic; REJECT the Playwright evaluator (per the analysis, confirmed)

Weighted rubric and defaults confirmed at `SKILL.md:112-148` and mirrored in
`agents/gan-evaluator.md:124-127,146-152`: Design Quality 0.3, Originality 0.2, Craft 0.3,
Functionality 0.2, weighted score = sum(score x weight). Pass threshold 7.0 and max iterations 15
confirmed at `SKILL.md:144-148` and reflected in the driver's defaults
(`scripts/gan-harness.sh:28-29`: `MAX_ITERATIONS="${GAN_MAX_ITERATIONS:-15}"`,
`PASS_THRESHOLD="${GAN_PASS_THRESHOLD:-7.0}"`). Per-role model overrides confirmed:
`GAN_PLANNER_MODEL`, `GAN_GENERATOR_MODEL`, `GAN_EVALUATOR_MODEL` (`SKILL.md:224-231`;
`gan-harness.sh:30-32`).

**One discrepancy found and worth flagging for anyone using this as a translation source:**
`GAN_EVAL_CRITERIA` is documented in `SKILL.md:231` as a configuration env var
("Comma-separated criteria") and is shown as an example override in `SKILL.md:174`, but
**`scripts/gan-harness.sh` never reads `GAN_EVAL_CRITERIA` anywhere** -- it is absent from the
script's configuration block (lines 27-37) and the rest of the file. The documented knob is a
no-op in the actual driver; the criteria are fixed by whatever `eval-rubric.md` the Planner writes,
not by this env var. Don't port `GAN_EVAL_CRITERIA` as a real mechanism without also building the
plumbing ECC's own script never built.

**Plateau detection mechanics, the piece the analysis explicitly said it could not describe --
now fully traced at `gan-harness.sh:175-259`:**
```bash
SCORES=(); PREV_SCORE="0.0"; PLATEAU_COUNT=0
for (( i=1; i<=MAX_ITERATIONS; i++ )); do
  # ...generate, evaluate, extract SCORE from feedback file...
  if score_passes "$SCORE" "$PASS_THRESHOLD"; then break; fi   # pass -> stop
  SCORE_DIFF=$(awk -v s="$SCORE" -v p="$PREV_SCORE" 'BEGIN { printf "%.1f", s - p }')
  if [ $i -ge 3 ] && awk -v d="$SCORE_DIFF" 'BEGIN { exit !(d <= 0.2) }'; then
    PLATEAU_COUNT=$((PLATEAU_COUNT + 1))
  else
    PLATEAU_COUNT=0
  fi
  if [ $PLATEAU_COUNT -ge 2 ]; then
    warn "Score plateau detected (no improvement for 2 iterations). Stopping early."
    break
  fi
  PREV_SCORE="$SCORE"
done
```
So: plateau = **two consecutive iterations, starting no earlier than iteration 3, where the score
gained <=0.2 points over the prior iteration** (this also fires on a score *regression*, since the
comparison is `<=0.2`, not `>=0` and `<=0.2`) -- the counter resets to zero on any iteration that
improves by more than 0.2. This is a real, simple, portable mechanism EDM can translate directly
into `bin/` bash for the Phase 6 auto-remediation loop the analysis recommends in 5.1.

**How the script bounds cost -- confirmed to be wall-only, no dollar ceiling.** The only cost
bound in `gan-harness.sh` is the hard iteration cap (`MAX_ITERATIONS`, default 15) combined with
the plateau early-stop above. There is **no per-iteration or per-run dollar budget check**
anywhere in this script (contrast with EDM's own `EDM_EVAL_MAX_BUDGET_USD` knob in
`evals/run-eval.sh`, which this file has no equivalent of). If EDM adopts the iteration-cap +
plateau pattern, it should pair it with EDM's existing cost-attribution machinery
(`edm-state phase-complete`'s token/cost capture) as an *additional* stop condition, not assume
ECC's own script already does this -- it does not.

Evaluator (`agents/gan-evaluator.md`) confirmed Playwright-driven, live-app testing exactly as the
analysis describes -- confirms the REJECT recommendation for that half.

## 6. `scripts/harness-audit.js` -- VERDICT: TAKE THE SHAPE, REJECT THE CONTENT (analysis's Part 8.2 correction CONFIRMED)

**Real line count: 1,083 lines** (`harness-audit.js:1-1083`) -- matches "~1,100".

**Repo-mode-is-fileExists-against-ECC's-own-paths CONFIRMED.** `getRepoChecks():388-657` is
overwhelmingly `fileExists(rootDir, '<ecc-specific-path>')` or `countFiles(...)` against paths like
`skills/strategic-compact/SKILL.md` (line 452), `commands/model-route.md` (line 473),
`skills/eval-harness/SKILL.md` (line 562), `skills/cost-aware-llm-pipeline/SKILL.md` (line 632) --
i.e., "do you have ECC's own bundled files," not a general readiness rubric. Confirmed as the
analysis's Part 8.2 correction states.

**Check-object shape confirmed exactly** (`harness-audit.js:396-404` for a representative example):
`{id, category, points, scopes, path, description, pass, fix}` -- eight fields, matching the
analysis's quoted shape field-for-field.

**`applicableCategories`/`max > 0` logic confirmed** at `buildReport():977`:
`CATEGORIES.filter(name => categoryScores[name]?.max > 0)` -- categories with zero applicable
checks (e.g. `Fly Integration` when no `fly.toml` exists) are excluded from the denominator rather
than scored as a zero, exactly as claimed.

**`detectTargetMode()` confirmed** (`harness-audit.js:217-233`): `'repo'` when
`package.json.name === 'everything-claude-code'`, OR when all four of
`scripts/harness-audit.js` + `.claude-plugin/plugin.json` + `agents/` + `skills/` exist;
`'consumer'` otherwise.

**Consumer-mode check count -- confirmed with one refinement the analysis's phrasing invites
misreading.** The 11 `consumer-*`-id checks in `getConsumerChecks():827-941` sum to exactly
**29 points** (4+3+3+2+4+3+2+2+2+2+2 = 29), matching "11 checks, ~29 points" precisely. **However**,
`getConsumerChecks()` also unconditionally appends `...buildGithubChecks(rootDir)`
(line 942 -- 5 more checks, 10 more points: `github-workflows`, `github-pr-template`,
`github-issue-templates`, `github-codeowners`, `github-dep-updates`) and conditionally appends
`...collectProviderChecks(...)` (line 943, only when a Vercel/Netlify/Cloudflare/Fly marker file is
detected). So **consumer mode's actual total surface is 16 checks / 39 points at minimum**, not 11
checks / 29 points -- the analysis's figure is accurate only for the checks that are
consumer-specific by `id` prefix, and undercounts what a real consumer-mode run reports because the
GitHub checks are shared with repo mode and easy to overlook when reading the two check-builder
functions separately. Whoever writes EDM's own `/edm:audit-harness` check table should decide
GitHub-integration checks' placement deliberately rather than inheriting this ambiguity.

`RUBRIC_VERSION = '2026-05-19'` confirmed at line 22, matching the analysis's quoted version
string -- versioned-rubric discipline is real and portable.

## 7. `skills/hookify-rules/SKILL.md` + `/hookify*` -- VERDICT: TRANSLATE THE FORMAT, BUT BUILD THE EVALUATOR FROM SCRATCH -- it does not exist in ECC

Rule file format, event list, action list, per-event fields, and six operators all confirmed
verbatim in `hookify-rules/SKILL.md:12-64`: events `bash|file|stop|prompt|all` (line 20, 34);
actions `warn` (default) / `block` (line 35); per-event condition fields -- bash: `command`; file:
`file_path`, `new_text`, `old_text`, `content`; prompt: `user_prompt` (lines 58-60); six operators
`regex_match, contains, equals, not_contains, starts_with, ends_with` (line 62); "all conditions
must match" (AND semantics, line 64).

**Critical finding the analysis's own task framing anticipated but did not resolve: there is no
evaluator.** I searched `scripts/` (all subdirectories) for any file referencing `hookify` and
found exactly one hit outside `commands/`/`skills/` -- `scripts/dashboard-web.js`, which is a
generic command-listing helper for a web dashboard (`loadCommands()`, reads `commands/*.md`
frontmatter), not a rule evaluator. I searched the entire tree for the six operator names
(`regex_match`, `not_contains`, etc.) and found them **only** in `hookify-rules/SKILL.md` and its
two translated-locale copies (`docs/ja-JP/`, `docs/zh-CN/`) -- never in any `.js`/`.sh`/`.py` file.
`hooks/hooks.json` (all 23 real registrations, enumerated below) contains **zero** references to
`hookify`. `/hookify` (`commands/hookify.md:33-46`) only *writes* `.claude/hookify.{name}.local.md`
files; `/hookify-list` (`commands/hookify-list.md`) only *reads and displays* them in a table;
`/hookify-configure` (`commands/hookify-configure.md`) only *toggles* the `enabled:` frontmatter
field. **None of the three consumes a rule at tool-call time.** Hookify in ECC is markdown
authoring tooling with no runtime enforcement wired to any hook event -- the entire
condition/operator matching engine described in the SKILL.md is aspirational documentation with no
corresponding code anywhere in this tree.

This changes 5.3's effort estimate materially: EDM is not porting an existing (if small) evaluator
and wiring it into a dispatcher -- **EDM would be writing the evaluator from nothing**, using
ECC's rule-file *format* as the only reusable artifact. The format itself (frontmatter schema +
markdown body message) is a good, small thing to translate; the "small, contained subsystem"
framing in the analysis's Part 5.3 effort estimate ("medium") should account for building condition
matching from scratch, not adapting existing logic.

`/hookify`'s no-argument conversation-analysis mode is confirmed real as a *concept*
(`commands/hookify.md:18-22`, `agents/conversation-analyzer.md` exists) but is equally
consumer-facing-prose-only for the same reason: it produces proposed rule files for human approval,
same downstream (file-write, no evaluation) as the explicit-argument path.

## 8. `skills/delivery-gate/SKILL.md` + `hooks/quality-gate.py` -- VERDICT: TRANSLATE THE PATTERN AND DISCIPLINE, WITH ONE DOC/CODE DRIFT NOTED

Four checks and block/warn split confirmed against `quality-gate.py:149-214`:
- **Rationalization patterns**: regex on transcript tail (`RATIONALIZE`, lines 22-27, matched
  against `tail = transcript[-8000:]` at line 165), logged via `log.warning()` only -- **never**
  calls `sys.exit(2)` on a rationalization hit anywhere in the file. Confirmed: never blocks.
- **Stale learning libraries**: `check_stale_libs()` (lines 80-118) checks mtime today across 5
  configurable `LIBS` paths; blocks (`sys.exit(2)`) if `len(stale) >= 3` (line 207) OR if
  `'growth-log' in stale` (line 211) -- both gated inside `if is_complex:` (edit_count >= 3).
  Matches the analysis exactly.
- **Disk space < 15GB**: blocks, `sys.exit(2)` (lines 152-155). Matches.

**Drift found: the SKILL.md documents a two-tier disk check; the code implements three tiers.**
`SKILL.md:24-26`'s table lists only "Disk space < 50GB -- Warning" and "Disk space < 15GB --
Block". The actual script defines `DISK_REMIND_GB = 50` (info-level reminder, line 158-159),
`DISK_WARN_GB = 30` (warning, line 156-157), and `DISK_CRIT_GB = 15` (block, lines 152-155) -- a
genuine intermediate 30GB warning tier the SKILL.md's own table omits. Not load-bearing for EDM's
adoption (EDM doesn't need disk checks at all, per the analysis), but worth knowing this SKILL.md
undersells its own script's granularity if EDM ever mines the three-tier pattern instead of the
two-tier one described.

**Exit-code contract confirmed**: `sys.exit(0)` = pass/continue (explicit at end of `main()`, line
216, and on the short-session early-return, line 163); `sys.exit(2)` = block, used only for the
disk-critical and stale-library-blocking paths. No third exit code anywhere in the file. Stop hooks
write their message to **stderr, not stdout** -- confirmed by the code comment at lines 131-133
("Stop hooks write feedback to stderr... Do NOT echo raw JSON to stdout") and consistent
`log.warning()`/`logging.basicConfig(stream=sys.stderr, ...)` usage throughout (lines 44-49).

## 9. `scripts/codemaps/generate.ts` -- VERDICT: THE PLACEHOLDER CORRECTION IS CONFIRMED; write fresh if written at all

Placeholder sections confirmed verbatim at `generate.ts:225-231`:
```
## Data Flow

> Detected from file patterns. Review individual files for detailed data flow.

## External Dependencies

> Run `npx jsdoc2md src/**/*.ts` to extract JSDoc and identify external dependencies.
```
These are the literal, unconditional template strings baked into `generateAreaDoc()` -- not
computed from any analysis of the files in that area. Confirms the analysis's Part 8.2 correction
exactly (analysis cited `generate.ts:200-240`; the actual lines are 225-231, a minor
line-number-range correction with the same substance).

**Five area classifications confirmed** at `AREA_PATTERNS` (`generate.ts:36-59`): `frontend`,
`backend`, `database`, `integrations`, `workers` -- exact match to the analysis's list.

**File-to-area assignment mechanism**, traced at `classifyFiles():107-137`: for each file's
repo-relative path, iterate the five areas **in object-key order** (frontend first) and test each
area's regex array (a mix of directory-segment regexes like `/\/(app|pages|components|...)\//i`
and extension regexes like `/\.(tsx|jsx|css|...)$/i`); the **first** area whose any pattern matches
wins (`break` on match, line 121) and the file is never tested against subsequent areas. A file
matching no area's patterns is silently omitted from every area (not placed in an "other" bucket).
This first-match, order-dependent, silently-drops-unmatched-files behavior is exactly the kind of
mechanical detail a fresh implementation should decide on purpose rather than inherit by accident.

## Additional Part 8 claims verified

- **ECC's own stale headline counts, and the real tree counts -- CONFIRMED exactly.**
  `SOUL.md:4` reads "30 specialized agents, 135 skills, 60 commands" verbatim. Direct counts via
  `Glob`: `agents/*.md` = **68** files; `skills/*/SKILL.md` = **286** files (glob tool reported
  "186 more not listed" past the first 100, confirming 286 total); `commands/*.md` = **94** files
  (manually counted the full returned list). All three match the analysis's claimed real counts
  exactly.

- **`hooks/hooks.json` registration count -- REFUTED. The analysis's own "25 across eight events"
  claim (stated in its Part 1.2 table, Part 1.6 table, and asked to be verified in Part 8.2) does
  not match the file.** I read the entire file (292 lines, one JSON document, no truncation) and
  counted every `"id":` field by event block:

  | Event | Registrations | IDs |
  |---|---|---|
  | `PreToolUse` | 8 | `pre:bash:dispatcher`, `pre:write:doc-file-warning`, `pre:edit-write:suggest-compact`, `pre:observe:continuous-learning`, `pre:governance-capture`, `pre:config-protection`, `pre:mcp-health-check`, `pre:edit-write:gateguard-fact-force` |
  | `PreCompact` | 1 | `pre:compact` |
  | `SessionStart` | 2 | `session:start`, `session-start:plan-canvas-sessions` |
  | `PostToolUse` | 2 | `post:dispatcher:sync`, `post:dispatcher:async` |
  | `PostToolUseFailure` | 2 | `post:mcp-health-check`, `post:skill:track` |
  | `Stop` | 7 | `stop:plan-canvas-pending`, `stop:format-typecheck`, `stop:check-console-log`, `stop:session-end`, `stop:evaluate-session`, `stop:cost-tracker`, `stop:desktop-notify` |
  | `SessionEnd` | 1 | `session:end:marker` |

  **Total: 23 registrations across 7 distinct event types** (not 25 across 8). Per-event counts
  for the six events the analysis's Part 1.6 table itemizes (`PreToolUse` 8, `PostToolUse` 2,
  `PostToolUseFailure` 2, `Stop` 7, `SessionStart` 2, `PreCompact` 1) are each individually
  correct and sum with `SessionEnd` (1, also individually correct) to 23 -- so the analysis's own
  per-row table is internally accurate; only its summary total (25) and event-type count (eight,
  vs. the seven event names its own table actually lists) are wrong. This looks like an arithmetic
  slip in the summary rather than a missed hook -- there is no eighth event type anywhere in the
  file (no `UserPromptExpansion`, no `beforeSubmitPrompt`, nothing else). Anyone citing ECC's hook
  count downstream should use **23 across 7 events**, sourced from `hooks/hooks.json` directly.

- **The ~1KB minified plugin-root resolver -- CONFIRMED ubiquitous, grounds the REJECT.** The
  identical `node -e "..."` IIFE (walks `CLAUDE_PLUGIN_ROOT` env var -> `resolve-ecc-root` lib in
  `~/.claude` -> six known plugin-dir names under `~/.claude/plugins/` -> a version-sorted plugin
  cache scan -> fallback to `~/.claude`) appears inline in **every one of the 23** `hooks.json`
  entries (all sampled entries above show it; grep of the raw file shows the same
  `require('path'),f=require('fs'),o=require('os')` fragment recurring in each `command` string).
  It is separately pasted as a literal inline `node -e` block into `commands/sessions.md` (6
  separate occurrences across the file's six workflow steps), and referenced/pasted in
  `commands/skill-health.md` and `commands/instinct-status.md` (the latter's own prose at
  `commands/instinct-status.md:14-18` explicitly says it duplicates "`hooks/hooks.json` and the
  other slash commands (`/sessions`, `/skill-health`)" to avoid a documented divergence bug
  (`#2037`) -- i.e., ECC's own authors know this is copy-pasted and accepted it as a tradeoff).
  This fully grounds the analysis's REJECT recommendation; EDM's `bin/`-on-`PATH` approach avoids
  the entire problem class.

## Component inventory

| Artifact | ECC path | Verdict | EDM target | Notes |
|---|---|---|---|---|
| GateGuard hook | `scripts/hooks/gateguard-fact-force.js` (1301 lines) + `scripts/lib/shell-substitution.js` (482) + `scripts/hooks/gateguard-heredoc.js` (259) | LIFT AS-IS (vendor Node) | new `hooks/` PreToolUse registration, Phase-6-scoped | GateGuard's own upstream license (`zunoworks/gateguard`) not yet checked -- open item |
| Data-dir resolution pattern | `skills/continuous-learning-v2/scripts/lib/homunculus-dir.sh` (31 lines) | LIFT AS-IS (pattern) | fix for `bin/edm-state` `cmd_update_patterns`'s read-only-install defect | No scoping logic needed per analysis; confirmed this file has none to strip out |
| Size classifier | `skills/orch-pipeline/SKILL.md:39-54,100-104` | TRANSLATE (prose) | new Step 0 in `skills/orchestrator/SKILL.md` before Step 1c | Cite `orch-pipeline/SKILL.md` for the 7 security triggers, not `rules/common/security.md` (misattributed in both ECC and the analysis) |
| Silent-failure / type-design / PR-test taxonomies | `agents/silent-failure-hunter.md` (60), `agents/type-design-analyzer.md` (51), `agents/pr-test-analyzer.md` (55) | LIFT TAXONOMY, REJECT PROMPTS | new lenses `agents/edm-audit-L12/L13/L14.md` | Body line counts 44/35/39, not "~30" uniformly -- silent-failure-hunter is 47% longer than the analysis's estimate |
| GAN loop mechanics | `skills/gan-style-harness/SKILL.md`, `agents/gan-planner\|generator\|evaluator.md`, `scripts/gan-harness.sh` (326 lines) | TRANSLATE (loop+plateau), REJECT (Playwright evaluator) | Phase 6 bounded auto-remediation loop | `GAN_EVAL_CRITERIA` is documented but dead code in the actual driver -- do not port as a real knob without building the plumbing |
| Repo-readiness rubric shape | `scripts/harness-audit.js` (1083 lines) | TAKE SHAPE, REJECT CONTENT | new `edm-audit-harness` check table | Consumer-mode is 16 checks/39 pts once shared GitHub checks are counted, not 11/29 as the headline states |
| Hookify rule format | `skills/hookify-rules/SKILL.md`, `commands/hookify*.md` | TRANSLATE FORMAT ONLY, BUILD EVALUATOR FROM SCRATCH | new `bin/` rule loader + dispatcher | No evaluator exists anywhere in ECC -- confirmed by exhaustive search; this is pure markdown tooling today |
| Stop-hook completion gate | `skills/delivery-gate/SKILL.md`, `skills/delivery-gate/hooks/quality-gate.py` (221 lines) | TRANSLATE PATTERN | extend `checkpoint-if-active` Stop hook | SKILL.md undocuments a real 30GB intermediate disk-warning tier the code has |
| Codemaps generator | `scripts/codemaps/generate.ts` (331 lines) | WRITE FRESH OR SKIP | none planned per analysis | Placeholder-section correction re-confirmed at exact lines 225-231 |

## Analysis claims I could NOT verify (in addition to the analysis's own Part 8.3 list)

- **GateGuard's own upstream (`zunoworks/gateguard`) license.** No network fetch was performed
  (out of scope for a read-only local-tree check); only ECC's own MIT license and the
  in-repo attribution comment were inspected. This must be resolved before vendoring the file
  under a clean-room posture equivalent to EDM's `caveman`/`ponytail` precedent.
- **Whether `orch-pipeline`'s wrapper skills (`orch-add-feature`, `orch-change-feature`,
  `orch-fix-defect`, `orch-refine-code`, `orch-build-mvp`) genuinely reimplement nothing**, as the
  analysis's Part 8.3 already flags as unread. Not read in this pass either -- out of the nine
  named artifacts.
- **Whether ECC's test suite passes** (`node tests/run-all.js`) -- not executed, consistent with
  the analysis's own scope limit and this task's read-only constraint.
- **The `conversation-analyzer` agent's actual rule-proposal quality** -- read the command
  (`commands/hookify.md`) that invokes it but not `agents/conversation-analyzer.md` itself in this
  pass; the analysis's Part 8.1 lists it as read, so this is not a new gap, just not independently
  re-verified here.
