# Epic 08: Cross-Cutting

This epic holds the four final verification passes that gate EDMV4's Definition of Done
(`srd.md` Sec.3.4): `EDMV4-T50` (the bash 3.2 floor), `EDMV4-T51` (the `bash`/`jq`/`git`
required-binary set), `EDMV4-T52` (ASCII-only across every artifact, by a manual `--path` sweep
plus a byte scan) and `EDMV4-T53` (smoke coverage for every new surface in `run-all.sh`). None of
the four builds a feature; each one runs as a discrete, executable verification pass over the
surfaces the implementation waves produced, and each closes with an artifact -- a smoke assertion,
a recorded command result, or a decisions.md entry -- rather than an opinion. The initiative is not
complete until all four pass.


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

## EDMV4-T50: Extend the tree-wide bash-4 construct ban to cover every new script and the new smoke suite

| Field | Value |
|---|---|
| Epic | Cross-Cutting |
| Phase | 5 |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV4-55 |
| Depends On | EDMV4-T13, EDMV4-T15, EDMV4-T20, EDMV4-T28, EDMV4-T30, EDMV4-T33, EDMV4-T41, EDMV4-T44, EDMV4-T47, EDMV4-T04, EDMV4-T05, EDMV4-T49 |
| Target Components | `plugins/edm/bin/_edm-datadir-lib.sh`, `plugins/edm/bin/edm-gateguard`, `plugins/edm/bin/edm-hookify`, `plugins/edm/bin/edm-stop-gate`, `plugins/edm/bin/edm-repo-readiness`, `plugins/edm/bin/tests/wave8-smoke.sh`, `plugins/edm/bin/edm-state`, `plugins/edm/bin/tests/wave7-smoke.sh` (`:1082-1100`, `:1083`, `:1095-1097`), `plugins/edm/bin/tests/harness-smoke.sh` (`:245-248`), `plugins/edm/bin/tests/timing.sh` (`:54-80`), `plugins/edm/bin/edm-lint-artifacts`, `plugins/edm/CLAUDE.md` Sec."Testing changes" |

### Description

The plugin supports macOS and Linux only, at a bash 3.2+ floor. macOS ships bash 3.2.57 as
`/bin/bash`, so this is not a theoretical constraint -- it is the interpreter every contributor to
this plugin actually has. EDMV4 adds four new scripts plus a shared library, the largest single
addition to `bin/` in the plugin's history, and therefore the largest single opportunity to
regress the floor.

