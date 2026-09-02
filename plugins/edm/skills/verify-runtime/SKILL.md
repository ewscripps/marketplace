---
name: verify-runtime
description: EDM Phase 6 closure -- drives every PARTIAL verdict in partial_verdict_map to a closing PASS or FAIL via runtime verification, writing post-deploy/verification.md. Mandatory before archive. Invoked explicitly via /edm:verify-runtime <PREFIX>.
user-invocable: true
model: sonnet
effort: high
argument-hint: <PREFIX>
allowed-tools: Read, Write, Bash(edm-state *), Bash(mkdir *), Glob, Grep, AskUserQuestion, TodoWrite
---

# EDM Phase 6 Closure: Runtime Verification

**Arguments**: $ARGUMENTS

- **Input**: `partial_verdict_map` entries recorded during Phase 6 QC (`edm-state record-partial-verdict`)
- **Output**: every entry closed to `PASS` or `FAIL` in state, plus `post-deploy/verification.md`

## Step 0 -- Gate and Branch Preflight

Before Step 1, run the preflight per `skills/plan/SKILL.md Sec."Step 0 -- Gate and Branch Preflight"`,
using `<gated-command>` = `verify-runtime` and `<phase-num>` = `6`.

This skill is the mandatory Phase 6 closure step. D13 forbids leaving a PARTIAL open at archive
time, and D15 forbids inventing a third verdict when the runtime check is hard to arrange --
`/edm:verify-runtime` records exactly two closing verdicts, ever: **PASS** or **FAIL**.

## Two-Verdict Policy (D15)

There is no third value of any kind anywhere in `partial_verdict_map`, in
`post-deploy/verification.md`, or in this skill's prompts -- only the two named above. See
`CLAUDE.md Sec."Unverifiable acceptance criteria (D15)"` for the full policy (including the
specific abolished tokens this methodology never uses). Read `docs/canonical-sections.md`
(resolved relative to the EDM plugin's own root -- `plugins/edm/` in this repository, or the
installed plugin's cache root, never the caller's cwd) for the actual section text; a bare
`CLAUDE.md Sec."..."` reference does not resolve because CLAUDE.md at the plugin root is not
loaded as runtime context. When the runtime
environment an AC assumes genuinely does not exist, that is a specification defect, not a
verification outcome. The correct response is to rework the AC or move it out of scope --
**never** to record a third verdict here. Both routes are a scope change to an approved ticket, so
both go through gate change control, not this skill: **the implementer cannot descope an AC by
declaring it unverifiable here**. If you reach that situation while running this skill, stop,
name the AC, and tell the user it needs to go back through the ticket/gate change-control path
described in `CLAUDE.md Sec."Unverifiable acceptance criteria (D15)"` before verification can
close it -- do not invent a verdict to unblock yourself. Read `docs/canonical-sections.md`
(resolved relative to the EDM plugin's own root -- `plugins/edm/` in this repository, or the
installed plugin's cache root, never the caller's cwd) for the actual section text; a bare
`CLAUDE.md Sec."..."` reference does not resolve because CLAUDE.md at the plugin root is not
loaded as runtime context.

## Operational Orchestration

1. Parse `{PREFIX}` from `$ARGUMENTS`. If missing, ask the user.
2. Resolve the initiative directory: `INIT_DIR=$(edm-state resolve-dir <PREFIX>)`
3. Read the map: `edm-state get <PREFIX> | jq -r '.partial_verdict_map // {}'`
   - **Empty map (AC12)**: if there are no entries, or every entry already carries a
     `closing_verdict`, print *"Nothing to verify for {PREFIX} -- no open PARTIAL verdicts."* and
     stop. Write **no** file -- absence is authoritative; do not create
     `post-deploy/verification.md` or its directory.
