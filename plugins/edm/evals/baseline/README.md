# EDM eval baseline (EDMV3-T23)

## Status: pending the live baseline capture

This directory is the committed home for `baseline/scores.json` -- the number wave B's
prompt changes (WS7, `EDMV3-T39`) are measured against. **As of this ticket's landing,
`scores.json` does not exist yet.** It is not faked, stubbed, or backfilled with placeholder
numbers: `score-artifacts.sh` only ever scores a real run directory produced by
`run-eval.sh`, and `run-eval.sh` only ever produces a real run directory by calling
`claude -p` through one of its two sanctioned auth paths (D20; `epics/03-ci-and-fixture-eval.md`
AC8; `run-eval.sh:30-32,:309-327` -- the `ANTHROPIC_API_KEY` env row and the "Two sanctioned auth
paths" comment plus the actual gate, not the help-text and retention-block ranges a prior version
of this citation pointed at) -- an exported `ANTHROPIC_API_KEY`, or a `claude` CLI
that is already authenticated via subscription/OAuth login -- neither of which this
implementation pass holds. Committing a hand-written `scores.json` here would look
identical to a real baseline to every downstream consumer (the CI comparison job, a human
reading this file, `git blame`) while actually being fiction, which is worse than the file
being absent. Absent, at least, is honest and fails loudly.

Everything this ticket can build without spending live API budget is built and is exercised
against a synthetic, by-hand-constructed run directory shaped like real wave-A output
(`planning.md`, `srd.md`, `architecture.md`, `audit-srd.md`) -- see the eval scorer's own
test evidence in the EDMV3-T23 implementation record. What remains is exactly the three
real runs this document describes below.

## Exact command to capture it

Run this from the repository root, with working Claude auth in place -- either export a real
`ANTHROPIC_API_KEY` or use a machine where the `claude` CLI is already logged in
(subscription/OAuth) -- three times in a row (fresh scratch tree each run -- `run-eval.sh`
provisions and tears down its own):

```bash
# Auth path 1: an exported API key.
export ANTHROPIC_API_KEY=sk-...
# Auth path 2 (alternative to the export above): skip it and rely on an already-authenticated
# `claude` CLI session instead -- run `claude` interactively once to log in if needed.
for i in 1 2 3; do
  bash plugins/edm/evals/run-eval.sh --out /path/outside/plugins/edm/eval-baseline-runs
done
```

Then, for each of the three run directories `run-eval.sh` printed:

```bash
bash plugins/edm/evals/score-artifacts.sh /path/outside/plugins/edm/eval-baseline-runs/<run-id>
```

Confirm all three runs have `complete: true` and `dimensions_scored: 4` (dimension 5 is
`null` for every one of them -- see "Why four dimensions" below) before using any of them as
the committed baseline. Copy the middle-scoring run's `scores.json` (by `total`) to
`plugins/edm/evals/baseline/scores.json` and commit it alongside this README once the
`max - min` figures below are filled in from the actual three runs.

## Why four dimensions, not five

The wave-A eval driver (`run-eval.sh`, `EDMV3-T22`) runs `plan -> srd -> audit-srd` and never
a code-audit round. Dimension 5 (lens JSONL-versus-prose agreement) has no input without a
code-audit round, so it is emitted with `score: null` and named in `dimensions_skipped` with
its reason on every wave-A run. `scores.json` for this baseline therefore records
`dimensions_scored: 4` and a `dimensions_skipped` array of length 1 (dimension 5 only). This
is a **four-dimension baseline**, deliberately: the first run that includes a code-audit
round establishes its own five-dimension baseline rather than being compared against this
one (`score-artifacts.sh --compare` refuses any comparison where `dimensions_scored` differs
between the two files being compared, precisely so a 4-dimension and a 5-dimension run are
never silently treated as comparable).

## Variance: `max - min` across the three runs

`EDMV3-28` requires at least three baseline runs, with the tolerance recorded as a single
`max - min` figure for the total, plus the same figure per dimension. Three runs is too few
for a meaningful standard deviation, which is why the simpler range statistic is used
instead. **These figures are populated from the three real runs described above and are not
yet known**:

