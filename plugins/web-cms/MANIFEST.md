# Skills & Agents -- Workflow Topology

This project defines Claude Code skills and agents for creating and implementing Jira cards. The system has two tiers: **intake skills** that gather context and create Jira cards, and **execution skills** that read those cards and do the work.

## Architecture

```
INTAKE (creates Jira cards)          EXECUTION (works Jira cards)
=============================        =============================

/requirements-intake (R0-R5)  --->   /task-card PROJ-123 (T0-T12)
  Creates Epic or Task card          /epic-card PROJ-123 (E0-E10)

/issue-intake (I0-I5)         --->   /bug-card PROJ-123 (B0-B14)
  Bug? Creates Bug card                OR
  Missing requirement?        --->   /requirements-intake (R0-R5)

/code-review-intake (CI0-CI5) --->   /code-review PROJ-123 (CR0-CR10)
  Creates Code Review card

                                       /mr-creation (M0-M6)
                                         Standalone -- creates GitLab MR

                                       /test-doc-review [PROJ-123] (TD0-TD5)
                                         Standalone -- independently runs test-reviewer and documentation-reviewer; skips TD0 when no Jira key is provided

                                       /manual-qa-plan PROJ-123 (Q0-Q4)
                                         Standalone -- reviews Jira context plus related branch diff, generates manual QA steps, and appends the plan to the issue description

                                       /document-card PROJ-123 (D0-D8)
                                         Standalone -- documents completed work
```

## Contract Between Tiers

The Jira card description is the interface between intake and execution:

- **Intakes** produce structured card descriptions with well-known section headers (`## Task Details`, `## Bug Details`, `## Acceptance Criteria`, `## Affected Areas`, etc.)
- **Execution skills** read the card description and consume those sections by name
- **Workflows are NOT embedded** in card descriptions -- each card contains only the structured work context needed by the downstream execution skill. Persisted Jira descriptions must not include workflow instructions, skill-invocation text, or temporary placeholders.
- The execution workflow lives in the skill's `workflow.md` file and is loaded when the user invokes the appropriate skill
- Jira comments are part of the durable execution record only when a workflow explicitly requires them. For `task-card`, use the minimal structured comment set defined in that workflow (T3 clarification status, one combined T4/T5 plan-and-approval comment, T11 user testing handoff when applicable, T12 summary, and failure comments) rather than phase-by-phase narration.

## Skills

### Intake Skills

| Skill | Invocation | Phases | Output |
|-------|-----------|--------|--------|
| **requirements-intake** | `/requirements-intake` | R0-R5 | Epic or Task card in Jira |
| **issue-intake** | `/issue-intake` | I0-I5 | Bug card in Jira, or transitions to requirements-intake |
| **code-review-intake** | `/code-review-intake` | CI0-CI5 | Code Review (Task) card in Jira |

### Execution Skills

| Skill | Invocation | Phases | Input | Sub-agents Used |
|-------|-----------|--------|-------|-----------------|
| **task-card** | `/task-card PROJ-123` | T0-T12 | Task card description | codebase-explorer, plan-reviewer, implementation-reviewer, test-reviewer, documentation-reviewer |
| **bug-card** | `/bug-card PROJ-123` | B0-B14 | Bug card description | codebase-explorer, plan-reviewer, implementation-reviewer, test-reviewer, documentation-reviewer |
| **epic-card** | `/epic-card PROJ-123` | E0-E10 | Epic card description | codebase-explorer |
| **code-review** | `/code-review PROJ-123` | CR0-CR10 | Code Review card description | review-analyst (4 or 5 parallel, depending on review type) |
| **mr-creation** | `/mr-creation` | M0-M6 | User input + repo state | None |
| **test-doc-review** | `/test-doc-review [PROJ-123]` | TD0-TD5 | Optional Task/Bug Jira context + current repo state | test-reviewer, documentation-reviewer |
| **manual-qa-plan** | `/manual-qa-plan PROJ-123` | Q0-Q4 | Task/Bug/Epic Jira context + related branch diff | manual-qa-reviewer |
| **document-card** | `/document-card PROJ-123` | D0-D8 | Completed Task/Epic/Bug card | None |

## Agents

