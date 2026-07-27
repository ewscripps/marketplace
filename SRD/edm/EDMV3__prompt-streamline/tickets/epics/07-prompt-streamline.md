# Epic E7 -- WS7: Prompt streamline

**Wave**: C (v3.0.0 -> v3.1.0)
**SRD requirements**: EDMV3-59 .. EDMV3-69 (11)
**Tickets**: EDMV3-T45 .. EDMV3-T49 (5)

D1, the original Large-scope mandate. Applied strictly after WS5 so every edit lands once in the
deduplicated skills rather than twice in duplicated ones. Explorer 02 Part D is the guardrail
throughout, and EDMV3-T49 records it as a standing regression guard so a future reader of the Opus 5
guidance does not delete EDM's audit architecture in the name of "removing over-verification".

All commands are run from the repository root unless stated otherwise.

---

## EDMV3-T45: Communication cadence and deliverable-length calibration

| Field | Value |
|---|---|
| Epic | E7 -- Prompt streamline |
| Wave | C |
| Priority | Should Have |
| Size | S |
| SRD Refs | EDMV3-59, EDMV3-60 |
| Depends On | EDMV3-T38 |
| Ships-with | -- |
| Target Components | `plugins/edm/skills/orchestrator/SKILL.md` (new `## Communication` section near the top, `<tone_preference>` block after the anti-patterns section), `plugins/edm/agents/edm-srd-writer.md:37`, `plugins/edm/skills/srd/SKILL.md:61`, and the `## Output` sections of the eight file-writing agents (`edm-explorer`, `edm-architect`, `edm-srd-writer`, `edm-ticket-writer`, `edm-audit-synthesizer`, `edm-qc-auditor`, `edm-test-planner`, `edm-test-coverage-auditor`) |

### Description

Explorer 02 A1.3 and C1.1: Opus 5 narrates readily during agentic work, and the plugin has zero
communication-cadence guidance across 30 agents and 13 skills. The Opus 5 guide also recommends
pairing a long system prompt with a short tone reminder near the end.

