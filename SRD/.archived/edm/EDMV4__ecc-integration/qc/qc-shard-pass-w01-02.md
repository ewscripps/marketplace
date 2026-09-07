# QC Audit Report: Epic 01 Preconditions and Change Control [Shard 2/3]

**Date**: 2026-09-02
**Tickets audited**: EDMV4-T07 through EDMV4-T10
**Tree graded**: `edm/edmv4-ecc-integration` pinned at **`c936e4f`** (extracted read-only to `/tmp/qcsnap`
via `git archive`, because the live working tree changed under this audit mid-run -- symbol line
numbers moved twice while grading). All `file:line` evidence below is against `c936e4f` unless a
finding explicitly names another commit. `d5f6b88` (T10) **is** merged at `c936e4f`.

## Summary

| Ticket | Title | Verdict |
|---|---|---|
| EDMV4-T07 | Run Spike B and set the GateGuard deny-mode default from evidence | PARTIAL |
| EDMV4-T08 | Reconcile the D4 residual plugin.json version divergence at merge time | **FAIL** |
| EDMV4-T09 | Enforce the inherited T01-T05 ticket-ID constraints and fix the stale CLAUDE.md reference | **FAIL** |
| EDMV4-T10 | Record and propagate the three Gate 2 ratifications (D14, D15, D16) | PASS |

---

## Detailed Findings

### EDMV4-T07: Run Spike B and set the GateGuard deny-mode default from evidence -- PARTIAL

Deliverable is decision **D26** at `SRD/edm/EDMV4__ecc-integration/decisions.md:36`. Grading rule
applied and stated for auditability: ACs whose operative clause is *"the record states X"* are
statically verifiable (PASS/FAIL); ACs asserting a **host behaviour that cannot be re-run from the
tree** are PARTIAL, per the standing instruction not to force PASS/FAIL on un-rerunnable host
observations. The record is complete and unusually specific in every PARTIAL case below -- each
carries the verbatim surfaced text -- so each runtime-check is cheap to close.

- [ ] AC1: JSON payload on stdout, exit 0, denies `Edit`; reason surfaced separately -- **PARTIAL**.
      `decisions.md:36` records both sub-answers: `Edit` DENIED (`target.txt` confirmed unchanged by
      direct file read) and the reason surfaced as a clean `<error>spike-b1-json-deny-reason</error>`
      tool result. Un-rerunnable from the tree.
- [ ] AC2: Repeated for `Write` and `MultiEdit`, recorded as three rows, never collapsed -- **PARTIAL**.
      Three per-tool rows are present and structurally uncollapsed (`Edit` DENIED / `Write` DENIED /
      `MultiEdit` UNTESTABLE). The `MultiEdit` repeat did not occur, so the AC is not fully met by any
      record.
- [ ] AC3: stderr + exit 2 mechanism -- **PARTIAL**. Recorded for both `Edit` and `Write` (both
      DENIED), with the noisier surfaced shape quoted verbatim, including the hook's own shell command
      leaking into the agent transcript. Un-rerunnable.
- [ ] AC4: Positive control with the hook removed -- **PARTIAL**. Recorded (`target.txt` changed
      `hello world` -> `goodbye world`, confirmed by direct file read). Un-rerunnable.
- [ ] AC5: `MultiEdit` batch of >=3 edits across >=2 files, partial-application read from post-run file
      contents -- **PARTIAL**. Explicitly recorded **UNTESTABLE**: the tool is absent from the host
      session's toolset, not reachable via `ToolSearch` (`select:MultiEdit` -> "No matching deferred
      tools found"), reproduced twice including a forced `--allowedTools MultiEdit`. Recording an
      honest negative rather than assuming by analogy is the correct behaviour here and is not graded
      as a defect.
- [x] AC6: Numbered decision naming `claude --version` verbatim, the date, and the default --
      **PASS**. `decisions.md:36` names `2.1.246 (Claude Code)`, dated `2026-09-02`, and sets
      `EDM_GATEGUARD_DENY_MODE` to `json` -- exactly one of the two permitted values.
