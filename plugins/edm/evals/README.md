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

**Retention (CA-066, G12, G54):** `run-eval.sh` prunes stale run directories under `DIR` (or
`plugins/edm/evals/runs/` when `--out` is not given) down to the 10 most recently created,
oldest first. Override the count with `EDM_EVAL_KEEP_RUNS`; a non-numeric value falls back to
the default of 10, and `0` is clamped to `1` with a warning on stderr (CA-443: `0` otherwise
selected every run-shaped directory *including the one the invocation had just written*, and the
cleanup trap deleted it, leaving a green result with no eval output at all). Pruning runs on **every**
exit path -- success, a partial run (exit 4), and an interrupted run (SIGINT/SIGTERM/SIGHUP) --
via the driver's cleanup/EXIT trap, not only on success (G54): a failed or killed run previously
accumulated its full run directory, raw `claude -p` payloads included, forever. The run directory
currently being investigated is always the newest by mtime, so with the effective floor of 1 it is
never eligible for pruning regardless of which exit path got there.

Only directories whose name matches the run-ID shape (`<timestamp>_<git-sha>`, e.g.
`20260101T000000Z_abc1234`) are ever counted or pruned (G12) -- a stray file or an unrelated
directory sitting in `DIR` is never touched and never consumes a protected slot in the
keep-window. **When you pass `--out` at a directory you chose, pruning is skipped by default**
(G12): `--out` only tells this driver where to write, it never grants permission to delete other
content that directory might hold, so pruning against a caller-supplied `--out` root requires an
explicit `EDM_EVAL_PRUNE_EXPLICIT_OUT=true` opt-in. The default `evals/runs/` root has no such
requirement, since nothing but this driver's own run directories can live there. This is a
disk-hygiene measure for the gitignored `runs/` directory, not a correctness requirement:
`evals/runs/` was never tracked by git, so nothing here affects what gets committed.

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
  `--allowedTools`/`--disallowedTools` pair. `run-eval.sh`'s own `CLAUDE_ALLOWED_TOOLS` /
  `CLAUDE_DISALLOWED_TOOLS` assignment (search the script for that name) is the single
  authoritative definition, with its own comment immediately above explaining every addition and
  subtraction from the three phase skills' declared allowed-tools (CA-316: this section
  previously hand-re-derived the string and, by the time it was checked, no longer matched --
  omitting the deliberate `AskUserQuestion` subtraction and undercounting the Bash prefix
  matchers). `--permission-mode bypassPermissions` is deliberately never used: it
  would ignore the allow-list entirely, which is exactly the containment property this harness
  needs.
- **Plugin directory**: `--plugin-dir <this checkout's plugins/edm>`, so the run always exercises
  the plugin version in the working tree, never a globally installed copy.
- **Timeout**: a per-phase wall-clock budget (`EDM_EVAL_PHASE_TIMEOUT_SECONDS`, default 2700) plus a
  per-phase `--max-budget-usd` spend ceiling (`EDM_EVAL_MAX_BUDGET_USD`, default 15). A phase that
  exceeds either is killed (`SIGTERM` then `SIGKILL`) and the run is scored as incomplete -- see
  "Exit codes" below. `EDM_EVAL_PHASE_TIMEOUT_SECONDS` is validated beside its default and a value
  that is not a positive whole number exits 2 rather than being used (CA-444: the polling
  comparison is numeric, and because this driver deliberately runs without `set -e`, a non-numeric
  value made every poll's test fail silently and disabled the phase timeout entirely, leaving the
  `claude -p` child unbounded). The timeout is implemented in bash (`run_with_timeout` in
  `run-eval.sh`) rather than depending on GNU coreutils' `timeout`, which is absent by default on
  macOS.
- `--bare` is deliberately **not** set: the driver uses `--no-session-persistence` for isolation,
  and it accepts either an exported `ANTHROPIC_API_KEY` or a `claude` CLI that is already logged
  in via subscription/OAuth auth.

## Credentials

`run-eval.sh` requires working Claude auth for a real run. Either export `ANTHROPIC_API_KEY`, or
run it from a machine where the `claude` CLI is already logged in. If neither auth path is
available, it exits 2 with:

