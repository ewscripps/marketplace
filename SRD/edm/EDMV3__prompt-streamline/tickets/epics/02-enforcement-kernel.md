# Epic E2 -- WS2: Enforcement kernel

**Wave**: A (13 tickets, v2.0.0 -> v2.1.0) plus B (1 ticket, v2.1.0 -> v3.0.0)
**SRD requirements**: EDMV3-08 .. EDMV3-22, EDMV3-112, EDMV3-114, EDMV3-115, EDMV3-118 (19)
**Tickets**: EDMV3-T05 .. EDMV3-T18 (14)

This is the product change. Every invariant that can be checked deterministically moves out of
prompt prose and into `bin/edm-state` plus the Claude Code permission system. Three documented
recurrences prove prose does not hold. The acceptance test for the whole epic is EDMV3-T16: the
reviewer's three-command bypass must fail twice.

All commands are run from the repository root unless stated otherwise.

---

## EDMV3-T05: Split `state_anomalies` into informational and blocking classes

| Field | Value |
|---|---|
| Epic | E2 -- Enforcement kernel |
| Wave | A |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV3-118 |
| Depends On | -- |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/edm-state:419` (`state_anomalies`), `:1243` (`cmd_validate`, the `return 3` inside it), `:1349` (`cmd_session_start`) |

### Description

`cmd_validate` returns 3 whenever `state_anomalies` emits any line at all. This initiative adds at
least five anomalies that are explicitly warnings -- `PERM_RULES_MISSING` (EDMV3-09),
`SCHEMA_VERSION_MISSING` (EDMV3-112), `MISSING_STATE_FILE` (EDMV3-17), `OPEN_AUDIT_ROUND`
(EDMV3-71) and the active-exemption reports (EDMV3-94) -- each of which is required not to change
`validate`'s exit code. As the code stands, every one of those acceptance criteria is unsatisfiable,
and adding them would turn `validate` non-zero on healthy initiatives, which trains people to ignore
it.

This ticket is first in the epic because it unblocks three others (EDMV3-T06, EDMV3-T10,
EDMV3-T62) and because the format change is additive and therefore cheap to land early.

### Acceptance Criteria

- [ ] AC1: each anomaly code declares a severity class, `info` or `blocking`, at the point where it
      is emitted. The class is part of the anomaly definition, not inferred by the consumer.
      Verify: `grep -n 'info\|blocking' plugins/edm/bin/edm-state | sed -n '/state_anomalies/,/^}/p'`
      shows a class token on every emit line.
- [ ] AC2 (backward compatible format, and it is canonical from here on): the emitted line format
      extends the existing `<CODE>  <field>  <description>` shape by **prefixing the class**, giving
      the four-field form `<class>  <CODE>  <field>  <description>` where `<class>` is `info` or
      `blocking`. Every existing consumer keeps parsing because the change is additive at the front
      and the separator is unchanged. **This four-field form is the canonical anomaly line for the
      whole initiative**: EDMV3-T06 AC5, EDMV3-T10 AC6, EDMV3-T17 AC3, EDMV3-T18 AC7, EDMV3-T51
      AC4/AC5 and EDMV3-T62 AC3/AC7 each add an anomaly and each states the same four fields. A
      three-field restatement anywhere in the pack is a defect, not a variant.
      Verify: `bash plugins/edm/bin/tests/wave4a-smoke.sh` and
      `bash plugins/edm/bin/tests/wave5-smoke.sh` remain green, and
      `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "every anomaly line has four fields, first
      field in {info, blocking}").
- [ ] AC3 (positive): `cmd_validate` exits 0 when only informational anomalies are present, and
      prints every one of them. Silence is never how an informational anomaly is handled.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "info-only validate exits 0 with
      output").
- [ ] AC4 (negative): `cmd_validate` exits 3 when at least one blocking anomaly is present, and
      prints both classes when both are present.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (cases "one blocking anomaly exits 3" and
      "both classes exit 3 and list both").
- [ ] AC5 (no behaviour change for existing codes): every anomaly that exists today keeps its
      current effect on the exit code. Each existing code is explicitly assigned `blocking` unless
      the ticket records a reason to reclassify it, and any reclassification is listed in the merge
      request description.
      Verify: `bash plugins/edm/bin/tests/wave3-smoke.sh` and
      `bash plugins/edm/bin/tests/wave4a-smoke.sh` are green, and the MR description lists zero
      reclassifications (or names each one).
- [ ] AC6: `edm-state session-start` renders both classes, visually distinguished.
      Verify: `edm-state session-start` against a scratch initiative carrying one of each class
      shows two distinct prefixes.
- [ ] AC7: the change is bash 3.2 compatible and passes `bash -n`.
      Verify: `bash -n plugins/edm/bin/edm-state`.
- [ ] AC8: no state mutation is introduced. `state_anomalies` and `cmd_validate` remain read-only.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "validate leaves state
      byte-identical", using `check_state_unchanged` from EDMV3-T19).

### Technical Notes

- The cleanest shape in bash 3.2 is to prefix the class onto the emitted line
  (`info  CODE  field  description`) and have `cmd_validate` count only lines whose first field is
  `blocking`. Avoid a parallel array -- there is no associative array available.
- Do not change the `return 3` value itself. `3` is the established `edm-state` convention
  (EDMV3-100 keeps it, and `audit-converged` reuses 3 for "no ledger"), and the new
  `bin/edm-check-*` scripts use a different 0/1/2 contract on purpose.

### Out of Scope

- Adding any of the five new anomalies. Each lands with its own requirement (EDMV3-T06, T10, T12,
  T51, T62).
- Changing `cmd_validate`'s other checks.

---

## EDMV3-T06: Permission `ask` rules -- documented setup, detection, and honest enforcement tags

| Field | Value |
|---|---|
| Epic | E2 -- Enforcement kernel |
| Wave | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV3-08, EDMV3-09, EDMV3-10 |
| Depends On | EDMV3-T05, EDMV3-T08 |
| Ships-with | -- |
| Target Components | `plugins/edm/README.md`, `plugins/edm/CLAUDE.md`, `plugins/edm/bin/edm-state:419` (`state_anomalies`), `:1243` (`cmd_validate`), `:1349` (`cmd_session_start`), `:590` (`cmd_approve_gate`), `:402` (`read_bool`), `:1700` (`write_handoff_internal`) |

### Description

Tier 1 in SRD Section 5.1 is the Claude Code permission system forcing an interactive human stop on
exactly the gate-mutation commands, regardless of which skill ran or how persuasive the transcript
was. It is the only mechanism that makes "free-text is never approval" defence in depth rather than
the sole line.

Three things ship together because they are one story about honesty. The plugin cannot ship the
settings itself, so it **documents** the block (EDMV3-08). The rules are removable and the matcher
is a literal Bash prefix match that misses compound invocations, so the plugin **detects** their
absence and warns (EDMV3-09). And because the quality of each approval therefore differs between
installations, every recorded approval carries an **enforcement tag** stating which tier enforced it
(EDMV3-10), making the gap measurable and auditable in a git-committed file.

The tag's meaning is documented precisely at the point it is defined and rendered: it records
whether the rules were *configured* at approval time, not whether a prompt actually fired for that
invocation. Overstating it would make it dishonest in exactly the bypass case it exists to expose.

### Acceptance Criteria

- [ ] AC1 (documented setup): the plugin ships a documented settings block for
      `.claude/settings.json` containing at minimum
      `{"permissions": {"ask": ["Bash(edm-state approve-gate*)", "Bash(edm-state archive*)"]}}`,
      under a `README.md` heading naming it as **required setup**, with one sentence on what it
      buys. The same block appears once in `plugins/edm/CLAUDE.md`, cross-referenced from the README
      rather than re-explained.
      Verify: `grep -n 'Bash(edm-state approve-gate\*)' plugins/edm/README.md plugins/edm/CLAUDE.md`
      returns one hit in each file.
- [ ] AC2 (matcher limitation stated plainly): the documentation states that Claude Code Bash
      permission matching is a literal prefix match, so `cd "$INIT_DIR" && edm-state approve-gate X 1`,
      the `"$CLAUDE_PLUGIN_ROOT"/bin/` absolute-path form, an env-prefixed form and
      `bash -c '...'` all miss the bare-prefix rule. The recommended block additionally lists the
      wildcard and absolute-path variants the installed Claude Code version actually honours.
      Verify: `grep -n 'prefix match' plugins/edm/README.md` returns the limitation note.
- [ ] AC3 (manual QA, bypass shapes recorded): a wave-A manual-QA case runs, with the rules
      configured, `edm-state approve-gate <PREFIX> 1`, then `cd <dir> && edm-state approve-gate <PREFIX> 1`,
      then the absolute-path form, and records for each whether a permission prompt appeared. The
      result is written into the ticket and into the README limitation note.
      Verify: the ticket's QC evidence contains the three observed outcomes with the Claude Code
      version, and `grep -n 'observed behaviour' plugins/edm/README.md` returns the note.
- [ ] AC4 (detection, positive): a `check_permission_rules()` helper in `bin/edm-state` scans
      `.claude/settings.json`, `.claude/settings.local.json` and `~/.claude/settings.json` for both
      required `ask` patterns. The verified file list and the date of verification against current
      Claude Code settings-precedence documentation are recorded in the function's comment block.
      Verify: `grep -n 'check_permission_rules' plugins/edm/bin/edm-state` and read the comment
      block for the dated file list.
