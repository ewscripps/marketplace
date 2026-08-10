# Epic E4 -- WS4: Structured findings and universal no-deferral

**Wave**: B (v2.1.0 -> v3.0.0)
**SRD requirements**: EDMV3-30 .. EDMV3-43, EDMV3-117, EDMV3-120 (16)
**Tickets**: EDMV3-T24 .. EDMV3-T33 (10)

R3 plus requirement 3 as broadened by D13. Convergence becomes a computed fact rather than a model's
opinion about markdown, and the no-deferral policy becomes one predicate in code plus a deterministic
vocabulary sweep rather than five prompt restatements.

Four tickets in this epic (T28, T29, T30, T31) form a same-MR group per SRD Section 11.2: splitting
them leaves a window where the code and the prose contradict each other on the blocking set.

All commands are run from the repository root unless stated otherwise.

---

## EDMV3-T24: Every lens emits JSONL with confidence under a two-path output contract

| Field | Value |
|---|---|
| Epic | E4 -- Structured findings |
| Wave | B |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV3-30, EDMV3-31 |
| Depends On | EDMV3-T02, EDMV3-T23 |
| Ships-with | EDMV3-T25 |
| Target Components | `plugins/edm/agents/edm-audit-{logic,dead-code,edge-cases,test-quality,runtime,docs,consistency,security,spec,dry,wiring}.md` (`## Output Format` and `## Output` sections), `plugins/edm/skills/code-audit/SKILL.md:89-99` (lens launch template, the output line at `:99`), `plugins/edm/bin/tests/fixtures/code-audit/` (new -- the committed synthetic pass directory) |

### Description

F5 plus explorer 02 C2.1. There is no machine-checkable representation of a finding anywhere in the
pipeline. Both current Anthropic model guides warn that filtering at the finding stage suppresses
recall when a downstream ranking stage exists; the lenses filter with no confidence signal for the
synthesizer to rank on.

Rendering the ledger deterministically (EDMV3-T26) removes drift downstream of the synthesizer but
not upstream: a lens writes two files and could describe different findings in each. The output
contract states the JSONL wins, and the eval scorer's dimension 5 compares per-lens counts. The
residual risk is documented rather than pretended away -- a count match does not imply a content
match, and a prose-only finding is a recall loss, not an integrity loss.

### Acceptance Criteria

- [ ] AC0 (the fixture this ticket and four others verify against is created here): a **committed
      synthetic code-audit pass directory** at `plugins/edm/bin/tests/fixtures/code-audit/`
      containing `lens-L1.jsonl` .. `lens-L11.jsonl`, the matching `lens-L{N}.md` prose reports,
      `lenses-run.txt` with its `Round type:` header, and a `README.md` stating the fixture's intent
      and that it is hand-authored ground truth rather than a captured run. `lens-L1.jsonl` covers
      **every severity** -- one `P0`, one `P1`, one `P2` line at `status: "open"` -- plus one
      `NOTED` line at `status: "noted"`, plus one `status: "fixed"` line and one legacy
      `status: "deferred"` line so the re-open path (EDMV3-T25 AC4, EDMV3-T28 AC5) has a subject.
      A committed directory rather than a live round is deliberate: the only fixture driver
      (EDMV3-T22) runs plan -> srd -> audit and never a code audit, so "run a fixture code-audit
      round" was not an expressible verification for any ticket that used it.
      Verify: `ls plugins/edm/bin/tests/fixtures/code-audit/lens-L*.jsonl | wc -l` prints 11, and
      `jq -sr '[.[].sev] | sort | unique | join(",")' plugins/edm/bin/tests/fixtures/code-audit/lens-L1.jsonl`
      prints `NOTED,P0,P1,P2`.
- [ ] AC1 (positive): each of the eleven lens prompts writes, alongside its prose report, a file
      `${OUTPUT_DIR}/lens-L{N}.jsonl` containing exactly one JSON object per line per finding, and
      the committed fixture from AC0 is an instance of exactly that shape.
      Verify: `ls plugins/edm/bin/tests/fixtures/code-audit/lens-L*.jsonl | wc -l` prints 11, and
      `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "eleven lens prompts instruct a JSONL
      sibling") asserts the instruction text in all eleven agent files.
- [ ] AC2 (schema fixed and documented once): the line schema is
      `{"schema":1,"id":null,"lens":"L1","round":N,"round_type":"full|partial","sev":"P0|P1|P2|NOTED","confidence":"high|medium|low","file":"path","line":42,"title":"...","status":"open"}`.
      `id` is `null` at the lens stage. `round` and `round_type` are supplied by the code-audit skill
      from the round it launched, not re-declared by the model.
      Verify: `grep -c '"schema":1' plugins/edm/agents/edm-audit-*.md` returns 11, and
      `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "lens JSONL schema text present in eleven
      files").
- [ ] AC3 (enums stated in one place, negative): `sev` is exactly one of `P0`, `P1`, `P2`, `NOTED`
      using the canonical scale from `CLAUDE.md Sec."Severity vocabulary"`, and `status` is exactly
      one of `open`, `fixed`, `noted`. **`deferred` is not a legal value.** Pairing rules:
      `sev: "NOTED"` carries `status: "noted"` and vice versa; `status: "fixed"` may carry any
      `sev`; `status: "open"` may not carry `sev: "NOTED"`.
      Verify: `grep -c 'deferred' plugins/edm/agents/edm-audit-*.md` returns 0 for every lens file,
      and `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "no lens declares a deferred status").
- [ ] AC4 (confidence mandatory): `confidence` is mandatory on every line. A finding with no
      confidence value is a contract violation, stated as such in the prompt.
      Verify: `grep -c 'confidence' plugins/edm/agents/edm-audit-*.md | grep -v ':0'` returns
      eleven files.
- [ ] AC5 (scope stated literally): the instruction states, per Sonnet 5 literal-instruction-
      following guidance, one line for **every** finding -- not just the first, and not just the
      high-confidence ones. `NOTED` items appear with `sev: "NOTED"` and `status: "noted"` so
      demotion is recorded as data rather than lost.
      Verify: `grep -c 'every finding' plugins/edm/agents/edm-audit-*.md | grep -v ':0'` returns
      eleven files.
- [ ] AC6 (two-path contract): each lens `## Output` section names exactly two permitted write
      paths, both under the current pass directory, states that writing anywhere else is a contract
      violation, and states that every prose finding must have exactly one corresponding JSONL line
      with the JSONL authoritative on conflict.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "eleven lens files contain the
      two-path contract text").
- [ ] AC7 (negative, valid JSON per line): every emitted line is valid JSON.
      Verify: `while read -r l; do echo "$l" | jq -e . >/dev/null || echo "BAD: $l"; done < plugins/edm/bin/tests/fixtures/code-audit/lens-L1.jsonl`
      prints nothing, run as part of `bash plugins/edm/bin/tests/wave7-smoke.sh`, and the same loop
      over all eleven fixture files prints nothing.
- [ ] AC8 (applied to all eleven, not one exemplar): the edit is applied to all eleven lens files
      and a smoke assertion counts eleven files containing the JSONL contract text.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "eleven JSONL contracts").
- [ ] AC9 (residual risk documented): the lens prompt and `architecture.md` both state that a count
      match does not imply a content match, and that a prose-only finding is invisible to the gate
      -- a recall loss, not an integrity loss.
      Verify: `grep -n 'count match does not imply' plugins/edm/agents/edm-audit-logic.md SRD/edm/EDMV3__prompt-streamline/architecture.md`.
- [ ] AC10 (scorer hook -- **cross-check, owned by EDMV3-T23**): the eval scorer's dimension 5
      compares per-lens finding counts between the prose and JSONL files and reports a mismatch
      (EDMV3-T23 AC2). This ticket does not write the scorer; it confirms the JSONL shape it lands
      is the shape dimension 5 reads.
      Verify: `bash plugins/edm/evals/score-artifacts.sh plugins/edm/bin/tests/fixtures/code-audit/ | jq -e '.dimensions[4].score != null'`
      exits 0 against the committed fixture from AC0.
- [ ] AC11 (prose-change convention, EDMV3-69): the merge request shows before and after for each
      changed `## Output Format` block plus one sentence on why the new wording is better. Eleven
      near-identical blocks are shown once as a canonical before/after plus a list of the eleven
      files it was applied to, which is the sanctioned grouping for a scripted repetition.
      Verify: the MR description contains the canonical before/after block and the eleven-file list.

### Technical Notes

- Depends on EDMV3-T02: a lens that cannot write its prose report cannot write a second JSONL file
  either. This edge is the one cross-wave dependency SRD Section 11.2 calls out explicitly.
- The eleven edits are identical except for the lens ID. Write one canonical `## Output Format`
  block, substitute `L{N}`, and assert eleven copies -- do not hand-vary the wording, or the smoke
  assertion in AC8 becomes eleven separate greps.
- `${OUTPUT_DIR}` is created by `skills/code-audit/SKILL.md:40` before the lenses are spawned. That
  is why a lens needs `Write` but no `Bash(mkdir *)` grant, and it is named as load-bearing in the
  contract (EDMV3-T02 AC7).
- **Depends on EDMV3-T23** because AC10 invokes `evals/score-artifacts.sh`, which T23 creates. The
  edge is cross-wave (A -> B) and therefore safe on wave order alone, but it was invisible, and an
  invisible edge is one a re-planner deletes.
- `bin/tests/fixtures/code-audit/` (AC0) is the verification subject for EDMV3-T24, EDMV3-T25,
  EDMV3-T42 and EDMV3-T02's grant spot-check. Hand-author it; do not capture it from a live round,
  or the ground truth drifts with the model.

### Out of Scope

- The synthesizer's consumption of the JSONL -- EDMV3-T25.
- `round_type` derivation -- EDMV3-T27 (this ticket carries the field; T27 makes it truthful).
- Lens model tiering -- EDMV3-T48 (wave C).

---

## EDMV3-T25: The synthesizer emits the authoritative JSONL ledger and ranks by confidence

