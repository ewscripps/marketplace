# Epic 02: GateGuard

Scope item 4.1: a fact-forcing `PreToolUse` edit gate for Phase 6, implemented as a bash rewrite
per AD1 (ratified at Gate 2 as decisions.md D14, 2026-09-02) with the destructive-`Bash` arm
descoped (D15). Six tickets: `EDMV4-T11` builds `bin/edm-gateguard` itself and registers its
matcher block; `EDMV4-T12` builds the Phase-6 marker primitive and its SessionStart
reconciliation inside `edm-state`; `EDMV4-T13` builds the single `emit_decision` function with its
two selectable deny back-ends; `EDMV4-T14` writes the fact-forcing denial content and the per-file
`MultiEdit` loop; `EDMV4-T15` adds the operational safety controls (kill switches, exemptions,
fail-open, denial budget); `EDMV4-T16` records ECC and GateGuard provenance in the house-style
attribution section. `EDMV4-T11` is the spine -- it blocks `EDMV4-T13`, `EDMV4-T14` and
`EDMV4-T15` one-way, never mutually, because every deny mechanism and every knob lives inside the
script it creates.


> **Line numbers in this epic are ADVISORY (ticket-pack audit P1-2).** Every `file:line` citation
> here -- including the "stale SRD citations, corrected" tables in the Technical Notes below -- was
> verified against the **pre-fast-forward** tree. The fast-forward's `6e29dcb` re-inserted four
> lines at `bin/edm-state:504-507`, so this epic's corrections are now wrong where the SRD is
> right: `ALL_LENS_IDS` is at **1613**, `MODE_ENUM_LIST` at **807**, `state_anomalies()` at
> **1709**. Symbols above line 4000 have drifted further than either document.
>
> **Locate every site by symbol name or by the literal string the AC quotes, at edit time.** Do not
> "correct" `srd.md` toward any number in this pack -- see `EDMV4-T08` AC8.

---

## EDMV4-T11: Build `bin/edm-gateguard` and register its `Edit`/`Write`/`MultiEdit` matcher block

| Field | Value |
|---|---|
| Epic | GateGuard |
| Phase | 2 |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV4-07 |
| Depends On | EDMV4-T06, EDMV4-T07, EDMV4-T10, EDMV4-T17 |
| Target Components | `plugins/edm/bin/edm-gateguard` (new), `plugins/edm/hooks/hooks.json` (the `PreToolUse` array), `plugins/edm/bin/_edm-cli-lib.sh`, `plugins/edm/bin/edm-lint-artifacts` (the `EDM-HELP` block), `plugins/edm/bin/tests/wave8-smoke.sh` (new), `plugins/edm/bin/tests/timing.sh` (new `--gateguard` mode) |

### Description

EDM has never enforced anything at per-tool-call cadence. Today `PreToolUse` fires exactly once per
`git commit`, where a human is already waiting and a 3,000 ms budget is acceptable. An edit gate
fires tens to hundreds of times per Phase 6 wave, so the entire structure of this script follows
from refusing to pay `edm-state`'s startup cost at that frequency: `edm-state` is a roughly
6,300-line script that pays a fresh parse plus at least one `jq` subprocess per invocation, and the
rejected alternative (re-running `cmd_active_initiatives`'s sweep) costs one `jq` per active
initiative on every edit.

This ticket delivers the script's structure and its host registration, not its decisions. It is a
rewrite, not a vendoring, per AD1 as ratified in D14: upstream `zunoworks/gateguard` is Python and
ECC's copy is a JavaScript port, so neither offers a bash implementation to adopt, and both would
add a runtime dependency the plugin has never had. D15 descoped the destructive-`Bash` arm, which
is what deletes ECC's 741 lines of shell tokenizer (`shell-substitution.js` plus
`gateguard-heredoc.js`) from the port surface entirely.

Every acceptance criterion below is structural and independently completable without a working deny
path. That is deliberate: `EDMV4-09`'s `emit_decision` lives inside this script, so it cannot
precede the script's existence. v1.0.0 of the SRD declared a mutual dependency between the two,
which is a cycle and unschedulable.

### Acceptance Criteria

- [ ] AC1: `plugins/edm/bin/edm-gateguard` exists, `test -x` succeeds on it, and `wc -l` reports a
      count in the closed range 200 to 400 (AD1's estimate is 250-350; the band allows for house
      boilerplate). `bin/tests/wave8-smoke.sh` asserts both bounds.
- [ ] AC2: The script sources `_edm-cli-lib.sh` and its `usage()` calls
      `print_help "${BASH_SOURCE[0]:-$0}"` against a `# EDM-HELP-BEGIN` / `# EDM-HELP-END`
      sentinel block, following `edm-lint-artifacts:1-70` and `edm-compare-eval:2-33`. A smoke
      assertion greps the script for a `sed -n '<A>,<B>p'` help range and fails if one is present.
- [ ] AC3: `hooks/hooks.json` gains exactly one new `PreToolUse` matcher block matching `Edit`,
      `Write` and `MultiEdit`, whose `command` begins
      `command -v edm-gateguard >/dev/null 2>&1 || exit 0` before exec, mirroring the existing
      `git commit` block's guard at `hooks.json:86`. A smoke assertion runs
      `jq '.hooks.PreToolUse | length'` and asserts the result is 2.
- [ ] AC4: The existing `git commit` matcher block is byte-identical after the change:
      `git diff -- plugins/edm/hooks/hooks.json` shows no modified line inside it, and a smoke
      assertion extracts `.hooks.PreToolUse[] | select(.matcher == "git commit") | .hooks[0].command`
      and compares it against the literal
      `command -v edm-lint-staged-artifacts >/dev/null 2>&1 || exit 0; edm-lint-staged-artifacts`.
