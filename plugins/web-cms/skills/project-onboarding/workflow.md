# PROJECT-ONBOARDING WORKFLOW — EXECUTION CONTRACT

> **How this works:** This workflow onboards a project so AI agents (and humans) can contribute to it effectively. It thoroughly investigates the codebase, auto-detects everything it can, interviews the user only for the gaps it cannot infer, then generates or enhances five documentation files in the project root: `README.md`, `CONTRIBUTING.md`, `CONTEXT.md`, `CLAUDE.md`, and `WORKFLOWS.md`. Alongside those it also writes a thin cross-agent `AGENTS.md` (pointing to `CLAUDE.md`), embeds mermaid architecture/data-flow diagrams in `CONTEXT.md`, and creates short nested per-module docs in large subdirectories. It runs in **initial mode** on a project that lacks these docs (full generation) and **refresh mode** on a project that already has them (reconcile against the current codebase, flag drift, preserve human-authored content, update only what changed). The same O0-O6 phase sequence applies in both modes.

**STRICT EXECUTION RULES — NO EXCEPTIONS:**

1. Execute phases in strict sequential order (O0 through O6).
2. Do not skip, reorder, or combine phases.
3. Each phase must be fully completed before starting the next.
4. If any phase fails, stop immediately and report the failure in the chat. Do not continue.
5. Every required output must be presented in the chat before the phase is considered complete.
6. **Do not create, overwrite, or edit any of the five documentation files until O4 is reached and its outline/drift report is approved.** No blind overwrite of an existing doc, ever.

**APPROVAL GATE BEHAVIOR:** Approval gates are chat-scoped. If explicit approval is not captured before the session ends or context is lost, stop at the gate. On resume, re-present the latest summary, outline, or drift report and ask for confirmation again. Never assume a pending approval was granted.

**CLARIFICATION RULE:** Do not assume facts about the project's conventions. Auto-detect first; where a fact is genuinely underivable from the codebase (branch naming policy, Jira spaces, review process, deploy flow), stop and use `AskUserQuestion`. Never invent a command, path, convention, or Jira key — every fact written into the docs must trace back to real evidence from the codebase (O1/O2) or an explicit user answer (O3).

**AUTO-DETECT-FIRST PRINCIPLE:** The interview in O3 asks the user *only* what O1 and O2 could not answer or must confirm. Do not re-ask anything already established from the codebase. A short interview is the goal.

**FILE MEMORY SCOPE:** This workflow stores session state in a per-work-item file-memory directory, keyed to the project being onboarded. Compute `MEM` once with the recipe in `file-memory-protocol.md` §1, using `<work-item-key>` = `onboarding-<project-slug>` where `<project-slug>` is the normalized basename of the project root (slug rules per §2). It reuses the shared `explorations/*.md` findings surface and a light `checkpoint.md`; it does **not** use the Jira `work-item.md` machinery. Files used:

- `$MEM/discovery.md` — O1 auto-detected signals (stack, commands, structure, VCS conventions, available skills) and the detected mode. This is the root/anchor file.
- `$MEM/explorations/*.md` — O2 codebase-explorer findings (schema §3.4).
- `$MEM/clarifications.md` — O3 interview answers (schema §3.5).
- `$MEM/checkpoint.md` — overwritten after every phase (schema §3.2); the recall surface.

See `file-memory-protocol.md` for the path recipe, the `checkpoint.md`/`clarifications.md`/`exploration` schemas, and the checkpoint/compaction contract. This workflow does not participate in `work-item.md` enumeration, so `/compact-context` will not auto-discover it — instead this workflow carries its own compaction gate at O2.

**SUB-AGENT NAME RESOLUTION:** This workflow refers to sub-agents by short name (`codebase-explorer`, `area-mapper`). The runtime registers them under different identifiers depending on how they are installed. Before the first sub-agent invocation, resolve each short name against the runtime's available-agents list and use the exact registered identifier:

- If the short name appears verbatim in the list (agents deployed into the project's `.claude/agents/`), use it as-is.
- If installed via the plugin, the registered identifier is `web-cms:<short-name>:<short-name>` — e.g. `codebase-explorer` → `web-cms:codebase-explorer:codebase-explorer`.
- Never invent a partial form such as `web-cms:codebase-explorer` — it will not resolve. If an invocation fails with an "agent type not found" error, read the available-agents list in the error message, select the entry whose **final segment** equals the short name, and retry with that exact identifier.
- Resolve the scheme once, then reuse it for every subsequent sub-agent invocation in the session.

**TOOL PREFERENCE:** Prefer native tools over Bash for filesystem work. All filesystem, search, and directory operations must stay within the target project directory.

- **File I/O (read, write, edit a known file):** Use native `Read`, `Write`, `Edit`.
- **File discovery (find files by name or pattern):** Use native `Glob`.
- **Content search (find text inside files):** Use native `Grep`. For symbolic code search (finding classes, methods, or callers), delegate to the `codebase-explorer` agent, which uses the Serena MCP server.
- **Directory operations (list, metadata, move, mkdir):** Use Bash (`ls`, `stat`, `mv`, `mkdir -p`).
- **Git:** Use Bash for all git operations (`git status`, `git log`, `git branch`, `git remote`, etc.). Run git checks as **separate** Bash calls (never chained with `&&`).

**SERENA PROJECT ACTIVATION:** Before O1, check Serena's project-activation message (emitted on connect via `--project-from-cwd`); if it reports that onboarding has not been performed, call `onboarding` to scope Serena's language server to the target project directory. The `codebase-explorer` agents' symbol tools depend on this. Do this once at the start of the workflow; do not repeat it between phases.

**TASK TRACKING:** Always use task tracking (`TaskCreate`/`TaskUpdate`) so progress is visible throughout. Create one task per phase at the start of the workflow. Mark each task `in_progress` when starting the phase and `completed` when the phase is done:

- O0 — Intake & Mode Detection
- O1 — Automated Signal Discovery
- O2 — Deep Codebase Investigation
- O3 — Gap Analysis & Targeted Interview
- O4 — Outline / Drift Report & Approval
- O5 — Generate / Update Files
- O6 — Verification & Summary

**CHECKPOINT & COMPACTION CONTRACT:** This workflow records position in a single `$MEM/checkpoint.md` file (full schema and contract in `file-memory-protocol.md` §4).

**Per-phase checkpoint — after EVERY phase (O0–O5), automatically, with no chat output and no `/compact` prompt.** Atomically overwrite `$MEM/checkpoint.md` (`Write` to `checkpoint.md.tmp`, then `mv` over `checkpoint.md`) with `skill: project-onboarding`, `checkpoint_type: phase`, the just-completed `phase`, the upcoming `next_phase`, the `references` list, `## Decisions`, and `## Open items`. Set `jira_key: null` and `work_item_key: onboarding-<project-slug>`.

**Compaction gate (O2) — additionally prompt the user to `/compact`.** Do the per-phase write but with `checkpoint_type: gate`, then: (1) wait for any background `area-mapper` to finish; (2) emit the Phase Summary block (§4(b)) — phase + skill, work item key, one-line decisions, `next_phase`, the checkpoint file path, and the resume contract; (3) end the turn with the literal line **"Run `/compact` now, then type `continue` to resume."** Do NOT call `AskUserQuestion` at a gate.

**Universal resume rule — on ANY resume, before doing anything else:** `Read $MEM/checkpoint.md` → `Read` every file in its `references` → **re-read the `next_phase` section of this `workflow.md`** (any phase asking clarifying/structured questions MUST use `AskUserQuestion`) → continue at `next_phase`. If `$MEM` is absent, recompute it from the deterministic key (`onboarding-<project-slug>`) and restart the affected phase. Approval gates stay chat-scoped — never assume a pending approval was granted.

---

### O0 — Intake & Mode Detection

**Objective:** Resolve the target project, detect which of the five docs already exist to set the mode, bootstrap memory, and confirm scope with the user.

**Agent Actions:**

1. **Resolve the project root.** If `$ARGUMENTS` holds a path, `cd`-scope to it (do not change directories via chained `cd`; pass the path explicitly to commands). Compute `ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"` (Bash). Announce the resolved root. All doc files will be written to `$ROOT/`.

2. **Introduce yourself and explain** what this workflow will do (investigate the codebase, ask a few targeted questions, then generate/enhance five docs), the phases, the approval gates, and the end result.

3. **Detect mode.** `Glob "$ROOT/README.md"`, `CONTRIBUTING.md`, `CONTEXT.md`, `CLAUDE.md`, `WORKFLOWS.md` (case-insensitively; also check common alternates like `README.rst`, `docs/`). Count how many of the five exist.
   - **Initial mode:** none or only one or two exist → full generation.
   - **Refresh mode:** three or more exist → reconcile against the current codebase.
   Present the per-file status (exists / missing) and the proposed mode.

4. **In refresh mode, load the existing docs.** `Read` each existing target file into working memory so O2/O4 can diff its claims against reality. Note their apparent structure and any obviously human-authored sections to preserve. Also `Glob` for an existing `$ROOT/AGENTS.md` and any existing nested `CLAUDE.md`/`README.md` in subdirectories, and `Read` them so refresh mode reconciles rather than clobbers them (a content-bearing `AGENTS.md` is preserved — only its CLAUDE.md pointer is ensured).

5. **Activate Serena** (see SERENA PROJECT ACTIVATION above) once.

6. **Bootstrap file memory.** Compute `MEM = $MEMROOT/onboarding-<project-slug>` (recipe §1; `<project-slug>` = normalized basename of `$ROOT`). `mkdir -p "$MEM/explorations"` and apply the git-exclude step from §1. `Write $MEM/discovery.md` with a minimal frontmatter stub (`schema: web-cms-memory/summary@1` is not required here; use a simple `onboarding` header) recording `project_root`, `project_slug`, `mode`, `existing_docs`, and `created_at`. This is the root/anchor file; O1 fills in the detected signals.

> **REQUIRED:** Present before proceeding:
> - Resolved project root
> - Per-file existence status for the five docs
> - Detected mode (initial / refresh), with a one-line rationale
> - For refresh mode: a note of which files will be reconciled

> **APPROVAL GATE — FULL STOP.** Use `AskUserQuestion` (Header: `O0 Approval`, Question: `Is this the right project and mode? I'll onboard <root> in <mode> mode, writing/updating the five docs there.`, Options: `Approve and proceed (Recommended)` — root and mode are correct, `Request changes` — root, mode, or per-file handling needs correction). Do not proceed to O1 until the user approves. If the user wants a different per-file handling (e.g. force-regenerate one stale file, or leave one untouched), record it and honor it in O4/O5.

---

### O1 — Automated Signal Discovery

**Objective:** Detect everything derivable from the codebase directly, with no user questions, so the O3 interview can be as short as possible.

**Agent Actions (inline — use `Read`/`Glob`/`Grep`/Bash; do not ask the user anything here):**

1. **Project shape & stack.** Identify the manifest / package manager and language(s) & framework(s): `package.json`, `pnpm-lock.yaml`/`yarn.lock`/`package-lock.json`, `pyproject.toml`/`requirements.txt`, `go.mod`, `pom.xml`/`build.gradle`, `Cargo.toml`, `Gemfile`, `composer.json`, etc. Capture declared runtime/tool versions (`engines`, `.nvmrc`, `.python-version`, `.tool-versions`, `go` directive, etc.).

2. **Commands.** Extract the canonical build / test / lint / format / run / typecheck commands from real sources — `package.json` `scripts`, `Makefile` targets, `Taskfile`, `justfile`, `tox.ini`, `noxfile`, CI config, and any `bin/` or `scripts/` entry points. Record the exact command strings; do not paraphrase or invent.

3. **CI/CD & deploy signals.** `Glob`/`Read` `.github/workflows/*`, `.gitlab-ci.yml`, `Jenkinsfile`, `.circleci/`, `azure-pipelines.yml`, Dockerfiles, `docker-compose*.yml`, `Procfile`, k8s/helm manifests, deploy scripts. Note what runs on push/PR and any deploy/release automation.

4. **Structure & entry points.** Map top-level directories and their apparent roles; find entry points (`main`, `index`, server bootstrap, CLI entry). Note config files, env templates (`.env.example`), and where tests live.

5. **VCS conventions (inferable).** Two separate Bash calls: `git branch -a` and `git log --oneline -30`. Infer the default/integration branch, any branch-name patterns (e.g. `feature/PROJ-123-...`, `develop`), commit-message style (conventional commits, gitmoji, ticket prefixes), and any Jira/issue keys appearing in history. Also `Read` `CODEOWNERS`, `.gitmessage`, PR/MR templates (`.github/PULL_REQUEST_TEMPLATE*`, `.gitlab/merge_request_templates/`), and commit-lint / husky config if present.

6. **Existing docs & conventions.** `Read` any existing `README`/`docs/`, `.editorconfig`, linter/formatter configs (`.eslintrc*`, `.prettierrc*`, `ruff.toml`, `.golangci.yml`, `checkstyle`, etc.) to capture code-style facts and directory/file-naming patterns.

7. **Available web-cms plugin skills.** Detect whether this plugin's skills are available to the project so WORKFLOWS.md can be generated from the actual skill roster. `Glob` for `.claude/skills/*/SKILL.md` in `$ROOT`, and for a plugin `MANIFEST.md` / `skills/*/SKILL.md` if the plugin is installed. Enumerate which skills are present (names + one-line purpose from each `SKILL.md` description). If none are found, note that WORKFLOWS.md will fall back to plain task recipes.

8. **Read Serena project memory as hints.** `list_memories` and `read_memory` for any `codebase-map-*`, `test-commands`, `documentation-conventions` entries — treat as starting context to verify, not ground truth.

9. **Write findings** to `$MEM/discovery.md`: stack, versions, commands (verbatim), CI/deploy signals, structure map, inferred VCS conventions, code-style facts, available skills, and — importantly — an explicit list of **open gaps** (facts the docs need that the codebase did not reveal), which seeds O3.

> **REQUIRED:** Present a concise discovery summary: stack & versions; canonical commands (build/test/lint/run); structure map; inferred VCS conventions; available skills (or "none"); and the list of open gaps to resolve with the user. Label any low-confidence inference as `[INFERRED]`.

> **CHECKPOINT (O1):** Per-phase checkpoint. `phase: O1`, `next_phase: O2`, `references: [discovery.md]`. No user prompt.

---

### O2 — Deep Codebase Investigation

**Objective:** Go beyond surface signals — understand architecture, conventions, key modules, patterns, and gotchas an AI agent must know to contribute, with evidence.

**Agent Actions:**

1. From O1, identify the distinct areas worth exploring (e.g. core domain modules, API/service layer, data layer, frontend, build/tooling, test harness). Limit scope to the target project directory.

2. Invoke a `codebase-explorer` sub-agent in **parallel** for each distinct area, providing:
   - **target_area** — the area/module/path.
   - **question** — "What are the architecture, key modules and responsibilities, conventions (naming, directory organization, file naming, error handling), reusable patterns/utilities, integration points, and gotchas an AI agent must know to contribute to this area?"
   - **memory_dir** (`$MEM`) and a normalized **area_slug**. The explorer writes `$MEM/explorations/<area_slug>.md`.
   - **context** — the O1 discovery summary.

3. Wait for all explorers to return. Treat `INCOMPLETE` as partial (re-spawn if coverage matters); treat `FAILED` as no file written (re-spawn before proceeding).

> **POST-EXPLORATION ENRICHMENT:** Spawn the `area-mapper` sub-agent **in the background** (`run_in_background: true`) with the same `memory_dir` (`$MEM`). It crystallizes durable area knowledge into Serena project memory for future runs. Do not wait for it — proceed to step 4.

4. `Read` each `$MEM/explorations/<area_slug>.md`. Re-spawn any missing/empty file. Surface `open_questions`. If a finding reveals a connected area not yet explored, dispatch a follow-up `codebase-explorer` (same `memory_dir`) before proceeding.

5. **Synthesize** across all explorations: architecture & module map, domain concepts, data models, external integrations, code conventions (naming/directory/file-naming/style), reusable patterns, risks, and known gotchas. In **refresh mode**, additionally **diff the synthesis against the existing docs loaded in O0** and record concrete drift items (commands/paths that no longer exist, moved directories, new integrations, changed conventions, newly available skills).

6. **Identify diagram inputs and nested-doc targets.** From the synthesis, capture the component relationships and a representative data-flow/request lifecycle needed for the **CONTEXT.md mermaid diagrams** (real modules and edges only). Also flag the **large/complex subdirectories that warrant a nested per-module doc** — those with substantial size, distinct concern, or non-obvious local conventions; skip small/leaf directories. Record the proposed nested-doc target list in `discovery.md` for the O4 gate.

> **REQUIRED:** Present the synthesized investigation: architecture/module map; domain concepts & data models; external integrations; code conventions with evidence; patterns to reuse; risks/gotchas; the planned CONTEXT.md diagrams; and the proposed nested-doc target subdirectories. In refresh mode, also present the per-file **drift list**. Label `inferred: true` items as `[INFERRED]`.

> **APPROVAL GATE — FULL STOP.** Use `AskUserQuestion` (Header: `O2 Approval`, Question: `Does the codebase investigation look accurate and complete?`, Options: `Approve and proceed (Recommended)` — investigation is accurate, `Request changes` — something needs correction). Do not proceed to O3 until the user approves.

> **COMPACTION GATE — O2:** Once O2 approval is confirmed, follow the Checkpoint & Compaction Contract (gate path). Write `checkpoint.md` with `phase: O2`, `next_phase: O3`, `checkpoint_type: gate`, `references: [discovery.md, explorations/*.md]`; `## Decisions`: confirmed architecture and conventions (and, refresh mode, the drift list). Emit the Phase Summary block and instruct the user to run `/compact` before proceeding to O3.

---

### O3 — Gap Analysis & Targeted Interview

**Objective:** Resolve only the facts the five docs need that the codebase could not reveal. Keep the interview short.

**Agent Actions:**

1. Review O1 `discovery.md` (open gaps) and O2 findings.

2. > **USE SEQUENTIAL THINKING:** Invoke the `sequentialthinking` tool. Work through each doc's required content against what O1+O2 already answered, and produce the minimal set of genuinely-unresolved questions. Do not present questions until this reasoning is complete. Never ask something already established from the codebase.

3. Build the question list from the categories below — **include a category only if it is still unresolved after O1/O2.** Mark each `[BLOCKING]` (a doc can't be written correctly without it) or `[NICE TO HAVE]`.

   - **Branch naming** — the branch-name convention (if not clearly inferable from history).
   - **Branching & merge model** — the integration/working branch (e.g. `develop`), branch types and lifecycles, epic/task branch strategy, and what each branch/MR targets (e.g. epic branch → MR into `develop` when complete).
   - **Commit convention** — commit-message format/scope rules, if not enforced by config.
   - **Review process** — PR vs MR platform, reviewers/approval rules, required CI checks, CODEOWNERS usage.
   - **Jira spaces** — the Jira project key(s)/spaces this project uses and the ticket workflow (how tickets map to branches/commits). Optionally confirm against read-only `jira_get_all_projects`.
   - **Testing policy** — pre-merge checks, coverage thresholds, Definition of Done, where new tests must live.
   - **Deploy/release** — how deploys happen, environments (dev/staging/prod), release cadence.
   - **Secrets/config** — how secrets and environment config are handled; what must never be committed.
   - **Code style specifics** — any conventions not captured by config or inferable from code.
   - **Logging conventions** — logger/framework, log levels and when to use each, structured vs. plain format, correlation/trace IDs, and what must never be logged (if not inferable from the code).
   - **Domain/context** — domain glossary terms or non-obvious design decisions an agent should know.
   - **Danger zones** — what an agent must NOT touch (generated code, vendored dirs, lockfiles, sensitive modules).
   - **Ownership/contacts** — maintainers, teams, or contacts for the README.

4. Ask each question via a separate `AskUserQuestion` call, one per call, short Header (≤12 chars), with the `[BLOCKING]`/`[NICE TO HAVE]` tag in the question text. For open-ended answers use options `Provide answer` (description: "Type your response in the Other field") and, for non-blocking questions only, `Skip` (description: "Skip this non-blocking question"). For closed-enum questions use specific options. If a detected value needs only confirmation, offer it as the first option (e.g. `Yes, develop`).

5. Record all answers verbatim to `$MEM/clarifications.md` (schema §3.5), tagging each with its category and priority.

> **REQUIRED:** Present a consolidated recap of the answers gathered (or "no gaps — everything was auto-detected").

> **APPROVAL GATE — FULL STOP.** Use `AskUserQuestion` (Header: `O3 Approval`, Question: `Are these answers correct and complete before I draft the docs?`, Options: `Approve and proceed (Recommended)` — answers are correct, `Request changes` — something needs correction). Do not proceed to O4 until the user approves.

> **CHECKPOINT (O3):** Per-phase checkpoint. `phase: O3`, `next_phase: O4`, `references: [discovery.md, explorations/*.md, clarifications.md]`.

---

### O4 — Outline / Drift Report & Approval

**Objective:** Get sign-off on exactly what each file will contain (initial) or exactly what will change (refresh) before writing anything.

**Agent Actions:**

1. Assemble the planned content for each of the five root docs **plus `AGENTS.md`** from O1/O2/O3, following the **file responsibilities** below. Respect the single-source-of-truth rules (no duplication; cross-links instead).

2. **Initial mode:** present a concise **outline** per file — the section headings and the key facts each will contain — including the planned **CONTEXT.md mermaid diagrams** and the **proposed list of nested per-module docs** (which subdirectories get one, and whether each is `CLAUDE.md` or `README.md` to match the repo's convention).
   **Refresh mode:** present a **drift report** per file — what's stale (to fix), what's missing (to add), what's outdated (to update), and which human-authored content will be **preserved untouched** — and reconcile any existing nested docs / diagrams. For an existing content-bearing `AGENTS.md`, only ensure the CLAUDE.md pointer is present; do not rewrite its content. Show it as a per-file change list, not a full rewrite.

3. Never propose a blind overwrite. Honor any per-file handling the user set at O0.

> **APPROVAL GATE — FULL STOP.** Use `AskUserQuestion` (Header: `O4 Approval`, Question: `Approve these outlines/changes? I'll write the files exactly as described.`, Options: `Approve and proceed (Recommended)` — write the files as outlined, `Request changes` — adjust the outline/drift plan first). Do not write any documentation file until the user approves.

> **CHECKPOINT (O4):** Per-phase checkpoint. `phase: O4`, `next_phase: O5`.

---

#### File responsibilities (avoid overlap — single source of truth per fact)

- **README.md** — human-facing overview: what the project is (one-liner + summary), tech stack, prerequisites (**required tool/runtime versions**), install/setup, **environment variables & config needed to run**, run / build / **test** commands, high-level directory structure, **setup troubleshooting**, **maintainers/ownership + contacts**, and links to the other four docs.

- **CONTRIBUTING.md** — process **and code standards**. Authoritative home for:
  - **Branching & merge model** — the integration/working branch (e.g. `develop`), branch types and their lifecycles, epic branches, task branches cut from and merged back into the epic branch, and what each branch/MR targets (e.g. epic branch → MR into `develop` when complete).
  - Branch naming, commit convention, PR/MR + review/approval flow.
  - **Jira spaces/project key(s)** and ticket linking — this is the authoritative list (CLAUDE.md and WORKFLOWS.md only point here).
  - **Code style & conventions** — formatter/linter rules, language idioms, **directory organization** (where things go), **file naming conventions**, import ordering, project-specific patterns.
  - **Logging conventions** — which logger/framework to use, log levels and when to use each, structured vs. plain format, correlation/trace-ID propagation, and what must **never** be logged (secrets, PII, tokens). (The logging *architecture* — where logs go, aggregation — lives in CONTEXT.md observability.)
  - **Testing conventions** — where tests live, naming, coverage thresholds; a **Definition of Done**.
  - **Dependency-management rules** — how to add/update deps, lockfile discipline.
  - **Secrets handling** — never commit secrets; how config/secrets are managed.
  - **PR/MR description/template + CODEOWNERS/reviewer-selection** expectations.
  - Local dev setup specifics.
  These are sourced primarily from O2 explorer findings (evidence-backed) and confirmed/supplemented in O3 — not invented.

- **CONTEXT.md** — architecture & domain reference, written for **AI reasoning as well as human onboarding** (distinct from README's user-facing overview). Include the following sections, each adapted to what the project actually has (omit a section only when it genuinely does not apply, and say so):
  - **System overview** — what the system is architecturally, who it's for, and the major technologies (a table works well).
  - **Repository layout** — an **annotated directory tree** explaining the *purpose* of each top-level area, not an exhaustive file listing.
  - **Architecture & component map** — modules/services and their responsibilities, plus a **mermaid** component/architecture diagram.
  - **Domain model** — entities, primary keys, key fields, and foreign-key relationships; include an **ERD** (mermaid `erDiagram` or an ASCII ERD) when the codebase has a data model. Plus a domain glossary of key terms.
  - **API surface / application boundaries** — the app's own route patterns, HTTP methods, and response/error conventions (or the CLI commands / public interfaces / entry points for non-web projects).
  - **Data flows / request lifecycle** — a **mermaid** flow of a representative request or operation end to end.
  - **Architectural patterns & conventions** — where business logic lives, how data access works, and how errors are handled and propagated. (Fine-grained style/naming rules live in CONTRIBUTING.md — cross-reference, don't duplicate.)
  - **External integrations** — APIs, databases, queues, third-party services.
  - **Environment topology** — dev/staging/prod and how they differ.
  - **Auth/security model** — how authentication and authorization work.
  - **Observability** — logging, metrics, and tracing **architecture** (where logs/metrics go, aggregation, correlation/trace IDs). Developer-facing logging *conventions* live in CONTRIBUTING.md.
  - **Known gaps & constraints** — explicitly call out what is mocked, stubbed, missing, or deliberately deferred (e.g. "auth is mocked in dev", "no service layer yet"), plus notable design decisions and known tech debt/limitations.
  - **Pointers (no duplication)** — build/run/test **commands** live in README.md and the CLAUDE.md golden path; **environment variables** in README.md; **testing strategy** in CONTRIBUTING.md — CONTEXT.md links to these rather than restating them.

  Embed **mermaid diagrams** in ` ```mermaid ` fences — at minimum a component/architecture diagram, plus a data-flow / request-lifecycle diagram (and an ERD where a data model exists) — reflecting real modules and edges from the O2 investigation, not decorative placeholders. Follow the source guidance ([github.com/orgs/community/discussions/191257](https://github.com/orgs/community/discussions/191257)): keep it a **living document**, prefer **structured data** (tables, ERDs) for efficient parsing, and focus on **constraints and anti-patterns** over generic positive advice.

- **CLAUDE.md** — *lean agent operating index* (concise; links out, never duplicates):
  - A copy-pasteable **golden-path** block (setup → build → test → lint → run), using the verbatim commands from O1.
  - Critical conventions (one-liners) and the exact **verification loop** to confirm a change works.
  - Known gotchas and an explicit **do-not-touch** list (generated code, vendored dirs, lockfiles, danger zones from O3).
  - A **"when unsure, ask/escalate"** rule and a note of available tooling (MCP servers, Serena) the agent can use.
  - A one-line **Jira project key(s)** pointer (authoritative list lives in CONTRIBUTING.md).
  - **Skill-suggestion behavior:** instruct the agent that when a user's request matches a documented skill's trigger (e.g. "start a new feature" → `/requirements-intake`, "implement PROJ-123" → `/task-card`, "fix this bug" → `/bug-card`), it should *suggest running that skill* rather than doing the work ad hoc, and consult WORKFLOWS.md for the mapping.
  - Pointers to README / CONTEXT / CONTRIBUTING / WORKFLOWS for detail.

- **WORKFLOWS.md** — *skill-driven development lifecycle*, generated from the skills detected in O1 (not hard-coded):
  - For each available skill: what it does, **when to run it**, what it takes/produces, and its **prerequisites** (e.g. needs a Jira key / branch state).
  - How the skills chain (intake → execution → review → MR), and how the CONTRIBUTING.md branching & merge model is **enacted via the skills** — e.g. epic branch ↔ `/epic-card`, task branches ↔ `/task-card`, epic→`develop` MR ↔ `/mr-creation` — referencing (not redefining) the model in CONTRIBUTING.md.
  - The **trigger conditions/phrases** so an agent or human recognizes which skill applies to a request.
  - A quick **"I want to X → run Y" decision table** and an end-to-end **lifecycle diagram** (idea → intake → epic/task → implement → review → QA → MR → document).
  - How checkpoints / `/compact-context` work during long skill runs.
  - **Fallback:** if the plugin skills are not present in the project, WORKFLOWS.md instead documents plain task recipes (add-a-feature, fix-a-bug, run locally, release) built from the O1/O2 commands and conventions.

- **AGENTS.md** — a thin **cross-agent pointer**, not a content file. A short intro line plus a directive to read `CLAUDE.md` as the authoritative agent operating guide, and README / CONTEXT / CONTRIBUTING / WORKFLOWS for detail. It exists so non-Claude tools (Cursor, Codex, Aider, etc.) land on the same golden path and guardrails. Keep it to a few lines; do not duplicate CLAUDE.md content. If the project already has a content-bearing `AGENTS.md`, leave that content intact and only ensure the pointer to `CLAUDE.md` is present.

- **Nested per-module docs** — for the large/complex subdirectories flagged in O2, a short doc placed *in that subdirectory* named to match the repo's existing convention (`CLAUDE.md`, or `README.md` if the repo already uses per-directory READMEs): what the module does, its key files/entry points, local conventions, and gotchas. Keep each brief and **link up to the root `CONTEXT.md`** rather than duplicating it. Only create these for directories that genuinely warrant local context; skip small/leaf directories. The target set is proposed and approved at O4.

---

### O5 — Generate / Update Files

**Objective:** Write the approved content into the target project root, preserving human-authored content in refresh mode.

**Agent Actions:**

1. Write into `$ROOT/` exactly as approved in O4.
   - **Initial mode:** `Write` each of the five root docs in full; `Write` `AGENTS.md` as the thin pointer to `CLAUDE.md`; embed the approved mermaid diagrams in `CONTEXT.md`; and `Write` each approved nested per-module doc into its subdirectory.
   - **Refresh mode:** apply **surgical `Edit`s** — update only the drifted sections, preserve author voice and hand-written content, and do not churn unchanged prose. Only `Write` a file wholesale if it did not previously exist or the user explicitly approved a full regenerate at O0/O4. For a content-bearing `AGENTS.md`, edit in only the missing CLAUDE.md pointer.

2. Keep everything cross-linked: CLAUDE.md points to README/CONTEXT/CONTRIBUTING/WORKFLOWS; README links to the other four; AGENTS.md points to CLAUDE.md; each nested per-module doc links up to the root CONTEXT.md; the Jira keys live only in CONTRIBUTING.md with pointers elsewhere.

3. Use only verbatim commands/paths captured in O1 and facts confirmed in O2/O3. Do not introduce any command, path, or convention not grounded in evidence. Mermaid diagrams must reference real modules/edges only.

> **REQUIRED:** List every file written or edited (root docs, `AGENTS.md`, and each nested doc), with a one-line note of what changed.

> **CHECKPOINT (O5):** Per-phase checkpoint. `phase: O5`, `next_phase: O6`.

---

### O6 — Verification & Summary

**Objective:** Confirm the docs are correct, internally consistent, and grounded, then summarize.

**Agent Actions:**

1. Confirm all five root docs, `AGENTS.md`, and each approved nested per-module doc exist in `$ROOT/` (and their subdirectories) and are non-empty (`Glob`/`Read`).
2. Verify cross-links resolve (each referenced doc exists, AGENTS.md → CLAUDE.md, nested docs → root CONTEXT.md).
3. Confirm the `CONTEXT.md` **mermaid fences are well-formed** (opened/closed ` ```mermaid ` blocks, valid node/edge syntax) and reference real modules.
4. **No invented commands/paths:** for every command and path written into the docs, confirm it actually exists in the project (a real script/target/config from O1, or a real directory). Flag and fix any that don't.
5. Present a **summary table**: per file (incl. `AGENTS.md` and nested docs) — created / enhanced / refreshed, and the key facts captured; plus, in refresh mode, the drift items resolved.

> **REQUIRED:** Present the verification results and the summary table. Note that the session memory under `$MEM` can be discarded (it holds only transient onboarding state); offer to remove it with `rm -rf "$MEM"` on the user's confirmation, or leave it for a future refresh run.

> **CHECKPOINT (O6):** Per-phase checkpoint. `phase: O6`, `next_phase: done`. The workflow is complete.
