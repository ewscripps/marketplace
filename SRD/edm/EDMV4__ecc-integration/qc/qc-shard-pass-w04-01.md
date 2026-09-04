# QC Audit Report: EDMV4 -- ECC Integration, Wave 4 [Shard 1/1]

**Date**: 2026-09-03
**Tickets audited**: `EDMV4-T14`, `EDMV4-T15`, `EDMV4-T26`, `EDMV4-T45`, `EDMV4-T56`, `EDMV4-T57` (6 of 6)
**Tree audited**: `edm/edmv4-ecc-integration` @ `6386a52`, main working tree (no worktree)

Wave 4 drained without a QC pass -- the post-wave shard count ran after wave 3 and was never
repeated, the exact silent-absence failure `EDMV4-61`/`T55` AC5 exists to prevent. These six
tickets were merged and Phase 6 was closed with no acceptance-criteria verification. Every claim
below was re-derived from the tree; nothing was carried forward from a ticket's own assertion.

`run-all.sh` was not run (a concurrent code audit held the tree). Where an AC's only evidence
would have been a green suite, that clause is graded PARTIAL, not PASS -- this initiative
produced eleven `set -e` aborts that ended a suite with no failing assertion, so a reported green
figure is not self-evidencing. Every other verdict rests on code read at `file:line` or on a
direct scratch-directory execution I ran myself.

## Summary

| Ticket | Title | Verdict |
|---|---|---|
| `EDMV4-T14` | Fact-forcing denial content and the per-file `MultiEdit` loop | **FAIL** |
| `EDMV4-T15` | GateGuard's operational safety controls | **FAIL** |
| `EDMV4-T26` | Lens L13 -- Type Design, with auto-N/A on an untyped stack | **PASS** |
| `EDMV4-T45` | Wire hookify events to their single owners, `bash` gated on Spike A | **PARTIAL** |
| `EDMV4-T56` | Document the three plugin locations and the push-to-observe constraint | **PASS** |
| `EDMV4-T57` | Retarget wave7's pattern-harvest assertions at the `T18` delta | **FAIL** |

**Totals**: 2 PASS, 1 PARTIAL, 3 FAIL. Three FAIL findings (1 P0, 1 P1, 1 P2), five P2
observations, one PARTIAL.

---

## Detailed Findings

### `EDMV4-T14`: Fact-forcing denial content and the per-file `MultiEdit` loop -- FAIL

I executed the gate directly against a scratch marker environment rather than reading the smoke
test's verdict. The captured `Edit` denial is exactly four numbered facts, in the specified
order, ASCII-clean:

```
1. List all files that import or require this file (src/foo.js), searching the tree.
2. List the public functions or classes affected by this change.
3. If this file reads or writes data files, show field names, structure and date format using redacted or synthetic values -- never raw production data.
4. Quote the acceptance criteria of the ticket being implemented, by its {PREFIX}-T{NN} ID.
```

- [x] **AC1** -- Exactly four facts, in order. `bin/edm-gateguard:330-335` is a single
      `printf '%s\n%s\n%s\n%s'` over four arguments, so the count and order are structural, not
      incidental. Confirmed by live capture above (4 lines).
- [x] **AC2** -- `Write` swaps facts 1/2 (`:324-325`) and reuses facts 3/4 byte-identically from
      the same `printf` at `:330-335`. `wave8-smoke.sh:4119-4120` additionally asserts the `Edit`
      import-search fact is *absent* from a `Write` denial, so the swap is proven in both
      directions.
- [x] **AC3** -- Fact 4 is the ticket-AC form at `:334`;
      `grep -c 'quote the user.s current instruction' bin/edm-gateguard` returns 0, and
      `wave8-smoke.sh:4125-4129` pairs that zero with a positive control that injects the phrase
      and confirms the detector fires. The zero is not vacuous.