The ban is already implemented tree-wide and this ticket extends it rather than writing weaker
parallel criteria. `wave7-smoke.sh:1082-1100` (T61 AC9) sweeps every file at the top level of
`plugins/edm/bin/` with `T61_BASH4_RE` (`:1083`), excluding comment-only lines, and carries a
positive control at `:1095-1097` that proves the alternation can fire before the empty result is
trusted. Because the sweep's file set is derived live from `find "$PLUGIN_DIR/bin" -maxdepth 1
-type f`, the five new top-level files fall under it automatically -- the work here is asserting
that they actually do, not re-encoding the rule.

The one real gap this ticket must close is `bin/tests/`. T61 AC9's `-maxdepth 1` deliberately
excludes the test surface, so the new `bin/tests/wave8-smoke.sh` is covered by nothing. This
ticket runs after every implementation wave that adds or edits a `bin/` script, since it verifies
the finished set.

### Acceptance Criteria

- [ ] AC1: A smoke assertion in `wave8-smoke.sh` recomputes T61 AC9's own file set
      (`find "$PLUGIN_DIR/bin" -maxdepth 1 -type f`) and fails naming any of
      `_edm-datadir-lib.sh`, `edm-gateguard`, `edm-hookify`, `edm-stop-gate` and
      `edm-repo-readiness` that is absent from it. The assertion derives the set live and compares
      against these five names; it does not assert a count, because a count is satisfied by any
      five files.
- [ ] AC2: `bin/tests/` is brought under the ban for the new suite, by one of two recorded routes:
      widen T61 AC9's sweep to include `bin/tests/wave8-smoke.sh`, or add an assertion inside
      `wave8-smoke.sh` that applies the pattern to itself. Either way the assertion **references**
      `T61_BASH4_RE` (sourced or re-read from `wave7-smoke.sh:1083`) and never re-encodes the
      alternation as a second literal that can drift. The chosen route is stated in a comment at
      the assertion site.
- [ ] AC3: No new or modified file under `plugins/edm/bin/` matches `T61_BASH4_RE`
      (`declare -A`, `mapfile`, `readarray`, `${var^^}`, `${var,,}`, `{fd}` redirection) on a
      non-comment line. `{fd}` is already in the pattern and is not restated as a separate,
      weaker criterion.
- [ ] AC4: Every constant in the new scripts that would naturally be an array is a
      space-separated string consumed with the word-membership idiom
      `case " $LIST " in *" $item "*)`, matching `bin/edm-state`'s `MODE_ENUM_LIST` (`:803`),
      `AUDIT_TYPE_ENUM_LIST` (`:808`) and `ALL_LENS_IDS` (`:1609`).
- [ ] AC5: No process substitution appears in a loop condition in any new script (the CA-472
      fd-leak class). A smoke assertion greps the five new files plus `wave8-smoke.sh` for
      `while ... < <(` inside a condition position and fails on a hit, with a positive control.
- [ ] AC6: `/bin/bash -n` parses each of the five new files and `wave8-smoke.sh` cleanly, invoked
      as literal `/bin/bash`, never as `bash` resolved from `PATH` (a developer's `PATH` bash is
      routinely 5.x from Homebrew and proves nothing about the floor).
- [ ] AC7: Each new executable script is additionally **run** under `/bin/bash <script> --help`
      and exits 0, so the 3.2 check covers execution and not only parsing.
- [ ] AC8: The suite records `/bin/bash --version` in its output, so a run on a host whose
      `/bin/bash` is not 3.2 is visible in the log rather than silently vacuous.
- [ ] AC9: No acceptance criterion, comment or ticket note in this initiative carries an "or the
      deviation is documented" escape hatch for a bash-4 construct. A bash-4 construct in a `bin/`
      script is a defect. A genuine platform deviation is handled the way `bin/tests/timing.sh`
      handles its optional `perl` timer (`:54-80`): a runtime `command -v` probe with a working
      fallback on the same code path.
- [ ] AC10: Every shellcheck directive added by this initiative is inline at the site it applies
      to, with the reason stated, following the form at `bin/edm-state:1610`. No file-level blanket
      disable is present in any new script.

### Technical Notes

Citations re-derived against the current branch before restating:

- **Holds.** `wave7-smoke.sh:1082-1100` is T61 AC9 exactly as the SRD describes; `T61_BASH4_RE` at
  `:1083` is byte-for-byte
  `declare -A|mapfile|readarray|\$\{[a-zA-Z_]+\^\^\}|\$\{[a-zA-Z_]+,,\}|\{fd\}`; the positive
  control is at `:1095-1097`; the file set comes from
  `find "$PLUGIN_DIR/bin" -maxdepth 1 -type f` at `:1091`. `harness-smoke.sh:245-248` pins
  `_harness.sh` as described.
- **Does not hold as stated.** The SRD describes `wave7-smoke.sh:512-535` (T03 AC10) as banning
  `declare -A` **tree-wide**. It does not. Despite the helper's name, the call at `:517-518`
  passes `"$(cat "$EDM_CHECK_GRANTS")"` as the haystack, so the assertion is scoped to
  `bin/edm-check-grants` alone; the `mapfile`/`readarray` check at `:528-535` greps the same single
  file. `:649` is likewise scoped, to `evals/score-artifacts.sh`, via `check_absent`. Only T61 AC9
  is genuinely tree-wide, which strengthens the case for AC1 and AC2: it is the single assertion
  the five new files depend on.
- **Off by four lines.** The SRD cites `bin/edm-state:1614` as the inline shellcheck form. The
  directive is at `:1610`
  (`# shellcheck disable=SC2086 -- deliberate word-splitting; bash 3.2 has no arrays-as-constants`);
  `:1614` sits inside the `AUDIT_ROUND_COERCE_JQ_DEF` comment block. AC10 cites `:1610`.
- `wave7-smoke.sh:2539-2542` (T43 AC11) pins `edm-lint-artifacts` with its own narrower literal
  (`declare -A|mapfile|readarray|\{fd\}`, no case-conversion arms). It is a second literal that has
  already drifted from `:1083`, which is precisely why AC2 forbids adding a third.
- T61 AC9's file set is every top-level file, not only scripts, so it also sweeps
  `vocabulary-allowlist.txt`, `vocabulary-prohibited.txt` and `edm-mermaid-rules.awk`. A new
  top-level `bin/` file of any kind inherits the ban; a new file placed in a `bin/` subdirectory
  does not.

### Out of Scope

- Rewriting or widening the existing per-file bans at `wave7-smoke.sh:512-535`, `:649` and
  `:2539-2542`. Their narrow scope is recorded above as a known property, not fixed here.
- Any bash-4 construct removal in pre-existing `bin/` scripts this initiative does not modify --
  T61 AC9 already keeps them clean.
- Building a container or `brew install bash@3.2` compatibility harness. `/bin/bash` on macOS is
  the 3.2 interpreter, which is the whole point of AC6 and AC7.
- Linux execution. See `EDMV4-T53` AC8 for why Linux is recorded as supported but untested.

---

## EDMV4-T51: Verify the required-binary set is still `bash`, `jq`, `git`

| Field | Value |
|---|---|
| Epic | Cross-Cutting |
| Phase | 5 |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV4-56 |
| Depends On | EDMV4-T10, EDMV4-T13, EDMV4-T15, EDMV4-T20, EDMV4-T28, EDMV4-T30, EDMV4-T33, EDMV4-T41, EDMV4-T44, EDMV4-T47, EDMV4-T04, EDMV4-T05, EDMV4-T49 |
| Target Components | `plugins/edm/bin/` (all scripts), `plugins/edm/bin/tests/timing.sh` (`:54-80`, `:59-60`, `:75-76`), `plugins/edm/bin/tests/wave8-smoke.sh`, `plugins/edm/CLAUDE.md` Sec."Testing changes", `SRD/edm/EDMV4__ecc-integration/decisions.md` (D7, D14), `SRD/edm/EDMV4__ecc-integration/architecture.md` (AD1) |

### Description

The plugin's required binaries are `bash`, `jq` and `git`. Two decisions in this initiative turned
on that constraint: D7 chose JSON rule files over ECC's YAML frontmatter because a YAML parser
would add a binary this plugin has never needed, and AD1 chose a bash rewrite of GateGuard over
vendoring because both adoption paths -- the Python upstream and ECC's JavaScript port -- add a
runtime dependency. The constraint is load-bearing for two separate design decisions, so recording
it as a testable requirement is what keeps a later implementer from quietly reintroducing one.

AD1 was ratified at Gate 2 on 2026-09-02 (`decisions.md` D14), so the bash rewrite stands and no
runtime dependency is added by this initiative. The dependency-addition clause in AC8 is therefore
dormant, but its wake condition is live and precisely worded: it fires on **an AD1 reversal by any
route**, matching D14's own wording. It does not fire on an `EDMV4-05` rejection, which yields a
larger bash rewrite and adds no binary at all. Wiring the clause to the wrong decision was the
v1.0.0 defect the SRD audit recorded as R17 -- a dormant obligation with nothing that could ever
wake it.

This ticket runs after every implementation wave that adds or edits a `bin/` script. It depends on
`EDMV4-T10` because that ticket records the Gate 2 ratifications, and AC8's wording is only
verifiable once AD1's status is fixed in `decisions.md`.

### Acceptance Criteria

- [ ] AC1: A smoke assertion in `wave8-smoke.sh` greps every file under `plugins/edm/bin/`
      (file set derived live from `find`, not a hardcoded name list) for `node`, `python`,
      `python3`, `yq`, `ruby`, `perl` and `deno` on a non-comment line, and fails on any hit not
      covered by AC2's exemption. A hardcoded list would stay green as new scripts are added.
- [ ] AC2: The `perl` exemption is declared by construction, not by line number. The assertion
      resolves `timing.sh`'s two `perl` call sites by content (the `_now` and `_ms_between`
      bodies) and fails on (a) any `perl` invocation anywhere else under `bin/`, and (b) a `perl`
      invocation at either site that is not immediately preceded by a
      `command -v perl >/dev/null 2>&1` guard with a non-perl fallback in the same `if`/`else`.
      Resolving by content rather than by `:59-60`/`:75-76` matters because `EDMV4-47` AC4 edits
      this very file.
