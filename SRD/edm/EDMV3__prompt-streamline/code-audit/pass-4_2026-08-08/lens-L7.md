# Lens L7: Cross-File Consistency -- Pass 4 (round 4, full)

Scope: `plugins/edm/` (bin/, bin/tests/, agents/, skills/, hooks/, docs/, evals/) plus
repository-root `.gitlab-ci.yml`. Cross-round ledger filtered to Status=open entries whose
Lens(es) include L7: CA-019, CA-049, CA-074, CA-156, CA-225, CA-226, CA-227, CA-228, CA-229,
CA-230, CA-231.

Headline: the "shared mechanism landed but consumers were never converted" class that has
recurred every round is, for the first time, genuinely closed on its two biggest instances --
CA-019 (`edm-mermaid-rules.awk`) and CA-156 (`project_class`). CA-049's zero-caller half is also
closed.

## Findings (L7: Cross-File Consistency)

| ID | File A | File B | What Differs | Fix |
|----|--------|--------|---------------|-----|
| L7-001 | `agents/edm-test-unit.md:103-105` | `agents/edm-test-planner.md:86-90`, CLAUDE.md | CA-228 residual: two of three N/A-enumerating sources now admit `integration`; edm-test-unit.md still lists five layers excluding integration, citing the planner as its source | Change edm-test-unit.md:104 to the six-layer set. |
| L7-002 | `.gitlab-ci.yml:246`,`:264` | `.gitlab-ci.yml:324`,`:441`,`:550` | CA-227 residual: success-path job-named OK line landed; failure-path FAILED line did not, for lint:file-type-ban, plus lint:bash-syntax:116 and lint:shellcheck:226 | Add job-named FAILED lines before each exit 1. |
| L7-003 | `.gitlab-ci.yml:138` | `.gitlab-ci.yml:118`,`:125` | NEW: the Wave-7 CA-019 entity-walk CI ban omits the bin/tests/ carve-out its two siblings carry, which is why CA-019 still has no smoke-suite positive control | Append `\| grep -v '/tests/'` at :138; add the positive-control assertion. |
| L7-004 | `bin/edm-check-grants:124` | `edm-lint-artifacts:141`, `edm-sync-canonical-sections:84`, `edm-state:622-625`,`:1115-1118`, `run-eval.sh:231`, `tiering-matrix.sh:147`, `_harness.sh:76`,`:104` | NEW: last EXIT-only cleanup trap in bin/+evals/; every sibling covers at least EXIT INT TERM. edm-state:604's exemplar citation also points at the wrong line (:121 not :124) | Change to `trap ... EXIT INT TERM`; fix the citation. |
| L7-005 | `bin/tests/wave3-smoke.sh:12` etc. | `bin/tests/wave4b-smoke.sh:9` etc. | CA-049 residual, narrowed: zero-caller half closed; two `_harness.sh` sourcing shapes and a `:-$0` fallback split survive | One mechanical sweep to the canonical form; update `_harness.sh:4`'s example. |
| L7-006 | `bin/tests/wave7-smoke.sh:303-325` | `bin/_edm-lint-lib.sh:4-5` | The CA-010 boundary assertion enumerates three consumers where the library header now says four (edm-state added); edm-state's no-local-redefinition half is unguarded | Add edm-state to the loop at :312. |
| L7-007 | `bin/edm-sync-canonical-sections:51` | `bin/edm-check-grants:72-76` etc. | CA-074 residual: named hybrid fixed, but the die() family is still four shapes across twelve scripts, untested; three evals drivers use two message-prefix conventions | Standardize the family and add one smoke assertion. |

## Noted / Not Actionable

- **CA-019 CLOSED** -- blocking consumer converted, private clone gone, CI ban exists, ignore-marker asymmetry now documented (score-artifacts.sh:98-108). Only the missing positive control remains (L7-003).
- **CA-156 CLOSED** -- `project_class` is the single filter; seven parsers reduced to one.
- **CA-049's zero-caller half CLOSED** -- `harness_scratch_dir` has three real callers; residual derivation shapes filed as L7-005.
- **CA-225 CLOSED** -- one sentinel-wrapped header in edm-check-vocabulary.
- **CA-226 CLOSED** -- all three evals drivers use identical source literal; test tightened.
- **CA-229 CLOSED** -- all five UserPromptExpansion hooks pass their own command name.
- **CA-230 CLOSED** -- all six test-writer agents render token-then-parenthetical consistently.
- **CA-231 CLOSED** -- header names four consumers and cites the correct variable.
- All eleven lens agent definitions compared field by field: byte-identical tools/model/effort/maxTurns/color; no drift (CA-080, CA-095 stay closed).
- Four scripts use `set -uo pipefail` instead of `set -euo pipefail`, each with an in-place rationale.
- All eleven `apk add` lines version-pinned and internally consistent per base image.
- `eval:nightly`'s missing `needs:` is intentional (sole job in last stage, never blocking).
- wave6's HUP trap (tracked-file cleanup) vs wave7/harness helpers (ephemeral scratch) -- documented divergence, criterion 1.
- Spot-checked CA-195 (L11-tagged) and CA-245 (L11-tagged) while reading siblings -- not re-filed here.
- **CA-130 reproduced a fifth consecutive round.** `Write` absent from delivered tool set; delivered agent definition lacked the `## JSONL Line Format` section present on disk.

## Meta

`Write` was absent from this lens's delivered runtime tool set despite the frontmatter grant
(ledger CA-130). Both `lens-L7.md` and `lens-L7.jsonl` were transcribed by the orchestrator.
