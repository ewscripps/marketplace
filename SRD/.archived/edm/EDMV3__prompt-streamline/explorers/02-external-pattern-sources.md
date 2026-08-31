# Explorer 02 -- External Pattern Sources

**Initiative**: EDMV3 (`edm` / prompt-streamline)
**Focus**: prompt-engineering ideas from external sources that should inform updates to `plugins/edm/` instruction files (`skills/*/SKILL.md`, `agents/*.md`).
**Scope note**: This report is about *instruction design*, not EDM's subject matter. All EDM files were read read-only; nothing was modified.

## Sources consulted

| # | Source | Type | What it contributes |
|---|--------|------|---------------------|
| S1 | `https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5` | Anthropic doc | Verbatim model-specific guidance on verbosity, narration, deliverable length, task scope, over-verification, subagent spawning, self-correction |
| S2 | `https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5` | Anthropic doc | Literal instruction-following, effort calibration, tool-use triggering, code-review-harness recall trap |
| S3 | `/Users/darryl.porter/projects/caveman/skills/caveman/SKILL.md` | Local repo (unrelated domain) | Persistence/anti-drift framing, intensity table, output pattern, auto-clarity carve-out |
| S4 | `/Users/darryl.porter/projects/ponytail/skills/ponytail/SKILL.md` | Local repo (unrelated domain) | Numbered decision ladder, "When NOT to be lazy" carve-out, output pattern, worked examples per intensity |
| S5 | `/Users/darryl.porter/projects/ponytail/ARCHITECTURE.md` Sec.8 (L635-709) | Local repo | "Patterns to follow" / "Anti-patterns to avoid" as a first-class doc section with issue citations |
| S6 | `/Users/darryl.porter/projects/caveman/CONTRIBUTING.md` | Local repo | Source-of-truth vs. build-artifact tables; PR conventions |
| S7 | `/Users/darryl.porter/projects/caveman/skills/cavecrew/SKILL.md` + `/Users/darryl.porter/projects/caveman/agents/cavecrew-investigator.md` | Local repo | Delegation decision table, per-agent output contracts, "What NOT to do" section |

---

## Part A -- Anthropic Opus 5 / Sonnet 5 guidance mapped to EDM

EDM runs almost entirely on `opus` at `effort: high|max` (`plugins/edm/CLAUDE.md:193-203`), so **S1 (Opus 5) is the governing document**. Every behavior S1 says needs tuning is one EDM amplifies: long-horizon, multi-agent, artifact-producing, high-stakes.

### A1. The six Opus 5 behaviors vs. EDM's current posture

