---
name: ada-health
description: Health check for an Ada AI Agent instance — surfaces recent config changes, action/API failures, handoff and repeat-contact movement, and automated resolution by channel over a short window. Read-only, everything via Ada MCP. Use when asked to check an Ada instance's health, whether anything recently broke or regressed, or to run a post-deployment or post-cutover check.
user-invocable: true
argument-hint: '[instance] [--days N] [--ar-days N] [--ar-offset N] [--topics]'
allowed-tools: Read, Grep, Glob, AskUserQuestion, Skill, Bash(mkdir -p *), Bash(cat *), Bash(ls *), Bash(python3 *ada-health/scripts/estimate_ar.py *), Bash(python3 *ada-health/scripts/coverage_curve.py *)
---

# Ada Instance Health Check

Read-only. This skill **never** stages, promotes, or reverts anything. If a finding needs a fix, name it and hand off to the skill that owns it.

Two tiers. Tier 1 is a fixed cheap sweep of aggregate metrics — no per-conversation reads, ever. Tier 2 is per-conversation and only runs when the user picks it from a prompt. Never run a tier-2 query because a finding looks interesting.

## Step -1: Pre-Flight

Invoke `skill: "preflight"` if the `ada-tablo` plugin is enabled. It is not required — this skill has no dependency on the `ada-tablo-ops` repo. If preflight is unavailable, continue without it and say so once.

## Step 0: Resolve instance, window, profile

**Instance.** From the first argument, or from an explicit instance name in the user's request. If neither, list the profiles in the profile directory (see **Profile** below for its exact location) plus any Ada MCP servers visible in this session and ask via `AskUserQuestion`. Never guess — the wrong instance produces a confident report about the wrong AI agent.

Set `SERVER` to that instance's MCP tool prefix (`mcp__ada-tablo__`, `mcp__ada-scripps__`). Every call below uses it. If the server is not connected, stop and say so — do not fall back to REST, curl, or a Python script. This skill is MCP-only by design.

**Windows.** This skill runs **two different window pairs**, because the metrics divide into two classes with incompatible freshness requirements. Never use one pair for both.

*Date ranges are inclusive of both endpoints.* Verified 2026-09-08: the seven single-day volumes for Sep 2-8 summed to exactly the 82 returned by `start=2026-09-02, end=2026-09-08`. So adjacent windows sharing a boundary date **double-count that whole day** — a naive `today-N → today` against `today-2N → today-N` put 10 of 46 conversations in both windows and damped every delta. Always leave a one-day gap.

**Continuity pair** — `--days N`, default **3**. Used for `containment_rate`, `conversation_volume_engaged`, `avg_handle_time`, handoff rate, repeat contact, status codes, changesets. None of these depend on the AR classifier, so they run on the freshest data available. Catching something that broke yesterday is the entire point of the check.
- Current: `start = today - (N-1)`, `end = today`
- Prior: `start = today - (2N-1)`, `end = today - N`

**Settled pair** — `--ar-days N`, default **7**; offset from `AR_OFFSET` (Step 0.5). Used for `resolution_rate` and `csat_rate` only. Both are LLM-classified after the fact and are unreadable on fresh data.
- Current: `start = today - (AR_OFFSET + N - 1)`, `end = today - AR_OFFSET`
- Prior: `start = today - (AR_OFFSET + 2N - 1)`, `end = today - (AR_OFFSET + N)`

Report the two window pairs explicitly at the top of the report. A reader who sees one date range will assume every number came from it.

Every `get_ada_metric` and `get_conversations` call takes explicit `start_date` and `end_date` in `YYYY-MM-DD`.

**Profile.** Profiles live at the **plugin root**, in `<plugin>/profiles/<instance>.md` — a sibling of `scripts/` and `skills/`, **not** inside this skill's own directory. The skill base directory you are given is `<plugin>/skills/ada-health/`, so the profile is one level *above* it: resolve `../../profiles/<instance>.md`.

**Verify before concluding a profile is absent.** Glob `**/profiles/*.md` under the plugin root rather than testing a single relative path. On 2026-09-08 this path was resolved against the skill directory instead, the check came back empty, and the run reported "no profile found" for an instance that *did* have one — so brand partition slicing silently never ran and a documented known issue went unmentioned. A wrong "no profile" is worse than a missing profile, because it looks like a clean account-level pass.

A profile may supply: dashboard base URL, a partition variable and its values, expected escalation reasons, a minimum-N floor, threshold overrides, and known-issue context worth repeating in the report.

**A genuinely missing profile is not an error.** Without one, run every block below at account level with prior-window comparison, skip partition slicing, and use the default thresholds. Say once in the report that no profile was found, so the reader knows partition checks did not run — and say *where* you looked, so a path mistake is visible rather than silent.

