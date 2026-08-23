# Lens L9 -- Spec & Ticket Compliance (pass 4, round 4)

Initiative: EDMV3 -- prompt-streamline
Inputs read in full: `srd.md` (targeted sections), `tickets/README.md`, all eleven
`tickets/epics/*.md`, `decisions.md` (D1-D37 + Finding-to-Commit Ledger), `architecture.md`,
`code-audit/findings-ledger.md`, `code-audit/pass-3_2026-08-08/REMEDIATION.md` (Wave 7 sequencing).

## Part 1 -- Cross-round ledger: every open L9-tagged entry, verified

Thirteen entries carry L9 with status `open`, all the Wave 7f batch.

| ID | Sev | Verdict | Evidence |
|---|---|---|---|
| CA-089 | P2 | **LANDED** (3/3 residues) + 1 new site | `architecture.md:646-652`,`:877`; `epics/05:653-665`,`:693-697`; `edm-check-skill-sync:3-9` retitled |
| CA-163 | P2 | **LANDED** | `decisions.md:45` (D36) names T23 AC13 |
| CA-190 | P1 | **LANDED, residue** | `epics/05:374-400` rewritten to per-phase contract. Residue: no decisions.md record |
| CA-191 | P1 | **LANDED, residue** | `epics/05:637-647` amended. Residue: AC claims a decisions.md record that doesn't exist |
| CA-192 | P1 | **LANDED, residue** | `epics/05:670-680` walked back. Residue: AC claims a decisions.md record that doesn't exist |
| CA-236 | P2 | **LANDED** | `srd.md:2846-2864` reconciled |
| CA-237 | P2 | **LANDED** | `epics/05:539-543` bin/tests carve-out |
| CA-238 | P2 | **LANDED** (documented) | `epics/05:156-172` records fragility honestly |
| CA-239 | P2 | **LANDED** | `epics/05:504-507` case-insensitive |
| CA-240 | P2 | **LANDED** | `CHANGELOG.md:292-298` placeholder replaced |
| CA-241 | P2 | **LANDED** | `epics/03:569-581` relabelled |
| CA-242 | P2 | **HALF LANDED** | `CLAUDE.md:757-767` lists all nine scripts. Residue: no AC covers the script list |
| CA-243 | P2 | **LANDED** | `decisions.md:46` (D37), `CHANGELOG.md:487-508` |

**Score: 13 targeted, 9 fully closed, 4 closed-with-residue (CA-190, CA-191, CA-192, CA-242), plus
one new site on CA-089.**

### D19's six amended ACs re-verified -- no regression.

### Requirement-wiring spot checks -- all pass, no new missing implementations.

## Findings (L9: Spec & Ticket Compliance)

### Missing Implementations (P1)

None found this round.

### Partial Implementations (P1)

| Ticket | AC | Requires | Code Does | File:Line |
|---|---|---|---|---|
| EDMV3-T66 / T43 | AC4, AC12 | verify greps CLAUDE.md for literal "four violation classes" | String absent -- Wave 7c's G9/G19 rewrote CLAUDE.md:762 to point at `--help`, and `wave7-smoke.sh:5475` now asserts the phrase's absence. Two Must-Have ACs permanently unpassable while a green suite asserts their inverse; no decisions.md record. Same class as CA-033, reopened by this round's own remediation. | Spec: `epics/11:662`, `epics/06:402-404`. Code: `CLAUDE.md:762`; `wave7-smoke.sh:5475-5478`,`:2228-2234` |
| EDMV3-T39 | AC5, AC9 | both ACs assert their rework is "recorded in decisions.md" | Record does not exist -- zero hits for "stop-before-gate"/"STOP and WAIT"/"re-verif" in decisions.md; D23 still enumerates only AC2/3/4/7; D37 names T39 only for the CHANGELOG bullet. Affirmatively false cross-reference inside an AC. | Spec: `epics/05:645`,`:670`. Absence: `decisions.md` |

### Scope Creep (P2)

| Feature | Issue | Recommendation |
|---|---|---|
| `EDM_SMOKE_SUITES` (`run-all.sh:21`) | No ticket, no SRD requirement, no docs anywhere | Keep (sanctioned remediation path); add CHANGELOG + CLAUDE.md note |
| `EDM_EVAL_KEEP_RUNS` (`run-eval.sh:553-571`) | No ticket, no CHANGELOG entry | Keep; changelog it |
| `EDM_SRD_ROOT` / `CLAUDE_PLUGIN_OPTION_SRD_ROOT` | No ticket, no CHANGELOG entry | Documented elsewhere; only changelog half missing |

### Additional spec/ticket-pack defects (P2)

1. T37 AC6 rework landed but no decisions.md record (CA-190's own prescribed fix) -- same class as CA-163.
2. T66 AC3/AC4: no AC covers the bin/ script list at all -- CA-242's second prescribed half unapplied.
3. T40 AC2: verify greps case-sensitively; sentence ships capitalized at `CLAUDE.md:235`. Same defect CA-239 fixed for T38 AC6; sweep didn't reach this sibling.
4. T41 AC5 + Target Components: names wrong smoke suite and a nonexistent case label; real assertions live in `wave6-smoke.sh:3138-3195` under different labels.
5. CA-089 residue at a fourth site: `run-all.sh:196`'s assertion label still says "fallback tripwire" after the amended AC/architecture.md/script header all say it's not a fallback.

## Noted / Not Actionable

1. T41 AC3's negative verify correctly returns nothing -- deliberate two-branch design (D22).
2. Stale path:line anchors in Target Components -- sanctioned by tickets/README.md:57's own convention.
3. ~7 AC case-name citations are paraphrases of shipped labels, not breaks -- substance is asserted under a different label in every instance sampled.
4. `_edm-cli-lib.sh`, `_edm-lint-lib.sh`, `edm-mermaid-rules.awk` are not scope creep -- all three are prescribed audit-remediation extractions (CA-175, CA-005, CA-019).
5. Ledger Decisions/Non-Findings 2,4,5,6,21,27,33,34 (CA-106,108,109,110,125,132,174,175) re-confirmed unchanged, not re-investigated.
6. **CA-130 reproduces a fifth consecutive round.** No Write tool delivered.

## Meta

`Write` was absent from this lens's delivered runtime tool set despite the frontmatter grant
(ledger CA-130). This lens's agent was also cut off mid-investigation on its first run and had to
be resumed once to produce this report. Both `lens-L9.md` and `lens-L9.jsonl` were transcribed by
the orchestrator.