| # | Opus 5 behavior | Prescription | EDM today | Delta |
|---|---|---|---|---|
| A1.1 | **Responses run longer than prior Opus** | Prompt for conciseness explicitly; effort controls thinking, not visible length. Pair a long system prompt with a short `<tone_preference>` reminder near the end. | No conversational-length guidance anywhere in `plugins/edm/`. Grep for `concise|verbose|brief|length` yields only `skills/plan/SKILL.md:129` and `agents/edm-explorer.md:63`. | **Gap.** Pure addition, near-zero risk. |
| A1.2 | **Written deliverables run longer** | "Match the length of written documents to what the task needs: cover the substance, but do not pad with filler sections, redundant summaries, or boilerplate." | EDM prescribes length **floors with no ceiling and no anti-padding clause**: `agents/edm-srd-writer.md:37` and `skills/srd/SKILL.md:61` both say "800+ lines major, 200+ focused, 50+ small change". | **Direct tension.** Floor + Opus 5 long-deliverable bias + no anti-padding clause is exactly what the doc warns about. |
| A1.3 | **Narrates readily during agentic work** | Prescribe cadence: one sentence before first tool call; brief update only on important finding or direction change; finish by leading with the outcome. | Nothing. 26 agents, 12 skills, zero communication-cadence guidance. | **Gap.** Highest payoff per line of prompt in the initiative. |
| A1.4 | **Expands task scope / applies own judgment** | "Deliver what was asked, at the scope intended... say so in a sentence and continue with the task as asked rather than quietly narrowing, widening, or transforming it." | Tickets/ACs constrain Phase 6, but nothing constrains the explorer and audit agents -- the widest-mandate roles, all at `effort: max`. | **Gap**, concentrated in `edm-explorer`, the 11 `edm-audit-*` lenses, `edm-audit-synthesizer`. |
| A1.5 | **Over-verification / self-correction** | Remove explicit "double-check", "re-verify", "final verification step", "use a subagent to verify" instructions. | Grep for `double-check|re-?verify|verification step|verify your own|self-verif|check your work|before responding` across `plugins/edm/` returns **zero matches**. EDM's verification is *structural* (independent agents, separate contexts): the `SubagentStop` -> `edm-qc-auditor` hook, Phase 3/5 audits, the lens fleet. | **Already compliant.** See D1 -- must be protected from a naive "remove verification" reading. |
| A1.6 | **Delegates to subagents more readily** | "Delegate only for large tasks that are genuinely independent and parallelizable... If one subagent can complete the task, use one rather than several, and keep spawn counts low." Alternative: "set deterministic caps." | EDM already uses deterministic caps: `skills/audit-tickets/SKILL.md:32` ("exactly 2... never serial, never merged"), `skills/orchestrator/SKILL.md:430` ("2-3"), `skills/implement/SKILL.md:23` ("6-10 per wave"), `skills/orchestrator/SKILL.md:553` ("all 11 lenses"). | **Mostly compliant.** One uncapped site: explorer spawning at `skills/orchestrator/SKILL.md:305` and `skills/plan/SKILL.md:116` -- "parallel if scope spans multiple codebase areas", no cap, no criterion. |

### A2. Sonnet 5 guidance that still applies

`plugins/edm/CLAUDE.md:196-201` puts `edm-implementer`, all 9 `edm-test-*` writers, `edm-test-scaffold`, `push-jira`, `metrics` on `sonnet`/`high`.

| # | Point | Relevance |
|---|---|---|
| A2.1 | **Literal instruction following** -- "It does not silently generalize an instruction from one item to another... state the scope explicitly (for example, 'Apply this formatting to every section, not just the first one')." | EDM templates are single-exemplar and expect generalization (`agents/edm-ticket-writer.md:43-72`; every lens `## Output Format`). Needs explicit "every ticket / every finding, not just the first". |
| A2.2 | **Code-review harness recall trap** -- "Report every issue you find, including ones you are uncertain about or consider low-severity. Do not filter for importance or confidence at this stage - a separate verification step will do that... include your confidence level and an estimated severity so a downstream filter can rank them." (S1 repeats this for Opus 5.) | **Highest-value external finding.** EDM filters twice: every lens has `## False Alarm Filter` (e.g. `agents/edm-audit-logic.md:43-50`) *and* `agents/edm-audit-synthesizer.md:32-41` has `## Second-Pass False Alarm Filter` whose criterion #4 is an explicit low-corroboration filter. That is the "filter at finding stage when a downstream ranking stage exists" anti-pattern. **Mitigating nuance**: the lens filter *demotes* to `## Noted / Not Actionable` rather than deleting, so findings aren't lost -- but the synthesizer's corroboration filter has no confidence signal to rank with. |
| A2.3 | **Positive examples beat negative instructions** | Endorses the caveman/ponytail worked-example technique (B2.4); cautions against expanding `skills/orchestrator/SKILL.md:636-645` (5 negative bullets) without paired positives. |
| A2.4 | **Raise effort rather than prompting around shallow reasoning** | Validates EDM's existing model/effort table. No change. |
| A2.5 | **Remove interim-status scaffolding** ("After every 3 tool calls, summarize progress") | EDM has none. Record as a "do not add" for EDMV3. |

### A3. Verbatim snippets worth lifting

