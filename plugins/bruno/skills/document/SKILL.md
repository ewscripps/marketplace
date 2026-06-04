---
name: document
description: Document a Bruno collection — catalog all endpoints, methods, auth, environments, and variables as formatted markdown. Reads OpenCollection YAML v1.0.0 schema (info/http/runtime) and legacy .bru format.
user-invocable: true
argument-hint: '[path/to/collection/]'
allowed-tools: Bash(find *), Read, Glob, Grep, AskUserQuestion
---

# Document a Bruno Collection

Analyze a Bruno collection and produce a comprehensive markdown reference. Reads the OpenCollection YAML v1.0.0 spec (`https://schema.opencollection.com/opencollection/v1.0.0.json`) by default, with transparent fallback to legacy `.bru` format.

## Step 1: Locate the Collection Root

Check `$ARGUMENTS` — if a directory path is provided, use it directly.

Otherwise (run in parallel):

```
find . -name "opencollection.yml" -not -path "*/node_modules/*" -maxdepth 6
find . -name "bruno.json" -not -path "*/node_modules/*" -maxdepth 6
```

Prefer `opencollection.yml`. Fall back to `bruno.json`. One result → use it. Multiple → AskUserQuestion to pick. None → stop.

## Step 2: Detect Collection Format

**YAML format** — `opencollection.yml` found. Read it.

**Legacy format** — only `bruno.json` found. Read `bruno.json` and `collection.bru` if present.

Note the format in the output header.

## Step 3: Read Collection Metadata

**YAML format** — extract from `opencollection.yml`:

| Key | Path | Notes |
|---|---|---|
| Spec version | `opencollection` | e.g., `"1.0.0"` |
| Name | `info.name` | |
| Summary | `info.summary` | |
| Version | `info.version` | |
| Authors | `info.authors[].name` | |
| Collection variables | `request.variables[]` | array of `{name, value}` objects |
| Default auth type | `request.auth.type` | or `"inherit"` string |
| Default headers | `request.headers[].name` | list of active (non-disabled) headers |
| Global scripts | `request.scripts[]` | array of `{type, code}` entries |

**Legacy format** — extract from `collection.bru`:
- `vars` block (key-value pairs)
- `auth` block (mode and config)
- `script:pre-request` / `script:pre-response` blocks

## Step 4: Catalog Environments

**YAML format** — environments may be defined inline in `opencollection.yml` under `config.environments[]`, OR as separate files in `environments/`:

- If `config.environments[]` is present in `opencollection.yml` (already read in Step 3), extract environments from that array directly — no additional file read needed.
- If not present inline, find separate environment files:

```
find <collection-root>/environments -name "*.yml" 2>/dev/null | sort
```

For each environment, extract from the `Environment` object:
- `name` — environment name (required field in spec)
- `variables[]` — array of `Variable` (`{name, value}`) or `SecretVariable` (`{name, secret: true}`) objects
- `extends` — parent environment name if this env inherits from another
- `dotEnvFilePath` — path to a `.env` file if external secrets are loaded

**Legacy format:**
```
find <collection-root>/environments -name "*.bru" 2>/dev/null | sort
```

## Step 5: Walk the Collection and Catalog All Requests

**YAML format:**
```
find <collection-root> -name "*.yml" -not -path "*/environments/*" -not -name "opencollection.yml" -not -name "folder.yml" | sort
```

**Legacy format:**
```
find <collection-root> -name "*.bru" -not -path "*/environments/*" -not -name "collection.bru" | sort
```

For each request file, read and extract. **YAML schema paths** (`HttpRequest` object):

| Field | YAML path | Notes |
|---|---|---|
| Request name | `info.name` | |
| Type | `info.type` | const `"http"` for HTTP requests |
| Sequence | `info.seq` | number |
| Tags | `info.tags[]` | string array |
| Method | `http.method` | |
| URL | `http.url` | |
| Auth type | `http.auth.type` | or string `"inherit"` |
| Headers | `http.headers[]` | skip entries where `disabled: true` |
| Query params | `http.params[]` where `type == "query"` | `type` is required per spec |
| Path params | `http.params[]` where `type == "path"` | |
| Body type | `http.body.type` | `json`, `xml`, `text`, `sparql`, `form-urlencoded`, `multipart-form`, `file` |
| Pre-request script | `runtime.scripts[]` entry with `type == "before-request"` | |
| Post-response script | `runtime.scripts[]` entry with `type == "after-response"` | |
| Test script | `runtime.scripts[]` entry with `type == "tests"` | |
| Assertions | `runtime.assertions[]` | array of `{expression, operator, value?}` |
| Request variables | `runtime.variables[]` | array of `{name, value}` |
| Docs | `docs` | top-level string |

