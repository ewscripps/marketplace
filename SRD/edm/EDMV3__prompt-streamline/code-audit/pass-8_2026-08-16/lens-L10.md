# Lens L10: DRY & Redundancy -- Pass 8 (2026-08-16)

**Tooling note (CA-130's class, ninth consecutive round):** Write/Edit/Bash absent from this
lens's delivered runtime tool set. Transcribed by the orchestrator from the lens agent's final
message. Bash absence again meant no `diff`/`sort`/`uniq` and no ability to execute the
commands under comparison -- every comparison below is by `Read` and `Grep`. Newly confirmed
this round: `pass-6/lens-L10.jsonl` and `pass-7/lens-L10.jsonl` were never written to disk.
Round 5 is the last round this lens produced its authoritative artifact. CA-331 is a
precondition, not a nicety.

## Ledger verdicts on prior L10-attributed findings

| ID | Sev | Verdict this round |
|---|---|---|
| **CA-344** | P2 | **STILL OPEN -- all five sub-parts individually re-verified present, none diverged.** |
| **CA-417** | P2 | **STILL OPEN -- both un-converted callers survive; docstring undercount survives.** Round 7's own CA-389 fix edited the line immediately below one of them without converting it. |
| **CA-418** | P2 | **STILL OPEN -- four header copies in two mechanisms, visibly divergent.** |
| **CA-419** | P2 | **STILL OPEN -- both halves (7-line twin, HANDOFF-refresh asymmetry).** |
| **CA-420** | P2 | **STILL OPEN -- both case patterns still hand-encoded; overclaiming comment unchanged.** |
| **CA-383** (round 7's L10-100, P1) | P1 | **RESOLVED -- verified.** `evals/score-artifacts.sh:681-695` is now a genuine thin delegation (`"${SCRIPT_DIR}/../bin/edm-compare-eval" "$tb" "$ta"`). One comparison implementation. See Noted 1-2 for the residual doc nit. |
| CA-037 (L10 half) | P1 | **RE-VERIFIED FOR THE FIRST TIME IN THREE ROUNDS.** `assert_absent_with_control` is gone, replaced by `assert_tree_absent` (`_harness.sh:235`) with 41 call sites. But ~17 hand-rolled copies survive outside it, and have diverged -- raised as L10-206. |

## Findings (L10: DRY & Redundancy)

| ID | Sev | Type | File A | File B | Canonical | Recommendation |
|---|---|---|---|---|---|---|
| L10-201 | P2 | **Carried CA-344:** five mechanical duplications | see detail | see detail | see detail | Unchanged; no divergence has appeared |
| L10-202 | P2 | **Carried CA-417:** missed callers on a landed extraction | `bin/edm-state:845` | `:2350`, `:5182` | `skipped_phases_str` | Two one-line conversions; fix docstring; add the smoke pin |
| L10-203 | P2 | **Carried CA-418:** diverged parallel renderer (header half) | `bin/edm-state:2625`, `:2638` | `:3455`, `:3465` | neither -- extract | Four headers, two mechanisms, disagreeing dash counts |
| L10-204 | P2 | **Carried CA-419:** duplicate function pair + behavioural divergence | `bin/edm-state:4754-4761` | `:4763-4770` | extract or delete | Collapse; also close the `write_handoff_internal` asymmetry |
| L10-205 | P2 | **Carried CA-420:** layout knowledge partially duplicated | `bin/edm-state:2705-2706` | `:134-138` | `list_state_files` | Add `archived_state_file_for`, or narrow the comment |
| **L10-206** | **P2** | **NEW -- Diverged parallel implementation (CA-037's L10 half)** | `bin/tests/_harness.sh:235` + `:198` | ~17 hand-rolled sites in wave6/wave7 | `assert_tree_absent` / `count_matches_strict` | 16 of 17 use the CA-145-unsafe `grep -c ... || true`; one was upgraded and the rest were not |
| **L10-207** | **P2** | **NEW -- 12 hand-maintained copies with a presence-only guard** | `agents/edm-audit-*.md` (11 files) | `skills/code-audit/SKILL.md:303` | generate, as `docs/canonical-sections.md` already is | Apply the plugin's own proven generator + `--check` mechanism to the JSONL schema literal |

### Details

#### L10-206 (NEW, P2, highest-priority new item) -- the positive-control idiom has a canonical harness helper and ~17 hand-rolled copies, and they have diverged on the exact defect the helper exists to close

This is **CA-037's L10 half**, unverified in rounds 6 and 7 for want of Bash. It is verifiable
by Grep and is re-flagged with fresh evidence.

- **Canonical A**: `bin/tests/_harness.sh:235-254` (`assert_tree_absent`) -- routes *both* the
  real and control haystacks through `count_matches_strict` (`:198-207`), asserts
  `count_matches_strict`'s own **exit status** alongside its printed value, and additionally
  guards every scan path with `[[ -e "$_p" ]]` before the needle check (`:239-241`). 41 call
  sites (`wave7:33`, `wave6:3`, `harness-smoke:5`).
- **Copies B**: ~17 hand-rolled blocks implementing the same "synthetic control line -> same
  pattern -> refuse a vacuous zero" idiom without the helper:
  `wave6-smoke.sh:291`, `:995`, `:2805`, `:3261`;
  `wave7-smoke.sh:409`, `:940`, `:963`, `:1137`, `:1284`, `:1294`, `:1304`, `:1442`, `:2852`,
  `:3007`, `:4149`, `:4206`, `:7924`.
  Eleven of these are the *same five-line shape* to within the needle:
  `X_control="$(printf '%s\n' '<synthetic>' | grep -c "$X_pattern" || true)"` followed by
  `if [[ "${X_control:-0}" -lt 1 ]]; then fail "... positive control broken ..."; else <real
  assertion>; fi`.

**The divergence is real, and it is exactly the defect CA-145 named.** Of the 17:
- **One** (`wave7-smoke.sh:4204-4208`, T47 AC5) uses `count_matches_strict` and captures its
  exit code into `t47_orch_explorer_control_ec` / `t47_orch_explorer_ec`, matching the canonical
  helper's contract.
- **The other sixteen** use a bare `grep -c ... || true` (or `grep -l`/`grep -n` variants). The
  harness's own docstring at `_harness.sh:179-185` states the rule these violate verbatim: "Any
  caller whose expected count is 0 MUST pair this with a positive control ... OR use
  `count_matches_strict`" -- and, critically, the positive control does **not** substitute for
  the second protection. It proves *the pattern can match*; it does not prove *the path was
  read*.

**Concrete live instance of the resulting false pass.** `wave7-smoke.sh:1438`:

```bash
t66ac12_flag_leak="$({ grep -c "$t66ac12_flag_leak_pattern" "${PLUGIN_DIR}/skills/"*/SKILL.md 2>/dev/null || true; } | awk -F: '{s+=$2} END{print s+0}')"
```

A wrong `PLUGIN_DIR`, a renamed `skills/` layout, or a glob that expands to nothing yields grep
exit 2, `2>/dev/null` discards the diagnostic, `|| true` swallows the status, `awk` prints `0`,
and the assertion passes as "the leak is absent." The control at `:1442` still passes, because
it is built from a synthetic string, not from the tree. `assert_tree_absent`'s path-existence
loop is the protection that closes precisely this, and this site does not have it.

**False-alarm filter.** (1) Different for good reason? No -- the sixteen differ from the one
only by not having been converted. The genuine structural gap is that `assert_tree_absent`
expresses only "expect zero", while several of these sites assert "expect exactly 1" (e.g.
`wave6:291`, `wave6:3261`) -- that argues for a second helper, not for sixteen hand-rolls.
(2) Test code only? Both copies are test code, so this is intra-suite duplication rather than
prod-vs-test -- lower blast radius, but prior rounds have consistently treated `_harness.sh`
duplication as in scope (CA-042, CA-145, CA-037 are all test-side). (3) Circular dependency?
No -- every one of these files already sources `_harness.sh`.

**Fix.**
1. Add `assert_count_with_control <label> <pattern> <expected-n> <control-haystack> <path...>`
   to `_harness.sh` beside `assert_tree_absent`, sharing its `count_matches_strict` +
   path-existence contract, so the "expect exactly N" family has a canonical form at all.
2. Convert the eleven identical-shape sites to one of the two helpers. The remaining
   non-`grep -c` variants (`:4149` `grep -l`, `:7924` `grep -n`, `:7863` tree scan, `:6621`
   string containment) may stay hand-rolled but must at minimum stop discarding grep's exit 2.
3. Add a durability pin of the shape `wave6-smoke.sh:781-784` already uses: assert that
   `grep -c ' || true'` adjacent to a `_control=` assignment occurs zero times in
   `bin/tests/*.sh`, with a positive control -- using `count_matches_strict`, not
   `count_matches`.

#### L10-207 (NEW, P2) -- the JSONL schema literal is hand-maintained in 12 files with only a presence check, while this plugin ships a generator-plus-`--check` mechanism built for exactly this class

- **Copies**: `agents/edm-audit-logic.md:92`, `-dead-code.md:91`, `-edge-cases.md:98`,
  `-test-quality.md:107`, `-runtime.md:103`, `-docs.md:98`, `-consistency.md:98`,
  `-security.md:138`, `-spec.md:118`, `-dry.md:108`, `-wiring.md:121`, and
  `skills/code-audit/SKILL.md:303`. Twelve copies of one line, currently identical apart from
  the `lens` value (`"L{N}"` in the SKILL, the concrete ID in each agent). Verified undiverged
  today by exact-string Grep.
- **The duplication itself is deliberate and correct.** `edm-audit-dry.md:107` states the
  rationale, and D22/CA-130 is the reason: the schema must not be resolvable *only* by
  reference, because a stale plugin cache breaks by-name resolution. I am not proposing to
  delete eleven copies.
- **What is missing is the drift guard, and the plugin already has one.**
  `bin/edm-sync-canonical-sections:20-26` states this project's own rule -- "never
  hand-maintained in two places" -- and implements it for the two canonical CLAUDE.md sections:
  a one-directional generator, a `--check` mode exiting 1 on drift, and a `wave6-smoke.sh` "T41
  AC5" byte-identity assertion. **None of that is applied to the schema line.** The only
  machine check that exists is `wave7-smoke.sh:1538`, which is a *presence* count
  (`grep -c '"schema":1'`), plus `:1548-1555`, which greps the section for the token `deferred`.
  Neither compares any copy against any other.
- **Why it matters.** Divergence here is silent by construction: `edm-audit-dry.md:123-126`
  states the residual risk in its own words -- a finding whose JSONL line has the wrong field
  set "is invisible to every downstream gate. That is a recall loss, not an integrity loss."
  Eleven independently-editable specifications of the format that recall depends on, with no
  identity check, is the same posture the two canonical sections were moved *away from*.
- **False-alarm filter.** (1) Different for good reason? The duplication is; the *unguarded*
  duplication is not. (2) Test-only? No. (3) Circular dependency? No. Distinguish this from
  Noted 8 (`hooks.json`'s five identical command hooks): JSON genuinely has no include
  mechanism, whereas these are markdown files the plugin already generates content into.

**Fix.** Extend `edm-sync-canonical-sections` (or add a sibling check) to assert all twelve
copies are byte-identical modulo the lens token, wired into `lint:bash-syntax`'s existing CI ban
list or `run-all.sh` alongside `edm-check-skill-sync`. Cheapest sufficient alternative: one
`wave7-smoke.sh` case extracting the `"schema":1` line from all twelve files, normalizing
`"lens":"L*"` to a placeholder, and asserting `sort -u | wc -l == 1` -- with a positive control.
While there, correct `edm-audit-dry.md:107`'s self-contradictory "documented once, identically
in every lens prompt" to say what it means ("restated deliberately in every lens prompt; kept
identical by <the new check>").

#### L10-201 (P2) -- CA-344's five, individually re-verified as still present and undiverged

Deferred in round 6, carried in round 7. All five re-read against current code; the round-6
rationale ("mechanical, no divergence, no false claim") still holds.

1. **Prefix-format regex duplicated** -- `bin/edm-init:53`
   (`^[A-Z][A-Z0-9]{2,5}$`, message "prefix must be 3-6 uppercase alphanumeric chars, starting
   with a letter") vs `bin/edm-validate-prefix:42-44` (same regex; message adds `(got
   '$PREFIX')`). `edm-init:81-86` still delegates to the validator behind `command -v`, so a
   normal install still checks the format twice against two independently-maintained regexes.
   **Unchanged.**
2. **Effective-grant predicate written once per direction** -- `bin/edm-check-grants:256-263`
   (`assert_agent_grant`, positive) vs `:504-508` (AC3 negative loop; round 7 recorded
   `:501-507`, a 1-line shift). Byte-equivalent three-statement `tools`-minus-`disallowedTools`
   rule. **Unchanged.**
3. **`edm-lint-artifacts`' three mode arms** -- the `while IFS= read -r -d "" _md_f` collect
   loop at `:414-417`, `:438-441`, `:486-489`, and the violations-summary/exit block at
   `:426-432`, `:457-463`, `:499-505`. The 0-clean/1-violations exit contract the `PreToolUse`
   hook depends on is still encoded three times. **Unchanged.**
4. **Product-dir collision scan twice in one 90-line script** -- `bin/edm-validate-prefix:58-72`
   (live: guarded by `[[ -d "$SRD_ROOT" ]]`, `.archived` basename skip, `die`s) vs `:80-87`
   (archived: no outer `-d` guard, no basename skip, warns). The doubled separator at `:80`
   (`"${SRD_ROOT}/.archived/"/*/`) is still present and still globs correctly. **Unchanged.**
5. **Lookback window computed twice** -- `bin/edm-check-grants:360-368` (`nearby_agent_name`)
   vs `:370-375` (`window_mentions_lens`): identical `lo=$((line - lookback)); [[ $lo -lt 1 ]]
   && lo=1; sed -n "${lo},${line}p"`. `resolve_targets_for_line:377-390` can still call both for
   one candidate line, so the `sed` range is still *executed* twice per hit. **Unchanged.**
   *(New observation, not a separate finding:* `scan_write_instructions:286-288` computes a
   third lo/hi + `sed -n` window with different semantics (+/-3 either side, clamped to
   `total_lines`), so any extraction should cover the general form, not just the two-arg
   lookback case.*)*

#### L10-202 (P2) -- CA-417: both un-converted callers survive, and a round-7 fix edited adjacent to one of them without converting it

The helper is at `bin/edm-state:845-847`. Two byte-identical literal copies of its jq survive:

- **`bin/edm-state:2350`** (`cmd_phase_complete`) --
  `pc_skipped_str="$(echo "$pc_state" | jq -r '[(.skipped_phases // [])[].phase] | join(" ")')"`
  (round 7 recorded `:2227`). `skipped_phases_str "$pc_state"` is a drop-in.
- **`bin/edm-state:5182`** (`_write_handoff_body`) --
  `skipped_for_count="$(echo "$state" | jq -r '[(.skipped_phases // [])[].phase] | join(" ")')"`
  (round 7 recorded `:5048`). Authored by round 6's own G4/CA-335 fix.

**Fresh aggravator this round.** `:5183-5192` is round 7's **G11/CA-389** remediation -- a
careful ten-line comment plus a rewrite of `required_gates_output` on the line *immediately
below* the duplicate. A third consecutive round's fix worked inside this exact five-line window
and left the duplicated derivation feeding it untouched. That makes this the **fourth**
documented instance of a same-round or adjacent-round fix passing over the DRY residual, and
strengthens round 7's standing durability recommendation.

The docstring at `:841-844` still reads "hand-copied at cmd_phase_start, cmd_gate_check and
cmd_archive (three separate literal copies)". Still wrong on both counts: five sites existed;
neither of the two survivors is named. Note the helper's live callers are now `:877`
(`gate_required_and_approved`) and `:2897` (`cmd_archive`) -- `cmd_phase_start` and
`cmd_gate_check` reach it through the composing wrapper, which the docstring does not say.

**No durability pin exists.** `wave6-smoke.sh:781-784` pins the *sibling* gate-approval
derivation at exactly one definition; there is still no analogous assertion for
`[(.skipped_phases // [])[].phase] | join(" ")`, which is why both survivors remain invisible to
a green suite.

**Fix.** `:2350` -> `pc_skipped_str="$(skipped_phases_str "$pc_state")"`; `:5182` ->
`skipped_for_count="$(skipped_phases_str "$state")"`; correct `:841-844` to name five original
sites and the two real callers; add the `count_matches_strict` single-definition pin.

#### L10-203 (P2) -- CA-418: the coverage row is shared, the four headers labelling it are not

Row defs are correctly shared: `COVERAGE_LAYER_ROW_JQ_DEF` (`bin/edm-state:1062-1063`) and
`COVERAGE_EPIC_ROW_JQ_DEF` (`:1071-1072`), each referenced from both `cmd_get_coverage`
(`:2619`, `:2632`) and `cmd_metrics_report` (`:3457`, `:3467`). No third copy exists.

Four header/underline pairs in two incompatible mechanisms remain:

| Site | Mechanism |
|---|---|
| `bin/edm-state:2625-2626` (get-coverage, layer) | hardcoded jq string literals, hand-counted spaces |
| `bin/edm-state:2638-2639` (get-coverage, epic) | same |
| `bin/edm-state:3455-3456` (metrics-report, layer) | `printf "  %-14s  %-10s  %-20s\n"` |
| `bin/edm-state:3465-3466` (metrics-report, epic) | `printf "  %-15s  %-14s  %-10s\n"` |

**The divergence is unambiguous without column arithmetic**, which is the improvement over round
7's caveated claim. The two underline rows for the *same shared layer row* use different dash
counts outright: get-coverage emits the literal `  ----------     --------   -----------` (ten
dashes under "Layer"), while metrics-report emits `printf ... "-----" "--------"
"-----------"` (five dashes, then padded to 14 by the format spec). These cannot both match the
row. metrics-report's `%-15s`/`%-14s` widths do reproduce the shared defs' 15-wide epic and
14-wide layer clamps exactly, so metrics-report is the correct one and get-coverage is the
misaligned one -- consistent with round 7's arithmetic.

Caveat retained: not confirmed by running both commands (no Bash). The structural finding -- one
shared row, four independently-maintained headers, two mechanisms, provably different dash
counts -- does not depend on running them.

**Fix.** Add `COVERAGE_LAYER_HEADER_JQ_DEF` / `COVERAGE_EPIC_HEADER_JQ_DEF` beside the row defs,
emitting header *and* underline from the same padding constants the row uses; reference from all
four sites, converting metrics-report's `printf` pair too so one mechanism owns the widths.
Extend `wave5-smoke.sh:112`'s byte-identity assertion to cover the header rows.

#### L10-204 (P2) -- CA-419: 7-line twin functions, and the provenance setters have diverged on HANDOFF refresh

- **File A**: `bin/edm-state:4754-4761` (`cmd_set_supersedes`)
- **File B**: `bin/edm-state:4763-4770` (`cmd_set_forked_from`)

Identical seven-line bodies -- same arg-count guard, same `require_jq`, same non-empty check,
same single-key `rmw_state` with `.last_updated`, same confirmation echo -- differing only in
the state key (`.supersedes` / `.forked_from`) and the subcommand name interpolated into three
strings.

**The diverged half:**

| Subcommand | Line | Validates target exists | Refreshes HANDOFF.md |
|---|---|---|---|
| `cmd_set_supersedes` | `:4754` | no | **no** |
| `cmd_set_forked_from` | `:4763` | no | **no** |
| `cmd_set_parent` | `:4792` | yes (`:4798`) | yes (`:4801`) |
| `cmd_add_related` | `:4805` | yes (`:4811`) | yes (`:4821`) |

The validation asymmetry matches `plugins/edm/CLAUDE.md`'s state-field table, which claims
"validated to exist" for `parent_prefix` only. The **HANDOFF-refresh asymmetry is documented
nowhere and is observable**: `_write_handoff_body` reads `supersedes` (`:5172`) and
`forked_from` (`:5173`) into the rendered artifact, so setting either leaves the committed
cross-user resume doc stale until an unrelated command rewrites it.

**Sequencing note retained.** Round 6's G30/CA-357 found both subcommands have zero callers and
no user-facing documentation. **Do not extract a helper before CA-357 is decided** -- deletion
closes this for free. If kept, collapse to `_cmd_set_provenance_link <state-key>
<subcommand-label> <prefix> <other>` and add the `write_handoff_internal` call in the same edit.

#### L10-205 (P2) -- CA-420: the enumeration is shared, both archived layout shapes are still re-encoded at the probe, and the comment says otherwise

`bin/edm-state:2710` correctly reads `done < <(list_state_files --archived)`. The shape
knowledge did not move -- `:2705-2706` re-encodes both archived layouts as `case` patterns
against `list_state_files`' own two globs at `:137-138`:

```bash
      "${SRD_ROOT}/.archived/${prefix}/.edm-state.json") archived_hit="$_ms_f" ;;
      "${SRD_ROOT}"/.archived/*/"${prefix}__"*/.edm-state.json) archived_hit="$_ms_f" ;;
```

The comment at `:2698-2701` still claims "routed through `list_state_files`' already-deduped
enumeration instead, so a future archived layout variant only needs to be taught to
`list_state_files`, not to every probe of it." False for this site: a third archived shape
taught to `list_state_files` would be enumerated, match neither arm, fall to `*) continue`,
leave `archived_hit` empty, and silently stop the AC4 archived-initiative refusal from firing
for that shape.

Partial mitigation stated fairly: this site genuinely needs *some* per-prefix knowledge, because
`list_state_files` does not filter by prefix. The honest framing is that the comment overclaims
by exactly the amount the fix left behind.

**Fix.** Add `archived_state_file_for <prefix>` beside `state_file_for` (`:219`, the declared
"single source of layout truth"), owning both the `list_state_files --archived` call and the
prefix filter; call it here. Cheaper: narrow the comment to "the enumeration is shared; the two
shape patterns below are still local to this probe."

## Noted / Not Actionable

| ID | File:Line | Rationale |
|---|---|---|
| N-01 | `evals/score-artifacts.sh:681-695` | **CA-383 verified RESOLVED.** `cmd_compare` is now a real thin delegation to `bin/edm-compare-eval`; the `complete: true` injection into temp copies is a fixture accommodation (documented `:668-680`), not a second implementation. One comparer, one exit-code family, one threshold. |
| N-02 | `bin/edm-compare-eval:4-5` | Residual doc nit from CA-383: still asserts "The scorer ... never compares", and `plugins/edm/CLAUDE.md`'s `eval:nightly` row repeats it, while `--compare` remains a documented user-facing mode that delegates. The DRY defect is closed; the wording is a docs-lens item, not L10. |
| N-03 | `bin/edm-state:2428-2437` vs `:4318-4327` | **Correcting a two-round-old undercount.** NOTED in rounds 5 and 6 as "a 3-line marshalling residual" after G46/CA-277 extracted `_unpack_token_fields`. The residual is actually a **10-line byte-identical block** (the `local input=0 ... unparseable_lines=0` defaults line, the `if [[ -n "$started_at" ]]` guard, the `get_session_tokens_since` call, four global-to-local reassignments, and the `compute_cost_usd` call). The defaults are load-bearing: `plugins/edm/CLAUDE.md`'s audit-round row documents them ("token counts stay 0, model_used stays unknown, estimated_cost_usd stays 0.0000, attribution_mode stays whole-directory") for one copy only. Held NOTED out of respect for two deliberate acceptances, but flagged as **inconsistent with CA-344**, which is P2 for the same "mechanical, no divergence" class -- if CA-344's five are batched for remediation, this belongs in the same batch. |
| N-04 | `bin/tests/_harness.sh:307-342` | `check_refuses_and_leaves_state` duplicating `check_fails` + `check_state_unchanged`: deliberate and well-argued at `:299-306` (CA-042) -- composing them needs two executions, "neither of which alone proves the other". The duplication is the fix. |
| N-05 | `bin/tests/_harness.sh:186`, `:198` | `count_matches` vs `count_matches_strict`: the difference *is* the point (CA-145), documented at `:179-185`. |
| N-06 | nine `bin/` helpers + three `evals/` drivers | Per-script `die()`: each carries its own name prefix and exit-code family contract (`edm-validate-prefix:22-25`, `edm-compare-eval:39-40`), pinned as a deliberate matrix by `wave7-smoke.sh:7775`. `_edm-cli-lib.sh` shares only `print_help`. Intentional. |
| N-07 | `_harness.sh:263` vs `edm-state:170` | `_harness_hash_file` vs `artifact_hash`: the harness cannot hash via the binary under test. Opposite tool-preference order (`shasum`-first vs `sha256sum`-first) is cosmetic -- both produce SHA-256. False-alarm criterion 2. |
| N-08 | `hooks/hooks.json:19/32/45/58/71` | Five UserPromptExpansion command hooks byte-identical apart from one token. JSON has no include mechanism. Contrast L10-207, where a generator mechanism does exist. |
| N-09 | four `bin/` scripts + the git-commit hook | `SRD_ROOT="${EDM_SRD_ROOT:-${CLAUDE_PLUGIN_OPTION_SRD_ROOT:-./SRD}}"`: each is an independent entry point resolving its root before `_edm-cli-lib.sh` is sourced; the hook cannot source bash libraries at all. Consistent everywhere. |
| N-10 | `edm-state:3075` vs `:3502` | `_cmd_archive_move_body` vs `_cmd_migrate_path_move_body` lock-name sweeps: divergence deliberate and explained at length. Unchanged. |
| N-11 | `edm-state:1496`, `:1505-1521` | **Verified clean this round.** `BLOCKING_FILTER` + `_audit_ledger_breakdown`: all four named consumers reach the predicate by reference or by delegating to `cmd_audit_converged` (`:2181`, `:3018`, `:4491`, `:5503`); the comments at `:2952` and `:5265` accurately describe delegation, not re-derivation. `wave6-smoke.sh:3248-3264` pins one definition and one invocation with a working positive control. This is the model the other extractions should follow. |
| N-12 | `evals/score-artifacts.sh:99` | `_scan_mermaid_blocks` vs `_edm-lint-lib.sh`'s `build_line_classes`: both load the shared `bin/edm-mermaid-rules.awk` via `-f` (CA-019); the one behavioural difference is stated in place. |
| N-13 | `edm-state:4792`, `:4805` | `cmd_set_parent` vs `cmd_add_related` share the validate-write-refresh skeleton, but `add_related`'s idempotent list-append jq is genuinely different work from a scalar set. The real copy is L10-204's pair. |
| N-14 | `edm-validate-prefix:59-71` vs `edm-state:231` | Product-scoped layout shape (`{PRODUCT}/{PREFIX}__*`) encoded in both. `edm-validate-prefix` is a standalone entry point invoked by `edm-init` via `command -v` and cannot source `edm-state`'s resolver without inverting the dependency. False-alarm criterion 3 (adjacent form). |
| N-15 | `evals/run-eval.sh` | CA-283 (three phase blocks): carried as NOTED, **not re-checked** -- see Meta. |
| N-16 | `edm-check-vocabulary` vs `_lint_report_class_hits` | Genuinely different designs. Unchanged from rounds 6-7. |

## Meta

- **Read in full or in the relevant part this round:** `bin/edm-validate-prefix` (whole),
  `bin/edm-init` (whole), `bin/edm-compare-eval` (whole), `bin/edm-check-grants:230-410`,
  `:460-535`, `bin/edm-lint-artifacts:380-508`, `bin/edm-state:115-235`, `:836-890`,
  `:1480-1540`, `:2340-2365`, `:2404-2455`, `:2605-2655`, `:2686-2720`, `:3444-3480`,
  `:4300-4360`, `:4745-4825`, `:5165-5200`, `:5250-5300`, `:5460-5520`,
  `bin/tests/_harness.sh:150-410`, `bin/edm-sync-canonical-sections:1-70`,
  `evals/score-artifacts.sh:660-720`, `agents/edm-audit-dry.md` (whole), plus targeted Grep
  sweeps across `bin/tests/`, `agents/`, `skills/` and `evals/`.
- **Not read closely (report as unaudited, not clean):** `bin/tests/wave6-smoke.sh` and
  `wave7-smoke.sh` in full (~11.5k lines; L10-206 was reached by pattern sweep, not by full
  read), `bin/tests/run-all.sh`, `bin/tests/timing.sh`, `bin/tests/wave3/4a/4b/5-smoke.sh`,
  `evals/run-eval.sh`, `evals/tiering-matrix.sh`, `.gitlab-ci.yml`, `bin/edm-check-vocabulary`,
  `bin/edm-check-skill-sync`, `bin/_edm-lint-lib.sh`, `monitors/monitors.json`, `CHANGELOG.md`,
  `README.md`, `bin/edm-state:5300-5700`.
- **Tooling gap (CA-130, ninth consecutive round), with a newly measurable cost.** Write, Edit
  and Bash absent. Beyond the usual loss of `diff`/`sort`/`uniq` and the inability to *run* the
  two coverage renderers (L10-203's caveat), this round confirmed the cumulative artifact loss:
  **`pass-6/lens-L10.jsonl` and `pass-7/lens-L10.jsonl` do not exist on disk.** Three rounds of
  L10 findings have reached the synthesizer only as prose. Per this lens's own contract
  ("The JSONL file is authoritative on conflict"), the authoritative artifact has been missing
  for the majority of this initiative's recent audit history. CA-331 should be treated as
  blocking for round 9.
- **Durability recommendation, carried and strengthened.** Round 7 recommended that any
  remediation extracting a helper must land a `count_matches_strict` single-definition pin in
  the same commit. L10-202 supplies a fourth data point (round 7's CA-389 fix editing one line
  below an un-converted duplicate), and L10-206/L10-207 generalize it: **this codebase's
  extractions consistently land the shared definition and omit the guard that keeps it the only
  one.** The three clean cases -- `BLOCKING_FILTER` (N-11), the canonical CLAUDE.md sections,
  and `assert_tree_absent`'s 41 converted sites -- are exactly the three that shipped with a
  machine check. Recommend adopting "an extraction is not done until a single-definition or
  byte-identity assertion exists" as a standing remediation rule, not a per-finding suggestion.

## Summary for the coordinator

**All five prior findings re-confirmed STILL OPEN** with current line numbers -- none has a fix.

- **CA-344** -- all five sub-parts present, none diverged. Only movement: the AC3 negative loop shifted from `:501-507` to `plugins/edm/bin/edm-check-grants:504-508`.
- **CA-417** -- both callers still un-converted at `plugins/edm/bin/edm-state:2350` and `:5182`; docstring still says "three". **New evidence:** round 7's CA-389 fix rewrote `:5192`, one line below the duplicate, without converting it -- the fourth instance of this pattern.
- **CA-418** -- four headers, two mechanisms. **Upgraded evidence:** the divergence is now provable without column arithmetic -- the underline rows use different dash counts outright (10 vs 5 under "Layer").
- **CA-419** -- both halves intact. Still blocked behind CA-357's delete/keep decision.
- **CA-420** -- case patterns at `:2705-2706` unchanged; the overclaiming comment at `:2698-2701` unchanged.

**Two new P2s:**
1. **CA-037's L10 half, verified for the first time in three rounds** -- ~17 hand-rolled positive-control blocks in `plugins/edm/bin/tests/wave6-smoke.sh` and `wave7-smoke.sh` duplicate `assert_tree_absent`, and have diverged: one site was upgraded to `count_matches_strict`, sixteen still use `grep -c ... || true` with no path-existence guard. Live false-pass instance cited at `wave7-smoke.sh:1438`.
2. **12 hand-maintained copies of the JSONL schema literal** with only a presence check, while `plugins/edm/bin/edm-sync-canonical-sections` already implements this plugin's own "never hand-maintained in two places" rule for the two canonical sections.

**One prior P1 confirmed fixed:** CA-383 (dual eval comparers) -- `plugins/edm/evals/score-artifacts.sh:681-695` is a genuine thin delegation.

**Escalation:** `pass-6/lens-L10.jsonl` and `pass-7/lens-L10.jsonl` do not exist on disk. Three consecutive rounds of L10 findings have reached the synthesizer as prose only, against a contract that names the JSONL authoritative. CA-331 should block round 9.
