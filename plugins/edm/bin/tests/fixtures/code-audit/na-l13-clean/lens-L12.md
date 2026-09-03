## Findings (L12: Silent Failures)

| ID | Sev | File:Line | What Is Wrong | Concrete Fix |
|----|-----|-----------|---------------|--------------|
| L12-001 | P1 | src/api/fetch-user.js:22 | `.catch(() => [])` turns a network failure into a silently-empty result with no log line, so a downstream empty-state render is indistinguishable from "the user genuinely has zero records" | Log the caught error with context before returning the fallback, or propagate a distinct error/empty-vs-failed signal to the caller |

## Noted / Not Actionable

| ID | File:Line | Rationale |
|----|-----------|-----------|
| L12-002 | src/worker/retry.js:9 | Falling back to a cached snapshot on timeout is a documented, intentional degrade path with its own alerting elsewhere in the pipeline, not a silent failure |