- [ ] AC3: The interpreter grep carries a positive control -- a scratch file containing a
      `python3 -c` line must fail it -- so a non-firing pattern is caught rather than read as a
      clean tree.
- [ ] AC4: `POSIX coreutils` is not used as the dependency boundary anywhere in this initiative's
      scripts or docs. Every coreutil a new script uses beyond the POSIX-guaranteed set is named
      in-file with its BSD/GNU divergence stated, or is avoided.
- [ ] AC5: `edm-gateguard`'s mtime read for `EDMV4-11`'s 30-minute denial expiry does not assume
      GNU `stat`. It either probes both `stat -f %m` (BSD) and `stat -c %Y` (GNU) at runtime, or
      avoids `stat` entirely (for example via `find -newermt` or a recorded timestamp in state).
      A smoke assertion greps `edm-gateguard` for a bare `stat -c` with no BSD arm and fails on it.
- [ ] AC6: No file is added anywhere under `plugins/edm/` with a `.js`, `.ts`, `.mjs`, `.cjs` or
      `.py` extension. A smoke assertion asserts this over a live `find`.
- [ ] AC7: `plugins/edm/CLAUDE.md` Sec."Testing changes" still opens with its existing
      required-binary statement -- "macOS and Linux only (bash 3.2+, jq, git required). Windows
      and WSL are unsupported." -- unchanged by this initiative, asserted as an exact string
      match against the sentence as it stands on the current branch.
- [ ] AC8: Each of the four new scripts and the shared library degrades correctly when `jq` is off
      `PATH`: a named setup error on stderr and the script's documented setup exit code (1 for
      hook scripts, 2 for CLI scripts), never a block of the tool call and never an unhandled
      crash. One test per script drives this with a `PATH` that excludes `jq`.
- [ ] AC9: The AD1-reversal clause is recorded in `decisions.md` beside D14 in exactly this form:
      if AD1 is reversed to vendoring **by any route** -- `EDMV4-59` rejected, or any later
      decision directing vendoring -- the dependency addition (`node` for ECC's JavaScript port,
      or `python3` plus `pip install gateguard-ai` for the upstream) is re-presented at a gate as
      an explicit dependency addition, never absorbed. The record states that an `EDMV4-05`
      rejection is **not** a trigger.

### Technical Notes

- `bin/tests/timing.sh` verified on the current branch: the guarded `perl` path is at `:58-71`
  (`_now`) and `:74-80` (`_ms_between`), both wrapped in `command -v perl >/dev/null 2>&1` with a
  POSIX-awk fallback. The comments at `:54-57` (CA-158) and `:63-68` (G31/CA-262) record why the
  fallback must not invent sub-second digits and why `systime()` is not usable. The SRD's
  `:59-60`/`:75-76` cites land on the `perl` invocation lines themselves and hold today, but AC2
  resolves by content because `EDMV4-47` AC4 edits this file.
- The BSD/GNU divergence is real and asymmetric: `stat` is not in POSIX at all, `stat -f` is BSD
  and `stat -c` is GNU, and `flock` is util-linux-only. `date -d` is another common GNU-only trap
  worth avoiding in `edm-gateguard`.
