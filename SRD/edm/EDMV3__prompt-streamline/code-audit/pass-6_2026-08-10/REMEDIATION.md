# Code Audit Remediation Plan: EDMV3 -- prompt-streamline (Round 6)

## Context

- **Audit date**: 2026-08-10 (`pass-6_2026-08-10`)
- **Round type**: **full** -- all 11 lenses ran (L1-L11, per `lenses-run.txt`). Satisfies the
  round-type half of the convergence gate.
- **Audited scope**: `plugins/edm/**` (bin/, bin/tests/, hooks/, evals/, monitors/, docs/,
  skills/, agents/, CLAUDE.md, README.md, CHANGELOG.md), the edm-scoped jobs of the
  repository-root `.gitlab-ci.yml`, the root `.gitignore`, and -- for L9 -- `srd.md`,
  `tickets/README.md`, all 11 `tickets/epics/*.md` and `decisions.md` D1-D48.
- **Branch / commit**: `edm/edmv3-prompt-streamline` @ `4022300`
- **SRD**: `/Users/darryl.porter/projects/marketplace/SRD/edm/EDMV3__prompt-streamline/srd.md`
- **Ticket pack**: `/Users/darryl.porter/projects/marketplace/SRD/edm/EDMV3__prompt-streamline/tickets/`
- **Ledger**: `/Users/darryl.porter/projects/marketplace/SRD/edm/EDMV3__prompt-streamline/code-audit/findings-ledger.jsonl`
  (authoritative; the `.md` render carries a Round 6 addendum pending re-render -- see G43/CA-378)
- **Deployment target**: local / plugin distribution (marketplace repo), with GitLab CI as the
  blocking gate on every MR touching `plugins/edm/**`

### Round-6 outcome at a glance

| | P0 | P1 | P2 | NOTED |
|---|----|----|----|-------|
| **Open after round 6** | **0** | **7** | **41** | -- |
| New this round | 0 | 6 | 36 | 4 |
| Carried open, re-scoped | 0 | 1 (CA-320, escalated P2 -> P1) | 5 | -- |

**45 findings fixed this round. 0 deferred. Convergence NOT reached.**

### Read this before trusting any closure in this round

CA-130 reproduced for a **seventh consecutive round**, and for the first time in a shape that
degraded every lens at once: **no lens was delivered `Bash`**, and eight of eleven were delivered
no `Write` either, so eight reports were transcribed by the orchestrator from chat text and
**not one lens executed the suite**. The 1996-assertion / 0-failed figure quoted this round is
**orchestrator-supplied and unverified by any lens**.

Named unaudited surfaces (report these as unaudited, not clean): L3 did not reach `cmd_archive`,
`cmd_git_lock_check`/`_git_lock_age_seconds`, `cmd_phase_start`/`_complete`/`approve_gate`/`init`,
CI job timeouts, the three `evals/*.sh` drivers, or `bin/tests/**`. L2 covered the seven smoke
suites, `_harness.sh`, `run-all.sh`, `score-artifacts.sh`, `tiering-matrix.sh` and
`edm-mermaid-rules.awk` by **targeted grep only** and flagged `bin/tests/` as the surface it could
least cover. L10 did not read `edm-state:3600-5193`, `wave6/wave7-smoke.sh`, `_harness.sh`,
`run-all.sh`, `evals/*.sh` or `.gitlab-ci.yml` closely. L7 did not exhaustively diff the suites
beyond their header/`SCRIPT_DIR`/`set` lines. L9 evaluated every `Verify:` clause **statically**.

Full record: **CA-377**. Standing recommendation (**CA-331**) is now a **precondition** for the
next convergence gate, not a nicety: a Bash-capable pass must run `bin/tests/run-all.sh` and
report the executed result.

---

## Findings Summary

### P1 -- fix before shipping (7)

| # | Sev | Lens(es) | Ledger ID | Component | Issue |
|---|-----|----------|-----------|-----------|-------|
| G1 | P1 | L8 | CA-320 | `plugins/edm/hooks/hooks.json:86` | **Escalated P2 -> P1.** CA-320's fix repointed 2 of 4 resolution bases; the two consumers still resolve `srd_root` against the hook's cwd, so a commit from a subdirectory silently drops all commit-time enforcement -- and the fix removed the only diagnostic |
| G2 | P1 | L2 | CA-333 | `plugins/edm/bin/edm-state:2148`, `:2697` | CA-182's class at two unswept siblings: both wave-B `schema_version >= 2` refusals are environmentally unreachable at the version every initiative carries, so CLAUDE.md's D15 archive hard-block is false in the shipped default |
| G3 | P1 | L9 | CA-334 | `.../epics/06-mermaid-rule.md:340`, `:385` | T43 AC1 and AC8 both assert a pre-extraction tree, broken by **this session's own commit `2d83898`** |
| G4 | P1 | L1 | CA-335 | `plugins/edm/bin/edm-state:5037` | HANDOFF.md's headline gate count has a hardcoded denominator and an un-deduped numerator: `1 of 3` on prototype, `4 of 3` via a documented workflow |
| G5 | P1 | L6 | CA-336 | `plugins/edm/CHANGELOG.md:41-43`, `:290` | CA-302's re-measurement left three siblings in the same file asserting the superseded figures, so the record states both numbers at once |
| G6 | P1 | L6 | CA-337 | `plugins/edm/bin/tests/wave7-smoke.sh:5586-5590` | Introduced by CA-256's own fix: three false claims about the marker derivation, so the adjacent `git check-ignore` assertion reads as covering today's marker when it covers only the legacy one |
| G7 | P1 | L9 | CA-338 | `.../epics/11-cross-cutting-delivery.md:860-864` | CA-319's AC half never landed: T67 AC11 still exempts exactly the two jobs that reach the network, one of which holds the API key |

### P2 -- fix before shipping; defer only with rationale (41)

| # | Sev | Lens(es) | Ledger ID | Component | Issue |
|---|-----|----------|-----------|-----------|-------|
| G8 | P2 | L4 | CA-346 | `wave7-smoke.sh:6137-6190` | **Highest-priority P2.** No executed happy-path case for the five gate hooks: a stray trailing `exit 2` locks the user out of five gated commands permanently and passes both existing cases |
| G9 | P2 | L3+L11 | CA-339 | `edm-state:3338`, `:3392-3397`, `hooks.json:23,36,49,62,75` | `gate-check`'s read-only contract contradicted in 8 places; the write is intended, the claims are the defect |
| G10 | P2 | L1+L6 | CA-340 | `edm-init:163-164`, `wave7-smoke.sh:3777` | Stale-citation class recurred at two new sites introduced by round 5's own fixes; the CA-315 guard's five-site scoping left it live |
| G11 | P2 | L3+L5 | CA-341 | `edm-state:1083-1087`, `edm-init:169-174`, `README.md:208-229` | CA-169's never-unlink justification holds only for `edm-init`-created initiatives; `edm-state init` and `rmw_state` bypass it |
| G12 | P2 | L3 | CA-345 | `edm-state:1625` | CA-298's residual: a non-refusal non-zero path (breadcrumb lock timeout; missing `jq`) still hard-blocks prompt expansion |
| G13 | P2 | L8 | CA-347 | `edm-state:1120-1129` | Introduced by CA-305's own fix: the unconditional marker probe reports a successful, committed mutation as a lock timeout |
| G14 | P2 | L3 | CA-352 | `edm-state:236-243` | `state_file_for` guesses on a duplicated PREFIX and every automated consumer discards the warning |
| G15 | P2 | L3 | CA-353 | `edm-state:5023-5028` | `2>&1` publishes `audit-converged`'s error diagnostics into HANDOFF.md as the open-findings section |
| G16 | P2 | L3 | CA-355 | `edm-state:4622-4630` | `update-patterns` reports a refusal as a clean zero and persists it, losing N findings permanently |
| G17 | P2 | L3 | CA-354 | `edm-state:3812-3865` | `render-ledger`'s render and hash-record run under no single lock -> phantom checkpoint drift warnings |
| G18 | P2 | synth | CA-378 | `edm-state:3829-3853` | `cmd_render_ledger` does not escape `\|` in titles, so a pipe-bearing finding silently shifts every later column in a committed, hash-recorded artifact |
| G19 | P2 | L1 | CA-360 | `evals/score-artifacts.sh:498` | Introduced by CA-088's own fix: division by zero laundered into a real D5 score of 0 |
| G20 | P2 | L8 | CA-348 | `evals/run-eval.sh:266` | Sole bare `mktemp -d` in bin/+evals/ does not honour TMPDIR; macOS resolves `_CS_DARWIN_USER_TEMP_DIR` first |
| G21 | P2 | L2 | CA-359 | `edm-compare-eval:133-135` | The reachable regression path instructs the operator to undo the initiative |
| G22 | P2 | L2 | CA-362 | `evals/run-eval.sh:616-624` | Four dead `''` case arms preempted by `${x:-0}` -- CA-140/CA-202/CA-260 class at four more sites |
| G23 | P2 | L10 | CA-343 | `edm-state:2371`, `:3398`, `:2432` | Three duplications each carrying a **false single-source claim** |
| G24 | P2 | L10 | CA-344 | `edm-init:53`, `edm-check-grants:256/:501`, `:360/:370`, `edm-lint-artifacts:414/:438/:486`, `edm-validate-prefix:58/:80` | Five mechanical duplications, no divergence, no false claim |
| G25 | P2 | L6 | CA-342 | `CLAUDE.md:843-854`, `_edm-lint-lib.sh:51-54` | Two self-describing counts wrong by exactly one; three lenses read one of them three different ways |
| G26 | P2 | L4 | CA-350 | `wave7-smoke.sh:4206` | T49 AC6's four D1 tripwires are case-blind (`grep -rni` producer, case-sensitive needle) |
| G27 | P2 | L4 | CA-361 | `wave7-smoke.sh:7362`, `:7370` | Two bare `grep -c` captures in this session's G51 block crash the suite instead of failing one assertion |
| G28 | P2 | L5 | CA-351 | `wave7-smoke.sh:7034`, `:7066`, `:5345-5349` | CA-264's class at two new G47 sites, plus the now-false "only bare `$HOME`" claim |
| G29 | P2 | L11 | CA-356 | `edm-state:1677` | `qc_shard_threshold`: settable, typed, tested, read by nothing |
| G30 | P2 | L11 | CA-357 | `edm-state:4389`, `:4398` | `set-supersedes`/`set-forked-from`: zero callers and no user-facing documentation |
| G31 | P2 | L11 | CA-358 | `hooks.json:23,36,49,62,75` | The invalid-prefix arm did not travel with CA-279's delegation rewrite |
| G32 | P2 | L7 | CA-363 | `hooks.json:8` | `SessionStart` uniquely silences the hook whose diagnostics matter most; corroborated by G14 |
| G33 | P2 | L7 | CA-364 | `edm-state:1124`, `:1028` | The two lock-timeout `die` messages quote different units |
| G34 | P2 | L7 | CA-365 | `edm-state:5186` | Sole `print_help "$0"` against eleven `${BASH_SOURCE[0]:-$0}` siblings |
| G35 | P2 | L6 | CA-366 | `wave7-smoke.sh:7364` | This session's G51 pass label hardcodes a class count CLAUDE.md refuses to state |
| G36 | P2 | L11 | CA-367 | `edm-state:6`, `:120` | Both EDM-HELP comments still name the dropped `lint` subcommand |
| G37 | P2 | L3 | CA-373 | `edm-state:4966` | HANDOFF Notes normalization is not a fixed point for a hand-edited file |
| G38 | P2 | L5 | CA-372 | `bin/tests/fixtures/code-audit/README.md:49` | The one bare-`/tmp` runtime-write instruction in the plugin |
| G39 | P2 | L8 | CA-349 | `.gitlab-ci.yml:603`, `wave7-smoke.sh:4511-4517` | CA-319's pin-enforcing assertion accepts `@latest` |
| G40 | P2 | L9 | CA-368 | `.../epics/02-enforcement-kernel.md:314`, `:328-329` | Two citation defects authored by this session's own D43 |
| G41 | P2 | L9 | CA-369 | `.../epics/03-ci-and-fixture-eval.md:264` | T21 AC5's "single invocation" against two invocations |
| G42 | P2 | L9 | CA-370 | `.../epics/11-cross-cutting-delivery.md:466-467` | CA-323's relabel left a second unverifiable "green in CI" clause |
| G43 | P2 | L9 | CA-371 | `.../epics/11-cross-cutting-delivery.md:660-674` | T66 AC3 prints the hardcoded literal its own text says it avoids |
| G44 | P2 | L7 | CA-317 | `.gitlab-ci.yml` (4 sites) | **4th round.** Four job-name/`FAILED` holes remain; the durability assertion landed as a hand-enumerated list |
| G45 | P2 | L7 | CA-318 | `edm-state:1185-1193` vs `:3587-3602` | Fixed on the happy path only: the two reclaimers take opposite directions on undetermined age, while both comments claim otherwise |
| G46 | P2 | L4 | CA-311 | `bin/tests/timing.sh:96-173` | The five assertions landed and **nothing runs them** -- `--self-test` has no invoker |
| G47 | P2 | L4 | CA-312 | `wave6-smoke.sh:205-207` | Sibling missed by CA-312's sweep: still proves presence where the contract is exclusivity |
| G48 | P2 | L7 | CA-233 | `wave7-smoke.sh:948-950` | In-suite twin still excludes only `awk`, not `txt`; cross-loop consistency assertion still absent |

