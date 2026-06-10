# File-Based Memory Protocol

This is the single source of truth for the web-cms plugin's **session-scoped, per-work-item file memory**. It replaces the old `@modelcontextprotocol/server-memory` knowledge graph. Skills and agents read this document for the path recipe, file schemas, the checkpoint/compaction contract, the full-context-load rule, and the HTML dashboard template.

**This is NOT Serena.** Serena project memory (`mcp__plugin_web-cms_serena__{read,write,edit,list}_memory`, e.g. `codebase-map-<area>.md`, `test-commands.md`) is a separate, durable, repo-scoped store and is unchanged. File memory here is per-work-item session state that is materialized into Jira and then deleted.

---

## 1. Storage location & path resolution

Each work item gets one directory under the project's `.claude/` folder:

```
<project-root>/.claude/web-cms-memory/<WORK-ITEM-KEY>/
```

- **In-project, discoverable, persistent across sessions, git-ignored.** `<project-root>` is the git worktree root (so each worktree gets its own memory), falling back to the current working directory when not in a git repo.
- `<WORK-ITEM-KEY>` is the Jira key (`PROJ-123`) or, for keyless work, a slug: `intake-<slug>` or `discovery-<slug>`.

Every skill and the `codebase-explorer` / `area-mapper` / `compact-context` agents MUST compute the **same** path on write and on resume, using this shared recipe:

```bash
# Project root = git worktree root, or cwd if not a git repo.
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
MEMROOT="$ROOT/.claude/web-cms-memory"
MEM="$MEMROOT/$KEY"
mkdir -p "$MEM/explorations"

# Keep memory out of version control (idempotent; writes only to the repo-local, never-committed exclude file).
EXCL="$(git rev-parse --git-path info/exclude 2>/dev/null)"
if [ -n "$EXCL" ] && ! grep -qxF ".claude/web-cms-memory/" "$EXCL" 2>/dev/null; then
  printf '.claude/web-cms-memory/\n' >> "$EXCL"
fi
```

`$MEMROOT` (`<project-root>/.claude/web-cms-memory`) is the base that enumeration globs scan (`$MEMROOT/*/work-item.md`). Because the path is derived deterministically from the git worktree root, write-time and resume-time always agree — there is no slug to reconstruct. The git-ignore step writes only to `.git/info/exclude` (never committed), so the ephemeral memory never lands in a commit even though `.claude/` itself is a tracked directory (it holds the deployed skills/agents). Run git checks as **separate** Bash calls (never chained with `&&`).

---

## 2. Directory & file layout (one work item)

```
<MEM>/                       # = $MEM from the recipe above
├── work-item.md             # root + enumeration anchor (mixed)
├── checkpoint.md            # SINGLE overwritten per-phase checkpoint — the recall surface (structured)
├── plan.md                  # full plan + ## Flowchart + files/testing/doc expectations (prose)
├── clarifications.md        # clarifying / stakeholder Q&A pairs (mixed)
├── criteria.md              # acceptance / fix criteria, verbatim gherkin/outcome (mixed)
├── related-cards.md         # intake-only: relevant related Jira cards' excerpts (mixed)
├── children.md              # epic-only: ordered child roster + status (structured)
├── explorations/
│   └── <area-slug>.md       # one per codebase-explorer instance — parallel-safe (prose)
├── summary.md               # discovery synthesis — cross-workflow reuse (prose)
└── work-item.html           # GENERATED dashboard — write-only, never read back
```

**There is no index/registry file.** The directory name is the key; `work-item.md` frontmatter is the per-item record (`Glob $MEMROOT/*/work-item.md` lists in-flight items). "Which files exist" is read from the directory listing — never a maintained manifest.

Optional files only exist when a workflow produces them; an absent file is a cheap `Glob`/`test -f` miss. Format follows content: structured-dominant files lead with frontmatter; prose files lead with the markdown body. `## Flowchart`/`## Architecture` use ` ```mermaid ` fences.

Slug normalization (everywhere): lowercase; runs of whitespace/punctuation/slashes → single `-`; trim; collapse repeats.

---

## 3. File schemas

Dates are `YYYY-MM-DD`; `git_sha`/`head_sha` from `git rev-parse HEAD` (or `git log --oneline -1`). Keep frontmatter flat and shallow so hand edits and partial reads stay robust.

### 3.1 `work-item.md` — root + enumeration anchor

```markdown
---
schema: web-cms-memory/work-item@1
work_item_key: PROJ-123          # Jira key or intake-/discovery- slug
work_type: task                  # task | bug | epic | intake | discovery | code-review | mr
jira_key: PROJ-123               # null when slug-based
title: Add retry logic to payment service
status: in_progress              # in_progress | awaiting_approval | complete | abandoned
phase: T8                        # current/last-entered phase id
skill: task-card
mode: null                       # define | fill_out (intake) | null
existing_issue_type: null        # Epic | Task (intake fill-out) | null
epic_integration_branch: null    # set for epic child tasks
requested_by: null
created_at: 2026-06-03
updated_at: 2026-06-03
---

