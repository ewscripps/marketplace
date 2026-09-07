# SRD Audit Report: EDMV4 -- ECC Integration

**SRD Version Audited**: 1.0.0
**Audit Date**: 2026-08-31
**Auditors**: 3 parallel `edm-srd-auditor` agents (Group A: Sec.1-5 + 6.1-6.4; Group B: Sec.6.5-6.9;
Group C: Sec.6.10-6.14 + Sec.7-12)

## Summary

- **P0 findings: 5 | P1 findings: 44 | P2 findings: 47 | NOTED: 11**
- **Verdict**: **FAIL** -- all P0 and P1 findings are remediated before Gate 2.

| Group | Scope | P0 | P1 | P2 |
|---|---|---|---|---|
| A | Sec.1-5, 6.1-6.4 (`EDMV4-01`..`22`) | 2 | 11 | 12 |
| B | Sec.6.5-6.9 (`EDMV4-23`..`46`) | 2 | 17 | 15 |
| C | Sec.6.10-6.14, Sec.7-12 (`EDMV4-47`..`58`) | 1 | 16 | 20 |

**Independent corroboration.** Groups A and C separately found the same two defects: the Sec.4.6
constraints table is systematically off-by-one in its requirement cross-references, and Sec.4.5
cites `EDMV4-05` where it means `EDMV4-04`. Two auditors reaching the same conclusion from
different scopes raises confidence that these are real and not artifacts of one agent's reading.

**Audit process note.** All three auditors hit the `edm-srd-auditor` 25-turn ceiling before
emitting findings and had to be resumed. This is a capacity finding about the methodology, not
about this SRD -- see "Process Findings" below.

---

## P0 -- Critical

### P0-1 [COMPETING REQUIREMENTS] Sec.6.5 / `EDMV4-24` -- the union derivation turns today's default `full` round into `partial`

The live derivation has **two branches**, not one (`plugins/edm/bin/edm-state:4552-4573`):

```
4553  if [[ -z "$lenses_arg" ]]; then
4557    lenses_json="[]"
4558    round_type="full"
4559  else
4567    all_sorted="$(printf '%s\n' $ALL_LENS_IDS | sort | tr '\n' ',' | sed 's/,$//')"
4568    if [[ "$given_sorted" == "$all_sorted" ]]; then round_type="full"; else round_type="partial"; fi
```

`EDMV4-24` AC2 states the replacement rule unconditionally: `round_type` is `full` when
`(lenses UNION lenses_na) == ALL_LENS_IDS` and `lenses_na` is a subset of `CONDITIONAL_LENS_IDS`.
With `--lenses` omitted, `lenses` is recorded as the empty array (`:4557`), so `{} UNION {}` never
equals `ALL_LENS_IDS` and the rule yields `partial`. AC5 asserts the opposite. The two ACs cannot
both be implemented from the text as written.

**Blast radius**: every `audit-round-start <PREFIX> srd` and `... tickets` call records `partial`
-- those types have no lens concept and never pass `--lenses` (`bin/edm-state:4554-4556` says so
explicitly) -- and `audit-converged` refuses forever because a partial round is never convergent.
`wave6-smoke.sh:3427-3432` and `:3452-3457` both assert `full` for exactly these inputs.

`architecture.md:161-165` (AD5) states the rule with the same unconditional framing, so the defect
originates there and was faithfully carried into the SRD.

**Recommendation**: adopt the materialize option -- require the omitted-`--lenses` branch to record
`lenses = ALL_LENS_IDS` explicitly, and state that as a tested state-shape change. This resolves
P0-2 in the same stroke. The alternative (scope AC2 to the `--lenses`-given branch and leave the
omitted branch untouched) leaves P0-2 open.

### P0-2 [FEATURE GAP] Sec.6.5 / `EDMV4-25` -- moving CA-471's source of truth to state makes the backstop vacuous for the incident it was built for

`EDMV4-25` AC1: "The backstop reads `lenses` and `lenses_na` from the **round record in state**,
not from `lenses-run.txt`. The manifest is a rendering, not a source of truth."

The state round record stores `lenses: []` whenever `--lenses` was omitted
(`bin/edm-state:4557`, written at `:4524`). Today the backstop iterates the **manifest**
(`bin/edm-state:4662-4669`), which lists the real lens IDs regardless of how the round was started,
and therefore requires a non-empty parseable JSONL for each. Under AC1, a full round started
without `--lenses` would iterate an empty array and require **zero** JSONL files.

That is precisely the founding incident recorded in the code comment the requirement cites,
`bin/edm-state:4617-4619`:

> pass-7 of this plugin's own EDMV3 initiative shipped eleven prose reports and ZERO JSONL files,
> and the round still closed and counted as full.

`skills/code-audit/SKILL.md:56-61` independently documents that omitting the flag "makes it record
`full` with an empty `lenses` array regardless of what was run" -- the exact state AC1 would leave
unguarded.

**Recommendation**: materialize `lenses = ALL_LENS_IDS` in the omitted branch (resolving P0-1
simultaneously), and add a regression test replaying the pass-7 shape -- N prose files, zero JSONL,
`--lenses` omitted -- asserting the downgrade still fires.