---

## Detailed Findings

### G1 (P1, lens L8): CA-320's remediation is incomplete -- commit-time enforcement still fails open

**Problem.** Round 5's CA-320 fix correctly repointed **two** of the PreToolUse hook's four
`srd_root` resolution bases at the repository root: the existence guard
(`check_dir="${repo_root:-.}/${srd_root}"` with `repo_root=$(git rev-parse --show-toplevel)`) and
the staged-path matcher (`root="$root_for_awk" awk ...` over `git diff --cached --name-only`). It
did **not** repoint the two **consumers** at the end of the same hook body, both of which still
resolve `srd_root` against the hook's own cwd:

- `bin/edm-state:65` -- `SRD_ROOT="${EDM_SRD_ROOT:-${CLAUDE_PLUGIN_OPTION_SRD_ROOT:-./SRD}}"`,
  consumed by `state_file_for:223` as a cwd-relative path
- `bin/edm-lint-artifacts:64` -- byte-identical derivation

Confirmed by inspection: `EDM_SRD_ROOT` occurs **exactly once** in `hooks/hooks.json` -- in the
hook's own derivation, and at **neither** child call site.

Failure path, with no attacker and no user error (a commit made with the hook's cwd anywhere other
than the repo root -- the exact premise CA-320 itself established):

1. `check_dir="$repo_root/SRD"` exists -> guard passes.
2. Staged path `SRD/edm/EDMV3__prompt-streamline/srd.md` is repo-root-relative -> awk extracts
   `EDMV3` -> charset filter passes -> `prefixes="EDMV3"`.
3. `edm-state resolve-dir EDMV3` runs with `SRD_ROOT="./SRD"` relative to the **subdirectory**;
   `state_file_for` returns `./SRD/EDMV3/.edm-state.json`; `cmd_resolve_dir` (`:4416`) finds no
   file and dies.
4. `|| continue` skips the prefix. Every prefix skips identically. `fail` stays 0. Hook `exit 0`.

Net: **all commit-time artifact enforcement silently drops, and the pre-CA-320 misleading-typo
diagnostic that at least signalled *something* is gone.** The `edm-lint-artifacts` call on the
next line is unreachable in this configuration, so an attribution trailer, a non-ASCII byte or a
raw Mermaid semicolon commits clean. The same mismatch also makes the **guard itself** wrong when
the Claude Code project directory is a *subdirectory* of the git root (monorepo sub-project),
because `$repo_root/SRD` is then not where the SRD tree lives.

Second sub-defect, merged here because one edit closes both (L8-6-02): the matcher assumes
`git diff --cached --name-only` emits repo-root-relative paths. That is git's default but is
configurable -- `diff.relative = true` makes `git diff` print paths relative to the cwd **and
exclude staged paths outside it entirely**. A developer with that common preference committing
from a subdirectory gets an empty `prefixes`, `test -z "$prefixes" && exit 0` fires, enforcement
drops with no diagnostic.

**Fix.**

1. Make all four bases agree on one absolute value, once. After `check_dir` is computed and the
   `-d` test passes, pass it down explicitly rather than letting the children re-derive:
   - `EDM_SRD_ROOT="$check_dir" edm-state resolve-dir "$p"`
   - `out=$(EDM_SRD_ROOT="$check_dir" edm-lint-artifacts "$p" 2>&1)`

   Both honour `EDM_SRD_ROOT` (`edm-state:65`, `edm-lint-artifacts:64`) and both accept an
   absolute value unchanged. (`cd "$repo_root" || exit 0` immediately after `repo_root` is
   captured is equivalent and also fixes the matcher's base as a side effect -- prefer the
   explicit-env form so the fix is visible at the two call sites it protects.)
2. Pin the diff base: `staged=$(git -c diff.relative=false diff --cached --name-only 2>/dev/null)`.
   Keep this even with the `cd` variant -- `cd` alone does not defeat `diff.relative`. (`-c` has
   no version floor; `--no-relative` needs git >= 2.28.)
3. Add a smoke case that **executes** the hook body -- not a static grep -- from a subdirectory of
   a scratch repo with a real violation staged, asserting exit 2. Current coverage is static only
   (`wave7-smoke.sh:3370` plus the stub-based case at `:6176`) and is structurally incapable of
   observing a resolution-base mismatch: the same blind spot CA-298's fix note called out for the
   sibling hook family.

**Verification.** From a scratch repo: `mkdir -p sub && cd sub`, stage a file under `SRD/` with a
git commit co-author trailer, run the hook body, assert exit 2 and a named diagnostic. Repeat with
`git -c diff.relative=true`. Then re-run the same case from the repo root and assert exit 2 there
too (no regression on the working path).

**Files affected.** `plugins/edm/hooks/hooks.json`, `plugins/edm/bin/tests/wave7-smoke.sh`.

**Severity note.** P1 rather than P0 because the blocking `lint:artifacts` CI job
(`edm-lint-artifacts --all`) still catches the same violation classes at merge-request time, so
the failure mode is a **lost fast local gate**, not an unguarded merge path. If that job were
`allow_failure` this would be P0.

---

### G2 (P1, lens L2): two wave-B enforcement arms are unreachable at the schema version every initiative carries

**Problem.** `cmd_phase_complete`'s phase-6 open-PARTIAL refusal (`edm-state:2148`, consequences
`:2149-2154`) and `cmd_archive`'s AC1e PARTIAL-closure refusal plus AC1f `audit-converged`
re-query (`:2697`, consequences `:2708-2720`, `:2728-2739`) are all gated on
`schema_at_least ... 2`.

- `_cmd_init_render:1755` writes the literal `schema_version: 1` (**verified**).
- `cmd_migrate_schema` is the only writer that can reach 2, and it is reachable from **no runtime
  surface** -- `migrate-schema` appears only in `bin/edm-state`, two smoke suites, `CLAUDE.md` and
  `CHANGELOG.md`. **No skill, no agent, no hook mentions it.**
- `_write_handoff_body:4782` renders the "run `edm-state migrate-schema`" prompt only when
  `schema_version` is **absent**, so a `schema_version: 1` initiative is never even told to
  migrate.

So for every initiative the current plugin creates, both refusals never execute and only the
`warn` + `record_degraded_check` arms fire.

