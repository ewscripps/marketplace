# Lens L7: Cross-File Consistency

Audit of EDM Claude Code plugin v2.0.0 (EDMV2). Scope: divergence between sibling files that
should follow identical conventions — `skills/*/SKILL.md` (13), `agents/*.md` (29), `bin/` scripts,
`docs/audit-patterns/`, and `CLAUDE.md`/`README.md` as the convention sources of truth.

Plugin root: `plugins/edm-ai-development/`. Canonical conventions: `plugins/edm-ai-development/CLAUDE.md`.

This lens hunts for *divergence between things that should match*, not isolated bugs. Most of the
plugin is strikingly uniform (see "Strong consistency confirmed" below); the findings concentrate on
the severity-vocabulary NOTED level and a few documentation-vs-code mismatches.

## Findings

| ID | Sev | Files compared | Divergence |
|----|-----|----------------|------------|
| L7-01 | P2 | `agents/edm-srd-auditor.md` vs `agents/edm-ticket-auditor.md` vs the 11 `agents/edm-audit-*.md` lenses | The NOTED severity level is implemented three different ways: lenses fully implement it (table row + `## Noted / Not Actionable` output section); `edm-ticket-auditor` names it but gives it no output home; `edm-srd-auditor` drops it entirely (3-row table, no NOTED output section). |
| L7-02 | P2 | `agents/edm-test-coverage-auditor.md` vs `CLAUDE.md` line 271 | Doc states the agent has `disallowedTools: Write, Edit, NotebookEdit`; the agent actually has `disallowedTools: Edit, NotebookEdit` (Write is allowed — it must write the coverage report). Doc contradicts code. |
| L7-03 | P2 | `agents/edm-architect.md` (`effort: max`) + `README.md` line 46 vs `CLAUDE.md` lines 167/198 | README documents architect as `opus / max`; CLAUDE.md's "Model and effort assignments" groups architect with `edm-srd-writer` as a Phase-2 "Writing" role at `opus / high` and never carves out the exception. Two blue Phase-2 writers diverge on effort with no rationale in CLAUDE.md. |
| L7-04 | P3 | `agents/edm-audit-logic.md` line 55 vs the other inline-severity lenses (`edm-audit-security/spec/dry/wiring`) and `edm-ticket-auditor` | The canonical-scale one-liner reads `P0 / P1 / P2` (omits `+ NOTED`) while siblings read `(P0/P1/P2 + NOTED)`. Body still has a `## Noted / Not Actionable` section, so behavior is unaffected — wording only. |
| L7-05 | P3 | `agents/edm-test-coverage-auditor.md` (frontmatter key order) vs every other agent with `disallowedTools` | `edm-test-coverage-auditor` places `disallowedTools` 3rd (after `tools:`, before `model:`); all 15 other agents that declare `disallowedTools` place it last (after `color:`). Cosmetic ordering drift. |

---

### L7-01 — NOTED severity level implemented three ways across the read-only auditors (P2)

**What should match**
CLAUDE.md "Severity vocabulary (canonical)" (lines 176–185) defines a **four-level** scale: P0 / P1 /
P2 / **NOTED**, and states "All EDM audit agents use the following four-level scale. No agent may
define a divergent local scale." Every read-only auditor should therefore (a) reference the full
four-level scale and (b) give NOTED a place in its output skeleton, so "intentional / pre-existing /
accepted trade-off" items have a documented home rather than being silently dropped or mis-graded P2.