## Description
<full work-item description / problem statement — verbatim, never truncated>

## Architecture
<!-- OPTIONAL: include a ```mermaid fence here ONLY when a root-level diagram is read back later
     (epic child-sequencing flowchart read at E8, or a discovery/intake architecture diagram reused at T4).
     Otherwise the flowchart lives only in plan.md. -->
```

### 3.2 `checkpoint.md` — the recall surface (overwritten after every phase)

```markdown
---
schema: web-cms-memory/checkpoint@1
work_item_key: PROJ-123
jira_key: PROJ-123
skill: task-card
phase: T8                         # the phase that just completed
next_phase: T9                    # where to resume
checkpoint_type: phase            # phase | gate | manual
branch: feature/PROJ-123-retry    # or "none"
head_sha: a1b2c3d                 # or "n/a"
approval_condition: "Approve and proceed"   # verbatim user phrasing, or "none"
reviewer_iterations: { impl: 2, test: 1, doc: 1 }   # T8/B10 only; else null
child_completed: null             # epic E8 / R5B only
next_child: null                  # epic E8 / R5B only
references:                       # files to reopen on resume (the full-context-load set)
  - plan.md
  - explorations/payment-core.md
  - criteria.md
written_at: 2026-06-03T14:31:00Z
---

## Decisions
- One bullet per key decision made this phase. Required (at least one).

## Open items
- One bullet per open item. May be empty.

## Resume contract
Read this file → open every `references` file → `git status` → re-read the `<next_phase>` section of this skill's `workflow.md` → continue at `<next_phase>`.
```

### 3.3 `plan.md` — `plan` / `fix_plan`

```markdown
---
schema: web-cms-memory/plan@1
work_item_key: PROJ-123
plan_type: plan                  # plan | fix_plan
status: approved                 # draft | approved | review_escalated
reviewer_iterations: 1
files_to_change:
  - src/payments/PaymentClient.java
approved_at: 2026-06-03
---

## Plan
<full reviewed plan text, verbatim — no truncation>

## Flowchart
```mermaid
flowchart TD
  ...
```

## Testing expectations
<verbatim testing expectations consumed by test-reviewer>

## Documentation expectations
<verbatim doc expectations consumed by documentation-reviewer>
```

### 3.4 `explorations/<area-slug>.md` — one per codebase-explorer instance

Frontmatter carries the structured findings (so `area-mapper` and synthesis phases consume them by key); the body is a human-readable mirror. The frontmatter arrays ARE the old `exploration → contains → {...}` subgraph, serialized.

```markdown
---
schema: web-cms-memory/exploration@1
work_item_key: PROJ-123
area_slug: payment-core
area: "Payment service — charge path"
question: "What governs the charge path and affects adding retries?"
explored_at: 2026-06-03
git_sha: a1b2c3d
summary: "Charge path centralizes on PaymentClient.charge(); BackoffPolicy reused by 3 callers; no retry today."
memory_read: yes                 # was a codebase-map-<area>.md serena memory read as a hint?
affected_files:
  - { path: src/payments/PaymentClient.java, role: "charge entrypoint", relevance: high, risk: medium, line_range: "40-120" }
evidence:
  - { claim: "charge() has no retry", file: src/payments/PaymentClient.java, line_range: "84-95", evidence_type: existence, confidence: high, inferred: false }
patterns:
  - { name: "Result-wrapped gateway calls", description: "...", evidence_files: [src/payments/PaymentClient.java] }
integration_points:
  - { with_area: ledger, interface: "LedgerClient.record()", description: "...", direction: outbound }
risks:
  - { severity: medium, description: "double-charge if retry fires after silent success", files: [src/payments/PaymentClient.java] }
open_questions:
  - { question: "Is the idempotency-key honored on retry?", why_unanswered: "no fixture", blocks: false }
---

## Summary
<1–3 sentences answering the assigned question>

## Affected files
- `path` (line_range) — role [relevance, risk]

## Patterns & conventions
- <name> — description [evidence: file1, file2]

## Integration points
- <with_area> via `interface` (direction)

## Risks
- [severity] description

## Open questions
- question (why_unanswered; blocks?)
```

