---
name: new-request
description: Scaffold a new request file in a Bruno collection using the OpenCollection YAML v1.0.0 schema — correct info/http/runtime structure with proper auth, body, params, scripts, and assertions.
user-invocable: true
argument-hint: '[path/to/collection/ | folder/name]'
allowed-tools: Bash(find *), Read, Write, Glob, AskUserQuestion
---

# Scaffold a New Bruno Request

Create a new `.yml` request file conforming to the OpenCollection YAML v1.0.0 spec
(`https://schema.opencollection.com/opencollection/v1.0.0.json`).

## Step 1: Locate the Collection Root

Check `$ARGUMENTS` — if a path contains `opencollection.yml` or `bruno.json`, use it as the collection root.

Otherwise, search from the current directory (run in parallel):

```
find . -name "opencollection.yml" -not -path "*/node_modules/*" -maxdepth 6
find . -name "bruno.json" -not -path "*/node_modules/*" -maxdepth 6
```

Prefer `opencollection.yml` (OpenCollection YAML). Fall back to `bruno.json` (legacy `.bru` format).

- One result → use it. Multiple → AskUserQuestion to pick. None → inform the user no Bruno collection was found and stop.

Note the detected format — YAML collections use the full spec schema; legacy collections use `.bru` block syntax. The rest of this skill applies to the YAML format. For legacy collections, generate `.bru` syntax instead.

## Step 2: Select a Target Folder

List all existing folders in the collection:

```
find <collection-root> -type d -not -path "*/environments*" -not -path "*/.git*"
```

Use AskUserQuestion to ask where to place the new request:

- Show each folder (path relative to collection root, e.g., `users/`, `orders/reports/`)
- **"Collection root"** — top-level placement
- **"Create new folder"** — ask for the folder name, create the directory, and write a `folder.yml` for it (see scaffold skill for correct format)

## Step 3: Gather Request Details

Ask via AskUserQuestion:

**Request name** (free-text): _"What's the request name? (e.g., Get User, Create Order)"_

**HTTP method** (single-select): GET · POST · PUT · PATCH · DELETE · HEAD · OPTIONS

**URL** (free-text): _"Request URL? Use `{{variable}}` for dynamic segments. (e.g., `{{base_url}}/users/{{userId}}`)"_

## Step 4: Configure Parameters

If the URL contains path variables (e.g., `{{userId}}`), automatically create path params for each.

Ask: _"Any query parameters to add?"_

Each param entry requires `name`, `value`, and `type` — the `type` field is **required** by the spec and must be either `"query"` or `"path"`.

## Step 5: Configure Authentication

Read `opencollection.yml` to detect the collection-level `request.auth` default. Surface it to the user.

Use AskUserQuestion:

- **Inherit** — write `auth: inherit` (the string `"inherit"`, not an object)
- **None** — omit auth block entirely
- **Bearer** — prompt for token variable; generates `{ type: bearer, token: "{{token}}" }`
- **Basic** — prompt for username/password vars; generates `{ type: basic, username: "...", password: "..." }`
- **API Key** — prompt for key name, value var, and placement (`header` or `query`); generates `{ type: apikey, key: "X-API-Key", value: "{{apiKey}}", placement: header }`
- **OAuth 2.0** — prompt for flow type and fields; see auth block examples below

**Auth block shapes — all use a flat `type:` discriminator (no nested sub-object):**

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
  placement: header        # enum: header | query (not body)

# OAuth2 client credentials
auth:
  type: oauth2
  flow: client_credentials
  accessTokenUrl: "{{token_url}}"
  credentials:
    clientId: "{{client_id}}"
    clientSecret: "{{client_secret}}"
    placement: basic_auth_header   # enum: basic_auth_header | body
  scope: ""

# OAuth2 authorization code
auth:
  type: oauth2
  flow: authorization_code
  authorizationUrl: "{{auth_url}}"
  accessTokenUrl: "{{token_url}}"
  credentials:
    clientId: "{{client_id}}"
    clientSecret: "{{client_secret}}"
  scope: ""

# Inherit from collection/folder default
auth: inherit
```

## Step 6: Configure Request Body

Use AskUserQuestion:

- **None** — omit body block
- **JSON** — `type: json`, ask for a sample payload
- **XML** — `type: xml`
- **Plain text** — `type: text`
- **SPARQL** — `type: sparql`
- **Form URL-encoded** — `type: form-urlencoded`
- **Multipart form** — `type: multipart-form`
- **GraphQL** — not a body type in the OpenCollection v1.0.0 spec; use the `GraphQLRequest` item type instead (set `info.type: graphql` and use the `graphql:` protocol block rather than an `http:` body)

**Body block shapes — `type` is a discriminator, content goes in `data`:**

```yaml
# Raw body (json, xml, text, sparql)
body:
  type: json
  data: |
    {
      "key": "value"
    }

