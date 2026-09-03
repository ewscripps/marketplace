# QC Audit Report: EDMV4 Wave 2 [Shard 4/4]

**Date**: 2026-09-02
**Tickets audited**: EDMV4-T16, EDMV4-T43, EDMV4-T46
**Mode**: `implementation_mode=standard` -- the TDD compliance pass does not run.

Every verdict below is graded against the tree at `bd582cc` (working tree clean), never against an
implementer self-report. `wave8-smoke.sh` was executed (344 passed, 0 failed, matching the stated
clean state) and `bin/edm-check-vocabulary` exits 0 (`CLEAN`). `run-all.sh` was not run.
`wave6-smoke.sh` T27 AC1 and `wave7-smoke.sh` are red by design (`EDMV4-T30`, wave 3) and are not
reported here.

## Summary

| Ticket | Title | Verdict |
|---|---|---|
| EDMV4-T16 | Record ECC and GateGuard provenance in the house-style attribution section | **FAIL** (1 of 7 ACs, P2) |
| EDMV4-T43 | Build the hookify evaluator from nothing, with one classify pass and N projections | **FAIL** (2 of 12 ACs, P1 + P2) |
| EDMV4-T46 | Build `edm-stop-gate` and add it as a second entry in the existing `Stop` block | **FAIL** (1 of 12 ACs, P1) |

All three tickets are functionally correct in the behaviour their ACs describe. Every FAIL below is
a **missing or under-powered assertion**, or a single omitted clause -- not a behavioural defect. I
found no P0.

## Detailed Findings

### EDMV4-T16: ECC and GateGuard provenance -- FAIL

- [x] **AC1** -- ECC entry at `plugins/edm/CLAUDE.md:538-542`. Copyright holder recorded verbatim
      ("MIT License / Copyright (c) 2026 Affaan Mustafa"); I independently confirmed
      `/Users/darryl.porter/projects/ECC/LICENSE:1-3` reads exactly that. Clone revision recorded as
      `ca185ef5`; `git -C /Users/darryl.porter/projects/ECC rev-parse --short HEAD` returns
      `ca185ef5`. The implementer correctly discarded the ticket's own stale `19e2f2b4` and
      re-verified, exactly as the Technical Notes demanded. PASS (one P2 nit below).
- [x] **AC2** -- GateGuard entry at `CLAUDE.md:543-549`. Independently verified against the two
      cited evidence points: `ECC/scripts/hooks/gateguard-fact-force.js:19-20` reads "Full package
      with config support: pip install gateguard-ai" / "Repo: https://github.com/zunoworks/gateguard",
      and `ECC/skills/gateguard/SKILL.md:5` is `  origin: community` under `metadata:` at `:4`. The
      "upstream is Python" claim at `:543` is directly supported by the `pip install` line.
