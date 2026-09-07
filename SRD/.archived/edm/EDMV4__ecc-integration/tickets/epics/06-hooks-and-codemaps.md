# Epic 06: Hooks and Codemaps

This epic delivers the three lowest-risk items Gate 1 kept in EDMV4: item 5.3's rules-as-data layer
(`EDMV4-T42` defines the JSON rule format per D7, `EDMV4-T43` builds the evaluator from nothing,
`EDMV4-T44` pins the two-tier exit contract that keeps `action: block` opt-in, and `EDMV4-T45`
wires the events into their single owners with the `bash` event gated on Spike A), item 5.4's
Stop-hook completion gate (`EDMV4-T46` builds `edm-stop-gate` and adds it as a second entry in the
existing `Stop` block, `EDMV4-T47` fixes the warn-versus-block classification to the class field
`edm-state validate` already emits), and item 5.5's codemap interim (`EDMV4-T48` teaches the first
explorer to write `SRD/.codemap.md`, with no generator built). Every requirement in this epic is
Should Have.


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

## EDMV4-T42: Define the JSON hookify rule format and its rule directory

| Field | Value |
|---|---|
| Epic | Hooks and Codemaps |
| Phase | 4 |
| Priority | Should Have |
| Size | S |
| SRD Refs | EDMV4-40 |
| Depends On | none |
| Target Components | plugins/edm/bin/edm-hookify (new), .claude/edm-hookify/ (new rule directory), plugins/edm/CLAUDE.md (format documentation), plugins/edm/CLAUDE.md Sec."Artifact content conventions" |

### Description

EDM's enforcement is entirely hardcoded bash: `edm-lint-artifacts`, `edm-check-grants`,
`edm-check-vocabulary` and the gate hooks. A team with its own conventions has no way to add
enforcement without editing the plugin and carrying a fork. The rules-as-data layer closes that,
and this ticket is the format half of it -- the schema, the rule directory, the naming convention
and the documented failure modes. `EDMV4-T43` builds the evaluator that consumes it.

**The format is JSON, settled at Gate 1 as D7.** It is jq-native, adds no required binary beyond
the `bash`/`jq`/`git` set `EDMV4-56` pins, and matches how every other structured file in `bin/` is
consumed. There is zero YAML parsing anywhere in `bin/` today, so ECC's YAML-frontmatter format
would need either a from-scratch bash/awk YAML-subset parser or a new required binary, which
constraint C2 forbids. ECC compatibility buys nothing: explorer 04 established by exhaustive search
that ECC has **no evaluator at all** -- the condition/operator engine in its
`hookify-rules/SKILL.md` is documentation with no corresponding code -- so only the format *concept*
was ever reusable and EDM is free to choose a better-fitting shape.

Rule files are source-controlled under the project tree, not gitignored local files. That is a
deliberate divergence from ECC's `.local.md`-plus-gitignore convention and follows this plugin's
"source control IS the feature" principle: a teammate reviews a new enforcement rule in a merge
request the same way they review an SRD.

### Acceptance Criteria

- [ ] AC1: Rule files are JSON and are read with `jq` only. `git grep -n 'yaml\|yml' plugins/edm/bin/`
      returns no new hit from this ticket, no YAML parser is written, and no YAML-capable binary
      joins the required set.
- [ ] AC2: Each rule object carries exactly these keys: `name` (string), `enabled` (boolean),
      `event` (one of the string literals `file`, `stop`, `bash`), `action` (`warn` or `block`,
      defaulting to `warn` when the key is absent), `conditions` (array), and `message` (string).
      An unknown top-level key is a setup error naming the rule file and the key.
- [ ] AC3: Each element of `conditions` carries `field`, `operator` and `pattern`. **All**
      conditions must match for the rule to fire (AND semantics), and the AND semantics are stated
      in one explicit sentence in the format documentation rather than left to be inferred from an
      example.
- [ ] AC4: Exactly six operators are supported: `regex_match`, `contains`, `equals`,
      `not_contains`, `starts_with`, `ends_with`. Any other operator string is a setup error whose
      stderr line names both the rule file path and the offending operator.
- [ ] AC5: `field` values are constrained per event and validated: `file_path`, `new_text`,
      `old_text`, `content` for `event: file`; `command` for `event: bash`. A `field` that does not
      belong to the rule's own `event` is a setup error naming the rule, the event and the field.
      The `stop` event's field set is stated explicitly in the documentation, including the case
      where it is empty.
- [ ] AC6: Rule files are discovered at `.claude/edm-hookify/*.json` relative to the project root
      (resolved the way `check_permission_rules()` already resolves it: `CLAUDE_PROJECT_DIR` when it
      names a directory, else `git rev-parse --show-toplevel`, else `.` -- the CA-448 precedent),
      and the directory is **source-controlled**, never gitignored.
- [ ] AC7: The format is documented once, in `plugins/edm/CLAUDE.md`, including the verb-first
      naming convention (`warn-*`, `block-*`, `require-*`) and a worked example rule file.
- [ ] AC8: The documentation names the three failure modes ECC documents honestly: patterns too
      broad (`log` matches "login" and "dialog"), patterns too specific, and shell/JSON escaping
      traps in `pattern` values. Each gets one concrete example.
- [ ] AC9: A malformed rule file (invalid JSON, missing required key, unknown operator, out-of-event
      field) is a **setup error**: its path is named on stderr, that file alone is skipped, the
      remaining valid rules are still loaded, and the evaluator exits 1. A malformed file never
      blocks and never silently disables the whole rule set.
- [ ] AC10: A fixture rule set under `bin/tests/fixtures/` carries one valid rule per event and one
      instance of each malformed shape in AC9, so `EDMV4-T43`'s smoke tests have inputs that do not
      have to be built inline.

### Technical Notes

- Citation check: `ECC/skills/hookify-rules/SKILL.md:12-64` is the named format source and is
  outside this repository, so it could not be re-verified here. Every in-repo citation this ticket
  rests on was re-verified against the current branch: `collect_md_files` is at
  `bin/edm-lint-artifacts:251-260` (matches the SRD) and its `find` filter is `-name '*.md'`.
- Bash 3.2 floor (C1): no associative arrays for the operator or field tables. Use a
  space-delimited string plus a `case` membership test, the same idiom `ALL_LENS_IDS`
  (`bin/edm-state:1613` region) already uses, with its own length self-check.
