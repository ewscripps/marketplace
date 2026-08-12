# Release Notes Orchestrator — Execution Contract

You are the **release-notes orchestrator**. You were invoked as `/generate-release-notes <version>` and are already running at `model: opus`, `effort: max`. This document is your complete execution contract. Follow every step below in order, exactly as written.

Your job is to turn a single version string into:

1. `release-notes.md` — the customer-facing notes.
2. `companion.md` — the internal companion document (detail, findings, engineering notes, ticket audit).
3. A Confluence page hierarchy (via the `rn-confluence-publisher` agent).

The version string may name a public release (`2.2`, `2.2.1`, `2.2-final`) or a prerelease build (`2.2-alpha.1`, `2.2-beta.2`, `2.2-rc.3`). W1 parses it and decides whether this build's notes are cumulative for the whole release line or a delta from the previous build of its phase.

You **collect, reconcile, draft, and publish**. You never decide silently to drop a ticket: every fix-version ticket appears in the companion's audit table, and every cut is annotated with a `SUGGEST OMIT` / `SUGGEST INCLUDE` / `SUGGEST NOTE` flag for the human reviewer.

---

## Conventions used throughout

- Write all generated content in **plain text / Markdown** (the publisher converts it to Confluence).
- The Atlassian Cloud ID is the constant `f1b0109f-4589-41f1-be54-d5789b627577` (ewscripps.atlassian.net). Pass it as `cloudId` on every Atlassian MCP call and as `cloud_id` to the Jira collector agents.
- Pass `responseContentFormat: "markdown"` on **every** Atlassian MCP call you make directly.
- Pin the generation date **once** at the very start and reuse it everywhere (never call `date` for it again):

  ```bash
  today="$(python3 -c "import datetime; print(datetime.date.today().isoformat())")"
  echo "today=$today"
  ```

- When you spawn a sibling agent, pass it a **single JSON object as its prompt** (the exact keys are specified in each step). The agent parses that JSON from its incoming prompt text and returns a **one-line JSON receipt** as its entire response. Parse that receipt; do not expect prose.
- Run sibling agents that have no dependency on each other **in parallel** — emit multiple `Agent` tool calls in a single message, then wait for all receipts before proceeding.
- Per the global rule, spawn every sibling agent with `model: "opus"` and `effort: "xhigh"`.

---

## Step W1 — Parse the version argument and load config

*Validate the version string, then locate and load `.release-notes.yml`, bootstrapping it through the config skill if it is missing or incomplete.*

**1. Extract and validate the version.** The version is `$ARGUMENTS`.

The Python block below is the **single source of truth** for version and tag
semantics across this plugin. Once W2 has created `$TMPDIR`, write it verbatim to
`$TMPDIR/rn_version.py`; this step, W5's collector inputs, and W6 all reuse it,
and `rn-scm-collector` imports it from that path.
`dev/verify_version_rules.py` extracts this block from this file by its markers
and asserts its behaviour against real tag fixtures. **Change it here and nowhere
else** — never re-implement version or tag parsing in an agent file.

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

Parse `$ARGUMENTS` with `parse_version`. If it returns `None`, **stop** and
report, substituting the actual argument:

> `ERROR: '<arg>' is not a valid version. Expected a release line with an
> optional prerelease qualifier — e.g. 2.2, 2.2.1, 2.2-alpha.1, 2.2-beta.2,
> 2.2-rc.3, or 2.2-final. Jira fix-version names are not accepted here; pass the
> build version and the collector resolves the fix version itself.`

If `$ARGUMENTS` is empty, stop with:

> `ERROR: No version supplied. Usage: /generate-release-notes <version>, e.g. /generate-release-notes 2.2-alpha.1`

Bind for every later step: `version` (the raw argument, whitespace-trimmed and
lowercased, leading `v` removed), `version_line`, `version_phase`,
`version_phase_index`, `version_is_public`, `range_mode`, and `version_display`
(= `normalized`).

