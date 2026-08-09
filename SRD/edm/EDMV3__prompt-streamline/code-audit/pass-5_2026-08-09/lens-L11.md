# Lens L11: Integration Wiring -- Pass 5 (2026-08-09)

Round type: full (11 lenses, per code-audit/pass-5_2026-08-09/lenses-run.txt:1)

## Delivery-layer self-report (diagnostic for G4/CA-193)

**The repository-side G4 fix IS present on disk.** skills/code-audit/SKILL.md:225-246 is the
fenced launch template; the literal one-line JSONL schema sits at :235 and the CA-130 fallback
clause at :236-242, both INSIDE the fence, exactly as CA-193 prescribed. The verbatim-copy
requirement is stated twice, at :72-77 and :220-223. Step 8a at :79-92 is a CHECKED
Glob-and-count gate, positioned before step 9's synthesizer spawn at :93. My own on-disk agent
definition carries "## JSONL Line Format" at agents/edm-audit-wiring.md:114-139 with the schema
at :121.

**The fix did NOT reach my delivered prompt.** Three independent elisions:

1. My delivered Output clause used the pointer form only -- "a matching lens-L11.jsonl using
   the schema in your own agent definition's '## JSONL Line Format' section". The literal schema
   line at SKILL.md:235 was elided. The CA-130 fallback clause at :236-242 was replaced with
   a different fallback (return-as-text marked TRANSCRIBE-TO), which covers the Write-absence
   case but not the schema-absence case.
2. My delivered agent definition is a stale pre-CA-165 revision missing four on-disk
   sections: "## Scope" (:20-22), "## Output" (:76-86), "## JSONL Line Format" (:114-139),
   and "## When this does NOT apply" (:141-143); plus the False-Alarm-Filter confidence
   paragraph at :70, the docs/canonical-sections.md read instruction at :90, and the
   "## Noted / Not Actionable" table at :107-112. So the pointer had nothing to resolve
   against.
3. Delivered tool set: Read, Grep, Glob, WebFetch, WebSearch, TaskStop. No Write, no Bash.

**Verdict: G4's fix is not working end-to-end.** The schema reached me only because I could
Read the on-disk agent definition myself -- a recovery available only because this round's audit
scope IS the repository that holds the plugin. On an installed-plugin run against an unrelated
project, the readable copy would be the same cache that produced the stale delivered definition,
and that recovery would not exist.

**New, measurable consequence found this round.** The stale delivered definition also reverts the
CA-165 fix. My delivered "## Output Format" shows the findings table as `| # | Type | ... |` with
a bare-integer row `| 1 | ... |`; the on-disk template at agents/edm-audit-wiring.md:95-97 shows
`| ID | Type | ... |` with `| L11-001 | ... |`. evals/score-artifacts.sh:473 counts prose rows
with `grep -cE "^\| *L${lens_n}-[0-9]+ *\|"`, so a report following the delivered template yields
md_count = 0, and :480-488 then scores that lens 0 against a non-zero jsonl_count -- a
false dimension-5 failure. That is CA-165's defect reproduced at the artifact level by the stale
cache. This report therefore uses the ON-DISK table format so dimension 5 can count it.

## Findings (L11: Integration Wiring)

| ID | Type | Component/Endpoint | Break In Chain | File:Line |
|----|------|----------------------|-------------------|-----------|
| L11-001 | Contract delivered but unenforceable | code-audit lens JSONL schema (CA-193 residual) | Repo fix present, but step 8a validates COUNT not SCHEMA, and the tripwire does not pin the schema inside the fence -- a positional regression stays green | plugins/edm/skills/code-audit/SKILL.md:79 |
| L11-002 | Gate bypassable by a second spawn site | step-8a precondition -> synthesizer spawn | "## Synthesizer Phase" restates the spawn under "After all lens reports are written" with zero reference to step 8a | plugins/edm/skills/code-audit/SKILL.md:259 |
| L11-003 | Tripwire scope not widened with its needle | G5/G14 flat-path tripwire (CA-195 residual) | Needle now catches both spellings; scope is still a hardcoded 19-file enumeration out of 14 skills + 21 agents | plugins/edm/bin/tests/wave7-smoke.sh:5777 |
| L11-004 | Consumers with zero producer | last_cmd (CA-246 residual) | Two renderers read it; nothing in skills/agents/hooks writes it, so both lines are permanently suppressed | plugins/edm/bin/edm-state:3602 |
| L11-005 | Subcommand with zero callers + stale citer | cmd_lint / cmd_git_lock_check (CA-247 residual) | edm-state lint has no caller anywhere; architecture.md cites the wrong 250-line-off range | plugins/edm/bin/edm-state:4280 |

### Details

#### L11-001: CA-193's repository fix landed and is still one elision from the CA-020 break -- fifth consecutive recurrence