- **Conciseness tail reminder** (S1): `<tone_preference>` / `Keep outputs reasonably concise.` / `</tone_preference>`
- **Written deliverable length** (S1): *"Match the length of written documents to what the task needs: cover the substance, but do not pad with filler sections, redundant summaries, or boilerplate."*
- **Narration cadence** (S1): *"Before your first tool call, say in one sentence what you're about to do. While working, give a brief update only when you find something important or change direction. When you finish, lead with the outcome: your first sentence should answer 'what happened' or 'what did you find,' with supporting detail after it for readers who want it."*
- **Scope discipline** (S1): *"Deliver what was asked, at the scope intended. Make routine judgment calls yourself, and check in only when different readings of the request would lead to materially different work. If the request seems mistaken or a better approach exists, say so in a sentence and continue with the task as asked rather than quietly narrowing, widening, or transforming it."*
- **Subagent discipline** (S1): *"Delegate to a subagent only for large tasks that are genuinely independent and parallelizable... Do not delegate work you can finish yourself in a handful of tool calls, and do not use subagents to verify or double-check your own work. If one subagent can complete the task, use one rather than several, and keep spawn counts low."*
- **Correction narration** (S1): *"Only correct an earlier statement when the error would change the user's code, conclusions, or decisions. State corrections plainly and briefly, then continue the task. For slips that change nothing for the user, make the fix and move on without noting it."*
- **Finding-stage coverage** (S2): *"Report every issue you find... Do not filter for importance or confidence at this stage - a separate verification step will do that... For each finding, include your confidence level and an estimated severity so a downstream filter can rank them."*

---

## Part B -- Instruction-design patterns from caveman & ponytail

Both solve EDM's meta-problem: a long behavioral instruction set that must survive dozens of turns without drift, across many agents, without being re-litigated mid-task. Their SKILL.md files are short (78 and 121 lines) and hold up because of *structure*, not length.

### B1. The shared skeleton (both files, same order)

| Section | caveman `skills/caveman/SKILL.md` | ponytail `skills/ponytail/SKILL.md` | EDM equivalent today |
|---|---|---|---|
| Identity, one line | L11 | L22-24 | Present (`orchestrator/SKILL.md:13`; every agent L13) |
| **Persistence / anti-drift** | L13-17 | L26-30 | **Absent** |
| **Decision ladder** (stop-at-first-rung) | -- | L32-54 | Absent -- EDM has sequential process lists, not ladders |
| Rules (flat bullets) | L19-30 | L56-64 | Present, varies |
| **Output pattern** (one line) | L27 `[thing] [action] [reason]. [next step].` | L75 `[code] -> skipped: [X], add when [Y].` | Present for lenses; **absent** for 9 `edm-test-*` writers, `edm-explorer`, `edm-implementer` |
| **Intensity table** | L32-41 | L77-83 | Analogous `mode`/`lifecycle_mode` matrix, but in `CLAUDE.md:409-423`, not in agent prompts |
| **Worked examples per level** | L43-56 | L85-88 | Sparse -- `agents/edm-ticket-writer.md:73-80` is the only real instance |
| **Carve-out: when NOT to apply** | L58-74 "Auto-Clarity" | L90-112 "When NOT to be lazy" | Partial -- lens `## False Alarm Filter`; one-line N/A carve-outs in test agents (e.g. `agents/edm-test-a11y.md:20`) |
| Boundaries / off-switch | L76-78 | L114-120 | Absent |

### B2. What makes them effective

**B2.1 -- Persistence framing is 2 sentences and does real work.** ponytail L28-30: *"ACTIVE EVERY RESPONSE. No drift back to over-building. Still active if unsure. Off only: 'stop ponytail' / 'normal mode'."* The load-bearing clause is **"Still active if unsure"** -- it pre-resolves the ambiguity case instead of leaving it to per-turn judgment. caveman L15 does the same with **"No revert after many turns"**, naming the specific failure mode (long-session drift).

**B2.2 -- The numbered ladder is a *decision* structure, not a *process* structure.** ponytail L34: *"Stop at the first rung that holds."* Seven yes/no rungs, cheapest-first. EDM's numbered lists are "do 1, then 2, then 3" -- a ladder short-circuits, a process doesn't. Crucially ponytail then **bounds** it (L44-48): *"The ladder is a reflex, not a research project -- but it runs after you understand the problem, not instead of it."* The bound prevents the terse rule from becoming an excuse to skip comprehension.

