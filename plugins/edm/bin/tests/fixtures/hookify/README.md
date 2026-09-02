# Hookify Fixture Set (EDMV4-T42 AC10)

Hand-authored JSON fixtures for the hookify rule format defined in `plugins/edm/CLAUDE.md`'s
"Hookify rule format (canonical)" section. There is no evaluator yet -- `EDMV4-T43` builds the
`edm-hookify` consumer that reads a rule directory shaped like this one. This directory exists so
that ticket's smoke tests have committed inputs to run `eval` against instead of building fixture
JSON inline in the test file, and so this ticket's own smoke coverage can assert the schema
directly with `jq`.

## Valid rules (one per event, AC10)

- `warn-no-console-log.json` -- `event: file`, `action: warn`, stated explicitly as the canonical
  worked example CLAUDE.md quotes. Two AND'd conditions. **Note (wave-1 QC):** an earlier revision
  of this line claimed the implicit-default form was "demonstrated by omitting the key entirely in
  a malformed fixture below". No fixture omits `action` -- all eight carry it explicitly. The
  default-to-`warn` behaviour is a property of the FORMAT, specified in CLAUDE.md and consumed by
  `EDMV4-T43`; it is deliberately not exercised by a fixture here, and the false claim mattered
  because this README names T43 as the directory's consumer.
- `require-ticket-id-reference.json` -- `event: file`, demonstrates the `require-*` naming
  convention: a `.md` file edited without a ticket ID reference.
- `block-rm-rf-bash.json` -- `event: bash`, `action: block`. Demonstrates `regex_match` and the
  JSON-escaped backslash a `bash`-field pattern needs (`rm\\s+-rf` in the JSON source, `rm\s+-rf`
  as the regex `jq`'s `test()` actually evaluates).
- `warn-stop-placeholder.json` -- `event: stop`, empty `conditions` array. The `stop` event
  currently defines no matchable `field` values (CLAUDE.md's per-event field table), so the only
  valid `stop` rule shape today is one with no conditions at all, matching unconditionally.

## Malformed rules (one per AC9 shape)

- `malformed-invalid-json.json` -- a deliberately truncated JSON object (unterminated, no closing
  brace). Any `jq` parse of this file fails.
- `malformed-missing-key.json` -- valid JSON, but the required `message` key is absent.
- `malformed-unknown-operator.json` -- an operator (`matches`) outside the six supported operators
  (`regex_match`, `contains`, `equals`, `not_contains`, `starts_with`, `ends_with`).
- `malformed-out-of-event-field.json` -- `event: file` with a condition naming `command`, which
  belongs only to `event: bash` per the per-event field table.

## What this fixture set is not

- It does not exercise `enabled: false` skip semantics, the two-tier exit-code contract, or any
  `list`/`eval` subcommand behavior -- those are `EDMV4-T43`/`EDMV4-T44` concerns, and this
  directory predates the evaluator that would exercise them.
- It is not installed anywhere as a default rule set. `.claude/edm-hookify/` is a project-owned
  directory the plugin never populates (see CLAUDE.md's "Rule directory and discovery"
  subsection); this fixture set lives under `bin/tests/fixtures/` precisely so it is test-only
  and never mistaken for a shipped default.

## Consumers

- `plugins/edm/bin/tests/wave8-smoke.sh` (EDMV4-T42 section) reads these files directly to assert
  the schema, the AND semantics, the six-operator closure, the per-event field constraint, and the
  four malformed shapes.
- `EDMV4-T43`'s smoke tests are expected to reuse this same directory as `eval` input once the
  evaluator exists, rather than duplicating a second fixture set.
