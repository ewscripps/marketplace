# Lens L9 -- Spec & Ticket Compliance (Round 8, full)

**Tooling note (CA-130's class, eighth consecutive round):** `Write` AND `Bash` are both
absent from this lens's delivered runtime tool set (only `Read`, `Grep`, `Glob`, `WebFetch`,
`WebSearch`, `TaskStop` were delivered). This report was returned as chat text for the
orchestrator to persist. Every "Verify:" below was therefore evaluated **statically** by
reading the target file and reasoning the command's result, never by executing it. Where a
claim depends on execution (CI runners, live pipelines), it is labelled as such.

Initiative: EDMV3 -- prompt-streamline
Inputs read: `srd.md` (targeted requirement reads: EDMV3-90, -11..-18, -38/-39, -43, -97, -98),
`tickets/README.md` (full, both pages), `tickets/epics/02`, `03`, `04`, `06`, `11` (targeted AC
reads), `decisions.md` D57, `code-audit/findings-ledger.jsonl` (CA-368..371, CA-416),
`HANDOFF.md`, pass-6 and pass-7 `lens-L9.md`.

## Part 1 -- Prior-round L9 findings: disposition

| Ledger ID | Prior sev | Disposition in round 8 | Evidence |
|---|---|---|---|
| CA-368 | P2 | **FIXED, both halves.** (a) The stale line number is gone: `epics/02:314` now reads ``Also: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "T07 AC5 -- single mode derivation")`` with no `:246`, and the label resolves verbatim. (b) The paraphrase is gone: `epics/02:328-329` now cites `case "T07 AC6 -- code_audit_required_for_mode has exactly one direct call site"`, matching the shipped `echo` label byte for byte. | `epics/02:314` vs `wave6-smoke.sh:271`; `epics/02:328-329` vs `wave6-smoke.sh:278` |
| CA-369 | P2 | **FIXED.** `epics/03:264-265` now reads "returns the aggregator invocation in each of the two `test:` jobs and nothing else" -- the singular is gone and the two jobs are named. Re-derived statically: `.gitlab-ci.yml:435` (`test:smoke`) and `:476` (`test:smoke-bash32`) are the two invocations. Residual nit in Noted #2. | `epics/03:264-265` vs `.gitlab-ci.yml:435`, `:476` |
| CA-370 | P2 | **FIXED.** `epics/11:467-470` now scopes the clause explicitly: "The 'green in CI' half of this clause is scoped the same way D27 scopes its siblings (verified-locally-pending-pipeline, not faked)", and the verify at `:476-480` repeats the scoping. | `epics/11:463-480` |
| CA-371 | P2 | **FIXED.** The `(9 as of this round)` parenthetical is gone from T66 AC3. The AC now derives the count only mechanically (`find plugins/edm/bin -maxdepth 1 -type f -name 'edm-*' ! -name '*.awk' | wc -l`) with no restated literal. Re-derived statically: `plugins/edm/bin/` still holds exactly 9 `edm-*` non-`.awk` files, so the derivation is live and correct. | `epics/11:656-679`; `plugins/edm/bin/` listing |
| CA-416 | P2 | **STILL OPEN.** No `spec/AC text swept in same commit` field (or any equivalent) exists anywhere in `plugins/edm/`. The synthesizer's "Findings Ledger Format" field rules (`agents/edm-audit-synthesizer.md:159-168`) enumerate only `id`, `status`, `confidence`, `lenses`, `raised_round`, `resolved_round`. The Remediation Plan Format (`:87-147`) carries Problem / Fix / Verification / Files affected and no doc-sweep obligation. A repository-wide grep for the token finds it only inside restatements of the finding itself (`HANDOFF.md:83`, `findings-ledger.jsonl:416`, `findings-ledger.md:356`, `pass-7/REMEDIATION.md:275`, `pass-7/lens-L9.md:43`). Re-flagged below. | `agents/edm-audit-synthesizer.md:149-175` |

Also re-verified (round-6 P1s, not in my brief but adjacent): **T43 AC1 and AC8 are FIXED.**
`epics/06:340-351` now names `_edm-lint-lib.sh` as the definition site and uses invocation-shape
greps; statically re-derived: `^build_line_classes()` -> 1 (`_edm-lint-lib.sh:92`),
`build_line_classes "` -> 1 (`edm-lint-artifacts:293`), `build_ignore_set` -> 0.
`epics/06:391-397` now verifies "by sentinel, not a hardcoded line range".

## Part 2 -- Findings (L9: Spec & Ticket Compliance)

### Missing Implementations (P1)

