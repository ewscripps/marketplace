---
name: myday
description: Daily planner — morning calendar/Jira briefing, mid-day check-ins, end-of-day reflection, team lookups, PTO tracking, meeting notes, reminders, and review prep
user-invocable: true
argument-hint: '[start|update|end|meeting|<name>|<PTO statement>|<reminder>|review <name>]'
allowed-tools: Bash(python3 *), Bash(pip3 install *), Bash(grep *), Read, Write, Edit, Grep, Glob, AskUserQuestion
---

# My Day

Help the user manage their workday.

**If `$ARGUMENTS` was passed** (e.g. `start`, `end`, `update`), map it immediately and skip the opening question:
- `start` / `begin` / `morning` → Flow A
- `update` / `checkin` / `check-in` / `mid` → Flow B
- `end` / `wrap` / `done` / `close` → Flow C
- A person's name or a question about the team (e.g. `anu`, `what is robb working on`) → Flow D
- A PTO statement (e.g. `anu is on pto next week`, `robb is out june 20–27`, `john is OOO from the 15th to the 22nd`) → Flow E
- `start meeting` / `meeting` / `meeting: [name]` → Flow F
- A review-writing request naming a person (e.g. `help me write a review for Jeff using jira tickets and meeting notes`, `write Anu's review`, `review prep for Robb`) → Flow H

**If no argument was passed**, ask: **"Are you starting your day, checking in mid-day, or wrapping up?"** and wait for the answer before proceeding.

**Also listen for team member queries** at any point — e.g. "what is Anu working on?", "what did Robb do last week?", "show me John's work this month." If the input matches that pattern (person name + optional time period), skip the opening question and go directly to **Flow D**.

**Also listen for PTO statements** at any point — e.g. "[name] is on PTO from [date] to [date]", "[name] is out [date range]", "[name] is OOO [dates]". If the input matches that pattern, go directly to **Flow E**.

**Also listen for todo/reminder statements** at any point:
- Add: "remind me to X", "add reminder: X", "don't let me forget X" → **Flow G (Add)**
- Complete: "I did X", "done: X", "finished X", "mark X done" → **Flow G (Complete)**

**Also listen for review-writing requests** at any point — e.g. "help me write a review for Jeff using jira tickets and meeting notes", "write Anu's review", "review prep for Robb." If the input matches that pattern (review + person name), go directly to **Flow H**.

---

## Configuration

This skill requires a config file at `~/.claude/myday-config.json`. Read it at the start of any flow that needs it (A, B, C, D, E, F). If it doesn't exist, display this setup message and stop:

```
myday isn't configured yet. Create ~/.claude/myday-config.json with the following:

{
  "planner_dir": "/path/to/your/MyDay",
  "email": "you@company.com",
  "team": [
    { "name": "First Last" },
    { "name": "First Last" }
  ]
}

- planner_dir: folder where your daily logs and calendar scripts live
- email: your work email (used for Jira lookups)
- team: list of people whose Jira work you want to track
```

Once the config is read, use these values throughout:
- `{PLANNER_DIR}` = `config.planner_dir`
- `{EMAIL}` = `config.email`
- `{TEAM}` = `config.team` (array of names)
- Jira cloud ID = `f1b0109f-4589-41f1-be54-d5789b627577` (constant for all Scripps users)
- PTO memory file = `~/.claude/myday/team_pto.md`
- Todos file = `~/.claude/todos.md`
- Backlog hygiene boards (optional) = `config.backlog_boards`, an array of `{ "label": "...", "project_key": "..." }`. If not set, skip Flow A2.5 entirely.
- T-shirt size field (optional) = `config.tshirt_size_field`, e.g. `"cf[11879]"` — your org's t-shirt-size custom field. Required only if `backlog_boards` is set.
- Jira base URL (optional) = `config.jira_base_url`, e.g. `"https://yourorg.atlassian.net"` — used to build a clickable link in the Flow A2.5 digest. Omit the link if not configured.

If your config includes the optional backlog hygiene fields, it looks like:

```json
{
  "planner_dir": "/path/to/your/MyDay",
  "email": "you@company.com",
  "team": [{ "name": "First Last" }],
  "backlog_boards": [
    { "label": "Team A", "project_key": "TEAMA" },
    { "label": "Team B", "project_key": "TEAMB" }
  ],
  "tshirt_size_field": "cf[11879]",
  "jira_base_url": "https://yourorg.atlassian.net"
}
```

---

## Flow A — Start

### A0. Open Todos

Read `~/.claude/todos.md`. If it doesn't exist or has no open items, skip silently.

Find all lines matching `- [ ] ...` (open todos). For each, check if it has a `(due: ...)` tag:
- If the due date is today or in the past → mark as **overdue** and show first
- If due within the next 7 days → show normally
- If no due date or due date is further out → show normally

Display as:

> **Reminders:**
> - ⚠ [overdue item] (due: [date])
> - [open item]
> - [open item]

Keep it brief — one line per item. If all todos are future-dated with no urgency, still show them so nothing is forgotten.

### A0.5. Recap Yesterday's Meeting Notes

Read yesterday's log at `{PLANNER_DIR}/logs/YYYY/MM/YYYY-MM-DD.md` (yesterday's actual date). Scan for any `## Meeting Notes —` sections. If any exist, display them as a brief recap before doing anything else:

> **Yesterday's meeting notes:**
> - **[Meeting Name]:** [bullet 1], [bullet 2], ...

Keep it tight — one line per meeting, bullets summarized to action items or key points. If there are no meeting notes sections in yesterday's log, skip this step silently.

### A1. Fetch Today's Schedule

```bash
cd "{PLANNER_DIR}" && python3 scripts/fetch_calendar.py
```

If it fails due to missing packages:
```bash
pip3 install -r "{PLANNER_DIR}/scripts/requirements.txt"
```
Then retry. Display the schedule clearly.

### A2. Check What the Team Is Working On

Use the Atlassian MCP tools to pull active Jira work.

**Step 0 — Check PTO.** Read `~/.claude/myday/team_pto.md` (if it exists). For each team member, check if today's date falls within any of their PTO windows. Keep a list of who is out today — they will be flagged in the output instead of showing Jira tickets.

**Step 1 — Look up account IDs.** For each person in `{TEAM}`, call `lookupJiraAccountId` using their display name. For the user themselves, use `{EMAIL}`. Collect all resolved IDs.

**Step 2 — Query active issues.** Run `searchJiraIssuesUsingJql`:
```
assignee in ("<id1>", "<id2>", ...) AND statusCategory = "In Progress" ORDER BY assignee ASC
```
Using `statusCategory = "In Progress"` instead of specific status names ensures custom board statuses (e.g. "Dev in Progress", "Dev Review") are all captured correctly across different boards.
If any lookup fails, skip that person and note it.

**Step 3 — Ask the user.** After showing Jira results: **"Anything your team is working on that isn't in Jira?"** Incorporate any additions.

**Step 4 — Format** grouped by person: ticket key, summary, status — one line per ticket. If someone has nothing active, note "nothing active in Jira." If someone is on PTO today (from Step 0), show **"on PTO today"** instead of their tickets.

### A2.5. Backlog Hygiene Check (optional)

Skip this step entirely if `config.backlog_boards` is not set.

Query for ungroomed tickets on each configured board — open tickets missing both a t-shirt size and an assignee. Run one query per board so each has its own count:

```
project = {project_key} AND statusCategory != Done AND assignee is EMPTY AND {tshirt_size_field} is EMPTY
```

Use `computeIssueCount: true` and `maxResults: 1` — this check only needs totals, not the full ticket list (large backlogs can return 100+ matching tickets, too many to list daily).

Format as a count-only digest:

> **Backlog hygiene — needs size + owner:**
> - {label}: [N] tickets
> - {label}: [N] tickets
> - [Full list]({jira_base_url}/issues/?jql=...) — only if `config.jira_base_url` is set; build the link from a combined JQL across all configured project keys, e.g. `project in ({key1}, {key2}) AND statusCategory != Done AND assignee is EMPTY AND {tshirt_size_field} is EMPTY`, URL-encoded

