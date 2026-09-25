#!/usr/bin/env python3
"""Confluence operations for infrastructure documentation.

Wraps the REST calls the Atlassian MCP cannot make (attachments especially) and the
ones that are easy to get wrong. Every subcommand has a documented curl equivalent in
references/confluence-mechanics.md.

Needs ATLASSIAN_EMAIL and ATLASSIAN_API_TOKEN in the environment. How you get them
there is per-platform -- see references/platforms.md. On macOS they live in
~/.config/zsh/secrets.zsh, which is not exported to non-interactive shells, so
`source ~/.zshenv` first.

    confluence.py tree       --page <id> [--depth 5]
    confluence.py publish    --parent <id> --title "..." --file page.html
    confluence.py attach     --page <id> --file d.svg [--place-before '<h2>X']
    confluence.py verify     --page <id>
    confluence.py provenance --page <id> [--stamp <sha>] [--repo <path>]
"""
import argparse, base64, html, json, mimetypes, os, re, sys, urllib.error, urllib.request, uuid
from collections import defaultdict

# Page titles carry em-dashes by house rule. When stdout is a pipe (which it is when an
# agent runs this), Python encodes with the locale codec -- cp1252 on Windows, which
# cannot represent every title character. That raises UnicodeEncodeError *after* a write
# has already committed, so the caller sees a failure on a successful publish and
# retries, duplicating attachment versions. Force UTF-8 out.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

# On Windows, mimetypes reads HKEY_CLASSES_ROOT and those entries OVERRIDE the built-in
# table -- any installed app can make .svg resolve to text/xml or text/plain. Confluence
# stores whatever we send as the attachment mediaType, and a non-image mediaType renders
# as a file link rather than a picture. Pin the two types we actually publish.
mimetypes.add_type("image/svg+xml", ".svg")
mimetypes.add_type("image/png", ".png")
_MIME = {".svg": "image/svg+xml", ".png": "image/png"}

SITE = os.environ.get("CONFLUENCE_SITE", "https://ewscripps.atlassian.net/wiki")
V1 = f"{SITE}/rest/api/content"

# The repo/branch/sha triple is the machine-critical part and is required.
# The date is a DEGRADED-mode fallback and may be plain text or a <time> element,
# so it is matched separately and treated as optional.
PROVENANCE_RE = re.compile(
    r"Verified as of\s+(?P<pre>.{0,160}?)against\s+"
    r"<code>(?P<repo>[^<]+)</code>\s*<code>(?P<branch>\S+)\s+(?P<sha>[0-9a-f]{7,40})</code>",
    re.S,
)
DATE_RE = re.compile(r'datetime="(\d{4}-\d{2}-\d{2})"|(\d{1,2}\s+\w+\s+\d{4})')


def _prov_date(pre: str) -> str:
    m = DATE_RE.search(pre or "")
    return (m.group(1) or m.group(2)) if m else "unknown"


def _auth() -> str:
    email, token = os.environ.get("ATLASSIAN_EMAIL"), os.environ.get("ATLASSIAN_API_TOKEN")
    if not email or not token:
        sys.exit("ATLASSIAN_EMAIL / ATLASSIAN_API_TOKEN not set.\n"
                 "  macOS/Linux: source ~/.zshenv\n"
                 "  PowerShell:  $env:ATLASSIAN_EMAIL='...'; $env:ATLASSIAN_API_TOKEN='...'\n"
                 "  See references/platforms.md")
    return base64.b64encode(f"{email}:{token}".encode()).decode()


def req(url, data=None, method="GET", headers=None):
    h = {"Authorization": f"Basic {_auth()}"}
    if data is not None and headers is None:
        h["Content-Type"] = "application/json"
        data = json.dumps(data).encode()
    if headers:
        h.update(headers)
    try:
        r = urllib.request.urlopen(urllib.request.Request(url, data=data, headers=h, method=method))
        body = r.read()
        return json.loads(body) if body and r.headers.get("Content-Type", "").startswith("application/json") else None
    except urllib.error.HTTPError as e:
        sys.exit(f"HTTP {e.code} on {method} {url}\n{e.read()[:500].decode(errors='replace')}")


def get_page(pid, expand="body.storage,version"):
    return req(f"{V1}/{pid}?expand={expand}")


def put_page(pid, title, body_storage, version, message=""):
    return req(f"{V1}/{pid}", {
        "version": {"number": version + 1, "message": message},
        "title": title, "type": "page",
        "body": {"storage": {"value": body_storage, "representation": "storage"}},
    }, "PUT")