- [ ] AC5: The script contains zero invocations of `edm-state`:
      `grep -c 'edm-state' plugins/edm/bin/edm-gateguard` returns 0, asserted by
      `bin/tests/wave8-smoke.sh`.
- [ ] AC6: The script contains no destructive-`Bash` detection -- no regex over shell commands, no
      heredoc stripping, no subshell explosion. `grep -ci 'destructive\|heredoc\|subshell'` over the
      script returns 0. (Follows from D15, ratified at Gate 2.)
- [ ] AC7: The plugin's required-binary set is unchanged. The script invokes only bash builtins,
      `jq`, and `stat`/`test`; `grep -cE '\b(node|python3?|npx|pip)\b'` over it returns 0.
- [ ] AC8: `jq` is a dependency only after the marker test passes. The script carries no
      top-of-script `require_jq`-style precondition; a smoke assertion computes the line number of
      the marker `test -f` with `grep -n` and the line number of the first `jq` reference with
      `grep -n`, and fails unless the marker line number is strictly lower.
- [ ] AC9: `bin/tests/wave8-smoke.sh` runs the script with the Phase-6 marker absent and with `jq`
      moved off `PATH`, and asserts exit status 0, empty stdout, and zero `jq` processes spawned.
- [ ] AC10: `bin/tests/timing.sh` gains a `--gateguard` mode that measures the allow-path p95 over
      a generated fixture, following the two existing modes' shape (`--lint`, `--all-lint`): it
      states the fixture size alongside every figure it prints, per
      `plugins/edm/CLAUDE.md Sec."edm-lint-artifacts latency budgets"`, which requires a budget
      never be quoted without its input size. It measures **both** branches -- marker-absent (the
      fast exit) and marker-present (the full gate) -- because only the second exercises the
      per-edit `stat`.
- [ ] AC11: The measured allow-path p95 is recorded, with its fixture size and the machine it was
      measured on, in this ticket's completion note and in `decisions.md`. The **50 ms figure is a
      design target, not a verified property**, until that measurement exists -- SRD Sec.9.3's own
      wording -- so this AC is satisfied by recording a real number, whatever it is, and by
      stating explicitly whether the target was met. If the budget cannot be met, that is a
      finding for the gate, not a licence to inline logic into the hook's JSON string, which is
      the thing CA-436 exists to prevent.

### Technical Notes

- **Bash 3.2 floor (C1)**: no associative arrays, no `${var^^}`, no `mapfile`. Required binaries
  stay `bash`, `jq`, `git` (C2), with `stat`/`test` as builtin-adjacent per AC7.
- **Citation drift verified.** `hooks.json` in the current branch tree opens `"PreToolUse": [` at
  line 80, the `git commit` block object spans 81-89, and the `command -v edm-lint-staged-artifacts`
  guard sits at line 86 exactly as the SRD states. `edm-lint-artifacts` carries `# EDM-HELP-BEGIN`
  at line 10 and `# EDM-HELP-END` at line 70, with `print_help "${BASH_SOURCE[0]:-$0}"` at line 85,
  so the `:1-70` citation holds. `edm-compare-eval`'s sentinels are at lines 2 and 33.
- **Smoke-suite discovery.** `bin/tests/run-all.sh` auto-discovers every `*-smoke.sh` file via
  `find "$_SUITE_DIR" -maxdepth 1 -name '*-smoke.sh'` (run-all.sh:45) and runs suites that are not
  in `_PREFERRED_ORDER`, so `wave8-smoke.sh` is picked up with no edit to the aggregator. Note that
  `_MIN_SUITE_COUNT` defaults to 7 (run-all.sh:87) and there are 7 suites today; adding an eighth
  leaves the backstop satisfied but no longer tight. Bumping it to 8 in the same commit keeps the
  "a suite was deleted" tripwire meaningful. That bump is not an acceptance criterion here.
- **`EDMV4-08` in the SRD's dependency line** is satisfied inside this epic by `EDMV4-T12`, which
  lands in the same phase. None of AC1-AC9 requires a working marker, so the two can be built in
  either order; the recorded `Depends On` follows the ticket-pack DAG.
- **The `timing.sh --gateguard` mode is now owned here (AC10, AC11).** This note originally flagged
  it as absent from every AC across `EDMV4-07` through `EDMV4-12` and handed the question to the
  ticket audit. Both audit lanes independently confirmed the gap was real and pack-wide -- three
  tickets disowned it in Out of Scope and none claimed it -- so it landed here per `srd.md` Sec.9.1,
  which assigns the target to `EDMV4-07`. Flagging rather than silently absorbing it was the right
  call and is why the gap closed instead of shipping.
- **Do not quote ECC's effect-size number.** `ECC/skills/gateguard/SKILL.md:3` claims "+2.25 points
  vs ungated agents"; risk R9 records that figure as n=2, self-reported and unblinded, and forbids
  it appearing in any AC as a target.

### Out of Scope

The deny mechanism and its back-ends (`EDMV4-T13`), the denial fact content and the `MultiEdit`
loop (`EDMV4-T14`), kill switches, exemption globs, session state and the denial budget
(`EDMV4-T15`), the marker primitive and its lifecycle inside `edm-state` (`EDMV4-T12`), any
destructive-`Bash` detection (descoped by D15), and the `PreToolUse` `Bash` matcher block for
hookify (gated on Spike A, owned by scope item 5.3).

**No longer out of scope**: the `timing.sh --gateguard` mode and its 50 ms p95 allow-path budget.
Ticket-pack audit finding P1-1 established that it was owned by no ticket in the pack -- three
tickets disowned it in Out of Scope and none claimed it, leaving SRD Sec.9.1 and risk R4 orphaned.
It is now AC10 and AC11 above, per `srd.md` Sec.9.1, which assigns the target to `EDMV4-07`.

