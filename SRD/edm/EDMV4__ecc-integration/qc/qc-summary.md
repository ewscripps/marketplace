# QC Audit Summary: EDMV4 -- ECC Integration, Phase 6 Waves 1-3

**Date**: 2026-09-02
**Tickets audited**: 15 of 15 (`EDMV4-T01`, `T04`..`T10`, `T17`, `T21`, `T34`, `T38`, `T42`, `T48`, `T49`)
**Shards merged**: 4 (`qc-shard-pass-w01-01` .. `-04`)

Every shard passed `edm-check-verifier-sentinel QC-SHARD` before any byte of this file was
written, per `skills/implement/SKILL.md` Step 7. No shard was truncated.

**These auditors were spawned manually.** The `SubagentStop` hook that should have spawned one
per implementer fired for none of the eight, silently -- the defect recorded as `EDMV4-61` and
fixed under `EDMV4-T55`. Had it not been caught, wave 1 would have merged unaudited, and every
finding below would have shipped.

## Verdict table

| Ticket | Original verdict | Post-remediation | Notes |
|---|---|---|---|
| `EDMV4-T01` | FAIL (P2) | **remediated** | AC9 currency answer w.r.t. the D4 reconciliation |
| `EDMV4-T04` | FAIL (**P0**) | **remediated** | AC11 orphan check was never built; built, and caught a live in-wave regression on first run |
| `EDMV4-T05` | FAIL | **remediated** | AC9 follow-on was unnamed; now `EVALB`, prefix verified free |
| `EDMV4-T06` | PARTIAL | **open** | Live-host spike; no harness survives to re-verify |
| `EDMV4-T07` | PARTIAL | **open** | `MultiEdit` absent from the host toolset -- recorded UNTESTABLE, not PASS |
| `EDMV4-T08` | FAIL | **remediated** | Self-masking suite abort + three hidden AC8 failures |
| `EDMV4-T09` | FAIL | **remediated** | AC7 lost in merge; `CLAUDE.md` named neither old nor new directory |
| `EDMV4-T10` | **PASS** | -- | 12/12 |
| `EDMV4-T17` | FAIL | **remediated** | AC5 never sourced the library; AC6 missed the CA-472 class |
| `EDMV4-T21` | **PASS** | -- | 9/9 |
| `EDMV4-T34` | PARTIAL | **open** | One runtime-only AC |
| `EDMV4-T38` | **PASS** | -- | Clean |
| `EDMV4-T42` | FAIL | **remediated** | Self-matching AC1, false README claim, over-absolute AC6 contract |
| `EDMV4-T48` | FAIL | **remediated** | Two documentation ACs short of their required facts |
| `EDMV4-T49` | FAIL | **remediated** | Stale citation its own correction 8 declares wrong |

**Totals**: 4 PASS-equivalent at audit time (3 PASS + 1 clean), 3 PARTIAL, 8 FAIL.
**After remediation**: 12 closed, **3 PARTIAL remain open** for `/edm:verify-runtime`.

## Outstanding PARTIAL acceptance criteria

Closed by `/edm:verify-runtime` before archive -- each either upgrades to PASS or becomes a FAIL
and is remediated. Per `CLAUDE.md Sec."Unverifiable acceptance criteria (D15)"` there is no third
verdict.

| Ticket | Runtime-check note |
|---|---|
| `EDMV4-T06` | Re-run Spike A's two-block `PreToolUse`/`Stop` experiments against a live host and confirm D25's recorded outcome still holds on the current `claude --version` |
| `EDMV4-T07` | Re-test `MultiEdit` denial on a host where the tool is present; it was absent from this session's toolset entirely, reproduced twice including with `--allowedTools MultiEdit` forced |
| `EDMV4-T34` | Exercise the size-classifier pre-step through a real `/edm:orchestrator` Step 1c dialog and confirm the recommendation surfaces without auto-applying a mode |

## What this audit caught that the test suite did not

Four findings were invisible to a green suite, and two were invisible *because* of a defect in
the suite itself:

1. **`EDMV4-T04` AC11 did not exist**, and the regression class it guards had already recurred
   in-wave -- `EDMV4-T34` added bare citations after `EDMV4-T04` anchored the tree.
2. **`EDMV4-T08`'s own assertion aborted the suite on a healthy tree** (`set -euo pipefail` plus
   a `grep -c` returning 1 on zero matches), masking its own three AC8 failures.
3. **`EDMV4-T17` AC5 tested `mkdir` and `echo`** -- it never sourced the library it exists to
   test, and would have passed had that library not parsed.
4. **Five separate self-matching scans** across four authors, each matching the prose describing
   the pattern it hunts.

It also caught four orchestrator errors: an unmerged branch reported as merged, two misread
pipeline exit codes, and a QC report written into a worktree.

---

## Wave 2 -- 14 tickets, 4 shards

Merged from `qc-shard-pass-w02-01.md` .. `qc-shard-pass-w02-04.md`. This merge did not run when
wave 2 drained; it is being run now, with wave 3, per `skills/implement/SKILL.md` Step 4's rule that
the merge re-runs after every wave so the summary always reflects every shard written so far.

| Ticket | Title | Verdict |
|---|---|---|
| `EDMV4-T12` | Add the Phase-6 marker primitive with SessionStart reconciliation | FAIL |
| `EDMV4-T16` | Record ECC and GateGuard provenance in the house-style attribution section | FAIL |
| `EDMV4-T18` | Land the 4.2 fix -- writable harvested delta and `get-patterns` read side | FAIL |
| `EDMV4-T22` | Materialize lenses and derive round_type from the union rule | PASS |
| `EDMV4-T25` | Write lens L12 -- Silent Failures | PASS |
| `EDMV4-T27` | Write lens L14 -- Behavioral Test Coverage | PASS |
| `EDMV4-T29` | Sweep `skills/code-audit/SKILL.md`'s twelve lens-count sites | FAIL |
| `EDMV4-T32` | Grow the code-audit test fixtures from 11 to 14 lens pairs | FAIL |
| `EDMV4-T33` | Sweep the documentation and user-facing surfaces for the lens count | PASS |
| `EDMV4-T35` | Pin the classifier to the eight existing mode enum values | PARTIAL |
| `EDMV4-T36` | Implement the security-trigger tie-breaker | PARTIAL |
| `EDMV4-T37` | Enforce guard D6 so the classifier never restates the mode matrix | PARTIAL |
| `EDMV4-T43` | Build the hookify evaluator, one classify pass and N projections | FAIL |
| `EDMV4-T46` | Build `edm-stop-gate` and add it as a second `Stop` entry | FAIL |

All wave-2 FAIL findings were remediated in-wave before wave 3 launched. The three PARTIALs
(`T35`, `T36`, `T37`) are persisted via `record-partial-verdict` and remain open pending
`/edm:verify-runtime`.

---

## Wave 3 -- 10 tickets, 2 shards

Merged from `qc-shard-pass-w03-01.md` and `qc-shard-pass-w03-02.md`.

| Ticket | Title | Verdict | Remediated |
|---|---|---|---|
| `EDMV4-T13` | Route every GateGuard decision through one `emit_decision` | PASS | -- |
| `EDMV4-T19` | Correct the stale caller-count comment in `cmd_update_patterns` | PARTIAL | open |
| `EDMV4-T20` | Regression coverage over every branch of the 4.2 write and read paths | FAIL | `f9bbd35` |
| `EDMV4-T23` | Teach the CA-471 backstop to distinguish N/A from missing JSONL | FAIL | `7cd7c6a` |
| `EDMV4-T24` | Make code-audit Step 1 the sole authority for L13 applicability | FAIL | `18c00c9` |
| `EDMV4-T30` | Rewrite the smoke-suite lens-count assertions for 14 lenses | FAIL | `2f3e588` |
| `EDMV4-T31` | Re-inventory the lens-count sites, close the do-not-touch list | FAIL | `fdb5ae3` |
| `EDMV4-T41` | Feed the readiness score into the classifier and into planning.md | PASS | -- |
| `EDMV4-T44` | Make `action: block` explicit opt-in behind a two-tier exit contract | FAIL | `8ea5aeb` |
| `EDMV4-T47` | Block only on the unambiguous subset, read from the class field | PASS | -- |