- The per-event field constraint is the cheapest guard against the largest class of authoring
  mistake: a `command` field on a `file` rule would otherwise silently never match, which reads
  identically to "my rule is fine and nothing violated it".
- `action` defaulting to `warn` on absence is load-bearing for `EDMV4-T44` and must be a property of
  the format, not of the evaluator, so a rule file read by any future consumer defaults the same
  way.
- Do not put logic in the rule filename. The verb-first convention is documentation for humans; the
  evaluator reads `action` from the file body only.

### Out of Scope

- The evaluator itself, `list`/`eval` subcommands and the single-`jq`-pass cost model
  (`EDMV4-T43`).
- The exit-code contract and `block` opt-in enforcement (`EDMV4-T44`).
- Registering any hook event or wiring any consumer (`EDMV4-T45`).
- Any YAML support, a YAML-to-JSON converter, or an ECC rule-file importer. There is no ECC
  evaluator to stay compatible with, so there is no migration path to build.
- Shipping any default rule files with the plugin. `.claude/edm-hookify/` is a project-owned
  directory; the plugin ships the format and the reader, not the policy.

---

## EDMV4-T43: Build the hookify evaluator from nothing, with one classify pass and N projections

| Field | Value |
|---|---|
| Epic | Hooks and Codemaps |
| Phase | 4 |
| Priority | Should Have |
| Size | M |
| SRD Refs | EDMV4-41 |
| Depends On | EDMV4-T42 |
| Target Components | plugins/edm/bin/edm-hookify (new), plugins/edm/bin/edm-lint-artifacts:303-448 (scan_md_files), :251-260 (collect_md_files), :286-297 (_lint_report_class_hits), plugins/edm/bin/_edm-cli-lib.sh, plugins/edm/CLAUDE.md Sec."bin/ helper scripts" |

### Description

EDM is not porting an existing evaluator and wiring it into a dispatcher -- it is **writing the
evaluator from nothing**. Explorer 04 Sec.7 searched all of ECC's `scripts/`, its `hooks/hooks.json`
and all six operator names, and found the condition-matching engine exists only in
`hookify-rules/SKILL.md` prose and its two translated locale copies. ECC's three `/hookify*`
commands only write, list and toggle rule files; none consumes a rule at tool-call time. There is
nothing to port, which is why this ticket is titled "from nothing" rather than "port".

The cost model is the design constraint. A rules engine with N enabled rules faces the identical
multiplying-cost problem `edm-lint-artifacts` already solved once, and the fix pattern transfers
directly: one classify pass, then N projections against a shared table
(`bin/edm-lint-artifacts:303-448`, with `_lint_report_class_hits` at `:286-297` built specifically
to eliminate a four-times-copy-pasted per-class loop that caused a real CA-008 divergence). This
evaluator can be invoked on every Phase 6 edit, so per-call cost that scales with rule count is not
an optimization question, it is a correctness question for the gate that depends on it.

Regex bounding is a documented **input-size cap**, not a timeout. `timeout(1)` is a GNU coreutils
binary absent from stock macOS, and macOS is this plugin's primary development platform, so
depending on it would either add a required binary outside the `bash`/`jq`/`git` set `EDMV4-56`
pins or silently do nothing exactly where it is most needed.

### Acceptance Criteria

- [ ] AC1: `plugins/edm/bin/edm-hookify` exists and is executable, with two subcommands: `list`
      (enumerate enabled rules, one per line) and `eval <file|bash|stop>` reading a JSON payload on
      stdin.
- [ ] AC2: `eval` reads and evaluates **all** enabled rules for the named event in a single `jq`
      invocation. Per-call cost does not multiply with rule count.
- [ ] AC3: A smoke test in `bin/tests/wave8-smoke.sh` runs `eval` against a 1-rule and a 50-rule
      fixture set and asserts the `jq` process count is **identical** for both (counted by wrapping
      `jq` with a counting shim on `PATH` for the duration of the assertion, not by timing).
- [ ] AC4: `eval` prints one line per matched rule in the exact form `rule_id action message`, with
      single-space separation and the message last so it may contain spaces.
- [ ] AC5: The evaluator honours `enabled: false` and skips those rules entirely -- they are neither
      evaluated nor counted, asserted by a fixture in which a disabled rule would otherwise match.
- [ ] AC6: The payload text a rule is matched against is truncated to a stated byte ceiling before
      evaluation. The ceiling and its rationale are stated in-file, in the `EDM-HELP-BEGIN` block,
      and in `CLAUDE.md`.
- [ ] AC7: `timeout(1)` appears nowhere in `edm-hookify` (`grep -c 'timeout' plugins/edm/bin/edm-hookify`
      counts only prose mentions in the rationale comment). If a future change introduces one, it is
      guarded by `command -v timeout` with a documented no-timeout fallback, and the **fallback**
      path is the one the smoke suite asserts, since that is the path macOS takes.
- [ ] AC8: A smoke test feeds a payload larger than the cap and asserts both that the cap was
      applied (a rule matching only on bytes past the ceiling does not fire) and that the call
      returns within the same order of magnitude as a normal call.
- [ ] AC9: The evaluator never writes to any file. `grep -nE '>[^&]|>>|tee|mktemp' ` over the script
      shows only stdout/stderr redirection, asserted by a smoke test that runs `eval` with the rule
      directory and the plugin tree mounted read-only.
- [ ] AC10: A rule set with zero enabled rules (and an absent `.claude/edm-hookify/` directory)
      exits 0 immediately, spawning no `jq` at all -- asserted by the same counting shim as AC3.
- [ ] AC11: It follows the conventions `EDMV4-36` requires of `edm-repo-readiness`: sources
      `_edm-cli-lib.sh` and calls `print_help "${BASH_SOURCE[0]:-$0}"`, carries
      `EDM-HELP-BEGIN`/`EDM-HELP-END` sentinels, resolves `SCRIPT_DIR`, and uses the shared `die()`.
- [ ] AC12: `plugins/edm/CLAUDE.md Sec."bin/ helper scripts"` gains a row for `edm-hookify` in the
      same two-column form the existing rows use.

### Technical Notes

