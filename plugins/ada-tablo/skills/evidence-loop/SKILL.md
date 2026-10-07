---
name: evidence-loop
description: Weekly evidence loop for the Tablo Ada instance. Shows where Ada got worse this week from the whole conversation population, turns real failed conversations into Ada test cases, and checks a staged change against them before a person promotes it. Read-heavy; every write to Ada sits behind an explicit approval. Use for the Friday review, or mid-week with a cluster, playbook or topic to chase one thing.
user-invocable: true
argument-hint: '[--window START END | --cluster KEY | --playbook ID | --topic ID] [--no-pull]'
allowed-tools: Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/brief_state.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/pull_evidence.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/triage_evidence.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/trend_evidence.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/targets_evidence.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/forensics_evidence.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/followthrough_evidence.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/finding_dupes.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/judge_evidence.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/approval_gate.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/ledger.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/changeset_inspect.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/sim_harness.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/loop_status.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/registry.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/tests/run_tests.py *), Bash(python3 ~/repos/ada-tablo-ops/scripts/pull_coaching_metrics.py *), Bash(ls *), Bash(mkdir -p *), Read, Grep, Glob, Edit(/Users/181085/Obsidian/Projects/Ada-Evidence-Loop/FINDINGS.md), AskUserQuestion, Skill
---

# Ada Evidence Loop (Tablo)

One weekly run. Step 2b reads last week's changes first; steps 3 to 5.6 measure and decide; step 6
verifies a change someone has already staged; a person promotes it. Every stage is built.
`sim_harness.py promote` stops at a stub by design.

**How to talk during the run.** Every script prints one JSON result (`--format json`). Read it,
then say two sentences: what happened, and what this run does next. One number with its
denominator when it matters. No entity IDs unless David must paste one; no statistics words.
Every W, D or F ID you say or put in a question carries its title from the registry, "W47
(Password Reset Fix)", and a changeset is said by its title ("CSAT Happy Paths"); `python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/registry.py
show <ID>` prints both. Every question to David goes through `AskUserQuestion`: up to 4 questions per call, 2 to 4
options each, the recommended option first and marked (Recommended). Where his own words are
recorded, the options include your recommended draft, and his free-text answer through "Other"
is what gets recorded, verbatim. Anything noticed that is not this step's output and meets the
findings rule (measured harm or a broken check; the rule in full at Step 8) is a finding, filed in
`~/Obsidian/Projects/Ada-Evidence-Loop/FINDINGS.md` at step 8; everything else stays in the step's
report. No recommendation, no investigation. Every line David reads follows the message contract:
the work item with its title first, then what the customer gets, then what was checked and found
in words a support manager uses, then the one next action, with batch and changeset IDs on a last
`ref:` line. Never "arm", "pool", "waive", "gate", a rule name or a finding number without its
one-line meaning. A question's text follows the same order and fits in four sentences.

**Why each rule exists** is in `REFERENCE.md` beside this file, by step. Read a section only
when a step's output surprises you. Do not narrate it.

**Writes.** Never `edit_agent_behavior` or `edit_agent_config`. The only Ada writes are test-case
and test-run creation through `sim_harness.py`. When a person must decide it returns
`approval_required` with a token and an `on_yes` command: run `on_yes` verbatim, never build a
token. Batches of 100 runs or fewer (30 for a voice batch) start without asking (David,
2026-09-15); larger batches and any test-case creation ask first. `sim_admin.py` deletes and this skill never calls it. Staging,
promotion and rollouts each need David's yes in the moment and none runs from this skill: a stage
is a `work` session's `scripts/stage_playbook.py` run, a promote or rollout is `weekly-playbook-analysis`
Step 9.

**Model calls** run through `claude -p` on David's subscription. There is no API key.

**Status page.** `loop_status.py` keeps a browser page in step with the run so David can see the
phase without reading the output. Step 0 starts it. At the start of every step, before its first
command, run `python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/loop_status.py step <ID>` (IDs: 0 1 2 2b 3 3b 4c 4d 5 5.5 5.6 6 6a 6b 6c 6d 7 8).
Just before any question to David, run `loop_status.py wait <ID> "<the ask in a few plain
words>"`, then ask it with `AskUserQuestion`; the next `step` clears it. The project's
`AskUserQuestion` hook (`loop_status.py ask-hook`) also records a wait on the current step with the
question's first 80 characters, so a question you forgot to announce still shows; the explicit
`wait` stays, since its words are shorter. After a step's result, `loop_status.py note <ID> "<one-line
result>"` is optional (a gate verdict, a batch size).