| Field | Value |
|---|---|
| Epic | E4 -- Structured findings |
| Wave | B |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV3-32, EDMV3-33, EDMV3-35 |
| Depends On | -- |
| Ships-with | EDMV3-T24 |
| Target Components | `plugins/edm/agents/edm-audit-synthesizer.md` -- the second-pass filter at `:32-41` especially criterion 4 at `:39`, the local P1/P2 severity table at `:60-61`, the worked example at `:116`, the ledger row at `:137`, the status-values sentence at `:140`, the summary template at `:157`, and the `tools:` line at `:5` (no `Bash` grant); `plugins/edm/agents/edm-audit-*.md` (`## False Alarm Filter` sections); `plugins/edm/skills/code-audit/SKILL.md:47-53`, `:140-142` |

### Description

The synthesizer's merge, dedup and cross-round identity work stays LLM judgment -- that is genuine
judgment and is explicitly not being replaced. What changes is the *record* it produces: a JSONL file
with stable CA-NNN IDs, from which the human-readable markdown is rendered deterministically.

Two prompt changes ship with it because they are one story about recall.
`agents/edm-audit-synthesizer.md:39` discards single-lens uncorroborated findings with no confidence
field to rank on -- the synthesizer discards blind, which both Anthropic model guides name as the
recall-suppression pattern to avoid in review harnesses. And each lens `## False Alarm Filter`
already demotes rather than deletes, which is the safe property, but nothing says so, so a future
editor could turn it into a delete. The framing sentence makes an existing safe property explicit.

The `deferred` status is the sharp edge. The live ledger schema today is `open`, `fixed`, `deferred`
(`:140`) with a worked row using it (`:137`), and `deferred` is documented there as *excluded from
the convergence blocking set*. A single surviving line with `status: "deferred"` would converge an
initiative holding an open P0 -- the no-deferral policy defeated by a leftover enum value rather than
by anyone deciding anything.

### Acceptance Criteria

- [ ] AC1 (positive): `agents/edm-audit-synthesizer.md` writes
      `${INIT_DIR}/code-audit/findings-ledger.jsonl` as its authoritative output, with each line
      carrying a stable `id` in the existing `CA-NNN` format preserved across rounds, plus
      `confidence` aggregated from the contributing lens lines and `lenses` listing every lens that
      reported it.
      Verify: run a fixture round, then
      `jq -se 'all(.id | test("^CA-[0-9]{3}$")) and all(has("confidence") and has("lenses"))' <init-dir>/code-audit/findings-ledger.jsonl`.
- [ ] AC2 (negative, no dual output): the synthesizer does **not** write `findings-ledger.md`
      directly. A synthesizer that writes both is a failing condition, because that recreates the
      dual-output drift the plan names as a riskiest assumption.
      Verify: `grep -c 'findings-ledger.md' plugins/edm/agents/edm-audit-synthesizer.md` returns 0
      outside a sentence explicitly forbidding it, and after a fixture round
      `git status --porcelain <init-dir>/code-audit/findings-ledger.md` shows it authored by
      `render-ledger`, not the agent.
- [ ] AC3 (negative, `deferred` deleted from all five sites): the `status` enum is exactly
      `open | fixed | noted`. `deferred` is deleted from the schema at `:140`, the worked
      remediation example at `:116`, the ledger row at `:137`, the local P1/P2 severity table at
      `:60-61`, and the summary-line template at `:157`. Every one of the five is edited.
      Verify: `grep -ni 'defer' plugins/edm/agents/edm-audit-synthesizer.md` returns zero results.
- [ ] AC4 (enforcement at read time, negative): a legacy `deferred` line encountered on first read
      is **re-opened** -- treated as `status: "open"` at its recorded severity -- rather than
      skipped, and `audit-converged` exits non-zero naming the offending line and its ID. A
      prompt-side sweep alone would red the *word* while leaving the *data* able to defeat the gate.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "legacy deferred line re-opens, does
      not skip") -- implemented in EDMV3-T28 and asserted here against the same fixture ledger.
- [ ] AC5 (cross-round semantics preserved): new findings get new IDs, prior-round findings absent
      from this round are marked `fixed`, findings that reappear are re-opened, and
      demote-don't-delete False Alarm handling is preserved. The only semantic change is the removal
      of the `deferred` state.
      Verify: run two fixture rounds and assert with `jq` that a finding fixed between rounds
      carries `status: "fixed"` with its original ID.
- [ ] AC6 (positive, confidence ranking replaces blind discard): criterion 4 (the low-corroboration
      discard) is replaced by a confidence-and-corroboration *ranking* rule -- a single-lens finding
      with `high` confidence is retained at its reported severity; a single-lens finding with `low`
      confidence is retained but demoted to `## Noted / Not Actionable` with its rationale recorded.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "blind corroboration discard phrase
      absent from the synthesizer prompt"), using `check_absent`.
- [ ] AC7 (negative, nothing is deleted): no finding is removed from the JSONL by the synthesizer.
      Demotion changes `sev` and `status`, never line existence. The remaining substantive
      false-alarm criteria (for example "the code path is unreachable in this deployment") are
      preserved unchanged.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "synthesizer prompt states no
      finding is removed") and a two-round fixture where a demoted finding still appears with
      `sev: "NOTED"`.
- [ ] AC8 (lens filter framing, all eleven): each of the eleven `## False Alarm Filter` sections is
      prefixed with an identical framing sentence -- coverage is the job at the lens stage, the
      filter demotes to `## Noted / Not Actionable` and never deletes, the synthesizer is the
      ranking stage -- and **no filter criterion is removed**. A diff that deletes a criterion is a
      failing condition.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "eleven occurrences of the framing
      sentence") and `git diff plugins/edm/agents/edm-audit-*.md | grep '^-' | grep -c 'Is the'`
      returns 0.
- [ ] AC9 (C-4, legacy ledger read): the synthesizer reads the prior `findings-ledger.jsonl` when
      present and falls back to reading a legacy `findings-ledger.md` when only that exists, so an
      in-flight initiative is not stranded.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "markdown-only prior ledger is read
      without error").
- [ ] AC10 (negative, IDs unique and JSON valid): every line of a fixture ledger is valid JSON and
      IDs are unique.
      Verify: `jq -se '(map(.id) | length) == (map(.id) | unique | length)' <fixture-ledger>`.
- [ ] AC11 (prose-change convention): the merge request shows before and after for each changed
      block plus one sentence of rationale (EDMV3-69).
      Verify: the MR description contains a before/after block per edited section.

### Technical Notes

- The synthesizer holds `Write` but **no `Bash` grant** (`agents/edm-audit-synthesizer.md:5`), so it
  could not invoke `render-ledger` even if asked. That is deliberate and is why EDMV3-T26 puts the
  call in the code-audit skill.
- AC8's framing sentence must be byte-identical across all eleven files so a single grep can assert
  it. Write it once and paste it.
- The `disallowedTools: Edit, NotebookEdit` line and the two-path output contract on the synthesizer
  land in EDMV3-T02, not here. Do not add them twice.
- **`Depends On` is empty and that is deliberate.** EDMV3-T24 is a `Ships-with` partner, not a
  build-order predecessor: the two land in one merge request, so there is no interval in which one
  exists without the other. Recording the same pair in both fields said two contradictory things
  about it -- `Ships-with` means "no build-order relationship" by this pack's own definition. The
  lens JSONL this synthesizer consumes arrives in the same MR, and the committed fixture at
  `bin/tests/fixtures/code-audit/` (EDMV3-T24 AC0) is the verification subject for both halves.

### Out of Scope

- `render-ledger` -- EDMV3-T26.
- `audit-converged` and the blocking predicate -- EDMV3-T28.
- The vocabulary sweep across skills and docs -- EDMV3-T29 and EDMV3-T30.

---

## EDMV3-T26: `edm-state render-ledger` produces the markdown deterministically

| Field | Value |
|---|---|
| Epic | E4 -- Structured findings |
| Wave | B |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV3-34 |
| Depends On | EDMV3-T25, EDMV3-T43 |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/edm-state` (new `cmd_render_ledger`), `:110` (`record_artifact_hash`), the drift loop in `cmd_checkpoint` near `:691-751`, `:312` (`rmw_state` discipline), the dispatch table near `:1980-2023`, the `--help` header at `:2-39`, `plugins/edm/skills/code-audit/SKILL.md`, `plugins/edm/CLAUDE.md` (`bin/` table) |

### Description

Scope delta per `architecture.md`: `planning.md` counted one new subcommand; the design needs
`render-ledger` because it is how JSONL/prose drift is eliminated **by construction** rather than
merely detected. The JSONL does not become markdown by itself -- `render-ledger` is a real node in
the pipeline, not an implicit step.

### Acceptance Criteria

- [ ] AC1 (positive): `edm-state render-ledger <PREFIX>` reads `code-audit/findings-ledger.jsonl`
      and writes `code-audit/findings-ledger.md`, preserving the existing human-facing shape -- the
      findings table with CA-NNN IDs, severity, lens attribution, component, status, and the
      `Decisions / Non-Findings` section for demoted items.
      Verify: `edm-state render-ledger TESTX && grep -n 'Decisions / Non-Findings' <init-dir>/code-audit/findings-ledger.md`.
- [ ] AC2 (deterministic): running it twice produces byte-identical output, with stable ordering by
      severity then by ID.
      Verify: `edm-state render-ledger TESTX && cp <f> a.md && edm-state render-ledger TESTX && diff a.md <f>`
      prints nothing.
- [ ] AC3 (generated-file header): the rendered file carries a machine-readable header line stating
      it is generated from the JSONL and must not be hand-edited.
      Verify: `head -3 <init-dir>/code-audit/findings-ledger.md` shows the header.
- [ ] AC4 (negative, hand-edit detected by reused machinery): the rendered ledger's hash is recorded
      via the existing `record_artifact_hash` helper (`bin/edm-state:110`), so the artifact-hash
      drift loop in `cmd_checkpoint` warns a live user when the file has been hand-edited out of
      band. The header line stays as documentation; the *detection* reuses working code.
      Verify: hand-edit the rendered file, run `edm-state checkpoint-if-active`, and confirm the
      drift warning names `findings-ledger.md`.
- [ ] AC5 (negative, hand-edit is overwritten): hand-editing the markdown and re-running
      `render-ledger` restores the generated content, proving the JSONL is the source of truth.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "hand-edited ledger is regenerated
      from JSONL").
- [ ] AC6 (atomic write): the output is written with a temp file plus rename, matching the
      discipline used elsewhere in the script, so an interrupted render cannot leave a truncated
      ledger.
      Verify: `grep -n 'mv .*findings-ledger.md' plugins/edm/bin/edm-state` shows a rename from a
      temp path.
- [ ] AC7 (caller is the skill, not the agent): the code-audit skill calls `render-ledger`
      immediately after the synthesizer returns. The synthesizer does not and cannot call it -- it
      holds no `Bash` grant.
      Verify: `grep -n 'render-ledger' plugins/edm/skills/code-audit/SKILL.md` returns the call, and
      `grep -c 'render-ledger' plugins/edm/agents/edm-audit-synthesizer.md` returns 0.
- [ ] AC8 (lint clean): the rendered output is ASCII-only and passes `edm-lint-artifacts` including
      the Mermaid class.
      Verify: `bash plugins/edm/bin/edm-lint-artifacts --all` exits 0 with a rendered ledger present.
- [ ] AC9 (surfaced): the subcommand appears in the `--help` block, the dispatch table, and the
      `CLAUDE.md` `bin/` table.
      Verify: `edm-state --help | grep -n render-ledger` and
      `grep -n 'render-ledger' plugins/edm/CLAUDE.md`.
- [ ] AC10 (negative, no ledger): `render-ledger` on an initiative with no JSONL exits non-zero with
      a message distinguishing "no audit has run" from "the render failed", and writes nothing.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "render-ledger with no JSONL
      refuses and writes nothing").

### Technical Notes

- Ordering must be total, not just by severity. Sort by `(sev_rank, id)` where `sev_rank` maps
  P0 -> 0, P1 -> 1, P2 -> 2, NOTED -> 3, so two P1s with adjacent IDs never swap between runs.
- `record_artifact_hash` currently records the SRD and ticket-pack artifacts. Adding a third key is
  additive and must use the `// default` idiom so legacy state files read cleanly (EDMV3-107).
