# QC Audit Report: EDMV4 ECC Integration -- Wave 2 [Shard 1/4]

**Date**: 2026-09-02
**Tickets audited**: `EDMV4-T12`, `EDMV4-T18`, `EDMV4-T22`, `EDMV4-T32` (4 of 4 assigned)
**Mode**: `implementation_mode=standard` -- the TDD compliance pass does not run.

Verified against the working tree, not implementer self-reports. Suite evidence:
`wave8-smoke.sh` and `wave6-smoke.sh` were executed directly (`run-all.sh` was not). `wave6`
returned 744 passed / 1 failed, and the single failure is the by-design
`T27 AC1 -- round_type = 'partial', expected full for an explicit all-11 listing`, owned by
`EDMV4-T30`. `wave7-smoke.sh`'s lens-count redness and the coordinator's in-flight
`EDMV4-T39 AC3` wave8 assertion are likewise not defects of these four tickets and are not
reported as such.

## Summary

| Ticket | Title | Verdict |
|---|---|---|
| EDMV4-T12 | Add the Phase-6 marker primitive with SessionStart reconciliation | FAIL |
| EDMV4-T18 | Land the 4.2 fix -- writable harvested delta and `get-patterns` read side, in one commit | FAIL |
| EDMV4-T22 | Materialize lenses and derive round_type from the lenses-union-lenses_na rule | PASS |
| EDMV4-T32 | Grow the code-audit test fixtures from 11 to 14 lens pairs | FAIL |

## Adjudications requested by the dispatcher

