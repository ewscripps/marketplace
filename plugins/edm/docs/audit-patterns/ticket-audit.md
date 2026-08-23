# Ticket Pack Audit Patterns

**Source:** EDM seed corpus (16 real-world initiatives).
**Auto-updated** by the ticket audit phase's own skill (`skills/audit-tickets/SKILL.md`) via `edm-state update-patterns` after each round (EDMV2-80a; EDMV3-T37).

---

## Top Recurring Findings

Frequency: [x/16] = appeared in x of 16 audited initiatives.

| # | Pattern | Frequency | Typical severity |
|---|---------|-----------|-----------------|
| 1 | Vague ACs without test gates | 7/16 | P1 |
| 2 | Missing / misplaced SRD refs | 8/16 | P1 |
| 3 | Dependency DAG errors | 7/16 | P0-P1 |
| 4 | File:line references out of sync | 6/16 | P1 |
| 5 | Coverage gaps in high-risk areas | 6/16 | P1 |
| 6 | Oversized tickets (L/XL) | 5/16 | P1 |
| 7 | Stale role/feature references | 5/16 | P1 |
| 8 | Unverified code anchors in Target Components | 4/16 | P2 |

### 1. Vague ACs without test gates (7/16)
- AC says "implement X" or "refactor for clarity" -- not testable
- AC says "ensure Y works" without specifying the test command
- "Verify manually" or "code review will check" as verification

### 2. Missing / misplaced SRD refs (8/16)
- A requirement appears in the SRD but no ticket carries a `SRD Refs:` entry for it
- A ticket's `SRD Refs:` points to a non-existent requirement (placeholder left in)
- Coverage map in README not regenerated after SRD revisions

### 3. Dependency DAG errors (7/16)
- Ticket lists `Depends On: T01, T03` but the diagram shows `T01 -> T02 -> T03` (T02 omitted)
- Circular dependencies (rare but fatal)
- `Depends On` edge declared but not drawn in the critical-path Mermaid

### 4. File:line references out of sync (6/16)
- Ticket says "in `src/file.ts:42`" but actual code is at line 48 or moved to a different file
- Refactors move code; tickets don't get updated

### 5. Coverage gaps in high-risk areas (6/16)
- A ticket adds a security gate but has no AC asserting "non-admin denied with 403"
- A ticket changes auth logic but tests only cover the happy path

### 6. Oversized tickets (5/16)
- Single ticket covers 2-3 sub-features that should be separate (e.g., DB migration AND API endpoint in one ticket)

### 7. Stale role/feature references (5/16)
- A ticket written before a role was removed still says "viewer/editor-facing" or has a docblock mentioning the phantom role

### 8. Unverified code anchors (4/16)
- `Target Components` says "modify `server/utils/auth.ts:70-92`" but the function is at lines 50-80 or moved

---

## Anti-Patterns

### Ticket duplication disguised as separate work
Two tickets have nearly identical ACs; one is a near-rename of the other.
**Fix:** If tickets n and n+1 have >=70% AC text overlap, merge them.

### Open questions in Must tickets
A Must-Have ticket says "Phase 4 will define the exact API response shape."
**Fix:** Any "TBD" / "TODO" / "phase X" in a Must AC is a blocker -- resolve the TBD before the ticket is approved or move the ticket to a follow-up phase.

### Missing test-infrastructure stories
Pack has 22 implementation tickets but zero tickets for wiring in the CI lint job, a11y test harness, or new test framework.
**Fix:** If a ticket introduces a new check (lint guard, CI gate, test suite), the pack must include a "harness" ticket to wire it in.

### Circular test dependencies
T08 (unit test new feature) depends-on T07 (implementation). T07 has an AC that runs T08's test.
**Fix:** Test tickets depend-on their implementation ticket; implementation tickets never depend-on their test tickets.

### Inadequate AC edge-case coverage
A "validate input" ticket has ACs for valid and missing input but not for null / 0 / "" / false input.
**Fix:** AC template includes boundary/edge prompts: null, 0, max-int, empty string, empty array, duplicate.

### Literal semicolon inside the critical-path Mermaid diagram
A ticket title or dependency label in the README's critical-path diagram contains a raw `;` (e.g., a node labeled `T04[Retry; backoff]`). Mermaid reserves `;` as a lexer-level statement separator even inside label text, so the critical path -- the single diagram every reader checks first -- breaks or mis-renders.
**Fix:** Use the `#59;` entity code instead of a raw semicolon (see `CLAUDE.md Sec."Mermaid diagram conventions"`); flag any raw `;` found inside `[...]`, `(...)`, `{...}`, `|...|`, `"..."`, or after the `:` in a `sequenceDiagram` message.

---

## Pre-Flight Checklist

Run before submitting a ticket pack to audit:

- [ ] **Coverage map regenerated:** README has a table with one row per SRD requirement listing which ticket(s) implement it. Every SRD row has >=1 ticket; every ticket has >=1 `SRD Refs` entry.
- [ ] **DAG verified:** For each ticket's `Depends On` field, confirm the corresponding edge is drawn in the critical-path Mermaid. Run a topological sort mentally (or with a tool) -- no cycles.
- [ ] **File:line spot-check:** Randomly select 5 tickets; for each, verify 2-3 code anchors with `grep -n "symbol" path/to/file`. Lines off by >3 are a finding.
- [ ] **High-risk ACs amplified:** Any ticket adding or changing a security gate, permission boundary, or auth path MUST have >=2 ACs: one positive (role granted), one negative (non-admin denied / 403).
- [ ] **Test commands specified:** Every AC verification block includes a copy-pasteable test command (`vitest run`, `pytest`, `npm run test:unit`). No AC says "verify manually."
- [ ] **Ticket sizing distribution:** Count XS/S/M/L/XL. Healthy: ~40-50% S, ~30-40% M, ~10-20% XS, <=5% L, 0 XL. Heavy skew toward L/XL signals over-scoping.
- [ ] **Phantom-role hunt:** Grep entire pack for any mention of removed roles or deleted features. Each hit must be paired with a removal ticket or confirmed as intentional.
- [ ] **Mermaid semicolon scan:** Grep the critical-path diagram and every epic-file diagram for a raw `;` inside label/edge/message text; per `CLAUDE.md Sec."Mermaid diagram conventions"` it must be the `#59;` entity code instead.
- [ ] **Runtime-environment reality check:** any AC assuming a runtime environment the project does not have (staging deploy, live database, deployed container, browser harness) is reworked
  into something verifiable, or moved out of scope, before the ticket is approved -- see
  `CLAUDE.md Sec."Unverifiable acceptance criteria (D15)"`. Caught here, it costs a rewording;
  caught at Phase 6's `/edm:verify-runtime` instead, it costs a gate change-control cycle.

---

## What a Passing First Draft Looks Like

- **Coverage is bidirectional:** every SRD requirement -> >=1 ticket; every ticket -> >=1 SRD ref. The README coverage map shows "PASS" on all rows.
- **DAG is acyclic and complete:** the critical-path diagram includes every dependency declared in `Depends On` fields; no missing edges.
- **High-risk areas over-tested:** tickets that add gates/permissions have 2-3 ACs (success + denial + edge case), not just one.
- **All code anchors verified:** spot-checking 5+ tickets shows file:line references within +/-2 lines of actual source.
- **Test commands are executable:** every AC verification block has a command a developer can copy-paste and run immediately.
- **Sizing is reasonable:** most tickets are S or M; no XL unless explicitly decomposed.
