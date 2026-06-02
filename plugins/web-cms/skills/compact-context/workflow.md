# COMPACT-CONTEXT WORKFLOW — EXECUTION CONTRACT

This skill creates a manual compaction checkpoint. It snapshots the active web-cms workflow session into the knowledge graph and instructs the user to run `/compact`. Invoke at any time when context is growing full mid-workflow, between or during any phase.

**STRICT EXECUTION RULES:**

1. Execute phases C0 through C3 in strict sequential order.
2. If no active session is found in C0, stop immediately — do not attempt to create any entity.
3. Do not call `AskUserQuestion` in C3 — the user must be free to run `/compact` without an open question consuming their input.

---

### C0 — Discover Active Session

Call `read_graph` to enumerate all entities in the current knowledge graph.

Look for:
- **`work_item-<KEY>`** entities (name starts with `work_item-`) — identifies the active Jira key(s)
- **`phase_handoff`** entities (name starts with `phase-handoff-`) — identifies previous compaction gates
- **Context entities:** `plan-<KEY>`, `fix_plan-<KEY>`, `exploration-*`, `root_cause-*`, `affected_area-*`

**If no `work_item-*` entity exists:** The knowledge graph has no active web-cms workflow session. Output exactly: "No active workflow session found in the knowledge graph. Run `/compact` directly — no handoff entity is needed." Stop.

**If multiple `work_item-*` entities exist:** Use `AskUserQuestion` to ask the user which Jira key to checkpoint (list all found keys as options).

Proceed with the identified work item key.

---

### C1 — Determine Current State

1. **Find the most recent `phase_handoff` entity** for this work item. If multiple exist (e.g., `phase-handoff-ELI-123-T3`, `phase-handoff-ELI-123-T5`), identify the latest by phase ordering. Call `open_nodes` on it to read its observations:
   - `skill` — which workflow is running (task-card, bug-card, epic-card, etc.)
   - `next_phase` — the phase that was queued to execute when the last gate fired (i.e., the phase currently in progress)
   - `branch`, `head_sha` — last recorded git context

2. **Collect entity names for REFERENCES.** From the `read_graph` results, collect names of all context entities linked to this work item: `plan-<KEY>` or `fix_plan-<KEY>`, any `exploration-*` entities, `root_cause-<KEY>`, `affected_area-*`, etc. These will be forwarded as REFERENCES so the resuming skill can reconstruct state.

3. **Run git state checks** (two separate Bash calls, do not chain with `&&`):
   - `git branch --show-current`
   - `git log --oneline -1`

   Use these results for `branch` and `head_sha` in C2. If the working tree has no commits yet, use `"none"` and `"n/a"`.

**If no `phase_handoff` entity exists:** The workflow is before its first compaction gate. Use `skill: unknown` and `next_phase: unknown` in C2, and note this in the Phase Summary.

---

### C2 — Write Phase Handoff Entity

Create a `phase_handoff` entity to capture the current checkpoint:

- **Name:** `phase-handoff-<KEY>-manual`
- **Entity type:** `phase_handoff`
- **Observations:**
  - `phase: manual-checkpoint`
  - `skill: <skill-name from C1, or "unknown">`
  - `jira_key: <KEY>`
  - `branch: <branch from C1 git check>`
  - `head_sha: <HEAD SHA from C1 git check>`
  - `next_phase: <next_phase from the prior phase_handoff — the phase currently in progress, or "unknown" if no prior handoff>`
  - `checkpoint_type: manual`
  - `decisions: Manual checkpoint — resume workflow at next_phase`

**Relations to create:**
  - `BELONGS_TO` → `work_item-<KEY>`
  - `SUPERSEDES` → prior `phase_handoff` entity for this work item (if any — use the most recent gate entity name from C1)
  - `REFERENCES` → each context entity name collected in C1 (one `REFERENCES` relation per entity)

Call `open_nodes` on `phase-handoff-<KEY>-manual` immediately after creation to confirm the write landed. If the entity comes back empty, include a warning line in the Phase Summary block in C3 but continue.

> **Note on repeated calls:** If the user runs `/compact-context` more than once in the same session, the second call will find `phase-handoff-<KEY>-manual` already present from the first call. Treat it as the prior handoff for SUPERSEDES purposes and create a fresh entity with updated observations. The graph's create call will overwrite the existing entity.

---

### C3 — Emit Phase Summary and Compact Instruction

Emit the following Phase Summary block (fill in placeholders):

```
---
**MANUAL COMPACTION CHECKPOINT**

- **Workflow:** <skill-name>
- **Jira key:** <KEY>
- **Branch:** <branch>
- **HEAD SHA:** <sha>
- **Resume at:** <next_phase>
- **Handoff entity:** `phase-handoff-<KEY>-manual`
- **Resume contract:** After compaction, invoke `/<skill-name> <KEY>` and type `continue`. The skill will call `open_nodes` on `phase-handoff-<KEY>-manual`, traverse its REFERENCES, verify git state, and resume at `<next_phase>`.
---
```

End your turn immediately after this block with this literal line: **"Run `/compact` now, then re-invoke `/<skill-name> <KEY>` and type `continue` to resume."**

Do NOT call `AskUserQuestion` here. Do not add any content after this line.