`evidence_type`: `existence | pattern | reference_chain | behavior | convention`. `confidence`/`relevance`/`risk`/`severity`: `high | medium | low`. Mark anything not directly grounded in code with `inferred: true`.

### 3.5 `clarifications.md` — Q&A pairs

```markdown
---
schema: web-cms-memory/clarifications@1
work_item_key: PROJ-123
items:
  - id: qa-scope-1
    priority: blocking            # blocking | nice_to_have
    category: scope_boundary      # scope_boundary | dependencies | non_functional | data_interface |
                                  # observability | functional | edge_cases | risk_rollback |
                                  # remediation_approach | regression_risk | testing | rollout
    question: "What is explicitly out of scope?"
    answer: "Refunds remain synchronous; only charge calls get retries."
    child_key: null               # R5B per-child Q&A only
updated_at: 2026-06-03
---

## Q&A log
**[BLOCKING] Scope boundary** — What is explicitly out of scope?
> Refunds remain synchronous; only charge calls get retries.
```

### 3.6 `criteria.md` — acceptance / fix criteria (intake-scoped)

```markdown
---
schema: web-cms-memory/criteria@1
work_item_key: PROJ-123
format: gherkin                  # gherkin | outcome_based
criteria:
  - { id: crit-1, traceable_to: qa-functional-1, text: "Charge retries up to 3× on 5xx with backoff" }
updated_at: 2026-06-03
---

## Acceptance Criteria
```gherkin
Feature: Payment retry
  Scenario: Transient 5xx triggers retry
    Given a charge request
    When the gateway returns 503
    Then the client retries up to 3 times with exponential backoff
```
```

The fenced block is verbatim so R5 copies it into the Jira description with no reconstruction.

### 3.7 `related-cards.md` — relevant related Jira cards (intake-only)

Written at R1/I1 for related cards that pass the **relevance bar** (materially informs scope/design/implementation — not merely a duplicate to flag). Cards that fail the bar are logged in chat, not stored.

```markdown
---
schema: web-cms-memory/related-cards@1
work_item_key: intake-add-retry-logic
cards:
  - key: ELI-900
    title: "Define retry envelope for gateway calls"
    status: Done
    relationship: prior-art       # overlaps | depends-on | prior-art | same-area | superseded-by
    why_relevant: "Established the BackoffPolicy contract this work must mirror."
updated_at: 2026-06-03
---

## ELI-900 — Define retry envelope for gateway calls  [prior-art, Done]
> Concise excerpt of the pertinent section only (never the whole description).
```

Consumer: R4 synthesis distills material cards into the new Jira card (`## Dependencies` for depends-on/blocks, `## Patterns & Code References` for prior-art/same-area, `## Context` for background; a `## Related Work` note only if none fit). Execution then inherits the context through the Jira card.

### 3.8 `children.md` — epic child roster (epic-only)

The authoritative execution-state map. Written at E4/E6; the `status` of a child is updated after it completes/merges at E8.

```markdown
---
schema: web-cms-memory/children@1
work_item_key: ELI-900
children:
  - { key: ELI-901, title: "Add BackoffPolicy", order: 1, depends_on: [], status: done, branch: feature/ELI-901 }
  - { key: ELI-902, title: "Wire retries into charge()", order: 2, depends_on: [ELI-901], status: in_progress, branch: feature/ELI-902 }
  - { key: ELI-903, title: "Metrics", order: 3, depends_on: [ELI-902], status: pending, branch: null }
updated_at: 2026-06-03
---

## Child roster
1. ELI-901 — Add BackoffPolicy — **done**
2. ELI-902 — Wire retries into charge() — **in_progress**
3. ELI-903 — Metrics — pending (depends on ELI-902)
```

`status`: `pending | in_progress | done | skipped`. E8 reads this to pick the next `pending` child whose `depends_on` are all `done`.

### 3.9 `summary.md` — discovery synthesis