---

## EDMV4-T12: Add the Phase-6 marker primitive with SessionStart reconciliation

| Field | Value |
|---|---|
| Epic | GateGuard |
| Phase | 2 |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV4-08 |
| Depends On | EDMV4-T17 |
| Target Components | `plugins/edm/bin/_edm-datadir-lib.sh` (new), `plugins/edm/bin/edm-state` (`cmd_phase_start`, `cmd_phase_complete`, `cmd_archive`, `cmd_skip_phase`, `cmd_session_start`), `plugins/edm/bin/tests/wave8-smoke.sh` (new) |

### Description

No cheap per-tool-call "which initiative is active" path exists today. The nearest primitives --
`cmd_active_initiatives`, `cmd_session_start` and `cmd_checkpoint` (which additionally takes a write
lock and computes SHA-256 over every tracked artifact) -- all run at SessionStart, Stop or
PreCompact cadence, a handful of times per conversation. Running any of them per edit is the exact
failure mode this requirement exists to prevent: at the 50-initiative fixture size the plugin's own
latency table already uses, the sweep is 50 `jq` invocations per edit.

The answer is a marker file at a fixed, project-keyed path outside the repository, written when
Phase 6 starts and removed when it ends. GateGuard's common case -- "not in Phase 6, allow" --
becomes one process exec and one `test -f`, with zero `jq` subprocesses and zero state reads.

The marker is a derived cache, never a second source of truth. SessionStart reconciles it against
`.edm-state.json` in both directions and never the reverse, which is what makes every failure mode
here self-healing rather than sticky. Every write is best-effort: a marker failure must never fail a
phase transition, and an unresolvable data directory must degrade to today's behaviour (no gate at
all), never to a deny.

### Acceptance Criteria

- [ ] AC1: `plugins/edm/bin/_edm-datadir-lib.sh` exposes `edm_marker_path()`, printing
      `${data}/run/<project-key>.phase6`. Its body spawns zero subprocesses: a smoke assertion
      extracts the function body and fails if it contains `$(`, a backtick, or a pipe.
- [ ] AC2: `cmd_phase_start` writes the marker when the phase being started is 6, after the
      successful `rmw_state`. A smoke test makes the resolved data directory read-only, runs
      `phase-start <PREFIX> 6`, and asserts the command still exits 0 with a warning on stderr.
- [ ] AC3: `cmd_phase_complete` removes the marker when the phase being completed is 6 and only when
      the marker's recorded PREFIX matches the completing initiative. A smoke test writes a marker
      for PREFIX A, completes phase 6 for PREFIX B, and asserts the marker still exists and still
      names A.
- [ ] AC4: `cmd_archive` and `cmd_skip_phase` remove the marker defensively, and both exit with
      their pre-change status when no marker is present.
- [ ] AC5: `cmd_session_start` reconciles in both directions: a marker whose named initiative is not
      at `current_phase == 6` is removed with exactly one line of operator output saying so, and an
      absent marker is recreated when some initiative is at phase 6.
- [ ] AC6: The marker holds exactly one line, `PREFIX<TAB>initiative_dir<TAB>started_at`, written
      with a literal tab (`printf '%s\t%s\t%s\n'`) and a UTC ISO-8601 timestamp.
- [ ] AC7: The marker path is outside the repository. A smoke assertion runs `phase-start <PREFIX> 6`
      in a fixture repo and asserts `git status --porcelain` is empty and that no file exists under
      `${EDM_SRD_ROOT}`.
- [ ] AC8: `edm_data_dir()` resolves `${CLAUDE_PLUGIN_DATA}` when absolute and creatable, then
      `${XDG_DATA_HOME}/edm` when `XDG_DATA_HOME` is absolute, then `${HOME}/.local/share/edm`, then
      prints an empty string. A relative value at any step falls through with a stderr warning and a
      zero exit status rather than erroring.
- [ ] AC9: When `edm_data_dir()` returns empty, `edm_marker_path()` returns empty and
      `edm-gateguard` treats that as "marker absent" and allows. A smoke test unsets all three
      variables (or points them at relative paths) and asserts the gate exits 0 with no output.
- [ ] AC10: `edm_project_key()` resolves `CLAUDE_PROJECT_DIR` when it names a directory, then
      `git rev-parse --show-toplevel`, then `pwd`, and replaces `/` and `.` with `-` using pure bash
      parameter expansion. A smoke test invokes the gate from a subdirectory of the fixture repo and
      asserts it resolves the same marker path `edm-state` wrote from the repository root.
- [ ] AC11: `bin/tests/wave8-smoke.sh` covers all five lifecycle cases end to end:
      create-on-`phase-start 6`, remove-on-`phase-complete 6`, remove-on-`archive`, PREFIX-mismatch
      non-removal, and SessionStart reconciliation in both directions.

### Technical Notes

- **Anchor edits by function name, not by line.** The SRD and `architecture.md` cite
  `cmd_phase_start` at `edm-state:2508-2562`, `cmd_phase_complete` at `:2564+`, `cmd_checkpoint` at
  `:2735+`, `cmd_archive` at `:3096+`, `cmd_active_initiatives` at `:3900-3916` and
  `cmd_session_start` at `:4347+`. On the current branch tree those functions begin at 2504, 2560,
  2731, 3092, 3896 and 4343 -- a uniform four-line drift. `session_dir_for_cwd` at `:307` and
  `cmd_skip_phase` (at 5119) are unaffected. Re-verify with
  `grep -n '^cmd_phase_start()' plugins/edm/bin/edm-state` before quoting a line number anywhere.
