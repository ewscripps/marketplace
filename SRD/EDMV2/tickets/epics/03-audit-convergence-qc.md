# Epic 3 — Audit Convergence (WS-B) and QC Scale + Verdict Fidelity (WS-C)

Generated From: srd.md v1.0.7

This epic delivers two corpus-driven scaling capabilities. WS-B (EDMV2-24 through EDMV2-31) makes the
multi-round code audit converge deterministically: a monotonic pass index, a persistent cross-round findings
ledger, a convergence gate, a stable-lens guarantee, version-drift detection for the SRD/ticket audits, and
scoped re-audit. WS-C (EDMV2-32 through EDMV2-37) makes Phase-6 QC scale across large ticket sets via sharding,
gives QC a canonical artifact home, and adds first-class PASS/PARTIAL/FAIL verdicts where PARTIAL captures ACs
that cannot be verified statically and are deferred to runtime.

All tickets here build on the Epic 2 foundation (WS-M/WS-N/WS-J, ticket range EDMV2-T24 through EDMV2-T54):
state-derived path resolution (EDMV2-88), typed-set with `--argjson` (EDMV2-68), file locking on `write_state()`
(EDMV2-70), the canonical artifact homes / state schema additions (WS-D, Epic 2), and the `code_audit_converged`
archive gate plumbing (EDMV2-15). Where a specific Epic 2 ticket is the blocking dependency, its EDMV2-T number is
named; where Epic 2 numbering is not yet final, the dependency is named by its requirement ID in parentheses.

Cross-cutting requirements (apply to every ticket in this epic):
- All Phase 6 implementation work is performed in `plugins/edm-ai-development-staging/` only; the live
  `plugins/edm-ai-development/` is untouched until cutover (EDMV2-109, C-5). All paths below are written relative
  to the plugin root and are edited in the staging copy.
- POSIX bash only for `bin/edm-state` changes; `jq` is the only new external tool (C-3).
- State-schema changes are additive and defaulted; a v1.x state file with none of the new fields still works
  (C-4, EDMV2-90). All new reads use jq `//` defaults.
- ASCII-only in every generated artifact and message (C-1, EDMV2-21/75).
- Bash unit checks for each new/changed `bin/edm-state` subcommand; `claude plugin validate` passes (C-2).
- No AI-attribution trailers or Unicode glyphs in any emitted content.

---

## EDMV2-T56: Add audit-round-start subcommand and audit_rounds counter to edm-state

| Field | Value |
|---|---|
| Workstream | WS-B |
| SRD Requirements | EDMV2-25, EDMV2-24 (partial — counter source) |
| Priority | Must |
| Size | S |
| Target Components | `bin/edm-state` — new `cmd_audit_round_start()` function; new dispatch case `audit-round-start` in the `case` block (`:777-801`); update `cmd_init` payload (`:218-230`) to seed `audit_rounds: {}`; update the usage header comment block (`:3-20`) |
| Dependencies | EDMV2-T25 typed-set path (`--argjson` for the integer counter); EDMV2-T24 file locking on `write_state()`; EDMV2-T37 state-derived `state_file_for()` |

### Description
The code audit currently has no concept of a "round." `audit-round-start` introduces an initiative-wide,
monotonically incrementing pass counter stored under `audit_rounds.<type>` in `.edm-state.json`, where
`<type>` is one of `code`, `srd`, `tickets`. The subcommand increments the counter for the named type, persists
it through the locked `write_state()` path, and echoes the new integer value to stdout so the caller (the
`code-audit` skill, EDMV2-T59) can build the `pass-{N}_{date}/` directory name.

The counter is the primary unique identifier for an audit round. It must never reset for the lifetime of the
initiative regardless of date, re-run, or day boundary. It must be stored as a JSON number (typed-set,
EDMV2-68), not a string, so `jq .audit_rounds.code` returns an integer.

### Acceptance Criteria
- [ ] AC1: `edm-state audit-round-start <PREFIX> code` increments `.audit_rounds.code` by 1 and echoes the new value to stdout as a bare integer (e.g., `1`).
- [ ] AC2: When `audit_rounds` is absent (legacy state file), the first call treats the missing counter as `0` and writes `1` without erroring.
- [ ] AC3: `<audit-type>` is validated against the set `code`, `srd`, `tickets`; an unknown type exits non-zero with `usage: edm-state audit-round-start <PREFIX> <audit-type>`.
- [ ] AC4: The counter is written as a JSON number — `jq -e '.audit_rounds.code | type == "number"' .edm-state.json` succeeds after a call.
- [ ] AC5: Calling the subcommand three times across three separate process invocations returns `1`, `2`, `3` in order; `jq .audit_rounds.code` reads `3` afterward.
- [ ] AC6: The counter does not reset on a new calendar day — three calls spanning a simulated day boundary (state edited between calls) still yield `1`, `2`, `3`.
- [ ] AC7: Missing or wrong argument count exits non-zero with the usage message; no state mutation occurs on a usage error.
- [ ] AC8: The write goes through `write_state()` so the advisory lock (EDMV2-70) serializes concurrent calls — two concurrent `audit-round-start` invocations produce distinct sequential values, never a duplicate.
- [ ] AC9: `cmd_init` seeds `audit_rounds: {}` (or the field is created lazily on first write); a freshly initialized initiative reads `{}` for `audit_rounds`.
- [ ] AC10: A fixture `.edm-state.json` lacking `audit_rounds` is read by all consumers without error; `audit_rounds` resolves to `0` via `jq // 0` guard.

### Technical Notes
Increment with `jq '.audit_rounds[$t] = ((.audit_rounds[$t] // 0) + 1)'` using `--arg t "$type"`, then read back
the new value with a second `jq -r '.audit_rounds[$t]'` for the echo. Follow the existing `cmd_record_tests_added`
pattern (`:427-442`) for the lazy-default-then-increment idiom. Use `--argjson` only if writing a literal; here the
arithmetic is inside jq, so the result is already a number. Add the dispatch case alphabetically near the other
new WS-B/C cases.