- [x] AC7: Names the precedent and states its limit -- **PASS**. Cites
      `edm-lint-staged-artifacts:7-10` and the loop at `:146-159` with `fail=2`, and states the limit
      (fires on a `Bash`-wrapped `git commit`, so it never evidenced the native-tool case). Both
      anchors verified on the tree: the `EDM-HELP-BEGIN` exit-code contract is at
      `plugins/edm/bin/edm-lint-staged-artifacts:7-10`; the loop is `:146-158` with `fail=2` at `:153`
      and `exit "$fail"` at `:159`.
- [x] AC8: Negative branch stated plainly if neither mechanism denies -- **PASS**. Branch did not fire
      for `Edit`/`Write`; the record says so and does **not** send 4.1 back to a gate, while separately
      preserving the `MultiEdit` caveat rather than papering over it.
- [x] AC9: `hooks.json` unmodified -- **PASS**. `git log -- plugins/edm/hooks/hooks.json` shows no
      EDMV4 commit touches it (last touch `e827f76`, EDMV3-era); `git status --short` on that path is
      empty.

**Findings**
```
[PARTIAL] EDMV4-T07 | AC#1: JSON deny for Edit + reason surfaced | runtime-check: re-run the scratch PreToolUse Edit hook on claude 2.1.246, assert target.txt unchanged and the tool result is <error>spike-b1-json-deny-reason</error>
[PARTIAL] EDMV4-T07 | AC#2: per-tool rows for Edit/Write/MultiEdit | runtime-check: on a host where MultiEdit loads, run the AC1 experiment for MultiEdit and replace the UNTESTABLE row with a result
[PARTIAL] EDMV4-T07 | AC#3: stderr + exit 2 deny | runtime-check: re-run the exit-2 hook against Edit and Write, assert refusal and capture the surfaced stderr shape
[PARTIAL] EDMV4-T07 | AC#4: positive control | runtime-check: re-run the identical Edit against a hookless scratch repo, assert it succeeds
[PARTIAL] EDMV4-T07 | AC#5: MultiEdit >=3 edits / >=2 files partial-application | runtime-check: on a host/config where MultiEdit is present in the toolset, run the batch and read post-run file contents to decide whole-call-refused vs partially-applied
```

---

### EDMV4-T08: Reconcile the D4 residual plugin.json version divergence at merge time -- FAIL

The stale-premise handling is correct and is **not** penalised: `plugin.json` already read `3.2.2`,
the `*opus-5*` arm already existed, and `SRD/.archived/` already existed. Recording those as
pre-satisfied (decision **D29**, `decisions.md:39`) rather than manufacturing work is right. The two
FAILs below are about what the ticket actually shipped.

- [x] AC1: version >= 3.2.1 and identical in both manifests -- **PASS**.
      `plugins/edm/.claude-plugin/plugin.json:4` = `"version": "3.2.2"`;
      `.claude-plugin/marketplace.json` `edm` entry = `"3.2.2"` -- identical strings, one final value,
      no second independent bump.
- [x] AC2: computed Opus row for a synthetic `claude-opus-5-*` identifier -- **PASS**, verified
      **behaviourally**, not by grep. Extracted `compute_cost_usd` from
      `plugins/edm/bin/edm-state:485-555` and executed it: full row = `56.1000`; decomposed
      input `6.0000`, output `30.0000`, cache-read `0.6000`, cache-write-5m `7.5000`,
      cache-write-1h `12.0000`. Matches the specified Opus row exactly.
- [x] AC3: `*)` arm's `WARNING: unrecognized model_used` does not fire for `opus-5` -- **PASS**,
      verified behaviourally. stderr for `claude-opus-5-20260501` is empty. Negative control run to
      prove the check discriminates: `claude-zzz-9-20260501` does emit
      `edm-state: WARNING: unrecognized model_used ...` from `edm-state:544`.