### The two findings that mattered

**`EDMV4-T24` AC4 (P1) -- a real functional bug, found by execution rather than inspection.**
`detect-conditional-lenses` was cwd-sensitive: `bin/edm-state` called a bare `git ls-files`, which
enumerates only the subtree below the current directory, and probed a cwd-relative
`pyproject.toml`. In a scratch repo with a tracked root-level `tsconfig.json`, the answer was
`""` (L13 applies) from the root and `"L13"` (L13 N/A) from a subdirectory. That answer gates
`round_type=full` -> `audit-converged` -> `archive`, so a code audit run from a subdirectory would
silently declare L13 inapplicable and let an initiative archive without a lens it needed -- exactly
what Guard D2 exists to prevent. Fixed by resolving the project root once via the existing CA-448
idiom and running `git -C "$root" ls-files`. Verified independently by the orchestrator: both
invocations now agree.

**`EDMV4-T30` AC10 (P1 x2) -- the ticket reintroduced the vacuity it was written to remove.**
Deriving `WAVE7_LENS_COUNT` from `LENS_AGENTS` was correct, but it made every assertion comparing
the two a tautology: both operands were the member count of one string, so no input could fail
them. The pre-T30 `-eq 11` / `-eq 15` literals were vacuous against the *tree* yet were still real
tripwires against the *list* -- drop a name and they fired. Computing the count away removed the
only thing checking the list at all, and both sites kept comments asserting a tripwire that no
longer existed. The `T48 AC1` site is the one the ticket itself flagged as "the dangerous
instance", where a dropped lens vanishes from the D16 opus/max assertion. Both now anchor to
`bin/edm-state`'s `ALL_LENS_IDS` -- an independent definition, in another file, maintained by
different tickets -- each with a positive control.

### Confirmed clean under specific challenge

- `EDMV4-T23` AC2's proof is genuinely non-vacuous: the fixture writes a `lenses-run.txt`
  containing no lens IDs, so a manifest-iterating implementation would stay `full`; only a state
  read with the C-4 substitution downgrades.
- `EDMV4-T20`'s three write branches are each really exercised -- branch (b) forces
  `edm_data_dir()` empty via `chmod 555` over all three candidates against a `cp -R` scratch tree;
  branch (c) additionally locks the copied docs dir and asserts SHA-256 equality.
- `EDMV4-T47`'s "no production change was needed" claim holds: `git log --all` on
  `bin/edm-stop-gate` returns exactly one commit, T46's.
- `EDMV4-T44`'s `2>&1` widening of two pre-existing `T43` assertions hides nothing; the dropped
  stream distinction is covered by a separate `check` on stderr plus `check_absent` on stdout.
- `EDMV4-T30`'s five `set -e` guard additions are genuine `|| true` wrappers, with no assertion
  deleted or neutered.

### Suite state at wave-3 close

| Suite | Result |
|---|---|
| `wave6-smoke.sh` | 795 passed, 0 failed |
| `wave8-smoke.sh` | 515 passed, 0 failed |
| `wave7-smoke.sh` | 1387 passed, 65 failed -- see below |

`wave7`'s 65 failures are attributed, not unexplained: the L13/L14 lens agents pending
`EDMV4-T26`; roughly 35 assertions gone stale against `EDMV4-T18`'s relocation of harvested
patterns to a data-dir delta, which **no ticket currently owns**; and two pending cross-cutting
version bumps. `wave7` also ran to completion for the first time since `T18` landed -- a stale
6-argument call left `$7` unbound and `set -u` killed the suite mid-run, hiding roughly 500 passing
assertions behind a suite that was already red by design (fixed in `9a4a7f0`).

<!-- QC-SUMMARY-COMPLETE wave=03 shards=10 tickets=39 -->
