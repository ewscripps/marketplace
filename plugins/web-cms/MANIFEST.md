# Skills & Agents -- Workflow Topology

This project defines Claude Code skills and agents for creating and implementing Jira cards. The system has two tiers: **intake skills** that gather context and create Jira cards, and **execution skills** that read those cards and do the work.

## Architecture

```
INTAKE (creates Jira cards)          EXECUTION (works Jira cards)
=============================        =============================

/requirements-intake (R0-R6)  --->   /task-card PROJ-123 (T0-T13)
  Creates Epic or Task card          /epic-card PROJ-123 (E0-E11)

/design-intake (R0-R6)        --->   /task-card PROJ-123 (T0-T13)
  Creates Epic or Task card          /epic-card PROJ-123 (E0-E11)
  (design-focused feature)

/issue-intake (I0-I6)         --->   /bug-card PROJ-123 (B0-B15)
  Bug? Creates Bug card                OR
  Missing requirement?        --->   /requirements-intake (R0-R6)

/code-review-intake (CI0-CI5) --->   /code-review PROJ-123 (CR0-CR11)
  Creates Code Review card

                                       /implementation-discovery (D0-D5)
                                         Pre-intake -- explores how to build or
                                         change something before requirements

                                       /mr-creation (M0-M8)
                                         Standalone -- creates GitLab MR

                                       /test-doc-review [PROJ-123] (TD0-TD5)
                                         Standalone -- independently runs test-reviewer and documentation-reviewer; skips TD0 when no Jira key is provided

                                       /manual-qa-plan PROJ-123 (Q0-Q4)
                                         Standalone -- reviews Jira context plus related branch diff, generates manual QA steps, and appends the plan to the issue description

                                       /document-card PROJ-123 (DC0-DC8)
                                         Standalone -- documents completed work

                                       /project-onboarding [path] (O0-O6)
                                         Standalone -- generates or refreshes
                                         README, CONTRIBUTING, CONTEXT, CLAUDE,
                                         and WORKFLOWS docs for AI-agent use

                                       /compact-context
                                         Standalone utility -- checkpoint the active
                                         workflow session and prompt /compact
```

## Contract Between Tiers

The Jira card description is the interface between intake and execution:

- **Intakes** produce structured card descriptions with well-known section headers (`## Task Details`, `## Bug Details`, `## Acceptance Criteria`, `## Affected Areas`, etc.)
- **Execution skills** read the card description and consume those sections by name
- **Workflows are NOT embedded** in card descriptions -- each card contains only the structured work context needed by the downstream execution skill. Persisted Jira descriptions must not include workflow instructions, skill-invocation text, or temporary placeholders.
- The execution workflow lives in the skill's `workflow.md` file and is loaded when the user invokes the appropriate skill
- Jira comments are part of the durable execution record only when a workflow explicitly requires them. For `task-card`, use the minimal structured comment set defined in that workflow (one combined T4/T5 plan-and-approval comment, T11 user testing handoff when applicable, T12 summary, and failure comments) rather than phase-by-phase narration.

## Skills

### Intake Skills

| Skill | Invocation | Phases | Output |
|-------|-----------|--------|--------|
| **requirements-intake** | `/requirements-intake` | R0-R6 | Epic or Task card in Jira |
| **design-intake** | `/design-intake` | R0-R6 | Epic or Task card in Jira with design specifications (colors, typography, component states, accessibility) |
| **issue-intake** | `/issue-intake` | I0-I6 | Bug card in Jira, or transitions to requirements-intake |
| **code-review-intake** | `/code-review-intake` | CI0-CI5 | Code Review (Task) card in Jira |

### Execution Skills