This is **not** the documented three-valued model. The in-code comment at `:2142-2146` frames it
as EDMV3-T14 AC6's intentional middle class -- and that is the framing **CA-182 was raised P0 and
fixed in round 4 for**, on the byte-identical construction one function away, with the identical
ledger wording ("for every initiative created by the current plugin version the precheck is
environmentally unreachable"). CA-182's fix made its precheck unconditional and degraded only its
exit-3 arm; the same remediation was not applied here, so False Alarm Filter criterion 2 does not
save these sites -- the comment asserting correctness is the comment CA-182 invalidated.

**Live consequence.** `CLAUDE.md`'s D15 section states: *"Archive stays hard-blocked until every
AC in `partial_verdict_map` carries a `closing_verdict` of PASS or FAIL."* That sentence is
**false in the shipped default configuration** -- `edm-state archive` proceeds with unclosed or
FAIL-closed PARTIAL verdicts. CA-316 swept the *approve-gate* half of this documentation class
(`CLAUDE.md:847`); the D15 half is unswept.

**Fix.** Mirror CA-182's own prescription at both sites: run each check **unconditionally** and
degrade only on the genuinely-absent shape (`partial_verdict_map` empty / no
`findings-ledger.jsonl`), never on the version number. Then leave D15 as written -- making the
checks unconditional is what makes the sentence true. Fold in the same-mechanism secondary site:
`cmd_audit_converged:4106-4111`'s `unknown` round_type refusal is likewise unreachable at
`schema_version: 1` (the `partial` refusal at `:4112-4114` is correctly ungated and does fire).

**Verification.** Add a `wave6-smoke.sh` case at `schema_version: 1` with one open PARTIAL and
assert that **both** `archive` and `phase-complete 6` exit non-zero. The coverage gap that let
this survive four rounds is that no assertion exercises either check at the version every
initiative actually carries. Then re-run `edm-state validate` and confirm the `OPEN_PARTIALS`
anomaly (deliberately not schema-gated, `:1500-1502`) still fires -- it is the compensating
control that holds this at P1 rather than P0, and it must not regress.

**Files affected.** `plugins/edm/bin/edm-state`, `plugins/edm/bin/tests/wave6-smoke.sh`, and
`plugins/edm/CLAUDE.md` only if option (a) is chosen instead.

**Confidence note.** This was one of two findings under verification when the round was
interrupted. The mechanism is confirmed directly: `schema_version: 1` at `edm-state:1755`, plus
in-code acknowledgements at `:1951` ("`_cmd_init_render` still writes the literal
`schema_version: 1` and nothing auto-migrates") and `:2578`. The specific line numbers `:2148` and
`:2697` come from L2's read and were not independently re-confirmed; if they have shifted, locate
the two arms by the `schema_at_least`-gated PARTIAL refusals rather than by line.

---

### G3 (P1, lens L9): T43 AC1 and AC8 both assert a pre-extraction tree

**Problem.** Both Must-Have criteria under EDMV3-56 were broken by **this session's own commit
`2d83898`** ("finish the shared-lint-library extraction"), which landed the code half and swept no
AC. One commit closes both.

1. **T43 AC1** (`epics/06:340-345`): the verify asserts `build_line_classes` has one definition
   **and** one call in `plugins/edm/bin/edm-lint-artifacts`. There is **no definition in that
   file** -- it lives at `bin/_edm-lint-lib.sh:89`. `edm-lint-artifacts` holds seven occurrences:
   six comments (`:81`, `:176`, `:184`, `:263`, `:284`, `:297`) and one real call (`:293`). The
   AC's *substance* (one pass, computed once per file, shared by all classes) still holds; the
   stated tree fact does not.
2. **T43 AC8** (`epics/06:385-390`): the verify asserts `sed -n '7,11p'
   plugins/edm/bin/edm-lint-artifacts` names **four** classes. Lines 7-11 today are the
   CA-005/CA-154 sentinel-convention comment, `# EDM-HELP-BEGIN`, and the one-line tool
   description -- **zero** class names; the enumeration is at `:24-39` and names **seven**. Two
   independent defects in one verify: (a) it is the last surviving ticket-pack site of the "four
   violation classes" staleness family that CA-254/CA-299/D41/D42 swept out of `CLAUDE.md`, the
   ticket pack and `srd.md`; (b) it verifies content by a **hardcoded line range**, the exact
   idiom this initiative deleted from that very file under EDMV3-96/T61 AC1 -- which the AC's own
   body acknowledges.

**Fix.**

- AC1 verify -> `grep -c '^build_line_classes()' plugins/edm/bin/_edm-lint-lib.sh` returns 1, and
  `grep -c 'build_line_classes ' plugins/edm/bin/edm-lint-artifacts` counts the single real call
  at `:293` (use the invocation shape, not the bare name -- the CA-322/CA-325 lesson).
- AC8 verify -> extract the class block by its **sentinels**, not by a line range, and assert the
  **seven** `#   <class>` rows at `edm-lint-artifacts:25-39` by name.
- Record both amendments in `decisions.md` with before/after text per `tickets/README.md:64-65`.

**Verification.** Run both re-expressed verify commands and confirm the stated results. Then
`grep -rn 'four violation classes' SRD/ plugins/edm/` and confirm the only survivors are the two
deliberate `wave7-smoke.sh` regression labels (the G51 pass label is G35/CA-366).

**Files affected.** `SRD/edm/EDMV3__prompt-streamline/tickets/epics/06-mermaid-rule.md`,
`SRD/edm/EDMV3__prompt-streamline/decisions.md`.

**Durability half (load-bearing -- fourth consecutive round of this root cause).** Any remediation
that moves a symbol between files, or that a ledger entry prescribes an AC edit for, must grep the
ticket pack and `srd.md` for the symbol name **before the commit is made**, and the prescribed AC
edit must land in the **same commit** as the code edit.

---

### G4 (P1, lens L1): HANDOFF.md's headline gate count is wrong in both halves

**Problem.** `edm-state:5037`:

```bash
printf '%s\n' "- **Gates approved**: ${gates_count} of 3"
```

*Wrong denominator.* The `3` is hardcoded. `required_gates_for_mode()` (`:811`) is the single
source for which gates a lifecycle requires, and `_write_handoff_body` already reads `mode`,
`lifecycle_mode` and `skipped_phases` at `:4770-4797` -- it just never uses them for the count.
For `mode=prototype`, `terminal_phase_for_mode` returns 2 and the default skip set covers phases
3-6, so exactly **one** gate is required: the artifact renders `1 of 3`, telling a teammate two
gates are outstanding on an initiative that has none. `mini-srd` (merged Gate 2+3, phases 4/5
skipped) and `fast-track`/`fix-pack` (phases 1/2/3/5 skipped) are wrong the same way. This is the
class `CLAUDE.md`'s mode matrix closes with *"never restated as prose in a phase skill or in the
dispatcher"* -- restated here as a literal instead.

*Inflatable numerator.* `gates_count` is `(.gates_approved // []) | length` (`:4760`), and
`cmd_approve_gate` appends with no dedup (`:1990`). Re-approval is not misuse --
`cmd_checkpoint`'s drift path explicitly instructs it at `:2280` and `:2289` -- so
`- **Gates approved**: 4 of 3` is reachable through a documented workflow.

**Fix.** Derive both halves inside the existing `with_state_lock` body, guarding against a
hand-edited invalid `mode` (`required_gates_for_mode` -> `terminal_phase_for_mode` calls `die`):

```bash
  local gates_count required_gate_count skipped_for_count
  gates_count="$(echo "$state" | jq -r '[(.gates_approved // [])[].gate] | unique | length')"
  skipped_for_count="$(echo "$state" | jq -r '[(.skipped_phases // [])[].phase] | join(" ")')"
  required_gate_count="$( (required_gates_for_mode "$mode" "$lifecycle_mode" "$skipped_for_count" \
    | grep -c . ) 2>/dev/null || echo 3 )"
  [[ "$required_gate_count" =~ ^[1-9][0-9]*$ ]] || required_gate_count=3
```

then `"- **Gates approved**: ${gates_count} of ${required_gate_count}"`.

**Verification.** Two assertions: one pinning `1` as the denominator for a `prototype` initiative,
one pinning that a double `approve-gate 1` still renders `1 of N`. Confirm no enforcement path
regressed -- `cmd_gate_check`, `cmd_archive` and `metrics-report` all use
`map(select(.gate == $g))`/`first` and must be untouched.

**Files affected.** `plugins/edm/bin/edm-state`, `plugins/edm/bin/tests/wave6-smoke.sh` (or
`wave7`, wherever the HANDOFF renderer cases live).

**Severity note.** P1 on the factual-error clause: HANDOFF.md is the committed cross-user resume
artifact and this is its headline status row. No enforcement path reads the value, so blast radius
is human-facing only; L1 recorded it would not object to P2.

---

### G5 (P1, lens L6): the CHANGELOG asserts both the old and the new timing figures

**Problem.** `CHANGELOG.md:253-266` declares that *"every figure in the table above is a fresh
20-sample nearest-rank p95 against the corrected formula, not the pre-fix numbers ... none of the
deferred 'should be re-measured' language from the prior version of this note still applies."* The
table records `2,034ms p95` (AC5, `:242`) and `1.12x` with baseline 2,013ms / with-Mermaid 2,253ms
(AC6, `:243`) -- and 2253/2013 = 1.119, so `1.12x` is the arithmetic-consistent figure.

Two sites in the same file contradict it:

- `:41-43`, the `[3.1.0]` release-notes bullet **a reader reaches first**: *"`edm-lint-artifacts`
  was 70,168 ms ... Now 978 ms, with the Mermaid-class ratio at 1.19x against a 1.40x ceiling."*
  Same binary, same 30-file fixture: 978 ms against 2,034 ms is a 2x discrepancy.
- `:290`: *"Optimizing class 4 in turn (`ea31ce8` ...) brought it to 1.19x"*, inside a paragraph
  whose other figures (2.26x, 3.40x) **do** match the table.

CA-302 was a P1 filed jointly by L6 and L9 whose prescription was to replace the T67 evidence
figures with fresh measurements. The table was re-measured; these three were not swept.

**Fix.** Replace `978 ms` -> `2,034 ms p95` and `1.19x` -> `1.12x` at `:42`, and `1.19x` ->
`1.12x` at `:290`. If `1.19x` was a genuine earlier 10-sample reading, label it as such at both
sites rather than leaving it stated as the current result. Fold into the same commit as G6/CA-337
and note it in `decisions.md` alongside D47.

**Verification.** `grep -n '978 ms\|1\.19x' plugins/edm/CHANGELOG.md` returns nothing (or only
explicitly-labelled historical readings). Confirm T67 AC14's reproducible-evidence requirement is
satisfiable: every published figure must be reproducible by a run of the current 20-sample
harness -- which is why G46/CA-311 should land first.

**Files affected.** `plugins/edm/CHANGELOG.md`, `SRD/edm/EDMV3__prompt-streamline/decisions.md`.

---

### G6 (P1, lens L6): CA-256's own fix left three false claims about the timeout marker

**Problem.** `wave7-smoke.sh:5586-5590`:

```
  # G15/CA-256 (round 5): the G49 flock-timeout marker, using the SAME "${lockfile}.timeout.$$"
  # formula with_state_lock's flock branch uses (bin/edm-state:1079) -- never a hand-typed guess.
```

All three claims are false against the current tree:

- `with_state_lock`'s flock branch derives the marker at `edm-state:1117` as
  `_lock_timeout_marker="${TMPDIR:-/tmp}/edm-state.lock-timeout.$$"`. G17/CA-305 moved it out of
  the initiative directory **and** renamed it. `"${lockfile}.timeout.$$"` appears **nowhere** in
  `bin/edm-state`.
- `bin/edm-state:1079` is the CA-169 "never `rm -f "$lockfile"`" rationale, not the marker
  derivation.
- "never a hand-typed guess" is exactly backwards -- the value **is** a hand-typed legacy literal.

`edm-state:2792-2796` gets this right. Two comments about one mechanism now disagree, and the
wave7 one is the misleading half: a maintainer reads the adjacent `git check-ignore` assertion at
`:5606` as covering **today's** marker when it covers only a pre-G17 one. Two round-5 fixes
landing in the same round invalidated each other's documentation -- the strongest available
argument for G10/CA-340's durability half.

**Fix.** Rewrite `:5586-5589` to state that the tested name is the **pre-G17 in-directory legacy
shape**, retained for backward-compatible `.gitignore` coverage, cross-referencing
`_cmd_archive_move_body`'s sweep rationale **by name, not by line**; and state explicitly that the
current marker is derived under `TMPDIR` by `with_state_lock`'s flock branch and therefore never
lands in an initiative directory. Drop the `bin/edm-state:1079` citation entirely.

**Verification.** `grep -n 'lockfile}.timeout' plugins/edm/` returns only the legacy-compat test
site, with a comment that says so. Confirm the `git check-ignore` assertion at `:5606` still
passes (the root `.gitignore` covers both shapes -- L5 verified this character by character).

**Files affected.** `plugins/edm/bin/tests/wave7-smoke.sh`.

---

### G7 (P1, lens L9): CA-319's AC half never landed

**Problem.** CA-319 prescribed three edits. The **code half is done** and L8 verified it: both
`npm install -g @anthropic-ai/claude-code@2.1.226` lines (`.gitlab-ci.yml:603`, `:657`) carry an
explicit real version, both carry the refresh-procedure note at `:597-598`, and the deliberate
decision to leave install scripts enabled is recorded in-file with its reason (`postinstall: node
install.cjs` fetches the platform binary, so `--ignore-scripts` would break rather than tighten
the install).

The **AC half did not**: `epics/11:860-864` is **byte-unchanged**, still scoping T67 AC11's
no-network control to blocking jobs and therefore structurally exempting exactly the two jobs that
reach the network -- including `eval:nightly`, the one job carrying `ANTHROPIC_API_KEY`. CA-319's
prescribed control ("extend AC11 with a weaker pass asserting version pinning on `allow_failure`
jobs rather than exempting them") exists in no AC, and there is no `decisions.md` record electing
a different resolution.

A smoke assertion for the weaker pass **did** land at `wave7-smoke.sh:4505-4513`, so the
enforcement exists in the suite while the criterion that governs it says the opposite -- the same
"green test asserting the inverse of its criterion" shape as CA-033, CA-254 and CA-300.

**Fix.** Amend T67 AC11 to state the weaker per-job pin pass for `allow_failure` jobs, point its
verify at `wave7-smoke.sh:4505-4513` **by case name** (verbatim label -- the G40/CA-368 lesson),
and record the amendment in `decisions.md`. Fix G39/CA-349 in the same pass so the assertion the
AC now points at is actually discriminating.

**Verification.** Read T67 AC11 and confirm both network-reaching jobs are in scope. Run the
cited case and confirm it passes. Confirm no `allow_failure` job is exempted by the AC's own text.

**Files affected.** `SRD/edm/EDMV3__prompt-streamline/tickets/epics/11-cross-cutting-delivery.md`,
`SRD/edm/EDMV3__prompt-streamline/decisions.md`.

---

### G8 (P2, lens L4): the five gate hooks have no executed happy-path case

Filed at P2 by the owning lens because it is a coverage gap rather than a live defect, but it is
the gap guarding a **P0-class regression**, so fix it first among the P2s.

**Problem.** `wave7-smoke.sh:6137-6190` (the CA-298/G1 block) is otherwise a strong test -- it
extracts each of the five real hook commands from `hooks/hooks.json` and executes them against
stub `edm-state` binaries. It runs exactly two cases per hook:

- **Case A** (`:6157-6169`): `resolve-dir` fails -> hook must exit 0 (allow).
- **Case B** (`:6173-6185`): `resolve-dir` succeeds, `gate-check` fails -> hook must exit 2 (block).

There is no **Case C**: `resolve-dir` succeeds **and** `gate-check` succeeds -> hook must exit 0.
The shipped hooks end `... edm-state gate-check "$prefix" srd || exit 2; exit 0`. A regression to
`gate-check "$prefix" srd; exit 2`, or a stray `exit 2` appended after the gate-check line, passes
Case A (returns earlier), passes Case B (exit 2), and **locks the user out of `/edm:srd`,
`/edm:audit-srd`, `/edm:tickets`, `/edm:audit-tickets` and `/edm:implement` permanently, even with
every gate approved**.

The only thing standing against that today is the literal text pin at `:6119` -- a substring
assertion on the hook's *source text*, not its behaviour, and one a trailing `; exit 2` would not
disturb.

**Fix.** Add Case C inside the same `for matcher in ...` loop, reusing the existing scratch/stub
scaffolding (~8 lines): stub `resolve-dir) echo "/tmp/CA298PFX"; exit 0` and `gate-check) exit 0`,
run `$cmdfile`, assert `ec -eq 0`, with a failure message naming that an approved gate must not
block.

**Verification.** Temporarily append `; exit 2` to one hook command in a scratch copy of
`hooks.json` and confirm the new case **fails**. Revert. Run `run-all.sh` and confirm five new
passing assertions.

**Files affected.** `plugins/edm/bin/tests/wave7-smoke.sh`.

---

### G9 (P2, lenses L3 + L11): `gate-check` is labelled read-only in eight places and writes

**Problem.** `cmd_gate_check:3393-3396` calls `record_degraded_check` on the absent-`schema_version`
/ `mode == "null"` branch, which at `:1625-1631` does
`rmw_state ... .degraded_checks = ... | .last_updated = $ts` -- taking the state lock, bumping
`last_updated`, and writing a `.bak` sibling via `_rmw_state_body:705`. The two pre-checks narrow
the window (CA-061's idempotence short-circuit `:1612-1615`, G22's writability skip
`:1618-1624`) but the **first** invocation for a legacy initiative on a writable checkout writes.

The eight claim sites: `edm-state:32` (help line), `:3338` ("Read-only -- never mutates state"),
and all five prompt bodies at `hooks.json:23, 36, 49, 62, 75` ("read-only; ..."). `:1621`'s own
message asserts "gate-check remains read-only", i.e. the code knows the contract is load-bearing
but preserves it only on the unwritable path; `:1588-1608` argues the contract holds for the
**non**-writable case only and never claims the writable first call is read-only -- so False Alarm
Filter criterion 2 does not cover this.

The mutation is intended (EDMV3-T62 AC5 wants the skip recoverable from state), so **the defect is
the eight claims, not the write**. CA-298's rewrite multiplied the inaccurate claim by five and
put it in front of a model instructed to run the command itself; an operator or agent reading
"read-only" will run `gate-check` against a shared initiative believing it cannot contend for the
lock or dirty the working tree, and it can do both.

**Fix.** Qualify the label at its source (`:32` and `:3338`: "read-only with respect to gate
state; may additively record a one-time `.degraded_checks` breadcrumb for a legacy initiative")
and drop the bare "(read-only)" from the five prompt strings. Alternative: move the breadcrumb
into `cmd_phase_start` / `cmd_approve_gate`, which already mutate on the same legacy branch
(`:2024`).

**Verification.** Add a smoke assertion that the unqualified string `read-only` does not appear in
`cmd_gate_check`'s docstring or the five prompt bodies while `record_degraded_check` remains
reachable from `cmd_gate_check`. Then run `gate-check` against a legacy scratch initiative and
confirm the state file diff matches what the qualified label now promises.

**Files affected.** `plugins/edm/bin/edm-state`, `plugins/edm/hooks/hooks.json`,
`plugins/edm/bin/tests/wave7-smoke.sh`.

---

### G10 (P2, lenses L1 + L6): the stale-citation class recurred at two sites round 5's own fixes created

**Problem.** Two new instances, both authored by round-5 remediation, both invisible to the guard
round 5 added:

1. `edm-init:163-164` (added by CA-314's fix) -- `edm-state:691` is cited for the state backup;
   that line is the `_print_line` docstring, and the backup is `cp -p "$f" "${f}.bak"` at
   `edm-state:705` inside `_rmw_state_body`. `edm-state:1034-1035` is cited for the lock file
   family; that is `with_state_lock`'s docstring header -- the `lockfile`/`lockdir` assignments
   are at `:1040-1041`, and the never-unlinked-per-CA-169 rationale the comment attributes to that
   range is at `:1079-1087`.
2. `wave7-smoke.sh:3777` (added by CA-007's fix) -- cites `run-eval.sh:443-460` for the
   containment loop; that range is `export EDM_SRD_ROOT=...` plus the opening of the
   `PHASE1_PROMPT` heredoc. The containment check lives at `:578-606`, with the `R*|C*`
   rename/copy parse at `:590`. ~140 lines off -- and the comment's stated purpose (catching a
   divergence between the two copies) is exactly what a wrong pointer defeats.

The G39/CA-315 durability guard landed at `wave7-smoke.sh:7293-7320` but pins only the five sites
round 5 named and explicitly declines a tree-wide ban at `:7296-7301` as "not statically
enforceable without false positives." **L6 has falsified that rationale in the narrow case**:
every new instance this round is a citation of this plugin's own `bin/` or `evals/` file by
relative name plus digits.

**Fix.**

1. Re-point all three by name per the CA-095 convention. For `edm-init:163-164`: *"the state
   backup (written by `_rmw_state_body` in `bin/edm-state`, permanent by design for migrate-path
   rollback), the lock file family (`with_state_lock`'s `.lock`/`.lockd`, deliberately never
   unlinked -- see its CA-169 comment) and `write_atomic`'s transient temp files."* For
   `wave7-smoke.sh:3777`: *"Reproduces `run-eval.sh`'s own containment-violation parse loop (the
   `R*|C*` rename/copy branch, CA-007) verbatim"* -- no line numbers.
2. **Durability half, load-bearing.** Extend the guard with a shape-restricted ban on new
   file-and-line citations inside comment lines:
   `\b(edm-state|edm-init|edm-lint-artifacts|edm-check-\w+|run-eval\.sh|score-artifacts\.sh|_edm-\w+\.sh|wave\d\w*-smoke\.sh|run-all\.sh):\d+`
   with an allowlist for the two DATA uses (`.gitlab-ci.yml:198`, and the ticket-provenance quote
   at `edm-check-grants:419`). Without this, expect an eighth consecutive round of this finding.

**Verification.** Run the new ban and confirm it fires on a deliberately-added
`edm-state:1234` comment and does not fire on the two allowlisted sites. Confirm the two re-pointed
comments resolve by name.

**Files affected.** `plugins/edm/bin/edm-init`, `plugins/edm/bin/tests/wave7-smoke.sh`.

---

### G11 (P2, lenses L3 + L5): CA-169's never-unlink justification is true only for `edm-init`-created initiatives

**Problem.** `edm-state:1083-1087` justifies never unlinking the flock file with *"G38/CA-314:
`edm-init` writes `.edm-state.lock*` into every initiative's own per-initiative `.gitignore`
unconditionally, so this is not a leak in a consumer project either"*, and `README.md:208-229`
carries the same `edm-init`-only framing. But `edm-init` is not the only creator: `cmd_init` does
its own `mkdir -p "$(dirname "$f")"` at `edm-state:1807` and `rmw_state` does the same at `:720`,
and `edm-state init <PREFIX>` is a publicly documented subcommand (`CLAUDE.md:761` table,
`edm-state --help`). Via that entry point the directory materializes with **no** ignore file,
after which `.edm-state.json.bak` (`:705`), the never-unlinked `.edm-state.lock` (`:1120`),
`.edm-state.lockd/` + `pid` (`:1165`, `:1214`) and `write_atomic`'s `*.tmp.XXXXXX` staging
(`:631`) all show up untracked in `git status` on the consumer's host and are reachable by a
`git add -A`.

L3's second site: `cmd_update_patterns` takes its lock on the **pattern document**
(`with_state_lock "${pattern_file%.md}"` at `:4705`), so the flock lockbase is
`plugins/edm/docs/audit-patterns/code-audit` -- inside the plugin's own tree, where `edm-init`
never writes a `.gitignore`, so the `:1083-1087` rationale does not reach it either.

**Fix (preferred).** Move the four-line `.gitignore` write into `cmd_init` itself so both entry
points are covered and `edm-init`'s copy becomes a redundant idempotent write; then correct
`:1083-1087` and `README.md:215-217` to cite the per-initiative file **plus** the root pattern for
the in-plugin lockbase. Alternative: declare `edm-state init` internal-only in its help text and
the `CLAUDE.md` subcommand table and name the precondition in both claims. Consider also moving
the pattern-file lockbase under `TMPDIR` keyed by a hash of the pattern file's absolute path,
which makes the claim true by construction rather than by a second `.gitignore` entry the next
reader has to find.

**Verification.** In a scratch consumer repo with no EDM history: `edm-state init TESTX`, run one
mutation, then `git status --porcelain` and confirm zero untracked EDM runtime files. Repeat via
`edm-init` and confirm parity.

**Files affected.** `plugins/edm/bin/edm-state`, `plugins/edm/bin/edm-init`,
`plugins/edm/README.md`.

**Note.** L3's stronger claim -- that the in-plugin `.lock` files are matched by no `.gitignore`
pattern -- is **not actionable**; see Decisions #1.

---

### G12 (P2, lens L3): CA-298's residual -- `gate-check` still has a non-refusal non-zero path

**Problem.** CA-298's remediation closed the missing-state-file case with a `resolve-dir`
pre-probe. It did not close the case where `gate-check` itself performs a **write** that can fail
for reasons unrelated to any gate, so the five command hooks still convert a setup error into a
gate refusal via `|| exit 2`.

Trigger, no user error: a legacy initiative (the exact population the branch exists for) plus a
Stop-hook or PreCompact-hook `checkpoint-if-active` sweep mid-flight holding the lock
(`cmd_checkpoint` takes it at `:2257` and again via `write_handoff_internal` at `:2298`); the user
submits `/edm:srd LEGACY` in that window; `record_degraded_check`'s `rmw_state` (`:1625`) exceeds
the give-up bound (10s flock `:1120`, ~5s across 50 tries mkdir `:1027`) and dies with exit 1; the
hook's `|| exit 2` converts it to a gate refusal and blocks the prompt with a lock-timeout
diagnostic naming no gate.

Same class in the missing-`jq` case: `cmd_resolve_dir:4411-4418` does **not** call `require_jq`,
so the pre-probe succeeds on a host without `jq` and `cmd_gate_check`'s `require_jq` at `:3357`
then dies. Every other hook in `hooks.json` degrades to exit 0 when a dependency is absent
(`SessionStart`, `Stop`, `PreCompact` all end in `|| true`; `PreToolUse` opens with two
`command -v ... || exit 0` probes), so these five remain the outliers.

**Fix (2 is the durable one).**

1. Make the breadcrumb write non-fatal: wrap `:1625` so a failure warns on stderr and returns 0,
   matching the two existing best-effort pre-checks in the same function (`:1615`, `:1620-1623`) --
   whose docstring already calls itself "best effort" twice.
2. Give `cmd_gate_check` a dedicated refusal status (CA-298's own option 2) so the hooks
   `exit 2` only on that code and `exit 0` on anything else. This also lets them drop the
   `resolve-dir` pre-probe and stop paying two process spawns per prompt. Plus: add `require_jq`
   to `cmd_resolve_dir`, or a `command -v jq >/dev/null 2>&1 || exit 0` probe to each hook body.
3. Add an **executing** case that runs a hook body against a legacy schema-less prefix with the
   lock held by a background holder and asserts exit 0 rather than 2.

**Verification.** Run step 3's case. Separately, `PATH` without `jq`: run a hook body and assert
exit 0.

**Files affected.** `plugins/edm/bin/edm-state`, `plugins/edm/hooks/hooks.json`,
`plugins/edm/bin/tests/wave7-smoke.sh`.

---

### G13 (P2, lens L8): CA-305's rewrite made the marker probe unconditional

**Problem.** CA-305's two named halves are verified closed by four lenses. What the rewrite
introduced: the marker's **existence probe at `:1122` now runs unconditionally** on every return
path from the locked subshell, where the pre-G49 design consulted `_lock_ec -eq 99` first; and the
pre-clean at `:1118` is best-effort (`rm -rf ... 2>/dev/null || true`).

Consequence: on a host with a shared `/tmp` (unset `TMPDIR`, sticky bit, multiple local users or a
shared CI shell runner) another local user pre-creates
`/tmp/edm-state.lock-timeout.<pid>` as a directory they own; the victim's `rm -rf` cannot remove
it and fails silently; `mkdir` is never reached because there was no timeout; `[[ -e ... ]]` is
true; and `die "state lock timeout after 10s on ..."` fires **after the locked body has already
run and mutated `.edm-state.json`**. The caller -- ~30 bare mutator call sites via `rmw_state` --
is told the write timed out when it **succeeded**. The PID space (32768 default on Linux) is small
enough to pre-plant exhaustively. The same trigger also fires with **no attacker at all**, from
any unremovable stale entry.

**Fix.** Gate the probe on the only branch that can create the marker, preserving CA-305's
two-arm diagnostic:

```bash
if [[ $_lock_ec -eq 99 ]]; then
  if [[ -e "$_lock_timeout_marker" ]]; then
    rm -rf "$_lock_timeout_marker" 2>/dev/null || true
    die "state lock timeout after 10s on ${lockfile} (another edm-state process may be holding it)"
  fi
  die "state lock timeout after 10s on ${lockfile} ... -- the timeout marker could not be created at ${_lock_timeout_marker} (check TMPDIR writability)"
fi
```

Optionally derive the name with `mktemp -d` (captured before the subshell, path passed in) so a
pre-plant is impossible at all.

**Verification.** Extend `wave7-smoke.sh`'s G49 case (currently a static needle on the marker path
literal at `:7209`) with an executing case that plants an unremovable marker and asserts a
**successful** write still reports success. Flock-branch-only, so this case must be skipped or
gated on `command -v flock`.

**Files affected.** `plugins/edm/bin/edm-state`, `plugins/edm/bin/tests/wave7-smoke.sh`.

---

### G14-G22 (P2): remaining code-behaviour findings

Each has a single concrete fix; full evidence is in the ledger entry named.

- **G14 / CA-352 -- `edm-state:236-243`.** `state_file_for`'s multiple-match branch warns to
  stderr and returns `matches[0]` in **glob order**, and every automated consumer discards stderr
  (the five hooks pipe `resolve-dir` to `>/dev/null 2>&1`; `SessionStart` adds `2>/dev/null`;
  `Stop`/`PreCompact` end in `|| true`), so two developers on one repo can have `edm-state set`
  write to two different initiatives. **Fix:** `die` on `${#matches[@]} -gt 1`, naming every
  candidate path and instructing `edm-state migrate-path` or removal of the duplicate -- mirroring
  `pattern_insert_line_for:4540-4542`, which already dies rather than guess and is the house
  pattern. If a read-only caller needs best-effort, add an explicit opt-in flag rather than making
  guess-silently the default for ~30 mutators. **Verify:** a smoke case asserting the refusal (no
  current assertion can distinguish "picked the right one" from "picked one").

- **G15 / CA-353 -- `edm-state:5023-5028`.** `of_out="$(cmd_audit_converged "$prefix" 2>&1)"`
  merges stderr, and exit 1 covers **three** conditions (`:4034-4035`): blocking findings remain,
  the round was partial/unknown, or a line carries an out-of-enum status. Only the first is a
  findings summary, yet all three render verbatim under `## Open Code-Audit Findings` in a
  committed HANDOFF.md -- so "invalid JSONL at .../findings-ledger.jsonl" publishes as the
  initiative's open-findings state to the very artifact an agent resumes from. `die` messages land
  there too. **Fix:** capture stdout and stderr independently; render only stdout under the
  findings heading; route a non-findings exit 1 to a distinct row
  (`- **Open findings**: unavailable (ledger error; run edm-state audit-converged <PREFIX>)`).
  Better: give `cmd_audit_converged` distinct exit codes for "blocking findings remain" versus
  "ledger unreadable / round not full" -- three callers branch on its status and none can tell
  those apart. **Verify:** render HANDOFF.md against a deliberately-malformed ledger and assert
  the findings section does not contain the diagnostic.

- **G16 / CA-355 -- `edm-state:4622-4630`.** The no-insertion-point branch prints `0` and returns
  0, indistinguishable from "no novel findings," and `cmd_update_patterns` persists
  `patterns_updates[<type>] = {new_findings: 0}` (`:4709-4713`) and prints "no novel findings to
  append" (`:4718`) -- which is false; N findings were found and none recorded. The state field is
  durable, so the loss is permanent and repeats every run. Root trigger: the `:4693` pre-flight
  uses a **fence-unaware** `grep -qxF` while the body resolves through the **fence-aware**
  `pattern_insert_line_for` (CA-056). **Fix:** make the `:4693` pre-flight use the same
  fence-aware resolution the body uses, so the two can never disagree, and delete the inner
  branch; return a distinct non-zero status and refuse loudly rather than recording a zero.
  **Verify:** a case with the target heading present **only inside a fence**, asserting non-zero
  exit and that `patterns_updates` is not written.

- **G17 / CA-354 -- `edm-state:3812-3865`.** Read+render (`:3829-3853`), `write_atomic`
  (`:3859-3860`) and `record_artifact_hash` (`:3864`, which takes the state lock via `rmw_state`)
  are each atomic but the sequence is not, so last-hash-wins races last-content-wins and surfaces
  as a phantom `cmd_checkpoint` drift warning (`:2263-2295`) whose prescribed remediation is
  expensive and wrong. **Fix:** move read+render+`write_atomic` into a `_cmd_render_ledger_body`
  under one `with_state_lock` on `"${init_dir}/code-audit/findings-ledger"`, printing the rendered
  path; call `record_artifact_hash` **after** the lock releases -- required, because the
  reentrancy guard at `:1067` is process-global, not lockbase-keyed (CA-306). **Verify:** two
  concurrent `render-ledger` invocations, then assert the recorded hash matches the on-disk `.md`.

- **G18 / CA-378 -- `edm-state:3829-3853`** (found by the synthesizer; attribution follows
  CA-182/CA-183's `operator` precedent). `cmd_render_ledger` interpolates each title verbatim into
  a markdown **table cell** with no `|` escaping, so a pipe-bearing title terminates the cell
  early and silently shifts every later column. Not hypothetical: pipes occur naturally in case
  patterns (`''|*[!0-9]*`), regexes, glob sets (`*.awk|*.txt`), enum diagnostics
  (`open|fixed|noted`) and column lists -- **ten round-6 entries contain them**. And
  `findings-ledger.md` is committed with its hash recorded at `:3864`, so a corrupted render is
  hashed as authoritative while `cmd_checkpoint` compares against that hash rather than the JSONL.
  **Fix:** in the jq program that builds `$body`, `gsub` the pipe (and backslash) in `title`,
  `component` and every other cell-bound field. **Verify:** render a ledger with a pipe-bearing
  title and assert the row still has exactly eight cells; assert the eight-cell shape across every
  rendered row so a future field addition cannot break alignment either. **Fix this before the
  next `render-ledger`.**

- **G19 / CA-360 -- `evals/score-artifacts.sh:498`.** CA-088's `case "$lens_n" in ''|*[!0-9]*)
  continue ;; esac` at `:464-466` skips a file **without incrementing `total`** (`:494` is after
  the guard), and the only zero-denominator guard is the "no files at all" return at `:435`. If
  every discovered file is skipped, awk aborts with "division by zero", emits nothing, and
  `round_int ""` coerces to **`D5_SCORE=0`** -- a data-shape error laundered into a real dimension
  score that enters `dimensions_scored` and the mean. Reachable via exactly the shapes CA-088 was
  written for (a literally-named `lens-L*.jsonl`, or `lens-L.jsonl`). **Fix:** insert after the
  loop closes at `:496`, before `:498`:
  `if [[ "$total" -eq 0 ]]; then D5_SCORE=""; D5_REASON="no lens-L<N>.jsonl with a numeric lens number (every discovered file was skipped)"; return; fi`
  **Verify:** score a run directory containing only `lens-L.jsonl` and assert D5 is reported
  unscored, not 0.

- **G20 / CA-348 -- `evals/run-eval.sh:266`.** `SCRATCH_DIR="$(mktemp -d)"` is the sole bare
  `mktemp -d` in `bin/` + `evals/`; all ~40 siblings use
  `mktemp -d "${TMPDIR:-/tmp}/<name>.XXXXXX"`, and `_harness.sh:59` names the bare form
  **explicitly as the anti-pattern** `harness_scratch_dir` was extracted to replace -- so the
  consistency test fails here rather than excusing it. On macOS a template-less `mktemp -d`
  behaves as `-t tmp`, resolving `_CS_DARWIN_USER_TEMP_DIR` **first**, so a redirected `TMPDIR` is
  bypassed. Second-order: the returned `/var/...` path is a symlink to `/private/var`, so
  `$SCRATCH_DIR` and `git rev-parse --show-toplevel` inside it disagree, and `:443` exports that
  unresolved value as an absolute `EDM_SRD_ROOT` -- the live counterexample to G1's relativization
  contract. **Fix:**
  `SCRATCH_DIR="$(mktemp -d "${TMPDIR:-/tmp}/edm-eval-scratch.XXXXXX")" || die "mktemp -d failed"`.
  Separately add a **missing-template** pattern to the T61 AC11 sweep at `wave7-smoke.sh:1022` --
  its current regex catches a template *suffix* (`XXXXXX[A-Za-z0-9]`), which is why this site
  survived CA-014's widening of that very sweep to cover `evals/`. **Verify:**
  `TMPDIR=/some/other/dir bash evals/run-eval.sh --provision-only` and assert the printed path is
  under `TMPDIR`.

- **G21 / CA-359 -- `edm-compare-eval:133-135`.** The reachable regression path prints *"adopt the
  documented fallback (EDMV3-T39 AC7): revert the dispatcher and ship bin/edm-check-skill-sync
  instead."* `edm-check-skill-sync:5-9` states the opposite as settled fact: *"This is not a
  fallback for a branch that was not taken (the GO path was taken); it is a permanent regression
  tripwire ... run unconditionally by bin/tests/run-all.sh."* So "ship it instead" is a no-op and
  "revert the dispatcher" reverses the shipped architecture that `CLAUDE.md`'s architectural rule
  2 enforces -- an operator following this line on a genuine score regression would **undo the
  initiative**. **Fix:** replace the two lines with the real remediation (investigate the
  per-dimension delta table the script already prints; record the comparison in `decisions.md`),
  drop the revert clause, and give the `EDMV3-T39 AC7` citation the same treatment. Do **not**
  delete the exit path. **Verify:** read the regression branch's output and confirm no instruction
  contradicts `edm-check-skill-sync`'s header.

- **G22 / CA-362 -- `evals/run-eval.sh:616-624`.** `${in_tok:-0}` on `:616` substitutes on unset
  **or null**, so the `''` alternative of the `case` at `:621`-`:624` can never match -- the
  empty-capture case it was written for is consumed one line earlier. Same shape as CA-140's dead
  `-z` disjunct and the CA-202/CA-260/timing.sh dead-default family, **all four of which this
  project chose to delete**, so criterion 3 argues for filing. **Fix (delete):** drop the four
  `; <var>="${<var>:-0}"` re-assignments on `:616-619` and let the `case` be the single guard --
  it already handles empty and non-numeric identically. **`cost` at `:620` has no `case`
  companion, so its `${cost:-0}` is load-bearing and must stay.** **Verify:** feed a malformed
  `raw/*.json` and assert the token fields still read 0.

---

### G23-G25 (P2): duplication and self-describing counts

- **G23 / CA-343 -- three duplications each carrying a FALSE single-source claim** (this is why
  they are grouped apart from G24). (a) `edm-state:2371-2375` vs `:3171-3174`: the per-epic
  coverage row is duplicated and **already diverged** (identical 15/14 padding prefix, then one
  adds a three-branch pct pad and `measured_at` and the other stops), with each site hand-writing
  its own header/underline pair -- while `COVERAGE_LAYER_ROW_JQ_DEF`'s docstring at `:990-994`
  says "one renderer, one padding scheme ... so the two can never diverge again (CA-012)", true
  only of the *layer* row. (b) `edm-state:2015-2046` (`cmd_phase_start`), `:3390-3415`
  (`cmd_gate_check`) and partially `:2618-2630` (`cmd_archive`): the required-gate-approved
  procedure is written three times; the skipped-phases jq appears at `:2034`, `:2090`, `:2621`,
  `:3400` (four copies) and the approval count at `:2039`, `:2625`, `:3408` (three) -- while
  `:2026-2028` and `:3379-3383` both assert the sites share one derivation. Two of the three
  enforcement points for this plugin's central invariant must be edited in lockstep, and a fix
  applied to `gate-check` alone leaves the `Skill`-tool path (which bypasses the hooks and reaches
  `phase-start` directly, `:2004-2007`) on the old rule. (c) `edm-state:2432-2439`:
  `migrate-schema` hand-globs both archived shapes that `list_state_files --archived`
  (`:129-148`) already enumerates deduped -- a third site knowing the layout against
  `state_file_for`'s declared "single source of layout truth" (`:208-218`), and the AC4 refusal
  silently stops working if a future variant is not applied here too.
  **Fix:** define `COVERAGE_EPIC_ROW_JQ_DEF` beside the layer def, reference it from both sites,
  and correct CA-012's docstring to name both rows; extract `gate_is_approved <state-json> <gate>`,
  `skipped_phases_str <state-json>` and a composing
  `gate_required_and_approved <state-json> <mode> <lifecycle_mode> <gate>`, keeping each caller's
  own diagnostic text and `record_degraded_check` label at the call site; route migrate-schema's
  archived probe through `list_state_files --archived` or a new `archived_state_file_for` helper
  next to `state_file_for`.
  **Verify:** `get-coverage` and `metrics-report` produce byte-identical epic rows on shared
  columns; `phase-start`, `gate-check` and `archive` agree on a `mini-srd` initiative with phases
  skipped; `migrate-schema`'s AC4 refusal still fires for both archived layouts.

- **G24 / CA-344 -- five mechanical duplications, no divergence, no false claim.** One DRY pass
  over the small `bin/` helpers. (a) `edm-init:53` re-implements `edm-validate-prefix:42`'s
  `^[A-Z][A-Z0-9]{2,5}$` with its own message while **also** delegating to the validator at
  `:81-86`; the risk is direction-asymmetric (a future widening is rejected by `edm-init`'s copy
  *before* the canonical validator is consulted), and the `command -v` premise is not one this
  script holds -- `:161` calls `edm-state init` unconditionally. **Fix:** delete `:53` and make
  `:81-86` unconditional. (b) `edm-check-grants:256-263` and `:501-507` implement the
  effective-grant predicate once per direction; **fix:** extract
  `agent_grants_class <tools> <disallowed> <class>` (~12 lines to 2). (c)
  `edm-lint-artifacts:414-417/:426-432`, `:438-441/:457-463`, `:486-489/:499-505` copy the
  collect-and-summarize wrapper three times, so the exit-code contract the PreToolUse hook depends
  on (0 clean / 1 violations, `:42-47`) is encoded three times; **fix:** `_collect_into
  <arrayname> <dir>` and `_summarize_and_exit <label> [<scope-suffix>]`. (d)
  `edm-validate-prefix:58-72` and `:80-87` are two copies of one product-dir walk with diverged
  guards; **fix:** `_scan_product_dirs_for_prefix <root> <prefix>`, each caller deciding `die` vs
  warn. (e) `edm-check-grants:360-368` and `:370-375` hand-compute the same lookback window and
  `resolve_targets_for_line:377-390` can call both for one hit, so the `sed` range runs twice;
  **fix:** `_lookback_window <file> <line> <lookback>`, capture once, pass the text to both.
  **Verify:** `run-all.sh` green with no assertion-count change, plus `edm-check-grants` and
  `edm-lint-artifacts` byte-identical output on the current tree before and after.

- **G25 / CA-342 -- two self-describing counts, each wrong by exactly one.** (a)
  `CLAUDE.md:843-854` says "Five of the eight `schema_at_least()` call sites ... carry that
  comment today; three do not" and names three. Eight sites confirmed (`:1957, 2019, 2082, 2148,
  2598, 2695, 3393, 4061`); canonical comments exist at `:2008, 2075, 2595, 3350, 3384` -- five
  comment *lines*, but `:3350` and `:3384` both serve the single `cmd_gate_check` site at `:3393`,
  so they cover **four** call sites. **Four** lack it: the three named, plus
  `cmd_phase_complete`'s phase-6 check at `:2148`, whose nearby `:2142` carries the number
  mid-sentence rather than in the canonical leading form -- verbatim the failure mode `:852-853`
  calls out for `cmd_archive`. A contributor who trusts the enumeration concludes `:2148` is
  covered when it is not -- and `:2148` is precisely G2/CA-333's site. (b)
  `_edm-lint-lib.sh:51-54`'s clause advertising itself as "the honest position on actual callers
  (G40, corrected -- the prior wording here overstated it)" names two external callers;
  `bin/edm-state` is a third (`ignored_line_set` at `:4530`, `:4593`; `is_ignored_line` at `:4535`,
  `:4599`), and the same file's header at `:4-5` correctly lists it -- so the file contradicts
  itself two paragraphs apart inside the clause claiming to be the corrected version.
  **Fix:** change "Five ... three do not" to "Four of the eight ... four do not" and add a bullet
  for `cmd_phase_complete`'s phase-6 check; correct `_edm-lint-lib.sh:51-54` to name all three
  external callers. **Durability:** convert both counts to computed smoke assertions (`grep -c`
  the call sites against the number in the prose) -- the shape G51's own `-eq 4` check already
  uses. **Lens disagreement recorded** -- see Decisions #3.
  **Verify:** the two new computed assertions fail if either number is edited without the code.

---

### G26-G28, G35, G39, G46-G48 (P2): test-quality findings

- **G26 / CA-350 -- `wave7-smoke.sh:4206`.** T49 AC6's four D1 tripwires are **case-blind**: the
  haystack is built with `grep -rni`, and the four assertions at `:4214/:4218/:4222/:4226` pass it
  to `assert_tree_absent`, which verifies case-**sensitively** (`_harness.sh:265` runs
  `count_matches_strict`, which at `:198-207` is `command grep -c "$@"` with no `-i`). A real
  violation written `Double-check your own work` -- sentence-initial capitalization, the most
  likely prose form -- is found by the scan, lands in the haystack, and is invisible to the needle:
  `real_count` is 0 and **all four assertions pass over a live violation**. The lowercase controls
  pass normally, so nothing signals. Verified live: 0 current hits, so this is tripwire blindness,
  not an escaped violation. CA-037's class on a new axis -- same literal, divergent matcher flags.
  **Fix:** drop `-i` from `:4206` (the four needles are already lowercase and the AC's text is the
  lowercase form) and add a fifth control seeded with `Double-Check your own work` asserted to be
  **caught**, so the case axis gets a positive control.

- **G27 / CA-361 -- `wave7-smoke.sh:7362`, `:7370`.** Two new captures in this session's G51 block
  use bare `grep -c` with no `|| true` and no `count_matches`. `grep -c` exits 1 on zero matches,
  so under this file's `set -euo pipefail` the assignment at `:7362` **aborts the suite**:
  `:7370-7373` never run and the `Results:` line at `:7376` never prints, so `run-all.sh:132-142`
  scores CRASH (correct -- no masked pass) but every assertion count from the run is lost.
  `_harness.sh:176-190` documents `count_matches` for exactly this and ~180 sibling sites use the
  guarded form. **Fix:**
  `count_matches '_lint_report_class_hits "' "${PLUGIN_DIR}/bin/edm-lint-artifacts"` (or append
  `|| true`) at both sites.

- **G28 / CA-351 -- `wave7-smoke.sh:7034-7036`, `:7066-7069`, `:5345-5349`.** Both G47 cases call
  `stage_session_jsonl` (`_harness.sh:400-419`, which `mkdir -p`s its target) while
  `session_dir_for_test_cwd` (`_harness.sh:390-392`) is `${HOME}/.claude/projects/...`; the
  subshells `cd` into `$TMP` but never export a scratch `HOME`, so the fabricated session dir
  materializes in the invoking user's **live Claude Code session store** -- which
  `get_session_tokens_since` itself reads. Cleanup is the last statement in each subshell and
  `:7072`'s `out="$(bash -c ...)"` is unguarded under `set -euo pipefail`, so any failure or
  Ctrl-C strands it; the suite's `$TMP` trap does not cover it. Verified currently clean, and
  residue would be inert (keyed to a vanished cwd), which holds it at P2. All six wave6 siblings
  and the CA-160b site **in this same file** do the opposite. **Fix:** `export HOME` to a scratch
  path (or `mktemp -d "${TMP}/g47-home.XXXXXX"`) inside each subshell before calling
  `session_dir_for_test_cwd`, mirroring `:5350`; then correct the now-false "only bare `$HOME`
  reference in this suite" claim at `:5345-5349`.

- **G35 / CA-366 -- `wave7-smoke.sh:7364`.** This session's G51 pass label prints "all four
  violation classes (attribution, unicode x2 platform branches, leaked-tool-tag)" -- but the
  parenthetical names **three** classes (unicode counted twice for its two platform branches) and
  `--help:24-39` documents **seven**; `mermaid-semicolon`, `unterminated-fence`, `scan-error` and
  `unreadable` do not route through `_lint_report_class_hits` at all. `CLAUDE.md`'s `bin/` table
  deliberately refuses to state a class count for this binary, and this is a printed,
  operator-visible line hardcoding one. The `-eq 4` assertion is **correct**; only the label is
  wrong. **Fix:** "all four per-class call sites (attribution, unicode on both platform branches,
  leaked-tool-tag) call the shared helper".

- **G39 / CA-349 -- `.gitlab-ci.yml:603`, `:657`, `wave7-smoke.sh:4511-4517`.** CA-319's pin is
  correct as shipped, but `check` is a plain substring test (`_harness.sh:27-34`) and the needle is
  `npm install -g @anthropic-ai/claude-code@` -- which `@latest`, `@next`, `@^2.1.0` and `@~2.1`
  all satisfy. The negative control at `:4516` only proves a **bare** install fails. So the one
  control guarding the least-controlled, `ANTHROPIC_API_KEY`-bearing job in the pipeline can be
  satisfied by exactly the unpinned behaviour it exists to prevent -- and "replace the stale pin
  with `@latest`" is the single most likely future edit to that line. **Fix:** require a numeric
  first character after the `@` (a `@[0-9]` regex form, or a captured
  `@<major>.<minor>.<patch>`), and add a second negative control asserting
  `...claude-code@latest` does **not** satisfy it. Consider folding both pinned versions into one
  `variables:` entry so the pin is one line to refresh, matching what `.alpine_edm` already does
  for the image digest.

- **G46 / CA-311 -- `bin/tests/timing.sh:96-173`, `:217-220`.** The round-5 remediation added five
  **correct** assertions in a new `self_test()`. **Nothing runs them.** `run-all.sh:45` discovers
  `*-smoke.sh` and `timing.sh` is deliberately not one (CA-328); `wave7-smoke.sh` invokes
  `timing.sh` three times only (`:4281` bare, `:4294 --session-start`, `:4316
  --generate-fixture`); no `--self-test` invocation exists anywhere in `plugins/edm/` or
  `.gitlab-ci.yml` (grep-verified); and `timing.sh:99-101` says so outright. So reverting
  `_P95_SAMPLE_COUNT` from 20 to 10, or `_p95`'s ceiling, or re-breaking the awk fallback, still
  leaves `run-all.sh` fully green -- and CA-309's and CA-310's fixes are unexercised for the same
  reason. The non-wiring is *acknowledged* in a comment but not *justified*, and the round-5
  prescription asked specifically for assertions that make a silent revert **fail**.
  **Fix:** wire it using the in-repo precedent -- `wave7-smoke.sh:4605-4613` runs
  `evals/tiering-matrix.sh --self-test`, asserts exit 0, then asserts each individual
  `self-test PASS:` line. Add the twin next to the T67 timing block: capture
  `bash "$TIMING_SH" --self-test 2>&1` with `|| ec=$?` **on the same statement**, assert exit 0,
  assert each of the five `self-test PASS:` substrings **individually** (so deleting one assertion
  fails rather than silently shrinking the run), and assert the summary line `self-test: PASS (5/5`
  so the assertion **count** is pinned. Cost ~1s. **Land this before G5/CA-336** so the published
  evidence figures are re-recorded against a guarded harness.

- **G47 / CA-312 -- `wave6-smoke.sh:205-207`.** CA-312's sweep converted `:214-217` and `:229-232`
  to exact string equality and missed the sibling **eight lines above the comment that describes
  the defect class**. The label claims "= only gate 3"; the assertions prove gate 3 present
  (`check`, a substring test) and gate 1 absent -- **nothing rules out gate 2**. A regression
  returning `"2 3 "` satisfies `check` (contains `3`) *and* `check_absent` (no `1 `), and gate 2's
  origin is phase 3, which is in this case's skip list, so gate-2 suppression is precisely what
  the case exists to test. **Fix:** `[[ "$gates_out2" == "3 " ]] && pass ... || fail ...`, and drop
  the now-redundant `check_absent` at `:207`.

- **G48 / CA-233 -- `wave7-smoke.sh:948-950`.** Both CI loops now carry the identical
  `*.awk|*.txt` exclusion (L7 verified `.gitlab-ci.yml:108` and `:243`), but the in-suite twin
  still excludes only `awk`, so both vocabulary data files remain load-bearing bash source for the
  blocking `test:smoke` job, and the prescribed cross-loop consistency assertion still does not
  exist. **Fix:** add the `txt` extension to the in-suite twin, then add **one** assertion that
  all **three** loops share the same extension set so they cannot diverge again.

---

### G29-G34, G36-G38, G40-G45 (P2): wiring, consistency and spec findings

- **G29 / CA-356 -- `edm-state:1677`.** `qc_shard_threshold` is in `SETTABLE_KEYS` with its own
  numeric-coercion arm (`:1735`) and is exercised by `wave6-smoke.sh:2575`, so it looks alive. It
  has **zero producers** in `skills/`, `agents/`, `hooks/`, `monitors/` and **zero readers
  anywhere**; `skills/implement/SKILL.md:85,91` reads `user_config.qc_shard_threshold`, never
  state -- so `edm-state set <PREFIX> qc_shard_threshold 40` succeeds, persists, and changes
  nothing. Not a false alarm: the provenance comment at `:1665-1671` names a producer for every
  other key and says nothing about this one, and CA-246's "deleted rather than kept settable for a
  future producer" precedent sits three lines below at `:1672-1676`. **Fix:** either make
  `implement`'s step 8 read state first and fall back to `user_config` (giving the key a real
  reader), or delete it from `SETTABLE_KEYS` and `:1735` and re-key `wave6-smoke.sh:2575` onto
  `current_phase`. Either way, extend `:1665-1671` so every member states a producer **and** a
  consumer -- the omission is what let this sit.

- **G30 / CA-357 -- `edm-state:4389`, `:4398`.** `set-supersedes` and `set-forked-from` are
  dispatched (`:5179-5180`), documented in the help sentinel (`:47-48`), and have real consumers
  (the HANDOFF renderer prints their rows at `:5055-5056`) -- but zero callers and **zero
  user-facing documentation**: no occurrence of either command, or of `supersedes`/`forked_from`,
  anywhere in `skills/`, `agents/`, `hooks/`, `monitors/`, `evals/` or `README.md`. The sibling
  pair is the control: `set-parent`/`add-related` are named at `README.md:264` and their
  `CLAUDE.md` rows carry an explicit "(set via ...)" clause, while `CLAUDE.md:802-803` does not.
  **Fix:** add both to `README.md:264`'s linkage bullet and add the "(set via ...)" clause to
  `CLAUDE.md:802-803`; or delete the pair, the two fields and the two renderer lines the way
  `last_cmd` was deleted.

- **G31 / CA-358 -- `hooks.json:23, 36, 49, 62, 75`.** The command hooks validate the prefix
  charset **before** `resolve-dir` (`case "$prefix" in ''|*[!A-Za-z0-9_-]*) echo "[EDM] invalid
  prefix" >&2; exit 2 ;; esac`) -- verified present in all five. The prompt bodies have three
  steps and no charset guard, so a malformed prefix makes `resolve-dir` fail and step 2 labels it
  "a legitimate first invocation -- allow expansion", inside a prompt whose opening sentence
  claims it "must resolve the SAME gate the binary would". Fail-safe in direction (the
  deterministic hook still blocks), so the cost is a contradictory advisory and an unkept parity
  claim. **Fix:** add one clause to each of the five prompt strings distinguishing "no state file
  yet" (allow) from "malformed prefix argument" (block), using the same `[EDM] invalid prefix`
  wording; extend the G31/CA-279 tripwire at `wave7-smoke.sh:6193-6203` with a per-matcher
  assertion that the prompt names the invalid-prefix case, so the next rewrite cannot drop it.

- **G32 / CA-363 -- `hooks.json:8` vs `:96`, `:106`.** `Stop` and `PreCompact` are byte-identical;
  `SessionStart` alone adds `2>/dev/null` inside its `|| true`, making it the one hook that
  discards its own diagnostics -- and it is the hook that globs **every** state file under the SRD
  root on every session, i.e. exactly where a torn state file, an unresolvable path or a lock
  timeout would announce itself. The `|| true` already guarantees non-blocking, so the redirect
  buys silence only. **Corroborated by G14/CA-352 from the consumer side**: the ambiguous-resolution
  warning is emitted on stderr and this hook is guaranteed to swallow it -- the two findings are
  mutually reinforcing evidence. `CLAUDE.md`'s Hooks-behavior table documents both rows (`:664`,
  `:667`) with no mention of the difference. **Fix:** drop `2>/dev/null` so all three degrade
  identically; or keep it and add the rationale to the `SessionStart` row so the divergence is
  intentional on the page.

- **G33 / CA-364 -- `edm-state:1124` vs `:1028`.** The two `die` messages for the identical
  failure quote different units: "state lock timeout after **10s** on `<lockfile>`" versus "state
  lock timeout after **50 tries** on `<lockdir>`", making the same failure uncorrelatable in a log
  and leaking a loop-internal count to the operator. `:1184`'s own comment already says "the
  existing 50-try/5s total budget", so the duration is known and simply not surfaced. **Fix:**
  make both quote the same unit, e.g. `state lock timeout after ~5s (50 tries x 0.1s) on ...`.
  **The underlying budget asymmetry is excluded** -- see Decisions #2.

- **G34 / CA-365 -- `edm-state:5186`.** The only one of twelve `print_help` call sites passing
  `$0`; the other eleven pass `${BASH_SOURCE[0]:-$0}`, the form `_edm-cli-lib.sh:25-28` documents
  as the caller convention. **No live defect** -- the dispatch is guarded by
  `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]` at `:5142`, so `$0` is provably the script path on the
  only reachable path, and the owning lens offered to disposition this NOTED. Filed at P2 because
  `edm-state` is the most-read member of the family (the shape a contributor copies) and the
  CA-005/CA-154 loop at `wave7-smoke.sh:5513-5528` asserts only that each file *sources* the
  library, never the call form. **Fix:** `print_help "${BASH_SOURCE[0]:-$0}"`, and extend that loop
  to assert the call literal alongside the source literal.

- **G36 / CA-367 -- `edm-state:6`, `:120`.** Both EDM-HELP rationale comments still read "which is
  exactly how `update-patterns` and `lint` fell out of `--help` before this ticket". `cmd_lint` and
  its `lint)` arm were removed **this round** (CA-247 closed; 39 dispatch arms == 39 `cmd_*`
  definitions == 39 names in `CLAUDE.md:760`), while `update-patterns` is live -- so the sentence
  mixes one resolvable name with one that resolves to nothing. **Fix:** three words -- "the
  since-removed `lint`" -- in both copies.

- **G37 / CA-373 -- `edm-state:4966`.** `notes="${notes#$'\n'}"` strips exactly one leading
  newline, but the `awk` capture can yield zero (prose immediately after `## Notes`) or two (an
  ordinary pasted block), so the general idempotence property the comment at `:4962-4966` claims is
  established only for the one-blank-line case; and command substitution strips **all** trailing
  newlines, so deliberate trailing blanks are silently dropped on every regeneration. CA-027 fixed
  the destructive half, so what remains is cosmetic and bounded. **Fix:** normalize instead of
  stripping a fixed count -- `while [[ "$notes" == $'\n'* ]]; do notes="${notes#$'\n'}"; done` (or
  an awk pass) -- and narrow the comment to describe normalization.

- **G38 / CA-372 -- `bin/tests/fixtures/code-audit/README.md:49`.** The one runtime-write
  instruction in the plugin using a bare `/tmp` path (`--out /tmp/scores.json`), against a
  `${TMPDIR:-/tmp}` convention every executable follows (`edm-state:1117`,
  `edm-lint-artifacts:133`/`:140`, `edm-check-grants:123`, `_harness.sh:75`/`:101`,
  `tiering-matrix.sh:147`, every suite's `TMP=`) and which G55/CA-215 fixed for exactly this class.
  Predictable and world-writable, so plantable on a shared host; it also self-contradicts the prose
  three lines below at `:52-54`. **Fix:** `--out "${TMPDIR:-/tmp}/edm-scores.json"`.

- **G40 / CA-368 -- `.../epics/02-enforcement-kernel.md:314`, `:328-329`.** Two citation defects
  authored by **this session's own D43**: `wave6-smoke.sh:246` is a **blank line** inside the T07
  AC4 block (`:236-259`) -- the AC5 case is at `:261-266`; and T07 AC6 cites case `"T07 AC6 --
  exactly one direct call site"` where the shipped labels are `"T07 AC6 --
  code_audit_required_for_mode has exactly one direct call site"` (`wave6-smoke.sh:270`, `:279`),
  so a reader grepping the cited string gets nothing. CA-321's class inside the remediation that
  closed CA-321. **Fix:** drop the `:246` and keep the case name; replace the paraphrase with the
  verbatim shipped label; adopt verbatim-label citation as a stated convention in
  `tickets/README.md` so the next amendment cannot paraphrase.

- **G41 / CA-369 -- `.../epics/03-ci-and-fixture-eval.md:264`.** T21 AC5's first verify half says
  `grep -n 'run-all.sh' .gitlab-ci.yml` "returns the single invocation"; the file has **two**
  invocations (`:377` `test:smoke`, `:416` `test:smoke-bash32`) plus three comment mentions
  (`:363`, `:379`, `:380`). D44 rewrote the *second* half of this same verify and its own
  re-verification clause names both jobs without noticing. Substance is fine (one aggregator entry
  point, deliberately run under two images); the stated result is not. **Fix:** "returns the
  aggregator invocation in each of the two `test:` jobs and nothing else."

- **G42 / CA-370 -- `.../epics/11-cross-cutting-delivery.md:466-467`, `:473-474`.** CA-323's
  relabel closed the baseline clause and left T64 AC11's second clause asserting the suites are
  green **in CI**, with a verify requiring a green default-branch pipeline -- which D27 records
  does not exist in this environment, and D27's scope is T67 AC9/AC13 only. The exact D15
  unverifiable-criterion class the relabel pass was in the AC to fix. The runnable half
  (`run-all.sh` exit 0) is fine. **Fix:** scope the CI clause the way D27 scopes its siblings
  (verified-locally-pending-pipeline), or point it at the aggregator alone; cross-reference D27.

- **G43 / CA-371 -- `.../epics/11-cross-cutting-delivery.md:660-674`.** CA-242's durability half
  landed correctly -- T66 AC3 now derives the `bin/` row count mechanically, and L9 re-derived it
  statically at exactly 9 of 9. But the AC's own text says the derivation avoids "a second
  hardcoded literal" and then prints one in prose as "(9 as of this round)". Currently accurate, so
  latent rather than live. **Fix:** delete the parenthetical, or mark it explicitly non-normative.

- **G44 / CA-317 -- `.gitlab-ci.yml`, four sites.** **Fourth consecutive round**, and the
  sweep-the-named-sites-only pattern this entry's own text predicted repeated exactly. Closed: the
  three named jobs plus `eval:nightly`'s comparison branch (9 of 13 conform). Remaining holes: (a)
  `lint:bash-syntax` has four terminal exits and only the first prints `lint:bash-syntax: FAILED`
  -- the three grep-ban exits print a job-named sentence with **no `FAILED` token**, inside the
  very job that demonstrates the convention; (b) `validate:manifest`'s parse early exit at `:502`
  prints `FAIL: marketplace.json does not parse ...` with no job name and the un-standardized
  `FAIL` token, where the same job's terminal path at `:581-585` prints `validate:manifest:
  FAILED`; (c) `test:smoke` and `test:smoke-bash32` print **no** job-named failure line anywhere,
  and `:415`'s version assertion fails with no message at all; (d) `eval:nightly`'s `run-eval.sh`
  and `score-artifacts.sh` steps do not name themselves. The **durability half also did not land
  as prescribed**: `wave7-smoke.sh:7329-7343` is a hand-enumerated list over exactly the sites the
  sweep fixed, and its bare-`FAIL` screen only sees the `<job>: FAIL` shape, so `:502` is invisible
  to it. **Fix:** add the missing lines at all four sites; wrap the two `test:` jobs so a non-zero
  suite prints `test:smoke: FAILED` / `test:smoke-bash32: FAILED` and give `:415` its own message;
  standardize on **one** of `FAIL` or `FAILED` across every job; then **replace** the hand list
  with a whole-file sweep -- enumerate every top-level job key (`^[a-z][a-z0-9:_-]*:$`) and for
  each body containing `exit 1` assert a `<job>: FAILED` occurrence. Only the self-enforcing
  version ends the recurrence.

- **G45 / CA-318 -- `edm-state:1185-1193` vs `:3587-3602`.** **Fixed on the happy path only.** Both
  reclaimers now age-gate, but they take **opposite** directions when the age cannot be computed.
  `cmd_git_lock_check` reads the age through the shared primitive and treats failure as unknown --
  `lock_age_s="$(_git_lock_age_seconds "$lock_file")" || lock_age_s=""`, then
  `[[ -n "$lock_age_s" ]] && (( lock_age_s >= 60 ))`, so unknown falls to the `else` and
  **refuses**. The sibling hand-rolls the computation with the inverse default --
  `_lockdir_created_s="$(date -r "$lockdir" +%s 2>/dev/null || echo 0)"` -- so an unreadable mtime
  yields an age of ~1.7e9 seconds and an unconditional **reclaim**, and it bypasses
  `_git_lock_age_seconds` (`:3538-3543`), whose own docstring says every age gate in the file
  derives from one call to it. This is the CA-227/CA-228 "PARTIALLY FIXED, and the comment says
  otherwise" shape: `:1173-1176` and `:3636-3638` both assert the asymmetry is closed, and both are
  false on the error path. On any host where `date -r <dir>` does not work, the new gate degrades to
  **no gate at all** with no diagnostic -- and reclaiming is the direction that can delete a live
  lock. The two age **thresholds** legitimately differ (1s vs 60s, documented at `:1176-1184`) and
  are not part of this. **Fix:**
  `_lockdir_age_s="$(_git_lock_age_seconds "$lockdir")" || _lockdir_age_s=""`, then gate on
  `[[ -n "$_lockdir_age_s" ]] && (( _lockdir_age_s >= 1 ))`, with the existing
  not-reclaiming-yet stderr line covering the empty case and naming "age could not be determined"
  so the two refusal reasons are distinguishable. One primitive, one error contract, and both
  comments become true as written.

---

## Decisions / Non-Findings

These were flagged by one or more lenses this round and determined **Not Actionable**. Future
audits should **not** re-investigate them. Full text: ledger `CA-374`, `CA-375`, `CA-376`, `CA-377`.

1. **L3 flagged `plugins/edm/docs/audit-patterns/*.lock` as covered by no `.gitignore`** -- L5
   verified the root pattern does cover it; resolved toward L5. Only the claim survives (G11).
2. **L7 flagged the two lock-acquisition wait budgets (10s flock vs ~5s mkdir) as unexplained** --
   standing NOTED under CA-294; L3 re-derived it and agreed. Only the message units are actionable
   (G33).
3. **L1 read `CLAUDE.md:843-854`'s schema_at_least count as correct; L11 read it as NOTED; L6 filed
   it** -- resolved toward L6 (a mid-sentence mention does not satisfy the canonical form the
   passage's own point rests on). Three readers, three answers: that is the argument for G25's
   computed assertion.
4. **L5 recorded `run-eval.sh:266`'s `mktemp -d` tree as TMPDIR-resident** -- resolved toward L8;
   the *retention* is deliberate, the *location* is not (G20).
5. **L1 flagged `edm-lint-artifacts:365-402`'s missing `UNREADABLE_FLAGS` guard** -- behaviourally
   equivalent; `MERMAID_SETS[$i]=""` at `:276` plus the `-z` continue at `:368` catches it.
6. **L1/L2/L10 flagged `edm-validate-prefix:80`'s doubled slash and guard asymmetry** --
   POSIX-harmless and the inner `-d` tests absorb an unmatched glob. Only the duplication is filed
   (G24).
7. **L1 flagged `--calibrate`'s upper median (`:2942-2943`)** -- used identically for duration and
   cost, and the output is labelled "Median values".
8. **L1/L2 flagged the `unknown` sentinel arm's placement (`:485-494`)** -- sanctioned by
   `CLAUDE.md`'s D32 note; the arm also differs behaviourally (it suppresses the AC10 warning).
9. **L1 flagged `audit-converged` accepting `deferred` while its diagnostic enumerates
   `open|fixed|noted`** -- read-compat only per EDMV3-T25 AC4; the message names the going-forward
   enum.
10. **L2 flagged `edm-state:1125-1129`'s `_lock_ec -eq 99` arm** -- CA-305's deliberate secondary
    diagnostic; no locked body exits 99 today.
11. **L3 flagged the timeout marker's `$$`-derived name as predictable** -- TMPDIR is per-container
    in every environment this runs in, and the marker is `rm -rf`'d before and after use. The
    *ordering* defect is filed (G13).
12. **L3 flagged `record_degraded_check`'s unlocked idempotence pre-check** -- benign TOCTOU; the
    locked jq filter re-checks at `:1627-1630`, documented at `:1594-1597`.
13. **L3 flagged `cmd_checkpoint`'s unlocked drift re-read (`:2260`)** -- read-only, advisory-only;
    a torn read yields a spurious warning, never a bad write.
14. **L3 flagged `_write_handoff_body` calling `cmd_audit_converged` inside `with_state_lock`** --
    verified read-only end to end, so no deadlock. Recorded so nobody adds a lock to it. The
    separate defect on those lines is G15.
15. **L4 flagged `count_matches`'s exit-1/exit-2 collapse** -- documented with a mandatory pairing
    rule at `_harness.sh:180-185`; `count_matches_strict` exists for the strict case.
16. **L4 flagged `check "..." "0" "$ca140_*"` as substring-on-a-number** --
    `schema_at_least` can only echo `0`, `1` or `2`; no wider value can satisfy the needle.
17. **L7 flagged `die()`'s two default exit codes across the twelve scripts** -- documented as
    deliberate at `edm-state:70-73` and asserted per-script; only the *shape* was ever to be
    unified (CA-074).
18. **L7 flagged the eight bare `CLAUDE.md Sec."..."` prompt-surface touch points** -- documented
    intentional residual scope at `CLAUDE.md:306-322` (D34), tracked as follow-on `EDMV4-T04`.
19. **L7/L11 flagged `KillShell`/`BashOutput` granted without `Bash` on all eleven lens agents** --
    CA-179, uniform and inert.
20. **L9 flagged nine `git diff ... | grep -c` verify forms** -- per-merge-request historical
    claims, not tree-state assertions; D48's own carve-out.
21. **L9 flagged T28 AC9's understated blocking filter** -- reconciled by T28 AC5's explicit
    `deferred`-counts-as-open requirement.
22. **L11 flagged `set-parent`/`add-related`/`migrate-schema`/`migrate-path`/`validate`/
    `render-ledger` as having no automated caller** -- documented operator commands. Contrast G30,
    which lacks that documentation.
23. **CA-130 reproduced a seventh consecutive round** -- host-side tooling gap, not a repository
    defect. Its round-6 *consequence* is recorded as CA-377 and constrains this round's confidence.

Roughly thirty further accepted behaviours are enumerated in ledger entry **CA-376** (grouped
deliberately so a future round does not re-derive them one at a time).

---

## Rollout Order

**Wave A -- P1s, parallelizable by file independence.** Three independent groups:

1. `plugins/edm/hooks/hooks.json` + `wave7-smoke.sh` -- **G1/CA-320** (both sub-defects in one
   edit). Do this first; it is the only security-control finding.
2. `plugins/edm/bin/edm-state` + `wave6-smoke.sh` -- **G2/CA-333** and **G4/CA-335** (different
   functions, one file, one commit).
3. Docs and spec, one commit each: **G5/CA-336** + **G6/CA-337** (both timing-evidence text --
   land **after** G46/CA-311 so the harness is guarded first); **G3/CA-334** + **G7/CA-338** (both
   ticket-pack AC sweeps, both needing `decisions.md` entries in the same commit as the text edit).

**Wave B -- P2s that guard a P1-class regression or unblock other work.** In this order:

4. **G8/CA-346** (Case C for the five hooks) -- pair with G1 so the hook family gets behavioural
   coverage in the same review.
5. **G18/CA-378** (`render-ledger` pipe escaping) -- **before any `render-ledger` run**, or the
   regenerated `findings-ledger.md` will be corrupt.
6. **G46/CA-311** (wire `timing.sh --self-test`) -- before G5, per above.
7. **G12/CA-345** + **G9/CA-339** + **G31/CA-358** -- all the same hook family and the same
   `gate-check` contract; one pass.

**Wave C -- P2 batches by file, each one commit.**

8. `bin/edm-state` behaviour: G13/CA-347, G14/CA-352, G15/CA-353, G16/CA-355, G17/CA-354,
   G33/CA-364, G34/CA-365, G36/CA-367, G37/CA-373, G45/CA-318, G29/CA-356, G30/CA-357.
9. `bin/edm-state` + helpers DRY: G23/CA-343 then G24/CA-344 (G23 first -- it touches the same
   functions and carries the false-claim corrections).
10. `evals/`: G19/CA-360, G20/CA-348, G21/CA-359, G22/CA-362.
11. `.gitlab-ci.yml` + its assertions: G44/CA-317, G39/CA-349, G48/CA-233.
12. Test quality: G26/CA-350, G27/CA-361, G28/CA-351, G35/CA-366, G47/CA-312.
13. Docs/consistency: G10/CA-340 (**including the shape-restricted citation ban -- the durability
    half**), G11/CA-341, G25/CA-342, G32/CA-363, G38/CA-372.
14. Ticket pack: G40/CA-368, G41/CA-369, G42/CA-370, G43/CA-371 -- one commit with the matching
    `decisions.md` entries.

**Nothing is deferred.** Per this initiative's established rule, P2 blocks convergence, so there is
no P2 tail to push to a maintenance window.

**Three durability fixes are load-bearing and must not be dropped from their groups** -- without
them the same findings return in round 7: G10's shape-restricted citation ban, G44's whole-file
job-name sweep, and G25's computed count assertions. G3's process rule (grep the ticket pack and
`srd.md` for a symbol before committing a move; land the AC edit in the same commit) is the fourth.

---

## Verification Plan

**This is a bash/markdown plugin -- there is no compile step.** Substitute the repo's own gates:

```bash
# Syntax / lint (matches the blocking CI stages)
bash -n plugins/edm/bin/edm-state plugins/edm/bin/edm-init plugins/edm/bin/edm-lint-artifacts \
        plugins/edm/bin/edm-validate-prefix plugins/edm/bin/edm-check-grants \
        plugins/edm/bin/edm-check-vocabulary plugins/edm/bin/edm-check-skill-sync \
        plugins/edm/bin/edm-compare-eval plugins/edm/bin/edm-sync-canonical-sections \
        plugins/edm/bin/_edm-lint-lib.sh plugins/edm/bin/_edm-cli-lib.sh \
        plugins/edm/evals/*.sh plugins/edm/bin/tests/*.sh
shellcheck plugins/edm/bin/edm-* plugins/edm/bin/_edm-*.sh plugins/edm/evals/*.sh

# Artifact / grant / vocabulary lints
plugins/edm/bin/edm-lint-artifacts --all
plugins/edm/bin/edm-check-grants
plugins/edm/bin/edm-check-vocabulary
plugins/edm/bin/edm-check-skill-sync

# Full suite -- THE gate. Must be executed, not statically reasoned about (CA-377).
bash plugins/edm/bin/tests/run-all.sh

# bash 3.2 conformance (macOS floor / the test:smoke-bash32 job)
docker run --rm -v "$PWD:/w" -w /w bash:3.2 sh -c \
  'apk add --no-cache jq git >/dev/null && bash plugins/edm/bin/tests/run-all.sh'

# Newly-wired self-tests
bash plugins/edm/bin/tests/timing.sh --self-test      # after G46/CA-311
bash plugins/edm/evals/tiering-matrix.sh --self-test

# State validation (mirrors the blocking test:state-validate job)
plugins/edm/bin/edm-state validate EDMV3

# Ledger integrity -- run AFTER G18/CA-378, never before
plugins/edm/bin/edm-state audit-converged EDMV3
plugins/edm/bin/edm-state render-ledger EDMV3
```

**Assertion-count expectations.** Baseline this round was reported as **1996 passed / 0 failed**
across seven suites (orchestrator-supplied; **unverified by any lens** -- re-establish it before
trusting any delta). Expected additions: +5 from G46/CA-311's `--self-test` wiring, +5 from
G8/CA-346's Case C (one per matcher), +1 from G26/CA-350's case control, +1 from G13/CA-347's
executing marker case, +1 from G1/CA-320's executing subdirectory case, +2 from G25/CA-342's
computed counts, +1 from G48/CA-233's cross-loop consistency check, plus G44/CA-317's whole-file
sweep (one assertion per job containing `exit 1`). **G47/CA-312 changes one assertion's shape
without changing the count.**

**Integration smoke (manual, in a scratch consumer repo -- not this one).**

1. `git init /tmp/edmsmoke && cd /tmp/edmsmoke`; scaffold via `edm-init`, then again via
   `edm-state init`. After one mutation each, `git status --porcelain` must show **zero** untracked
   EDM runtime files (**G11/CA-341**).
2. `mkdir -p sub && cd sub`; stage a file under `SRD/` containing a git commit co-author trailer;
   run the PreToolUse hook body. Must **exit 2** with a named diagnostic. Repeat with
   `git -c diff.relative=true` (**G1/CA-320**).
3. Create a `prototype` initiative, approve Gate 1 twice, render HANDOFF.md. Must read
   `Gates approved: 1 of 1` (**G4/CA-335**).
4. Create an initiative at `schema_version: 1` with one open PARTIAL. Both `archive` and
   `phase-complete 6` must **refuse** (**G2/CA-333**).
5. With every gate approved, invoke `/edm:srd`, `/edm:audit-srd`, `/edm:tickets`,
   `/edm:audit-tickets` and `/edm:implement`. All five must be **allowed** (**G8/CA-346** is the
   automated form of this).
6. Point `TMPDIR` at a non-default directory and run `run-eval.sh --provision-only`; the printed
   scratch path must be under `TMPDIR` (**G20/CA-348**).

**Re-audit (targeted).** Every lens surfaced at least one finding this round, and 45 closures rest
partly on absence-of-report, so **round 7 must be a full 11-lens round** -- a partial round cannot
satisfy the convergence gate and would not cover the closures. Three specific spot-checks take
priority regardless of lens assignment (all recorded under CA-377):

- **CA-037's DRY half** -- re-count the ten hand-rolled tautological-control copies across
  `wave6`/`wave7`. L10 explicitly declined to verify this; closure rests on L4's verdict plus the
  verified zero-production-caller tripwire.
- **CA-251's L8 residual** -- the `pgrep` exit-code distinction in `git-lock-check` candidate
  selection. L3 did not reach that function this round.
- **CA-307** -- the `_print_literal` assertion label at `wave7-smoke.sh:6025-6026`. L2 could only
  grep `bin/tests/`.

**Precondition for the round-7 convergence gate (CA-331, now mandatory):** a Bash-capable pass
must execute `bash plugins/edm/bin/tests/run-all.sh` and report the executed result. Six
consecutive rounds have closed on a figure no lens produced.

---

## Convergence Read

**NOT CONVERGED.**

- Round type: **full** (11 of 11 lenses) -- the round-type half of the gate is satisfied.
- **P0: 0.** No production-failure or unguarded-merge finding survives.
- **P1: 7** -- CA-320 (escalated), CA-333, CA-334, CA-335, CA-336, CA-337, CA-338.
- **P2: 41.**
- **Deferred: 0.** Nothing is excluded from the blocking set.

Per this initiative's established rule that **P2 also blocks**, 48 open findings block the gate.
Even under the standard rule (zero open P0/P1), the 7 P1s block it.

**Two structural observations for the gate decision.**

1. **Eight of this round's findings were introduced by round 5's own remediation** -- CA-333's
   siblings survived CA-182's sweep, and CA-337, CA-340, CA-347, CA-351, CA-360, CA-361 and CA-366
   were each *created* by a round-5 or in-session fix. The remediation loop is now generating
   findings at a rate comparable to the rate at which it closes them, and the durability halves
   (G10, G44, G25, plus G3's process rule) are what change that.
2. **L9's entire finding set is spec-side, not code-side.** In every one of its eight findings the
   shipped code is correct and the specification is stale -- the inverse of the usual direction,
   for the fourth consecutive round, from one root cause: a remediation lands the code and does not
   sweep the AC that names it.