- `edm-state` establishes the house shape for a `jq`-missing failure: a named setup error rather
  than a crash. Match it rather than inventing a new convention per script.
- `decisions.md` D14 (2026-09-02) is the authority for AD1's ratified status and already carries
  the "wired to an AD1 reversal by any route" phrasing that AC9 must match. D13 records the
  MIT-attribution obligation that the same reversal would wake.

### Out of Scope

- Removing or restructuring `timing.sh`'s `perl` path. It is an optional accelerator with a
  working fallback, and this ticket verifies its guard rather than replacing it.
- Auditing pre-existing `bin/` scripts this initiative does not touch for coreutil portability.
  AC4 and AC5 bind new and modified scripts.
- Deciding the GateGuard implementation strategy. That is AD1, ratified at Gate 2 under
  `EDMV4-59`/`EDMV4-T10`; this ticket only verifies the binary consequence and records the
  reversal clause.
- Adding a `yq`, `node` or `python3` dependency under any circumstance short of the gate
  presentation AC9 describes.

---

## EDMV4-T52: Verify ASCII-only artifacts by a manual `--path` sweep plus an explicit byte scan

| Field | Value |
|---|---|
| Epic | Cross-Cutting |
| Phase | 5 |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV4-57 |
| Depends On | EDMV4-T13, EDMV4-T15, EDMV4-T20, EDMV4-T28, EDMV4-T30, EDMV4-T33, EDMV4-T41, EDMV4-T44, EDMV4-T47, EDMV4-T04, EDMV4-T05, EDMV4-T49 |
| Target Components | `plugins/edm/bin/edm-lint-artifacts` (class 2, and `collect_md_files` at `:251-260`), `plugins/edm/bin/tests/wave8-smoke.sh`, `plugins/edm/hooks/hooks.json`, `plugins/edm/monitors/monitors.json`, `plugins/edm/bin/edm-gateguard` (`emit_decision`), `plugins/edm/bin/edm-hookify`, `plugins/edm/bin/edm-stop-gate`, `plugins/edm/bin/edm-check-vocabulary`, `plugins/edm/CLAUDE.md` Sec."Artifact content conventions" and Sec."Mermaid diagram conventions (canonical)", `plugins/edm/agents/` (3 new lens prompts), `plugins/edm/bin/` (4 new scripts plus the shared library), `SRD/edm/EDMV4__ecc-integration/` |

### Description

Every artifact this plugin produces or ships is ASCII-only: no em dashes, no arrows (use `->`), no
smart quotes, no emoji. The automatic enforcement does not match the rule, in two independent
ways, and this ticket exists because both gaps are directly in EDMV4's path.

The first gap is reach. `edm-lint-artifacts` class 2 (`unicode`) scans initiative directories:
prefix mode resolves one, `--all` walks the ones `edm-state list --paths` returns. The `PreToolUse`
git-commit hook runs prefix mode, so it never reaches `plugins/edm/skills/`, `agents/`, `docs/`,
`evals/`, `CLAUDE.md` or `README.md`. Em dashes have in fact landed in `skills/` and `agents/` and
survived there undetected, found only by hand. A manual `edm-lint-artifacts --path plugins/edm/`
sweep closes that half.

The second gap is collection, and a `--path` sweep does **not** close it. `collect_md_files`
(`bin/edm-lint-artifacts:251-260`) runs `find "$dir" -type f ... -name '*.md'`, so no `.sh` file
and no extensionless `bin/` script is ever collected, in any mode, `--path` included. That means
the four new scripts and the shared library -- the largest `bin/` addition in this plugin's
history -- are scanned by nothing at all today. Risk R16 records the exposure: three new lens
prompts and four new scripts would otherwise ship undetected. The acceptance criteria split
accordingly: the `--path` sweep owns `.md`, an explicit byte scan owns everything else, and every
new file is assigned to exactly one of the two. Definition of Done item 5 depends on this ticket,
which runs after every wave that writes a prompt, script or artifact.

### Acceptance Criteria

- [ ] AC1: `plugins/edm/bin/edm-lint-artifacts --path plugins/edm/` reports zero violations. This
      is a **manual** invocation, run and its output recorded before the initiative is called
      complete; it is Definition of Done item 5 and is never assumed to have happened because a
      commit succeeded.
- [ ] AC2: A new assertion in `bin/tests/wave8-smoke.sh` runs `LC_ALL=C grep -n '[^\x00-\x7F]'`
      over every file under `plugins/edm/bin/` (file set derived live from
      `find plugins/edm/bin -type f`, so extensionless scripts and `bin/tests/` are included),
      plus `plugins/edm/hooks/hooks.json` and `plugins/edm/monitors/monitors.json`, and fails
      printing file and line on any hit.
- [ ] AC3: The byte scan carries a positive control: a scratch file written with one non-ASCII
      byte must make the scan report a hit, asserted in the same test, so a silently non-firing
      grep is caught the way `T61_BASH4_RE`'s control catches a broken alternation.
- [ ] AC4: A coverage assignment is recorded in `wave8-smoke.sh`'s comment header naming which
      mechanism owns which file: the three new lens agent prompts, every edited `SKILL.md` and
      every edited `CLAUDE.md` are covered by AC1's `--path` sweep; the four new `bin/` scripts,
      the shared library and the two JSON config files are covered by AC2's byte scan. No file is
      listed under both, and no new file this initiative adds is listed under neither.
