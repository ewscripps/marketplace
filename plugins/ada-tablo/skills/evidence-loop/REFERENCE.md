# Evidence loop: reference

Why each rule in `SKILL.md` exists, by step, with the measurements behind it. Read a section when a
step's output surprises you. None of this is narrated to David during a run; the runbook says what
to say. Moved here from `SKILL.md` on 2026-09-22 so the runbook could be read in one sitting.

## Output rules

Every script takes `--format json` and prints one result dict; the text view is rendered from it.
No statistics vocabulary ("kappa", "p-value", "power", "significant") in anything said to David;
say "moved more than chance explains". No entity IDs unless he must paste one.

## Step 1

`--no-close` previews the closures; step 2b appends the verdict rows. The seasonal banner: Tablo
demand tracks the fall TV season and the holiday buying cycle, so inside a ramp broad simultaneous
movement should be read as seasonal until shown otherwise, and no decision should be opened on a
cluster whose movement is channel-wide.

## Step 2b: last week's changes

Why it runs second. Three runs in a row (2026-09-28, 2026-10-02, 2026-10-05) collected data, read
targets and changed nothing in Ada. On 2026-10-05 the week's largest fact, the CSAT rollout
regression (F637: Connectivity chat resolved 7 of 85 on the change arm against 21 of 99 on the
control), was on the step 1 page at 13:03 UTC and acted on at 13:41, after two approvals were
written. Last week's changes are read before anything new is approved, and a regressing one holds
new predictions on its channel until David decides it.

Why the pull and not Ada's metrics. The export carries `changeset_id` on every conversation, so a
rollout's arm and control are split exactly, on the same days, with no Ada call. The control
follows the scoreboard's rule: with two rollouts at 50% on different channels, the other rollout's
arm on this channel (D17); otherwise `changeset_id` baseline. Only playbooks and articles can be
found in the export; a coaching rule's export id is not the rule's, so coaching and tools are listed
as not read.

Why email on a partial read is not scored (F615). Chat and voice are graded as they end (F391); email
is graded days later, so in a week that ended under 72 hours ago most email is ungraded and the
graded remainder is mostly handoffs: -39.3 points [-49.7, -27.7] from grading lag alone on
2026-10-02. The cell is shown with its numbers and labelled too early.

Labels. regressing: resolution's 95% interval lies wholly below zero (above it, for a change
expected to lower resolution), whatever the goal. on track or behind: against a goal in resolved
conversations a week, from the deploy note (`note --expect "resolution up 12/wk on <id>/<channel>"`)
or an open ledger decision on that changeset and channel. no goal: neither. too early: under 72
hours live inside the week, a side with no conversations, no weekly pull on disk for the before
window, or email on a partial read.

## Step 3: a topic that is not a cluster

A device, a platform or a brand name someone typed has its own kind: `customer_text` and
`customer_text_x_playbook`, keyed on a small reviewed watchlist in `triage_evidence.py`. They get
the same channel split, history and `trend_evidence.py series` support as any structural cluster,
and they are baseline rows David sees, never a ranked finding on their own (the same treatment as
a variable cluster). Matching runs only over `inquiry_summary` and the customer's last message,
never Ada's own coaching or article text. Matching the whole record is about four times too big,
because it also catches Ada's own config talking about the term.

## Step 3b: coaching

The pull-based command `trend_evidence.py coaching` was retired from the weekly run on
2026-09-22. Its volume runs 1.71x to 4.98x Ada's COACHINGAPPLIED figure (median 2.30x, n=7 of the
top 12 rules, 2026-09-17), unevenly enough to reorder the list; the resolution rates agree within
0.6 to 9.0 points. Why is not diagnosed (FINDINGS F01). It remains usable for week-over-week
movement only, never absolute volume or rate.

`pull_coaching_metrics.py` asks Ada per rule with the COACHINGAPPLIED filter, which matches the
UI exactly, and it iterates the inventory in `reference/coaching_ids.md` rather than the pull, so
a rule that fired zero times shows as zero instead of vanishing. Two things still hold:

- Handoff coaching hands the customer to a person, so it is never recorded resolved. Its 0% is
  arithmetic, not a finding.
- A rule that fires a lot and resolves almost nothing is a candidate for a step 4c read, not a
  conclusion; stage 5 cannot rank a coaching cluster (FINDINGS F02). No coaching edit is
  proposed from this skill.

## Step 4d: which labeller counts

The code rule is the labeller of record: if Ada sent the identical message twice in a row, that
is a defect. It is six lines of Python and no model call. Scored against David's own labels on 74
conversations across four clusters it agreed 55 times; the older set of six structural flags
agreed 37 times, and a model reading one conversation at a time agreed 38 and called a defect on
57 conversations where David called 26. Every way of combining the model with the code rule
scored worse than the code rule on its own, so the combination was built, measured and taken back
out. `--llm-label` still exists and still scores, but it is a measurement tool, not part of the
run; do not offer it as a labeller.

