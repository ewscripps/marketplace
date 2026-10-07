---
name: work
description: Open a scoped work session on one item from the Ada-Evidence-Loop TODO list. States the deliverable, does only that, files measured harm or a broken check as a finding, and stops with "Deliverable complete, nothing pending." Hands off to playbook-authoring, deterministic-logic, config-health or evidence-loop targeted mode when the work is theirs. Use for any session in the Ada-Evidence-Loop project that is not the Friday run.
user-invocable: true
argument-hint: '<W#>'
allowed-tools: Read, Grep, Glob, Skill, Agent, AskUserQuestion, Edit(/Users/181085/Obsidian/Projects/Ada-Evidence-Loop/TODO.md), Edit(/Users/181085/Obsidian/Projects/Ada-Evidence-Loop/FINDINGS.md), Edit(/Users/181085/Obsidian/Projects/Ada-Evidence-Loop/OngoingWork.md), Edit(/Users/181085/Obsidian/Projects/Ada-Evidence-Loop/HISTORY.md), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/*), Bash(python3 ~/repos/ada-tablo-ops/evidence-loop/tests/run_tests.py *), Bash(python3 ~/repos/ada-tablo-ops/scripts/*), Bash(git *), Bash(ls *)
---

# Work session (Ada-Evidence-Loop)

One item, one deliverable, then stop. The files:

- TODO: `~/Obsidian/Projects/Ada-Evidence-Loop/TODO.md`
- FINDINGS: `~/Obsidian/Projects/Ada-Evidence-Loop/FINDINGS.md`
- OngoingWork: `~/Obsidian/Projects/Ada-Evidence-Loop/OngoingWork.md`
- HISTORY: `~/Obsidian/Projects/Ada-Evidence-Loop/HISTORY.md`

Replies are one or two sentences in plain words. The root CLAUDE.md interaction rules apply.

## 1. Open the item

Read TODO. Find the line for `$ARGUMENTS`. If no ID was given, or none matches, list the open IDs
one line each with its title and priority ("W47 (Password Reset Fix) P1"), say which one is first (the list is in priority order, P0 to
P3, defined in TODO under Priority levels; skip a line marked BLOCKED or QUEUED, and skip W1
outside a Friday run), and stop.

If a P0 is open and `$ARGUMENTS` names a different item, say so in one line, then open the item
David named.

If the line says BLOCKED, say what it is blocked on in one line and stop, unless David says the
blocker is cleared.

Write the item under `## Now` in OngoingWork: the ID, its title, its priority, the deliverable,
the done-when, today's date. Record the open in the registry, the title as the TODO line carries it:
`python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/registry.py item <W#> --title "<Title>" --priority <P#> --status open --by david`.
Say an ID with its title, "W47 (Password Reset Fix)", every time. Then say two lines and nothing
else:

> Deliverable: <the deliverable>.
> Done when: <the done-when>.

## 2. Do only that

- **The TODO line is the brief, and it is permanent for this session.** Anything the brief marks
  out of scope stays out, even if evidence turns up that it matters.
- **Before any tool call that does not serve the deliverable, name the part of the brief that
  authorizes it.** If you cannot, do not make the call.
- **Hand off when the work belongs to another skill**, and let that skill's own gates apply:
  - `Skill: playbook-authoring` to draft or revise a playbook.
  - `Skill: deterministic-logic` to build or fix a code tool.
  - `Skill: config-health` to check a playbook's wiring and behaviour.
  - `Skill: evidence-loop` with `--cluster`, `--playbook` or `--topic` to read one cluster or to
    test a staged change against real failures (its step 6).
- **Sub-agents** are for a build, a config sweep, or bulk transcript reading. Ask for a
  three-part report: done or not done in one line; the verification command and its real output;
  findings as numbered one-liners with verbatim text beside every ID. Report it to David in two
  sentences, never the transcript. **Re-resolve every Ada ID a sub-agent cites** before repeating
  or acting on it: run IDs and step IDs have been invented with the surrounding analysis correct.
- **Ada writes from this skill: one kind only, a `scripts/stage_playbook.py` run.** Its allowed tools
  cover the evidence-loop scripts, and a playbook's `sections` edit is too wide for a model tool
  call (F71), so this skill runs the stage script: a dry run first, then the stage with the
  script's fresh confirm token, on David's yes in the moment, every time. It never runs under
  standing approval, and the change lands on a TESTING changeset. Every other write goes through
  its owner: test cases and test runs through `evidence-loop`; any other config change, every
  promote and every rollout through `weekly-playbook-analysis` Step 9. `sim_admin.py` deletes and
  needs David's yes in the moment too.
  Run `python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/stage_playbook.py EDIT [--variant V] [--changeset ID] [--confirm TOKEN]`.
  `EDIT` is `fts_voice`, `voice_connectivity`, `presales_pricing`, `ldd_fourthgen_exit`,
  `ldd_usersid_guard` (`--variant ldd` or `--variant connectivity`), `csat_happy_paths`
  (`--variant fts` or `--variant conn`), or `password_reset`. Omit `--confirm` for the dry run;
  it writes `~/.ada-evidence/tablo/sim/<name>_payload.json` and prints the token for the stage.
  Each edit has an `evidence-loop/scripts/payload_<EDIT>.py` builder with constants `PLAYBOOK`,
  `CHANGESET`, `PAYLOAD`, `BATCH`, `NOTE` and `build(live, client, variant)` returning
  `(fields, errs, lines)`. A new `sections` edit needs a `payload_<name>.py` registered in the
  driver's `EDITS` tuple. Shared tree helpers `index`, `clean`, `validate`, `flow_check` live in
  `evidence-loop/scripts/playbook_flow.py`. The confirm flow, journal and TESTING landing stay
  the same; `config-health --draft PATH` reads the dry-run payload.
- **Verify before claiming.** Run the check the done-when names and read its output. A reach run
  shows the change was reached and the words were said; the 72-hour production read is the verdict.
- **Test sizing.** One reach run per cycle: 1 rep per target case, on the change only, creates
  paced one every 90 seconds (the default). No live arm, no 3-rep gate, no separate regression
  batch. Say the size before it starts. A case that did not reach the change is fixed, or the
  change is restaged with one or two edits (R15), and only those cases run again. The old gate
  runs only when David asks for it.
- **Real calls before a rewrite.** A deliverable that rewrites or restages a voice playbook starts
  with a read of real calls through that playbook (`forensics_evidence.py`, 20 to 50 conversations)
  and names what the read changed in the draft, before any test run is spent (F100, F101).
- **The ledger is written only through `ledger.py`.** The decision ledger, verifications and
  attribution files under `reference/history/` and `~/.ada-evidence/` are never edited by hand.
  This skill writes to them in one place, close step 1 below, with `ledger.py register` or
  `ledger.py link`, for a changeset promoted while the session is open. Every changeset ID this
  session stages or promotes still goes on the HISTORY line at close; one staged but not
  promoted is left for the Friday run's step 2b ("changes nobody claimed").

## 3. Findings

A finding is filed only when it names measured harm (a count, a rate, named conversations) or a
broken check (a test, a gate, a script or skill step that gives a wrong answer). Anything else stays
in the worker's report and goes nowhere. Every finding is one line carrying: the date, `[loop]` or
`[ada]`, what is wrong, where (entity ID, file and line, or run ID), the evidence pointer, what
correct looks like, and a priority P0 to P3 by the definitions in TODO under Priority levels, as
`(open, P2)`. Enough that a reader can act without re-reading the transcript.

Before writing the line, run `python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/finding_dupes.py --line "<the line>"`
as its own call and read what it lists: open and closed findings that share an entity with it
(directly or through a conversation or test run it cites) or 3 or more IDs. When one already says
it, add the evidence to that line (an open one) or name it in the new line (a closed one) rather
than filing the same thing under a new number.

The ID is the next one, one past the highest in FINDINGS or `notes/FINDINGS-closed.md`. A P0 or P1
line goes at the bottom of the P0 and P1 section of FINDINGS, a P2 or P3 line at the bottom of
Open. A P0 is also said to David in one line. A finding a W item owns carries `(work: W#)` with no
P tag, since it takes the W's priority. A watch the session opens on a promoted change (what the
next loop runs should read) goes under `## Loop run reads` in TODO, outside the W line. No
recommendation. Do not investigate it, act on it, or propose acting on it. If David asks about
one, answer in one line and return to the deliverable.

## 4. Close

When the done-when holds and you have read the verification output:

1. **Every changeset promoted while this session was open has a ledger row, or the session does
   not close (F267).** This covers promotions through any handoff skill and ones David made in
   the dashboard. For each one, check the ledger:

   ```bash
   python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/ledger.py open --format json
   ```

   A changeset is claimed when its full ID appears in the output, as a row's `changeset_id` or
   in an `attribution` entry. If it does not appear, it is unclaimed. Then do one of the following:
   - **An open decision already predicts this change's cluster and has no change attached**
     (`ledger.py open` shows "no change attached yet"): link it, with David's yes on which one.
     `python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/ledger.py link <decision-id> --changeset <CHANGESET-ID> --by david --note "<W#>"`
   - **Otherwise, register one.** Take the prediction from the gate file the promotion used,
     `~/.ada-evidence/tablo/stage-results/gate_<date>_<runs-batch>.json`, key `prediction`
     (`cluster_key`, `metric`, `direction`, `threshold`, `horizon_weeks`). If the gate has no
     prediction, ask David for one; never write one yourself. Take the baseline from the latest
     measured window with `--baseline-window` so `register` checks it against the measured row.
     `python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/ledger.py register <promoted-date>-<slug> --changeset <CHANGESET-ID> --cluster-key <key> --metric <pct|count> --baseline-count <n> --baseline-denominator <d> --baseline-window <window-end> --target <threshold> --direction <down|up> --horizon-weeks <n> --promoted-at <ISO time> --by david --note "<what changed> (<W#>, gate <file>)"`

   Re-run `ledger.py open --format json`: every promoted changeset's ID must now appear. If `register` or
   `link` refuses, or David has no prediction to give, do not close. Write
   `BLOCKED: ledger row for <CHANGESET-ID>: <the refusal, verbatim>` on the TODO line and follow
   the blocked path below. Every changeset promoted or rolled out while the session was open also
   has a deploy note, written before the promote on David's yes (see the changeset-inspect skill,
   Deploy notes). If one is missing, for a promotion David made in the dashboard, draft it, show it
   and write it on his yes: `python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/changeset_inspect.py note --changeset <ID> --by david --source <W#> --expect "..." --note "..."`.
2. Move the TODO line to HISTORY as one line under today's date, with what was verified, any
   changeset ID staged or promoted through a handoff skill and the ledger row that claims each
   promoted one, and whether files under `~/repos` were left uncommitted (they are, unless David
   asked for a commit; `Skill: commit-results` does that).
3. Clear `## Now` in OngoingWork back to "Nothing in progress." Close the item in the registry,
   with one link row first for every changeset this session staged or promoted and every decision it
   registered or linked (`stage_playbook.py` and `ledger.py` write their own rows; this one ties
   them to the item):
   `python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/registry.py link <W#> <CHANGESET-ID> --relation fixes --by david` (`--relation reads` for
   a decision), then `python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/registry.py item <W#> --status done --by david`. A changeset or decision ID
   written into an open TODO line also gets its link row, or `doc_hygiene.py` flags it as bare.
4. Say: "Deliverable complete, nothing pending." Add "N findings filed." if any. The message
   ends there: no next action, no suggestion, no offer.

If the deliverable cannot be finished: write the blocker on the TODO line as `BLOCKED: <what>`,
record it (`python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/registry.py item <W#> --status blocked --by david`, and
`python3 ~/repos/ada-tablo-ops/evidence-loop/scripts/registry.py link <W#> <blocker ID> --relation blocked_by --by david` when the blocker is a W,
D or F item), clear `## Now`, say "Blocked on <what>. Nothing pending." and stop.