Run every status command as its own Bash call: never chained with `&&` or `;`, never piped, never
redirected to `/dev/null`, so its exit code and its JSON are the call's own. Read the exit code
every time: 0 is done; 3 is `approval_required` (a skip request: follow its `ask_first`); 4 is
`refused` (see below, a stop). Any other failure does not block the run: say so in one line and
carry on. The server stays up until it is stopped; step 0 restarts
it, and a status call after a stop starts it again. Do not otherwise mention the page.

**Skipping a step needs David's yes.** No step is skipped on your judgment, a targeted run's
steps and last week's changes (2b, due every run) included. `loop_status.py skip <IDs> --reason
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
those lines now: step 2b does the reads, and a line that changes how a step runs (for example
F238's, which sends step 2b's close to `--no-close`) applies at that step.

## Step 1: Where are we

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/brief_state.py --no-close
```

Say: last run date, how many clusters moved more than chance explains, which predictions are
due this run and which would close and how, and what was promoted since last time. If the
seasonal banner is set, say so. `--no-close` previews; step 2b closes. Also say the CHANGESET
SCOREBOARD SUM line with its interval, and how many open decisions lack a resolved-a-week
prediction.

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

## Step 2b: Last week's changes

Runs right after the pull, before anything this week is ranked or approved. Four parts, in order.

**Close what is due.**

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/brief_state.py
```

If a Loop run reads line says to preview only, run it with `--no-close` instead and say why in one
line. A decision is looked at from its earliest look (the typed horizon, one week by default) and
gets one of four answers: it worked, it did not move, it got worse, not enough evidence. Two
readings are said in these words: "moved, short of target" (the number moved the predicted way by
more than chance and stopped short of the target) and "reached, underpowered" (the number is at or
past the target, but the data cannot yet tell it from chance). Each names the change it was testing
or says plainly that none was attached. When other changes shipped in the same stretch, list them:
an attached change is a candidate, never a cause. A decision that needs more weeks stays open and
says how many; its verdict date is when the data should have enough conversations to see the change.

The same output prints WHICH CHANGE GOES WITH WHICH PREDICTION. `attached`: nothing to do.
`NEEDS YOU`: more than one open prediction on that cluster; ask David which with
`AskUserQuestion`, once. `changes nobody claimed` (promoted since the oldest open prediction and
attached to nothing): ask David with `AskUserQuestion`, once, whether any was meant to fix
something he predicted.

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/ledger.py link <decision-id> --changeset <CHANGESET-ID> --by david --note "..."
```

Refuses a changeset that is not promoted. Appends a row, never edits. A conflict credits neither
change; report it, do not resolve it.

**Read every live change from the pull.**

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/changeset_inspect.py --from-pull ~/.ada-evidence/tablo/conversations_<MON>_<SUN>.jsonl --out-dir ~/.ada-evidence/tablo/stage-results
```

No Ada call. The live set is the newest readings file (the `read` that step 0 starts in the
background); the counts are this week's pull. A rollout is its change arm against its control, split
by the export's `changeset_id`; a promotion is what it touched before against after it went live,
less the rest of the channel. Every cell carries one label: on track, behind, regressing, too early
or no goal. Say per changeset one line: its cells with numbers and denominators, and the label.
Email in a week that ended under 72 hours ago is shown and labelled too early, never scored (F615).
A cell with "the after window also holds" names the other changes on the same entity: say them.
"early read, not a verdict".

**Loop run reads.** Every line under `## Loop run reads` in TODO is due on every run, whatever the
day. A line whose date has passed or whose item is closed: say so in one line and skip it. Every
other line: read what it names from this week's pull and triage artifact, the cells above, or
read-only from Ada, and report it in one or two sentences per item read, with numbers and
denominators against the baseline the line gives. Say "not measurable this run" and why when a read
cannot be done; never skip one silently. A read is a report. It is filed as a finding at step 8 only
when it shows new measured harm or a new broken check. Never edit TODO; a line that needs changing
is asked of David with `AskUserQuestion` at step 8. Report step 1's CHANGESET SCOREBOARD as printed,
without recomputing it, and say "early read, not a verdict".