If all counts are 0, skip this section silently (don't show an empty header).

### A3. Create or Open Today's Log

Log path: `{PLANNER_DIR}/logs/YYYY/MM/YYYY-MM-DD.md` (today's actual date). Create year/month subdirectory if needed.

If the log doesn't exist, create it:

```markdown
# Daily Log — [Full date, e.g. Friday, June 12, 2026]

## Schedule
[paste formatted schedule output here]

## Team — Active Work
[paste Jira team summary here, including any additions the user mentioned]

## Backlog Hygiene — [board labels]
[paste backlog hygiene results here, or omit this section if not configured or nothing found]

## Start of Day — Priorities & Notes
[to be filled in]

## End of Day — Reflection
[to be filled in]
```

If it already exists, read it for context.

### A4. Ask for Priorities

Ask: **"What are your top priorities for today?"** and **"Anything you want to flag or watch out for?"**

Append answers under `## Start of Day — Priorities & Notes`.

### A5. Close

2-3 sentences: key meetings, focused blocks between them, any busy stretches, and a one-line read on where the team's attention is today. No fluff.

---

## Flow B — Update

### B1. Read Today's Log

Read `{PLANNER_DIR}/logs/YYYY/MM/YYYY-MM-DD.md`. Summarize in one sentence what the plan was at start of day.

### B2. Ask What's Changed

Ask these two questions, waiting for each answer:

1. **"What have you gotten done so far?"**
2. **"What's shifted — any new priorities, blockers, or things you've dropped?"**

### B3. Refresh Team Jira (Optional)

Ask: **"Want me to re-check what the team is up to in Jira?"**

If yes, repeat steps A2 Step 1–4. If no, skip.

### B4. Save Mid-Day Notes

Append to the log under a new section:

```markdown
## Mid-Day Update — [HH:MM]

**Progress so far:**
[answer]

**Shifts in priorities or blockers:**
[answer]

**Team Jira refresh:**
[results or "skipped"]
```

### B5. Close

One sentence: where the afternoon is headed given what's shifted. No fluff.

---

## Flow C — End

### C0. Which Day?

Before anything else: if the current time is before noon, ask — **"Are you closing out yesterday (YYYY-MM-DD) or today (YYYY-MM-DD)?"** (fill in both actual dates).

Use whichever date is confirmed for all log reads and writes in this flow.

If it's afternoon or evening, assume today and skip this question.

### C1. Pull Up Today's Context

Read the log for the confirmed date (`{PLANNER_DIR}/logs/YYYY/MM/YYYY-MM-DD.md`). If it doesn't exist, run the calendar fetch to reconstruct the day:
```bash
cd "{PLANNER_DIR}" && python3 scripts/fetch_calendar.py
```

### C2. Jira Check Reminder

**"Before we wrap up — have you updated your Jira tickets for today?"**

### C3. Lead a Short Reflection

Ask these three questions **one at a time**, waiting for each answer:

1. **"What did you get done today?"**
2. **"What didn't happen that needs to move forward?"**
3. **"Any notes for tomorrow — blockers, things to prep, or people to follow up with?"**

### C4. Save the Reflection

Append to the log under `## End of Day — Reflection`:

```markdown
## End of Day — Reflection

**Accomplished:**
[answer]

**Carry forward:**
[answer]

**Notes for tomorrow:**
[answer]
```

### C5. Tomorrow's Look Ahead

Fetch tomorrow's schedule:
```bash
cd "{PLANNER_DIR}" && python3 scripts/fetch_calendar.py --date YYYY-MM-DD
```
(Use tomorrow's actual date.) Display it clearly.

### C6. Close

One sentence: what got done and one clear next action for tomorrow. No motivational fluff.

---

## Flow D — Team Member Query

Triggered when the user asks about a specific person's work, e.g.:
- "What is Anu working on?"
- "What did Robb do last week?"
- "Show me John's tickets this month"
- "What has Mason been up to?"

### D1. Parse the Request

Extract:
- **Person** — match against `{TEAM}` (fuzzy match first names)
- **Time period** — map natural language to a Jira date range:

| Phrase | JQL date filter |
|---|---|
| today | `updated >= startOfDay()` |
| yesterday | `updated >= startOfDay(-1) AND updated < startOfDay()` |
| this week | `updated >= startOfWeek()` |
| last week | `updated >= startOfWeek(-1) AND updated < startOfWeek()` |
| this month | `updated >= startOfMonth()` |
| last month | `updated >= startOfMonth(-1) AND updated < startOfMonth()` |
| last 30 days | `updated >= -30d` |
| last 90 days / this quarter | `updated >= -90d` |
| (no time period given) | default to `updated >= -30d` |

### D1.5. Check PTO Memory

Read `~/.claude/myday/team_pto.md` (if it exists). Find any entry for this person. Compare their PTO windows against today's date:

- If today falls within a PTO window → note it as **currently on PTO through [end date]**
- If a PTO window starts within the next 14 days → note it as **upcoming PTO [start] – [end]**
- If a PTO window has already ended → ignore it

Surface any active or upcoming PTO as the **first line** of the output, before any Jira results.

### D2. Look Up Account ID

Call `lookupJiraAccountId` for the person using their display name. Use cloudId `f1b0109f-4589-41f1-be54-d5789b627577`.

### D3. Query Jira

Run two queries in parallel:

**Active work** (what they have open right now):
```
assignee = "{accountId}" AND status in ("In Progress", "In Review") ORDER BY updated DESC
```

**Work during the time window** (includes completed items):
```
assignee = "{accountId}" AND updated >= {startDate} ORDER BY updated DESC
```

Deduplicate across both result sets by issue key.

### D4. Scan Daily Logs

Search the daily logs for mentions of the person during the time window:
```bash
grep -ril "{first name}" "{PLANNER_DIR}/logs/" | sort | tail -30
```
Read any matching log files and extract relevant notes about that person (1:1 mentions, priorities flagged, blockers noted).

### D5. Present the Summary

Format as:

**[Name] — [time period]**

*Active in Jira:*
- KEY-123 — Summary (status)

*Completed / updated in Jira during this period:*
- KEY-456 — Summary (Done)

*Notes from daily logs:*
- [date]: [relevant note]

Keep it scannable. If nothing shows up in a section, omit that section header rather than showing it empty.

---

## Flow E — Record PTO

Triggered when the user says a teammate is on PTO, out, or OOO for a date range.

### E1. Parse the Statement

Extract:
- **Person** — fuzzy-match first name to `{TEAM}`
- **Start date** — convert any natural language to an absolute YYYY-MM-DD date using today's actual date as the reference
- **End date** — same conversion; if only one date is given, use it as both start and end

### E2. Update the PTO Memory File

Read `~/.claude/myday/team_pto.md`. If it doesn't exist, create the `~/.claude/myday/` directory and the file with this header:

```markdown
# Team PTO

PTO windows for team members. Checked automatically during team lookups.

```

Find the existing entry for this person (if any) and replace it. Otherwise append a new entry. Each entry uses this format:

```
**[Full Name]**
- [YYYY-MM-DD] to [YYYY-MM-DD]
```

A person can have multiple PTO lines (one per window). Keep past windows as a record.

### E3. Confirm

Reply in one line: **"Got it — [Name] is on PTO from [start] to [end]. I'll flag it when you ask about them."**

---

## Flow F — Meeting Notes

Triggered by: `start meeting`, `meeting`, `meeting: [name]`, or any phrase like "I'm in a meeting" / "taking notes for [meeting name]".

### F1. Identify the Meeting

If a meeting name was provided in the trigger (e.g. `meeting: Robb<>Todd`), use it directly.

If not, read today's log (`{PLANNER_DIR}/logs/YYYY/MM/YYYY-MM-DD.md`) and check the Schedule section. Find the meeting that is closest to the current time and suggest it: **"Starting notes for [meeting name]? Or tell me the name."** Wait for confirmation or correction.

**Is it a 1:1?** A meeting name matching `{TeamMemberFirstName}<>{YourFirstName}` (e.g. `Jeff<>Todd`) is a 1:1 with that teammate.

### F2. Enter Note-Taking Mode

Confirm with one line:

> **In: [Meeting Name]. Type your notes — I'll capture everything. Say "end meeting" when done.**

If this is a 1:1 (per F1), add a second line prompting the success question:

> **Ask [Teammate]: "What success have you had recently?"**

From this point on, treat every message as a meeting note. Acknowledge each one with just **"noted."** — nothing more. Do not summarize, ask questions, or respond with anything else until "end meeting" is received.

### F3. End and Save

When the user says `end meeting`, `done`, `stop`, or `end`:

1. Read today's log to find the right insertion point.
2. Append a new section to the log:

```markdown
## Meeting Notes — [Meeting Name] — [HH:MM]

- [note 1]
- [note 2]
- [note 3]
...
```

Format each captured input as a bullet. Preserve the user's words exactly — do not paraphrase or clean up.

If this is a 1:1 (per F1), the first note captured is the answer to the success question — save it as `- **Success:** [note 1]` instead of a plain bullet. This tag is how Flow H later finds successes without re-reading every note.

### F4. Confirm

Reply in one line: **"Saved [N] notes for [Meeting Name]."**

---

## Flow G — Todos & Reminders

### G — Add a Todo

Triggered by: "remind me to X", "add reminder: X", "don't let me forget X", or similar.

1. Extract the task description from the statement.
2. Extract any due date or timeframe (e.g. "in early July" → an absolute date, "next week" → approximate date). If none, store without a due date.
3. Read `~/.claude/todos.md`. If it doesn't exist, create it:

```markdown
# MyDay — Reminders

```

4. Append the new todo:
   - With due date: `- [ ] [task] (due: [date])`
   - Without: `- [ ] [task]`

5. Reply in one line: **"Added: [task][ — due [date]]"**

---

### G — Complete a Todo

Triggered by: "I did X", "done: X", "finished X", "mark X done", or similar.

1. Read `~/.claude/todos.md`.
2. Fuzzy-match the user's description against open `- [ ]` items.
3. If a match is found, change `- [ ]` to `- [x]` on that line.
4. Reply in one line: **"Done: [task]. Removed from your reminders."**
5. If no match found, list the open todos and ask which one to mark done.

---

## Flow H — Review Prep

Triggered by a review-writing request naming a person, e.g. "help me write a review for Jeff using jira tickets and meeting notes", "write Anu's review", "review prep for Robb."

### H1. Parse the Request

Extract:
- **Person** — fuzzy-match against `{TEAM}`
- **Time period** — if the user stated one, map it using the table in D1. If none was stated, ask: **"What period should this review cover?"** and wait for the answer. Reviews are tied to a review cycle, so don't guess a default window.

### H2. Query Jira

Look up the person's account ID (`lookupJiraAccountId`, per D2), then run:

```
assignee = "{accountId}" AND updated >= {startDate} ORDER BY updated DESC
```

Group results by status: completed/Done work is the strongest review evidence; still-open work provides supporting context on scope and ownership.

### H3. Scan Meeting Notes for Successes

```bash
grep -rl "## Meeting Notes — {first name}<>" "{PLANNER_DIR}/logs/"
```

Read each matching log dated within the time period. Pull every `- **Success:**` bullet — these are direct answers to the recurring 1:1 success question (see Flow F).

Older logs won't have the tag (it was introduced later). For those, use judgment to pull bullets that describe an accomplishment, a shipped thing, or positive feedback, and note them as untagged so the user knows they're inferred rather than a direct quote.

### H4. Present a Review Draft

Format as:

**[Name] — review draft, [time period]**

*Completed in Jira:*
- KEY-123 — Summary (Done, [date])

*Still in progress / supporting context:*
- KEY-456 — Summary (status)

*Successes from 1:1s:*
- [date]: [success bullet]

*Possible successes (inferred, not tagged):*
- [date]: [bullet]

Keep it scannable and ready to paste into a review doc. Omit any section with nothing in it rather than showing it empty.
