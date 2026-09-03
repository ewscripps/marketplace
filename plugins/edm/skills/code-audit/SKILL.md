---
name: code-audit
description: EDM Code Audit (post-Phase 6) -- 14 parallel orthogonal audit agents (logic, dead code, edge cases, tests, hygiene, docs, consistency, security, spec, DRY, wiring, silent failures, type design, behavioral tests) plus a synthesizer that produces a severity-ranked remediation plan. Invoked explicitly via /edm:code-audit. Supports --lenses subset for targeted re-audits.
user-invocable: true
model: opus
effort: max
argument-hint: <PREFIX> [files-or-branch-scope] [--lenses L1,L3]
allowed-tools: Read, Write, Edit, Bash(edm-state *), Bash(mkdir *), Bash(date *), Glob, Grep, Task, TodoWrite, AskUserQuestion
---

# EDM Code Audit: Exhaustive Multi-Round QA

**Arguments**: $ARGUMENTS

- **Input**: An implementation (files, commits, branch) plus the initiative's ticket pack and SRD
- **Output**:
  - Per-round report: `<initiative-dir>/code-audit/pass-{N}_{YYYY-MM-DD}/REMEDIATION.md`
  - Persistent findings ledger: `<initiative-dir>/code-audit/findings-ledger.jsonl` (authoritative,
    spans all rounds); `findings-ledger.md` is deterministically rendered from it by
    `edm-state render-ledger` (CA-166)

**Plugin asset note**: every `docs/...` reference in this skill is relative to the EDM plugin root (`plugins/edm/` in this repository, or the installed plugin root in cache). Resolve that root before reading or grepping those files; never assume the current working directory is the plugin root.

A single auditor misses things because it gravitates toward familiar patterns. Fourteen auditors with **orthogonal
mandates** -- plus a synthesizer -- catch what a single pass misses. Multiple rounds use a persistent ledger to
track findings across passes and determine convergence.

## Step 0 -- Gate and Branch Preflight

Before Step 1, run the preflight per `skills/plan/SKILL.md Sec."Step 0 -- Gate and Branch Preflight"`,
using `<gated-command>` = `code-audit` and `<phase-num>` = `6`.

## Operational Orchestration

1. Parse `{PREFIX}`, optional scope, and optional `--lenses` subset from `$ARGUMENTS`.
   - `--lenses L1,L3` runs only those lens agents (comma-separated, with or without spaces).
   - Validate lens tokens against L1-L14; reject unknown tokens (including `L15` and above) with a
     clear message naming the accepted range.
   - **Stack detection (EDMV4-T24) -- Step 1 is the SOLE authority for L13's applicability.**
     When the operator did **not** pass an explicit `--lenses` list to `/edm:code-audit`, run
     `edm-state detect-conditional-lenses <PREFIX>` and record its CSV output (possibly empty) as
     `NA_LENSES`. This determination is a deterministic filesystem predicate over the repository's
     tracked files, computed fresh every round -- never inherited from a previous round, never
     re-derived or second-guessed by a lens agent. Every lens agent must **agree** with this
     determination rather than form its own; `agents/edm-audit-type-design.md`'s own N/A exit
     agrees with Step 1's determination and never substitutes for it (`EDMV4-T26`) -- a mismatch
     between the two is a contract violation, in the `agents/edm-test-integration.md:21-25` shape.
     **Operator override:** when the operator DID pass an explicit `--lenses` list, `NA_LENSES` is
     always empty and this auto-N/A path does not run at all -- an explicit human request is
     honored exactly as given, never silently rewritten.
   - If `--lenses` is omitted, run all 14 lenses **minus** any named in `NA_LENSES` (a lens marked
     N/A is never launched -- absence is authoritative; no placeholder `.md` or `.jsonl` is ever
     written for it).
   - Set `LENS_SET` = the list to run; set `ROUND_TYPE` = `full` when the union of `LENS_SET` and
     `NA_LENSES` covers all 14 lens IDs, or `partial` otherwise.
   - Set `LENS_SET_CSV` = `LENS_SET` joined with commas (e.g. `L1,L9,L11`, or all fourteen minus
     any N/A lens on a full round). Set `NA_LENSES_CSV` = `NA_LENSES` joined with commas (empty
     when `NA_LENSES` is empty). Step 4 **must** pass `LENS_SET_CSV` to `audit-round-start`, or the
     round is recorded as `full` whatever you actually ran, and the never-convergent guarantee
     below silently stops applying.
2. Determine scope: files / commits / branch. Read critical files yourself first to write sharp agent prompts.
3. Resolve the initiative directory from state (handles both flat and product-scoped layouts):
   ```bash
   INIT_DIR="$(edm-state resolve-dir <PREFIX>)"
   ```
   - SRD: `${INIT_DIR}/${user_config.srd_filename}`
   - Ticket pack: `${INIT_DIR}/${user_config.ticket_pack_dirname}/`
   - Ledger: `${INIT_DIR}/code-audit/findings-ledger.jsonl`  (authoritative cross-round path;
     `findings-ledger.md` is its rendered copy, written separately by `edm-state render-ledger`)
