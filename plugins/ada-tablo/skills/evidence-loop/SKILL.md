---
name: evidence-loop
description: Weekly evidence loop for the Tablo Ada instance. Shows where Ada got worse this week from the whole conversation population, turns real failed conversations into Ada test cases, and checks a staged change against them before a person promotes it. Read-heavy; every write to Ada sits behind an explicit approval. Use for the Friday review, or mid-week with a cluster, playbook or topic to chase one thing.
user-invocable: true
argument-hint: '[--window START END | --cluster KEY | --playbook ID | --topic ID] [--no-pull]'
allowed-tools: Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/brief_state.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/pull_evidence.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/triage_evidence.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/trend_evidence.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/targets_evidence.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/forensics_evidence.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/followthrough_evidence.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/judge_evidence.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/approval_gate.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/ledger.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/changeset_inspect.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/sim_harness.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/loop_status.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/tests/run_tests.py *), Bash(python3 ~/repos/ada-tablo-ops/scripts/pull_coaching_metrics.py *), Bash(ls *), Bash(mkdir -p *), Read, Grep, Glob, Edit(/Users/181085/Obsidian/Projects/Ada-Evidence-Loop/FINDINGS.md), AskUserQuestion, Skill
---

# Ada Evidence Loop (Tablo)

One weekly run. Steps 1 to 5.8 measure and decide; step 6 verifies a change someone has already
staged; a person promotes it. Every stage is built. `sim_harness.py promote` stops at a stub by
design.

**How to talk during the run.** Every script prints one JSON result (`--format json`). Read it,
then say two sentences: what happened, and what this run does next. One number with its
denominator when it matters. No entity IDs unless David must paste one; no statistics words.
Every question to David goes through `AskUserQuestion`: up to 4 questions per call, 2 to 4
options each, the recommended option first and marked (Recommended). Where his own words are
recorded, the options include your recommended draft, and his free-text answer through "Other"
is what gets recorded, verbatim. Anything noticed that is not this step's output and meets the
findings rule (measured harm or a broken check; the rule in full at Step 8) is a finding, filed in
`~/Obsidian/Projects/Ada-Evidence-Loop/FINDINGS.md` at step 8; everything else stays in the step's
report. No recommendation, no investigation.

**Why each rule exists** is in `REFERENCE.md` beside this file, by step. Read a section only
when a step's output surprises you. Do not narrate it.

**Writes.** Never `edit_agent_behavior` or `edit_agent_config`. The only Ada writes are test-case
and test-run creation through `sim_harness.py`. When a person must decide it returns
`approval_required` with a token and an `on_yes` command: run `on_yes` verbatim, never build a
token. Batches of 100 runs or fewer (30 for a voice batch) start without asking (David,
2026-09-15); larger batches and any test-case creation ask first. `sim_admin.py` deletes and this skill never calls it. Staging,
promotion and rollouts each need David's yes in the moment and none runs from this skill: a stage
is a `work` session's `scripts/stage_*.py` run, a promote or rollout is `weekly-playbook-analysis`
Step 9.

**Model calls** run through `claude -p` on David's subscription. There is no API key.

**Status page.** `loop_status.py` keeps a browser page in step with the run so David can see the
phase without reading the output. Step 0 starts it. At the start of every step, before its first
command, run `python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/loop_status.py step <ID>` (IDs: 0 1 2 3 3b 4 4b 4c 5 5.5 5.6 5.7 5.8 5.9 6 6a 6b 6c 6d 7 8).
Just before any question to David, run `loop_status.py wait <ID> "<the ask in a few plain
words>"`, then ask it with `AskUserQuestion`; the next `step` clears it. After a step's result, `loop_status.py note <ID> "<one-line
result>"` is optional (a gate verdict, a batch size). These calls never block the run: if one
fails, say so in one line and carry on. The server stays up until it is stopped; step 0 restarts
it, and a status call after a stop starts it again. Do not otherwise mention the page.

