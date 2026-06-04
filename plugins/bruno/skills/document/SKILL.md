---
name: document
description: Document a Bruno collection — catalog all endpoints, methods, auth, environments, and variables as formatted markdown. Supports OpenCollection YAML and legacy .bru format.
user-invocable: true
argument-hint: '[path/to/collection/]'
allowed-tools: Bash(find *), Read, Glob, Grep, AskUserQuestion
---

# Document a Bruno Collection

Analyze a Bruno collection and produce a comprehensive markdown reference covering all endpoints, authentication patterns, environments, variables, and scripting conventions. Prefers OpenCollection YAML format (`.yml`) but reads legacy `.bru` collections transparently.

## Step 1: Locate the Collection Root

Check `$ARGUMENTS` — if a directory path is provided, use it directly.

Otherwise, search for a collection root from the current directory (run in parallel):

```
find . -name "opencollection.yml" -not -path "*/node_modules/*" -maxdepth 6
find . -name "bruno.json" -not -path "*/node_modules/*" -maxdepth 6
```

Prefer `opencollection.yml`. Fall back to `bruno.json`. Use the parent directory as the collection root.

- One result → use it.
- Multiple → use AskUserQuestion to let the user pick.
- None → inform the user no Bruno collection was found and stop.

## Step 2: Detect Collection Format

If `opencollection.yml` was found → **YAML format** (preferred). Read `opencollection.yml`.

If only `bruno.json` was found → **legacy format**. Read `bruno.json` and `collection.bru` (if present).

Note the format in the final output header.

## Step 3: Read Collection Metadata

**YAML format** — extract from `opencollection.yml`:

```yaml
info:
  name:         # collection name
  description:  # description
  version:      # version

vars:           # collection-level variables (key: value)
auth:
  mode:         # default auth mode
headers:        # collection-level headers (list)
script:
  req:          # global pre-request script (JS)
  res:          # global post-response script (JS)
```

**Legacy format** — extract from `collection.bru`:
- `vars` block — key-value pairs
- `auth` block — mode and config
- `script:pre-request` / `script:pre-response` blocks

## Step 4: Catalog Environments

Run:

```
find <collection-root>/environments -name "*.yml" 2>/dev/null | sort
```

For each environment file, read it and extract the `vars` block (key-value pairs). Flag any keys whose values appear masked or empty (likely secrets).

For legacy format, look for `.bru` files in `environments/` instead.

## Step 5: Walk the Collection and Catalog All Requests

**YAML format** — find all request files:

```
find <collection-root> -name "*.yml" -not -path "*/environments/*" -not -name "opencollection.yml" -not -name "folder.yml" | sort
```

**Legacy format**:

```
find <collection-root> -name "*.bru" -not -path "*/environments/*" -not -name "collection.bru" | sort
```

For each request file, read it and extract the following. Use the YAML path `http.<field>` for YAML format, or the corresponding `.bru` block for legacy:

| Field | YAML path | Notes |
|---|---|---|
| Request name | `meta.name` | |
| Type | `meta.type` | http, graphql, grpc, ws |
| Sequence | `meta.seq` | |
| Method | `http.method` | |
| URL | `http.url` | |
| Auth mode | `http.auth.mode` | none, basic, bearer, oauth2, api-key, digest, aws-signature |
| Headers | `http.headers[].name` | list of enabled headers |
| Query params | `http.params[].name` | list of enabled params |
| Body mode | `http.body.mode` | json, form-urlencoded, multipart/form-data, xml, text |
| Has pre-request script | `http.script.req` present? | |
| Has post-response script | `http.script.res` present? | |
| Has test script | `http.script.tests` present? | |
| Has declarative assertions | `http.tests` present? | |
| Docs | top-level `docs` block | |

Sort requests by folder path, then by `meta.seq` within each folder.

## Step 6: Identify Folder-Level Config

For each subdirectory, check for `folder.yml` (YAML) or `bruno.bru` / `folder.bru` (legacy):

- Extract `auth`, `headers`, `vars`, and `script` overrides
- Note which folders inherit the collection default vs. override it

## Step 7: Compile Variable Inventory

Scan all request URLs, headers, body content, and scripts for `{{variable_name}}` references. Deduplicate and cross-reference with environment and collection vars to identify:

- Variables defined at collection level
- Variables defined per environment
- Variables set dynamically in scripts (`bru.setVar(...)`)
- Variables used but not defined anywhere (flag these as potentially missing)

## Step 8: Produce the Documentation

Output a structured markdown document:

---

# `<Collection Name>` — API Reference

> Bruno `<YAML|legacy>` collection · v`<version>` · `<N>` requests · `<N>` folders

## Environments

| Environment | Variables |
|---|---|
| `development` | `BASE_URL`, `API_KEY`, `TOKEN` (+N more) |
| `staging` | … |
| `production` | … |

## Collection Defaults

**Auth:** `<mode>` — `<token/username field or "none">`

**Global Headers:**

| Header | Value |
|---|---|
| `X-API-Key` | `{{api_key}}` |

**Global Pre-request Script:** yes / no

## Collection Variables

| Variable | Value |
|---|---|
| `base_url` | `https://api.example.com` |

## Endpoints

### `<Folder Name>` (or Root)

> Folder auth: `<mode>` (overrides collection default) — or "Inherits collection auth"

| # | Method | Endpoint | Auth | Body | Tests |
|---|---|---|---|---|---|
| 1 | `GET` | `/users/{{userId}}` | bearer | — | yes |
| 2 | `POST` | `/users` | bearer | json | — |

**`GET /users/{{userId}}`** — _Get User by ID_

- Auth: bearer
- Params: `userId` (path variable)
- Pre-request script: yes
- Assertions: yes

*(repeat for each request)*

## Variable Inventory

| Variable | Defined In | Used In |
|---|---|---|
| `{{base_url}}` | collection, all envs | All request URLs |
| `{{token}}` | env | Auth headers (N requests) |
| `{{userId}}` | script (`bru.setVar`) | `/users/{{userId}}` |
| `{{unknownVar}}` | **⚠ not defined** | `POST /orders` header |

## Scripting Summary

| Request | Pre-request | Post-response | Tests |
|---|---|---|---|
| `Login` | Sets `access_token` | — | Checks 200 + token field |

---

If the collection has more than 50 requests, use AskUserQuestion to ask whether the user wants full per-request detail or a condensed table-only view.
