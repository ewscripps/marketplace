---
name: weekly-playbook-analysis
description: Run weekly playbook analysis for Ada-Tablo. Guides CSV export, runs analysis script, compares to baselines.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion, Skill
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

**Before telling user to export, check when the last analysis was run.**

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
   Recommended: Export [date range] (e.g., "Mar 10-16" or "Last month")
   ```

5. If multiple weeks are missing, ask user preference:
   - Run single analysis for full gap period, OR
   - Run week-by-week to track trends

## Step 1: Select Playbooks

Present the known active playbooks and ask the user which to analyze:

**Available playbooks:**

| Playbook | Notes |
|----------|-------|
| Connectivity | Primary playbook — high volume, weekly standard |
| First Time Setup | Chat variant — weekly standard |
| Voice First-Time Setup | Voice variant — separate from the chat First Time Setup. Choose this only if analyzing voice channel specifically. |

**Default suggestion:** Connectivity + First Time Setup (chat)

Ask the user: "Which playbooks do you want to analyze this run? You can also enter a custom playbook name if a new one has gone live."

Proceed with the selected playbooks for all remaining steps.

## Step 2: CSV Export Guidance

Tell the user to export conversation CSVs from Ada for **each selected playbook**:

**Ada Dashboard:** https://nuvyyo-gr.ada.support/insights/reports/automated_resolution

**Note:** API/MCP cannot filter by playbook — manual UI export is required.

**For each selected playbook:**
1. Go to Automated Resolution report (URL above)
2. Click "Add filter" → Select the playbook name
3. Set date range to **[date range from Step 0]**
4. Click Download → Downloads as `conversations_YYYY-MM-DD.csv`
5. Note the file name — it will need to be renamed in Step 3

**Files needed:** Only the `conversations_*.csv` files. The `ar_timeseries.csv` (daily metrics) is NOT needed — the script calculates metrics from conversation data.

Ask the user for the full paths to the CSV files once downloaded. Confirm files exist before proceeding.

## Step 3: Move Files to Workspace

Create the output directory and copy exports with clear names. Run each command separately:

```bash
mkdir -p ~/repos/ada-tablo-ops/output/YYYY-MM
```

For each playbook CSV:

```bash
cp ~/Downloads/[downloaded_file].csv ~/repos/ada-tablo-ops/output/YYYY-MM/[playbook]_YYYY-MM-DD.csv
```

Example names: `connectivity_2026-04-08.csv`, `setup_2026-04-08.csv`, `voice_setup_2026-04-08.csv`

## Step 4: Load Workflow Reference

Read the workflow document for baselines and guidance:

```
~/repos/ada-tablo-ops/reference/playbook_baselines.md
```

Extract and note:
- **Baselines** (Feb 4, 2025): Resolution Rate, Abandonment %, Escalation %, App Not Found %, Issue Not Resolved %
- **Changes being tracked** with their metrics
- **Red flag thresholds**: Abandonment increasing, new pattern >5%, resolution dropping, pattern persisting 3+ weeks

## Step 5: Run Analysis Script

Execute the pattern analysis script with the CSV paths:

```bash
python3 ~/repos/ada-tablo-ops/scripts/analyze_playbook_failures.py ~/repos/ada-tablo-ops/output/YYYY-MM/connectivity_YYYY-MM-DD.csv ~/repos/ada-tablo-ops/output/YYYY-MM/setup_YYYY-MM-DD.csv
```

If no paths provided, prompt user again. The script outputs:
- Pattern distribution tables for both playbooks
- SID fix impact analysis (if applicable date range)
- Top recommendations with specific playbook edits

**Note:** If the user selected different or additional playbooks, adjust the script arguments accordingly. The script accepts any number of CSV paths.

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

## Step 9: Offer Next Steps

1. **If deep-dive needed on specific patterns:**
   - Warn: "Full transcript analysis via MCP costs ~11k tokens per conversation"
   - Recommend: "Pull 2-3 representative conversations for [pattern]"
   - Provide conversation IDs from script output

2. **If changes ready to deploy:**
   - Offer to format playbook edit instructions
   - Offer to update the Changes Deployed tracking table

3. **If baselines shifted significantly (>5%):**
   - Offer to update baselines in workflow doc
   - Note what caused the shift

4. **Log results:**
   - Append summary to Historical Context section of workflow doc
   - Format: `**[Month Year]:** [Key findings, metrics changes, actions taken]`

## Step 10: Commit Results

Invoke the commit-results skill to save output and reference updates:

```
skill: "commit-results", args: "playbook"
```

## Token Efficiency Notes

- CSV pattern analysis: Free (local script)
- Workflow doc read: ~300 tokens
- Summaries via MCP: ~100-200 tokens/conversation
- Full transcripts via MCP: ~11,000 tokens/conversation — use sparingly

Budget guidance: Allow 50-100 conversations via summaries, limit full transcripts to 5-10 per session.

## DO / DON'T

**DO:**
- Export fresh data weekly from Ada UI
- Run analyze_playbook_failures.py first (free pattern categorization)
- Compare metrics week-over-week
- Pull full transcripts only for edge cases (max 3-5)

**DON'T:**
- Use Ada MCP for ARR/effectiveness analysis (it can't filter by playbook)
- Analyze more than 100-150 conversations at once (diminishing returns)
- Pull full transcripts for pattern discovery (use summaries or CSV reasons)
- Expect immediate results — allow 7 days for changes to take effect