- **Depends on EDMV3-T43** because AC8 requires the rendered ledger to pass `edm-lint-artifacts`
  **including the Mermaid class**, and that fourth class does not exist until T43 lands. Without the
  edge, AC8 asserts a class the tree does not yet have.
- Latency budget: under 1s at p95 on a ledger of 500 findings (EDMV3-101, measured by EDMV3-T67).

### Out of Scope

- The convergence query -- EDMV3-T28.
- Making the synthesizer stop writing the markdown -- EDMV3-T25 AC2.

---

## EDMV3-T27: Rounds record their lens set, so a partial round can never compute convergence

| Field | Value |
|---|---|
| Epic | E4 -- Structured findings |
| Wave | B |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV3-120 |
| Depends On | EDMV3-T24, EDMV3-T25 |
| Ships-with | -- |
| Shared record shape | **The audit-round record**, owned here and extended additively by EDMV3-T51 in wave C. Not a `Ships-with` relationship: same-MR across a wave boundary is unsatisfiable (srd.md v1.2.0 CR3). This ticket designs the record once -- round number, audit type, lens set, `round_type` -- and leaves documented slots for the completion timestamp, duration and cost fields T51 adds. The shape is recorded in `CLAUDE.md`'s state-field table so T51 extends a documented shape rather than rediscovering one. |
| Target Components | `plugins/edm/bin/edm-state:1394-1406` (`cmd_audit_round_start`), the new `cmd_audit_converged` from EDMV3-T28, `plugins/edm/skills/code-audit/SKILL.md:26-30` (`--lenses`), `:46` (`lenses-run.txt` and the `Round type:` header), `:54` (the prose non-convergence heading), `plugins/edm/agents/edm-audit-*.md` (`## Output Format`) |

### Description

`--lenses` already exists and `skills/code-audit/SKILL.md:54` states that partial rounds are never
convergent -- but that is a prose heading, and this initiative replaces prose with mechanism. The
ledger carries no round-type field, so once convergence becomes a `jq` query over the JSONL,
`/edm:code-audit X --lenses L1,L9,L11` returning zero blocking findings computes as converged. The
replacement mechanism would be strictly weaker than the prose it replaced, in the one place the
initiative promises the opposite.

### Acceptance Criteria

- [ ] AC1 (positive): `edm-state audit-round-start <PREFIX> code` accepts and records the round's
      lens set and derived `round_type` (`full` when all eleven lenses ran, `partial` otherwise),
      keyed by audit type and round number, alongside the existing round counter.
      Verify: `edm-state audit-round-start TESTX code --lenses L1,L9,L11 && edm-state get TESTX | jq -e '.audit_rounds.code.rounds[-1].round_type == "partial"'`.
      This read is only valid because AC1a below makes `.audit_rounds.code` an object on every file,
      legacy ones included.
- [ ] AC1a (C-4, the one sanctioned type widening -- read-coerced, never migrated):
      `audit_rounds.<type>` widens from a bare integer to `{count: N, rounds: [...]}`. Today
      `bin/edm-state:1402` writes `.audit_rounds[$t] = ((.audit_rounds[$t] // 0) + 1)`, a plain
      integer, and the archived EDMV2 state file carries `audit_rounds: {code: 2}`. **Every read of
      `audit_rounds.<type>` coerces first**: a bare integer `N` is read as `{count: N, rounds: []}`,
      so a legacy file yields a round count and an empty round list rather than a `jq` type error.
      No legacy file is rewritten. EDMV3-T14 AC7 names this as the single sanctioned exception to
      "no existing field changes type"; any other type change in this initiative is a defect.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "integer audit_rounds coerces to
      {count, rounds}") against a fixture state file containing literally
      `"audit_rounds": {"code": 2}`, asserting
      `jq -e '.audit_rounds.code.count == 2 and (.audit_rounds.code.rounds | length == 0)'` on the
      coerced read and `check_state_unchanged` on the file itself, plus
      `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "archived EDMV2 state file end-to-end",
      EDMV3-T14 AC4) remaining green.
- [ ] AC2 (derived, not model-declared): the code-audit skill passes the lens set it actually
      launched, derived from `--lenses` or its absence, not re-declared by the model.
      Verify: `grep -n 'audit-round-start' plugins/edm/skills/code-audit/SKILL.md` shows the lens
      set passed from the resolved variable, not from a model-authored string.
- [ ] AC3 (self-describing ledger): every JSONL line carries the `round` and `round_type` of the
      round that produced it, so the ledger is self-describing even if state and ledger are read
      separately.
      Verify: `jq -se 'all(has("round") and has("round_type"))' <fixture-ledger>`.
- [ ] AC4 (negative, the core guarantee): `edm-state audit-converged` requires the **latest** round
      for the audit type to be `full`, and exits 1 naming the partial lens list otherwise -- for
      example `last round was partial (lenses: L1,L9,L11)#59; a full round is required for
      convergence`. A full round followed by a partial re-check does not converge.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (cases "clean ledger after a full round
      converges" and "the same ledger after a recorded partial round does not, naming the lenses").
- [ ] AC5 (existing artifacts unchanged): the partial-round artifacts are unchanged and are the
      human-facing half of the same fact -- `ROUND_TYPE=partial`, the `lenses-run.txt` header, and
      the non-convergent marking in `REMEDIATION.md` all continue to be written exactly as today.
      Verify: `bash plugins/edm/bin/tests/wave4b-smoke.sh` is green and a partial fixture round
      still writes `lenses-run.txt` with its `Round type:` header.
- [ ] AC6 (C-4, legacy rounds): rounds recorded before this field exists are treated as `unknown`
      and, for an initiative at `schema_version >= 2`, block convergence with a message directing
      the user to run a full round. Below that version they warn and proceed.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (cases "unknown round type blocks at
      schema_version 2" and "warns and proceeds below it").
- [ ] AC8 (atomicity and bash 3.2): all state mutation goes through `rmw_state`, and the change
      passes `bash -n` with no bash 4+ construct.
      Verify: `bash -n plugins/edm/bin/edm-state` and
      `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "audit-round-start leaves valid JSON").

### Technical Notes

- **Resolved in srd.md v1.2.0 (CR3), no longer an open ambiguity.** EDMV3-120 previously recorded
  `Ships-with: EDMV3-71` across a wave boundary, which is unsatisfiable -- same-MR means one merge
  request, and wave B and wave C are different merge requests by construction. The field is replaced
  by a `Shared shape:` note in both requirements, mirrored in this ticket's field table and in
  EDMV3-T51's. Nothing about the work changes: this ticket still designs the record once with room
  for T51's additive fields.
- The former AC7 (a cross-check that EDMV3-67's smoke-audit guidance names `edm-state
  audit-converged` as the enforcer) has moved to **EDMV3-T48 AC8**, which is the ticket that owns
  the guidance text and the wave it lands in. A wave-B ticket cannot verify a wave-C edit.
- The `#59;` in AC4's message example is the Mermaid entity code for a literal semicolon and appears
  here because this pack obeys the rule it specifies. The actual shell message contains a literal
  `;` -- the entity code is a document convention, not a runtime string.
- `round_type` derivation is a set-equality check against the eleven known lens IDs. Hardcode the
  list once next to the derivation and assert its length is 11.

### Out of Scope

- `audit-converged` itself -- EDMV3-T28 (this ticket specifies the field it reads).
- `audit-round-complete` and per-round cost -- EDMV3-T51 (wave C).
- The smoke-audit path documentation -- EDMV3-T48 (wave C).

---

## EDMV3-T28: `edm-state audit-converged` computes convergence over one blocking predicate

| Field | Value |
|---|---|
| Epic | E4 -- Structured findings |
| Wave | B |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV3-36, EDMV3-37 |
| Depends On | EDMV3-T07, EDMV3-T25, EDMV3-T27 |
| Ships-with | EDMV3-T29, EDMV3-T30, EDMV3-T31 |
| Target Components | `plugins/edm/bin/edm-state` (new `cmd_audit_converged`, the blocking-predicate constant, the dispatch table near `:1980-2023`, the `--help` header at `:2-39`), `:590` (`cmd_approve_gate`, the pre-check), `:860` (`cmd_archive`), `:1700` (`write_handoff_internal`), `:1252` (the `cmd_validate` exit-3 precedent) |

### Description

R3. Convergence stops being asserted and becomes a query, and the EDMV2 ledger-versus-state
contradiction becomes structurally impossible. D6 as broadened by D13(a): the whole point of the data
representation is that the no-deferral policy becomes one predicate instead of five prompt
restatements that can drift apart.

### Acceptance Criteria

- [ ] AC1 (positive): `edm-state audit-converged <PREFIX>` runs a `jq` query over
      `code-audit/findings-ledger.jsonl` and exits 0 when no finding has `status == "open"` with a
      severity in the blocking set, printing a one-line confirmation including the total findings
      considered and the count of `NOTED` items excluded.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "clean ledger exits 0 with counts").
