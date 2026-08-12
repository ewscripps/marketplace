# tablo-release-notes v2 — Prerelease Versions, Confluence-Only Output, Rename

**Date:** 2026-08-12
**Branch:** `generate-release-notes-plugin-v2`
**Plugin:** `release-notes` v1.0.0 → `tablo-release-notes` v2.0.0

> **Revision 2 (2026-08-12).** Revision 1 claimed no `-final` tag existed and
> that a bare `v2.2` was Android's GA build. Both were wrong: they described
> `tablo-android`'s **legacy** tag line. The current line lives under the
> `fast/release/` tag namespace, where `-final` *is* the GA convention. §1b,
> §1d, §4.3, §5, §12 and §13 are corrected accordingly. Every expectation in
> §12 is now verified against the real tag lists rather than inferred.

---

## 1. Problem

`/generate-release-notes 2.2-alpha.1` fails at Step W1. The validation pattern
`^[0-9]+\.[0-9]+(\.[0-9]+)?$` accepts only plain `major.minor[.patch]`, so every
prerelease build is rejected before any work starts.

Investigating that failure surfaced three further defects that make the plugin
non-functional for its target repos.

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
forbids the spaces needed to pass one verbatim. Jira collection has never
returned tickets for TBAD.

**1b. Tag conventions differ per repo and per line.** Verified:

| Repo | Line | GA convention | Prerelease |
|---|---|---|---|
| `tablo-android` | `fast/release/` (current) | `-final` | `-alpha.N`, `-beta.N`, `-rc.N` |
| `tablo-android` | unprefixed (**legacy**) | bare `v2.1.14` | `-alpha.N`, `-beta.N` |
| `tablo-apple` | unprefixed (main app) | `-release` | `-alpha.N`, `-beta.N` |
| `tablo-apple` | `fast/release/` (FAST) | `-final` | `-alpha.N` |
| `tablo-roku` | unprefixed | `-release` | — |

So `-final` is real — it is the GA convention of Android's current line — and no
single tag pattern serves every platform. Platform suffixes `_ios`, `_tvos`,
`_ENGINE` also appear.

**1c. Git sorts prereleases above their release.** `rn-scm-collector` C1 picks
the baseline with `git tag --sort=-version:refname | grep -v <current> | head -1`.
Verified against `tablo-android`:

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

**1d. Legacy tags contaminate the ordering.** `tablo-android` carries 369 tags,
of which only 55 belong to the current `fast/release/` line. The unprefixed
`v2.x` tags are a legacy codebase and must never be selected. Nothing in the
current design distinguishes them, so a baseline search would happily return a
legacy tag and produce a commit range spanning two unrelated codebases.

## 2. Goals

- `/generate-release-notes <version>` accepts `2.2`, `2.2.1`, `2.2-alpha.1`,
  `2.2-beta.2`, `2.2-rc.3`, `2.2-final`, `2.2-release`.
- Prerelease builds report the correct changes per the phase rule (§4.2).
- Only tags belonging to the configured line are considered (§5.1).
- Jira fix-version lookup resolves against the real, freeform version names.
- The plugin is named for what it is: Tablo client-app release notes.

## 3. Non-goals

- Email / `email.html` / OneDrive / Power Automate output — **removed** (§9).
  Confluence is the only publish target.
- Retagging any product repo.
- Generating notes for the legacy Android line. It is excluded by
  configuration, not supported.
- Supporting non-Tablo products.

## 4. Version grammar and range semantics

### 4.1 Grammar

```
^([0-9]+\.[0-9]+(\.[0-9]+)?)(-(alpha|beta|rc|final|release)(\.([0-9]+))?)?$
```

| Field | Meaning |
|---|---|
| `line` | `major.minor[.patch]` — the public release line, e.g. `2.2` |
| `phase` | `alpha` \| `beta` \| `rc` \| `public` |
| `phase_index` | integer, default `1` when the suffix omits `.N` |
| `is_public` | true for a bare line, `-final`, or `-release` |

`-final` and `-release` both normalize to `phase = public`. `rc` is included
because `fast/release/v2.1-rc.7`-style tags exist.

Input is normalized before matching: surrounding whitespace is stripped and a
single leading `v` removed, so `v2.2-alpha.1` is accepted. Tags carry the `v`,
so users will type it.

`line` compares as an integer tuple, missing patch treated as `0`:
`2.2` → `(2,2,0)`, `2.1.9` → `(2,1,9)`.

### 4.2 Range mode

**The first build of a phase is cumulative; later builds in that phase are
deltas.**

```
range_mode = cumulative  if is_public or phase_index == 1
             delta       if phase_index >= 2
```

