# EDM eval harness

A headless, fixture-based regression harness for the EDM methodology's prompts (SRD EDMV3-25,
EDMV3-26; tickets EDMV3-T22, EDMV3-T23). It exists so a prompt change to `plan`, `srd`, or
`audit-srd` gets a before/after number instead of vibes.

This directory has three parts, built across two tickets:

| Piece | Owner ticket | What it does |
|---|---|---|
| `fixtures/tiny-svc/`, `initiative.txt`, `run-eval.sh` | EDMV3-T22 (this one) | A frozen, checked-in subject and a driver that runs plan -> srd -> audit-srd against it headlessly, producing `run.json` |
| `score-artifacts.sh`, `vague-ac-patterns.txt`, `baseline/` | EDMV3-T23 | A deterministic scorer that turns a run directory into `scores.json`, plus the wave-A committed baseline |

`run-eval.sh` and `score-artifacts.sh` are separate programs on purpose: the driver never
computes a score, and the scorer never launches `claude` or reads `ANTHROPIC_API_KEY`. Run them
back to back:

```bash
bash plugins/edm/evals/run-eval.sh
bash plugins/edm/evals/score-artifacts.sh plugins/edm/evals/runs/<the-run-that-just-completed>
```

## Running it

```bash
export ANTHROPIC_API_KEY=sk-...
bash plugins/edm/evals/run-eval.sh
```

This provisions a scratch clone of `fixtures/tiny-svc/` in a temp directory, initializes a
throwaway git repository inside it, and runs `claude -p` through EDM Phase 1 (`plan`) -> Phase 2
(`srd`) -> Phase 3 (`audit-srd`) against the frozen initiative in `initiative.txt`. Artifacts land
in `plugins/edm/evals/runs/<timestamp>_<git-sha>/`: `planning.md`, `srd.md`, `architecture.md`,
`audit-srd.md`, and `run.json` (the model, the plugin version, and the token and cost totals for
the run). The scratch clone is deleted on exit, including on failure -- nothing outside
`plugins/edm/evals/runs/` is ever left behind in the repository you ran this from.

### `--out DIR`

Writes the run directory under `DIR` instead of `plugins/edm/evals/runs/`. Useful for keeping a
run somewhere outside the plugin source tree (see "Where committed run artifacts live" below).

### `--provision-only`

```bash
bash plugins/edm/evals/run-eval.sh --provision-only
```

Provisions the scratch fixture tree, prints its path, and exits 0 -- no `claude` invocation, no
network call, no `ANTHROPIC_API_KEY` requirement. This is what proves the fixture is self-contained
(EDMV3-25): run it with the network disabled and confirm it still exits 0 and populates the
scratch tree.

- Linux: `unshare -rn bash plugins/edm/evals/run-eval.sh --provision-only`
- macOS (no `unshare`): poison the proxy environment instead --
  `http_proxy=http://127.0.0.1:1 https_proxy=http://127.0.0.1:1 no_proxy= bash plugins/edm/evals/run-eval.sh --provision-only`

## The `claude -p` invocation, fully specified

`run-eval.sh` runs `claude -p` once per phase with:

- **Model**: `opus` by default (override with `EDM_EVAL_MODEL`) -- an alias, not a dated snapshot,
  so this harness does not go stale as models rotate.
- **Permission posture**: `--permission-mode acceptEdits` so file edits are auto-accepted (no
  interactive prompt a headless run cannot answer), combined with a tight
  `--allowedTools`/`--disallowedTools` pair -- the union of what `skills/plan/SKILL.md`,
  `skills/srd/SKILL.md`, and `skills/audit-srd/SKILL.md` each declare in their own frontmatter,
  plus `Bash(jq *)` for the inline `jq` usage those skills document, minus `WebFetch`/`WebSearch`/
  `KillShell`/`BashOutput`. `--permission-mode bypassPermissions` is deliberately never used: it
  would ignore the allow-list entirely, which is exactly the containment property this harness
  needs.
- **Plugin directory**: `--plugin-dir <this checkout's plugins/edm>`, so the run always exercises
  the plugin version in the working tree, never a globally installed copy.