### Out of Scope
Building the `pass-{N}_{date}/` directory (EDMV2-T59). The SRD/ticket audit-round consumption (those skills read
the counter but their drift logic is EDMV2-T62). Convergence evaluation (EDMV2-T60).

### Verification
QC confirms PASS by running the subcommand three times in a bash sandbox against a temp state file, asserting the
echoed sequence `1 2 3` and `jq` integer type, plus a usage-error exit-code check and a concurrent-call check that
no value is duplicated.

---

## EDMV2-T57: Round/pass-indexed code-audit directory layout

| Field | Value |
|---|---|
| Workstream | WS-B |
| SRD Requirements | EDMV2-24 |
| Priority | Must |
| Size | S |
| Target Components | `skills/code-audit/SKILL.md` — replace the `{YYYY-MM-DD}` output-dir resolution (`:17`, `:29`) and the `Output:` lens-template line (`:33`, `:66`) with the `pass-{N}_{YYYY-MM-DD}/` scheme; add a step that calls `audit-round-start` before `mkdir`; `CLAUDE.md` (plugin) artifact-layout block — update `code-audit/` shape |
| Dependencies | EDMV2-T56 (audit-round-start); EDMV2-T37 state-derived path resolution |

### Description
The code-audit skill currently writes to `code-audit/{YYYY-MM-DD}/`, which collides when two rounds run on the
same day and gives no notion of round ordering. This ticket changes the directory naming to
`code-audit/pass-{N}_{YYYY-MM-DD}/`, where `{N}` is the value returned by `edm-state audit-round-start <PREFIX>
code` and `{YYYY-MM-DD}` is the date the round started. The pass number is the unique key; the date is
informational. The skill must call `audit-round-start` to obtain `{N}` before creating the directory.

The full initiative directory must be resolved from state (product/prefix/description, EDMV2-88), not hardcoded to
`SRD/{PREFIX}/`.

### Acceptance Criteria
- [ ] AC1: The code-audit skill resolves its output directory as `<initiative-dir>/code-audit/pass-{N}_$(date +%Y-%m-%d)/`, where `{N}` is the stdout of `edm-state audit-round-start <PREFIX> code`.
- [ ] AC2: Three rounds run across two days produce `pass-1_{date-a}/`, `pass-2_{date-b}/`, `pass-3_{date-b}/` with `N` always incrementing and no reset on the day change.
- [ ] AC3: Two rounds on the same day produce distinct directories (`pass-2_{date}/` and `pass-3_{date}/`) with no collision.
- [ ] AC4: The lens-launch template's `Output:` line and the synthesizer prompt both reference the `pass-{N}_{date}/` directory, not `{YYYY-MM-DD}/`.
- [ ] AC5: `mkdir -p` targets the pass-indexed path; lens reports land at `code-audit/pass-{N}_{date}/lens-L{1..11}.md` and the synthesizer writes `code-audit/pass-{N}_{date}/REMEDIATION.md`.
- [ ] AC6: The initiative directory is derived from state (handles both new `SRD/{PRODUCT}/{PREFIX}__{DESC}/` and legacy `SRD/{PREFIX}/` layouts).
- [ ] AC7: The skill calls `audit-round-start` exactly once per round (not once per lens), so all 11 lenses in a round share one pass directory.
- [ ] AC8: The plugin `CLAUDE.md` artifact-layout block documents the `code-audit/pass-{N}_{YYYY-MM-DD}/` shape, replacing the old `{YYYY-MM-DD}/` entry.

### Technical Notes
`date +%Y-%m-%d` (local date is acceptable for the informational segment; the pass number guarantees uniqueness).
Capture `N` into a skill variable before the `mkdir` step. The skill is markdown read by an LLM, so the change is
to the documented procedure and the templated `${OUTPUT_DIR}` references at `:29`, `:33`, `:66`, `:91`.

### Out of Scope
The ledger file inside the pass directory (EDMV2-T58/T63). Convergence (EDMV2-T60). Scoped re-audit lens subset
(EDMV2-T64).

### Verification
QC confirms PASS by inspecting the skill prose for the `pass-{N}_{date}/` pattern at every output-path reference,
confirming a single `audit-round-start` call per round, and confirming the `CLAUDE.md` layout block was updated.

---

## EDMV2-T58: Persistent cross-round findings ledger with stable IDs and status

| Field | Value |
|---|---|
| Workstream | WS-B |
| SRD Requirements | EDMV2-26 |
| Priority | Must |
| Size | M |
| Target Components | `agents/edm-audit-synthesizer.md` — add ledger read/merge/write responsibility; `skills/code-audit/SKILL.md` — synthesizer prompt (`:86-92`) instructs ledger maintenance; ledger schema documented in the skill; `bin/edm-state` — optional `findings_ledger` mirror field already defined in schema (§5.4) |
| Dependencies | EDMV2-T57 (pass directories); EDMV2-T67 (canonical ledger home, sequencing); EDMV2-T13 (severity unification); EDMV2-T76 WS-D decision/audit ledger pattern |

### Description
Findings today live only inside per-round `REMEDIATION.md` files, so a finding raised in round 1 and fixed in
round 2 cannot be tracked as a single item — its history is scattered. This ticket introduces a persistent
findings ledger that accumulates findings across rounds with: a stable ID (e.g., `CA-001`), severity on the
unified scale (P0/P1/P2 per EDMV2-13), status (`open` / `fixed` / `deferred`), the round in which each was raised
(`raised_round`), and the round in which it was resolved (`resolved_round`, null while open).

The `edm-audit-synthesizer` owns the ledger: on each round it reads the prior ledger, assigns new findings the
next stable ID, marks previously-open findings that no longer appear as `fixed` (recording `resolved_round`), and
re-opens any finding that reappears. The ledger is written as a markdown table at its canonical path (EDMV2-T67);
its structure mirrors the `findings_ledger` array in state (§5.4).