| ID | Requirement | Ticket | What's Missing | Evidence (search results) |
|----|-------------|--------|-----------------|---------------------------|
| L9-001 | Same-commit spec/AC sweep obligation (structural, CA-416) | none -- ledger/synthesizer templates | No acceptance criterion, ledger field or remediation-format field anywhere obliges a spec/AC sweep in the commit that lands a code fix. Round 7 prescribed a mandatory `spec/AC text swept in same commit: yes/no/n-a` field on the findings-ledger entry template and the synthesizer's remediation format; neither was added. This is the named structural root cause of the stale-citation class, which produced a fresh instance again this round (L9-006). | `grep 'swept in same commit\|doc_sweep\|spec_swept'` over `plugins/edm/` -> 0 hits. Field rules at `agents/edm-audit-synthesizer.md:159-168` list six fields, none of them this one. Remediation format `:87-147` has no such row. |

### Partial Implementations (P1)

| ID | Ticket | AC | What the Spec Requires | What Code Does | File:Line |
|----|--------|----|--------------------------|------------------|-----------|
| L9-002 | (no ticket) -- SRD requirement **EDMV3-90**, Won't Have | AC1 | `srd.md:3836-3837`: "No `--force`, `--accept-partials`, `--skip-checks`, `--yes`, **or equivalent bypass flag** exists on `phase-complete`, `archive`, `approve-gate`, or `audit-converged`." AC4 adds that a recorded-exemption category "would be an override flag with a state field instead of a command-line argument". AC6 requires the D13 rationale recorded precisely so "a future contributor does not add a flag 'for convenience'". | A bypass flag now exists on `approve-gate`. `edm-state approve-gate <PREFIX> code-audit --accept-p2-debt` (`bin/edm-state:2085-2093`) converges an initiative that `cmd_audit_converged` has just refused, whenever the refusal is P2-only (`:2178-2195`), and records the exemption in five new state fields (`:2210-2227`), i.e. it is **both** halves AC1 and AC4 forbid. `cmd_archive` (`:3013-3034`) and HANDOFF rendering (`:5327-5332`) were extended to honour it. No srd.md change request amends EDMV3-90; `tickets/README.md:688` still asserts the boundary intact and names T09 AC13 / T30 AC10 as its negative enforcement. Both enforcement mechanisms enumerate **flag names** rather than the class, so both still pass: `vocabulary-prohibited.txt:18-19` bans only `accept-partials` and `--force`, and T30 AC10's grep (`epics/04:797`) is `-- '--force\|--accept-partials'`. `decisions.md:66` (D57) records the decision, but a decision record is not the gate change-control route the pack's own D15/D13 rules require for a scope change, and it does not amend the SRD it contradicts. | Spec: `SRD/edm/EDMV3__prompt-streamline/srd.md:3836` -- Code: `plugins/edm/bin/edm-state:2087` |
| L9-003 | **T28** (EDMV3-36/37) | AC12 | `epics/04:547-550`: "`cmd_approve_gate <PREFIX> code-audit` calls the check and **refuses when it fails**, and `cmd_archive` calls it as part of lifecycle verification." The blocking set is defined once and includes P2 (`bin/edm-state:1496`, `BLOCKING_FILTER`). | `cmd_approve_gate` still calls the check, but no longer unconditionally refuses when it fails: `bin/edm-state:2178-2195` inspects the refusal, and when `conv_ec -eq 1` with P0=0/P1=0/P2>0 it proceeds to record convergence anyway. AC12 was not amended, and no AC anywhere describes the new branch, so the ticket pack's statement of `cmd_approve_gate`'s contract is now false for one of its three input classes. The `--accept-p2-debt`-absent path is unchanged and still refuses correctly, which is why every existing smoke case stays green. | `epics/04:547-550` vs `plugins/edm/bin/edm-state:2178-2195` |

### Scope Creep (P2)

