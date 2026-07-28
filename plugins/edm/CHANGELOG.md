# Changelog

All notable changes to the EDM plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.1.0] — 2026-07-28

Wave C of EDMV3 (prompt-streamline): economics honesty (Phase 6 cost is now actually recorded,
per-round audit cost, honest token attribution and a refreshed pricing table, the human-baseline
comparison moved behind an opt-in flag), the delete-list epic (dead surfaces removed:
`lifecycle_mode=partial`, the grant ritual, the `TaskCompleted` no-op), the pattern-library
curation contract (Append Schema, keep/edit/discard at gates, a four-heading CI regression guard),
communication cadence and deliverable-length calibration, and this wave-C closeout ticket
(EDMV3-T66), which folds every individual wave-C change (landed incrementally on
`edm/edmv3-prompt-streamline` across EDMV3-T25(AC8), EDMV3-T30-T31, EDMV3-T33-T47, EDMV3-T50-T60)
into this single versioned entry.

### Wave-C QC remediation and prose-versus-code sweep

Folded into this same unreleased entry rather than given a version of its own, because none of it
shipped separately. Two QC shards audited T45-T67 and reported 34 findings; a subsequent
prose-versus-code sweep enumerated 118 enforcement points, checked 110, and found 24 more. Every
finding was remediated -- `NOTED` is the only status that closes one without a fix (decisions.md
D13), and the convergence gate counts open P2 as blocking, so there was no lower tier to park
anything in.

The findings that were code defects rather than documentation drift:

- **T54 never shipped its code half.** `update-patterns` still appended at end-of-file with no
  `pending-review` marker, while the contract document asserted it never does that and T56's own
  CI guard was built to fail on exactly what the append produced. Both stayed green only because
  nothing in the suite ever called `update-patterns`. Insertion is now heading-targeted and a
  missing heading is a skip, never an EOF fallback.
- **A de-duplication bug that produced eleven copies over ten runs.** The normalizer stripped one
  trailing paren group, but a library heading carries the source title's parens *plus* the
  `(prefix, date, severity)` group this command appends, so any finding title ending in parens
  never matched itself.
- **T55's gate curation was documented and unimplemented**, with a green test asserting the
  documentation.
- **`edm-lint-artifacts` was 70,168 ms** on a 30-file initiative against a 3,000 ms budget, from
  two per-line fork loops. Now 978 ms, with the Mermaid-class ratio at 1.19x against a 1.40x
  ceiling. Byte-identical detection across 17 fixtures, a purpose-built adversarial corpus and a
  full tree scan.
- **Indented code fences were invisible to the linter**, in both directions: false positives on
  the contents of an indented plain fence, and missed violations inside an indented mermaid fence.
- **Exit codes contradicted their own contract** -- usage and environment errors returned 1,
  colliding with "violations found", so the commit hook could not distinguish a misinvocation from
  a dirty tree.
- **The attribution class only recognized Claude.** `Generated-By: <any other tool>` passed clean
  despite the convention banning those trailers as a class.
- **`compute_cost_usd`'s family wildcards defeated T52 AC10 from inside a known family** (D32).
  Every generation of Opus, Sonnet or Haiku was priced at *current*-generation rates with no
  warning. This initiative's own recorded figures are the evidence: `model_used` is
  `claude-sonnet-5` and `claude-fable-5`, neither of which is in either pricing table, so the
  recorded $25.869 is placeholder arithmetic. Left as recorded rather than repriced against
  invented rates, and now warned rather than silent.
- **The convergence blocking set was described wrongly in four places.** `BLOCKING_FILTER`
  includes open P2; the skill said P2 does not block, so `audit-converged` would have refused a
  round the skill called clean.
- **`implementation_mode` was named in three places as governing the code audit.** It governs
  nothing of the kind, and the sentence mixed two orthogonal enums.
- **The convergence exemption existed twice** in `bin/edm-state`, byte-identically, while every
  prose description states it as one rule. Now one `convergence_exempt()`.
- **The CI lint stage ran four checks as sequential script lines** (T67 AC10), so their times
  summed and `set -e` hid every result after the first failure. Split into four jobs with
  `needs:`. That split then dropped `jq` from two of them, caught before merge; and it exposed
  that `edm-lint-artifacts --all` never had `edm-state` on PATH in any lint job, latent because
  this pipeline has not yet run against a live runner.
- **Nothing enforced ASCII on the plugin's own tree.** Class 2 scans initiative directories only,
  which is how four em dashes reached `skills/` and `agents/` prompt templates -- the literal
  shapes agents copy into artifacts. Shipped surfaces are now asserted ASCII-only, with a positive
  control on the detector: the first version of that check used `grep -P`, which BSD grep rejects
  with exit 2, and the guard swallowed it into a false green.
- **T67 AC8 asserted `hooks.json` had no uncommitted diff**, which goes green after any commit
  whatever the content. Replaced with seven assertions on the scoping properties it names.

Suite: 1401 assertions passing before this remediation's own test additions.

### Added

- **`edm-state phase-complete 6` is actually called** (EDMV3-T50): the orchestrator's Phase 6
  entry now invokes `/edm:verify-runtime` via the `Skill` tool and then calls
  `edm-state phase-complete <PREFIX> 6` itself -- the single owning, automatic call site.
  `skills/implement/SKILL.md` Step 8 and `README.md`'s command table restate the same
  two-command sequence only for the standalone/direct-invocation path. This closes the exact
  EDMV2 failure mode D9 identified: `phase-start 6` firing and `phase-complete 6` never following,
  leaving Phase 6 permanently recorded at 0s/$0.00.
- **`edm-state audit-round-complete <PREFIX> <code|srd|tickets>`** (EDMV3-T51): records a
  completion timestamp, duration, and token/cost totals for an individual code-audit round, keyed
  by audit type and round number, reusing the same `get_session_tokens_since` helper
  `phase-complete` uses (one cost computation, not two). `skills/code-audit/SKILL.md` calls it at
  the end of every round (full or partial), immediately after `edm-state render-ledger`. An
  unclosed round surfaces as an informational `OPEN_AUDIT_ROUND` anomaly on `edm-state validate`
  rather than staying invisible.
- **Update-patterns writes atomically** (EDMV3-92, EDMV3-T66 AC9): the pattern-library insertion
  path now builds its appended content in a tmp file beside the target
  `docs/audit-patterns/*.md` file and `mv`s it into place, rather than appending in place --
  never leaves a shared pattern file half-written if interrupted mid-append, and never
  interleaves with a concurrent `update-patterns` call on the same file.

### Changed

- **Token attribution scoped to the driving session, pricing refreshed** (EDMV3-T52, decisions.md
  D25): `get_session_tokens_since` now scopes to the single most-recently-modified session JSONL
  (falling back to the pre-fix whole-directory sum, recorded via `attribution_mode`) instead of
  summing every session JSONL unconditionally, so a second open Claude Code window no longer
  inflates a phase's or round's cost. Pricing constants move one generation forward (Opus
  4.7/Sonnet 4.6/Haiku 4.5 -> Opus 4.8/Sonnet 4.7/Haiku 4.6, verified 2026-07-28); previous-generation
  identifiers and rates are frozen (not env-overridable) so an already-recorded state file is never
  silently repriced on a later read, and an unrecognized `model_used` now warns explicitly and
  prices at a Sonnet-tier placeholder rather than silently costing zero.
- **The human-baseline comparison leaves default output** (EDMV3-T53): `edm-state metrics-report`
  now shows raw Claude cost and duration by default, with no baseline/multiple/savings language.
  `--with-human-baseline` is the explicit opt-in that restores the comparison, labelled as an
  estimate. `human_baseline_usd` continues to be recorded in state on every phase regardless, so
  the comparison remains reconstructable. `skills/metrics/SKILL.md` no longer frames the
  comparison as a headline. `metrics-report` also gains a code-audit section (rounds run, lenses
  per round, cost per round) and a tiered-vs-untiered lens-cost section where tiering data exists
  (omitted, not rendered empty, where it does not).
- **Delete-list epic executed** (EDMV3-T57..T60, D12/D24): `lifecycle_mode=partial` is removed
  from `LIFECYCLE_MODE_ENUM_LIST` (existing state files carrying the legacy value still read
  without error, C-4); the standalone grant-approval ritual and the `TaskCompleted` hook no-op are
  deleted; `.pptx`/`.docx` assets moved out of the plugin directory (`docs/`) and the CI
  file-type-ban job flips from `allow_failure: true` to blocking; the `monitors/watch-impl`
  lifecycle finding (D24) is documented (host-managed, Branch A) rather than deleted.
- **Pattern-library curation contract** (EDMV3-T54..T56): a pending-review Append Schema, a
  keep/edit/discard decision surfaced at gates, and a four-`##`-heading Living-Library contract
  now enforced as a CI regression guard rather than only a convention.
