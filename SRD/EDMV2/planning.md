# EDMV2 Planning

## Initiative

Enhance the **`edm-ai-development`** Claude Code plugin (internal name `edm`, currently **v1.3.0**) — the plugin that implements the Enterprise Development Methodology itself. The enhancement set is **evidence-based**: it is derived from a systematic analysis of ~30 real EDM initiatives (active + archived) in `/Users/darryl.porter/projects/scripps-mcp/SRD/` and the foundational methodology doc (`ai-assisted-development-methodology.md`, v2.0.0). Four parallel `edm-explorer` agents mapped (1) the plugin's current surface, (2) the recent DC/control-plane plugin-era cohort, (3) the TIPS product-line cohort, and (4) the methodology doc + legacy initiatives. Their findings converge on a consistent set of gaps — many corroborated across multiple cohorts, which raises confidence that these are systemic, not one-off.

This is a meta-initiative: **using EDM to improve EDM.** Artifacts live in this repo at `marketplace/SRD/EDMV2/`; the corpus being analyzed lives in the separate `scripps-mcp/SRD/` repo.

## Current State

**Plugin surface (v1.3.0):**

- **13 skills** (`skills/<name>/SKILL.md`): `orchestrator`, `plan`, `srd`, `audit-srd`, `tickets`, `audit-tickets`, `implement`, `code-audit`, `test`, `test-plan`, `test-coverage`, `metrics`, `push-jira`.
- **29 agents** (`agents/*.md`): 8 phase agents (`edm-explorer`, `edm-architect`, `edm-srd-writer`, `edm-srd-auditor`, `edm-ticket-writer`, `edm-ticket-auditor`, `edm-implementer`, `edm-qc-auditor`); 11 code-audit lenses + `edm-audit-synthesizer`; 10 `edm-test-*` agents.
- **`bin/edm-state`** (802-line state machine, 16 subcommands), `edm-init`, `edm-validate-prefix`.
- **`hooks/hooks.json`**: `SessionStart`→list; `UserPromptExpansion` gate-blocking on `edm:(srd|tickets|implement)`; `Stop`/`PreCompact`→checkpoint; `SubagentStop`(edm-implementer)→auto-QC; `TaskCompleted`→record duration. **`monitors/monitors.json`**: impl-progress watcher.
- **6 phases + 3 HITL gates**; canonical per-initiative artifacts: `planning.md`, `srd.md`, `audit-srd.md`, `tickets/{README,audit,epics/}`, `code-audit/{date}/{lens-L1..L11,REMEDIATION}.md`, `test-plan.md`, `test-coverage.md`, `HANDOFF.md`, `.edm-state.json`.
- userConfig for paths, coverage targets, framework overrides, Jira key, hourly rate. Cost/metrics tracking from session JSONL.

**Corpus analyzed (evidence base):** ~30 initiatives spanning the full evolution of the methodology —
- **Pure legacy** (single-file SRD or raw agent export): `court_navigation_tool`, `video_editing_agent`, `Recursive_Language_model`, `SnowFlake`, `kb_ingestion`, `microsoft_graph_mcp`, `sales`, `spelling-bee`, `scripps-foundation-framework`.
- **Two-file / collection legacy**: `news_agents` (10 sub-agents, some already in full plugin layout but using the banned `TICK-NN` ID format).
- **Hybrid** (`TIPS/`): monolithic `TIPS_*_SRD.md` + single `TIPS_TICKET_PACK.md` with a plugin-style `tickets/` grafted in.
- **Plugin-era** (canonical layout): the DC family (DCAUTHZ, DCHELP, DCRBAC, DCJWT, CONV, RBT, DEEPCHAT) and the TIPS* family (TIPSCONF, TIPSBRV, TIPSFIX, TIPSMORE, TIPSBRK, TIPSCOST, TIPSINST, TIPSOURCE, TIPSSTNUM).

## Gap Analysis

The findings cluster into **11 workstreams (WS-A … WS-K)**. Each is grounded in cited evidence. Severity/impact noted; "corroborated by N cohorts" indicates cross-explorer agreement.

