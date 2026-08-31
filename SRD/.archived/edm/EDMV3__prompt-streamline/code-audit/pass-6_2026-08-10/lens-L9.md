# Lens L9 -- Spec & Ticket Compliance (pass 6, round 6)

**Tooling note (CA-130's class, seventh consecutive round):** Write absent from this
lens's delivered runtime tool set. This report was transcribed by the orchestrator
from the lens agent's final message.

Initiative: EDMV3 -- prompt-streamline
Inputs read: `srd.md` (Sec. 14 traceability + targeted requirement reads), `tickets/README.md` (full), all 11 `tickets/epics/*.md`, `decisions.md` D1-D48, `code-audit/findings-ledger.jsonl`, pass-5 `lens-L9.md`.
Method note: no `Bash` in this lens's delivered tool set either, so every "verify" below was evaluated **statically** by reading the target file and reasoning the command's result, not by executing it. Where a claim depends on execution (CI runners, live eval spend, aggregator exit status), it is labelled as such rather than asserted.

## Part 1 -- Round-5 L9 entries: disposition

| Ledger ID | Round-5 severity | Disposition in round 6 |
|---|---|---|
| CA-299 | P1 | **FIXED.** `grep -c 'four violation classes' srd.md` returns 0; the EDMV3-97 bullet now defers to `--help`/seven classes. Recorded as D42 with before/after text. |
| CA-300 | P1 | **FIXED in substance, with a new stale citation** (see F3). `epics/02:307` now requires exactly 2 `prototype)` sites; the tree has exactly 2 (`bin/edm-state:801`, `:858`). Recorded as D43. |
| CA-301 | P1 | **FIXED.** `epics/03:265` now greps for a wave-suite job KEY (`^[a-z0-9_-]+:wave[0-9]`), which returns nothing against `.gitlab-ci.yml` as required. Recorded as D44. One residual on the *first* half of the same verify (see F4). |
| CA-302 | P1 | **FIXED.** D47 records re-running every timing mode against the shipped 20-sample harness and replacing the T67 evidence figures; `CHANGELOG.md:253` now reads as a result, not a deferral. |
| CA-321 | P2 | **PARTIALLY FIXED.** T66 AC4 and T43 AC12 now cite the smoke cases **by name** ("G9", "T43 AC12") and both names resolve (`wave7-smoke.sh:6252`, `:2368-2374`); D38 now cites by content. But the same-day-stale-citation class recurred inside this session's own new records (F3). |
| CA-322 | P2 | **FIXED, all three halves.** `epics/02:315-329` states the one-call-site contract and names D35; `bin/edm-state:846-854` replaced the future-tense promise with the settled record; `wave6-smoke.sh:277` counts the invocation shape (`code_audit_required_for_mode "`) instead of raw name hits, with a positive control at `:283-286`. Verify re-derived statically: exactly 1 matching line (`bin/edm-state:869`). |
| CA-323 | P2 | **FIXED, with a residual.** `epics/11:463-475` relabels the baseline half as blocked on the D23 gap, mirroring D36's T23 AC13 treatment. Residual second unverifiable clause in the same AC (see F5). |
| CA-324 | P2 | **FIXED at all four named sites** (T67 AC8 `epics/11:839`, T64 AC10 `epics/11:455`, T43 AC12 `epics/06:415`, epics/03 AC7 `epics/03:176`), all now pointing at `wave7-smoke.sh`'s "T67 AC8" case, which exists at `:4358-4396` and asserts the hook's shipped content directly. D48 records the general ruling. |
| CA-325 | P2 | **FIXED.** `epics/04:518-535` restates AC9 as one definition plus one real invocation site; re-derived statically: `^BLOCKING_FILTER=` -> 1 (`:1364`), `$BLOCKING_FILTER` -> 1 (`:4125`), `cmd_audit_converged "$prefix"` -> 3 (`:1959`, `:2729`, `:5023`). |
| CA-106, CA-108, CA-109, CA-110, CA-125, CA-132, CA-174, CA-175 | NOTED | Still correctly NOTED. Not re-filed. |
| CA-130 | NOTED | **Reproduces a seventh consecutive round** (this lens has no `Write`). |

No prior L9 finding reopened.

## Part 2 -- Findings (L9: Spec & Ticket Compliance)

### Missing Implementations (P1)

| Requirement | Ticket | What's Missing | Evidence |
|---|---|---|---|
| EDMV3-56 (Must) -- "one pass serves four classes" | **T43 AC1**, `epics/06:340-345` | The AC's verify asserts `build_line_classes` has **one definition and one call in `plugins/edm/bin/edm-lint-artifacts`**. There is **no definition in that file**: it lives in `plugins/edm/bin/_edm-lint-lib.sh:89`. `edm-lint-artifacts` holds 7 occurrences -- six comments (`:81`, `:176`, `:184`, `:263`, `:284`, `:297`) and one real call (`:293`). The AC's *substance* (one pass, computed once per file, shared by all classes) still holds; the stated tree fact does not. The shared-lint-library extraction that moved it was completed **in this session** (`2d83898`, "finish the shared-lint-library extraction (Wave 3, P2 Group A)") and no sweep of the AC that names the old location followed. Third consecutive round of the same root cause: a remediation lands the code half and not the spec half. | `epics/06:343-345` vs `_edm-lint-lib.sh:89`, `edm-lint-artifacts:293` |
| EDMV3-56 (Must) -- header block lists the classes | **T43 AC8**, `epics/06:385-390` | The AC's verify asserts `sed -n '7,11p' plugins/edm/bin/edm-lint-artifacts` **names four classes**. Lines 7-11 today are the CA-005/CA-154 sentinel-convention comment, `# EDM-HELP-BEGIN`, and the one-line tool description -- **zero** class names. The class enumeration is at `:24-39` and names **seven**. Two independent defects in one verify: (a) it is the last surviving site of the "four violation classes" staleness family that CA-254/CA-299 swept out of `CLAUDE.md` (D41), the ticket pack (D41) and `srd.md` (D42) -- neither sweep reached this one; (b) it verifies content by a **hardcoded line range**, the exact idiom this initiative deleted from the file under EDMV3-96/T61 AC1, which the AC's own body acknowledges ("EDMV3-96 replaces the hardcoded range with sentinel delimiters and owns that line"). | `epics/06:385-390` vs `edm-lint-artifacts:1-11`, `:24-39` |

### Partial Implementations (P1)

| Ticket | AC | What the Spec Requires | What Code Does | File:Line |
|---|---|---|---|---|
| T67 | **AC11** (Should) | Round-5 remediation CA-319 prescribed three edits, the third being: *"extend AC11 with a weaker pass asserting version pinning on `allow_failure` jobs rather than exempting them."* | The **code half landed** -- both npm installs are now pinned (`.gitlab-ci.yml:603`, `:657`, `@anthropic-ai/claude-code@2.1.226`) with a documented refresh-procedure note at `:597-598`, and the install-scripts decision is recorded in-file rather than left silent. The **AC half did not**: `epics/11:860-864` is byte-unchanged, still scoping the no-network control to blocking jobs and structurally exempting exactly the two jobs that reach the network. The prescribed control that would notice a future unpinned install still does not exist in any AC, and there is no decisions.md record electing a different resolution. | `epics/11:860-864` vs `.gitlab-ci.yml:597-603`, `:657` |

### Scope Creep (P2)

None new. Checked and **not** creep:

- `bin/_edm-lint-lib.sh` and `bin/edm-mermaid-rules.awk` -- prescribed by committed REMEDIATION docs and sanctioned by T30 AC9 (`epics/04:781-784`); CA-175's precedent stands. (The *AC-staleness* it caused is F1, which is a different defect from creep.)
- `bin/_edm-cli-lib.sh` -- CA-005's prescription, named in `edm-lint-artifacts:3` and T61 AC1.
- `.gitlab-ci.yml`'s npm pins and the four-way lint split -- sanctioned by CA-319 and D26/D29-T02 respectively.
- The hook exit-code conversion (CA-298 family) now carries CHANGELOG coverage at `:101` (G44) and `:124-125` (G30), closing the change-control half CA-275 named. Not re-filed as creep.

### Additional P2 findings

1. **F3 -- a stale line citation authored by this session's own decision record.** D43 prescribed pointing T07 AC5's second verify half at `wave6-smoke.sh:246`, and `epics/02:314` now reads `bash plugins/edm/bin/tests/wave6-smoke.sh:246 (case "single mode derivation")`. **Line 246 is blank** -- it sits inside the T07 **AC4** block (`:236-259`). The AC5 case is at `:261-266` (section comment `:261`, echo `:263`, assertion `:264-266`). The cited case name resolves; the line number does not. This is precisely CA-321's class ("a citation authored the same day as the fix is already wrong"), reproduced inside the remediation that was closing CA-321, and it is the one axis on which D43-D48 fall below the by-name-citation bar D38 set. Fix: drop the `:246` and keep the case name, per the by-name convention D38/D41/CA-321 adopted everywhere else this session.
2. **F4 -- T21 AC5's first verify half still states a singular that the file contradicts.** `epics/03:264` says `grep -n 'run-all.sh' .gitlab-ci.yml` "returns **the single invocation**". The file has **two** invocations (`:377` `test:smoke`, `:416` `test:smoke-bash32`) plus three comment mentions (`:363`, `:379`, `:380`) -- five lines. D44 rewrote the *second* half of this same verify and left the singular standing, while D44's own re-verification clause names **both** jobs without noticing the contradiction. Substance is fine (one aggregator entry point, deliberately run under two images); the stated expected result is not. Fix: "returns the aggregator invocation in each of the two `test:` jobs and nothing else."
3. **F5 -- CA-323's relabel left a second unverifiable clause in the same AC.** T64 AC11 (`epics/11:466-467`) still asserts "all smoke suites are green **in CI** including the flat-layout, `fast-track` and `mini-srd` cases", and its verify (`:473-474`) still requires "the CI default-branch pipeline is green today". D27 already records that a live GitLab runner does not exist in this environment, and D27's scope is T67 AC9/AC13 only -- so this clause is the exact D15 class the relabel pass was in the AC to fix, left uncovered by any recorded exception. The runnable half (`run-all.sh` exit 0) is fine. Fix: scope the CI clause the way D27 scopes its siblings (verified-locally-pending-pipeline), or point it at the aggregator alone.
4. **F6 -- the by-name case citation in the freshly amended T07 AC6 is a paraphrase, not the shipped label.** `epics/02:328-329` cites case `"T07 AC6 -- exactly one direct call site"`. The shipped labels are `"T07 AC6 -- code_audit_required_for_mode has exactly one direct call site"` (`wave6-smoke.sh:270`, `:279`). A reader grepping the cited string gets nothing. Same one-line fix class as F3; listed separately because the defect is the *string*, not a line number, and the by-name convention is only durable if the name is verbatim.
5. **F7 -- CA-242's durability half is real but its numeric anchor is already load-bearing prose.** T66 AC3 (`epics/11:660-674`) now carries the `bin/` row-count contract and derives the shipped count mechanically. Verified statically: `plugins/edm/bin/` holds exactly **9** `edm-*` non-`.awk` files (`edm-state`, `edm-init`, `edm-validate-prefix`, `edm-lint-artifacts`, `edm-sync-canonical-sections`, `edm-check-grants`, `edm-check-vocabulary`, `edm-compare-eval`, `edm-check-skill-sync`), matching the AC's parenthetical "(9 as of this round)". The AC's own text says the derivation avoids "a second hardcoded literal" and then prints one in prose. Low-severity, but it is the same shape that let the table sit at 9 rows describing a stale set. Fix: delete the parenthetical or mark it non-normative.

## Part 3 -- Cross-check: did this session's 51 fixes invalidate any other AC verify?

Systematically walked every count-bearing and tree-state `Verify:` clause in the eleven epic files against the current tree. **Broken by a later change** (all filed above): T43 AC1 and AC8 (the shared-lint-library extraction), T67 AC11 (the npm-pinning half), T21 AC5 first half, T07 AC5 line citation, T07 AC6 case name.

**Checked and still resolving correctly** (statically re-derived, not assumed):

- T07 AC5: `prototype)` -> 2 (`bin/edm-state:801`, `:858`).
- T07 AC6: `code_audit_required_for_mode "` -> 1 (`:869`). The definition line `:855`, the `die()` message `:860` and the four comment mentions correctly do not match the invocation shape.
- T28 AC9: `^BLOCKING_FILTER=` -> 1; `$BLOCKING_FILTER` -> 1; `cmd_audit_converged "$prefix"` -> 3.
- T43 AC12 / T66 AC4: `four violation classes` in `plugins/edm/CLAUDE.md` -> 0 (surviving hits are only the two `wave7-smoke.sh` regression labels and one G51 pass-line); `edm-lint-artifacts --help` row present; the seven-class `--help` regex matches exactly the seven `#   <class>` lines at `edm-lint-artifacts:25-39`.
- T64 AC10, T67 AC8, epics/03 AC7: the "T67 AC8" case exists (`wave7-smoke.sh:4358-4396`) and covers all six behaviours the three ACs enumerate -- `diff --cached --name-only`, derived `srd_root`, unresolvable-prefix skip, exit-1-vs-exit-2, per-prefix invocation, `check_absent` on `--all`.
- T21 AC5 second half: `^[a-z0-9_-]+:wave[0-9]` -> no matches.
- T38 AC (`epics/05:492`): exactly one skill grants `Skill` (`skills/orchestrator/SKILL.md:8`).
- T66 AC6: `agents/*.md` -> 30.
- T42 (`epics/06:243`): the `sort -u` form -> 1 (21 occurrences across 13 files, one unique string).
- T45 (`epics/07:87-88`): "match the length of the document" -> 8 agent files.
- T49 (`epics/07:544`): `(D[1-6])` in `plugins/edm/CLAUDE.md` -> 6.
- T48/T02 lens count (`epics/07:435`): 11 `edm-audit-*` lenses excluding the synthesizer.
- D45's CA-308 fix: `skills/plan/SKILL.md` now names the cross-reference mechanism and points at the existing G15 case by name; no AC asserts the narrower vocabulary.
- D46's `cmd_lint` removal: no AC anywhere in the pack references an `edm-state lint` subcommand, so dropping it broke no criterion; the 40 -> 39 correction is in `CLAUDE.md` and T66 AC3 carries no hardcoded subcommand number.

## Part 4 -- Noted / Not Actionable

1. **T28 AC9's "the set is exactly `status == "open"`"** understates the shipped `BLOCKING_FILTER` at `bin/edm-state:1364`, which is `(.status == "open" or .status == "deferred")`. Not actionable: T28 **AC5** explicitly requires a legacy `deferred` line to be "counted as **open** at its recorded severity", so the code satisfies the ticket read as a whole and the divergence is documented-as-intentional in the same AC set.
2. **Nine `git diff ... | grep -c` verify forms** (`epics/05:83`, `epics/06:390`, `epics/07:77`, `:185`, `:206`, `epics/09:77`, `:196`, `epics/10:167`, plus the `git log` forms at `epics/11:343`, `:354`, `:479`) are per-merge-request historical claims about what a diff did or did not contain, not tree-state assertions -- exactly the distinction D48 drew when it deliberately excluded T36 AC6 and T13 AC8. Not re-filed.
3. **T67 AC6's bare Mermaid ratio** remains a malformed budget shape; already recorded as CA-108 / D26 / D29-EDMV4-T01. Not re-filed.
4. **`evals/baseline/scores.json` absence** remains the one recorded gap behind T23 AC8/AC9/AC13 and T64 AC11's baseline clause; already CA-106 / D23 / D36. Only the AC11 *residual* clause is new (F5).
5. **T67 AC9/AC13** stay verified-locally-pending-pipeline per D27; not a deferral and not re-filed.
6. **EDMV3-86 through -90** (the five Won't-Haves) remain recorded scope boundaries with their negative-enforcement ACs intact; spot-checked T09 AC13, T04 AC7 and T14 AC3/AC11 citations and all still resolve.
7. **The `find plugins/edm/bin` derivation excluding `_edm-*.sh`** is correct, not a gap: the two shared libraries are sourced, not PATH-exposed executables, which is why `CLAUDE.md`'s `bin/` table omits them (standing carve-out from pass-5 note 1).
8. **CA-130 reproduces a seventh consecutive round** -- `Write` absent from this lens's delivered tool set; this report was returned as chat text for orchestrator transcription. This is the failure mode D18 predicted for a proxying model and it has now recurred every round of the initiative.

## Part 5 -- Convergence read for this lens

Two P1 (both `epics/06` T43 ACs asserting a pre-extraction tree), one P1 partial (T67 AC11's missing AC half), five P2. All eight are ticket-pack or SRD text defects; **none is a code defect** -- in every case the shipped code is the correct half and the specification is the stale half, which is the inverse of the usual direction and is worth naming for the convergence decision. The recurring root cause is unchanged for the fourth consecutive round: a remediation lands the code and does not sweep the AC that names the code. F1 and the T67 AC11 half are both instances created **by this session's own remediation**, so the durability recommendation stands and hardens: any remediation that moves a symbol between files, or that a ledger entry prescribes an AC edit for, must grep the ticket pack and `srd.md` for the symbol name before the commit is made, and the prescribed AC edit must be part of the same commit as the code edit.
</content>
