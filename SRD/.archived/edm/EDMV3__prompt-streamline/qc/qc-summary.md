# QC Summary: EDMV3 Wave A (merged shards 1+2)

**Date**: 2026-07-27
**Tickets**: EDMV3-T01..T17, T19-T23, T61-T64 (26)
**Shard reports**: qc-shard-01.md (T01-T14), qc-shard-02.md (T15-T64)
**Remediation**: all 12 findings (6 P1, 5 P2, 1 AC-contradiction arbitration D19) fixed in commits 23e1554, ebb1b83, 421e7a0 -- zero skipped per D13.

## Post-remediation verdict table

| Ticket | QC verdict | Post-remediation |
|---|---|---|
| T01 | FAIL (AC9) | CLOSED via D19 amendment (run-all.sh auto-discovery is the assertion) |
| T02 | PARTIAL | OPEN -- runtime closures (live lens run post cache-refresh; validate; MR review) |
| T03 | PARTIAL | OPEN -- runtime closures (pre-T02 count record; validate) |
| T04 | FAIL (AC8) | FIXED (README + CLAUDE.md ASCII-normalized, zero non-ASCII) |
| T05 | PARTIAL (AC5 MR half) | OPEN -- MR-description review |
| T06 | PARTIAL (AC3) | OPEN -- human interactive permission-dialog observation |
| T07 | FAIL (AC4) | FIXED (set-mode seeds skipped_phases, deduped; wave4a updated) |
| T08 | PASS | -- |
| T09 | PASS | -- |
| T10 | PASS | -- |
| T11 | FAIL (AC1 structural) | FIXED (six checks routed through present_or_absent nonempty) |
| T12 | PASS | -- |
| T13 | FAIL (AC7) | FIXED (schema_version legacy signal in phase-start + gate-check) |
| T14 | FAIL (AC1/AC2) | FIXED (same root cause; fixtures re-pointed at real EDMV2 shape) |
| T15 | PARTIAL (AC9) | OPEN -- MR-description review |
| T16 | PASS | -- |
| T17 | FAIL (AC8) | FIXED (edm-state:2917 em dash; phase-6 ASCII fixture added) |
| T19 | FAIL (AC8) | FIXED (with_scratch_dir sibling / call sites converted per remediation) |
| T20 | FAIL (AC10) | FIXED (three --path cases added) |
| T21 | FAIL (AC3/AC5/AC7) | FIXED (tripwire case; token contradiction resolved per D19; bash:3.2 documented exception) -- AC10/AC11 remain runtime (live GitLab) |
| T22 | FAIL (AC3) | FIXED (du -sk size gate) -- AC4/AC5 remain runtime |
| T23 | PARTIAL | OPEN -- three live baseline runs (ANTHROPIC_API_KEY) |
| T61 | PARTIAL | OPEN -- shellcheck/bash32 job logs, jq review record, macOS exception re-confirm |
| T62 | PASS | -- |
| T63 | PARTIAL | OPEN -- commit dry-run, template list, git-log greps (greps verifiable now: wave-A commits carry no attribution trailers by construction; one pre-existing kickoff-commit emoji recorded in T64's report) |
| T64 | PARTIAL | OPEN -- AC9 checklist (in T64 report text), AC11 blocked on T23 baseline |

## Wave-A exit status

- Suite: 709/709 across 7 suites; edm-check-grants exit 0; edm-lint-artifacts --all CLEAN; YAML valid.
- Plugin at v2.1.0; EDMV3 state migrated to schema_version 1 (kernel fully enforcing its own initiative).
- **Remaining before wave-A can be declared closed** (all environment/human-dependent, none code):
  1. Three live eval baseline runs -> commit baseline/scores.json + variance table (T23 AC8/9/13, T64 AC11). Owner: user with ANTHROPIC_API_KEY.
  2. First live GitLab pipeline: refresh image digests, confirm merge-blocks-on-red + green default branch (T21 AC7/10/11).
  3. Plugin cache refresh (v2.1.0 install), then the single-lens live spot run (T02 AC8).
  4. Human interactive permission-dialog observation of the three bypass shapes (T06 AC3).
  5. MR-description review artifacts (T02 AC12, T05 AC5, T15 AC9) at MR time.
