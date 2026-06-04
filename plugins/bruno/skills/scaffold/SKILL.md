---
name: scaffold
description: Create a new Bruno collection from scratch or update an existing one — add environments, folders, variables, auth defaults, and global scripts using OpenCollection YAML format
user-invocable: true
argument-hint: '[path/to/collection/ | "new"]'
allowed-tools: Bash(find *), Read, Write, Edit, Glob, AskUserQuestion
---

# Scaffold or Update a Bruno Collection

Create a brand-new Bruno collection with the OpenCollection YAML structure, or extend and update an existing one — adding environments, folders, collection-level variables, auth defaults, and global scripts.

## Step 1: New Collection or Update Existing?

If `$ARGUMENTS` is `"new"`, skip to **Step 2: New Collection**.

Otherwise, search for an existing collection from the current directory (run in parallel):

```
find . -name "opencollection.yml" -not -path "*/node_modules/*" -maxdepth 6
find . -name "bruno.json" -not -path "*/node_modules/*" -maxdepth 6
```

If a collection is found, use AskUserQuestion to ask:

- **Update existing collection** — continue to Step 3
- **Create a new collection** — continue to Step 2

If no collection is found, go directly to Step 2.

---

## Step 2: New Collection

Ask the following via AskUserQuestion (gather separately where appropriate):

**Collection name** (free-text):
_"What's the collection name? (e.g., Payments API, Internal Admin)"_

**Base URL** (free-text):
_"What's the base URL for this API? (e.g., `https://api.example.com/v1`) — you can use a variable like `{{base_url}}`"_

**Default authentication** (single-select):
- None
- Bearer token — prompt for the token variable name (default: `{{token}}`)
- Basic — prompt for username/password variable names
- API Key — prompt for key name, value variable, and placement (header or query)
- OAuth 2.0 — prompt for grant type, token URL, client ID/secret variable names

**Root directory** (free-text):
_"Where should the collection be created? (default: `./<collection-slug>/`)"_

### Create the directory structure

Slugify the collection name (lowercase, spaces to hyphens). Create:

```
<collection-slug>/
├── opencollection.yml
├── environments/
│   ├── local.yml
│   ├── staging.yml
│   └── production.yml
```

### Write `opencollection.yml`

```yaml
info:
  name: "<Collection Name>"
  description: ""
  version: "1.0.0"

vars:
  base_url: "https://api.example.com"

auth:
  mode: <mode>
  bearer:
    token: "{{token}}"

headers:
  - name: Content-Type
    value: application/json
    enabled: true

script:
  req: |
    // Global pre-request script
    // Runs before every request in the collection
  res: |
    // Global post-response script
    // Runs after every request in the collection
```

Adjust the `auth` block to match the selected mode. Omit empty auth sections.

### Write starter environment files

**`environments/local.yml`:**
```yaml
vars:
  base_url: "http://localhost:3000"
  token: ""
```

**`environments/staging.yml`:**
```yaml
vars:
  base_url: "https://staging.api.example.com"
  token: ""
```

**`environments/production.yml`:**
```yaml
vars:
  base_url: "https://api.example.com"
  token: ""
```

Substitute the user's base URL for `https://api.example.com` in all three. Adjust variable names to match the selected auth mode.

### Offer to create a starter folder

Ask: _"Add an initial request folder? (e.g., `auth/`, `users/`) — or skip to create just the collection structure."_

If yes, ask for the folder name and create:
```
<collection-slug>/<folder-name>/
├── folder.yml
```

**`folder.yml`:**
```yaml
meta:
  name: "<Folder Name>"
  seq: 1

auth:
  mode: inherit
```

After writing all files, summarize what was created:

```
Created: <collection-slug>/
  opencollection.yml
  environments/local.yml
  environments/staging.yml
  environments/production.yml
  [<folder-name>/folder.yml]
```

Offer to run the `/new-request` skill to add the first request.

---

## Step 3: Update Existing Collection

Read `opencollection.yml` (or `collection.bru` for legacy) to understand the current collection configuration.

Use AskUserQuestion to ask what to update (multi-select):

- **Add a new environment**
- **Add a new folder**
- **Add or update a collection variable**
- **Change the default auth**
- **Add or update a global pre-request script**
- **Add or update a global post-response script**
- **Update collection metadata** (name, description, version)

Handle each selected option:

---

### Add a New Environment

Ask for:
- **Environment name** (free-text, e.g., `qa`, `production`)
- **Base URL for this environment** (free-text)
- **Additional variables** — offer to copy the variable keys from an existing environment and let the user fill in new values

Create `environments/<name>.yml`:

```yaml
vars:
  base_url: "<user-supplied URL>"
  token: ""
  # ... additional vars copied from existing env
```

---

### Add a New Folder

Ask for:
- **Folder name** (free-text)
- **Folder auth** (single-select): Inherit from collection · Override with specific mode
- **Folder sequence number** — default to `(existing folder count + 1)`

Create `<folder-name>/folder.yml`:

```yaml
meta:
  name: "<Folder Name>"
  seq: <N>

auth:
  mode: inherit
```

Adjust auth block if the user chose to override.

---

### Add or Update a Collection Variable

Read the current `vars` block from `opencollection.yml`.

Ask:
- **Variable name** (free-text)
- **Default value** (free-text, can be empty for secrets)

Update the `vars` block in `opencollection.yml` using Edit. Preserve all existing variables.

---

### Change the Default Auth

Ask for the new auth mode (same options as Step 2) and update the `auth` block in `opencollection.yml`.

Show the user the current auth config before overwriting it.

---

### Add or Update a Global Script

Show the existing script content (if any).

Ask the user to provide the new script body (free-text, JavaScript). Replace the `script.req` or `script.res` block in `opencollection.yml` accordingly.

---

### Update Collection Metadata

Ask for new name, description, and/or version. Update the `info` block in `opencollection.yml`.

---

After all updates, summarize every file that was created or modified.