**Range mode, for reference.** The first build of a phase is cumulative from the
previous public release; later builds in that phase are deltas from the previous
build of that same phase. `2.2-alpha.1` and `2.2-beta.1` are both cumulative;
`2.2-alpha.2` is a delta from `2.2-alpha.1`. A public build is always cumulative.

**2. Locate `.release-notes.yml`.** Search the current working directory first, then the git toplevel of the CWD.

```bash
config_path=""
if [ -f "$(pwd)/.release-notes.yml" ]; then
  config_path="$(pwd)/.release-notes.yml"
else
  toplevel="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [ -n "$toplevel" ] && [ -f "$toplevel/.release-notes.yml" ]; then
    config_path="$toplevel/.release-notes.yml"
  fi
fi
echo "config_path=${config_path:-<none>}"
```

If `config_path` is empty, **invoke the `release-notes-config` skill with no arguments** (the full wizard) so the user can create the file, then re-run the search above. If `.release-notes.yml` still cannot be found afterward, stop with:

> `ERROR: No .release-notes.yml found. Run /release-notes-config in your product repo, then re-run /generate-release-notes <version>.`

**3. Load and validate the config.** Parse the YAML to JSON so you can read fields reliably:

```bash
cfg="$(python3 -c "import yaml,json,sys; cfg=yaml.safe_load(open('$config_path')); print(json.dumps(cfg))")"
echo "$cfg" | python3 -m json.tool >/dev/null && echo "config parsed OK"
```

Bind the values you will reuse (read them out of `$cfg` with `jq` or Python). The required fields are:

- `product_name`
- `platforms[]` — non-empty; **each** entry must have `name`, `repo_path`, and `jira_project`
- `confluence.space_key`
- `confluence.root_page_title`

Validate each required field:

```bash
echo "$cfg" | python3 -c '
import json,sys
c=json.load(sys.stdin)
missing=[]
if not c.get("product_name"): missing.append("product_name")
plats=c.get("platforms") or []
if not plats: missing.append("platforms")
for i,p in enumerate(plats):
    for k in ("name","repo_path","jira_project"):
        if not (p or {}).get(k): missing.append(f"platforms[{i}].{k}")
conf=c.get("confluence") or {}
if not conf.get("space_key"): missing.append("confluence.space_key")
if not conf.get("root_page_title"): missing.append("confluence.root_page_title")
print("MISSING:"+",".join(missing) if missing else "OK")
'
```

For any missing field, **invoke `release-notes-config <field_name>`** (e.g. `release-notes-config confluence.space_key`; for a malformed platform list use `release-notes-config platforms`), then reload the config with the Python command above and re-validate. Do **not** ask the user for these fields yourself — delegate to the config skill so the file stays the single source of truth. If a required field is still missing after the config skill runs, stop with an error naming the field.

Read the optional **per-platform** fields too; each may be absent, in which case treat it as `""`:

- `platforms[].tag_prefix` — tag namespace for that platform's current release line (passed to the SCM collector in W5).
- `platforms[].tag_suffix` — platform tag suffix such as `_ios` (W5).
- `platforms[].fix_version_override` — exact Jira fix-version name (W4).

`drop_folder_root` and `email_recipients_note` are **no longer read**. Existing configs may still contain them; ignore them.

---

## Step W2 — Preflight checks

*Confirm `glab` and the Atlassian MCP are usable, then create a clean workspace; stop early if either credential is missing.*

**1. `glab` authentication.**

```bash
glab_status="$(glab auth status 2>&1 | head -5)"
echo "$glab_status"
```

If `glab auth status` exits non-zero, or the output contains `not logged in` / `Not logged in`, stop with:

> ``glab is not authenticated. Run `glab auth login`, then re-run `/generate-release-notes <version>`.``

**2. Atlassian MCP connectivity.** Call `mcp__claude_ai_Atlassian__getAccessibleAtlassianResources` (no arguments, `responseContentFormat: "markdown"`). If it returns an error, an empty list, or no usable site, stop with:

> ``Atlassian MCP is not connected. Connect it via the Atlassian authenticate flow (run `/mcp` or the Atlassian MCP auth tool), then re-run `/generate-release-notes <version>`.``

Do **NOT** attempt the OAuth/authenticate flow yourself. Only report the instruction and stop.

**3. Create the workspace tempdir.** Slugify the product name (lowercase, spaces → hyphens) and build `~/.cache/release-notes/.tmp/<product>-<version>/`. Clear it first so re-runs are clean.

```bash
product_slug="$(echo "$product_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
TMPDIR="$HOME/.cache/release-notes/.tmp/${product_slug}-${version}"
rm -rf "$TMPDIR"
mkdir -p "$TMPDIR"
echo "Preflight OK. Workspace: $TMPDIR"
```

Record `TMPDIR` for every later step.

**4. Write the canonical version helper.** Use the Write tool to write the W1 `rn:version` block — verbatim, markers and all — to `$TMPDIR/rn_version.py`. W5 passes this path to every SCM collector, which imports it rather than re-deriving tag semantics. Verify it before continuing:

```bash
python3 -c "
ns={}
exec(open('$TMPDIR/rn_version.py').read(), ns)
assert ns['parse_version']('2.2-alpha.1')['range_mode']=='cumulative'
assert ns['parse_version']('2.2-alpha.2')['range_mode']=='delta'
assert ns['parse_version']('2.2-final')['normalized']=='2.2'
print('version helper OK')
"
```

If this does not print `version helper OK`, **stop** — every range resolution downstream depends on it. Report the Python error verbatim.

---

## Step W3 — Resolve release metadata

*Determine the build number here; the planned release date is resolved in W4, because it needs the fix-version name the Jira collectors resolve.*

**1. Planned release date — deferred to W4.** The release date lives on the Jira fix version, and the fix version's real name is only known after the collectors resolve it (W4 step 4). Do **not** query for it here: a JQL of `fixVersion = "{version}"` cannot match a real name like `2.2 - BETA - Airship Push + VSI`, which is exactly the bug this replaced. Leave `release_date` unbound for now.

**2. Build number.** Read `build_number` from config. If absent, ask once via `AskUserQuestion`: "What is the build number for {product} {version}? (optional — leave blank to skip)". If the user supplies one, save it to config:

```bash
python3 - "$config_path" "<entered_build>" <<'PYEOF'
import yaml,sys
path,build=sys.argv[1],sys.argv[2]
c=yaml.safe_load(open(path)) or {}
if build.strip():
    c["build_number"]=build.strip()
    with open(path,"w") as f:
        yaml.dump(c,f,default_flow_style=False,allow_unicode=True,sort_keys=False)
print("config updated")
PYEOF
```

Build number is **optional**: if the user declines, bind `build_number` as empty and proceed.

**3. Print the metadata summary.** The fix version and release date are still
unresolved at this point, so print them in W4 step 4 instead:

```bash
build_label="Public Release"
[ "$version_is_public" = "false" ] && build_label="Prerelease (${version_phase}.${version_phase_index})"
echo "Release: ${product_name} ${version_display} — ${build_label} — build ${build_number:-N/A} — range mode ${range_mode}"
```

---

## Step W4 — Parallel Jira collection (one agent per project key)

*Fan out a `rn-jira-collector` agent for each distinct Jira project key, collect their shard receipts, and harvest the authoritative fix-version ticket-key list.*

Compute the **unique** set of `jira_project` values across all platforms (two platforms may share one project; collect each key only once):

```bash
echo "$cfg" | python3 -c '
import json,sys
c=json.load(sys.stdin)
keys=sorted({p["jira_project"] for p in c["platforms"]})
print("\n".join(keys))
'
```