Explorer 02 A1.2 and C2.3 is the direct tension: EDM prescribes length floors with no ceiling and no
anti-padding clause (`agents/edm-srd-writer.md:37`, `skills/srd/SKILL.md:61`: "800+ lines major, 200+
focused, 50+ small change"). A raw line-count floor given to a model with a documented long-deliverable
bias is the most likely source of filler in EDM's most-read artifact. Explorer 02 F4 warns the floors
presumably exist because SRDs *were* thin, so removing them risks regressing the original problem.

The two ship in one ticket precisely so one implementer enforces the separation between them: the
conversational guidance and the deliverable guidance must never appear in the same section
(explorer 02 F2).

### Acceptance Criteria

- [ ] AC1 (positive, cadence section): the dispatcher gains a `## Communication` section near the top
      prescribing cadence -- one sentence before the first tool call stating what is about to happen;
      a brief update only on an important finding or a change of direction; on finishing, lead with
      the outcome.
      Verify: `grep -n '^## Communication$' plugins/edm/skills/orchestrator/SKILL.md`.
- [ ] AC2 (tone reminder placement): a three-line `<tone_preference>` reminder is placed near the end
      of the dispatcher, after the anti-patterns section.
      Verify: `grep -n '<tone_preference>' plugins/edm/skills/orchestrator/SKILL.md` returns a line
      number greater than the anti-patterns heading's.
- [ ] AC3 (cap not re-baselined): both sections are budgeted inside EDMV3-T38's 300-line cap, which
      was re-derived to include them (~20 lines). The cap is **not** re-baselined by this ticket.
      Verify: `wc -l < plugins/edm/skills/orchestrator/SKILL.md` is at most 300 and
      `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "orchestrator at most 300 lines") is green.
- [ ] AC4 (negative, strict scoping): both sections are scoped explicitly and exclusively to
      conversational output. Neither mentions artifacts, deliverables, or file contents.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "Communication section mentions no
      artifact"), asserting the absence of `srd.md`, `artifact` and `deliverable` within the section
      and the `<tone_preference>` block.
- [ ] AC5 (correction narration): the correction-narration guidance is included -- correct an earlier
      statement only when the error would change the user's code, conclusions or decisions; state
      corrections plainly and briefly, then continue.
      Verify: `grep -n 'change the user' plugins/edm/skills/orchestrator/SKILL.md`.
- [ ] AC6 (negative, no interim scaffolding): no interim-progress scaffolding is added -- no
      "summarize every N tool calls" (explorer 02 D4).
      Verify: `grep -rn -i 'every [0-9]* tool calls\|summarize every' plugins/edm/skills/` returns
      zero results.
- [ ] AC7 (floors preserved verbatim, negative): the length floors are preserved verbatim at both
      sites. A diff that lowers or removes a floor is a failing condition.
      Verify: `grep -n '800+\|200+\|50+' plugins/edm/agents/edm-srd-writer.md plugins/edm/skills/srd/SKILL.md`
      returns the unchanged figures, and
      `git diff plugins/edm/agents/edm-srd-writer.md | grep '^-' | grep -c '800+'` returns 0.
- [ ] AC8 (positive, anti-padding clause): each floor gains the anti-padding clause -- match the
      length of the document to what the task needs, cover the substance, do not pad with filler
      sections, redundant summaries or boilerplate -- and is reframed as a substance signal rather
      than a target: a draft below the floor is probably missing substance, not merely short.
      Verify: `grep -n 'do not pad with filler' plugins/edm/agents/edm-srd-writer.md plugins/edm/skills/srd/SKILL.md`.
- [ ] AC9 (clause applied to eight agents, identically): the same one-line deliverable-length clause
      is added to the `## Output` section of the eight file-writing agents, identical across all
      sites so it can be asserted with one grep.
      Verify: `grep -rho 'match the length of the document to what the task needs' plugins/edm/agents/ | sort -u | wc -l`
      returns 1, and `grep -rlc 'match the length of the document' plugins/edm/agents/ | wc -l`
      returns 8.
- [ ] AC10 (negative, never co-located): this requirement's text never appears in the same section as
      the conversational guidance.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "length clause absent from the
      Communication section").
- [ ] AC11 (grounded, not assumed): before touching `agents/edm-srd-writer.md:37`, the ticket records
      a check of archived EDMV2 artifacts for filler sections, so the change is grounded rather than
      assumed (explorer 02 F4).
      Verify: the ticket's QC evidence names the archived artifacts inspected and what was found.
- [ ] AC12 (prose-change convention): the merge request shows before and after for each changed block
      plus one sentence of rationale (EDMV3-69).
      Verify: the MR description contains the before/after blocks.

### Technical Notes

- RK-12: Anthropic guidance written for direct API prompting may not transfer to Claude Code plugin
  skills. The mitigation is exactly AC4 and AC10 -- conversational cadence guidance is scoped so it
  can never touch deliverable length, and the floors are preserved verbatim.
- Depends on EDMV3-T38 so the edit lands once in the dispatcher rather than in the 645-line
  orchestrator and again in a phase skill.

### Out of Scope

- Any change to the floors themselves (explicitly forbidden by AC7).
- Agent scope, output contracts and carve-outs -- EDMV3-T46.
- The do-NOT-adopt guards -- EDMV3-T49.

---

## EDMV3-T46: Agent scope, output contracts, decision ladder, and N/A carve-outs

| Field | Value |
|---|---|
| Epic | E7 -- Prompt streamline |
| Wave | C |
| Priority | Should Have |
| Size | M |
| SRD Refs | EDMV3-61, EDMV3-62, EDMV3-63, EDMV3-64 |
| Depends On | EDMV3-T03, EDMV3-T38 |
| Ships-with | -- |
| Target Components | `plugins/edm/agents/edm-explorer.md`, `plugins/edm/agents/edm-audit-*.md` (11 lenses plus the synthesizer), `plugins/edm/agents/edm-implementer.md` (`## Core Rules`), `plugins/edm/agents/edm-test-{unit,component,composable,integration,contract,e2e,a11y,scaffold,planner}.md`, all 30 `plugins/edm/agents/*.md`, `plugins/edm/CLAUDE.md` (Testing layer N/A behaviour) |

### Description

Four related agent-prompt normalizations, batched because they touch the same 30 files and because
three of them are the same shape of edit -- add a consistently named short section, identical across
sites, assertable with one grep.

Explorer 02 A1.4 and C1.3: tickets and ACs constrain Phase 6, but nothing constrains the explorer, the
eleven lenses or the synthesizer -- the widest-mandate roles, all running `opus` at `effort: max`,
which is the exact configuration the Opus 5 guide says expands scope and adds unrequested steps.

Explorer 02 B2.3 and C1.6: every audit agent already has a `## Output Format`; `edm-implementer` and
the nine `edm-test-*` writers return free-form prose into the orchestrating context, so their tool
results are unbounded and unparseable.

Explorer 02 C2.6: implementation decisions are cheapest-first choices, which a stop-at-first-rung
ladder encodes and a flat bullet list does not.

Explorer 02 C2.7 and B2.5: six test agents already have a one-line N/A carve-out; the pattern is what
makes an aggressive instruction safe to ship, and a consistent named section lets the caller rely on a
uniform exit token.

### Acceptance Criteria

- [ ] AC1 (positive, scope line on thirteen agents): `agents/edm-explorer.md`, all eleven
      `agents/edm-audit-*.md` lenses, and `agents/edm-audit-synthesizer.md` gain a one-line
      `## Scope` statement: deliver what was asked at the scope intended; make routine judgment
      calls; if a better approach exists, say so in a sentence and continue with the task as asked
      rather than quietly narrowing, widening or transforming it. The line is identical across all
      thirteen files.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "thirteen occurrences of the scope
      line"), and
      `grep -rho 'deliver what was asked at the scope intended' plugins/edm/agents/ | sort -u | wc -l`
      returns 1.
- [ ] AC2 (negative, the scope line does not narrow a mandate): the line does not weaken any lens's
      mandate. A lens still reports everything it finds within its lens; the scope line constrains
      *what work it does*, not *what it reports*.
      Verify: `git diff plugins/edm/agents/edm-audit-*.md | grep '^-' | grep -ci 'report'` returns 0,
      and `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "False Alarm Filter criteria count
      unchanged").
- [ ] AC3 (positive, output contracts on ten agents): `agents/edm-implementer.md` and the nine
      `edm-test-*` agents each gain an `## Output` section with a one-line output pattern, mirroring
      the lens `## Output Format` shape, spelling out the degenerate cases explicitly -- zero
      results, single result, and the terminating summary line.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "ten agents contain an `## Output`
      section").
- [ ] AC4 (write paths: exact list versus path class): each contract states the write paths the agent
      is permitted to produce, matching EDMV3-T03's grant cross-reference. For the
      artifact-producing agents this is an exact path list. For the nine `edm-test-*` writers it is a
      path **class** -- only under the detected test root or roots recorded in `test-plan.md`, plus
      the agent's own coverage artifact -- because their whole job is writing test files into
      arbitrary project trees, and an exact list is neither achievable nor desirable there. Anything
      outside that class is a contract violation.
      Verify: `grep -n 'detected test root' plugins/edm/agents/edm-test-unit.md` and
      `bash plugins/edm/bin/edm-check-grants; echo "exit=$?"` prints `exit=0`.
- [ ] AC5 (N/A carve-out preserved and folded in): the existing one-line "when this layer is N/A"
      carve-outs in the test agents are preserved and folded into the contract as the documented N/A
      exit token, so the caller can rely on a uniform signal.
      Verify: `git diff plugins/edm/agents/edm-test-*.md | grep '^-' | grep -ci 'N/A'` returns 0.
- [ ] AC6 (generalization stated literally): contracts state their generalization scope explicitly
      per Sonnet 5 literal-instruction-following -- apply the format to every item, not just the
      first.
      Verify: `grep -c 'every item, not just the first' plugins/edm/agents/edm-implementer.md` is
      non-zero.
- [ ] AC7 (positive, decision ladder): `agents/edm-implementer.md` `## Core Rules` becomes a numbered
      ladder with the instruction "stop at the first rung that holds", ordered cheapest-first, each
      rung a yes/no test rather than a step.
      Verify: `sed -n '/## Core Rules/,/^## /p' plugins/edm/agents/edm-implementer.md` shows a
      numbered list and the stop instruction.
- [ ] AC8 (negative, the ladder cannot short-circuit comprehension or ACs): the bound clause is
      included -- the ladder runs *after* the ticket is understood, never instead of understanding it
      -- and satisfying the ticket's acceptance criteria is never a rung that can be short-circuited.
      Verify: `grep -n 'after the ticket is understood' plugins/edm/agents/edm-implementer.md` and
      `grep -n 'never a rung' plugins/edm/agents/edm-implementer.md`.
- [ ] AC9 (negative, no rule dropped in the conversion): each surviving rule is traceable to a rung or
      to a retained flat rule below the ladder. The mapping is shown in the merge request
      description.
      Verify: the MR description contains the rule-to-rung mapping table with one row per
      pre-existing rule.
- [ ] AC10 (positive, carve-out on all 30 agents): every one of the 30 `agents/*.md` files has a
      consistently named carve-out section stating when the agent does not apply and what it emits in
      that case. The exit token is uniform: a single line of the form `N/A -- <reason>`. Agents that
      always apply state so explicitly rather than omitting the section, so absence is never
      ambiguous.
      Verify: `for f in plugins/edm/agents/*.md; do grep -q '^## When this does NOT apply' "$f" || echo "MISSING: $f"; done`
      prints nothing, and the file count is 30.
- [ ] AC11 (six existing carve-outs normalized without substance change): the six existing carve-outs
      are normalized to the same section name and token without changing their substance.
      Verify: `git diff plugins/edm/agents/edm-test-*.md | grep '^-' | grep -vc 'N/A designation'`
      shows only heading-line removals.
- [ ] AC12 (cross-referenced, not restated): the N/A behaviour already documented in `CLAUDE.md` --
      designations recomputed each run and never inherited, no placeholder file or coverage row
      written, absence is authoritative -- is preserved and cross-referenced rather than restated per
      agent.
      Verify: `grep -rl 'recomputed each run' plugins/edm/agents/ | wc -l` prints 0 and
      `grep -n 'recomputed each run' plugins/edm/CLAUDE.md` returns the single source. (`grep -rc`
      prints one `file:0` line per file and exits 1, so it never "returns 0" the way the earlier
      wording assumed; `grep -rl ... | wc -l` prints a count and exits 0 either way.)
- [ ] AC13 (prose-change convention): the merge request shows before and after for each changed block
      plus one sentence of rationale (EDMV3-69).
      Verify: the MR description contains the before/after blocks.

### Technical Notes

- Four requirements, four assertable greps, 30 files. Script the repetitive insertions and hand-write
  only the per-agent reason strings in AC10 -- an agent that "always applies" still needs a
  specific sentence saying why.
- AC9's mapping table is the reviewable artifact for the ladder conversion. Without it the diff looks
  like a rewrite and a dropped rule is invisible.
- **AC-band note.** 13 acceptance criteria against the 6-12 band. Four requirements are batched here
  because they touch the same 30 files and three of them are the same shape of edit; the AC count
  tracks the four requirements, not hidden complexity. Recorded in the README sizing section.
- Depends on EDMV3-T03 because AC4's write-path contracts must agree with what `edm-check-grants`
  cross-references, and on EDMV3-T38 so the edits land in the post-dispatcher file set.

### Out of Scope

- Cadence and length -- EDMV3-T45.
- Lens model tiering -- EDMV3-T48.
- Any change to the eleven lenses' hunting briefs or False Alarm Filter criteria (forbidden by AC2
  and by EDMV3-32).

