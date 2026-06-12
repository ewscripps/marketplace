# QC Notes: EDMV2-T17 and EDMV2-T18

Verified: 2026-06-08
Plugin version: 1.3.0 (staging copy: plugins/edm-ai-development-staging/)

---

## EDMV2-T17: Resolve --fill-gaps contradiction

### Change made

`plugins/edm-ai-development-staging/CLAUDE.md`, "When to invoke /edm:test" section (line 244):

Before:
```
For `--fill-gaps` mode (fix only P1 gaps in an existing coverage report), pass the flag:
```

After:
```
For `--fill-gaps` mode (fill ALL gaps -- P0, P1, and P2 -- in an existing coverage report), pass the flag:
```

The test skill at `skills/test/SKILL.md:20` was left unchanged -- it is the authoritative source and
already reads: "fill ALL gaps (P0, P1, and P2)".

### AC verification

- AC-1: PASS -- CLAUDE.md now says "fill ALL gaps -- P0, P1, and P2"
- AC-2: PASS -- the phrase "fix only P1 gaps" (and any P1-only restriction) no longer appears
- AC-3: PASS -- `grep -rn 'only P1|P1 only|P1-only' CLAUDE.md skills/test/SKILL.md` returns nothing
- AC-4: PASS -- `skills/test/SKILL.md:20` is unchanged
- AC-5: PASS -- all other `--fill-gaps` references in the test skill (lines 7, 38, 165, 169, 172) consistently describe ALL-gaps semantics
- AC-6: PASS -- `grep -rn 'fill-gaps' CLAUDE.md skills/test/SKILL.md` shows matching semantics in both files

---

## EDMV2-T18: Reconcile prefix regex with documented format

### Decision: tighten regex to match documentation

The documented format in CLAUDE.md ("3-6 uppercase characters") and plugin.json
prefix_format_hint ("UPPERCASE 3-6 chars (AUTH, MIGR, TIPS)") are the intended user-facing
contract. The old regex `^[A-Z][A-Z0-9_-]{1,7}$` was more permissive (2-8 chars, allowed `_`
and `-`). Rationale for tightening: the prefix becomes part of file paths, directory names, Jira
labels, and grep patterns -- underscores and hyphens in prefixes are confusing and collision-prone.
3-6 chars is the documented, user-facing promise. This direction is recorded here as the canonical
decision (EDMV2-T18 AC-7).

### Changes made

1. `plugins/edm-ai-development-staging/bin/edm-validate-prefix:17-18`
   - Regex changed from `^[A-Z][A-Z0-9_-]{1,7}$` to `^[A-Z][A-Z0-9]{2,5}$`
   - Error message changed from "prefix must be 2-8 chars, uppercase, starting with a letter"
     to "prefix must be 3-6 uppercase alphanumeric chars, starting with a letter"

2. `plugins/edm-ai-development-staging/bin/edm-init:12`
   - Regex changed from `^[A-Z][A-Z0-9_-]{1,7}$` to `^[A-Z][A-Z0-9]{2,5}$`
   - Error message changed from "prefix must be 2-8 chars, uppercase, starting with a letter"
     to "prefix must be 3-6 uppercase alphanumeric chars, starting with a letter"

3. `plugins/edm-ai-development-staging/CLAUDE.md` -- no change needed; line 82 already reads
   "3-6 uppercase characters" and is now consistent with the regex.

4. `plugins/edm-ai-development-staging/plugin.json` -- no change needed; prefix_format_hint
   default already reads "UPPERCASE 3-6 chars (AUTH, MIGR, TIPS)" and is consistent.

### Regex anatomy: ^[A-Z][A-Z0-9]{2,5}$

- `^[A-Z]` -- first char must be an uppercase letter (A-Z)
- `[A-Z0-9]{2,5}` -- 2 to 5 more uppercase alphanumeric chars
- Total length: 3 to 6 chars
- No underscores, no hyphens, no lowercase

### Backward compatibility check

Existing corpus prefix `EDMV2` (5 chars, all uppercase alphanumeric) satisfies the new regex.
No existing in-flight initiative prefix is broken by this change.

Prefixes now rejected that were previously accepted:
- 2-char prefixes (e.g., `AB`) -- never appeared in the documented format hint
- 7-8 char prefixes (e.g., `TOOLONG7`) -- never appeared in the documented format hint
- Prefixes with `_` or `-` (e.g., `MY_INIT`, `MY-INIT`) -- never appeared in examples

### AC verification

- AC-1: PASS -- regex in edm-validate-prefix and documented format both describe 3-6 uppercase alphanumeric chars
- AC-2: PASS -- regex in edm-init:12 exactly matches regex in edm-validate-prefix:17
- AC-3: PASS -- both error messages state "3-6 uppercase alphanumeric chars"
- AC-4: PASS -- CLAUDE.md "3-6 uppercase characters" and plugin.json "UPPERCASE 3-6 chars (AUTH, MIGR, TIPS)" both agree with the regex
- AC-5: PASS -- conforming prefix `AUTH` (4 chars) accepted; non-conforming `AB` (2 chars) rejected with documented message
- AC-6: PASS -- `EDMV2` (existing corpus prefix) still valid under new regex
- AC-7: PASS -- decision to tighten regex to docs is recorded above