**Ask the open rollout decisions, before any new approval.** For every active rollout with an open
decision, and for every `regressing` line, ask David now with one `AskUserQuestion` call (before it:
`loop_status.py wait 2b "Decide the rollouts"`): the change in one line, the cell's numbers and
label, and the options (keep the rollout running, stop it, or widen it), your recommendation first.
His answer is a decision he makes outside this loop (`weekly-playbook-analysis` Step 9 for a rollout
change); record his words. Once a rollout has ended (promoted or stopped), end its registry row, so
`registry.py ready` stops holding that channel, one call per entity it names:
`python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/registry.py link <CHANGESET-ID> <ENTITY-ID> --relation rollout_on --channel <CHANNEL> --remove --by david`. While a rollout on a channel is `regressing` and David has not decided it,
no new prediction goes on that channel: `approval_gate.py decide` refuses one there and asks for
`--rollout-decided "<David's words>"`. A `regressing` line also takes target slot 1 at step 4c with
its drafted question.

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

## Step 4c: Up to three targets, one question each

The only step that asks David to decide mid-run. He approves one question per target, for up to
3 targets, and never approves answers one conversation at a time. Targeted mode reads its one
target the same way.

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/targets_evidence.py --artifact ~/.ada-evidence/tablo/triage_<MON>_<SUN>.json --run-date <TODAY>
```

No Ada call and no model call; nothing is spent here. It reads step 2b's
`changes_<MON>_<SUN>.json` from stage-results: a `regressing` line takes the first slot (rollouts
first, then the largest loss) with a `drafted_question`, and is read like any target; it is decided
as its change's question at step 2b, never at step 5.5. The first 3 on the shortlist
(`read_at_4c: true`) are this week's reads; the rest are there to swap in. Say the shortlist in
plain words: what each target is, how many conversations there are to read, and which way it
moved. Topics, intents and playbooks rank on resolutions lost: this week's conversations times
the drop from the 12 weeks before, with the 4-week figure, the range and how much of it is
channel mix. Say the mix part: a drop that is mostly mix means more of the topic arrived by
voice, where Ada resolves less, while each channel held its own rate. Coaching targets rank on
Ada's figures; say how many rules could not be matched to this week's conversations. Every
target carries `reaches_gate`: stage 5 ranks playbook failures and ended-unresolved reasons by
count, gives a slot ahead of them to any playbook, reason, topic or intent target whose
transcripts you read here, and scores playbook escalations separately, so only a reading of a
coaching target cannot be approved at step 5.5. Say which targets are like that before David
approves; what such a reading shows is filed at step 8 when it meets the findings rule. Nothing
checks whether two of the 3 are the same conversations, such as a topic and one of its own
intents.

Then draft one question per target in David's terms, specific rather than broad ("did we ask
for a serial when the problem was already obvious?" rather than "what went wrong?"), and
written so each conversation answers it yes or no on its own: the reader returns one answer per
conversation, not one for the group. For a regression target, start from its `drafted_question`,
which is already in that form. One
`AskUserQuestion` call holds all of them, one question per target: the target in a line, your
drafted question, and two options, approve the question (Recommended) and skip this target. His
own wording through "Other" is what goes into `--question` for that target, verbatim. A skipped
target is not read. Before sending it: `loop_status.py wait 4c "Approve or replace up to 3
questions"`.

## Step 4d: Read and verify each target

Steps 4 (a 20-conversation read of one cluster) and 4b (what a person did next) were folded in
here on 2026-10-05 (W89): the reading below covers what step 4 read, and the Zendesk read is part
of a target that hands off.

Read each approved target on its own, one after the other, with its own sheet, its own
answer and its own recorded reading. Never pool two targets on one sheet. `<KEY>` is repeated
for each of the target's cluster keys, as in its `read_it_with`.

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/forensics_evidence.py --cluster-key "<KEY>" --window <MON> <SUN>
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/forensics_evidence.py --cluster-review <SHEET> --question "<David's words, verbatim>"
```

The sheet describes what ran, which asks went unanswered, which actions failed and which variables
were set; it describes and never says why. The labeller of record is the code rule: Ada sent the
identical message twice in a row. `--llm-label` is a measurement tool, not part of the run.

The sheet holds every conversation of a channel cluster under 150, else 120 of them; the fetch
cap is that sample, so a target no longer shares 60 fetches across its channels. The question
is asked of each conversation on its own, in groups of 10, and each conversation is read twice
in two different groups. Say per target: how many conversations got the same answer both
times (the agreement), then per channel cluster the agreed answers (yes, no, cannot tell, does
not apply). A row whose quote is not words from that conversation is marked unsupported; say
how many. Nothing combines the rows except code counting them.

Then, for each target, read in full every conversation on the "Read these in full" list (every
disagreement and 2 agreeing ones at random) and record what they showed. This is a gate, not a
suggestion: the command refuses an id that is not in the cluster or has no transcript on disk,
and refuses a reading that names none of that cluster's disagreements; stage 5 prints NOT
VERIFIED against every finding with no row, on both tables; stage 5.5 refuses to approve one and
its refusal prints this command.
Reject and defer work without it. A model may describe and cite; cause is yours to establish.
A reading is recorded against one cluster: the channel cluster the transcripts came from. Each
recorded cluster is its own finding at step 5 and its own ledger row if David approves it.

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/forensics_evidence.py --record-verification --cluster-key "<KEY>" --window <MON> <SUN> --conversation-ids <ID,ID,ID> --note "<what the transcripts showed>"
```

