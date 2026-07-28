# EDM Audit Pattern Library

This living reference captures recurring audit findings across EDM initiatives. It is the primary input for writer-agent pre-emption guidance (EDMV2-81/82/83) and the pre-flight checklists embedded in each agent prompt.

## Living-Library Contract

Each document in this library contains exactly four subsection headings (in this order):

1. `## Top Recurring Findings` -- findings with observed frequency and corpus citations
2. `## Anti-Patterns` -- patterns that reliably produce findings
3. `## Pre-Flight Checklist` -- self-checks to run before submission
4. `## What a Passing [X] Looks Like` -- concrete example of a passing artifact

The fourth heading's exact wording varies by document (`What a Passing First Draft Looks Like` in `srd-audit.md`/`ticket-audit.md`, `What a Passing QC Round Looks Like` in `qc-audit.md`, `What Passing Code Looks Like` in `code-audit.md`, `What Passing Test Coverage Looks Like` in `test-coverage-audit.md`) -- this variation is sanctioned, not accidental: headings 1-3 must match exactly; heading 4 must match the regex `^## What .*Looks Like$`.

**Insertion target** (EDMV3-76/77): new entries are inserted as `### ` entries under one of the four `##` headings above, chosen by a documented mapping from finding type; `## Anti-Patterns` is the default target absent a more specific mapping entry (self-consistent with where this initiative's own EDMV3-T42 entries live). Insertion never lands past the fourth section or at end-of-file. If the target heading is absent from a document, the insertion is skipped with a message -- it never falls back to appending at end-of-file.

**Structure check** (run as a regression guard):
```bash
for doc in srd-audit ticket-audit code-audit test-coverage-audit qc-audit; do
  echo "=== $doc.md ===" && grep "^## " docs/audit-patterns/$doc.md
done
```
All four headings must be present in every document, in contract order, with heading 4 matching the regex above.

**Exemptions** (named, not incidental): `README.md` is exempt -- it is the contract document itself, not a library document. `SOURCES.md` is exempt -- it is the provenance document (two `##` headings), neither four-heading-compliant nor exempted from this contract before EDMV3-79. Any third file appearing under `docs/audit-patterns/` without either the four contract headings or an explicit, named exemption entry here fails the automated check below.

CI runs the authoritative version of this check automatically -- see `.gitlab-ci.yml`'s `lint:pattern-library-contract` job (lint stage) and `bin/tests/wave7-smoke.sh`'s "EDMV3-T56" section (test stage). The snippet above is for a contributor's own local sanity check; it does not itself enforce the fourth-heading regex or the exemption list -- the automated checks do.

## Append Schema

When appending a new finding (via auto-update or `edm-state update-patterns`), place it under the appropriate subsection heading (see "Insertion target" above -- `## Anti-Patterns` by default):

```markdown
### {Finding title} ({source-prefix}, {date}, {severity})

status: pending-review
source: {source-prefix}
audit-type: {srd|ticket|qc|code}
date: {date}

> {One-paragraph description of the finding and how to prevent it -- delimited stub text pending
> human curation; not yet curated prose.}
```

De-duplication: if the finding title (lowercased, whitespace-collapsed, trailing-parens metadata stripped) already exists in the document, skip the append.

**Curation lifecycle** (EDMV3-77/78): every auto-appended entry carries `status: pending-review` on its own line, plus its provenance (`source`, `audit-type`, `date`). Pending entries are surfaced for human curation at the audit gates -- see "Curation at Gates" below. Removing the `status: pending-review` line marks an entry curated; curation is one-way -- nothing re-adds the marker, and de-duplication prevents the same title being re-appended. The pending count is always `grep -c 'status: pending-review' docs/audit-patterns/*.md` computed at read time -- there is no mirrored count in `.edm-state.json`.

## Curation at Gates

Pending entries (`status: pending-review`) are presented to a human at three existing HITL gates -- Gate 2 (`/edm:audit-srd`), Gate 3 (`/edm:audit-tickets`), and the code-audit Convergence gate -- alongside the findings review already happening there, never as a separate interaction round. For each pending entry the human is offered:

- **Keep** -- remove the `status: pending-review` marker; the entry is curated as-is.
- **Edit** -- prompt for the one-paragraph description, then remove the marker.
- **Discard** -- remove the entry from the pattern document entirely.

Declining to curate (or when nothing is pending) leaves the gate presentation unchanged and never blocks gate approval -- the entries simply remain pending for the next gate.

## Consumers

This library is loaded at write time by three agents (EDMV2-81/82/83):
- `edm-srd-writer` loads `srd-audit.md`
- `edm-ticket-writer` loads `ticket-audit.md`
- `edm-implementer` loads `qc-audit.md` + `code-audit.md`
- `skills/orchestrator` uses `edm-state update-patterns` after each audit phase (EDMV2-80a)

And by the planning template (EDMV2-84):
- `skills/orchestrator/SKILL.md` and `skills/plan/SKILL.md` planning.md template

## How This Library Works

- **Seed:** created from analysis of 16 real-world initiatives (600+ findings). See `SOURCES.md` for details.
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

Patterns that surface across all audit types, from 16 real-world initiatives (600+ findings):

### 1. Specification incompleteness, not incorrectness (14/16 initiatives)
SRD says "handle retries" but doesn't say how many times, what backoff, or which errors. Ticket says "add validation" but doesn't specify the error code or message. Code implements one interpretation; auditor expects another.
**Prevention:** SRD should be fully specific; ticket ACs must prescribe exact error codes, messages, and thresholds.

### 2. Naming/terminology drift (12/16)
SRD calls it "order", ticket calls it "purchase", code calls it "transaction." SRD says "item type", code says `product_type`.
**Prevention:** Sec.11 Glossary is mandatory; every use of a domain term matches the glossary term exactly.

### 3. Pre-existing debt surfaced by a new initiative (8/16)
An old function is suddenly called in a new code path and reveals stale behavior.
**Prevention:** code audits include a "standing debt" section; prioritize which must ship now vs. which is recorded as a follow-on.

### 4. Migration/schema coordination gaps (7/16)
SRD says "migration 012" but a parallel initiative already took 012. Two SRDs reference the same file path and disagree on expected state.
**Prevention:** central migration/schema registry; SRD auditor scans for conflicts with other in-flight initiatives.

### 5. Stale references after iteration (8/16)
SRD v0.3 says "see migration 015" but that migration was removed in v0.4. A ticket says "add field X" but field X was already added by a merged PR.
**Prevention:** automated SRD consistency checks; find all `migration \d+` / requirement ID references and verify each is real and current.

## Severity Distribution (600+ findings across 16 initiatives)

| Severity | Share | Description |
|----------|-------|-------------|
| P0 (blocks shipping) | ~10% | Contradictions, security gaps, data-corrupting defaults |
| P1 (must fix before release) | ~30% | Ambiguities, missing ACs, incomplete coverage, stale refs |
| P2 (remediate before convergence) | ~60% | Cosmetic, docs, optimizations, pre-existing debt noted but deprioritized |

**Key insight:** Most P0s and P1s are preventable with a thorough pre-flight checklist before submission. The checklists in each doc are designed to catch ~80% of findings before they reach an auditor.
