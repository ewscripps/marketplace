# Epic E5 -- WS5: Orchestrator as dispatcher

**Wave**: B (v2.1.0 -> v3.0.0)
**SRD requirements**: EDMV3-44 .. EDMV3-52 (9)
**Tickets**: EDMV3-T34 .. EDMV3-T39 (6)

R4 at full scope (D10). Every phase's procedure exists twice today, hand-synced and already divergent
at the gates. Deduplication means every future prompt improvement lands once and the F4 class dies.

This is the riskiest change in the initiative, which is why it lands after the harness (E3) and why
two of the three L tickets in the whole pack live here.

All commands are run from the repository root unless stated otherwise.

---

## EDMV3-T34: Skill-tool composition depth spike, and `CLAUDE.md` documents the pattern

| Field | Value |
|---|---|
| Epic | E5 -- Orchestrator as dispatcher |
| Wave | B |
| Priority | Must Have |
| Size | XS |
| SRD Refs | EDMV3-44, EDMV3-50 |
| Depends On | -- |
| Ships-with | -- |
| Target Components | `plugins/edm/CLAUDE.md` (architectural rule 2), `SRD/edm/EDMV3__prompt-streamline/decisions.md`, a spike note in the initiative directory |

### Description

`architecture.md` R-B. The git-plugin precedent is one skill calling one skill, once, at a leaf. WS5
chains dispatcher -> phase skill across six phases with state handoffs and gate returns between each.
Specifically unvalidated: how `$ARGUMENTS` and the caller's variables are visible to the callee, and
whether the callee's or the caller's `allowed-tools` apply. This is a go/no-go for the refactor.

The documentation half ships in the same ticket because it is the same finding written down.
`plugins/edm/CLAUDE.md` architectural rule 2 states "Skills don't load other skills -- they each
contain their own orchestration." That statement is the documented justification for the duplication
this epic removes, and it is no longer true of current Claude Code -- this marketplace's own git
plugin composes skills.

### Acceptance Criteria

- [ ] AC1 (spike executed and recorded): a time-boxed spike (target 10-30 minutes) invokes a phase
      skill from a skill via the Skill tool and records, in a written note committed to the
      initiative directory: whether the invocation succeeds, whether `$ARGUMENTS` reaches the
      callee, whether variables set by the caller are visible, whose `allowed-tools` govern, what
      happens when the target skill is not enabled, and whether context accumulated in the caller
      survives the round trip.
      Verify: `ls SRD/edm/EDMV3__prompt-streamline/spike-skill-composition.md` and the note answers
      all six questions.
- [ ] AC2 (depth, not just existence): the spike tests at least two chained invocations in one
      session, not one, since the risk is depth.
      Verify: the note records the two-level chain and its outcome.
- [ ] AC3 (negative, disabled target): the spike records the failure mode for a disabled target skill
      precisely enough to write the graceful-degradation instruction required by EDMV3-50.
      Verify: the note contains the observed error text or behaviour for a disabled target.
- [ ] AC4 (explicit GO or NO-GO): the result is an explicit GO or NO-GO recommendation. On NO-GO the
      documented fallback in EDMV3-52 is adopted and EDMV3-T35 through EDMV3-T38 are rescoped
      accordingly, with the rescope recorded in `decisions.md`.
      Verify: `grep -n 'GO\b\|NO-GO' SRD/edm/EDMV3__prompt-streamline/decisions.md` returns the
      recommendation with its date.
- [ ] AC5 (ordering): the spike runs before any dispatcher edit is committed.
      Verify: `git log --format='%h %cI %s' -- plugins/edm/skills/orchestrator/SKILL.md SRD/edm/EDMV3__prompt-streamline/spike-skill-composition.md`
      shows the spike note committed first.
- [ ] AC6 (rule 2 rewritten, positive): architectural rule 2 documents the Skill-tool composition
      pattern -- the orchestrator dispatches, the phase skill owns its phase, and the procedure
      exists once -- and states the two caller obligations: `Skill` must appear in the caller's
      `allowed-tools`, and the caller must handle target-skill-not-enabled gracefully.
      Verify: `grep -n 'Skill-tool composition' plugins/edm/CLAUDE.md` returns the rewritten rule.
- [ ] AC7 (negative, the old sentence is removed not qualified): the "they each contain their own
      orchestration" sentence is **removed** from `CLAUDE.md` and appears nowhere else in the
      plugin, so it cannot be cited to justify re-introducing duplication.
      Verify: `grep -rl 'each contain their own orchestration' plugins/edm/ | wc -l` prints 0.
      (`grep -c` on a single file prints `0` but exits 1, so it fails a `set -e` verification block
      while reporting success; `grep -rl ... | wc -l` prints a count and exits 0 either way.)
- [ ] AC8 (concrete failure mode, precedent cited): rule 2 records the failure mode observed in AC3
      concretely enough to be actionable, and cites the git plugin as the in-repository precedent.
      Verify: `grep -n 'git plugin' plugins/edm/CLAUDE.md`.
- [ ] AC9 (other rules untouched): rule 1 (`commands/` is not re-introduced) and rules 3-4 are
      unchanged.
      Verify: `git diff plugins/edm/CLAUDE.md | grep '^-' | grep -c 'commands/'` returns 0.
- [ ] AC10 (intent-to-file index): explorer 02 C3.3's intent-to-file index is added, or an existing
      index is extended, so a contributor wanting to change explorer behaviour is told which file is
      authoritative rather than guessing among three.
      Verify: `grep -n 'intent-to-file\|which file is authoritative' plugins/edm/CLAUDE.md`.

### Technical Notes

- The spike is the go/no-go for four downstream tickets and costs half an hour. Do not fold it into
  EDMV3-T38 "while we are in there" -- the point is that the decision is made and recorded before the
  dispatcher is touched.
- Run the spike against an **installed plugin cache**, not the development tree, for the same reason
  EDMV3-T41 does: the runtime resolution behaviour is what matters.

