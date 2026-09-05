# QC Audit Report: EDMV4 -- ECC Integration (merged)

**Date**: 2026-09-04
**Shards merged**: 14 (`qc-shard-pass-w01-01` .. `w05-01`)
**Tickets covered**: 55 of 55

## What this file is, and what it is not

This is the merged, **point-in-time** record of every QC shard this initiative produced. Each
verdict below is the verdict that shard recorded **at the moment it audited**, against the tree as
it stood then. It is NOT a statement of current state.

That distinction is load-bearing here, because most of the FAIL verdicts below were remediated
inside their own wave by the Step 5 remediation loop that the FAIL itself triggered -- that is the
mechanism working, not a backlog. Reading the 32 FAIL rows as "32 tickets are broken today" would
misread this file badly. For current state, read the code-audit findings ledger
(`../code-audit/findings-ledger.jsonl`), which is maintained across rounds and reflects what is
open now.

## Verdict distribution (at audit time)

| Verdict | Count |
|---|---|
| PASS | 15 |
| FAIL | 32 |
| PARTIAL | 8 |

## Sentinel provenance -- read this before trusting a shard

The VERIF-T03 merge gate ran over all 14 shards before any byte of this file was written, and all
14 passed. **Passing did not mean the same thing for all 14**, and the difference is worth stating
plainly rather than leaving a uniform-looking green.

`edm-check-verifier-sentinel`'s trust ordering is: explicit CLI count > parsed `T{a}-T{b}` span >
the shard's own `assigned=` field. `assigned=` is deliberately last, because a shard reporting its
own assignment is self-certification: a shard given five tickets can write `assigned=2 audited=2`
and pass. Only a count sourced from OUTSIDE the shard is a real check.

| Shards | Range form | What the gate actually verified |
|---|---|---|
| `w03-01`, `w03-02` | `T13-T24`, `T30-T47` (span) | Real check. Both were assigned 5 discontiguous tickets but labelled with a span, so the parser derived 12 and 18 and **refused**. That refusal is a false positive, resolved per decision D41 by passing the true count (5) explicitly at merge time -- not by relabelling the shard, and not by changing the checker |
| `w04-01`, `w05-01` | comma | Real check. Expected counts (6, 5) taken from `orchestrator-notes.md`, which records those two assignments independently of the shards |
| `w01-05`, `w02-05` | comma | Real check. Expected counts (2, 3) are the assignment this session handed the auditor |
| `w01-01`..`w01-04`, `w02-01`..`w02-04` | `EDMV4-T12..EDMV4-T32` (double-dot) | **Self-certified only.** The span parser fails on the double-dot-with-prefix form, so the gate fell back to each shard's own `assigned=`. No orchestrator-side count survives for waves 1 and 2, so these eight cannot be independently verified against their real assignments |

**Twelve of fourteen shards self-certify.** The only two that ever received a genuine external
check were the two that refused -- and their refusal was a false positive from a mislabelled range.
D41 predicted exactly this ("a malformed range is more dangerous than a wrong one") and it holds at
full scale: a uniformly green sentinel sweep across this initiative's QC verified almost nothing.
The contract gap D41 records -- that the sentinel grammar has no discontiguous-set form -- remains
open, and this table exists so the green above is not mistaken for coverage it does not have.

Coverage of the ticket pack itself was therefore measured independently of the sentinels, by
checking every one of the 55 pack tickets for a verdict row in some shard. All 55 have one.

## Merged verdict table