# ---------------------------------------------------------------- tree
def cmd_tree(a):
    """Walk descendants, following the cursor. The API paginates at 250."""
    rows, url = [], f"{SITE}/api/v2/pages/{a.page}/descendants?depth={a.depth}&limit=250"
    while url:
        d = req(url)
        rows += d.get("results", [])
        nxt = (d.get("_links") or {}).get("next")
        url = f"{SITE.rsplit('/wiki',1)[0]}{nxt}" if nxt else None
    kids = defaultdict(list)
    for r in rows:
        kids[str(r.get("parentId"))].append(r)
    for v in kids.values():
        v.sort(key=lambda x: x.get("childPosition") or 0)
    seen = set()

    def walk(pid, ind):
        for r in kids.get(str(pid), []):
            if r["id"] in seen:
                continue
            seen.add(r["id"])
            print(f"{'  '*ind}- {r['title']}  [{r['id']}]")
            walk(r["id"], ind + 1)

    walk(a.page, 0)
    print(f"\n{len(seen)} descendant page(s)")


# ---------------------------------------------------------------- publish
def cmd_publish(a):
    """Create a page from an HTML file, or update one in place with --page."""
    # encoding is explicit: Windows defaults to cp1252, which silently turns the
    # em-dashes this house style mandates into mojibake rather than raising.
    body = open(os.path.expanduser(a.file), encoding="utf-8").read()
    if body.lstrip().startswith("&lt;"):
        sys.exit("Body looks pre-escaped (starts with &lt;). Pass real HTML, not entities.")
    if "<ac:structured-macro" in body:
        sys.exit("Body contains storage XML; the create/update API here takes HTML.")
    if a.page:
        cur = get_page(a.page)
        put_page(a.page, a.title or cur["title"], body, cur["version"]["number"], a.message or "update")
        print(f"updated {a.page} -> v{cur['version']['number']+1}")
        return
    res = req(f"{V1}", {
        "type": "page", "title": a.title,
        "ancestors": [{"id": str(a.parent)}],
        "space": {"key": a.space},
        "body": {"storage": {"value": body, "representation": "storage"}},
    }, "POST")
    got = res["title"]
    print(f"created {res['id']}  {got}")
    if got != a.title:
        print(f"  !! TITLE COLLISION: asked for {a.title!r}, got {got!r}. Rename it.")


# ---------------------------------------------------------------- attach
def cmd_attach(a):
    """Upload an attachment and optionally place it in the body before an anchor."""
    path = os.path.expanduser(a.file)
    fn = os.path.basename(path)
    ext = os.path.splitext(fn)[1].lower()
    ct = _MIME.get(ext) or mimetypes.guess_type(fn)[0]
    if not ct or not ct.startswith(("image/", "text/", "application/")):
        sys.exit(f"refusing to upload {fn}: could not determine a sane content type "
                 f"(got {ct!r}). Add it to _MIME.")
    b = uuid.uuid4().hex
    payload = (
        f'--{b}\r\nContent-Disposition: form-data; name="file"; filename="{fn}"\r\n'
        f"Content-Type: {ct}\r\n\r\n".encode()
        + open(path, "rb").read()
        + f"\r\n--{b}--\r\n".encode()
    )
    # Posting to child/attachment with a filename that already exists returns 400 --
    # it does NOT create a new version. To update, post to that attachment's /data.
    existing = {html.unescape(x["title"]): x["id"]
                for x in req(f"{V1}/{a.page}/child/attachment?limit=100")["results"]}
    if fn in existing:
        req(f"{V1}/{a.page}/child/attachment/{existing[fn]}/data", payload, "POST",
            {"Content-Type": f"multipart/form-data; boundary={b}", "X-Atlassian-Token": "nocheck"})
        print(f"updated {fn} ({ct}) on {a.page} -- new attachment version")
    else:
        req(f"{V1}/{a.page}/child/attachment", payload, "POST",
            {"Content-Type": f"multipart/form-data; boundary={b}", "X-Atlassian-Token": "nocheck"})
        print(f"uploaded {fn} ({ct}) to {a.page}")
    if not a.place_before:
        return
    d = get_page(a.page)
    body = d["body"]["storage"]["value"]
    if a.place_before not in body:
        sys.exit(f"anchor not found in body: {a.place_before!r}")
    if f'ri:filename="{fn}"' in body:
        print("  already referenced; new attachment version only, no body edit")
        return
    img = (f'<p><ac:image ac:align="center" ac:width="{a.width}" ac:alt="{html.escape(a.alt or fn)}">'
           f'<ri:attachment ri:filename="{fn}" /></ac:image></p>')
    put_page(a.page, d["title"], body.replace(a.place_before, img + a.place_before, 1),
             d["version"]["number"], "place diagram")
    print(f"  placed before {a.place_before!r}")


