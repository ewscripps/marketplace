#!/usr/bin/env python3
"""Per-day AR-status coverage and resolution rate for one channel.

Ada's AR classifier runs after the fact. This shows how completely each day has
been classified, so a stalled classifier can be told apart from a real decline.
Re-run it over days to watch a backlog clear.

Read this by comparing columns, not rows:
  coverage rising, AR rising with it -> backlog clearing, metric still filling in
  coverage rising, AR flat and low   -> backlog cleared, the decline is real
  coverage at 100%, AR moved         -> trustworthy change, investigate it

Uses only get_ada_metric, so it is cheap: 3 calls per day.

Usage:
  ADA_TOKEN=... python3 coverage_curve.py \
      --url https://nuvyyo-gr.ada.support/api/mcp --channel email --days 10
"""
import argparse, datetime, json, os, sys, urllib.request


def metric(url, token, mt, s, e, filters):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "tools/call",
                       "params": {"name": "get_ada_metric", "arguments": {
                           "metric_type": mt, "start_date": s, "end_date": e,
                           "filters": filters}}}).encode()
    req = urllib.request.Request(url, body, {
        "Authorization": "Bearer " + token, "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream"})
    raw = urllib.request.urlopen(req, timeout=90).read().decode()
    if raw.lstrip().startswith("event:"):
        raw = "".join(l[5:].strip() if l.startswith("data:") else ""
                      for l in raw.splitlines())
    d = json.loads(raw)
    if "error" in d:
        return 0.0
    try:
        return float(json.loads("".join(c["text"] for c in d["result"]["content"]))["value"])
    except (ValueError, KeyError, TypeError):
        return 0.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", required=True)
    ap.add_argument("--channel")
    ap.add_argument("--days", type=int, default=10)
    ap.add_argument("--end", help="last day to show, YYYY-MM-DD (default today)")
    a = ap.parse_args()

    token = os.environ.get("ADA_TOKEN")
    if not token:
        sys.exit("ADA_TOKEN not set")

    base = [{"type": "CHANNEL", "operator": "IS", "value": [a.channel]}] if a.channel else []
    res = [{"type": "ARSTATUS", "operator": "IS", "value": ["Resolved"]}]
    nres = [{"type": "ARSTATUS", "operator": "IS", "value": ["Not Resolved"]}]

    last = datetime.date.fromisoformat(a.end) if a.end else datetime.date.today()
    print(f"{a.url}   channel={a.channel or 'all'}   as of {datetime.datetime.now():%Y-%m-%d %H:%M}\n")
    print(f"{'day':<12}{'engaged':>9}{'classified':>12}{'coverage':>10}{'resolved':>10}{'AR%':>8}   status")

    settled = []
    for back in range(a.days - 1, -1, -1):
        d = last - datetime.timedelta(days=back)
        s, e = d.isoformat(), (d + datetime.timedelta(days=1)).isoformat()
        eng = metric(a.url, token, "conversation_volume_engaged", s, e, base)
        if not eng:
            print(f"{s:<12}{0:>9}")
            continue
        r = metric(a.url, token, "conversation_volume_engaged", s, e, base + res)
        n = metric(a.url, token, "conversation_volume_engaged", s, e, base + nres)
        cls = r + n
        cov = 100 * cls / eng
        ar = 100 * r / cls if cls else 0.0
        if cov >= 95:
            status = "settled"
            settled.append(ar)
        elif cov >= 80:
            status = "nearly complete"
        else:
            status = "INCOMPLETE - AR not usable"
        print(f"{s:<12}{eng:>9.0f}{cls:>12.0f}{cov:>9.0f}%{r:>10.0f}{ar:>8.1f}   {status}")

    if settled:
        print(f"\nsettled days (>=95% coverage): {len(settled)}, "
              f"AR range {min(settled):.1f}% - {max(settled):.1f}%, mean {sum(settled)/len(settled):.1f}%")
        print("Judge change against these days only. Incomplete days read low because")
        print("backlogs clear 'Not Resolved' first, not because resolution fell.")
    else:
        print("\nNo day in this range has reached 95% coverage. AR is not usable here.")


if __name__ == "__main__":
    main()
