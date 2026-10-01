---
name: weekly-playbook-analysis
description: The deploy path for Ada-Tablo behavior changes (Step 9). Stages an edit on a changeset through edit_agent_behavior, or takes one a stage script staged, checks the staged diff, gates it with config-health on the staged body and evidence-loop's 3-rep test gate, writes the deploy note, then promotes or starts a rollout on the user's yes. Other skills hand off here to deploy. Steps 0 to 8 are the older per-playbook weekly metrics review; the Friday whole-population review is evidence-loop.
user-invocable: true
allowed-tools: Bash(python3 ~/repos/ada-tablo-ops/scripts/analyze_playbook_failures.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/changeset_inspect.py note *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/ledger.py *), Bash(mkdir *), Bash(cp *), Bash(ls *), Read, Grep, Glob, AskUserQuestion, Skill
---

# Weekly Playbook Analysis

Automates the weekly Ada-Tablo playbook effectiveness review workflow.

## Step -1: Pre-Flight

Invoke the preflight skill to ensure the workspace is ready:

```
skill: "preflight"
```

After preflight completes, all subsequent steps operate in `~/repos/ada-tablo-ops`.

If this is the first `edit_agent_behavior` or `edit_agent_config` call of the session, call
`get_improvement_guide()` once before proposing or applying any edit — its output stays in
context for the rest of the session, so do not re-call it. Call `get_available_filters()`
once before the first `get_ada_metric`/`get_conversations` call if filter names are unfamiliar.

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

Pull the live playbook list — do NOT rely on a hardcoded table (playbook count and IDs change
across cutovers; new ones go live without skill updates):

```
get_ada_configuration()
```

`get_ada_configuration()` is adequate here because this step only needs active playbook names
and IDs for the selection menu, not the full structural surface — that's what `config-health`
uses `list_entities` for instead (it also needs disabled entities, which
`get_ada_configuration()` omits).

Present the **active** playbooks from the response and ask the user which to analyze this run.

**Default suggestion:** Connectivity + First Time Setup (chat)

**Note:** First Time Setup has chat and voice variants — the weekly standard is the chat variant. Choose the voice variant only if analyzing the voice channel specifically.

Record each selected playbook's **ID** from the configuration response — the `PLAYBOOKID` filters in Steps 2-3 take IDs, not names. Playbook names may carry a version prefix (e.g. `V2 …`) that changes across a cutover — always use the live ID, never a name string, as the join key.

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

2. **Escalation %** — prefer the native metric, scoped by playbook:
   ```
   get_ada_metric(
     metric_type="containment_rate",
     start_date="[from Step 0]", end_date="[from Step 0]",
     filters=[{"type": "PLAYBOOKID", "operator": "IS", "value": ["<playbook_id>"]}]
   )
   ```
   Escalation % = 100% − containment_rate.

   Fall back to the two-call derivation only if `containment_rate` rejects the `PLAYBOOKID`
   filter or its definition doesn't match what you need for a specific playbook:
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

## Step 3b: Classification Discipline

- **Classify outcomes by tool-call structure — which tools fired, in what order, with what
  `result.status` — not by keyword-matching bot text.** Bot phrasing changes with playbook
  edits and localization (this account is multilingual), so a text match silently miscounts.
- Where MCP summaries don't establish the tool sequence, pull `tool_call` messages for the
  window and group by conversation, ordered by call sequence:
  ```
  python3 ~/repos/ada-tablo-ops/scripts/export_messages.py --since <start> --until <end> --tool-calls-csv <path>
  ```
- Identify the playbook family by `used_playbooks` firing counts, not by name. Check
  co-occurrence before summing, so an entry flow and its sub-flows are not double counted.
- **`tool_call` messages mix internal reasoning with real outcomes** (verified 2026-08-20):
  `deep_thinking` and `(naive_)search_knowledge` are internal steps, not Actions or Handoffs —
  exclude them when counting Action/Handoff outcomes. Playbook starts also surface as
  `tool_call` rows named after the playbook.
- **State the denominator.** Classify the full population when volume allows (low thousands
  is fine). If sampling, say so and give the sample size and how it was drawn.

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

Use this path only if MCP is unavailable or the sample is too large for summaries.

**Baseline caveat:** Older baselines were computed by `analyze_playbook_failures.py` from CSV rows. MCP-derived numbers may not be definitionally identical (e.g., abandonment is not a native MCP filter) — treat cross-path comparisons as approximate.

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