**B2.3 -- The output pattern appears twice: abstract, then instantiated.** `agents/cavecrew-investigator.md:18-28` goes further with a fenced output contract plus degenerate cases spelled out (`Single hit -> one line, no header. / Zero hits -> 'No match.' / Last line -> totals`). `skills/cavecrew/SKILL.md:34-58` republishes those contracts under `## Output contracts` -- *"What main thread can rely on per agent"*, *"Safe to grep with `path:\d+`"* -- i.e. the contract is declared machine-parseable so the caller can depend on it.

**B2.4 -- Worked before/after in adjacent-line form.** caveman L29-30 is the minimal canonical form: one `Not:` line immediately anchored by one `Yes:` line. This satisfies S2's positive-examples rule while still naming the failure. The multi-level examples (caveman L43-56, ponytail L85-88) show *the same input* rendered at each intensity, teaching the delta rather than the endpoints.

**B2.5 -- The "when NOT to" carve-out is what makes an aggressive instruction safe to ship.** ponytail L90-112 is the longest section in the file -- longer than the ladder: never simplify away input validation at trust boundaries, error handling that prevents data loss, security, accessibility, anything explicitly requested; *"Never lazy about understanding the problem. The ladder shortens the solution, never the reading"*; *"Lazy code without its check is unfinished."* caveman L60-67 does the same for terseness, including the sharpest one -- *"Compression itself creates technical ambiguity"* with a concrete ambiguous string as the example. Both end with "resume after", making the carve-out a local suspension, not a mode exit.

**B2.6 -- Delegation guidance as a decision *table*.** `skills/cavecrew/SKILL.md:16-28` is a 7-row `Task | Use` table that includes rows for **not delegating** ("One-line answer you already know -> Main thread, no subagent") and for **using a different tool than ours** ("Deep code review with rationale + alternatives -> `Code Reviewer` (vanilla)"). Closes with a one-line heuristic (L28) and `## What NOT to do` (L73-78) where each anti-pattern states its concrete cost ("Builder will return `too-big.` and you'll have wasted a turn"). Section L30-32 quantifies the payoff in tokens -- rationale attached to the rule, so the rule survives unanticipated edge cases.

**B2.7 -- Compact mirror of the same instruction set.** `/Users/darryl.porter/projects/ponytail/AGENTS.md` is a 32-line restatement of the 121-line SKILL.md for hosts that read only one markdown file. Same ladder, same carve-outs, compressed. Closing line: *"(Yes, this file also applies to agents working on the ponytail repo itself. Especially to them.)"* -- explicit self-application, which EDMV3 needs since it is EDM applied to EDM.

### B3. Repo-hygiene patterns relevant to EDMV3 execution

**B3.1 -- Source-of-truth vs. build-artifact tables** (`caveman/CONTRIBUTING.md:30-70`). Two tables: "What to edit" mapping *intent -> file* ("I want to change... | Edit this file"), and "What NOT to edit (CI-generated mirrors)" mapping *path -> rebuilt from*, with the closing heuristic (L68-69): *"if the file lives under `plugins/`, `dist/`, or any agent dotdir mirror, it's a build artifact."* EDM has architectural rules in `CLAUDE.md` but no intent->file index -- a contributor wanting to change explorer behavior must guess between `agents/edm-explorer.md`, `skills/plan/SKILL.md:116`, and `skills/orchestrator/SKILL.md:305`, all three of which describe it.

**B3.2 -- CI-verified sync over manual copy-paste** (`ponytail/ARCHITECTURE.md:690-693`): *"Any time content exists in two places... there is a script that asserts they still match. Don't add a third copy of anything without also adding its guard."* Enforced by `/Users/darryl.porter/projects/ponytail/scripts/check-rule-copies.js`. **EDM has this duplication by design**: `plugins/edm/CLAUDE.md:22-23` states *"Skills don't load other skills -- they each contain their own orchestration."* So `skills/orchestrator/SKILL.md:302-409` and `skills/plan/SKILL.md:114-133` are intentional near-duplicates (same for Phases 2-6). Nothing asserts they stay in sync -- and EDMV3, which edits prompt text in both, is precisely the change that will desync them.

