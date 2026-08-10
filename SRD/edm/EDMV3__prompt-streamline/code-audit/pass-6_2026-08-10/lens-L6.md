# Lens L6 -- Documentation Accuracy (Round 6, full round)

**Tooling note (CA-130's class, seventh consecutive round):** Write absent from this
lens's delivered runtime tool set. This report was transcribed by the orchestrator
from the lens agent's final message.

Scope: `plugins/edm/` in full (bin/, hooks/, evals/, skills/, agents/, docs/, CLAUDE.md, README.md, CHANGELOG.md) plus repository-root `.gitlab-ci.yml` comments.

## Direct answer to the round-6 tasking

**Yes -- this session's own remediation introduced two new, already-wrong `file:line` citations, and re-staled a third comment's factual claim.** The `G39/CA-315` durability guard added at `bin/tests/wave7-smoke.sh:7293-7320` pins only the five specific sites round 5 named, and explicitly declines a tree-wide ban (`:7296-7301`). That scoping decision is defensible, but it left the class live: `bin/edm-init:163-164` (added by CA-314's fix) carries two fresh line-number citations that resolved to the wrong code the day they were written, and `bin/tests/wave7-smoke.sh:5586-5590` (added by CA-256's fix) asserts a formula that CA-305's fix -- landed in the same round -- deleted.

## Cross-round ledger re-verification

| Ledger ID | Verdict |
|---|---|
| CA-168 / L6-001 | **FIXED** -- `docs/audit-patterns/SOURCES.md:19` now states the table is hand-maintained and that nothing writes to the file |
| CA-268 / L6-002 | **FIXED** -- `edm-state:633-643` now cites the trap exemplars by function/site name, with the re-staling history recorded inline |
| CA-302 | **Table FIXED; three sibling sites still assert the superseded figures -- raised as L6-002 below** |
| CA-306 / L6-006 | **FIXED, both halves** -- `edm-state:601-612` and `:1057-1066` both accurate |
| CA-315 site 1 (`run-eval.sh` -> write_atomic trap layer) | **FIXED** -- by-name at `run-eval.sh:218` |
| CA-315 site 2 (`wave7-smoke.sh` -> `--path` mode) | **FIXED** -- by-name at `wave7-smoke.sh:1032` |
| CA-315 site 3 (`wave6-smoke.sh` -> `convergence_exempt()`) | **FIXED** -- by-name at `wave6-smoke.sh:3909`, with the by-name rationale stated |
| CA-315 site 4 (`edm-state:415` docstring "above") | **FIXED** -- `edm-state:423-424` now says "further DOWN this file" |
| CA-315 site 5 (`run-all.sh` bare-capture rationale) | **FIXED** -- `run-all.sh:10-16` matches the shipped loop at `:104-105` |
| CA-316 half 1 (`CLAUDE.md` precheck) | **FIXED** -- `CLAUDE.md:847-851` states the precheck is unconditional |
| CA-316 half 2 (`evals/README.md` allow-list) | **FIXED** -- `evals/README.md:86-94` now points at the single authoritative assignment; the third formula is gone and `run-eval.sh:374-382` reproduces `:393` exactly |
| CA-130 | **REPRODUCES -- seventh consecutive round** |

## Findings (L6: Documentation Accuracy)

**L6-001 (P1) -- `plugins/edm/bin/tests/wave7-smoke.sh:5586-5590`: the comment asserts a marker-name formula that `edm-state` no longer contains, cites a stale line for it, and claims derived provenance it does not have.**

The comment reads:

```
  # G15/CA-256 (round 5): the G49 flock-timeout marker, using the SAME "${lockfile}.timeout.$$"
  # formula with_state_lock's flock branch uses (bin/edm-state:1079) -- never a hand-typed guess.
  # This name matches neither the ".lock" nor ".lockd" shapes above by one character (it hangs
  # off ".lock", not ".lockd"), which is exactly how it escaped every existing pattern.
  local lock_timeout_marker="${lockfile}.timeout.$$"
```

Three claims, all false against the current tree:
- `with_state_lock`'s flock branch derives the marker at `bin/edm-state:1117` as `_lock_timeout_marker="${TMPDIR:-/tmp}/edm-state.lock-timeout.$$"`. G17/CA-305 moved it out of the initiative directory into `TMPDIR` **and** renamed it. `"${lockfile}.timeout.$$"` appears nowhere in `bin/edm-state`.
- `bin/edm-state:1079` is the CA-169 "never `rm -f "$lockfile"`" rationale, not the marker derivation.
- "never a hand-typed guess" is now exactly backwards: the value *is* a hand-typed legacy literal.

`bin/edm-state:2792-2796` gets this right ("G17/CA-305 (round 5) moved the marker's home to TMPDIR, so a marker created from here on never lands inside an initiative directory to begin with -- this sweep is kept regardless, as a backward-compatible cleanup for any pre-G17 marker"). Two comments about one mechanism now disagree, and the wave7 one is the misleading half: it presents a legacy-compat shape as the current derivation, so a maintainer reads the adjacent `git check-ignore` assertion at `:5606` as covering today's marker when it covers only a pre-G17 one.

Fix: rewrite `:5586-5589` to say the tested name is the **pre-G17 in-directory legacy shape**, retained for backward-compatible `.gitignore` coverage (cross-referencing `_cmd_archive_move_body`'s sweep rationale by name, not by line), and state explicitly that the current marker is derived under `TMPDIR` by `with_state_lock`'s flock branch and therefore never lands in an initiative directory. Drop `bin/edm-state:1079`.

**L6-002 (P1) -- `plugins/edm/CHANGELOG.md:41-43` and `:290`: the 3.1.0 release-notes bullet and the AC6 prose still state the pre-re-measurement figures that the same file's own T67 table declares superseded.**

`CHANGELOG.md:253-266` states: "**every figure in the table above is a fresh 20-sample nearest-rank p95 against the corrected formula, not the pre-fix numbers** ... none of the deferred 'should be re-measured' language from the prior version of this note still applies." The table then records `2,034ms p95` (AC5, `:242`) and `1.12x` with baseline 2,013ms / with-Mermaid 2,253ms (AC6, `:243`) -- and 2253/2013 = 1.119, so 1.12x is the arithmetic-consistent figure.

Two sites in the same file contradict it:
- `:41-43` (the `[3.1.0]` release-notes bullet a reader reaches first): "**`edm-lint-artifacts` was 70,168 ms** ... Now 978 ms, with the Mermaid-class ratio at 1.19x against a 1.40x ceiling." Same binary, same 30-file fixture, 978 ms vs 2,034 ms -- a 2x discrepancy.
- `:290`: "Optimizing class 4 in turn (`ea31ce8` ...) brought it to 1.19x", inside the paragraph whose other figures (2.26x, 3.40x) do match the table.

CA-302 was a P1 filed jointly by L6 and L9 whose prescription was to replace the T67 evidence figures with fresh 20-sample measurements. The table was re-measured; these three siblings were not swept, so the project's own record still asserts both numbers at once.

Fix: replace `978 ms` -> `2,034 ms p95` and `1.19x` -> `1.12x` at `:42`, and `1.19x` -> `1.12x` at `:290`; or, if 1.19x was a genuine earlier 10-sample reading, label it as such at both sites rather than leaving it stated as the current result.

**L6-003 (P2) -- `plugins/edm/bin/edm-init:163-164`: two new line-number citations, both landing on unrelated code.**

```
# .gitignore behavior (CA-314): the state backup (edm-state:691, permanent by design for
# migrate-path rollback), the lock file family (edm-state:1034-1035, deliberately never
# unlinked per CA-169) and write_atomic's transient temp files ...
```

- `edm-state:691` is the `_print_line` docstring (G38 / G28-CA-259). The state backup is `cp -p "$f" "${f}.bak"` at `edm-state:705`, inside `_rmw_state_body`.
- `edm-state:1034-1035` is `with_state_lock`'s docstring header (`# with_state_lock <lockbase> <command...>` / "Acquires an exclusive advisory lock..."). The lock-file family names appear at `:1036-1037` (docstring) and `:1040-1041` (`lockfile=`/`lockdir=`); the "deliberately never unlinked per CA-169" rationale the comment attributes to that range is at `:1079-1087`.

This is the same defect class CA-315 raised and CA-268 was re-staled by, reintroduced by CA-314's own remediation in the round that closed it.

Fix: "the state backup (written by `_rmw_state_body` in `bin/edm-state`, permanent by design for migrate-path rollback), the lock file family (`with_state_lock`'s `.lock`/`.lockd`, deliberately never unlinked -- see its CA-169 comment)". Then extend the `G39/CA-315` guard at `wave7-smoke.sh:7302-7320` with a `check_absent` on `edm-state:691` and `edm-state:1034` in `edm-init`, matching the shape already used for the other five sites.

**L6-004 (P2) -- `plugins/edm/bin/tests/wave7-smoke.sh:3777`: cites `run-eval.sh:443-460` for the containment loop; that range is the Phase-1 prompt.**

```
# Reproduces run-eval.sh:443-460's fixed containment loop verbatim, so a future edit to one and
# not the other is caught the next time this test runs against a real regression scenario.
```

`run-eval.sh:443-460` is `export EDM_SRD_ROOT="$SCRATCH_DIR/SRD"` plus the opening of the `PHASE1_PROMPT` heredoc. The containment check lives at `run-eval.sh:578-606`, with the `R*|C*` rename/copy parse the CA-007 fix added at `:590`. The citation is ~140 lines off, and the comment's stated purpose -- catching a divergence between the two copies -- is exactly what a wrong pointer defeats.

Fix: "Reproduces `run-eval.sh`'s own containment-violation parse loop (the `R*|C*` rename/copy branch, CA-007) verbatim". No line numbers.

**L6-005 (P2) -- `plugins/edm/bin/_edm-lint-lib.sh:51-54`: the "honest position on actual callers" enumerates two of three external callers.**

```
#     ... Honest position on actual callers (G40, corrected --
#     the prior wording here overstated it): only ignored_line_set has external callers today
#     (bin/edm-check-grants and bin/edm-check-vocabulary, neither of which needs the mermaid or
#     marker classes at all).
```

`bin/edm-state` is a third external caller: `ignored_line_set` at `:4530` and `:4593`, `is_ignored_line` at `:4535` and `:4599`, with its own note at `:56-57` and `:4524` naming the dependency. This same file's header at `:4-5` correctly lists `bin/edm-state` as one of the four consumers, so the file contradicts itself two paragraphs apart -- and the contradiction sits inside a clause that advertises itself as the corrected, honest version.

Fix: "(bin/edm-check-grants, bin/edm-check-vocabulary and bin/edm-state's pattern-library machinery -- none of which needs the mermaid or marker classes)".

**L6-006 (P2) -- `plugins/edm/CLAUDE.md:843-854`: the `schema_at_least()` comment-coverage split is 4/4, not 5/3, and the enumerated exception list omits a fourth site.**

The passage says "Five of the eight `schema_at_least()` call sites in `bin/edm-state` carry that comment today; three do not", then names three (`cmd_approve_gate`'s precheck, `cmd_archive`'s wave-B block, `cmd_audit_converged`).

Eight call sites confirmed: `edm-state:1957, 2019, 2082, 2148, 2598, 2695, 3393, 4061`. Canonical `# requires schema_version >= N` comments exist at `:2008, 2075, 2595, 3350, 3384` -- five comment lines, but `:3350` and `:3384` both serve the single `cmd_gate_check` site at `:3393`, so they cover **four** call sites (`2019, 2082, 2598, 3393`). Four sites lack it: the three named, plus **`cmd_phase_complete`'s phase-6 open-PARTIAL check at `:2148`**, whose nearby `:2142` reads `# ... refuses on an open PARTIAL. requires schema_version >= 2 (EDMV3-T09` -- the number in the wrong shape, mid-sentence, which is verbatim the failure mode `:852-853` calls out for `cmd_archive`.

The passage closes with "Until those three are brought into line, do not treat 'no `# requires schema_version >= N` comment here' as evidence that a check is version-independent" -- so a contributor who trusts the enumeration concludes `:2148` is covered when it is not.

Fix: change "Five ... three do not" to "Four of the eight ... four do not", and add a bullet for `cmd_phase_complete`'s phase-6 open-PARTIAL check (needs `>= 2`; the number appears mid-sentence rather than in the canonical leading form).

**L6-007 (P2) -- `plugins/edm/bin/tests/wave7-smoke.sh:7364`: the G51/CA-327 pass label mislabels four call sites as "four violation classes".**

```
    && pass "G51/CA-327 -- all four violation classes (attribution, unicode x2 platform branches, leaked-tool-tag) call the shared helper" \
```

The parenthetical names **three** classes (the fourth entry is `unicode` counted a second time for its second platform branch), and `edm-lint-artifacts --help:24-39` documents **seven** classes -- `mermaid-semicolon`, `unterminated-fence`, `scan-error` and `unreadable` do not route through `_lint_report_class_hits` at all. `CLAUDE.md`'s `bin/` table deliberately refuses to state a class count for this binary ("run `edm-lint-artifacts --help` for the authoritative, current class list rather than a count hardcoded here (a count drifts as classes are added)"), and this label is a printed, operator-visible line that hardcodes one anyway.

Fix: "all four per-class call sites (attribution, unicode on both platform branches, leaked-tool-tag) call the shared helper". The assertion itself (`-eq 4`) is correct and needs no change.

## Noted / Not Actionable

1. `edm-state:4172`'s `hooks/hooks.json:117` and `skills/implement/SKILL.md:117` both resolve correctly today (verified) -- accurate, though it is the fragile shape; recorded as at-risk, not a finding.
2. `edm-check-grants:419`'s `"hooks/hooks.json:117"` quotes the *ticket's* own citation as historical provenance, not a claim about current position.
3. `_edm-lint-lib.sh:64-75`'s two `report_violation` output examples reproduce both the 4-arg and 5-arg shapes exactly, including the documented field-order difference -- verified against `:205-225`.
4. `edm-lint-artifacts:263-265`'s "all five violation classes" against a 7-class help list: the five are the content classes; `scan-error` and `unreadable` are per-file diagnostics. Approximating, not false.
5. `run-eval.sh:362-363` lists `Read/Glob/Grep/LS/TodoWrite/Task` under "auto-accepts file edits" -- loose grouping; the operative claim (a headless run never blocks on a permission prompt) is exact.
6. `findings-ledger.jsonl` still carries `"status":"open"` / `"resolved_round":null` for CA-298..CA-327 though all were remediated this session -- ledger status transitions at round close, so this is in-flight state, not a documentation defect.
7. `.gitlab-ci.yml:58`'s "ten consumers total (`grep -c '<<: *alpine_edm'`)" -- verified exactly 10.
8. `CLAUDE.md`'s "39 subcommands" for `edm-state` -- verified 39 dispatcher arms (`:5146-5184`) and 39 names listed. (Round 5 recorded 40/40; the current pair is self-consistent at 39.)
9. `run-all.sh:10-16`'s CA-074/CA-315 rationale -- verified against the shipped loop at `:104-105`; the "seven-suite floor" at `:37` matches the seven `*-smoke.sh` suites on disk.
10. `_edm-lint-lib.sh:4-5`'s "four consumers" -- all four verified sourcing it (`edm-lint-artifacts:67`, `edm-check-grants:66`, `edm-check-vocabulary:60`, `edm-state:63`).
11. `README.md:219-224`'s gitignore block byte-matches `edm-init:169-174`'s heredoc; its `with_state_lock` cross-reference is by name.
12. `README.md:212`'s "the advisory lock file" (singular) against a `.edm-state.lock*` glob covering `.lock`, `.lockd`, `.lockd.stale.PID` -- deliberate simplification for an operator-facing reference block.
13. **CA-130 reproduces a seventh consecutive round** (see Meta).

## Meta

`Write` was again absent from this lens's delivered runtime tool set despite the frontmatter grant (ledger CA-130, **seventh consecutive round**). Delivered set was `Read, Glob, Grep, WebFetch, WebSearch, TaskStop` -- no `Write`, `Edit`, or `Bash`, so neither `lens-L6.md` nor `lens-L6.jsonl` could be written and no smoke-suite run was possible from inside this lens. Report delivered as reply text for orchestrator transcription. Every finding above is verified by static read of the current tree; no assertion depends on a suite run.

**Lens-level observation.** The dominant class held at 5 of 7 findings (L6-001, L6-003, L6-004 stale citations; L6-005, L6-006 miscounted enumerations), and three of those five were introduced *by round 5's own remediation commits* (CA-314 -> L6-003, CA-256 -> L6-001, G40 -> L6-005). The `G39/CA-315` guard works for the five sites it pins, but its scoping rationale at `wave7-smoke.sh:7296-7301` -- that a general ban is not statically enforceable without false positives -- has now been falsified in the narrow case: every new instance this round is a citation of *this plugin's own* `bin/` or `evals/` files by relative name plus digits. A ban restricted to that shape (`\b(edm-state|edm-init|edm-lint-artifacts|edm-check-\w+|run-eval\.sh|score-artifacts\.sh|_edm-\w+\.sh|wave\d\w*-smoke\.sh|run-all\.sh):\d+`) inside comment lines, with an allowlist for the two DATA uses (`.gitlab-ci.yml:198`, the ticket-provenance quote at `edm-check-grants:419`), would have caught L6-003 and L6-004 mechanically. Recommend that as the durability half of this round's remediation; the alternative is an eighth round of the same finding.

Two of the seven (L6-005, L6-006) are a distinct sub-class worth naming separately: **self-describing counts inside prose that also enumerates its own exceptions.** Both were wrong by exactly one because a later edit added a call site or a caller without touching the count. Both would be cheap to convert to a computed assertion in the existing smoke suites (`grep -c` on the call sites vs. the number in the prose), which is the shape `G51`'s own `-eq 4` check already uses successfully.
</content>
