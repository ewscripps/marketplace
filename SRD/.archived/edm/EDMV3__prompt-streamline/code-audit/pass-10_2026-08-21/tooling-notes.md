Round 10 tooling degradation (CA-130 / CA-388)

All 11 lenses (L1-L11) were delivered without the `Write` tool this round, despite the frontmatter grant on each `agents/edm-audit-*.md` definition -- the standing CA-130 stale-plugin-cache condition, now reproduced for an 8th-11th consecutive round depending on lens (each lens's own report states its own count). L3 and L9 additionally reported no `Bash`. Consequence: no lens could persist its own `lens-L{N}.md`/`.jsonl`; every lens returned both halves inline in its final chat message, and the orchestrator persisted them verbatim (fixing only HTML-entity transport artifacts -- `&amp;`/`&gt;`/`&lt;` back to `&`/`>`/`<` -- introduced by the notification transport layer, not by the lenses themselves).

Additionally, on the first resume attempt after each lens's initial (incomplete) response, 10 of the 11 lenses (all except L1) failed with "You've hit your individual spend limit" and had to be resumed a second time after the limit reset before delivering their final report. No content was lost -- each lens picked up from its own prior context and delivered a complete report on the successful resume -- but round 10's wall-clock cost was roughly double a normal round because of this.

Per-lens tool set actually delivered (as self-reported):
- L1: Read, Grep, Glob, WebFetch, WebSearch, TaskStop (no Bash, no Write)
- L2: Read, Grep, Glob, WebFetch, WebSearch, TaskStop (no Bash, no Write)
- L3: explicitly stated no Write and no Bash
- L4: no Write, no Bash
- L5: no Write tool available (Bash status not explicitly stated; report is static/read-only throughout)
- L6: no Write, Edit, or Bash
- L7: no Write, no Bash (11th consecutive round per lens's own count)
- L8: no Write in delivered tool set; report notes the delivered agent definition also lacked a `## JSONL Line Format` section, so the prompt-supplied fallback schema (D22/CA-130) was used
- L9: explicitly stated no Write, Edit, or Bash
- L10: no Write, Edit, or Bash (11th consecutive round per lens's own count)
- L11: no Bash, no Write

No lens's findings were suppressed or truncated because of this -- each lens completed its full mandate and returned complete markdown + JSONL content in its final message. This note exists solely to make the degradation countable per `skills/code-audit/SKILL.md` step 8b, and to flag CA-130 as still unresolved at the tooling/plugin-delivery layer after this many consecutive rounds.