- [x] **AC4** -- `:375-383` extracts `.tool_input.file_path` and `.tool_input.edits[]?.file_path?`
      into one `unique` list (tolerant of both payload shapes, per the ticket's Technical Notes)
      and iterates; `gg_maybe_deny` reaches `emit_decision`, which `exit`s, so the loop returns on
      the first still-unchecked path without evaluating the rest. The here-string loop is not a
      subshell, so the `exit` is the script's. `wave8-smoke.sh:4139-4163` drives the three-file
      batch and asserts three distinct-path denials plus a silent fourth-call allow.
      **On the `MultiEdit` caveat**: the fixture is synthetic and the test says so in its own
      comment (`:4133-4136`) -- it asserts the script's iteration logic, and explicitly disclaims
      any claim about a live host's `MultiEdit` shape, which D26 records as UNTESTABLE. No
      assertion here claims `MultiEdit` denial *works* on a host, so nothing is overclaimed.
- [x] **AC5** -- A fully-checked batch short-circuits at `gg_is_checked` (`:347`) before any
      denial, falling through to `emit_decision allow` (`:412`). Asserted at
      `wave8-smoke.sh:4167-4177` with a pre-seeded checked-file (exit 0, empty stdout).
- [x] **AC6** -- `LC_ALL=C grep -c '[^ -~]'` over the live-captured denial returns **0**.
      `emit_decision` additionally sanitizes with `tr -c '\011\012\015\040-\176' '?'` at `:163`
      *before* the payload reaches `jq`. `wave8-smoke.sh:4192-4197` pairs the scan with a real
      UTF-8 em-dash injection control.
- [ ] **AC7** -- **FAIL**. See finding below.
- [x] **AC8** -- `wave8-smoke.sh:4087-4094` (four `Edit` facts) and `:4111-4114` (two swapped
      `Write` facts) each match on a distinctive per-fact substring, never the whole block.

**Finding**: [P2] `EDMV4-T14` | `plugins/edm/bin/edm-gateguard:324` | AC#7: "No text is copied
verbatim from `gateguard-fact-force.js`" is provably false. The `Write` fact-1 string
`Name the file(s) and line(s) that will call this new file` is word-for-word identical to
`/Users/darryl.porter/projects/ECC/scripts/hooks/gateguard-fact-force.js:1085` (clone `ca185ef5`),
differing only by an appended `(${path})`. Two more facts are minimal-edit paraphrases with long
verbatim runs: `:328` vs ECC `:1070` (`functions/classes` -> `functions or classes`) and `:333` vs
ECC `:1086`-adjacent fact 3. Only fact 4 is genuinely re-expressed.

Two things make this worth fixing rather than waiving:

1. **AC2 and AC7 are in direct conflict.** AC2 dictates the exact phrase ("swaps facts 1 and 2
   for: name the file(s) and line(s) that will call this new file") that AC7 forbids as verbatim
   copying. The implementer followed AC2 literally and could not satisfy both. That is a ticket
   defect, not an implementer error.
2. **`CLAUDE.md`'s MIT NOTICE dormancy argument rests on AC7.** `plugins/edm/CLAUDE.md`'s "Prompt
   conventions (house style)" states the NOTICE obligation "binds only on verbatim reuse, and
   AD1's ratified bash rewrite produces none." That clause is now inaccurate. There is no licence
   exposure -- GateGuard is MIT and attribution with copyright holder is already recorded in the
   same section (D13/D14) -- but the stated basis for dormancy is wrong.

**Root cause**: no assertion anywhere checks AC7. `wave8-smoke.sh` has no verbatim-overlap scan
against the ECC source, so this clean-room claim shipped with zero verification. AC3's
`quote the user's current instruction` check is the only clean-room-adjacent assertion, and it
covers one phrase, not the fact set.

---

### `EDMV4-T15`: GateGuard's operational safety controls -- FAIL

The vacuity risk this ticket was flagged for is **genuinely closed**. Every kill-switch,
exemption and staleness assertion is paired with a control that proves the gate could have fired:

| AC | Positive direction | Paired negative | Site |
|---|---|---|---|
| AC1 | 5 spellings each exit 0 | unswitched fixture denies (rc 2) first | `wave8-smoke.sh:4220-4236` |
| AC2 | `=1` exits 0 | `=true`/`=yes` must still **deny** (rc 2 asserted) | `:4252-4263` |
| AC3 | `stat` spy silent under switch | spy proven to fire with switch off | `:4306-4340` |
| AC4 | both path forms exempt | `src/unrelated.js` still denies | `:4360-4368` |
| AC5 | `SRD/` exempt by default | `/repo/src/main.js` still denies | `:4383-4390` |
| AC6 | stale file -> denies | -- (asserts the deny, not the quiet) | `:4421-4438` |
| AC11 | deleted-dir marker allows | identical marker naming a live dir denies | `:4519-4532` |

Each of these asserts the gate *firing* somewhere, so "the gate stayed quiet" is never the whole
of any claim.

- [x] **AC1** -- `bin/edm-gateguard:80-82`, a `case` over the five literals, before anything else.
- [x] **AC2** -- `:83-85`, literal `1` only.
- [x] **AC3** -- Kill switches at `:80-85` precede the datadir-lib source at `:88-91`; the
      `stat`-spy pairing at `wave8-smoke.sh:4306-4340` proves no marker `stat` and no
      session-state read occurs under a mode-000 data path. (See P2 note 1 below on the AC's
      broader "zero filesystem reads" phrasing.)
- [x] **AC4** -- `gg_is_exempt` at `:293-315` normalises `**` to `*` and tests each glob twice,
      as-is and with a leading `*/` stripped -- the explicit fix for ECC's relative-path gotcha.
- [x] **AC5** -- `GG_EXEMPT_GLOBS_DEFAULT` at `:292` covers `SRD/`, four test-tree shapes,
      `dist`, `build`, `node_modules`, `.git`.
- [x] **AC6** -- 500-entry cap via `tail -n 500` at `:262`; 30-minute staleness via
      `gg_fresh_lines` at `:228-240` with the required GNU/BSD `stat` fallback pair at `:232`
      (`find` correctly avoided per `EDMV4-07` AC7).
- [ ] **AC7** -- **FAIL**. See finding below.
- [x] **AC8** -- `:348-351`, default 3, stderr advisory then allow.
- [x] **AC9** -- `:120-121` guards the gated path only; nothing above `:120` references `jq`. The
      distinction is stated inside the `EDM-HELP-BEGIN` block at `:42-44`. The marker-absent half
      is asserted separately at `wave8-smoke.sh:3386-3414` with a jq-spy positive control.
- [x] **AC10** -- `:127-133`, `die` at exit 1, stdout empty.
- [x] **AC11** -- `:105-114`, pure-bash field extraction, no `jq`.
- [x] **AC12** -- All six variables documented at `plugins/edm/CLAUDE.md:1600-1620` in the
      required bullet form, each with its default and an explicit "Unset (the default)..." clause.

**Finding**: [P0] `EDMV4-T15` | `plugins/edm/bin/edm-gateguard:252-269, 343-355` | AC#7: "Every
state-write failure path **allows**, with a stderr warning naming `EDM_GATEGUARD_STATE_DIR` ...
**never a deny**" -- the implementation does the exact opposite, and the smoke test was written to
assert the implementation rather than the AC.

`gg_mark_checked` warns and `return 0`s on write failure (`:255-258`, `:265-268`); control returns
to `gg_maybe_deny`, which proceeds straight to `gg_record_denial` and `emit_decision deny`
(`:352-354`). There is no allow path on a state-write failure anywhere in the file.

I reproduced the consequence directly -- a scratch project, marker present, `run/` at mode 555,
the same path six times:

```
call 1 -> rc=2   call 2 -> rc=2   call 3 -> rc=2
call 4 -> rc=2   call 5 -> rc=2   call 6 -> rc=2
```

**The denial budget does not bound it.** `gg_record_denial` writes its temp file into the same
read-only `run/` directory (`:282-284`), so no `.denials` file is ever created (confirmed: the
directory listing after six calls holds only the `.phase6` marker), `gg_denial_count` returns 0
forever, and the `AC8` budget at `:348` never engages. This is precisely the failure mode the
ticket's own Description names: *"a gate that cannot record what it has already asked would
otherwise deny the same edit forever."* It is unbounded, and the only escape is a kill switch.

Three aggravating facts:

1. **The code comment cites the AC while contradicting it.** `:250-251` reads "never denies again
   for lack of a mark (AC7)". The six-call run above shows it denies every time.
2. **The test is a retrofit.** `wave8-smoke.sh:4440-4441`'s own comment header restates AC7
   correctly ("every state-write failure path **allows** ... **never a deny**"). The assertion
   four lines later, `:4450-4453`, passes on
   `.hookSpecificOutput.permissionDecision == "deny"` and is labelled "a state-write failure still
   denies ... rather than silently allowing". `:4447` selects `EDM_GATEGUARD_DENY_MODE=json`
   specifically, which makes a deny exit 0 -- so the AC's "asserts exit 0" clause is satisfied
   while its "never a deny" clause is inverted. No fixture anywhere asserts the allow.
3. **The divergence is unrecorded.** `decisions.md` has no entry for it (D42 is the only wave-5
   GateGuard decision and concerns the line-count ceiling). The upstream this AC was written from
   does allow: `ECC/scripts/hooks/gateguard-fact-force.js:1176` defines `allowWithStateWarning()`
   and calls it at `:1220`, `:1245`, `:1269`, `:1286` -- confirming the SRD's previously
   unverified `:1176-1181` fail-open citation and confirming EDM diverged from it silently.

---

### `EDMV4-T26`: Lens L13 -- Type Design, with auto-N/A on an untyped stack -- PASS

All eleven acceptance criteria verified. `L13` being N/A for this repository does not bear on any
AC -- every one is about the agent file's content or the `edm-state` constant.

- [x] **AC1** -- `plugins/edm/agents/edm-audit-type-design.md` exists (120 lines) and conforms to
      all nine parts of the `EDMV4-T28` house contract: frontmatter `:8-13`, opening frame + mandate
      sentence `:16-18`, verbatim house `## Scope` `:20-22`, `## What You Hunt For` `:24-47`,
      `## False Alarm Filter` with exactly three criteria `:49-55`, `## Output` `:57-67`,
      `## Output Format` `:69-85`, `## JSONL Line Format` `:87-112`,
      `## When this does NOT apply` `:114-120`. The `wave8-smoke.sh` T28 checker derives its file
      set from a live glob (`:4749`) rather than a hardcoded list, so this file is covered
      automatically.
- [x] **AC2** -- All four dimensions present as bold subheadings: Encapsulation `:26`, Invariant
      Expression `:32`, Invariant Usefulness `:38`, Enforcement `:43`.
- [x] **AC3** -- `:116` frames the condition as "genuine **inapplicability**" in exactly those
      terms and states "cost is never a reason to skip this lens (guard D2)". Asserted at
      `wave8-smoke.sh:1097-1098`.
- [x] **AC4** -- `:118` carries "agrees with that determination and never substitutes for it" and
      "a mismatch ... is a contract violation", in the `edm-test-integration.md` form. **The
      merge-time citation fix held**: the file now cites `agents/edm-test-integration.md` by name
      with no line numbers, so the stale-`file:line` defect the implementer shipped is gone --
      confirmed by `grep -n "edm-test-integration.md"` returning one hit at `:118` with no
      `:21-25` suffix, and `wave8-smoke.sh:1112` asserts the precedent citation without
      hardcoding a line range.
- [x] **AC5** -- `:120` states "exit immediately without writing anything at all: no `lens-L13.md`,
      no `lens-L13.jsonl`, no placeholder of any kind. Absence is authoritative." Machine-backstopped
      independently: `EDMV4-T23`'s check refuses a round where a `lenses_na` member produced a
      JSONL file.
- [x] **AC6** -- `bin/edm-state:1685` is `CONDITIONAL_LENS_IDS="L13"` -- exactly one member.
      `wave8-smoke.sh:1120-1126` counts members and asserts the value.
- [x] **AC7** -- The ticket text at `tickets/epics/04-audit-lenses.md:541-549` carries the D2
      framing constraint: conditionality justified "**only** as genuine inapplicability", with
      D2's cost-of-ignoring clause ("coverage loss disguised as an efficiency gain") recorded
      inline so it travels with the work.
- [x] **AC8** -- `check_absent` for `GateGuard` in the agent file (`wave8-smoke.sh:1129`) passes;
      I confirmed no effect-size figure appears anywhere in the file or in this epic's ACs.
- [x] **AC9** -- `L13` used consistently at `:60`, `:61`, `:74`, `:89`, `:94`. `## Output Format`
      `:71` cites `CLAUDE.md Sec."Severity vocabulary"` *and* carries the
      `Read docs/canonical-sections.md` instruction with the "never the caller's cwd" qualifier
      verbatim (`EDMV4-T28` AC8 / D22).
- [x] **AC10** -- `grep -c` for all six stack markers over the agent file returns **0**
      (verified directly). `wave8-smoke.sh:1141-1144` loops the same six names as `check_absent`.
- [x] **AC11** -- `bash plugins/edm/bin/edm-check-grants` exits **0** (run directly).
      `LC_ALL=C grep '[^ -~]'` over the file returns no lines -- ASCII-only.

---

### `EDMV4-T45`: Wire hookify events to their single owners, `bash` gated on Spike A -- PARTIAL

**On the concurrent lens's report that no `.claude/edm-hookify/*.json` ships anywhere in the
tree**: the fact is correct, but it is the specified design, not a defect, and it does not make
the blocking path unreachable. `EDMV4-T42` established that the plugin ships the format and the
reader and *no default rule file*; `.claude/edm-hookify/` is a project-owned directory that does
not exist until a consuming team adds a rule. `wave8-smoke.sh:830-832` asserts this affirmatively
-- "no default rule files may ship with the plugin" -- so a shipped rule file would be a *failure*,
not a fix.

I confirmed the wiring is exercisable rather than inferring it. Scratch project, marker present,
a project-local rule file, four cases:

| Case | Result |
|---|---|
| (a) no `edm-hookify` on PATH, path already checked | `rc=0`, silent |
| (b) hookify on PATH, zero rule files | `rc=0`, silent |
| (c) hookify on PATH, enabled `warn` rule matching | `rc=0`, `warn-x warn warn rule matched` on stderr |
| (d) hookify on PATH, enabled `block` rule matching | `{"hookSpecificOutput":{...,"permissionDecision":"deny","permissionDecisionReason":"block-x block block rule matched"}}`, `rc=0` (json mode) |

The blocking path is reachable by exactly the configuration the format documents. No `set -e`
abort occurs at `:405`'s `[[ ... ]] && emit_decision` despite `set -euo pipefail`.

- [x] **AC1** -- `bin/edm-gateguard:390-406` sits *after* the tool-name dispatch, so every deny has
      already `exit`ed and only the allow path reaches it; it is inside the marker guard at
      `:101-103`, so it is Phase-6-only; it re-projects `$PAYLOAD` (`:394`) rather than re-reading
      stdin, which is already consumed. `wave8-smoke.sh:4580-4582` asserts exactly one
      `Edit|Write|MultiEdit` `PreToolUse` block. Case (d) above is the live confirmation.
- [x] **AC2** -- `hooks/hooks.json:109-121`: one `Stop` matcher block, two entries in its `hooks`
      array (`edm-state checkpoint-if-active` unmodified at `:114`, `edm-stop-gate` at `:118`).
      No second `Stop` block. Asserted at `wave8-smoke.sh:4588-4590`.
- [x] **AC3** -- `decisions.md` D25 records the positive Spike A result explicitly: "Order is not
      load-bearing for either event; **a deny always wins; every registered command runs**", with
      the `PreToolUse`/`Bash` double-registration experiment and its AC8 conclusion that 5.3 "MAY
      register a second `bash`-event `PreToolUse` block alongside the existing `git commit` block
      ... without suppressing it". `wave8-smoke.sh:4557-4565` reads D25 before asserting anything
      else in the section, matching the AC's own reading-order requirement.
- [x] **AC4** -- The conditional does not trigger (Spike A was positive), so the unshipped-event
      branch is correctly not exercised. `bin/edm-bash-gate` exists and is executable.
- [x] **AC5** -- `hooks.json:86` is byte-identical:
      `command -v edm-lint-staged-artifacts >/dev/null 2>&1 || exit 0; edm-lint-staged-artifacts`.
      Pinned at `wave8-smoke.sh:4574-4576` via a `jq` selection on the `git commit` matcher, so the
      assertion cannot drift with line numbers. AD4's fallback was not attempted (no change to
      `edm-lint-staged-artifacts` in any T45 commit).
- [x] **AC6** -- `wave8-smoke.sh:4596-4661`: an `edm-hookify` spy proves zero invocations with the
      marker absent, paired with a positive control on a separate fakebin (real `jq`, spy hookify)
      showing the spy *does* fire with the marker present. The zero is not vacuous. My case (b)
      corroborates the allow.
- [x] **AC7** -- `wave8-smoke.sh:4667-4703` uses a real call-count spy that `exec`s the genuine
      binary, against a rule carrying **two** AND'd conditions, and asserts the count is exactly
      `1` -- so "once per condition" would read 2 and visibly fail. This is the right shape for
      the claim.
- [x] **AC8** -- `plugins/edm/CLAUDE.md`'s "Hooks behavior" table documents the
      `Edit|Write|MultiEdit` row (file events via `edm-gateguard`'s allow path), the `Stop` row
      (stop events via `edm-stop-gate`, once per invocation), and a new `Bash` row naming
      `bin/edm-bash-gate`; the closing paragraph states "hookify registers no `PreToolUse` or
      `Stop` block of its own for `file` or `stop` events". Each surface has one named owner.
- [ ] **AC9** -- **PARTIAL** on its first clause. See below.

**Static half of AC9, all verified**: `edm-check-vocabulary` exits **0** (run directly);
`hooks/hooks.json` is `SCOPE_ROOTS[4]` at `bin/edm-check-vocabulary:99-107`; it is `jq -e`
validated with a hard `die` at `:121-125`, so a syntax error there is fatal, not a skipped file --
both cited ranges hold exactly. `jq . hooks.json` parses.

**Finding**: [PARTIAL] `EDMV4-T45` | AC#9: runtime-check: run
`bash plugins/edm/bin/tests/run-all.sh` on a quiet tree and confirm zero failures with the `Bash`
matcher block registered. Not run by this audit -- a concurrent code audit held the tree, and a
reported green figure is not self-evidencing in an initiative that produced eleven `set -e` aborts
which ended a suite green with no failing assertion. Recorded via
`edm-state record-partial-verdict`.

---

### `EDMV4-T56`: Document the three plugin locations and the push-to-observe constraint -- PASS

All eight acceptance criteria verified. **AC4's sandbox gap is closed**: I ran the documented
command myself and it succeeded, so the URL rests on a direct read of the clone, not on the
`.git/config` fallback the implementer had to use.

- [x] **AC1** -- `plugins/edm/CLAUDE.md:1522-1537`: a named section with a three-row table giving
      each location's path and the command that reads it (working tree / nothing at runtime;
      marketplace clone / `/plugin update`; unpacked cache / `/reload-plugins`).
- [x] **AC2** -- `:1550-1551`: "**Neither `/plugin update` nor `/reload-plugins` reads the working
      tree at any point.**"
- [x] **AC3** -- `:1551-1553` states the consequence (unreachable until committed AND pushed to
      the GitLab remote; an author on an unpushed branch has no refresh path at all) and
      `:1558-1562` names the remedy: invoke `plugins/edm/bin/*` by explicit repo-relative path.
      This agrees with the standing user memory note, as the ticket's Technical Notes require.
- [x] **AC4** -- Re-verified live:
      `git -C ~/.claude/plugins/marketplaces/stg-marketplace remote get-url origin` ->
      `https://gitlab.com/scripps/public/marketplace.git`, matching the documented URL at `:1540`
      exactly. The verification command is recorded inline as a fenced block at `:1545-1547`, so a
      later reader can repeat it. The unpacked-cache path is real too
      (`~/.claude/plugins/cache/stg-marketplace/edm/{2.0.0,3.2.0,3.2.1}/`), confirming the
      `<version>`-as-placeholder treatment the Technical Notes required.
- [x] **AC5** -- `:1515-1516`: step 3 of "Testing changes" (`/reload-plugins`) carries an inline
      forward reference -- "but see 'Plugin distribution: three locations and the push-to-observe
      constraint' immediately below before trusting this on an unpushed branch". "Testing changes"
      steps 1-5 (`claude plugin validate`, sandbox, reload, verify, smoke suite) are the only
      place a plugin-development workflow is described in this repository -- a repo-wide grep for
      `/reload-plugins` and `/plugin update` outside `SRD/` returns hits in this one file only. An
      author hits the reference without knowing to look under distribution.
- [x] **AC6** -- `wave8-smoke.sh:3988-4000`: `t56_three_location_check` requires both
      `~/.claude/plugins/marketplaces/stg-marketplace` and
      `~/.claude/plugins/cache/stg-marketplace/edm/` to be present. Prose cannot accidentally
      satisfy that -- naming both literal paths *is* the explanation.
- [x] **AC7** -- `:4009-4018`: a real positive control. It strips every line containing either
      literal from a scratch copy and asserts the detector then reports absence, failing loudly
      ("the detector cannot fail and proves nothing") if it does not. This is a genuine negative
      fixture, not a restatement.
- [x] **AC8** -- `:4024-4039`: the reword fixture is written from scratch with an entirely
      different heading and no sentence from the real section, keeping only the two literal paths
      -- so it cannot accidentally preserve a phrase the detector secretly needs. That is the
      correct construction for this claim.

---

### `EDMV4-T57`: Retarget wave7's pattern-harvest assertions at the `T18` delta -- FAIL

The retargeting itself is good work: `+166/-57` on one file, resolving the delta through the real
production read path and isolating each case from ambient host state (the actual root cause of
"no novel findings" persisting across invocations). AC3's demonstrated-discrimination requirement
is where it falls short.

- [x] **AC1** -- The delta retarget lands across `T56 AC8` (`wave7-smoke.sh:3793-3825`),
      `CA-002 AC1/AC3/AC4/AC5/AC9` (`:3884-3975`), `G16/CA-355` (`:4113-4130`),
      `G35` (`:7983-7993`), `CA-476`/`G39` (`:4613, :8214`), and `CA-533` (`:1168-1175`).
      Two groups AC1 names were deliberately *not* retargeted -- `T56 AC1/AC4` and `CA-531` -- and
      that was the correct call: their failures had a different root cause (a doc-content defect
      and version drift), so retargeting them "at the delta location" would have been wrong. The
      reasoning is recorded in commit `5e38087`'s message and in in-place comments. AC1's group
      list was over-inclusive; the implementer handled it correctly rather than force-fitting.
- [x] **AC2** -- The delta is resolved by calling the production read path, never a formula:
      `get-patterns <type> --paths | sed -n '2p'` at `:3823-3824`, `:3919-3920`, and in the
      `T56 AC8` loop. I confirmed the contract holds by running it: line 1 is the shipped seed,
      line 2 is `${data}/patterns/<type>-audit.md`. A broken resolver would surface as an empty or
      nonexistent path, which `:3825-3830` hard-fails on.
- [ ] **AC3** -- **FAIL**. See finding below.
- [x] **AC4** -- No assertion was deleted; commit `5e38087` records the reason explicitly: "No
      assertions were deleted -- every one of the ~40 affected assertions was misdirected, not
      obsolete." The diff is net-additive (+166/-57), with deletions being in-place replacements.
      AC4's condition never triggers, and the negative is recorded where AC4 requires it.
- [x] **AC5** -- `git show --stat` over all `EDMV4-T57` commits shows **one** file touched,
      `plugins/edm/bin/tests/wave7-smoke.sh`. No three-branch write matrix was added to wave7; the
      two chmod-555 sites (`:4045-4055`, `:4113-4123`) force branch (b) to preserve a pre-existing
      case's premise, which is branch *selection*, not matrix re-proof.
- [x] **AC6** -- wave7 reports **1436 passed / 0 failed** at tip, so "zero failures except those
      owned by a named, still-open ticket" holds and the naming clause has nothing to bind on.
      **On the two `NEEDS-NEW-TICKET` sites** (`:3664-3671`, `:4675-4678`) a concurrent lens flags:
      both annotate assertions that currently **pass**, so neither is a "remaining failure". I
      re-derived the four-heading contract by hand over all five `docs/audit-patterns/*.md` files
      -- every one has exactly 4 `##` headings and 0 orphan `###` headings under the fourth
      section. AC6 is met at tip. See the two P2 notes below for what is wrong with those comments
      anyway.
- [x] **AC7** -- T57 touched only `wave7-smoke.sh` (git stat above), so wave6 and wave8 are
      provably unaffected *by this ticket*. wave6 holds at 795/0. See P2 note 5 on the stale `515/0`
      figure.
- [ ] **AC8** -- **PARTIAL** on the `run-all.sh` clause (runtime-only); the second clause is
      satisfied -- `.edm-state.json`'s `partial_verdict_map` shows `EDMV4-T19` and `EDMV4-T20` both
      closed `PASS` on 2026-09-04 with the run-all figure as their `verification_ref`, so
      `/edm:verify-runtime` did close them as AC8 intended. Not separately recorded in state: this
      ticket's rollup is FAIL, and remediating AC3 requires re-running wave7 and `run-all.sh`
      anyway, which closes this clause in the same pass.

**Finding**: [P1] `EDMV4-T57` | `plugins/edm/bin/tests/wave7-smoke.sh:3813-3825, 3888-3925` |
AC#3: "Each retargeted assertion is proven to still discriminate: a fixture in which the harvested
entry is absent from the new location must fail it. **Passing after the retarget is not evidence
on its own.**" No such fixture exists for any retargeted group.

What was delivered instead is a *seed-unchanged* discriminator, added twice (`:3820-3825` and
`:3949-3954`): "the shipped seed's own heading count is unchanged by all ten runs (proves the
writes really landed in the delta, not the seed)". That is a useful control -- it proves the write
target moved -- but it is the opposite direction from the one AC3 names. It cannot show that an
assertion still fails when the entry is *absent from the delta*.