### P0-3 [COMPETING REQUIREMENTS] Sec.6.11 / `EDMV4-49`+`50`+`51` -- the Must-Have pair anchors four skills to sections that do not exist

`EDMV4-50`'s premise -- "One of the 14 files needs a materially different fix shape from the other
13" (`srd.md:2208`) -- is factually false. **Five of the 14 files carry orphaned citations, at 8
sites naming 6 distinct sections**, only one of which `EDMV4-50` addresses:

| Site | Section cited | Mirror status |
|---|---|---|
| `agents/edm-qc-auditor.md:39` | `Unverifiable acceptance criteria (D15)` | orphan -- `EDMV4-50` fixes |
| `skills/verify-runtime/SKILL.md:31,39,147` | `Unverifiable acceptance criteria (D15)` | orphan -- **not mentioned anywhere in the SRD** |
| `skills/orchestrator/SKILL.md:28,152,196` | `Skill-tool composition` | orphan, **and not a `##` heading** -- bold inline text at `CLAUDE.md:24` |
| `skills/orchestrator/SKILL.md:113,200` | `EDM mode matrix` | orphan; real heading is `## EDM mode matrix (EDMV3-T38)` -- **name mismatch** |
| `skills/orchestrator/SKILL.md:199` | `Project artifact layout` | orphan (exact match available) |
| `skills/orchestrator/SKILL.md:200`, `skills/metrics/SKILL.md:74` | `Phase Timing Guidelines` | orphan; real heading carries `(EDMV3-T38)` -- **name mismatch** |
| `skills/push-jira/SKILL.md:36` | `Optional: Jira synchronization` | orphan (exact match available) |

`EDMV4-49` is **Must Have** and its AC7 declares success when "a grep returns only anchored sites."
`EDMV4-51` -- the only requirement that resolves orphans -- is **Should Have and depends on
`EDMV4-49`/`EDMV4-50`**, so it runs after. Executed as written, the Must-Have pair anchors four
skills to a document that does not contain the sections they name: precisely the outcome
`EDMV4-51`'s own Description calls "worse than the bare form because it looks fixed."

Three of the six section names cannot be added to the generator without first changing a
`CLAUDE.md` heading, because `extract_section` (`bin/edm-sync-canonical-sections:72-79`) matches
`"## ${heading}"` exactly -- and the Mermaid convention forbids renaming a by-name-referenced
heading without updating every reference in the same commit.

**Recommendation**: raise `EDMV4-51` to Must Have and **invert the dependency** so orphan
enumeration completes before `EDMV4-49` anchors anything. Replace `EDMV4-50`'s "one of the 14"
framing with the table above. Add resolution routes for the heading-mismatch class and for
`Skill-tool composition`, which is not a heading at all. Add `verify-runtime/SKILL.md`'s three D15
sites to `EDMV4-50`.

### P0-4 [FACTUAL MISTAKE] Sec.4.6 C9 + `EDMV4-03` -- the premise is contradicted by `decisions.md` D4 as amended and by the working tree

`srd.md:386-392` states the branch "still carries `disable-model-invocation: true` on all 14 skills
... and no `edm-check-skill-sync` guard", and that merging "would silently **revert** that fix."
`srd.md:252` (C9) repeats it.

All three claims are false in the working tree. Grep returns **zero** `disable-model-invocation:
true` in any `skills/*/SKILL.md`; the guard exists at `bin/edm-check-skill-sync:77-78`;
`README.md:131` and `CLAUDE.md:40` carry post-fix wording. `decisions.md` D4 (amended 2026-08-31)
records this and corrects the count to **3** commits behind, not 2.

The SRD was written from `planning.md` before D4 was amended mid-Phase-2, so this is drift, not
authoring error.

**Recommendation**: rewrite `EDMV4-03` and C9 against D4-as-amended. The residual task is only
reconciling `plugins/edm/.claude-plugin/plugin.json:4` (`3.2.0`) against `origin/main`'s `3.2.1`
while preserving the unstaged `*opus-5*` arm. Re-examine "Blocks: every implementation requirement"
-- D4 calls the residual explicitly non-blocking, so the current framing gates the whole initiative
on a one-line version bump.

### P0-5 [COMPETING REQUIREMENTS] Sec.6.3 -- two dependency cycles make 4.2 unschedulable

`srd.md:863` -- `EDMV4-14` depends on `EDMV4-13`, **`EDMV4-16`**.
`srd.md:942` -- `EDMV4-16` depends on **`EDMV4-14`**, **`EDMV4-15`**.
`srd.md:910` -- `EDMV4-15` depends on `EDMV4-13`, `EDMV4-14`, **`EDMV4-16`**.

This yields `14 -> 16 -> 14` and `15 -> 16 -> 15`. Phase 4 wave scheduling is dependency-ordered; a
cycle either deadlocks the scheduler or is silently broken by whichever tool topologically sorts
it -- at which point `EDMV4-16`'s single-commit guarantee, the only thing preventing silent loss of
all harvested pattern content, is the constraint most likely to be dropped.