**B3.3 -- "Patterns to follow" / "Anti-patterns to avoid" as a named section** (`ponytail/ARCHITECTURE.md:679-709`). Each anti-pattern cites the incident that produced it: *"Don't loosen `RUNTIME_MODES` to include `review`. This was reverted for good reason (#576/#377, see `hooks/ponytail-config.js:79-81`)."* EDM's `skills/orchestrator/SKILL.md:636-645` has the section but no citations and no paired positives.

**B3.4 -- PR convention for prose changes** (`caveman/CONTRIBUTING.md:165`): *"**Show before/after** for prose changes to any `SKILL.md`. One sentence on why the new wording is better."* The single most directly transplantable governance rule for EDMV3, whose entire diff is prose changes to a mature prompt set.

---

## Part C -- Concrete recommendations

Each row: which file, which technique, one sentence why. **R** = regression risk on a mature, already-audited prompt set.

### C1. Additive -- no existing text changes

| # | File | Technique | Why | R |
|---|---|---|---|---|
| C1.1 | `plugins/edm/skills/orchestrator/SKILL.md` -- new `## Communication` section near the top + 3-line `<tone_preference>` after `## Anti-Patterns` (L645) | S1 narration-cadence snippet + S1 long-prompt tail-reminder pattern | Opus 5 narrates and runs long by default, the orchestrator is a 645-line prompt driving hours of agentic work, and the plugin currently says nothing about output cadence. | very low |
| C1.2 | `agents/edm-explorer.md`, `edm-architect.md`, `edm-srd-writer.md`, `edm-ticket-writer.md`, `edm-audit-synthesizer.md`, `edm-qc-auditor.md`, `edm-test-planner.md`, `edm-test-coverage-auditor.md` -- one line in each `## Output` | S1 written-deliverable-length snippet verbatim | These eight write files to disk and Opus 5's documented bias is longer on-disk deliverables with padded sections; one sentence per file is the cheapest possible fix. | very low |
| C1.3 | `agents/edm-explorer.md` + the 11 `edm-audit-*` lenses + `edm-audit-synthesizer.md` -- one `## Scope` line | S1 scope-discipline snippet, trimmed to first and last clauses | These are the widest-mandate agents in the plugin and all run `opus`/`max`, the exact configuration S1 says expands scope and adds unrequested steps. | very low |
| C1.4 | `plugins/edm/CLAUDE.md` -- new subsection under "Model and effort assignments" (L193-203) | "Prompt conventions for opus/high agents" recording C1.1-C1.3 as house style, citing the S1/S2 URLs | Agents added later should inherit the conventions rather than rediscover them, and CLAUDE.md is already the plugin's conventions home. | very low |
| C1.5 | `skills/orchestrator/SKILL.md:305` and `skills/plan/SKILL.md:116` | Deterministic cap on explorer fan-out in S1's form ("one explorer per genuinely distinct codebase area, maximum N; if one can cover the scope, use one") | This is the only uncapped spawn site in the plugin -- every other site names an exact count -- and S1 flags uncapped delegation as Opus 5's most expensive default. | low |
| C1.6 | `agents/edm-implementer.md` + the 9 `edm-test-*` writers | Add `## Output` with a one-line output pattern, mirroring the lens `## Output Format` (`agents/edm-audit-logic.md:52-66`) and `cavecrew-investigator.md:18-28` | These `sonnet` agents return free-form prose into the orchestrator's context, so their tool-results are unbounded and unparseable while every audit agent already has a contract. | low |

### C2. Structural -- edits existing text

