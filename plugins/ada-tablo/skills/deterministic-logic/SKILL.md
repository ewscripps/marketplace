---
name: deterministic-logic
description: Move computable logic out of playbook prose and into a deterministic Ada tool — a code tool (sandboxed Python, the default) or an Answers Utility endpoint (evaljs JavaScript, the legacy path). Use whenever a playbook asks the reasoning engine to do something computable: validate or normalize a serial, compare version strings, classify a value into bands, do date math, count matches, check list membership. Also use when asked to build or fix a code tool, AU endpoint, evaljs action, or "ada/code" function. Writes via edit_agent_behavior changesets gated by config-health and a test run.
user-invocable: true
allowed-tools: Bash(node -e *), Bash(python3 *), Read, Grep, Glob, AskUserQuestion, Skill
---

# Deterministic Logic in Ada

A playbook `set` step with a prose instruction asks the reasoning engine to perform string
manipulation, arithmetic, or date math *probabilistically*. A deterministic tool does it
exactly, every time. This skill moves that logic where it belongs and wires the result back to
a variable.

The canonical example on this instance: `Tablo Device Issue & Replacement` spends a
15-line action description and two prose `set` steps teaching the model to extract the last six
characters of a serial, complete with "if you extract 5 characters, you made an error." That is
`clean[6:]`.

**Prefer an endpoint whenever the answer is computable.** Keep a prose `set` only when the task
genuinely requires judgment about what the customer meant. "Is this a valid serial" is
computable. "Did the customer sound frustrated" is not.

Origin: adapted from Anna Prince's (IPSY) `ada-utility-endpoint-creator`, shared at the Ada ACX
community meetup 2026-08-26. Her method note is in
`/Users/181085/Obsidian/Projects/Ada-Tablo/workspace/ipsy-variables-to-verdicts.md`.

## Step -1: Pre-Flight

Invoke `skill: "preflight"` to confirm MCP connectivity and the workspace clone.

## Step 0: Pick the Mechanism

This account is entitled to **both**. Verified 2026-08-27 by staging code tool
`6a9076a58a98c915a7ec2606`.

| | Code tool (`code_tool`) | AU endpoint (`api_tool` → evaljs) |
|---|---|---|
| Language | Restricted Python | JavaScript |
| Logic editable in place | **Yes** — `source_code` is updatable | **No** — logic lives in `request_body`, which is immutable |
| Changing the logic later | Edit and re-promote | Recreate the tool and rewire every playbook that calls it |
| Stage-time checking | Syntax, imports, builtin names | None |
| Input binding | `variable_id` per input, resolved automatically | `{{name}}` token in the JSON body |
| Output binding | JMESPath `key` + `variable_id` | Body `key` + `variable_name` |

**Default to a code tool.** The editability difference is decisive: a validator will need tuning
as new edge cases appear, and with an AU endpoint every tweak is a recreate-and-rewire.

Choose an AU endpoint only when editing an existing one, or when the logic genuinely needs
JavaScript. We run exactly one AU endpoint today (see Reference) and it is not a model to copy.

Before writing either, check for an existing tool that already does the job:
`list_entities(entity_type="tools", detail="full")`. Extend rather than near-duplicate.

## Step 1: Define the Contract

Write this down and confirm it with the user before any code:

- **Inputs** — variable name, id, and expected shape.
- **Computation** — one sentence.
- **Outputs** — flat key names, and the variable each binds to.

**Variables cannot be created through MCP.** Neither `edit_agent_behavior` (playbooks, tools,
coaching) nor `edit_agent_config` (topics, tests, glossary) can mint one. If an output needs a
variable that does not exist, the user must create it in the Ada dashboard first — surface that
as a blocking prerequisite with the exact name and type, and do not stage an output bound to a
variable you cannot verify with `list_entities(entity_type="variables")`.

An output with no variable to write to is still useful with `is_visible_to_llm: true` and
`save_as_variable: false` — the reasoner sees it, but it is not filterable in analytics.

## Step 2: Write It Readably First

Author multi-line and legible while you reason about it. Never reason directly in a compressed
form. Keep the readable version — it goes in the commit (Step 9).

## Step 3: The Rules That Are Load-Bearing

**3a. Never throw.** When an action fails, Ada returns `outcome.status: "failed"` with
**`return_values: null`** and parses no response body at all (confirmed from conversation
`6a8f5458e7a04fb3373cb681`). A tool that raises writes *nothing* to any bound variable, and the
playbook then branches on a null it may not check — silently. Always return a predictable
value with a reason code instead:

```python
result = {'serial_valid': False, 'sid': 'NONE', 'reason': 'wrong_length'}
```

This is why `device_status_error_code` sat at zero across 8,497 conversations: it was bound to
an error field on a call that only ever fails.

**3b. Return a reason code, not just a verdict.** A bare boolean tells you a serial failed. A
`reason` of `bad_prefix` / `wrong_length` / `not_hex` tells you *why*, across thousands of
conversations, and costs one extra dict key. This is the double-duty principle: one value gates
the retry now, the same value explains the failure distribution later.

**3c. Normalize before comparing.** Strip non-alphanumerics, fold case, and handle the null and
empty cases explicitly at the top. Compare strings case-insensitively.

**3d. Never interpolate a variable into source code.** Bind inputs (`variable_id` on a code
tool, a `{{name}}` token on an AU endpoint). Our live AU endpoint splices a variable straight
into the JS — `var lastSeenUTC = '{...|}{var:lastSeen|}';`. It works only because the value is
an ISO timestamp from our own API; a value containing a quote breaks the script, and the same
pattern on customer-typed input is a code-injection surface.

## Step 4: Code Tool Sandbox Constraints

Call `edit_agent_behavior(operation="describe_entity", entity_type="code_tool")` and read its
`notes` — those are authoritative and can move ahead of this list.

- **Restricted Python, not CPython.** No class definitions, `match`, `yield`, or `del` — those
  fail at stage time. `str.format()` and `%`-formatting fail at *run* time; **f-strings only**.
- **Importable:** `datetime`, `json`, `math`, `os`, `pathlib`, `re`, `sys`, `typing`. Notably
  absent: `base64`, `collections`, `functools`, `hashlib`, `itertools`, `random`, `string`,
  `time`, `urllib`, `uuid`. Several of those gaps are filled by bare functions needing no
  import: `uuid4()`, `sha256()`, `hmac_sha256()`, `b64encode()`, `b64decode()`, `quote()`,
  `urlencode()`, `get_variable()`, `set_variable()`, `fetch()`, `log()`. None can be aliased or
  passed to `map()`.
- **Must end on an expression.** Declared inputs are bound as locals; the final expression is
  the result. A snippet ending on an assignment, or on `None`, fails. Build the dict, then put
  the bare name on the last line.
- **Result must be JSON-serializable** — dict, list, str, int, float, bool, None. No tuples.
- **Dates:** `from datetime import datetime, date` — never bare `import datetime`. Do not
  compare `datetime.now()` (aware) with `fromisoformat()` (naive): the comparison returns
  `False` for `>`, `<` and `==` alike rather than raising, so the test is silently always false.
- **Staging checks syntax, imports, and builtin names — nothing else.** Your own undefined name
  or a wrong call signature stages clean, promotes clean, then fails on live traffic.
- **`inputs` and `outputs` are immutable after create.** Only `name`, `description`,
  `source_code`, `enabled`, `direct_use` are updatable. Get the contract right the first time.

## Step 5: Test Locally Before It Touches Ada

Non-negotiable, because staging will not catch a logic error. Build a case table covering the
happy path, malformed input, empty, null, and the `ask` step's `fallback_value` (usually
`NONE`) — a fallback arriving as a literal string is a real input.

For a code tool, check the sandbox shape as well as the behavior:

```
python3 - <<'PY'
import ast
src = open('snippet.py').read()
tree = ast.parse(src)
banned = tuple(t for t in (getattr(ast,n,None) for n in
              ('ClassDef','Delete','Yield','YieldFrom','Match')) if t)
assert not [type(n).__name__ for n in ast.walk(tree) if isinstance(n, banned)]
imports = {a.name for n in ast.walk(tree) if isinstance(n, ast.Import) for a in n.names}
assert imports <= {'datetime','json','math','os','pathlib','re','sys','typing'}
assert isinstance(tree.body[-1], ast.Expr), 'must end on an expression'
PY
```

Then run every case and print a table. Do not proceed while any case raises or returns a key
the declared outputs do not select.

If porting existing logic between languages (JS ↔ Python), run both and assert the outputs are
identical case-for-case rather than eyeballing them.

## Step 6: Stage on a Changeset

1. `edit_agent_behavior(operation="describe_entity", entity_type="code_tool")` —
   `change_type="created"` for new, `"modified"` for an edit. For an edit, read the live
   definition first; the ops repo and vault notes drift and are not source of truth.
