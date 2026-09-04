# Lens L11: Integration Wiring -- EDMV4 ECC Integration, Round 1 (full)

Scope: `git diff main..HEAD -- plugins/edm/` plus the repo-root `.claude-plugin/marketplace.json`.
Method: for every registered hook, every new binary, and every new agent, trace the producer end
and the consumer end by file and line, and flag any break.

Standing caveat that shapes confidence throughout: per `EDMV4-62`, neither `/plugin update` nor
`/reload-plugins` reads the working tree, so none of these hook consumers has ever fired from a
real host event. Every "this is wired" claim in this tree is asserted by a smoke test against file
CONTENT, never observed against a running host. Findings below are therefore graded on the
producer/consumer contract as written, not on observed runtime behaviour.

## Findings (L11: Integration Wiring)

| ID | Type | Component/Endpoint | Break In Chain | File:Line |
|----|------|----------------------|-------------------|-----------|
| L11-002 | Agent never loaded | `edm-audit-silent-failures`, `edm-audit-type-design`, `edm-audit-behavioral-tests` (L12/L13/L14) | An explicit `agents` array REPLACES default `agents/` scanning; the manifest lists 30 of the plugin's 33 agent files, so the three new lens agents are never loaded and no full 14-lens round can converge | .claude-plugin/marketplace.json:82 |
| L11-001 | Event handler never triggered | `PreToolUse` block for `edm-lint-staged-artifacts` | `matcher` is `git commit`, but `PreToolUse` matchers match TOOL NAMES only; no tool is named `git commit`, so the block never fires | plugins/edm/hooks/hooks.json:82 |
| L11-003 | Consumer cannot invoke producer | `skills/plan/SKILL.md` Step 6 -> `bin/edm-repo-readiness` | Step 6 instructs `command -v edm-repo-readiness` then runs it, but the skill's `allowed-tools` grants only `Bash(edm-state *)`, `Bash(edm-init *)`, `Bash(edm-validate-prefix *)` | plugins/edm/skills/plan/SKILL.md:8 |
| L11-004 | Consumer reached before producer; no read path | orchestrator Step 1b.5 design-ambiguity signal -> readiness score | Step 1b.5 runs in Step 1 (Intake); the score is produced in Phase 1, dispatched at Step 2. No file, state key or command is named for the consumer to read the score from | plugins/edm/skills/orchestrator/SKILL.md:123 |
| L11-005 | Registered rule path unreachable in the common case | `file`-event hookify rules -> `edm-gateguard` | `edm-gateguard` bare-`exit 0`s on marker-absent BEFORE the hookify call site, so `file` rules evaluate only during an active Phase 6 in the same project | plugins/edm/bin/edm-gateguard:101 |
| L11-006 | Canonical doc declares a wired path unwired | `CLAUDE.md` "Hookify rule format (canonical)" -> `bin/edm-hookify` | The canonical section still states no evaluator reads the rules and no hook fires because of them; `EDMV4-T43` shipped the evaluator and `EDMV4-T45` wired three consumers in this same initiative | plugins/edm/CLAUDE.md:899 |

### Details

#### Finding L11-002: the three new lens agents are never loaded, because an explicit `agents` array replaces directory auto-discovery

- **What exists**: `plugins/edm/agents/edm-audit-silent-failures.md` (L12),
  `plugins/edm/agents/edm-audit-type-design.md` (L13),
  `plugins/edm/agents/edm-audit-behavioral-tests.md` (L14). Thirty-three agent files ship under
  `plugins/edm/agents/`.
- **What it is wired to**: registration is complete in four of the five surfaces the other eleven
  lenses appear in, and broken in the fifth:
  - `ALL_LENS_IDS="L1 ... L14"` at `plugins/edm/bin/edm-state:1673`, with the count assertion at
    `:1675` and `CONDITIONAL_LENS_IDS="L13"` at `:1685`. PRESENT.
  - The lens table at `plugins/edm/skills/code-audit/SKILL.md:288-290` names all three agents.
    PRESENT.
  - `plugins/edm/CLAUDE.md` addresses them collectively (the audit-lens house contract and the
    agent colour table cover "all 14 `edm-audit-*` lenses"), and `agents/edm-audit-type-design.md:116`
    is cross-referenced by name from the conditional-lens rule. PRESENT.
  - `plugins/edm/.claude-plugin/plugin.json` declares no `agents` key at all, so the plugin-level
    manifest relies on auto-discovery and introduces no inconsistency. NOT APPLICABLE.
  - `.claude-plugin/marketplace.json:52-83` -- the `edm` entry's explicit `agents` array lists
    exactly 30 paths, ending at `./agents/edm-ticket-writer.md` (line 82). The three new lens
    agents are ABSENT. `./agents/edm-audit-wiring.md` (L11) is present at line 65, so this is not
    a blanket omission of lens agents; it is specifically the three added by this initiative.