| ID | File / Feature | Not Specified In | Recommendation |
|----|----------------|------------------|----------------|
| L9-004 | The entire `--accept-p2-debt` feature: `bin/edm-state:18`, `:1499`, `:2085-2093`, `:2169-2227`, `:3004-3034`, `:4488`, `:5327-5332`; `skills/code-audit/SKILL.md:141-190`; `CLAUDE.md:234-249`; `docs/canonical-sections.md:31`; `bin/tests/wave6-smoke.sh:658-730`. Commits `dc8a24f`, `bdab2ac`. | No ticket in the EDMV3 pack: `SRD Refs`, `tickets/README.md`'s 67-ticket index and its bidirectional coverage map carry nothing for it. The label used in code and comments is **`T-EDMV4`**, which resolves to no ticket pack anywhere -- `SRD/**/EDMV4*` matches zero paths on disk, so the `EDMV4__lint-and-pipeline-budgets` initiative `CLAUDE.md:338-339` names does not exist. A new CLI flag, five new state fields, a new gate branch and a new archive staleness guard is not "a necessary implementation detail not worth ticketing" under the False Alarm Filter. | Open a real ticket with ACs (positive: converges with P0/P1 clear; negative: refuses with any open P0/P1; negative: archive refuses on stale debt) in whichever pack owns it, and stop citing a ticket ID that no pack defines. If EDMV3 is to own it, it needs an SRD change request against EDMV3-90 approved at a gate, not only `decisions.md` D57. |
| L9-005 | `plugins/edm/WHATS_NEW.md` (new top-level plugin document, currently **untracked**) | No ticket and no SRD requirement covers a `WHATS_NEW.md`. `EDMV3-111`'s preserve-untouched list and `EDMV3-85`'s post-deletion validation both describe the shipped file set; this file is outside all of them. It also carries deferral vocabulary at `:19` ("deferrable", "defer.") and `:32` ("no-deferral") which the deterministic backstop structurally cannot see -- `edm-check-vocabulary`'s `SCOPE_ROOTS` (`bin/edm-check-vocabulary:98-107`) lists `CLAUDE.md` and `README.md` as **explicit files**, never the plugin root as a directory, so a new top-level `.md` is invisible to it. Its own line `:19` also claims the override-flag exception is "fully-audited", which is not yet true: this round is the first audit round after `dc8a24f` landed. | Either ticket it (it is user-facing release communication and reads like a deliverable) or keep it out of `plugins/edm/`. Independently: add `${PLUGIN_ROOT}` top-level `*.md` to `edm-check-vocabulary`'s scope so the next new root document is covered by default, and correct the "fully-audited" claim. |

### Additional P2 findings (spec/AC text defects)