`--verified-by` defaults to `claude`; pass `--verified-by david` only for transcripts David opened
himself.

For a target whose conversations hand off, read what the human agent did next (Zendesk,
read-only, capped; ask before raising `--max-gets`; `--excerpts` only if David asks to read the
notes). Say how many sampled conversations became a ticket, and on how many a person wrote
something. It is optional and never needs a skip.

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/followthrough_evidence.py --cluster-key "<KEY>" --window <MON> <SUN> --max-conversations 20 --max-gets 60
```

`--question-id <ID>` re-asks a question already on file in `reference/history/questions.jsonl`. It
refuses a sheet on a channel the question was not written for; ask that channel with `--question`.

## Step 5: What it ranks

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/judge_evidence.py --artifact ~/.ada-evidence/tablo/triage_<MON>_<SUN>.json --run-date <TODAY>
```

Always pass `--artifact`. Two tables: at most five findings ranked by conversation count with
movement as the tie-breaker, each cluster read at step 4d taking a slot ahead of them, and
escalation findings scored against each channel's own handoff and resolution rate, ranked by how
many times off its channel a playbook is. Above them, one line per channel (context, never a
finding). Below them, where the handoffs sat by volume (where to work, never a ranking). Read
both tables out and stop. Both tables are decided at the same gate and both block on the same
missing transcript read. No cause claim, no config proposal.

## Step 5.5: David decides

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/approval_gate.py show --judgment <JUDGMENT JSON>
```

`AskUserQuestion`, one question per finding from both tables, every target read at step 4d
among them, 4 findings a call and several calls when there are more. Each question leads with one
goal block, from the page's `goal` for that finding: the goal in resolved conversations a week, the
loss it recovers, the earliest look and the verdict date, and how many weeks the data needs to see
a change that size. The options are the page's two goal options (`goal.options`: the whole loss back
and half of it, or the smallest goals one week and four weeks of data can see), each an approve with
its goal, then reject and defer, the one you recommend first and why. No separate resolved-a-week
question is asked. Each approve creates or extends a W item with that goal: the question names it,
"extends W62 (Chat Connectivity Fix)" when an open W item already works that playbook, rule or topic
(`python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/registry.py show` lists them with their links), else "new W item, <2 to 3 word title>" with
the next free ID (one past the highest W in TODO, HISTORY or the registry). His free-text answer
through "Other", a goal number included, is what gets recorded in `--note`, verbatim. Before the first call: `loop_status.py wait 5.5 "Decide every
finding, with a goal for each approve"`. Then, per finding, with the chosen option's `prediction`
JSON passed as it stands:

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/approval_gate.py decide --judgment <JSON> --finding <ID> --decision approved|rejected|deferred --note "<David's words>" --prediction '{"cluster_key":"<KEY>","metric":"pct","direction":"down","threshold":3.5,"horizon_weeks":1}' --item <W#>

