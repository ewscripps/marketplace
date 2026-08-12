# tablo-release-notes v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `/generate-release-notes 2.2-alpha.1` work end-to-end — prerelease version support, correct commit ranges scoped to the current tag line, line-keyed Jira fix-version lookup — while removing the email output and renaming the plugin to `tablo-release-notes` v2.0.0.

**Architecture:** The plugin is prompt markdown, not application code. The only real logic is version parsing and tag ranking, which lives as **one** canonical Python block in `workflow.md` Step W1. The orchestrator writes that block to `$TMPDIR/rn_version.py` at the start of every run and passes the path to `rn-scm-collector`, which imports it — one copy, no bundled-script path convention needed, reusing the `$TMPDIR` plumbing the agents already share for shards. A committed harness extracts that same block from the markdown and asserts its behaviour against 643 real git tags.

**Tech Stack:** Markdown skill/agent definitions, JSON manifests, YAML config, Python 3 (stdlib only — `re`, `json`, `yaml`), `git`, `glab`, Atlassian MCP.

**Spec:** `docs/superpowers/specs/2026-08-12-tablo-release-notes-prerelease-design.md`

## Global Constraints

These are marketplace-wide hard rules from `CLAUDE.md`. They apply to every task.

- Gitmoji must use **shortcodes** (`:sparkles:`, `:bug:`), never Unicode emoji — Unicode breaks GitLab/Jira integrations.
- Commit messages must **never** include AI attribution trailers (`Co-Authored-By`, `Generated-By`, or similar).
- Git commands in skills must run as **separate parallel Bash calls**, never chained with `&&`.
- Never use `git add -A` or `git add .` — always stage files by explicit name.
- MCP tools are **NOT** listed in `allowed-tools` in SKILL.md — they are controlled via `.claude/settings.local.json`.
- Do **not** add a `requires: { "mcp": [...] }` field to `marketplace.json` — it does not work in newer Claude Code versions.
- The Atlassian Cloud ID constant is `f1b0109f-4589-41f1-be54-d5789b627577`.
- Every sibling agent is spawned with `model: "opus"` and `effort: "xhigh"`.
- Work happens on branch `generate-release-notes-plugin-v2`.

---

### Task 1: Rename the plugin and strip email from manifests and docs

Rename first so every later task edits final paths.

**Files:**
- Move: `plugins/release-notes/` → `plugins/tablo-release-notes/`
- Modify: `plugins/tablo-release-notes/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `plugins/tablo-release-notes/README.md`
- Modify: `plugins/tablo-release-notes/CLAUDE.md`
- Modify: `CLAUDE.md` (repo root)

**Interfaces:**
- Consumes: nothing.
- Produces: the path prefix `plugins/tablo-release-notes/` that Tasks 2–6 edit, and the plugin name `tablo-release-notes` that Task 7 invokes as `/tablo-release-notes:generate-release-notes`.

- [ ] **Step 1: Move the plugin directory**

```bash
git mv plugins/release-notes plugins/tablo-release-notes
```

- [ ] **Step 2: Verify the move preserved history and left nothing behind**

Run: `git status --short` and `ls plugins/`
Expected: only `R` (rename) entries; `plugins/` no longer lists `release-notes`.

- [ ] **Step 3: Rewrite `plugin.json`**

Replace the whole file. Note `userConfig` is gone entirely — it existed only for the email drop folder.

```json
{
  "$schema": "https://json.schemastore.org/claude-code-plugin-manifest.json",
  "name": "tablo-release-notes",
  "version": "2.0.0",
  "description": "Release-note generation for Tablo client applications. Collects Jira fix-version tickets and GitLab MRs/commits for a build, drafts customer-facing notes and an internal companion document, and publishes both to Confluence. Tablo-specific: assumes Tablo Jira projects, Tablo tag conventions, and the Scripps Atlassian site.",
  "author": {
    "name": "STG Software Engineering Team",
    "email": "stg@scripps.com"
  },
  "homepage": "https://gitlab.com/scripps/public/marketplace",
  "license": "MIT",
  "keywords": ["release-notes", "tablo", "jira", "gitlab", "confluence", "scripps"]
}
```

- [ ] **Step 4: Update the `marketplace.json` entry**

Change `name`, `source`, `description`, `version` on the existing entry. Leave `skills` and `agents` paths unchanged — they are relative to the plugin root, which did not change internally.

```json
{
  "name": "tablo-release-notes",
  "source": "./plugins/tablo-release-notes",
  "description": "Release-note generation for Tablo client applications. Collects Jira fix-version tickets and GitLab MRs/commits for a build, drafts customer-facing notes and an internal companion document, and publishes both to Confluence.",
  "version": "2.0.0",
  "skills": [
    "./skills/generate-release-notes",
    "./skills/release-notes-config"
  ],
  "agents": [
    "./agents/rn-jira-collector.md",
    "./agents/rn-scm-collector.md",
    "./agents/rn-confluence-publisher.md"
  ]
}
```

- [ ] **Step 5: Verify both JSON files still parse**

```bash
python3 -m json.tool .claude-plugin/marketplace.json > /dev/null && echo "marketplace.json OK"
python3 -m json.tool plugins/tablo-release-notes/.claude-plugin/plugin.json > /dev/null && echo "plugin.json OK"
```

Expected: both print OK.

- [ ] **Step 6: Add the scope note to the plugin `README.md` and remove email content**

Insert immediately after the README's opening description paragraph:

```markdown
> **Scope:** This plugin is specific to **Tablo client applications** (Android,
> Apple, Roku). It assumes Tablo's Jira projects, Tablo's git tag conventions
> (including the `fast/release/` tag namespace on `tablo-android`), and the
> Scripps Atlassian site. It is not a general-purpose release-notes tool.
```

Then delete every mention of the email output: the `email.html` / OneDrive / Power Automate sentences, the `drop_folder_root` setup instructions, and any numbered setup step that only configured the drop folder. Confluence is the sole publish target. Renumber remaining steps.

- [ ] **Step 7: Add the same scope note to the plugin `CLAUDE.md` and remove email content**

Add the scope blockquote under the `## Overview` heading, rewrite the Overview sentence to drop "and dropping a formatted email HTML for stakeholder notification", and update the `generate-release-notes` row of the Skills table to end at Confluence publishing.

- [ ] **Step 8: Add the plugin to the root `CLAUDE.md`**

Append to the `## Current Plugins` list:

```markdown
- **tablo-release-notes** (v2.0.0) — `/generate-release-notes <version>` for Tablo client apps. Collects Jira fix-version tickets and GitLab MRs/commits for a build, drafts customer notes plus an internal companion doc, and publishes to Confluence. Supports prerelease builds (`2.2-alpha.1`, `2.2-beta.2`, `2.2-final`). Three collector/publisher agents (`rn-jira-collector`, `rn-scm-collector`, `rn-confluence-publisher`).
```

- [ ] **Step 9: Verify no stale references remain**

```bash
grep -rn "release-notes/" --include="*.json" --include="*.md" . | grep -v "tablo-release-notes" | grep -v "^./docs/"
grep -rni "power automate\|onedrive\|email.html\|drop_folder_root" plugins/tablo-release-notes/README.md plugins/tablo-release-notes/CLAUDE.md .claude-plugin/marketplace.json plugins/tablo-release-notes/.claude-plugin/plugin.json
```