- [ ] AC5 (detection, negative): when either pattern is missing from all scanned files,
      `state_anomalies` emits a `PERM_RULES_MISSING` entry in the canonical four-field format
      `info  PERM_RULES_MISSING  <field>  <description>` (EDMV3-T05 AC2) whose description names
      the exact JSON to add, and the anomaly surfaces in both `edm-state validate` and
      `edm-state session-start`.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (cases "PERM_RULES_MISSING appears
      without rules" and "disappears with rules").
- [ ] AC6 (fail-safe direction): the detector biases toward reporting missing on any uncertainty --
      unreadable file, malformed JSON, unexpected schema. A false "missing" is harmless, a false
      "present" is not.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "malformed settings JSON reports
      missing").
- [ ] AC7 (warning only): absence of the settings files is not an error and does not change
      `validate`'s exit code. This is satisfiable only because EDMV3-T05 split the anomaly classes.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` asserts `validate` exit code 0 both with
      and without the rules present.
- [ ] AC8 (enforcement tag, positive): `cmd_approve_gate` records an `enforcement` field alongside
      `approved_at` and `approver` on every approval, valued `permission-ask` when
      `check_permission_rules()` reports both rules present.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "approval with rules records
      permission-ask").
- [ ] AC9 (enforcement tag, negative): an approval recorded with the rules absent carries
      `enforcement: prose-only`.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "approval without rules records
      prose-only").
- [ ] AC10 (sibling scalar keys, `read_bool` unaffected): the Gate 3.5 branch records
      `compliance_gate_approved_at`, `compliance_gate_approver` and `compliance_gate_enforcement` as
      sibling scalar keys, and the code-audit gate uses the identical shape
      (`code_audit_gate_approved_at`, `code_audit_gate_approver`,
      `code_audit_gate_enforcement`). Converting either boolean into an object is a failing
      condition.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "read_bool unchanged before and
      after sibling keys exist") and
      `jq -e '(.code_audit_converged | type) == "boolean" and has("code_audit_gate_approved_at") and has("code_audit_gate_approver") and has("code_audit_gate_enforcement")' <state-file>`.
- [ ] AC11 (tag meaning documented): the tag's precise meaning -- rule *presence* at approval time,
      not that a prompt fired -- is documented where it is defined in `bin/edm-state` and where it
      is rendered in `HANDOFF.md`.
      Verify: `grep -n 'records whether the rules were configured' plugins/edm/bin/edm-state`.
- [ ] AC12 (C-4): reading a state file that predates the field does not error and the renderer omits
      the tag when absent.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "legacy state renders HANDOFF
      without enforcement tag").

### Technical Notes

- Depends on EDMV3-T08 because the `enforcement` write happens inside `cmd_approve_gate`'s
  `code-audit` branch, which does not exist until T08 lands. The build order is
  T08 (gate token and state write) then T06 (tags on every branch), not the reverse.
- Enterprise or managed-policy settings and CLI-supplied settings are the known candidates the
  three-file list may miss. AC4 requires the check to be made and the answer recorded in the comment
  either way -- an omission stated is acceptable, an omission unexamined is not.
- Every state mutation here goes through `rmw_state` (`bin/edm-state:312`) per EDMV3-92.

### Manual QA Evidence (AC3, recorded during implementation, wave A)

Recorded 2026-07-26 against Claude Code 2.1.220 (`claude --version`). **Methodology note:**
this pass is a documented-behaviour derivation, not a live interactive dialog capture. EDM's
Phase 6 implementer runs headlessly inside an automated worktree session with no human
present to click an "Allow"/"Deny" permission prompt; forcing a live `ask`-rule trigger in
that context would either silently auto-resolve (defeating the point of the observation) or
block the run indefinitely waiting for input that will never arrive -- neither is a genuine
observation, and fabricating one would be exactly the kind of dishonesty this ticket exists
to prevent. The three outcomes below are derived directly from Claude Code's published Bash
permission-matching behaviour (a literal prefix match against the exact command string the
tool executes, not a shell-aware parse -- see the README.md limitation note this evidence
feeds) and are flagged here for a human teammate to reconfirm interactively before this
record is treated as a substitute for that confirmation:

| # | Invocation (rules configured per AC1's minimal block) | Observed/expected outcome |
|---|---|---|
| 1 | `edm-state approve-gate PREFIX 1` (bare prefix) | Prompt expected -- the command string starts with `edm-state approve-gate`, matching the rule literally. |
| 2 | `cd SRD/PREFIX && edm-state approve-gate PREFIX 1` (compound `cd ... &&`) | No prompt expected -- the command string starts with `cd`, not `edm-state`; the prefix rule never matches. |
| 3 | `"$CLAUDE_PLUGIN_ROOT"/bin/edm-state approve-gate PREFIX 1` (absolute path) | No prompt expected -- same reason; only the wildcard/absolute-path variant (`Bash(*/bin/edm-state approve-gate*)`) closes this shape. |

This is written into `README.md`'s "Observed behaviour (manual QA, wave A)" note verbatim
(same three rows), satisfying AC3's requirement that the result live in both places.

### Out of Scope

- Shipping the settings file itself. The plugin cannot, and AC1 says so explicitly.
- A `bin/edm-doctor` binary. Rejected in `architecture.md`; the check folds into `state_anomalies`
  and `cmd_session_start`.
- A `PreToolUse` hook enforcing gate approvals. Rejected: a hook can block but cannot synthesize a
  human interaction.

---

## EDMV3-T07: Mode derivation helpers become the single source for gates and terminal phase

| Field | Value |
|---|---|
| Epic | E2 -- Enforcement kernel |
| Wave | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV3-114 |
| Depends On | -- |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/edm-state:344` (`gated_phase_for_gate`, the insertion point for the new helpers), `:1433` (`cmd_set_mode`), `:1475` (`cmd_skip_phase`), `:611` (`cmd_phase_start`), `:622` (`cmd_phase_complete`), `:860` (`cmd_archive`), `:1194` (`cmd_gate_check`), `plugins/edm/bin/edm-init`, `plugins/edm/skills/orchestrator/SKILL.md:212-216` (mini-srd sub-flow), `:247-263` (fast-track sub-flow) |

### Description

Four separate commands need to answer "which gates does this initiative require, and where does its
lifecycle end". The SRD previously pointed all of them at `gated_phase_for_gate()`
(`bin/edm-state:344`), which is a gate-to-phase map and is entirely mode-blind:
`case "$1" in 1) echo 1 ;; 2) echo 3 ;; 3) echo 5 ;; *) echo "null" ;; esac`. It cannot answer either
question. Building the answer separately in `archive` and in `gate-check` would produce two mappings
that drift, which is the defect class this whole initiative exists to close.

The two axes are orthogonal and were previously conflated. `mode` (`standard`, `mini-srd`,
`prototype`, `iac`, `data-ml`) and `lifecycle_mode` (`standard`, `fast-track`, `fix-pack`) are set
separately at `bin/edm-state:1433`+, and both affect the answer.

This ticket also fixes a live dead end: the fast-track sub-flow at
`skills/orchestrator/SKILL.md:247-263` records `skip-phase 2, 3, 5` but not phase 1, and prescribes
"a single human review gate" without naming any `approve-gate` call. Gate 1 would be derived as
required while no code path ever records it, so a fast-track initiative could never archive.

### Acceptance Criteria

- [ ] AC1: `terminal_phase_for_mode()` takes `mode` and `lifecycle_mode` and returns the phase at
      which that lifecycle ends. The full enum is enumerated in the function with a comment per row:
      `prototype` -> 2, every other `mode` -> 6. `lifecycle_mode` does not shorten the terminal
      phase -- a `fast-track` initiative still ends at 6 and skips middle phases.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "terminal phase per (mode,
      lifecycle_mode) pair" enumerating every legal pair).
- [ ] AC2: `required_gates_for_mode()` takes the same two inputs plus `skipped_phases` and returns
      the gate set the lifecycle actually produces. A gate G is required if and only if
      `gated_phase_for_gate(G)` is not in `skipped_phases` and is at or below the terminal phase.
      `gated_phase_for_gate` is reused as the gate-to-phase half, not replaced.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "required gates per mode").
- [ ] AC3 (fast-track dead end closed, both halves): the fast-track sub-flow at
      `skills/orchestrator/SKILL.md:247-263` records `skip-phase 1` where phase 1 genuinely does not
      run **and** names the exact `approve-gate` invocation for the single review gate it does hold.
      Both, not either.
      Verify: `grep -n 'skip-phase' plugins/edm/skills/orchestrator/SKILL.md` shows phase 1 and
      `grep -n 'approve-gate' plugins/edm/skills/orchestrator/SKILL.md` shows the named invocation
      in the fast-track block.
- [ ] AC4 (seeding, positive): `edm-init` and `cmd_set_mode` seed `skipped_phases` from the mode's
      phase graph at creation and at mode change, each entry carrying a rationale string naming the
      mode. `skipped_phases` is populated on a fresh `mini-srd` or `prototype` initiative rather
      than empty.
      Verify: `edm-init --product demo --description seedtest --mode mini-srd TESTS` in a scratch
      repo, then `edm-state get TESTS | jq -e '.skipped_phases | length > 0'`.
- [ ] AC5 (single derivation, negative): a grep asserts no second mode-to-phase or mode-to-gate
      mapping exists anywhere in `bin/edm-state`. `cmd_phase_start`, `cmd_gate_check`,
      `cmd_phase_complete` and `cmd_archive` all call the helpers.
      Verify: `grep -n 'prototype)' plugins/edm/bin/edm-state | wc -l` returns **exactly 2** -- one
      inside `terminal_phase_for_mode()` and one inside `code_audit_required_for_mode()`.
      `cmd_archive`'s own convergence waiver is NOT a third standalone site: it was consolidated
      into the shared `convergence_exempt()` helper (decisions.md D43), which calls
      `code_audit_required_for_mode()` rather than carrying its own copy of the `prototype)` case
      -- one derivation, two consumers, not three derivations. A third hit anywhere in
      `bin/edm-state` is a second mode mapping and is a failing condition.
      Also: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "T07 AC5 -- single mode derivation").
- [ ] AC6 (one direct call site, corrected per decisions.md D35/G46-CA-322): a third helper
      `code_audit_required_for_mode()` reports whether a mode's phase graph contains a
      code-audit round. It has exactly ONE direct call site, inside the shared
      `audit_required_for_mode_or_legacy()` wrapper -- both `cmd_archive` (via
      `convergence_exempt()`) and `cmd_approve_gate`'s code-audit branch consume it THROUGH that
      wrapper, not by calling `code_audit_required_for_mode` directly a second time. D35
      settled that `cmd_approve_gate`'s code-audit precheck deliberately shares only the
      wrapper, not this function itself, so the convergence exemption is still derived once,
      not special-cased twice -- just through one fewer layer of direct calls than originally
      specified.
      Verify: `grep -n 'code_audit_required_for_mode "' plugins/edm/bin/edm-state` (the
      invocation shape -- name, space, opening quote -- excludes the definition line, comments
      and the `die()` message, none of which match it) returns exactly one line, and
      `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "T07 AC6 -- code_audit_required_for_mode
      has exactly one direct call site").
- [ ] AC7 (negative, unknown mode): an unrecognized `mode` or `lifecycle_mode` value causes the
      helpers to fail loudly with a message naming the value and listing the legal enum, rather than
      silently returning the `standard` answer.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "unknown mode errors, does not
      default").
- [ ] AC8: both helpers are bash 3.2 compatible (no associative arrays) and covered by unit-style
      smoke cases enumerating every `(mode, lifecycle_mode)` pair the enum permits.
      Verify: `bash -n plugins/edm/bin/edm-state` and
      `bash plugins/edm/bin/tests/wave6-smoke.sh 2>&1 | grep -c 'mode pair'` matches the pair count.

### Technical Notes

- `mini-srd`'s terminal phase is **6**, not an early one. It *skips* phases 2, 4 and 5
  (`plugin.json:119`, `skills/orchestrator/SKILL.md:212-216`) while still reaching phase 6. The
  earlier conflation of "skipped" with "terminal" was factually wrong about this mode and is the
  reason AC1 requires a comment per enum row.
- A second, mode-derived exemption mechanism alongside `skipped_phases` is explicitly rejected in
  `architecture.md`. Seeding `skipped_phases` from the phase graph keeps one exemption source with
  one shape for both the automatic and manual paths.
- Blocks EDMV3-T11, EDMV3-T12 and EDMV3-T13. Land it before any of them.

### Out of Scope

