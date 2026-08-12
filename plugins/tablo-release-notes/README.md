# tablo-release-notes

## Overview

The `tablo-release-notes` plugin generates release notes for Tablo client-app builds from Jira fix-versions and GitLab/git history. It drafts customer-facing notes and an internal companion doc, then publishes both to Confluence with smart-merge.

> **Scope:** This plugin is specific to **Tablo client applications** (Android,
> Apple, Roku). It assumes Tablo's Jira projects, Tablo's git tag conventions
> (including the `fast/release/` tag namespace on `tablo-android`), and the
> Scripps Atlassian site. It is not a general-purpose release-notes tool.

## Prerequisites

- **Atlassian MCP connected and authenticated** — the `claude.ai Atlassian` server requires a one-time OAuth flow. Run `/mcp` in Claude Code to connect. If the MCP server is not connected, the skill will stop with instructions.
- **`glab` CLI installed and authenticated** — run `glab auth status` to confirm you are logged in to GitLab.
- **`git` available** — standard git CLI must be on your `PATH`.
- **A Confluence space with a manually-created root "Release Notes" page** — the space key and page title are configured in `.release-notes.yml`.
- **A `.release-notes.yml` config file** in the target product repo — create it by running `/release-notes-config` on first use.

## Usage

1. **Bootstrap the config** (first time only, or when platforms change):
   ```
   /release-notes-config
   ```
   This walks you through setting up `.release-notes.yml` in the current product repo.

2. **Generate release notes** for a specific build:
   ```
   /generate-release-notes 2.2-alpha.1
   ```
   The skill collects Jira tickets and GitLab MRs/commits for the build, drafts notes, and publishes to Confluence.

## Build versions

The version argument is a release line with an optional prerelease qualifier:

| Argument | Meaning |
|---|---|
| `2.2`, `2.2.1` | Public release |
| `2.2-final`, `2.2-release` | Public release (both are aliases for the same thing) |
| `2.2-alpha.1`, `2.2-beta.2`, `2.2-rc.3` | Prerelease build |

A leading `v` is accepted and ignored, so `v2.2-alpha.1` works.

**The first build of a phase is cumulative; later builds in that phase are deltas.** `2.2-alpha.1` and `2.2-beta.1` each report everything in the 2.2 line, because each opens a new test cycle. `2.2-alpha.2` reports only what changed since `2.2-alpha.1`. Tickets excluded by a delta are never dropped silently — they appear in the companion's ticket-audit table with the reason.

Jira fix versions track public release lines only, never prerelease builds. The plugin resolves the line to the real fix-version name for you: `2.2`, `2.2-alpha.1`, and `2.2-final` all resolve to a Jira version named something like `2.2 - BETA - Airship Push + VSI`.

## `.release-notes.yml` Schema

Place this file in the root of your product repo (one per product, committed to source control):

```yaml
product_name: Tablo
platforms:
  - name: Android
    repo_path: ~/Documents/newt/git/tablo-android
    jira_project: TBAD
    tag_prefix: fast/release/
  - name: Apple
    repo_path: ~/Documents/newt/git/tablo-apple
    jira_project: TBAP
confluence:
  space_key: REL
  root_page_title: "Release Notes"
release_date_source: jira
```

Required per platform: `name`, `repo_path`, `jira_project`. Optional per platform:

- `tag_prefix` — tag namespace holding the platform's **current** release line, with its trailing slash. Only tags under it are considered. **`tablo-android` requires `fast/release/`**: its unprefixed `v2.x` tags are a legacy codebase and must never be used for a commit range. Leave blank to consider only non-namespaced tags.
- `tag_suffix` — platform suffix on tags, e.g. `_ios`. Only needed when one repo tags several platforms at the same version.
- `fix_version_override` — exact Jira fix-version name to use verbatim, skipping line-prefix discovery.

## Confluence Page Hierarchy

The skill builds and maintains the following page structure under the configured root page. Pages are created automatically if missing; the root page must be created manually before first use.

```
[root_page_title]               <- human-created
└── {product_name}              <- created by skill if missing
    └── {Platform} {Version}    <- created by skill
        └── {Platform} {Version} Release Notes    <- parent page
            ├── Release Notes   <- child: customer-facing notes
            └── Companion       <- child: internal detail + engineering notes + ticket audit
```

Public builds use the bare line in page titles, so `2.2-final` publishes as `Tablo Android 2.2 Release Notes`. Prerelease builds keep their qualifier: `Tablo Android 2.2-alpha.1 Release Notes`. Each build gets its own page.

## Atlassian Auth Note

If the `claude.ai Atlassian` MCP server is not connected when you run `/generate-release-notes`, the skill will stop and display instructions for connecting it. You must complete the OAuth flow (run `/mcp` in Claude Code) before the skill can query Jira or Confluence. Authentication persists across sessions once established.

## Upgrading from `release-notes` v1

This plugin was renamed from `release-notes` in v2.0.0, so the installed copy needs refreshing: run `/plugin marketplace update`, then enable `tablo-release-notes`. Skills are now invoked as `/tablo-release-notes:generate-release-notes`.

The email output was removed in v2.0.0 — Confluence is the only publish target. The `drop_folder_root` and `email_recipients_note` config keys are no longer read; leaving them in an existing `.release-notes.yml` is harmless.

## Contributing

Issues and PRs for this plugin are tracked in Jira project **ELI** (`ewscripps.atlassian.net/jira/software/projects/ELI`). The plugin is published to the `stg-marketplace` at `gitlab.com/scripps/public/marketplace`.
