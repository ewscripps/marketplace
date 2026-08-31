# Lens L10: DRY & Redundancy -- Pass 4 (2026-08-08)

## Ledger verdicts (every open entry whose Lens(es) column includes L10)

Five open ledger entries carry L10. **All five are now RESOLVED.**

| ID | Sev | Verdict | Evidence |
|---|---|---|---|
| CA-019 | P1 | **RESOLVED** | Shared awk rule file loaded via `-f`; private clone gone; CI ban added; ignore-marker carve-out documented. |
| CA-049 | P2 | **RESOLVED** | `harness_scratch_dir`/`_HARNESS_PLUGIN_DIR`/`_HARNESS_REPO_ROOT` all have real callers; duplicated preambles gone. |
| CA-094 | P2 | **RESOLVED** (one residual -> Finding 6) | All six named sites converted to `$WAVE7_GRANTS_EXIT` with freshness guard. |
| CA-156 | P2 | **RESOLVED** | `project_class` is the only `$2==<class>` filter; seven former parsers route through it. |
| CA-244 | P2 | **RESOLVED** | `_save_traps`/`_restore_traps`/`_write_atomic_unwind` collapse six repeated blocks into one call each. |

## Findings

| # | Sev | Conf | Type | Canonical | Recommendation |
|---|---|---|---|---|---|
| 1 | P2 | high | Byte-identical block x2 | one `_TOKEN_SUM_JQ` string | Hoist the two identical jq programs in `get_session_tokens_since` (`edm-state:341-364`/`:383-406`) into one variable; the only difference is already `--arg mode`. |
| 2 | P2 | high | Copy-pasted block x2 | new `_unpack_token_fields` | Extract the 14-line token-unpack block duplicated between `cmd_phase_complete` (`:2042-2055`) and `_cmd_audit_round_complete_body` (`:3661-3674`). |
| 3 | P2 | high | Copy-pasted block x3 | one shared tail | Extract the retry-accounting tail duplicated three times in `with_state_lock` (`:1062-1067`,`:1080-1085`,`:1088-1092`); the comment already calls it "the shared retry accounting". |
| 4 | P2 | medium | Same check twice | route through `edm-state` | The five UserPromptExpansion prompt hooks reimplement `cmd_gate_check`'s mapping in prose with none of its mode/skipped-phase refinements. |
| 5 | P2 | high | Copy-pasted loop x9 | new `_measure_p95` | `timing.sh`'s p95 sample loop is hand-repeated nine times; CA-196's sample-count fix needs nine synchronized edits. |
| 6 | P2 | high | CA-094 residual | hoist above T03 | A duplicate whole-tree `edm-check-grants` run survives at `wave7-smoke.sh:232`; the hoisted capture's own comment at `:1274-1275` falsely claims it is the earliest point that needs it. |
| 7 | P2 | low | Forked jq renderers x3 | parameterize columns | `cmd_metrics_report`'s baseline/non-baseline renderer pairs fork whole expressions where most columns are identical. |
| 8 | P2 | low | Copy-pasted phase blocks x3 | new `run_phase` | `run-eval.sh`'s three phase blocks are copy-pasted and already drifted structurally on where `PHASEn_OK=false` is set. |

## Noted / Not Actionable

1. `mermaid_line_set`/`marker_line_set` still have zero callers but the docstring now states that
   honestly (CA-200's territory, not an L10 duplicate).
2. Two `_harness.sh` sourcing shapes coexist; both sanctioned per the documented usage.
3. CA-019's CI ban has no smoke-suite twin (L7's territory).
4. CA-193's restated lens JSONL schema is byte-identical across all twelve copies; documented as intentional.
5. The five prompt hooks vs command hooks -- command hooks are near-identical but delegate to one binary; nothing to factor.
6. `edm-check-skill-sync` still hand-rolls its counter; dependency would exist for one 8-line function.
7. `cmd_set_supersedes`/`cmd_set_forked_from` near-identical thin CLI arms; factoring would obscure usage strings.
8. `cmd_compare` (evals) as a second comparison implementation is CA-120, already demoted.
9. `die()` multiple shapes is CA-074 (L7), not re-reported here.
10. `mermaid_fence_run_len`/`mermaid_fence_rest` each de-indent independently; factoring buys nothing.

## Meta

`Write` was absent from this lens's delivered runtime tool set (ledger CA-130, fourth consecutive
round at time of this lens's run). Separately, the delivered *system prompt* was an older
revision missing `## Scope`, `## Output`, `## JSONL Line Format` sections and using the
pre-CA-165 output-table shape; the JSONL schema below was read off the on-disk agent definition.
Both `lens-L10.md` and `lens-L10.jsonl` were transcribed by the orchestrator.
