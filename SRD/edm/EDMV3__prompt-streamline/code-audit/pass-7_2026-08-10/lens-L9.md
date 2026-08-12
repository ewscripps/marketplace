# Lens L9 -- Spec & Ticket Compliance (Round 7)

**Tooling note (CA-130's class, 7+ consecutive rounds):** Write absent from this
lens's delivered runtime tool set. This report was transcribed by the
orchestrator from the lens agent's final message, after a stalled first attempt.

**Coverage caveat, stated up front:** this run was truncated. No requirement-by-
requirement sweep of `srd.md` and no AC-by-AC sweep of all epic files. What
follows is what was verified with direct evidence, plus an explicit list of what
remains uncovered. Treat the finding count as a floor, not a total.

## Findings (L9: Spec & Ticket Compliance)

### Missing Implementations (P1)

None verified. Sweep incomplete -- see "Not Covered" below.

### Partial Implementations (P1)

| Ticket | AC | What the Spec Requires | What Code Does | File:Line |
|---|---|---|---|---|
| (no ticket -- architecture.md spec text, remediation-ledger work) | Concurrency-control row of the enforcement-surface table | `architecture.md:609` states: concurrent `edm-state` writers are guarded by `with_state_lock` (`:359-396`) ... "flock with 10s timeout, or the mkdir spin-lock fallback with 50 tries. **Unchanged**" | Two independent defects. (a) The line-range citation is stale: `with_state_lock()` is actually defined at `plugins/edm/bin/edm-state:1119`, and `write_atomic()` at `:637`. Nothing lives at `:359-396`. (b) The word "Unchanged" is now false -- round 6 commit `4022300` is titled "close eight `with_state_lock`/`write_atomic` concurrency gaps (Wave 4a)", i.e. that exact surface was changed in the same round the spec still claims it was not. | Spec: `SRD/edm/EDMV3__prompt-streamline/architecture.md:609` -- Code: `plugins/edm/bin/edm-state:1119` and `:637` |

This is a **direct recurrence of the initiative's documented 4+ round root
cause** ("a code remediation lands and the AC/SRD text naming the old code shape
never gets swept in the same commit"), and it recurred *inside round 6 itself*
-- the round whose stated purpose included fixing four citation defects
(G40-G43) and adding the "verbatim shipped case labels, never a paraphrase"
convention to `tickets/README.md`. Round 6 fixed citation drift in the **ticket
pack** and left the identical class un-swept in the **architecture spec**. The
convention added to `tickets/README.md` does not reach `architecture.md`, so it
structurally could not have caught this.

Recommendation: fix both halves of `architecture.md:609` in the same commit
(correct line anchor, and replace "Unchanged" with a pointer to the Wave 4a
remediation), and extend the round-6 citation convention to cover
`architecture.md` / `srd.md` line-anchor citations, not just ticket ACs.

### Scope Creep (P2)

| File / Feature | Not Specified In | Recommendation |
|---|---|---|
| Wave 3 shared-lint-library extraction (commit `2d83898`) and Wave 4a concurrency hardening (commit `4022300`) | Grep for `with_state_lock\|write_atomic` across `SRD/edm/EDMV3__prompt-streamline/tickets/` returns **zero matches** -- no epic AC anywhere in the ticket pack covers either wave. Both appear only in `decisions.md`, `architecture.md`, `HANDOFF.md`, `findings-ledger.md`/`.jsonl`, and per-pass audit artifacts. | **Not** classic scope creep -- code-audit remediation is authorized by `findings-ledger.md`, which is the correct work-item source for remediation waves. See Noted. The actionable residue is structural: because remediation waves are ledger-tracked and never AC-tracked, **no acceptance criterion anywhere obliges the doc sweep**, which is precisely why this class has now recurred for 5 rounds. Recommend the findings-ledger entry template carry a mandatory "spec/AC text swept in same commit: yes/no/n-a" field so the obligation lives on the same artifact that authorizes the code change. |

## Noted / Not Actionable

- **Wave 3 / Wave 4a absent from the ticket pack** -- passes the False Alarm
  Filter as *necessary implementation detail authorized elsewhere*:
  `findings-ledger.md` is this initiative's documented tracking artifact for
  audit remediation, so absence of an epic AC is by design, not an unticketed
  feature. Filed above only for its structural consequence, not as a creep
  violation.
- **`cc733cc` ("fix stale T67 AC8")** -- not a finding; this is round 6
  correctly *fixing* an instance of the recurring class. Cited here as
  corroboration that the class was live during round 6, which raises the prior
  on the `architecture.md:609` finding above being real rather than cosmetic.
- **`write_atomic()` at `edm-state:637`** -- no stale spec citation found
  pointing at it; `architecture.md:609` names only `with_state_lock` with a
  line range. No separate finding.

## Not Covered (must be re-run before L9 is considered clean for pass 7)

Roughly the round-6-regression slice only was covered. Uncovered:

1. Per-requirement sweep of `SRD/edm/EDMV3__prompt-streamline/srd.md` -- no
   requirement IDs were enumerated or matched to code.
2. AC-by-AC sweep of all ten epics: `01-mechanical-fixes.md`,
   `02-enforcement-kernel.md`, `04-structured-findings.md`,
   `05-orchestrator-dispatcher.md`, `06-mermaid-rule.md`,
   `07-prompt-streamline.md`, `08-economics-honesty.md`,
   `09-pattern-library-curation.md`, `10-delete-list.md` (plus the epic not
   surfaced in the truncated glob).
3. Whether the other ~19 of round 6's 23 commits (beyond the four in recent
   log) left stale AC/spec text -- only the `with_state_lock`/`write_atomic`/
   lint-library axis was checked.
4. Reverse direction: files under `plugins/edm/bin/` and `plugins/edm/skills/`
   with no corresponding ticket -- no reverse mapping was performed, so the
   Scope Creep table is not exhaustive.
5. Whether the round-6 `tickets/README.md` "verbatim shipped case labels"
   convention is actually satisfied by current epic text (the convention was
   added; compliance was not verified).

Two systemic asks for the parent: (a) restore Write for L9 or accept text-only
reports as the persistent record -- five rounds of ledger continuity depend on
these files existing; (b) the fact that L9 found a fresh instance of the
initiative's named root cause *in round 6's own output* argues the remediation
gate should require a same-commit doc sweep before a wave is marked done, rather
than relying on the next audit round to catch it.
</content>
