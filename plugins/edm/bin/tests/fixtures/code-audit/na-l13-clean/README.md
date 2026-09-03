# Code Audit Fixture: Clean 13-of-14 with L13 Declared N/A (EDMV4-T23 AC11 / EDMV4-T32 AC3)

A **hand-authored, committed synthetic code-audit pass** representing the composition
`EDMV4-T22` introduced: a full round where `L13` (Type Design) is genuinely inapplicable (an
untyped stack) and every other lens landed its authoritative JSONL. This composition did not
exist before `EDMV4-T22` materialized `lenses` and added `lenses_na` -- it is new in this
initiative, not a captured live run.

## Contents

- `lens-L1.jsonl` .. `lens-L12.jsonl`, `lens-L14.jsonl` -- thirteen lens pairs, copied verbatim
  (byte-identical) from the sibling top-level fixture directory's own `lens-L{N}.jsonl` /
  `lens-L{N}.md` files. **No `lens-L13.jsonl` or `lens-L13.md` exists here** -- L13's absence is
  the point of this fixture (`EDMV4-T24`/`EDMV4-T26`: on N/A, a lens writes nothing at all).
- `lenses-run.txt` -- the thirteen run lens IDs, one per line, under the `Round type: full` header
  plus the `Lenses N/A: L13` header line `EDMV4-T24` AC8 adds.
- `round-record.json` -- the exact round-record object `edm-state audit-round-start` writes for
  this composition, captured from a real invocation
  (`edm-state audit-round-start <PREFIX> code --lenses L1,...,L12,L14 --na-lenses L13`) rather than
  hand-guessed, per `EDMV4-T32`'s Technical Notes ("author them after `EDMV4-T22` lands so the
  shape is copied from real output rather than guessed").

## What this fixture proves

`EDMV4-T23`'s completeness backstop must read `lenses`/`lenses_na` from the round record (not
`lenses-run.txt`) and treat this composition as **fully backed** -- `round_type` stays `full` at
completion, with no completeness warning. `bin/tests/wave6-smoke.sh`'s `EDMV4-T23 AC11` section
loads `round-record.json` into a scratch `.edm-state.json` and runs `audit-round-complete` against
these files directly, exercising the real code path against real files on disk rather than a
synthesized in-memory path.

## Consumers

- `plugins/edm/bin/tests/wave6-smoke.sh` (`EDMV4-T23 AC11` section).

## What this fixture is not

- Not a captured output of a live `/edm:code-audit` round.
- Not wired into `run-eval.sh` or `score-artifacts.sh` -- it exists solely to exercise the
  completeness backstop's N/A handling.
