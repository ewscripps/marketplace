---
name: ada-health
description: Health check for an Ada AI Agent instance — surfaces recent config changes, action/API failures, handoff and repeat-contact movement, and automated resolution by channel over a short window. Read-only, everything via Ada MCP. Use when asked to check an Ada instance's health, whether anything recently broke or regressed, or to run a post-deployment or post-cutover check.
user-invocable: true
argument-hint: '[instance] [--days N] [--topics]'
allowed-tools: Read, Grep, Glob, AskUserQuestion, Skill, Bash(mkdir -p *), Bash(cat *), Bash(ls *), Bash(python3 *ada-health/scripts/estimate_ar.py *)
---

# Ada Instance Health Check

Read-only. This skill **never** stages, promotes, or reverts anything. If a finding needs a fix, name it and hand off to the skill that owns it.

Two tiers. Tier 1 is a fixed cheap sweep of aggregate metrics — no per-conversation reads, ever. Tier 2 is per-conversation and only runs when the user picks it from a prompt. Never run a tier-2 query because a finding looks interesting.

## Step -1: Pre-Flight

Invoke `skill: "preflight"` if the `ada-tablo` plugin is enabled. It is not required — this skill has no dependency on the `ada-tablo-ops` repo. If preflight is unavailable, continue without it and say so once.

## Step 0: Resolve instance, window, profile

**Instance.** From the first argument, or from an explicit instance name in the user's request. If neither, list the profiles in `profiles/` plus any Ada MCP servers visible in this session and ask via `AskUserQuestion`. Never guess — the wrong instance produces a confident report about the wrong AI agent.

Set `SERVER` to that instance's MCP tool prefix (`mcp__ada-tablo__`, `mcp__ada-scripps__`). Every call below uses it. If the server is not connected, stop and say so — do not fall back to REST, curl, or a Python script. This skill is MCP-only by design.

**Window.** `--days N`, default **3**.
- Current window: `start = today - N`, `end = today`
- Prior window: `start = today - 2N`, `end = today - N`

Every `get_ada_metric` and `get_conversations` call takes explicit `start_date` and `end_date` in `YYYY-MM-DD`.

**Profile.** Read `profiles/<instance>.md` if it exists. It may supply: dashboard base URL, a partition variable and its values, expected escalation reasons, a minimum-N floor, threshold overrides.

**A missing profile is not an error.** Without one, run every block below at account level with prior-window comparison, skip partition slicing, and use the default thresholds. Say once in the report that no profile was found, so the reader knows partition checks did not run.

Set `MIN_N` from the profile, default **20** engaged conversations.

## Step 1: Resolve IDs fresh — retired-ID guard

Before any ID-filtered call, resolve IDs in this run via `list_entities(entity_type=..., detail="minimal")`.

**Never read an entity ID from a profile, a baseline file, a note, or this skill's own text.** An `IS` filter on a retired ID returns **zero silently, not an error** — indistinguishable from "no traffic." The Tablo V1→V2 playbook cutover on 2026-08-14 retired every previously documented playbook ID, and every baseline predating it is not comparable.

If an ID named in a profile no longer resolves, report it as a **config finding** ("profile references retired ID X") and never as a zero measurement.

## Step 2: What changed

`list_agent_changesets(limit=15)`.

Flag:
- **RED** — any changeset with `status: "reverted"` where `revert_time` falls in the window. Someone shipped something and pulled it back.
- **AMBER** — `status: "promoted"` with `promotion_time` in the window. Note the name; correlate against the metric blocks below.
- **AMBER** — `status: "testing"` with `created_at` older than 14 days. Abandoned in-flight edit.

Do **not** call `include_diff=true` here. Diffs are a tier-2 drill-down.

**Print this caveat in the report every run, unconditionally:**

> Change detection covers changesets only — knowledge, playbooks, custom instructions, tools, coaching. Topic, intent, test-case and glossary edits go live without a changeset and are invisible here, as are edits made directly in the Ada dashboard. Ada's full Audit Log covers those but is not exposed over MCP. An empty change list means "no changesets," not "nothing changed."

## Step 3: Headline metrics

For each of `resolution_rate`, `containment_rate`, `csat_rate`, `conversation_volume_engaged`, `avg_handle_time` — call `get_ada_metric` once for the current window and once for the prior window. 10 calls.

