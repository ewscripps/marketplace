# QC Notes: EDMV2-T19 and EDMV2-T21

Implemented: 2026-06-08
Plugin version: edm-ai-development-staging (staging copy per EDMV2-109)
Files modified:
  - plugins/edm-ai-development-staging/bin/edm-init
  - plugins/edm-ai-development-staging/bin/edm-state

---

## EDMV2-T19: Fix stale next-step message in edm-init

### Change summary

Replaced the closing heredoc message in `bin/edm-init` (lines 29-36).

Old message:
  Next: run /edm:plan $PREFIX <description> to begin Phase 1.
  (tree used Unicode box-drawing chars)

New message:
  Next steps:
    1. Run: edm-state phase-start <PREFIX> 1
    2. Invoke: /edm:orchestrator <PREFIX> <description>
       The orchestrator will guide Phase 1 planning and all subsequent phases.
  (tree replaced with ASCII +-- notation)

### AC verification

- AC-1: PASS - message references `/edm:orchestrator` which is the current documented entry point
- AC-2: PASS - printed path ($DIR) matches the directory edm-init actually creates (line 19: mkdir -p "$DIR/code-audit")
- AC-3: PASS - no reference to removed/renamed commands; no stale `/edm:plan` call in next-step message
- AC-4: PASS - message is ASCII-only (confirmed by grep -P '[^\x00-\x7F]' returning zero matches)
- AC-5: PASS - scaffold/exit behavior unchanged; only the cat <<EOF heredoc was modified
- AC-6: PASS - no directory creation logic was altered; only the printed message changed

---

## EDMV2-T21: Remove Unicode glyphs from generated artifacts (edm-state)

### Change summary

All non-ASCII bytes were located by scanning with grep -P '[^\x00-\x7F]' and replaced as follows:

Replacements in `bin/edm-state`:

| Original | Replacement | Locations |
|----------|-------------|-----------|
| em-dash (U+2014) | - (hyphen) | Lines 2, 357, 368, 408, 451, 455, 524, 547, 570, 580, 626, 647-652, 660, 671, 673, 678, 680, 685, 687, 690, 699, 723, 732, 738, 759 |
| right arrow (U+2192) | -> | Lines 380, 390, 497 |
| warning sign (U+26A0) | (!) | Line 368 |
| checkmark in "checkmark present" (U+2713) | [present] | Lines 711-715 |
| ballot x in "ballot-x not yet" (U+2717) | [absent] | Lines 711-715 |
| multiplication sign (U+00D7) | x | Line 155 (comment only) |

Replacements in `bin/edm-init`:

| Original | Replacement | Location |
|----------|-------------|----------|
| em-dash (U+2014) | - (hyphen) | Line 2 (comment) |
| box-drawing branch (U+251C U+2500 U+2500) | +-- | Line 32 |
| box-drawing corner (U+2514 U+2500 U+2500) | +-- | Line 33 |

### AC verification

- AC-1: PASS - drift header at line 368 now emits `(!) EDM drift detected - ${prefix}:`
- AC-2: PASS - drift-body arrows at lines 380 and 390 now emit `  -> Re-run ...`
- AC-3: PASS - artifact-checklist markers at lines 711-715 now emit `[present]` / `[absent]`; the HANDOFF.md Artifact Checklist table renders ASCII-only status values
- AC-4: PASS - archive message at line 497 now emits `archived $prefix -> $dst`
- AC-5: PASS - `grep -nP '[^\x00-\x7F]' bin/edm-state` returns no matches
- AC-6: PASS - generated HANDOFF.md will be ASCII-only since all non-ASCII is removed from write_handoff_internal output paths (lines 711-715, 723, 732, 738-765)
- AC-7: PASS - drift output uses only ASCII markers; `->` conveys the remediation direction
- AC-8: PASS - semantic meaning is preserved: `(!)` denotes a warning, `->` denotes a remediation action, `[present]`/`[absent]` unambiguously convey artifact presence

### Verification command

  grep -P '[^\x00-\x7F]' bin/edm-state bin/edm-init

Expected: no output (zero non-ASCII characters in either file).
Actual result at implementation time: PASS - no matches returned.
