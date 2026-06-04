---
name: test
description: Add, generate, or run tests for Bruno requests using the OpenCollection YAML v1.0.0 schema — correct runtime.scripts (type:tests) and runtime.assertions (expression/operator/value) structure.
user-invocable: true
argument-hint: '[path/to/request.yml | path/to/folder/]'
allowed-tools: Bash(bru *), Bash(find *), Read, Edit, Glob, Grep, AskUserQuestion
---

# Bruno Testing Assistant

Add, generate, or run tests for Bruno requests conforming to the OpenCollection YAML v1.0.0 spec
(`https://schema.opencollection.com/opencollection/v1.0.0.json`).

Tests and assertions live under the `runtime` top-level key — **not** under `http`. Scripts are typed array entries; assertions are structured objects with `expression`, `operator`, and optional `value`.

## Step 1: Locate the Collection Root

Check `$ARGUMENTS` — if it points to a specific `.yml` request file, use it directly (skip to Step 3). If it points to a folder, use that folder as the scope.

Otherwise, find the collection root (run in parallel):

```
find . -name "opencollection.yml" -not -path "*/node_modules/*" -maxdepth 6
find . -name "bruno.json" -not -path "*/node_modules/*" -maxdepth 6
```

Prefer `opencollection.yml`. Fall back to `bruno.json`.

## Step 2: Select the Target Scope

Use AskUserQuestion:

- **A single request** — show a numbered list of all `.yml` request files
- **All requests in a folder** — show a numbered list of subfolders
- **The entire collection** — all request files

Present up to 15 options. Note the total count if more exist.

## Step 3: Choose Testing Mode

Use AskUserQuestion:

- **Add tests to requests** — generate and write tests for the selected scope
- **Run existing tests** — execute `bru run --tests-only`
- **Review and fix failing tests** — run tests, diagnose failures, apply fixes

---

## Mode A: Add Tests

For each targeted request file:

### A1. Read the Request

Read the `.yml` file. Locate:

- `info.name` — request name
- `http.method` and `http.url`
- `http.auth.type` — auth mode
- `http.body.type` — body type
- `runtime.scripts` — look for entries with `type: "tests"` (Chai script)
- `runtime.assertions` — existing declarative assertions

If tests already exist, show them and use AskUserQuestion to ask:
- **Extend** — keep existing, add new ones
- **Replace** — start fresh
- **Skip** — leave unchanged

### A2. Generate Tests

Propose tests based on `http.method`:

**Always:**
- Status code matches the expected code for the method (200 GET, 201 POST, 204 DELETE, etc.)
- Response time under 2000ms

**GET:** response body defined, required top-level fields exist, pagination fields if params include `page`/`limit`

**POST/PUT/PATCH:** returned resource has `id`, submitted fields are echoed back, `Content-Type` response header contains `application/json`

**DELETE:** body empty or success confirmation, status 200 or 204

**Authenticated requests:** note that a 401 negative test should be a separate request file

**JSON body:** suggest field-level response assertions based on the submitted payload shape

### A3. Choose Test Format

Use AskUserQuestion:

- **Declarative assertions** — entries under `runtime.assertions`; best for simple status/field checks
- **Chai test script** — `type: tests` entry under `runtime.scripts`; best for complex logic
- **Both** — use assertions for simple checks, test script for complex ones

**Declarative assertions — `expression` and `operator` are REQUIRED; `value` is optional:**

```yaml
runtime:
  assertions:
    - expression: "response.status"
      operator: "equals"
      value: "200"
    - expression: "response.body.id"
      operator: "isDefined"
    - expression: "response.body.name"
      operator: "isString"
    - expression: "response.time"
      operator: "lt"
      value: "2000"
    - expression: "response.headers.content-type"
      operator: "contains"
      value: "application/json"
```

Available operators: `equals`, `notEquals`, `gt`, `gte`, `lt`, `lte`, `contains`, `notContains`, `startsWith`, `endsWith`, `matches`, `notMatches`, `isNull`, `isNotEmpty`, `isEmpty`, `isDefined`, `isUndefined`, `isTruthy`, `isFalsy`, `isNumber`, `isString`, `isBoolean`, `isArray`, `isJson`.

**Chai test script — a `type: tests` entry in `runtime.scripts`:**

```yaml
runtime:
  scripts:
    - type: tests
      code: |
        test("Status is 201", function() {
          expect(res.getStatus()).to.equal(201);
        });

        test("Response has id", function() {
          const body = res.getJSON();
          expect(body).to.have.property("id");
          expect(body.id).to.be.a("string");
        });

        test("Response time under 2s", function() {
          expect(res.getResponseTime()).to.be.below(2000);
        });
```

If the request already has a `before-request` or `after-response` script, append the `tests` entry to the existing `runtime.scripts` array — do NOT overwrite existing entries.

### A4. Preview and Confirm

Show the generated `runtime` block using AskUserQuestion with a `preview`. Options:
- **Write tests** — update the file
- **Adjust** — ask what to change, regenerate
- **Skip** — leave unchanged

### A5. Write Tests

Use Edit to insert or update the `runtime` block in the `.yml` file. Rules:

- Merge with any existing `runtime` content — preserve `variables`, `actions`, and any existing script entries with different `type` values
- For assertions: replace the entire `runtime.assertions` array if replacing, or append entries if extending
- For the test script: if a `type: tests` entry already exists, replace only its `code` field; otherwise append a new `{type: tests, code}` entry to `runtime.scripts`

Confirm: `Updated: <relative-path>`

Repeat A1–A5 for each targeted request file.

---

## Mode B: Run Existing Tests

### B1. Select an Environment

List environments from `<collection-root>/environments/*.yml`. Use AskUserQuestion to select one (or "No environment").

### B2. Build and Execute

```
bru run <target> --tests-only [--env <env-name>] [--recursive] [--sandbox developer]
```

Add `--recursive` for full-collection runs. Show the command before running.

### B3. Display Results

- **Summary**: total tests, passed, failed, skipped
- **Failures**: request name, test/assertion name, expected vs. actual
- **Exit code**: 0 = all passed, 1 = test failures

---

## Mode C: Review and Fix Failing Tests

Run tests as in Mode B. For each failure:

### C1. Diagnose

Read the request file. Identify the failing `runtime.assertions` entry or `type: tests` script block. Categorize:

- **Wrong expected value** — `value` in assertion doesn't match actual response
- **Missing field** — `expression` references a field that no longer exists in the response
- **Wrong status code** — API now returns a different status
- **Response time fluke** — timing assertion; note thresholds can be environment-dependent
- **Auth error** — 401/403 points to token/scope issue, not a test bug
- **Script runtime error** — JavaScript exception in the `code` field

### C2. Propose Fixes

For each diagnosis, propose a concrete edit to the `runtime.assertions` entry or `runtime.scripts[type=tests].code`. Use AskUserQuestion:

- **Apply fix** — update the file
- **Skip** — leave failing test as-is
- **Remove** — delete the assertion entry or the specific `test(...)` block from the script

### C3. Re-run to Verify

Re-run with `bru run --tests-only`. If still failing, repeat up to 2 more times.

After the third failure on the same test, stop and output:

```
STILL FAILING after 3 attempts:
  Request:    <request name>
  Test:       <assertion expression or test() name>
  Error:      <raw output from bru>
  File:       <path/to/request.yml>
```

Present this to the user so they have the exact output needed to fix it manually.