Rationale: alpha.1 and beta.1 each open a new test cycle, so their audience
needs the whole line's content; later builds within a cycle need only what
changed since the last build handed to that audience.

### 4.3 Baseline definitions

- **delta** — the highest in-scope tag with the same `line` and same `phase`
  whose `phase_index` is strictly lower. "Highest below" rather than
  "index − 1" is load-bearing: `fast/release/v2.1` has `beta.2`/`beta.3` with no
  `beta.1`, and `rc.1` then `rc.4`–`rc.7`. Index − 1 breaks on every one.
- **cumulative** — the highest in-scope **public** tag whose `line` is strictly
  lower.
- Ties break on `(phase_index, suffix preference, tag name)` where suffix
  preference favours an unsuffixed tag, then one matching the platform name.
  Deterministic, and any tie emits a warning naming every candidate.
- If neither yields a tag, fall back to the C1 date window and warn.

Verified baselines in `tablo-android` with `tag_prefix: fast/release/`:

| Version | Baseline | Mode |
|---|---|---|
| `2.2-alpha.1` | `fast/release/v2.1-final` | cumulative |
| `2.1-final` | `fast/release/v2.0.5-final` | cumulative |
| `2.0.1-final` | `fast/release/v2.0-final` | cumulative |
| `2.1-rc.4` | `fast/release/v2.1-rc.1` | delta (gap) |
| `2.1-beta.3` | `fast/release/v2.1-beta.2` | delta |
| `2.0-alpha.3` | `fast/release/v2.0-alpha.2` | delta |

## 5. Tag resolution (`rn-scm-collector`, C1)

### 5.1 Scoping — the legacy fix

New optional per-platform `tag_prefix` in `.release-notes.yml`. A tag is
in scope only when it starts with `tag_prefix` and the remainder contains no
`/`. With `tag_prefix` unset, only non-namespaced tags qualify.

Consequences, both required:

- `tag_prefix: fast/release/` on Android excludes all 314 legacy and `fast/*`
  tags; only the 55 current-line tags rank.
- An unset prefix excludes every namespaced tag, so `fast/release/*` can never
  contaminate `tablo-apple`'s main-app ordering.

**Discovery warning.** When `tag_prefix` is unset and excluded namespaced tags
would have parsed as releases, warn:

```
No tag_prefix set, so 150 namespaced tag(s) were excluded. Namespaces with
parseable release tags: fast/ (82), fast/release/ (67). Set tag_prefix in
.release-notes.yml if one of these is the current line.
```

This is the warning that would have caught defect 1d without a human noticing.

`tablo-android/.release-notes.yml` must be updated to
`tag_prefix: fast/release/` as part of this work.

### 5.2 Release tag candidates

Ordered, `tag_prefix` prepended to each; first match wins.

- `is_public` → `v<line>`, `<line>`, `v<line>-release`, `v<line>-final`
- prerelease → `v<line>-<phase>.<n>`, `<line>-<phase>.<n>`

This makes `-final` an alias rather than a literal: `2.1-final` and a bare `2.1`
both resolve to Android's `fast/release/v2.1-final`, and `2.4.0-final` resolves
to Apple's `v2.4.0-release`, with no repo changing.

### 5.3 Platform suffix tolerance

If no exact candidate matches, retry allowing a trailing `_<alnum>` segment,
covering `_ios`, `_tvos`, `_ENGINE`. On multiple matches, prefer the unsuffixed
tag, then one matching the platform name, else the lexical maximum — always
with a warning naming every match. Optional per-platform `tag_suffix` is tried
first when set.

### 5.4 Ordering implementation

`--sort=-version:refname` is removed from baseline selection (§1c). Replace it
with the inline Python comparator, sorting on
`(line_tuple, phase_rank, phase_index)` with
`phase_rank = alpha:0, beta:1, rc:2, public:3`.

In-scope tags that do not parse are excluded from ordering and reported in a
warning listing up to eight names — 12 exist under `fast/release/`, including
`v2.2-975f7f5663`, `v1.8-alpha.3-bluetooth`, `v1.7-exnets`,
`v2.1-edge-vsi-validation`. Out-of-scope tags are counted only, never listed
individually; listing 302 of them every run would bury the signal.

## 6. Jira fix-version resolution (`rn-jira-collector`)

Resolution moves into the collector, which already holds the Jira tools.

- New input `version_line` — the §4.1 `line` (e.g. `2.2`), never the full build
  string. Jira tracks public release lines only.
- The collector discovers the project's fix-version names and selects those
  whose name starts with `<version_line>`.
- Exactly one match → proceed, using that name in its ticket JQL.
- Zero or 2+ matches → **hard stop**, receipt `status: "failed"`, reason listing
  every candidate name found.
