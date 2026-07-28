# Epic E10 -- WS10: Delete list

**Wave**: C (v3.0.0 -> v3.1.0)
**SRD requirements**: EDMV3-80 .. EDMV3-85 (6)
**Tickets**: EDMV3-T57 .. EDMV3-T60 (4)

R8, F11, D12. Every item here is either shipped-to-users dead weight or documentation debt -- and a
wired no-op is worse than no wiring, because it implies a capability that does not exist.

The epic is mutually independent of E7, E8 and E9 and can be batched opportunistically anywhere in
wave C, with the single ordering constraint that EDMV3-T60 runs last.

All commands are run from the repository root unless stated otherwise.

---

## EDMV3-T57: Binaries and OS metadata leave the plugin directory

| Field | Value |
|---|---|
| Epic | E10 -- Delete list |
| Wave | C |
| Priority | Should Have |
| Size | S |
| SRD Refs | EDMV3-80 |
| Depends On | EDMV3-T21 |
| Ships-with | -- |
| Target Components | `plugins/edm/EDM_Plugin_Presentation.pptx` (676KB), `plugins/edm/EDM_Plugin_User_Guide.docx` (32KB), `plugins/edm/.DS_Store`, `plugins/edm/skills/.DS_Store`, `.gitignore`, `docs/` (repository root), `plugins/edm/README.md`, `.gitlab-ci.yml` |

### Description

F11. 708KB of binaries plus macOS metadata ship inside the plugin directory to every installer.
Demoted to Should Have in SRD v1.1.0: relocating two binaries and deleting OS metadata is distribution
hygiene, nothing in the initiative depends on it, and it is worth doing without being a release
blocker.

The CI check is the part with reach. The file-type ban binds **all six plugins in the marketplace**,
not only `edm`, so it cannot become blocking until a clean pre-merge scan across `git`, `jira`,
`ada-tablo`, `web-cms`, `myday` and `edm` is recorded.

### Acceptance Criteria

- [ ] AC1 (positive, history preserved): `EDM_Plugin_Presentation.pptx` and
      `EDM_Plugin_User_Guide.docx` are moved to a repository `docs/` location outside `plugins/edm/`
      using `git mv`, so history is preserved.
      Verify: `git log --follow --oneline docs/EDM_Plugin_Presentation.pptx | wc -l` is greater than
      1, and `test ! -e plugins/edm/EDM_Plugin_Presentation.pptx`.
- [ ] AC2 (discoverability preserved): `plugins/edm/README.md` links to their new location so they
      remain discoverable.
      Verify: `grep -n 'EDM_Plugin_Presentation\|EDM_Plugin_User_Guide' plugins/edm/README.md`
      returns links to the new paths.
- [ ] AC3 (positive, metadata deleted from index and tree): `plugins/edm/.DS_Store` and
      `plugins/edm/skills/.DS_Store` are deleted from the index and the working tree.
      Verify: `git ls-files plugins/edm | grep -c '\.DS_Store'` returns 0 and
      `find plugins/edm -name '.DS_Store' | wc -l` returns 0.
- [ ] AC4 (recurrence prevented): `.DS_Store` is added to the repository `.gitignore`.
      Verify: `grep -n '^\.DS_Store$' .gitignore` and
      `touch plugins/edm/.DS_Store && git status --porcelain | grep -c 'DS_Store'` returns 0
      (remove the file afterwards).
