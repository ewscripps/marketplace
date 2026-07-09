---
name: weekly-playbook-analysis
description: Run weekly playbook analysis for Ada-Tablo. Pulls per-playbook metrics and failure patterns via Ada MCP, compares to baselines, deploys edits via propose_change.
user-invocable: true
allowed-tools: Bash(python3 ~/repos/ada-tablo-ops/scripts/analyze_playbook_failures.py *), Bash(mkdir *), Bash(cp *), Bash(ls *), Read, Grep, Glob, AskUserQuestion, Skill
---

# Weekly Playbook Analysis

Automates the weekly Ada-Tablo playbook effectiveness review workflow.

## Step -1: Pre-Flight

Invoke the preflight skill to ensure the workspace is ready:

```
skill: "preflight"
```

After preflight completes, all subsequent steps operate in `~/repos/ada-tablo-ops`.

## Step 0: Determine Date Range

**Before pulling any data, check when the last analysis was run.**

1. Read the workflow doc's Historical Context section:
   ```
   ~/repos/ada-tablo-ops/reference/playbook_baselines.md
   ```

2. Find the most recent entry (format: `**[Month] [Year]:**` or `**[Month] [Day], [Year]:**`)

3. Calculate the recommended date range:
   - If last analysis was within 7 days: "You're up to date. Run again next week."
   - If last analysis was 7-14 days ago: "Run weekly analysis for [last 7 days]"
   - If last analysis was 2-4 weeks ago: "Gap detected. Run for [specific date range] to catch up."
   - If last analysis was 1+ month ago: "Run monthly analysis for [last month]"

4. Tell the user:
   ```
   Last analysis: [date from Historical Context]
   Days since: [N days]
   Recommended: Analyze [date range] (e.g., "Mar 10-16" or "Last month")
   ```

5. If multiple weeks are missing, ask user preference:
   - Run single analysis for full gap period, OR
   - Run week-by-week to track trends

## Step 1: Select Playbooks

Pull the live playbook list — do NOT rely on a hardcoded table (the instance now has 6 active playbooks, and new ones go live without skill updates):

```
get_ada_configuration()
```

Present the **active** playbooks from the response and ask the user which to analyze this run.

**Default suggestion:** Connectivity + First Time Setup (chat)

**Note:** First Time Setup has chat and voice variants — the weekly standard is the chat variant. Choose the voice variant only if analyzing the voice channel specifically.

Record each selected playbook's **ID** from the configuration response — the `PLAYBOOKID` filters in Steps 2-3 take IDs, not names.

Proceed with the selected playbooks for all remaining steps.

## Step 2: Pull Headline Metrics via MCP

MCP is the default data path — both `get_ada_metric` and `get_conversations` support the `PLAYBOOKID` filter (verified 2026-07-08). No UI export is needed for the standard weekly run.

**For each selected playbook:**

1. **Resolution rate:**
   ```
   get_ada_metric(
     metric_type="resolution_rate",
     start_date="[from Step 0]", end_date="[from Step 0]",
     filters=[{"type": "PLAYBOOKID", "operator": "IS", "value": ["<playbook_id>"]}]
   )
   ```

2. **Escalation %** — two volume calls, then divide:
   - Playbook volume: `get_ada_metric(metric_type="conversation_volume_engaged", start_date="[from Step 0]", end_date="[from Step 0]", filters=[{"type": "PLAYBOOKID", "operator": "IS", "value": ["<playbook_id>"]}])`
   - Escalated volume: same call (same dates) with `{"type": "HANDOFF", "operator": "IS", "value": true}` added to the filters
   - Escalation % = escalated volume ÷ playbook volume

## Step 3: Pull Failure Patterns via MCP

For each selected playbook, pull Not Resolved conversation summaries:

```
get_conversations(
  detail_level="SUMMARY",
  start_date="[from Step 0]", end_date="[from Step 0]",
  filters=[
    {"type": "PLAYBOOKID", "operator": "IS", "value": ["<playbook_id>"]},
    {"type": "ARSTATUS", "operator": "IS", "value": ["Not Resolved"]}
  ]
)
```

- Target ~50-100 conversations per playbook (~5-20k tokens at ~100-200 tokens each)
- Categorize failure patterns from the Classification, Reason, and Inquiry Summary fields
- Report each pattern as N conversations and % of Not Resolved

## Step 4: Load Workflow Reference

Read the workflow document for baselines and guidance:

```
~/repos/ada-tablo-ops/reference/playbook_baselines.md
```

Extract and note:
- **Baselines** (Feb 4, 2025): Resolution Rate, Abandonment %, Escalation %, App Not Found %, Issue Not Resolved %
- **Changes being tracked** with their metrics
- **Red flag thresholds**: Abandonment increasing, new pattern >5%, resolution dropping, pattern persisting 3+ weeks

## Step 5: Fallback — CSV Export + Analysis Script

Use this path only if MCP is unavailable, the sample is too large for summaries, or a baseline reconciliation run is needed.

**Baseline caveat:** The Feb 4 baselines were computed by `analyze_playbook_failures.py` from CSV rows. MCP-derived numbers may not be definitionally identical (e.g., abandonment is not a native MCP filter). A parallel run of both paths on the same week is pending to reconcile baselines — keep this CSV path documented until that reconciliation is done.

**Export from Ada UI** for each selected playbook:

**Ada Dashboard:** https://nuvyyo-gr.ada.support/insights/reports/automated_resolution

1. Go to Automated Resolution report (URL above)
2. Click "Add filter" → Select the playbook name
3. Set date range to **[date range from Step 0]**
4. Click Download → Downloads as `conversations_YYYY-MM-DD.csv`

**Files needed:** Only the `conversations_*.csv` files. The `ar_timeseries.csv` (daily metrics) is NOT needed — the script calculates metrics from conversation data.

**Move files to workspace** (run each command separately):

```bash
mkdir -p ~/repos/ada-tablo-ops/output/YYYY-MM
```

```bash
cp ~/Downloads/[downloaded_file].csv ~/repos/ada-tablo-ops/output/YYYY-MM/[playbook]_YYYY-MM-DD.csv
```

Example names: `connectivity_2026-04-08.csv`, `setup_2026-04-08.csv`, `voice_setup_2026-04-08.csv`

**Run the analysis script:**

```bash
python3 ~/repos/ada-tablo-ops/scripts/analyze_playbook_failures.py ~/repos/ada-tablo-ops/output/YYYY-MM/connectivity_YYYY-MM-DD.csv ~/repos/ada-tablo-ops/output/YYYY-MM/setup_YYYY-MM-DD.csv
```

The script accepts any number of CSV paths and outputs pattern distribution tables and top recommendations.

## Step 6: Present Results with Baseline Comparison

Format output as comparison table for each analyzed playbook:

| Metric | Baseline (Feb 4) | This Week | Change |
|--------|------------------|-----------|--------|
| **Connectivity** |
| Resolution Rate | 13.6% | [X]% | [+/-Y]% |
| Abandonment (% of NR) | 31.4% | [X]% | [+/-Y]% |
| Escalated to Human | 27.9% | [X]% | [+/-Y]% |
| Issue Not Resolved | 37.9% | [X]% | [+/-Y]% |
| **Setup** |
| Resolution Rate | 9.5% | [X]% | [+/-Y]% |
| Abandonment (% of NR) | 36.8% | [X]% | [+/-Y]% |
| Escalated to Human | 25.8% | [X]% | [+/-Y]% |
| App Not Found | 6.0% | [X]% | [+/-Y]% |
| Issue Not Resolved | 51.1% | [X]% | [+/-Y]% |

For non-standard playbooks, present the metrics without baseline comparison and note this is a first run.