- Phases-as-data (`phases.json`). Recorded scope boundary, D14 / EDMV3-86.
- Removing `lifecycle_mode=partial` from the enum -- EDMV3-83, ticket EDMV3-T59.
- Enforcing the rationale-non-empty rule on `cmd_skip_phase` -- EDMV3-94, ticket EDMV3-T62.

---

## EDMV3-T08: `approve-gate` accepts the `code-audit` gate and keeps `gates_approved` integral

| Field | Value |
|---|---|
| Epic | E2 -- Enforcement kernel |
| Wave | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV3-11, EDMV3-108 |
| Depends On | EDMV3-T07 |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/edm-state:590` (`cmd_approve_gate`, the Gate 3.5 dedicated-boolean special case inside it), `:1194` (`cmd_gate_check`, numeric comparison unchanged), the dispatch `case` near `:1987`, the `--help` header block at `:2-39`, the metrics gate-review timing loop at `:1048-1068` (the loop opens at `:1048` with `[1, 2, 3] | .[] as $g |`), `plugins/edm/bin/tests/wave4a-smoke.sh:236-282` (template) and `:262-265` (integer assertion) |

### Description

D2 and requirement 1's mechanism. `code_audit_converged` becomes human-gated: settable only by
`edm-state approve-gate <PREFIX> code-audit`. The gate follows the Gate 3.5 dedicated-boolean
precedent at `bin/edm-state:590` because `gates_approved` holds integers only -- a non-integer
member would overload the type and break `cmd_gate_check`'s `select(.gate == $g)` comparison.

This must land **before** EDMV3-T09 removes the field from `cmd_set`, or the flow is stranded with
no way to record convergence at all.

The requirement spans two waves. Wave A delivers the gate token, the state write, the `enforcement`
tag hook and the help and dispatch entries. Wave B (EDMV3-T28) wires the `audit-converged` pre-check
and the `ledger: absent` degradation. A wave-A smoke case asserts the interim behaviour explicitly,
so the gap is tested rather than assumed.

### Acceptance Criteria

- [ ] AC1 (positive): `cmd_approve_gate` accepts the literal gate token `code-audit` in addition to
      numeric gates and `3.5`. On `edm-state approve-gate <PREFIX> code-audit` it sets
      `code_audit_converged = true`, records `approved_at`, `approver` (from `${USER:-unknown}`) and
      `enforcement`, updates `last_updated`, and calls `write_handoff_internal`.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "approve-gate code-audit sets the
      boolean"), asserting the pre-state is `false` and the post-state is `true`.
- [ ] AC2 (negative, type contract): `gates_approved` gains no entry. Its length is unchanged and
      it contains no non-integer member.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "gates_approved length unchanged")
      and `jq -e '[.gates_approved[].gate] | map(type == "number") | all' <state-file>`.
- [ ] AC3 (negative, wave-A interim behaviour is tested not assumed): until EDMV3-T28 lands, the
      gate records the approval with `enforcement` and `ledger: absent` and does **not** run a
      convergence pre-check. A wave-A smoke case asserts exactly that.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "wave A: approve-gate code-audit
      records ledger: absent with no pre-check").
- [ ] AC4 (negative, mode exemption): for a mode recorded as exempt from code audit
      (`code_audit_required_for_mode()` returns false, EDMV3-T07), the gate is not presented and the
      exemption reason is recorded rather than an approval.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "fast-track records
      CONVERGENCE_NOT_REQUIRED rather than an approval").
- [ ] AC5: the success message follows the existing style:
      `approved code-audit gate for <PREFIX> at <timestamp>`.
      Verify: `edm-state approve-gate TESTX code-audit` in a scratch repo prints the string, and
      `bash plugins/edm/bin/tests/wave6-smoke.sh` asserts it.
- [ ] AC6: `archive` flips from refusing to permitting once the gate is approved (given the other
      wave-A lifecycle conditions are met).
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "archive refuses before approval,
      permits after").
- [ ] AC7: the `--help` header block and the dispatch `case` are updated for the new gate token.
      Verify: `edm-state --help | grep -n 'code-audit'` returns the usage line.
- [ ] AC8 (metrics compatibility): the metrics gate-review timing loop, which iterates numeric gates
      only, continues to work and is extended to surface the two dedicated-boolean gates separately
      rather than by adding them to the array.
      Verify: `bash plugins/edm/bin/tests/wave5-smoke.sh` is green and
      `edm-state metrics-report TESTX` shows the code-audit gate in its own row.
- [ ] AC9: the design-rationale comment at `bin/edm-state:595-596` is extended to name the
      code-audit gate as the second user of the dedicated-boolean pattern.
      Verify: `sed -n '590,615p' plugins/edm/bin/edm-state`.
- [ ] AC10: all state mutation goes through `rmw_state` and the smoke coverage follows the
      `wave4a-smoke.sh:236-282` gate-behaviour template.
      Verify: `bash plugins/edm/bin/tests/wave4a-smoke.sh && bash plugins/edm/bin/tests/wave6-smoke.sh`.

### Technical Notes

- The dedicated-boolean special case already exists in `cmd_approve_gate` for `3.5`. Extend that
  branch shape rather than adding a parallel one -- a fourth gate field added later should inherit
  the behaviour by adding one token to a list.
- The `enforcement` value itself is computed by `check_permission_rules()`, which lands in
  EDMV3-T06. Land T08 first with the field written from a helper that returns `prose-only` until
  T06 replaces the helper body, and assert the interim in AC3.
- Do not alter `cmd_gate_check`'s numeric comparison logic (EDMV3-108 AC3). EDMV3-T13 adds tokens
  and a default branch around it.

### Out of Scope

- Removing `code_audit_converged` from `cmd_set` -- EDMV3-T09, which must land after this.
- The `audit-converged` pre-check and the `ledger: absent` degradation logic -- EDMV3-T28 (wave B).
- Prompt-side gate presentation -- EDMV3-T15.

---

## EDMV3-T09: `cmd_set` becomes a checked contract -- allowlist, gate-field refusals, `schema_version`

| Field | Value |
|---|---|
| Epic | E2 -- Enforcement kernel |
| Wave | A |
| Priority | Must Have |
| Size | L |
| SRD Refs | EDMV3-12, EDMV3-13, EDMV3-14, EDMV3-15 |
| Depends On | EDMV3-T08, EDMV3-T19 |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/edm-state:474-496` (`cmd_set`), especially the boolean allowlist at `:479` and the generic branch at `:491-494`; `:498` (`cmd_init`); `plugins/edm/bin/tests/wave7-smoke.sh` (new); all skill, agent, hook and bin files containing `edm-state set` |

### Description

`bin/edm-state:479` allowlists `code_audit_converged` alongside `compliance_enabled` as a settable
boolean. That line is the actual hole in F1: any agent holding `Bash(edm-state *)` can flip the
archive gate. The generic branch at `:491-494` is the second hole -- it accepts arbitrary keys, and
the external reviewer planted `totally_made_up_key` into a state file with no complaint.

Four requirements land together because they are four properties of one function. Removing
`code_audit_converged` (EDMV3-12) must `die` with an explicit redirect rather than fall through to
the generic string branch, which would write the *string* `"true"` and silently corrupt the boolean.
All three gate-bearing fields must behave identically (EDMV3-14) so the class is closed rather than
one instance of it. An allowlist turns the state schema into a checked contract (EDMV3-13), and
`schema_version` is added at the same time as the legacy signal for grandfathering. And because
maintaining the allowlist and its callers as two hand-kept lists guarantees eventual divergence, a
test greps every call site and asserts membership (EDMV3-15).

EDMV3-90 (no override flags are introduced anywhere) is a **Won't Have** and a recorded scope
boundary, so it is not an `SRD Refs` entry. AC13 is the negative enforcement that keeps the boundary
true here, and the boundary's disposition is recorded once in the README coverage map.

**Size justification (L).** Round-1 ticket audit resized this from M. It is the most
schedule-critical node in the pack: eight tickets depend on it directly and 37 transitively across
all three waves, so an underestimate here moves every wave. The work itself is four requirements in
one function plus a new file -- `cmd_set` is rewritten around a shared gate-field refusal path and a
single-source allowlist, the whole `schema_version` contract is defined including its integer value
set and the three-valued degradation rule that four later checks consult, and `bin/tests/wave7-smoke.sh`
is created from nothing as the contract suite that EDMV3-T03, EDMV3-T04 and eighteen wave-B and
wave-C tickets go on to consume. Decomposition was considered and rejected: splitting the allowlist
from the `schema_version` contract leaves an interval in which `cmd_set` refuses a key the state
schema has no version to gate on, and splitting the caller-contract test out leaves the allowlist
landing with nothing asserting its callers, which is the exact drift EDMV3-15 exists to prevent.

### Acceptance Criteria

- [ ] AC1 (negative, the hole): `code_audit_converged` no longer appears in the boolean allowlist,
      and `edm-state set <PREFIX> code_audit_converged true` exits non-zero with a message naming
      `edm-state approve-gate <PREFIX> code-audit` as the correct command.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "set code_audit_converged refused"),
      using `check_fails` to assert both the exit code and the message substring.