- [ ] AC5 (negative, CI ban across all six plugins): a CI check asserts that no file matching
      `.DS_Store`, `*.pptx` or `*.docx` exists anywhere under `plugins/`. This binds all six
      marketplace plugins.
      Verify: `git ls-files -- plugins | grep -icE '\.(pptx|docx)$|(^|/)\.DS_Store$'` returns 0, and
      the CI job fails when a matching file is committed. The developer-side hygiene equivalent,
      `find plugins -name '.DS_Store' -o -name '*.pptx' -o -name '*.docx' | wc -l`, should also
      return 0 and is worth running locally, but it is not the shipped assertion.
      **Amended per D30 (accepted deviation, recorded).** The shipped CI check
      (`.gitlab-ci.yml:111`) scans `git ls-files -- plugins`, not a plain `find`. That is a
      deliberate, accepted choice, not drift: the failure this control exists to prevent (F11) is
      banned files *shipping* inside the plugin, shipping means tracked, and `git ls-files` measures
      exactly that. On a runner the two forms are equivalent anyway -- a GitLab checkout carries the
      tracked tree and nothing else -- while `find` adds one failure mode a **blocking** job should
      not have: going red on a runner-local artifact that is not and never will be committed. The
      untracked case is covered by `.gitignore:3` (a bare, unanchored `.DS_Store`, so it matches at
      every depth), and a deliberate `git add -f` override lands the file in `git ls-files`, where
      this check catches it. Both forms measured 0 on the live tree 2026-07-28. See D30 for the full
      argument; this supersedes the Technical Note below.
- [ ] AC6 (pre-merge scan recorded before the check blocks): the ticket records a clean pre-merge scan
      across `git`, `jira`, `ada-tablo`, `web-cms`, `myday` and `edm` before the check becomes
      blocking, so an unrelated plugin's stray file does not red the pipeline on merge day.
      Verify: the ticket's QC evidence contains the `find plugins -name ...` output per plugin, all
      empty.
- [ ] AC7 (negative, size ceiling on what replaces it): the same check asserts a total-directory-size
      ceiling for `plugins/edm/evals/` (EDMV3-T22 AC3), so the tree this initiative adds cannot
      quietly replace the 708KB it removes.
      Verify: `du -sk plugins/edm/evals` is under the documented ceiling, and the CI job fails when
      it is not.
- [ ] AC8 (evidence recorded): the plugin directory size after the change is recorded in the merge
      request as evidence.
      Verify: `du -sh plugins/edm` output is pasted into the MR description alongside the
      pre-change figure.
- [ ] AC9: `claude plugin validate` passes after the move.
      Verify: `claude plugin validate plugins/edm/`.
- [ ] AC10 (the check flips to blocking, in this merge request): EDMV3-T21 AC3 added the file-type
      job to the wave-A pipeline with `allow_failure: true` and nothing else, because
      `plugins/edm/` itself carried two of the banned files at that point. This ticket removes them,
      records the clean six-plugin scan (AC6), and **flips the job to blocking in the same merge
      request** by deleting `allow_failure` from it. Without this AC the non-blocking state has no
      tracking edge and nothing ever flips it -- the check would sit permanently advisory, which is
      the shape of a control that exists on paper.
      Verify: `grep -n 'allow_failure' .gitlab-ci.yml` no longer returns the file-type job (it
      remains only on `claude plugin validate` tier 2 and the eval job), the job is red on a branch
      that adds a `.DS_Store` under any plugin, and green on the default branch. The flip is
      cross-checked at wave-C close by EDMV3-T66 AC11.

### Technical Notes

- Use `git mv`, not `mv` plus `git add` -- AC1's `--follow` check depends on rename detection.
- The `docs/` destination is the repository root's `docs/`, which does not exist yet in this tree.
  Creating it is part of this ticket.
- ~~AC5's check should be a plain `find` in the lint stage, not a `git ls-files` check: an untracked
  `.DS_Store` in a runner checkout is not the failure case, but a tracked one is, and `find` catches
  both while `.gitignore` (AC4) prevents the untracked case from becoming tracked.~~
  **Overruled by D30 (2026-07-28).** The `git ls-files` form shipped and is accepted. This note's own
  premise concedes the point: an untracked `.DS_Store` in a runner checkout "is not the failure
  case", so the extra reach buys nothing on the surface the job actually runs on, and it costs a
  false-red mode that a blocking job should not carry. The untracked-becomes-tracked path stays
  closed by `.gitignore:3` plus the fact that a `git add -f` override lands in `git ls-files`
  anyway. See D30 and the amendment on AC5 above.

### Out of Scope

- Any other plugin's content. This ticket scans all six and fixes only `edm`; a stray file elsewhere
  is recorded as a finding and given its own ticket.
