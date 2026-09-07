# EDM Code Audit Lens L10: DRY & Redundancy -- Round 1 (full)

Scope: `git diff main..HEAD -- plugins/edm/` on `edm/edmv4-ecc-integration` (131 files, 12282
insertions). Audited via static read of the working tree (`Read`/`Grep`/`Glob`; no `Bash` grant,
so no `git diff` -- findings are against the tree as it stands, and pre-existing items are marked).

## Findings (L10: DRY & Redundancy)

| ID | Type | File A | File B | Canonical | Recommendation |
|----|------|--------|--------|-----------|----------------|
| L10-001 | Copy-pasted block + missing fourth copy | plugins/edm/bin/edm-hookify:262 | plugins/edm/bin/edm-bash-gate:72 | edm-hookify's `hookify_emit_match` | Extract one `edm_sanitize_ascii` into `_edm-cli-lib.sh`; give edm-bash-gate a named emit point |
| L10-002 | Diverged parallel implementation | plugins/edm/bin/edm-state:1137 | plugins/edm/bin/edm-hookify:106 | edm-state's `_resolve_permcheck_project_root` | Move the CA-500-hardened resolver into `_edm-datadir-lib.sh`; redirect hookify + `edm_project_key` |
| L10-003 | Duplicate function (x3 + variant) | plugins/edm/bin/tests/wave8-smoke.sh:2522 | plugins/edm/bin/tests/wave8-smoke.sh:3547 | one helper in `_harness.sh` | Promote one `_harness_extract_fn` to `_harness.sh`, delete the three local copies |
| L10-004 | Duplicate utility already in dependency tree | plugins/edm/bin/tests/wave8-smoke.sh:120 | plugins/edm/bin/tests/wave8-smoke.sh:3438 | `_harness.sh:369` `_wave7_extract_between` | Delete both locals; call the already-sourced shared helper |
| L10-005 | Consumer bypasses shared primitive | plugins/edm/bin/edm-state:3804 | plugins/edm/bin/edm-state:4758 | `LENS_READ_JQ_DEF` | Route the metrics-report Lenses column through `read_round_lenses($all)` |
| L10-006 | Copy-pasted block, already diverged | plugins/edm/hooks/hooks.json:19 | plugins/edm/hooks/hooks.json:75 | the `srd` block's prompt text | Add a smoke check asserting the five prompt bodies stay identical modulo the gate token |
| L10-007 | Diverged parallel implementation | plugins/edm/bin/edm-repo-readiness:134 | plugins/edm/bin/edm-stop-gate:96 | `edm-state active-initiatives` | Add a machine-readable accessor to edm-state; both consumers call it |

### Details

#### Finding L10-001: the ASCII sanitizer is hand-copied five times across three hook scripts, and the fourth hook consumer has no sanitizing emit point at all

- **File A**: `plugins/edm/bin/edm-hookify:262-264` -- `hookify_emit_match()` runs the literal
  `LC_ALL=C tr -c '\011\012\015\040-\176' '?'` three separate times, once each for `rule_id`,
  `action` and `message`.
- **File B**: `plugins/edm/bin/edm-gateguard:163` -- `emit_decision()` runs the byte-identical
  literal once against `$reason`.
- **File C**: `plugins/edm/bin/edm-stop-gate:82` -- `stop_gate_emit_blocking()` runs the
  byte-identical literal once against `$text`.
- **File D (the gap)**: `plugins/edm/bin/edm-bash-gate:72` -- `printf '%s\n' "$HOOKIFY_OUT" >&2`.
  No sanitizer, no named emit function, and no `_edm-cli-lib.sh` helper to call.
- **Divergence**: five occurrences of one character-class literal with no shared owner, and the
  four hook consumers disagree about whose job sanitization is. `edm-hookify:255-258` states its
  contract as "so neither downstream consumer ever has to sanitize a second time" -- yet
  `edm-gateguard:405` feeds `GG_HOOKIFY_OUT` back through `emit_decision`'s sanitizer and
  `edm-stop-gate:166` feeds `_hookify_out` back through `stop_gate_emit_blocking`'s. Two of three
  consumers re-sanitize in contradiction of the producer's stated contract; the third does not.
  `edm-bash-gate` is additionally the only one of the four outside `EDMV4-T52` AC6/AC7's
  single-emit-point verification: `bin/tests/wave8-smoke.sh:5611-5685` checks exactly
  `emit_decision`, `hookify_emit_match` and `stop_gate_emit_blocking` by name, so a future edit
  that widens `edm-bash-gate`'s stderr write (for example to `2>&1` capture, the shape
  `edm-stop-gate:160` already uses, which would mix in unsanitized `edm-hookify` diagnostics) has
  no structural check standing against it.
