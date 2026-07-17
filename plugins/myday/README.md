# MyDay — Daily Planner Plugin

A Claude Code skill that helps you manage your workday: pulls your calendar, checks what your team is working on in Jira, keeps a daily log, tracks PTO and reminders, takes meeting notes, and drafts performance reviews.

---

## Requirements

- Claude Code with this marketplace added
- Atlassian MCP connector connected in Claude Code (for Jira) — this plugin bundles its own `.mcp.json` entry
- Python 3 with `pip3`
- An ICS feed URL for your calendar (Outlook or Google)
- VPN connected if your Outlook ICS feed is behind the corporate network

---

## Installation

### 1. Enable the plugin

Enable `myday` from this marketplace in Claude Code. This installs the `/myday` skill and connects the Atlassian MCP server.

### 2. Set up the MyDay project folder

Copy the `MyDay/` folder from this plugin somewhere on your machine — OneDrive is recommended so logs sync automatically:

```bash
cp -r MyDay ~/Library/CloudStorage/OneDrive-The\ E.W.\ Scripps\ Company/Documents/MyDay
```

### 3. Configure your calendar

Copy `MyDay/config.example.json` to `MyDay/config.json` and fill in your ICS feed URLs:

```json
{
  "calendars": [
    {
      "name": "Outlook Work",
      "ics_url": "https://outlook.office365.com/owa/your.email@scripps.com/calendar/.../calendar.ics"
    }
  ]
}
```

**To get your Outlook ICS URL:**
1. Go to outlook.office.com → Settings → Calendar → Shared calendars
2. Under "Publish a calendar", select your calendar and set to "Can view all details"
3. Click Publish and copy the ICS link

### 4. Install Python dependencies

```bash
pip3 install -r MyDay/scripts/requirements.txt
```

### 5. Create your personal config

Copy `myday-config.example.json` to `~/.claude/myday-config.json` and fill in your details:

```json
{
  "planner_dir": "/path/to/your/MyDay",
  "email": "your.name@scripps.com",
  "team": [
    { "name": "First Last" },
    { "name": "First Last" }
  ]
}
```

- **planner_dir**: full path to wherever you put the MyDay folder
- **email**: your Scripps email (used for Jira lookups)
- **team**: the people whose Jira work you want to track each morning

**Optional — backlog hygiene digest.** If you want the morning check to also flag ungroomed tickets (open, unassigned, no size) on your team's boards, add:

```json
{
  "backlog_boards": [
    { "label": "Team A", "project_key": "TEAMA" },
    { "label": "Team B", "project_key": "TEAMB" }
  ],
  "tshirt_size_field": "cf[11879]",
  "jira_base_url": "https://yourorg.atlassian.net"
}
```

- **backlog_boards**: Jira project keys to check each morning. Omit this to skip the check entirely.
- **tshirt_size_field**: your org's t-shirt-size custom field (e.g. `cf[11879]`). Only needed if `backlog_boards` is set.
- **jira_base_url**: your Jira instance's base URL, used to build a clickable link to the full ticket list. Optional even when `backlog_boards` is set — the digest just won't have a link.

---

## Usage

| Command | What it does |
|---|---|
| `/myday start` | Fetches calendar + Jira, creates today's log, captures your priorities |
| `/myday end` | Guided end-of-day reflection saved to the log |
| `/myday update` | Mid-day check-in — what's changed, optional Jira refresh |
| `/myday meeting` | Starts meeting note-taking mode |
| `/myday [name]` | Shows what a team member is working on |
| `/myday [name] last week` | Shows a team member's work over a time period |
| `[name] is out June 20-27` | Records PTO for a team member |
| `remind me to X` | Adds a todo, shown each morning |
| `done: X` / `mark X done` | Completes a todo |
| `write [name]'s review` | Pulls together a review draft from Jira + 1:1 notes |

### Natural language also works at any time:
- `"What is Anu working on?"` → team member lookup
- `"I'm in a meeting"` → starts note-taking mode
- `"Robb is on PTO next week"` → records PTO
- `"Remind me to follow up with legal"` → adds a reminder, resurfaced each morning until done
- `"Help me write a review for Jeff using jira tickets and meeting notes"` → review prep draft

### 1:1 meeting notes

If you name a meeting `[TeamMemberFirstName]<>[YourFirstName]` (e.g. `Jeff<>Todd`) when starting notes, MyDay recognizes it as a 1:1 and asks the recurring question "What success have you had recently?" The answer is tagged so Review Prep can pull it up later without re-reading every note.

---

## Daily Log

Each day's log is saved to `MyDay/logs/YYYY/MM/YYYY-MM-DD.md` and contains:

- **Schedule** — calendar events for the day
- **Team — Active Work** — Jira snapshot at start of day
- **Backlog Hygiene** — ungroomed ticket counts, if `backlog_boards` is configured
- **Meeting Notes** — one section per meeting
- **Start of Day — Priorities & Notes** — your focus for the day
- **End of Day — Reflection** — what got done, carry-forwards, notes for tomorrow

Reminders live separately in `~/.claude/todos.md` and are resurfaced each morning until you mark them done.

---

## Optional: Auto-launch at 9 AM

To have a Terminal window open with `/myday start` automatically every weekday morning:

**1. Create the launcher script** at `~/.claude/myday_launcher.sh`:

```bash
#!/bin/bash
caffeinate -u -t 2
sleep 5
CLAUDE_BIN=$(find "$HOME/Library/Application Support/Claude/claude-code" -name "claude" -not -path "*/Resources/*" -type f 2>/dev/null | sort -V | tail -1)
osascript <<EOF
tell application "Terminal"
    activate
    delay 2
    do script "\"$CLAUDE_BIN\" \"/myday start\""
end tell
EOF
```

```bash
chmod +x ~/.claude/myday_launcher.sh
```

**2. Create a Launch Agent** at `~/Library/LaunchAgents/com.myday.plist` — a `launchd` template that runs the launcher script on a weekday schedule, then load it:

```bash
launchctl load ~/Library/LaunchAgents/com.myday.plist
```

To disable: `launchctl unload ~/Library/LaunchAgents/com.myday.plist`

---

## Notes

- **VPN**: Outlook ICS feeds require VPN. If the calendar fetch fails at startup, connect to VPN and retry.
- **Jira**: Account IDs are looked up dynamically each session — no hardcoding needed.
- **PTO tracking**: Stored in `~/.claude/myday/team_pto.md` — persists across sessions and is checked automatically during team lookups.
- **Google Calendar**: Supported alongside Outlook. Add your Google ICS URL to `config.json`.