**How they diverge (file:line for each)**
- **Lenses (correct, full implementation)** — e.g. `agents/edm-audit-logic.md:50` ("record as 'Noted /
  Not Actionable' with a one-line rationale") and `:64` (`## Noted / Not Actionable` output section).
  All 11 `edm-audit-*` lenses carry an explicit `## Noted / Not Actionable` section; `edm-audit-security.md:63`
  and `edm-audit-spec.md:63` cite "(P0/P1/P2 + NOTED)".
- **`agents/edm-ticket-auditor.md:73`** — names the full scale ("the canonical severity scale
  (P0/P1/P2 + NOTED)") but its **output skeleton** (`:75`–end: Summary counts by category, per-category
  findings, "Verdict: PASS / NEEDS FIXES") has **no NOTED / Decisions / Non-Findings section**. NOTED
  is referenced but homeless.
- **`agents/edm-srd-auditor.md:61`–`97`** — **drops NOTED entirely.** The "Severity Levels" table
  (`:65`–`69`) is **three rows** (P0/P1/P2 only); the output skeleton (`:89`–`96`) has `## P0`,
  `## P1`, `## P2` sections and **no NOTED/Non-Findings section**; the description (`:4`) advertises only
  "(P0/P1/P2)". A `grep` for noted/non-finding/intentional/decisions in this file returns nothing.

**Which is correct**
The **lenses** are correct — they match CLAUDE.md's four-level mandate and give NOTED an output home.
`edm-srd-auditor` is the clearest violator ("No agent may define a divergent local scale" — a 3-level
table is exactly that). `edm-ticket-auditor` is a partial violator (names NOTED, no output home).

**Fix**
1. `edm-srd-auditor.md`: add a NOTED row to the Severity Levels table (`:65`–`69`) and a
   `## Noted / Not Actionable` (or "Decisions / Non-Findings") section to the output skeleton (after
   `:96`); update the description (`:4`) to "(P0/P1/P2 + NOTED)". Mirror `edm-ticket-auditor.md:73`
   wording and the lenses' Noted-section pattern.
2. `edm-ticket-auditor.md`: add a `## Noted / Not Actionable` section to its output skeleton so the
   level it already names has somewhere to land.

---

### L7-02 — `edm-test-coverage-auditor` disallowedTools: doc says Write-blocked, code allows Write (P2)

**What should match**
A `disallowedTools` value documented in CLAUDE.md should equal the value in the agent frontmatter.

**How they diverge (file:line for each)**
- `CLAUDE.md:271` — "`edm-test-coverage-auditor` has `disallowedTools: Write, Edit, NotebookEdit`."
- `agents/edm-test-coverage-auditor.md:10`–`11` — `tools: Read, Write, Bash, Glob, Grep, TodoWrite`
  and `disallowedTools: Edit, NotebookEdit`. Write is **granted** (the agent's job, per `:5`–`9`, is to
  "write `SRD/{PREFIX}/test-coverage.md`" and "remove stale per-epic coverage files").

**Which is correct**
The **agent** is correct — it cannot produce its coverage report if Write is disallowed. Note this is
internally consistent (Write in `tools`, not in `disallowedTools`) and parallels the other writing
auditor `edm-audit-synthesizer.md:5` (Write/Edit in `tools`, no `disallowedTools`). The **CLAUDE.md
line is stale.** (Aside: coverage-auditor blocks `Edit` while synthesizer allows it — a minor approach
difference between the two cyan writing auditors, not separately flagged.)

**Fix**
Correct `CLAUDE.md:271` to "`disallowedTools: Edit, NotebookEdit` (Write is required — it produces
`test-coverage.md`)."

---

### L7-03 — Two blue Phase-2 writers diverge on effort; CLAUDE.md prose doesn't carve out the exception (P2)

**What should match**
CLAUDE.md's "Model and effort assignments" table and color scheme are the source of truth for
per-agent `model`/`effort`. Agents sharing a documented role band should match it, or the doc should
state the exception.

**How they diverge (file:line for each)**
- `agents/edm-architect.md:6`–`7` — `model: opus`, `effort: max`.
- `agents/edm-srd-writer.md:9`–`10` — `model: opus`, `effort: high`.
- `CLAUDE.md:167` groups both under `blue` = "Phase 2 — writing"; `CLAUDE.md:198` assigns "Writing
  (SRD, tickets) → opus / **high**" and `:203` lists `skills/srd/` writers at "effort: high". Architect
  is never named in the effort table, so by the documented banding it would read `high`, not `max`.
- `README.md:46` **does** document `edm-architect | 2 — Architecture | opus / max`.