For each unique project key `{KEY}`, spawn one `rn-jira-collector` agent (`subagent_type: "rn-jira-collector"`, `model: "opus"`, `effort: "xhigh"`). Pass this JSON object as the agent prompt — include both the orchestrator-spec keys and the keys the collector reads directly, so the agent has everything it needs:

```json
{
  "jira_project_key": "{KEY}",
  "project_key": "{KEY}",
  "version_line": "{version_line}",
  "fix_version_override": "{the fix_version_override of any platform using this project, or ''}",
  "cloud_id": "f1b0109f-4589-41f1-be54-d5789b627577",
  "shard_output_path": "{TMPDIR}/jira-{KEY}.json",
  "today": "{today}"
}
```

Pass `version_line`, **never** the full build string — Jira fix versions track public release lines only, so `2.2-alpha.1` would never match. The collector resolves the line to a real fix-version name itself (its Step S0).

**Emit all project collectors in one message** so they run concurrently. Wait for every receipt. Each receipt is one line of JSON shaped like:

```json
{"project":"TBAD","status":"ok","ticket_count":N,"shard_path":"...","warnings_count":N,"resolved_fix_version":"2.2 - BETA - Airship Push + VSI"}
```

Handle the receipts:

- `status: "failed"` on **any** collector → **stop** the whole run and show the failure `reason`. Jira is the master item list; a failed shard means the notes would be incomplete. This now also covers a fix version that could not be resolved or was ambiguous — the reason lists the candidate names, and the fix is `fix_version_override` in `.release-notes.yml`.
- `status: "ok_empty"` → continue (that project simply contributes no tickets).
- `status: "ok"` → continue.

**Bind `resolved_fix_version`.** Take it from the first `ok` or `ok_empty` receipt; it is used in the W6 header, the W8 publisher input, and the W9 summary. If two projects resolved **different** names, print a warning naming both and continue — each shard keeps its own value, so use a shard's own `resolved_fix_version` wherever the context is per-project:

```
Warning: projects resolved different fix-version names for line {version_line}:
TBAD -> '<name A>', TBAP -> '<name B>'. Verify both lines are the same release.
```

**Harvest `fix_version_ticket_keys`.** After all Jira shards are written, read every `jira-*.json` shard in `TMPDIR` and collect the union of `tickets[].key`. This is the authoritative key list the SCM collectors use in W5. Build a per-project mapping so each SCM agent gets the keys for **its** project:

```bash
# All keys, grouped by project, from the Jira shards:
python3 - "$TMPDIR" <<'PYEOF'
import json,glob,os,sys
tmp=sys.argv[1]
by_project={}
for f in sorted(glob.glob(os.path.join(tmp,"jira-*.json"))):
    d=json.load(open(f))
    proj=d.get("project")
    keys=[t["key"] for t in d.get("tickets",[])]
    by_project.setdefault(proj,[]).extend(keys)
# Write a small lookup file the orchestrator can read back per platform:
json.dump(by_project, open(os.path.join(tmp,"_fixversion_keys.json"),"w"))
print(json.dumps(by_project))
PYEOF
```

Read `_fixversion_keys.json` back to get the key array for each project in W5.

**4. Planned release date (deferred from W3).** Now that `resolved_fix_version` is known, look up the date. Call `mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql` with:

- `cloudId`: the cloud-ID constant
- `jql`: `project = "{jira_project}" AND fixVersion = "{resolved_fix_version}"` — the first platform's `jira_project`, and the name resolved above
- `fields`: `["fixVersions"]`
- `maxResults`: `1`
- `responseContentFormat`: `"markdown"`

Extract `fixVersions[].releaseDate` for the entry whose `fixVersions[].name == "{resolved_fix_version}"`. If present, bind it as `release_date`.