- Citations re-verified against the current branch: `collect_md_files` at
  `bin/edm-lint-artifacts:251-260`, `_lint_report_class_hits` at `:286` (its documented block starts
  at `:263`), and `scan_md_files` at `:303`. All three match the SRD.
- `_edm-cli-lib.sh` is 32 lines and defines exactly one function, `print_help`, which must be called
  with the caller's own path explicitly -- `BASH_SOURCE[0]` inside the sourced library resolves to
  the library, not the caller. Copying the extractor awk literal instead of sourcing the library is
  banned outside `bin/tests/`.
- The one-classify-pass shape here is: `jq --slurp` the enabled rule set once, project the payload's
  fields into a single object once, then evaluate all conditions inside that one jq program. Do not
  loop rules in bash calling `jq` per rule -- that is precisely the multiplying cost the pattern
  exists to avoid.
- Bash 3.2 (C1): no `mapfile` for reading rule paths; use `while IFS= read -r` over a `find -print0`
  loop, matching `_collect_md_files_into` at `bin/edm-lint-artifacts:453-458`.
- C10 bears on this ticket only insofar as it does not: `edm-check-vocabulary`'s `SCOPE_ROOTS`
  (`bin/edm-check-vocabulary:98-107`) include `${PLUGIN_ROOT}/bin`, so `edm-hookify`'s own source is
  scanned for prohibited vocabulary tokens. It does **not** reach a project's
  `.claude/edm-hookify/`.
- `jq`'s `test()` uses Oniguruma, not POSIX ERE. State that in the format documentation's escaping
  section so a rule author does not assume `grep -E` semantics.

### Out of Scope

- The exit-code contract, `action: block` semantics and consumer translation (`EDMV4-T44`).
- Registering the evaluator against any hook event, and any change to `hooks/hooks.json`
  (`EDMV4-T45`).
- A `timeout`-based or `ulimit`-based execution bound. The cap is on input size, deliberately.
- Any rule-authoring UI, `add`/`toggle` subcommands, or an ECC-style `/hookify` slash command. The
  rule directory is edited with a text editor and reviewed in a merge request.
- Caching parsed rule sets between invocations. A per-edit cache is state, and state on the hook
  path is the cost this design exists to avoid.

---

## EDMV4-T44: Make `action: block` explicit opt-in behind a two-tier exit contract

| Field | Value |
|---|---|
| Epic | Hooks and Codemaps |
| Phase | 4 |
| Priority | Should Have |
| Size | S |
| SRD Refs | EDMV4-42 |
| Depends On | EDMV4-T43, EDMV4-T11, EDMV4-T46 |
| Target Components | plugins/edm/bin/edm-hookify (new), plugins/edm/bin/edm-lint-staged-artifacts:7-10,150-158 (the two-tier precedent), plugins/edm/bin/edm-gateguard (new, the file-event consumer), plugins/edm/bin/edm-stop-gate (new, the stop-event consumer), plugins/edm/CLAUDE.md Sec."Hooks behavior" |

### Description

The source analysis rated 5.3's risk "low, **if** `action: block` requires explicit opt-in per
rule". That conditional is the entire safety argument, so it is a requirement rather than a note in
a design doc. A rules layer that can block by default hands every team member the ability to wedge
every other team member's edits with one committed file.

The exit-code contract must match the violation-versus-setup-error split
`edm-lint-staged-artifacts` already expresses, because a rule that fires and says "block" is a
categorically different event from a rule file that is malformed or unreadable. Conflating them
means one team's typo silently blocks another team's commits -- the failure mode the two-tier split
exists to make impossible. The precedent is verified in the current tree:
`edm-lint-staged-artifacts:7-10` documents exit 2 as the blocking violation and exit 1 as the
non-blocking setup error, and `:150-158` is the loop that implements exactly that translation.

### Acceptance Criteria

- [ ] AC1: `action` defaults to `warn` when the key is absent from a rule object. A rule blocks only
      when it explicitly carries the literal `"action": "block"`. A fixture rule with no `action`
      key and a matching condition produces a warn, asserted by a smoke test.
- [ ] AC2: `edm-hookify eval` exit codes are exactly three: **0** when no rule matched or only
      `warn` rules matched; **1** on a setup error (malformed rule file, unknown operator,
      unreadable rule directory, missing `jq`) which is **never blocking**; **2** when at least one
      `block` rule matched. There is no fourth code.
- [ ] AC3: A `warn` match writes its `rule_id action message` line to **stderr** and leaves the exit
      code at 0, asserted by a smoke test that captures stdout and stderr separately.
- [ ] AC4: `edm-gateguard` translates `edm-hookify` exit 2 into a refusal through its own
      `emit_decision deny` function (AD2), and `edm-stop-gate` translates it into its own exit 2. No
      third refusal mechanism is introduced by either consumer.
- [ ] AC5: Exit 1 from `edm-hookify` never escalates to a block in any consumer. A smoke test places
      a malformed rule file in the rule directory and asserts an `Edit` payload through
      `edm-gateguard` is still allowed **and** a `Stop` through `edm-stop-gate` still exits 0, with
      the malformed file named on stderr in both cases.
- [ ] AC6: A single rule set containing one matching `warn` rule and one matching `block` rule exits
      2 and prints both lines, so a block never suppresses a concurrent warning.
- [ ] AC7: The exit-code contract is documented in `plugins/edm/CLAUDE.md Sec."Hooks behavior"` in
      the same table form the existing rows use, and cross-references
      `edm-lint-staged-artifacts`'s identical split by name.
- [ ] AC8: Rule files are ASCII-only, **and the gap in their automatic coverage is stated as fact in
      `CLAUDE.md Sec."Artifact content conventions"` rather than assumed closed**: nothing reaches
      `.claude/edm-hookify/`. `edm-lint-artifacts` collects only `*.md`
      (`bin/edm-lint-artifacts:251-260`, `-name '*.md'`), so a `.json` rule file is skipped in every
      mode including the manual `--path` sweep; and `edm-check-vocabulary`'s `SCOPE_ROOTS`
      (`bin/edm-check-vocabulary:98-107`) are all `${PLUGIN_ROOT}`-anchored, so a project's rule
      directory is out of its scope entirely. The documentation names both reasons and points at
      `EDMV4-57`.

### Technical Notes