Read the **Baselines** section of `playbook_baselines.md` for the current-generation numbers
per playbook ID — do NOT hardcode baseline values in this skill, they go stale across
cutovers (the Feb 4 2025 / pre-cutover numbers in older reference history are historical only
and not comparable to a post-cutover playbook — a version prefix change in the playbook name,
e.g. `V2 …`, is a strong signal the underlying baseline was reset). Format output as a
comparison table for each analyzed playbook:

| Metric | Baseline | This Week | Change |
|--------|----------|-----------|--------|
| Resolution Rate | [from ref] | [X]% | [+/-Y]% |
| Escalated to Human | [from ref] | [X]% | [+/-Y]% |
| Issue Not Resolved | [from ref] | [X]% | [+/-Y]% |
| Abandonment (% of NR) | [from ref] | [X]% | [+/-Y]% |

For playbooks with no baseline yet (first run after a cutover, or a brand-new playbook),
present the metrics without comparison, label it **"First run — establishing baseline,"** and
write this week's numbers into `playbook_baselines.md` as the new baseline row in Step 10.

**Note:** Older CSV-derived baselines and MCP-derived numbers may not be definitionally
identical (e.g., abandonment is not a native MCP filter) — treat derived-metric comparisons
across that boundary as approximate; resolution rate and escalation % compare directly.

Flag any metrics that crossed red flag thresholds.

Close the presented results with an explicit **Verified vs inferred** line: name which claims
were confirmed against live backend data via MCP (e.g. a metric pull, a `list_entities` read)
and which are pattern inference from summaries.

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

**Do not report a defect as fact from transcript text alone.** Verify any "bug" claim against
live backend data via MCP (`list_entities` for the playbook body, `get_ada_metric` /
`get_conversations` for behavior) before it enters a recommendation.

**Do not report a subagent's causal claim without spot-checking it.** When a subagent report says
"X broke", "the migration caused Y", or anything else causal and specific, pull **3-4 of its own
cited conversations** at full transcript detail and confirm the mechanism first. This is a standard
step, not an optional one — it caught two separate overclaims in the 2026-09-14/15 AR-decline
investigation, including a Haiku subagent reporting "the Aug 14 migration broke the Device Status
action backend" when the real mechanism was client-side serial validation rejecting a legacy device
ID format before Device Status was ever called.

## Step 9: Deploy Approved Edits via edit_agent_behavior

This step is the deploy path for the other skills: `playbook-authoring`, `deterministic-logic`,
`coaching-review` and `evidence-loop` step 6d hand off here. It can run on its own ("Step 9
only") on a change record or on a changeset that is already staged. Edits go live through
`edit_agent_behavior`'s changeset model (the old `propose_change` tool no longer exists on the
live server). Do NOT deliver paste-into-UI edit instructions.

**Which route stages the edit.**
- **Any field except a playbook's `sections`:** steps 1 to 3 below, through `edit_agent_behavior`.
- **A playbook's `sections`:** a whole-list field about 40KB wide, too large to go through a
  model tool call (F71), so steps 1 to 3 cannot stage it. A `scripts/stage_playbook.py` script in
  `~/repos/ada-tablo-ops/evidence-loop/` stages it instead, using the selected
  `payload_<EDIT>.py` builder: it builds the field from the live body, writes the payload under
  `~/.ada-evidence/tablo/sim/`, and stages it on a TESTING changeset behind a fresh confirm
  token. The script runs from a `work` session on David's yes in the moment, never under
  standing approval; this skill does not run it. Start at step 4 with the changeset id the
  script printed.

For each approved change record:

1. **Pull the live playbook body first:**
   ```
   list_entities(entity_type="playbooks", entity_id="<playbook_id>")
   ```
   Never propose edits from notes/ or workspace/ copies — they drift from the live instance.

2. **Discover the editable fields** — call without `changes`:
   ```
   edit_agent_behavior(operation="describe_entity", entity_type="playbook")
   ```
   Pass `change_type="modified"` (the update-time schema — every field optional) since this
   is always an edit to an existing playbook, never a new one.

