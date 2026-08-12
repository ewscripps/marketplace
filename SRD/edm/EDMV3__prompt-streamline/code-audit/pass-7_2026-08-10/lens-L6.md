# Lens L6 -- Comment & Error-Message Accuracy (Round 7)

**Tooling note (CA-130's class, 7+ consecutive rounds):** Write absent from this
lens's delivered runtime tool set. This report was transcribed by the
orchestrator from the lens agent's final message, after a stalled first attempt.

**Coverage caveat, stated up front:** this round was cut short. Sampled
`plugins/edm/bin/tests/wave7-smoke.sh`, `plugins/edm/CLAUDE.md`,
`plugins/edm/bin/edm-state` (partial verdict region),
`plugins/edm/skills/implement/SKILL.md`, and `plugins/edm/hooks/hooks.json`,
plus a tree-wide grep for citation-shaped strings. `agents/*.md` prose,
`README.md`, `CHANGELOG.md`, and `docs/audit-patterns/*` were not audited for
L6 this round.

## Findings (L6: Documentation Accuracy)

### L6-01 (P2) Round 6's citation-durability guard does not reach `bin/` -- three live unpinned line citations survive

Files: `plugins/edm/bin/edm-state:4403`, `plugins/edm/bin/edm-check-grants:419`

`bin/edm-state:4403-4404` reads:

```
# first form), so hooks/hooks.json:117 and skills/implement/SKILL.md:117 -- both single-write
# callers of the first form -- are unaffected.
```

`bin/edm-check-grants:419` carries a second citation of the same target: `#
doubles as the citation (matches the ticket's own "hooks/hooks.json:117"
citation).`

**What the code actually does:** both claims are **accurate as of this
round.** Verified `hooks/hooks.json:117` is the `SubagentStop` prompt whose
step 6 calls `edm-state record-partial-verdict <PREFIX> <ticket> PARTIAL
'<note>'`, and `skills/implement/SKILL.md:117` is `edm-state
record-partial-verdict <PREFIX> <ticket> PARTIAL '<runtime-check note>'`. Both
are single-write callers of the first form. The coincidence of both landing on
line 117 is real, not a copy-paste error.

So this is not a stale-citation finding. It is a **guard-coverage finding**:
round 6 added a citation-durability guard specifically to catch new stale
`file:line` citations, and these three absolute line references -- in shipped
`bin/` scripts, pointing into two files that other tickets edit freely -- are
unpinned by any assertion. A single line inserted anywhere above line 117 of
`hooks.json` silently falsifies **two** comments in **two** files at once, and
nothing fails.

The plugin's own comments record this exact failure mode recurring at least
four times already: `bin/edm-init:170` ("the two line-number citations this
comment used to carry had already drifted stale"), `evals/run-eval.sh:221`
("line-range citation here has already gone stale twice"),
`wave7-smoke.sh:464-468` (CA-102, a hardcoded `sed -n '69,106p'` window),
`wave7-smoke.sh:1036-1037` (CA-315/G39, "a line-range citation here had
already gone stale"). Every one of those was fixed by *removing* the citation
and anchoring to a named marker instead. The three in `bin/` were not.

**Fix:** apply the same remediation the other four received -- replace with
by-name anchors, e.g. `hooks/hooks.json`'s `"matcher": "edm-implementer"`
`SubagentStop` prompt and `skills/implement/SKILL.md`'s `## Step 5: Remediate`
step 2. If the citations are kept, add a wave7 assertion that greps each cited
file at the cited line for the expected `record-partial-verdict` string.

**Escalate to P1** if `code-audit/findings-ledger.jsonl` records the round-6
guard as closing the citation class *tree-wide* -- in that case the class is
falsely closed and this round's convergence math is wrong.

### L6-02 (P2) Guard-effectiveness: the durability assertion for the `schema_at_least()` count cannot detect the case its own prose promises

File: `plugins/edm/CLAUDE.md`, `### .edm-state.json schema_version contract`
section

The doc says:

> **Durability (G25/CA-342):** `wave6-smoke.sh` carries a computed assertion
> (grep -c the real `schema_at_least(` call sites in `bin/edm-state` against
> the count named in this paragraph) so a future edit that adds, removes,
> **or comments** a call site without updating this passage fails a test
> instead of silently drifting stale a fifth time.

**What the code actually does:** a `grep -c 'schema_at_least('` yields one
number -- the total call-site count (6). It is structurally incapable of
detecting the third case the sentence promises. The paragraph makes *two*
numeric claims: six total call sites, and a 4-with-comment / 2-without split
(`cmd_phase_start`, `cmd_phase_complete`'s artifact precheck, `cmd_archive`'s
wave-B check, `cmd_gate_check` have the canonical `# requires schema_version
>= N` comment; `cmd_approve_gate`'s convergence precheck and
`cmd_audit_converged` do not). Only the total is pinned. If a contributor adds
the canonical comment to `cmd_audit_converged`, the count stays 6, the test
stays green, and the "two do not" claim goes stale -- the exact silent drift
the paragraph claims is now impossible.

This matters because the same paragraph instructs readers: *"do not treat 'no
`# requires schema_version >= N` comment here' as evidence that a check is
version-independent."* A reader who trusts the durability sentence will trust
the 4/2 split it does not actually protect.

**Fix:** either (a) extend the wave6 assertion to also count call sites whose
preceding 3 lines contain `# requires schema_version >=`, asserting 4, and
count those without, asserting 2; or (b) narrow the prose -- drop "or
comments" and state explicitly that only the total is machine-checked and the
4/2 split is hand-maintained.

Note the same paragraph already carries a self-corrected drift record ("the
original eight-site, three-missing count this passage stated is stale; two
call sites were retired, not fixed"), which is exactly the failure a
count-only guard permits. That history supports fix (a) over (b).

### L6-03 (P2) `wave7-smoke.sh` T03 block banner is malformed -- its header is attributed to the T04 block

File: `plugins/edm/bin/tests/wave7-smoke.sh:213-226`

Every other section in the file opens with a three-line banner (divider, `#
EDMV3-TNN ...`, divider). The T03 section has only a *trailing* divider:

```
223  # EDMV3-T04 end
224  # EDMV3-T03: bin/edm-check-grants -- four-source grant/instruction contract checker
225  # =================================================================================
```

The T04 block's own comment at :214-215 instructs "Do not add unrelated cases
to this block; append a new commented block instead if another ticket needs
one" -- so a reader following that instruction sees T03's header sitting
immediately under `# EDMV3-T04 end` with no opening divider and cannot tell
where the T04 block's scope ends. **Fix:** insert a `# ====` divider line
before line 224.

## Noted / Not Actionable

- **`wave7-smoke.sh:1379` -- `# the T03 AC2/AC4 block far above (~line 231)`.**
  A line reference, but hedged with `~` (intentionally approximating) and
  accurate today -- line 231 is the T03 `--list-sources` invocation. Passes
  the false-alarm filter. Worth knowing the guard is blind to path-less prose
  line references of this shape.
- **`wave7-smoke.sh:1385` -- "a shared, invariant-tracked capture 1000+ lines
  later".** Approximation, accurate (T03 at ~231, capture at ~1394).
- **`plugins/edm/bin/_edm-lint-lib.sh:78` -- `"agent: edm-audit-runtime:
  missing-write-grant: agents/x.md:12"`.** Illustrative example output using a
  placeholder path (`agents/x.md`), not a citation. A naive `path:NNN` guard
  would false-positive here.
- **~20 `| ID | File:Line | ... |` report-table headers across
  `agents/edm-audit-*.md`, `agents/edm-audit-dry.md`,
  `agents/edm-test-coverage-auditor.md`, and `CLAUDE.md:811`'s `` `file:line`
  `` prose.** Literal column labels and prose, not citations. Combined with
  the item above, this is the reason a strict `path:NNN` guard is hard to
  write -- worth telling round 8 before someone tightens the regex.
- **`bin/edm-init:170`, `evals/run-eval.sh:221`, `wave7-smoke.sh:464-468`
  (CA-102), `wave7-smoke.sh:1036-1037` (CA-315/G39).** All four are *correct*
  remediations: the citation was removed and replaced with a named anchor,
  with a comment recording why. Exemplary; cite these as the pattern when
  fixing L6-01.
- **`CLAUDE.md` "Model and effort assignments" -- literal unfilled `<date>`
  in "Derived from tiering matrix `<date>`".** Immediately followed by
  "**Status: NOT yet matrix-derived**" plus decisions.md D23/D28 and the exact
  command that replaces it. Documented as intentional.
- **`CLAUDE.md` "Cost tracking" -- pricing tables verified 2026-07-28, current
  generation is Opus 4.8 / Sonnet 4.7 / Haiku 4.6.** Runs driven by Opus 5
  today fall to the `*)` arm and record placeholder Sonnet-tier
  `estimated_cost_usd` with a stderr warning. The doc explicitly names
  `claude-opus-5-20260501` as an example of this and instructs the reader to
  cross-check `model_used` before quoting a figure. Correct and self-aware.
- **`CLAUDE.md` counts verified as accurate this round:** `edm-state` "39
  subcommands" (enumerated list counts to exactly 39); "All 14 skills are
  accounted for" (10 opus + 4 sonnet; effort split 3 high + 7 max = 10);
  "these thirteen files" for D34 anchoring (synthesizer + srd-auditor + 11
  lenses); "nine prompt-surface touch points" with one overlap leaving eight
  residual; "all seven [lint jobs] concurrently" and "The three `test` jobs"
  both match the CI job table.
- **`wave7-smoke.sh:459` check label** names "free-text-is-never-approval"
  while the needle is only `"Gate PROTOCOL"`. The parenthetical ("EDMV3-T35
  re-baseline: restatement replaced by the by-name Gate PROTOCOL reference")
  explains precisely this. Documented.
- **`CLAUDE.md` hooks table `SubagentStop` row** ("Auto-spawn
  `edm-qc-auditor`; write verdict to `qc/qc-summary.md`; persist PARTIAL
  verdicts via `edm-state record-partial-verdict`") matches
  `hooks/hooks.json:117` steps 5-6 exactly. Verified accurate.

## Unverified -- carry to round 8

Stated as gaps, not findings:

1. **Whether the round-6 citation-durability guard exists as an executable
   assertion at all.** A grep for `/citation|stale|line.number/i` across
   `wave7-smoke.sh` returned only prose comments (CA-102, CA-315/G39) -- no
   scanning assertion, but the search output may have been truncated. Confirm
   with `grep -n 'citation' plugins/edm/bin/tests/*.sh` (unlimited output). If
   no assertion exists, L6-01 escalates to P1 and the round-6 remediation was
   comment-only.
2. **`wave7-smoke.sh:1019-1021`** claims a divergence sweep "currently reports
   zero hits for all four" -- yet line 1029's `check` requires
   `$t61_divergence_hits` to *contain* `grep -qP`, so the sweep returns at
   least one hit. The comment's head (lines ~1010-1018) was outside the read
   window, so "all four" may name a subset excluding the `grep -P` family.
   Read `wave7-smoke.sh:1005-1031` to resolve.
3. **`CLAUDE.md` claim that `EDMV4-T04` is "the next unused ticket number in
   `EDMV4__lint-and-pipeline-budgets`"** and that `EDMV4-T02`/`T03` are closed
   per D29. Cross-repo claim, not checked.
4. **`CLAUDE.md` `UserPromptExpansion` matcher**
   `edm:(srd|audit-srd|tickets|audit-tickets|implement)` -- not checked
   against `hooks/hooks.json`.
5. **`CLAUDE.md` "all ten consumers" of the `.alpine_edm` anchor.** 13 total
   jobs minus `test:smoke-bash32`, `validate:plugin-cli`, `eval:nightly` = 10
   is plausible but unverified against `.gitlab-ci.yml`.
</content>