That call writes nothing; it prints the `on yes` command with a token and its `question` carries
the goal block for the prediction given. Run `on yes` verbatim. Approval is refused for a finding
with no recorded transcript read this window (step 4d), on both tables; the refusal prints the
`--record-verification` command. Go and read; do not work around it. Reject and defer are
unaffected. A prediction on an escalation finding is refused; approve it without one. A prediction
on a cluster that does not translate into resolved conversations needs `goal_resolved_per_week`
(David's goal) in its JSON. A prediction on a channel whose rollout step 2b found regressing is
refused until David has decided that rollout; pass his words with `--rollout-decided`.

## Step 5.6: Record the decisions

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/ledger.py import-approvals ~/.ada-evidence/tablo/stage-results/approvals_<TODAY>.jsonl --dry-run
```

Say what would be recorded and what skipped and why, then run it without `--dry-run`. Per
decision say its goal in resolved conversations a week, its earliest look and its verdict date. The
horizon typed (1 week by default, W85) is the earliest look; the verdict date is the weeks the data
needs to see the predicted change (David, 2026-10-05). When the tool says no number of weeks can see
it, say that in those words and leave it. A prediction in conversations rather than percent is
refused; ask for a percent. Every imported decision carries its goal and a resolved-a-week row; an
approval on a cluster that does not translate and carries no goal is skipped with that reason:
decide it again at step 5.5 with a goal option.

## Step 6: Reach check, then launch

Needs a changeset in `testing` status. Its staged body has a `config-health` pass with no P0
(`Skill: config-health --changeset <ID>`); a P0 stops step 6 here. Asking for the changeset:
`loop_status.py wait 6 "Name the changeset in testing"`, then `AskUserQuestion` with the testing
changesets as options, each named by its work item and title (`registry.py show`).
When nothing is in testing, `loop_status.py skip 6 6a 6b 6c 6d --reason "nothing in testing"`,
ask David with `AskUserQuestion`, and on his yes run its `on_yes` and go to step 7.

A simulation here answers one question: does Ada reach the changed steps and say the new words.
It never decides on a pass rate. Live Ada is measured in production, by the 72-hour read, so
there is no live arm, no 3-rep gate, no reasons file, no waiver, no top-up and no separate
regression batch. The old gate (`sim_harness.py gate`) is kept for one exception: a change that
removes a handoff or an exit, where David asks for it.

**6a. Cases.** One case per behaviour the change fixes, built from the real conversations the
work item names (`sim_harness.py convert`, or the drafts the authoring step proposed). 3 to 8
cases. Show the opening line and the one thing each case checks. When a `work` session's stage
question already listed these cases and David said yes, create them on that yes: run the `on_yes`
the converter returns with no second question. Otherwise ask once with `AskUserQuestion` (after
`loop_status.py wait 6a "Create N test cases in Ada?"`): "Create these N test cases in Ada?".

**6b. Reach run.** One rep per case, on the change only, creates paced one every 90 seconds
(the default):

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/sim_harness.py run --cases-file <DRAFTS>.applied.jsonl --changeset <ID> --changeset-only --reps 1 --note "<what the customer gets, one clause>"
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/sim_harness.py compare --batch <BATCH> --wait
```

Say the size before it starts: "N test conversations, about N x 1.5 minutes to create, then the
calls themselves." Start the run in the background and wait for it to finish: 8 paced creates
take over 10 minutes, past a foreground command's ceiling, and a run killed partway leaves cases
uncreated. A batch over 30 voice runs needs David's confirm token, as before.

**6c. Read.** `compare` prints which cases reached the change. For every case that reached it,
read the transcript of that run (the test-run read the harness already caches) and check the new
words were said and the step did what the work item says. For a case that did not reach it, the
case's opening or the step it should reach is wrong: fix the case, or restage with one or two
changes (rule R15), and run 6b again for those cases only.
Record `loop_status.py note 6c "reach N of M, words held on N"`.

**6d. Launch.** Draft the deploy note (changeset-inspect skill, Deploy notes) and a prediction
(cluster, metric, direction, threshold, horizon 1 week). Read the slots from Ada itself:
`list_agent_changesets(status="testing")`, and every changeset whose `rollout.status` is `active`
holds a slot on its playbooks' channel; name each one by its work item (`registry.py show`). Ada
allows 100% in total, so two 50% rollouts at once. Then `loop_status.py wait 6d
"Launch, and how"` and one `AskUserQuestion` with these options, recommended first:
- **50% rollout, capped** when this channel's slot is free: names the cap (600 voice, 1,000
  chat) and that the 72-hour read decides promote or stop.
- **Promote at 100%** when the slot is taken and the change is a small chat fix (one or two
  steps, chat only): names that `revert` is the way back and the read is before against after.
- **Wait for a slot** when this channel's slot is taken and the change is voice or a rewrite:
  names the changeset holding the slot, its work item, and when its 72-hour read is due.
- **Hold.**
The note is written on his yes, then the hand-off to `weekly-playbook-analysis` Step 9 items 7
and 8 for the call itself. The ledger row is registered at the `work` close with the prediction
from this question (F267).

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
   Before writing each line, run the duplicate check on it as its own call and read what it lists:
   `python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/finding_dupes.py --line "<the line>"`. It
   names open and closed findings that share an entity with the line (a playbook, rule or
   changeset, directly or through a conversation or test run it cites) or 3 or more IDs. When one
   already says it, add this run's evidence to that line (an open one) or name it in the new line
   (a closed one) rather than filing the same thing under a new number.