- **Why this is fatal rather than cosmetic**: per the Claude Code plugins reference, the component
  path fields split into two classes. `skills` **adds to** the default (`skills/` is always
  scanned and listed entries load alongside it) -- which is why the 14-skill list at
  `marketplace.json:36-51` is harmless either way. `agents` **replaces** the default: "when the
  manifest specifies `commands`, the default `commands/` directory is not scanned", and the field
  table reads "Custom agent files (replaces default `agents/`)". To keep directory scanning you
  must list `"./agents/"` itself. This manifest lists 30 individual files and not the directory,
  so `plugins/edm/agents/` is not scanned and the three unlisted files are never loaded.
- **Downstream consequence, and why it blocks closure**: `skills/code-audit/SKILL.md:51` runs all
  14 lenses minus `NA_LENSES` on a full round. Three of the 14 agent types do not exist to the
  host, so at most 11 lens reports can land. Step 8a (`:102-116`) then refuses to proceed, naming
  L12/L13/L14 as missing. If step 8a is bypassed, `edm-state audit-round-complete`'s CA-471
  completeness backstop (`bin/edm-state:5007-5018`) records `round_type=partial` and that
  downgrade is IRREVERSIBLE for that round (`skills/code-audit/SKILL.md:172-182`). A partial round
  is never convergent, `edm-state audit-converged` refuses, `approve-gate ... code-audit` refuses,
  and `edm-state archive` refuses. **No initiative can reach convergence or archive** until this
  is fixed. That includes this initiative's own closure.
- **Why nothing caught it**: the smoke suites assert marketplace.json's `version`
  (`wave7-smoke.sh:1334`, `:9370`; `wave6-smoke.sh:5600`) and its `skills` array LENGTH
  (`wave7-smoke.sh:1519-1525`), but nothing asserts anything about the `agents` array.
  `wave8-smoke.sh:4753-4763` cross-checks the agent FILE count against `ALL_LENS_IDS` -- on disk,
  never against the manifest. `plugins/edm/CHANGELOG.md:31-33` claims "`skills/code-audit/SKILL.md`,
  `README.md`, `plugin.json`, `marketplace.json` ... are updated throughout to read 14 lenses";
  marketplace.json's `description` and `version` were updated, its `agents` array was not.
- **Failure shape**: identical to the `SubagentStop` matcher that named the bare `edm-implementer`
  while agents spawn as `edm:edm-implementer` -- the artifact exists, the registration does not
  name it, and the only symptom is an absent output file.
- **Fix**: at `.claude-plugin/marketplace.json:52-83`, either (a) replace the 30-entry array with
  `"agents": ["./agents/"]` so the directory is scanned and no future agent can be orphaned this
  way again -- strongly preferred, and it makes this class of defect structurally impossible -- or
  (b) add the three missing paths in alphabetical position:
  `"./agents/edm-audit-behavioral-tests.md"` after `edm-audit-wiring.md`'s alphabetical neighbours,
  `"./agents/edm-audit-silent-failures.md"`, `"./agents/edm-audit-type-design.md"`. Either way add
  a smoke assertion that the set of `plugins/edm/agents/*.md` files is covered by the manifest
  (a live-glob-versus-manifest set difference, the shape `wave8-smoke.sh:4753` already uses for
  the file count). Then re-run the round: this round's lens set cannot be trusted to be complete.

#### Finding L11-001: the `git commit` PreToolUse block is registered against an event that is never emitted

- **What exists**: `plugins/edm/hooks/hooks.json:81-89` registers a `PreToolUse` matcher block
  whose `matcher` is the literal string `git commit` and whose command is
  `command -v edm-lint-staged-artifacts >/dev/null 2>&1 || exit 0; edm-lint-staged-artifacts`
  (hooks.json:86). The binary itself exists at `plugins/edm/bin/edm-lint-staged-artifacts` and
  implements the documented 0/1/2 exit contract.