Set `MIN_N` from the profile, default **20** engaged conversations.

## Step 0.5: Measure the classification lag — set AR_OFFSET

**Do not hardcode the lag and do not assume it is short.** Ada's AR classifier runs days behind, the depth varies by instance and drifts as Ada's pipeline speeds up or stalls, and a stale hardcoded offset fails silently — it hands you a confident AR number built on a fraction of the traffic.

If `--ar-offset N` was passed, use it and skip this step. Otherwise measure it.

Sweep the last 8 single days. For each `d` in `today-7 … today`, three calls with `start_date = end_date = d`:

1. `conversation_volume_engaged`
2. same, plus `ARSTATUS IS "Resolved"`
3. same, plus `ARSTATUS IS "Not Resolved"`

24 calls, ~360 tokens total. **Query one day as `start_date == end_date`** — ranges are inclusive of both endpoints, so `end = d + 1` spans two days and blends each fresh day with the settled day after it, which under-reports the lag. Skip any day where engaged is 0 — it carries no coverage information either way.

`scripts/coverage_curve.py` computes this same curve and prints it as a table with a settled-days summary. The inline sweep above is the default because it needs no credential beyond the MCP connection the skill already has, whereas the script needs `ADA_TOKEN` for the instance. Reach for the script when you want a lookback longer than 8 days or a human-readable table to watch a backlog clear across runs:

```
ADA_TOKEN=<instance token> python3 <plugin>/scripts/coverage_curve.py \
  --url <instance>/api/mcp --channel email --days 14
```

The two must stay in agreement — if you change the coverage rule here, change it there.

`AR_OFFSET` = the age in days of the **newest day whose coverage is >= 95%**, provided every older day in the sweep is also >= 95%. Require that monotonicity: a single fresh day that happens to classify early is not evidence the backlog has cleared behind it. If no day reaches 95%, set `AR_OFFSET` to the age of the oldest day swept and say in the report that the entire 8-day sweep is unsettled, so even the settled-pair AR is gated.

Measured on scripps 2026-09-08 — the shape to expect:

| Age (days) | Coverage |
|---|---|
| 0 | 8.3% |
| 1 | 16.7% |
| 2 | 16.7% |
| 3 | 70.0% |
| 4 | 93.3% |
| 5-6 | 100% |

That instance needed `AR_OFFSET = 5`. **Excluding only the last 24 hours would have accomplished nothing** — day 1 and day 2 sat at 16.7%. Treat the table as an illustration of the curve's shape, never as a source for the number.

**Report the curve whenever `AR_OFFSET` exceeds 2**, and flag a change in it against the last run's recorded value (Step 10). A lag that is growing run over run is its own finding — Ada's classification pipeline is falling further behind — and it is invisible in any single reading.

**The classifier emits `Not Resolved` first.** On the scripps sweep, all 5 conversations classified across the three freshest days were `Not Resolved`, with zero `Resolved`. This is the mechanism behind the biased-backlog warning in Step 3: a fresh-window AR is dragged toward zero by construction, not by the agent performing worse. Never report a fresh-window AR, even when it looks fine.

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

Call `get_ada_metric` once per window, on the pair that matches the metric's class (Step 0). 10 calls.

| Metric | Window pair |
|---|---|
| `containment_rate` | continuity |
| `conversation_volume_engaged` | continuity |
| `avg_handle_time` | continuity |
| `resolution_rate` | **settled** |
| `csat_rate` | **settled** |

`conversation_volume_engaged` on the settled pair is also needed as the AR denominator and for the numerator guard — that is 2 more calls, and it is not interchangeable with the continuity volume.

Use `conversation_volume_engaged`, never `conversation_volume_opened`. `opened` runs ~40% higher and is not the number the Ada dashboard shows.

**AR coverage gate — run this before reporting any resolution_rate.**

The gate stays even though Step 0.5 chose the offset. `AR_OFFSET` is derived from single-day coverage and can still be wrong for an aggregated window, and it does not protect a per-channel slice at all. Belt and braces: the offset avoids the problem, the gate catches it when the offset misses.

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

A day that has reached >=95% coverage is settled — that is exactly the rule Step 0.5 applies to pick `AR_OFFSET`, so a gate trip on the settled pair means the measured offset was too small for this window. Say so, and record the discrepancy in the state file.

**`containment_rate` is derived mechanically from whether a handoff occurred and is unaffected by this backlog.** It is the correct continuity metric whenever the coverage gate trips, and it runs on the fresh continuity pair — so when AR is gated, containment still answers "did anything break in the last three days." Check coverage per channel, not just account-wide: a backlog can hit one channel while others sit at 100%.

