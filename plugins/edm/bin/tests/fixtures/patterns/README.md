# Pattern-Harvest Fixture Set (EDMV4-T20)

Hand-authored audit-report fixtures for `edm-state update-patterns`'s source-side finding shapes,
documented in `plugins/edm/docs/audit-patterns/README.md` Sec."Append Schema" -> "Source-side
finding shape" and implemented by `pattern_extract_titles` in `plugins/edm/bin/edm-state`. These
exist so `wave8-smoke.sh`'s EDMV4-T20 section has committed inputs instead of heredoc'd fixture
content inline in the test file, matching the `code-audit/` and `hookify/` fixture directories'
own precedent.

Only `srd`, `qc` and `code` are represented: the `ticket` and `test-coverage` arms have no
machine-readable finding shape by design and must never be used to test a positive harvest
(`docs/audit-patterns/README.md:63-64`; this initiative's own Technical Notes for `EDMV4-T20`).

## Fixtures

- `srd-fixture.md` -- an `audit-srd.md`-shaped report with one novel `[CATEGORY] [SEVERITY]
  Section X.Y | finding | recommendation` line. Used to exercise the shipped-tree-writable
  fallback branch (b) end to end.
- `code-fixture.md` -- a `REMEDIATION.md`-shaped report with one `### CA-9001 (...)` finding
  heading. Used to exercise the writable-data-directory branch (a) end to end, and re-run against
  the same delta to prove delta-side de-duplication (the same finding is never appended twice).
- `qc-seed-duplicate.md` -- a `qc-summary.md`-shaped report whose one `**Finding**: ...` line's
  finding text is `PASS based on code structure, not behavior` -- the exact title of an existing
  `### ` entry already shipped in `docs/audit-patterns/qc-audit.md`'s Anti-Patterns section. Used
  to prove seed-side de-duplication: a title already present in the shipped seed is never
  re-appended to a separate delta, even though the delta itself starts empty.

## What this fixture set is not

- It does not cover `ticket` or `test-coverage` -- see above.
- It is not a copy of, or a substitute for, the shipped seed documents under
  `docs/audit-patterns/`; `qc-seed-duplicate.md`'s finding text is chosen to MATCH an existing
  seed title deliberately, as the point of that fixture, not by accident.

## Consumers

- `plugins/edm/bin/tests/wave8-smoke.sh`'s "EDMV4-T20" section reads these files directly as
  `update-patterns`'s source audit report for each of its three fixture-driven cases.