Use `conversation_volume_engaged`, never `conversation_volume_opened`. `opened` runs ~40% higher and is not the number the Ada dashboard shows.

**AR coverage gate — run this before reporting any resolution_rate.**

`resolution_rate` is produced by an LLM that classifies each conversation after the fact, and that pipeline can fall days behind. Unclassified conversations are **excluded from the denominator**, so a backlog does not merely add noise — observed backlogs are heavily biased toward `Not Resolved`, which drags the reported rate toward zero while the real rate is unknown.

Three cheap calls per slice, ~45 tokens total:

1. `conversation_volume_engaged` for the slice
2. same, plus `ARSTATUS IS "Resolved"`
3. same, plus `ARSTATUS IS "Not Resolved"`

`coverage = (resolved + not_resolved) / engaged`.

| Coverage | Action |
|---|---|
| >= 95% | Report AR normally |
| 80-95% | Report AR with the coverage figure beside it |
| < 80% | **Do not report an AR number or an AR delta.** State that classification is only N% complete for the window and that AR is unavailable, not low. |

Never extrapolate the missing portion yourself — the classified subset is not a random sample, so the completed fraction cannot stand in for the whole.

**Coverage trend.** Record coverage per slice in the state file (Step 10). When a previous run exists, report the direction rather than a bare number: `AR 14.3% at 47% coverage, up from 41% coverage / 6.7% twelve hours ago`. Two readings are enough to tell the two cases apart, and it costs nothing beyond the 3 calls already made:

- **Coverage rising and AR rising with it** — a clearing backlog. Say the metric is still filling in and name the level earlier, more-complete days settled at.
- **Coverage rising while AR stays flat and low** — the backlog is clearing and the decline is real. Escalate it.

A day that has reached >=95% coverage is settled. Use those days, not the recent incomplete ones, to judge whether anything actually changed.

**`containment_rate` is derived mechanically from whether a handoff occurred and is unaffected by this backlog.** It is the correct continuity metric whenever the coverage gate trips. Check coverage per channel, not just account-wide: a backlog can hit one channel while others sit at 100%.

**If current-window `conversation_volume_engaged` < `MIN_N`, the run is INCONCLUSIVE.** Report every raw number, state that the window holds too little traffic to read deltas as signal, and skip the flag bands entirely for percentage metrics. Do not report a quiet window as a clean pass — at low volume, zero conversations is the expected result, not evidence of health.

## Step 4: Automated resolution by channel

Candidate channel values: `email`, `voice`, `chat`, `web`, `mobile`, `mobile_sdk`, `api`.

1. `conversation_volume_engaged` per candidate, current window (7 calls). Drop any returning 0 — that value is not in use on this instance.
2. For surviving channels with volume >= `MIN_N`: `resolution_rate` current + prior, and `conversation_volume_engaged` prior (3 calls each).
3. **Run the Step 3 coverage gate per channel.** A backlog is routinely channel-specific — one channel at 27% while another sits at 100%. A channel below 80% coverage shows its containment rate and its coverage figure instead of an AR delta.

Report a table of channel, volume, AR now, AR prior, delta. Channels below `MIN_N` appear in the table with their volume and an explicit "insufficient volume" marker instead of a delta.

## Step 5: Action and API failures

Nothing else in the Ada toolkit covers this block. It is the direct replacement for the manual "check for API failures" step.

1. `conversation_volume_engaged` filtered `STATUSCODE IS <code>` for the current window, for each of: `400, 401, 403, 404, 408, 409, 429, 500, 502, 503, 504`. 11 calls, ~15 tokens each.
2. Only for codes returning > 0, repeat on the prior window. Typically fewer than 5 calls.

Flag:
- **RED** — any 5xx count > 0. A server-side action failure is never normal.
- **RED** — total 4xx > 10% of current-window engaged volume.
- **AMBER** — any 4xx code at least double its prior-window count, with a current count of 3 or more.

A count here is *conversations touched*, not requests. Say so in the report.

## Step 6: Handoff rate

`conversation_volume_engaged` filtered `HANDOFF IS true`, current and prior. Rate = that over engaged volume for the same window.

- **RED** — rate up more than 15 points.
- **AMBER** — rate up 5 to 15 points.

