# tiny-svc -- EDM eval fixture

This is a small, synthetic, frozen codebase. It exists only so
`plugins/edm/evals/run-eval.sh` has a stable, checked-in subject to run the
EDM methodology (plan -> srd -> audit) against without a human in the loop.

## What it is

A webhook relay service with two areas an explorer can map:

- `src/api/` -- an HTTP-facing layer that receives inbound webhooks and hands
  them to the worker.
- `src/worker/` -- a background job processor that forwards accepted
  webhooks to a downstream billing system.

`config/settings.json` holds service configuration.

## Why it looks unfinished

tiny-svc intentionally contains a fixed, countable set of gaps -- missing
authentication, a hardcoded secret, no retry/backoff, no input validation,
no logging, and no test suite. Those gaps are enumerated in `expected.json`
one directory up so the eval scorer (`score-artifacts.sh`, EDMV3-T23) has
ground truth to check a produced SRD against, rather than only a
self-consistency check.

**Do not "fix" the gaps in this fixture.** They are the point: a good
headless SRD run should surface most of them as requirements. If you need to
add coverage for a new class of gap, add it to both the source tree and
`expected.json` in the same change, and bump `plugins/edm/evals/initiative.txt`'s
version per that file's own header.

## Constraints

- No network access, no external services, no dependency on the marketplace
  repository's own content (EDMV3-25). The source below is read-only input
  for an explorer agent -- nothing here is ever executed by the eval driver.
- The fixture plus `expected.json` stays under the 100KB budget enforced by
  `edm-lint-artifacts`'s size check for `plugins/edm/evals/` (EDMV3-25 AC,
  EDMV3-80).
- ASCII only, same as every other artifact this initiative produces.