| Statistic | Value |
|---|---|
| Total: `max - min` across the 3 runs | PENDING (populate from the 3 live runs) |
| Dimension 1 (requirement-id-coverage): `max - min` | PENDING |
| Dimension 2 (ac-testability): `max - min` | PENDING |
| Dimension 3 (mermaid-parse-success): `max - min` | PENDING |
| Dimension 4 (coverage-map-bidirectionality): `max - min` | PENDING |
| Dimension 5 (lens-jsonl-prose-agreement): `max - min` | N/A -- null on every wave-A run |

Once known, this table (and the machine-readable field noted below) become the tolerance
band the CI comparison job (`EDMV3-T39`) uses to decide whether a later run's total is a
genuine regression or ordinary run-to-run noise.

`EDMV3-T39`'s comparison job is the consumer of this figure and reads it as a
machine-readable field on the committed `scores.json` (not by parsing this markdown table).
When the baseline is captured, add a `variance` object to `baseline/scores.json` itself,
e.g.:

```json
"variance": {
  "total_max_minus_min": 0.0,
  "per_dimension_max_minus_min": {
    "requirement-id-coverage": 0,
    "ac-testability": 0,
    "mermaid-parse-success": 0,
    "coverage-map-bidirectionality": 0
  }
}
```

## What this number is, and what it is not

This is a **tripwire**, not a quality score. Five mechanical dimensions are proxies for
"the methodology's prompts still produce a competent SRD against a known subject" -- they
are not a substitute for a human reading the run's actual `srd.md`. A prompt refactor can
score identically on all four (or five) dimensions and still produce a worse SRD in ways
none of these dimensions happen to measure (weaker rationale in a Description field, a
Target Components list that quietly drops a file, prose that technically satisfies every
regex while saying less). Treat a red tripwire as "investigate before merging"; treat a
green tripwire as "no regression on the axes this scorer checks," never as "the SRD is
good."

**Re-versioning the scorer invalidates the baseline and requires re-capture.** If
`score-artifacts.sh`'s `scorer_version` changes for any reason -- a new dimension, a changed
normalization, a bug fix that changes a dimension's score for the same input -- this
baseline's `scores.json` was produced by a different program and is no longer a valid
comparison target. `score-artifacts.sh --compare` enforces this mechanically (it refuses any
comparison across a `scorer_version` mismatch), but the baseline itself must also be
re-captured against the new scorer version before wave B's comparison job has anything
meaningful to compare against.

## Where committed run artifacts live

The scores (`scores.json`) are committed inside this directory
(`plugins/edm/evals/baseline/scores.json`), inside the plugin's source tree, because they
are small (a few hundred bytes of JSON) and CI needs to read them without an external
fetch. The full **run artifacts** the three baseline runs produce (`planning.md`, `srd.md`,
`architecture.md`, `audit-srd.md`, `run.json` -- potentially tens of kilobytes per run) live
outside plugins/edm, at a location recorded here once the runs are captured (the
`--out` flag above is exactly how `run-eval.sh` is pointed somewhere other than
`plugins/edm/evals/runs/`): a sibling directory such as
`<repository-root>/.eval-baselines/EDMV3/` is the intended location, tracked outside the
shipped plugin directory. This keeps faith with `EDMV3-80`: the same initiative that ships
this harness removes 708KB of binaries from the shipped plugin directory on the grounds that
every installer downloads it, and an unbounded set of committed run artifacts inside
`plugins/edm/evals/` would undo that. `evals/runs/.gitignore` already excludes ad hoc local
runs from `plugins/edm/evals/runs/` for the same reason -- the baseline runs are additionally
kept out of the plugin source tree entirely, not merely gitignored inside it.

## Cost note

See `plugins/edm/evals/README.md` ("Cost and duration") for the approximate per-run cost and
duration; capturing this baseline costs three runs of that figure. That cost is the reason
this ticket does not spend it on the implementer's own credential -- it is a decision for
whoever owns the `ANTHROPIC_API_KEY` used for wave-A exit, made once, deliberately, not
spent silently by an agent verifying its own ticket.