Model calls are spent on what code cannot see (a missing flow, a wrong route, wording) and that is
steps 4c and 4d: up to 3 targets, one sharpened question each, each read on its own. Stage 3 describes
and points; it does not decide what is a defect.

Scoring the code rule against a sheet David has filled in:

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/forensics_evidence.py --labels <SHEET>
```

Pooling a `customer_text` cohort that stage 2 keys per channel:
`--cluster-key "customer_text|voice|outcome=not_resolved|term=roku" --cluster-key
"customer_text|chat|outcome=not_resolved|term=roku"`. Each key is matched exactly; a typo raises
with the near-miss keys for that one key.

## Step 4d: what the human agent did next

Zendesk carries no call recordings text, so on voice the human-side record is the agent's
internal note after the call. About 5 fetches go into each conversation, which is why
`--max-gets` is capped at 60. Excerpts are written outside the repo and the redaction is regex,
so names can survive.

## Step 4c

**Why the question is David's.** "What went wrong here?" is the open-ended ask that was measured
and abandoned: it produced over-calling (57 defect calls against 26 real ones) and, on one
cluster, five invented conversation ids. A specific question written by the person who knows the
product is what the reading is for. He approves each question, once; that is what keeps it
worth his time as the volume grows.

**Why three targets (W80, 2026-10-02).** With one target a run, the 2026-10-02 run read Legacy
Device Detection on voice, whose decision was flagged underpowered with a pre-trend of -1.71
points a week, and the one-of-each-kind shortlist left Antenna & Channels (7.7 resolutions lost)
out because Legacy & Migration (7.8) held the one topic slot. The three reads are now the three
largest losses whatever their kind. Each is read and recorded on its own, so each reaches the
gate and the ledger on its own.

**Coaching targets** are ranked by Ada's own figures, not this week's pull (see step 3b). A rule
that cannot be matched to this week's conversations is listed, never dropped; it is usually a
large minority (78 of 134 active rules on 2026-09-18) and a real limit on what a week can see.
Quote Ada's number; the pull only says how many conversations you could actually read.

**One row per conversation, read twice (W89 Stage D, 2026-10-05).** Until 2026-10-05 a group of
20 came back as one answer with claims citing conversations, and a citation was only checked for
being in the group. On the 2026-10-05 target 1 read a claim that a dead Tablo got "only handoff,
not replacement path or warranty offer" cited `6abd8fbeafdf9da3ffe324f4`, whose transcript asks
"Would you like me to provide the link to request a replacement Tablo?"; the check passed it. Now
the model returns, for each conversation, `applies`, `answer` (yes, no, cannot tell), the step the
answer turns on, and a quote copied from one message. Code checks the quote is in that
conversation's stored messages (case, spacing, curly quotes and markdown asterisks aside; Ada's
own summary is never searched), and a yes or no without a found quote is unsupported. Each
conversation is read twice, groups of 10, the second grouping taking every sixth row of a
60-row sheet, so its neighbours differ; agreement is the share answered the same both times.
At 3 targets of 120 that is 72 Haiku calls. Measured on the 2026-10-05 target 2 sheet (60
conversations, 12 calls): 6 minutes 25 seconds wall time, $1.67 nominal on the subscription.

**Sample size.** All of a channel cluster under 150 conversations, else 120. The 2026-10-05
target 2 read stopped its chat cluster at 30 of 188 because a 60-fetch cap was shared by chat,
voice and email. `--per-cluster N` still gives the older capped read that stops on saturation.

**Three things to report and not bury.** A row whose quote is not in the conversation is
counted and marked; do not repeat its answer. A row naming a conversation that was not in its
group is dropped and counted; a warning prints. A group whose reply could not be read loses only
its conversations' reading; they show as read once.

**Why the verification gate exists.** "Check it yourself" used to be a sentence here and nothing
enforced it, so it was skipped and a third confident wrong cause reached a fix on 2026-09-18. It
is now a gate: `--record-verification` refuses an id that is not in the cluster or has no
transcript on disk, and, when the targeted read of that cluster and window has disagreements,
refuses a reading that names none of them; stage 5 prints NOT VERIFIED against every finding
with no row, and stage 5.5 will not approve one. Rejecting or deferring still works without it.
A model may describe and cite; cause is yours to establish.

**The default questions.** Without `--question` the command asks four fixed ones: what pattern,
what flow is missing, what was misrouted, how sure. Fine for a first look at an unfamiliar
cluster, weaker than a question David wrote. Questions are filed in
`reference/history/questions.jsonl` so one can be re-asked on a later week and the two answers
set side by side.

## Step 5: two tables

The ranked five cannot contain a handoff: voice hands off 75% of calls as a matter of course, so
escalation clusters would take every slot. They are scored separately, against each channel's own
behaviour, under AGAINST THE CHANNEL BASELINE (`--top-escalation`, default 3). A playbook at its
channel's handoff rate is not a finding; one resolving at half its channel's rate is. Both tables
are decided at the same gate and both block on the same missing transcript read.

That table is ordered by how many times worse than its own channel a playbook is, not by how many
conversations it costs. Conversations are the right unit inside one channel and the wrong one
across channels: a playbook can be short by at most its channel's resolution rate, so chat has
about four times the room voice has, and ranking on conversations hands every slot to the channel
already doing best. Both numbers print on every row, and the 5-conversation floor still decides
what gets in at all.

The per-channel lines above the tables (own handoff and resolution rate, last week's, trend) are
context and never a finding. They are on the page so the baseline the table is scored against is
visible, because a table scored against 75% cannot ask whether 75% should be lower. "Where the
handoffs sat" under the tables is a decomposition by volume: where to work if a channel is to
improve, never a ranking, because the biggest playbook is biggest either way.

Stage 5 makes no cause claim and proposes no config edit. Without `--artifact` it uses the newest
pull, which may be a two-day mid-week pull judged on a partial window with no matching history.

## Step 5.5

The `decide` call without confirm writes nothing: it prints the question and the exact `on yes`
command with a token. Never construct a token. Nothing here touches Ada.

Approval is refused without a recorded transcript read: see step 4c. A prediction on an
against-the-channel finding is refused because the ledger scores a cluster's recorded percentage,
which for one of those rows is the playbook's share of the whole channel, not the rate the page
shows, so the prediction would be stored in units nobody typed (David, 2026-09-21).

## Step 5.6

The horizon David types is the earliest look (W85, one week by default). The verdict date is the
power weeks: the weeks of the cluster's volume the data needs to see the predicted change at 80%
(David, 2026-10-05, changing W85 and the 2026-09-16 rule that power was reported and never acted
on). A decision is still looked at from the earliest look, and the one-look rule holds an
underpowered one open, so an early look cannot close it on chance. Predictions counted in
conversations are refused because the verdict engine compares rates. The goal comes first: every
imported decision carries `goal_resolved_per_week` and a resolved-a-week row, computed when the
cluster translates (a topic's unresolved share joined the failure kinds on 2026-10-05, so both
2026-10-05 approvals translate), else the goal chosen at the gate.

## Step 2b: closing

Never soften "no change attached" into a hint that two things are connected. Eight changesets
shipped between 2026-09-14 and 2026-09-17, four of them inside two hours, so one attached change
is a candidate and never a cause. "moved, short of target" replaced "CONFIRMED, target NOT
reached", and "reached, underpowered" replaced INCONCLUSIVE on a target already reached (W89
Stage B): both verdicts were read as their opposite.

## Step 2b: which change each prediction tested

`ledger.py link` reads the changeset from Ada and refuses one that is not promoted. It appends a
row and never edits the decision. If the link disagrees with a changeset already written on the
decision row, the ledger records a conflict and credits neither. When more than one open
prediction sits on a cluster, never pick one yourself.

## Step 6

5 to 10 cases per cluster of 100+, one per distinct failure mode, not one per conversation
(David, 2026-09-16). The gate records which changeset and which clusters the batch tested because
that is the only moment both are in hand; it is what lets a verdict weeks later name the change
instead of guessing at one. Nothing is sent to Ada; it is a line on disk.

The reach check replaced the per-case bar as the launch path (W97, David, 2026-10-07). Replayed
on 63 historical batches, the bar read GO on 10; it read GO on 0 of 6 since 2026-10-06; an
80%-true fix clears 3 of 3 runs 51% of the time; W7 took 17 gate runs to GO and was then rolled
back after trailing control. A simulation now answers only whether Ada reached the change and
said the new words, and the 72-hour production read is the verdict. The bar below runs only when
David asks for the old gate, for example on a change that removes a handoff or an exit.

The old bar (David, 2026-09-16, reworked by W95, 2026-10-06) is per case, by role: a target case passes on every evidence-bearing run (or at most 1 failure in 6 or
more pooled runs), and a regression case is judged against live on the same case. A failing case
is waived only by a reason with `"waive": true`; a reason alone records the failure. The bar is
not a hard 100% (D4, David, 2026-09-22), because on a non-deterministic bench a hard 100% gives
either fake passes or a gate that is always red. For a voice change the bar is outcome criteria plus assertions
(David, 2026-09-23, W10): the D12 circle was held up by a "same thing twice" rule that live failed
at the same rate as the change (F119). `run --cases ID` picks up the bench spec a case was created
or last run with from `sim/` (F105); a case with none on disk is named on stderr and scored by
Ada's judge. `promote` is a stub by design and not a bug to work around. The
first real promotion (2026-09-21) was made from the session on David's explicit approval, after
two attempts were refused by the permission classifier; the intended path for the next one is
`weekly-playbook-analysis` Step 9.

## Step 7

Ada's own "last run" grouping is unreliable: `get_test_cases(group_by_last_run=true)` files cases
under `datetime: null` that have completed runs. The audit uses run history instead.

## Model calls

`forensics_evidence.py` model paths run through `claude -p` on David's Claude subscription. Never
an API key; there is none in the repo `.env`. Budget roughly one short turn of plan usage per
labelled row with `--llm-label`, and per group of 20 with `--cluster-review`.