Grepping the full T57 diff for control language returns exactly three hits: the two
seed-unchanged discriminators and one comment about isolating `CLAUDE_PLUGIN_DATA` for a
pre-existing positive control. No negative fixture was built.

This matters because the retarget introduced assertion shapes that pass on empty input. The two
`check_absent` calls against `$(cat "$delta")` (`:3927`, `:3944`) pass vacuously if the delta is
empty or missing. They survive today only because an adjacent guard at `:3825-3830` hard-fails on
an unresolvable delta and the positive assertions establish content first -- but that is an
inherited property of neighbouring code, not a demonstrated one, which is exactly the distinction
AC3 was written to force. The rest of the initiative shipped explicit paired controls for claims
of this class (`T14` AC3/AC6, `T15` AC1-AC5, `T56` AC7); AC3 asked for the same and did not get it.

I did rule out one adjacent vacuity by direct execution: `_t56_four_heading_contract_check
"$(dirname "$delta")"` is **not** vacuous -- the delta directory contains exactly one `.md` file
(`<type>-audit.md`) carrying a real four-heading stub, so the loop body runs and the contract is
genuinely applied.

---

## P2 observations (not FAIL findings)

1. **`EDMV4-T15` AC3's "zero filesystem reads" is imprecise, and the ordering assertion does not
   cover it.** `bin/edm-gateguard:50-51` spawns `dirname` and sources `_edm-cli-lib.sh` *before*
   either kill switch at `:80-85`, so "zero filesystem reads beyond its own environment" is not
   literally true. The AC's enumerated conditions (no marker `stat`, no session-state read, exit 0
   and empty stderr under mode-000 paths) are all met, so this is not a FAIL -- but
   `wave8-smoke.sh:4272-4278` compares the kill switch only against the `_edm-datadir-lib.sh`
   source at `:88`, never against the `_edm-cli-lib.sh` source at `:51`. That the test authors had
   to stub `dirname` into the fakebin (`:4283`) shows they knew a spawn occurs there.

