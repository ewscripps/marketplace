# Explorer 01 -- bin/ shell tooling, test harness, eval driver

Area owned: `plugins/edm/bin/` (all scripts, `bin/tests/`), `plugins/edm/evals/`. Scope items:
4.2 (update-patterns defect), 5.2 (repo-readiness scorecard), 5.3 (hookify-style rule loader),
EDMV4-T01 (Mermaid lint budget), EDMV4-T05 (eval driver / baseline).

**Repo-state caveats that bear on every finding below**: `plugins/edm/bin/edm-state` and
`plugins/edm/bin/tests/wave6-smoke.sh` have unstaged working-tree edits -- all line numbers cited
here are from the working tree (`Read`'s view), not from HEAD, and will not match a `git blame` or
a clean checkout. Per `decisions.md` D1/D2, this initiative (EDMV4, absorbing the never-created
`EDMV4__lint-and-pipeline-budgets`) already owns three specific ticket IDs pre-assigned by EDMV3:
**EDMV4-T01** (Mermaid budget), **EDMV4-T04** (not in my area -- prompt-surface anchoring),
**EDMV4-T05** (eval baseline capture + CA-532/CA-490 re-verification). D2 scopes 4.2/5.2/5.3 in.

---

## 1. Current State

### 1.1 `update-patterns` (analysis Sec. 4.2)

**The defect is real, but two of the analysis's cited facts are stale or wrong -- verify before
citing them further:**

- **Line numbers moved.** The analysis cites `bin/edm-state:5577` and `:5624`. In the current
  working tree: the write-target computation is at **`bin/edm-state:5595`**
  (`local patterns_dir="${SCRIPT_DIR}/../docs/audit-patterns"`), and the read-only skip/`return 0`
  is at **`bin/edm-state:5627-5629`** (test at `:5627`, message+return at `:5628-5629`). The
  function itself (`cmd_update_patterns`) starts at `:5581`; the sibling body helper
  `_cmd_update_patterns_body` starts at `:5527`. Both are ~18-50 lines later than the analysis
  states -- consistent with unstaged edits since the analysis was written today.
- **"Called mid-phase by four skills" is undercounted -- it's six, and the file's own comment
  repeats the stale number.** `bin/edm-state:5672` itself says "update-patterns is called
  mid-phase by four skills," but grep of `skills/` finds SIX distinct call sites:
  `skills/implement/SKILL.md:46`, `skills/code-audit/SKILL.md:135`,
  `skills/audit-tickets/SKILL.md:52`, `skills/audit-srd/SKILL.md:50`,
  `skills/test/SKILL.md:132`, `skills/test-coverage/SKILL.md:65`. Whoever fixes 4.2 should also
  correct this in-code comment (it's a small standalone doc-accuracy fix, not part of the
  read-only-path defect itself).
- **`${CLAUDE_PLUGIN_DATA}` is not used anywhere in `bin/` today.** Grep across the whole plugin
  finds exactly two references, both prose: `CLAUDE.md:71` (the reservation rule) and the analysis
  document itself. There is no existing resolution pattern to copy from inside `bin/` -- 4.2's fix
  would be the first `bin/` consumer of this variable, and would need to establish its own
  fallback chain (`${CLAUDE_PLUGIN_DATA}` -> `${XDG_DATA_HOME:-$HOME/.local/share}/edm` per the
  analysis's own recommendation) from scratch, since nothing else in this codebase demonstrates the
  idiom.

**Confirmed accurate**: the write-target IS inside the plugin's own tree (`SCRIPT_DIR` is
`bin/`'s own directory, resolved via `BASH_SOURCE[0]`, deliberately -- comment at `:5591-5594`
explains why `$0` was rejected: it breaks when the file is sourced). On a read-only plugin-cache
install, `[[ ! -w "$pattern_dir" ]]` at `:5627` is true, the function warns to stderr and
`return 0`s (never `die`s), so the calling skill's phase proceeds as if nothing happened. This is
confirmed structurally correct, not merely asserted.

**Readers of `docs/audit-patterns/*.md`** (five pattern files: `srd-audit.md`, `ticket-audit.md`,
`qc-audit.md`, `code-audit.md`, `test-coverage-audit.md`) -- four agents, via `Read` at write time,
each resolving "the plugin root" themselves with no shared mechanism:

| Agent | File(s) read | Citation |
|---|---|---|
| `agents/edm-srd-writer.md` | `srd-audit.md` | `:25` |
| `agents/edm-ticket-writer.md` | `ticket-audit.md` | `:32` |
| `agents/edm-implementer.md` | `qc-audit.md`, `code-audit.md` | `:24-25` |
| `agents/edm-test-coverage-auditor.md` | `test-coverage-audit.md` | `:40-42` |

Every one of these citations uses the same disclaimer phrase, "plugin-root-relative," and
`edm-implementer.md:19` states it most explicitly: *"Resolve the plugin root before reading these
files... If a referenced file cannot be resolved there, stop and report the blocker."* **No
concrete resolution mechanism is named anywhere** -- no env var, no `bin/` helper call, nothing
like `CLAUDE_PLUGIN_ROOT`. It relies entirely on the invoked agent's own ability to locate the
plugin root at runtime. This is the exact gap the EDMV3-T41 "by-name reference resolution" finding
(`CLAUDE.md` Sec. "By-name reference resolution...") already documents for `CLAUDE.md`
cross-references -- the same underlying problem (an installed plugin cache is not path-adjacent to
the project it's installed into) applies here too, just not yet named for `docs/audit-patterns/`.

**What a seed-plus-harvested read side would need to change**: today a reader does one `Read` of
one file. Concatenating a read-only shipped seed with a writable harvested delta means either (a)
the reader does two `Read`s and merges in-context (cheapest, no `bin/` change, but pushes the
merge-order/de-dup logic into four agent prompts, which is exactly the kind of duplicated-logic
EDM's own `docs/audit-patterns/README.md` "Append Schema" existed to avoid), or (b) a new `bin/`
subcommand (e.g. `edm-state get-patterns <type>`) does the concatenation and the four agents call
it instead of `Read`ing the file directly -- consistent with this plugin's own precedent of
routing shared logic through `bin/edm-state` rather than four independent prompt copies. Given
this plugin's `CLAUDE.md` D-guard pattern of "do not duplicate state-backed matrices into agent
prompts" (D6 in the prompt-conventions section), route (b) is the more consistent choice, but it is
new `bin/` surface, not a one-file fix.

### 1.2 Repo-readiness scorecard (analysis Sec. 5.2) -- does not exist

No `bin/` script, skill, or agent does anything resembling a repo-readiness check today. What
exists that a new script would need to follow or could reuse:

**House patterns for a new `bin/` script** (from every existing script):
- `#!/usr/bin/env bash` or `#!/bin/bash`, `set -euo pipefail` (or documented deviation, e.g.
  `run-eval.sh` deliberately uses `set -uo pipefail` without `-e` -- see its own CA-074 comment).
- `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"` computed once, near the top --
  every script in `bin/` does this identically (`edm-lint-artifacts:74`, `timing.sh:26`,
  `edm-compare-eval:39`, `edm-state:61`).
- `--help`/`-h`/`help` handled via a **sentinel-delimited block** (`# EDM-HELP-BEGIN` ...
  `# EDM-HELP-END`) extracted by the shared `print_help` function in `_edm-cli-lib.sh`, never a
  hardcoded `sed -n 'A,Bp'` line range (`edm-lint-artifacts:1-70`, `edm-compare-eval:2-33`,
  `run-eval.sh:4-59` all follow this). A new scorecard script sources `_edm-cli-lib.sh` and does
  the same.
- Exit-code convention, per script but consistent in shape: `edm-lint-artifacts` uses 0=clean,
  1=violation, 2=usage/setup error. `edm-compare-eval` uses 0=pass, 1=regression, 2=usage/refused,
  3=not-armed (no baseline). Both share the idea "a distinguishable non-zero for 'something is
  wrong with the *input*' vs 'the check itself ran and found a problem.'" A scorecard would want a
  similar split (e.g. 0=scored regardless of score value, 2=usage error) since a "low score" is not
  a script failure.
- `die()` as a local two-arg helper (`msg`, `code="${2:-2}"`) -- present verbatim (with the same
  comment citing `edm-validate-prefix`'s rationale) in `edm-compare-eval:44-48` and `run-eval.sh`.
- JSON vs text output: `edm-compare-eval` and `run-eval.sh`/`score-artifacts.sh` both default to
  human-readable stdout text plus a machine-readable JSON artifact on disk (`run.json`,
  `scores.json`), produced via `jq -n`. No `bin/` script currently supports a `--json` stdout flag
  directly; the JSON-vs-text split in this codebase is "text to stdout, JSON to a file," not a flag
  on one command. ECC's `harness-audit.js` text-or-JSON-to-stdout shape (cited in the analysis)
  would be a new pattern here, not an existing one.
- A versioned rubric string: no existing precedent in `bin/`, but `score-artifacts.sh` has the
  adjacent idea -- `SCORER_VERSION="1.1.0"` (`score-artifacts.sh:139`), written into every
  `scores.json` and used by `edm-compare-eval` to refuse cross-version comparisons
  (`edm-compare-eval:85-91`). A scorecard's rubric-version field should follow this exact
  precedent (a bare top-level string constant, refused-on-mismatch by any comparator), not invent
  a new versioning scheme.

**What EDM already knows about a repo that a scorecard could reuse rather than re-detect**:
- `edm-state session-start` / `check_permission_rules()` already detects `.claude/settings.json`,
  `.claude/settings.local.json`, and whether the two required `permission.ask` rules are present
  (`CLAUDE.md` Sec. "Required setup: permission `ask` rules").
- `edm-test-planner` already detects test frameworks per layer (`test_frameworks_detected` in
  state) and stack.
- `edm-state validate` already computes a battery of anomaly checks (`OPEN_AUDIT_ROUND`,
  `TORN_TOKEN_LINES`, `SPEC_SWEEP_PENDING`, `PERM_RULES_MISSING`, `OPEN_PARTIALS`, ...) -- these
  are readiness-adjacent signals already computed, just not aggregated into a 0-10 scorecard.
- `edm-state metrics-report` already knows per-phase/per-round cost and duration history.

A scorecard's highest-leverage move, given this, is less "write 20-30 new `fileExists` checks"
(ECC's actual implementation, which the analysis itself says not to port) and more "aggregate
signals `edm-state validate`/`session-start`/`get-coverage` already compute into named,
`0-10`-normalized categories with a versioned rubric string" -- new categorization logic, but not
entirely new detection logic.

### 1.3 Hookify-style rules-as-data loader (analysis Sec. 5.3) -- does not exist

House patterns a rule loader would need to follow, established from existing `bin/` code:

- **jq usage**: every `bin/edm-state` mutation goes through `rmw_state` (read-modify-write, jq
  filter + `--arg`/`--argjson`), and every read goes through direct `jq -r '... // default'` calls
  with explicit `//` fallbacks for C-4 backward compatibility (documented extensively in
  `CLAUDE.md`'s state-field table). A rules-as-data loader reading YAML-frontmatter rule files
  would need its own frontmatter parser -- there is **no YAML parsing anywhere in `bin/` today**.
  Every "structured" file this plugin's `bin/` scripts consume is either JSON (state files,
  `findings-ledger.jsonl`, `scores.json`, `run.json`) or plain markdown scanned with `awk`/`grep`
  (audit-pattern files, lint targets). Hookify's rule format (YAML frontmatter + markdown body,
  same shape as a `SKILL.md`) has no existing `bin/`-side reader to extend; a new loader would
  either need a from-scratch bash/awk YAML-subset parser (risky -- YAML is not a shell-friendly
  format) or would need to constrain the rule format to something jq/awk can parse (e.g. requiring
  each condition as a JSON block instead of a YAML list, which would diverge from ECC's format).
- **How `edm-lint-artifacts` walks files and reports violations** (directly reusable as the
  dispatch skeleton for a rule engine): `collect_md_files` (a `find ... -name '*.md' -print0`,
  `edm-lint-artifacts:251-260`) enumerates files; `scan_md_files` (`:303-448`) computes one shared
  "line classification" pass per file via `build_line_classes` (from `_edm-lint-lib.sh`) and then
  runs each violation class against that shared table rather than re-scanning the file once per
  class -- explicitly to keep the per-file cost from multiplying with the number of classes
  (comment at `:307-310`, CA-156 at `:327-336`). A rules-as-data engine with N enabled rules would
  face the identical multiplying-cost problem `edm-lint-artifacts` already solved once; the fix
  pattern (one classify pass, N projections) transfers directly.
- **Exit-code conventions for "violation" vs "setup error"**: `edm-lint-staged-artifacts` is the
  clearest existing model for exactly this distinction -- `edm-lint-artifacts` exit 1 (real
  violation) is translated to the git-commit hook's exit 2 (block the commit); exit 2 (setup/usage
  error, e.g. "no initiative for that prefix") is reported to stderr but does **not** block
  (`CLAUDE.md` Sec. "Hooks behavior" table, `edm-lint-staged-artifacts` row). A rule loader with an
  `action: block` mode should adopt this same two-tier distinction: a rule that actually fires and
  says "block" should exit differently from a rule file that is malformed or unreadable.

### 1.4 Mermaid-class lint budget (EDMV4-T01)

`bin/tests/timing.sh` (full file read) already has everything the ticket asks whether it needs
built:

- **The 50-initiative fixture generator already exists**: `timing.sh --generate-fixture
  [--initiatives N] [--dir DIR]` (`:239-253`), default `N_INITIATIVES=50` (`:217`). It calls
  `edm-state init`/`approve-gate` in a loop to build a real fixture tree under a scratch
  `EDM_SRD_ROOT`. **This does not need to be written -- EDMV4-T01 should consume it, not
  reimplement it.**
- **`--lint` mode** (`:366-384`) measures the **commit-path budget**: a single initiative,
  configurable `--files`/`--lines-per-file` (default 30 files x 333 lines = ~9,990 lines total),
  against `edm-lint-artifacts <PREFIX>`. This is the number the 3,000ms p95 commit-path budget in
  `CLAUDE.md`'s "`edm-lint-artifacts` latency budgets" section is measured against.
- **`--all-lint` mode** (`:430-451`) measures the **CI-budget / full-repo-sweep** number: requires
  a `--dir` pointing at a `--generate-fixture` output, runs `edm-lint-artifacts --all` once
  (single-sample, not p95 -- comment at `:440-447` explains why: a ~60s scan is not something this
  harness re-runs 20x per invocation), reports `duration_ms` against the documented 60,000ms
  ceiling.
- **`--mermaid-ratio` mode** (`:386-428`) is the actual "Mermaid-class code path" measurement
  the ticket is about: it builds a fixture with no mermaid fences, measures baseline `--lint`
  p95, then appends one small ```` ```mermaid ```` fence per file and re-measures, reporting the
  ratio (budget stated as `<= 1.40x`, per `:426`). It deliberately measures the *worst* realistic
  case (every file gets a fence, so the no-fence short-circuit never engages) rather than a
  best-case near-1.0x number (comment `:388-396`).

**The class-4 rewrite CLAUDE.md alludes to** (commit `ea31ce8`) is confirmed present in
`edm-lint-artifacts`: `mermaid_scan_awk` (`:214-248`) is one `awk` process per file rather than
per-line, cached program text (`_MSA_PROG_CACHE`, `:225-246`, fixed under CA-472 to avoid a
process-substitution fd leak), loading the shared rule file (`MERMAID_RULES_AWK`, from
`_edm-lint-lib.sh`) exactly the way the analogous class-1 (attribution) and class-2/3 (unicode,
leaked-tool-tag) fixes already work (`_lint_report_class_hits`, `:286-297`, explicitly built to
eliminate a four-times-copy-pasted per-class loop body that once caused a real CA-008 divergence).
`CHANGELOG.md:382,426-428` corroborates the numeric history: 3.40x after an unrelated 40x
baseline speedup (`d591b92`, which made class-4 the dominant relative cost without touching it),
then 1.12x after `ea31ce8` applied the same one-process-per-file treatment to class 4.
`CHANGELOG.md:382` also flags: *"PASS on the number, but the budget is still malformed"* --
worth reading the referenced note in full before treating the 1.40x ceiling as settled, since the
changelog itself disputes the budget's form (no stated input-size floor), not just the number.

**Verdict on EDMV4-T01's stated open question** ("whether a 50-initiative fixture generator exists
or must be written"): it exists, is already wired into `--all-lint`, and needs no new work beyond
possibly parameterizing it further if the ticket wants a different N or shape.

### 1.5 Eval driver (EDMV4-T05)

`evals/run-eval.sh` (full file read) and `bin/edm-compare-eval` (full file read), both current.

**CA-532 (`--allowedTools` argv-splitting) is already fixed in this tree, not open.** The archived
EDMV3 findings ledger (`SRD/.archived/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl`,
entry id `CA-532`, `raised_round:10`, `resolved_round:11`, `status:"fixed"`) records the original
defect (a space-joined string passed as one `--allowedTools` argv element, which does not survive
the CLI's documented space-separated-separate-arguments contract for any of the four
space-containing specifiers) and its verified fix. Confirmed directly in the current source:
`run-eval.sh:420-421` defines `CLAUDE_ALLOWED_TOOLS`/`CLAUDE_DISALLOWED_TOOLS` as real bash arrays
(`CLAUDE_ALLOWED_TOOLS=(Read Write Edit Glob Grep LS TodoWrite Task "Bash(edm-state *)" ...)`),
and `:460-461` expands them as `"${CLAUDE_ALLOWED_TOOLS[@]}"` / `"${CLAUDE_DISALLOWED_TOOLS[@]}"`
-- exactly the fix the ledger entry prescribes and records as verified. **EDMV4-T05, as scoped in
`decisions.md` D1, should re-verify this is still fixed (a regression check), not re-fix it.**

**CA-490 (baseline-check-before-completeness-check ordering) is also already fixed.** Ledger entry
`CA-490` (`raised_round:9`, `resolved_round:11`, `status:"fixed"`, `spec_swept:"yes"`) describes the
original ordering bug and its fix; confirmed in current source: `edm-compare-eval:62-75` runs
refusal condition 3 (`complete != true` check) **before** the baseline-existence check at
`:77-81` -- the exact reorder the ledger records as landed. A related residual, **CA-537**
(`.gitlab-ci.yml` exit-code arm ordering, also `status:"fixed"`), is now moot in this repo: **no
`.gitlab-ci.yml` exists in the working tree** (only stray copies under `.claude/worktrees/*/`,
which are agent-team scratch worktrees, not this repo's own file) -- consistent with `CLAUDE.md`'s
current statement ("There is no separate CI pipeline for this plugin") and the recent commit
`b56558d` ("Remove the GitLab CI pipeline"). Any EDMV4-T05 work item that assumed a CI job needs
re-wiring should be dropped; the eval driver and comparator are purely local invocations now.

**What is genuinely still open, per `decisions.md` D1 and `evals/baseline/README.md`**:
`plugins/edm/evals/baseline/scores.json` **does not exist** (`Glob` on `evals/baseline/*` returns
only `README.md`). This is the actual live gap EDMV4-T05 must close -- not a bug fix, a **live
capture requiring real API spend and human-owned credentials** (`README.md` is explicit that this
was deliberately not spent on an implementer's own credential). The archived ledger's `CA-106`
entry documents this same fact from EDMV3's side and names **EDMV4-T05 by ID** as its own
follow-on (`"tickets/epics/03-ci-and-fixture-eval.md:579-583 and :616-628 record the boundary and
name EDMV4-T05 as the owning follow-on"`), confirming D1's inheritance claim is accurate.

**What `edm-compare-eval` does when the baseline is absent**: exits 3, printing "no committed
baseline... the eval tripwire is NOT ARMED" (`edm-compare-eval:77-81`) -- a distinct, named,
non-blocking-in-the-sense-of-"regression" outcome, not a crash and not a silent pass.

**What `scores.json` needs to contain** (from `score-artifacts.sh` and the baseline README):
`scorer_version` (currently `"1.1.0"`, `score-artifacts.sh:139`), `dimensions_scored` (an integer
-- 5 expected for a wave-A plan->srd->audit-srd-only capture, since dimension 5,
lens-JSONL-vs-prose agreement, has no input without a code-audit round), `dimensions` (array of
`{name, score}`), `total`, `complete` (boolean), and -- only on the committed baseline file, not
every candidate run -- a `variance.total_range` object (`README.md:104-116`), the sole field
`edm-compare-eval` reads off the baseline for its threshold (`edm-compare-eval:109`,
`jq -r '.variance.total_range // 0'`). It is produced by three real `run-eval.sh` invocations
(fresh scratch tree each) scored individually by `score-artifacts.sh`, with the **middle-scoring**
run's `scores.json` (by `total`) committed as the baseline (`README.md:39-55`).

---

## 2. Gap Analysis

| Item | What exists | What is missing / gap |
|---|---|---|
| 4.2 update-patterns | Full harvest/append machinery (`_cmd_update_patterns_body`, extraction, de-dup, state recording) works correctly on a writable checkout | Write target is hardcoded to the plugin's own installed tree; no `${CLAUDE_PLUGIN_DATA}` fallback exists anywhere in `bin/` to model a fix on; four readers rely on undefined "resolve the plugin root" agent behavior with no shared mechanism (echoes the already-named EDMV3-T41 gap, just for a different file set); in-code comment undercounts callers (four vs. actual six) |
| 5.2 scorecard | `edm-state validate`/`session-start`/`get-coverage`/`metrics-report` compute many readiness-adjacent signals already; `score-artifacts.sh` has a real versioned-scorer precedent (`SCORER_VERSION`) | No aggregation into named 0-10 categories; no rubric-version convention in `bin/` outside the eval scorer; no JSON-or-text-to-stdout precedent (existing scripts write JSON to a file, text to stdout, never both from one flag) |
| 5.3 hookify loader | `edm-lint-artifacts`'s one-classify-pass-N-projections pattern and its violation/setup-error exit split are directly reusable skeletons | No YAML parsing capability anywhere in `bin/`; no PreToolUse/Stop rule dispatcher exists; format choice (YAML frontmatter vs. JSON rule blocks) is an open design fork with real parser-availability consequences |
| EDMV4-T01 Mermaid budget | `timing.sh --generate-fixture`, `--lint`, `--all-lint`, `--mermaid-ratio` all already built and wired to the class-4 one-awk-per-file implementation; numeric history documented in CHANGELOG.md | CHANGELOG.md itself disputes the 1.40x budget's *form* ("still malformed" -- no stated size floor) even though the number passes; that framing issue, not a missing harness, is the open work |
| EDMV4-T05 eval driver | CA-532 and CA-490 both verified fixed in source; no CI pipeline exists to re-wire (removed) | `evals/baseline/scores.json` does not exist; three live-API captures plus a middle-run commit are the only remaining step, and it is a human/credential decision, not a code change |

---

## 3. Component Inventory

| Component | Path | Status | Notes |
|---|---|---|---|
| `cmd_update_patterns` / write-target resolution | `bin/edm-state:5581-5595` | Modified | Change `patterns_dir` resolution; add `${CLAUDE_PLUGIN_DATA}` fallback chain |
| Read-only skip branch | `bin/edm-state:5625-5630` | Modified | Becomes a seed-copy-then-write path instead of a permanent no-op |
| Stale "four skills" comment | `bin/edm-state:5672` | Modified | Correct to six, or reword to avoid a maintained count |
| Pattern-file readers | `agents/edm-srd-writer.md:25`, `edm-ticket-writer.md:32`, `edm-implementer.md:24-25`, `edm-test-coverage-auditor.md:40-42` | Modified | If concatenation moves into a new `bin/edm-state` subcommand, all four switch from `Read <file>` to `Bash(edm-state get-patterns ...)` or equivalent |
| New pattern-concat subcommand (if route (b) chosen) | `bin/edm-state` (new subcommand) | New | Not required if route (a), in-prompt concatenation, is chosen instead |
| Repo-readiness scorecard script | `bin/` (new script, e.g. `edm-audit-harness` or similar) | New | Follows `_edm-cli-lib.sh` help/exit conventions; category list and versioned rubric string are new design work, not extraction |
| Rules-as-data loader | `bin/` (new script) + a `PreToolUse`/`Stop` hook registration | New | Needs a parser decision (YAML subset vs. JSON rule format) before implementation can start |
| `bin/tests/timing.sh` | `plugins/edm/bin/tests/timing.sh` | Exists, unmodified (probably) | All four relevant modes already built; EDMV4-T01 likely only needs the budget-framing fix CHANGELOG.md flags, not new harness code |
| `bin/edm-lint-artifacts` class-4 scan | `bin/edm-lint-artifacts:184-248, 406-447` | Exists, unmodified (probably) | Already carries the `ea31ce8` one-awk-per-file fix; verify CHANGELOG.md's "still malformed" budget-form complaint before treating it as fully closed |
| `evals/run-eval.sh` allowedTools arrays | `evals/run-eval.sh:420-421, 460-461` | Exists, unmodified | CA-532 fix already present; EDMV4-T05 re-verifies, does not re-fix |
| `bin/edm-compare-eval` refusal ordering | `bin/edm-compare-eval:62-81` | Exists, unmodified | CA-490 fix already present; EDMV4-T05 re-verifies |
| `evals/baseline/scores.json` | `plugins/edm/evals/baseline/` | **Missing** | The one real open item in EDMV4-T05; requires 3 live `claude -p` runs + human credential decision, not a code change |
| `.gitlab-ci.yml` eval:nightly job | (removed) | N/A | No longer exists in this repo; CA-537's fix is moot here |

---

## 4. Constraints Identified

- **Licensing / attribution**: none apply to this area directly -- `bin/` and `evals/` are
  wholly this plugin's own original bash/jq/awk, no vendored ECC code proposed for this area (the
  analysis's ECC-sourced items, GateGuard etc., live outside my scope).
- **Platform**: `CLAUDE.md`'s "Testing changes" section is explicit -- macOS and Linux only, bash
  3.2+ (the plugin's stated floor; `edm-lint-artifacts` and `timing.sh` both carry live comments
  about bash-3.2-specific gotchas, e.g. no associative arrays, `mktemp` template quirks, a `<(...)`
  process-substitution fd leak class fixed under CA-472). Any new `bin/` script (scorecard, rule
  loader) must be written to this floor, not to bash 4+ conveniences.
- **No YAML tooling dependency assumed available.** The plugin's stated required binaries are
  `bash`, `jq`, `git` (`CLAUDE.md` "Testing changes"). A hookify-style loader that requires a real
  YAML parser (`yq`, a Python/Node dependency) would add a new required binary this plugin has
  never needed before -- a real constraint on 5.3's design, not a detail.
- **Live-API budget ownership for EDMV4-T05.** `evals/baseline/README.md` records, in its own
  words, that capturing the baseline is a decision "for whoever owns the `ANTHROPIC_API_KEY`," made
  deliberately, "not spent silently by an agent verifying its own ticket." This is a human-gate
  constraint on the ticket, not a technical one -- an implementer should not spend this
  unilaterally.
- **No CI pipeline exists to enforce any of this automatically.** `CLAUDE.md`: "There is no
  separate CI pipeline for this plugin" -- the local `bin/tests/run-all.sh` smoke suite plus the
  git-commit hook are the entire enforcement surface. Any new scorecard/rule-loader work is
  enforced the same way: local smoke tests, not a pipeline gate.

---

## 5. Dependency Map

- **4.2 fix blocks nothing else in my scope**, but its readers (4 agent files) are a dependency
  *of* 4.2: the write-side fix and the read-side concatenation change should land together, since
  a seed-only read against a harvested-only write location silently loses all harvested content
  until both sides move in the same commit.
- **5.2 (scorecard) depends on 4.3 landing first** per the analysis's own framing (the size
  classifier is the scorecard's consumer) -- **4.3 is outside my scope** (owned by whichever
  explorer covers `skills/orchestrator/`), so 5.2's *value* is blocked on that explorer's findings,
  though 5.2's *construction* (the check table itself) is not technically blocked.
- **5.3 (hookify loader) has a real, unresolved parser-choice fork** that blocks implementation
  start: YAML-subset bash parsing (risky, no precedent) vs. JSON-shaped rule files (safe, jq-native,
  but diverges from ECC's exact format and from any future desire to literally copy ECC rule files
  over). This should be a Phase-2 architecture decision, not left implicit.
- **EDMV4-T01 is not blocked on anything** -- the harness exists; the work is narrowly re-framing
  or re-stating the budget per CHANGELOG.md's "still malformed" flag, and possibly re-running
  `--mermaid-ratio` to reconfirm the 1.12x figure is current.
- **EDMV4-T05's scores.json capture is blocked on a human credential decision**, not on any other
  ticket in this initiative. It has no technical dependency on 4.2/5.2/5.3.
- **Cross-initiative dependency**: EDMV4-T04 (prompt-surface anchoring, the eight remaining
  EDMV3-54 touch points) is explicitly out of my scope per the task brief but shares this
  initiative and the same `decisions.md` D1 inheritance -- worth flagging to the synthesizer that
  three inherited ticket IDs (T01, T04, T05) span two different explorers' areas and should be
  reconciled in `planning.md` rather than double-scoped.

---

## 6. Complexity Estimate (my area only)

- **Files affected**: ~10-14 -- `bin/edm-state` (2-3 hunks: write-target, skip branch, stale
  comment), 4 agent files (pattern-file read instructions, if route (b) chosen), 1-2 new `bin/`
  scripts (scorecard, rule loader), `bin/tests/wave*-smoke.sh` (new assertions for each), possibly
  `CLAUDE.md` (new `bin/` helper-table rows, new env-var family docs), `CHANGELOG.md`.
- **New modules needed**: 2 new `bin/` scripts (repo-readiness scorecard; hookify-style rule
  loader) + possibly 1 new `edm-state` subcommand (pattern concatenation, if route (b) is chosen
  for 4.2's read side). EDMV4-T01 and EDMV4-T05 need **zero** new modules -- both are
  fix/verify/capture work against existing harnesses.
- **Integration points**: 4 (agent read-sites for 4.2), 1 (git-commit hook, if the rule loader
  wires into `PreToolUse`), 1 (`Stop` hook, if the rule loader also fires there), 1 (whatever
  Phase-1/orchestrator surface would invoke the scorecard, likely outside my area).
- **Estimated ticket size for my area alone**: **Small (10-20 tickets)** -- 4.2 is a few hours per
  the analysis's own effort estimate and is the only item with a concrete, narrow fix; EDMV4-T01
  and EDMV4-T05 are narrow re-verification/capture tasks, not builds; 5.2 and 5.3 are genuinely new
  but each analysis-rated "medium effort," consistent with a handful of tickets each rather than a
  multi-epic build. If 5.2 and 5.3 are both taken to full implementation (not just design), this
  area alone could push toward the low end of **Medium (30-50)** combined with the other explorers'
  areas -- but on the `bin/`/`evals/` surface specifically, Small is the more accurate estimate.

---

## 7. Riskiest Assumptions

1. **That "seed + harvested concatenation" (4.2's prescribed fix) is actually wanted by the four
   reading agents as a two-file read rather than a single pre-merged file.** No agent prompt today
   is written to merge two documents' guidance; verifying this doesn't silently double-count
   pre-flight-checklist items or contradict itself when the same anti-pattern appears in both the
   seed and the harvested delta is unverified.
2. **That the `${CLAUDE_PLUGIN_DATA}` fallback chain (`${XDG_DATA_HOME:-$HOME/.local/share}/edm`)
   is genuinely writable and genuinely persistent across plugin reinstalls/upgrades on every
   supported platform (macOS + Linux).** Nothing in this codebase has ever exercised this
   env var; its actual runtime value and write permissions inside a real Claude Code plugin-cache
   install are asserted by the analysis, not verified from this repo (the analysis itself only
   cites `CLAUDE.md`'s prose reservation of the variable, not a working example).
3. **That the CHANGELOG.md "budget is still malformed" note for EDMV4-T01 is still the live
   objection**, rather than something already addressed in a subsequent, unlogged change --
   I read the CHANGELOG entry as current, but did not find a corresponding fix or superseding note
   in `timing.sh` or `CLAUDE.md`'s budget table itself; a synthesizer should re-check whether the
   "no stated absolute floor" complaint has since been addressed elsewhere before treating it as
   this ticket's whole scope.
4. **That a bash/awk-only rules-as-data loader (5.3) can adequately parse a hookify-style YAML rule
   file without a real YAML library.** This is asserted as feasible above only in the sense that a
   JSON-shaped alternative format is safe; whether a genuine YAML-frontmatter format (matching
   `SKILL.md`'s own frontmatter shape, which this plugin already parses in some form for its own
   skills) is parseable with the tools already on the required-binaries list is not verified here
   and would need a spike before committing to the ECC-native format.