- [x] AC4: `*opus-5*` precedes `*)`, no bare family wildcard -- **PASS**. Arm `*opus-4-8*|*opus-4.8*|*opus-5*`
      at `edm-state:507`; final `*)` at `:538`. The eight arms are all explicit generation identifiers;
      no bare `*opus*`, `*sonnet*` or `*haiku*` arm exists in the `case`.
- [x] AC5: regression verification of the D3/D4 state -- **PASS**, verified directly against the tree
      rather than through the (unreachable) test:
      `grep -rc 'disable-model-invocation' plugins/edm/skills/` totals **0**; 14/14 `SKILL.md` files
      carry `user-invocable: true`; `bash plugins/edm/bin/edm-check-skill-sync` exits **0** and its
      body still carries the guard at `plugins/edm/bin/edm-check-skill-sync:77`
      (`grep -q '^disable-model-invocation: *true'`).
- [x] AC6: both change sets accounted for, choice recorded in `decisions.md` -- **PASS**. `D29`
      (`decisions.md:39`) records both as already resolved: the ~313-path archival rename set is
      committed (`SRD/.archived/edm/EDMV3__prompt-streamline/` exists on the tree) and no unstaged
      `wave6-smoke.sh` edits remain from D4's snapshot. Neither was carried into an unrelated commit.
- [ ] AC7: `run-all.sh` passes on the reconciled tree -- **FAIL (P0)**. `wave6-smoke.sh` (a member of
      `run-all.sh`'s suite set, `run-all.sh:39`) **aborts** and exits 1. The abort is inside this
      ticket's own new code, at `plugins/edm/bin/tests/wave6-smoke.sh:4854`:
      ```bash
      t08_dmi_count="$(command grep -rc 'disable-model-invocation' "${_HARNESS_PLUGIN_DIR}/skills"/*/SKILL.md 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')"
      ```
      The file sets `set -euo pipefail` at `:6`. On a **healthy** tree `grep -rc` finds zero matches in
      every file and exits **1**; under `pipefail` the command substitution's pipeline returns 1 and
      `set -e` kills the script. Confirmed three ways: full run (`exit=1`, no summary line ever
      printed); `bash -x` trace, whose last statements are the `grep -rc`/`awk` pipeline followed
      immediately by `cleanup_wave6`; and an isolated one-line repro under `set -euo pipefail`
      (`exit=1`, the `echo` after it never reached).
      **Baseline proving it is a regression this ticket introduced**: the same suite at `9f3f248` (the
      commit immediately before T08 merged) runs to completion -- `Results: 682 passed, 1 failed`, the
      single failure being the known by-design `T27 AC1` owned by EDMV4-T30. At `c936e4f` the run dies
      after 656 passes.
      The defect is also **self-masking and inverted**: it aborts precisely when the tree is clean, and
      would only let the suite proceed if `disable-model-invocation` had actually regressed.
      Everything after `:4854` is dead: the rest of AC5's assertions, all three AC8 citation
      assertions (`:4876-4887`), the AC9 assertion, ~26 later assertions and the whole `CA-061` tail,
      and the summary line itself.
- [ ] AC8: every `file:line` citation re-verified against the tree by locating the symbol by name --
      **FAIL (P1)**. Not a "correcting toward the pack" defect -- the implementer was correct to leave
      `srd.md` alone for `ALL_LENS_IDS` and `MODE_ENUM_LIST`, and correct that the pack's 803/1705 are
      the wrong numbers. The defect is that the re-derivation was **not actually performed** for
      `state_anomalies()`. At the ticket's **own commit `0c0c470`**, `grep -n '^state_anomalies()'
      plugins/edm/bin/edm-state` returns **1733**, not 1709. `srd.md` cites `1709` -- off by **+24**,
      already outside AC8's own +/-10 tolerance at close, so the AC's correction obligation was
      triggered and not discharged. `decisions.md:39` (D29) nevertheless asserts
      `state_anomalies():1709` is "already-accurate", which is false against the tree it was written
      on. Contrast `ALL_LENS_IDS`, where the same block *did* notice the +1 shift and says so at
      `wave6-smoke.sh:4880` -- so the check was applied unevenly, not skipped wholesale.
      Compounding this, the verification block hardcodes three absolute line literals
      (`:4879` `== "1614"`, `:4882` `== "807"`, `:4885` `== "1709"`). At `c936e4f` the live values are
      **1620 / 813 / 1739** -- all three assertions are now wrong. This re-encodes, as a test, exactly
      the frozen-line-number anti-pattern D21 was written to break ("locate by symbol name at edit
      time"). Nobody sees the failures because AC7's abort fires first.
- [x] AC9: non-blocking status visible in the pack -- **PASS**. No ticket lists `EDMV4-T08` in
      `Depends On` (`tickets/README.md:103` records T08's own as `none`); the README critical-path
      Mermaid has `T08["T08 D4 residual"]` at `:193` as a leaf with **zero** outbound edges; and
      `tickets/README.md:391` states "**`EDMV4-T08` blocks nothing.**"

**Not an AC, checked because it was claimed** -- the `shellcheck` sub-claim is **confirmed and is a
pre-existing condition, not an EDMV4 defect**. `shellcheck` 0.11.0 cannot parse
`plugins/edm/bin/edm-state` at all: it aborts at the malformed directive
`# shellcheck disable=SC2086 -- deliberate glob expansion...` (`edm-state:138` at `c936e4f`; the
implementer said "near 132" -- drift only) with `SC1073`/`SC1072` plus `SC1009`, and reports nothing
else about the file. The identical failure reproduces on `origin/main`, and the line was introduced
by EDMV3-era commit `1dc9da8`. "No new shellcheck warning" is therefore genuinely unverifiable
whole-file **by anyone** on this tree -- correctly classified rather than silently passed. The fix is
one character class: `disable=SC2086 -- text` must be `disable=SC2086 # text`. Recorded as NOTED,
out of scope for this shard.