**Which is correct**
The **agent frontmatter matches README** (`opus / max`) — architecture is judgment-heavy, so `max` is
defensible and likely intentional. The gap is that **CLAUDE.md's effort table is silent** on the
architect exception, so CLAUDE.md and README disagree about a blue Phase-2 agent's effort.

**Fix**
Add a row/note to the `CLAUDE.md:195`–`203` table: "Architecture (edm-architect) → opus / max —
judgment-heavy design work, unlike the SRD/ticket writers which run at high." This makes the
intentional split explicit and aligns CLAUDE.md with README.

---

### L7-04 — `edm-audit-logic` severity one-liner omits "+ NOTED" (P3)

**What should match**
The inline canonical-scale reference wording across the lenses that restate it on one line.

**How they diverge (file:line for each)**
- `agents/edm-audit-logic.md:55` — "**Severity**: P0 / P1 / P2 -- use the canonical scale…" (no "+ NOTED").
- `agents/edm-audit-security.md:63`, `agents/edm-audit-spec.md:63`, `agents/edm-audit-dry.md`,
  `agents/edm-audit-wiring.md`, `agents/edm-ticket-auditor.md:73` — "(P0/P1/P2 + NOTED)".

**Which is correct**
The "(P0/P1/P2 + NOTED)" siblings. Impact is wording-only — `edm-audit-logic.md:64` still has a
`## Noted / Not Actionable` output section, so behavior is unaffected (related to but milder than L7-01).

**Fix**
Change `edm-audit-logic.md:55` to "P0 / P1 / P2 + NOTED" to match the other lenses.

---

### L7-05 — `disallowedTools` frontmatter key ordering outlier (P3)

**What should match**
Frontmatter key ordering across sibling agents. 15 of 16 agents that declare `disallowedTools` use the
order `… maxTurns: color: disallowedTools:` (key last).

**How they diverge (file:line for each)**
- `agents/edm-test-coverage-auditor.md:2`–`15` — order is `name: description: tools: disallowedTools:
  model: effort: maxTurns: color:` (disallowedTools 3rd).
- All others, e.g. `agents/edm-audit-logic.md`, `edm-srd-auditor.md`, `edm-qc-auditor.md`,
  `edm-explorer.md`, `edm-ticket-auditor.md` — `disallowedTools` is the **last** key (after `color:`).

**Which is correct**
The majority ordering (`disallowedTools` last). Purely cosmetic — YAML is order-insensitive — but it's
a real sibling divergence in a plugin whose product is convention enforcement.

**Fix**
Move `disallowedTools` to the end of `edm-test-coverage-auditor.md`'s frontmatter to match the other 15.

---

## Strong consistency confirmed (no findings)

These were checked specifically for divergence and found uniform — recorded so the next round doesn't
re-investigate:

- **No bare/unscoped `Bash` in any skill.** All 13 `skills/*/SKILL.md` scope `Bash(...)` to command
  families only: `Bash(edm-state *)` ×13, `Bash(edm-init *)` ×2, `Bash(edm-validate-prefix *)` ×2,
  `Bash(mkdir *)`, `Bash(date *)`, `Bash(grep *)`. EDMV2-T20 (scope bare Bash) is fully applied.
- **Skill frontmatter is uniform.** All 13 skills share the identical key set and ordering:
  `name, description, disable-model-invocation, model, effort, argument-hint, allowed-tools`. No skill
  is missing a required key.
- **Severity vocabulary — no legacy P1/P2/P3 scale survives.** `grep` for `P3` across `agents/` and
  `docs/audit-patterns/` returns nothing; no `CRITICAL`/`BLOCKER`/`MAJOR`/`MINOR`/`Sev 1` divergent
  scales anywhere. The synthesizer (`edm-audit-synthesizer.md:55`–`62`) carries the full four-level
  table including NOTED. (The NOTED divergence in L7-01/L7-04 is the only severity exception.)
