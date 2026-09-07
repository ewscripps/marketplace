
# Explorer 03 -- Skills, Agents & Prompt Surface

Scope: `plugins/edm/skills/` (14 skills), `plugins/edm/agents/` (30 agents),
`plugins/edm/docs/canonical-sections.md`. Covers analysis items 4.3, 4.4, 5.1, and EDMV4-T04/D3.

## 0. Repository-state caveat that governs every finding below

The working tree has an **unstaged** edit to `plugins/edm/CLAUDE.md` (per git status at session
start). All reads below are working-tree reads, which is the correct thing to plan against, but
any finding keyed to a specific line number in `CLAUDE.md` should be re-verified against the
committed version before a ticket cites it, since the file is mid-edit.

Separately -- and this **directly answers item 5 below** -- this initiative's own
`SRD/edm/EDMV4__ecc-integration/decisions.md` (D3, D4) already documents that the branch
`edm/edmv4-ecc-integration` was cut from a local `main` 2 commits behind `origin/main`, and that
the D3 defect (below) is fixed upstream at commit `bdec805`/`bdb5698`, released as plugin 3.2.1,
but **not yet present on this branch**. Everything I independently verified from source (Part 5)
is consistent with, and corroborates, D3/D4's account. I did not re-litigate the decision; I
verified the artifacts it cites.

---

## 1. Item 4.4 -- L12/L13/L14 lens additions: the "eleven" load-bearing inventory

### 1.1 Exhaustive `file:line` table of every hardcoded "eleven"/"L1..L11" touch point

This table is the ticket scope for 4.4. Grouped by file, in the order a contributor would need to
touch them.