2. Stage:
   ```
   edit_agent_behavior(
     operation="update",
     entity_type="code_tool",
     changeset_id="<existing id, or omit to auto-create>",
     name="<short generic label, e.g. 'Deterministic serial handling YYYY-MM-DD'>",
     changes=[{"entity_type": "code_tool", "change_type": "created", "fields": {...}}]
   )
   ```
   Nothing is live — this lands on a TESTING changeset.
3. Verify the diff:
   ```
   list_agent_changesets(changeset_id="<id>", include_diff=true)
   ```
   Confirm `diff.changed` shows only the intended fields, and that every `variable_id` is the
   one you meant.

Set `direct_use: false` unless the reasoner should be able to call the tool unprompted. A
validator invoked by a playbook step does not need direct use.

## Step 7: Gates — config-health, then a Test Run

**7a.** Invoke `/ada-tablo:config-health` scoped to the playbook that will call the tool.
Resolve any P0 before promoting; never stage on top of a known P0.

**7b.** `get_test_run_quota()`, then `get_test_cases()`, then create a run pinned to the
changeset so it exercises staged config:

```
edit_agent_config(entity_type="test_run", operation="create",
  fields={"test_case_ids": ["<id>", ...], "changeset_id": "<id>"})
```

Poll `get_test_runs(test_run_id="<id>")` until `completed`; any other terminal status blocks the
promote. Do not use `simulate_conversation` to verify a changeset — it evaluates live baseline
state and cannot pin to a changeset.

**Test runs execute Actions live against production.** Check what the exercised playbook path
calls before running.

## Step 7c: Staleness Gate — re-read the diff immediately before promoting

**A staged changeset goes stale silently when the live config moves underneath it.** An edit
carries the entity's *whole* field set, so a field you never intended to change is still in the
payload. While the changeset sits, someone may improve that field live. Promoting then reverts
their work, with no warning anywhere.

This is not hypothetical. On 2026-08-28 a changeset staged overnight would have reverted ~1,050
characters of live guidance on `V2 Legacy Device Detection`, including new instructions about the
September 1 2026 end of support, because the live `description` and `general_instructions` had
been improved after staging. It surfaced only because the diff was re-read right before promote.

Immediately before every promote, re-pull and check:

```
list_agent_changesets(changeset_id="<id>", include_diff=true)
```

For each edited entity, assert `diff.changed` contains **only** the fields you meant to change.
Any extra key means the live value moved and your snapshot is stale.

To fix a stale field, restage the edit carrying the **current live value** (the diff's `before`
side) alongside your intended change. A `fields` update **replaces** the edit wholesale, so every
field you want kept must be present in the payload — sending only your intended field silently
drops the others from the edit.

This response is large (hundreds of KB and up). Never read it into context; let it spill to a
file and assert over it with a script.

## Step 8: Confirm, Then Promote

Present the verified diff, the local test table, and the test-run result. Use
`AskUserQuestion` with Confirm/Cancel. Only after explicit confirmation:

```
edit_agent_behavior(operation="promote", changeset_id="<id>", confirmed=true)
```

Echo back any `warnings_token` from the unconfirmed preview. Never confirm on the user's
behalf. To walk back: `operation="remove"` (one entity), `"delete"` (whole changeset, still
testing), `"revert"` (already promoted).

## Step 9: Verify It Actually Writes, Then Record It

A tool that promotes clean can still never fire. After 24h of traffic:

```
get_ada_metric(metric_type="conversation_volume_engaged", start_date=..., end_date=...,
  filters=[{"type":"VARIABLE","operator":"ISSET","item":"<variable id>","value":[]}])
```

Zero means the binding or the playbook path is wrong. Do not call the work done on the strength
of a clean promote — `device_status_error_code` promoted clean and never wrote once.

Then invoke `skill: "commit-results"` with `"deterministic-logic"` to record the readable
source, the case table, and the variable contract in `~/repos/ada-tablo-ops/reference/`. MCP
does not return an api tool's `request_body` at all, and a code tool's `source_code` is only
readable through a changeset — if it is not written down, the logic exists in one place nobody
can review.

## Reference: What We Already Run

