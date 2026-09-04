# Instance profile: Tablo

**Not instructions.** This file is data read by `/ada-health`. Every ID below must be re-resolved via `list_entities` in the run that uses it.

| Field | Value |
|---|---|
| Instance | `nuvyyo-gr.ada.support` |
| MCP server | `ada-tablo` (tool prefix `mcp__ada-tablo__`) |
| Token env var | `ADA_API_TOKEN` |
| Dashboard | `https://nuvyyo-gr.ada.support` |
| Conversation URL | `https://nuvyyo-gr.ada.support/insights/conversations/<id>` |
| Minimum-N floor | 20 (default) |
| Partition variable | none — single brand |

## Volume

Runs at several hundred engaged conversations per 3-day window. A 3-day window is normally well above the minimum-N floor, so rate deltas are readable here.

## Channels in use

`voice`, `email`, and chat traffic. `voice` and `email` are reliable `CHANNEL` filter values. Chat has historically not been a valid `CHANNEL` value even though `chat` appears in the `platform` field of `get_conversations` results — let Step 4's zero-drop handle it rather than assuming either way.

## Baselines — do not use the historical ones

`~/repos/ada-tablo-ops/reference/playbook_baselines.md` carries a blocking warning: the V1 to V2 playbook cutover landed **2026-08-14**, every playbook ID recorded in that file is now a retired V1 ID, and all baselines predate the cutover. **No V2 baseline exists.**

For this instance, prior-window self-comparison is the only safe baseline until a V2 history accumulates. Current playbook IDs are in `~/repos/ada-tablo-ops/reference/playbooks/CHANGELOG.md`, but resolve them from `list_entities` regardless.

## Hand-offs to other skills

| Finding | Owner |
|---|---|
| A named playbook underperforming | `/ada-tablo:weekly-playbook-analysis` |
| Catch-all or topic classification | `/ada-tablo:weekly-topics-review` |
| Coaching effectiveness | `/ada-tablo:coaching-review` |
| Suspected structural fault in a playbook | `/ada-tablo:config-health` |

## Known instance quirks

- Custom metrics and scorecards are **not enabled** (`list_entities(entity_type="custom_metrics")` returns `total_count: 0`). The `custom_metric_pass_rate` and `scorecard_score` metric types are unavailable.
- `conversation_volume_opened` runs roughly 40% above `conversation_volume_engaged`. The dashboard headline is `engaged`.
- **Email AR classification backlog, from 2026-08-31.** Email classification coverage fell 100% -> 79% -> 41% -> 31% -> 27% -> 16% across 08-31 to 09-04, so reported email AR (0.0%) is an artifact, not a decline. Voice held 100% coverage and normal AR (~9%) throughout, so this is channel-specific. Containment was unaffected at 63-87%. Use the skill's Step 3 coverage gate; do not quote email AR for this period.