- Both `edm-lint-staged-artifacts` citations re-verified against the current branch and **both
  hold**: `:7-10` is the exit-code contract inside the help sentinel block, and `:150-158` is the
  `if [ "$code" -eq 1 ]` / `elif [ "$code" -eq 2 ]` translation loop. Note the polarity inversion
  there: `edm-lint-artifacts` exit **1** (a real violation) becomes `edm-lint-staged-artifacts` exit
  **2**, and `edm-lint-artifacts` exit **2** (setup error) becomes non-blocking. `edm-hookify` uses
  the outer, hook-facing polarity (2 blocks, 1 does not), so do not copy the inner script's numbers
  by mistake.
- AC8 is a "state the gap" acceptance criterion, not a "close the gap" one. Closing it would mean
  widening `collect_md_files`'s filter, which changes the behaviour of every existing
  `edm-lint-artifacts` invocation and belongs to `EDMV4-57`, not here.
- Exit 1 must be reachable without `jq` having run, since a missing `jq` is itself a setup error.
  Guard with `command -v jq` before the rule-directory read, matching the CA-298 convention that a
  setup condition never blocks.
- C10: any prose this ticket adds to `CLAUDE.md` is scanned by `edm-check-vocabulary`, whose
  prohibited list (`bin/vocabulary-prohibited.txt`) bans `defer`/`deferred`/`deferral` as whole
  words. Describe an unshipped `bash` event as "not shipped in this initiative", never as
  "deferred".

### Out of Scope

- The rule format itself (`EDMV4-T42`) and the evaluator's cost model (`EDMV4-T43`).
- Building `edm-gateguard` or `edm-stop-gate`. This ticket specifies how those two consumers
  translate an exit code; `EDMV4-T07` and `EDMV4-T46` build them.
- Any per-rule or global override that lets a `warn` rule escalate to `block` at run time. The opt-in
  lives in the committed rule file and nowhere else.
- Widening `edm-lint-artifacts`'s file collection to reach non-`.md` files (`EDMV4-57`).

---

## EDMV4-T45: Wire hookify events to their single owners, with `bash` gated on Spike A

| Field | Value |
|---|---|
| Epic | Hooks and Codemaps |
| Phase | 4 |
| Priority | Should Have |
| Size | S |
| SRD Refs | EDMV4-43 |
| Depends On | EDMV4-T43, EDMV4-T06, EDMV4-T11, EDMV4-T44, EDMV4-T46 |
| Target Components | plugins/edm/hooks/hooks.json:80-90 (unmodified), plugins/edm/hooks/hooks.json:91-100, plugins/edm/bin/edm-gateguard (new), plugins/edm/bin/edm-stop-gate (new), plugins/edm/bin/edm-hookify (new), plugins/edm/CLAUDE.md Sec."Hooks behavior" |

### Description

Per AD4, hookify does **not** register its own `PreToolUse` block for file events. `edm-gateguard`
evaluates `file`-event rules in-process after its own decision, and `edm-stop-gate` evaluates
`stop`-event rules. Both surfaces then have exactly one EDM-authored owner, so the unverified
multi-hook-per-event combination question is never asked for either of them.

The one place it cannot be avoided is `bash` rules, which need a `Bash` matcher that overlaps the
existing `git commit` block at `hooks.json:81-89`. Risk R1 is High, and its dangerous outcome is not
that the new block never fires -- it is that the new block **suppresses the commit lint**, silently
disabling the plugin's only proven-working blocking hook. That is why the `bash` event ships only on
a positive Spike A result, and why AD4's fallback (folding `edm-lint-staged-artifacts` into a Bash
dispatcher) is deliberately the contingency and not the plan: the fallback touches the one hook
that demonstrably works today.

The second half of this ticket is a cost guard. A rules layer that evaluates on every edit
regardless of phase would re-introduce exactly the per-edit cost the marker design exists to
eliminate, so `file`-rule evaluation happens only inside Phase 6, on the allow path, reusing the
payload `edm-gateguard` already parsed.

### Acceptance Criteria

- [ ] AC1: `file`-event rules are evaluated by `edm-gateguard` on its **allow** path, inside Phase 6
      only, reusing the payload it already parsed -- no second `jq` invocation to re-read stdin. No
      second `PreToolUse` block is registered for file events.
- [ ] AC2: `stop`-event rules are evaluated by `edm-stop-gate`. No second `Stop` matcher block is
      registered by this ticket.
- [ ] AC3: `bash`-event rules ship **only if** `EDMV4-01`'s recorded decision states that the host
      executes every matching block on one tool call. The ticket's implementer reads that decision
      in `decisions.md` before writing any `Bash` matcher block.
- [ ] AC4: If Spike A shows otherwise, `bash` events are not shipped in this initiative and the
      limitation is stated plainly in the rule-format documentation, so a user writing a
      `"event": "bash"` rule is told in advance that it will not fire. `edm-hookify eval bash` in
      that case exits 1 as a setup error naming the unshipped event, rather than exiting 0 and
      appearing to have evaluated something.
- [ ] AC5: The existing `git commit` matcher block is **byte-identical** after this ticket, asserted
      by a smoke test that pins the exact command string at `hooks.json:82-88`. AD4's fallback --
      folding `edm-lint-staged-artifacts` into a Bash dispatcher -- is recorded as a scope boundary
      in `decisions.md` and is not attempted here.
- [ ] AC6: A smoke test asserts that with hookify present and a `file` rule enabled, an `Edit`
      outside Phase 6 (marker absent) is allowed with **zero** rule evaluation -- asserted by the
      `jq`-counting shim from `EDMV4-T43` AC3 showing zero hookify-attributable `jq` spawns.
- [ ] AC7: A smoke test asserts the inverse: with the Phase 6 marker present and a matching `file`
      rule enabled, the rule is evaluated exactly once per gated edit, not once per condition.
- [ ] AC8: `plugins/edm/CLAUDE.md Sec."Hooks behavior"` documents which events hookify serves
      (`file` via `edm-gateguard`, `stop` via `edm-stop-gate`) and which it does not, naming the
      owner of each surface so the "who blocks this" question has one documented answer.
- [ ] AC9: If a `Bash` matcher block **is** added under AC3, `bash bin/tests/run-all.sh` passes and
      `edm-check-vocabulary` passes: the new block's command string is inside
      `plugins/edm/hooks/hooks.json`, which is one of that checker's eight scope roots
      (`bin/edm-check-vocabulary:98-107`) and is additionally validated as parseable JSON at
      `:121-124`, so a syntax error there is a hard `die`, not a skipped file.