Expected: both produce no output. Any hit in the first command is a missed path reference; any hit in the second is missed email content.

- [ ] **Step 10: Commit**

```bash
git add plugins/tablo-release-notes .claude-plugin/marketplace.json CLAUDE.md
git commit -m "refactor(tablo-release-notes): :truck: rename plugin and scope it to Tablo apps

Renames release-notes to tablo-release-notes v2.0.0 and states the Tablo scope
explicitly in both READMEs. Drops the email output from the manifests and docs:
plugin.json loses its drop_folder_root userConfig, and Confluence becomes the
sole publish target."
```

---

### Task 2: Config skill — drop email fields, add tag scoping fields

**Files:**
- Modify: `plugins/tablo-release-notes/skills/release-notes-config/SKILL.md`
- Modify: `~/Documents/newt/git/tablo-android/.release-notes.yml` (outside this repo — not committed here)

**Interfaces:**
- Consumes: the renamed plugin path from Task 1.
- Produces: the config schema Tasks 4–6 read — per-platform `tag_prefix` (string, default `""`), `tag_suffix` (string, default `""`), `fix_version_override` (string, default `""`); and the removal of top-level `drop_folder_root` and `email_recipients_note`.

- [ ] **Step 1: Read the current schema section**

Run: `grep -n "drop_folder_root\|email_recipients_note\|platforms\|jira_project\|repo_path" plugins/tablo-release-notes/skills/release-notes-config/SKILL.md`

This shows every place the wizard defines or prompts for fields, so the edits below land in the right spots.

- [ ] **Step 2: Delete the email fields from the wizard and schema**

Remove every prompt, schema line, example-YAML line, and validation reference for `drop_folder_root` and `email_recipients_note`. Also remove the closing-message line that mentions the email drop. Renumber any numbered wizard steps.

- [ ] **Step 3: Add the three new optional per-platform fields**

Each is **optional** and lives under a `platforms[]` entry, alongside the existing required `name` / `repo_path` / `jira_project`. Document them in the schema section and prompt for them in the wizard as skippable:

```markdown
Optional per-platform fields (press Enter to skip any of them):

- `tag_prefix` — tag namespace for the platform's **current** release line, with
  its trailing slash, e.g. `fast/release/`. Only tags starting with this prefix
  are considered. Leave blank to consider only non-namespaced tags.
  **`tablo-android` requires `fast/release/`** — its unprefixed `v2.x` tags are
  a legacy codebase and must never be used for a commit range.
- `tag_suffix` — platform suffix appended to tags, e.g. `_ios`. Only needed when
  one repo tags several platforms at the same version (`tablo-apple` has both
  `v2.3.0-release_ios` and `v2.3.0-release_tvos`).
- `fix_version_override` — exact Jira fix-version name to use verbatim,
  skipping line-prefix discovery. Only needed when discovery reports an
  ambiguous match.
```

- [ ] **Step 4: Ask about `tag_prefix` during platform setup**

In the wizard's per-platform loop, after `jira_project`, add a prompt that lists the namespaces actually present in the repo so the user can choose from real data rather than guessing:

```bash
# Show the tag namespaces present in this platform's repo:
git -C "$repo_path" tag --list \
  | grep '/' \
  | sed 's|/[^/]*$|/|' \
  | sort | uniq -c | sort -rn | head -5
```

Then ask via `AskUserQuestion`: "Which tag namespace holds the **current** release line for {platform}? (blank = non-namespaced tags)", offering each listed namespace plus a blank option.

- [ ] **Step 5: Update the documented example YAML**

The example must show the new shape, with no email keys:

```yaml
product_name: Tablo
platforms:
  - name: Android
    repo_path: ~/Documents/newt/git/tablo-android
    jira_project: TBAD
    tag_prefix: fast/release/
confluence:
  space_key: Tablo
  root_page_title: Release Notes
  parent_page_title: Client Applications
release_date_source: jira
```

- [ ] **Step 6: Verify the email fields are gone and the new ones documented**

```bash
grep -c "drop_folder_root\|email_recipients_note" plugins/tablo-release-notes/skills/release-notes-config/SKILL.md
grep -c "tag_prefix" plugins/tablo-release-notes/skills/release-notes-config/SKILL.md
```

Expected: first prints `0`; second prints `3` or more.

- [ ] **Step 7: Add `tag_prefix` to the live tablo-android config**

This file is in another repo and is not committed by this plan. Without it, Task 7's live run would resolve a legacy baseline.

```bash
python3 - "$HOME/Documents/newt/git/tablo-android/.release-notes.yml" <<'PYEOF'
import yaml, sys
path = sys.argv[1]
c = yaml.safe_load(open(path)) or {}
for p in c.get("platforms", []):
    if p.get("name") == "Android":
        p["tag_prefix"] = "fast/release/"
with open(path, "w") as f:
    yaml.dump(c, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
print(open(path).read())
PYEOF
```

Expected: the printed YAML shows `tag_prefix: fast/release/` under the Android platform.

- [ ] **Step 8: Commit**

```bash
git add plugins/tablo-release-notes/skills/release-notes-config/SKILL.md
git commit -m "feat(tablo-release-notes): :wrench: add tag scoping config, drop email fields

Adds optional per-platform tag_prefix, tag_suffix and fix_version_override, and
prompts for tag_prefix by listing the namespaces actually present in the repo.
tablo-android needs fast/release/ because its unprefixed v2.x tags are a legacy
codebase. Removes drop_folder_root and email_recipients_note now that Confluence
is the only publish target."
```

---

### Task 3: Verification harness, tag fixtures, and the canonical version block

This is the task that carries the real logic. The code below is **already proven** against the fixtures — do not redesign it.

**Files:**
- Create: `plugins/tablo-release-notes/dev/verify_version_rules.py`
- Create: `plugins/tablo-release-notes/dev/fixtures/tags-android.txt`
- Create: `plugins/tablo-release-notes/dev/fixtures/tags-apple.txt`
- Create: `plugins/tablo-release-notes/dev/fixtures/tags-roku.txt`
- Create: `plugins/tablo-release-notes/dev/README.md`
- Modify: `plugins/tablo-release-notes/skills/generate-release-notes/workflow.md` (Step W1)
- Modify: `plugins/tablo-release-notes/CLAUDE.md`

**Interfaces:**
- Consumes: the renamed plugin path from Task 1.
- Produces: the canonical block in `workflow.md` delimited by the exact markers `# --- rn:version (canonical) ---` and `# --- end rn:version ---`, exposing:
  - `parse_version(raw) -> dict | None` with keys `line`, `line_tuple`, `phase`, `phase_index`, `is_public`, `range_mode`, `normalized`
  - `parse_tag(tag, tag_prefix="") -> dict | None` with keys `line`, `line_tuple`, `phase`, `phase_index`, `is_public`, `tag`, `suffix`
  - `candidate_tags(v, tag_prefix="", tag_suffix="") -> list[str]`
  - `resolve_release_tag(v, tags, tag_prefix="", platform_name="", tag_suffix="") -> (str | None, list[str])`
  - `pick_baseline(v, tags, tag_prefix="", platform_name="") -> (str | None, list[str], dict)`
  - `PHASE_RANK = {"alpha": 0, "beta": 1, "rc": 2, "public": 3}`
  
  Task 4 imports all of these from `$TMPDIR/rn_version.py`. Task 6 uses `parse_version` only.