### WS-A — Correctness & Consistency Defects (plugin-internal) — **High confidence, low risk**
Seventeen defects found by direct inspection of the plugin (Explorer 1):
- **P0/High:** **G1** `edm-test-coverage-auditor` is denied `Write` (`tools:`/`disallowedTools:` at `agents/edm-test-coverage-auditor.md:8-9`) yet is mandated to write `test-coverage.md` (`:6,19`) — the headline v1.3.0 testing feature's output is structurally broken (its sibling writers `edm-audit-synthesizer`/`edm-architect` both have `Write`). **G3** `metrics` skill advertises features (`gate_review_seconds`, p95, bottleneck highlighting, guideline comparison) that `edm-state metrics-report` never computes (`skills/metrics/SKILL.md:30-34,44-46,64` vs `bin/edm-state:518-623`). **G4** two divergent Phase-1 `planning.md` templates — `plan` skill has Go/No-Go + Riskiest Assumptions but **not** the `## Open Questions`/`## Decisions Made` that `write-handoff` parses (`bin/edm-state:719-720`); orchestrator has the inverse. **G2** CHANGELOG claims all agents have `<example>` blocks; zero exist.
- **P1/Med:** **G5** `/edm:plan` never creates `HANDOFF.md` (only orchestrator does). **G6** dedicated `srd-version` subcommand is dead — `srd`/`audit-srd` use `set`, which skips the handoff refresh. **G7** `record-task-duration` is a documented no-op (`bin/edm-state:403-411`) but the `TaskCompleted` hook calls it and docs claim it's live. **G8** `push-jira` hardcodes `mcp__MCP_DOCKER__*` while the marketplace `jira` plugin uses `mcp__plugin_jira_atlassian-mcp-server__*` — Jira sync silently no-ops for marketplace users. **G9** two severity vocabularies (P0/P1/P2 in SRD/ticket/QC audits vs P1/P2/P3+NOTED in code-audit). **G18** `/edm:code-audit` is positioned as an optional post-Phase-6 step ("Optional: invoke `/edm:code-audit`" in the orchestrator skill) rather than a mandatory phase — an initial design oversight. The 11-lens audit is a core quality gate, not an add-on; every corpus initiative that ran it found production-blocking issues (DCRBAC pass 4 surfaced a P1 that survived 3 prior passes + `/edm:test`).
- **P2/Low:** G10 `--dry-run` unparsed; G11 `--fill-gaps` skill-vs-CLAUDE.md contradiction (ALL gaps vs P1-only); G12 prefix regex (`2-8 chars, allows _/-`) ≠ documented "3-6 uppercase"; G13 `edm-init` prints a stale next-step; G14 unscoped `Bash` in all skill `allowed-tools`; G15 Unicode glyphs (`✓✗⚠→`) written into committed `HANDOFF.md`/drift warnings (violates marketplace no-Unicode rule); G16 duplicate `plugin.json` + wrong README install paths; G17 scaffold asymmetry.

### WS-B — Audit Scalability & Convergence — **High; corroborated by 2 cohorts**
The code-audit phase re-runs many times with **ad-hoc round directory names** the plugin doesn't define: `-r2/-r3/-r4` (DCAUTHZ), `-pass2/3/4` (DCRBAC), `-followup/-epic-b/-pass2/3` (TIPSCONF), `-h1-h14/-k1-k2-k5-k8/-tests/-post-remediation/-final` (TIPSMORE), `-post-remediation/-4th-audit/-deferred-items` (DEEPCHAT). No round/pass index; the date-only key collides on multi-audit days. **No convergence guarantee:** DCRBAC pass 4 (invoked with literal "no deferrals") surfaced a **P1 production-blocker that survived 3 prior 11-lens passes AND `/edm:test`** (`.archived/DCRBAC/code-audit/2026-06-02-pass4/REMEDIATION.md:1-29`); DEEPCHAT ran 4 passes / 151 findings / 48 commits. **Lens set unstable across rounds** (rounds silently drop lenses; some passes have only `REMEDIATION.md`). Ticket/SRD audits show the same multi-pass strain: `tickets/audit-pass2.md`, `audit-pass3.md` (flagging "pack v1.1 stale vs SRD v1.2"), `audit-srd-v1.2.md` — **version drift between artifact and the SRD/pack it audited is untracked.**

