# SRD Audit Patterns

**Source:** EDM seed corpus (16 real-world initiatives).
**Auto-updated** by the SRD audit phase's own skill (`skills/audit-srd/SKILL.md`) via `edm-state update-patterns` after each round (EDMV2-80a; EDMV3-T37).

---

## Top Recurring Findings

Frequency: [x/16] = appeared in x of 16 audited initiatives.

| # | Pattern | Frequency | Typical severity |
|---|---------|-----------|-----------------|
| 1 | Factual/data-model contradictions | 12/16 | P0-P1 |
| 2 | Specification ambiguity (OR/AND, silent failure modes) | 11/16 | P0-P1 |
| 3 | Competing or missing requirements | 10/16 | P0 |
| 4 | Diagram inconsistencies with prose | 9/16 | P1 |
| 5 | Security / data-corruption risks missed | 8/16 | P0 |
| 6 | API contract mismatches | 7/16 | P1 |

### 1. Factual/data-model contradictions (12/16)
- Conflicting default values -- same TTL or column size specified differently in two sections
- Env var naming inconsistencies (`SERVICE_URL` vs `API_BASE_URL`; missing framework-required prefix such as `VITE_` or `NEXT_PUBLIC_`)
- Line-number references off by 5-50 lines from actual source

### 2. Specification ambiguity (11/16)
- `OR` vs `AND` logic unspecified (e.g., "bypass if A or B or C" without precedence)
- Silent-vs-loud failure modes -- "graceful degrade" left undefined (drop requests, log, or queue?)
- Empty-vs-null / zero-vs-omit distinctions not formalized
- Flag-off byte-identity requirement stated but no AC asserts it

### 3. Competing / missing requirements (10/16)
- Two requirements cannot both be satisfied simultaneously
- Pre-conditions stated in narrative prose but never mandated as a numbered requirement
- Feature gaps: requirement assumes another requirement exists without citing it
- Migration ordering constraints stated informally, not enforced in ACs

### 4. Diagram inconsistencies with prose (9/16)
- Sequence diagram shows eager fetches; prose says lazy
- Mermaid graph omits error-handling edges
- Flow shows step X before Y; numbered prose says Y before X
- Missing nodes/participants in architecture diagrams

### 5. Security / data-corruption risks (8/16)
- Open redirects not validated
- Destructive default -- `conflictBehavior: "replace"` silently deletes folder contents
- Secrets never documented as being persisted to disk
- Token/credential handling unspecified (e.g., header never removed from logs)

### 6. API contract mismatches (7/16)
- Response shape contradictions (array vs paged object with `totalCount`)
- Status-code ambiguity (202 vs 200 for create vs upsert)
- Missing error-code taxonomy (409 vs 422 for uniqueness violations)
- Endpoint path inconsistencies (`/a2a` vs `/gateways` for the same operation)

---

## Anti-Patterns

### Copy-paste constant misalignment
Same enum/role/tier value exists in 3+ files without a single source of truth. Two files agree, one drifts (e.g., `system_admin=3` in roles.ts vs stale `system_admin=2` in constants.sql).
**Fix:** "define once, import three places" rule enforced in AC.

### Default-off invariant violations
Requirement states "with all flags off, byte-identical to baseline" but introduces a new column/logic that can't be disabled (e.g., pooled session, triage feature).
**Fix:** Explicit AC for every flag-gated requirement: "on `ENABLE_X=false`, this code path is bypassed entirely."

### Stale migration numbering
SRD says "migration 012-016" but actual files are 015-019; a companion document uses the old numbers.
**Fix:** Enumerate migration filenames in Sec.6, not ranges; companion docs link to SRD as canonical.

### Hidden schema blockers
Requirement assumes a schema change (e.g., `UNIQUE(name, call_letters)`) but never explicitly mandates a migration. Implementer writes code, then discovers the old `UNIQUE(name)` constraint blocks the insert.
**Fix:** Explicit pre-requisite block in Sec.6: "Before R31 implementation, migration 037 must drop `people_name_key` and add `uq_people_name_station`."