- **Jira MCP namespace is constructed consistently.** `skills/push-jira/SKILL.md` uses
  `mcp__{jira_mcp_namespace}__{tool}` in every tool position (frontmatter line 8 and body
  lines 19/31/34/35/36/51/63/64/116/121/193). The literal `plugin_jira_atlassian-mcp-server` appears
  **only** as the documented default value (push-jira:30, push-jira:219, CLAUDE.md:371) — never
  hardcoded into a tool call. Matches CLAUDE.md's `${user_config.jira_mcp_namespace}` model.
- **No Unicode emoji glyphs** in `skills/`, `agents/`, `bin/`, `hooks/`, `docs/`, or `plugin.json`.
  The only non-ASCII characters are typographic em-dashes (—) and arrows (→) in prose/`plugin.json`
  description — not gitmoji shortcodes, and not in any commit-guidance context. `edm-architect.md:85`
  actively enforces "ASCII-only (no Unicode arrows or glyphs in text)". No `:shortcode:`-vs-Unicode
  inconsistency exists because the plugin emits no gitmoji at all.
- **`model`/`effort`/`color`/`maxTurns` otherwise match CLAUDE.md + README.** All cyan lenses +
  synthesizer + coverage-auditor = opus/max; explorer = opus/max yellow; QC = opus/max red; the two
  orange auditors = opus/max; implementer = sonnet/high green; all 7 test-writers = sonnet/high green;
  scaffold = sonnet/high blue; planner = opus/high yellow; the writers = opus/high (architect excepted,
  see L7-03). Colors match the CLAUDE.md table (164–172) and test inventory (254–265) exactly. maxTurns
  are internally consistent by role (lenses 30, pre-impl auditors/QC/coverage 25, test writers 50/60/30,
  writers 50, implementer 60).
- **`tools:` lists are byte-identical within role classes.** All 15 read-only auditors share the exact
  string `Glob, Grep, LS, Read, NotebookRead, WebFetch, TodoWrite, WebSearch, KillShell, BashOutput`;
  all test-writers + scaffold + planner share `Read, Write, Edit, Bash, Glob, Grep, TodoWrite`.
- **userConfig variables consistently spelled.** Every reference uses `${user_config.<key>}` — no
  `${userConfig.x}`, `$USER_CONFIG`, or casing variants. Keys observed: `srd_root` (53), `ticket_pack_dirname`
  (19), `srd_filename` (14), coverage targets, `jira_mcp_namespace`, `jira_project_key`,
  `prefix_format_hint`, framework overrides, `human_hourly_rate_usd` — all matching the CLAUDE.md
  `userConfig` reference.

## Noted / Not Actionable

- **`edm-qc-auditor` uses PASS/PARTIAL/FAIL verdicts instead of a P0/P1/P2/NOTED scale for ACs.**
  (`agents/edm-qc-auditor.md:29`–`36`.) This is intentional and documented: it grades acceptance
  criteria with a verdict paradigm, then applies the canonical P0/P1/P2 scale only to its **FAIL
  findings** (`:61`–`64`), correctly citing CLAUDE.md. PARTIAL/`deferred-to-runtime` plays the
  NOTED-equivalent role for un-statically-verifiable ACs. Not a divergence.
- **Synthesizer P0/P1/P2 definition wording leans "legacy" ("production failure", "operational
  friction", "defensive improvements" — `edm-audit-synthesizer.md:59`–`61`).** These are the *source*
  terms in CLAUDE.md's backward-compat mapping (lines 187–190). Because the synthesizer relabels them to
  the canonical P0/P1/P2 and explicitly references "the canonical severity scale defined in CLAUDE.md"
  (`:55`) and includes the NOTED row (`:62`), it is post-mapping aligned. Wording flavor only, not a
  scale divergence.
- **`edm-test-planner` opus/high while sibling discovery agent `edm-explorer` is opus/max** (both
  yellow). Documented: CLAUDE.md's testing-layer inventory (line 258) explicitly assigns the planner
  opus/high, and `skills/test-plan/` mirrors it. Intentional, not a contradiction.
- **`edm-test-coverage-auditor` blocks `Edit` while `edm-audit-synthesizer` allows it** (both cyan
  writing auditors). Minor approach difference; both are functional for their write tasks. Captured under
  L7-02's aside; not separately actionable.