**Recommendation**: `EDMV4-16` is a constraint *on* 14 and 15, not a peer. Remove it from their
Dependencies lines. Better: fold 14, 15 and 16 into one ticket, since AC5 ("No intermediate commit
leaves the write side landed and the read side not") is unenforceable across two tickets in two
waves by construction.

---

## P1 -- Significant

Forty-four findings. Grouped by theme; each carries its `file:line` and fix.

### Cross-reference integrity (7 findings, corroborated by two auditors)

1. **Sec.4.6 constraints table: six of ten rows cite the wrong requirement.** C1 -> `EDMV4-55`
   (not 34/38/54); C2 -> `EDMV4-56` (not 55); C5 -> `EDMV4-22` (not 17); C6 -> no plausible match
   for `EDMV4-33`; C7 -> `EDMV4-57` (not 56); C8 -> `EDMV4-58` (not 57); C9 -> `EDMV4-03` (not 04).
   A ticket writer using this table as a traceability map wires constraints to the wrong tickets.
2. **Sec.4.5 cites `EDMV4-05` for the inherited-ticket-ID constraint; it is `EDMV4-04`**
   (`srd.md:238`). Sec.10 R13 and the Glossary both get it right, so Sec.4.5 is the outlier.
3. **Sec.4.4 cites `EDMV4-53` for the source-document self-correction; it is `EDMV4-54`**
   (`srd.md:214`).
4. **Sec.3.4 DoD item 9 cites `EDMV4-53`; it is `EDMV4-54`** (`srd.md:158-159`).
5. **Sec.12.2 says "three requirements are unblocked" then names three groups of 13**, and
   `EDMV4-49` is not unblocked by `EDMV4-03` alone.
6. **Sec.12.2 says `EDMV4-03` blocks "everything"**, contradicting `EDMV4-55` and `EDMV4-57`, both
   declaring "Dependencies: none".
7. **`EDMV4-07` <-> `EDMV4-09` mutual dependency** (`srd.md:558`, `:647`) -- same scheduling
   failure class as P0-5. `EDMV4-09` is the deny back-end inside `edm-gateguard`; it cannot precede
   the script's existence.

### Gate 2 presentation accuracy (2 findings -- these govern a human decision)

8. **`EDMV4-05`'s stated cost saving is overstated by roughly an order of magnitude.** Description
   says the descope takes the rewrite "from 400-600 lines to roughly 250-350"; AC1 tells the human
   the saving is "roughly 741 lines of tokenizer plus 250-350 lines". The 741 lines are ECC's
   **JavaScript** -- never written in bash under either option. The real saving is 400-600 minus
   250-350 = **150-250 lines of bash**, plus not porting the recursive-BFS tokenizer.
9. **`EDMV4-05` mischaracterizes what remains guarded.** It claims "EDM already blocks the one
   destructive `Bash` operation its methodology cares about, `git commit`, via
   `edm-lint-staged-artifacts`". Verified at `bin/edm-lint-staged-artifacts:140-159`: that hook
   blocks only on **artifact lint violations**. It guards nothing destructive. `rm -rf`,
   `git reset --hard`, `git clean -fd`, force-push and `DROP TABLE` remain entirely unguarded. The
   Gate-2 presentation must enumerate the concrete unguarded classes.

### Licence and ratification (1 finding)

10. **The dormant MIT NOTICE clause is wired to the wrong decision, creating a live exposure.**
    Sec.7.3 and `EDMV4-56` AC6 both revive the obligation "if Gate 2 rejects `EDMV4-05`". But
    `EDMV4-05` ratifies the destructive-`Bash` descope, not vendor-versus-rewrite; rejecting it
    yields a *larger bash rewrite*, not vendoring. `decisions.md` D13 states the trigger correctly
    (AD1 reversal). **No requirement in this SRD ratifies AD1 itself** -- so a Gate 2 that approves
    `EDMV4-05` while separately directing vendoring leaves the NOTICE obligation dormant.
    Fix: restate the trigger as "if AD1 is reversed to vendoring, by any route", and add a
    requirement presenting AD1 itself for ratification.

### Lens-count sweep completeness (8 findings)

11. **The wave7 inventory misses every hardcoded lens-NAME list and every non-`-eq 11` count**, and
    `EDMV4-33`'s second-pass grep is structurally incapable of finding them:
    `wave7-smoke.sh:1589` (`LENS_AGENTS`, 11 names), `:1905` (`lens_files`, the list T25 AC8
    actually iterates), `:4734` (`T46_LENSES`), `:5386` (`T48_CONTESTED_AGENTS`, 15 names);
    `:1688` (`-eq 12`), `:4735,:4749` (`-eq 13`), `:5402` (`-eq 15`); `:1751`
    (`for t24_n in 1 ... 11`); `:1591,:1599,:1603` ("twelve" banners).
    **`:5386` is the dangerous one**: `t48_contested_count` counts the hardcoded list, so it stays
    15 and **passes green** while silently dropping the three new lenses out of the D16 opus/max
    assertion -- exactly the "silently escapes existing assertions" failure `EDMV4-30` warns about.
12. **`EDMV4-33` AC4's closure grep cannot see most live lens-count forms.** `eleven|11 lens|11-lens`
    misses `run all 11` (`skills/code-audit/SKILL.md:38` -- the exact string T47 AC6 asserts),
    `L1-L11` (`:37`), `lens-L11.jsonl`, `11 parallel orthogonal audit agents` (`:3`), and every
    `-eq 11|12|13|15`. Conversely it *matches* `CLAUDE.md:429` (the D2 guard), which is on neither
    list -- so AC4 reports a defect nobody owns.
13. **Four `bin/edm-state` prose sites explorer 03 marked "must change" are in no requirement**:
    `:3632` (`metrics-report` output), `:4827` (`cmd_audit_converged` refusal text), `:4762`,
    `:4660`.
14. **The artifact-layout trees carry `lens-L11` and are unswept**: `CLAUDE.md:118-119`,
    `README.md:204-205`.
15. **`CLAUDE.md:368`'s contested-audit-set row** ("11 code-audit lenses ... (15 agents)") is cited
    as authority by `EDMV4-30` AC3 but never updated. Its machine counterpart is
    `wave7-smoke.sh:5386,:5402`.
16. **`EDMV4-49` AC5 rewrites the D34 passage, which contains two live lens-count strings**
    (`CLAUDE.md:339` "eleven", `:342` "thirteen"). Neither is on `EDMV4-33`'s do-not-touch list nor
    in its Target Components, so no requirement owns them and AC4's grep flags them as unexplained
    survivors.
17. **Sec.10 R5's "54 occurrences" is wrong.** Running the exact pattern `EDMV4-33` AC4 prescribes
    returns **90 across 16 files**. The delta is partly this initiative's own doing --
    `docs/ecc-integration-analysis.md` contributes 6 and did not exist at Phase 1.
18. **`wave7-smoke.sh:4756-4763` (T46 AC2) is a second machine assertion on the three-criteria
    False Alarm Filter** and is named nowhere in the SRD.

### AD5 / round-type design (4 findings beyond P0-1 and P0-2)

19. **The stated safety property is overclaimed.** "For every input that exists today the new
    derivation returns the identical answer" (`srd.md:1187-1189`, `architecture.md:170-171`) is
    false for `--lenses L1,...,L11`, which returns `full` today and `partial` after -- deliberately.
    Restate as: holding `ALL_LENS_IDS` constant, the union derivation with an empty `lenses_na`
    returns the same answer as today's set-equality for every input.
20. **`EDMV4-24` AC4's "byte-identical replay" is impossible for the case `EDMV4-32` AC7
    simultaneously requires be rewritten** (`wave6-smoke.sh:3445-3449`).
21. **The `lenses_na` timing property -- the entire anti-abuse mechanism -- has no AC and no test.**
    It appears only in prose. AC6 requires atomicity (same `rmw_state` write, under lock), which is
    not ordering. Add an AC: no code path writes or mutates `lenses_na` after `audit-round-start`
    returns; `audit-round-complete` never accepts an N/A declaration.
22. **`EDMV4-25` AC4's coverage downgrade fires on every legitimate operator-requested partial
    round.** For the documented smoke set `--lenses L1,L9,L11`, the union is not `ALL_LENS_IDS`, so
    every smoke round prints an "incomplete coverage" downgrade warning. Scope AC4 to rounds whose
    recorded `round_type` is `full` at completion time.
23. **`EDMV4-25` AC1 vs AC7**: the manifest is declared "not a source of truth" while remaining the
    trigger deciding whether the gate runs at all (`bin/edm-state:4656`). A round producing no
    manifest -- the strongest non-delivery signal -- escapes entirely.
24. **`EDMV4-24` AC5 vs `EDMV4-26` AC8**: "`--lenses` omitted" means the `edm-state` flag in one and
    the operator's `/edm:code-audit` argument in the other. Under the flag reading the auto-N/A path
    is dead code, because `skills/code-audit/SKILL.md:40-42` mandates Step 4 always pass `--lenses`.

### Factual errors in file paths and premises (6 findings)

25. **`agents/edm-audit-tests.md` does not exist.** The L4 lens file is
    `agents/edm-audit-test-quality.md`. `EDMV4-29` AC5 and its Target Components both name the
    non-existent path; AC8's smoke assertion would target a file that cannot be created without
    inventing a twelfth lens.
26. **`EDMV4-50`'s Target Components name `wave7-smoke.sh` for the canonical-section assertions.
    They are in `wave6-smoke.sh:4052-4119`.** `wave6-smoke.sh:4055-4058` carries a comment recording
    that **EDMV3-T41's own ticket made this identical wrong citation**.
27. **`EDMV4-48`'s premise that `--mermaid-ratio` can run against a 50-initiative fixture is false.**
    It creates its own scratch tree with exactly one initiative `TIMMR` (`timing.sh:397-400`),
    ignores `DIR` entirely, and its size knobs are `--files`/`--lines-per-file`. `N_INITIATIVES` is
    consumed only by `--generate-fixture:246`. No AC authorizes adding a `--dir` arm.
28. **`EDMV4-44`'s `hooks.json:16-24` precedent is a `command`+`prompt` pair, not two `command`
    entries.** The proposal adds a second `command` to the `Stop` block -- a homogeneous pair with
    **zero in-repo instances**. `architecture.md:130` states the qualifier; the SRD drops it.
    `EDMV4-01`'s experiment must specifically test two `command` entries.
29. **`EDMV4-46` AC7's claim that `SRD/.codemap.md` is covered by `edm-lint-artifacts` is false.**
    Prefix mode resolves one initiative directory; `--all` iterates initiative directories. Only the
    manual `--path` mode reaches the `SRD/` root, and nothing invokes it automatically.
30. **`EDMV4-57` AC1-AC2's ASCII sweep cannot cover shell sources.** `collect_md_files`
    (`bin/edm-lint-artifacts:251-260`) runs `find -name '*.md'`; no `.sh` or extensionless `bin/`
    script is ever collected. AC4's runtime-text requirement has no static mechanism at all.

### Specification quality (10 findings)

31. **`EDMV4-19` claims "no new dialog and no new UI mechanism" but requires one.** The orchestrator
    offers only `mode` values (`skills/orchestrator/SKILL.md:107-108`) and has **no `lifecycle_mode`
    write path at all** (`:111-112`). A `fix-pack` recommendation requires a new dialog option plus a
    new `set-mode ... lifecycle_mode` call.
32. **`EDMV4-19` AC7 vs `EDMV4-20` AC3 disagree on the classifier's output shape** -- three single
    values versus a `(mode, lifecycle_mode)` pair per tier.
33. **`EDMV4-20` AC5 is not mechanically executable**: `set-mode <PREFIX> mode fix-pack` dies
    (`fix-pack` is not in `MODE_ENUM_LIST`) and `set-mode <PREFIX> lifecycle_mode mini-srd` dies.
    The AC never names which `kind` each value is driven through.
34. **`EDMV4-22` AC3's smoke assertion is scoped to fail on correct code** -- it greps the whole tree
    for phrases that legitimately appear in `skills/tickets/SKILL.md` and `skills/srd/SKILL.md` per
    the mode matrix's own "owning phase skill" design.
35. **`EDMV4-26` AC2 requires deterministic L13 stack detection but specifies no mechanism.** The
    criteria are never enumerated and `skills/code-audit/SKILL.md` Step 1 is prose an LLM executes.
    This determination gates `round_type=full`, which gates convergence and archive -- a
    non-deterministic input to a convergence gate. Either enumerate file markers, or move detection
    into a deterministic `edm-state` helper.
36. **`EDMV4-13` AC1 cannot be verified at its own completion** -- it asserts `edm-gateguard` and
    `edm-hookify` source the new library, neither of which exists when `EDMV4-13` lands. It also
    contradicts `architecture.md:213`, which omits `_edm-datadir-lib.sh` from `edm-hookify`'s
    dependencies.
37. **`EDMV4-07` AC8 and `EDMV4-11` AC9 contradict on a missing `jq`**, and neither carries AD3's
    qualifier that `jq` is a dependency only after the marker test passes.
38. **`EDMV4-50` AC7 is vacuously satisfiable** -- it requires updating "any smoke assertion counting
    generated sections", and no counting assertion exists. What exists is two named per-section
    presence checks and two byte-identity diffs. The D15 section would ship with zero coverage.
39. **`EDMV4-55` AC5/AC6 and `EDMV4-58` AC7 are untestable as written** -- an "or the deviation is
    documented" escape hatch makes AC5 unfalsifiable; AC6 requires bash 3.2 with no acquisition path
    named; AC7 requires a Linux run with no environment named and no CI pipeline.
40. **`EDMV4-56` AC1 vs AC2 conflict on `perl`.** `timing.sh` invokes `perl` at `:59-60` and
    `:75-76`, and `EDMV4-47` AC4 modifies that file. AC2 phrases the carve-out as a hypothesis when
    it is a verified fact.

### Feature gaps (5 findings)

41. **AD4 is omitted from Sec.5.1's architecture-decision table** while `EDMV4-01` is written
    against it and its AC4 tests "AD4's chosen `Stop` design". The lead-in says "plus four others".
42. **5.2 specifies the scorecard's shape completely and its content not at all.** No requirement
    names a single category, check, point value or conditional marker. A ticket writer cannot derive
    the check table.
43. **`EDMV4-55`'s bash-4 construct ban is already implemented tree-wide and is neither cited nor
    extended** -- `wave7-smoke.sh:1083` (`T61_BASH4_RE`), `:512-535`, `:649`, `:2539-2541`,
    `harness-smoke.sh:245`. The new ACs are *weaker* than the existing assertions.
44. **Prefix resolution for the Stop gate is unspecified**, and `edm-state validate` requires a
    `<PREFIX>` the Stop hook does not have (`bin/edm-state:4037`). Neither requirement states the
    multi-initiative rule. Also unspecified: whether `info`-class anomalies print at every `Stop`,
    which would be a significant noise regression (`PERM_RULES_MISSING`, one `ACTIVE_EXEMPTION` per
    skipped phase, `SIZE_UNKNOWN`, `SCHEMA_VERSION_MISSING`).
45. **`EDMV4-41` AC5 offers `timeout(1)` as an option; it is not in the required-binary set and is
    absent on stock macOS.**

---

## P2 -- Minor

Forty-seven findings, remediated before convergence rather than before Gate 2. Summarized by class;
full detail is preserved in the three auditor transcripts.

| Class | Count | Representative examples |
|---|---|---|
| Stale line citations | 12 | Every `CLAUDE.md`/`README.md` cite in the lens sweep is stale by 4-7 lines (`:211`->`:217`, `:250`->`:256`, `:292`->`:298`, `:333`->`:339`, `:1000`->`:1007`; `README.md:265,268`->`:269,272`). Most dangerous: `EDMV4-33`'s **do-not-touch list** keys the Mermaid sentence to `CLAUDE.md:292`, now a different line. Key that list to strings, not line numbers. Also `CHANGELOG.md:382` -> `:393,433`; `CLAUDE.md:71` -> `:77-78`; `hooks.json:2` -> `:3` |
| Miscounts | 8 | Revision History says 57 requirements and `D1-D12` (actual 58, `D1-D13`) and cites a licence precondition that D13 removed; "eight enum values" is 8 entries but 7 distinct strings (`standard` appears in both lists); exact-integer set is 10 tree-wide, not 9 (`wave7` 9 + `edm-state:1615`); `CHANGELOG` mentions are 12, not 14; `EDMV4-31` says "twelve places", enumerates 14 |
| Untestable ACs | 9 | `EDMV4-27` AC3 ("most explicitly"), AC6 (no-copy with no mechanism), AC7 (unfalsifiable length rule); `EDMV4-37` AC3 binds hypothetical future work; `EDMV4-46` AC4 asserts unobservable future-initiative behaviour |
| Unswept sites | 7 | Fixture README `:21,26,28` (only `:33` named); `skills/code-audit/SKILL.md:81`, `:148`; synthesizer's `lenses-run.txt` reader at `:205` |
| Convention conflicts | 6 | `edm-repo-readiness` (2=usage) vs `edm-hookify` (2=block) pick opposite exit conventions in one initiative; `EDMV4-56` AC1's "POSIX coreutils" is imprecise -- `stat` is not POSIX and its flags differ BSD/GNU, `flock` is util-linux-only |
| Provenance gaps | 3 | Only `EDMV4-27` carries a no-copy clause; L13 and L14 take ECC taxonomies with no equivalent, and none of the three records source/licence/verification per D13 |
| Misc | 2 | `EDMV4-58` AC1 omits `_PREFERRED_ORDER` registration, so `wave8-smoke.sh` is unprotected by the tripwire; AC6's clean-tree invariant conflicts with `wave6-smoke.sh:4090`'s deliberate mutation of a tracked file |

---

## NOTED -- Intentional / Pre-existing

1. **The D2 guard is correctly and explicitly defended.** `EDMV4-28` forbids the cost reading, AC3
   requires the agent to state cost is never a reason with a grep assertion, and `EDMV4-23` AC4
   requires the same in `CONDITIONAL_LENS_IDS`'s comment. No cost-based justification for L13's
   conditionality appears anywhere in 6.5.
2. **D7 (JSON, not YAML) is honoured exactly.** `EDMV4-40` AC1 forbids adding a YAML-capable binary;
   no YAML requirement appears anywhere in 6.7.
3. **`EDMV4-45`'s `OPEN_PARTIALS` claim is correct** -- blocking at `bin/edm-state:1827-1847`, with
   `archive`'s independent refusal at `:3250-3262`. 5.4 is genuinely a timing improvement.
4. **The 5.4 descope premise is factually grounded.** The complete anomaly set was read in full
   (`:1709-1928`); there is no "phase started with no `completed_at`" anomaly.
5. **`EDMV4-52` closes as verification, not a fix**, and its AC6 ("A ticket that 'fixes'
   already-correct code is a defect in the ticket") is exactly right.
6. **`EDMV4-53` declines API spend** deliberately per D9, correctly recorded as a boundary.
7. **Sec.12.2's critical path is plain ASCII, not Mermaid** -- an SRD is not a ticket pack.
8. **Section 5 discipline is correct** -- zero Mermaid fences, names `architecture.md` as canonical.
9. **The SRD does not assume Spike B's outcome** -- `EDMV4-09` AC6 makes the default a product of
   `EDMV4-02`'s recorded decision.
10. **The inherited ticket-ID constraint is properly binding** -- `EDMV4-04` pins each of T01/T04/T05,
    bans T02/T03, requires new tickets from T06, and requires the gap be documented.
11. **`CLAUDE.md Sec."Unverifiable acceptance criteria (D15)"` is cited as change-control authority
    for SRD-level scope reductions.** That section is scoped to unverifiable ACs on tickets, not to
    reductions against Gate-1-approved SRD scope. The extension is a reasonable analogy and the
    substantive obligation is right, but no canonical section covers this case. Worth opening as a
    convention gap, not an EDMV4 defect.

---

## Diagram Errors -- none found

All three auditors report the same: the SRD body contains **zero Mermaid or PlantUML diagrams** by
design, so `Sec."Mermaid diagram conventions (canonical)"` is not exercised anywhere in it. The only
fenced block is Sec.12.2's plain-text critical path.

`architecture.md`'s four diagrams were **not linted by any auditor** -- they fell outside all three
assigned scopes. Group A flagged `architecture.md:342` and `:350` as unquoted `sequenceDiagram`
message text, the exposure class the convention specifically warns about, but did not check every
line. `edm-lint-artifacts` reports the initiative CLEAN, which covers the semicolon class
mechanically, so this is a low residual risk rather than an open one.

---

## Verified CORRECT

Recorded because a reader might reasonably doubt them, and a clean verification has value.

- **58 requirements, `EDMV4-01`..`EDMV4-58`, no gaps, no duplicates. 41 Must / 16 Should / 1 Could.**
  Counted independently by Group C; Sec.12's Should-Have ID list matches element-for-element and
  Sec.12.1's per-scope rows sum correctly.
- **T04's "14 files" has not drifted since `bdec805`** -- re-derived independently: 9 skills carry a
  bare citation, 18 agents of which 13 are already anchored, leaving 5. 5 + 9 = 14.
- **`update-patterns`: `bin/edm-state:5595` and `:5627-5629` are exact**, and the six call sites are
  confirmed at their cited lines. The stale in-code "four skills" comment is at `:5672` as stated.
- **`${CLAUDE_PLUGIN_DATA}` has zero consumers in `bin/`** -- one prose hit in `CLAUDE.md` only. The
  SRD consistently and correctly says "the first consumer".
- **The enum backstop is sound** -- `MODE_ENUM_LIST`/`LIFECYCLE_MODE_ENUM_LIST` at `:807-808`,
  validated at `:5071-5074` and `:5093-5096`, both hard `die`s.
- **`EDMV4-52`'s regression premise is fully verified** -- CA-532 fixed (`run-eval.sh:420-421`,
  `:460-461`), CA-490 fixed (`edm-compare-eval:62-81`), `scores.json` genuinely absent, no
  `.gitlab-ci.yml`, so CA-537 is moot.
- **The house-lens contract is accurate in every particular**, checked field-by-field against
  `agents/edm-audit-logic.md` (115 lines).
- **`EDMV4-26` AC7's parsing-safety claim is correct** -- `^L[0-9]+$` at `bin/edm-state:4664` cannot
  match a `Lenses N/A:` header, and `SKILL.md:78`'s existing `Round type:` header is the precedent.
- **Both MIT licences verified by direct inspection** -- ECC root (Affaan Mustafa 2026) and
  `zunoworks/gateguard` (Hirokazu Seto / ZUNO WORKS K.K. 2026).
- **D12 corrections spot-checked (3 of 11), all correct** -- ECC has 23 registrations across 7
  events; the seven security triggers are at `orch-pipeline/SKILL.md:100-104` and
  `rules/common/security.md` holds an unrelated 8-item checklist.
- **`EDMV4-05` is structurally not buried** -- standalone Must Have with a Gate-2 presentation AC,
  cross-referenced from five places. The two P1s against it concern the *content* of that
  presentation, not its existence.

---

## Coverage Boundary -- what this audit did NOT check

Stated explicitly so no reader mistakes silence for a clean result.

- **`architecture.md` was read in full by only one auditor** and linted for Mermaid violations by
  none. Its four diagrams are unaudited beyond the mechanical semicolon class.
- **`planning.md` was not opened by any auditor.** Its "Decisions Made" and "What Phase 1 Changed"
  sections are binding per `srd.md:28`; drift between them and Sec.2/3.2/3.3 is unaudited.
- **8 of the 11 D12 corrections are unverified.** Only corrections 1, 2 and 8 were spot-checked.
- **Most ECC source citations are unverified.** The five silent-failure categories, four type-design
  dimensions, six hookify operators, `harness-audit.js` scoring internals, `generate.ts` templates,
  and `quality-gate.py` exit contract were all taken on the SRD's word.
- **No test suite or linter was executed by any auditor.** No `run-all.sh`, no
  `edm-sync-canonical-sections --check`, no `timing.sh --mermaid-ratio`. All harness claims are from
  source reading.
- **Testability sweeps are partial in all three scopes.** Group A did not systematically sweep
  `EDMV4-08`, `-10`, `-11`, `-12`, `-14`, `-16`, `-17`, `-18`; Group B did not sweep `EDMV4-33`,
  `-34`, `-35`, `-38`, `-39`, `-40`, `-43`, `-44`; Group C did not cross-check Sec.7-8's requirement
  IDs, which given the confirmed Sec.4.6 off-by-one **should be re-verified ID by ID before
  Phase 4**.
- **Reuse Opportunities is thinly covered.** Group A reports no findings in that category but
  attributes this to incomplete search, not a clean result.
- **Accessibility, i18n and backward-compatibility were not assessed as categories.**

---

## Process Findings (about the methodology, not this SRD)

1. **`edm-srd-auditor`'s 25-turn ceiling does not scale to a Large SRD.** All three auditors hit it
   before emitting any findings, at 45-55 tool uses each, and all three required a resume message
   to produce output. A 2,772-line SRD split three ways with ~10 verification items per auditor
   exceeds the budget. Candidate remedies: raise `maxTurns` for the auditor agent, split a Large
   SRD across more than three auditors, or have the dispatching skill pre-verify cheap factual
   claims (which is what happened here on resume, and it worked).
2. **The orchestrator pre-verifying claims materially improved auditor output.** Groups B and C were
   resumed with ground-truth blocks covering their cheapest checks, which freed their remaining
   turns for judgment work -- and Group B's two P0s came from that freed budget.
3. **Line-number citations in this plugin's own documents go stale fast.** This audit found stale
   cites in the source analysis, in two explorer reports, in the SRD, and in `architecture.md` --
   including `CLAUDE.md` line numbers that moved twice during this initiative. `EDMV3-T41`'s own
   ticket made the same class of error (recorded at `wave6-smoke.sh:4055-4058`), and CA-464 already
   retired one line-range citation for going stale twice. **Recommendation for the pattern library:
   key do-not-touch lists and cross-document references to strings, not line numbers.**

---

## Machine-readable findings (harvest shape)

One line per novel finding class, in the `pattern_extract_titles` shape documented at
`docs/audit-patterns/README.md Sec."Append Schema"` -- `[CATEGORY] [SEVERITY] Section | Finding |
Recommendation`, three pipe-separated fields. The prose sections above remain the authoritative
record; this block exists so `edm-state update-patterns` can harvest the classes worth teaching
forward, rather than reporting `no-recognized-findings`.

[COMPETING REQUIREMENTS] [P0] Sec.6.3 | A constraint spanning two requirements was written as a peer dependency of both, creating a cycle that dependency-ordered wave scheduling cannot resolve, and the constraint is the element most likely to be silently dropped when a tool breaks the cycle | Write a cross-cutting constraint as an AC block inside one requirement, never as a mutual dependency between the requirements it constrains; six cycles of this exact shape appeared in one SRD
[COMPETING REQUIREMENTS] [P0] Sec.6.5 | A replacement derivation was specified unconditionally against a function that has two branches, so the branch the spec did not consider inverts its result and every default invocation returns the opposite verdict | State a replacement derivation per-branch against the live control flow, and assert the unchanged branch explicitly rather than assuming it
[FEATURE GAP] [P0] Sec.6.5 | A completeness gate was re-pointed from a manifest to a state field that is empty in the default case, making the gate vacuous for exactly the incident that motivated building it | When moving a check's source of truth, verify the new source is populated in every path the old source covered, especially the default path
[FACTUAL MISTAKE] [P0] Sec.4.6 | An SRD premise describing repository state went stale mid-phase when the branch it described was updated underneath the document | Re-verify environment-describing claims at audit time rather than authoring time, and cite the decision record rather than restating its content
[SPECIFICATION QUALITY] [P1] Sec.6.11 | An acceptance criterion required updating a counting assertion that does not exist, making it vacuously satisfiable -- an implementer finds nothing to change, ticks the box, and the new surface ships with zero coverage | Name the concrete assertion to add by file and line rather than describing a class of assertion to update
[FACTUAL MISTAKE] [P1] Sec.6.14 | A lint sweep was cited as covering shell scripts, but the collector globs only markdown, so no script was ever scanned by the mechanism the AC named | Verify a cited enforcement mechanism actually reaches the file types the requirement claims, by reading the collector rather than trusting the invocation name
[FACTUAL MISTAKE] [P1] Sec.6.8 | A design cited an in-repo precedent that on inspection had different element types than the shape being proposed, so the claimed precedent did not support the design | Quote the precedent's actual shape when citing it; a structurally similar instance is not a precedent for a different composition
[TEST QUALITY] [P1] Sec.6.5 | An anti-regression assertion counts a hardcoded name list rather than the live set, so it stays green while newly added members silently escape the property it exists to enforce | Derive every count assertion from the live set it guards; a hardcoded list makes the assertion blind to exactly the change it should catch
[ADDITIONAL CONCERNS] [P1] Sec.7.3 | A dormant licence obligation was wired to the wrong ratification decision, so approving the named requirement while separately reversing the underlying architecture decision would leave the obligation dormant | Wire a conditional obligation to the decision it actually depends on, and ensure that decision has a requirement that presents it for ratification
[SPECIFICATION QUALITY] [P2] Sec.6.5 | Cross-document references keyed to line numbers went stale four to seven lines within a single initiative because the target file was edited mid-flight, including a do-not-touch list that then pointed at unrelated text | Key do-not-touch lists and cross-document references to quoted strings rather than line numbers; line citations in a living document have a short half-life
[TEST QUALITY] [P1] Process | A read-only verifier agent's turn budget sits below the producer agent whose output it checks, so on a large artifact it truncates before emitting findings, and a hook-spawned verifier's partial output is merged as if complete | Budget verifiers at or above the producers they check, and require every verifier to emit a self-describing completion sentinel that the consumer refuses to merge without

## Remediation

Applied to the SRD before Gate 2. Version bumped 1.0.0 -> 1.1.0.

See the Revision History in `srd.md` Sec.1 for the applied change list.
