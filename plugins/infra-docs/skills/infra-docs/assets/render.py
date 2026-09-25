#!/usr/bin/env python3
"""Render every diagram source to SVG, and check it will be legible in Confluence.

Python rather than a shell script so one file works under Git Bash, PowerShell, cmd,
WSL and macOS. Python is already required for confluence.py, so this adds no dependency
and removes the bash-only constructs (set -euo pipefail, shopt, heredocs, /tmp) that
made the old render.sh unusable outside a POSIX shell.

Copy this into <repo>/docs/diagrams/ alongside src/ and out/.

    python render.py              # or: py -3 render.py   on Windows

Needs graphviz on PATH (`dot`). mermaid-cli (`mmdc`) only if a repo still has .mmd
sources. See references/platforms.md for per-platform install.

SVG, not PNG: Confluence renders SVG natively, it stays crisp at any zoom, and the
label text stays selectable and searchable.
"""
import os, shutil, struct, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SRC, OUT = os.path.join(HERE, "src"), os.path.join(HERE, "out")

# Confluence content is ~820px wide, so a diagram is scaled to that and its labels
# shrink with it. Effective label size is the BINDING measure; aspect ratio only
# predicts it. A wide diagram with few short labels can still read fine, and tall is
# always fine -- Confluence pages scroll, they do not widen.
PAGE_WIDTH_PX, BASE_LABEL_PT = 820, 11
MIN_PT, MAX_RATIO = 7.0, 2.0


def need(tool):
    if shutil.which(tool) is None:
        sys.exit(f"{tool!r} not found on PATH.\n"
                 f"  Windows: winget install Graphviz.Graphviz\n"
                 f"  macOS:   brew install graphviz\n"
                 f"  Linux:   sudo apt install graphviz\n"
                 f"  See references/platforms.md")


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        err = (r.stderr or "").strip()
        hint = ""
        if "not recognized" in err.lower():
            # The Windows installer sometimes fails to register plugins.
            hint = ("\n  Looks like Graphviz plugins are not registered. "
                    "Run `dot -c` from an elevated prompt.")
        sys.exit(f"{' '.join(cmd)} failed:\n  {err}{hint}")


def png_size(path):
    with open(path, "rb") as f:
        return struct.unpack(">II", f.read(24)[16:24])


def main():
    if not os.path.isdir(SRC):
        sys.exit(f"no src/ directory beside {os.path.basename(__file__)} ({SRC})")
    os.makedirs(OUT, exist_ok=True)

    dots = sorted(f for f in os.listdir(SRC) if f.endswith(".dot"))
    mmds = sorted(f for f in os.listdir(SRC) if f.endswith(".mmd"))
    if dots:
        need("dot")
    if mmds:
        need("mmdc")

    for f in dots:
        n = f[:-4]
        run(["dot", "-Tsvg", os.path.join(SRC, f), "-o", os.path.join(OUT, n + ".svg")])
        print(f"  {n:<36} -> out/{n}.svg")
    for f in mmds:
        n = f[:-4]
        run(["mmdc", "-i", os.path.join(SRC, f), "-o", os.path.join(OUT, n + ".svg"), "-b", "white"])
        print(f"  {n:<36} -> out/{n}.svg (mermaid)")

    if not dots:
        return 0

    print()
    print(f"  legibility check (labels >={MIN_PT:g}pt binding; ratio >{MAX_RATIO:g} flagged separately):")
    failed = 0
    with tempfile.TemporaryDirectory() as tmp:          # not /tmp: Windows has none
        for f in dots:
            n = f[:-4]
            png = os.path.join(tmp, n + ".png")
            run(["dot", "-Tpng", "-Gdpi=110", os.path.join(SRC, f), "-o", png])
            w, h = png_size(png)
            pt = PAGE_WIDTH_PX / w * BASE_LABEL_PT
            flags = []
            if pt < MIN_PT:
                flags.append("LABELS TOO SMALL")
            if w / h > MAX_RATIO:
                flags.append("TOO WIDE")
            if flags:
                failed += 1
            flag = ("   <-- " + ", ".join(flags)) if flags else ""
            print(f"    {n:<36} {w}x{h}  ratio {w/h:.2f}  {pt:.1f}pt{flag}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
