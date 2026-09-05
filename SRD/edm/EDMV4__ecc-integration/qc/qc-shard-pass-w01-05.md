# QC Audit Report: EDMV4 -- ECC Integration, Wave 1 [Shard 5/5]

**Date**: 2026-09-04
**Tickets audited**: `EDMV4-T54`, `EDMV4-T55` (2 of 2 assigned)
**Tree audited**: `edm/edmv4-ecc-integration` @ `581db12`, main working tree (no worktree). The one
uncommitted change (`.edm-state.json`) is a `checkpoint-if-active` findings-ledger hash written at
`2026-09-05T03:10:50Z`; it touches nothing either ticket owns.

Commissioned to close code-audit finding CA-006. Both tickets are Phase-1, `Depends On: none`,
retroactive "written after the fact" tickets, and neither carried an acceptance-criteria verdict in
any existing shard -- each appears in the earlier shards only as incidental prose.

## Wave placement, and the one case that does not fit

`EDMV4-T55` is unambiguously wave 1. Its implementing commit `a0959a8` lands 2026-09-02 15:03,
after wave 1's implementer batch (`94dd043` 12:53 through `fd60bfd` 13:48) and before the wave-1 QC
remediation (`9a63ac8` 15:25) and the wave-1 shard merge (`47811c9` 15:53). The ticket's own
Description says so directly: "the fixes were applied during wave 1 because every subsequent wave
pays the same cost otherwise."