### Acceptance Criteria
- [ ] AC1: A finding raised in round 1 and fixed in round 2 appears exactly once in the ledger with `raised_round: 1` and `resolved_round: 2`, status `fixed`.
- [ ] AC2: Each ledger entry has a stable, unique ID that does not change across rounds (`CA-001`, `CA-002`, ...); the synthesizer assigns the next sequential ID to genuinely new findings only.
- [ ] AC3: Each entry records severity on the unified P0/P1/P2 scale (EDMV2-13), never the legacy P1/P2/P3 scale.
- [ ] AC4: Status is one of `open`, `fixed`, `deferred`; a finding present in round N but absent from round N+1's lens output is marked `fixed` with `resolved_round = N+1`.
- [ ] AC5: A finding that was marked `fixed` but reappears in a later round is re-opened (status back to `open`, `resolved_round` cleared) under its original ID, not a new ID — oscillation is visible.
- [ ] AC6: The ledger is append-and-update (idempotent): re-running the synthesizer on the same lens reports for the same round does not duplicate entries or bump IDs.
- [ ] AC7: A `deferred` finding (e.g., out-of-scope or accepted risk) retains its ID and is excluded from the convergence blocking set (coordinated with EDMV2-T60).
- [ ] AC8: The synthesizer prompt in the code-audit skill instructs reading the prior ledger before writing the new round's findings, and writing back the merged ledger.
- [ ] AC9: The ledger table columns are exactly: ID, Severity, Status, Lens(es), Component, Summary, Raised Round, Resolved Round.

### Technical Notes
The synthesizer agent (cyan, opus/max) already dedupes multi-lens findings (`skills/code-audit/SKILL.md:96-101`);
extend its mandate to ID assignment and cross-round status. Matching a finding across rounds is by
component+summary similarity, not by literal text — instruct the synthesizer to reconcile by (lens, file,
issue-class). The state-mirror `findings_ledger` array is optional for this ticket (the markdown ledger is the
source of truth); keep state writes minimal to avoid lock contention during a round.

### Out of Scope
The canonical ledger path itself (EDMV2-T67). The convergence decision that consumes ledger status (EDMV2-T60).
Automatic pattern-library extraction from the ledger (WS-L, separate epic).

### Verification
QC confirms PASS by simulating a two-round sequence (a fixture set of round-1 and round-2 lens reports) and
asserting the merged ledger shows one entry with both round references, a re-opened finding keeps its ID, and a
re-run is idempotent.

---

## EDMV2-T59: Convergence gate for the code-audit loop

| Field | Value |
|---|---|
| Workstream | WS-B |
| SRD Requirements | EDMV2-27, EDMV2-15 (sets the flag the archive gate reads) |
| Priority | Must |
| Size | M |
| Target Components | `skills/code-audit/SKILL.md` — replace step 10 loop (`:38`) with an explicit convergence check; `skills/orchestrator/SKILL.md` — mandatory code-audit completion block (G18, `:279`) reads convergence; `bin/edm-state set <PREFIX> code_audit_converged true` (typed) on a clean round |
| Dependencies | EDMV2-T58 (findings ledger supplies open-P0/P1 set); EDMV2-T60 (stable-lens flag); EDMV2-T13 (severity unification); EDMV2-T25 typed-set for the boolean; EDMV2-T14, EDMV2-T15 G18 orchestrator gating from Epic 1 |

### Description
Today the code-audit loop is "re-run touched lenses, loop until clean" with no defined termination condition. This
ticket defines the convergence condition explicitly: the audit is converged only when a full-lens round (all 11
lenses, EDMV2-T60) completes with zero new open P0-or-P1 findings in the ledger. A round that surfaces a new
blocking finding does not satisfy convergence; a clean full-lens round does. On convergence the skill (or
orchestrator) sets `code_audit_converged` to a JSON boolean `true` (typed-set), which the archive gate
(EDMV2-15) reads.

This is the loop's stopping rule, and it is what makes G18 (mandatory code audit blocking completion) terminate.

### Acceptance Criteria
- [ ] AC1: Convergence is declared only when the most recent round is a full-lens round (all 11 lenses ran) AND the ledger shows zero open P0 and zero open P1 findings introduced or surviving in that round.
- [ ] AC2: A round that surfaces any new open P0 or P1 finding does not satisfy convergence; the skill loops to the next pass via `audit-round-start`.
- [ ] AC3: A scoped/partial round (lens subset, EDMV2-T60) can never by itself satisfy convergence, even if it surfaces no findings.
- [ ] AC4: On convergence, `edm-state set <PREFIX> code_audit_converged true` is called with typed-set so `jq -e '.code_audit_converged == true'` succeeds (JSON boolean, not the string `"true"`).
- [ ] AC5: P2 (and `deferred`) findings do not block convergence; a clean round with only open P2 findings still converges.
- [ ] AC6: The orchestrator's completion logic (G18) refuses to advance past the code-audit phase / refuses initiative completion until `code_audit_converged` is `true` (or `mode == prototype`).
- [ ] AC7: The convergence check reads the ledger (EDMV2-T58) as the authoritative open-finding source, not the raw per-lens reports.
- [ ] AC8: When convergence is not met, the skill presents the remaining open P0/P1 findings to the human before looping, so a non-terminating loop can be halted manually (Risk 5 mitigation).

### Technical Notes
Risk 5 (§5.6) warns convergence may not terminate if remediation introduces new findings; the ledger's stable IDs
make oscillation visible. Keep the human in the loop: present the blocking set before each re-round rather than
auto-looping silently. The typed-set boolean write depends on EDMV2-68 landing first. The orchestrator side is the
G18 work from Epic 1 (EDMV2-14/15); this ticket supplies the convergence predicate it gates on.

