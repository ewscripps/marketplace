---
name: weekly-topics-review
description: Run weekly Ada Topics review for catch-all reduction. Guides CSV export, analyzes catch-all %, proposes and applies topic description edits via edit_agent_config.
user-invocable: true
allowed-tools: Bash(python3 ~/repos/ada-tablo-ops/scripts/analyze_topics_report.py *), Bash(python3 ~/repos/ada-tablo-ops/scripts/analyze_catchall_conversations.py *), Bash(mkdir *), Bash(cp *), Bash(ls *), Read, Grep, Glob, AskUserQuestion, Skill
---

# Weekly Topics Review

Automates the Friday Ada-Tablo topics analysis workflow to reduce catch-all routing.

## Step -1: Pre-Flight

Invoke the preflight skill to ensure the workspace is ready:

```
skill: "preflight"
```

After preflight completes, all subsequent steps operate in `~/repos/ada-tablo-ops`.

If this is the first `edit_agent_config` call of the session, call `get_improvement_guide()`
once before proposing or applying any edit — its output stays in context for the rest of the
session, so do not re-call it.

## Step 0: Load Context

Read the weekly review notes to understand current state:

**Weekly Review Notes** — Progress table, active issues, implementation log:
   ```
   ~/repos/ada-tablo-ops/reference/weekly_review_notes.md
   ```

Extract from weekly_review_notes.md:
- Current catch-all % (from Progress Summary table, most recent row)
- Last review date
- Active issues being tracked
- Pending verification items

Tell user:
```
Last review: [date] at [catch-all %]
Active issues: [list from Active Issues table]
```

## Step 1: Topics Report CSV Export

Guide user to export the topics report from Ada:

**Ada Dashboard:** https://nuvyyo-gr.ada.support/insights/topics

**Export Steps:**
1. Go to Topics Report (URL above)
2. Set date range to **last 7 days** (or since last review)
3. Click Download CSV → Downloads as `topics_report.csv` or `topics_report (n).csv`
4. Move to project: `~/repos/ada-tablo-ops/output/YYYY-MM/topics_report_YYYY-MM-DD.csv`

Ask user for the CSV file path once downloaded.

## Step 2: Run Topics Analysis Script

Execute the analysis script with the CSV path:

```bash
python3 ~/repos/ada-tablo-ops/scripts/analyze_topics_report.py ~/repos/ada-tablo-ops/output/YYYY-MM/topics_report_YYYY-MM-DD.csv
```

Script outputs:
- Catch-all percentage (Unclear + Other Inquiries)
- Comparison to baseline
- Top 10 topics by volume
- Performance flags (low CSAT, high AR opportunity)

## Step 3: Calculate Change from Previous Week

Compare current catch-all % to previous week from Progress Summary table:

| Metric | Previous | Current | Change |
|--------|----------|---------|--------|
| Catch-All % | [X]% | [Y]% | [+/-Z]% |
| Unclear/Incomplete | [X]% | [Y]% | [+/-Z]% |
| Other Inquiries | [X]% | [Y]% | [+/-Z]% |

Flag if:
- Catch-all increased by >2% (investigate what changed)
- Catch-all decreased by >3% (confirm which changes worked)

## Step 3b: Mid-Week Catch-All Spot Check (Optional)

Catch-all % can be spot-checked any time via MCP — no CSV export needed. Useful mid-week to verify whether a deployed change is moving the number before Friday's full review.

**Catch-all topic IDs (for TOPIC filters):**

| Topic | ID |
|-------|-----|
| Unclear or Incomplete Inquiries | `67f95e779a99fb6bdfe534a8` |
| Other Inquiries | `67fec3bbac473f6c4a232f93` |

1. **Filtered volume** (both catch-all topics):
   ```
   get_ada_metric(
     metric_type="conversation_volume_engaged",
     start_date="[start]", end_date="[end]",
     filters=[{"type": "TOPIC", "operator": "IS", "value": ["67f95e779a99fb6bdfe534a8", "67fec3bbac473f6c4a232f93"]}]
   )
   ```
2. **Total volume:** same call without filters
3. **Catch-all % = filtered ÷ total**

This is a spot check only — the Friday review still uses the topics report CSV for the full per-topic breakdown.

## Step 4: Check Active Issues

Review Active Issues table from weekly_review_notes.md. For each tracked item:
- Is it due for verification this week?
- Did the metric improve as expected?
- Should it be marked Done or need continued tracking?

## Step 5: Deep-Dive on Catch-All (If Needed)

If catch-all increased OR user wants pattern analysis:

1. **Option A: Pull catch-all conversation summaries via Ada MCP (default)**
   - Token-efficient: ~100-200 tokens per conversation
   - Filter directly to the two catch-all topics (IDs in Step 3b):
   ```
   get_conversations(
     detail_level="SUMMARY",
     start_date="[start]", end_date="[end]",
     filters=[{"type": "TOPIC", "operator": "IS", "value": ["67f95e779a99fb6bdfe534a8", "67fec3bbac473f6c4a232f93"]}]
   )
   ```
   - Identify patterns from the Inquiry Summary / Classification fields

2. **Option B: Run catch-all analysis script (fallback for large samples)**
   - Requires conversation export (not topics report)
   - Identifies keyword patterns in catch-all conversations
   - Use when the sample is too large to review via summaries
   ```bash
   python3 ~/repos/ada-tablo-ops/scripts/analyze_catchall_conversations.py [conversations.csv]
   ```

3. **Option C: Sample specific conversations via MCP**
   - Use sparingly: ~11k tokens per conversation
   - Get 2-3 representative conversations for pattern identification

## Step 6: Generate Recommendations

For any topic improvements identified, use this EXACT format:

```markdown
**Category name:** [verbatim from CSV]
**Topic name:** [verbatim from CSV]
**Topic ID:** [from list_entities(entity_type="topics") — needed for Step 6b]
**Current description:** [copy from CSV or Ada UI]
**Proposed description:**
[Full text of new description, using the format:]
Your task is to identify [X]. Apply when [specific scenarios]. Do not apply if [explicit exclusions].
**Rationale:** [why this change will help]
```

Key principles:
- Use actual customer phrases from catch-all analysis
- Be super specific about what IS and ISN'T included
- Reference other topics to reduce overlap ("Do not apply for X — use Category > Topic instead")

Limit to 2-3 recommendations unless more are critical.

## Step 6b: Apply Approved Recommendations via edit_agent_config

Topic descriptions are UI-only entities but are now writable directly via MCP — do NOT
deliver paste-into-UI instructions as the default path.

1. **Discover the update schema**, if unfamiliar:
   ```
   edit_agent_config(entity_type="topic", operation="update")
   ```
   (call without `fields` to get the schema preview).

2. **Apply with fields** to get a Confirm/Cancel preview:
   ```
   edit_agent_config(
     entity_type="topic",
     operation="update",
     entity_id="<topic_id>",
     fields={"description": "<proposed description from Step 6>"}
   )
   ```

3. **Present the preview to the user** (use AskUserQuestion) — this entity type applies
   immediately on confirm, there is no TESTING changeset for topics.

4. **Only after explicit user confirmation**, re-call with `confirmed=true`. Never confirm on
   the user's behalf.

**Fallback:** if MCP write access is unavailable, deliver the Step 6 block formatted for
manual paste into Settings > Topics in the Ada UI instead.

## Step 7: Update Weekly Review Notes

Append to `~/repos/ada-tablo-ops/reference/weekly_review_notes.md`:

1. **Progress Summary table** — Add new row:
   ```
   | Week [N] | [Date] | [X]% | [+/-Y]% | [Key actions] |
   ```

2. **Current State section** — Update with new metrics

3. **Active Issues table** — Update statuses, add new issues

4. **Implementation Log** — Document any changes made in Ada UI

5. **Week [N] Details section** — Add detailed analysis if significant changes

## Step 8: Offer Next Steps

1. **If recommendations ready:**
   - Offer to apply via `edit_agent_config` (Step 6b) with explicit confirmation
   - Remind: Changes take effect immediately for future conversations

2. **If deep-dive needed:**
   - Offer conversation analysis options
   - Recommend specific patterns to investigate

3. **If all stable:**
   - Confirm verification items for next week
   - Note any deferred items

## Step 9: Commit Results

Invoke the commit-results skill to save output and reference updates:

```
skill: "commit-results", args: "topics"
```

## Token Efficiency Notes

- Topics report CSV analysis: Free (local script)
- Weekly review notes read: ~300 tokens
- Conversation summaries via MCP: ~100-200 tokens each
- Full transcripts via MCP: ~11,000 tokens each — avoid unless necessary

Budget guidance: Use script analysis first, summaries for patterns, full transcripts only for edge cases (max 3-5).

## DO / DON'T

**DO:**
- Export fresh topics report weekly from Ada UI
- Run analyze_topics_report.py first (free analysis)
- Follow the exact recommendation format above
- Use customer phrases from catch-all samples
- Apply approved topic edits via `edit_agent_config`, with explicit user confirmation
- Update weekly_review_notes.md with findings

**DON'T:**
- Propose topic changes without reading current descriptions
- Skip the structured format (Category/Topic/Current/Proposed/Rationale)
- Use generic descriptions without specific patterns
- Call `edit_agent_config` with `confirmed=true` without the user's explicit sign-off
- Forget to track changes in Implementation Log
- Expect immediate results — allow 7 days for routing changes to take effect