| Skill | Invocation | Phases | Input | Sub-agents Used |
|-------|-----------|--------|-------|-----------------|
| **task-card** | `/task-card PROJ-123` | T0-T13 | Task card description | codebase-explorer, area-mapper, plan-reviewer, comment-reviewer, verification-runner, implementation-builder, implementation-reviewer, code-quality-reviewer, test-reviewer, documentation-reviewer |
| **bug-card** | `/bug-card PROJ-123` | B0-B15 | Bug card description | codebase-explorer, area-mapper, plan-reviewer, comment-reviewer, verification-runner, implementation-builder, implementation-reviewer, code-quality-reviewer, test-reviewer, documentation-reviewer |
| **epic-card** | `/epic-card PROJ-123` | E0-E11 | Epic card description | codebase-explorer, area-mapper, plan-reviewer, comment-reviewer, verification-runner (plus the full task-card set via E8 inline child execution) |
| **code-review** | `/code-review PROJ-123` | CR0-CR11 | Code Review card description | review-analyst (4 or 5 parallel, depending on review type), comment-reviewer |
| **implementation-discovery** | `/implementation-discovery` | D0-D5 | User's build/change goal | codebase-explorer, area-mapper |
| **mr-creation** | `/mr-creation` | M0-M8 | User input + repo state | code-review-responder (M7) |
| **test-doc-review** | `/test-doc-review [PROJ-123]` | TD0-TD5 | Optional Task/Bug Jira context + current repo state | test-reviewer, documentation-reviewer |
| **manual-qa-plan** | `/manual-qa-plan PROJ-123` | Q0-Q4 | Task/Bug/Epic Jira context + related branch diff | manual-qa-reviewer |
| **document-card** | `/document-card PROJ-123` | DC0-DC8 | Completed Task/Epic/Bug card | comment-reviewer |
| **project-onboarding** | `/project-onboarding [path]` | O0-O6 | Target project repo state | codebase-explorer, area-mapper |
| **compact-context** | `/compact-context` | — | Active work item's file memory | None |

## Agents