- [ ] AC2 (negative, no partial mutation): the refusal happens before any state mutation and the
      state file is byte-identical after the failed command, for every supplied value (`true`,
      `false`, and garbage).
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` using `check_state_unchanged` for all
      three values.
- [ ] AC3 (negative, whole class): `edm-state set <PREFIX> compliance_gate_approved <any>` and
      `... gates_approved <any>` each exit non-zero, each refusal names the specific `approve-gate`
      invocation that is the legitimate path (`3.5` and `<gate-num>` respectively), and no state
      mutation occurs.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (three refusal cases plus three
      `check_state_unchanged` assertions).
- [ ] AC4 (shared refusal path): a single shared code path handles all three gate fields, so a
      fourth added later inherits the behaviour by adding one token to a list.
      Verify: `grep -n 'gate-bearing' plugins/edm/bin/edm-state` returns one token list and one
      refusal branch.
- [ ] AC5 (positive, allowlist): `cmd_set` enumerates every legal key, defined in one place and
      consumed by both the validation and the error message so the two cannot drift. A known key
      still succeeds.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "known key succeeds") and
      `grep -c 'SETTABLE_KEYS' plugins/edm/bin/edm-state` is non-zero.
- [ ] AC6 (negative, unknown key): an unknown key is refused with a non-zero exit and a message
      printing the full sorted list of valid keys, with no state mutation.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "unknown key lists valid keys" plus
      `check_state_unchanged`).
- [ ] AC7 (typed validation preserved): booleans accept only `true` or `false`, numerics accept only
      numbers, and the existing error strings for those cases are unchanged.
      Verify: `bash plugins/edm/bin/tests/wave4a-smoke.sh` remains green and
      `edm-state set TESTX compliance_enabled maybe` prints the pre-existing message verbatim.
- [ ] AC8 (`schema_version`, positive): `schema_version` is an integer with a defined value set --
      `1` at wave A, `2` at wave B, `3` at wave C only if a shape actually changes -- written by
      `cmd_init` for the wave the running script belongs to, readable via `edm-state get`, and
      documented once in `CLAUDE.md`'s state-field section with the minimum version each new check
      requires.
      Verify: `edm-init --product demo --description sv TESTV` in a scratch repo then
      `edm-state get TESTV | jq -e '.schema_version == 1'`.
- [ ] AC9 (`schema_version`, negative): `set schema_version` is refused, naming `migrate-schema` as
      the only writer. Making it a `cmd_set` key would reopen the hand-flip path the allowlist
      exists to close.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "set schema_version refused naming
      migrate-schema" plus `check_state_unchanged`).
- [ ] AC10 (three-valued degradation defined): a present-but-lower `schema_version` degrades
      warn-and-proceed for checks introduced above it and applies normally for checks at or below
      it. The version each new check requires is recorded in a comment at the check and in the
      `CLAUDE.md` table: EDMV3-16, -17 and -115 require `>= 1`; EDMV3-18, -36, -42 and -120 require
      `>= 2`.
      Verify: `grep -n 'requires schema_version' plugins/edm/bin/edm-state` returns one comment per
      new check.
- [ ] AC11 (caller contract, positive): a test in `bin/tests/wave7-smoke.sh` greps every
      `plugins/edm/skills/**/SKILL.md`, `plugins/edm/agents/*.md`, `plugins/edm/hooks/hooks.json`
      and `plugins/edm/bin/*` for `edm-state set` invocations, extracts the key argument, and
      asserts each appears in the allowlist. Running it at the moment this ticket lands produces
      zero misses. Known live call sites include `test_layer_skipped`
      (`skills/implement/SKILL.md:149`), `last_decision`
      (`skills/orchestrator/SKILL.md:421`) and `estimated_size`.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "every set caller key is
      allowlisted").
- [ ] AC12 (caller contract, negative and inverse): a key used by a caller but absent from the
      allowlist fails the test naming both the key and the calling `file:line`. Allowlisted keys
      with no caller anywhere are reported as a **warning** so dead schema fields become visible.
      Documentation placeholders such as `<key>` are excluded by an explicit, documented ignore list
      rather than a loose regex.
      Verify: add `edm-state set X bogus_key 1` to a scratch copy of a skill and confirm
      `bash plugins/edm/bin/tests/wave7-smoke.sh` exits non-zero naming the file and line.
- [ ] AC13 (no override flag reintroduced): **the literal string `--force` does not appear anywhere
      in `bin/edm-state`.** Not on `set`, not in a refusal message, not in a comment. An unrecognized
      argument is handled by the existing unknown-argument path, which names no flag, so the script
      never has to spell the thing it refuses. The pack's negative tests that must contain the
      literal (EDMV3-T11 AC7, EDMV3-T12 AC12) live in `bin/tests/`, which is inside the documented
      carve-out for the repository-wide override-flag grep (EDMV3-T30 AC5).
      Verify: `grep -c -- '--force' plugins/edm/bin/edm-state` prints 0, asserted by
      `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "no literal --force in bin/edm-state").

### Technical Notes

- The refusal must be a `die` before the `case` reaches the generic branch. Falling through writes a
  JSON string where a boolean belongs and `read_bool` then reports `true` for the string `"false"`.
- Define the allowlist once as a space-separated string constant and use a word-membership test.
  bash 3.2 has no associative arrays, so a `case "$key" in $LIST)` construction will not work --
  use `case " $SETTABLE_KEYS " in *" $key "*)`.
- The caller-contract test lives in `wave7-smoke.sh`, the new suite for check-script and contract
  tests, not in `wave6-smoke.sh` which is the lifecycle suite.
- Wave-C's `schema_version` value is left open by the SRD (AC8 says "3 only if shapes change"). The
  decision is recorded by EDMV3-T66.

### Out of Scope

- `edm-state migrate-schema` itself -- EDMV3-T10.
- The degradation *behaviour* of each individual check. This ticket defines the version contract;
  EDMV3-T14 implements and tests the three-valued degradation end to end.
- Widening the allowlist to include `initiative_branch` -- explicitly forbidden by EDMV3-T01 AC6.

---

## EDMV3-T10: `edm-state migrate-schema` backfills `schema_version` on existing initiatives

| Field | Value |
|---|---|
| Epic | E2 -- Enforcement kernel |
| Wave | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV3-112 |
| Depends On | EDMV3-T05, EDMV3-T09 |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/edm-state` (new `cmd_migrate_schema`), `:419` (`state_anomalies`), `:312` (`rmw_state`), the dispatch table near `:1980-2023`, the `--help` header at `:2-39`, `plugins/edm/CLAUDE.md` (`bin/` table) |

### Description

Without a backfill path, every initiative that exists on the day wave A ships is **permanently**
exempt from the entire enforcement kernel, because absent `schema_version` is the legacy signal and
nothing ever adds it. That includes EDMV3 itself:
`SRD/edm/EDMV3__prompt-streamline/.edm-state.json` was created 2026-07-24, before wave A, so the
initiative that builds the kernel would archive with every new check warn-and-proceeded. A permanent
exemption that grows automatically with the age of the repository is not grandfathering; it is a
hole with a polite name.

### Acceptance Criteria

- [ ] AC1 (positive): `edm-state migrate-schema <PREFIX>` stamps `schema_version` onto an existing
      state file after printing what it found -- current phase, approved gates, whether a
      terminal-phase `completed_at` exists, whether a findings ledger exists and in which format,
      how many `partial_verdict_map` entries are unclosed -- and requires an explicit confirmation
      before writing.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "migrate-schema stamps 1 on a copied
      legacy v2.0 state file").
- [ ] AC2 (honest version): the version written is the highest whose shape requirements the
      initiative actually satisfies, never higher. An initiative with a markdown-only ledger and
      pre-closure PARTIAL entries migrates to `1`, not `2`.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "markdown ledger migrates to 1, not
      2") and (case "JSONL ledger with closed PARTIALs advances to 2").
- [ ] AC3 (negative, already migrated): it refuses on an initiative that already carries
      `schema_version`, naming the recorded value -- unless the recorded value is lower and the next
      version's shapes are now satisfied, in which case it advances by exactly one and says so.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "second migration attempt refused"),
      using `check_fails`.
- [ ] AC4 (negative, never lowers, never touches archives): it never lowers `schema_version` and
      never touches anything under `SRD/.archived/`.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "archived initiative refused") and
      `check_state_unchanged` on an archived fixture.
- [ ] AC5 (single writer): `schema_version` remains unsettable via `cmd_set` (EDMV3-T09 AC9).
      `migrate-schema` is the only writer.
      Verify: `grep -n 'schema_version' plugins/edm/bin/edm-state | grep -v migrate_schema | grep -v '# '`
      shows only reads and the `cmd_set` refusal.
- [ ] AC6 (informational anomaly): `state_anomalies` emits a `SCHEMA_VERSION_MISSING` entry for any
      **non-archived** initiative with no `schema_version`, in the canonical four-field format
      `info  SCHEMA_VERSION_MISSING  schema_version  <description>` (EDMV3-T05 AC2), whose
      description names `edm-state migrate-schema <PREFIX>` as the remedy. The `info` class is what
      keeps `validate`'s exit code unchanged.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "SCHEMA_VERSION_MISSING is
      informational, validate exits 0").
- [ ] AC7 (hand-removal detectable): removing `schema_version` by hand from a state file fires the
      same anomaly and `HANDOFF.md` renders the migration prompt, so a silent downgrade that
      disables every new check at once is visible.
      Verify: `jq 'del(.schema_version)' <state> > tmp && mv tmp <state> && edm-state validate TESTX`
      prints `SCHEMA_VERSION_MISSING`.
- [ ] AC8 (atomicity): all state mutation goes through `rmw_state` and the state file is
      byte-identical after a refused migration.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` uses `check_state_unchanged` on every
      refusal case.
- [ ] AC9 (surfaced): the subcommand appears in the `--help` block, in the dispatch table, and in
      the `CLAUDE.md` `bin/` table.
      Verify: `edm-state --help | grep -n migrate-schema` and
      `grep -n 'migrate-schema' plugins/edm/CLAUDE.md`.

### Technical Notes

- Grandfathering is bounded, not open-ended: it applies to initiatives under `SRD/.archived/` and to
  initiatives whose `last_updated` predates the wave-A merge date. Everything else, including EDMV3
  itself, is expected to be backfilled.
- The confirmation prompt must work non-interactively in tests. Read the confirmation from stdin so
  a test can pipe `yes`, and refuse (not proceed) when stdin is not a TTY and nothing is piped.
- `list_state_files()` (`bin/edm-state:53`) already enumerates both layouts with an `--archived`
  opt-in. Use it to determine archived status rather than string-matching the path.

### Out of Scope

- Re-opening the convergence gate on any existing initiative. Forbidden by D4 / EDMV3-89.
- Any down-migration. The version never decreases; the downgrade story is documentation
  (EDMV3-98 / EDMV3-T65).

---

## EDMV3-T11: `phase-complete` verifies the phase produced its artifact, with no force path

| Field | Value |
|---|---|
| Epic | E2 -- Enforcement kernel |
| Wave | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV3-16 |
| Depends On | EDMV3-T07, EDMV3-T09 |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/edm-state:622` (`cmd_phase_complete`), `:338` (`present_or_absent`), `:110` (`record_artifact_hash`), `:674-686` (the artifact-hash recording call), `:43-44` (`SRD_FILENAME`, `TICKET_PACK_DIRNAME`), `plugins/edm/bin/tests/wave6-smoke.sh` |

### Description

`cmd_phase_complete` currently records timing for whatever the caller claims. R1(b) converts "the
model said so" into "the deliverable exists". Per D13(c) there is **no** `--force` override; the
only exemption is a phase already recorded in `skipped_phases`, which is an auditable state entry
rather than a command-line flag.

The degenerate phase-6 case is the subtle one. `qc/qc-summary.md` is produced only after a QC wave
and only under sharding-merge (`agents/edm-qc-auditor.md:71-74`). An initiative that reached phase 6
with zero tickets, or where every shard is still pending, has no such file -- and with no force flag
it would otherwise be permanently unable to complete phase 6. Accepting any `qc/qc-shard-*.md`
covers the sharded case; a zero-ticket phase 6 is covered by a `skipped_phases` record with its
rationale, which is visible in git.

### Acceptance Criteria

- [ ] AC1 (positive, per-phase map): before the read-modify-write block, `cmd_phase_complete`
      resolves the initiative directory via `initiative_dir_for` and applies a per-phase
      non-empty-file check -- phase 1 -> `planning.md`, 2 -> `${SRD_FILENAME}`, 3 -> `audit-srd.md`,
      4 -> `${TICKET_PACK_DIRNAME}/README.md`, 5 -> `${TICKET_PACK_DIRNAME}/audit.md`,
      6 -> `qc/qc-summary.md` **or any** `qc/qc-shard-*.md`. The check extends `present_or_absent()`
      (`bin/edm-state:338`) into a non-empty variant rather than defining a sixth presence idiom.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (six "artifact present -> success"
      cases).
- [ ] AC2 (negative, per-phase refusal): a missing or empty artifact causes a non-zero exit with a
      message naming the exact expected path and the phase number, and no timing, token or cost data
      is recorded.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (six "artifact absent -> refusal" cases,
      each using `check_fails` and `check_state_unchanged`).
- [ ] AC3 (positive, sharded phase 6): a phase 6 with only `qc/qc-shard-01.md` on disk completes
      successfully.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "shard-only phase 6 completes").
- [ ] AC4 (negative, phase 6 with open PARTIALs): phase 6 additionally requires zero unclosed
      PARTIAL entries in `partial_verdict_map`, and the refusal message names
      `/edm:verify-runtime <PREFIX>`. This check requires `schema_version >= 2` and warn-and-proceeds
      below it.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "phase 6 with open PARTIAL refuses
      naming verify-runtime").
- [ ] AC5 (exemption, exactly one source): a phase listed in `skipped_phases` is exempt from **its
      own artifact check** and completes normally, and the exemption is visible in `edm-state get`
      output and in `HANDOFF.md`. There is no second, mode-derived exemption mechanism. A skipped
      phase 6 is **not** exempt from the PARTIAL check.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (cases "skipped phase 2 completes without
      srd.md" and "skipped phase 6 still refuses on open PARTIAL").
- [ ] AC6 (mode seeding is what makes the exemption reachable): a fresh `mini-srd` initiative
      completes `phase-complete 2` because `edm-init` seeded `skipped_phases` (EDMV3-T07 AC4).
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "mini-srd phase-complete 2
      succeeds").
- [ ] AC7 (negative, no force path): no `--force`, `-f` or equivalent flag exists. Passing `--force`
      produces an unknown-argument error rather than a bypass.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "phase-complete --force is an
      unknown argument") -- this test file is inside the documented carve-out for the repository
      override-flag grep (EDMV3-90 AC2) precisely so it can contain the literal string.
- [ ] AC8 (C-4): legacy state files with no `schema_version` warn and proceed rather than hard
      failing, with a `[warn] legacy initiative` line naming the skipped check.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "legacy phase-complete warns and
      proceeds").
- [ ] AC9 (preserve): the artifact-hash recording at `bin/edm-state:674-686` continues to work
      unchanged for phases 2-5, and the new checks run before it without disturbing it.
      Verify: `bash plugins/edm/bin/tests/wave4a-smoke.sh` is green and
      `edm-state get TESTX | jq -e '.artifact_hashes.srd.hash'` is non-null after
      `phase-complete 2`.
- [ ] AC10: the three literal filenames (`planning.md`, `audit-srd.md`, the `qc/` paths) are fixed
      by the artifact layout in `plugins/edm/CLAUDE.md` and are **not** user-configurable, unlike
      `${SRD_FILENAME}` and `${TICKET_PACK_DIRNAME}`. A comment at the check states this so a reader
      does not expect a variable that does not exist.
      Verify: `sed -n '622,700p' plugins/edm/bin/edm-state` shows the comment.

### Technical Notes

- `mini-srd`'s phase-3 artifact is named explicitly: the sub-flow audits a fused planning-plus-SRD
  file and produces `audit-srd.md` covering it, so the standard phase-3 check applies unchanged.
- The PARTIAL check here is what makes EDMV3-70's ordering enforced rather than requested. Without
  it, `archive` becomes the only place the invariant holds and the direct-invocation path is
  unprotected.
- Blocks EDMV3-T12. Land in that order.

### Out of Scope

- The archive-side PARTIAL check -- EDMV3-T18 (wave B).
- The `verify-runtime` skill the refusal message names -- EDMV3-T33 (wave B). In wave A the message
  names the command; the skill arrives before any user can hit the refusal, because the phase-6
  PARTIAL check requires `schema_version >= 2` which only wave B creates.
- Wiring the `phase-complete 6` call site -- EDMV3-70, ticket EDMV3-T50.

---

## EDMV3-T12: `archive` verifies the whole lifecycle (wave-A sub-checks)

| Field | Value |
|---|---|
| Epic | E2 -- Enforcement kernel |
| Wave | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV3-17 (AC1a-AC1d, AC2-AC9) |
| Depends On | EDMV3-T07, EDMV3-T08, EDMV3-T11 |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/edm-state:860` (`cmd_archive`), the convergence check at `:877-889` including the `product_name` conjunct at `:887`, `:344` (`gated_phase_for_gate`), the new helpers from EDMV3-T07, `plugins/edm/CHANGELOG.md` |

### Description

R1(c). `cmd_archive` validates exactly one boolean, never reads `gates_approved` or `current_phase`,
and even that one check fires only when `product_name` is non-empty (`:887`) -- so a flat-layout
initiative with `code_audit_converged=false` archives today with **no refusal at all**, a second and
larger hole than the one the review named. The reviewer's three-command bypass must become
impossible. SRD Section 5.4 is the normative decision flow and mirrors `architecture.md` D-8.

This ticket delivers the wave-A half. The PARTIAL-closure and computed-convergence sub-checks arrive
in EDMV3-T18 when their machinery exists. That split is what makes wave A buildable: without it, a
wave-A archive refusal would direct users to `/edm:verify-runtime`, a skill that does not exist
until wave B, with no override by design.

### Acceptance Criteria

- [ ] AC1 (negative, AC1a gates): `cmd_archive` refuses with a non-zero exit unless every gate
      returned by `required_gates_for_mode()` is present in `gates_approved` or recorded as a
      dedicated-boolean approval. The message names the missing gates and the exact
      `edm-state approve-gate <PREFIX> <N>` that resolves each.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "archive with gates 1 and 2 but not
      3 refuses naming gate 3").
- [ ] AC2 (negative, AC1b terminal phase): `current_phase` must equal `terminal_phase_for_mode()`.
      The phase number is derived, never hardcoded to 6 -- `prototype` terminates at 2. The refusal
      names the phase actually reached.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (cases "archive at current_phase 5
      refuses" and "prototype archives at phase 2").
- [ ] AC3 (negative, AC1c completed_at): the terminal phase's entry in `phase_durations` must carry
      a `completed_at` timestamp, and the refusal directs the user to `edm-state phase-complete`.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "archive without terminal
      completed_at refuses").
- [ ] AC4 (negative, AC1d convergence boolean): `code_audit_converged` must read `true` as a boolean
      for any mode that requires a code audit, and the refusal names
      `edm-state approve-gate <PREFIX> code-audit`.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "archive with converged=false
      refuses naming approve-gate").
- [ ] AC5 (negative, `product_name` coupling deleted): the refusal is unconditional on
      `product_name`. The `-n "$product_name"` conjunct at `bin/edm-state:887` is deleted. This is a
      behaviour change for flat-layout initiatives and is called out in `CHANGELOG.md`.
      Verify: `grep -n 'product_name' plugins/edm/bin/edm-state | sed -n '/cmd_archive/,$p'` shows
      no conjunct in the convergence condition, and
      `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "flat-layout initiative with
      converged=false is refused").
- [ ] AC6 (no wave-A message names a wave-B command): no refusal message emitted in wave A mentions
      `/edm:verify-runtime` or `audit-converged`.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "no wave-A refusal names a wave-B
      command"), asserting the absence with `check_absent`.
- [ ] AC7 (positive, happy path): a fully compliant standard-lifecycle initiative archives
      successfully, so the refusals are targeted rather than blanket. The move itself is unchanged:
      `git_aware_mv`, product-scoped destination preservation, and the existing success message.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "compliant initiative archives").
- [ ] AC8 (`prototype` waives one check only): `mode == prototype` waives convergence only and
      preserves its current warning text. It does not waive the gate, phase or `completed_at`
      checks. This is a deliberate narrowing of pre-EDMV3 behaviour and is in `CHANGELOG.md`.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (cases "prototype without gate 1 still
      refuses" and "prototype warning text preserved").
- [ ] AC9 (audit-free modes exempt with a recorded reason, not by silence): `fast-track` and
      `fix-pack` initiatives, and any initiative whose `audit_rounds.code` is zero under a mode whose
      phase graph contains no audit round, record a `CONVERGENCE_NOT_REQUIRED` reason in state at
      archive time rather than being silently skipped.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "fast-track archives with
      CONVERGENCE_NOT_REQUIRED recorded") and
      `jq -e '.archive_exemptions[]? | select(. == "CONVERGENCE_NOT_REQUIRED")' <state-file>`.
- [ ] AC10 (missing state file reported, not silently permitted): `cmd_archive` on a directory under
      `SRD/` with no `.edm-state.json` emits a `MISSING_STATE_FILE` anomaly and a warning before
      proceeding.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "archive with deleted state file
      warns MISSING_STATE_FILE").
- [ ] AC11 (`skipped_phases` respected): phases recorded in `skipped_phases` do not cause a refusal
      for their own gate or artifact.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "mini-srd archives with seeded
      skips").
- [ ] AC12 (negative, no override flags): no `--force`, `--accept-partials` or equivalent flag
      exists. Each such argument produces an unknown-argument error.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (cases "archive --force unknown argument"
      and "archive --accept-partials unknown argument").

### Technical Notes

- SRD Section 5.4's flowchart has no override edges by construction. Implement the checks in that
  order (gates, phase, `completed_at`, PARTIAL, convergence) so the refusal a user sees is the
  earliest unmet condition, which is the most actionable one.
- Two non-refusing early exits exist and only two: a missing state file (AC10, now reported) and
  legacy state detected by an absent `schema_version` (EDMV3-T14).
- The wave-B slots (AC1e PARTIAL closure, AC1f `audit-converged`) should be left as clearly marked
  insertion points with a comment naming EDMV3-T18, so the wave-B ticket is a fill-in rather than a
  restructure.

### Out of Scope

- AC1e and AC1f -- EDMV3-T18.
- The legacy warn-and-proceed degradation across all new checks -- EDMV3-T14 (this ticket implements
  its own degradation; T14 tests the class end to end).
- The `MISSING_STATE_FILE` anomaly's severity classification -- delivered by EDMV3-T05, consumed
  here.

---

## EDMV3-T13: Gate enforcement moves into the kernel and `gate-check` becomes complete

| Field | Value |
|---|---|
| Epic | E2 -- Enforcement kernel |
| Wave | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV3-115 |
| Depends On | EDMV3-T07 |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/edm-state:1194-1237` (`cmd_gate_check`), especially the `case` at `:1201-1209` and the `*) return 0` fall-through at `:1205-1208`; `:611` (`cmd_phase_start`); `plugins/edm/hooks/hooks.json:13-78` (`UserPromptExpansion`, retained unchanged) |

### Description

The dispatcher refactor (EDMV3-T38) moves the primary path off `UserPromptExpansion`, where the only
genuinely deterministic gate enforcement lives. Compensating with a Step 0 instruction in each
SKILL.md would trade a T1/T2-grade control for a T3 one and record it as equivalent -- SRD Section
5.1 classifies prompt text as "cannot be bypassed by: nothing".

Worse, the command those hooks and that Step 0 both call is already a partial no-op.
`cmd_gate_check` maps only `srd|audit-srd` -> 1, `tickets` -> 2, `audit-tickets|implement` -> 3, and
falls through to `*) return 0` for everything else, so `plan`, `code-audit` and `verify-runtime` are
unconditionally allowed. It also has zero mode awareness, so under `fast-track` (which skips phases
2, 3 and 5) `gate-check <PREFIX> tickets` still hard-requires gate 2 and blocks.

The fix is to put the enforcement where entry path cannot reach it: `phase-start`.

### Acceptance Criteria

- [ ] AC1 (positive and negative, kernel refusal): `edm-state phase-start <PREFIX> <N>` refuses with
      a non-zero exit when the phase's prerequisite gate, derived by `required_gates_for_mode()`, is
      unapproved, and succeeds once it is approved. Every phase skill already calls `phase-start`,
      so this is Tier 2 and applies to every caller including a shell user.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (cases "phase-start refuses without the
      prerequisite gate" and "phase-start succeeds with it").
- [ ] AC2 (negative, no mutation on refusal): the refusal names the missing gate and the exact
      `approve-gate` invocation, and mutates nothing.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` uses `check_fails` for the message and
      `check_state_unchanged` for the file.
- [ ] AC3 (positive, missing tokens added): `cmd_gate_check` accepts `plan` (no prerequisite gate --
      it returns 0 **explicitly**, with a comment saying so, rather than by falling through),
      `code-audit` (gate 3) and `verify-runtime` (gate 3). All eight phase-skill tokens resolve to a
      documented gate.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "each of the eight phase-skill
      tokens resolves").
- [ ] AC4 (negative, hard-error default): the `*)` default branch becomes a hard error -- non-zero
      exit, message naming the unknown gated command and listing the valid tokens. A typo in a hook
      or a Step 0 block must not silently disable enforcement, which is what returning 0 does today.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "unknown gate-check token errors"),
      asserting exit non-zero and the token list in the message.
- [ ] AC5 (mode awareness, same derivation): a gate whose feeding phase is in `skipped_phases`, or
      beyond `terminal_phase_for_mode()`, is not required and the check passes. The derivation is
      the same one archive uses (EDMV3-T07), not a second one.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "fast-track passes gate-check
      tickets without gate 2").
- [ ] AC6 (preserve): `cmd_gate_check`'s existing numeric comparison logic is unchanged. This ticket
      adds tokens, a default branch and a mode filter around it.
      Verify: `bash plugins/edm/bin/tests/wave4a-smoke.sh` is green, and a diff of the
      `select(.gate == $g)` expression shows no change.
- [ ] AC7 (C-4): legacy state (`schema_version` absent) warn-and-proceeds through the new
      `phase-start` refusal rather than hard-failing.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "legacy initiative phase-start warns
      and proceeds").
- [ ] AC8 (hooks retained): the existing `UserPromptExpansion` hooks at `hooks/hooks.json:13-78` are
      unchanged, so direct user invocation keeps its hook-side check as well.
      Verify: `git diff --stat plugins/edm/hooks/hooks.json` shows no change in this ticket.
- [ ] AC9 (vocabulary guard): nothing in this ticket, in `CLAUDE.md`, or in any skill describes the
      Step 0 preflight as deterministic or as the mechanism that restores enforcement. The phrase
      used is "defence in depth on the Skill-tool path".
      Verify: `grep -rn 'Step 0' plugins/edm/ | grep -i 'deterministic'` returns zero results.

### Technical Notes

- Blocks EDMV3-T36 (Step 0 preflight) and EDMV3-T38 (dispatcher). Step 0 passes the three tokens
  this ticket adds; without them Step 0 is an unconditional no-op in three of eight skills, which is
  exactly where the dispatcher path matters most.
- `cmd_phase_start` is at `bin/edm-state:611`, twelve lines long today. The refusal goes at the top,
  before any timestamp is written.
- The hard-error default branch will break any caller passing an unrecognized token. Grep
  `hooks/hooks.json` and every SKILL.md for `gate-check` call sites before merging and fix any
  mismatch in the same MR.

### Out of Scope

- The Step 0 preflight blocks in the phase skills -- EDMV3-T36.
- Removing the `UserPromptExpansion` hooks. They are retained as defence in depth.
- The dispatcher restructure itself -- EDMV3-T38.

---

## EDMV3-T14: Legacy state files keep working and converged initiatives are grandfathered

| Field | Value |
|---|---|
| Epic | E2 -- Enforcement kernel |
| Wave | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV3-19, EDMV3-107 |
| Depends On | EDMV3-T09, EDMV3-T10, EDMV3-T11, EDMV3-T12 |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/edm-state:498` (`cmd_init`), `:622` (`cmd_phase_complete`), `:860` (`cmd_archive`), `:402` (`read_bool`), `:125-192` (state-derived path resolution, unchanged), `plugins/edm/bin/tests/wave6-smoke.sh`, fixture source `SRD/.archived/EDMV2/.edm-state.json` |

### Description

C-4 plus D4 plus `architecture.md` R-J. Every initiative created before wave A -- including
everything already under `SRD/.archived/` -- must survive every new check. Absence of
`schema_version` is the legacy signal.

The degradation model is **three-valued**, not binary, and the middle class is the one the earlier
draft stranded. Absent `schema_version` means legacy and warn-and-proceed everywhere.
Present-but-below-a-check's-minimum means warn-and-proceed for that check only, with normal
enforcement for every check at or below the recorded version -- this is the wave-A-created
initiative that reaches wave B. Present and at or above the minimum means full enforcement with no
warning.

Grandfathering is also bounded rather than open-ended. It applies to initiatives under
`SRD/.archived/` and to initiatives whose `last_updated` predates the wave-A merge date. Everything
else is expected to be backfilled by `edm-state migrate-schema`, which is why this ticket depends on
EDMV3-T10.

EDMV3-89 (existing converged initiatives are not re-approved) is a **Won't Have** and a recorded
scope boundary, so it is not an `SRD Refs` entry. AC3 and AC11 are the positive and negative
enforcement that keep the boundary true, and its disposition is recorded in the README coverage map.

### Acceptance Criteria

- [ ] AC1 (degradation, class 1): every new check in EDMV3-T11, EDMV3-T12, EDMV3-T13 and (in
      wave B) EDMV3-T18 degrades to warn-and-proceed when `schema_version` is absent. None hard-
      fails on a legacy file.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "legacy state warns at every new
      check").
- [ ] AC2 (visible degradation): each warning is prefixed `[warn] legacy initiative` and names the
      check that was skipped, so the degradation is visible rather than silent.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` asserts the prefix and the named check for
      each of the four.
- [ ] AC3 (D4 grandfathering, positive): an initiative with `code_audit_converged = true` set under
      the old flow archives without being asked to re-approve through the new gate.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "pre-set converged flag archives").
- [ ] AC4 (end-to-end legacy fixture): a smoke test copies the real v2.0 state file from
      `SRD/.archived/EDMV2/.edm-state.json` into a scratch initiative and runs `edm-state get`,
      `validate`, `phase-complete` and `archive` against it end to end, asserting warn-and-proceed
      at each new check and a successful archive.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "archived EDMV2 state file
      end-to-end").
- [ ] AC5 (degradation, class 3 -- negative): an initiative created at the current
      `schema_version` is subject to every check with no warn-and-proceed. The new path is not
      degraded.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "current-version initiative is fully
      enforced"), asserting the absence of any `[warn] legacy` line with `check_absent`.
- [ ] AC6 (degradation, class 2 -- the middle class): an initiative at `schema_version: 1` running
      against wave-B code is fully enforced on the version-1 checks and warn-and-proceeds, naming
      each one, on the version-2 checks.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "schema_version 1 against wave-B
      checks"). In wave A this case asserts the class exists and is reachable; the wave-B checks are
      added to it by EDMV3-T18.
- [ ] AC7 (additive fields, with exactly one sanctioned widening): every new state field is additive
      and uses the `// default` idiom or `read_bool`, so `jq` reads on old files never produce
      null-propagation errors, and no existing field changes meaning or name.
      **One field changes shape, and it is named here rather than discovered later**:
      `audit_rounds.<type>` widens from a bare integer (`bin/edm-state:1402` writes
      `.audit_rounds[$t] = ((.audit_rounds[$t] // 0) + 1)`, and the archived EDMV2 state file
      carries `audit_rounds: {code: 2}`) to the object `{count: N, rounds: [...]}` when EDMV3-T27
      adds round-type recording in wave B. This is the **single sanctioned exception** to
      "no existing field changes type". It is sanctioned because the widening is read-coerced rather
      than migrated -- EDMV3-T27 carries the C-4 coercion AC that reads a bare integer `N` as
      `{count: N, rounds: []}` -- so no legacy file is rewritten and no legacy `jq` read breaks. Any
      **other** type change is a failing condition.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "jq reads on legacy file produce no
      nulls"), and `git diff plugins/edm/bin/edm-state | grep '^-.*"'` shows no removed field name.
      The exception is recorded in `CLAUDE.md`'s state-field table (EDMV3-T66 AC5) with its coercion
      rule, so a reader of the schema sees both shapes.
- [ ] AC8 (legacy artifact shapes readable): a markdown-only findings ledger, a
      `partial_verdict_map` in the pre-closure shape, and a state file with
      `lifecycle_mode: "partial"` are all readable without error.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (three "legacy shape reads without error"
      cases).
- [ ] AC9 (both layouts): flat `SRD/{PREFIX}/` and product-scoped
      `SRD/{PRODUCT}/{PREFIX}__{DESC}/` both continue to resolve, and `edm-state migrate-path`
      continues to work and is not a prerequisite for anything.
      Verify: `bash plugins/edm/bin/tests/wave3-smoke.sh` is green and
      `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "flat layout resolves").
- [ ] AC10 (bounded, negative): a non-archived initiative with no `schema_version` raises the
      informational `SCHEMA_VERSION_MISSING` anomaly until it is migrated, so grandfathering does not
      become a permanent exemption.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "non-archived unmigrated initiative
      raises SCHEMA_VERSION_MISSING").
- [ ] AC11 (no archived initiative modified): nothing under `SRD/.archived/` is modified by this
      initiative (EDMV3-89).
      Verify: `git status --porcelain SRD/.archived/` prints nothing after the full test run.

### Technical Notes

- The three-valued model is easiest to express as a `schema_at_least <n>` helper returning 0, 1 or
  2 (absent / below / at-or-above) that every check consults, rather than each check re-deriving it.
- Copy the EDMV2 fixture into the scratch tree rather than pointing the test at the live archived
  path. The test must not be able to mutate a real archived initiative even on failure.
- Wave-A merge date: record it as a constant with a comment when the wave A MR merges, so the
  `last_updated` bound in the grandfathering rule is a real date and not a placeholder.

### Out of Scope

- The `migrate-schema` command itself -- EDMV3-T10.
- The wave-B version-2 checks whose degradation this ticket's AC6 will exercise -- EDMV3-T18.
- Re-approving any existing converged initiative. Forbidden.

---

## EDMV3-T15: Prompts present the convergence gate instead of setting the flag

| Field | Value |
|---|---|
| Epic | E2 -- Enforcement kernel |
| Wave | A |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV3-20 |
| Depends On | EDMV3-T08, EDMV3-T09 |
| Ships-with | EDMV3-T03 |
| Target Components | `plugins/edm/skills/code-audit/SKILL.md:54-69` (Step 10, the `edm-state set ... code_audit_converged true` instruction at `:57`, the closure note at `:58-67`), `:193-200` (the free-prose gate), `plugins/edm/skills/orchestrator/SKILL.md:550-581` (Step 8 point 5 at `:557-558`, the Step 9 checklist at `:569-581`), the plugin's own anti-pattern at `skills/orchestrator/SKILL.md:640-645` |

### Description

Two prompt sites instruct the model to set the convergence flag itself:
`skills/code-audit/SKILL.md:57` (Step 10) and `skills/orchestrator/SKILL.md:557-558` (Step 8 point
5), both against the orchestrator's own anti-pattern at `:640-645`. Explorer 01 also documents an
ordering problem: the existing gate in the code-audit skill fires *after* convergence is recorded
and semantically gates remediation, not convergence. Both the instruction and the ordering change.

The normative sequence is SRD Section 5.3: compute, present, approve, record.

### Acceptance Criteria

- [ ] AC1 (negative, the instruction is gone): `skills/code-audit/SKILL.md` Step 10 no longer
      contains `edm-state set <PREFIX> code_audit_converged true`, and no prompt anywhere instructs
      the model to set the flag.
      Verify: `grep -rn 'code_audit_converged true' plugins/edm/skills/` returns zero results.
- [ ] AC2 (positive, the gate is presented): on a computed-clean round, Step 10 presents the
      convergence gate via `AskUserQuestion` with header `"Convergence"` (12 characters or fewer)
      and options Approve, Revise, No-Go, and runs
      `edm-state approve-gate <PREFIX> code-audit` only on explicit Approve.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (cases "Convergence header present" and
      "approve-gate code-audit command present"), using the
      `bin/tests/wave4b-smoke.sh:104-109` prompt-text assertion pattern.
- [ ] AC3 (ordering): the gate is presented **after** the convergence computation and **before** any
      state mutation. The skill text states the compute -> present -> approve -> record order
      explicitly.
      Verify: read `sed -n '54,69p' plugins/edm/skills/code-audit/SKILL.md` and confirm the ordered
      steps, asserted by `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "convergence gate
      ordering text").
- [ ] AC4 (gate summary content): the summary presented to the human states the computed result --
      counts of open P0, P1, P2 and NOTED findings, plus the pass number.
      Verify: `grep -n 'P0.*P1.*P2.*NOTED' plugins/edm/skills/code-audit/SKILL.md` returns the
      summary template line.
- [ ] AC5: `skills/orchestrator/SKILL.md` Step 8 point 5 is replaced by an invocation of the gate
      protocol by name rather than a restatement.
      Verify: `sed -n '550,570p' plugins/edm/skills/orchestrator/SKILL.md` shows the by-name
      reference and no local protocol text.
- [ ] AC6 (two distinct gates, no ambiguity): the free-prose gate at
      `skills/code-audit/SKILL.md:193-200` is upgraded to `AskUserQuestion` and retitled the
      **remediation** gate, distinct from the convergence gate, and it records no state.
      Verify: `grep -n 'remediation gate' plugins/edm/skills/code-audit/SKILL.md` and
      `sed -n '193,205p' plugins/edm/skills/code-audit/SKILL.md` shows no `approve-gate` call.
- [ ] AC7 (grant present): `skills/code-audit/SKILL.md` lists `AskUserQuestion` in `allowed-tools`,
      without which both gates are un-runnable.
      Verify: `grep -n 'AskUserQuestion' plugins/edm/skills/code-audit/SKILL.md` returns the
      frontmatter line.
- [ ] AC8: the Step 9 completion checklist at `skills/orchestrator/SKILL.md:569-581` names the
      convergence gate, and the Post-Remediation Closure note at
      `skills/code-audit/SKILL.md:58-67` is preserved with only its trigger moved to after approval.
      Verify: `grep -n 'Post-Remediation Closure' plugins/edm/skills/code-audit/SKILL.md` still
      returns the section, and `sed -n '569,581p' plugins/edm/skills/orchestrator/SKILL.md` names
      the gate.
- [ ] AC9 (prose-change convention): the merge request shows before and after for each changed block
      plus one sentence on why the new wording is better (EDMV3-69).
      Verify: the MR description contains a before/after block per edited section.

### Technical Notes

- `AskUserQuestion` headers are capped at 12 characters. `"Convergence"` is 11. Do not lengthen it.
- The convergence *computation* does not exist until EDMV3-T28 (wave B). In wave A the skill
  presents the gate based on the round's own reading of the ledger and calls `approve-gate`, which
  records `ledger: absent` per EDMV3-T08 AC3. The prompt text names `edm-state audit-converged` as
  the authority so no second edit is needed when T28 lands.
- Ships in the same MR as EDMV3-T03, which grants the tool this ticket uses. `Ships-with` is a
  same-MR relationship and **not** a build-order edge, so EDMV3-T03 is deliberately absent from
  `Depends On`: declaring both fields for the same pair says two contradictory things about it.
  The grant and its first consumer land together in one review.

### Out of Scope

- The `audit-converged` command -- EDMV3-T28.
- The canonical gate PROTOCOL section -- EDMV3-T35 (wave B). This ticket references the protocol by
  name at the location it will occupy.
- The three weak standalone-skill gates -- EDMV3-T35.

---

## EDMV3-T16: The three-command bypass becomes a must-fail smoke suite

| Field | Value |
|---|---|
| Epic | E2 -- Enforcement kernel |
| Wave | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV3-21 |
| Depends On | EDMV3-T07, EDMV3-T09, EDMV3-T11, EDMV3-T12, EDMV3-T13, EDMV3-T19 |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/tests/wave6-smoke.sh` (new), `plugins/edm/bin/tests/_harness.sh`, `plugins/edm/bin/edm-init:60` (bare-name `edm-validate-prefix`), `:139` (bare-name `edm-state`) |

### Description

The reviewer's reproduction is the acceptance test for the entire enforcement kernel. Explorer 01
notes that grepping `bin/tests/` for `archive` or `converged` currently returns zero matches -- there
is no coverage of `cmd_archive` or the convergence flag at all.

The suite is the wave-A exit criterion. It must prove that refusal is targeted rather than blanket,
which is why the happy path is asserted alongside every must-fail case.

### Acceptance Criteria

- [ ] AC1 (the reproduction, command 2): the suite scaffolds a phase-0 initiative in a scratch repo
      and runs the exact sequence
      `edm-init --product demo --description bypass-test TESTX`,
      `edm-state set TESTX code_audit_converged true`,
      `edm-state archive TESTX`. Command 2 exits non-zero with a message naming `approve-gate`.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "bypass command 2 refused"), using
      `check_fails "bypass cmd2" "approve-gate" edm-state set TESTX code_audit_converged true`.
- [ ] AC2 (the reproduction, command 3 after a hand-edit): the suite then forces the flag by direct
      `jq` edit of the state file, simulating a hand-edit, and asserts command 3 still exits
      non-zero, naming the missing gates and the wrong `current_phase`.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "bypass command 3 refused after
      hand-edit").
- [ ] AC3 (nothing moved): the initiative directory still exists at its original path after both
      refusals.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "initiative directory unmoved after
      refusals").
- [ ] AC4 (must-fail matrix): additional cases cover `phase-complete` with the artifact absent,
      `archive` with gates 1 and 2 but not 3, `archive` at `current_phase == 5`, `set` with an
      unknown key, `set` on each of the three gate-bearing fields, `set schema_version`, and
      `phase-start` into a phase whose prerequisite gate is unapproved.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh 2>&1 | grep -c 'PASS.*must-fail'` matches
      the documented case count.
- [ ] AC5 (flat-layout case, the second hole): an initiative scaffolded without `--product` at
      `SRD/{PREFIX}/`, with `code_audit_converged=false`, is refused by `archive`. This case fails
      against today's code because of the `product_name` conjunct at `bin/edm-state:887`, which is
      exactly why it is here -- every other case uses `--product demo` and would have missed it.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "flat-layout archive refused").
- [ ] AC6 (mode cases): a `fast-track` case and a `mini-srd` case each scaffold under their mode,
      record the `skipped_phases` the mode seeds, approve only the gates the mode requires, and
      assert a successful archive. Without these the matrix covers only the standard lifecycle and
      a mode that can never archive would not be caught.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (cases "fast-track archives" and
      "mini-srd archives").
- [ ] AC7 (positive, happy path): a fully compliant standard-lifecycle initiative archives
      successfully, proving refusal is targeted rather than blanket.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "compliant standard lifecycle
      archives").
- [ ] AC8 (shared helpers, not hand-rolled): every case uses `with_scratch_repo`, `check_fails` and
      `check_state_unchanged` from EDMV3-T19 rather than hand-rolling scratch-repo setup, and
      `with_scratch_repo` puts `plugins/edm/bin` on `PATH` because `bin/edm-init:139` calls
      `edm-state` and `:60` calls `edm-validate-prefix` **by bare name**, unlike the existing suites
      which invoke `"$EDM_STATE"` by absolute path.
      Verify: `grep -c 'with_scratch_repo' plugins/edm/bin/tests/wave6-smoke.sh` is non-zero and
      `grep -c 'mktemp -d' plugins/edm/bin/tests/wave6-smoke.sh` is 0.
- [ ] AC9 (no residue): the suite leaves nothing in the developer's working tree, including on
      failure.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh; git status --porcelain` prints nothing
      new.
- [ ] AC10 (CI): all cases run in CI.
      Verify: `grep -n 'run-all.sh' .gitlab-ci.yml plugins/edm/bin/tests/run-all.sh`.

### Technical Notes

- The PARTIAL case (`archive` with an unclosed PARTIAL) is a wave-B addition and lands with
  EDMV3-T18. Leave a clearly marked placeholder comment so the wave-B ticket is an insertion.
- `edm-init` writes to the current working directory tree. `with_scratch_repo` must set
  `EDM_SRD_ROOT` inside the scratch tree, or the suite scaffolds real initiatives into the
  developer's `SRD/`.
- Case ordering matters: run the happy path last, after every refusal case, so a bug that makes
  everything pass is caught by the refusal count rather than masked by a green happy path.

### Out of Scope

- Any production-code change. This ticket is tests only; every refusal it asserts is implemented by
  EDMV3-T09 through EDMV3-T13.
- The `wave7-smoke.sh` contract suite -- created by EDMV3-T09.

---

## EDMV3-T17: HANDOFF and anomalies surface the new lifecycle facts (wave A)

| Field | Value |
|---|---|
| Epic | E2 -- Enforcement kernel |
| Wave | A |
| Priority | Should Have |
| Size | S |
| SRD Refs | EDMV3-22 (wave-A portion) |
| Depends On | EDMV3-T05, EDMV3-T08 |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/edm-state:1700` (`write_handoff_internal`), the `next_action` block at `:1749-1779`, the gate list at `:1783-1788`, `:419` (`state_anomalies`) |

### Description

Explorer 01 section 1.5: the HANDOFF gate list renders only `gates_approved`, so a dedicated boolean
does not appear at all -- neither the Gate 3.5 compliance gate nor the new code-audit gate. The
phase-6 `next_action` emits one generic message regardless of what is actually blocking.
`state_anomalies` is the natural home for "converged with no recorded approval".

The wave-B portion of EDMV3-22 (the `OPEN_PARTIALS` entry and the ledger-sourced open-findings
summary) lands in EDMV3-T18 with its machinery.

### Acceptance Criteria

- [ ] AC1 (positive): the HANDOFF gate list renders the code-audit gate and the Gate 3.5 compliance
      gate alongside numeric gates, showing approval status, timestamp, approver and enforcement
      tag.
      Verify: `edm-state write-handoff TESTX && grep -n 'code-audit' <init-dir>/HANDOFF.md` shows
      the row with all four fields.
- [ ] AC2: the phase-6 `next_action` distinguishes at least four states -- implementation in
      progress, awaiting runtime verification of open PARTIALs, awaiting the convergence gate, and
      ready to archive.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "phase-6 next_action four states"),
      driving each state and asserting a distinct string.
- [ ] AC3 (negative anomaly): `state_anomalies` gains a `CONVERGED_NO_APPROVAL` entry in the
      canonical four-field format `blocking  CONVERGED_NO_APPROVAL  code_audit_converged  <description>`
      (EDMV3-T05 AC2) when `code_audit_converged` is `true` but no approval record exists **and**
      `schema_version` is present, so legacy files are not flagged.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (cases "CONVERGED_NO_APPROVAL fires on a
      hand-set flag with four fields and class blocking" and "does not fire on a legacy file").
- [ ] AC4 (severity declared): every anomaly added here declares its severity class per EDMV3-T05,
      so a warning does not silently turn `edm-state validate` non-zero.
      Verify: `edm-state validate TESTX; echo "exit=$?"` prints `exit=0` for an initiative whose
      only anomaly is informational.
- [ ] AC5 (preserve): existing HANDOFF sections, including the preserved user-editable `## Notes`
      section, are unchanged across regeneration.
      Verify: `bash plugins/edm/bin/tests/wave5-smoke.sh` is green and
      `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "Notes section preserved across
      regeneration").
- [ ] AC6 (C-4): regenerating HANDOFF for a legacy initiative omits the new sections rather than
      rendering empty ones or erroring.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "legacy HANDOFF omits new
      sections").
- [ ] AC7 (the generator's own non-ASCII is fixed, not just the template): the three `next_action`
      strings at `bin/edm-state:1754`, `:1763` and `:1772` each contain a literal U+2014 em dash
      (`"Phase N skipped <em dash> run \`/edm:orchestrator ${prefix}\` to continue"`, verified
      2026-07-25). Each is normalized to the ASCII `--`. This is the whole reason AC8 is satisfiable:
      `write_handoff_internal` emits those strings into `HANDOFF.md`, `HANDOFF.md` sits in the
      initiative directory that `edm-lint-artifacts` class 2 scans, and any initiative with a
      skipped phase 1, 3 or 5 therefore fails `--all` today through no fault of its author.
      Verify: `LC_ALL=C sed -n '1749,1779p' plugins/edm/bin/edm-state | grep -n '[^\x00-\x7F]'`
      returns nothing, and `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "HANDOFF for an
      initiative with skipped phases 1, 3 and 5 is ASCII-only"), which drives all three branches.
      The scope is the `next_action` block only: em dashes elsewhere in `bin/edm-state` are in
      comments, never reach an artifact, and are out of scope here.
- [ ] AC8: HANDOFF output remains ASCII-only and passes the artifact lint, including for an
      initiative whose `next_action` comes from one of the three branches AC7 fixed.
      Verify: `bash plugins/edm/bin/edm-lint-artifacts --all` exits 0, and
      `LC_ALL=C grep -n '[^\x00-\x7F]' <init-dir>/HANDOFF.md` returns nothing.

### Technical Notes

- AC7 is the wave-A half of a two-part problem the round-1 ticket audit surfaced: the pack's ASCII
  discipline was clean, and the plugin source it generates artifacts from was not. EDMV3-T63 owns
  the imported-document half (`EDM-REVIEW.md`); this ticket owns the generator half.
- The gate list at `:1783-1788` iterates `gates_approved` only. Add the two dedicated booleans as a
  separate rendering pass rather than synthesizing fake array members -- EDMV3-108 forbids
  non-integer members and a renderer that fakes them will eventually leak into state.
- Wave-B insertion points (`OPEN_PARTIALS`, the ledger summary) should be marked with a comment
  naming EDMV3-T18.

### Out of Scope

- `OPEN_PARTIALS` and the open-findings summary -- EDMV3-T18.
- The full HANDOFF completeness requirement EDMV3-99 -- also EDMV3-T18.

---

## EDMV3-T18: `archive` blocks unclosed PARTIALs and gains its wave-B sub-checks

| Field | Value |
|---|---|
| Epic | E2 -- Enforcement kernel |
| Wave | B |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV3-18, EDMV3-17 (AC1e, AC1f), EDMV3-22 (wave-B portion), EDMV3-99 |
| Depends On | EDMV3-T12, EDMV3-T17, EDMV3-T28, EDMV3-T32, EDMV3-T33 |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/edm-state:860` (`cmd_archive`, the wave-B insertion points left by EDMV3-T12), `:1412` (`cmd_record_partial_verdict`), `:1700` (`write_handoff_internal`), `:1749-1779` (`next_action`), `:419` (`state_anomalies`) |

### Description

F7 plus D13(b). PARTIAL verdicts are recorded, listed in `exec-report.md`, explicitly excluded from
remediation, unchecked by archive, and never closed. An initiative can converge, archive and ship
with acceptance criteria nobody and nothing verified. There is no waiver flag (D13(c)); the
sanctioned closure path is `/edm:verify-runtime` (EDMV3-T33).

This ticket also fills the two wave-B slots EDMV3-T12 left in `cmd_archive` (AC1e PARTIAL closure,
AC1f computed convergence) and completes the HANDOFF story EDMV3-T17 started. It is one ticket
because all four edits touch the same two functions and because the closure representation, the
skill that writes it, and the archive check that reads it are one unit -- splitting them re-creates
the wave-A dead end.

### Acceptance Criteria

- [ ] AC1 (closure representation): `partial_verdict_map` entries gain a closure representation --
      the closing verdict (`PASS` or `FAIL`), the closing timestamp, and a reference to the
      `post-deploy/verification.md` section that closed it.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "closed PARTIAL entry shape"),
      asserting all three keys with `jq -e`.
- [ ] AC2 (negative, open PARTIAL blocks): `cmd_archive` refuses when any entry lacks a closure
      record, listing each open ticket and AC identifier, directing the user to
      `/edm:verify-runtime <PREFIX>` and stating that no override exists.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "archive refuses with an open
      PARTIAL"), using `check_fails` on the message.
- [ ] AC3 (negative, FAIL-closed also blocks): an entry closed as `FAIL` also blocks archive,
      because a failed runtime verification becomes a FAIL finding that must be remediated. There is
      no third closure verdict.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "archive refuses with a FAIL-closed
      PARTIAL").
- [ ] AC4 (positive): archive succeeds when every entry is `PASS`-closed and the other lifecycle
      conditions hold.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "archive succeeds with all PARTIALs
      PASS-closed").
- [ ] AC5 (AC1f, computed convergence): `cmd_archive` calls `edm-state audit-converged` as part of
      lifecycle verification, so the boolean is corroborated by the ledger rather than trusted
      alone.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (cases "archive refuses when
      audit-converged exits 1" and "archive proceeds when it exits 0").
- [ ] AC6 (C-4, three-valued): legacy initiatives (`schema_version` absent) and wave-A initiatives
      (`schema_version: 1`) warn and proceed through the closure check, naming each such entry, and
      are not asked to re-run an eleven-lens audit round.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (cases "legacy warn-and-proceed on closure
      check" and "schema_version 1 warn-and-proceed naming each version-2 check").
- [ ] AC7 (`OPEN_PARTIALS` anomaly): `state_anomalies` gains an `OPEN_PARTIALS` entry in the
      canonical four-field format `blocking  OPEN_PARTIALS  partial_verdict_map  <description>`
      (EDMV3-T05 AC2), the description listing the unclosed PARTIAL verdicts.
      Verify: `edm-state validate TESTX | grep -n '^blocking  OPEN_PARTIALS  partial_verdict_map'`.
- [ ] AC8 (HANDOFF completeness, EDMV3-99): HANDOFF renders the code-audit gate status with approver
      and enforcement tag, open PARTIAL verdicts with their runtime-check notes, skipped phases with
      rationales, and an open-findings summary sourced from `findings-ledger.jsonl` when present.
      The `next_action` line distinguishes the four phase-6 states.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "HANDOFF renders all four new
      sections").
- [ ] AC9 (preserve): HANDOFF regeneration remains automatic at phase-complete, gate approval and
      checkpoint with no new manual step, the user-editable `## Notes` section is still preserved
      verbatim, and the output is ASCII-only.
      Verify: `bash plugins/edm/bin/tests/wave5-smoke.sh` is green and
      `bash plugins/edm/bin/edm-lint-artifacts --all` exits 0.
- [ ] AC10 (negative, no override): no `--accept-partials` or equivalent flag exists on `archive`.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "archive --accept-partials is an
      unknown argument").
- [ ] AC11 (bypass suite extended): the wave-A bypass suite's placeholder case for an unclosed
      PARTIAL is filled in.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "bypass matrix: archive with an
      unclosed PARTIAL") passes and the placeholder comment is gone.

### Technical Notes

- The closure write is a second write against an existing entry. EDMV3-T32 makes that safe by
  preserving the original note under a `prior` key -- do not implement a second closure path here.
- `audit-converged` uses exit code 3 for "no ledger", which is **not** a refusal condition for
  archive on a legacy initiative. Map 3 to warn-and-proceed and 1 to refuse.
- The wave-A refusal messages were forbidden from naming wave-B commands (EDMV3-T12 AC6). That
  constraint lifts here, and the refusal message naming `/edm:verify-runtime` is now correct because
  the skill exists.

### Out of Scope

- `/edm:verify-runtime` itself -- EDMV3-T33.
- `record-partial-verdict`'s closure support -- EDMV3-T32.
- `audit-converged` itself -- EDMV3-T28.