- [ ] AC2 (negative, blocking findings): it exits 1 when open P0, P1 or P2 findings remain, printing
      counts by severity plus the ID, severity and title of each blocking finding, so the caller can
      present the blocking set to the human without re-reading the file.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (cases "open P0 fails", "open P1 fails",
      "open P2 fails").
- [ ] AC3 (exit codes stated once): `0` converged; `1` blocking findings remain, or the latest round
      was partial, or a line carries an out-of-enum `status`; `3` no JSONL ledger exists. `2` is
      **not** used, because EDMV3-100 reserves 2 for "usage or environment error" across the new
      check scripts and overloading it would make "no ledger" indistinguishable from "you called
      this wrong". `3` matches the `cmd_validate` precedent at `bin/edm-state:1252`.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` asserts each of 0, 1 and 3, and
      `grep -n 'exit 2' plugins/edm/bin/edm-state | sed -n '/cmd_audit_converged/,/^}/p'` returns
      nothing.
- [ ] AC4 (negative, partial round): the command reads the latest round's `round_type` and exits 1
      naming the lens list that ran when it is `partial`. Without this,
      `/edm:code-audit X --lenses L1,L9,L11` producing zero blocking findings would exit 0, pass
      EDMV3-11's pre-check, let `approve-gate` succeed, and satisfy EDMV3-17's convergence condition
      -- a three-lens smoke audit unlocking archive.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "partial round fails naming the lens
      list").
- [ ] AC5 (negative, out-of-enum status): a line whose `status` is outside `open | fixed | noted`
      exits 1 naming the line and its ID, and a legacy `deferred` line is counted as **open** at its
      recorded severity rather than skipped.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "deferred line fails naming it").