- [ ] **Step 1: Capture the tag fixtures**

```bash
mkdir -p plugins/tablo-release-notes/dev/fixtures
git -C ~/Documents/newt/git/tablo-android tag --list > plugins/tablo-release-notes/dev/fixtures/tags-android.txt
git -C ~/Documents/newt/git/tablo-apple   tag --list > plugins/tablo-release-notes/dev/fixtures/tags-apple.txt
git -C ~/Documents/newt/git/tablo-roku    tag --list > plugins/tablo-release-notes/dev/fixtures/tags-roku.txt
wc -l plugins/tablo-release-notes/dev/fixtures/tags-*.txt
```

Expected: 369 android, 139 apple, 135 roku (643 total). Counts may grow as the repos gain tags; if they differ, the assertions in Step 3 still hold because they name specific tags rather than counts.

- [ ] **Step 2: Write the failing harness**

Create `plugins/tablo-release-notes/dev/verify_version_rules.py`. It extracts the canonical block from the shipped markdown, so it fails before the block exists.

```python
#!/usr/bin/env python3
"""Verify the canonical rn:version block inside the shipped skill markdown.

Extracts the block from workflow.md by marker and exec's it, so this tests the
artifact that actually ships rather than a copy that can drift.

Run:  python3 plugins/tablo-release-notes/dev/verify_version_rules.py
"""
import os
import re
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
```

- [ ] **Step 3: Run the harness to verify it fails**

Run: `python3 plugins/tablo-release-notes/dev/verify_version_rules.py`
Expected: FAIL with `canonical block markers not found in .../workflow.md`.

- [ ] **Step 4: Add the canonical block to `workflow.md` Step W1**

Replace the existing W1 "Extract and validate the version" bash block. The prose becomes: the orchestrator writes the canonical helper to `$TMPDIR` and every later step plus the SCM collector reuses it. Because `$TMPDIR` is created in W2, W1 writes the helper to a temp path and W2 moves it — simplest is to have W1 define the block and W2 write it; keep the block itself in W1 as the single source of truth.

The block must be inside a ```` ```python ```` fence and reproduce these markers **exactly**, since the harness splits on them:

````markdown
**1. Extract and validate the version.** The version is `$ARGUMENTS`. Write the
canonical version helper below to `$TMPDIR/rn_version.py` once W2 has created
`$TMPDIR`, then reuse it here, in W5's collector inputs, and in W6. This block is
the **single source of truth** for version and tag semantics — `dev/verify_version_rules.py`
extracts it from this file by its markers and asserts its behaviour against real
tag fixtures. Change it here and nowhere else.

```python
# --- rn:version (canonical) ---
import re

PHASE_RANK = {"alpha": 0, "beta": 1, "rc": 2, "public": 3}

_VERSION_RE = re.compile(
    r"^(?P<line>[0-9]+\.[0-9]+(?:\.[0-9]+)?)"
    r"(?:-(?P<phase>alpha|beta|rc|final|release)(?:\.(?P<idx>[0-9]+))?)?$"
)

_TAG_RE = re.compile(
    r"^v?(?P<line>[0-9]+\.[0-9]+(?:\.[0-9]+)?)"
    r"(?:-(?P<phase>alpha|beta|rc|final|release)(?:\.(?P<idx>[0-9]+))?)?"
    r"(?P<suffix>_[A-Za-z0-9]+)?$"
)


def _norm(line, phase, idx):
    if phase in (None, "", "final", "release"):
        phase = "public"
    idx = int(idx) if idx else 1
    parts = [int(p) for p in line.split(".")]
    while len(parts) < 3:
        parts.append(0)
    return {
        "line": line,
        "line_tuple": tuple(parts),
        "phase": phase,
        "phase_index": idx,
        "is_public": phase == "public",
    }


def parse_version(raw):
    """Parse the /generate-release-notes argument. Returns dict or None."""
    s = (raw or "").strip()
    if s[:1] in ("v", "V"):
        s = s[1:]
    m = _VERSION_RE.match(s.lower())
    if not m:
        return None
    d = _norm(m.group("line"), m.group("phase"), m.group("idx"))
    d["range_mode"] = "cumulative" if (d["is_public"] or d["phase_index"] == 1) else "delta"
    d["normalized"] = d["line"] if d["is_public"] else "%s-%s.%d" % (
        d["line"], d["phase"], d["phase_index"])
    return d


def parse_tag(tag, tag_prefix=""):
    """Parse a git tag within tag_prefix. Returns dict or None.

    Tags outside tag_prefix are None (not this product line). With an empty
    tag_prefix only non-namespaced tags qualify, so a repo's namespaced tags
    never contaminate the main line's ordering.
    """
    t = (tag or "").strip()
    if tag_prefix:
        if not t.startswith(tag_prefix):
            return None
        rest = t[len(tag_prefix):]
    else:
        rest = t
    if "/" in rest or not rest:
        return None
    m = _TAG_RE.match(rest)
    if not m:
        return None
    d = _norm(m.group("line"), m.group("phase"), m.group("idx"))
    d["tag"] = tag
    d["suffix"] = m.group("suffix") or ""
    return d


def _suffix_pref(suffix, platform_name):
    """Higher is better: unsuffixed beats a platform match beats anything else."""
    if not suffix:
        return 2
    if platform_name and suffix.lower() == "_" + platform_name.lower():
        return 1
    return 0


def candidate_tags(v, tag_prefix="", tag_suffix=""):
    """Ordered exact-match candidates for v's own release tag."""
    line = v["line"]
    if v["is_public"]:
        bases = ["v%s" % line, line, "v%s-release" % line, "v%s-final" % line]
    else:
        pn = "%s.%d" % (v["phase"], v["phase_index"])
        bases = ["v%s-%s" % (line, pn), "%s-%s" % (line, pn)]
    out = []
    for b in bases:
        if tag_suffix:
            out.append(tag_prefix + b + tag_suffix)
        out.append(tag_prefix + b)
    return out


def resolve_release_tag(v, tags, tag_prefix="", platform_name="", tag_suffix=""):
    """Return (tag_or_None, warnings) for v's own release tag."""
    warnings = []
    tagset = set(t.strip() for t in tags)
    cands = candidate_tags(v, tag_prefix, tag_suffix)
    for cand in cands:
        if cand in tagset:
            return cand, warnings
    for cand in cands:
        matches = sorted(t for t in tagset
                         if t.startswith(cand + "_") and parse_tag(t, tag_prefix))
        if not matches:
            continue
        best = max(matches, key=lambda t: (
            _suffix_pref(parse_tag(t, tag_prefix)["suffix"], platform_name), t))
        if len(matches) > 1:
            warnings.append("Multiple tags match %s: %s. Using %s."
                            % (cand, ", ".join(matches), best))
        return best, warnings
    return None, warnings