2. **`EDMV4-T57`: the two `NEEDS-NEW-TICKET` comments are now factually false.**
   `wave7-smoke.sh:3664-3671` and `:4675-4678` both assert a "genuine, currently-shipped defect in
   the committed file itself (a `### ` entry landed after the 4th `## What Passing Code Looks
   Like` heading)". Commit `b697142` moved that entry into `## Anti-Patterns` and the defect is
   gone -- I re-derived the contract by hand and all five docs pass. A future reader hitting a
   CONTRACT-FAIL at those sites will be sent hunting for a fixed defect and told the fix "belongs
   to a new, not-yet-filed ticket" when it already landed.

3. **`EDMV4-T57`: the "not-yet-filed ticket" was closed by an unticketed commit.** `b697142`
   ("Move a harvested pattern entry into the section it belongs in") carries no `{PREFIX}-T{NN}`
   ID in its subject, and its body records a wave7 delta (`1428/7 -> 1432/3`). AC6's condition at
   tip is therefore satisfied by work T57 did not do and that no ticket owns -- a change-control
   gap worth naming even though the outcome is correct.

4. **`EDMV4-T45` AC1: the gated allow path still spawns a second `jq`.** `bin/edm-gateguard:394`
   runs `jq -c` to project `$PAYLOAD` into hookify's field shape on every gated call. This does not
   violate AC1 as written (stdin is not re-read; the parsed payload is reused), but it partly
   undercuts the cost intent, and no assertion pins the `jq`-spawn count on the *gated* allow path
   -- AC6's spy covers only the marker-absent path.