| Agent | Purpose | Tool Access | Used By |
|-------|---------|-------------|---------|
| **codebase-explorer** | Read-only codebase investigation (may write durable area maps to Serena project memory; does not modify project files) | Read, Glob, Grep, Bash, Serena read tools (`get_symbols_overview`, `find_symbol`, `find_referencing_symbols`, `search_for_pattern`), Serena project memory (`codebase-map-<area>.md`), MCP git tools | requirements-intake R2, issue-intake I2, task-card T2, bug-card B3, epic-card E2 |
| **implementation-reviewer** | Adversarial review of core implementation against plan/criteria before test/doc completion | Read, Glob, Grep, Serena read tools (`get_symbols_overview`, `find_symbol`, `find_referencing_symbols`, `search_for_pattern`), MCP git tools | task-card T8, bug-card B10 |
| **test-reviewer** | Completes automated test coverage and runs relevant test commands after implementation review | Read, Edit, Glob, Grep, Bash, Serena read tools (`get_symbols_overview`, `find_symbol`, `find_referencing_symbols`, `search_for_pattern`), Serena symbol-aware writes (`replace_symbol_body`, `insert_after_symbol`, `insert_before_symbol`, `rename_symbol`, `safe_delete_symbol`), Serena project memory (`test-commands.md`), MCP git tools | task-card T8, bug-card B10 |
| **documentation-reviewer** | Completes inline and repository documentation and flags `/document-card` follow-up when needed | Read, Edit, Glob, Grep, Serena read tools (`get_symbols_overview`, `find_symbol`, `find_referencing_symbols`, `search_for_pattern`), Serena symbol-aware writes (`insert_after_symbol`, `insert_before_symbol`, `replace_content`), Serena project memory (`documentation-conventions.md`), MCP git tools | task-card T8, bug-card B10 |
| **plan-reviewer** | Reviews plan before implementation, including testing and documentation strategy | Read, Glob, Grep, Serena read tools (`get_symbols_overview`, `find_symbol`, `find_referencing_symbols`, `search_for_pattern`), MCP git tools | task-card T4, bug-card B5 |
| **review-analyst** | Specialist review for one category (4 or 5 parallel, depending on review type) | Read, Glob, Grep, Bash, Serena read tools (`get_symbols_overview`, `find_symbol`, `find_referencing_symbols`, `search_for_pattern`), Serena project memory (`review-checklist-<category>.md`), MCP git tools | code-review CR4 |
| **manual-qa-reviewer** | Translates Jira context and branch diffs into tester-friendly manual QA scenarios, prerequisites, expected results, regressions, and edge cases | Read, Glob, Grep, Bash, Serena read tools (`get_symbols_overview`, `find_symbol`, `find_referencing_symbols`, `search_for_pattern`), MCP git tools | manual-qa-plan Q3 |

**Execution skill direct Serena access:** `task-card` (T8), `bug-card` (B10), and `code-review` (CR5/CR6) declare Serena read tools and, for `task-card` and `bug-card`, symbol-aware write tools. This lets the orchestrator use `replace_symbol_body`, `insert_after_symbol`, `insert_before_symbol`, `rename_symbol`, and `safe_delete_symbol` directly during implementation phases rather than falling back to text-level `Edit` for every code change. See the Serena-first editing rule in each workflow's implementation phase.

**Serena project activation:** `task-card`, `bug-card`, `epic-card`, and `code-review` call `check_onboarding_performed` at the start of the workflow and `onboarding` if the project has not yet been activated. Serena's symbol and memory tools require this activation to be scoped to the current project directory.

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
   E7: Create integration branch + worktree
   E8: Execute child tasks sequentially inline (T0-T12 per task), then remove the epic worktree
       Each child task runs T0-T12:
         T0: Transition to In Progress
         T1: Read task description
         T2: Codebase review
         T3: Clarifying questions
         T4: Implementation plan + plan-reviewer agent review
         T5: Await approval
         T6: Create branch (from integration branch)
         T7: Baseline verification
         T8: Core implementation + implementation-reviewer, test-reviewer, and documentation-reviewer loops
         T9: Post-implementation verification
         T10: Commit + merge to integration branch
         T11: User testing (skipped in epic mode -- handled at E9)
         T12: Summary of changes
   E9: User testing (end-to-end, after epic worktree cleanup)
   E10: Epic summary

3. User invokes /mr-creation
   M0-M6: Create GitLab MR for the integration branch

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
- `## Acceptance Criteria` -- Gherkin (features) or outcome-based (tech debt/upkeep)
- `## Dependencies` -- hard and soft
- `## Scope` -- in scope / out of scope
- `## Risks` -- risk register table
- `## Open Items` -- unresolved questions

**Epic child tasks (from epic-card E6):**