### Technical Notes

- Both `hooks.json` citations re-verified and **exact**: the `PreToolUse` array is lines 80-90 with
  the `git commit` block at 81-89, and the `Stop` array is lines 91-100 with its single block at
  92-99. Unlike the `bin/edm-state` citations elsewhere in this SRD, the `hooks.json` line numbers
  did not drift.
- The AD4 qualifier that matters for the neighbouring `Stop` work: the in-repo two-entries-in-one-
  `hooks`-array precedent at `hooks.json:16-24` is a `command` entry **plus a `prompt` entry**.
  Two `command` entries in one array have **zero** in-repo instances. This ticket does not depend on
  that shape (it adds no entry), but do not cite `:16-24` as covering it -- see `EDMV4-T46`.
- The hook body stays a `command -v ... || exit 0; exec ...` one-liner. Path resolution and event
  dispatch live in the script, per CA-436: a one-line JSON hook body is the wrong place for logic
  and has no place for a shellcheck directive.
- C10: `edm-check-vocabulary` scans `hooks/hooks.json` for prohibited vocabulary tokens **and**
  hard-`die`s on invalid JSON before scanning. Run it locally after any edit to that file rather
  than relying on the commit hook, which does not reach it (`edm-lint-artifacts`'
  `collect_md_files` finds only `*.md`).
- Evaluating `file` rules only on the allow path is deliberate: on a deny, `edm-gateguard` has
  already produced a refusal, and a second refusal reason from a rule would make the retry's success
  condition ambiguous.

### Out of Scope

- Building `edm-gateguard` itself (`EDMV4-T07`) or `edm-stop-gate` itself (`EDMV4-T46`). This ticket
  owns the wiring inside them.
- The `PreToolUse` matcher block for `Edit`/`Write`/`MultiEdit`, which `EDMV4-T07` registers.
- Running Spike A (`EDMV4-T06`). This ticket consumes its recorded decision.
- Folding `edm-lint-staged-artifacts` into a Bash dispatcher under any circumstances. That is AD4's
  contingency and requires its own gate presentation.
- Any change to the five `UserPromptExpansion` blocks or the `SubagentStop` block.

---

## EDMV4-T46: Build `edm-stop-gate` and add it as a second entry in the existing `Stop` block

| Field | Value |
|---|---|
| Epic | Hooks and Codemaps |
| Phase | 4 |
| Priority | Should Have |
| Size | M |
| SRD Refs | EDMV4-44 |
| Depends On | EDMV4-T06, EDMV4-T10 |
| Target Components | plugins/edm/bin/edm-stop-gate (new), plugins/edm/hooks/hooks.json:91-100, plugins/edm/hooks/hooks.json:16-24, plugins/edm/bin/edm-state (cmd_validate, the PREFIX-required die, cmd_active_initiatives, state_anomalies), plugins/edm/CLAUDE.md Sec."Hooks behavior" |

### Description

Today every anomaly in 5.4's scope is enforced no later than `edm-state archive`, at the very end of
an initiative. Surfacing them at `Stop` makes the debt visible the moment it is created rather than
weeks later. EDM already has the query (`edm-state validate`) and already has a `Stop` hook
(`checkpoint-if-active`) to extend, so this is **wiring, not new policy**. Per AD4 the new work is a
**second entry in the existing `Stop` block's `hooks` array**, not a second matcher block.

**The in-repo precedent for that shape is weaker than the design's first draft claimed, and this
ticket does not ship on the assumption.** `hooks.json:16-24` does carry two entries in one `hooks`
array, but they are a `"type": "command"` entry **and a `"type": "prompt"` entry** -- a heterogeneous
pair, re-verified in the current tree. That the host runs a command alongside a prompt says nothing
about whether it runs **two commands**, which is what AD4 proposes. A homogeneous `command` plus
`command` pair has **zero instances anywhere in this repository**. `architecture.md:130` states the
qualifier; the SRD's v1.0.0 dropped it and presented the shape as proven. Spike A (`EDMV4-T06`) must
test two `command` entries specifically, before this ships.

**Prefix resolution is a real gap, not a detail.** `edm-state validate` requires a `<PREFIX>`
argument and `die`s without one. A `Stop` hook receives no arguments and no prefix. The gate resolves
one by calling `edm-state active-initiatives`, which requires no argument -- and must handle the
zero-initiative and multi-initiative cases explicitly, because both are ordinary.

**Noise is the other design constraint.** Printing informational anomalies individually would fire
on essentially every `Stop`, and noise on a gate is how a gate gets disabled.

### Acceptance Criteria

- [ ] AC1: **Prefix resolution.** `edm-stop-gate` resolves which initiative(s) to validate by calling
      `edm-state active-initiatives` (which lists initiatives with `current_phase` in 1-6 and takes
      no argument). It does not re-implement the sweep and does not guess a prefix from the working
      directory. It parses that command's human-readable `  <PREFIX>  phase=N  last_updated=...`
      lines and ignores its `(no active initiatives)` and `(no SRD/ directory)` sentinel lines.
- [ ] AC2: **Multi-initiative rule.** When `active-initiatives` returns more than one, the gate runs
      `validate` for **each** and blocks if **any** returns a blocking-class anomaly, naming the
      specific initiative in the message. A smoke test with two active initiatives, one clean and one
      with a blocking anomaly, asserts exit 2 and that the message names the offending prefix.
- [ ] AC3: When `active-initiatives` returns none, the gate exits **0 silently** -- zero bytes on
      stdout and stderr. A repository with no active initiative has nothing to say at every `Stop`.
- [ ] AC4: **Only blocking-class anomalies reach stderr, plus one informational count line.** The
      gate prints the full text of blocking-class anomalies and suppresses per-anomaly informational
      output, replacing it with a single line of the exact form
      `[EDM] <N> informational anomalies (run: edm-state validate <PREFIX>)`. A smoke test asserts
      the informational-only case produces exactly one line of output, exit 0, and a count matching
      the number of `info`-class lines `validate` emitted. The fixture for that assertion carries
      all four routine anomalies that justify the suppression -- `PERM_RULES_MISSING` (present
      until permission rules are configured), `ACTIVE_EXEMPTION` (one line **per skipped phase**),
      `SIZE_UNKNOWN` and `SCHEMA_VERSION_MISSING` -- and still asserts exactly one output line.
