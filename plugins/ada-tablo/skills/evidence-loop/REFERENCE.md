# Evidence loop: reference

Why each rule in `SKILL.md` exists, by step, with the measurements behind it. Read a section when a
step's output surprises you. None of this is narrated to David during a run; the runbook says what
to say. Moved here from `SKILL.md` on 2026-09-22 so the runbook could be read in one sitting.

## Output rules

Every script takes `--format json` and prints one result dict; the text view is rendered from it.
No statistics vocabulary ("kappa", "p-value", "power", "significant") in anything said to David;
say "moved more than chance explains". No entity IDs unless he must paste one.

## Step 1

`--no-close` previews the closures; step 5.7 appends the verdict rows. The seasonal banner: Tablo
demand tracks the fall TV season and the holiday buying cycle, so inside a ramp broad simultaneous
movement should be read as seasonal until shown otherwise, and no decision should be opened on a
cluster whose movement is channel-wide.

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

## Step 4: which labeller counts

The code rule is the labeller of record: if Ada sent the identical message twice in a row, that
is a defect. It is six lines of Python and no model call. Scored against David's own labels on 74
conversations across four clusters it agreed 55 times; the older set of six structural flags
agreed 37 times, and a model reading one conversation at a time agreed 38 and called a defect on
57 conversations where David called 26. Every way of combining the model with the code rule
scored worse than the code rule on its own, so the combination was built, measured and taken back
out. `--llm-label` still exists and still scores, but it is a measurement tool, not part of the
run; do not offer it as a labeller.

Model calls are spent on what code cannot see (a missing flow, a wrong route, wording) and that is
step 4c: up to 3 targets, one sharpened question each, each read on its own. Stage 3 describes
and points; it does not decide what is a defect.

Scoring the code rule against a sheet David has filled in:

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/forensics_evidence.py --labels <SHEET>
```

Pooling a `customer_text` cohort that stage 2 keys per channel:
`--cluster-key "customer_text|voice|outcome=not_resolved|term=roku" --cluster-key
"customer_text|chat|outcome=not_resolved|term=roku"`. Each key is matched exactly; a typo raises
with the near-miss keys for that one key.

## Step 4b

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

**Groups of 20.** The sheet is split into groups of 20 and each group is read separately, so 60
conversations is three calls, not one enormous one. Every statement the model makes must name the
conversations that show it, and each group's citations are checked against that group's
conversations only. The groups are reported one by one; nothing combines them, because combining
is where a claim loses the conversations that were supposed to back it. Citations resolve by
prefix: 8 or more characters matching exactly one conversation resolves; several is ambiguous and
not guessed at; none is the fabrication case.

**Three things to report and not bury.** A statement with no conversation behind it is printed
and marked; do not repeat it. A conversation named that is in no part of the cluster is a
fabrication; say so and treat the whole answer with suspicion. A group whose reply could not be
read reports nothing at all; the other groups still stand.

**Why the verification gate exists.** "Check it yourself" used to be a sentence here and nothing
enforced it, so it was skipped and a third confident wrong cause reached a fix on 2026-09-18. It
is now a gate: `--record-verification` refuses an id that is not in the cluster or has no
transcript on disk, stage 5 prints NOT VERIFIED against every finding with no row, and stage 5.5
will not approve one. Rejecting or deferring still works without it. A model may describe and
cite; cause is yours to establish.

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

The horizon David typed is the one used. The power calculation is reported as `power_weeks` /
`underpowered` and never acted on (David, 2026-09-16). Predictions counted in conversations are
refused because the verdict engine compares rates.

## Step 5.7

Never soften "no change attached" into a hint that two things are connected. Eight changesets
shipped between 2026-09-14 and 2026-09-17, four of them inside two hours, so one attached change
is a candidate and never a cause.

## Step 5.8

`ledger.py link` reads the changeset from Ada and refuses one that is not promoted. It appends a
row and never edits the decision. If the link disagrees with a changeset already written on the
decision row, the ledger records a conflict and credits neither. When more than one open
prediction sits on a cluster, never pick one yourself.

## Step 6

5 to 10 cases per cluster of 100+, one per distinct failure mode, not one per conversation
(David, 2026-09-16). The gate records which changeset and which clusters the batch tested because
that is the only moment both are in hand; it is what lets a verdict weeks later name the change
instead of guessing at one. Nothing is sent to Ada; it is a line on disk.

The bar (David, 2026-09-16): every test case made for the change passes on every run, or at least
one passes on every run and every remaining failure has a written reason. A written reason waives
the failure; the bar is not a hard 100% (D4, David, 2026-09-22), because on a non-deterministic
bench a hard 100% gives either fake passes or a gate that is always red. For a voice change the bar is outcome criteria plus assertions
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
