## Findings (L8: Security & Portability)

| ID | Sev | File:Line | What Is Wrong | Concrete Fix |
|----|-----|-----------|---------------|--------------|
| L8-001 | P0 | src/worker/queue.js:1 | The systemd unit for this consumer runs `User=root` with no `NoNewPrivileges` | Set `NoNewPrivileges=true` and drop to a dedicated non-root user |

## Noted / Not Actionable

| ID | File:Line | Rationale |
|----|-----------|-----------|
| L8-002 | config/settings.json:1 | Hardcoded path is identical across all deployment hosts by design (immutable infra) |
