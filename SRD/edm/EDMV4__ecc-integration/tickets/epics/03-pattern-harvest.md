# Epic 03: Pattern Harvest

Scope item 4.2 -- the `update-patterns` read-only-install defect, plus the shared data-directory
resolver both 4.1 and 4.2 stand on. Four tickets: **EDMV4-T17** delivers
`bin/_edm-datadir-lib.sh`, the first `${CLAUDE_PLUGIN_DATA}` consumer in `bin/` and the only
unblocked-from-day-one ticket in this epic; **EDMV4-T18** is the 4.2 fix itself -- the writable
harvested delta, the `get-patterns --paths` read side, and the single-commit coupling that binds
them, carried as one ticket because `EDMV4-15` and `EDMV4-16` were merged into `EDMV4-14` during
the SRD audit; **EDMV4-T19** corrects the stale caller-count comment in `cmd_update_patterns`;
and **EDMV4-T20** lays regression coverage over every branch of the new write and read paths.
The epic's whole reason for existing is that EDM's pattern library today only ever grows for
people running the plugin from a checkout of this repository -- for every installed user the
learning loop is a no-op that logs to stderr and returns success.


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

## EDMV4-T17: Build the shared data-directory resolver library

| Field | Value |
|---|---|
| Epic | Pattern Harvest |
| Phase | 2 |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV4-13 |
| Depends On | none |
| Target Components | plugins/edm/bin/_edm-datadir-lib.sh (new), plugins/edm/bin/edm-state, plugins/edm/CLAUDE.md, plugins/edm/bin/tests/wave8-smoke.sh (new), SRD/edm/EDMV4__ecc-integration/architecture.md |

### Description

`${CLAUDE_PLUGIN_DATA}` appears exactly once in the entire plugin -- as prose in
`plugins/edm/CLAUDE.md:77`, the reservation rule -- and **zero times in any executable script**.
There is no existing resolution pattern in `bin/` to copy. Both 4.1's Phase-6 marker and 4.2's
harvested pattern delta need a writable, plugin-owned directory outside the repository working
tree, so per AD3 one library owns the whole question rather than each consumer inventing its own
fall-through chain.

The library exposes exactly three functions. `edm_data_dir()` walks
`${CLAUDE_PLUGIN_DATA}` (if absolute and creatable) -> `${XDG_DATA_HOME}/edm` (if `XDG_DATA_HOME`
is absolute) -> `${HOME}/.local/share/edm` -> the empty string, which callers treat as
"unresolvable" and degrade against. `edm_project_key()` resolves `CLAUDE_PROJECT_DIR` when it
names a directory, else `git rev-parse --show-toplevel`, else `pwd`, then replaces `/` and `.`
with `-` in pure bash parameter expansion rather than `tr` -- the CA-448 precedent from
`check_permission_rules`, so a hook invoked from a subdirectory keys the same path the `edm-state`
writer created. `edm_marker_path()` prints `${data}/run/<key>.phase6`.

**Scope is the library and its own coverage, and nothing else.** Assertions about a *consumer*
sourcing it belong to the requirement that builds that consumer, because neither hook consumer
exists when this lands: `edm-gateguard`'s sourcing is asserted by `EDMV4-07` and `edm-state`'s
marker writes by `EDMV4-08`. The consumer set is **two sourcing consumers, `edm-state` and
`edm-gateguard`** -- `edm-hookify` does not need the data directory (its rule files are
project-relative and source-controlled per D7, and `EDMV4-41` requires it be read-only), and
sourcing a resolver it never calls would add startup cost to a path `edm-gateguard` invokes per
edit.

### Acceptance Criteria

- [ ] AC1: `plugins/edm/bin/_edm-datadir-lib.sh` exists, `bash -n` passes under `/bin/bash`
      (the macOS bash 3.2 binary, not a Homebrew bash 5), and sourcing it in a fresh shell defines
      `edm_data_dir`, `edm_project_key` and `edm_marker_path`, exits 0, produces no stdout, no
      stderr, and creates no files.
- [ ] AC2: `bin/edm-state` sources the library, and the sourcing is guarded (a `[[ -r ... ]]` test
      or equivalent) so that deleting the library file degrades `edm-state` to today's behaviour
      rather than failing every subcommand. A smoke test runs `edm-state list` and
      `edm-state validate` with the library removed and asserts both still exit as they do today.