- `## Task Details` -- wrapper with **Summary** field and **Epic Integration Branch**
- `## Overview` -- child-task specific what/why
- `## Context` -- parent epic relationship plus child-task context
- `## Affected Areas` -- structured list: path, description, risk level
- `## Acceptance Criteria` -- task-specific criteria
- `## Dependencies` -- hard and soft
- `## Scope` -- child-task scope boundaries
- `## Risks` -- task-specific risks or `N/A — managed in parent epic`
- `## Open Items` -- unresolved questions

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
- `## Fix Criteria` -- outcome-based acceptance criteria
- `## Open Items` -- unresolved questions

### Code Review Cards (from code-review-intake)

- `## Review Details` -- review type, branch, goals, work items, risks

## Knowledge Graph

Most intake and execution workflows use a session-scoped knowledge graph to accumulate structured state across phases. Key rules:

- **Graph-backed intake workflows:** Graph content must be fully materialized into the Jira card description before the session ends
- **Graph-backed execution workflows:** Graph is used within the session for state tracking; if resumed in a new session with an empty graph, reconstruct state from the Jira issue description and comment history before continuing
- **Epic workflow:** Graph is the authoritative execution state map tracking child task completion; critical for resumability
- **Cleanup required:** If a workflow uses a session-scoped knowledge graph, add a dedicated final cleanup phase after the last durable artifact has been created (for example: Jira description, Jira summary comment, review findings comment, or MR description). Perform graph cleanup there, not inline in an earlier phase.
- **Worktree cleanup:** For workflows that create worktrees, the dedicated final cleanup phase should verify no workflow-owned worktree remains before the workflow is considered complete. If a worktree must be removed earlier for user testing, the cleanup phase should still verify that removal at the end.

## Serena Project Memory

Distinct from the session-scoped knowledge graph, Serena's project memory (`write_memory`, `read_memory`, `edit_memory`, `list_memories`) persists durable repo-scoped knowledge across sessions. Memories live in Serena's project store (scoped to `SERENA_PROJECT`) and survive between runs. This surface is wired into four agents:

| Agent | Memory key | Purpose |
|-------|-----------|---------|
| **test-reviewer** | `test-commands.md` | Canonical build, test, and lint commands for the repo so each run doesn't re-discover them |
| **documentation-reviewer** | `documentation-conventions.md` | Doc-comment dialect, where docs live, and repo-wide style rules |
| **review-analyst** | `review-checklist-<category>.md` (one per assigned category) | Repo-specific review checklist and anti-pattern catalog for each review category |
| **codebase-explorer** | `codebase-map-<area>.md` (one per normalized target-area slug) | Durable area maps: purpose, key symbols, patterns, integration points. Read at the start of every run; written at end only when deep area mapping produced multi-file-evidenced knowledge. |

**Discipline rules (apply to every memory-using agent):**

- **Durable knowledge only.** Memories encode slow-changing repo facts — build commands, doc conventions, review standards, area maps. Do not write work-item-specific findings, session state, or ephemeral observations. Those belong in the session-scoped knowledge graph or nowhere.
- **Read before work.** At the start of every run, `list_memories` and `read_memory` for the relevant key. Treat contents as starting context, not ground truth.
- **Verify before relying.** Before citing a memory claim in a finding, decision, or report, confirm it still holds against the current worktree. Memory staleness is worse than no memory because it gives false confidence.
- **Write with provenance.** Every memory file starts with a frontmatter block carrying `verified_at` (date) and `verified_against` (git SHA) so the next consumer can detect staleness.
- **Refresh, don't duplicate.** When a memory contradicts what you observe, use `edit_memory` to update it in place. Do not fork.
- **Named by durable scope.** Memory names describe what the memory covers (`test-commands`, `documentation-conventions`, `review-checklist-code_quality`, `codebase-map-<area>`), not who produced it or when.

**Staleness detection pattern:** For memories whose claims reference specific files or directories (notably `codebase-map-<area>`), the frontmatter should include a `covers:` list of those paths. On read, compare `verified_against` against `HEAD` for each covered path via `git log <verified_against>..HEAD -- <path>`. Any commits in that range mark the memory as potentially stale, triggering per-claim verification before citation. Memories that encode general conventions (`test-commands`, `documentation-conventions`, `review-checklist-*`) typically do not need a `covers:` list; their staleness is detected by contradiction during the run.

**Parallel-run collisions:** `codebase-explorer` runs in parallel (R2/I2/T2/B3/E2 spawn multiple instances). Memory key collisions are avoided by normalizing target-area arguments to deterministic slugs. For defense in depth, the write protocol re-reads the memory immediately before writing and merges rather than clobbers when a peer instance has written to the same key.

## Deployment

To use these skills and agents in a target project, copy the `skills/` and `agents/` directories into the project's `.claude/` directory:

```
your-project/
  .claude/
    skills/
      requirements-intake/
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
    agents/
      codebase-explorer/
      documentation-reviewer/
      implementation-reviewer/
      manual-qa-reviewer/
      plan-reviewer/
      review-analyst/
      test-reviewer/
```

Agent invocations in the workflows assume the runtime can resolve agent names directly from the copied `.claude/agents/` directory. If your target environment requires an explicit agent registry or routing configuration, add that registration as part of deployment so references such as `codebase-explorer`, `plan-reviewer`, `test-reviewer`, and `documentation-reviewer` resolve correctly at runtime.

**MCP tool name prefix:** The `allowed-tools` field in each SKILL.md references MCP tools using the `mcp__MCP_DOCKER__` prefix (e.g., `mcp__MCP_DOCKER__sequentialthinking`). This prefix is specific to the Docker MCP Toolkit setup. If you deploy these skills to a project with a different MCP server configuration, update the prefix in every SKILL.md to match the target environment's MCP server name.

## MCP Server Configuration

The plugin is designed around a **per-project MCP gateway** model. Each consuming project (Brightspot, Shadowstream, etc.) runs its own Docker MCP Gateway with Serena pre-scoped to that project, so concurrent Claude Code sessions on different projects never race on Serena's active-project state. A shared gateway remains available for ad-hoc, non-project Claude Code work.

### Per-project gateway pattern

Each project provides three things:

1. **`mcp-gateway` service** in its own `docker-compose.yml`. The service mounts the shared catalog + registry from `~/.docker/mcp/` and its own `config.yaml` override that sets `serena.project_path` to the project's absolute host path.
2. **`.docker-mcp/config.yaml`** (gitignored; `.docker-mcp/config.example.yaml` is the committed template). Contains the project-specific Serena scoping plus other config the gateway needs.
3. **`.mcp.json`** at the repo root pointing Claude Code at the project's gateway:

```json
{
  "mcpServers": {
    "MCP_DOCKER": {
      "type": "http",
      "url": "http://<project>-mcp.lvh.me/mcp"
    }
  }
}
```

The server name stays `MCP_DOCKER` for every project — this is what keeps the plugin's skill `allowed-tools` prefixes (`mcp__MCP_DOCKER__<tool>`) stable. Only the URL differs per project. The shared gateway at `http://mcp-gateway.lvh.me:8811/mcp` is used by Claude Code sessions opened outside a project.

### How Serena scoping works

The Serena catalog entry in `web-cms-mcp.yaml` sets `env: SERENA_PROJECT = {{serena.project_path}}`. Each gateway resolves that template against its own `config.yaml`:

- **Per-project gateway:** `serena.project_path` is set → spawned Serena starts with `--project <path>`, auto-activates that project, and does not expose `activate_project` or `get_current_config` (project switching is impossible once scoped).
- **Shared gateway:** `serena.project_path` is unset → spawned Serena starts unscoped, exposes all 21 tools, and requires `activate_project` at runtime.

The Serena image itself is built from `webcms-local-infrastructure/docker-mcp-toolkit-configuration/Dockerfile`. Its entrypoint reads `$SERENA_PROJECT`, creates a `/workspace/<basename>` symlink pointing at the project (so dev-container paths like `/workspace/brightspot/...` resolve transparently), and launches `serena start-mcp-server --context ide --project "$SERENA_PROJECT"`.

### Deployment prerequisites

Before this plugin's tool references will resolve, the consuming project must:

- Have `webcms-local-infrastructure` running (Traefik + shared gateway + `webcms-shared` network).
- Bring up the project's own `mcp-gateway` service (typically via the project's `start.sh` or `docker compose up -d`).
- Have a populated `<project>/.docker-mcp/config.yaml` (copy `config.example.yaml` and fill in per-user values).

See `webcms-local-infrastructure/docker-mcp-toolkit-configuration/README.md` (section: "Per-project gateway configuration") for the full setup.

### MCP git server

All skills and agents include MCP git tools (`git_status`, `git_add`, `git_commit`, `git_diff`, `git_diff_staged`, `git_diff_unstaged`, `git_log`, `git_show`, `git_create_branch`, `git_checkout`, `git_reset`). These require the `git` MCP server to be present in the catalog. Workflows prefer these MCP tools over Bash for git operations, using Bash only for git operations with no MCP equivalent (`git push`, `git pull`, `git merge`, `git worktree`, `git remote`, `git stash`, `git rebase`) and for build/test/lint commands. Filesystem operations use native `Read`/`Write`/`Edit`/`Glob`/`Grep` and Bash — the plugin does not require a filesystem MCP server.