### Out of Scope
The archive refusal behavior itself (`cmd_archive` three-case gating) — that is EDMV2-15 in Epic 1. The pass-index
mechanics (EDMV2-T56/T57). Stable-lens enforcement (EDMV2-T60).

### Verification
QC confirms PASS by driving a fixture two-round sequence: round 1 with an open P1 yields non-convergence and a
loop; round 2 clean full-lens yields convergence and a typed `code_audit_converged: true` write. A scoped round is
asserted non-convergent.

---

## EDMV2-T60: Stable lens set with per-round lens recording and partial-round flagging

| Field | Value |
|---|---|
| Workstream | WS-B |
| SRD Requirements | EDMV2-28 |
| Priority | Must |
| Size | S |
| Target Components | `skills/code-audit/SKILL.md` — record the lens set per round (new `lenses-run.txt` or front-matter in REMEDIATION); the 11-lens canonical set (`:42-54`); `agents/edm-audit-synthesizer.md` — record which lenses contributed and flag the round full vs. partial |
| Dependencies | EDMV2-T57 (pass directories); EDMV2-T58 (ledger entries carry lens refs) |

### Description
Convergence must not be claimable by silently narrowing the lens scope. This ticket requires each code-audit round
to record which of the 11 lenses actually ran, and to mark any round that ran a subset as a `partial`/`scoped`
round. A partial round is recorded with its lens subset and is flagged non-convergent (it cannot, on its own,
satisfy the EDMV2-T59 convergence gate). The canonical full set remains the same 11 lenses (L1-L11) across all
rounds, each seeded with prior-round findings from the ledger.

### Acceptance Criteria
- [ ] AC1: Each round's output directory records the set of lenses that ran (e.g., `pass-{N}_{date}/lenses-run.txt` listing `L1..L11` or the subset).
- [ ] AC2: A round that ran all 11 lenses is marked `full`; a round that ran fewer is marked `partial` with the specific subset listed.
- [ ] AC3: A `partial` round is flagged non-convergent and the synthesizer/skill does not set `code_audit_converged` from it (consistent with EDMV2-T59 AC3).
- [ ] AC4: The canonical lens set is the same 11 lenses (L1-L11) in every round; lens identity is stable across rounds.
- [ ] AC5: Each lens in a round is seeded with the prior-round open findings for its lens (the synthesizer passes the relevant ledger slice into the lens prompt, or the lens reads the ledger).
- [ ] AC6: The REMEDIATION.md (or a sibling marker) for the round states `Round type: full` or `Round type: partial (lenses: L1, L3)`.
- [ ] AC7: A full round following one or more partial rounds correctly re-evaluates all lenses against the accumulated ledger.

### Technical Notes
This is the scope-integrity half of convergence (EDMV2-T59 reads the `full`/`partial` flag this ticket sets). The
"seeded with prior-round findings" requirement ties lenses to the ledger (EDMV2-T58): the synthesizer or the skill
provides each lens its own prior open findings so a lens can confirm fixes or re-flag. Record the lens set as a
simple newline-delimited file to keep parsing trivial in bash.

### Out of Scope
The scoped re-audit invocation UX (`--lenses L1,L3` flag) — that is EDMV2-T64. The convergence predicate itself
(EDMV2-T59).

### Verification
QC confirms PASS by running a full round (asserts `Round type: full`, 11 lenses recorded) and a scoped round
(asserts `Round type: partial`, subset recorded, non-convergent), and confirming each lens prompt receives its
prior-round ledger slice.

---

## EDMV2-T61: Version-drift detection between SRD/ticket audit and audited artifact

| Field | Value |
|---|---|
| Workstream | WS-B |
| SRD Requirements | EDMV2-29 |
| Priority | Must |
| Size | M |
| Target Components | `skills/audit-srd/SKILL.md` and `skills/audit-tickets/SKILL.md` — record audited version + drift check; `bin/edm-state` — `audit_rounds.srd` / `.tickets` already from EDMV2-T56; record `audited_srd_version` / `audited_pack_version` into state on audit start; drift comparison against `srd_version` |
| Dependencies | EDMV2-T56 (audit-round-start for srd/tickets types); EDMV2-T09 srd-version routing from Epic 1; EDMV2-T25 typed-set |

### Description
SRD and ticket audits can silently pass against a stale artifact. This ticket requires each SRD audit and each
ticket-pack audit to record the version of the artifact it audited, and the plugin to detect and flag drift when
that recorded version is older than the current `srd_version` (or ticket-pack version). Auditing pack v1.1 against
SRD v1.2 must produce a visible drift flag rather than a false PASS.

The audited version is captured at audit time and compared against the current state `srd_version` (set via
`srd-version`, EDMV2-09). The drift flag surfaces in the audit output and in HANDOFF (WS-N rendering handled by
Epic 2; this ticket records the field).

### Acceptance Criteria
- [ ] AC1: The SRD audit records the SRD version it audited into state (e.g., `audited_srd_version`) at audit start.
- [ ] AC2: The ticket audit records the ticket-pack version (the `Generated From: srd.md v{srd_version}` header value) it audited.
- [ ] AC3: When the recorded audited version is older than the current `srd_version`, the audit output emits a drift flag (ASCII `(!)` marker) naming both versions.
- [ ] AC4: Auditing pack v1.1 against SRD v1.2 produces a drift flag; auditing pack v1.2 against SRD v1.2 does not.
- [ ] AC5: The version comparison is semantic (1.10 > 1.9), not lexical string comparison.
- [ ] AC6: A drift flag never silently upgrades to PASS — the audit verdict reflects that it was run against a stale artifact.
- [ ] AC7: Recorded version fields are stored as strings via the existing string path (versions are strings like `"1.2.0"`); no spurious numeric coercion occurs.
- [ ] AC8: When no prior audited version is recorded (first audit), no drift is flagged.