### Silent failure modes
When a flag is off, do you (a) silently skip, (b) log INFO, (c) log WARN, or (d) throw? "Graceful degrade" used without definition.
**Fix:** Enumerate all outcome branches per requirement.

### Qualitative performance claims
"Typical operator workstation" maps to 0.5-8 vCPU -- too wide to be testable.
**Fix:** `MUST complete in <=200 seconds on a 4-vCPU instance with 100 Mbps network and a pre-warmed cache.`

### Literal semicolon inside a Mermaid label
A diagram's node, edge or message label contains a raw `;` (e.g., `A[Wait; then retry] --> B`). Mermaid reserves `;` as a lexer-level statement separator even inside label text, so the diagram breaks or silently mis-renders.
**Fix:** Use the `#59;` entity code instead of a raw semicolon (see `CLAUDE.md Sec."Mermaid diagram conventions"`); flag any raw `;` found inside `[...]`, `(...)`, `{...}`, `|...|`, `"..."`, or after the `:` in a `sequenceDiagram` message.

### A constraint spanning two requirements was written as a peer dependency of both, creating a cycle that dependency-ordered wave scheduling cannot resolve, and the constraint is the element most likely to be silently dropped when a tool breaks the cycle (EDMV4, 2026-08-31, P2)

status: pending-review
source: EDMV4
audit-type: srd
date: 2026-08-31

> Extracted from the srd audit for EDMV4. One-paragraph description of the finding
> and how to prevent it -- delimited stub text pending human curation; not yet curated prose.

### A replacement derivation was specified unconditionally against a function that has two branches, so the branch the spec did not consider inverts its result and every default invocation returns the opposite verdict (EDMV4, 2026-08-31, P2)

status: pending-review
source: EDMV4
audit-type: srd
date: 2026-08-31

> Extracted from the srd audit for EDMV4. One-paragraph description of the finding
> and how to prevent it -- delimited stub text pending human curation; not yet curated prose.

### A completeness gate was re-pointed from a manifest to a state field that is empty in the default case, making the gate vacuous for exactly the incident that motivated building it (EDMV4, 2026-08-31, P2)

status: pending-review
source: EDMV4
audit-type: srd
date: 2026-08-31

> Extracted from the srd audit for EDMV4. One-paragraph description of the finding
> and how to prevent it -- delimited stub text pending human curation; not yet curated prose.

### An SRD premise describing repository state went stale mid-phase when the branch it described was updated underneath the document (EDMV4, 2026-08-31, P2)

status: pending-review
source: EDMV4
audit-type: srd
date: 2026-08-31

> Extracted from the srd audit for EDMV4. One-paragraph description of the finding
> and how to prevent it -- delimited stub text pending human curation; not yet curated prose.

### An acceptance criterion required updating a counting assertion that does not exist, making it vacuously satisfiable -- an implementer finds nothing to change, ticks the box, and the new surface ships with zero coverage (EDMV4, 2026-08-31, P2)

status: pending-review
source: EDMV4
audit-type: srd
date: 2026-08-31

> Extracted from the srd audit for EDMV4. One-paragraph description of the finding
> and how to prevent it -- delimited stub text pending human curation; not yet curated prose.

### A lint sweep was cited as covering shell scripts, but the collector globs only markdown, so no script was ever scanned by the mechanism the AC named (EDMV4, 2026-08-31, P2)

status: pending-review
source: EDMV4
audit-type: srd
date: 2026-08-31

> Extracted from the srd audit for EDMV4. One-paragraph description of the finding
> and how to prevent it -- delimited stub text pending human curation; not yet curated prose.

### A design cited an in-repo precedent that on inspection had different element types than the shape being proposed, so the claimed precedent did not support the design (EDMV4, 2026-08-31, P2)

status: pending-review
source: EDMV4
audit-type: srd
date: 2026-08-31

> Extracted from the srd audit for EDMV4. One-paragraph description of the finding
> and how to prevent it -- delimited stub text pending human curation; not yet curated prose.

