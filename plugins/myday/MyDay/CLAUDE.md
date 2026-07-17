# MyDay — Claude Context

This project is a daily planning and time-tracking workspace. It connects to your calendars via ICS feeds and uses structured daily logs for reflection and note-taking. It's the data folder the `myday` plugin skill reads and writes to.

## Project Structure

```
MyDay/
├── config.json             # ICS URLs (secret — do not share)
├── config.example.json     # Template
├── scripts/
│   ├── fetch_calendar.py   # Fetches and parses ICS feeds for a given date
│   └── requirements.txt    # icalendar, recurring-ical-events
└── logs/
    └── YYYY/MM/YYYY-MM-DD.md   # One file per day
```

## Calendar Setup

`config.json` must exist at the project root. Copy from `config.example.json` and fill in real ICS URLs. See setup instructions below.

## Fetching Calendars

```bash
python3 scripts/fetch_calendar.py              # today
python3 scripts/fetch_calendar.py --date 2026-05-01   # specific date
python3 scripts/fetch_calendar.py --json       # JSON output
```

Requires: `pip3 install -r scripts/requirements.txt`

## Daily Logs

Stored at `logs/YYYY/MM/YYYY-MM-DD.md`. Each file is built up over the day by the `myday` skill's flows — schedule, team Jira snapshot, optional backlog hygiene digest, meeting notes, start-of-day priorities, and end-of-day reflection.

---

## One-Time Setup

### Get Your Google Calendar ICS URL

1. Open [Google Calendar](https://calendar.google.com) → Settings (gear icon)
2. Select the calendar you want under "Settings for my calendars"
3. Scroll to **"Integrate calendar"**
4. Copy the **"Secret address in iCal format"** URL (starts with `https://calendar.google.com/calendar/ical/...`)

### Get Your Outlook ICS URL

**Option A — Outlook Web App (OWA / Microsoft 365)**
1. Go to [outlook.office.com](https://outlook.office.com) and sign in with your work account
2. Click the Settings gear → **View all Outlook settings**
3. Go to **Calendar → Shared calendars**
4. Under **"Publish a calendar"**, select your calendar and set permissions to "Can view all details"
5. Click **Publish** — copy the **ICS** link (not the HTML link)

**Option B — If your IT doesn't allow publishing**
Your IT team can generate a calendar ICS feed URL for you.

Once you have both URLs, add them to `config.json`.