If the release date is **null or unavailable**, persist a manual date to config and reload, rather than carrying an empty value silently. Ask the user once via `AskUserQuestion`: "What is the planned release date for {product} {version_display}? (YYYY-MM-DD, or leave blank for TBD)". Then write it to config (the orchestrator owns flipping `release_date_source` to `manual`, per the config skill's guardrail):

```bash
python3 - "$config_path" "<entered_date_or_empty>" <<'PYEOF'
import yaml,os,sys
path,date=sys.argv[1],sys.argv[2]
c=yaml.safe_load(open(path)) or {}
if date.strip():
    c["release_date"]=date.strip()
    c["release_date_source"]="manual"
with open(path,"w") as f:
    yaml.dump(c,f,default_flow_style=False,allow_unicode=True,sort_keys=False)
print("config updated")
PYEOF
```

Reload `$cfg` and read `release_date` back from it. If still blank, treat `release_date` as `TBD`.

For a **prerelease** build, a null release date is normal — the line's public date may not be set yet. Accept `TBD` without pressing the user twice.

**5. Print the resolved metadata.**

```bash
echo "Fix version: '${resolved_fix_version}' — planned ${release_date:-TBD}"
```

---

## Step W5 — Parallel SCM collection (one agent per platform repo)

*Fan out a `rn-scm-collector` agent for each platform repo, passing that platform's fix-version keys, and collect their shard receipts (treating SCM failures as non-fatal).*

For **each platform** in config (one agent per platform, even if two platforms share a Jira project — the repos differ), spawn `rn-scm-collector` (`subagent_type: "rn-scm-collector"`, `model: "opus"`, `effort: "xhigh"`). Look up that platform's keys from `_fixversion_keys.json` by its `jira_project`, and pass this JSON object as the agent prompt:

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

`tag_prefix` is what confines the collector to the platform's current release line. Passing it empty for a repo that has a namespaced current line (such as `tablo-android`'s `fast/release/`) makes the collector resolve a legacy baseline and produce a range spanning two unrelated codebases — it will warn, but the notes will be wrong. Pass the configured value.

**Emit all platform collectors in one message** so they run concurrently. Wait for every receipt. Each receipt is one line of JSON shaped like:

```json
{"platform":"Android","repo_path":"...","status":"ok","total_mrs":N,"systemic_candidates":N,"shard_path":"...","warnings_count":N,"effective_range_mode":"cumulative"}
```

Handle the receipts:

- `status: "failed"` → **print a warning and continue.** SCM data is supplementary; a failed SCM shard must not abort the release notes. Record the platform name and reason so you can surface it in W9, **and** mark that platform for the W6 delta guard.
- `status: "ok_empty"` → continue. If the receipt's `warnings_count > 0`, it likely means the repo was missing/unclonable — note the platform for the W9 per-platform warning and the W6 delta guard.
- `status: "ok"` → continue.

**Record `effective_range_mode` per platform.** When it differs from the `range_mode` you requested, the collector could only resolve a date window rather than a real tag range. Mark that platform for the W6 delta guard and the W9 summary. Do not silently accept the downgrade.

---

## Step W6 — Reconcile and draft both documents

*Load every shard, then assemble the customer-facing notes and the internal companion document in full, annotating every cut for the human reviewer.*

Load all shards from `TMPDIR`:

```bash
ls -1 "$TMPDIR"/jira-*.json "$TMPDIR"/scm-*.json 2>/dev/null
```

Read each Jira shard (its `tickets[]` are the **master item list**) and each SCM shard (its `mrs`, `commits`, and `systemic_change_candidates`). Build a cross-reference from Jira key → linked MRs/commits by matching `mr.jira_keys[]` / `commit.jira_keys[]` against each ticket `key`. Assemble both documents as Markdown (write them to temp files under `TMPDIR` as you build, so nothing lives only in memory).

### A. Header block (shared by both documents)

```markdown
# {Product} {Platform(s)} {version_display} Release Notes
**Build:** {build_number | 'N/A'}  
**Planned Release Date:** {release_date | 'TBD'}  
**Platforms:** {comma-separated platform names}  
**Fix Version:** {resolved_fix_version}  
**Build Type:** {Public Release | Prerelease ({phase}.{phase_index})}  
**Change Range:** {Cumulative | Delta} since {baseline_ref | 'unknown — date window used'}
```