### Technical Notes
Semantic version comparison in POSIX bash: split on `.` and compare field-by-field numerically, or use
`sort -V` / `printf` field comparison. The ticket-pack version comes from the README's first body line
(`Generated From: srd.md v{srd_version}`), which the audit skill already reads for Dimension-8 alignment. Tie the
audited-version capture to `audit-round-start <PREFIX> srd|tickets` so the round and the version are recorded
together.

### Out of Scope
The code-audit version drift (code audit audits code, not a versioned doc — N/A). HANDOFF rendering of the drift
flag (WS-N, Epic 2). The Dimension-8 README-header check itself (existing ticket-auditor behavior).

### Verification
QC confirms PASS by recording an audited version of `1.1` against a current `srd_version` of `1.2` and asserting a
drift flag in the audit output, then `1.2` vs `1.2` asserting none; plus a `1.10 > 1.9` semantic-comparison check.

---

## EDMV2-T62: Scoped re-audit support (--lenses subset)

| Field | Value |
|---|---|
| Workstream | WS-B |
| SRD Requirements | EDMV2-30 |
| Priority | Should |
| Size | S |
| Target Components | `skills/code-audit/SKILL.md` — parse an optional `--lenses L1,L3` arg from `$ARGUMENTS` (`:7`, `:24`); launch only the named lenses; synthesizer appends to the existing ledger |
| Dependencies | EDMV2-T57 (pass directories), EDMV2-T58 (ledger append), EDMV2-T60 (partial-round flagging) |

### Description
After remediation, re-running all 11 lenses is wasteful when only a couple were affected. This ticket adds scoped
re-audit: the code-audit skill accepts `--lenses L1,L3` and runs only the named lenses for a targeted follow-up,
while preserving the full findings ledger. A scoped re-audit still starts a new pass (so it has its own
`pass-{N}_{date}/` directory and round index), is recorded as a `partial` round (EDMV2-T60), and appends its
findings to the existing ledger rather than starting a fresh one.

### Acceptance Criteria
- [ ] AC1: `/edm:code-audit <PREFIX> --lenses L1,L3` runs exactly lenses L1 and L3 and no others.
- [ ] AC2: A scoped re-audit still calls `audit-round-start` and gets its own pass-indexed directory.
- [ ] AC3: The scoped round is recorded as `partial` (EDMV2-T60) and is therefore non-convergent (EDMV2-T59).
- [ ] AC4: The scoped run's findings append to the existing `findings-ledger.md`, preserving prior entries and their IDs.
- [ ] AC5: An invalid lens token (e.g., `L99`) is rejected with a clear message listing the valid set L1-L11.
- [ ] AC6: The `--lenses` value parses a comma-separated list with or without spaces (`L1,L3` and `L1, L3` both work).
- [ ] AC7: Omitting `--lenses` runs the full 11-lens set (default behavior unchanged from EDMV2-T57).
- [ ] AC8: The argument-hint in the skill frontmatter documents `[--lenses L1,L3]`.

### Technical Notes
The skill already accepts an optional scope arg (`argument-hint: <PREFIX> [files-or-branch-scope]`, `:7`); add
`--lenses` alongside it. Parsing is in the skill prose (LLM-driven), so describe the parse and validation steps
explicitly. The valid lens set is the table at `:42-54`.

### Out of Scope
Auto-selecting which lenses to re-run based on which files changed (manual subset only). Promoting a scoped round
to convergent (forbidden by EDMV2-T60).

### Verification
QC confirms PASS by invoking with `--lenses L1,L3`, asserting only those two lens reports are produced, the round
is flagged partial and non-convergent, and the ledger retains prior entries.

---

## EDMV2-T63: Findings-ledger canonical home

| Field | Value |
|---|---|
| Workstream | WS-B |
| SRD Requirements | EDMV2-31 |
| Priority | Should |
| Size | XS |
| Target Components | `skills/code-audit/SKILL.md` and `agents/edm-audit-synthesizer.md` — write the ledger to `code-audit/findings-ledger.md` (not per-round); `CLAUDE.md` (plugin) artifact-layout block — add `code-audit/findings-ledger.md`; coordinate with WS-D decisions-ledger convention |
| Dependencies | EDMV2-T58 (ledger content); EDMV2-T76 WS-D ledger pattern (coordination) |

### Description
The findings ledger must live at a single canonical path within the initiative directory rather than being
reconstructed from per-round REMEDIATION files. This ticket fixes that path as
`<initiative-dir>/code-audit/findings-ledger.md` — at the `code-audit/` root, sibling to the `pass-{N}_{date}/`
round directories, so it spans rounds. The path is documented in `CLAUDE.md` and is derived from state
(EDMV2-88).

### Acceptance Criteria
- [ ] AC1: The findings ledger is written to `<initiative-dir>/code-audit/findings-ledger.md`, at the `code-audit/` root (not inside a `pass-{N}_{date}/` directory).
- [ ] AC2: The ledger file exists at that canonical path after the first code-audit round completes.
- [ ] AC3: The path is derived from state (works under both new and legacy layouts).
- [ ] AC4: The synthesizer reads and writes the ledger at this single path across all rounds — no per-round ledger copies are created.
- [ ] AC5: The plugin `CLAUDE.md` artifact-layout block lists `code-audit/findings-ledger.md` with a one-line description.
- [ ] AC6: The path convention is consistent with the WS-D decision/audit-ledger convention (EDMV2-40) — both are top-level initiative-directory ledgers.

### Technical Notes
Pure path-convention ticket; the ledger content/merge logic is EDMV2-T58. Placing the ledger at the `code-audit/`
root (not under a pass directory) is what makes it survive across rounds. Match the §5.4 / §6.3 layout diagrams.

### Out of Scope
Ledger schema and merge semantics (EDMV2-T58). The state-mirror `findings_ledger` array.

