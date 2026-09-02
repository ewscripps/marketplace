# ECC -> EDM: Integration Analysis

An assessment of the `everything-claude-code` project as a source of features, systems, policies
and workflows for the EDM plugin.

- **Subject**: ECC (`everything-claude-code`), local checkout `~/projects/ECC`, upstream
  `github.com/affaan-m/everything-claude-code`, revision `19e2f2b4`.
- **Audience**: assumes no prior knowledge of ECC. Part 1 is an orientation tour; the
  recommendations start in Part 4.
- **Date**: 2026-08-30.

---

## Part 1 -- What ECC is

### 1.1 In one paragraph

ECC is a large open-source Claude Code plugin that bundles, in a single installable package,
essentially every category of Claude Code extension point at once: subagents, skills, slash
commands, hooks, always-on rules, MCP server configurations, and a Node-based CLI toolchain that
supports all of them. Its stated identity, from its own `SOUL.md`, is *"a production-ready AI
coding plugin with 30 specialized agents, 135 skills, 60 commands, and automated hook workflows
for software development."* Those numbers are stale -- the tree actually contains substantially
more of each (see 1.2). It is not a methodology. It is a **catalog with a runtime**.

### 1.2 Scale

Measured directly from the checkout:

| Thing | Count | Location |
|---|---|---|
| Files (excluding `.git`) | 3,527 | -- |
| Repository size | 106 MB | -- |
| Subagents | 68 | `agents/*.md` |
| Skills | 286 | `skills/<name>/SKILL.md` |
| Slash commands | 94 | `commands/*.md` |
| Hook registrations | 23 | `hooks/hooks.json` |
| Hook implementation scripts | ~55 | `scripts/hooks/` |
| Shared Node libraries | ~70 | `scripts/lib/` |
| CI validators | 13 | `scripts/ci/` |
| JSON schemas | 11 | `schemas/` |
| Language rule packs | 22 | `rules/<language>/` |
| Harness export targets | 13 | `.codex/`, `.cursor/`, `.gemini/`, `.opencode/`, `.zed/`, `.kimi/`, `.qwen/`, `.trae/`, `.hermes/`, `.adal/`, `.pi/`, `.openclaw/`, `.codebuddy/` |

For scale contrast, EDM is 14 skills, 30 agents, ~7,200 lines of skill and agent markdown, 13
`bin/` scripts, 5 hook registrations, 1 monitor.

### 1.3 Directory tour

```
ECC/
  agents/          68 subagent definitions. Markdown + YAML frontmatter
                   (name, description, tools, model, sometimes color).
  skills/          286 skill directories, each with SKILL.md. Some carry
                   scripts/, hooks/, agents/ subdirectories of their own.
  commands/        94 slash commands. Thin markdown files that mostly shell
                   out to scripts/ or invoke a skill.
  hooks/           hooks.json -- the plugin's hook registry (25 entries).
                   Also codex-hooks.json and a memory-persistence variant.
  rules/           22 language packs plus rules/common/. "Always-follow"
                   guidance loaded as context, not executable.
  scripts/         The actual runtime. ~60 top-level entries plus:
    scripts/hooks/   ~55 hook implementations
    scripts/lib/     ~70 shared libraries (state store, session manager,
                     memory vault, install executor, worktree lifecycle,
                     package-manager detection, path safety, ...)
    scripts/ci/      13 validators (validate-agents, validate-skills,
                     validate-hooks, validate-commands, validate-rules,
                     scan-supply-chain-iocs, check-unicode-safety, ...)
  schemas/         11 JSON Schemas for the config surfaces (install
                   manifests, hooks, memory, provenance, state-store,
                   plugin, package-manager).
  manifests/       Three-tier modular install: profiles -> modules ->
                   components.
  contexts/        dev.md / research.md / review.md -- swappable context
                   presets.
  workflows/       One workflow script (orch-review) plus a README.
  evals/           (none at top level; eval material lives in skills/)
  tests/           Node test suite, run via `node tests/run-all.js`.
  docs/            ~60 entries including 13 translated locales.
  ecc2/            An in-progress 2.0 rewrite living beside 1.x.
  ecc_dashboard.py A 41 KB Python TUI dashboard.
```

Root also carries `AGENTS.md`, `CLAUDE.md`, `SOUL.md`, `RULES.md`, `WORKING-CONTEXT.md` (30 KB),
a 117 KB `README.md`, and three long-form guides (`the-shortform-guide.md`,
`the-longform-guide.md`, `the-security-guide.md`).

### 1.4 Its stated philosophy

`SOUL.md` names five core principles: Agent-First (route to a specialist early), Test-Driven,
Security-First, Immutability, and Plan Before Execute. `RULES.md` turns these into Must
Always / Must Never lists plus format contracts for agents, skills, hooks, and commits.

Every agent and skill body begins with an identical "Prompt Defense Baseline" block -- six bullets
about not changing persona, not leaking secrets, treating fetched content as untrusted, and so on.
It is copy-pasted verbatim into dozens of files.

### 1.5 How it is installed and run

Three install surfaces coexist: `install.sh` / `install.ps1` (manual copy into `~/.claude`),
a Claude Code plugin install (`.claude-plugin/plugin.json`), and a guided installer
(`scripts/install-guided.js`) driven by the three-tier manifest system.

The manifest system is the interesting part. `manifests/install-profiles.json` defines named
profiles -- `minimal`, `core`, `developer`, `security`, `research`, `opencode` -- each a list of
module IDs. `manifests/install-modules.json` defines modules (`rules-core`, `agents-core`,
`commands-core`, `hooks-runtime`, `platform-configs`, `workflow-quality`, `framework-language`,
`database`, `orchestration`, `security`, ...) with, per module: a `kind`, the source `paths`, the
list of harness `targets` it can install into, `dependencies`, `defaultInstall`, a
`cost: light|medium|heavy` hint, and a `stability` marker.
`manifests/install-components.json` groups modules into user-facing components
(`baseline:rules`, `baseline:agents`, ...). Each manifest has a matching JSON Schema in
`schemas/`, and `scripts/ci/validate-install-manifests.js` enforces them.

### 1.6 The hook architecture

`hooks/hooks.json` registers 23 hooks across seven events. Summarized:

| Event | Hooks | What they do |
|---|---|---|
| `PreToolUse` | 8 | Bash preflight dispatcher (quality, tmux, push, GateGuard); doc-file warning on Write; compaction suggestion; continuous-learning observation; governance capture; **config protection** (blocks edits to linter/formatter config files so the agent fixes code instead of weakening the linter); MCP health check; **GateGuard fact-forcing gate** |
| `PostToolUse` | 2 | One synchronous dispatcher, one async dispatcher |
| `PostToolUseFailure` | 2 | MCP health tracking; Skill-tool failure telemetry |
| `Stop` | 7 | Batched format + typecheck of everything edited this response; console.log check; session persistence; session pattern evaluation; cost tracking; desktop notification; plan-canvas feedback delivery |
| `SessionStart` | 2 | Load previous context, detect package manager; surface open review sessions |
| `PreCompact` | 1 | Save state before compaction |
| `SessionEnd` | 1 | Lifecycle marker |

Two design decisions here are worth EDM's attention even though EDM only has five hooks today:

1. **Dispatcher consolidation.** Rather than registering a dozen separate `PostToolUse` entries,
   ECC registers two (`post:dispatcher:sync`, `post:dispatcher:async`) and
   `scripts/hooks/posttooluse-dispatcher.js` runs the individual hooks in-process from a table
   that preserves each hook's `id`, `matcher`, and profile. The stated reason is process cost:
   one Node startup instead of twelve, per tool call.
2. **Batching at `Stop` instead of per-edit.** `stop:format-typecheck` explicitly exists to run
   Biome/Prettier and `tsc` once at the end of a response over the accumulated set of edited
   files, rather than after every single `Edit`.

