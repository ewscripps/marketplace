---
name: metrics
description: EDM Metrics — report per-phase durations, gate review times, Claude API cost, and human-baseline cost comparison; aggregate across initiatives; suggest calibration of Phase Timing Guidelines from actual data. Invoked explicitly via /edm:metrics.
disable-model-invocation: true
model: sonnet
effort: high
argument-hint: <PREFIX|--all|--calibrate>
allowed-tools: Read, Bash(edm-state *), Glob, Grep
---

# EDM Metrics & Calibration

Reports both **time** (wall-clock duration per phase + gate review time) and **cost** (Claude API USD spent, computed from session token usage × current Anthropic pricing) alongside a **human baseline** (estimated developer hours × `${user_config.human_hourly_rate_usd}`) for each phase.

The single-initiative report includes columns: Phase | Duration | Claude Cost | Human Cost | Savings (ratio) | Tokens (input/output) | Model used.

**Arguments**: $ARGUMENTS

## Operational Orchestration

This skill is a thin wrapper around `bin/edm-state metrics-report`. Three modes:

### Mode 1: Single-initiative report

```
/edm:metrics AUTH
```

Calls `edm-state metrics-report AUTH`. Reads `${user_config.srd_root}/AUTH/.edm-state.json` and prints a per-phase report:
- Phase number → wall-clock duration
- Gate number → review time (seconds between phase-complete and gate-approved)
- Total initiative time

### Mode 2: Aggregate across all initiatives

```
/edm:metrics --all
```

Calls `edm-state metrics-report --all`. Aggregates across every initiative in `${user_config.srd_root}/` (active and `.archived/`) and prints one row per initiative:
- Initiative prefix and recorded size
- Total wall-clock time across all phases
- Total Claude API cost
- Total human baseline cost
- Cost ratio (human cost / Claude cost)

### Mode 3: Calibration suggestion

```
/edm:metrics --calibrate
```

Calls `edm-state metrics-report --calibrate`. Outputs per (size, phase) aggregate rows from all completed initiatives (active and archived):
- For each (size, phase) combination: sample count, median duration in seconds, median Claude cost

Useful for retrospectives. The team can then update the Phase Timing Guidelines table in `skills/orchestrator/SKILL.md` based on the observed medians.

## Interpretation Notes

When the user reads the report:

- **Wall-clock vs. work time**: wall-clock includes idle time. The `gate_review_seconds` field separates "human waiting on review" from "Claude executing the phase."
- **Long execution time** → phase complexity, agent inefficiency, or scope underestimate.
- **Long gate review time** → stakeholder availability, not methodology friction.
- **Phases that consistently miss guidelines** → methodology calibration target.
- **Claude cost** is computed from `~/.claude/projects/<encoded-cwd>/*.jsonl` session files (assistant messages with `usage` fields), summed for messages with `timestamp >= phase started_at`, multiplied by Anthropic's published per-million-token rates per model (Opus, Sonnet, Haiku — distinct rates for input, output, cache-read, cache-write). Override default rates with env vars `EDM_OPUS_INPUT_RATE`, etc.
- **Human cost** is computed from the Phase Timing Guidelines (median expected hours per phase × `${user_config.human_hourly_rate_usd}`).
- **Savings ratio** = `human_cost / claude_cost`. A 50× ratio means Claude cost 1/50th of what a human team would have. Use it to make the case for AI-assisted development to stakeholders.
- **Cost outliers** matter: if a single phase's Claude cost is 10× the median for that phase across initiatives, something went wrong (likely a runaway agent, excessive retries, or context exhaustion). Investigate.

## Process

1. Parse `$ARGUMENTS`.
2. Invoke `edm-state metrics-report` with the appropriate argument.
3. Format the output for readability.
4. If single-initiative mode, also print: "To calibrate the team's guidelines from accumulated data, run `/edm:metrics --calibrate`."

This skill does not modify any state — it's read-only reporting.
