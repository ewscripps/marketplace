# REMEDIATION Plan (EDMV4-T20 fixture)

Hand-authored fixture matching `agents/edm-audit-synthesizer.md` Sec."Remediation Plan Format":
a finding heading whose title begins with a stable `CA-NNN` ID. Drives
`plugins/edm/bin/tests/wave8-smoke.sh`'s EDMV4-T20 section (branch (a) end-to-end and delta-side
de-duplication) only.

## Context

Scratch fixture; no real audit round.

## Detailed Findings

### CA-9001 (P2): EDMV4-T20 branch (a) positive-control finding for the writable-data-directory path

source: EDMV4T20
audit-type: code
date: 2026-09-02

> Fixture finding used only to drive the EDMV4-T20 writable-data-directory-path and delta-side
> de-duplication regression tests. Not a real audit finding.

## Rollout Order

None -- fixture only.

## Verification Plan

None -- fixture only.
