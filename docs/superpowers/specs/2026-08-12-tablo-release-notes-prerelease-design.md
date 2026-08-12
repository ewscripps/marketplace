# tablo-release-notes v2 — Prerelease Versions, Confluence-Only Output, Rename

**Date:** 2026-08-12
**Branch:** `generate-release-notes-plugin-v2`
**Plugin:** `release-notes` v1.0.0 → `tablo-release-notes` v2.0.0

---

## 1. Problem

`/generate-release-notes 2.2-alpha.1` fails at Step W1. The validation pattern
`^[0-9]+\.[0-9]+(\.[0-9]+)?$` accepts only plain `major.minor[.patch]`, so every
prerelease build is rejected before any work starts.

Investigating that failure surfaced three further defects that make the plugin
non-functional for its actual target repos:

**1a. The Jira query can never match.** Step W4 issues
`fixVersion = "{version}"`. Project TBAD has exactly four fix versions, none of
them semver:

```
2.1 - BETA - Pause Ads + DPI + misc
2.2 - BETA - Airship Push + VSI
2.3 - Pause Ads Phase 2
2.4 - Support Diagnostics + Mobile Parity
```

A version argument can never equal one of those strings — and the W1 regex
forbids the spaces that would be needed to pass one verbatim. Jira collection
has never returned tickets for TBAD.

**1b. `-final` does not exist.** No `-final` tag exists in any Tablo repo. The
real suffixes are `-alpha.N`, `-beta.N`, `-rc.N`, `-release`,
`-release-hotfix[N]`, plus platform suffixes `_ios`, `_tvos`, `_ENGINE`.
Android's GA build is a bare `v2.2`; Apple's and Roku's is `v2.4.0-release`.

**1c. Git sorts prereleases above their release.** `rn-scm-collector` C1 picks
the baseline with `git tag --sort=-version:refname | grep -v <current> | head -1`.
Verified against `tablo-android` (369 tags):

```
$ git tag --list 'v2.2*' --sort=-version:refname
v2.2.2-alpha.1
v2.2.2
v2.2.1-beta.1
...
v2.2
```

`v2.2.2-alpha.1` ranks above `v2.2.2` and `v2.2-beta.1` above `v2.2`, so the
baseline resolves to the repo's newest tag rather than the build's predecessor.
Every prerelease commit range would be wrong.

## 2. Goals

- `/generate-release-notes <version>` accepts `2.2`, `2.2.1`, `2.2-alpha.1`,
  `2.2-beta.2`, `2.2-rc.3`, `2.2-final`, `2.2-release`.
- Prerelease builds report the correct set of changes per the phase rule (§4).
- Jira fix-version lookup resolves against the real, freeform version names.
- Commit ranges are correct for prerelease tags.
- The plugin is named for what it is: Tablo client-app release notes.

## 3. Non-goals

- Email / `email.html` / OneDrive / Power Automate output — **removed entirely**
  (§9). Confluence is the only publish target.
- Retagging any product repo to introduce a `-final` convention.
- Changing Jira fix-version naming.
- Supporting non-Tablo products. The plugin is explicitly Tablo-scoped.

## 4. Version grammar and range semantics

### 4.1 Grammar

```
^([0-9]+\.[0-9]+(\.[0-9]+)?)(-(alpha|beta|rc|final|release)(\.([0-9]+))?)?$
```

Parsed fields:

| Field | Meaning |
|---|---|
| `line` | `major.minor[.patch]` — the public release line, e.g. `2.2` |
| `phase` | `alpha` \| `beta` \| `rc` \| `public` |
| `phase_index` | integer, default `1` when the suffix omits `.N` |
| `is_public` | true for a bare line, `-final`, or `-release` |

`-final` and `-release` both normalize to `phase = public`. `rc` is included
because `v1.7.4-rc.3`-style tags exist in `tablo-android`. Phase matching is
case-insensitive on input; the normalized lowercase form is used downstream.

Input is normalized before matching: surrounding whitespace is stripped and a
single leading `v` is removed, so `v2.2-alpha.1` is accepted and treated as
`2.2-alpha.1`. Tags carry the `v`, so users will type it; rejecting it would be
a pointless footgun.

