#!/usr/bin/env python3
"""Estimate automated resolution for conversations Ada has not yet classified.

Ada's AR classifier runs after the fact and can fall days behind. Unclassified
conversations are excluded from the resolution_rate denominator, and observed
backlogs clear `Not Resolved` first, so the reported rate is both incomplete and
biased low. This samples the unclassified remainder and produces an ESTIMATE.

The estimate is not automated resolution. It will not reconcile with the Ada
dashboard, /support-ratios or /monthly-deck. Label it as an estimate wherever it
is reported, and never write it into a baseline.

Transcripts are fetched and scored in this process. They are never returned to
the caller -- only aggregate counts, a confidence interval, and a few short
rationales.

Usage:
  ADA_TOKEN=... ANTHROPIC_API_KEY=... python3 estimate_ar.py \
      --url https://nuvyyo-gr.ada.support/api/mcp \
      --start 2026-09-02 --end 2026-09-03 --channel email --sample 25
"""
import argparse, json, os, random, sys, urllib.request
from math import sqrt

MODEL = "claude-haiku-4-5-20251001"
MAX_TRANSCRIPT_CHARS = 12000

RUBRIC = """You are replicating Ada's automated-resolution classifier.

Label the conversation "Resolved" when the AI agent handled the customer's
inquiry without a human taking over. This INCLUDES cases where the agent
correctly acknowledged feedback or a suggestion, explained a policy, or pointed
the customer to the right resource, when that is the appropriate outcome.

Label it "Not Resolved" when the conversation was escalated or handed off to a
human, or when the agent failed to address what the customer actually asked.

Answer with strict JSON only: {"verdict":"Resolved"|"Not Resolved","reason":"<12 words max>"}"""


def mcp(url, token, name, args, timeout=120):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": "tools/call",
                       "params": {"name": name, "arguments": args}}).encode()
    req = urllib.request.Request(url, body, {
        "Authorization": "Bearer " + token, "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream"})
    raw = urllib.request.urlopen(req, timeout=timeout).read().decode()
    if raw.lstrip().startswith("event:"):
        raw = "".join(l[5:].strip() if l.startswith("data:") else ""
                      for l in raw.splitlines())
    d = json.loads(raw)
    if "error" in d:
        raise RuntimeError(d["error"])
    return "".join(c["text"] for c in d["result"]["content"])


def ids(url, token, start, end, filters, cap=2000):
    out, off = [], 0
    while True:
        t = mcp(url, token, "get_conversations",
                {"detail_level": "IDS_ONLY", "start_date": start, "end_date": end,
                 "size": 100, "offset": off, "filters": filters})
        o = json.loads(t)
        batch = o.get("conversations", [])
        out += [c["id"] for c in batch]
        nxt = o.get("next_offset")
        if not batch or not nxt or len(out) >= cap:
            break
        off = nxt
    return set(out)


def wilson(k, n, z=1.96):
    """Wilson score interval -- correct at small n and near 0, unlike normal approx."""
    if n == 0:
        return (0.0, 0.0)
    p = k / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return (max(0.0, c - h) * 100, min(1.0, c + h) * 100)


