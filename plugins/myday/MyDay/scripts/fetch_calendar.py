#!/usr/bin/env python3
"""Fetches today's (or a given date's) events from configured ICS calendar feeds."""

import json
import sys
import argparse
from datetime import datetime, date, timedelta
import urllib.request
from pathlib import Path

try:
    from icalendar import Calendar
    import recurring_ical_events
except ImportError:
    print("ERROR: Missing dependencies. Run: pip3 install -r scripts/requirements.txt", file=sys.stderr)
    sys.exit(1)

PROJECT_ROOT = Path(__file__).parent.parent
CONFIG_FILE = PROJECT_ROOT / "config.json"


def load_config():
    if not CONFIG_FILE.exists():
        print("ERROR: config.json not found.", file=sys.stderr)
        print(f"Copy config.example.json to config.json and fill in your ICS URLs.", file=sys.stderr)
        sys.exit(1)
    with open(CONFIG_FILE) as f:
        return json.load(f)


def fetch_ics(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "PlannerBot/1.0"})
    with urllib.request.urlopen(req, timeout=20) as response:
        return response.read()


def get_events_for_date(ics_data: bytes, calendar_name: str, target_date: date) -> list:
    cal = Calendar.from_ical(ics_data)
    start_dt = datetime(target_date.year, target_date.month, target_date.day, 0, 0, 0)
    end_dt = start_dt + timedelta(days=1)

    events = recurring_ical_events.of(cal).between(start_dt, end_dt)
    results = []

    for event in events:
        dtstart = event.get("DTSTART")
        dtend = event.get("DTEND")
        if dtstart is None:
            continue

        dtstart = dtstart.dt
        dtend = dtend.dt if dtend else dtstart

        all_day = isinstance(dtstart, date) and not isinstance(dtstart, datetime)

        if all_day:
            time_str = "All day"
            sort_key = datetime.combine(dtstart, datetime.min.time())
        else:
            # Normalize timezone-aware datetimes for display
            def fmt(dt):
                if hasattr(dt, "astimezone"):
                    dt = dt.astimezone()
                return dt.strftime("%-I:%M %p")
            time_str = f"{fmt(dtstart)} – {fmt(dtend)}"
            sort_key = dtstart.replace(tzinfo=None) if hasattr(dtstart, "tzinfo") else dtstart

        summary = str(event.get("SUMMARY", "No Title"))
        location = str(event.get("LOCATION", "")).strip()
        description = str(event.get("DESCRIPTION", "")).strip()

        results.append({
            "calendar": calendar_name,
            "time": time_str,
            "title": summary,
            "location": location,
            "description": description[:300] if description else "",
            "sort_key": sort_key,
            "all_day": all_day,
        })

    return results


def main():
    parser = argparse.ArgumentParser(description="Fetch calendar events")
    parser.add_argument("--date", help="Date in YYYY-MM-DD format (default: today)")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    args = parser.parse_args()

    target_date = date.today()
    if args.date:
        target_date = date.fromisoformat(args.date)

    config = load_config()
    all_events = []

    for cal_config in config.get("calendars", []):
        name = cal_config.get("name", "Unknown")
        url = cal_config.get("ics_url", "")
        if not url or "YOUR_" in url:
            print(f"  [SKIP] {name}: ICS URL not configured", file=sys.stderr)
            continue
        print(f"  Fetching {name}...", file=sys.stderr)
        try:
            ics_data = fetch_ics(url)
            events = get_events_for_date(ics_data, name, target_date)
            all_events.extend(events)
            print(f"  Found {len(events)} events in {name}", file=sys.stderr)
        except Exception as e:
            print(f"  ERROR fetching {name}: {e}", file=sys.stderr)

    all_events.sort(key=lambda x: (not x["all_day"], x["sort_key"]))

    if args.json:
        # Strip non-serializable sort_key
        for e in all_events:
            e.pop("sort_key", None)
        print(json.dumps(all_events, indent=2))
        return

    date_label = target_date.strftime("%A, %B %-d, %Y")
    print(f"\n## Today's Schedule — {date_label}\n")

    if not all_events:
        print("No events found for today.")
        return

    for event in all_events:
        cal_tag = f"  _{event['calendar']}_"
        print(f"**{event['time']}** — {event['title']}{cal_tag}")
        if event["location"]:
            print(f"  📍 {event['location']}")
        if event["description"]:
            print(f"  > {event['description'][:150]}")
        print()


if __name__ == "__main__":
    main()