3. **Stage the edit on a changeset:**
   ```
   edit_agent_behavior(
     operation="update",
     entity_type="playbook",
     changeset_id="<existing id, or omit to auto-create>",
     name="<short generic label if creating a new changeset, e.g. 'Weekly playbook fixes YYYY-MM-DD'>",
     changes=[{
       "entity_type": "playbook",
       "change_type": "modified",
       "entity_id": "<playbook_id>",
       "fields": { ... }
     }]
   )
   ```
   This lands the edit on a TESTING changeset — nothing is live yet. Multiple approved
   recommendations for the same run can share one changeset (repeat step 3 with the same
   `changeset_id`).

4. **Verify the staged diff:**
   ```
   list_agent_changesets(changeset_id="<id>", include_diff=true)
   ```
   Confirm `diff.changed` shows exactly the intended field(s) changed and nothing else. For a
   `sections` edit the response runs to hundreds of KB: let it spill to a file and compare it
   with the stage script's payload file by script; never read it into context.

5. **Gate: config-health on the staged body.** Run `/ada-tablo:config-health --changeset <id>`
   scoped to the playbook(s) being changed, so it reads the body that will ship. A check on the
   live body says nothing about the change. If it reports any P0 (orphan read, unbound action
   output, dangling reference, destructive warning in the same turn as its trigger), surface it
   and resolve it, as its own change or folded into this one, before going further. Do not test
   or promote on top of a known P0.

6. **Gate: test runs.** Before promoting or rolling out, run the test gate in Step 9b. Do not
   promote on a regression.

7. **Present the preview to the user** with Confirm/Cancel options (use AskUserQuestion) —
   include the verified diff, the config-health verdict, the test-gate result, and the draft
   deploy note (why, source, expected effect; see `changeset-inspect` Deploy notes). Say which
   of the two ways in step 8 is being asked for.

8. **Only after explicit user confirmation**, write the deploy note, then promote or roll out.
   No note, no promote, and no note, no rollout.

   **Promote** (live for every conversation):
   ```
   edit_agent_behavior(operation="promote", changeset_id="<id>", confirmed=true)
   ```
   If the first (unconfirmed) preview call returned a `warnings_token`, echo that same token
   back on the `confirmed=true` call — otherwise the tool re-issues the preview. Never confirm
   on the user's behalf.

   **Roll out** (a sampled share of new conversations up to a hard cap; the changeset stays in
   TESTING):
   ```
   edit_agent_behavior(operation="set_rollout", changeset_id="<id>", percentage=<1-100>, max_conversations=<cap>)
   ```
   `set_rollout` has no preview and no confirm step: sampling starts on the call. So the
   AskUserQuestion in step 7 names the percentage and the cap, and the call is made only on
   that yes. Percentages across all active rollouts on the instance sum to at most 100, and a
   request over that is rejected. The rollout ends when `max_conversations` is reached; calling
   `set_rollout` again resets the applied count to 0. Read progress with
   `list_agent_changesets(changeset_id="<id>")` (`rollout.status`, `rollout.applied_count`,
   `rollout.started_at`). To end it early, ask the same way, then
   `edit_agent_behavior(operation="stop_rollout", changeset_id="<id>")`; conversations already
   sampled keep the change until they end. Promoting the changeset after a rollout is its
   own step 7 and 8.

If the user wants to walk back an edit before promoting, use
`edit_agent_behavior(operation="remove", changeset_id="<id>", entity_id="<entity_id>")`; to
discard the whole changeset before it's live, use `operation="delete"` (same confirm flow as
promote). A changeset already promoted can be walked back with `operation="revert"`.

### Step 9b: Test Gate

Run this before every promote or rollout — do not promote on the strength of the preview diff
alone. One test run is not evidence: the bench is non-deterministic, so every case runs 3 times.

**The gate is `evidence-loop` step 6.** Invoke `Skill: evidence-loop` in targeted mode for the
changed playbook and run its step 6 on this changeset: real failures converted to cases, the
failures-first batch, 3 reps, `--changeset-only` for cases already measured on live, the voice
ceiling, and its GO / NO-GO bar. Bring its gate verdict and batch id back to step 7.

**Only when `evidence-loop` is not installed**, run the same gate by hand:

1. `get_test_run_quota()` — confirm headroom for the day before creating runs.
2. Identify the test cases relevant to the changed playbook(s) via `get_test_cases()`.
3. Create test runs pinned to the changeset so they exercise the staged (not yet live)
   config, 3 runs per case:
   ```
   edit_agent_config(
     entity_type="test_run",
     operation="create",
     fields={"test_case_ids": ["<id>", ...], "changeset_id": "<id>"}
   )
   ```
   (Call without `fields` first if the exact field names need confirming — this tool
   discovers schemas the same way as `edit_agent_behavior`.)
