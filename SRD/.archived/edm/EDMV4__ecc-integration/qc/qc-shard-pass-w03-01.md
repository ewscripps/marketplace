# QC Audit Report: EDMV4 -- ECC Integration, Wave 3 [Shard 1/2]

**Date**: 2026-09-03
**Tickets audited**: `EDMV4-T13`, `EDMV4-T19`, `EDMV4-T20`, `EDMV4-T23`, `EDMV4-T24` (5 assigned, 5 audited)
**Audit target**: branch tip `edm/edmv4-ecc-integration` @ `0d099e9`, main working tree
**Mode**: `implementation_mode=standard` -- the TDD compliance pass does not run.

Suites re-run by this auditor on the merged tree: `wave6-smoke.sh` **789 passed / 0 failed**,
`wave8-smoke.sh` **507 passed / 0 failed**. Both match the orchestrator's baseline. `run-all.sh`
was not run, per instruction.

## Summary

| Ticket | Title | Verdict |
|---|---|---|
| `EDMV4-T13` | Route every GateGuard decision through one `emit_decision` with two back-ends | **PASS** |
| `EDMV4-T19` | Correct the stale caller-count comment in `cmd_update_patterns` | **PARTIAL** |
| `EDMV4-T20` | Lay regression coverage over every branch of the 4.2 write and read paths | **FAIL** |
| `EDMV4-T23` | Teach the CA-471 completeness backstop to distinguish N/A from missing JSONL | **FAIL** |
| `EDMV4-T24` | Make code-audit Step 1 the sole authority for L13 applicability | **FAIL** |

Three FAILs, one P1 each on `T20`/`T24` and one P1 plus two P2 on `T23`. Two PARTIALs recorded to
`partial_verdict_map` (`EDMV4-T19`, `EDMV4-T20`), both the same runtime question: a green
`run-all.sh`.

## Detailed Findings

### EDMV4-T13: one `emit_decision` with two back-ends -- PASS

All 9 acceptance criteria verified. The assertion block (`bin/tests/wave8-smoke.sh:3301-3518`)
carries real positive controls on its two zero-count checks, so neither is vacuous.

- [x] AC1: `emit_decision` defined exactly once -- `bin/edm-gateguard:170`; assertion
      `wave8-smoke.sh:3329-3346` counts `exit 2` and `permissionDecision` outside the function's
      line range, with a positive control at `:3348-3357` that injects both and confirms the
      detectors fire.
- [x] AC2: `bin/edm-gateguard:194-196` builds the payload with `jq -cn` (`-c` is load-bearing --
      jq's default pretty-print would not match the single-line literal); `wave8-smoke.sh:3396-3415`
      compares the emitted string byte-for-byte and asserts empty stdout/stderr on allow.
- [x] AC3: `bin/edm-gateguard:199-202` -- plain text to stderr, `exit 2`; `wave8-smoke.sh:3417-3433`.
- [x] AC4: `bin/edm-gateguard:175-180`; `wave8-smoke.sh:3435-3452`. **Independently re-verified
      against the shipped binary** by this auditor (marker present, `{"tool_name":"Edit"}` on stdin,
      `EDM_GATEGUARD_DENY_MODE=yes`): `rc=1`, empty stdout, stderr
      `edm-gateguard: EDM_GATEGUARD_DENY_MODE must be 'json' or 'exit-code' (got: 'yes')`.
- [x] AC5: no `exit 1` inside `emit_decision`'s body (`wave8-smoke.sh:3359-3371`, with positive
      control); setup errors route through `die()` at `bin/edm-gateguard:71-75`, default code 1.
- [x] AC6: `EDM_GATEGUARD_DENY_MODE_DEFAULT="json"` at `bin/edm-gateguard:159`, pinned by
      `wave8-smoke.sh:3375-3376`. Matches `decisions.md` D26 exactly.
- [x] AC7: `wave8-smoke.sh:3459-3466`, `jq -e '.hookSpecificOutput.permissionDecision == "deny"'`.
- [x] AC8: `wave8-smoke.sh:3468-3488` -- embedded double quote, embedded newline **and** backslash,
      each asserted to parse under `jq -e .` and to round-trip through
      `.permissionDecisionReason` unchanged.
