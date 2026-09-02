# Code Audit Patterns

**Source:** EDM seed corpus (16 real-world initiatives).
**Auto-updated** by the code-audit phase's own skill (`skills/code-audit/SKILL.md`) via `edm-state update-patterns` after each round (EDMV2-80a; EDMV3-T37).

---

## Top Recurring Findings

Frequency: [x/16] = appeared in x of 16 audited initiatives.

| # | Pattern                                              | Frequency | Typical severity |
|---|------------------------------------------------------|-----------|------------------|
| 1 | Inline privilege checks instead of shared predicates | 9/16      | P0               |
| 2 | Missing error paths / silent failures                | 8/16      | P0-P1            |
| 3 | Silent privilege escalation from stale data          | 7/16      | P0               |
| 4 | Hardcoded constants replicated across files          | 6/16      | P1               |
| 5 | Secrets/credentials in logs or test fixtures         | 5/16      | P0               |
| 6 | Type/interface mismatches across service boundaries  | 5/16      | P1               |
| 7 | Feature flags without a consistent check pattern     | 5/16      | P1               |
| 8 | Test double pollution / missing teardown             | 5/16      | P1               |
| 9 | Dead code / orphaned functions                       | 4/16      | P2               |

### 1. Inline privilege checks (9/16)

- `role === "admin"` checked inline in 5+ files with subtle variations (one uses `===`, another `includes` which
  unintentionally matches `system_admin`)
- Same logic duplicated; one copy drifts silently

### 2. Missing error paths (8/16)

- A request fails (500 from upstream, timeout) but code logs only at INFO or emits no span
- No distinction between "not found" (expected 404) and "error during fetch" (unexpected 500)

### 3. Silent privilege escalation from stale data (7/16)

- DB role says "user" but JWT says "admin"; code picks the highest instead of the DB-authoritative one
- Old token/header never invalidated; no refresh gate

### 4. Hardcoded constants replicated (6/16)

- Role name `"system_admin"` appears inline in 3 places; migration SQL creates a 4th variant `"systemadmin"`
- Two files agree; one drifts silently

### 5. Secrets/credentials in logs or fixtures (5/16)

- A test fixture contains a real API key or JWT token
- Error logging includes the full request body (with credentials)

### 6. Type/interface mismatches (5/16)

- Server returns `{ role: string }` but client expects `role: 'admin' | 'user' | 'system_admin'` (no null)
- Field added to a DTO but not propagated to all consuming code

### 7. Feature flags without a consistent pattern (5/16)

- Some flags are env vars, others are DB fields, others are computed; the check logic is duplicated and diverges

### 8. Test double pollution (5/16)

- A test stubs a global (e.g., `globalThis.fetch`, a module mock, or a singleton) and never restores it; later tests
  in the same process use the stub unintentionally

### 9. Dead code / orphaned functions (4/16)

- A function is exported but imported nowhere; a route handler is defined but never registered

---

## Anti-Patterns

### Bare `if (role === "admin")` literal check

The codebase has >=2 isAdminRole-like predicates that diverge. A new developer writes `includes("admin")` which
unintentionally matches `system_admin`.
**Fix:** Remove all bare literals from main code. Every privilege check calls a single named predicate (`isAdminRole()`,
`isStationAdmin()`). Code-audit lint asserts this.

### Stale docblock with inverted behavior

Docblock says "returns true if user has admin role" but the code returns `true` for non-admins.
**Fix:** Flag any change that inverts a condition and mandate a docblock update as part of the AC.

### Configuration validated in multiple places

A value is validated in a schema library (e.g., Pydantic, Zod, Joi), again in a custom check, again at the server
endpoint. One is stricter/different -- config passing place A fails place B.
**Fix:** "validate once" in a centralized config module; other layers trust it or re-validate only from untrusted
sources.

### Asymmetric error handling on paired operations

Read operation has `try/catch` that logs ERROR; write operation's catch silently continues.
**Fix:** Paired operations (read+write, request+response) have symmetric error handling.

### Implicit test ordering assumptions

Test of feature X assumes feature Y was already initialized in a separate test file that may run in any order.
**Fix:** Tests are fully independent; each sets up all preconditions in its own `beforeEach`/`beforeAll`.