- **Fix**: keep `hookify_emit_match`'s producer-side sanitization as canonical. Extract the `tr`
  invocation into a single `edm_sanitize_ascii <text>` in `bin/_edm-cli-lib.sh` (already the
  plugin's shared-bin-helper home, and already sourced by all four scripts), have all five current
  call sites call it, and give `edm-bash-gate` a named `bash_gate_emit_blocking` that routes
  through it so `EDMV4-T52` AC6's structural check can be extended to the fourth consumer. If the
  double-sanitization at gateguard/stop-gate is deliberate defence-in-depth, say so once in
  `edm-hookify`'s contract paragraph instead of leaving it contradicted by two of three callers.

#### Finding L10-002: three project-root resolvers, and the two that claim to share the canonical one predate its CA-500 hardening

- **File A (canonical)**: `plugins/edm/bin/edm-state:1137` `_resolve_permcheck_project_root()` --
  resolves `CLAUDE_PROJECT_DIR`, then cross-checks it PHYSICALLY (`pwd -P`) against
  `git rev-parse --show-toplevel` and refuses it with a stderr diagnostic when it falls outside
  the toplevel; falls back to the toplevel, then `.`. The comment at `:1125-1136` records why:
  CA-500, "a bypass that RECORDS ITSELF AS ENFORCED".
- **File B**: `plugins/edm/bin/_edm-datadir-lib.sh:113` `edm_project_key()` -- accepts
  `CLAUDE_PROJECT_DIR` on the sole test `[[ -d "$dir" ]]`, else git toplevel, else `pwd`. Its own
  docstring at `:44` cites "the CA-448 precedent from check_permission_rules".
- **File C**: `plugins/edm/bin/edm-hookify:106` `resolve_project_root()` -- accepts
  `CLAUDE_PROJECT_DIR` on the sole test `-d`, else git toplevel, else `.`. Its header at `:23-25`
  says rule discovery is "resolved the same way check_permission_rules() resolves it in
  bin/edm-state (CA-448 baseline)".
- **Divergence**: B and C were written against the CA-448 shape; A has since been hardened by
  CA-500 and no longer matches what B and C say they mirror. `plugins/edm/CLAUDE.md:911-918`
  compounds this by documenting the three-step chain as canonical -- "so a future consumer never
  has to invent a second resolution procedure" -- while itself omitting the cross-check the real
  `check_permission_rules()` performs. Concretely: a `CLAUDE_PROJECT_DIR` pointing outside the git
  toplevel is refused for permission-rule resolution but silently honoured for hookify rule
  discovery (`edm-hookify` will then load and enforce `.claude/edm-hookify/*.json` from that
  directory) and for the gateguard marker and session-state key.
- **Fix**: `_edm-datadir-lib.sh` is the right home -- it is already the shared resolver library and
  is already sourced by `edm-gateguard`. Move the CA-500-hardened body there as one
  `edm_resolve_project_root()`, have `edm_project_key()` compose on it, have `edm-hookify` source
  the lib and call it (it currently sources only `_edm-cli-lib.sh`), and have edm-state's
  `_resolve_permcheck_project_root` delegate. One deliberate difference must be preserved
  explicitly rather than lost in the merge: the terminal fallback is `pwd` in B and `.` in A/C.
  Then correct `CLAUDE.md:911-918` to describe the cross-check.

#### Finding L10-003: three byte-identical awk function-body extractors in one test suite, plus a fourth near-variant

- **File A**: `plugins/edm/bin/tests/wave8-smoke.sh:2522` `_t44_extract_emit_decision()`.
- **File B**: `plugins/edm/bin/tests/wave8-smoke.sh:3547` `_t13_extract_fn()`.
- **File C**: `plugins/edm/bin/tests/wave8-smoke.sh:5206` `t51_extract_fn()`.
  B and C are byte-identical:
  `awk -v needle="${name}() {" 'index($0, needle) == 1 { found=1 } found { print } found && /^}/ { exit }'`.
  A is the same program with the needle hardcoded to `emit_decision() {` instead of parameterized.
- **File D (variant)**: `plugins/edm/bin/tests/wave8-smoke.sh:1675` `_t12_extract_fn_body()` -- the
  same awk shape but with `next` after the match, so it prints the body EXCLUDING the signature and
  closing brace, where A/B/C include both.
- **Divergence**: A/B/C are not yet behaviourally different, but D already is, and nothing marks D's
  difference as deliberate -- a reader picking "the extractor" from this file gets a 1-in-4 chance
  of the exclusive-bounds variant. The comment at `:3543-3546` acknowledges B "mirrors the proven
  awk idiom EDMV4-T12 uses" while silently changing its bounds semantics.
- **Fix**: promote one parameterized `_harness_extract_fn <file> <name> [--body-only]` into
  `bin/tests/_harness.sh` (which every suite already sources), delete A/B/C, and convert D to the
  `--body-only` form so the bounds difference is named rather than implied.

#### Finding L10-004: two local `extract_between` helpers duplicate the shared `_harness.sh` one the same file already calls

- **File A**: `plugins/edm/bin/tests/wave8-smoke.sh:120` `_t34_extract_between()`.
- **File B**: `plugins/edm/bin/tests/wave8-smoke.sh:3438` `_t41_extract_between()`.
- **File C (canonical, already in the dependency tree)**: `plugins/edm/bin/tests/_harness.sh:369`
  `_wave7_extract_between()`. A, B and C are the identical awk program
  (`$0 ~ ENVIRON[START] {found=1;next} found && $0 ~ ENVIRON[END] {exit} found {print}`), differing
  only in the two environment variable names (`T34_`/`T41_`/`WAVE7_EXTRACT_`).
- **Divergence**: none yet in behaviour, but this is the exact shape CA-102/CA-099 already fixed
  once -- `_harness.sh:380-382` records that `_wave7_extract_between` was moved into the harness
  "so every suite can replace" its own copy. `wave8-smoke.sh:5569` already calls the shared
  `_wave7_extract_between` directly, proving it is in scope in this very file; A and B were written
  anyway. B's own comment at `:3434-3437` claims it is "the same sentinel-delimited extraction
  EDMV4-T34/T37 already use", which is true only because it re-typed it.
- **Fix**: delete both locals and call `_wave7_extract_between` at all seven call sites
  (`:129`, `:181`, `:1492`, `:1493`, `:1555`, `:1580`, `:3447`). Consider renaming the shared helper
  off its `_wave7_` prefix, which is now misleading for a harness-level utility.

#### Finding L10-005: metrics-report re-implements the `.lenses` read that `LENS_READ_JQ_DEF` exists to own

- **File A (canonical)**: `plugins/edm/bin/edm-state:4758` -- `LENS_READ_JQ_DEF` defines
  `read_round_lenses($all)`, whose whole purpose (comment at `:4754-4757`) is the C-4
  backward-compatible substitution: a round record with an empty/absent `lenses` and
  `round_type == "full"` reads as the full `ALL_LENS_IDS` set, "so the substitution happens in
  exactly one place".
- **File B**: `plugins/edm/bin/edm-state:3804` -- `cmd_metrics_report`'s per-round cost table reads
  `((.lenses // []) | length | tostring)` inline for its Lenses column.
- **Divergence**: real, and visible in the rendered output. For a legacy round recorded with
  `lenses: []` and `round_type: "full"`, `read_round_lenses` yields 14 while B yields 0 -- and B
  prints that 0 directly above its own caption at `:3806`, "round_type full = all 14 lenses". Two
  consumers of the same field, one of which contradicts both the shared rule and its own adjacent
  legend. The other two in-file consumers of `.lenses` (`:4669`, `:4678`) read the findings-ledger
  `lenses` key, a different field entirely, and are not in scope here.
- **Fix**: prepend `${LENS_READ_JQ_DEF}` to the `jq` program at `:3800` (the sibling call at
  `:3788` already prepends `${AUDIT_ROUND_COERCE_JQ_DEF}` the same way) and read
  `(read_round_lenses($all) | length)`, passing `$all` from the same
  `printf '%s\n' $ALL_LENS_IDS | jq -R . | jq -s .` expression used at `:4862` and `:4972`.
  `LENS_READ_JQ_DEF` is a top-level assignment, so it is in scope by the time `cmd_metrics_report`
  runs despite being defined lower in the file.

#### Finding L10-006: five copy-pasted UserPromptExpansion gate blocks, one of which has already diverged

- **File A**: `plugins/edm/hooks/hooks.json:19` and `:23` -- the `edm:srd` matcher's command
  one-liner and its ~1100-character advisory prompt.
- **File B**: `plugins/edm/hooks/hooks.json:32/36`, `:45/49`, `:58/62`, `:71/75` -- the same two
  strings repeated for `edm:audit-srd`, `edm:tickets`, `edm:audit-tickets` and `edm:implement`.
  The command one-liner is identical in all five except the single `gate-check ... <name>` token.
  The prompt is identical in all five except that same token.
- **Divergence**: the `edm:implement` copy at `:75` has drifted -- it alone carries the extra clause
  "and also enforces Gate 3.5 when compliance_enabled=true" inside the otherwise byte-identical
  parenthetical. That is a legitimate difference in content, but it is now indistinguishable from an
  accidental edit, and it proves the five copies are edited independently. The prompts themselves
  carry the warning that makes this ironic: "CA-409: two independent procedures for one predicate
  drift apart silently" -- restated five times, in five separately editable copies.
- **Fix**: this is the one finding whose canonical form is constrained by the file format -- JSON
  has no include mechanism, so the five blocks cannot literally share a string in place. The
  realistic options are (a) accept the duplication but add a smoke check asserting the five prompt
  bodies are identical after normalizing the gate-name token and the recorded `implement`
  exception, so a sixth divergence fails the suite; or (b) generate `hooks.json` from a template
  the way `edm-sync-canonical-sections` already generates `docs/canonical-sections.md`, with a
  `--check` mode. (a) is proportionate. Pre-existing: only the `PreToolUse: Bash` block (`:100-107`)
  and the second `Stop` entry (`:116-119`) are new in this initiative.

#### Finding L10-007: two hand-rolled parsers of edm-state's human-readable initiative listing, diverged on which subcommand they parse

- **File A**: `plugins/edm/bin/edm-repo-readiness:129-135` `_rr_active_prefixes()` --
  `"$EDM_STATE_BIN" list 2>/dev/null | awk '/phase=/{print $1}'`.
- **File B**: `plugins/edm/bin/edm-stop-gate:96-104` -- a `while IFS= read -r` loop matching
  `case "$_line" in *"phase="*)` then `awk '{print $1}'`, over `edm-state active-initiatives`.
- **Divergence**: both extract field 1 from a `phase=`-bearing line of an output format that exists
  only as a `printf` in edm-state (`cmd_list` at `:2435`/`:2438`, `cmd_active_initiatives` at
  `:4086`), so a padding or column change in either `printf` silently breaks one or both consumers.
  Worse, they read DIFFERENT subcommands with different semantics: `cmd_active_initiatives:4081`
  filters to `current_phase` 1-6, while `cmd_list` emits every non-archived initiative including
  `phase=0` scaffolds and completed ones. A's function is named `_rr_active_prefixes` and its
  docstring at `:125-128` says "every active initiative `edm-state list` itself already resolves",
  which is not what `list` does -- so the readiness scorecard's State-health, Test-stack and
  Coverage-posture categories are computed over a wider set than the name and doc claim.
- **Fix**: give `edm-state` one machine-readable accessor (for example `active-initiatives --prefixes`,
  or `list --prefixes [--active]`, alongside the existing `list --paths` precedent at `:2403`) and
  have both consumers call it, so the human-readable `printf` format stops being a parsed
  interface. Then decide explicitly whether readiness wants active-only (switch to the active
  accessor) or all-non-archived (rename `_rr_active_prefixes` and correct its docstring).

## Noted / Not Actionable

| ID | File:Line | Rationale |
|----|-----------|-----------|
| L10-008 | plugins/edm/bin/edm-state:5155 | `cmd_audit_converged` also reads `(.lenses // [])` inline rather than via `read_round_lenses`, but the value (`latest_lenses_csv`) is consumed only on the `round_type == "partial"` branch at `:5179`, and `read_round_lenses`'s substitution fires only when `round_type == "full"`. The two reads are provably equivalent at this call site. Worth routing through the shared def for uniformity, but it is not a divergence. |
| L10-009 | plugins/edm/agents/edm-audit-security.md:19 | The house `## Scope` paragraph is hard-wrapped across two source lines here and single-line in the other thirteen lens files. Content is identical once the wrap is treated as a space, the divergence is whitespace-only, and `bin/tests/wave8-smoke.sh:4786-4798` explicitly documents and accommodates it with two wrap-safe substring checks (as does `:4826-4830` for the same file's wrapped canonical-sections instruction). Deliberate repetition, no content drift. |
| L10-010 | plugins/edm/bin/_edm-cli-lib.sh:29 | CA-005 verified clean. Every `--help` site -- `edm-state:6808`, `edm-gateguard:62`, `edm-hookify:78`, `edm-stop-gate:53`, `edm-bash-gate:44`, `edm-repo-readiness:57`, `edm-init:43`, `edm-lint-artifacts:85`, `edm-lint-staged-artifacts:49`, `edm-validate-prefix:34`, `edm-check-grants:79`, `edm-check-vocabulary:73`, `edm-check-skill-sync:40`, `edm-check-verifier-sentinel:58`, `edm-compare-eval:51`, `edm-sync-canonical-sections:61`, plus the three `evals/` drivers -- sources `_edm-cli-lib.sh` and calls `print_help "${BASH_SOURCE[0]:-$0}"`. The extractor awk literal occurs in exactly one non-test file. `edm-bash-gate` (the newest, written last) conforms at `:41` and `:44`. No fourth shape. |
| L10-011 | plugins/edm/bin/_edm-lint-lib.sh:104 | CA-513 verified clean, no fourth fence-tracker copy. Every fence-aware consumer in `bin/edm-state` (`pattern_extract_titles:5712`, `pattern_insert_line_for:5825`, the `### ` heading walk at `:5959`) goes through `ignored_line_set`/`is_ignored_line` from the shared library, as do `edm-check-grants` and `edm-check-vocabulary`. `edm-state:5713-5722` additionally single-sources the awk skip-set CONSUMPTION prelude (CA-556) that CA-513 had left triplicated across the three `pattern_extract_titles` arms. Nothing hand-rolls a `/^```/` toggler. |
| L10-012 | plugins/edm/bin/edm-gateguard:55 | Each `bin/` script defines its own two-argument `die()`. This is a deliberate family convention, not accidental duplication: the message prefix is the script's own name and the default exit code varies by contract (1 for `edm-gateguard`/`edm-hookify` because 2 means "deny" there, 2 for `edm-repo-readiness`/`edm-compare-eval`). `edm-gateguard:53-54` and `edm-repo-readiness:48-49` each record the choice and name the sibling they match. |
| L10-013 | plugins/edm/bin/edm-bash-gate:43 | The four-line `usage() { print_help "${BASH_SOURCE[0]:-$0}"; exit 0; }` wrapper repeats in every `bin/` script. It cannot be factored into `_edm-cli-lib.sh`: `_edm-cli-lib.sh:25-28` documents that `BASH_SOURCE[0]` inside a function defined in a sourced library resolves to the LIBRARY's path, so the caller must pass its own. Intentional, and the calling shape is itself smoke-checked at `wave7-smoke.sh:6644`. |
| L10-014 | plugins/edm/hooks/hooks.json:86 | The `command -v <bin> >/dev/null 2>&1 || exit 0; <bin>` guard idiom repeats across six hook commands (two in the `&& ... || true` variant). JSON has no include mechanism, each guard names a different binary, and the repetition is one short idiom rather than a logic block. Every new consumer's help text cites it as the house form. |
| L10-015 | plugins/edm/bin/edm-repo-readiness:302 | `_rr_archived_count()` uses its own `find`-based discovery rather than an `edm-state` accessor, duplicating `list_state_files()`'s layout knowledge. The comment at `:296-301` records this as the one genuinely self-detected signal and names the cause: no `edm-state` subcommand exposes archived-initiative existence (`list`/`list --paths` deliberately exclude `.archived/` per EDMV3-111). Documented, bounded, with a stated remedy. |
| L10-016 | plugins/edm/bin/edm-gateguard:124 | `edm-gateguard:124-129` and `edm-bash-gate:58-60` both do `PAYLOAD=""; IFS= read -r -d '' PAYLOAD || true; [[ -n "$PAYLOAD" ]] || ...`. Three lines, and they diverge for a stated reason: gateguard `die`s (exit 1, setup error) while bash-gate exits 0, because `edm-bash-gate:52-54` documents that "every guard below allows rather than dies" for an opt-in rules format a project may not have adopted. Different behaviour for a good reason. |
| L10-017 | plugins/edm/agents/edm-audit-synthesizer.md:5 | CA-529 verified closed. All fifteen `agents/edm-audit-*.md` files, synthesizer included, carry byte-identical `tools: Glob, Grep, LS, Read, NotebookRead, WebFetch, TodoWrite, WebSearch, Write`, `model: opus`, `effort: max`, `maxTurns: 30`, `color: cyan`, `disallowedTools: Edit, NotebookEdit`. The prior silent divergence between the synthesizer's grant and the fourteen lenses' is not present in this tree. |
| L10-018 | plugins/edm/skills/code-audit/SKILL.md:348 | The JSONL schema line is repeated in all fourteen lens agents plus `skills/code-audit/SKILL.md` and is byte-identical modulo the lens ID (`L{N}` in the skill, the concrete ID in each agent). This is the deliberate stale-cache survival property recorded at D22/CA-130, with a smoke-test identity check guarding the copies. Verified no drift across all fifteen occurrences. |
