## Findings (L5: Runtime Hygiene)

| ID | Sev | File:Line | What Is Wrong | Concrete Fix |
|----|-----|-----------|---------------|--------------|
| L5-001 | P2 | src/worker/queue.js:8 | The temp file this line creates is not covered by any `.gitignore` glob | Add the pattern to `.gitignore` |

## Noted / Not Actionable

| ID | File:Line | Rationale |
|----|-----------|-----------|
| L5-002 | src/api/server.js:1 | Log file is rotated externally by systemd's `logrotate` config, documented in the runbook |