- [ ] **AC3** -- **FAIL (P2).** The GateGuard entry's clean-room note (`CLAUDE.md:550-554`) states
      mechanism-level adoption verbatim ("deny first touch, demand facts, allow on retry ... no text
      was copied from either the Python upstream or ECC's JavaScript port"). The **ECC** entry's
      clean-room note (`CLAUDE.md:541-542`) does not: it reads "L12's taxonomy source
      (`ECC/agents/silent-failure-hunter.md`) was read for its five-category structure only, per
      `EDMV4-T25` -- no text was copied." That satisfies the "no text was copied" half for both
      entries, but AC3 requires **both** entries to state the mechanism-level adoption, and the ECC
      entry states a structural (taxonomy) adoption instead. The deviation is defensible on the
      facts -- what EDM took directly from ECC is L12's taxonomy, and the GateGuard mechanism is
      attributed in the GateGuard entry where it originates -- but unlike the D13 date deviation it
      is **not** sanctioned by the ticket's Technical Notes, so it is graded as written.
- [x] **AC4** -- Both entries use the `caveman`/`ponytail` form. ECC (`:539`): "Licence verified
      2026-08-31 by direct inspection of the local clone's `LICENSE:1-3`". GateGuard (`:547-549`):
      "Licence verified 2026-08-31 by direct inspection of
      `https://raw.githubusercontent.com/zunoworks/gateguard/main/LICENSE` -- a fetched URL, not a
      local clone". A URL alone would not satisfy this AC; the delivered text names the date, the
      means, **and** explicitly disclaims the local clone, so the AC's exclusion does not bite.

  **Judgement on the AC-vs-evidence deviation (the specific thing this shard was asked to rule on):
  the implementer was correct, and this is the strongest part of the delivery.** AC1/AC2's implied
  wording ("verified 2026-08-30 ... by direct inspection of its `LICENSE`") is contradicted by the
  record. `decisions.md:19` (D13) is dated **2026-08-31, amended 2026-09-02** and records the
  GateGuard verification as direct inspection of the `raw.githubusercontent.com` URL, not a clone.
  The delivered text matches D13 clause for clause -- the date, the fetched-URL means, the explicit
  "not a local clone" disclaimer, the copyright string "Copyright (c) 2026 Hirokazu Seto / ZUNO
  WORKS K.K.", and a `(decisions.md D13)` citation. Recording a weaker-but-true provenance instead
  of a stronger-but-false one is what AC4 exists to force, and the ticket's own Technical Notes
  directed exactly this ("Record what D13 actually supports"). No finding.

- [x] **AC5** -- `CLAUDE.md:512` reads "**Six sources, with licence and location, matching the
      enumeration this subsection uses**". Machine-counted six top-level bullets in the list below
      it: `:514` opus-5, `:517` sonnet-5, `:520` caveman, `:528` ponytail, `:538` ECC, `:543`
      GateGuard. Prose count and bullet count agree. The string "Four sources" no longer appears
      anywhere in the file.
- [x] **AC6** -- `bin/tests/wave8-smoke.sh:1070` asserts `zunoworks` and `:1071` asserts `MIT`,
      both against `$T16_SECTION`, which `:1061-1065` extracts from the house-style heading to the
      next `##` heading -- so an unrelated `MIT` elsewhere in `CLAUDE.md` cannot satisfy it, which
      is the AC's stated point. `:1086` carries an explicit positive control (`caveman` must also
      appear) proving the extraction is non-empty rather than empty-but-truthy. `:1067-1068` fails
      loudly if the section cannot be located at all.
- [x] **AC7** -- `CLAUDE.md:556-562`, stated once (the only `NOTICE` occurrences in the file are
      `:556` and `:560`). **The R17 wiring is correct and I verified it three ways.** The trigger is
      "if AD1 is ever reversed to vendoring **by any route**" (`:558`), enumerated open-endedly as
      "`EDMV4-59` rejected at a later gate, or any subsequent decision directing vendoring"
      (`:558-559`) -- not any single gate outcome. `EDMV4-05` (the destructive-`Bash` descope, the
      wrong trigger R17 named) appears **zero** times in the extracted section. All three bound
      obligations are present and conjoined ("three things bind together"): unmodified copyright
      headers (`:560`), a `plugins/edm/NOTICE` naming ZUNO WORKS K.K. and Affaan Mustafa with their
      MIT texts (`:560-561`), and `EDMV4-56`'s required-binary set re-presented at the gate
      (`:561-562`). The clause ships dormant on the strength of D14's ratification (`:556-557`).
      The one wording change from the AC -- "rejected at **a later gate**" where the AC says
      "rejected at **Gate 2**" -- is a necessary correction, not a drift: `decisions.md:21` (D14)
      records Gate 2 as already RATIFIED on 2026-09-02, so "rejected at Gate 2" is a counterfactual
      that could never fire and would have left the obligation dormant with nothing to wake it --
      R17's exact failure mode.

**Findings**:

