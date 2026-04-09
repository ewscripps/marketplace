---
name: coaching-review
description: Run monthly coaching inventory review. Syncs with Ada MCP, tracks coaching effectiveness, guides new coaching implementation.
user-invocable: true
allowed-tools: Bash(python3 *), Bash(mkdir *), Bash(cp *), Bash(ls *), Read, Grep, Glob, AskUserQuestion, Skill
---

# Coaching Management Review

Monthly workflow to evaluate existing coaching performance and maintain the coaching inventory.

**Primary Focus:** Measure efficacy of existing coaching rules
**Secondary:** Recommend new coaching when gaps identified

**Frequency:** Monthly (standalone workflow)

## Step -1: Pre-Flight

Invoke the preflight skill to ensure the workspace is ready:

```
skill: "preflight"
```

After preflight completes, all subsequent steps operate in `~/repos/ada-tablo-ops`.

## Quick Run (Routine Check)

Use when no major changes expected since last review:

1. **Load context** (Step 0) — Check last sync date
2. **Skip Steps 1-2** if CSV exists for this month
3. **Spot-check 5 highest-usage coaching** for resolution rates (Step 3a)
4. **Flag any issues** found
5. **Update Last Sync date** only if checks passed

Skip Quick Run if: >30 days since last sync, known issues pending, or significant Ada changes.

## Step 0: Load Context

Read these files to understand current state:

1. **Coaching Inventory** — Current coaching list and static reference:
   ```
   ~/repos/ada-tablo-ops/reference/coaching_inventory.md
   ```

2. **Review History** — Past insights and performance trends:
   ```
   ~/repos/ada-tablo-ops/reference/coaching_review_history.md
   ```

**From Inventory:** Summary counts, high-impact coaching list, custom instructions, pending recommendations
**From History:** Last review date, resolution rate trends, flagged concerns, month-over-month changes

Tell user:
```
Last review: [date from most recent history entry]
Total coaching: [X] | Active (used): [Y] | Inactive: [Z]
High-impact items: [count with >10 uses/week]
Previous concerns: [any flagged items from last review]
```

## Step 1: Sync with Ada

**Skip if:** CSV export already exists for this month (`~/repos/ada-tablo-ops/output/YYYY-MM/coaching_export_YYYYMM*.csv`)

**IMPORTANT: MCP Capabilities & Limitations**

**What MCP CAN do:**
- `COACHINGAPPLIED` filter: Get resolution rates for specific coaching IDs
- `search_coaching`: Find coaching IDs via semantic search (need IDs for filtering)

**What MCP CANNOT do:**
- `get_ada_configuration` returns only Custom Instructions (global behavior rules)
- `search_coaching` cannot enumerate all coaching — only finds items matching query terms
- No way to list all coaching rules — requires UI export

**Option A: Manual UI Export (Recommended monthly)**

Ask user to export from Ada UI:
1. Go to: Settings > AI Agent > Coaching
2. Copy the coaching list from browser (text dump)
3. Paste into chat for parsing

Parse the dump format:
- Line 1: Action (article/playbook/reply/handoff)
- Line 2: Intent/trigger scenario
- Line 3: Availability rules
- Line 4: Usage count (last 7 days, "-" = 0)
- Line 5: Created date and **owner** (e.g., "Jun 09, 2025 by Lauren")

**Note:** The creator is the owner. Track this for accountability.

Save to: `~/repos/ada-tablo-ops/output/YYYY-MM/coaching_export_YYYYMMDD.csv`

**Compare to Previous Export:**
If previous export exists, compare to identify:
- New coaching added since last sync
- Coaching removed/deleted
- Usage changes (trending up/down)

**Option B: MCP Quick Check (Between full syncs)**

Use `get_ada_configuration` for Custom Instructions only:
- Token cost: ~2-5k tokens
- Returns global behavior rules

Use `search_coaching` for targeted lookups:
- "registration setup firmware"
- "connectivity troubleshooting"
- Token cost: ~500 tokens per query
- Will miss items not matching queries

**Sync Comparison:**

| Status | Description |
|--------|-------------|
| **New in Ada** | Found in Ada but not in inventory |
| **Missing from Ada** | In inventory but not found in Ada |
| **Match** | Items in sync |

Present findings:
```
Sync Results:
- Total coaching in Ada: [X]
- Custom Instructions: [N]
- High-impact (>10 uses/week): X
- New since last sync: Y
```

## Step 2: Update Inventory from Sync

**Skip if:** Step 1 was skipped (CSV already exists for this month)

**If first sync (no previous CSV):**
- Parse all coaching into CSV
- Update inventory summary counts
- Identify high-impact items (>10 uses/week)