### WS-C — QC Scale & Verdict Fidelity — **High; corroborated by 3 cohorts**
The single `edm-qc-auditor` / auto-QC-on-`SubagentStop` flow **does not scale** to large ticket sets: TIPSCONF was manually sharded into `qc-audit-T01-T11.md` + `qc-audit-T12-T22.md` + a hand-written `qc-audit-summary.md` ("auditor ×2 in parallel"). **Phase-6 QC output has no canonical home** (lands in ad-hoc `qc-audit.md` in RBT, or buried in HANDOFF tables elsewhere). **No `PARTIAL` / "deferred-to-runtime" AC state:** RBT QC recorded ACs unverifiable statically (needs running Redis; systemd-on-macOS; MR-description checks) as an invented PARTIAL (`.archived/RBT/tickets/qc-audit.md:9-17`). The methodology doc mandates PASS/**PARTIAL**/FAIL (doc:356,370,390) but the plugin doesn't preserve PARTIAL in state.

### WS-D — Artifact-Set Expansion (canonical homes for real artifacts) — **High; corroborated by 2 cohorts**
Real, recurring artifacts have no defined home and leak into sidecars or HANDOFF prose:
- **Architecture doc** — `edm-architect`'s output appears as `arch-section5.md` sidecars (DEEPCHAT, DCRBAC) or inconsistent inline SRD sections.
- **Explorer findings** — parallel explorer outputs persist as `explorer-blacklist.md`/`explorer-email.md` (TIPSCONF), hand-merged into `planning.md`. *(This very initiative spawned 4 explorers with no defined home for their reports.)*
- **Decision / audit ledger** — finding→commit tables (78 findings in DEEPCHAT HANDOFF:22-47) and "Key Decisions Made" lists (DCRBAC, RBT) overload `HANDOFF.md`.
- **Rollback runbook** (`TIPSBRV/ROLLBACK.md`), **post-deploy verification** (`TIPSFIX/verification.md`), **live-run execution reports** (`TIPSMORE/epic9-execution-report.md`, "Mode: live-db"), **analysis inputs** (`rate-limit-analysis.md`, `portal-source-triage.md`, `cost-analysis-*`).

### WS-E — Methodology Adaptation Modes (doc fidelity) — **High; the single largest intent gap (Explorer 4)**
The source doc's **`## Adapting to Your Project`** (lines 446-468) defines four first-class modes the plugin implements as **none**:
- **mini-SRD** for small projects (fuse Phases 2-5 into one file, skip the separate ticket pack, *still audit*) — `grep mini-SRD` = 0 hits. `video_editing_agent/` is exactly this shape.
- **Regulated industries** — add a **compliance review gate between Phase 5 and 6** + regulatory-traceability columns. Plugin has only 3 gates; "compliance" exists merely as an audit-lens word. Directly relevant to Scripps newsroom/legal context (FOIA, court data, editorial ethics — `foia_assistant`, `court_navigation_tool`).
- **Infrastructure-as-code** — "resource paths" not "file paths"; QC checks `terraform plan`/drift.
- **Data/ML** — mandatory Data Requirements section; QC validates model metrics. `kb_ingestion`, `Recursive_Language_model` are exactly data/ML.
- Plus the documented-but-unimplemented **"Exploratory prototype → Phase 1-2 only"** path (no flag/mode actually runs the subset).

### WS-F — Lifecycle Modes: partial / fast-track / supersede — **Med-High; corroborated by 3 cohorts**
- **Partial-EDM / phase-skip** is not first-class: CONV skipped Phases 4-5, recorded only as "Gate 3 N/A (partial EDM)" + "⏭ Skipped" prose (`.archived/CONV/HANDOFF.md:30-52`).
- **Analysis→fast-track / fix-pack**: TIPSFIX generated tickets directly from an analysis doc with no `srd.md`/`planning.md`/`.edm-state.json` (`TIPSFIX/tickets/README.md:3`) — a common real workflow that looks like a broken EDM run.
- **Supersede / fork**: REBOOT_SURVIVAL is an orphan re-scope of RBT with no provenance link.

