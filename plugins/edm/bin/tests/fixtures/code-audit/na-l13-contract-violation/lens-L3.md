## Findings (L3: Edge Cases & Concurrency)

| ID | Sev | File:Line | What Is Wrong | Concrete Fix |
|----|-----|-----------|---------------|--------------|
| L3-001 | P0 | src/api/routes.js:22 | `req.body.id` is read with no null check; a request missing the field crashes the process | Validate `req.body.id` and return 400 before use |
| L3-002 | P2 | src/worker/queue.js:30 | Boundary check uses `<=` where the max-size semantics call for `<` | Confirm the intended inclusive/exclusive boundary and align the comparison |

## Noted / Not Actionable

[none this round]