- [ ] AC5: `plugins/edm/bin/edm-lint-artifacts EDMV4` reports zero violations across every
      artifact this initiative writes under `SRD/edm/EDMV4__ecc-integration/`.
- [ ] AC6: `emit_decision` in `edm-gateguard` (`EDMV4-09`) and the single equivalent emit point in
      each of `edm-hookify` and `edm-stop-gate` strip or replace non-ASCII bytes in every
      interpolated value before emitting. Static scanning cannot cover this, because the
      interpolated values -- file paths, user rule messages, anomaly text -- originate outside the
      plugin and a user's repository may legitimately contain a path with a non-ASCII character.
- [ ] AC7: A smoke test drives a denial through each of the three emit points on a path containing
      a non-ASCII byte and asserts the emitted output is (a) pure ASCII, verified with the same
      `LC_ALL=C grep` as AC2, and (b) still parses as JSON under `jq -e .`. Both halves are
      asserted: sanitization that breaks the JSON control channel is a worse defect than the byte
      it removed.
- [ ] AC8: `bash plugins/edm/bin/edm-check-vocabulary` exits 0 with its full scan set --
      `skills/`, `agents/`, `docs/`, `hooks/hooks.json`, `monitors/monitors.json`, `CLAUDE.md`,
      `README.md` and `bin/`.
- [ ] AC9: Every Mermaid diagram added or edited by this initiative, in any artifact, uses the
      `#59;` entity code for a literal semicolon inside label, node, edge or message text, per
      `CLAUDE.md` Sec."Mermaid diagram conventions (canonical)". A raw `;` inside a label is a
      violation, and `edm-lint-artifacts` class 4 asserts it over the initiative's own artifacts.
- [ ] AC10: The two-half reach gap is written into this ticket's own text (Description above) and
      into `plugins/edm/CLAUDE.md` Sec."Artifact content conventions", so a later reader does not
      skip the manual sweep on the assumption that the commit hook covers it.
- [ ] AC11: Where this initiative writes files into a tree that no `edm-lint-artifacts` invocation
      reaches -- notably `.claude/edm-hookify/*.json` rule files (`EDMV4-42`) -- the gap is stated
      explicitly in that feature's documentation as an uncovered surface, rather than left
      implicitly assumed closed.

### Technical Notes

- `collect_md_files` verified at `bin/edm-lint-artifacts:251-260` on the current branch, exactly
  as the SRD describes: `find "$dir" -type f -not -path '*/.git/*' -not -path '*/.archived/*'
  -name '*.md' -print0`. The `-name '*.md'` filter is the reason AC2 exists and is why a
  `--path` sweep alone cannot satisfy this requirement.
- `edm-lint-artifacts` skips lines inside fenced code blocks and lines under an `edm-lint-ignore`
  marker. AC2's byte scan deliberately has no such exclusion -- a shell script has no fenced
  blocks, and an exempt non-ASCII byte in a `bin/` script is not a case this plugin wants.
- AC2's file set must be derived live. A hardcoded list of the five new files would be green on
  the day it is written and silently escape every script added afterwards -- the same failure
  class as an anti-regression assertion that counts a hardcoded name list rather than the live
  set.
- The three emit points are single functions by requirement (`EDMV4-09` for `emit_decision`), so
  AC6's sanitization has exactly one site per script. Verify that single-emit-point property
  holds before writing the sanitizer, since a second emit path would bypass it.
- Prefer `LC_ALL=C` on the grep. Without it, a UTF-8 locale can make `grep` interpret the byte
  range and report differently across BSD and GNU grep.

### Out of Scope

- Widening `collect_md_files` to collect shell scripts. That would change `edm-lint-artifacts`
  behavior for every caller including the commit-path latency budget; the byte scan in
  `wave8-smoke.sh` is the chosen mechanism instead.
- Making the git-commit hook reach the plugin's own source tree. The manual sweep (AC1) is the
  recorded answer.
- ASCII-normalizing pre-existing violations outside this initiative's edited set. AC1 will surface
  them; fixing files this initiative does not otherwise touch is separate work.
- Asserting anything about runtime-emitted text by static scan. AC6 and AC7 are the sanctioned
  treatment; see the Description for why no static mechanism can cover interpolated values.

---

## EDMV4-T53: Land `wave8-smoke.sh` in `run-all.sh` and run the Definition-of-Done verification pass

| Field | Value |
|---|---|
| Epic | Cross-Cutting |
| Phase | 5 |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV4-58 |
| Depends On | EDMV4-T13, EDMV4-T15, EDMV4-T20, EDMV4-T28, EDMV4-T30, EDMV4-T33, EDMV4-T41, EDMV4-T44, EDMV4-T47, EDMV4-T04, EDMV4-T05, EDMV4-T49 |
| Target Components | `plugins/edm/bin/tests/wave8-smoke.sh`, `plugins/edm/bin/tests/run-all.sh` (`:39` `_PREFERRED_ORDER`, `:75-86` the tripwire, `:87` `_MIN_SUITE_COUNT`), `plugins/edm/bin/tests/wave6-smoke.sh` (`:4087-4099`), `plugins/edm/bin/tests/harness-smoke.sh`, `plugins/edm/bin/tests/wave7-smoke.sh`, `plugins/edm/CLAUDE.md` Sec."Testing changes", `plugins/edm/CHANGELOG.md` (**CA-117**: added so AC13 below is assignable at all -- this ticket already owns the Definition-of-Done pass and its evidence, and DoD item 8 is the changelog entry), `SRD/edm/EDMV4__ecc-integration/decisions.md` |

