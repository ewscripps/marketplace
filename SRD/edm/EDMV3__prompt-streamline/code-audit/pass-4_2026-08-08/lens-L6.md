# Lens L6 -- Documentation Accuracy (Round 4, full round)

Scope audited: `plugins/edm/` in full (bin/ help text and comments, agents/, skills/, docs/,
evals/, hooks/, CLAUDE.md, CHANGELOG.md), plus repository-root `CLAUDE.md` and `.gitlab-ci.yml`
comments. Cross-round ledger entries filtered to Lens(es) containing L6 with Status `open`:
CA-017, CA-166, CA-168, CA-187, CA-218, CA-219, CA-220, CA-221, CA-222, CA-223, CA-224 (11
entries). All eleven re-verified against current code.

## Cross-round ledger re-verification (11 open L6 entries)

| Ledger ID | Verdict | Evidence |
|---|---|---|
| CA-017 (P2, L1+L6) | **FIXED** | `bin/edm-lint-artifacts:24-39` now enumerates seven classes including `unreadable`. `plugins/edm/CLAUDE.md:759`'s bin/ row no longer states a count. |
| CA-166 (P2, L6+L11) | **FIXED** | `skills/code-audit/SKILL.md:136-137` corrects the closure block; `CLAUDE.md:863` attributes `.md` to `edm-state render-ledger` and `.jsonl` to `edm-audit-synthesizer`; both artifact-layout blocks list `.jsonl` first as authoritative. |
| CA-168 (P2, L6+L11) | **PARTIALLY FIXED -- residual raised as L6-001** | Write-orphan half and library index CLOSED. NOT fixed: producer attribution in the doc header itself. |
| CA-187 (P1, L1+L6) | **FIXED** | `bin/edm-lint-artifacts:42-47` now reads the correct direction, matching `hooks/hooks.json:86`. |
| CA-218 (P2, L6+L11) | **FIXED** | `docs/audit-patterns/README.md:73-76` replaced line citations with by-name step form; all four step labels resolve. |
| CA-219 (P2, L6) | **FIXED** | `evals/README.md:302` now correctly references D28. |
| CA-220 (P2, L6) | **FIXED at the named site -- mirror site raised as L6-002** | `.gitlab-ci.yml:56-60` corrected to "ten consumers total", verified. |
| CA-221 (P2, L6) | **FIXED** | Root `CLAUDE.md:59-65` now matches marketplace.json on all seven plugins. |
| CA-222 (P2, L6) | **FIXED** | Root `CLAUDE.md:19-33` shows both agent layouts and states validate:manifest's edm-specific glob. |
| CA-223 (P2, L6) | **FIXED** | `bin/_edm-cli-lib.sh:9-12` now states the bin/tests/ exemption accurately. |
| CA-224 (P2, L6) | **FIXED** | `plugins/edm/CLAUDE.md:665` names both actors explicitly in both directions. |

## Findings (L6: Documentation Accuracy)

| ID | File:Line | Doc Says | Code Does | Fix |
|----|-----------|----------|-----------|-----|
| L6-001 | `docs/audit-patterns/test-coverage-audit.md:4` (and 4 siblings) | Each opens with "Auto-updated by orchestrator after each audit round" | The orchestrator does not update the pattern library; the producer is each phase's own skill (EDMV3-T37). `docs/audit-patterns/README.md:71-72` states the opposite explicitly. | Change all five headers to attribute the phase skill, not the orchestrator. |
| L6-002 | `plugins/edm/CLAUDE.md:984` | "single `.alpine_edm` anchor ... across all seven jobs" | The anchor is consumed by ten jobs (seven lint + test:smoke + test:state-validate + validate:manifest). `.gitlab-ci.yml:56-60` was corrected to "ten"; CLAUDE.md's copy was not. | Update CLAUDE.md to say ten consumers, matching `.gitlab-ci.yml`. |
| L6-003 | `plugins/edm/CLAUDE.md:966` | `lint:shellcheck` row: "every file directly in bin/" | Job loops over `bin/*`, `bin/tests/*.sh`, `evals/*.sh` (CA-162 widened this in round 3). | Update the row to name all three globs. |
| L6-004 | `plugins/edm/CLAUDE.md:961` | `lint:bash-syntax` row: "every file in bin/ (incl. bin/tests/*.sh)" | Also covers `evals/*.sh` and enforces three additional CI bans not mentioned in the table. | Extend the row or add a pointer to the authoritative job block. |
| L6-005 | `plugins/edm/bin/edm-state:604` | Cites `edm-check-grants:121` as a correct trap-form exemplar | `:121` is the jq dependency check; the trap is at `:124`. | Fix citation to `:124`. |
| L6-006 | `plugins/edm/bin/edm-state:3867` | Cites `skills/implement/SKILL.md:98` as a single-write caller | `:98` is a QC-shard merge pseudo-code line; the actual call is at `:117`. | Fix citation to `:117`. |
| L6-007 | `plugins/edm/evals/baseline/README.md:11` | Cites `run-eval.sh:24-27,:37-39,:181-183` as the two-sanctioned-auth-paths evidence | None of the three ranges is the auth gate (help text / retention doc / retention rationale). Real auth contract is at `:30-32` and `:285-301`. | Re-point citations to `:30-32` and `:285-301`. |

## Noted / Not Actionable

1. `.gitlab-ci.yml:22-23`'s "every blocking job installs bash/jq/git/shellcheck" is an approximation
   naming the package set, not a per-job claim; the operative pinning claim beside it is exact.
2. `agents/edm-audit-security.md:94`, `edm-audit-runtime.md:87` -- stale citations sit inside a
   fenced template Output Format sample alongside an obviously fictional sibling row; template
   illustration, not a factual claim.
3. `bin/_edm-cli-lib.sh:12-14` -- the CI ban scope claim is a policy statement, not a claim about
   grep's reach beyond bin/ and evals/.
4. Model/effort claims for all 14 skills re-verified exactly matching frontmatter.
5. "40 subcommands" claim and update-patterns' five-value enum re-verified exactly matching code.
6. **CA-130 reproduces a fifth consecutive round.** `Write` present in frontmatter but absent from
   delivered runtime tool set.

## Wave-7 remediation spot-checks that came back clean

- attribution_mode enum fix (CA-185 doc side) -- doc and code agree in all four places.
- Per-file token cap comment (CA-207) -- corrected comment matches the loop.
- `EDM_TOKEN_READ_LINE_CAP` zero-value refusal -- die message matches regex and anomaly.
- hooks.json fail-open fix (CA-186) and its documentation -- all three behaviours described accurately.
- `decisions.md` Wave-7 records -- D19, D36, D37 present and accurate.
- `pattern_target_heading_for` docstring -- names all five audit types correctly.

## Meta

`Write` was absent from this lens's delivered runtime tool set despite the frontmatter grant
(ledger CA-130 -- fifth consecutive round). Both `lens-L6.md` and `lens-L6.jsonl` were
transcribed by the orchestrator from the agent's returned text.