| ID | Ticket / AC | Defect | Evidence |
|----|-------------|--------|----------|
| L9-006 | **T66 AC3** (`epics/11:671-672`) | Fresh instance of the exact class CA-368 closed, and a violation of the pack's own rule added in the same round ("Verbatim shipped case labels, never a paraphrase (G40/CA-368)", `tickets/README.md:74-81`). The AC cites `case "CLAUDE.md subcommand count and membership match dispatch"`. That string exists nowhere in the suite. The shipped labels are `T66 AC3 -- subcommand count and membership match the dispatch table exactly` (`wave7-smoke.sh:1193`) and `T66 AC3 -- CLAUDE.md's documented subcommand count ($t66ac3_claude_count) matches the dispatch table ($t66ac3_dispatch_count)` (`:1197`). A reader grepping the cited string gets nothing. The sibling citation in the same AC (`"T66 AC3 (G25/CA-242) -- bin/ table row count matches shipped bin/ script count"`, `epics/11:675-676`) **is** verbatim (`wave7-smoke.sh:1235`), which is what makes this one a miss rather than a convention gap. | `epics/11:671-672` vs `wave7-smoke.sh:1193`, `:1197` |
| L9-007 | **T30 AC4** (`epics/04:763-769`) | Stale in both its normative half and its verify half. Normative: "The allowed classes are exactly: the `NOTED`-versus-deferral clarification in `CLAUDE.md`, the checker's own two pattern files, `CHANGELOG.md` history entries, and `plugins/edm/bin/tests/`" -- five. The shipped allowlist has **seven** labelled classes over nine data lines, adding Class 5 (`agents/edm-audit-spec.md|deferred`, `:34`), Class 6 (`bin/edm-state|deferred`, `:52`) and Class 7 (`docs/canonical-sections.md|`, `:41`). Each addition was sanctioned by a later ticket (the comments name EDMV3-32/T29, T25 AC4/T28 AC5, and T41), and none swept this AC. Verify: both stated counts are wrong by construction -- `grep -c '^#'` counts comment lines (about 36 in a 53-line file), not "the entry count" (9); `grep -c .` counts non-blank lines (about 52), not "exactly five classes". | `epics/04:763-769` vs `plugins/edm/bin/vocabulary-allowlist.txt:13,15,18,21,24,28,34,41,52` |
| L9-008 | **T29 AC12** (`epics/04:677-681`) | The "normative catch-all" is unsatisfiable as written and its enumeration is incomplete. It claims `grep -rni 'defer' plugins/edm/` returns "only the `NOTED`-versus-deferral clarification in `CLAUDE.md`, the vocabulary checker's own pattern and allowlist files, and `CHANGELOG.md` history entries", and its verify (`grep -rni 'defer' plugins/edm/ | grep -v CHANGELOG.md | grep -v vocabulary- | grep -v 'not a deferral'`) is stated to return zero results. It does not: surviving hits include `CLAUDE.md:224-225` (the clarification itself does not contain the literal string "not a deferral", so the third filter never removes it), `docs/canonical-sections.md:21-22`, `skills/code-audit/SKILL.md:139`, `bin/edm-state:1488-1491`/`:1496`/`:1508`/`:4147`/`:4423`/`:4428`, `bin/tests/_harness.sh:82`, `agents/edm-audit-spec.md:66`, `bin/tests/fixtures/code-audit/lens-L1.jsonl:6`, several `bin/tests/wave7-smoke.sh` lines, plus `WHATS_NEW.md:19`/`:32`. All but the last are sanctioned carve-outs the real checker honours -- the three-filter pipeline simply does not reproduce the allowlist's seven classes. The **substance is sound**: `edm-check-vocabulary` exits 0 (AC13). The AC text is the defect. | `epics/04:677-681` vs `plugins/edm/bin/vocabulary-allowlist.txt:10-52` |
| L9-009 | Cross-cutting AC "Changelog entry written if initiative has a CHANGELOG" (`tickets/README.md:103`) and **EDMV3-98** | The `--accept-p2-debt` feature ships with no CHANGELOG entry and no version bump. `grep 'accept-p2-debt\|code_audit_p2_debt' plugins/edm/CHANGELOG.md` returns zero; the newest entry is `## [3.1.0] - 2026-07-28` (`CHANGELOG.md:7`) and `plugin.json:4` is still `3.1.0`, so a user-visible CLI flag, a new gate branch and five new state fields are shipping inside a released version with no release note. Separately, the five new fields (`code_audit_p2_debt_accepted`/`_count`/`_round`/`_accepted_at`/`_accepted_by`) appear nowhere in `CLAUDE.md`'s state-field table -- only in the Severity-vocabulary prose at `CLAUDE.md:241` -- while that table's own preamble states it "is the whole state-field reference, not only the mode family" and that "every row states what a reader does when the field is absent (C-4 backward compatibility)". T66 AC5's obligation is scoped to "every field added by **this initiative**", so if the feature is genuinely T-EDMV4's then no AC owns documenting them: the same orphaned-obligation shape as L9-001. | `plugins/edm/CHANGELOG.md:7`; `plugins/edm/.claude-plugin/plugin.json:4`; `plugins/edm/CLAUDE.md:241` vs the state-field table |

## Part 3 -- Cross-check: did anything else break?

Statically re-derived and **still resolving correctly** (not assumed):

- T07 AC5: `prototype)` in `bin/edm-state` -> 2 (`:814`, `:920`).
- T07 AC6: `code_audit_required_for_mode "` -> 1 (`:931`).
- T21 AC5 second half: `^[a-z0-9_-]+:wave[0-9]` against `.gitlab-ci.yml` -> no matches.
- T28 AC9: `^BLOCKING_FILTER=` -> 1 (`bin/edm-state:1496`).
- T43 AC1: 1 definition (`_edm-lint-lib.sh:92`), 1 call (`edm-lint-artifacts:293`), 0 `build_ignore_set`.
- T66 AC3 (row-count half): `plugins/edm/bin/` holds exactly 9 `edm-*` non-`.awk` files; no new script appeared this round.
- T64 AC10 / T67 AC8 / epics/03 AC7: the `"T67 AC8"` case still exists (`wave7-smoke.sh:4537-4556`).
- T61 AC11: the divergence-point case still exists by name (`wave7-smoke.sh:1017`).
- T30 AC5 / AC12 (checker exits 0): `docs/canonical-sections.md` is allowlisted wholesale as Class 7 (`vocabulary-allowlist.txt:41`) and `bin/tests/` as Class 4 (`:28`), so the byte-identical canonical-sections duplicate of the deferral clarification does **not** trip the checker. Confirmed not a defect.
- EDMV3-86, -87, -88, -89: all four Won't-Have boundaries still intact; only EDMV3-90 is breached (L9-002).

## Part 4 -- Noted / Not Actionable

1. **CA-130 reproduces an eighth consecutive round.** Neither `Write` nor `Bash` was in this
   lens's delivered tool set; the report was returned as chat text. Structural, not a code defect.
