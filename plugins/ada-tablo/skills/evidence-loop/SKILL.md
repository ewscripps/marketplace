---
name: evidence-loop
description: Weekly evidence loop for the Tablo Ada instance. Shows where Ada got worse this week from the whole conversation population, turns real failed conversations into Ada test cases, and checks a staged change against them before a person promotes it. Read-heavy; every write to Ada sits behind an explicit approval. Use for the Friday review, or mid-week with a cluster, playbook or topic to chase one thing.
user-invocable: true
argument-hint: '[--window START END | --cluster KEY | --playbook ID | --topic ID] [--no-pull]'
allowed-tools: Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/brief_state.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/pull_evidence.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/triage_evidence.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/trend_evidence.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/targets_evidence.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/forensics_evidence.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/followthrough_evidence.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/judge_evidence.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/approval_gate.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/ledger.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/sim_harness.py *), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/tests/run_tests.py *), Bash(ls *), Bash(mkdir -p *), Read, Grep, Glob, AskUserQuestion, Skill
---

# Ada Evidence Loop (Tablo)

One weekly run. Every stage is built except the live promote call, which stops at a stub on
purpose. Step 6 verifies a change someone has already staged; a person still promotes it.

**Output rules for every step.** Every script takes `--format json` and prints one result dict;
read that, then tell the user in plain words: what happened, the one number that matters with
its denominator, and the one next action. No entity IDs unless the user must paste one. No
statistics vocabulary ("kappa", "p-value", "power", "significant") in anything you say. Every
question to the user is a closed question through `AskUserQuestion`, recommended option first.