```markdown
---
schema: web-cms-memory/summary@1
work_item_key: discovery-notification-fanout
summary_type: discovery          # discovery | changes
topic_slug: notification-fanout
chosen_approach: "fan-out via existing queue"
verification_status: accepted    # accepted | accepted_with_open_questions
discovery_confirmed: true        # set at D5 — gates the intake discovery pre-check
affected_areas: [src/notify, src/queue]
updated_at: 2026-06-03
---

## Synthesis (chosen)
<synthesis text for discovery, or summary-of-changes for an execution skill>

## Open questions
- ...
```

---

## 4. Checkpoint & Compaction Contract

Two decoupled mechanisms, both backed by the single overwritten `checkpoint.md`. Recording state (frequent, automatic) is separate from asking the user to compact (only at heavy points) — this protects against early/auto-compaction and session interruptions, not just the orchestrated manual `/compact`.

### (a) Per-phase checkpoint — after EVERY phase completes (automatic, no prompt)

1. Two separate Bash calls: `git branch --show-current` and `git log --oneline -1` (use `"none"`/`"n/a"` if no commits yet).
2. **Overwrite `checkpoint.md`** (§3.2) with `checkpoint_type: phase`, the just-completed `phase`, the upcoming `next_phase`, the `references` list (the full-context-load set for the next phase — see §5), and any skill-specific fields (`reviewer_iterations` at T8/B10, `child_completed`/`next_child` at epic E8 / R5B). Overwriting **is** the supersession — no enumeration, no history.
3. Write **atomically**: `Write` the content to `checkpoint.md.tmp`, then `mv "$MEM/checkpoint.md.tmp" "$MEM/checkpoint.md"` (Bash), so an interruption mid-write cannot corrupt the recall surface.
4. No chat output, no `/compact` prompt — continue straight into the next phase.

### (b) Compaction gate — only at the designated key points

Each skill marks its gates (e.g. task-card T3/T5/T8). At a gate, do the per-phase write as above but with `checkpoint_type: gate`, plus:

1. Wait for any background `area-mapper` sub-agent to finish.
2. Emit the **Phase Summary block** in chat:

```
---
**COMPACTION CHECKPOINT — <skill> <phase>**

- Workflow: <skill>
- Work item: <KEY>
- Branch: <branch> @ <head_sha>
- Decisions: <one-line summary>
- Approval condition: <verbatim, or "none">
- Reviewer iterations: impl=N test=N doc=N      (T8/B10 only)
- Resume at: <next_phase>
- Checkpoint file: web-cms-memory/<KEY>/checkpoint.md
- Resume contract: Read checkpoint.md → open its `references` files → `git status` → re-read the <next_phase> section of workflow.md → continue at <next_phase>.
---
```

3. End the turn with this literal line (and nothing after it): **"Run `/compact` now, then type `continue` to resume."** Do NOT call `AskUserQuestion` here — the user's prompt input must stay free for `/compact`.

### (c) Universal resume rule — on ANY resume, before doing anything else

Covers all recovery paths: the user typed `continue` after a manual `/compact`; auto-compaction injected a summary mid-phase; or a fresh session re-invoked the skill.

1. `Read <MEM>/checkpoint.md` (replaces `open_nodes` on the handoff entity).
2. `Read` every file in `references` (replaces traversing `REFERENCES`). If a referenced file is missing, `Glob <MEM>` and read what's present.
3. Verify git: `git status`, `git branch --show-current`, `git log --oneline -1`; compare against `branch`/`head_sha` and surface any drift.
4. **Re-read the `next_phase` section of this skill's `workflow.md`** so its full instructions (especially `AskUserQuestion` requirements) survive compaction.
5. Continue at `next_phase`. Approval gates stay chat-scoped — never assume a pending approval was granted.

**If `<MEM>` / `checkpoint.md` is absent** (new/abandoned session, or it was deleted): reconstruct state from the Jira issue description and durable comment history, then recreate `work-item.md` and continue. For keyless intake/discovery work items there is nothing to reconstruct from — start over.

---

## 5. Full-context load at the two critical stages

Because memory is per-work-item and small, load the **entire** work-item directory at the two moments that matter — the scoped equivalent of the old `read_graph`, with no cross-contamination. Both stages `Glob <MEM>` and `Read` every present input file before proceeding; `checkpoint.md`'s `references` names this same set so resume reloads it identically.

**Plan-crafting stage** (task T4 · bug B5 · epic E4 · intake R4 · discovery D2/D3) — read `work-item.md`, every `explorations/*.md`, `clarifications.md`, `related-cards.md`, `summary.md`, and (intake) `criteria.md` before drafting the plan / criteria / breakdown.