**If continuity-window `conversation_volume_engaged` < `MIN_N`, the run is INCONCLUSIVE.** Judge the settled pair against `MIN_N` separately — the two windows have different lengths and different volumes, and one can clear the floor while the other does not. Report every raw number, state that the window holds too little traffic to read deltas as signal, and skip the flag bands entirely for percentage metrics. Do not report a quiet window as a clean pass — at low volume, zero conversations is the expected result, not evidence of health.

## Step 4: Automated resolution by channel

Candidate channel values: `email`, `voice`, `chat`, `web`, `mobile`, `mobile_sdk`, `api`.

1. `conversation_volume_engaged` per candidate, continuity current window (7 calls). Drop any returning 0 — that value is not in use on this instance.
2. For surviving channels with volume >= `MIN_N`: `resolution_rate` and `conversation_volume_engaged` on the **settled pair**, current + prior (4 calls each). AR is settled-pair only here, exactly as in Step 3.
3. **Run the Step 3 coverage gate per channel, on the settled pair.** A backlog is routinely channel-specific — one channel at 27% while another sits at 100% — and `AR_OFFSET` is measured account-wide, so it does not protect an individual channel. A channel below 80% coverage shows its containment rate and its coverage figure instead of an AR delta.

Report a table of channel, volume, AR now, AR prior, delta. Channels below `MIN_N` appear in the table with their volume and an explicit "insufficient volume" marker instead of a delta. Where a channel's continuity volume and settled volume differ materially, show both — otherwise the AR column appears to have a denominator it does not have.

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

**State both window pairs and `AR_OFFSET` in the header**, e.g. `continuity 2026-09-06 → 2026-09-08 vs 2026-09-03 → 2026-09-05; AR/CSAT 2026-08-28 → 2026-09-03 vs 2026-08-21 → 2026-08-27 (AR_OFFSET 5d)`. Tag the AR and CSAT rows in every table so no reader assumes they share the continuity dates.

Every flag carries its **denominator**. `AR fell 12 points` is not a finding; `AR fell 12 points on email (n=84)` is. Any flag whose denominator is below `MIN_N` is demoted to "insufficient volume" and reported as an observation, never as a flag.

**Numerator guard.** A denominator floor alone is not enough — at n=25, a 50-point AR swing is two conversations changing hands. Before flagging any *rate* delta, convert both sides back to conversation counts (`rate x volume / 100`). If the two counts differ by fewer than **5 conversations**, demote it to an observation and say the delta rests on fewer than 5 conversations. This applies to AR, CSAT, containment, handoff rate, and repeat-contact rate alike. Absolute-count findings — a 5xx, a reverted changeset, a raw handoff count — are exempt; they are readable at any volume.

Flag bands, unless the profile overrides them:

| Band | Trigger |
|---|---|
| RED | any 5xx > 0 · a changeset reverted in window · AR down >10pts on a slice with n >= `MIN_N` · 4xx > 10% of engaged volume · handoff rate up >15pts |
| AMBER | AR down 5-10pts · CSAT down >5pts · repeat-contact rate up >5pts · handoff rate up 5-15pts · 4xx code doubled (n>=3) · changeset promoted in window · changeset in `testing` >14d |
| GREEN | AR up >5pts · handoff rate down >5pts · repeat-contact rate down >5pts |
| INCONCLUSIVE | engaged volume < `MIN_N` |
| AMBER | `AR_OFFSET` grew by 2 or more days since the last run — Ada's classifier is falling further behind |

When a changeset was promoted in the window **and** a metric moved, say the two coincide and that the direction is unverified. Do not assert causation from a timestamp.

**A changeset correlates only against the continuity metrics.** The settled AR/CSAT window ends `AR_OFFSET` days ago, so a changeset promoted this week is usually *outside* it entirely — its AR effect is not measurable yet. Say that plainly rather than reading the settled AR as evidence either way.

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

Offer to append a one-line run record to `~/.ada-health/state/<instance>-last-run.md` (`mkdir -p` first): timestamp, **both window pairs**, **`AR_OFFSET`**, engaged volume for each pair, **AR-status coverage (account-wide and per channel)**, AR, containment, CSAT, handoff rate, repeat rate, and the flags raised.

Coverage is the column that makes Step 3's trend work, and `AR_OFFSET` is the column that makes the lag trend work. Record both even when nothing tripped — a lag drifting from 3 days to 6 over four runs is a real finding that no single run can show. Keep every run rather than overwriting; the history is what distinguishes a clearing backlog from a real decline.

Records written before the two-window split are **not comparable** on AR — their AR came from a fresh, partly-classified window. A record with no `AR_OFFSET` column predates the split: use it for containment, handoff and repeat rate, and ignore its AR.

State lives outside the plugin directory so a marketplace update cannot clobber it. On the next run, read it and report movement against the last run alongside the prior-window comparison. Ask before writing.