- **What it is wired to**: nothing the host emits. Claude Code's hook reference states that for
  `PreToolUse` the `matcher` field filters on **tool name** (`Bash`, `Edit|Write`, `mcp__.*`).
  Command-string filtering is a separate mechanism -- the per-handler `if` field, which uses
  permission-rule syntax (`"if": "Bash(git *)"`). No tool in the tool set is named `git commit`,
  so this matcher matches no tool call, and the handler is never invoked.
- **What it should call**: this is the plugin's only commit-time artifact gate. `plugins/edm/CLAUDE.md`
  treats it as the enforcement substitute for the CI this repository deliberately does not have,
  and `bin/edm-repo-readiness:412-414` scores `edm-lint-artifacts` cleanliness as 10 of the 60
  rubric points on the assumption that violations are caught at commit time.
- **Corroborating evidence that this was never observed running**: the initiative's own hooks
  explorer records the block as a working precedent by inspection only
  (`SRD/edm/EDMV4__ecc-integration/explorers/02-hooks-runtime.md:41`, `:46`), and Spike A
  (`EDMV4-T06`) tested two blocks both registered with `matcher: "Bash"` -- it never exercised the
  `git commit` matcher. `EDMV4-T06` is recorded PARTIAL and NOT RUNTIME-VERIFIED in
  `SRD/edm/EDMV4__ecc-integration/.edm-state.json:191,196`.
- **Fix**: change hooks.json:82 to `"matcher": "Bash"` and move the command filter onto the
  handler: add `"if": "Bash(git commit*)"` alongside `"type": "command"` at hooks.json:84-87.
  Verify against the same host version D25 records (`2.1.246`). Note this makes two
  `PreToolUse` blocks able to match one `Bash` call (this one and `edm-bash-gate`); D25 already
  records that co-registered blocks all run and that any deny wins regardless of order.

#### Finding L11-003: plan Step 6 invokes a binary its own tool grant does not cover

- **What exists (producer)**: `plugins/edm/bin/edm-repo-readiness` emits, on stdout,
  `Rubric version: ${READINESS_RUBRIC_VERSION}` at `:475` and
  `Overall score: %s / 10` at `:493`.
- **What exists (consumer)**: `plugins/edm/skills/plan/SKILL.md:83-92` Step 6 instructs: run
  `command -v edm-repo-readiness >/dev/null 2>&1`, then run the command and capture stdout, then
  "read the `Rubric version:` and `Overall score:` lines from its stdout". The template at
  `:194-198` renders exactly those two labels. **The two line formats match exactly** -- the
  producer/consumer text contract itself is sound.
- **Where the connection breaks**: `plugins/edm/skills/plan/SKILL.md:8` reads
  `allowed-tools: Read, Write, Edit, Bash(edm-state *), Bash(edm-init *), Bash(edm-validate-prefix *), Glob, Grep, Task, TodoWrite, AskUserQuestion`.
  There is no `Bash(edm-repo-readiness *)` grant and no unscoped `Bash` grant, so neither the
  `command -v` probe nor the run itself is permitted. Step 6's own fallback ("if the command is
  not on PATH ... skip this step entirely") means the failure is SILENT: the section is simply
  never written, and absence is documented as authoritative, so there is no diagnostic.
- **Why nothing caught it**: `bin/edm-check-grants`'s Source 4
  (`scan_skill_tool_usage`, `:486-538`) only detects three missing tool classes --
  `AskUserQuestion`, `Task` and `Skill`. Its comment at `:586-590` states plainly that the
  scoped-`Bash` direction is warning-only and checks grant-without-instruction, never
  instruction-without-grant. `wave8-smoke.sh:3456-3467` asserts the Step 6 PROSE exists; it never
  checks the frontmatter grant.
- **Fix**: add `Bash(edm-repo-readiness *)` to `plugins/edm/skills/plan/SKILL.md:8`. Extend
  `bin/edm-check-grants`'s Source 4 with the instruction-without-grant direction for scoped
  `Bash(<cmd> *)`: for every `edm-*` binary name appearing in a skill body inside a run
  instruction, require a matching scoped grant.