| # | File | Technique | Why | R |
|---|---|---|---|---|
| C2.1 | The 11 `agents/edm-audit-*.md` `## Output Format` sections | Add `Confidence: high | medium | low` per finding (S2 snippet) | `agents/edm-audit-synthesizer.md:39` already filters on corroboration but has no confidence signal to rank with, so it is discarding low-corroboration findings blind. | low |
| C2.2 | The 11 `## False Alarm Filter` sections (e.g. `agents/edm-audit-logic.md:43-50`) | Prepend one framing sentence: coverage is the job at the lens stage; the filter *demotes* to `## Noted / Not Actionable`, never deletes; the synthesizer is the ranking stage | S1 and S2 both warn finding-stage filtering suppresses recall on these models; EDM already demotes rather than drops, so this makes an existing safe property explicit rather than changing behavior. | low |
| C2.3 | `agents/edm-srd-writer.md:37` and `skills/srd/SKILL.md:61` | Keep the "800+ / 200+ / 50+" floors, append the S1 anti-padding clause, reframe the floor as a substance signal not a target | A raw line-count floor given to a model with a documented long-deliverable bias and no ceiling is the most likely source of filler in EDM's most-read artifact. | medium |
| C2.4 | `skills/orchestrator/SKILL.md:636-645` `## Anti-Patterns` | Pair each of the 5 negative bullets with the positive behavior and cite the enforcing file/section (S5 pattern, `ponytail/ARCHITECTURE.md:695-709`) | S2 states positive examples outperform negative instructions, and citations make a rule survive edge cases its author didn't anticipate. | low |
| C2.5 | `agents/edm-ticket-writer.md:43-72` and every `## Output Format` template | Add explicit generalization scope -- "apply to every ticket / every finding, not just the first" (S2 literal-instruction-following) | Sonnet 5 and Opus 5 do not silently generalize a template from one exemplar to the rest of a list, and EDM's templates are all single-exemplar. | low |
| C2.6 | `agents/edm-implementer.md` `## Core Rules` (L27-34) | Convert to a numbered stop-at-first-rung ladder (S4, `ponytail/SKILL.md:32-54`) including ponytail's bound clause (runs *after* understanding the ticket, never instead of it) | Implementation decisions are cheapest-first choices (reuse existing helper -> stdlib -> new code), which a ladder encodes and a flat bullet list does not. | medium |
| C2.7 | Every `agents/*.md` | Normalize the one-line "when this agent does NOT apply" carve-out that 6 test agents already have (e.g. `agents/edm-test-a11y.md:20`, `edm-test-contract.md:21`, `edm-test-e2e.md:22`) into a consistent named section across all 26 | Consistency lets the orchestrator rely on a uniform "N/A -- reason" exit token, and S3/S4 both show the carve-out is what makes an aggressive instruction safe. | low |

### C3. Governance for the EDMV3 change itself

| # | Target | Technique | Why |
|---|---|---|---|
| C3.1 | EDMV3 ticket ACs | Adopt `caveman/CONTRIBUTING.md:165` verbatim as a required AC: every prompt-text ticket shows **before/after** plus one sentence on why the new wording is better | The entire initiative is prose edits to an audited prompt set, so diff-with-rationale is the only reviewable artifact. |
| C3.2 | `plugins/edm/bin/` (new check) + `plugins/edm/CLAUDE.md` | Sync-check for the intentionally-duplicated orchestration text between `skills/orchestrator/SKILL.md` and the per-phase skills (S5, `ponytail/scripts/check-rule-copies.js`) | `CLAUDE.md:22-23` mandates the duplication, EDMV3 edits both copies, nothing asserts they still agree, and desync is invisible until a user runs a standalone skill. |
| C3.3 | `plugins/edm/CLAUDE.md` | Intent->file index ("I want to change... | Edit this file"), per `caveman/CONTRIBUTING.md:30-47` | Explorer behavior is described in three files today with no indication which is authoritative. |
| C3.4 | EDMV3 planning | Treat the 26 agents as **families** (11 audit lenses / 9 test writers / 4 writer-auditor pairs / 2 singletons); edit one exemplar per family, then propagate | The lens family is already near-identical (`## What You Hunt For` / `## False Alarm Filter` / `## Output Format` / findings template), so per-family edits are cheaper and less divergence-prone. |

---

## Part D -- Explicitly do NOT adopt (regression guards)

