---
name: config-health
description: Structural and behavioural integrity check for Ada-Tablo playbooks. Finds variables a playbook reads but nothing writes, action outputs that were never bound to a variable, dangling entity references, null-check conflation, cross-playbook variable contracts, and how the playbook behaves on a call: a destructive warning delivered in the same breath as the instruction that triggers it, consecutive sends with no ask on voice, a physical step split into a send and a "say done" ask, fixed messages carrying multi-step manual instructions, unguarded tool failure paths, steps that contradict the playbook's own general guidelines, and on voice a send that repeats the automatic acknowledgement or an exit with no question. Read-only. Reads the live body by default, a TESTING changeset's staged body with --changeset, or a stage script's payload with --draft. Run standalone before any cutover, or as the gate on a staged playbook changeset before its test batch. Playbooks only; it has no coaching checks.
user-invocable: true
argument-hint: '[--changeset ID | --draft PATH] [PLAYBOOK_ID ...]'
allowed-tools: Read, Grep, Glob, AskUserQuestion, Skill
---

# Config Health — Playbook/Action/Variable Integrity Check

Finds the defect class that shipped in the Playbooks 2.0 cutover twice before anyone caught
it by hand: a playbook branches on a variable that nothing ever writes, so the branch always
reads null. Metrics and transcript review cannot surface this — it's a structural property of
the configuration, not an outcome. This skill reads that structure directly.

It also checks a second defect class, added 2026-09-21 after the `[TEMP] Roku App Connectivity`
playbook (`6aac09fcdd2bc622f30792a5`) was disabled four days into its life. That playbook's wiring
was clean, every check above passed, and it still escalated 75% of 60 conversations and cost one
customer their recordings. It failed on how it behaves when spoken: instructions stacked faster
than a caller could act on them, and a factory-reset warning delivered in the same breath as the
instruction that triggers it. The behavioural checks in Step 5 read the same step tree for that.
Rationale and the measured evidence behind each one are in
`~/repos/ada-tablo-ops/reference/playbook_authoring_rules.md`; the checks below are self-contained
so this skill still runs as a gate when that clone is missing.

This skill never writes anything. It reports findings; a human (or
`weekly-playbook-analysis`) decides what to fix and stages the actual edit via
`edit_agent_behavior`.

## Step -1: Pre-Flight

Invoke the preflight skill to confirm MCP connectivity (this skill does not need the
`ada-tablo-ops` workspace repo for anything but the optional cross-reference in Step 6, so a
missing clone is not blocking):

```
skill: "preflight"
```

## Step 0: Load Reference

This skill is read-only — it never calls `edit_agent_behavior` or `edit_agent_config`. Skip
`get_improvement_guide()` here. If a write skill (e.g. `weekly-playbook-analysis`) already
called it earlier in the session, its output is still in context and can inform how findings
are framed — but do not call it on that skill's behalf.

## Step 1: Pull the Full Config Surface

Do NOT use `get_ada_configuration()` for this — it silently omits every disabled tool (as of
2026-08-14 it returned 7 of 15 configured tools), and a disabled action can still be
referenced by a playbook or carry the exact unbound-output defect this skill exists to catch.
Instead pull each entity type in full, once, for the whole run:

```
list_entities(entity_type="tools", detail="full")
list_entities(entity_type="variables", detail="full")
list_entities(entity_type="handoffs", detail="minimal")
list_entities(entity_type="playbooks", detail="full")
```

`tools` full detail carries `inputs[]` and, critically, `outputs[]`, but the two tool types read
differently (measured 2026-09-30):
- **api tools**: take outputs from this bulk pull. Each output carries `key` (the field read from
  the API response), `save_as_variable`, and `variable_name`, which holds the bound variable's id;
  `enabled` is on the tool itself. A per-tool read of an api tool (`entity_id`) returns only id,
  type and name, with no outputs (F387).
- **code tools**: the bulk pull gives each output only its `name`, so every binding reads as
  missing (F304). Read each code tool once with
  `list_entities(entity_type="tools", entity_id="<tool_id>")`. There each output carries `key`,
  `save_as_variable` and `variable.id`, the bound variable's id; `variable_name` is null. Do this
  for every code tool, not only the ones in scope: the unbound-output check walks them all.

