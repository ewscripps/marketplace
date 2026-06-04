---
name: scaffold
description: Create a new Bruno collection from scratch or update an existing one using the OpenCollection YAML v1.0.0 schema — correct opencollection.yml, environment, and folder file structure.
user-invocable: true
argument-hint: '[path/to/collection/ | "new"]'
allowed-tools: Bash(find *), Read, Write, Edit, Glob, AskUserQuestion
---

# Scaffold or Update a Bruno Collection

Create or update a Bruno collection conforming to the OpenCollection YAML v1.0.0 spec
(`https://schema.opencollection.com/opencollection/v1.0.0.json`).

All generated YAML uses the correct spec field names — `info`, `request`, `runtime`, `config` — not the legacy `.bru` block names.

## Step 1: New or Existing?

If `$ARGUMENTS` is `"new"`, skip to **Step 2**.

Otherwise, search from the current directory (run in parallel):

```
find . -name "opencollection.yml" -not -path "*/node_modules/*" -maxdepth 6
find . -name "bruno.json" -not -path "*/node_modules/*" -maxdepth 6
```

If a collection is found, use AskUserQuestion:

- **Update existing collection** — continue to Step 3
- **Create a new collection** — continue to Step 2

If none found, go directly to Step 2.

---

## Step 2: New Collection

Ask via AskUserQuestion:

**Collection name** (free-text): _"Collection name? (e.g., Payments API)"_

**Base URL** (free-text): _"Base URL? (e.g., `https://api.example.com/v1` — can use `{{base_url}}`)"_

**Default auth** (single-select): None · Bearer · Basic · API Key · OAuth 2.0

If Bearer: prompt for the token variable name (default: `{{token}}`).
If Basic: prompt for username/password variable names.
If API Key: prompt for key name, value variable, and placement (`header` or `query`).
If OAuth 2.0: prompt for flow (`client_credentials` or `authorization_code`) and token/auth URLs.

**Root directory** (free-text): _"Where to create? (default: `./<collection-slug>/`)"_

### Create the directory structure

```
<collection-slug>/
├── opencollection.yml
└── environments/
    ├── local.yml
    ├── staging.yml
    └── production.yml
```

### Write `opencollection.yml`

The root collection file uses these top-level keys from the spec: `opencollection` (the spec version string), `info`, `config` (for environments), and `request` (for collection-level defaults shared by all requests).

```yaml
opencollection: "1.0.0"

info:
  name: "<Collection Name>"
  summary: ""
  version: "1.0.0"

request:
  auth:
    type: bearer
    token: "{{token}}"
  headers:
    - name: Content-Type
      value: application/json
  variables:
    - name: base_url
      value: "<user-supplied base URL>"
```

**Auth shapes for `request.auth` (same rules as request files):**

```yaml
# Bearer
auth:
  type: bearer
  token: "{{token}}"

# Basic
auth:
  type: basic
  username: "{{username}}"
  password: "{{password}}"

# API Key
auth:
  type: apikey
  key: X-API-Key
  value: "{{apiKey}}"
  placement: header        # enum: header | query

# OAuth2 client credentials
auth:
  type: oauth2
  flow: client_credentials
  accessTokenUrl: "{{token_url}}"
  credentials:
    clientId: "{{client_id}}"
    clientSecret: "{{client_secret}}"
    placement: basic_auth_header
  scope: ""

# None — omit auth block entirely
```

Omit any block the user did not configure. Do NOT include an empty `auth: {}` or `scripts: []`.

### Write environment files

Environment files are `Environment` objects from the spec. Each requires a `name` field. Variables are an **array** of `{name, value}` objects — NOT a flat key-value map. Secret variables use `{name, secret: true}` and have no `value`.

**`environments/local.yml`:**
```yaml
name: local
variables:
  - name: base_url
    value: "http://localhost:3000"
  - name: token
    secret: true
```

**`environments/staging.yml`:**
```yaml
name: staging
variables:
  - name: base_url
    value: "https://staging.api.example.com"
  - name: token
    secret: true
```

