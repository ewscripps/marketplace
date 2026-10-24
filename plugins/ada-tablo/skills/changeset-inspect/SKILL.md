---
name: changeset-inspect
description: On-demand read of how each live Tablo Ada changeset is doing in production. Compares the playbooks, coaching rules and tools a changeset touched before and after it went live, from Ada's own grading, skips the last 72 hours unless asked for a partial read, and appends the result to reference/history/readings for the Friday evidence loop. Read-only on Ada. Use when asked to inspect, check or read a deployed or rolled-out changeset, any day.
user-invocable: true
argument-hint: '[CHANGESET-ID] [--partial]'
allowed-tools: Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/changeset_inspect.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/ledger.py open *), Read, Grep, Edit(/Users/181085/Obsidian/Projects/Ada-Evidence-Loop/FINDINGS.md)
---

# Changeset inspect (Tablo)

An early read, never a verdict. A decision closes from its day-7 verdict read (`early_read.py
verdict`, evidence-loop step 2); nothing here closes, edits or judges a decision. Nothing here
writes to Ada.

## Step 1: Read

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/changeset_inspect.py read [--changeset <ID>] [--partial]
```

- The output is the text form, the one to report from. The stored row is still appended to the
  readings file; `--format json` prints that row instead, for a machine step and for the
  `rollout_compare` custom-metric rows.
- No argument: every changeset promoted in the last 28 days, every active rollout, and every
  changeset an open decision names.
- `--partial`: counts from the go-live time to now, ungraded conversations included. Refused
  once a full read is available (from the fifth UTC day after go-live); run a full read then.
- The script appends one row per changeset to `reference/history/readings/<date>.jsonl`, each
  as soon as it is read.
- Superseded changesets (a later edit replaced every step they added) are skipped and said in one
  line: "1 superseded, frozen at its last reading" or "N superseded, frozen at their last reading".
  `--changeset <ID>` still reads one by name.
- `read --list` prints what a read would select, the superseded line and any playbook edited
  outside a changeset, with no metric call.
- Each read records the changeset's edit (step and tool ids, no text) in
  `reference/history/edits.jsonl`; `edits --backfill` does it for every changeset the readings and
  the registry name.
- A cold run can take about 10 minutes. Run the command in the background and wait for it to
  finish before reporting.

## Step 2: Report

Per changeset, 3 to 5 lines, plain words, numbers with denominators. Name every changeset by its
registry title (one title per changeset); never print an id, a step id or a "+x points, range a to
b". A result is counts with a verdict word: "73 of 87 chats resolved, before 50 of 85: up". Say
the playbook edited outside a changeset, if the read printed one.

1. Title, how it went live (promoted or rollout at N%), and why: the deploy note, or
   "reason unknown" with Ada's summary.
2. Windows compared.
3. For a rollout, the A/B lines first (changeset against the rest of traffic, same channel,
   same days), as "A/B voice: containment 30 of 40 on the change, 20 of 50 on the control: up".
   Then the headline lines as `read` prints them: counts with a verdict word for a change with
   both sides ("<playbook> voice: resolution 30 of 100 after, 20 of 100 before: up"); "new, no
   before" or "was ... before, none after" for one side; "no data" when the channel has no line;
   "no comparison" when a side has no conversations. The `headline_text` field and every delta's
   interval stay in the stored row; none is repeated here.
   `compare_changeset_metrics` only
   as secondary, saying its baseline is all channels. Each `custom_metric_pass_rate` row in
   `rollout_compare.metrics` is one more secondary line: `metric_name`, pass rate changeset
   against baseline, then pass, fail and not-applicable (`null_count`) counts per cohort from
   `counts`, marked "baseline is all channels". Ada gives no verdict on custom metrics, so none
   is printed.
4. Any other comparison that came out up or down, next to the run's "N of M comparisons clear of
   chance, about X would be by chance" line, since about 1 in 20 comparisons clears by chance.
5. The instance line for the same channel, other changes live or reverted in the same windows
   (same entity marked; a revert from `events`), the ungraded share on a partial read, and "early read, not a verdict".

`wait`, skipped and error changesets: one line each.

**The instance line (F393).** The whole instance moves too: across late September voice
containment and email both moved up for the whole instance. So read every
entity's verdict word against the instance's for the same channel and window, and say both, from
the counts: "the playbook went up, 30 of 100 after against 20 of 100 before; all voice went up
too, so the playbook moved with the instance". When the two words match, say the entity moved
with the instance and the reading shows no effect of its own. Only an entity that went up or down
while the instance word is "too early to tell" or the opposite, is reported as the entity's own
movement, and still as an early read.

**Chance across many comparisons (F396).** About 1 in 20 comparisons comes out up or down by
chance. Before the per-changeset lines, say once for the run: "X of N comparisons clear of chance
across M readings, about N/20 would be by chance", with N the sum of `intervals_computed` and X
the count of those that came out up or down; `read` prints the same sentence under each reading.
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
   source W#/F#, the expected effect per entity and channel, the rubric, and the gate batch and
   ledger decision if there are any. The rubric is what the day-7 verdict read checks on every
   conversation beside its four standard questions (reached the change, did the new thing, ended
   well, a benign stop): the change's own checks, one sentence each, judged from the messages
   alone; a wrong-entrant test (who the change is not meant for); the ended-well share it must
   reach (the W item's goal in resolved a week over the playbook's weekly volume, added to its
   current share); and the share that ended well the week before launch, from triage.
2. Show the draft next to the promote confirmation. David corrects it or says yes.
3. On his yes, write it, then promote:

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/changeset_inspect.py note --changeset <ID> --by david --source <W#,F#> --expect "<containment|resolution> <up|down> on <entity_id>/<channel>" --rubric "<check>" [--rubric "<check>" ...] --wrong-entrant "<test>" --ended-well-pct <N> --before-pct <N> [--gate <BATCH>] [--decision <DECISION-ID>] --note "<why it changed>"
```

A promote or rollout start without a rubric is refused: write it first. `--rubric` repeats, one
check each; the two percents are 0 to 100. A note on a changeset not yet live records `live_kind:
staged`; a read takes the live time from Ada. After a rollout starts, run the same command once
more, rubric included, so the rollout start is recorded.
`--expect` sets the headline lines of every later read, so name the entity and channel the change
is meant to move. A reverted changeset is refused.