**Skipping a step needs David's yes.** No step is skipped on your judgment, a targeted run's
steps and the Loop run reads (5.9, due every run) included. `loop_status.py skip <IDs> --reason
"<why>"` skips nothing: it returns `approval_required` with `ask_first` and `on_yes`. Run
`ask_first` (it puts `Skip <IDs>? <reason>` on the page), ask David with `AskUserQuestion`, and run `on_yes`
verbatim only on his yes in the moment, with his words in place of `<David's words>`. If he says
no, run the steps. `step`, `wait` and `done` refuse (`status: refused`, exit 4) while an earlier
step has neither run nor an approved skip. A refusal is a stop, unlike a failed call: stop the
run, ask David with `AskUserQuestion` whether to run or skip the steps it names, and never work around it.

## Step 0: Preflight

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/loop_status.py start
```

It opens the status page in the browser. A targeted run declares its plan here, every step it
will not run in one call: `loop_status.py start --mode targeted --skip <IDs> --reason "<why>"`.
That returns one `approval_required` for the whole plan; ask David once, as under Status page,
before step 1. A step outside the plan runs, or gets its own yes. Then invoke
`Skill: preflight`. It pulls the repo, checks credentials, and runs the weekly platform
contract check unless it passed in the last 7 days (a failed check reruns every time). If the contract check FAILS, show the failing group's WHAT BROKE /
INVALIDATES / DO lines and ask with `AskUserQuestion` whether to continue. Then read
`~/Obsidian/Projects/Ada-Evidence-Loop/TODO.md` and say in one line how many work items are open,
whether a P0 is open, which one is Now, and how many lines are under `## Loop run reads`. Read
those lines now: step 5.9 does the reads, and a line that changes how a step runs (for example
F238's, which sends step 5.7 to `--no-close`) applies at that step.

## Step 1: Where are we

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/brief_state.py --no-close
```

Say: last run date, how many clusters moved more than chance explains, which predictions are
due this run and which would close and how, and what was promoted since last time. If the
seasonal banner is set, say so. `--no-close` previews; step 5.7 closes.

## Step 2: This week's conversations

Targeted mode (`--cluster`, `--playbook`, `--topic`): skip the pull if an artifact covers the
window, run `run_tests.py --playbook/--topic`, and go to step 3 for that one target.

Weekly mode: run the pull for the most recent complete Monday to Sunday week every time, before
triage. When its artifact already exists under `~/.ada-evidence/tablo/`, the pull does not
fetch the week again; it re-reads the conversations Ada had not classified yet and replaces
each one that is classified now (F311). Say how many it re-read and how many are now classified.

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/pull_evidence.py --instance tablo --start-date <MON> --end-date <SUN>
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/triage_evidence.py --instance tablo
```

Say: conversations read, and the top three failure clusters with their channel and share of that
channel's non-escalated conversations. Keep the artifact path; step 5 needs it.

## Step 3: Is this new

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/trend_evidence.py mix
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/trend_evidence.py series --kind <KIND> --platform <CHANNEL>
```

`series` has no single-cluster flag. `<KIND>` and `<CHANNEL>` are the first two parts of the
cluster key (`kind|channel|...`); it prints the top 8 clusters of that kind on that channel, so
raise `--top` if the chosen cluster is not among them.

Say, one sentence each: whether the week's change is mostly who escalates, how often Ada
resolves, or channel mix; and whether the chosen cluster is a step change or a slow slide.

## Step 3b: What is coaching doing

```bash
python3 ~/repos/ada-tablo-ops/scripts/pull_coaching_metrics.py --days 7
```

Ada's own per-rule volume and resolution rate through its coaching filter; it rewrites
`reference/coaching_ids.md`. This is the one coaching measurement: `coaching-review` reads these
figures and pulls none of its own. Say: how many rules were active, the top three by volume
with their resolution rate, and any rule over 10 a week resolving under 10%. A handoff rule
resolves 0% by definition and is not a finding. The script measures only the rules the file
lists and finds no new ones, so a rule missing from `coaching_ids.md` is invisible here: say how
many rules the file tracks, and say the list may be incomplete. Finding
missing rules is `reconcile_coaching_ids.py` (read-only without `--write`), outside the run. Do not
propose a coaching edit here.

## Step 4: Why

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/forensics_evidence.py --cluster-key "<KEY>" --window <MON> <SUN> --per-cluster 20
```

Describes what ran, which asks went unanswered, which actions failed, which variables were set,
and writes a labelling sheet under `~/.ada-evidence/tablo/sim/labels/`. It describes and never
says why; repeat no cause claim as established. The labeller of record is the code rule: Ada
sent the identical message twice in a row. `--llm-label` is a measurement tool, not part of the
run. `--cluster-key` can be repeated to pool a `customer_text` cohort split by channel.

### Step 4b: What a person did next (optional, one cluster)

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/followthrough_evidence.py --cluster-key "<KEY>" --window <MON> <SUN> --max-conversations 20 --max-gets 60
```

Zendesk, read-only, capped. Ask before raising `--max-gets`. To leave 4b out, ask David first:
`loop_status.py skip 4b --reason "<why>"`, then its `ask_first` and, on his yes, its `on_yes`. Add
`--excerpts` only if David asks
to read the notes. Say: how many sampled conversations became a ticket, and on how many a person
wrote something.

### Step 4c: One target, one question, read it

The only step that asks David to decide mid-run. He approves the question once, for one target,
and never approves answers one conversation at a time.

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/targets_evidence.py --artifact ~/.ada-evidence/tablo/triage_<MON>_<SUN>.json --run-date <TODAY>
```

No Ada call and no model call; nothing is spent here. Say the shortlist in plain words: what each target is, how many conversations there are to read,
which way it moved, and which one you recommend and why. Coaching targets rank on Ada's figures;
say how many rules could not be matched to this week's conversations. Every target carries
`reaches_gate`: stage 5 ranks only playbook failures, ended-unresolved reasons and playbook
escalations, so a reading of a coaching, topic or intent target cannot be approved at step 5.5.
Say which targets are like that before David picks; what such a reading shows is filed at step 8
when it meets the findings rule. Then draft one question in
David's terms, specific rather than broad ("did we ask for a serial when the problem was already
obvious?" rather than "what went wrong?"), and let him replace it. One `AskUserQuestion` call
covers both: the target, your recommended one first, and the question, your draft first; his own
wording through "Other" is what goes into `--question`, verbatim. Before sending it: `loop_status.py wait 4c "Approve or replace the
question"`.

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/forensics_evidence.py --cluster-key "<KEY>" --window <MON> <SUN> --per-cluster 60
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/forensics_evidence.py --cluster-review <SHEET> --question "<David's words, verbatim>"
```

Groups of 20, each read separately, never combined. Say per group: the answer, then each
statement with the conversations behind it, and how many statements are backed. A statement with
no conversation is marked and not repeated. A cited conversation outside the cluster is a
fabrication and taints the whole answer. A group that could not be read reports nothing.

Then read three or four cited conversations in full yourself and record what they showed. This
is a gate, not a suggestion: the command refuses an id that is not in the cluster or has no
transcript on disk; stage 5 prints NOT VERIFIED against every finding with no row, on both tables;
stage 5.5 refuses to approve one and its refusal prints this command. Reject and defer work
without it. A model may describe and cite; cause is yours to establish.

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/forensics_evidence.py --record-verification --cluster-key "<KEY>" --window <MON> <SUN> --conversation-ids <ID,ID,ID> --note "<what the transcripts showed>"
```

`--verified-by` defaults to `claude`; pass `--verified-by david` only for transcripts David opened
himself.

`--question-id <ID>` re-asks a question already on file in `reference/history/questions.jsonl`. It
refuses a sheet on a channel the question was not written for; ask that channel with `--question`.

## Step 5: What it ranks

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/judge_evidence.py --artifact ~/.ada-evidence/tablo/triage_<MON>_<SUN>.json --run-date <TODAY>
```

Always pass `--artifact`. Two tables: at most five findings ranked by conversation count with
movement as the tie-breaker, and
escalation findings scored against each channel's own handoff and resolution rate, ranked by how
many times off its channel a playbook is. Above them, one line per channel (context, never a
finding). Below them, where the handoffs sat by volume (where to work, never a ranking). Read
both tables out and stop. Both tables are decided at the same gate and both block on the same
missing transcript read. No cause claim, no config proposal.

## Step 5.5: David decides

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/approval_gate.py show --judgment <JUDGMENT JSON>
```

`AskUserQuestion`, one question per finding from both tables, 4 findings a call and several calls
when there are more: the finding in one or two lines, and approve, reject and defer as options
with the one you recommend first and why. For a recommended approve, that option carries your
drafted prediction: which way, to what number, in how many weeks. His free-text answer through
"Other", a prediction number included, is what gets recorded in `--note`, verbatim. Before the
first call: `loop_status.py wait 5.5 "Decide every finding, with a prediction for each
approve"`. Then,
per finding:

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/approval_gate.py decide --judgment <JSON> --finding <ID> --decision approved|rejected|deferred --note "<David's words>" --prediction '{"cluster_key":"<KEY>","metric":"pct","direction":"down","threshold":3.5,"horizon_weeks":4}'
```

That call writes nothing; it prints the `on yes` command with a token. Run it verbatim. Approval
is refused for a finding with no recorded transcript read this window (step 4c), on both tables;
the refusal prints the `--record-verification` command. Go and read; do not work around it.
Reject and defer are unaffected. A prediction on an escalation finding is refused; approve it without one.

## Step 5.6: Record the decisions

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/ledger.py import-approvals ~/.ada-evidence/tablo/stage-results/approvals_<TODAY>.jsonl --dry-run
```

Say what would be recorded and what skipped and why, then run it without `--dry-run`. David's
horizon is used as typed; if the tool says it may be too short to tell, say that in those words
and leave it. A prediction in conversations rather than percent is refused; ask for a percent.

## Step 5.7: Close what is due

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/brief_state.py
```

If a Loop run reads line says to preview only, run it with `--no-close` instead and say why in one
line. A decision is looked at once, from the date it was pre-registered for, and gets one of four
answers: it worked, it did not move, it got worse, not enough
evidence. Each names the change it was testing or says plainly that none was attached. When
other changes shipped in the same stretch, list them: an attached change is a candidate, never a
cause. A decision that needs more weeks stays open and says how many.

## Step 5.8: Which change each prediction tested

The same output prints WHICH CHANGE GOES WITH WHICH PREDICTION. `attached`: nothing to do.
`NEEDS YOU`: more than one open prediction on that cluster; ask David which with
`AskUserQuestion`, once. `changes nobody claimed` (promoted since the oldest open prediction and
attached to nothing): ask David with `AskUserQuestion`, once, whether any was meant to fix something he predicted.

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/ledger.py link <decision-id> --changeset <CHANGESET-ID> --by david --note "..."
```

Refuses a changeset that is not promoted. Appends a row, never edits. A conflict credits neither
change; report it, do not resolve it.

## Step 5.9: Loop run reads

Every line under `## Loop run reads` in TODO is due on every run, whatever the day. A line whose
date has passed or whose item is closed: say so in one line and skip it. Every other line: read
what it names from this week's pull and triage artifact, or read-only from Ada, and report it in
one or two sentences per item read, with numbers and denominators against the baseline the line
gives. Say "not measurable this run" and why when a read cannot be done; never skip one silently.
A read is a report. It is filed as a finding at step 8 only when it shows new measured harm or a
new broken check. Never edit TODO; a line that needs changing is asked of David with
`AskUserQuestion` at step 8.

Early reads: every changeset in step 1's CHANGES PROMOTED list that carries an `early read` label
(promoted on or after the window start, not reverted) gets one, whether or not a TODO line names
it. Nothing is checked before it has been live 72 hours inside the pulled window (Ada's guidance,
David 2026-09-25); `brief_state.py` counts the hours to the window's last day, not to now.
- `ready`: If the CHANGES PROMOTED line shows a `latest daily read` marked `(full)` and dated
  within the 7 days before this run, report that reading (its date, mode and headline lines) as
  the early read and do not recompute; say it came from changeset-inspect. Otherwise, including
  when the reading is partial or older (say its date in one clause): find what it edited
  (`list_agent_changesets`), and from this week's pulled conversations after its promotion time
  give engaged, resolved and escalated counts for each playbook or coaching rule it touched,
  against the same entity's week before. Say "early read, not a verdict".
- `wait`: say it had N of 72 hours live in the data and is read next run. A Loop run reads line
  about the same change waits too.
- An active rollout listed under CHANGES PROMOTED: report its latest daily read if one exists,
  otherwise one line, "no reading yet".

The 72 hours governs early reads only. When a decision closes is the ledger's horizon and
settling rule, unchanged.

## Step 6: Prove it before it ships

Needs a changeset in `testing` status: David gives its id, or list them with
`list_agent_changesets`. Before 6b, its staged body has a `config-health` pass with no P0
(`Skill: config-health --changeset <ID>`, the one place every caller gates); if none is on record
this session, run it, and a P0 stops step 6 here. Asking for it: `loop_status.py wait 6 "Name the changeset in testing"`,
then `AskUserQuestion` with the testing changesets as options.
When nothing is in testing, `loop_status.py skip 6 6a 6b 6c 6d --reason "nothing in testing"`,
ask David with `AskUserQuestion`, and on his yes run its `on_yes` and go to step 7.

**6a. Real failures to test drafts.**

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/sim_harness.py convert --cluster-key "<KEY>" --limit 10
```

5 to 10 cases on a cluster of 100+, one per distinct failure mode. Show the drafts path and the
first two drafts' opening message and criteria. Ask once with `AskUserQuestion`: "Create these N test cases in Ada?",
after `loop_status.py wait 6a "Create N test cases in Ada?"`.

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/sim_harness.py --format json convert --create <DRAFTS>
```

Run the `on_yes` command it returns.

**6b. Run on live and on the change, three times each.**

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/sim_harness.py run --cases-file <DRAFTS>.applied.jsonl --changeset <ID> --reps 3
```

Size the batch before you start it. Voice runs are real simulated calls of several minutes, and
Ada runs about 10 at a time with the rest queued (F102), so 160 voice runs take about two hours.
- 3 reps, not 5. Queued runs finish: 0 of 70 were cut off in a queued batch, against about 40% when
  runs started all at once (F89).
- Cases already measured on live (a calibration floor, or a case from an earlier batch on the same
  live body) run on the change only: add `--changeset-only`. Only new cases need the live arm.
- Top up only a case with fewer than 3 complete runs, and pool complete runs by test case id.
- Voice cases that carry a `bench` spec are scored on the playbook window, not by Ada's judge.
- **Failures first.** When the change answers known failing cases, the first batch is only those
  cases, 3 reps, `--changeset-only`. The regression batch (every other case for the playbook) runs
  only after the first batch clears, never in the same batch and never before it.
- **Voice ceiling: 30 runs a batch.** That is three rounds of 10 concurrent calls, under an hour.
  Above 30 a voice batch returns `approval_required` exactly like a batch above 100 runs and does
  not start without David's confirm token: ask David with `AskUserQuestion`, the number in the question, and run the `on_yes` command
  only on his yes in the moment. State the batch size (cases x reps x arms) before every start.

**6c. Read and gate.**

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/sim_harness.py compare --batch <BATCH> --wait
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/sim_harness.py gate --batch <BATCH> --prediction '{"cluster_key":"<KEY>","metric":"pct","direction":"down","threshold":3.5,"horizon_weeks":4}'
```

The bar is per batch: GO when every case in this batch passes on every run, or when at least one
case passes on every run and every remaining failure has a written reason. A run with no spoken
lines in the playbook window, or whose `action_executed` result failed or was throttled (429), is
`no_evidence`: it does not count toward "passed every run", the gate prints how many it excluded
per arm, and a case with fewer than 2 evidence-bearing runs on an arm is inconclusive and blocks
GO. For a voice change the bar is outcome criteria plus assertions only. A gate
case's `judge_criteria` say what the caller ends up with (the serial captured, the offer asked
before a transfer, no troubleshooting step given). Wording and repeat rules ("same thing twice",
"never asks in the same words", "stops asking for the serial") never sit in a gate case's
`judge_criteria`: live fails them at the same rate as the change (F119), repeats do not separate
outcomes on real calls (F120), and the window judge reads a spell-back confirmation as a re-ask
(F121). They are reported by `compare` (Ada's own judge per run as `ada_did_pass`, and the judge
quotes) and read as findings; they never decide the gate. A case that carries one is rewritten
before its batch runs. A failures-first batch that clears earns the regression batch; a regression
batch that clears earns the promotion question. On NO-GO, run `sim_harness.py reasons --batch <BATCH>`,
collect one reason per failing case from David (`AskUserQuestion`, your drafted reason first, his
own through "Other"), and stop: the next step is a fix and one more
failures-first batch, not more runs on the same change. The gate also records which changeset
and which clusters the batch tested. Record the verdict: `loop_status.py note 6c "gate GO 9 of 9"`
(or NO-GO with its count).

