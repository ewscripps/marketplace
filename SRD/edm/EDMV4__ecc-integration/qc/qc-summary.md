# QC Audit Summary: EDMV4 -- ECC Integration, Phase 6 Wave 1

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

<!-- QC-SUMMARY-COMPLETE wave=01 shards=4 tickets=15 -->
