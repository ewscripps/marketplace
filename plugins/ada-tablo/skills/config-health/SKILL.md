---
name: config-health
description: Structural and behavioural integrity check for Ada-Tablo playbooks. Finds variables a playbook reads but nothing writes, action outputs that were never bound to a variable, dangling entity references, null-check conflation, cross-playbook variable contracts, and how the playbook behaves on a call: a destructive warning delivered in the same breath as the instruction that triggers it, consecutive sends with no ask on voice, fixed messages carrying multi-step manual instructions, unguarded tool failure paths, and steps that contradict the playbook's own general guidelines. Read-only. Run standalone before any cutover, or as a gate before promoting a playbook/coaching changeset.
user-invocable: true
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

`tools` full detail carries `inputs[]` and, critically, `outputs[]` — each output carries
`key` (the field read from the API response), `save_as_variable`, `variable_name`, and
`enabled` on the tool itself. `variables` full detail carries `scope` (needed by Step 4's
meta/auto_capture check). `playbooks` full detail (bulk call, no `entity_id`) carries
`is_active` for every playbook cheaply, without pulling full step trees — that's still done
per-playbook in Step 3. `handoffs` has no fields these checks depend on, so minimal is enough
there.

## Step 2: Select Scope

Ask the user (AskUserQuestion) which playbooks to check:
- **All active playbooks** (default, recommended before any cutover or weekly run)
- **A specific playbook or set** (e.g. the ones a pending recommendation touches — this is
  the mode `weekly-playbook-analysis` Step 9a calls with)

## Step 3: Pull Full Playbook Bodies

For each in-scope playbook:

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
- `on_human_request` / `on_off_topic` / `on_off_script` say whether the playbook has a knowledge exit
  or is a dead end.

## Step 4: Build the Write-Set and Read-Set (per playbook)

Walk every step in every section, including nested `if_else` branches recursively. For each
playbook, build two sets of variable IDs:

**Writes** — a variable is written if:
- A `set` step targets it (`variable_id`), regardless of whether `value` is a literal, a
  `{{ variable:OTHER_ID }}` template, or null with `instruction` (LLM-derived).
- An `ask` step targets it (`variable_id`).
- It is the `variable_name` of an output (with `save_as_variable: true`) on an action that a
  `run` step in this playbook invokes (`target_type: "action"`, `target_id` = the action).
- It is a meta/auto_capture-scope global (populated by the platform itself, not by any step —
  treat these as always-written; cross-check the variable's `scope` field from Step 1's
  `variables` list if uncertain).

**Reads** — a variable is read if:
- It appears as `left_operand` or `right_operand` in an `if_else` condition.
- It appears as `{{ variable:ID }}` inside any `instruction`, `message`, `exact_words`, or
  `set.value` string, anywhere in the playbook (including nested branches).

**Voice-reachable** is a third derivation, used only by the behavioural checks. A playbook is
voice-reachable when either:
- its `availability_rules` contain a condition on the channel variable
  `65eb4a21c9f9e85c0294ab92` with value `voice`; **or**
- it has **no channel condition at all** (including no `availability_rules` key), which means it is
  reachable on every channel with one set of copy.

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
- Flag if `save_as_variable: true` and `variable_name` is null, empty, or not a real variable
  id from the Step 1 `variables` list.
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

Walk it per execution path, not per node. Four rules make the difference between a useful finding
and a noisy one. Each was got wrong once while building this check and corrected against
the live FTS [Voice] body:

1. **Sibling `if_else` branches are alternatives, never a sequence.** Each branch inherits the run
   arriving at the conditional and produces its own continuation. Concatenating two branches into
   one run reports sends that can never be spoken on the same call.
2. **A run can span a section boundary.** Sections are an authoring convenience; nothing waits
   between them. Scan the playbook as one sequence.
3. **Report only maximal runs.** A path of three sends also contains two runs of two. Report the
   longest run per path and drop anything contained in it, or one defect reads as four findings.
4. **`set` and `go_to` do not break a run**, because neither is spoken and neither waits. `ask` breaks it,
   because that is the step that waits. `run` breaks it too, but a run of two or more sends
   arriving at a `run` step is still reported: the caller heard both.

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

Use `list_entities(entity_type="tools", detail="full")` to build the tool-to-status map, never
`get_ada_configuration()`. Measured 2026-09-21: the configuration call returns 8 tools and the
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

## Step 6: Report

Structure the output severity-first:

```
## Config Health Report — [scope] — [date]

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

If invoked as a gate from another skill (e.g. `weekly-playbook-analysis` Step 9a), return
this same structure to the caller rather than a conversational summary, so the P0 check can
be enforced programmatically.

## Token Efficiency Notes

- `list_entities(entity_type="tools"/"variables"/"playbooks", detail="full")`: bulk calls, ~1-5k tokens each, once per run — more than `detail="minimal"` would cost, but minimal detail lacks the `enabled`/`scope`/`is_active` fields these checks depend on
- `list_entities(entity_type="handoffs", detail="minimal")`: ~200-500 tokens, once per run
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