Never fill a gap from `get_ada_configuration()`. `variables` full detail carries `scope` (needed by Step 4's
meta/auto_capture check). `playbooks` full detail (bulk call, no `entity_id`) carries
`is_active` for every playbook cheaply, without pulling full step trees — that's still done
per-playbook in Step 3. `handoffs` has no fields these checks depend on, so minimal is enough
there.

## Step 2: Select Scope

Ask the user (AskUserQuestion) which playbooks to check:
- **All active playbooks** (default, recommended before any cutover or weekly run)
- **A specific playbook or set** (e.g. the ones a pending recommendation touches — this is
  the mode `weekly-playbook-analysis` Step 9 calls with)

## Step 3: Pull Full Playbook Bodies

**Which body.** The check is only as good as the body it reads. Say which one in the report
header.
- **Live** (default, no flag): the body customers get today. Right for a standalone sweep or a
  pre-cutover check. Wrong for a gate on a change: it checks the old body.
- **`--changeset <ID>`**, a TESTING changeset: the body that will ship. Call
  `list_agent_changesets(changeset_id="<ID>", include_diff=true)`; the response is large, so let
  it spill to a file and read it with Read or Grep. For each playbook edit on it, take the
  `after` value of every field in `diff.changed` and the live value (below) for every field the
  edit does not change. A playbook the changeset creates is read from its `after` side alone.
- **`--draft <PATH>`**, a stage script's payload before it is staged (the dry run writes it under
  `~/.ada-evidence/tablo/sim/`, for example `voice_connectivity_stage_payload.json`): read the
  file, take its fields as the draft, and the live value for anything it does not carry. A
  draft that exists only in the conversation (a `playbook-authoring` build spec) is checked the
  same way, from the steps as written, and the report says so.

The gate on a change runs on the changeset or the draft, after staging or before it, and always
before the test batch. Every caller uses that one place.

For each in-scope playbook, pull the live body (the whole check for the live mode, the base for
the other two):

```
list_entities(entity_type="playbooks", entity_id="<playbook_id>")
```

This returns `referenced_variables`, `referenced_actions`, `referenced_handoffs`,
`referenced_playbooks`, and the full `sections[].steps[]` tree (recursive — `if_else` steps
carry nested `branches[].steps[]`).

It also returns three fields the behavioural checks depend on, all from this same call, so they need
no extra requests:
- `availability_rules` feeds the voice-reachable derivation in Step 4.
- `general_instructions` is the behaviour contract every step inherits (P2 contradiction check).
- `on_human_request` / `on_off_topic` / `on_off_script` say what the agent does when the customer
  asks for a person, changes topic or asks a side question (rules A9). `search_knowledge` answers
  the side question and resumes at the same step, so it is no exit from a gate; a gate's exit is
  its own branch (rules R6).

## Step 4: Build the Write-Set and Read-Set (per playbook)

Walk every step in every section, including nested `if_else` branches recursively. For each
playbook, build two sets of variable IDs:

**Writes** — a variable is written if:
- A `set` step targets it (`variable_id`), regardless of whether `value` is a literal, a
  `{{ variable:OTHER_ID }}` template, or null with `instruction` (LLM-derived).
- An `ask` step targets it (`variable_id`).
- It is bound to an output (with `save_as_variable: true`) on an action that a `run` step in this
  playbook invokes (`target_type: "action"`, `target_id` = the action). The binding is
  `variable_name` on an api tool and `variable.id` on a code tool (Step 1).
- It is a meta/auto_capture-scope global (populated by the platform itself, not by any step —
  treat these as always-written; cross-check the variable's `scope` field from Step 1's
  `variables` list if uncertain).

**Reads** — a variable is read if:
- It appears as `left_operand` or `right_operand` in an `if_else` condition.
- It appears as `{{ variable:ID }}` inside any `instruction`, `message`, `exact_words`, or
  `set.value` string, anywhere in the playbook (including nested branches).

**Voice-reachable** is a third derivation, used only by the behavioural checks. Evaluate the
`availability_rules` as though the channel variable `65eb4a21c9f9e85c0294ab92` were `voice`:
- A channel condition is true or false on that value: `equals voice` is true and `equals chat` false;
  `does_not_equal voice` is false and `does_not_equal email` true; any other operator is applied to
  the string `voice`.
- Every condition on another variable counts as possibly true.
- Combine them through each group's `match` (`all` or `any`), nested groups included.

