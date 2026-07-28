## Findings (L2: Dead Code & Unreachable Paths)

| ID | Sev | File:Line | What Is Wrong | Concrete Fix |
|----|-----|-----------|---------------|--------------|
| L2-001 | P1 | src/worker/queue.js:15 | Branch after an unconditional `return` in `dequeue()` can never execute | Delete the dead branch or move it before the `return` |

## Noted / Not Actionable

| ID | File:Line | Rationale |
|----|-----------|-----------|
| L2-002 | src/worker/processor.js:2 | Retry branch is reachable only under the staging config flag, documented in README |