- **CI blocking scope widened** (EDMV3-T66 AC11): `bin/edm-check-vocabulary` and the four-heading
  contract check are both blocking in the CI lint stage. After this wave, exactly two jobs in
  `.gitlab-ci.yml` carry `allow_failure: true`: `validate:plugin-cli` (tier-2 `claude plugin
  validate`, no CLI in every runner image) and `eval:nightly` (reaches the Anthropic API). The
  file-type-ban job (previously non-blocking) is no longer one of them, per the delete-list item
  above.

### Schema version decision (EDMV3-T66 AC2)

`schema_version` stays at `2` for wave C -- **not** bumped to `3`. Wave C's only state-shape work
(EDMV3-T51's round-completion fields) is an additive extension of the wave-B round-record shape
already certified at `schema_version 2` (adds `completed_at`, `duration_seconds`, `tokens`,
`model_used`, `estimated_cost_usd`, `attribution_mode` to an existing `rounds[]` entry), not a new
shape a reader must recognize to interpret correctly. Every wave-C check that consults these
fields reads them with jq `//` defaults, so no check requires `schema_version >= 3`. Bumping for
symmetry with the wave number would create a version value with no check gated on it -- the same
prose-not-mechanism drift this initiative exists to close.

### Known scope gap (recorded, not faked)

`CLAUDE.md`'s "Model and effort assignments" table update to reflect **measured**
lens tiering (EDMV3-T48) has not landed as of this entry: the wave-C tiering matrix (D16) has not
yet been run against the wave-A eval fixture, so all 11 code-audit lens agents remain
`opus`/`max` on disk. Per D15, an AC whose stated precondition (measured tiering data) does not
yet exist is not asserted as passing here. `CLAUDE.md`'s Model and effort table is left
unchanged pending EDMV3-T48; this is a recorded scope gap for EDMV3-T48 to close, not a wave-C
regression.

### Preserve-untouched verification (EDMV3-111, all eight, EDMV3-T66 AC10)

1. **State-derived path resolution** -- unchanged: `resolve-dir`/`initiative_dir_for` still resolve
   both flat and product-scoped layouts; no new wave-C write path (`audit-round-complete`,
   `update-patterns`) hardcodes a path -- both call `initiative_dir_for`/the existing
   `patterns_dir` resolution.
2. **Locking and atomicity** -- unchanged and extended: every new wave-C write
   (`audit-round-complete`) goes through the existing `rmw_state` helper; `update-patterns`'
   insertion path is now also atomic (tmp file + `mv`, this wave, see Added above).
3. **Artifact-hash drift detection** -- unchanged: no wave-C ticket touches `artifact_hashes` or
   its check.
4. **QC verdict semantics** -- verbatim: PASS/PARTIAL/FAIL definitions in
   `skills/implement/SKILL.md` are byte-identical to wave B.
5. **Gate approval rules text** -- verbatim: the canonical Gate PROTOCOL section in
   `skills/orchestrator/SKILL.md` is unchanged by any wave-C ticket.
6. **Stable CA-NNN IDs and demote-don't-delete** -- unchanged: `edm-audit-synthesizer`'s merge
   logic is untouched this wave.
7. **Lint infrastructure extended, not replaced** -- the three existing violation classes
   (attribution trailers, non-ASCII bytes, leaked tool tags) behave identically; only the
   file-type-ban job's blocking status changed (CI config, not linter behavior).
8. **HANDOFF auto-refresh and `## Notes`** -- unchanged: no wave-C ticket touches
   `cmd_write_handoff`.

### Performance and cost budgets measured (EDMV3-T67)

A committed, executable timing harness (`bin/tests/timing.sh`) measures the eight budgets named
in EDMV3-T67 against reproducible, generated fixtures (a 50-initiative repo, a 500-finding
ledger, a 30-file/~10,000-line initiative directory) rather than ad hoc one-off numbers. Every
figure below was measured on this machine (macOS, bash 3.2.57, this initiative's working tree);
figures that require the pinned CI runner image or a live pipeline are marked
**verified-locally-pending-pipeline** rather than asserted as certified. `get_session_tokens_since`
now bounds its read of each session JSONL to the last `${EDM_TOKEN_READ_LINE_CAP:-20000}` lines
(`tail -n`, per file) so phase-complete's latency can no longer grow unbounded with total session
history (AC2's `since`-anchored read means the messages that matter are always among the newest
lines).

| AC | Budget | Measured (this machine) | Result |
|---|---|---|---|
| AC1 | get/resolve-dir/branch-check/gate-check < 250ms p95 (50-init fixture) | get 28ms, resolve-dir 28ms, branch-check 48ms, gate-check 64ms | PASS |
| AC2 | phase-complete < 2000ms p95 excl. token read; token read bounded | 340ms p95; bound added (`tail -n` cap, see above) | PASS |
| AC3 | audit-converged < 500ms p95, render-ledger < 1000ms p95 (500-finding ledger) | audit-converged 123ms, render-ledger 84ms | PASS |
| AC4 | check_permission_rules() adds < 50ms to session-start | measured delta -2ms (noise-level) | PASS |
| AC5 | full lint of one initiative directory of **30 files / 9,990 lines** < 3000ms p95 (the fixture size is part of the budget: `bin/tests/timing.sh --lint`, 30 files x 333 lines) | **1,021ms p95** (samples 1035/1021/1018) after the `edm-lint-artifacts` rewrite in commit `d591b92` | PASS |
| AC6 | Mermaid class adds <= 40% lint time vs. 3-class baseline (stated as a bare 1.40x ratio, with no input size and no absolute floor) | **1.19x** on the 30-file/9,990-line fixture (baseline 1,000ms, with-Mermaid 1,193ms) after the class-4 rewrite in commit `ea31ce8`; was 3.40x immediately after `d591b92` and 2.26x before either | **PASS on the number, but the budget is still malformed** (see the note below the table) |
| AC7 | `--all` over 50 initiatives < 60,000ms (CI budget) | 1,671ms | PASS |
| AC8 | commit-hook scoping in `hooks.json:80-90` unchanged | `git diff --stat` shows zero changes to `hooks/hooks.json` | PASS |
| AC9 | blocking pipeline < 5 minutes at each wave boundary, fixed fixture subject | not run against a live GitLab runner this session | **verified-locally-pending-pipeline** |
| AC10 | the four lint checks (`bash -n`, `edm-lint-artifacts --all`, `edm-check-grants`, `edm-check-vocabulary`) run as parallel jobs | split into `lint:bash-syntax`, `lint:artifacts`, `lint:grants` and `lint:vocabulary`; every `lint` job carries `needs: []` and the three `test` jobs carry `needs: ["lint:bash-syntax"]` | **PASS** (pipeline parses; graph is seven independent `lint` jobs plus three `test` jobs gated on the syntax check. `grep -n 'needs:' .gitlab-ci.yml` now returns the keys AC10 asked for) |
| AC11 | no blocking job reaches the network beyond image pull | exactly 2 `allow_failure: true` lines (`validate:plugin-cli`, `eval:nightly`), both outside the blocking path; confirmed by `grep` | PASS |
| AC12 | code-audit round cost measurable and reported, **and** the EDMV3-T48 AC11 tiering reduction figure recorded alongside it (before and after figures with the percentage delta) | First half met: `metrics-report` renders the code-audit section (rounds run, lenses per round, cost per round) once EDMV3-T51 data exists, per this wave's own T51/T53 work. Second half unmet: there is no before figure, no after figure and no delta, because EDMV3-T48's tiering matrix was built and never run | **MISS -- recorded** (the tiering half has no data to record: decisions.md D28) |
| AC13 | one eval run < 30 minutes, cost documented | `evals/README.md` already documents 30-60 minutes wall-clock and a `$15`/phase budget ceiling from a prior measured run (2026-07-27) -- the existing documented range itself brackets the 30-minute figure, so a fresh timed run is needed to confirm | **verified-locally-pending-pipeline** (a live eval run was not triggered this session -- real API spend and up to an hour of wall time) |
| AC14 | reproducible, committed timing script | `bin/tests/timing.sh`, executable, all modes above run from it | PASS |

**Two real, recorded misses (AC6, AC12) are not silently accepted.** Per this ticket's own
Out of Scope clause ("optimizing anything that misses a budget... this ticket measures and
records"), each is left for its own follow-on ticket rather than patched here under time
pressure without a fresh full-suite validation pass.

**AC5 was a fourth miss and is now a PASS.** `bin/edm-lint-artifacts` was rewritten for
performance in commit `d591b92`: class 1 (attribution) had been forking `echo | tr` twice per
line and now runs a single `grep -niF -f` per file, and `build_line_classes()` is a single awk
pass instead of a per-line bash `while IFS= read -r` loop. The 39,872ms originally recorded here
(re-profiled at 70,168ms on the same fixture before the fix) measures 1,021ms p95 afterwards,
against the same 3,000ms budget on the same 30-file/9,990-line fixture. The budget is restated in
the table above **with its input size attached**, because a passing number quoted against an
unstated fixture size recreates the same defect in the opposite direction.

**AC6's budget is malformed, independently of what it measures.** Both QC shards ruled this
independently. A bare ratio with no stated input size and no absolute floor is dominated by fixed
process overhead: it reads differently on every machine, and it moves when unrelated code gets
faster. That is exactly what happened here, twice, in both directions. The AC5 rewrite
(`d591b92`) made the baseline roughly 40x faster without touching the Mermaid class, and the
ratio got *worse* -- 2.26x to 3.40x -- because class 4 became the dominant cost rather than a
marginal one. Optimizing class 4 in turn (`ea31ce8`, the same one-process-per-file treatment
class 1 got) brought it to 1.19x. So the same budget read miss, worse-miss, then pass across
three commits, only one of which touched the code it is supposed to be measuring.

The number now passes and the budget is still wrong. It needs re-deriving as a conditional --
"the ratio applies only above N lines / N ms", with an absolute floor below which it does not
bind -- and re-measuring on the 50-initiative fixture the AC actually names; the recorded 2.26x
was taken on a 5-file fixture, so the original figure never answered the AC either way. A green
number against an unstated fixture size recreates the same defect in the opposite direction,
which is why this row reads "PASS on the number" rather than PASS. The re-derivation is the one
piece of EDMV3-T67's budget work that remains open; the Mermaid-class optimization it used to
be paired with has landed.

AC10's gap was structural, not a speed problem, and it is now closed: `lint:shell-and-artifacts`
ran the four checks as sequential script lines in one job, so their wall-clock times summed and
`set -e` meant the first failure suppressed the results of the other three. They are now four
jobs joined by `needs:`. AC12's gap is missing data, not code: the code-audit cost half ships and works, but the
tiering before/after and percentage delta cannot be recorded because EDMV3-T48's matrix was built
and never run (decisions.md D28 carries the closing command).

## [3.0.0] — 2026-07-28

Wave B of EDMV3 (prompt-streamline): the enforcement kernel's version-2 checks (PARTIAL closure,
computed convergence), the structured JSONL findings ledger and its deterministic markdown
render, the no-deferral-vocabulary policy and its automated checker, the mandatory
`/edm:verify-runtime` closure skill, the Skill-tool composition/dispatcher restructure (gate
PROTOCOL collapsed to one canonical section, every phase skill's Step 0 preflight), and the
Mermaid diagram-convention rule. EDMV3-T65 is the wave-B closeout ticket that folds every
individual wave-B change (landed incrementally on `edm/edmv3-prompt-streamline` across
EDMV3-T18, EDMV3-T24 through EDMV3-T36, EDMV3-T40, and EDMV3-T42 through EDMV3-T44) into this
single versioned entry.

**This is a major version bump, not a minor one, because the Skill-tool composition/dispatcher
restructure (EDMV3-T34, EDMV3-T35, EDMV3-T36) is a breaking behavioural change for anyone who
invoked phase skills directly and relied on the previous local-approval-prompt path** -- see
"Breaking changes" below. **The permission `ask` rule setup documented in README.md's "Required
setup" section (`Bash(edm-state approve-gate*)` and `Bash(edm-state archive*)`) is required for
this version's enforcement guarantees to hold** -- without it, `check_permission_rules()` records
`prose-only` enforcement instead of `permission-ask`, and the `PERM_RULES_MISSING` informational
anomaly fires on every `validate` call.

### Breaking changes

- **`branch-check` becomes a BLOCK on the standalone-skill path** (EDMV3-T36): every phase
  skill's new Step 0 preflight runs `edm-state branch-check <PREFIX>` and hard-blocks the phase
  on a non-zero exit. Previously `branch-check` hard-blocked only at the orchestrator's Step 1d,
  so running e.g. `/edm:code-audit PREFIX` directly (bypassing the orchestrator) worked from any
  branch; that posture now requires checking out the initiative's recorded `initiative_branch`
  first. Both the `UserPromptExpansion` hooks and the orchestrator's own Step 1d check are
  retained unchanged -- Step 0 is a second, defence-in-depth enforcement point on the Skill-tool
  path, not a replacement for either.
- **`current_step` vocabulary migration (EDMV3-T38): tracked, not yet landed as of this entry.**
  EDMV3-T38's orchestrator/dispatcher restructure defines a `current_step` vocabulary mapping
  from the 2.x values (`1a`, `1b`, `1c`, ...) to a wave-B vocabulary, with old values tolerated
  and resumed with a warning rather than erroring. EDMV3-T38 had not landed on
  `edm/edmv3-prompt-streamline` as of this changelog entry; its published mapping supersedes this
  paragraph once it does. Recorded here rather than omitted because EDMV3-95 names this item
  explicitly and an honest "not yet" is more useful than silence.
- **archive hard-blocks on any unclosed or FAIL-closed `partial_verdict_map` entry** (EDMV3-T18):
  previously an open PARTIAL was tracked but never checked by `archive`. At `schema_version >= 2`
  every PARTIAL must be closed `PASS` via `/edm:verify-runtime` before `archive` will run; no
  override flag exists. Below `schema_version` 2 this degrades to warn-and-proceed (unchanged
  behaviour for pre-wave-B initiatives).

### Added

- **Eleven code-audit lens agents emit structured JSONL findings** (EDMV3-T24): every
  `agents/edm-audit-*.md` lens instructs a JSONL sibling (one line per finding, `confidence`
  mandatory, "every finding" scope stated literally) alongside its prose report. A committed
  synthetic pass fixture (`bin/tests/fixtures/code-audit/`) proves the eleven-lens shape end to
  end and lets the eval scorer's lens-jsonl-prose-agreement dimension score non-null.
- **`edm-audit-synthesizer` writes `findings-ledger.jsonl` as the authoritative record**
  (EDMV3-T25): the legacy `findings-ledger.md` is no longer written by the synthesizer (it is
  now a pure, deterministic projection rendered by `edm-state render-ledger`, see below). Stable
  `CA-NNN` IDs are assigned once and preserved across rounds; `resolved_round`/`raised_round`
  track cross-round history; a single-lens, low-confidence finding is retained and demoted to
  `NOTED` rather than discarded -- no finding is ever removed from the ledger. The abolished
  `deferred` status is dropped from the enum (`open`/`fixed`/`noted` only going forward); a
  legacy `deferred` line already on disk is read and re-opened for backward compatibility, never
  an error.
- **No-deferral-vocabulary policy and its checker** (EDMV3-T29, EDMV3-T30): `CLAUDE.md`'s
  Severity vocabulary section states that `NOTED` is not actionable and is distinct from
  deferral, and that deferral does not exist in this methodology. `edm-check-vocabulary` is a
  new deterministic scanner (`skills/`, `agents/`, `docs/`, `hooks/hooks.json`,
  `monitors/monitors.json`, `CLAUDE.md`, `README.md`, `bin/`) backstopping that policy so it
  cannot silently regress; a documented, justified allowlist (`bin/vocabulary-allowlist.txt`)
  carves out the handful of legitimate uses (e.g. this file's own history, a data-shape
  identifier on legacy ledger input).
- **`implement` and QC remediate every FAIL, and every PARTIAL closes via `/edm:verify-runtime`**
  (EDMV3-T31): `skills/implement/SKILL.md`'s FAIL compilation is no longer severity-filtered
  (every severity, not just P0/P1), and the abolished "PARTIALs do not require remediation"
  sentence is rewritten to require mandatory runtime-verified closure. `agents/edm-qc-auditor.md`
  keeps "Never invent a PASS for something you cannot verify" verbatim (preserve-untouched item
  4, see below) with only the note token renamed.
- **`edm-state render-ledger <PREFIX>`** (EDMV3-T26): deterministically renders
  `code-audit/findings-ledger.md` from the authoritative `code-audit/findings-ledger.jsonl`,
  sorted by `(severity, ID)` for byte-identical output across runs. Writes a machine-readable
  generated-file header, includes a `Decisions / Non-Findings` section for `NOTED` items, writes
  atomically (temp file plus rename), and records the rendered file's hash via the existing
  `record_artifact_hash` helper so `edm-state checkpoint-if-active`'s drift loop warns on a
  hand-edit out of band. Refuses (non-zero exit, writes nothing) with a message distinguishing
  "no audit has run" from "the render failed" when `findings-ledger.jsonl` is absent or invalid.
- **`edm-state audit-round-start` records the round's lens set and `round_type`** (EDMV3-T27):
  a new optional `--lenses <comma-list>` argument records which lenses ran; `round_type` is
  derived as `full` when all eleven lenses ran (or `--lenses` was omitted) and `partial`
  otherwise. `audit_rounds.<type>` widens from a bare integer round-count to
  `{count, rounds: [...]}` to hold this per-round detail (the one sanctioned C-4 type widening
  in this initiative) -- no existing state file is rewritten; every reader coerces a bare
  integer to `{count: N, rounds: []}` at read time. The external contract of
  `N=$(edm-state audit-round-start <PREFIX> code)` is unchanged (still echoes the round number).

- **`edm-state audit-converged <PREFIX>`** (EDMV3-T28): a read-only convergence query over
  `code-audit/findings-ledger.jsonl`, replacing "a human re-reads the ledger and asserts
  convergence in prose" with one deterministic `jq` predicate (`BLOCKING_FILTER`, defined once
  and referenced by name at all four consumers: `audit-converged` itself, `approve-gate`'s
  code-audit branch, `archive`'s convergence check, and `write-handoff`'s Phase-6 rendering).
  Exit 0 converged (or the mode/lifecycle_mode is exempt from a code audit entirely); exit 1
  when open P0/P1/P2 findings remain, the latest round was partial, or a line carries an
  out-of-enum status; exit 3 when no ledger exists (distinguishing "no audit has run" from a
  legacy markdown-only ledger, which degrades per `schema_version` rather than demanding a
  fresh audit). A legacy `deferred` status line is re-opened (counted as open at its recorded
  severity) rather than skipped or erroring.
- **`approve-gate <PREFIX> code-audit` re-runs the convergence pre-check** (EDMV3-T28 AC12): at
  `schema_version >= 2`, the approval now calls `audit-converged` itself and refuses when it
  fails, closing the time-of-check-to-time-of-use window between a standalone
  `audit-converged` call and the approval. Below `schema_version` 2, this degrades to the
  existing wave-A permissive behaviour (recorded via `degraded_checks`), so a pre-wave-B
  initiative is never told to run a fresh eleven-lens round it never opted into.
- **`archive` gains its wave-B sub-checks: PARTIAL-closure and a computed audit-converged
  re-query** (EDMV3-T18): fills the two wave-B insertion points left in `cmd_archive`. Every
  `partial_verdict_map` entry must be closed `PASS` (a `FAIL`-closed or still-open entry blocks,
  no override); `archive` additionally re-queries `audit-converged` directly rather than trusting
  the cached `code_audit_converged` boolean alone, closing the time-of-check-to-time-of-use gap
  one more consumer deep. Both checks degrade to warn-and-proceed below `schema_version` 2. A new
  `OPEN_PARTIALS` blocking anomaly surfaces unclosed/FAIL-closed entries from `validate`, and
  HANDOFF gains an "Open Code-Audit Findings" section sourced from the ledger when present.
- **Canonical Mermaid diagram conventions, referenced by name from eleven touch points**
  (EDMV3-T40, EDMV3-T42): `CLAUDE.md` gains a `## Mermaid diagram conventions (canonical)`
  section (the `#59;` entity-code rule for a literal `;` inside label/edge/message text, worked
  examples, legal exceptions). Three authoring agents, two auditing agents, and four skills
  reference it by name; the two writer-facing pattern-library docs
  (`docs/audit-patterns/srd-audit.md`, `docs/audit-patterns/ticket-audit.md`) gain a matching
  entry.
- **`edm-lint-artifacts` gains a fourth violation class: Mermaid label semicolons**
  (EDMV3-T43, EDMV3-T44): a one-pass line classifier flags a raw `;` inside Mermaid
  label/edge/message text (the three existing classes -- attribution trailers, non-ASCII bytes,
  leaked tool-invocation tags -- are unaffected). A committed 16-file fixture corpus (11 valid,
  5 invalid) asserts the exact violation set with zero false positives.
- **`edm-sync-canonical-sections` and `docs/canonical-sections.md`** (EDMV3-T41): `claude plugin
  validate` confirms plugin-root `CLAUDE.md` is never loaded as runtime context, so by-name
  references like `` `CLAUDE.md Sec."Severity vocabulary"` `` have no plugin-relative path to
  resolve against from an installed cache. This generator deterministically, one-directionally
  duplicates the Severity vocabulary and Mermaid diagram conventions sections, byte-identical,
  into `docs/canonical-sections.md` -- see `decisions.md` D22 for the full finding and the
  still-open handoff (the nine prompt-surface reference-form updates).

- **`edm-state render-ledger <PREFIX>`** (EDMV3-T26): deterministically renders
  `code-audit/findings-ledger.md` from the authoritative `code-audit/findings-ledger.jsonl`,
  sorted by `(severity, ID)` for byte-identical output across runs. Writes a machine-readable
  generated-file header, includes a `Decisions / Non-Findings` section for `NOTED` items, writes
  atomically (temp file plus rename), and records the rendered file's hash via the existing
  `record_artifact_hash` helper so `edm-state checkpoint-if-active`'s drift loop warns on a
  hand-edit out of band. Refuses (non-zero exit, writes nothing) with a message distinguishing
  "no audit has run" from "the render failed" when `findings-ledger.jsonl` is absent or invalid.
- **`edm-state audit-round-start` records the round's lens set and `round_type`** (EDMV3-T27):
  a new optional `--lenses <comma-list>` argument records which lenses ran; `round_type` is
  derived as `full` when all eleven lenses ran (or `--lenses` was omitted) and `partial`
  otherwise. `audit_rounds.<type>` widens from a bare integer round-count to
  `{count, rounds: [...]}` to hold this per-round detail (the one sanctioned C-4 type widening
  in this initiative) -- no existing state file is rewritten; every reader coerces a bare
  integer to `{count: N, rounds: []}` at read time. The external contract of
  `N=$(edm-state audit-round-start <PREFIX> code)` is unchanged (still echoes the round number).

- **`edm-state audit-converged <PREFIX>`** (EDMV3-T28): a read-only convergence query over
  `code-audit/findings-ledger.jsonl`, replacing "a human re-reads the ledger and asserts
  convergence in prose" with one deterministic `jq` predicate (`BLOCKING_FILTER`, defined once
  and referenced by name at all four consumers: `audit-converged` itself, `approve-gate`'s
  code-audit branch, `archive`'s convergence check, and `write-handoff`'s Phase-6 rendering).
  Exit 0 converged (or the mode/lifecycle_mode is exempt from a code audit entirely); exit 1
  when open P0/P1/P2 findings remain, the latest round was partial, or a line carries an
  out-of-enum status; exit 3 when no ledger exists (distinguishing "no audit has run" from a
  legacy markdown-only ledger, which degrades per `schema_version` rather than demanding a
  fresh audit). A legacy `deferred` status line is re-opened (counted as open at its recorded
  severity) rather than skipped or erroring.
- **`approve-gate <PREFIX> code-audit` re-runs the convergence pre-check** (EDMV3-T28 AC12): at
  `schema_version >= 2`, the approval now calls `audit-converged` itself and refuses when it
  fails, closing the time-of-check-to-time-of-use window between a standalone
  `audit-converged` call and the approval. Below `schema_version` 2, this degrades to the
  existing wave-A permissive behaviour (recorded via `degraded_checks`), so a pre-wave-B
  initiative is never told to run a fresh eleven-lens round it never opted into.

### Changed

- **`wave4a-smoke.sh`'s `audit_rounds.code` assertion re-baselined** (EDMV3-T27, same commit as
  the widening): reads `.audit_rounds.code.count` instead of the old bare-integer
  `.audit_rounds.code`.
