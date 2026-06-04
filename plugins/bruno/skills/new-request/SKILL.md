---
name: new-request
description: Scaffold a new request file in a Bruno collection. Defaults to OpenCollection YAML format (.yml) with method, URL, auth, headers, body, and optional scripts.
user-invocable: true
argument-hint: '[path/to/collection/ | folder/name]'
allowed-tools: Bash(find *), Read, Write, Glob, AskUserQuestion
---

# Scaffold a New Bruno Request

Create a new request file in an existing Bruno collection. Defaults to OpenCollection YAML format (`.yml`). Detects the collection format automatically and matches it.

## Step 1: Locate the Collection Root

Check `$ARGUMENTS` — if a path is provided and it contains `opencollection.yml` or `bruno.json`, use it as the collection root.

Otherwise, search from the current directory (run in parallel):

```
find . -name "opencollection.yml" -not -path "*/node_modules/*" -maxdepth 6
find . -name "bruno.json" -not -path "*/node_modules/*" -maxdepth 6
```

Prefer `opencollection.yml` (YAML format). Fall back to `bruno.json` (legacy `.bru` format).

- One result → use it.
- Multiple → use AskUserQuestion to let the user pick.
- None → inform the user no Bruno collection was found and stop.

Note the detected format — it will determine the generated file syntax and extension.

## Step 2: Select a Target Folder

List all existing folders in the collection:

```
find <collection-root> -type d -not -path "*/environments*" -not -path "*/.git*"
```

Use AskUserQuestion to ask where to place the new request:

- Show each folder as an option (path relative to collection root, e.g., `users/`, `orders/reports/`)
- Include **"Collection root"** for top-level placement
- Include **"Create new folder"** — if chosen, ask for the folder name and create the directory (and an empty `folder.yml` for YAML collections)

## Step 3: Gather Request Details

Ask via AskUserQuestion in sequence:

**Request name** (free-text):
_"What's the request name? (e.g., Get User, Create Order)"_

**HTTP method** (single-select):
GET · POST · PUT · PATCH · DELETE · HEAD · OPTIONS

**URL** (free-text):
_"What's the request URL? Use `{{variable}}` for dynamic segments. (e.g., `{{base_url}}/users/{{userId}}`)"_

## Step 4: Configure Authentication

Read `opencollection.yml` (or `collection.bru`) to detect the collection-level auth default. If one is configured, surface it to the user.

Use AskUserQuestion to select auth:

- **Inherit from collection** — no auth block written (uses collection/folder default)
- **None** — explicit `auth: { mode: none }`
- **Bearer token** — prompt for token variable (e.g., `{{token}}`)
- **Basic** — prompt for username and password variables
- **API Key** — prompt for key name, value, and placement (`header` or `query`)
- **OAuth 2.0** — prompt for grant type (client_credentials or authorization_code), token URL, client ID/secret variables, and scope

## Step 5: Configure Request Body

Use AskUserQuestion to select body type:

- **None** — no body block
- **JSON** — `mode: json` with a starter `{}` template; ask if the user wants to provide a sample payload
- **Form URL-encoded** — `mode: form-urlencoded`
- **Multipart form** — `mode: multipart/form-data`
- **XML** — `mode: xml`
- **GraphQL** — `mode: graphql` with a query/variables stub

If JSON is selected and the user provides a sample body, include it verbatim in the file.

## Step 6: Configure Headers

Ask: _"Any custom headers? (e.g., `Content-Type: application/json`, `X-Request-Id: {{requestId}}`)"_

Accept a free-text list (one per line), parse each as `name: value`. Pre-fill `Content-Type` matching the selected body type automatically — do not duplicate if the user also listed it.

## Step 7: Determine Sequence Number

Count existing request files in the target folder:

```
find <target-folder> -maxdepth 1 -name "*.yml" | wc -l
```

Set `seq` to `count + 1`.

## Step 8: Generate the File

Build the filename: lowercase the request name, replace spaces with hyphens, strip special characters (e.g., `Get User by ID` → `get-user-by-id.yml`).

### YAML Format (`.yml`) — default

Produce a YAML file using the OpenCollection schema. Include only blocks that have content — omit empty sections entirely.

```yaml
meta:
  name: <Request Name>
  type: http
  seq: <N>

http:
  method: <METHOD>
  url: "<URL>"

  auth:
    mode: <mode>
    bearer:
      token: "{{token}}"
    # or basic:
    #   username: "{{username}}"
    #   password: "{{password}}"
    # or apikey:
    #   key: X-API-Key
    #   value: "{{apiKey}}"
    #   placement: header

  headers:
    - name: Content-Type
      value: application/json
      enabled: true

  params:
    - name: <paramName>
      value: <value>
      enabled: true

  body:
    mode: json
    json: |
      {
        "key": "value"
      }

  script:
    req: |
      // pre-request script
    res: |
      // post-response script

  tests:
    - name: "Status is 200"
      assert: "res.status === 200"
```

**Auth block examples by mode:**

```yaml
# Bearer
auth:
  mode: bearer
  bearer:
    token: "{{token}}"

# Basic
auth:
  mode: basic
  basic:
    username: "{{username}}"
    password: "{{password}}"

# API Key
auth:
  mode: apikey
  apikey:
    key: X-API-Key
    value: "{{apiKey}}"
    placement: header

# OAuth2 client credentials
auth:
  mode: oauth2
  oauth2:
    grant_type: client_credentials
    access_token_url: "{{token_url}}"
    client_id: "{{client_id}}"
    client_secret: "{{client_secret}}"
    scope: ""
```

### Legacy Format (`.bru`) — only when the collection uses `bruno.json`

Use the `.bru` block syntax matching the existing collection style. Do not mix formats.

## Step 9: Confirm and Write

Show the complete generated file content using AskUserQuestion with a `preview` option.

Options:
- **Create file** (preview shows full file content) — write the file
- **Edit first** — ask what to change and regenerate
- **Abort** — cancel

Write the file to `<target-folder>/<filename>.yml` (or `.bru` for legacy).

After writing, confirm:

```
Created: <relative-path>/<filename>.yml
```
