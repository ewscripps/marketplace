# Headless Ada health check: design

Date: 2026-09-30. Status: approved in conversation, awaiting spec review.

## Purpose

A scheduled, unattended check on both Ada instances (Tablo `nuvyyo-gr`, Scripps `scripps`) that catches
breakage within a day and pages only when something is broken. Every run leaves a ledger line; a RED
finding posts a Teams @mention.

Failures in scope:

- Changeset breakage: a changeset reverted, or a live changeset moving handoff or containment the wrong way.
- Tool and API failures: 4xx and 5xx on actions such as Device Status or the account lookup.
- Volume swings: a channel, topic or intent spiking or collapsing against its own history.
- Scripps brand misroutes: a conversation for one brand running another brand's playbook.

Out of scope: AR and CSAT (classified days after the conversation, so they cannot show a break within a
day; the interactive `/ada-health` and the weekly evidence loop cover them), per-conversation reads,
any write to Ada, drill-downs.

## Components

All in the `ada-health` plugin, `~/repos/marketplace/plugins/ada-health/`.

| Unit | Does | Depends on |
|---|---|---|
| `scripts/ada_mcp.py` | Minimal JSON-RPC client for `<instance>/api/mcp`: `call(tool, args)`, one retry, raises on auth or transport failure. Extracted from the `metric()` helper in `coverage_curve.py`, which then imports it. | stdlib only |
| `scripts/health_cron.py` | Entry point. `--instance tablo\|scripps`, `--as-of YYYY-MM-DD` (default today), `--dry-run` (print flags, write nothing). Resolves windows, runs the checks, applies thresholds, writes ledger and alert. | `ada_mcp.py`, `profiles/<instance>.json` |
| `profiles/<instance>.json` | Machine-readable config: MCP URL, token env var name, dashboard URL, `min_n`, partition variable name, brand to address and brand to playbook-name pattern (Scripps), thresholds. The existing `profiles/<instance>.md` stay as the interactive skill's data. | none |
| `scripts/run_health_cron.sh` | Loads tokens from an env file outside git (per Credential-Patterns), runs both instances in sequence, writes a crash alert if either exits non-zero. | `health_cron.py` |
| `com.nuvyyo.ada-health.plist` | launchd job, Mon, Wed, Fri 06:00 local. launchd runs a missed calendar interval on wake. Logs to `~/.ada-health/logs/`. | wrapper |

The interactive `/ada-health` skill is unchanged.

## Windows

Dates are inclusive on both ends (verified in the skill, Step 0). The window ends yesterday so a partial
day never enters a comparison.

| Run day | Current window |
|---|---|
| Monday | Fri to Sun (3 days) |
| Wednesday | Mon to Tue (2 days) |
| Friday | Wed to Thu (2 days) |

Baseline: the same weekday span in each of the 4 prior weeks, queried directly from Ada. Baseline value
is the median of the 4. No ledger history is needed, so the first run is as good as the hundredth, and
`--as-of` backtests any past date.

`--as-of` on a non-run day uses the span since the previous run day.

## Checks

Every entity ID (tools, topics, intents, variables, playbooks, changesets) is resolved via
`list_entities` or `list_agent_changesets` in the same run. Never read from a file.

All volume figures use `conversation_volume_engaged`.

1. **Reachable.** The first MCP call succeeds with valid auth. On failure after one retry, the instance
   is RED `unreachable` and its remaining checks are skipped. The other instance still runs.
2. **Changesets.** `list_agent_changesets(limit=30)`.
   - Reverted with `revert_time` since the previous run day: RED.
   - Promoted or rolled out in the last 14 days: compare handoff rate and containment.
     Rolled out (partial): `CHANGESETID IS <id>` against `CHANGESETID IS baseline`, current window.
     Promoted (full): current window against the equal-length span before `promotion_time`.
3. **Tool failures.**
   - Account level: engaged volume per `STATUSCODE` in 400, 401, 403, 404, 408, 409, 429, 500, 502, 503, 504.
   - For each code above zero: the same count per tool (`ACTIONID`), current window and the 4 baseline spans.
4. **Volume.** Engaged volume per `CHANNEL` in use, per `TOPIC`, per `INTENT`, current window and the 4
   baseline spans.
5. **Scripps partition** (only when the profile defines one).
   - Misroute: for each ordered brand pair (A, B), engaged volume with `VARIABLE <partition> IS <A address>`
     and `PLAYBOOKID IS <any B playbook>`, B's playbooks resolved by name pattern.
   - Brand volume: engaged volume per brand address, current and baseline.
