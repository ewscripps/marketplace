# Ticket Size Legend

| Size | Duration | Story Points | Guidance |
|------|----------|-------------|---------|
| XS | < 1 day | 1 pt | Trivial change: single-file fix, config tweak, doc update |
| S | 1-3 days | 2-3 pt | Small feature: one component, 1-3 tests, clear path |
| M | 3-5 days | 5 pt | Medium feature: multiple components, integration work |
| L | 1-2 weeks | 8-13 pt | Large feature: cross-cutting, architectural impact |
| XL | > 2 weeks | -- | **DECOMPOSE** -- must be split before implementation |

## Rules

- No XL tickets may enter a wave. Decompose before starting Phase 6.
- L tickets require explicit justification of why decomposition would add overhead.
- Size is based on implementation effort, not complexity of the problem statement.
- When in doubt, size up (S -> M) rather than down.