### WS-G — Product-Line / Multi-Initiative Linkage — **High (TIPS); Med (multi-pack)**
The 10 TIPS initiatives are a de-facto product line, but the plugin treats each as an island. Constant cross-references (TIPSCONF→TIPS/TIPSOURCE/TIPSINST; TIPSBRV→"TIPSCOST-46"; TIPSFIX→TIPSCOST) and baseline facts (the `tips.stations`/`call_letters` model) re-derived from scratch in multiple explorer reports. The legacy "Related Documents / additive, remains in force unless superseded" contract (`TIPS_QUALITY_PHASE2_SRD.md:26-31`) is lost. **Multi-phase sub-initiatives** (TIPS_QUALITY_PHASE1/2, prerequisite chains) have no plugin model. **Multiple ticket packs in one dir + custom prefix**: `deep-chat-gui` uses `tickets-gui/` + `tickets-platform-expansion/` with a `DCXT-` prefix.

### WS-H — Multi-Stack / Multi-Epic Support — **High (where it bites)**
TIPSCONF spanned two stacks (Epic A Python / Epic B Nuxt) on stacked branches. The single-`test-plan.md` assumption broke: the base plan **wrongly** declared Epic B "out-of-tree N/A," forcing a `test-plan-epic-b.md` that explicitly supersedes it ("that was incorrect", `:6-8`); `test-coverage.md:4` still carries the wrong "N/A." Per-epic/per-stack test-plan + coverage and per-epic stack auto-detection are needed.

### WS-I — Legacy Migration — **Med-High; reverses a stated non-goal**
~15 legacy initiatives in 4+ formats; several are already ~80% plugin-shaped (`news_agents/summarize` has the full `tickets/README+epics/` layout but uses the **banned `TICK-NN`** IDs). The plugin CLAUDE.md explicitly states it **"does NOT migrate these."** A `/edm:import` assistant (single-file SRD and two-file `SRD`+`DEVELOPER_TICKETS.md` → canonical layout) + ticket-ID normalization would unlock state/metrics/audits for a large backlog — but it reverses a deliberate design decision.

### WS-J — State Integrity & Determinism — **Med-High**
`.edm-state.json` shows internal inconsistencies across the corpus: `estimated_size:"Unknown"` for a 44-ticket initiative; `current_phase` lagging HANDOFF; `completed_at` **earlier than** `started_at`; zeroed tokens/`model_used`. Plus: **gate enforcement is prompt-based** (an LLM `UserPromptExpansion` hook, not a hard-failing script) though gates are marketed as "enforced"; no file-locking on state; `archive` is a bare `mv` with no git awareness; `set` stores all values as strings (timestamps/booleans untyped). **Gate false-positive:** the orchestrator's HITL gate handler does not reliably distinguish between the user explicitly selecting "Approve" vs. typing arbitrary text in the `AskUserQuestion` "Other" field — free-text responses have been misrouted as gate approvals; only an explicit "Approve" selection must trigger `edm-state approve-gate`, with free-text treated as a no-op or escalated to a re-prompt.

### WS-K — Convention Enforcement & Templates — **Med**
- **AI-attribution + Unicode emoji leak into shipped artifacts**: a PR-body template with `🤖 Generated with [claude-flow]` baked into `.archived/DEEPCHAT/HANDOFF.md:92` — violates the repo's no-attribution / no-Unicode rules. (Ties to G15.)
- **No artifact lint**: leaked tool tags (`</content></invoke>`) committed in `.archived/DCRBAC/HANDOFF.md:58-59`.
- **Duplicated boilerplate**: the XS/S/M/L "no XL — decompose" size legend and large "Every ticket MUST include…" cross-cutting-AC blocks are re-authored in every `tickets/README.md` — candidates for a shared template the plugin owns.
- **Two-lane ticket audit** (structural + content-quality) is run manually (`DCAUTHZ/tickets/audit.md:6`) — could be built in.

### WS-L — Audit-Informed Artifact Quality (shift-left) — **High; evidence from all cohorts**
The plugin runs five distinct audit types (SRD audit → `edm-srd-auditor`; ticket audit → `edm-ticket-auditor`; QC audit → `edm-qc-auditor`; 11-lens code audit → `edm-audit-*` lenses; test coverage audit → `edm-test-coverage-auditor`) but the *writer* agents (SRD writer, ticket writer, implementer) operate without knowledge of what auditors repeatedly flag. The corpus shows sustained audit churn: every DC initiative ran 2-4 SRD audit rounds; TIPSCONF ran 3 ticket audit passes; DEEPCHAT ran 4 code-audit passes with 151 findings. Rather than accepting multi-pass iteration as inherent cost, this workstream: (1) conducts a systematic analysis of each audit type — what it checks, what it most commonly flags, what a first-draft looks like that *passes* — and (2) encodes those patterns into the corresponding writer-agent prompts and artifact templates so that first drafts enter audits closer to passing. Deliverables: a per-audit-type "what auditors look for" reference (embedded as guidance in each writer agent); updated `edm-srd-writer`, `edm-ticket-writer`, implementer-agent, and planning-document template to pre-empt top findings; measurable reduction in audit-pass count across initiatives.