**Write rules.** This skill never calls `edit_agent_behavior` or `edit_agent_config`. The only
writes to Ada are test-case and test-run creation through `sim_harness.py`, which asks for a
confirm token when a human decision is needed. Test-run batches of 100 runs or fewer start
without a prompt (David's standing approval, 2026-09-15); anything larger, and any test-case
creation, asks first. `sim_admin.py` is the only delete path and this skill does not call it.
Staging and promoting a change stay with a person.

**Model calls.** `forensics_evidence.py --llm-label` runs through `claude -p` on David's Claude
subscription. Never an API key; there is none in the repo `.env`. Budget roughly one short turn
of plan usage per labelled row.

## Step 0: Preflight

Invoke `Skill: preflight`. It pulls the repo, checks credentials, and runs the weekly platform
contract check if it is more than 7 days old. If the contract check FAILS, show the failing
group's "WHAT BROKE / INVALIDATES / DO" lines and ask whether to continue.

## Step 1: Where are we

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/brief_state.py --no-close
```

Report: last run date, how many clusters moved past the noise threshold (say "moved more than
chance explains"), which predictions are due, which would close this run and how, and what was
promoted since last time. `--no-close` previews; Step 5.7 does the closing. If the seasonal
banner is set, say the window is inside the fall or holiday ramp and broad movement should be
read as seasonal until shown otherwise.

## Step 2: This week's conversations

Targeted mode (`--cluster`, `--playbook`, `--topic`): skip the pull if an artifact covers the
window, then run `run_tests.py --playbook/--topic` and go to Step 3 for that one target.

Weekly mode: pull the Monday to Sunday week that ended most recently, unless an artifact for it
already exists under `~/.ada-evidence/tablo/`.

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/pull_evidence.py --instance tablo --start-date <MON> --end-date <SUN>
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/triage_evidence.py --instance tablo
```

Report: conversations read, the top three failure clusters by count with their channel and the
share of that channel's non-escalated conversations. Note the artifact path; Step 5 needs it.

## Step 3: Is this new

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/trend_evidence.py mix
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/trend_evidence.py series --cluster "<KEY>"
```

Report in one sentence each: whether this week's change is mostly a change in who escalates,
a change in how often Ada resolves, or a change in channel mix; and whether the chosen cluster
is a step change or a slow slide.

**A topic that is not a cluster** (a device, a platform, a brand name someone typed) has its own
kind: `customer_text` and `customer_text_x_playbook`, keyed on a small reviewed watchlist in
`triage_evidence.py`. They give the same channel split, history and `trend_evidence.py series`
support as any structural cluster, and they are baseline rows David sees, never a ranked finding
on their own (same treatment as a variable cluster). Matching runs only over `inquiry_summary`
and the customer's last message - never Ada's own coaching or article text. Matching the whole
record instead is about four times too big, because it also catches Ada's own config talking
about the term.

## Step 3b: What is coaching doing

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/trend_evidence.py coaching
```

How often each coaching rule fired this week, how the conversations it fired on ended, and the
change since last week. No Ada call and no export: the weekly pull already carries the coaching
intent text and the outcome on every conversation.

Report: how many rules fired, which fired most, and the rules that fired often and almost never
ended resolved. Two things to say plainly and not get wrong:

- **Handoff coaching hands the customer to a person, so it is never recorded resolved.** Its 0%
  is arithmetic, not a finding. The command already keeps it out of the worst list; do not
  reintroduce it in what you say.
- **A rule that fired zero times cannot be seen here at all.** Counting rules that never fire
  still needs a manual export from the Ada UI. Say so rather than implying the list is complete.

A rule that fires a lot and resolves almost nothing is a candidate for Step 5, not a conclusion.
Do not propose a coaching edit from this skill.

## Step 4: Why

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/forensics_evidence.py --cluster-key "<KEY>" \
  --window <MON> <SUN> --per-cluster 20
```

Reads the transcripts, describes what the structured log shows (which playbook steps ran, which
asks went unanswered, which actions failed, which variables were set), and writes a labelling
sheet at `~/.ada-evidence/tablo/sim/labels/forensics_<run_date>.jsonl`. It describes; it never
says why. Do not repeat any cause claim it or a model produces as established.

**Which labeller counts.** The code rule is the labeller of record: if Ada sent the identical
message twice in a row, that is a defect. It is six lines of Python and no model call. Scored
against David's own labels on 74 conversations across four clusters it agreed 55 times; the
older set of six structural flags agreed 37 times, and a model reading one conversation at a
time agreed 38 and called a defect on 57 conversations where David called 26. Every way of
combining the model with the code rule scored worse than the code rule on its own, so the
combination was built, measured and taken back out.

**The per-conversation model path is not used.** `--llm-label` still exists and still scores,
but it is a measurement tool, not part of the run. Do not offer it as a labeller.

Scoring the code rule against a sheet David has filled in:

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/forensics_evidence.py --labels <SHEET>
```

Model calls are spent on what code cannot see - a missing flow, a wrong route, wording - and
that is Step 4c: pick one target, sharpen one question, read that cluster. Stage 3 still describes and points; it
does not decide what is a defect.

`--cluster-key` can be repeated to pool a `customer_text` cohort that stage 2 keys separately per
channel, e.g. `--cluster-key "customer_text|voice|outcome=not_resolved|term=roku" --cluster-key
"customer_text|chat|outcome=not_resolved|term=roku"`. Each key is still matched exactly - a typo
raises with the near-miss keys for that one key.

### Step 4b: What a person did next (optional, one cluster at a time)

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/followthrough_evidence.py \
  --cluster-key "<KEY>" --window <MON> <SUN> --max-conversations 20 --max-gets 60
```

Zendesk, read-only, capped. Ask before raising `--max-gets` past 60; about 5 fetches go into
each conversation. Zendesk carries no call recordings text, so on voice the human-side record is
the agent's internal note after the call. Add `--excerpts` only if David asks to read the notes;
they are written outside the repo and the redaction is regex, so names can survive.

Report: how many of the sampled conversations came back as a support ticket, and on how many a
person actually wrote something.

### Step 4c: Pick one target, sharpen one question, read it

This is where model calls get spent, and it is the only step that asks David to decide
something mid-run. He approves the **question**, once, for one target. He never approves
answers one conversation at a time. That is what keeps it worth his time as the volume grows.

**First, what is worth reading.** No Ada call, no model call, nothing is spent here:

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/targets_evidence.py \
  --artifact ~/.ada-evidence/tablo/triage_<MON>_<SUN>.json --run-date <TODAY>
```

Read the shortlist out in plain words: what each target is, how many conversations there are
to read, and which way it moved. Then **one `AskUserQuestion`** to pick one, options drawn from
the shortlist, recommended one first with the reason in its description.

Two things to say straight and not get wrong:

- **Coaching rules are ranked by Ada's own figures, not by this week's pull.** The two disagree:
  the pull runs 1.71 to 4.98 times Ada's number (median 2.3, seven rules checked 2026-09-17) and
  the gap is uneven enough to change the order. Why is not known. Quote Ada's number; the pull is
  only there to say how many conversations you could actually read.
- **A rule that cannot be matched to this week's conversations is listed, not dropped.** Say how
  many landed there. It is usually a large minority and it is a real limit on what the week can
  see.

**Then the question.** A second `AskUserQuestion` confirming the exact wording. Offer a first
draft built from the target - what David would want to know about these conversations - and let
him replace it. Specific beats broad: "did we ask for a serial number when the problem was
already obvious?" is a question; "what went wrong here?" is the open-ended ask that was measured
and abandoned.

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/forensics_evidence.py \
  --cluster-key "<KEY>" --window <MON> <SUN> --per-cluster 60        # build the sheet
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/forensics_evidence.py \
  --cluster-review <SHEET> --question "<David's words, verbatim>"
```

The sheet is split into groups of 20 and each group is read separately, so 60 conversations is
three calls, not one enormous one. Every statement the model makes must name the conversations
that show it, and each group's citations are checked against **that group's** conversations only.
The groups are reported one by one; nothing combines them, because combining is where a claim
loses the conversations that were supposed to back it.

Read out, per group: the answer, then each statement with the conversations you can open. Say
plainly how many statements are backed and how many are not. Three things to report and not bury:

- A statement with no conversation behind it is printed and marked. Do not repeat it.
- A conversation named that is in no part of the cluster is a fabrication. Say so, and treat the
  whole answer with suspicion.
- A group whose reply could not be read reports nothing at all. The other groups still stand.

**Then check it yourself before repeating any of it.** Open three or four of the conversations it
named, in full, and confirm the mechanism. This is a standard step, not an optional one: it has
already caught two confident, wrong causes on this dataset. A model may describe and cite; cause
is yours to establish.

The question is filed in `reference/history/questions.jsonl` so it can be asked again on a later
week and the two answers set side by side. `--question-id <ID>` re-asks one already on file.

Without `--question` the command falls back to four fixed questions - what pattern, what flow is
missing, what was misrouted, how sure. That default is fine for a first look at an unfamiliar
cluster and weaker than a question David wrote.

## Step 5: What it ranks

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/judge_evidence.py \
  --artifact ~/.ada-evidence/tablo/triage_<MON>_<SUN>.json --run-date <TODAY>
```

**Always pass `--artifact`.** Without it the newest pull is used, which may be a two-day
mid-week pull, and the week will be judged on a partial window with no matching history.

Five findings at most, ranked by conversation count with movement as the tie-breaker. Stage 5
makes no cause claim and proposes no config edit; do not add one. Read the five findings out in
plain words and stop.

## Step 5.5: David decides

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/approval_gate.py show --judgment <JUDGMENT JSON>
```

Read the page. Then, **one `AskUserQuestion` per finding**, options: Approve / Reject / Defer
(recommend the one the evidence supports, and say why in the option description). If David
approves a finding and wants to pre-register a prediction, ask for it in the same closed form:
which way the number should move, to what number, and by how many weeks.

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/approval_gate.py decide --judgment <JSON> \
  --finding <ID> --decision approved|rejected|deferred --note "<David's words>" \
  --prediction '{"cluster_key":"<KEY>","metric":"pct","direction":"down","threshold":3.5,"horizon_weeks":4}'
```

That first call writes nothing: it prints the question and the exact `on yes` command with a
token. Run that command verbatim. Never construct a token. Nothing here touches Ada.

## Step 5.6: Record the decision

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/ledger.py import-approvals \
  ~/.ada-evidence/tablo/stage-results/approvals_<TODAY>.jsonl --dry-run
```

Show what would be recorded and what was skipped and why, then run the same command without
`--dry-run`. The horizon David typed is the one that is used; if the tool says the number of
weeks he asked for may not be enough to tell, say that in those words and leave the horizon
alone. Predictions counted in conversations rather than percent are refused; ask for a percent.

## Step 5.7: Close what is due

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/brief_state.py                 # appends verdict rows
```

A decision is looked at once, from the date it was pre-registered for, and gets one answer:
it worked, it did not move, it got worse, or there was not enough evidence. Report each
closure in those words. A decision that needs more weeks stays open and says how many.

Every closure also says which change it was testing, or says plainly that no change was
attached. Never soften the second one into a hint that the two are connected. When the run
lists other changes promoted in the same stretch, read them out: eight changesets shipped
between 2026-09-14 and 2026-09-17, four of them inside two hours, so one attached change is
a candidate and never a cause.

## Step 5.8: Say which change each prediction was testing

The same run prints `WHICH CHANGE GOES WITH WHICH PREDICTION`. Three things can be in it:

- **attached** - the gate recorded which changeset a test batch ran against, and Ada now
  reports it promoted. Nothing to do.
- **NEEDS YOU** - more than one open prediction sits on that cluster. Ask David which one,
  then run the link command below. Never pick one yourself.
- **changes nobody claimed** - promoted since the oldest open prediction and attached to
  nothing. Ask David, once, whether any of them was meant to fix something he predicted:

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/ledger.py link <decision-id> \
  --changeset <CHANGESET-ID> --by david --note "..."
```

This reads the changeset from Ada and refuses one that is not promoted. It appends a row;
it never edits the decision. If the link disagrees with a changeset already written on the
decision row, the ledger records a conflict and credits neither - report that, do not
resolve it.

## Step 6: Prove it before it ships

Precondition: a changeset in `testing` status exists (the user gives its id or you list them
with `list_agent_changesets`).

6a. Turn the cluster's real failures into test drafts:

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/sim_harness.py convert --cluster-key "<KEY>" --limit 10
```

Aim for 5 to 10 cases on a cluster of 100+ conversations, one per distinct failure mode, not
one per conversation (David, 2026-09-16). Show the drafts file path and the first two drafts'
opening message and criteria. Ask: "Create these N test cases in Ada?" If yes:

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/sim_harness.py convert --create <DRAFTS> --format json
```

The script returns `status: approval_required` with a `token` and the exact `on_yes` command.
Run the `on_yes` command. Never construct a token yourself.

6b. Run them on live Ada and on the change, three times each:

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/sim_harness.py run --cases-file <DRAFTS>.applied.jsonl --changeset <ID> --reps 3
```

6c. Read the result, then put it through the gate:

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/sim_harness.py compare --batch <BATCH> --wait
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/sim_harness.py gate --batch <BATCH> \
  --prediction '{"cluster_key":"<KEY>","metric":"pct","direction":"down","threshold":3.5,"horizon_weeks":4}'
```

The gate also records which changeset this batch tested and which clusters its cases came
from. That is the only moment both are in hand, and it is what lets a verdict weeks later
name the change instead of guessing at one. Nothing is sent to Ada; it is a line on disk.

The bar (David, 2026-09-16): every test case made for the change passes on **every** run, and
every remaining failure has a written reason. On NO-GO:

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/sim_harness.py reasons --batch <BATCH>
```

Ask David for a reason per failing case, write them into that file, and run `gate` again.

6d. Promotion. `sim_harness.py promote` stops at a stub and sends nothing to Ada. That is
deliberate and not a bug to work around. Show the stub's summary, then say: "Promoting is your
call and it happens outside this loop." If David wants to promote, hand off to
`weekly-playbook-analysis` Step 9, which shows Ada's own confirm preview. Do not offer to
enable the promote call.

## Step 7: Audit the test bench (occasional)

```bash
python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/sim_harness.py audit
```

Report keep / rewrite / retire counts and the report path. Ada's own "last run" grouping is
unreliable (it reports cases as never run that have run); the audit uses run history.

## Step 8: Record

Invoke `Skill: commit-results` with args `evidence`. It stages `output/` and `reference/`
files by name. Nothing is pushed to a remote until David says the loop works end to end.

## Not settled (say "unknown", do not guess)

- Whether voice test runs simulate anything meaningful. Ada's docs say voice simulation exists;
  no voice run result has been inspected yet.
- Whether the remaining stale test cases are repaired or replaced.
- Who closes a decision when the evidence is not decisive at its horizon.
- Whether the live promote call is ever enabled.
- Whether a failing test case with a written reason may be waived, or the bar is a hard 100%.
- Whether a run pinned to a changeset can be told apart later; the harness journal is the record.