**If incremental sync (previous CSV exists):**
- Compare intents between old and new CSV
- Report: "X new coaching added, Y removed, Z with changed usage"
- Add new items to inventory summary

**For new coaching found:**
- Note in High-Impact section if >10 uses
- Owner = creator from CSV (already captured)

**For missing coaching:**
- Move to Deprecated section with date
- Note reason: "Removed from Ada"

Update "Last Sync" date in Summary table.
Save new CSV, keep previous for comparison.

## Step 3: Evaluate Existing Coaching Performance

**This is the primary focus of the review.**

### 3a: Measure Resolution Rates (Primary Method)

**Date Range Strategy:**
- Default: From last sync date to today
- New coaching (<30 days old): Since creation date
- First review: Last 30 days

Use the `COACHINGAPPLIED` filter to measure actual effectiveness:

1. **Find coaching IDs** via `search_coaching`:
   ```
   search_coaching(query="power cycle instructions", limit=3)
   # Returns coaching_id like "684723241119c4a75c522d5f"
   ```

   **Note:** CSV export doesn't include coaching IDs. Cache IDs in a separate file or re-search each month.

2. **Check resolution rate** for conversations where coaching fired:
   ```
   get_ada_metric(
     metric_type="resolution_rate",
     start_date="[last_sync_date]",
     end_date="[today]",
     filters=[{"type": "COACHINGAPPLIED", "operator": "IS", "value": ["coaching_id_here"]}]
   )
   ```

3. **Interpret results:**
   | Resolution Rate | Assessment |
   |-----------------|------------|
   | >80% | Highly effective |
   | 60-80% | Moderate — monitor |
   | <50% | Low — needs review |
   | <30% | Poor — likely not helping |

**Note:** Low resolution doesn't always mean bad coaching. Some coaching (like "ask clarifying questions") naturally leads to longer conversations. Consider the coaching's purpose.

**Which items to check:**
Check ALL high-impact coaching (>10 uses/week) each review. This ensures comprehensive coverage and catches declining performance early.

### 3b: Identify Performance Concerns

Review high-impact coaching (>10 uses/week) for issues:
- Resolution rate below 50%?
- Usage dropping significantly from previous month? (>30% decline)
- Content accuracy issues (outdated info)?

### 3c: Flag for Action

| Status | Action |
|--------|--------|
| High-use + high resolution | No action needed |
| High-use + low resolution | Review if coaching helps or delays resolution |
| Low-use + high resolution | Keep — effective for niche scenarios |
| Low-use + low resolution | Consider deprecation |

### 3d: Inactive Coaching Policy

For coaching with 0 uses/week (currently ~85 items):
- **Annual review:** Check if content is still accurate
- **Deprecate if:** Inactive >6 months AND content outdated
- **Keep if:** Content accurate (may be relevant for rare scenarios)
- **Skip monthly:** Focus reviews on high-impact items only

## Step 4: Track Month-over-Month Trends

Track month-over-month resolution rates (measured via Step 3a):
- Resolution rate improving or declining?
- Compare to overall resolution rate baseline

**Secondary Method: Usage Trend Analysis**

The coaching export includes 7-day usage counts. Compare month-over-month:
- Items with declining usage may need review
- High-usage items (>50/week) are critical — monitor for issues

**Update Inventory:**
- Update resolution rates for high-impact coaching
- Flag items with <50% resolution
- Note any coaching with declining effectiveness

## Step 5: Recommend New Coaching (Optional)

**Skip if:** No new coaching recommendations needed from recent analyses

Only after evaluating existing coaching. Review recent analyses for gaps:

1. **Check Sources:**
   - Weekly topics review: `~/repos/ada-tablo-ops/reference/weekly_review_notes.md`
   - Playbook baselines: `~/repos/ada-tablo-ops/reference/playbook_baselines.md`

2. **Cross-Reference:**
   - Is it already in "Recommended Coaching" section?
   - Is similar coaching already Active?

3. **Format New Recommendations:**

```markdown
**Intent:** [What triggers this coaching — user scenario]
**Instruction:** [What Ada should do differently]
**Module:** planner | contextual_response | search_knowledge
**Type:** playbook | handoff | reply | search_knowledge
**Related To:** [Playbook or Topic name]
**Source:** [Which analysis recommended this]
**Priority:** High | Medium | Low
**Assigned Owner:** [Name or "Unassigned"]
```

## Step 6: Guide Implementation (Optional)

**Skip if:** No new coaching to implement from Step 5

For new coaching to implement in Ada:

**Ada UI Navigation:**
1. Go to: Settings > AI Agent > Coaching
2. Click "Add coaching"

**Fill in Fields:**

