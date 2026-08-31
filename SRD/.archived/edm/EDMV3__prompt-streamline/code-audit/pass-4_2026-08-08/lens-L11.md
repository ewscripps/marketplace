# Lens L11: Integration Wiring -- Round 4

## JSONL mechanism status

The repository-side CA-193 fix DID land (`skills/code-audit/SKILL.md:219` literal schema plus
fallback clause), but the break recurred one layer up: the prompt delivered to this lens carried
the pointer form only, and the delivered agent definition had no `## JSONL Line Format` section to
resolve it against. Re-filed as L11-001.

## Findings (L11: Integration Wiring)

| ID | Sev | Conf | Component | Fix |
|----|-----|------|-----------|-----|
| L11-001 | P1 | high | Lens JSONL schema handoff | `skills/code-audit/SKILL.md:218-226`'s launch template schema line and CA-130 fallback clause were dropped from the delivered lens prompt this round. Make the schema/fallback non-elidable; harden step 8a from a prose precondition to a checked one (Glob the output dir before spawning the synthesizer). |
| L11-002 | P1 | high | 12 legacy-flat-path sites | Same CA-195 class survives under the bare `SRD/{PREFIX}/` spelling in 4 skills + 3 agents, outside G14's tripwire needle. Sweep to `${INIT_DIR}`; widen G14's needle. |
| L11-003 | P2 | high | `last_cmd` | Two renderers read it; nothing writes it. Add a producer in plan/SKILL.md's Step 0, or delete the renderers. |
| L11-004 | P2 | high | `lens-L{N}.jsonl` unlisted | Absent from both artifact-layout blocks (README.md:195, CLAUDE.md:111) though it's authoritative and a blocking precondition. |
| L11-005 | P2 | high | orchestrator -> testing layer | Zero mentions of `/edm:test` anywhere in orchestrator/SKILL.md, though CLAUDE.md claims the flow suggests it at end of Phase 6. |
| L11-006 | P2 | medium | `edm-state lint`; git-lock-check citation | `cmd_lint` still has zero callers tree-wide; architecture.md:631's corrected prose now cites a stale line range. |
| L11-007 | P2 | medium | `score-artifacts.sh` dimension 5 | Keys solely on absence of `lens-L*.jsonl`, never consults `.md` presence, so "no round" and "round with zero JSONL" score identically. |

## Verdicts on prior-round open L11 ledger entries

| Ledger ID | Verdict |
|---|---|
| CA-193 | **RE-FILED as L11-001** -- repository fix landed; break recurred at the delivered-prompt layer |
| CA-194 | **FIXED end-to-end** -- producer, all 7 consumer skills, renderers, and a guard test all verified |
| CA-195 | **FIXED as scoped; class survives at 12 unnamed sites** -- see L11-002 |
| CA-166 | **FIXED at all 3 named sites; one residual** -- see L11-004 |
| CA-168 | **FIXED end-to-end** |
| CA-218 | **FIXED** |
| CA-245 | **FIXED** |
| CA-246 | **PARTIALLY FIXED** -- see L11-003 |
| CA-247 | **PARTIALLY FIXED** -- see L11-006 |

## Noted / Not Actionable

1. `monitors.json`'s zero-arg `watch-impl` declaration is correct -- the command is prefix-agnostic by design.
2. The flat-only `SRD/{PREFIX}/` existence probe in orchestrator/SKILL.md is prose shorthand beside an already-correct `edm-validate-prefix` call.
3. `edm-qc-auditor.md:77`'s `SRD/{PREFIX}/` correctly names the legacy layout as a concept, not a path residue.
4. push-jira and metrics are intentionally not dispatched by the orchestrator -- documented opt-in.
5. `lenses-run.txt` verified consumed by edm-audit-synthesizer.
6. All five documented `EDM_EVAL_*` config knobs verified consumed.
7. All 30 agents verified to have at least one launch site.
8. `.tiering_results` has no producer (CA-107, already NOTED).
9. **CA-130 reproduced a fifth consecutive round.** Delivered tool set lacked Write; delivered agent definition was a pre-CA-165 revision missing four on-disk sections.

## Meta

`Write` was absent from this lens's delivered runtime tool set despite the frontmatter grant
(ledger CA-130). Both `lens-L11.md` and `lens-L11.jsonl` were transcribed by the orchestrator.