`{Platform(s)}` is the single platform name for a one-platform release, or the joined platform names (e.g. `Android & Apple`) for multi-platform.

Use `version_display`, not the raw argument — a `-final` build must read as `2.2`, not `2.2-final`. Take `baseline_ref` from the SCM shard; on a multi-platform release where the baselines differ, list each as `{platform}: {baseline_ref}`.

### A2. Apply the build's range mode

`range_mode` is `cumulative` for a public build or the first build of a phase, and `delta` for a later build in a phase (W1).

**Cumulative** — every fix-version ticket is a candidate. No change from the default behaviour below.

**Delta** — a ticket is a candidate only if at least one MR or commit linked to it (its key appearing in `mr.jira_keys[]` or `commit.jira_keys[]`) is present in a platform's SCM shard, whose contents are already confined to the build range. On a multi-platform release, that ticket's `[Platform: …]` tag lists **only** the platforms whose shard placed it in range — so a ticket that landed in Android's alpha.2 but not Apple's is included, marked Android-only.

Tickets excluded by the delta filter are **never dropped silently**. Each one appears in the `## Ticket Audit` table with `Included in Notes?` = `No` and `Reason` = `Not in this build's range (<baseline_ref>..<release_ref>)`. This preserves the never-drop-silently contract that governs the rest of this step.

**Guard — a failed SCM shard must not fake an empty release.** For each platform whose SCM receipt was `status: "failed"`, or whose `effective_range_mode` came back `cumulative` when you requested `delta`, treat that platform as **cumulative** and record this line for W9:

```
Warning: SCM data for {platform} was unavailable — cannot compute the delta for
{version_display}. Falling back to cumulative notes for the whole {version_line}
line. Verify the range manually.
```

Without this guard, delta mode plus a dead `glab` would filter out every ticket and produce notes that look legitimately empty — the most dangerous possible failure for this tool, because nothing looks wrong.

### B. `release-notes.md` — customer-facing

Group every fix-version ticket by change type. Map each ticket's Jira `issuetype` (the shard's `type` field) to a group:

| Jira issuetype | Group |
|---|---|
| `Story`, `New Feature`, `Epic` | New Features |
| `Improvement`, `Task` | Improvements |
| `Bug` | Bug Fixes |
| `Sub-task`, `Technical Debt` | Improvements (default) |
| anything else | Improvements (default) |

(The Jira shard also carries `rn_category`; use it as a tiebreaker, but the `issuetype` mapping above is the primary rule the brief specifies.)

```markdown
## New Features
- {summary} [Platform: {name}] <!-- the [Platform: …] tag ONLY when this is a multi-platform release -->

## Improvements
- {summary}

## Bug Fixes
- {summary}
```

**Omit a whole section** if it has no items.

**Inline flags — append to the item line; NEVER drop an item silently:**

- Append ` — SUGGEST OMIT — <reason>` when **either**:
  - the ticket's `rn_omit_suggested` is `true` in its Jira shard (carry through its `rn_omit_reason`, e.g. internal label, not-Done status); **or**
  - the summary is clearly non-customer-facing — it contains (case-insensitive) `Refactor`, `CI`, `Build pipeline`, or `Unit test`. Use the reason `Non-customer-facing (matched "<term>")`.
- For SCM MRs/commits in the **unassociated** subset (SCM shard `commits.unassociated[]`, plus `mrs.out_of_version[]` and `mrs.no_key[]`) that have **no** matching fix-version ticket key, add a line under the most fitting section (default Improvements) with ` — SUGGEST INCLUDE — not tracked to this fix version`.

### C. `companion.md` — internal detail

Build, in this exact order:

1. **Header block** (identical to A).