`line` compares as an integer tuple with a missing patch treated as `0`:
`2.2` → `(2,2,0)`, `2.1.9` → `(2,1,9)`.

### 4.2 Range mode

**The first build of a phase is cumulative; later builds in that phase are
deltas.**

```
range_mode = cumulative  if is_public or phase_index == 1
             delta       if phase_index >= 2
```

| Version | Baseline | Mode |
|---|---|---|
| `2.2-alpha.1` | `v2.1.9` — prior line's GA | cumulative |
| `2.2-alpha.2` | `v2.2-alpha.1` | delta |
| `2.2-beta.1` | `v2.1.9` — prior line's GA | cumulative |
| `2.2-beta.2` | `v2.2-beta.1` | delta |
| `2.2-final` / `2.2` | `v2.1.9` — prior line's GA | cumulative |
| `2.2.1-alpha.1` | `v2.2` — prior line's GA | cumulative |

Rationale: alpha.1 and beta.1 each open a new test cycle, so their audience
needs the whole line's content; subsequent builds within a cycle only need what
changed since the last build handed to that audience.

### 4.3 Baseline definitions

- **delta** — the highest tag in the same `line` and same `phase` whose
  `phase_index` is strictly less than this build's. Using "highest below"
  rather than "index − 1" means a skipped `alpha.2` does not break `alpha.3`.
- **cumulative** — the highest **public** tag whose `line` is strictly less
  than this build's line.
- If neither yields a tag, fall back to the existing C1 date-window strategy
  and warn.

## 5. Tag resolution (`rn-scm-collector`, C1)

### 5.1 Release tag candidates

Ordered; first match wins.

- `is_public` → `v<line>`, `<line>`, `v<line>-release`, `v<line>-final`
- prerelease → `v<line>-<phase>.<n>`, `<line>-<phase>.<n>`

This is what makes `-final` an alias rather than a literal: `2.2-final`
resolves to Android's `v2.2` and Apple's `v2.4.0-release` shape without either
repo changing.

### 5.2 Platform suffix tolerance

Every candidate additionally matches with an optional trailing
`_<alnum>` segment, covering `_ios`, `_tvos`, `_ENGINE`. On multiple matches:

1. prefer the unsuffixed tag;
2. else the suffix matching the platform name case-insensitively;
3. else the first match, plus a warning naming all matches.

Optional per-platform `tag_suffix` in `.release-notes.yml` (e.g. `_ios`) is the
escape hatch; when set it is tried first and preferred.

### 5.3 Ordering implementation

`--sort=-version:refname` is removed from baseline selection (§1c). Replace it
with an inline Python comparator that parses each tag with the §4.1 grammar and
sorts on `(line_tuple, phase_rank, phase_index)` where
`phase_rank = alpha:0, beta:1, rc:2, public:3`. Tags that do not parse are
ignored for ordering (`vizbee-staging-test`, `v2.0.0-release-hotfix2_ios`) but
still counted in a warning so nothing disappears silently.

`--sort=-version:refname` may remain wherever the collector merely needs a
stable listing, not a semantic predecessor.

## 6. Jira fix-version resolution (`rn-jira-collector`)

Resolution moves into the collector, which already holds the Jira tools.

- New input `version_line` — the §4.1 `line` (e.g. `2.2`), never the full
  build string. Jira tracks public release lines only; a prerelease qualifier
  is never part of a fix-version name.
- The collector discovers the project's fix-version names and selects those
  whose name starts with `<version_line>`.
- Exactly one match → proceed, using that name in its real ticket JQL.
- Zero or 2+ matches → **hard stop**, receipt `status: "failed"` with a reason
  listing every candidate name found, so the user can set an override.
- New receipt/shard field `resolved_fix_version` carries the chosen name back
  for the document header and the final summary.

Config escape hatch: optional per-platform `fix_version_override` in
`.release-notes.yml`. When set, it is used verbatim and discovery is skipped.

Because prefix matching keys on the line, `2.2`, `2.2-alpha.1`, and `2.2-final`
all resolve to the same Jira fix version — which is the intended behavior.

## 7. Delta filtering (W6) and its safety guard

