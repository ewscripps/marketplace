# Code Audit Fixture: Committed Synthetic Pass (EDMV3-T24 AC0)

This directory is a **hand-authored, committed synthetic code-audit pass** -- it is ground truth
written to exercise the lens JSONL contract (EDMV3-T24), the synthesizer's JSONL ledger (EDMV3-T25),
the convergence predicate (EDMV3-T28), and the eval scorer's dimension 5 (EDMV3-T23). It is **not**
a captured output of a live `/edm:code-audit` round against a real project.

## Why hand-authored, not captured

The only fixture driver in this initiative (EDMV3-T22, `plugins/edm/evals/run-eval.sh`) runs
`plan -> srd -> audit` and never invokes a code-audit round, so "run a fixture code-audit round and
commit its output" was not an expressible verification path for any ticket that needed one. Rather
than leave the JSONL/ledger/convergence contract unverified until some future round happens to
exercise it, this directory is written directly, by hand, to the exact shape the contract requires.
Because it is hand-authored rather than captured from a model run, it will not drift if a future
lens prompt or model version changes wording -- it is a fixed target the mechanism is checked
against, not a snapshot of current model behavior.

## Contents

- `lens-L1.jsonl` .. `lens-L14.jsonl` -- one JSON object per line per finding, per the schema in
  each lens agent's `## JSONL Line Format` section (`{"schema":1,"id":null,"lens":"L{N}",...}`).
  `lens-L1.jsonl` is the widest fixture: it carries all four severities (`P0`, `P1`, `P2` at
  `status: "open"`, plus `NOTED` at `status: "noted"`), one `status: "fixed"` line, and one legacy
  `status: "deferred"` line -- the one the re-open path (EDMV3-T25 AC4, EDMV3-T28 AC5) exercises.
  `lens-L2.jsonl` .. `lens-L14.jsonl` each carry two findings (one open, one `NOTED`) -- enough to
  prove the shape without repeating the full severity sweep in every file.
- `lens-L1.md` .. `lens-L14.md` -- the matching prose reports. Each finding in the JSONL has a
  corresponding row in the prose table, identified by a local `L{N}-NNN` ID in the same order as
  the JSONL lines -- this is what lets `score-artifacts.sh`'s dimension 5
  (`lens-jsonl-prose-agreement`) compute a real per-lens count comparison against this fixture
  instead of scoring null.
- `lenses-run.txt` -- the fourteen lens IDs, one per line, with the `Round type: full` header the
  synthesizer and `edm-state audit-round-start` both read.
- This `README.md`.

## What this fixture is not

- It is not a `findings-ledger.jsonl` or `findings-ledger.md` -- the synthesizer produces those by
  reading these lens files (EDMV3-T25); this directory is upstream of the synthesizer.
- It does not exercise `code-audit/pass-{N}_{YYYY-MM-DD}/REMEDIATION.md` -- that is also a
  synthesizer output, generated from this input.
- It is intentionally not wired into `run-eval.sh` (see "Why hand-authored, not captured" above).

## Consumers

- `plugins/edm/bin/tests/wave7-smoke.sh` (EDMV3-T24, EDMV3-T25, EDMV3-T42 sections) reads these
  files directly.
- `plugins/edm/evals/score-artifacts.sh plugins/edm/bin/tests/fixtures/code-audit/ --out "${TMPDIR:-/tmp}/edm-scores.json"`
  scores dimension 5 against the `lens-L*.jsonl` / `lens-L*.md` pairs here. The explicit `--out`
  is required (CA-151): this directory is a tracked, committed fixture, not a real run directory,
  and the scorer refuses to write `scores.json` into it without an explicit scratch destination
  -- point `--out` at a scratch path outside the plugin source tree, never back into this
  directory.
- EDMV3-T02's grant spot-check uses this directory as a known-good two-path-contract example.
