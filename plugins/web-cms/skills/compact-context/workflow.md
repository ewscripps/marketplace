# COMPACT-CONTEXT WORKFLOW — EXECUTION CONTRACT

This skill creates a manual compaction checkpoint. It snapshots the active web-cms workflow's position into the work item's `checkpoint.md` and instructs the user to run `/compact`. Invoke at any time when context is growing full mid-workflow, between or during any phase. See `file-memory-protocol.md` for the file-memory layout, the path-resolution recipe (§1), and the `checkpoint.md` schema (§3.2).

**STRICT EXECUTION RULES:**

1. Execute phases C0 through C3 in strict sequential order.
2. If no active work item is found in C0, stop immediately — do not write any file.
3. Do not call `AskUserQuestion` in C3 — the user must be free to run `/compact` without an open question consuming their input.

---

### C0 — Discover Active Work Item

Compute `$MEMROOT` with the recipe in `file-memory-protocol.md` §1 (`ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"`, `MEMROOT="$ROOT/.claude/web-cms-memory"`). Then `Glob "$MEMROOT/*/work-item.md"` to enumerate active work items. `Read` each `work-item.md` frontmatter for its `work_item_key`, `skill`, `status`, and `phase`.

**If no `work-item.md` is found:** There is no active web-cms workflow session. Output exactly: "No active workflow session found. Run `/compact` directly — no checkpoint is needed." Stop.

**If multiple are found:** Use `AskUserQuestion` to ask the user which work item to checkpoint (list each found `work_item_key` — with its `skill` and `status` — as options).

Proceed with the identified work item. Its directory is `$MEM = $MEMROOT/<work_item_key>`.

---

### C1 — Determine Current State

1. **Read the existing checkpoint.** If `$MEM/checkpoint.md` exists, `Read` it for:
   - `skill` — which workflow is running (task-card, bug-card, epic-card, etc.)
   - `next_phase` — the phase queued to execute when the last checkpoint was written (i.e., the phase currently in progress)
   - `branch`, `head_sha` — last recorded git context
   - `references` — the files the resuming skill should reopen

   If `checkpoint.md` is absent, fall back to `work-item.md`'s `skill` and `phase`; use `next_phase: unknown` and note this in the Phase Summary.

2. **Collect the reference file list.** `Glob "$MEM"` (and `"$MEM/explorations"`) to list the present memory files — `plan.md`, `criteria.md`, `clarifications.md`, `children.md`, `summary.md`, `explorations/*.md`, etc. These become the `references` list so the resuming skill reloads full context.

3. **Run git state checks** (two separate Bash calls, do not chain with `&&`):
   - `git branch --show-current`
   - `git log --oneline -1`

   Use these for `branch` and `head_sha` in C2. If the working tree has no commits yet, use `"none"` and `"n/a"`.

---

### C2 — Write the Manual Checkpoint

**Atomically overwrite** `$MEM/checkpoint.md` (`Write` the content to `$MEM/checkpoint.md.tmp`, then `mv "$MEM/checkpoint.md.tmp" "$MEM/checkpoint.md"` via Bash) per the schema in `file-memory-protocol.md` §3.2:

- `work_item_key: <key>`, `jira_key: <key or null>`
- `skill: <skill from C1, or "unknown">`
- `phase: manual-checkpoint`
- `next_phase: <next_phase from the prior checkpoint — the phase currently in progress, or "unknown">`
- `checkpoint_type: manual`
- `branch: <branch from C1>`, `head_sha: <head_sha from C1>`
- `references: <the file list collected in C1>`
- `## Decisions`: "Manual checkpoint — resume workflow at next_phase."
- `## Open items`: carry forward any from the prior checkpoint, or empty.

Overwriting in place IS the supersession — there is no separate handoff entity and nothing to enumerate. `Read` `$MEM/checkpoint.md` once after the write to confirm it landed; if it comes back empty, include a warning line in the C3 Phase Summary but continue.

> **Note on repeated calls:** Running `/compact-context` more than once just overwrites `checkpoint.md` again with fresh git state and `next_phase` — the file always reflects the latest checkpoint.

---

### C3 — Emit Phase Summary and Compact Instruction

Emit the following Phase Summary block (fill in placeholders):

```
---
**MANUAL COMPACTION CHECKPOINT**

- **Workflow:** <skill>
- **Work item:** <key>
- **Branch:** <branch> @ <head_sha>
- **Resume at:** <next_phase>
- **Checkpoint file:** web-cms-memory/<key>/checkpoint.md
- **Resume contract:** After compaction, invoke `/<skill> <key>` and type `continue`. The skill will read `checkpoint.md`, reopen its `references` files, verify git state, and resume at `<next_phase>`.
---
```

End your turn immediately after this block with this literal line: **"Run `/compact` now, then re-invoke `/<skill> <key>` and type `continue` to resume."**

Do NOT call `AskUserQuestion` here. Do not add any content after this line.