- The evals size ceiling's definition -- EDMV3-T22 sets the number; this ticket enforces it.

---

## EDMV3-T58: The grant ritual, the `TaskCompleted` hook, and the no-op handler are deleted

| Field | Value |
|---|---|
| Epic | E10 -- Delete list |
| Wave | C |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV3-81, EDMV3-82 |
| Depends On | EDMV3-T03 |
| Ships-with | -- |
| Target Components | `plugins/edm/skills/implement/SKILL.md:162-172` (the ritual, including the two `grep` commands at `:166-167` and the pass/fail conditions), `plugins/edm/hooks/hooks.json:122-131` (the `TaskCompleted` block, whose command is at `:127`), `plugins/edm/bin/edm-state:753-758` (`cmd_record_task_duration`), the dispatch entry at `:1991`, the `--help` header line at `:13`, `plugins/edm/CLAUDE.md` (`bin/` table and Hooks behavior table) |

### Description

Two deletions of the same shape: a ceremony that should have been a test, and a wire that goes
nowhere.

R2 and R8. `skills/implement/SKILL.md:162-172` is a permanent manual step in the Phase 6 done-checklist
telling the model to re-grep one agent's frontmatter on every future initiative, forever. It is the
instance-fix response to a class defect, and `bin/edm-check-grants` (EDMV3-T03) is the class-level
replacement -- which is why this ticket depends on it. The test must exist before the ritual it
replaces is deleted.

`hooks/hooks.json:122-131` wires `TaskCompleted` to `edm-state record-task-duration`, and
`cmd_record_task_duration` is an admitted no-op whose comment says accumulation "is not yet
implemented". A wired no-op is documentation debt: it implies a capability that does not exist.

### Acceptance Criteria