- [ ] AC3: The library defines **only** those three functions plus strictly-internal helpers whose
      names carry a leading underscore, and declares no global variables. A smoke test sources the
      library inside a scratch shell alongside `edm-state`'s constant block (the region containing
      `PATTERN_AUDIT_TYPE_ENUM_LIST` at `bin/edm-state:811`) and asserts no function or variable
      is redefined by either side.
- [ ] AC4: `edm_data_dir()` implements the four-step order above exactly, including the
      **fall-through on a relative value** (a relative `CLAUDE_PLUGIN_DATA` or `XDG_DATA_HOME` is
      skipped, not used) and the **empty-string terminal case** when all three fail.
- [ ] AC5: Two subdirectories are created on demand and never conflated: `${data}/patterns/`
      (durable harvested deltas) and `${data}/run/` (ephemeral markers and session state). A smoke
      test asserts a `patterns/` write does not appear under `run/` and vice versa.
- [ ] AC6: The library is bash 3.2 compatible: no associative arrays, no `${var^^}`, no `mapfile`,
      and no process substitution in a loop condition (the CA-472 fd-leak class). A smoke test
      greps the file for each of those four constructs and fails on any hit.
- [ ] AC7: `edm_data_dir()` and `edm_marker_path()` spawn **zero** subprocesses. `edm_project_key()`
      may spawn `git rev-parse --show-toplevel` only when `CLAUDE_PROJECT_DIR` is unset or does not
      name a directory. Asserted by a smoke test that sets `CLAUDE_PROJECT_DIR` to a scratch
      directory, shadows `git` with a failing stub earlier on `PATH`, and requires all three
      functions to still succeed.
- [ ] AC8: A smoke test exercises all four `edm_data_dir()` branches by manipulating
      `CLAUDE_PLUGIN_DATA`, `XDG_DATA_HOME` and `HOME`, including the relative-value fall-through
      and the all-fail case where the returned string is empty and the exit status is still 0.
- [ ] AC9: A smoke test asserts that with `CLAUDE_PLUGIN_DATA` unset, no `edm_data_dir()` or
      `edm_marker_path()` call writes anything inside the repository working tree:
      `git status --porcelain` is empty before and after.
- [ ] AC10: `plugins/edm/CLAUDE.md`'s `bin/` helper table gains a row for `_edm-datadir-lib.sh`
      naming its three functions, and `architecture.md` AD3's prose (the sentence at `:96-97`
      naming `edm-state`, `edm-gateguard` **and** `edm-hookify`) is amended to name two sourcing
      consumers so it agrees with its own component table at `:212`.

### Technical Notes

The structural source is ECC's MIT-licensed
`ECC/skills/continuous-learning-v2/scripts/lib/homunculus-dir.sh:1-31` -- the three-step
absolute-only chain with fall-through-on-relative. Per AD1 the adoption is mechanism-level and no
text is copied; the attribution obligation itself is `EDMV4-59`/`EDMV4-56`'s, not this ticket's.

Filename note: the leading underscore in `_edm-datadir-lib.sh` matters. `run-all.sh` discovers
suites with `find ... -name '*-smoke.sh'` (`bin/tests/run-all.sh:45`) and every script in `bin/` is
added to PATH while the plugin is enabled, so a sourced-only library must not read as a callable
helper. It follows the existing `_edm-cli-lib.sh` convention.

**Stale citation corrected.** The SRD and `architecture.md` both cite the `${CLAUDE_PLUGIN_DATA}`
reservation prose as `plugins/edm/CLAUDE.md:71`. On the current branch tree it is at
**`plugins/edm/CLAUDE.md:77`**. The SRD also names "the analysis document" as the second prose
reference; `plugins/edm/docs/ecc-integration-analysis.md` **does not exist anywhere in this
repository on this branch**, so `CLAUDE.md:77` is the only prose reference that survives
verification. Do not restate the two-reference claim without re-checking it.

`edm_project_key()`'s `/`-and-`.`-to-`-` encoding is EDM's own existing idiom from
`session_dir_for_cwd` in `bin/edm-state`. Reimplement it with parameter expansion
(`${path//\//-}` then `${path//./-}`), not `tr`, so the hook path stays subprocess-free per AC7.

Size is S rather than XS because AC3, AC7 and AC9 each need a purpose-built scratch-shell harness
that `bin/tests/_harness.sh` does not provide today.

### Out of Scope

- Any marker write or removal in `cmd_phase_start` / `cmd_phase_complete` / `cmd_archive` /
  `cmd_skip_phase` (that is `EDMV4-08`, Epic 02).