- [ ] AC6 (negative, no ledger vs no findings, not conflated): a missing
      `findings-ledger.jsonl` exits 3 with a message distinguishing "no audit has run" from
      "findings remain open". An empty ledger exits 0 with the "no findings" wording.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (cases "no ledger exits 3" and "empty
      ledger exits 0 with the no-findings wording").
- [ ] AC7 (C-4, legacy migration is not a fresh audit): a legacy initiative (`schema_version` absent
      or below 2) with only a markdown ledger exits 3 with a warning, and its caller degrades per
      EDMV3-11 rather than the user being told to run a fresh eleven-lens `opus` round.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "markdown-only legacy ledger exits 3
      with a warning").
- [ ] AC8 (positive, audit-free modes): when `code_audit_required_for_mode()` returns false, the
      command exits 0 with the wording
      `no code audit is required for this mode (<mode>/<lifecycle_mode>)` and the reason is recorded
      by the caller. Otherwise `fast-track`, `fix-pack` and audit-free `mini-srd` initiatives could
      never archive.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "audit-free mode exits 0 with the
      exemption wording").
- [ ] AC9 (blocking set defined once, positive; semantics corrected per G49/CA-325 -- the
      original "1 definition plus 4 call sites" claim counted comments as if they were
      enforcing code): the blocking predicate is defined once in `bin/edm-state` as a named
      constant, and evaluated at exactly ONE real invocation site, inside `cmd_audit_converged`'s
      own `jq` filter. The four named consumers -- `audit-converged` (the direct CLI dispatch),
      `approve-gate code-audit`, `archive`, and HANDOFF rendering -- do NOT each re-invoke the
      predicate themselves; all four reach it INDIRECTLY by calling `cmd_audit_converged` itself,
      which is where the sole real invocation lives. The set is exactly `status == "open"` and
      `sev` in `{P0, P1, P2}`, with `NOTED` excluded and a comment at the definition stating why
      (`NOTED` is non-actionable via the False Alarm Filter, not a deferred finding).
      Verify: `grep -c '^BLOCKING_FILTER=' plugins/edm/bin/edm-state` returns `1` (the
      definition); `grep -c '\$BLOCKING_FILTER' plugins/edm/bin/edm-state` returns `1` (the sole
      real invocation -- this pattern requires the `$` sigil of an actual variable expansion, so
      it excludes the three comments that mention the bare name without evaluating it, unlike a
      literal-name count); and `grep -c 'cmd_audit_converged "\$prefix"' plugins/edm/bin/edm-state`
      returns at least `3` (the three internal callers -- `approve-gate code-audit`, `archive`,
      HANDOFF rendering -- in addition to the direct CLI dispatch entry, which invokes it by a
      different call shape).
- [ ] AC10 (negative, static single-definition assertion): a grep asserts the blocking-predicate
      string appears exactly once in `bin/edm-state`. This is the mechanically checkable form of
      "defined in exactly one place" -- a smoke test cannot mutate the constant inside the script
      under test and remain a smoke test.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "blocking predicate string appears
      exactly once").
- [ ] AC11 (four consumers agree): a smoke test exercises all four consumers against one fixture
      ledger containing an open P0, an open P2, a `noted` entry, a `fixed` entry and a legacy
      `deferred` entry, and asserts all four agree on blocking-set membership.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "four consumers agree on one
      fixture ledger").
- [ ] AC12 (wiring): `cmd_approve_gate <PREFIX> code-audit` calls the check and refuses when it
      fails, and `cmd_archive` calls it as part of lifecycle verification. No prompt file restates
      the blocking-set membership; prompts reference `CLAUDE.md Sec."Severity vocabulary"` and the
      command.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "approve-gate refuses on an open
      P0") and `grep -rn 'P0 and P1' plugins/edm/skills/` returns zero results.
- [ ] AC13 (surfaced): the subcommand appears in the `--help` block, dispatch, and the `CLAUDE.md`
      `bin/` table.
      Verify: `edm-state --help | grep -n audit-converged`.

### Technical Notes

- Read-only: takes no lock and mutates nothing (EDMV3-92 AC3). Assert with `check_state_unchanged`.
- Latency budget: under 500ms at p95 on a ledger of 500 findings (EDMV3-101). A single `jq -se` pass
  over the file meets it comfortably; a per-line shell loop will not.
- The time-of-check-to-time-of-use window between a standalone `audit-converged` call and the
  approval is closed by re-running the check **inside** `cmd_approve_gate` (SRD Section 5.3), not by
  trusting a prior call.
- Ships in the same MR as EDMV3-T29, T30 and T31 (SRD Section 11.2): a split leaves a window where
  the code and the prose contradict each other on the blocking set.
- **AC-band note.** 13 acceptance criteria against the 6-12 band. Six of them (AC1-AC6) are the exit
  contract enumerated one branch at a time, which is the shape that makes a refusal path checkable
  rather than a shape that hides a second ticket. Recorded in the README sizing section.

### Out of Scope

- The archive-side call site -- EDMV3-T18 wires it.
- Replacing the synthesizer's LLM merge/dedup with deterministic matching. Explicitly out of scope
  in SRD Section 3.3: merge/dedup is genuine judgment, only the *record* becomes data.

---

## EDMV3-T29: The canonical severity vocabulary and every restatement site drop deferral language

| Field | Value |
|---|---|
| Epic | E4 -- Structured findings |
| Wave | B |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV3-38, EDMV3-39 |
| Depends On | -- |
| Ships-with | EDMV3-T28, EDMV3-T30, EDMV3-T31 |
| Target Components | `plugins/edm/CLAUDE.md` (Severity vocabulary section); `plugins/edm/skills/code-audit/SKILL.md:144-155` (local table, blocking-set sentence at `:155`, by-name reference at `:146`); `plugins/edm/skills/audit-srd/SKILL.md:71`, `:98`, `:121`; `plugins/edm/agents/edm-srd-auditor.md:69`; `plugins/edm/agents/edm-audit-synthesizer.md:60-61`, `:116`, `:137`, `:140`, `:157`; `plugins/edm/agents/edm-audit-spec.md:57`; `plugins/edm/skills/orchestrator/SKILL.md:372`, `:387`, `:444`, `:525`; `plugins/edm/skills/plan/SKILL.md:57`; `plugins/edm/docs/audit-patterns/README.md:76`, `:92`; `plugins/edm/docs/audit-patterns/qc-audit.md:30`, `:68`, `:76` |

### Description

D13(d). `CLAUDE.md`'s canonical Severity vocabulary currently says P1 is "Fix before shipping; defer
only with explicit written rationale" and P2 is "Fix if low-effort; explicitly defer otherwise". Both
contradict the policy. This is the canonical section every other site references by name, so it
changes first -- and then every site that restates the table locally and would now contradict it.

The enumeration in the Target Components field is the **verified inventory, not an illustrative
sample**: `grep -rni defer plugins/edm/` returns **44 matching lines across 14 files** as of
2026-07-25 -- roughly 45 occurrences, since a few lines carry the token twice. The earlier "~40
across 12 files" undercounted by two whole files, and this ticket sizes from the grep, so the
correction matters. The two files the earlier count missed are `plugins/edm/CHANGELOG.md` (history,
allowlisted) and `plugins/edm/bin/tests/wave4b-smoke.sh` (assertion strings, carved out by
EDMV3-T30 AC5) -- both are scan-scope facts rather than edit sites, which is exactly why an
enumeration that omits them under-scopes the checker. The catch-all grep in AC12 is normative; the
enumeration exists so the work is sized correctly.

The most consequential site is `docs/audit-patterns/qc-audit.md`, which is loaded into
`edm-implementer` at write time (`docs/audit-patterns/README.md:39`), so it actively teaches the
abolished policy to the agent that implements.

### Acceptance Criteria

- [ ] AC1 (canonical section): the P1 row drops "defer only with explicit written rationale" and
      states that P1 findings are remediated before the phase or round may be called complete. The
      P2 row drops "explicitly defer otherwise" and states that P2 findings are remediated before
      convergence. The P0 row is unchanged.
      Verify: `grep -n 'P1\|P2' plugins/edm/CLAUDE.md | sed -n '/Severity vocabulary/,/^##/p'`
      shows the new wording.
- [ ] AC2 (NOTED preserved and distinguished): the `NOTED` row is unchanged and explicitly retains
      its meaning. A one-clause note distinguishes `NOTED` (non-actionable) from deferral
      (actionable but postponed) and states that deferral does not exist in this methodology. The
      backward-compatibility mapping from the legacy P1/P2/P3 scale and the opening sentence
      ("No agent may define a divergent local scale") are preserved verbatim.
      Verify: `grep -n 'No agent may define a divergent local scale' plugins/edm/CLAUDE.md` and
      `grep -n 'not actionable' plugins/edm/CLAUDE.md`.
- [ ] AC3 (delete, do not correct): `skills/code-audit/SKILL.md:144-155`'s local severity table is
      **deleted** in favour of the existing by-name reference at `:146`. It is not corrected in
      place -- a local copy that happens to agree today is the mechanism by which it disagrees
      tomorrow.
      Verify: `sed -n '140,160p' plugins/edm/skills/code-audit/SKILL.md` shows the by-name reference
      and no table.
- [ ] AC4 (blocking-set sentence): `skills/code-audit/SKILL.md:155`'s "Convergence blocking set"
      sentence names open P0, P1 and P2 with `NOTED` excluded, and points at
      `edm-state audit-converged` as the authority.
      Verify: `grep -n 'Convergence blocking set' -A2 plugins/edm/skills/code-audit/SKILL.md`.
- [ ] AC5 (restatements, not the by-name references): in `skills/audit-srd/SKILL.md` the edits are
      the "Can defer" table row at `:71`, the report-template heading
      `## P2 -- Minor (Can Defer)` at `:98`, and the summary line `P2: N deferred` at `:121`. `:65`
      is the correct by-name reference and needs no change. Likewise
      `agents/edm-srd-auditor.md:63` is correct and the edit is the "Can defer" row at `:69`.
      Verify: `grep -ni 'defer' plugins/edm/skills/audit-srd/SKILL.md plugins/edm/agents/edm-srd-auditor.md`
      returns zero results.
- [ ] AC6 (orchestrator, four sites): `skills/orchestrator/SKILL.md:372` (`"Defer to SRD"` option,
      renamed `"Resolve in SRD"`), `:387` (`**Deferred to SRD**` heading, renamed
      `**Resolved in SRD**`), `:444` (`P2: N deferred`), and `:525` (the exec-report content list
      naming "deferred work", renamed "recorded scope boundaries").
      Verify: `grep -ni 'defer' plugins/edm/skills/orchestrator/SKILL.md` returns zero results.
- [ ] AC7 (substantive ruling, the bucket survives): `skills/plan/SKILL.md:57`'s
      `- **Deferred**: follow-up initiatives` is renamed
      `- **Follow-on initiatives**: recorded scope boundaries`. Only the word changes; the planning
      template's scope bucket stays, because a follow-on initiative decided on its own merits is
      D14's scope-boundary framing and is explicitly not a deferral.
      Verify: `sed -n '55,60p' plugins/edm/skills/plan/SKILL.md`.
- [ ] AC8 (reword, do not delete): `agents/edm-audit-spec.md:57`'s False Alarm Filter criterion is
      **reworded** to `Is the requirement explicitly marked out of scope or descoped in the ticket?`
      rather than deleted. This criterion is about the *audited project's* tickets, not EDM's own
      methodology, so its substance is legitimate -- and EDMV3-32 makes deleting any filter
      criterion a failing condition. The reworded form needs no allowlist entry.
      Verify: `sed -n '55,60p' plugins/edm/agents/edm-audit-spec.md`.
- [ ] AC9 (the highest-leverage site): `docs/audit-patterns/qc-audit.md` gets three edits -- `:30`
      (an AC closed "without ever reaching a PASS or explicit runtime-deferred decision"), `:68`
      (the Pre-Flight bullet, rewritten to "verified at runtime via `/edm:verify-runtime` (PASS) or
      remediated (FAIL)"), and `:76` (rewritten to use the `runtime-check:` token). All three are
      `###`-level or bullet content under existing `##` headings, so no new `##` is introduced.
      Verify: `grep -ni 'defer' plugins/edm/docs/audit-patterns/qc-audit.md` returns zero results,
      and `grep -c '^## ' plugins/edm/docs/audit-patterns/qc-audit.md` returns 4.
- [ ] AC10 (pattern library, percentages preserved): `docs/audit-patterns/README.md`'s
      severity-distribution "P2 (can defer)" label at `:92` and the standing-debt prevention
      sentence at `:76` are edited. The percentages are historical data and are preserved.
      Verify: `grep -ni 'defer' plugins/edm/docs/audit-patterns/README.md` returns zero results and
      `git diff plugins/edm/docs/audit-patterns/README.md | grep -c '^-.*%'` returns 0.
- [ ] AC11 (synthesizer, five sites): the five sites enumerated in EDMV3-T25 AC3 are edited. This
      ticket cross-checks them rather than duplicating the edit.
      Verify: `grep -ni 'defer' plugins/edm/agents/edm-audit-synthesizer.md` returns zero results.
- [ ] AC12 (normative catch-all, negative): `grep -rni 'defer' plugins/edm/` returns only the
      `NOTED`-versus-deferral clarification in `CLAUDE.md`, the vocabulary checker's own pattern and
      allowlist files, and `CHANGELOG.md` history entries.
      Verify: `grep -rni 'defer' plugins/edm/ | grep -v CHANGELOG.md | grep -v vocabulary- | grep -v 'not a deferral'`
      returns zero results.
- [ ] AC13 (checker passes): `bin/edm-check-vocabulary` passes over its full scan scope.
      Verify: `bash plugins/edm/bin/edm-check-vocabulary; echo "exit=$?"` prints `exit=0`.
- [ ] AC14 (prose-change convention): the merge request shows before and after for each of the
      roughly 40 occurrences grouped by file, plus one sentence of rationale per file
      (EDMV3-69).
      Verify: the MR description contains a per-file before/after block.

### Technical Notes

- Ships in one MR with EDMV3-T28, T30 and T31. The checker, the sweep and the test re-baselines
  cannot be split without leaving a red window.
- `skills/audit-srd/SKILL.md:98`'s heading is a **report template** heading, not a document heading
  -- renaming it changes the shape of every future SRD audit report. Say so in the MR so a reviewer
  does not read it as cosmetic.
- Size the work from the 44-line grep, not from the file list. Several files carry the token three
  or four times.
- `agents/edm-ticket-auditor.md:73` is **not** an edit site and was removed from Target Components.
  The line reads "Use the canonical severity scale (P0/P1/P2 + NOTED) from `CLAUDE.md
  Sec.\"Severity vocabulary\"`" (verified 2026-07-25) -- a correct by-name reference carrying no
  deferral token. It needs no change and listing it invited an edit that would have introduced a
  local restatement where a reference belongs. Same class as `skills/audit-srd/SKILL.md:65` and
  `agents/edm-srd-auditor.md:63`, both already excluded by AC5.
- **AC-band note.** 14 acceptance criteria against the 6-12 band. Each AC is one named file or file
  group in a mechanical sweep, and the count tracks the corpus rather than the complexity; the
  normative catch-all is AC12. Recorded in the README sizing section rather than resolved by
  splitting, because a partial sweep leaves the canonical section and its restatements in
  contradiction, which is the window SRD Section 11.2 forbids.

### Out of Scope

- The checker script itself -- EDMV3-T30.
- The `implement` and QC-agent edits -- EDMV3-T31.
- The `wave4b-smoke.sh` re-baselines -- EDMV3-T30 and EDMV3-T31 own their respective assertions.

---

## EDMV3-T30: `bin/edm-check-vocabulary` enforces the no-deferral sweep

| Field | Value |
|---|---|
| Epic | E4 -- Structured findings |
| Wave | B |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV3-43 |
| Depends On | -- |
| Ships-with | EDMV3-T28, EDMV3-T29, EDMV3-T31 |
| Target Components | `plugins/edm/bin/edm-check-vocabulary` (new), `plugins/edm/bin/vocabulary-prohibited.txt` (new), `plugins/edm/bin/vocabulary-allowlist.txt` (new), `plugins/edm/bin/edm-lint-artifacts:59` (`report_violation`), `:69` (`build_ignore_set`), `plugins/edm/hooks/hooks.json:117`, `plugins/edm/monitors/monitors.json`, `plugins/edm/bin/tests/wave4b-smoke.sh:36`, `:38`, `:40`, `plugins/edm/skills/orchestrator/SKILL.md:372`, `:387`, `.gitlab-ci.yml` |

### Description

D13(d) needs a deterministic backstop, or the vocabulary creeps back the first time someone writes a
prompt from memory. Per `architecture.md` R-H, the sweep also reds currently-green assertions, so the
checker, the sweep and the test re-baselines ship together.

Two scan-scope facts drove the v1.1.0 correction. `hooks/hooks.json:117` is a `type: prompt` hook
whose text reads "Assign PASS (statically verified), PARTIAL (runtime-only, with
**deferred-to-runtime** note), or FAIL" -- a prompt the model executes on every implementer
completion, squarely inside D13(d)'s "no deferral vocabulary in any prompt or template". And
`bin/tests/wave4b-smoke.sh:36,40` carry the token as assertion strings. A scan that omitted both
would report clean while the policy was being taught at runtime.

### Acceptance Criteria

- [ ] AC1 (scan scope is complete): the new executable scans, in full,
      `plugins/edm/skills/`, `plugins/edm/agents/`, `plugins/edm/docs/` (**including**
      `docs/audit-patterns/qc-audit.md`), `plugins/edm/hooks/hooks.json`,
      `plugins/edm/monitors/monitors.json`, `plugins/edm/CLAUDE.md`, `plugins/edm/README.md` and
      `plugins/edm/bin/`.
      Verify: `bash plugins/edm/bin/edm-check-vocabulary --list-scope` prints all eight paths.
- [ ] AC2 (JSON-escaped prompt strings, negative): the checker parses JSON string values in
      `hooks.json` and `monitors.json`, not only markdown. A scanner that only read `*.md` would
      miss the single highest-leverage site in the corpus.
      Verify: temporarily reinsert `deferred-to-runtime` into the `hooks/hooks.json:117` prompt in a
      scratch copy and confirm `bash plugins/edm/bin/edm-check-vocabulary` exits 1 naming
      `hooks/hooks.json`.
- [ ] AC3 (token list is data, not code): the prohibited-token list lives in
      `plugins/edm/bin/vocabulary-prohibited.txt` and contains at minimum `defer`, `deferred`,
      `deferral`, `deferred-to-runtime`, `next maintenance window`, `accept-partials`, `--force`.
      Verify: `grep -c . plugins/edm/bin/vocabulary-prohibited.txt` is at least 7 and
      `grep -n 'defer' plugins/edm/bin/edm-check-vocabulary` returns no inline token list.
- [ ] AC4 (allowlist is a sibling and is justified per entry): the allowlist lives in
      `plugins/edm/bin/vocabulary-allowlist.txt`, a sibling of the prohibited list so both share one
      location and one lookup. Each entry carries a one-line justification comment. The allowed
      classes are exactly: the `NOTED`-versus-deferral clarification in `CLAUDE.md`, the checker's
      own two pattern files, `CHANGELOG.md` history entries, and `plugins/edm/bin/tests/`.
      Verify: `grep -c '^#' plugins/edm/bin/vocabulary-allowlist.txt` matches the entry count, and
      `grep -c . plugins/edm/bin/vocabulary-allowlist.txt` shows exactly five classes.
- [ ] AC5 (the carve-out that makes the requirement satisfiable): `plugins/edm/bin/tests/` is
      allowlisted because its negative-test cases must contain `--force` and `--accept-partials`
      verbatim in order to assert those arguments are rejected (EDMV3-16 AC10, EDMV3-17). Without
      that carve-out the checker and the required negative tests are mutually unsatisfiable.
      Verify: `bash plugins/edm/bin/edm-check-vocabulary; echo "exit=$?"` prints `exit=0` while
      `grep -c -- '--force' plugins/edm/bin/tests/wave6-smoke.sh` is non-zero.
- [ ] AC6 (output and exit contract): output is
      `path:line: vocabulary: <token>: <snippet>`; exit 0 clean, 1 on any violation, 2 on a usage or
      environment error.
      Verify: `bash plugins/edm/bin/edm-check-vocabulary --bogus; echo "exit=$?"` prints `exit=2`.
- [ ] AC7 (token replacement and three re-baselines): `deferred-to-runtime` is replaced with
      `runtime-check:` everywhere it appears, including in the `hooks/hooks.json:117` prompt text,
      and **all three** affected assertions (`bin/tests/wave4b-smoke.sh:36`, `:38`, `:40`) are
      re-baselined to the new text in the same merge request.
      Verify: `bash plugins/edm/bin/tests/wave4b-smoke.sh` is green and
      `grep -rn 'deferred-to-runtime' plugins/edm/ | grep -v vocabulary-` returns zero results.
- [ ] AC8 (the `"Defer to SRD"` string and its assertion): `skills/orchestrator/SKILL.md:372`'s
      routing option is renamed `"Resolve in SRD"` and its downstream summary heading at `:387`
      matches. Any smoke assertion on either old string is updated in the same MR.
      Verify: `grep -rn 'Defer to SRD' plugins/edm/` returns zero results and
      `bash plugins/edm/bin/tests/run-all.sh` is green.
- [ ] AC9 (no re-derived file walk): the checker sources or mirrors
      `bin/edm-lint-artifacts`' `report_violation` and ignore-marker helpers rather than re-deriving
      the file walk.
      Verify: `grep -n 'report_violation\|build_ignore_set' plugins/edm/bin/edm-check-vocabulary`.
- [ ] AC10 (override-flag grep, negative): the repository-wide override-flag grep passes with the
      documented carve-outs, asserted in CI.
      Verify: `grep -rn -- '--force\|--accept-partials' plugins/edm/bin plugins/edm/skills plugins/edm/agents | grep -v 'plugins/edm/bin/tests/' | grep -v vocabulary- | grep -v 'refused:'`
      returns zero results.
- [ ] AC11 (bash 3.2 and CI): the checker is bash 3.2 compatible, passes `bash -n`, and runs in the
      CI lint stage.
      Verify: `bash -n plugins/edm/bin/edm-check-vocabulary` and
      `grep -n 'edm-check-vocabulary' .gitlab-ci.yml`.
- [ ] AC12 (clean after the sweep): running the checker after the sweep returns exit 0 over the full
      scan scope.
      Verify: `bash plugins/edm/bin/edm-check-vocabulary; echo "exit=$?"` prints `exit=0`.

### Technical Notes

- **`Depends On` is empty and that is deliberate.** EDMV3-T29 is a `Ships-with` partner, not a
  build-order predecessor: the checker, the prose sweep and the test re-baselines land in one merge
  request, so there is no interval in which the checker exists against an unswept tree. Recording
  the same pair in both fields said two contradictory things about it.
- EDMV3-90 (no override flags anywhere) is a **Won't Have** and a recorded scope boundary, so it is
  not an `SRD Refs` entry. AC10's repository-wide override-flag grep is the negative enforcement
  that keeps the boundary true, and the disposition is recorded once in the README coverage map.
- Word-boundary matching matters: `deferential` and `deferred` share a stem but only one is a policy
  violation. Anchor the patterns and record the anchoring choice in the prohibited-list file header.
- `monitors/monitors.json` is in scope even though it carries no token today. Scanning it now is
  cheaper than remembering to add it later.
- CI lands in wave A and blocks merge on red, so the three `wave4b-smoke.sh` re-baselines in AC7 are
  a pipeline stop rather than a stale test. They must be in this MR.

### Out of Scope

- The `implement`/QC prose edits whose assertions this ticket re-baselines -- EDMV3-T31, same MR.
- Adding tokens beyond the seven in AC3. Extending the list later requires no code change, which is
  the point of AC3.

---

## EDMV3-T31: `implement` and QC remediate every FAIL and stop excluding PARTIALs

| Field | Value |
|---|---|
| Epic | E4 -- Structured findings |
| Wave | B |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV3-40 |
| Depends On | EDMV3-T32 |
| Ships-with | EDMV3-T28, EDMV3-T29, EDMV3-T30 |
| Target Components | `plugins/edm/skills/implement/SKILL.md:84`, `:88-91` (QC output format), `:95` (P0/P1 filter), `:98`, `:105` (the PARTIAL exclusion sentence), `:121` (`## Deferred Work`), `:130` (exec-report table column), `:152-161`, `:199`, `:200`, `:209`; `plugins/edm/agents/edm-qc-auditor.md:30`, `:56`, `:58`, `:100`, `:103`, `:113`, `:122`, `:152`; `plugins/edm/skills/orchestrator/SKILL.md:565`; `plugins/edm/hooks/hooks.json:117`; `plugins/edm/bin/tests/wave4b-smoke.sh:36`, `:38`, `:40` |

### Description

F7 plus D13(a). `skills/implement/SKILL.md:95` compiles "all P0/P1 FAIL findings" only, so P2 FAILs
are silently out of scope. `:105` states "PARTIAL findings do not require remediation -- they are
deferred to runtime verification", which is the deferral the policy abolishes.

The QC verdict *semantics* are on the preserve-untouched list (EDMV3-111) and survive verbatim --
"cannot be verified statically", "Never invent a PASS for something you cannot verify". The PARTIAL
*lifecycle* changes; the *semantics* do not. Only the note token is renamed, with one substantive
exception at `agents/edm-qc-auditor.md:113`, which states the abolished policy outright and is
rewritten rather than merely re-tokenized.

### Acceptance Criteria

- [ ] AC1 (positive, every severity): `skills/implement/SKILL.md:95` reads "Compile all FAIL
      findings from `qc/qc-summary.md`, at every severity" with no severity filter.
      Verify: `sed -n '93,97p' plugins/edm/skills/implement/SKILL.md` and
      `grep -c 'P0/P1 FAIL' plugins/edm/skills/implement/SKILL.md` returns 0.
- [ ] AC2 (negative, the abolished sentence is gone): `:105` no longer states that PARTIAL findings
      do not require remediation. It states instead that every PARTIAL is closed by the mandatory
      `/edm:verify-runtime` step before archive, and that a PARTIAL failing runtime verification
      becomes a FAIL and is remediated like any other finding.
      Verify: `grep -c 'do not require remediation' plugins/edm/skills/implement/SKILL.md` returns 0.
- [ ] AC3 (Declare Done checklist): the Step 8 checklist requires all FAIL findings resolved at
      every severity, not "All P0 QC findings resolved", and adds `/edm:verify-runtime` as a
      mandatory item.
      Verify: `grep -n 'verify-runtime' plugins/edm/skills/implement/SKILL.md` returns the checklist
      item.
- [ ] AC4 (token replacement, every occurrence): `deferred-to-runtime` is replaced throughout with
      `runtime-check:`, including at `:121`, `:130`, `:199` and `:200` -- the four the original
      enumeration missed -- and the QC output format at `:88-91` is updated accordingly.
      Verify: `grep -c 'deferred-to-runtime' plugins/edm/skills/implement/SKILL.md` returns 0.
- [ ] AC5 (the section survives, its contents change): `:121`'s `## Deferred Work` section becomes
      `## Out of Scope (recorded boundaries)` with a one-line note that a recorded boundary is a
      decision made on its own merits, not a postponed finding. The section is **not** deleted --
      "items not implemented" is a real thing an exec report must state. What changes is that it can
      only hold decisions, never findings, and a FAIL finding placed there is a QC failure.
      Verify: `grep -n 'Out of Scope (recorded boundaries)' plugins/edm/skills/implement/SKILL.md`.
- [ ] AC6 (exec-report column): `:130`'s table column
      `| Ticket | AC | Deferred-to-runtime note |` becomes `| Ticket | AC | Runtime-check note |`,
      and `:209` is rewritten to state that PARTIALs appear in the runtime-check table and are
      closed by `/edm:verify-runtime` before archive.
      Verify: `grep -n 'Runtime-check note' plugins/edm/skills/implement/SKILL.md`.
- [ ] AC7 (QC semantics preserved verbatim, negative): `agents/edm-qc-auditor.md` PARTIAL semantics
      survive unchanged -- "cannot be verified statically", "Never invent a PASS for something you
      cannot verify" -- with only the note token renamed at `:30`, `:56`, `:58`, `:100`, `:103`,
      `:122` and `:152`.
      Verify: `grep -n 'Never invent a PASS' plugins/edm/agents/edm-qc-auditor.md` still returns the
      sentence, and `git diff plugins/edm/agents/edm-qc-auditor.md | grep '^-' | grep -vc 'deferred-to-runtime'`
      returns 1 (the AC8 rewrite only).
- [ ] AC8 (the one substantive QC edit): `agents/edm-qc-auditor.md:113` -- "PARTIAL findings do not
      require remediation -- they are deferred to runtime verification" -- states the abolished
      policy and is rewritten, not merely re-tokenized.
      Verify: `sed -n '110,116p' plugins/edm/agents/edm-qc-auditor.md`.
- [ ] AC9 (three re-baselines, not two): `bin/tests/wave4b-smoke.sh:36` (`deferred-to-runtime`),
      `:38` (`do not require remediation` -- the literal sentence AC2 deletes), and `:40`
      (`deferred-to-runtime: call the endpoint`, whose target text lives at
      `skills/implement/SKILL.md:200`, a line outside every range the original enumeration listed)
      are all re-baselined in the same MR.
      Verify: `bash plugins/edm/bin/tests/wave4b-smoke.sh` is green.
- [ ] AC10 (orchestrator parallel text): `skills/orchestrator/SKILL.md:565` is updated so
      `post-deploy/verification.md` is no longer described as optional or on-demand.
      Verify: `sed -n '563,567p' plugins/edm/skills/orchestrator/SKILL.md`.
- [ ] AC11 (hook prompt): `hooks/hooks.json:117`'s prompt uses `runtime-check:` rather than
      `deferred-to-runtime`, and remains valid JSON.
      Verify: `jq -e . plugins/edm/hooks/hooks.json >/dev/null && jq -r '.. | strings' plugins/edm/hooks/hooks.json | grep -c 'deferred-to-runtime'`
      returns 0.
- [ ] AC12 (prose-change convention): the merge request shows before and after for each changed
      block plus one sentence of rationale (EDMV3-69).
      Verify: the MR description contains the before/after blocks.

### Technical Notes

- Depends on EDMV3-T32 because AC2's replacement text promises a closure mechanism that must exist.
- The `runtime-check:` token appears in QC output that the `SubagentStop` hook parses. Rename it in
  the hook prompt and in the QC agent in the same commit, or one round of QC output will use the old
  token against a new parser.
- Ships with T28, T29 and T30. All four touch the blocking-set story.

### Out of Scope

- `/edm:verify-runtime` itself -- EDMV3-T33.
- The `record-partial-verdict` closure write -- EDMV3-T32.
- Deleting the grant ritual at `skills/implement/SKILL.md:162-172` -- EDMV3-T58 (wave C).

---

## EDMV3-T32: `record-partial-verdict` supports closure without losing the original note

| Field | Value |
|---|---|
| Epic | E4 -- Structured findings |
| Wave | B |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV3-42 |
| Depends On | -- |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/edm-state:1412-1424` (`cmd_record_partial_verdict`), `:312` (`rmw_state`), `plugins/edm/hooks/hooks.json:117` (existing single-write caller), `plugins/edm/skills/implement/SKILL.md:98` (existing single-write caller) |

### Description

`cmd_record_partial_verdict` currently records a verdict and note. Closure needs a second write
against the same entry, and the original QC-authored runtime-check note must survive it, because
that note is the evidence of what was supposed to be checked.

This ticket blocks EDMV3-T33 and EDMV3-T18 and has no dependencies of its own, so it can land first
in wave B.

### Acceptance Criteria

- [ ] AC1 (positive, note preserved): recording a closing verdict against an existing entry
      preserves the original note under a `prior` key rather than overwriting it.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "closure preserves the prior note"),
      asserting `jq -e '.partial_verdict_map[$k].prior.note' ` is the original string.
- [ ] AC2 (closed entry shape): after closure the entry contains the original verdict (`PARTIAL`),
      the original note, the closing verdict (`PASS` or `FAIL`), the closing timestamp, and the
      verification-document reference.
      Verify: `jq -e 'has("prior") and has("closing_verdict") and has("closed_at") and has("verification_ref")' <entry>`.
- [ ] AC3 (negative, single closure): an entry may be closed only once. A second closure attempt
      exits non-zero naming the existing closure.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "second closure refused"), using
      `check_fails`.
- [ ] AC4 (positive, the sanctioned exception): an entry closed `FAIL` may be re-closed after
      remediation, and doing so appends to a closure history array rather than overwriting.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "FAIL then re-close appends to
      history"), asserting the history array has length 2.
- [ ] AC5 (negative, unknown ticket): recording against a non-existent ticket exits non-zero and
      mutates nothing.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "unknown ticket refused" plus
      `check_state_unchanged`).
- [ ] AC6 (existing callers unchanged): the `SubagentStop` hook at `hooks/hooks.json:117` and
      `skills/implement/SKILL.md:98` work unchanged as single-write callers.
      Verify: `bash plugins/edm/bin/tests/wave4b-smoke.sh` is green and
      `git diff --stat plugins/edm/hooks/hooks.json` shows only the AC-unrelated token rename from
      EDMV3-T31.
- [ ] AC7 (C-4): legacy `partial_verdict_map` entries in the old shape are readable and are reported
      as unclosed.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "legacy entry shape reads as
      unclosed").
- [ ] AC8 (atomicity): all writes go through `rmw_state`, and the state file is byte-identical after
      any refused write.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` uses `check_state_unchanged` on both
      refusal cases.
- [ ] AC9 (no third verdict): the only closing verdicts accepted are `PASS` and `FAIL`. Any other
      value is refused naming the two legal values.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "BLOCKED closing verdict refused").