5. **`EDMV4-T57` AC7 pins a snapshot count that later tickets legitimately invalidated.** The AC
   states wave8 holds at `515/0`; it is `735/0` at tip, because `T14`, `T15`, `T45`, `T53` and
   `T28` each appended their own banded sections afterwards. The substantive claim (unaffected by
   *this* ticket) is provable from the commit stat, but the AC as literally written can never be
   re-verified. Pin a delta or a "touched files" claim, not an absolute suite count, in any
   successor AC.

6. **`EDMV4-T15` AC9's help-block assertion is looser than the AC.** `wave8-smoke.sh:4493-4494`
   greps the whole of `edm-gateguard` for `once a marker is present`, not the
   `EDM-HELP-BEGIN`/`END` block the AC names. The phrase does occur exactly once, at `:43`, inside
   the block -- so the AC is satisfied -- but the assertion would still pass if the sentence moved
   out of the help block into a code comment.

---

## Remediation Required

**P0 -- `EDMV4-T15` AC7: `bin/edm-gateguard` denies forever when session state is unwritable.**

Fix `gg_maybe_deny` (`bin/edm-gateguard:343-355`) so a failed `gg_mark_checked` allows instead of
denying, matching the AC and the upstream behaviour it was written from
(`ECC/scripts/hooks/gateguard-fact-force.js:1176` `allowWithStateWarning()`, called at `:1220`,
`:1245`, `:1269`, `:1286`). Concretely: have `gg_mark_checked` signal failure to its caller
(return non-zero on the two warn paths at `:255-258` and `:265-268`) and have `gg_maybe_deny`
`return 0` on that signal, before `gg_record_denial` and `emit_decision deny`. The stderr warning
naming `EDM_GATEGUARD_STATE_DIR` stays.

