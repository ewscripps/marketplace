# QC Report: EDMV2-T13

**Ticket**: EDMV2-T13 — Unify the severity vocabulary across all audit agents
**Date**: 2026-06-08
**Verdict**: PASS

---

## AC Verification

**AC-1**: A single severity vocabulary is documented in exactly one canonical location.
- PASS: `CLAUDE.md §"Severity vocabulary"` added with P0/P1/P2/NOTED table and definitions.

**AC-2**: The chosen scale reconciles the two existing scales into one with backward-compat mapping.
- PASS: Backward-compat mapping (legacy P1→P0, P2→P1, P3→P2, NOTED→unchanged) documented in the canonical section.

**AC-3**: Every `agents/edm-audit-*.md` lens agent references the canonical scale.
- PASS: All 11 lens agents (L1–L11) now reference `CLAUDE.md §"Severity vocabulary"` in their Output Format section.

**AC-4**: `agents/edm-audit-synthesizer.md` references the canonical scale; its Severity Reference table matches canonical definitions.
- PASS: Synthesizer's Severity Reference updated to P0/P1/P2/NOTED with pointer to CLAUDE.md. All examples (G1/G2, rollout order, summary line) updated from P1/P2/P3 to P0/P1/P2.

**AC-5**: `edm-srd-auditor.md`, `edm-ticket-auditor.md`, `edm-qc-auditor.md`, and `edm-test-coverage-auditor.md` each reference the canonical scale.
- PASS: All four agents updated with pointer to `CLAUDE.md §"Severity vocabulary"`.

**AC-6**: No two distinct severity scales remain anywhere in `agents/`.
- PASS: `grep -rn "P3\b" agents/` returns no results. Only P0/P1/P2/NOTED in use.

**AC-7**: The NOTED concept is preserved in the unified scale.
- PASS: NOTED preserved as a disposition qualifier in the canonical table and in the synthesizer's Severity Reference.

**AC-8**: Backward compatibility documented so legacy reports remain interpretable.
- PASS: The backward-compat mapping in CLAUDE.md covers all legacy P1/P2/P3 reports.

---

## Files Modified

- `plugins/edm-ai-development-staging/CLAUDE.md` — added `## Severity vocabulary (canonical)` section
- `plugins/edm-ai-development-staging/agents/edm-audit-synthesizer.md` — updated to P0/P1/P2, added canonical reference
- `plugins/edm-ai-development-staging/agents/edm-audit-logic.md` — updated severity line, added canonical reference
- `plugins/edm-ai-development-staging/agents/edm-audit-spec.md` — added canonical reference
- `plugins/edm-ai-development-staging/agents/edm-audit-dead-code.md` — added canonical reference
- `plugins/edm-ai-development-staging/agents/edm-audit-edge-cases.md` — added canonical reference
- `plugins/edm-ai-development-staging/agents/edm-audit-test-quality.md` — added canonical reference
- `plugins/edm-ai-development-staging/agents/edm-audit-docs.md` — added canonical reference
- `plugins/edm-ai-development-staging/agents/edm-audit-consistency.md` — added canonical reference
- `plugins/edm-ai-development-staging/agents/edm-audit-runtime.md` — added canonical reference
- `plugins/edm-ai-development-staging/agents/edm-audit-dry.md` — added canonical reference
- `plugins/edm-ai-development-staging/agents/edm-audit-wiring.md` — added canonical reference
- `plugins/edm-ai-development-staging/agents/edm-audit-security.md` — added canonical reference
- `plugins/edm-ai-development-staging/agents/edm-srd-auditor.md` — added canonical reference
- `plugins/edm-ai-development-staging/agents/edm-ticket-auditor.md` — added canonical reference
- `plugins/edm-ai-development-staging/agents/edm-qc-auditor.md` — added canonical reference
- `plugins/edm-ai-development-staging/agents/edm-test-coverage-auditor.md` — added canonical reference
