---
name: changeset-inspect
description: On-demand read of how each live Tablo Ada changeset is doing in production. Compares the playbooks, coaching rules and tools a changeset touched before and after it went live, from Ada's own grading, skips the last 72 hours unless asked for a partial read, and appends the result to reference/history/readings for the Friday evidence loop. Read-only on Ada. Use when asked to inspect, check or read a deployed or rolled-out changeset, any day.
user-invocable: true
argument-hint: '[CHANGESET-ID] [--partial]'
allowed-tools: Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/changeset_inspect.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/ledger.py open *), Read, Grep, Edit(/Users/181085/Obsidian/Projects/Ada-Evidence-Loop/FINDINGS.md)
---

# Changeset inspect (Tablo)

An early read, never a verdict. The decision ledger closes predictions with one test at their
horizon; nothing here closes, edits or judges a decision. Nothing here writes to Ada.

## Step 1: Read

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/changeset_inspect.py --format json read [--changeset <ID>] [--partial]
```

- No argument: every changeset promoted in the last 28 days, every active rollout, and every
  changeset an open decision names.
- `--partial`: counts from the go-live time to now, ungraded conversations included. Refused
  once a full read is available (from the fifth UTC day after go-live); run a full read then.
- The script appends one row per changeset to `reference/history/readings/<date>.jsonl`, each
  as soon as it is read.
- A cold run can take about 10 minutes. Run the command in the background and wait for it to
  finish before reporting.

## Step 2: Report

Per changeset, 3 to 5 lines, plain words, numbers with denominators:

1. Name, id, how it went live (promoted or rollout at N%), and why: the deploy note, or
   "reason unknown" with Ada's summary.
2. Windows compared.
3. For a rollout, the A/B lines first (changeset against the rest of traffic, same channel,
   same days). Then the headline lines with their intervals. `compare_changeset_metrics` only
   as secondary, saying its baseline is all channels. Each `custom_metric_pass_rate` row in
   `rollout_compare.metrics` is one more secondary line: `metric_name`, pass rate changeset
   against baseline, then pass, fail and not-applicable (`null_count`) counts per cohort from
   `counts`, marked "baseline is all channels". Ada gives no verdict on custom metrics, so none
   is printed.
4. Any other line whose interval excludes zero, next to "N intervals computed", since about
   1 in 20 does so by chance.
5. The instance line for the same channel, other changes live or reverted in the same windows
   (same entity marked; a revert from `events`), the ungraded share on a partial read, and "early read, not a verdict".

`wait`, skipped and error changesets: one line each.

**The instance line (F393).** The whole instance moves too: across late September voice
containment moved about +3 to +4pp and email +7 to +11pp with intervals that exclude zero. So
read every entity delta against the instance delta for the same channel and window, and say
both: "the playbook moved +4.0pp, all voice moved +3.5pp". When the entity delta has the same
sign and falls inside the instance delta's interval, say the entity moved with the instance and
the reading shows no effect of its own. Only a delta outside the instance interval, or of the
opposite sign, is reported as the entity's own movement, and still as an early read.

**Chance across many intervals (F396).** At 95%, about 1 in 20 intervals excludes zero by
chance. Before the per-changeset lines, say once for the run: "N intervals computed across M
readings; about N/20 would exclude zero by chance", with N the sum of `intervals_computed`.
The same entity and channel headlining several readings whose after-windows overlap counts the
same conversations more than once, so report it once, naming each reading it appears in; three
readings agreeing there is one observation, not three.

Say once per run that entity lines count conversations that reached the entity, so a change
to who reaches it moves the population as well as the behaviour.

## Step 3: Findings

Anything found on the way is one line at the bottom of Open in FINDINGS.md, next ID, no
recommendation. Do not investigate it.

## Step 4: End

End with "Inspect complete". No next step, no offer.

## Deploy notes

The session that promotes a changeset or starts a rollout writes one before the promote or
rollout call. No note, no promote.

1. Draft it from the conversation: why the change was made (David's reason, in plain words), the
   source W#/F#, the expected effect per entity and channel, and the gate batch and ledger
   decision if there are any.
2. Show the draft next to the promote confirmation. David corrects it or says yes.
3. On his yes, write it, then promote:

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/changeset_inspect.py note --changeset <ID> --by david --source <W#,F#> --expect "<containment|resolution> <up|down> on <entity_id>/<channel>" [--gate <BATCH>] [--decision <DECISION-ID>] --note "<why it changed>"
```

A note on a changeset not yet live records `live_kind: staged`; a read takes the live time from
Ada. After a rollout starts, run the same command once more so the rollout start is recorded.
`--expect` sets the headline lines of every later read, so name the entity and channel the change
is meant to move. A reverted changeset is refused.