For `range_mode: cumulative`, behavior is unchanged: every fix-version ticket
is a candidate for `release-notes.md`.

For `range_mode: delta`, a fix-version ticket reaches `release-notes.md` only
if at least one linked MR or commit falls inside the build range in **any**
platform's SCM shard. On a multi-platform release, the ticket's
`[Platform: …]` tag lists only the platforms whose shard placed it in range —
so a ticket that landed in Android's alpha.2 but not Apple's is included, marked
Android-only. Tickets in the line but outside the range on every platform are
**not dropped silently** — they appear in the companion's Ticket Audit with
`Included in Notes? = No` and reason
`Not in this build's range (<baseline_ref>..<release_ref>)`. This preserves the
plugin's existing never-drop-silently contract.

**Safety guard.** SCM failure is a soft warning today (W5). Under delta mode a
failed or empty SCM shard would filter every ticket out and yield empty notes
that look legitimately empty. Therefore: if `range_mode == delta` and a
platform's SCM shard is `failed` or empty, that platform falls back to
`cumulative`, and the run surfaces:

```
Warning: SCM data for {platform} was unavailable — cannot compute the delta for
{version}. Falling back to cumulative notes for the whole {line} line. Verify
the range manually.
```

The collector reports `effective_range_mode` in its shard so the orchestrator
can detect a degrade it did not request.

## 8. Confluence titles

One page per build (per decision). Titles normalize public builds to the bare
line and keep the suffix for prereleases:

| Version argument | Release page title |
|---|---|
| `2.2` or `2.2-final` | `Tablo Android 2.2 Release Notes` |
| `2.2-alpha.1` | `Tablo Android 2.2-alpha.1 Release Notes` |

Child page titles follow the same normalized string
(`… 2.2-alpha.1 — Customer Notes`, `… — Companion`). `-final` never appears in
a page title.

Each page's header block gains two lines so a reader knows what they are
looking at. Rendered examples, one per build kind rather than one line with
alternatives:

```
**Build Type:** Prerelease (alpha.1)
**Change Range:** Cumulative since v2.1.9
```

```
**Build Type:** Public Release
**Change Range:** Cumulative since v2.1.9
```

```
**Build Type:** Prerelease (alpha.2)
**Change Range:** Delta since v2.2-alpha.1
```

## 9. Email removal

Delete, do not deprecate:

- Step W9 in `workflow.md` in full.
- The email drop line in the W10 summary block, and `drop_folder_root` from W1's
  optional-field read.
- `drop_folder_root` and `email_recipients_note` from the `release-notes-config`
  wizard and its documented schema.
- `userConfig.drop_folder_root` from `plugin.json`.
- Every email / OneDrive / Power Automate mention in the plugin `README.md`,
  plugin `CLAUDE.md`, `SKILL.md` descriptions, and the `marketplace.json`
  description.

`tablo-android/.release-notes.yml` already contains `drop_folder_root` and
`email_recipients_note`. Both become unread keys; YAML loading ignores them, so
no migration is required and no existing config breaks.

## 10. Rename and versioning

- `git mv plugins/release-notes plugins/tablo-release-notes`.
- `plugin.json` — `name: tablo-release-notes`, `version: 2.0.0`, Tablo-scoped
  description, `userConfig` block removed.
- `.claude-plugin/marketplace.json` — entry `name`, `source`, `description`,
  `version: 2.0.0`.
- Skill directory names are unchanged, so invocation becomes
  `/tablo-release-notes:generate-release-notes`.
- Agent names (`rn-jira-collector`, `rn-scm-collector`,
  `rn-confluence-publisher`) and the `.release-notes.yml` filename are
  unchanged — `tablo-android` already has that file.
- Plugin `README.md` and `CLAUDE.md` gain an explicit scope note: built for
  Tablo client applications (Android, Apple, Roku), assumes Tablo Jira projects
  and Tablo tag conventions, hardcoded Scripps Atlassian cloud ID.
- Root `CLAUDE.md` "Current Plugins" list gains a `tablo-release-notes` entry.
  That list currently omits `release-notes`, `edm`, `bruno`, and `wave-to-jpd`;
  only the entry for this plugin is added, since the others are out of scope.