def pick_baseline(v, tags, tag_prefix="", platform_name=""):
    """Return (baseline_tag_or_None, warnings, stats).

    stats counts what was skipped so nothing disappears silently:
      in_scope     -- rankable tags on this line
      unparsed     -- in scope but not rankable (hashes, feature tags)
      out_of_scope -- outside tag_prefix (another product line / legacy)
    """
    parsed, unparsed, out_of_scope = [], [], []
    for raw in tags:
        t = raw.strip()
        if not t:
            continue
        in_scope = (t.startswith(tag_prefix) and "/" not in t[len(tag_prefix):]) \
            if tag_prefix else "/" not in t
        if not in_scope:
            out_of_scope.append(t)
            continue
        p = parse_tag(t, tag_prefix)
        (parsed if p else unparsed).append(p if p else t)

    warnings = []
    if unparsed:
        warnings.append("Ignored %d unrankable tag(s) in scope: %s"
                        % (len(unparsed), ", ".join(sorted(unparsed)[:8])))
    if not tag_prefix:
        ns = {}
        for t in out_of_scope:
            if "/" in t:
                k = t.rsplit("/", 1)[0] + "/"
                ns[k] = ns.get(k, 0) + 1
        hits = {k: n for k, n in ns.items()
                if any(parse_tag(t, k) for t in out_of_scope if t.startswith(k))}
        if hits:
            warnings.append(
                "No tag_prefix set, so %d namespaced tag(s) were excluded. "
                "Namespaces with parseable release tags: %s. Set tag_prefix in "
                ".release-notes.yml if one of these is the current line."
                % (sum(hits.values()),
                   ", ".join("%s (%d)" % (k, n) for k, n in sorted(hits.items()))))

    if v["range_mode"] == "delta":
        cands = [p for p in parsed
                 if p["line_tuple"] == v["line_tuple"]
                 and p["phase"] == v["phase"]
                 and p["phase_index"] < v["phase_index"]]
    else:
        cands = [p for p in parsed
                 if p["is_public"] and p["line_tuple"] < v["line_tuple"]]

    stats = {"in_scope": len(parsed), "unparsed": len(unparsed),
             "out_of_scope": len(out_of_scope)}
    if not cands:
        return None, warnings, stats
    best = max(cands, key=lambda p: (
        p["line_tuple"], p["phase_index"],
        _suffix_pref(p["suffix"], platform_name), p["tag"]))
    return best["tag"], warnings, stats
# --- end rn:version ---
```
````

Then add the validation prose and the hard-stop behaviour:

```markdown
Parse `$ARGUMENTS` with `parse_version`. If it returns `None`, **stop** and
report, substituting the actual argument:

> `ERROR: '<arg>' is not a valid version. Expected a release line with an
> optional prerelease qualifier — e.g. 2.2, 2.2.1, 2.2-alpha.1, 2.2-beta.2,
> 2.2-rc.3, or 2.2-final. Jira fix-version names are not accepted here; pass the
> build version and the collector resolves the fix version itself.`

Bind for every later step: `version` (the raw normalized string),
`version_line`, `version_phase`, `version_phase_index`, `version_is_public`,
`range_mode`, and `version_display` (= `normalized`).
```

- [ ] **Step 5: Run the harness to verify it passes**

Run: `python3 plugins/tablo-release-notes/dev/verify_version_rules.py`
Expected: prints the two stats lines, one `warn:` line about 12 unrankable in-scope tags, then `ALL CHECKS PASSED`, exit 0.

If it fails on an indentation error, the fenced block was re-indented on paste — the block must start at column 0 inside the fence.

- [ ] **Step 6: Write `dev/README.md`**

```markdown
# dev — verification harness

Not shipped behaviour; these files exist to keep the version and tag rules
honest.

## `verify_version_rules.py`

Extracts the canonical Python block from
`skills/generate-release-notes/workflow.md` by its
`# --- rn:version (canonical) ---` / `# --- end rn:version ---` markers and
`exec`s it, then asserts its behaviour against real tag fixtures. Testing the
extracted block rather than a copy means the harness cannot silently drift from
what ships.

Run it after any change to that block:

```bash
python3 plugins/tablo-release-notes/dev/verify_version_rules.py
```

Exit 0 and `ALL CHECKS PASSED` is the only acceptable result.

## `fixtures/tags-*.txt`

`git tag --list` output captured from `tablo-android`, `tablo-apple`, and
`tablo-roku`. Committed so runs are deterministic and need no repo checkouts.
They cover the cases that make this logic non-trivial:

- `tablo-android` mixes a legacy unprefixed `v2.x` line with the current
  `fast/release/` line — 369 tags, only 55 of which are current.
- `fast/release/v2.1` has `beta.2`/`beta.3` with no `beta.1`, and `rc.1` then
  `rc.4`–`rc.7`, so "previous index" must mean "highest lower index".
- `tablo-apple` tags two platforms at one version (`_ios`, `_tvos`) and holds
  both a main-app line and a FAST line.
- Junk tags (`vizbee-staging-test`, `fast/release/v2.2-975f7f5663`) must be
  excluded from ordering rather than crash it.

Refresh with `git -C <repo> tag --list > fixtures/tags-<name>.txt`. Adding tags
should never break the assertions, which name specific tags rather than counts.
```

- [ ] **Step 7: Document the canonical block in the plugin `CLAUDE.md`**

Add a section so contributors do not copy the logic elsewhere:

```markdown
## Version and tag semantics

The canonical implementation is the Python block in
`skills/generate-release-notes/workflow.md`, delimited by
`# --- rn:version (canonical) ---` / `# --- end rn:version ---`. It is the
**only** copy. The orchestrator writes it to `$TMPDIR/rn_version.py` at the start
of a run and `rn-scm-collector` imports it from there — never re-implement version
or tag parsing in an agent file.

`dev/verify_version_rules.py` extracts that block and asserts it against real tag
fixtures. Run it after any change to the block.

Grammar: `<line>[-(alpha|beta|rc|final|release)[.N]]`, where `line` is
`major.minor[.patch]`. `-final` and `-release` both mean the public build.

Range rule: the first build of a phase is cumulative from the previous public
release; later builds in that phase are deltas from the previous build of that
same phase.

Tag scoping: only tags under a platform's `tag_prefix` are considered. This is
load-bearing for `tablo-android`, whose unprefixed `v2.x` tags are a legacy
codebase.
```

- [ ] **Step 8: Commit**

```bash
git add plugins/tablo-release-notes/dev plugins/tablo-release-notes/skills/generate-release-notes/workflow.md plugins/tablo-release-notes/CLAUDE.md
git commit -m "feat(tablo-release-notes): :sparkles: add prerelease version grammar and verification harness

W1 gains the canonical rn:version block: parses <line>[-(alpha|beta|rc|final|
release)[.N]], derives cumulative-vs-delta range mode, scopes tags to a
platform's tag_prefix, and ranks baselines with a comparator instead of git's
version:refname, which sorts prereleases above their release.

