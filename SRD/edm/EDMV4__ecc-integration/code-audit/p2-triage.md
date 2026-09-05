# P2 Triage -- EDMV4 code audit pass 1

**Date**: 2026-09-05
**Input**: the 73 P2 findings open in `findings-ledger.jsonl` after the P1 batches merged
**Decision**: fix groups 1, 3 and 4 (34 findings); carry groups 2 and 5 (39) as documented debt,
to be accepted explicitly at the convergence gate rather than silently.

This split was proposed from finding TITLES, then spot-verified against REMEDIATION.md for group 1
(the group the recommendation argued hardest for). Groups 2 and 5 were NOT re-read finding by
finding, so some are certainly misfiled. A misfiled finding is carried as debt rather than fixed --
it does not disappear, and it stays open in the ledger either way.

## Fix now

### Group 1 -- concurrency and filesystem safety (12)

CA-073, CA-077, CA-081, CA-082, CA-083, CA-084, CA-085, CA-086, CA-087, CA-088, CA-092, CA-101

Not accepted as debt, and the reason is operational rather than theoretical: `edm-gateguard` fires
on every Edit and Write, and Phase 6 runs 6-10 implementers in parallel. Concurrent hook invocation
is the normal operating mode of this plugin, not a corner case -- CA-083's own prescription says so
in as many words. These are also small: CA-088 is deleting the word `local`, and CA-082/CA-101 are
one shared `mktemp` template applied at three sites. They are P2 on impact-under-contention, not on
effort.

### Group 3 -- stale claims and prose (12)

CA-060, CA-061, CA-062, CA-064, CA-065, CA-067, CA-070, CA-071, CA-110, CA-117, CA-123, CA-133

Cheap, and one of them is actively misleading: CA-123 -- the canonical Hookify section still states
that no evaluator reads the rules and no hook fires because of them, which stopped being true when
EDMV4-T45 shipped.

### Group 4 -- small hardening one-liners (10)

CA-076, CA-078, CA-093, CA-107, CA-108, CA-111, CA-115, CA-120, CA-124, CA-125

## Carry as debt

### Group 2 -- test-coverage gaps (21)

CA-066, CA-068, CA-069, CA-080, CA-094, CA-095, CA-096, CA-097, CA-098, CA-099, CA-102, CA-104,
CA-118, CA-119, CA-126, CA-127, CA-128, CA-129, CA-130, CA-131, CA-132

Carried with a stated reservation: this is the kind of debt that hides the NEXT defect rather than
merely deferring this one. Fourteen findings of the "assertion that cannot fail" class have already
been fixed on this initiative, every one of them a check that reported success while verifying
nothing. Twenty-one more coverage gaps is not a neutral carry. CA-096 in particular hard-codes this
initiative's live SRD artifact paths, so the suite fails in any other repository -- that one bites
the next adopter, not us. This group wants a named follow-on initiative, not silent acceptance.

### Group 5 -- structural, needs a design decision (18)

CA-063, CA-072, CA-074, CA-075, CA-089, CA-090, CA-091, CA-100, CA-103, CA-105, CA-106, CA-109,
CA-112, CA-113, CA-114, CA-116, CA-121, CA-122

Each needs a decision before a fix is even well-defined: three diverged project-root resolvers, an
ASCII sanitizer literal hand-copied five times across three files, host-global harvested-delta
growth with no bound, the CA-471 completeness-gate semantics, and two untrusted-input questions
(a rule author's message folded verbatim into `permissionDecisionReason`, and an unbounded
Oniguruma pattern whose 64 KiB input cap is not a time bound).

## What this decision is NOT

This records which findings get fixed in this round. It is not the convergence gate and carries no
approval weight. Accepting the 39 carried findings as debt requires an explicit selection at the
gate, which runs `edm-state approve-gate EDMV4 code-audit --accept-p2-debt` -- and that command
hard-refuses while any P0 or P1 is open, so the eight remaining P1s must close first regardless.