- [x] AC9: ASCII check at `wave8-smoke.sh:3490-3497`; `edm-check-vocabulary` at `:3499-3501`.

**`MultiEdit` posture is conservative and correct.** `bin/edm-gateguard:154-156` records
`MultiEdit` as UNTESTABLE on the Spike B host and explicitly "not evidence either way"; the
`MultiEdit` case arm at `:227-230` is an unwired extension point. No assertion in this ticket's
range claims `MultiEdit` denial works. This matches `decisions.md` D26 and does not disturb the
open `EDMV4-T07` PARTIAL.

### EDMV4-T19: count-free CA-476 comment -- PARTIAL

The count-free wording was the option the ticket itself preferred, and AC1 offers it explicitly as
a legal choice ("the count-free wording is preferred and the choice is stated in the commit
message"). It satisfies AC1 as written.

- [x] AC1: `bin/edm-state:6158` now reads "called mid-phase by the audit and implementation
      skills" -- verbatim the phrasing AC1 names. Commit `48025c1` states the choice: "Reworded to
      state the property that matters instead of a maintained count".
- [x] AC2: six call sites re-verified live at audit time, not copied: `skills/audit-srd/SKILL.md:87`,
      `skills/audit-tickets/SKILL.md:94`, `skills/code-audit/SKILL.md:158`,
      `skills/implement/SKILL.md:64`, `skills/test/SKILL.md:132`,
      `skills/test-coverage/SKILL.md:108`. Exactly six files in the whole `skills/` tree carry an
      `edm-state update-patterns <PREFIX>` invocation, and they are the six files AC2 names.
      `wave8-smoke.sh:2589-2600` re-greps each at test time.
- [x] AC3: substantive point intact at `bin/edm-state:6158-6159`; asserted `wave8-smoke.sh:2572-2573`.
- [x] AC4: `docs/audit-patterns/README.md:84-85` corrected identically in the same commit;
      `wave8-smoke.sh:2602-2612` asserts both the absence of "four skills" and the presence of the
      replacement, newline-normalized so the file's own hard wrap cannot break the match.
- [x] AC5: `git show 48025c1 -- plugins/edm/bin/edm-state` is exactly two changed comment lines,
      zero executable lines; `bash -n` asserted at `wave8-smoke.sh:2615-2619`.
- [x] AC6: number-word tripwire at `wave8-smoke.sh:2575-2587` (`grep -qiw four` / `six` over the
      extracted block). Not vacuous on an empty extraction, because AC1/AC3's two `check`s on the
      same variable fail first if the awk range match returns nothing.
- [ ] AC7: **runtime-check** -- `bash plugins/edm/bin/tests/run-all.sh` cannot be shown green
      today. The static half of AC7 *is* verified: no assertion anywhere in `bin/tests/` depends on
      the old comment text (the only `four skills` hits are `wave8-smoke.sh:2609-2610`, which is
      T19's own `check_absent`, and `wave7-smoke.sh:2220/2227`, an unrelated T42 canonical-sections
      assertion).

**Finding**: [PARTIAL] EDMV4-T19 | AC#7: runtime-check: re-run `bash plugins/edm/bin/tests/run-all.sh`
once `EDMV4-T26` has landed and the ~35 wave7 assertions stale against `EDMV4-T18` have an owner;
confirm a green aggregate. Recorded via `edm-state record-partial-verdict`.

**Note on the ticket text, not the implementation**: AC2's six `file:line` citations have all
drifted except `skills/test/SKILL.md:132` (`implement` is now `:64` not `:46`; `code-audit` `:158`
not `:135`; `audit-tickets` `:94` not `:52`; `audit-srd` `:87` not `:50`; `test-coverage` `:108`
not `:65`). AC2's own second sentence anticipates this and mandates re-checking by grep rather than
copying, which is what both the implementation and this audit did. No action required.

### EDMV4-T20: regression coverage over the 4.2 write and read paths -- FAIL

**The three write branches are each genuinely exercised, not merely named.** This was the specific
risk flagged for this shard, and it does not materialize: each branch drives a real
`edm-state update-patterns` invocation under a different environment and asserts a
branch-distinguishing outcome.

- [x] AC1 -- branch (a): `wave8-smoke.sh:2636-2677`. Writable `CLAUDE_PLUGIN_DATA`; asserts the
      delta at `${data}/patterns/code-audit.md` exists, that the four Living-Library headings appear
      in ascending line order, and that `CA-9001` is spliced under `## Anti-Patterns` (the default
      target, `docs/audit-patterns/README.md:16`).
- [x] AC2 -- branch (b): `wave8-smoke.sh:2686-2724`. `edm_data_dir()` forced empty by a `chmod 555`
      ancestor over all three candidates, against a `cp -R` scratch copy of the plugin tree; asserts
      the finding lands in the shipped `docs/audit-patterns/srd-audit.md` and that
      `patterns_updates.srd` still carries `new_findings==1`, `extraction_status=="ok"`,
      `extracted_titles` and `updated_at`.
- [x] AC3 -- branch (c): `wave8-smoke.sh:2726-2785`. Both the data dir *and* the copied
      `docs/audit-patterns/` made unwritable; asserts exit 0, a warning naming the actual
      unwritable path, and SHA-256 equality of the target file before and after.
- [x] AC4: `wave8-smoke.sh:2787-2820`, with an explicit positive control at `:2800-2805` proving the
      shipped seed still carries the title the fixture reuses -- without it the dedup assertion
      would prove nothing.
- [x] AC5: `wave8-smoke.sh:2679-2684` -- second run over the same fixture, `### CA-9001` counted at
      exactly 1.
- [x] AC6: `wave8-smoke.sh:2822-2851`. `wc -l` is piped directly from the command's own stdout in
      both cases (never from a `$()` capture, which would strip the trailing newline and misreport a
      genuinely empty second line), for both the no-delta and unresolvable-data-dir cases.
- [x] AC7: `wave8-smoke.sh:2853-2895` -- fence-only target heading, non-zero exit, both message
      substrings, SHA-256 equality of the delta.
- [ ] AC8: **FAIL**. The discovery half passes (`wave8-smoke.sh:2901-2904` runs the identical
      `find -maxdepth 1 -name '*-smoke.sh'` invocation `run-all.sh:45` uses, and `run-all.sh:32-34`
      confirms a discovered-but-unlisted suite still runs). The registration half does not: AC8 says
      "Assert the registration is *present*; if it is not, that is a defect against `EDMV4-T53`",
      and `wave8-smoke.sh:2906-2912` instead emits a bare `echo "  NOTE: ..."` on the absent branch.
      No `fail` is ever called, so the assertion cannot fail. And the registration **is** absent
      today: `run-all.sh:39` `_PREFERRED_ORDER` does not list `wave8-smoke.sh`, and `run-all.sh:96`
      `_MIN_SUITE_COUNT` is still `7` against 8 existing suites -- so deleting `wave8-smoke.sh`
      right now leaves the aggregate green, which is exactly the tripwire the constant exists to be
      (this ticket's own Technical Notes say so).
- [x] AC9 (first clause): every case runs against scratch `HOME` / `CLAUDE_PLUGIN_DATA` /
      `XDG_DATA_HOME`; `wave8-smoke.sh:2632` / `:2917-2922` diff `git status --porcelain` across the
      section. The relaxation from "empty" to "unchanged" is documented at `:2627-2631` and is the
      right call -- a bare emptiness check would fail on any tree with legitimate uncommitted work,
      while before/after still catches real leakage.
- [ ] AC9 (second and third clauses): **runtime-check** -- `run-all.sh` green from a clean tree, and
      twice in a row producing the same result.

**Finding**: [P1] EDMV4-T20 | plugins/edm/bin/tests/wave8-smoke.sh:2906-2912 | AC#8: the
registration check is an `echo "  NOTE: ..."`, not an assertion -- no code path calls `fail`, so it
can never turn the suite red. AC8 explicitly requires "Assert the registration is *present*".
Replace the `else` branch with `fail`. It will go red immediately, and that is the intended
outcome: it routes the live gap to `EDMV4-T53` AC2 rather than leaving it invisible.

**Finding**: [PARTIAL] EDMV4-T20 | AC#9: runtime-check: run `bash plugins/edm/bin/tests/run-all.sh`
twice consecutively from a clean tree and confirm both runs are green and identical. Recorded via
`edm-state record-partial-verdict`.

**Sizing self-report confirmed.** T20 is genuinely M, not S. Its S estimate rested on
`EDMV4-T18` having already landed the three-branch degradation test; T18 asserted branch (a) only.
T20 built all three from scratch (~300 lines across `wave8-smoke.sh:2621-2924` plus three fixtures
under `bin/tests/fixtures/patterns/`). The mutual assumption between T18 and T20 was caught and
closed here rather than shipping as a hole.

### EDMV4-T23: state-authoritative CA-471 backstop -- FAIL

**AC2 is not vacuous.** This was the highest-priority check for this shard, and the assertion holds
up under adversarial reading. `wave6-smoke.sh:4004-4034` starts a round with `--lenses L1`,
hand-patches the record to the legacy `lenses:[]` + `round_type:"full"` shape, writes a
`lenses-run.txt` containing **only** the line `Round type: full` (deliberately no lens IDs), lands
**zero** JSONL, and asserts a `CA-471` warning plus `round_type == "partial"`. Two independent
wrong implementations both make it fail: reading the literal empty `lenses` array requires zero
files (stays `full`), and iterating the manifest yields zero `^L[0-9]+$` matches (also stays
`full`). Only a state read *with* the C-4 substitution produces the downgrade. It is paired with a
positive control at `:4036-4059` -- same legacy shape, all 14 JSONL landed, must stay `full` --
which rules out a gate that always downgrades.

- [x] AC1: `bin/edm-state:4959-4961` reads `lenses`/`lenses_na` from `$last_round` through
      `read_round_lenses($all)` / `read_round_lenses_na`; the manifest's content is no longer parsed
      at all (`:4900-4909` documents the retirement of the CRLF/trailing-newline defensive parsing
      along with it).
- [x] AC2: see above. `wave6-smoke.sh:4004-4059`.
- [x] AC3: `bin/edm-state:4969` -- `[[ ! -s "$_lens_file" ]] || ! jq empty "$_lens_file"`, unchanged
      in substance.
- [x] AC4: `bin/edm-state:4978-4990`; `wave6-smoke.sh:4061-4083` runs the real
      `fixtures/code-audit/na-l13-contract-violation/` fixture and asserts both the N/A-disagreement
      message and the `agents/edm-test-integration.md:21-25` citation.
- [x] AC5: `bin/edm-state:4994` scopes check 3 to `_recorded_round_type == "full"`. Confirmed live by
      this auditor -- see the AC11 finding below for the exact reproduction.
- [x] AC6: `wave6-smoke.sh:4106-4123` -- `--lenses L1,L9,L11` run to completion, asserted to emit
      neither "coverage incomplete" nor any `CA-471` string at all.
- [x] AC7 (implementation): three distinct prefixes at `bin/edm-state:4974` ("lens JSONL
      missing/empty/unparseable for:"), `:4988` ("lens JSONL present for lens(es) declared N/A"),
      `:5004` ("lens coverage incomplete:"). Reasons 1 and 2 are asserted against real captured
      output (`wave6-smoke.sh:4126-4129`); reason 3 is asserted only against the source text
      (`:4135-4136`) -- see AC11.
- [ ] AC8: **FAIL (P2)**. `wave6-smoke.sh:4138-4143` asserts only that the second
      `audit-round-complete` exits non-zero. AC8 says "exits non-zero **and mutates nothing**", and
      the mutation half is never asserted, even though `_harness.sh` ships `check_state_unchanged`
      for exactly this. The property itself is sound -- `bin/edm-state:4865-4867` and `:4878` put
      the double-completion decision inside the single `with_state_lock` acquisition, before any
      write -- so this is a test-coverage gap, not a behavior defect.
- [x] AC9: `bin/edm-state:4955` gates on `[[ -n "$_pass_dir" && -f "$_manifest" ]]`, so both cases
      AC9 names (no pass directory; pass directory but no manifest) are covered by the same
      conjunct. `wave6-smoke.sh:4145-4155` exercises the first.
- [ ] AC10: **FAIL (P2)**. `decisions.md:53` records the gap and the acceptance rationale in full,
      and carries a bolded `**Named follow-on**:` label -- but names no follow-on. Its content is a
      list of prerequisites ("a future ticket that wants to close this gap must first define...")
      with no ticket ID and no reserved initiative prefix. Wave-1 QC set this initiative's own
      standard when it failed `EDMV4-T05` AC9 for the identical shape and required an actual name
      (`EVALB`, prefix verified free).
- [ ] AC11: **FAIL (P1)**. AC11 requires smoke tests covering **all three** downgrade reasons.
      Reasons 1 and 2 are covered by executing cases. Reason 3 is not executed anywhere in the tree
      -- `grep -rn "coverage incomplete" bin/tests/` returns only `wave6-smoke.sh:4121` (a
      `check_absent`), the explanatory comment at `:4130-4134`, and the source grep at `:4135-4136`.
      A source grep proves the string exists in `bin/edm-state`; it cannot detect an inverted or
      broken `$union == $allsorted` condition, which is precisely what a regression here would look
      like. The stated justification at `:4130-4134` -- that triggering reason 3 "requires
      simulating `ALL_LENS_IDS` growing between round-start and completion, which... this suite
      cannot safely mutate mid-run" -- is factually wrong. The other four required AC11 cases are
      covered: clean 13-of-14 N/A (`wave6-smoke.sh:4085-4104`), `--lenses L1,L9,L11`
      (`:4106-4123`), and the pass-7 replay (`wave6-smoke.sh:3832-3853`, under the `EDMV4-T22` AC6
      banner -- AC11 cites it as T22 AC7, an immaterial citation slip in the ticket).
- [x] AC12: `CLAUDE.md`'s `audit_rounds.<type>.rounds[].round_type` row is rewritten to describe the
      three-way check, carries both `**C-4 read rule (EDMV4-T22)**` paragraphs, and names the
      manifest-trigger residual gap as `**Known residual gap (accepted, recorded in
      decisions.md)**`. Asserted `wave6-smoke.sh:4157-4162`.

**Finding**: [P1] EDMV4-T23 | plugins/edm/bin/tests/wave6-smoke.sh:4130-4136 | AC#11: downgrade
reason 3 (incomplete coverage) has no executing smoke case, and the comment claiming it is
untriggerable is wrong. Reproduced live by this auditor without touching `ALL_LENS_IDS`, using the
same hand-patch technique AC2's own case uses 100 lines above:

```
edm-state audit-round-start <PFX> code --lenses L1,L2
jq '.audit_rounds.code.rounds[-1].round_type = "full"' ...   # lenses stays ["L1","L2"], non-empty
#   -> read_round_lenses does NOT substitute, union {L1,L2} != ALL_LENS_IDS
mkdir pass-1_<date>; write lenses-run.txt; land lens-L1.jsonl and lens-L2.jsonl
edm-state audit-round-complete <PFX> code
#   -> "CA-471: round 1 lens coverage incomplete"; round_type becomes partial
```

Add that as a real case and replace the source grep at `:4135-4136` with an assertion against the
captured output.

**Finding**: [P2] EDMV4-T23 | plugins/edm/bin/tests/wave6-smoke.sh:4138-4143 | AC#8: the
double-completion case asserts the exit code but not "mutates nothing". Capture the state file
before and after (or use `_harness.sh`'s `check_state_unchanged`) and assert equality.

**Finding**: [P2] EDMV4-T23 | SRD/edm/EDMV4__ecc-integration/decisions.md:53 | AC#10: the row is
labelled `**Named follow-on**` but names none. Give it a real identifier (a ticket ID in this
initiative, or a reserved prefix verified free), per the `EDMV4-T05` AC9 precedent.

### EDMV4-T24: code-audit Step 1 as the sole L13 authority -- FAIL

- [x] AC1: `cmd_detect_conditional_lenses` at `bin/edm-state:1745-1764`, dispatched at `:6792`,
      documented in the `EDM-HELP` block at `:54`. Always exits 0; prints nothing when the list is
      empty (`:1763`). Asserted `wave6-smoke.sh:4171-4185`.
- [x] AC2: markers enumerated in the help block at `bin/edm-state:54`; predicates at `:1720-1736` are
      pure filesystem tests over `git ls-files` output with no content heuristic except the
      sanctioned `^\[tool\.\(mypy\|pyright\)\]` probe. `wave6-smoke.sh:4187-4253` builds one scratch
      git repo per case: no-marker, tracked `tsconfig.json`, **untracked** `tsconfig.json` (must not
      flip), bare `pyproject.toml` (must not flip), and `pyproject.toml` with `[tool.mypy]` (must
      flip).
- [x] AC3: `wave6-smoke.sh:4255-4269` greps `skills/code-audit/SKILL.md` for five marker filenames
      and requires zero hits, with a positive control proving the same loop finds them in
      `bin/edm-state`. The `agents/edm-audit-type-design.md` half of AC3 is not grepped -- correctly,
      since that file does not exist yet and T24's own Out of Scope assigns it to `EDMV4-T26`, whose
      AC10 duplicates the requirement.
- [ ] AC4: **FAIL (P1)**. The assertion at `wave6-smoke.sh:4209-4216` runs the helper twice from the
      same `cd` and diffs -- which passes -- but the same tree yields a *different answer* from a
      different working directory. `bin/edm-state:1748` calls bare `git ls-files`, which is scoped
      to the caller's cwd, not the repository root; `:1731`'s `grep -q '...' pyproject.toml` is
      likewise cwd-relative. Demonstrated by this auditor in a scratch repo with a tracked
      root-level `tsconfig.json` and one subdirectory:

      ```
      from repo root:   ""      (L13 APPLIES -- correct)
      from sub/:        "L13"   (L13 N/A     -- wrong)
      ```

      This is a wrong answer on an input that gates `round_type=full` -> `audit-converged` ->
      `archive`, which this ticket's own Description names as unacceptable, and it silently drops a
      lens on a typed codebase -- the coverage-loss-as-efficiency-gain shape guard D2 exists to
      prevent. `bin/edm-state` already carries the resolution idiom to use, in
      `check_permission_rules()` (CA-448): `CLAUDE_PROJECT_DIR` when it names a directory, else
      `git rev-parse --show-toplevel`, else `.`.
- [x] AC5: bash 3.2 clean -- no associative array, no `${var^^}`, no `mapfile`; every `grep` is
      wrapped in an `if` so a non-match cannot trip `set -e` (`bin/edm-state:1722-1734`). Required
      binaries unchanged. `shellcheck plugins/edm/bin/edm-state` reports exactly one warning, SC2034
      at `:6616` (`of_err` unused), ~4,850 lines away from this ticket's code -- no new warning.
- [x] AC6: `skills/code-audit/SKILL.md:39-47` -- "**Stack detection (EDMV4-T24) -- Step 1 is the SOLE
      authority for L13's applicability.**", calling `edm-state detect-conditional-lenses <PREFIX>`
      and recording the result as `NA_LENSES`. Asserted `wave6-smoke.sh:4277-4280`.
- [x] AC7: both halves are present in T24's own surfaces, contrary to the implementer's self-report.
      "Recomputed every round, never read from a previous round's record": `bin/edm-state:1740-1744`
      documents that `[<PREFIX>]` is accepted for call-site symmetry and deliberately not read, and
      the function body reads only `git ls-files`; `skills/code-audit/SKILL.md:41-42` states
      "computed fresh every round -- never inherited from a previous round". "Nothing is written on
      N/A": `SKILL.md:52-54` -- "a lens marked N/A is never launched -- absence is authoritative; no
      placeholder `.md` or `.jsonl` is ever written for it". Only the **agent's own** N/A exit
      behavior is `EDMV4-T26` AC5's, so the hand-off as stated was over-broad -- but nothing was
      actually dropped.
- [x] AC8: `skills/code-audit/SKILL.md:73` passes both `--lenses` and `--na-lenses` to
      `audit-round-start`; `:101` specifies the `Lenses N/A: L13` / `Lenses N/A: (none)` header line.
      `wave6-smoke.sh:4286-4301` asserts the header does not match `^L[0-9]+$` **and** carries a
      positive control proving a bare `L13` does match, so the regex is shown to discriminate.
      `bin/edm-state:4660`'s filter is untouched.
- [x] AC9: `skills/code-audit/SKILL.md:48-50` -- explicit `--lenses` means `NA_LENSES` is always
      empty and the auto-N/A path does not run. Asserted `wave6-smoke.sh:4281-4282`.
- [x] AC10: `skills/code-audit/SKILL.md:44-47` states every lens agent must **agree** rather than
      form its own, and names the mismatch as a contract violation in the
      `agents/edm-test-integration.md:21-25` shape. Asserted `wave6-smoke.sh:4283-4284`. **The
      hand-off checks out against `EDMV4-T26`'s actual text**: T26 AC4 independently requires the
      reciprocal clause inside `agents/edm-audit-type-design.md`, and T26's Technical Notes settle
      the dependency direction the same way (the agent depends on the authority, not vice versa).
- [x] AC11: `CLAUDE.md`'s `bin/` table documents the subcommand and the marker list, and the
      `edm-state` count reads 41. **Independently verified**: the dispatcher `case` in
      `bin/edm-state` has exactly 41 subcommand arms, including both `get-patterns` and
      `detect-conditional-lenses` -- the two increments are reconciled into one number, not double
      counted.
- [x] AC12: the `detect-conditional-lenses` row cross-references `CLAUDE.md Sec."Layers that are N/A
      and per-epic test plans"` as the precedent. Substantively satisfied; the assertion that
      checks it is not (see the P2 finding below).

**Finding**: [P1] EDMV4-T24 | plugins/edm/bin/edm-state:1748 (and :1731) | AC#4: `detect-conditional-lenses`
is cwd-sensitive, so "the same tree" produces two different answers depending on where it is
invoked from. `git ls-files` at `:1748` lists only files at or below the caller's cwd, and the
`pyproject.toml` content probe at `:1731` opens a cwd-relative path. Resolve the project root first
using the `check_permission_rules()` / CA-448 idiom already in this file, and run both the
`git ls-files` call and the `pyproject.toml` probe against it. Add a subdirectory-invocation case to
`wave6-smoke.sh`'s marker-repo block -- the existing determinism assertion at `:4209-4216` cannot see
this class because both runs share one `cd`.

**Finding**: [P2] EDMV4-T24 | plugins/edm/bin/tests/wave6-smoke.sh:4309-4310 | AC#12: the assertion
searches `CLAUDE.md` for the literal `Layers that are N/A and per-epic test plans`, which is also
that file's own `###` section heading. It therefore passes whether or not any cross-reference
exists, and would keep passing if the `detect-conditional-lenses` row's citation were deleted
tomorrow. Anchor the match to the citing row instead -- e.g. assert that the
`detect-conditional-lenses` table row itself contains the section name.

## Non-blocking observations

None of these change a verdict. They are recorded because each is a small step away from a defect
class this initiative has already paid for.

1. **`EDMV4-T13` AC1's scope is narrower than its text.** `bin/edm-gateguard:106` and `:117` are
   allow decisions emitted as bare `exit 0` outside `emit_decision`, and the AC1 assertion cannot
   see them (it counts only `exit 2` and `permissionDecision`). Both sites belong to work T13
   declares out of scope (`:117` is the marker test, `EDMV4-T12`; `:106` is `EDMV4-T17`'s
   library-degradation guard), and `emit_decision` is defined below both in file order so neither
   could call it anyway. The gated-path guarantee -- the one that matters -- is fully asserted.
2. **`wave8-smoke.sh:3457` is an unconditional `pass`.** It is a prose summary of AC5 stated as a
   test result: no condition guards it, so it inflates the pass count by one without asserting
   anything. AC5's real evidence is `:3359-3371` plus AC3/AC4's observed exit codes. This is the
   fourth instance of this shape in the initiative; consider deleting the line or converting it to
   a comment.
3. **`EDMV4-T13`'s harness reproduces `die()` by hand** (`wave8-smoke.sh:3389`) rather than sourcing
   the shipped one, so a change to `bin/edm-gateguard:71-75`'s default exit code would not be
   caught by AC4/AC5. A real end-to-end path exists today (marker present + `Edit` payload +
   `EDM_GATEGUARD_DENY_MODE=yes` reaches `emit_decision allow` and dies through the real `die()`) --
   this auditor ran it and it behaves correctly.
4. **`EDMV4-T20` AC3 merges stderr into stdout** (`wave8-smoke.sh:2764`, `2>&1`), so the assertion
   does not prove the warning went to stderr specifically. It does -- `bin/edm-state:6099` ends in
   `>&2` -- so the substance holds; capturing the two streams separately would make the assertion
   match the AC.
5. **`EDMV4-T19` AC2's assertion checks only that the six named files each carry a call**, never
   that no seventh file does. A seventh call site would not fail it. Low impact, since the whole
   point of the count-free rewording is that a seventh caller invalidates nothing.
6. **`EDMV4-T24`'s marker list appears three times inside `bin/edm-state`** -- the `EDM-HELP` block
   at `:54` (required by AC2), the explanatory comment at `:1713-1719`, and the executable
   predicates at `:1722-1734`. AC3's "exactly one place in `bin/edm-state`" and AC2's help-block
   mandate cannot both be met literally. The prose copy at `:1713-1719` is the one that can drift
   from the code without any check noticing -- the same comment-versus-truth drift `EDMV4-T19` just
   spent a ticket fixing.

## Remediation Required

Prioritized. PARTIAL findings are not remediated here -- `/edm:verify-runtime` closes both before
archive.

**P1 -- three, all independently fixable**

1. `EDMV4-T24` | `plugins/edm/bin/edm-state:1748`, `:1731` -- resolve the project root
   (`CLAUDE_PROJECT_DIR` -> `git rev-parse --show-toplevel` -> `.`, the CA-448 idiom already in this
   file) and run `git ls-files` and the `pyproject.toml` probe against it, so a
   `/edm:code-audit` invoked from a subdirectory cannot silently mark L13 N/A on a typed codebase.
   Add a subdirectory-invocation case to `wave6-smoke.sh:4187-4253`.
2. `EDMV4-T23` | `plugins/edm/bin/tests/wave6-smoke.sh:4130-4136` -- add a real executing case for
   downgrade reason 3 (recipe in the finding above; no `ALL_LENS_IDS` mutation needed) and replace
   the source-text grep with an assertion against the captured operator output.
3. `EDMV4-T20` | `plugins/edm/bin/tests/wave8-smoke.sh:2909-2911` -- replace the `echo "  NOTE: ..."`
   with `fail`. Expect it to go red until `EDMV4-T53` AC2 adds `wave8-smoke.sh` to
   `run-all.sh:39`'s `_PREFERRED_ORDER` and raises `_MIN_SUITE_COUNT` at `:96` from 7 to 8. That red
   is the intended routing of the defect, per AC8's own wording.

**P2 -- three**

4. `EDMV4-T23` | `plugins/edm/bin/tests/wave6-smoke.sh:4138-4143` -- assert the second
   `audit-round-complete` mutates nothing, not just that it exits non-zero.
5. `EDMV4-T23` | `SRD/edm/EDMV4__ecc-integration/decisions.md:53` -- give the "Named follow-on" an
   actual name.
6. `EDMV4-T24` | `plugins/edm/bin/tests/wave6-smoke.sh:4309-4310` -- anchor the AC12 assertion to the
   citing table row so it cannot pass on `CLAUDE.md`'s own section heading.

**Outstanding PARTIALs** (recorded to `partial_verdict_map`, closed by `/edm:verify-runtime`)

| Ticket | Runtime-check note |
|---|---|
| `EDMV4-T19` | AC7 -- re-run `run-all.sh` once `EDMV4-T26` lands and the stale wave7 assertions have an owner; confirm green. No current wave7 failure is T19-attributable |
| `EDMV4-T20` | AC9 -- run `run-all.sh` twice consecutively from a clean tree; confirm both green and identical |

<!-- QC-SHARD-COMPLETE range=T13-T24 assigned=5 audited=5 -->
