# QC Summary (EDMV4-T20 fixture)

Hand-authored fixture matching `agents/edm-qc-auditor.md` Sec."Output Format"'s labelled
`**Finding**: ...` finding-line shape. Its finding text is deliberately the exact title of an
existing `### ` entry already shipped in `docs/audit-patterns/qc-audit.md`'s Anti-Patterns
section (`### PASS based on code structure, not behavior`), so that this fixture drives
`wave8-smoke.sh`'s EDMV4-T20 seed-side de-duplication case: a fresh, empty delta must still skip
appending a title that already exists in the shipped seed.

**Finding**: [P2] EDMV4T20-T04 | bin/foo.sh:44 | PASS based on code structure, not behavior