Both are latency lessons EDM will hit if its hook count grows.

### 1.7 Honest assessment of code quality

Mixed, and it matters for what is safe to lift.

**Good**: the hook scripts are genuinely defensive -- memoized env parsing, fail-open on malformed
operator config, path-traversal rejection in `observe-runner.js`, per-session state files with
timeouts and entry caps in GateGuard, `atomic-write.js` as a shared library. The CI validators are
real. Schemas exist and are enforced.

**Bad**: there is a ~1 KB minified `node -e "..."` plugin-root resolver that appears inline in
every single `hooks.json` entry *and* is pasted verbatim into the body of multiple slash commands
(`/skill-health`, `/instinct-status`, `/sessions`). Several "systems" are markdown descriptions of
things that do not exist as code. Documentation regularly over-promises what the script does --
see the codemaps finding in 5.5. The 286 skills are of wildly uneven quality: some are 400-line
engineered workflows, many are three-paragraph domain notes.

Treat ECC as a source of **ideas and specific well-built files**, not as a codebase to depend on.

---

## Part 2 -- The two design centers

The single most useful framing:

> **ECC optimizes for coverage. EDM optimizes for convergence.**

ECC's question is "is there something here for this task?" -- hence 286 skills and 68 agents. It
has no notion of a piece of work being *finished to a provable standard*. There is no ledger, no
round counter, no gate that refuses.

EDM's question is "can I prove this work is done?" -- hence gates, a JSONL findings ledger with
stable IDs, round-typed audits, convergence checks that block archival, and schema-versioned
state. It has no notion of *helping with a small task*.

Neither is wrong. They are complementary in a very specific way: **ECC's best ideas are all about
the moment of action** (what happens the instant before an edit, what gets captured after a
session), while **EDM's strength is entirely about the shape of a whole initiative**. EDM's gaps
are almost all at ECC's timescale.

---

## Part 3 -- Where EDM is already ahead

Listed so the reader knows what *not* to touch. In each of these, importing ECC's version would be
a regression.

### 3.1 State machine

EDM's `bin/edm-state` is ~5,700 lines of bash exposing 39 subcommands, with a
`schema_version` contract that has three-valued degradation (absent = legacy, no enforcement;
present-but-lower = warn-and-proceed naming the check; at-or-above = enforce), a `SETTABLE_KEYS`
allowlist that prevents hand-flipping the version, and documented C-4 backward-compatibility
behaviour for every field.

ECC's nearest equivalent is `schemas/state-store.schema.json` plus `scripts/lib/state-store/`. It
persists session data. It does not gate anything, has no version contract, and nothing refuses on
its contents.

### 3.2 Findings ledger and convergence

EDM: `code-audit/findings-ledger.jsonl` is authoritative, carries stable `CA-NNN` IDs across
rounds, tracks fixed/re-opened status, records a `spec_swept` documentation-sweep flag that
*blocks* the gate when explicitly `no`, and feeds `edm-state audit-converged`, which exits non-zero
when the latest round is `partial`. `edm-state render-ledger` produces the markdown deterministically
from the JSONL so the two cannot drift.

ECC's nearest equivalent is the `recursive-decision-ledger` skill -- a well-written prose
description of append-only JSONL rollout ledgers with accept/watch/reject marks and coherence
checks. There is no implementation. It is a pattern document.

### 3.3 Multi-lens code audit

EDM runs 11 lenses (L1 logic, L2 dead code, L3 edge cases and concurrency, L4 test quality, L5
runtime hygiene, L6 documentation accuracy, L7 cross-file consistency, L8 security and
portability, L9 spec and ticket compliance, L10 DRY, L11 integration wiring), each a
130-200 line agent writing structured JSONL, then an `edm-audit-synthesizer` that applies a
second-pass false-alarm filter ranking by confidence rather than discarding, deduplicates
multi-lens findings, and merges into the cross-round ledger.

ECC has ~20 per-language reviewer agents (`python-reviewer`, `rust-reviewer`, ...) plus generic
`code-reviewer` and `security-reviewer`. Single pass. No structured output contract, no dedup, no
synthesizer, no ledger, no rounds. Its lens *taxonomy* has three ideas EDM lacks (see 4.4) but its
*machinery* is far behind.

### 3.4 Cost and time attribution

EDM records, per phase and per audit round: `duration_seconds`, a token object splitting
`input`/`output`/`cache_read`/`cache_write_5m`/`cache_write_1h`, `model_used`,
`estimated_cost_usd`, an `attribution_mode` enum (`scoped` vs `whole-directory`), and an
`unparseable_lines` count for torn session-JSONL lines. `/edm:metrics --calibrate` feeds measured
medians back into the phase timing guidelines.

ECC's `stop:cost-tracker` hook appends one cumulative row per session-stop to
`~/.claude/metrics/costs.jsonl`. Per session only. No phase, no task, no attribution mode.

### 3.5 Artifact governance

EDM lints its own artifacts at commit time via a `PreToolUse` hook on `git commit`, with
documented p95 latency budgets stated *against named fixtures* (3,000 ms for one initiative of 30
files / 9,990 lines on the commit path; 60,000 ms for a 50-initiative `--all` sweep) and an
explicit note that the two numbers must never be compared to each other.

ECC has `.markdownlint.json`.

---

## Part 4 -- Adopt: the case is made

Four items. In each, the gap in EDM was verified against source, the ECC artifact is directly
usable or directly translatable, and no prior decision is needed before starting. Ordered by my
confidence in the case, not by effort -- the effort ratings vary from hours (4.2) to a couple of
days (4.1).

### 4.1 GateGuard -- a fact-forcing gate on the edit itself

**Files**: `scripts/hooks/gateguard-fact-force.js` (~1,300 lines), `skills/gateguard/SKILL.md`.
Origin is a third-party project (`zunoworks/gateguard`, also on PyPI as `gateguard-ai`); ECC
vendored the hook.

**The idea.** EDM gates *phases*: a human approves Gate 1, Gate 2, Gate 3. Nothing whatsoever
gates the *individual edit*. An `edm-implementer` in a Phase 6 worktree can assume a date format,
write code against it, and still produce a passing QC verdict, because QC checks acceptance
criteria rather than assumptions.

GateGuard's premise is that asking a model to self-evaluate does not work. ECC states it plainly:
ask "did you violate any policies?" and the answer is always no. But ask "list every file that
imports this module" and the model *has no choice but to run Grep and Read* -- and the context that
investigation produces changes the output. The gate is not a confirmation prompt; it is a forced
research step.

**Mechanically**, it is a `PreToolUse` hook with three stages:

1. **DENY** -- the first `Edit`/`Write`/`MultiEdit` per file, and every destructive `Bash`, is
   refused. It returns the standard Claude Code shape:
   `{hookSpecificOutput: {permissionDecision: 'deny', permissionDecisionReason: <the fact list>}}`.
2. **FORCE** -- the denial reason is not "are you sure"; it is a numbered list of facts to produce.
3. **ALLOW** -- retrying the same file or command after presenting facts never re-triggers.

The four fact demands for an Edit:

```
1. List ALL files that import/require this file (search the tree)
2. List the public functions/classes affected by this change
3. If this file reads/writes data files, show field names, structure,
   and date format (use redacted or synthetic values, not raw production data)
4. Quote the user's current instruction verbatim
```

For a `Write` (new file) it swaps 1 and 2 for "name the file(s) and line(s) that will call this new
file" and "confirm no existing file serves the same purpose". For destructive `Bash` it asks for
the blast radius, a one-line rollback procedure, and the quoted instruction. Routine `Bash` is
gated **once per session** only -- ECC calls out over-gating as an anti-pattern explicitly.

`MultiEdit` is handled per-file, not per-call: it denies on the first still-unchecked file in the
batch, and a batch of three unchecked files needs **one retry per still-unchecked file**, not one
retry total (`gateguard-fact-force.js:1234-1256`) -- a mechanical subtlety an earlier reading of
this document omitted.