dev/verify_version_rules.py extracts that block from the shipped markdown and
asserts it against 643 real tags, so the harness cannot drift from what ships."
```

---

### Task 4: SCM collector — scoped tag resolution and correct baselines

**Files:**
- Modify: `plugins/tablo-release-notes/agents/rn-scm-collector.md` (input contract; Step C1; shard schema)

**Interfaces:**
- Consumes: `$TMPDIR/rn_version.py` from Task 3 — `parse_version`, `parse_tag`, `resolve_release_tag`, `pick_baseline`.
- Produces: shard fields `baseline_ref` (string|null), `release_ref` (string|null), `range_mode` (`"cumulative"|"delta"`), `effective_range_mode` (same domain), `tag_stats` (`{in_scope, unparsed, out_of_scope}` ints), and receipt field `effective_range_mode`. Task 6 reads all of these.

- [ ] **Step 1: Extend the documented input contract**

Add to the agent's input JSON documentation, alongside the existing `repo_path`, `platform_name`, `version`, `jira_project_key`, `fix_version_ticket_keys`, `shard_output_path`, `today`:

```json
{
  "version_helper_path": "{TMPDIR}/rn_version.py",
  "range_mode": "cumulative",
  "tag_prefix": "fast/release/",
  "tag_suffix": ""
}
```

Document each:

```markdown
- **`version_helper_path`** — path to the canonical version helper the
  orchestrator wrote. Import it; do **not** re-implement version or tag parsing.
- **`range_mode`** — `cumulative` or `delta`, decided by the orchestrator from
  the version string. Determines which baseline is selected.
- **`tag_prefix`** — tag namespace for this platform's current release line
  (e.g. `fast/release/`), or `""`. Only tags in this namespace are considered.
  For `tablo-android` this is what keeps the legacy `v2.x` line out of the range.
- **`tag_suffix`** — platform suffix such as `_ios`, or `""`.
```

- [ ] **Step 2: Replace C1 strategy 1 with scoped resolution**

Delete the two `git tag --list ... --sort=-version:refname` lines entirely — that is the defect. Replace with:

````markdown
**1. Git tags (preferred).** Resolve this build's tag and its baseline using the
canonical helper. Never rank tags with `--sort=-version:refname`: git sorts
`v2.2-beta.1` *above* `v2.2`, which silently yields the wrong baseline.

```bash
git -C "$repo" tag --list > "$TMPDIR_LOCAL/tags.txt"
python3 - "$version_helper_path" "$TMPDIR_LOCAL/tags.txt" "$version" \
         "$tag_prefix" "$platform_name" "$tag_suffix" <<'PYEOF'
import json, sys
helper, tagfile, version, prefix, platform, suffix = sys.argv[1:7]
ns = {}
exec(open(helper).read(), ns)
tags = [l.strip() for l in open(tagfile) if l.strip()]
v = ns["parse_version"](version)
release_ref, w1 = ns["resolve_release_tag"](v, tags, prefix, platform, suffix)
baseline_ref, w2, stats = ns["pick_baseline"](v, tags, prefix, platform)
print(json.dumps({"release_ref": release_ref, "baseline_ref": baseline_ref,
                  "warnings": w1 + w2, "tag_stats": stats}))
PYEOF
```

Read the JSON back and bind `release_ref`, `baseline_ref`, `tag_stats`, and
append every returned warning to the shard's `warnings[]`.

Outcomes:

- **both refs found** → the range is `<baseline_ref>..<release_ref>`. Set
  `commit_range_description` to that string and
  `effective_range_mode` = the requested `range_mode`.
- **release ref found, no baseline** → use `release_ref` as the end and the date
  window for the start. Warn:
  `"No baseline tag found for <version> in scope <tag_prefix or '(none)'>. Using date window."`
  Set `effective_range_mode` to `"cumulative"` — a date window is not a delta.
- **no release ref** → fall through to the date-window strategy below and set
  `effective_range_mode` to `"cumulative"`.

Capture the tag dates for MR filtering in C2:

```bash
baseline_date=$(git -C "$repo" log -1 --format="%aI" "$baseline_ref" 2>/dev/null)
release_date=$(git -C "$repo" log -1 --format="%aI" "$release_ref" 2>/dev/null)
```
````

Note the existing variable names `prev_tag`/`release_tag` are replaced by
`baseline_ref`/`release_ref` — update every later reference in C2 and C5,
including `prev_ref`/`release_ref` bindings and the `prev_tag_date` /
`release_tag_date` names.

- [ ] **Step 3: Make the date-window fallback report cumulative**

In C1 strategy 2 and strategy 3, add: `effective_range_mode` is always
`"cumulative"` for a date window or `last-200`, because neither can express a
delta. This is what lets the orchestrator's W6 guard detect the degrade.

- [ ] **Step 4: Add the new fields to the documented shard schema**

In the shard JSON example, alongside `commit_range_description`:

```json
{
  "baseline_ref": "fast/release/v2.1-final",
  "release_ref": "fast/release/v2.2-alpha.1",
  "range_mode": "cumulative",
  "effective_range_mode": "cumulative",
  "tag_stats": {"in_scope": 55, "unparsed": 12, "out_of_scope": 302}
}
```

Add to the field documentation list: `baseline_ref` / `release_ref` are the
resolved tags or `null`; `range_mode` echoes the input; `effective_range_mode`
is what was actually achievable; `tag_stats` records scoping counts.

- [ ] **Step 5: Add `effective_range_mode` to the receipt**

The one-line receipt becomes:

```json
{"platform":"Android","repo_path":"...","status":"ok","total_mrs":12,"systemic_candidates":2,"shard_path":"...","warnings_count":1,"effective_range_mode":"cumulative"}
```

- [ ] **Step 6: Update the empty-shard and step-summary sections**

The `ok_empty` shard must include the new keys (`baseline_ref: null`,
`release_ref: null`, `range_mode` echoed, `effective_range_mode: "cumulative"`,
`tag_stats` zeroed) so the schema is uniform. Update the C1 line of the
step-summary list at the end of the file to describe scoped resolution instead
of tag sorting.

- [ ] **Step 7: Verify no stale sorting or naming remains**

```bash
grep -n "version:refname\|prev_tag" plugins/tablo-release-notes/agents/rn-scm-collector.md
grep -c "effective_range_mode" plugins/tablo-release-notes/agents/rn-scm-collector.md
```

Expected: the first prints nothing for `prev_tag`; any `version:refname` hit must be a non-ranking use (plain listing) — if it is ranking, it is a bug. The second prints `4` or more.

- [ ] **Step 8: Re-run the harness**

Run: `python3 plugins/tablo-release-notes/dev/verify_version_rules.py`
Expected: `ALL CHECKS PASSED`. This task did not change the block, so a failure means the block was edited by accident.

- [ ] **Step 9: Commit**

```bash
git add plugins/tablo-release-notes/agents/rn-scm-collector.md
git commit -m "fix(tablo-release-notes): :bug: scope tag resolution and fix prerelease baselines

C1 no longer ranks tags with --sort=-version:refname, which sorts v2.2-beta.1
above v2.2 and so returned the repo's newest tag as the baseline for every
prerelease. It now imports the canonical helper and resolves both refs within
the platform's tag_prefix, keeping tablo-android's legacy v2.x line out of the
range entirely.