| Field | Guidance |
|-------|----------|
| **User Intent** | Triggering scenario — be specific about customer situation |
| **Planned Action** | What Ada should do (use playbook, search knowledge, reply directly) |
| **Instructions** | Detailed guidance for Ada's response behavior |

**Module Selection:**
- **Planner:** Affects initial routing/playbook selection (most common)
- **Contextual Response:** Affects reply generation within conversations
- **Search Knowledge:** Affects knowledge base search behavior

**Related Links:**
- Associate with specific playbook if applicable
- Associate with topic if applicable

**After Implementation:**
- Note the coaching ID from Ada
- Add to Active Coaching section with all fields
- Set Status to "Testing"
- Set Created date
- Schedule efficacy check for next month

## Step 7: Update Files

Write changes to BOTH files:

### 7a: Update Inventory (~/repos/ada-tablo-ops/reference/coaching_inventory.md)

Static reference updates only:

1. **Summary Table:**
   - Update Total/Active/Inactive counts with today's date
   - Update "Last Updated" column

2. **High-Impact Coaching:**
   - Add/remove items based on usage changes
   - Update owner info if changed

3. **Recommended Coaching:**
   - Remove items that were implemented (move to Deprecated with implementation date)
   - Add new recommendations from Step 5

4. **Deprecated Coaching:**
   - Move implemented or removed coaching here with date and reason

### 7b: Prepend to History (~/repos/ada-tablo-ops/reference/coaching_review_history.md)

Add new review section at TOP of file (newest first):

```markdown
## YYYY-MM-DD Review

**Reviewed by:** /coaching-review skill
**Date range:** [start_date] to [end_date]
**CSV source:** coaching_export_YYYYMMDD.csv

### Resolution Rates

| Date | Intent | Coaching ID | Usage/wk | Resolution | Assessment |
|------|--------|-------------|----------|------------|------------|
| YYYY-MM-DD | [intent] | [id] | [N] | [X%] | [assessment] |

### Performance Concerns

| Date | Intent | Issue | Usage | Resolution | Action Needed |
|------|--------|-------|-------|------------|---------------|
| YYYY-MM-DD | [intent] | [issue] | [N/wk] | [X%] | [action] |

### Effective Coaching (>80% resolution)

| Date | Intent | Resolution | Usage |
|------|--------|------------|-------|
| YYYY-MM-DD | [intent] | [X%] | [N/wk] |

### Month-over-Month Comparison

| Metric | Previous | Current | Change |
|--------|----------|---------|--------|
| Total coaching | [N] | [N] | [+/-N] |
| High-impact items | [N] | [N] | [+/-N] |
| Avg resolution (high-impact) | [X%] | [X%] | [+/-X%] |
| Performance concerns | [N] | [N] | [+/-N] |

---
```

## Step 8: Commit Results

Invoke the commit-results skill to save output and reference updates:

```
skill: "commit-results", args: "coaching"
```

## Token Efficiency Notes

**MCP Tool Costs:**
See Step 1 for capabilities. Key costs:
- `get_ada_metric`: ~200 tokens per query (preferred)
- `get_conversation`: ~11k tokens — AVOID (ask user for permission if more context needed)

**Strategy:**
1. Monthly: Request UI export from user (free, complete data)
2. Use `search_coaching` to find coaching IDs for high-impact items
3. Use `get_ada_metric` with `COACHINGAPPLIED` filter to check resolution rates
4. Cache coaching IDs in CSV to avoid re-searching

**CSV Management:**
- Keep last 3 monthly exports for trend comparison
- Delete exports older than 3 months
- Location: `~/repos/ada-tablo-ops/output/YYYY-MM/coaching_export_YYYYMMDD.csv`

## DO / DON'T

**DO:**
- Sync with Ada at start of every review
- Check resolution rates for high-impact coaching using `COACHINGAPPLIED` filter
- Track owner (= creator) for accountability
- Document the source analysis for each coaching recommendation
- Move implemented pending items to Active section

**DON'T:**
- Create coaching without clear triggering scenario
- Implement coaching without documenting in inventory
- Forget to update both inventory AND history files
- Use full conversation transcripts for volume analysis
- Assume high usage = effective (check resolution rates)
- Put dynamic insights (resolution rates) in inventory file — use history file

## Completion Checklist

- [ ] Context loaded from inventory AND history (Step 0)
- [ ] CSV exported or skipped (Step 1)
- [ ] Inventory counts updated (Step 2)
- [ ] Resolution rates checked for all high-impact items (Step 3)
- [ ] Performance concerns flagged (Step 3b-c)
- [ ] Trends compared to previous month (Step 4)
- [ ] New recommendations documented if needed (Step 5)
- [ ] Inventory file updated with static changes (Step 7a)
- [ ] History file prepended with new review section (Step 7b)