---

## EDMV3-T47: Explorer fan-out gets a deterministic cap

| Field | Value |
|---|---|
| Epic | E7 -- Prompt streamline |
| Wave | C |
| Priority | Should Have |
| Size | XS |
| SRD Refs | EDMV3-65 |
| Depends On | EDMV3-T37 |
| Ships-with | -- |
| Target Components | `plugins/edm/skills/plan/SKILL.md:114-119` (`## AI Execution Pattern`, the spawn text at `:116`), `plugins/edm/skills/orchestrator/SKILL.md:305` (the pre-move spawn step) |

### Description

Explorer 02 A1.6 and C1.5. Explorer spawning is the only uncapped delegation site in the plugin. The
two sites do not share a literal string and must be read separately:
`skills/orchestrator/SKILL.md:305` says "Spawn `edm-explorer` agent(s) ... -- parallel if scope spans
multiple codebase areas", while `skills/plan/SKILL.md:116` says "Spawn the `edm-explorer` agent. For
initiatives spanning multiple codebase areas, launch parallel agents". Neither carries a cap or a
criterion. Every other spawn site names an exact count, which is precisely the mitigation the Opus 5
guide recommends.

### Acceptance Criteria

- [ ] AC1 (positive, the cap): the explorer spawn instruction names a deterministic cap -- one
      explorer per genuinely distinct codebase area, **maximum 4**.
      Verify: `grep -n 'maximum 4' plugins/edm/skills/plan/SKILL.md`.