6. **Continuity numbers for the ledger:** account engaged volume, containment, handoff rate, repeat-contact rate.

## Paging rules (RED)

Thresholds live in `profiles/<instance>.json`; the values below are defaults, tuned after two weeks of
ledger data.

| Check | RED when |
|---|---|
| Reachable | auth or transport failure after one retry |
| Run | `health_cron.py` exits non-zero (wrapper writes the alert) |
| Changeset reverted | any, since the previous run day |
| Live changeset | handoff rate at least 10 points worse than its comparison and the gap is at least 5 conversations |
| Tool 5xx | count > max(3, 3 x baseline median), per tool |
| Tool 4xx | count >= 3 x baseline median and >= 10, per tool and code |
| Volume spike | baseline median >= 10 and current >= 2.5 x median (channel, topic, intent) |
| Volume collapse | baseline median >= 10 and current <= 0.4 x median |
| Brand misroute | any count > 0 |
| Brand silent | brand volume 0 while its baseline median >= 5 |

Everything else is a ledger line. The fixed RED bands in the interactive skill (for example any 5xx > 0)
are recorded in the ledger as `band` values and never page.

Monday heartbeat: the Monday run also writes one plain post covering the previous 7 days: runs completed
per instance and RED count. A run that silently stopped shows up as a missing count.

## Outputs

**Ledger** `~/.ada-health/state/<instance>-ledger.jsonl`, one JSON object per run, append only:
`run_at`, `as_of`, `window`, `baseline_spans`, continuity numbers, per-check values with baseline medians,
`flags` (each `{check, subject, current, baseline, n, severity}`), `errors`. Aggregates only; no
customer data. Separate from the interactive skill's `<instance>-last-run.md`.

**Alert** written only when at least one RED fires, to
`~/Library/CloudStorage/OneDrive-TheE.W.ScrippsCompany/Automated Reports/Spike Alerts/`
as `ada-health-<instance>-<YYYY-MM-DDTHH-MM-SSZ>.json`:

```json
{
  "type": "ada-health",
  "instance": "tablo",
  "timestamp": "2026-10-05T10:00:03Z",
  "window": "2026-10-02..2026-10-04",
  "summary": "2 RED: Device Status 5xx 14 (median 1); topic Connectivity 212 (median 81)",
  "flags": [{"check": "tool_5xx", "subject": "Device Status", "current": 14, "baseline": 1, "n": 959}],
  "dashboard_url": "https://nuvyyo-gr.ada.support"
}
```

Heartbeat file: `ada-health-heartbeat-<YYYY-MM-DD>.json` with `type: "ada-health-heartbeat"`.

David adds `ada-health` and `ada-health-heartbeat` branches to the existing Power Automate flow:
`ada-health` posts a Teams @mention with `summary` and `dashboard_url`; `ada-health-heartbeat` posts a
plain message.

## Errors

- MCP call failure: one retry, then the instance is RED `unreachable`; the partial result is still written
  to the ledger with `errors` set.
- A resolved entity with zero volume is a valid zero. An entity that fails to resolve is logged in `errors`.
- Alert or ledger write failure: logged, exit non-zero, which triggers the wrapper's crash alert.

## Testing

- Unit tests (pytest) for window resolution per weekday and `--as-of`, baseline median, every paging rule
  at and around its threshold, and alert JSON shape. MCP responses recorded as fixtures.
- Backtest before go-live with `--dry-run --as-of`:
  - 2026-08-17 (covers the 2026-08-14 V1 to V2 playbook cutover): expect tool or volume flags.
  - 2026-09-25 (covers the 2026-09-24 V2 Presales pricing drop): expect whatever the aggregates show, recorded as the calibration reference.
  - Two quiet run dates chosen from the evidence-loop history: expect no RED.
- One live `--dry-run` per instance, then enable the launchd job.

## To verify during implementation

- How `CHANGESETID` attributes conversations to a fully promoted changeset. If promoted changesets carry
  no attribution, the before and after comparison stands alone.
- Topic and intent counts per instance, and whether the MCP endpoint rate-limits a run of several hundred
  metric calls. If it does, add pacing to `ada_mcp.py`.
- Scripps brand playbook naming, so each brand's playbooks resolve by pattern.
- `ada-scripps` returned `-32603 Internal Error` in the 2026-09-30 session; confirm it connects before the
  Scripps backtest.