- [ ] AC1 (positive, ritual removed): lines 162-172 of `skills/implement/SKILL.md` are removed
      entirely, including the two `grep` commands and the pass and fail conditions.
      Verify: `grep -c 'edm-test-coverage-auditor.md' plugins/edm/skills/implement/SKILL.md` returns
      0, asserted by
      `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "implement no longer names
      edm-test-coverage-auditor").
- [ ] AC2 (negative, nothing else lost from the checklist): the Declare Done checklist retains all
      other items.
      Verify: `git diff plugins/edm/skills/implement/SKILL.md | grep '^-' | grep -c '^- \[ \]'`
      matches only the ritual's own items, listed in the MR description.
- [ ] AC3 (the replacement is strictly wider): `bin/edm-check-grants` covers
      `edm-test-coverage-auditor`, so the protection the ritual provided is strictly preserved and
      extended to all **30** agents.
      Verify: `bash plugins/edm/bin/edm-check-grants 2>&1 | grep -c 'edm-test-coverage-auditor'`
      shows the agent is inspected, and the agent count checked equals
      `ls plugins/edm/agents/*.md | wc -l`.
- [ ] AC4 (substitution recorded with a verified count): the merge request records the substitution
      explicitly -- ceremony removed, test added, coverage widened from 1 agent to 30. The count is
      verified against `ls plugins/edm/agents/*.md | wc -l` at merge time rather than copied from any
      document.
      Verify: the MR description contains the command output alongside the claim.
- [ ] AC5 (positive, hook block removed, JSON still valid): the `TaskCompleted` block is removed from
      `hooks/hooks.json`, leaving the remaining hook families structurally valid JSON.
      Verify: `jq -e . plugins/edm/hooks/hooks.json >/dev/null && jq -r '.hooks|keys[]' plugins/edm/hooks/hooks.json | wc -l`
      returns 6.
      **Note (spec defect, no code change needed).** The command originally read `jq -r 'keys[]'`,
      which enumerates the *top-level* keys of `hooks.json`. There is exactly one -- `hooks` -- so it
      returns 1, not 6, no matter how many hook families survive. The six families live one level
      down, under `.hooks`. The corrected filter is `jq -r '.hooks|keys[]'`. Confirmed 2026-07-28:
      the corrected form prints 6 (`PreCompact`, `PreToolUse`, `SessionStart`, `Stop`,
      `SubagentStop`, `UserPromptExpansion`).
- [ ] AC6 (positive, handler and its three references removed): `cmd_record_task_duration` is removed
      from `bin/edm-state`, along with its dispatch entry at `:1991` and its `--help` header line at
      `:13`.
      Verify: `grep -rl 'record_task_duration\|record-task-duration' plugins/edm/bin/ | wc -l`
      prints 0. (`grep -c` on a single file prints `0` but exits 1, failing a `set -e` verification
      block while reporting the right answer.)
- [ ] AC7 (negative, the subcommand now errors): `edm-state record-task-duration` exits non-zero with
      the standard unknown-subcommand message.
      Verify: `edm-state record-task-duration TESTX 2>&1; echo "exit=$?"` prints the unknown-
      subcommand message and a non-zero exit.
- [ ] AC8 (docs updated, count corrected): `record-task-duration` is removed from the `CLAUDE.md`
      `bin/` table subcommand list, the subcommand count is corrected, and the Hooks behavior table
      drops the `TaskCompleted` row.
      Verify: `grep -c 'record-task-duration\|TaskCompleted' plugins/edm/CLAUDE.md` returns 0, and
      the documented subcommand count matches the dispatch table.
- [ ] AC9 (negative, class-wide grep): `grep -rn 'record-task-duration\|TaskCompleted' plugins/edm/`
      returns only `CHANGELOG.md` history entries.
      Verify: `grep -rn 'record-task-duration\|TaskCompleted' plugins/edm/ | grep -vc CHANGELOG.md`
      returns 0.
- [ ] AC10: `claude plugin validate` passes and all smoke suites remain green.
      Verify: `claude plugin validate plugins/edm/ && bash plugins/edm/bin/tests/run-all.sh`.
- [ ] AC11 (prose-change convention, EDMV3-69): the ritual at `skills/implement/SKILL.md:162-172` is
      prompt text, so the merge request shows before and after for the deleted block plus one
      sentence on why removing it is better than keeping it -- naming `bin/edm-check-grants` as the
      strictly wider replacement and the 1-agent-to-30-agent coverage change from AC4. A deletion
      still gets a before/after: the "after" is the surrounding checklist with the block gone, which
      is what makes AC2's "nothing else lost" reviewable.
      Verify: the MR description contains the before/after block and the rationale sentence.

### Technical Notes

- The ritual deletion is ordered strictly after EDMV3-T03. Deleting a protection before its
  replacement exists is the failure mode this initiative is built to prevent, and the SRD's Section
  11.2 records the edge explicitly.
- Removing the `TaskCompleted` key drops the hook family count from 7 to 6. That number appears in
  `plugins/edm/CLAUDE.md` and in the SRD's inventory; AC8 covers the former, and the latter is a
  historical document that is not edited.
- The `--help` header line at `:13` is inside the range `usage()` prints. EDMV3-T61 replaces that
  hardcoded range with sentinels; if T61 lands first, this deletion is simply a line removal inside
  the sentinels.

### Out of Scope

- The `bin/edm-check-grants` script itself -- EDMV3-T03 (wave A).
- The `monitors/watch-impl` decision -- EDMV3-T59.
- The `--help` sentinel refactor -- EDMV3-T61.

---

## EDMV3-T59: `lifecycle_mode=partial` is removed and the monitor is documented or deleted

| Field | Value |
|---|---|
| Epic | E10 -- Delete list |
| Wave | C |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV3-83, EDMV3-84 |
| Depends On | -- |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/edm-state:1433` (`cmd_set_mode`, the `lifecycle_mode` enum validation), `:419` (`state_anomalies`), `:905` (`cmd_watch_impl`), the dispatch entry and `--help` line for `watch-impl`, `plugins/edm/monitors/monitors.json:1-8`, `plugins/edm/CLAUDE.md` (mode-family field table), `SRD/edm/EDMV3__prompt-streamline/decisions.md` |

### Description

D12. `partial` is a legal `lifecycle_mode` value accepted by `cmd_set_mode` with no documented
sub-flow anywhere -- a dead value, not an unshipped feature.

R8, marked `[inferred]` in the review: `monitors/monitors.json` registers `edm-impl-progress` running
`edm-state watch-impl`, which polls `git log` in a loop. Whether the monitor lifecycle is host-managed
was not confirmed, so the decision requires a check before action. That is why the ticket carries both
branches rather than pre-deciding.

The two ship together because both are enum-or-wiring cleanups touching `cmd_set_mode`'s neighbourhood
and the same `CLAUDE.md` tables, and because both are conditional on preserving existing state files.

### Acceptance Criteria

- [ ] AC1 (positive, enum narrowed): `partial` is removed from the `lifecycle_mode` enum validation in
      `cmd_set_mode`. The remaining values are `standard`, `fast-track` and `fix-pack`.
      Verify: `sed -n '1433,1470p' plugins/edm/bin/edm-state` shows the three-value enum.
- [ ] AC2 (negative, setting it is refused): `edm-state set-mode <PREFIX> lifecycle_mode partial`
      exits non-zero listing the valid values, and mutates nothing.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "set-mode lifecycle_mode partial
      refused" plus `check_state_unchanged`).
- [ ] AC3 (C-4, existing files still readable): any existing state file carrying
      `lifecycle_mode: "partial"` continues to be readable -- reads do not error, and
      `edm-state validate` reports it as an anomaly with a remediation instruction rather than hard
      failing.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "legacy lifecycle_mode partial reads
      and reports an anomaly").
- [ ] AC4 (docs): the `CLAUDE.md` mode-family field table drops `partial` from the `lifecycle_mode`
      row.
      Verify: `grep -n 'lifecycle_mode' plugins/edm/CLAUDE.md` shows the three remaining values.
- [ ] AC5 (negative, class-wide grep): `grep -rn 'lifecycle_mode.*partial' plugins/edm/` returns only
      the validation error message, the anomaly text and `CHANGELOG.md` history.
      Verify: `grep -rn 'lifecycle_mode.*partial' plugins/edm/ | grep -vc 'CHANGELOG.md\|die \|anomaly\|bin/tests/\|LEGACY_LIFECYCLE_MODE\|== "partial"'`
      returns 0.
      **Note (spec defect, no code change needed).** The exclusion filter originally carved out only
      `CHANGELOG.md`, `die ` and `anomaly`, and therefore had no `bin/tests/` carve-out -- which puts
      it in direct conflict with this ticket's own AC3, which *mandates* C-4 regression tests proving
      that an existing state file carrying `lifecycle_mode: "partial"` still reads without error.
      Those tests cannot be written without the literal string, so satisfying AC3 guarantees AC5
      fails. Measured 2026-07-28: the original filter returns **13**. Eleven are the AC3-mandated
      regression cases (`bin/tests/wave4a-smoke.sh:186`, `wave6-smoke.sh:2107-2147`,
      `wave7-smoke.sh:919-922`). The remaining two are the survivors this AC's own prose already
      names as expected, which the filter's tokens simply fail to match: `bin/edm-state:487`, the
      C-4 legacy-read branch (`if [[ "$lifecycle_mode" == "partial" ]]`, which coerces to
      `standard`), and `bin/edm-state:908`, the `LEGACY_LIFECYCLE_MODE` anomaly message (the word
      `anomaly` never appears on that line). Adding the three missing tokens brings it to 0 and makes
      the AC assert what it means: no *production* code path outside the documented legacy-read
      branch and its anomaly message still treats `partial` as a live enum value.
- [ ] AC6 (negative, the unrelated PARTIAL vocabulary is untouched): the distinct and unrelated
      PARTIAL *verdict* vocabulary is unaffected.
      Verify: `bash plugins/edm/bin/tests/wave6-smoke.sh` (case "partial_verdict_map and the QC
      PARTIAL verdict are unaffected") is green, and
      `grep -c 'partial_verdict_map' plugins/edm/bin/edm-state` is unchanged.
- [ ] AC7 (monitor lifecycle confirmed before action): the monitor lifecycle is confirmed -- whether
      Claude Code starts, stops and reaps `on-skill-invoke` monitors, and what happens when the skill
      ends or the session is compacted. The finding is recorded in `decisions.md` **before** any
      deletion.
      Verify: `grep -n 'monitor lifecycle' SRD/edm/EDMV3__prompt-streamline/decisions.md` returns the
      finding with its date, committed before the code change.
- [ ] AC8 (branch A, host-managed): if host-managed, `CLAUDE.md` gains a short subsection documenting
      the monitor's lifecycle, its polling interval, and how a user stops it.
      Verify: `grep -n 'edm-impl-progress' plugins/edm/CLAUDE.md` returns the subsection with all
      three facts.
- [ ] AC9 (branch B, not host-managed): if not host-managed, the monitor entry and `cmd_watch_impl`
      are removed along with the dispatch entry and the `--help` line, and `CLAUDE.md` is updated.
      Verify: on branch B, `grep -c 'watch-impl\|watch_impl' plugins/edm/bin/edm-state plugins/edm/monitors/monitors.json plugins/edm/CLAUDE.md`
      returns 0 for all three.
- [ ] AC10 (negative, either branch): no unkillable-looking loop with no documented owner remains.
      Verify: whichever branch was taken, `grep -rn 'while true\|sleep ' plugins/edm/bin/edm-state`
      returns either nothing or a loop whose owner is named in `CLAUDE.md`.
- [ ] AC11 (exactly one branch, and which is stated): the ticket states which branch was taken and
      links the `decisions.md` entry. A ticket closing without naming the branch is not done.
      Verify: the ticket's QC evidence names the branch.

### Technical Notes

- **Known SRD ambiguity.** EDMV3-84 is conditional on a monitor-lifecycle finding that has not been
  made. AC7 makes the finding a precondition rather than an assumption, and AC11 forces the branch to
  be recorded.
- AC6 exists because the two `partial` vocabularies are easy to confuse in a grep-driven deletion.
  `lifecycle_mode: "partial"` is dead; the QC `PARTIAL` verdict is load-bearing and is the subject of
  four wave-B tickets.
- `edm-state validate` reporting the legacy value as an anomaly requires the anomaly to be
  informational (EDMV3-T05) so a legacy initiative does not start exiting 3 on `validate`.

### Out of Scope

- Removing `mode` enum values. Only `lifecycle_mode` is narrowed.
- Any change to the PARTIAL verdict lifecycle -- wave B, EDMV3-T18 / T31 / T32 / T33.
- Rewriting `cmd_watch_impl`'s polling logic on branch A. Document it or delete it; do not improve
  it.

---

## EDMV3-T60: The plugin validates cleanly after every deletion

| Field | Value |
|---|---|
| Epic | E10 -- Delete list |
| Wave | C |
| Priority | Must Have |
| Size | XS |
| SRD Refs | EDMV3-85 |
| Depends On | EDMV3-T57, EDMV3-T58, EDMV3-T59, EDMV3-T61 |
| Ships-with | -- |
| Target Components | `plugins/edm/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (the `edm` entry: version at `:35`, `skills` at `:36-49`, `agents` at `:51-82`), `plugins/edm/hooks/hooks.json`, `plugins/edm/monitors/monitors.json`, `.gitlab-ci.yml` (validate stage) |

### Description

Deletions touch the manifest surface -- hooks, monitors, subcommands, files -- and a broken manifest
is a worse outcome than the debt being removed. This ticket is the epic's gate: it runs after all
three deletion tickets and proves none of them left a dangling reference.

### Acceptance Criteria

- [ ] AC1 (positive, after each deletion): `claude plugin validate` passes after each deletion in this
      epic, with no new warnings relative to the recorded v2.0.0 baseline.
      Verify: `claude plugin validate plugins/edm/` run after T57, after T58 and after T59, with the
      warning count compared against the baseline recorded in `plugins/edm/CHANGELOG.md`. All three
      results are recorded in the ticket.
- [ ] AC2 (positive, manifest is bidirectional): `.claude-plugin/marketplace.json` and
      `plugins/edm/.claude-plugin/plugin.json` list exactly the skills and agents that exist on disk
      -- no entry for a deleted file, no file without an entry.
      Verify: `diff <(jq -r '.plugins[]|select(.name=="edm").skills[]' .claude-plugin/marketplace.json | sed 's#^\./skills/##' | sort) <(cd plugins/edm && for d in skills/*/; do [ -f "${d}SKILL.md" ] && basename "$d"; done | sort)`
      prints nothing, and the equivalent for `agents`. This is the same normalization the CI job
      already performs; `.gitlab-ci.yml:314` is the reference implementation.
      **Note (spec defect, no code change needed).** The command originally diffed the raw manifest
      values against `ls -d skills/*/SKILL.md`. Those are two different shapes and can never match:
      the manifest declares `./skills/orchestrator` (leading `./`, no filename) while the `ls` form
      yields `skills/orchestrator/SKILL.md`. Confirmed 2026-07-28 -- the un-normalized diff reports
      all 14 skills as differing on a tree where the manifest and disk agree perfectly, so a future
      reader sees 14 phantom mismatches and may "fix" a correct manifest. The comparison is only
      meaningful once both sides are reduced to bare skill names, which is what
      `.gitlab-ci.yml:314`'s `sed 's#^\./skills/##'` plus `basename` loop does, and why the tier-1
      `validate:manifest` job passes while the AC's literal command does not.
- [ ] AC3 (negative, no dangling hook command): `hooks/hooks.json` is valid JSON and every remaining
      hook command resolves to an existing subcommand.
      Verify: `jq -e . plugins/edm/hooks/hooks.json >/dev/null` and
      `for c in $(jq -r '.. | .command? // empty' plugins/edm/hooks/hooks.json | grep -o 'edm-state [a-z-]*' | awk '{print $2}' | sort -u); do edm-state --help | grep -q "$c" || echo "DANGLING: $c"; done`
      prints nothing.
- [ ] AC4 (negative, no dangling monitor command): the same check applies to
      `monitors/monitors.json` on the branch where it survives.
      Verify: the equivalent loop over `monitors/monitors.json` prints nothing, or the file is absent
      on branch B of EDMV3-T59.
- [ ] AC5: all smoke suites remain green.
      Verify: `bash plugins/edm/bin/tests/run-all.sh; echo "exit=$?"` prints `exit=0`.
- [ ] AC6 (CI covers it): the CI validate stage covers all of the above, so a future deletion cannot
      reintroduce the class.
      Verify: `grep -n 'marketplace.json' .gitlab-ci.yml` shows the tier-1 `jq` manifest check
      exercising AC2's comparison.
- [ ] AC7 (negative, the deleted subcommand is genuinely gone from help) **(cross-check, owned by
      EDMV3-T61)**: the help block contains no entry for a removed subcommand, checked
      bidirectionally against the dispatch table. The test is EDMV3-T61's bidirectional
      help-completeness case, which landed in wave A; this ticket exercises it after the deletions
      rather than writing a second one. The dependency on EDMV3-T61 is declared so the reuse is a
      graph edge rather than a hope -- the earlier "if T61 has not landed, run the comparison
      manually" fallback made the AC pass without the test existing.
      Verify: `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "help block and dispatch table
      agree") is green after EDMV3-T57, T58 and T59 have landed.

### Technical Notes

- This ticket writes almost no code. Its value is the ordering constraint: it must run after all
  three deletions, and its evidence is three recorded validator runs rather than one.
- AC7 reuses the bidirectional help test from EDMV3-T61 rather than writing a second one, and the
  reuse is a declared `Depends On` edge. T61 lands in wave A and this ticket is wave C, so the edge
  costs nothing and makes the reuse visible to anyone re-planning the graph.
- The v2.0.0 baseline warning count must be recorded in `CHANGELOG.md` before wave C, otherwise "no
  new warnings" is unmeasurable. EDMV3-T64 records it at wave-A close.

### Out of Scope

- Any new deletion. This ticket only verifies.
- Fixing the pre-existing warning about root `CLAUDE.md` not being runtime context. Accepted and
  unchanged in the SRD's Definition of Done.