**Engineering quality.** This is one of the better-built files in ECC. Session state lives in
`~/.gateguard` scoped per session with a 30-minute inactivity timeout and a 500-entry cap.
Quoted strings and heredoc bodies are stripped before the destructive-command regex runs, so a
commit message containing "drop table" does not trigger it. If state cannot be persisted, the gate
**allows** rather than looping, and names the env var in the warning. Malformed operator regex is
treated as unset and logged once. There is an anti-context-flood control:
`GATEGUARD_FACT_FORCE_FULL_DENIALS` (default 3) emits the full four-fact block only for the first
N denials, condensing later ones to a single line carrying the ordinal, because near-identical deny
blocks accumulating in context were observed to amplify model repetition loops (their issue #2142).

**Graduated controls** -- and this is the part that makes it safe to adopt, because each narrows
one behaviour while leaving the load-bearing checks running:

| Variable | Default | Effect |
|---|---|---|
| `GATEGUARD_EXEMPT_GLOBS` | unset | Comma-separated globs; matching Edit/Write targets skip first-touch fact-forcing. For trees where "who imports this" carries no signal -- tests, generated artifacts, scratch dirs |
| `GATEGUARD_BASH_ROUTINE_DISABLED` | unset | Turns off the routine-Bash gate only; destructive-Bash checks unaffected |
| `GATEGUARD_BASH_EXTRA_DESTRUCTIVE` | unset | Extra destructive patterns as regex source, added to built-ins |
| `GATEGUARD_FACT_FORCE_FULL_DENIALS` | `3` | Full-block denials before condensing |
| `GATEGUARD_STATE_DIR` | `~/.gateguard` | Per-session state location |
| `ECC_GATEGUARD=off` | -- | Disables entirely |
| `GATEGUARD_DISABLED=1` | -- | A second, independent kill switch alongside `ECC_GATEGUARD=off` (`gateguard-fact-force.js:732-734`); this table originally omitted it. It recognizes only the literal `'1'`, not the word-forms `ECC_GATEGUARD` accepts |

Note a documented glob gotcha: a leading `**/` compiles to `.*/` and so requires at least one
preceding separator. `**/tests/**` matches `/repo/tests/foo.js` but not a bare relative
`tests/foo.js`. Both forms must be listed.

**Evidence, and how much to trust it.** ECC reports two A/B pairs -- identical agents, same task,
gated vs ungated -- scored 8.0 vs 6.5 on an analytics module and 10.0 vs 7.0 on a webhook
validator, averaging +2.25/10. Their stated observation is that both agents produced code that ran
and passed tests; the difference was design depth, and in both ungated runs the agent assumed
ISO-8601 dates where the real data used `%Y/%m/%d %H:%M`.

That is n=2, self-reported, unblinded, with no stated rubric. **Treat it as directional, not
proven.** The mechanism is nonetheless sound and matches something EDM already believes: EDM's
whole `edm-audit-*` design rests on the same premise that a separate critic beats self-assessment.
GateGuard applies that premise earlier in time.

**Recommendation for EDM.** Adopt, scoped narrowly:

- Register on `PreToolUse` matching `Edit|Write|MultiEdit`, active **only** during Phase 6, keyed
  off `edm-state get <PREFIX> current_phase` or an env var the implement skill sets.
- Ship a default `GATEGUARD_EXEMPT_GLOBS` covering test trees, `SRD/**` (EDM's own artifacts --
  "who imports this markdown file" is meaningless), and generated output.
- Replace fact 4 ("quote the user's instruction") with **"quote the acceptance criteria of the
  ticket you are implementing, by `{PREFIX}-T{NN}` ID"**. EDM has something better than a
  free-text instruction to force a quote of, and this makes the gate reinforce ticket traceability.
- Rewrite as bash for `bin/` consistency, or vendor the Node file as-is. The Node file is
  self-contained apart from two local requires (`shell-substitution.js`, `gateguard-heredoc.js`)
  which would need vendoring too.

**Effort**: medium (1-2 days including the phase-scoping and EDM-specific fact list).
**Risk**: low, given the graduated controls and fail-open behaviour.
**Value**: highest of anything in this report.

### 4.2 EDM's pattern-learning loop is inert on installed copies

This is not an ECC feature request. It is a **defect in EDM that ECC happens to have already
solved**, and it is the finding with the clearest immediate payoff.

**The defect.** `edm-state update-patterns <PREFIX> <srd|ticket|qc|code|test-coverage>` exists to
harvest novel audit findings out of a completed audit report and append them to EDM's shipped
pattern library, so future audits get smarter. It is called mid-phase by six skills (`implement`, `code-audit`, `audit-tickets`, `audit-srd`,
`test`, `test-coverage`). At `bin/edm-state:5607` the target directory is computed as:

```bash
local patterns_dir="${SCRIPT_DIR}/../docs/audit-patterns"
```

`SCRIPT_DIR` is the plugin's own `bin/`. So the write target is
`plugins/edm/docs/audit-patterns/*.md` -- **inside the plugin's installed tree**. At
`bin/edm-state:5640`:

```bash
echo "update-patterns: pattern directory is not writable at ${pattern_dir} \
(plugin may be installed read-only; skipping)" >&2
return 0
```

On any plugin-cache install that directory is not writable, so this is the path taken every time.
The consequence: **EDM's pattern library only ever grows for people running the plugin from a
checkout of this repository.** For every installed user, the learning loop is a no-op that logs to
stderr and returns success.

To be fair to the design: the skip is deliberate and graceful (warn, exit 0, never abort the
phase), and the comment shows the author anticipated read-only installs. What was not followed
through is where the data should go *instead*.

**ECC's answer to the identical problem.** `skills/continuous-learning-v2/` (v2.1) hit exactly
this wall -- background writes into `~/.claude` were being blocked by Claude Code's
sensitive-path guard -- and resolved it with a three-step resolution order documented in the
skill:

1. `CLV2_HOMUNCULUS_DIR` when set to an absolute path
2. `$XDG_DATA_HOME/ecc-homunculus`
3. `$HOME/.local/share/ecc-homunculus`

It also added **project scoping**, which is the second half of the answer. Learned data is keyed
by a 12-character project hash derived, in priority order, from `CLAUDE_PROJECT_DIR` (honored even
when not a git repo), then `git remote get-url origin` (hashed, so the same repo on two machines
yields the same ID), then `git rev-parse --show-toplevel`, then a global fallback. A registry at
`<data-dir>/projects.json` maps hashes to human-readable names. Data lands in
`projects/<hash>/instincts/` rather than a single global pile, so React conventions from one repo
do not leak into a Python repo.

Their third piece is a **promotion rule**: an instinct observed in 2+ distinct projects becomes a
candidate for promotion to global scope, via `/promote` (with `--dry-run` and `--force`), and
`/prune` deletes pending items older than 30 days that were never promoted.

**Recommendation for EDM.** Fix the write target. EDM's own `CLAUDE.md` already reserves
`${CLAUDE_PLUGIN_DATA}` for "plugin-internal caches only (convention detection, prefix lookup
tables)" -- a harvested pattern library is precisely that. So:

- Resolve the pattern directory to `${CLAUDE_PLUGIN_DATA}/audit-patterns/`, falling back to
  `${XDG_DATA_HOME:-$HOME/.local/share}/edm/audit-patterns/`.
- Treat the shipped `plugins/edm/docs/audit-patterns/*.md` as a **read-only seed**: on first run,
  copy them out, then append only to the writable copy. Readers concatenate seed + harvested.
- Consider project scoping later. EDM already has a stronger key than a git-remote hash --
  the initiative PREFIX and `product_name` -- so per-product pattern files are the natural
  granularity if cross-project contamination ever becomes a real complaint. Do not build it
  speculatively.