The playbook is voice-reachable when the result can be true. That covers a rule with **no channel
condition at all** (including no `availability_rules` key): it is reachable on every channel with
one set of copy. Live examples, 2026-09-30: V2 Password Reset `6a693fd527809d4206fbbfa4` carries
`channel does_not_equal "email"` and is voice-reachable; V2 CSAT Survey `6abb3301b2a454ca79c7aa42`
carries `does_not_equal "voice"` and is not (F19).

The second case is the one that bites. `[TEMP] Roku App Connectivity` was gated only on
`own_tablo equals Yes`, so chat-shaped copy was spoken down the phone. Default to voice-reachable
when in doubt; a false positive costs a sentence in the report, a false negative costs a caller.

If `availability_rules` is explicitly `null`, a rule exists at runtime that the tool cannot
represent. Report the playbook as **unknown** for this derivation and say so. Do not assume either
way, and do not propose overwriting the rule.

## Step 5: Run the Checks

Report every finding found, grouped by severity. This skill does not stop at the first
finding — enumerate all of them per playbook.

Two families, both read off the same step tree from Step 3. **Structural** checks ask whether the
wiring is sound. **Behavioural** checks ask what the playbook does to the person on the other end.
A playbook can pass every structural check and still be the worst thing on the instance.

### P0 — Orphan read (the Password Reset bug shape)

For each playbook: `reads − writes` (reads with no corresponding write, anywhere in the
playbook, in this playbook or via an action it invokes). For every orphan, report:
- The variable id and name (from the Step 1 `variables` list)
- The exact step(s) that read it (step `id`, section title, and the condition or template
  text)
- The action(s) referenced by the playbook whose outputs *could* have written it but didn't
  (cross-check: does any action in `referenced_actions` have an output whose `key` plausibly
  matches, but `save_as_variable: false` or `variable_name` blank/mismatched?)

A playbook-scoped orphan is not automatically a bug — some variables are legitimately written
by a *different* playbook in a shared conversation flow (see P2). Before flagging, check
whether the variable is written by any *other* active playbook or is a documented
meta/global. If so, downgrade this specific instance to a P2 cross-playbook note instead of
a P0. If no writer exists anywhere in the active config, it is a P0.

### P0 — Unbound action output (the Device Status bug shape)

Independent of any specific playbook, walk every action from Step 1's `list_entities(entity_type="tools", detail="full")` pull — including disabled ones (`enabled: false`); a dormant action can still carry this defect and gets referenced the moment someone re-enables it or a new playbook picks it up. For each output:
- Flag if `save_as_variable: true` and the binding (`variable_name` on an api tool, `variable.id`
  from the per-tool read on a code tool, Step 1) is null, empty, or not a real variable id from the
  Step 1 `variables` list.
- Flag if `save_as_variable: false` but the output's `key` (e.g. `devices[0].registrationStatus`)
  looks like a field a playbook actually branches on — cross-check by searching all in-scope
  playbooks' read-sets and instruction text for a variable whose *name* plausibly matches the
  output's `name`/`key` after normalizing both (lower-case, strip underscores/hyphens, drop
  leading path segments from the key). e.g. output name `registration_status` and a playbook
  reading a variable named `registrationStatus` both normalize to `registrationstatus` — flag
  this as a likely binding gap even though the raw strings differ in convention. This is
  exactly how the Device Status bug hid: the output existed and had sensible data, it just was
  never captured into a variable.

Report: action id + name, the specific output, and which playbook(s) appear to expect it.

### P0 — Dangling reference

For every id in every playbook's `referenced_variables`, `referenced_actions`,
`referenced_handoffs`, `referenced_playbooks`:
- Confirm it resolves to a real entity in the corresponding Step 1 list.
- For actions: also confirm `enabled: true` (from the full-detail tools pull). A disabled
  action referenced by an active playbook is a live P0, not a maybe.
- Additionally grep the raw step tree for reference-shaped tokens that are NOT a 24-hex id —
  e.g. `{{ exit_procedure | #exit_procedure(...) }}` or any `{{ <bareword> | ... }}` pattern.
  These are exactly the shape of a reference that resolves to null; flag every occurrence
  even if you can't confirm what it should have pointed to.

### P0 — Destructive warning delivered with its own trigger (behavioural)

For every `send` step, read the delivered text (`message` or `instruction`). Flag it when the same
step both **instructs a physical action** and **warns about a harmful outcome of performing that
action wrongly**.