#### Finding L11-004: the size classifier consumes a score that cannot exist yet, by a path that is never named

- **What exists (producer)**: `skills/plan/SKILL.md:83-92` Step 6, which runs during Phase 1 and
  writes the score into `planning.md`'s optional `## Repository Readiness` section (`:191-198`).
- **What exists (consumer)**: `skills/orchestrator/SKILL.md:123`: "When a repository readiness
  score is available (`skills/plan/SKILL.md`'s optional Phase 1 step), this step may consult it
  only as an additional input to the **design-ambiguity** signal."
- **Where the connection breaks -- two independent breaks**:
  1. **Ordering.** Step 1b.5 is part of Step 1 (Intake), headed at
     `skills/orchestrator/SKILL.md:102`. Phase 1 -- the only producer of the score -- is not
     dispatched until Step 2, at `:187` (`invoke /edm:plan <PREFIX> <INITIATIVE>`). For a new
     initiative, `planning.md` does not exist when Step 1b.5 runs. Step 1b.5 is additionally
     "Skipped on resume" (`:104`), which is the only run in which a prior `planning.md` would
     exist, so the two cases are disjoint: whenever the score could exist, the consumer is
     skipped; whenever the consumer runs, the score cannot exist.
  2. **No read path.** Even setting ordering aside, `:123` names no artifact, no state field and
     no command. The score lives only as prose in a `planning.md` section the orchestrator is
     never instructed to read; nothing writes it to `.edm-state.json`; and Step 1b.5 is not
     granted or instructed to run `edm-repo-readiness` itself (the orchestrator's `allowed-tools`
     at `:8` has the same missing scoped grant as L11-003).
- **What it should call**: either (a) Step 1b.5 runs `edm-repo-readiness --json <tmp>` itself,
  with the grant added at `:8`, since the rubric is repository-wide and does not need
  `planning.md`; or (b) the sentence at `:123` is removed and the coupling dropped, leaving Step
  6's `planning.md` section as a human-facing artifact only. Option (a) is the smaller change and
  preserves the ticket's stated intent.
- **Note on scope**: `EDMV4-T41`'s own smoke assertions (`wave8-smoke.sh:3455-3500`) check that
  the sentences exist in both files. They cannot check that a consumer positioned before its
  producer can ever read anything, which is why this survived to here.
- **Fix**: add `Bash(edm-repo-readiness *)` to `skills/orchestrator/SKILL.md:8` and rewrite
  `:123` to name the concrete acquisition step, or delete the coupling sentence. Do not leave it
  as an unresolvable reference.

#### Finding L11-005: `file`-event hookify rules never evaluate outside an active Phase 6

- **What exists (call site)**: `plugins/edm/bin/edm-gateguard:393-406` -- `command -v edm-hookify`,
  project the already-parsed payload into hookify's `file`-event field shape, run
  `edm-hookify eval file`, and translate exit 2 into `emit_decision deny` (`:405`).
- **Where the connection breaks**: that call site sits below two unconditional early exits:
  `:101-103` (`[[ -z "$MARKER_PATH" ]] || ! test -f "$MARKER_PATH"` -> bare `exit 0`) and
  `:112-114` (stale marker whose recorded initiative directory is gone -> bare `exit 0`). The
  Phase-6 marker is written only by `bin/edm-state:2726` (`cmd_phase_start` when phase is 6) and
  `:4615` (session-start reconciliation), and removed at `:2899`, `:3498` and `:5494`. So in any
  repository that is not, right now, inside Phase 6 of an EDM initiative -- the normal state of
  every adopting project most of the time -- a `file`-event rule with `"action": "block"` is read
  by nobody and blocks nothing.
- **Why this is a wiring finding and not a design note**: the two other events have no such
  coupling. `edm-bash-gate:55-74` evaluates `bash` rules on every `Bash` call unconditionally, and
  `edm-stop-gate:158-168` evaluates `stop` rules whenever any initiative is active. A rule author
  reading `CLAUDE.md`'s per-event field table has no way to know that one of the three events is
  silently scoped to Phase 6 while the other two are not; the asymmetry is stated nowhere outside
  `edm-gateguard`'s own control flow.
- **Fix**: preferred -- hoist the hookify block above the marker early-exit and guard it on the
  rule directory existing (`[[ -d "${PROJECT_ROOT}/.claude/edm-hookify" ]]`), so a repo with no
  rules still pays zero subprocesses and a repo with rules gets them enforced. Minimum acceptable
  -- document the scoping at `edm-gateguard:37-38` and in `CLAUDE.md`'s hookify section.

#### Finding L11-006: the canonical hookify section still declares the layer inert after it was wired

- **What exists**: `plugins/edm/CLAUDE.md:899-901`: "It is deliberately format-only -- no
  evaluator reads these files yet, no subcommand consumes them, and no hook fires because of
  them. A later initiative wires an `eval` consumer against this exact schema." And `:925-926`:
  "The plugin ships the format and (in a later initiative) the reader".
- **What it is wired to**: as of this same initiative, three shipped consumers read those files
  and all three can block:
  `bin/edm-gateguard:401` (`edm-hookify eval file`, deny at `:405`),
  `bin/edm-bash-gate:67` (`edm-hookify eval bash`, exit 2 at `:73`),
  `bin/edm-stop-gate:160` (`edm-hookify eval stop`, blocking exit at `:170`).
  The evaluator itself is `bin/edm-hookify` (EDMV4-T43), and `CLAUDE.md:1093-1095` describes its
  two-tier exit contract fewer than 200 lines below the section saying no subcommand consumes the
  rules.
- **Why this is L11 and not only a docs finding**: `CLAUDE.md` is the canonical reference an
  adopting team reads before dropping a rule file into `.claude/edm-hookify/`. A team acting on
  `:899-901` will believe an `"action": "block"` rule is inert and cannot break anything, then
  find that it denies `Edit` calls and refuses `Stop`. The doc and the wiring disagree about
  whether a connection exists, which is the same class of defect as a connection that does not.
- **Fix**: rewrite `plugins/edm/CLAUDE.md:899-901` and `:925-926` to name the three consumers and
  their events, and cross-reference the two-tier exit contract section at `:1093`. State the
  Phase-6 scoping of the `file` event there too (see L11-005).

## Verified-intact chains (traced, no finding)

Recorded so a later round does not re-trace them, and so the negative results are on the record
alongside the positives.

| Chain | Producer | Consumer | Verdict |
|---|---|---|---|
| `SubagentStop` -> `edm-qc-auditor` | `agents/edm-implementer.md:2` declares `name: edm-implementer` | `hooks/hooks.json:135` matcher `edm-implementer\|edm:edm-implementer` | INTACT. `SubagentStop`'s matcher filters on agent type and accepts plugin-scoped names, so both the bare and `edm:`-prefixed spawn forms are covered. The prior defect (bare name only) is fixed. |
| `detect-conditional-lenses` -> code-audit Step 1 | `bin/edm-state:1757-1778` prints a CSV of N/A conditional lenses (nothing at all when empty), always exit 0; dispatched at `:6806` | `skills/code-audit/SKILL.md:41` records it as `NA_LENSES`; `:73` passes it as `--na-lenses` | INTACT. The subcommand's `[<PREFIX>]` is accepted-but-unread by design (`:1743-1747`) and the call site passes one, which is harmless. `Bash(edm-state *)` is granted at `skills/code-audit/SKILL.md:8`. The empty case is handled at both ends (`:1777` prints nothing; `:75` omits the flag). |
| Phase-6 marker -> `edm-gateguard` | `bin/edm-state:2726` (`cmd_phase_start` phase 6) and `:4615` (session-start reconciliation) write it via `_edm_marker_write`; removal at `:2899`, `:3498`, `:5494` | `bin/edm-gateguard:97-114` reads it via `edm_marker_path` (`_edm-datadir-lib.sh:135-141`) | INTACT. Both ends resolve the path through the same library function and the same `CLAUDE_PROJECT_DIR`/git-toplevel project key (`_edm-datadir-lib.sh:113-126`). The explorer's concern that no producer existed (`explorers/02-hooks-runtime.md:104-110`) was closed by EDMV4-T12. |
| `run-all.sh` -> `wave8-smoke.sh` | `bin/tests/wave8-smoke.sh` | `bin/tests/run-all.sh:47` glob discovery; named in `_PREFERRED_ORDER` at `:41`; floor bumped to 8 at `:102` | INTACT. Discovery is glob-driven (`find ... -name '*-smoke.sh'`), so wave8 ran from the moment the file existed; the `:41`/`:102` additions add the missing-suite tripwire and the count floor. No gap. |
| `edm-gateguard`/`edm-bash-gate`/`edm-stop-gate` binaries -> hooks.json | `bin/edm-gateguard`, `bin/edm-bash-gate`, `bin/edm-stop-gate` all exist; executable bit and `--help` exit-0 asserted over all five new binaries at `bin/tests/wave8-smoke.sh:5125-5134` | `hooks/hooks.json:95`, `:104`, `:118`, each guarded with `command -v <name> >/dev/null 2>&1 \|\| exit 0` | INTACT for existence/executability/guarding. The matchers `Edit\|Write\|MultiEdit` and `Bash` are valid tool-name patterns. Host PATH resolution of `plugins/edm/bin/` is the plugin's existing, pre-EDMV4 mechanism (every `edm-state` hook already depends on it) and is not re-litigated here. |
| `UserPromptExpansion` gates -> `edm-state gate-check` | `bin/edm-state`'s `cmd_gate_check`, exit 3 on gate refusal | `hooks/hooks.json:19`, `:32`, `:45`, `:58`, `:71` -- five matcher-disjoint blocks, each guarded with `command -v edm-state`, each mapping exit 3 to exit 2 and every other status to exit 0 | INTACT. `UserPromptExpansion` is a supported event; the five matchers name real skill commands; the command and prompt halves resolve the same gate via the same binary rather than hardcoding a gate number. |

## Noted / Not Actionable

| ID | File:Line | Rationale |
|----|-----------|-----------|
| L11-007 | plugins/edm/CLAUDE.md:925 | No hookify rule file ships anywhere in the plugin and `.claude/edm-hookify/` does not exist in this repository (only test fixtures at `bin/tests/fixtures/hookify/`). Taken alone this reads as "evaluator wired to nothing", but it is explicitly intentional and documented: the directory is project-owned and "does not exist until a project's own team adds a rule to it" (`:926-927`), and `:929-936` explains why this marketplace repo's own `.gitignore` correctly excludes it. False-alarm filter 2 (intentional by design). Recorded rather than dropped because it means no shipped configuration exercises the hookify blocking path at all, so L11-005 and L11-006 are latent rather than active. |
| L11-008 | plugins/edm/bin/edm-repo-readiness:496 | `--json <path>` writes the machine-readable report, and no shipped consumer reads it -- the only caller is `bin/tests/wave8-smoke.sh:3153`. This is a deliberate user-facing CLI affordance documented in the EDM-HELP block at `:35-36`, not an orphaned internal contract. Noted because it is also the obvious acquisition path for the L11-004 fix. |
| L11-009 | plugins/edm/bin/edm-hookify:91 | The `list` subcommand has no in-plugin consumer; only `eval` is called by the three gates. Documented as a user-facing CLI in the EDM-HELP block at `:16`, so this is a CLI surface, not a dead internal call. False-alarm filter 2. |
| L11-010 | plugins/edm/bin/edm-stop-gate:108 | `stop`-event hookify rules evaluate only when at least one initiative is active -- the zero-active-initiative path exits at `:108` before the hookify block at `:158`. Unlike the `file`-event case (L11-005) this IS documented, at `:154-157` and in the EDM-HELP block at `:24-25`, with a stated rationale (a repository with no active initiative has nothing to say at every Stop). False-alarm filter 2. |

## Traces completed

All five requested traces were completed: (1) hooks.json to its registered commands, (2) hookify
to `edm-gateguard`/`edm-stop-gate`/`edm-bash-gate`, (3) the three new lens agents across all five
registration surfaces, (4) `edm-repo-readiness` to plan Step 6 and to the Step 1b.5 classifier,
(5) `detect-conditional-lenses` to code-audit Step 1.

One trace was NOT performed and is called out so it is not assumed clean: host PATH injection of
`plugins/edm/bin/` was taken as given rather than verified, because it is the plugin's
pre-existing mechanism that every `edm-state` hook already depends on. If that assumption is ever
false, every hook in `hooks.json` silently no-ops via its own `command -v ... || exit 0` guard,
and no finding here would surface it.