- [ ] AC2 (rationale recorded with the cap): the instruction records why 4 -- consistency with the
      `AskUserQuestion` four-option convention and with the existing fan-outs (2 ticket auditors, 2-3
      SRD auditors), and because a fifth genuinely distinct area is a signal the initiative should be
      split rather than explored wider.
      Verify: `sed -n '/AI Execution Pattern/,/^## /p' plugins/edm/skills/plan/SKILL.md` shows the
      rationale sentence.
- [ ] AC3 (the one-is-enough case): it states the one-is-enough case explicitly -- if one explorer can
      cover the scope, use one.
      Verify: `grep -n 'use one' plugins/edm/skills/plan/SKILL.md`.
- [ ] AC4 (criterion is applicable without further judgment): the criterion for "genuinely distinct
      area" is given concretely -- for example distinct top-level source trees, or distinct subsystems
      named in the initiative description.
      Verify: `grep -n 'distinct top-level source trees' plugins/edm/skills/plan/SKILL.md`.
- [ ] AC5 (negative, one location after the move): after the EDMV3-T37 move the instruction exists in
      `skills/plan/SKILL.md` only, and the dispatcher carries no copy.
      Verify: `grep -c 'edm-explorer' plugins/edm/skills/orchestrator/SKILL.md` returns 0.