### Out of Scope

- Any dispatcher edit -- EDMV3-T38.
- Adding `Skill` to the orchestrator's `allowed-tools` -- EDMV3-T38.
- The documented fallback script `bin/edm-check-skill-sync` -- EDMV3-T39. (CA-089 amendment:
  the GO path was taken and the script shipped anyway, as a regression tripwire rather than a
  fallback that was never exercised; `run-all.sh` invokes it unconditionally, not only on
  NO-GO. See EDMV3-T39's Technical Notes for the current framing.)

---

## EDMV3-T35: The gate PROTOCOL is written once and the weak protocol is deleted

| Field | Value |
|---|---|
| Epic | E5 -- Orchestrator as dispatcher |
| Wave | B |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV3-47, EDMV3-49 |
| Depends On | EDMV3-T03 |
| Ships-with | -- |
| Target Components | `plugins/edm/skills/orchestrator/SKILL.md:395-402` (the strong protocol, preserved verbatim), `:267-285` (Gate 3.5 block) and every gate site; `plugins/edm/skills/plan/SKILL.md:40`, `:130-132`; `plugins/edm/skills/audit-srd/SKILL.md:38`, `:122-124`; `plugins/edm/skills/audit-tickets/SKILL.md:40`, `:127-129`; `plugins/edm/skills/code-audit/SKILL.md:193-200` |

### Description

F4. The strong protocol at `skills/orchestrator/SKILL.md:395-402` is, in the reviewer's words,
"sharp, model-aware design" and its *text* is on the preserve-untouched list. What changes is that it
stops being one of two protocols and becomes the only one, in one location, cited by name from
everywhere else -- exactly the pattern the Severity vocabulary already proves works.

F4's sharpest edge is the deletion half: invoke `/edm:audit-srd` directly and a typed "looks good"
becomes a recorded Gate 2 approval; invoke `/edm:orchestrator` and it does not. **The deletion is
safe because the canonical PROTOCOL replaces it in the same merge request and the phase skills stop
containing approval-recording text at all** -- not because EDMV3-08 prevents the recording. EDMV3-08
only *documents* a settings block the plugin cannot ship, and `cmd_approve_gate` succeeds for any
caller on an install without the rules. Where the T1 rules *are* configured, a drifted skill
additionally cannot record an approval without a human click; that is a second line, not the first.

### Acceptance Criteria

- [ ] AC1 (positive, one canonical section): a named section
      `## Gate PROTOCOL (canonical)` exists exactly once in `skills/orchestrator/SKILL.md`.
      Verify: `grep -c '^## Gate PROTOCOL (canonical)$' plugins/edm/skills/orchestrator/SKILL.md`
      returns 1.
- [ ] AC2 (preserve verbatim): its text preserves the four existing rules verbatim -- `approve-gate`
      is called only on the exact "Approve" selection; free-text responses are not approvals;
      re-present on free text with "Please select an option to proceed."; never infer intent from
      sentiment.
      Verify: `grep -n 'Please select an option to proceed' plugins/edm/skills/orchestrator/SKILL.md`
      and a diff against `:395-402` showing no reword.
- [ ] AC3 (four additions): it additionally states STOP and WAIT for the `AskUserQuestion` response;
      headers are 12 characters or fewer; the three standard options are Approve, Revise, No-Go; and
      the `approve-gate` invocation happens only after the selection.
      Verify: `grep -n 'STOP and WAIT\|12 characters\|Approve, Revise, No-Go' plugins/edm/skills/orchestrator/SKILL.md`.
- [ ] AC4 (negative, zero restatements): every gate site in the plugin references it as
      `` `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"` `` rather than restating it. Gate 1,
      Gate 2, Gate 3, Gate 3.5 and the convergence gate all cite the same section.
      Verify: `grep -rn 'free-text is never approval\|free text is not an approval' plugins/edm/ | grep -v 'orchestrator/SKILL.md'`
      returns zero results -- confirmed live, round-3 Wave 7f: this exact pipeline returns 0 today.

      **Note -- why this AC's own test case describes the phrase it forbids, and does not fail.**
      `bin/tests/wave7-smoke.sh`'s "T35 AC4" case is a repo-wide scan that includes `bin/tests/`
      itself, and its own echo/label text literally spells out `'free-text is never approval'` to
      describe what it is asserting the absence of -- so the raw (pre-filter) scan does match its
      own source line before any exclusion runs. The result is correct only because that same echo
      line also happens to contain the literal substring `orchestrator/SKILL.md` (as part of its own
      human-readable description, "... outside orchestrator/SKILL.md"), which the `grep -v
      'orchestrator/SKILL.md'` filter incidentally strips along with the real gate-site restatements
      it exists to exclude. This is fragile, not a clean self-avoidance: a future rewording of that
      echo line that drops the literal substring `orchestrator/SKILL.md` (e.g. paraphrasing it)
      would resurface the self-match and turn this AC red with no change to any actual gate site.
      The needle is already built from split string parts (`t35_freetext_needle_a`/`_b`,
      concatenated at runtime) precisely to keep the *pattern itself* out of the source as a
      contiguous literal, but the plain-English echo/label text describing the case is not covered
      by that same protection.
- [ ] AC5 (negative, the weak gates are gone): `skills/plan/SKILL.md:130-132`,
      `skills/audit-srd/SKILL.md:122-124` and `skills/audit-tickets/SKILL.md:127-129` no longer
      contain free-prose approval questions -- "Ask: 'Do you approve ...?'" followed by "On approval:
      `edm-state approve-gate`".
      Verify: `grep -rn "Ask: .Do you approve" plugins/edm/skills/` returns zero results.
- [ ] AC6 (the abbreviated lines too): the earlier abbreviated approval lines in the same files
      (`skills/plan/SKILL.md:40`, `skills/audit-srd/SKILL.md:38`,
      `skills/audit-tickets/SKILL.md:40`) are checked and corrected to the same standard.
      Verify: `sed -n '38,42p' plugins/edm/skills/plan/SKILL.md plugins/edm/skills/audit-srd/SKILL.md plugins/edm/skills/audit-tickets/SKILL.md`
      shows by-name references only.
- [ ] AC7 (the fourth free-prose gate): `skills/code-audit/SKILL.md:193-200` is brought to the same
      standard -- upgraded to `AskUserQuestion` and retitled the *remediation* gate. EDMV3-20 gives
      the identical instruction (delivered in EDMV3-T15), so the two requirements agree rather than
      offering the implementer a choice.
      Verify: `grep -n 'remediation gate' plugins/edm/skills/code-audit/SKILL.md`.
- [ ] AC8 (grants present before the replacements can run): all four skills list `AskUserQuestion`
      in `allowed-tools`.
      Verify: `bash plugins/edm/bin/edm-check-grants; echo "exit=$?"` prints `exit=0`.
- [ ] AC9 (negative, no orphan approve-gate): no skill file contains an `approve-gate` invocation
      that is not preceded within the same section by the PROTOCOL reference.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "every approve-gate call site is
      preceded by the PROTOCOL reference").
- [ ] AC10 (smoke assertions): a smoke assertion checks the section exists exactly once and that
      each of the five gate sites contains the by-name reference.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (cases "PROTOCOL section appears once" and
      "five gate sites reference it").
- [ ] AC11 (prose-change convention): the merge request shows before and after for each deleted gate
      block plus one sentence of rationale (EDMV3-69).
      Verify: the MR description contains the before/after blocks.

### Technical Notes

- The PROTOCOL section must land in the orchestrator at the location it will still occupy after
  EDMV3-T38's restructure, so T38 moves nothing and the by-name references written here never
  dangle.
- Blocks EDMV3-T37 and EDMV3-T38. The phase-skill move (T37) ends each skill with "present the gate
  per the PROTOCOL", which requires the PROTOCOL to exist.
- Do not reword the four preserved rules. They are on the preserve-untouched list (EDMV3-111) and a
  reword is a finding at wave close.

### Out of Scope

- Moving the phase procedures -- EDMV3-T37.
- The 300-line cap -- EDMV3-T38.
- The convergence gate's own presentation -- EDMV3-T15 (wave A), which references this section by
  name at the location it will occupy.

---

## EDMV3-T36: Every phase skill opens with a Step 0 gate and branch preflight

| Field | Value |
|---|---|
| Epic | E5 -- Orchestrator as dispatcher |
| Wave | B |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV3-45 |
| Depends On | EDMV3-T01, EDMV3-T13, EDMV3-T33 |
| Ships-with | -- |
| Target Components | `plugins/edm/skills/{plan,srd,audit-srd,tickets,audit-tickets,implement,code-audit,verify-runtime}/SKILL.md`, `plugins/edm/bin/edm-state:1194-1237` (`cmd_gate_check`), `plugins/edm/bin/edm-state:1264-1286` (`cmd_branch_check`), `plugins/edm/hooks/hooks.json:13-78` (retained unchanged), `plugins/edm/CHANGELOG.md` |

### Description

Scope delta per `architecture.md` AD-3. The `UserPromptExpansion` gate-check hooks fire on
user-prompt expansion for five skills. They do not fire when the dispatcher reaches a phase skill
through the Skill tool.

**Step 0 is prompt text, which SRD Section 5.1 classifies as Tier 3 -- "cannot be bypassed by:
nothing".** It is therefore defence in depth and is described that way everywhere. The requirement
that actually restores deterministic enforcement on the Skill-tool path is EDMV3-115, which landed
in wave A as EDMV3-T13. Shipping Step 0 alone would trade a T1/T2 control for a T3 one and record the
trade as neutral.

### Acceptance Criteria

- [ ] AC1 (positive, all eight): every phase skill (`plan`, `srd`, `audit-srd`, `tickets`,
      `audit-tickets`, `implement`, `code-audit`, `verify-runtime`) begins with a Step 0 that runs
      `edm-state gate-check <PREFIX> <gated-command>` and `edm-state branch-check <PREFIX>`.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "all eight phase skills contain the
      Step 0 reference").
- [ ] AC2 (the token resolves to a real gate): the token each skill passes resolves to a real gate.
      Three of the eight -- `plan`, `code-audit`, `verify-runtime` -- previously fell through
      `cmd_gate_check`'s `*) return 0` branch and would have made Step 0 an unconditional no-op
      exactly where the dispatcher path matters most.
      Verify: `for t in plan srd audit-srd tickets audit-tickets implement code-audit verify-runtime; do edm-state gate-check TESTX "$t" >/dev/null 2>&1; echo "$t=$?"; done`
      shows a deliberate result for each, with none silently 0 by fall-through.
- [ ] AC3 (negative, gate-check blocks): a non-zero `gate-check` blocks the phase and surfaces the
      exact message the command printed.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "Step 0 text instructs a block on
      non-zero gate-check and surfaces the message").
- [ ] AC4 (negative, branch-check blocks -- and this is a behaviour change): a non-zero
      `branch-check` blocks the phase and surfaces the `git checkout <initiative_branch>`
      instruction it printed. This is a BLOCK, matching current orchestrator Step 1d semantics, and
      it is a **behaviour change on the standalone-skill path** -- today `branch-check` hard-blocks
      only at orchestrator Step 1d, so `/edm:code-audit PREFIX` run from `main` works, and reviewing
      an initiative from another branch is a common code-audit posture. It is recorded in
      `CHANGELOG.md`.
      Verify: `grep -n 'branch-check becoming a BLOCK' plugins/edm/CHANGELOG.md` and
      `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "Step 0 blocks on non-zero branch-check").
- [ ] AC5 (written once, referenced eight times): Step 0 is written once as a named block and
      referenced by the phase skills, not restated eight times, so it cannot drift.
      Verify: `grep -rc 'edm-state branch-check' plugins/edm/skills/*/SKILL.md` shows the full text
      in one file and a by-name reference in the others.
- [ ] AC6 (hooks retained): the existing `UserPromptExpansion` hooks are retained unchanged, so
      direct user invocation keeps its hook-side check as well. Both are defence in depth and neither
      is the deterministic layer.
      Verify: `git diff --stat plugins/edm/hooks/hooks.json` shows no change in this ticket.
- [ ] AC7 (mode suppression computed, not restated): phases whose gate does not apply under the
      initiative's mode -- a `skipped_phases` entry, or a gate beyond `terminal_phase_for_mode()` --
      pass Step 0 rather than blocking, and the suppression is computed by `cmd_gate_check` itself
      rather than restated in eight prompts.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "fast-track passes gate-check
      tickets") and `grep -c 'skipped_phases' plugins/edm/skills/*/SKILL.md` returns 0 for all
      eight.
- [ ] AC8 (negative, vocabulary): neither this ticket's text, nor SRD Section 5.6, nor the Glossary
      describes Step 0 as deterministic or as restoring deterministic gate enforcement. The phrase
      used throughout is "defence in depth on the Skill-tool path".
      Verify: `grep -rn -i 'step 0' plugins/edm/ | grep -i 'deterministic'` returns zero results.
- [ ] AC9 (branch advice is now correct): the `git checkout <initiative_branch>` advice Step 0
      surfaces is correct only because EDMV3-T01 fixed the recorded value.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "branch-check exits 0 after
      edm-init") is green.

### Technical Notes

- Depends on EDMV3-T13 for the three missing tokens and the hard-error default branch. Without it,
  AC2 is unsatisfiable in three skills.
- Depends on EDMV3-T01 because `branch-check` must be truthful before it is promoted to a BLOCK on a
  second code path. Blocking on a wrong value is worse than not blocking.
- **Depends on EDMV3-T33, and this ticket owns Step 0 for all eight skills.** The `verify-runtime`
  skill is the eighth of the eight and does not exist until T33 creates it, so AC1's "all eight" is
  unsatisfiable before T33 merges. The earlier note offered the implementer a choice -- "land T33
  first **or** add the Step 0 block to it as part of T33" -- which is two build orders where the
  ticket must declare one, and the second option produced a latent circular constraint with T33's
  own AC11. The build order is: T33 creates the skill without a Step 0 block, then this ticket adds
  Step 0 to all eight skills including that one. T33 AC11 is correspondingly narrowed to the gate
  token only, and both tickets record the choice.

### Out of Scope

- The kernel enforcement itself -- EDMV3-T13 (wave A).
- Removing the `UserPromptExpansion` hooks -- explicitly retained.
- The dispatcher restructure -- EDMV3-T38.

---

## EDMV3-T37: Each phase skill owns its phase entirely

| Field | Value |
|---|---|
| Epic | E5 -- Orchestrator as dispatcher |
| Wave | B |
| Priority | Must Have |
| Size | L |
| SRD Refs | EDMV3-48 |
| Depends On | EDMV3-T03, EDMV3-T35, EDMV3-T36 |
| Ships-with | EDMV3-T38 |
| Target Components | `plugins/edm/skills/{plan,srd,audit-srd,tickets,audit-tickets,implement,code-audit,verify-runtime}/SKILL.md`, `plugins/edm/skills/orchestrator/SKILL.md` (the six inline phase procedures being removed), `plugins/edm/bin/tests/wave4b-smoke.sh` (the `$ORCH` assertion set) |

### Description

The phase procedure moves from the orchestrator into its phase skill as the single source of truth.
This is what makes EDMV3-T38 possible and what kills the F4 class permanently.

**Size justification (L).** Six phase procedures move across eight files, each move requiring a
reconciliation decision where the two copies have drifted, and every relocated smoke assertion must
be re-baselined in the same merge request. Decomposing by phase would leave the plugin in a state
where three procedures live in the phase skill and three still live in the orchestrator, which is
strictly worse than either endpoint: the duplication is gone in some places and doubled in others,
and no smoke assertion set is coherent. The move is atomic by nature.

### Acceptance Criteria

- [ ] AC1 (positive, single source of truth): for each of the six phases, the complete procedure --
      agent spawn templates, spawn counts, artifact templates, output paths, `edm-state` calls --
      lives in that phase's SKILL.md and nowhere else. "Phase skill" means the eight skills
      enumerated in EDMV3-45, with `code-audit` and `verify-runtime` both belonging to Phase 6.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "each phase's agent spawn template
      text appears in exactly one file").
- [ ] AC2 (negative, no orchestrator copy): `skills/orchestrator/SKILL.md` contains no agent spawn
      template, no artifact template, and no per-phase step list.
      Verify: `grep -c 'Task tool\|spawn the .edm-' plugins/edm/skills/orchestrator/SKILL.md`
      returns 0.
- [ ] AC3 (reconciliation is deliberate, not accidental): where the orchestrator copy and the phase
      skill copy currently differ, the merged version is a recorded reconciliation. Each divergence
      found during the move is listed in the merge request description with the resolution chosen
      and one sentence of rationale.
      Verify: the MR description contains a divergence table with one row per difference found.
- [ ] AC4 (gate handoff): each phase skill ends with
      "present the gate per `skills/orchestrator/SKILL.md Sec.\"Gate PROTOCOL\"`" and contains no
      local approval text.
      Verify: `for s in plan srd audit-srd tickets audit-tickets implement code-audit verify-runtime; do tail -20 "plugins/edm/skills/$s/SKILL.md" | grep -q 'Gate PROTOCOL' || echo "MISSING: $s"; done`
      prints nothing.
- [ ] AC5 (standalone still works, including gate presentation): each phase skill still functions
      standalone when invoked directly by the user, including the Step 0 preflight and gate
      presentation -- which requires the `AskUserQuestion` grant from EDMV3-T03, without which
      "functions standalone including gate presentation" is not achievable in four of the eight
      skills.
      Verify: `/edm:audit-srd EDMV3` invoked directly runs Step 0, executes the phase, and presents
      the gate via `AskUserQuestion`. Recorded as a manual-QA case in the ticket.
- [ ] AC6 (one owning file per phase, phase-complete-6's three-way split sanctioned): for each of
      the six phases N=1..6, exactly one phase skill's SKILL.md contains `phase-start <PREFIX> N`.
      The same holds for `phase-complete <PREFIX> N`, except phase 6, where exactly three files
      contain it: the orchestrator (the owning call, EDMV3-T50), `skills/implement/SKILL.md` and
      `skills/verify-runtime/SKILL.md` (both documented direct-invocation restatements for a user
      who invokes the phase standalone, EDMV3-T50 AC5). `skills/tickets/SKILL.md` legitimately
      contains a second `phase-start <PREFIX> 4` occurrence for its fast-track mode-branch
      duplicate; both occurrences live in the same file, so phase 4 still has exactly one owning
      file, not two.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "T37 AC6 -- one owning file per
      phase-start/phase-complete call (phase-complete 6's three-file split is the documented
      orchestrator-owns/implement+verify-runtime-restate-for-direct-invocation exception,
      EDMV3-T50)").

      **Note -- why the obvious command does not work.** The obvious form,
      `grep -rc 'phase-start' plugins/edm/skills/*/SKILL.md` summed across files, does not return 8
      (one per phase skill) -- it returns **7**. This is not a defect. The contract is per-*phase*
      (six phases), not per-*skill* (fourteen skills, only eight of which own a numbered phase):
      `skills/code-audit/SKILL.md` and `skills/verify-runtime/SKILL.md` are Phase 6's two sub-skills
      and carry no `phase-start` call of their own -- Phase 6's single owning `phase-start` lives in
      `skills/implement/SKILL.md` -- while `skills/tickets/SKILL.md` carries two occurrences (the
      base call plus the sanctioned fast-track mode-branch duplicate described above) that both
      count toward the same phase-4 owning file, not two owners. A future reader re-deriving "one
      phase-start per phase skill" from a bare per-skill literal sum always lands on 7, never 8, and
      "fixing" the sum to 8 would mean adding a spurious `phase-start` call to a Phase 6 sub-skill
      that must not own one. The per-phase ownership check above -- not the per-skill sum -- is what
      actually verifies this AC.
- [ ] AC7 (assertions re-baselined in the same MR): every smoke assertion on text this move
      relocates is re-baselined in the same merge request. Each is either re-pointed at the phase
      skill that now owns the text or deleted with a one-line reason in the MR description.
      Verify: `bash plugins/edm/bin/tests/run-all.sh; echo "exit=$?"` prints `exit=0`, and the MR
      description lists each re-pointed or deleted assertion.
- [ ] AC8 (no content lost): any content present in one copy but not the other is preserved in the
      merged version, not dropped. Each such case is listed in the merge request description.
      Verify: the divergence table from AC3 marks each row as `merged`, `orchestrator-wins`,
      `skill-wins` or `both-preserved`, with none marked `dropped` without a rationale sentence.
- [ ] AC9 (numbering, per-skill): every numbered list in each phase skill after the move has strictly
      ascending numbering with no repeats and no gaps.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "numbered lists in skills are
      strictly ascending").
- [ ] AC10 (prose-change convention): the merge request shows before and after for each moved block
      plus one sentence on why the merged wording is better (EDMV3-69).
      Verify: the MR description contains the before/after blocks.

### Technical Notes

- Ships with EDMV3-T38 in the same MR. The orchestrator cannot drop below 300 lines until the
  procedures have somewhere to live, and the phase skills cannot own their phases while the
  orchestrator still runs them.
- Around thirty `$ORCH` assertions are at risk in `bin/tests/wave4b-smoke.sh`. Enumerate them before
  starting the move -- `grep -n '\$ORCH' plugins/edm/bin/tests/wave4b-smoke.sh` -- and treat the list
  as the AC7 checklist.
- CI landed in wave A and blocks merge on red, so an unmigrated assertion is a pipeline stop rather
  than a nuisance. That is the mechanism, not a hope.
- The divergence table is the most valuable artifact this ticket produces. It is the only record of
  what the two copies actually disagreed about after months of hand-syncing.

### Out of Scope

- The 300-line cap and the mode sub-flow relocation -- EDMV3-T38.
- The gate PROTOCOL section -- EDMV3-T35.
- The explorer fan-out cap that lands in `skills/plan/SKILL.md` after this move -- EDMV3-T47
  (wave C).

---

## EDMV3-T38: The orchestrator becomes a dispatcher of at most 300 lines

| Field | Value |
|---|---|
| Epic | E5 -- Orchestrator as dispatcher |
| Wave | B |
| Priority | Must Have |
| Size | L |
| SRD Refs | EDMV3-46, EDMV3-51 |
| Depends On | EDMV3-T13, EDMV3-T34, EDMV3-T35, EDMV3-T36 |
| Ships-with | EDMV3-T37 |
| Target Components | `plugins/edm/skills/orchestrator/SKILL.md` (entire file, 645 lines today: methodology context `:11-53`, intake `:55-148`, Step 1d safety `:289-299`, mode dispatch `:149-287`, gate PROTOCOL `:395-402`, anti-patterns `:636-645`, duplicate numbering at `:417-423`, `:432-433`, `:478-479`, `current_step` vocabulary at `:127-130`), `plugins/edm/CLAUDE.md`, `plugins/edm/bin/tests/wave4b-smoke.sh:123-125` and the wider `$ORCH` set, `plugins/edm/CHANGELOG.md` |

### Description

D10. `skills/orchestrator/SKILL.md` is 645 lines containing all six phase procedures inline,
duplicated in the phase skills and already drifted. The dispatcher retains only what genuinely
belongs to orchestration.

**The cap is derived, not asserted.** SRD Section 6 EDMV3-46 carries the derivation table: methodology
context ~35, intake ~90, mode dispatch ~30, gate PROTOCOL ~18, resume and compaction ~20,
anti-patterns ~12, six invoke-and-gate entries ~40, `## Communication` plus `<tone_preference>` ~20,
frontmatter and structure ~20 -- total ~285. **The cap is 300**, the derived total plus a small
margin and no more. The same number appears in the SRD, in `architecture.md` and in `planning.md`.

**Size justification (L).** This is a full rewrite of the most-loaded prompt in the system, with a
content-relocation map, a `current_step` vocabulary migration, roughly thirty smoke-assertion
re-baselines, and an eval comparison as an acceptance gate. Decomposing it produces intermediate
states that are strictly worse than either endpoint -- a half-collapsed orchestrator has neither the
old procedures nor the new dispatch, and the eval comparison in EDMV3-T39 has no coherent subject.
The risk is managed by the harness (E3), the spike (T34) and the fallback (T39), not by splitting.

### Acceptance Criteria

- [ ] AC1 (negative, hard cap): `skills/orchestrator/SKILL.md` is at most **300** lines, asserted by
      a smoke test that fails above the limit. The derivation table is reproduced in the merge
      request so a future change to the retained set re-derives rather than re-guesses.
      Verify: `wc -l < plugins/edm/skills/orchestrator/SKILL.md` is at most 300, asserted by
      `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "orchestrator at most 300 lines").
- [ ] AC2 (positive, retained set is exact): it retains exactly methodology context, intake Steps
      1a-1d, mode dispatch (table and routing), the gate PROTOCOL, resume and compaction logic, the
      anti-patterns section, the `## Communication` section and `<tone_preference>` block, and
      per-phase entries of the form "invoke `/edm:{phase}`, then present Gate N per the PROTOCOL".
      Verify: `grep -c '^## ' plugins/edm/skills/orchestrator/SKILL.md` matches the retained-section
      count listed in the MR, and each is present.
- [ ] AC3 (negative, no phase procedure body): it contains no phase procedure body -- no agent spawn
      templates, no artifact templates, no per-phase step lists beyond the invoke-and-gate line.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "orchestrator contains no spawn
      template"), using `check_absent`.
- [ ] AC4 (Skill grant, exactly one): phase invocation uses the Skill tool and `Skill` is added to
      the orchestrator's `allowed-tools`. No other skill gains `Skill`.
      Verify: `grep -rn 'allowed-tools' plugins/edm/skills/*/SKILL.md | grep -c 'Skill'` returns 1,
      and `bash plugins/edm/bin/edm-check-grants` exits 0.
- [ ] AC5 (negative, graceful degradation): a target skill that is not enabled is handled with the
      failure mode observed in EDMV3-T34 -- the orchestrator reports which skill is unavailable and
      what the user must enable, and does not silently continue. It never falls back to inlining the
      phase procedure.
      Verify: disable one phase skill in a sandbox and confirm `/edm:orchestrator EDMV3` reports the
      unavailable skill by name and stops. Recorded as a manual-QA case.
- [ ] AC6 (content relocation map): the three mode sub-flows (`mini-srd`, `prototype`, `fast-track`)
      and the Gate 3.5 block move out of the dispatcher -- to the phase skills where their steps
      belong and to `CLAUDE.md` for the mode matrix itself. The artifact layout block and phase
      timing guidelines likewise move to `CLAUDE.md` with a by-name reference. Each piece of content
      exists in exactly one place afterwards, and the merge request lists where each moved.
      Verify: `grep -ic 'mini-srd' plugins/edm/skills/orchestrator/SKILL.md` returns only the
      routing row's mention(s) -- the dispatcher writes the display-cased form `mini-SRD` in its
      mode-header and Gate-2/3 routing text, not the lowercase enum form, so the grep is
      case-insensitive -- and the MR description contains the relocation table.
- [ ] AC7 (resume preserved): `edm-state current-step` read and write, `SessionStart` resume points,
      and HANDOFF refresh all continue to work.
      Verify: `bash plugins/edm/bin/tests/wave5-smoke.sh` is green and `edm-state session-start`
      emits a resume point for an active initiative.
- [ ] AC8 (`current_step` vocabulary defined and old values tolerated): the post-restructure
      `current_step` vocabulary is defined, a mapping from the 2.x values (`1a`, `1b`, `1c`,
      `2`..`6`, `2.srd`, `4.epic-N`, documented at `:127-130`) is published, and an unrecognized
      `current_step` resumes at the start of its phase with a warning rather than erroring. The
      mapping is recorded in `CHANGELOG.md`.
      Verify: `edm-state set TESTX current_step 2.srd && /edm:orchestrator TESTX` resumes at the
      start of phase 2 with a warning, and `grep -n 'current_step' plugins/edm/CHANGELOG.md`.
- [ ] AC9 (numbering drift cleaned): every numbered list in the surviving orchestrator content has
      strictly ascending numbering with no repeats and no gaps -- the duplicate "5." items at
      `:417-423`, and the duplicates at `:432-433` and `:478-479`, are resolved. Any content
      orphaned by a duplicate number is preserved in the merged version, not dropped, and each such
      case is listed in the MR description.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "numbered lists strictly
      ascending").
- [ ] AC10 (assertions re-baselined, known-red set named): every smoke assertion on relocated
      orchestrator text is re-baselined in the same merge request. The known-red set includes
      `bin/tests/wave4b-smoke.sh:123` ("Impl mode"), `:124` ("TDD") and `:125`
      ("set-mode <PREFIX> implementation_mode"), all asserting Step 7 text this ticket forbids the
      dispatcher from retaining.
      Verify: `bash plugins/edm/bin/tests/run-all.sh; echo "exit=$?"` prints `exit=0`.
- [ ] AC11 (eval artifact is a hard acceptance criterion): the eval is run before and after and its
      `scores.json` is attached to the merge request. "CI will catch it" is not a substitute.
      Verify: the MR has `scores.json` attached and EDMV3-T39's comparison job is green.
- [ ] AC12 (phases-as-data boundary confirmed): no `phases.json`, phase-graph interpreter, or
      mode-as-graph-variant code is introduced. The dispatcher is compatible with such a future
      shape without being built for it. This is the negative enforcement of EDMV3-86, a Won't Have
      and a recorded scope boundary (D14) rather than a delivery of this ticket, which is why
      EDMV3-86 is not an `SRD Refs` entry. The negative-test case asserting this AC's own absence
      necessarily contains the literal string `phases.json` to describe what it is checking for,
      which lives in `bin/tests/`, inside the same documented carve-out EDMV3-T09 AC13 already
      uses for this exact self-reference shape.
      Verify: `grep -rl 'phases.json' plugins/edm/ | grep -v '/bin/tests/' | wc -l` prints 0.
- [ ] AC13 (the Phase 6 Skill invocation lands here, with its grant): the dispatcher's Phase 6 entry
      contains the `/edm:verify-runtime` Skill-tool invocation, in the same merge request as AC4's
      `Skill` grant. EDMV3-T33 deliberately adds no Skill call to the orchestrator, because a
      Skill-tool call in the tree ahead of its grant reds `bin/edm-check-grants` in CI for the whole
      interval between the two merges; EDMV3-T50 then wires `phase-complete 6` after it in wave C.
      The grant and its first use ship together, which is the same rule EDMV3-T03 and EDMV3-T15
      follow in wave A.
      Verify: `grep -n 'verify-runtime' plugins/edm/skills/orchestrator/SKILL.md` returns the Skill
      invocation in the Phase 6 entry, and `bash plugins/edm/bin/edm-check-grants; echo "exit=$?"`
      prints `exit=0` on the merge commit.
- [ ] AC14 (the MR is two reviewable commits): this ticket and EDMV3-T37 ship as one merge request,
      and by the pack's own legend two L tickets in one MR is a 16-21 point delivery unit -- an XL
      by size, wearing two L labels. It is not decomposed, for the reasons in both size
      justifications, so the risk is managed at review time instead: the merge request is structured
      as **exactly two reviewable commits**, the first moving the phase procedures into the phase
      skills (EDMV3-T37) with every relocated assertion re-baselined and the suite green, the second
      collapsing the orchestrator to the 300-line dispatcher (this ticket). Each commit is green on
      its own, so a reviewer can read and revert either half independently.
      Verify: `git log --oneline <merge-base>..HEAD -- plugins/edm/skills/` shows exactly two
      commits, and `git stash`-free checkout of the first commit alone runs
      `bash plugins/edm/bin/tests/run-all.sh` to `exit=0`. Both outputs are recorded in the MR
      description alongside the combined-unit note from the README Ships-with table.

### Technical Notes

- Ships with EDMV3-T37 in one MR. See T37's technical notes for why. `Ships-with` is a same-MR
  relationship and **not** a build-order edge, so EDMV3-T37 is deliberately absent from
  `Depends On`: declaring both fields for the same pair says two contradictory things about it. The
  combined unit is recorded as one L-class 16-21 point delivery in the README Ships-with table, and
  AC14 gives it a two-commit internal structure.
- Enumerate the `$ORCH` assertion set before starting:
  `grep -n '\$ORCH' plugins/edm/bin/tests/wave4b-smoke.sh`. Roughly thirty assertions are at risk.
- The `## Communication` section and `<tone_preference>` block (EDMV3-T45, wave C) are budgeted
  inside the 300-line cap, which was re-derived to include them. Do **not** re-baseline the cap when
  T45 lands -- it already accounts for the ~20 lines.
- On a NO-GO from EDMV3-T34, this ticket is rescoped per EDMV3-T39's documented fallback and the
  rescope is recorded in `decisions.md`. Waves A and C proceed unaffected.

### Out of Scope

- The eval comparison and the fallback decision -- EDMV3-T39.
- `## Communication` and `<tone_preference>` content -- EDMV3-T45 (wave C), budgeted here.
- Any change to the phase skills' bodies -- EDMV3-T37.

---

## EDMV3-T39: The refactor is gated on an eval comparison with a documented fallback

| Field | Value |
|---|---|
| Epic | E5 -- Orchestrator as dispatcher |
| Wave | B |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV3-52 |
| Depends On | EDMV3-T23, EDMV3-T38 |
| Ships-with | -- |
| Target Components | `.gitlab-ci.yml` (the comparison job), `plugins/edm/evals/baseline/scores.json`, `plugins/edm/evals/run-eval.sh` (the stop-before-gate contract re-verification), `plugins/edm/bin/edm-check-skill-sync` (fallback tripwire, shipped and also used on the rollback path), `SRD/edm/EDMV3__prompt-streamline/decisions.md` |

### Description

`architecture.md` R-A and R-K. The dispatcher rewrites the most-loaded prompt in the system, and a
regression there is expensive and hard to see. The eval is the tripwire. If nobody runs it, the
mitigation evaporates -- which is RK-13, and why the run artifact is a hard acceptance criterion
rather than a suggestion.

### Acceptance Criteria

- [ ] AC1 (positive): the eval is run against the post-refactor code and its `scores.json` is
      attached to the merge request.
      Verify: the MR has the artifact attached and `jq -e '.complete == true' <attached>/scores.json`.
- [ ] AC2 (comparison lives in CI, not the scorer): the total score is compared against the wave-A
      baseline **by the CI job**, not by the scorer. Acceptance requires the total to be at or above
      `baseline_total - (max - min across the three baseline runs)`.
      Verify: `grep -n 'baseline_total' .gitlab-ci.yml` shows the comparison expression, and the job
      is green.
- [ ] AC3 (negative, refused comparisons -- three refusal conditions): the comparison is refused,
      with a message naming the mismatch, when the two `scores.json` files carry different
      `scorer_version` values, when they carry different `dimensions_scored` values, or when the
      post-refactor run is flagged `complete: false`. The `dimensions_scored` condition is the one
      that matters here in practice: the wave-A baseline is a **four**-dimension figure (EDMV3-T23
      AC8) because the driver runs no code audit, so a post-refactor run that does include one
      produces a five-dimension score whose mean has a different denominator. Comparing them
      produces a delta with no meaning (srd.md v1.2.0 CR6).
      Verify: run the job three times against hand-edited `scores.json` files -- one with a bumped
      `scorer_version`, one with `dimensions_scored` changed from 4 to 5, one with
      `complete: false` -- and confirm each exits non-zero with a refusal message naming its own
      condition.
- [ ] AC4 (per-dimension check): a per-dimension comparison is included, and any single dimension
      regressing by more than that dimension's recorded baseline range is explained in the merge
      request description even when the total passes.
      Verify: the job prints a five-row per-dimension delta table, and the MR explains any row
      exceeding its range.
- [ ] AC5 (stop-before-gate contract re-verified against the final PROTOCOL): the driver's
      stop-before-gate instruction is re-verified against the wave-B PROTOCOL wording from
      EDMV3-T35, and any change to driver behaviour is recorded. If the change is material, the
      baseline is invalidated and re-captured before the comparison is trusted. Re-verified this
      wave (round-3 Wave 7f): `run-eval.sh`'s driver prompts already use "STOP and WAIT" phrasing
      (e.g. "no STOP and WAIT text, no waiting for sign-off"), matching the canonical PROTOCOL's
      "**STOP and WAIT for the `AskUserQuestion` response**" verbatim at
      `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL (canonical)"`. No material change -- the
      terminology already agrees, so the baseline is not invalidated. Recorded in `decisions.md`.
      Verify: `grep -n 'STOP and WAIT' plugins/edm/evals/run-eval.sh` matches the final PROTOCOL's
      terminology.
- [ ] AC6 (negative, "CI will catch it" is invalid): "CI will catch it" is documented as an invalid
      substitute for running the eval, and the run artifact is a hard acceptance criterion on
      EDMV3-T38.
      Verify: `grep -n 'CI will catch it' plugins/edm/evals/README.md` returns the statement, and
      EDMV3-T38 AC11 is checked.
- [ ] AC7 (tripwire shipped regardless of GO/NO-GO, amended per CA-089): the GO path was taken
      (the T34 spike recommended GO; EDMV3-T37/T38 deduplicated the phase procedures into the
      dispatcher's Skill-tool dispatch), and `bin/edm-check-skill-sync` still ships -- not as a
      fallback that reverts the dispatcher change, but as a regression tripwire proving the
      deduplication holds. It asserts the inverse of the original wording: the dispatcher
      (`skills/orchestrator/SKILL.md`) contains **no** phase procedure body (no phase skill's
      `## Operational Orchestration` marker appears in it), and every phase skill still owns its
      own `## Operational Orchestration` section. `run-all.sh` runs it unconditionally, as part
      of the smoke suite, on every invocation -- not only on a comparison failure.
      Verify: `bash plugins/edm/bin/edm-check-skill-sync; echo "exit=$?"` prints `exit=0` on the
      current (deduplicated) tree; pasting a phase skill's `## Operational Orchestration` section
      body back into `skills/orchestrator/SKILL.md`, or deleting that section from any phase
      skill, makes it exit 1 and name the specific violation.
- [ ] AC8 (fallback recorded, waves unaffected): the fallback decision, if taken, is recorded in
      `decisions.md` with the score comparison that triggered it, and waves A and C proceed
      unaffected.
      Verify: `grep -n 'dispatcher fallback' SRD/edm/EDMV3__prompt-streamline/decisions.md`.
- [ ] AC9 (trend preserved, walked back to T23 AC11's naming-convention wording -- decisions.md
      records the rework): the nightly `scores.json` files remain named or tagged such that a
      simple script **could** plot total score over time after this comparison job lands -- the
      naming convention exists and is documented; no plotting script is required to exist. This
      matches the wording T39 AC9 originally escalated from (`epics/03-ci-and-fixture-eval.md`
      T23 AC11), which asks only that artifacts be named or tagged so a script could be written,
      not that one already is. `evals/runs/` is gitignored (never committed), so a run-directory
      listing is never present in a clean checkout regardless of naming; the naming convention
      itself, not a populated directory, is what this AC verifies.
      Verify: `grep -n 'timestamp.*git-sha\|<timestamp>_<git-sha>' plugins/edm/evals/README.md`
      shows the documented run-directory naming convention.

### Technical Notes

- **Resolved in srd.md v1.2.0 (CR2), no longer an open ambiguity.** EDMV3-26 previously listed
  EDMV3-47 as a build-order dependency while EDMV3-28 required the baseline to precede wave B -- a
  wave-A requirement depending on a wave-B one. EDMV3-26's `Dependencies` are now EDMV3-25 only and
  the ordering survives as a soft edge in SRD Section 11.2, discharged by **AC5 of this ticket**:
  the wave-A baseline is captured against the pre-PROTOCOL gate text, and this ticket re-verifies
  and, if needed, re-captures. Record the outcome either way -- a "no material change" finding is as
  useful as a re-capture.
- The comparison job must read the variance figure from `baseline/scores.json`'s machine-readable
  field, not parse `baseline/README.md`.
- **(Amended per CA-089.)** `bin/edm-check-skill-sync` was originally scoped to be written only
  on the fallback path, to avoid building it speculatively before a GO/NO-GO decision existed.
  The GO path was taken and the script was built anyway, reframed as a regression tripwire (see
  AC7 above) rather than deleted -- `run-all.sh` invokes it unconditionally. This amendment
  records the rework; it does not reopen AC7.

### Out of Scope

- The scorer and the baseline -- EDMV3-T23 (wave A).
- Re-running the eval for lens tiering -- EDMV3-T48 (wave C), which is a different comparison
  against a different fixture configuration.