# Form URL-encoded
body:
  type: form-urlencoded
  data:
    - name: field1
      value: "value1"
    - name: field2
      value: "value2"

# Multipart form
body:
  type: multipart-form
  data:
    - name: file
      type: file             # enum: text | file
      value: "/path/to/file"
      contentType: "application/octet-stream"
    - name: description
      type: text
      value: "some text"
```

## Step 7: Configure Headers

Ask: _"Any custom headers? (e.g., `Accept: application/json`, `X-Request-Id: {{requestId}}`)"_

Parse each as `name: value`. Pre-fill `Content-Type` based on body type. Do not duplicate.

Headers use `disabled: true` (not `enabled: false`) to mark inactive entries — omit `disabled` entirely for active headers.

## Step 8: Configure Runtime (Scripts and Assertions)

Ask via AskUserQuestion (multi-select):

- **Pre-request script** — adds a `before-request` script to `runtime.scripts`
- **Post-response script** — adds an `after-response` script to `runtime.scripts`
- **Test script** — adds a `tests` script to `runtime.scripts`
- **Declarative assertions** — adds entries to `runtime.assertions`
- **None** — omit `runtime` block entirely

**Scripts are an array of typed objects under `runtime.scripts`:**

```yaml
runtime:
  scripts:
    - type: before-request
      code: |
        // Runs before the request is sent
        bru.setVar("timestamp", new Date().toISOString());
    - type: after-response
      code: |
        // Runs after the response is received
        const body = res.getBody();
        bru.setVar("userId", body.id);
    - type: tests
      code: |
        test("Status is 200", function() {
          expect(res.getStatus()).to.equal(200);
        });
```

**Declarative assertions under `runtime.assertions` — `expression` and `operator` are required:**

```yaml
runtime:
  assertions:
    - expression: "response.status"
      operator: "equals"
      value: "200"
    - expression: "response.body.id"
      operator: "isDefined"
    - expression: "response.time"
      operator: "lt"
      value: "2000"
```

Available assertion operators: `equals`, `notEquals`, `gt`, `gte`, `lt`, `lte`, `contains`, `notContains`, `startsWith`, `endsWith`, `matches`, `notMatches`, `isNull`, `isNotEmpty`, `isEmpty`, `isDefined`, `isUndefined`, `isTruthy`, `isFalsy`, `isNumber`, `isString`, `isBoolean`, `isArray`, `isJson`.

## Step 9: Determine Sequence Number

Count existing request files in the target folder:

**YAML format:**
```
find <target-folder> -maxdepth 1 -name "*.yml" | wc -l
```

**Legacy format:**
```
find <target-folder> -maxdepth 1 -name "*.bru" | wc -l
```

Set `seq` to `count + 1`.

## Step 10: Generate the File

Build filename: lowercase request name, replace spaces with hyphens, strip special characters (e.g., `Get User by ID` → `get-user-by-id.yml`).

Assemble the file using the OpenCollection schema. The top-level keys are `info`, `http`, `runtime`, `settings`, `examples`, `docs`. Include only blocks that have content — omit empty sections entirely.

```yaml
info:
  name: Get User by ID
  type: http
  seq: 1

http:
  method: GET
  url: "{{base_url}}/users/{{userId}}"

  auth:
    type: bearer
    token: "{{token}}"

  headers:
    - name: Accept
      value: application/json

  params:
    - name: userId
      value: "{{userId}}"
      type: path            # REQUIRED — enum: query | path

  body:
    type: json
    data: |
      {}

runtime:
  scripts:
    - type: before-request
      code: |
        // pre-request script
    - type: after-response
      code: |
        // post-response script
  assertions:
    - expression: "response.status"
      operator: "equals"
      value: "200"
```

## Step 11: Confirm and Write

Show the full generated content using AskUserQuestion with a `preview`. Options:

- **Create file** (preview shows full YAML) — write the file
- **Edit first** — ask what to change and regenerate
- **Abort** — cancel

Write to `<target-folder>/<filename>.yml`.

Confirm: `Created: <relative-path>/<filename>.yml`