- [ ] AC6 (negative, other caps untouched -- asserted positively on the surviving text): the
      existing deterministic caps elsewhere are left unchanged. Each is asserted by its own positive
      grep against the post-change tree rather than by a negative diff-grep on bare digits, which
      would false-positive the moment an adjacent ticket touches a numbered line -- and EDMV3-T37's
      phase-procedure move touches these same files in the same wave.
      Verify: after the change, `grep -rn 'exactly 2 .*ticket auditor' plugins/edm/skills/`,
      `grep -rn '2-3 .*SRD auditor' plugins/edm/skills/`,
      `grep -rn '6-10 .*implementer' plugins/edm/skills/` and
      `grep -rn 'all 11 lenses' plugins/edm/skills/` each return the surviving line with its count
      unchanged. The four outputs are pasted into the ticket alongside the same four commands run
      against the pre-change tree, and the pairs are identical.
- [ ] AC7 (smoke assertion): a smoke assertion checks the cap text is present in exactly one file.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "explorer cap appears exactly once").

### Technical Notes

- The value 4 is a v1.1.0 inline choice by the SRD author, not an arbitration ruling. It is recorded
  here so a future reader knows it was chosen rather than measured.
- Depends on EDMV3-T37 because before the move there are two spawn sites with different wording, and
  editing both invites the drift this whole epic removes.

### Out of Scope

- Changing any other fan-out count (forbidden by AC6).
- The explorer's `Write` grant -- EDMV3-T02 (wave A).

---

## EDMV3-T48: The tiering matrix derives model/effort assignments from fixture measurements, and the smoke path is documented

| Field | Value |
|---|---|
| Epic | E7 -- Prompt streamline |
| Wave | C |
| Priority | Should Have |
| Size | M |
| SRD Refs | EDMV3-66, EDMV3-67, EDMV3-104 |
| Depends On | EDMV3-T23, EDMV3-T27, EDMV3-T50, EDMV3-T51 |
| Ships-with | -- |
| Target Components | `plugins/edm/agents/edm-audit-*.md`, `plugins/edm/agents/edm-srd-auditor.md`, `plugins/edm/agents/edm-ticket-auditor.md`, `plugins/edm/agents/edm-qc-auditor.md` (frontmatter model and effort, matrix-derived), `plugins/edm/CLAUDE.md` (Model and effort assignments table), `plugins/edm/skills/code-audit/SKILL.md:26-30` (`--lenses`), `:54` (the prose non-convergence heading), `plugins/edm/README.md` (command table and phase-timing guidance), `plugins/edm/evals/README.md` |

### Description

F8, R5.3, and the Gate 3 revise decision **D16**. Sixteen of thirty agents run `opus`/`max` on a
table calibrated by judgment for a prior model generation and never measured. v1.2.0's
mechanical/judgment lens split was a better guess, but still a guess. This ticket replaces guessing
with the measurement: every contested assignment (the eleven lenses, `edm-srd-auditor`,
`edm-ticket-auditor`, `edm-qc-auditor`, `edm-audit-synthesizer`) enters wave C unchanged and is
retiered only by the matrix result. The three safe downgrades (explorer, test-coverage-auditor,
architect) landed in wave A via EDMV3-T02 and are out of scope here.

The smoke-audit path ships in the same ticket because the two are the same cost story from opposite
ends -- measured tiering makes a full round cheaper, and the smoke path makes a partial round a
sanctioned choice with an honestly stated trade-off. That trade-off is now *enforced* rather than
*stated*, because EDMV3-T27 made a partial round non-convergent in code.

**Ordering matters and is stated in the SRD**: EDMV3-70 and EDMV3-71 (EDMV3-T50 and EDMV3-T51) must
land before this ticket, because the untiered baseline this matrix measures against is only
measurable once Phase 6 and per-round cost are instrumented. A tiering measurement taken before the
instrumentation exists measures nothing.

### Acceptance Criteria