```
[P2] EDMV4-T16 | plugins/edm/CLAUDE.md:541-542 | AC#3: Both entries carry a clean-room note ... stating that the adoption is mechanism-level (deny first touch, demand facts, allow on retry) | The ECC bullet's clean-room note states a structural (five-category taxonomy) adoption, not the mechanism-level adoption AC3 requires of both entries. The GateGuard bullet at :550-554 states it correctly. Fix: add one clause to the ECC note, or amend AC3 through gate change control on the argument that the mechanism belongs to the GateGuard entry alone.
[P2] EDMV4-T16 | plugins/edm/CLAUDE.md:539 | AC#1: ... the local clone inspected ... | The ECC entry says "the local clone's LICENSE:1-3" without naming the clone path, where the sibling caveman (:522) and ponytail (:530) entries both give the absolute path ("the local clone at /Users/darryl.porter/projects/caveman"). Re-checkability is preserved by the recorded revision + repo URL, so this is form, not substance. Fix: append "at /Users/darryl.porter/projects/ECC".
```

**Not a finding, recorded for the reader**: the blank line at `CLAUDE.md:537` between the `ponytail`
and `ECC` bullets makes the six-item list render "loose" (every item wrapped in `<p>`) where the
other five items are tight. Cosmetic; the list is still one list of six and AC5 is unaffected.
Separately, AC6's `MIT` half is weak on its own -- the pre-existing `caveman`/`ponytail` entries
already carry `MIT`, so that one assertion would survive deletion of both new entries. The
`zunoworks` assertion plus the sibling assertions at `:1072-1082` (`everything-claude-code`,
`Affaan Mustafa`, `Hirokazu Seto`, `gateguard-fact-force.js`, `Six sources`) make the set as a whole
a real tripwire. This is the AC's own design, not an implementation defect.

### EDMV4-T43: hookify evaluator -- FAIL

- [x] **AC1** -- `bin/edm-hookify` exists, mode `0755`. Subcommand dispatch at `:69-89`; `eval`'s
      event argument is validated against exactly `file|bash|stop` at `:81-84`; the stdin payload is
      drained at `:132-135`. Exercised live: `list` enumerated three rules one per line; `eval bash`
      and `eval stop` each matched their event's rule; a malformed rule produced
      `edm-hookify: setup error: <path>: invalid JSON` on stderr with the other rule still evaluated
      and exit 1.
- [x] **AC2** -- Exactly one `jq` invocation exists in the whole script (`:228`); every other
      occurrence of the token is prose or the `command -v jq` guard at `:126`. The design is the
      required one-classify-pass shape: `build_rule_stream` (`:147-153`) NUL-joins every rule file's
      bytes into that single `jq -R -s` call, and all N rules are projected inside the one jq program
      (`:200-225`), with per-rule malformed handling done via `try/catch` at `:207` rather than a
      per-file jq call.
- [x] **AC3** -- `wave8-smoke.sh:1926-1978`. **The shim is not vacuous, and I verified this three
      ways.** It appends a line to a counter file and then `exec`s the real `jq` (`:1929-1933`, with
      `$(command -v jq)` expanded at heredoc-write time so it cannot recurse); it is prepended to
      `PATH` ahead of the real binary (`:1965`, `:1970`); the counter is reset immediately before
      each arm (`:1964`, `:1969`) and **after** the fixture-building `jq` calls at `:1961-1962`, so
      fixture construction is not counted. The assertion at `:1974` is
      `1RULE == 50RULE && 1RULE -ge 1` -- the `-ge 1` conjunct is a genuine positive control that
      rejects the vacuous `0 == 0` pass. Observed on the live run: **1 spawn each**.
- [x] **AC4** -- `edm-hookify:256` emits `"${_mname} ${_maction} ${_mmessage}"`, message last.
      Asserted at `wave8-smoke.sh:1894-1896`; confirmed live
      (`block-rm-rf-bash block Refusing a bash command matching rm -rf; ...`, message containing
      spaces).