- **`code_audit_gate_ledger` now records the real ledger path** (EDMV3-T28) instead of the
  hardcoded wave-A interim literal `"absent"`, when `code-audit/findings-ledger.jsonl` exists at
  approval time.
- **branch-check becoming a BLOCK on the standalone-skill path** (EDMV3-T36): every phase
  skill's new Step 0 preflight runs `edm-state branch-check <PREFIX>` and now hard-blocks the
  phase on a non-zero exit. Previously `branch-check` hard-blocked only at the orchestrator's
  Step 1d, so running e.g. `/edm:code-audit PREFIX` directly from `main` worked, and reviewing an
  initiative from another branch was a common code-audit posture. That posture now requires
  checking out the initiative's recorded `initiative_branch` first. This is a behaviour change,
  not a bug fix -- both the `UserPromptExpansion` hooks and the orchestrator's own Step 1d check
  are retained unchanged; Step 0 is a second, defence-in-depth enforcement point on the
  Skill-tool path, not a replacement for either.
- **The gate PROTOCOL restated at five sites collapses to one canonical section**
  (EDMV3-T35): `skills/orchestrator/SKILL.md`'s `## Gate PROTOCOL (canonical)` is now the single
  definition every gate site in the plugin cites by name; no behavioural change to gate approval
  rules themselves (the four preserved rules are verbatim), only to where the rules live.