## Reading conversations: match model and detail to the task

Two task shapes, two different setups. Picking the wrong one produced a false root cause in the
2026-09-14/15 AR-decline investigation.

**Large-N classification / tallying** — "how many of these 200 mention X", "bucket these by
playbook", "what share are power-on complaints". Haiku subagents reading `detail_level="SUMMARY"`
are fine here. Individual misreads wash out in the aggregate. Cross-check the resulting counts
against structured data (`get_ada_metric` volumes, topic/playbook-filtered counts) as a sanity
check; if the tally and the metric disagree by more than a rounding margin, the tally is wrong.

**Small-N causal attribution** — "why did these 15 escalate", "what is actually failing here". The
deliverable is a causal claim that will be reported and acted on, so:

- Use a stronger model — Sonnet, or a forked session — not Haiku.
- Read `detail_level="FULL"` / `get_conversation`, or pull the raw per-conversation export fields
  directly. **Not SUMMARY.**
- Budget for it: ~11k tokens per chat transcript, and full-detail voice transcripts run several
  thousand tokens each, sometimes far more. If the budget only covers SUMMARY, the honest move is to
  read fewer conversations at full detail, not more at SUMMARY.

SUMMARY-level data does not carry the granular `action_executed` / outcome entries. Without them a
model cannot distinguish "a client-side validator rejected the input before the action ever ran"
from "the action's backend call failed" — so a causal story built on SUMMARY is close to a guess
even from a strong model. That is the exact substitution that happened on 2026-09-14: a Haiku
subagent reading SUMMARY data reported "the Aug 14 migration broke the Device Status action
backend"; pulling its own cited conversations at full transcript detail showed client-side serial
validation rejecting a legacy device ID format before Device Status was ever called.

**Spot-check every confident causal claim a subagent makes.** When a subagent report asserts "X
broke", "the migration caused Y", or anything else causal and specific, pull **3-4 of its own cited
conversations** at full detail and confirm the mechanism before repeating the claim to the user or
letting it into a recommendation. Treat this as a standard verification step, not an optional one —
it caught two separate overclaims in the 2026-09-14/15 investigation.

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

Tier 1 as specified is roughly 75-80 calls and **under 9,000 tokens**, dominated by the changeset listing rather than the metrics. The Step 0.5 lag sweep adds 24 calls (~360 tokens) and the settled-pair metrics add ~6 more; both are noise against one `get_conversations(SUMMARY)`. The whole design rests on aggregate metric calls being nearly free while per-conversation reads are not.

`conversation_summaries` is **banned**. One day of it costs more than five full transcripts and more than the entire tier-1 sweep. `get_conversations(detail_level="SUMMARY")` with filters answers the same questions for a fraction of it.

## DO

- **DO** resolve every entity ID fresh via `list_entities` in the same run.
- **DO** report the denominator beside every rate, and demote any flag below `MIN_N`.
- **DO** measure `AR_OFFSET` every run (Step 0.5) instead of assuming a lag, and report the curve when it exceeds 2 days.
- **DO** run the AR coverage gate before quoting any `resolution_rate`, per channel as well as account-wide, even after the offset is applied.
- **DO** run continuity metrics on the fresh window and AR/CSAT on the settled window, and label which is which in the report.
- **DO** leave a one-day gap between current and prior windows — ranges are inclusive on both ends, and one day is `start == end`.
- **DO** glob for the profile under the plugin root before reporting that none exists, and say where you looked.
- **DO** spot-check 3-4 cited conversations at full detail before repeating any confident causal claim a subagent made.
- **DO** use a stronger model and `FULL` detail for small-N causal attribution; Haiku + `SUMMARY` is only for large-N tallying.
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
- **DON'T** report AR or CSAT from the fresh continuity window, however healthy the number looks. The classifier emits `Not Resolved` first, so a fresh AR is biased low by construction.
- **DON'T** hardcode `AR_OFFSET` or copy the example curve's numbers. Measure it; the lag drifts per instance and over time.
- **DON'T** compare a state-file AR against a record with no `AR_OFFSET` column — those predate the two-window split and are not comparable.
- **DON'T** trust an entity ID from a profile, note, or baseline file without resolving it.
- **DON'T** claim handoffs, tickets, or brand routing were verified — MCP shows handoff counts, not outcomes.
- **DON'T** let an `estimate_ar.py` figure be called AR, enter a baseline, or reach `/support-ratios` or `/monthly-deck`.
- **DON'T** stage, promote, or revert anything. This skill is read-only.
- **DON'T** fall back to REST, curl, or a script when the MCP server is down. Report the outage and stop.
- **DON'T** infer causation from a changeset timestamp lining up with a metric move.