- **Timeout**: a per-phase wall-clock budget (`EDM_EVAL_PHASE_TIMEOUT_SECONDS`, default 900) plus a
  per-phase `--max-budget-usd` spend ceiling (`EDM_EVAL_MAX_BUDGET_USD`, default 2). A phase that
  exceeds either is killed (`SIGTERM` then `SIGKILL`) and the run is scored as incomplete -- see
  "Exit codes" below. The timeout is implemented in bash (`run_with_timeout` in `run-eval.sh`)
  rather than depending on GNU coreutils' `timeout`, which is absent by default on macOS.
- `--bare` is also set: it forces `ANTHROPIC_API_KEY` (or `apiKeyHelper`) as the only auth path, so
  the credential requirement below is enforced by the `claude` CLI itself, not only by this
  script's own pre-flight check.

## Credentials

`run-eval.sh` requires `ANTHROPIC_API_KEY` in the environment for a real run. Without it:

```bash
env -u ANTHROPIC_API_KEY bash plugins/edm/evals/run-eval.sh
# run-eval: ANTHROPIC_API_KEY is not set. ...
# exit=2
```

`--provision-only` is the exception -- it never needs the key.

## The gate problem, and how the driver handles it

Every phase skill ends with "present the gate per the PROTOCOL", and the PROTOCOL mandates
`AskUserQuestion` plus "STOP and WAIT" -- which `claude -p` cannot answer. Pre-seeding the next
phase's approval satisfies the *next* skill's precondition check but does nothing about the
*current* skill stopping at an unanswerable prompt, so a naive driver would hang or time out on
every phase. `run-eval.sh` does both halves:

1. Each phase invocation's prompt explicitly instructs the model to execute the phase body and
   stop **before** gate presentation -- no `AskUserQuestion`, no waiting for sign-off -- and to
   print a single `EVAL_PHASE_COMPLETE: <phase>` line instead.
2. Between invocations, the driver shell itself calls `edm-state approve-gate <PREFIX> <gate>` to
   pre-seed the next phase's precondition.

No eval-only environment marker is read anywhere in `bin/edm-state`, and no production check is
conditional on this harness running: `grep -rn 'EDM_EVAL\|IS_EVAL\|eval_mode' plugins/edm/bin/`
returns nothing.

## Containment

After the audit-srd phase completes, the driver checks `git status --porcelain` inside the
scratch tree and fails (`containment: VIOLATION`, exit 2) if anything shows up outside `SRD/` --
the only tree the three phases were ever expected to touch. A clean run prints
`containment: clean`. This is the containment check EDMV3-93 requires.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | The run reached the end of the audit-srd phase and containment is clean. **Not** a quality verdict -- run `score-artifacts.sh` separately for that. |
| 1 | Reserved for the scorer/CI comparison (`score-artifacts.sh` and its caller, EDMV3-T23/EDMV3-T39). `run-eval.sh` never emits this itself. |
| 2 | A usage or environment error: missing `ANTHROPIC_API_KEY`, a missing required binary, bad flags, a provisioning failure before any phase started, or a containment violation. |
| 4 | A partially completed run: at least one phase did not finish (timeout, non-zero exit, or a missing expected artifact), so the run never reached the final phase. `run.json` and a stub `scores.json` are written with `complete: false`, and CI refuses to compare that run against the baseline. |

## Lint policy

**Eval run artifacts are held to the same content rules as real artifacts.** A run that produces
non-ASCII text or malformed Mermaid inside `planning.md`, `srd.md`, `architecture.md`, or
`audit-srd.md` is a genuine signal about the prompts, not noise to filter out.

**Nothing lints them automatically, though.** `run-eval.sh` contains no reference to
`edm-lint-artifacts` -- it provisions, runs three phases, and checks containment, and that is all.
Neither does the `eval:nightly` CI job, which runs the driver, then the scorer, then
`bin/edm-compare-eval`. To lint a run, invoke it by hand:

```bash
bash plugins/edm/bin/edm-lint-artifacts --path plugins/edm/evals/runs/<run-dir>
```

The scorer's dimension 3 (Mermaid parse success, EDMV3-T23) does **not** consume lint output. It
runs its own `_scan_mermaid_blocks` over the four artifact files and scores a per-block OK/BAD
ratio -- see the header comment in `score-artifacts.sh` for why that implementation is separate
from the linter's mermaid-semicolon class rather than delegating to it.