### Description

There is no CI pipeline for this plugin -- commit `b56558d` removed the GitLab one and nothing
replaced it. `bash plugins/edm/bin/tests/run-all.sh` plus the git-commit hook are the entire
enforcement surface. The local smoke suite is the actual enforcement, not a convenience check run
ahead of a pipeline, which means an untested new script is permanently untested rather than
untested until the pipeline catches up.

This ticket lands the new suite, registers it so its disappearance is loud rather than silent, and
runs the aggregate Definition-of-Done verification pass. Registration is the load-bearing half:
`run-all.sh` discovers suites by glob, so a new suite runs whether or not it is named, but the
tripwire at `:75-86` only iterates `_PREFERRED_ORDER` and only fails naming a suite listed there.
An unlisted suite that later stops being discovered takes the whole run green with one fewer suite
and nothing says so. `_MIN_SUITE_COUNT` at `:87` defaults to 7 today, which is satisfied by the
seven existing suites even if `wave8-smoke.sh` vanishes -- so it must be bumped to 8 as well.

The platform claim is stated honestly. macOS is verified, because every contributor runs it and
its `/bin/bash` 3.2.57 is what makes `EDMV4-55`'s floor check real. Linux is recorded as untested:
no CI pipeline exists, no container image is named anywhere in this repository, and nothing in
this initiative introduces one, so a Linux claim would be signed off on the basis of nobody having
run it. Linux remains a supported platform by construction -- `EDMV4-55`'s bash-3.2 floor and
`EDMV4-56`'s BSD/GNU coreutil discipline are what make that support plausible -- but supported and
verified are recorded as different claims. This ticket runs after every implementation wave in the
initiative.

### Acceptance Criteria

- [ ] AC1: `bin/tests/wave8-smoke.sh` exists, is executable (`chmod +x`), sources `_harness.sh`,
      uses its `pass`/`fail` helpers, and emits the standard
      `Results: N passed, M failed` summary line that `run-all.sh:108` parses. A suite emitting no
      summary line is already classified as a failure by the aggregator.
- [ ] AC2: **This ticket is the sole owner of the `run-all.sh` registration** (audit P1-3). It is
      stated as a durable post-condition, not as a delta, so it is non-vacuous regardless of which
      ticket lands first and survives the ninth suite:
      (a) `wave8-smoke.sh` appears in `_PREFERRED_ORDER` so the missing-preferred tripwire names it
      if it ever stops being discovered; and
      (b) `_MIN_SUITE_COUNT`'s default **equals the number of `*-smoke.sh` files the `find` sweep
      discovers** -- asserted by computing both at test time and comparing, never by pinning the
      literal `8`.
      Locate `_MIN_SUITE_COUNT` by the literal string `_MIN_SUITE_COUNT="${EDM_RUN_ALL_MIN_SUITE_COUNT:-`
      rather than by line number: it moved from `:87` to `:96` when commit `5f90001` inserted the
      `_branch_before` capture block, and the earlier wording of this AC rested its anti-vacuity
      argument on that stale line.
- [ ] AC3: Every new `bin/` script (`edm-gateguard`, `edm-hookify`, `edm-stop-gate`,
      `edm-repo-readiness`) has at least three cases in `wave8-smoke.sh`: a `--help` invocation
      asserting exit 0 and non-empty output, a usage-error case asserting the exit code this SRD
      documents for it, and one happy-path case.
- [ ] AC4: Every new hook registration in `hooks/hooks.json` has a case asserting its
      `command -v` guard exits 0 when the delegate script is off `PATH`, matching the exit-code
      contract `CLAUDE.md` Sec."Hooks behavior" records (a setup condition never blocks).
- [ ] AC5: Every exit code this SRD documents for a new script has a case in `wave8-smoke.sh` that
      actually produces it. The case set is cross-checked against the SRD's exit-code tables at
      review time, not asserted by a count.
- [ ] AC6: `wave8-smoke.sh` runs with no network access and spends no API budget. No case invokes
      `claude`, `curl`, `git fetch`, `git push` or any other remote operation.
- [ ] AC7: `wave8-smoke.sh` creates no files inside the repository working tree. Scratch trees use
      `mktemp -d` and are removed on every exit path including trap-driven ones. The invariant is
      verified by snapshotting `git status --porcelain` immediately before and after running
      `wave8-smoke.sh` **in isolation** and asserting no new entry is attributable to it. It is
      deliberately not a blanket "clean tree" assertion, because `wave6-smoke.sh:4087-4099`
      correctly mutates the tracked `docs/canonical-sections.md` to prove
      `edm-sync-canonical-sections --check` catches a hand-edit, restoring it afterwards.
- [ ] AC8: `bash plugins/edm/bin/tests/run-all.sh` passes with zero failures **on macOS**, run
      under `/bin/bash` (3.2.57). The run's aggregate output is recorded as the Definition of Done
      item 2 evidence.