- [ ] AC1 (negative, nothing pre-tiered): the contested set enters this ticket unchanged -- the
      eleven lenses, `edm-srd-auditor`, `edm-ticket-auditor`, `edm-qc-auditor` and
      `edm-audit-synthesizer` all show `opus`/`max` before the matrix runs.
      Verify: `grep -n '^model:\|^effort:' plugins/edm/agents/edm-audit-*.md plugins/edm/agents/edm-srd-auditor.md plugins/edm/agents/edm-ticket-auditor.md plugins/edm/agents/edm-qc-auditor.md`
      shows `opus` and `max` for all fifteen files pre-matrix.
- [ ] AC2 (the matrix, both dimensions recorded): each contested agent runs the eval fixture at
      candidate (model, effort) pairs -- at minimum (`sonnet`, `high`) and (`opus`, `high`) against
      the recorded (`opus`, `max`) baseline -- one run per configuration, same fixture, same lens
      set, with per-agent finding counts and per-run cost recorded.
      Verify: the ticket's QC evidence contains an agent-by-configuration table (15 agents x >= 3
      configurations) with finding counts and cost per cell.
- [ ] AC3 (the promotion rule is mechanical and fires): the cheapest configuration that reports
      **100% of the P0/P1 findings the baseline reported** and **at least 80% of total findings**
      wins and is written into the agent's frontmatter; any configuration missing a P0 or P1 is
      disqualified outright; an agent with no qualifying cheaper configuration keeps `opus`/`max`.
      Verify: the ticket records, per agent, the total-findings ratio and the P0/P1 set comparison
      per configuration, and `grep -n '^model:\|^effort:'` on each agent file matches the table's
      winning configuration exactly.
- [ ] AC4 (provenance, the table is derived not asserted): the `CLAUDE.md` "Model and effort
      assignments" table is regenerated from the matrix results and carries the header line
      "Derived from tiering matrix <date>; re-run when the model generation or pricing table
      changes (EDMV3-73)."
      Verify: `grep -n 'Derived from tiering matrix' plugins/edm/CLAUDE.md` returns the header with
      a date.
- [ ] AC5 (wave-A downgrades reflected, not re-decided): the three EDMV3-T02 downgrades
      (`edm-explorer` and `edm-test-coverage-auditor` at `sonnet`/`high`, `edm-architect` at
      `opus`/`high`) appear in the regenerated table unchanged.
      Verify: `grep -n '^model:\|^effort:' plugins/edm/agents/edm-explorer.md plugins/edm/agents/edm-test-coverage-auditor.md plugins/edm/agents/edm-architect.md`
      matches the table rows.
- [ ] AC6 (negative, fan-out unchanged): lens fan-out remains eleven. No lens is merged or removed
      (explorer 02 D2).
      Verify: `ls plugins/edm/agents/edm-audit-*.md | grep -vc synthesizer` returns 11.
- [ ] AC7 (positive, smoke-audit path documented): `skills/code-audit/SKILL.md` documents a
      smoke-audit path -- `/edm:code-audit <PREFIX> --lenses L1,L9,L11` for small initiatives, full
      eleven for release candidates -- with concrete selection criteria (for example ticket count and
      whether the change touches production behaviour), not "use judgment".
      Verify: `grep -n 'lenses L1,L9,L11' plugins/edm/skills/code-audit/SKILL.md` and the criteria
      lines following it.