2. Audit of the lines new or changed since the last audit (Friday runs only), after item 1 so this
   run's findings are in it. Run it as its own call and read its exit code (0 nothing to propose,
   1 proposals or a failed call, 2 a bad argument):
   `python3 ~/Obsidian/Projects/Ada-Evidence-Loop/workspace/doc_hygiene.py --audit`.
   On the first Friday run of a month run the full sweep instead, every line with no call cap:
   `doc_hygiene.py --audit --full --max-calls 0`. The audit finds candidate pairs in code (a new
   open finding and an older one sharing an entity or 3 or more IDs, directly or through a
   conversation or test run; a HISTORY sentence that names an open finding as fixed; a
   `notes/falsified.md` entry an open line shares a code name or ID with; a W or D "From" list
   citing a closed finding) and asks Haiku once per pair with the two lines only: same, related or
   different. About 40 calls and 40k tokens, under a minute; the hashes it read go to
   `~/.ada-evidence/tablo/audit-state.json`, and it writes nothing else. Haiku over-calls same
   (2026-10-05: 3 of 6 fixed pairs on a sentence that said "held the fixed ask"), so read both
   lines of every SAME pair yourself before proposing from it. From the SAME pairs and the FROM
   lines, propose closes (only on evidence in the files: a fix in HISTORY, a later finding,
   falsified, or out of scope by a standing rule), merges (oldest ID survives, the rest move to
   closed with the status `(merged: F##, YYYY-MM-DD)`), From lists corrected to the surviving ID,
   and the W item each new open finding belongs to, keeping `## Open` at 10 or fewer with the rest
   in `## Queued`. Pairs under NOT ASKED were over the call cap: give their count, they come back
   in the monthly sweep. Nothing is applied yet. Ask David with `AskUserQuestion` whether to apply
   it (the counts in the question: closes, merges, new and extended W items), apply on his yes,
   then run `workspace/doc_hygiene.py` without `--fix` (F451) and fix what it flags.
3. Record how the run ends, as its own calls. (A) Every change this run staged, gated GO or
   promoted, one call each:
   `loop_status.py shipped <CHANGESET-ID> --title "<2 to 3 words>" --staged --gated-go --promoted`
   (the flags that hold). (B) When nothing was staged or gated: a week plan of at most 5 W items,
   most resolved conversations a week first, one call each, the title read from the registry:
   `loop_status.py plan <W#> --goal <resolved a week> --route "<stage script or skill>" --blocker
   "<what it waits on, or none>"`. Ask David with `AskUserQuestion` to approve the plan (the items
   with title and goal in the question). Its result prints `this_week`: put those lines in
   `~/Obsidian/Projects/Ada-Evidence-Loop/OngoingWork.md` under `## This week`, replacing what is
   there, on his yes. `registry.py ready` lists the open P1 items with a stage route and nothing in
   the way, and why each other one is held.
4. Invoke `Skill: commit-results` with args `evidence`; `reference/history/registry.jsonl` goes
   with it.
5. Run `loop_status.py done "Run complete. N decisions recorded, M findings added, nothing
   pending."` with the real counts, and `--tokens N` when the session's token count is known. It
   refuses while any step has neither run nor a skip David approved; then stop and ask him with
   `AskUserQuestion` about the steps it names, and run `done` again after. It also refuses while
   the run has neither a shipped list nor a complete week plan; its JSON names what is missing:
   record it (item 3) and run `done` again. An accepted `done` appends the run's scorecard row to
   `reference/history/loop-runs.jsonl` (it goes with the next commit). Once it succeeds, say exactly
   that line and stop. That message has no next action and no offer.

## Settled (David, 2026-09-22)

- D3: promotion stays manual, through `weekly-playbook-analysis` Step 9; the live promote call is not enabled.
- D4 (applies to the old gate only, run on David's request): a failing test case is waived only by a reason with `"waive": true`; a reason alone records the failure. The bar is per case by role (step 6c), with no hard 100%.
- D5: a decision whose evidence is not decisive at its horizon closes itself as "not enough evidence".
- D7: voice test runs simulate the conversation (F48); there is no audio, so speech recognition, barge-in and keypad input are not tested.
