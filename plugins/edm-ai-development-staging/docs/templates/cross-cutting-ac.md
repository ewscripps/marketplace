# Cross-Cutting Acceptance Criteria

Every ticket in the pack MUST include these acceptance criteria where applicable:

## Tests (apply to all tickets unless ticket is docs-only)

- [ ] At least one smoke test exercises the main code path
- [ ] Error/edge cases handled and tested
- [ ] Existing tests still pass after the change

## Documentation (apply when the ticket changes user-visible behavior or public API)

- [ ] CLAUDE.md or relevant docs updated if conventions change
- [ ] Public API changes documented with examples
- [ ] Changelog entry written if initiative has a CHANGELOG

## Logging and Observability (apply to tickets that add/change server-side behavior)

- [ ] Errors logged with structured data (correlation ID, context)
- [ ] New metrics/traces added if performance is critical
- [ ] Health check updated if new dependencies are introduced

## CI / Integration (apply to tickets that change the deployment surface)

- [ ] CI passes with the change
- [ ] No new linter warnings introduced
- [ ] Migrations are reversible and tested

## Source: `docs/templates/cross-cutting-ac.md`
## Authority: EDMV2-77 (WS-K) -- single source of truth; do not copy inline
