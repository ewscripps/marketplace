# QC Note: EDMV2-T07 and EDMV2-T22

Date: 2026-06-08
Plugin version under test: 1.3.0 (staging copy)
Implementer: Claude Sonnet 4.6

---

## EDMV2-T07: Remove or fulfill the CHANGELOG example-block claim

**Resolution path taken:** Remove (not fulfill).

**Verification:**
- `grep -c '<example>' agents/*.md` returns 0 for all 30 agents (confirmed before change).
- The false claim "All agents have proper `<example>` blocks in their `description` fields per the canonical spec." was removed from `CHANGELOG.md` line 154.
- `grep -ri 'example.*block' CHANGELOG.md` returns nothing after the change.
- `grep -i '<example>' CHANGELOG.md` returns nothing after the change.
- The surrounding CHANGELOG entry remains grammatical; the 1.0.0 Agents section still reads coherently.
- No other CHANGELOG entry was modified.

**AC status:**
- AC-1: PASS -- state is internally consistent (no agents have blocks, no text claims they do).
- AC-2: PASS -- no surviving sentence asserting all agents contain `<example>` blocks.
- AC-3: PASS -- surrounding bullet list is grammatical; 1.0.0 entry reads coherently.
- AC-4: N/A -- fulfillment path not taken.
- AC-5: PASS -- resolution recorded here and in commit message (EDMV2-T07).
- AC-6: PASS -- no other CHANGELOG entry's factual content was altered.

---

## EDMV2-T22: De-duplicate plugin.json and fix README install paths

**Files changed:**
- `plugins/edm-ai-development-staging/.claude-plugin/plugin.json` -- retained as sole authoritative manifest.
- `plugins/edm-ai-development-staging/plugin.json` -- deleted (was byte-identical duplicate, confirmed with diff).
- `plugins/edm-ai-development-staging/README.md` lines 11 and 14 -- stale install paths updated.

**Verification:**
- `diff plugin.json .claude-plugin/plugin.json` returned empty (byte-identical) before removal.
- Root-level `plugin.json` deleted; `.claude-plugin/plugin.json` is the only manifest.
- README install path changed from `/Users/darryl.porter/projects/scripps-mcp/edm-plugin` to `./plugins/edm-ai-development`.
- README dev-mode path changed from same stale value to `./plugins/edm-ai-development`.
- `grep -n 'scripps-mcp' README.md` returns nothing after the change.
- `marketplace.json` (repo root) references `./plugins/edm-ai-development` as the source path -- unaffected by this change, still correct.

**Decision on canonical manifest location:** `.claude-plugin/plugin.json` is authoritative per the Claude Code plugin spec (the `.claude-plugin/` directory is the spec-defined plugin root for manifest and config). The root-level `plugin.json` had no spec basis and was removed.

**AC status:**
- AC-1: PASS -- exactly one authoritative manifest; duplicate removed.
- AC-2: PASS -- version bumps need only edit `.claude-plugin/plugin.json`.
- AC-3: PASS -- README install command now uses `./plugins/edm-ai-development`, which exists in the repo.
- AC-4: PASS -- README dev-mode command likewise corrected.
- AC-5: PASS -- no README install/usage example references a non-existent directory.
- AC-6: Not testable in staging (requires `claude plugin validate` tool access), but manifest JSON is well-formed and schema-valid per its `$schema` reference.
- AC-7: PASS -- canonical decision recorded in commit message and this QC note.
- AC-8: PASS -- `marketplace.json` source path `./plugins/edm-ai-development` is unchanged and correct.

---

## Overall QC verdict

Both tickets: PASS. Changes are minimal and targeted; no regressions introduced.