### WS-M — Initiative Directory Structure — **High; affects all path references**
Currently `SRD/{PREFIX}/` — a 2-8 char prefix alone is insufficient to identify an initiative at a glance; consulting HANDOFF.md or git history is required. **New canonical structure:** `SRD/{PRODUCT}/{PREFIX}__{DESCRIPTION}/` (e.g., `SRD/tips/TIPSBRV__broadcast-reliability-validation/`, `SRD/dc-auth/DCRBAC__rbac-implementation/`, `SRD/edm/EDMV2__enhance-edm-plugin/`). Initiative purpose becomes discoverable at the filesystem level; product-level directories allow `ls` to enumerate all initiatives for a product. Changes required:
- `edm-init`: accept `--product <name>` and `--description <slug>` (or prompt interactively); create the product subdirectory if absent; write `product_name` and `initiative_description` into `.edm-state.json` at init time.
- `edm-validate-prefix`: validate uniqueness within the product's subdirectory, not globally across `SRD/`.
- `edm-state`: store `product_name` + `initiative_description`; surface both in `metrics-report`, `write-handoff`, and the forthcoming `list` subcommand.
- All skills and agents that construct artifact paths must derive the full initiative directory from state rather than assuming a flat `SRD/{PREFIX}` layout.
- Existing in-flight initiatives: remain functional unmodified via `EDM_SRD_ROOT` pointing to the old path; provide an opt-in `edm-state migrate-path --product <name> --description <slug>` helper for teams adopting the new layout.

### WS-N — Compaction Resilience — **High; confirmed defect during this initiative**
When Claude Code compacts conversation history during a long EDM phase, the orchestrator loses: which step within the phase it was executing, the last decision made, which agents were spawned and whether they completed, and the next concrete action. The `PreCompact` hook already exists and calls `edm-state write-handoff`, but `HANDOFF.md` captures only the *phase* level — not the *step* within a phase or the specific pending action. After compaction, Claude must re-derive its position from a sparse summary, leading to repeated steps, missed state writes, or stalled progress (confirmed in EDMV2 Phase 1: a cwd drift caused `edm-state phase-complete` to fail silently after context grew large, requiring manual recovery). Required changes:
- `HANDOFF.md` gets a **`## Resume Point`** section written at every `write-handoff` call: current phase + step number within the phase, the last bash command executed (with exact args), the last decision recorded, any pending agents, and the literal next action as a copy-paste-ready instruction.
- `edm-state` gains an optional `current_step` field — updated by the orchestrator at each step boundary — so `write-handoff` can emit "Phase 2, Step 3: spawn `edm-architect` for Section 5" rather than just "Phase 2 in-progress."
- `edm-state write-handoff` populates `Resume Point` from state (`current_phase`, `current_step`, `last_cmd`, `last_decision`, pending artifact list).
- **`SessionStart` hook enhancement:** when an active initiative is detected (`current_phase` > 0, no `completed_at`), inject the `## Resume Point` block verbatim into session context at the *top* of the injected payload — it must anchor Claude's position before any broader context loads.
- The orchestrator skill's resume branch must read `current_step` from `.edm-state.json` and jump to the correct step rather than restarting Phase 1.

## Component Inventory