**Implementation stage** (task T8 · bug B10 · epic E8 per child) — read `plan.md` (full: `## Plan`, `## Flowchart`, `files_to_change`, testing/doc expectations), every `explorations/*.md`, `work-item.md`, and any `clarifications.md`/`related-cards.md`; acceptance criteria come from the Jira card in execution skills.

---

## 6. Codebase-explorer → area-mapper (file form)

The one cross-agent data flow. Each `codebase-explorer` writes its OWN `explorations/<area-slug>.md` (distinct slugs → distinct files → structurally parallel-safe, no locks). `area-mapper` enumerates them with `Glob <MEM>/explorations/*.md`, reads each, and crystallizes durable knowledge into Serena `codebase-map-<area>.md` memories (Serena output, quality bar, and merge logic unchanged). The orchestrator confirms a write by `Read`ing the file (not `open_nodes`).

---

## 7. Cleanup (atomic)

The final cleanup phase of a workflow (task T13, bug B15, epic E11, requirements/design R6, issue I6, code-review CR11, mr M7) removes the whole directory:

```bash
rm -rf "$MEM"
```

One atomic op — no entity enumeration, so nothing is missed, and an abandoned work item's leftover dir never pollutes another's recall. Skills with a "present cleanup plan, then confirm" gate (R6) keep that gate: print the dir path + a file count, `AskUserQuestion`, then `rm -rf` on confirm. **Epic mode:** E11 removes the epic dir AND every child dir listed in `children.md`; a child's T13 does NOT self-clean under an epic. **implementation-discovery does NOT clean up** — its `summary.md` persists for a follow-on `requirements-intake` R0; that R6 owns teardown.

---

## 8. HTML dashboard (`work-item.html`)

A write-only, human-facing view — the agent never reads it back. One self-contained file with each source markdown embedded inline in `<script type="text/markdown">` blocks, rendered client-side by CDN `marked.js` + `mermaid.js`. Inline embedding (not `fetch()`) sidesteps the `file://` CORS block, so it opens by double-click with no server and no build step.

**Regenerate** (full overwrite) after plan approval and after a summary phase (optionally at gates). Escape any literal `</script>` in embedded content to `<\/script>`. Sections: header (key/title/status from `work-item.md`; branch/sha from `checkpoint.md`) · Plan (`plan.md`) · Flowchart (`plan.md ## Flowchart`, else `work-item.md ## Architecture`) · Decisions / Open items (`checkpoint.md`) · Acceptance criteria (`criteria.md`) · Summary (`summary.md`).

Template skeleton:

```html
<!doctype html><html><head><meta charset="utf-8">
<title>{{KEY}} — web-cms memory</title>
<script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
<script type="module">
  import mermaid from "https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.esm.min.mjs";
  mermaid.initialize({ startOnLoad: false });
  window.addEventListener("DOMContentLoaded", () => {
    document.querySelectorAll('script[type="text/markdown"]').forEach(s => {
      const el = document.getElementById(s.dataset.target);
      el.innerHTML = marked.parse(s.textContent);
      el.querySelectorAll('code.language-mermaid').forEach(c => {
        const pre = document.createElement('pre');
        pre.className = 'mermaid'; pre.textContent = c.textContent;
        c.closest('pre').replaceWith(pre);
      });
    });
    mermaid.run();
  });
</script>
<style>body{font:14px/1.5 system-ui,sans-serif;max-width:60rem;margin:2rem auto;padding:0 1rem}
.badge{padding:.1rem .5rem;border-radius:.4rem;background:#eee}.badge.complete{background:#d4edda}
section{border-top:1px solid #ddd;margin-top:1.5rem;padding-top:.5rem}</style>
</head><body>
  <header>
    <h1>{{KEY}} — {{TITLE}}</h1>
    <span class="badge {{STATUS}}">{{STATUS}}</span>
    <div>{{BRANCH}} @ {{SHA}} · resume at {{NEXT_PHASE}}</div>
  </header>
  <section id="plan-out"></section>
  <script type="text/markdown" data-target="plan-out">{{plan.md ## Plan + ## Flowchart}}</script>
  <section id="decisions-out"></section>
  <script type="text/markdown" data-target="decisions-out">{{checkpoint.md ## Decisions + ## Open items}}</script>
  <section id="criteria-out"></section>
  <script type="text/markdown" data-target="criteria-out">{{criteria.md body}}</script>
  <section id="summary-out"></section>
  <script type="text/markdown" data-target="summary-out">{{summary.md body}}</script>
</body></html>
```