| # | File | Line(s) | What it hardcodes | Must change for L12-14? |
|---|---|---|---|---|
| 1 | `bin/edm-state` | 1613 | `ALL_LENS_IDS="L1 L2 L3 L4 L5 L6 L7 L8 L9 L10 L11"` -- single source of the lens ID set | **Yes** -- append `L12 L13 L14` |
| 2 | `bin/edm-state` | 1615 | `[[ ... -eq 11 ]] || die "internal: ALL_LENS_IDS must enumerate exactly 11 lenses"` -- a self-check that hardcodes the count `11` in the error text too | **Yes** -- becomes 14 (or a conditional count if L13 is stack-conditional, see 1.3) |
| 3 | `bin/edm-state` | 1608 | Comment: "the eleven canonical code-audit lens IDs, single source (EDMV3-T27 ...)" | Yes (comment) |
| 4 | `bin/edm-state` | 3632 | `echo "... round_type full = all 11 lenses)"` -- CLI help/report text | Yes |
| 5 | `bin/edm-state` | 4508-4510 | Comment above `cmd_audit_round_start`: "full when all eleven ... ('absence of --lenses means run all 11' convention)" | Yes |
| 6 | `bin/edm-state` | 4555, 4567-4571 | `_cmd_audit_round_start` body: `all_sorted="$(printf '%s\n' $ALL_LENS_IDS | sort ...)"` compares the caller's `--lenses` set against `ALL_LENS_IDS` to derive `round_type=full` vs `partial` | **Yes, mechanically** -- this is the actual `round_type` derivation the analysis calls out; it reads `ALL_LENS_IDS` so item 1's edit auto-propagates here, but the *comment* at 4508-4510 needs a manual update |
| 7 | `bin/edm-state` | 4619 | Comment recounting a past incident: "own EDMV3 initiative shipped eleven prose reports and ZERO JSONL files" | No (historical, do not touch) |
| 8 | `bin/edm-state` | 4827 | `echo "... run a full (eleven-lens) code-audit round before checking convergence"` -- user-facing error text in `cmd_audit_converged` | Yes |
| 9 | `bin/edm-state` | 2390 | Comment near `--accept-p2-debt`: "does NOT imply 'a full eleven-lens round was run'" | No (describes an invariant, still true at 14) but should be re-read for correctness once the count changes |
| 10 | `skills/code-audit/SKILL.md` | 3 (frontmatter `description`) | "11 parallel orthogonal audit agents (logic, dead code, edge cases, tests, hygiene, docs, consistency, security, spec, DRY, wiring)" | **Yes** |
| 11 | `skills/code-audit/SKILL.md` | 24 | Prose: "Eleven auditors with orthogonal mandates" | Yes |
| 12 | `skills/code-audit/SKILL.md` | 37 | Step 1: "Validate lens tokens against L1-L11; reject unknown tokens" | **Yes** -- validation range |
| 13 | `skills/code-audit/SKILL.md` | 38-40 | Step 1: "If `--lenses` is omitted, run all 11 (full round)"; `ROUND_TYPE` = full (11 lenses) / partial | **Yes** |
| 14 | `skills/code-audit/SKILL.md` | 57, 60 | Step 4 prose repeating "eleven members means full" / "all eleven explicitly" | Yes |
| 15 | `skills/code-audit/SKILL.md` | 95-96 | Step 8a content-check prose: "the count check above cannot distinguish eleven correctly-schema'd files from eleven files carrying an invented schema" | Yes (prose only; logic is count-agnostic) |
| 16 | `skills/code-audit/SKILL.md` | 250 | `## The 11 Audit Lenses` heading | **Yes** -- heading + table needs 3 new rows |
| 17 | `skills/code-audit/SKILL.md` | 252-264 | The lens table itself (`edm-audit-logic` .. `edm-audit-wiring`, L1-L11) | **Yes** -- add 3 rows |
| 18 | `skills/code-audit/SKILL.md` | 273-274, 290, 298 | Smoke-Audit-vs-Full-Round table and prose: "Full round (11 lenses)", "run the full eleven regardless", "one full eleven-lens round" | Yes |
| 19 | `skills/code-audit/SKILL.md` | 373 | Synthesizer launch prompt: "If this is a partial round (fewer than 11 lenses)" | Yes |
| 20 | `skills/code-audit/SKILL.md` | 524 | `## What Single-Pass Audits Miss (Why 11 Lenses)` heading | Yes |
| 21 | `agents/edm-audit-synthesizer.md` | 24 | "The round type (full: 11 lenses, or partial: subset) from `lenses-run.txt`" | Yes |
| 22 | `CLAUDE.md` | 211 | Agent color table: "`cyan` \| all 11 `edm-audit-*` lenses + `edm-audit-synthesizer`" | **Yes** |
| 23 | `CLAUDE.md` | 250 | "not itself require that a full eleven-lens round was ever recorded (CA-426)" | Yes (prose) |
| 24 | `CLAUDE.md` | 292, `docs/canonical-sections.md`:88 | "referenced by name from the eleven touch points inventoried in `architecture.md`" -- **this is the Mermaid-convention touch-point count, a DIFFERENT "eleven" than the lens count**, do not conflate the two when editing | No -- unrelated eleven, but a careless find-replace on this file would corrupt it |
| 25 | `CLAUDE.md` | 333 | "`agents/edm-audit-synthesizer.md`, `agents/edm-srd-auditor.md`, and all eleven `agents/edm-audit-*.md` lens definitions" (D34 passage, EDMV4-T04's own home paragraph) | **Yes** |
| 26 | `CLAUDE.md` | 423 | D2 do-NOT-adopt guard: "Do not reduce the 11-lens or 2-auditor fan-out to keep spawn counts low" | Prose only, but see 1.4's D2 conflict note below |
| 27 | `CLAUDE.md` | 1000 | "the 11-lens code-audit methodology audits the plugin's own bin/ scripts..." | Yes |
| 28 | `.claude-plugin/plugin.json` | 5 | Manifest `description`: "...and 11-lens code audit." | **Yes** -- user-facing marketplace listing |
| 29 | `README.md` | 123, 265, 268 | User-facing table + prose: "11-lens exhaustive audit", "does not have to be the full eleven lenses", "Reserve the full eleven-lens round" | **Yes** |
| 30 | `skills/implement/SKILL.md` | 48, 241 | "remind the user about `/edm:code-audit <PREFIX>` for the 11-lens audit"; "recommend the user run `/edm:code-audit <PREFIX>` for the 11-lens exhaustive audit" | Yes |
| 31 | `bin/edm-check-grants` | 11 | Comment: "a 'grep every agents/*.md' check passes green while eleven ..." | Likely no (describes the check's own rationale, not a lens count assertion -- verify at edit time) |
| 32 | `evals/README.md` | 306 | "agents (the eleven code-audit lenses, `edm-audit-synthesizer`, `edm-srd-auditor`, ...)" | Yes |
| 33 | `docs/audit-patterns/README.md` | 137 | Table row: "11-lens code audit \| EDMV2 seed" | Yes (or leave as historical seed-date row -- judgment call at edit time) |
| 34 | `docs/audit-patterns/code-audit.md` | (present in grep hit list, not line-inspected) | Contains `CA-440`/`CA-473`/`CA-515` references, likely lens-count-adjacent prose | Check at edit time |
| 35 | `bin/tests/fixtures/code-audit/README.md` | 33 | "`lenses-run.txt` -- the eleven lens IDs, one per line" | **Yes** -- test fixture must grow to 14 |
| 36 | `bin/tests/wave6-smoke.sh` | 3440, 3445-3448 | T27 AC1 test: "3-of-11 lens round"; `--lenses L1,...,L11` literal full-round invocation; `round_type == "full"` assertion | **Yes** -- this test will start FAILING the moment `ALL_LENS_IDS` grows, because it explicitly lists all eleven and expects the comparison to still read `full` -- with 14 real lenses this input is now a **partial** (11-of-14) round, silently inverting the test's own claim |
| 37 | `bin/tests/wave7-smoke.sh` | 480, 1473, 1582, 1591, 1593, 1627, 1630, 1650, 1656-1657, 1660, 1666-1667, 1673, 1722-1723, 1732-1733, 1736, 1745-1746, 1798, 1902, 1911-1912, 2153, 2272, 2283, 4756, 4762, 4902, 5417, 5419, 7565-7566 | **~28 separate hardcoded `-eq 11` assertions** across T24 (AC0/AC1/AC2/AC4/AC5/AC6/AC8), T25 AC8, T42 AC10, T46 AC2, T47 AC6, T48 AC6 -- every one of these counts `agents/edm-audit-*.md` files or greps a fixed-count pattern and asserts the literal integer `11` | **Yes -- this is the largest single blast radius of 4.4.** Every one of these ~28 assertions must become `14` (or a computed `$(ls agents/edm-audit-*.md | wc -l)`-style count) or the smoke suite fails green-for-the-wrong-reason the moment two new lens agent files exist, even before their prompts are correct |
| 38 | `CHANGELOG.md` | 13, 73, 93, 128, 174, 333, 494, 497, 532, 555, 564, 594, 617, 1090 | Historical entries mentioning "eleven"/"11-lens" | **No** -- CHANGELOG is a historical record; do not retroactively edit past entries. A NEW entry documenting the 11->14 change is the correct addition |

**Why item 37 (wave7-smoke.sh) is the item most likely to be under-scoped if a ticket writer only
reads the analysis document's own inventory.** The analysis names `skills/code-audit/SKILL.md`,
`bin/edm-state`, `CLAUDE.md`, and `agents/edm-audit-synthesizer.md` explicitly, but does not
mention the test suite at all. `bin/tests/wave7-smoke.sh` alone carries roughly 28 separate
`-eq 11` (or equivalent) assertions verifying "eleven lens files carry X" for seven different
regression classes (T24, T25, T42, T46, T47, T48). None of these are cosmetic -- T47 AC6 and T48
AC6 in particular are explicitly named "lens cap surviving unchanged" / "lens fan-out unchanged:
eleven lenses, none merged or removed" (`wave7-smoke.sh:4902,5417`), i.e. **tests that currently
exist specifically to assert the count never changes**. A ticket for 4.4 must include rewriting
or retiring these two assertions as a first-class AC, not as an afterthought discovered mid-audit.

### 1.2 House style a new lens agent must match (from `edm-audit-logic.md` L1 and `edm-audit-security.md` L8, read in full)

Both files are ~115-204 lines. Structural contract, present in both, that a new L12/L13/L14
prompt must replicate exactly:

1. **Frontmatter** (`edm-audit-logic.md:1-14`, `edm-audit-security.md:1-11`):
   `name: edm-audit-{lens-name}`, a YAML block-scalar `description:` naming the lens number and
   what it hunts, `tools: Glob, Grep, LS, Read, NotebookRead, WebFetch, TodoWrite, WebSearch,
   Write` (identical set across both), `model: opus`, `effort: max`, `maxTurns: 30`,
   `color: cyan`, `disallowedTools: Edit, NotebookEdit`. This tool grant is **structurally
   read-only apart from Write** -- a new lens must not be granted `Edit`/`NotebookEdit`.
2. **Opening frame**: `"You are executing **EDM Code Audit Lens L{N}: {Name}**."` followed
   immediately by `"Your mandate is ONLY this lens. Do not audit other dimensions -- other agents
   handle those."`
3. **`## Scope`** section: the verbatim "deliver what was asked at the scope intended..." house
   scope-statement paragraph (identical text in every lens agent read).
4. **`## What You Hunt For`**: bolded sub-headings, bullet lists of concrete patterns. L8's
   security lens additionally cross-walks every category against an OWASP Top 10:2025 label --
   this is lens-specific content, not part of the house contract.
5. **`## False Alarm Filter`**: identical framing sentence in both files verbatim ("Report every
   finding at your best-effort confidence level rather than self-suppressing on uncertainty: this
   filter demotes a finding to `## Noted / Not Actionable`..."), followed by exactly **three**
   numbered criteria specific to the lens. `bin/tests/wave7-smoke.sh:1902-1912` (T25 AC8) is a
   smoke test asserting this exact framing sentence appears in all eleven lens files with exactly
   three criteria each -- **a new lens agent must be added to this assertion's file set or the
   test's `-eq 11` count check (item 37 above) will simply never see it**.
6. **`## Output`**: "You have exactly two permitted write paths, both inside the current pass
   directory" followed by `${OUTPUT_DIR}/lens-L{N}.md` and `${OUTPUT_DIR}/lens-L{N}.jsonl`, the
   ASCII-only reminder, the `mkdir -p` rationale for why `Write` is granted without
   `Bash(mkdir *)`, and the "JSONL file is authoritative on conflict" sentence -- word-for-word
   identical modulo the lens ID.
7. **`## Output Format`**: severity-scale reference sentence naming
   `CLAUDE.md Sec."Severity vocabulary"` **plus** the `Read docs/canonical-sections.md` anchoring
   instruction (the D34 addition -- see Part 3 below) -- present verbatim in both files read, then
   a markdown table template with a `## Findings` and `## Noted / Not Actionable` section.
8. **`## JSONL Line Format`**: restates the fixed schema literally
   (`{"schema":1,"id":null,"lens":"L{N}",...}`), the D22/CA-130 stale-cache fallback clause, and
   five bulleted field rules (`id`, `round`/`round_type`, `sev`, `confidence`, `status`) --
   identical wording modulo the lens ID substitution. Ends with the "Residual risk" paragraph
   about JSONL/prose count-vs-content mismatch, stated identically in both files (and per that
   paragraph, also restated once in `architecture.md`, so a new lens agent's residual-risk
   paragraph should be cross-referenced there too).
9. **`## When this does NOT apply`**: both lenses read use the identical "always applies once the
   code-audit skill selects lens L{N} for the round; lens selection ... is decided by
   `skills/code-audit/SKILL.md`, not by this agent" sentence.

**Length calibration**: L1 is 115 lines, L8 is 204 lines (L8 is longer purely because its "What
You Hunt For" section has nine OWASP-mapped sub-categories vs L1's three). A new lens's length
should scale with the number of hunt categories it needs, not target either file's line count.

### 1.3 Precedent for stack-conditional lens behavior (L13 Type Design)

The analysis states "EDM's mode matrix already has precedent for stack-conditional behaviour" but
also flags the test layer's N/A logic as possibly closer. Having read both, **the test layer is
the correct and closer precedent; the mode matrix is not actually stack-conditional in the same
sense**:

- The **mode matrix** (`CLAUDE.md` "EDM mode matrix" section) is a *user-selected enum*
  (`mode=iac`, `mode=data-ml`, etc.) that changes which phase skills run and what vocabulary they
  use. It is not automatically derived from the target codebase's language/type system -- a human
  picks it at Step 1c. This is a poor fit for L13, whose applicability should be *detected*, not
  chosen by the user launching a code-audit round.
- The **test layer's N/A logic** (`agents/edm-test-integration.md:21-25, 100-116`, and the
  parallel N/A carve-outs documented in `CLAUDE.md`'s "Layers that are N/A" section) is a much
  closer structural match: a single authority (`edm-test-planner`) determines applicability once,
  every consumer agent's own N/A exit must *agree* with that determination rather than
  self-declare independently ("this carve-out is sanctioned by `edm-test-planner.md`'s
  N/A-assignment enumeration ... a mismatch between this agent's exit and the planner's assignment
  for the same epic is a contract violation" -- `edm-test-integration.md:22-25`), N/A is
  recomputed every run rather than inherited, and absence of a coverage row is authoritative (no
  placeholder file/row is written). This is exactly the shape L13 needs: **the code-audit skill's
  Step 1 (where `LENS_SET` is computed) would need a stack-detection step that determines whether
  L13 applies**, and `edm-audit-type-design` (or whatever it is named) would carry the identical
  "N/A -- no typed stack detected" exit token and identical language to the test agents', not
  invent its own.
- **Caution**: unlike the test layer, code-audit's lens selection today has exactly one input
  mechanism -- the human-supplied `--lenses` flag (Section 1's Step 1). Introducing an
  *automatically computed* N/A for one lens inside a round that is otherwise "run all 14" is a new
  kind of round-composition logic that does not exist today; `ALL_LENS_IDS` and the
  full-vs-partial derivation (item 6 above) currently only understand "the caller passed a subset"
  as the reason a round is partial. If L13 auto-excludes itself on an untyped stack, that round
  would need to still read as `full` despite running only 13 of 14 lenses -- a case the current
  `round_type` derivation (comparing the run set against `ALL_LENS_IDS`) does not have a concept
  for and would need new logic to distinguish "auto-N/A'd lens" from "operator-requested partial
  scope." This is a real design gap in the analysis's "add as lenses" recommendation, not just an
  implementation detail.

### 1.4 D2 guard tension

CLAUDE.md's do-NOT-adopt guard **D2** ("Do not reduce the 11-lens or 2-auditor fan-out to keep
spawn counts low... The cost of ignoring this is coverage loss disguised as an efficiency gain")
is about *reducing* fan-out, not increasing it -- 4.4 adds lenses, so it does not violate D2 on
its face. But the analysis's own "Risk" note for 4.4 ("more lenses means more audit cost per
round... Measure with `/edm:metrics` before making all three unconditional") is in tension with
D2's spirit if it is read as license to make L13 conditional for cost reasons. Section 1.3 above
resolves this: L13's conditionality must be justified as **inapplicability** (untyped stacks have
no type-design lens to run), the same rationale the test layer already uses for N/A carve-outs --
never as a cost-driven exclusion of an applicable lens, which is exactly the D2 regression the
guard exists to prevent.

---

## 2. Item 4.3 -- size classifier at the orchestrator front door

`skills/orchestrator/SKILL.md` Step 1c (`orchestrator/SKILL.md:103-114`), read in full:

```
**Step 1c -- Mode and profile selection**
Skipped on resume (Step 1b already read a recorded non-default mode).
1. `AskUserQuestion` header `"EDM mode"` (<=12 chars): Standard (Recommended) / mini-SRD /
   IaC / Data/ML / Prototype.
2. Present a compliance toggle via `AskUserQuestion` header `"Compliance"`: Off (Recommended) / On.
3. Record: `edm-state set-mode <PREFIX> mode <value>`; ... compliance_enabled true (only if On).
4. Mode-family fields ... are `CLAUDE.md Sec."EDM mode matrix"` -- consult before dispatching;
   do not restate the sub-flows here.
```

**Insertion point**: a classifier step would sit as new **Step 1b.5 or 1c.0**, immediately after
prefix/product resolution (Step 1b) and before the existing `AskUserQuestion` mode dialog (Step
1c.1). The recommendation in the analysis ("pre-select a recommendation... that the user confirms
or overrides") maps cleanly onto `AskUserQuestion`'s existing mechanics: EDM's dialogs already
support a "(Recommended)" annotation on one option (see Step 1c.1's "Standard (Recommended)" and
1c.2's "Off (Recommended)") -- the classifier's job is to compute *which* option gets that
annotation and to state the one-line reasoning in the question body, not to add a new UI
mechanism.

**Mapping the analysis's four tiers onto EDM's real enums.** EDM has two independent enum
families (`CLAUDE.md` "`.edm-state.json` mode-family fields" table, and `MODE_ENUM_LIST`/
`LIFECYCLE_MODE_ENUM_LIST` in `bin/edm-state:807-808`):

- `mode` (5 values): `standard`, `mini-srd`, `iac`, `data-ml`, `prototype`
- `lifecycle_mode` (3 values): `standard`, `fast-track`, `fix-pack`

These are **orthogonal** (`CLAUDE.md`: "an initiative can be `mode=iac` AND
`lifecycle_mode=fast-track` simultaneously"). The analysis's four-tier scheme
(trivial/small/standard/large) does not cleanly bijection onto either enum alone, and the
analysis's own suggested mapping ("trivial/small -> `lifecycle_mode=fix-pack`, standard ->
`mode=mini-srd`, large -> full `standard`") mixes the two families inside one tier list. A
concrete ticket needs to decide, explicitly, a two-axis mapping:

| Tier | `lifecycle_mode` | `mode` | Rationale |
|---|---|---|---|
| trivial | `fix-pack` | (n/a -- fix-pack skips SRD/tickets audit) | Matches "Tickets generated directly from an analysis document" behavior already documented under `lifecycle_mode` in the mode matrix |
| small | `fast-track` or `fix-pack` | (n/a, same reason) | The two `lifecycle_mode` values are currently documented as behaviorally identical ("`fast-track` / `fix-pack`" share one row in the mode matrix table) -- a classifier cannot distinguish them without EDM first splitting that row, which is out of this ticket's scope unless taken up explicitly |
| standard | `standard` | `mini-srd` | Analysis's own suggestion |
| large | `standard` | `standard` | Full six-phase flow |

**Where the enums are validated, so a mapping cannot silently drift**: `bin/edm-state:5063-5114`
(`cmd_set_mode`) is the single write path for both families. It validates `mode` against
`MODE_ENUM_LIST` (`bin/edm-state:5071-5074`, a word-membership test, not a re-declared case list
per the EDMV3-T07 AC5 comment) and `lifecycle_mode` against `LIFECYCLE_MODE_ENUM_LIST`
(`:5093-5096`) identically. Any classifier-authored value that is not one of the five/three
canonical strings is hard-refused by `die "set-mode: invalid mode '$value' ..."` -- so a
classifier ticket cannot introduce a fifth "tier" value that doesn't already exist in
`MODE_ENUM_LIST`/`LIFECYCLE_MODE_ENUM_LIST` without a separate, larger change to `bin/edm-state`
(`terminal_phase_for_mode` at `:839-847`, `code_audit_required_for_mode` at `:952-958`, and
`convergence_exempt` at `:987-998` would all need new arms too). **This is a hard backstop: the
classifier can only ever recommend one of the eight enum values that already exist**, which
closes off any temptation to invent a bespoke "trivial" state distinct from `fix-pack`.

**D6 guard applies directly here.** CLAUDE.md's do-NOT-adopt guard D6 ("Do not duplicate the mode
matrix into agent prompts, since it is state-backed and read at runtime") means the classifier's
Step 1c.0 prose must **compute a recommendation and cite the mode matrix by section reference**,
never restate what each mode/lifecycle_mode value does -- Step 1c.4 already models the correct
pattern ("consult it before dispatching; do not restate the sub-flows here"). A classifier ticket
that inlines a description of what `fix-pack` or `mini-srd` do (even briefly, to justify the
recommendation) would violate D6.

**Compliance/security-trigger tie-breaker composability.** The analysis proposes adopting ECC's
security-trigger tie-breaker ("anything touching a security trigger... is at least standard") and
states it "composes cleanly with EDM's existing `compliance_enabled` Gate 3.5." Verified: Step
1c.2 already presents an independent `AskUserQuestion` for `compliance_enabled`, so a
classifier-computed tie-breaker recommendation would need to pre-select **On** for that dialog
too, not just the mode dialog -- a second `AskUserQuestion` outcome the analysis's one-paragraph
treatment doesn't separately account for.

---

## 3. Item 5.1 -- closing the implementer/QC loop

### 3.1 How QC triggers today

`hooks/hooks.json:111-117` -- `SubagentStop` matcher `"edm-implementer"`. Per
`CLAUDE.md`'s "Hooks behavior" table and `skills/implement/SKILL.md` Step 4 (`:75-127`), the hook
auto-spawns `edm-qc-auditor` after every `edm-implementer` finishes.

### 3.2 Verdict-shard naming (CA-440/CA-473/CA-515)

Two **disjoint** namespaces, both documented identically in `skills/implement/SKILL.md:80-98` and
`agents/edm-qc-auditor.md:79-85`:

- **Hook-spawned** (per-implementer): `qc/qc-shard-impl-{NN}.md`, `{NN}` = lowest ticket number in
  the implementer's range, zero-padded. Exists to fix **CA-440**: concurrent auditors finishing at
  the same time and all writing to `qc-summary.md` directly would silently overwrite each other's
  FAIL verdicts.
- **Threshold-shard** (`/edm:implement`'s own post-wave QC, `qc_shard_threshold` default 20,
  `implement/SKILL.md:100-127`): `qc/qc-shard-pass-w{WW}-{NN}.md`, `{WW}` = 1-based wave number,
  `{NN}` = 1-based shard ordinal *within that wave*. The wave component fixes **CA-515**: an
  ordinal-only name would collide across waves the moment two different waves each produce a
  single shard 1.
- **CA-473** is the reason the two prefixes (`qc-shard-impl-` vs `qc-shard-pass-`) must never
  overlap: a bare `qc-shard-{NN}.md` key space would let threshold shard 1 clobber the
  implementer shard whose range starts at T01.
- Both are merged into `qc/qc-summary.md` by `/edm:implement` itself after each wave drains
  (`implement/SKILL.md:39, :96-98`) -- **never** written by any `edm-qc-auditor` instance directly.

### 3.3 What happens today on FAIL vs. PARTIAL

- **FAIL** (`implement/SKILL.md` Step 5, `:140-150`, and Operational Orchestration step 8,
  `:40`): "Remediate any FAIL QC findings, at every severity: spawn `edm-implementer` agents to
  fix; re-trigger QC." This is a **manual, unbounded, human-supervised loop** today -- there is no
  iteration counter, no cost ceiling, and no automatic escalation-to-human after N attempts. The
  orchestrator (a human-in-the-loop conversation) decides when to stop retrying.
- **PARTIAL** (`implement/SKILL.md` Step 5 item 2, `:143-146`, and Step 8): persisted via
  `edm-state record-partial-verdict <PREFIX> <ticket> PARTIAL '<note>'`, then **closed later**, not
  during Phase 6 proper, by the mandatory `/edm:verify-runtime` step before archive -- which
  records exactly one of two closing verdicts, PASS or FAIL (`CLAUDE.md` "Unverifiable acceptance
  criteria (D15)" section; `edm-qc-auditor.md:36-40`). This is the "hand-cranked version of an
  iteration" the analysis names.

### 3.4 State fields that already exist for iteration, vs. what would be new

Read at `bin/edm-state:4936-5038` (`cmd_record_partial_verdict`, both the open-record and
`close` sub-paths):

- **Already exists**: `closure_history` (`bin/edm-state:4978`) -- an array field populated on
  **re-closure** of a previously-closed PARTIAL: `.closure_history = ((.closure_history //
  [{closing_verdict:..., closed_at:..., verification_ref:...}]) + [{new entry}])`. This means a
  FAIL-then-later-fixed PARTIAL keeps its full history, not just its latest state.
- **Already exists**: the `prior` preservation pattern is referenced by
  `CLAUDE.md`'s state-field table row for `partial_verdict_map.<ticket>.closing_verdict`: "The
  entire pre-closure entry is preserved under `prior` rather than overwritten, and a re-closure
  appends to `closure_history` so the FAIL record is never lost." (I could not find a `prior` key
  literal in the `_cmd_record_partial_verdict_close_body` jq expression at
  `bin/edm-state:4949-4990` in the excerpt read -- **this is a claim from CLAUDE.md's own state
  table that I was not able to independently re-derive line-by-line from the jq body in the
  section read; flagging as unverified against source rather than asserting it as confirmed.**)
- **Does NOT exist today**: any iteration counter, attempt cap, or "rounds remediated" field
  scoped to a *FAIL* verdict the way `closure_history` is scoped to a *PARTIAL* closure. FAIL
  remediation today produces new commits and a re-run QC verdict, but nothing in
  `.edm-state.json` records "this ticket was auto-remediated N times" -- a bounded loop (5.1's
  recommendation) would need a **new** counter, most naturally living beside
  `partial_verdict_map` or as a new top-level `remediation_attempts.<ticket>` map, since
  `closure_history`'s shape (verdict/timestamp/ref triples) is PARTIAL-closure-specific and not a
  drop-in fit for "FAIL -> respawn -> re-QC" cycles.

### 3.5 Cost instrumentation a bounded loop would need to bound itself against

Already exists, per `CLAUDE.md`'s "Cost tracking" section (verified against source there, not
re-derived independently in this file):

- **Per-phase**: `phase_durations[N_phase]` carries `tokens.{input,output,cache_read,
  cache_write_5m,cache_write_1h}`, `model_used`, `estimated_cost_usd`, `attribution_mode`
  (`scoped`/`whole-directory`), `unparseable_lines`. Phase 6 (implementation) is one such phase --
  so today's cost figure for "all of Phase 6" already exists, but it is **not decomposed** by
  implementer-wave or by remediation-cycle-within-Phase-6; a FAIL-remediation loop running inside
  Phase 6 would be invisible as a separate cost line inside the existing `phase_durations[6]`
  entry.
- **Per-audit-round**: `audit_rounds.<type>.rounds[].{completed_at, duration_seconds, tokens,
  model_used, estimated_cost_usd, attribution_mode}` (EDMV3-T51) gives the same shape for
  code-audit rounds specifically.
- **What is missing for a bounded loop specifically**: neither of the above is scoped to a single
  QC-verdict-to-remediation cycle. A cost ceiling designed "before anything is built" (the
  analysis's explicit precondition) would need a new attribution unit -- most naturally a
  per-remediation-attempt token/cost record, keyed by ticket and attempt number, using the same
  `get_session_tokens_since`/`compute_cost_usd` pair the two mechanisms above already share (per
  `CLAUDE.md`: "computed with the same ... pair `phase-complete` uses, so audit-round cost can
  never diverge from phase cost via a second implementation" -- the analogous invariant a
  remediation-loop cost field would need to preserve is "loop cost can never diverge from Phase 6
  cost via a second implementation").

### 3.6 Where the loop would insert

`implement/SKILL.md` Operational Orchestration step 8 (`:40`, "Remediate any FAIL QC findings...")
is the exact insertion point: a bounded loop replaces the current unbounded
"spawn-to-fix-then-re-trigger" prose with an explicit `for attempt in 1..N` structure, each
iteration writing an attempt record (3.4), checking against a cost ceiling (3.5) and the
configurable `GAN_PASS_THRESHOLD`-equivalent EDM does not yet have, and falling through to a human
escalation (an `AskUserQuestion` gate, following the canonical Gate PROTOCOL in
`skills/orchestrator/SKILL.md`) when the cap is hit. This is squarely a Phase 6 change, not an
orchestrator-dispatcher change, since Phase 6's whole procedure already lives in
`implement/SKILL.md` alone per the intent-to-file index (`CLAUDE.md` "Intent-to-file index" table:
"What a phase does, step by step" -> `skills/{phase}/SKILL.md`).

---

## 4. EDMV4-T04 -- by-name reference anchoring, verified against the tree

### 4.1 The verified current set is LARGER than CLAUDE.md's own eight-file list

Grepping `CLAUDE.md Sec\.` across `skills/` and `agents/` and subtracting the files that already
carry a `docs/canonical-sections.md`/`canonical-sections` anchor:

**Agents carrying a bare `CLAUDE.md Sec."..."` reference with NO canonical-sections anchor (5,
not 4):**

| File | Bare reference(s) | In CLAUDE.md's named EDMV4-T04 list? |
|---|---|---|
| `agents/edm-architect.md:31, 89` | `CLAUDE.md Sec."Mermaid diagram conventions"` (x2) | Yes |
| `agents/edm-srd-writer.md` | (present in grep hit set; not individually excerpted here) | Yes |
| `agents/edm-ticket-writer.md` | (present in grep hit set) | Yes |
| `agents/edm-ticket-auditor.md` | (present in grep hit set) | Yes |
| `agents/edm-qc-auditor.md:39, 70` | `CLAUDE.md Sec."Unverifiable acceptance criteria (D15)"`, `CLAUDE.md Sec."Severity vocabulary"` | **No -- not in CLAUDE.md's named list of eight.** This is a real, additional touch point the T04 scope note misses |

**Skills carrying a bare `CLAUDE.md Sec."..."` reference with NO canonical-sections anchor (9, not
4):**

| File | In CLAUDE.md's named EDMV4-T04 list? |
|---|---|
| `skills/srd/SKILL.md` | Yes |
| `skills/tickets/SKILL.md` | Yes |
| `skills/audit-srd/SKILL.md` | Yes |
| `skills/audit-tickets/SKILL.md` | Yes |
| `skills/verify-runtime/SKILL.md` | **No** |
| `skills/push-jira/SKILL.md` | **No** |
| `skills/orchestrator/SKILL.md` | **No** (references `CLAUDE.md Sec."Skill-tool composition"`, `Sec."Project artifact layout"`, `Sec."Phase Timing Guidelines"`, `Sec."EDM mode matrix"`, multiple times) |
| `skills/metrics/SKILL.md` | **No** |
| `skills/code-audit/SKILL.md` | **No** (references `CLAUDE.md Sec."Severity vocabulary"` at line 389, despite its own lens/synthesizer consumers being anchored) |

**Net finding**: the real, currently-unanchored set is **5 agents + 9 skills = 14 files**, not the
8 CLAUDE.md itself names. The 6 additional files (`edm-qc-auditor.md`, `verify-runtime/SKILL.md`,
`push-jira/SKILL.md`, `orchestrator/SKILL.md`, `metrics/SKILL.md`, `code-audit/SKILL.md`) carry
the identical unresolvable-reference defect D22 describes, but were not swept into either the D34
remediation (13 files) or CLAUDE.md's own EDMV4-T04 scope note (8 files). A ticket that scopes
itself strictly to CLAUDE.md's named eight will under-deliver relative to what "close the ordering
gap" actually requires.

**A second, distinct gap inside the 6 additional files**: `agents/edm-qc-auditor.md:39` references
`CLAUDE.md Sec."Unverifiable acceptance criteria (D15)"` -- but `docs/canonical-sections.md` (read
in full) contains **only two** generated sections, "Severity vocabulary" and "Mermaid diagram
conventions." There is no canonical-sections entry for "Unverifiable acceptance criteria (D15)"
at all. Anchoring `edm-qc-auditor.md` the same way the 13 lens/synthesizer files were anchored
(pointing at `docs/canonical-sections.md`) would **not** fix this specific reference, because the
target section doesn't exist there yet. Fixing this file requires either (a) adding a third
generated section to `canonical-sections.md` via `edm-sync-canonical-sections`, or (b) inlining
the D15 rule directly into `edm-qc-auditor.md` since it is short. This is a materially different
fix shape than the other 13 files' fix, and should be called out as its own sub-item if T04 is
ticketed.

### 4.2 What the anchored 13 files actually say (the pattern to copy)

Verified identical (modulo lens ID) in `edm-audit-logic.md:69`, `edm-audit-security.md:154-157`,
and `edm-audit-synthesizer.md:87`:

> "Use the canonical P0/P1/P2/NOTED vocabulary from `CLAUDE.md Sec."Severity vocabulary"`. Read
> `docs/canonical-sections.md` (resolved relative to the EDM plugin's own root -- `plugins/edm/`
> in this repository, or the installed plugin's cache root, never the caller's cwd) for the actual
> section text; a bare `CLAUDE.md Sec."..."` reference does not resolve because CLAUDE.md at the
> plugin root is not loaded as runtime context."

`edm-srd-auditor.md:38-42` (the Mermaid-conventions consumer, slightly different section target
but the same anchor shape):

> "...of `CLAUDE.md Sec."Mermaid diagram conventions"`. That section's text is not directly
> loadable at runtime (CLAUDE.md at the plugin root is not loaded as runtime context); read
> `docs/canonical-sections.md` instead, resolved relative to the EDM plugin's own root
> (`plugins/edm/` in this repository, or the installed plugin's cache root, never the caller's cwd)
> -- it carries a byte-identical copy of this section"

The pattern to copy into the 14 (or, per 4.1, effectively the 8-named-plus-6-unnamed) remaining
files: keep the original `CLAUDE.md Sec."..."` citation as-is (it still resolves for anyone
reading the file in-repo, e.g. a human reviewer), and **append** the `Read docs/canonical-sections.md
...` sentence immediately after it, with the same "resolved relative to the EDM plugin's own
root... never the caller's cwd" qualifier every one of the 13 existing instances carries verbatim.
`agents/edm-architect.md:31,89` and `skills/*/SKILL.md`'s bare references would each get this
same one-sentence addition at each citation site.

---

## 5. D3 finding -- `disable-model-invocation` blocking Skill-tool dispatch

**This item is already fully investigated and closed by this initiative's own `decisions.md` (D3,
D4).** My independent source verification corroborates it exactly; I report the verification
rather than re-litigating the decision.

### 5.1 Repo tree (checked out at plugin version 3.2.0) vs. installed cache (3.2.1)

- **Repo tree, all 14 `skills/*/SKILL.md` files** (`Grep` across `plugins/edm/skills/`):
  every one carries `disable-model-invocation: true` at line 4 of its frontmatter, and **none**
  carry a `user-invocable` key. `plugins/edm/.claude-plugin/plugin.json:4` records
  `"version": "3.2.0"`; `CHANGELOG.md`'s latest entry is `## [3.2.0] -- 2026-08-16` with no 3.2.1
  entry present in this checkout.
- **Installed cache at `~/.claude/plugins/cache/stg-marketplace/edm/3.2.1/`**: diffing
  `skills/plan/SKILL.md` frontmatter line-for-line against the repo tree's copy, the **only**
  change is line 4: `disable-model-invocation: true` is **removed** and replaced with
  `user-invocable: true`. Everything else in the frontmatter (`name`, `description`, `model`,
  `effort`, `argument-hint`, `allowed-tools`) is byte-identical. Grepping all 14 cached 3.2.1
  `SKILL.md` files confirms this same swap applies uniformly across all 14, with zero remaining
  `disable-model-invocation` occurrences anywhere in that cache's `skills/` tree.
- **Conclusion, independently reached**: yes, this is a real, verified frontmatter change between
  3.2.0 and 3.2.1, and it is genuinely a defect fix, not an artifact of caching or a Claude Code
  version difference. `decisions.md` D3 additionally names the exact upstream commits (`bdec805`,
  merged `bdb5698`) and states a plugin-wide `bin/edm-check-skill-sync` guard against
  `disable-model-invocation` was added alongside it.

### 5.2 Whether the repo tree still ships the defect

**Yes.** I verified this directly rather than trusting D3's prose: `bin/edm-check-skill-sync`
(read in full, `plugins/edm/bin/edm-check-skill-sync:1-78`) contains **zero** references to
`disable-model-invocation` anywhere in its body -- its only two checks are (a) the dispatcher
contains no `## Operational Orchestration` procedure body, and (b) every phase skill still owns
one. There is no guard here banning `disable-model-invocation` under `skills/`, confirming D4's
claim that this branch predates that guard's addition. **The repo tree at this branch, as of this
read, still carries the exact D3 defect: every one of the 14 skills would fail Skill-tool dispatch
today**, and nothing in `bin/tests/` on this branch would catch a regression back to it (or,
symmetrically, nothing would catch this branch's failure to have the fix at all) except the manual
verification D4 prescribes ("Rebase ... onto `origin/main` before Phase 6 implementation begins
... re-verify with `bash plugins/edm/bin/edm-check-skill-sync`").

### 5.3 What `CLAUDE.md Sec."Skill-tool composition"` (D21) claims vs. what the frontmatter permits

`CLAUDE.md`'s "Skill-tool composition" section (`CLAUDE.md:24-45`) states skills DO load other
skills via the `Skill` tool, citing the git plugin's `commit -> jira:search-jira` call as the
in-repo precedent, live-verified in a D21 spike. **This precedent's own frontmatter was never
checked by me for `disable-model-invocation` presence** -- decisions.md D3 states the precedent
"holds only because its target carries `user-invocable: true` and no `disable-model-invocation`
key," which I did not independently re-verify against `plugins/jira/skills/search-jira/SKILL.md`
in this pass (out of this explorer's assigned scope area, `plugins/edm/`). If a future ticket
needs that cross-plugin fact re-confirmed, it is a one-file read outside this report's scope.

Within `plugins/edm/` itself: the repo tree's frontmatter (`disable-model-invocation: true` on all
14) **directly contradicts** what D21/the Skill-tool-composition section assumes is possible
(`orchestrator/SKILL.md` dispatching `/edm:plan`, `/edm:srd`, etc. via the `Skill` tool, per Step
2's own text) -- this is not a hypothetical risk, it is the literal failure D3 records happening
live during this initiative's own Phase 1 intake.

---

## Component Inventory

| Component | Path | Status | Notes |
|---|---|---|---|
| `ALL_LENS_IDS` lens-set single source | `bin/edm-state:1613,1615` | Modified | Grows from 11 to 14 entries; self-check literal `-eq 11` must change too |
| Code-audit lens table & prose | `skills/code-audit/SKILL.md` (12 sites) | Modified | Table, headings, `--lenses` validation range, smoke-audit language |
| `edm-audit-silent-failures` (L12) | `agents/edm-audit-silent-failures.md` (name TBD) | New | ~130-160 lines, house style per Sec.1.2; unconditional |
| `edm-audit-type-design` (L13) | `agents/edm-audit-type-design.md` (name TBD) | New | Stack-conditional; needs new N/A-agreement mechanism (Sec.1.3) not yet designed |
| `edm-audit-behavioral-test-coverage` (L14) | `agents/edm-audit-behavioral-tests.md` (name TBD) | New | Unconditional; overlaps conceptually with L4 and `edm-test-coverage-auditor` -- mandate boundary needs one clarifying sentence in the new lens's Scope section to avoid duplicate findings |
| Smoke-suite lens-count assertions | `bin/tests/wave7-smoke.sh` (~28 sites) | Modified | Largest blast radius in 4.4; includes two tests explicitly asserting the count must NOT change (T47 AC6, T48 AC6) which must be intentionally revised, not just incremented |
| Full-round fixture | `bin/tests/fixtures/code-audit/README.md` | Modified | Fixture must grow from 11 to 14 lens JSONL/MD pairs |
| Orchestrator Step 1c | `skills/orchestrator/SKILL.md:103-114` | Modified | New pre-step (1b.5/1c.0) computing a recommendation; must not restate mode matrix (D6) |
| `MODE_ENUM_LIST`/`LIFECYCLE_MODE_ENUM_LIST` | `bin/edm-state:807-808` | Exists, unmodified | Hard backstop the classifier's output must always satisfy |
| Bounded remediation loop | `skills/implement/SKILL.md:40` (Operational Orchestration step 8) | Modified | Replaces unbounded FAIL-remediation prose; needs new attempt-counter state field and a cost-ceiling design predating implementation |
| `partial_verdict_map.<ticket>.closure_history` | `bin/edm-state:4978` | Exists, unmodified | PARTIAL-closure-specific; not a drop-in shape for FAIL-remediation attempt tracking |
| `phase_durations[6]` / `audit_rounds` cost fields | `bin/edm-state` (Cost tracking section) | Exists, unmodified | A remediation loop needs a NEW, finer-grained attribution unit; neither existing structure is scoped to a single QC cycle |
| By-name reference anchors | 14 files (5 agents + 9 skills, Sec.4.1) | Modified | Larger set than CLAUDE.md's own named 8; `edm-qc-auditor.md`'s D15 reference needs a different fix shape (no canonical-sections.md target exists yet) |
| `docs/canonical-sections.md` | `plugins/edm/docs/canonical-sections.md` | Possibly modified | Only if D15 is added as a third generated section (Sec.4.1) |
| Skill frontmatter (`disable-model-invocation`) | `skills/*/SKILL.md` (14 files) | **Already fixed upstream, not on this branch** | Confirmed defect on this branch (Sec.5); resolved by rebase per decisions.md D4, not by new work |
| `bin/edm-check-skill-sync` disable-model-invocation guard | `bin/edm-check-skill-sync` | **Missing on this branch, exists upstream** | Confirmed absent by direct read; arrives via the D4 rebase, not a new ticket |

---

## Constraints

- **D2** (do not reduce lens/auditor fan-out): 4.4 is additive so does not violate D2 on its face,
  but a cost-driven decision to make L13 "usually skipped" would be a D2 regression in spirit;
  L13's conditionality must be framed as genuine inapplicability (Sec.1.3/1.4).
- **D6** (do not duplicate the mode matrix into agent prompts): binds the 4.3 classifier's
  recommendation text -- it may cite the mode matrix by section reference and compute a
  recommendation, never restate what each mode does.
- **Severity vocabulary is closed** (`CLAUDE.md` "Severity vocabulary" section): a new lens (L12,
  L14) must use the existing P0/P1/P2/NOTED scale with no local scale -- verified as a hard rule
  every existing lens agent obeys identically.
- **ASCII-only artifact convention**: every new/modified prompt file and this report itself must
  stay ASCII-only (`edm-lint-artifacts` class 2), though note per `CLAUDE.md`'s own admission that
  this class does **not** scan `plugins/edm/skills/`, `agents/`, or `docs/` automatically -- so a
  new lens agent's ASCII compliance is not machine-enforced today and must be checked by hand or
  via `edm-lint-artifacts --path plugins/edm/`.
- **`bin/tests/wave7-smoke.sh`'s existing anti-regression tests** (T47 AC6, T48 AC6) are, by
  design, tests that currently PASS specifically because the lens count is 11. 4.4 requires
  deliberately rewriting these two tests' expected values, which is a different kind of change
  from "add a test" -- it is "revise a test whose entire purpose was asserting today's number is
  permanent."
- **Branch hygiene** (D4): none of this explorer's findings should be acted on before the D4
  rebase, since several of the file:line references above (e.g., anything inside
  `bin/edm-check-skill-sync`, or the 14 skill frontmatters) will change wholesale the moment the
  rebase lands.

## Dependency Map

- **4.4 depends on** the L13 stack-detection design question (Sec.1.3) being resolved as its own
  sub-decision before any lens prompt is written -- writing L13's prompt without first deciding
  how `round_type=full` behaves when L13 self-excludes would ship an inconsistency into
  `bin/edm-state`'s round-completeness logic (CA-471's completeness backstop, which already
  distinguishes "missing JSONL" from "lens didn't run," would need to learn a third state:
  "lens legitimately N/A").
- **4.4's test-suite rewrite (item 37, Sec.1.1) blocks** any other work landing cleanly on
  `bin/tests/wave7-smoke.sh` -- it is the single largest and most interconnected file this
  initiative's prompt-surface area touches.
- **4.3 depends on nothing else in this report** -- it is purely additive prose plus one new
  `AskUserQuestion` pre-step, with a hard validation backstop (`MODE_ENUM_LIST`) already in place.
- **5.1 (the bounded loop) depends on** a cost-ceiling design being written and reviewed BEFORE
  any code changes, per the analysis's own explicit precondition -- this is a planning-phase
  deliverable (a short design note answering "what counts as one attempt, what is the per-attempt
  cost cap, what is the total-loop cost cap, what triggers escalation"), not something this
  explorer's inventory can substitute for.
- **EDMV4-T04 depends on** first deciding the `edm-qc-auditor.md`/D15 fix shape (Sec.4.1's second
  gap) -- if the answer is "add a third canonical-sections.md section," `edm-sync-canonical-sections`
  needs to be re-run and its `--check` drift assertion re-verified as part of the same ticket.
- **The D3/D4 rebase is a hard prerequisite for everything else in this report landing on this
  branch** -- every file:line citation above is against a tree that D4 says must be rebased before
  Phase 6, and several files (`bin/edm-check-skill-sync`, all 14 skill frontmatters) will change
  wholesale when that happens.

## Complexity Estimate (this explorer's area only)

- **Files affected**: ~45-55 (37-item table above collapses to roughly: 1 state script, 1
  code-audit skill, 3 new agent files, 1 large smoke-test file with ~28 discrete edit sites, 1
  fixture file, 1 orchestrator skill, 1 implement skill, 14 by-name-reference files, 1
  plugin.json, 1 README.md, 1 CHANGELOG entry, plus `CLAUDE.md` itself for several sections).
- **New modules/agents needed**: 3 (L12, L13, L14 lens agents), plus possibly a small new
  stack-detection helper for L13's conditionality (function, not necessarily a new file).
- **Integration points**: 4 -- `bin/edm-state`'s round-completeness/round-type logic, the
  `SubagentStop` hook's remediation loop insertion, the orchestrator's Step 1c classifier
  insertion, and `docs/canonical-sections.md`'s generation pipeline (`edm-sync-canonical-sections`)
  if D15 is added as a third section.
- **Estimated ticket size for this explorer's four scope items combined**: **Large (50-85
  tickets-equivalent of surface area)** if 4.4, 4.3, 5.1 and EDMV4-T04 are all taken together in
  one initiative wave -- 5.1 alone (a genuinely new bounded-loop subsystem plus a cost-ceiling
  design) is Large-sized on its own per the source analysis's own effort rating; 4.4's test-suite
  rewrite is Medium-sized by itself; 4.3 and EDMV4-T04 are each Small. A planning author should
  strongly consider splitting 5.1 into its own initiative or a clearly separated epic, since its
  precondition (a designed, reviewed cost ceiling) is itself non-trivial planning work distinct
  from the other three items' mostly-mechanical scope.

## Riskiest Assumptions

1. **That `round_type=full` can be cleanly redefined once L13 is stack-conditional.** Unverified:
   nothing in the source establishes how "all lenses that apply ran" should be distinguished from
   "the operator deliberately ran a subset" inside `ALL_LENS_IDS`'s current comparison logic
   (`bin/edm-state:4567-4571`). This is a design question, not an implementation detail, and the
   source analysis does not resolve it either.
2. **That the ~28 `wave7-smoke.sh` assertions I found by grep are the complete set.** I used
   pattern matching (`eleven|L1-L11|...|11 lens|...`) rather than reading every one of that file's
   >7,000 lines; a targeted assertion using different phrasing (e.g. a bare `[[ "$count" -eq 11
   ]]` with no nearby "eleven"/"11" text token) could exist and not have been caught by this
   grep. A ticket for 4.4 should re-grep specifically for `-eq 11` and `== 11` as a second pass
   before considering the test-file inventory closed.
3. **That the FAIL-remediation loop's cost data can reuse `get_session_tokens_since`/
   `compute_cost_usd` unmodified.** Both are currently invoked once per phase-boundary or
   audit-round-boundary call; a per-attempt loop calling them mid-phase, multiple times, has not
   been done anywhere in the codebase today (no existing call site invokes them more than once per
   phase), so there is no precedent verifying they behave correctly when called at a finer grain
   than a full phase.
4. **That `edm-qc-auditor.md`'s D15 reference is genuinely the only "orphaned" citation** (a
   `CLAUDE.md Sec."..."` reference whose target section has no `canonical-sections.md` mirror at
   all). I checked this one instance because it surfaced during the EDMV4-T04 grep; I did not
   exhaustively cross-check every one of the ~14 unanchored files' individual section citations
   against `canonical-sections.md`'s two-section contents. Other files may cite other sections
   with the same "no mirror exists" gap.
5. **That the 3.2.1 cache's frontmatter change is the ONLY difference from 3.2.0.** I diffed only
   the frontmatter block (lines 1-9) of one representative file (`plan/SKILL.md`) plus a grep for
   the two competing keys across all 14 cached files. I did not diff full file bodies between
   3.2.0 and 3.2.1, so I cannot rule out other, unrelated changes having shipped in the same
   release that this report's Sec.5 does not account for.