4. For each entry whose `verdict == "PARTIAL"` and which has **no** `closing_verdict` yet (an
   entry already closed `PASS` is done; an entry closed `FAIL` is not re-asked here -- it is
   remediated through `/edm:implement` and re-verified only after that remediation lands):
   a. Present the ticket, the AC identifier, and the recorded `runtime-check:` note from the
      entry to the user.
   b. Perform (or have the user perform, when it requires access this session does not have) the
      described runtime check -- call the live endpoint, run the load test, execute the migration
      against a real database, drive the browser flow, etc. -- and record what was actually done
      and observed.
   c. If, and only if, performing the check reveals the described runtime environment does not
      exist and cannot reasonably be constructed for this verification pass, apply the **Two-Verdict
      Policy (D15)** above instead of closing this entry -- do not proceed to step (d).
   d. Ask for the verdict via `AskUserQuestion`:
      - Header: `"Verify: {ticket}"` (<=12 chars where the ticket ID allows; truncate the
        header, never the ticket ID, if it would run long)
      - Question body: state the runtime check performed and the observed result.
      - Options: **PASS** (the check confirms the AC), **FAIL** (the check disproves the AC).
        There is no third option.
   e. On **PASS**:
      ```bash
      edm-state record-partial-verdict <PREFIX> <ticket> close PASS "post-deploy/verification.md#{ticket}-ac{N}"
      ```
   f. On **FAIL**: state plainly that the AC is now a FAIL finding and that the next step is the
      `/edm:implement` remediation loop -- **this skill offers no way to accept the failure**, no
      "accept and continue" option, no override:
      ```bash
      edm-state record-partial-verdict <PREFIX> <ticket> close FAIL "post-deploy/verification.md#{ticket}-ac{N}"
      ```
   g. Run `mkdir -p "${INIT_DIR}/post-deploy"` first (CA-560: the directory does not exist until
      the first closure writes into it), then append (never overwrite -- see Idempotency below) a
      section to `${INIT_DIR}/post-deploy/verification.md` documenting this closure:
      ```markdown
      ## {ticket} AC#{N} -- {short criterion}

      - **Ticket**: {ticket}
      - **AC**: AC#{N} -- {criterion text}
      - **Runtime check performed**: {what was actually run/observed}
      - **Observed result**: {result}
      - **Verdict**: PASS | FAIL
      - **Closed**: {timestamp}
      ```
5. After every entry is either already-closed or newly closed, print a one-line summary: counts of
   newly-closed PASS, newly-closed FAIL, and any still-FAIL entries awaiting remediation.
   - If any entry is FAIL (new or still-open from a prior run), direct the user to
     `/edm:implement <PREFIX>` to remediate, then re-run `/edm:verify-runtime <PREFIX>` afterward.
   - If every entry is PASS, tell the user Phase 6 closure is clear and the next command is
     `edm-state phase-complete <PREFIX> 6` (see "Direct-invocation sequence" below).

## Idempotency

Re-running this skill after a FAIL has been remediated must **append** a new closure section to
`post-deploy/verification.md`, never rewrite the file -- the audit trail of every closure attempt,
including the original FAIL, survives. `record-partial-verdict close` itself preserves this
history in state (a FAIL closure may be re-closed after remediation; a PASS closure may not be
re-closed at all).

## Direct-invocation sequence

When this skill is run standalone (not via `/edm:orchestrator`), the mandatory sequence is:

```bash
/edm:verify-runtime <PREFIX>
edm-state phase-complete <PREFIX> 6
```

`phase-complete 6` refuses when an open PARTIAL remains, so the ordering is enforced rather than
merely requested even on this direct path. See `README.md`'s command table and
`skills/implement/SKILL.md` Step 8 for the same two-command sequence.

## post-deploy/verification.md Format

```markdown
# Post-Deploy Verification: {PREFIX}

Generated by `/edm:verify-runtime`. Closes every PARTIAL verdict recorded during Phase 6 QC.
This file is appended to, never rewritten -- each verify-runtime run adds new closure sections.

## {ticket} AC#{N} -- {short criterion}

- **Ticket**: {ticket}
- **AC**: AC#{N} -- {criterion text}
- **Runtime check performed**: {what was actually run/observed}
- **Observed result**: {result}
- **Verdict**: PASS | FAIL
- **Closed**: {timestamp}
```

## AI Execution Notes

- This skill never invents a PASS. If a runtime check cannot actually be performed this session
  (no access to the target environment), say so plainly and leave the entry open rather than
  guessing.
- A `FAIL` closure is not a dead end for the initiative -- it is a normal finding, remediated like
  any other FAIL, then re-verified.
- An AC that cannot be verified because its runtime environment does not exist is not this
  skill's problem to solve by inventing a verdict -- it is a specification defect, routed through
  gate change control per `CLAUDE.md Sec."Unverifiable acceptance criteria (D15)"`. Read
  `docs/canonical-sections.md` (resolved relative to the EDM plugin's own root -- `plugins/edm/`
  in this repository, or the installed plugin's cache root, never the caller's cwd) for the
  actual section text; a bare `CLAUDE.md Sec."..."` reference does not resolve because CLAUDE.md
  at the plugin root is not loaded as runtime context.

This skill presents no HITL gate of its own -- its per-entry PASS/FAIL prompts (Two-Verdict Policy
above) are a distinct, two-option pattern, not the three-option Approve/Revise/No-Go gate defined in
`skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"`. Both share the same STOP-and-WAIT discipline:
`edm-state record-partial-verdict ... close` runs only after the explicit PASS/FAIL selection, never
before it, and free text is re-presented rather than interpreted.