| Component | Path | Status | Notes / Workstreams touched |
|-----------|------|--------|------|
| `skills/orchestrator` | `plugins/edm-ai-development/skills/orchestrator/SKILL.md` | Modified | Mode selection (WS-E/F), gate model (WS-E compliance gate), partial/fast-track (WS-F), product-line linkage (WS-G) |
| `skills/plan` | `.../skills/plan/SKILL.md` | Modified | Unify Phase-1 template w/ orchestrator (G4), call `write-handoff` (G5), reconcile go/no-go (WS-A) |
| `skills/srd` / `skills/audit-srd` | `.../skills/{srd,audit-srd}/SKILL.md` | Modified | Route through `srd-version` (G6), versioned/iterative audits (WS-B), SRD section manifest (WS-E), Data Requirements (WS-E) |
| `skills/tickets` / `skills/audit-tickets` | `.../skills/{tickets,audit-tickets}/SKILL.md` | Modified | Shared size legend + cross-cutting-AC template (WS-K), built-in two-lane audit (WS-K), ID renumbering (WS-A), version-drift detection (WS-B) |
| `skills/code-audit` | `.../skills/code-audit/SKILL.md` | Modified | Round/pass index, findings ledger, convergence gate, lens-subset + scoped re-audit (WS-B) |
| `skills/implement` | `.../skills/implement/SKILL.md` | Modified | QC sharding + canonical QC artifact + PARTIAL/deferred-AC (WS-C), execution-report artifact (WS-D) |
| `skills/test` / `test-plan` / `test-coverage` | `.../skills/test*/SKILL.md` | Modified | Per-epic/stack plans (WS-H), `--fill-gaps` contradiction (G11) |
| `skills/metrics` | `.../skills/metrics/SKILL.md` | Modified | Implement or trim advertised features (G3) |
| `skills/push-jira` | `.../skills/push-jira/SKILL.md` | Modified | MCP namespace param (G8), strip attribution/Unicode (WS-K), `--dry-run` (G10) |
| `skills/import` (new) | `.../skills/import/SKILL.md` | New | Legacy migration assistant (WS-I) — *conditional* |
| `agents/edm-test-coverage-auditor` | `.../agents/edm-test-coverage-auditor.md` | Modified | **G1 — add `Write` (P0)** |
| `agents/edm-architect` | `.../agents/edm-architect.md` | Modified | Canonical architecture artifact (WS-D) |
| `agents/edm-explorer` | `.../agents/edm-explorer.md` | Modified | Canonical explorer-findings home + synthesis (WS-D) |
| `agents/edm-qc-auditor` | `.../agents/edm-qc-auditor.md` | Modified | Sharding, PARTIAL verdict, deferred-to-runtime ACs (WS-C) |
| Audit lens agents (×11) + synthesizer | `.../agents/edm-audit-*.md` | Modified | Round/lens-subset behavior, severity-vocab unification (WS-B, G9) |
| `agents/*` (all 29) | `.../agents/*.md` | Modified | `<example>` blocks to match CHANGELOG claim (G2) |
| `bin/edm-state` | `.../bin/edm-state` | Modified | New subcommands (round index, ledger, mode/partial state, parent/related, PARTIAL), metrics impl (G3,G7), typed values, locking, git-aware archive, ASCII output (G15) — WS-A/B/C/F/G/J |
| `bin/edm-init` / `edm-validate-prefix` | `.../bin/{edm-init,edm-validate-prefix}` | Modified | Prefix regex reconcile (G12), stale message (G13), mode-aware scaffold (WS-E/F) |
| `hooks/hooks.json` | `.../hooks/hooks.json` | Modified | Deterministic gate enforcement (WS-J), artifact lint (WS-K), QC sharding hook (WS-C) |
| `plugin.json` (×2) | `.../plugin.json`, `.../.claude-plugin/plugin.json` | Modified | De-dup (G16), new userConfig (modes, compliance, regulated, jira namespace) |
| `README.md` / `CHANGELOG.md` / `CLAUDE.md` | `.../{README,CHANGELOG,CLAUDE}.md` | Modified | Fix claims/paths (G2,G16), document new modes/artifacts, revisit non-migration stance (WS-I) |
| `agents/edm-srd-writer` / `edm-ticket-writer` | `.../agents/edm-srd-writer.md`, `edm-ticket-writer.md` | Modified | Audit-pattern pre-emption guidance embedded in writer prompts (WS-L) |
| `docs/audit-patterns/` (new) | `.../docs/audit-patterns/` | New | Per-audit-type "what auditors look for" reference — one doc per audit type (WS-L) |
| `bin/edm-init` (extended path handling) | `.../bin/edm-init` | Modified | `--product`/`--description` args; product-dir scaffolding; writes `product_name` + `initiative_description` to state (WS-M) |
| `bin/edm-validate-prefix` (product scope) | `.../bin/edm-validate-prefix` | Modified | Product-scoped uniqueness check; `edm-state migrate-path` helper (WS-M) |
| `bin/edm-state` (`current_step` + `Resume Point`) | `.../bin/edm-state` | Modified | `current_step` field; `write-handoff` populates `## Resume Point` section (WS-N) |
| `hooks/hooks.json` (`SessionStart` resume injection) | `.../hooks/hooks.json` | Modified | On active-initiative detect: inject `## Resume Point` at top of session context (WS-N) |