**Note:** Baselines are CSV-derived. When using the MCP path (Steps 2-3), treat derived-metric comparisons (Abandonment, App Not Found) as approximate until the parallel-run reconciliation is complete; resolution rate and escalation % compare directly.

Flag any metrics that crossed red flag thresholds.

## Step 7: Check Deployed Changes

Review the "Changes Deployed" table in the workflow doc. For each tracked change:
- Is the target metric improving?
- If yes after 2 weeks: Consider removing from tracking
- If no after 2 weeks: Investigate why, suggest revision

## Step 8: Generate Recommendations

Format each recommendation using the established format:

```
**Pattern:** [What you observed]
**Count:** [N conversations, X% of Not Resolved]
**Edit:** [Specific playbook change — exact text]
**Measurement:** [How to verify improvement]
```

Limit to top 3 recommendations unless more are critical.

## Step 9: Deploy Approved Edits via propose_change

Playbook edits are applied directly via MCP (`propose_change` supports the `playbook` entity — verified 2026-07-08). Do NOT deliver paste-into-UI edit instructions.

For each approved recommendation:

1. **Pull the live playbook body first:**
   ```
   list_entities(entity_type="playbooks", entity_id="<playbook_id>")
   ```
   Never propose edits from notes/ or workspace/ copies — they drift from the live instance.

2. **Discover the update schema** — call without fields:
   ```
   propose_change(entity_type="playbook", operation="update")
   ```

3. **Propose with fields** to stage the change and get a preview.

4. **Present the preview to the user** with Confirm/Cancel options (use AskUserQuestion).

5. **Only after explicit user confirmation**, re-call with `confirmed=true`. Never confirm on the user's behalf.

**First-edit safety:** until write fidelity is validated, use `strategy="duplicate"` with `set_active=false` — this creates an inactive copy carrying the edit so the round-trip can be inspected in the Ada UI before trusting `strategy="existing"` on the live playbook.

After deploying, update the Changes Deployed tracking table.

## Step 10: Offer Next Steps

1. **If deep-dive needed on specific patterns:**
   - Warn: "Full transcript analysis via MCP costs ~11k tokens per conversation"
   - Recommend: "Pull 2-3 representative conversations for [pattern]"
   - Provide conversation IDs from the summaries or script output

2. **If baselines shifted significantly (>5%):**
   - Offer to update baselines in workflow doc
   - Note what caused the shift

3. **Log results:**
   - Append summary to Historical Context section of workflow doc
   - Format: `**[Month Year]:** [Key findings, metrics changes, actions taken]`

## Step 11: Commit Results

Invoke the commit-results skill to save output and reference updates:

```
skill: "commit-results", args: "playbook"
```

## Token Efficiency Notes

- Metric calls via MCP: ~200 tokens each
- Workflow doc read: ~300 tokens
- Summaries via MCP: ~100-200 tokens/conversation
- Full transcripts via MCP: ~11,000 tokens/conversation — use sparingly
- CSV pattern analysis (fallback path): Free (local script)

Budget guidance: Allow 50-100 conversations via summaries, limit full transcripts to 5-10 per session.

## DO / DON'T

**DO:**
- Pull the live playbook list via `get_ada_configuration` each run
- Use `PLAYBOOKID` filters on `get_ada_metric` / `get_conversations` as the default data path
- Compare metrics week-over-week
- Pull full transcripts only for edge cases (max 3-5)
- Pull the live playbook body via `list_entities` before proposing any edit
- Get explicit user confirmation before calling `propose_change` with `confirmed=true`

**DON'T:**
- Call `propose_change` with `confirmed=true` without the user's explicit sign-off
- Use `strategy="existing"` for playbook edits until duplicate-mode write fidelity is validated
- Retire the CSV fallback path before baselines are reconciled with a parallel run
- Analyze more than 100-150 conversations at once (diminishing returns)
- Pull full transcripts for pattern discovery (use summaries or CSV reasons)
- Expect immediate results — allow 7 days for changes to take effect