### Technical Notes

- The `prior` key must nest the whole original entry, not just the note, so a future field added to
  the open shape survives closure automatically.
- The closure-history array is only created on the second closure of a `FAIL`-closed entry. Keep the
  common case a flat object so `jq` reads in `cmd_archive` stay simple.
- AC9 is what makes D15 mechanically true at the state layer: EDMV3-T33 states the policy, this
  ticket refuses the data.

### Out of Scope

- The skill that drives closure -- EDMV3-T33.
- The archive-side check that reads it -- EDMV3-T18.

---

## EDMV3-T33: `/edm:verify-runtime` closes every PARTIAL, and an unverifiable AC is a spec defect

| Field | Value |
|---|---|
| Epic | E4 -- Structured findings |
| Wave | B |
| Priority | Must Have |
| Size | L |
| SRD Refs | EDMV3-41, EDMV3-113 (wave-B portion), EDMV3-117 |
| Depends On | EDMV3-T03, EDMV3-T13, EDMV3-T32, EDMV3-T43 |
| Ships-with | -- |
| Target Components | `plugins/edm/skills/verify-runtime/SKILL.md` (new), `.claude-plugin/marketplace.json:36-49` (the `edm` entry's `skills` array), `plugins/edm/README.md` (command table), `plugins/edm/skills/implement/SKILL.md` (Step 8), `plugins/edm/skills/orchestrator/SKILL.md` (Phase 6 entry), `plugins/edm/CLAUDE.md` (new D15 subsection), `plugins/edm/agents/edm-qc-auditor.md`, `plugins/edm/agents/edm-ticket-auditor.md`, `plugins/edm/docs/audit-patterns/qc-audit.md`, `plugins/edm/docs/audit-patterns/ticket-audit.md`, `SRD/edm/EDMV3__prompt-streamline/decisions.md` |

### Description

R6 hardened by D13(b). The QC prompt design already generates a runtime test plan as a side effect --
each PARTIAL carries a machine-suggested verification note -- and today that plan is thrown away.
This skill drives it.

D15 ships in the same ticket because the two are inseparable. D13 forbids override flags and requires
every PARTIAL to close as PASS or FAIL. That combination produces a real dead end: an AC whose runtime
environment genuinely does not exist cannot be verified, cannot be closed PASS honestly, and if
closed FAIL blocks archive forever. The resolution is not a fourth verdict. **An AC that cannot be
verified was mis-specified**, and the correct place to fix it is the specification, through the
change-control path that already exists: a gate.

**Size justification (L).** This ticket creates a new skill, wires it into two existing skills and
the orchestrator's Phase 6 entry, edits the marketplace manifest, and adds a policy subsection plus
two pattern-library entries and two agent edits. Decomposing it would split the skill from the policy
that defines its verdict set, leaving a window in which `verify-runtime` exists with an undefined
answer to "what if the environment does not exist" -- which is precisely the dead end D15 closes.

### Acceptance Criteria

- [ ] AC1 (positive, the skill exists and runs): a new skill
      `plugins/edm/skills/verify-runtime/SKILL.md` is invocable as `/edm:verify-runtime <PREFIX>`,
      reads `partial_verdict_map` from state, and for each entry presents the recorded runtime-check
      note and drives the check.
      Verify: `/edm:verify-runtime TESTX` in a scratch initiative with two PARTIAL entries presents
      both notes, and `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "verify-runtime skill file
      exists and names partial_verdict_map").
- [ ] AC2 (positive, closure recorded): each entry is resolved to `PASS` or `FAIL` and recorded in
      state with a closing timestamp and a reference to the section of `post-deploy/verification.md`
      that documents it. The skill writes that file with one section per PARTIAL: ticket, AC
      identifier, the runtime check performed, the observed result, and the verdict.
      Verify: after a run, `jq -e '[.partial_verdict_map[] | has("closing_verdict")] | all' <state>`
      and `grep -c '^## ' <init-dir>/post-deploy/verification.md` matches the entry count.
- [ ] AC3 (negative, FAIL creates an obligation, not an escape): a `FAIL` result states plainly that
      the AC is now a FAIL finding and directs the user back to the implement remediation loop. The
      skill offers no way to accept the failure.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "FAIL text directs to remediation
      and offers no acceptance option"), using `check_absent` on accept-style wording.
- [ ] AC4 (negative, no third verdict anywhere): `verify-runtime` records exactly two verdicts. No
      `BLOCKED`, `WAIVED`, `N/A-runtime` or equivalent third value exists in `partial_verdict_map`,
      in `post-deploy/verification.md`, or in any prompt.
      Verify: `grep -rn 'BLOCKED\|WAIVED\|N/A-runtime' plugins/edm/bin/edm-state plugins/edm/skills/verify-runtime/SKILL.md plugins/edm/agents/edm-qc-auditor.md`
      returns zero results, asserted by
      `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "no third verdict token").
