---
name: test
description: Add, generate, or run tests for Bruno requests. Scaffolds declarative assertions and Chai test scripts in OpenCollection YAML format, then optionally executes them with bru run.
user-invocable: true
argument-hint: '[path/to/request.yml | path/to/folder/]'
allowed-tools: Bash(bru *), Bash(find *), Read, Edit, Glob, Grep, AskUserQuestion
---

# Bruno Testing Assistant

Add tests to existing Bruno requests, generate Chai test suites from request/response context, or run existing tests and interpret failures. Uses OpenCollection YAML format by default.

## Step 1: Locate the Collection Root

Check `$ARGUMENTS` — if it points to a specific `.yml` request file, use it directly (skip to Step 3). If it points to a folder, use that folder as the target scope.

Otherwise, find the collection root (run in parallel):

```
find . -name "opencollection.yml" -not -path "*/node_modules/*" -maxdepth 6
find . -name "bruno.json" -not -path "*/node_modules/*" -maxdepth 6
```

Prefer `opencollection.yml`. Fall back to `bruno.json`.

- One result → use its parent as the collection root.
- Multiple → use AskUserQuestion to pick.
- None → inform the user no collection was found and stop.

## Step 2: Select the Target Scope

Ask the user what to work on (single-select via AskUserQuestion):

- **A single request** — show a numbered list of all `.yml` request files in the collection
- **All requests in a folder** — show a numbered list of subfolders
- **The entire collection** — all request files

For single request or folder, present up to 15 options. Note the total count if more exist.

## Step 3: Choose Testing Mode

Use AskUserQuestion to ask what the user wants to do:

- **Add tests to a request** — generate and write tests for the selected target
- **Run existing tests** — execute `bru run` with `--tests-only` for the selected target
- **Review and fix failing tests** — run tests, interpret failures, and propose fixes

---

## Mode A: Add Tests to a Request

For each targeted request file:

### A1. Read the Request

Read the `.yml` file. Extract:
- `http.method` and `http.url`
- `http.auth.mode`
- `http.body.mode` and body content
- Existing `http.tests` (declarative) and `http.script.tests` (Chai script) — if any

If tests already exist, show them to the user and use AskUserQuestion to ask:
- **Extend existing tests** — add new tests while keeping existing ones
- **Replace existing tests** — start fresh
- **Skip this request** — leave it unchanged

### A2. Generate Tests

Analyze the request and propose appropriate tests. Use the method and URL as context:

**Always include:**
- Status code check (match the expected code for the method — 200 for GET, 201 for POST, 204 for DELETE, etc.)
- Response time under 2000ms

**For GET requests:**
- Response body is defined / not empty
- Required top-level fields exist in the response
- Pagination fields (if URL has `page` or `limit` params)

**For POST/PUT/PATCH requests:**
- Created/updated resource has an `id` field
- Returned object includes the submitted fields
- Response `Content-Type` contains `application/json`

**For DELETE requests:**
- Body is empty or returns a success confirmation
- Status is 200 or 204

**For authenticated requests:**
- Include a note that a 401 test can be run by omitting the token (suggest doing so in a separate "negative test" request)

**For requests with JSON bodies:**
- Parse the body and suggest field-level assertions on the response

### A3. Choose Test Style

Use AskUserQuestion to select the test format:

- **Declarative assertions** — simple `name` + `assert` expression pairs under `http.tests`; best for straightforward status/field checks
- **Chai test script** — full `test("...", function() { expect(...) })` blocks under `http.script.tests`; best for complex logic, loops, or extraction

**Declarative format:**
```yaml
  tests:
    - name: "Status is 200"
      assert: "res.status === 200"
    - name: "Response has id"
      assert: "res.body.id !== undefined"
    - name: "Response time under 2s"
      assert: "res.getResponseTime() < 2000"
```

**Chai script format:**
```yaml
  script:
    tests: |
      test("Status is 200", function() {
        expect(res.getStatus()).to.equal(200);
      });

      test("Response body has id", function() {
        const body = res.getJSON();
        expect(body).to.have.property("id");
      });

      test("Response time under 2s", function() {
        expect(res.getResponseTime()).to.be.below(2000);
      });
```

Both styles can coexist in the same request — `http.tests` for declarative, `http.script.tests` for Chai.

### A4. Preview and Confirm

Show the user the generated tests using AskUserQuestion with a `preview` block. Options:
- **Write tests** (preview shows the test YAML block)
- **Adjust** — ask the user what to change and regenerate
- **Skip this request** — leave it unchanged

### A5. Write Tests

Use Edit to insert or replace the `tests` and/or `script.tests` block in the `.yml` file. Preserve all other fields.

After writing, confirm: `Updated: <relative-path>`

Repeat A1–A5 for each targeted request file.

---

## Mode B: Run Existing Tests

### B1. Select an Environment

List available environments from `<collection-root>/environments/*.yml`. Use AskUserQuestion to select one (or "No environment").

### B2. Build and Execute

Run:

```
bru run <target> --tests-only [--env <env-name>] [--sandbox developer]
```

`<target>` is the specific request file, folder path, or collection root with `--recursive`.

Show the command to the user before running.

### B3. Display Results

After execution, display:
- **Summary**: total tests, passed, failed, skipped
- **Failures**: request name, test name, expected vs. actual value
- **Exit code**: 0 = all passed, 1 = test failures

If all tests pass, say so clearly.

---

## Mode C: Review and Fix Failing Tests

Run tests as in Mode B. If any fail:

### C1. Diagnose Each Failure

For each failing test, read the corresponding request file and the test block. Diagnose the failure:

- **Wrong expected value** — the assert literal doesn't match the real API response
- **Missing field** — response body structure changed
- **Wrong status code expectation** — API now returns a different code
- **Response time fluke** — if timing-based, note that thresholds can be flaky
- **Auth error** — 401/403 indicates token or scope issue
- **Script error** — JavaScript runtime error in the test block itself

### C2. Propose Fixes

For each diagnosis, propose a concrete fix to the test or to the request. Use AskUserQuestion to confirm:

- **Apply fix** — update the test block in the `.yml` file
- **Skip** — leave the failing test as-is
- **Remove test** — delete the failing test entry

### C3. Re-run to Verify

After applying fixes, re-run with `bru run --tests-only` and confirm the tests now pass. If they still fail, repeat the diagnosis cycle up to 2 more times.

After the third failure on the same test, stop retrying and output a final failure summary:

```
STILL FAILING after 3 attempts:
  Request: <request name>
  Test:    <test name>
  Error:   <raw assertion output from bru>
  File:    <path/to/request.yml>:<line>
```

Present this summary to the user so they have the exact assertion output and file location needed to fix it manually.
