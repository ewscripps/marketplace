# release-notes

## Overview

The `release-notes` plugin automates release-note generation from Jira fix-versions and GitLab/git history. It drafts customer-facing notes and an internal companion doc, publishes both to Confluence with smart-merge, and drops a formatted `email.html` into a configured OneDrive-synced folder for stakeholder notification via Power Automate.

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

2. **Generate release notes** for a specific version:
   ```
   /generate-release-notes 2.8.0
   ```
   The skill collects Jira tickets and GitLab MRs/commits, drafts notes, publishes to Confluence, and writes the email HTML to your drop folder.

## `.release-notes.yml` Schema

Place this file in the root of your product repo (one per product, committed to source control):

```yaml
product_name: Tablo
platforms:
  - name: Android
    repo_path: ~/Documents/newt/git/tablo-android
    jira_project: TBAD
  - name: Apple
    repo_path: ~/Documents/newt/git/tablo-apple
    jira_project: TBAP
confluence:
  space_key: REL
  root_page_title: "Release Notes"
drop_folder_root: ~/OneDrive/ReleaseNotesOutbox
email_recipients_note: ""
release_date_source: jira
```

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

## Atlassian Auth Note

If the `claude.ai Atlassian` MCP server is not connected when you run `/generate-release-notes`, the skill will stop and display instructions for connecting it. You must complete the OAuth flow (run `/mcp` in Claude Code) before the skill can query Jira or Confluence. Authentication persists across sessions once established.

## Contributing

Issues and PRs for this plugin are tracked in Jira project **ELI** (`ewscripps.atlassian.net/jira/software/projects/ELI`). The plugin is published to the `stg-marketplace` at `gitlab.com/scripps/public/marketplace`.