- Skip the promotion/prune machinery for now. EDM's audit patterns are curated content reviewed
  by a human, not confidence-scored observations; the 2+ projects rule solves a problem EDM does
  not have.

**Effort**: small (a few hours -- one path resolution, one seed-copy, one test).
**Risk**: low.
**Value**: high, and it is a bug fix rather than an enhancement.

### 4.3 An automatic size classifier at the orchestrator's front door

**File**: `skills/orch-pipeline/SKILL.md`, Step 0.

**Context on ECC's orch-\* family.** ECC has five thin "operation" skills --
`orch-add-feature`, `orch-change-feature`, `orch-fix-defect`, `orch-refine-code`,
`orch-build-mvp` -- that share one engine, `orch-pipeline`. The engine defines seven phases
(0 Intake, 1 Research and Reuse, 2 Plan, 3 Scaffold, 4 Implement via TDD, 5 Review, 6 Commit),
two human gates (after Plan, before Commit), and an agent map naming which agent runs each phase.
The wrappers do not reimplement anything; they select which phases run.

**The part worth taking** is Step 0, "Classify size (right-sizing)". The stated principle is
*ceremony scales to blast radius*. Three signals are scored, the **highest** tier any one signal
reaches wins, and the result is stated in one line so the user can override:

| Tier | Files touched | New dependency / contract | Design ambiguity | Phases that run |
|---|---|---|---|---|
| trivial | 1, a few lines | none | none, the change is obvious | 4, 5, 6 |
| small | 1 file / 1 function | none | clear once you read the code | (1 light), 4, 5, 6 |
| standard | 2-5 files | maybe a new internal module | one real choice to make | 1, 2, 4, 5, 6 |
| large | many / cross-cutting | new external dep, public API, or a spec doc | multiple open questions | 1, 2, (3), 4, 5, 6 |

With a tie-breaker: anything touching a security trigger or a public API/contract is **at least**
standard regardless of file count. ECC's security triggers, from `orch-pipeline/SKILL.md:100-104`
(not `rules/common/security.md`, which holds an unrelated 8-item pre-commit checklist -- see the
Part 8.2 correction), are:
authentication or authorization, user-input handling, database queries, filesystem paths, external
API calls, cryptography, secrets or credentials.

**Why EDM needs this.** EDM already has the *destinations* -- five `mode` values (`standard`,
`mini-srd`, `iac`, `data-ml`, `prototype`) and three `lifecycle_mode` values (`standard`,
`fast-track`, `fix-pack`), which between them can collapse the six phases down to a single
ticket-pack review gate. What EDM lacks is the *routing*. The user must already know
`lifecycle_mode=fix-pack` exists and set it by hand; someone arriving with a 20-line bug fix and
no prior EDM knowledge gets the full six-phase flow by default.

Whether that default actually costs EDM anything in practice is **unmeasured** -- no usage data,
no user feedback, and no adoption complaints were consulted for this document. The argument here
is structural only: the cheap paths exist but are reachable only by prior knowledge. If in
practice every EDM user already knows the mode matrix, this recommendation is worth little.

**Recommendation.** `skills/orchestrator/SKILL.md` Step 1c already presents the mode matrix
interactively. Add the classifier immediately before it and use the result to **pre-select** a
recommendation, stated in one line with the reasoning, that the user confirms or overrides. Map
the tiers onto EDM's existing enums -- roughly trivial/small -> `lifecycle_mode=fix-pack`,
standard -> `mode=mini-srd`, large -> full `standard`. Adopt the security-trigger tie-breaker
verbatim; it composes cleanly with EDM's existing `compliance_enabled` Gate 3.5.

**Effort**: small (~30 lines of skill prose, no new binary, no state change).
**Risk**: very low -- it is a default, not an enforcement.
**Value**: highest value-per-unit-effort in this document, *conditional* on the unmeasured premise
above being true.

### 4.4 Three audit lenses ECC has that EDM's eleven do not cover

EDM's lens taxonomy is stronger than ECC's overall, but three of ECC's reviewer agents cover
ground that no EDM lens claims.

**`agents/silent-failure-hunter.md`** -- opens with "You have zero tolerance for silent failures"
and hunts five categories: empty catch blocks and errors converted to `null`/`[]` without context;
inadequate logging (missing context, wrong severity, log-and-forget); **dangerous fallbacks**
(default values that hide real failure, `.catch(() => [])`, graceful-looking paths that make
downstream bugs harder to diagnose); error propagation problems (lost stack traces, generic
rethrows, missing async handling); and missing handling entirely around network/file/db paths or
transactional work without rollback.

*The EDM gap*: L1 (Logic, Correctness and Completeness) explicitly lists "empty catch blocks" as a
hunt target. Nothing in L1-L11 hunts the **fallback that succeeds while hiding a failure** -- which
is the more dangerous and much harder-to-spot half of this category, and one that a passing test
suite actively conceals.

**`agents/type-design-analyzer.md`** -- evaluates "whether types make illegal states harder or
impossible to represent" across four dimensions: encapsulation (are internals hidden, can
invariants be violated from outside), invariant expression (do types encode business rules),
invariant usefulness (do they prevent real bugs, are they domain-aligned), and enforcement (does
the type system enforce them, are there easy escape hatches).

*The EDM gap*: total. No lens touches type design. For a plugin whose implementers write
TypeScript, Kotlin, Swift and Rust, this is a real hole.

**`agents/pr-test-analyzer.md`** -- asks whether a change's tests cover the changed *behaviour*:
map changed functions to their tests, find new untested paths, verify edge and error paths, prefer
meaningful assertions over no-throw checks, flag flaky patterns, then rate gaps
critical/important/nice-to-have.

*The EDM gap*: EDM has two adjacent things that both miss this. L4 (Test Quality) hunts defects
*in the tests themselves* -- `2>/dev/null || true` masking failures, mocks hiding the code under
test. `edm-test-coverage-auditor` reports *percentages* against configured thresholds. Neither
asks the question "would these tests catch a real bug in this change?"

**Important caveat on quality.** All three ECC agents are thin -- `silent-failure-hunter`'s body is
44 lines after the boilerplate defense block, not "~30" (the other two are 35 and 39) -- with
output formats given as four-item bullet lists. EDM's lens
agents run 130-200 lines with structured JSONL output contracts, explicit false-alarm guidance,
and defined severity vocabulary. **Take the taxonomy, not the prompts.**