Sort requests by folder path, then by `info.seq` within each folder.

## Step 6: Identify Folder-Level Config

For each subdirectory, check for `folder.yml` (YAML) or `bruno.bru`/`folder.bru` (legacy).

**YAML `folder.yml`** — a `Folder` object:

| Key | Notes |
|---|---|
| `info.name` | Folder name |
| `info.seq` | Folder sequence |
| `request.auth` | Auth override (`type:` object or `"inherit"`) |
| `request.headers[]` | Additional headers |
| `request.variables[]` | Folder-level variables |
| `request.scripts[]` | Folder-level scripts |

Note which folders override auth vs. inherit from the collection default.

## Step 7: Compile Variable Inventory

Scan all request URLs, header values, body `data` fields, and script `code` fields for `{{variable_name}}` references.

Cross-reference with:
- `request.variables[]` in `opencollection.yml` (collection-level)
- `variables[]` in each environment file
- `bru.setVar(...)` calls in script `code` fields (set dynamically at runtime)

Report:
- Variables defined at collection level
- Variables defined per environment (note which envs define each)
- Variables set dynamically in scripts
- Variables used but not defined anywhere (flag as ⚠ missing)
- Secret variables (defined with `secret: true`, no stored value)

## Step 8: Produce the Documentation

Output as structured markdown:

---

# `<Collection Name>` — API Reference

> OpenCollection YAML v`<opencollection>` · v`<info.version>` · `<N>` requests · `<N>` folders *(for legacy .bru collections, omit the OpenCollection version and label as "Bruno legacy .bru")*

## Environments

| Environment | Variables | Extends | .env |
|---|---|---|---|
| `local` | `base_url`, ~~`token`~~ (secret) | — | `.env.local` |
| `staging` | `base_url`, ~~`token`~~ (secret) | — | — |

*(Strike through secret variable names to indicate they have no stored value)*

## Collection Defaults

**Auth:** `bearer` — `token: {{token}}`

**Global Headers:**

| Header | Value |
|---|---|
| `Content-Type` | `application/json` |

**Global Scripts:** before-request, after-response (or "none")

## Collection Variables

| Variable | Value |
|---|---|
| `base_url` | `https://api.example.com` |
| `api_version` | `v1` |

## Endpoints

### `<Folder Name>` (or Root)

> Folder auth: `inherit` (uses collection bearer) — or describe the override

| # | Method | Endpoint | Auth | Body | Assertions | Tests |
|---|---|---|---|---|---|---|
| 1 | `GET` | `/users/{{userId}}` | bearer | — | 2 | yes |
| 2 | `POST` | `/users` | inherit | json | 1 | — |

**`GET /users/{{userId}}`** — _Get User by ID_

- Auth: `bearer`
- Path params: `userId`
- Pre-request script: yes
- Post-response script: no
- Assertions: `response.status equals 200`, `response.body.id isDefined`
- Test script: yes

*(repeat for each request)*

## Variable Inventory

| Variable | Defined In | Used In |
|---|---|---|
| `{{base_url}}` | collection, all envs | All request URLs |
| `{{token}}` | env (secret) | Bearer auth (N requests) |
| `{{userId}}` | runtime (`bru.setVar`) | `/users/{{userId}}` |
| `{{unknownVar}}` | **⚠ not defined** | `POST /orders` body |

## Scripting Summary

| Request | Before-request | After-response | Tests | Assertions |
|---|---|---|---|---|
| `Login` | Sets `access_token` | — | Checks 200 + token | 1 |

---

If the collection has more than 50 requests, use AskUserQuestion to ask: full per-request detail or condensed table-only view.
