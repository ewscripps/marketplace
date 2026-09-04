# Instance profile: Scripps (LAFF / Bounce / GRIT)

**Not instructions.** This file is data read by `/ada-health`. Every ID below must be re-resolved via `list_entities` in the run that uses it.

| Field | Value |
|---|---|
| Instance | `scripps.ada.support` |
| MCP server | `ada-scripps` (tool prefix `mcp__ada-scripps__`) |
| Token env var | `SCRIPPS_ADA_API_TOKEN` |
| Dashboard | `https://scripps.ada.support` |
| Minimum-N floor | 20 (default — see Volume) |

## Volume — read this before reporting anything

Three brands share one instance. Volume has grown: through August 2026 a 48-hour window often held **zero** real conversations, but as of 2026-09-04 a 2-day window measures 25-33 engaged. Re-check rather than assuming either figure.

Consequence: this instance sits near the readability boundary. Rate deltas will often trip the numerator guard — at n=25 a 50-point AR swing is a couple of conversations — so expect rate findings to be demoted to observations more often than on a high-volume instance. Absolute-count findings still work at any volume: a 5xx, a reverted changeset, a raw handoff count. What must never happen is reporting a quiet window as a clean pass.

Test conversations are excluded by default. Do not add the `ISTESTUSER` filter.

## Partition: brand isolation

Three near-identical brand configs share one instance with no hard gate on playbook routing. Isolation depends on availability rules keyed to the recipient address. A misroute is silent — nothing errors, the agent just answers with the wrong brand's content.

Partition variable `email_recipient_address` — resolve its ID via `list_entities(entity_type="variables")`; last known `6a4e5ee0e22a4cd79777b9a4`.

| Brand | BYOD address | Native address |
|---|---|---|
| LAFF | `support@help.laff.com` | `help2@scripps.email.ada.support` |
| Bounce | `support@help.bouncetv.com` | `help3@scripps.email.ada.support` |
| GRIT | `support@help.grittv.com` | `help4@scripps.email.ada.support` |

To slice a metric by brand, add a `VARIABLE` filter with `item` set to that variable's resolved ID and `value` set to the brand's address.

Last known handoff IDs — **resolve before use**: LAFF `6a4e9bdf30ec24a08c4b9b2a`, Bounce `6a4e9cd8b99ba2639798dd55`, GRIT `6a4e590f3999d9eff00ec9ac`.

## Known AR classification backlog, from 2026-08-31

Email classification coverage fell 100% -> 74% -> 36% -> 29% across 08-31 to 09-04, so the reported 0.0% email AR is an artifact of an incomplete, `Not Resolved`-biased sample rather than a real decline. Baseline email AR here is 55-77%.

This instance had promoted no changeset since 2026-08-19, and the identical pattern appears on the unrelated Tablo tenant, which places the cause on Ada's side rather than in local config. Use the skill's Step 3 coverage gate; do not quote email AR for this period.

## Expected escalation reasons

Not a spike when the reason is: explicit agent request · closed captions · non-programming technical issue · engineering-level technical report · sports event question (Bounce). Anything outside this set is worth a drill-down.

## What this skill does not cover here

Ticket-level verification — that a handoff produced exactly one Freshdesk ticket on the right product, group, and type — is **out of scope**. It needs full transcripts plus Freshdesk, which is outside Ada entirely. Legacy-instance leakage checks against `laffcs`, `bouncecs`, and `gritcs` need each configured as its own MCP server.

Both live in `Obsidian/Projects/Ada-Freshdesk-Integration/notes/PostConsolidation-HealthCheck.md`, which remains the procedure for consolidation-specific verification. `/ada-health` complements it; it does not replace it.