**Findings**
```
[P0] EDMV4-T08 | plugins/edm/bin/tests/wave6-smoke.sh:4854 | AC#7: run-all.sh passes on the reconciled tree | `grep -rc` exits 1 on a clean tree; under this file's `set -euo pipefail` (:6) the command substitution aborts the whole suite before any summary. Baseline at 9f3f248 was "682 passed, 1 failed"; at c936e4f the run dies after 656. Kills the remaining AC5 assertions, all three AC8 assertions (:4876-4887), the AC9 assertion and the CA-061 tail. Self-masking: it aborts only when the tree is HEALTHY.
[P1] EDMV4-T08 | SRD/edm/EDMV4__ecc-integration/decisions.md:39 + plugins/edm/bin/tests/wave6-smoke.sh:4885 | AC#8: re-verify every file:line citation by locating the symbol by name | `state_anomalies()` was at 1733 at this ticket's own commit 0c0c470 (1739 at c936e4f), not 1709. srd.md's 1709 is off by +24 -- outside AC8's own +/-10 tolerance at close -- so the correction was owed and not made, and D29's claim that 1709 is "already-accurate" is false against the tree.
[P2] EDMV4-T08 | plugins/edm/bin/tests/wave6-smoke.sh:4879,4882,4885 | AC#8: citation re-verification | The assertions derive the line by name and then compare to a frozen literal (1614/807/1709). Live values at c936e4f are 1620/813/1739 -- all three now wrong. Assert the symbol resolves and that srd.md's cited number is within +/-10 of it; never pin an absolute line.
```

---

### EDMV4-T09: Enforce the inherited T01-T05 ticket-ID constraints and fix the stale CLAUDE.md reference -- FAIL

- [x] AC1: "Inherited ticket IDs" note in the pack README -- **PASS**.
      `tickets/README.md:13` (`## Inherited ticket IDs -- read before renumbering anything`), with the
      pre-claimed table at `:19-23` and the retirement statement at `:25-27`.
- [x] AC2: `EDMV4-T01` `SRD Refs` lists exactly `EDMV4-47, EDMV4-48` -- **PASS**
      (`tickets/epics/07-inherited-tickets.md`, T01 heading `:32`).
