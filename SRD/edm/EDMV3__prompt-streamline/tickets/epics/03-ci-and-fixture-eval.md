# Epic E3 -- WS3: CI and fixture eval

**Wave**: A (v2.0.0 -> v2.1.0)
**SRD requirements**: EDMV3-23 .. EDMV3-29, EDMV3-119 (8)
**Tickets**: EDMV3-T19 .. EDMV3-T23 (5)

R7. CI locks WS1 and WS2 in place, and the fixture eval is WS5's regression harness. Both must
precede the dispatcher refactor. The plugin that mandates test coverage for its users has none for
itself: the four smoke suites pass 76/76 and run only when someone remembers.

All commands are run from the repository root unless stated otherwise.

---

## EDMV3-T19: `_harness.sh` gains the helpers three new suites would otherwise hand-roll

| Field | Value |
|---|---|
| Epic | E3 -- CI and fixture eval |
| Wave | A |
| Priority | Should Have |
| Size | S |
| SRD Refs | EDMV3-119 |
| Depends On | -- |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/tests/_harness.sh` (33 lines today: `pass` at `:11`, `fail` at `:12`, `check` at `:15`, `check_absent` at `:25`), consumed by `plugins/edm/bin/tests/wave6-smoke.sh` and `wave7-smoke.sh` (both new) |

### Description

`bin/tests/_harness.sh` is 33 lines offering `pass`, `fail`, `check` and `check_absent`. Every new
case in EDMV3-02, EDMV3-15, EDMV3-21 and EDMV3-57 needs the same three things it does not provide: a
scratch git repository with cleanup on failure, a "this command must exit non-zero with message X"
assertion, and a byte-identity check on a state file. Writing them three times is the DRY defect
lens L10 exists to catch, in the test suite of the plugin that ships L10.

This ticket is first in the epic and is a dependency of EDMV3-T01, EDMV3-T09, EDMV3-T16 and
EDMV3-T44. Land it before any of them.

### Acceptance Criteria

- [ ] AC1 (positive): `_harness.sh` gains `with_scratch_repo <fn>` -- creates a temp directory,
      `git init`s it, commits an initial file, runs the supplied function with the directory as the
      working tree and `EDM_SRD_ROOT` pointed inside it.
      Verify: write a throwaway suite calling `with_scratch_repo` and confirm
      `edm-init --product demo --description h TESTH` scaffolds inside the temp tree, not the
      repository.
- [ ] AC2 (negative, cleanup on every exit path): the scratch tree is removed on exit **including
      on failure and on interrupt**, so a failing test leaves no residue in the developer's working
      tree.
      Verify: run a suite whose test function returns 1, then run one that is interrupted with
      `SIGINT`, and confirm `ls /tmp | grep edm-scratch` returns nothing after each and
      `git status --porcelain` prints nothing new.
- [ ] AC3 (`PATH` is required, not cosmetic): `with_scratch_repo` prepends `plugins/edm/bin` to
      `PATH`, because `bin/edm-init:139` invokes `edm-state` and `:60` invokes
      `edm-validate-prefix` **by bare name**, unlike the existing suites which call `"$EDM_STATE"`
      by absolute path.
      Verify: inside `with_scratch_repo`, `command -v edm-state` resolves to the plugin's copy.
- [ ] AC4 (positive and negative, `check_fails`): `_harness.sh` gains
      `check_fails <label> <expected-message-substring> <cmd...>` asserting the command exits
      non-zero **and** that its combined output contains the substring. An assertion on the exit
      code alone would pass on an unrelated failure, which is the failure mode that matters for a
      suite full of must-fail cases.
      Verify: `check_fails "t" "no such" ls /definitely-not-here` passes, and
      `check_fails "t" "wrong-substring" ls /definitely-not-here` fails.
- [ ] AC5 (`check_state_unchanged`): `_harness.sh` gains
      `check_state_unchanged <state-file> <cmd...>` -- hashes the file, runs the command, re-hashes,
      and asserts byte identity. EDMV3-12, -13 and -14 each require exactly this.
      Verify: `check_state_unchanged <f> true` passes and
      `check_state_unchanged <f> sh -c 'echo x >> '<f>` fails.
- [ ] AC6 (no regression in the existing suites): the four existing helpers keep their current
      signatures and behaviour, and the four existing suites are not modified by this ticket.
      Verify: `bash plugins/edm/bin/tests/wave3-smoke.sh && bash plugins/edm/bin/tests/wave4a-smoke.sh && bash plugins/edm/bin/tests/wave4b-smoke.sh && bash plugins/edm/bin/tests/wave5-smoke.sh`
      all green, and `git diff --stat plugins/edm/bin/tests/wave*.sh` is empty.
- [ ] AC7 (bash 3.2): the new helpers use no associative arrays, no `mapfile`, no `{fd}`
      redirection, and pass `bash -n`.
      Verify: `bash -n plugins/edm/bin/tests/_harness.sh` and
      `grep -nE 'declare -A|mapfile|readarray' plugins/edm/bin/tests/_harness.sh` returns nothing.
- [ ] AC8 (no local copies): the helpers are used by EDMV3-T01, EDMV3-T09, EDMV3-T16 and
      EDMV3-T44 rather than reimplemented.
      Verify: `grep -c 'mktemp -d' plugins/edm/bin/tests/wave6-smoke.sh plugins/edm/bin/tests/wave7-smoke.sh`
      returns 0 for both once those suites exist.

### Technical Notes

- Cleanup on interrupt needs `trap 'rm -rf "$dir"' EXIT INT TERM` set *inside* `with_scratch_repo`
  before the function body runs, and restored afterwards so nested calls do not clobber each other.
  bash 3.2 has no `trap -p` inheritance semantics worth relying on -- keep the nesting depth at one.
- `check_state_unchanged` should use `shasum -a 256` with a fallback to `sha256sum`, matching the
  macOS/Linux divergence handling the plugin already uses elsewhere (EDMV3-106).
- Do not add a sixth helper "while you are in there". The three named here are the ones with three
  callers each.

### Out of Scope

- Any change to the four existing suites (explicitly forbidden by AC6).
- The `run-all.sh` aggregator -- EDMV3-T20.
- Creating `wave6-smoke.sh` or `wave7-smoke.sh` -- EDMV3-T01 and EDMV3-T09 create them respectively.

---

## EDMV3-T20: Smoke aggregation and repository-wide lint

| Field | Value |
|---|---|
| Epic | E3 -- CI and fixture eval |
| Wave | A |
| Priority | Must Have |
| Size | S |
| SRD Refs | EDMV3-24 |
| Depends On | -- |
| Ships-with | -- |
| Target Components | `plugins/edm/bin/tests/run-all.sh` (new), `plugins/edm/bin/edm-lint-artifacts` (new `--all` mode, `usage()` at `:30`), `plugins/edm/bin/edm-state:53` (`list_state_files`), `plugins/edm/hooks/hooks.json:80-90` (`PreToolUse` commit hook, unchanged) |

### Description

Explorer 01 risk R9: new tests written into a harness nobody executes are worthless. The CI job needs
a single entry point, and `edm-lint-artifacts` currently requires a `PREFIX` argument, which makes a
repository-wide lint pass awkward to express in CI.

Promoted to Must Have in SRD v1.1.0 because EDMV3-23 and EDMV3-95 both depend on `--all` existing;
descoping it would silently break two Must requirements.

### Acceptance Criteria

- [ ] AC1 (positive): `plugins/edm/bin/tests/run-all.sh` runs every smoke suite in a defined order,
      prints a per-suite pass/fail summary and a total, and exits 0 when all pass.
      Verify: `bash plugins/edm/bin/tests/run-all.sh; echo "exit=$?"` prints a per-suite table and
      `exit=0`.
- [ ] AC2 (negative): it exits non-zero if any suite fails, and the summary names which suite failed
      and how many assertions within it.
      Verify: introduce a deliberate failure in a scratch copy of `wave3-smoke.sh` and confirm
      `bash plugins/edm/bin/tests/run-all.sh; echo "exit=$?"` prints `exit=1` naming `wave3`.
- [ ] AC3 (negative, silent omission is a failing condition -- auto-discovery is asserted, not
      offered as an alternative): the aggregator **discovers** `bin/tests/*-smoke.sh` rather than
      reading a hand-kept list, so a new suite runs without being registered. The earlier "or the
      aggregator fails naming the unregistered file" wording made the AC pass under either outcome,
      and an empty `wave99-smoke.sh` passed it vacuously.
      Verify: write a scratch suite `plugins/edm/bin/tests/wave99-smoke.sh` whose body is
      `#!/usr/bin/env bash` then `echo "wave99 deliberate failure"; exit 1`, run
      `bash plugins/edm/bin/tests/run-all.sh; echo "exit=$?"`, and confirm it prints `exit=1` **and**
      names `wave99` in the per-suite summary -- proving the suite was discovered and executed, not
      merely listed. Remove the file afterwards and confirm the aggregator returns to `exit=0`.
- [ ] AC4 (positive, `--all`): `edm-lint-artifacts --all` resolves every initiative under the SRD
      root -- both flat and product-scoped layouts, excluding `.archived/` -- and lints each.
      Verify: `bash plugins/edm/bin/edm-lint-artifacts --all; echo "exit=$?"`.
- [ ] AC5 (negative, `--all` exit code): `--all` exits non-zero if any initiative has violations,
      and the output groups violations by initiative while preserving the existing
      `path:line: <class>: <snippet>` format per violation.
      Verify: introduce a non-ASCII character into a scratch initiative artifact and confirm
      `bash plugins/edm/bin/edm-lint-artifacts --all` exits non-zero, groups by initiative, and
      keeps the per-line format.
- [ ] AC6 (no third layout implementation): `--all` consumes the existing enumeration rather than
      re-deriving it. `list_state_files()` (`bin/edm-state:53`) already enumerates both layouts,
      deduplicates with a bash-3.2-safe linear seen-array, and takes an `--archived` opt-in. A
      read-only `edm-state list --paths` exposes it and `--all` calls that. Re-implementing the walk
      would make three implementations of layout resolution, which EDMV3-111 forbids. The new
      `--paths` flag is documented as an explicit item on the `list` help line, so the
      bidirectional help-completeness test (EDMV3-T61 AC2) sees it rather than treating it as an
      undocumented option on an already-documented subcommand.
      Verify: `grep -n 'edm-state list --paths' plugins/edm/bin/edm-lint-artifacts` returns the call,
      `grep -cn 'SRD/\*/\*__\*' plugins/edm/bin/edm-lint-artifacts` returns 0, and
      `edm-state --help | grep -n -- 'list .*--paths'` returns the documented flag.