def classify(transcript, api_key):
    body = json.dumps({
        "model": MODEL, "max_tokens": 100,
        "system": [{"type": "text", "text": RUBRIC,
                    "cache_control": {"type": "ephemeral"}}],
        "messages": [{"role": "user", "content": transcript[:MAX_TRANSCRIPT_CHARS]}],
    }).encode()
    req = urllib.request.Request("https://api.anthropic.com/v1/messages", body, {
        "x-api-key": api_key, "anthropic-version": "2023-06-01",
        "content-type": "application/json"})
    r = json.loads(urllib.request.urlopen(req, timeout=120).read().decode())
    txt = "".join(b.get("text", "") for b in r.get("content", []))
    s, e = txt.find("{"), txt.rfind("}")
    if s < 0 or e < 0:
        return None, "unparseable"
    o = json.loads(txt[s:e + 1])
    return o.get("verdict"), o.get("reason", "")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", required=True)
    ap.add_argument("--start", required=True)
    ap.add_argument("--end", required=True)
    ap.add_argument("--channel")
    ap.add_argument("--sample", type=int, default=25)
    ap.add_argument("--seed", type=int, default=0)
    a = ap.parse_args()

    token = os.environ.get("ADA_TOKEN")
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not token:
        sys.exit("ADA_TOKEN not set")
    if not api_key:
        sys.exit("ANTHROPIC_API_KEY not set")

    base = [{"type": "CHANNEL", "operator": "IS", "value": [a.channel]}] if a.channel else []
    res = [{"type": "ARSTATUS", "operator": "IS", "value": ["Resolved"]}]
    nres = [{"type": "ARSTATUS", "operator": "IS", "value": ["Not Resolved"]}]

    allid = ids(a.url, token, a.start, a.end, base)
    r_id = ids(a.url, token, a.start, a.end, base + res)
    n_id = ids(a.url, token, a.start, a.end, base + nres)
    done = r_id | n_id
    unc = sorted(allid - done)

    total, ndone, nunc = len(allid), len(done), len(unc)
    cov = 100 * ndone / total if total else 0
    ada_ar = 100 * len(r_id) / ndone if ndone else 0

    print(f"window        : {a.start} -> {a.end}" + (f"  channel={a.channel}" if a.channel else ""))
    print(f"conversations : {total}")
    print(f"classified    : {ndone}  ({cov:.0f}% coverage)  Ada AR on this subset: {ada_ar:.1f}%")
    print(f"unclassified  : {nunc}")
    if not nunc:
        print("\nNothing unclassified. Ada's reported AR is complete for this window.")
        return

    random.seed(a.seed)
    pick = random.sample(unc, min(a.sample, nunc))
    print(f"sampling      : {len(pick)} of {nunc} unclassified\n")

    ok = fail = 0
    verdicts, examples = [], []
    for i, cid in enumerate(pick, 1):
        try:
            t = mcp(a.url, token, "get_conversation", {"conversation_id": cid})
            v, why = classify(t, api_key)
            if v not in ("Resolved", "Not Resolved"):
                fail += 1
                continue
            verdicts.append(v)
            ok += 1
            if len(examples) < 4:
                examples.append(f"  {v:<13} {why}")
        except Exception as ex:
            fail += 1
            print(f"  [{i}] {cid} failed: {str(ex)[:80]}", file=sys.stderr)
        print(f"\r  scored {i}/{len(pick)}", end="", file=sys.stderr)
    print("", file=sys.stderr)

    if not ok:
        sys.exit("No conversations could be scored.")

    k = verdicts.count("Resolved")
    p = 100 * k / ok
    lo, hi = wilson(k, ok)
    print(f"SAMPLE  : {k}/{ok} Resolved = {p:.1f}%   95% CI [{lo:.1f}%, {hi:.1f}%]")
    if fail:
        print(f"          ({fail} could not be scored)")

    # Blend the measured classified subset with the estimated remainder.
    est = (len(r_id) + (p / 100) * nunc) / total * 100 if total else 0
    elo = (len(r_id) + (lo / 100) * nunc) / total * 100 if total else 0
    ehi = (len(r_id) + (hi / 100) * nunc) / total * 100 if total else 0
    print(f"\nESTIMATED full-window AR: {est:.1f}%   95% CI [{elo:.1f}%, {ehi:.1f}%]")
    print(f"Ada currently reports    : {ada_ar:.1f}%  (computed on {cov:.0f}% of the window)")
    print("\nThis is an ESTIMATE produced by a local classifier approximating Ada's")
    print("rubric. It is not automated resolution, will not match the Ada dashboard,")
    print("and must not be written into a baseline or reported as AR.")
    if examples:
        print("\nsample rationales:")
        print("\n".join(examples))


if __name__ == "__main__":
    main()
