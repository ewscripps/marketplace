# SRD Audit Report (EDMV4-T20 fixture)

This is a hand-authored fixture matching the source-side finding shape `pattern_extract_titles`
recognizes for the `srd` audit type: `[CATEGORY] [SEVERITY] Section X.Y | finding | recommendation`.
It exists only to drive `plugins/edm/bin/tests/wave8-smoke.sh`'s EDMV4-T20 section and is never
read by anything else.

## Findings

[Specification Quality] [P2] Section 4.1 | EDMV4-T20 branch (b) positive-control finding for the shipped-tree-writable fallback | Add a deterministic regression test exercising the shipped-tree-writable branch with the data directory forced unresolvable.