**6d. Promotion.** `sim_harness.py promote` is a stub and sends nothing. Show its summary and
ask with `AskUserQuestion`: "Promoting is your call and it happens outside this loop." Before saying it:
`loop_status.py wait 6d "Promote outside the loop, or not"`. If David wants to promote, hand
off to `weekly-playbook-analysis` Step 9. Do not offer to enable the promote call. Before David
promotes or starts a rollout, draft the deploy note, show it to him, ask with `AskUserQuestion` and write it on his yes (see
the changeset-inspect skill, Deploy notes). No note, no promote.

## Step 7: Audit the bench (occasional)

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/sim_harness.py audit
```

Say keep, rewrite and retire counts and the report path. To leave the audit out this week, ask
David with `AskUserQuestion`: `loop_status.py skip 7 --reason "<why>"`, its `ask_first`, and its `on_yes` on his yes.

## Step 8: Record and stop

1. Append every finding from this run to `~/Obsidian/Projects/Ada-Evidence-Loop/FINDINGS.md`.
   A finding is filed only when it names measured harm (a count, a rate, named conversations) or a
   broken check (a test, a gate, a script or skill step that gives a wrong answer). Anything else
   stays in the worker's report and goes nowhere. Every finding is one line carrying: the date,
   `[loop]` or `[ada]`, what is wrong, where (entity ID, file and line, or run ID), the evidence
   pointer, what correct looks like, and a priority P0 to P3 by the definitions in TODO under
   Priority levels, as `(open, P2)`. Enough that a reader can act without re-reading the transcript.
   The ID is the next one, one past the highest in FINDINGS or `notes/FINDINGS-closed.md`. A P0 or
   P1 line goes at the bottom of the P0 and P1 section, a P2 or P3 line at the bottom of Open; say
   a P0 to David in one line. A finding a W item owns carries `(work: W#)` with no P tag, since it
   takes the W's priority. No recommendation.
2. Full audit of FINDINGS and TODO (Friday runs only), by one sub-agent: read FINDINGS.md,
   `notes/FINDINGS-closed.md`, TODO.md, HISTORY.md and `notes/falsified.md` in full; propose closes
   (only on evidence in the files: a fix in HISTORY, a later finding, falsified, or out of scope by
   a standing rule), merges (oldest ID survives, the rest move to closed with the status
   `(merged: F##, YYYY-MM-DD)`), and the W item each open finding belongs to, keeping `## Open`
   at 10 or fewer with the rest in `## Queued`. Nothing is applied yet. Ask David with `AskUserQuestion` whether to apply it (the
   counts in the question: closes, merges, new and extended W items), apply on his yes, then run
   `workspace/doc_hygiene.py` without `--fix` (F451) and fix what it flags.
3. Invoke `Skill: commit-results` with args `evidence`.
4. Run `loop_status.py done "Run complete. N decisions recorded, M findings added, nothing
   pending."` with the real counts. It refuses while any step has neither run nor a skip David
   approved; then stop and ask him with `AskUserQuestion` about the steps it names, and run `done` again after. Once it
   succeeds, say exactly that line and stop. That message has no next action and no offer.

## Settled (David, 2026-09-22)

- D3: promotion stays manual, through `weekly-playbook-analysis` Step 9; the live promote call is not enabled.
- D4: a failing test case may be waived with a written reason; the bar is not a hard 100%.
- D5: a decision whose evidence is not decisive at its horizon closes itself as "not enough evidence".
- D7: voice test runs simulate the conversation (F48); there is no audio, so speech recognition, barge-in and keypad input are not tested.