- [ ] AC8 (the trade-off is stated as enforced, and names the enforcer -- **owned here**, moved from
      EDMV3-T27 AC7): the guidance states plainly that a partial round is never convergent, so a
      smoke audit cannot close an initiative, and says "enforced by `edm-state audit-converged`"
      rather than pointing at the prose heading at `skills/code-audit/SKILL.md:54`. EDMV3-T27
      (wave B) previously carried this as a cross-check, which had a wave-B ticket verifying a
      wave-C edit; the assertion lives with the ticket that makes the edit.
      Verify: `grep -n 'enforced by .edm-state audit-converged' plugins/edm/skills/code-audit/SKILL.md`
      and `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "smoke-audit guidance names the
      enforcer").
- [ ] AC9 (negative, existing partial-round semantics unchanged): `ROUND_TYPE=partial`, the
      `lenses-run.txt` header, and the non-convergent marking in `REMEDIATION.md` are unchanged.
      Verify: `bash plugins/edm/bin/tests/wave4b-smoke.sh` is green and a partial fixture round still
      writes all three.
- [ ] AC10 (README surfaces the path): the `README.md` command table and the phase-timing guidance
      mention the smoke path.
      Verify: `grep -n 'smoke audit\|--lenses' plugins/edm/README.md`.
- [ ] AC11 (cost outcome measured and recorded, not a pass/fail threshold): lens tiering is expected
      to reduce measured full-round cost by roughly 25% relative to the untiered baseline on the same
      fixture. The **binding** criterion is that the reduction is *measured and recorded* against the
      same fixture and lens set, with no material recall loss per AC5. A reduction materially below
      25% is recorded with the measured figure and triggers a named consequence: the lens assignments
      are re-examined in a follow-on initiative decided on its own merits (D14 framing), and the
      recorded number becomes that initiative's starting point.
      Verify: `edm-state metrics-report <fixture-prefix>` shows the per-round cost before and after,
      both recorded in the ticket with the percentage delta.

### Technical Notes

- Depends on EDMV3-T50 and EDMV3-T51 for the reason stated in the description. If they slip, this
  ticket slips -- do not measure against an uninstrumented baseline.
- AC3's thresholds (100% baseline P0/P1, >= 80% total) are D16 policy choices where the data does
  not yet exist. Record that in the ticket so a later reader does not treat them as derived; the
  matrix results themselves become the data future thresholds are derived from.
- The matrix set is 15 agents (11 lenses + synthesizer + 3 auditors). Batch the runs: the fixture
  round already spawns all lenses at once, so a full-round run per configuration covers the 12
  code-audit agents in one pass; the srd/ticket/qc auditors need one fixture document run each per
  configuration.
- AC11 deliberately carries one reading, not two. The earlier "at least 25%, and if it does not reach
  25% record the shortfall" made the requirement pass either way, which is not an acceptance
  criterion.

### Out of Scope

- Changing the lens count or merging lenses (forbidden by AC6).
- Any change to `--lenses` machinery itself. It already exists.
- `audit-round-complete` and per-round cost capture -- EDMV3-T51.

---

## EDMV3-T49: The do-NOT-adopt guards and the before/after prose convention are recorded

| Field | Value |
|---|---|
| Epic | E7 -- Prompt streamline |
| Wave | C |
| Priority | Should Have |
| Size | S |
| SRD Refs | EDMV3-68, EDMV3-69 |
| Depends On | -- |
| Ships-with | -- |
| Target Components | `plugins/edm/CLAUDE.md` (a subsection under Model and effort assignments, plus contribution guidance), EDMV3 ticket pack acceptance criteria |

### Description

Explorer 02 Part D is the main regression surface for a prompt-only workstream, and its handoff note
says to carry it into the SRD verbatim. Without a recorded guard, a future reader of the Opus 5
guidance will delete EDM's audit architecture in the name of "removing over-verification".

The before/after convention ships here because it is the other half of the same governance story: the
entire initiative's diff is prose changes to a mature, already-audited prompt set, so a diff with
rationale is the only reviewable artifact -- and recording the convention once in `CLAUDE.md` makes it
outlive this initiative.

### Acceptance Criteria

- [ ] AC1 (positive, conventions recorded as house style): `plugins/edm/CLAUDE.md` gains a subsection
      under Model and effort assignments recording the prompt conventions adopted (EDMV3-59 through
      EDMV3-67) as house style, citing the Opus 5 and Sonnet 5 guide URLs, so agents added later
      inherit the conventions rather than rediscover them.
      Verify: `grep -n 'house style' plugins/edm/CLAUDE.md` returns the subsection with both URLs.
- [ ] AC2 (provenance and licence recorded, **four** sources): the same subsection records the
      licence and URL of every external prompt source this initiative mined, and states that the
      adoptions are structural (instruction-design patterns) rather than verbatim text. **Four**
      sources, matching the enumeration that follows: the Opus 5 guide, the Sonnet 5 guide, and the
      two external repositories `caveman` and `ponytail`. The earlier text said "Three sources" and
      then listed four, and the verification checked only two of them. If either repository is
      non-permissively licensed, a clean-room note records that the adoption was pattern-level and
      no text was copied.
      Verify: `grep -c 'https://' <the subsection>` returns at least 4, and each of the four sources
      has a URL line -- `grep -n 'opus-5' plugins/edm/CLAUDE.md`,
      `grep -n 'sonnet-5' plugins/edm/CLAUDE.md`, `grep -n 'caveman' plugins/edm/CLAUDE.md` and
      `grep -n 'ponytail' plugins/edm/CLAUDE.md` each return a line carrying both a licence and a
      URL.
- [ ] AC3 (six guards, named and cited): the subsection records the six do-NOT-adopt guards as named,
      cited rules -- (D1) do not strip the audit or QC architecture in the name of over-verification
      guidance, since EDM contains no *self*-verification and its independent-agent auditing is the
      writer-verifier pattern the guide praises; (D2) do not reduce the 11-lens or 2-auditor fan-out
      to keep spawn counts low, since the counts are already deterministic; (D3) do not import terse
      register into EDM artifacts, since SRDs and tickets are read by humans in merge requests; (D4)
      do not add interim-progress scaffolding; (D5) do not add "think step by step" or anti-thinking
      instructions -- raise effort instead; (D6) do not duplicate the mode matrix into agent prompts,
      since it is state-backed and read at runtime.
      Verify: `grep -c '(D[1-6])' plugins/edm/CLAUDE.md` returns 6.
- [ ] AC4 (each guard states its cost): each guard states its cost concretely, in the ponytail
      pattern, so it survives edge cases its author did not anticipate.
      Verify: read the subsection -- each of the six carries a "the cost of ignoring this is ..."
      clause, asserted by
      `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "six guards each carry a cost clause").