### Verification
QC confirms PASS by running one round and asserting `code-audit/findings-ledger.md` exists at the `code-audit/`
root and the `CLAUDE.md` layout block documents it.

---

## EDMV2-T64: QC sharding for large ticket sets

| Field | Value |
|---|---|
| Workstream | WS-C |
| SRD Requirements | EDMV2-32 |
| Priority | Must |
| Size | M |
| Target Components | `skills/implement/SKILL.md` — QC step (`:56-72`): compute ticket count, read `qc_shard_threshold`, spawn N `edm-qc-auditor` instances over ranges; `agents/edm-qc-auditor.md` — accept an assigned ticket range/shard index; `plugin.json` — `qc_shard_threshold` userConfig (default 20) per EDMV2-102 |
| Dependencies | EDMV2-T65 (canonical qc/ home for shard files); EDMV2-T129 userConfig key registration (coordination) |

### Description
A single QC pass over a large ticket set is unreliable — the auditor loses fidelity. This ticket makes QC shard:
when the ticket count exceeds the `qc_shard_threshold` (userConfig, default 20), the implement skill spawns
multiple `edm-qc-auditor` instances, each covering at most 12 tickets, with shard boundaries following epic
boundaries where possible, then merges per-shard reports into a summary. Below the threshold, a single auditor
runs as today.

### Acceptance Criteria
- [ ] AC1: When the ticket count is `> qc_shard_threshold` (default 20), QC runs as multiple `edm-qc-auditor` shards; at or below the threshold, a single auditor runs (current behavior preserved).
- [ ] AC2: Each shard covers at most 12 tickets.
- [ ] AC3: Shard boundaries follow epic boundaries where possible — a shard does not split an epic unless the epic alone exceeds 12 tickets.
- [ ] AC4: A 25-ticket set produces at least two shard files (`qc/qc-shard-01.md`, `qc/qc-shard-02.md`) and a merged `qc/qc-summary.md`.
- [ ] AC5: The threshold is read from the `qc_shard_threshold` userConfig key (default 20); overriding it to 5 causes a 6-ticket set to shard.
- [ ] AC6: Each `edm-qc-auditor` shard is told its assigned ticket range / epic subset and audits only those tickets.
- [ ] AC7: The merged `qc/qc-summary.md` aggregates per-ticket verdicts (PASS/PARTIAL/FAIL counts) across all shards with no ticket missing or double-counted.
- [ ] AC8: Shard files use zero-padded two-digit indices (`qc-shard-01.md`, ..., `qc-shard-10.md`) for stable sort order.
- [ ] AC9: `plugin.json` defines `qc_shard_threshold` with default `20` and omitting it reproduces v1.x single-pass behavior (when ticket count <= 20).

### Technical Notes
Ticket count is the number of `## {PREFIX}-T{NN}:` headings across `tickets/epics/*.md`. Epic-aligned sharding:
walk epics in order, accumulate tickets into the current shard until adding the next epic would exceed 12, then
start a new shard. Spawn shards in a single message with multiple `Task` calls (parallel), mirroring the lens
launch pattern. The `qc_shard_threshold` registration is shared with EDMV2-102 (release); coordinate so it is not
double-defined.

### Out of Scope
The canonical `qc/` directory definition (EDMV2-T65). PARTIAL verdict semantics (EDMV2-T66). The SubagentStop hook
coordination (EDMV2-T68). Per-epic test plans (WS-H, separate epic).

### Verification
QC confirms PASS by running against a 25-ticket fixture and asserting >= 2 shard files plus a summary, an epic not
split across shards, and a `qc_shard_threshold=5` override that shards a 6-ticket set.

---

## EDMV2-T65: Canonical QC artifact home

| Field | Value |
|---|---|
| Workstream | WS-C |
| SRD Requirements | EDMV2-33 |
| Priority | Must |
| Size | S |
| Target Components | `skills/implement/SKILL.md` — write QC output under `<initiative-dir>/qc/`; `agents/edm-qc-auditor.md` — output path; `hooks/hooks.json` SubagentStop prompt (`:49-50`) — direct QC output to `qc/`; `CLAUDE.md` (plugin) artifact-layout block — add `qc/` |
| Dependencies | EDMV2-T37 state-derived path resolution; coordinates with EDMV2-T64 (shards) and EDMV2-T68 (hook) |

### Description
Phase-6 QC output currently has no canonical home — it lands as ad-hoc `qc-audit.md` or inline HANDOFF tables.
This ticket defines the canonical QC artifact home as `<initiative-dir>/qc/`, containing per-shard files
(`qc-shard-NN.md`) and a `qc-summary.md`. A non-sharded (single-auditor) run writes `qc/qc-summary.md` (and
`qc/qc-shard-01.md` for its single shard, or writes the report directly as the summary). The path is documented in
`CLAUDE.md` and derived from state.

### Acceptance Criteria
- [ ] AC1: After QC runs, the report(s) exist under `<initiative-dir>/qc/` — never as a top-level `qc-audit.md` or only inside HANDOFF.
- [ ] AC2: Sharded runs write `qc/qc-shard-NN.md` per shard plus `qc/qc-summary.md`.
- [ ] AC3: A single-auditor (sub-threshold) run writes `qc/qc-summary.md` as the canonical report.
- [ ] AC4: The `qc/` directory path is derived from state (works under new and legacy layouts).
- [ ] AC5: The `edm-qc-auditor` agent's documented output path points at `qc/` (its current report format has no path; this ticket fixes that).
- [ ] AC6: The SubagentStop hook prompt directs auto-triggered QC output into `qc/` (coordinated with EDMV2-T68).
- [ ] AC7: The plugin `CLAUDE.md` artifact-layout block lists `qc/{qc-shard-*.md, qc-summary.md}` with a description.
- [ ] AC8: `mkdir -p` creates `qc/` if absent before any QC write.