| Agent | Purpose | Tool Access | Used By |
|-------|---------|-------------|---------|
| **codebase-explorer** | Codebase investigation. Reads Serena project memory as starting hints; writes its findings to one `explorations/<area>.md` file in the work item's memory directory; does not modify project files | Read, Write, Glob, Grep, Bash, Serena read tools (`get_symbols_overview`, `find_symbol`, `find_referencing_symbols`, `search_for_pattern`), Serena project memory read (`list_memories`, `read_memory`) | requirements-intake R2, issue-intake I2, task-card T2, bug-card B3, epic-card E2, implementation-discovery D1, project-onboarding O2 |
| **area-mapper** | Crystallizes durable area knowledge from a session's exploration files into Serena project memory. Does not re-explore code, does not modify project files. Spawned in the background after each codebase-analysis phase to accumulate memory over time | Bash, `Glob`, `Read` (reads the work item's `explorations/*.md`), Serena project memory (`list_memories`, `read_memory`, `write_memory`, `edit_memory`) | requirements-intake R2, issue-intake I2, task-card T2, bug-card B3, epic-card E2, implementation-discovery D1, project-onboarding O2 |
| **implementation-builder** | Executes the approved implementation/fix plan in a dedicated context (the default T8/B10 build path). Loads the work item's `$MEM` files itself, applies changes with symbol-aware edits, and returns a `BUILD REPORT` with low-confidence areas and potential issues for the reviewers. Never commits, pushes, or touches Jira | Read, Write, Edit, Glob, Grep, Bash, Serena read tools, Serena symbol-aware writes (`replace_symbol_body`, `insert_after_symbol`, `insert_before_symbol`, `rename_symbol`, `safe_delete_symbol`, `replace_content`), Serena memory read (`list_memories`, `read_memory`) | task-card T8, bug-card B10 |
| **implementation-reviewer** | Adversarial review of core behavior, plan adherence, and caller integrity against plan/criteria before test/doc completion (conventions and pattern reuse are owned by `code-quality-reviewer`, which runs in parallel) | Bash, Read, Glob, Grep, Serena read tools (`get_symbols_overview`, `find_symbol`, `find_referencing_symbols`, `search_for_pattern`) | task-card T8, bug-card B10 |
| **code-quality-reviewer** | Single-concern review that conventions are followed and existing patterns/utilities are reused instead of reinvented. Runs in parallel with `implementation-reviewer`; shares the `review-checklist-code_quality.md` Serena memory with `review-analyst` so T8/B10 review and CR4 review enforce one standard | Bash, Read, Glob, Grep, Serena read tools, Serena project memory (`list_memories`, `read_memory`, `write_memory`, `edit_memory`) | task-card T8, bug-card B10 |
| **test-reviewer** | Completes automated test coverage and runs relevant test commands after implementation review | Read, Write, Edit, Glob, Grep, Bash, Serena read tools (`get_symbols_overview`, `find_symbol`, `find_referencing_symbols`, `search_for_pattern`), Serena symbol-aware writes (`replace_symbol_body`, `insert_after_symbol`, `insert_before_symbol`, `rename_symbol`, `safe_delete_symbol`), Serena project memory (`test-commands.md`) | task-card T8, bug-card B10, test-doc-review TD3 |
| **documentation-reviewer** | Completes inline and repository documentation and flags `/document-card` follow-up when needed | Bash, Read, Write, Edit, Glob, Grep, Serena read tools (`get_symbols_overview`, `find_symbol`, `find_referencing_symbols`, `search_for_pattern`), Serena symbol-aware writes (`insert_after_symbol`, `insert_before_symbol`, `replace_content`), Serena project memory (`documentation-conventions.md`) | task-card T8, bug-card B10, test-doc-review TD4 |
| **plan-reviewer** | Reviews implementation/fix plans and epic breakdown plans before execution, including testing and documentation strategy | Bash, Read, Glob, Grep, Serena read tools (`get_symbols_overview`, `find_symbol`, `find_referencing_symbols`, `search_for_pattern`) | task-card T4, bug-card B5, epic-card E4 |
| **review-analyst** | Specialist review for one category (4 or 5 parallel, depending on review type) | Read, Glob, Grep, Bash, Serena read tools (`get_symbols_overview`, `find_symbol`, `find_referencing_symbols`, `search_for_pattern`), Serena project memory (`review-checklist-<category>.md`) | code-review CR4 |
| **manual-qa-reviewer** | Translates Jira context and branch diffs into tester-friendly manual QA scenarios, prerequisites, expected results, regressions, and edge cases | Read, Glob, Grep, Bash, Serena read tools (`get_symbols_overview`, `find_symbol`, `find_referencing_symbols`, `search_for_pattern`) | manual-qa-plan Q3 |
| **comment-reviewer** | Reviews every drafted Jira comment against the phase's required heading and field outline before `jira_add_comment` is called | Bash, Read, Glob, Grep | every gated `jira_add_comment` (task-card T4/T5, T10, T12; bug-card B5/B6, B12, B14; epic-card E4/E5, E9, E10; code-review CR8; document-card DC8) |
| **verification-runner** | Runs the full build, all tests, and all linters against the working tree; returns a per-category pass/fail verdict with failing-test excerpts | Bash, Read, Glob, Grep | task-card T7/T9 (and T11 in epic child mode), bug-card B8/B11, epic-card E8 (integration branch after each child merge) |
| **code-review-responder** | Verifies an automated GitLab code-review bot's findings against the actual code, applies the fixes that are genuinely legitimate (symbol-aware edits; runs tests), and returns per-finding verdicts, evidence-backed rebuttals for false positives, and a ready-to-post response comment. Never commits, pushes, or touches GitLab/Jira | Read, Write, Edit, Glob, Grep, Bash, Serena read tools, Serena symbol-aware writes (`replace_symbol_body`, `insert_after_symbol`, `insert_before_symbol`, `rename_symbol`, `safe_delete_symbol`, `replace_content`), Serena memory read (`list_memories`, `read_memory`) | mr-creation M7 |

**Execution skill direct Serena access:** `task-card` (T8), `bug-card` (B10), and `code-review` (CR5/CR6) declare Serena read tools and, for `task-card` and `bug-card`, symbol-aware write tools. This lets the orchestrator use `replace_symbol_body`, `insert_after_symbol`, `insert_before_symbol`, `rename_symbol`, and `safe_delete_symbol` directly during implementation phases rather than falling back to text-level `Edit` for every code change. See the Serena-first editing rule in each workflow's implementation phase.

**Serena project activation:** `task-card`, `bug-card`, `epic-card`, and `code-review` check Serena's project-activation message at the start of the workflow and call `onboarding` if the project has not yet been activated. Serena's symbol and memory tools require this activation to be scoped to the current project directory.

## Detailed Flow: Feature Development (Happy Path)