- **AC8 and AC10 restate contracts `EDMV4-T17` (`EDMV4-13`) delivers.** That ticket owns
  `_edm-datadir-lib.sh` and its own coverage; this ticket adds `edm_marker_path()` and asserts the
  two resolvers from the marker's point of view. If T17 has landed, AC8 and AC10 are verification
  rather than implementation. Do not fork a second resolution chain.
- **Consumer set.** `architecture.md:97` prose names `edm-hookify` as a third sourcing consumer
  while its own component table at `:213` omits it; `EDMV4-13` resolves this to two consumers,
  `edm-state` and `edm-gateguard`. Do not source the library from `edm-hookify`.
- **Bash 3.2**: `${key//\//-}` and `${key//./-}` are both legal in 3.2 and are the pure-bash form
  the project-key encoding needs; `tr` would spawn a subprocess on a path GateGuard runs per edit.
  `${var^^}` is not available -- do not normalise case that way.
- **Sourcing safety.** Guard the `source` in `edm-state` with a file test so a partial install never
  breaks the 39 existing subcommands, and keep the library free of top-level side effects.
- **Two initiatives at Phase 6 (R6).** The marker is per-project and holds the most recent Phase 6
  entry. AC3's PREFIX match plus AC5's reconciliation are jointly the mitigation -- neither alone
  is sufficient.

### Out of Scope

`edm-gateguard`'s own reading of the marker (`EDMV4-T11`), the GateGuard session-state file
`${data}/run/<project-key>.checked` and its cap and expiry (`EDMV4-T15`), the harvested pattern
delta under `${data}/patterns/` (scope item 4.2), and `edm-state validate`'s R3 upgrade-detection
anomaly.

---

## EDMV4-T13: Route every GateGuard decision through one `emit_decision` with two back-ends

| Field | Value |
|---|---|
| Epic | GateGuard |
| Phase | 2 |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV4-09 |
| Depends On | EDMV4-T07, EDMV4-T11 |
| Target Components | `plugins/edm/bin/edm-gateguard` (new), `plugins/edm/bin/edm-lint-staged-artifacts:7-10,150-158`, `plugins/edm/CLAUDE.md Sec."Hooks behavior"`, `plugins/edm/bin/tests/wave8-smoke.sh` (new) |

### Description

Per AD2, every refusal routes through a single `emit_decision deny|allow <reason>` function with two
back-ends selected by `EDM_GATEGUARD_DENY_MODE`. This exists for two reasons. First, whether an
exit-code-only hook can deny a native `Edit` is Spike B and is unverified in both directions, so the
design must let the spike's outcome flip a default constant and a smoke assertion rather than force
a rewrite. Second, `permissionDecision` and `hookSpecificOutput` appear zero times in this
repository -- it is a response protocol this plugin's tooling has never reasoned about -- so it must
be emitted from exactly one place where its shape can be parsed and asserted.

The exit-code split must match `edm-lint-staged-artifacts` exactly. That script's help block states
the contract at lines 7-10 and its body enforces it at lines 150-158: `edm-lint-artifacts` exit 1
(a real violation) becomes `fail=2` and the script exits 2, the code that blocks; a setup error is
reported to stderr and does not block. A divergent third convention on the same event is precisely
the drift EDM's helper table exists to prevent.

### Acceptance Criteria

- [ ] AC1: All deny and allow decisions in `edm-gateguard` are emitted by one function. A smoke test
      greps the script for `printf`, `echo` and `exit` statements producing a decision outside
      `emit_decision`'s body and fails on any hit.
- [ ] AC2: With `EDM_GATEGUARD_DENY_MODE=json` (the default), a denial prints exactly
      `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"<facts>"}}`
      on stdout and exits 0. Nothing is written to stdout on an allow.
- [ ] AC3: With `EDM_GATEGUARD_DENY_MODE=exit-code`, a denial prints the fact list on stderr, writes
      nothing to stdout, and exits 2 -- the same code `edm-lint-staged-artifacts:7-10` already means
      "block".
- [ ] AC4: Any other value of `EDM_GATEGUARD_DENY_MODE` is a setup error: a stderr warning naming
      both legal values (`json` and `exit-code`), exit 1, and no block. A smoke test asserts
      `EDM_GATEGUARD_DENY_MODE=yes` exits 1 with empty stdout.
- [ ] AC5: Exit 1 is reserved for setup errors and never blocks, matching the CA-298 convention
      recorded in `CLAUDE.md Sec."Hooks behavior"` that a setup condition never blocks while a real
      refusal does. No code path in the script exits 1 on a policy refusal.
- [ ] AC6: The default value is a single named constant set from `EDMV4-02`'s recorded Spike B
      decision, and `bin/tests/wave8-smoke.sh` asserts the constant's value equals that decision, so
      a silent revert fails a test rather than a wave.
- [ ] AC7: `bin/tests/wave8-smoke.sh` pipes an emitted denial through
      `jq -e '.hookSpecificOutput.permissionDecision == "deny"'` and fails on a non-zero status, so
      an unparseable payload is a test failure rather than a silently unenforced gate.
- [ ] AC8: The `permissionDecisionReason` string is valid JSON with embedded newlines, double
      quotes and backslashes escaped. A smoke test denies on a file path containing a literal `"`
      and asserts the emitted payload still parses under `jq -e .`.
- [ ] AC9: The emitted JSON is ASCII-only (`LC_ALL=C grep -q '[^ -~]'` over the payload finds
      nothing outside tab and newline), and `bin/edm-check-vocabulary` passes over the new script.

### Technical Notes