- [ ] AC10 (positive, `--path` mode -- lint an arbitrary directory or file without resolving a
      prefix): `edm-lint-artifacts --path <dir|file>` lints exactly the given path, recursing when
      it is a directory, using the same four classes, the same
      `path:line: <class>: <snippet>` output and the same exit contract as prefix mode. It is
      strictly read-only, performs **no** state resolution, and never calls `edm-state`. Today the
      script accepts a `PREFIX` only -- `:37` dies with `usage: edm-lint-artifacts <PREFIX>` on an
      empty argument and `:44` resolves the prefix through `edm-state resolve-dir` -- so linting a
      fixture corpus or a scratch directory is not expressible, and five verification commands in
      EDMV3-T43 and EDMV3-T44 would exit 1 with "no initiative for prefix".
      Verify: `bash plugins/edm/bin/edm-lint-artifacts --path plugins/edm/bin/tests/fixtures/; echo "exit=$?"`
      lints the fixture tree, and `bash plugins/edm/bin/tests/wave7-smoke.sh` (cases "--path on a
      directory lints recursively", "--path on a single file lints that file", and "--path makes no
      edm-state call", the last asserted by running it with `edm-state` removed from `PATH`).
- [ ] AC7 (preserve; method corrected per G48/CA-324, same class CHANGELOG.md already ruled out
      for the sibling T67 AC8 -- an empty diff stat "goes green after any commit whatever the
      content"): the existing single-prefix invocation and the `PreToolUse` commit hook
      behaviour at `hooks/hooks.json` are unchanged, so commit-path cost stays proportional to
      what changed.
      Verify: `bash plugins/edm/bin/edm-lint-artifacts EDMV3` still works, and
      `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "T67 AC8") asserts the hook's shipped
      scoping content directly.
- [ ] ~~AC8: both are wired into the CI lint and test stages.~~ **Superseded, D63**: no CI pipeline exists;
      `run-all.sh` is invoked locally (the developer's own pre-push step, `plugins/edm/CLAUDE.md` "Testing
      changes") and `edm-lint-artifacts` runs via the git-commit hook per initiative.
- [ ] AC9 (bash 3.2): both pass `bash -n` and introduce no bash 4+ construct.
      Verify: `bash -n plugins/edm/bin/tests/run-all.sh && bash -n plugins/edm/bin/edm-lint-artifacts`.

### Technical Notes

- `edm-state list --paths` must be strictly read-only and take no lock (EDMV3-92 AC3). Assert that
  with `check_state_unchanged`.
- `--path` and `--all` are mutually exclusive and both are mutually exclusive with a bare `PREFIX`.
  Supplying two of the three is a usage error (exit 2), not a silent precedence rule.
- `--path` is what makes EDMV3-T43's and EDMV3-T44's fixture verifications expressible. Both
  tickets invoke it by name, so it must land in wave A even though its first consumer is wave B.
- The aggregator's ordering matters for diagnosis, not correctness: run `wave3` (state basics) first
  and `wave6` (lifecycle) last so a foundational break is reported before a downstream one.
- `--all` will be slow on a repository with many initiatives. EDMV3-102 sets a 60s budget for 50
  initiatives, measured by EDMV3-T67, and documents it as a CI budget rather than a commit-path one.

### Out of Scope

- The Mermaid violation class the `--all` pass will eventually run (EDMV3-56) -- EDMV3-T43.
- The pipeline file itself -- EDMV3-T21.
- ASCII-normalizing existing artifacts so `--all` can exit 0 -- EDMV3-T63.

---

## EDMV3-T21: GitLab CI pipeline -- lint, test, and two-tier validate

> **SUPERSEDED (D63, 2026-08-23).** Delivered as specified below, then removed by an explicit human decision: EDM's
> own local mechanisms (the git-commit hook, the 11-lens code-audit methodology) already provide the enforcement
> this ticket existed to add. Ticket text preserved as historical record; does not describe current state.

| Field | Value |
|---|---|
| Epic | E3 -- CI and fixture eval |
| Wave | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV3-23 |
| Depends On | EDMV3-T03, EDMV3-T20 |
| Ships-with | -- |
| Target Components | `.gitlab-ci.yml` (new, repository root), `plugins/edm/bin/tests/`, `plugins/edm/CLAUDE.md` ("Testing changes" section), `CLAUDE.md` (repository root: the "No build process, tests, or CI/CD" statement and the Current Plugins list, where `edm` is currently absent) |

### Description

F10. There is no CI. The four smoke suites run only when someone remembers;
`plugins/edm/CLAUDE.md` "Testing changes" is a manual checklist. Prompt changes ship on vibes.

This pipeline is what locks waves A and B in place: from the moment it lands, a stale smoke
assertion is a pipeline stop rather than a nuisance, which is the mechanism SRD Section 11.2 relies
on for the "ships with its assertion updates" ordering rule.

### Acceptance Criteria

- [ ] AC1: `.gitlab-ci.yml` exists at the repository root with at least three stages -- `lint`,
      `test`, `validate`. No root pipeline exists today, so this creates one.
      Verify: `test -f .gitlab-ci.yml && grep -n '^stages:' -A5 .gitlab-ci.yml`.
- [ ] AC2 (scoped, not a cross-plugin gate): jobs use `rules:changes` on `plugins/edm/**` for
      merge-request runs, plus an always-on run on the default branch so the pipeline cannot rot
      behind an unrelated merge. The repository-root `CLAUDE.md` is updated in the same MR: its
      "No build process, tests, or CI/CD" statement becomes a description of the pipeline, and
      `edm` is added to its Current Plugins list.
      Verify: `grep -n 'rules:' -A4 .gitlab-ci.yml` shows the `changes` clause, and
      `grep -n 'edm' CLAUDE.md` returns the Current Plugins entry.
- [ ] AC3 (the file-type check is added here **non-blocking only**): EDMV3-80's file-type ban binds
      all six marketplace plugins, not only `edm`, and today `plugins/edm/` itself carries two of
      the banned files. This ticket therefore adds the job with `allow_failure: true` and nothing
      else -- it does **not** run or record the cross-plugin scan, and it does not flip the job to
      blocking. **EDMV3-T57 owns both**: AC6 there records the clean six-plugin scan and its new
      AC10 flips this job to blocking in the same MR. Two tickets running the same scan was a
      duplicate with no stated authority; the scan lives with the ticket that fixes what it finds.
      Verify: `grep -n 'allow_failure' -B4 .gitlab-ci.yml` shows it on the file-type job, and
      `bash plugins/edm/bin/tests/wave7-smoke.sh` (case "file-type job is non-blocking until
      EDMV3-T57") reads the flag from `.gitlab-ci.yml`. The flip is cross-checked at wave-C close by
      EDMV3-T66 AC11.
- [ ] AC4 (lint stage): the `lint` stage runs `bash -n` over every file in `plugins/edm/bin/`
      including `bin/tests/*.sh`, runs `edm-lint-artifacts --all` over tracked artifact trees, and
      runs `bin/edm-check-grants`.
      Verify: `grep -n 'bash -n\|edm-lint-artifacts --all\|edm-check-grants' .gitlab-ci.yml`.
- [ ] AC5 (test stage invokes the aggregator and nothing else): the `test` stage's script is
      `bash plugins/edm/bin/tests/run-all.sh` and contains **no enumeration of individual suites**.
      `run-all.sh` auto-discovers `bin/tests/*-smoke.sh` (EDMV3-T20 AC3), so an enumerated CI list
      would be a second source of truth for the suite set and would silently skip any suite added
      later -- exactly the omission AC3 there exists to prevent.
      Verify: `grep -n 'run-all.sh' .gitlab-ci.yml` returns the aggregator invocation in each of
      the two `test:` jobs and nothing else, and
      `grep -nE '^[a-z0-9_-]+:wave[0-9]' .gitlab-ci.yml` returns nothing -- no job KEY is named
      after an individual wave suite. (A bare `grep -c 'bin/tests/' .gitlab-ci.yml` count is not
      this check: that literal token also appears in unrelated lint-glob lines, shellcheck-glob
      lines, and prose comments that legitimately mention the path, so its count moves every time
      one of those unrelated things is edited and is not a stable signal of "no per-suite job
      exists" -- decisions.md D44.)
- [ ] AC6 (validate stage is two-tier, positive and negative): tier 1 is a deterministic `jq`
      manifest-and-frontmatter check -- every skill and agent on disk appears in
      `.claude-plugin/marketplace.json` and vice versa, every frontmatter block parses, every
      declared tool name is well-formed. It needs only `jq`, always runs, and **blocks**. Tier 2
      runs `claude plugin validate` and fails on any new warning relative to a committed baseline
      count; it runs when the `claude` CLI image is available and is `allow_failure` otherwise.
      Verify: `grep -n 'allow_failure' .gitlab-ci.yml` shows it on tier 2 only, and deleting an
      agent from `marketplace.json` in a scratch branch reds tier 1.
- [ ] AC7 (images pinned by digest): job images and dependencies are pinned by digest -- `bash`,
      `jq`, `git` for every blocking job, and additionally the `claude` CLI for validate tier 2 and
      for the eval job.
      Verify: `grep -n 'image:' .gitlab-ci.yml` shows an `@sha256:` digest on every entry.
- [ ] AC8 (negative, missing secret skips rather than fails): the eval job consumes
      `ANTHROPIC_API_KEY` as a masked, protected CI variable. When the variable is absent the job
      **skips**, it does not fail -- a missing secret on a fork or a contributor pipeline must not
      present as a broken pipeline.
      Verify: `grep -n 'ANTHROPIC_API_KEY' -B2 -A4 .gitlab-ci.yml` shows the `rules: if:` guard, and
      a pipeline run with the variable unset shows the job skipped.
- [ ] AC9 (eval is not blocking): the eval job is defined but is `when: manual` plus a scheduled
      nightly run.
      Verify: `grep -n 'when: manual' .gitlab-ci.yml` on the eval job.
- [ ] AC10 (red blocks merge, verified against the API rather than a screenshot): the pipeline runs
      on merge requests and on the default branch, and a red pipeline blocks merge.
      Verify: `GET /projects/:id/` returns `"only_allow_merge_if_pipeline_succeeds": true`. The
      inspection target is that field in the project-settings API response; the JSON fragment is
      pasted into the ticket's QC evidence. A screenshot is not the evidence -- it cannot be
      re-checked, and the setting is the thing that must be true.
- [ ] AC11 (green on the default branch, verified against the API): the pipeline is green on the
      default branch before wave A merges.
      Verify: `GET /projects/:id/pipelines?ref=<default-branch>&status=success` returns a pipeline
      whose `sha` is the wave-A merge commit; the pipeline `id`, `sha` and `status` fields from that
      response are pasted into the ticket alongside the pipeline URL.
- [ ] AC12 (state files validated in CI -- the last unmechanized check, Gate 3 revise): the test
      stage runs `edm-state validate` across every tracked, non-archived initiative (enumerated via
      the same layout-aware listing `edm-lint-artifacts --all` uses, EDMV3-T20). Informational
      anomalies are reported in the job output without failing it; blocking anomalies fail the job
      (the informational/blocking split is EDMV3-118's, delivered by EDMV3-T05 in this wave).
      Verify: the CI job log for a clean tree shows one `validate` line per tracked initiative and
      exits 0; a scratch initiative with a hand-planted blocking anomaly makes the job exit non-zero
      naming the initiative and the anomaly code.

### Technical Notes

- The pipeline may land before every check it will eventually run exists. `bin/edm-check-vocabulary`
  (EDMV3-T30, wave B) and the four-`##` contract check (EDMV3-T56, wave C) are added to the lint
  stage by their own tickets, not here. This is why this wave-A ticket does not depend on them --
  SRD EDMV3-23's dependency note says the pipeline may land first with jobs added incrementally.
- The `shellcheck` job required by EDMV3-91 is added by EDMV3-T61 with its documented fallback.
- Tier 1's `jq` check is the one that must never be `allow_failure`. It is the only manifest
  validation that survives a runner fleet without the `claude` CLI.

### Out of Scope

- The eval driver and scorer the eval job invokes -- EDMV3-T22, EDMV3-T23.
- The bash 3.2 and macOS runner matrix -- EDMV3-T61.
- The CI failure-message contract -- EDMV3-T65.

---

## EDMV3-T22: Eval fixture and headless driver

| Field | Value |
|---|---|
| Epic | E3 -- CI and fixture eval |
| Wave | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV3-25, EDMV3-26 |
| Depends On | -- |
| Ships-with | -- |
| Target Components | `plugins/edm/evals/fixtures/tiny-svc/` (new), `plugins/edm/evals/fixtures/tiny-svc/expected.json` (new), `plugins/edm/evals/initiative.txt` (new), `plugins/edm/evals/run-eval.sh` (new), `plugins/edm/evals/README.md` (new) |

### Description

R7. A small synthetic repository plus a frozen initiative description, checked in, so a headless run
has a stable subject -- and a driver that executes the methodology against it without a human, so
prompt changes get a before/after number instead of vibes.

The gate handling is the subtle part. After EDMV3-48 and EDMV3-49 every phase skill *ends* with
"present the gate per the PROTOCOL", and the PROTOCOL mandates `AskUserQuestion` plus "STOP and
WAIT", which `claude -p` cannot answer. Pre-seeding approvals satisfies the *next* skill's gate check
but does nothing about the *current* skill stopping at an unanswerable prompt, so the eval would hang
or time out on every phase. The driver therefore does both: it instructs each phase skill to execute
the phase body and stop before gate presentation, and it pre-seeds the next phase's approval from the
driver shell between invocations.

### Acceptance Criteria

- [ ] AC1 (fixture, positive): `plugins/edm/evals/fixtures/tiny-svc/` contains a small synthetic
      project -- enough source files across at least two areas that an explorer has something real
      to map -- plus a README describing the fixture's intent. This is the canonical path and
      matches `architecture.md` Plane 4.
      Verify: `ls plugins/edm/evals/fixtures/tiny-svc/` shows at least two source areas and a
      `README.md`.
- [ ] AC2 (ground truth): `expected.json` describes the known, countable gaps a good SRD should
      surface from this fixture, so the scorer has ground truth rather than only self-consistency
      checks. `plugins/edm/evals/initiative.txt` holds a frozen initiative description with a fixed
      prefix and product, never edited without a version bump recorded in the file itself.
      Verify: `jq -e '.gaps | length > 0' plugins/edm/evals/fixtures/tiny-svc/expected.json` and
      `grep -n '^version:' plugins/edm/evals/initiative.txt`.
- [ ] AC3 (negative, size budget): the fixture plus its `expected.json` stays under 100KB. **Superseded, D63**:
      this was originally asserted by a CI check (the same one enforcing the file-type ban, extended to a
      total-directory-size assertion for `plugins/edm/evals/`); that check no longer exists, so the budget is now
      verified manually. The initiative removes 708KB of binaries from the shipped plugin directory on the grounds
      that every installer downloads them; an unbounded fixture tree would undo that.
      Verify: `git ls-files -- plugins/edm/evals | xargs wc -c | tail -1` (tracked bytes, never `du`) is under
      100KB for the tracked tree overall.
- [ ] AC4 (self-contained, with the network-disable mechanism named): the fixture requires no
      network access, no external services, and no dependency on the marketplace repository's own
      content.
      Verify: run the **fixture provisioning step alone** (not the full driver, which reaches the
      Anthropic API by design) with the network disabled by a named mechanism -- on Linux
      `unshare -rn bash plugins/edm/evals/run-eval.sh --provision-only`, and on macOS, where
      `unshare` does not exist, by poisoning the proxy environment
      (`http_proxy=http://127.0.0.1:1 https_proxy=http://127.0.0.1:1 no_proxy= bash plugins/edm/evals/run-eval.sh --provision-only`).
      Both invocations exit 0 and populate the scratch fixture tree. The `--provision-only` flag is
      part of this ticket's deliverable and is documented in `evals/README.md`.
- [ ] AC5 (driver, positive): `plugins/edm/evals/run-eval.sh` provisions a scratch copy of the
      fixture in a temp directory, initializes a git repository, and runs `claude -p` through
      plan -> srd -> audit, writing all produced artifacts to a run directory named by timestamp and
      git SHA and recording the model, the plugin version, and the token and cost totals.
      Verify: `bash plugins/edm/evals/run-eval.sh` produces
      `plugins/edm/evals/runs/<ts>_<sha>/` containing `planning.md`, `srd.md` and `audit-srd.md`
      plus a `run.json` with the four recorded fields.
- [ ] AC6 (negative, no production check is weakened): the driver invokes each phase skill with an
      explicit instruction to execute the phase body and stop before gate presentation, and
      pre-seeds the next phase's approval by calling `edm-state approve-gate` from the driver shell
      between invocations. No eval-only environment marker is read by `bin/edm-state`, and no
      production check is conditional on the eval.
      Verify: `grep -rn 'EDM_EVAL\|IS_EVAL\|eval_mode' plugins/edm/bin/` returns zero results.
- [ ] AC7 (invocation fully specified): the `claude -p` invocation is fully specified in the script
      and in `evals/README.md` -- the model, the permission posture (`--permission-mode` and the
      `--allowedTools` set, chosen so the run cannot mutate anything outside the scratch tree), the
      plugin directory, and a per-phase timeout after which the run is abandoned and scored as a
      failure.
      Verify: `grep -n 'permission-mode\|allowedTools\|timeout' plugins/edm/evals/run-eval.sh` and
      the same four items documented in `plugins/edm/evals/README.md`.
- [ ] AC8 (auth contract matches shipped driver): the driver requires working Claude auth for a real
      run. Either an exported `ANTHROPIC_API_KEY` or an already authenticated `claude` CLI session
      satisfies the contract; `--provision-only` needs neither. When both auth paths are absent, the
      driver exits with a usage message naming both remedies.
      Verify: `env -u ANTHROPIC_API_KEY bash plugins/edm/evals/run-eval.sh; echo "exit=$?"` prints
      the combined-auth refusal and `exit=2` on a machine with no stored `claude` auth, while a
      logged-in CLI run still succeeds without exporting the variable.
- [ ] AC9 (containment check): a post-run cleanliness check asserts `git status` in the scratch tree
      shows no files created outside the expected artifact paths. This is the containment check for
      EDMV3-93.
      Verify: the driver prints `containment: clean` on a successful run and exits non-zero when a
      stray file appears.
- [ ] AC10 (negative, partial run is a distinct failure): a partially completed run scores as a
      failure with a distinct exit code -- not as a low score, which would be indistinguishable from
      a genuine quality regression. Exit 0 when the run completes and the scorer produces a score,
      1 when the scorer reports a regression, 2 on a usage or environment error, 4 when the run did
      not reach the final phase. `scores.json` records `complete: false` in that case and
      `bin/edm-compare-eval` refuses to compare it against the baseline.
      Verify: kill the run mid-phase and confirm `echo "exit=$?"` prints `exit=4` and
      `jq -e '.complete == false' <run-dir>/scores.json`.
- [ ] AC11 (cleanup): the driver cleans up the scratch tree on exit including on failure, and never
      mutates the developer's working tree.
      Verify: `bash plugins/edm/evals/run-eval.sh; git status --porcelain` prints nothing outside
      `plugins/edm/evals/runs/`.
- [ ] AC12 (lint policy stated): `evals/README.md` states that eval **run artifacts** are linted by
      the same rules as real artifacts (a run producing non-ASCII or malformed Mermaid is a genuine
      signal about the prompts, and lint results feed scorer dimension 3), while committed baseline
      run artifacts live outside the plugin source tree and are excluded from `--all` by location.
      Verify: `grep -n 'run artifacts are linted' plugins/edm/evals/README.md`.
- [ ] AC13 (ground-truth match patterns, fixture version, and run attribution -- added with the
      scorer's sixth dimension): every gap in `expected.json` carries an `srd_match` field, a
      case-insensitive ERE that the scorer's known-gap-recall dimension (EDMV3-T23 AC1/AC2,
      dimension 6) greps the produced `srd.md` for, and `expected.json` records a `fixture_version`
      that is bumped whenever a gap or an `srd_match` pattern changes, so a captured baseline is
      never silently re-scored against different ground truth. `run-eval.sh` writes
      `fixture: "tiny-svc"` into `run.json` on **both** its complete and its partial exit path;
      that field is the sole gate dimension 6 reads to decide whether known-gap recall applies to a
      run directory, which is why a wave-A run scores dimension 6 and skips only dimension 5. These
      three fields are owned here rather than by EDMV3-T23 because the fixture and the driver
      produce them and the scorer only consumes them (the same reasoning that kept `expected.json`
      in this ticket per the Technical Notes). Added by code-audit finding CA-462; decisions.md D61
      records the authorization.
      Verify: `jq -e '([.gaps[].srd_match] | length == 6) and ([.gaps[].srd_match] | map(. != null) | all)' plugins/edm/evals/fixtures/tiny-svc/expected.json`,
      `jq -e '.fixture_version' plugins/edm/evals/fixtures/tiny-svc/expected.json`, and
      `grep -c 'fixture: "tiny-svc"' plugins/edm/evals/run-eval.sh` returns `2`.

### Technical Notes

- **Resolved in srd.md v1.2.0 (CR2), no longer an open ambiguity.** EDMV3-26's dependency list
  previously named EDMV3-47 (the final PROTOCOL wording, wave B) while EDMV3-28 required the
  baseline to be captured on wave-A code before any wave-B prompt edit -- a wave-A requirement
  depending on a wave-B one, which made the wave plan unexecutable. EDMV3-26's `Dependencies` are
  now EDMV3-25 only; the ordering survives as a **soft edge** recorded in SRD Section 11.2. This
  ticket builds the stop-before-gate contract against the *current* gate text, and EDMV3-T39 AC5
  re-verifies it against the wave-B PROTOCOL and records the result either way. If that
  re-verification changes driver behaviour materially, the baseline is invalidated and re-captured
  before any comparison is trusted.
- **Size note (stays M).** The round-1 ticket audit flagged this as characteristically L -- a
  headless driver, a synthetic repository, a four-valued exit contract and a ground-truth
  `expected.json` in one ticket. It stays M deliberately: the fixture tree is under 100KB of
  hand-written source with no logic to get wrong, the driver is a single bash script whose hard part
  (the stop-before-gate contract) is one instruction string, and the four-valued exit contract is
  four `exit` statements rather than four code paths. What would make it L is `expected.json`'s
  ground truth, and that is bounded by AC2 to the countable gaps the fixture was built to contain.
  Descoping `expected.json` into EDMV3-T23 was considered and rejected: the scorer would then own
  ground truth for a fixture it did not author.
- **AC-band note.** This ticket carries 13 acceptance criteria against the pack's 6-12 band. The
  overage is one AC wide and arrived after the fact: AC13 was added when CA-462 gave the fixture's
  ground truth a machine-readable consumer (the scorer's known-gap-recall dimension), and all three
  fields it owns -- `expected.json`'s `srd_match` and `fixture_version`, and `run.json`'s `fixture`
  -- sit in this ticket's own Target Components. Splitting them into a fixture-only ticket would
  separate `expected.json` from the driver that attributes runs to it, which is exactly the pairing
  AC13 exists to pin.
- The fixture must pass `claude plugin validate` scanning cleanly rather than being excluded from
  it, since it contains no skills, agents or manifests to confuse the validator.
- Keep `run.json` and `scores.json` separate. The driver writes the former; the scorer
  (EDMV3-T23) writes the latter and never reads the developer's environment.

### Out of Scope

- The scorer -- EDMV3-T23.
- The baseline capture -- EDMV3-T23.
- Any change to `bin/edm-state` for the eval's convenience -- explicitly forbidden by AC6.

---

## EDMV3-T23: Mechanical scorer, committed baseline, and eval cadence

| Field | Value |
|---|---|
| Epic | E3 -- CI and fixture eval |
| Wave | A |
| Priority | Must Have |
| Size | M |
| SRD Refs | EDMV3-27, EDMV3-28, EDMV3-29 |
| Depends On | EDMV3-T21, EDMV3-T22 |
| Ships-with | -- |
| Target Components | `plugins/edm/evals/score-artifacts.sh` (new), `plugins/edm/evals/vague-ac-patterns.txt` (new), `plugins/edm/evals/baseline/` (new), `plugins/edm/evals/baseline/README.md` (new), `plugins/edm/evals/README.md`, `.gitlab-ci.yml` |

### Description

The score must be computed by a deterministic script, not by a model, so it is comparable across
runs. The baseline is worthless if captured after prompt edits begin, so it must be taken on wave-A
code -- which makes this ticket a wave-A exit criterion. And the eval costs real money and real wall
time per run, which is why it cannot be a blocking CI job, and why the consequence must be managed
rather than hoped away.

### Acceptance Criteria

- [ ] AC1 (exactly six dimensions): `plugins/edm/evals/score-artifacts.sh` scores a run directory
      on **exactly six** dimensions -- not "at least six", which would leave two runs of different
      scorer versions incomparable -- and emits a `scores.json` with a per-dimension score and a
      total. The six are: requirement-ID coverage, AC testability, Mermaid parse success,
      coverage-map bidirectionality, lens JSONL-versus-prose agreement, and known-gap recall
      against the tiny-svc fixture's ground truth. The set was five as originally written; the
      sixth was added by code-audit finding CA-462 with a `scorer_version` bump to 1.1.0
      (decisions.md D61), because the original five are all self-consistency checks over the run's
      own output, so an SRD surfacing none of the fixture's six known gaps scored identically to
      one surfacing all six.
      Verify: `jq -e '.dimensions | length == 6' <run-dir>/scores.json`.
- [ ] AC2 (dimension definitions): dimension 1 checks that every `{PREFIX}-NN` ID in the SRD is
      unique, sequential with no gaps, and appears in the audit report's coverage discussion.
      Dimension 2 counts ACs matching the vague-AC regexes divided by total AC count. Dimension 3
      checks every ` ```mermaid ` block parses and contains no raw `;` in label text per the
      EDMV3-56 detection rule. Dimension 4 checks coverage-map bidirectionality where the run
      reached the ticket phase. Dimension 5 compares per-lens finding counts between
      `lens-L{N}.md` and `lens-L{N}.jsonl` for a run including a code-audit round. Dimension 6
      scores the fraction of the tiny-svc fixture's six ground-truth gaps
      (`fixtures/tiny-svc/expected.json`, `srd_match` patterns) the produced `srd.md` engages, and
      is skipped (`score: null`) for any run directory whose `run.json` does not attribute it to
      the tiny-svc fixture.
      Verify: `bash plugins/edm/evals/score-artifacts.sh --describe` prints the six definitions
      verbatim.
- [ ] AC3 (normalization fully specified, and the denominator is data not a constant): each
      dimension normalizes to an integer 0-100 where higher is better. Dimension 2 is inverted at
      normalization time (`100 * (1 - vague/total)`) so its polarity matches the rest. A dimension
      that could not be computed is emitted with `score: null`, named in `dimensions_skipped` with a
      one-line reason, and excluded from both the sum and the denominator. The total is the
      **unweighted arithmetic mean of the dimensions that produced a number**, divided by
      `dimensions_scored`, rounded to one decimal place. No dimension carries a weight.
      Verify: `jq -e '([.dimensions[].score | select(. != null)] | add) as $sum | .dimensions_scored as $n | (($sum / $n * 10 | round) / 10) == .total' <run-dir>/scores.json`
      exits 0. This is the exact expression -- there is no licence to adapt it. The earlier wording
      let the implementer rewrite the check until it passed, which is not an acceptance criterion,
      and its `[...]|.total` form resolved `.total` against the array rather than the object.
- [ ] AC4 (versioned dimension set and recorded dimension count, negative): `scores.json` records
      `scorer_version`, the ordered dimension name list, `dimensions_scored` (the integer count of
      dimensions that produced a number) and `dimensions_skipped` (the names that did not, each with
      a reason). A comparison between two `scores.json` files is refused, with a message naming the
      mismatch, when their `scorer_version` values differ **or** when their `dimensions_scored`
      values differ. Comparing a five-dimension run against a six-dimension run produces a delta
      with no meaning, and an unstated `null` silently changing the denominator is how two
      incomparable runs come to look comparable (srd.md CR6).
      Verify: run the comparison against a hand-edited `scores.json` with a bumped `scorer_version`
      and confirm it exits non-zero with the refusal message; repeat with `scorer_version` equal and
      `dimensions_scored` changed from 5 to 6 and confirm the same refusal naming the dimension sets.
- [ ] AC5 (negative, the scorer emits scores only): the scorer performs no baseline comparison and
      never exits non-zero on a low score. Exit 0 when it produced a score, non-zero only on a usage
      or environment error. The pass/fail decision belongs to `bin/edm-compare-eval`.
      Verify: `bash plugins/edm/evals/score-artifacts.sh <run-dir-with-terrible-scores>; echo "exit=$?"`
      prints `exit=0`.
- [ ] AC6 (deterministic): running the scorer twice over the same run directory produces
      byte-identical output, and it depends on nothing beyond bash 3.2 plus `jq`.
      Verify: `bash plugins/edm/evals/score-artifacts.sh <dir> > a.json && bash plugins/edm/evals/score-artifacts.sh <dir> > b.json && diff a.json b.json`
      prints nothing.
- [ ] AC7 (committed regex file): the vague-AC regex set lives in
      `plugins/edm/evals/vague-ac-patterns.txt`, not inline, and `architecture.md` names the same
      path.
      Verify: `test -s plugins/edm/evals/vague-ac-patterns.txt` and
      `grep -n 'vague-ac-patterns.txt' SRD/edm/EDMV3__prompt-streamline/architecture.md`.
- [ ] AC8 (baseline committed, on wave-A code, and it is a **five**-dimension wave-A baseline) --
      **out-of-scope boundary recorded (CA-106, D62, D15 route (b)):** `plugins/edm/evals/baseline/scores.json`
      does not exist in this initiative and its capture is explicitly deferred to the named
      follow-on **EDMV4-T05**, not silently left "pending" with no owning ticket. The requirement
      text below is unchanged and remains the target AC13's follow-on must satisfy; this AC is not
      met by EDMV3 and is not claimed to be. When EDMV4-T05 lands: `plugins/edm/evals/baseline/scores.json`
      is committed, produced by a run against wave-A code, and records the plugin version, the git
      SHA, the `complete` flag from the driver, and `dimensions_scored: 5`. Five of the six, not all
      six: the wave-A driver runs plan -> srd -> audit and never a code audit, so dimension 5 has no
      input and is emitted `null` with its reason in `dimensions_skipped`, while dimension 6 does
      score on a wave-A run because `run-eval.sh` attributes every run it produces to the tiny-svc
      fixture in `run.json`. `evals/baseline/README.md` states plainly that this is a five-dimension
      figure and that the first six-dimension run establishes its own baseline rather than being
      compared against this one.
      Verify (deferred to EDMV4-T05): `jq -e '.plugin_version and .git_sha and (.complete == true) and (.dimensions_scored == 5) and (.dimensions_skipped | length == 1)' plugins/edm/evals/baseline/scores.json`,
      and `grep -n 'five-dimension' plugins/edm/evals/baseline/README.md`.
- [ ] AC9 (variance is a named statistic, not a hand-wave): at least three baseline runs are
      performed and the tolerance is recorded as `max - min` of the total across the three runs, as
      a single number, plus the same figure per dimension. Three runs are too few for a meaningful
      sigma, which is why the range is used.
      Verify: `grep -n 'max - min' plugins/edm/evals/baseline/README.md` returns the recorded total
      range and the six per-dimension ranges (dimension 5's recorded as N/A on a wave-A capture).
- [ ] AC10 (honest framing): `evals/baseline/README.md` states plainly that the six dimensions are
      proxies, that a refactor can score identically and still produce worse artifacts, that the
      number is a regression tripwire rather than a quality score, and that re-versioning the scorer
      invalidates the baseline and requires re-capture. Baseline run artifacts (not just the scores)
      live at a documented location **outside `plugins/edm/`** and that location is recorded.
      Verify: `grep -n 'tripwire\|invalidates the baseline\|outside plugins/edm' plugins/edm/evals/baseline/README.md`.
- [ ] ~~AC11 (cadence): the eval job in `.gitlab-ci.yml` is `when: manual` on merge requests and
      additionally runs on a nightly schedule against the default branch, publishing `scores.json`
      as a pipeline artifact with at least 30 days retention, named or tagged so a simple script can
      plot total score over time.~~ **Superseded, D63**: no CI pipeline exists, so there is no unattended
      nightly run and no pipeline-artifact retention. A prompt regression is now only caught if a human runs
      `run-eval.sh` before merging the change that introduced it (acknowledged gap, D63).
- [ ] AC12 (cost documented): `evals/README.md` documents the approximate cost and duration of one
      run so the decision to trigger it is informed. **Amended, D63**: the original "CI will catch it" framing
      no longer applies (there is no CI); the doc instead states plainly that nothing runs this for you.
      Verify: `grep -n 'cost per run' plugins/edm/evals/README.md`.
- [ ] AC13 (out-of-scope boundary recorded, CA-106/D62, superseding the "blocked" framing D36
      corrected to): the committed baseline artifact records the wave-A fixture/scorer it was
      captured from and the variance table that EDMV3-T39 consumes, so later tickets can verify
      provenance from the artifact itself instead of from a no-longer-live chronology claim. This
      AC's `README.md` half is verifiable today and is met by this initiative; its `scores.json`
      half is explicitly **out of scope for EDMV3** and named as follow-on ticket **EDMV4-T05**
      (D62) rather than left as an open-ended "blocked pending D23" status with no owning ticket --
      D15's route (b) (move the unverifiable clause out of scope as a recorded boundary), not route
      (a). This is not silently passed and not faked: the boundary is named, dated, and ticketed.
      Verify: `grep -n 'wave-A\|variance\|dimensions_scored' plugins/edm/evals/baseline/README.md`
      shows the provenance and tolerance table today (this half is met); the second half,
      `jq -e '(.dimensions_scored == 5) and (.complete == true)' plugins/edm/evals/baseline/scores.json`,
      is EDMV4-T05's closing verify, not EDMV3-T23's.

### Technical Notes

- Dimension 5 requires a code-audit round in the run. The wave-A driver runs plan -> srd -> audit
  (the SRD audit), not a code audit, so dimension 5 scores as `null` and is excluded from the mean
  for wave-A baseline runs -- it is the only one of the six that skips there, since dimension 6
  reads `run.json`'s `fixture` field, which the driver writes on every run. That exclusion is what
  `dimensions_scored` makes explicit: the denominator is read from the file rather than assumed to
  be 6, and a comparison across differing `dimensions_scored` is refused (AC4). An unstated `null`
  silently changes the denominator and makes the baseline incomparable to later runs, which is the
  defect srd.md CR6 closes.
- **AC-band note.** This ticket carries 13 acceptance criteria against the pack's 6-12 band. The
  overage is three requirements batched into one deliverable (scorer, baseline, cadence) rather than
  one requirement over-specified, and every AC is independently checkable. Recorded in the README
  sizing section rather than resolved by splitting: separating the cadence from the scorer would
  leave a CI job with nothing to run.
- `jq` cannot do floating-point rounding cleanly in all builds. Compute the mean in integer
  tenths and format at print time.
- The CI comparison job (EDMV3-T39) is the consumer of the variance figure. Write it into
  `baseline/scores.json` as a machine-readable field as well as into the README prose, so the job
  does not parse markdown.

### Out of Scope

- The comparison job and the fallback decision -- EDMV3-T39 (wave B).
- Re-capturing the baseline after the dispatcher refactor -- EDMV3-T39.
- Lens tiering's before/after fixture comparison -- EDMV3-T48 (wave C).