- [ ] AC9: Linux is recorded as untested for this initiative, in `decisions.md` as a numbered
      decision with a named follow-on, and `srd.md` Sec.3.4 Definition of Done item 2 states the
      same. No acceptance criterion anywhere in this pack claims a Linux run. The same decision
      states that if a Linux environment is ever named, it is named **concretely** -- an image tag
      and the bash version that image ships -- and the run becomes a manual Definition-of-Done
      step with a recorded result, following the discipline `EDMV4-48` applies to a measured
      latency figure. An unnamed "run it on Linux" item is not acceptable.
- [ ] AC10: The Definition-of-Done command set is run and each result recorded:
      `bash plugins/edm/bin/edm-check-grants`, `bash plugins/edm/bin/edm-check-vocabulary`,
      `bash plugins/edm/bin/edm-check-skill-sync` and
      `bash plugins/edm/bin/edm-sync-canonical-sections --check` all exit 0 (item 3), and
      `claude plugin validate plugins/edm/` exits 0 (item 4).
- [ ] AC11: The `EDM_RUN_ALL_*` knob family still works after the change:
      `harness-smoke.sh` can still point the aggregator at a scratch suite directory via
      `EDM_RUN_ALL_SUITE_DIR` with `EDM_RUN_ALL_PREFERRED_ORDER` and
      `EDM_RUN_ALL_MIN_SUITE_COUNT` overriding both values AC2 changes, and `harness-smoke.sh`
      still passes.
- [ ] AC12: `plugins/edm/CLAUDE.md` Sec."Testing changes" is updated wherever it states a suite
      count or the run procedure, so the documented procedure matches the eight-suite reality.
- [ ] AC13 (**CA-117**): DoD item 8 -- the initiative CHANGELOG entry -- is discharged HERE, by
      this ticket, and `CHANGELOG.md` is in its Target Components above so it can be. The
      cross-cutting "Changelog entry written if initiative has a CHANGELOG" AC that every epic
      ticket carries is **unassignable by every ticket that does not name `CHANGELOG.md`**: an
      implementer satisfying it would be writing outside its own Target Components, which `D34`
      records as a contract violation and correctly praises an implementer for refusing. The AC
      therefore read as satisfied because no single ticket ever failed on it, which is the direct
      mechanism behind CA-025 (`[3.3.0]` shipped omitting every new executable and blocking hook).
      Verify by reading `CHANGELOG.md`'s entry for this release against the set of new or changed
      user-visible surfaces in the initiative -- new `bin/` executables, new hook registrations,
      new environment knobs -- rather than against any list restated in a ticket.
      `tickets/README.md`'s cross-cutting AC block carries the general rule.

### Technical Notes

- `run-all.sh` verified on the current branch: `_PREFERRED_ORDER` at `:39` currently lists seven
  suites (`wave3`, `wave4a`, `wave4b`, `wave5`, `harness`, `wave6`, `wave7`); discovery is the
  glob at `:43-45`; the missing-preferred tripwire is at `:75-86`; `_MIN_SUITE_COUNT` defaults to
  `7` at `:87`. The SRD cites the tripwire as `:73-76`; the block actually spans `:75-86` (the
  comment explaining it starts at `:70`). AC2 is written against the verified lines.
- AC2's second half is the anti-vacuity guard for this ticket. An AC that says "update the
  counting assertion" without naming a line that exists is satisfiable by finding nothing to
  change; `:87` exists on this branch and its current value is `7`.
- `run-all.sh` already runs three of Definition of Done item 3's four checks itself, via
  `_standalone_check` at `:192`, `:201` and `:206` (`edm-check-grants`, `edm-check-skill-sync`,
  `edm-check-vocabulary`). The fourth, `edm-sync-canonical-sections --check`, is exercised inside
  `wave6-smoke.sh` (`:4082-4101`) rather than by the aggregator directly. AC10 still runs all four
  explicitly, because the three standalone checks are **skipped** whenever
  `EDM_RUN_ALL_SUITE_DIR` is set (`run-all.sh:26`), and a Definition-of-Done record should not
  depend on which environment the aggregator happened to run in.
- `wave6-smoke.sh:4087-4099` verified: it copies `docs/canonical-sections.md` to a `mktemp`
  backup, appends `hand-edited, not regenerated`, asserts `--check` fails, then restores. This is
  the existing, correct test AC7's scoping exists to avoid conflicting with.
- The aggregator classifies a suite that emits zero assertions as a failure (`run-all.sh:120-123`),
  so an accidentally empty `wave8-smoke.sh` cannot pass silently.
- `git status --porcelain` in AC7 must be taken with `wave8-smoke.sh` run alone, not as part of
  `run-all.sh`, since a full aggregate run passes through `wave6-smoke.sh`'s deliberate mutation
  window.

### Out of Scope

- Introducing a CI pipeline, a container image, or any remote runner. `srd.md` Sec.3.3 excludes a
  CI pipeline by recorded decision.
- Running the suite on Linux. AC9 records that as a boundary, not a task.
- Adding cases for surfaces this initiative does not build. `wave8-smoke.sh` covers EDMV4's new
  scripts, hooks and library only; pre-existing surfaces stay with their existing suites.
- Restructuring `run-all.sh`'s discovery, ordering or accounting logic. AC2's two line edits are
  the only changes it receives.