**1. `EDMV4-T22` AC10 -- is the `LENS_READ_JQ_DEF`-without-backstop-integration reading defensible?**
**Yes. Defensible scope boundary; AC10 graded PASS.** Three independent facts carry it:
`EDMV4-T22`'s own Out of Scope names "the CA-471 backstop's use of the new fields (`EDMV4-T23`)";
`EDMV4-T23` AC2 restates the identical assertion ("A smoke test replays that fixture and asserts
the backstop requires the full JSONL set rather than passing vacuously"), so the ticket pack
duplicates it rather than assigning it solely to T22; and the assertion is *unwritable today* --
`EDMV4-T23`'s Description states the backstop still iterates `lenses-run.txt`, so a T22-era test
routed through the backstop would exercise the manifest, not `read_round_lenses`, and would pass
regardless of whether the read rule existed. That is a vacuous assertion, which is precisely the
defect class this initiative has been bitten by five times. The implementer instead proved the rule
directly against fixture round records **with two discriminating controls**
(`wave6-smoke.sh:3845-3857`). The substance of AC10 -- the rule exists, in exactly one place, fires
on the empty+`full` shape, and does not fire otherwise -- is fully delivered. Recorded as
`[NOTED]` so the backstop-side assertion is not lost when T23 lands.

**2. `EDMV4-T32` AC3/AC4 -- does the deferral still stand?**
**No. The deferral is now stale, and both ACs are FAIL.** The stated reason for deferring was that
AC3/AC4 encode a `lenses_na` round-record shape `EDMV4-T22` was building concurrently, per T32's own
Technical Note: "Author them after `EDMV4-T22` lands so the shape is copied from real output rather
than guessed." `EDMV4-T22` has landed (`fd9b6d5`, `2395aa8`), `lenses_na` is now written by
`cmd_audit_round_start` (`bin/edm-state:4687`), and a real round record carrying
`lenses_na: ["L13"]` is producible today -- `wave6-smoke.sh:3693-3701` already produces and asserts
exactly that shape. The blocking precondition is gone; nothing now prevents authoring both
fixtures. Neither exists: `find plugins/edm/bin/tests/fixtures -type d` returns only `code-audit`,
`hookify`, `lint-lib` and `mermaid`, and `grep -rn lenses_na plugins/edm/bin/tests/fixtures/`
returns nothing.

## Detailed Findings

### EDMV4-T12: Phase-6 marker primitive with SessionStart reconciliation -- FAIL

- [ ] **AC1** (statically verifiable): `edm_marker_path()` spawns zero subprocesses; a smoke
      assertion fails if the body contains `$(`, a backtick, or a pipe -- **FAIL**. The body at
      `_edm-datadir-lib.sh:135-141` contains two command substitutions (`:137`
      `data="$(edm_data_dir)"`, `:139` `key="$(edm_project_key)"`). The smoke assertion at
      `wave8-smoke.sh:1558-1562` tests a different property -- an external-binary name list
      (`T12_EXTERNAL_BIN_RE`) -- not `$(`, backtick or pipe.
- [x] **AC2**: `cmd_phase_start` writes the marker on phase 6 after a successful `rmw_state`;
      degrades to exit 0 + stderr warning -- verified at `bin/edm-state:2640-2645` (write follows
      the `rmw_state` at `:2640-2642`) and `:88-102`; asserted at `wave8-smoke.sh:1662-1667`
      (exit 0 plus `could not create Phase-6 marker directory` on stderr) and `:1690`.
      The test substitutes a plain-file collision at `${data}/run` for `chmod`, documented at
      `wave8-smoke.sh:1633-1636`; that is strictly more robust than `chmod 555` (which root
      bypasses) and asserts the identical observable contract. Not a finding.
- [x] **AC3**: PREFIX-matched removal on `phase-complete 6` -- verified at `bin/edm-state:2815-2818`
      via `_edm_marker_remove_if_matches` (`:110-121`, the PREFIX comparison at `:118`); asserted
      at `wave8-smoke.sh:1755-1770` (non-removal for a different prefix, then removal for its own).
- [x] **AC4**: `cmd_archive` and `cmd_skip_phase` remove defensively, pre-change status when no
      marker -- verified at `bin/edm-state:3414-3417` and `:5356-5359`; asserted at
      `wave8-smoke.sh:1772-1822`. The no-marker case has a dedicated assertion for `skip-phase`
      (`:1814-1821`); for `archive` it is proven by code -- `_edm_marker_remove_if_matches` returns
      0 at `bin/edm-state:115` when no marker exists and `:3418`'s `echo "archived ..."` follows.
- [x] **AC5**: SessionStart reconciles both directions, exactly one line of operator output --
      verified at `bin/edm-state:4512-4537` (removal + single `echo` at `:4530-4531`, recreation at
      `:4533-4534`); asserted at `wave8-smoke.sh:1824-1856`, including an exact
      one-removal-line count.
- [x] **AC6**: one line, `PREFIX<TAB>dir<TAB>started_at`, literal tab, UTC ISO-8601 -- verified at
      `bin/edm-state:98` (`printf '%s\t%s\t%s\n' ... "$(now_utc)"`); asserted at
      `wave8-smoke.sh:1711-1723` (line count, three fields, ISO-8601 regex, literal tab byte).
- [x] **AC7**: marker path outside the repository -- verified: the path is rooted at
      `edm_data_dir()` (`_edm-datadir-lib.sh:140`), never at `SRD_ROOT`; asserted at
      `wave8-smoke.sh:1726-1734` (`git status --porcelain` unchanged; path not under
      `${EDM_SRD_ROOT}`).
- [ ] **AC8** (statically verifiable): the resolution chain, with a relative value falling through
      **with a stderr warning** and a zero exit status -- **FAIL**. The four-step order and the
      always-zero exit status are correct (`_edm-datadir-lib.sh:84-110`), but no stderr warning is
      emitted anywhere: `grep -n '>&2' plugins/edm/bin/_edm-datadir-lib.sh` returns nothing, and a
      live call with `CLAUDE_PLUGIN_DATA=relative/path` printed `${HOME}/.local/share/edm` on
      stdout with empty stderr and rc=0. `EDMV4-T17` AC4 does not carry the warning clause either,
      so T12's "AC8 is verification rather than implementation" note does not cover it -- the
      requirement is unimplemented on both tickets.
- [x] **AC9**: empty `edm_data_dir()` -> empty `edm_marker_path()` -> `edm-gateguard` treats it as
      "marker absent" and allows -- verified end to end now that `EDMV4-T11` has merged.
      `_edm-datadir-lib.sh:138` returns the empty string; `bin/edm-gateguard:109` resolves through
      the same function and `:117` exits 0 on `[[ -z "$MARKER_PATH" ]]` before any parser is
      referenced. Asserted at `wave8-smoke.sh:1577-1594` (empty return plus a positive control
      proving non-empty on a resolvable directory), `:1597-1631` (`phase-start 6` exits 0 with no
      marker warning when the data dir is unresolvable), and `wave8-smoke.sh:2536` /`:2557`
      (`EDMV4-T11 AC9`: exit 0, empty stdout, empty stderr, with a jq-spy positive control proving
      the zero-count is not vacuous).
- [x] **AC10**: `edm_project_key()` resolution order and pure-bash `/`-and-`.` encoding -- verified
      at `_edm-datadir-lib.sh:113-126` (`CLAUDE_PROJECT_DIR` -> `git rev-parse --show-toplevel` ->
      `pwd`, then `${dir//\//-}` and `${key//./-}`, no `tr`); asserted at
      `wave8-smoke.sh:1695-1701`, which resolves the marker path from a subdirectory and compares
      it to the root-resolved path that `edm-state` actually wrote (`:1703`). See the P2 finding
      below: the assertion exercises the shared resolver rather than the `edm-gateguard` binary
      named in the AC. The two are the same code path by construction -- `bin/edm-gateguard:109`
      has no independent resolution -- so the substance holds.
- [x] **AC11**: all five lifecycle cases covered end to end -- `wave8-smoke.sh:1680-1859`:
      create-on-`phase-start 6` (`:1703`), remove-on-`phase-complete 6` (`:1765`),
      remove-on-`archive` (`:1784`), PREFIX-mismatch non-removal (`:1753`), SessionStart
      reconciliation in both directions (`:1827`, `:1840`).

**Findings**:
```
[P2] EDMV4-T12 | plugins/edm/bin/tests/wave8-smoke.sh:1558-1562 | AC#1: the smoke assertion must fail if edm_marker_path()'s body contains `$(`, a backtick, or a pipe | The assertion tests an external-binary name list instead; the body at _edm-datadir-lib.sh:137,139 does contain two `$(` substitutions, so the AC as literally worded is unmet. Literal compliance is unreachable without duplicating both resolvers inside edm_marker_path(), which this ticket's own Technical Notes forbid ("Do not fork a second resolution chain"). The substantive property -- no external binary exec on GateGuard's per-edit path -- IS verified, with a positive control at :1566-1570. Remediate as a spec amendment at the gate (restate AC1 as "invokes no external binary"), not as a code change.
[P1] EDMV4-T12 | plugins/edm/bin/_edm-datadir-lib.sh:84-110 | AC#8: a relative value at any step falls through with a stderr warning and a zero exit status | No stderr warning is emitted on a relative CLAUDE_PLUGIN_DATA or XDG_DATA_HOME -- the file contains no `>&2` at all. An operator who mis-sets either variable gets no signal and silently lands under ${HOME}. Add a one-line `echo "... [warn] ignoring relative <VAR>=<value>; falling through" >&2` to each of the two relative-value branches. This does not conflict with EDMV4-T17 AC1 (which forbids stderr at *source* time, not at call time) nor with T12 AC9's check_absent at wave8-smoke.sh:1630 (which matches the distinct string "Phase-6 marker").
[P2] EDMV4-T12 | plugins/edm/bin/tests/wave8-smoke.sh:1695-1701 | AC#10: a smoke test invokes the gate from a subdirectory and asserts it resolves the same marker path | The assertion sources the resolver directly rather than invoking `edm-gateguard`, because the gate did not exist when T12 landed. It does now (EDMV4-T11 merged). Tighten cheaply by running `edm-gateguard` from `subdir` and asserting the allow path; the resolver is shared (bin/edm-gateguard:109), so this is hardening, not a behavior gap.
```

### EDMV4-T18: Writable harvested delta and `get-patterns` read side, in one commit -- FAIL

- [ ] **AC1** (statically verifiable): three strictly additive write-target branches, **each
      asserted independently**, exit 0 in all three -- **FAIL on the test half**. The
      implementation is correct and complete: branch (a) at `bin/edm-state:5953-5969`, branch (b)
      at `:5971-5974`, branch (c) at `:5975-5980`, all reaching `return 0`. Only branch (a) is
      asserted (`wave8-smoke.sh:2226-2234`). No assertion for branch (b) or (c) exists anywhere in
      the suite: `grep -n "AC1(b)\|AC1(c)\|shipped tree\|not writable"` over `wave8-smoke.sh`
      returns one comment line and no assertion.
- [x] **AC2**: first write creates a stub with only the four Living-Library headings plus one
      provenance line; zero shared `###` entries with the seed -- verified at
      `bin/edm-state:5795-5812` (four headings at `:5807-5810`, provenance line at `:5806`, fourth
      heading per type at `:5781-5788`, matching `docs/audit-patterns/README.md:7-14` and every
      shipped seed's actual heading text). Asserted at `wave8-smoke.sh:2238-2245`, with a
      **positive control at `:2222-2223`** that fails the run if the shipped seed has zero `###`
      headings -- so the disjointness assertion cannot pass vacuously.
- [x] **AC3**: de-duplication against both the delta's and the seed's entry titles, using the
      existing normalization -- verified at `bin/edm-state:5875-5879` (the seed is scanned whenever
      `seed_file != pattern_file`) via the single-sourced `_pattern_collect_normalized_headings`
      (`:5820-5832`), which calls the existing `normalize_pattern_titles`. The delta direction is
      asserted at `wave8-smoke.sh:2247-2251`; the seed direction's smoke case is `EDMV4-T20` AC4's.
- [x] **AC4**: the fence-aware pre-flight is preserved unchanged, with both outcomes -- verified:
      `pattern_target_heading_for` and `pattern_insert_line_for` have no added or removed lines in
      commit `4e4b6ab`. Heading genuinely absent -> clean skip, exit 0 (`bin/edm-state:6021-6022`);
      heading only inside a fence -> loud `die` recording no `patterns_updates`
      (`bin/edm-state:6018-6019`); the under-lock re-check survives at `:5905-5907`.
- [x] **AC5**: `harvest-provenance.json` records a write count and a first-write ISO-8601 UTC
      timestamp under the same lock as the splice -- verified at `bin/edm-state:5842-5863`
      (`write_count` incremented, `first_write_at` set once via `//`), called at `:5915` from
      inside the body dispatched under `with_state_lock` at `:6053`. Asserted at
      `wave8-smoke.sh:2253-2258`.
- [ ] **AC6** (statically verifiable): `edm-state validate` gains an **informational** anomaly when
      the seed's mtime is newer than the delta's recorded first-write timestamp -- **FAIL**. No such
      anomaly exists. `grep -n "harvest\|first_write_at\|seed.*mtime"` over `bin/edm-state` returns
      hits only inside `_pattern_record_provenance` (`:5835-5855`); `state_anomalies()` carries
      nothing, and no `info`-class four-field emission for this condition exists. Self-reported gap
      confirmed accurate. Consequence: R3's exposure -- a plugin upgrade silently clearing the
      delta while `update-patterns` keeps reporting successful appends -- has a recorded signature
      (AC5) but no detector reading it.
- [ ] **AC7** (statically verifiable): three clauses -- **FAIL on one of three**.
      `patterns_updates` keeps its shape including `new_findings` and `extraction_status`
      (`bin/edm-state:6057-6061`) -- PASS. The `bin/` helper table lists `get-patterns` and the
      stated count matches the subcommands actually dispatched (`CLAUDE.md:1142` reads "40
      subcommands"; the dispatch `case` at `bin/edm-state:6630-6670` contains exactly 40 arms,
      counted mechanically) -- PASS. But the state-field table gains **no row for the new anomaly**
      and no C-4 absent behavior for it: `grep -n "harvest\|SEED_NEWER"` over `plugins/edm/CLAUDE.md`
      returns nothing. Dependent on AC6.
- [x] **AC8**: `get-patterns <type> --paths` prints exactly two absolute lines, second empty rather
      than absent, contract stated in the `EDM-HELP-BEGIN` block, type validated against the shared
      enum with the word-membership idiom -- verified at `bin/edm-state:6079-6096` (two unconditional
      `printf` at `:6094-6095`; `delta_file` stays empty unless the file exists, `:6092`), help
      contract at `bin/edm-state:53` inside the sentinels at `:10`/`:54`, validation at `:6084-6087`
      reusing `case " $PATTERN_AUDIT_TYPE_ENUM_LIST "`. Asserted at `wave8-smoke.sh:2207-2218`,
      which correctly counts lines from a re-run pipe rather than a `$()` capture (the trailing-
      newline-stripping trap is called out in its own comment at `:2208-2210`).
- [x] **AC9**: four skills resolve and interpolate both paths; four agents read two explicit paths,
      seed first, each with one merge-order sentence citing `docs/audit-patterns/README.md`, none
      carrying its own de-duplication rule -- verified: `skills/srd/SKILL.md:169-171` + `:181`,
      `skills/tickets/SKILL.md:121-123` + `:135`, `skills/implement/SKILL.md:83-88` + `:97-98`,
      `skills/test-coverage/SKILL.md:40-42` + `:55-56`; agents `edm-srd-writer.md`,
      `edm-ticket-writer.md`, `edm-implementer.md`, `edm-test-coverage-auditor.md` all rewritten in
      `4e4b6ab` to read seed-then-delta with an Append-Schema reference and no de-dup rule.
      Asserted at `wave8-smoke.sh:2289-2297`.
- [ ] **AC10** (statically verifiable in two clauses; one runtime clause): **FAIL**. "No agent gains
      a new tool grant" holds and is asserted (`wave8-smoke.sh:2300-2304`; `edm-srd-writer.md` and
      `edm-ticket-writer.md` still carry no `Bash`). But `bin/edm-check-grants` gained **no**
      assertion that every launch template spawning one of the four pattern-reading agents carries
      both interpolated paths: `grep -n "pattern\|SEED\|DELTA\|get-patterns"` over
      `bin/edm-check-grants` returns only five unrelated hits. Risk R8/R7 -- a skill edit silently
      leaving an agent reading nothing -- stays open. Self-reported gap confirmed accurate. The
      third clause's smoke test (an agent handed an empty second path reads only the seed and
      proceeds with no error and no warning) is also absent; its behavioral half is agent-runtime
      and cannot be closed by a smoke assertion, but the agents' own prose does carry the guard
      ("if its path is non-empty and the file exists").
- [x] **AC11**: **one commit** contains the write-target change, the stub writer, the `get-patterns`
      subcommand and its dispatch arm, the four agent read-site edits and the four skill
      interpolation edits -- verified. `4e4b6ab` is the only `EDMV4-T18` commit in the repository
      (`git log --all --grep=T18` returns one, the rest being EDMV3). Its 11 files are
      `bin/edm-state` (write side, `cmd_get_patterns`, dispatch arm), the four agents, the four
      skills, `CLAUDE.md` and `wave8-smoke.sh`. The single-commit constraint is restated in bold in
      the ticket's own Description. The WIP-amend approach preserved the constraint correctly --
      there is no split, and R9's failure mode cannot be reintroduced by reverting one half.
- [x] **AC12**: coupling enforced three ways -- (a) `tickets/README.md:455-457` maps `EDMV4-14`,
      `EDMV4-15` and `EDMV4-16` all to `EDMV4-T18`, and `:121` carries the same mapping in the
      ticket row; (b) the end-to-end test at `wave8-smoke.sh:2261-2268` drives `update-patterns` ->
      `get-patterns` -> two real reads in one process and asserts the harvested finding is in the
      concatenation; (c) the retained negative test at `:2270-2275` asserts a seed-only read never
      sees it, explicitly labelled RETAINED and tied to R9. AC12(b)'s "with the shipped tree made
      read-only" is not literally staged, but branch (a) is taken unconditionally whenever the data
      directory resolves, so the write demonstrably lands in the delta
      (`wave8-smoke.sh:2231-2234`, `:2254`) and the clause's purpose is met.

**Findings**:
```
[P1] EDMV4-T18 | plugins/edm/bin/tests/wave8-smoke.sh:2226-2234 | AC#1: a smoke test asserts each of the three branches independently and asserts exit status 0 in all three | Only branch (a) is asserted. Branches (b) (shipped tree writable) and (c) (neither writable -- warn to stderr and return 0) have no assertion anywhere in the suite, so a future edit can break either silently. The self-report that "the three-branch write matrix is EDMV4-T20's scope" is inaccurate: EDMV4-T20's own Technical Notes justify its S sizing on the premise that "EDMV4-T18 has already landed the three-branch degradation test". Add two cases -- force edm_data_dir() empty with a writable shipped-tree copy, and force both unwritable -- asserting rc=0 in each.
[P1] EDMV4-T18 | plugins/edm/bin/edm-state (state_anomalies) | AC#6: edm-state validate gains an informational anomaly when the seed's mtime is newer than the delta's recorded first_write_at | Not implemented. Emit it in the canonical four-field form `<class>  <CODE>  <affected-field>  <description>` with <class> literally `info`, and add the smoke case asserting a state whose only anomaly is this one still exits 0 from validate. Without it, AC5's provenance record has no reader and R3 stays unobservable.
[P1] EDMV4-T18 | plugins/edm/CLAUDE.md (state-field table) | AC#7: the state-field table gains a row for the new anomaly stating its C-4 absent behaviour | No such row exists. Dependent on AC6 -- add it in the same change. The other two AC7 clauses (patterns_updates shape; bin/ table lists get-patterns with the count at 40, matching the 40 dispatched arms) both pass.
[P1] EDMV4-T18 | plugins/edm/bin/edm-check-grants | AC#10: edm-check-grants gains an assertion that every skill launch template spawning one of the four pattern-reading agents carries both interpolated paths | Not implemented -- the script has no pattern-path detector at all. wave8-smoke.sh:2289-2297 checks the four skills, but that is a suite assertion, not the grants checker the AC names, and R8/R7 (a skill edit silently leaving an agent reading nothing) is what edm-check-grants exists to catch. Also missing: the smoke case for an agent handed an empty second path (its behavioral half is agent-runtime and cannot be fully closed statically).
```

### EDMV4-T22: Materialize lenses, derive round_type from the union rule -- PASS

- [x] **AC1**: `--lenses` omitted records the full `ALL_LENS_IDS` list in `ALL_LENS_IDS` order --
      verified at `bin/edm-state:4740-4749` (`:4743` replaces the former `lenses_json="[]"`);
      asserted directly against the state file at `wave6-smoke.sh:3657-3668` (length 14, exact
      order `L1..L14`, `round_type` still `full`).
- [x] **AC2**: the same materialization for `srd` and `tickets` rounds -- same code path (the branch
      is type-agnostic); asserted at `wave6-smoke.sh:3672-3689`, both recording `full`.
- [x] **AC3**: `--na-lenses <csv>`, same normalization as `--lenses`, either flag order -- verified:
      the shared `_normalize_lens_csv` at `bin/edm-state:4663-4665` is used by both parsers
      (`:4746`, `:4760`), and the `while`/`case` loop at `:4707-4727` accepts either order, each
      flag at most once; asserted at `wave6-smoke.sh:3693-3711` in both orders.
- [x] **AC4**: `full` iff `(lenses UNION lenses_na) == ALL_LENS_IDS` with `lenses_na` a subset of
      `CONDITIONAL_LENS_IDS`, evaluated uniformly, no branch hardcoding `full` -- verified at
      `bin/edm-state:4779-4786`: a single `jq` union/sort/compare runs after both branches converge,
      and the subset check `die`s earlier at `:4762-4768`. Asserted at `wave6-smoke.sh:3715-3719`.
- [x] **AC5**: `--na-lenses` naming a non-conditional lens is a hard `die` naming the offending ID,
      writing no round record -- verified at `bin/edm-state:4764-4767`, which runs before
      `with_state_lock` is acquired at `:4792`; asserted at `wave6-smoke.sh:3723-3730`, including a
      before/after round-count comparison proving nothing was written.
- [x] **AC6**: pass-7 regression replay -- `wave6-smoke.sh:3737-3753` builds a real fixture
      (manifest listing 14 IDs, zero `lens-L{N}.jsonl`), starts the round with `--lenses` omitted,
      asserts 14 materialized lenses, asserts the CA-471 message fires, and asserts the round closes
      `partial`. This is a behavioral replay against real files, not a structural check.
- [x] **AC7**: `--na-lenses` omitted produces `lenses_na: []`; the T27 fixtures' derived
      `round_type` is asserted, never byte-identity -- `wave6-smoke.sh:3759-3778`. Every assertion
      is on the derived `round_type` (or on `lenses_na | length`), and the deliberate all-eleven ->
      `partial` reversal is documented in place at `:3770-3775` as `EDMV4-T30`'s to reconcile.
- [x] **AC8**: `lenses_na` written alongside `lenses` in the same `_rmw_state_body` write under the
      existing lock -- verified at `bin/edm-state:4681-4690` (one object literal at `:4687`), lock
      acquired once at `:4792`; asserted at `wave6-smoke.sh:3782-3785`.
- [x] **AC9**: `audit-round-start` is the sole writer; completion accepts no N/A declaration --
      verified at `bin/edm-state:4757-4769` (the only assignments) and by the structural scan at
      `wave6-smoke.sh:3795-3822`, whose function boundaries are derived by `awk` from symbol names
      rather than hand-maintained line ranges, and which deliberately anchors on two literal *write*
      shapes so it cannot self-match `LENS_READ_JQ_DEF`'s `read_round_lenses_na` declaration
      (rationale in place at `:3788-3794`). Behavioral half at `:3827-3829`: `audit-round-complete`
      refuses any extra token. See the P2 hardening finding below.
- [x] **AC10**: both C-4 read rules -- `LENS_READ_JQ_DEF` at `bin/edm-state:4677` implements (a) the
      empty-plus-`full` substitution and (b) the `lenses_na // []` default in one shared def.
      Asserted at `wave6-smoke.sh:3840-3844` (substitution returns 14) with **two discriminating
      controls** at `:3848-3857` (a `partial` round with real lenses passes through unchanged; a
      `full` round with non-empty lenses is not substituted either), and at `:3860-3868` for (b)
      with its own control. `schema_version` is not bumped -- neither T22 commit touches it, and
      `CLAUDE.md`'s `lenses_na` row states the non-bump explicitly -- and no existing state file is
      rewritten in place (every reader coerces via `coerce_round_entry`). Backstop-integration
      clause adjudicated above; recorded as `[NOTED]`.
- [x] **AC11**: an untyped stack with `--na-lenses` omitted records `partial` and `audit-converged`
      refuses -- `wave6-smoke.sh:3872-3886`: 13-of-14 records `partial`, and `audit-converged` exits
      1 even against a clean findings ledger.
- [x] **AC12**: `CLAUDE.md` gains a `lenses_na` row with type, default, purpose and C-4 absent
      behaviour, and both C-4 rules are documented together -- verified in `2395aa8`: the
      `round_type` row carries the lenses C-4 read rule and the new `lenses_na` row carries the
      `lenses_na` C-4 read rule, adjacent in the same mode-family table; asserted at
      `wave6-smoke.sh:3890-3895`.

**Findings**:
```
[NOTED] EDMV4-T22 | plugins/edm/bin/edm-state:4677 | AC#10(a): a smoke test ... asserting the EDMV4-T23 backstop requires the full JSONL set rather than passing vacuously | The read rule is delivered as a shared primitive and proven directly against fixture round records with two discriminating controls (wave6-smoke.sh:3840-3857). The backstop-routed form of the assertion is duplicated verbatim as EDMV4-T23 AC2, is excluded by EDMV4-T22's own Out of Scope, and is unwritable today because the backstop still iterates lenses-run.txt -- a T22-era version would assert nothing. No remediation against T22. ACTION FOR THE T23 AUDITOR: EDMV4-T23 AC2 is now the sole home of this assertion; if T23 ships without it, the C-4 read rule has no consumer-side proof anywhere.
[P2] EDMV4-T22 | plugins/edm/bin/tests/wave6-smoke.sh:3809-3822 | AC#9: a smoke assertion greps bin/edm-state and fails if any write-shaped lenses_na occurrence appears outside the two functions | The zero-count assertion has no positive control proving its two greps still match anything. If `lenses_na_json=` were renamed, both greps would return empty, t22ac9_outside would be 0, and the sole-writer guarantee would pass vacuously -- the exact class this suite has been bitten by five times. The scan is otherwise well built (awk-derived ranges, deliberately non-self-matching). Add one assertion that the collected site list is non-empty before range-filtering. AC8's behavioral test is a partial backstop, so this is hardening, not a behavior gap.
```

### EDMV4-T32: Grow the code-audit fixtures from 11 to 14 lens pairs -- FAIL

- [x] **AC1**: 14 `lens-L{N}.jsonl` and 14 `lens-L{N}.md`, `L1`-`L14`, and `lenses-run.txt` lists
      all 14 IDs one per line under the existing `Round type: full` header -- verified by directory
      listing and by reading `fixtures/code-audit/lenses-run.txt` (header plus `L1`..`L14`).
- [x] **AC2**: `fixtures/code-audit/README.md:33` documents fourteen lens IDs and the `lens-L11`
      references at `:21`, `:26`, `:28` now read `lens-L14` -- verified at exactly those four lines.
- [ ] **AC3** (statically verifiable): a **new** fixture providing the 13-plus-N/A composition (13
      lens pairs with no `L13`, a `lenses-run.txt` carrying 13 IDs plus a `Lenses N/A:` header, and
      a round record with `lenses_na: ["L13"]`) -- **FAIL**. No such fixture exists.
- [ ] **AC4** (statically verifiable): a **negative** fixture providing the contract-violation case
      (`lenses_na: ["L13"]` with a `lens-L13.jsonl` present on disk) -- **FAIL**. No such fixture
      exists.
- [x] **AC5**: every new JSONL line conforms to the fixed schema exactly as the existing eleven do;
      `jq empty` exits 0 -- verified: `jq empty` returns 0 for `lens-L12/13/14.jsonl`, and each
      line's `keys_unsorted` is byte-identical to the reference `lens-L2.jsonl`
      (`schema,id,lens,round,round_type,sev,confidence,file,line,title,status`).
- [x] **AC6**: two findings per new file (one `open`, one `NOTED`), each with a matching prose entry
      -- verified: `L12`/`L13`/`L14` each carry one `open` plus one `noted` line, and each sibling
      `.md` carries the matching `L{N}-001` / `L{N}-002` rows in the same order.
- [x] **AC7**: all fixture content is ASCII-only -- verified two ways:
      `edm-lint-artifacts --path plugins/edm/bin/tests/fixtures/code-audit/` reports
      `CLEAN (no violations found)`, and an `LC_ALL=C` scan for bytes outside tab/space/printable
      over all six new files plus `lenses-run.txt` and `README.md` matches nothing.
- [x] **AC8**: the fixture side of `wave7-smoke.sh`'s T24 AC0 counts -- 14 files of each kind are on
      disk, so the assertions pass the moment their `-eq 11` literals are retargeted. Those two
      sites belong to `EDMV4-T30` AC3 (they appear in its explicit nine-site `-eq 11` list), T30's
      Out of Scope states they "will stay red until [the fixtures] land", and T32's own Out of Scope
      excludes "the smoke assertions that consume the fixtures". Recorded as `[NOTED]`; not reported
      as a T32 defect.
- [x] **AC9**: `lens-L1.jsonl` keeps its widest-fixture role -- verified: it still carries `P0 open`,
      `P1 open`, `P2 open`, `NOTED noted`, plus the `fixed` and legacy `deferred` lines the re-open
      path depends on. The three new files add only `open`/`noted` and disturb nothing.

**Findings**:
```
[P1] EDMV4-T32 | plugins/edm/bin/tests/fixtures/code-audit/ | AC#3: a new fixture provides the 13-plus-N/A composition (13 lens pairs, no L13, lenses-run.txt with the 13 IDs plus a `Lenses N/A:` header, round record with lenses_na: ["L13"]) | Not created. The deferral rationale is now stale: EDMV4-T22 landed (fd9b6d5, 2395aa8), cmd_audit_round_start writes lenses_na at bin/edm-state:4687, and the exact round-record shape is producible today -- wave6-smoke.sh:3693-3701 already generates and asserts it, so it can be copied from real output rather than guessed, exactly as the ticket's Technical Notes require. BLOCKS EDMV4-T23 AC11's clean 13-of-14 N/A case; remediate before wave 3 dispatch.
[P1] EDMV4-T32 | plugins/edm/bin/tests/fixtures/code-audit/ | AC#4: a negative fixture provides the contract-violation case -- lenses_na: ["L13"] with a lens-L13.jsonl present on disk | Not created. Same stale deferral. BLOCKS EDMV4-T23 AC4, whose third downgrade reason this ticket exists to exercise "against real files rather than a synthesized path" -- without it T23 AC4 can only be tested through a synthesized path, which is the weaker form its own AC text rejects. Remediate before wave 3 dispatch.
[NOTED] EDMV4-T32 | plugins/edm/bin/tests/wave7-smoke.sh:1634-1638 | AC#8: the T24 AC0 assertions count 14 files each and pass | Still `-eq 11` and red, but these two sites are EDMV4-T30 AC3's (named in its nine-site list) and T32's own Out of Scope excludes the consuming assertions. The fixture side is complete, so both assertions go green as soon as T30 retargets the literals. No remediation against T32.
```

## Remediation Required

Ordered by severity, then by blocking effect on wave 3.

1. **[P1] `EDMV4-T32` AC3 and AC4** -- author the two missing fixtures under
   `plugins/edm/bin/tests/fixtures/code-audit/`. These are the only findings in this shard that
   block scheduled downstream work: `EDMV4-T23` AC4 and AC11 both consume them, and T23's own Out
   of Scope names T32 as the supplier. The blocking precondition (a `lenses_na` shape to copy) no
   longer exists -- copy the round record from `wave6-smoke.sh:3693-3701`'s real output.
2. **[P1] `EDMV4-T18` AC6 + AC7** -- add the `info`-class seed-newer-than-delta anomaly to
   `state_anomalies()` in `plugins/edm/bin/edm-state`, in the canonical four-field form, with the
   smoke case asserting `validate` still exits 0; then add the matching state-field row with its
   C-4 absent behaviour to `plugins/edm/CLAUDE.md`. These two land together. Until they do, AC5's
   provenance record has no reader and R3 is unobservable.
3. **[P1] `EDMV4-T18` AC10** -- add the both-paths-interpolated assertion to
   `plugins/edm/bin/edm-check-grants` for the four pattern-reading agents' launch templates. This
   is the R8/R7 guard; a suite assertion in `wave8-smoke.sh` is not the surface the AC names.
4. **[P1] `EDMV4-T18` AC1** -- add independent smoke assertions for write-target branches (b) and
   (c) in `wave8-smoke.sh`, each asserting exit status 0. Do not defer to `EDMV4-T20`: that
   ticket's S sizing is explicitly justified on this test already existing.
5. **[P1] `EDMV4-T12` AC8** -- emit a stderr warning on the relative-value fall-through in both
   branches of `edm_data_dir()` (`plugins/edm/bin/_edm-datadir-lib.sh:87-100`).
6. **[P2] `EDMV4-T12` AC1** -- resolve the AC-versus-Technical-Notes contradiction at the gate.
   Recommended direction is a spec amendment restating AC1 as "invokes no external binary", since
   literal compliance requires the duplicated resolution chain the same ticket forbids.
7. **[P2] `EDMV4-T22` AC9** -- assert the collected `lenses_na` write-site list is non-empty before
   range-filtering, so the sole-writer scan cannot pass vacuously after a rename.
8. **[P2] `EDMV4-T12` AC10** -- now that `bin/edm-gateguard` exists, invoke it from the
   subdirectory in the existing assertion instead of sourcing the resolver.

`[NOTED]` findings are not remediated here. The `EDMV4-T22` AC10 note carries a live action for
whoever audits `EDMV4-T23`: AC2 of that ticket is now the sole home of the backstop-routed C-4
assertion.

<!-- QC-SHARD-COMPLETE range=EDMV4-T12..EDMV4-T32 assigned=4 audited=4 -->