- **Build the payload with `jq -n`, not string concatenation.** A hand-rolled escaper is the
  failure mode AC8 exists to catch. `jq -n --arg reason "$facts" '{hookSpecificOutput: {...}}'`
  handles quotes, backslashes and newlines correctly in one call. This does not violate
  `EDMV4-07` AC8's zero-`jq` allow-path guarantee: by the time `emit_decision deny` runs, the
  marker test has already passed, so `jq` is legitimately a dependency of that path (AD3's
  qualifier). Keep every `jq` reference below the marker test in file order.
- **`exit-code` mode needs no JSON at all** -- the fact list goes to stderr as plain text, so AC8's
  escaping concern applies only to the `json` back-end.
- **Verified citations.** `edm-lint-staged-artifacts` lines 7-10 state "exit 2 = at least one real
  artifact violation (blocks the commit when run as the PreToolUse git-commit hook); exit 1 =
  setup/configuration error (non-blocking)", and the body at 150-158 implements it with
  `fail=2` on `edm-lint-artifacts` exit 1 and a non-blocking stderr report on exit 2. Both hold on
  the current branch.
- **`edm-check-vocabulary` scans `bin/`** per the helper table in `plugins/edm/CLAUDE.md`, so the
  new script is in its scope automatically; AC9 is a re-assertion, not a new registration.
- **R2 bounds what AC7 can prove.** A smoke assertion catches a malformed emission but cannot catch
  a host that parses the payload and ignores it. Only Spike B, run against the live host, closes
  that; AC6's constant is the one-line lever if it comes back negative.

### Out of Scope

The content of the fact list (`EDMV4-T14`), which conditions reach a denial at all (`EDMV4-T15`),
the marker test (`EDMV4-T12`), and hookify's `file`-event rule escalation through the same function
(scope item 5.3).

---

## EDMV4-T14: Write the fact-forcing denial content and the per-file `MultiEdit` loop

| Field | Value |
|---|---|
| Epic | GateGuard |
| Phase | 2 |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV4-10 |
| Depends On | EDMV4-T11, EDMV4-T13 |
| Target Components | `plugins/edm/bin/edm-gateguard` (new), `plugins/edm/bin/tests/wave8-smoke.sh` (new), `plugins/edm/CLAUDE.md Sec."Prompt conventions (house style)"` |

### Description

The gate's entire value is that the denial reason is a numbered list of facts the agent must
produce, not a confirmation prompt. Asking a model "did you violate any policies" gets "no"; asking
"list every file that imports this module" forces a `Grep` and a `Read`, and the context that
investigation produces is what changes the output. The mechanism is the adopted thing, and it is
adopted structurally -- the wording is EDM's own.

EDM substitutes one fact for a better one it already has. Where the source demands the user's
current instruction quoted back, EDM demands the acceptance criteria of the ticket being
implemented, by `{PREFIX}-T{NN}` ID, so the gate reinforces ticket traceability instead of
re-narrating a prompt the agent already holds.

`MultiEdit` is handled per file: a batch with three unchecked files needs three retries, not one.
Denying on the first still-unchecked path and returning immediately is what makes each retry carry
its own investigation.

### Acceptance Criteria

- [ ] AC1: An `Edit` denial emits exactly four numbered facts, in order: (1) list all files that
      import or require this file, searching the tree; (2) list the public functions or classes
      affected by this change; (3) if this file reads or writes data files, show field names,
      structure and date format using redacted or synthetic values, never raw production data;
      (4) quote the acceptance criteria of the ticket being implemented, by `{PREFIX}-T{NN}` ID.
- [ ] AC2: A `Write` (new file) denial swaps facts 1 and 2 for: name the file(s) and line(s) that
      will call this new file, and confirm no existing file already serves the same purpose. Facts
      3 and 4 are byte-identical to the `Edit` variant.
- [ ] AC3: Fact 4 is the ticket-AC form in both variants, and
      `grep -c 'quote the user.s current instruction' plugins/edm/bin/edm-gateguard` returns 0.
- [ ] AC4: `MultiEdit` iterates the batch and denies on the first still-unchecked `file_path`,
      returning immediately without evaluating the rest. A smoke test with a three-file batch, all
      unchecked, asserts three successive denials naming a different path each time, and an allow on
      the fourth call.
- [ ] AC5: A `MultiEdit` batch where every file is already recorded as checked allows on the first
      call, with exit 0 and empty stdout.
- [ ] AC6: The denial text is plain ASCII: `LC_ALL=C grep -n '[^ -~]'` over the emitted reason
      returns nothing, so no em dash, arrow, smart quote or emoji can reach the operator
      (`EDMV4-57`).
- [ ] AC7: No text is copied verbatim from `gateguard-fact-force.js` or ECC's
      `skills/gateguard/SKILL.md`. The fact list is re-expressed in EDM's own register, and the
      clean-room posture recorded in `CLAUDE.md Sec."Prompt conventions (house style)"` for
      `caveman` and `ponytail` is the standard applied.
- [ ] AC8: `bin/tests/wave8-smoke.sh` asserts each of the four `Edit` facts and each of the two
      swapped `Write` facts appears in the corresponding denial output, matching on a distinctive
      substring per fact rather than on the whole block.

### Technical Notes

- **`MultiEdit`'s payload shape is an unverified premise.** `architecture.md` and the SRD assume a
  batch of `edits[].file_path` entries spanning several files, inherited from ECC's implementation.
  Claude Code's own `MultiEdit` applies several edits to a *single* file: `tool_input.file_path`
  plus `tool_input.edits[]` of `old_string`/`new_string`. If that is what the host actually sends,
  AC4's three-file batch is not representable and the smoke fixture asserts a shape that never
  occurs. Confirm the real payload against a live host before writing the fixture, and make the
  extraction tolerant of both shapes -- collect `.tool_input.file_path` and
  `.tool_input.edits[]?.file_path?` into one de-duplicated list -- rather than assuming either.
  Record the confirmed shape in `decisions.md`; do not silently narrow AC4.