- [x] AC3: `EDMV4-T04` lists exactly `EDMV4-49, EDMV4-50, EDMV4-51` -- **PASS** (T04 heading `:131`).
- [x] AC4: `EDMV4-T05` lists exactly `EDMV4-52, EDMV4-53` -- **PASS** (T05 heading `:246`).
- [x] AC5: zero `T02`/`T03` ticket headings + intentional-gap note -- **PASS**. `grep -rn '^## EDMV4-T0[23]'`
      over `epics/` returns nothing; the four surviving mentions are all prose forbidding reuse. The
      gap note is at `tickets/README.md:29-31`: "**The gap between `EDMV4-T01` and `EDMV4-T04` in this
      pack is correct and intentional.** It is not a numbering mistake -- do not \"fix\" it."
- [x] AC6: every created ticket is `T06`+, contiguous from `T06` with no gaps or duplicates --
      **PASS**. 52 unique headings; `sort | uniq -d` is empty; the ID set is `T01`, then `T04`..`T54`
      unbroken -- so `T06` upward is contiguous and the only gap is the intentional retired pair.
- [ ] AC7: `EDMV4__lint-and-pipeline-budgets` replaced with `SRD/edm/EDMV4__ecc-integration/`, the
      parenthetical still grammatical and still naming `EDMV4-T04` -- **FAIL (P1)**. Half met, half
      silently reverted by merge order:
      - Stale name gone: `grep -c 'EDMV4__lint-and-pipeline-budgets' plugins/edm/CLAUDE.md` = **0**.
      - Replacement path **absent**: `grep -c 'EDMV4__ecc-integration' plugins/edm/CLAUDE.md` = **0**.
      T09's own commit `28f4dfe` made the edit correctly -- at that commit
      `plugins/edm/CLAUDE.md:458` reads `` `SRD/edm/EDMV4__ecc-integration/`; `EDMV4-T02` and
      `EDMV4-T03` are already closed per ``. It was written against a parent that predated
      `EDMV4-T04`'s rewrite of the same D34 passage; the subsequent merge kept T04's rewrite, which
      names **no directory at all**. `git log -S'SRD/edm/EDMV4__ecc-integration/' -- plugins/edm/CLAUDE.md`
      returns exactly one commit (`28f4dfe`) and the string is not present at `c936e4f`.
      The second clause survives: `plugins/edm/CLAUDE.md:468` still names the ticket ("**`EDMV4-T04`
      has landed**: the residual scope opened as a named follow-on ticket by D34 ... is closed") and
      reads grammatically. Net effect: the stale pointer is dead (the defect T09 exists to kill), but a
      reader of the D34 passage now has no path to the owning initiative, and nothing guards the loss.
- [x] AC8: repo-wide grep returns no live pointer presented as a current path -- **PASS**. All 16
      surviving matches are historical or descriptive and every one labels the initiative
      "named-but-never-created" / "never existed on disk": EDMV4 `decisions.md:5` (D1), EDMV3 archived
      `decisions.md:38,71` (D29, D62), four EDMV3 archived code-audit ledger/lens entries, and EDMV4's
      own `planning.md:13`, `srd.md:54,524,2973`, `explorers/01-bin-shell-tooling.md:11`,
      `tickets/epics/01:347,362,382,386,393` and `tickets/epics/07:4,185`. None is a live pointer.
      NOTED: AC8's parenthetical enumeration ("only ... EDMV4 D1, EDMV3 D29/D34/D62") is under-inclusive
      of what the grep actually returns; graded on the operative clause, which is satisfied.

**Finding**
```
[P1] EDMV4-T09 | plugins/edm/CLAUDE.md:468 (passage), regression vs 28f4dfe:458 | AC#7: the stale reference is replaced with this initiative's real directory, SRD/edm/EDMV4__ecc-integration/ | The stale name is gone but the required replacement path is absent at c936e4f. T09's own commit added it at :458; EDMV4-T04's rewrite of the same D34 passage merged over it and names no directory. Restore the pointer inside T04's current wording, e.g. "...named follow-on ticket by D34, now owned by `SRD/edm/EDMV4__ecc-integration/`".
```

---

### EDMV4-T10: Record and propagate the three Gate 2 ratifications (D14, D15, D16) -- PASS

All twelve acceptance criteria verified. Commit `d5f6b88`, merged at `c936e4f` (merge `c936e4f` of
`worktree-agent-a5210de8f14565c8e`); it was **not** on the branch when this audit began and every
verdict below is re-derived against `c936e4f`, not against the worktree.

- [x] AC1: three separate numbered Gate 2 entries, each dated, each with its own verdict --
      `decisions.md:21` (D14, `EDMV4-59`), `:22` (D15, `EDMV4-05`), `:23` (D16, `EDMV4-06`), all
      `2026-09-02`, each carrying an explicit **RATIFIED** verdict plus its own rationale. D15 states
      "**Independent of D14**" in terms; no verdict is inferred from another or from silence.
- [x] AC2: AD1 amended to record both D14 and D15 -- `architecture.md:45-50`: "**Ratified at Gate 2 on
      2026-09-02.** Two separate decisions ratify this section, and they stay independent in the
      record: `decisions.md` D14 ratifies AD1 itself -- bash rewrite, roughly 250-350 lines, not a
      vendoring -- and `decisions.md` D15 ratifies the destructive-`Bash` arm's descope". Closes the
      possibility of the two documents disagreeing.
- [x] AC3 (**the highest-value item**): the false claim is corrected, and the correction is accurate.
      The old assertion that EDM "already blocks the one destructive Bash operation its methodology
      cares about (`git commit`, via `edm-lint-staged-artifacts`)" is **gone** from `architecture.md`
      (`grep` returns zero hits). The replacement at `architecture.md:52-59` states all three things
      AC3 requires: "`bin/edm-lint-staged-artifacts:146-159` blocks only on artifact lint violations
      -- a non-ASCII byte, an attribution trailer, a raw semicolon in a Mermaid label -- and fires only
      when something under the derived `srd_root` is staged; it guards nothing destructive."
      **Verified accurate against source, not just present**: the loop at
      `plugins/edm/bin/edm-lint-staged-artifacts:146-158` delegates to `edm-lint-artifacts` per
      prefix, sets `fail=2` at `:153` only on that binary's exit 1 (a lint violation), and exits at
      `:159`; the prefix set at `:130-141` is derived from staged paths under `check_dir`, so the hook
      is inert unless `srd_root` content is staged. The claim is true. Note the implementer cites
      `:146-159` where AC3 said `:140-159` -- the tighter range is the **correct** one, re-derived
      from the tree, which is the required behaviour, not a deviation. The surviving occurrence at
      `srd.md:568` is explicitly historical ("v1.0.0 claimed EDM \"already blocks...\"").
- [x] AC4: D15 boundary recorded as a decision on its own merits, naming `EDMV4-43` and its condition
      -- `decisions.md:22`: "**Scope-boundary record** (EDMV3 D14 scope-boundary framing -- a decision
      on its own merits, not a postponed finding) ... The named follow-on vehicle is 5.3's `bash`-event
      rule files (`EDMV4-43`), and that vehicle ships **only if Spike A (`EDMV4-T06`) clears** -- the
      follow-on route is conditional, not assured."