- [ ] AC5 (D15 policy, two sanctioned responses): `plugins/edm/CLAUDE.md` gains a short subsection,
      referenced by name from `skills/verify-runtime/SKILL.md` and `agents/edm-qc-auditor.md`,
      stating the rule and the two sanctioned responses when an AC's runtime environment does not
      exist: **(a) rework the AC** into something verifiable in the environment that does exist --
      the usual outcome -- or **(b) move the unverifiable clause out of scope** as a recorded
      boundary for a follow-on initiative, using D14's framing.
      Verify: `grep -n 'unverifiable acceptance criterion' plugins/edm/CLAUDE.md` returns the
      subsection heading and both routes.
- [ ] AC6 (negative, route (b) is a gate action): removing an AC from a ticket after Gate 3 is a
      scope change, so it goes back through gate change control -- presented at the gate with the
      rationale, approved or rejected by the human via the canonical PROTOCOL, recorded in
      `decisions.md` and in the ticket's audit trail. An implementer cannot descope an AC by
      declaring it unverifiable.
      Verify: `grep -n 'implementer cannot descope' plugins/edm/CLAUDE.md` and
      `grep -n 'gate change control' plugins/edm/skills/verify-runtime/SKILL.md`.
- [ ] AC7 (archive stays hard-blocked): once route (a) or (b) is taken the AC is verifiable or gone.
      Nothing in this ticket creates a path to archive with an open one.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "archive still refuses with an open
      PARTIAL after the D15 text lands").