# ---------------------------------------------------------------- verify
def cmd_verify(a):
    """Check image refs resolve, render, and download."""
    d = get_page(a.page, "body.storage,body.view,version")
    storage, view = d["body"]["storage"]["value"], d["body"]["view"]["value"]
    # decode entities: an em-dash stored as &mdash; will not match the attachment's literal
    refs = [html.unescape(x) for x in re.findall(r'ri:filename="([^"]+)"', storage)]
    atts = {x["title"]: x for x in req(f"{V1}/{a.page}/child/attachment?limit=100")["results"]}
    print(f"{d['title']}  (v{d['version']['number']})")
    if not refs and not atts:
        print("  text only")
        return 0
    bad = 0
    for r in refs:
        ok = r in atts
        if not ok:
            bad += 1
        media = (atts.get(r, {}).get("extensions") or {}).get("mediaType", "-")
        status = "-"
        if ok:
            url = SITE + atts[r]["_links"]["download"]
            try:
                status = urllib.request.urlopen(urllib.request.Request(
                    url, headers={"Authorization": f"Basic {_auth()}"})).status
            except Exception as e:
                status, bad = f"FAIL {e}", bad + 1
        print(f"  {'OK ' if ok else 'BROKEN'}  {r}  [{media}]  download={status}")
    imgs = len(re.findall(r"<img[^>]+src=", view))
    print(f"  rendered <img>: {imgs}")
    # Referenced but not rendered means the attachment exists and downloads, yet the
    # page shows a file link instead of a picture -- the signature of a wrong mediaType.
    # Without this the run was green on a visibly broken page.
    if refs and imgs < len(refs):
        print(f"  !! {len(refs)} image ref(s) but only {imgs} rendered "
              f"-- check attachment mediaType")
        bad += 1
    for r in refs:
        mt = (atts.get(r, {}).get("extensions") or {}).get("mediaType", "")
        if mt and not mt.startswith("image/"):
            print(f"  !! {r} stored as {mt}, not an image type")
            bad += 1
    orphan = set(atts) - set(refs)
    if orphan:
        print(f"  !! unreferenced attachments: {sorted(orphan)}")
    return 1 if bad else 0


# ---------------------------------------------------------------- provenance
def cmd_provenance(a):
    """Read, or stamp, the provenance line that refresh mode diffs against."""
    d = get_page(a.page)
    body, title = d["body"]["storage"]["value"], d["title"]
    m = PROVENANCE_RE.search(body)
    if not a.stamp:
        if not m:
            print(f"{title}: NO PROVENANCE LINE — needs full derivation before refresh")
            return 2
        print(f"{title}: {m.group('repo')} {m.group('branch')} {m.group('sha')}  ({_prov_date(m.group('pre'))})")
        return 0
    if not m:
        sys.exit(f"{title}: no provenance line to update; add one by hand first")
    import datetime
    # Not strftime("%-d ...") -- %- is a glibc extension that raises ValueError on
    # Windows. Building the day from the integer is portable and needs no platform
    # branch. Month name is pinned rather than %B so a set locale cannot change it.
    _d = datetime.date.today()
    _MONTHS = ("January", "February", "March", "April", "May", "June", "July",
               "August", "September", "October", "November", "December")
    today = f"{_d.day} {_MONTHS[_d.month - 1]} {_d.year}"
    repo = a.repo or m.group("repo")
    new = (f"Verified as of {today} against <code>{repo}</code> "
           f"<code>{m.group('branch')} {a.stamp}</code>")
    put_page(a.page, title, body[:m.start()] + new + body[m.end():],
             d["version"]["number"], f"provenance -> {a.stamp}")
    print(f"{title}: stamped {a.stamp} ({today})")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    t = sub.add_parser("tree"); t.add_argument("--page", required=True); t.add_argument("--depth", type=int, default=5)
    t.set_defaults(fn=cmd_tree)

    pub = sub.add_parser("publish")
    pub.add_argument("--parent"); pub.add_argument("--page"); pub.add_argument("--title")
    pub.add_argument("--space", default="Infra"); pub.add_argument("--file", required=True)
    pub.add_argument("--message", default="")
    pub.set_defaults(fn=cmd_publish)

    at = sub.add_parser("attach")
    at.add_argument("--page", required=True); at.add_argument("--file", required=True)
    at.add_argument("--place-before"); at.add_argument("--alt"); at.add_argument("--width", default="820")
    at.set_defaults(fn=cmd_attach)

    v = sub.add_parser("verify"); v.add_argument("--page", required=True); v.set_defaults(fn=cmd_verify)

    pr = sub.add_parser("provenance")
    pr.add_argument("--page", required=True); pr.add_argument("--stamp"); pr.add_argument("--repo")
    pr.set_defaults(fn=cmd_provenance)

    a = p.parse_args()
    sys.exit(a.fn(a) or 0)


if __name__ == "__main__":
    main()