- **The gate cannot resolve the ticket ID for the agent.** Fact 4 demands the agent name and quote
  it, because resolving `{PREFIX}-T{NN}` from state would require `edm-state`, which
  `EDMV4-07` AC5 forbids outright.
- **Citation status.** The behaviour sources cited by the SRD -- `gateguard-fact-force.js:1062-1076`
  (Edit facts), `:1078-1092` (Write facts), `:1234-1256` (the `MultiEdit` loop) -- were not
  line-verified for this ticket. The file exists at
  `/Users/darryl.porter/projects/ECC/scripts/hooks/gateguard-fact-force.js` (the SRD's bare filename
  omits `scripts/hooks/`), and other citations into it were confirmed exact. Re-check the three
  ranges above with `sed -n` before treating them as anchors; they are read for mechanism only and
  nothing is copied either way.
- **Bash 3.2**: build the fact list with a quoted multi-line string or successive `printf` calls,
  never an associative array keyed by tool name. A `case "$tool_name" in Edit|Write|MultiEdit)`
  dispatch is the portable form.
- **Do not cite ECC's "+2.25 points" claim** (`ECC/skills/gateguard/SKILL.md:3`) anywhere in the
  denial text or in an AC. Risk R9 records it as n=2, self-reported and unblinded; `/edm:metrics`
  measuring Phase 6 QC FAIL rate before and after is the honest instrument.

### Out of Scope

The transport that carries the fact list to the host (`EDMV4-T13`), the exemption match and session
state that decide whether a denial happens (`EDMV4-T15`), the marker (`EDMV4-T12`), and any
destructive-`Bash` fact variant (descoped by D15).

---

## EDMV4-T15: Add GateGuard's operational safety controls

| Field | Value |
|---|---|
| Epic | GateGuard |
| Phase | 2 |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV4-11 |
| Depends On | EDMV4-T11, EDMV4-T13, EDMV4-T17 |
| Target Components | `plugins/edm/bin/edm-gateguard` (new), `plugins/edm/bin/_edm-datadir-lib.sh` (new), `plugins/edm/CLAUDE.md Sec."Testing changes"`, `plugins/edm/bin/tests/wave8-smoke.sh` (new) |

### Description

The graduated controls are what make a per-edit gate safe to ship. Each narrows one behaviour while
leaving the load-bearing checks running, and every state-write failure path allows rather than
loops: a gate that cannot record what it has already asked would otherwise deny the same edit
forever. Two independent kill switches travel, not one -- the source analysis's table omitted
`GATEGUARD_DISABLED=1`, which is correction 9.

ECC's exempt-glob matcher has a documented gotcha this implementation fixes rather than inherits.
Its unanchored substring regex means `**/tests/**` matches `/repo/tests/x.js` but not the bare
relative `tests/x.js`, which is why ECC's own skill doc tells users to list both forms. EDM tests
each glob against both the absolute path and the repository-relative path, so one entry covers both.

The `jq`-missing case needs care because two true statements about it contradict each other when
either is read alone. On the gated path a missing `jq` is a setup error and exits 1. With the marker
absent it is not a setup error at all -- the script exits 0 having never referenced `jq`, which is
`EDMV4-07`'s zero-`jq` allow-path guarantee.

### Acceptance Criteria

- [ ] AC1: `EDM_GATEGUARD` set to any of `0`, `false`, `off`, `disabled` or `disable` exits 0 before
      anything else runs. `bin/tests/wave8-smoke.sh` asserts each of the five spellings separately.
- [ ] AC2: `EDM_GATEGUARD_DISABLED=1` independently exits 0 before anything else runs, recognising
      the literal `1` only. A smoke test asserts `EDM_GATEGUARD_DISABLED=true` and
      `EDM_GATEGUARD_DISABLED=yes` do **not** disable the gate.
- [ ] AC3: With either kill switch engaged the script performs zero filesystem reads beyond its own
      environment -- no marker `stat`, no session-state read. A smoke test points
      `EDM_GATEGUARD_STATE_DIR` and the data-directory chain at a path whose parent has mode `000`
      and asserts exit 0 with empty stderr, proving no read was attempted.
- [ ] AC4: `EDM_GATEGUARD_EXEMPT_GLOBS` is a comma-separated glob list. Each entry is tested with
      bash `case` pattern matching against both the absolute path and the repository-relative path.
      A smoke test sets a single `**/tests/**` entry and asserts both `/repo/tests/x.js` and the
      bare `tests/x.js` are exempted -- the explicit fix for the ECC gotcha.
