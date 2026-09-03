# Code Audit Fixture: Contract Violation -- JSONL Present for a Lens Declared N/A (EDMV4-T23 AC4 / EDMV4-T32 AC4)

A **hand-authored, committed synthetic code-audit pass** representing the negative composition
`EDMV4-T23` AC4 guards against: the round record declares `L13` N/A (`lenses_na: ["L13"]`), but a
`lens-L13.jsonl` is present on disk anyway -- the agent produced output despite Step 1's
applicability determination saying it should not have. This is the disagreement-between-
determination-and-behaviour shape `agents/edm-test-integration.md:21-25` uses for the test layer.

## Contents

- `lens-L1.jsonl` .. `lens-L12.jsonl`, `lens-L14.jsonl` -- the same thirteen lens pairs as the
  sibling `na-l13-clean/` fixture, copied verbatim from the top-level fixture directory.
- `lens-L13.jsonl` / `lens-L13.md` -- the **stray** pair: copied verbatim from the top-level
  fixture directory's own `lens-L13.jsonl` / `lens-L13.md`, present here specifically because it
  must NOT be, given `lenses_na` declares `L13`.
- `lenses-run.txt` -- identical to `na-l13-clean/`'s: the manifest never lists L13 either way (an
  N/A lens is never added to the run-lens list), so the manifest alone cannot distinguish the
  clean case from this violation. The violation is visible only by cross-referencing the round
  record's `lenses_na` against the files actually on disk -- which is exactly what
  `EDMV4-T23` AC4 requires the backstop to do.
- `round-record.json` -- byte-identical to `na-l13-clean/`'s, captured from the same real
  `edm-state audit-round-start` invocation. The state is identical between the two fixtures; only
  the files on disk differ, which is what proves the backstop's third check inspects the
  filesystem rather than re-deriving its answer from the round record alone.

## What this fixture proves

`EDMV4-T23`'s completeness backstop must downgrade this round to `partial` and name `L13` as
having produced unexpected output, with a message distinguishable from the other two downgrade
reasons (missing JSONL for a run lens; incomplete coverage). `bin/tests/wave6-smoke.sh`'s
`EDMV4-T23 AC4` section loads `round-record.json` into a scratch `.edm-state.json` and runs
`audit-round-complete` against these files directly -- "tested against real files rather than a
synthesized path" per the assignment brief.

## Consumers

- `plugins/edm/bin/tests/wave6-smoke.sh` (`EDMV4-T23 AC4` section).

## What this fixture is not

- Not a captured output of a live `/edm:code-audit` round.
- Not wired into `run-eval.sh` or `score-artifacts.sh`.