### Technical Notes
Matches the §5.2.6 / §6.3 target layout. The `edm-qc-auditor` agent body currently emits a report with no path
(`agents/edm-qc-auditor.md:45-72`); add the canonical output path to its mission. This ticket defines the home;
EDMV2-T64 fills it with shards and EDMV2-T68 makes the hook coherent with it.

### Out of Scope
Sharding logic (EDMV2-T64). PARTIAL verdict persistence (EDMV2-T66/T67). Hook coordination details (EDMV2-T68).

### Verification
QC confirms PASS by running QC (sharded and single) and asserting all output lands under `qc/`, the summary path
exists, and `CLAUDE.md` documents the home.

---

## EDMV2-T66: PASS/PARTIAL/FAIL verdicts with deferred-to-runtime semantics

| Field | Value |
|---|---|
| Workstream | WS-C |
| SRD Requirements | EDMV2-34 |
| Priority | Must |
| Size | S |
| Target Components | `agents/edm-qc-auditor.md` — formalize PARTIAL as "cannot verify statically, requires runtime" (`:36-42`, `:62-72`); add a deferred-to-runtime note convention; `skills/implement/SKILL.md` QC report format (`:109-`) |
| Dependencies | EDMV2-T65 (qc/ home for the report) |

### Description
The QC auditor already names PASS/PARTIAL/FAIL but treats PARTIAL loosely as "some AC met, some gaps." This ticket
gives PARTIAL a precise, distinct meaning per the methodology doc (lines 356/370/390): PARTIAL means an AC
**cannot be verified statically and requires a runtime environment** (e.g., an AC asserting a running service
returns a 201). Such an AC must be recorded as PARTIAL with an explicit deferred-to-runtime note — never invented
as PASS, never marked FAIL. FAIL remains for ACs that are statically verifiable and provably unmet. PASS remains
for statically-verified satisfaction.

### Acceptance Criteria
- [ ] AC1: The auditor classifies each AC as statically-verifiable or runtime-only before assigning a verdict.
- [ ] AC2: An AC that requires a running service / live environment to verify is recorded as PARTIAL with a `deferred-to-runtime: {reason}` note, not PASS and not FAIL.
- [ ] AC3: An AC that is statically verifiable and provably unmet is FAIL (not PARTIAL).
- [ ] AC4: An AC that is statically verified as satisfied is PASS.
- [ ] AC5: A ticket's verdict is PARTIAL when one or more of its ACs are deferred-to-runtime and none are FAIL; FAIL when any AC is FAIL; PASS only when all ACs are PASS.
- [ ] AC6: The auditor never fabricates evidence for a runtime-only AC — the report explicitly states the AC could not be statically verified and why.
- [ ] AC7: Each PARTIAL AC in the report carries a one-line deferral rationale describing what runtime check would resolve it.
- [ ] AC8: The agent description and verdict table (`:36-42`) document the deferred-to-runtime definition of PARTIAL, distinct from FAIL.

### Technical Notes
Methodology-doc alignment: PARTIAL is for the genuinely-unverifiable-statically case, which is common for
performance, integration, and live-service ACs. This prevents the two failure modes the corpus showed: inventing a
PASS for something untestable, and marking it FAIL (which forces pointless remediation). The rationale text is
what EDMV2-T67 persists to state and EDMV2-36 renders in HANDOFF.

### Out of Scope
Persisting verdicts to state (EDMV2-T67). HANDOFF/exec-report rendering of unresolved PARTIALs (EDMV2-36, handled
via EDMV2-T67 + Epic 2 HANDOFF work). Sharding (EDMV2-T64).

### Verification
QC confirms PASS by giving the auditor a fixture ticket with a runtime-only AC (asserts PARTIAL +
deferred-to-runtime note), a statically-unmet AC (asserts FAIL), and a satisfied AC (asserts PASS), plus the
ticket-level worst-case rollup.

---

## EDMV2-T67: record-partial-verdict subcommand and PARTIAL preservation in state + HANDOFF

| Field | Value |
|---|---|
| Workstream | WS-C |
| SRD Requirements | EDMV2-35, EDMV2-36 |
| Priority | Must |
| Size | M |
| Target Components | `bin/edm-state` — new `cmd_record_partial_verdict()`; dispatch case `record-partial-verdict` (`:777-801`); `partial_verdict_map` seeded in `cmd_init`; `write_handoff_internal()` (`:631-766`) renders outstanding PARTIALs; usage header (`:3-20`); `skills/implement/SKILL.md` — calls the subcommand per ticket; `exec-report.md` slot lists unresolved PARTIALs with deferral rationale (WS-D EDMV2-42 coordination) |
| Dependencies | EDMV2-T66 (verdict semantics); EDMV2-T24 file locking; EDMV2-T48 WS-N HANDOFF Resume-Point/rendering plumbing from Epic 2 |

### Description
PARTIAL verdicts and their deferred-to-runtime reasons must survive in `.edm-state.json` and surface in HANDOFF so
a teammate sees exactly what still needs runtime verification. This ticket adds
`record-partial-verdict <PREFIX> <ticket> <verdict> [note]`, which persists a per-ticket entry into a
`partial_verdict_map` object in state, and extends `write_handoff_internal()` to render an "Outstanding PARTIAL
verdicts" section listing each PARTIAL ticket with its deferral note. The exec-report slot (WS-D EDMV2-42) lists
all unresolved PARTIALs with their deferral rationale.

