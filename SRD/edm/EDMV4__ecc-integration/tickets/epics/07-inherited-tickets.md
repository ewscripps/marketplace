# Epic 07: Inherited Tickets

This epic carries the three ticket IDs EDMV4 inherited from the named-but-never-created
`EDMV4__lint-and-pipeline-budgets` pack, plus the D12 source-document correction. **`EDMV4-T01`,
`EDMV4-T04` and `EDMV4-T05` are pre-claimed with fixed meanings** assigned by EDMV3's
`decisions.md` (D29, D34, D62) and cited by ID in `plugins/edm/CLAUDE.md:352` and in EDMV3's
archived ticket coverage map -- each covers its inherited scope and nothing else, and no new work
may drift into them. **`EDMV4-T02` and `EDMV4-T03` were closed inside EDMV3 and are retired**: they
must never be reused, because reusing them would make two different pieces of work share one ID
across the archived and the live ledgers. **The numbering gap between `T01` and `T04` is therefore
correct and intentional** -- a later reader must not "fix" it. New tickets in this pack are
numbered from `EDMV4-T06` upward; `EDMV4-T49` below is one of those, and is grouped here because
D12's source-document correction is the fourth piece of standalone, dependency-free cleanup this
epic exists to hold. All four tickets depend on nothing and can start on day one. `EDMV4-T01` is
one of the initiative's three named quick wins (SRD Sec.12.2); `EDMV4-T04` is unblocked but
explicitly **not** a quick win -- it is a three-requirement chain whose middle link must enumerate
and resolve every orphaned citation before any anchoring happens.


> **Line numbers in this epic are ADVISORY (ticket-pack audit P1-2).** Every `file:line` citation
> here -- including the "stale SRD citations, corrected" tables in the Technical Notes below -- was
> verified against the **pre-fast-forward** tree. The fast-forward's `6e29dcb` re-inserted four
> lines at `bin/edm-state:504-507`, so this epic's corrections are now wrong where the SRD is
> right: `ALL_LENS_IDS` is at **1613**, `MODE_ENUM_LIST` at **807**, `state_anomalies()` at
> **1709**. Symbols above line 4000 have drifted further than either document.
>
> **Locate every site by symbol name or by the literal string the AC quotes, at edit time.** Do not
> "correct" `srd.md` toward any number in this pack -- see `EDMV4-T08` AC8.

---

## EDMV4-T01: Re-derive the Mermaid lint budget as an absolute ceiling plus a sized ratio