- [ ] AC5: `plugins/edm/bin/edm-stop-gate` exists and owns the whole EDM `Stop` surface: it runs
      `edm-state validate` and honours only `blocking`-class anomalies. **It is validate-only.**
      Hookify `stop`-rule evaluation is NOT in this ticket -- `EDMV4-T45` owns that wiring (its
      AC2), and `EDMV4-T44` owns the exit-2 translation. Keeping the hookify clause here made
      `EDMV4-T44` and this ticket mutually blocking (audit P0-2): T44's AC4/AC5 need this script
      to exist, while this AC needed T44's block semantics.
- [ ] AC6: The existing `Stop` block at `hooks.json:92-99` gains `edm-stop-gate` as a **second
      entry** in its `hooks` array, after `checkpoint-if-active`. No second `Stop` matcher block is
      added, asserted by a smoke test that the `Stop` array still has length 1 and its single block's
      `hooks` array has length 2.
- [ ] AC7: The existing `checkpoint-if-active` entry is **byte-identical** after the change,
      asserted by pinning its exact command string in the smoke suite.
- [ ] AC8: All operator text goes to **stderr**, never stdout, asserted by a smoke test capturing the
      two streams separately. A raw JSON echo to stdout is the documented failure mode for a Stop
      hook.
- [ ] AC9: Exit codes are exactly **0** (continue) and **2** (block). There is no third code. Any
      internal error -- `edm-state` off `PATH`, `jq` missing, no resolvable initiative, `validate`
      itself failing or `die`ing -- exits **0**. Only a genuine `blocking`-class anomaly returns 2.
      A smoke test covers each of those four internal-error paths. (The hookify `block` match is
      the other route to 2, but it arrives via `EDMV4-T44`/`EDMV4-T45` and is asserted there, not
      here -- see AC5.)
- [ ] AC10: `command -v edm-stop-gate >/dev/null 2>&1 || exit 0` guards the hook body, mirroring the
      existing entries' guard form.
- [ ] AC11: `EDMV4-01`'s **two-`command`-entries** experiment confirms both entries execute and that
      the second entry's exit code is honoured, **before this ships**. `hooks.json:16-24` is not
      cited as establishing this. If the experiment shows only the first `command` entry runs, or
      that the second's exit 2 is ignored, a second `Stop` **matcher block** -- the alternative
      `architecture.md` rejected -- is re-presented at a gate rather than shipped on an assumption.
- [ ] AC12: `plugins/edm/CLAUDE.md Sec."Hooks behavior"`'s table gains a row for the new entry, and
      the existing collapsed `Stop` and `PreCompact` row is split, since `Stop` now carries two
      entries while `PreCompact` still carries one -- that collapse no longer holds.

### Technical Notes

- **Citation drift, verified.** Every `bin/edm-state` line number this requirement carries is
  **4 lines high** against the current branch. Re-derived: the `<PREFIX>`-required `die` is at
  `:4033` (SRD says `:4037`); `cmd_validate` spans `:4032-4055` (SRD `:4036-4059`);
  `cmd_active_initiatives` spans `:3896-3912` (SRD `:3900-3916`); `state_anomalies` starts at
  `:1705` (SRD `:1709`). Use the verified numbers; the drift is uniform, so a `grep -n` on the
  function name is the safest anchor. The `hooks.json` citations (`:16-24`, `:91-100`) are exact.
- **`cmd_validate` exits 3, not 1**, on a blocking anomaly (`bin/edm-state:4050`, `return 3`). The
  gate must test for 3 explicitly; treating any non-zero as blocking would turn a `die` (exit 1)
  into a `Stop` block, violating AC9.
- `active-initiatives` output is human-readable, not machine-readable: `printf "  %-12s  phase=%d
  last_updated=%s\n"` at `:3908`, with `  (no active initiatives)` at `:3911` and
  `(no SRD/ directory)` at `:3897`. Parse the first whitespace-delimited field of lines matching
  `phase=`; do not parse by column position, which the `%-12s` padding makes fragile for a
  six-character prefix.
- The anomaly line format is four space-separated fields with the class first
  (`class  NAME  field  message`), so `class="${line%% *}"` is the same extraction `cmd_validate`
  itself uses. Reuse that idiom rather than inventing a parse.
- Bash 3.2 (C1): the per-initiative loop uses a plain `while IFS= read -r` over the command's
  output; no `mapfile`, no associative array keyed by prefix.
- C10: the new entry's command string lands in `hooks/hooks.json`, which `edm-check-vocabulary`
  scans and JSON-validates (`bin/edm-check-vocabulary:98-107`, `:121-124`). Nothing else reaches
  that file automatically -- `edm-lint-artifacts` collects only `*.md`.

### Out of Scope

- The **"phase started with no `completed_at`" anomaly is descoped** and is not implemented. That
  descope (`EDMV4-06`) was **RATIFIED at Gate 2 on 2026-09-02** (decisions.md D16): the anomaly does
  not exist today, a phase legitimately stays started for hours, and a naive presence check would
  block on ordinary long-running work. It is a named scope boundary, not a silent drop.
- The warn-versus-block classification of individual anomalies (`EDMV4-T47`).
- Any new anomaly, any change to `state_anomalies`, and any re-classification of an existing
  anomaly. This gate reads what `validate` already emits.
- Running Spike A (`EDMV4-T06`) and ratifying the Gate 2 descope (`EDMV4-T10`).
- Adding a second `Stop` matcher block. If Spike A forces that shape, it returns to a gate first.
- Touching the `PreCompact` block, which keeps its single `checkpoint-if-active` entry.

---

## EDMV4-T47: Block only on the unambiguous subset, read from the existing class field