**MCP exposes handoff count, not handoff success.** A handoff that fired but failed to create a ticket looks identical here to one that worked. Where a handoff is webhook-backed, its failure surfaces in Step 5 as a 4xx/5xx on that tool — say this in the report rather than implying handoffs were verified end to end.

## Step 7: Repeat contacts

`conversation_volume_engaged` filtered `REPEATCONTACT IS true`, current and prior. Rate over engaged volume.

Rising repeat contact is the cheapest proxy for "the agent started answering worse" — the customer came back within 30 minutes on the same topic.

- **AMBER** — rate up more than 5 points.

## Step 8: Report

Order strictly by severity: RED, then AMBER, then GREEN, then the flat metric tables. A reader who stops after the first screen must have seen everything broken.

Every flag carries its **denominator**. `AR fell 12 points` is not a finding; `AR fell 12 points on email (n=84)` is. Any flag whose denominator is below `MIN_N` is demoted to "insufficient volume" and reported as an observation, never as a flag.

**Numerator guard.** A denominator floor alone is not enough — at n=25, a 50-point AR swing is two conversations changing hands. Before flagging any *rate* delta, convert both sides back to conversation counts (`rate x volume / 100`). If the two counts differ by fewer than **5 conversations**, demote it to an observation and say the delta rests on fewer than 5 conversations. This applies to AR, CSAT, containment, handoff rate, and repeat-contact rate alike. Absolute-count findings — a 5xx, a reverted changeset, a raw handoff count — are exempt; they are readable at any volume.

Flag bands, unless the profile overrides them:

| Band | Trigger |
|---|---|
| RED | any 5xx > 0 · a changeset reverted in window · AR down >10pts on a slice with n >= `MIN_N` · 4xx > 10% of engaged volume · handoff rate up >15pts |
| AMBER | AR down 5-10pts · CSAT down >5pts · repeat-contact rate up >5pts · handoff rate up 5-15pts · 4xx code doubled (n>=3) · changeset promoted in window · changeset in `testing` >14d |
| GREEN | AR up >5pts · handoff rate down >5pts · repeat-contact rate down >5pts |
| INCONCLUSIVE | engaged volume < `MIN_N` |

When a changeset was promoted in the window **and** a metric moved, say the two coincide and that the direction is unverified. Do not assert causation from a timestamp.

Close with the Step 2 caveat, plus a one-line note of what did not run (no profile, channels dropped, `--topics` not requested).

## Step 9: Drill-down — user picks, never automatic

Build an `AskUserQuestion` from **the flags that actually fired**, at most 4 options, **each labelled with its token cost**. Always include a "stop here" option.

| Offer when | Query | Cost |
|---|---|---|
| Step 5 flagged | `get_conversations(detail_level="IDS_ONLY", size=10, filters=[STATUSCODE, optionally ACTIONID])` -> present the list -> user picks at most 3 -> `get_conversation` each | ~2k + ~11k each |
| Step 4 or 3 flagged | `get_conversations(detail_level="SUMMARY", size=50, filters=[CHANNEL, ARSTATUS IS "Not Resolved"])`, read the classification reasons | ~8k |
| Step 2 flagged | `list_agent_changesets(changeset_id=<id>, include_diff=true)` per flagged changeset | ~2-4k each |
| `--topics`, or volume moved | per-topic `conversation_volume_engaged` fan-out over resolved topic IDs, then `get_conversations(SUMMARY, TOPIC, size=30)` on the top mover | ~1.5k + ~5k |
| Coverage gate tripped and a number is needed before Ada catches up | `scripts/estimate_ar.py` — see below | ~2k in context |
| A structural fault is suspected | invoke `/ada-tablo:config-health` | varies |

### Estimating AR under a backlog

Offer this **only** when the coverage gate has tripped and the user needs a figure before the backlog clears. Waiting is usually the better answer — say so — because a clearing backlog resolves the question on its own.

```
ADA_TOKEN=<instance token> ANTHROPIC_API_KEY=<key> \
  python3 <plugin>/scripts/estimate_ar.py \
    --url <instance>/api/mcp --start <date> --end <date> \
    --channel <channel> --sample 25
```

