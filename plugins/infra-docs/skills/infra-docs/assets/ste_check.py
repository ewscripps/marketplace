#!/usr/bin/env python3
"""Lint the prose of Confluence storage-format pages against the STE structural rules.

ste-lint.py (bundled with the asd-ste100 skill) reads Markdown, not HTML. Fed a raw
page it reports every &nbsp; and &amp; as a banned semicolon and lints the contents of
<pre> blocks. This strips code, macros and tags first, then hands the prose to it.

    python3 ste_check.py page.html [page.html ...]   # or: py -3 ste_check.py ...
    python3 ste_check.py --baseline 3 page.html      # extra flags pass through

Exit status is ste-lint.py's: 1 when hard violations exceed the baseline.
"""
import html, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
LINT = os.path.join(HERE, "..", "..", "asd-ste100", "scripts", "ste-lint.py")

CODE = re.compile(r"(?s)<pre\b.*?</pre>|<code\b.*?</code>|<ac:structured-macro\b.*?</ac:structured-macro>")
BLOCK_END = re.compile(r"</(?:p|h[1-6]|li|tr|td|th)>")
TAG = re.compile(r"<[^>]+>")


def prose(page):
    # Code becomes a neutral token so sentences that mention a value still parse.
    text = BLOCK_END.sub("\n", CODE.sub("CODE", page))
    return html.unescape(TAG.sub("", text))


def main(argv):
    files = [a for a in argv if a.endswith((".html", ".htm", ".xml"))]
    flags = [a for a in argv if a not in files]
    if not files:
        sys.exit(__doc__)
    if not os.path.exists(LINT):
        sys.exit(f"ste-lint.py not found at {LINT} -- is the asd-ste100 skill installed alongside?")
    status = 0
    for path in files:
        with open(path, encoding="utf-8") as f:
            text = prose(f.read())
        print(f"== {path}", flush=True)
        status |= subprocess.run([sys.executable, LINT, *flags], input=text, text=True).returncode
    sys.exit(status)


if __name__ == "__main__":
    main(sys.argv[1:])