| Field | Value |
|---|---|
| Epic | Hooks and Codemaps |
| Phase | 4 |
| Priority | Should Have |
| Size | S |
| SRD Refs | EDMV4-45 |
| Depends On | EDMV4-T46, EDMV4-T10 |
| Target Components | plugins/edm/bin/edm-stop-gate (new), plugins/edm/bin/edm-state (cmd_validate and its blocking-class test, OPEN_PARTIALS, OPEN_AUDIT_ROUND, SPEC_SWEEP_PENDING, archive's own OPEN_PARTIALS check) |

### Description

The discipline that has to travel alongside the Stop-gate pattern is: warn by default, block only on
the subset that is unambiguous. EDM already applies exactly this reasoning to `spec_swept`, where
only the explicit string `no` blocks and an absent field never does.

The classification is not a judgment call here. `cmd_validate` already classifies every anomaly as
`info` or `blocking` at the point each line is emitted, and the Stop gate must honour that existing
classification rather than inventing a second one. Three of the four candidates the source analysis
named are verified to exist, and their current classifications are already correct for Stop-time
use: `OPEN_PARTIALS` already **blocks** at `validate`, so surfacing it at `Stop` is a timing
improvement with no new classification risk; `OPEN_AUDIT_ROUND` and `SPEC_SWEEP_PENDING` are
informational by design, and blocking on either would fire on every `Stop` for the remainder of a
round in which anything is mid-flight.

The design property that makes this safe is the absence of policy in the gate. If the gate contains
no anomaly names, it cannot drift from `edm-state`'s classification, and a future anomaly is
correctly handled the day it is added.

### Acceptance Criteria

- [ ] AC1: `edm-stop-gate` blocks **only** when `edm-state validate` emits at least one line whose
      first whitespace-delimited field is literally `blocking` -- the same condition `cmd_validate`
      uses for its own exit 3.
- [ ] AC2: The `<PREFIX>` each `validate` call needs comes from `edm-state active-initiatives`
      (`EDMV4-T46`), never from a guess, a cwd derivation or a hardcoded value. `cmd_validate` `die`s
      without exactly one argument, so an unresolved prefix produces a clean exit 0 from the gate
      rather than a `die` surfaced at every `Stop`, asserted by a smoke test that runs the gate from
      a directory with no resolvable initiative.
- [ ] AC3: Informational anomalies are **not** printed individually, per `EDMV4-T46` -- only their
      count. This ticket's warn-versus-block classification governs which anomalies *block*; it does
      not license printing every informational line at every `Stop`.
- [ ] AC4: The gate re-classifies no anomaly. `grep -nE 'OPEN_PARTIALS|OPEN_AUDIT_ROUND|SPEC_SWEEP_PENDING|PERM_RULES_MISSING|SIZE_UNKNOWN'`
      over `bin/edm-stop-gate` returns hits **only** inside comments and help text, never inside a
      conditional -- asserted by a smoke test, so the "no allow-list, no deny-list" property is
      machine-checked rather than reviewed once.
- [ ] AC5: `OPEN_PARTIALS` blocks at `Stop`, because it already blocks at `validate` and at
      `archive`. A fixture with an unclosed `partial_verdict_map` entry asserts exit 2.
- [ ] AC6: `OPEN_AUDIT_ROUND` warns and does not block, matching its informational classification
      and the in-code rationale that a round in progress is the normal state for most of an audit's
      duration. A fixture with an open audit round asserts exit 0.
- [ ] AC7: `SPEC_SWEEP_PENDING` warns and does not block, matching its informational classification
      and the in-code rationale that its blocking enforcement already lives at `audit-converged` and
      `approve-gate`. A fixture with a `spec_swept: "no"` fixed finding asserts exit 0.
- [ ] AC8: The "phase started with no `completed_at`" anomaly is **not** implemented. The gate ships
      the three verified anomalies above.
- [ ] AC9: When it blocks, the stderr message names the specific anomaly **and** the initiative, so
      the operator can act without running `validate` themselves. A smoke test asserts both tokens
      appear in the message.
- [ ] AC10: A smoke test asserts a blocking anomaly returns 2 and an informational-only anomaly set
      returns 0, in the same fixture initiative, so the two paths are compared against one state
      file rather than two.
- [ ] AC11: A smoke test asserts that a repository with no active initiative returns 0 and produces
      no output on either stream.

### Technical Notes

- **Citation drift, verified.** As in `EDMV4-T46`, every `bin/edm-state` citation in this
  requirement is **4 lines high** against the current branch. Re-derived anchors: the blocking-class
  test is at `:4044-4051` (SRD says `:4048-4054`) and returns **3**, not 1; `OPEN_PARTIALS` is
  emitted at `:1823-1842` (SRD `:1827-1847`); `OPEN_AUDIT_ROUND` at `:1780-1797` with its
  informational rationale in the comment at `:1783-1786` (SRD `:1784-1801` and `:1786-1789`);
  `SPEC_SWEEP_PENDING` at roughly `:1903-1922` with its rationale comment just above (SRD
  `:1907-1926` and `:1911-1913`); `archive`'s own `OPEN_PARTIALS` refusal is the `die` at `:3256`
  (SRD `:3260`). Anchor on the function or the emitted string, not the number.
- The class field is emitted at the point each anomaly line is written, not inferred by the
  consumer -- that is stated in the comment above `state_anomalies`. This is precisely why the gate
  can be policy-free: `edm-state` already made the call.
- `OPEN_AUDIT_ROUND` fires for `code`, `srd` and `tickets` round types independently
  (`bin/edm-state:1788`, `for oar_type in code srd tickets`), so a fixture must be explicit about
  which type it opens or the count in `EDMV4-T46` AC4's line will not match.
- AC4's grep assertion is the durable form of "contains no per-anomaly logic". A reviewed-once
  property regresses; a machine-checked one does not, which is the same reasoning behind the
  `schema_at_least()` call-site assertions already in `wave7-smoke.sh`.
- C1: no `${var^^}` when normalising the class token. The field is already lowercase as emitted;
  compare it literally.

### Out of Scope

- The gate script's construction, prefix resolution, multi-initiative handling and noise suppression
  (`EDMV4-T46`).
- The "phase started with no `completed_at`" anomaly, **descoped and RATIFIED at Gate 2 on
  2026-09-02** (`EDMV4-06`, decisions.md D16). Written against the descoped 5.4.
- Changing any anomaly's class in `state_anomalies`, adding a new anomaly, or changing
  `cmd_validate`'s exit-3 contract.
- Blocking on `OPEN_AUDIT_ROUND` or `SPEC_SWEEP_PENDING` under any configuration flag. Their
  blocking enforcement already lives at `audit-converged`, `approve-gate` and `archive`.
- Hookify `stop`-rule evaluation and its exit-2 translation (`EDMV4-T44`, `EDMV4-T45`).

---

## EDMV4-T48: Have the first explorer write and refresh `SRD/.codemap.md`

| Field | Value |
|---|---|
| Epic | Hooks and Codemaps |
| Phase | 4 |
| Priority | Should Have |
| Size | XS |
| SRD Refs | EDMV4-46 |
| Depends On | none |
| Target Components | plugins/edm/agents/edm-explorer.md, plugins/edm/CLAUDE.md Sec."Project artifact layout", SRD/.codemap.md (new, project-resident) |

### Description

The idea is sound: a token-lean map of a repository's **current** architecture, so agents read a
compact artifact instead of re-deriving structure by grepping the tree on every initiative. What is
not sound is building a generator for it. ECC's generator emits its two most valuable sections --
Data Flow and External Dependencies -- as literal unconditional template strings
(`generate.ts:225-231`), not computed from anything, so the script is a file inventory with an
architecture-shaped outline around it. Its file-to-area classifier is additionally first-match and
order-dependent, and silently drops files matching no area.

Per Gate 1 / D11, **no generator is built**. The first explorer of an initiative writes a reusable
current-architecture codemap that later initiatives read and refresh. The source document's own
value claim for codemaps is explicitly unmeasured, and this interim is the cheapest way to test that
premise before spending medium-to-large effort on tooling for it.

The current-versus-target distinction is the whole reason the file lives at the `SRD/` root rather
than inside an initiative directory: `architecture.md` is one initiative's **target** architecture
and is initiative-scoped; the codemap is the repository's **current** architecture and is shared.
Two artifacts that both describe "the architecture" will contradict each other unless the
distinction is stated in the instruction itself.

### Acceptance Criteria

- [ ] AC1: `plugins/edm/agents/edm-explorer.md` instructs the first explorer of an initiative to
      write `SRD/.codemap.md` if it does not exist, or refresh it if it does. The instruction sits
      alongside the existing `## Output` section's `explorers/{NN}-{slug}.md` contract and states
      that this is a second permitted write path, so it does not read as a contract violation of
      "writing anywhere else is a contract violation".
- [ ] AC2: The instruction states plainly that a codemap is the **current** architecture and
      `architecture.md` is the **target** architecture, in one sentence, so the two artifacts do not
      duplicate or contradict each other.
- [ ] AC3: `SRD/.codemap.md` lives at the `${user_config.srd_root}` root, not inside any one
      initiative's directory, and the instruction says why: it is shared across initiatives.
- [ ] AC4: On a later initiative, the first explorer **reads** the existing codemap and refreshes it
      rather than rewriting it from scratch, and records what it changed -- a short "Refreshed"
      note naming the sections it touched and the initiative prefix that touched them.
- [ ] AC5: The instruction states that a section with nothing real to say is **omitted**, never
      filled with a placeholder or an instruction to the reader. That is the exact failure ECC's
      generator ships and is named as the reason.
- [ ] AC6: **No generator script is written.** No file under `plugins/edm/bin/` produces, refreshes
      or validates the codemap, and no `edm-state` subcommand is added for it.
- [ ] AC7: The codemap is ASCII-only, **and the gap in its automatic coverage is stated as fact**:
      `edm-lint-artifacts` does not reach `SRD/.codemap.md` through any automatic invocation --
      prefix mode resolves a single initiative directory and `--all` iterates the initiative
      directories `edm-state list --paths` returns, while the git-commit hook runs prefix mode. Only
      the manual `--path` mode reaches the `SRD/` root, and nothing invokes it automatically. The
      codemap is covered by `EDMV4-57`'s **manual** `--path` sweep and by nothing else.
- [ ] AC8: `agents/edm-explorer.md`'s instruction states the ASCII-only requirement **inline** (no
      em dashes, use `->` for arrows, straight quotes, no emoji), since the writing agent cannot
      rely on a lint pass catching a violation before the file is committed.
