---
name: config-health
description: Structural integrity check for Ada-Tablo playbooks — finds variables a playbook reads but nothing writes, action outputs that were never bound to a variable, dangling entity references, null-check conflation, and cross-playbook variable contracts. Read-only. Run standalone before any cutover, or as a gate before promoting a playbook/coaching changeset.
user-invocable: true
allowed-tools: Read, Grep, Glob, AskUserQuestion, Skill
---

# Config Health — Playbook/Action/Variable Integrity Check

Finds the defect class that shipped in the Playbooks 2.0 cutover twice before anyone caught
it by hand: a playbook branches on a variable that nothing ever writes, so the branch always
reads null. Metrics and transcript review cannot surface this — it's a structural property of
the configuration, not an outcome. This skill reads that structure directly.

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

## Step 5: Run the Checks

Report every finding found, grouped by severity. This skill does not stop at the first
finding — enumerate all of them per playbook.

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

### P2 — Cross-playbook contract

Across all in-scope playbooks, build a table of variables written in one playbook and read in
another (e.g. a `device_type`/`board_type` classification variable set in Legacy Device
Detection and read in Connectivity). List each as a producer → consumer pair. This is not a
bug by itself — it's the map that makes the next rename or ID change break loudly instead of
silently. Flag specifically any pair where the producer playbook is `is_active: false` while
the consumer is `is_active: true` (an active playbook depending on an inactive one's output).

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
- `list_entities(entity_type="playbooks", entity_id=...)`: full body, ~1-3k tokens per
  playbook — this is the expensive call; only pull playbooks actually in scope
- No `get_conversation` calls — this skill never touches conversation data

## DO / DON'T

**DO:**
- Enumerate every finding per severity tier — don't stop at the first
- Distinguish a true orphan (no writer anywhere) from a cross-playbook dependency (P2)
- Quote the exact step id / condition / template text for every finding, so it can be found
  and fixed without re-deriving the analysis
- Treat a P0 as a hard gate on promotion, not a suggestion

**DON'T:**
- Propose a specific fix for a P1 null-conflation finding — that's a product decision
- Write anything — this skill has no `edit_agent_behavior`/`edit_agent_config` calls at all
- Skip actions just because no playbook currently references them — an unbound output today
  can become tomorrow's bug the moment a playbook starts reading it
- Treat "no test case covers this" as evidence the check passed — this skill's checks are
  independent of test coverage