- [x] **AC5** -- `edm-hookify:214` (`elif ($parsed.enabled != true) then empty`) short-circuits
      before any condition is evaluated or counted. `wave8-smoke.sh:1899-1906` uses a fixture whose
      disabled rule would otherwise match and asserts no output. Confirmed live: flipping
      `warn-no-console-log` to `enabled: false` dropped it from `list` output too.
- [x] **AC6** -- Truncation applied before any operator runs (`cap()` at `:164`, applied at `:198`
      inside `conds_match` before `op_match`). Ceiling and rationale stated in all three required
      places: in-file at `:137-139`, in the `EDM-HELP-BEGIN` block at `:27-35`, and in
      `CLAUDE.md:1155`. See the NOTED entry below on the unit.
- [x] **AC7** -- `grep -c 'timeout' plugins/edm/bin/edm-hookify` returns **1**, and that single
      occurrence is `:30`, inside the rationale comment ("CAP, not a timeout -- `timeout(1)` is a
      GNU coreutils binary absent from stock macOS"). No `timeout` invocation exists, so the AC's
      conditional fallback clause is not yet engaged.
- [ ] **AC8** -- **FAIL (P2).** The cap half is met with a proper positive control
      (`wave8-smoke.sh:2002-2005`: a marker only past 65536 chars does not fire, and the same rule
      *does* fire when the marker is inside the ceiling). The **timing** half is not: `:1992-1998`
      measures with `date +%s`, whole-second granularity, and `:2006` compares
      `HUGE <= NORMAL * 20 + 5`. On the live run both arms measured **0s**, so the comparison
      degenerated to `0 -le 5` -- a fixed five-second ceiling that cannot discriminate 40 ms from
      4 s and therefore does not assert "the same order of magnitude as a normal call". The
      variables are also named `T43_HUGE_MS`/`T43_NORMAL_MS` while holding seconds (`:1999-2000`).
- [ ] **AC9** -- **FAIL (P1).** The behavioural half holds: I ran the AC's own grep
      (`grep -nE '>[^&]|>>|tee|mktemp'`) over the script and every hit is either help-block prose
      (`:17`, `:37`), a `<file|bash|stop>` usage literal (`:74`, `:83`), a `>/dev/null` or `>&2`
      redirection (`:99`, `:116`, `:126`), or a `> 0` comparison inside the jq program (`:168`,
      `:176`, `:180`). No file write exists; no `tee`, no `mktemp`, no temp file anywhere. But AC9
      requires this be "asserted by a smoke test that runs `eval` with the rule directory and the
      plugin tree mounted read-only", and **no such test exists**. `wave8-smoke.sh:1909-1915`
      substitutes a static grep over the script text -- it never invokes `eval`, never makes
      anything read-only, and carries no positive control. I probed that substitute grep against
      synthetic positives and it has two blind spots (evidence in the finding below).
- [x] **AC10** -- `edm-hookify:119-124` exits 0 on an empty `RULE_FILES` array, **before** the
      `command -v jq` guard at `:126`, so an absent `.claude/edm-hookify/` spawns no jq at all.
      Asserted with the same counting shim at `wave8-smoke.sh:1936-1947`; observed rc=0 and **0**
      jq spawns on the live run. (The AC's parenthetical binds "zero enabled rules" to the absent
      directory as one scenario; a directory of files all `enabled: false` still spawns one jq,
      which is unavoidable -- determining that a rule is disabled requires parsing it.)
- [x] **AC11** -- Sources the library at `:56`; calls `print_help "${BASH_SOURCE[0]:-$0}"` at `:65`
      (the caller-path form `_edm-cli-lib.sh:25-28` requires); sentinels at `:5` and `:52`;
      `SCRIPT_DIR` at `:55` in the house idiom. On the shared `die()`: `_edm-cli-lib.sh` defines
      only `print_help`, so `die()` is a per-script convention -- `edm-hookify:58-62` is
      shape-identical to `edm-repo-readiness:50-54` (the `EDMV4-36` reference this AC names),
      differing only in the script-name prefix and the default exit code, which correctly matches
      this script's own documented `1`-for-setup-error contract.
- [x] **AC12** -- `CLAUDE.md:1155`, same two-column form as the surrounding rows.

**Findings**:

```
[P1] EDMV4-T43 | plugins/edm/bin/tests/wave8-smoke.sh:1909-1915 | AC#9: The evaluator never writes to any file ... asserted by a smoke test that runs `eval` with the rule directory and the plugin tree mounted read-only | The required smoke test does not exist. What ships is a static grep over the script text that never invokes `eval` and never makes any path read-only, and it carries no positive control, so its two blind spots are invisible in the suite's green output. Probed and reproduced: (a) appending `echo x > /tmp/leak.txt` to a copy of edm-hookify produces NO HIT -- the alternation `>[[:space:]]*"?\$[A-Za-z_]` only matches a redirect into a $VAR path, never a hardcoded one; (b) appending `echo x > "$SOMEFILE" 2>&1` produces NO HIT -- the `grep -v '2>/dev/null\|>&2\|2>&1'` filter at :1910 excludes the whole LINE, so any real write sharing a line with a stderr redirect is swallowed. Control (c) `echo x > "$SOMEFILE"` alone does hit, confirming the probe method. Fix: add the missing runtime assertion (`chmod -R a-w` over a scratch rule dir + a copy of the plugin tree is the feasible stand-in -- a literal read-only mount needs root on macOS), run `eval` against it, and assert exit 0 with no new files; and add a positive control for the static grep by running it against a deliberately-broken copy, the pattern wave8-smoke.sh:44-54 already establishes for EDMV4-T05 AC5.
[P2] EDMV4-T43 | plugins/edm/bin/tests/wave8-smoke.sh:1992-2010 | AC#8: ... asserts ... that the call returns within the same order of magnitude as a normal call | Timing is measured with `date +%s` (whole seconds). Both arms measured 0s on the live run, so the assertion at :2006 reduces to `0 -le 5`: a fixed 5-second ceiling that would pass a 100x regression. Variables :1999-2000 are named `_MS` but hold seconds. Fix: reuse the bash-3.2-safe sub-second timer already shipping at bin/tests/timing.sh:56-71 (perl Time::HiRes with a documented whole-second degradation) and assert a real ratio.
```

**NOTED (not remediated)**: AC6's cap is expressed in **characters**, not bytes -- `jq`'s
`$s[0:$maxchars]` at `edm-hookify:164` is a codepoint slice, so 65536 chars of 4-byte UTF-8 is
262144 bytes, 4x the stated 64 KiB. This is disclosed rather than hidden, in all three places AC6
names (`edm-hookify:28-29`, `:137-138`, `CLAUDE.md:1155` -- each says "65536 characters (64 KiB for
ASCII content)"), and characters are the correct unit for bounding Oniguruma's per-codepoint regex
cost, which is what the cap exists to bound. Intentional and documented trade-off.

### EDMV4-T46: `edm-stop-gate` -- FAIL

- [x] **AC1** -- `edm-stop-gate:73` calls `edm-state active-initiatives` with no argument. The sweep
      is not re-implemented and no prefix is derived from cwd. Parsing at `:80-88` selects on
      `*"phase="*` and takes the first whitespace-delimited field, so both sentinel lines
      (`  (no active initiatives)`, `(no SRD/ directory)`) are ignored by construction -- neither
      contains `phase=`. Not parsed by column position, so the `%-12s` padding is not a hazard.
- [x] **AC2** -- Per-initiative loop at `:96-137`; `ANY_BLOCKING` is set on any blocking hit
      (`:129`) and the message names the prefix (`:130`). `wave8-smoke.sh:2115-2137` builds two
      active initiatives (`T46CLEAN` clean, `T46BLOCK` carrying an open PARTIAL) and asserts exit 2,
      that the message names `T46BLOCK`, and that the full `blocking  OPEN_PARTIALS` text is
      present. All observed passing on the live run.
- [x] **AC3** -- `edm-stop-gate:92` exits 0 with no output when zero prefixes were parsed.
      `wave8-smoke.sh:2076-2083` asserts rc=0 and `-z` on a **combined** `2>&1` capture, so zero
      bytes on both streams is genuinely asserted. Observed passing.
- [x] **AC4** -- `edm-stop-gate:134-136` emits exactly
      `[EDM] ${_info_count} informational anomalies (run: edm-state validate ${_prefix})`, matching
      the AC's literal form; blocking text is printed verbatim at `:131` while `info` lines are only
      counted (`:121-122`). **I independently reproduced the AC4 fixture** (scratch git repo,
      isolated `HOME`, `edm-state init` + `current_phase=2` + `del(.schema_version)` +
      one `skipped_phases` entry) and confirmed `edm-state validate` emits exactly the four routine
      anomalies AC4 names -- `SIZE_UNKNOWN`, `PERM_RULES_MISSING`, `SCHEMA_VERSION_MISSING`,
      `ACTIVE_EXEMPTION` -- and that `edm-stop-gate` collapsed them to the single line
      `[EDM] 4 informational anomalies (run: edm-state validate T46INFO)` with rc=0. The smoke
      assertions at `:2103-2110` (exit 0, exactly one line, count matches `validate`'s own `info`
      count) all pass, and the live run printed the count as `4`.
- [x] **AC5** -- **Validate-only confirmed; no hookify evaluation leaked in.**
      `grep -n 'edm-hookify' bin/edm-stop-gate` returns nothing; the only case-insensitive `hookify`
      match in the whole script is `:10`, a scope-disclaimer comment ("Hookify `stop`-rule
      evaluation is NOT wired here"). The gate's only external calls are `edm-state
      active-initiatives` (`:73`) and `edm-state validate` (`:99`). The smoke check at
      `wave8-smoke.sh:2029-2030` is **not** self-matching: its needle is the hyphenated
      `edm-hookify` and the haystack is `edm-stop-gate`'s content (not the test file's own prose),
      and the script's one prose mention is the un-hyphenated `Hookify`, so the assertion
      discriminates correctly.
- [x] **AC6** -- `hooks/hooks.json`: `.hooks.Stop | length` = **1** matcher block, and
      `.hooks.Stop[0].hooks | length` = **2**, both entries `"type": "command"` -- AD4's
      homogeneous shape exactly. No second matcher block was added. `PreCompact` still carries its
      single entry, untouched. Asserted at `wave8-smoke.sh:2035-2038`.
- [x] **AC7** -- **Byte-identity proven from the diff, not just the pin.** `git log -p` over
      `plugins/edm/hooks/hooks.json` shows the checkpoint entry's command line
      (`command -v edm-state >/dev/null 2>&1 && edm-state checkpoint-if-active || true`) as an
      unchanged **context** line; the only `+` lines are the new entry and its braces.
      `wave8-smoke.sh:2039-2041` additionally pins that exact string against
      `.hooks.Stop[0].hooks[0].command`, so a future edit cannot silently reformat it.
- [x] **AC8** -- Every operator-facing write is `>&2` (`edm-stop-gate:65`, `:130`, `:131`, `:135`);
      no `echo`/`printf` to stdout exists anywhere in the script. `wave8-smoke.sh:2100/2105-2106`
      (informational case) and `:2127/2134-2135` (blocking case) capture stdout separately with
      `2>/dev/null` and assert it is empty. Both observed passing.
- [ ] **AC9** -- **FAIL (P1).** The **behaviour** is correct and I verified it directly with a fake
      `edm-state`, per this shard's brief. With a fake that serves `active-initiatives` normally but
      makes `validate` write to stderr and exit **1**, the gate exits **0** silently; with a fake
      whose `validate` exits **3** with a `blocking` line, the gate exits **2** and names the
      prefix. `edm-stop-gate:104-107` (`case "$_validate_rc" in 0|3) ;; *) continue ;;`) is the
      correct exit-3-only test, matching `bin/edm-state:4159` (`return 3`). What fails is the AC's
      explicit test requirement: "A smoke test covers each of those four internal-error paths." The
      fourth path -- "`validate` itself failing or `die`ing" -- has **no smoke test**, and the
      `t46_ac9_case` fake-`jq` arm does not reach it (evidence in the finding below).
- [x] **AC10** -- `.hooks.Stop[0].hooks[1].command` is
      `command -v edm-stop-gate >/dev/null 2>&1 || exit 0; edm-stop-gate`, carrying the AC's exact
      guard prefix. Asserted at `wave8-smoke.sh:2042-2044`.
- [x] **AC11** -- `decisions.md:35` (D25) records Spike A run against `claude --version` `2.1.246`
      and reports the AC5 homogeneous-pair experiment specifically: one `Stop` block,
      `hooks: [entry1, entry2]`, both `"type": "command"` -- "entry1 and entry2 both ran on both
      Stop-event firings, and entry2's exit 2 WAS honored on the first firing despite entry1 exiting
      0 in the same array". It also records that Spike A's own AC7 branch (only the first entry runs)
      did **not** occur, so no re-presentation of a second `Stop` matcher block is triggered, and
      that the pre-spike count of homogeneous command-plus-command pairs anywhere in this repository
      was grep-verified as **zero** -- so `hooks.json:16-24` is correctly not cited as establishing
      the shape. D25 carries a standing caveat that this is one host version's behaviour and should
      be re-run against a materially different Claude Code version; that is a recorded condition,
      not an unmet criterion.
- [x] **AC12** -- `CLAUDE.md:1028`'s Hooks behavior table now carries a dedicated `Stop` row
      (documenting the two-entry array, `edm-stop-gate`, the exit-3-not-1 detail, the exit-0
      internal-error contract, the silent zero-initiative case and the one-line informational
      collapse) and a separate `PreCompact` row ("single entry, unchanged"). The collapsed row is
      gone, asserted at `wave8-smoke.sh:2048-2049`.

**Findings**:

```
[P1] EDMV4-T46 | plugins/edm/bin/tests/wave8-smoke.sh:2140-2161 | AC#9: A smoke test covers each of those four internal-error paths | Three of four are covered (edm-state off PATH at :2144; no resolvable initiative at :2076-2083; broken jq at :2157). The fourth -- "`validate` itself failing or `die`ing" -- has no test, and the fake-jq arm does NOT reach that code path: I ran `edm-state active-initiatives` under the same fake `jq` (`#!/bin/sh; exit 1`) and it prints "  (no active initiatives)" and exits 0, so edm-stop-gate short-circuits at :92 and never enters the loop at :96. That leaves edm-stop-gate:104-107 -- the single line that keeps a routine `die` (exit 1) from being converted into a `Stop` block, the exact hazard the ticket's Technical Notes calls out -- with zero automated coverage. The behaviour is correct today (verified by hand); nothing would catch a regression. Fix: add a fourth arm using a fake `edm-state` on PATH that serves `active-initiatives` normally and makes `validate` exit 1 on stderr, asserting the gate exits 0; and a companion arm whose `validate` exits 3 with a `blocking` line, asserting exit 2 -- the pair is what pins "only 3 blocks".
[P2] EDMV4-T46 | plugins/edm/bin/tests/wave8-smoke.sh:2100 | AC#4/AC#8 harness | Latent `set -e` suite abort of the class commit bd582cc is actively remediating: `stdout_only="$(edm-stop-gate 2>/dev/null)"` has no `|| true` guard under the file's `set -euo pipefail` (:7). It survives only because the T46INFO fixture happens to exit 0. The identical call in the blocking case at :2127 DOES carry `|| true`, so the omission is inconsistent rather than deliberate. If that fixture ever grows a blocking anomaly, the suite aborts silently at this line and every later assertion -- T46 AC2/AC8/AC9 and the entire EDMV4-T18 section -- stops running while the suite still reports a green tail. Fix: append `|| true`.
[P2] EDMV4-T46 | plugins/edm/CLAUDE.md:1156 | AC#12 adjacent | The bin/ table's edm-stop-gate row says "see \"Hooks behavior\" below", but the Hooks behavior section is at :1028 -- above the bin/ table at :1136. Fix: "above".
```

## Remediation Required

Ordered by severity, then by blast radius. No P0 findings. Every item is a test or documentation
change; no shipped behaviour needs to change.

1. **[P1] `EDMV4-T46` AC9 -- add the missing fourth internal-error arm.**
   `plugins/edm/bin/tests/wave8-smoke.sh`, inside `t46_ac9_case` (`:2140-2160`). Add a fake
   `edm-state` on `PATH` that answers `active-initiatives` with one real-looking
   `  FAKEPFX      phase=2  last_updated=...` line and makes `validate` write to stderr and
   `exit 1`; assert the gate exits **0**. Add the mirrored arm whose `validate` exits **3** with a
   `blocking  ...` line; assert exit **2**. Only that pair actually pins `edm-stop-gate:104-107`,
   the one line standing between a routine `die` and a `Stop` block.

2. **[P1] `EDMV4-T43` AC9 -- build the read-only assertion the AC names, and give the static grep a
   positive control.** `plugins/edm/bin/tests/wave8-smoke.sh:1909-1915`. Run `eval` against a
   scratch rule directory and plugin-tree copy made read-only with `chmod -R a-w` (a literal mount
   needs root on macOS; note the substitution in a comment), asserting exit 0 and no new files.
   Separately, prove the static grep discriminates by running it against a deliberately-broken copy
   carrying `echo x > "$F"`, following the `EDMV4-T05` AC5 pattern at `:44-54`. While there, widen
   the pattern to catch a redirect into a hardcoded path and switch the `2>/dev/null|>&2|2>&1`
   exclusion from line-level to token-level.

3. **[P2] `EDMV4-T43` AC8 -- measure sub-second.** `wave8-smoke.sh:1992-2010`. Replace `date +%s`
   with the bash-3.2-safe timer already shipping at `bin/tests/timing.sh:56-71`, assert a real
   ratio, and rename `T43_HUGE_MS`/`T43_NORMAL_MS` to match their unit.

4. **[P2] `EDMV4-T16` AC3 -- one clause.** `plugins/edm/CLAUDE.md:541-542`. Either add the
   mechanism-level statement to the ECC entry's clean-room note, or take the alternative through
   gate change control on the argument that the mechanism belongs to the GateGuard entry alone.
   Do not silently leave it as-is; the AC as approved requires both entries to carry it.

5. **[P2] `EDMV4-T46` harness -- `|| true` at `wave8-smoke.sh:2100`.** One token; closes a latent
   silent-abort of the class `bd582cc` is already sweeping.

6. **[P2] `EDMV4-T16` AC1 -- append the clone path** at `CLAUDE.md:539`, matching the
   `caveman`/`ponytail` form.

7. **[P2] `EDMV4-T46` -- "below" should be "above"** at `CLAUDE.md:1156`.

No PARTIAL verdicts were recorded for this shard. Every acceptance criterion across the three
tickets was statically verifiable, and where a criterion looked runtime-bound -- the jq spawn
counts, the anomaly-suppression count, the exit-3-only contract, the Spike A host behaviour -- it
was resolved by executing the suite, reproducing the fixture by hand, or reading the recorded
experiment in `decisions.md` D25, so nothing is left for `/edm:verify-runtime`.

<!-- QC-SHARD-COMPLETE range=EDMV4-T16..EDMV4-T46 assigned=3 audited=3 -->