- `bin/edm-gateguard` and its sourcing of this library (`EDMV4-07`).
- Any `edm-hookify` dependency on this library -- explicitly decided against.
- Resolving where `${data}/patterns/` should live if R3 proves true (the "move patterns to XDG
  unconditionally" mitigation); this ticket only makes the durable/ephemeral split cheap.
- The `update-patterns` write-target change itself -- `EDMV4-T18`.

---

## EDMV4-T18: Land the 4.2 fix -- writable harvested delta and `get-patterns` read side, in one commit

| Field | Value |
|---|---|
| Epic | Pattern Harvest |
| Phase | 2 |
| Priority | Must Have |
| Size | L |
| SRD Refs | EDMV4-14, EDMV4-15 (merged), EDMV4-16 (merged) |
| Depends On | EDMV4-T17 |
| Target Components | plugins/edm/bin/edm-state (`cmd_update_patterns`, `_cmd_update_patterns_body`, `PATTERN_AUDIT_TYPE_ENUM_LIST`, the dispatch `case`, `state_anomalies`), plugins/edm/docs/audit-patterns/README.md, plugins/edm/docs/audit-patterns/{srd,ticket,qc,code,test-coverage}-audit.md, plugins/edm/agents/edm-srd-writer.md, plugins/edm/agents/edm-ticket-writer.md, plugins/edm/agents/edm-implementer.md, plugins/edm/agents/edm-test-coverage-auditor.md, plugins/edm/skills/{srd,tickets,implement,test-coverage}/SKILL.md, plugins/edm/bin/edm-check-grants, plugins/edm/CLAUDE.md, plugins/edm/bin/tests/wave8-smoke.sh (new) |

### Description

`cmd_update_patterns` computes its write target as
`local patterns_dir="${SCRIPT_DIR}/../docs/audit-patterns"` -- inside the plugin's own installed
tree. On any plugin-cache install that directory is not writable, so the `[[ ! -w "$pattern_dir" ]]`
guard is true, the function warns to stderr and `return 0`s. The skip is deliberate and graceful
(it never `die`s and never aborts the phase), and the message shows the author anticipated
read-only installs; what was never followed through is where the data should go instead. The
consequence is that **EDM's pattern library only ever grows for people running the plugin from a
checkout of this repository**. This ticket resolves the write target through `edm_data_dir()` to
`${data}/patterns/{type}-audit.md`, creating the delta on first write as a **stub** carrying only
the Living-Library contract headings plus one provenance line -- never a copy of the seed -- so
seed and delta are disjoint by construction and concatenation cannot double-count an entry.

**The read side is the other half of the same change.** Four agents read the pattern library today,
each doing one `Read` of one file and each resolving "the plugin root" itself with no concrete
mechanism named anywhere -- no env var, no `bin/` helper, nothing like `CLAUDE_PLUGIN_ROOT`.
`agents/edm-implementer.md:19` states it most explicitly, and it is the same unresolvable-reference
class D22 documents for `CLAUDE.md Sec."..."` references. Per AD6 the fix is **route (c)**:
`edm-state get-patterns <type> --paths` prints the two resolved absolute paths, seed first and
delta second, the launching skill (which already has `Bash`) interpolates both into the agent
launch template, and the agents do two ordinary `Read`s. **Route (b) is blocked**:
`agents/edm-srd-writer.md:8` and `agents/edm-ticket-writer.md:7` carry
`tools: Glob, Grep, LS, Read, NotebookRead, WebFetch, Write, Edit, TodoWrite, WebSearch` with **no
`Bash` grant**, and widening a deliberately narrow tool surface on two writer agents to read a
documentation file is disproportionate. Route (a) -- four agents each merging by their own rule --
is the duplicated-logic class the Append Schema and the D6 guard both exist to prevent.

**Why the two sides cannot be separated, and why this is one ticket.** A seed-only read against a
delta-only write **silently loses all harvested content**, and the loss is invisible because
`update-patterns` reports success on every append. Both halves individually pass their own tests;
the failure surfaces only as a pattern library that stops growing, which nobody notices. That is
risk R9 and the single most dangerous sequencing hazard in the initiative.
**`EDMV4-14`, `EDMV4-15` and `EDMV4-16` are one requirement mapped to this one ticket, and every
piece named in AC11 lands in one commit. Do not split this ticket. A later editor who splits it
reintroduces exactly the failure mode AC12's retained negative test documents.**

### Acceptance Criteria

- [ ] AC1: `cmd_update_patterns` resolves its write target via `edm_data_dir()` to
      `${data}/patterns/{srd,ticket,qc,code,test-coverage}-audit.md`, and its degradation is
      strictly additive, preserving both existing behaviours in order: (a) try the data directory;
      (b) if unresolvable, try the shipped tree when writable -- today's behaviour; (c) if neither,
      warn to stderr and `return 0` -- today's behaviour. A smoke test asserts each of the three
      branches independently and asserts the exit status is 0 in all three, so no branch can abort
      a phase.
- [ ] AC2: On first write for a given audit type the delta is created as a stub containing only the
      four Living-Library contract headings from `docs/audit-patterns/README.md:7-14` (`## Top
      Recurring Findings`, `## Anti-Patterns`, `## Pre-Flight Checklist`, and a fourth matching
      `^## What .*Looks Like$`) plus a one-line provenance record. A smoke test compares the fresh
      stub against the shipped seed and requires **zero shared `###` finding entries**.
- [ ] AC3: De-duplication runs against **both** the seed's entry titles and the delta's entry
      titles, using the existing normalisation from `docs/audit-patterns/README.md:46` (lowercased,
      whitespace-collapsed, trailing-parens metadata stripped), so a finding already present in the
      shipped seed is never re-appended to the delta.
- [ ] AC4: The fence-aware insertion-target resolution (`pattern_target_heading_for` plus
      `pattern_insert_line_for`, currently at `bin/edm-state:5645-5654`) is preserved unchanged,
      including its two distinct outcomes: a heading genuinely absent is a clean skip that appends
      nothing and exits 0, and a heading present only inside a fenced code block is a loud `die`
      that records no `patterns_updates` (the G16 / CA-355 fix).
- [ ] AC5: `${data}/patterns/harvest-provenance.json` records a write count and a first-write
      timestamp (ISO-8601 UTC), updated under the same lock as the splice, so the R3 exposure -- a
      plugin upgrade silently clearing the delta while `update-patterns` keeps reporting successful
      appends -- has an observable signature.
- [ ] AC6: `edm-state validate` gains an **informational** anomaly when the shipped seed's mtime is
      newer than the delta's recorded first-write timestamp. It is emitted in the canonical
      four-field form `<class>  <CODE>  <affected-field>  <description>` documented at
      `bin/edm-state:1693` with `<class>` literally `info`, and a smoke test asserts that a state
      whose only anomaly is this one still exits 0 from `validate` -- it never flips the exit code.
- [ ] AC7: `patterns_updates` continues to be recorded in `.edm-state.json` on every successful
      splice with the same shape as today (including `new_findings` and `extraction_status`);
      `plugins/edm/CLAUDE.md`'s state-field table gains a row for the new anomaly stating its C-4
      absent behaviour; and its `bin/` helper table lists `get-patterns` among `edm-state`'s
      subcommands, with the stated count **incremented to match the subcommands actually
      dispatched** rather than set to a literal. `EDMV4-T24` also adds one
      (`detect-conditional-lenses`), so a literal "40" here is wrong once both land -- the true
      final value is 41. `EDMV4-T24` AC11 owns the reconciliation. This ticket's own sibling
      `EDMV4-T19` exists precisely because a maintained count in a comment drifts silently.
- [ ] AC8: `edm-state get-patterns <type> --paths` prints **exactly two lines**: the seed's absolute
      path, then the delta's absolute path. Neither is plugin-root-relative. When the delta does not
      exist or the data directory is unresolvable the second line is **empty rather than absent**,
      so a consumer can distinguish "no delta" from a truncated read; that contract is stated in the
      subcommand's `EDM-HELP-BEGIN` block. `<type>` is validated against the existing
      `PATTERN_AUDIT_TYPE_ENUM_LIST` (`bin/edm-state:811`) using the same
      `case " $LIST " in *" $v "*)` word-membership idiom, never a re-encoded literal list.
- [ ] AC9: The four launching skills (`skills/{srd,tickets,implement,test-coverage}/SKILL.md`) call
      `get-patterns --paths` and interpolate both paths into their agent launch templates, and the
      four reading agents (`edm-srd-writer.md:25`, `edm-ticket-writer.md:32`,
      `edm-implementer.md:24-25`, `edm-test-coverage-auditor.md:41`) are updated to `Read` two
      explicit absolute paths in order, seed first. Each agent carries one sentence on merge order
      referencing `docs/audit-patterns/README.md`, and **none carries its own de-duplication rule**.
- [ ] AC10: **No agent gains a new tool grant.** `agents/edm-srd-writer.md:8` and
      `agents/edm-ticket-writer.md:7` still list no `Bash` after the change, asserted by
      `bin/edm-check-grants`. `edm-check-grants` additionally gains an assertion that every skill
      launch template spawning one of the four pattern-reading agents carries **both** interpolated
      paths, closing risk R8/R7 (a skill edit silently leaving an agent reading nothing). A smoke
      test asserts an agent handed an empty second path reads only the seed and proceeds normally,
      with no error and no warning.
- [ ] AC11: **One commit** contains all of: the `cmd_update_patterns` write-target change, the
      seed-stub creation, the `get-patterns` subcommand and its dispatch arm, the four agent
      read-site edits, and the four launching-skill interpolation edits. The single-commit
      constraint is restated in this ticket's own Description so a later editor cannot split it.
- [ ] AC12: The coupling is enforced three ways, all of which must be present: (a) the ticket-pack
      coverage map in `tickets/README.md` shows `EDMV4-14`, `EDMV4-15` and `EDMV4-16` all mapped to
      `EDMV4-T18` and the ticket-pack audit fails if the requirement is split across two tickets or
      two waves; (b) an end-to-end smoke test in one process runs `update-patterns` against a
      fixture audit report with the shipped tree made read-only, then runs `get-patterns --paths`,
      then reads both paths, and asserts the harvested finding is present in the concatenation --
      this test fails if either half is missing; (c) a **retained** negative test asserts that with
      the write side applied and the read side reverted, the harvested finding is **absent** from
      what an agent would read. Test (c) exists to document why the coupling is mandatory and is
      never deleted as redundant.

### Technical Notes

**Every `bin/edm-state` line citation in `EDMV4-14` is stale by 4 lines against the current branch
tree, and the SRD's own two citations of the caller-count comment disagree with each other.**
Verified positions on this branch:

| SRD says | Actually at | What it is |
|---|---|---|
| `:5581-5604` | `:5577-5600` | `cmd_update_patterns` head through the `pattern_file` `case` |
| `:5595` | `:5591` | the `patterns_dir` assignment this ticket changes |
| `:5625-5630` (guard at `:5627`) | `:5621-5626` (guard at `:5623`) | the read-only skip branch |
| `:5649-5658` | `:5645-5654` | the fence-aware pre-flight |
| `:5527` | `:5523` | `_cmd_update_patterns_body` |
| `:813-814` | `:811` | `PATTERN_AUDIT_TYPE_ENUM_LIST` |
| dispatch `case` at `:6239+` | `update-patterns)` arm at `:6274` | where the `get-patterns` arm is added |

Re-derive every one of these by symbol name before editing; do not seek by line number. The agent
and skill citations, by contrast, **all verified exact** (`edm-srd-writer.md:8` and `:25`,
`edm-ticket-writer.md:7` and `:32`, `edm-implementer.md:24-25`, `edm-test-coverage-auditor.md:41`).

The splice already runs under `with_state_lock "${pattern_file%.md}"`. Moving `pattern_file` out of
the repository moves the lock file with it; confirm the lock path stays inside `${data}/` and does
not fall back to a repository-relative location when `edm_data_dir()` returns empty.

Bash 3.2 floor: `harvest-provenance.json` is read and written with `jq` (an allowed binary under
C2), not with an associative array. `jq` is already required by `cmd_update_patterns` via
`require_jq` at its top, so this adds no new dependency.

The `ticket` and `test-coverage` arms harvest **nothing** by design -- their report formats have no
machine-identifiable finding shape and they report `extraction_status: unsupported-format`
(`docs/audit-patterns/README.md:63-64`). The end-to-end test in AC12(b) must therefore use `srd`,
`qc` or `code` as its fixture type, or it will pass vacuously.

**Size justification (L, and it is honestly L, not a disguised XL).** This ticket carries three
merged requirements and touches 15 files across `bin/`, `agents/`, `skills/`, `docs/` and
`CLAUDE.md`. Decomposition is not merely overhead here -- it is the specific failure the merge
exists to prevent, so the usual "split an L" reflex is exactly wrong. The work is nonetheless
bounded: the write side is one function's target resolution plus a stub writer, the read side is
one new subcommand arm plus eight prose edits following one template, and the coupling is three
tests. If an implementer finds it running past two weeks, the correct response is to say so at the
gate and re-scope the requirement -- **not** to split the ticket.

### Out of Scope

- The data-directory resolver itself (`EDMV4-T17`).
- The stale caller-count comment (`EDMV4-T19`) -- it lands adjacent in the same function but is a
  separate doc-accuracy fix with its own SRD requirement.
- The broader regression suite (`EDMV4-T20`). This ticket writes only the tests its own ACs name.
- Any change to the shipped seeds' content. The five `docs/audit-patterns/*-audit.md` files become
  read-only inputs; nothing in this ticket edits their findings.
- Curation-at-gates behaviour (`docs/audit-patterns/README.md Sec."Curation at Gates"`). The four
  curation options operate on whichever document holds the pending entry; no gate prompt changes.
- Any new tool grant for any agent, and any migration of existing harvested content -- there is
  none, because on a read-only install nothing was ever harvested.
- Moving `${data}/patterns/` to XDG unconditionally (the R3 mitigation, if R3 proves true).

---

## EDMV4-T19: Correct the stale caller-count comment in `cmd_update_patterns`

| Field | Value |
|---|---|
| Epic | Pattern Harvest |
| Phase | 2 |
| Priority | Should Have |
| Size | XS |
| SRD Refs | EDMV4-17 |
| Depends On | EDMV4-T18 |
| Target Components | plugins/edm/bin/edm-state (the CA-476 comment block in `cmd_update_patterns`), plugins/edm/docs/audit-patterns/README.md, plugins/edm/skills/implement/SKILL.md:46, plugins/edm/skills/code-audit/SKILL.md:135, plugins/edm/skills/audit-tickets/SKILL.md:52, plugins/edm/skills/audit-srd/SKILL.md:50, plugins/edm/skills/test/SKILL.md:132, plugins/edm/skills/test-coverage/SKILL.md:65 |

### Description

The CA-476 comment inside `cmd_update_patterns` reads "update-patterns is called mid-phase by four
skills". The verified count is **six**. This is a small standalone doc-accuracy fix, distinct from
the read-only-path defect itself, and it belongs in the same change so the file's own comment does
not keep asserting a number the tree contradicts.

The durable fix is to stop carrying a maintained count in a comment at all. A count in a comment
drifts silently -- this one already has -- and re-stating "six" only resets the clock until the
seventh call site is added. The comment's substantive point does not depend on the number: neither
"nothing harvested" outcome is a `die`, because aborting a phase over a report-format gap would be
worse than the gap.

### Acceptance Criteria

- [ ] AC1: The comment no longer carries a maintained count. It is reworded to state the property
      that matters ("called mid-phase by the audit and implementation skills") rather than a number,
      or it enumerates the six call sites explicitly; the count-free wording is preferred and the
      choice is stated in the commit message.
- [ ] AC2: The six call sites are verified against the tree at edit time and are exactly:
      `skills/implement/SKILL.md:46`, `skills/code-audit/SKILL.md:135`,
      `skills/audit-tickets/SKILL.md:52`, `skills/audit-srd/SKILL.md:50`, `skills/test/SKILL.md:132`,
      `skills/test-coverage/SKILL.md:65`. Each is re-checked with `grep -n 'update-patterns'` before
      the comment is rewritten, not copied from this ticket.
- [ ] AC3: The comment's substantive point is preserved **unchanged**: neither "nothing harvested"
      outcome (`unsupported-format`, `no-recognized-findings`) is a `die`, because aborting a phase
      over a report-format gap would be worse than the gap (CA-476).
- [ ] AC4: The second copy of the same stale claim, at
      `plugins/edm/docs/audit-patterns/README.md:85` ("`update-patterns` is called mid-phase by four
      skills, so it warns and continues rather than aborting the phase"), is corrected the same way
      in the same commit. Its own Consumers section at `README.md:113-118` already lists all six
      call sites, so the file currently contradicts itself.
- [ ] AC5: The change is **comment-only and prose-only**. `git diff` on `bin/edm-state` for this
      commit touches no executable line, and `bash -n plugins/edm/bin/edm-state` passes.
- [ ] AC6: A smoke assertion in `bin/tests/wave8-smoke.sh` greps the CA-476 comment block for the
      literal number-words `four` and `six` and fails on either, so the count cannot be
      reintroduced and drift a second time.
- [ ] AC7: `bash plugins/edm/bin/tests/run-all.sh` passes after the change, with no assertion
      elsewhere in the suite depending on the old comment text.

### Technical Notes

**Two SRD citations of this comment disagree, and both are stale.** `EDMV4-17`'s heading names
`bin/edm-state:5672`; its own Target Components line names `bin/edm-state:5668-5673`. On the current
branch tree the CA-476 comment block is at **`:5664-5669`**, with the words "four skills" on
**`:5668`**; `:5672` is the `extracted_count` normalisation line, which carries no comment at all.
Locate the block by grepping for `called mid-phase by four skills`, not by line number. That two
citations of a single four-word comment could both be wrong is a fair summary of why this
requirement exists.

`EDMV4-17` AC4 states that `plugins/edm/docs/ecc-integration-analysis.md`'s own "called mid-phase by
four skills" claim is corrected as part of `EDMV4-54`. **That file does not exist anywhere in this
repository on this branch** (`docs/` contains only `canonical-sections.md` at its top level). Either
it is authored later by another EDMV4 ticket, or the citation is a residue of a working document
that was never committed. Nothing in this ticket depends on it; do not create the file to satisfy
the reference.

AC4 is an addition beyond `EDMV4-17`'s own four acceptance criteria, made because verification
surfaced a third site the SRD did not name. It is the same claim, the same class of defect, and the
same commit -- but an auditor comparing this ticket against `EDMV4-17` line by line should know it
was added deliberately rather than inherited.

Depends on `EDMV4-T18` because that ticket rewrites the surrounding function; sequencing this first
guarantees a conflict on the same hunk for no benefit.

### Out of Scope

- Any behavioural change to `cmd_update_patterns` -- this is a comment and prose change only.
- `docs/ecc-integration-analysis.md`, which does not exist here (owned by `EDMV4-54` if and when it
  does).
- Auditing every other maintained count in the plugin (the "39 subcommands" figure in
  `CLAUDE.md`'s `bin/` table is handled by `EDMV4-T18` AC7; other counts are not this ticket's).
- Changing the CA-476 warning messages themselves or the `extraction_status` enum.

---

## EDMV4-T20: Lay regression coverage over every branch of the 4.2 write and read paths

| Field | Value |
|---|---|
| Epic | Pattern Harvest |
| Phase | 2 |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV4-18 |
| Depends On | EDMV4-T18 |
| Target Components | plugins/edm/bin/tests/wave8-smoke.sh (new), plugins/edm/bin/tests/run-all.sh, plugins/edm/bin/tests/fixtures/ (new pattern fixtures) |

### Description

There is no CI pipeline for this plugin. `bin/tests/run-all.sh` plus the git-commit hook are the
entire enforcement surface, and `plugins/edm/CLAUDE.md` says so explicitly: running the local smoke
suite *is* the enforcement, not a convenience check ahead of a pipeline. Every branch of the new
write path and read path therefore needs an assertion, or a future edit reverts one silently -- and
the silent-revert failure mode here is exactly the one risk R9 names, where the library stops
growing and nobody notices for months.

`EDMV4-T18` writes the tests its own acceptance criteria name. This ticket completes the matrix:
the two de-duplication directions, the preserved fence-aware refusal, the `--paths` empty-second-
line contract, and the registration work that makes the whole new suite discoverable and
non-deletable.

### Acceptance Criteria

- [ ] AC1: A smoke test asserts the writable-data-directory path end to end: the delta file is
      created under `${data}/patterns/`, the stub carries the four Living-Library headings in
      contract order (heading 4 matching `^## What .*Looks Like$`), and the harvested finding is
      spliced under the correct insertion target -- `## Anti-Patterns` by default, per
      `docs/audit-patterns/README.md:16`.
- [ ] AC2: A smoke test asserts the shipped-tree-writable fallback produces today's exact
      behaviour: with `edm_data_dir()` forced to return empty and the shipped tree writable, the
      finding lands in `docs/audit-patterns/{type}-audit.md` and `patterns_updates` is recorded
      with the same shape as before the change.
- [ ] AC3: A smoke test asserts the all-unwritable path warns on stderr naming the directory, exits
      **0**, and appends nothing -- the target file is byte-identical before and after (compared by
      checksum, not by line count).
- [ ] AC4: A smoke test asserts de-duplication against the seed: a fixture report whose finding
      title already exists in the shipped seed produces no append to the delta and
      `new_findings: 0`.
- [ ] AC5: A smoke test asserts de-duplication against the delta: running `update-patterns` twice
      on the same fixture report appends the finding exactly once, asserted by counting `###`
      entries matching the title.
- [ ] AC6: A smoke test asserts `get-patterns <type> --paths` prints exactly two lines with an
      **empty second line** when no delta exists, and that the same holds when `edm_data_dir()` is
      unresolvable -- `wc -l` is 2 in both cases, distinguishing this from a truncated read.
- [ ] AC7: A smoke test asserts the fence-aware refusal still fires: with the target heading present
      only inside a fenced code block, `update-patterns` exits non-zero, appends nothing, and
      records no `patterns_updates` entry (the G16 / CA-355 behaviour).
- [ ] AC8: The new tests are reachable from `run-all.sh`: `wave8-smoke.sh` is discovered by the
      `find ... -name '*-smoke.sh'` sweep and this ticket's cases actually execute in an aggregate
      run. **This ticket does not perform the `_PREFERRED_ORDER` / `_MIN_SUITE_COUNT` registration
      -- `EDMV4-T53` AC2 owns it solely** (audit P1-3). Three tickets previously carried the same
      two-line edit with no edge between them, so whichever landed first made the others vacuous.
      Assert the registration is *present*; if it is not, that is a defect against `EDMV4-T53`.
- [ ] AC9: Every test in the suite runs against a scratch `HOME` / `CLAUDE_PLUGIN_DATA` /
      `XDG_DATA_HOME` and leaves `git status --porcelain` empty. `bash plugins/edm/bin/tests/run-all.sh`
      passes from a clean tree, and re-running it twice in a row produces the same result (no test
      leaves state that another test depends on).

### Technical Notes

Follow `bin/tests/_harness.sh`'s existing assertion helpers rather than inventing a second harness;
`wave7-smoke.sh` is the closest structural model for a suite that manipulates state files.

`_MIN_SUITE_COUNT` currently defaults to `7` and exactly seven suites exist today (`wave3`,
`wave4a`, `wave4b`, `wave5`, `harness`, `wave6`, `wave7`). Adding `wave8-smoke.sh` without raising
the floor means deleting `wave8-smoke.sh` again would leave the aggregate green -- which is
precisely the tripwire the constant exists to be. Note that `EDM_RUN_ALL_SUITE_DIR`,
`EDM_RUN_ALL_PREFERRED_ORDER` and `EDM_RUN_ALL_MIN_SUITE_COUNT` are `harness-smoke.sh`'s own
override knobs; raising the default must not break `harness-smoke.sh`'s scratch-suite scenarios,
which pass their own `EDM_RUN_ALL_MIN_SUITE_COUNT`.

Fixture audit reports must match the documented **source-side** finding shapes at
`docs/audit-patterns/README.md:58-64`, not the destination shape: an `srd` fixture needs a
`[CATEGORY] [SEVERITY] Section X.Y | finding | recommendation` line; a `qc` fixture needs a
`**Finding**: [SEV] {PREFIX}-T{NN} | {file:line} | {text}` line; a `code` fixture needs a heading
whose title starts with `CA-NNN` or `G{N}`. Fixtures for `ticket` and `test-coverage` will harvest
nothing by design and must not be used for AC1, AC4 or AC5.

`wave8-smoke.sh` is shared with `EDMV4-07`/`EDMV4-08` (the GateGuard and marker work) and with
`EDMV4-T19` AC6. Write the pattern-harvest assertions under their own clearly banded section header
so a later GateGuard commit does not interleave with them.

Size is S rather than M because `EDMV4-T18` has already landed the three-branch degradation test,
the stub-disjointness test, the empty-second-path agent test, and the end-to-end and negative
tests; what remains here is four additional assertions plus fixtures plus registration.

### Out of Scope

- Any production-code change. If an assertion in this ticket fails against `EDMV4-T18`'s
  implementation, the fix belongs in a follow-on against `EDMV4-14`, not in this ticket's diff.
- Timing or latency assertions (`bin/tests/timing.sh --gateguard` belongs to the 4.1 epic).
- Coverage for `_edm-datadir-lib.sh` itself -- `EDMV4-T17` AC3/AC6/AC7/AC8/AC9 own that.
- Coverage for the GateGuard, hookify or Stop-gate surfaces that also land in `wave8-smoke.sh`.
- Retrofitting an extractor onto the `ticket` or `test-coverage` arms so they could be tested for
  harvest -- that requires changing those report formats first
  (`docs/audit-patterns/README.md:69-72`) and is not in this initiative.