**D1. Do not strip EDM's audit/QC architecture in the name of Opus 5's "over-verification" guidance.** S1 targets *self*-verification ("double-check your answer", "use a subagent to verify **your own work**"). EDM contains none -- grep confirms zero matches for the entire phrase family. EDM's Phase 3/5 audits, the `SubagentStop` -> `edm-qc-auditor` hook (`plugins/edm/CLAUDE.md:393`), and the 11-lens audit are **independent agents auditing a different agent's output in a separate context** -- the writer-verifier pattern S1 explicitly praises. Removing them deletes the methodology.

**D2. Do not reduce the 11-lens or 2-auditor fan-out to "keep spawn counts low."** S1's cap advice targets *ad hoc* delegation; EDM's counts are already deterministic and named (`skills/audit-tickets/SKILL.md:32` mandates exactly 2, "never serial, never merged into one agent") -- which is the mitigation S1 recommends. Lenses are orthogonal by construction; merging re-introduces the single-perspective blind spot they exist to eliminate.

**D3. Do not import caveman's terseness into EDM artifacts.** caveman carves this out itself (`skills/caveman/SKILL.md:76-78`: "Code/commits/PRs: write normal") and its auto-clarity list (L60-67) covers "multi-step sequences where fragment order or omitted conjunctions risk misread" -- which describes every EDM ticket AC and remediation step. Mine caveman for *structure*, never register. SRDs and tickets are read by humans in PRs (`plugins/edm/CLAUDE.md:26-34`).

**D4. Do not add interim-progress scaffolding.** S2: *"If you've added scaffolding to force interim status messages... try removing it."* EDM has none; prescribe cadence (C1.1), not counters.

**D5. Do not add "think step by step" / "reason carefully" / anti-thinking instructions.** S2 says raise effort rather than prompting around shallow reasoning, and EDM already runs `opus`/`max` on every judgment-heavy role. S1 adds that rules telling the model *not* to think increase internal-tag leakage.

**D6. Do not turn EDM's `mode`/`lifecycle_mode` matrix into a caveman/ponytail-style intensity table inside agent prompts.** The intensity table (S3 L32-41, S4 L77-83) is attractive, but EDM's modes are state-backed (`CLAUDE.md:409-423`) and read at runtime via `edm-state`. Duplicating into 26 prompts creates 26 copies to desync -- the exact anti-pattern in `ponytail/ARCHITECTURE.md:697-700` ("Don't hardcode per-mode strings inside adapter code... will drift from every other host"). If a per-agent mode summary is wanted, it belongs in one place with a B3.2 sync guard.

---

## Part E -- Component inventory (external-pattern lens)

| Component | Path | Status | Notes |
|---|---|---|---|
| Orchestrator skill | `plugins/edm/skills/orchestrator/SKILL.md` | Modified | 645 lines; add `## Communication` + tail `<tone_preference>`; cap explorer fan-out (L305); rework `## Anti-Patterns` (L636-645) |
| Phase skills (12) | `plugins/edm/skills/{plan,srd,audit-srd,tickets,audit-tickets,implement,code-audit,test,test-plan,test-coverage,metrics,push-jira}/SKILL.md` | Modified | Concrete edit sites: `plan/SKILL.md:116`, `srd/SKILL.md:61`; rest inherit conventions |
| Audit lens agents (11) | `plugins/edm/agents/edm-audit-{logic,dead-code,edge-cases,test-quality,runtime,docs,consistency,security,spec,dry,wiring}.md` | Modified | Family edit: confidence field + coverage framing; near-identical structure makes one exemplar sufficient |
| Synthesizer | `plugins/edm/agents/edm-audit-synthesizer.md` | Modified | Consumes the new confidence field at L32-41; add deliverable-length line |
| Writer agents (4) | `edm-srd-writer.md`, `edm-ticket-writer.md`, `edm-architect.md`, `edm-test-planner.md` | Modified | Anti-padding clause; template generalization scope |
| Auditor agents (4) | `edm-srd-auditor.md`, `edm-ticket-auditor.md`, `edm-qc-auditor.md`, `edm-test-coverage-auditor.md` | Modified | Same coverage-vs-filter framing as the lenses |
| Explorer | `plugins/edm/agents/edm-explorer.md` | Modified | 64 lines; scope line + deliverable-length line + N/A carve-out |
| Implementer | `plugins/edm/agents/edm-implementer.md` | Modified | `## Core Rules` -> ladder; add `## Output` contract |
| Test writers (9) | `plugins/edm/agents/edm-test-{unit,component,composable,integration,contract,e2e,a11y,scaffold}.md` (+ planner) | Modified | Only have `## Inputs` / `## Process`; add `## Output` contract; normalize existing N/A carve-outs |
| Plugin conventions | `plugins/edm/CLAUDE.md` | Modified | New "Prompt conventions" subsection + intent->file index |
| Duplication sync check | `plugins/edm/bin/` (e.g. `edm-check-skill-sync`) | New | Guards the orchestrator <-> per-phase-skill duplication mandated by `CLAUDE.md:22-23` |