**Recommendation.** Add as lenses **L12 (Silent Failures), L13 (Type Design), L14 (Behavioral Test
Coverage)** rather than as standalone agents. Written as lenses they inherit EDM's entire existing
machinery for free -- JSONL output, the ledger, stable `CA-NNN` IDs, the synthesizer's false-alarm
filter, round typing, and convergence. Written as agents they would inherit none of it. Note that
`skills/code-audit/SKILL.md` hardcodes eleven lens IDs in several places (`lens-L1.jsonl` through
`lens-L11.jsonl`, the "absence of `--lenses` means run all 11" rule, and
`audit_rounds.<type>.rounds[].round_type` deriving `full` from "the lens set equals all eleven lens
IDs"), so this is not purely additive -- the count is load-bearing and appears in
`bin/edm-state` as well.

L13 in particular should be **conditional on stack**, since type design is meaningless in
untyped code. EDM's mode matrix already has precedent for stack-conditional behaviour.

**Effort**: medium (three lens agents in EDM's house style, plus updating the hardcoded lens count
in skill and state code).
**Risk**: medium -- more lenses means more audit cost per round, and EDM already tracks
tiered-vs-untiered lens cost precisely because this matters. Measure with `/edm:metrics` before
making all three unconditional.
**Value**: high for L12, high for L13 on typed stacks, medium for L14.

---

## Part 5 -- Qualified: worth something, but read the qualifier first

These six do **not** share a single property, and an earlier revision of this document mislabelled
them as if they did ("real value but real work" -- which is simply false for 5.4, the smallest
item in the report). Each is here for its own reason, and the reason changes what you would
actually build:

| Item | Why it is not in Part 4 | Effort |
|---|---|---|
| 5.1 Implementer/QC iteration loop | Largest item in the report; needs a cost ceiling designed before anything is built | large |
| 5.2 Repo-readiness scorecard | ECC's implementation is not reusable -- only the rubric *shape* transfers. Value depends on 4.3 landing first | medium |
| 5.3 Hookify rules layer | Solves a team-extensibility problem that has not been shown to exist for EDM yet | medium |
| 5.4 Stop-hook completion gate | Small and low-risk, but strictly a timing improvement -- EDM already blocks on all of it at `archive` | **small** |
| 5.5 Codemaps | Recommendation is largely *against* porting ECC's script; the idea needs a fresh implementation, or none | medium-large |
| 5.6 Modular install | Not actionable on its own -- conditional on the Part 7 kernel/methodology split ever being pursued | n/a |

5.4 is the one to look at first if the goal is a quick win; 5.1 is the one with the highest
ceiling if the goal is capability.

### 5.1 Close the implementer/QC loop into an adversarial iteration

**File**: `skills/gan-style-harness/SKILL.md`, plus agents `gan-planner`, `gan-generator`,
`gan-evaluator`, the driver `scripts/gan-harness.sh`, and commands `/gan-build`, `/gan-design`.

**What it is.** ECC's harness separates generation from evaluation into distinct agents and
iterates between them. Its stated core insight is worth quoting because it is the same belief
EDM's audit design rests on:

> When asked to evaluate their own work, agents are pathological optimists -- they praise mediocre
> output and talk themselves out of legitimate issues. But engineering a separate evaluator to be
> ruthlessly strict is far more tractable than teaching a generator to self-critique.

Three agents: a **Planner** that expands a one-line brief into a multi-sprint specification and,
critically, also produces the evaluation criteria the Evaluator will later use; a **Generator**
that implements in sprints and reads the previous iteration's feedback; and an **Evaluator** that
drives the **live running application** via Playwright MCP -- clicking through features, filling
forms, hitting endpoints -- rather than reading code.

Scoring is a weighted rubric, each criterion 1-10 with explicit band descriptions, defaults being
Design Quality (0.3), Originality (0.2), Craft (0.3), Functionality (0.2). Weighted score = sum of
score x weight. **Pass threshold 7.0, max iterations 15**, both configurable
(`GAN_PASS_THRESHOLD`, `GAN_MAX_ITERATIONS`), with per-role model overrides
(`GAN_GENERATOR_MODEL=opus` etc.). The loop terminates on threshold or plateau.
**`GAN_EVAL_CRITERIA` is documented but dead code** -- `scripts/gan-harness.sh` never reads it, so
it is not a real knob and should not be ported as one.

**Where EDM stands.** EDM already has the hard part: genuine generator/evaluator separation, with
`edm-implementer` producing and `edm-qc-auditor` judging, the latter auto-spawned by a
`SubagentStop` hook and denied `Edit`/`NotebookEdit` so it structurally cannot fix what it
criticizes. Verdicts are PASS/PARTIAL/FAIL with `file:line` evidence, sharded per implementer to
avoid the concurrent-overwrite bug documented as CA-440.

What EDM lacks is the **loop**. QC writes a verdict shard, `/edm:implement` merges shards into
`qc-summary.md`, and then a human reads it. PARTIAL verdicts are closed manually later via
`/edm:verify-runtime`, which records `closing_verdict` and a mandatory non-empty
`verification_ref`. That is the hand-cranked version of an iteration.

**Recommendation.** Add a bounded auto-remediation loop to Phase 6: on a FAIL verdict, respawn the
implementer with the QC report as input, up to N rounds (2 or 3), then escalate to the human. EDM
already has everywhere to record it -- the ledger, `closure_history`, the `prior` preservation on
re-closure. Take from ECC specifically: (a) the configurable pass threshold and max-iteration
ceiling as explicit knobs rather than hardcoded values, (b) plateau detection as a second stop
condition alongside the iteration cap, and (c) the discipline that the *evaluator* owns the rubric
and it is fixed before generation starts.

Do **not** take the Playwright-driven live-app evaluation. EDM has `/edm:verify-runtime` for
runtime evidence and it is deliberately human-gated.

**Effort**: large. **Risk**: medium (unbounded cost is the obvious failure mode; the iteration cap
is the mitigation). **Value**: high -- it is the natural next step for machinery EDM has already
built and is currently only half-using.

### 5.2 A repo-readiness scorecard -- take the rubric shape, not the checks

**File**: `scripts/harness-audit.js` (~1,100 lines), command `/harness-audit`.

**What it claims to be.** A deterministic repository audit producing a prioritized scorecard
across 12 categories, each normalized 0-10: Tool Coverage, Context Efficiency, Quality Gates,
Memory Persistence, Eval Coverage, Security Guardrails, Cost Efficiency, GitHub Integration, plus
Vercel / Netlify / Cloudflare / Fly, the last four applicable only when a marker file is detected
(`vercel.json`, `netlify.toml`, `wrangler.toml`, `fly.toml`). The rubric carries a version string
(`2026-05-19`) and the command doc states "Do not invent additional dimensions or ad-hoc points."
Output is text or JSON.

**What it actually is -- and this changes the recommendation.** The scoring engine is a flat array
of check objects, each shaped:

```js
{
  id: 'context-suggest-compact-hook',
  category: 'Context Efficiency',
  points: 3,
  scopes: ['repo', 'hooks'],
  path: 'scripts/hooks/suggest-compact.js',
  description: 'Suggest-compact automation hook exists',
  pass: fileExists(rootDir, 'scripts/hooks/suggest-compact.js'),
  fix: 'Implement scripts/hooks/suggest-compact.js for context pressure hints.',
}
```

`detectTargetMode()` distinguishes "repo mode" (auditing ECC itself) from "consumer mode"
(auditing a project that uses ECC). **In repo mode the checks are almost entirely `fileExists`
against ECC's own paths** -- it scores you on whether you have `skills/strategic-compact/SKILL.md`
and `commands/model-route.md`. That is not a readiness rubric; it is an ECC installation
completeness check.

Consumer mode is more honest but shallow -- 16 checks worth 39 points once the
unconditionally-appended GitHub checks are counted: is ECC installed (4
points, self-serving), does `.claude/` carry project overrides, is there an `AGENTS.md` or
`CLAUDE.md`, is there `.mcp.json` or `.claude/settings.json`, is there a test entrypoint, is there
a CI workflow, is there `.claude/memory.md` or `docs/adr/`, are there evals or 3+ tests, is there
a `SECURITY.md` or dependabot/codeql config, does `.gitignore` contain `.env`, do project hooks
mention `PreToolUse`.

**What is genuinely worth stealing** is therefore the *shape*, not the content:

- fixed category list, each normalized to 0-10, so scores are comparable across runs
- a **versioned rubric string** so a score can be traced to the rubric that produced it
- per-check `points`, `scopes`, and -- the best detail -- a `fix:` string carried on the check
  itself, so the report is actionable without a second pass
- categories that are *conditionally applicable* based on detected markers, with the denominator
  adjusting rather than penalising absence (`applicableCategories` filters on `max > 0`)
- pure `fileExists`-grade determinism, so the same commit always scores the same

**Why EDM wants one.** EDM measures *itself* via `/edm:metrics` -- time and cost per phase. It
never scores the *repository it is about to work in*. Yet that is exactly the information that
should drive the size classifier in 4.3: a repo with no tests, no CI and no `CLAUDE.md` should
route differently from a mature one. A `/edm:audit-harness` run during Phase 1 would feed the
classifier real signal, and its findings are precisely the kind of thing that belongs in
`planning.md`.

**Recommendation.** Write EDM's own check table -- roughly 20-30 checks in EDM's categories --
using ECC's object shape and the versioned-rubric discipline. Do not port the file. Compose with
4.3.

**Effort**: medium. **Risk**: low. **Value**: medium alone, high combined with 4.3.

### 5.3 Hookify -- let teams write their own enforcement without editing the plugin

**Files**: `skills/hookify-rules/SKILL.md`, commands `/hookify`, `/hookify-list`,
`/hookify-configure`, `/hookify-help`, agent `conversation-analyzer`.

**What it is.** A small rules-as-data layer. A rule is a markdown file at
`.claude/hookify.{name}.local.md`:

```markdown
---
name: warn-env-api-keys
enabled: true
event: file
conditions:
  - field: file_path
    operator: regex_match
    pattern: \.env$
  - field: new_text
    operator: contains
    pattern: API_KEY
---

You're adding an API key to a .env file. Ensure this file is in .gitignore!
```

Events are `bash`, `file`, `stop`, `prompt`, or `all`. Actions are `warn` (default, shows the
message) or `block` (prevents the operation). The simple form takes a single `pattern`; the
advanced form takes a `conditions` list where **all** must match. Available fields depend on the
event -- `command` for bash; `file_path`, `new_text`, `old_text`, `content` for file;
`user_prompt` for prompt. Operators are `regex_match`, `contains`, `equals`, `not_contains`,
`starts_with`, `ends_with`. Naming convention is verb-first (`warn-*`, `block-*`, `require-*`).

The genuinely clever part is `/hookify` **with no arguments**: it invokes the
`conversation-analyzer` agent, which reads the session transcript looking for explicit
corrections, frustrated reactions to repeated mistakes, reverted changes, and repeated similar
issues -- then proposes rules for the behaviours it finds. The user approves, and the rule files
are written. It closes the loop from "Claude keeps doing this annoying thing" to "there is now a
hook preventing it" inside one session.

The skill also documents its own failure modes honestly: patterns too broad (`log` matches
"login" and "dialog"; use `console\.log\(`), too specific (`rm -rf /tmp`; use `rm\s+-rf`), and
YAML escaping traps (use unquoted patterns, since quoted strings need `\\s`).

**Why EDM wants it.** EDM's enforcement is entirely hardcoded bash --
`edm-lint-artifacts`, `edm-check-grants`, `edm-check-vocabulary`, the gate hooks. A team with its
own conventions (a required ticket-ID format in commit scopes, a banned import, a mandated
directory) has no way to add enforcement without editing the plugin and carrying a fork.

**Recommendation.** Adopt as a small, contained subsystem: a rule loader in `bin/`, a
`PreToolUse`/`Stop` dispatcher that evaluates enabled rules, and rules living under the project's
`SRD/` root or `.claude/` so they are source-controlled like every other EDM artifact -- which
fits EDM's "source control IS the feature" principle better than ECC's `.local.md` +
gitignore convention. The conversation-analyzer half is optional and can come later.

**Effort**: medium -- and this estimate assumes no evaluator exists to adapt. **ECC has no rule
evaluator at all**: `/hookify*` commands write, list and toggle rule files, but nothing evaluates
them at tool-call time -- the condition/operator engine described above is documentation with no
corresponding code (exhaustive search of `scripts/`, `hooks/hooks.json` and all six operator
names). EDM therefore builds the evaluator entirely from scratch; only the JSON rule-file *format*
is reusable. **Risk**: low, if `action: block` requires explicit opt-in per rule.
**Value**: medium-high, mostly for team adoption.

### 5.4 A Stop hook that blocks premature completion claims

**File**: `skills/delivery-gate/SKILL.md` plus `skills/delivery-gate/hooks/quality-gate.py`.

**What it is.** A `Stop` hook that refuses to let the agent declare a session finished until
deterministic checks pass. The design constraint is the interesting bit -- it uses **only**
machine-verifiable facts: file modification timestamps, `shutil.disk_usage`, and regex over the
transcript tail. No AI inference anywhere.

| Check | Mechanism | On hit |
|---|---|---|
| Rationalization patterns | Regex on transcript tail | **Warning only, never blocks** |
| Stale learning libraries | mtime on 5 configurable paths | Warn if some stale; **block** if >=3 stale, or the growth log is stale on a complex task |
| Disk space < 50 GB | `shutil.disk_usage` | Warning |
| Disk space < 30 GB | `shutil.disk_usage` | Warning (undocumented third tier, present in code between the 50GB and 15GB tiers but absent from `SKILL.md`) |
| Disk space < 15 GB | `shutil.disk_usage` | **Block** (exit 2) |

ECC positions it explicitly against reasoning-based gates: *delivery-gate checks
machine-verifiable facts; self-audit checks output quality*. And it is disciplined about which
signals earn the right to block -- rationalization detection looks for phrases like "skip tests
for now" and "pre-existing bug", but it **never blocks**, because "regex heuristics can
false-positive".

**What is applicable to EDM.** The specific checks are useless here -- learning-log mtime and disk
headroom are ECC's concerns. The *pattern* maps directly onto facts EDM already tracks and
currently enforces too late:

- `partial_verdict_map` entries that are open or FAIL-closed
- an audit round that was started and never completed (EDM already surfaces this as the
  informational `OPEN_AUDIT_ROUND` anomaly on `edm-state validate`)
- ledger entries marked `status: fixed` carrying `spec_swept: no`
- a phase marked started with no `completed_at`

Today all of these block at `edm-state archive` -- the very end of an initiative. Surfacing them
at `Stop` makes the debt visible the moment it is created rather than weeks later. EDM already has
the query (`edm-state validate`) and already has a `Stop` hook (`checkpoint-if-active`) to extend.

Adopt ECC's discipline alongside the pattern: **warn by default, block only on the subset that is
unambiguous**. EDM already applies exactly this reasoning to `spec_swept`, where only the explicit
string `no` blocks and an absent field never does.

**Effort**: small (extend the existing `Stop` hook to also run `edm-state validate` and surface
blocking anomalies). **Risk**: low, if warn-first. **Value**: medium.

### 5.5 Codemaps -- take the idea, do not port the script

**Files**: `scripts/codemaps/generate.ts`, command `/update-codemaps`, agent `doc-updater`.

**The idea, which is good.** Generate a deterministic, token-lean map of a repository's *current*
architecture, so agents read a compact artifact instead of re-deriving structure by grepping the
tree. The generator classifies files into five areas by path and extension regex -- frontend,
backend, database, integrations, workers -- and writes `docs/CODEMAPS/INDEX.md` plus one file per
area.

**What the command doc promises**: token-lean call chains such as

```
POST /api/users -> UserController.create -> UserService.create -> UserRepo.insert
```

**What the script actually produces**: per area, a header with file count and total lines, an
"Entry Points" list, an "Architecture" section containing a directory tree, a "Key Modules" table
of file paths and line counts, and then:

```markdown
## Data Flow

> Detected from file patterns. Review individual files for detailed data flow.

## External Dependencies

> Run `npx jsdoc2md src/**/*.ts` to extract JSDoc and identify external dependencies.
```

Those two sections are literal placeholders in the template. The call-chain example lives only in
the command's *agent guidance*, not in the generator. So the script is a file inventory with an
architecture-shaped outline around it.

**Why the idea still matters for EDM.** Phase 1 spawns parallel `edm-explorer` agents that map
scope boundaries and dependencies from scratch, every initiative, at full model cost, writing to
`explorers/{NN}-{slug}.md`. For a repository with several initiatives over time, that is the same
structural discovery paid for repeatedly. A generated, cheap, deterministic current-architecture
map that explorers *start from* would plausibly reduce that cost -- by how much is unknown and
unestimated here. EDM already records per-phase token counts, so a Phase 1 cost figure from any
completed initiative would turn this from a plausible claim into a measured one before any work
is done.

Note this does not duplicate EDM's `architecture.md`, which is the **target** architecture written
by `edm-architect` in Phase 2 (Mermaid diagrams, component boundaries, integration patterns for
what is being built). A codemap is the **current** architecture. Complementary.

**Recommendation.** Low priority, and write it fresh if written at all. The valuable version is
language-aware enough to extract real route-to-handler-to-service chains, which is a genuinely
harder problem than ECC solved. An honest interim: have the first explorer of an initiative write
a reusable `SRD/.codemap.md` that later initiatives read and refresh, rather than building a
generator at all.

**Effort**: medium-large for a real one. **Risk**: low. **Value**: medium, and better revisited
once the Part 4 items have landed and a measured Phase 1 explorer cost exists to judge it against.

### 5.6 Modular install

Covered mechanically in 1.5. Relevant to EDM only if it splits along the lines suggested in Part
7. If `/edm:code-audit` ever ships standalone, ECC's profiles -> modules -> components structure,
with per-module `dependencies` / `cost` / `stability` / `targets` and a JSON Schema per manifest
enforced in CI, is a good model to copy. Until then it solves a problem EDM does not have.

---

## Part 6 -- Reject, with reasons

**The 286 skills and 68 agents as a body.** A catalog is the opposite of a methodology. EDM's
value proposition is that it is opinionated about one process; importing breadth dilutes exactly
that. Individual items are worth taking (Parts 4 and 5); the collection is not.

**The 13-target cross-harness export layer.** Enormous maintenance surface --
`scripts/harness-adapter-compliance.js`, `scripts/gemini-adapt-agents.js`,
`scripts/build-opencode.js`, `scripts/sync-ecc-to-codex.sh`, `scripts/lib/install-targets/`,
`docs/MANUAL-ADAPTATION-GUIDE.md`, and per-target guide docs. And ECC's own `SOUL.md` concedes it
is aspirational: *"This gitagent surface is an initial portability layer... Native agents,
commands, and hooks remain authoritative in the repository until full manifest coverage is
added."* EDM targets Claude Code. Keep it that way.

**ECC's plugin-root resolver.** A ~1 KB minified `node -e "..."` expression that walks env var ->
standard install -> six known plugin directory names -> plugin cache -> fallback. It appears
inline in every `hooks.json` entry *and* is pasted verbatim into the visible body of several slash
commands. EDM solved the same problem correctly by putting `bin/` on PATH and calling scripts by
bare name. Do not import this under any circumstances.

**Autonomous loops, crons, computer use.** `autonomous-agent-harness`, `continuous-agent-loop`,
`autonomous-loops`, `/loop-start`, `/loop-status`, `/santa-loop`, `loop-operator`. These build
toward unattended operation. EDM is HITL-gated by design -- the gates are the product. Directly
opposed.

**Multi-model orchestration.** `/multi-plan`, `/multi-execute`, `/multi-backend`,
`/multi-frontend`, `/multi-workflow` route work to Codex and Antigravity through an external
`ccg-workflow` runtime. ECC flags this itself: *"Requires the external ccg-workflow runtime, which
is not part of the base ECC install... Without that runtime, this command will not run
correctly."* An undeclared external dependency in a plugin is a support burden.

**`token-budget-advisor`, `strategic-compact`, `context-budget`.** Reasonable ideas, but
host-level concerns. `strategic-compact` in particular reads the session transcript to infer
context pressure and suggests `/compact` at thresholds -- work the harness itself now does.

**The Prompt Defense Baseline block.** Six identical bullets copy-pasted into the top of every
agent and skill body, costing context on every load. EDM handles the same concern with narrow
tool grants per agent (`Edit`/`NotebookEdit` denied on read-only auditors), which is enforcement
rather than instruction.

**`ecc2/`.** An in-progress 2.0 rewrite living alongside 1.x with a migration guide and a GA
roadmap. Not settled enough to learn from.

---

## Part 7 -- On reimagining EDM

The honest conclusion after reading both: **EDM does not need reimagining. It needs a smaller
front door and a detachable kernel.**

### 7.1 The front door

EDM's own published timing guidelines put a small initiative (10-20 tickets) at 1-2 days end to
end, with 30 minutes of planning before the SRD starts. That is a stated design parameter, not a
criticism -- it is the cost of the guarantees EDM provides.

The structural observation is narrower: EDM has cheap paths (`lifecycle_mode=fix-pack`,
`mode=prototype`, `mode=mini-srd`) but no mechanism that *selects* one from the request. ECC has
the opposite balance -- weaker guarantees, but `/orch-fix-defect` classifies the request itself
and runs three phases instead of seven. Section 4.3 proposes borrowing the classifier.

Whether this matters depends on a fact not established here: how often EDM is asked to handle
work below its design point, and whether the people asking know the mode matrix exists. Usage
data would settle it; none was consulted.

### 7.2 The kernel

The deeper structural observation. EDM contains two separable things:

**A verification kernel** -- `edm-state` and its schema contract, the JSONL findings ledger with
stable IDs and cross-round status, the eleven-lens machinery and its synthesizer with the
false-alarm filter, convergence checking, artifact linting, and per-phase cost attribution. None
of this is inherently about a six-phase SDLC. It is a general apparatus for *proving a body of
work converged*.

**A methodology** -- the six phases, the HITL gates, SRDs, ticket packs, the mode matrix. This is
one consumer of the kernel.

The concrete form this could take is `/edm:code-audit` **standing alone**: point it at any
repository, with no initiative, no SRD, no prefix and no gates, and get eleven lenses, a
synthesized severity-ranked remediation plan, and a findings ledger that remembers across runs.

Nothing in the 286 ECC skills read or enumerated for this document comes close to that. I have
**not** surveyed the wider Claude Code plugin ecosystem and make no claim about it.

Whether an unbundled audit would actually find users is unknown -- it is a hypothesis about
demand, and this document contains no evidence for it. What can be said from the source alone is
narrower and still useful: the kernel has no *technical* dependency on the methodology, so the
split is feasible whether or not it is wanted. If it were ever pursued, ECC's modular install
manifests (1.5, 5.6) are a reasonable packaging model.

This is a suggestion, not a recommendation to act on now. It is a larger change than everything in
Parts 4 and 5 combined, and those should be done first regardless of whether the split ever
happens.

---

## Part 8 -- Method, verification status, and caveats

### 8.1 What was actually examined

Read in full: `SOUL.md`, `RULES.md`, `CLAUDE.md`, `hooks/hooks.json` (all 25 registrations),
`manifests/*.json` (all three), `scripts/harness-audit.js` (structure, mode detection, and the
full consumer-mode check table), `scripts/hooks/gateguard-fact-force.js` (~400 lines including all
config handling and the decision shape), `scripts/hooks/posttooluse-dispatcher.js`,
`scripts/hooks/observe-runner.js`, `scripts/hooks/evaluate-session.js`,
`scripts/ci/validate-skills.js`, `scripts/codemaps/generate.ts` (classification and output
templates), `bin/edm-state`'s `cmd_update_patterns` on the EDM side.

Skills read in full or near-full (~25): `gateguard`, `continuous-learning-v2`, `orch-pipeline`,
`gan-style-harness`, `delivery-gate`, `safety-guard`, `search-first`, `verification-loop`,
`hookify-rules`, `skill-scout`, `skill-stocktake`, `rules-distill`, `recursive-decision-ledger`,
`eval-harness`, `agent-eval`, `cost-tracking`, `context-budget`, `token-budget-advisor`,
`strategic-compact`, `parallel-execution-optimizer`, `autonomous-agent-harness`,
`living-docs-governance`, `intent-driven-development`, `codebase-onboarding`, `production-audit`.

Agents read in full (11): `silent-failure-hunter`, `spec-miner`, `type-design-analyzer`,
`code-simplifier`, `comment-analyzer`, `harness-optimizer`, `agent-evaluator`, `chief-of-staff`,
`loop-operator`, `conversation-analyzer`, `pr-test-analyzer`.

Commands read (14): `learn`, `evolve`, `prune`, `promote`, `harness-audit`, `quality-gate`,
`skill-health`, `instinct-status`, `epic-decompose`, `epic-claim`, `epic-validate`, `model-route`,
`multi-plan`, `orch-build-mvp`, `hookify`, `update-codemaps`, `sessions`.

Enumerated by name and frontmatter only: the remaining ~261 skills, ~57 agents, ~77 commands.

### 8.2 Claims that were verified against source, not taken from documentation

- The `update-patterns` read-only skip (4.2) -- confirmed by locating the symbols by name; see
  correction 8 below for the re-derived citations. Line numbers here are advisory.
- `harness-audit` scoring being `fileExists` against ECC's own paths (5.2) -- confirmed by reading
  the check table and `detectTargetMode()`. **This corrects an earlier assessment of mine that
  treated it as a neutral readiness rubric.**
- The codemap generator's placeholder Data Flow and External Dependencies sections (5.5) --
  confirmed by reading the output template at `scripts/codemaps/generate.ts:225-231`. **This also
  corrects an earlier assessment that credited it with producing call chains.**
- GateGuard's deny mechanism -- confirmed as `permissionDecision: 'deny'` with the fact list
  carried in `permissionDecisionReason`.
- ECC's own headline counts in `SOUL.md` (30 agents / 135 skills / 60 commands) are stale; the
  tree contains 68 / 286 / 94.

**Eleven further corrections, verified during EDMV4 Phase 1 (2026-09-02) and applied in place at
their own sites in Parts 1, 4 and 5:**

1. **Hook count.** Part 1.2 and Part 1.6 said 25 hooks across eight events. **This corrects that
   summary total**: it is 23 registrations across seven events. The per-event table's own rows were
   already correct; only the summary total and event-type count were wrong.
2. **Security-trigger citation.** Part 4.3 cited `rules/common/security.md` for the seven security
   triggers. **This corrects a citation the document repeated from ECC without checking**: that
   file holds an unrelated 8-item pre-commit checklist. The triggers live at
   `orch-pipeline/SKILL.md:100-104`, which itself miscites `security.md` -- that miscitation is how
   the error propagated here.
3. **Hookify evaluator.** Part 5.3's effort estimate implicitly assumed there was existing
   evaluator logic to adapt. **This corrects that assumption**: ECC has no evaluator at all: the
   `/hookify*` commands manage rule files, but nothing evaluates them at tool-call time. Only the
   rule-file *format* is reusable.
4. **`GAN_EVAL_CRITERIA`.** Part 5.1 listed it alongside two real, code-read configuration knobs.
   **This corrects that listing**: `scripts/gan-harness.sh` never reads it, so it is documented but
   dead code, not a real knob to port.
5. **`delivery-gate` disk tiers.** Part 5.4's table listed two disk-space tiers (50GB warning,
   15GB block). **This corrects an incomplete table**: the code carries an undocumented third tier,
   a 30GB warning, between the two.