Adds baseline_ref, release_ref, range_mode, effective_range_mode and tag_stats
to the shard. effective_range_mode reports when only a date window was
achievable, which the orchestrator needs to detect a degraded delta."
```

---

### Task 5: Jira collector — resolve the fix version from the release line

**Files:**
- Modify: `plugins/tablo-release-notes/agents/rn-jira-collector.md` (input contract; new resolution step; shard schema; receipt)

**Interfaces:**
- Consumes: nothing from earlier tasks at runtime; the orchestrator supplies inputs.
- Produces: shard/receipt field `resolved_fix_version` (string). Task 6 reads it for the document header and the final summary.

- [ ] **Step 1: Extend the documented input contract**

Add alongside the existing keys:

```json
{
  "version_line": "2.2",
  "fix_version_override": ""
}
```

Document them, and mark the old `fix_version` input as derived:

```markdown
- **`version_line`** — the release line only (e.g. `2.2`), never a prerelease
  build string. Jira fix versions track public release lines; `-alpha.N` and
  `-beta.N` never appear in one. Resolve this to a real fix-version name in S0.
- **`fix_version_override`** — an exact fix-version name to use verbatim,
  skipping S0 discovery. Empty means discover.
```

- [ ] **Step 2: Add Step S0 — resolve the fix-version name**

Insert before the existing first step:

````markdown
## Step S0 — Resolve the fix-version name

*Turn the release line into the exact Jira fix-version name, because real names
are freeform and never equal a bare version.*

TBAD's four fix versions are named
`2.2 - BETA - Airship Push + VSI` and similar — so
`fixVersion = "2.2"` matches nothing. Resolve before querying tickets.

**1. Override wins.** If `fix_version_override` is non-empty, bind
`resolved_fix_version` to it verbatim and skip to S1.

**2. Discover the project's fix-version names.** Call
`mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql` with:

- `cloudId`: the cloud-ID constant
- `jql`: `project = "{project_key}" AND fixVersion IS NOT EMPTY ORDER BY updated DESC`
- `fields`: `["fixVersions"]`
- `maxResults`: `100`
- `responseContentFormat`: `"markdown"`

This response is large and may exceed the tool's output limit, in which case it
is written to a file and the path is returned. Either way, extract the distinct
names with `jq` rather than reading the payload:

```bash
jq -r '[.issues.nodes[].fields.fixVersions[]?.name] | unique | .[]' "$result_file"
```

**3. Match on the line prefix.** Keep every name that starts with
`{version_line}`. Then:

- **exactly one** → bind it as `resolved_fix_version` and continue to S1.
- **zero** → return the **failed** receipt and stop:

  ```json
  {"project":"TBAD","status":"failed","reason":"No fix version in TBAD starts with '2.2'. Names found: 2.1 - BETA - ..., 2.3 - .... Set fix_version_override in .release-notes.yml if the name differs."}
  ```

- **two or more** → return the **failed** receipt and stop, listing every match
  and naming `fix_version_override` as the fix. Do not guess: picking the wrong
  line silently produces notes for the wrong release.
````

- [ ] **Step 3: Use the resolved name in the ticket query**

Every JQL in the collector that referenced the raw `fix_version` input must now
use `resolved_fix_version`, quoted, e.g.
`project = "{project_key}" AND fixVersion = "{resolved_fix_version}"`.

- [ ] **Step 4: Add the field to the shard and receipt**

Shard gains `"resolved_fix_version": "2.2 - BETA - Airship Push + VSI"` next to
the existing `project` field, documented as "the Jira fix-version name S0
resolved from `version_line`". Receipt gains the same key:

```json
{"project":"TBAD","status":"ok","ticket_count":14,"shard_path":"...","warnings_count":0,"resolved_fix_version":"2.2 - BETA - Airship Push + VSI"}
```

- [ ] **Step 5: Update the empty-shard case and step summary**

The `ok_empty` shard includes `resolved_fix_version`, and its warning names the
resolved name rather than the raw version:
`"No tickets found for project <project_key> with fixVersion <resolved_fix_version>"`.
Add S0 to the numbered step-summary list at the end of the file and renumber.

- [ ] **Step 6: Verify**

```bash
grep -n 'fixVersion = "{version}"\|fixVersion = "{fix_version}"' plugins/tablo-release-notes/agents/rn-jira-collector.md
grep -c "resolved_fix_version" plugins/tablo-release-notes/agents/rn-jira-collector.md
```

Expected: first prints nothing (no raw-version JQL left); second prints `6` or more.

- [ ] **Step 7: Commit**

```bash
git add plugins/tablo-release-notes/agents/rn-jira-collector.md
git commit -m "fix(tablo-release-notes): :bug: resolve Jira fix version from the release line

TBAD's fix versions are named '2.2 - BETA - Airship Push + VSI', so the previous
exact-match fixVersion = \"{version}\" query could never match and Jira
collection returned nothing for the project.

New Step S0 discovers the project's fix-version names and matches on the release
line prefix, so 2.2, 2.2-alpha.1 and 2.2-final all resolve to the same version.
Zero or ambiguous matches hard-stop with the candidates listed rather than
guessing a release. fix_version_override bypasses discovery."
```

---

### Task 6: Orchestrator wiring — collector inputs, delta filtering, titles, and W9 removal

**Files:**
- Modify: `plugins/tablo-release-notes/skills/generate-release-notes/workflow.md` (W2, W3, W4, W5, W6, W8; delete W9; W10; error-recovery)
- Modify: `plugins/tablo-release-notes/skills/generate-release-notes/SKILL.md`

**Interfaces:**
- Consumes: Task 3's `parse_version` bindings; Task 4's `baseline_ref` / `release_ref` / `effective_range_mode` / `tag_stats`; Task 5's `resolved_fix_version`.
- Produces: the finished orchestrator contract Task 7 exercises.

- [ ] **Step 1: Write the helper to `$TMPDIR` in W2**

In W2 step 3, after `mkdir -p "$TMPDIR"`, write the canonical block from W1 to
`$TMPDIR/rn_version.py` with the Write tool and verify it imports:

```bash
python3 -c "
import sys; ns={}
exec(open('$TMPDIR/rn_version.py').read(), ns)
assert ns['parse_version']('2.2-alpha.1')['range_mode']=='cumulative'
assert ns['parse_version']('2.2-alpha.2')['range_mode']=='delta'
print('version helper OK')
"
```

Expected: `version helper OK`. If it fails, stop — every later step depends on it.

- [ ] **Step 2: Use `version_line` for the W3 release-date lookup**

W3's JQL currently uses `fixVersion = "{version}"`, which cannot match (Task 5).
Change W3 to read the release date from the Jira shards instead, after W4, or —
simpler and preferred — move the whole release-date lookup to **after** W4 and
read `resolved_fix_version` from the first shard, then query:

```
project = "{jira_project}" AND fixVersion = "{resolved_fix_version}"
```

Renumber W3's remaining content (build number, metadata summary) and note in the
step's intro that the date lookup now depends on W4's resolution. Update the
metadata summary line to print the build type and resolved fix version:

```bash
echo "Release: ${product_name} ${version_display} (${version_phase}${phase_note}) — fix version '${resolved_fix_version}' — planned ${release_date:-TBD}"
```

- [ ] **Step 3: Pass the new keys to the Jira collectors in W4**

The agent prompt JSON becomes:

```json
{
  "jira_project_key": "{KEY}",
  "project_key": "{KEY}",
  "version_line": "{version_line}",
  "fix_version_override": "{platform.fix_version_override or ''}",
  "cloud_id": "f1b0109f-4589-41f1-be54-d5789b627577",
  "shard_output_path": "{TMPDIR}/jira-{KEY}.json",
  "today": "{today}"
}
```

The `fix_version` key is removed — the collector resolves its own. Add to the
receipt handling: bind `resolved_fix_version` from the first `ok`/`ok_empty`
receipt for the header and summary; if two projects resolve **different** names,
print a warning naming both and continue using each shard's own value.

- [ ] **Step 4: Pass the new keys to the SCM collectors in W5**

```json
{
  "repo_path": "{platform.repo_path}",
  "platform_name": "{platform.name}",
  "version": "{version}",
  "jira_project_key": "{platform.jira_project}",
  "fix_version_ticket_keys": ["TBAD-123", "TBAD-124"],
  "version_helper_path": "{TMPDIR}/rn_version.py",
  "range_mode": "{range_mode}",
  "tag_prefix": "{platform.tag_prefix or ''}",
  "tag_suffix": "{platform.tag_suffix or ''}",
  "shard_output_path": "{TMPDIR}/scm-{platform.name}.json",
  "today": "{today}"
}
```

Add to receipt handling: record each platform's `effective_range_mode`. When it
differs from the requested `range_mode`, note the platform for the W6 guard and
the W10 summary.

- [ ] **Step 5: Add delta filtering and the safety guard to W6**

Insert immediately before the `### B. release-notes.md` subsection:

````markdown
### A2. Apply the build's range mode

`range_mode` is `cumulative` for a public build or the first build of a phase,
and `delta` for a later build in a phase (W1).

**Cumulative** — every fix-version ticket is a candidate. No change from the
default behaviour.

**Delta** — a ticket is a candidate only if at least one MR or commit linked to
it (its key in `mr.jira_keys[]` or `commit.jira_keys[]`) appears in a platform's
SCM shard. On a multi-platform release, that ticket's `[Platform: …]` tag lists
only the platforms whose shard placed it in range.

Tickets excluded by the delta filter are **never dropped silently**. Each one
appears in the `## Ticket Audit` table with `Included in Notes?` = `No` and
`Reason` = `Not in this build's range (<baseline_ref>..<release_ref>)`.

**Guard — a failed SCM shard must not fake an empty release.** For each platform
whose SCM receipt was `status: "failed"`, or whose `effective_range_mode` is
`cumulative` when `delta` was requested, treat that platform as **cumulative**
and record this line for W10:

```
Warning: SCM data for {platform} was unavailable — cannot compute the delta for
{version_display}. Falling back to cumulative notes for the whole {version_line}
line. Verify the range manually.
```

Without this, delta mode plus a dead `glab` would filter out every ticket and
produce notes that look legitimately empty.
````

- [ ] **Step 6: Update the W6 header block**

The shared header block gains the build-type and range lines and uses the
resolved fix version:

```markdown
# {Product} {Platform(s)} {version_display} Release Notes
**Build:** {build_number | 'N/A'}  
**Planned Release Date:** {release_date | 'TBD'}  
**Platforms:** {comma-separated platform names}  
**Fix Version:** {resolved_fix_version}  
**Build Type:** {Public Release | Prerelease ({phase}.{phase_index})}  
**Change Range:** {Cumulative | Delta} since {baseline_ref | 'unknown — date window used'}
```

- [ ] **Step 7: Use `version_display` in W8's publisher input**

The publisher's `version` key must receive `version_display` (so `2.2-final`
publishes as `2.2` and `2.2-alpha.1` keeps its suffix), and the new header
values must reach the page:

```json
{
  "product_name": "{product_name}",
  "version": "{version_display}",
  "platforms": ["Android"],
  "release_notes_path": "{TMPDIR}/release-notes.md",
  "companion_path": "{TMPDIR}/companion.md",
  "confluence_space_key": "{confluence.space_key}",
  "confluence_root_page_title": "{confluence.root_page_title}",
  "release_date": "{release_date}",
  "build_number": "{build_number}",
  "build_type": "Prerelease (alpha.1)",
  "change_range": "Cumulative since fast/release/v2.1-final",
  "today": "{today}"
}
```

Add a sentence to W8 stating that `version_display` is already normalized, so
the publisher must use it verbatim in titles and never re-derive it.

- [ ] **Step 8: Delete Step W9 entirely**

Remove the whole `## Step W9 — Compose and drop email.html` section, its bash
block, and its `---` separator. Renumber `## Step W10` to `## Step W9`.

- [ ] **Step 9: Update the final summary**

Remove the `Email drop:` line. The block becomes:

```
:white_check_mark: Release notes for {Product} {version_display} complete.

Build type:      {Public Release | Prerelease (alpha.1)}
Change range:    {Cumulative | Delta} since {baseline_ref}
Fix version:     {resolved_fix_version}

Customer notes:  {config_dir}/release-notes.md
Companion:       {config_dir}/companion.md
Confluence:      {release_page_url}   (or: not published)

Review before publishing:
- Items marked SUGGEST OMIT:    {omit_count}
- Items marked SUGGEST INCLUDE: {incl_count}
- Items marked SUGGEST NOTE:    {note_count}
```

Add a per-platform warning bullet for every delta→cumulative fallback recorded
in W6, and one reporting `tag_stats.out_of_scope` when it is non-zero:

```
Note: {platform} — {out_of_scope} tag(s) outside '{tag_prefix}' were excluded from
range resolution (legacy or other product lines).
```

- [ ] **Step 10: Update the error-recovery section**

- Hard stops: replace "empty/invalid version (W1)" with "version fails the W1
  grammar"; add "any Jira collector `status: \"failed\"`, which now includes an
  unresolvable or ambiguous fix version (W4)".
- Soft failures: remove the `drop_folder_root` entry; add "a platform whose
  delta could not be computed falls back to cumulative and warns (W6)".
- Remove the "Email-drop idempotency" bullet.

- [ ] **Step 11: Update `SKILL.md` frontmatter and body**

```yaml
description: Generate release notes for a Tablo client-app build — gathers Jira fix-version tickets and GitLab MRs/commits, drafts customer-facing notes and an internal companion doc, and publishes both to Confluence. Supports prerelease builds. Invoke with the build version, e.g. `/generate-release-notes 2.2-alpha.1`.
argument-hint: '<version, e.g. 2.2, 2.2-alpha.1, 2.2-beta.2, 2.2-final>'
```

Keep `allowed-tools`, `model: opus`, `effort: max`, and
`disable-model-invocation: true` unchanged. The body line stays as-is — it
already points at `./workflow.md`.

- [ ] **Step 12: Verify email is gone and the new wiring is present**