### CA-513 (P1, lenses L10 + L1): the CA-476 fix hand-rolls a fence tracker three times and it diverged from the shared classifier (EDMV3, 2026-08-21, P2)

source: EDMV3
audit-type: code
date: 2026-08-21

> Extracted from the code audit for EDMV3. One-paragraph description of the finding
> and how to prevent it -- delimited stub text pending human curation; not yet curated prose.

### CA-514 (P1, lens L9): CA-416's own fix shipped two blocking refusals with zero acceptance criteria (EDMV3, 2026-08-21, P2)

source: EDMV3
audit-type: code
date: 2026-08-21

> Extracted from the code audit for EDMV3. One-paragraph description of the finding
> and how to prevent it -- delimited stub text pending human curation; not yet curated prose.

### CA-515 (P1, lens L3): CA-473's fix left `qc-shard-pass-{NN}` non-unique across waves, and the skill contradicts itself on cardinality (EDMV3, 2026-08-21, P2)

source: EDMV3
audit-type: code
date: 2026-08-21

> Extracted from the code audit for EDMV3. One-paragraph description of the finding
> and how to prevent it -- delimited stub text pending human curation; not yet curated prose.

### CA-509 (P1, lens L9): the ticket pack asserts an SRD amendment that does not exist (EDMV3, 2026-08-21, P2)

source: EDMV3
audit-type: code
date: 2026-08-21

> Extracted from the code audit for EDMV3. One-paragraph description of the finding
> and how to prevent it -- delimited stub text pending human curation; not yet curated prose.

### CA-510 (P1, lens L9): the CA-471 `round_type` gate has neither a positive nor a negative AC (EDMV3, 2026-08-21, P2)

source: EDMV3
audit-type: code
date: 2026-08-21

> Extracted from the code audit for EDMV3. One-paragraph description of the finding
> and how to prevent it -- delimited stub text pending human curation; not yet curated prose.

### CA-106 (P1, lens L9; consequence corroborated by L2 and L11): EDMV3-28 is an undelivered Must Have (EDMV3, 2026-08-21, P2)

source: EDMV3
audit-type: code
date: 2026-08-21

> Extracted from the code audit for EDMV3. One-paragraph description of the finding
> and how to prevent it -- delimited stub text pending human curation; not yet curated prose.

### CA-524 (P2, lens L4): CA-473's disjointness assertion **and its positive control** both pass on an empty extraction (EDMV3, 2026-08-21, P2)

status: pending-review
source: EDMV3
audit-type: code
date: 2026-08-21

> Extracted from the code audit for EDMV3. One-paragraph description of the finding
> and how to prevent it -- delimited stub text pending human curation; not yet curated prose.

### CA-518 (P2, lens L1): `lint:hooks-shell` prints OK for a hook it never checked (EDMV3, 2026-08-21, P2)

status: pending-review
source: EDMV3
audit-type: code
date: 2026-08-21

> Extracted from the code audit for EDMV3. One-paragraph description of the finding
> and how to prevent it -- delimited stub text pending human curation; not yet curated prose.

### CA-493 (P2, lenses L4 + L8): a blocking CI gate reports green having validated nothing (EDMV3, 2026-08-21, P2)

source: EDMV3
audit-type: code
date: 2026-08-21

> Extracted from the code audit for EDMV3. One-paragraph description of the finding
> and how to prevent it -- delimited stub text pending human curation; not yet curated prose.

### CA-481 (P2, lenses L3 + L5 + L7 + L8): the highest-corroboration finding of the round (EDMV3, 2026-08-21, P2)

source: EDMV3
audit-type: code
date: 2026-08-21

> Extracted from the code audit for EDMV3. One-paragraph description of the finding
> and how to prevent it -- delimited stub text pending human curation; not yet curated prose.

### CA-495 (P2, lens L5): a scratch tree removed on no path, leaking on the success path every run (EDMV3, 2026-08-21, P2)

source: EDMV3
audit-type: code
date: 2026-08-21

> Extracted from the code audit for EDMV3. One-paragraph description of the finding
> and how to prevent it -- delimited stub text pending human curation; not yet curated prose.

---

## Pre-Flight Checklist

Run before merging code that will undergo a code audit:

- [ ] **Privilege predicates consolidated:** Search for all inline `role ===`, `includes("admin")`,
  `includes("system_admin")`. Every one is wrapped in a named predicate function. Exceptions documented in an allowlist.
- [ ] **Trust hierarchy explicit:** If a request carries multiple role signals (DB, JWT, header), a comment states which
  is authoritative (e.g., "DB role is authoritative; JWT consulted only if DB role absent").
- [ ] **Error paths present:** For every HTTP call, DB query, and network operation, there is an explicit error handler.
  Find all `http.get`/`client.execute`/`fetch` calls; verify each has a `catch` or is wrapped in `try`.
- [ ] **Secrets never logged:** Grep `log.error(`, `console.log(`, `logger.debug(` -- none include request bodies, auth
  headers, or credential-like fields. If a log site includes `?` or `=`, verify it doesn't leak secrets.
- [ ] **Test stubs are isolated:** For every global stub or mock (`jest.mock`, `vi.stubGlobal`, `unittest.mock.patch`,
  `sinon.stub`, etc.) -- there is a matching restore/teardown in `afterAll`, `afterEach`, or a `finally` block. Run
  each test file in isolation and confirm it passes.
- [ ] **Types match across boundaries:** Verify that types for API request/response match between client and server. Run
  the contract tests or manually check call sites.
- [ ] **Constants are single-sourced:** Search for role names, magic numbers, URLs, env var names. If any appears >=2
  times in main code, extract to a const/enum and import everywhere.

---

## What Passing Code Looks Like

- All privilege checks use a **named predicate** defined once and imported everywhere -- no inline literals.
- **Trust hierarchy is documented** in a comment wherever multiple auth signals are present.
- **Error paths are explicit:** every network/IO operation has a visible catch block or the caller documents its
  error-handling contract.
- **Test setup is self-contained:** each test file runs independently; tests within a file don't leak state to each
  other.
- **Secrets never appear in logs:** grepping for `token|password|secret|key` in error-logging call sites returns only
  safe, allowlisted references (e.g., "API key missing" -- not the key value).
- **Constants are single-sourced:** role names, enums, magic numbers each have one definition; all other usages import
  from that definition.

### A verification scan matches the prose that describes the pattern it hunts, so it reports its own documentation as findings or is defeated into reporting none (EDMV4, 2026-09-02, P1)

source: EDMV4
audit-type: code
date: 2026-09-02

A check that greps for a defect pattern must not match the comments, assertion labels, or
remediation text that *describe* that pattern. This bit five times in one initiative, from four
different authors, in three distinct shapes -- it is the most reproducible defect EDMV4 found:

- **Self-defeat by exclusion.** `EDMV4-T21` AC7 scanned `${SCRIPT_DIR}/..` then filtered
  `grep -v '/tests/'`. Every result path from that unnormalized root reads `.../bin/tests/../x`,
  which contains `/tests/`, so the filter stripped the one legitimate match. It reported zero and
  failed unconditionally -- a vacuously FAILING assertion.
- **Self-match by growth.** `EDMV4-T04`'s anchoring sweep matched the literal `Sec."..."`
  placeholder inside the anchor sentences it was itself adding, so every file it fixed made the
  next scan noisier. It consumed three implementer turn budgets and was reverted unshipped.
- **Self-match by label.** `EDMV4-T42` AC1 asserts no `yaml` appears under `bin/`; its own
  assertion label contained the literal, making the AC's stated command a permanent false
  positive -- in the same file that already carried a guard against this class.
- **Over-broad subject.** The `EDMV4-T04` AC11 orphan check matched every `Sec."X"`, including
  citations to documents other than the one it validates against, reporting 28 phantom orphans.

**Prevention.** Anchor the pattern to the shape a *real* occurrence has and a description cannot:
require start-of-line position (`^[[:space:]]*# shellcheck disable=`), require the qualifying
prefix (`CLAUDE.md Sec."`), or assemble the needle at runtime so the literal never appears in
source. Normalize any path root with `pwd -P` **before** applying a path-based exclusion. Then
prove the detector fires: pair every zero-count assertion with a positive control against a
known-bad fixture, because "found 0" and "matched nothing, ever" are indistinguishable otherwise.