- [ ] AC5: The shipped default `EDM_GATEGUARD_EXEMPT_GLOBS` covers the `SRD/` artifact tree ("who
      imports this markdown file" carries no signal), common test trees, and generated output. A
      smoke test asserts an edit to a path under `SRD/` is exempt with no variable set.
- [ ] AC6: Session state lives at `${data}/run/<project-key>.checked`, is capped at 500 entries with
      the oldest pruned first, and is treated as empty and truncated when its mtime is older than 30
      minutes. Smoke tests assert a 501st append leaves exactly 500 lines with the oldest gone, and
      that a state file backdated past 30 minutes produces a denial (not an allow) on a path it
      previously recorded.
- [ ] AC7: Every state-write failure path allows, with a stderr warning naming
      `EDM_GATEGUARD_STATE_DIR`. A smoke test makes the data directory read-only and asserts exit 0
      plus the warning, never a deny.
- [ ] AC8: `EDM_GATEGUARD_MAX_DENIALS` (default 3) bounds full denials per session. Past the budget
      the gate emits a stderr advisory and allows. A smoke test drives four unchecked paths in one
      session and asserts denials on the first three and an allow with the advisory on the fourth.
- [ ] AC9: `jq` missing exits 1 (setup error, non-blocking) per the CA-298 convention, never 2 --
      but only on the gated path. With the marker absent, `jq` missing exits 0 having never been
      referenced. The two cases are asserted by separate smoke tests, and the distinction is stated
      in the script's `# EDM-HELP-BEGIN` block.
- [ ] AC10: An unparseable stdin payload exits 1 with a stderr diagnostic and never blocks. A smoke
      test pipes `not json` and asserts exit 1 with empty stdout.
- [ ] AC11: A marker present whose named initiative directory no longer exists (branch switch,
      `git clean`) allows. A smoke test writes a marker naming a deleted directory and asserts
      exit 0.
- [ ] AC12: Every environment variable introduced by this epic (`EDM_GATEGUARD`,
      `EDM_GATEGUARD_DISABLED`, `EDM_GATEGUARD_DENY_MODE`, `EDM_GATEGUARD_EXEMPT_GLOBS`,
      `EDM_GATEGUARD_STATE_DIR`, `EDM_GATEGUARD_MAX_DENIALS`) is documented in
      `plugins/edm/CLAUDE.md` in the same bullet form as the existing `EDM_RUN_ALL_*` and
      `EDM_EVAL_*` knob families, each stating its default and its unset-equals-prior-behaviour
      property.

### Technical Notes

- **`**` is not a recursive glob in a bash `case`.** Normalise `**` to `*` before matching, as AD3's
  data-flow step 5 specifies. This works because `*` in a `case` pattern does match `/`, unlike a
  filename glob -- so `*/tests/*` matches `/repo/tests/x.js`. The relative form `tests/x.js` has no
  leading segment, so the matcher must also test the pattern with a leading `*/` stripped, or it
  will fail exactly the case AC4 exists to prove.
- **Bash 3.2 (C1)**: split the comma list with `IFS=,` plus `set -- $globs` (or a `while read -d ,`
  loop), never `mapfile`. The checked-path set is a file, not an associative array; membership is
  `grep -Fxq`. No `${var^^}` -- lowercase the kill-switch values with `tr` only if the kill-switch
  path is allowed to spawn a process, which AC3 says it is not, so compare against the five literals
  in a `case` instead.
- **mtime comparison is the portability trap.** `stat -c %Y` (GNU) and `stat -f %m` (BSD/macOS) are
  mutually exclusive, so try one and fall back to the other. `find "$f" -mmin +30` is portable
  across both but introduces `find`, which `EDMV4-07` AC7 excludes from the allowed binary set;
  `stat` with a two-format fallback is the compliant route.
- **Env-name divergence from upstream is deliberate.** ECC uses `GATEGUARD_DISABLED` and
  `ECC_GATEGUARD` (`gateguard-fact-force.js:732-734`, with the five disable spellings at line 49).
  EDM namespaces both as `EDM_GATEGUARD_DISABLED` and `EDM_GATEGUARD`, so an operator who exports
  upstream's unprefixed names is not covered. Say so in the help block -- AC2 inherits the
  literal-`1` contract, not the variable name.
- **Verified ECC citations.** Line 36 is `SESSION_TIMEOUT_MS = 30 * 60 * 1000`; line 40 is
  `MAX_CHECKED_ENTRIES = 500`; `:806-819` is `pruneCheckedEntries`; `:732-734` is the
  `GATEGUARD_DISABLED === '1'` arm. All four hold in the clone at `/Users/darryl.porter/projects/ECC`.
  The remaining SRD citations `:117-134` (the glob gotcha), `:1176-1181` (fail-open) and `:904-912`
  (the denial budget) were not line-verified here -- check them before restating them as anchors.
- **The denial budget is per session, and the session is the state file.** Record the counter in the
  same `${data}/run/<project-key>.checked` surface (or a sibling keyed the same way) so AC8's budget
  expires on the same 30-minute idle rule as AC6 and cannot outlive the wave it was meant to bound.

### Out of Scope

The fact-list content (`EDMV4-T14`), the deny transport (`EDMV4-T13`), the marker's lifecycle inside
`edm-state` (`EDMV4-T12`), destructive-`Bash` command inspection (descoped by D15), hookify rule
evaluation and its `block` escalation (scope item 5.3), and the `timing.sh --gateguard` latency
fixture.

---

## EDMV4-T16: Record ECC and GateGuard provenance in the house-style attribution section

| Field | Value |
|---|---|
| Epic | GateGuard |
| Phase | 2 |
| Priority | Should Have |
| Size | XS |
| SRD Refs | EDMV4-12 |
| Depends On | EDMV4-T10 |
| Target Components | `plugins/edm/CLAUDE.md Sec."Prompt conventions (house style)"`, `plugins/edm/bin/tests/wave8-smoke.sh` (new); evidence `ECC/LICENSE:1-3`, `scripts/hooks/gateguard-fact-force.js:19-20`, `ECC/skills/gateguard/SKILL.md:5`, `SRD/edm/EDMV4__ecc-integration/decisions.md` (D13) |

### Description

`CLAUDE.md Sec."Prompt conventions (house style)"` is this plugin's established form for recording
borrowed material: source, URL, licence, and the means of verification, with a clean-room note
stating what was actually adopted. Both licences are permissive and verified -- ECC is MIT (Affaan
Mustafa, 2026) and `zunoworks/gateguard` is MIT (Hirokazu Seto / ZUNO WORKS K.K., 2026), per
decisions.md D13.

Under AD1 as ratified at Gate 2 (D14, 2026-09-02), what carries over is the concept -- deny first
touch, demand facts, allow on retry -- which is pattern-level adoption matching the posture already
recorded for `caveman` and `ponytail`, not verbatim reuse. This entry is therefore house convention
rather than strict licence compulsion, which is why it is Should Have.

The strict MIT NOTICE obligation is dormant, and the trigger that revives it is an AD1 reversal to
vendoring **by any route** -- not the outcome of any single gate question. The obligation binds on
verbatim reuse, and only vendoring produces verbatim reuse. Wiring it to the destructive-`Bash`
descope would have been wrong in a way that creates real exposure: rejecting that descope yields a
larger bash rewrite, not a vendoring, so it could never wake anything.

### Acceptance Criteria

- [ ] AC1: `plugins/edm/CLAUDE.md Sec."Prompt conventions (house style)"` gains an entry for **ECC**
      (`everything-claude-code`, `github.com/affaan-m/everything-claude-code`, MIT) naming the
      copyright holder as recorded at `ECC/LICENSE:1-3` ("MIT License / Copyright (c) 2026 Affaan
      Mustafa"), the local clone inspected, and the clone revision.
- [ ] AC2: The same section gains an entry for **GateGuard** (`github.com/zunoworks/gateguard`, MIT,
      "Copyright (c) 2026 Hirokazu Seto / ZUNO WORKS K.K.") noting that ECC vendored a JavaScript
      port -- evidenced by `scripts/hooks/gateguard-fact-force.js:19-20`, which points at
      `pip install gateguard-ai` and `https://github.com/zunoworks/gateguard`, and by
      `ECC/skills/gateguard/SKILL.md:5` marking `origin: community` -- and that upstream is Python.
- [ ] AC3: Both entries carry a clean-room note in the existing form, stating that the adoption is
      mechanism-level (deny first touch, demand facts, allow on retry) and that no text was copied
      from either source.
- [ ] AC4: Each entry states its means of verification explicitly, in the form the `caveman` and
      `ponytail` entries use ("verified <date> by direct inspection of <what>"); a URL alone does
      not satisfy this AC.
- [ ] AC5: The section's existing enumeration is updated so the prose and the list agree: the
      sentence currently reading "**Four sources, with licence and location, matching the
      enumeration this subsection uses**" names six, and the bullet list below it has six entries.
- [ ] AC6: `bin/tests/wave8-smoke.sh` asserts both the strings `zunoworks` and `MIT` appear within
      that section of `plugins/edm/CLAUDE.md`, so a later edit cannot silently drop the attribution.
- [ ] AC7: The dormant clause is stated once, here: if AD1 is reversed to vendoring by any route
      (`EDMV4-59` rejected at Gate 2, or any later decision directing vendoring), this requirement
      is re-raised to Must Have and three things bind -- the vendored files retain their original
      copyright headers unmodified, a new `plugins/edm/NOTICE` names ZUNO WORKS K.K. and Affaan
      Mustafa with their MIT texts, and `EDMV4-56`'s required-binary set is re-presented at the gate
      as an explicit dependency addition. D14 ratified the rewrite, so the clause ships dormant.

### Technical Notes

- **Date and means discrepancy, unresolved in the source.** `EDMV4-12`'s own ACs say both licences
  were "verified 2026-08-30", and describe the GateGuard verification as direct inspection of "its
  `LICENSE`". decisions.md D13 is dated **2026-08-31** and records that verification as direct
  inspection of `https://raw.githubusercontent.com/zunoworks/gateguard/main/LICENSE` -- a fetched
  URL, not a local clone. Record what D13 actually supports; do not copy "2026-08-30 by direct
  inspection of its LICENSE" for the GateGuard entry without re-verifying, because AC4's whole point
  is that the means is accurate.
- **Verified in this repository's environment.** `/Users/darryl.porter/projects/ECC/LICENSE` exists
  and lines 1-3 read "MIT License" / blank / "Copyright (c) 2026 Affaan Mustafa".
  `ECC/skills/gateguard/SKILL.md` carries `metadata:` at line 4 and `origin: community` at line 5.
  `gateguard-fact-force.js:19-20` read "Full package with config support: pip install gateguard-ai"
  and "Repo: https://github.com/zunoworks/gateguard" -- direct evidence for AC2's Python-upstream
  claim. The SRD's bare `gateguard-fact-force.js` omits its directory; the file is at
  `scripts/hooks/gateguard-fact-force.js`.
- **The clone revision `19e2f2b4` was not re-verified.** Confirm with
  `git -C /Users/darryl.porter/projects/ECC rev-parse --short HEAD` before writing it into AC1's
  entry; a wrong revision is worse than none, since the whole entry exists to be re-checkable.
- **Nothing automatic lints this file.** Per `CLAUDE.md Sec."Artifact content conventions"`, no
  `edm-lint-artifacts` invocation the git-commit hook makes ever reaches `plugins/edm/CLAUDE.md`, so
  the ASCII rule on the new entries is enforced only by AC6's smoke assertion and by hand. Write
  `--` and `->`, never an em dash or arrow.
- **AC5 depends on the exact prose string.** Re-grep for "Four sources" before editing -- if an
  earlier ticket already changed that count, update to the true new total rather than to six.

### Out of Scope

Creating `plugins/edm/NOTICE` (dormant unless AD1 is reversed), amending `decisions.md` D13 or
`architecture.md` AD1 to record the Gate 2 outcome (owned by `EDMV4-T10`), re-presenting the
required-binary set at a gate (`EDMV4-56`), and any change to the `caveman`, `ponytail`, `opus-5` or
`sonnet-5` entries beyond the enumeration count in AC5.