- [x] AC5: unguarded command classes enumerated **by name** -- `decisions.md:22` names all five:
      `rm -rf`, `git reset --hard`, `git clean -fd`, force-push (`git push --force` /
      `--force-with-lease`), and destructive SQL such as `DROP TABLE`. The same five are mirrored at
      `architecture.md:56-58`.
- [x] AC6: D15 propagated into the pack -- `EDMV4-07`'s ticket is `EDMV4-T11`
      (`tickets/epics/02-gateguard.md:28`), whose scope reads "`Edit`/`Write`/`MultiEdit` matcher
      block" and whose own AC6 (`:84-85`) affirmatively requires "The script contains no
      destructive-`Bash` detection". Epic 02's header `:4` records the D14 ratification with the arm
      descoped. `grep -rn 'isDestructiveBash|shell-substitution|gateguard-heredoc' tickets/` returns
      only `epics/02:54-55` (describing what is **deleted** from the port surface) and `epics/01:475`
      (the AC's own text) -- no in-scope work anywhere.
- [x] AC7: D13's attribution paragraph records D14's outcome -- `decisions.md:19`: "**Amended again
      after Gate 2 (D14, 2026-09-02): AD1 is now ratified, not merely architect-chosen** -- the bash
      rewrite stands, nothing is copied from either upstream, and `EDMV4-12` stays Should Have with its
      NOTICE clause dormant." All three required elements present; row date reads "2026-08-31, amended
      2026-09-02". Licence record and architecture record now agree.
- [x] AC8: NOTICE trigger stated once, in the `EDMV4-12` ticket, in the required words -- `EDMV4-12` is
      owned by `EDMV4-T16` (`tickets/README.md:452`), and the trigger appears at
      `tickets/epics/02-gateguard.md:574`: "The strict MIT NOTICE obligation is dormant, and the
      trigger that revives it is an AD1 reversal to vendoring, by any route." The negative half holds:
      no pack text makes an `EDMV4-05` rejection revive the obligation -- `epics/01:441` describes the
      old wiring as the defect being corrected, and `epics/01:483` is the AC text itself.
- [x] AC9: `EDMV4-56` carries the same wiring -- owned by `EDMV4-T51` (`tickets/README.md:496`).
      `epics/08-cross-cutting.md:161-167` records that AD1 was ratified so no dependency is added, the
      clause is dormant, "its wake condition ... fires on **an AD1 reversal by any route**, matching
      D14's own wording. It does not fire on an `EDMV4-05` rejection". T51's own AC9 (`epics/08:206-211`)
      pins the same form and states an `EDMV4-05` rejection is **not** a trigger; the ratified set stays
      `bash`/`jq`/`git` (`epics/08:4`) with no re-presentation required now.
- [x] AC10: D16 propagated -- `EDMV4-45` is owned by `EDMV4-T47` (`tickets/README.md:485`), which ships
      exactly three anomalies (`epics/06:49` `OPEN_PARTIALS` blocks, `:51` `OPEN_AUDIT_ROUND` warns,
      `:54` `SPEC_SWEEP_PENDING` warns) and no fourth -- its AC8 (`:57`) states "The \"phase started
      with no `completed_at`\" anomaly is **not** implemented." The boundary record at
      `decisions.md:23` names what a future design would need: "a time threshold or an explicit
      wave-in-progress carve-out".
- [x] AC11: the two facts cited, with anchors that were **correct when re-derived at close** --
      `decisions.md:23` cites `bin/edm-state:1784-1790` and `:3181-3185`. Verified against T10's own
      commit `d5f6b88`: `:1784-1790` is exactly the seven-line `OPEN_AUDIT_ROUND (info -- EDMV3-T51
      AC4/AC5)` rationale comment ("a round in progress mid-audit is normal, not corrupted data, so
      this never flips cmd_validate's exit code"), and `:3181-3185` is exactly the AC1c terminal-phase
      block ending in `die "archive refused: phase ... has no completed_at recorded ..."`. Both are
      **tighter and more accurate** than the AC's own advisory `:1782-1789` / `:3178-3181` -- correct
      re-derivation by name, which is what D21 mandates. NOTED: at `c936e4f` unrelated later merges
      shifted both symbols +30 (now `:1814-1820` and `:3211-3215`); post-close drift caused by other
      tickets, not a T10 defect.
- [x] AC12: every `srd.md` passage that presented these as pending now reads as ratified --
      `srd.md:314` ("**All three were ratified at Gate 2 on 2026-09-02** (`decisions.md` D14, D15,
      D16)") and `:329` annotate Sec.5.2's framing; the three requirement entries each carry their own
      annotation: `:576` (`EDMV4-05`, D15), `:634` (`EDMV4-06`, D16), `:684` (`EDMV4-59`, D14), plus
      `:167`. No reader is left to re-run a gate that already happened. The EDMV3-D14 naming collision
      is also avoided as the Technical Notes require -- `srd.md:602,648` write "EDMV3 D14" explicitly.

No findings.

---

## Remediation Required

Ordered by severity. PARTIALs are not remediated here -- they are closed by `/edm:verify-runtime`.

1. **[P0] `plugins/edm/bin/tests/wave6-smoke.sh:4854` (EDMV4-T08 AC7)** -- the suite aborts on a clean
   tree. Make the pipeline's exit status explicit so `pipefail` cannot fire, e.g. append
   `|| true` to the `grep`, or restructure as
   `t08_dmi_count="$( { command grep -rc '...' ... || true; } | awk ... )"`. Then re-run
   `bash plugins/edm/bin/tests/wave6-smoke.sh` and confirm a summary line is printed and that the
   assertions at `:4855-4887` actually execute. Expected post-fix baseline: the pre-T08 result
   (`682 passed, 1 failed` at `9f3f248`) plus this ticket's new assertions, with `T27 AC1` remaining
   the only by-design failure (owned by EDMV4-T30). Separately: `EDMV4-T21 AC7` at `:3574` also fails
   at `c936e4f`; a fix for it is already in the uncommitted working tree and is EDMV4-T21's, not this
   shard's.
2. **[P1] `plugins/edm/bin/tests/wave6-smoke.sh:4885` and `decisions.md:39` (EDMV4-T08 AC8)** -- the
   `state_anomalies()` re-derivation was not performed. Locate the symbol by name, compare to
   `srd.md`'s cited `1709`, and since the delta exceeds +/-10, correct `srd.md` to the re-derived
   value (and only then). Amend D29's claim that `state_anomalies():1709` is "already-accurate", which
   was false at `0c0c470`. Leave `ALL_LENS_IDS` and `MODE_ENUM_LIST` alone -- those calls were right.
3. **[P1] `plugins/edm/CLAUDE.md:468` (EDMV4-T09 AC7)** -- restore the initiative pointer lost to merge
   order. Add `SRD/edm/EDMV4__ecc-integration/` into `EDMV4-T04`'s current "has landed" wording so the
   D34 passage again names the owning initiative, without reintroducing the stale name.
4. **[P2] `plugins/edm/bin/tests/wave6-smoke.sh:4879,4882,4885` (EDMV4-T08 AC8)** -- replace the three
   hardcoded absolute line literals with a tolerance check against `srd.md`'s cited number, so the
   assertions stop rotting on every unrelated insertion above them.

**NOTED (no action required by this shard)**

- `plugins/edm/bin/edm-state:138` -- the malformed directive `# shellcheck disable=SC2086 -- text`
  makes `shellcheck` 0.11.0 unable to parse the file at all (`SC1073`/`SC1072`). Pre-existing, present
  on `origin/main`, introduced by `1dc9da8`. Until fixed, no whole-file shellcheck claim about
  `edm-state` is verifiable by anyone. One-character fix (`--` -> `#`).
- Cross-referenced from sibling shards, not re-derived here, and relevant to this shard only as
  context for the T09 AC7 regression: `bin/edm-check-grants` has no orphan-citation check
  (`EDMV4-T04` AC11 never built, P0, shard 1), and `skills/orchestrator/SKILL.md:118,123` carry bare
  un-suffixed `CLAUDE.md Sec."EDM mode matrix"` citations added by `EDMV4-T34` after the anchoring
  commit. Both are the same failure class as T09 AC7: an anchoring/pointer fix silently undone by a
  later commit touching the same surface, with no assertion guarding it.
- `implementation_mode` is `standard` for this initiative; the TDD compliance pass does not run.

<!-- QC-SHARD-COMPLETE range=EDMV4-T07..EDMV4-T10 assigned=4 audited=4 -->