## Constraints

- **No build/test/CI in the marketplace repo** (per repo CLAUDE.md) — the plugin is markdown + bash + JSON. "Tests" for EDMV2 = `claude plugin validate`, sandbox runs, and bash unit checks for `edm-state`.
- **Marketplace conventions (hard rules):** gitmoji shortcodes only (no Unicode emoji); **no AI-attribution trailers** in commits; git commands as separate parallel Bash calls (no `&&`); explicit `git add` by name; do **not** add `requires:{mcp:[]}` to marketplace.json. EDMV2 must both *obey* these and *fix the plugin's violations of them* (WS-K, G15).
- **`bin/` scripts must be POSIX-compatible bash** and operate on the project CWD (no plugin-relative paths).
- **Backward compatibility:** existing in-flight initiatives (DCAUTHZ, DCHELP, etc.) and their `.edm-state.json` files must keep working; state-schema changes must be additive/migratable.
- **Self-hosting risk:** EDMV2 is built *with* the plugin it modifies. Changing `edm-state`/hooks mid-initiative could disrupt EDMV2's own state — sequence carefully (don't break the running methodology).
- **Source-doc authority:** the methodology doc is `ai-assisted-development-methodology.md` v2.0.0 ("AI-Assisted Development Methodology"); the plugin rebranded it "Enterprise." Confirm the doc is canonical before treating every delta as a defect (some divergence may be deliberate).
- **The corpus is a separate repo** (`scripps-mcp/SRD`); EDMV2 only *reads* it for evidence — it does not modify those initiatives (unless WS-I migration is explicitly chosen, and even then only as an opt-in tool the user runs).

## Dependency Map

- **WS-A (correctness)** is foundational and mostly independent — it unblocks trust in the testing layer (G1) and metrics (G3) that later workstreams report through. **Do first.**
- **WS-D (artifact homes)** and **WS-J (state schema)** are infrastructure that several others build on: WS-B's findings ledger, WS-C's QC artifact, WS-F's mode state, and WS-G's parent/related links all need new artifact slots and/or `.edm-state.json` fields. **Do early.**
- **WS-B (audit convergence)** and **WS-C (QC scale)** are independent of each other but both touch `edm-state` (round/pass + ledger) — coordinate the schema once (via WS-J).
- **WS-E (adaptation modes)** depends on a **mode concept** in `orchestrator` + `edm-state` that **WS-F (lifecycle modes)** also needs — design the mode/profile model once and share it.
- **WS-G (product-line linkage)** needs the parent/related state field (WS-J) before SRD/orchestrator can consume it.
- **WS-H (multi-stack tests)** is largely self-contained in the test layer but assumes the per-epic artifact convention from WS-D.
- **WS-I (legacy migration)** is the most decoupled — a new `/edm:import` skill — but depends on a stable canonical layout (so do it after WS-A/D settle).
- **WS-K (conventions/templates)** is cross-cutting and low-risk; can land alongside WS-A.
- **WS-L (audit-informed quality)** can begin its analysis phase in parallel with any workstream — analysis is read-only. Writer-agent updates should land *after* the audit analysis is complete and after WS-B/C audit artifact contracts settle.
- **WS-M (directory structure)** is foundational plumbing with the highest blast radius of any workstream — it changes every path reference across skills, agents, bin scripts, and hooks. Must land **before** any workstream that adds new path references; coordinate schema extension with WS-J (state) and WS-D (artifact homes). Existing initiatives must remain functional throughout.
- **WS-N (compaction resilience)** is self-contained in `edm-state` + hooks, with no conflict risk with other workstreams. Prioritize early to protect EDMV2's own implementation runs against context compaction.

## Complexity Estimate

