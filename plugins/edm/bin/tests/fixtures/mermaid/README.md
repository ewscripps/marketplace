# Mermaid lint fixture corpus (EDMV3-T44)

Ground truth for `edm-lint-artifacts`'s Mermaid literal-semicolon class (EDMV3-T43, class
`mermaid-semicolon`). Proves the class fires on every kind of raw semicolon it is meant to
catch and produces zero false positives on every legal case it must leave alone.

## Layout

- `valid/*.md` -- each file must produce **zero** violations when linted
  (`edm-lint-artifacts --path plugins/edm/bin/tests/fixtures/mermaid/valid/` exits 0).
- `invalid/*.md` -- each file has exactly one expected violation, recorded as an
  `<!-- expected-line: N -->` HTML comment on line 1 of the file so the test reads ground
  truth from the fixture itself rather than from a parallel list that can drift.

## Floors

At least 10 files in `valid/` and at least 5 in `invalid/` (12 and 5 respectively as of this
writing) -- each side carries its own floor rather than a single combined count, because a
combined floor of 15 would be satisfiable by 15 valid fixtures and zero invalid ones, which
would prove the class never fires rather than that it fires correctly.

## Coverage

`valid/` covers: entity codes (`#59;`, `#quot;`, `#35;`), a statement-terminating semicolon,
`%%` comment lines containing semicolons, `classDef`/`style`/`linkStyle` directives, a clean
`sequenceDiagram`, a `flowchart` with quoted labels containing commas and parentheses, a
diagram inside a non-Mermaid fence, an indented non-Mermaid fence nested under a numbered
step, the block-form `edm-lint-ignore-start/end` escape valve around a genuine violation, the
single-line marker on a fence-open line, a multi-diagram file with prose (including a
semicolon) outside any fence, and a `classDiagram` relationship line to guard against the
sequence-message heuristic over-firing.

`invalid/` covers: a raw `;` inside `[...]`, inside `"..."`, inside an edge `|...|` label,
inside `{...}`, and inside a `sequenceDiagram` message after the `:`.

## Regression discipline

This corpus is also the regression suite for any future tightening of the span-detection
regexes in `edm-lint-artifacts`. If the detection logic changes, extend this corpus with the
new case rather than loosening an existing guard to make a test pass -- a false positive here
blocks a commit for every contributor (RK-10), so the bar for changing what counts as "legal"
is high.

## Running the corpus directly

```bash
bash plugins/edm/bin/edm-lint-artifacts --path plugins/edm/bin/tests/fixtures/mermaid/valid/
# expect: exit 0, "CLEAN"

bash plugins/edm/bin/edm-lint-artifacts --path plugins/edm/bin/tests/fixtures/mermaid/invalid/
# expect: exit 1, one "mermaid-semicolon" line per file at its recorded expected-line
```
