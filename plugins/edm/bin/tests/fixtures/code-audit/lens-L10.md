## Findings (L10: DRY & Redundancy)

| ID | Type | File A | File B | Canonical | Recommendation |
|----|---|---|---|---|---|
| L10-001 | Duplicate retry-backoff logic | src/worker/queue.js:12 | src/worker/processor.js:18 | src/worker/queue.js | Extract to a shared helper, redirect processor.js to call it |

## Noted / Not Actionable

| ID | File:Line | Rationale |
|----|-----------|-----------|
| L10-002 | src/api/routes.js:1 | Duplication is intentional here to avoid a circular import between the two modules |