**Rough sizing from this lens alone**: ~50 files touched, 1 new script, 0 new agents. Most edits are 1-3 lines and family-propagatable.

---

## Part F -- Riskiest assumptions

| # | Assumption | Why risky | Cheap validation |
|---|---|---|---|
| F1 | Opus 5 doc guidance applies to Claude Code plugin skills/agents, not just direct API prompts | The doc targets API integrators; Claude Code injects its own system prompt above EDM's text and may already handle narration and length | Run `/edm:plan` on a small initiative before and after C1.1; diff artifact length and turn count |
| F2 | A conciseness instruction won't shorten EDM *artifacts* below required substance | Conciseness and anti-padding are adjacent; a model may apply the conversational rule to `srd.md` | Scope C1.1 explicitly to conversational output and C1.2 explicitly to on-disk files; never state them in the same section |
| F3 | The per-lens `## False Alarm Filter` is actually suppressing real findings | It demotes rather than deletes, so the S2 recall loss may not manifest here | Re-run `/edm:code-audit` on an archived initiative with and without the C2.2 framing; compare `## Noted / Not Actionable` counts vs. promoted findings |
| F4 | The 800+ line SRD floor causes padding rather than preventing thinness | The floor presumably exists because SRDs *were* thin; removing pressure may regress the original problem | Inspect `SRD/.archived/EDMV2/` artifacts for filler sections before touching `edm-srd-writer.md:37`; keep the floor, add only the anti-padding clause |
| F5 | Family-wise lens edits won't break synthesizer parsing | Lens output feeds `edm-audit-synthesizer` and `code-audit/findings-ledger.md` with stable CA-NNN IDs; a new `Confidence:` field changes the finding shape | Update lens + synthesizer in the same ticket; extend C3.2's check to cover the finding-format contract |
| F6 | caveman/ponytail patterns transfer despite being single-agent, single-turn skills | Both are behavioral *modes* over one conversation; EDM is a multi-agent pipeline with file handoffs, so persistence/off-switch framing may not map | Adopt only the four agent-count-agnostic patterns (output contract, decision ladder, carve-out section, worked before/after); skip persistence/off-switch framing -- D6 already skips intensity tables |
| F7 | The orchestrator <-> per-phase-skill duplication is currently in sync | Nothing has ever asserted it; drift may predate EDMV3 | Run the C3.2 check *before* any prompt edits so pre-existing drift isn't attributed to this initiative |

---

## Handoff notes

- **Write access**: this agent role has `disallowedTools: Write, Edit, NotebookEdit` (`plugins/edm/agents/edm-explorer.md` frontmatter), so this report was returned as text and persisted by the orchestrating agent rather than written directly -- see Explorer 01's new finding on this.
- **Single biggest finding**: `plugins/edm/agents/edm-audit-*.md` double-filter against `plugins/edm/agents/edm-audit-synthesizer.md:32-41` -- the pattern both Anthropic docs single out as a recall killer. Mitigated in EDM by demotion-not-deletion, so the fix is a confidence field plus framing, not removing the filter.
- **Second biggest**: zero communication/length calibration anywhere in a 26-agent, all-opus plugin (`plugins/edm/CLAUDE.md:193-203`), against models whose documented default is longer responses, longer deliverables, and heavier narration.
- **Do-not-break list is Part D** -- carry it into the SRD verbatim; it is the main regression surface for a prompt-only initiative.