4. Obtain the pass number, passing both the lens set AND the N/A set so the round records what
   actually ran and what Step 1 determined was inapplicable:
   ```bash
   N=$(edm-state audit-round-start <PREFIX> code --lenses "${LENS_SET_CSV}" --na-lenses "${NA_LENSES_CSV}")
   ```
   Omit `--na-lenses` entirely when `NA_LENSES_CSV` is empty (the flag requires a non-empty value).
   `--lenses` is not optional here even on a full round. `cmd_audit_round_start` derives
   `round_type` from the union rule: `full` when the union of `lenses` and any lens legitimately
   recorded as N/A (`lenses_na`) covers all 14 lens IDs and `lenses_na` is a subset of the
   conditional lens set, `partial` otherwise. Omitting `--lenses` materializes `lenses` as the full
   14-lens set rather than recording an empty array, so a call that omits the flag still records
   `full` rather than silently satisfying `audit-converged` on a smoke round -- exactly what step
   10's never-convergent rule exists to prevent. Passing all fourteen explicitly on a full round
   is deliberate and self-documenting. `lenses_na` is committed to state under lock here, before
   step 7 launches any agent, so a lens can never retroactively excuse its own non-delivery.
5. Set `OUTPUT_DIR="${INIT_DIR}/code-audit/pass-${N}_$(date +%Y-%m-%d)/"` and `mkdir -p "${OUTPUT_DIR}"`
6. Read the prior `findings-ledger.jsonl` if it exists (or the legacy `findings-ledger.md` if
   only that exists) -- prior round context for the synthesizer, and for briefing each lens
   agent in step 7 with its own prior-round open findings. Reading the JSONL here (not the
   markdown render) matters when a round was interrupted before step 9a's `render-ledger` call
   in a *previous* round: the JSONL is always current, the markdown render can be stale (CA-166).
7. **Launch lens agents in parallel** for every lens in `LENS_SET` (single message, multiple Task calls).
   Each lens:
   - Writes its raw report to `${OUTPUT_DIR}/lens-L{N}.md` and `${OUTPUT_DIR}/lens-L{N}.jsonl`
   - Receives the relevant prior-round open findings from the ledger (filtered to its lens) so it can confirm fixes or re-flag
   - Its Task prompt is the "Lens Agent Launch Template" below, copied **verbatim** -- every line,
     including the JSONL schema line and the CA-130 fallback clause, is literal text that ships in
     the delivered prompt. Do not summarize, paraphrase, or drop any line of the template when
     constructing the actual Task call; the schema and fallback live inside the template's own
     fenced body precisely so they travel with the interpolated prompt rather than being read as
     prose about the template.
8. Write `${OUTPUT_DIR}/lenses-run.txt` -- one lens ID per line (e.g., `L1`, `L2`, ... for a full round, or `L1`, `L3` for a partial). Add a `Round type: full` or `Round type: partial` header line, plus a `Lenses N/A: L13` (or `Lenses N/A: (none)` when `NA_LENSES` is empty) header line (`EDMV4-T24`). This header format does NOT match the `^L[0-9]+$` filter `bin/edm-state`'s completeness backstop uses to recognize a lens-ID line, so no existing or future consumer of this manifest mis-reads it as a lens ID. (`bin/edm-state`'s completeness backstop no longer reads this manifest's content at all -- EDMV4-T23 moved that source of truth to the round record in state -- but the manifest's mere EXISTENCE remains the gate trigger, C-4, so this header still needs to be safe for any reader that does inspect the file.)
8a. **Checked precondition -- do not proceed to step 9 until it holds**: `Glob`
    `${OUTPUT_DIR}/lens-L*.jsonl` and count the matches. Compare that count against `|LENS_SET|`
    (the number of lenses actually run this round, e.g. 14 on a full round). If the counts are
    equal, proceed to the content check below. If the counts differ, **refuse to proceed** and
    name, by lens ID, every member of `LENS_SET` whose `${OUTPUT_DIR}/lens-L{N}.jsonl` is absent
    from the Glob result.
    For each named lens, check whether it returned its findings as text without writing either
    file -- the same stale-plugin-cache issue as the missing `## JSONL Line Format` section,
    decisions.md D22/CA-130 (its delivered agent definition lacked a `Write` tool this round). If
    so, YOU, the orchestrator running this skill, must persist BOTH halves from the returned text:
    write the missing `lens-L{N}.md` AND the missing `lens-L{N}.jsonl` yourself, using the schema
    in the launch template above. Never persist only the `.md` half and proceed; a lens with zero
    corresponding JSONL is a blocking gap, not a degraded-but-acceptable result. After persisting
    any missing halves, re-run the Glob-and-count check; only proceed to the content check below
    once the count equals `|LENS_SET|`.

    **Content check (CA-193, fifth recurrence)**: the count check above cannot distinguish fourteen
    correctly-schema'd files from fourteen files carrying an invented schema -- a count match is
    necessary but not sufficient. For every `${OUTPUT_DIR}/lens-L{N}.jsonl` file, read each line
    and confirm it carries the lens schema's keys -- `schema`, `lens`, `sev` and `status` present,
    and `id` literally `null` -- never the findings-ledger schema's keys (`lenses` (plural),
    `component`, `raised_round`), which is a different, larger schema the synthesizer assigns
    later and no lens ever produces. If any line carries ledger-shaped keys instead of
    lens-shaped keys, or is missing any of `schema`/`lens`/`sev`/`status`, or the file is EMPTY
    (zero lines -- an empty file vacuously passes a per-line check but is an unlanded artifact,
    CA-471), **refuse to proceed**:
    name the offending lens and line, and re-deliver that lens's launch template (below)
    verbatim -- the schema line and the CA-130 fallback clause travel inside the template's own
    fence precisely so a lens producing the wrong shape can be corrected by re-sending the same
    unabridged prompt, not by hand-patching its output. Only proceed to step 9 once every
    `lens-L{N}.jsonl` file passes this content check.