- Reordering or renaming any existing suite.

---

## EDMV4-T57: Retarget wave7's pattern-harvest assertions at the delta EDMV4-T18 introduced

| Field | Value |
|---|---|
| Epic | Cross-Cutting |
| Phase | 6 |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV4-63 |
| Depends On | none (`EDMV4-T18` already landed) |
| Blocks | `/edm:verify-runtime` closure of the `EDMV4-T19` and `EDMV4-T20` PARTIALs |
| Target Components | `plugins/edm/bin/tests/wave7-smoke.sh` |

### Description

`EDMV4-T18` moved harvested pattern entries out of the shipped `docs/audit-patterns/*.md` files
and into a delta under the resolved data directory, because the shipped plugin tree is read-only
once a plugin is installed. That was the ticket's entire purpose and the behaviour is correct.

Roughly 35 assertions in `wave7-smoke.sh` predate that move and still look in the shipped tree.
`update-patterns` now reports `no novel findings to append` for those fixtures -- accurately -- and
the assertions treat that as a failure. Nothing is broken. The assertions are looking in the old
place.

No ticket owns them. `EDMV4-T18` did not scope updating the old suite, and `EDMV4-T20` wrote fresh
coverage for the new behaviour in `wave8-smoke.sh` rather than retargeting `wave7`. The gap was
found only after a separate `set -u` abort was fixed and `wave7` ran to completion for the first
time since `T18` landed.

This is on the critical path. `EDMV4-T19` and `EDMV4-T20` both carry PARTIAL verdicts whose
recorded runtime-check is a green `run-all.sh`; that cannot happen while these fail,
`/edm:verify-runtime` cannot close the PARTIALs, and `phase-complete 6` refuses while one remains
open.

### Acceptance Criteria

- [ ] AC1: Every failing assertion in these groups is retargeted at the delta location:
      `CA-002` (AC1, AC2, AC3, AC8, AC9), `T56` (AC1, AC4, and the 22 AC8 run assertions),
      `G16/CA-355`, `G35`, `CA-476`, `CA-531`, `CA-533`.
- [ ] AC2: The delta path is resolved the way the production code resolves it, never hardcoded --
      a test that hardcodes the path passes while the resolution logic is broken.
- [ ] AC3: Each retargeted assertion is proven to still discriminate: a fixture in which the
      harvested entry is absent from the new location must fail it. Passing after the retarget is
      not evidence on its own.
- [ ] AC4: Any assertion genuinely obsolete rather than misdirected is deleted with its reason
      recorded in the commit, not left passing vacuously. Deleting dead coverage is preferred to
      keeping a check that cannot fail.
- [ ] AC5: The three-branch write matrix is NOT re-proven here -- `EDMV4-T20` already covers it in
      `wave8-smoke.sh`. This ticket touches the pre-existing `wave7` assertions only.
- [ ] AC6: `bash plugins/edm/bin/tests/wave7-smoke.sh` reports zero failures except those owned by
      a named, still-open ticket, and every remaining failure names its owning ticket in its
      message or an adjacent comment.
- [ ] AC7: `bash plugins/edm/bin/tests/wave6-smoke.sh` and `wave8-smoke.sh` are unaffected by
      **this** ticket: both still report zero failures, and this ticket's own commits change
      neither file (`git diff --stat <base>..<head> -- plugins/edm/bin/tests/wave6-smoke.sh
      plugins/edm/bin/tests/wave8-smoke.sh` is empty). **CA-067: this AC pinned an absolute
      515/0 for `wave8` and 795/0 for `wave6`.** Both figures were already invalidated by
      `EDMV4-T14`, `T15`, `T28`, `T45` and `T53`, each of which legitimately appended banded
      sections afterwards; `wave8` alone has since passed 500, 735 and 1234. An absolute suite
      count is wrong by construction as an AC for a ticket that does not own the suite -- it can
      never be re-verified, because any later ticket touching that suite falsifies it without
      doing anything wrong. **Convention for any successor AC: pin a DELTA or a touched-files
      claim, never an absolute total.** "Zero failures" is stable; "515 passed" is not.
- [ ] AC8: `bash plugins/edm/bin/tests/run-all.sh` passes with zero failures, so
      `/edm:verify-runtime` can close the `EDMV4-T19` and `EDMV4-T20` PARTIALs.

### Technical Notes

- `EDMV4-T20`'s `wave8-smoke.sh` section is the reference for how the delta is resolved and
  asserted correctly; read it before writing anything here.
- The `T56 AC8` group is 22 of the ~35 and is one loop over ten runs -- fixing the loop's target
  fixes most of the count at once. Do not mistake the assertion count for the work count.
- Line numbers in this ticket are deliberately absent. `wave7-smoke.sh` has been edited by four
  tickets this initiative; locate every site by the literal assertion string.
- `wave7` also carries failures that are NOT yours: the L13/L14 lens agents pending `EDMV4-T26`,
  and `T64 AC1`/`T66 AC3` pending the version and bin/-table cross-cutting work. Leave those.

### Out of Scope

- Changing where `update-patterns` writes. `EDMV4-T18`'s behaviour is correct and settled.
- `EDMV4-T26`'s lens-agent failures in the same suite.
- `bin/tests/run-all.sh` registration, which `EDMV4-T53` owns.