**2.0.0 is correct** — the plugin name, the invocation path, and the output
surface all change.

Post-merge the user must run `/plugin marketplace update` and enable the plugin
under its new name; the old `release-notes` entry disappears.

## 11. File change map

| File | Change |
|---|---|
| `plugins/release-notes/**` | `git mv` → `plugins/tablo-release-notes/**` |
| `.claude-plugin/marketplace.json` | name, source, description, version 2.0.0 |
| `CLAUDE.md` (root) | add plugin to Current Plugins |
| `tablo-release-notes/.claude-plugin/plugin.json` | name, version, description, drop `userConfig` |
| `tablo-release-notes/README.md` | Tablo scope note; remove email/OneDrive |
| `tablo-release-notes/CLAUDE.md` | Tablo scope note; remove email; document §4.1 grammar as canonical |
| `skills/generate-release-notes/SKILL.md` | description, `argument-hint` showing a prerelease example |
| `skills/generate-release-notes/workflow.md` | W1 grammar + parse; W3 metadata; W4 pass `version_line`; W5 pass `range_mode`; W6 delta filter + guard; W8 titles; **delete W9**; W10 summary; error-recovery list |
| `skills/release-notes-config/SKILL.md` | remove `drop_folder_root`, `email_recipients_note`; add optional `tag_suffix`, `fix_version_override` |
| `agents/rn-jira-collector.md` | `version_line` input, resolution + hard stop, `resolved_fix_version` output |
| `agents/rn-scm-collector.md` | C1 candidate matching, suffix tolerance, Python comparator baseline, new inputs (`line`, `phase`, `phase_index`, `range_mode`, `tag_suffix`), new shard fields (`baseline_ref`, `release_ref`, `effective_range_mode`) |

## 12. Verification

The repository has no test framework, so verification is a scripted dry run
against real data plus a live end-to-end run.

1. **Grammar table** — a scratchpad Python script asserts the §4.1 parse and the
   §4.2 mode/baseline for every row of the §4.2 table; accepts `v2.2-alpha.1`
   as equivalent to `2.2-alpha.1`; and rejects
   `2`, `2.2.3.4`, `2.2-gamma.1`, `2.2-alpha.x`, `2.2-alpha.`, `""`.
2. **Comparator against real tags** — run the §5.3 comparator over
   `tablo-android`'s 369 tags and `tablo-apple`'s tags, asserting:
   - `2.2-alpha.1` → baseline `v2.1.9`
   - `2.2-alpha.2` → baseline `v2.2-alpha.1`
   - `2.2-beta.1` → baseline `v2.1.9`
   - `2.2` → baseline `v2.1.9`
   - `2.2.1-alpha.1` → baseline `v2.2`
   - `2.4.0-final` in `tablo-apple` → release tag `v2.4.0-release`
   These are the exact cases §1c gets wrong today.
3. **Live run** — `/tablo-release-notes:generate-release-notes 2.2-alpha.1`
   against `tablo-android`, confirming: W1 accepts the argument, the collector
   resolves `2.2 - BETA - Airship Push + VSI`, the range is
   `v2.1.9..v2.2-alpha.1`, Confluence publishes
   `Tablo Android 2.2-alpha.1 Release Notes`, and no email path is exercised.
4. **Delta run** — repeat with `2.2-alpha.2`, confirming delta mode, a
   `v2.2-alpha.1..v2.2-alpha.2` range, and that tickets outside the range show
   in the audit table with the §7 reason rather than vanishing.

## 13. Risks

| Risk | Mitigation |
|---|---|
| Fix-version prefix matching is ambiguous for a future name (e.g. lines `2.2` and `2.2.1` both present as Jira versions) | Hard stop listing candidates; `fix_version_override` in config |
| Delta mode silently empties notes when SCM is down | §7 guard: fall back to cumulative and warn loudly |
| Apple's `_ios`/`_tvos` tags make a version ambiguous across platforms | §5.2 preference order + warning; `tag_suffix` config override |
| Unparseable tags (`vizbee-staging-test`) skew ordering | Excluded from ordering, reported in a warning |
| Users' installed plugin breaks on rename | Documented in README; requires `/plugin marketplace update` |