6. **`silent-failure-hunter` body length.** Part 4.4 described all three ECC agents as "roughly 30
   lines" of body. **This corrects that figure for `silent-failure-hunter` specifically**: its body
   is 44 lines, 47% higher than stated; the other two are 35 and 39.
7. **`harness-audit.js` consumer-mode scoring.** Part 5.2 stated 11 checks worth ~29 points.
   **This corrects that count**: it is 16 checks worth 39 points once the unconditionally-appended
   GitHub checks are counted.
8. **`update-patterns` citations and caller count.** Part 4.2 cited `bin/edm-state:5577` and
   `:5624`, and said the function is called mid-phase by four skills. **This corrects both**: the
   current-tree citations are `:5607` (target-directory computation) and `:5640` (the read-only
   skip message), and the verified caller set is six skills (`implement`, `code-audit`,
   `audit-tickets`, `audit-srd`, `test`, `test-coverage`).
9. **GateGuard kill switches.** Part 4.1's environment-variable table listed only
   `ECC_GATEGUARD=off`. **This corrects an incomplete table**: `GATEGUARD_DISABLED=1` is a second,
   independent kill switch (`gateguard-fact-force.js:732-734`), recognizing only the literal `'1'`
   and not the word-forms `ECC_GATEGUARD` accepts.