### An anti-regression assertion counts a hardcoded name list rather than the live set, so it stays green while newly added members silently escape the property it exists to enforce (EDMV4, 2026-08-31, P2)

status: pending-review
source: EDMV4
audit-type: srd
date: 2026-08-31

> Extracted from the srd audit for EDMV4. One-paragraph description of the finding
> and how to prevent it -- delimited stub text pending human curation; not yet curated prose.

### A dormant licence obligation was wired to the wrong ratification decision, so approving the named requirement while separately reversing the underlying architecture decision would leave the obligation dormant (EDMV4, 2026-08-31, P2)

status: pending-review
source: EDMV4
audit-type: srd
date: 2026-08-31

> Extracted from the srd audit for EDMV4. One-paragraph description of the finding
> and how to prevent it -- delimited stub text pending human curation; not yet curated prose.

### Cross-document references keyed to line numbers went stale four to seven lines within a single initiative because the target file was edited mid-flight, including a do-not-touch list that then pointed at unrelated text (EDMV4, 2026-08-31, P2)

status: pending-review
source: EDMV4
audit-type: srd
date: 2026-08-31

> Extracted from the srd audit for EDMV4. One-paragraph description of the finding
> and how to prevent it -- delimited stub text pending human curation; not yet curated prose.

### A read-only verifier agent's turn budget sits below the producer agent whose output it checks, so on a large artifact it truncates before emitting findings, and a hook-spawned verifier's partial output is merged as if complete (EDMV4, 2026-08-31, P2)

status: pending-review
source: EDMV4
audit-type: srd
date: 2026-08-31

> Extracted from the srd audit for EDMV4. One-paragraph description of the finding
> and how to prevent it -- delimited stub text pending human curation; not yet curated prose.

---

## Pre-Flight Checklist

Run before submitting an SRD to audit:

- [ ] **Data model consistency:** Every numeric/string value that appears >=2 times in the SRD matches exactly across all occurrences. Spot-check 5 cross-references.
- [ ] **Diagram walkthrough:** Step through each Mermaid sequence diagram vs. the corresponding prose. Verify every numbered step appears in both. Check error edges (catch blocks, retries, 5xx paths).
- [ ] **Competing requirements scan:** Search for `must` + `must not` pairs that contradict. For each, add a Sec.7 Design Decision explaining the chosen trade-off.
- [ ] **Flag-off parity clause:** For every feature flag, add a line: `"With [FLAG]=false, this behavior is disabled entirely. See NFR-X for the byte-identity requirement."`
- [ ] **Migration envelope:** For any schema changes, Sec.6 enumerates the exact migration filename (not a range). Include a "Prerequisites" row if a prior migration must run first.
- [ ] **API error codes complete:** Grep for `[1-5]\d\d` -- every HTTP status code found in prose must appear in the Sec.8 status-code table.
- [ ] **Secret/security anchor:** For every secret/token/credential, verify it appears in Sec.7 Risk and has a documented mitigation. Grep `password|secret|key|token|credential|jwt|api_key`.
- [ ] **Line-number freshness:** For any `path:line` reference, verify against current source (allow +/-2 lines; +/-10 is a finding).
- [ ] **Mermaid semicolon scan:** Grep every diagram fence for a raw `;` inside label/edge/message text; per `CLAUDE.md Sec."Mermaid diagram conventions"` it must be the `#59;` entity code instead.

---

## What a Passing First Draft Looks Like

- All data values (enums, numbers, timings) are **defined once** in a glossary or data-model section and cited by name elsewhere -- never re-stated inline with a different value.
- Diagrams **include error paths** (5xx, timeouts, malformed input) with explicit edge labels.
- Every requirement has an **acceptance criteria block** with >=1 testable assertion. Pure `MUST` prose without criteria is incomplete.
- Contradictions are **explicitly called out in Sec.7 Design Decisions** with a reasoned choice and mitigations listed.
- For any new column/table, an AC **asserts the migration is idempotent** (running it twice does not corrupt data).
- Sequence diagrams include **every HTTP request/response**, including error cases and retries.