### Added (continued)

- **`edm-state record-partial-verdict <PREFIX> <ticket> close <PASS|FAIL> <verification_ref>`**
  (EDMV3-T32): closes an existing PARTIAL entry in `partial_verdict_map` without losing the
  original note -- the whole prior entry (verdict, note, recorded_at) nests under a `prior` key
  alongside the new `closing_verdict`, `closed_at` and `verification_ref`. An entry may be
  closed only once; the sole exception is re-closing an entry whose existing closure was
  `FAIL` (after remediation), which appends to a `closure_history` array instead of
  overwriting. Only `PASS` and `FAIL` are legal closing verdicts. The existing
  `<PREFIX> <ticket> <PASS|PARTIAL|FAIL> [<note>]` open/record form (used by
  `hooks/hooks.json`'s `SubagentStop` handler and `skills/implement/SKILL.md`) is unchanged --
  the literal third argument `close` disambiguates the two forms.
- **New skill `/edm:verify-runtime <PREFIX>`** (EDMV3-T33): the mandatory Phase 6 closure step.
  Reads `partial_verdict_map`, drives each PARTIAL to a closing `PASS` or `FAIL` via
  `edm-state record-partial-verdict ... close`, and writes `post-deploy/verification.md` (one
  section per closure, appended not overwritten). Exactly two closing verdicts, ever -- see the
  new `CLAUDE.md` "Unverifiable acceptance criteria (D15)" policy below.
- **D15 policy: unverifiable acceptance criteria are a specification defect** (EDMV3-T33):
  `CLAUDE.md` gains a new section stating that an AC whose runtime environment does not exist is
  reworked or moved out of scope via gate change control -- never a third verdict
  (`BLOCKED`/`WAIVED`/`N/A-runtime` do not exist in this methodology).
- **`current_step` fields and Skill-tool composition documented** (EDMV3-T34): `CLAUDE.md`
  architectural rule 2 now documents the Skill-tool composition pattern (the orchestrator
  dispatches; each phase skill owns its phase) in place of the abolished "skills don't load other
  skills" sentence, which was no longer true of current Claude Code. Decision D21 (GO) records a
  live two-level skill-composition spike in `SRD/edm/EDMV3__prompt-streamline/decisions.md`.
- **Step 0 -- Gate and Branch Preflight, all eight phase skills** (EDMV3-T36): every phase skill
  (`plan`, `srd`, `audit-srd`, `tickets`, `audit-tickets`, `implement`, `code-audit`,
  `verify-runtime`) now opens with a Step 0 that runs `edm-state gate-check` and
  `edm-state branch-check` before doing anything else, as defence in depth on the Skill-tool
  invocation path (Tier 3, prompt text -- the deterministic enforcement is `cmd_gate_check`
  itself, EDMV3-115/T13). Written once in `skills/plan/SKILL.md`, referenced by name from the
  other seven.

### Backward Compatibility

Every wave-B change is backward compatible for existing state files (EDMV3-107): `schema_version`
gates every new version-2 check so a wave-A (`schema_version: 1`) or legacy (absent) initiative
warn-and-proceeds through the PARTIAL-closure check, the `audit-converged` re-query, and the
round-type gate, naming each skipped check rather than silently applying or silently skipping it.
No existing field changes meaning or name; `audit_rounds.<type>` is the one sanctioned type
widening (bare integer -> `{count, rounds}`), and every reader coerces the legacy shape at read
time rather than requiring a rewrite.

### Downgrade Path

Downgrading an initiative under 3.0.0 back to a 2.1.0-era `edm-state` binary is possible but
lossy. Four concrete things break:

1. **The synthesizer writes `findings-ledger.md` again while a stale `findings-ledger.jsonl`
   remains on disk and is still authoritative** for anyone still on 3.0.0 -- do not delete the
   JSONL or treat a post-downgrade markdown render as its replacement; the two are a fork, not a
   continuation, until re-upgrading.
2. **PARTIAL closure records become invisible.** A 2.1.0 `edm-state` does not read
   `closing_verdict`/`closed_at`/`verification_ref`, so every `partial_verdict_map` entry looks
   still-open even if already closed PASS/FAIL under 3.0.0 -- do not re-verify against that view.
3. **`/edm:verify-runtime` disappears while `partial_verdict_map` closure entries persist on
   disk.** A 2.1.0 install cannot close a new PARTIAL until re-upgrading; existing closures are
   only unreadable by 2.1.0 (item 2), not deleted -- re-upgrading recovers them losslessly.
4. **The recorded `schema_version` is the signal a downgraded install should refuse to act on,
   not ignore.** 2.1.0 has no `schema_version >= 2` gating, so it applies wave-A-shaped checks to
   a 3.0.0-shaped file rather than refusing. Use a 2.1.0 binary on a `schema_version: 2`+ file for
   read-only inspection only; a full downgrade should re-`edm-init` under 2.1.0.

### Preserve-untouched list verification (EDMV3-111, items 4-6, wave B)

Per-wave verification of the review's "genuinely good -- do not refactor away" list. Commands and
findings (items 1-3, 7-8 were wave-A/earlier; the full eight-item walk closes at the final wave):

- **Item 4, QC verdict semantics** -- `grep -n 'Never invent a PASS' plugins/edm/agents/edm-qc-auditor.md`
  finds it verbatim (line 33); the PASS/PARTIAL/FAIL semantics table is otherwise unchanged. Only
  the runtime note token was renamed (`runtime-check:`, EDMV3-T31) -- confirmed PRESERVED.
- **Item 5, gate approval rules text** -- the four "CRITICAL -- gate approval rules" bullets now
  live once in `skills/orchestrator/SKILL.md`'s `## Gate PROTOCOL (canonical)` section
  (EDMV3-T35) rather than restated at five sites; diffed byte-for-byte against the pre-T35
  wording (`git show <pre-T35 commit>^:plugins/edm/skills/orchestrator/SKILL.md`) -- identical.
  Confirmed PRESERVED, relocated not reworded.
- **Item 6, stable CA-NNN IDs and demote-don't-delete** -- `grep -n 'CA-NNN\|demoted, never deleted'
  plugins/edm/agents/edm-audit-synthesizer.md` confirms the stable-ID scheme ("assigned once and
  preserved across every subsequent round") and demote-don't-delete language ("No finding is
  removed from the ledger by this step") both carried into the EDMV3-T25 JSONL rewrite unchanged.
  Confirmed PRESERVED.

## [2.1.0] — 2026-07-27

Wave A of EDMV3 (prompt-streamline): the enforcement kernel, the mechanical-fixes epic, the CI
pipeline and fixture eval harness, and a first tranche of measured model/effort downgrades
(D16). EDMV3-T64 is the wave-A closeout ticket that folds every individual wave-A change (landed
incrementally on `edm/edmv3-prompt-streamline` across EDMV3-T01 through EDMV3-T23 and
EDMV3-T61-EDMV3-T63) into this single versioned entry.

### Added

- **GitLab CI pipeline** (`.gitlab-ci.yml`, EDMV3-T21): four stages -- `lint` (shell syntax,
  `edm-lint-artifacts --all`, `edm-check-grants`, shellcheck on the unquoted-expansion class),
  `test` (`run-all.sh` on the pinned image and again under `bash:3.2`, plus
  `edm-state validate` across every tracked initiative), `validate` (a deterministic
  manifest-vs-disk check plus a `claude plugin validate` tier-2 job compared against a committed
  warning-count baseline), and `eval` (the nightly fixture-eval run, `allow_failure: true`).
- **Fixture eval harness** (EDMV3-T22, EDMV3-T23): a headless eval driver
  (`plugins/edm/evals/run-eval.sh`) against a committed `tiny-svc` fixture, a five-dimension
  mechanical scorer (`plugins/edm/evals/score-artifacts.sh`), and a wave-A baseline capture
  pending (see `evals/baseline/README.md`).
- **Smoke-test harness helpers** (EDMV3-T19): `with_scratch_repo`, `check_fails`, and
  `check_state_unchanged` in `bin/tests/_harness.sh`, shared by every `*-smoke.sh` suite instead
  of each suite hand-rolling its own scratch-repo/assertion boilerplate.
- **`run-all.sh` smoke aggregator** (EDMV3-T20): auto-discovers every `bin/tests/*-smoke.sh`
  suite by glob (a new suite runs without being added to a hand-kept list), prints a per-suite
  pass/fail table, and exits non-zero naming the failing suite(s).
- **`edm-lint-artifacts --all` / `--path`** (EDMV3-T20): scan every initiative under the SRD
  root (flat and product-scoped layouts, `.archived/` excluded) or an arbitrary directory/file
  directly, in addition to the existing single-`<PREFIX>` mode. Exit code 2 added for a usage
  error (mutually-exclusive-argument misuse), alongside the existing 0 (clean) / 1 (violations).
- **`edm-check-grants`** (EDMV3-T03): a four-source grant/instruction contract checker --
  cross-references each agent's tool grants against its own prose instructions, the invoking
  skill's `allowed-tools`, and the skill's own instructions, and flags a grant with no
  corresponding instruction.
- **`edm-state migrate-schema`** (EDMV3-T10): backfills `schema_version` on existing initiatives
  that predate the field, so the three-valued degradation class (EDMV3-T09/EDMV3-T14) has a
  value to read instead of treating every pre-existing initiative as permanently legacy.
- **Permission `ask` rules setup and detection** (EDMV3-T06, EDMV3-08): documented required
  `.claude/settings.json` block (see `CLAUDE.md`/`README.md` "Required setup: permission `ask`
  rules"), detected at runtime by `check_permission_rules()` and recorded on every gate approval
  as an `enforcement` tag (`permission-ask` | `prose-only`); its absence surfaces as an
  informational `PERM_RULES_MISSING` anomaly rather than silently proceeding unenforced.

### Changed

- **Gate enforcement moved into the kernel** (EDMV3-T08, EDMV3-T13): `gate-check` is now a
  complete, hard-blocking check rather than an advisory one, and `approve-gate` accepts the
  `code-audit` gate while keeping `gates_approved` integral.
- **`cmd_set` allowlist and `schema_version` contract** (EDMV3-T09): every key `cmd_set` will
  write is enumerated once in `SETTABLE_KEYS`; an unknown key is refused before any mutation,
  naming the full legal list. `schema_version` is refused from `cmd_set` entirely -- it is a
  single-writer field, advanced only by `edm-state migrate-schema`.
- **`phase-complete` requires the phase's artifact** (EDMV3-T11): a phase can no longer be
  marked complete without its artifact file present and non-empty on disk; there is no force
  path.
- **`archive` verifies the whole lifecycle** (EDMV3-T12; also see the `product_name` item
  below): gates, the mode-derived terminal phase, and the terminal phase's recorded
  `completed_at` are all checked before an initiative may be archived, for any initiative whose
  `schema_version >= 1`.
- **`product_name` coupling removed from `cmd_archive`'s convergence check** (EDMV3-17, wave-A
  half): for any initiative with `schema_version >= 1`, the code-audit convergence check that
  gates archival now depends only on `mode`/`lifecycle_mode` via `code_audit_required_for_mode()`
  -- it no longer additionally requires a non-empty `product_name` to fire. The pre-existing
  `product_name`-gated behavior is preserved verbatim, but only for legacy initiatives with no
  recorded `schema_version` (C-4).
- **`edm-state` skip-phase refusing an empty rationale (EDMV3-T62 AC2):**
  `skip-phase <PREFIX> <phase-num> <rationale>` now requires a non-empty third argument.
  Previously `rationale="${3:-}"` accepted an omitted or empty rationale and recorded it as an
  empty string. Every sanctioned skip must now record *why* it was skipped, so a skip with no
  rationale is refused with a non-zero exit rather than silently written. Existing state files
  that already carry a skip recorded with an empty rationale continue to be read without error
  (backward compatible, C-4) and are surfaced by `edm-state validate` as an informational
  `EMPTY_SKIP_RATIONALE` anomaly rather than being migrated or hidden.
- **`prototype` mode waives only the convergence check** (EDMV3-17): the `prototype`/
  fast-track/fix-pack exemption path (`archive_exemptions: ["CONVERGENCE_NOT_REQUIRED"]`) skips
  the code-audit convergence check specifically -- it does not waive gate approval,
  terminal-phase, or `completed_at` checks, which still apply in full.
- **State anomalies split into `info` and `blocking` classes** (EDMV3-T05): `edm-state validate`
  now emits a class token (`info` or `blocking`) on every anomaly line; an informational-only
  anomaly set exits 0, a blocking anomaly set exits 3, exactly as before.
- **Mode-derivation helpers** (EDMV3-T07): `terminal_phase_for_mode`, `required_gates_for_mode`,
  and `code_audit_required_for_mode` are the single source every mode-aware check (`gate-check`,
  `archive`, `phase-complete`) now derives from, rather than three independently hand-maintained
  mode-to-behavior mappings.
- **The convergence gate is presented via `AskUserQuestion`, not self-flipped** (EDMV3-T15).
- **Agent Write grants and output-contract tightening** (EDMV3-T02): Write access granted to the
  13-agent F3 class that needs it; the synthesizer's over-broad grant closed; blast radius
  bounded.
- **Model/effort downgrades, first tranche (D16, EDMV3-T02):** `edm-explorer` and
  `edm-test-coverage-auditor` move from `opus`/`max` to `sonnet`/`high` (scan/list work);
  `edm-architect` moves from `max` to `high` effort (writing work, model unchanged). Every other
  agent (the 11 code-audit lenses, the SRD/ticket auditors, `edm-qc-auditor`, the synthesizer)
  is unchanged pending the wave-C measured tiering matrix (EDMV3-T70/T71) -- these three are the
  only downgrades applied without that measurement, because they were assessed as safe by
  inspection (non-judgment scan/write work) rather than deferred to the matrix.
- **Sentinel-delimited `--help` output and bash 3.2/macOS CI hardening** (EDMV3-T61): help text
  in `bin/edm-state` and `bin/edm-lint-artifacts` is extracted between `EDM-HELP-BEGIN`/
  `EDM-HELP-END` sentinels rather than a hardcoded `sed -n 'A,Bp'` line range, so a new doc line
  can't silently fall outside the extracted block.
- **Every exemption leaves an audit trail** (EDMV3-T62): `archive_exemptions` and
  `degraded_checks` record every waived or degraded check (empty-rationale skips, legacy
  schema-version skips, prototype-mode convergence waivers) in state, surfaced by
  `edm-state validate` and `session-start` rather than only logged to the console.
- **Artifact lint compliance and ASCII import policy** (EDMV3-T63): `edm-lint-artifacts --all`
  now exits 0 across the whole tracked artifact tree, including this initiative's own directory;
  imported third-party documents are ASCII-normalized on import (documented in `CLAUDE.md`)
  rather than wrapped in lint-ignore markers.
- **`edm-init` branch handshake fix** (EDMV3-T01) and **README/CLAUDE.md stale install-path
  fixes plus a stated platform constraint** (EDMV3-T04, macOS/Linux only, bash 3.2+).

### Breaking Changes

- `edm-state skip-phase <PREFIX> <phase-num>` invoked with only two arguments now fails (see
  "Required user action" below). This is the only breaking change in wave A.

### Required User Action

- **Permission `ask` rules (EDMV3-08, Must Have):** add the block documented in `CLAUDE.md` /
  `README.md` ("Required setup: permission `ask` rules") to `.claude/settings.json` (or
  `.claude/settings.local.json`):
  ```json
  { "permissions": { "ask": [ "Bash(edm-state approve-gate*)", "Bash(edm-state archive*)" ] } }
  ```
  Without it, `check_permission_rules()` records `enforcement: "prose-only"` on every gate
  approval (rather than `"permission-ask"`) and an informational `PERM_RULES_MISSING` anomaly
  appears on `edm-state validate` / `session-start`. This does not block any command in wave A --
  it is a "should already be in place" recommendation with an honest enforcement tag, not a new
  hard gate.
- Any script or automation invoking `edm-state skip-phase` with only two arguments (prefix and
  phase number) must be updated to supply a third, non-empty rationale argument, or the call now
  fails.

### Backward Compatibility

All wave-A changes are backward compatible for existing state files (per EDMV3-107), with the
following explicit exceptions/notes:

- A state file with a skip already recorded under an empty rationale (pre-2.1.0) continues to be
  read without error; `edm-state validate` surfaces it as informational `EMPTY_SKIP_RATIONALE`
  rather than migrating or erroring on it.
- A legacy state file with no `schema_version` keeps the pre-2.1.0 `product_name`-gated archive
  convergence behavior verbatim (the new `mode`-derived behavior applies only to
  `schema_version >= 1` states); this is deliberate C-4 preservation, not a bug.
- No new field added in wave A is required for an existing 2.0.0-era state file to keep working;
  every new check reads a missing field as its documented default rather than failing closed.

### Downgrade Path

Wave A introduces no new authoritative on-disk shape that a 2.0.0 install would misread --
`schema_version`, `archive_exemptions`, and `degraded_checks` are additive fields a 2.0.0-era
`edm-state` simply ignores if present. There is no wave-A downgrade hazard to document; the
downgrade story that matters (2.1.0 <- 3.0.0, once the JSONL findings ledger and PARTIAL closure
representation exist) is EDMV3-T65's (wave B).

### `claude plugin validate` baseline

The v2.0.0 `claude plugin` validate baseline: 1 warning (root `CLAUDE.md` not loaded as project
context -- expected, since the plugin uses `skills/` for context per its own architectural
rules). Recorded at `.gitlab/edm-validate-baseline.txt` and unchanged in wave A, so "no new
warnings" is a measurable comparison in waves B and C.

## [2.0.0] — 2026-06-08

### Added

#### Per-epic multi-stack testing (WS-H / T106-T109)

The testing layer now detects the technology stack independently per epic, enabling initiatives that span multiple stacks (e.g., a Python backend epic and a Vue frontend epic) to produce the right test frameworks and coverage targets for each.

**Per-epic test plans** (`test-plan-{epic-slug}.md`): The `edm-test-planner` builds a per-epic stack table. When all epics share the same stack, it collapses to single `test-plan.md` (v1.x behavior preserved). For multi-stack initiatives it writes one `test-plan-{epic-slug}.md` per epic plus an index `test-plan.md`.

**Per-epic coverage reports** (`test-coverage-{epic-slug}.md`): The `edm-test-coverage-auditor` measures coverage per epic for multi-stack initiatives and writes `test-coverage-{epic-slug}.md` per epic plus a summary `test-coverage.md`. Single-stack continues to write only `test-coverage.md`.

**Absence-authoritative N/A** (T109): N/A designations are recomputed each run and never inherited. Stale `test-coverage-{slug}.md` files whose epics no longer appear in the current plan are removed on re-run. No placeholder files are written.

#### New `userConfig` keys (T129)

| Key | Default | Description |
|-----|---------|-------------|
| `mode` | `standard` | Default initiative mode (standard, mini-srd, iac, data-ml, prototype) |
| `compliance_enabled` | `false` | Enable Gate 3.5 compliance review and regulatory-traceability columns |
| `qc_shard_threshold` | `20` | Ticket count above which QC spawns multiple shards |
| `jira_mcp_namespace` | `plugin_jira_atlassian-mcp-server` | Namespace for Jira MCP tool names |
| `implementation_mode` | `standard` | Phase 6 mode: `standard` or `tdd` (Red-Green-Refactor) |

#### Product-line linkage (T125-T126)

Link related initiatives with `edm-state set-parent <PREFIX> <PARENT>` and `edm-state add-related <PREFIX> <RELATED>`. Linkage fields (`parent_prefix`, `related_prefixes`) appear in HANDOFF.md so teams can navigate across child/sibling initiatives.

#### State enhancements

- **`coverage_by_epic`** field in `.edm-state.json` holds per-epic coverage (keyed by epic slug) alongside existing `coverage_by_layer`
- **`record-test-coverage`** now accepts optional 4th `<epic>` arg: `edm-state record-test-coverage <PREFIX> <layer> <pct> [<epic>]`
- **`get-coverage`** prints both whole-initiative and per-epic sections when available
- **`metrics-report`** includes a per-epic coverage table when `coverage_by_epic` data is present
- **Auto-backup**: `.edm-state.json` is backed up to `.edm-state.json.bak` before every write

### Changed

- **`edm-test-planner`** fully rewritten for per-epic stack detection with single-stack collapse
- **`edm-test-coverage-auditor`** fully rewritten for per-epic coverage, stale-file cleanup, and absence-authoritative N/A
- **Documentation**: `CLAUDE.md` state schema section documents `coverage_by_epic`, `parent_prefix`, `related_prefixes`; `README.md` updated with multi-stack and product-line sections

---

## [1.3.0] — 2026-04-30

### Added — Comprehensive Testing Layer (`/edm:test`)

A full multi-layer test orchestration pipeline. Runs after Phase 6 implementation to build thorough, stack-aware coverage — not just "tests exist" but tests that meet configured coverage targets by layer.

#### New skills (3)

| Skill | Description |
|-------|-------------|
| `/edm:test <PREFIX>` | Full pipeline: plan → scaffold → write (parallel) → run → audit → record |
| `/edm:test-plan <PREFIX>` | Preview mode: detect stack + map ACs to layers, no writing |
| `/edm:test-coverage <PREFIX>` | Re-audit coverage against existing tests (no writing) |

#### New agents (10)

| Agent | Model | Color | Role |
|-------|-------|-------|------|
| `edm-test-planner` | opus / high | yellow | Stack detection, AC↔layer mapping, writes `test-plan.md` |
| `edm-test-scaffold` | sonnet / high | blue | Installs missing test deps + config files (asks before installing) |
| `edm-test-unit` | sonnet / high | green | Pure-function unit tests, mocked at boundaries |
| `edm-test-component` | sonnet / high | green | UI component tests (RTL, Vue Test Utils, Svelte, Angular) |
| `edm-test-composable` | sonnet / high | green | React hooks and Vue composables via renderHook / wrapper |
| `edm-test-integration` | sonnet / high | green | Multi-module tests with real DB or HTTP |
| `edm-test-contract` | sonnet / high | green | API contract tests driven by OpenAPI/GraphQL schema |
| `edm-test-e2e` | sonnet / high | green | Playwright/Cypress critical path journeys, page-object pattern |
| `edm-test-a11y` | sonnet / high | green | axe-core scans + keyboard nav, WCAG 2.1 AA |
| `edm-test-coverage-auditor` | opus / max | cyan | Read-only: coverage parse + AC↔test cross-reference + gap findings |

#### New project artifacts

| File | Written by |
|------|-----------|
| `SRD/{PREFIX}/test-plan.md` | `edm-test-planner` |
| `SRD/{PREFIX}/test-coverage.md` | `edm-test-coverage-auditor` |

#### State schema additions

- `test_frameworks_detected: {}` — auto-detected framework per layer; written by `edm-test-planner`.
- `coverage_by_layer: {}` — `{pct, measured_at}` per layer; written by `edm-state record-test-coverage`.
- `phase_durations[N_phase].tests_added` and `.tests_by_layer` — written by `edm-state record-tests-added`.

#### New `userConfig` keys (7)

Coverage targets (defaults match typical project standards): `coverage_target_unit_pct` (80), `coverage_target_component_pct` (70), `coverage_target_integration_pct` (60), `coverage_target_e2e_critical_paths_pct` (100). Framework override strings: `test_framework_unit_override`, `test_framework_component_override`, `test_framework_e2e_override` — pin a framework when auto-detection is ambiguous.

#### New `bin/edm-state` subcommands (3)

`record-test-coverage <PREFIX> <layer> <pct>`, `record-tests-added <PREFIX> <phase> <layer> <count>`, `get-coverage <PREFIX>`.

`metrics-report <PREFIX>` now includes a test coverage table when data is available.

#### Existing files updated

- `agents/edm-implementer.md` — clarified role: write basic smoke tests per ticket; comprehensive coverage comes from `/edm:test` afterward.
- `agents/edm-audit-test-quality.md` — added reference to `/edm:test` as the fix path for L4 findings.
- `skills/implement/SKILL.md` — Step 6 now recommends `/edm:test` before declaring Phase 6 done.
- `skills/orchestrator/SKILL.md` — Step 7b now suggests `/edm:test` between QC pass and final declaration; artifact layout updated to include test artifacts.

### Why

EDM's six-phase process produces well-specified code — but specification alone doesn't guarantee test coverage. Teams using Phase 6 implementers ended up with whatever smoke tests the implementer threw in alongside the code: often shallow, often missing error paths, almost never integration or E2E. The testing layer fills that gap with a structured, parallel, stack-aware pipeline. The `test-plan.md` and `test-coverage.md` artifacts make coverage intent and actuals visible in PRs alongside every other EDM artifact.

---

## [1.2.0] — 2026-05-01

### Changed — Writers upgraded to Opus
- `edm-srd-writer` and `edm-ticket-writer` agents (and their parent skills `skills/srd/`, `skills/tickets/`) now run on `model: opus, effort: high` (was `sonnet, high`). High-stakes artifacts the rest of the methodology depends on benefit from Opus's stronger judgment, even at writing-throughput effort. Audits and QC remain on `opus, max`.

### Added — `/edm:push-jira` (optional Jira synchronization)
- New skill `skills/push-jira/SKILL.md`. Pushes the ticket pack to a Jira project via the Atlassian MCP server.
- Idempotent — re-runs update existing issues instead of creating duplicates. Tracks EDM tickets in Jira via labels (`edm-{prefix}-t{nn}`); no Jira custom fields required.
- Preserves Jira-side state (status, comments, worklog) across re-runs.
- Dependencies become Issue Links of type `Blocks` (or `Relates`).
- Writes Jira keys back into the source ticket pack: `## AUTH-T01: …  ([MCP-1234](https://….atlassian.net/browse/MCP-1234))`.
- Writes a sync summary to `${ticket_pack_dirname}/jira-sync.md`.
- Tracks `jira_synced_at` and `jira_project_key` in `.edm-state.json`.
- Skips gracefully with a friendly message if the Atlassian MCP isn't connected — strictly opt-in.
- New userConfig key `jira_project_key` (optional, no default).

### Fixed — Pricing constants updated to current Anthropic rates (verified May 2026)
Per [docs.anthropic.com/en/docs/about-claude/pricing](https://docs.anthropic.com/en/docs/about-claude/pricing):

| Model | Input | Output | Cache Read | Cache Write 5m | Cache Write 1h |
|---|---|---|---|---|---|
| Opus 4.7 | $5 (was $15) | $25 (was $75) | $0.50 (was $1.50) | $6.25 (was $18.75) | $10.00 (NEW) |
| Sonnet 4.6 | $3 | $15 | $0.30 | $3.75 | $6.00 (NEW) |
| Haiku 4.5 | $1 (was $0.80) | $5 (was $4) | $0.10 (was $0.08) | $1.25 (was $1) | $2.00 (NEW) |

Cache writes are now tracked separately by TTL (5-minute vs 1-hour) because they have different rates. Token reading parses `cache_creation.ephemeral_5m_input_tokens` and `cache_creation.ephemeral_1h_input_tokens` from session JSONLs.

New env var overrides: `EDM_OPUS_CACHE_WRITE_5M_RATE`, `EDM_OPUS_CACHE_WRITE_1H_RATE`, etc. (likewise for Sonnet and Haiku).

State schema's `tokens` field changes from `{input, output, cache_read, cache_write}` to `{input, output, cache_read, cache_write_5m, cache_write_1h}`.

### Why
Pricing accuracy: prior cost numbers in v1.1.0 reports were ~3× too high for Opus phases due to outdated rate constants, undermining the credibility of the human-baseline savings ratio. Now corrected.

Writers upgraded: surveying real EDM runs, the most common quality issue at HITL Gate 2 was vague or incomplete acceptance criteria from sonnet-written tickets. Opus catches more.

Jira: requested by teams that need EDM artifacts visible alongside their existing sprint planning workflow.

---

## [1.1.0] — 2026-05-01

### Added — Cost tracking per phase
- `bin/edm-state` reads token usage from Claude Code's session JSONL files (`~/.claude/projects/<encoded-cwd>/*.jsonl`) and computes per-phase Claude API cost from token counts × Anthropic pricing.
- `phase-complete` now records: `tokens.{input,output,cache_read,cache_write}`, `model_used`, `estimated_cost_usd`, and `human_baseline_usd`.
- `metrics-report <PREFIX>` shows: Phase | Duration | Claude Cost | Human Cost | Savings (ratio) | Tokens | Model. Total row reports overall savings vs. human baseline (e.g., "42× cheaper").
- `metrics-report --all` aggregates costs across all initiatives.
- `metrics-report --calibrate` now includes median cost per (size, phase) alongside median duration.
- New userConfig key `human_hourly_rate_usd` (default $150) drives the human-baseline computation.
- Pricing is overridable via env vars: `EDM_OPUS_INPUT_RATE`, `EDM_SONNET_OUTPUT_RATE`, `EDM_HAIKU_CACHE_READ_RATE`, etc.
- Path-encoding fix: `~/.claude/projects/<cwd>` encodes both `/` and `.` as `-`.

### Why
EDM's value proposition rests on the cost-of-rework argument. Now teams can prove it numerically: "this initiative cost the team $X in Claude API; the same work would have cost $Y in human time at our $/hr rate." Stakeholder conversations get easier when the savings ratio is in the report.

---

## [1.0.0] — 2026-04-30

Initial release. Implements the EDM Plugin Remediation Plan.

### Added — Architecture
- Single-source-of-truth model: skills/ is the only entry point; no commands/ directory.
- Project-resident artifacts: every output lives in `SRD/{PREFIX}/` and is committed to git.
- Initiative state file at `SRD/{PREFIX}/.edm-state.json` (committed by default; configurable).

### Added — Skills (8 phase skills + 1 reporting skill)
- `/edm:orchestrator` — full 6-phase methodology with HITL gates
- `/edm:plan` — Phase 1 Planning & Discovery
- `/edm:srd` — Phase 2 SRD Creation
- `/edm:audit-srd` — Phase 3 SRD Audit (7 categories)
- `/edm:tickets` — Phase 4 Ticket Pack Creation (with version-linkage header)
- `/edm:audit-tickets` — Phase 5 Ticket Pack Audit (8 dimensions including version alignment)
- `/edm:implement` — Phase 6 Implementation + automatic QC + remediation
- `/edm:code-audit` — Post-Phase 6 11-lens exhaustive audit
- `/edm:metrics` — per-phase duration reporting and calibration

All phase skills carry `disable-model-invocation: true`. Planning, audit, and QC skills run on `model: opus, effort: max`.

### Added — Agents (20 total)
- Phase agents: `edm-explorer`, `edm-architect` (with Write tool), `edm-srd-writer`, `edm-srd-auditor`, `edm-ticket-writer`, `edm-ticket-auditor`, `edm-implementer` (with `isolation: worktree`), `edm-qc-auditor`.
- 11 code-audit lens agents (`edm-audit-logic`, `…-dead-code`, `…-edge-cases`, `…-test-quality`, `…-runtime`, `…-docs`, `…-consistency`, `…-security`, `…-spec`, `…-dry`, `…-wiring`) plus `edm-audit-synthesizer` for plan aggregation.
- All read-only audit agents have `disallowedTools: Write, Edit, NotebookEdit`.
- `maxTurns` set on every agent. Semantic color scheme applied.

### Added — Hooks (`hooks/hooks.json`)
- `SessionStart` — prints in-progress initiatives via `edm-state list`.
- `UserPromptExpansion` (matcher: `edm:(srd|tickets|implement)`) — blocks expansion if the prerequisite HITL gate isn't approved.
- `Stop` and `PreCompact` — opportunistically checkpoint state.
- `SubagentStop` (matcher: `edm-implementer`) — auto-spawns `edm-qc-auditor` after every implementer completes.
- `TaskCompleted` — reserved; wires to `record-task-duration` but per-task duration accumulation is not yet implemented.

### Added — Helper scripts (`bin/`)
- `edm-state` — read/write `SRD/{PREFIX}/.edm-state.json` with subcommands: `get`, `set`, `init`, `list`, `approve-gate`, `phase-start`, `phase-complete`, `checkpoint-if-active`, `record-task-duration`, `archive`, `watch-impl`, `metrics-report`.
- `edm-init` — scaffold a new initiative directory.
- `edm-validate-prefix` — verify prefix uniqueness and format.

### Added — Background monitor (`monitors/monitors.json`)
- `edm-impl-progress` — during `/edm:implement`, tails git log for ticket commits and emits notifications.

### Added — Configuration (`plugin.json` `userConfig`)
- `srd_root` (directory, default `./SRD`)
- `srd_filename` (string, default `srd.md`)
- `ticket_pack_dirname` (string, default `tickets`)
- `prefix_format_hint` (string, default `UPPERCASE 3-6 chars (AUTH, MIGR, TIPS)`)
- `commit_state_file` (boolean, default `true`)

### Added — Documentation
- `README.md` — user-facing install and usage
- `CLAUDE.md` — contributor conventions (architectural rules, layout, naming, colors, models, hooks, bin scripts, userConfig)
- `CHANGELOG.md` — this file

### Conventions
- Initiative prefix: 3–6 uppercase chars (e.g., `AUTH`, `MIGR`).
- SRD requirement IDs: `{PREFIX}-NN` (e.g., `AUTH-01`).
- Ticket IDs: `{PREFIX}-T{NN}` (e.g., `AUTH-T01`) — never the legacy `TICK-NN`.
- Version linkage: ticket pack `README.md` body's first line is `Generated From: srd.md v{srd_version}`.

### Known limitations
- Multi-developer concurrent edits to `.edm-state.json` are not file-locked (intentional — gate approvals are sequenced by HITL anyway).
- Existing `/SRD/` initiatives in this repository (TIPS, deep-chat-gui, microsoft_graph_mcp, etc.) use older naming conventions; the plugin does not migrate them. New initiatives use the cleaner directory-per-initiative layout.
- `edm-implementer` is generic with stack detection; language-specialized variants (Python, Go, TypeScript, etc.) are deferred to a future release.