2. **CA-369 residual.** `grep -n 'run-all.sh' .gitlab-ci.yml` also matches three comment lines
   (`:420`, `:437`, `:438`) alongside the two invocations, so "and nothing else" is loose if read
   as a raw line count. Not re-filed: the clause immediately preceding it scopes the claim to
   invocations ("the `test` stage's script is `bash .../run-all.sh` and contains no enumeration of
   individual suites"), and the three comments are AC5's own rationale text. False Alarm Filter (2).
3. **Nine `git diff ... | grep -c` and `git log` verify forms** (`epics/05:83`, `epics/06:390`,
   `epics/07:77`, `:185`, `:206`, `epics/09:77`, `:196`, `epics/10:167`, `epics/11:343`, `:354`,
   `:479`) are per-merge-request historical claims, not tree-state assertions -- the distinction
   D48 drew when it excluded T36 AC6 and T13 AC8. Not re-filed.
4. **T67 AC6's bare Mermaid ratio** remains a malformed budget shape; already CA-108 / D26 /
   D29-EDMV4-T01. Not re-filed.
5. **`evals/baseline/scores.json` absence** remains the recorded gap behind T23 AC8/AC9/AC13;
   already CA-106 / D23 / D36. Not re-filed.
6. **T67 AC9/AC13** stay verified-locally-pending-pipeline per D27. Not a deferral, not re-filed.
7. **T28 AC9's "the set is exactly `status == \"open\"`"** understates the shipped
   `BLOCKING_FILTER` (`bin/edm-state:1496`, which is `(.status == "open" or .status ==
   "deferred")`). Still not actionable: T28 AC5 explicitly requires a legacy `deferred` line
   counted as open at its recorded severity, so the code satisfies the AC set read as a whole.
8. **`CLAUDE.md:338-339`'s claim that `EDMV4-T04` is "the next unused ticket number in
   `EDMV4__lint-and-pipeline-budgets`"** while no such initiative exists on disk was already
   reported by L6 in pass 7. Cited here only as corroboration for L9-004's "T-EDMV4 resolves to
   no pack" finding; not re-filed under L9.
9. **`bin/_edm-lint-lib.sh`, `bin/_edm-cli-lib.sh`, `bin/edm-mermaid-rules.awk`** remain
   sanctioned (T30 AC9, CA-005, committed REMEDIATION docs). CA-175's precedent stands; not creep.
10. **The `find plugins/edm/bin` derivation excluding `_edm-*.sh`** is correct, not a gap: the two
    shared libraries are sourced, not PATH-exposed executables. Standing carve-out.

## Part 5 -- Convergence read for this lens

One P1 missing implementation (L9-001, the CA-416 structural gap, now in its second round), two P1
partials (L9-002, L9-003 -- both consequences of one unticketed feature), two P2 scope-creep
entries and four P2 spec-text defects. Nine total.

The character of this round differs from rounds 5-7 and that matters for the convergence
decision. In every prior round the shipped code was the correct half and the specification was the
stale half. This round contains the **inverse**: `--accept-p2-debt` is shipped code that
contradicts a Won't-Have SRD acceptance criterion (EDMV3-90 AC1) with no ticket, no SRD change
request and no gate change-control record -- only a `decisions.md` row. It is also, by
construction, a feature that makes it easier to converge with open P2s, landed while 50+ P2s stand
open, which is exactly the situation EDMV3-90's own rationale ("an override flag is the exact
mechanism that converts an enforced invariant back into a suggestion") was written to prevent. I
am not judging the product decision -- only recording that the specification forbidding it is
unamended, no ticket authorizes it, and the two mechanisms the pack names as keeping the boundary
true both pass because they enumerate flag names instead of the class.

The four P2 spec-text defects (L9-006 through L9-009) are the same root cause for the fifth
consecutive round: a remediation lands the code and does not sweep the AC that names it. L9-001 is
the fix for that class and it is still not built.

## Summary

- **CA-368 FIXED**, **CA-369 FIXED**, **CA-370 FIXED**, **CA-371 FIXED**, **CA-416 STILL OPEN** (re-filed as L9-001).
- Also confirmed fixed, though outside my brief: round-6's two P1s on T43 AC1 and AC8.
- **The material new finding is `--accept-p2-debt`** (commits `dc8a24f`, `bdab2ac`): a bypass flag on `approve-gate` that contradicts `srd.md:3836` (EDMV3-90 AC1, a Won't-Have), has no ticket in any pack, and passes both enforcement mechanisms only because they ban flag *names* rather than the class. `decisions.md` D57 records the decision but does not amend the SRD, and `tickets/README.md:688` still asserts the boundary intact.