It set-differences `IDS_ONLY` against both `ARSTATUS` filters to isolate unclassified conversations, samples them, scores each with Haiku against an approximation of Ada's rubric, and returns a point estimate with a Wilson 95% interval. Transcripts are fetched and scored inside the script and never enter context — only the aggregate comes back, so a 25-conversation run costs ~2k tokens here instead of ~275k.

**Report the output as an estimate, always.** It approximates Ada's rubric rather than reproducing it, and Ada's own classifier is demonstrably inconsistent on near-identical conversations. Never write it into a baseline, never present it as AR, and never let it reach `/support-ratios` or `/monthly-deck`. Quote the interval, not just the point estimate — at n=25 the interval is wide, and that width is the honest part of the answer.

Run **one** drill-down, report it, then ask again. Never chain two without a fresh prompt. Cap full transcripts at 3 per drill-down and state the cost before reading them.

For a flagged playbook, topic, or coaching item, name it and hand off — `/ada-tablo:weekly-playbook-analysis`, `/ada-tablo:weekly-topics-review`, `/ada-tablo:coaching-review`. Do not re-analyze what those skills own.

## Step 10: Persist the run

Offer to append a one-line run record to `~/.ada-health/state/<instance>-last-run.md` (`mkdir -p` first): timestamp, window, engaged volume, **AR-status coverage (account-wide and per channel)**, AR, containment, CSAT, handoff rate, repeat rate, and the flags raised.

Coverage is the column that makes Step 3's trend work, so record it even when the gate did not trip. Keep every run rather than overwriting — the history is what distinguishes a clearing backlog from a real decline.

State lives outside the plugin directory so a marketplace update cannot clobber it. On the next run, read it and report movement against the last run alongside the prior-window comparison. Ask before writing.

## Token Efficiency Notes

Measured against a live Ada instance, 2026-09-04:

| Call | Cost |
|---|---|
| `get_ada_metric` scalar, any filter | **~15 tokens** |
| `list_entities(detail="minimal")` | 200-700 tokens |
| `list_agent_changesets(limit=15)` | ~700-1,200 tokens |
| `get_conversations(IDS_ONLY, size=10)` | ~185 tokens |
| `get_conversations(SUMMARY, size=50)` | ~8,000 tokens |
| `get_conversation` — one transcript | **~11,000 tokens** |
| `get_ada_metric(conversation_summaries)` — **one day** | **~41,000 tokens** |

Tier 1 as specified is roughly 50-55 calls and **under 8,000 tokens**, dominated by the changeset listing rather than the metrics. The whole design rests on aggregate metric calls being nearly free while per-conversation reads are not.

`conversation_summaries` is **banned**. One day of it costs more than five full transcripts and more than the entire tier-1 sweep. `get_conversations(detail_level="SUMMARY")` with filters answers the same questions for a fraction of it.

## DO

- **DO** resolve every entity ID fresh via `list_entities` in the same run.
- **DO** report the denominator beside every rate, and demote any flag below `MIN_N`.
- **DO** run the AR coverage gate before quoting any `resolution_rate`, per channel as well as account-wide.
- **DO** prefer waiting for a backlog to clear over estimating around it, and say so when offering the estimator.
- **DO** declare a low-volume window INCONCLUSIVE rather than passing it.
- **DO** print the change-detection caveat every run, including when no changesets are found.
- **DO** state the token cost of each drill-down before the user picks it.
- **DO** hand off to the skill that owns a finding.

## DON'T

- **DON'T** call `get_ada_metric(metric_type="conversation_summaries")`. Ever.
- **DON'T** run a tier-2 query without an explicit user choice, or chain two on one prompt.
- **DON'T** use `conversation_volume_opened` for any reported figure.
- **DON'T** report a low AR as a regression without checking classification coverage first — a stalled classifier and a failing agent look identical in the metric alone.
- **DON'T** trust an entity ID from a profile, note, or baseline file without resolving it.
- **DON'T** claim handoffs, tickets, or brand routing were verified — MCP shows handoff counts, not outcomes.
- **DON'T** let an `estimate_ar.py` figure be called AR, enter a baseline, or reach `/support-ratios` or `/monthly-deck`.
- **DON'T** stage, promote, or revert anything. This skill is read-only.
- **DON'T** fall back to REST, curl, or a script when the MCP server is down. Report the outage and stop.
- **DON'T** infer causation from a changeset timestamp lining up with a metric move.
