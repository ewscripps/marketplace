## Findings (L1: Logic, Correctness & Completeness)

| ID | Sev | File:Line | What Is Wrong | Concrete Fix |
|----|-----|-----------|---------------|--------------|
| L1-001 | P0 | src/api/routes.js:12 | `DELETE /users/:id` has no auth check before deleting -- any caller can delete any user | Add the same `requireAuth` middleware the sibling `PUT /users/:id` route already uses |
| L1-002 | P1 | src/worker/processor.js:20 | Batch loop uses `for (i = 0; i < items.length - 1; i++)`, dropping the last item every run | Change the bound to `i < items.length` |
| L1-003 | P2 | src/worker/queue.js:5 | Retry count of 3 is a bare literal with no comment on why 3 | Add a one-line comment stating the SLA basis for the value, or extract to a named constant |
| L1-005 | P1 | src/api/routes.js:30 | Fixed this round -- the stub handler flagged in a prior pass now returns real data | n/a (resolved) |
| L1-006 | P2 | src/worker/processor.js:40 | Legacy line carrying the pre-EDMV3 status token, retained here only so the re-open fixture (EDMV3-T25/T28) has a subject | Not this ticket's concern -- fixture-only |

## Noted / Not Actionable

| ID | File:Line | Rationale |
|----|-----------|-----------|
| L1-004 | src/api/server.js:8 | Hardcoded port 8080 is documented in README.md as intentional for local dev only |