- New receipt/shard field `resolved_fix_version` carries the chosen name back
  for the document header and the final summary.

Optional per-platform `fix_version_override` bypasses discovery.

`2.2`, `2.2-alpha.1`, and `2.2-final` all resolve to
`2.2 - BETA - Airship Push + VSI`, which is intended.

## 7. Delta filtering (W6) and its safety guard

`cumulative` is unchanged: every fix-version ticket is a candidate.

For `delta`, a fix-version ticket reaches `release-notes.md` only if it has a
linked MR or commit inside the build range in **any** platform's SCM shard. On a
multi-platform release the `[Platform: …]` tag lists only platforms whose shard
placed it in range, so a ticket that landed in Android's alpha.2 but not
Apple's is included, marked Android-only. Tickets out of range on every platform
are **not dropped silently** — they appear in the companion's Ticket Audit with
`Included in Notes? = No` and reason
`Not in this build's range (<baseline_ref>..<release_ref>)`.

**Safety guard.** SCM failure is a soft warning today (W5). Under delta mode a
failed or empty shard would filter every ticket out and yield empty notes that
look legitimately empty. So if `range_mode == delta` and a platform's shard is
`failed` or empty, that platform falls back to `cumulative` and the run reports:

```
Warning: SCM data for {platform} was unavailable — cannot compute the delta for
{version}. Falling back to cumulative notes for the whole {line} line. Verify
the range manually.
```

The collector reports `effective_range_mode` so the orchestrator can detect a
degrade it did not request.

## 8. Confluence titles

One page per build. Public builds normalize to the bare line; prereleases keep
the suffix:

| Version argument | Release page title |
|---|---|
| `2.2`, `2.2-final` | `Tablo Android 2.2 Release Notes` |
| `2.2-alpha.1` | `Tablo Android 2.2-alpha.1 Release Notes` |

Child titles follow the same normalized string (`… — Customer Notes`,
`… — Companion`). `-final` never appears in a page title.

Header block gains two lines. Rendered examples, one per build kind:

```
**Build Type:** Prerelease (alpha.1)
**Change Range:** Cumulative since fast/release/v2.1-final
```

```
**Build Type:** Public Release
**Change Range:** Cumulative since fast/release/v2.1-final
```

```
**Build Type:** Prerelease (alpha.2)
**Change Range:** Delta since fast/release/v2.2-alpha.1
```

## 9. Email removal

Delete, do not deprecate:

- Step W9 of `workflow.md` in full.
- The email line in W10's summary, and `drop_folder_root` from W1's optional
  read.
- `drop_folder_root` and `email_recipients_note` from the `release-notes-config`
  wizard and schema.
- `userConfig.drop_folder_root` from `plugin.json`.
- Every email / OneDrive / Power Automate mention in the plugin `README.md`,
  plugin `CLAUDE.md`, `SKILL.md` descriptions, and the `marketplace.json`
  description.

`tablo-android/.release-notes.yml` contains both dropped keys; they become
unread, so no migration is needed and no existing config breaks.

## 10. Rename and versioning

- `git mv plugins/release-notes plugins/tablo-release-notes`.
- `plugin.json` — `name: tablo-release-notes`, `version: 2.0.0`, Tablo-scoped
  description, `userConfig` removed.
- `.claude-plugin/marketplace.json` — entry `name`, `source`, `description`,
  `version: 2.0.0`.
- Skill directory names unchanged, so invocation becomes
  `/tablo-release-notes:generate-release-notes`.
- Agent names and the `.release-notes.yml` filename unchanged.
- Plugin `README.md` and `CLAUDE.md` gain a scope note: built for Tablo client
  applications (Android, Apple, Roku), assumes Tablo Jira projects and Tablo tag
  conventions, hardcoded Scripps Atlassian cloud ID.
- Root `CLAUDE.md` "Current Plugins" gains a `tablo-release-notes` entry. That
  list also omits `edm`, `bruno`, and `wave-to-jpd`; those stay out of scope.

**2.0.0 is correct** — name, invocation path, and output surface all change.
Post-merge the user runs `/plugin marketplace update` and re-enables under the
new name.

## 11. File change map