- [ ] AC9: `plugins/edm/CLAUDE.md Sec."Project artifact layout"` documents `SRD/.codemap.md` as a
      `Should`/`on-demand` slot in the layout tree, with its current-versus-target distinction
      stated in the annotations beneath it.

### Technical Notes

- Verified against the current branch: `SRD/.codemap.md` does not exist yet, and
  `agents/edm-explorer.md` is 75 lines with a single permitted write path stated at `:65`
  ("Writing anywhere else is a contract violation"). AC1 must amend that sentence, not sit beside it
  contradicting it -- an agent reading both would otherwise have to guess.
- `edm-explorer`'s frontmatter already grants `Write` (`:5`) and denies `Edit`/`NotebookEdit`
  (`:10`). A refresh therefore has to be a full `Write` of the merged content, not an in-place edit.
  Say so in the instruction so the agent does not attempt a tool it does not have.
- AC7's claim was re-verified: `collect_md_files` (`bin/edm-lint-artifacts:251-260`) runs
  `find "$dir" -type f -not -path '*/.git/*' -not -path '*/.archived/*' -name '*.md'`, so a `.md`
  file at the `SRD/` root **is** collected once `--path SRD/` names it -- the gap is which directory
  the automatic invocations pass in, not the file filter. That is the opposite of the rule-file gap
  in `EDMV4-T44` AC8, where the `*.md` filter is itself the blocker. Do not conflate the two.
- The leading dot in `.codemap.md` keeps it out of casual directory listings but does **not** hide it
  from `find`, so the `--path` sweep does reach it.
- ECC's `generate.ts` is outside this repository and its line citations (`:36-59`, `:107-137`,
  `:225-231`) could not be re-verified here. They are carried as the recorded rationale for not
  porting, not as facts this ticket depends on.

### Out of Scope

- Any codemap generator, validator, freshness check or `bin/` script (D11). Explicitly rejected, not
  postponed.
- A codemap template file. A template is how placeholder sections get shipped, which AC5 exists to
  prevent.
- Porting ECC's five area patterns or its first-match file classifier.
- Making the codemap a required input to any agent or skill. It is an on-demand artifact that later
  explorers read when it exists.
- Widening `edm-lint-artifacts`' automatic invocations to reach the `SRD/` root (`EDMV4-57` owns the
  manual sweep as a Definition-of-Done step).