**`environments/production.yml`:**
```yaml
name: production
variables:
  - name: base_url
    value: "<user-supplied base URL>"
  - name: token
    secret: true
```

Substitute the user's base URL. Adjust variable names to match the selected auth mode (e.g., use `username`/`password` instead of `token` for Basic auth). Mark sensitive values as `secret: true` with no `value` field.

If the user chose a `.env` file for secrets, add `dotEnvFilePath: ".env"` to the environment(s) where it applies.

### Offer to create a starter folder

Ask: _"Add an initial request folder? (e.g., `auth/`, `users/`)"_

If yes, ask for the folder name and write a `folder.yml`:

```yaml
info:
  name: "<Folder Name>"
  type: folder
  seq: 1

request:
  auth: inherit
```

`auth: inherit` is the string `"inherit"` — not an object. It tells Bruno to use the parent's auth.

### Summarize what was created

```
Created: <collection-slug>/
  opencollection.yml
  environments/local.yml
  environments/staging.yml
  environments/production.yml
  [<folder-name>/folder.yml]
```

Offer to invoke the `new-request` skill to add the first request.

---

## Step 3: Update Existing Collection

Read `opencollection.yml` to understand the current state. Use AskUserQuestion (multi-select) to ask what to update:

- **Add a new environment**
- **Add a new folder**
- **Add or update a collection variable**
- **Change the default auth**
- **Add or update a global script**
- **Update collection metadata** (name, summary, version)

---

### Add a New Environment

Ask for:
- **Name** (free-text)
- **Base URL** (free-text)
- **Copy variable keys from existing env?** (offer to mirror the variable names from an existing env file)
- **Load from `.env` file?** — if yes, ask for the file path

Write `environments/<name>.yml` as an `Environment` object:

```yaml
name: <env-name>
variables:
  - name: base_url
    value: "<URL>"
  - name: token
    secret: true
  # ... additional vars with names mirrored from existing env
```

---

### Add a New Folder

Ask for:
- **Folder name** (free-text)
- **Auth**: Inherit · Override (same auth type options as Step 2)
- **Sequence number** — default to `(existing folder count + 1)`

Write `<folder-name>/folder.yml`:

```yaml
info:
  name: "<Folder Name>"
  type: folder
  seq: <N>

request:
  auth: inherit
```

If overriding auth, write the appropriate auth object under `request.auth` instead of `inherit`.

---

### Add or Update a Collection Variable

Read the current `request.variables` array from `opencollection.yml`.

Ask:
- **Variable name** (free-text)
- **Value** (free-text — leave empty for secrets)
- **Secret?** — if yes, write `{name, secret: true}` with no `value`

Use Edit to update the `request.variables` array in `opencollection.yml`. Preserve existing entries.

Variables are an **array**, not a flat map:

```yaml
request:
  variables:
    - name: base_url
      value: "https://api.example.com"
    - name: api_version
      value: "v1"
    - name: api_secret
      secret: true
```

---

### Change the Default Auth

Show the current `request.auth` block. Ask for the new auth mode (same options as Step 2). Update `request.auth` in `opencollection.yml` with the correct flat-type object.

---

### Add or Update a Global Script

Global scripts live in `request.scripts` — an **array** of `{type, code}` objects. Valid `type` values: `before-request`, `after-response`, `tests`, `hooks`.

Show the existing scripts array (if any). Ask the user which type to add/update and for the script body. Update the `request.scripts` array in `opencollection.yml`:

```yaml
request:
  scripts:
    - type: before-request
      code: |
        // Runs before every request in the collection
        bru.setVar("requestTime", new Date().toISOString());
    - type: after-response
      code: |
        // Runs after every request in the collection
        if (res.getStatus() === 401) {
          console.log("Auth expired");
        }
```

---

### Update Collection Metadata

Ask for new name, summary, and/or version. Update the `info` block in `opencollection.yml`.

---

After all updates, summarize every file that was created or modified.