- [ ] AC5 (smoke assertion): a smoke assertion checks the guard subsection exists and contains all
      six guard identifiers.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "do-NOT-adopt subsection with six
      identifiers").
- [ ] AC6 (negative, the already-compliant state is preserved -- with the one carve-out that makes
      it survivable): `grep` confirms the plugin still contains zero matches for the
      **self**-verification phrase family, so the compliant state is preserved rather than
      accidentally regressed by this epic. `skills/verify-runtime/` is carved out: EDMV3-T33 creates
      a skill whose entire subject is runtime verification, so the phrase "verification step" is
      legitimate there and an uncarved grep is guaranteed to false-positive from wave B onward. The
      family is narrowed to self-directed phrasing accordingly.
      Verify: `grep -rni 'double-check\|verify your own\|check your work\|re-verify your' plugins/edm/skills plugins/edm/agents | grep -v 'skills/verify-runtime/'`
      returns zero results. The carve-out is one directory and is named in the ticket, not a general
      licence.
- [ ] AC7 (positive, before/after convention as a ticket AC): every ticket in this pack whose change
      is prompt text carries an acceptance criterion requiring the merge request to show before and
      after for each changed block plus one sentence on why the new wording is better. After the
      round-1 ticket audit this holds for every epic file: the convention ACs were added to
      EDMV3-T24, T36, T42, T53 and T58 alongside the ones already present in T15, T25, T29, T31,
      T35, T37, T38, T45, T46 and T55.
      Verify: `grep -rl 'before and after' SRD/edm/EDMV3__prompt-streamline/tickets/epics/ | sort`
      lists **exactly the nine epic files that contain a prompt-text ticket** -- `01`, `02`, `04`,
      `05`, `06`, `07`, `08`, `09`, `10`. `epics/03` (CI, harness, eval scripts) and `epics/11`
      (portability guards, closeouts, budgets) contain no prompt-text ticket and are expected
      absences, named here so a zero is read as correct rather than as a miss. Before the round-1
      ticket audit the list was missing `01`, `06`, `08` and `10`. (`grep -c` per file would print
      `file:0` lines for any miss and exit 1, hiding the failure inside a command that looks like it
      passed -- which is why the grep is restated in `-rl` form.)
- [ ] AC8 (convention outlives the initiative): the convention is recorded once in
      `plugins/edm/CLAUDE.md` under contribution guidance.
      Verify: `grep -n 'before and after for each changed block' plugins/edm/CLAUDE.md`.
- [ ] AC9 (two named special cases): for EDMV3-T37's phase-procedure move the merge request
      additionally lists every divergence found between the orchestrator copy and the phase-skill
      copy with the resolution chosen, and for EDMV3-T46's ladder conversion the merge request shows
      the rule-to-rung mapping.
      Verify: the two MR descriptions contain the divergence table and the mapping table
      respectively, cross-checked at wave close.

### Technical Notes

- AC2 is a licence question, not a style question. If `caveman` or `ponytail` turns out to be
  non-permissively licensed, the clean-room note is the deliverable and no text moves. The plugin is
  MIT (`plugins/edm/.claude-plugin/plugin.json:11`) and ships to other teams.
- This ticket has no dependencies and guards every other requirement in E7. Land it early in wave C
  so the guards are recorded before the edits they guard are reviewed.

### Out of Scope

- Any prompt edit. This ticket records conventions and guards; the edits are T45 through T48.
- Enforcing the before/after convention retroactively on waves A and B. The convention is recorded
  now and the pack already carries the AC on every prompt-text ticket.