8b. **Record tooling degradation, if any (CA-388)**. If a lens agent stalled and had to be
    resumed before it produced usable output, or its final report ships an explicit
    scope-truncation caveat (e.g. "covered only ~30% of X" or "skipped Y entirely"), record it in
    `${OUTPUT_DIR}/tooling-notes.md`: one line per affected lens naming the lens ID, its stall
    count for this round, and a one-sentence quote or paraphrase of any truncation caveat it
    shipped. Write the file only when there is something to record -- a round where every lens
    produced clean output on the first attempt writes nothing. `lenses-run.txt` stays exactly what
    it is today (the lens set and round type, consumed structurally by the synthesizer and by
    `wave7-smoke.sh`'s T24 AC0); this is a separate, additive file so degraded delivery is
    measurable round over round rather than lost the moment the round's own transcript scrolls
    away. Stabilizing lens-agent delivery itself is out of scope here -- that fix is owned outside
    this repository (findings-ledger.jsonl CA-130, status `noted`) -- this step only makes the
    degradation countable.
9. **Spawn `edm-audit-synthesizer`**. It:
   - Reads the lens reports in `${OUTPUT_DIR}/`
   - Reads the prior `findings-ledger.jsonl` (or the legacy `findings-ledger.md` if only that exists)
   - Merges findings: assigns stable CA-NNN IDs to new findings, marks prior-round findings as `fixed` if absent, re-opens any that reappear, and ranks by confidence rather than discarding single-lens findings
   - Writes the updated `findings-ledger.jsonl` to `${INIT_DIR}/code-audit/findings-ledger.jsonl` -- the authoritative record (it does not write `findings-ledger.md`; that file is rendered separately, deterministically, by `edm-state render-ledger`)
   - Writes `${OUTPUT_DIR}/REMEDIATION.md` for this round
   - Marks the round as `partial` (non-convergent) in REMEDIATION.md if `ROUND_TYPE=partial`
9a. **Render the ledger, close the round, then update the pattern library** -- runs for every round
    (full or partial), after the synthesizer returns and before any convergence approval is presented:
    ```bash
    edm-state render-ledger <PREFIX>
    edm-state audit-round-complete <PREFIX> code
    edm-state update-patterns <PREFIX> code
    ```
    `render-ledger` deterministically writes `findings-ledger.md` from the synthesizer's
    authoritative `findings-ledger.jsonl`; `audit-round-complete` (EDMV3-T51) then records this
    round's completion timestamp, duration, and token/cost totals, keyed by round number, so the
    cost of an individual code-audit round is never invisible. Running `update-patterns` here makes
    this round's pending entries available to the same Convergence gate instead of deferring them to
    the next round. `update-patterns` harvests only headings whose title starts with a stable
    finding ID (`CA-NNN` or `G{N}`) -- the Remediation Plan Format's structural headings carry no
    ID and are never harvested (`docs/audit-patterns/README.md Sec."Append Schema"`). If it prints
    a `WARNING` with `extraction_status=no-recognized-findings`, the synthesizer's REMEDIATION.md
    departed from that format: fix the report, do not treat the run as a clean round.
    `audit-round-complete` also runs the CA-471 completeness backstop: for every lens named in
    `lenses-run.txt`, it verifies a non-empty, parseable `lens-L{N}.jsonl` landed in the pass
    directory, and on any miss it warns naming the lenses and records the round as
    `round_type=partial` -- so a round whose authoritative artifacts are missing can never
    converge even if step 8a was skipped or bungled. That downgrade is IRREVERSIBLE for the round
    it fires on (CA-471): `audit-round-complete` refuses a second completion of the same round
    ("a round may be completed only once"), so persisting the missing halves afterwards does not
    restore `round_type=full` and does not make that round convergent. If the warn fires, persist
    the missing `lens-L{N}.jsonl` halves and record the miss in `tooling-notes.md` (step 8b) so
    the evidence is not lost, then recover by running a WHOLE NEW round
    (`audit-round-start` -> lenses -> synthesis -> `audit-round-complete`) whose lens JSONL all
    lands; convergence reads the LATEST round's type, so only a fresh full round clears it. Never
    proceed to the convergence gate on a downgraded round.
10. **Convergence gate** (full rounds only -- partial rounds are never convergent). The order is always
    **compute -> present -> approve -> record** -- the flag is never set as a side effect of computing it:
    1. **Compute**: `edm-state audit-converged <PREFIX>` is the authority for this computation. Run it
       and take its exit code as the verdict (`0` converged, `1` blocking findings remain or the latest
       round was partial, `3` no `findings-ledger.jsonl` exists yet); it reads the JSONL ledger and names
       every blocking finding by ID, severity and title. Read `findings-ledger.md` alongside it only for
       the presentation counts the gate body quotes -- open `P0`, `P1`, `P2`, and `NOTED` findings
       introduced or surviving in this round (call these `P0_COUNT`, `P1_COUNT`, `P2_COUNT`,
       `NOTED_COUNT`). A round with zero open P0, P1 and P2 findings is clean; any open P0, P1 or P2
       is the blocking set (`Sec."Severity Reference"` below). Do not treat P2 as non-blocking --
       `BLOCKING_FILTER` in `bin/edm-state` includes it, so `audit-converged` will refuse a round
       that a P0/P1-only reading would call clean.
    2. **Present** the gate via `AskUserQuestion` -- before any state mutation, regardless of clean or blocked.
       The option set depends on what's actually open (EDMV3-T68, "give the user the option to converge
       once P0/P1 are clear"):
        - Header: `"Convergence"`
        - **Clean** (`P0_COUNT=0`, `P1_COUNT=0`, `P2_COUNT=0`): question body states the result, e.g.
          *"Pass {N}: 0 P0, 0 P1, 0 P2, {NOTED_COUNT} NOTED findings open. Converge this round?"*
          Options: **Approve** (record convergence now), **Revise** (address anything the human still
          wants changed and re-run affected lenses before asking again), **No-Go** (stop; do not
          record convergence).
        - **P0 or P1 still open**: question body names the blocking set findings (P0/P1 first). Options:
          **Approve** (attempts `edm-state approve-gate <PREFIX> code-audit`, which refuses -- P0/P1
          are never waivable by any option here), **Revise**, **No-Go** -- unchanged from today.
        - **P0/P1 clear but P2s remain** (`P0_COUNT=0`, `P1_COUNT=0`, `P2_COUNT>0`): this is the new
          branch. Question body states: *"Pass {N}: 0 P0, 0 P1, {P2_COUNT} P2, {NOTED_COUNT} NOTED
          findings open. P0/P1 are clear."* -- name the open P2 findings by ID. Options:
          - **Converge now** -- accept the {P2_COUNT} open P2 finding(s) as documented debt and record
            convergence immediately.
          - **Fix low-hanging fruit first** -- remediate the P2 findings whose REMEDIATION.md
            prescription is a single self-contained code change (one file, or a tightly-coupled pair;
            no new test framework or scaffold needed), re-run `edm-state audit-converged <PREFIX>` for
            an updated count, and re-present this same gate with the smaller remaining set. This is a
            loop back to step 11/12 for that narrower subset only -- not every open P2, and not a new
            lens round.
          - **Keep fixing everything** -- treat every open P2 as blocking, same as today's default;
            loop back to the remediation gate (step 11) and step 12 for the full set.
          - **No-Go** -- stop; do not record convergence.
        - If any pattern-library entries are pending review, this same `AskUserQuestion` call also
          carries their curation questions -- see Sec."Pending Pattern Entries (gate-time curation)"
          below. If none are pending, the presentation is exactly as described above.
        - Follows `` `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"` `` -- only an explicit
          **Approve** or **Converge now** selection records convergence.
    3. **Approve** (and only on explicit **Approve**, clean or P0/P1-blocked case): run
       `edm-state approve-gate <PREFIX> code-audit`.
       **Converge now** (and only on explicit **Converge now**, the P0/P1-clear-P2s-remain case): run
       `edm-state approve-gate <PREFIX> code-audit --accept-p2-debt`. This flag hard-refuses if any P0
       or P1 is open (defense in depth -- the gate presentation above should never have offered this
       option in that case) and otherwise records `code_audit_converged=true` plus debt metadata
       (`code_audit_p2_debt_accepted`, `_count`, `_round`, `_accepted_at`, `_accepted_by`) -- the ledger
       itself is left unchanged, so the accepted P2s still show as open findings; only the gate is
       unblocked. `edm-state archive` later re-verifies P0/P1 are still clear and refuses if a newer
       full audit round has completed since acceptance (the debt has gone stale -- re-run
       `--accept-p2-debt` or fix the remaining findings first).
    4. **Record**: immediately after Approve or Converge now, append the gate approval to
       `decisions.md` in the initiative directory and add a closure note to the top of
       `${OUTPUT_DIR}/REMEDIATION.md` (the current round's file):
       ```
       | Convergence | Pass {N} | Approve | {P0_COUNT} P0, {P1_COUNT} P1, {P2_COUNT} P2, {NOTED_COUNT} NOTED open at presentation; convergence approved | {date} |
       ```
       or, on **Converge now** with accepted debt:
       ```
       | Convergence | Pass {N} | Converge now (accept-p2-debt) | 0 P0, 0 P1, {P2_COUNT} P2 accepted as debt, {NOTED_COUNT} NOTED open at presentation; convergence approved with debt | {date} |
       ```
       ```markdown
       ## Post-Remediation Closure ({YYYY-MM-DD})
       All findings in this round resolved. Convergence reached {YYYY-MM-DD}.
       The cross-round ledger at `code-audit/findings-ledger.jsonl` is the authoritative record;
       `findings-ledger.md` is its deterministic render, produced by `edm-state render-ledger`.
       The original audit snapshot is preserved below.
       ---
       ```
       On **Converge now**, replace the first sentence with `{P2_COUNT} P2 finding(s) accepted as
       documented debt; all P0/P1 findings resolved. Convergence reached {YYYY-MM-DD}.` so a reader
       does not conclude every finding was fixed.
       ASCII-only, like every other committed artifact this methodology produces (no em dashes,
       no arrows, no smart quotes) -- `edm-lint-artifacts` class 2 enforces this at commit time.
       This prevents a reviewer reading the round directory in isolation from seeing
       "Convergence NOT reached" after all work is done.
    - On **Fix low-hanging fruit first**: remediate the identified subset, re-run `edm-state
      audit-converged <PREFIX>`, and re-present this gate (do not loop through the full
      remediation-gate/step-11 cycle for findings outside that subset).
    - On **Revise** or **Keep fixing everything**: no state mutation; loop back to the remediation
      gate (step 11) and step 12.
    - On **No-Go**: no state mutation; stop and summarize the blockers for the human.
11. Read `REMEDIATION.md`. Present the remediation gate (see "Remediation Gate (Code Audit)" below) and STOP
    for approval.
12. On approval, remediate per the rollout order in the plan.
13. After remediation, re-run affected lenses (use `--lenses` for targeted re-audit, or full round for convergence). Loop until the Convergence gate records Approve.

## The 14 Audit Lenses

| Agent                        | Lens                                                                             |
|-------------------------------|----------------------------------------------------------------------------------|
| `edm-audit-logic`             | L1: Logic, correctness, stubs, TODOs, NotImplementedError                        |
| `edm-audit-dead-code`         | L2: Dead code, unreachable paths, env-eliminated branches                        |
| `edm-audit-edge-cases`        | L3: Edge cases, concurrency, race conditions, null/empty inputs                  |
| `edm-audit-test-quality`      | L4: Test quality, suppressed failures, mock abuse                                |
| `edm-audit-runtime`           | L5: Runtime hygiene (lock files, temp files, .gitignore coverage)                |
| `edm-audit-docs`              | L6: Comment & error-message accuracy                                             |
| `edm-audit-consistency`       | L7: Cross-file consistency (timeouts, retry, error handling)                     |
| `edm-audit-security`          | L8: Security & portability (bash, paths, env vars, systemd)                      |
| `edm-audit-spec`              | L9: Spec/ticket compliance (REQUIRES ticket pack/SRD paths)                      |
| `edm-audit-dry`               | L10: DRY violations, duplicate utilities, divergent parallel implementations     |
| `edm-audit-wiring`            | L11: Integration wiring (frontend<->API<->backend, dummy data, unused endpoints) |
| `edm-audit-silent-failures`   | L12: Silent failures -- dangerous fallbacks and errors that succeed while hiding a real failure |
| `edm-audit-type-design`       | L13: Type design -- illegal states made unrepresentable (**conditional**: auto-N/A on an untyped stack, see Step 1) |
| `edm-audit-behavioral-tests`  | L14: Behavioral test coverage -- would the tests catch a real bug in the changed behaviour |

## Smoke Audit vs. Full Round

A partial round is a sanctioned choice with a stated cost, not a shortcut taken quietly. There are
exactly two paths:

| Path | Command | When |
|---|---|---|
| **Smoke audit** (3 lenses) | `/edm:code-audit <PREFIX> --lenses L1,L9,L11` | The wave under audit is **10 tickets or fewer** AND the change **does not touch production behaviour** |
| **Full round** (14 lenses) | `/edm:code-audit <PREFIX>` | Everything else, and **always** for a release candidate |

Both conditions must hold to take the smoke path. Ticket count is the count of `{PREFIX}-T{NN}`
tickets in the scope being audited this round, not the initiative total.

"Touches production behaviour" is mechanical, not a judgment call. The change touches production
behaviour if **any** of the following is true:

1. It edits code that runs in a deployed environment -- application, service, scheduled job,
   migration, or infrastructure definition -- rather than only tests, fixtures, docs, or
   developer-only tooling.
2. It changes a database schema, a migration, an API request/response contract, or a persisted
   data format.
3. It changes authentication, authorization, secret handling, or any network boundary.
4. It changes a runtime default, timeout, retry policy, or the default value of a feature flag.

If any one of the four holds, run the full fourteen regardless of ticket count.

L1, L9 and L11 are the smoke set because their misses are the ones review does not recover: a stub
that returns a constant (L1), an AC that was never built (L9), and a UI wired to `MOCK_DATA` (L11)
each pass every other lens cleanly.

**A partial round is never convergent, so a smoke audit cannot close an initiative** --
enforced by `edm-state audit-converged`, which refuses convergence when the latest recorded
round's round type is `partial`. Reaching convergence always costs one full fourteen-lens round; a
smoke audit buys a faster answer between rounds, never the last one. Nothing about the
partial-round machinery changes here: `ROUND_TYPE=partial` is still set in Operational
Orchestration step 1, the `Round type: partial` header is still written into `lenses-run.txt` in
step 8, and the synthesizer still marks the round non-convergent in `REMEDIATION.md` (step 9 and
Sec."Synthesizer Phase").

## Lens Agent Launch Template

Copy the fenced block below **verbatim** into each lens's Task prompt. Every line inside the
fence -- including the JSONL schema line and the CA-130 fallback clause -- is literal text that
must reach the delivered prompt unabridged; it is not a description of the prompt to write from
memory.

```
Agent: edm-audit-{lens-name}
Prompt: "You are auditing [scope] on lens [L#]: [Lens Name].

Scope:
- Files: [explicit file paths]
- Context: [deployment env, tool versions, constraints]
- Related docs: ${INIT_DIR}/${user_config.srd_filename}, ${INIT_DIR}/${user_config.ticket_pack_dirname}/
- Output: write your raw report to ${OUTPUT_DIR}/lens-L{N}.md and ${OUTPUT_DIR}/lens-L{N}.jsonl
- JSONL schema (one JSON object per line, every finding including NOTED):
  `{"schema":1,"id":null,"lens":"L{N}","round":N,"round_type":"full|partial","sev":"P0|P1|P2|NOTED","confidence":"high|medium|low","file":"path","line":42,"title":"...","status":"open"}`
  -- this literal token list is restated here so the schema is never resolvable ONLY by
  reference. It must also match, verbatim, the schema documented in your own agent
  definition's `## JSONL Line Format` section; if your delivered definition lacks that
  section (a stale plugin cache -- decisions.md D22/CA-130), use the schema above as the
  authoritative fallback rather than treating its absence as license to skip the JSONL file.
  Do not use the findings-ledger schema here (`id` is null at the lens stage; the synthesizer
  assigns the stable `CA-NNN` ledger ID later; that is a different, larger schema).

Your mandate is ONLY [lens name]. Apply the False Alarm Filter before reporting.
Write findings + 'Noted / Not Actionable' section to your markdown file, and emit the same actionable/noted findings to your JSONL file using that schema."
```

## False Alarm Filter

Before reporting any finding, the lens agent applies:

1. Is this behavior documented as intentional in the plan/SRD/ticket?
2. Is there a comment explaining why this looks wrong but is correct?
3. Is this pattern used consistently everywhere in the file or project?

If yes to any -> record as "Noted / Not Actionable" with one-line rationale, do not report as a finding.

## Synthesizer Phase

**Gated on step 8a (CA-193)**: "after all lens reports are written" below means "after step 8a's
Checked precondition -- both the count check and the content check -- holds for every
`lens-L{N}.jsonl` file," not "as soon as any report exists." Do not spawn the synthesizer on the
strength of this section alone; a reader who skips straight here and treats markdown-only reports
as sufficient reproduces the exact CA-193 regression step 8a's content check exists to catch.

After all lens reports are written (per step 8a, above), spawn `edm-audit-synthesizer` with:

```
Agent: edm-audit-synthesizer
Prompt: "Read the lens reports (prose and JSONL) in ${OUTPUT_DIR}/, including
         ${OUTPUT_DIR}/tooling-notes.md if it exists (CA-466: per-lens stall counts and
         truncation caveats -- carry them into REMEDIATION.md's coverage caveat).
         Read the prior findings
         ledger at ${INIT_DIR}/code-audit/findings-ledger.jsonl (or the legacy
         findings-ledger.md if only that exists).
         Apply the second-pass False Alarm Filter, ranking by confidence and corroboration
         rather than discarding single-lens findings (multi-lens = higher confidence; a
         single-lens low-confidence finding is demoted to NOTED, never dropped).
         Deduplicate findings flagged by multiple lenses.
         Merge findings with the ledger: assign stable IDs (CA-001, CA-002, ...) to new
         findings; mark prior open findings as 'fixed' (resolved_round = N) if they no
         longer appear; re-open any that reappear under their original ID.
         Write the updated ledger to ${INIT_DIR}/code-audit/findings-ledger.jsonl -- the
         authoritative record. Do not write findings-ledger.md yourself.
         Write the consolidated remediation plan to ${OUTPUT_DIR}/REMEDIATION.md.
         If this is a partial round (fewer than 14 lenses), note 'Round type: partial'
         in REMEDIATION.md -- this round cannot satisfy the convergence gate."
```

Synthesizer responsibilities:

- Apply second-pass filter (intentional behavior, pre-existing issue, documented trade-off), ranking by confidence and corroboration rather than discarding single-lens findings
- Deduplicate (same issue flagged by L1 and L4 -> one finding, higher confidence)
- Severity-rank using canonical P0/P1/P2/NOTED scale (NOT legacy P1/P2/P3)
- Assign stable CA-NNN IDs and merge with prior-round ledger
- Suggest rollout order (which fixes first, which can batch)
- Write the authoritative ledger to `${INIT_DIR}/code-audit/findings-ledger.jsonl` (never `findings-ledger.md` directly -- `edm-state render-ledger` renders that file)
- Write round report to `${OUTPUT_DIR}/REMEDIATION.md`

## Severity Reference

Use the canonical P0/P1/P2/NOTED vocabulary from `CLAUDE.md Sec."Severity vocabulary"` -- no local restatement or legacy relabeling. Read `docs/canonical-sections.md` (resolved relative to the EDM plugin's own root -- `plugins/edm/` in this repository, or the installed plugin's cache root, never the caller's cwd) for the actual section text; a bare `CLAUDE.md Sec."..."` reference does not resolve because CLAUDE.md at the plugin root is not loaded as runtime context.

**Convergence blocking set**: open P0, P1 **and P2** findings from the ledger. `NOTED` is the only
status that closes a finding without a fix, because it is non-actionable rather than postponed
(`CLAUDE.md Sec."Severity vocabulary"`, decisions.md D13; read `docs/canonical-sections.md`,
resolved relative to the EDM plugin's own root -- `plugins/edm/` in this repository, or the
installed plugin's cache root, never the caller's cwd, for the actual section text, since a bare
`CLAUDE.md Sec."..."` reference does not resolve because CLAUDE.md at the plugin root is not
loaded as runtime context). This is not a prose claim: it is
`BLOCKING_FILTER` in `bin/edm-state`, which every consumer of the blocking set references by name,
and `edm-state audit-converged` refuses convergence while any of the three remain open. Legacy
per-finding statuses that a pre-EDMV3 ledger may still carry are coerced to open on read by that
same code, so a finding recorded under the abolished vocabulary cannot reach convergence unfixed.

## Remediation Plan Format

```markdown
# Code Audit Remediation Plan: {Initiative or Feature Name}

## Context

[What was audited, commit/branch, date, deployment target]

## Findings Summary

| # | Sev | Lens(es) | Component | Issue |

## Detailed Findings

### CA-001 (P1, lenses L1 + L4): [Title]

**Problem**

**Fix (concrete code or config)**

**Verification**

**Files**

## Decisions / Non-Findings

[Every false alarm with rationale -- prevents re-investigation]

## Rollout Order

[Which findings first, which to batch, commit strategy]

## Verification Plan

[Syntax checks, tests to run, manual smoke test steps]
```

`agents/edm-audit-synthesizer.md Sec."Remediation Plan Format"` is the authoritative template;
this is its abridged form and must not disagree with it. Two parts are machine-read, not
cosmetic: every finding heading starts with its stable ledger ID (`CA-NNN`, or `G{N}` for an
in-round group), and the six section headings above (`Context`, `Findings Summary`,
`Detailed Findings`, `Decisions / Non-Findings`, `Rollout Order`, `Verification Plan`) carry no
ID. That is exactly how `edm-state update-patterns` tells a finding from scaffolding
(`docs/audit-patterns/README.md Sec."Append Schema"`), so a finding heading written without its
ID is silently dropped from the pattern library, and a structural heading written with one is
harvested as a pattern.

## Remediation Gate (Code Audit)

This is the remediation gate: distinct from the Convergence gate in Step 10, it approves the *remediation
plan itself* (whether to start fixing findings) rather than round closure, and it records no state --
no `edm-state` command runs from this gate.

After the synthesizer writes `REMEDIATION.md`:

1. Summarize: P0/P1/P2 counts (+ NOTED count), top 3 most impactful findings (one sentence each), false alarm count (demonstrates the
   filter worked), estimated remediation effort.
2. Present via `AskUserQuestion`:
   - Header: `"Remediation"`
   - Question: *"Do you approve this remediation plan?"* -- summarize the counts and top findings in the body.
   - Options: **Approve** (proceed to remediate per the rollout order), **Revise** (change scope or priority
     before starting), **No-Go** (stop; do not remediate)
   - Follows `` `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"` ``.
3. **STOP and WAIT** for explicit approval.

## Pending Pattern Entries (gate-time curation)

`edm-state update-patterns` appends novel findings to the pattern library as stubs, each carrying a
`status: pending-review` line plus `source:`, `audit-type:` and `date:` provenance
(`docs/audit-patterns/README.md Sec."Append Schema"`). A stub nobody is ever asked about is a stub
forever, so the Convergence gate -- one the human already stops at -- is where the ask happens.
Because `update-patterns` now runs before the Convergence gate, the pending set may include entries
created by this round as well as entries carried over from earlier rounds or earlier phases.

**Derive the list at presentation time with the `Grep` tool, never from state:** search the
plugin-root-relative path `docs/audit-patterns/*.md` for `status: pending-review`.

Nothing about pending entries is mirrored in `.edm-state.json`. The pattern documents are the only
record, so an entry curated by hand between gates simply stops appearing here.

**No matches: show nothing.** No heading, no "0 pending entries" line, no mention of curation
anywhere in the gate summary. Absence is authoritative.

**Matches: add one line per entry** to the gate summary, reading the entry's `###` heading and its
`source:` line out of the file each match came from:

```
Pending pattern entries
- {entry title} (source: {source-prefix}) -- landed in plugin-root-relative docs/audit-patterns/{target-document}.md
```

Then carry the curation questions **in the same `AskUserQuestion` call as the Convergence
question** -- never a second round. Four questions is that tool's ceiling, so at most three entries
are curated per gate; when more are pending, take the three oldest by `date:` and leave the rest
for the next gate. Each per-entry question uses a short header (`"Pattern 1"`, `"Pattern 2"`,
`"Pattern 3"` -- within the PROTOCOL's header limit), names the entry and its target document in
its body, and offers exactly these four options:

- **Keep** -- delete the entry's `status: pending-review` line, and only that line. Heading,
  provenance lines and body stay exactly as written.
- **Edit** -- take the human's revised one-paragraph description, replace the entry's body with it,
  then delete the `status: pending-review` line.
- **Discard** -- delete the entry outright: its `###` heading, its provenance lines and its body.
- **Leave pending** -- change nothing. The entry keeps its marker and is offered again at the next
  gate.

Apply the chosen edits with `Edit` after the response comes back and before running
`edm-state approve-gate`. Curation is one-way: once the marker is gone the entry is an ordinary
library entry, and a later `update-patterns` never re-marks it (de-duplication on the entry title
blocks the re-append).

The drain is only as good as what enters it. `update-patterns` appends a stub for every
*recognized* finding title and nothing else, so a pending list that is obviously not made of
patterns (severity roll-ups, rollout stages, verification steps) means the source report departed
from the Remediation Plan Format above and the entries should be **Discard**ed, not curated -- and
the report format fixed. Conversely, an arm that harvested nothing says so: `update-patterns`
prints a `WARNING` and records `extraction_status` in state for anything but a clean read, so an
empty pending list is never by itself evidence that a round found nothing worth keeping
(`docs/audit-patterns/README.md Sec."Append Schema"`).

Curation carries no approval weight. The Convergence question itself follows
`` `skills/orchestrator/SKILL.md Sec."Gate PROTOCOL"` `` unchanged, and leaving every entry pending
has no effect on **Approve** / **Revise** / **No-Go**.

## What Single-Pass Audits Miss (Why 14 Lenses)

- **Stubs**: A function returning `{"status": "ok"}` regardless of input looks syntactically correct to every other
  lens.
- **Spec gaps (L9)**: Without the ticket pack, an auditor reading code never knows a `--dry-run` flag was required but
  not built.
- **DRY (L10)**: Two date formatters in two files both work perfectly -- only L10's "count duplicate capabilities"
  mandate finds them.
- **Frontend wired to dummy data (L11)**: A React component rendering from `const MOCK_DATA = [...]` passes every other
  check.
- **Dead error messages**: An error in `if ! flock -w 1800` is unreachable if systemd kills the process at 600s -- only
  L2's cross-reference of timeouts vs. constraints finds it.
- **Runtime file hygiene**: Lock files created at runtime but missing from `.gitignore` only surface under L5.
