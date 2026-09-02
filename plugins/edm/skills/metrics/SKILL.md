---
name: metrics
description: EDM Metrics -- report per-phase durations, gate review times, and Claude API cost; per-round code-audit cost; tiered-vs-untiered lens cost where measured; aggregate across initiatives; suggest calibration of Phase Timing Guidelines from actual data. An optional human-baseline cost comparison is available behind --with-human-baseline. Invoked explicitly via /edm:metrics.
user-invocable: true
model: sonnet
effort: high
argument-hint: <PREFIX|--all|--calibrate> [--with-human-baseline]
allowed-tools: Read, Bash(edm-state *), Glob, Grep
---

# EDM Metrics & Calibration

Reports **time** (wall-clock duration per phase + gate review time) and **cost** (Claude API USD
spent, computed from session token usage x current Anthropic pricing) for each phase, plus
per-round code-audit cost and a tiered-vs-untiered lens-cost comparison where that data exists
(EDMV3-T48/T51). The Claude cost is knowable and actionable on its own -- it does not need a
human-baseline comparison to be useful, so the default report leads with it alone.

The single-initiative default report includes columns: Phase | Duration | Claude Cost | Tokens
(input/output) | Model used. A human-baseline comparison (estimated developer hours x
`${user_config.human_hourly_rate_usd}`) remains available but is **opt-in**, not shown by default
-- pass `--with-human-baseline` to render it (adds Human Cost and Savings columns, with an explicit
note that the baseline is an estimate, not a measured figure).

**Arguments**: $ARGUMENTS

## Operational Orchestration

This skill is a thin wrapper around `bin/edm-state metrics-report`. Three modes, each with an
optional `--with-human-baseline` flag:

### Mode 1: Single-initiative report

```
/edm:metrics AUTH
/edm:metrics AUTH --with-human-baseline
```

Calls `edm-state metrics-report AUTH [--with-human-baseline]`. Reads
`${user_config.srd_root}/AUTH/.edm-state.json` and prints a per-phase report:
- Phase number -> wall-clock duration, Claude cost, tokens, model
- Gate number -> review time (seconds between phase-complete and gate-approved)
- Total initiative time and total Claude cost
- Code-audit section (when round data exists): rounds run, lenses per round, cost per round
- Tiered vs. untiered lens cost (when tiering data exists, EDMV3-T48) -- omitted entirely when no
  tiering data has been measured, rather than rendered empty
- With `--with-human-baseline`: adds Human Cost and Savings (ratio) columns, and a total-row
  savings ratio, each labelled as an estimate

### Mode 2: Aggregate across all initiatives

```
/edm:metrics --all
/edm:metrics --all --with-human-baseline
```

Calls `edm-state metrics-report --all [--with-human-baseline]`. Aggregates across every initiative
in `${user_config.srd_root}/` (active and `.archived/`) and prints one row per initiative:
- Initiative prefix and recorded size
- Total wall-clock time across all phases
- Total Claude API cost
- With `--with-human-baseline`: adds total human baseline cost and cost ratio (human cost / Claude
  cost)

### Mode 3: Calibration suggestion

```
/edm:metrics --calibrate
```

Calls `edm-state metrics-report --calibrate`. Outputs per (size, phase) aggregate rows from all completed initiatives (active and archived):
- For each (size, phase) combination: sample count, median duration in seconds, median Claude cost

Useful for retrospectives. The team can then update the Phase Timing Guidelines table in `CLAUDE.md Sec."Phase Timing Guidelines (EDMV3-T38)"` based on the observed medians. Read `docs/canonical-sections.md` (resolved relative to the EDM plugin's own root -- `plugins/edm/` in this repository, or the installed plugin's cache root, never the caller's cwd) for the actual section text; a bare `CLAUDE.md Sec."..."` reference does not resolve because CLAUDE.md at the plugin root is not loaded as runtime context. `--calibrate` ignores `--with-human-baseline` -- there is no baseline concept at this granularity.

## Interpretation Notes

When the user reads the report:

- **Wall-clock vs. work time**: wall-clock includes idle time. The `gate_review_seconds` field separates "human waiting on review" from "Claude executing the phase."
- **Long execution time** -> phase complexity, agent inefficiency, or scope underestimate.
- **Long gate review time** -> stakeholder availability, not methodology friction.
- **Phases that consistently miss guidelines** -> methodology calibration target.
- **Claude cost** is computed from `~/.claude/projects/<encoded-cwd>/*.jsonl` session files (assistant messages with `usage` fields), summed for messages with `timestamp >= phase started_at`, multiplied by Anthropic's published per-million-token rates per model (Opus, Sonnet, Haiku -- distinct rates for input, output, cache-read, cache-write). Override default rates with env vars `EDM_OPUS_INPUT_RATE`, etc.
- **Cost outliers** matter: if a single phase's Claude cost is 10x the median for that phase across initiatives, something went wrong (likely a runaway agent, excessive retries, or context exhaustion). Investigate.
- **Per-round audit cost** (when present) surfaces the cost of an individual code-audit round -- watch for a round whose cost is far above the others, which usually means a large `--lenses` re-run rather than a targeted one.
- **Tiered vs. untiered lens cost** (when present) shows what the wave-C measured tiering matrix (EDMV3-T48) actually saved for the same lens set, rather than an assumed saving.
- **Human baseline (opt-in, `--with-human-baseline` only)**: computed from the Phase Timing Guidelines (median expected hours per phase x `${user_config.human_hourly_rate_usd}`) -- an estimate, not a measured cost. The rendered Savings ratio (`human_cost / claude_cost`) is useful context for a stakeholder conversation, but it is not the report's headline: a tool that measures its own cost precisely should not lean on an unmeasurable baseline to make its case. `human_baseline_usd` is still recorded in state on every phase regardless of the flag, so the comparison remains reconstructable later even though it is not shown by default.

## Process

1. Parse `$ARGUMENTS`, including an optional trailing `--with-human-baseline`.
2. Invoke `edm-state metrics-report` with the appropriate argument(s).
3. Format the output for readability.
4. If single-initiative mode, also print: "To calibrate the team's guidelines from accumulated data, run `/edm:metrics --calibrate`." If the human-baseline flag was not passed, note once that `--with-human-baseline` is available for that comparison -- do not render it unasked.

This skill does not modify any state -- it's read-only reporting.
