# EDM Audit Pattern Library

This living reference captures recurring audit findings across EDM initiatives. It is the primary input for writer-agent pre-emption guidance (EDMV2-81/82/83) and the pre-flight checklists embedded in each agent prompt.

## Living-Library Contract

Each document in this library contains exactly four subsection headings (in this order):

1. `## Top Recurring Findings` -- findings with observed frequency and corpus citations
2. `## Anti-Patterns` -- patterns that reliably produce findings
3. `## Pre-Flight Checklist` -- self-checks to run before submission
4. `## What a Passing [X] Looks Like` -- concrete example of a passing artifact

**Structure check** (run as a regression guard):
```bash
for doc in srd-audit ticket-audit code-audit test-coverage-audit qc-audit; do
  echo "=== $doc.md ===" && grep "^## " docs/audit-patterns/$doc.md
done
```
All four headings must be present in every document.

## Append Schema

When appending a new finding (via auto-update or `edm-state update-patterns`), place it under the appropriate subsection heading:

```markdown
### {Finding title} ({source-prefix}, {date}, {severity})

{One-paragraph description of the finding and how to prevent it.}
```

De-duplication: if the finding title (lowercased, whitespace-collapsed) already exists in the document, skip the append.

## Consumers

This library is loaded at write time by three agents (EDMV2-81/82/83):
- `edm-srd-writer` loads `srd-audit.md`
- `edm-ticket-writer` loads `ticket-audit.md`
- `edm-implementer` loads `qc-audit.md` + `code-audit.md`
- `skills/orchestrator` uses `edm-state update-patterns` after each audit phase (EDMV2-80a)

And by the planning template (EDMV2-84):
- `skills/orchestrator/SKILL.md` and `skills/plan/SKILL.md` planning.md template

## How This Library Works

- **Seed:** created from analysis of 16 real initiatives in the scripps-mcp/SRD corpus (June 2026). See `SOURCES.md` for the full list.
- **Auto-update:** after each audit phase, the orchestrator appends novel findings (EDMV2-80a).
- **Manual update:** `edm-state update-patterns <PREFIX> <audit-type>` to backfill on demand (EDMV2-80b).
- **Consumer:** writer agents load the relevant doc at write time so guidance improves without manual prompt edits.

## Documents

| File | Audit type | Last updated |
|------|-----------|--------------|
| [srd-audit.md](srd-audit.md) | SRD audit | EDMV2 seed (2026-06-08) |
| [ticket-audit.md](ticket-audit.md) | Ticket pack audit | EDMV2 seed (2026-06-08) |
| [code-audit.md](code-audit.md) | 11-lens code audit | EDMV2 seed (2026-06-08) |
| [test-coverage-audit.md](test-coverage-audit.md) | Test-coverage audit | EDMV2 seed (2026-06-08) |
| [qc-audit.md](qc-audit.md) | QC (AC) audit | EDMV2 seed (2026-06-08) |

## Cross-Cutting Patterns

Patterns that surface across all audit types, from 16 initiatives (600+ findings):

### 1. Specification incompleteness, not incorrectness (14/16 initiatives)
SRD says "handle retries" but doesn't say how many times, what backoff, or which errors. Ticket says "add validation" but doesn't specify the error code or message. Code implements one interpretation; auditor expects another.
**Prevention:** SRD should be fully specific; ticket ACs must prescribe exact error codes, messages, and thresholds.

### 2. Naming/terminology drift (12/16)
SRD calls it "channel", ticket calls it "stream", code calls it "lane." SRD says "beat type", code says `topic_type`.
**Prevention:** Sec.11 Glossary is mandatory; every use of a domain term matches the glossary term exactly.

### 3. Pre-existing debt surfaced by a new initiative (8/16)
An old function is suddenly called in a new code path and reveals stale behavior.
**Prevention:** code audits include a "standing debt" section; prioritize which must ship vs. can defer.

### 4. Migration/schema coordination gaps (7/16)
SRD says "migration 031" but a parallel initiative already took 031. Two SRDs reference the same file path and disagree on expected state.
**Prevention:** central migration/schema registry; SRD auditor scans for conflicts with other in-flight initiatives.

### 5. Stale references after iteration (8/16)
SRD v0.3 says "see migration 045" but that migration was removed in v0.4. A ticket says "add field X" but field X was already added by a merged PR.
**Prevention:** automated SRD consistency checks; find all `migration \d+` / requirement ID references and verify each is real and current.

## Severity Distribution (600+ findings across 16 initiatives)

| Severity | Share | Description |
|----------|-------|-------------|
| P0 (blocks shipping) | ~10% | Contradictions, security gaps, data-corrupting defaults |
| P1 (must fix before release) | ~30% | Ambiguities, missing ACs, incomplete coverage, stale refs |
| P2 (can defer) | ~60% | Cosmetic, docs, optimizations, pre-existing debt noted but deprioritized |

**Key insight:** Most P0s and P1s are preventable with a thorough pre-flight checklist before submission. The checklists in each doc are designed to catch ~80% of findings before they reach an auditor.