Then invert the test. `wave8-smoke.sh:4450-4458` currently asserts the deny; it must assert
exit 0, **empty stdout** (no `hookSpecificOutput` payload), and the warning on stderr. Pair it, as
every other `T15` assertion is paired, with a control proving the same fixture denies when the
state directory *is* writable -- otherwise the new allow-assertion is the vacuity trap this ticket
was flagged for, in the other direction.

Regression to keep: repeat the same path 4+ times under a read-only `run/` and assert every call
after the first allows. Today all six of my calls returned `rc=2`, and the denial budget cannot
bound it because `gg_record_denial` writes into the same unwritable directory (`:282-284`).

**P1 -- `EDMV4-T57` AC3: build the negative fixture the AC requires.**

For each retargeted group, add a case that removes (or never writes) the harvested entry in the
delta and asserts the retargeted assertion **fails**. The cheapest construction reuses the
existing scratch harness: after a successful `update-patterns` run, truncate `$delta` and re-run
only the assertion block, confirming it reports a failure. Prioritise the two `check_absent` calls
at `:3927` and `:3944`, whose shape passes on empty input and which are the only ones that cannot
be shown non-vacuous by inspection alone. Keep the seed-unchanged discriminators -- they are a
good control for a different risk, not a substitute for this one.

**P2 -- `EDMV4-T14` AC7: resolve the AC2/AC7 conflict, do not paper over it.**

