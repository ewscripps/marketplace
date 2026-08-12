#!/usr/bin/env python3
"""Verify the canonical rn:version block inside the shipped skill markdown.

Extracts the block from workflow.md by marker and exec's it, so this tests the
artifact that actually ships rather than a copy that can drift.

Run:  python3 plugins/tablo-release-notes/dev/verify_version_rules.py
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PLUGIN = os.path.dirname(HERE)
WORKFLOW = os.path.join(PLUGIN, "skills", "generate-release-notes", "workflow.md")
FAST = "fast/release/"

START = "# --- rn:version (canonical) ---"
END = "# --- end rn:version ---"

fails = []


def load_canonical():
    src = open(WORKFLOW).read()
    if START not in src or END not in src:
        sys.exit("FAIL: canonical block markers not found in %s\n"
                 "      expected %r ... %r" % (WORKFLOW, START, END))
    block = src.split(START, 1)[1].split(END, 1)[0]
    ns = {}
    exec(START + block + END, ns)
    missing = [n for n in ("parse_version", "parse_tag", "candidate_tags",
                           "resolve_release_tag", "pick_baseline", "PHASE_RANK")
               if n not in ns]
    if missing:
        sys.exit("FAIL: canonical block does not define: %s" % ", ".join(missing))
    return ns


def tags(name):
    with open(os.path.join(HERE, "fixtures", "tags-%s.txt" % name)) as f:
        return [l.strip() for l in f if l.strip()]


def check(label, got, want):
    if got != want:
        fails.append("%s\n    got:  %r\n    want: %r" % (label, got, want))


M = load_canonical()
parse_version = M["parse_version"]
parse_tag = M["parse_tag"]
pick_baseline = M["pick_baseline"]
resolve_release_tag = M["resolve_release_tag"]

# --- grammar: accept ---
for raw, line, phase, idx, mode in [
    ("2.2", "2.2", "public", 1, "cumulative"),
    ("2.2.1", "2.2.1", "public", 1, "cumulative"),
    ("2.2-final", "2.2", "public", 1, "cumulative"),
    ("2.2-release", "2.2", "public", 1, "cumulative"),
    ("2.2-alpha.1", "2.2", "alpha", 1, "cumulative"),
    ("2.2-alpha.2", "2.2", "alpha", 2, "delta"),
    ("2.2-beta.1", "2.2", "beta", 1, "cumulative"),
    ("2.2-beta.2", "2.2", "beta", 2, "delta"),
    ("2.2-rc.3", "2.2", "rc", 3, "delta"),
    ("2.2-alpha", "2.2", "alpha", 1, "cumulative"),
    ("v2.2-alpha.1", "2.2", "alpha", 1, "cumulative"),
    ("  2.2-BETA.2  ", "2.2", "beta", 2, "delta"),
]:
    v = parse_version(raw)
    check("parse(%r)" % raw, None if not v else
          (v["line"], v["phase"], v["phase_index"], v["range_mode"]),
          (line, phase, idx, mode))

# --- grammar: reject ---
for raw in ["2", "2.2.3.4", "2.2-gamma.1", "2.2-alpha.x", "2.2-alpha.", "", "   ",
            "2.2 - BETA - Airship Push + VSI", "latest", "2.2-QA.1"]:
    check("reject(%r)" % raw, parse_version(raw), None)

check("normalized 2.2-final", parse_version("2.2-final")["normalized"], "2.2")
check("normalized 2.2-alpha.1", parse_version("2.2-alpha.1")["normalized"], "2.2-alpha.1")

# --- scoping: prefix in, legacy and other namespaces out ---
check("in-scope fast tag", bool(parse_tag(FAST + "v2.2-alpha.1", FAST)), True)
check("legacy tag excluded by prefix", parse_tag("v2.2-alpha.1", FAST), None)
check("fast/ excluded by fast/release/ prefix", parse_tag("fast/v1.0", FAST), None)
check("namespaced excluded when no prefix", parse_tag(FAST + "v2.2-alpha.1"), None)
check("plain tag in scope when no prefix", bool(parse_tag("v2.4.0-release")), True)
check("suffix captured", parse_tag("v2.3.0-release_ios")["suffix"], "_ios")
p = parse_tag("v1.7.6-rc.2_ENGINE")
check("rc index parsed", (p["line_tuple"], p["phase"], p["phase_index"]),
      ((1, 7, 6), "rc", 2))
for junk in ["vizbee-staging-test", "v2.0.0-release-hotfix2_ios", "new_ui",
             FAST + "v2.2-975f7f5663", FAST + "v1.8-alpha.3-bluetooth",
             FAST + "v2.2-vsi-validation-2026.04.29", FAST + "v2.2.0-QA.1"]:
    check("junk excluded %s" % junk,
          parse_tag(junk, FAST if junk.startswith(FAST) else ""), None)

# --- android: current line is fast/release/ ---
A = tags("android")
for raw, want in [
    ("2.2-alpha.1", FAST + "v2.1-final"),
    ("2.1-final", FAST + "v2.0.5-final"),
    ("2.0.1-final", FAST + "v2.0-final"),
    ("2.1-rc.4", FAST + "v2.1-rc.1"),
    ("2.1-beta.3", FAST + "v2.1-beta.2"),
    ("2.0-alpha.3", FAST + "v2.0-alpha.2"),
]:
    base, _, _ = pick_baseline(parse_version(raw), A, FAST)
    check("android baseline %s" % raw, base, want)

for raw, want in [
    ("2.2-alpha.1", FAST + "v2.2-alpha.1"),
    ("2.1-final", FAST + "v2.1-final"),
    ("2.1", FAST + "v2.1-final"),
    ("2.1-rc.4", FAST + "v2.1-rc.4"),
]:
    tag, _ = resolve_release_tag(parse_version(raw), A, FAST, "Android")
    check("android release tag %s" % raw, tag, want)

base, _, _ = pick_baseline(parse_version("2.2-alpha.1"), A, FAST)
check("android baseline never legacy", base.startswith(FAST), True)

# --- apple: main app line is non-namespaced; FAST lives under the prefix ---
P = tags("apple")
tag, _ = resolve_release_tag(parse_version("2.4.0-final"), P, "", "Apple")
check("apple release tag 2.4.0-final", tag, "v2.4.0-release")
base, _, _ = pick_baseline(parse_version("2.4.0-final"), P, "", "Apple")
check("apple baseline 2.4.0-final", base, "v2.3.0-release_tvos")
tag, _ = resolve_release_tag(parse_version("2.1-final"), P, FAST, "Apple")
check("apple FAST release tag 2.1-final", tag, FAST + "v2.1-final")

# --- roku: no namespaces, -release for GA ---
tag, _ = resolve_release_tag(parse_version("3.0.0-final"), tags("roku"), "", "Roku")
check("roku release tag 3.0.0-final", tag, "v3.0.0-release")

# --- the discovery warning that would have caught the legacy mixup ---
_, warns, stats = pick_baseline(parse_version("2.2"), A, "")
check("warns about unset tag_prefix",
      any("tag_prefix" in w and FAST in w for w in warns), True)
_, warns2, stats2 = pick_baseline(parse_version("2.2-alpha.1"), A, FAST)
check("silent once prefix is set", any("tag_prefix" in w for w in warns2), False)

print("android no-prefix: %r" % stats)
print("android %s: %r" % (FAST, stats2))
for w in warns2:
    print("  warn: %s" % w)

if fails:
    print("\n%d FAILURE(S):\n" % len(fails))
    for f in fails:
        print("  " + f)
    sys.exit(1)
print("\nALL CHECKS PASSED")