| Ticket | Verdict (at audit time) | Shard |
|---|---|---|
| `EDMV4-T01` | FAIL | `w01-01` |
| `EDMV4-T04` | FAIL | `w01-01` |
| `EDMV4-T05` | FAIL | `w01-01` |
| `EDMV4-T06` | PARTIAL | `w01-01` |
| `EDMV4-T07` | PARTIAL | `w01-02` |
| `EDMV4-T08` | FAIL | `w01-02` |
| `EDMV4-T09` | FAIL | `w01-02` |
| `EDMV4-T10` | PASS | `w01-02` |
| `EDMV4-T11` | FAIL | `w02-05` |
| `EDMV4-T12` | FAIL | `w02-01` |
| `EDMV4-T13` | PASS | `w03-01` |
| `EDMV4-T14` | FAIL | `w04-01` |
| `EDMV4-T15` | FAIL | `w04-01` |
| `EDMV4-T16` | FAIL | `w02-04` |
| `EDMV4-T17` | FAIL | `w01-04` |
| `EDMV4-T18` | FAIL | `w02-01` |
| `EDMV4-T19` | PARTIAL | `w03-01` |
| `EDMV4-T20` | FAIL | `w03-01` |
| `EDMV4-T21` | PASS | `w01-03` |
| `EDMV4-T22` | PASS | `w02-01` |
| `EDMV4-T23` | FAIL | `w03-01` |
| `EDMV4-T24` | FAIL | `w03-01` |
| `EDMV4-T25` | PASS | `w02-02` |
| `EDMV4-T26` | PASS | `w04-01` |
| `EDMV4-T27` | PASS | `w02-02` |
| `EDMV4-T28` | PASS | `w05-01` |
| `EDMV4-T29` | FAIL | `w02-02` |
| `EDMV4-T30` | FAIL | `w03-02` |
| `EDMV4-T31` | FAIL | `w03-02` |
| `EDMV4-T32` | FAIL | `w02-01` |
| `EDMV4-T33` | PASS | `w02-02` |
| `EDMV4-T34` | PARTIAL | `w01-03` |
| `EDMV4-T35` | PARTIAL | `w02-03` |
| `EDMV4-T36` | PARTIAL | `w02-03` |
| `EDMV4-T37` | PARTIAL | `w02-03` |
| `EDMV4-T38` | PASS | `w01-04` |
| `EDMV4-T39` | FAIL | `w02-05` |
| `EDMV4-T40` | FAIL | `w02-05` |
| `EDMV4-T41` | PASS | `w03-02` |
| `EDMV4-T42` | FAIL | `w01-04` |
| `EDMV4-T43` | FAIL | `w02-04` |
| `EDMV4-T44` | FAIL | `w03-02` |
| `EDMV4-T45` | PARTIAL | `w04-01` |
| `EDMV4-T46` | FAIL | `w02-04` |
| `EDMV4-T47` | PASS | `w03-02` |
| `EDMV4-T48` | FAIL | `w01-03` |
| `EDMV4-T49` | FAIL | `w01-03` |
| `EDMV4-T50` | FAIL | `w05-01` |
| `EDMV4-T51` | FAIL | `w05-01` |
| `EDMV4-T52` | FAIL | `w05-01` |
| `EDMV4-T53` | FAIL | `w05-01` |
| `EDMV4-T54` | PASS | `w01-05` |
| `EDMV4-T55` | PASS | `w01-05` |
| `EDMV4-T56` | PASS | `w04-01` |
| `EDMV4-T57` | FAIL | `w04-01` |

## PARTIAL closure status

Eight tickets took a PARTIAL verdict. All eight are recorded in `.edm-state.json`'s
`partial_verdict_map`; their current closure state is authoritative there, not here.

| Ticket | Closing verdict | Basis |
|---|---|---|
| `EDMV4-T06` | PASS | `NOT RUNTIME-VERIFIED (D44)` -- carried to follow-on `EDMRT` |
| `EDMV4-T07` | PASS | `NOT RUNTIME-VERIFIED (D44)` -- carried to follow-on `EDMRT` |
| `EDMV4-T19` | PASS | `run-all.sh` green after `EDMV4-T26` landed |
| `EDMV4-T20` | PASS | `run-all.sh` run twice consecutively |
| `EDMV4-T34` | PASS | `NOT RUNTIME-VERIFIED (D44)` -- carried to follow-on `EDMRT` |
| `EDMV4-T35` | PASS | `NOT RUNTIME-VERIFIED (D44)` -- carried to follow-on `EDMRT` |
| `EDMV4-T36` | PASS | `NOT RUNTIME-VERIFIED (D44)` -- carried to follow-on `EDMRT` |
| `EDMV4-T37` | PASS | `NOT RUNTIME-VERIFIED (D44)` -- carried to follow-on `EDMRT` |
| `EDMV4-T45` | **OPEN** | Not closed. `edm-state archive` hard-blocks while this is open |

`EDMV4-T45` is the one outstanding item: it holds a PARTIAL with no `closing_verdict`, so archive
is blocked until `/edm:verify-runtime` closes it PASS or FAIL. It is not covered by D44's six.

## Open FAIL findings raised by the wave-1/wave-2 residue shards (CA-006)

`w01-05` and `w02-05` were commissioned this session to close CA-006 -- five tickets that no
wave's shard had ever given a verdict. Three came back FAIL, and unlike the historic FAILs above
these have NOT been remediated:

- **[P1] `EDMV4-T11` AC3** -- `bin/tests/wave8-smoke.sh:3325-3330`. AC3 mandates asserting the
  `PreToolUse` block count **is 2**; the code asserts `-ge 2` against a live value of 3. A
  `>= 2` bound on an array that only grows cannot fail, and nothing asserts the
  `Edit|Write|MultiEdit` block count is exactly 1, so a duplicated gateguard block passes silently.
- **[P1] `EDMV4-T39` AC7** -- `bin/edm-repo-readiness`. The rubric version reaches the JSON, but
  the second half of the AC -- that the script documents a future comparator must REFUSE rather
  than silently pass on a version mismatch -- has no implementation. The smoke assertion covers
  only the half that exists, so the gap is invisible to the suite.
- **[P2] `EDMV4-T40` AC7** -- `bin/edm-repo-readiness:264-267,269-270`. `GIT_REPO_PRESENT` and
  `SRD_DIR_PRESENT` self-detect without the justification comment AC7 requires, and
  `SRD_DIR_PRESENT` re-derives `SRD_ROOT` from a chain `edm-state` already owns (the CA-409 class).

All three are being remediated by the P1 batches in flight against those two files.

<!-- QC-SUMMARY-COMPLETE wave=05 shards=14 tickets=55 -->