- [ ] AC8 (invoked, not merely named -- and this ticket does not do the invoking): the ordering is
      that the **orchestrator's Phase 6 entry** invokes `/edm:verify-runtime` via the Skill tool and
      then calls `phase-complete 6`. **The orchestrator edit belongs to EDMV3-T38**, which adds
      `Skill` to the orchestrator's `allowed-tools` (its AC4) and writes the per-phase
      invoke-and-gate entries, and **the `phase-complete 6` call is wired by EDMV3-T50**. This
      ticket adds **no** Skill invocation to `skills/orchestrator/SKILL.md`: doing so would put a
      Skill-tool call in the tree ahead of the grant that makes it legal, which
      `bin/edm-check-grants` (EDMV3-T03) reds in CI for the whole interval between the two merges.
      Taking the edge instead -- EDMV3-T33 depending on EDMV3-T38 -- was rejected because
      EDMV3-T36 depends on this ticket and EDMV3-T38 depends on EDMV3-T36, so the edge would close
      the cycle T36 -> T38 -> T33 -> T36. srd.md v1.2.0 CR5 records the same reassignment at the
      requirement level. What this ticket owns is the statement of ownership and the negative half.
      Verify: `grep -c 'Skill' plugins/edm/skills/implement/SKILL.md` shows no `allowed-tools`
      entry, `git diff plugins/edm/skills/orchestrator/SKILL.md` is empty **in this ticket**, and
      `grep -n 'Phase 6 is closed by the orchestrator' plugins/edm/skills/implement/SKILL.md`
      returns the ownership sentence. The orchestrator side is cross-checked at wave-B close by
      EDMV3-T65 and asserted by EDMV3-T50 AC1 and AC4 in wave C.
- [ ] AC9 (direct-invocation path specified): `README.md`'s command table and
      `skills/implement/SKILL.md` Step 8 both state the two-command sequence --
      `/edm:verify-runtime <PREFIX>` then `edm-state phase-complete <PREFIX> 6` -- and
      `phase-complete 6` refuses on open PARTIALs, so the ordering is enforced rather than requested
      even on that path.
      Verify: `grep -n 'verify-runtime' plugins/edm/README.md plugins/edm/skills/implement/SKILL.md`.
- [ ] AC10 (frontmatter contract complete): the skill carries `name`, `description`,
      `user-invocable: true`, `argument-hint: '<PREFIX>'`, and
      `allowed-tools: Read, Write, Bash(edm-state *), Bash(mkdir *), Glob, Grep, AskUserQuestion, TodoWrite`.
      No `Edit`, no bare `Bash`.
      Verify: `sed -n '1,12p' plugins/edm/skills/verify-runtime/SKILL.md` and
      `bash plugins/edm/bin/edm-check-grants` exits 0.
- [ ] AC11 (a real gate token -- **not** the Step 0 block, which EDMV3-T36 owns):
      `edm-state gate-check <PREFIX> verify-runtime` resolves to a real gate rather than falling
      through `cmd_gate_check`'s `*) return 0` branch to an unconditional pass. The **Step 0 block
      itself is added to this skill by EDMV3-T36**, which owns Step 0 for all eight phase skills and
      declares this ticket as a dependency because `verify-runtime` is the eighth of the eight and
      does not exist until this ticket creates it. The earlier wording had this ticket requiring the
      Step 0 block that EDMV3-T36 defines while EDMV3-T36 asserted Step 0 in a skill this ticket
      creates -- a latent circular constraint the prose resolved two contradictory ways. One owner,
      recorded in both tickets.
      Verify: `edm-state gate-check TESTX verify-runtime; echo "exit=$?"` returns non-zero without
      gate 3 and 0 with it. The Step 0 block's presence in this skill is asserted by EDMV3-T36 AC1
      ("all eight phase skills contain the Step 0 reference").
- [ ] AC12 (negative, empty map): running it with an empty `partial_verdict_map` exits 0 with a
      message stating there is nothing to verify, and writes **no** file. Absence is authoritative.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "empty map writes no file"),
      asserting `post-deploy/verification.md` does not exist afterwards.
- [ ] AC13 (manifest): `.claude-plugin/marketplace.json`'s `edm` entry lists the new skill.
      `plugins/edm/.claude-plugin/plugin.json` is **not** edited for this purpose -- it contains no
      `skills` or `agents` arrays. `claude plugin validate` passes.
      Verify: `jq -e '.plugins[] | select(.name=="edm") | .skills | index("skills/verify-runtime/SKILL.md")' .claude-plugin/marketplace.json`
      is non-null, and `claude plugin validate plugins/edm/` exits 0.
- [ ] AC14 (upstream loop closed): `docs/audit-patterns/qc-audit.md` gains a `###` entry under
      `## Anti-Patterns` describing the failure shape -- an AC written against infrastructure that
      does not exist, discovered at Phase 6 -- with the fix being to catch it at ticket-audit time.
      `agents/edm-ticket-auditor.md` and `docs/audit-patterns/ticket-audit.md` add the corresponding
      pre-flight check.
      Verify: `grep -n 'infrastructure that does not exist' plugins/edm/docs/audit-patterns/qc-audit.md`
      and `grep -n 'environment the project does not have' plugins/edm/docs/audit-patterns/ticket-audit.md`,
      with `grep -c '^## ' plugins/edm/docs/audit-patterns/qc-audit.md` still returning 4.
- [ ] AC15 (artifact lint): the `post-deploy/verification.md` template satisfies all four lint
      classes including the new Mermaid class.
      Verify: `bash plugins/edm/bin/edm-lint-artifacts --all` exits 0 with a generated verification
      report present.

### Technical Notes

- The skill is the fifth `AskUserQuestion` holder. EDMV3-T03 granted the other four in wave A; this
  is the wave-B portion of EDMV3-113.
- **Depends on EDMV3-T13** (declared, not merely noted): AC11's gate token resolves only because
  T13 added `verify-runtime` to `cmd_gate_check` and turned the `*)` fall-through into a hard error.
  The edge was previously stated in these notes only, which makes it invisible to the graph.
- **Depends on EDMV3-T43** because AC15 requires the `post-deploy/verification.md` template to
  satisfy **all four** lint classes including the Mermaid class, which does not exist until T43.
- **AC-band note.** 15 acceptance criteria, the highest in the pack, against the 6-12 band. The
  ticket is the pack's single L-sized skill creation and its verdict policy (D15) in one unit; the
  ACs split cleanly into the skill (AC1-AC4, AC10-AC13), the policy (AC5-AC7), the ownership
  boundary (AC8-AC9) and the upstream loop (AC14-AC15). Recorded in the README sizing section
  rather than resolved by splitting, for the reason in the size justification above.
- Keep `post-deploy/verification.md` regeneration idempotent: re-running the skill after remediating
  a FAIL should append a new closure section, not rewrite the file, so the audit trail survives.
- The two pattern-library edits must be `###` under an existing `##` (EDMV3-109). Adding a fifth
  `##` fails the contract check EDMV3-T56 adds in wave C, and would fail the manual check today.

### Out of Scope

- The archive-side PARTIAL block -- EDMV3-T18.
- `record-partial-verdict`'s closure write -- EDMV3-T32.
- Wiring `phase-complete 6` -- EDMV3-T50 (wave C). This ticket states the ordering; T50 makes the
  call.