Harm vocabulary to look for, not exhaustive: deletes, erases, wipes, loses recordings, factory
reset, resets to defaults, unpairs, deregisters, cancels the subscription, permanently.

This is the only check here with known customer harm behind it. Roku step
`6aac060000000000000000c2`, one fixed message: *"Find the reset button... Press and quickly release
it once. Don't hold it for 7-10 seconds or longer - that triggers a factory reset and deletes your
recordings and schedules. Wait for the blue light to go solid."* In conversation
`6aac7a93bf786671cad5d61a` the caller held the button for ten seconds while that block was still
being spoken, and lost their recordings.

Report the step id, the section title, and the message text **verbatim**, because a person has to be able
to read it and judge. Say which clause is the instruction and which is the warning.

The fix shape, for the report: warn first, in its own step; `ASK` the customer to confirm they have
found the control and understood the limit; then give the instruction. Do not draft the replacement
text here. That is `playbook-authoring`'s job.

**P0 on any playbook, not just voice-reachable ones.** On chat the customer can re-read the
warning, which makes it less likely to bite, not safe.

### P1 — Null conflation

For every `if_else` condition using `is null` (or `is not null`) on a variable: enumerate
every distinct upstream cause that can leave that variable null (device not found, action
error, action returned a body but this field was absent, brand-new/never-set-up device,
field genuinely optional). If two or more materially different causes collapse into the same
branch, flag it — quote the condition, the branch's steps, and the distinct causes. Do not
propose a fix; the correct split is a product decision. (This is the exact shape of the LDD
v2 "widened null-check" bug: *device not found* and *device found but firmware unreadable*
reaching the same re-ask loop instead of the firmware-unreadable handoff it was built to
reach.)

### P1 — Write-order

Within a single playbook's step order (accounting for `if_else` branching — a read inside a
branch only "sees" writes from steps that execute before that branch on every path that
reaches it), flag any read of a variable that has no writer earlier in the same execution
path within this playbook, *and* is not covered by the P2 cross-playbook allowance below.
This is a narrower, order-aware pass over the same read/write sets from Step 4 — expect
overlap with P0 orphan reads; report a write-order finding only when the variable does have a
writer somewhere in the playbook, just not before the read.

### P1 — Consecutive sends with no ask, on a voice-reachable playbook (behavioural)

Flag any run of **two or more `send` steps that execute in sequence with no `ask` between them**,
on a playbook the Step 4 derivation marks voice-reachable.

Walk it per execution path, not per node. Five rules make the difference between a useful finding
and a noisy one. Each was got wrong once while building this check or the stage scripts' counter,
and corrected against an FTS [Voice] body:

1. **Sibling `if_else` branches are alternatives, never a sequence.** Each branch inherits the run
   arriving at the conditional and produces its own continuation. Concatenating two branches into
   one run reports sends that can never be spoken on the same call.
2. **A run can span a section boundary.** Sections are an authoring convenience; nothing waits
   between them. Scan the playbook as one sequence.
3. **Report only maximal runs.** A path of three sends also contains two runs of two. Report the
   longest run per path and drop anything contained in it, or one defect reads as four findings.
4. **`set`, `go_to` and a `run` of a tool or a CSAT survey do not break a run**, because none of
   them waits for the caller. The docs say the CSAT `RUN` "continues with the next step
   immediately" and describe no `RUN` that waits (F329). A `run` of an exit or a handoff ends the
   path. A `run` of a linked playbook breaks the run only if the child's first spoken step is an
   `ask`. `ask` breaks it, because that is the step that waits, when it prompts: an ask on the
   default `only_when_needed` can be answered silently from earlier in the conversation and never
   be spoken (rules A5). Treat it as breaking the run, and let the next check flag it if it is a
   physical step.
5. **A path does not take a branch its own earlier branches rule out.** After a branch on
   `connection is "ethernet"`, a later branch on `connection is "wifi"` cannot follow until a step
   writes `connection` again. Counting both reports sends no caller hears on one call (F91).

Why it is a defect: `SEND` never waits on any channel, `ASK` is the only step that waits, and the
platform has no pause step. So a run of sends carrying instructions is a caller being read a script
faster than they can act on it. Measured on the Roku playbook: **5.6 seconds median** from the
first spoken instruction to the question, range 3.9 to 24 seconds, over 42 calls. One caller
answered *"Your directions are very fast. Humans cannot go as fast as an AI."*