**`EDMV4-T54` has no Phase 6 wave, and this is stated rather than papered over.** Its implementing
commit `3e20ed2` lands 2026-09-02 12:36 -- the direct parent of `1ea4994`
("EDMV4 Phases 4-5 -- 52-ticket pack, audit, SRD v1.2.0, Gates 2 and 3") and 17 minutes before wave
1's first implementer commit. It was found and fixed during **Phase 5 preflight**, exactly as its
own Description records ("EDMV4 is the first standard-lifecycle initiative to reach the check, and
found it in its own Phase 5 preflight"). It therefore predates Phase 6 entirely.

It is placed in this wave-1 shard, with that stated rationale, because: it is the commit immediately
preceding wave 1's first; it is a Phase-1 ticket in the pack exactly as `T55` is; and `T55`'s own
Description names it as the sibling precedent for a retroactive ticket raised at a gate
("raised for ratification at the code-audit convergence gate, the same way `EDMV4-60`/`EDMV4-T54`
was raised at Gate 3"). No wave number was invented for it; the `range=` field of this shard's
sentinel names the two tickets, not a wave.

## Summary

| Ticket | Title | Verdict |
|---|---|---|
| `EDMV4-T54` | Map `audit-tickets` to the gate it consumes, not the one it produces | **PASS** |
| `EDMV4-T55` | Fix Phase 6's agent capacity and QC wiring, found by running EDM on itself | **PASS** |

**Totals**: 2 PASS, 0 PARTIAL, 0 FAIL, across 19 acceptance criteria. Three P2 observations, no
remediation-blocking findings.

Every behavioral claim below was executed, not inferred. `bash plugins/edm/bin/tests/run-all.sh`
was run to completion by this audit: **3289 passed, 0 failed across 8 suites, exit 0**, under
`/bin/bash` 3.2.57(1)-release (arm64-apple-darwin25) on macOS Darwin 25.6.0 -- which is the exact
interpreter and platform `T54` AC8 names, and `PATH` `bash` on this host resolves to `/bin/bash`, so
`run-all.sh`'s own `bash "$suite"` dispatch (`run-all.sh:120`) inherits it. That green run is
first-hand evidence here, not a carried-forward claim.

---

## Detailed Findings

### `EDMV4-T54`: Map `audit-tickets` to the gate it consumes, not the one it produces -- PASS

The three behavioral criteria (AC2, AC3, AC4) were executed against a throwaway initiative in a
scratch git repository rather than read off the `case` arm, because the arm alone does not prove the
`gate_required_and_approved` path downstream of it behaves as the AC states:

```
gate 2 unapproved,  gate-check T54X audit-tickets -> rc=3   (AC4)
gates 1+2 approved, gate-check T54X audit-tickets -> rc=0   (AC2)
gates 1+2 approved, gate-check T54X implement     -> rc=3   (AC3)
```

- [x] **AC1** -- `bin/edm-state:4172` is `tickets|audit-tickets) required_gate=2 ;;`, one arm, with
      the fix's rationale inline at `:4170-4171`. `implement)` keeps `required_gate=3` on an arm of
      its own at `:4173`, and `code-audit|verify-runtime` sits on a third at `:4174`. The two arms
      were not collapsed into `tickets|audit-tickets|implement`, which the Technical Notes
      explicitly forbid as a fresh instance of the same bug class.
- [x] **AC2** -- exit 0 with Gate 2 approved and Gate 3 unapproved, captured above. Confirmed the
      fixture really was in that state: `gates_approved[].gate` read back `1,2`.
- [x] **AC3** -- `implement` still exits 3 on that same initiative, so the change narrowed exactly
      one token and did not weaken Phase 6's gate. `GATE_CHECK_REFUSED=3` (`bin/edm-state:4154`) is
      the dedicated refusal code the hook consumer greps for, not a generic non-zero.
- [x] **AC4** -- exit 3 when Gate 2 is not approved. Enforcement moved, not removed.
- [x] **AC5** -- the `Gated commands and their required gates` docstring at `bin/edm-state:4124-4130`
      states the corrected mapping (`tickets | audit-tickets -> Gate 2 must be approved` at `:4128`),
      and `:4132-4140` records the invariant in the form the AC requires: "the token maps to the gate
      a phase skill CONSUMES, never the one it PRODUCES", with `audit-srd` named as the second
      instance so the rule reads as general rather than as a one-off patch.
- [x] **AC6** -- `bin/tests/wave6-smoke.sh:1236-1258` replaces the old `*"Gate "*` acceptance with
      `for tok_spec in plan:0 srd:1 audit-srd:1 tickets:2 audit-tickets:2 implement:3 code-audit:3
      verify-runtime:3`, asserting `"$tok_out" == *"Gate ${tok_want} has not been approved"*` at
      `:1250`. A wrong-but-present gate number now fails at `:1253` instead of passing. The loop
      counts to 8 and `:1257` fails on any shortfall, so a token silently dropping out of the
      enumeration is caught too. `wave6-smoke.sh` ran 796 passed / 0 failed in this audit's suite
      run.
- [x] **AC7** -- `wave6-smoke.sh:1260-1305` implements all four lettered clauses, and I checked each
      against the tree rather than against the comment above it:
      **(a)** the token set is derived live from `cmd_gate_check`'s own `Valid tokens:` line
      (`:1275-1276`), with `:1277-1278` failing outright if that derivation yields nothing --
      so a reworded error line is a loud failure, not a silent empty loop.
      **(b)** the produced gate comes from each skill's own `^## HITL Gate [0-9]+` heading
      (`:1286`). Verified live: `plan` presents Gate 1, `audit-srd` Gate 2, `audit-tickets` Gate 3;
      the other five present none and are skipped at `:1287`.
      **(c)** `:1296` fails on `gc_consumes -ge gc_produces`, which is the strict-inequality form
      the AC specifies.
      **(d)** `:1301-1302` fails when fewer than two gate-presenting skills are found. Live count is
      3, so the guard is satisfied with margin, and the two real comparisons the AC names
      (`audit-srd` 1 vs 2, `audit-tickets` 2 vs 3) both execute.
      No hardcoded pair list exists anywhere in the block -- the thing the ticket-pack audit (P1-8)
      rejected in the first implementation.
- [x] **AC8** -- `run-all.sh`: 3289 passed, 0 failed, 8 suites, exit 0, on macOS under `/bin/bash`
      3.2.57(1)-release. Run by this audit, not quoted from the ticket.
- [x] **AC9** -- `plugins/edm/CHANGELOG.md:129-151` records it under `## [Unreleased]` / `### Fixed`
      as a user-visible bug fix, naming the deadlock, both enforcement layers, why it escaped
      detection, and why it went unnoticed until now. `git show 3e20ed2 -- plugins/edm/CHANGELOG.md`
      is `27 insertions(+)`, `0 deletions` -- no historical entry was edited, which is the half of
      this AC a diff proves and prose cannot.

**P2 observation (not remediation-blocking)**: AC7's vacuity guard covers only the **producer** half
of its own derivation. `gc_pairs_checked` is incremented at `wave6-smoke.sh:1288`, which is reached
as soon as a skill has a `## HITL Gate N` heading -- before `gc_consumes` is derived at `:1293` and
before the `[[ -n "$gc_consumes" ]] || continue` skip at `:1295`. If the refusal wording
`Gate N has not been approved` ever changed, `gc_consumes` would be empty for every token, all three
iterations would `continue`, `gc_circular` would stay 0 and `gc_pairs_checked` would still read 3 --
and the assertion at `:1303-1305` would pass having compared nothing. AC7(d) as literally worded
("fewer than two gate-presenting skills") is met, so this is not a FAIL; but the clause's stated
purpose ("so a broken derivation can never pass vacuously") is only half-achieved. A one-line fix
closes it: count a second variable at `:1295` for iterations that actually reach the comparison, and
require **that** to be `>= 2`.

### `EDMV4-T55`: Fix Phase 6's agent capacity and QC wiring -- PASS

This is the ticket whose AC5 exists to prevent precisely the failure that produced CA-006, so it was
graded against the tree with that irony in view rather than on its own say-so.

- [x] **AC1** -- `agents/edm-implementer.md:12` is `maxTurns: 200`. The justification is recorded in
      three independent places, and the AC's own parenthetical figures appear verbatim in the first:
      commit `a0959a8`'s body ("edm-implementer 60 -> 200 (8/8 wave-1 agents exhausted 60; one
      stopped between building and committing, leaving two new bin/ scripts untracked where a
      worktree cleanup would have destroyed them; single agents used 148-155 tool calls)");
      `decisions.md` D30; and `plugins/edm/CLAUDE.md`'s "Turn budget parity" paragraph.
- [x] **AC2** -- `agents/edm-qc-auditor.md:11` is `maxTurns: 150`, raised on the same measured basis
      ("edm-qc-auditor 50 -> 150 (2/3 exhausted 50 on four tickets each)", `a0959a8`). CLAUDE.md's
      "Turn budget parity" section states the pairing explicitly and, per CA-032, is phrased
      per-pair so this raise cannot silently falsify a blanket claim about the other two verifiers.
- [x] **AC3** -- `.claude-plugin/plugin.json`'s `userConfig.qc_shard_threshold.default` is `6`, and
      its `description` is not a bare number: it states the calibration basis ("EDMV4 wave 1
      measured ~4 tickets (roughly 40 acceptance criteria) as one auditor's realistic budget, and a
      12-ticket shard exhausted it") **and** the ceiling it depends on ("Keep this at or below 6
      unless maxTurns is raised with it"). That dependency clause is what the AC asks for beyond the
      value itself. `CLAUDE.md`'s `userConfig` reference agrees at `6`, so the CA-023 20-vs-6
      disagreement is closed on both sides.
- [x] **AC4** -- `hooks/hooks.json`'s `SubagentStop` matcher reads `edm-implementer|edm:edm-implementer`,
      covering both the bare and the plugin-namespaced spawn name. `jq empty hooks/hooks.json`
      returns clean, so the file still parses as valid JSON -- the second half of this AC, and the
      one an eyeball on the matcher string would miss.
- [x] **AC5** -- `skills/implement/SKILL.md:48-55` satisfies all four clauses: it is placed **before**
      step 7 (the merge step) by its own heading text "After each wave drains, before step 7"; it
      gives the count command (`ls "${INIT_DIR}"/qc/qc-shard-impl-*.md 2>/dev/null | wc -l`, `:51`);
      it requires the zero case be stated explicitly ("**Say so explicitly to the user, then spawn
      `edm-qc-auditor` manually for every ticket in the wave**", `:53-54`); and it carries the
      forbidding clause verbatim ("never treat an empty `qc/` as \"nothing to merge\"", `:55`). The
      surrounding `:40-46` explains the mechanism, so the rule is understood rather than
      cargo-culted.
- [x] **AC6** -- `skills/implement/SKILL.md:336` is the prohibition ("**Implementers must NOT run
      `bin/tests/run-all.sh`.**"); `:341-342` names the single-suite alternative ("run only the
      single suite covering its change (e.g. `bash bin/tests/wave8-smoke.sh`)"); and `:336-340`
      states the contention mechanism in the terms the AC requires -- a whole-tree run that itself
      spawns every sub-suite, multiplied by 6-10 parallel implementers, measured at 38 concurrent
      suite processes at load average 10, with the consequence named (the suite each agent waited on
      got slower *because* the others were waiting on it).
- [x] **AC7** -- `skills/implement/SKILL.md:346-349` requires both halves: "**Tell every implementer,
      in its prompt, to run `git rebase <initiative-branch>` before its first commit**", and "never
      merge a worktree branch without checking
      `git merge-base --is-ancestor <initiative-branch> <wt-branch>` first". `:343-346` states the
      evidence (five of seven wave-1 worktrees had no `tickets/` directory at all).
- [x] **AC8** -- `shellcheck --severity=error` returns **zero findings, exit 0** on both
      `bin/edm-state` and `bin/edm-check-grants` (shellcheck 0.11.0). The zero is not vacuous: the
      same invocation against a deliberately broken script returns exit 1 with SC1049/SC1050/
      SC1072/SC1073, so the tool is genuinely parsing rather than skipping. The directive-syntax
      half also holds -- an anchored scan
      (`grep -rn -E '^[[:space:]]*# shellcheck disable=[A-Z0-9,]+ -- ' plugins/`) returns **0**
      tree-wide. The only two ` -- ` occurrences near a `disable=` string are
      `wave8-smoke.sh:853` (a comment quoting the bad form) and `:875` (the positive-control
      fixture inside a `printf` argument); neither is a directive on a real script line, which is
      why the anchored form is the correct scan and an unanchored one is not.
- [x] **AC9** -- `bin/tests/wave8-smoke.sh:858-870` is the assertion, anchored at `:865` to
      `^[[:space:]]*# shellcheck disable=` so it matches a real directive and never prose quoting
      one -- the self-matching class the comment at `:862-864` names. It is paired with a genuine
      positive control at `:872-880`: a known-bad line is written to a scratch file and the detector
      must fire on it, failing loudly at `:879` if it does not. That is the difference between this
      assertion and the four vacuous-assertion findings recorded elsewhere on this initiative.
- [x] **AC10** -- `run-all.sh`: 3289 passed, **0 failed**, exit 0. The AC's carve-out
      (`wave6-smoke.sh`'s `T27 AC1`, owned by `EDMV4-T30`) is not needed: `wave6-smoke.sh` returned
      796 passed / 0 failed, so that assertion is now green rather than excepted.

**P2 observation (not remediation-blocking)**: AC7's requirement lives at
`skills/implement/SKILL.md:346-349`, under "AI Execution Tips", but the implementer prompt template
the orchestrator actually copies -- Step 2, `:91-101` -- carries no rebase instruction. An
orchestrator that follows the template literally omits the very line AC7 requires be in every
implementer's prompt. Adding `Rebase onto <initiative-branch> before your first commit.` to the
template block at `:93-100` makes the requirement self-executing instead of dependent on the reader
having reached `:346`.

**P2 observation (not remediation-blocking)**: neither `agents/edm-implementer.md` nor
`agents/edm-qc-auditor.md` carries an in-file note beside its `maxTurns` value pointing at the
calibration record. AC1/AC2 do not require one -- "recorded" is satisfied by `a0959a8`, D30 and
CLAUDE.md -- but a future contributor "tidying" `maxTurns: 200` down has no signal at the point of
edit, which is exactly the failure mode CLAUDE.md's "Do not 'tidy' any of these four down" sentence
was written to prevent for the verifier side.

---

## Remediation Required

**None.** Both tickets are PASS. The three P2 observations above are recorded for the ledger, not as
blocking findings; each names its own one-line fix inline. No PARTIAL verdicts were produced by this
shard, so there is nothing here for `/edm:verify-runtime` to close and nothing to persist via
`edm-state record-partial-verdict`.

<!-- QC-SHARD-COMPLETE range=T54,T55 assigned=2 audited=2 -->