### Acceptance Criteria
- [ ] AC1: `edm-state record-partial-verdict <PREFIX> EDMV2-T07 PARTIAL "needs running service"` writes `partial_verdict_map["EDMV2-T07"] = {verdict: "PARTIAL", note: "needs running service"}` to state.
- [ ] AC2: The subcommand accepts verdict values `PASS`, `PARTIAL`, `FAIL`; any other value exits non-zero with a usage message.
- [ ] AC3: The `[note]` argument is optional; when omitted the entry stores an empty note (`""`), and the call still succeeds.
- [ ] AC4: Re-recording a verdict for the same ticket overwrites that ticket's entry (idempotent per ticket), not append a duplicate.
- [ ] AC5: The write goes through the locked `write_state()` so concurrent shard writes (EDMV2-T64) serialize without corrupting `partial_verdict_map`.
- [ ] AC6: `cmd_init` seeds `partial_verdict_map: {}` (or it is created lazily on first write with a `// {}` default on read).
- [ ] AC7: `write_handoff_internal()` renders an "Outstanding PARTIAL verdicts" section listing every ticket whose verdict is `PARTIAL`, each with its deferral note; tickets with PASS/FAIL are not listed there.
- [ ] AC8: When `partial_verdict_map` is empty or absent, HANDOFF renders no PARTIAL section (or a "none" line) and does not error.
- [ ] AC9: The rendered HANDOFF section and any exec-report listing are ASCII-only (no Unicode markers).
- [ ] AC10: Missing required arguments exit non-zero with `usage: edm-state record-partial-verdict <PREFIX> <ticket> <verdict> [note]` and no state mutation.
- [ ] AC11: A fixture `.edm-state.json` lacking `partial_verdict_map` is read without error; resolves to `{}` via `jq // {}` guard.
- [ ] AC12: The `## Notes` awk parse (`:729-731`) and `## Key Decisions Made` block (`:719-720`) still extract correctly after this section is added; section order is documented and compatible with T81 (WS-D checklist), T99 (lifecycle), and T103 (related initiatives).

### Technical Notes
Use `jq --arg ticket ... --arg v ... --arg note ...` to set the nested object; verdict is a constrained string, so
the existing `--arg` string path is correct (no typed-set needed here). The HANDOFF rendering hooks into
`write_handoff_internal()` (`:631-766`); follow the existing section-rendering style and use `[present]`/`[absent]`
ASCII conventions established by EDMV2-21. Coordinate the exec-report listing with WS-D EDMV2-42 (the exec-report
slot is defined in Epic 2 / WS-D; this ticket populates its PARTIAL section).

The `write_handoff_internal()` heredoc is edited by T67, T81, T99, and T103. These tickets must coordinate on
section order. T99 is designated the owner of the final combined section sequence.

### Out of Scope
The verdict classification logic (EDMV2-T66). The exec-report slot definition itself (WS-D EDMV2-42). The
Resume-Point block (WS-N, Epic 2) — this ticket adds a sibling HANDOFF section only.

### Verification
QC confirms PASS by recording a PARTIAL with a note (asserts the nested state entry and JSON shape), recording
without a note (asserts empty note), re-recording (asserts overwrite), running an invalid verdict (asserts
non-zero exit), and running `write-handoff` to assert the PARTIAL section renders ASCII-only.

---

## EDMV2-T68: QC sharding hook coordination (SubagentStop)

| Field | Value |
|---|---|
| Workstream | WS-C |
| SRD Requirements | EDMV2-37 |
| Priority | Should |
| Size | S |
| Target Components | `hooks/hooks.json` — `SubagentStop` matcher `edm-implementer` prompt (`:44-53`): make auto-QC coherent with sharded QC and write to `qc/`; `skills/implement/SKILL.md` — reconcile hook-triggered QC with explicit sharded runs |
| Dependencies | EDMV2-T64 (sharding), EDMV2-T65 (qc/ home), EDMV2-T66 (verdicts), EDMV2-T67 (verdict persistence) |

### Description
The `SubagentStop` hook auto-spawns `edm-qc-auditor` after each `edm-implementer` finishes. With sharded QC now in
play, this auto-trigger must not conflict with an explicit sharded run: it must scope itself to the tickets the
just-completed implementer worked on, write into the canonical `qc/` home, and record verdicts via
`record-partial-verdict` — producing no duplicate or conflicting artifacts when a full sharded QC later runs.

### Acceptance Criteria
- [ ] AC1: An `edm-implementer` subagent stop triggers QC scoped to the tickets that implementer just worked on, not the entire ticket set.
- [ ] AC2: The auto-triggered QC writes its report into the canonical `qc/` home (EDMV2-T65), using a non-colliding filename (e.g., `qc/qc-auto-{ticket-range}.md`) so it does not overwrite a sharded `qc-shard-NN.md`.
- [ ] AC3: The auto-triggered QC records per-ticket verdicts via `record-partial-verdict` (EDMV2-T67) so results persist in state.
- [ ] AC4: A subsequent explicit sharded QC run (EDMV2-T64) does not produce duplicate verdict entries — re-recording overwrites per ticket (EDMV2-T67 AC4), so state stays consistent.
- [ ] AC5: The hook does not error or block the session when no sharded run is active or when the ticket scope cannot be determined (best-effort, falls back to a friendly note).
- [ ] AC6: The hook prompt references PASS/PARTIAL/FAIL with the deferred-to-runtime PARTIAL semantics (EDMV2-T66), not the old loose PARTIAL.
- [ ] AC7: Auto-QC and explicit sharded QC artifacts coexist in `qc/` without overwriting each other.

### Technical Notes
The current hook prompt (`hooks.json:49-50`) tells QC to "read the relevant epic file" and report per ticket — it
already scopes to the just-completed work conceptually; this ticket makes the path (`qc/`), verdict persistence
(`record-partial-verdict`), and PARTIAL semantics explicit and coherent with sharding. Keep the hook best-effort
(it must never fail the session). This is a `prompt` hook, so changes are to the instruction text.

### Out of Scope
The sharding algorithm (EDMV2-T64). The `qc/` home definition (EDMV2-T65). Converting this to a deterministic
`command` hook (out of scope; QC needs an LLM agent).

### Verification
QC confirms PASS by simulating an implementer stop and asserting the auto-QC report lands in `qc/` with a
non-colliding name, verdicts are recorded via `record-partial-verdict`, and a later sharded run does not duplicate
entries.