Committed baseline run artifacts live outside the plugin source tree entirely (see below) and are
excluded from `edm-lint-artifacts --all` by location, not by an exemption rule.

## Where committed run artifacts live

The fixture and driver in this directory are checked into the plugin's source tree. Committed run
*output* -- the wave-A baseline captured by EDMV3-T23 -- is not: `evals/baseline/README.md`
records that location explicitly, because the initiative that ships this harness also removes
708KB of binaries from the shipped plugin directory (EDMV3-80) on the grounds that every installer
downloads them, and an unbounded set of committed run artifacts in `plugins/edm/evals/` would undo
that.

## Scoring a run (`score-artifacts.sh`, EDMV3-T23)

```bash
bash plugins/edm/evals/score-artifacts.sh <run-dir>
```

Reads the run directory `run-eval.sh` produced (or any directory shaped like one --
`planning.md`, `srd.md`, `architecture.md`, `audit-srd.md`, and optionally a `code-audit/`
round), and writes `<run-dir>/scores.json` (also printed to stdout). No model is in the
loop -- every dimension is computed by `grep`/`awk`/`jq` over the run's own files, so scoring
the same run directory twice produces byte-identical output. `score-artifacts.sh` never
calls `claude`, never reads `ANTHROPIC_API_KEY`, and never touches `bin/edm-state`.

**Exactly five dimensions**, in fixed order, each normalized to an integer 0-100 (higher is
better; dimension 2 is inverted at normalization time):

1. **requirement-id-coverage** -- every `{PREFIX}-NN` ID in `srd.md` is unique, sequential
   with no gaps, and appears in `audit-srd.md`'s discussion.
2. **ac-testability** -- ACs matching `vague-ac-patterns.txt` divided by total AC count,
   inverted (`100 * (1 - vague/total)`).
3. **mermaid-parse-success** -- every ` ```mermaid ` block parses (closing fence present, a
   recognized diagram-type keyword on its first content line) and contains no raw `;` in
   label text once known HTML entity escapes (`#59;`, `#35;`, `#quot;`, any `#NNN;`) are
   accounted for (the EDMV3-56 detection rule).
4. **coverage-map-bidirectionality** -- the ticket phase's own coverage map when the run
   reached it, falling back to `srd.md` <-> `audit-srd.md` ID bidirectionality (every
   declared ID is discussed, and nothing discussed is a fabricated ID) when it did not --
   true of every wave-A eval run today, since `run-eval.sh` stops after `audit-srd`.
5. **lens-jsonl-prose-agreement** -- per-lens finding counts, `lens-L{N}.md` versus
   `lens-L{N}.jsonl`, for a run that includes a code-audit round.

A dimension that cannot be computed for the given run (e.g. dimension 5 when the run never
ran a code-audit round) is emitted `score: null`, named in `dimensions_skipped` with a
one-line reason, and excluded from both the sum and the denominator. `total` is the
unweighted arithmetic mean of the dimensions that produced a number, divided by
`dimensions_scored` (read from the data, never assumed to be 5), rounded to one decimal
place. `scores.json` also records `scorer_version` and the ordered `dimension_names` list,
so a later comparison can detect a scorer change before treating two runs as comparable.
This is the exact expression `scores.json`'s own `total` field satisfies -- there is no
licence to adapt it (EDMV3-T23 AC3):

```bash
jq -e '. as $r | ([$r.dimensions[].score | select(. != null)] | add) as $sum
       | $r.dimensions_scored as $n | (($sum / $n * 10 | round) / 10) == $r.total' \
  <run-dir>/scores.json
```

**The scorer emits scores only.** It performs no baseline comparison of any kind and never
exits non-zero on a low (or entirely null) score -- exit 0 whenever a score was produced,
exit 2 only on a usage or environment error (missing `jq`, a missing run directory, a
missing `vague-ac-patterns.txt`). The pass/fail decision belongs to the CI job that consumes
`scores.json` (EDMV3-T39, srd.md EDMV3-52), not to this script.

### `--describe`