4. Poll `get_test_runs(test_run_id="<id>")` until `status` is `completed` (or `failed`/
   `timeout`/`cancelled` — treat any of those as a blocked promote, investigate before
   retrying).
5. **Read the criteria results and, for anything unexpected, the transcript — not just the
   pass/fail verdict.** The grader has produced misleading verdicts on this suite before
   (e.g. penalizing a correct handoff offer as a false failure). A `did_pass: false` on a
   criterion unrelated to the change under test is not necessarily a regression; a
   `did_pass: true` is not proof the change works if the criteria don't actually probe it.
6. Block promotion on any real regression relative to the pre-edit baseline for that test
   case. Surface the pass/fail delta (not just raw counts) to the user in the step 7 preview.

**Standing caveat:** Ada Simulations always execute Actions live against production —
only Handoffs are mocked. There is no toggle to mock action calls; a field like
`use_real_web_actions` on a test case is inert. Treat every test run as touching real
downstream systems.

**Record it.** After a promote, the record is the deploy note and a ledger row, written only
through `ledger.py register` or `ledger.py link`, with the prediction from the gate file (see the `work` skill, close step 1, for the exact commands; ask the user for a prediction when the gate has none, never write one yourself). A
rollout has its deploy note and no ledger row until it is promoted. The Changes Deployed table
in `playbook_baselines.md` is read only by Step 7; add a row there too only when Steps 0 to 8
ran this session.

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

Match the read depth to the task shape:

- **Large-N tallying** ("how many of these mention X", "bucket these by playbook") — Haiku subagents
  on `detail_level="SUMMARY"` are fine; errors wash out in aggregate. Sanity-check the counts against
  `get_ada_metric` / filtered volumes.
- **Small-N causal attribution** ("why did these 15 escalate", "what is actually failing") — stronger
  model (Sonnet or a forked session) and `FULL` detail, or the raw per-conversation export fields.
  SUMMARY carries no `action_executed`/outcome entries, so it cannot separate "a validator rejected
  the input" from "the backend call failed" — a causal story built on it is close to a guess. Read
  fewer conversations at full detail rather than more at SUMMARY. Full-detail voice transcripts can
  run several thousand tokens each.

## DO / DON'T

**DO:**
- Pull the live playbook list via `get_ada_configuration` each run
- Use `PLAYBOOKID` filters on `get_ada_metric` / `get_conversations` as the default data path
- Compare metrics week-over-week
- Pull full transcripts only for edge cases (max 3-5)
- Pull full transcripts (not SUMMARY) whenever the deliverable is a causal claim, and use a stronger model than Haiku for that read
- Spot-check 3-4 cited conversations at full detail before repeating any confident causal claim from a subagent
- Pull the live playbook body via `list_entities` before proposing any edit
- Run `/ada-tablo:config-health --changeset <id>` on the staged body before the test gate
- Run the Step 9b test gate (evidence-loop step 6, 3 reps) on the changeset before promoting or rolling out
- Send a playbook `sections` edit through its `scripts/stage_playbook.py` script, never through `edit_agent_behavior` from this skill
- Read test-run transcripts for anything unexpected, not just the pass/fail verdict
- Get explicit user confirmation before calling `edit_agent_behavior` with `confirmed=true`
- Classify outcomes by tool-call structure (which tools fired, in what order, with what status)
- State the denominator — full population, or sample size and how it was drawn

**DON'T:**
- Call `edit_agent_behavior` promote/revert/delete with `confirmed=true`, or `set_rollout`/`stop_rollout` at all, without the user's explicit sign-off in the moment
- Test or promote a changeset while config-health has an open P0 on its staged body
- Promote or roll out a changeset without its test gate or its deploy note
- Build a root-cause claim on `SUMMARY`-level conversation data, or repeat a subagent's causal claim unverified
- Analyze more than 100-150 conversations at once (diminishing returns)
- Pull full transcripts for pattern discovery (use summaries or CSV reasons)
- Expect immediate results — allow 7 days for changes to take effect
- Classify outcomes by keyword-matching bot text
- Report a defect as fact from transcript text alone — confirm against live backend state first