```
1. User invokes /requirements-intake
   R0: Conversational intake (gather context)
   R1: Jira context review (check for duplicates)
   R2: Codebase analysis (parallel codebase-explorer agents)
   R3: Stakeholder Q&A (resolve ambiguities)
   R4: Requirements synthesis (acceptance criteria, risks, Epic vs Task)
   R5: Create Jira card with structured description

2. User invokes /epic-card PROJ-100  (or /task-card for single tasks)
   E0: Transition to In Progress
   E1: Read epic description (Task Details, Affected Areas, Acceptance Criteria)
   E2: Codebase review (parallel codebase-explorer agents)
   E3: Clarifying questions (post to Jira, ask in chat)
   E4: Breakdown plan (decompose into ordered child tasks)
   E5: Await approval (in chat)
   E6: Create child tasks in Jira (Standard Task Template)
   E7: Verify epic integration branch (the user supplies/creates the branch; no worktree)
   E8: Execute child tasks sequentially inline (T0-T13 per task)
       Each child task runs T0-T13:
         T0: Transition to In Progress
         T1: Read task description
         T2: Codebase review
         T3: Clarifying questions
         T4: Implementation plan + plan-reviewer agent review
         T5: Await approval
         T6: Verify working branch (in epic mode, created from the integration branch)
         T7: Baseline verification
         T8: Core implementation (implementation-builder by default; inline only for
             trivial changes) + parallel implementation-reviewer / code-quality-reviewer
             loop, then test-reviewer and documentation-reviewer completion loops
         T9: Post-implementation verification
         T10: User testing (skipped in epic mode -- handled at E9)
         T11: Commit + push (in epic mode, also merge to the integration branch)
         T12: Summary of changes
         T13: Cleanup (file memory)
   E9: User testing (end-to-end)
   E10: Epic summary
   E11: Cleanup (file memory)

3. User invokes /mr-creation
   M0-M8: Create GitLab MR for the integration branch, then respond to the code review bot

4. User invokes /manual-qa-plan PROJ-123
   Q0-Q4: Read Jira context and related branch diff, then generate tester-friendly manual QA verification steps
```

## Card Description Section Headers

Execution skills consume these sections by name. Intake skills must produce the sections relevant to each card type.

### Task Cards

**Standalone tasks (from requirements-intake):**

