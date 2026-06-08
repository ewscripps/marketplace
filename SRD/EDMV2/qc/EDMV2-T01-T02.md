# QC Note: EDMV2-T01 and EDMV2-T02

**Date verified**: 2026-06-08
**Plugin version**: edm-ai-development-staging (working toward v1.4.0)
**Verified by**: Phase 6 implementation agent (EDMV2 Wave 1)

---

## EDMV2-T01: Grant Write to edm-test-coverage-auditor

### What was changed

`agents/edm-test-coverage-auditor.md` frontmatter lines 8-9:

- **Before**: `tools: Read, Bash, Glob, Grep, TodoWrite` / `disallowedTools: Write, Edit, NotebookEdit`
- **After**: `tools: Read, Write, Bash, Glob, Grep, TodoWrite` / `disallowedTools: Edit, NotebookEdit`

`CLAUDE.md` Testing layer section (line ~199):

- **Before**: `edm-test-coverage-auditor has disallowedTools: Write, Edit, NotebookEdit`
- **After**: `edm-test-coverage-auditor has tools: Write (to write test-coverage.md) and disallowedTools: Edit, NotebookEdit`

### QC auditor verification steps

1. Run:
   ```bash
   grep '^tools:' agents/edm-test-coverage-auditor.md
   grep '^disallowedTools:' agents/edm-test-coverage-auditor.md
   ```
2. Assert: `tools:` line contains the token `Write`.
3. Assert: `disallowedTools:` line does NOT contain the token `Write`.
4. Assert: `disallowedTools:` line still contains `Edit` and `NotebookEdit`.
5. Confirm no other frontmatter field (`name`, `description`, `model`, `effort`, `maxTurns`, `color`) was altered.
6. Confirm the agent body still references `SRD/{PREFIX}/test-coverage.md` as the output target (Step 4 of the agent body).

**Expected grep output (pass state):**
```
tools: Read, Write, Bash, Glob, Grep, TodoWrite
disallowedTools: Edit, NotebookEdit
```

---

## EDMV2-T02: Coverage-auditor write-permission regression check

### What was changed

`skills/implement/SKILL.md` Step 7 (Declare Done) checklist gained a new checklist item:

- The item instructs the implementer to run two grep commands against `agents/edm-test-coverage-auditor.md`
  and verify the pass/fail conditions before declaring Phase 6 complete.
- The check is labeled `EDMV2-02 regression guard` so it is traceable.

### QC auditor verification steps

1. Run:
   ```bash
   grep -A15 'Step 7: Declare Done' skills/implement/SKILL.md
   ```
2. Assert: the output includes a checklist item referencing `EDMV2-02 regression guard`.
3. Assert: the item includes exact commands:
   ```bash
   grep '^tools:' agents/edm-test-coverage-auditor.md
   grep '^disallowedTools:' agents/edm-test-coverage-auditor.md
   ```
4. Assert: the pass and fail conditions are documented in the checklist item.

### Positive control (check passes with fix in place)

Run the commands specified in the checklist item against the current agent file:
```bash
grep '^tools:' agents/edm-test-coverage-auditor.md
# Expected: tools: Read, Write, Bash, Glob, Grep, TodoWrite   <- contains Write
grep '^disallowedTools:' agents/edm-test-coverage-auditor.md
# Expected: disallowedTools: Edit, NotebookEdit               <- does NOT contain Write
```
Result: PASS (Write is in tools, absent from disallowedTools).

### Negative control (check fails if regression is introduced)

If `Write` is moved back to `disallowedTools:` (the G1 regression), the commands produce:
```bash
grep '^tools:' agents/edm-test-coverage-auditor.md
# tools: Read, Bash, Glob, Grep, TodoWrite                    <- Write absent
grep '^tools:' agents/edm-test-coverage-auditor.md
# disallowedTools: Write, Edit, NotebookEdit                  <- Write present
```
Result: FAIL (the checklist item blocks declaring Phase 6 done until fixed).

This confirms the regression guard detects the G1 defect and is not a no-op check.
