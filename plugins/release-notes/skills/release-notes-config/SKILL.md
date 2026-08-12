---
name: release-notes-config
description: Bootstrap or update the .release-notes.yml config file for the current product repo. Run this once before the first /release-notes invocation to set up Jira project keys, repo paths, platform names, Confluence space, and the email drop folder.
user-invocable: true
argument-hint: ''
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

# Config Wizard

Interactive wizard that creates or updates `.release-notes.yml` in the current directory. Run once per product repo before the first `/release-notes` invocation. The orchestrator also invokes this skill with a field name argument when a required field is missing at runtime.

The user's request is: $ARGUMENTS

## Guardrails

- **Never modify `release_date_source`.** Always write it as `jira` on creation. The orchestrator sets it to `manual` if a fallback fires; this skill never touches it in an existing file.
- **Never ask for fields that already have values in the existing config.** Only ask for missing or explicitly requested fields.
- **Platform git-repo validation is advisory only.** Warn the user if the path is not a valid git repo, but save whatever they typed and continue. The repo may not be cloned yet.
- **Never expand `~` in stored paths.** Store paths exactly as the user typed them so the file stays human-readable.

---

## Step 0 — Locate the config

Run:

```bash
CONFIG_PATH="$(pwd)/.release-notes.yml"
```

If the file exists, read it with the Read tool. Parse it mentally to determine which required fields are already present. If the file does not exist, treat all required fields as missing.

**Required fields:** `product_name`, `platforms` (at least one entry with `name`, `repo_path`, and `jira_project`), `confluence.space_key`, `confluence.root_page_title`, `drop_folder_root`.

**Optional fields:** `email_recipients_note` (ask but allow empty).

**Auto-set fields:** `release_date_source` — never ask the user; always write as `jira`.

---

## Step 1 — Handle `$ARGUMENTS`

Evaluate `$ARGUMENTS`:

- **Empty or not provided:** proceed to Step 2.
- **`--show`:** display the formatted summary (see Step 5 format) and stop. Do not ask anything.
- **A recognized field name** (`product_name`, `platforms`, `platform`, `confluence.space_key`, `confluence.root_page_title`, `drop_folder_root`, `email_recipients_note`): skip to Step 3, ask only for that specific field, update the file, save, display the summary, and stop.
- **Unrecognized argument:** print `Note: unrecognized argument '$ARGUMENTS' — running full wizard.` and proceed to Step 2.

---

## Step 2 — Check completeness