**Code tool — `Validate and Normalize Tablo Serial`** (`6a9076a58a98c915a7ec2606`, staged on
changeset `6a9076a48a98c915a7ec2600` 2026-08-27). Replaces three prose `set` steps: sanitize
(`6a6a48068bcdd34a3a0000a1`), validate (`6a6a4821da9a7347900000c6`), and SID extraction
(`6a6a5034f02e499912000154`). Input `raw_serial` bound to `6a6a47a5132ee6ce855b83f9`; outputs
`sanitized_serial`, `serial_valid`, `sid`, plus a non-persisted `reason`. Verified on 15 cases
including colon-separated MACs, lowercase, letter-O-for-zero, the `508788`→`5087B8`
speech-to-text mishearing, six-character SID-only input, real model numbers customers read out
by mistake, and null.

**AU endpoint — `Compare last seen to current time`** (`692df80ad6eb0821022fb88c`), POST to
`https://answer-utilities.svc.ada.support/evaljs`, referenced by 4 of the 7 active playbooks:

```json
{
  "ada/code": "var lastSeenUTC = '{690bb877cfa1b18a0c01a7e8|}{var:lastSeen|}'; if (!lastSeenUTC) return false; var lastSeen = new Date(lastSeenUTC); var now = new Date(); var diffMinutes = (now - lastSeen) / (1000 * 60); return diffMinutes <= 60;"
}
```

Output `result` → `last_seen_within_60_min` (`692df823970272571ef60936`). It works — 563 true /
721 false in Aug 2026 — and demonstrates three things not to copy: variable interpolation into
source instead of binding; a bare top-level `return` rather than a named handler; and two
concatenated tokens, `{690bb877cfa1b18a0c01a7e8|}` and `{var:lastSeen|}`, where the first id
matches no variable in the account. It resolves to empty and the name-based token supplies the
value, so the result is right by accident. Reference a variable once, by id.

Its `request_body` is only readable through the Ada REST API
(`GET /api/v2/actions/<id>` with `ADA_API_TOKEN`), which returns `url`, `headers`, and
`request_body` — all of which MCP omits.

## Final Checklist

- Mechanism chosen deliberately (code tool unless editing an existing AU endpoint)
- Every target variable exists and its id verified via `list_entities`
- Snippet ends on an expression; result is JSON-serializable; f-strings only
- Only sandbox-importable modules; no class/`match`/`yield`/`del`
- Never raises — returns a predictable value plus a `reason` code
- Inputs bound by `variable_id` / token, never interpolated into source
- Outputs' JMESPath `key` matches the returned dict keys exactly
- Local case table green: happy path, malformed, empty, null, and the `NONE` fallback
- Ported logic asserted identical against the original, case-for-case
- `config-health` clean of P0; test run completed without regression
- User explicitly confirmed the promote
- `ISSET` count checked 24h after promote
- Readable source and variable contract committed to `ada-tablo-ops/reference/`

## Token Efficiency Notes

- `list_entities(entity_type="tools", detail="full")` — ~4k for all 15 tools. Covers Step 0's
  duplicate check in one call.
- `list_entities(entity_type="variables", detail="minimal")` — ~3k for 161 variables. `full`
  adds only scope and type.
- `list_entities(entity_type="playbooks", entity_id=...)` — 8–12k per playbook body. Pull only
  the one that will call the tool.
- `describe_entity` — ~4k for `code_tool` (the sandbox notes are long but authoritative); once
  per entity type per session.
- `get_improvement_guide()` — ~6k, once per session, required before the first write.
- `get_conversation` — ~13k and frequently over the tool cap; it spills to a file. Never use it
  to check whether a tool fired; Step 9's `ISSET` count answers that for ~200 tokens.

## DO / DON'T

**DO**
- Replace a prose `set` with a tool whenever the logic is computable
- Return a `reason` code alongside every verdict
- Build the local case table before staging; staging catches syntax, not logic
- Bind every output to a variable id you have verified exists
- Check an `ISSET` count 24h after promote
- Re-read the diff immediately before promoting and confirm `diff.changed` holds only your intended fields
- Write the source into `ada-tablo-ops/reference/` — MCP cannot read it back

**DON'T**
- Let a tool raise; a failed action writes nothing at all, silently
- Interpolate a variable into source code
- Assume `inputs`/`outputs` can be fixed later — they are immutable after create
- Bare `import datetime`, or compare an aware datetime to a naive one
- End a snippet on an assignment or on `None`
- Ask the user to create a variable *after* staging an output bound to it
- Promote without the config-health, test-run, and staleness gates, or without explicit confirmation
- Assume a changeset staged hours ago still matches live; re-read the diff or you may revert someone's work
- Build a tool for a judgment call — that stays a prose `set`