```text
run-eval: no working Claude auth: ANTHROPIC_API_KEY is not set and the 'claude' CLI is not authenticated. Export ANTHROPIC_API_KEY or run 'claude' interactively to log in. Use --provision-only to exercise fixture provisioning without auth.
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
| 1 | Reserved for the scorer/comparison caller (`score-artifacts.sh` and `bin/edm-compare-eval`, EDMV3-T23/EDMV3-T39). `run-eval.sh` never emits this itself. |
| 2 | A usage or environment error: missing `ANTHROPIC_API_KEY`, a missing required binary, bad flags, an invalid `EDM_EVAL_PHASE_TIMEOUT_SECONDS` (CA-444), a provisioning failure before any phase started, or a containment violation. |
| 4 | A partially completed run: at least one phase did not finish (timeout, non-zero exit, or a missing expected artifact), so the run never reached the final phase. `run.json` and a stub `scores.json` are written with `complete: false`. Do not treat exit 4 as a reason to skip scoring/comparison (CA-452) -- run `score-artifacts.sh` then `bin/edm-compare-eval` anyway so the `complete: false` candidate is visibly refused by name, rather than silently discarded. |

## Lint policy

**Eval run artifacts are held to the same content rules as real artifacts.** A run that produces
non-ASCII text or malformed Mermaid inside `planning.md`, `srd.md`, `architecture.md`, or
`audit-srd.md` is a genuine signal about the prompts, not noise to filter out.

**Nothing lints them automatically, though.** `run-eval.sh` contains no reference to
`edm-lint-artifacts` -- it provisions, runs three phases, and checks containment, and that is all.
Neither does the scorer or `bin/edm-compare-eval`. To lint a run, invoke it by hand:

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

**Exactly six dimensions**, in fixed order, each normalized to an integer 0-100 (higher is
better; dimension 2 is inverted at normalization time). (T23 AC1 originally fixed the set at
five; CA-462 added the sixth with a `scorer_version` bump to 1.1.0, because all five originals
are self-consistency checks over the run's own output and none consulted the fixture's ground
truth -- an SRD surfacing zero of the six known gaps scored identically to one surfacing all six.)

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
6. **known-gap-recall** -- fraction of the tiny-svc fixture's six ground-truth gaps
   (`fixtures/tiny-svc/expected.json`, `srd_match` patterns) the produced `srd.md` engages.
   Skipped (`score: null`) for any run directory whose `run.json` does not carry
   `fixture: "tiny-svc"`, so the scorer stays usable against arbitrary directories.

A dimension that cannot be computed for the given run (e.g. dimension 5 when the run never
ran a code-audit round) is emitted `score: null`, named in `dimensions_skipped` with a
one-line reason, and excluded from both the sum and the denominator. `total` is the
unweighted arithmetic mean of the dimensions that produced a number, divided by
`dimensions_scored` (read from the data, never assumed to be 6), rounded to one decimal
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
missing `vague-ac-patterns.txt`). The pass/fail decision belongs to `bin/edm-compare-eval`,
the script that consumes `scores.json` (EDMV3-T39, srd.md EDMV3-52), not to this script.

### `--describe`

`bash plugins/edm/evals/score-artifacts.sh --describe` prints the six dimension
definitions above verbatim and exits 0. Useful for confirming the scorer's own
understanding of what it measures without running it against a run directory.

### `--compare <a.json> <b.json>`

`bash plugins/edm/evals/score-artifacts.sh --compare <a> <b>` is a thin delegation to
`bin/edm-compare-eval` (CA-383) -- it is not a second comparison implementation, kept
deliberately separate only from the default scoring mode above (which never compares
anything). It injects `complete: true` into temp copies of both inputs first (a hand-built
`scores.json` fixture may not carry that field, but `edm-compare-eval` refuses any candidate
whose `complete` field is not exactly `true` before it ever reaches the version/dimension
checks below), then delegates. The exit code and refusal wording are `edm-compare-eval`'s
own: refuses (exit 2, naming the mismatch) when the two files' `scorer_version` differ, or
when their `dimensions_scored` differ -- comparing a five-dimension run against a
six-dimension run produces a delta with no meaning. When both match, it prints a
per-dimension and total delta and exits 0 (or exit 1 on a threshold regression). Comparing a
run against `baseline/scores.json` is done by calling `bin/edm-compare-eval` directly rather
than via this flag.

### Cost and duration

One `run-eval.sh` run costs roughly $10-25 in Claude API spend at opus (measured 2026-07-27: plan $1.49, srd $5.42, audit-srd exceeds $6 -- it spawns the auditor subagents; three phases, each capped by
`EDM_EVAL_MAX_BUDGET_USD`, default $15 per phase) and takes 30-60 minutes wall-clock (measured 2026-07-27: the audit-srd phase alone ran 913s) depending
on model load, within the default 2700-second per-phase timeout. `score-artifacts.sh`
itself costs nothing -- it makes no network call. There is no automated schedule that runs
this for you: a prompt regression is only caught if a human runs `run-eval.sh` locally before
merging the change that introduced it. The longer that run is deferred, the more prompt
changes may land on top of it, making it progressively harder to isolate which change
regressed the score.

## What this fixture is (and isn't)

`fixtures/tiny-svc/` is a small, frozen, synthetic webhook relay with six known, countable gaps
(see `fixtures/tiny-svc/expected.json` and `fixtures/tiny-svc/README.md`). It requires no network
access, no external services, and no dependency on the marketplace repository's own content. The
fixture plus `expected.json` stays under 100KB. Note the scope difference (CA-463): EDMV3-T22 AC3
states that budget over the *fixture* tree specifically, not over all of `plugins/edm/evals/` --
the driver and scorer scripts included, untracked output under `runs/` excluded. Nothing enforces
this automatically; measure git-tracked bytes with `git ls-files -- plugins/edm/evals | xargs wc
-c | tail -1`, never `du`, which measures disk blocks rather than tracked bytes.

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
yet (D23). See `SRD/edm/EDMV3__prompt-streamline/decisions.md` D28 for the exact command that
closes this gap once the baseline is captured.