10. **`MultiEdit` retry semantics.** Part 4.1 said `MultiEdit` is handled per-file, not per-call,
    without stating what that means for retries. **This corrects the omission**: it denies on the
    first still-unchecked file in the batch, so a batch with three unchecked files needs one retry
    per still-unchecked file, not one retry total (`gateguard-fact-force.js:1234-1256`).
11. **Codemaps placeholder citation.** This section's own earlier entry cited
    `scripts/codemaps/generate.ts:200-240` for the placeholder Data Flow and External Dependencies
    sections. **This corrects that line range**: the placeholders are at `:225-231`; the substance
    of the original claim (that they are literal template placeholders) is confirmed unchanged.

### 8.3 Claims NOT verified

- **The GateGuard +2.25 result.** Self-reported, n=2, unblinded, no published rubric or task
  definitions. Directional only. The mechanism is sound independent of the number.
- **The harness-audit rubric weights.** Point values per check appear to be assigned by judgement;
  no derivation is documented.
- **ECC's claim that `orch-*` wrappers do not reimplement work.** The five wrapper skills were not
  read individually.
- **Whether ECC's test suite passes.** `node tests/run-all.js` was not executed.

**Resolved and moved out of this list (2026-09-02):** GateGuard's upstream `zunoworks/gateguard`
licence is now verified MIT ("MIT License / Copyright (c) 2026 Hirokazu Seto / ZUNO WORKS K.K."),
verified by direct inspection of the upstream `LICENSE` (`SRD/edm/EDMV4__ecc-integration/decisions.md`
D13). It no longer belongs among the claims not verified.

