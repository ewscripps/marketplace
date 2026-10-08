---
name: early-read
description: Early transcript read of a deployed Tablo Ada changeset, within hours of the promote or rollout start instead of the 72 hours Ada's grader needs. Pulls the conversations that entered the changeset's playbooks since it went live, has Haiku readers read each one twice against the change's own expectations (the deploy note and the work item's done-when), checks every quote against the transcript in code, counts the touched code tools and coaching rules in code, and lists the conversations the session must read in full before repeating anything. Read-only on Ada. Use when asked for an early read, a quick read or a transcript read of a change that just went live.
user-invocable: true
argument-hint: 'CHANGESET-ID [W#]'
allowed-tools: Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/early_read.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/changeset_inspect.py *), Read, Grep
---

# Early read (Tablo)

An early read, never a verdict. It answers "is the change doing what it was meant to, on real
conversations" before Ada's grading is in; the 72-hour production read (`changeset-inspect`) is
the verdict. Nothing here writes to Ada or to `reference/history/`.

`forensics_evidence.py --cluster-review` reads by cluster key from last Friday's triage, so it
cannot read a change that went live mid-week. This reads by playbook since the go-live time.

## Step 1: Write the checks

Read the changeset's deploy note (the newest `deploy_note` row for the ID in
`~/repos/ada-tablo-ops/reference/history/deployments.jsonl`) and, when a work item is named, its
TODO line and done-when. Turn each expectation into one check: one sentence saying what Ada
should do in the conversation, judged from the messages alone. Examples from W86:

- "On a call, a customer whose Tablo is dead is offered the replacement form by a one-time text."
- "On chat, the replacement form is given as a labelled link."
- "A customer whose Tablo was seen in the last 24 hours, or whose light came back, is sent to
  connectivity troubleshooting and not back into the replacement steps."

Leave out what code counts: which channel entered, handoffs, and every run of a code tool or
coaching rule the changeset touched (outcome status and return values) are counted from the
transcript events by the script. A check the messages cannot show (a text actually delivered) is
not a check; say in the report that the transcript cannot show it.

## Step 2: Read

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/early_read.py read --changeset <ID> \
  --check "<check 1>" --check "<check 2>" ... [--channel voice] [--max 40] [--group 5]
```

- Window: the promote time (or rollout start) to now. `--since` / `--until` take ISO times.
  A changeset that is not live (still TESTING, no active rollout) needs `--since`; the output
  then says "not live".
- Every transcript is fetched fresh from Ada, so a chat or email still open at an earlier
  fetch is read as it is now.
- Conversations: every one that entered a playbook the changeset touched, by Ada's PLAYBOOKID
  filter; a seeded random sample of `--max` (40) when there are more. Simulated ones are left out.
- Each conversation is read twice, `--group` (5) to a reader, in two different groupings: 40
  conversations is 8 readers a reading, 16 `claude -p` calls on the subscription.
- Run it in the background; a 40-conversation read takes several minutes. The result is saved to
  `~/.ada-evidence/tablo/early-reads/<changeset>_<UTC time>.json` (PII, outside git).
- "Nothing to read yet" means no conversation has entered since go-live. Say so with the
  window and stop; about 35 a day enter Tablo Device Issue & Replacement, for scale.

## Step 3: Re-check before repeating anything

The output ends with READ THESE IN FULL: every conversation with an agreed "not met", a
single "not met" where the other reading was lost ("read once: not met"), a disagreement
between the two readings, a quote not found in the conversation, or no reading at all ("not
read"), plus two that agree, at random. The CHECKS counts are agreed answers; a check read
only once or not at all is counted on its own line under it. For each one:

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/early_read.py show <CONVERSATION-ID>
```

`show` fetches the conversation from Ada by its ID, so an invented ID fails here. Read it and
decide each flagged check yourself: confirmed or overturned. A reader's count is reported only
after this, corrected by what the full reads overturned, and a conversation ID is repeated only
after `show` has printed it.

## Step 4: Report

Five to eight lines, plain words, numbers with denominators:

1. Change, how it went live and when, the window, conversations entered by channel, how many read.
2. Per check: met, not met, cannot tell, does not apply, after the re-check, with the named
   conversations behind every "not met".
3. Touched tools and coaching from code: runs, statuses, and each return field's values with
   counts (for example a matcher's `match_reason: ok 23, bad_payload 4`, a bucket tool's values,
   a disabled coaching rule that still applied). Fields with a different value nearly every run
   (timestamps, IDs) are named and left out.
4. Handoffs: how many, and from the full reads what caused them.
5. What the transcript cannot show, and "early read, not a verdict".

In a `work` session, a defect with measured harm (named conversations) is a finding under that
skill's rule; outside one, it stays in the report.
