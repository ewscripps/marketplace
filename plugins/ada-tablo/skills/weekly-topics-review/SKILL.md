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

**There is no catch-all topic.** The V2 Topics & Intents cutover retired the legacy
taxonomy; the live taxonomy is 16 topics, all `6a2702*`. A conversation Ada could not
classify has an **empty `classifications` array**, not a membership in an "Other" topic.

> Do NOT reintroduce a hardcoded catch-all topic ID here. This step previously
> filtered on `67f95e779a99fb6bdfe534a8` and `67fec3bbac473f6c4a232f93`, both retired.
> `get_ada_metric` returns `"0"` for a non-existent topic ID with **no error**, so the
> catch-all trend line read a flat zero and nobody noticed. Any replacement must be
> derived from the live taxonomy, never pasted from a previous run.

Catch-all is measured from the conversation export, not from a TOPIC filter:

1. Run `analyze_catchall_conversations.py` against the window's export. It counts
   engaged conversations whose `classifications` array is empty.
2. **Catch-all % = empty-classification engaged ÷ total engaged.**
3. Baseline for sanity: 28/2,925 engaged = 1.0% on the week of 2026-09-07.

To confirm the taxonomy is live before trusting any topic number, list it rather than
assuming it:

```
list_entities(entity_type="topics", detail="full")
```

This is a spot check only — the Friday review still uses the topics report CSV for the full per-topic breakdown.

## Step 4: Check Active Issues

Review Active Issues table from weekly_review_notes.md. For each tracked item:
- Is it due for verification this week?
- Did the metric improve as expected?
- Should it be marked Done or need continued tracking?

## Step 5: Deep-Dive on Catch-All (If Needed)

If catch-all increased OR user wants pattern analysis:

1. **Option A: Run the catch-all analysis script (default)**
   - Selects on an empty `classifications` array and reports the inquiry summaries
     behind it, with keyword patterns
   - There is no TOPIC filter that isolates catch-all (see Step 3b) — an unclassified
     conversation has no topic to filter on, which is what makes it unclassified
   - Requires a conversation export (not the topics report)
   ```bash
   python3 ~/repos/ada-tablo-ops/scripts/analyze_catchall_conversations.py [conversations.csv]
   ```

2. **Option B: Sample specific conversations via MCP**
   - Use sparingly: budget ~37k tokens per conversation, not the ~11k quoted
     historically — a single measured payload was 147 KB, of which 95% was
     `knowledge_referenced[].articles[].content` (full article bodies)
   - Get 2-3 representative conversations for pattern identification

Catch-all pattern analysis is large-N tallying, so Option A (the script) is the right
default — Haiku subagents on SUMMARY data are fine, and the counts should be sanity-checked against
`get_ada_metric` volumes. The moment the question turns causal ("why did these escalate", "what is
failing"), switch to Option B with a stronger model than Haiku and full transcripts: SUMMARY carries
no action-level outcomes, so a root-cause claim built on it is close to a guess. And spot-check 3-4
cited conversations at full detail before repeating any confident causal claim a subagent makes.

## Step 6: Generate Recommendations

For any topic improvements identified, use this EXACT format:

```markdown
**Category name:** [verbatim from CSV]
**Topic name:** [verbatim from CSV]
**Topic ID:** [from list_entities(entity_type="topics") — needed for Step 6b]
**Current scope:** [copy from list_entities(entity_type="topics", detail="full")]
**Proposed scope:** [what this topic covers — the types of conversations it should match]
**Proposed signals:** [keywords/phrases indicating a conversation belongs here]
**Proposed excludes:** [keywords/phrases indicating it does NOT — including
"use Category > Topic instead" redirects]
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

**A topic has no `description` field.** Verified against the live write schema on
2026-09-15. The writable fields are exactly `name`, `scope`, `signals`, `excludes` and
`intents` (the last is create-only — manage intents afterwards with
`entity_type="intent"`). What the UI and the CSV label "Topic description" is **`scope`**,
documented as "A description of what this topic covers — the types of conversations it
should match." Everything Step 6 calls a description writes to `scope`.

1. **Discover the update schema**, if unfamiliar:
   ```
   edit_agent_config(entity_type="topic", operation="update", entity_id="<topic_id>")
   ```
   (call without `fields` to get the schema preview).

2. **Apply with fields** to get a Confirm/Cancel preview:
   ```
   edit_agent_config(
     entity_type="topic",
     operation="update",
     entity_id="<topic_id>",
     fields={"scope": "<proposed description from Step 6>"}
   )
   ```
   Put match keywords in `signals` and explicit exclusions in `excludes` rather than
   folding them into `scope` prose — they are separate fields for a reason, and the
   "Do not apply if ..." half of a Step 6 recommendation belongs in `excludes`.

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