- `## Task Details` -- wrapper with **Summary** field
- `## Overview` -- what and why
- `## Context` -- background
- `## Affected Areas` -- structured list: path, description, risk level
- `## Patterns & Code References` -- patterns to follow, `path:line` code references, short snippets, integration points (or "None")
- `## Non-Functional Requirements` -- performance, security/privacy, accessibility, compliance targets (or "None specified")
- `## Data & Interface Changes` -- data model/migrations, API shapes, events/config (or "None")
- `## Observability & Telemetry` -- logs/metrics/traces, alerts, prod success signal (or "None")
- `## Acceptance Criteria` -- Gherkin for features (single fenced ` ```gherkin ` block, `Feature:`/`Scenario:`, every criterion a Scenario), outcome-based for maintenance
- `## Dependencies` -- hard and soft
- `## Scope` -- in scope / out of scope
- `## Risks` -- risk register table
- `## Open Items` -- unresolved questions

**Epic child tasks (from epic-card E6):**

- `## Task Details` -- wrapper with **Summary** field and **Epic Integration Branch**
- `## Overview` -- child-task specific what/why
- `## Context` -- parent epic relationship plus child-task context
- `## Affected Areas` -- structured list: path, description, risk level
- `## Patterns & Code References` -- patterns/code references for this child (or "None")
- `## Non-Functional Requirements` -- per-child NFR targets (or "N/A")
- `## Data & Interface Changes` -- per-child data/interface contracts (or "None")
- `## Observability & Telemetry` -- per-child instrumentation (or "None")
- `## Acceptance Criteria` -- Gherkin for feature/behavioral children (fenced `Feature:`/`Scenario:`), outcome-based otherwise
- `## Dependencies` -- hard and soft
- `## Scope` -- child-task scope boundaries
- `## Risks` -- task-specific risks or `N/A — managed in parent epic`
- `## Open Items` -- unresolved questions

### Design Cards (from design-intake)

A design card uses the standalone Task-card section set above, plus design-specific
sections inserted before `## Scope`:

- `## Patterns & Code References` -- component-reuse/token/style conventions, `path:line` references, snippets (or "None")
- `## Non-Functional Requirements` -- performance budget and compliance (accessibility has its own section), or "None specified"
- `## Design Assets` -- links to Figma, screenshots, or HTML exports, or "None provided"
- `## Design System` -- name/version of the component library, or "None / not applicable"
- `## Visual Specifications` -- colors, typography, spacing, borders/shadows, iconography
- `## Component States` -- per-component default/hover/active/focus/disabled/loading/error/empty
- `## Responsive Behavior` -- breakpoint-by-breakpoint layout changes
- `## Animation & Transitions` -- motion specs, or "No animation defined"
- `## Accessibility Requirements` -- WCAG level, contrast, keyboard, screen-reader needs

Execution skills consume these the same way as a standalone Task card; the extra
sections are additive context for frontend implementation.

### Bug Cards (from issue-intake)

- `## Bug Details` -- wrapper with **Summary** field
- `## Overview` -- what is broken and impact
- `## Observed Behavior` -- exact description
- `## Expected Behavior` -- exact description
- `## Steps to Reproduce` -- numbered steps or intermittent note
- `## Logs / Exceptions / Stack Traces` -- content or "None provided"
- `## Environment` -- tier, OS, browser, app version
- `## Severity` -- Critical/High/Medium/Low
- `## Affected Areas` -- structured list from codebase analysis
- `## Root Cause (if known)` -- from investigation or "Unknown"
- `## Patterns & Code References` -- code paths/conventions for the fix, `path:line` references, snippets (or "None")
- `## Fix Criteria` -- outcome-based acceptance criteria
- `## Open Items` -- unresolved questions

### Code Review Cards (from code-review-intake)

- `## Review Details` -- review type, branch, goals, work items, risks

## File-Based Memory

Most intake and execution workflows accumulate structured state across phases in a **per-work-item file-memory directory** at `<project-root>/.claude/web-cms-memory/<WORK-ITEM-KEY>/` (the git worktree root's `.claude/` folder, git-ignored) (markdown + YAML frontmatter). This replaces the former knowledge-graph MCP server. The full specification — path-resolution recipe, file schemas, the checkpoint/compaction contract, the full-context-load rule, the codebase-explorer → area-mapper file flow, and the generated `work-item.html` dashboard — lives in **`file-memory-protocol.md`** at the plugin root. Key rules:

- **Intake workflows:** file content must be fully materialized into the Jira card description before cleanup
- **Execution workflows:** the directory tracks state within and across sessions; if resumed and the directory is absent, reconstruct state from the Jira issue description and comment history before continuing
- **Epic workflow:** `children.md` is the authoritative execution-state map tracking child task completion; critical for resumability
- **Checkpoint & recall:** a single `checkpoint.md` is overwritten after *every* phase (so recall survives auto-compaction and interruptions); `/compact` is prompted only at designated gates; on any resume the agent reads `checkpoint.md` and its `references`, then continues
- **Cleanup is atomic:** the final cleanup phase removes the whole directory with `rm -rf <work-item-dir>` after the last durable artifact has been created — nothing to enumerate, nothing missed. `implementation-discovery` intentionally skips cleanup (its `discovery-<slug>/` directory is reaped by the follow-on requirements-intake R6 or issue-intake I6)
- **Human dashboard:** a `work-item.html` is generated from the markdown (rendered client-side via CDN marked.js + mermaid.js) for browser review; the agent never reads it back
- **Related-card context (intake):** R1/I1 capture relevant related Jira cards' excerpts into `related-cards.md`, which R4 distills into the new card

## Serena Project Memory

Distinct from the per-work-item file memory, Serena's project memory (`write_memory`, `read_memory`, `edit_memory`, `list_memories`) persists durable repo-scoped knowledge across sessions. Memories live in Serena's project store (the project's `.serena/memories/` directory, scoped to whichever project Serena auto-activated from the Claude Code launch directory) and survive between runs. This surface is wired into four agents:

| Agent | Memory key | Purpose |
|-------|-----------|---------|
| **test-reviewer** | `test-commands.md` | Canonical build, test, and lint commands for the repo so each run doesn't re-discover them |
| **documentation-reviewer** | `documentation-conventions.md` | Doc-comment dialect, where docs live, and repo-wide style rules |
| **review-analyst** | `review-checklist-<category>.md` (one per assigned category) | Repo-specific review checklist and anti-pattern catalog for each review category |
| **code-quality-reviewer** | `review-checklist-code_quality.md` (shared with review-analyst) | Same checklist as review-analyst's `code_quality` category, so implementation-time review (T8/B10) and CR4 diff review enforce a single repo standard |
| **codebase-explorer** | `codebase-map-<area>.md` (one per normalized target-area slug) | Durable area maps: purpose, key symbols, patterns, integration points. Read at the start of every run; written at end only when deep area mapping produced multi-file-evidenced knowledge. |

**Discipline rules (apply to every memory-using agent):**

- **Durable knowledge only.** Memories encode slow-changing repo facts — build commands, doc conventions, review standards, area maps. Do not write work-item-specific findings, session state, or ephemeral observations. Those belong in the per-work-item file memory or nowhere.
- **Read before work.** At the start of every run, `list_memories` and `read_memory` for the relevant key. Treat contents as starting context, not ground truth.
- **Verify before relying.** Before citing a memory claim in a finding, decision, or report, confirm it still holds against the current worktree. Memory staleness is worse than no memory because it gives false confidence.
- **Write with provenance.** Every memory file starts with a frontmatter block carrying `verified_at` (date) and `verified_against` (git SHA) so the next consumer can detect staleness.
- **Refresh, don't duplicate.** When a memory contradicts what you observe, use `edit_memory` to update it in place. Do not fork.
- **Named by durable scope.** Memory names describe what the memory covers (`test-commands`, `documentation-conventions`, `review-checklist-code_quality`, `codebase-map-<area>`), not who produced it or when.

**Staleness detection pattern:** For memories whose claims reference specific files or directories (notably `codebase-map-<area>`), the frontmatter should include a `covers:` list of those paths. On read, compare `verified_against` against `HEAD` for each covered path via `git log <verified_against>..HEAD -- <path>`. Any commits in that range mark the memory as potentially stale, triggering per-claim verification before citation. Memories that encode general conventions (`test-commands`, `documentation-conventions`, `review-checklist-*`) typically do not need a `covers:` list; their staleness is detected by contradiction during the run.

**Parallel-run collisions:** `codebase-explorer` runs in parallel (R2/I2/T2/B3/E2 spawn multiple instances). Memory key collisions are avoided by normalizing target-area arguments to deterministic slugs. For defense in depth, the write protocol re-reads the memory immediately before writing and merges rather than clobbers when a peer instance has written to the same key. The same re-read-and-merge protocol covers `review-checklist-code_quality.md`, which is deliberately shared between `review-analyst` and `code-quality-reviewer`.

## Deployment

To use these skills and agents in a target project, copy the `skills/` and `agents/` directories into the project's `.claude/` directory:

```
your-project/
  .claude/
    skills/
      implementation-discovery/
      requirements-intake/
      design-intake/
      issue-intake/
      code-review-intake/
      bug-card/
      task-card/
      epic-card/
      code-review/
      mr-creation/
      test-doc-review/
      manual-qa-plan/
      document-card/
      project-onboarding/
      compact-context/
    agents/
      area-mapper/
      code-quality-reviewer/
      codebase-explorer/
      comment-reviewer/
      documentation-reviewer/
      implementation-builder/
      implementation-reviewer/
      manual-qa-reviewer/
      plan-reviewer/
      review-analyst/
      test-reviewer/
      verification-runner/
```

**Agent name resolution:** Workflows reference sub-agents by short name (`codebase-explorer`, `plan-reviewer`, `implementation-builder`, `code-quality-reviewer`, `test-reviewer`, `documentation-reviewer`, …). The registered identifier depends on the installation mode:

- **Copied into the project's `.claude/agents/`** (the deployment above): the short name resolves verbatim.
- **Installed as the plugin**: the runtime registers each agent as `web-cms:<short-name>:<short-name>` (e.g. `web-cms:verification-runner:verification-runner`). Partial forms like `web-cms:verification-runner` do **not** resolve.

Every workflow that spawns sub-agents carries a `SUB-AGENT NAME RESOLUTION` header rule instructing the orchestrator to resolve short names against the runtime's available-agents list (matching on the final segment) before the first invocation and to reuse the resolved scheme for the rest of the session. If your target environment requires an explicit agent registry or routing configuration, add that registration as part of deployment so these references resolve at runtime.

**MCP tool names:** Each skill and agent declares its MCP tool dependencies in its `allowed-tools` / `tools` frontmatter using the plugin-declared server names: `mcp__plugin_web-cms_atlassian__<tool>`, `mcp__plugin_web-cms_serena__<tool>`, `mcp__plugin_web-cms_gitlab__<tool>`, `mcp__plugin_web-cms_sequentialthinking__<tool>`, `mcp__plugin_web-cms_playwright__<tool>`. File memory uses the native `Read`/`Write`/`Edit`/`Glob`/`Grep` tools — no MCP server. All git operations use `Bash` directly.

## MCP Server Configuration

The plugin declares its own stdio MCP servers in `.mcp.json` and relies on Claude Code launching them per-session. There is no gateway container to manage; each MCP server is a subprocess Claude Code spawns on demand.

### Declared servers

`.mcp.json` at the plugin root declares five stdio servers plus one HTTP gateway:

| Server | Purpose | Launcher |
|---|---|---|
| `atlassian` | Jira and Confluence operations (get/create/update issues, search, comments, page management, attachments, labels) | `uvx mcp-atlassian` |
| `serena` | Symbolic code navigation (find_symbol, find_referencing_symbols, get_symbols_overview, search_for_pattern, replace_content, insert_after/before_symbol, rename_symbol, replace_symbol_body, safe_delete_symbol, read/write/list/edit/delete_memory, onboarding, initial_instructions) | `uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context ide --project-from-cwd` |
| `gitlab` | GitLab repo operations (create_branch, create_issue, create_merge_request, create_or_update_file, create_repository, fork_repository, get_file_contents, push_files, search_repositories) | `npx -y gitlab-mcp` |
| `sequentialthinking` | Sequential thinking helper | `npx -y @modelcontextprotocol/server-sequential-thinking` |
| `playwright` | Browser automation (browser_click, browser_navigate, etc.) | `npx -y @playwright/mcp` |
| `MCP_DOCKER` | HTTP gateway providing additional Jira, Confluence, and other tool coverage | `http://mcp-gateway.lvh.me:8811/mcp` |

### Serena project scoping

The `serena` server is launched with `--project-from-cwd`, which auto-detects the project by searching the MCP subprocess's current working directory (and its parents) for a `.serena/project.yml` or `.git` marker. Because Claude Code launches MCP subprocesses with CWD set to the directory where Claude Code was started (the project root), each Claude Code session gets its own Serena subprocess scoped to that project. Concurrent sessions on different projects never share Serena state.

This replaces the earlier per-project Docker gateway pattern that was required when Serena was containerized.

### Atlassian coverage

Jira and Confluence tools are provided by the plugin's own `atlassian` MCP server (`uvx mcp-atlassian`), declared in `.mcp.json`. Skills reference these tools as `mcp__plugin_web-cms_atlassian__<tool>`. This includes full Confluence support: page create/update, attachment upload (`confluence_upload_attachment`, `confluence_upload_attachments`), label management (`confluence_add_label`), and all Jira operations. The `document-card` DC8 phase handles attachment uploads and label application directly via these tools.

### Deployment prerequisites

Each machine that runs Claude Code against a project using this plugin needs:

- `uv` installed (provides `uvx`; used by `serena` and `git` servers). Install with `curl -LsSf https://astral.sh/uv/install.sh | sh`.
- Node 20+ installed (provides `npx`; used by `gitlab`, `sequentialthinking`, `playwright` servers).
- A GitLab personal access token exported in the shell as `GITLAB_PERSONAL_ACCESS_TOKEN`. Optionally override `GITLAB_API_URL` (defaults to `https://gitlab.com/api/v4`).
- Java 17+ on PATH (Serena's bundled Eclipse JDTLS is Java-based; required for Java projects).

Projects do not need any local MCP configuration — no per-project `.mcp.json`, no Docker MCP gateway, no catalog files. The plugin's `.mcp.json` is the single source of truth and travels with the plugin installation.

### Git operations

All git operations in skills and agents use `Bash` directly — there is no MCP git server in this plugin. Filesystem operations use native `Read` / `Write` / `Edit` / `Glob` / `Grep` tools and Bash.