`bin/edm-gateguard:324` reproduces `ECC/scripts/hooks/gateguard-fact-force.js:1085` verbatim, and
AC2 is what mandated it. Two routes, both requiring gate change control per
`CLAUDE.md Sec."Unverifiable acceptance criteria (D15)"`'s scope-change rule:

- Reword `Write` fact 1 (and tighten `:328` and `:333`, which are minimal-edit paraphrases with
  long verbatim runs), then amend AC2 to describe the fact's *content* rather than dictate its
  wording -- the clean route, since AC2's wording is what created the conflict.
- Or accept the reuse and correct `plugins/edm/CLAUDE.md`'s "Prompt conventions (house style)"
  clause that the bash rewrite "produces none" of the verbatim reuse the MIT NOTICE obligation
  binds on. Attribution is already recorded there, so this is a factual correction, not a new
  obligation.

Either way, add the assertion AC7 never had: a scan comparing the emitted fact strings against the
ECC source, or -- if the clone is not assumed present -- a pinned list of the phrases the fact set
must *not* contain, paired with a positive control the way AC3's check at
`wave8-smoke.sh:4125-4129` already is.

**PARTIAL closure** -- `EDMV4-T45` AC9's `run-all.sh` clause is recorded in
`partial_verdict_map` and closes to PASS or FAIL under `/edm:verify-runtime` before archive. It is
not remediated here.

<!-- QC-SHARD-COMPLETE range=T14,T15,T26,T45,T56,T57 assigned=6 audited=6 -->