Step-8a is count-only (":79-83 reads Glob lens-L*.jsonl and count the matches; compare against
|LENS_SET|"), so it cannot distinguish eleven correctly-schema'd files from eleven files carrying
an invented schema. The wave7-smoke.sh:5749-5752 tripwire asserts the four schema tokens exist
somewhere in the FILE, not inside the fenced body -- moving the schema back above the fence (the
exact CA-193 regression) leaves all four assertions green.

**Fix**: extend step 8a to validate content (schema/lens/sev/status keys present, id null; refuse
on findings-ledger-shaped keys like lenses/component/raised_round). In wave7-smoke.sh, extract the
fenced template body and assert the schema tokens appear WITHIN it.

#### L11-002: step-8a can be bypassed because a second section restates the synthesizer spawn without it

skills/code-audit/SKILL.md:258-279's "## Synthesizer Phase" is where the actual spawn PROMPT
lives, and it contains no reference to step 8a or |LENS_SET|. "After all lens reports are
written" is satisfied by markdown-only reports -- precisely the pass-3 state CA-193 documents.

**Fix**: one clause at :259 cross-referencing step 8a's precondition, with an assertion that the
cross-reference cannot be dropped.

#### L11-003: the CA-195 tripwire's needle was widened; its enumeration was not

The substantive sweep is complete and the tripwire's control is real (paired positive checks
prevent vacuous passes). But it's wired to a hardcoded 19-file enumeration (7 skills + 10 agents +
2 more) out of 14 skills and 21+ agents shipped. A regression in any of the ~16 unenumerated files
is invisible -- the same "sweep keyed on one axis" root cause CA-195 was raised for, one axis over
(spelling fixed, scope not).

**Fix**: replace the two enumerated loops with one tree-wide scan over skills/*/SKILL.md and
agents/*.md for both needles, with a three-entry exception list.

#### L11-004: last_cmd still has two live consumers and zero producers

bin/edm-state:3596/3602 (session-start) and :4815/4881 (HANDOFF.md) both read last_cmd; nothing in
skills/agents/hooks writes it. Third round running with this gap documented but not resolved. The
sibling field estimated_size IS fixed (producer at skills/plan/SKILL.md:197).

**Fix**: add a producer at phase skills' Step 0 preflight, or delete the two renderer lines.
Documenting the gap a third time is not a resolution state.

#### L11-005: cmd_lint still has zero callers, and the architecture.md citer went stale a second time

cmd_lint (bin/edm-state:4280) has zero callers tree-wide; the PreToolUse hook calls
edm-lint-artifacts directly. Separately, architecture.md:631 cites cmd_git_lock_check at
:3177-3202 where the function is actually at :3426 -- stale in two consecutive rounds.

**Fix**: decide on cmd_lint (route the hook through it or drop the wrapper); re-point the citation
using the by-name form CA-095 adopted elsewhere so it cannot re-stale.

## Verified Fixed This Round (open L11 ledger entries)

| ID | Evidence |
|----|----------|
| CA-284 | lens-L{N}.jsonl now present in BOTH artifact-layout blocks, listed before the markdown (README.md:195, CLAUDE.md). |
| CA-285 | orchestrator/SKILL.md:174 now suggests /edm:test <PREFIX> at end of Phase 6. |
| CA-286 | score-artifacts.sh:432-447 now counts lens-L*.md and scores 0 with a named reason when markdown exists but JSONL doesn't, distinguishing no-round from round-with-a-dropped-contract. |

Also spot-checked and confirmed fixed: CA-194 (current_step producer), CA-245 (resolve-dir in
hooks.json step 4), CA-168's wiring half (all five update-patterns arms have real skill callers),
CA-004/CA-020 (--lenses passed correctly).

## Orphaned-Helper Check (Wave 8 extractions) -- none orphaned

| Helper | Definition | Callers |
|--------|------------|---------|
| _unpack_token_fields | bin/edm-state:420 | :2102, :3797 -- both sites CA-277 named |
| _lock_retry_or_die | bin/edm-state:1005 | :1130, :1144, :1148 -- all three CA-278 tails, asserted at wave7-smoke.sh:4680/4725/4728 |
| _measure_p95 | bin/tests/timing.sh:97 | 13 sites across all six measuring modes |
| assert_tree_absent | bin/tests/_harness.sh:243 | 16 sites in wave7-smoke.sh, 1 in wave6-smoke.sh |

Also checked and fully consumed: the EDM_RUN_ALL_SUITE_DIR/PREFERRED_ORDER/MIN_SUITE_COUNT family.

## Noted / Not Actionable

1. plan/SKILL.md:60 -- bare SRD/{PREFIX}/ in an existence probe with resolve-dir 4 lines below;
   same shape as CA-297's orchestrator carve-out, extending it here.
2. **CA-130 reproduced a fifth consecutive round** on this lens -- no Write/Bash, stale
   pre-CA-165 definition missing four sections. Host-side, not a repository defect.
3. CA-131 data point: delivered prompt again carried a resolved path rather than literal
   ${OUTPUT_DIR}; still not statically decidable.
4. wave7-smoke.sh:129 -- mislabelled assertion greps bin/edm-state instead of skills tree for
   estimated_size; no live consequence since G86 at :5916-5917 covers it. L4's class.
5. wave7-smoke.sh:5812 -- edm-audit-test-quality leg of the tripwire has no positive control;
   CA-037's class, folded into L11-003's fix.
6. KillShell/BashOutput granted with no Bash grant -- CA-179's accepted dead-grant surface.

## Meta

`Write` and `Bash` were absent from this lens's delivered runtime tool set despite the frontmatter
grant (ledger CA-130 -- fifth consecutive round). The delivered agent definition was also a stale
pre-CA-165 revision. Both `lens-L11.md` and `lens-L11.jsonl` were transcribed by the orchestrator.
