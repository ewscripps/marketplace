# Epic E11 -- Cross-cutting delivery

**Waves**: A (4 tickets), B (1 ticket), C (2 tickets)
**SRD requirements**: EDMV3-86 .. EDMV3-111 (26 -- explicit non-goals 86-90, security and integrity
91-95, observability 96-100, performance and cost 101-104, cross-cutting constraints 105-111)
**Tickets**: EDMV3-T61 .. EDMV3-T67 (7)

**This is a delivery grouping, not an eleventh workstream.** The SRD's Section 14.2 places these
requirements outside the ten workstream epics. They still need owners, so they are collected here
rather than smeared across the ten workstream files where they would be invisible to a reader sizing
a wave.

The five explicit non-goals (EDMV3-86 .. EDMV3-90) carry no implementation ticket by construction --
they are recorded scope boundaries. Their dispositions are in the README coverage map, and the
negative checks that keep them true live on the tickets that could otherwise violate them
(EDMV3-T09, T11, T12, T30, T33, T38).

All commands are run from the repository root unless stated otherwise.

---

## EDMV3-T61: Script safety, bash 3.2 and macOS portability, and complete `--help`

| Field | Value |
|---|---|
| Epic | E11 -- Cross-cutting delivery |
| Wave | A |
| Priority | Must Have |
| Size | L |
| SRD Refs | EDMV3-91, EDMV3-96, EDMV3-105, EDMV3-106 |
| Depends On | EDMV3-T09, EDMV3-T21 |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/edm-state` (header block `:2-39`, `usage` at `:2017-2019`, dispatch `:1980-2023`, all new subcommands), `plugins/edm/bin/edm-lint-artifacts` (header `:2-22`, `usage()` at `:30-33`, the PCRE-detection-and-fallback pattern at `:49-53`), `plugins/edm/bin/edm-check-grants`, `plugins/edm/bin/edm-check-vocabulary`, `plugins/edm/bin/tests/*`, `.gitlab-ci.yml`, `plugins/edm/README.md`, `plugins/edm/CLAUDE.md` |

### Description

Four cross-cutting constraints that all land as CI guards over `bin/`, batched because they are one
job family and one header-block change.

`edm-state --help` prints `sed -n '2,39p' "$0"` over the header comment block, and the header block
currently ends at line 39. Any new subcommand documented on line 40 or beyond silently vanishes from
help -- and four are being added. The same hazard is already live in `edm-lint-artifacts`, whose
`usage()` prints `sed -n '2,19p'` while its header block runs to line 22, so three header lines are
truncated today before this initiative adds anything.

The three new subcommands and two new check scripts take user-supplied prefixes and paths, so the
existing script's discipline must extend to them rather than being re-derived per function. And
macOS ships bash 3.2, which is already called out in the codebase (`bin/edm-init:170` carries a
heredoc workaround comment explaining a bash 3.2 limitation).

**Size justification (L).** Round-1 ticket audit resized this from M. Four cross-cutting
requirements land here, and each brings CI infrastructure rather than a code edit: a sentinel
refactor of the header-and-`usage` mechanism in **two** scripts, a bidirectional help-versus-dispatch
test that must parse both a `case` statement and a comment block, a pinned `shellcheck` job, a
prohibited-construct grep job, a **pinned bash 3.2 runner image**, and a **macOS runner** added to a
Linux-only fleet. Three of those (AC8, AC10, AC12) carry a named-exception path that has to be
investigated and recorded before it can be taken, which is investigation work, not implementation
work. Decomposition was considered and rejected: splitting the runner matrix into its own ticket
leaves the bash 3.2 grep asserting a constraint nothing executes, and splitting the sentinel refactor
from the bidirectional test leaves the test parsing a hardcoded range it is meant to replace.

### Acceptance Criteria

- [ ] AC1 (positive, sentinels replace hardcoded ranges): the `edm-state` header block is delimited
      by sentinel comment lines and `usage` extracts between the sentinels rather than between
      hardcoded line numbers. The same change is applied to `edm-lint-artifacts` `usage()` at
      `:30-33`, and **it restores the currently-truncated lines 20-22**.
      Verify: `edm-state --help | tail -5` shows the last documented subcommand, and
      `bash plugins/edm/bin/edm-lint-artifacts --help | wc -l` is three lines longer than before the
      change.
- [ ] AC2 (negative, bidirectional help completeness): every subcommand present in the dispatch
      `case` appears in the help block, and every help entry corresponds to a real subcommand. A test
      asserts both directions and fails naming the mismatch.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "help and dispatch agree in both
      directions"), and adding a dispatch entry without a help line makes it fail naming the
      subcommand.
- [ ] AC3 (every subcommand that exists **at this ticket's wave boundary** is in help, including the
      new flags): at wave-A close, every subcommand present in the dispatch `case` appears in the
      help block with a usage line matching the existing style. That set includes `migrate-schema`
      (EDMV3-T10, wave A) and the new read-only `list --paths` flag (EDMV3-T20 AC6), which is
      documented as an **explicit item on the `list` help line** rather than as an undocumented
      option on an already-documented subcommand -- otherwise AC2's bidirectional test sees `list`
      and stops.
      Verify: `edm-state --help | grep -q migrate-schema`, `edm-state --help | grep -q -- 'list .*--paths'`,
      and `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "help and dispatch agree in both
      directions") green at wave-A close.
      **The four-subcommand enumeration is a wave-C assertion and lives on EDMV3-T66 AC3.**
      `render-ledger` and `audit-converged` land in wave B and `audit-round-complete` in wave C, so
      asserting all four here would be an AC a wave-A ticket cannot satisfy -- under D15 that is a
      specification defect, not an aspiration. What this ticket delivers is the mechanism that
      catches each of them automatically as it lands; what EDMV3-T66 AC3 verifies is that it did.
- [ ] AC4 (help output is ASCII): the help output remains ASCII-only.
      Verify: `edm-state --help | LC_ALL=C grep -n '[^\x00-\x7F]'` returns nothing.
- [ ] AC5 (positive, argument validation -- **for every subcommand and script that exists at this
      ticket's wave boundary**): each validates its argument count and exits with a `usage:` message
      on mismatch, matching the existing convention, and `set -euo pipefail` is present in every new
      script. At wave A that set is `migrate-schema` and `bin/edm-check-grants`. The guard is
      generic rather than a hardcoded subcommand list, so it covers `render-ledger` and
      `audit-converged` in wave B and `audit-round-complete` in wave C as they land -- each of those
      requirements carries its own instance of this AC (srd.md v1.2.0 CR4's wave split for
      EDMV3-91).
      Verify: at wave-A close, `edm-state migrate-schema 2>&1 | grep -q '^usage:'` succeeds, and
      `head -5 plugins/edm/bin/edm-check-grants | grep -c 'set -euo pipefail'` returns 1. The
      generic guard is asserted by `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "every dispatch
      entry emits a usage: line on zero arguments"), which iterates the dispatch table rather than a
      list, so a subcommand added in a later wave is covered without editing the test.
- [ ] AC6 (negative, prefix cannot traverse): a prefix argument is validated against the character
      class the plugin already enforces (`^[A-Z][A-Z0-9_-]*$`) before it is used in any path
      construction, so a prefix cannot traverse directories.
      Verify: `edm-state audit-converged '../../etc'; echo "exit=$?"` prints a validation error and a
      non-zero exit, asserted by
      `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "path-traversal prefix refused").
- [ ] AC7 (negative, no eval, no string-built subshells, no unbound jq): no new code passes
      user-supplied strings to `eval`, to a subshell built by string concatenation, or to `jq`
      outside `--arg` and `--argjson` bindings. Paths written by new code are constructed from
      `initiative_dir_for` output rather than from raw user input.
      Verify: `grep -n 'eval ' plugins/edm/bin/edm-state plugins/edm/bin/edm-check-*` returns zero
      results, and `grep -n 'jq ' plugins/edm/bin/edm-state | grep -v -- '--arg' | grep -c '\$'`
      returns 0 for new code paths (reviewed line by line and recorded in the ticket).
- [ ] AC8 (shellcheck job with a named exception): a **pinned `shellcheck` job** in the CI lint stage
      reports no unquoted-expansion findings in new code. If `shellcheck` is unavailable in the
      runner fleet, the ticket records why and a documented manual review pass covers the same
      ground.
      Verify: `grep -n 'shellcheck' .gitlab-ci.yml` shows the pinned job, or the ticket records the
      named exception and the manual pass.
- [ ] AC9 (negative, bash 4 constructs banned and grepped): no new or modified bash uses associative
      arrays (`declare -A`), `mapfile`/`readarray`, `{fd}` redirection, `${var^^}`/`${var,,}` case
      conversion, or negative array indices. A CI check greps for the prohibited constructs and fails
      naming the file and line. Where a bash 4 idiom would be natural, the bash 3.2 workaround
      carries a comment naming the constraint.
      Verify: `grep -rnE 'declare -A|mapfile|readarray|\$\{[a-zA-Z_]+\^\^\}|\$\{[a-zA-Z_]+,,\}|\{fd\}' plugins/edm/bin/`
      returns zero results, and the CI job fails when one is introduced.
- [ ] AC10 (bash 3.2 image, with a named exception): `bash -n` passes over every file in
      `plugins/edm/bin/` including `bin/tests/*.sh`, run in CI, and **the CI test stage runs the
      suites under a pinned bash 3.2 image in addition to the default runner bash**, so the
      constraint is enforced rather than asserted. If a bash 3.2 image is unavailable in the runner
      fleet, the ticket records why and the AC9 grep becomes the sole guard.
      Verify: `grep -n 'bash:3.2' .gitlab-ci.yml` shows the pinned image, or the ticket records the
      exception.
- [ ] AC11 (macOS/Linux divergence points checked): new scripts use only utilities available on both
      userlands, or detect and branch. `sed -i`, `date` format strings, `grep -P`, `find` and `stat`
      are the known divergence points and each use is checked. Where `grep -P` is used, the existing
      PCRE-detection-and-fallback pattern at `bin/edm-lint-artifacts:49-53` is followed.
      Verify: `grep -rn "sed -i\|grep -P\|stat -c\|stat -f" plugins/edm/bin/` -- every hit is either
      inside a detection branch or listed in the ticket with its portability justification.
- [ ] AC12 (macOS runner, with a named exception): CI exercises the suites on a macOS runner in
      addition to Linux. Where a macOS runner is unavailable, the ticket records why, the divergence
      points named in AC11 are covered by targeted assertions, and the gap is documented in
      `CLAUDE.md`.
      Verify: `grep -n 'macos' .gitlab-ci.yml`, or the ticket records the exception and
      `grep -n 'macOS runner' plugins/edm/CLAUDE.md` documents the gap.
- [ ] AC13 (CI): the help-completeness test runs in CI.
      Verify: `grep -n 'run-all.sh' .gitlab-ci.yml`.

### Technical Notes

- **Resolved in srd.md v1.2.0 (CR4), no longer an open ambiguity.** EDMV3-96 and EDMV3-91 both
  carried dependency sets spanning all three waves -- a wave-A requirement depending on wave-B and
  wave-C subcommands. Both now carry an explicit `Wave split` block in the same shape EDMV3-11,
  -17, -22 and -113 already use: **wave A lands the mechanism** (sentinels, the bidirectional test,
  the argument-validation guard, the CI jobs) and **each later wave's subcommand carries its own
  help and usage AC** in its own requirement. That is why AC3 and AC5 here are scoped to the wave-A
  boundary and the four-subcommand enumeration sits on EDMV3-T66 AC3. Holding the help fix until
  wave C would let the drift ship twice before it was fixed.
- **AC-band note.** 13 acceptance criteria against the 6-12 band. Four cross-cutting requirements
  are batched here because they are one CI job family and one header-block change; three of the ACs
  (AC8, AC10, AC12) are the same default-plus-named-exception shape applied to three different
  runner-fleet questions. Recorded in the README sizing section.
- AC8, AC10 and AC12 all use the same default-plus-named-exception shape rather than "where
  practical", which would make the criterion unfalsifiable. If the exception is taken, the ticket
  must say why and what covers the gap instead.
- EDMV3-T43 explicitly does **not** widen `edm-lint-artifacts`' `usage()` range. This ticket owns that
  line; two requirements editing it in incompatible directions was the hazard the SRD called out.

### Out of Scope

- The `shellcheck` findings themselves in pre-existing code. The job covers **new** code; a
  pre-existing finding is recorded and given its own ticket.
- Windows or WSL support. Recorded scope boundary (EDMV3-87).
- Adding new subcommands. This ticket makes help complete; the subcommands come from T10, T26, T28
  and T51.

---

## EDMV3-T62: Every exemption leaves an audit trail

| Field | Value |
|---|---|
| Epic | E11 -- Cross-cutting delivery |
| Wave | A |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV3-94 |
| Depends On | EDMV3-T05, EDMV3-T06, EDMV3-T11, EDMV3-T14 |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/edm-state:1475-1488` (`cmd_skip_phase`, the `rationale="${3:-}"` default), `:419` (`state_anomalies`), `:1243` (`cmd_validate`), `:1700` (`write_handoff_internal`), `plugins/edm/CHANGELOG.md` |

### Description

D13(c) removes override flags, leaving `skipped_phases` and legacy degradation as the only ways a
check does not apply. Each must be visible in the committed record, or the enforcement kernel becomes
unauditable in exactly the cases that matter.

RK-9 accepts knowingly that removing every override flag makes a legitimate exception expensive,
pushing users toward hand-editing state. This ticket is what makes those cases visible rather than
silent: hand-edits stay visible in `git diff` and in `validate`, a deleted state file raises
`MISSING_STATE_FILE`, and every sanctioned exemption carries a rationale.

### Acceptance Criteria

- [ ] AC1 (positive, rationale required): every `skipped_phases` entry records the phase number, a
      non-empty rationale string, and a timestamp.
      Verify: `edm-state skip-phase TESTX 2 "mini-srd fuses planning and SRD" && edm-state get TESTX | jq -e '.skipped_phases[0] | has("phase") and (.rationale | length > 0) and has("skipped_at")'`.
      The timestamp key is **`skipped_at`**, which is what `cmd_skip_phase` writes today
      (`bin/edm-state:1483`: `+ [{phase: ($p|tonumber), rationale: $r, skipped_at: $ts}]`, verified
      2026-07-25). The earlier verification asserted `recorded_at`, a key the code has never
      written, so the command failed against correct code. This ticket does **not** rename the
      field: a C-4 rename would break every existing state file carrying a skip record for no gain.
- [ ] AC2 (negative, empty rationale refused -- a breaking change): a skip recorded with an empty
      rationale is refused. This is a breaking change to an existing command --
      `cmd_skip_phase` takes `rationale="${3:-}"` and accepts empty today -- so it is called out in
      `CHANGELOG.md`.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "skip-phase with an empty rationale
      is refused" plus `check_state_unchanged`), and
      `grep -n 'skip-phase refusing an empty rationale' plugins/edm/CHANGELOG.md`.
- [ ] AC3 (C-4, pre-existing empty rationales are read and surfaced): pre-existing entries with
      `rationale: ""` are read without error and surfaced as an anomaly in the canonical four-field
      format `info  EMPTY_SKIP_RATIONALE  skipped_phases  <description>` (EDMV3-T05 AC2), the
      description naming the phase and the initiative, so C-4 holds and the gap is visible rather
      than either crashing or hiding. The `info` class is what keeps `validate` at exit 0.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "legacy empty rationale reads and
      reports an informational anomaly"), asserting the four-field line, its `info` first field, and
      `validate` exiting 0.
- [ ] AC4 (seeded entries satisfy the same rule): entries seeded automatically from a mode's phase
      graph (EDMV3-T07) carry a rationale naming the mode, so the automatic path satisfies the same
      rule as the manual one.
      Verify: `edm-init --product demo --description seed --mode mini-srd TESTM` then
      `edm-state get TESTM | jq -e '[.skipped_phases[].rationale | length > 0] | all'`.
- [ ] AC5 (legacy degradation is recoverable from state, not just console): every legacy
      warn-and-proceed path prints a `[warn] legacy initiative` line naming the skipped check, and
      the fact that a check was skipped is recoverable from the state file, not only from transient
      console output.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "skipped-check record persists in
      state"), asserting `jq -e '.degraded_checks | length > 0'` after a legacy run.
- [ ] AC6 (HANDOFF renders exemptions): `HANDOFF.md` renders skipped phases and their rationales.
      Verify: `edm-state write-handoff TESTM && grep -n 'Skipped phases' <init-dir>/HANDOFF.md`
      shows the phase and rationale.
- [ ] AC7 (validate reports every active exemption, informationally): `edm-state validate` reports
      every active exemption as an anomaly in the canonical four-field format
      `info  ACTIVE_EXEMPTION  <field>  <description>` (EDMV3-T05 AC2), so a reviewer reading a
      completed initiative can see which invariants were not enforced without a healthy initiative
      exiting non-zero. One line per exemption; the `info` class is declared at the emit site.
      Verify: `edm-state validate TESTM; echo "exit=$?"` prints one four-field `info` line per
      active exemption and `exit=0`.
- [ ] AC8 (preserve, prototype warning): the `prototype` mode exemption on archive continues to print
      its warning.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "prototype archive warning text
      preserved").
- [ ] AC9 (every approval carries its tag): every approval carries its enforcement tag (EDMV3-T06),
      so a reviewer can distinguish a permission-enforced approval from a prose-only one.
      Verify: `edm-state get TESTX | jq -e '[.gates_approved[] | has("enforcement")] | all'`.
- [ ] AC10 (negative, no unrecorded exemption path exists): recorded `skipped_phases` entries and the
      three-valued legacy degradation are the **only** ways a check does not apply. No flag, no
      environment variable, and no mode shortcut bypasses a check without a state record.
      Verify: `grep -rn 'EDM_SKIP\|EDM_FORCE\|SKIP_CHECKS' plugins/edm/bin/` returns zero results,
      and `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "no unrecorded exemption path").

### Technical Notes

- AC5's `degraded_checks` field is additive and must use the `// default` idiom so legacy reads never
  produce nulls (EDMV3-107).
- AC2 is a genuine breaking change for anyone scripting `edm-state skip-phase` with two arguments.
  The `CHANGELOG.md` entry is not optional and belongs in the wave-A entry (EDMV3-T64).
- The informational classification in AC3 and AC7 depends entirely on EDMV3-T05. Without it, a
  healthy initiative with one recorded skip would start exiting 3 on `validate`.

### Out of Scope

- Adding new exemption categories. RK-9's recorded response to hand-edits appearing in the first real
  initiative after wave A is a new *recorded* exemption, decided then -- never a force flag.
- The `MISSING_STATE_FILE` anomaly -- EDMV3-T12.
- The D15 AC-granularity question -- EDMV3-T33. A recorded-exemption category at AC granularity would
  be an override flag with a state field instead of a command-line argument, and is explicitly
  rejected.

---

## EDMV3-T63: Artifact content lint compliance and the ASCII import policy

| Field | Value |
|---|---|
| Epic | E11 -- Cross-cutting delivery |
| Wave | A |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV3-95, EDMV3-110 |
| Depends On | EDMV3-T20 |
| Ships-with | -- |
| Target Components | `SRD/edm/EDMV3__prompt-streamline/EDM-REVIEW.md` (78 non-ASCII lines), `plugins/edm/bin/edm-lint-artifacts` (class 1 attribution trailers, class 2 non-ASCII at `:163-183`), `plugins/edm/hooks/hooks.json:86` (the `PreToolUse` commit hook and its staged-prefix derivation), `plugins/edm/CLAUDE.md` (import policy), `plugins/edm/skills/verify-runtime/SKILL.md` (template, wave B), `plugins/edm/bin/edm-state` (`render-ledger` output, wave B) |

### Description

The commit-time lint already enforces three classes -- AI-attribution trailers, non-ASCII bytes and
leaked tool tags -- over artifact `.md` files. Everything this initiative generates or templates must
satisfy it.

The urgent part is not a template. `EDM-REVIEW.md`, imported into this initiative's own directory,
carries 78 non-ASCII lines (em dashes and arrows). `bin/edm-lint-artifacts` class 2 flags non-ASCII
outside code fences, and the `PreToolUse` commit hook derives the prefix from staged `SRD/` paths and
blocks the commit -- so **every commit staging an EDMV3 artifact already fails today**, and the
`--all` exit-0 criterion is unsatisfiable until this is fixed.

Wrapping the file in ignore markers is rejected: an exempted document in the initiative's own
directory is a standing invitation to exempt the next one.

### Acceptance Criteria

- [ ] AC1 (positive, the blocking fix): `EDM-REVIEW.md` is ASCII-normalized -- em dashes become `--`,
      arrows become `->` -- with the document's meaning unchanged.
      Verify: `LC_ALL=C grep -n '[^\x00-\x7F]' SRD/edm/EDMV3__prompt-streamline/EDM-REVIEW.md`
      returns nothing.
- [ ] AC2 (negative, ignore markers are not the answer): `EDM-REVIEW.md` is **not** wrapped in
      `edm-lint-ignore` markers.
      Verify: `grep -c 'edm-lint-ignore' SRD/edm/EDMV3__prompt-streamline/EDM-REVIEW.md` returns 0.
- [ ] AC3 (the policy is stated, not just the fix): imported third-party documents are
      ASCII-normalized on import, recorded once in `plugins/edm/CLAUDE.md` alongside the ASCII-only
      convention, so the next imported review does not reintroduce the same block.
      Verify: `grep -n 'ASCII-normalized on import' plugins/edm/CLAUDE.md`.
- [ ] AC4 (positive, the whole tree lints clean): `edm-lint-artifacts --all` exits 0 over the
      repository's tracked artifact trees, **including this initiative's own directory**.
      Verify: `bash plugins/edm/bin/edm-lint-artifacts --all; echo "exit=$?"` prints `exit=0`.
- [ ] AC5 (negative, the commit hook stops blocking): a commit staging an EDMV3 artifact succeeds.
      Verify: `git add SRD/edm/EDMV3__prompt-streamline/srd.md && git commit -m ':memo: test' --dry-run`
      passes the `PreToolUse` lint hook rather than being blocked.
- [ ] AC7 (templates specify ASCII): every prompt template added or edited by this initiative that
      produces artifact text specifies ASCII-only output.
      Verify: `grep -rc 'ASCII-only' plugins/edm/skills/ plugins/edm/agents/` shows a hit in each
      file that templates artifact text, listed in the ticket.
<!-- edm-lint-ignore-start -->
- [ ] AC8 (negative, no attribution trailer in any commit): no commit message produced during this
      initiative contains `Co-Authored-By`, `Generated-By`, `Generated with Claude` or any equivalent
      trailer.
      Verify: `git log --format='%B' <wave-A-base>..HEAD | grep -ci 'co-authored-by\|generated-by\|generated with'`
      returns 0.
<!-- edm-lint-ignore-end -->
- [ ] AC9 (negative, gitmoji shortcodes only): gitmoji appear as shortcodes (`:sparkles:`, `:bug:`)
      and never as Unicode glyphs, in commit messages and in artifact text alike.
      Verify: `git log --format='%s' <wave-A-base>..HEAD | LC_ALL=C grep -n '[^\x00-\x7F]'` returns
      nothing.
- [ ] AC10 (git conventions during execution): git commands are run as separate parallel calls rather
      than chained with `&&`, and files are staged by explicit name rather than with `git add -A` or
      `git add .`.
      Verify: recorded as a working convention in the ticket, and
      `git log --format='%B' <wave-A-base>..HEAD | grep -c 'git add -A'` returns 0.

### Technical Notes

- AC1 is the highest-priority item in this ticket and arguably in wave A's supporting work: until it
  lands, committing any EDMV3 artifact requires bypassing the plugin's own hook, which is a bad
  precedent to set inside the initiative that is hardening the hooks.
- 78 lines is a mechanical `sed` pass for em dashes and arrows, but read the diff -- a few may be
  inside code fences where class 2 already permits them, and normalizing those changes quoted source
  text.
- Depends on EDMV3-T20 for `--all`, without which AC4 cannot be expressed.
- **The former AC6 has moved to EDMV3-T65 AC13.** It asserted that `render-ledger` output and the
  `post-deploy/verification.md` template pass all four lint classes -- both wave-B artifacts, and
  the fourth class does not exist until wave B either. A wave-A ticket cannot close on it. This is
  the pack-wide convention the round-1 ticket audit adopted: **a wave-N ticket's acceptance criteria
  are all verifiable at wave-N close, and a later-wave clause moves to that wave's closeout ticket
  as a named row.** EDMV3-T64 AC9 was already the model; this is the same treatment applied to the
  three remaining instances.

### Out of Scope

- The Mermaid lint class -- EDMV3-T43 (wave B).
- Wave-B generated artifacts (`render-ledger` output, the `post-deploy/verification.md` template)
  and their four-class lint check -- EDMV3-T65 AC13, which also carries `EDMV3-95 (wave-B
  artifacts)` in its SRD Refs so the requirement is owned in the wave it is checkable in.
- Normalizing any document outside this initiative's directory and the plugin tree.

---

## EDMV3-T64: Wave A closeout -- version 2.1.0, changelog, preserve-untouched verification

| Field | Value |
|---|---|
| Epic | E11 -- Cross-cutting delivery |
| Wave | A |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV3-92, EDMV3-98 (wave A), EDMV3-111 (wave A) |
| Depends On | EDMV3-T16, EDMV3-T21, EDMV3-T23 |
| Ships-with | -- |
| Target Components | `plugins/edm/.claude-plugin/plugin.json` (version), `.claude-plugin/marketplace.json:35` (the `edm` entry version), `plugins/edm/CHANGELOG.md`, `plugins/edm/bin/edm-state:125-192` (state-derived path resolution), `:291-396` (locking and atomicity), `:674-686` and `:691-751` (artifact-hash drift), `plugins/edm/agents/edm-qc-auditor.md:26-48`, `plugins/edm/skills/orchestrator/SKILL.md:395-402`, `plugins/edm/bin/edm-lint-artifacts` |

### Description

The wave-A gate. Three cross-cutting requirements converge at every wave boundary: the version and
changelog must be correct (EDMV3-98), the locking and atomicity discipline must have been preserved by
every new write path (EDMV3-92), and the eight-item preserve-untouched list must be verified
explicitly rather than assumed (EDMV3-111).

SRD Section 11.3 says EDMV3-111 is best expressed as one verification ticket per wave rather than a
single ticket at the end. This is the wave-A instance; EDMV3-T65 and EDMV3-T66 are B and C.

RK-15 is the risk this ticket exists to close: ten epics across three waves touch nearly every file,
and something on the preserve-untouched list breaks quietly.

### Acceptance Criteria

- [ ] AC1 (version): `plugins/edm/.claude-plugin/plugin.json` version is `2.1.0`, and
      `.claude-plugin/marketplace.json`'s `edm` entry matches. A test asserts the two agree.
      Verify: `jq -r '.version' plugins/edm/.claude-plugin/plugin.json` prints `2.1.0` and
      `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "plugin.json and marketplace.json versions
      agree").
- [ ] AC2 (changelog entry): `plugins/edm/CHANGELOG.md` gains a wave-A entry listing the behavioural
      changes, the breaking changes and the required user action -- naming the permission-rule setup
      as required (EDMV3-08).
      Verify: `grep -n '2.1.0' plugins/edm/CHANGELOG.md` returns the entry with all three sections.
- [ ] AC3 (named behaviour changes, all of wave A's): the changelog names each behaviour change
      explicitly -- the `product_name` coupling removed from `cmd_archive`, `skip-phase` refusing an
      empty rationale, and `prototype` mode waiving only the convergence check.
      Verify: `grep -c 'product_name\|empty rationale\|prototype mode waives' plugins/edm/CHANGELOG.md`
      returns 3.
- [ ] AC4 (compatibility stated, exceptions called out): the changelog states which changes are
      backward compatible for existing state files and which are not. Per EDMV3-107 the answer should
      be "all backward compatible", and any exception is called out explicitly.
      Verify: `grep -n 'backward compatible' plugins/edm/CHANGELOG.md`.
- [ ] AC5 (baseline warning count recorded): the v2.0.0 `claude plugin validate` baseline warning
      count is recorded in `CHANGELOG.md`, so "no new warnings" is measurable in waves B and C.
      Verify: `grep -n 'validate baseline: .* warning' plugins/edm/CHANGELOG.md`.
- [ ] AC6 (EDMV3-92, positive): every new state mutation in wave A uses `rmw_state`. No new code
      reads a state file, modifies it and writes it back outside the lock.
      Verify: `grep -n 'jq .*> .*\.edm-state.json' plugins/edm/bin/edm-state | grep -v rmw_state`
      returns zero results, and the four wave-A mutation sites (`cmd_approve_gate`'s code-audit
      branch, `cmd_phase_complete`'s new checks, `cmd_archive`'s new checks, `cmd_migrate_schema`)
      each call `rmw_state`.
- [ ] AC7 (EDMV3-92, negative): read-only new commands take no lock and mutate nothing.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "read-only commands leave the state
      byte-identical"), using `check_state_unchanged` on `validate`, `get`, `gate-check` and
      `list --paths`.
- [ ] AC8 (EDMV3-92, concurrency): a concurrency smoke test runs two `edm-state` mutations against the
      same prefix and asserts the resulting file is valid JSON containing both mutations.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "two concurrent mutations both
      land").
- [ ] AC9 (EDMV3-111, eight items walked explicitly): a checklist verifies each of the eight
      preserve-untouched items and records the evidence, rather than assuming preservation because
      nothing obviously broke -- state-derived path resolution, locking and atomicity,
      artifact-hash drift detection, QC verdict semantics, the gate approval rules text, stable
      CA-NNN IDs and demote-don't-delete, the lint infrastructure, and HANDOFF auto-refresh with the
      `## Notes` section.
      Verify: the ticket's QC evidence contains one row per item with a command and its output. For
      wave A the applicable subset is items 1, 2, 3, 7 and 8; items 4, 5 and 6 are verified at
      wave-B close and the row records "not yet touched".
- [ ] AC10 (EDMV3-111, the three existing lint classes are unchanged; method corrected per
      G48/CA-324, same class CHANGELOG.md already ruled out for T67 AC8): the three existing
      `edm-lint-artifacts` classes behave identically, and the staged-prefix derivation in the commit
      hook is unchanged.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "T67 AC8") asserts the staged-prefix
      derivation's shipped content directly rather than an empty diff stat (which goes green
      after any commit regardless of content); the three-class output on a fixed corpus is
      byte-identical pre- and post-change across wave A.
- [ ] AC11 (wave exit criteria met; the baseline half is blocked on the D23-documented gap,
      G47/CA-323, same relabeling `epics/03-ci-and-fixture-eval.md` T23 AC13 already applied
      per decisions.md D36): the three-command bypass fails at command 2 and again at command 3
      on gate, phase and `completed_at` grounds; all smoke suites are green in CI including the
      flat-layout, `fast-track` and `mini-srd` cases. The fourth original clause -- "`evals/
      baseline/scores.json` is committed" -- is not verifiable today: `decisions.md` D23 records
      that the wave-A baseline has not yet been captured (`plugins/edm/evals/baseline/` holds
      only `README.md`), so a non-empty-file test against it cannot run in a clean checkout
      until D23's documented closing command is executed. This is not silently passed and not
      faked, per D15.
      Verify: `bash plugins/edm/bin/tests/run-all.sh; echo "exit=$?"` prints `exit=0` and the CI
      default-branch pipeline is green today; the baseline-commit half is verified by running
      D23's closing command and then confirming `test -s plugins/edm/evals/baseline/scores.json`.
<!-- edm-lint-ignore-start -->
- [ ] AC12 (no gitmoji or attribution violations in the wave): the wave's commits satisfy EDMV3-T63
      AC8 and AC9.
      Verify: `git log --format='%B' <wave-A-base>..HEAD | grep -ci 'co-authored-by'` returns 0.
<!-- edm-lint-ignore-end -->

### Technical Notes

- AC9's wave-A subset matters: items 4 (QC verdict semantics), 5 (gate approval rules text) and 6
  (CA-NNN IDs) are not touched until wave B, so recording them as "verified" in wave A would be
  false. Record them as "not yet touched" with the command that will verify them later.
- AC5 is small and easy to skip, and skipping it makes EDMV3-T60 AC1 unmeasurable in wave C. Do it.

### Out of Scope

- Waves B and C -- EDMV3-T65 and EDMV3-T66.
- The performance budgets -- EDMV3-T67.

---

## EDMV3-T65: Wave B closeout -- version 3.0.0, downgrade path, and CI failure messaging

| Field | Value |
|---|---|
| Epic | E11 -- Cross-cutting delivery |
| Wave | B |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV3-92, EDMV3-95 (wave-B artifacts), EDMV3-98 (wave B), EDMV3-100, EDMV3-111 (wave B) |
| Depends On | EDMV3-T18, EDMV3-T30, EDMV3-T33, EDMV3-T38, EDMV3-T43 |
| Ships-with | -- |
| Target Components | `plugins/edm/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json:35-49`, `plugins/edm/CHANGELOG.md`, `plugins/edm/bin/tests/wave6-smoke.sh` (the downgrade case), all new `plugins/edm/bin/` check scripts, `.gitlab-ci.yml`, `plugins/edm/bin/tests/run-all.sh`, the eight preserve-untouched anchors |

### Description

The wave-B gate, plus the CI failure-message contract, which lands here because every new check script
it binds exists by the end of wave B.

Wave B is a major version bump because the dispatcher restructure is a behavioural change for anyone
who invoked phase skills directly and relied on the local approval path. It also introduces four new
state shapes, which makes the **downgrade** path a real question -- and forward compatibility is the
easy half.

### Acceptance Criteria

- [ ] AC1 (version): `plugin.json` version is `3.0.0` and `marketplace.json`'s `edm` entry matches,
      and the manifest's `skills` list includes `verify-runtime`.
      Verify: `jq -r '.version' plugins/edm/.claude-plugin/plugin.json` prints `3.0.0`, and
      `jq -e '.plugins[]|select(.name=="edm")|.skills|index("skills/verify-runtime/SKILL.md")' .claude-plugin/marketplace.json`
      is non-null.
- [ ] AC2 (changelog states the major change plainly): the wave-B entry states plainly that the
      orchestrator restructure is a major behavioural change and names the permission-rule setup as
      required.
      Verify: `grep -n '3.0.0' -A20 plugins/edm/CHANGELOG.md` shows both statements.
- [ ] AC3 (named behaviour changes, wave B's): the changelog names `branch-check` becoming a BLOCK on
      the standalone-skill path and the `current_step` vocabulary change with its published mapping
      from the 2.x values.
      Verify: `grep -c 'branch-check\|current_step' plugins/edm/CHANGELOG.md` returns at least 2.
- [ ] AC4 (downgrade path documented concretely): the entry documents its downgrade path, not only its
      upgrade compatibility. Downgrading to 2.1.0 means the synthesizer writes `findings-ledger.md`
      again while a stale JSONL remains on disk and is still authoritative for anyone on 3.0.0,
      closure records become invisible, and `verify-runtime` disappears while `partial_verdict_map`
      closure entries persist. The entry states plainly what breaks, what to do about each item, and
      that the recorded `schema_version` is the signal a downgraded install should refuse to act on
      rather than ignore.
      Verify: `grep -n 'Downgrade' -A15 plugins/edm/CHANGELOG.md` names all four items.
- [ ] AC5 (negative, the downgrade story is tested): a wave-B smoke case runs a 2.1.0-era
      `edm-state` against a 3.0.0-shaped state file and asserts it reads without error and reports
      the version mismatch.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "2.1.0 edm-state against a
      3.0.0-shaped state file").
- [ ] AC6 (EDMV3-100, message format): every new check script -- `edm-check-grants`,
      `edm-check-vocabulary`, the Mermaid lint class, the allowlist contract test, the four-`##`
      contract test, the help-completeness test -- emits `path:line: <class>: <detail>` on failure,
      and each failure message states the corrective action, not only the violation.
      Verify: force one failure in each and confirm the format and a corrective sentence, recorded in
      the ticket.
- [ ] AC7 (EDMV3-100, negative -- check failure versus infrastructure failure): the CI job summary
      distinguishes them mechanically: exit 1 maps to `CHECK FAILED: <script>: <n> violations` and
      exit 2 maps to `INFRASTRUCTURE: <script>: <detail>`. A test asserts both strings are produced
      for both exit codes.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "job summary strings for exit 1 and
      exit 2").
- [ ] AC8 (EDMV3-100, exit codes consistent across the new family only): 0 clean, 1 violations found,
      2 usage or environment error, across all new `bin/edm-check-*` scripts and the lint class. This
      binds the new check scripts only -- `cmd_validate` keeps returning 3 for blocking anomalies and
      `audit-converged` uses 0/1/3 with 3 meaning "no ledger".
      Verify: `for s in edm-check-grants edm-check-vocabulary; do bash "plugins/edm/bin/$s" --bogus >/dev/null 2>&1; echo "$s=$?"; done`
      prints `=2` for both.
- [ ] AC9 (EDMV3-100, aggregator diagnostics): the smoke aggregator reports which suite failed and how
      many assertions within it.
      Verify: introduce a deliberate failure and confirm
      `bash plugins/edm/bin/tests/run-all.sh` names the suite and the assertion count.
- [ ] AC10 (EDMV3-92, wave-B write paths): every new wave-B state mutation uses `rmw_state`,
      `render-ledger` writes with a temp-file-plus-rename, and read-only new commands
      (`audit-converged`, the two check scripts) take no lock and mutate nothing.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "audit-converged leaves the state
      byte-identical") and `grep -n 'mv .*findings-ledger.md' plugins/edm/bin/edm-state`.
- [ ] AC11 (EDMV3-111, the three items wave B touches): the wave-B checklist verifies QC verdict
      semantics survive verbatim including "Never invent a PASS for something you cannot verify"; the
      gate approval rules text survives verbatim in the canonical PROTOCOL without rewording; and
      stable CA-NNN IDs and demote-don't-delete False Alarm handling survive into the JSONL
      unchanged. The other five items are re-verified.
      Verify: the ticket's QC evidence contains one row per item with a command and its output,
      including `grep -n 'Never invent a PASS' plugins/edm/agents/edm-qc-auditor.md`.
- [ ] AC12 (wave exit criteria met): convergence is computed rather than asserted and a partial round
      cannot compute it; every PARTIAL closes through `/edm:verify-runtime` and `archive` enforces
      it; `edm-check-vocabulary` finds no deferral vocabulary across its full scan scope; and the eval
      total is at or above baseline minus the recorded run-to-run range.
      Verify: `bash plugins/edm/bin/edm-check-vocabulary; echo "exit=$?"` prints `exit=0`, EDMV3-T39's
      comparison job is green, and `bash plugins/edm/bin/tests/run-all.sh` is green.
- [ ] AC13 (EDMV3-95, wave-B generated artifacts pass all four lint classes) -- **moved here from
      EDMV3-T63 AC6**, because both the artifacts and the fourth lint class are wave-B and a wave-A
      ticket cannot close on them: `render-ledger` output is ASCII-only and carries no attribution
      trailer or leaked tool tag, and the `post-deploy/verification.md` template written by
      `/edm:verify-runtime` satisfies **all four** classes including the Mermaid class from
      EDMV3-T43.
      Verify: against the committed synthetic pass directory
      `plugins/edm/bin/tests/fixtures/code-audit/` (EDMV3-T24 AC0), run `edm-state render-ledger`
      and `/edm:verify-runtime` into a scratch initiative, then
      `bash plugins/edm/bin/edm-lint-artifacts --all; echo "exit=$?"` prints `exit=0` with both
      files present, and `LC_ALL=C grep -n '[^\x00-\x7F]' <init-dir>/code-audit/findings-ledger.md <init-dir>/post-deploy/verification.md`
      returns nothing.

### Technical Notes

- AC5 needs a 2.1.0-era `edm-state` binary. Check out the wave-A tag into a temp directory rather than
  vendoring a copy, so the test cannot drift from what actually shipped.
- AC7's job-summary strings make "diagnosable without opening the log" a checkable property rather
  than an aspiration. Emit them from the CI job wrapper, not from the scripts, so the scripts keep a
  single output format.
- AC8 deliberately does not unify the two exit-code families. Stating one table for both would force
  one of them to change an existing contract for symmetry.

### Out of Scope

- Waves A and C -- EDMV3-T64 and EDMV3-T66.
- The performance budgets -- EDMV3-T67.

---

## EDMV3-T66: Wave C closeout -- version 3.1.0 and `CLAUDE.md` reference tables match reality

| Field | Value |
|---|---|
| Epic | E11 -- Cross-cutting delivery |
| Wave | C |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV3-92, EDMV3-97, EDMV3-98 (wave C), EDMV3-111 (wave C) |
| Depends On | EDMV3-T48, EDMV3-T53, EDMV3-T56, EDMV3-T60 |
| Ships-with | -- |
| Target Components | `plugins/edm/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json:35`, `plugins/edm/CHANGELOG.md`, `plugins/edm/CLAUDE.md` (`bin/` table, state-field table, Hooks behavior table, Testing changes, Model and effort assignments, Cost tracking), the eight preserve-untouched anchors |

### Description

The wave-C gate, plus EDMV3-97, which lands here because it can only be true once every wave's changes
exist. `CLAUDE.md` hardcodes "36 subcommands" and enumerates them, describes the linter's violation
classes, documents the state-field schema, and lists the hook behaviours. This initiative changes all
four. A stale reference table is worse than none, because it is cited by name from agent prompts at
runtime.

### Acceptance Criteria

- [ ] AC1 (version and changelog): `plugin.json` version is `3.1.0`, `marketplace.json` matches, and
      `CHANGELOG.md` gains a wave-C entry listing behavioural changes, breaking changes and required
      user action.
      Verify: `jq -r '.version' plugins/edm/.claude-plugin/plugin.json` prints `3.1.0` and
      `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "versions agree").
- [ ] AC2 (the open `schema_version` decision is made and recorded): the SRD leaves wave C's
      `schema_version` value conditional -- `3` only if a state shape actually changes in wave C. The
      decision is made explicitly, recorded in `CHANGELOG.md` and in the `CLAUDE.md` state-field
      table, and if nothing changed the value stays at `2` rather than being bumped for symmetry.
      Verify: `grep -n 'schema_version' plugins/edm/CHANGELOG.md` records the decision and its
      reason, and `edm-state get <fresh-initiative> | jq -r '.schema_version'` matches it.
- [ ] AC3 (subcommand count and membership, **and the four-subcommand help enumeration lands here**):
      the `bin/` table's subcommand count and enumeration match the dispatch table exactly after all
      waves. A test asserts the count and the membership. This AC additionally carries the
      enumeration that EDMV3-T61 AC3 could not satisfy at wave A: **all four** new subcommands --
      `audit-converged` (wave B), `render-ledger` (wave B), `audit-round-complete` (wave C) and
      `migrate-schema` (wave A) -- appear in `--help` with usage lines matching the existing style,
      and `record-task-duration` is absent after EDMV3-T58. Wave C is the first boundary at which
      all four exist, which is why the assertion is here rather than three waves earlier (srd.md
      v1.2.0 CR4's wave split for EDMV3-96). A separate, previously-unenforced claim in the same
      section (CA-242, round 5): the `bin/` table's own **row count** -- one row per shipped
      script, not `edm-state`'s subcommand count -- must match the actual script set on disk, so
      the table (cited by name from agent prompts at runtime) cannot go stale undetected the way
      it did before (round 4 found it stuck at 9 rows describing a set that no longer matched
      disk). A test asserts both: the row count equals the shipped script count, and every shipped
      script has a row.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "CLAUDE.md subcommand count and
      membership match dispatch"), plus
      `for c in audit-converged render-ledger audit-round-complete migrate-schema; do edm-state --help | grep -q -- "$c" || echo "MISSING: $c"; done`
      printing nothing, `edm-state --help | grep -l record-task-duration | wc -l` printing 0, and
      `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "T66 AC3 (G25/CA-242) -- bin/ table row
      count matches shipped bin/ script count") -- which independently derives the shipped count
      via `find plugins/edm/bin -maxdepth 1 -type f -name 'edm-*' ! -name '*.awk' | wc -l` (9 as of
      this round) and the table's row count via a heading-scoped scan of the `bin/` table, rather
      than a second hardcoded literal.
- [ ] AC4 (linter row, hook row, mode row -- the row defers to `--help` instead of hardcoding a
      class count, per decisions.md D41): the `edm-lint-artifacts` row in the `bin/` table no
      longer hardcodes a violation class count or class names -- the linter emits **seven** classes
      by the close of this initiative (`attribution`, `unicode`, `leaked-tool-tag`,
      `mermaid-semicolon`, `unterminated-fence`, `scan-error`, `unreadable`), not the four this AC
      originally named, and a hardcoded count/list drifts every time a class is added (it already
      had, before this AC was ever satisfied). The row instead points readers at
      `edm-lint-artifacts --help` for the authoritative, current class list. The Hooks behavior
      table drops `TaskCompleted`, and the `lifecycle_mode` row drops `partial`.
      Verify: `grep -c 'four violation classes' plugins/edm/CLAUDE.md` prints `0` (the phrase is
      gone, not merely outnumbered); `grep -n 'edm-lint-artifacts --help' plugins/edm/CLAUDE.md`
      shows the bin/ table row deferring to `--help`;
      `bash plugins/edm/bin/edm-lint-artifacts --help 2>&1 | grep -cE '^#   (attribution|unicode|leaked-tool-tag|mermaid-semicolon|unterminated-fence|scan-error|unreadable)( |$)'`
      prints `7` (all seven emitted classes enumerated); and `grep -rl 'TaskCompleted' plugins/edm/CLAUDE.md | wc -l`
      and `grep -rl 'lifecycle_mode.*partial' plugins/edm/CLAUDE.md | wc -l` each print `0`. This
      mirrors `bin/tests/wave7-smoke.sh`'s "G9" test case (cited by name per CA-321/G45 -- a
      line-range citation here had already gone stale) (`check_absent` on "four
      violation classes", `check` on "edm-lint-artifacts --help").
- [ ] AC5 (state-field table complete): the table documents every field added by this initiative --
      `schema_version` with its integer value set and the minimum version each new check requires, the
      approval `enforcement` tag and its sibling `*_approved_at` / `*_approver` keys, the PARTIAL
      closure representation, audit-round completion data, and `round_type`. Each row states its
      type, default and C-4 backward-compatibility behaviour.
      Verify: `grep -c 'schema_version\|enforcement\|round_type\|closing_verdict' plugins/edm/CLAUDE.md`
      returns at least 4, and each row has all three columns populated.
- [ ] AC6 (agent and skill counts asserted against disk): a test asserts the documented agent count
      matches `ls plugins/edm/agents/*.md | wc -l` (30) and the documented skill count matches the
      `skills` array in `.claude-plugin/marketplace.json` (14 after `verify-runtime`), so the counts
      cannot drift the way 26 and 12 did.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "documented agent and skill counts
      match reality").
- [ ] AC7 (remaining table updates): the Testing changes section describes CI as the primary
      verification path with the manual checklist as a local convenience, and the Model and effort
      assignments table reflects lens tiering.
      Verify: `grep -n 'CI is the primary verification path' plugins/edm/CLAUDE.md` and
      `grep -n 'sonnet' plugins/edm/CLAUDE.md` shows the five tiered lenses.
- [ ] AC8 (pricing table matches the code): a test asserts the `CLAUDE.md` pricing table matches the
      script constants.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "pricing table matches script
      constants").
- [ ] AC9 (EDMV3-92, wave-C write paths): `update-patterns`' new insertion path is atomic, and
      `audit-round-complete` routes its mutation through `rmw_state`.
      Verify: `grep -n 'mv .*audit-patterns' plugins/edm/bin/edm-state` and
      `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "audit-round-complete uses rmw_state").
- [ ] AC10 (EDMV3-111, all eight verified with evidence): the wave-C checklist walks all eight
      preserve-untouched items and records the evidence: state-derived path resolution unchanged in
      behaviour with both layouts resolving and no hardcoded path in new code; locking and atomicity
      unchanged and used by every new write path; artifact-hash drift detection unchanged in
      behaviour; QC verdict semantics verbatim; the gate approval rules text verbatim; stable CA-NNN
      IDs and demote-don't-delete surviving; the lint infrastructure extended rather than replaced
      with the three existing classes behaving identically; and HANDOFF auto-refresh with the
      `## Notes` section preserved.
      Verify: the ticket's QC evidence contains eight rows, each with a command and its output.
- [ ] AC11 (wave exit criteria met, plus the two cross-wave flips this wave is responsible for
      closing): prompt conventions are recorded and applied once; Phase 6 cost is non-zero on a real
      run; the pattern library respects its contract and pending entries reach a human; the delete
      list is executed and `claude plugin validate` is clean. **Two checks that landed non-blocking
      in earlier waves are confirmed flipped**, because a non-blocking check with no closing row is
      a control that never arrives: (a) the file-type ban, added `allow_failure: true` by EDMV3-T21
      AC3 and flipped to blocking by EDMV3-T57 AC10, and (b) `bin/edm-check-vocabulary` and the
      four-heading contract check, both added to the CI lint stage by their own tickets rather than
      by EDMV3-T21, are present and blocking.
      Verify: `claude plugin validate plugins/edm/`,
      `bash plugins/edm/bin/tests/run-all.sh; echo "exit=$?"` prints `exit=0`, the Phase 6 cost
      figure from EDMV3-T50 AC7 is recorded, and `grep -n 'allow_failure' .gitlab-ci.yml` returns
      **only** the `claude plugin validate` tier-2 job and the eval job -- the file-type,
      vocabulary and four-heading jobs are all blocking. The full `allow_failure` line list is
      pasted into the ticket.
- [ ] AC12 (Definition of Done spot-check): the SRD Section 3.4 Definition of Done items that are
      mechanically checkable all pass.
      Verify: run the SRD's own checks --
      `grep -rn 'code_audit_converged true' plugins/edm/skills/` returns nothing,
      `wc -l < plugins/edm/skills/orchestrator/SKILL.md` is at most 300,
      `bash plugins/edm/bin/edm-lint-artifacts --all` exits 0, and
      `grep -rn -- '--force\|--accept-partials' plugins/edm/bin plugins/edm/skills plugins/edm/agents | grep -v tests/ | grep -v vocabulary- | grep -v 'refused:'`
      returns nothing. All four outputs are recorded.

### Technical Notes

- **Known SRD ambiguity.** EDMV3-13 AC5 leaves the wave-C `schema_version` value undecided at
  ticket-pack time. AC2 makes the decision an explicit deliverable rather than an omission.
- AC12 is the closest thing this pack has to an initiative-level acceptance test. Run it and paste the
  four outputs; a green run here is the strongest single piece of evidence that EDMV3 did what it
  said.
- The skill count becomes 14 at wave B (`verify-runtime`) and stays 14 in wave C. The agent count
  stays 30 throughout -- zero new agents is an explicit scope statement.

### Out of Scope

- Waves A and B -- EDMV3-T64 and EDMV3-T65.
- Performance measurement -- EDMV3-T67.

---

## EDMV3-T67: Performance and cost budgets are measured and recorded

| Field | Value |
|---|---|
| Epic | E11 -- Cross-cutting delivery |
| Wave | C |
| Priority | Should Have |
| Size | L |
| SRD Refs | EDMV3-101, EDMV3-102, EDMV3-103, EDMV3-104 |
| Depends On | EDMV3-T21, EDMV3-T43, EDMV3-T48, EDMV3-T51 |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/edm-state` (`cmd_get`, `resolve-dir`, `branch-check`, `gate-check`, `cmd_phase_complete`, `cmd_audit_converged`, `cmd_render_ledger`, `check_permission_rules`), `plugins/edm/bin/edm-lint-artifacts`, `plugins/edm/hooks/hooks.json:80-90`, `.gitlab-ci.yml`, `plugins/edm/evals/README.md`, a committed timing script |

### Description

The plugin has no runtime service, so "performance" means developer-loop latency: commands invoked
inside a Claude Code turn, a hook on the commit path, and a CI pipeline gating merges. Three budgets
plus the cost-and-duration record for a code-audit round and an eval run.

**The reference environment is defined by the SRD, not by this ticket**: the pinned CI `test` job
image, running on the default GitLab shared runner class, against a scratch repository of the stated
size. Defining it here would let the environment be chosen to fit the number. Local measurements on a
developer machine are informative and are not the acceptance measurement.

**Size justification (L).** Round-1 ticket audit resized this from M. The ticket's deliverable is
not fourteen readings, it is the harness that produces them: a committed `bin/tests/timing.sh` with
seven measurement modes, a `--generate-fixture` mode that builds a **50-initiative** repository so
the subject is reproducible, a 500-finding ledger generator, and a bounded-token-read cap added to
`get_session_tokens_since`. Those are real code against eight `edm-state` entry points, the linter
and the pipeline, and AC9 requires the harness to be runnable at **each** wave boundary rather than
once at the end. Decomposition was considered and rejected: splitting the script from the
measurements leaves a wave-A ticket delivering a harness with nothing to measure and a wave-C ticket
recording numbers whose provenance is a different ticket's code, which is exactly the
unreproducibility AC14 exists to close. The technical note below already says the script can be
written early and run at each boundary -- that is a scheduling property of one L ticket, not two.

### Acceptance Criteria

- [ ] AC1 (subcommand latency): `edm-state get`, `resolve-dir`, `branch-check` and `gate-check`
      complete in under 250ms at p95 on a repository with 50 initiatives, measured on the reference
      environment.
      Verify: `bash plugins/edm/bin/tests/timing.sh --subcommands` on the CI `test` image prints a
      p95 per subcommand, all under 250, and the output is recorded in the ticket.
- [ ] AC2 (phase-complete and its bounded token read): `phase-complete` completes in under 2s at p95
      excluding token-file reading, and the token-reading step is bounded so a large session directory
      cannot make it unbounded.
      Verify: `bash plugins/edm/bin/tests/timing.sh --phase-complete` records both figures, and the
      bound is visible as a cap in `get_session_tokens_since`.
- [ ] AC3 (ledger commands): `audit-converged` completes in under 500ms at p95 on a ledger of 500
      findings and `render-ledger` in under 1s at p95 on the same ledger.
      Verify: `bash plugins/edm/bin/tests/timing.sh --ledger` against a generated 500-finding fixture,
      both figures recorded.
- [ ] AC4 (permission check overhead): `check_permission_rules()` reads at most three small files and
      adds under 50ms to `session-start`.
      Verify: `bash plugins/edm/bin/tests/timing.sh --session-start` shows the delta with and without
      the check.
- [ ] AC5 (commit-path lint budget): a full lint of a typical initiative directory (30 `.md` files,
      10,000 total lines) completes in under 3s on the reference environment.
      Verify: `bash plugins/edm/bin/tests/timing.sh --lint` against a generated fixture directory.
- [ ] AC6 (negative, the Mermaid class does not blow the budget) **(cross-check, owned by
      EDMV3-T43)**: adding the Mermaid class increases total lint time by no more than 40% relative
      to the three-class baseline, measured pre- and post-change and recorded. Files containing no
      ` ```mermaid ` fence short-circuit the new class without a per-line scan. EDMV3-T43 AC10 takes
      the measurement in wave B; this ticket re-takes it on the reference environment with the
      committed timing script and confirms the ratio holds on the 50-initiative fixture.
      Verify: both figures recorded, ratio at most 1.40, alongside EDMV3-T43 AC10's wave-B figures.
- [ ] AC7 (`--all` is a CI budget, documented as such): `--all` mode over a repository with 50
      initiatives completes in under 60s, documented as a CI budget rather than a commit-path budget.
      Verify: `time bash plugins/edm/bin/edm-lint-artifacts --all` on the 50-initiative fixture,
      recorded, and `grep -n 'CI budget' plugins/edm/CLAUDE.md`.
- [ ] AC8 (commit-hook scoping preserved, method corrected per G48/CA-324 -- CHANGELOG.md
      records that an empty diff stat "goes green after any commit whatever the content" and
      was replaced): the commit hook's existing behaviour of linting only the prefixes derived
      from staged `SRD/` paths is preserved, so commit-path cost stays proportional to what
      changed.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "T67 AC8") -- a tree-state
      assertion naming the shipped content directly: staged-path scoping (`diff --cached
      --name-only`), a derived (not hardcoded) `srd_root`, unresolvable prefixes skipped rather
      than treated as violations, the exit-1-vs-exit-2 blocking semantics, per-prefix invocation
      (never `--all`), and graceful no-op when `edm-lint-artifacts` is unavailable or nothing is
      staged.
- [ ] AC9 (pipeline budget, on a fixed subject): the blocking pipeline (lint, test, validate tier 1)
      completes in under 5 minutes wall clock for **the fixture-repository pipeline run measured at
      each wave boundary** -- a fixed, reproducible subject rather than an undefined "typical" MR.
      Verify: the pipeline duration is recorded at each wave boundary in the ticket, all under 5
      minutes.
- [ ] AC10 (parallelism): stages run in parallel where they have no dependency -- the four lint jobs
      (`bash -n`, `edm-lint-artifacts --all`, `edm-check-grants`, `edm-check-vocabulary`) run
      concurrently and converge on the test stage, rather than chaining.
      Verify: `grep -n 'needs:' .gitlab-ci.yml` shows the four lint jobs with no inter-dependency, and
      the pipeline graph shows them parallel.
- [ ] AC11 (negative, no blocking job depends on network beyond image pull): the eval job and
      `claude plugin validate` tier 2 both reach the Anthropic API and both are outside the blocking
      path, which is why the constraint is scoped to blocking jobs rather than stated unqualified.
      Verify: `grep -n 'allow_failure\|when: manual' .gitlab-ci.yml` shows both outside the blocking
      path, and the blocking jobs' scripts contain no network call.
- [ ] AC12 (round cost measurable and reported): after EDMV3-T50 and EDMV3-T51, the cost of one full
      code-audit round is measurable from state and is reported by `metrics-report`. The tiering
      reduction figure from EDMV3-T48 AC11 is recorded alongside it, with recall loss on any tiered
      lens remaining a hard revert.
      Verify: `edm-state metrics-report <fixture-prefix>` shows the full-round cost, and the ticket
      records the pre- and post-change figures with the percentage delta.
- [ ] AC13 (eval run bounded and documented): one eval run (plan -> srd -> audit against the fixture)
      completes within 30 minutes wall clock and its cost is documented in `evals/README.md` so the
      decision to trigger it is informed.
      Verify: `time bash plugins/edm/evals/run-eval.sh` recorded, and
      `grep -n 'cost per run\|minutes' plugins/edm/evals/README.md`.
- [ ] AC14 (reproducible measurement): all measurements are taken with a committed timing script so
      the numbers are reproducible, and the results are recorded in the ticket.
      Verify: `test -x plugins/edm/bin/tests/timing.sh` and the ticket contains its full output.

### Technical Notes

- The timing script is a deliverable, not a scratch command. Without it, "measured at each wave
  boundary" is unrepeatable and the numbers recorded here are unfalsifiable.
- The 50-initiative fixture is generated, not hand-built. Add a `--generate-fixture` mode to the
  timing script so the subject is reproducible.
- AC12's tiering figure is a measured-and-reported outcome, not a pass/fail threshold. The binding
  constraint in that area is recall (EDMV3-T48 AC5), not cost.
- This ticket lands late in wave C by necessity -- it measures things that only exist by then -- but
  the timing script itself can be written earlier and run at each wave boundary for AC9.
- **AC-band note.** 14 acceptance criteria against the 6-12 band. Four requirements batch here
  because they share one committed harness and one reference environment; each AC is one budget with
  one number, so the count tracks the number of budgets rather than hidden complexity. Recorded in
  the README sizing section.

### Out of Scope

- Optimizing anything that misses a budget. A miss is recorded with its figure and given its own
  ticket; this ticket measures and records.
- The tiering change itself -- EDMV3-T48.