**The exemption that matters.** Ada's docs sanction one use of a bare send: *"Use `SEND` to provide
context between backend operations (`SET`, `RUN`) so end users are not left waiting in silence."* A
send that sits next to a `run` purely to cover latency, and asks the customer to do nothing, is
correct. Do not flag it. The test is whether the customer is being asked to act.

Report the step ids in the run, the section title, the branch path, and each message text
truncated to its first clause, so the sequence is readable at a glance. Where two separate `if_else`
steps each have an empty `else`, the structural maximum can exceed what a caller
plausibly hears. Say both numbers rather than picking one. On FTS [Voice] the structural run is 4 and the real path
is 3 (`I couldn't detect your Tablo online yet` → the on-screen-steps instruction → one of the
Ethernet or Wi-Fi scripts), and it is the defect either way.

### P1 — Physical step split into a send and a "done" ask, on a voice-reachable playbook (behavioural)

The pattern rules R1 requires: one `ASK` per physical step, whose instruction gives the step and asks
about what the caller will see when it is finished (the router's lights, the next app screen), with
`when_to_ask: always`. Flag each of these, per step:

1. **A `send` that asks the caller to perform a physical action, followed directly by an `ask`** (no
   other spoken step between) that asks whether it is done. That is the old shape: the instruction and
   the confirmation are two turns.
2. **An `ask` whose question, `exact_words` or instruction asks the caller to say "done"**, or to
   "let me know when you're done", without naming a result they will see. Search the text for
   `done`, `finished`, `ready`, `let me know when`; a question that names a visible result ("tell me
   when the light is solid blue") passes.
3. **A physical-step `ask` on `when_to_ask: only_when_needed`** (the default, or null). An earlier
   "done" or "yes" can answer it silently, so the caller is given the next step before acting on this
   one.
4. **A physical-step turn that asks for three or more actions.** Two small taps on one screen pass.
5. **A physical-step `ask` whose instruction does not say what a re-ask asks**, or that allows a
   generic one ("Would you like to continue").
6. **A physical-step `ask` whose instruction does not say the first ask speaks the action.**
   Contextual phrasing has dropped it and asked only the result question (F326).

Also flag `general_instructions` that tell the agent to have the caller say "done". FTS [Voice] carried
one until W35 removed it (promoted 2026-09-29); `payload_fts_voice.py` now forbids it.

Why it is a defect, measured on this instance (rules R1): on live FTS [Voice] after its 2026-09-23
promotion, 32 of 34 "say done" asks were a separate line after the instruction, 10 of 34 got a clean
"Done." first time and 11 got silence until Ada broke in with "Would you like to continue
troubleshooting your Tablo connection?" (50 calls, 09-23..27). In `6ab41025e6801a02e618f3e8`, "say
'done' once you've been through those steps" drew "Say that again.", then "Agent.". In W7 draft test
runs 72 of 131 back-to-back Ada pairs were an instruction then a separate "Say 'done'" line. In 146 live voice calls, a cue naming the visible result was
answered 7 of 7 times on restart steps, three or more actions in a turn went wrong 29% of 146 against
15% of 249 for one or two, and step-specific re-prompts drew 0 non-replies of 17 against 3 of 20 for
"Would you like to continue". There is no per-step wait on voice (rules A4), so this ask and its
re-prompt are all that hold the flow while the caller acts. Ada's docs say nothing either way about
confirming a physical step; the check rests on measurement.

Report the step ids, the section title, which of the six it is, and the send and ask text
verbatim. Do not draft the replacement; that is `playbook-authoring`'s job.

### P1 — Fixed `message` carrying multi-step manual instructions (behavioural)

For every `send` with a non-null `message` (fixed mode, not `instruction`) on a voice-reachable
playbook: flag it when the text asks the customer to perform **two or more physical actions**.

Why fixed mode specifically: fixed text is delivered as authored and is never re-paced, re-chunked
or shortened for the channel. Only `instruction` sends can be reworded. So a playbook-level rule
like *"on a voice call keep every message to one or two short conversational sentences"* cannot
reach a fixed message, and both live examples carry exactly that instruction and ignore it:

- Roku `6aac060000000000000000b3`: *"press Home on your Roku remote, highlight the Tablo app, press
  the Star (*) button, select Remove app, and confirm."*
- `V2 NEW: Tablo 4th Gen First-Time Setup [Voice]` (`6a693fd47f29e2f8774514c3`), the power-cycle
  message: unplug the router, wait, plug it back in, repeat on the Tablo, force-close the app,
  reopen it, turn off the VPN. That playbook resolves 4.6% on 238 conversations and is still live.

This is model judgment against a stated rule, the same shape as the null-conflation check. Report
the message text verbatim and count the actions, so a person can overrule you.

Do not flag a fixed message that is a single clause, a greeting, a status line, or a bare URL.
`Tablo Device Issue & Replacement` has exactly two fixed messages in the whole playbook and neither
should fire.

### P1 — Unguarded tool failure path

For every `run` step with `target_type: "action"`, find the tool's status output: an api tool's
HTTP status code output, or a code tool's `ada_run_status`. Flag when that output's variable is
**never referenced in any `if_else` condition** anywhere downstream in the playbook.

Why: Ada's documented default is that an unreferenced error code makes the tool *"exit the Playbook
and hand off to a human agent automatically"*. Referencing it in a condition disables that and
hands you the fallback path. So every `RUN` of a tool is a fork whether the author wrote one or
not, and an unguarded one is a silent escalation nobody chose.

Two sub-cases, reported differently, because the fix lands in different places. Measured across
all seven live playbooks on 2026-09-21: 21 of 32 action runs unguarded, 3 sub-case A, 18 sub-case B.

- **A: the tool has a status output and the playbook ignores it.** Fixable by the playbook author.
  `Tablo Device Issue & Replacement` (`6a6a473a78f6ecdfd6ceee87`) and `V2 Legacy Device Detection`
  (`6a693f79cf457078e15fdccb`) both omit `6a6a46fa8d425159a6955e5f` from their
  `referenced_variables` entirely.
- **B: the tool has no status output at all**, so no guard is possible from any playbook. Only 1 of
  16 tools on this instance exposes one. On a code tool this means *"Let playbooks branch when this
  tool fails"* was never enabled. **Report the tool, not the playbook**, and say so plainly, or the
  author will try to fix something they cannot reach.

**Do not read "guards one tool" as "clean".** A playbook can guard its main lookup and still fire
this check several times on sub-case B. FTS [Voice] `6a693fd47f29e2f8774514c3` guards its 404
correctly and fires five times, which makes it the heaviest sub-case-B playbook on the instance,
tied with FTS [Chat]. Count every `run`, not the notable one.

**Also flag a guard that tests a single status code.** All three guarding playbooks test
`is "404"` and nothing else. Because the variable is referenced, the automatic handoff is already
disabled, so a 500, a 502 or a timeout falls through the `else` and is handled as though the device
were found. Report it under this check as a narrow guard rather than a missing one. Arguably worse
than no guard, and it belonged to none of these checks until 2026-09-21.

Use `list_entities(entity_type="tools", detail="full")` for api tools and the per-tool read for
code tools (Step 1) to build the tool-to-status map, never `get_ada_configuration()`. Measured 2026-09-21: the configuration call returns 8 tools and the
entity call returns 16, and the 8 it drops are the disabled ones. Same warning as Step 1.

Not a P0: the auto-handoff is a defined behaviour and a customer reaches a person. It is a P1
because nobody decided it.

### P2 — Cross-playbook contract

Across all in-scope playbooks, build a table of variables written in one playbook and read in
another (e.g. a `device_type`/`board_type` classification variable set in Legacy Device
Detection and read in Connectivity). List each as a producer → consumer pair. This is not a
bug by itself — it's the map that makes the next rename or ID change break loudly instead of
silently. Flag specifically any pair where the producer playbook is `is_active: false` while
the consumer is `is_active: true` (an active playbook depending on an inactive one's output).

### P2 — Step contradicts the playbook's general guidelines (behavioural)

Read `general_instructions` as a list of constraints. Then read every step's `message`,
`instruction` and `exact_words` and flag any that directs behaviour the general guidelines forbid.

Live example: `V2 NEW: Tablo 4th Gen First-Time Setup [Voice]` general instructions say *"Do not
read out URLs; instead offer to send the article by email or describe the steps aloud."* Its
article step instruction says *"share this link on its own line as a clickable link."* Whichever is
right, the playbook cannot follow both, and nothing at runtime resolves the conflict.

Report both texts side by side and say which constraint is being contradicted. Do not pick a
winner. Which one is correct is a product call.

P2 rather than P1 because the reasoning engine usually resolves these in some direction rather than
erroring, so the cost is inconsistency rather than breakage.

### P2 - Voice acknowledgement repeated, or a voice exit with no question (behavioural)

Rules R12, on a voice-reachable playbook. Flag each of these:

1. **A `send` that only acknowledges.** Its whole text (fixed `message`, or an `instruction` that
   tells the agent only to acknowledge, thank or confirm receipt) is an acknowledgement such as
   "Great.", "Thanks.", "Got it." or "Perfect." The voice agent "automatically acknowledges end
   user responses before and during Playbook execution", so the caller hears it twice. A send that
   acknowledges and then gives information or covers a `run` passes; judge the send by what else it
   says.
2. **A path that ends the playbook with no question.** Walk every path to a `run` with
   `target_type: "exit"` and to the end of the last section. Flag it when the last spoken step
   before the end is a `send` that asks nothing. The docs say "End every Voice Playbook with a clear
   question before exiting". A path that ends in a handoff passes: the caller is transferred, not
   left.

Report the step ids, the section title, the branch path and the text verbatim. P2, like R12: the
cost is a repeated word or an abrupt end, and no measured failure on this instance sits behind it
yet (F335).

## Step 6: Report

Structure the output severity-first:

```
## Config Health Report — [scope] — [date]
Body read: [live | changeset <ID> | draft <path or "in conversation">]

### P0 — Must fix before promoting anything on this playbook
[entity, exact location, what's wrong, one-line why-it-matters]

### P1 — Should fix, needs a product call
...

### P2 — Informational (cross-playbook map)
...

## Verdict
[If any P0: "Do not promote edits to <playbook(s)> until these are resolved."]
[If zero P0: "No structural blockers found. P1/P2 items are advisory."]
```

**On any P0, refuse to recommend promotion of pending changes to the affected playbook(s)**
until the user has either fixed it or explicitly acknowledged and accepted the risk.

If invoked as a gate from another skill (e.g. `weekly-playbook-analysis` Step 9, step 5), return
this same structure to the caller rather than a conversational summary, so the P0 check can
be enforced programmatically.

## Token Efficiency Notes

- `list_entities(entity_type="tools"/"variables"/"playbooks", detail="full")`: bulk calls, ~1-5k tokens each, once per run — more than `detail="minimal"` would cost, but minimal detail lacks the `enabled`/`scope`/`is_active` fields these checks depend on
- `list_entities(entity_type="handoffs", detail="minimal")`: ~200-500 tokens, once per run
- `list_entities(entity_type="tools", entity_id=...)` per code tool: three on 2026-09-30, a few KB
  each because the response carries the source code
- `list_entities(entity_type="playbooks", entity_id=...)`: full body, roughly **8-20k tokens per
  playbook**. This is by far the expensive call; only pull playbooks actually in scope, one at a
  time. (An earlier note here said 1-3k. Measured 2026-09-21: `V2 NEW: Tablo 4th Gen First-Time
  Setup [Voice]` returned 72.7 KB.)
- No `get_conversation` calls — this skill never touches conversation data

## DO / DON'T

**DO:**
- Enumerate every finding per severity tier — don't stop at the first
- Distinguish a true orphan (no writer anywhere) from a cross-playbook dependency (P2)
- Quote the exact step id / condition / template text for every finding, so it can be found
  and fixed without re-deriving the analysis
- Treat a P0 as a hard gate on promotion, not a suggestion
- Default to voice-reachable when a playbook has no channel condition. That is the case that has
  already cost a customer their recordings
- Quote a flagged message verbatim on every behavioural finding, so a person can overrule you

**DON'T:**
- Propose a specific fix for a P1 null-conflation finding — that's a product decision
- Write anything — this skill has no `edit_agent_behavior`/`edit_agent_config` calls at all
- Skip actions just because no playbook currently references them — an unbound output today
  can become tomorrow's bug the moment a playbook starts reading it
- Treat "no test case covers this" as evidence the check passed — this skill's checks are
  independent of test coverage
- Draft replacement copy for a behavioural finding. Report the defect and hand it to
  `playbook-authoring`, which owns the rules and the wording
- Flag a bare `send` next to a `run` that only covers latency. The docs sanction that use