| File | Change |
|---|---|
| `plugins/release-notes/**` | `git mv` → `plugins/tablo-release-notes/**` |
| `.claude-plugin/marketplace.json` | name, source, description, version 2.0.0 |
| `CLAUDE.md` (root) | add plugin to Current Plugins |
| `tablo-release-notes/.claude-plugin/plugin.json` | name, version, description, drop `userConfig` |
| `tablo-release-notes/README.md` | Tablo scope note; remove email/OneDrive |
| `tablo-release-notes/CLAUDE.md` | scope note; remove email; canonical §4.1 grammar + §4.3 baseline rules |
| `skills/generate-release-notes/SKILL.md` | description, `argument-hint` with a prerelease example |
| `skills/generate-release-notes/workflow.md` | W1 grammar + parse; W3 metadata; W4 `version_line`; W5 `range_mode` + `tag_prefix`; W6 delta filter + guard; W8 titles; **delete W9**; W10 summary; error-recovery list |
| `skills/release-notes-config/SKILL.md` | remove `drop_folder_root`, `email_recipients_note`; add `tag_prefix`, `tag_suffix`, `fix_version_override` |
| `agents/rn-jira-collector.md` | `version_line` input, resolution + hard stop, `resolved_fix_version` |
| `agents/rn-scm-collector.md` | C1 scoping, candidates, suffix tolerance, comparator baseline; new inputs (`line`, `phase`, `phase_index`, `range_mode`, `tag_prefix`, `tag_suffix`); new shard fields (`baseline_ref`, `release_ref`, `effective_range_mode`, tag stats) |
| `~/Documents/newt/git/tablo-android/.release-notes.yml` | add `tag_prefix: fast/release/` (outside this repo) |

## 12. Verification

No test framework exists, so verification is a committed harness plus live runs.

**Harness** — `plugins/tablo-release-notes/dev/verify_version_rules.py` extracts
the canonical Python block from the shipped markdown by its
`# --- rn:version (canonical) ---` marker and `exec`s it, so the test exercises
the artifact that actually ships rather than a copy that can drift. Tag
fixtures are committed under `dev/fixtures/tags-{android,apple,roku}.txt`
(643 real tags), making runs deterministic and repo-independent.

All of the following are already proven against the real fixtures:

1. **Grammar** — accepts the §4.1 table plus `v2.2-alpha.1`, `2.2-alpha`,
   `  2.2-BETA.2  `; rejects `2`, `2.2.3.4`, `2.2-gamma.1`, `2.2-alpha.x`,
   `2.2-alpha.`, `2.2-QA.1`, `""`, `2.2 - BETA - Airship Push + VSI`.
2. **Scoping** — `fast/release/v2.2-alpha.1` in scope under that prefix; legacy
   `v2.2-alpha.1` and `fast/v1.0` excluded by it; namespaced tags excluded when
   no prefix is set; junk excluded (`vizbee-staging-test`,
   `v2.0.0-release-hotfix2_ios`, `fast/release/v2.2-975f7f5663`,
   `fast/release/v1.8-alpha.3-bluetooth`, `fast/release/v2.2.0-QA.1`).
3. **Baselines** — every row of the §4.3 table, plus an assertion that the
   Android baseline never starts outside `fast/release/`.
4. **Release tags** — Android `2.2-alpha.1` → `fast/release/v2.2-alpha.1`;
   Android `2.1` → `fast/release/v2.1-final` via the alias; Apple `2.4.0-final`
   → `v2.4.0-release`; Apple FAST `2.1-final` → `fast/release/v2.1-final`; Roku
   `3.0.0-final` → `v3.0.0-release`.
5. **Discovery warning** — fires naming `fast/release/` when Android runs with
   no prefix; silent once the prefix is set.

**Live runs**

6. `/tablo-release-notes:generate-release-notes 2.2-alpha.1` against
   `tablo-android`: W1 accepts, the collector resolves
   `2.2 - BETA - Airship Push + VSI`, the range is
   `fast/release/v2.1-final..fast/release/v2.2-alpha.1`, Confluence publishes
   `Tablo Android 2.2-alpha.1 Release Notes`, and no email path is exercised.
7. A delta run once a second alpha is tagged, confirming delta mode and that
   out-of-range tickets appear in the audit table with the §7 reason rather than
   vanishing.

## 13. Risks

| Risk | Mitigation |
|---|---|
| A future line uses a phase this grammar lacks — `fast/release/v2.2.0-QA.1` already exists on Apple | Excluded and named in the §5.4 unparsed warning. Adding `qa` needs a decided rank, so it is deliberately deferred rather than guessed |
| `_ios`/`_tvos` tie makes Apple's baseline ambiguous — resolves to `v2.3.0-release_tvos` for platform `Apple` | Deterministic + warned; `tag_suffix: _ios` in config is the fix |
| Fix-version prefix matching ambiguous for a future name | Hard stop listing candidates; `fix_version_override` |
| Delta mode silently empties notes when SCM is down | §7 guard: fall back to cumulative and warn |
| Legacy Android tags re-enter if `tag_prefix` is dropped from config | §5.1 discovery warning names `fast/release/` whenever the prefix is unset |
| Users' installed plugin breaks on rename | Documented in README; requires `/plugin marketplace update` |