```bash
grep -rni "email\|onedrive\|power automate\|drop_folder_root\|drop_dir" plugins/tablo-release-notes/skills/generate-release-notes/
grep -n "Step W9\|Step W10" plugins/tablo-release-notes/skills/generate-release-notes/workflow.md
grep -c "version_display\|range_mode\|version_helper_path\|resolved_fix_version" plugins/tablo-release-notes/skills/generate-release-notes/workflow.md
```

Expected: the first prints nothing. The second shows a `Step W9` that is the
cleanup/summary step and **no** `Step W10`. The third prints `12` or more.

- [ ] **Step 13: Re-run the harness**

Run: `python3 plugins/tablo-release-notes/dev/verify_version_rules.py`
Expected: `ALL CHECKS PASSED` — proving the W1 block survived the W2–W9 edits intact.

- [ ] **Step 14: Commit**

```bash
git add plugins/tablo-release-notes/skills/generate-release-notes/workflow.md plugins/tablo-release-notes/skills/generate-release-notes/SKILL.md
git commit -m "feat(tablo-release-notes): :sparkles: wire prerelease builds through the orchestrator

W2 writes the canonical version helper to TMPDIR for the SCM collectors. W4
passes version_line so the Jira collector resolves the real fix-version name,
and W3's release-date lookup now uses that resolved name instead of a bare
version that could never match. W5 passes range_mode, tag_prefix and tag_suffix.

W6 gains delta filtering: for a later build in a phase, only tickets with a
commit or MR in the build range are published, and excluded tickets are recorded
in the audit table rather than dropped. A failed SCM shard falls back to
cumulative and warns loudly, so a dead glab cannot fake an empty release.

Deletes Step W9's email drop; Confluence is the only publish target."
```

---

### Task 7: Live verification

The harness proves the logic; this proves the wiring. No commit unless a defect is found.

**Files:**
- Read: `~/Documents/newt/git/tablo-android/.release-notes.yml`
- Possibly modify: whichever file a failure implicates

**Interfaces:**
- Consumes: everything from Tasks 1–6.
- Produces: a verified end-to-end run, or a defect report.

- [ ] **Step 1: Reinstall the renamed plugin**

The plugin name changed, so the installed copy is stale. In Claude Code run
`/plugin marketplace update` then enable `tablo-release-notes`. Confirm
`/tablo-release-notes:generate-release-notes` appears in the skill list and the
old `release-notes` entry is gone.

- [ ] **Step 2: Confirm the config has the tag prefix**

```bash
grep -n "tag_prefix" ~/Documents/newt/git/tablo-android/.release-notes.yml
```

Expected: `tag_prefix: fast/release/`. If missing, redo Task 2 Step 7 — without it the run resolves a legacy baseline.

- [ ] **Step 3: Confirm both tags the run depends on exist**

```bash
git -C ~/Documents/newt/git/tablo-android tag --list 'fast/release/v2.2-alpha.1' 'fast/release/v2.1-final'
```

Expected: both printed. These are the release ref and the baseline the run must resolve.

- [ ] **Step 4: Run the cumulative case**

From `~/Documents/newt/git/tablo-android`, run:

```
/tablo-release-notes:generate-release-notes 2.2-alpha.1
```

Verify each of these, and stop at the first that fails:

1. W1 accepts the argument — no "not a valid version" error.
2. The Jira collector resolves `2.2 - BETA - Airship Push + VSI`, printed in the metadata summary.
3. `commit_range_description` is `fast/release/v2.1-final..fast/release/v2.2-alpha.1`.
4. No `baseline_ref` outside `fast/release/` appears anywhere in the output.
5. The header shows `Build Type: Prerelease (alpha.1)` and `Change Range: Cumulative since fast/release/v2.1-final`.
6. Confluence publishes `Tablo Android 2.2-alpha.1 Release Notes` with both children.
7. Nothing mentions email, OneDrive, or a drop folder.
8. `release-notes.md` and `companion.md` land beside the config, and every fix-version ticket appears in the companion's audit table.

- [ ] **Step 5: Run the argument-rejection case**

```
/tablo-release-notes:generate-release-notes 2.2-gamma.9
```

Expected: stops at W1 with the grammar error listing valid forms, and touches no
config, Jira, or Confluence — the run must not reach W2.

- [ ] **Step 6: Run the delta case**

`fast/release/v2.2-alpha.2` may not exist yet. Check first:

```bash
git -C ~/Documents/newt/git/tablo-android tag --list 'fast/release/v2.2-alpha.*'
```

If a second alpha exists, run `/tablo-release-notes:generate-release-notes 2.2-alpha.2`
and verify: `range_mode` is `delta`; the range is
`fast/release/v2.2-alpha.1..fast/release/v2.2-alpha.2`; the header says
`Delta since fast/release/v2.2-alpha.1`; and tickets in the fix version without
a commit in that range appear in the audit table with
`Not in this build's range (…)` rather than vanishing.

If no second alpha exists, record that step 6 is **deferred** and say so
explicitly in the final report — do not claim delta mode was verified live. The
harness covers the baseline arithmetic; only the W6 filtering is unverified.

- [ ] **Step 7: Report**

State plainly which of steps 4–6 passed, which were deferred and why, and any
defect found with the file and step that caused it. Do not describe deferred
verification as passing.

---

## Self-Review

**Spec coverage.** §1a → Task 5. §1b → Task 3 (grammar, `-final` alias) + Task 4. §1c → Tasks 3–4. §1d → Tasks 2–4. §4 → Task 3. §5 → Tasks 2–4. §6 → Task 5. §7 → Task 6 Step 5. §8 → Task 6 Steps 6–7. §9 → Tasks 1, 2, 6. §10 → Task 1. §11 → every file appears in a task. §12 → Task 3 (harness 1–5) + Task 7 (live 6–7). §13 risks: the `-QA.1` gap and the `_ios`/`_tvos` tie are asserted as *exclusions* in Task 3's harness, which is the intended deferral, not a fix.

**Placeholder scan.** No TBD/TODO. Every code step carries runnable content; every "verify" step names a command and its expected output. Task 7 has no code because it is an interactive run, and each of its checks is a concrete observable.

**Type consistency.** `parse_version` keys (`line`, `line_tuple`, `phase`, `phase_index`, `is_public`, `range_mode`, `normalized`) are defined in Task 3 and consumed under those names in Tasks 4 and 6. `pick_baseline` returns a 3-tuple `(tag, warnings, stats)` and `resolve_release_tag` a 2-tuple `(tag, warnings)` — Task 4's snippet unpacks both correctly. `baseline_ref` / `release_ref` replace `prev_tag` / `release_tag` consistently, and Task 4 Step 2 flags the C2/C5 renames. `effective_range_mode` and `resolved_fix_version` are produced in Tasks 4 and 5 and read in Task 6 under the same names. `version_display` is derived from `normalized` in Task 3 and used in Task 6 Steps 6, 7, 9.

**One known ordering hazard.** Task 6 Step 2 moves W3's release-date lookup after W4 because it depends on `resolved_fix_version`. An implementer who edits W3 without reading Step 2 in full will leave a JQL that silently matches nothing. The step states the dependency explicitly for that reason.
