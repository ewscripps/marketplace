# Lens L6 -- Documentation Accuracy (Round 5, full round)

Scope: plugins/edm/ in full plus repository-root CLAUDE.md and .gitlab-ci.yml comments.

## Cross-round ledger re-verification

| Ledger ID | Verdict |
|---|---|
| CA-168 | **FIXED at all five named sites -- sixth sibling raised as L6-001** |
| CA-265 | **FIXED** |
| CA-266 | **FIXED** |
| CA-267 | **FIXED, both halves** |
| CA-268 | **Trap FIXED; citation RE-STALED by its own remediation -- raised as L6-002** |
| CA-130 | **REPRODUCES -- sixth consecutive round** |

## Findings (L6: Documentation Accuracy)

1. **L6-001** -- `docs/audit-patterns/SOURCES.md:19` still attributes auto-population to the
   orchestrator; nothing auto-populates this file at all. CA-168's unswept sixth sibling.
2. **L6-002** -- `edm-state:626-629`'s trap-exemplar citations: one of four resolves.
   `edm-check-grants:124` is now the rationale comment (trap at :127); `_harness.sh:104` is
   `prev_path="$PATH"` (trap at :110); `_harness.sh:76` is mid-comment (corrected form at :81-82).
   CA-232's citations re-staled by CA-268's own trap widening.
3. **L6-003** -- `run-eval.sh:212-214` cites `edm-state:622-625` for write_atomic's trap layer;
   that's the CA-159 comment, trap layer is at :645-648.
4. **L6-004** -- `wave7-smoke.sh:983` cites the wrong 30-line range for `--path`'s implementation.
5. **L6-005** -- `wave6-smoke.sh:3782` cites `edm-state:687-704` for `convergence_exempt()`,
   defined at :871.
6. **L6-006** -- `edm-state:594`'s section header still says `_EDM_TRAP_DEPTH` is armed only
   around the mkdir branch; CA-257 armed the flock branch too and moved the guard above both.
7. **L6-007** -- `run-all.sh:10-13`'s CA-074 rationale describes the bare-capture pattern the
   suite now bans; the actual code uses the seed-zero-then-capture form.
8. **L6-008** -- `CHANGELOG.md:236-240`'s CA-196 caveat says sample counts are 3/5/10 and
   unchanged; Wave 8 raised every mode to 20, and the cross-referenced timing.sh comment now says
   the opposite.
9. **L6-009** -- `CLAUDE.md:847` still says the convergence precheck needs `schema_version >= 2`;
   CA-182 made the precheck unconditional, >= 2 now gates only the degradation arm.
10. **L6-010** -- `evals/README.md:84-91`'s allow-list derivation doesn't reproduce the actual
    `CLAUDE_ALLOWED_TOOLS` string (implies AskUserQuestion granted, omits LS, undercounts Bash
    matchers); a third, different formula exists in the code comment.
11. **L6-011** -- `edm-state:415-416`'s new docstring says the `_save_traps` convention is
    "above" `_unpack_token_fields`; it's ~140 lines below.

## Noted / Not Actionable

1. Stale-looking citations in two agent files sit inside fenced template samples -- illustration.
2. Citations inside committed scorer fixtures are synthetic test data, not tree claims.
3. `timing.sh:74` vs `:89` gives two different denominators for the same collapse (9 loops vs 6
   modes) -- approximating, not false.
4. `CHANGELOG.md:206`'s "eight budgets" loosely restates timing.sh's exact phrase against a
   14-row table -- approximating.
5. `evals/README.md:46` names SIGINT/SIGTERM where HUP is also trapped -- the operative claim is
   exact.
6. `docs/audit-patterns/qc-audit.md:54`'s orchestrator attribution is inside EDMV2-seeded process
   advice with its own provenance, not a claim about current wiring -- distinguished from CA-168.
7. `vocabulary-allowlist.txt`'s Class 7/6 ordering is cosmetic; CA-233's load-bearing constraint
   confirmed removed.
8. **CA-130 reproduces a sixth consecutive round.**

## Wave-8 remediation spot-checks that came back clean

Subcommand count (40/40 match), bin/ script table (9/9), skill/agent inventories (14/14, all
model/effort claims verified), CA-284 (lens jsonl in layout blocks), CA-285 (/edm:test suggestion
present), CA-218 (all four step citations resolve by name), CA-269/CA-233 (carve-outs present,
extension exclusions on both loops), CA-240 (current_step vocabulary published), CA-274/CA-281
(labels and comments corrected), CA-275 CHANGELOG half, CA-231/CA-200, CA-229/CA-245/CA-253
(hooks table now accurate), evals/README.md retention section, evals/baseline/README.md auth
narrative.

## Meta

`Write` was absent from this lens's delivered runtime tool set despite the frontmatter grant
(ledger CA-130, sixth consecutive round). Both `lens-L6.md` and `lens-L6.jsonl` were transcribed
by the orchestrator.

**Lens-level observation**: 8 of 11 findings are stale citations that were correct when written
and went stale because a later edit in the same or following wave moved the target -- three
(L6-002, L6-003, L6-008) were re-staled by the very remediation that fixed their predecessors.
Recommend a CI ban or smoke assertion on new `<file>:<digits>` citations in comments, matching
the existing sentinel-extractor/entity-walk ban shape, or this class recurs again in round 6.