- **Files affected:** ~40-60 across `skills/` (13), `agents/` (up to 29 for G2 alone), `bin/`, `hooks/`, manifests, docs — depending on scope tier.
- **New modules:** 0-3 (e.g., `skills/import`, a shared mode/profile module in `edm-state`, new agent(s) for compliance/IaC/data-ML QC).
- **Integration points:** `edm-state` schema (consumed by hooks, skills, metrics), the hook system, the orchestrator's phase/gate flow.
- **Estimated size — depends on the scope decision below:**
  - **Foundation** (WS-A + WS-J + WS-D): **Small-Medium, ~20-30 tickets.**
  - **Core** (Foundation + WS-B + WS-C + WS-E mini-SRD/adaptation + WS-K): **Medium-Large, ~45-60 tickets.** *(Recommended)*
  - **Comprehensive** (all workstreams incl. WS-L/M/N additions, excl. legacy migration): **Large, ~95-115 tickets.**

## Open Questions

**Resolved at Gate 1** (see Decisions Made):
- ~~[DECISION] Scope ambition~~ → **Comprehensive (~75-90 tickets)**
- ~~[DECISION] WS-A delivery~~ → **Epic 1 of EDMV2**
- ~~[DECISION] Legacy migration (WS-I)~~ → **Excluded**
- ~~[DECISION] Adaptation modes (WS-E)~~ → **All four + prototype**

**Still open — deferred to SRD** (proposed defaults noted; user may override):
- [OPEN] Retarget `push-jira` to this marketplace's `jira` plugin / Confluence vs. keep MCP-agnostic (G8). *Proposed:* make the MCP server name a userConfig value, support both `MCP_DOCKER` and `plugin_jira_atlassian-mcp-server` namespaces, default to the marketplace `jira` plugin; project `ELI`.
- [OPEN] Is `ai-assisted-development-methodology.md` v2.0.0 the canonical spec? *Proposed:* treat the v2.0.0 doc as the authoritative reference for WS-E adaptation modes; the plugin's "Enterprise" rebrand and web-stack testing focus are intentional, retained divergences — not defects.

## Decisions Made

- **Scope ambition: Comprehensive (~75-90 tickets — Large).** In scope: WS-A (correctness defects), WS-B (audit convergence), WS-C (QC scale & verdict fidelity), WS-D (canonical artifact homes), WS-E (adaptation modes — all four + prototype), WS-F (lifecycle modes), WS-G (product-line linkage), WS-H (multi-stack tests), WS-J (state integrity & determinism), WS-K (conventions/templates). **Out of scope:** WS-I (legacy migration).
- **WS-A correctness defects → Epic 1 of EDMV2.** Tracked in-initiative with full QC rather than fast-tracked separately, so all 17 fixes (incl. G1 broken coverage-auditor, G3 overstated metrics) are auditable within the methodology.
- **Legacy migration (WS-I) → EXCLUDED.** Keep the ~15 legacy initiatives frozen; respect the plugin's current "does NOT migrate" design decision; candidate for a future version once the core is hardened.
- **Adaptation modes (WS-E) → ALL FOUR + prototype.** mini-SRD (fused small-initiative mode), compliance review gate (Gate 3.5) + regulatory traceability, IaC profile (resource paths + `terraform plan`/drift QC), data/ML profile (Data Requirements section + model-metric QC), and the documented prototype (Phase 1-2 only) mode.
- **(Deferred to SRD)** push-jira MCP retarget and canonical methodology-doc authority — proposed defaults recorded under Open Questions.
- **Post-Gate-1 scope additions (user-directed):**
  - **WS-L (Audit-Informed Artifact Quality):** systematic per-audit-type analysis feeds back into writer-agent prompts and templates to reduce audit churn. In scope.
  - **WS-M (Initiative Directory Structure):** adopt `SRD/{PRODUCT}/{PREFIX}__{DESCRIPTION}/` layout with product-level grouping and human-readable initiative names. In scope; highest blast radius — sequence first.
  - **WS-N (Compaction Resilience):** step-level `## Resume Point` in HANDOFF.md; `current_step` state field; `SessionStart` hook injects resume context; orchestrator resume branch reads step. In scope; prioritize early.
  - **G18 (code-audit as mandatory phase):** `/edm:code-audit` moved from optional post-Phase-6 suggestion to a mandatory orchestrated phase. Added to WS-A (Epic 1).
  - **Gate false-positive fix:** free-text "Other" input at HITL gates must never trigger `edm-state approve-gate`; only explicit "Approve" selection counts. Added to WS-J.
