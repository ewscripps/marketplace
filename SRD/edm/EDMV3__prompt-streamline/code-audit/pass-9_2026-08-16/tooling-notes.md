# Tooling notes -- round 9 (pass-9_2026-08-16)

Per-lens delivery degradation recorded per skills/code-audit/SKILL.md step 8b (CA-388/CA-466).

All eleven lenses were repeatedly interrupted mid-run by the driving account's API spend limit
("individual spend limit" terminal error) and resumed from their own transcripts via SendMessage.
Each resume continued from the prior stopping point; no lens restarted from scratch and no lens
shipped a scope-truncation caveat -- every final report is complete over its mandate.

| Lens | Stall count (spend-limit interruptions before final delivery) | Truncation caveat |
|---|---|---|
| L1 | 1 | none |
| L2 | 2 | none |
| L3 | 1 | none |
| L4 | 1 | none |
| L5 | 1 | none |
| L6 | 1 | none |
| L7 | 1 | none |
| L8 | 3 | none |
| L9 | 2 | none |
| L10 | 2 | none |
| L11 | 2 | none |

CA-130 recurrence: every lens's delivered tool set lacked Write and Bash (stale-plugin-cache
class, NOTED, do-not-re-file). Consequences uniform across all eleven: reports returned inline
and persisted by the orchestrator (both halves, validated per step 8a), and Priority-1
remediation verification was performed by reading the tree at HEAD rather than executing
git log/diff over 833a06d..HEAD. The 2182/0 suite figure quoted in the lens briefs was
orchestrator-supplied and not independently executed by any lens.