`bash plugins/edm/evals/score-artifacts.sh --describe` prints the five dimension
definitions above verbatim and exits 0. Useful for confirming the scorer's own
understanding of what it measures without running it against a run directory.

### `--compare <a.json> <b.json>`

`bash plugins/edm/evals/score-artifacts.sh --compare <a> <b>` is the one piece of
comparison logic in this file, kept deliberately separate from the default scoring mode
above (which never compares anything). It refuses (exit 1, naming the mismatch) when the
two files' `scorer_version` differ, or when their `dimensions_scored` differ -- comparing a
four-dimension run against a five-dimension run produces a delta with no meaning. When both
match, it prints a per-dimension and total delta. Wiring this into an automatic CI
comparison against `baseline/scores.json` is EDMV3-T39's job, not this ticket's.

### Cost and duration

One `run-eval.sh` run costs roughly $10-25 in Claude API spend at opus (measured 2026-07-27: plan $1.49, srd $5.42, audit-srd exceeds $6 -- it spawns the auditor subagents; three phases, each capped by
`EDM_EVAL_MAX_BUDGET_USD`, default $15 per phase) and takes 30-60 minutes wall-clock (measured 2026-07-27: the audit-srd phase alone ran 913s) depending
on model load, within the default 2700-second per-phase timeout. `score-artifacts.sh`
itself costs nothing -- it makes no network call. **"CI will catch it" is not a valid reason
to skip running this locally before a prompt change merges**: the eval job is `when: manual`
on merge requests and only automatic on a scheduled nightly run against the default branch
(see `plugins/edm/CLAUDE.md`'s CI table), so a prompt regression introduced and merged
between two nightly runs will not be caught by CI at all until the next scheduled run --
possibly after several more prompt changes have landed on top of it, at which point
isolating which change regressed the score is much harder than it would have been the day
it happened.

## What this fixture is (and isn't)

`fixtures/tiny-svc/` is a small, frozen, synthetic webhook relay with six known, countable gaps
(see `fixtures/tiny-svc/expected.json` and `fixtures/tiny-svc/README.md`). It requires no network
access, no external services, and no dependency on the marketplace repository's own content. The
fixture plus `expected.json` stays under 100KB.

`initiative.txt` is the frozen Phase 1 input. Its header records a `version:` line; both files
change together, and neither changes without a recorded version bump, because runs are compared
against each other and against the wave-A baseline.

This harness measures whether the *methodology's prompts* still produce a competent SRD against a
known subject. It does not measure the quality of any real initiative's SRD, and a green run here
is not a substitute for the SRD audit gate (Gate 2) on real work.

## Tiering matrix (`tiering-matrix.sh`, EDMV3-T48, D16)

`tiering-matrix.sh` applies D16's mechanical model/effort promotion rule to the fifteen contested
agents (the eleven code-audit lenses, `edm-audit-synthesizer`, `edm-srd-auditor`,
`edm-ticket-auditor`, `edm-qc-auditor`). Like `bin/edm-compare-eval`, it never invokes `claude`
itself -- it consumes a JSON manifest of already-captured per-agent, per-configuration finding
counts and cost, and applies the rule mechanically:

1. Evaluate candidate configurations cheapest-first (`tier_rank` ascending).
2. A configuration missing even one baseline P0 or P1 finding (checked by finding ID, not just
   count) is disqualified outright, regardless of its total-findings ratio.
3. A configuration that is not disqualified qualifies only if its total findings are >= 80% of
   the baseline's total findings.
4. The first (cheapest) qualifying configuration wins; if none qualify, the agent stays
   `opus`/`max`.

Run `bash plugins/edm/evals/tiering-matrix.sh --help` for the full manifest schema and
`bash plugins/edm/evals/tiering-matrix.sh --self-test` to verify the promotion rule end to end
against three synthetic agents (a qualifying config wins; a P0-missing config is rejected and the
next tier wins instead; an agent with no qualifying config is left unchanged).

**As of this ticket's landing, this script has not been run against real data.** Producing a real
manifest requires the wave-A eval baseline (`evals/baseline/scores.json`), which does not exist
yet (D23). See `SRD/edm/EDMV3__prompt-streamline/decisions.md` D26 for the exact command that
closes this gap once the baseline is captured.