### 8.3.1 Claims about EDM's users, demand, or reception -- none are supported

An earlier revision of this document asserted that EDM "is perceived as heavy", referred to its
"perceived cost of entry", and described an unbundled `/edm:code-audit` as "the lowest-risk
adoption path" for "a team that will never adopt the full methodology". **All of these were
inferences dressed as observations.** No usage data, telemetry, user interview, adoption metric
or complaint was consulted for this document, and none exists in the repository. They have been
removed or rewritten as explicitly conditional.

The distinction matters for how the recommendations should be read. Two different kinds of claim
appear in Parts 4-7:

- **Structural claims**, checkable against source: "EDM has no gate on the individual edit",
  "`update-patterns` writes to a read-only path", "no EDM lens covers type design", "the kernel
  has no technical dependency on the six-phase methodology". These are verifiable and were
  verified.
- **Value claims**, which depend on facts about users and workloads: how often EDM meets work
  below its design point, whether an unbundled audit would find users, how much Phase 1 explorer
  cost a codemap would recover. **None of these were established.**

Where an "Effort / Risk / Value" line gives a Value rating, treat it as the author's ranking of
the structural argument, not as a measured outcome. The cheapest way to convert several of them
into real numbers already exists inside EDM: `/edm:metrics --all` reports per-phase duration and
cost across every initiative, and `/edm:metrics --calibrate` prints measured medians.

### 8.4 Scope limits

Roughly 261 of ECC's 286 skills were not read. The large majority are domain-specific --
healthcare EMR/CDSS/HIPAA, logistics and customs, blockchain and DeFi, homelab networking,
scientific databases, marketing and investor materials, video production, trading agents. They sit
outside EDM's scope regardless of their quality, and sampling their names and descriptions was
sufficient to establish that.

No judgement is offered here on ECC's suitability as a plugin to *install*. This document assesses
it purely as a source of design ideas for EDM.