Determine which required fields are missing from the existing config (or all of them if the file doesn't exist).

**If all required fields are present**, display the formatted summary (Step 5 format) and output:

> Your `.release-notes.yml` is complete. Run `/release-notes-config <field>` to update a specific field, or run `/generate-release-notes <version>` to generate release notes.

Then stop.

**If any required fields are missing**, proceed to Step 3, asking only for those missing fields (in the order listed below).

---

## Step 3 — Ask for missing fields (one at a time)

Use `AskUserQuestion` for each missing required field. Ask them in this order. Skip any field that already has a value in the existing config.

### 3.1 `product_name`

Inspect the current directory name for a hint. If `$(basename $(pwd))` looks like a product name (e.g. `tablo`, `tablo-android`, `core-news`), derive a suggested display name from it (capitalise, strip hyphens/underscores). Ask:

> What is the product name? This is used in headers, email subject lines, and Confluence page titles. (e.g. 'Tablo', 'Core News')

Suggested option: the inferred name if one was derived, otherwise freetext.

### 3.2 `platforms`

Ask:

> How many platforms does this release cover?

Options: `1`, `2`, `3`, `4+`

Then for each platform (platforms 1 through N; for `4+`, keep asking until the user says they are done — ask "Add another platform? (yes/no)" after each entry):

**Platform N name:**
> Platform N name? (e.g. 'Android', 'Apple', 'Roku', 'React Native')

**Platform N repo path:**
> Path to the Platform N git repo? (absolute or ~/... path, e.g. ~/Documents/newt/git/tablo-android)

After receiving the path, run this validation check in Bash:

```bash
repo_path="<the path the user typed>"
expanded="${repo_path/#\~/$HOME}"
git -C "$expanded" remote get-url origin 2>/dev/null
```

If the command fails or returns empty, warn: `Warning: that path doesn't appear to be a git repo — double-check it. Saving what you typed and continuing.` Do not block on this; continue to the next question.

**Platform N Jira project key:**
> Jira project key for Platform N? (e.g. TBAD, TBAP, TBRK, TBRN)

### 3.3 `confluence.space_key`

Ask:

> What is the Confluence space key where release notes should be published? (NOT the space name — the short key shown in Confluence URLs, e.g. REL, TBLO, PM)

### 3.4 `confluence.root_page_title`

Ask:

> What is the title of the root 'Release Notes' page in that Confluence space? You must create this page manually first. (Default: 'Release Notes')

Default option: `Release Notes`

If the user presses Enter without typing, use `Release Notes`.

### 3.5 `drop_folder_root`

Ask:

> What is the path to your OneDrive-synced email drop folder? The skill will create a per-release subfolder inside it and write email.html there. (e.g. ~/Library/CloudStorage/OneDrive-Nuvyyo/ReleaseNotesOutbox)

### 3.6 `email_recipients_note` (optional)

Ask:

> Optional: list the email recipients here for reference. This is just a note — it is not read or sent by any automation. Press Enter to skip.

If the user presses Enter without typing, store an empty string.

---

## Step 4 — Write the config file

Assemble the complete YAML using Python via Bash heredoc. **Do not use random `echo` calls that might corrupt YAML indentation.**

Use the following template, substituting each collected value. For an existing file being updated, merge the new values with existing ones — preserve any fields already in the file.

```bash
python3 - <<'PYEOF'
import yaml, os, sys

config_path = os.path.join(os.getcwd(), '.release-notes.yml')

# Load existing config if present (to preserve any untouched fields)
existing = {}
if os.path.exists(config_path):
    with open(config_path) as f:
        existing = yaml.safe_load(f) or {}

# Merge collected values (substitute actual values below)
product_name = "<product_name>"
platforms = [
    {"name": "<platform1_name>", "repo_path": "<platform1_repo_path>", "jira_project": "<platform1_project_key>"},
    # additional platform dicts if collected
]
confluence_space_key = "<space_key>"
confluence_root_page_title = "<root_page_title>"
drop_folder_root = "<drop_folder_root>"
email_recipients_note = "<email_recipients_note_or_empty>"

# Build the config dict, preserving release_date_source if already set
config = dict(existing)
config["product_name"] = product_name
config["platforms"] = platforms
config["confluence"] = {
    "space_key": confluence_space_key,
    "root_page_title": confluence_root_page_title,
}
config["drop_folder_root"] = drop_folder_root
config["email_recipients_note"] = email_recipients_note
# Never overwrite release_date_source if already set to something other than 'jira'
if not config.get("release_date_source"):
    config["release_date_source"] = "jira"

with open(config_path, "w") as f:
    yaml.dump(config, f, default_flow_style=False, allow_unicode=True, sort_keys=False)

print(f"Written: {config_path}")
PYEOF
```

**When updating a single field** (argument-mode from Step 1): use the same Python approach, loading the existing file, updating only the targeted key, and writing back. Never blow away the entire file for a single-field update.

**YAML field-update format for single fields via Python:**

- `product_name`: `config["product_name"] = new_value`
- `platforms` / `platform`: replace the entire `platforms` list with newly collected entries
- `confluence.space_key`: `config.setdefault("confluence", {})["space_key"] = new_value`
- `confluence.root_page_title`: `config.setdefault("confluence", {})["root_page_title"] = new_value`
- `drop_folder_root`: `config["drop_folder_root"] = new_value`
- `email_recipients_note`: `config["email_recipients_note"] = new_value`

**Tilde preservation:** if the user typed `~` in a path, `yaml.dump` will quote it correctly. Do not expand `~` before storing.

---

## Step 5 — Confirm and show summary

After writing, display:

```
✓ .release-notes.yml written to <CONFIG_PATH>

Product: <product_name>
Platforms:
  • <name> — <repo_path> (Jira: <jira_project>)
  • <name> — <repo_path> (Jira: <jira_project>)
  ...
Confluence: space <space_key>, root page "<root_page_title>"
Email drop: <drop_folder_root>

Next: run `/generate-release-notes <version>` to generate release notes.
```

If invoked in `--show` mode (Step 1), show the same summary without the "✓ ... written" line and without the "Next:" line.
