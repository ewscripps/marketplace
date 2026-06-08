# Test-Coverage Audit Patterns

**Source:** 16 initiatives from scripps-mcp/SRD corpus, June 2026 (EDMV2 seed).
**Auto-updated** by orchestrator after each test-coverage audit round (EDMV2-80a).

---

## Top Recurring Findings

Frequency: [x/16] = appeared in x of 16 audited initiatives.

| # | Pattern | Frequency | Typical severity |
|---|---------|-----------|-----------------|
| 1 | AC <-> test cross-reference incomplete | 7/16 | P1 |
| 2 | Missing tests for error paths | 6/16 | P1 |
| 3 | Coverage floor not met on changed surfaces | 6/16 | P1 |
| 4 | Branch coverage gaps in defensive paths | 5/16 | P1 |
| 5 | Fragile / flaky integration tests | 4/16 | P1 |
| 6 | Test setup complexity hides the assertions | 3/16 | P2 |
| 7 | Golden snapshots that drift silently | 3/16 | P2 |

### 1. AC <-> test cross-reference incomplete (7/16)
- An AC says "assert X" but the named test file doesn't exist or tests the wrong code
- AC says "unit test" but only an integration test covers it
- Test file exists but no test exercises the specific AC behavior end-to-end

### 2. Missing tests for error paths (6/16)
- Tests cover "success" (200, single item) but not error cases (timeout, 429, 5xx, malformed response)
- AC says "on 429 response, read Retry-After header" but only the 200 case is tested

### 3. Coverage floor not met on changed surfaces (6/16)
- Pre-existing untested code drags the file-level % down; new code is 95% covered but old code is 40%
- File-level coverage measured instead of changed-line coverage

### 4. Branch coverage gaps in defensive paths (5/16)
- Line coverage 95% but branch coverage 70% -- the `else` path (unexpected values) untested
- High-confidence "can't happen" branches left uncovered -- they fail open silently

### 5. Fragile / flaky integration tests (4/16)
- Tests call external APIs (Brave, SendGrid, etc.) and pass most of the time but fail intermittently
- Tests depend on specific data in a shared environment that can be mutated by other tests

### 6. Test setup complexity hides assertions (3/16)
- A test has 50 lines of setup (mocking, fixtures, DB seeding) and 3 lines of assertion
- The actual behavior being verified is buried and hard to review

### 7. Snapshot drift (3/16)
- A snapshot test regenerates every run because the output includes timestamps, UUIDs, or dynamic values
- Snapshot passes but represents non-deterministic output -- a false green

---

## Anti-Patterns

### Over-mocking hides real bugs
All database calls are mocked; the test passes but real DB code would fail because the ORM is misconfigured.
**Fix:** Unit tests mock at the service boundary; integration tests hit a real or containerized DB (testcontainers).

### Global test setup that persists across files
`beforeEach` in one test file sets a global variable that another test file assumes exists.
**Fix:** Test files are independent. `beforeEach` paired with `afterEach` for cleanup; no cross-file globals.

### Test that only checks it doesn't crash
AC says "assert X" but the test only checks "calling X does not throw."
**Fix:** Every test has >=1 assertion on the output or state, not just "no error thrown."

### Happy-path-only coverage
Requirement says "reject on invalid input"; test covers the valid case only.
**Fix:** AC template includes edge cases: null, empty, invalid, boundary values, duplicates.

### Misleading test name
Test named `testAdminCanCreate` only tests "no error on create" -- it doesn't verify non-admin gets 403.
**Fix:** Test name includes both cases when testing a gate (e.g., `testAdminCanCreateAndUserCannot`).

---

## Pre-Flight Checklist

Run before declaring test coverage complete:

- [ ] **Coverage measured correctly:** Measure coverage of *changed lines only* via `git diff main...HEAD`, not file-level %. Target: >=80% of changed lines covered.
- [ ] **High-risk paths tested (both directions):** Any changed line that touches auth, permissions, or data integrity has >=2 tests: one asserting allow, one asserting deny.
- [ ] **AC <-> test table complete:** For each ticket, a table lists all ACs and their corresponding test file:line. Spot-check >=5 entries by running the test and confirming it actually asserts the AC.
- [ ] **Error paths tested:** For every HTTP call, retry, or async operation, there is a test exercising the error case (timeout, 429, 5xx, exception, empty response).
- [ ] **Mocking policy clear:** Unit tests mock external services; integration tests use a real or containerized dependency; E2E tests use the real system. Document the policy in the test-coverage report.
- [ ] **No flaky tests:** Run the full test suite >=3 times locally; 100% pass rate each time. Any intermittent failure is tagged `@flaky` and tracked.
- [ ] **Test setup is minimal:** Test code <=20 lines; setup is in fixtures/helpers; the assertion is the final 1-3 lines.
- [ ] **Snapshots are deterministic:** Regenerating a snapshot produces byte-identical output. No timestamps, UUIDs, or process-order-dependent values in snapshot fixtures.

---

## What Passing Test Coverage Looks Like

- **Changed-line coverage >=80%,** measured via `git diff` -- pre-existing untested code doesn't penalize the new work.
- **Every AC has a corresponding test** listed in a table with file:line citations. Spot-checking confirms each test actually exercises the AC, not just the happy path.
- **High-risk code has >=2 tests per operation:** success case and failure/denial case.
- **Error paths are tested:** every fallible operation (HTTP, DB, file I/O) has a test mocking the error and asserting the response (log warning, return null, throw, etc.).
- **Test setup is clean:** no leaking globals; each test file runs independently; setup is in a helper, not repeated inline.
- **Snapshot tests are deterministic:** regenerating produces the same output -- no dynamic values in fixtures.