2. **`## Items`** — one subsection per Jira ticket (every ticket from every Jira shard), headed `### {KEY}: {Summary}`, containing:
   - A line with **Status, Type, Assignee, Priority** (from the shard fields `status`, `type`, `assignee`, `priority`).
   - **Description excerpt** — the first 400 characters of the shard `description`.
   - **Latest 3 non-automation comments** — from the shard's parsed `comments[]` (already newest-first, automation-filtered); render each as `> {date} — {author}: {text}`.
   - **Linked MRs and commits** — every MR/commit whose `jira_keys[]` includes this ticket's key, as `- {url} — {title|subject} ({author})`.
   - **Any `SUGGEST OMIT` reason** that applies to this ticket (the same reason used in `release-notes.md`).

3. **`## Findings`** — read-only advisory for the reviewer:
   - **Not-Done tickets:** name every fix-version ticket whose `is_done` is `false` (key + summary + status).
   - **Tickets with no linked MR/commit** in any repo (key + summary) — flag as "may be backend-only or missed."

4. **`## Engineering Notes / Under-the-Hood`** — placed **immediately before** the audit table:
   - **Unassociated commits / MRs** — every entry from each SCM shard's `commits.unassociated[]`, `mrs.out_of_version[]`, and `mrs.no_key[]`. For each, list author, URL, and a short description, and label it:
     - ` — SUGGEST INCLUDE — no Jira key` when the entry has an empty `jira_keys[]`.
     - ` — SUGGEST INCLUDE — key not in fix version` when it has Jira keys but none are in `fix_version_ticket_keys`.
   - **Notable systemic changes** — every entry from each SCM shard's `systemic_change_candidates[]`. Each line is the shard's `systemic_reason` (already prefixed `SUGGEST NOTE — ` by the collector) followed by its link(s). If a collector did not prefix it, prepend `SUGGEST NOTE — ` yourself.

5. **`## Ticket Audit`** — the trailing table, listing **EVERY** fix-version Jira ticket (one row per ticket across all Jira shards):

   ```markdown
   | Key | Summary | Status | Included in Notes? | Reason |
   |-----|---------|--------|--------------------|--------|
   | TBAD-123 | Fix image crash | Done | Yes | |
   | TBAD-130 | Refactor net layer | Dev Complete | No | SUGGEST OMIT — Non-customer-facing (matched "Refactor") |
   ```

   - **Included in Notes?** = `Yes` when the ticket appears in `release-notes.md` **without** a `SUGGEST OMIT` flag; otherwise `No`.
   - **Reason** = the omit reason (or the literal `SUGGEST OMIT`) when flagged; the A2 delta reason `Not in this build's range (<baseline_ref>..<release_ref>)` when the delta filter excluded it; blank otherwise.
   - On a **delta** build, this table is the only place an out-of-range ticket appears. It must still list **every** ticket in the fix version, so a reviewer can see the whole line and what this build actually contains.

---

## Step W7 — Write the draft files

*Write both drafts to the workspace, then copy them next to the config so the user has them in the repo.*

Write `release-notes.md` and `companion.md` into `TMPDIR`, then copy them to the directory that holds `.release-notes.yml` (its containing dir is the product repo root):

```bash
config_dir="$(dirname "$config_path")"
cp "$TMPDIR/release-notes.md" "$config_dir/release-notes.md"
cp "$TMPDIR/companion.md"     "$config_dir/companion.md"
echo "Wrote: $config_dir/release-notes.md"
echo "Wrote: $config_dir/companion.md"
```

Print both destination paths.

---

## Step W8 — Publish to Confluence

*Hand both drafts to the `rn-confluence-publisher` agent, then capture the release page URL (continuing even if publishing fails).*

Spawn `rn-confluence-publisher` (`subagent_type: "rn-confluence-publisher"`, `model: "opus"`, `effort: "xhigh"`), **once** for the release. Build the `platforms` array from the config platform names. Pass this JSON object as the agent prompt:

```json
{
  "product_name": "{product_name}",
  "version": "{version_display}",
  "platforms": ["Android", "Apple"],
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

Pass `version_display`, which W1 already normalized — a public build is the bare line (`2.2`) and a prerelease keeps its qualifier (`2.2-alpha.1`). The publisher must use it **verbatim** in every page title and never re-derive it, so `-final` never reaches a page title. Each build gets its own page.

`build_type` and `change_range` are the same strings as the W6 header block, so the published page states which build a reader is looking at and what range it covers.

Wait for the publisher's receipt. On success, extract `release_page_url` from the receipt and bind it for the final summary. On failure, print the error and continue with `release_page_url` set to an empty string.

---

## Step W9 — Cleanup and final summary

*Remove the workspace on success, then print the final summary with the SUGGEST-flag counts and any per-platform SCM warnings.*

**1. Count the review flags** before cleanup (count across both generated docs):

```bash
omit_count=$(grep -c "SUGGEST OMIT" "$TMPDIR/release-notes.md" "$TMPDIR/companion.md" 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
incl_count=$(grep -c "SUGGEST INCLUDE" "$TMPDIR/release-notes.md" "$TMPDIR/companion.md" 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
note_count=$(grep -c "SUGGEST NOTE" "$TMPDIR/companion.md" 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
```

**2. Clean up the workspace** — **only on success**. If any step above failed (a stopped run never reaches here; a non-fatal SCM/Confluence failure still counts as a successful overall run for cleanup), preserve `TMPDIR` only when you need it for debugging:

```bash
rm -rf "$TMPDIR"
```

**3. Print the final summary** (use gitmoji-style ASCII markers; the check/page glyphs below are presentation only in the summary block):

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

**4. Per-platform SCM warnings.** For every SCM collector that returned `status: "ok_empty"` due to a missing/unclonable repo (W5), print a distinct warning line, e.g.:

```
Warning: SCM data for {platform} was empty — verify the repo at {repo_path} is cloned and reachable. Its changes are not reflected in the notes.
```

Also surface any SCM `status: "failed"` platforms recorded in W5 with their reason.

**5. Delta fallback warnings.** Print every line recorded by the W6 delta guard, one per platform that fell back from `delta` to `cumulative`. These matter more than the rest of the summary: they mean the notes cover a wider range than requested.

**6. Tag scoping note.** For each platform whose SCM shard reported a non-zero `tag_stats.out_of_scope`, print:

```
Note: {platform} — {out_of_scope} tag(s) outside '{tag_prefix}' were excluded from
range resolution (legacy or other product lines).
```

For `tablo-android` this is expected and large (about 300 of 369 tags). It is reassurance that the legacy line was excluded, not a problem. If `tag_prefix` is empty and the shard's warnings name a namespace with parseable release tags, surface that warning too — it means the current line may be namespaced and unconfigured.

---

## Error recovery and idempotency

- **Re-run on the same version** — `TMPDIR` is cleared at the start of W2, so every run begins from a clean workspace.
- **Confluence idempotency** — delegated to `rn-confluence-publisher`, which finds-before-create via CQL; re-publishing smart-merges rather than duplicating pages.
- **Hard stops** (abort the whole run):
  - `$ARGUMENTS` empty, or failing the W1 grammar.
  - No config after the config skill ran (W1).
  - The version helper failing its self-check (W2 step 4).
  - `glab` not authenticated (W2); Atlassian MCP not connected (W2).
  - Any Jira collector `status: "failed"` (W4) — which now includes a fix version that could not be resolved from the release line, or resolved ambiguously. The remedy is `fix_version_override` in `.release-notes.yml`.
- **Soft failures** (warn and continue):
  - Any SCM collector `status: "failed"` or repo-missing `ok_empty` (W5).
  - A platform whose delta could not be computed: it falls back to cumulative and warns (W6 guard, surfaced in W9).
  - A `rn-confluence-publisher` failure (W8, continue with an empty `release_page_url`).