| Field | Value |
|---|---|
| Epic | Inherited Tickets |
| Phase | 1 |
| Priority | Should Have |
| Size | S |
| SRD Refs | EDMV4-47, EDMV4-48 |
| Depends On | none |
| Target Components | plugins/edm/bin/tests/timing.sh (`--mermaid-ratio` at `:386-428`, the printed budget at `:426`, the UNMEASURABLE refusal at `:419-423`, `N_FILES`/`N_LINES_PER_FILE` at `:219-220`, `N_INITIATIVES` at `:217`, `--generate-fixture` at `:239-253`, `--all-lint`'s `--dir` resolver at `:438-439`, `_P95_SAMPLE_COUNT`, `--self-test`), plugins/edm/CLAUDE.md Sec."edm-lint-artifacts latency budgets (EDMV3-T67 AC5/AC7)", plugins/edm/CHANGELOG.md:393,433-450, plugins/edm/bin/edm-lint-artifacts:214-248 (`mermaid_scan_awk`, the code being measured), :225-246 (`_MSA_PROG_CACHE`, the CA-472 fd-leak fix) |

### Description

This is the inherited `EDMV4-T01`, claimed in EDMV3's `decisions.md` D29 as "re-derive the
Mermaid-class `edm-lint-artifacts` budget as an absolute ceiling plus a sized ratio". Phase 1
verified that most of the work the inherited ticket assumed was outstanding already exists: the
50-initiative fixture generator (`timing.sh --generate-fixture`, `N_INITIATIVES=50` at `:217`), and
the `--lint`, `--all-lint` and `--mermaid-ratio` modes, all against the post-`ea31ce8`
one-awk-per-file class-4 scan. What actually remains is a **budget framing fix plus one honest
re-measurement**, and the ticket is scoped to exactly that.

The defect is in the budget's shape, not its number. `plugins/edm/CHANGELOG.md:433-441` states the
objection precisely: a bare ratio with no stated input size and no absolute floor is dominated by
fixed process overhead, so it reads differently on every machine and it moves when unrelated code
gets faster. That happened twice, in both directions: the AC5 rewrite (`d591b92`) made the baseline
roughly 40x faster without touching the Mermaid class and the ratio got **worse**, 2.26x to 3.40x,
because class 4 became the dominant cost rather than a marginal one; optimizing class 4 (`ea31ce8`)
then brought it to 1.12x. The same budget read miss, worse-miss, then pass across three commits,
only one of which touched the code it measures. Independently, the recorded 2.26x "was taken on a
5-file fixture", so the original figure never answered the AC either way -- which is why the AC6 row
at `:393` reads "PASS on the number" rather than PASS.

The second requirement carries a trap the ticket resolves explicitly rather than leaving a
developer to discover: **`--mermaid-ratio` cannot be pointed at the 50-initiative fixture as it
stands.** The mode builds its own scratch tree containing exactly one initiative, `TIMMR`
(`timing.sh:397-400`), and **ignores `--dir` entirely**; its size knobs are `--files`
(`N_FILES=30`) and `--lines-per-file` (`N_LINES_PER_FILE=333`), giving 30 files / 9,990 lines.
`N_INITIATIVES=50` is consumed only by `--generate-fixture` at `:246`, a different mode.

### Acceptance Criteria

- [ ] AC1: The Mermaid-class budget is restated in `plugins/edm/CLAUDE.md Sec."edm-lint-artifacts latency budgets (EDMV3-T67 AC5/AC7)"` as a **conditional** -- an absolute millisecond ceiling plus a ratio that binds only above a stated input-size floor -- and is quoted together with its input size, with the floor expressed in **both** files and lines. A bare ratio does not survive this change.
- [ ] AC2: The absolute floor below which the ratio does not bind is stated numerically, with one sentence naming why (fixed process overhead dominates below it).
- [ ] AC3: The latency-budget table in that section gains or amends a Mermaid row using the **same column shape the two existing rows use** -- verified in the tree as five columns: `Budget | Invocation | Ceiling | Fixture the ceiling is stated against | Where it binds`. (The SRD's "three-column form" phrasing names the three load-bearing cells, not the literal column count.)
- [ ] AC4: **The fixture question is settled before any measurement, and the choice is recorded.** Exactly one of: **(a)** `--mermaid-ratio` gains a `--dir` arm reusing `--all-lint`'s existing resolver (`export EDM_SRD_ROOT="${DIR}/SRD"`, `timing.sh:438-439`) and appends its mermaid fences into that tree instead of building `TIMMR`, carrying the same `[[ -n "$DIR" ]]` usage guard and the same measure-what-is-there discipline `--all-lint` uses to avoid misreporting fixture size (CA-073); or **(b)** the 50-initiative framing is **dropped** and the budget is stated against `--mermaid-ratio`'s real fixture -- 30 files / 9,990 lines, single initiative, 20-sample nearest-rank p95. **Option (b) is the default.** Whichever is chosen, SRD Sec.9.1's fixture column is corrected to match.
- [ ] AC5: `timing.sh:426`'s printed budget line emits the new conditional form. The literal string `(budget: <= 1.40x)` no longer appears in the file (`grep -n 'budget: <= 1.40x' plugins/edm/bin/tests/timing.sh` returns nothing).
- [ ] AC6: The `ratio=UNMEASURABLE` refusal at `timing.sh:419-423` (the G37/CA-197 fix that refuses rather than reporting a fabricated ratio when either p95 measures 0 ms) is preserved **unchanged** -- `git diff` shows no edit inside that block, and its `exit 3` arm still fires when `--files 1 --lines-per-file 1` drives both p95 figures to 0 ms on a fast host.
- [ ] AC7: `bash plugins/edm/bin/tests/timing.sh --mermaid-ratio` is re-run against the fixture AC4 settled on, and the new figure is recorded **together with that fixture's size in files and lines**.
- [ ] AC8: The re-measurement uses the 20-sample nearest-rank p95 harness (`_P95_SAMPLE_COUNT`), not a smaller sample count. `N=20` is the smallest count where `ceil(0.95*20)=19 < 20`, making `p95_ms` a real 95th-percentile figure rather than a relabeled maximum.
- [ ] AC9: The re-measurement states in writing whether the 1.12x figure is still current after the D4 `plugin.json` reconciliation (`EDMV4-03`) and after this initiative's own changes -- confirmed or refuted, not left implicit.
- [ ] AC10: The measured figure is recorded in `CHANGELOG.md` under this initiative's **new** entry (`EDMV4-35`). The historical EDMV3-T67 AC table is not edited: the AC6 row at `:393` is left intact as the record of the miss.
- [ ] AC11: The CHANGELOG note at `:433-450` is updated to record that the re-derivation has landed. The sentence "The re-derivation is the one piece of EDMV3-T67's budget work that remains open" no longer appears in the file. The same update closes Explorer 01's third riskiest assumption explicitly by stating whether the "budget is still malformed" objection had already been addressed elsewhere between that CHANGELOG entry and this initiative, and recording the answer either way.
- [ ] AC12: `bash plugins/edm/bin/tests/timing.sh --self-test` exits 0, including the G35/CA-311 assertion pinning the nearest-rank p95 index; and `git diff --stat plugins/edm/bin/edm-lint-artifacts` is empty across this ticket's commits -- this ticket measures and records, it does not optimize.

### Technical Notes

- **Priority derivation.** Both requirements this ticket carries (`EDMV4-47`, `EDMV4-48`) are
  **Should Have** in the SRD, so the ticket takes Should Have as the highest priority among them.
  This is the only ticket in the epic that is not Must Have; the other three carry Must Have
  requirements exclusively. The two requirements do not differ from each other in priority.
- **This ticket does need new harness code**, contrary to a claim SRD v1.0.0 made about the
  inherited T01/T05 pair. AC5 rewrites `timing.sh`'s printed budget line, and AC4 either adds a
  `--dir` arm or restates the budget against the mode's real fixture. Only `EDMV4-T05` is
  code-free.
- **Verify the assertion exists before writing an AC against it.** The SRD audit found an AC in
  this area that was vacuously satisfiable because it required updating a counting assertion that
  does not exist. Every AC above names a line, a string or a command that was checked against this
  branch's tree while this ticket was written. Re-check before implementing -- these are
  `file:line` citations, and the class of defect `EDMV4-51` exists to fix is exactly citations
  going stale.
- **Verified against the current tree**: `timing.sh:217` (`N_INITIATIVES=50`), `:219-220`
  (`N_FILES=30`, `N_LINES_PER_FILE=333`), `:246` (the only consumer of `N_INITIATIVES`),
  `:397-400` (the `TIMMR` scratch tree built from `TMP_MR`, with `DIR` never read),
  `:419-423` (the UNMEASURABLE refusal and its `exit 3`), `:426` (the bare `(budget: <= 1.40x)`),
  `:438-439` (`--all-lint`'s `[[ -n "$DIR" ]]` guard and `EDM_SRD_ROOT` export),
  `CHANGELOG.md:393` (the AC6 row) and `:433-450` (the malformed-budget note).
- **Two budgets, never interchangeable.** `CLAUDE.md` already documents the commit-path budget
  (3,000 ms p95 against one initiative directory of 30 `.md` files / 9,990 lines) and the
  full-repo sweep (60,000 ms against a 50-initiative repository), with the standing rule "always
  quote a budget together with its input size". The Mermaid row must read the same way. Note that
  the commit-path fixture and `--mermaid-ratio`'s own fixture happen to be the same size -- that
  coincidence is what makes option (b) in AC4 the cheap and honest choice.

### Out of Scope

- **Any optimization of `bin/edm-lint-artifacts`.** If the re-derived budget is missed, that is a
  recorded miss for its own follow-on, matching EDMV3-T67's own Out of Scope discipline.
- The commit-path (3,000 ms) and full-repo-sweep (60,000 ms) budgets themselves. Only the Mermaid
  row is re-derived.
- **Nothing from any other requirement may drift into this pre-claimed ID.** `EDMV4-T01` covers
  `EDMV4-47` and `EDMV4-48` and nothing else. In particular it does not carry the `--all-lint`
  work, the ASCII sweep (`EDMV4-57`), the bash-3.2 floor (`EDMV4-55`), or the `plugin.json`
  reconciliation (`EDMV4-03`), all of which touch neighbouring files.
- Rewriting the historical EDMV3-T67 AC table. AC10 and AC11 add to the record; they never edit
  the miss out of it.

---

## EDMV4-T04: Anchor all 14 by-name reference files, after enumerating and resolving every orphan

| Field | Value |
|---|---|
| Epic | Inherited Tickets |
| Phase | 1 |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV4-49, EDMV4-50, EDMV4-51 |
| Depends On | none |
| Target Components | plugins/edm/agents/edm-architect.md, plugins/edm/agents/edm-srd-writer.md, plugins/edm/agents/edm-ticket-writer.md, plugins/edm/agents/edm-ticket-auditor.md, plugins/edm/agents/edm-qc-auditor.md, plugins/edm/skills/srd/SKILL.md, plugins/edm/skills/tickets/SKILL.md, plugins/edm/skills/audit-srd/SKILL.md, plugins/edm/skills/audit-tickets/SKILL.md, plugins/edm/skills/verify-runtime/SKILL.md, plugins/edm/skills/push-jira/SKILL.md, plugins/edm/skills/orchestrator/SKILL.md, plugins/edm/skills/metrics/SKILL.md, plugins/edm/skills/code-audit/SKILL.md, plugins/edm/agents/edm-audit-logic.md:69 and plugins/edm/agents/edm-srd-auditor.md:38-42 (the two verbatim pattern exemplars), plugins/edm/bin/edm-sync-canonical-sections (`extract_section` at `:72-79`, the generation block at `:100-113`), plugins/edm/docs/canonical-sections.md, plugins/edm/CLAUDE.md Sec."By-name reference resolution from an installed plugin cache (EDMV3-T41)" (the D34 passage at `:333-353`), plugins/edm/CLAUDE.md:24 (`Skill-tool composition`, bold inline text and not a heading), plugins/edm/bin/edm-check-grants, plugins/edm/bin/tests/wave6-smoke.sh:4052-4119, SRD/edm/EDMV4__ecc-integration/decisions.md |

### Description

This is the inherited `EDMV4-T04`, claimed in EDMV3's `decisions.md` D34 and named directly in
`plugins/edm/CLAUDE.md:351-353` as "the residual scope opened as a named follow-on ticket". D22
verified against Claude Code 2.1.220 that a bare `` CLAUDE.md Sec."..." `` reference in a prompt
**does not resolve** from an installed plugin cache: plugin-root `CLAUDE.md` is never loaded as
runtime context, and an installed cache directory is not path-adjacent to the project it is
installed into, so the reference either fails to resolve or silently resolves to the target
project's own unrelated `CLAUDE.md`. D34 anchored thirteen files (the eleven lenses, the
synthesizer, and `edm-srd-auditor`) and left the rest.

**The scope is 14 files, not the eight `CLAUDE.md` names.** Per decision D10 the verified
unanchored set is 5 agents + 9 skills: `CLAUDE.md`'s own list misses `edm-qc-auditor.md`,
`verify-runtime/`, `push-jira/`, `orchestrator/`, `metrics/` and `code-audit/SKILL.md`, all
carrying the identical D22 defect. A ticket scoped to the named eight under-delivers against what
"close the ordering gap" actually requires.

**The ticket has a mandatory internal ordering, and it is the inverse of SRD v1.0.0's.** The
sequence is `EDMV4-50` (add the third canonical section) -> `EDMV4-51` (enumerate every orphaned
citation) -> `EDMV4-49` (anchor all 14 files). The SRD audit raised `EDMV4-51` from Should Have to
Must Have (P0-3) precisely because it gates whether the other two can be executed correctly at all.
An orphaned citation is one whose named section has no `docs/canonical-sections.md` mirror;
anchoring one produces a reference that resolves to a document lacking the section -- **worse than
the bare form, because it looks fixed**, and the reader who follows it has no reason to suspect the
anchor rather than their own search. Five of the 14 files carry orphaned citations at 8 sites
naming 6 distinct sections. Executed in v1.0.0's order, the Must-Have pair would anchor four skills
to six sections of which only one exists, and the sweep that would have caught it runs afterwards,
if at all, being lower priority. **Orphan enumeration completes first.**

### Acceptance Criteria

- [ ] AC1: **The mandatory order is honoured and visible.** `EDMV4-50`'s generator change lands first, `EDMV4-51`'s enumeration second, `EDMV4-49`'s anchoring third; `git log --oneline` for this ticket shows that sequence. **No file is anchored until every section it cites is known to resolve** -- no anchoring edit is committed before the enumeration is complete and every orphan it found is resolved.
- [ ] AC2: `bin/edm-sync-canonical-sections` generates a **third** section by adding an `extract_section "Unverifiable acceptance criteria (D15)" "$SRC"` call to the generation block at `:100-113`, byte-identical and one-directional exactly as it already does for the other two. The D15 heading string in `CLAUDE.md` is left unchanged, since it is referenced by name.
- [ ] AC3: `docs/canonical-sections.md` is **regenerated by running the script**, never hand-edited. `bash plugins/edm/bin/edm-sync-canonical-sections --check` exits 0 after the regeneration and exits 1 if either file is subsequently edited out of step; **both directions are proven by a smoke case**, not asserted.
- [ ] AC4: The two existing wave6 assertions are extended and a third pair is added, in `bin/tests/wave6-smoke.sh` (**not** `wave7-smoke.sh` -- the comment at `:4055-4058` records that EDMV3-T41's own ticket made this identical wrong citation and a ticket writer following it would have edited the wrong suite): a third presence check asserting `## Unverifiable acceptance criteria (D15)` appears in the generated file, mirroring the form at `:4076-4077`; a third byte-identity diff extracting the D15 span from both `CLAUDE.md` and the generated copy with the same `awk` idiom and asserting they are identical, mirroring `:4115-4119`; and one further presence-plus-diff pair per section added by an AC7 route-1 resolution.
- [ ] AC5: **Every distinct section name cited under `skills/` and `agents/` is enumerated, with every site of each, not one row per file.** The sweep must catch **three citation shapes**, since a single grep for `` `CLAUDE.md Sec\." `` misses two of them: (i) the backticked form; (ii) the unbackticked form (`skills/srd/SKILL.md:182`); (iii) bare `Sec."..."` sentence continuations -- `skills/orchestrator/SKILL.md:200` carries two of these (`Phase Timing Guidelines` and `EDM mode matrix`) that a `CLAUDE.md`-prefixed grep does not match at all.
- [ ] AC6: Each cited name is cross-checked against `docs/canonical-sections.md`'s generated section list **by exact string**, since `extract_section` (`bin/edm-sync-canonical-sections:72-79`) matches `"## ${heading}"` exactly and a near-match is an orphan. The two already-shipped sections are generated under the headings `## Severity vocabulary (canonical)` and `## Mermaid diagram conventions (canonical)` while every citation omits the `(canonical)` suffix; that prefix-versus-exact case is **classified deliberately and recorded** -- neither silently exempted nor mass-flagged as orphans.
- [ ] AC7: Every orphan is resolved by one of the **three** named routes, chosen deliberately per case and **recorded per case in `decisions.md`**: (1) **add to the generator**, available when the cited name matches a `##` heading exactly -- covers D15, `Project artifact layout` and `Optional: Jira synchronization`; (2) **heading mismatch** (`EDM mode matrix`, `Phase Timing Guidelines`, whose real headings carry an `(EDMV3-T38)` suffix) -- default route (a), update the citing sites to the real heading including its suffix then add that exact string to the generator; route (b), renaming the `CLAUDE.md` heading, requires updating every reference in the same commit and needs a stated reason; (3) **not a heading** (`Skill-tool composition`, bold inline text at `CLAUDE.md:24`) -- either promote it to a real `##` heading and add it to the generator, or inline the rule at the three citation sites and drop the `Sec."..."` form. No orphan is left anchored-but-unresolvable.
- [ ] AC8: The enumeration is **recorded in `decisions.md`** so the sweep is auditable and does not have to be re-derived, and it **reconciles against `EDMV4-50`'s 8-site / 6-section table**. Any orphan found here and absent from that table is added to it and the discrepancy is recorded rather than silently absorbed.
- [ ] AC9: **All 14 files are anchored, at every citation site, not one per file**: `agents/edm-architect.md` (`:31`, `:89`), `agents/edm-srd-writer.md` (`:36`, `:85`), `agents/edm-ticket-writer.md` (`:44`, `:104`), `agents/edm-ticket-auditor.md` (`:63`, `:81`, `:134`), `agents/edm-qc-auditor.md` (`:39`, `:70`), `skills/srd/SKILL.md` (`:80`, `:182`), `skills/tickets/SKILL.md` (`:54`), `skills/audit-srd/SKILL.md` (`:68`, `:85`), `skills/audit-tickets/SKILL.md` (`:85`, `:97`), `skills/verify-runtime/SKILL.md` (`:31`, `:39`, `:147`), `skills/push-jira/SKILL.md` (`:36`), `skills/orchestrator/SKILL.md` (`:28`, `:113`, `:152`, `:196`, `:199`, `:200`), `skills/metrics/SKILL.md` (`:74`), `skills/code-audit/SKILL.md` (`:389`, `:393`). This includes **all four D15 sites** (`edm-qc-auditor.md:39` plus `verify-runtime/SKILL.md:31`, `:39`, `:147`, all resolved at once by AC2's generator addition) and `edm-qc-auditor.md:70`'s Severity citation in the same pass. The site count reconciles against AC5's enumeration; 31 sites were verified on this branch (see Technical Notes) and any divergence is recorded, not absorbed.
- [ ] AC10: The pattern applied is **exactly** the one already in use, verified identical at `edm-audit-logic.md:69`, `edm-audit-security.md:154-157`, `edm-audit-synthesizer.md:87` and `edm-srd-auditor.md:38-42`: **keep** the original citation and **append** the `Read docs/canonical-sections.md` sentence immediately after it, carrying the qualifier "resolved relative to the EDM plugin's own root -- `plugins/edm/` in this repository, or the installed plugin's cache root, never the caller's cwd" verbatim. **The original citation is never deleted** -- it still resolves for a human reading the file in-repo, a different and still-valid audience.
- [ ] AC11: `bin/edm-check-grants` gains **one check with two failure modes**, so neither half of the class can regress: (i) it exits 1 on any file under `skills/` or `agents/` carrying a bare `Sec."..."` citation with no adjacent canonical-sections anchor; (ii) it exits 1 on any anchored citation whose named section does not exist in `docs/canonical-sections.md`. **Both are proven to discriminate by positive controls** -- a scratch copy carrying a bare citation, and a scratch copy anchored to a deliberately nonexistent section name, each making `edm-check-grants` exit 1 while the clean tree exits 0. `bash plugins/edm/bin/tests/run-all.sh` exits 0 (it already invokes `edm-check-grants` as a standalone check at `run-all.sh:192-193`).
- [ ] AC12: After the change, a grep across `skills/` and `agents/` returns **only anchored sites, and every anchored site's named section exists in `docs/canonical-sections.md`** -- the first clause alone is satisfiable by anchoring four skills to sections that do not exist, which is exactly what v1.0.0's ordering would have produced. In the same pass, `plugins/edm/CLAUDE.md`'s D34 passage (`:333-353`) replaces the eight-file list with the verified fourteen, updates the "residual scope opened as a named follow-on ticket, `EDMV4-T04`" sentence to record that the ticket has landed, fixes the stale `EDMV4__lint-and-pipeline-budgets` directory name at `:352` (shared with `EDMV4-04`), and updates the note below the Mermaid section -- which currently says both the Severity and Mermaid sections are generated -- to the true final count, **derived from the generator's actual section list at edit time, not assumed**.

### Technical Notes

- **All three requirements are Must Have**, so the ticket is Must Have. `EDMV4-51` was raised from
  Should Have in SRD v1.0.0 (audit P0-3) specifically so it could not be scheduled after the two it
  gates.
- **The verified orphan table** (`EDMV4-50`), to be re-verified against the tree before use:

  | Site | Section cited | Resolution route |
  |---|---|---|
  | `agents/edm-qc-auditor.md:39` | `Unverifiable acceptance criteria (D15)` | Route 1 -- add to the generator |
  | `skills/verify-runtime/SKILL.md:31,39,147` | `Unverifiable acceptance criteria (D15)` | Route 1 -- three sites, same generator addition resolves all four D15 sites at once |
  | `skills/orchestrator/SKILL.md:113,200` | `EDM mode matrix` | Route 2 -- real heading is `## EDM mode matrix (EDMV3-T38)` |
  | `skills/metrics/SKILL.md:74`, `skills/orchestrator/SKILL.md:200` | `Phase Timing Guidelines` | Route 2 -- real heading carries `(EDMV3-T38)` |
  | `skills/orchestrator/SKILL.md:199` | `Project artifact layout` | Route 1 -- exact heading match exists |
  | `skills/push-jira/SKILL.md:36` | `Optional: Jira synchronization` | Route 1 -- exact heading match exists |
  | `skills/orchestrator/SKILL.md:28,152,196` | `Skill-tool composition` | Route 3 -- bold inline text at `CLAUDE.md:24`, not a `##` heading at all |

- **Site inventory verified on this branch: 14 files, 31 citation sites** -- 5 agents / 11 sites
  and 9 skills / 20 sites, enumerated in AC9. This is the working figure `EDMV4-51`'s enumeration
  reconciles against; it is not a substitute for that enumeration, which owns proving the table
  complete.
- **`skills/orchestrator/SKILL.md:199-200` is the trickiest site in the set.** The sentence spans
  two lines, only the first carries the `CLAUDE.md` prefix, and its backtick nesting is malformed
  in the source (`` Sec."Phase Timing Guidelines"` `` has an unbalanced closing backtick). A
  grep-driven anchoring pass will find one citation there and there are three. Fixing the backticks
  is in scope as part of anchoring the site.
- **`skills/srd/SKILL.md:182` is inside an agent launch template** and is unbackticked. It is a
  prompt the `edm-srd-writer` agent receives, so it has the same resolution problem as a citation
  in the agent body and must be anchored the same way.
- **Do not hand-edit `docs/canonical-sections.md`.** It is a generated, byte-identical mirror with
  exactly one writer, and hand-editing it is precisely the drift `--check` exists to catch. The
  file's own banner and `wave6-smoke.sh`'s AC5 case both enforce this.
- **The generated headings carry a `(canonical)` suffix that citations omit.** `extract_section` is
  called with `"Severity vocabulary (canonical)"` and `"Mermaid diagram conventions (canonical)"`
  at `edm-sync-canonical-sections:110,112`, while every prompt cites `Sec."Severity vocabulary"`.
  The D15 heading has no such suffix, so the third section will match exactly. AC6 exists because a
  naive exact-string sweep would otherwise report every already-anchored lens as an orphan.
- **Blast radius.** `CLAUDE.md`'s Mermaid section states that its own heading string is referenced
  by name from eleven touch points and asserted by a smoke test -- renaming any by-name-referenced
  heading (route 2b) means updating every reference in the same commit. That is why route 2a, which
  changes prompts rather than headings, is the default.

### Out of Scope

- **Re-anchoring the thirteen files D34 already anchored** (the eleven lenses, the synthesizer,
  `edm-srd-auditor`). They are the pattern exemplars, read but not edited.
- **Any change to the D15, Severity or Mermaid section text in `CLAUDE.md`.** All three are
  referenced by name; this ticket adds a generated mirror and edits citations, never the source
  section bodies.
- The wider EDMV3-54 nine-touch-point framing. The set is the verified 14, which overlaps that list
  in eight files and adds six.
- **Nothing from any other requirement may drift into this pre-claimed ID.** `EDMV4-T04` covers
  `EDMV4-49`, `EDMV4-50` and `EDMV4-51` and nothing else. It is not the vehicle for the ASCII sweep
  (`EDMV4-57`), the lens-count work (`EDMV4-23`, `EDMV4-33`), or any other edit to the 14 files it
  touches -- a prompt-text improvement noticed while anchoring belongs in its own ticket, since
  this one's whole diff must be reviewable as "citation kept, anchor appended".

---

## EDMV4-T05: Verify the CA-532 and CA-490 fixes and record the eval-baseline scope boundary

| Field | Value |
|---|---|
| Epic | Inherited Tickets |
| Phase | 1 |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV4-52, EDMV4-53 |
| Depends On | none |
| Target Components | plugins/edm/evals/run-eval.sh:420-421,460-461, plugins/edm/bin/edm-compare-eval:62-75,77-81,109, plugins/edm/evals/baseline/README.md:39-55,104-116, plugins/edm/evals/baseline/ (the missing `scores.json`), plugins/edm/evals/score-artifacts.sh:139, plugins/edm/bin/tests/run-all.sh, SRD/.archived/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl (entries CA-532, CA-490, CA-537), SRD/edm/EDMV4__ecc-integration/decisions.md |

### Description

This is the inherited `EDMV4-T05`, claimed in EDMV3's `decisions.md` D62 as "fix the CA-532
`--allowedTools` argv-splitting bug, run the live wave-A eval capture, commit
`evals/baseline/scores.json`, re-verify CA-490's `edm-compare-eval` reorder". **Both named bugs are
already fixed and verified in current source, so the code work is complete and the ticket closes as
verification plus a boundary record, not as a fix.** CA-532's fix is present: `run-eval.sh:420-421`
defines `CLAUDE_ALLOWED_TOOLS` and `CLAUDE_DISALLOWED_TOOLS` as real bash arrays and `:460-461`
expands them as `"${ARRAY[@]}"`, so the CLI's documented space-separated-separate-arguments
contract is honoured for all four space-containing specifiers. CA-490's fix is present:
`edm-compare-eval:70-75` runs the `complete != true` refusal **before** the baseline-existence check
at `:77-81`. A third inherited item, CA-537's `.gitlab-ci.yml` exit-code arm ordering, is **moot**:
no `.gitlab-ci.yml` exists in this repository (constraint C8 -- there is no CI pipeline at all) and
commit `b56558d` removed the pipeline.

**This ticket spends no API budget, by decision D9 and Gate 1.** The live capture of
`evals/baseline/scores.json` is an explicit scope boundary with a named follow-on, not an omission.
`evals/baseline/README.md:165-171` already records, in its own words, that the capture is a
decision for whoever owns the `ANTHROPIC_API_KEY`, made once and deliberately, "not spent silently
by an agent verifying its own ticket". The interim behaviour is not a silent pass: with no committed
baseline, `edm-compare-eval` exits **3** and prints "the eval tripwire is NOT armed" -- a distinct,
named, non-crashing outcome. The boundary is recorded explicitly with a named follow-on rather than
left as an unnamed candidate, following the D13/D14 precedent: an unnamed gap is how `EDMV4-T01`,
`T04` and `T05` became orphans in the first place.

### Acceptance Criteria

- [ ] AC1: A regression check asserts `CLAUDE_ALLOWED_TOOLS` and `CLAUDE_DISALLOWED_TOOLS` are declared as bash **arrays** in `evals/run-eval.sh` and expanded as `"${CLAUDE_ALLOWED_TOOLS[@]}"` / `"${CLAUDE_DISALLOWED_TOOLS[@]}"` on the `claude -p` invocation -- not as a space-joined string passed as one argv element.
- [ ] AC2: A regression check asserts `bin/edm-compare-eval` performs its `complete != true` refusal **before** its baseline-existence check, pinning the CA-490 ordering. The assertion compares the two blocks' **relative** positions (the line number of the `cand_complete` test versus the line number of the `[ ! -f "$BASELINE" ]` test), never absolute line numbers, so an unrelated edit above them does not produce a false failure.
- [ ] AC3: Both checks live in a suite `bin/tests/run-all.sh` discovers -- its `find "$_SUITE_DIR" -maxdepth 1 -name '*-smoke.sh'` glob. Prefer extending an existing suite. If a new suite file is unavoidable, its `_PREFERRED_ORDER` / `_MIN_SUITE_COUNT` registration is **`EDMV4-T53` AC2's to perform, not this ticket's** (audit P1-3) -- assert the registration is present and raise a defect against `EDMV4-T53` if it is not. Do not cite `_MIN_SUITE_COUNT` by line number; it moved from `:87` to `:96` under commit `5f90001`.
- [ ] AC4: `bash plugins/edm/bin/tests/run-all.sh` exits 0 with both new cases reported as passes.
- [ ] AC5: **Both checks are proven to discriminate.** On a scratch copy, collapsing either array to a space-joined string makes AC1's check fail, and swapping the two blocks in `edm-compare-eval` makes AC2's check fail. A check that cannot fail is not a regression check.
- [ ] AC6: The verification result is recorded, naming the archived ledger entries as the origin of each claim: `CA-532` (`raised_round: 10`, `resolved_round: 11`) and `CA-490` (`raised_round: 9`, `resolved_round: 11`) in `SRD/.archived/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl`.
- [ ] AC7: The CA-537 CI item is **dropped**, with the reason recorded: no pipeline exists (constraint C8), the eval driver and the comparator are purely local invocations, and stray `.gitlab-ci.yml` copies under `.claude/worktrees/*/` are agent scratch worktrees, not this repository's own files.
- [ ] AC8: **No re-fix is attempted for either bug.** `git diff` across this ticket's commits shows no change to `evals/run-eval.sh:420-421` / `:460-461` or to `bin/edm-compare-eval:62-81`. A ticket that "fixes" already-correct code is a defect in the ticket.
- [ ] AC9: `decisions.md` carries the baseline-capture boundary as a **numbered decision**: the capture is out of scope for EDMV4, it is a human credential decision, and the follow-on that owns it is recorded **by name**.
- [ ] AC10: The record states precisely what a capture requires: three `run-eval.sh` invocations against fresh scratch trees, each scored individually by `score-artifacts.sh`, with the **middle run by `total`** committed as the baseline.
- [ ] AC11: The record states what the committed baseline file must contain: `scorer_version` (currently `"1.1.0"`, `score-artifacts.sh:139`), `dimensions_scored` (**5** for a wave-A `plan -> srd -> audit-srd` capture, since dimension 5 -- lens-JSONL-versus-prose agreement -- has no input without a code-audit round), `dimensions`, `total`, `complete`, and -- **only** on the committed baseline, never on every candidate run -- `variance.total_range`, the sole baseline field `edm-compare-eval` reads (`jq -r '.variance.total_range // 0'` at `:109`).
- [ ] AC12: The record states the interim behaviour plainly -- `edm-compare-eval` exits **3** printing "the eval tripwire is NOT armed" (`:77-81`), neither a crash nor a silent pass -- and cross-references `evals/baseline/README.md` (`:39-55`, `:104-116`, `:165-171`) so the two records agree. **No agent spends API budget under this initiative to capture the baseline**: no AC above runs a live eval, and this ticket's text says so. `EDMV4-T05` closes on AC1 through AC12 and is not left open pending a capture that is deliberately not scheduled.

### Technical Notes

- **Both requirements are Must Have**, so the ticket is Must Have. There is no priority divergence
  within this ticket.
- **This is the one ticket in the epic with no production-code change.** `EDMV4-52` adds two test
  assertions and `EDMV4-53` writes a decision record; nothing under `bin/` or `evals/` changes
  behaviour.
- **Verified against the current tree**: `run-eval.sh:420` (the 12-entry `CLAUDE_ALLOWED_TOOLS`
  array, 4 entries containing internal spaces), `:421` (`CLAUDE_DISALLOWED_TOOLS`), `:460-461`
  (the `"${ARRAY[@]}"` expansions on the `claude -p` call); `edm-compare-eval:70-75` (the
  `cand_complete` refusal with its CA-490 comment at `:62-66`), `:77-81` (the exit-3 arm, whose
  exact printed string is `the eval tripwire is NOT armed` -- lowercase "armed", not "ARMED"),
  `:109` (`variance.total_range`); `score-artifacts.sh:139` (`SCORER_VERSION="1.1.0"`);
  `evals/baseline/` contains **only** `README.md`. A grep for `.gitlab-ci.yml` finds nothing in the
  repository's own tree.
- **Suite placement.** `run-all.sh` discovers `*-smoke.sh` files at `bin/tests/` depth 1 and
  refuses if fewer than 7 are found. Extending `wave7-smoke.sh` is the low-friction choice; note
  that `EDMV4-32` (the smoke rewrite) blocks other work touching `wave7-smoke.sh` per SRD Sec.12.2,
  so coordinate placement with that ticket or use `wave6-smoke.sh`.
- **Why AC2 pins relative order rather than line numbers.** The CA-490 comment at
  `edm-compare-eval:62-66` explains that before the fix, the `complete: false` handshake CA-452 was
  filed to make live **never executed** on this repository's actual path, because no baseline is
  committed and every invocation hit the exit-3 return first. Any assertion that pins absolute line
  numbers will go stale the first time a comment above it is edited -- the exact class
  `EDMV4-51` exists to stop.

### Out of Scope

- **Capturing `evals/baseline/scores.json`.** Explicitly out of scope by D9 and Gate 1, recorded as
  a boundary with a named follow-on. Three live `run-eval.sh` runs are real API spend on
  human-owned credentials.
- **Populating the PENDING variance table** in `evals/baseline/README.md:86-94`. Those figures come
  from the three live runs and cannot be invented.
- **Arming the eval tripwire.** `edm-compare-eval` continues to exit 3 until a human captures the
  baseline; that is the correct interim behaviour, not a defect to work around.
- Any CI or pipeline work. There is no pipeline (C8), which is why CA-537 is dropped rather than
  carried.
- **Nothing from any other requirement may drift into this pre-claimed ID.** `EDMV4-T05` covers
  `EDMV4-52` and `EDMV4-53` and nothing else -- in particular not the broader smoke-coverage
  requirement (`EDMV4-58`), which owns coverage for every new surface this initiative adds.

---

## EDMV4-T49: Write the eleven verified corrections back into `ecc-integration-analysis.md`

| Field | Value |
|---|---|
| Epic | Inherited Tickets |
| Phase | 1 |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV4-54 |
| Depends On | none |
| Target Components | plugins/edm/docs/ecc-integration-analysis.md (Part 1.2, Part 1.6, Part 4.2 at `:360,368`, Part 4.3 at `:449`, Part 5.1, Part 5.2 at `:646-650`, Part 5.3, Part 5.5, Part 8.2, Part 8.3), SRD/edm/EDMV4__ecc-integration/planning.md Sec."Corrections to the source document", SRD/edm/EDMV4__ecc-integration/decisions.md (D12, D13) |

### Description

Per Gate 1 and decision D12, Phase 1's eleven verified corrections are amended into the source
document **in place**, in the Part 8.2 self-correction style the document already uses to correct
itself twice. Leaving the analysis uncorrected means the next reader re-derives the same eleven
findings from scratch.

The corrections are substantive, not cosmetic. One of them (correction 2) is a citation the
analysis repeated from ECC without checking, pointing at a file that does not contain what it is
cited for: the seven security triggers are attributed to `rules/common/security.md`, which actually
holds an unrelated 8-item pre-commit checklist; they live at `orch-pipeline/SKILL.md:100-104`, and
`orch-pipeline/SKILL.md` itself miscites `security.md`, which is how the error propagated. Others
change counts a reader would act on: ECC's hook count is 23 registrations across 7 event types, not
25 across 8; `harness-audit.js` consumer mode is 16 checks / 39 points, not 11 / 29.

`planning.md` keeps its correction table as the audit record of what changed. The two documents
cross-reference each other rather than one replacing the other -- the source document carries the
corrected claims, `planning.md` carries the evidence trail.

### Acceptance Criteria

- [ ] AC1: **Pre-flight:** `plugins/edm/docs/ecc-integration-analysis.md` is confirmed present in the working tree before any edit. It was absent when this ticket was written and **is present now**, brought in by the Phase 4 fast-forward (audit P1-9). The pre-flight is retained because it is cheap and correct as a guard: if the file is absent when the ticket is picked up, the ticket blocks and the absence is reported. Under no circumstances are the corrections written into a newly-invented file at that path.
- [ ] AC2: All eleven corrections enumerated in SRD Sec.4.4 are written into the document. A checklist mapping correction number -> the Part it landed in is recorded in the commit message or in `decisions.md`, so an auditor can confirm eleven and not ten.
- [ ] AC3: Each correction is applied in the document's **own Part 8.2 self-correction style**, not as a silent overwrite -- a reader must be able to see that the claim changed and why. The two existing self-corrections in Part 8.2 are the format exemplars; the new ones match their shape.
- [ ] AC4: **Correction 1** corrects the summary total to **23 registrations across 7 event types** while leaving the per-row table unchanged, and the note says explicitly that every individual row is correct, so a reader does not distrust the whole table.
- [ ] AC5: **Correction 2** is applied at **every** site where the analysis cites `rules/common/security.md` for the seven security triggers -- located by grep at edit time, not trusted from the SRD's line numbers -- and each is redirected to `orch-pipeline/SKILL.md:100-104`. The note records that the misattribution originated in ECC's own parenthetical citation. The Target Components name Part 4.2 at `:360,368` and Part 4.3 at `:449` as known sites.
- [ ] AC6: **Correction 3** records that ECC has no hookify evaluator, and the **Part 5.3 effort estimate is annotated** to reflect that EDM builds it from nothing rather than adapting existing logic. This is the correction with a downstream cost consequence, so the estimate change is explicit rather than implied.
- [ ] AC7: **Correction 8** updates the `update-patterns` line citations from `:5577`/`:5624` to `bin/edm-state:5595` and `:5627-5629` (both re-verified in the tree at edit time), and corrects "called mid-phase by four skills" to the verified **six**.
- [ ] AC8: **Corrections 4, 5, 6, 7, 9, 10 and 11** are applied with their verified figures and citations exactly as SRD Sec.4.4 records them: `GAN_EVAL_CRITERIA` is documented but dead code (`scripts/gan-harness.sh` never reads it); `delivery-gate`'s `SKILL.md` omits a third disk tier (a 30GB warning between the documented 50GB and 15GB tiers); `silent-failure-hunter`'s body is 44 lines, not "~30" (the other two are 35 and 39); `harness-audit.js` consumer mode is 16 checks / 39 points once the unconditionally-appended GitHub checks are counted; the GateGuard env-var table omits `GATEGUARD_DISABLED=1` as a second independent kill switch alongside `ECC_GATEGUARD=off`, recognizing only the literal `'1'` and not the word-forms `ECC_GATEGUARD` accepts (`gateguard-fact-force.js:732-734`); `MultiEdit` needs one retry **per still-unchecked file**, not one retry total (`gateguard-fact-force.js:1234-1256`); codemaps placeholder lines are `generate.ts:225-231`, not `:200-240`, with the substance of the claim confirmed.
- [ ] AC9: The document's **Part 8.3 "claims NOT verified" list is updated**: the `zunoworks/gateguard` licence is now verified MIT (`decisions.md` D13, verified by direct inspection of the upstream `LICENSE`) and moves out of the unverified list.
- [ ] AC10: `planning.md`'s correction table is left **intact** as the audit record (`git diff` shows no deletion from Sec."Corrections to the source document"), and the two documents cross-reference each other rather than one replacing the other.
- [ ] AC11: The amended document is **ASCII-only, normalized in place** per `CLAUDE.md Sec."Artifact content conventions"` -- em dashes become `--`, arrows become `->`, smart quotes become straight quotes. **Wrapping the document in `edm-lint-ignore` markers is not an acceptable substitute** and no such marker is added.
- [ ] AC12: `bash plugins/edm/bin/edm-lint-artifacts --path plugins/edm/docs/` exits 0.

### Technical Notes

- **`EDMV4-54` is Must Have**, so the ticket is Must Have. It is the only requirement this ticket
  carries; there is no priority divergence.
- **Blocking risk RESOLVED (audit P1-9): the target file now exists.** It was absent when this
  ticket was written; the Phase 4 fast-forward to `origin/main` restored it at
  `plugins/edm/docs/ecc-integration-analysis.md` (1,024 lines). The original finding is kept
  below for the audit trail, but the ticket is executable.
- **Superseded:**
  `plugins/edm/docs/ecc-integration-analysis.md` is absent from the working tree of
  `edm/verif-verifier-truncation` (the branch this ticket pack was written against) -- the only
  file under `plugins/edm/docs/` at that level is `canonical-sections.md`. Every reference to the
  document in `srd.md`, `planning.md`, `decisions.md` and the explorer reports was taken against the
  initiative branch `edm/edmv4-ecc-integration`, whose ref exists locally. **Execute this ticket on
  the initiative branch**, and treat the file's absence as a blocker (AC1) rather than a signal to
  recreate it -- an imported third-party analysis cannot be reconstructed from its own corrections.
- **This is an imported third-party document**, so `CLAUDE.md Sec."Artifact content conventions"`
  binds: ASCII normalization on import, never an `edm-lint-ignore` exemption ("an exempted document
  in an initiative's own directory is a standing invitation to exempt the next one"). Note also
  that `edm-lint-artifacts` does **not** reach `plugins/edm/docs/` through any automatic
  invocation -- the git-commit hook runs prefix mode, which never touches the plugin's own source
  tree -- so AC12's manual `--path` sweep is the only enforcement here.
- **Verified against the current tree**: `bin/edm-state:5595` (the `srd)` arm of the
  `update-patterns` pattern-file `case`) and `:5627-5629` (the Living-Library insertion-target
  comment), confirming correction 8's replacement citations are accurate as of this branch. The
  `:5577` and `:5624` figures the analysis carries are stale.
- **Line citations in Target Components are against the initiative branch.** `:360`, `:368`,
  `:449` and `:646-650` come from the SRD and could not be re-verified here because the file is
  absent. Locate each site by grep on its content before editing, per AC5, rather than seeking the
  line number.
- **The correction table lives in two places by design.** `planning.md` is the audit record of what
  changed; the source document carries the corrected claims. AC10 exists because the natural
  instinct after amending the source is to delete the now-redundant table, which would destroy the
  evidence trail.

### Out of Scope

- **Any change to ECC's own source.** ECC is an external repository; this ticket corrects EDM's
  analysis **of** it, never ECC itself.
- **Re-verifying the eleven findings.** They were verified in Phase 1 by `explorers/01` and
  `explorers/04` and by direct inspection of `gateguard-fact-force.js`; this ticket transcribes
  verified results, it does not re-derive them.
- **Any scope decision the analysis records.** D2 already settled which Parts are in scope (Part 4
  in full, Parts 5.1 to 5.5; not 5.6, not Part 6, not Part 7); correcting a factual claim inside an
  out-of-scope Part does not bring that Part into scope.
- **Rewriting the document's "Value" ratings.** Per Part 8.3.1 every Value rating is the author's
  ranking of a structural argument, not a measured outcome. The structural claims were verified and
  are corrected here; the value claims were not verified and are left as the author's.
- **The `SRD/.codemap.md` interim** (`EDMV4-46`, D11), even though correction 11 touches the same
  codemaps material. Correcting the citation is this ticket; building the interim is not.
